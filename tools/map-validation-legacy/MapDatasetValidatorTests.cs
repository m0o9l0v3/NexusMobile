using System.Text.Json.Nodes;
using AdminApi.Services.MapValidation;
using Xunit;

namespace AdminApi.Tests;

public sealed class MapDatasetValidatorTests
{
    private static readonly Guid SpotId = Guid.Parse("11111111-1111-1111-1111-111111111111");
    private readonly MapDatasetValidator _validator = new();
    private static JsonObject Fixture() => JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures/map-dataset.json")))!.AsObject();
    private static JsonArray Features(JsonObject data) => data["features"]!.AsArray();
    private static JsonObject Feature(JsonObject data, string id) => Features(data).Single(f => f!["id"]!.GetValue<string>() == id)!.AsObject();
    private static DatasetValidationContext Complete() => new()
    {
        ForPublication = true,
        StartNodeIds = ["campus_n_020"],
        CampusBoundaryGeoJson = """{"type":"Polygon","coordinates":[[[141.68,42.77],[141.69,42.77],[141.69,42.78],[141.68,42.78],[141.68,42.77]]]}""",
        EnuOrigin = new(141.68, 42.77), EntranceMaxGapMetres = 5, PathDistanceToleranceMetres = 1,
        ExpectedPathSeconds = new Dictionary<string, double> { ["campus_e_012"] = 15, ["mb_1f_e_001"] = 13 },
        FloorTransforms = new Dictionary<string, FloorTransformEvidence> { ["mb_1f"] = new(.01, 1, 1, 1, .01) },
        DatabaseSpots = [new(SpotId, "mb_1f_n_005", true)],
        PublishedNavigationSpotIds = ["mb_1f_n_005"], Aliases = [], OtherReservedCanonicalIds = []
    };
    private DatasetValidationResult Validate(JsonObject data, DatasetValidationContext? context = null) => _validator.Validate(data.ToJsonString(), context ?? Complete());
    private static void Has(DatasetValidationResult result, string code)
    {
        Assert.False(result.CanPublish);
        Assert.Contains(result.Errors, e => e.Code == code);
    }

    [Fact]
    public void CompleteSyntheticContext_PassesWithoutRewritingInput()
    {
        var data = Fixture(); var original = data.ToJsonString();
        var result = Validate(data);
        Assert.True(result.CanPublish, string.Join("\n", result.Errors));
        Assert.Equal(original, data.ToJsonString());
        Assert.Equal(result.Errors, Validate(data).Errors);
    }

    [Fact]
    public void EmptyDraft_IsValidButCannotPublish()
    {
        const string data = """{"type":"FeatureCollection","nexus":{"schema_version":"1.0.0","floors":[]},"features":[]}""";
        Assert.True(_validator.Validate(data).IsValid);
        Assert.False(_validator.Validate(data).CanPublish);
        Has(_validator.Validate(data, Complete()), "empty_navigation_graph");
    }

    [Theory]
    [InlineData("{", "invalid_json")]
    [InlineData("null", "schema_violation")]
    [InlineData("{\"type\":\"a\",\"type\":\"b\"}", "duplicate_json_member")]
    [InlineData("{\"x\":1e999}", "non_finite_number")]
    public void MalformedPayload_IsRejected(string json, string code) => Has(_validator.Validate(json), code);

    [Theory]
    [InlineData("duplicate_feature", "duplicate_canonical_id")]
    [InlineData("duplicate_floor", "duplicate_canonical_id")]
    [InlineData("missing_reference", "undefined_reference")]
    [InlineData("parent_mismatch", "parent_id_mismatch")]
    [InlineData("outside_world", "schema_violation")]
    [InlineData("extra_dimension", "schema_violation")]
    [InlineData("unknown_property", "schema_violation")]
    [InlineData("uppercase_id", "schema_violation")]
    [InlineData("precision", "coordinate_precision")]
    [InlineData("endpoint", "path_endpoint_mismatch")]
    [InlineData("self_loop", "self_loop_path")]
    [InlineData("duplicate_edge", "duplicate_edge")]
    [InlineData("unclosed_ring", "invalid_geometry")]
    [InlineData("self_intersection", "invalid_geometry")]
    [InlineData("orientation", "ring_orientation")]
    [InlineData("isolation", "isolated_node")]
    [InlineData("outside_campus", "outside_campus")]
    [InlineData("entrance_gap", "entrance_connection_gap")]
    [InlineData("distance", "path_distance_mismatch")]
    [InlineData("seconds", "path_seconds_mismatch")]
    public void BrokenFixtures_ProduceSpecificFinding(string kind, string code)
    {
        var data = Fixture();
        var node = Feature(data, "mb_1f_n_004");
        var path = Feature(data, "campus_e_012");
        var polygon = Feature(data, "mb")["geometry"]!["coordinates"]![0]!.AsArray();
        switch (kind)
        {
            case "duplicate_feature": Features(data).Add(node.DeepClone()); break;
            case "duplicate_floor": data["nexus"]!["floors"]!.AsArray().Add(data["nexus"]!["floors"]![0]!.DeepClone()); break;
            case "missing_reference": path["properties"]!["to_node_id"] = "campus_n_999"; break;
            case "parent_mismatch": node["properties"]!["floor_id"] = "mb_2f"; break;
            case "outside_world": node["geometry"]!["coordinates"]![0] = 501.62; break;
            case "extra_dimension": node["geometry"]!["coordinates"]!.AsArray().Add(1); break;
            case "unknown_property": node["properties"]!["unknown"] = true; break;
            case "uppercase_id": node["id"] = "MB_1f_n_004"; break;
            case "precision": node["geometry"]!["coordinates"]![0] = 141.6810301; break;
            case "endpoint": path["geometry"]!["coordinates"]![0]![0] = 141.68081; break;
            case "self_loop": path["properties"]!["to_node_id"] = "campus_n_020"; break;
            case "duplicate_edge": var copy = path.DeepClone(); copy["id"] = "campus_e_013"; Features(data).Add(copy); break;
            case "unclosed_ring": polygon[4]![0] = 141.68101; break;
            case "self_intersection": polygon[1] = JsonNode.Parse("[141.682,42.772]"); polygon[2] = JsonNode.Parse("[141.682,42.771]"); break;
            case "orientation": var reverse = polygon.Reverse().Select(x => x!.DeepClone()).ToArray(); polygon.Clear(); foreach (var point in reverse) polygon.Add(point); break;
            case "isolation": var isolated = node.DeepClone(); isolated["id"] = "mb_1f_n_099"; Features(data).Add(isolated); break;
            case "outside_campus": node["geometry"]!["coordinates"]![0] = 140; break;
            case "entrance_gap": Feature(data, "mb_ent_001")["geometry"]!["coordinates"]![0] = 141.688; break;
            case "distance": path["properties"]!["distance_m"] = 1000; break;
            case "seconds": path["properties"]!["estimated_seconds"] = 99; break;
        }
        Has(Validate(data), code);
    }

    // Issue #77: broken fixtures must fail with the specific finding at the right location.
    // Each case mutates one aspect of the canonical example; none of these values are field measurements.
    [Theory]
    [InlineData("floor_building_missing", "undefined_reference", "mb_1f", "/nexus/floors/0/building_id")]
    [InlineData("node_floor_missing", "undefined_reference", "mb_1f_n_004", "/features/4/properties/floor_id")]
    [InlineData("entrance_outside_missing", "undefined_reference", "mb_ent_001", "/features/7/properties/outside_node_id")]
    [InlineData("zero_length_path", "invalid_geometry", "campus_e_012", "/features/3/geometry")]
    [InlineData("latitude_out_of_range", "schema_violation", null, null)]
    [InlineData("path_partly_outside_campus", "outside_campus", "campus_e_012", "/features/3/geometry")]
    [InlineData("building_partly_outside_campus", "outside_campus", "mb", "/features/0/geometry")]
    public void BrokenFixtures_ReportReferenceGeometryAndRangeFindingsAtTheirLocation(string kind, string code, string? id, string? location)
    {
        var data = Fixture();
        var path = Feature(data, "campus_e_012");
        var line = path["geometry"]!["coordinates"]!.AsArray();
        switch (kind)
        {
            case "floor_building_missing": data["nexus"]!["floors"]![0]!["building_id"] = "ab"; break;
            case "node_floor_missing": Feature(data, "mb_1f_n_004")["properties"]!["floor_id"] = "mb_9f"; break;
            case "entrance_outside_missing": Feature(data, "mb_ent_001")["properties"]!["outside_node_id"] = "campus_n_999"; break;
            case "zero_length_path": line[1] = line[0]!.DeepClone(); while (line.Count > 2) line.RemoveAt(2); break;
            case "latitude_out_of_range": Feature(data, "campus_n_020")["geometry"]!["coordinates"]![1] = 91; break;
            case "path_partly_outside_campus": line[1]![0] = 140; break;
            case "building_partly_outside_campus": Feature(data, "mb")["geometry"]!["coordinates"]![0]![1]![0] = 141.7; break;
        }
        var result = Validate(data);
        Has(result, code);
        if (location is not null)
            Assert.Contains(result.Errors, e => e.Code == code && e.CanonicalId == id && e.Path == location);
    }

    [Fact]
    public void RemovedFormalEntrance_LeavesIndoorNodesUnreachableButNotIsolated()
    {
        var data = Fixture();
        Features(data).Remove(Feature(data, "mb_ent_001"));
        var result = Validate(data);
        Has(result, "unreachable_node");
        Assert.Equal(new[] { "mb_1f_n_004", "mb_1f_n_005" }, result.Errors.Where(e => e.Code == "unreachable_node").Select(e => e.CanonicalId).Order().ToArray());
        Assert.DoesNotContain(result.Errors, e => e.Code == "isolated_node");
    }

    [Fact]
    public void PublicationWithoutStartNodes_IsRejectedInsteadOfGuessingAStart()
    {
        foreach (var start in new IReadOnlyList<string>?[] { null, [] })
            Assert.Contains(Validate(Fixture(), Complete() with { StartNodeIds = start }).Errors,
                e => e.Code == "missing_validation_context" && e.Path == "/context/startNodeIds");
    }

    [Fact]
    public void DraftValidation_RejectsBrokenReferencesButNeverPublishes()
    {
        var data = Fixture();
        Feature(data, "campus_e_012")["properties"]!["to_node_id"] = "campus_n_999";
        var result = _validator.Validate(data.ToJsonString());
        Assert.False(result.IsValid);
        Assert.False(result.CanPublish);
        Assert.Contains(result.Errors, e => e.Code == "undefined_reference");
    }

    [Fact]
    public void SeveralDefects_AreAllReportedInOneRunInDeterministicOrder()
    {
        var data = Fixture();
        Feature(data, "campus_e_012")["properties"]!["to_node_id"] = "campus_n_999";
        var duplicate = Feature(data, "mb_1f_n_005").DeepClone(); Features(data).Add(duplicate);
        var isolated = Feature(data, "mb_1f_n_004").DeepClone(); isolated["id"] = "mb_1f_n_099"; Features(data).Add(isolated);
        Feature(data, "campus_n_021")["geometry"]!["coordinates"]![0] = 140;
        var first = Validate(data);
        // Assert each defect by code AND target: the broken path also orphans campus_n_020, so codes alone could pass on side effects.
        Has(first, "undefined_reference");
        foreach (var (code, id) in new[] { ("duplicate_canonical_id", "mb_1f_n_005"), ("isolated_node", "mb_1f_n_099"), ("outside_campus", "campus_n_021") })
            Assert.Contains(first.Errors, e => e.Code == code && e.CanonicalId == id);
        Assert.Equal(first.Errors, Validate(data).Errors);
        Assert.Equal(first.Errors.OrderBy(e => e.Path, StringComparer.Ordinal).ThenBy(e => e.Code, StringComparer.Ordinal).ThenBy(e => e.CanonicalId, StringComparer.Ordinal), first.Errors);
    }

    [Fact]
    public void DirectedReachability_DoesNotTreatIncomingPathAsOutgoing()
    {
        var data = Fixture(); var path = Feature(data, "campus_e_012");
        path["properties"]!["bidirectional"] = false;
        path["properties"]!["from_node_id"] = "campus_n_021";
        path["properties"]!["to_node_id"] = "campus_n_020";
        var line = path["geometry"]!["coordinates"]!.AsArray();
        var points = line.Reverse().Select(n => n!.DeepClone()).ToArray(); line.Clear(); foreach (var point in points) line.Add(point);
        var result = Validate(data);
        Has(result, "unreachable_node");
        Assert.DoesNotContain(result.Errors, e => e.Code == "isolated_node");
    }

    [Fact]
    public void DisconnectedComponent_IsUnreachableEvenWhenNoneOfItsNodesAreIsolated()
    {
        var data = Fixture();
        var a = Feature(data, "campus_n_020").DeepClone(); a["id"] = "campus_n_098";
        var b = Feature(data, "campus_n_021").DeepClone(); b["id"] = "campus_n_099";
        var path = Feature(data, "campus_e_012").DeepClone(); path["id"] = "campus_e_099";
        path["properties"]!["from_node_id"] = "campus_n_098"; path["properties"]!["to_node_id"] = "campus_n_099";
        Features(data).Add(a); Features(data).Add(b); Features(data).Add(path);
        var result = Validate(data);
        Has(result, "unreachable_node");
        Assert.DoesNotContain(result.Errors, e => e.Code == "isolated_node");
    }

    [Fact]
    public void MissingPublicationContext_NeverPassesAsPublishable()
    {
        var result = Validate(Fixture(), new() { ForPublication = true });
        Has(result, "missing_validation_context"); Has(result, "missing_transform_evidence");
        Assert.False(_validator.Validate(Fixture().ToJsonString()).CanPublish);
    }

    [Theory]
    [InlineData("alias_collision", "alias_canonical_collision")]
    [InlineData("reserved_collision", "alias_canonical_collision")]
    [InlineData("alias_duplicate", "duplicate_alias")]
    [InlineData("alias_missing", "alias_target_missing")]
    [InlineData("alias_chain", "alias_chain")]
    [InlineData("spot_duplicate", "duplicate_spot_code")]
    [InlineData("navigation_duplicate", "duplicate_navigation_id")]
    [InlineData("missing_navigation", "missing_navigation_spot")]
    [InlineData("navigation_case", "navigation_spot_mismatch")]
    [InlineData("unpublished_spot", "navigation_spot_mismatch")]
    [InlineData("missing_spot", "undefined_spot_canonical_id")]
    public void IdentitySnapshots_AreComparedExactly(string kind, string code)
    {
        var context = Complete();
        context = kind switch
        {
            "alias_collision" => context with { Aliases = [new("mb", SpotId)] },
            "reserved_collision" => context with { Aliases = [new("old", SpotId)], OtherReservedCanonicalIds = ["old"] },
            "alias_duplicate" => context with { Aliases = [new("old", SpotId), new("old", SpotId)] },
            "alias_missing" => context with { Aliases = [new("old", Guid.Empty)] },
            "alias_chain" => context with { DatabaseSpots = [new(SpotId, "second_alias", true)], Aliases = [new("first_alias", SpotId), new("second_alias", Guid.Empty)] },
            "spot_duplicate" => context with { DatabaseSpots = [new(SpotId, "mb_1f_n_005", true), new(Guid.NewGuid(), "mb_1f_n_005", true)] },
            "navigation_duplicate" => context with { PublishedNavigationSpotIds = ["mb_1f_n_005", "mb_1f_n_005"] },
            "missing_navigation" => context with { PublishedNavigationSpotIds = [] },
            "navigation_case" => context with { PublishedNavigationSpotIds = ["MB_1f_n_005"] },
            "unpublished_spot" => context with { DatabaseSpots = [new(SpotId, "mb_1f_n_005", false)] },
            "missing_spot" => context with { DatabaseSpots = [new(SpotId, "not_a_canonical_id", true)] },
            _ => throw new ArgumentException(kind)
        };
        Has(Validate(Fixture(), context), code);
    }

    [Fact]
    public void SameEntityProjectionAndExplicitAlias_AreNotDuplicateCanonicalIds()
    {
        var result = Validate(Fixture(), Complete() with { Aliases = [new("old_reception", SpotId)] });
        Assert.True(result.CanPublish, string.Join("\n", result.Errors));
    }

    [Theory]
    [InlineData(.051, 1, 1, 1, .01)]
    [InlineData(.01, 2.001, 1, 1, .01)]
    [InlineData(.01, 1, 3.001, 1, .01)]
    [InlineData(.01, 1, 1, 3.001, .01)]
    [InlineData(.01, 1, 1, 1, .101)]
    [InlineData(-1, 1, 1, 1, .01)]
    public void TransformEvidence_UsesApprovedE15Limits(double roundTrip, double rms, double fitMax, double checkMax, double rounding)
    {
        Has(Validate(Fixture(), Complete() with { FloorTransforms = new Dictionary<string, FloorTransformEvidence> { ["mb_1f"] = new(roundTrip, rms, fitMax, checkMax, rounding) } }), "transform_tolerance_exceeded");
    }

    [Fact]
    public void UndefinedRootAndInvalidTolerances_AreRejected()
    {
        Has(Validate(Fixture(), Complete() with { StartNodeIds = ["CAMPUS_N_020"] }), "undefined_start_node");
        Has(Validate(Fixture(), Complete() with { EntranceMaxGapMetres = double.NaN }), "invalid_validation_context");
        Has(Validate(Fixture(), Complete() with { CampusBoundaryGeoJson = "{}" }), "invalid_validation_context");
    }

    [Fact]
    public async Task Service_CanBeUsedConcurrently()
    {
        var payload = Fixture().ToJsonString();
        var results = await Task.WhenAll(Enumerable.Range(0, 20).Select(_ => Task.Run(() => _validator.Validate(payload, Complete()))));
        Assert.All(results, result => Assert.True(result.CanPublish, string.Join("\n", result.Errors)));
    }

    [Fact]
    public void ContextDictionaries_DoNotOverrideExactIdComparison()
    {
        var context = Complete() with
        {
            FloorTransforms = new Dictionary<string, FloorTransformEvidence>(StringComparer.OrdinalIgnoreCase) { ["MB_1F"] = new(.01, 1, 1, 1, .01) },
            ExpectedPathSeconds = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase) { ["CAMPUS_E_012"] = 15, ["MB_1F_E_001"] = 13 }
        };
        var result = Validate(Fixture(), context);
        Has(result, "missing_transform_evidence");
        Has(result, "missing_validation_context");
    }

    [Fact]
    public void Cancellation_IsObserved() => Assert.Throws<OperationCanceledException>(() => _validator.Validate(Fixture().ToJsonString(), Complete(), new CancellationToken(true)));
}

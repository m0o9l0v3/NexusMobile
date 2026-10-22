import XCTest
@testable import Nexus

final class ParticipantBundleValidatorTests: XCTestCase {

    private func validate(_ object: [String: Any]) throws -> ParticipantBundle {
        let response = BundleFixtures.response(object)
        return try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
    }

    private func assertInvariant(
        _ object: [String: Any],
        _ expected: ParticipantBundleInvariant,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try validate(object), file: file, line: line) { error in
            XCTAssertEqual(error as? ParticipantBundleError, .invariantViolated(expected), file: file, line: line)
        }
    }

    // MARK: - 正常系

    func testValidBundleDecodesSpotsAndPlacements() throws {
        let bundle = try validate(BundleFixtures.bundleObject())

        XCTAssertEqual(bundle.meta.bundleVersion, 42)
        XCTAssertEqual(bundle.spots.map(\.id), ["mb_2f_cl_001", "mb", "campus_lm_001"])
        XCTAssertEqual(bundle.spots[0].placement?.accessNodeID, "mb_2f_n_012")
        // 建物は Polygon なので点を持たない。ランドマークは建物に属さない。
        XCTAssertNil(bundle.spots[1].placement?.point)
        XCTAssertNil(bundle.spots[1].placement?.floorID)
        XCTAssertNil(bundle.spots[2].placement?.buildingID)
    }

    /// 同じメジャー版で追加された未知の項目は無視する（§6 規則6）。
    func testUnknownFieldsAreIgnored() throws {
        var object = BundleFixtures.bundleObject()
        object["future_section"] = ["anything": true]
        var spots = BundleFixtures.validSpots()
        spots[0]["future_field"] = 1
        object["spots"] = spots

        XCTAssertEqual(try validate(object).spots.count, 3)
    }

    func testBundleWithoutMapAndPlacementsIsValid() throws {
        let object = BundleFixtures.bundleObject(
            spots: [BundleFixtures.spot(id: "mb", name: "教室棟")],
            map: NSNull()
        )
        XCTAssertNil(try validate(object).map)
    }

    // MARK: - ヘッダーとの照合（§6 規則2・8）

    func testChecksumMismatchIsRejected() {
        let response = BundleFixtures.response(BundleFixtures.bundleObject())
        let headers = ParticipantBundleHeaders(
            sha256: String(repeating: "0", count: 64),
            byteLength: response.headers.byteLength,
            bundleVersion: 42,
            schemaVersion: "2.0.0",
            etag: nil
        )
        XCTAssertThrowsError(try ParticipantBundleValidator.validate(body: response.body, headers: headers)) {
            XCTAssertEqual($0 as? ParticipantBundleError, .checksumMismatch)
        }
    }

    func testLengthMismatchIsRejected() {
        let response = BundleFixtures.response(BundleFixtures.bundleObject())
        let headers = ParticipantBundleHeaders(
            sha256: response.headers.sha256,
            byteLength: response.headers.byteLength + 1,
            bundleVersion: 42,
            schemaVersion: "2.0.0",
            etag: nil
        )
        XCTAssertThrowsError(try ParticipantBundleValidator.validate(body: response.body, headers: headers)) {
            XCTAssertEqual(
                $0 as? ParticipantBundleError,
                .lengthMismatch(expected: response.headers.byteLength + 1, actual: response.body.count)
            )
        }
    }

    func testHeaderVersionMustMatchPayload() {
        let response = BundleFixtures.response(BundleFixtures.bundleObject(version: 42))
        let headers = ParticipantBundleHeaders(
            sha256: response.headers.sha256,
            byteLength: response.headers.byteLength,
            bundleVersion: 43,
            schemaVersion: "2.0.0",
            etag: nil
        )
        XCTAssertThrowsError(try ParticipantBundleValidator.validate(body: response.body, headers: headers)) {
            XCTAssertEqual($0 as? ParticipantBundleError, .versionMismatch(header: 43, payload: 42))
        }
    }

    func testDeclaredLengthOverHardLimitIsRejectedBeforeDecoding() {
        let headers = ParticipantBundleHeaders(
            sha256: String(repeating: "0", count: 64),
            byteLength: ParticipantBundleValidator.hardLimitBytes + 1,
            bundleVersion: 42,
            schemaVersion: "2.0.0",
            etag: nil
        )
        XCTAssertThrowsError(try ParticipantBundleValidator.validate(body: Data("{}".utf8), headers: headers)) {
            XCTAssertEqual(
                $0 as? ParticipantBundleError,
                .exceedsHardLimit(byteLength: ParticipantBundleValidator.hardLimitBytes + 1)
            )
        }
    }

    func testUnknownMajorVersionIsRejected() {
        XCTAssertThrowsError(try validate(BundleFixtures.bundleObject(schemaVersion: "3.0.0"))) {
            XCTAssertEqual($0 as? ParticipantBundleError, .unsupportedSchema("3.0.0"))
        }
    }

    func testUnknownGeoJSONMajorVersionIsRejected() {
        let object = BundleFixtures.bundleObject(map: [
            "dataset_version": 7,
            "dataset_sha256": String(repeating: "a", count: 64),
            "geojson": BundleFixtures.geojson(schemaVersion: "1.0.0"),
        ])
        XCTAssertThrowsError(try validate(object)) {
            XCTAssertEqual($0 as? ParticipantBundleError, .unsupportedSchema("1.0.0"))
        }
    }

    func testMalformedJSONIsRejected() {
        let body = Data("{\"nexus_bundle\":".utf8)
        let headers = ParticipantBundleHeaders(
            sha256: ParticipantBundleValidator.sha256Hex(of: body),
            byteLength: body.count,
            bundleVersion: 42,
            schemaVersion: "2.0.0",
            etag: nil
        )
        XCTAssertThrowsError(try ParticipantBundleValidator.validate(body: body, headers: headers)) {
            XCTAssertEqual($0 as? ParticipantBundleError, .undecodable)
        }
    }

    // MARK: - 不変条件（§5.3）

    func testDuplicateSpotIDIsRejected() {
        let spots = BundleFixtures.validSpots() + [BundleFixtures.spot(id: "mb", name: "重複")]
        assertInvariant(BundleFixtures.bundleObject(spots: spots), .duplicateSpotID("mb"))
    }

    /// 大文字小文字が違う ID は別の ID として扱う（E1-3）。
    func testIDsDifferingOnlyInCaseAreDistinct() throws {
        let spots = [
            BundleFixtures.spot(id: "mb", name: "教室棟", placement: BundleFixtures.placement(featureType: "building", buildingID: "mb")),
            BundleFixtures.spot(id: "MB", name: "別の地点"),
        ]
        XCTAssertEqual(try validate(BundleFixtures.bundleObject(spots: spots)).spots.count, 2)
    }

    func testAliasCollidingWithFeatureIDIsRejected() {
        let object = BundleFixtures.bundleObject(idAliases: [["alias": "mb_2f_n_012", "canonical_id": "mb"]])
        assertInvariant(object, .aliasCollidesWithID("mb_2f_n_012"))
    }

    func testAliasCollidingWithFloorIDIsRejected() {
        let object = BundleFixtures.bundleObject(idAliases: [["alias": "mb_2f", "canonical_id": "mb"]])
        assertInvariant(object, .aliasCollidesWithID("mb_2f"))
    }

    func testAliasTargetMustBeAPublishedSpot() {
        let object = BundleFixtures.bundleObject(idAliases: [["alias": "old_id", "canonical_id": "not_published"]])
        assertInvariant(object, .aliasTargetMissing(alias: "old_id", canonicalID: "not_published"))
    }

    func testDuplicateAliasIsRejected() {
        let object = BundleFixtures.bundleObject(idAliases: [
            ["alias": "old_id", "canonical_id": "mb"],
            ["alias": "old_id", "canonical_id": "mb_2f_cl_001"],
        ])
        assertInvariant(object, .duplicateAlias("old_id"))
    }

    func testPlacementWithoutDestinationFeatureIsRejected() {
        var spots = BundleFixtures.validSpots()
        spots.append(BundleFixtures.spot(
            id: "mb_2f_cl_002",
            name: "2B教室",
            placement: BundleFixtures.placement(featureType: "room", buildingID: "mb", floorID: "mb_2f")
        ))
        assertInvariant(BundleFixtures.bundleObject(spots: spots), .destinationFeatureMissing(spotID: "mb_2f_cl_002"))
    }

    /// 解決できるのに placement を null にしない。
    func testNullPlacementWhenDestinationExistsIsRejected() {
        var spots = BundleFixtures.validSpots()
        spots[0]["placement"] = NSNull()
        assertInvariant(BundleFixtures.bundleObject(spots: spots), .placementMissing(spotID: "mb_2f_cl_001"))
    }

    func testPlacementValuesMustMatchFeature() {
        var spots = BundleFixtures.validSpots()
        spots[0]["placement"] = BundleFixtures.placement(
            featureType: "room",
            buildingID: "mb",
            floorID: "mb_2f",
            point: [141.0, 42.0],
            accessNodeID: "mb_2f_n_012"
        )
        assertInvariant(BundleFixtures.bundleObject(spots: spots), .placementMismatch(spotID: "mb_2f_cl_001"))
    }

    /// ノードは目的地種別ではないので、ノード ID の spot は解決できない（E1-4 改訂1 §5）。
    func testNodeIsNotADestinationType() {
        let spots = BundleFixtures.validSpots() + [BundleFixtures.spot(
            id: "mb_2f_n_012",
            name: "ノード",
            placement: BundleFixtures.placement(featureType: "indoor_node", buildingID: "mb", floorID: "mb_2f")
        )]
        assertInvariant(BundleFixtures.bundleObject(spots: spots), .destinationFeatureMissing(spotID: "mb_2f_n_012"))
    }

    func testPlacementRequiresMap() {
        let object = BundleFixtures.bundleObject(
            spots: [BundleFixtures.spot(
                id: "mb",
                name: "教室棟",
                placement: BundleFixtures.placement(featureType: "building", buildingID: "mb")
            )],
            map: NSNull()
        )
        assertInvariant(object, .placementWithoutMap(spotID: "mb"))
    }

    func testFloorMustBelongToPlacementBuilding() {
        let extra: [[String: Any]] = [
            [
                "type": "Feature",
                "id": "ptb",
                "geometry": ["type": "Polygon", "coordinates": [[[141.0, 42.0], [141.1, 42.0], [141.1, 42.1], [141.0, 42.0]]]],
                "properties": ["feature_type": "building"],
            ],
            [
                "type": "Feature",
                "id": "ptb_1f_rm_001",
                "geometry": ["type": "Point", "coordinates": [141.05, 42.05]],
                "properties": ["feature_type": "room", "building_id": "ptb", "floor_id": "mb_2f", "room_type": "rm"],
            ],
        ]
        let map: [String: Any] = [
            "dataset_version": 7,
            "dataset_sha256": String(repeating: "a", count: 64),
            "geojson": BundleFixtures.geojson(extraFeatures: extra),
        ]
        let spots = BundleFixtures.validSpots() + [BundleFixtures.spot(
            id: "ptb_1f_rm_001",
            name: "実習室",
            placement: BundleFixtures.placement(featureType: "room", buildingID: "ptb", floorID: "mb_2f", point: [141.05, 42.05])
        )]
        assertInvariant(BundleFixtures.bundleObject(spots: spots, map: map), .floorBuildingMismatch(spotID: "ptb_1f_rm_001"))
    }

    // MARK: - レビュー対応（PR #110）

    private func mapObject(extraFeatures: [[String: Any]]) -> [String: Any] {
        [
            "dataset_version": 7,
            "dataset_sha256": String(repeating: "a", count: 64),
            "geojson": BundleFixtures.geojson(extraFeatures: extraFeatures),
        ]
    }

    private func assertUndecodable(_ object: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try validate(object), file: file, line: line) { error in
            XCTAssertEqual(error as? ParticipantBundleError, .undecodable, file: file, line: line)
        }
    }

    /// 「必須（null可）」のキーの欠落は、null と区別して拒否する。
    func testMissingRequiredNullableSpotKeysAreRejected() {
        for key in ["kind", "description", "placement"] {
            var spots = BundleFixtures.validSpots()
            spots[1].removeValue(forKey: key)
            assertUndecodable(BundleFixtures.bundleObject(spots: spots))
        }
    }

    func testMissingRequiredNullablePlacementKeysAreRejected() {
        for key in ["building_id", "floor_id", "point", "access_node_id"] {
            var spots = BundleFixtures.validSpots()
            var placement = spots[0]["placement"] as! [String: Any]
            placement.removeValue(forKey: key)
            spots[0]["placement"] = placement
            assertUndecodable(BundleFixtures.bundleObject(spots: spots))
        }
    }

    func testMissingMapKeyIsRejected() {
        var object = BundleFixtures.bundleObject()
        object.removeValue(forKey: "map")
        assertUndecodable(object)
    }

    /// room は建物・階・点が必須。Feature 側も欠けていて値が一致しても通さない。
    func testRoomWithoutBuildingAndFloorIsRejected() {
        let extra: [[String: Any]] = [[
            "type": "Feature",
            "id": "mb_2f_cl_002",
            "geometry": ["type": "Point", "coordinates": [141.6228, 42.7844]],
            "properties": ["feature_type": "room", "room_type": "cl"],
        ]]
        let spots = BundleFixtures.validSpots() + [BundleFixtures.spot(
            id: "mb_2f_cl_002",
            name: "2B教室",
            placement: BundleFixtures.placement(featureType: "room", buildingID: NSNull(), point: [141.6228, 42.7844])
        )]
        assertInvariant(
            BundleFixtures.bundleObject(spots: spots, map: mapObject(extraFeatures: extra)),
            .placementShapeInvalid(spotID: "mb_2f_cl_002")
        )
    }

    /// landmark は建物に属さない。
    func testLandmarkWithBuildingIsRejected() {
        let extra: [[String: Any]] = [[
            "type": "Feature",
            "id": "campus_lm_002",
            "geometry": ["type": "Point", "coordinates": [141.6226, 42.7851]],
            "properties": ["feature_type": "landmark", "scope": "campus", "building_id": "mb"],
        ]]
        let spots = BundleFixtures.validSpots() + [BundleFixtures.spot(
            id: "campus_lm_002",
            name: "目印",
            placement: BundleFixtures.placement(featureType: "landmark", buildingID: "mb", point: [141.6226, 42.7851])
        )]
        assertInvariant(
            BundleFixtures.bundleObject(spots: spots, map: mapObject(extraFeatures: extra)),
            .placementShapeInvalid(spotID: "campus_lm_002")
        )
    }

    /// 到達ノードはノードでなければならない（建物などを指さない）。
    func testAccessNodeMustBeANode() {
        let extra: [[String: Any]] = [[
            "type": "Feature",
            "id": "mb_2f_cl_002",
            "geometry": ["type": "Point", "coordinates": [141.6228, 42.7844]],
            "properties": [
                "feature_type": "room", "building_id": "mb", "floor_id": "mb_2f",
                "room_type": "cl", "access_node_id": "mb",
            ],
        ]]
        let spots = BundleFixtures.validSpots() + [BundleFixtures.spot(
            id: "mb_2f_cl_002",
            name: "2B教室",
            placement: BundleFixtures.placement(
                featureType: "room", buildingID: "mb", floorID: "mb_2f",
                point: [141.6228, 42.7844], accessNodeID: "mb"
            )
        )]
        assertInvariant(
            BundleFixtures.bundleObject(spots: spots, map: mapObject(extraFeatures: extra)),
            .accessNodeInvalid(spotID: "mb_2f_cl_002")
        )
    }

    /// schema_version は SemVer として厳密に解析する。
    func testSemanticVersionParsing() {
        XCTAssertEqual(ParticipantBundleValidator.semanticMajorVersion(of: "2.0.0"), 2)
        XCTAssertEqual(ParticipantBundleValidator.semanticMajorVersion(of: "2.10.3"), 2)
        XCTAssertEqual(ParticipantBundleValidator.semanticMajorVersion(of: "2.1.0-beta.1+build.5"), 2)
        for invalid in ["2", ".2", "2.0", "2..0", "02.0.0", "2.0.0.1", "2.0.0-", "2.0.0+", "v2.0.0", "2.a.0", ""] {
            XCTAssertNil(ParticipantBundleValidator.semanticMajorVersion(of: invalid), invalid)
        }
    }

    func testNonSemanticSchemaVersionIsRejected() {
        XCTAssertThrowsError(try validate(BundleFixtures.bundleObject(schemaVersion: "2"))) {
            XCTAssertEqual($0 as? ParticipantBundleError, .unsupportedSchema("2"))
        }
    }
}

using System.Security.Cryptography;
using System.Text;
using AdminApi.Controllers;
using AdminApi.Data;
using AdminApi.Dto;
using AdminApi.Models;
using AdminApi.Services.MapValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AdminApi.Tests;

public sealed class MapDatasetDraftsControllerTests
{
    private const string EmptyDraft = "{\"type\":\"FeatureCollection\",\"nexus\":{\"schema_version\":\"1.0.0\",\"floors\":[]},\"features\":[]}";
    private const string FormattedDraft = """
        {
          "type": "FeatureCollection",
          "nexus": { "schema_version": "1.0.0", "floors": [] },
          "features": []
        }
        """;

    private static string Checksum(string payload) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(payload))).ToLowerInvariant();

    private static AdminDbContext Context(SqliteConnection connection) => new(
        new DbContextOptionsBuilder<AdminDbContext>().UseSqlite(connection).Options);

    private static MapDatasetDraftsController Controller(AdminDbContext db) =>
        new(db, new MapDatasetValidator());

    [Fact]
    public void ValidateDraft_ReturnsStructuredErrorsWithoutPublicationApproval()
    {
        using var connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();
        using var db = Context(connection);
        var result = Controller(db).ValidateDraft(new() { Payload = "{" }, CancellationToken.None);

        var response = Assert.IsType<DatasetValidationResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);
        Assert.False(response.IsValid);
        Assert.False(response.CanPublish);
        Assert.Contains(response.Errors, error => error.Code == "invalid_json");
    }

    [Fact]
    public async Task CreateDraft_AssignsNextVersionAndChecksumWithoutRewritingPayload()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.EnsureCreatedAsync();
        db.MapDatasets.Add(new MapDataset
        {
            Version = 7,
            Status = MapDatasetStatus.Archived,
            Payload = EmptyDraft,
            Checksum = Checksum(EmptyDraft),
            PublishedAt = DateTimeOffset.Parse("2026-09-20T00:00:00Z")
        });
        await db.SaveChangesAsync();

        var result = await Controller(db).CreateDraft(new() { Payload = FormattedDraft }, CancellationToken.None);

        var response = Assert.IsType<MapDatasetDraftResponse>(Assert.IsType<ObjectResult>(result.Result).Value);
        Assert.Equal(201, Assert.IsType<ObjectResult>(result.Result).StatusCode);
        Assert.Equal(8, response.Version);
        Assert.Equal(MapDatasetStatus.Draft, response.Status);
        Assert.Equal(FormattedDraft, response.Payload);
        Assert.Equal(Checksum(FormattedDraft), response.Checksum);
        Assert.Null(response.PublishedAt);
        var saved = await db.MapDatasets.SingleAsync(dataset => dataset.Id == response.Id);
        Assert.Equal(FormattedDraft, saved.Payload);
        Assert.Equal(response.Checksum, saved.Checksum);
    }

    [Fact]
    public async Task CreateDraft_RejectsInvalidPayloadWithoutSaving()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.EnsureCreatedAsync();

        var result = await Controller(db).CreateDraft(new() { Payload = "not-json" }, CancellationToken.None);

        var response = Assert.IsType<DatasetValidationResponse>(Assert.IsType<UnprocessableEntityObjectResult>(result.Result).Value);
        Assert.False(response.IsValid);
        Assert.Contains(response.Errors, error => error.Code == "invalid_json");
        Assert.Empty(await db.MapDatasets.ToListAsync());
    }

    [Fact]
    public async Task CreateDraft_ReturnsConflictWhenVersionIsExhausted()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.EnsureCreatedAsync();
        db.MapDatasets.Add(new MapDataset
        {
            Version = long.MaxValue,
            Payload = EmptyDraft,
            Checksum = Checksum(EmptyDraft)
        });
        await db.SaveChangesAsync();

        var result = await Controller(db).CreateDraft(new() { Payload = EmptyDraft }, CancellationToken.None);

        var conflict = Assert.IsType<ObjectResult>(result.Result);
        Assert.Equal(409, conflict.StatusCode);
        Assert.Single(await db.MapDatasets.ToListAsync());
    }

    [Fact]
    public async Task UpdateDraft_PreservesVersionAndRecomputesChecksum()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.EnsureCreatedAsync();
        var draft = new MapDataset
        {
            Version = 3,
            Payload = EmptyDraft,
            Checksum = Checksum(EmptyDraft)
        };
        db.MapDatasets.Add(draft);
        await db.SaveChangesAsync();

        var result = await Controller(db).UpdateDraft(draft.Id, new() { Payload = FormattedDraft }, CancellationToken.None);

        var response = Assert.IsType<MapDatasetDraftResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);
        Assert.Equal(3, response.Version);
        Assert.Equal(FormattedDraft, response.Payload);
        Assert.Equal(Checksum(FormattedDraft), response.Checksum);
        Assert.Equal(MapDatasetStatus.Draft, response.Status);
    }

    [Fact]
    public async Task UpdateDraft_RejectsNonDraftWithoutMutation()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.EnsureCreatedAsync();
        var published = new MapDataset
        {
            Version = 4,
            Status = MapDatasetStatus.Published,
            Payload = EmptyDraft,
            Checksum = Checksum(EmptyDraft),
            PublishedAt = DateTimeOffset.Parse("2026-09-20T00:00:00Z")
        };
        db.MapDatasets.Add(published);
        await db.SaveChangesAsync();

        var result = await Controller(db).UpdateDraft(published.Id, new() { Payload = FormattedDraft }, CancellationToken.None);

        var conflict = Assert.IsType<ObjectResult>(result.Result);
        Assert.Equal(409, conflict.StatusCode);
        Assert.Equal(EmptyDraft, (await db.MapDatasets.SingleAsync()).Payload);
    }

    [Fact]
    public async Task UpdateDraft_InvalidPayloadDoesNotMutateStoredDraft()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.EnsureCreatedAsync();
        var draft = new MapDataset
        {
            Version = 5,
            Payload = EmptyDraft,
            Checksum = Checksum(EmptyDraft)
        };
        db.MapDatasets.Add(draft);
        await db.SaveChangesAsync();

        var result = await Controller(db).UpdateDraft(draft.Id, new() { Payload = "{" }, CancellationToken.None);

        Assert.IsType<UnprocessableEntityObjectResult>(result.Result);
        Assert.Equal(EmptyDraft, (await db.MapDatasets.SingleAsync()).Payload);
        Assert.Equal(Checksum(EmptyDraft), (await db.MapDatasets.SingleAsync()).Checksum);
    }

    [Fact]
    public async Task UpdateDraft_ReturnsNotFoundForUnknownDataset()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.EnsureCreatedAsync();

        var result = await Controller(db).UpdateDraft(Guid.NewGuid(), new() { Payload = EmptyDraft }, CancellationToken.None);

        Assert.IsType<NotFoundResult>(result.Result);
    }
}

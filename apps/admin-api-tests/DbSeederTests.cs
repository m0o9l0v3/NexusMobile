using AdminApi.Data;
using AdminApi.Models;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AdminApi.Tests;

public sealed class DbSeederTests
{
    [Theory]
    [InlineData(MapDatasetStatus.Draft)]
    [InlineData(MapDatasetStatus.Published)]
    [InlineData(MapDatasetStatus.Archived)]
    public async Task SeedAsync_PreservesExistingSqliteDataOnRepeat(string status)
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = new AdminDbContext(
            new DbContextOptionsBuilder<AdminDbContext>().UseSqlite(connection).Options);
        var seeder = new DbSeeder(db);

        await seeder.SeedAsync();
        var existingId = Guid.NewGuid();
        db.Spots.Add(new Spot
        {
            Id = existingId,
            Code = "preserve-on-reseed",
            Name = "Preserved spot",
            Description = "Existing data must survive application startup.",
            IsPublished = true,
            UpdatedAt = DateTimeOffset.UtcNow
        });
        const string payload = "{\"type\":\"FeatureCollection\",\"nexus\":{\"schema_version\":\"1.0.0\",\"floors\":[]},\"features\":[]}";
        var dataset = new MapDataset
        {
            Version = 1,
            Status = status,
            Payload = payload,
            Checksum = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(payload))).ToLowerInvariant(),
            PublishedAt = status == MapDatasetStatus.Draft ? null : DateTimeOffset.Parse("2026-09-19T00:00:00Z")
        };
        db.MapDatasets.Add(dataset);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        // A new context represents application startup against the same database.
        await using var restarted = new AdminDbContext(
            new DbContextOptionsBuilder<AdminDbContext>().UseSqlite(connection).Options);
        await new DbSeeder(restarted).SeedAsync();

        Assert.True(await restarted.Spots.AnyAsync(spot => spot.Id == existingId));
        var saved = await restarted.MapDatasets.SingleAsync();
        Assert.Equal(dataset.Id, saved.Id);
        Assert.Equal(dataset.Version, saved.Version);
        Assert.Equal(dataset.Status, saved.Status);
        Assert.Equal(dataset.Payload, saved.Payload);
        Assert.Equal(dataset.Checksum, saved.Checksum);
        Assert.Equal(dataset.PublishedAt, saved.PublishedAt);
    }
}

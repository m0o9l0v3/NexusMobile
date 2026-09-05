using System.Security.Cryptography;
using System.Text;
using AdminApi.Data;
using AdminApi.Migrations;
using AdminApi.Models;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;
using Xunit;

namespace AdminApi.Tests;

public sealed class MapDatasetTests
{
    private const string Payload = "{\"type\":\"FeatureCollection\",\"nexus\":{\"schema_version\":\"1.0.0\",\"floors\":[]},\"features\":[]}";
    private const string MigrationId = "20260905120000_AddMapDatasets";

    private static MapDataset Dataset(long version = 1) => new()
    {
        Version = version,
        Payload = Payload,
        Checksum = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Payload))).ToLowerInvariant()
    };

    private static AdminDbContext Context(SqliteConnection connection) => new(
        new DbContextOptionsBuilder<AdminDbContext>().UseSqlite(connection).Options);

    [Theory]
    [InlineData(MapDatasetStatus.Draft, false)]
    [InlineData(MapDatasetStatus.Published, true)]
    [InlineData(MapDatasetStatus.Archived, true)]
    public async Task Dataset_RoundTripsWithoutRewritingPayload(string status, bool published)
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.MigrateAsync();
        var dataset = Dataset();
        dataset.Status = status;
        dataset.PublishedAt = published ? DateTimeOffset.Parse("2026-09-05T12:00:00+00:00") : null;
        db.MapDatasets.Add(dataset);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var saved = await db.MapDatasets.SingleAsync(item => item.Id == dataset.Id);
        Assert.Equal(1, saved.Version);
        Assert.Equal(status, saved.Status);
        Assert.Equal(Payload, saved.Payload);
        Assert.Equal(dataset.Checksum, saved.Checksum);
        Assert.Equal(dataset.PublishedAt, saved.PublishedAt);
    }

    [Fact]
    public async Task Dataset_RejectsDuplicateVersion()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.MigrateAsync();
        db.MapDatasets.Add(Dataset());
        await db.SaveChangesAsync();
        db.MapDatasets.Add(Dataset());
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }

    [Theory]
    [InlineData(0, "draft", 64)]
    [InlineData(-1, "draft", 64)]
    [InlineData(1, "invalid", 64)]
    [InlineData(1, "Draft", 64)]
    [InlineData(1, "draft", 0)]
    [InlineData(1, "draft", 63)]
    public async Task Dataset_RejectsInvalidStorageMetadata(long version, string status, int checksumLength)
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        await db.Database.MigrateAsync();
        var dataset = Dataset(version);
        dataset.Status = status;
        dataset.Checksum = new string('a', checksumLength);
        db.MapDatasets.Add(dataset);
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }

    [Fact]
    public async Task Migration_IsDiscoverableAndPreservesExistingDataOnRepeat()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = Context(connection);
        // Fixture represents a pre-existing database, without modifying a real database.
        await db.Database.ExecuteSqlRawAsync("CREATE TABLE existing_data (id INTEGER PRIMARY KEY, value TEXT NOT NULL)");
        await db.Database.ExecuteSqlRawAsync("INSERT INTO existing_data VALUES (1, 'preserve')");
        Assert.Contains(MigrationId, db.Database.GetMigrations());
        await db.Database.MigrateAsync();
        db.MapDatasets.Add(Dataset());
        await db.SaveChangesAsync();
        await db.Database.MigrateAsync();
        Assert.Equal(1, await db.MapDatasets.CountAsync());
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT value FROM existing_data WHERE id = 1";
        Assert.Equal("preserve", await command.ExecuteScalarAsync());
    }

    [Fact]
    public void Migration_OnlyAddsDatasetTableAndIndex()
    {
        var migration = new AddMapDatasets { ActiveProvider = "Npgsql.EntityFrameworkCore.PostgreSQL" };
        Assert.Collection(migration.UpOperations,
            operation => Assert.Equal("map_datasets", Assert.IsType<CreateTableOperation>(operation).Name),
            operation => Assert.Equal("map_datasets", Assert.IsType<CreateIndexOperation>(operation).Table));
    }

    [Fact]
    public void Migration_GeneratesPostgreSqlStorageTypes()
    {
        using var db = new AdminDbContext(new DbContextOptionsBuilder<AdminDbContext>()
            .UseNpgsql("Host=localhost;Database=unused;Username=unused;Password=unused").Options);
        var sql = db.GetService<IMigrator>().GenerateScript(toMigration: MigrationId);
        Assert.Contains("CREATE TABLE map_datasets", sql);
        Assert.Contains("version bigint NOT NULL", sql);
        Assert.Contains("payload text NOT NULL", sql);
        Assert.Contains("published_at timestamp with time zone", sql);
        Assert.DoesNotContain("DROP TABLE", sql);
        Assert.DoesNotContain("ALTER TABLE spots", sql);
    }
}

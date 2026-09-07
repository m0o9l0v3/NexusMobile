using AdminApi.Data;
using AdminApi.Models;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AdminApi.Tests;

public sealed class DbSeederTests
{
    [Fact]
    public async Task SeedAsync_PreservesExistingSqliteDataOnRepeat()
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
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        await seeder.SeedAsync();

        Assert.True(await db.Spots.AnyAsync(spot => spot.Id == existingId));
    }
}

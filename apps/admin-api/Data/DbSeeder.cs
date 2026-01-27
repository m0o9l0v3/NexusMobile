using AdminApi.Models;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Data;

public sealed class DbSeeder
{
    private readonly AdminDbContext _dbContext;

    public DbSeeder(AdminDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task SeedAsync()
    {
        await _dbContext.Database.MigrateAsync();

        if (!await _dbContext.Spots.AnyAsync())
        {
            _dbContext.Spots.AddRange(new Spot
            {
                Id = Guid.NewGuid(),
                Code = "SPOT-001",
                Name = "Main Hall",
                Description = "Welcome spot for visitors.",
                Tags = new[] { "welcome", "info" },
                Lat = 35.681236,
                Lng = 139.767125,
                IsPublished = true,
                UpdatedAt = DateTimeOffset.UtcNow
            }, new Spot
            {
                Id = Guid.NewGuid(),
                Code = "SPOT-002",
                Name = "Library",
                Description = "Quiet study area.",
                Tags = new[] { "study" },
                IsPublished = false,
                UpdatedAt = DateTimeOffset.UtcNow
            });
        }

        var spotSeeds = new[]
        {
            new { Code = "pc_room", Name = "PC室", Description = "トータルモビリティ工学科" },
            new { Code = "ctc", Name = "CTC", Description = "CA/GS科" },
            new { Code = "vehicle_hangar", Name = "車両格納庫", Description = "グランドハンドリング科" },
            new { Code = "basic_training_room", Name = "基礎訓練室", Description = "整備科" },
            new { Code = "hangar", Name = "ハンガー", Description = "整備科" }
        };

        foreach (var seed in spotSeeds)
        {
            if (!await _dbContext.Spots.AnyAsync(spot => spot.Code == seed.Code))
            {
                _dbContext.Spots.Add(new Spot
                {
                    Id = Guid.NewGuid(),
                    Code = seed.Code,
                    Name = seed.Name,
                    Description = seed.Description,
                    IsPublished = true,
                    UpdatedAt = DateTimeOffset.UtcNow
                });
            }
        }

        if (!await _dbContext.Events.AnyAsync())
        {
            _dbContext.Events.Add(new Event
            {
                Id = Guid.NewGuid(),
                Title = "Campus Tour",
                Description = "Guided tour around the campus.",
                StartsAt = DateTimeOffset.UtcNow.AddDays(1).AddHours(1),
                EndsAt = DateTimeOffset.UtcNow.AddDays(1).AddHours(3),
                LocationText = "Main Entrance",
                IsPublished = true
            });
        }

        if (!await _dbContext.OcDays.AnyAsync())
        {
            _dbContext.OcDays.Add(new OcDay
            {
                Id = Guid.NewGuid(),
                Date = DateOnly.FromDateTime(DateTime.UtcNow.Date),
                Name = "Spring Open Campus"
            });
        }

        await _dbContext.SaveChangesAsync();
    }
}

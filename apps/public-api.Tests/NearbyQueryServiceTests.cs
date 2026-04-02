using AdminApi.Data;
using AdminApi.Models;
using Microsoft.EntityFrameworkCore;
using PublicApi.Services;
using Xunit;

namespace PublicApi.Tests;

public sealed class NearbyQueryServiceTests
{
    [Fact]
    public async Task QueryAsync_FiltersAndSortsByDistance()
    {
        await using var context = BuildContext();
        context.Spots.AddRange(
            new Spot
            {
                Id = Guid.NewGuid(),
                Code = "SPOT001",
                Name = "Near Spot",
                Description = "near",
                Lat = 35.6804,
                Lng = 139.7690,
                IsPublished = true,
                UpdatedAt = DateTimeOffset.UtcNow
            },
            new Spot
            {
                Id = Guid.NewGuid(),
                Code = "SPOT002",
                Name = "Far Spot",
                Description = "far",
                Lat = 35.7000,
                Lng = 139.9000,
                IsPublished = true,
                UpdatedAt = DateTimeOffset.UtcNow
            },
            new Spot
            {
                Id = Guid.NewGuid(),
                Code = "SPOT003",
                Name = "Hidden Spot",
                Description = "hidden",
                Lat = 35.6806,
                Lng = 139.7688,
                IsPublished = false,
                UpdatedAt = DateTimeOffset.UtcNow
            });

        await context.SaveChangesAsync();

        var service = new NearbyQueryService(context);
        var result = await service.QueryAsync(35.681236, 139.767125, 2000d, 20, CancellationToken.None);

        Assert.Single(result);
        Assert.Equal("SPOT001", result[0].Code);
    }

    [Fact]
    public async Task QueryAsync_LimitsToMaxResults()
    {
        await using var context = BuildContext();
        var spots = Enumerable.Range(1, 25)
            .Select(index => new Spot
            {
                Id = Guid.NewGuid(),
                Code = $"SPOT{index:D3}",
                Name = $"Spot {index}",
                Description = "desc",
                Lat = 35.68 + (index * 0.0001),
                Lng = 139.76 + (index * 0.0001),
                IsPublished = true,
                UpdatedAt = DateTimeOffset.UtcNow
            })
            .ToArray();
        context.Spots.AddRange(spots);
        await context.SaveChangesAsync();

        var service = new NearbyQueryService(context);
        var result = await service.QueryAsync(35.68, 139.76, 20000d, 20, CancellationToken.None);

        Assert.Equal(20, result.Count);
        Assert.True(result.Zip(result.Skip(1), (a, b) => a.DistanceMeters <= b.DistanceMeters).All(isOrdered => isOrdered));
    }

    private static AdminDbContext BuildContext()
    {
        var options = new DbContextOptionsBuilder<AdminDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AdminDbContext(options);
    }
}


using AdminApi.Data;
using AdminApi.Models;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.EntityFrameworkCore;
using PublicApi.Controllers;
using PublicApi.Dto;
using Xunit;

namespace PublicApi.Tests;

public sealed class SpotsControllerTests
{
    [Fact]
    public async Task Get_ReturnsOnlyPublishedSpotsWithListDtoMapping()
    {
        await using var context = BuildContext();
        var publishedWithoutTagsId = Guid.NewGuid();
        var publishedWithAssetsId = Guid.NewGuid();

        context.Spots.AddRange(
            new Spot
            {
                Id = publishedWithAssetsId,
                Code = "LIBRARY",
                Name = "Library",
                Description = "Campus library",
                ContentAssets = "{\"images\":[{\"url\":\"https://example.com/images/library.jpg\"}]}",
                Lat = 35.681236,
                Lng = 139.767125,
                IsPublished = true,
                Tags = new[] { "study", "facility" },
                ModelRef = "https://example.com/models/library.usdz",
                UpdatedAt = DateTimeOffset.UtcNow
            },
            new Spot
            {
                Id = publishedWithoutTagsId,
                Code = "CAFETERIA",
                Name = "Cafeteria",
                Description = "Campus cafeteria",
                IsPublished = true,
                Tags = null,
                UpdatedAt = DateTimeOffset.UtcNow
            },
            new Spot
            {
                Id = Guid.NewGuid(),
                Code = "HIDDEN",
                Name = "Hidden Spot",
                Description = "Unpublished",
                ContentAssets = "https://example.com/hidden.jpg",
                IsPublished = false,
                Tags = new[] { "private" },
                UpdatedAt = DateTimeOffset.UtcNow
            });

        await context.SaveChangesAsync();

        var controller = new SpotsController(context);
        var result = await controller.Get(CancellationToken.None);

        var ok = Assert.IsType<Ok<SpotResponse[]>>(result);
        var spots = Assert.IsType<SpotResponse[]>(ok.Value);
        Assert.Equal(new[] { "CAFETERIA", "LIBRARY" }, spots.Select(spot => spot.Code).ToArray());
        Assert.All(spots, spot => Assert.True(spot.IsPublished));
        Assert.DoesNotContain(spots, spot => spot.Code == "HIDDEN");

        var spotWithoutTags = Assert.Single(spots, spot => spot.Id == publishedWithoutTagsId);
        Assert.Empty(spotWithoutTags.Tags);
        Assert.Null(spotWithoutTags.ImageUrl);
        Assert.Null(spotWithoutTags.ArModelUrl);

        var spotWithAssets = Assert.Single(spots, spot => spot.Id == publishedWithAssetsId);
        Assert.Equal("https://example.com/images/library.jpg", spotWithAssets.ImageUrl);
        Assert.Equal("https://example.com/models/library.usdz", spotWithAssets.ArModelUrl);
        Assert.Equal(new[] { "study", "facility" }, spotWithAssets.Tags);
        Assert.Equal(35.681236, spotWithAssets.Latitude);
        Assert.Equal(139.767125, spotWithAssets.Longitude);
    }

    private static AdminDbContext BuildContext()
    {
        var options = new DbContextOptionsBuilder<AdminDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AdminDbContext(options);
    }
}

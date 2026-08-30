using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.Extensions.FileProviders;
using PublicApi.Controllers;
using PublicApi.Dto;
using PublicApi.Services.Navigation;
using Xunit;

namespace PublicApi.Tests;

public sealed class NavigationControllerTests
{
    private readonly NavigationController _controller = new(BuildStore());

    [Fact]
    public void GetFloors_ReturnsSeededFloors()
    {
        var result = _controller.GetFloors();

        var ok = Assert.IsType<Ok<IReadOnlyList<FloorMapDto>>>(result);
        var floors = Assert.IsAssignableFrom<IReadOnlyList<FloorMapDto>>(ok.Value);
        Assert.Contains(floors, floor => floor.Id == "1f");
        Assert.Contains(floors, floor => floor.Id == "2f");
    }

    [Fact]
    public void GetSpotById_ReturnsCaseInsensitiveMatch()
    {
        var result = _controller.GetSpotById("ENTRANCE");

        var ok = Assert.IsType<Ok<SpotDto>>(result);
        Assert.Equal("entrance", ok.Value?.Id);
    }

    [Fact]
    public void GetSpotById_ReturnsNotFoundForUnknownId()
    {
        var result = _controller.GetSpotById("unknown");

        Assert.IsType<NotFound>(result);
    }

    [Fact]
    public void GetRoutes_ReturnsOnlyMatchingRoutes()
    {
        var result = _controller.GetRoutes("entrance", "room-a");

        var ok = Assert.IsType<Ok<IEnumerable<RouteDto>>>(result);
        var route = Assert.Single(Assert.IsAssignableFrom<IEnumerable<RouteDto>>(ok.Value));
        Assert.Equal("entrance-to-room-a", route.Id);
    }

    [Theory]
    [InlineData(null, "room-a")]
    [InlineData("", "room-a")]
    [InlineData("entrance", null)]
    [InlineData("entrance", " ")]
    public void GetRoutes_ReturnsBadRequestWhenEndpointIsMissing(string? from, string? to)
    {
        var result = _controller.GetRoutes(from, to);

        var problem = Assert.IsType<ProblemHttpResult>(result);
        Assert.Equal(StatusCodes.Status400BadRequest, problem.StatusCode);
        Assert.Equal("from and to are required.", problem.ProblemDetails.Detail);
    }

    private static NavigationDataStore BuildStore()
    {
        var repositoryRoot = FindRepositoryRoot();
        var environment = new TestWebHostEnvironment
        {
            ContentRootPath = Path.Combine(repositoryRoot, "apps", "public-api")
        };

        return new NavigationDataStore(environment);
    }

    private static string FindRepositoryRoot()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "Nexus.sln")))
            {
                return directory.FullName;
            }
        }

        throw new DirectoryNotFoundException("Nexus.sln が見つかりません。");
    }

    private sealed class TestWebHostEnvironment : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "PublicApi.Tests";
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
        public string WebRootPath { get; set; } = string.Empty;
        public string EnvironmentName { get; set; } = "Testing";
        public string ContentRootPath { get; set; } = string.Empty;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}

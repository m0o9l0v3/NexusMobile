using System.Text.Json;
using PublicApi.Dto;

namespace PublicApi.Services.Navigation;

public sealed class NavigationDataStore
{
    private readonly IReadOnlyList<SpotDto> _spots;
    private readonly IReadOnlyList<FloorMapDto> _floors;
    private readonly IReadOnlyList<RouteDto> _routes;

    public NavigationDataStore(IWebHostEnvironment env)
    {
        var path = Path.Combine(env.ContentRootPath, "Data", "phase1-navigation.json");
        using var stream = File.OpenRead(path);
        var data = JsonSerializer.Deserialize<NavigationSeed>(stream, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException("Navigation seed not found.");
        _spots = data.Spots;
        _floors = data.Floors;
        _routes = data.Routes;
    }

    public IReadOnlyList<SpotDto> Spots => _spots;
    public IReadOnlyList<FloorMapDto> Floors => _floors;
    public IReadOnlyList<RouteDto> Routes => _routes;

    private sealed record NavigationSeed(
        IReadOnlyList<FloorMapDto> Floors,
        IReadOnlyList<SpotDto> Spots,
        IReadOnlyList<RouteDto> Routes);
}

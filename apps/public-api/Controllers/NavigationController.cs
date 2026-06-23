using Microsoft.AspNetCore.Mvc;
using PublicApi.Dto;
using PublicApi.Services.Navigation;

namespace PublicApi.Controllers;

[ApiController]
[Route("api")]
public sealed class NavigationController : ControllerBase
{
    private readonly NavigationDataStore _store;

    public NavigationController(NavigationDataStore store)
    {
        _store = store;
    }

    [HttpGet("spots")]
    [ProducesResponseType<IEnumerable<SpotDto>>(StatusCodes.Status200OK)]
    public IResult GetSpots() => Results.Ok(_store.Spots);

    [HttpGet("spots/{id}")]
    [ProducesResponseType<SpotDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public IResult GetSpotById(string id)
    {
        var spot = _store.Spots.FirstOrDefault(s => s.Id.Equals(id, StringComparison.OrdinalIgnoreCase));
        return spot is null ? Results.NotFound() : Results.Ok(spot);
    }

    [HttpGet("floors")]
    [ProducesResponseType<IEnumerable<FloorMapDto>>(StatusCodes.Status200OK)]
    public IResult GetFloors() => Results.Ok(_store.Floors);

    [HttpGet("routes")]
    [ProducesResponseType<IEnumerable<RouteDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public IResult GetRoutes([FromQuery] string? from, [FromQuery] string? to)
    {
        if (string.IsNullOrWhiteSpace(from) || string.IsNullOrWhiteSpace(to))
        {
            return Results.Problem(statusCode: 400, title: "Invalid request", detail: "from and to are required.");
        }

        var routes = _store.Routes.Where(r =>
            r.FromSpotId.Equals(from, StringComparison.OrdinalIgnoreCase)
            && r.ToSpotId.Equals(to, StringComparison.OrdinalIgnoreCase));

        return Results.Ok(routes);
    }
}

using Microsoft.AspNetCore.Mvc;
using PublicApi.Dto;
using PublicApi.Services;

namespace PublicApi.Controllers;

[ApiController]
[Route("api")]
public sealed class NearbyController : ControllerBase
{
    private readonly NearbyQueryService _nearbyQueryService;

    public NearbyController(NearbyQueryService nearbyQueryService)
    {
        _nearbyQueryService = nearbyQueryService;
    }

    /// <summary>
    /// 指定座標の近傍にある公開スポットを距離順で返します。
    /// </summary>
    /// <param name="lat">緯度。</param>
    /// <param name="lng">経度。</param>
    /// <param name="radius">検索半径 (メートル)。</param>
    /// <param name="cancellationToken">キャンセル トークン。</param>
    /// <returns>近傍スポット一覧。</returns>
    [HttpGet("nearby")]
    [ProducesResponseType<IEnumerable<NearbySpotResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IResult> GetNearby([FromQuery] double? lat, [FromQuery] double? lng, [FromQuery] double radius = 500, CancellationToken cancellationToken = default)
    {
        if (!lat.HasValue || !lng.HasValue)
        {
            return Results.Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Invalid request",
                detail: "lat and lng are required.");
        }

        if (lat < -90 || lat > 90 || lng < -180 || lng > 180)
        {
            return Results.Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Invalid request",
                detail: "lat or lng is out of range.");
        }

        if (radius <= 0)
        {
            return Results.Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Invalid request",
                detail: "radius must be greater than 0.");
        }

        var response = await _nearbyQueryService.QueryAsync(
            lat.Value,
            lng.Value,
            radius,
            20,
            cancellationToken);

        return Results.Ok(response);
    }
}

using AdminApi.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PublicApi.Dto;
using PublicApi.Helpers;

namespace PublicApi.Controllers;

[ApiController]
[Route("api/events")]
public sealed class EventsController : ControllerBase
{
    private readonly AdminDbContext _dbContext;

    public EventsController(AdminDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    /// <summary>
    /// 当日 (JST) の公開イベントを取得します。
    /// </summary>
    /// <param name="cancellationToken">キャンセル トークン。</param>
    /// <returns>イベント一覧。</returns>
    [HttpGet("today")]
    [ProducesResponseType<IEnumerable<TodayEventResponse>>(StatusCodes.Status200OK)]
    public async Task<IResult> GetToday(CancellationToken cancellationToken)
    {
        var todayJst = JstTimeHelper.GetCurrentJstDate(DateTimeOffset.UtcNow);
        var (startUtc, endUtc) = JstTimeHelper.GetUtcRangeForJstDay(todayJst);

        var events = await _dbContext.Events.AsNoTracking()
            .Where(eventItem => eventItem.IsPublished && eventItem.StartsAt >= startUtc && eventItem.StartsAt < endUtc)
            .OrderBy(eventItem => eventItem.StartsAt)
            .ToListAsync(cancellationToken);

        var publishedSpots = await _dbContext.Spots.AsNoTracking()
            .Where(spot => spot.IsPublished)
            .Select(spot => new SpotCandidate(spot.Code, spot.Lat, spot.Lng))
            .ToListAsync(cancellationToken);

        var spotByCode = publishedSpots
            .ToDictionary(spot => spot.Code, spot => spot.Code, StringComparer.OrdinalIgnoreCase);

        var payload = events.Select(eventItem =>
        {
            var startJst = JstTimeHelper.ToJst(eventItem.StartsAt);
            var endJst = JstTimeHelper.ToJst(eventItem.EndsAt);
            var spotCode = ResolveSpotCode(eventItem.LocationText, eventItem.Lat, eventItem.Lng, spotByCode, publishedSpots);

            return new TodayEventResponse(
                eventItem.Id,
                eventItem.Title,
                eventItem.Description,
                startJst.ToString("HH:mm"),
                endJst.ToString("HH:mm"),
                eventItem.LocationText,
                spotCode,
                null,
                Array.Empty<string>());
        });

        return Results.Ok(payload);
    }

    private static string? ResolveSpotCode(
        string? locationText,
        double? eventLat,
        double? eventLng,
        IReadOnlyDictionary<string, string> spotByCode,
        IEnumerable<SpotCandidate> publishedSpots)
    {
        if (!string.IsNullOrWhiteSpace(locationText) &&
            spotByCode.TryGetValue(locationText.Trim(), out var matchedCode))
        {
            return matchedCode;
        }

        if (!eventLat.HasValue || !eventLng.HasValue)
        {
            return null;
        }

        var nearest = publishedSpots
            .Where(spot => spot.Lat.HasValue && spot.Lng.HasValue)
            .Select(spot => new
            {
                spot.Code,
                Distance = DistanceHelper.CalculateMeters(eventLat.Value, eventLng.Value, spot.Lat!.Value, spot.Lng!.Value)
            })
            .OrderBy(item => item.Distance)
            .FirstOrDefault();

        if (nearest is null || nearest.Distance > 30d)
        {
            return null;
        }

        return nearest.Code;
    }

    private sealed record SpotCandidate(string Code, double? Lat, double? Lng);
}

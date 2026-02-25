using AdminApi.Data;
using Microsoft.EntityFrameworkCore;
using PublicApi.Dto;
using PublicApi.Helpers;

namespace PublicApi.Services;

public sealed class NearbyQueryService
{
    private readonly AdminDbContext _dbContext;

    public NearbyQueryService(AdminDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<IReadOnlyList<NearbySpotResponse>> QueryAsync(
        double lat,
        double lng,
        double radiusMeters,
        int maxResults,
        CancellationToken cancellationToken)
    {
        var spots = await _dbContext.Spots.AsNoTracking()
            .Where(spot => spot.IsPublished && spot.Lat.HasValue && spot.Lng.HasValue)
            .Select(spot => new
            {
                spot.Id,
                spot.Code,
                spot.Name,
                Lat = spot.Lat!.Value,
                Lng = spot.Lng!.Value,
                spot.Tags
            })
            .ToListAsync(cancellationToken);

        var nearby = spots
            .Select(spot => new
            {
                spot.Id,
                spot.Code,
                spot.Name,
                spot.Lat,
                spot.Lng,
                spot.Tags,
                Distance = DistanceHelper.CalculateMeters(lat, lng, spot.Lat, spot.Lng)
            })
            .Where(item => item.Distance <= radiusMeters)
            .OrderBy(item => item.Distance)
            .Take(maxResults)
            .Select(item => new NearbySpotResponse(
                item.Id,
                item.Code,
                item.Name,
                Math.Round(item.Distance, 1),
                item.Lat,
                item.Lng,
                item.Tags ?? Array.Empty<string>()))
            .ToList();

        return nearby;
    }
}


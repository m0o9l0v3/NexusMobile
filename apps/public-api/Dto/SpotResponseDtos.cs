namespace PublicApi.Dto;

public sealed record SpotResponse(
    Guid Id,
    string Code,
    string Name,
    string Description,
    string? ImageUrl,
    double? Latitude,
    double? Longitude,
    bool IsPublished,
    string[] Tags,
    string? ArModelUrl);

public sealed record SpotByCodeResponse(
    Guid Id,
    string Code,
    string Name,
    string Description,
    string? ImageUrl,
    double? Latitude,
    double? Longitude,
    bool IsPublished,
    string[] Tags,
    string? ArModelUrl);

public sealed record NearbySpotResponse(
    Guid Id,
    string Code,
    string Name,
    double DistanceMeters,
    double Latitude,
    double Longitude,
    string[] Tags);


namespace PublicApi.Dto;

public sealed record SpotDto(
    string Id,
    string Name,
    string? Description,
    string Category,
    string Floor,
    double X,
    double Y,
    string[]? Tags);

public sealed record FloorMapDto(
    string Id,
    string Name,
    string? ImageUrl,
    string? SvgPath,
    double Width,
    double Height);

public sealed record RoutePointDto(double X, double Y);

public sealed record RouteDto(
    string Id,
    string FromSpotId,
    string ToSpotId,
    string Floor,
    IReadOnlyList<RoutePointDto> Points,
    int? EstimatedMinutes,
    double? DistanceMeters);

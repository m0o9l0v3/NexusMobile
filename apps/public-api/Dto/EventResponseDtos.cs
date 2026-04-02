namespace PublicApi.Dto;

public sealed record TodayEventResponse(
    Guid Id,
    string Title,
    string? Description,
    string StartTime,
    string EndTime,
    string? Location,
    string? SpotCode,
    string? ImageUrl,
    string[] Tags);


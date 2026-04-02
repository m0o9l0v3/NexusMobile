using System.Text.Json;
using System.ComponentModel.DataAnnotations;

namespace PublicApi.Dto;

public sealed record CreateLogRequest(
    [property: Required]
    string SessionId,
    [property: Required]
    string EventType,
    string? SpotCode,
    JsonElement? Payload,
    DateTimeOffset? OccurredAt,
    double? LocationLat,
    double? LocationLng,
    double? LocationAccuracy);

public sealed record CreateLogBatchRequest(
    IReadOnlyList<CreateLogRequest> Logs);

public sealed record AcceptedResponse(bool Accepted);

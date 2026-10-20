using System.Text.Json;
using System.ComponentModel.DataAnnotations;

namespace PublicApi.Dto;

public sealed record CreateLogRequest(
    [param: Required]
    string SessionId,
    [param: Required]
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

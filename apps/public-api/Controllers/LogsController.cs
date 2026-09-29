using AdminApi.Options;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using PublicApi.Dto;
using PublicApi.Infrastructure;
using PublicApi.Services;

namespace PublicApi.Controllers;

[ApiController]
[Route("api/logs")]
public sealed class LogsController : ControllerBase
{
    private static readonly HashSet<string> AllowedEventTypes = new(StringComparer.Ordinal)
    {
        "spot_view",
        "qr_scan",
        "event_tap",
        "nearby_open"
    };

    private readonly IBackgroundTaskQueue _taskQueue;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<LogsController> _logger;

    public LogsController(IBackgroundTaskQueue taskQueue, IServiceScopeFactory scopeFactory, ILogger<LogsController> logger)
    {
        _taskQueue = taskQueue;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    /// <summary>
    /// 匿名参加者ログを1件受け付けます。
    /// </summary>
    /// <param name="request">ログ情報。</param>
    /// <param name="cancellationToken">キャンセル トークン。</param>
    /// <returns>受付結果。</returns>
    [HttpPost]
    [EnableRateLimiting(RateLimitPolicies.LogIngest)]
    [ProducesResponseType<AcceptedResponse>(StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IResult> Create([FromBody] CreateLogRequest request, CancellationToken cancellationToken)
    {
        if (request is null)
        {
            return Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: "Invalid request", detail: "Request body is required.");
        }

        var validationError = Validate(request);
        if (validationError is not null)
        {
            return Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: "Invalid request", detail: validationError);
        }

        var entry = MapToQueuedEntry(request);
        await QueueEntriesAsync([entry], cancellationToken);
        return Results.Accepted(value: new AcceptedResponse(true));
    }

    /// <summary>
    /// 匿名参加者ログを最大50件まとめて受け付けます。
    /// </summary>
    /// <param name="request">ログ配列。</param>
    /// <param name="cancellationToken">キャンセル トークン。</param>
    /// <returns>受付結果。</returns>
    [HttpPost("batch")]
    [EnableRateLimiting(RateLimitPolicies.LogIngestBatch)]
    [ProducesResponseType<AcceptedResponse>(StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IResult> CreateBatch([FromBody] CreateLogBatchRequest request, CancellationToken cancellationToken)
    {
        if (request?.Logs is null || request.Logs.Count == 0)
        {
            return Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: "Invalid request", detail: "logs is required.");
        }

        if (request.Logs.Count > 50)
        {
            return Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: "Invalid request", detail: "logs must contain 50 entries or fewer.");
        }

        var entries = new List<QueuedLogEntry>(request.Logs.Count);
        foreach (var log in request.Logs)
        {
            var validationError = Validate(log);
            if (validationError is not null)
            {
                return Results.Problem(statusCode: StatusCodes.Status400BadRequest, title: "Invalid request", detail: validationError);
            }

            entries.Add(MapToQueuedEntry(log));
        }

        await QueueEntriesAsync(entries, cancellationToken);
        return Results.Accepted(value: new AcceptedResponse(true));
    }

    private async Task QueueEntriesAsync(IReadOnlyList<QueuedLogEntry> entries, CancellationToken cancellationToken)
    {
        await _taskQueue.QueueBackgroundWorkItemAsync(async workerToken =>
        {
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                var persistenceService = scope.ServiceProvider.GetRequiredService<LogPersistenceService>();
                await persistenceService.PersistAsync(entries, workerToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to persist queued public logs.");
            }
        });
    }

    private static QueuedLogEntry MapToQueuedEntry(CreateLogRequest request)
    {
        var payload = request.Payload.HasValue &&
                      request.Payload.Value.ValueKind is not System.Text.Json.JsonValueKind.Null and not System.Text.Json.JsonValueKind.Undefined
            ? request.Payload.Value.GetRawText()
            : null;

        return new QueuedLogEntry(
            request.SessionId.Trim(),
            request.EventType.Trim(),
            request.SpotCode?.Trim(),
            payload,
            request.OccurredAt,
            request.LocationLat,
            request.LocationLng,
            request.LocationAccuracy);
    }

    private static string? Validate(CreateLogRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.SessionId))
        {
            return "sessionId is required.";
        }

        if (string.IsNullOrWhiteSpace(request.EventType))
        {
            return "eventType is required.";
        }

        if (!AllowedEventTypes.Contains(request.EventType.Trim()))
        {
            return "eventType is invalid.";
        }

        if (request.LocationLat.HasValue ^ request.LocationLng.HasValue)
        {
            return "locationLat and locationLng must be provided together.";
        }

        if (request.LocationLat is < -90 or > 90)
        {
            return "locationLat is out of range.";
        }

        if (request.LocationLng is < -180 or > 180)
        {
            return "locationLng is out of range.";
        }

        if (request.LocationAccuracy is < 0)
        {
            return "locationAccuracy must be greater than or equal to 0.";
        }

        return null;
    }
}

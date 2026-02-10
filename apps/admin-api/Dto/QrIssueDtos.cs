using System.ComponentModel.DataAnnotations;

namespace AdminApi.Dto;

public sealed class QrIssueRequest
{
    public DateTimeOffset? ExpiresAt { get; set; }
}

public sealed class QrIssueResponse
{
    public Guid QrIssueId { get; set; }
    public Guid EventId { get; set; }
    public Guid TimeslotId { get; set; }
    public DateTimeOffset IssuedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }
    public string? RevokeReason { get; set; }
    public int ScanCount { get; set; }
    public DateTimeOffset? LastScannedAt { get; set; }
    public string Url { get; set; } = string.Empty;
    public TimeslotSummary? Timeslot { get; set; }
}

public sealed class TimeslotSummary
{
    public Guid TimeslotId { get; set; }
    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset EndsAt { get; set; }
}

public sealed class RevokeQrIssueRequest
{
    [MaxLength(200)]
    public string? Reason { get; set; }
}

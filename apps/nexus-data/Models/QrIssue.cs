namespace AdminApi.Models;

public sealed class QrIssue
{
    public Guid Id { get; set; }
    public Guid EventId { get; set; }
    public Event? Event { get; set; }
    public Guid TimeslotId { get; set; }
    public OpenCampusTimeslot? Timeslot { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public string PayloadSnapshotJson { get; set; } = string.Empty;
    public string IssuedByAdminId { get; set; } = string.Empty;
    public DateTimeOffset IssuedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }
    public string? RevokeReason { get; set; }
    public int ScanCount { get; set; }
    public DateTimeOffset? LastScannedAt { get; set; }
}

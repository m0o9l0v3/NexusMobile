namespace AdminApi.Dto;

public sealed class VisitLogResponse
{
    public Guid Id { get; set; }
    public string SessionId { get; set; } = string.Empty;
    public string EventType { get; set; } = string.Empty;
    public string? SpotCode { get; set; }
    public DateTimeOffset OccurredAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class AuditLogVerificationResponse
{
    public bool IsValid { get; set; }
    public Guid? FirstInvalidLogId { get; set; }
}

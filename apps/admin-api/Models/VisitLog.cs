namespace AdminApi.Models;

public sealed class VisitLog
{
    public Guid Id { get; set; }
    public string SessionId { get; set; } = string.Empty;
    public string EventType { get; set; } = string.Empty;
    public string? SpotCode { get; set; }
    public DateTimeOffset OccurredAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string? PrevHash { get; set; }
    public string? Hash { get; set; }
    public string? HashAlg { get; set; }
    public string? ChainId { get; set; }
}

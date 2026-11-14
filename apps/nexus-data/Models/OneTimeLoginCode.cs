namespace AdminApi.Models;

public sealed class OneTimeLoginCode
{
    public Guid Id { get; set; }
    public string CodeHash { get; set; } = string.Empty;
    public Guid EventId { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? UsedAt { get; set; }
    public Guid? UsedByUuid { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

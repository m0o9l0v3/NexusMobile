namespace AdminApi.Models;

public sealed class RevokedToken
{
    public string Jti { get; set; } = string.Empty;
    public DateTimeOffset RevokedAt { get; set; }
    public string? Reason { get; set; }
    public string? RevokedByUserId { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
}

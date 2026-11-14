namespace AdminApi.Models;

public sealed class IssuedToken
{
    public string Jti { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public DateTimeOffset IssuedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
}

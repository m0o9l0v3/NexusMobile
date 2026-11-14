namespace AdminApi.Options;

public sealed class AuditLogOptions
{
    public const string SectionName = "AuditLog";

    public string HashKey { get; set; } = string.Empty;
}

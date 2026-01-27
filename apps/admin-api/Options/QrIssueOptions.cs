namespace AdminApi.Options;

public sealed class QrIssueOptions
{
    public const string SectionName = "QrIssue";

    public string HashKey { get; init; } = "change-me";
    public int TokenBytesLength { get; init; } = 32;
    public string PublicBaseUrl { get; init; } = "https://example.local";
}

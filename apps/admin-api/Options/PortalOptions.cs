namespace AdminApi.Options;

public sealed class PortalOptions
{
    public const string SectionName = "Portal";

    public string ParticipantBaseUrl { get; init; } = "https://example.local";
}

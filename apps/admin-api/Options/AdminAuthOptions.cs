namespace AdminApi.Options;

public sealed class AdminAuthOptions
{
    public const string SectionName = "AdminAuth";

    public string Username { get; init; } = "admin";
    public string Password { get; init; } = "AdminPassword123!";
    public string Issuer { get; init; } = "Nexus.Admin";
    public string Audience { get; init; } = "Nexus.AdminPortal";
    public string SigningKey { get; init; } = "CHANGE_ME_TO_A_LONG_RANDOM_SECRET";
    public int TokenExpiresMinutes { get; init; } = 480;
    public int VisitorTokenExpiresMinutes { get; init; } = 60;
    public string Role { get; init; } = "Owner";
}

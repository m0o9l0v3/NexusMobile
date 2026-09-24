using Npgsql;

namespace AdminApi.Data;

public static class DatabaseRuntimeConfiguration
{
    // File values deliberately override appsettings defaults. Never include secret values in errors.
    public static void LoadSecretFiles(ConfigurationManager configuration)
    {
        string[] keys = ["ConnectionStrings:AdminDatabase", "ConnectionStrings:PublicApiReadOnly",
            "AdminAuth:Password", "AdminAuth:SigningKey", "AuditLog:HashKey", "OneTimeCode:HashKey", "QrIssue:HashKey"];
        foreach (var key in keys)
        {
            var path = configuration[key + "File"];
            if (string.IsNullOrWhiteSpace(path)) continue;
            var value = File.ReadAllText(path).TrimEnd('\r', '\n');
            if (string.IsNullOrWhiteSpace(value)) throw new InvalidOperationException($"Secret file for {key} is empty.");
            configuration.AddInMemoryCollection(new Dictionary<string, string?> { [key] = value });
        }
    }

    public static string ResolveConnection(IConfiguration configuration, bool development, bool publicApi)
    {
        var sqlite = string.Equals(configuration["DatabaseProvider"], "sqlite", StringComparison.OrdinalIgnoreCase);
        if (!development && sqlite) throw new InvalidOperationException("PostgreSQL is required outside Development.");
        if (development && sqlite) return configuration.GetConnectionString("AdminDatabase") ?? "Data Source=admin-dev.db";
        var name = publicApi ? "PublicApiReadOnly" : "AdminDatabase";
        var connection = configuration.GetConnectionString(name);
        if (development && string.IsNullOrWhiteSpace(connection)) connection = configuration.GetConnectionString("AdminDatabase");
        if (string.IsNullOrWhiteSpace(connection)) throw new InvalidOperationException($"ConnectionStrings:{name} is required.");
        if (!development)
        {
            NpgsqlConnectionStringBuilder parsed;
            try { parsed = new(connection); }
            catch (ArgumentException) { throw new InvalidOperationException($"ConnectionStrings:{name} is invalid."); }
            var expectedUser = publicApi ? "nexus_public" : "nexus_admin_app";
            if (parsed.Username != expectedUser || string.IsNullOrWhiteSpace(parsed.Password) || parsed.Password == "nexus_password")
                throw new InvalidOperationException($"ConnectionStrings:{name} must use the dedicated {expectedUser} login and a non-default password.");
        }
        return connection;
    }

    public static void RequireSecret(IConfiguration configuration, string key, int minimumLength = 32)
    {
        var value = configuration[key];
        if (string.IsNullOrWhiteSpace(value) || value.Length < minimumLength ||
            value.Contains("CHANGE_ME", StringComparison.OrdinalIgnoreCase) || value == "AdminPassword123!")
            throw new InvalidOperationException($"A non-default secret is required for {key}.");
    }
}

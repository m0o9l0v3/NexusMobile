using AdminApi.Data;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AdminApi.Tests;

public sealed class DatabaseRuntimeConfigurationTests
{
    private static ConfigurationManager Config(params (string Key, string Value)[] values)
    {
        var config = new ConfigurationManager();
        config.AddInMemoryCollection(values.ToDictionary(v => v.Key, v => (string?)v.Value));
        return config;
    }

    [Fact]
    public void ProductionPublicConnection_DoesNotFallBackToAdmin()
    {
        var config = Config(("ConnectionStrings:AdminDatabase", "Host=localhost;Username=nexus_admin_app;Password=private"));
        Assert.Throws<InvalidOperationException>(() => DatabaseRuntimeConfiguration.ResolveConnection(config, false, true));
    }

    [Theory]
    [InlineData("postgres", "private")]
    [InlineData("nexus_migrator", "private")]
    [InlineData("nexus_owner", "private")]
    [InlineData("nexus_admin_app", "nexus_password")]
    [InlineData("nexus_admin_app", "")]
    public void ProductionAdminConnection_RejectsUnsafeLogin(string username, string password)
    {
        var config = Config(("ConnectionStrings:AdminDatabase", $"Host=localhost;Username={username};Password={password}"));
        Assert.Throws<InvalidOperationException>(() => DatabaseRuntimeConfiguration.ResolveConnection(config, false, false));
    }

    [Theory]
    [InlineData(true, "nexus_public", "PublicApiReadOnly")]
    [InlineData(false, "nexus_admin_app", "AdminDatabase")]
    public void ProductionConnection_AcceptsDedicatedLogin(bool publicApi, string username, string key)
    {
        var connection = $"Host=localhost;Username={username};Password=private-test-only";
        Assert.Equal(connection, DatabaseRuntimeConfiguration.ResolveConnection(Config(("ConnectionStrings:" + key, connection)), false, publicApi));
    }

    [Fact]
    public void Sqlite_IsLimitedToDevelopment()
    {
        var config = Config(("DatabaseProvider", "Sqlite"));
        Assert.Throws<InvalidOperationException>(() => DatabaseRuntimeConfiguration.ResolveConnection(config, false, false));
        Assert.Contains("Data Source=", DatabaseRuntimeConfiguration.ResolveConnection(config, true, false));
    }

    [Fact]
    public void SecretFiles_OverrideDefaultsAndRejectEmptyFiles()
    {
        var path = Path.GetTempFileName();
        try
        {
            File.WriteAllText(path, "file-secret\n");
            var config = Config(("AdminAuth:SigningKey", "old-default"), ("AdminAuth:SigningKeyFile", path));
            DatabaseRuntimeConfiguration.LoadSecretFiles(config);
            Assert.Equal("file-secret", config["AdminAuth:SigningKey"]);
            File.WriteAllText(path, "\n");
            Assert.Throws<InvalidOperationException>(() => DatabaseRuntimeConfiguration.LoadSecretFiles(config));
        }
        finally { File.Delete(path); }
    }

    [Theory]
    [InlineData("CHANGE_ME_TO_A_LONG_RANDOM_SECRET")]
    [InlineData("AdminPassword123!")]
    [InlineData("")]
    public void ProductionSecret_RejectsDefaults(string secret)
    {
        Assert.Throws<InvalidOperationException>(() => DatabaseRuntimeConfiguration.RequireSecret(Config(("Test:Secret", secret)), "Test:Secret"));
    }
}

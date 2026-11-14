using Microsoft.Extensions.Configuration;
using Xunit;

namespace AdminApi.Tests;

/// <summary>
/// 本番の admin-api は許可オリジンを持たない（E8-7 C-4・C-5、#72）。開発用の値は appsettings.Development.json にだけ置く。
/// </summary>
public sealed class CorsConfigurationTests
{
    [Fact]
    public void Production_WithoutOverride_AllowsNoOrigin()
    {
        Assert.Empty(Origins("Production", new()));
    }

    [Fact]
    public void Production_EnvOverrideOfIndex0_LeavesOnlyThatOrigin()
    {
        const string origin = "https://admin-portal.test";
        Assert.Equal(new[] { origin }, Origins("Production", new() { ["Cors__Origins__0"] = origin }));
    }

    [Fact]
    public void Production_EmptyEnvOverride_AllowsNoOrigin()
    {
        // compose.production.yml の ${NEXUS_ADMIN_ORIGIN:-} は、未設定のとき空文字の環境変数を渡す。
        // .NET の SetEnvironmentVariable は空文字で変数を消してしまうため、同じ値をメモリ上の設定で与える。
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["Cors:Origins:0"] = "", ["Cors:Origins:1"] = "  " })
            .Build();
        Assert.Empty(AdminApi.Options.CorsOrigins.FromConfiguration(configuration.GetSection("Cors:Origins")));
    }

    [Fact]
    public void Development_KeepsLocalPortalOrigins()
    {
        Assert.Contains("http://localhost:5176", Origins("Development", new()));
    }

    private static string[] Origins(string environmentName, Dictionary<string, string> environment)
    {
        // 実際の環境変数名（__ 区切り）をホストと同じプロバイダーで読む。接頭辞はテストごとに一意にする。
        var prefix = $"NEXUS_CORS_TEST_{Guid.NewGuid():N}_";
        try
        {
            foreach (var (key, value) in environment)
                Environment.SetEnvironmentVariable(prefix + key, value);

            var configuration = new ConfigurationBuilder()
                .SetBasePath(ApiDirectory())
                .AddJsonFile("appsettings.json", optional: false)
                .AddJsonFile($"appsettings.{environmentName}.json", optional: true)
                .AddEnvironmentVariables(prefix)
                .Build();
            return AdminApi.Options.CorsOrigins.FromConfiguration(configuration.GetSection("Cors:Origins"));
        }
        finally
        {
            foreach (var key in environment.Keys)
                Environment.SetEnvironmentVariable(prefix + key, null);
        }
    }

    private static string ApiDirectory()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var candidate = Path.Combine(dir.FullName, "apps", "admin-api");
            if (File.Exists(Path.Combine(candidate, "appsettings.json")))
                return candidate;
        }

        throw new InvalidOperationException("apps/admin-api/appsettings.json was not found.");
    }
}

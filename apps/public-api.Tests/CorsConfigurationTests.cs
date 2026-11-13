using Microsoft.Extensions.Configuration;
using Xunit;

namespace PublicApi.Tests;

/// <summary>
/// 本番での CORS 許可オリジンの組み立てを確かめる（E8-7 §1.3・C-5、#72）。
/// 本番のホストは PostgreSQL が無いと起動しないため、ホストと同じ順で設定を重ねて読む。
/// </summary>
public sealed class CorsConfigurationTests
{
    private const string PublicOrigin = "https://public-site.test";

    [Fact]
    public void Production_EnvOverrideOfIndex0_LeavesOnlyThatOrigin()
    {
        // 本番の Compose は Cors__AllowedOrigins__0 だけを渡す。ASP.NET Core は配列を添字ごとに上書きするため、
        // appsettings.json に添字 1 以降が残っていると、それも許可されてしまう。
        var origins = ProductionOrigins(new() { ["Cors__AllowedOrigins__0"] = PublicOrigin });

        Assert.Equal(new[] { PublicOrigin }, origins);
    }

    [Fact]
    public void Production_WithoutOverride_AllowsNoOrigin()
    {
        Assert.Empty(ProductionOrigins(new()));
    }

    [Fact]
    public void NoAppSettingsFile_ContainsTheUnusedExampleOrigin()
    {
        foreach (var file in Directory.GetFiles(ApiDirectory(), "appsettings*.json"))
            Assert.DoesNotContain("nexus.example.com", File.ReadAllText(file));
    }

    private static string[] ProductionOrigins(Dictionary<string, string> environment)
    {
        // 環境変数は実際の名前（__ 区切り）で入れ、ホストと同じ環境変数プロバイダーで読む。
        // 他のテストと混ざらないよう、テストごとに一意の接頭辞を付ける。
        var prefix = $"NEXUS_CORS_TEST_{Guid.NewGuid():N}_";
        try
        {
            foreach (var (key, value) in environment)
                Environment.SetEnvironmentVariable(prefix + key, value);

            var configuration = new ConfigurationBuilder()
                .SetBasePath(ApiDirectory())
                .AddJsonFile("appsettings.json", optional: false)
                .AddJsonFile("appsettings.Production.json", optional: true)
                .AddEnvironmentVariables(prefix)
                .Build();
            return configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? Array.Empty<string>();
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
            var candidate = Path.Combine(dir.FullName, "apps", "public-api");
            if (File.Exists(Path.Combine(candidate, "appsettings.json")))
                return candidate;
        }

        throw new InvalidOperationException("apps/public-api/appsettings.json was not found.");
    }
}

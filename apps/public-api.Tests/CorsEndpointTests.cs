using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace PublicApi.Tests;

/// <summary>CORS は公開サイトのオリジンからの GET /health にだけ付く（E8-7 C-1、#72）。</summary>
public sealed class CorsEndpointTests
{
    private sealed class PublicApiFactory : WebApplicationFactory<PublicApi.Controllers.LogsController>;

    private const string AllowedOrigin = "https://public-site.test";
    private const string UnknownOrigin = "https://unknown-site.test";
    private const string AllowOriginHeader = "Access-Control-Allow-Origin";

    [Fact(Timeout = 30000)]
    public async Task Health_FromAllowedOrigin_ReturnsAllowOrigin()
    {
        await WithClientAsync(async client =>
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, "/health");
            request.Headers.Add("Origin", AllowedOrigin);
            using var response = await client.SendAsync(request);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal(AllowedOrigin, Assert.Single(response.Headers.GetValues(AllowOriginHeader)));
            Assert.False(response.Headers.Contains("Access-Control-Allow-Credentials"));
        });
    }

    [Fact(Timeout = 30000)]
    public async Task HealthPreflight_FromAllowedOrigin_AllowsGetOnly()
    {
        await WithClientAsync(async client =>
        {
            using var get = await client.SendAsync(Preflight("/health", AllowedOrigin, "GET"));
            Assert.Equal(AllowedOrigin, Assert.Single(get.Headers.GetValues(AllowOriginHeader)));

            using var post = await client.SendAsync(Preflight("/health", AllowedOrigin, "POST"));
            Assert.False(post.Headers.Contains(AllowOriginHeader));
        });
    }

    [Theory(Timeout = 30000)]
    [InlineData("/api/logs")]
    [InlineData("/api/logs/batch")]
    public async Task LogsPreflight_FromAllowedOrigin_ReturnsNoCorsHeaders(string path)
    {
        await WithClientAsync(async client =>
        {
            using var response = await client.SendAsync(Preflight(path, AllowedOrigin, "POST", "content-type"));

            Assert.False(response.Headers.Contains(AllowOriginHeader));
            Assert.False(response.Headers.Contains("Access-Control-Allow-Methods"));
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Health_FromUnknownOrigin_ReturnsNoAllowOrigin()
    {
        await WithClientAsync(async client =>
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, "/health");
            request.Headers.Add("Origin", UnknownOrigin);
            using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.False(response.Headers.Contains(AllowOriginHeader));

            using var preflight = await client.SendAsync(Preflight("/health", UnknownOrigin, "GET"));
            Assert.False(preflight.Headers.Contains(AllowOriginHeader));
        });
    }

    private static HttpRequestMessage Preflight(string path, string origin, string method, string? headers = null)
    {
        var request = new HttpRequestMessage(HttpMethod.Options, path);
        request.Headers.Add("Origin", origin);
        request.Headers.Add("Access-Control-Request-Method", method);
        if (headers is not null)
            request.Headers.Add("Access-Control-Request-Headers", headers);
        return request;
    }

    private static async Task WithClientAsync(Func<HttpClient, Task> test)
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"nexus-public-cors-{Guid.NewGuid():N}.db");
        try
        {
            using var factory = new PublicApiFactory().WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureAppConfiguration((_, config) =>
                {
                    // 開発用の設定（appsettings.Development.json）を消し、許可オリジンをこのテストの値だけにする。
                    foreach (var source in config.Sources.OfType<Microsoft.Extensions.Configuration.Json.JsonConfigurationSource>()
                                 .Where(source => source.Path?.EndsWith(".Development.json", StringComparison.Ordinal) == true)
                                 .ToList())
                        config.Sources.Remove(source);
                    config.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        ["DatabaseProvider"] = "sqlite",
                        ["ConnectionStrings:AdminDatabase"] = $"Data Source={databasePath}",
                        ["Cors:AllowedOrigins:0"] = AllowedOrigin
                    });
                });
            });
            using var client = factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
            await test(client);
        }
        finally
        {
            File.Delete(databasePath);
        }
    }
}

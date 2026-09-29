using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace PublicApi.Tests;

public sealed class RateLimitingTests
{
    // Program は AdminApi と曖昧になるため、PublicApi アセンブリ内の型でホストを特定する。
    private sealed class PublicApiFactory : WebApplicationFactory<PublicApi.Controllers.LogsController>;

    [Fact(Timeout = 30000)]
    public async Task Logs_ExceedingLimit_Returns429WithRetryAfter()
    {
        await WithClientAsync(new() { ["RateLimiting:Policies:log-ingest:PermitLimit"] = "2" }, async client =>
        {
            for (var i = 0; i < 2; i++)
            {
                using var ok = await client.PostAsJsonAsync("/api/logs", new { });
                Assert.NotEqual(HttpStatusCode.TooManyRequests, ok.StatusCode);
            }

            using var limited = await client.PostAsJsonAsync("/api/logs", new { });
            Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
            Assert.True(limited.Headers.RetryAfter is not null);
        });
    }

    [Fact(Timeout = 30000)]
    public async Task LogsBatch_HasSeparateBudgetFromSingleLogs()
    {
        await WithClientAsync(new()
        {
            ["RateLimiting:Policies:log-ingest:PermitLimit"] = "1",
            ["RateLimiting:Policies:log-ingest-batch:PermitLimit"] = "1"
        }, async client =>
        {
            using var single = await client.PostAsJsonAsync("/api/logs", new { });
            using var batch = await client.PostAsJsonAsync("/api/logs/batch", new { });
            Assert.NotEqual(HttpStatusCode.TooManyRequests, single.StatusCode);
            Assert.NotEqual(HttpStatusCode.TooManyRequests, batch.StatusCode);

            using var batchLimited = await client.PostAsJsonAsync("/api/logs/batch", new { });
            Assert.Equal(HttpStatusCode.TooManyRequests, batchLimited.StatusCode);
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Health_IsNeverRateLimited()
    {
        await WithClientAsync(new() { ["RateLimiting:Policies:log-ingest:PermitLimit"] = "1" }, async client =>
        {
            for (var i = 0; i < 20; i++)
            {
                using var response = await client.GetAsync("/health");
                Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            }
        });
    }

    private static async Task WithClientAsync(Dictionary<string, string?> overrides, Func<HttpClient, Task> test)
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"nexus-public-ratelimit-{Guid.NewGuid():N}.db");
        try
        {
            using var factory = new PublicApiFactory().WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureAppConfiguration((_, config) =>
                {
                    overrides["DatabaseProvider"] = "sqlite";
                    overrides["ConnectionStrings:AdminDatabase"] = $"Data Source={databasePath}";
                    config.AddInMemoryCollection(overrides);
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

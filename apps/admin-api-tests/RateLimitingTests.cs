using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AdminApi.Tests;

[Collection(AdminApiHostCollection.Name)]
public sealed class RateLimitingTests
{
    [Fact(Timeout = 30000)]
    public async Task Login_ExceedingLimit_Returns429WithRetryAfter()
    {
        await WithClientAsync(new() { ["RateLimiting:Policies:auth-login:PermitLimit"] = "2" }, async client =>
        {
            for (var i = 0; i < 2; i++)
            {
                using var ok = await client.PostAsJsonAsync("/admin/auth/login", new { username = "x", password = "y" });
                Assert.Equal(HttpStatusCode.Unauthorized, ok.StatusCode);
            }

            using var limited = await client.PostAsJsonAsync("/admin/auth/login", new { username = "x", password = "y" });
            Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
            Assert.True(limited.Headers.RetryAfter is not null);
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Redeem_ExceedingLimit_Returns429()
    {
        await WithClientAsync(new() { ["RateLimiting:Policies:code-redeem:PermitLimit"] = "1" }, async client =>
        {
            using var first = await client.PostAsJsonAsync("/admin/one-time-codes/redeem", new { code = "invalid" });
            Assert.NotEqual(HttpStatusCode.TooManyRequests, first.StatusCode);

            using var limited = await client.PostAsJsonAsync("/admin/one-time-codes/redeem", new { code = "invalid" });
            Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Health_IsNeverRateLimited()
    {
        await WithClientAsync(new() { ["RateLimiting:Policies:auth-login:PermitLimit"] = "1" }, async client =>
        {
            for (var i = 0; i < 20; i++)
            {
                using var response = await client.GetAsync("/health");
                Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            }
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Disabled_DoesNotLimit()
    {
        await WithClientAsync(new()
        {
            ["RateLimiting:Enabled"] = "false",
            ["RateLimiting:Policies:auth-login:PermitLimit"] = "1"
        }, async client =>
        {
            for (var i = 0; i < 5; i++)
            {
                using var response = await client.PostAsJsonAsync("/admin/auth/login", new { username = "x", password = "y" });
                Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            }
        });
    }

    private static async Task WithClientAsync(Dictionary<string, string?> overrides, Func<HttpClient, Task> test)
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"nexus-admin-ratelimit-{Guid.NewGuid():N}.db");
        try
        {
            using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
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

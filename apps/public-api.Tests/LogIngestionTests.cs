using System.Net;
using System.Net.Http.Json;
using AdminApi.Data;
using AdminApi.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace PublicApi.Tests;

public sealed class LogIngestionTests
{
    private sealed class PublicApiFactory : WebApplicationFactory<PublicApi.Controllers.LogsController>;

    [Theory(Timeout = 30000)]
    [InlineData("/api/logs")]
    [InlineData("/api/logs/batch")]
    public async Task ValidLogs_AreAcceptedAndPersistedWithHashChain(string path)
    {
        await WithClientAsync(async (client, services) =>
        {
            for (var index = 1; index <= 2; index++)
            {
                var entry = new { sessionId = "http-test", eventType = "spot_view" };
                object payload = path.EndsWith("/batch", StringComparison.Ordinal)
                    ? new { logs = new[] { entry } } : entry;
                using var response = await client.PostAsJsonAsync(path, payload);
                Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
                Assert.True((await response.Content.ReadFromJsonAsync<PublicApi.Dto.AcceptedResponse>())!.Accepted);

                var persisted = false;
                for (var attempt = 0; attempt < 100; attempt++)
                {
                    using var scope = services.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<AdminDbContext>();
                    if (await db.VisitLogs.CountAsync() == index)
                    {
                        persisted = true;
                        break;
                    }
                    await Task.Delay(50);
                }
                Assert.True(persisted, "Accepted log was not persisted by the background worker.");
            }

            using var finalScope = services.CreateScope();
            var logs = await finalScope.ServiceProvider.GetRequiredService<AdminDbContext>()
                .VisitLogs.AsNoTracking().OrderBy(log => log.CreatedAt).ToListAsync();
            Assert.Equal(2, logs.Count);
            Assert.Equal(string.Empty, logs[0].PrevHash);
            Assert.Equal(logs[0].Hash, logs[1].PrevHash);
            Assert.Equal(logs[0].ChainId, logs[1].ChainId);
            Assert.All(logs, log =>
            {
                Assert.NotNull(log.Hash);
                Assert.Equal(64, log.Hash.Length);
                Assert.Equal("HMAC-SHA256", log.HashAlg);
            });
        });
    }

    [Theory(Timeout = 30000)]
    [InlineData("/api/logs", "sessionId")]
    [InlineData("/api/logs", "eventType")]
    [InlineData("/api/logs/batch", "sessionId")]
    [InlineData("/api/logs/batch", "eventType")]
    public async Task MissingRequiredField_Returns400WithoutPersisting(string path, string missingField)
    {
        await WithClientAsync(async (client, services) =>
        {
            var entry = new Dictionary<string, string> { ["sessionId"] = "http-test", ["eventType"] = "spot_view" };
            entry.Remove(missingField);
            object payload = path.EndsWith("/batch", StringComparison.Ordinal)
                ? new { logs = new[] { entry } } : entry;
            using var response = await client.PostAsJsonAsync(path, payload);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            using var scope = services.CreateScope();
            Assert.Equal(0, await scope.ServiceProvider.GetRequiredService<AdminDbContext>().VisitLogs.CountAsync());
        });
    }

    private static async Task WithClientAsync(Func<HttpClient, IServiceProvider, Task> test)
    {
        var databaseName = $"nexus-public-log-http-{Guid.NewGuid():N}";
        using var factory = new PublicApiFactory().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Development");
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["DatabaseProvider"] = "sqlite",
                ["ConnectionStrings:AdminDatabase"] = "Data Source=:memory:",
                ["AuditLog:HashKey"] = "http-integration-test-only-audit-key-123456789",
            }));
            builder.ConfigureServices(services =>
            {
                // Exercise MVC and the real background worker independently of a relational provider.
                services.RemoveAll<AdminDbContext>();
                services.AddScoped(provider => new AdminDbContext(
                    new DbContextOptionsBuilder<AdminDbContext>().UseInMemoryDatabase(databaseName).Options,
                    provider.GetRequiredService<AuditLogHasher>()));
            });
        });
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
        await test(client, factory.Services);
    }
}

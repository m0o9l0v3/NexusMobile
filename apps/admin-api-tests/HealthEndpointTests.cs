using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AdminApi.Tests;

[Collection(AdminApiHostCollection.Name)]
public sealed class HealthEndpointTests
{
    [Fact(Timeout = 20000)]
    public async Task Health_IsAvailableWithoutAuthentication()
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"nexus-admin-health-{Guid.NewGuid():N}.db");
        try
        {
            using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(
                    new Dictionary<string, string?>
                    {
                        ["DatabaseProvider"] = "sqlite",
                        ["ConnectionStrings:AdminDatabase"] = $"Data Source={databasePath}"
                    }));
            });
            using var client = factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

            using var response = await client.GetAsync("/health");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            Assert.Equal("ok", body.RootElement.GetProperty("status").GetString());
        }
        finally
        {
            File.Delete(databasePath);
        }
    }
}

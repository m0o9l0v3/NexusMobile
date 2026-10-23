using System.Data.Common;
using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PublicApi.Controllers;
using PublicApi.Services.Delivery;
using Xunit;

namespace PublicApi.Tests;

/// <summary>
/// <c>GET /api/v2/bundle</c> の契約（E2-5 §4・§9 の #23 の行）。配信表は差し替えた repository で再現する。
/// </summary>
public sealed class BundleEndpointTests
{
    private sealed class PublicApiFactory : WebApplicationFactory<LogsController>;

    /// <summary>配信表の代わり。読まれた回数を数える。</summary>
    private sealed class FakeRepository : IParticipantBundleRepository
    {
        private readonly Dictionary<long, StoredParticipantBundle> _bundles = new();

        public long? CurrentVersion { get; set; }
        public Exception? Failure { get; set; }
        public int BundleReads { get; private set; }

        public void Publish(StoredParticipantBundle bundle)
        {
            _bundles[bundle.BundleVersion] = bundle;
            CurrentVersion = bundle.BundleVersion;
        }

        public Task<long?> GetCurrentVersionAsync(CancellationToken cancellationToken) =>
            Failure is null ? Task.FromResult(CurrentVersion) : Task.FromException<long?>(Failure);

        public Task<StoredParticipantBundle?> GetBundleAsync(long bundleVersion, CancellationToken cancellationToken)
        {
            BundleReads++;
            return Task.FromResult(_bundles.GetValueOrDefault(bundleVersion));
        }
    }

    private sealed class FakeDbException : DbException
    {
        public FakeDbException() : base("Host=secret-host;Password=secret") { }
    }

    /// <summary>キー順・空白を正規化していない、保存したままのバイト列（jsonb にしない理由、§3.1）。</summary>
    private static StoredParticipantBundle Stored(long version, string? sha256Override = null, int? lengthOverride = null)
    {
        var json = $"{{\"nexus_bundle\": {{\"schema_version\":\"2.0.0\", \"bundle_version\":{version}}},  \"spots\":[], \"id_aliases\":[], \"map\":null}}";
        var payload = Encoding.UTF8.GetBytes(json);
        var sha256 = Convert.ToHexString(SHA256.HashData(payload)).ToLowerInvariant();
        return new StoredParticipantBundle(version, "2.0.0", payload, sha256Override ?? sha256, lengthOverride ?? payload.Length);
    }

    private static async Task WithClientAsync(
        FakeRepository repository,
        Func<HttpClient, IServiceProvider, Task> test,
        Dictionary<string, string?>? overrides = null)
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"nexus-public-bundle-{Guid.NewGuid():N}.db");
        try
        {
            using var factory = new PublicApiFactory().WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureAppConfiguration((_, config) =>
                {
                    var values = overrides ?? new Dictionary<string, string?>();
                    values["DatabaseProvider"] = "sqlite";
                    values["ConnectionStrings:AdminDatabase"] = $"Data Source={databasePath}";
                    config.AddInMemoryCollection(values);
                });
                builder.ConfigureTestServices(services =>
                    services.AddSingleton<IParticipantBundleRepository>(repository));
            });
            using var client = factory.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
            await test(client, factory.Services);
        }
        finally
        {
            File.Delete(databasePath);
        }
    }

    private static string Header(HttpResponseMessage response, string name) =>
        response.Headers.TryGetValues(name, out var values) ? string.Join(",", values) : string.Empty;

    private static async Task<string?> ProblemType(HttpResponseMessage response)
    {
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return document.RootElement.GetProperty("type").GetString();
    }

    // MARK: 200

    [Fact(Timeout = 30000)]
    public async Task Get_ReturnsStoredBytesWithIntegrityHeaders()
    {
        var repository = new FakeRepository();
        var stored = Stored(42);
        repository.Publish(stored);

        await WithClientAsync(repository, async (client, _) =>
        {
            using var response = await client.GetAsync("/api/v2/bundle");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = await response.Content.ReadAsByteArrayAsync();
            Assert.Equal(stored.Payload, body);
            Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
            Assert.Equal("utf-8", response.Content.Headers.ContentType?.CharSet);
            Assert.Equal($"\"sha256-{stored.Sha256}\"", response.Headers.ETag?.ToString());
            Assert.False(response.Headers.ETag?.IsWeak);
            Assert.Equal(Convert.ToHexString(SHA256.HashData(body)).ToLowerInvariant(), Header(response, "Nexus-Bundle-Sha256"));
            Assert.Equal(body.Length.ToString(), Header(response, "Nexus-Bundle-Length"));
            Assert.Equal("42", Header(response, "Nexus-Bundle-Version"));
            Assert.Equal("2.0.0", Header(response, "Nexus-Bundle-Schema"));
            Assert.Equal("300", Header(response, "Nexus-Recheck-After"));
            Assert.True(response.Headers.CacheControl?.NoCache);
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Get_RecheckAfterComesFromConfiguration()
    {
        var repository = new FakeRepository();
        repository.Publish(Stored(42));

        await WithClientAsync(repository, async (client, _) =>
        {
            using var response = await client.GetAsync("/api/v2/bundle");
            Assert.Equal("120", Header(response, "Nexus-Recheck-After"));
        }, new() { ["ParticipantBundle:RecheckAfterSeconds"] = "120" });
    }

    /// <summary>圧縮は edge（Caddy）の担当で、public-api は圧縮しない（§4.1）。</summary>
    [Fact(Timeout = 30000)]
    public async Task Get_DoesNotCompressEvenWhenClientAcceptsGzip()
    {
        var repository = new FakeRepository();
        var stored = Stored(42);
        repository.Publish(stored);

        await WithClientAsync(repository, async (client, _) =>
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v2/bundle");
            request.Headers.AcceptEncoding.Add(new StringWithQualityHeaderValue("gzip"));
            request.Headers.AcceptEncoding.Add(new StringWithQualityHeaderValue("br"));
            using var response = await client.SendAsync(request);

            Assert.Empty(response.Content.Headers.ContentEncoding);
            Assert.Equal(stored.Payload, await response.Content.ReadAsByteArrayAsync());
        });
    }

    // MARK: 304

    [Fact(Timeout = 30000)]
    public async Task Get_WithCurrentETag_Returns304WithHeadersAndNoBody()
    {
        var repository = new FakeRepository();
        var stored = Stored(42);
        repository.Publish(stored);

        await WithClientAsync(repository, async (client, _) =>
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v2/bundle");
            request.Headers.TryAddWithoutValidation("If-None-Match", $"\"other\", \"sha256-{stored.Sha256}\"");
            using var response = await client.SendAsync(request);

            Assert.Equal(HttpStatusCode.NotModified, response.StatusCode);
            Assert.Empty(await response.Content.ReadAsByteArrayAsync());
            Assert.Equal($"\"sha256-{stored.Sha256}\"", response.Headers.ETag?.ToString());
            Assert.Equal(stored.Sha256, Header(response, "Nexus-Bundle-Sha256"));
            Assert.Equal("42", Header(response, "Nexus-Bundle-Version"));
            Assert.Equal("300", Header(response, "Nexus-Recheck-After"));
        });
    }

    /// <summary>edge が付けた接尾辞は edge が取り除く（§4.1.1）。public-api に届いた値は解釈せず、完全一致だけを見る。</summary>
    [Theory(Timeout = 30000)]
    [InlineData("-gzip")]
    [InlineData("-old")]
    public async Task Get_WithDifferentETag_Returns200(string suffix)
    {
        var repository = new FakeRepository();
        var stored = Stored(42);
        repository.Publish(stored);

        await WithClientAsync(repository, async (client, _) =>
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v2/bundle");
            request.Headers.TryAddWithoutValidation("If-None-Match", $"\"sha256-{stored.Sha256}{suffix}\"");
            using var response = await client.SendAsync(request);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        });
    }

    // MARK: 404・503・500

    [Fact(Timeout = 30000)]
    public async Task Get_BeforeFirstPublication_Returns404NotPublished()
    {
        await WithClientAsync(new FakeRepository(), async (client, _) =>
        {
            using var response = await client.GetAsync("/api/v2/bundle");

            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
            Assert.Equal(BundleController.NotPublishedType, await ProblemType(response));
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Get_WhenDatabaseUnavailable_Returns503WithRetryAfterAndNoDetails()
    {
        var repository = new FakeRepository { Failure = new FakeDbException() };

        await WithClientAsync(repository, async (client, _) =>
        {
            using var response = await client.GetAsync("/api/v2/bundle");

            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
            Assert.Equal(TimeSpan.FromSeconds(30), response.Headers.RetryAfter?.Delta);
            Assert.Equal(BundleController.UnavailableType, await ProblemType(response));
            var text = await response.Content.ReadAsStringAsync();
            Assert.DoesNotContain("secret", text, StringComparison.OrdinalIgnoreCase);
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Get_WhenStoredSha256DoesNotMatch_Returns500Integrity()
    {
        var repository = new FakeRepository();
        repository.Publish(Stored(42, sha256Override: new string('a', 64)));

        await WithClientAsync(repository, async (client, _) =>
        {
            using var response = await client.GetAsync("/api/v2/bundle");

            Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
            Assert.Equal(BundleController.IntegrityType, await ProblemType(response));
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Get_WhenStoredLengthDoesNotMatch_Returns500Integrity()
    {
        var repository = new FakeRepository();
        repository.Publish(Stored(42, lengthOverride: 1));

        await WithClientAsync(repository, async (client, _) =>
        {
            using var response = await client.GetAsync("/api/v2/bundle");

            Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
            Assert.Equal(BundleController.IntegrityType, await ProblemType(response));
        });
    }

    [Fact(Timeout = 30000)]
    public async Task Get_WhenPointerTargetsMissingBundle_Returns500Integrity()
    {
        var repository = new FakeRepository { CurrentVersion = 7 };

        await WithClientAsync(repository, async (client, _) =>
        {
            using var response = await client.GetAsync("/api/v2/bundle");

            Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
            Assert.Equal(BundleController.IntegrityType, await ProblemType(response));
        });
    }

    // MARK: メモリ上の保持（§4.1.2）

    [Fact(Timeout = 30000)]
    public async Task Get_DoesNotReloadBundleUntilVersionChanges()
    {
        var repository = new FakeRepository();
        repository.Publish(Stored(42));

        await WithClientAsync(repository, async (client, _) =>
        {
            for (var i = 0; i < 3; i++)
            {
                using var response = await client.GetAsync("/api/v2/bundle");
                Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            }
            Assert.Equal(1, repository.BundleReads);

            repository.Publish(Stored(43));
            using var updated = await client.GetAsync("/api/v2/bundle");
            Assert.Equal("43", Header(updated, "Nexus-Bundle-Version"));
            Assert.Equal(2, repository.BundleReads);
        });
    }

    // MARK: rate limit（§4.1.2）

    [Fact(Timeout = 30000)]
    public async Task Endpoint_HasNoRateLimitingPolicy()
    {
        var repository = new FakeRepository();
        repository.Publish(Stored(42));

        await WithClientAsync(repository, async (client, services) =>
        {
            using var _ = await client.GetAsync("/api/v2/bundle");
            var endpoint = services.GetRequiredService<EndpointDataSource>().Endpoints
                .OfType<RouteEndpoint>()
                .Single(item => item.RoutePattern.RawText == "api/v2/bundle");

            Assert.Null(endpoint.Metadata.GetMetadata<EnableRateLimitingAttribute>());
        });
    }
}

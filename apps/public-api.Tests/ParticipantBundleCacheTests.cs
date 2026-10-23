using System.Security.Cryptography;
using System.Text;
using PublicApi.Services.Delivery;
using Xunit;

namespace PublicApi.Tests;

/// <summary>配信する bundle のメモリ上の保持（E2-5 §4.1.2）。</summary>
public sealed class ParticipantBundleCacheTests
{
    private sealed class Repository : IParticipantBundleRepository
    {
        private readonly Dictionary<long, StoredParticipantBundle> _bundles = new();

        public long? CurrentVersion { get; set; }
        public int BundleReads { get; private set; }

        public void Add(long version)
        {
            var payload = Encoding.UTF8.GetBytes($"{{\"bundle_version\":{version}}}");
            var sha256 = Convert.ToHexString(SHA256.HashData(payload)).ToLowerInvariant();
            _bundles[version] = new StoredParticipantBundle(version, "2.0.0", payload, sha256, payload.Length);
        }

        public Task<long?> GetCurrentVersionAsync(CancellationToken cancellationToken) => Task.FromResult(CurrentVersion);

        public Task<StoredParticipantBundle?> GetBundleAsync(long bundleVersion, CancellationToken cancellationToken)
        {
            BundleReads++;
            return Task.FromResult(_bundles.GetValueOrDefault(bundleVersion));
        }
    }

    /// <summary>
    /// 公開と重なって古い版番号を読んだリクエストが、保持している新しい版を古い版で上書きしない。
    /// <c>current_bundle</c> は単調に増える（§3.2）ため、新しい版を返せばよい。
    /// </summary>
    [Fact]
    public async Task OlderVersionReadDoesNotOverwriteNewerCachedBundle()
    {
        var cache = new ParticipantBundleCache();
        var repository = new Repository();
        repository.Add(42);
        repository.Add(43);

        repository.CurrentVersion = 43;
        var newer = await cache.GetCurrentAsync(repository, CancellationToken.None);

        repository.CurrentVersion = 42;
        var stale = await cache.GetCurrentAsync(repository, CancellationToken.None);

        Assert.Equal(43, newer?.BundleVersion);
        Assert.Equal(43, stale?.BundleVersion);
        Assert.Equal(1, repository.BundleReads);

        repository.CurrentVersion = 43;
        var again = await cache.GetCurrentAsync(repository, CancellationToken.None);
        Assert.Same(newer, again);
    }

    [Fact]
    public async Task NewerVersionReplacesCachedBundle()
    {
        var cache = new ParticipantBundleCache();
        var repository = new Repository();
        repository.Add(42);
        repository.Add(43);

        repository.CurrentVersion = 42;
        await cache.GetCurrentAsync(repository, CancellationToken.None);
        repository.CurrentVersion = 43;
        var current = await cache.GetCurrentAsync(repository, CancellationToken.None);

        Assert.Equal(43, current?.BundleVersion);
        Assert.Equal(2, repository.BundleReads);
    }
}

using System.Security.Cryptography;

namespace PublicApi.Services.Delivery;

/// <summary>配信する現在の bundle。<see cref="ETag"/> は条件付き GET 専用（E2-5 §4.1.1）。</summary>
public sealed record CurrentParticipantBundle(
    long BundleVersion,
    string SchemaVersion,
    byte[] Payload,
    string Sha256)
{
    public string ETag => $"\"sha256-{Sha256}\"";
}

/// <summary>配信表の bundle が壊れている（SHA-256・大きさが保存時と一致しない、ポインタの指す行が無い）。</summary>
public sealed class ParticipantBundleIntegrityException : Exception
{
    public ParticipantBundleIntegrityException(string message) : base(message)
    {
    }
}

/// <summary>
/// 現在の版の bytes とヘッダーの値を、<c>bundle_version</c> を鍵にメモリに保持する（E2-5 §4.1.2）。
/// リクエストごとに DB から読むのは現在の版番号だけで、版が変わったときだけ本体を読み直す。
/// 読み直すたびに、送信する bytes の SHA-256 を計算し直して保存時の値と照合する（§4.1）。
/// 中身の妥当性（§5）は Studio の責任で、ここでは検査しない。
/// <c>current_bundle.bundle_version</c> は単調に増える（§3.2、トリガーで後退を拒否）ため、保持している版より
/// 古い版番号を読んだリクエスト（公開と重なり、待っている間に新しい版が保持された場合など）は、保持している
/// 新しい版を返し、古い版で上書きしない。
/// </summary>
public sealed class ParticipantBundleCache
{
    private readonly SemaphoreSlim _reloadLock = new(1, 1);
    private CurrentParticipantBundle? _current;

    /// <summary>現在の bundle。一度も公開されていなければ null。DB に接続できなければ例外を投げる。</summary>
    public async Task<CurrentParticipantBundle?> GetCurrentAsync(
        IParticipantBundleRepository repository,
        CancellationToken cancellationToken)
    {
        var version = await repository.GetCurrentVersionAsync(cancellationToken);
        if (version is null)
        {
            return null;
        }

        var cached = Volatile.Read(ref _current);
        if (cached is not null && cached.BundleVersion >= version)
        {
            return cached;
        }

        await _reloadLock.WaitAsync(cancellationToken);
        try
        {
            // 待っている間に、別のリクエストが同じ版かより新しい版を保持したかもしれない。
            cached = _current;
            if (cached is not null && cached.BundleVersion >= version)
            {
                return cached;
            }

            var stored = await repository.GetBundleAsync(version.Value, cancellationToken)
                ?? throw new ParticipantBundleIntegrityException($"current_bundle が指す版 {version} の bundle がない。");
            var loaded = Verify(stored);
            Volatile.Write(ref _current, loaded);
            return loaded;
        }
        finally
        {
            _reloadLock.Release();
        }
    }

    private static CurrentParticipantBundle Verify(StoredParticipantBundle stored)
    {
        if (stored.Payload.Length != stored.ByteLength)
        {
            throw new ParticipantBundleIntegrityException($"版 {stored.BundleVersion} の大きさが保存時と一致しない。");
        }

        var sha256 = Convert.ToHexString(SHA256.HashData(stored.Payload)).ToLowerInvariant();
        if (!string.Equals(sha256, stored.Sha256, StringComparison.Ordinal))
        {
            throw new ParticipantBundleIntegrityException($"版 {stored.BundleVersion} の SHA-256 が保存時と一致しない。");
        }

        return new CurrentParticipantBundle(stored.BundleVersion, stored.SchemaVersion, stored.Payload, sha256);
    }
}

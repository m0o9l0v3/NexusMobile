namespace PublicApi.Options;

public sealed class RateLimitPolicyOptions
{
    public int PermitLimit { get; set; }
    public int WindowSeconds { get; set; } = 60;
}

public sealed class RateLimitOptions
{
    public const string SectionName = "RateLimiting";

    public bool Enabled { get; set; } = true;

    /// <summary>X-Forwarded-For を信頼するリバースプロキシの IP。未設定ならループバックのみ信頼する。</summary>
    public string[] KnownProxies { get; set; } = Array.Empty<string>();

    /// <summary>X-Forwarded-For を信頼するプロキシのネットワーク（CIDR 表記、例: 172.18.0.0/16）。</summary>
    public string[] KnownNetworks { get; set; } = Array.Empty<string>();

    /// <summary>ポリシー名ごとの制限値。設定で指定したキーのみ上書きされる。</summary>
    public Dictionary<string, RateLimitPolicyOptions> Policies { get; set; } = new(StringComparer.Ordinal)
    {
        [RateLimitPolicies.LogIngest] = new() { PermitLimit = 60, WindowSeconds = 60 },
        [RateLimitPolicies.LogIngestBatch] = new() { PermitLimit = 12, WindowSeconds = 60 },
    };
}

public static class RateLimitPolicies
{
    public const string LogIngest = "log-ingest";
    public const string LogIngestBatch = "log-ingest-batch";
}

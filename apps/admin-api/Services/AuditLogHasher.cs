using System.Security.Cryptography;
using System.Text;
using AdminApi.Models;
using AdminApi.Options;
using Microsoft.Extensions.Options;

namespace AdminApi.Services;

public sealed class AuditLogHasher
{
    public const string DefaultHashAlgorithm = "HMAC-SHA256";

    private readonly AuditLogOptions _options;

    public AuditLogHasher(IOptions<AuditLogOptions> options)
    {
        _options = options.Value;
    }

    public string HashAlgorithm => DefaultHashAlgorithm;

    public string BuildChainId(VisitLog log)
    {
        var date = log.OccurredAt == default
            ? DateTimeOffset.UtcNow
            : log.OccurredAt.ToUniversalTime();
        return $"visitlog-{date:yyyyMMdd}";
    }

    public string ComputeHash(VisitLog log, string prevHash, string chainId)
    {
        var canonical = BuildCanonicalString(log, prevHash, chainId);
        var key = _options.HashKey;
        if (string.IsNullOrWhiteSpace(key))
        {
            throw new InvalidOperationException("AuditLog hash key is not configured.");
        }

        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(key));
        var hashBytes = hmac.ComputeHash(Encoding.UTF8.GetBytes(canonical));
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
    }

    public string BuildCanonicalString(VisitLog log, string prevHash, string chainId)
    {
        var occurredAt = log.OccurredAt.ToUniversalTime().ToString("O");
        var createdAt = log.CreatedAt.ToUniversalTime().ToString("O");
        return string.Join("\n",
            $"occurredAtUtc={occurredAt}",
            $"createdAtUtc={createdAt}",
            $"sessionId={log.SessionId}",
            $"eventType={log.EventType}",
            $"spotCode={log.SpotCode ?? string.Empty}",
            $"chainId={chainId}",
            $"prevHash={prevHash}");
    }
}

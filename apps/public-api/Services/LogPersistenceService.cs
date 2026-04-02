using AdminApi.Data;
using AdminApi.Models;
using AdminApi.Services;
using Microsoft.EntityFrameworkCore;

namespace PublicApi.Services;

/// <summary>
/// 参加者向けログをDBへ永続化するサービスです。
/// 監査のため、チェーンIDとハッシュ連鎖を付与して保存します。
/// </summary>
public sealed class LogPersistenceService
{
    private readonly AdminDbContext _dbContext;
    private readonly AuditLogHasher _hasher;

    public LogPersistenceService(AdminDbContext dbContext, AuditLogHasher hasher)
    {
        _dbContext = dbContext;
        _hasher = hasher;
    }

    /// <summary>
    /// キューされたログをまとめて保存します。
    /// 同一チェーン内では直前ハッシュを引き継いで整合性を維持します。
    /// </summary>
    public async Task PersistAsync(IReadOnlyList<QueuedLogEntry> entries, CancellationToken cancellationToken)
    {
        if (entries.Count == 0)
        {
            return;
        }

        var previousHashes = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var entry in entries)
        {
            var occurredAt = entry.OccurredAt ?? DateTimeOffset.UtcNow;
            var log = new VisitLog
            {
                Id = Guid.NewGuid(),
                SessionId = entry.SessionId,
                EventType = entry.EventType,
                SpotCode = entry.SpotCode,
                PayloadJson = entry.PayloadJson,
                OccurredAt = occurredAt,
                CreatedAt = DateTimeOffset.UtcNow,
                LocationLat = entry.LocationLat,
                LocationLng = entry.LocationLng,
                LocationAccuracy = entry.LocationAccuracy
            };

            var chainId = _hasher.BuildChainId(log);
            if (!previousHashes.TryGetValue(chainId, out var prevHash))
            {
                prevHash = await _dbContext.VisitLogs.AsNoTracking()
                    .Where(existing => existing.ChainId == chainId)
                    .OrderByDescending(existing => existing.CreatedAt)
                    .Select(existing => existing.Hash)
                    .FirstOrDefaultAsync(cancellationToken) ?? string.Empty;
            }

            log.ChainId = chainId;
            log.PrevHash = prevHash;
            log.HashAlg = _hasher.HashAlgorithm;
            log.Hash = _hasher.ComputeHash(log, prevHash, chainId);

            previousHashes[chainId] = log.Hash;
            _dbContext.VisitLogs.Add(log);
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
    }
}

public sealed record QueuedLogEntry(
    string SessionId,
    string EventType,
    string? SpotCode,
    string? PayloadJson,
    DateTimeOffset? OccurredAt,
    double? LocationLat,
    double? LocationLng,
    double? LocationAccuracy);

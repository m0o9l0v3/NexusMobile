using AdminApi.Data;
using AdminApi.Models;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Services;

public sealed class AuditLogVerificationService
{
    private readonly AdminDbContext _dbContext;
    private readonly AuditLogHasher _hasher;

    public AuditLogVerificationService(AdminDbContext dbContext, AuditLogHasher hasher)
    {
        _dbContext = dbContext;
        _hasher = hasher;
    }

    public async Task<AuditLogVerificationResult> VerifyAsync(
        string? chainId,
        DateTimeOffset? start,
        DateTimeOffset? end,
        CancellationToken cancellationToken)
    {
        var query = _dbContext.VisitLogs.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(chainId))
        {
            query = query.Where(log => log.ChainId == chainId);
        }

        if (start.HasValue)
        {
            query = query.Where(log => log.CreatedAt >= start.Value);
        }

        if (end.HasValue)
        {
            query = query.Where(log => log.CreatedAt <= end.Value);
        }

        var logs = await query
            .OrderBy(log => log.CreatedAt)
            .ThenBy(log => log.Id)
            .ToListAsync(cancellationToken);

        if (logs.Count == 0)
        {
            return new AuditLogVerificationResult(null);
        }

        var lastHashes = new Dictionary<string, string>();
        foreach (var log in logs)
        {
            if (string.IsNullOrWhiteSpace(log.ChainId) ||
                string.IsNullOrWhiteSpace(log.Hash) ||
                string.IsNullOrWhiteSpace(log.HashAlg))
            {
                return new AuditLogVerificationResult(log.Id);
            }

            var currentChainId = log.ChainId!;
            if (!lastHashes.TryGetValue(currentChainId, out var prevHash))
            {
                prevHash = await GetPreviousHashAsync(currentChainId, start, cancellationToken);
                lastHashes[currentChainId] = prevHash;
            }

            if (!string.Equals(log.PrevHash ?? string.Empty, prevHash, StringComparison.Ordinal))
            {
                return new AuditLogVerificationResult(log.Id);
            }

            if (!string.Equals(log.HashAlg, _hasher.HashAlgorithm, StringComparison.Ordinal))
            {
                return new AuditLogVerificationResult(log.Id);
            }

            var expectedHash = _hasher.ComputeHash(log, prevHash, currentChainId);
            if (!string.Equals(log.Hash, expectedHash, StringComparison.Ordinal))
            {
                return new AuditLogVerificationResult(log.Id);
            }

            lastHashes[currentChainId] = log.Hash;
        }

        return new AuditLogVerificationResult(null);
    }

    private async Task<string> GetPreviousHashAsync(string chainId, DateTimeOffset? start, CancellationToken cancellationToken)
    {
        if (!start.HasValue)
        {
            return string.Empty;
        }

        var previousHash = await _dbContext.VisitLogs.AsNoTracking()
            .Where(log => log.ChainId == chainId && log.CreatedAt < start.Value)
            .OrderByDescending(log => log.CreatedAt)
            .Select(log => log.Hash)
            .FirstOrDefaultAsync(cancellationToken);

        return previousHash ?? string.Empty;
    }
}

public sealed record AuditLogVerificationResult(Guid? FirstInvalidLogId)
{
    public bool IsValid => FirstInvalidLogId is null;
}

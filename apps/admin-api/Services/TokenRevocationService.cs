using AdminApi.Data;
using AdminApi.Models;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Services;

public sealed class TokenRevocationService
{
    private readonly AdminDbContext _dbContext;

    public TokenRevocationService(AdminDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task RecordIssuedAsync(string jti, string subject, DateTimeOffset issuedAt, DateTimeOffset expiresAt, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(jti))
        {
            return;
        }

        var existing = await _dbContext.IssuedTokens.FindAsync([jti], cancellationToken);
        if (existing != null)
        {
            existing.Subject = subject;
            existing.IssuedAt = issuedAt;
            existing.ExpiresAt = expiresAt;
            await _dbContext.SaveChangesAsync(cancellationToken);
            return;
        }

        _dbContext.IssuedTokens.Add(new IssuedToken
        {
            Jti = jti,
            Subject = subject,
            IssuedAt = issuedAt,
            ExpiresAt = expiresAt
        });

        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<bool> IsRevokedAsync(string jti, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(jti))
        {
            return false;
        }

        return await _dbContext.RevokedTokens
            .AsNoTracking()
            .AnyAsync(token => token.Jti == jti, cancellationToken);
    }

    public async Task<bool> RevokeAsync(string jti, string? reason, string? revokedByUserId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(jti))
        {
            return false;
        }

        var issuedToken = await _dbContext.IssuedTokens
            .AsNoTracking()
            .FirstOrDefaultAsync(token => token.Jti == jti, cancellationToken);

        if (issuedToken is null)
        {
            return false;
        }

        var existing = await _dbContext.RevokedTokens.FindAsync([jti], cancellationToken);
        if (existing != null)
        {
            existing.Reason = reason ?? existing.Reason;
            existing.RevokedByUserId = revokedByUserId ?? existing.RevokedByUserId;
            existing.RevokedAt = DateTimeOffset.UtcNow;
            await _dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }

        _dbContext.RevokedTokens.Add(new RevokedToken
        {
            Jti = issuedToken.Jti,
            RevokedAt = DateTimeOffset.UtcNow,
            Reason = reason,
            RevokedByUserId = revokedByUserId,
            ExpiresAt = issuedToken.ExpiresAt
        });

        await _dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<int> RevokeBySubjectAsync(string subject, string? reason, string? revokedByUserId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(subject))
        {
            return 0;
        }

        var now = DateTimeOffset.UtcNow;
        var activeTokens = await _dbContext.IssuedTokens
            .AsNoTracking()
            .Where(token => token.Subject == subject && token.ExpiresAt > now)
            .ToListAsync(cancellationToken);

        if (activeTokens.Count == 0)
        {
            return 0;
        }

        var revokedTokens = await _dbContext.RevokedTokens
            .AsNoTracking()
            .Select(token => token.Jti)
            .ToListAsync(cancellationToken);
        var revokedSet = revokedTokens.ToHashSet(StringComparer.Ordinal);

        foreach (var token in activeTokens)
        {
            if (revokedSet.Contains(token.Jti))
            {
                continue;
            }

            _dbContext.RevokedTokens.Add(new RevokedToken
            {
                Jti = token.Jti,
                RevokedAt = DateTimeOffset.UtcNow,
                Reason = reason,
                RevokedByUserId = revokedByUserId,
                ExpiresAt = token.ExpiresAt
            });
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
        return activeTokens.Count;
    }
}

using AdminApi.Data;
using AdminApi.Models;
using AdminApi.Options;
using AdminApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace AdminApi.Tests;

public sealed class AuditLogChainTests
{
    private static (AdminDbContext Context, AuditLogHasher Hasher) BuildContext()
    {
        var options = new DbContextOptionsBuilder<AdminDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        var hasher = new AuditLogHasher(Options.Create(new AuditLogOptions
        {
            HashKey = "test_hash_key_1234567890"
        }));
        return (new AdminDbContext(options, hasher), hasher);
    }

    [Fact]
    public async Task SaveChanges_SetsChainHashes()
    {
        var (context, _) = BuildContext();

        var log1 = new VisitLog
        {
            Id = Guid.NewGuid(),
            SessionId = "session-1",
            EventType = "enter",
            OccurredAt = DateTimeOffset.UtcNow.AddMinutes(-1),
            CreatedAt = DateTimeOffset.UtcNow.AddMinutes(-1)
        };
        var log2 = new VisitLog
        {
            Id = Guid.NewGuid(),
            SessionId = "session-2",
            EventType = "exit",
            OccurredAt = DateTimeOffset.UtcNow,
            CreatedAt = DateTimeOffset.UtcNow
        };

        context.VisitLogs.AddRange(log1, log2);
        await context.SaveChangesAsync();

        Assert.False(string.IsNullOrWhiteSpace(log1.Hash));
        Assert.False(string.IsNullOrWhiteSpace(log1.HashAlg));
        Assert.False(string.IsNullOrWhiteSpace(log1.ChainId));
        Assert.True(string.IsNullOrEmpty(log1.PrevHash));
        Assert.Equal(log1.Hash, log2.PrevHash);
    }

    [Fact]
    public async Task VerifyAsync_DetectsTampering()
    {
        var (context, hasher) = BuildContext();

        var log = new VisitLog
        {
            Id = Guid.NewGuid(),
            SessionId = "session-1",
            EventType = "enter",
            OccurredAt = DateTimeOffset.UtcNow,
            CreatedAt = DateTimeOffset.UtcNow
        };

        context.VisitLogs.Add(log);
        await context.SaveChangesAsync();

        log.EventType = "tampered";
        await context.SaveChangesAsync();

        var verifier = new AuditLogVerificationService(context, hasher);
        var result = await verifier.VerifyAsync(log.ChainId, null, null, CancellationToken.None);

        Assert.False(result.IsValid);
        Assert.Equal(log.Id, result.FirstInvalidLogId);
    }
}

using AdminApi.Data;
using AdminApi.Models;
using AdminApi.Options;
using AdminApi.Services;
using Microsoft.EntityFrameworkCore;
using PublicApi.Services;
using MsOptions = Microsoft.Extensions.Options.Options;
using Xunit;

namespace PublicApi.Tests.Data;

/// <summary>
/// PostgreSQL の timestamptz はマイクロ秒までしか持たない。保存して読み直した値でチェーンを検証しても
/// 合格することを確かめる（docs/backup-restore.md §6、2026-11-14 のリハーサルで 50 件中 49 件が不合格）。
/// InMemory や SQLite は 100 ナノ秒単位のまま保つので不具合が隠れる。そのため読み直しのときに
/// Npgsql と同じ切り捨てを（本体のコードを使わずに）この中で行う。
/// </summary>
public sealed class AuditLogPrecisionTests
{
    private const string HashKey = "precision_test_hash_key_1234567890";

    // 2026-11-14T03:04:05.1234567Z：100 ナノ秒の桁（7桁目）が 0 でない値。
    private static readonly DateTimeOffset SubMicrosecond =
        new DateTimeOffset(2026, 11, 14, 3, 4, 5, TimeSpan.Zero).AddTicks(1_234_567);

    private static AuditLogHasher Hasher() =>
        new(MsOptions.Create(new AuditLogOptions { HashKey = HashKey }));

    private static DbContextOptions<AdminDbContext> InMemory() =>
        new DbContextOptionsBuilder<AdminDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;

    /// <summary>Npgsql が timestamptz に書くときと同じく、マイクロ秒未満を切り捨てる。</summary>
    private static DateTimeOffset AsStoredByPostgres(DateTimeOffset value) =>
        new DateTimeOffset(value.UtcTicks / 10 * 10, TimeSpan.Zero);

    /// <summary>保存した行を PostgreSQL の精度で別の DB に写し、そこで audit-verify と同じ検証をする。</summary>
    private static async Task<AuditLogVerificationResult> VerifyAfterPostgresRoundTripAsync(
        AdminDbContext written, AuditLogHasher hasher)
    {
        var stored = await written.VisitLogs.AsNoTracking().ToListAsync();
        Assert.NotEmpty(stored);

        // ハッシュを付け直さないよう、hasher なしのコンテキストに写す（DB から読んだのと同じ状態）。
        await using var restored = new AdminDbContext(InMemory());
        foreach (var log in stored)
        {
            log.OccurredAt = AsStoredByPostgres(log.OccurredAt);
            log.CreatedAt = AsStoredByPostgres(log.CreatedAt);
            restored.VisitLogs.Add(log);
        }
        await restored.SaveChangesAsync();

        return await new AuditLogVerificationService(restored, hasher)
            .VerifyAsync(null, null, null, CancellationToken.None);
    }

    [Fact]
    public async Task PersistAsync_ChainVerifiesAfterPostgresPrecisionLoss()
    {
        var hasher = Hasher();
        // public-api と同じく、hasher 付きのコンテキストに LogPersistenceService で書く。
        await using var context = new AdminDbContext(InMemory(), hasher);
        var service = new LogPersistenceService(context, hasher);

        var entries = Enumerable.Range(0, 50)
            .Select(i => new QueuedLogEntry(
                $"session-{i % 3}",
                "spot_view",
                $"spot-{i}",
                null,
                // 半分は端末から届いた時刻（100 ナノ秒の桁あり）、半分はサーバーの現在時刻。
                i % 2 == 0 ? SubMicrosecond.AddTicks(i * 13) : null,
                null,
                null,
                null))
            .ToList();
        await service.PersistAsync(entries, CancellationToken.None);

        var stored = await context.VisitLogs.AsNoTracking().ToListAsync();
        Assert.Equal(50, stored.Count);
        Assert.All(stored, log =>
        {
            Assert.Equal(0, log.OccurredAt.UtcTicks % 10);
            Assert.Equal(0, log.CreatedAt.UtcTicks % 10);
        });

        var result = await VerifyAfterPostgresRoundTripAsync(context, hasher);
        Assert.True(result.IsValid, $"audit chain broken at {result.FirstInvalidLogId}");
    }

    [Fact]
    public async Task SaveChanges_ChainVerifiesAfterPostgresPrecisionLoss()
    {
        var hasher = Hasher();
        await using var context = new AdminDbContext(InMemory(), hasher);

        // 同じマイクロ秒の中で 100 ナノ秒だけずれた2件：保存後は同じ created_at になり Id 順で並ぶ。
        context.VisitLogs.AddRange(
            new VisitLog { Id = Guid.NewGuid(), SessionId = "s", EventType = "enter", OccurredAt = SubMicrosecond, CreatedAt = SubMicrosecond },
            new VisitLog { Id = Guid.NewGuid(), SessionId = "s", EventType = "exit", OccurredAt = SubMicrosecond.AddTicks(1), CreatedAt = SubMicrosecond.AddTicks(1) },
            new VisitLog { Id = Guid.NewGuid(), SessionId = "s", EventType = "view", OccurredAt = SubMicrosecond.AddTicks(20), CreatedAt = SubMicrosecond.AddTicks(20) });
        await context.SaveChangesAsync();

        var result = await VerifyAfterPostgresRoundTripAsync(context, hasher);
        Assert.True(result.IsValid, $"audit chain broken at {result.FirstInvalidLogId}");
    }

    [Fact]
    public void CanonicalString_UsesMicrosecondPrecision()
    {
        var hasher = Hasher();
        var log = new VisitLog { SessionId = "s", EventType = "enter", OccurredAt = SubMicrosecond, CreatedAt = SubMicrosecond };
        var truncated = new VisitLog { SessionId = "s", EventType = "enter", OccurredAt = AsStoredByPostgres(SubMicrosecond), CreatedAt = AsStoredByPostgres(SubMicrosecond) };

        var canonical = hasher.BuildCanonicalString(log, string.Empty, "visitlog-20261114");
        Assert.Contains("occurredAtUtc=2026-11-14T03:04:05.1234560+00:00", canonical);
        Assert.Contains("createdAtUtc=2026-11-14T03:04:05.1234560+00:00", canonical);
        Assert.Equal(
            hasher.ComputeHash(truncated, string.Empty, "visitlog-20261114"),
            hasher.ComputeHash(log, string.Empty, "visitlog-20261114"));
    }
}

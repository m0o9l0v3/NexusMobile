using System.Text.Json;
using AdminApi.Data;
using AdminApi.Models;
using AdminApi.Options;
using AdminApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace AdminApi.Tests;

public sealed class QrIssueLookupServiceTests
{
    private static AdminDbContext BuildContext()
    {
        var options = new DbContextOptionsBuilder<AdminDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AdminDbContext(options);
    }

    private static QrIssueTokenService BuildTokenService()
    {
        var options = Options.Create(new QrIssueOptions { HashKey = "test_hash_key_1234567890", PublicBaseUrl = "https://example.local" });
        return new QrIssueTokenService(options);
    }

    [Fact]
    public async Task ResolveAsync_ReturnsValidIssueWithSnapshot()
    {
        await using var context = BuildContext();
        var tokenService = BuildTokenService();
        var lookupService = new QrIssueLookupService(context, tokenService);

        var token = tokenService.GenerateToken();
        var tokenHash = tokenService.HashToken(token);
        var snapshot = new OpenCampusQrSnapshot
        {
            Event = new QrSnapshotEvent { EventId = Guid.NewGuid(), Title = "Open Campus", Date = "2024-10-01" },
            Timeslot = new QrSnapshotTimeslot { TimeslotId = Guid.NewGuid(), StartsAt = "2024-10-01T10:00:00+09:00", EndsAt = "2024-10-01T11:00:00+09:00" },
            Exhibits = new List<QrSnapshotExhibit>
            {
                new()
                {
                    ExhibitId = Guid.NewGuid(),
                    Name = "展示A",
                    SpotId = "pc_room",
                    SpotName = "PC室",
                    DepartmentId = "dept-a",
                    DepartmentName = "トータルモビリティ工学科"
                }
            },
            Version = 1
        };

        var issue = new QrIssue
        {
            Id = Guid.NewGuid(),
            EventId = snapshot.Event.EventId,
            TimeslotId = snapshot.Timeslot.TimeslotId,
            TokenHash = tokenHash,
            PayloadSnapshotJson = JsonSerializer.Serialize(snapshot, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }),
            IssuedByAdminId = "admin",
            IssuedAt = DateTimeOffset.UtcNow,
            ExpiresAt = DateTimeOffset.UtcNow.AddHours(1)
        };

        context.QrIssues.Add(issue);
        await context.SaveChangesAsync();

        var result = await lookupService.ResolveAsync(token, DateTimeOffset.UtcNow);

        Assert.Equal(QrIssueStatus.Valid, result.Status);
        Assert.NotNull(result.Snapshot);
        Assert.Equal("展示A", result.Snapshot!.Exhibits[0].Name);
    }

    [Fact]
    public async Task ResolveAsync_DeniesExpiredIssue()
    {
        await using var context = BuildContext();
        var tokenService = BuildTokenService();
        var lookupService = new QrIssueLookupService(context, tokenService);

        var token = tokenService.GenerateToken();
        context.QrIssues.Add(new QrIssue
        {
            Id = Guid.NewGuid(),
            EventId = Guid.NewGuid(),
            TimeslotId = Guid.NewGuid(),
            TokenHash = tokenService.HashToken(token),
            PayloadSnapshotJson = "{}",
            IssuedByAdminId = "admin",
            IssuedAt = DateTimeOffset.UtcNow.AddHours(-2),
            ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(-1)
        });
        await context.SaveChangesAsync();

        var result = await lookupService.ResolveAsync(token, DateTimeOffset.UtcNow);

        Assert.Equal(QrIssueStatus.Expired, result.Status);
    }

    [Fact]
    public async Task ResolveAsync_DeniesRevokedIssue()
    {
        await using var context = BuildContext();
        var tokenService = BuildTokenService();
        var lookupService = new QrIssueLookupService(context, tokenService);

        var token = tokenService.GenerateToken();
        context.QrIssues.Add(new QrIssue
        {
            Id = Guid.NewGuid(),
            EventId = Guid.NewGuid(),
            TimeslotId = Guid.NewGuid(),
            TokenHash = tokenService.HashToken(token),
            PayloadSnapshotJson = "{}",
            IssuedByAdminId = "admin",
            IssuedAt = DateTimeOffset.UtcNow.AddHours(-1),
            ExpiresAt = DateTimeOffset.UtcNow.AddHours(1),
            RevokedAt = DateTimeOffset.UtcNow
        });
        await context.SaveChangesAsync();

        var result = await lookupService.ResolveAsync(token, DateTimeOffset.UtcNow);

        Assert.Equal(QrIssueStatus.Revoked, result.Status);
    }

    [Fact]
    public async Task ResolveAsync_UsesSnapshotEvenAfterExhibitChanges()
    {
        await using var context = BuildContext();
        var tokenService = BuildTokenService();
        var lookupService = new QrIssueLookupService(context, tokenService);

        var token = tokenService.GenerateToken();
        var snapshot = new OpenCampusQrSnapshot
        {
            Event = new QrSnapshotEvent { EventId = Guid.NewGuid(), Title = "Open Campus", Date = "2024-10-01" },
            Timeslot = new QrSnapshotTimeslot { TimeslotId = Guid.NewGuid(), StartsAt = "2024-10-01T10:00:00+09:00", EndsAt = "2024-10-01T11:00:00+09:00" },
            Exhibits = new List<QrSnapshotExhibit>
            {
                new()
                {
                    ExhibitId = Guid.NewGuid(),
                    Name = "旧展示名",
                    SpotId = "hangar",
                    SpotName = "ハンガー",
                    DepartmentId = "dept-b",
                    DepartmentName = "整備科"
                }
            },
            Version = 1
        };

        context.QrIssues.Add(new QrIssue
        {
            Id = Guid.NewGuid(),
            EventId = snapshot.Event.EventId,
            TimeslotId = snapshot.Timeslot.TimeslotId,
            TokenHash = tokenService.HashToken(token),
            PayloadSnapshotJson = JsonSerializer.Serialize(snapshot, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }),
            IssuedByAdminId = "admin",
            IssuedAt = DateTimeOffset.UtcNow,
            ExpiresAt = DateTimeOffset.UtcNow.AddHours(2)
        });
        await context.SaveChangesAsync();

        var result = await lookupService.ResolveAsync(token, DateTimeOffset.UtcNow);

        Assert.Equal(QrIssueStatus.Valid, result.Status);
        Assert.NotNull(result.Snapshot);
        Assert.Equal("旧展示名", result.Snapshot!.Exhibits[0].Name);
    }
}

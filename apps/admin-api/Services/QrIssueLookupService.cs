using System.Text.Json;
using AdminApi.Data;
using AdminApi.Models;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Services;

public sealed class QrIssueLookupService
{
    private readonly AdminDbContext _dbContext;
    private readonly QrIssueTokenService _tokenService;
    private static readonly JsonSerializerOptions SnapshotJsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    public QrIssueLookupService(AdminDbContext dbContext, QrIssueTokenService tokenService)
    {
        _dbContext = dbContext;
        _tokenService = tokenService;
    }

    public async Task<QrIssueResolution> ResolveAsync(string token, DateTimeOffset now, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            return QrIssueResolution.NotFound();
        }

        var tokenHash = _tokenService.HashToken(token);
        var issue = await _dbContext.QrIssues.FirstOrDefaultAsync(item => item.TokenHash == tokenHash, cancellationToken);
        if (issue is null)
        {
            return QrIssueResolution.NotFound();
        }

        if (issue.RevokedAt is not null)
        {
            return QrIssueResolution.Revoked(issue);
        }

        if (issue.ExpiresAt < now)
        {
            return QrIssueResolution.Expired(issue);
        }

        var snapshot = JsonSerializer.Deserialize<OpenCampusQrSnapshot>(issue.PayloadSnapshotJson, SnapshotJsonOptions);
        if (snapshot is null)
        {
            return QrIssueResolution.InvalidSnapshot(issue);
        }

        return QrIssueResolution.Valid(issue, snapshot);
    }
}

public sealed class QrIssueResolution
{
    private QrIssueResolution(QrIssueStatus status, QrIssue? issue, OpenCampusQrSnapshot? snapshot)
    {
        Status = status;
        Issue = issue;
        Snapshot = snapshot;
    }

    public QrIssueStatus Status { get; }
    public QrIssue? Issue { get; }
    public OpenCampusQrSnapshot? Snapshot { get; }

    public static QrIssueResolution NotFound() => new(QrIssueStatus.NotFound, null, null);
    public static QrIssueResolution Revoked(QrIssue issue) => new(QrIssueStatus.Revoked, issue, null);
    public static QrIssueResolution Expired(QrIssue issue) => new(QrIssueStatus.Expired, issue, null);
    public static QrIssueResolution InvalidSnapshot(QrIssue issue) => new(QrIssueStatus.InvalidSnapshot, issue, null);
    public static QrIssueResolution Valid(QrIssue issue, OpenCampusQrSnapshot snapshot) => new(QrIssueStatus.Valid, issue, snapshot);
}

public enum QrIssueStatus
{
    NotFound,
    Revoked,
    Expired,
    InvalidSnapshot,
    Valid
}

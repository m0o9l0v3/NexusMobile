using System.IdentityModel.Tokens.Jwt;
using System.Text.Json;
using AdminApi.Data;
using AdminApi.Dto;
using AdminApi.Models;
using AdminApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Controllers;

[ApiController]
[Authorize(Policy = "AdminAccess")]
public sealed class QrIssuesController : ControllerBase
{
    private readonly AdminDbContext _dbContext;
    private readonly QrIssueTokenService _tokenService;
    private static readonly JsonSerializerOptions SnapshotJsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    public QrIssuesController(AdminDbContext dbContext, QrIssueTokenService tokenService)
    {
        _dbContext = dbContext;
        _tokenService = tokenService;
    }

    [HttpGet("admin/qr-issues")]
    public async Task<ActionResult<IEnumerable<QrIssueResponse>>> GetIssues([FromQuery] Guid? eventId)
    {
        var query = _dbContext.QrIssues.AsNoTracking();
        if (eventId.HasValue)
        {
            query = query.Where(issue => issue.EventId == eventId.Value);
        }

        var issues = await query
            .Join(_dbContext.OpenCampusTimeslots, issue => issue.TimeslotId, timeslot => timeslot.Id, (issue, timeslot) => new { issue, timeslot })
            .OrderByDescending(item => item.issue.IssuedAt)
            .Select(item => new QrIssueResponse
            {
                QrIssueId = item.issue.Id,
                EventId = item.issue.EventId,
                TimeslotId = item.issue.TimeslotId,
                IssuedAt = item.issue.IssuedAt,
                ExpiresAt = item.issue.ExpiresAt,
                RevokedAt = item.issue.RevokedAt,
                RevokeReason = item.issue.RevokeReason,
                ScanCount = item.issue.ScanCount,
                LastScannedAt = item.issue.LastScannedAt,
                Url = string.Empty,
                Timeslot = new TimeslotSummary
                {
                    TimeslotId = item.timeslot.Id,
                    StartsAt = item.timeslot.StartsAt,
                    EndsAt = item.timeslot.EndsAt
                }
            })
            .ToListAsync();

        return Ok(issues);
    }

    [HttpPost("admin/timeslots/{timeslotId:guid}/qr-issues")]
    public async Task<ActionResult<QrIssueResponse>> CreateIssue(Guid timeslotId, [FromBody] QrIssueRequest request)
    {
        request ??= new QrIssueRequest();
        var timeslot = await _dbContext.OpenCampusTimeslots
            .Include(item => item.Event)
            .FirstOrDefaultAsync(item => item.Id == timeslotId);
        if (timeslot is null)
        {
            return NotFound();
        }

        var eventItem = timeslot.Event;
        if (eventItem is null)
        {
            return Problem(statusCode: StatusCodes.Status409Conflict, detail: "Timeslot is missing event.");
        }

        var exhibits = await _dbContext.TimeslotExhibits
            .Where(item => item.TimeslotId == timeslotId)
            .Join(_dbContext.Exhibits, item => item.ExhibitId, exhibit => exhibit.Id, (item, exhibit) => new { item, exhibit })
            .Join(_dbContext.Spots, item => item.exhibit.SpotId, spot => spot.Id, (item, spot) => new { item.item, item.exhibit, spot })
            .Join(_dbContext.Departments, item => item.exhibit.DepartmentId, department => department.Id, (item, department) => new { item.item, item.exhibit, item.spot, department })
            .OrderBy(item => item.item.SortOrder)
            .Select(item => new QrSnapshotExhibit
            {
                ExhibitId = item.exhibit.Id,
                Name = item.exhibit.Name,
                SpotId = item.spot.Code,
                SpotName = item.spot.Name,
                DepartmentId = item.department.Id,
                DepartmentName = item.department.Name
            })
            .ToListAsync();

        var jstOffset = TimeSpan.FromHours(9);
        var eventDate = timeslot.StartsAt.ToOffset(jstOffset).Date.ToString("yyyy-MM-dd");
        var snapshot = new OpenCampusQrSnapshot
        {
            Event = new QrSnapshotEvent
            {
                EventId = eventItem.Id,
                Title = eventItem.Title,
                Date = eventDate
            },
            Timeslot = new QrSnapshotTimeslot
            {
                TimeslotId = timeslot.Id,
                StartsAt = timeslot.StartsAt.ToString("o"),
                EndsAt = timeslot.EndsAt.ToString("o")
            },
            Exhibits = exhibits,
            Version = 1
        };

        var snapshotJson = JsonSerializer.Serialize(snapshot, SnapshotJsonOptions);

        string token;
        string tokenHash;
        do
        {
            token = _tokenService.GenerateToken();
            tokenHash = _tokenService.HashToken(token);
        } while (await _dbContext.QrIssues.AnyAsync(issue => issue.TokenHash == tokenHash));

        var expiresAt = request.ExpiresAt ?? BuildDefaultExpiry();
        var issuedBy = User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value ?? "unknown";
        var now = DateTimeOffset.UtcNow;

        var issue = new QrIssue
        {
            Id = Guid.NewGuid(),
            EventId = eventItem.Id,
            TimeslotId = timeslot.Id,
            TokenHash = tokenHash,
            PayloadSnapshotJson = snapshotJson,
            IssuedByAdminId = issuedBy,
            IssuedAt = now,
            ExpiresAt = expiresAt,
            ScanCount = 0
        };

        _dbContext.QrIssues.Add(issue);
        await _dbContext.SaveChangesAsync();

        var url = _tokenService.BuildPublicUrl(token);
        return Ok(new QrIssueResponse
        {
            QrIssueId = issue.Id,
            EventId = issue.EventId,
            TimeslotId = issue.TimeslotId,
            IssuedAt = issue.IssuedAt,
            ExpiresAt = issue.ExpiresAt,
            RevokedAt = issue.RevokedAt,
            RevokeReason = issue.RevokeReason,
            ScanCount = issue.ScanCount,
            LastScannedAt = issue.LastScannedAt,
            Url = url,
            Timeslot = new TimeslotSummary
            {
                TimeslotId = timeslot.Id,
                StartsAt = timeslot.StartsAt,
                EndsAt = timeslot.EndsAt
            }
        });
    }

    [HttpPost("admin/qr-issues/{id:guid}/revoke")]
    public async Task<ActionResult<QrIssueResponse>> RevokeIssue(Guid id, [FromBody] RevokeQrIssueRequest request)
    {
        var issue = await _dbContext.QrIssues.FindAsync(id);
        if (issue is null)
        {
            return NotFound();
        }

        if (issue.RevokedAt is null)
        {
            issue.RevokedAt = DateTimeOffset.UtcNow;
            issue.RevokeReason = request.Reason;
            await _dbContext.SaveChangesAsync();
        }

        return Ok(new QrIssueResponse
        {
            QrIssueId = issue.Id,
            EventId = issue.EventId,
            TimeslotId = issue.TimeslotId,
            IssuedAt = issue.IssuedAt,
            ExpiresAt = issue.ExpiresAt,
            RevokedAt = issue.RevokedAt,
            RevokeReason = issue.RevokeReason,
            ScanCount = issue.ScanCount,
            LastScannedAt = issue.LastScannedAt,
            Url = string.Empty
        });
    }

    private static DateTimeOffset BuildDefaultExpiry()
    {
        var jstOffset = TimeSpan.FromHours(9);
        var nowJst = DateTimeOffset.UtcNow.ToOffset(jstOffset);
        return new DateTimeOffset(nowJst.Date.AddDays(1).AddSeconds(-1), jstOffset);
    }
}

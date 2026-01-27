using AdminApi.Data;
using AdminApi.Dto;
using AdminApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/logs")]
[Authorize(Policy = "AdminAccess")]
public sealed class LogsController : ControllerBase
{
    private readonly AdminDbContext _dbContext;
    private readonly AuditLogVerificationService _verificationService;

    public LogsController(AdminDbContext dbContext, AuditLogVerificationService verificationService)
    {
        _dbContext = dbContext;
        _verificationService = verificationService;
    }

    [HttpGet("recent")]
    public async Task<ActionResult<IEnumerable<VisitLogResponse>>> GetRecent([FromQuery] int limit = 100)
    {
        limit = Math.Clamp(limit, 1, 100);
        var logs = await _dbContext.VisitLogs
            .OrderByDescending(log => log.OccurredAt)
            .Take(limit)
            .Select(log => new VisitLogResponse
            {
                Id = log.Id,
                SessionId = log.SessionId,
                EventType = log.EventType,
                SpotCode = log.SpotCode,
                OccurredAt = log.OccurredAt,
                CreatedAt = log.CreatedAt
            })
            .ToListAsync();

        return Ok(logs);
    }

    [HttpGet("verify")]
    public async Task<ActionResult<AuditLogVerificationResponse>> VerifyChain(
        [FromQuery] string? chainId,
        [FromQuery] DateTimeOffset? start,
        [FromQuery] DateTimeOffset? end,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(chainId) && start is null && end is null)
        {
            return BadRequest("chainId or start/end must be provided.");
        }

        if (start.HasValue && end.HasValue && end < start)
        {
            return BadRequest("end must be greater than or equal to start.");
        }

        var result = await _verificationService.VerifyAsync(chainId, start, end, cancellationToken);
        return Ok(new AuditLogVerificationResponse
        {
            IsValid = result.IsValid,
            FirstInvalidLogId = result.FirstInvalidLogId
        });
    }
}

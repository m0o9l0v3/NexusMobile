using AdminApi.Data;
using AdminApi.Dto;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/logs")]
[Authorize]
public sealed class LogsController : ControllerBase
{
    private readonly AdminDbContext _dbContext;

    public LogsController(AdminDbContext dbContext)
    {
        _dbContext = dbContext;
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
}

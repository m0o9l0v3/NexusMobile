using AdminApi.Data;
using AdminApi.Dto;
using AdminApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/oc-days")]
[Authorize(Policy = "AdminAccess")]
public sealed class OcDaysController : ControllerBase
{
    private readonly AdminDbContext _dbContext;

    public OcDaysController(AdminDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<OcDayResponse>>> GetOcDays()
    {
        var ocDays = await _dbContext.OcDays
            .OrderBy(ocDay => ocDay.Date)
            .Select(ocDay => new OcDayResponse
            {
                Id = ocDay.Id,
                Date = ocDay.Date,
                Name = ocDay.Name
            })
            .ToListAsync();

        return Ok(ocDays);
    }

    [HttpPost]
    public async Task<ActionResult<OcDayResponse>> CreateOcDay([FromBody] OcDayRequest request)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var exists = await _dbContext.OcDays.AnyAsync(day => day.Date == request.Date);
        if (exists)
        {
            return Problem(statusCode: StatusCodes.Status409Conflict, detail: "OcDay date already exists.");
        }

        var ocDay = new OcDay
        {
            Id = Guid.NewGuid(),
            Date = request.Date,
            Name = request.Name
        };

        _dbContext.OcDays.Add(ocDay);
        await _dbContext.SaveChangesAsync();

        return CreatedAtAction(nameof(GetOcDays), new { id = ocDay.Id }, new OcDayResponse
        {
            Id = ocDay.Id,
            Date = ocDay.Date,
            Name = ocDay.Name
        });
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteOcDay(Guid id)
    {
        var ocDay = await _dbContext.OcDays.FindAsync(id);
        if (ocDay is null)
        {
            return NotFound();
        }

        _dbContext.OcDays.Remove(ocDay);
        await _dbContext.SaveChangesAsync();
        return NoContent();
    }
}

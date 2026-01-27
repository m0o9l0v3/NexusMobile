using AdminApi.Data;
using AdminApi.Dto;
using AdminApi.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/events")]
[Authorize(Policy = "AdminAccess")]
public sealed class EventsController : ControllerBase
{
    private readonly AdminDbContext _dbContext;

    public EventsController(AdminDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<EventResponse>>> GetEvents()
    {
        var events = await _dbContext.Events
            .OrderBy(eventItem => eventItem.StartsAt)
            .Select(eventItem => new EventResponse
            {
                Id = eventItem.Id,
                Title = eventItem.Title,
                Description = eventItem.Description,
                StartsAt = eventItem.StartsAt,
                EndsAt = eventItem.EndsAt,
                Lat = eventItem.Lat,
                Lng = eventItem.Lng,
                LocationText = eventItem.LocationText,
                IsPublished = eventItem.IsPublished
            })
            .ToListAsync();

        return Ok(events);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<EventResponse>> GetEvent(Guid id)
    {
        var eventItem = await _dbContext.Events.FindAsync(id);
        if (eventItem is null)
        {
            return NotFound();
        }

        return Ok(new EventResponse
        {
            Id = eventItem.Id,
            Title = eventItem.Title,
            Description = eventItem.Description,
            StartsAt = eventItem.StartsAt,
            EndsAt = eventItem.EndsAt,
            Lat = eventItem.Lat,
            Lng = eventItem.Lng,
            LocationText = eventItem.LocationText,
            IsPublished = eventItem.IsPublished
        });
    }

    [HttpPost]
    public async Task<ActionResult<EventResponse>> CreateEvent([FromBody] EventRequest request)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var eventItem = new Event
        {
            Id = Guid.NewGuid(),
            Title = request.Title,
            Description = request.Description,
            StartsAt = request.StartsAt,
            EndsAt = request.EndsAt,
            Lat = request.Lat,
            Lng = request.Lng,
            LocationText = request.LocationText,
            IsPublished = request.IsPublished
        };

        _dbContext.Events.Add(eventItem);
        await _dbContext.SaveChangesAsync();

        return CreatedAtAction(nameof(GetEvent), new { id = eventItem.Id }, new EventResponse
        {
            Id = eventItem.Id,
            Title = eventItem.Title,
            Description = eventItem.Description,
            StartsAt = eventItem.StartsAt,
            EndsAt = eventItem.EndsAt,
            Lat = eventItem.Lat,
            Lng = eventItem.Lng,
            LocationText = eventItem.LocationText,
            IsPublished = eventItem.IsPublished
        });
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<EventResponse>> UpdateEvent(Guid id, [FromBody] EventRequest request)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var eventItem = await _dbContext.Events.FindAsync(id);
        if (eventItem is null)
        {
            return NotFound();
        }

        eventItem.Title = request.Title;
        eventItem.Description = request.Description;
        eventItem.StartsAt = request.StartsAt;
        eventItem.EndsAt = request.EndsAt;
        eventItem.Lat = request.Lat;
        eventItem.Lng = request.Lng;
        eventItem.LocationText = request.LocationText;
        eventItem.IsPublished = request.IsPublished;

        await _dbContext.SaveChangesAsync();

        return Ok(new EventResponse
        {
            Id = eventItem.Id,
            Title = eventItem.Title,
            Description = eventItem.Description,
            StartsAt = eventItem.StartsAt,
            EndsAt = eventItem.EndsAt,
            Lat = eventItem.Lat,
            Lng = eventItem.Lng,
            LocationText = eventItem.LocationText,
            IsPublished = eventItem.IsPublished
        });
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteEvent(Guid id)
    {
        var eventItem = await _dbContext.Events.FindAsync(id);
        if (eventItem is null)
        {
            return NotFound();
        }

        _dbContext.Events.Remove(eventItem);
        await _dbContext.SaveChangesAsync();
        return NoContent();
    }

    [HttpPatch("{id:guid}/publish")]
    public async Task<ActionResult<EventResponse>> PublishEvent(Guid id, [FromBody] PublishRequest request)
    {
        var eventItem = await _dbContext.Events.FindAsync(id);
        if (eventItem is null)
        {
            return NotFound();
        }

        eventItem.IsPublished = request.IsPublished;
        await _dbContext.SaveChangesAsync();

        return Ok(new EventResponse
        {
            Id = eventItem.Id,
            Title = eventItem.Title,
            Description = eventItem.Description,
            StartsAt = eventItem.StartsAt,
            EndsAt = eventItem.EndsAt,
            Lat = eventItem.Lat,
            Lng = eventItem.Lng,
            LocationText = eventItem.LocationText,
            IsPublished = eventItem.IsPublished
        });
    }
}

using AdminApi.Data;
using AdminApi.Dto;
using AdminApi.Models;
using AdminApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/spots")]
[Authorize(Policy = "AdminAccess")]
public sealed class SpotsController : ControllerBase
{
    private readonly AdminDbContext _dbContext;
    private readonly QrCodeService _qrCodeService;

    public SpotsController(AdminDbContext dbContext, QrCodeService qrCodeService)
    {
        _dbContext = dbContext;
        _qrCodeService = qrCodeService;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<SpotResponse>>> GetSpots()
    {
        var spots = await _dbContext.Spots
            .OrderByDescending(spot => spot.UpdatedAt)
            .Select(spot => new SpotResponse
            {
                Id = spot.Id,
                Code = spot.Code,
                Name = spot.Name,
                Description = spot.Description,
                Tags = spot.Tags,
                Lat = spot.Lat,
                Lng = spot.Lng,
                IsPublished = spot.IsPublished,
                UpdatedAt = spot.UpdatedAt
            })
            .ToListAsync();

        return Ok(spots);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<SpotResponse>> GetSpot(Guid id)
    {
        var spot = await _dbContext.Spots.FindAsync(id);
        if (spot is null)
        {
            return NotFound();
        }

        return Ok(new SpotResponse
        {
            Id = spot.Id,
            Code = spot.Code,
            Name = spot.Name,
            Description = spot.Description,
            Tags = spot.Tags,
            Lat = spot.Lat,
            Lng = spot.Lng,
            IsPublished = spot.IsPublished,
            UpdatedAt = spot.UpdatedAt
        });
    }

    [HttpPost]
    public async Task<ActionResult<SpotResponse>> CreateSpot([FromBody] SpotRequest request)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var codeExists = await _dbContext.Spots.AnyAsync(spot => spot.Code == request.Code);
        if (codeExists)
        {
            return Problem(statusCode: StatusCodes.Status409Conflict, detail: "Spot code already exists.");
        }

        var spot = new Spot
        {
            Id = Guid.NewGuid(),
            Code = request.Code,
            Name = request.Name,
            Description = request.Description,
            Tags = request.Tags,
            Lat = request.Lat,
            Lng = request.Lng,
            IsPublished = request.IsPublished,
            UpdatedAt = DateTimeOffset.UtcNow
        };

        _dbContext.Spots.Add(spot);
        await _dbContext.SaveChangesAsync();

        return CreatedAtAction(nameof(GetSpot), new { id = spot.Id }, new SpotResponse
        {
            Id = spot.Id,
            Code = spot.Code,
            Name = spot.Name,
            Description = spot.Description,
            Tags = spot.Tags,
            Lat = spot.Lat,
            Lng = spot.Lng,
            IsPublished = spot.IsPublished,
            UpdatedAt = spot.UpdatedAt
        });
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<SpotResponse>> UpdateSpot(Guid id, [FromBody] SpotRequest request)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var spot = await _dbContext.Spots.FindAsync(id);
        if (spot is null)
        {
            return NotFound();
        }

        var codeExists = await _dbContext.Spots.AnyAsync(existing => existing.Code == request.Code && existing.Id != id);
        if (codeExists)
        {
            return Problem(statusCode: StatusCodes.Status409Conflict, detail: "Spot code already exists.");
        }

        spot.Code = request.Code;
        spot.Name = request.Name;
        spot.Description = request.Description;
        spot.Tags = request.Tags;
        spot.Lat = request.Lat;
        spot.Lng = request.Lng;
        spot.IsPublished = request.IsPublished;
        spot.UpdatedAt = DateTimeOffset.UtcNow;

        await _dbContext.SaveChangesAsync();

        return Ok(new SpotResponse
        {
            Id = spot.Id,
            Code = spot.Code,
            Name = spot.Name,
            Description = spot.Description,
            Tags = spot.Tags,
            Lat = spot.Lat,
            Lng = spot.Lng,
            IsPublished = spot.IsPublished,
            UpdatedAt = spot.UpdatedAt
        });
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteSpot(Guid id)
    {
        var spot = await _dbContext.Spots.FindAsync(id);
        if (spot is null)
        {
            return NotFound();
        }

        _dbContext.Spots.Remove(spot);
        await _dbContext.SaveChangesAsync();
        return NoContent();
    }

    [HttpPatch("{id:guid}/publish")]
    public async Task<ActionResult<SpotResponse>> PublishSpot(Guid id, [FromBody] PublishRequest request)
    {
        var spot = await _dbContext.Spots.FindAsync(id);
        if (spot is null)
        {
            return NotFound();
        }

        spot.IsPublished = request.IsPublished;
        spot.UpdatedAt = DateTimeOffset.UtcNow;
        await _dbContext.SaveChangesAsync();

        return Ok(new SpotResponse
        {
            Id = spot.Id,
            Code = spot.Code,
            Name = spot.Name,
            Description = spot.Description,
            Tags = spot.Tags,
            Lat = spot.Lat,
            Lng = spot.Lng,
            IsPublished = spot.IsPublished,
            UpdatedAt = spot.UpdatedAt
        });
    }

    [HttpGet("{id:guid}/qr")]
    public async Task<IActionResult> GetSpotQrCode(Guid id)
    {
        var spot = await _dbContext.Spots.FindAsync(id);
        if (spot is null)
        {
            return NotFound();
        }

        var png = _qrCodeService.GenerateQrCodePng(spot.Code);
        return File(png, "image/png");
    }
}

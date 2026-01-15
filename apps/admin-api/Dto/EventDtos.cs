using System.ComponentModel.DataAnnotations;

namespace AdminApi.Dto;

public sealed class EventRequest
{
    [Required]
    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    [Required]
    public DateTimeOffset StartsAt { get; set; }

    [Required]
    public DateTimeOffset EndsAt { get; set; }

    public double? Lat { get; set; }
    public double? Lng { get; set; }
    public string? LocationText { get; set; }
    public bool IsPublished { get; set; } = true;
}

public sealed class EventResponse
{
    public Guid Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset EndsAt { get; set; }
    public double? Lat { get; set; }
    public double? Lng { get; set; }
    public string? LocationText { get; set; }
    public bool IsPublished { get; set; }
}

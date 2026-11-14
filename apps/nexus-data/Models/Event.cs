namespace AdminApi.Models;

public sealed class Event
{
    public Guid Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset EndsAt { get; set; }
    public double? Lat { get; set; }
    public double? Lng { get; set; }
    public string? LocationText { get; set; }
    public bool IsPublished { get; set; } = true;
}

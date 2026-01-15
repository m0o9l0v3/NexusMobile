namespace AdminApi.Models;

public sealed class Spot
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string[]? Tags { get; set; }
    public double? Lat { get; set; }
    public double? Lng { get; set; }
    public bool IsPublished { get; set; } = true;
    public DateTimeOffset UpdatedAt { get; set; }

    // TODO: Reserve extensibility for 3D/AR assets.
    public string? ContentAssets { get; set; }
    public string? ModelRef { get; set; }
}

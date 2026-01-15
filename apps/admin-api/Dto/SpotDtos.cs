using System.ComponentModel.DataAnnotations;

namespace AdminApi.Dto;

public sealed class SpotRequest
{
    [Required]
    public string Code { get; set; } = string.Empty;

    [Required]
    public string Name { get; set; } = string.Empty;

    [Required]
    public string Description { get; set; } = string.Empty;

    public string[]? Tags { get; set; }
    public double? Lat { get; set; }
    public double? Lng { get; set; }
    public bool IsPublished { get; set; } = true;
}

public sealed class SpotResponse
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string[]? Tags { get; set; }
    public double? Lat { get; set; }
    public double? Lng { get; set; }
    public bool IsPublished { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class PublishRequest
{
    public bool IsPublished { get; set; }
}

using System.ComponentModel.DataAnnotations;

namespace AdminApi.Dto;

public sealed class OcDayRequest
{
    [Required]
    public DateOnly Date { get; set; }
    public string? Name { get; set; }
}

public sealed class OcDayResponse
{
    public Guid Id { get; set; }
    public DateOnly Date { get; set; }
    public string? Name { get; set; }
}

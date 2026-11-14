namespace AdminApi.Models;

public sealed class OcDay
{
    public Guid Id { get; set; }
    public DateOnly Date { get; set; }
    public string? Name { get; set; }
}

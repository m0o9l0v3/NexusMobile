namespace AdminApi.Models;

public sealed class Exhibit
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public Guid SpotId { get; set; }
    public Spot? Spot { get; set; }
    public string DepartmentId { get; set; } = string.Empty;
    public Department? Department { get; set; }
    public string? Description { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

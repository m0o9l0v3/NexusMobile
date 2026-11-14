namespace AdminApi.Models;

public sealed class OpenCampusQrSnapshot
{
    public QrSnapshotEvent Event { get; set; } = new();
    public QrSnapshotTimeslot Timeslot { get; set; } = new();
    public List<QrSnapshotExhibit> Exhibits { get; set; } = new();
    public int Version { get; set; } = 1;
}

public sealed class QrSnapshotEvent
{
    public Guid EventId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Date { get; set; } = string.Empty;
}

public sealed class QrSnapshotTimeslot
{
    public Guid TimeslotId { get; set; }
    public string StartsAt { get; set; } = string.Empty;
    public string EndsAt { get; set; } = string.Empty;
}

public sealed class QrSnapshotExhibit
{
    public Guid ExhibitId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string SpotId { get; set; } = string.Empty;
    public string? SpotName { get; set; }
    public string DepartmentId { get; set; } = string.Empty;
    public string DepartmentName { get; set; } = string.Empty;
}

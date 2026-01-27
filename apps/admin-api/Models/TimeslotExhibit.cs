namespace AdminApi.Models;

public sealed class TimeslotExhibit
{
    public Guid TimeslotId { get; set; }
    public OpenCampusTimeslot? Timeslot { get; set; }
    public Guid ExhibitId { get; set; }
    public Exhibit? Exhibit { get; set; }
    public int SortOrder { get; set; }
}

namespace AdminApi.Dto;

public sealed class OpenCampusTimeslotResponse
{
    public Guid Id { get; set; }
    public Guid EventId { get; set; }
    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset EndsAt { get; set; }
}

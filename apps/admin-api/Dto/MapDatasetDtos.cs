using System.ComponentModel.DataAnnotations;
using AdminApi.Services.MapValidation;

namespace AdminApi.Dto;

public sealed class MapDatasetDraftRequest
{
    [Required]
    public string Payload { get; init; } = string.Empty;
}

public sealed record MapDatasetDraftResponse(
    Guid Id,
    long Version,
    string Status,
    string Payload,
    string Checksum,
    DateTimeOffset? PublishedAt);

public sealed record DatasetValidationResponse(
    bool IsValid,
    bool CanPublish,
    IReadOnlyList<ValidationFinding> Errors)
{
    public static DatasetValidationResponse From(DatasetValidationResult result) =>
        new(result.IsValid, result.CanPublish, result.Errors);
}

using System.Data;
using System.Security.Cryptography;
using System.Text;
using AdminApi.Data;
using AdminApi.Dto;
using AdminApi.Models;
using AdminApi.Services.MapValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/map-datasets/drafts")]
[Authorize(Policy = "AdminAccess")]
public sealed class MapDatasetDraftsController : ControllerBase
{
    private readonly AdminDbContext _dbContext;
    private readonly MapDatasetValidator _validator;

    public MapDatasetDraftsController(AdminDbContext dbContext, MapDatasetValidator validator)
    {
        _dbContext = dbContext;
        _validator = validator;
    }

    /// <summary>draft 用の検証を実行する。公開可否の検証は行わない。</summary>
    [HttpPost("validate")]
    [ProducesResponseType<DatasetValidationResponse>(StatusCodes.Status200OK)]
    public ActionResult<DatasetValidationResponse> ValidateDraft(
        [FromBody] MapDatasetDraftRequest request,
        CancellationToken cancellationToken)
    {
        var validation = _validator.Validate(request.Payload, cancellationToken: cancellationToken);
        return Ok(DatasetValidationResponse.From(validation));
    }

    /// <summary>draft 検証に合格した payload を新しい単調増加版として保存する。</summary>
    [HttpPost]
    [ProducesResponseType<MapDatasetDraftResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<DatasetValidationResponse>(StatusCodes.Status422UnprocessableEntity)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MapDatasetDraftResponse>> CreateDraft(
        [FromBody] MapDatasetDraftRequest request,
        CancellationToken cancellationToken)
    {
        var validation = _validator.Validate(request.Payload, cancellationToken: cancellationToken);
        if (!validation.IsValid)
        {
            return UnprocessableEntity(DatasetValidationResponse.From(validation));
        }

        await using var transaction = await _dbContext.Database.BeginTransactionAsync(
            IsolationLevel.Serializable,
            cancellationToken);
        try
        {
            var latestVersion = await _dbContext.MapDatasets
                .Select(dataset => (long?)dataset.Version)
                .MaxAsync(cancellationToken) ?? 0;
            if (latestVersion == long.MaxValue)
            {
                return Problem(
                    statusCode: StatusCodes.Status409Conflict,
                    detail: "MapDataset version has reached its maximum value.");
            }

            var dataset = new MapDataset
            {
                Id = Guid.NewGuid(),
                Version = latestVersion + 1,
                Status = MapDatasetStatus.Draft,
                Payload = request.Payload,
                Checksum = ComputeChecksum(request.Payload),
                PublishedAt = null
            };

            _dbContext.MapDatasets.Add(dataset);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return StatusCode(StatusCodes.Status201Created, ToResponse(dataset));
        }
        catch (Exception exception) when (IsVersionAllocationConflict(exception))
        {
            return Problem(
                statusCode: StatusCodes.Status409Conflict,
                detail: "MapDataset version allocation conflicted with another request. Retry the request.");
        }
    }

    /// <summary>既存の draft payload を検証後に更新し、checksum を再計算する。</summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType<MapDatasetDraftResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<DatasetValidationResponse>(StatusCodes.Status422UnprocessableEntity)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<MapDatasetDraftResponse>> UpdateDraft(
        Guid id,
        [FromBody] MapDatasetDraftRequest request,
        CancellationToken cancellationToken)
    {
        var dataset = await _dbContext.MapDatasets.FindAsync([id], cancellationToken);
        if (dataset is null)
        {
            return NotFound();
        }

        if (!string.Equals(dataset.Status, MapDatasetStatus.Draft, StringComparison.Ordinal))
        {
            return Problem(
                statusCode: StatusCodes.Status409Conflict,
                detail: "Only draft MapDatasets can be updated.");
        }

        var validation = _validator.Validate(request.Payload, cancellationToken: cancellationToken);
        if (!validation.IsValid)
        {
            return UnprocessableEntity(DatasetValidationResponse.From(validation));
        }

        dataset.Payload = request.Payload;
        dataset.Checksum = ComputeChecksum(request.Payload);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToResponse(dataset));
    }

    private static string ComputeChecksum(string payload) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(payload))).ToLowerInvariant();

    private static bool IsVersionAllocationConflict(Exception exception) => exception switch
    {
        PostgresException { SqlState: PostgresErrorCodes.UniqueViolation or PostgresErrorCodes.SerializationFailure } => true,
        SqliteException { SqliteErrorCode: 5 or 6 } => true,
        SqliteException { SqliteExtendedErrorCode: 2067 } => true,
        DbUpdateException { InnerException: Exception innerException } =>
            IsVersionAllocationConflict(innerException),
        _ => false
    };

    private static MapDatasetDraftResponse ToResponse(MapDataset dataset) => new(
        dataset.Id,
        dataset.Version,
        dataset.Status,
        dataset.Payload,
        dataset.Checksum,
        dataset.PublishedAt);
}

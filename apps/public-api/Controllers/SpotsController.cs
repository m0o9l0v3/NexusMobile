using AdminApi.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PublicApi.Dto;
using PublicApi.Helpers;

namespace PublicApi.Controllers;

[ApiController]
[Route("api/spots")]
public sealed class SpotsController : ControllerBase
{
    private readonly AdminDbContext _dbContext;

    public SpotsController(AdminDbContext dbContext)
    {
        _dbContext = dbContext;
    }


    /// <summary>
    /// 公開済みスポット一覧を取得します。
    /// </summary>
    /// <param name="cancellationToken">キャンセル トークン。</param>
    /// <returns>公開済みスポット一覧。</returns>
    [HttpGet("public")]
    [ProducesResponseType<SpotResponse[]>(StatusCodes.Status200OK)]
    public async Task<IResult> GetPublic(CancellationToken cancellationToken)
    {
        var spots = await _dbContext.Spots.AsNoTracking()
            .Where(item => item.IsPublished)
            .OrderBy(item => item.Name)
            .ThenBy(item => item.Code)
            .Select(item => new SpotResponse(
                item.Id,
                item.Code,
                item.Name,
                item.Description,
                SpotAssetHelper.ResolveImageUrl(item.ContentAssets),
                item.Lat,
                item.Lng,
                item.IsPublished,
                item.Tags ?? Array.Empty<string>(),
                item.ModelRef))
            .ToArrayAsync(cancellationToken);

        return Results.Ok(spots);
    }

    /// <summary>
    /// 公開済みスポットをコードで1件取得します。
    /// </summary>
    /// <param name="code">スポット短縮コード。</param>
    /// <param name="cancellationToken">キャンセル トークン。</param>
    /// <returns>スポット情報。</returns>
    [HttpGet("by-code/{code}")]
    [ProducesResponseType<SpotByCodeResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IResult> GetByCode(string code, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            return Results.Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Invalid request",
                detail: "Code is required.");
        }

        var spot = await _dbContext.Spots.AsNoTracking()
            .Where(item => item.IsPublished && item.Code == code)
            .Select(item => new SpotByCodeResponse(
                item.Id,
                item.Code,
                item.Name,
                item.Description,
                SpotAssetHelper.ResolveImageUrl(item.ContentAssets),
                item.Lat,
                item.Lng,
                item.IsPublished,
                item.Tags ?? Array.Empty<string>(),
                item.ModelRef))
            .FirstOrDefaultAsync(cancellationToken);

        return spot is null
            ? Results.Problem(statusCode: StatusCodes.Status404NotFound, title: "Not Found", detail: "Spot not found")
            : Results.Ok(spot);
    }
}


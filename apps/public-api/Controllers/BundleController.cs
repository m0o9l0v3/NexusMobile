using System.Data.Common;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using PublicApi.Services.Delivery;

namespace PublicApi.Controllers;

/// <summary>
/// 参加者向け bundle の配信設定（E2-5 §4.1）。値は運用で見直す仮の値。
/// </summary>
public sealed class ParticipantBundleOptions
{
    public const string SectionName = "ParticipantBundle";

    /// <summary>次の更新確認までの間隔（秒）。<c>Nexus-Recheck-After</c> に入れる（O-9a、既定 300）。</summary>
    public int RecheckAfterSeconds { get; set; } = 300;

    /// <summary>DB に接続できないときの <c>Retry-After</c>（秒）。</summary>
    public int UnavailableRetryAfterSeconds { get; set; } = 30;
}

/// <summary>
/// 参加者向け公開データ（spot と地図の単一 bundle）の配信（E2-5 §4、#23）。認証なし・読み取り専用。
/// rate limit のポリシーは付けない（§4.1.2）。応答の圧縮は edge（Caddy）が行い、ここでは行わない。
/// </summary>
[ApiController]
[Route("api/v2")]
public sealed class BundleController : ControllerBase
{
    public const string NotPublishedType = "urn:nexus:problem:bundle-not-published";
    public const string UnavailableType = "urn:nexus:problem:bundle-unavailable";
    public const string IntegrityType = "urn:nexus:problem:bundle-integrity";

    private readonly IParticipantBundleRepository _repository;
    private readonly ParticipantBundleCache _cache;
    private readonly ParticipantBundleOptions _options;
    private readonly ILogger<BundleController> _logger;

    public BundleController(
        IParticipantBundleRepository repository,
        ParticipantBundleCache cache,
        IOptions<ParticipantBundleOptions> options,
        ILogger<BundleController> logger)
    {
        _repository = repository;
        _cache = cache;
        _options = options.Value;
        _logger = logger;
    }

    /// <summary>
    /// 現在公開中の bundle を返します。<c>If-None-Match</c> が現在の ETag と一致すれば 304 を返します。
    /// </summary>
    /// <remarks>
    /// 完全性の照合は <c>Nexus-Bundle-Sha256</c>・<c>Nexus-Bundle-Length</c> で行い、ETag は照合に使いません（E2-5 §4.1.1）。
    /// </remarks>
    /// <param name="cancellationToken">キャンセル トークン。</param>
    /// <response code="200">現在の bundle。本体は配信表に保存したバイト列そのもの。</response>
    /// <response code="304">端末が保持している版が現在の版と同じ。</response>
    /// <response code="404">まだ一度も公開されていない（urn:nexus:problem:bundle-not-published）。</response>
    /// <response code="500">保存データの破損（urn:nexus:problem:bundle-integrity）。</response>
    /// <response code="503">DB に接続できない（urn:nexus:problem:bundle-unavailable、Retry-After 付き）。</response>
    [HttpGet("bundle")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status304NotModified)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status500InternalServerError, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable, "application/problem+json")]
    public async Task<IActionResult> GetBundle(CancellationToken cancellationToken)
    {
        CurrentParticipantBundle? bundle;
        try
        {
            bundle = await _cache.GetCurrentAsync(_repository, cancellationToken);
        }
        catch (ParticipantBundleIntegrityException exception)
        {
            // 応答には内部の詳細を含めない（§4.3）。
            _logger.LogError("参加者向け bundle の照合に失敗した: {Reason}", exception.Message);
            return ProblemResult(IntegrityType, StatusCodes.Status500InternalServerError, "Bundle integrity check failed");
        }
        catch (Exception exception) when (exception is DbException or TimeoutException
                                          && !cancellationToken.IsCancellationRequested)
        {
            // 接続文字列・例外の内容は応答にもログにも出さない（§4.3）。
            _logger.LogWarning("参加者向け bundle の配信表を読めない: {ExceptionType}", exception.GetType().Name);
            Response.Headers.RetryAfter = _options.UnavailableRetryAfterSeconds.ToString();
            return ProblemResult(UnavailableType, StatusCodes.Status503ServiceUnavailable, "Bundle temporarily unavailable");
        }

        if (bundle is null)
        {
            return ProblemResult(NotPublishedType, StatusCodes.Status404NotFound, "Bundle not published");
        }

        var headers = Response.Headers;
        headers.ETag = bundle.ETag;
        headers["Nexus-Bundle-Sha256"] = bundle.Sha256;
        headers["Nexus-Bundle-Version"] = bundle.BundleVersion.ToString();
        headers["Nexus-Recheck-After"] = _options.RecheckAfterSeconds.ToString();
        headers.CacheControl = "no-cache";

        if (MatchesCurrent(Request.Headers.IfNoneMatch, bundle.ETag))
        {
            return StatusCode(StatusCodes.Status304NotModified);
        }

        headers["Nexus-Bundle-Schema"] = bundle.SchemaVersion;
        headers["Nexus-Bundle-Length"] = bundle.Payload.Length.ToString();
        return File(bundle.Payload, "application/json; charset=utf-8");
    }

    /// <summary><c>If-None-Match</c> の候補のいずれかが現在の ETag と完全一致するか（strong 比較）。</summary>
    private static bool MatchesCurrent(Microsoft.Extensions.Primitives.StringValues ifNoneMatch, string currentETag)
    {
        foreach (var value in ifNoneMatch)
        {
            if (value is null)
            {
                continue;
            }

            foreach (var candidate in value.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
            {
                if (string.Equals(candidate, currentETag, StringComparison.Ordinal))
                {
                    return true;
                }
            }
        }

        return false;
    }

    private static ObjectResult ProblemResult(string type, int statusCode, string title)
    {
        var problem = new ProblemDetails { Type = type, Status = statusCode, Title = title };
        return new ObjectResult(problem)
        {
            StatusCode = statusCode,
            ContentTypes = { "application/problem+json" },
        };
    }
}

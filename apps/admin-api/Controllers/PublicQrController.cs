using AdminApi.Options;
using System.Net;
using System.Text;
using AdminApi.Data;
using AdminApi.Models;
using AdminApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace AdminApi.Controllers;

[ApiController]
[AllowAnonymous]
public sealed class PublicQrController : ControllerBase
{
    private readonly AdminDbContext _dbContext;
    private readonly QrIssueLookupService _lookupService;

    public PublicQrController(AdminDbContext dbContext, QrIssueLookupService lookupService)
    {
        _dbContext = dbContext;
        _lookupService = lookupService;
    }

    [HttpGet("/q/{token}")]
    [EnableRateLimiting(RateLimitPolicies.QrLanding)]
    public async Task<IActionResult> Show(string token)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            return Content(BuildInvalidPage("無効なQRです。"), "text/html; charset=utf-8");
        }

        var resolution = await _lookupService.ResolveAsync(token, DateTimeOffset.UtcNow, HttpContext.RequestAborted);
        if (resolution.Status == QrIssueStatus.NotFound)
        {
            return Content(BuildInvalidPage("このQRは見つかりませんでした。"), "text/html; charset=utf-8");
        }

        if (resolution.Status == QrIssueStatus.Revoked)
        {
            return Content(BuildInvalidPage("このQRは失効しました。"), "text/html; charset=utf-8");
        }

        if (resolution.Status == QrIssueStatus.Expired)
        {
            return Content(BuildInvalidPage("このQRは期限切れです。"), "text/html; charset=utf-8");
        }

        if (resolution.Status == QrIssueStatus.InvalidSnapshot || resolution.Snapshot is null || resolution.Issue is null)
        {
            return Content(BuildInvalidPage("表示データの読み込みに失敗しました。"), "text/html; charset=utf-8");
        }

        var issue = resolution.Issue;
        issue.ScanCount += 1;
        issue.LastScannedAt = DateTimeOffset.UtcNow;
        await _dbContext.SaveChangesAsync();

        return Content(BuildSnapshotPage(resolution.Snapshot), "text/html; charset=utf-8");
    }

    private static string BuildSnapshotPage(OpenCampusQrSnapshot snapshot)
    {
        var eventTitle = WebUtility.HtmlEncode(snapshot.Event.Title);
        var eventDate = WebUtility.HtmlEncode(snapshot.Event.Date);
        var startsAt = WebUtility.HtmlEncode(snapshot.Timeslot.StartsAt);
        var endsAt = WebUtility.HtmlEncode(snapshot.Timeslot.EndsAt);

        var builder = new StringBuilder();
        builder.AppendLine("<!doctype html>");
        builder.AppendLine("<html lang=\"ja\">");
        builder.AppendLine("<head>");
        builder.AppendLine("<meta charset=\"utf-8\" />");
        builder.AppendLine("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />");
        builder.AppendLine($"<title>{eventTitle} | オープンキャンパス</title>");
        builder.AppendLine("<style>");
        builder.AppendLine("body{font-family:'Noto Sans JP',sans-serif;margin:0;background:#f5f6f9;color:#1e1e1e;}");
        builder.AppendLine(".container{max-width:540px;margin:0 auto;padding:20px;}");
        builder.AppendLine(".card{background:#fff;border-radius:16px;padding:16px;box-shadow:0 8px 20px rgba(0,0,0,0.06);}");
        builder.AppendLine(".title{font-size:1.2rem;font-weight:700;margin-bottom:8px;}");
        builder.AppendLine(".meta{color:#555;font-size:0.9rem;margin-bottom:12px;}");
        builder.AppendLine(".list{display:grid;gap:10px;}");
        builder.AppendLine(".item{padding:12px;border-radius:12px;background:#f0f4ff;border:1px solid #dfe6ff;}");
        builder.AppendLine(".item-title{font-weight:700;margin-bottom:4px;}");
        builder.AppendLine(".item-sub{font-size:0.85rem;color:#3f4a63;}");
        builder.AppendLine("</style>");
        builder.AppendLine("</head>");
        builder.AppendLine("<body>");
        builder.AppendLine("<div class=\"container\">");
        builder.AppendLine("<div class=\"card\">");
        builder.AppendLine($"<div class=\"title\">{eventTitle}</div>");
        builder.AppendLine($"<div class=\"meta\">{eventDate} / {startsAt} - {endsAt}</div>");
        builder.AppendLine("<div class=\"list\">");

        foreach (var exhibit in snapshot.Exhibits)
        {
            var name = WebUtility.HtmlEncode(exhibit.Name);
            var spotId = WebUtility.HtmlEncode(exhibit.SpotId);
            var spotName = WebUtility.HtmlEncode(exhibit.SpotName ?? string.Empty);
            var departmentName = WebUtility.HtmlEncode(exhibit.DepartmentName);
            builder.AppendLine("<div class=\"item\">");
            builder.AppendLine($"<div class=\"item-title\">{name}</div>");
            builder.AppendLine($"<div class=\"item-sub\">スポット: {spotId}{(string.IsNullOrEmpty(spotName) ? string.Empty : $" ({spotName})")} / 学科: {departmentName}</div>");
            builder.AppendLine("</div>");
        }

        if (snapshot.Exhibits.Count == 0)
        {
            builder.AppendLine("<div class=\"item\">");
            builder.AppendLine("<div class=\"item-title\">展示情報が登録されていません</div>");
            builder.AppendLine("</div>");
        }

        builder.AppendLine("</div>");
        builder.AppendLine("</div>");
        builder.AppendLine("</div>");
        builder.AppendLine("</body>");
        builder.AppendLine("</html>");
        return builder.ToString();
    }

    private static string BuildInvalidPage(string message)
    {
        var encoded = WebUtility.HtmlEncode(message);
        return $"<!doctype html><html lang=\"ja\"><head><meta charset=\"utf-8\" /><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" /><title>QR無効</title><style>body{{font-family:'Noto Sans JP',sans-serif;margin:0;background:#f5f6f9;color:#1e1e1e;}}.container{{max-width:540px;margin:0 auto;padding:20px;}}.card{{background:#fff;border-radius:16px;padding:20px;box-shadow:0 8px 20px rgba(0,0,0,0.06);}}</style></head><body><div class=\"container\"><div class=\"card\"><h1>このQRは無効です</h1><p>{encoded}</p></div></div></body></html>";
    }
}

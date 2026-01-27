using AdminApi.Data;
using AdminApi.Models;
using AdminApi.Options;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AdminApi.Services;

public sealed class OneTimeLoginService
{
    private readonly AdminDbContext _dbContext;
    private readonly OneTimeCodeService _codeService;
    private readonly JwtTokenService _tokenService;
    private readonly PortalOptions _portalOptions;
    private readonly TimeZoneInfo _jstTimeZone;

    public OneTimeLoginService(
        AdminDbContext dbContext,
        OneTimeCodeService codeService,
        JwtTokenService tokenService,
        IOptions<PortalOptions> portalOptions)
    {
        _dbContext = dbContext;
        _codeService = codeService;
        _tokenService = tokenService;
        _portalOptions = portalOptions.Value;
        _jstTimeZone = ResolveJstTimeZone();
    }

    public async Task<OneTimeCodeGenerationResult?> GenerateCodesAsync(Guid eventId, int count, CancellationToken cancellationToken)
    {
        var eventItem = await _dbContext.Events.FindAsync([eventId], cancellationToken);
        if (eventItem is null)
        {
            return null;
        }

        var expiresAt = GetEventEndOfDayUtc(eventItem.StartsAt);
        var payloads = new List<OneTimeCodePayload>();

        for (var i = 0; i < count; i++)
        {
            string code;
            string codeHash;

            do
            {
                code = _codeService.GenerateCode();
                codeHash = _codeService.HashCode(code);
            } while (await _dbContext.OneTimeLoginCodes.AnyAsync(existing => existing.CodeHash == codeHash, cancellationToken));

            var entity = new OneTimeLoginCode
            {
                Id = Guid.NewGuid(),
                CodeHash = codeHash,
                EventId = eventItem.Id,
                ExpiresAt = expiresAt,
                CreatedAt = DateTimeOffset.UtcNow
            };

            _dbContext.OneTimeLoginCodes.Add(entity);

            payloads.Add(new OneTimeCodePayload
            {
                Code = code,
                RedeemUrl = BuildRedeemUrl(code)
            });
        }

        await _dbContext.SaveChangesAsync(cancellationToken);

        return new OneTimeCodeGenerationResult(eventItem.Id, expiresAt, payloads);
    }

    public async Task<OneTimeCodeRedemptionResult?> RedeemAsync(string code, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var codeHash = _codeService.HashCode(code);
        var entity = await _dbContext.OneTimeLoginCodes
            .FirstOrDefaultAsync(item => item.CodeHash == codeHash, cancellationToken);

        if (entity is null || entity.UsedAt.HasValue || entity.ExpiresAt < now)
        {
            return null;
        }

        entity.UsedAt = now;
        entity.UsedByUuid = Guid.NewGuid();

        await _dbContext.SaveChangesAsync(cancellationToken);

        var token = _tokenService.CreateVisitorToken(entity.UsedByUuid.Value, entity.EventId, entity.ExpiresAt);

        return new OneTimeCodeRedemptionResult(entity.EventId, entity.UsedByUuid.Value, entity.ExpiresAt, token);
    }

    private DateTimeOffset GetEventEndOfDayUtc(DateTimeOffset eventStart)
    {
        var jstTime = TimeZoneInfo.ConvertTime(eventStart, _jstTimeZone);
        var jstDate = jstTime.Date;
        var endOfDayJst = new DateTime(jstDate.Year, jstDate.Month, jstDate.Day, 23, 59, 59, DateTimeKind.Unspecified);
        var offset = _jstTimeZone.GetUtcOffset(endOfDayJst);
        return new DateTimeOffset(endOfDayJst, offset).ToUniversalTime();
    }

    private string BuildRedeemUrl(string code)
    {
        return $"{_portalOptions.ParticipantBaseUrl.TrimEnd('/')}/?code={Uri.EscapeDataString(code)}";
    }

    private static TimeZoneInfo ResolveJstTimeZone()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Asia/Tokyo");
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Tokyo Standard Time");
        }
    }
}

public sealed record OneTimeCodePayload
{
    public string Code { get; init; } = string.Empty;
    public string RedeemUrl { get; init; } = string.Empty;
}

public sealed record OneTimeCodeGenerationResult(Guid EventId, DateTimeOffset ExpiresAt, IReadOnlyList<OneTimeCodePayload> Codes);

public sealed record OneTimeCodeRedemptionResult(Guid EventId, Guid VisitorId, DateTimeOffset ExpiresAt, string AccessToken);

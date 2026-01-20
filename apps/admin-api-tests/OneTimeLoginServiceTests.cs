using AdminApi.Data;
using AdminApi.Models;
using AdminApi.Options;
using AdminApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace AdminApi.Tests;

public sealed class OneTimeLoginServiceTests
{
    private static AdminDbContext BuildContext()
    {
        var options = new DbContextOptionsBuilder<AdminDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AdminDbContext(options);
    }

    private static OneTimeLoginService BuildService(AdminDbContext context, OneTimeCodeService codeService)
    {
        var authOptions = Microsoft.Extensions.Options.Options.Create(new AdminAuthOptions { SigningKey = "test_signing_key_1234567890_abcdef" });
        var portalOptions = Microsoft.Extensions.Options.Options.Create(new PortalOptions { ParticipantBaseUrl = "https://example.local" });
        var tokenService = new JwtTokenService(authOptions, new TokenRevocationService(context));
        return new OneTimeLoginService(context, codeService, tokenService, portalOptions);
    }

    [Fact]
    public async Task RedeemAsync_AllowsUnusedCode()
    {
        await using var context = BuildContext();
        var codeOptions = Microsoft.Extensions.Options.Options.Create(new OneTimeCodeOptions { HashKey = "hash_key_1234567890" });
        var codeService = new OneTimeCodeService(codeOptions);
        var service = BuildService(context, codeService);

        var eventId = Guid.NewGuid();
        context.Events.Add(new Event
        {
            Id = eventId,
            Title = "Open Campus",
            StartsAt = DateTimeOffset.UtcNow,
            EndsAt = DateTimeOffset.UtcNow.AddHours(8)
        });

        var code = codeService.GenerateCode();
        context.OneTimeLoginCodes.Add(new OneTimeLoginCode
        {
            Id = Guid.NewGuid(),
            CodeHash = codeService.HashCode(code),
            EventId = eventId,
            ExpiresAt = DateTimeOffset.UtcNow.AddHours(1),
            CreatedAt = DateTimeOffset.UtcNow
        });

        await context.SaveChangesAsync();

        var result = await service.RedeemAsync(code, CancellationToken.None);

        Assert.NotNull(result);
        Assert.False(string.IsNullOrWhiteSpace(result!.AccessToken));
        Assert.Equal(eventId, result.EventId);
        Assert.NotEqual(Guid.Empty, result.VisitorId);
    }

    [Fact]
    public async Task RedeemAsync_DeniesUsedCode()
    {
        await using var context = BuildContext();
        var codeOptions = Microsoft.Extensions.Options.Options.Create(new OneTimeCodeOptions { HashKey = "hash_key_1234567890" });
        var codeService = new OneTimeCodeService(codeOptions);
        var service = BuildService(context, codeService);

        var eventId = Guid.NewGuid();
        context.Events.Add(new Event
        {
            Id = eventId,
            Title = "Open Campus",
            StartsAt = DateTimeOffset.UtcNow,
            EndsAt = DateTimeOffset.UtcNow.AddHours(8)
        });

        var code = codeService.GenerateCode();
        context.OneTimeLoginCodes.Add(new OneTimeLoginCode
        {
            Id = Guid.NewGuid(),
            CodeHash = codeService.HashCode(code),
            EventId = eventId,
            ExpiresAt = DateTimeOffset.UtcNow.AddHours(1),
            UsedAt = DateTimeOffset.UtcNow,
            UsedByUuid = Guid.NewGuid(),
            CreatedAt = DateTimeOffset.UtcNow
        });

        await context.SaveChangesAsync();

        var result = await service.RedeemAsync(code, CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task RedeemAsync_DeniesExpiredCode()
    {
        await using var context = BuildContext();
        var codeOptions = Microsoft.Extensions.Options.Options.Create(new OneTimeCodeOptions { HashKey = "hash_key_1234567890" });
        var codeService = new OneTimeCodeService(codeOptions);
        var service = BuildService(context, codeService);

        var eventId = Guid.NewGuid();
        context.Events.Add(new Event
        {
            Id = eventId,
            Title = "Open Campus",
            StartsAt = DateTimeOffset.UtcNow,
            EndsAt = DateTimeOffset.UtcNow.AddHours(8)
        });

        var code = codeService.GenerateCode();
        context.OneTimeLoginCodes.Add(new OneTimeLoginCode
        {
            Id = Guid.NewGuid(),
            CodeHash = codeService.HashCode(code),
            EventId = eventId,
            ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(-1),
            CreatedAt = DateTimeOffset.UtcNow.AddHours(-1)
        });

        await context.SaveChangesAsync();

        var result = await service.RedeemAsync(code, CancellationToken.None);

        Assert.Null(result);
    }
}

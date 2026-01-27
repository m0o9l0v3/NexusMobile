using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using AdminApi.Data;
using AdminApi.Models;
using AdminApi.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace AdminApi.Tests;

public sealed class TokenRevocationValidatorTests
{
    private static AdminDbContext BuildContext()
    {
        var options = new DbContextOptionsBuilder<AdminDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new AdminDbContext(options);
    }

    [Fact]
    public async Task OnTokenValidated_FailsWhenRevoked()
    {
        await using var context = BuildContext();
        context.RevokedTokens.Add(new RevokedToken
        {
            Jti = "revoked_jti",
            RevokedAt = DateTimeOffset.UtcNow,
            ExpiresAt = DateTimeOffset.UtcNow.AddHours(1)
        });
        await context.SaveChangesAsync();

        var validator = new TokenRevocationValidator();
        var options = new JwtBearerOptions();
        validator.PostConfigure(JwtBearerDefaults.AuthenticationScheme, options);

        var httpContext = new DefaultHttpContext();
        var services = new ServiceCollection()
            .AddScoped(_ => new TokenRevocationService(context))
            .BuildServiceProvider();
        httpContext.RequestServices = services;
        var scheme = new AuthenticationScheme(JwtBearerDefaults.AuthenticationScheme, "Bearer", typeof(JwtBearerHandler));
        var principal = new ClaimsPrincipal(new ClaimsIdentity(new[]
        {
            new Claim(JwtRegisteredClaimNames.Jti, "revoked_jti")
        }, JwtBearerDefaults.AuthenticationScheme));

        var tokenValidatedContext = new TokenValidatedContext(httpContext, scheme, options)
        {
            Principal = principal
        };

        await options.Events.OnTokenValidated(tokenValidatedContext);

        Assert.NotNull(tokenValidatedContext.Result);
        Assert.NotNull(tokenValidatedContext.Result?.Failure);
        Assert.Equal("revoked", tokenValidatedContext.Result?.Failure?.Message);
    }
}

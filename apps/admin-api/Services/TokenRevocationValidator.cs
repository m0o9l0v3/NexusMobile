using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.DependencyInjection;

namespace AdminApi.Services;

public sealed class TokenRevocationValidator : IPostConfigureOptions<JwtBearerOptions>
{
    public void PostConfigure(string? name, JwtBearerOptions options)
    {
        options.Events ??= new JwtBearerEvents();
        var originalOnTokenValidated = options.Events.OnTokenValidated;
        options.Events.OnTokenValidated = async context =>
        {
            if (originalOnTokenValidated != null)
            {
                await originalOnTokenValidated(context);
            }

            var jti = context.Principal?.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Jti)?.Value;
            if (string.IsNullOrWhiteSpace(jti))
            {
                context.Fail("missing_jti");
                return;
            }

            var tokenRevocationService = context.HttpContext.RequestServices.GetRequiredService<TokenRevocationService>();
            if (await tokenRevocationService.IsRevokedAsync(jti, context.HttpContext.RequestAborted))
            {
                context.Fail("revoked");
            }
        };
    }
}

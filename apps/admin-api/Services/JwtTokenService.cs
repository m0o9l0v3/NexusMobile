using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using AdminApi.Options;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace AdminApi.Services;

public sealed class JwtTokenService
{
    private readonly AdminAuthOptions _options;
    private readonly TokenRevocationService _tokenRevocationService;

    public JwtTokenService(IOptions<AdminAuthOptions> options, TokenRevocationService tokenRevocationService)
    {
        _options = options.Value;
        _tokenRevocationService = tokenRevocationService;
    }

    public string CreateToken(string username)
    {
        return CreateToken(username, _options.Role, DateTimeOffset.UtcNow.AddMinutes(_options.TokenExpiresMinutes));
    }

    public string CreateToken(string username, string role, DateTimeOffset expiresAt)
    {
        var issuedAt = DateTimeOffset.UtcNow;
        var jti = Guid.NewGuid().ToString();
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, username),
            new Claim(JwtRegisteredClaimNames.Jti, jti),
            new Claim("role", role)
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            expires: expiresAt.UtcDateTime,
            signingCredentials: creds);

        _tokenRevocationService.RecordIssuedAsync(jti, username, issuedAt, expiresAt, CancellationToken.None)
            .GetAwaiter()
            .GetResult();
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public string CreateVisitorToken(Guid visitorId, Guid eventId, DateTimeOffset expiresAt)
    {
        var issuedAt = DateTimeOffset.UtcNow;
        var jti = Guid.NewGuid().ToString();
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, visitorId.ToString()),
            new Claim(JwtRegisteredClaimNames.Jti, jti),
            new Claim("role", "Visitor"),
            new Claim("event_id", eventId.ToString())
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var finalExpiresAt = expiresAt.UtcDateTime < DateTime.UtcNow
            ? DateTimeOffset.UtcNow.AddMinutes(_options.VisitorTokenExpiresMinutes)
            : expiresAt;
        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            expires: finalExpiresAt.UtcDateTime,
            signingCredentials: creds);

        _tokenRevocationService.RecordIssuedAsync(jti, visitorId.ToString(), issuedAt, finalExpiresAt, CancellationToken.None)
            .GetAwaiter()
            .GetResult();
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

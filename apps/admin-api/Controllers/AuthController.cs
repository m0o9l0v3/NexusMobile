using AdminApi.Dto;
using AdminApi.Options;
using AdminApi.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly AdminAuthOptions _options;
    private readonly JwtTokenService _tokenService;

    public AuthController(IOptions<AdminAuthOptions> options, JwtTokenService tokenService)
    {
        _options = options.Value;
        _tokenService = tokenService;
    }

    [HttpPost("login")]
    [EnableRateLimiting(RateLimitPolicies.AuthLogin)]
    public ActionResult<LoginResponse> Login([FromBody] LoginRequest request)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        if (!string.Equals(request.Username, _options.Username, StringComparison.Ordinal) ||
            !string.Equals(request.Password, _options.Password, StringComparison.Ordinal))
        {
            return Unauthorized();
        }

        var token = _tokenService.CreateToken(request.Username);
        return Ok(new LoginResponse { AccessToken = token });
    }
}

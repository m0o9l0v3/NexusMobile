using AdminApi.Dto;
using AdminApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/tokens")]
[Authorize(Policy = "AdminAccess")]
public sealed class TokenRevocationController : ControllerBase
{
    private readonly TokenRevocationService _tokenRevocationService;

    public TokenRevocationController(TokenRevocationService tokenRevocationService)
    {
        _tokenRevocationService = tokenRevocationService;
    }

    [HttpPost("revoke")]
    public async Task<ActionResult<TokenRevocationResponse>> RevokeByJti([FromBody] TokenRevocationRequest request, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var revokedBy = User.Identity?.Name ?? User.FindFirst("sub")?.Value;
        var revoked = await _tokenRevocationService.RevokeAsync(request.Jti, request.Reason, revokedBy, cancellationToken);
        return Ok(new TokenRevocationResponse { Revoked = revoked });
    }

    [HttpPost("revoke-user")]
    public async Task<ActionResult<UserTokenRevocationResponse>> RevokeBySubject([FromBody] UserTokenRevocationRequest request, CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var revokedBy = User.Identity?.Name ?? User.FindFirst("sub")?.Value;
        var revokedCount = await _tokenRevocationService.RevokeBySubjectAsync(request.Subject, request.Reason, revokedBy, cancellationToken);
        return Ok(new UserTokenRevocationResponse { RevokedCount = revokedCount });
    }
}

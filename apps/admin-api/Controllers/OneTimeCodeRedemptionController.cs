using AdminApi.Dto;
using AdminApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/one-time-codes")]
public sealed class OneTimeCodeRedemptionController : ControllerBase
{
    private readonly OneTimeLoginService _oneTimeLoginService;

    public OneTimeCodeRedemptionController(OneTimeLoginService oneTimeLoginService)
    {
        _oneTimeLoginService = oneTimeLoginService;
    }

    [AllowAnonymous]
    [HttpPost("redeem")]
    public async Task<ActionResult<OneTimeCodeRedeemResponse>> Redeem(
        [FromBody] OneTimeCodeRedeemRequest request,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var result = await _oneTimeLoginService.RedeemAsync(request.Code, cancellationToken);
        if (result is null)
        {
            return Problem(statusCode: StatusCodes.Status400BadRequest, detail: "invalid_or_expired");
        }

        return Ok(new OneTimeCodeRedeemResponse
        {
            EventId = result.EventId,
            VisitorId = result.VisitorId,
            ExpiresAt = result.ExpiresAt,
            AccessToken = result.AccessToken
        });
    }
}

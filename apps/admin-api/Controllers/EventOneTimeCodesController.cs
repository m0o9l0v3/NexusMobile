using AdminApi.Dto;
using AdminApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AdminApi.Controllers;

[ApiController]
[Route("admin/events/{eventId:guid}/one-time-codes")]
[Authorize(Policy = "AdminAccess")]
public sealed class EventOneTimeCodesController : ControllerBase
{
    private readonly OneTimeLoginService _oneTimeLoginService;

    public EventOneTimeCodesController(OneTimeLoginService oneTimeLoginService)
    {
        _oneTimeLoginService = oneTimeLoginService;
    }

    [HttpPost]
    public async Task<ActionResult<OneTimeCodeGenerateResponse>> GenerateCodes(
        Guid eventId,
        [FromBody] OneTimeCodeGenerateRequest request,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return ValidationProblem(ModelState);
        }

        var result = await _oneTimeLoginService.GenerateCodesAsync(eventId, request.Count, cancellationToken);
        if (result is null)
        {
            return NotFound();
        }

        return CreatedAtAction(nameof(GenerateCodes), new { eventId }, new OneTimeCodeGenerateResponse
        {
            EventId = result.EventId,
            ExpiresAt = result.ExpiresAt,
            Codes = result.Codes.Select(code => new OneTimeCodePayloadResponse
            {
                Code = code.Code,
                RedeemUrl = code.RedeemUrl
            }).ToList()
        });
    }
}

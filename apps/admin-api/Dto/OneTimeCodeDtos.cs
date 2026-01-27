using System.ComponentModel.DataAnnotations;

namespace AdminApi.Dto;

public sealed class OneTimeCodeGenerateRequest
{
    [Range(1, 1000)]
    public int Count { get; init; } = 1;
}

public sealed class OneTimeCodeGenerateResponse
{
    public Guid EventId { get; init; }
    public DateTimeOffset ExpiresAt { get; init; }
    public IReadOnlyList<OneTimeCodePayloadResponse> Codes { get; init; } = Array.Empty<OneTimeCodePayloadResponse>();
}

public sealed class OneTimeCodePayloadResponse
{
    public string Code { get; init; } = string.Empty;
    public string RedeemUrl { get; init; } = string.Empty;
}

public sealed class OneTimeCodeRedeemRequest
{
    [Required]
    public string Code { get; init; } = string.Empty;
}

public sealed class OneTimeCodeRedeemResponse
{
    public Guid EventId { get; init; }
    public Guid VisitorId { get; init; }
    public DateTimeOffset ExpiresAt { get; init; }
    public string AccessToken { get; init; } = string.Empty;
}

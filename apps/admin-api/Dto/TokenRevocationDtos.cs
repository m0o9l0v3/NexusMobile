using System.ComponentModel.DataAnnotations;

namespace AdminApi.Dto;

public sealed class TokenRevocationRequest
{
    [Required]
    public string Jti { get; init; } = string.Empty;

    public string? Reason { get; init; }
}

public sealed class UserTokenRevocationRequest
{
    [Required]
    public string Subject { get; init; } = string.Empty;

    public string? Reason { get; init; }
}

public sealed class TokenRevocationResponse
{
    public bool Revoked { get; init; }
}

public sealed class UserTokenRevocationResponse
{
    public int RevokedCount { get; init; }
}

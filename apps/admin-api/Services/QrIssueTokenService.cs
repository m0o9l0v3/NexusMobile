using System.Security.Cryptography;
using System.Text;
using AdminApi.Options;
using Microsoft.Extensions.Options;

namespace AdminApi.Services;

public sealed class QrIssueTokenService
{
    private readonly QrIssueOptions _options;

    public QrIssueTokenService(IOptions<QrIssueOptions> options)
    {
        _options = options.Value;
    }

    public string GenerateToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(_options.TokenBytesLength);
        return Base64UrlEncode(bytes);
    }

    public string HashToken(string token)
    {
        var keyBytes = Encoding.UTF8.GetBytes(_options.HashKey);
        using var hmac = new HMACSHA256(keyBytes);
        var hashBytes = hmac.ComputeHash(Encoding.UTF8.GetBytes(token));
        return Convert.ToBase64String(hashBytes);
    }

    public string BuildPublicUrl(string token)
    {
        return $"{_options.PublicBaseUrl.TrimEnd('/')}/q/{token}";
    }

    private static string Base64UrlEncode(byte[] data)
    {
        return Convert.ToBase64String(data)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }
}

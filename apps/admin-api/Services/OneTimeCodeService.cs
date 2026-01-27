using System.Security.Cryptography;
using System.Text;
using AdminApi.Options;
using Microsoft.Extensions.Options;

namespace AdminApi.Services;

public sealed class OneTimeCodeService
{
    private readonly OneTimeCodeOptions _options;

    public OneTimeCodeService(IOptions<OneTimeCodeOptions> options)
    {
        _options = options.Value;
    }

    public string GenerateCode()
    {
        var bytes = RandomNumberGenerator.GetBytes(_options.CodeBytesLength);
        return Base64UrlEncode(bytes);
    }

    public string HashCode(string code)
    {
        var keyBytes = Encoding.UTF8.GetBytes(_options.HashKey);
        using var hmac = new HMACSHA256(keyBytes);
        var hashBytes = hmac.ComputeHash(Encoding.UTF8.GetBytes(code));
        return Convert.ToBase64String(hashBytes);
    }

    private static string Base64UrlEncode(byte[] data)
    {
        return Convert.ToBase64String(data)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }
}

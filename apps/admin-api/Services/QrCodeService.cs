using AdminApi.Options;
using Microsoft.Extensions.Options;
using QRCoder;

namespace AdminApi.Services;

public sealed class QrCodeService
{
    private readonly PortalOptions _portalOptions;

    public QrCodeService(IOptions<PortalOptions> portalOptions)
    {
        _portalOptions = portalOptions.Value;
    }

    public byte[] GenerateQrCodePng(string code)
    {
        var url = $"{_portalOptions.ParticipantBaseUrl.TrimEnd('/')}/?code={Uri.EscapeDataString(code)}";
        using var generator = new QRCodeGenerator();
        using var data = generator.CreateQrCode(url, QRCodeGenerator.ECCLevel.Q);
        using var qrCode = new PngByteQRCode(data);
        return qrCode.GetGraphic(10);
    }
}

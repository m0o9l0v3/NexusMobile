using Microsoft.Extensions.Configuration;

namespace AdminApi.Options;

/// <summary>
/// admin-api の許可オリジン（<c>Cors:Origins</c>）を読む。本番の雛形は <c>NEXUS_ADMIN_ORIGIN</c> が未設定だと
/// <c>Cors__Origins__0</c> に空文字を渡すため、空・空白の値を取り除く（E8-7 C-4、#72）。
/// </summary>
public static class CorsOrigins
{
    public static string[] FromConfiguration(IConfigurationSection section) =>
        (section.Get<string[]>() ?? Array.Empty<string>())
            .Where(origin => !string.IsNullOrWhiteSpace(origin))
            .Select(origin => origin.Trim())
            .ToArray();
}

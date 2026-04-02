using System.Text.Json;

namespace PublicApi.Helpers;

public static class SpotAssetHelper
{
    public static string? ResolveImageUrl(string? contentAssets)
    {
        if (string.IsNullOrWhiteSpace(contentAssets))
        {
            return null;
        }

        if (Uri.TryCreate(contentAssets, UriKind.Absolute, out _))
        {
            return contentAssets;
        }

        try
        {
            using var document = JsonDocument.Parse(contentAssets);
            var root = document.RootElement;

            if (root.ValueKind != JsonValueKind.Object)
            {
                return null;
            }

            if (TryReadString(root, "imageUrl", out var imageUrl))
            {
                return imageUrl;
            }

            if (TryReadString(root, "image", out var image))
            {
                return image;
            }

            if (root.TryGetProperty("images", out var images) && images.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in images.EnumerateArray())
                {
                    if (item.ValueKind == JsonValueKind.String)
                    {
                        var value = item.GetString();
                        if (!string.IsNullOrWhiteSpace(value))
                        {
                            return value;
                        }
                    }

                    if (item.ValueKind == JsonValueKind.Object && TryReadString(item, "url", out var url))
                    {
                        return url;
                    }
                }
            }
        }
        catch (JsonException)
        {
            return null;
        }

        return null;
    }

    private static bool TryReadString(JsonElement root, string propertyName, out string value)
    {
        if (root.TryGetProperty(propertyName, out var element) && element.ValueKind == JsonValueKind.String)
        {
            var raw = element.GetString();
            if (!string.IsNullOrWhiteSpace(raw))
            {
                value = raw;
                return true;
            }
        }

        value = string.Empty;
        return false;
    }
}


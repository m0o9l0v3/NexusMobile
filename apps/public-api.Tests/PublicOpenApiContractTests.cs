using Xunit;

namespace PublicApi.Tests;

public sealed class PublicOpenApiContractTests
{
    [Fact]
    public void PublicYaml_DefinesIssue6EndpointsAndResponses()
    {
        var yaml = File.ReadAllText(Path.Combine(FindRepositoryRoot(), "openapi", "public.yaml"));

        var spotByCode = ExtractPath(yaml, "/api/spots/by-code/{code}");
        Assert.Contains("required: true", spotByCode);
        Assert.Contains("\n        \"200\":", spotByCode);
        Assert.Contains("\n        \"400\":", spotByCode);
        Assert.Contains("\n        \"404\":", spotByCode);
        Assert.Contains("#/components/schemas/SpotByCodeResponse", spotByCode);
    }

    /// 静的な経路デモ API（phase1-navigation.json）は #21 で撤去した。参加者の地点・地図は
    /// `GET /api/v2/bundle`（E2-5）だけで配る。
    [Fact]
    public void NavigationDemoPaths_AreRemoved()
    {
        var yaml = File.ReadAllText(Path.Combine(FindRepositoryRoot(), "openapi", "public.yaml"));

        foreach (var path in new[] { "/api/navigation/spots", "/api/navigation/spots/{id}", "/api/floors", "/api/routes" })
        {
            Assert.DoesNotContain($"  {path}:", yaml);
            Assert.DoesNotContain($"  \"{path}\":", yaml);
        }
        foreach (var schema in new[] { "FloorMapDto", "RouteDto", "RoutePointDto", "SpotDto:" })
        {
            Assert.DoesNotContain(schema, yaml);
        }
    }

    [Fact]
    public void LogIngestionPaths_DocumentRateLimitResponse()
    {
        var yaml = File.ReadAllText(Path.Combine(FindRepositoryRoot(), "openapi", "public.yaml"));

        foreach (var path in new[] { "/api/logs", "/api/logs/batch" })
        {
            var section = ExtractPath(yaml, path);
            Assert.Contains("\n        \"429\":", section);
            Assert.Contains("Retry-After:", section);
        }
    }

    [Fact]
    public void BundlePath_DocumentsDeliveryContractV2()
    {
        var yaml = File.ReadAllText(Path.Combine(FindRepositoryRoot(), "openapi", "public.yaml"));

        var bundle = ExtractPath(yaml, "/api/v2/bundle");
        Assert.Contains("\n    get:", bundle);
        Assert.Contains("- name: If-None-Match", bundle);
        foreach (var status in new[] { "200", "304", "404", "500", "503" })
        {
            Assert.Contains($"\n        \"{status}\":", bundle);
        }
        foreach (var header in new[] { "ETag:", "Nexus-Bundle-Sha256:", "Nexus-Bundle-Version:", "Nexus-Bundle-Schema:", "Nexus-Bundle-Length:", "Nexus-Recheck-After:", "Retry-After:" })
        {
            Assert.Contains(header, bundle);
        }
        Assert.Contains("bundle-not-published", bundle);
        Assert.Contains("bundle-integrity", bundle);
        Assert.Contains("bundle-unavailable", bundle);
    }

    private static string ExtractPath(string yaml, string path)
    {
        var lines = yaml.Replace("\r\n", "\n", StringComparison.Ordinal).Split('\n');
        var candidates = new[] { $"  {path}:", $"  \"{path}\":" };
        var start = Array.FindIndex(lines, line => candidates.Contains(line, StringComparer.Ordinal));
        Assert.True(start >= 0, $"OpenAPI に {path} が定義されていません。");

        var end = start + 1;
        while (end < lines.Length && (string.IsNullOrWhiteSpace(lines[end]) || lines[end].StartsWith("    ", StringComparison.Ordinal)))
        {
            end++;
        }

        return string.Join('\n', lines[start..end]);
    }

    private static string FindRepositoryRoot()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "Nexus.sln")))
            {
                return directory.FullName;
            }
        }

        throw new DirectoryNotFoundException("Nexus.sln が見つかりません。");
    }
}

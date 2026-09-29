using Xunit;

namespace PublicApi.Tests;

public sealed class PublicOpenApiContractTests
{
    [Fact]
    public void PublicYaml_DefinesIssue6EndpointsAndResponses()
    {
        var yaml = File.ReadAllText(Path.Combine(FindRepositoryRoot(), "openapi", "public.yaml"));

        var floors = ExtractPath(yaml, "/api/floors");
        Assert.Contains("\n    get:", floors);
        Assert.Contains("\n        \"200\":", floors);
        Assert.Contains("#/components/schemas/FloorMapDto", floors);

        var routes = ExtractPath(yaml, "/api/routes");
        Assert.Contains("\n    get:", routes);
        Assert.Contains("- name: from", routes);
        Assert.Contains("- name: to", routes);
        Assert.Contains("\n        \"200\":", routes);
        Assert.Contains("\n        \"400\":", routes);
        Assert.Contains("#/components/schemas/RouteDto", routes);

        var navigationSpot = ExtractPath(yaml, "/api/navigation/spots/{id}");
        Assert.Contains("required: true", navigationSpot);
        Assert.Contains("\n        \"200\":", navigationSpot);
        Assert.Contains("\n        \"404\":", navigationSpot);
        Assert.Contains("#/components/schemas/SpotDto", navigationSpot);

        var spotByCode = ExtractPath(yaml, "/api/spots/by-code/{code}");
        Assert.Contains("required: true", spotByCode);
        Assert.Contains("\n        \"200\":", spotByCode);
        Assert.Contains("\n        \"400\":", spotByCode);
        Assert.Contains("\n        \"404\":", spotByCode);
        Assert.Contains("#/components/schemas/SpotByCodeResponse", spotByCode);
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

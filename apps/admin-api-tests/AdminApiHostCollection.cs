using Xunit;

namespace AdminApi.Tests;

/// <summary>
/// WebApplicationFactory&lt;Program&gt; を使うテストを直列化する。
/// 並列にホストを起動すると SQLite の EnsureCreated が競合して不安定になるため。
/// </summary>
[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class AdminApiHostCollection
{
    public const string Name = "AdminApiHost";
}

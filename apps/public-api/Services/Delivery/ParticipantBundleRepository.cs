using System.Data;
using System.Data.Common;
using AdminApi.Data;
using Microsoft.EntityFrameworkCore;

namespace PublicApi.Services.Delivery;

/// <summary>
/// <c>delivery.participant_bundles</c> の1行（E2-5 §3.1）。<c>payload</c> は保存したバイト列そのもの。
/// </summary>
public sealed record StoredParticipantBundle(
    long BundleVersion,
    string SchemaVersion,
    byte[] Payload,
    string Sha256,
    int ByteLength);

/// <summary>
/// 参加者向け bundle の配信表を読む（E2-5 §3、M1-2）。public-api は読むだけで、書き込みの経路を持たない。
/// </summary>
public interface IParticipantBundleRepository
{
    /// <summary>現在公開中の版。一度も公開されていなければ null。</summary>
    Task<long?> GetCurrentVersionAsync(CancellationToken cancellationToken);

    /// <summary>指定した版の bundle。無ければ null。</summary>
    Task<StoredParticipantBundle?> GetBundleAsync(long bundleVersion, CancellationToken cancellationToken);
}

/// <summary>
/// PostgreSQL の <c>delivery</c> スキーマを、admin・public と同じデータベースへの既存の接続（本番は
/// <c>nexus_public</c>）で読む（M1-2）。<c>delivery</c> は Studio の移行で作られるため、
/// <see cref="AdminDbContext"/> のモデルには含めず、SQL を直接発行する（admin の移行履歴を変えない）。
/// </summary>
public sealed class PostgresParticipantBundleRepository : IParticipantBundleRepository
{
    private readonly AdminDbContext _dbContext;

    public PostgresParticipantBundleRepository(AdminDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<long?> GetCurrentVersionAsync(CancellationToken cancellationToken)
    {
        await using var command = await CreateCommandAsync(
            "SELECT bundle_version FROM delivery.current_bundle WHERE singleton",
            cancellationToken);
        var value = await command.ExecuteScalarAsync(cancellationToken);
        return value is null or DBNull ? null : Convert.ToInt64(value);
    }

    public async Task<StoredParticipantBundle?> GetBundleAsync(long bundleVersion, CancellationToken cancellationToken)
    {
        await using var command = await CreateCommandAsync(
            "SELECT schema_version, payload, sha256, byte_length FROM delivery.participant_bundles WHERE bundle_version = @version",
            cancellationToken);
        var parameter = command.CreateParameter();
        parameter.ParameterName = "version";
        parameter.DbType = DbType.Int64;
        parameter.Value = bundleVersion;
        command.Parameters.Add(parameter);

        await using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow, cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new StoredParticipantBundle(
            bundleVersion,
            reader.GetString(0),
            reader.GetFieldValue<byte[]>(1),
            // char(64) は空白で埋められうるため、照合の前に取り除く。
            reader.GetString(2).Trim(),
            reader.GetInt32(3));
    }

    private async Task<DbCommand> CreateCommandAsync(string sql, CancellationToken cancellationToken)
    {
        var connection = _dbContext.Database.GetDbConnection();
        if (connection.State != ConnectionState.Open)
        {
            await _dbContext.Database.OpenConnectionAsync(cancellationToken);
        }

        var command = connection.CreateCommand();
        command.CommandText = sql;
        return command;
    }
}

/// <summary>
/// SQLite での開発用。<c>delivery</c> スキーマは PostgreSQL にしかないため、常に「未公開」として扱う。
/// </summary>
public sealed class NotPublishedParticipantBundleRepository : IParticipantBundleRepository
{
    public Task<long?> GetCurrentVersionAsync(CancellationToken cancellationToken) => Task.FromResult<long?>(null);

    public Task<StoredParticipantBundle?> GetBundleAsync(long bundleVersion, CancellationToken cancellationToken) =>
        Task.FromResult<StoredParticipantBundle?>(null);
}

using System.Security.Cryptography;
using System.Text;
using AdminApi.Data;
using AdminApi.Models;
using AdminApi.Options;
using AdminApi.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Options;
using Npgsql;
using PublicApi.Services;

const string payload = "{\n  \"type\":\"FeatureCollection\",\"nexus\":{\"schema_version\":\"1.0.0\",\"floors\":[]},\"features\":[]\n}";
if (args.Length == 2 && args[0] == "script")
{
    using var db = Context("Host=localhost;Database=unused");
    var preflight = """
        \set ON_ERROR_STOP on
        SET ROLE nexus_owner;
        SELECT pg_advisory_lock(hashtext('nexus-schema-migration'));
        -- Refuse legacy databases before creating even the first table/history record.
        DO $preflight$
        DECLARE initialized boolean := false;
        BEGIN
            IF to_regclass('public."__EFMigrationsHistory"') IS NOT NULL THEN
                IF EXISTS (SELECT 1 FROM public."__EFMigrationsHistory" WHERE "MigrationId" NOT IN
                    ('20260905120000_AddMapDatasets', '20260919120000_AddInitialPostgreSqlSchema')) THEN
                    RAISE EXCEPTION 'Unknown migration history detected. Stop and review.';
                END IF;
                SELECT EXISTS (SELECT 1 FROM public."__EFMigrationsHistory"
                    WHERE "MigrationId" = '20260919120000_AddInitialPostgreSqlSchema') INTO initialized;
            END IF;
            IF NOT initialized AND EXISTS (
                SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm', 'f', 'S')
                  AND c.relname NOT IN ('map_datasets', '__EFMigrationsHistory')) THEN
                RAISE EXCEPTION 'Existing public schema detected. Stop and review migration history.';
            END IF;
        END $preflight$;

        """;
    File.WriteAllText(args[1], preflight + db.GetService<IMigrator>().GenerateScript(options: MigrationsSqlGenerationOptions.Idempotent)
        + "\nSELECT pg_advisory_unlock(hashtext('nexus-schema-migration'));\n");
    Console.WriteLine("Migration SQL exported without a database connection.");
    return;
}

if (Environment.GetEnvironmentVariable("NEXUS_DB_DISPOSABLE") != "1")
    throw new InvalidOperationException("Verification commands require NEXUS_DB_DISPOSABLE=1.");
var adminConnection = ReadConnection("NEXUS_VERIFY_ADMIN_CONNECTION_FILE");
var publicConnection = ReadConnection("NEXUS_VERIFY_PUBLIC_CONNECTION_FILE");
await using var admin = Context(adminConnection);
await using var participant = Context(publicConnection);

if (args.Length == 2 && args[0] == "add-version")
{
    admin.MapDatasets.Add(Dataset(long.Parse(args[1])));
    await admin.SaveChangesAsync();
    Console.WriteLine($"Added verification dataset version {args[1]}.");
    return;
}

await DatabaseReadiness.CheckAsync(admin, false);
await DatabaseReadiness.CheckAsync(participant, true);
await using var adminSql = new NpgsqlConnection(adminConnection);
await adminSql.OpenAsync();
foreach (var table in admin.Model.GetRelationalModel().Tables)
{
    await using var command = new NpgsqlCommand("""
        SELECT a.attname, format_type(a.atttypid, a.atttypmod), NOT a.attnotnull
        FROM pg_attribute a WHERE a.attrelid = to_regclass(@table) AND a.attnum > 0 AND NOT a.attisdropped
        """, adminSql);
    command.Parameters.AddWithValue("table", "public.\"" + table.Name + "\"");
    await using var reader = await command.ExecuteReaderAsync();
    var columns = new Dictionary<string, (string Type, bool Nullable)>();
    while (await reader.ReadAsync()) columns.Add(reader.GetString(0), (reader.GetString(1), reader.GetBoolean(2)));
    Check(columns.Count == table.Columns.Count(), $"Column count: {table.Name}");
    foreach (var column in table.Columns)
        Check(columns.TryGetValue(column.Name, out var actual) && actual == (column.StoreType, column.IsNullable), $"Column mapping: {table.Name}.{column.Name}");
}

if (args.Length == 2 && args[0] == "assert-restored")
{
    Check(await admin.MapDatasets.CountAsync() == int.Parse(args[1]), "Restored dataset count");
    await VerifyPayloads();
    Check(await admin.Spots.CountAsync() == 2, "Restored spots");
    Check(await admin.VisitLogs.CountAsync() == 2, "Restored audit logs");
    Console.WriteLine("PASS: restored schema, histories, dataset bytes/checksums, spots and audit logs.");
    return;
}
if (args.Length != 1 || args[0] != "verify") throw new ArgumentException("Use script <file>, verify, add-version <n>, or assert-restored <count>.");
Check(!await admin.Spots.AnyAsync() && !await admin.MapDatasets.AnyAsync(), "Fresh database must not contain samples");
admin.Spots.AddRange(
    new Spot { Id = Guid.NewGuid(), Code = "verification-visible", Name = "検証用公開スポット", Description = "synthetic fixture", IsPublished = true, UpdatedAt = DateTimeOffset.UtcNow },
    new Spot { Id = Guid.NewGuid(), Code = "verification-hidden", Name = "検証用非公開スポット", Description = "synthetic fixture", IsPublished = false, UpdatedAt = DateTimeOffset.UtcNow });
admin.Events.AddRange(
    new Event { Id = Guid.NewGuid(), Title = "visible", StartsAt = DateTimeOffset.UtcNow, EndsAt = DateTimeOffset.UtcNow.AddHours(1), IsPublished = true },
    new Event { Id = Guid.NewGuid(), Title = "hidden", StartsAt = DateTimeOffset.UtcNow, EndsAt = DateTimeOffset.UtcNow.AddHours(1), IsPublished = false });
admin.MapDatasets.Add(Dataset(1));
await admin.SaveChangesAsync();
Check(await participant.Spots.CountAsync() == 1 && await participant.Events.CountAsync() == 1, "RLS hides unpublished rows without API filters");
await VerifyPayloads();
var hasher = new AuditLogHasher(Options.Create(new AuditLogOptions { HashKey = new string('x', 64) }));
var persistence = new LogPersistenceService(participant, hasher);
await persistence.PersistAsync([new("verification", "spot_view", "verification-visible", null, null, null, null, null)], CancellationToken.None);
await persistence.PersistAsync([new("verification", "spot_view", "verification-visible", null, null, null, null, null)], CancellationToken.None);
Check(await admin.VisitLogs.CountAsync() == 2, "Public audit inserts");
var logs = await admin.VisitLogs.OrderBy(l => l.CreatedAt).ToListAsync();
Check(logs[1].PrevHash == logs[0].Hash, "Public role can read the previous audit hash");
foreach (var table in new[] { "map_datasets", "qr_issues", "issued_tokens", "revoked_jti", "one_time_login_codes", "departments", "exhibits", "oc_days", "open_campus_timeslots", "timeslot_exhibits", "verification_future" })
    await Denied(publicConnection, $"SELECT * FROM {table}");
foreach (var sql in new[] { "SELECT session_id FROM visit_logs", "UPDATE events SET title='forbidden'", "DELETE FROM spots", "UPDATE visit_logs SET hash='forbidden'", "DELETE FROM visit_logs", "CREATE TABLE forbidden(id int)", "SET ROLE nexus_owner" })
    await Denied(publicConnection, sql);
await Denied(adminConnection, "CREATE TABLE forbidden(id int)");
await Denied(adminConnection, "SET ROLE nexus_owner");
await Denied(adminConnection, "DELETE FROM \"__EFMigrationsHistory\"");
admin.MapDatasets.Add(Dataset(1));
try { await admin.SaveChangesAsync(); throw new Exception("Duplicate version accepted"); }
catch (DbUpdateException error) when (error.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation }) { admin.ChangeTracker.Clear(); }
foreach (var invalid in new[] { Dataset(0), new MapDataset { Version = 2, Status = "invalid", Payload = payload, Checksum = Hash(payload) }, new MapDataset { Version = 2, Payload = payload, Checksum = "short" } })
{
    admin.MapDatasets.Add(invalid);
    try { await admin.SaveChangesAsync(); throw new Exception("Invalid metadata accepted"); }
    catch (DbUpdateException error) when (error.InnerException is PostgresException { SqlState: PostgresErrorCodes.CheckViolation }) { admin.ChangeTracker.Clear(); }
}
Console.WriteLine("PASS: complete PostgreSQL schema, read-only readiness, RLS, role denials, audit chain, MapDataset constraints and payload roundtrip.");

async Task VerifyPayloads()
{
    foreach (var item in await admin.MapDatasets.AsNoTracking().ToListAsync())
        Check(item.Payload == payload && item.Checksum == Hash(item.Payload), "Dataset payload and checksum");
}
static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
MapDataset Dataset(long version) => new() { Version = version, Payload = payload, Checksum = Hash(payload) };
static AdminDbContext Context(string connection) => new(new DbContextOptionsBuilder<AdminDbContext>().UseNpgsql(connection).Options);
static string ReadConnection(string key)
{
    var value = File.ReadAllText(Environment.GetEnvironmentVariable(key) ?? throw new InvalidOperationException($"Missing {key}")).Trim();
    var parsed = new NpgsqlConnectionStringBuilder(value);
    if (parsed.Database != "nexus_verify" || parsed.Host is not ("127.0.0.1" or "localhost"))
        throw new InvalidOperationException("Verification only supports the local disposable nexus_verify database.");
    return value;
}
static void Check(bool condition, string message) { if (!condition) throw new Exception("FAILED: " + message); }
static async Task Denied(string connection, string sql)
{
    await using var db = new NpgsqlConnection(connection);
    await db.OpenAsync();
    await using var command = new NpgsqlCommand(sql, db);
    try { await command.ExecuteNonQueryAsync(); }
    catch (PostgresException error) when (error.SqlState == PostgresErrorCodes.InsufficientPrivilege) { return; }
    throw new Exception("Expected permission denied: " + sql);
}

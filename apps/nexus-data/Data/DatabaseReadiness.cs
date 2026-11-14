using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace AdminApi.Data;

public static class DatabaseReadiness
{
    /// <summary>Read-only startup gate. Schema changes are applied by a separate deployment step.</summary>
    public static async Task CheckAsync(AdminDbContext db, bool publicApi, CancellationToken cancellationToken = default)
    {
        if (!db.Database.IsNpgsql()) throw new InvalidOperationException("Production readiness requires PostgreSQL.");
        var expected = db.Database.GetMigrations().Order().ToArray();
        var applied = (await db.Database.GetAppliedMigrationsAsync(cancellationToken)).Order().ToArray();
        if (!expected.SequenceEqual(applied))
            throw new InvalidOperationException("Database migration history differs from this application. Apply the reviewed deployment SQL first.");

        await db.Database.OpenConnectionAsync(cancellationToken);
        try
        {
            await using var command = new NpgsqlCommand("""
                SELECT r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolbypassrls
                    OR pg_has_role(current_user, 'nexus_owner', 'MEMBER')
                    OR has_schema_privilege(current_user, 'public', 'CREATE')
                FROM pg_roles r WHERE r.rolname = current_user
                """, (NpgsqlConnection)db.Database.GetDbConnection());
            if (await command.ExecuteScalarAsync(cancellationToken) is not false)
                throw new InvalidOperationException("Runtime database role has deployment privileges.");

            var tables = publicApi ? new[] { "spots", "events", "visit_logs" }
                : db.Model.GetEntityTypes().Select(e => e.GetTableName()!).Distinct().ToArray();
            foreach (var table in tables)
            {
                await using var check = new NpgsqlCommand("SELECT to_regclass(@name) IS NOT NULL",
                    (NpgsqlConnection)db.Database.GetDbConnection());
                check.Parameters.AddWithValue("name", "public." + table);
                if (await check.ExecuteScalarAsync(cancellationToken) is not true)
                    throw new InvalidOperationException("Required database tables are missing.");
            }
        }
        finally { await db.Database.CloseConnectionAsync(); }
    }
}

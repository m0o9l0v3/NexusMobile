using AdminApi.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace AdminApi.Migrations;

[DbContext(typeof(AdminDbContext))]
[Migration("20260919120000_AddInitialPostgreSqlSchema")]
public sealed class AddInitialPostgreSqlSchema : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        if (ActiveProvider != "Npgsql.EntityFrameworkCore.PostgreSQL") return;
        // The earlier discoverable migration owns map_datasets. Historical, undiscoverable
        // migration files are not enabled retroactively against existing installations.
        migrationBuilder.Sql("""
            DO $$ BEGIN
                IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm', 'f', 'S')
                    AND c.relname NOT IN ('map_datasets', '__EFMigrationsHistory')) THEN
                    RAISE EXCEPTION 'Existing public schema detected. Review the schema and migration history before adopting the initial PostgreSQL schema.';
                END IF;
            END $$;
            """);
        using var stream = typeof(AddInitialPostgreSqlSchema).Assembly.GetManifestResourceStream("AdminApi.Migrations.InitialPostgreSqlSchema.sql")!;
        using var reader = new StreamReader(stream);
        migrationBuilder.Sql(reader.ReadToEnd());
    }

    protected override void Down(MigrationBuilder migrationBuilder) =>
        throw new NotSupportedException("Restore a verified backup instead of dropping the production schema.");
}

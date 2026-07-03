using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AdminApi.Migrations
{
    public partial class AddPublicApiReadOnlyRole : Migration
    {
        private const string RoleName = "nexus_public_readonly";
        private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";

        protected override void Up(MigrationBuilder migrationBuilder)
        {
            if (migrationBuilder.ActiveProvider != NpgsqlProviderName)
            {
                return;
            }

            migrationBuilder.Sql($@"
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT FROM pg_catalog.pg_roles WHERE rolname = '{RoleName}'
                    ) THEN
                        CREATE ROLE {RoleName} WITH NOLOGIN;
                    END IF;
                END
                $$;
            ");

            migrationBuilder.Sql($@"
                DO $$
                BEGIN
                    EXECUTE format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), '{RoleName}');
                END
                $$;

                GRANT USAGE ON SCHEMA public TO {RoleName};
                GRANT SELECT ON ALL TABLES IN SCHEMA public TO {RoleName};

                -- visit_logs への INSERT のみ例外的に許可する。
                -- public-api の LogPersistenceService が匿名参加者ログ（監査ハッシュチェーン付き）を
                -- 書き込むための唯一のサンクション済み書き込み経路であり、他テーブルへの書き込みは許可しない。
                GRANT INSERT ON TABLE visit_logs TO {RoleName};

                ALTER DEFAULT PRIVILEGES IN SCHEMA public
                    GRANT SELECT ON TABLES TO {RoleName};
            ");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            if (migrationBuilder.ActiveProvider != NpgsqlProviderName)
            {
                return;
            }

            migrationBuilder.Sql($@"
                ALTER DEFAULT PRIVILEGES IN SCHEMA public
                    REVOKE SELECT ON TABLES FROM {RoleName};
                REVOKE INSERT ON TABLE visit_logs FROM {RoleName};
                REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM {RoleName};
                REVOKE USAGE ON SCHEMA public FROM {RoleName};
            ");

            migrationBuilder.Sql($@"
                DO $$
                BEGIN
                    EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM %I', current_database(), '{RoleName}');
                END
                $$;
            ");

            migrationBuilder.Sql($@"DROP ROLE IF EXISTS {RoleName};");
        }
    }
}

using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AdminApi.Migrations
{
    public partial class AddAuditLogChainFields : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "chain_id",
                table: "visit_logs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "hash",
                table: "visit_logs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "hash_alg",
                table: "visit_logs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "prev_hash",
                table: "visit_logs",
                type: "text",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_visit_logs_chain_id_created_at",
                table: "visit_logs",
                columns: new[] { "chain_id", "created_at" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_visit_logs_chain_id_created_at",
                table: "visit_logs");

            migrationBuilder.DropColumn(
                name: "chain_id",
                table: "visit_logs");

            migrationBuilder.DropColumn(
                name: "hash",
                table: "visit_logs");

            migrationBuilder.DropColumn(
                name: "hash_alg",
                table: "visit_logs");

            migrationBuilder.DropColumn(
                name: "prev_hash",
                table: "visit_logs");
        }
    }
}

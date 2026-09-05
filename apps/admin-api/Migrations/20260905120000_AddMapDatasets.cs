using AdminApi.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AdminApi.Migrations;

[DbContext(typeof(AdminDbContext))]
[Migration("20260905120000_AddMapDatasets")]
public partial class AddMapDatasets : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "map_datasets",
            columns: table => new
            {
                id = table.Column<Guid>(nullable: false),
                version = table.Column<long>(nullable: false),
                status = table.Column<string>(nullable: false),
                payload = table.Column<string>(type: "text", nullable: false),
                checksum = table.Column<string>(nullable: false),
                published_at = table.Column<DateTimeOffset>(nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_map_datasets", x => x.id);
                table.CheckConstraint("ck_map_datasets_version", "version > 0");
                table.CheckConstraint("ck_map_datasets_status", "status IN ('draft', 'published', 'archived')");
                table.CheckConstraint("ck_map_datasets_checksum", "length(checksum) = 64");
            });

        migrationBuilder.CreateIndex(
            name: "IX_map_datasets_version",
            table: "map_datasets",
            column: "version",
            unique: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "map_datasets");
    }
}

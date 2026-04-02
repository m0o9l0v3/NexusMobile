using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AdminApi.Migrations
{
    public partial class AddVisitLogMetadata : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "location_accuracy",
                table: "visit_logs",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "location_lat",
                table: "visit_logs",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "location_lng",
                table: "visit_logs",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "payload_json",
                table: "visit_logs",
                type: "text",
                nullable: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "location_accuracy",
                table: "visit_logs");

            migrationBuilder.DropColumn(
                name: "location_lat",
                table: "visit_logs");

            migrationBuilder.DropColumn(
                name: "location_lng",
                table: "visit_logs");

            migrationBuilder.DropColumn(
                name: "payload_json",
                table: "visit_logs");
        }
    }
}


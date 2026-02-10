using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AdminApi.Migrations
{
    public partial class AddOpenCampusQrIssues : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "departments",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_departments", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "open_campus_timeslots",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    event_id = table.Column<Guid>(type: "uuid", nullable: false),
                    starts_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    ends_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_open_campus_timeslots", x => x.id);
                    table.ForeignKey(
                        name: "FK_open_campus_timeslots_events_event_id",
                        column: x => x.event_id,
                        principalTable: "events",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "exhibits",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    spot_id = table.Column<Guid>(type: "uuid", nullable: false),
                    department_id = table.Column<string>(type: "text", nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_exhibits", x => x.id);
                    table.ForeignKey(
                        name: "FK_exhibits_departments_department_id",
                        column: x => x.department_id,
                        principalTable: "departments",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_exhibits_spots_spot_id",
                        column: x => x.spot_id,
                        principalTable: "spots",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "qr_issues",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    event_id = table.Column<Guid>(type: "uuid", nullable: false),
                    timeslot_id = table.Column<Guid>(type: "uuid", nullable: false),
                    token_hash = table.Column<string>(type: "text", nullable: false),
                    payload_snapshot_json = table.Column<string>(type: "jsonb", nullable: false),
                    issued_by_admin_id = table.Column<string>(type: "text", nullable: false),
                    issued_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    revoked_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    revoke_reason = table.Column<string>(type: "text", nullable: true),
                    scan_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    last_scanned_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_qr_issues", x => x.id);
                    table.ForeignKey(
                        name: "FK_qr_issues_events_event_id",
                        column: x => x.event_id,
                        principalTable: "events",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_qr_issues_open_campus_timeslots_timeslot_id",
                        column: x => x.timeslot_id,
                        principalTable: "open_campus_timeslots",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "timeslot_exhibits",
                columns: table => new
                {
                    timeslot_id = table.Column<Guid>(type: "uuid", nullable: false),
                    exhibit_id = table.Column<Guid>(type: "uuid", nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_timeslot_exhibits", x => new { x.timeslot_id, x.exhibit_id });
                    table.ForeignKey(
                        name: "FK_timeslot_exhibits_exhibits_exhibit_id",
                        column: x => x.exhibit_id,
                        principalTable: "exhibits",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_timeslot_exhibits_open_campus_timeslots_timeslot_id",
                        column: x => x.timeslot_id,
                        principalTable: "open_campus_timeslots",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_exhibits_department_id",
                table: "exhibits",
                column: "department_id");

            migrationBuilder.CreateIndex(
                name: "IX_exhibits_spot_id",
                table: "exhibits",
                column: "spot_id");

            migrationBuilder.CreateIndex(
                name: "IX_open_campus_timeslots_event_id",
                table: "open_campus_timeslots",
                column: "event_id");

            migrationBuilder.CreateIndex(
                name: "IX_qr_issues_event_id",
                table: "qr_issues",
                column: "event_id");

            migrationBuilder.CreateIndex(
                name: "IX_qr_issues_timeslot_id",
                table: "qr_issues",
                column: "timeslot_id");

            migrationBuilder.CreateIndex(
                name: "IX_qr_issues_token_hash",
                table: "qr_issues",
                column: "token_hash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_timeslot_exhibits_exhibit_id",
                table: "timeslot_exhibits",
                column: "exhibit_id");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "qr_issues");

            migrationBuilder.DropTable(
                name: "timeslot_exhibits");

            migrationBuilder.DropTable(
                name: "exhibits");

            migrationBuilder.DropTable(
                name: "open_campus_timeslots");

            migrationBuilder.DropTable(
                name: "departments");
        }
    }
}

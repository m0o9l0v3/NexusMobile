using System;
using AdminApi.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

#nullable disable

namespace AdminApi.Migrations
{
    [DbContext(typeof(AdminDbContext))]
    partial class AdminDbContextModelSnapshot : ModelSnapshot
    {
        protected override void BuildModel(ModelBuilder modelBuilder)
        {
            modelBuilder
                .HasAnnotation("ProductVersion", "8.0.6")
                .HasAnnotation("Relational:MaxIdentifierLength", 63);

            modelBuilder.Entity("AdminApi.Models.Event", b =>
                {
                    b.Property<Guid>("Id")
                        .HasColumnType("uuid")
                        .HasColumnName("id");

                    b.Property<string>("Description")
                        .HasColumnType("text")
                        .HasColumnName("description");

                    b.Property<DateTimeOffset>("EndsAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("ends_at");

                    b.Property<bool>("IsPublished")
                        .HasColumnType("boolean")
                        .HasDefaultValue(true)
                        .HasColumnName("is_published");

                    b.Property<double?>("Lat")
                        .HasColumnType("double precision")
                        .HasColumnName("lat");

                    b.Property<double?>("Lng")
                        .HasColumnType("double precision")
                        .HasColumnName("lng");

                    b.Property<string>("LocationText")
                        .HasColumnType("text")
                        .HasColumnName("location_text");

                    b.Property<DateTimeOffset>("StartsAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("starts_at");

                    b.Property<string>("Title")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("title");

                    b.HasKey("Id");

                    b.ToTable("events");
                });

            modelBuilder.Entity("AdminApi.Models.IssuedToken", b =>
                {
                    b.Property<string>("Jti")
                        .HasColumnType("text")
                        .HasColumnName("jti");

                    b.Property<DateTimeOffset>("ExpiresAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("expires_at");

                    b.Property<DateTimeOffset>("IssuedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("issued_at");

                    b.Property<string>("Subject")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("subject");

                    b.HasKey("Jti");

                    b.HasIndex("Subject");

                    b.ToTable("issued_tokens");
                });

            modelBuilder.Entity("AdminApi.Models.OcDay", b =>
                {
                    b.Property<Guid>("Id")
                        .HasColumnType("uuid")
                        .HasColumnName("id");

                    b.Property<DateOnly>("Date")
                        .HasColumnType("date")
                        .HasColumnName("date");

                    b.Property<string>("Name")
                        .HasColumnType("text")
                        .HasColumnName("name");

                    b.HasKey("Id");

                    b.HasIndex("Date")
                        .IsUnique();

                    b.ToTable("oc_days");
                });

            modelBuilder.Entity("AdminApi.Models.Department", b =>
                {
                    b.Property<string>("Id")
                        .HasColumnType("text")
                        .HasColumnName("id");

                    b.Property<string>("Name")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("name");

                    b.HasKey("Id");

                    b.ToTable("departments");
                });

            modelBuilder.Entity("AdminApi.Models.Exhibit", b =>
                {
                    b.Property<Guid>("Id")
                        .HasColumnType("uuid")
                        .HasColumnName("id");

                    b.Property<DateTimeOffset>("CreatedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("created_at");

                    b.Property<string>("DepartmentId")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("department_id");

                    b.Property<string>("Description")
                        .HasColumnType("text")
                        .HasColumnName("description");

                    b.Property<string>("Name")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("name");

                    b.Property<Guid>("SpotId")
                        .HasColumnType("uuid")
                        .HasColumnName("spot_id");

                    b.Property<DateTimeOffset>("UpdatedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("updated_at");

                    b.HasKey("Id");

                    b.HasIndex("DepartmentId");

                    b.HasIndex("SpotId");

                    b.HasOne("AdminApi.Models.Department", "Department")
                        .WithMany()
                        .HasForeignKey("DepartmentId")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.HasOne("AdminApi.Models.Spot", "Spot")
                        .WithMany()
                        .HasForeignKey("SpotId")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.ToTable("exhibits");
                });

            modelBuilder.Entity("AdminApi.Models.OpenCampusTimeslot", b =>
                {
                    b.Property<Guid>("Id")
                        .HasColumnType("uuid")
                        .HasColumnName("id");

                    b.Property<DateTimeOffset>("CreatedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("created_at");

                    b.Property<DateTimeOffset>("EndsAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("ends_at");

                    b.Property<Guid>("EventId")
                        .HasColumnType("uuid")
                        .HasColumnName("event_id");

                    b.Property<DateTimeOffset>("StartsAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("starts_at");

                    b.Property<DateTimeOffset>("UpdatedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("updated_at");

                    b.HasKey("Id");

                    b.HasIndex("EventId");

                    b.HasOne("AdminApi.Models.Event", "Event")
                        .WithMany()
                        .HasForeignKey("EventId")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.ToTable("open_campus_timeslots");
                });

            modelBuilder.Entity("AdminApi.Models.QrIssue", b =>
                {
                    b.Property<Guid>("Id")
                        .HasColumnType("uuid")
                        .HasColumnName("id");

                    b.Property<DateTimeOffset>("ExpiresAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("expires_at");

                    b.Property<Guid>("EventId")
                        .HasColumnType("uuid")
                        .HasColumnName("event_id");

                    b.Property<DateTimeOffset>("IssuedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("issued_at");

                    b.Property<string>("IssuedByAdminId")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("issued_by_admin_id");

                    b.Property<DateTimeOffset?>("LastScannedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("last_scanned_at");

                    b.Property<string>("PayloadSnapshotJson")
                        .IsRequired()
                        .HasColumnType("jsonb")
                        .HasColumnName("payload_snapshot_json");

                    b.Property<string>("RevokeReason")
                        .HasColumnType("text")
                        .HasColumnName("revoke_reason");

                    b.Property<DateTimeOffset?>("RevokedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("revoked_at");

                    b.Property<int>("ScanCount")
                        .ValueGeneratedOnAdd()
                        .HasColumnType("integer")
                        .HasDefaultValue(0)
                        .HasColumnName("scan_count");

                    b.Property<Guid>("TimeslotId")
                        .HasColumnType("uuid")
                        .HasColumnName("timeslot_id");

                    b.Property<string>("TokenHash")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("token_hash");

                    b.HasKey("Id");

                    b.HasIndex("EventId");

                    b.HasIndex("TimeslotId");

                    b.HasIndex("TokenHash")
                        .IsUnique();

                    b.HasOne("AdminApi.Models.Event", "Event")
                        .WithMany()
                        .HasForeignKey("EventId")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.HasOne("AdminApi.Models.OpenCampusTimeslot", "Timeslot")
                        .WithMany()
                        .HasForeignKey("TimeslotId")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.ToTable("qr_issues");
                });

            modelBuilder.Entity("AdminApi.Models.OneTimeLoginCode", b =>
                {
                    b.Property<Guid>("Id")
                        .HasColumnType("uuid")
                        .HasColumnName("id");

                    b.Property<string>("CodeHash")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("code_hash");

                    b.Property<DateTimeOffset>("CreatedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("created_at");

                    b.Property<Guid>("EventId")
                        .HasColumnType("uuid")
                        .HasColumnName("event_id");

                    b.Property<DateTimeOffset>("ExpiresAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("expires_at");

                    b.Property<DateTimeOffset?>("UsedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("used_at");

                    b.Property<Guid?>("UsedByUuid")
                        .HasColumnType("uuid")
                        .HasColumnName("used_by_uuid");

                    b.HasKey("Id");

                    b.HasIndex("CodeHash")
                        .IsUnique();

                    b.ToTable("one_time_login_codes");
                });

            modelBuilder.Entity("AdminApi.Models.TimeslotExhibit", b =>
                {
                    b.Property<Guid>("TimeslotId")
                        .HasColumnType("uuid")
                        .HasColumnName("timeslot_id");

                    b.Property<Guid>("ExhibitId")
                        .HasColumnType("uuid")
                        .HasColumnName("exhibit_id");

                    b.Property<int>("SortOrder")
                        .HasColumnType("integer")
                        .HasColumnName("sort_order");

                    b.HasKey("TimeslotId", "ExhibitId");

                    b.HasIndex("ExhibitId");

                    b.HasOne("AdminApi.Models.Exhibit", "Exhibit")
                        .WithMany()
                        .HasForeignKey("ExhibitId")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.HasOne("AdminApi.Models.OpenCampusTimeslot", "Timeslot")
                        .WithMany()
                        .HasForeignKey("TimeslotId")
                        .OnDelete(DeleteBehavior.Cascade);

                    b.ToTable("timeslot_exhibits");
                });

            modelBuilder.Entity("AdminApi.Models.RevokedToken", b =>
                {
                    b.Property<string>("Jti")
                        .HasColumnType("text")
                        .HasColumnName("jti");

                    b.Property<DateTimeOffset>("ExpiresAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("expires_at");

                    b.Property<string>("Reason")
                        .HasColumnType("text")
                        .HasColumnName("reason");

                    b.Property<DateTimeOffset>("RevokedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("revoked_at");

                    b.Property<string>("RevokedByUserId")
                        .HasColumnType("text")
                        .HasColumnName("revoked_by_user_id");

                    b.HasKey("Jti");

                    b.ToTable("revoked_jti");
                });

            modelBuilder.Entity("AdminApi.Models.Spot", b =>
                {
                    b.Property<Guid>("Id")
                        .HasColumnType("uuid")
                        .HasColumnName("id");

                    b.Property<string>("Code")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("code");

                    b.Property<string>("ContentAssets")
                        .HasColumnType("text")
                        .HasColumnName("content_assets");

                    b.Property<string>("Description")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("description");

                    b.Property<bool>("IsPublished")
                        .HasColumnType("boolean")
                        .HasDefaultValue(true)
                        .HasColumnName("is_published");

                    b.Property<double?>("Lat")
                        .HasColumnType("double precision")
                        .HasColumnName("lat");

                    b.Property<double?>("Lng")
                        .HasColumnType("double precision")
                        .HasColumnName("lng");

                    b.Property<string>("ModelRef")
                        .HasColumnType("text")
                        .HasColumnName("model_ref");

                    b.Property<string>("Name")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("name");

                    b.Property<string[]>("Tags")
                        .HasColumnType("text[]")
                        .HasColumnName("tags");

                    b.Property<DateTimeOffset>("UpdatedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("updated_at");

                    b.HasKey("Id");

                    b.HasIndex("Code")
                        .IsUnique();

                    b.ToTable("spots");
                });

            modelBuilder.Entity("AdminApi.Models.VisitLog", b =>
                {
                    b.Property<string>("ChainId")
                        .HasColumnType("text")
                        .HasColumnName("chain_id");

                    b.Property<Guid>("Id")
                        .HasColumnType("uuid")
                        .HasColumnName("id");

                    b.Property<DateTimeOffset>("CreatedAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("created_at");

                    b.Property<string>("EventType")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("event_type");

                    b.Property<string>("Hash")
                        .HasColumnType("text")
                        .HasColumnName("hash");

                    b.Property<string>("HashAlg")
                        .HasColumnType("text")
                        .HasColumnName("hash_alg");

                    b.Property<double?>("LocationAccuracy")
                        .HasColumnType("double precision")
                        .HasColumnName("location_accuracy");

                    b.Property<double?>("LocationLat")
                        .HasColumnType("double precision")
                        .HasColumnName("location_lat");

                    b.Property<double?>("LocationLng")
                        .HasColumnType("double precision")
                        .HasColumnName("location_lng");

                    b.Property<DateTimeOffset>("OccurredAt")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("occurred_at");

                    b.Property<string>("PayloadJson")
                        .HasColumnType("text")
                        .HasColumnName("payload_json");

                    b.Property<string>("PrevHash")
                        .HasColumnType("text")
                        .HasColumnName("prev_hash");

                    b.Property<string>("SessionId")
                        .IsRequired()
                        .HasColumnType("text")
                        .HasColumnName("session_id");

                    b.Property<string>("SpotCode")
                        .HasColumnType("text")
                        .HasColumnName("spot_code");

                    b.HasIndex("ChainId", "CreatedAt")
                        .HasDatabaseName("ix_visit_logs_chain_id_created_at");

                    b.HasKey("Id");

                    b.ToTable("visit_logs");
                });
        }
    }
}

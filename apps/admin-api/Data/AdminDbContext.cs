using System.Linq;
using System.Text.Json;
using AdminApi.Models;
using AdminApi.Services;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace AdminApi.Data;

public sealed class AdminDbContext : DbContext
{
    private readonly AuditLogHasher? _auditLogHasher;

    public AdminDbContext(DbContextOptions<AdminDbContext> options) : base(options)
    {
    }

    public AdminDbContext(DbContextOptions<AdminDbContext> options, AuditLogHasher auditLogHasher) : base(options)
    {
        _auditLogHasher = auditLogHasher;
    }

    public DbSet<MapDataset> MapDatasets => Set<MapDataset>();
    public DbSet<Spot> Spots => Set<Spot>();
    public DbSet<Event> Events => Set<Event>();
    public DbSet<OcDay> OcDays => Set<OcDay>();
    public DbSet<Department> Departments => Set<Department>();
    public DbSet<Exhibit> Exhibits => Set<Exhibit>();
    public DbSet<OpenCampusTimeslot> OpenCampusTimeslots => Set<OpenCampusTimeslot>();
    public DbSet<TimeslotExhibit> TimeslotExhibits => Set<TimeslotExhibit>();
    public DbSet<QrIssue> QrIssues => Set<QrIssue>();
    public DbSet<VisitLog> VisitLogs => Set<VisitLog>();
    public DbSet<OneTimeLoginCode> OneTimeLoginCodes => Set<OneTimeLoginCode>();
    public DbSet<IssuedToken> IssuedTokens => Set<IssuedToken>();
    public DbSet<RevokedToken> RevokedTokens => Set<RevokedToken>();

    public override int SaveChanges()
    {
        PrepareVisitLogsForSaveAsync(CancellationToken.None).GetAwaiter().GetResult();
        return base.SaveChanges();
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        PrepareVisitLogsForSaveAsync(CancellationToken.None).GetAwaiter().GetResult();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return SaveChangesAsync(acceptAllChangesOnSuccess: true, cancellationToken);
    }

    public override async Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        await PrepareVisitLogsForSaveAsync(cancellationToken);
        return await base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    private async Task PrepareVisitLogsForSaveAsync(CancellationToken cancellationToken)
    {
        if (_auditLogHasher is null)
        {
            return;
        }

        var newLogs = ChangeTracker.Entries<VisitLog>()
            .Where(entry => entry.State == EntityState.Added)
            .Select(entry => entry.Entity)
            .OrderBy(log => log.CreatedAt)
            .ThenBy(log => log.Id)
            .ToList();

        if (newLogs.Count == 0)
        {
            return;
        }

        var previousHashes = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var log in newLogs)
        {
            if (log.OccurredAt == default)
            {
                log.OccurredAt = DateTimeOffset.UtcNow;
            }

            if (log.CreatedAt == default)
            {
                log.CreatedAt = DateTimeOffset.UtcNow;
            }

            var chainId = string.IsNullOrWhiteSpace(log.ChainId)
                ? _auditLogHasher.BuildChainId(log)
                : log.ChainId;

            if (chainId is null)
            {
                continue;
            }

            if (!previousHashes.TryGetValue(chainId, out var prevHash))
            {
                prevHash = await VisitLogs.AsNoTracking()
                    .Where(existing => existing.ChainId == chainId)
                    .OrderByDescending(existing => existing.CreatedAt)
                    .Select(existing => existing.Hash)
                    .FirstOrDefaultAsync(cancellationToken) ?? string.Empty;
            }

            log.ChainId = chainId;
            log.PrevHash = prevHash;
            log.HashAlg = _auditLogHasher.HashAlgorithm;
            log.Hash = _auditLogHasher.ComputeHash(log, prevHash, chainId);

            previousHashes[chainId] = log.Hash;
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<MapDataset>(entity =>
        {
            entity.ToTable("map_datasets", table =>
            {
                table.HasCheckConstraint("ck_map_datasets_version", "version > 0");
                table.HasCheckConstraint("ck_map_datasets_status", "status IN ('draft', 'published', 'archived')");
                table.HasCheckConstraint("ck_map_datasets_checksum", "length(checksum) = 64");
            });
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Version).HasColumnName("version").IsRequired();
            entity.HasIndex(e => e.Version).IsUnique();
            entity.Property(e => e.Status).HasColumnName("status").IsRequired();
            // text keeps exactly the bytes used for the checksum on both providers.
            entity.Property(e => e.Payload).HasColumnName("payload").HasColumnType("text").IsRequired();
            entity.Property(e => e.Checksum).HasColumnName("checksum").IsRequired();
            entity.Property(e => e.PublishedAt).HasColumnName("published_at");
        });

        modelBuilder.Entity<Spot>(entity =>
        {
            entity.ToTable("spots");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Code).HasColumnName("code").IsRequired();
            entity.HasIndex(e => e.Code).IsUnique();
            entity.Property(e => e.Name).HasColumnName("name").IsRequired();
            entity.Property(e => e.Description).HasColumnName("description").IsRequired();
            if (Database.IsSqlite())
            {
                var tagsConverter = new ValueConverter<string[]?, string?>(
                    value => value == null ? null : JsonSerializer.Serialize(value, (JsonSerializerOptions?)null),
                    value => value == null ? null : JsonSerializer.Deserialize<string[]>(value, (JsonSerializerOptions?)null));
                var tagsComparer = new ValueComparer<string[]?>(
                    (left, right) => left == null && right == null || left != null && right != null && left.SequenceEqual(right),
                    value => value == null ? 0 : value.Aggregate(0, (current, item) => HashCode.Combine(current, item == null ? 0 : item.GetHashCode())),
                    value => value == null ? null : value.ToArray());
                var tagsProperty = entity.Property(e => e.Tags).HasColumnName("tags").HasConversion(tagsConverter);
                tagsProperty.Metadata.SetValueComparer(tagsComparer);
            }
            else
            {
                entity.Property(e => e.Tags).HasColumnName("tags");
            }
            entity.Property(e => e.Lat).HasColumnName("lat");
            entity.Property(e => e.Lng).HasColumnName("lng");
            entity.Property(e => e.IsPublished).HasColumnName("is_published").HasDefaultValue(true);
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");
            entity.Property(e => e.ContentAssets).HasColumnName("content_assets");
            entity.Property(e => e.ModelRef).HasColumnName("model_ref");
        });

        modelBuilder.Entity<Event>(entity =>
        {
            entity.ToTable("events");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Title).HasColumnName("title").IsRequired();
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.StartsAt).HasColumnName("starts_at").IsRequired();
            entity.Property(e => e.EndsAt).HasColumnName("ends_at").IsRequired();
            entity.Property(e => e.Lat).HasColumnName("lat");
            entity.Property(e => e.Lng).HasColumnName("lng");
            entity.Property(e => e.LocationText).HasColumnName("location_text");
            entity.Property(e => e.IsPublished).HasColumnName("is_published").HasDefaultValue(true);
        });

        modelBuilder.Entity<OcDay>(entity =>
        {
            entity.ToTable("oc_days");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Date).HasColumnName("date").IsRequired();
            entity.HasIndex(e => e.Date).IsUnique();
            entity.Property(e => e.Name).HasColumnName("name");
        });

        modelBuilder.Entity<Department>(entity =>
        {
            entity.ToTable("departments");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name).HasColumnName("name").IsRequired();
        });

        modelBuilder.Entity<Exhibit>(entity =>
        {
            entity.ToTable("exhibits");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name).HasColumnName("name").IsRequired();
            entity.Property(e => e.SpotId).HasColumnName("spot_id").IsRequired();
            entity.Property(e => e.DepartmentId).HasColumnName("department_id").IsRequired();
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();
            entity.HasOne(e => e.Spot)
                .WithMany()
                .HasForeignKey(e => e.SpotId);
            entity.HasOne(e => e.Department)
                .WithMany()
                .HasForeignKey(e => e.DepartmentId);
        });

        modelBuilder.Entity<OpenCampusTimeslot>(entity =>
        {
            entity.ToTable("open_campus_timeslots");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.EventId).HasColumnName("event_id").IsRequired();
            entity.Property(e => e.StartsAt).HasColumnName("starts_at").IsRequired();
            entity.Property(e => e.EndsAt).HasColumnName("ends_at").IsRequired();
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();
            entity.HasOne(e => e.Event)
                .WithMany()
                .HasForeignKey(e => e.EventId);
        });

        modelBuilder.Entity<TimeslotExhibit>(entity =>
        {
            entity.ToTable("timeslot_exhibits");
            entity.HasKey(e => new { e.TimeslotId, e.ExhibitId });
            entity.Property(e => e.TimeslotId).HasColumnName("timeslot_id");
            entity.Property(e => e.ExhibitId).HasColumnName("exhibit_id");
            entity.Property(e => e.SortOrder).HasColumnName("sort_order");
            entity.HasOne(e => e.Timeslot)
                .WithMany()
                .HasForeignKey(e => e.TimeslotId);
            entity.HasOne(e => e.Exhibit)
                .WithMany()
                .HasForeignKey(e => e.ExhibitId);
        });

        modelBuilder.Entity<QrIssue>(entity =>
        {
            entity.ToTable("qr_issues");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.EventId).HasColumnName("event_id").IsRequired();
            entity.Property(e => e.TimeslotId).HasColumnName("timeslot_id").IsRequired();
            entity.Property(e => e.TokenHash).HasColumnName("token_hash").IsRequired();
            entity.HasIndex(e => e.TokenHash).IsUnique();
            entity.Property(e => e.PayloadSnapshotJson).HasColumnName("payload_snapshot_json").HasColumnType("jsonb").IsRequired();
            entity.Property(e => e.IssuedByAdminId).HasColumnName("issued_by_admin_id").IsRequired();
            entity.Property(e => e.IssuedAt).HasColumnName("issued_at").IsRequired();
            entity.Property(e => e.ExpiresAt).HasColumnName("expires_at").IsRequired();
            entity.Property(e => e.RevokedAt).HasColumnName("revoked_at");
            entity.Property(e => e.RevokeReason).HasColumnName("revoke_reason");
            entity.Property(e => e.ScanCount).HasColumnName("scan_count").HasDefaultValue(0);
            entity.Property(e => e.LastScannedAt).HasColumnName("last_scanned_at");
            entity.HasOne(e => e.Event)
                .WithMany()
                .HasForeignKey(e => e.EventId);
            entity.HasOne(e => e.Timeslot)
                .WithMany()
                .HasForeignKey(e => e.TimeslotId);
        });

        modelBuilder.Entity<VisitLog>(entity =>
        {
            entity.ToTable("visit_logs");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.SessionId).HasColumnName("session_id");
            entity.Property(e => e.EventType).HasColumnName("event_type");
            entity.Property(e => e.SpotCode).HasColumnName("spot_code");
            entity.Property(e => e.PayloadJson).HasColumnName("payload_json");
            entity.Property(e => e.OccurredAt).HasColumnName("occurred_at");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.LocationLat).HasColumnName("location_lat");
            entity.Property(e => e.LocationLng).HasColumnName("location_lng");
            entity.Property(e => e.LocationAccuracy).HasColumnName("location_accuracy");
            entity.Property(e => e.PrevHash).HasColumnName("prev_hash");
            entity.Property(e => e.Hash).HasColumnName("hash");
            entity.Property(e => e.HashAlg).HasColumnName("hash_alg");
            entity.Property(e => e.ChainId).HasColumnName("chain_id");
            entity.HasIndex(e => new { e.ChainId, e.CreatedAt }).HasDatabaseName("ix_visit_logs_chain_id_created_at");
        });

        modelBuilder.Entity<OneTimeLoginCode>(entity =>
        {
            entity.ToTable("one_time_login_codes");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CodeHash).HasColumnName("code_hash").IsRequired();
            entity.HasIndex(e => e.CodeHash).IsUnique();
            entity.Property(e => e.EventId).HasColumnName("event_id").IsRequired();
            entity.Property(e => e.ExpiresAt).HasColumnName("expires_at").IsRequired();
            entity.Property(e => e.UsedAt).HasColumnName("used_at");
            entity.Property(e => e.UsedByUuid).HasColumnName("used_by_uuid");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
        });

        modelBuilder.Entity<OneTimeLoginCode>(entity =>
        {
            entity.ToTable("one_time_login_codes");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CodeHash).HasColumnName("code_hash").IsRequired();
            entity.HasIndex(e => e.CodeHash).IsUnique();
            entity.Property(e => e.EventId).HasColumnName("event_id").IsRequired();
            entity.Property(e => e.ExpiresAt).HasColumnName("expires_at").IsRequired();
            entity.Property(e => e.UsedAt).HasColumnName("used_at");
            entity.Property(e => e.UsedByUuid).HasColumnName("used_by_uuid");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
        });

        modelBuilder.Entity<IssuedToken>(entity =>
        {
            entity.ToTable("issued_tokens");
            entity.HasKey(e => e.Jti);
            entity.Property(e => e.Jti).HasColumnName("jti");
            entity.Property(e => e.Subject).HasColumnName("subject").IsRequired();
            entity.Property(e => e.IssuedAt).HasColumnName("issued_at").IsRequired();
            entity.Property(e => e.ExpiresAt).HasColumnName("expires_at").IsRequired();
            entity.HasIndex(e => e.Subject);
        });

        modelBuilder.Entity<RevokedToken>(entity =>
        {
            entity.ToTable("revoked_jti");
            entity.HasKey(e => e.Jti);
            entity.Property(e => e.Jti).HasColumnName("jti");
            entity.Property(e => e.RevokedAt).HasColumnName("revoked_at").IsRequired();
            entity.Property(e => e.Reason).HasColumnName("reason");
            entity.Property(e => e.RevokedByUserId).HasColumnName("revoked_by_user_id");
            entity.Property(e => e.ExpiresAt).HasColumnName("expires_at").IsRequired();
        });
    }
}

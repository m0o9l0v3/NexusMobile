using System.Data;
using AdminApi.Models;
using AdminApi.Services;
using Microsoft.EntityFrameworkCore;
using Npgsql;

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

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Spot>(entity =>
        {
            entity.ToTable("spots");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Code).HasColumnName("code").IsRequired();
            entity.HasIndex(e => e.Code).IsUnique();
            entity.Property(e => e.Name).HasColumnName("name").IsRequired();
            entity.Property(e => e.Description).HasColumnName("description").IsRequired();
            entity.Property(e => e.Tags).HasColumnName("tags");
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
            entity.Property(e => e.OccurredAt).HasColumnName("occurred_at");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
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

    public override int SaveChanges()
    {
        return SaveChangesAsync().GetAwaiter().GetResult();
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var logsToHash = ChangeTracker.Entries<VisitLog>()
            .Where(entry => entry.State == EntityState.Added)
            .Select(entry => entry.Entity)
            .ToList();

        if (logsToHash.Count == 0 || _auditLogHasher is null)
        {
            return await base.SaveChangesAsync(cancellationToken);
        }

        if (!Database.IsRelational())
        {
            await PrepareAuditLogsAsync(logsToHash, cancellationToken);
            return await base.SaveChangesAsync(cancellationToken);
        }

        const int maxAttempts = 3;
        for (var attempt = 1; attempt <= maxAttempts; attempt++)
        {
            await using var transaction = await Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
            try
            {
                await PrepareAuditLogsAsync(logsToHash, cancellationToken);
                var result = await base.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return result;
            }
            catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.SerializationFailure && attempt < maxAttempts)
            {
                await transaction.RollbackAsync(cancellationToken);
            }
        }

        throw new InvalidOperationException("Failed to persist audit logs after retrying serialization failures.");
    }

    private async Task PrepareAuditLogsAsync(IReadOnlyCollection<VisitLog> logsToHash, CancellationToken cancellationToken)
    {
        if (_auditLogHasher is null)
        {
            return;
        }

        foreach (var log in logsToHash)
        {
            if (log.OccurredAt == default)
            {
                log.OccurredAt = DateTimeOffset.UtcNow;
            }

            if (log.CreatedAt == default)
            {
                log.CreatedAt = DateTimeOffset.UtcNow;
            }
        }

        var orderedLogs = logsToHash
            .OrderBy(log => log.CreatedAt)
            .ThenBy(log => log.Id)
            .ToList();

        var chainIds = orderedLogs
            .Select(log => string.IsNullOrWhiteSpace(log.ChainId) ? _auditLogHasher.BuildChainId(log) : log.ChainId!)
            .Distinct()
            .ToList();

        var lastHashes = new Dictionary<string, string>();
        foreach (var chainId in chainIds)
        {
            var lastHash = await VisitLogs.AsNoTracking()
                .Where(log => log.ChainId == chainId && log.Hash != null)
                .OrderByDescending(log => log.CreatedAt)
                .Select(log => log.Hash)
                .FirstOrDefaultAsync(cancellationToken);

            lastHashes[chainId] = lastHash ?? string.Empty;
        }

        foreach (var log in orderedLogs)
        {
            var chainId = string.IsNullOrWhiteSpace(log.ChainId) ? _auditLogHasher.BuildChainId(log) : log.ChainId!;
            var prevHash = lastHashes.TryGetValue(chainId, out var hash) ? hash : string.Empty;

            log.ChainId = chainId;
            log.PrevHash = prevHash;
            log.HashAlg = _auditLogHasher.HashAlgorithm;
            log.Hash = _auditLogHasher.ComputeHash(log, prevHash, chainId);

            lastHashes[chainId] = log.Hash;
        }
    }
}

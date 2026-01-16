using AdminApi.Models;
using Microsoft.EntityFrameworkCore;

namespace AdminApi.Data;

public sealed class AdminDbContext : DbContext
{
    public AdminDbContext(DbContextOptions<AdminDbContext> options) : base(options)
    {
    }

    public DbSet<Spot> Spots => Set<Spot>();
    public DbSet<Event> Events => Set<Event>();
    public DbSet<OcDay> OcDays => Set<OcDay>();
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

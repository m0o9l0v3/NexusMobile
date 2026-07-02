using System.Reflection;
using AdminApi.Data;
using AdminApi.Options;
using AdminApi.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ApplicationParts;
using Microsoft.EntityFrameworkCore;
using PublicApi.Infrastructure;
using PublicApi.Services;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((context, services, config) =>
{
    config.ReadFrom.Configuration(context.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext()
        .WriteTo.Console();
});

builder.Services.AddProblemDetails();
builder.Services.Configure<ApiBehaviorOptions>(options => options.SuppressModelStateInvalidFilter = true);
builder.Services.Configure<AuditLogOptions>(builder.Configuration.GetSection(AuditLogOptions.SectionName));

var dbProvider = builder.Configuration.GetValue<string>("DatabaseProvider")?.ToLowerInvariant();
var adminDbConnection = builder.Configuration.GetConnectionString("AdminDatabase");
var publicApiReadOnlyConnection = builder.Configuration.GetConnectionString("PublicApiReadOnly");

builder.Services.AddDbContext<AdminDbContext>(options =>
{
    if (dbProvider == "sqlite")
    {
        options.UseSqlite(adminDbConnection ?? "Data Source=public-dev.db");
        return;
    }

    // PublicApiReadOnly is populated only once the nexus_public_readonly DB role is wired up
    // in production (see docs/deploy-public-api-readonly-role.md); until then this falls back
    // to AdminDatabase so docker-compose and existing deployments keep working unchanged.
    options.UseNpgsql(publicApiReadOnlyConnection ?? adminDbConnection ?? throw new InvalidOperationException("ConnectionStrings:PublicApiReadOnly or ConnectionStrings:AdminDatabase is required."));
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.WithOrigins(builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? Array.Empty<string>())
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

builder.Services.AddScoped<AuditLogHasher>();
builder.Services.AddScoped<LogPersistenceService>();
builder.Services.AddScoped<NearbyQueryService>();
builder.Services.AddSingleton<IBackgroundTaskQueue, BackgroundTaskQueue>();
builder.Services.AddHostedService<QueuedHostedService>();
builder.Services.AddSingleton<PublicApi.Services.Navigation.NavigationDataStore>();

builder.Services.AddControllers()
    .ConfigureApplicationPartManager(manager =>
    {
        manager.ApplicationParts.Clear();
        manager.ApplicationParts.Add(new AssemblyPart(typeof(Program).Assembly));
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new() { Title = "Nexus Public API", Version = "v1" });
    options.SupportNonNullableReferenceTypes();
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        options.IncludeXmlComments(xmlPath);
    }
});

var app = builder.Build();

app.UseSerilogRequestLogging();
app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowFrontend");

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
app.MapControllers();

app.Run();

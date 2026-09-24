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
DatabaseRuntimeConfiguration.LoadSecretFiles(builder.Configuration);
var databaseConnection = DatabaseRuntimeConfiguration.ResolveConnection(builder.Configuration, builder.Environment.IsDevelopment(), publicApi: true);
if (!builder.Environment.IsDevelopment())
    DatabaseRuntimeConfiguration.RequireSecret(builder.Configuration, "AuditLog:HashKey");

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

builder.Services.AddDbContext<AdminDbContext>(options =>
{
    if (dbProvider == "sqlite")
    {
        options.UseSqlite(databaseConnection);
        return;
    }

    options.UseNpgsql(databaseConnection);
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

if (!app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    await DatabaseReadiness.CheckAsync(scope.ServiceProvider.GetRequiredService<AdminDbContext>(), publicApi: true);
}

app.Run();

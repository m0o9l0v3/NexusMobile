using System.Net;
using System.Threading.RateLimiting;
using AdminApi.Options;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace AdminApi.RateLimiting;

/// <summary>admin-api / public-api 共通の rate limiting と X-Forwarded-For 設定。</summary>
public static class RateLimitingExtensions
{
    private static readonly string[] PolicyNames =
    {
        RateLimitPolicies.AuthLogin,
        RateLimitPolicies.CodeRedeem,
        RateLimitPolicies.QrLanding,
        RateLimitPolicies.LogIngest,
        RateLimitPolicies.LogIngestBatch,
    };

    public static IServiceCollection AddNexusRateLimiting(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<RateLimitOptions>(configuration.GetSection(RateLimitOptions.SectionName));

        // 設定値は起動後に解決する（テスト等での上書きを反映するため）。
        services.AddOptions<ForwardedHeadersOptions>()
            .Configure<IOptions<RateLimitOptions>>((forwarded, rateLimit) =>
            {
                forwarded.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
                forwarded.ForwardLimit = 1;

                var options = rateLimit.Value;
                if (options.KnownProxies.Length == 0 && options.KnownNetworks.Length == 0)
                    return;

                forwarded.KnownProxies.Clear();
                forwarded.KnownNetworks.Clear();
                foreach (var proxy in options.KnownProxies)
                    forwarded.KnownProxies.Add(IPAddress.Parse(proxy));
                foreach (var network in options.KnownNetworks)
                {
                    var parts = network.Split('/', 2);
                    forwarded.KnownNetworks.Add(new Microsoft.AspNetCore.HttpOverrides.IPNetwork(IPAddress.Parse(parts[0]), int.Parse(parts[1])));
                }
            });

        services.AddOptions<RateLimiterOptions>()
            .Configure<IOptions<RateLimitOptions>>((limiter, rateLimit) =>
            {
                var options = rateLimit.Value;
                limiter.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
                limiter.OnRejected = WriteRejectionAsync;

                foreach (var name in PolicyNames)
                {
                    if (!options.Policies.TryGetValue(name, out var policy))
                        continue;

                    limiter.AddPolicy(name, context =>
                    {
                        if (!options.Enabled)
                            return RateLimitPartition.GetNoLimiter("disabled");

                        var clientIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
                        return RateLimitPartition.GetFixedWindowLimiter(clientIp, _ => new FixedWindowRateLimiterOptions
                        {
                            PermitLimit = policy.PermitLimit,
                            Window = TimeSpan.FromSeconds(policy.WindowSeconds),
                            QueueLimit = 0,
                            AutoReplenishment = true,
                        });
                    });
                }
            });

        services.AddRateLimiter(_ => { });
        return services;
    }

    private static async ValueTask WriteRejectionAsync(OnRejectedContext context, CancellationToken cancellationToken)
    {
        var response = context.HttpContext.Response;
        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
            response.Headers.RetryAfter = ((int)Math.Ceiling(retryAfter.TotalSeconds)).ToString();

        await response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = StatusCodes.Status429TooManyRequests,
            Title = "Too many requests",
            Detail = "Rate limit exceeded. Retry after the interval given in the Retry-After header.",
        }, cancellationToken);
    }
}

# Public API

Nexus participant-facing API (`apps/public-api`) is implemented as ASP.NET Core 8 Web API.

## Data access design

This project reuses the existing `AdminApi.Data.AdminDbContext` and entity models via:

- Project reference: `apps/public-api/PublicApi.csproj` -> `../admin-api/AdminApi.csproj`

No separate `packages/data` extraction was introduced in this change to keep migration/history compatibility with the existing admin database.

In production, this project connects through the `nexus_public_readonly` PostgreSQL role (see
`docs/deploy-public-api-readonly-role.md`), which grants `SELECT` on all tables plus a single
sanctioned `INSERT` on `visit_logs` for anonymous participant log ingestion
(`Services/LogPersistenceService.cs`) — turning "no writes in public-api" from a convention into
a database-enforced constraint.

## OpenAPI export

```bash
dotnet tool install --global Swashbuckle.AspNetCore.Cli
swagger tofile --yaml ./apps/public-api/bin/Debug/net8.0/PublicApi.dll v1 > ./openapi/public.yaml
```


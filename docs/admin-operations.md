# Nexus Admin Operations

## Environment
- Target runtime: Windows Server / Azure
- Database: PostgreSQL
- Admin API: ASP.NET Core (.NET 8)

## Admin Accounts
- Initial account is configured via `AdminAuth` in `appsettings.json` or environment variables.
- Replace the signing key before production.

## OpenAPI Export
- Swagger UI is available in Development at `/swagger`.
- Export YAML using Swashbuckle CLI:
  ```bash
  dotnet tool install --global Swashbuckle.AspNetCore.Cli
  swagger tofile --yaml ./apps/admin-api/bin/Debug/net8.0/AdminApi.dll v1 > ./packages/openapi/admin.yaml
  ```

## Notes
- Log aggregation and analytics are intentionally postponed.
- 3D/AR assets are planned as future extensions of Spot fields.

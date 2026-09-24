# Nexus Admin Operations

## Environment
- Target runtime: 選定済みVPS上のLinux / Docker Compose（OSとリソースはログイン後に確認）
- Database: PostgreSQL 18系。初期検証は18.6、本番導入時に最新修正版を再確認する。
- Admin API: ASP.NET Core (.NET 8)

本番DBの構築、接続権限、バックアップ、復旧、更新は
[本番データベースの採用・運用方針](decisions/production-database.md)を正とする。
現行の開発用Composeと起動時シーダーは本番向けの実装ではない。
構築・更新・検証の実行方法は[本番DBの構築・検証手順](production-database-runbook.md)を参照する。

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

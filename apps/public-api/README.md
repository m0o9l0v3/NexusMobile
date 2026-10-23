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


## Participant bundle (`GET /api/v2/bundle`)

参加者向け公開データの配信（E2-5 §4、#23）。

- `delivery.current_bundle`・`delivery.participant_bundles` を、admin・public と同じデータベースへの既存の接続で読む（M1-2）。`delivery` は Studio の移行で作られるため `AdminDbContext` のモデルには含めず、SQL を直接発行する（admin の移行履歴を変えない）。`Services/Delivery/ParticipantBundleRepository.cs`
- 現在の版の bytes はメモリに保持し、リクエストごとに読むのは版番号だけ。版が変わったときだけ本体を読み直し、SHA-256 と大きさを保存時の値と照合する（不一致は 500）。`Services/Delivery/ParticipantBundleCache.cs`
- SQLite の開発環境には `delivery` がないため、常に 404（未公開）を返す。
- 設定：`ParticipantBundle:RecheckAfterSeconds`（`Nexus-Recheck-After`、既定 300）、`ParticipantBundle:UnavailableRetryAfterSeconds`（503 の `Retry-After`、既定 30）。いずれも仮の値。
- `openapi/public.yaml` の `/api/v2/bundle` は応答ヘッダーを手で記述している。上の `swagger tofile` で全体を書き出すとヘッダーの記述が消えるため、書き出した結果から変更のあった path だけを反映する。

# public-api専用DBロールの導入

新規本番DBは[本番DBの構築・検証手順](production-database-runbook.md)に従う。
従来の `nexus_public_readonly` と全テーブルへのSELECT付与を使う手順は、新規本番構築には適用しない。

## 新規本番での権限

- 接続ユーザーは `nexus_public`。移行専用ユーザー・管理APIと資格情報を分ける。
- 公開スポット・イベントだけを読み取れるよう、`spots` / `events` にSELECTと行単位の制限を設定する。
- `visit_logs` へのINSERT、および監査チェーンに必要な `chain_id` / `created_at` / `hash` のSELECTを許可する。
- 起動時の整合確認用に `__EFMigrationsHistory` のSELECTを許可する。
- MapDatasetを含む管理用表・将来追加される表への既定SELECT、データ更新・削除、DDL、所有者への昇格を許可しない。

権限の正本は `deploy/database/grant-runtime.sql`。移行適用後に `nexus_owner` として実行する。
本番の `ConnectionStrings:PublicApiReadOnly` またはその `File` 設定は必須であり、管理API用接続へのフォールバックはDevelopmentに限定する。
設定不足・管理者資格情報・不一致の移行履歴がある場合は起動を停止する。

## 確認と復旧

`tools/database/verify.py` が実PostgreSQLで、未公開行・管理表・将来表の読み取り拒否、ログINSERT、API起動とHTTP応答を検証する。
既存環境に従来ロールがある場合、その権限や接続を自動変更しない。稼働中の接続を調査し、専用ロールへの切替手順を別途確認する。

接続切替に失敗した場合は公開APIを停止して専用接続と権限を修復する。管理APIの資格情報への切替を復旧策にしない。

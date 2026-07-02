# public-api 読み取り専用DBロール デプロイ手順

`AddPublicApiReadOnlyRole` マイグレーションは PostgreSQL 上に `nexus_public_readonly`
ロールを `NOLOGIN` で作成するのみで、パスワード発行とアプリからの接続切り替えは
本番デプロイ側の作業として分離している（マイグレーション履歴に秘密情報を残さないため）。

## 1. ロールへのログイン権限付与

マイグレーション適用後、本番DBに対して以下を実行する。手動実行、またはシークレット管理
ツール（例: Azure Key Vault / AWS Secrets Manager経由のデプロイスクリプト）経由での実行を想定。

```sql
ALTER ROLE nexus_public_readonly WITH LOGIN PASSWORD '<十分な長さのランダムなパスワード>';
```

- パスワードはコード・ドキュメント・チケットのいずれにも平文で残さない。
- ローテーション時も同じ `ALTER ROLE ... WITH LOGIN PASSWORD` で再発行できる。

## 2. public-api の接続文字列切り替え

`apps/public-api/appsettings.Production.json` は `ConnectionStrings:PublicApiReadOnly` キー自体を
**意図的に含めない**（空文字列やダミー値をコミットすると、それだけで有効な接続文字列として
扱われてしまい `AdminDatabase` へのフォールバックが効かなくなるため）。実値は必ず環境変数
オーバーライドでのみ注入する。

```bash
export ConnectionStrings__PublicApiReadOnly="Host=<db-host>;Port=5432;Database=nexus_admin;Username=nexus_public_readonly;Password=<発行したパスワード>"
```

- `PublicApiReadOnly` が未設定（または空白のみ）の間は `AdminDatabase`（従来通りの書き込み可能な
  接続）にフォールバックする（`apps/public-api/Program.cs`）。切り替え後に初めて読み取り専用
  ロールが実際に使われる。
- 切り替え後も `visit_logs` テーブルへの INSERT は許可されているため、匿名参加者ログの
  書き込み（`LogsController` → `LogPersistenceService`）は引き続き動作する。

## 3. 動作確認

`nexus_public_readonly` ユーザーで直接 `psql` に接続し、想定通りの権限になっているか確認する。

```bash
psql "host=<db-host> port=5432 dbname=nexus_admin user=nexus_public_readonly password=<発行したパスワード>"
```

```sql
-- 成功するはず（読み取りは許可）
SELECT count(*) FROM events;

-- 成功するはず（visit_logs への書き込みのみ例外的に許可）
INSERT INTO visit_logs (id, session_id, event_type, occurred_at, created_at, chain_id, prev_hash, hash, hash_alg)
VALUES (gen_random_uuid(), 'smoke-test', 'spot_view', now(), now(), 'smoke-test', '', 'placeholder', 'sha256');

-- 失敗するはず（read-onlyロールに書き込み権限がないテーブル）
UPDATE events SET name = 'should fail' WHERE false;
```

## 4. ロールバック時の注意

`Down` マイグレーションは権限剥奪の後に `DROP ROLE` を実行する。そのため、ロールバックを行う
前に **必ず public-api 側の接続文字列を `AdminDatabase`（または他の有効な接続）に退避してから**
マイグレーションをロールバックすること。順序を誤ると、ロール削除後も public-api が
`nexus_public_readonly` への接続を試み続け、全リクエストが認証エラーで失敗する。

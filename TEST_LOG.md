# テスト実行ログ

## 2026-01-20 15:52:47

### テスト内容
- apps/admin-api のビルド（dotnet build）

### 表示されたエラー
- apphost.exe や obj 内の一時ファイルへのアクセス拒否（CreateAppHost/UnauthorizedAccess）

### 解決した方法
- 実行中の dotnet プロセスを停止
- obj/bin を削除し、BaseIntermediateOutputPath を TEMP に切り替えてビルド

---

### テスト内容
- apps/admin-api-tests の dotnet test（OneDrive 配下）

### 表示されたエラー
- obj 内の一時ファイル作成でアクセス拒否
- AssemblyAttribute 重複（CS0579）
- Options.Create が AdminApi.Options と衝突（Create が見つからない）

### 解決した方法
- 一時的に C:\Work\Nexus へコピーして実行
- apps/admin-api-tests/AdminApi.Tests.csproj に FrameworkReference（Microsoft.AspNetCore.App）を追加
- apps/admin-api-tests/OneTimeLoginServiceTests.cs の Options.Create を完全修飾

---

### テスト内容
- apps/admin-api-tests の dotnet test（C:\Work\Nexus）

### 表示されたエラー
- HS256 署名キー長不足（IDX10720: 256 bits 未満）

### 解決した方法
- テスト用署名キーを 32 文字以上に変更

---

### テスト内容
- apps/admin-api-tests の dotnet test（C:\Work\Nexus、最終）

### 結果
- 成功（合格 4 / 失敗 0 / スキップ 0）

---

### テスト内容
- apps/admin-api-tests の dotnet test（OneDrive 配下、TEMP 出力指定）

### 表示されたエラー
- AdminApi.csproj の AssemblyAttribute 重複（CS0579）

### 解決した方法
- OneDrive 外の C:\Work\Nexus で実行し回避

---

## 2026-01-21 12:12:35

### テスト内容
- apps/admin-web の npm run build（C:\Work\Nexus）

### 表示されたエラー
- なし

### 解決した方法
- 事前に src/api/client.ts の headers 設定を fetch フックに変更

---

### テスト内容
- web の npm run build（C:\Work\Nexus）

### 表示されたエラー
- なし

### 解決した方法
- 追加対応なし

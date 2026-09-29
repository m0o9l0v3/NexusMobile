#!/usr/bin/env bash
# ローカル Docker Compose 用の Secret を生成し、リポジトリ直下の .env に追記する。
# 既存キーは上書きしない（冪等）。生成した値は出力しない。
set -euo pipefail
umask 077
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
env_file="${NEXUS_ENV_FILE:-$root/.env}"
command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }
touch "$env_file"
chmod 600 "$env_file"
for key in NEXUS_DEV_DB_PASSWORD NEXUS_DEV_SIGNING_KEY NEXUS_DEV_AUDIT_HASH_KEY; do
  if grep -Eq "^${key}=.+" "$env_file"; then
    echo "skip: $key (already set)"
    continue
  fi
  # 空値の行が残っていれば取り除いてから追記する
  sed -i.bak "/^${key}=\$/d" "$env_file" && rm -f "$env_file.bak"
  value=$(openssl rand -hex 32)
  [[ -n "$value" ]] || { echo "failed to generate $key" >&2; exit 1; }
  printf '%s=%s\n' "$key" "$value" >> "$env_file"
  echo "generated: $key"
done

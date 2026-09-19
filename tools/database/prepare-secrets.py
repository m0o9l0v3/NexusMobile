#!/usr/bin/env python3
"""Generate fresh local secret files; does not create cloud credentials or connect anywhere."""
import os
from pathlib import Path
import secrets
import sys

if len(sys.argv) != 2:
    raise SystemExit("Usage: prepare-secrets.py <new-private-directory>")
target = Path(sys.argv[1]).resolve()
repo = Path(__file__).resolve().parents[2]
if target == repo or repo in target.parents:
    raise SystemExit("Production secrets must be outside the repository.")
target.mkdir(mode=0o700, parents=True, exist_ok=False)
for name in ["postgres_password", "admin_password", "public_password", "migrator_password", "backup_cipher", "admin_login", "signing_key", "audit_key", "one_time_key", "qr_key"]:
    descriptor = os.open(target / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as file:
        file.write(secrets.token_hex(32))
for name, role in [("admin", "nexus_admin_app"), ("public", "nexus_public")]:
    descriptor = os.open(target / (name + "_connection"), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as file:
        file.write(f"Host=postgres;Port=5432;Database=nexus_admin;Username={role};Password={(target / (name + '_password')).read_text()}")
print("Secret files created. Supply separately scoped backup_s3_key and backup_s3_secret files before deployment.")

#!/usr/bin/env python3
"""Disposable local PostgreSQL, API, permission and encrypted PITR exercise.

Requires Docker/Compose, Python 3, and .NET 8. No cloud credentials are used.
On failure only this run's containers are stopped; artifacts/volumes are preserved.
"""
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import time
import urllib.request
import importlib.util

transfer_spec = importlib.util.spec_from_file_location("backup_transfer", Path(__file__).with_name("download-backup.py"))
transfer = importlib.util.module_from_spec(transfer_spec)
transfer_spec.loader.exec_module(transfer)

ROOT = Path(__file__).resolve().parents[2]
DOTNET = os.environ.get("DOTNET", "dotnet")
DOCKER = os.environ.get("DOCKER", "docker")
COMPOSE = os.environ.get("COMPOSE", "docker-compose")
context = os.environ.get("DOCKER_CONTEXT")
if not context:
    raise SystemExit("Set DOCKER_CONTEXT explicitly to a local verification engine.")
endpoint = subprocess.check_output([DOCKER, "context", "inspect", context, "--format", "{{.Endpoints.docker.Host}}"], text=True).strip()
if not endpoint.startswith("unix://"):
    raise SystemExit("Only a local Unix-socket Docker context is supported.")

artifact_root = ROOT / ".local/database-verification"
artifact_root.mkdir(parents=True, exist_ok=True, mode=0o700)
run_dir = Path(tempfile.mkdtemp(prefix="nexus-db-verify-", dir=artifact_root))
project = "nexus-db-verify-" + secrets.token_hex(6)
env = dict(os.environ, NEXUS_DB_VERIFY_DIR=str(run_dir), NEXUS_DB_DISPOSABLE="1")
compose = [COMPOSE, "--project-name", project, "--file", str(ROOT / "deploy/database/compose.verify.yml")]
steps = []
processes = []
print(f"Verification artifacts: {run_dir}", flush=True)


def run(args, *, stdin=None, expected_failure=False, extra_env=None, capture=False):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, env=env | (extra_env or {}), input=stdin, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if not capture:
        print(result.stdout, end="", flush=True)
    if (result.returncode == 0) == expected_failure:
        raise RuntimeError(f"Unexpected exit code {result.returncode}: {args[0]}")
    return result.stdout


def dc(*args, **kwargs):
    return run(compose + list(args), **kwargs)


def sql(text, service="postgres", database="nexus_verify", *, migrator=False, expected_failure=False):
    if migrator:
        command = ["bash", "-c", f'export PGPASSWORD="$(cat /run/secrets/migrator_password)"; exec psql -h 127.0.0.1 -U nexus_migrator -d {database} -v ON_ERROR_STOP=1 -At']
    else:
        command = ["psql", "-U", "postgres", "-d", database, "-v", "ON_ERROR_STOP=1", "-At"]
    return dc("exec", "-T", service, *command, stdin=text, expected_failure=expected_failure, capture=True)


def step(name):
    steps.append({"step": name, "status": "passed", "at": time.time()})
    (run_dir / "results.json").write_text(json.dumps(steps, indent=2))
    print("PASS: " + name, flush=True)


def connections(service):
    port = dc("port", service, "5432", capture=True).strip().rsplit(":", 1)[1]
    for role, filename in [("nexus_admin_app", "admin"), ("nexus_public", "public")]:
        path = run_dir / f"{filename}_connection"
        path.write_text(f"Host=127.0.0.1;Port={port};Database=nexus_verify;Username={role};Password={(run_dir / (filename + '_password')).read_text().strip()};Timeout=10")
        path.chmod(0o600)
        env[f"NEXUS_VERIFY_{filename.upper()}_CONNECTION_FILE"] = str(path)


def tool(*args):
    return run([DOTNET, ROOT / "tools/database/bin/Debug/net8.0/Nexus.Database.dll", *args])


def stop_apis():
    for process, stream in processes:
        process.terminate()
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        stream.close()
    processes.clear()


def api_startup():
    # Use local random free ports; the DB connections point only at this run's cluster.
    import socket
    for app, route in [("admin", "/admin/spots"), ("public", "/health")]:
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        path = ROOT / f"apps/{app}-api"
        dll = path / f"bin/Debug/net8.0/{app.title()}Api.dll"
        api_env = env | {"ASPNETCORE_ENVIRONMENT": "Production", "ASPNETCORE_URLS": f"http://127.0.0.1:{port}",
                         "DatabaseProvider": "postgresql", "AdminAuth__PasswordFile": str(run_dir / "admin_login"),
                         "AdminAuth__SigningKeyFile": str(run_dir / "signing_key"), "AuditLog__HashKeyFile": str(run_dir / "audit_key")}
        key = "AdminDatabase" if app == "admin" else "PublicApiReadOnly"
        api_env["ConnectionStrings__" + key + "File"] = str(run_dir / (app + "_connection"))
        stream = (run_dir / f"{app}-api.log").open("w")
        process = subprocess.Popen([DOTNET, str(dll)], cwd=path, env=api_env, stdout=stream, stderr=subprocess.STDOUT)
        processes.append((process, stream))
        for _ in range(60):
            if process.poll() is not None:
                raise RuntimeError(f"{app} API exited; see {run_dir / (app + '-api.log')}")
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}{route}", timeout=1) as response:
                    if app == "public":
                        assert response.status == 200
                    break
            except urllib.error.HTTPError as error:
                if app == "admin" and error.code == 401:
                    break
                raise
            except (urllib.error.URLError, TimeoutError):
                time.sleep(0.5)
        else:
            raise RuntimeError(f"{app} API startup timed out")
        if app == "public":
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/spots/public") as response:
                data = response.read().decode()
                assert "verification-visible" in data and "verification-hidden" not in data
    stop_apis()


try:
    for name in ["postgres_password", "admin_password", "public_password", "migrator_password", "backup_cipher", "admin_login", "signing_key", "audit_key"]:
        path = run_dir / name
        path.write_text(secrets.token_hex(32))
        path.chmod(0o600)
    restore_args = [DOTNET, "restore", ROOT / "tools/database/Nexus.Database.csproj"]
    if os.environ.get("NUGET_PACKAGES"):
        restore_args.extend(["--packages", os.environ["NUGET_PACKAGES"]])
    run(restore_args)
    run([DOTNET, "build", ROOT / "tools/database/Nexus.Database.csproj", "--no-restore"])
    tool("script", str(run_dir / "migrate.sql"))
    dc("up", "-d", "--build", "--wait", "--wait-timeout", "180", "postgres")
    versions = dc("exec", "-T", "postgres", "bash", "-c", "postgres --version && pgbackrest version", capture=True)
    (run_dir / "versions.txt").write_text(versions)
    assert "18.6" in versions and "2.59.1" in versions
    sql("CREATE DATABASE nexus_legacy_guard OWNER nexus_owner;", database="postgres")
    sql("CREATE TABLE existing_data(value text); INSERT INTO existing_data VALUES ('preserve');", database="nexus_legacy_guard")
    rejected = sql((run_dir / "migrate.sql").read_text(), database="nexus_legacy_guard", migrator=True, expected_failure=True)
    assert "Existing public schema detected" in rejected
    assert sql("SELECT value FROM existing_data; SELECT to_regclass('map_datasets') IS NULL; SELECT to_regclass('\"__EFMigrationsHistory\"') IS NULL;", database="nexus_legacy_guard").splitlines() == ["preserve", "t", "t"]
    step("Unknown existing schema rejected before any table/history creation")
    migration = (run_dir / "migrate.sql").read_text()
    sql(migration, migrator=True)
    sql(migration, migrator=True)
    grants = (ROOT / "deploy/database/grant-runtime.sql").read_text()
    sql("SET ROLE nexus_owner;\n" + grants, migrator=True)
    step("Complete empty-database initialization and idempotent migration replay")
    connections("postgres")
    sql("SET ROLE nexus_owner; CREATE TABLE verification_future (id integer);", migrator=True)
    tool("verify")
    sql("SET ROLE nexus_owner; DROP TABLE verification_future;", migrator=True)
    step("Real Npgsql/EF storage, all model columns/types, role restrictions, RLS and audit chain")
    before = sql("SELECT count(*) FROM map_datasets; SELECT count(*) FROM spots; SELECT count(*) FROM events;")
    api_startup()
    assert sql("SELECT count(*) FROM map_datasets; SELECT count(*) FROM spots; SELECT count(*) FROM events;") == before
    step("Both Production APIs start with runtime roles; no migration or sample seeding")
    dc("restart", "postgres")
    dc("up", "-d", "--wait", "--wait-timeout", "120", "postgres")
    connections("postgres")
    tool("assert-restored", "1")
    sql(migration, migrator=True)
    step("Restart and migration replay preserve all verification data")
    dc("exec", "-T", "--user", "postgres", "postgres", "pgbackrest", "--stanza=nexus", "stanza-create")
    dc("exec", "-T", "--user", "postgres", "postgres", "pgbackrest", "--stanza=nexus", "check")
    dc("exec", "-T", "--user", "postgres", "postgres", "nexus-backup", "full")
    tool("add-version", "2")
    dc("exec", "-T", "--user", "postgres", "postgres", "nexus-backup", "diff")
    sql("SELECT pg_create_restore_point('nexus_verified');")
    tool("add-version", "3")
    sql("SELECT pg_switch_wal();")
    dc("exec", "-T", "--user", "postgres", "postgres", "pgbackrest", "--stanza=nexus", "check")
    info = dc("exec", "-T", "--user", "postgres", "postgres", "pgbackrest", "--stanza=nexus", "--output=json", "info", capture=True)
    (run_dir / "backup-info.json").write_text(info)
    assert json.loads(info)[0]["cipher"] == "aes-256-cbc"
    pitr_set = json.loads(info)[0]["backup"][-1]["label"]
    step("Encrypted full/differential backups and continuous WAL archiving")
    # receive uses the same byte-stream/partial-file checks as the Mac SSH command.
    with_env = ["env", "NEXUS_DB_VERIFY_DIR=" + str(run_dir)]
    archive = transfer.receive(with_env + compose + ["exec", "-T", "--user", "postgres", "postgres", "nexus-backup", "export"],
                               run_dir / "mac-copy", source="local-disposable-container")
    with archive.open("rb") as source:
        subprocess.run(compose + ["run", "--rm", "--no-deps", "-T", "--entrypoint", "bash", "recovery", "-c",
                       "test -z \"$(ls -A /backup)\" && chown postgres:postgres /backup && exec gosu postgres tar --directory=/backup --extract --file=- --no-same-owner"],
                       cwd=ROOT, env=env, stdin=source, check=True)
    step("Encrypted export received on Mac and imported into an independent backup volume without cloud storage")
    # The original repository/container is no longer available during either restore.
    dc("stop", "postgres")
    started = time.monotonic()
    dc("run", "--rm", "--no-deps", "recovery", "restore", "--set=" + pitr_set, "--type=name", "--target=nexus_verified", "--target-action=promote")
    dc("--profile", "recovery", "up", "-d", "--wait", "--wait-timeout", "180", "recovery")
    for _ in range(60):
        if sql("SELECT NOT pg_is_in_recovery();", service="recovery").strip() == "t":
            break
        time.sleep(1)
    else:
        raise RuntimeError("Recovery promotion timed out")
    connections("recovery")
    tool("assert-restored", "2")
    elapsed = time.monotonic() - started
    step(f"PITR from the Mac copy recovered version 2 and excluded version 3 with the source offline ({elapsed:.1f}s)")
    dc("run", "--rm", "--no-deps", "recovery-latest", "restore", "--type=immediate", "--target-action=promote")
    dc("--profile", "recovery", "up", "-d", "--wait", "--wait-timeout", "180", "recovery-latest")
    for _ in range(60):
        if sql("SELECT NOT pg_is_in_recovery();", service="recovery-latest").strip() == "t": break
        time.sleep(1)
    else: raise RuntimeError("Latest recovery promotion timed out")
    connections("recovery-latest")
    tool("assert-restored", "3")
    step("Latest full backup exported to Mac restored version 3 without the source DB or repository")
    (run_dir / "summary.json").write_text(json.dumps({"status": "passed", "project": project, "versions": versions.strip().splitlines(), "local_restore_seconds": round(elapsed, 1), "mac_archive_restore_verified": True, "vps_ssh_transfer_verified": False, "production_rpo_rto_verified": False, "steps": steps}, indent=2))
    dc("--profile", "recovery", "down", "--volumes", "--remove-orphans")
    print(f"PASS: all local checks. Evidence: {run_dir / 'summary.json'}", flush=True)
except BaseException:
    stop_apis()
    try:
        dc("--profile", "recovery", "stop")
    except Exception:
        pass
    print(f"FAILED: preserved project {project}; private artifacts {run_dir}", flush=True)
    raise

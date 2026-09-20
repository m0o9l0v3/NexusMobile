#!/usr/bin/env python3
"""Fetch an encrypted repository over existing SSH into a new, private Mac directory."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import subprocess
import tarfile


def validate_archive(path):
    required = {"archive/nexus/archive.info", "backup/nexus/backup.info"}
    with tarfile.open(path, "r:") as archive:
        for member in archive:
            name = member.name
            parts = PurePosixPath(name).parts
            if not parts or name.startswith("/") or ".." in parts or parts[0] not in {"archive", "backup"}:
                raise ValueError("Unexpected archive path")
            if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
                raise ValueError("Unexpected archive entry type")
            if member.issym() or member.islnk():
                target = member.linkname
                base = posixpath.dirname(name) if member.issym() else ""
                resolved = PurePosixPath(posixpath.normpath(posixpath.join(base, target)))
                if target.startswith("/") or ".." in resolved.parts or resolved.parts[0] not in {"archive", "backup"}:
                    raise ValueError("Archive link leaves backup repository")
            if member.isfile():
                required.discard(name)
    if required:
        raise ValueError("Archive is missing pgBackRest metadata")


def receive(command, destination, *, source):
    destination.mkdir(mode=0o700, parents=True, exist_ok=False)
    partial = destination / "repository.tar.partial"
    descriptor = os.open(partial, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as output:
        # stderr stays separate from the binary archive; nonzero exit never becomes success.
        subprocess.run(command, stdout=output, check=True)
        output.flush()
        os.fsync(output.fileno())
    validate_archive(partial)
    digest = hashlib.sha256()
    with partial.open("rb") as content:
        for block in iter(lambda: content.read(1024 * 1024), b""):
            digest.update(block)
    complete = destination / "repository.tar"
    partial.rename(complete)
    (destination / "repository.tar.sha256").write_text(digest.hexdigest() + "  repository.tar\n")
    (destination / "manifest.json").write_text(json.dumps({
        "source": source, "received_at_utc": datetime.now(timezone.utc).isoformat(),
        "sha256": digest.hexdigest(), "bytes": complete.stat().st_size,
        "status": "downloaded_not_restore_verified", "cipher_key_included": False,
        "restore_requirement": "Use the separately saved backup_cipher with pgBackRest; test restore before relying on this copy."
    }, indent=2) + "\n")
    return complete


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ssh_host", help="Existing SSH config alias or user@host")
    parser.add_argument("destination", type=Path, help="New directory outside the repository")
    parser.add_argument("--key-file", required=True, type=Path, help="Separately saved backup_cipher; never sent to the VPS")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.@-]*", args.ssh_host):
        parser.error("Use an SSH alias or user@host; configure port/key in ~/.ssh/config")
    destination = args.destination.expanduser().resolve()
    repo = Path(__file__).resolve().parents[2]
    if destination == repo or repo in destination.parents:
        parser.error("Store downloaded backups outside the repository")
    key = args.key_file.expanduser().resolve()
    if not key.is_file() or key.stat().st_size == 0 or key.stat().st_mode & 0o077:
        parser.error("Save the backup cipher key separately in a private file (mode 600)")
    if key == destination or destination in key.parents:
        parser.error("Keep the key outside the archive destination directory")
    archive = receive(["ssh", "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
                       "-o", "ServerAliveInterval=30", "-o", "ServerAliveCountMax=3", "--",
                       args.ssh_host, "sudo -n /usr/local/sbin/nexus-backup-host export"], destination, source=args.ssh_host)
    print(f"Saved encrypted backup: {archive}. Restore verification is still required.")


if __name__ == "__main__":
    main()

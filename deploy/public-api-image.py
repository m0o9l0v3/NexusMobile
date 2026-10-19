"""Validate manual image publication inputs and write a digest review receipt. No deployment."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.request

REPOSITORY = "m0o9l0v3/NexusMobile"
PACKAGE_NAME = "nexus-public-api-pg17-private"
IMAGE = f"ghcr.io/m0o9l0v3/{PACKAGE_NAME}"


def inputs(commit, platform):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("reviewed_commit must be a full lowercase commit SHA")
    if platform not in {"linux/amd64", "linux/arm64"}:
        raise ValueError("target_platform must be explicitly confirmed as linux/amd64 or linux/arm64")
    return "ubuntu-24.04" if platform == "linux/amd64" else "ubuntu-24.04-arm"


def require_private(package):
    if package.get("visibility") != "private" or package.get("package_type") != "container":
        raise ValueError("Existing GHCR package must be private and of type container; no visibility changes are automatic")


def check_package(allow_missing):
    if os.environ.get("GITHUB_REPOSITORY") != REPOSITORY:
        raise ValueError("Publication is restricted to the approved repository")
    owner_type = os.environ.get("GITHUB_REPOSITORY_OWNER_TYPE")
    if owner_type not in {"User", "Organization"}:
        raise ValueError("Unknown package owner type")
    prefix = "users" if owner_type == "User" else "orgs"
    url = f"https://api.github.com/{prefix}/m0o9l0v3/packages/container/{PACKAGE_NAME}"
    request = urllib.request.Request(url, headers={
        "Authorization": "Bearer " + os.environ["GH_TOKEN"],
        "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28",
    })
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            package = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404 and allow_missing:
            # First publication defaults to private. Never change an existing package's visibility.
            print("Package not visible yet; first publication must use GHCR's private default")
            return
        raise ValueError(f"GHCR package permission/visibility check failed (HTTP {error.code})") from None
    require_private(package)
    print("GHCR package visibility is private")


def receipt(commit, platform, digest, source, output):
    inputs(commit, platform)
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError("Build output digest is invalid")
    actual = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    if actual != commit:
        raise ValueError("Built checkout does not match the reviewed commit")
    if subprocess.check_output(["git", "-C", str(source), "status", "--porcelain", "--untracked-files=no"], text=True).strip():
        raise ValueError("Tracked build sources changed after checkout")
    job_url = os.environ.get("PUBLICATION_JOB_URL", "")
    if not re.fullmatch(r"https://github\.com/" + re.escape(REPOSITORY)
                        + r"/actions/runs/" + re.escape(os.environ["GITHUB_RUN_ID"]) + r"/job/[0-9]+", job_url):
        raise ValueError("Publication job URL is missing or does not match this run")
    output.mkdir(parents=True, exist_ok=True)
    ref = IMAGE + "@" + digest
    (output / "public-api.txt").write_text(ref + "\n")
    (output / "public-api.json").write_text(json.dumps({
        "repository": REPOSITORY, "source_commit": commit, "image": ref,
        "target_platform": platform, "visibility": "private",
        "workflow_commit": os.environ["GITHUB_SHA"],
        "run_url": f"https://github.com/{REPOSITORY}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
        "job_url": job_url,
        "run_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
        "provenance": "BuildKit mode=min attestation attached to registry image",
    }, indent=2) + "\n")
    print(ref)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    check = sub.add_parser("inputs")
    check.add_argument("--commit", required=True)
    check.add_argument("--platform", required=True)
    package = sub.add_parser("package")
    package.add_argument("--allow-missing", action="store_true")
    record = sub.add_parser("receipt")
    record.add_argument("--commit", required=True)
    record.add_argument("--platform", required=True)
    record.add_argument("--digest", required=True)
    record.add_argument("--source", type=Path, required=True)
    record.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "inputs":
            runner = inputs(args.commit, args.platform)
            with open(os.environ["GITHUB_OUTPUT"], "a") as handle:
                handle.write("runner=" + runner + "\n")
        elif args.command == "package":
            check_package(args.allow_missing)
        else:
            receipt(args.commit, args.platform, args.digest, args.source, args.output)
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()

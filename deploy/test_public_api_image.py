"""Publication inputs and provenance must fail closed before a deployment adopts an image."""
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

SCRIPT = Path(__file__).with_name("public-api-image.py")
spec = importlib.util.spec_from_file_location("public_api_image", SCRIPT)
image = importlib.util.module_from_spec(spec)
spec.loader.exec_module(image)


class PublicationTests(unittest.TestCase):
    def test_workflow_checks_and_receipt_target_the_same_private_package(self):
        workflow = SCRIPT.parents[1] / ".github/workflows/public-api-image.yml"
        self.assertIn(f"      IMAGE: {image.IMAGE}\n", workflow.read_text())
        env = {"GITHUB_REPOSITORY": image.REPOSITORY, "GH_TOKEN": "test-only"}
        for owner_type, prefix in (("User", "users"), ("Organization", "orgs")):
            with self.subTest(owner_type=owner_type), patch.dict(
                    os.environ, env | {"GITHUB_REPOSITORY_OWNER_TYPE": owner_type}):
                package = io.BytesIO(json.dumps({
                    "visibility": "private", "package_type": "container"
                }).encode())
                with patch.object(image.urllib.request, "urlopen", return_value=package) as request:
                    image.check_package(False)
                    self.assertEqual(request.call_args.args[0].full_url,
                        f"https://api.github.com/{prefix}/m0o9l0v3/packages/container/{image.PACKAGE_NAME}")

    def test_platform_is_explicit_and_inputs_cannot_inject_output_lines(self):
        self.assertEqual(image.inputs("a" * 40, "linux/amd64"), "ubuntu-24.04")
        self.assertEqual(image.inputs("a" * 40, "linux/arm64"), "ubuntu-24.04-arm")
        for commit, platform in [("develop", "linux/amd64"), ("a" * 7, "linux/amd64"),
                                 ("a" * 40 + "\nrunner=evil", "linux/amd64"),
                                 ("a" * 40, ""), ("a" * 40, "linux/amd64,linux/arm64")]:
            with self.subTest(commit=commit, platform=platform), self.assertRaises(ValueError):
                image.inputs(commit, platform)

    def test_public_or_internal_existing_package_is_rejected(self):
        image.require_private({"visibility": "private", "package_type": "container"})
        for value in ({"visibility": "public", "package_type": "container"},
                      {"visibility": "internal", "package_type": "container"},
                      {"visibility": "private", "package_type": "npm"}, {}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                image.require_private(value)

    def test_only_first_publication_tolerates_missing_package(self):
        env = {"GITHUB_REPOSITORY": image.REPOSITORY, "GITHUB_REPOSITORY_OWNER_TYPE": "User", "GH_TOKEN": "test-only"}
        with patch.dict(os.environ, env):
            for code in (401, 403, 404, 500):
                with self.subTest(code=code), patch.object(image.urllib.request, "urlopen",
                        side_effect=urllib.error.HTTPError("https://api.github.com", code, "test", {}, None)):
                    if code == 404:
                        image.check_package(True)
                    else:
                        with self.assertRaises(ValueError):
                            image.check_package(True)
                    with self.assertRaises(ValueError):
                        image.check_package(False)

    def test_receipt_matches_real_git_checkout_and_rejects_changed_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, output = Path(tmp) / "source", Path(tmp) / "receipt"
            source.mkdir()
            def git(*args):
                return subprocess.check_output(["git", "-C", str(source), *args], text=True).strip()
            git("init", "-q")
            (source / "Dockerfile").write_text("FROM scratch\n")
            git("add", "Dockerfile")
            git("-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture")
            commit = git("rev-parse", "HEAD")
            env = os.environ | {"GITHUB_SHA": "b" * 40, "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "1",
                                "PUBLICATION_JOB_URL": "https://github.com/m0o9l0v3/NexusMobile/actions/runs/123/job/456"}
            command = [sys.executable, str(SCRIPT), "receipt", "--commit", commit, "--platform", "linux/amd64",
                       "--digest", "sha256:" + "0" * 64, "--source", str(source), "--output", str(output)]
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            receipt = json.loads((output / "public-api.json").read_text())
            self.assertEqual(receipt["source_commit"], commit)
            self.assertEqual(receipt["workflow_commit"], "b" * 40)
            self.assertEqual(receipt["image"], image.IMAGE + "@sha256:" + "0" * 64)
            self.assertEqual(receipt["job_url"], env["PUBLICATION_JOB_URL"])
            self.assertEqual((output / "public-api.txt").read_text().strip(), receipt["image"])
            for old, new in [("sha256:" + "0" * 64, "latest"), (commit, "c" * 40)]:
                invalid = [new if value == old else value for value in command]
                self.assertNotEqual(subprocess.run(invalid, env=env, capture_output=True).returncode, 0)
            self.assertNotEqual(subprocess.run(command, env=env | {"PUBLICATION_JOB_URL": ""}, capture_output=True).returncode, 0)
            (source / "Dockerfile").write_text("FROM changed\n")
            self.assertNotEqual(subprocess.run(command, env=env, capture_output=True).returncode, 0)


if __name__ == "__main__":
    unittest.main()

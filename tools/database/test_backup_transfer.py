import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("backup_transfer", Path(__file__).with_name("download-backup.py"))
transfer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transfer)


class BackupTransferTests(unittest.TestCase):
    def fixture(self, path, extra=None):
        with tarfile.open(path, "w") as archive:
            for name in ["archive/nexus/archive.info", "backup/nexus/backup.info"]:
                entry = tarfile.TarInfo(name)
                entry.size = 16
                archive.addfile(entry, io.BytesIO(b"encryptedfixture"))
            if extra:
                archive.addfile(extra)

    def test_success_is_private_and_requires_restore_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.tar"
            self.fixture(source)
            target = Path(directory) / "received"
            result = transfer.receive([sys.executable, "-c", "import sys;sys.stdout.buffer.write(open(sys.argv[1],'rb').read())", str(source)], target, source="test")
            self.assertEqual(result.read_bytes(), source.read_bytes())
            self.assertEqual(target.stat().st_mode & 0o777, 0o700)
            self.assertEqual(result.stat().st_mode & 0o777, 0o600)
            self.assertFalse((target / "repository.tar.partial").exists())
            self.assertEqual(json.loads((target / "manifest.json").read_text())["status"], "downloaded_not_restore_verified")

    def test_failed_transfer_never_publishes_complete_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "failed"
            with self.assertRaises(subprocess.CalledProcessError):
                transfer.receive([sys.executable, "-c", "import sys;print('partial');sys.exit(9)"], target, source="test")
            self.assertTrue((target / "repository.tar.partial").exists())
            self.assertFalse((target / "repository.tar").exists())
            self.assertFalse((target / "manifest.json").exists())

    def test_existing_backup_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            (target / "repository.tar").write_bytes(b"keep")
            with self.assertRaises(FileExistsError):
                transfer.receive([sys.executable, "-c", "pass"], target, source="test")
            self.assertEqual((target / "repository.tar").read_bytes(), b"keep")

    def test_invalid_or_incomplete_archive_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.tar"
            path.write_text("not a backup")
            with self.assertRaises(tarfile.ReadError): transfer.validate_archive(path)
            with tarfile.open(path, "w"): pass
            with self.assertRaises(ValueError): transfer.validate_archive(path)

    def test_path_escape_and_special_files_are_rejected(self):
        entries = [tarfile.TarInfo("../escape"), tarfile.TarInfo("/escape")]
        link = tarfile.TarInfo("backup/nexus/escape")
        link.type, link.linkname = tarfile.SYMTYPE, "../../../escape"
        entries.append(link)
        device = tarfile.TarInfo("backup/device")
        device.type = tarfile.CHRTYPE
        entries.append(device)
        with tempfile.TemporaryDirectory() as directory:
            for entry in entries:
                path = Path(directory) / "bad.tar"
                self.fixture(path, entry)
                with self.assertRaises(ValueError): transfer.validate_archive(path)


if __name__ == "__main__":
    unittest.main()

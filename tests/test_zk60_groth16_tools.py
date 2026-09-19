"""Archive and provenance boundaries; these tests do not download or execute tools."""
import hashlib
import io
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_groth16_tools as tools


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def archive(self, entries):
        path = self.root / "layer.tar.gz"
        with tarfile.open(path, "w:gz") as archive:
            for name, payload, kind in entries:
                entry = tarfile.TarInfo(name)
                entry.type = kind
                entry.size = len(payload) if kind == tarfile.REGTYPE else 0
                if kind in [tarfile.SYMTYPE, tarfile.LNKTYPE]:
                    entry.linkname = "../../outside"
                archive.addfile(entry, io.BytesIO(payload) if entry.isfile() else None)
        return path

    def test_only_exact_regular_member_is_copied(self):
        blob = self.archive([("../../escaped", b"bad", tarfile.REGTYPE),
                             ("usr/local/bin/prover", b"intended", tarfile.REGTYPE)])
        result = tools.extract_member(blob, "usr/local/bin/prover", self.root / "prover")
        self.assertEqual((self.root / "prover").read_bytes(), b"intended")
        self.assertEqual(result["sha256"], hashlib.sha256(b"intended").hexdigest())
        self.assertEqual({p.name for p in self.root.iterdir()}, {"layer.tar.gz", "prover"})

    def test_links_duplicates_and_oversized_members_are_refused(self):
        for kind in [tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.DIRTYPE]:
            with self.subTest(kind=kind):
                blob = self.archive([("app/tool", b"", kind)])
                with self.assertRaises(ValueError):
                    tools.extract_member(blob, "app/tool", self.root / "tool")
        blob = self.archive([("app/tool", b"a", tarfile.REGTYPE),
                             ("./app/tool", b"b", tarfile.REGTYPE)])
        with self.assertRaises(ValueError):
            tools.extract_member(blob, "app/tool", self.root / "tool")
        self.assertFalse((self.root / "tool").exists())
        blob = self.archive([("app/tool", b"a", tarfile.REGTYPE)])
        with patch.object(tools, "MAX_MEMBER", 0), self.assertRaises(ValueError):
            tools.extract_member(blob, "app/tool", self.root / "tool")

    def test_wrong_layer_or_symlink_cache_never_passes(self):
        blob = self.archive([("app/tool", b"a", tarfile.REGTYPE)])
        digest = hashlib.sha256(blob.read_bytes()).hexdigest()
        tools.checked_layer(blob, digest, blob.stat().st_size)
        with self.assertRaises(ValueError):
            tools.checked_layer(blob, "0" * 64, blob.stat().st_size)
        with self.assertRaises(ValueError):
            tools.checked_layer(blob, digest, blob.stat().st_size + 1)
        link = self.root / "link"
        link.symlink_to(blob)
        with self.assertRaises(ValueError):
            tools.checked_layer(link, digest, blob.stat().st_size)

    def test_destination_symlink_and_existing_file_are_not_overwritten(self):
        blob = self.archive([("app/tool", b"a", tarfile.REGTYPE)])
        original = self.root / "original"
        original.write_bytes(b"keep")
        link = self.root / "tool"
        link.symlink_to(original)
        for path in [link, original]:
            with self.assertRaises(ValueError):
                tools.extract_member(blob, "app/tool", path)
        self.assertEqual(original.read_bytes(), b"keep")


if __name__ == "__main__":
    unittest.main()

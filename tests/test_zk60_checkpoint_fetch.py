"""Download integrity and resume controls; no live network or model allocation."""
import hashlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/zk60_checkpoint_fetch.py"
spec = importlib.util.spec_from_file_location("checkpoint_fetch", SCRIPT)
fetcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetcher)


class Response(io.BytesIO):
    def __init__(self, data, status=200, headers=None):
        super().__init__(data)
        self.status = status
        self.headers = headers or {}


class FetchTests(unittest.TestCase):
    def lfs_item(self, data):
        return {"size": len(data), "lfs": {"sha256": hashlib.sha256(data).hexdigest()}}

    def test_verified_download_and_cached_file(self):
        data = b"checkpoint tensor payload"
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "weights.safetensors"
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data)) as network:
                fetcher.download("https://example.test/weights", target, self.lfs_item(data))
                self.assertEqual(target.read_bytes(), data)
                fetcher.download("https://example.test/weights", target, self.lfs_item(data))
                self.assertEqual(network.call_count, 1)

    def test_resumed_payload_must_match_range_and_final_digest(self):
        data = b"abcdefghijklmno"
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "weights.safetensors"
            partial = target.with_name(target.name + ".partial")
            partial.write_bytes(data[:5])
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data[5:], 206, {"Content-Range": "bytes 5-14/15"})) as network:
                fetcher.download("https://example.test/weights", target, self.lfs_item(data))
                self.assertEqual(network.call_args.args[0].get_header("Range"), "bytes=5-")
            self.assertEqual(target.read_bytes(), data)

    def test_resume_refuses_full_body_without_correct_range(self):
        data = b"abcdefghijklmno"
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "weights.safetensors"
            partial = target.with_name(target.name + ".partial")
            partial.write_bytes(data[:5])
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data)):
                with self.assertRaisesRegex(ValueError, "resume offset"):
                    fetcher.download("https://example.test/weights", target, self.lfs_item(data))
            self.assertEqual(partial.read_bytes(), data[:5])
            self.assertFalse(target.exists())

    def test_digest_mismatch_is_never_published(self):
        data = b"abcdefghijklmno"
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "weights.safetensors"
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(b"x" * len(data))):
                with self.assertRaisesRegex(ValueError, "hash/length differs"):
                    fetcher.download("https://example.test/weights", target, self.lfs_item(data))
            self.assertFalse(target.exists())
            self.assertTrue(target.with_name(target.name + ".partial").exists())

    def test_small_file_checks_provider_git_blob(self):
        data = b'{"config": 1}'
        digest = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / "config.json"
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data)):
                fetcher.download("https://example.test/config", target, {"size": len(data), "blobId": digest})
            self.assertEqual(target.read_bytes(), data)
            with patch.object(fetcher.urllib.request, "urlopen", return_value=Response(data)):
                with self.assertRaisesRegex(ValueError, "blob pin differs"):
                    fetcher.download("https://example.test/config", target, {"size": len(data), "blobId": "0" * 40})


if __name__ == "__main__":
    unittest.main()

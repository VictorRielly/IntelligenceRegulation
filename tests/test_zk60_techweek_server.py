import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from unittest.mock import Mock

from scripts import zk60_techweek_server as server


class DemoStateTests(unittest.TestCase):
    def test_submit_failure_releases_active_job(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = server.DemoState(Path(tmp))
            try:
                with patch.object(state.pool, "submit", side_effect=RuntimeError("shutdown")):
                    with self.assertRaisesRegex(RuntimeError, "worker is unavailable"):
                        state.start("token")
                self.assertIsNone(state.active)
                self.assertEqual(next(iter(state.jobs.values()))["state"], "failed")
            finally:
                state.pool.shutdown()

    def test_busy_run_is_refused_and_invalid_mode_starts_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = server.DemoState(Path(tmp))
            try:
                with self.assertRaises(ValueError):
                    state.start("../../private")
                self.assertEqual(state.jobs, {})
                with patch.object(state.pool, "submit"):
                    first = state.start("token")
                    with self.assertRaises(RuntimeError):
                        state.start("native")
                self.assertEqual(state.active, first["id"])
            finally:
                state.pool.shutdown()

    def test_failed_worker_does_not_expose_diagnostic_or_block_retry(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = server.DemoState(Path(tmp))
            try:
                with patch.object(state.pool, "submit"):
                    job = state.start("token")
                with patch.object(server.demo, "verify_saved_demo", side_effect=ValueError("sensitive diagnostic")):
                    with patch("builtins.print"):
                        state._run(job["id"], "token")
                self.assertIsNone(state.active)
                public = state.get(job["id"])
                self.assertEqual(public["state"], "failed")
                self.assertNotIn("sensitive", json.dumps(public))
            finally:
                state.pool.shutdown()


class ArtifactTests(unittest.TestCase):
    def test_download_matches_verified_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "receipt"
            path.write_bytes(b"verified receipt")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertEqual(server.verified_artifact(path, digest, 16), b"verified receipt")
            path.write_bytes(b"corrupted bytes!")
            with self.assertRaisesRegex(ValueError, "changed"):
                server.verified_artifact(path, digest, 16)

    def test_oversize_file_is_refused_before_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "huge"
            with path.open("wb") as output:
                output.truncate(server.MAX_ARTIFACT_BYTES + 1)
            with self.assertRaisesRegex(ValueError, "size"):
                server.verified_artifact(path, "unused")

    def test_fifo_and_symlink_are_refused_without_blocking(self):
        with tempfile.TemporaryDirectory() as tmp:
            fifo = Path(tmp) / "fifo"
            os.mkfifo(fifo)
            with self.assertRaisesRegex(ValueError, "type"):
                server.verified_artifact(fifo, "unused")
            link = Path(tmp) / "link"
            link.symlink_to(fifo)
            with self.assertRaises(OSError):
                server.verified_artifact(link, "unused")


class RequestLimitTests(unittest.TestCase):
    def make_server(self):
        # Bind-free construction: exercise the real admission/release methods.
        with patch.object(server.ThreadingHTTPServer, "__init__", return_value=None):
            instance = server.BoundedHTTPServer(("127.0.0.1", 0), None, max_requests=1)
        instance.shutdown_request = Mock()
        return instance

    def test_overload_refuses_instead_of_spawning_another_thread(self):
        instance = self.make_server()
        accepted, excess = Mock(), Mock()
        with patch.object(server.ThreadingHTTPServer, "process_request") as dispatch:
            instance.process_request(accepted, ("127.0.0.1", 1))
            instance.process_request(excess, ("127.0.0.1", 2))
        dispatch.assert_called_once_with(accepted, ("127.0.0.1", 1))
        self.assertIn(b"503 Service Unavailable", excess.sendall.call_args.args[0])
        instance.shutdown_request.assert_called_once_with(excess)

    def test_handler_failure_frees_slot_for_next_request(self):
        instance = self.make_server()
        with patch.object(server.ThreadingHTTPServer, "process_request"):
            instance.process_request(Mock(), ("127.0.0.1", 1))
        with patch.object(server.ThreadingHTTPServer, "process_request_thread", side_effect=ValueError("failure")):
            with self.assertRaises(ValueError):
                instance.process_request_thread(Mock(), ("127.0.0.1", 1))
        with patch.object(server.ThreadingHTTPServer, "process_request") as dispatch:
            instance.process_request(Mock(), ("127.0.0.1", 2))
        dispatch.assert_called_once()

    def test_thread_launch_failure_frees_slot(self):
        instance = self.make_server()
        with patch.object(server.ThreadingHTTPServer, "process_request", side_effect=RuntimeError("thread failed")):
            with self.assertRaises(RuntimeError):
                instance.process_request(Mock(), ("127.0.0.1", 1))
        self.assertTrue(instance.request_slots.acquire(blocking=False))

    def test_accepted_socket_has_a_read_timeout(self):
        instance = self.make_server()
        request = Mock()
        with patch.object(server.ThreadingHTTPServer, "get_request", return_value=(request, ("127.0.0.1", 1))):
            instance.get_request()
        request.settimeout.assert_called_once_with(server.REQUEST_TIMEOUT_SECONDS)


if __name__ == "__main__":
    unittest.main()

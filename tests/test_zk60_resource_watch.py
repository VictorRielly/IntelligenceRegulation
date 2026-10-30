"""Tests for scripts/zk60_resource_watch.py: host-drive and Windows-memory problems,
the unattended --state mode and page-cache eviction (2026-10-30, after the C: crash).

Nothing here notifies, probes Windows or touches the real guard state: each run
points the guard at private files and the Windows probe at a stub.
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

WATCH = Path(__file__).resolve().parents[1] / "scripts" / "zk60_resource_watch.py"
GIB_KB = 1024 * 1024


def load_watch(env: dict):
    with mock.patch.dict(os.environ, env):
        spec = importlib.util.spec_from_file_location("zk60_watch_under_test", WATCH)
        w = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(w)
    return w


class WatchCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        (t / "meminfo").write_text(f"MemTotal: {16 * GIB_KB} kB\nMemAvailable: {12 * GIB_KB} kB\n"
                                   f"Cached: {3 * GIB_KB} kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n")
        self.env = {"ZK60_GUARD_DIR": str(t / "state"), "ZK60_GUARD_HISTORY": str(t / "h.jsonl"),
                    "ZK60_GUARD_MEMINFO": str(t / "meminfo"), "ZK60_GUARD_HOST_DRIVE": str(t),
                    "ZK60_GUARD_NVIDIA_SMI": "/nonexistent/nvidia-smi",
                    "ZK60_WATCH_POWERSHELL": "/nonexistent/powershell.exe"}
        self.w = load_watch(self.env)
        self.w.windows_memory = lambda: None  # never run PowerShell from the tests

    def tearDown(self):
        self.tmp.cleanup()

    def test_disklow_reports_under_the_warning_level_only(self):
        self.assertIn("disklow", self.w.problems(1.5, 3.0, disk_warn_gib=1e9))
        self.assertNotIn("disklow", self.w.problems(1.5, 3.0, disk_warn_gib=0))

    def test_winmem_reports_low_free_ram_or_high_commit(self):
        fine = {"ram_gib": 31.6, "free_gib": 10, "commit_limit_gib": 35.5,
                "commit_used_gib": 20, "vmmem_gib": 8}
        self.w.windows_memory = lambda: fine
        self.assertNotIn("winmem", self.w.problems(1.5, 3.0, 0))
        self.w.windows_memory = lambda: dict(fine, free_gib=2)
        self.assertIn("winmem", self.w.problems(1.5, 3.0, 0))
        self.w.windows_memory = lambda: dict(fine, commit_used_gib=32)
        self.assertIn("winmem", self.w.problems(1.5, 3.0, 0))

    def test_evict_advises_only_large_files_outside_build_output(self):
        root = Path(self.tmp.name) / "data"
        (root / "target").mkdir(parents=True)
        big, small = root / "receipt.bin", root / "note.txt"
        big.write_bytes(b"\0" * (2 * 1024 ** 2))
        small.write_bytes(b"x")
        (root / "target" / "built.bin").write_bytes(b"\0" * (2 * 1024 ** 2))
        n, _gib = self.w.evict_page_cache((root,), min_bytes=1024 ** 2)
        self.assertEqual(n, 1)
        self.assertEqual(big.read_bytes()[:1], b"\0")  # contents untouched

    def test_once_with_state_reports_a_problem_only_once(self):
        state = Path(self.tmp.name) / "watch.json"
        env = dict(os.environ, **self.env)
        run = lambda: subprocess.run(
            [sys.executable, str(WATCH), "--once", "--disk-warn-gib", "1e9", "--state", str(state)],
            env=env, capture_output=True, text=True, timeout=60)
        first, second = run(), run()
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertIn("DISKLOW", first.stdout)
        self.assertNotIn("DISKLOW", second.stdout)
        self.assertIn("disklow", json.loads(state.read_text())["seen"])


if __name__ == "__main__":
    unittest.main()

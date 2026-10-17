"""Isolated scope-identity regression: no processes are launched or signaled."""
import importlib.util
import io
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("scope_candidate", Path(__file__).with_name("guard_scope_candidate.py"))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

UNIT = "zk60-0123456789ab.scope"
OWN = "/user.slice/user-1000.slice/user@1000.service/zk60.slice/" + UNIT
PARENT = "/user.slice/user-1000.slice/session-7.scope"


class ScopeIdentity(unittest.TestCase):
    def discover(self, proc_path, unit_path, unit_rc=0):
        tracker = guard.Tracker(424242, True, UNIT)
        opened = patch("builtins.open", side_effect=FileNotFoundError()) if proc_path is None else patch(
            "builtins.open", return_value=io.StringIO("0::" + proc_path + "\n"))
        with opened, patch.object(Path, "exists", return_value=True), patch.object(
                guard.subprocess, "run", return_value=subprocess.CompletedProcess([], unit_rc, unit_path, "")) as query:
            tracker._discover_cgroup()
        return tracker, query

    def test_caller_session_scope_is_never_adopted(self):
        tracker, _ = self.discover(PARENT, PARENT)
        self.assertIsNone(tracker.cg)

    def test_exact_job_scope_from_live_pid_is_accepted(self):
        tracker, query = self.discover(OWN, "", 1)
        self.assertEqual(tracker.cg, Path("/sys/fs/cgroup") / OWN.lstrip("/"))
        query.assert_not_called()

    def test_scope_found_by_exact_unit_after_parent_exits(self):
        tracker, query = self.discover(None, OWN)
        self.assertEqual(tracker.cg, Path("/sys/fs/cgroup") / OWN.lstrip("/"))
        self.assertEqual(query.call_args.args[0][-1], UNIT)

    def test_unrelated_scope_from_unit_query_is_also_refused(self):
        tracker, _ = self.discover(None, PARENT)
        self.assertIsNone(tracker.cg)

    def test_tracking_requires_explicit_job_identity(self):
        with self.assertRaises(ValueError):
            guard.Tracker(424242, True)
        guard.Tracker(424242, False)


if __name__ == "__main__":
    unittest.main()

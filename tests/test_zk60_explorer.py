import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/zk60_explorer.py"
spec = importlib.util.spec_from_file_location("zk60_explorer", SCRIPT)
explorer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(explorer)


class ExplorerTests(unittest.TestCase):
    def test_command_preserves_sandbox_and_live_search(self):
        cmd = explorer.command("/bin/codex", Path("/tmp/work"), Path("/tmp/final"))
        self.assertIn("--search", cmd)
        self.assertEqual(cmd[cmd.index("--sandbox") + 1], "workspace-write")
        self.assertEqual(cmd[cmd.index("--ask-for-approval") + 1], "never")
        self.assertEqual(cmd[cmd.index("--model") + 1], "gpt-6.1-sol")
        self.assertFalse(any("dangerously" in part for part in cmd))
        self.assertEqual(cmd[-1], "-")

    def test_exclusive_worker_lock(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock = Path(tmp) / "lock"
            with explorer.exclusive(lock) as first:
                self.assertTrue(first)
                with explorer.exclusive(lock) as second:
                    self.assertFalse(second)
            with explorer.exclusive(lock) as third:
                self.assertTrue(third)

    def run_fake(self, code, timeout=5):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        worker = explorer.Worker(Path(tmp.name), "/bin/false", "test prompt", timeout=timeout)
        record = worker.cycle([sys.executable, "-c", "import sys; sys.stdin.read(); " + code])
        return worker, record

    def test_completed_cycle_is_durable(self):
        worker, record = self.run_fake('print(\'{"type":"thread.started","thread_id":"test"}\'); print(\'{"type":"turn.completed","usage":{"input_tokens":1}}\')')
        self.assertEqual(record["state"], "completed")
        state = explorer.read_json(worker.runtime / "status.json")
        self.assertEqual(state["last_completed_run"], record["run_id"])
        self.assertGreater(state["next_due_unix"], 0)
        self.assertEqual((worker.runtime / "runs" / record["run_id"] / "run.done").read_text(), "completed\n")

    def test_zero_exit_without_completion_is_not_success(self):
        _, record = self.run_fake('print("not a completed turn")')
        self.assertEqual(record["state"], "failed")

    def test_error_event_does_not_count_as_success(self):
        _, record = self.run_fake('print(\'{"type":"error"}\'); print(\'{"type":"turn.completed"}\')')
        self.assertEqual(record["state"], "failed")

    def test_timeout_stops_child_and_records_failure(self):
        _, record = self.run_fake("import time; time.sleep(10)", timeout=0.1)
        self.assertEqual(record["state"], "timeout")
        self.assertIsNotNone(record["returncode"])

    def test_resume_uses_disk_not_chat(self):
        worker, record = self.run_fake('print(\'{"type":"turn.completed"}\')')
        resumed = explorer.Worker(worker.work, "/bin/false", "next")
        self.assertEqual(explorer.read_json(resumed.runtime / "status.json")["last_completed_run"], record["run_id"])

    def test_existing_worker_reads_updated_prompt_on_next_cycle(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            prompt = root / "prompt.md"
            prompt.write_text("first instructions")
            worker = explorer.Worker(root / "work", "/bin/false", "stale cached prompt", prompt_path=prompt)
            argv = [sys.executable, "-c", 'import sys; sys.stdin.read(); print(\'{"type":"turn.completed"}\')']
            first = worker.cycle(argv)
            prompt.write_text("new instructions and workload")
            second = worker.cycle(argv)
            first_text = (worker.runtime / "runs" / first["run_id"] / "prompt.md").read_text()
            second_text = (worker.runtime / "runs" / second["run_id"] / "prompt.md").read_text()
            self.assertTrue(first_text.startswith("first instructions\n"))
            self.assertTrue(second_text.startswith("new instructions and workload\n"))
            self.assertNotIn("stale cached prompt", second_text)
            self.assertEqual(second["requested_model"], "gpt-6.1-sol")

    def test_restart_wait_preserves_schedule_and_drops_old_child_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            worker = explorer.Worker(Path(tmp), "/bin/false", "test prompt")
            due = explorer.time.time() + 3600
            explorer.atomic_json(worker.runtime / "status.json", {
                "state": "interrupted", "child_pid": 1234,
                "next_due_unix": due, "last_completed_run": "old-success",
            })
            def stop_after_idle(_seconds):
                state = explorer.read_json(worker.runtime / "status.json")
                self.assertEqual(state["state"], "idle")
                self.assertNotIn("child_pid", state)
                self.assertEqual(state["next_due_unix"], due)
                self.assertEqual(state["last_completed_run"], "old-success")
                self.assertEqual(state["requested_model"], "gpt-6.1-sol")
                worker.stopping = True
            with patch.object(explorer.time, "sleep", side_effect=stop_after_idle), patch.object(worker, "cycle") as cycle:
                self.assertEqual(worker.serve(), 0)
                cycle.assert_not_called()

    def test_unit_has_restart_resource_limits_and_main_read_only(self):
        unit = explorer.unit_text(Path("/tmp/project"), "/bin/codex")
        for line in ["Restart=on-failure", "ProtectSystem=strict", "ProtectHome=read-only",
                     "CPUQuota=100%", "MemoryMax=3G", "KillMode=control-group"]:
            self.assertIn(line, unit)
        self.assertNotIn("PrivateTmp", unit)
        self.assertNotIn("ReadWritePaths=/tmp/project ", unit)

    def test_invalid_service_paths_refuse(self):
        with self.assertRaises(ValueError):
            explorer.unit_text(Path("/tmp/bad\npath"), "/bin/codex")

    def test_cron_preserves_unrelated_jobs_and_is_idempotent(self):
        previous = "MAILTO=owner\n0 1 * * * /bin/true\n"
        once = explorer.cron_text(previous, Path("/tmp/project"), "/bin/codex")
        self.assertTrue(once.startswith(previous))
        self.assertEqual(once, explorer.cron_text(once, Path("/tmp/project"), "/bin/codex"))
        self.assertEqual(once.count(explorer.CRON_BEGIN), 1)
        self.assertIn("@reboot ", once)
        self.assertIn("*/5 * * * * ", once)

    def test_cron_refuses_partial_markers_and_percent_paths(self):
        for prior in [explorer.CRON_BEGIN, explorer.CRON_END]:
            with self.assertRaises(ValueError):
                explorer.cron_text(prior, Path("/tmp/project"), "/bin/codex")
        with self.assertRaises(ValueError):
            explorer.cron_text("", Path("/tmp/percent%"), "/bin/codex")

    def test_fallback_retains_read_only_production_mount(self):
        cmd = explorer.isolated_command(Path("/tmp/project"), "/bin/codex", Path("/home/test"))
        self.assertIn("--ro-bind", cmd)
        self.assertEqual(cmd[cmd.index("--ro-bind") + 1:cmd.index("--ro-bind") + 3], ["/", "/"])
        binds = [cmd[i + 1] for i, word in enumerate(cmd) if word == "--bind"]
        self.assertEqual(binds, ["/tmp/project/research/zkp-efficiency", "/home/test/.codex", "/tmp"])
        self.assertIn("--dev", cmd)  # no host GPU device nodes

    def test_pause_blocks_watchdog_without_starting_a_process(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(explorer, "WORK", Path(tmp)), patch.object(explorer, "worker_host_pid", return_value=None), patch.object(explorer.subprocess, "Popen") as start:
                explorer.pause()
                explorer.ensure("/bin/codex")
                self.assertTrue((Path(tmp) / "runtime/paused").exists())
                start.assert_not_called()

    def test_reused_launcher_pid_is_not_signalled(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            explorer.atomic_json(work / "runtime/launcher.json", {"host_pid": 12345, "host_starttime": "old"})
            with patch.object(explorer, "WORK", work), patch.object(explorer, "process_identity", return_value="new"), patch.object(explorer, "descendants") as walk:
                self.assertIsNone(explorer.worker_host_pid())
                walk.assert_not_called()


if __name__ == "__main__":
    unittest.main()

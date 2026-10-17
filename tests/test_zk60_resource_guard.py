"""Tests for scripts/zk60_resource_guard.py (admission, caps, watchdog, telemetry).

Every case runs the guard as a subprocess against a private state dir, private
lock files, a fake /proc/meminfo and a fake nvidia-smi, so nothing here touches
the shared box's real locks, history or GPU.
"""
import fcntl
import importlib.util
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

GUARD = Path(__file__).resolve().parents[1] / "scripts" / "zk60_resource_guard.py"
_spec = importlib.util.spec_from_file_location("zk60_resource_guard_under_test", GUARD)
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)
GIB_KB = 1024 * 1024

HAVE_SCOPE = (os.path.exists("/usr/bin/systemd-run") and subprocess.run(
    ["systemd-run", "--user", "--scope", "--quiet", "true"],
    capture_output=True).returncode == 0)


def meminfo_text(total_gib=16, avail_gib=12, swap_used_gib=0):
    return (f"MemTotal: {total_gib * GIB_KB} kB\nMemAvailable: {int(avail_gib * GIB_KB)} kB\n"
            f"SwapTotal: {4 * GIB_KB} kB\nSwapFree: {(4 - swap_used_gib) * GIB_KB} kB\n")


def gone(pid):
    """True once the pid no longer exists (or is only an unreaped zombie)."""
    try:
        with open(f"/proc/{pid}/stat") as f:
            s = f.read()
        return s[s.rindex(")") + 2] == "Z"
    except OSError:
        return True


def wait_for_file(path, secs=20):
    t = time.time()
    while time.time() - t < secs:
        if Path(path).exists() and Path(path).read_text().strip():
            return Path(path).read_text().strip()
        time.sleep(0.1)
    raise AssertionError(f"{path} never appeared")


class GuardCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.meminfo = t / "meminfo"
        self.meminfo.write_text(meminfo_text())
        self.smi = t / "nvidia-smi"
        self.smi_out = t / "nvidia-smi.out"
        self.smi_fail = t / "nvidia-smi.fail"
        self.smi.write_text('#!/bin/sh\n[ -f "$0.fail" ] && exit 1\ncat "$0.out"\n')
        self.smi.chmod(0o755)
        self.smi_out.write_text("0, 8188\n")
        self.history = t / "history.jsonl"
        self.heavy = t / "heavy.lock"
        self.env = dict(os.environ,
                        ZK60_GUARD_DIR=str(t / "state"), ZK60_GUARD_HISTORY=str(self.history),
                        ZK60_HEAVY_LOCK=str(self.heavy), ZK60_BUILD_LOCK=str(t / "build.lock"),
                        ZK60_GUARD_MEMINFO=str(self.meminfo), ZK60_GUARD_NVIDIA_SMI=str(self.smi),
                        ZK60_GUARD_DRAIN_SECS="3", ZK60_GUARD_TERM_GRACE_SECS="2")
        for k in ("ZK60_GUARD_JOB", "ZK60_GUARD_HELD_LOCKS", "ZK60_GUARD_RUN_ID"):
            self.env.pop(k, None)  # never inherit a guard from the environment running the tests

    def tearDown(self):
        self.tmp.cleanup()

    def guard(self, *args, timeout=90, env=None):
        return subprocess.run([sys.executable, str(GUARD), *args], env=env or self.env,
                              capture_output=True, text=True, timeout=timeout)

    def popen_guard(self, *args):
        return subprocess.Popen([sys.executable, str(GUARD), *args], env=self.env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    def records(self):
        if not self.history.exists():
            return []
        return [json.loads(x) for x in self.history.read_text().splitlines()]

    def lock_is_free(self):
        fd = os.open(self.heavy, os.O_RDWR | os.O_CREAT)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except BlockingIOError:
            return False
        finally:
            os.close(fd)


class TestRun(GuardCase):
    def test_exit_code_passes_through_and_history_is_written(self):
        r = self.guard("run", "--class", "light", "--label", "rc3", "--no-cgroup",
                       "--", sys.executable, "-c", "import sys; sys.exit(3)")
        self.assertEqual(r.returncode, 3, r.stderr)
        rec = self.records()[-1]
        self.assertEqual((rec["label"], rec["exit"], rec["enforcement"]),
                         ("rc3", 3, "watchdog-only"))
        self.assertIsNone(rec["guard_killed"])
        self.assertIn("peak_rss_gib", rec)

    def test_terminal_record_carries_identity_and_child_wall(self):
        res = Path(self.tmp.name) / "res.json"
        r = self.guard("run", "--class", "cpu", "--no-cgroup", "--result-json", str(res),
                       "--", sys.executable, "-c", "import time; time.sleep(1)")
        self.assertEqual(r.returncode, 0, r.stderr)
        rec = json.loads(res.read_text())
        self.assertEqual((rec["exit"], rec["child_rc"], rec["guard_killed"]), (0, 0, None))
        self.assertGreaterEqual(rec["child_wall_seconds"], 1.0)
        self.assertLess(rec["child_wall_seconds"], 10)
        self.assertTrue(rec["run_id"] and rec["boot_id"] and rec["guard_starttime_ticks"])
        self.assertEqual(set(rec["lock_ids"]), {"heavy", "build"})

    def test_done_marker_and_log(self):
        d, lg = Path(self.tmp.name) / "x.done", Path(self.tmp.name) / "x.log"
        r = self.guard("run", "--class", "light", "--no-cgroup", "--log", str(lg),
                       "--done", str(d), "--", sys.executable, "-c", "print('hello-guard')")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(d.read_text().strip(), "0")
        self.assertIn("hello-guard", lg.read_text())

    def test_launch_failure_leaves_a_terminal_record_and_frees_the_lock(self):
        res, done = Path(self.tmp.name) / "r.json", Path(self.tmp.name) / "r.done"
        r = self.guard("run", "--class", "cpu", "--no-cgroup", "--result-json", str(res),
                       "--done", str(done), "--", "/nonexistent/binary")
        self.assertEqual(r.returncode, 127, r.stderr)
        self.assertEqual(done.read_text().strip(), "127")
        self.assertIn("launch failed", json.loads(res.read_text())["guard_error"])
        self.assertTrue(self.lock_is_free())

    def test_rss_cap_kills_the_job(self):
        t0 = time.time()
        r = self.guard("run", "--class", "light", "--cap-gib", "0.15", "--no-cgroup",
                       "--", sys.executable, "-c",
                       "import time; x = bytearray(400*1024*1024)\n"
                       "for i in range(0, len(x), 4096): x[i] = 1\n"
                       "time.sleep(60)")
        self.assertEqual(r.returncode, 75, r.stderr)
        self.assertLess(time.time() - t0, 40)
        self.assertIn("RSS", self.records()[-1]["guard_killed"])

    def test_host_memory_floor_kills_the_job(self):
        p = self.popen_guard("run", "--class", "light", "--no-cgroup", "--",
                             sys.executable, "-c", "import time; time.sleep(60)")
        time.sleep(2)
        self.meminfo.write_text(meminfo_text(avail_gib=0.5))  # box suddenly short of RAM
        out, err = p.communicate(timeout=40)
        self.assertEqual(p.returncode, 75, err)
        self.assertIn("MemAvailable", self.records()[-1]["guard_killed"])

    def test_max_secs_kills_the_job(self):
        r = self.guard("run", "--class", "light", "--max-secs", "1", "--no-cgroup",
                       "--", sys.executable, "-c", "import time; time.sleep(60)")
        self.assertEqual(r.returncode, 75, r.stderr)

    def test_watchdog_failure_kills_the_job_and_says_so(self):
        pidfile = Path(self.tmp.name) / "job.pid"
        p = self.popen_guard(
            "run", "--class", "cpu", "--no-cgroup", "--", sys.executable, "-c",
            f"import os,time; open({str(pidfile)!r},'w').write(str(os.getpid())); time.sleep(60)")
        job = int(wait_for_file(pidfile))
        self.meminfo.unlink()  # the watchdog can no longer observe memory
        p.communicate(timeout=40)
        self.assertEqual(p.returncode, 71)
        self.assertIn("watchdog failed", self.records()[-1]["guard_error"])
        self.assertTrue(gone(job))
        self.assertTrue(self.lock_is_free())

    @unittest.skipUnless(HAVE_SCOPE, "no systemd user scope on this host")
    def test_kernel_memory_cap_stops_a_runaway(self):
        r = self.guard("run", "--class", "light", "--cap-gib", "0.2",
                       "--", sys.executable, "-c",
                       "x = bytearray(700*1024*1024)\n"
                       "for i in range(0, len(x), 4096): x[i] = 1\n")
        self.assertIn(r.returncode, (75, 137), r.stderr)  # watchdog or the kernel, both fine
        self.assertEqual(self.records()[-1]["enforcement"], "cgroup+watchdog")


class TestSignals(GuardCase):
    def test_sigterm_kills_a_child_that_ignores_sigterm_then_releases_the_lock(self):
        pidfile = Path(self.tmp.name) / "job.pid"
        res = Path(self.tmp.name) / "res.json"
        p = self.popen_guard(
            "run", "--class", "cpu", "--no-cgroup", "--result-json", str(res), "--",
            sys.executable, "-c",
            "import os,signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
            f"open({str(pidfile)!r},'w').write(str(os.getpid()))\n"
            "time.sleep(120)")
        job = int(wait_for_file(pidfile))
        t0 = time.time()
        p.send_signal(signal.SIGTERM)
        p.wait(timeout=30)
        self.assertLess(time.time() - t0, 20)
        self.assertEqual(p.returncode, 75)
        self.assertTrue(gone(job), "the job outlived its guard")
        self.assertIn("signal", json.loads(res.read_text())["guard_killed"])
        self.assertTrue(self.lock_is_free())

    def test_sigterm_while_queued_publishes_a_refusal(self):
        fd = os.open(self.heavy, os.O_RDWR | os.O_CREAT)
        fcntl.flock(fd, fcntl.LOCK_EX)  # something else holds the heavy lock
        try:
            res = Path(self.tmp.name) / "res.json"
            p = self.popen_guard("run", "--class", "cpu", "--no-cgroup", "--result-json",
                                 str(res), "--", "true")
            time.sleep(2)
            p.send_signal(signal.SIGTERM)
            p.wait(timeout=20)
            self.assertEqual(p.returncode, 70)
            self.assertIn("terminated by signal", json.loads(res.read_text())["refused"])
        finally:
            os.close(fd)

    def test_locks_stay_held_if_the_guard_itself_is_sigkilled(self):
        self._sigkill_case(["--no-cgroup"])

    @unittest.skipUnless(HAVE_SCOPE, "no systemd user scope on this host")
    def test_locks_stay_held_if_the_guard_is_sigkilled_in_cgroup_mode(self):
        self._sigkill_case([])

    def _sigkill_case(self, extra):
        pidfile = Path(self.tmp.name) / "job.pid"
        g = self.popen_guard(
            "run", "--class", "cpu", *extra, "--", sys.executable, "-c",
            f"import os,time; open({str(pidfile)!r},'w').write(str(os.getpid())); time.sleep(30)")
        job_pid = int(wait_for_file(pidfile))
        os.kill(g.pid, 9)          # the guard dies (session death, OOM kill, ...)
        g.wait(timeout=10)         # not communicate(): the surviving job still holds its pipes
        self.assertFalse(self.lock_is_free(), "job lost the lock when its guard died")
        os.kill(job_pid, 9)
        deadline = time.time() + 10
        while time.time() < deadline and not self.lock_is_free():
            time.sleep(0.2)
        self.assertTrue(self.lock_is_free(), "lock never released after the job died")


class TestAdmission(GuardCase):
    def test_refuses_when_live_memory_is_short(self):
        self.meminfo.write_text(meminfo_text(avail_gib=3))
        r = self.guard("run", "--class", "cpu", "--wait-secs", "1", "--no-cgroup",
                       "--", "true")
        self.assertEqual(r.returncode, 70, r.stderr)
        self.assertIn("MemAvailable", r.stderr)
        c = self.guard("check", "--class", "cpu")
        self.assertEqual(c.returncode, 1)

    def test_refusal_publishes_result_and_done(self):
        self.meminfo.write_text(meminfo_text(avail_gib=3))
        res, done = Path(self.tmp.name) / "r.json", Path(self.tmp.name) / "r.done"
        r = self.guard("run", "--class", "cpu", "--wait-secs", "1", "--no-cgroup",
                       "--result-json", str(res), "--done", str(done), "--", "true")
        self.assertEqual(r.returncode, 70)
        rec = json.loads(res.read_text())
        self.assertEqual(rec["exit"], 70)
        self.assertIn("MemAvailable", rec["refused"])
        self.assertEqual(done.read_text().strip(), "70")

    def test_refuses_a_job_that_can_never_fit(self):
        r = self.guard("run", "--class", "cpu", "--need-gib", "99", "--no-cgroup", "--", "true")
        self.assertEqual(r.returncode, 70)
        self.assertIn("cannot run on this box", r.stderr)

    def test_refuses_nonfinite_or_negative_numbers(self):
        for flag, value in (("--need-gib", "nan"), ("--need-gib", "-1"), ("--need-gib", "0"),
                            ("--cap-gib", "inf"), ("--max-secs", "-5"), ("--wait-secs", "nan")):
            r = self.guard("run", "--class", "light", flag, value, "--no-cgroup", "--", "true")
            self.assertEqual(r.returncode, 70, f"{flag} {value}: {r.stderr}")
            self.assertIn("finite", r.stderr)
        r = self.guard("run", "--class", "light", "--need-gib", "5", "--cap-gib", "2",
                       "--no-cgroup", "--", "true")
        self.assertEqual(r.returncode, 70)
        self.assertIn("below", r.stderr)

    def test_refuses_when_swap_is_already_in_use(self):
        self.meminfo.write_text(meminfo_text(swap_used_gib=2))
        r = self.guard("run", "--class", "light", "--wait-secs", "1", "--no-cgroup", "--", "true")
        self.assertEqual(r.returncode, 70)
        self.assertIn("swap", r.stderr)

    def test_budget_counts_live_jobs(self):
        first = self.popen_guard("run", "--class", "light", "--need-gib", "7", "--no-cgroup",
                                 "--", sys.executable, "-c", "import time; time.sleep(6)")
        time.sleep(2)
        # budget = 16 - 3.5 = 12.5 GiB; 7 + 7 does not fit while the first is live
        second = self.guard("run", "--class", "light", "--need-gib", "7", "--wait-secs", "2",
                            "--no-cgroup", "--", "true")
        self.assertEqual(second.returncode, 70, second.stderr)
        self.assertIn("budget", second.stderr)
        first.communicate(timeout=30)
        third = self.guard("run", "--class", "light", "--need-gib", "7", "--no-cgroup", "--", "true")
        self.assertEqual(third.returncode, 0, third.stderr)

    def test_heavy_lock_is_shared_with_old_style_flock_wrappers(self):
        fd = os.open(self.heavy, os.O_RDWR | os.O_CREAT)
        fcntl.flock(fd, fcntl.LOCK_EX)  # what `flock /tmp/zk-heavy.lock cmd` would hold
        try:
            r = self.guard("run", "--class", "cpu", "--wait-secs", "3", "--no-cgroup", "--", "true")
            self.assertEqual(r.returncode, 70, r.stderr)
        finally:
            os.close(fd)
        ok = self.guard("run", "--class", "cpu", "--wait-secs", "10", "--no-cgroup", "--", "true")
        self.assertEqual(ok.returncode, 0, ok.stderr)

    def test_stale_job_file_is_reaped(self):
        jobs = Path(self.env["ZK60_GUARD_DIR"]) / "jobs"
        jobs.mkdir(parents=True)
        (jobs / "dead.json").write_text(json.dumps(
            {"label": "dead", "class": "cpu", "need_gib": 11.0, "cap_gib": 11.5,
             "pid": 999999, "started": "x", "cmd": []}))
        s = json.loads(self.guard("status", "--json").stdout)
        self.assertEqual(s["live_guarded_jobs"], [])
        self.assertEqual(s["committed_gib"], 0)
        self.assertFalse((jobs / "dead.json").exists())

    def test_stale_environment_claims_do_not_bypass_admission(self):
        env = dict(self.env, ZK60_GUARD_JOB="/nonexistent/parent.json",
                   ZK60_GUARD_HELD_LOCKS="heavy,build")
        self.meminfo.write_text(meminfo_text(avail_gib=3))
        r = self.guard("run", "--class", "cpu", "--wait-secs", "1", "--no-cgroup", "--", "true",
                       env=env)
        self.assertEqual(r.returncode, 70, r.stderr)
        self.assertIn("MemAvailable", r.stderr)          # full admission still applied
        self.assertNotIn("nested", r.stderr)
        self.meminfo.write_text(meminfo_text())
        self.assertEqual(self.guard("run", "--class", "cpu", "--no-cgroup", "--", "true",
                                    env=env).returncode, 0)

    def test_stale_claim_does_not_skip_the_gpu_idle_check(self):
        env = dict(self.env, ZK60_GUARD_JOB="/nonexistent/parent.json",
                   ZK60_GUARD_HELD_LOCKS="heavy")
        self.smi_out.write_text("6000, 8188\n")
        r = self.guard("run", "--class", "gpu", "--wait-secs", "1", "--no-cgroup", "--", "true",
                       env=env)
        self.assertEqual(r.returncode, 70)
        self.assertIn("VRAM", r.stderr)


class TestExclusionAndTracking(GuardCase):
    def test_a_build_never_overlaps_a_proof(self):
        fd = os.open(self.heavy, os.O_RDWR | os.O_CREAT)
        fcntl.flock(fd, fcntl.LOCK_EX)  # a proof holds the heavy lock
        try:
            r = self.guard("run", "--class", "build", "--wait-secs", "2", "--no-cgroup",
                           "--", "true")
            self.assertEqual(r.returncode, 70, r.stderr)
        finally:
            os.close(fd)

    def test_a_proof_never_overlaps_a_build(self):
        b = self.popen_guard("run", "--class", "build", "--no-cgroup", "--",
                             sys.executable, "-c", "import time; time.sleep(5)")
        time.sleep(2)
        for cls in ("gpu", "cpu"):
            r = self.guard("run", "--class", cls, "--wait-secs", "1", "--no-cgroup", "--", "true")
            self.assertEqual(r.returncode, 70, f"{cls}: {r.stderr}")
        b.communicate(timeout=30)

    def test_light_jobs_run_beside_a_heavy_job(self):
        h = self.popen_guard("run", "--class", "cpu", "--no-cgroup", "--",
                             sys.executable, "-c", "import time; time.sleep(5)")
        time.sleep(2)
        r = self.guard("run", "--class", "light", "--wait-secs", "5", "--no-cgroup", "--", "true")
        self.assertEqual(r.returncode, 0, r.stderr)
        h.communicate(timeout=30)

    def test_setsid_child_is_counted_and_killed_without_cgroups(self):
        pidfile = Path(self.tmp.name) / "child.pid"
        code = ("import os,time; open(%r,'w').write(str(os.getpid()))\n"
                "x = bytearray(400*1024*1024)\n"
                "for i in range(0, len(x), 4096): x[i] = 1\n"
                "time.sleep(60)" % str(pidfile))
        r = self.guard("run", "--class", "light", "--cap-gib", "0.15", "--no-cgroup", "--",
                       "sh", "-c", f'setsid {sys.executable} -c "$0" & wait', code)
        self.assertEqual(r.returncode, 75, r.stderr)
        pid = int(wait_for_file(pidfile))
        time.sleep(1)
        self.assertTrue(gone(pid), "the setsid child survived the guard")

    @unittest.skipUnless(HAVE_SCOPE, "no systemd user scope on this host")
    def test_double_forked_straggler_is_killed_with_cgroups(self):
        pidfile = Path(self.tmp.name) / "straggler.pid"
        script = (f"setsid sh -c 'echo $$ > {pidfile}; exec sleep 60' >/dev/null 2>&1 & "
                  "sleep 0.5; exit 0")
        t0 = time.time()
        r = self.guard("run", "--class", "light", "--", "sh", "-c", script)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(time.time() - t0, 40)
        pid = int(wait_for_file(pidfile))
        time.sleep(1)
        self.assertTrue(gone(pid), "the detached straggler survived the guard")
        self.assertGreaterEqual(self.records()[-1]["stragglers_killed"], 1)

    def test_nested_guard_call_is_refused_not_deadlocked(self):
        inner = [sys.executable, str(GUARD), "run", "--class", "cpu", "--label", "inner",
                 "--no-cgroup", "--wait-secs", "10", "--", "true"]
        r = self.guard("run", "--class", "cpu", "--label", "outer", "--no-cgroup", "--",
                       sys.executable, "-c",
                       f"import subprocess,sys; sys.exit(subprocess.run({inner!r}).returncode)")
        self.assertEqual(r.returncode, 70, r.stderr)
        by_label = {x["label"]: x for x in self.records()}
        self.assertIn("nested guard call", by_label["inner"]["refused"])
        self.assertEqual(by_label["outer"]["child_rc"], 70)

    def test_child_sees_which_locks_it_already_holds(self):
        r = self.guard("run", "--class", "build", "--no-cgroup", "--", sys.executable, "-c",
                       "import os; print(os.environ['ZK60_GUARD_HELD_LOCKS'])")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "build,heavy")


class TestScopeIdentity(GuardCase):
    """First Codex's review, 2026-09-30 01:14 UTC: the guard adopted whatever `.scope`
    its launched process reported, so a caller's session scope could be killed."""

    UNIT = "zk60-abc123def456.scope"

    def fakes(self, proc_cgroup_line=None, unit_dir=None, members="555\n666\n"):
        t = Path(self.tmp.name)
        proc, cg = t / "fakeproc", t / "fakecg"
        (proc / "4242").mkdir(parents=True)
        if proc_cgroup_line is not None:
            (proc / "4242" / "cgroup").write_text(proc_cgroup_line)
        cg.mkdir()
        if unit_dir is not None:
            d = cg / unit_dir
            d.mkdir(parents=True)
            (d / "cgroup.procs").write_text(members)
        return proc, cg

    def tracker(self, proc, cg):
        p1 = mock.patch.object(guard, "PROC_ROOT", proc)
        p2 = mock.patch.object(guard, "CG_ROOT", cg)
        p3 = mock.patch.object(guard.subprocess, "run", side_effect=OSError("no systemctl"))
        for p in (p1, p2, p3):
            p.start()
            self.addCleanup(p.stop)
        return guard.Tracker(4242, self.UNIT)

    def test_an_inherited_session_scope_is_never_adopted(self):
        proc, cg = self.fakes("0::/user.slice/user-1000.slice/session-7.scope\n",
                              "user.slice/user-1000.slice/session-7.scope", "4242\n1\n999\n")
        t = self.tracker(proc, cg)
        t._discover_cgroup()
        self.assertIsNone(t.cg)
        self.assertNotIn(1, t.pids({}))  # the caller's other processes are never in the set

    def test_a_scope_with_a_different_unit_name_is_not_adopted(self):
        proc, cg = self.fakes("0::/user.slice/user-1000.slice/user@1000.service/zk60.slice/zk60-OTHER.scope\n",
                              "user.slice/user-1000.slice/user@1000.service/zk60.slice/zk60-OTHER.scope")
        t = self.tracker(proc, cg)
        t._discover_cgroup()
        self.assertIsNone(t.cg)

    def test_the_right_name_is_still_refused_if_it_contains_the_guard(self):
        rel = f"user.slice/user-1000.slice/user@1000.service/zk60.slice/{self.UNIT}"
        proc, cg = self.fakes(f"0::/{rel}\n", rel, f"555\n{os.getpid()}\n")
        t = self.tracker(proc, cg)
        t._discover_cgroup()
        self.assertIsNone(t.cg)
        self.assertEqual(len(t.refused_cgroups), 1)

    def test_the_right_name_is_refused_if_it_contains_the_guards_parent(self):
        rel = f"user.slice/user-1000.slice/user@1000.service/zk60.slice/{self.UNIT}"
        proc, cg = self.fakes(f"0::/{rel}\n", rel, f"555\n{os.getppid()}\n")
        t = self.tracker(proc, cg)
        t._discover_cgroup()
        self.assertIsNone(t.cg)

    def test_the_exact_unit_is_adopted_and_guard_pids_stay_out_of_the_kill_set(self):
        rel = f"user.slice/user-1000.slice/user@1000.service/zk60.slice/{self.UNIT}"
        proc, cg = self.fakes(f"0::/{rel}\n", rel, "555\n666\n")
        t = self.tracker(proc, cg)
        t._discover_cgroup()
        self.assertEqual(t.cg, cg / rel)
        self.assertEqual(t.pids({}), {555, 666})
        with mock.patch.object(guard.os, "getpid", return_value=666):
            self.assertEqual(t.pids({}), {555})  # even if it somehow listed the guard

    def test_the_unit_is_resolved_by_identity_after_the_launcher_exited(self):
        rel = f"user.slice/user-{os.getuid()}.slice/user@{os.getuid()}.service/zk60.slice/{self.UNIT}"
        proc, cg = self.fakes(None, rel, "555\n")  # no /proc/4242/cgroup any more
        t = self.tracker(proc, cg)
        t._discover_cgroup()
        self.assertEqual(t.cg, cg / rel)
        self.assertEqual(t.pids({}), {555})

    @unittest.skipUnless(HAVE_SCOPE, "no systemd user scope on this host")
    def test_a_guard_started_inside_a_scope_leaves_that_scope_alone(self):
        t = Path(self.tmp.name)
        sentinel, rcf = t / "sentinel.pid", t / "rc"
        script = (f"sleep 300 >/dev/null 2>&1 & echo $! > {sentinel}; "
                  f"{sys.executable} {GUARD} run --class light --max-secs 1 -- sleep 60; "
                  f"echo $? > {rcf}")
        subprocess.run(["systemd-run", "--user", "--scope", "--quiet", "--", "sh", "-c", script],
                       env=self.env, capture_output=True, timeout=90)
        pid = int(wait_for_file(sentinel))
        try:
            self.assertEqual(rcf.read_text().strip(), "75")
            self.assertFalse(gone(pid), "the guard killed a process in its caller's scope")
            rec = self.records()[-1]
            self.assertTrue(rec["scope_unit"].startswith("zk60-"))
            self.assertTrue((rec["scope_adopted"] or "").endswith(rec["scope_unit"]))
            self.assertEqual(rec["foreign_cgroups_refused"], [])
        finally:
            try:
                os.kill(pid, 9)
            except OSError:
                pass

    def test_a_finished_command_is_noticed_immediately(self):
        walls = []
        for _ in range(3):
            self.guard("run", "--class", "light", "--no-cgroup", "--", "true")
            walls.append(self.records()[-1]["child_wall_seconds"])
        self.assertLess(min(walls), 0.3, walls)  # was ~0.5 s with sleep(0.5); poll()


class TestGpu(GuardCase):
    def test_gpu_job_refused_when_card_is_busy(self):
        self.smi_out.write_text("6000, 8188\n")
        r = self.guard("run", "--class", "gpu", "--wait-secs", "1", "--no-cgroup", "--", "true")
        self.assertEqual(r.returncode, 70, r.stderr)
        self.assertIn("VRAM", r.stderr)

    def test_gpu_job_refused_when_card_unreadable(self):
        self.env["ZK60_GUARD_NVIDIA_SMI"] = "/nonexistent/nvidia-smi"
        r = self.guard("run", "--class", "gpu", "--wait-secs", "1", "--no-cgroup", "--", "true")
        self.assertEqual(r.returncode, 70)
        self.assertIn("unreadable", r.stderr)

    def test_gpu_job_runs_on_an_idle_card_and_records_vram(self):
        r = self.guard("run", "--class", "gpu", "--label", "g", "--no-cgroup",
                       "--", sys.executable, "-c", "import time; time.sleep(3)")
        self.assertEqual(r.returncode, 0, r.stderr)
        rec = self.records()[-1]
        self.assertIsNotNone(rec["vram_drain_s"])
        self.assertEqual(rec["peak_vram_mib"], 0)  # sampled, card stayed idle
        self.assertFalse(rec["gpu_drain_failed"])

    def test_stuck_vram_after_exit_is_a_recorded_failure(self):
        # the job exits fine but the card never drains (WSL late release): exit 76, not 0
        p = self.popen_guard("run", "--class", "gpu", "--no-cgroup", "--",
                             sys.executable, "-c", "import time; time.sleep(2)")
        time.sleep(1)
        self.smi_out.write_text("3000, 8188\n")  # below the kill cap, above idle
        out, err = p.communicate(timeout=60)
        self.assertEqual(p.returncode, 76, err)
        rec = self.records()[-1]
        self.assertEqual((rec["child_rc"], rec["gpu_drain_failed"]), (0, True))
        self.assertIn("do not start another GPU job", err)
        # ...and the next GPU job is refused while the card stays busy
        nxt = self.guard("run", "--class", "gpu", "--wait-secs", "1", "--no-cgroup", "--", "true")
        self.assertEqual(nxt.returncode, 70)

    def test_vram_over_cap_kills_the_job(self):
        p = self.popen_guard("run", "--class", "gpu", "--no-cgroup", "--",
                             sys.executable, "-c", "import time; time.sleep(60)")
        time.sleep(2.5)
        self.smi_out.write_text("7900, 8188\n")
        p.communicate(timeout=60)
        self.assertEqual(p.returncode, 75)
        self.assertIn("VRAM", self.records()[-1]["guard_killed"])

    def test_losing_gpu_telemetry_mid_run_kills_the_job(self):
        pidfile = Path(self.tmp.name) / "job.pid"
        p = self.popen_guard(
            "run", "--class", "gpu", "--no-cgroup", "--", sys.executable, "-c",
            f"import os,time; open({str(pidfile)!r},'w').write(str(os.getpid())); time.sleep(120)")
        job = int(wait_for_file(pidfile))
        self.smi_fail.write_text("x")  # nvidia-smi starts failing
        p.communicate(timeout=90)
        self.assertEqual(p.returncode, 75)
        rec = self.records()[-1]
        self.assertTrue(rec["gpu_telemetry_lost"])
        self.assertIn("telemetry", rec["guard_killed"])
        self.assertTrue(gone(job))


class TestStatus(GuardCase):
    def test_status_reports_memory_and_locks(self):
        s = json.loads(self.guard("status", "--json").stdout)
        self.assertEqual(s["mem_total_gib"], 16.0)
        self.assertEqual(s["job_budget_gib"], 12.5)
        self.assertTrue(s["heavy_lock_free"])
        self.assertEqual(s["gpu_total_mib"], 8188)


if __name__ == "__main__":
    unittest.main()

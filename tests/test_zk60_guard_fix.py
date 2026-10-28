"""Tests for the 2026-10-21 guard fix: admission before the heavy lock, optional FIFO.

Staged in results/zk60_guard_fix_20261021/tests/; copy into tests/ when the
candidate guard replaces scripts/zk60_resource_guard.py.

Which guard is tested:
  * NEW = $GUARD_FIX_NEW, else <repo>/scripts/zk60_resource_guard.py, where <repo> is
    the nearest parent directory that contains scripts/zk60_resource_guard.py.  From
    tests/ that is the live guard; the lane's results/.../test_guard_fix.py sets
    GUARD_FIX_NEW to the candidate before the swap.
  * OLD = $GUARD_FIX_OLD, else <repo>/results/zk60_guard_fix_20261021/
    zk60_resource_guard.py.orig.  It must be the pre-fix guard (sha256 f0b87668...);
    the cases that need it (gap evidence, old/new mix, record shapes) are skipped
    with a reason if it is missing or different.

What is checked:
  * a heavy job waiting for memory does not hold the heavy lock (the old guard does);
  * smaller heavy jobs run while it waits;
  * the re-check under the locks releases them when it fails (in-process);
  * FIFO is off unless <state>/fifo.on or ZK60_GUARD_FIFO=1; =0 keeps a process out;
    removing the file turns it off at the next poll;
  * with FIFO on: an older budget-blocked job starts before newer ones; dead / unlocked
    / stale / non-reserving tickets never block; the reservation time cap;
  * no admission past the budget and never two heavy jobs at once (new only, and a mix
    of old and new guard processes on the same lock and state files), FIFO off and on;
  * an old guard still holding the lock while it waits does not deadlock new guards;
  * history / result-json records, job files and `status --json` keep their shape.

Isolation: every guard runs on a private state dir, private heavy/build locks, a
private history file, a fake /proc/meminfo and a fake nvidia-smi (env overrides the
guard honours).  setUp refuses to run if any of those resolves to a live path.  Every
guard gets --wait-secs and --max-secs, so it ends on its own; no test sends a signal.
Jobs are `python3 -c` sleeps of < 7 s that allocate nothing.
"""
import fcntl
import hashlib
import importlib.machinery
import importlib.util
import json
import os
import signal
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True


def _repo() -> Path:
    for p in Path(__file__).resolve().parents:
        if (p / "scripts" / "zk60_resource_guard.py").exists():
            return p
    return Path(__file__).resolve().parents[1]


REPO = _repo()
BASE_SHA256 = "f0b87668b9ad3bc42683d95a16314b54973b8e36be576b25183302287168e772"
NEW = Path(os.environ.get("GUARD_FIX_NEW", REPO / "scripts" / "zk60_resource_guard.py"))
OLD = Path(os.environ.get(
    "GUARD_FIX_OLD", REPO / "results/zk60_guard_fix_20261021/zk60_resource_guard.py.orig"))


def _sha256(p: Path) -> str | None:
    try:
        return hashlib.sha256(p.read_bytes()).hexdigest()
    except OSError:
        return None


HAVE_OLD = _sha256(OLD) == BASE_SHA256
NO_OLD = f"pre-fix guard copy {OLD} missing or not sha256 {BASE_SHA256[:8]}..."
GIB_KB = 1024 * 1024
BUDGET = 12.5  # fake MemTotal 16 GiB - reserve 3.5
LIVE_PATHS = ("/tmp/zk-heavy.lock", "/tmp/zk-build.lock", "/tmp/zk-guard")

JOB = ("import os, sys, time\n"
       "f, label, secs = sys.argv[1], sys.argv[2], float(sys.argv[3])\n"
       "def w(kind):\n"
       "    fd = os.open(f, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)\n"
       "    os.write(fd, f'{kind} {label} {time.time():.4f}\\n'.encode())\n"
       "    os.close(fd)\n"
       "w('start'); time.sleep(secs); w('end')\n")


def meminfo_text(total_gib=16, avail_gib=12.0, swap_used_gib=0):
    return (f"MemTotal: {total_gib * GIB_KB} kB\nMemAvailable: {int(avail_gib * GIB_KB)} kB\n"
            f"SwapTotal: {4 * GIB_KB} kB\nSwapFree: {(4 - swap_used_gib) * GIB_KB} kB\n")


def load_new_module():
    loader = importlib.machinery.SourceFileLoader("zk60_guard_new_inproc", str(NEW))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="guardfix-")
        t = Path(self.tmp.name)
        self.t = t
        self.meminfo = t / "meminfo"
        self.meminfo.write_text(meminfo_text())
        self.smi = t / "nvidia-smi"
        self.smi_out = t / "nvidia-smi.out"
        self.smi.write_text('#!/bin/sh\n[ -f "$0.fail" ] && exit 1\ncat "$0.out"\n')
        self.smi.chmod(0o755)
        self.smi_out.write_text("0, 8188\n")
        self.state = t / "state"
        self.heavy = t / "heavy.lock"
        self.build = t / "build.lock"
        self.history = t / "history.jsonl"
        self.events = t / "events.log"
        self.env = dict(os.environ,
                        ZK60_GUARD_DIR=str(self.state), ZK60_GUARD_HISTORY=str(self.history),
                        ZK60_HEAVY_LOCK=str(self.heavy), ZK60_BUILD_LOCK=str(self.build),
                        ZK60_GUARD_MEMINFO=str(self.meminfo), ZK60_GUARD_NVIDIA_SMI=str(self.smi),
                        ZK60_GUARD_DRAIN_SECS="3", ZK60_GUARD_TERM_GRACE_SECS="2",
                        ZK60_GUARD_POLL_SECS="0.5")
        for k in ("ZK60_GUARD_JOB", "ZK60_GUARD_HELD_LOCKS", "ZK60_GUARD_RUN_ID",
                  "ZK60_GUARD_FIFO", "ZK60_GUARD_FIFO_MAX_PRIORITY_SECS",
                  "ZK60_GUARD_TICKET_STALE_SECS"):
            self.env.pop(k, None)
        for k in ("ZK60_GUARD_DIR", "ZK60_HEAVY_LOCK", "ZK60_BUILD_LOCK", "ZK60_GUARD_HISTORY"):
            v = os.path.realpath(self.env[k])
            assert not any(v.startswith(p) for p in LIVE_PATHS), f"{k}={v} is a live path"
            assert "results/zk60_resource_guard" not in v, f"{k}={v} is the live history"
        self.procs = []

    def tearDown(self):
        for p in self.procs:  # never signalled: every guard has --wait-secs/--max-secs
            if p.poll() is None:
                p.communicate(timeout=180)
        self.tmp.cleanup()

    def fifo_on(self):
        self.state.mkdir(parents=True, exist_ok=True)
        (self.state / "fifo.on").write_text("")

    # -- launching ---------------------------------------------------------------
    def job(self, label, secs):
        return [sys.executable, "-c", JOB, str(self.events), label, str(secs)]

    def guard_argv(self, version, cls, label, need, secs, extra=()):
        return [sys.executable, str(version), "run", "--class", cls, "--label", label,
                "--need-gib", str(need), "--no-cgroup", "--wait-secs", "150",
                "--max-secs", "30", *extra, "--", *self.job(label, secs)]

    def start(self, version, cls, label, need, secs, env=None, extra=()):
        p = subprocess.Popen(self.guard_argv(version, cls, label, need, secs, extra),
                             env=env or self.env, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, text=True)
        p.label = label
        self.procs.append(p)
        return p

    def cli(self, version, *args, env=None, timeout=120):
        return subprocess.run([sys.executable, str(version), *args], env=env or self.env,
                              capture_output=True, text=True, timeout=timeout)

    def finish(self, *procs, timeout=180):
        for p in procs:
            out, err = p.communicate(timeout=timeout)
            self.assertEqual(p.returncode, 0, f"{p.label}: rc={p.returncode}\n{err}")

    # -- observing ---------------------------------------------------------------
    def intervals(self):
        d = {}
        if self.events.exists():
            for line in self.events.read_text().splitlines():
                kind, label, t = line.split()
                d.setdefault(label, {})[kind] = float(t)
        return d

    def wait_event(self, kind, label, secs=60):
        t0 = time.time()
        while time.time() - t0 < secs:
            iv = self.intervals()
            if kind in iv.get(label, {}):
                return iv[label][kind]
            time.sleep(0.05)
        raise AssertionError(f"no {kind} event for {label} within {secs}s")

    def started(self, label):
        return "start" in self.intervals().get(label, {})

    def tickets(self):
        q = self.state / "queue"
        out = []
        if q.exists():
            for p in sorted(q.glob("*.ticket")):
                try:
                    out.append(json.loads(p.read_text()))
                except ValueError:
                    pass
        return out

    def wait_ticket(self, label, secs=20, **want):
        t0 = time.time()
        while time.time() - t0 < secs:
            for tk in self.tickets():
                if tk["label"] == label and all(tk.get(k) == v for k, v in want.items()):
                    return tk
            time.sleep(0.05)
        raise AssertionError(f"no ticket for {label} with {want} within {secs}s; "
                             f"have {self.tickets()}")

    def lock_free(self, path=None):
        fd = os.open(path or self.heavy, os.O_RDWR | os.O_CREAT, 0o666)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(fd, fcntl.LOCK_UN)
            return True
        except BlockingIOError:
            return False
        finally:
            os.close(fd)

    def records(self, history=None):
        h = history or self.history
        return [json.loads(x) for x in h.read_text().splitlines()] if h.exists() else []

    def assert_invariants(self, meta):
        """meta: label -> (class, need).  Child run windows are inside the guard's
        registration windows, so a violation here is a real double admission."""
        iv = self.intervals()
        self.assertEqual(set(iv), set(meta), "every job ran exactly once")
        worst = (0.0, 0)
        for t in sorted(v["start"] for v in iv.values()):
            running = [l for l, v in iv.items() if v["start"] <= t < v["end"]]
            need = sum(meta[l][1] for l in running)
            heavy = [l for l in running if meta[l][0] != "light"]
            self.assertLessEqual(need, BUDGET + 1e-9, f"budget exceeded at {t}: {running}")
            self.assertLessEqual(len(heavy), 1, f"two heavy jobs at once: {heavy}")
            worst = (max(worst[0], need), max(worst[1], len(running)))
        return worst

    def stress_new_only(self):
        meta, procs = {}, []
        for i in range(8):
            meta[f"l{i}"] = ("light", 4)
        for i in range(3):
            meta[f"b{i}"] = ("build", 3)
        meta["c0"] = ("cpu", 6)
        for label, (cls, need) in meta.items():
            procs.append(self.start(NEW, cls, label, need, 0.8))
        self.finish(*procs)
        worst = self.assert_invariants(meta)
        self.assertGreaterEqual(worst[1], 2, "no concurrency at all: the test proved nothing")
        self.assertEqual(self.tickets(), [])

    def hold_ticket(self, need, label="held", heartbeat_age=0.0, priority=True, lock=True,
                    age_ns=10 ** 9):
        """Write a ticket the way a waiting guard would (optionally holding its flock)."""
        q = self.state / "queue"
        q.mkdir(parents=True, exist_ok=True)
        enq = time.time_ns() - age_ns
        name = q / f"{enq:020d}-{label:0>12.12}.ticket"
        rec = {"run_id": label, "label": label, "class": "light", "need_gib": need,
               "pid": 999999, "boot_id": None, "pid_ns": None, "guard_starttime_ticks": None,
               "enqueued": "x", "enqueued_ns": enq, "state": "waiting", "priority": priority,
               "priority_until": None, "priority_secs": 0.0, "priority_expired": False,
               "heartbeat": time.time() - heartbeat_age, "reasons": ["budget: test"]}
        fd = os.open(name, os.O_RDWR | os.O_CREAT, 0o666)
        if lock:
            fcntl.flock(fd, fcntl.LOCK_EX)
        os.write(fd, json.dumps(rec).encode())
        if not lock:
            os.close(fd)
            fd = None
        return name, fd


# ------------------------------------------------------------------ gap (a) --------
class TestNoLockWhileWaiting(Base):
    """Default configuration (FIFO off): what the swap changes."""

    def test_new_waiting_big_job_does_not_hold_the_heavy_lock(self):
        L = self.start(NEW, "light", "L", 9, 4)
        self.wait_event("start", "L")
        H = self.start(NEW, "cpu", "H", 8, 0.3)
        time.sleep(1.0)  # several 0.5 s polls: H is waiting for the budget
        probes = []
        for _ in range(10):
            probes.append(self.lock_free())
            time.sleep(0.2)
        self.assertTrue(all(probes), f"heavy lock held while waiting: {probes}")
        self.assertFalse(self.started("H"))
        self.finish(L, H)
        iv = self.intervals()
        self.assertGreaterEqual(iv["H"]["start"], iv["L"]["end"])
        self.assertFalse((self.state / "queue").exists(), "FIFO off must write no tickets")

    @unittest.skipUnless(HAVE_OLD, NO_OLD)
    def test_base_version_holds_the_heavy_lock_while_waiting(self):
        """Evidence that gap (a) is real in the pre-fix guard (same scenario)."""
        L = self.start(NEW, "light", "L", 9, 4)
        self.wait_event("start", "L")
        H = self.start(OLD, "cpu", "H", 8, 0.3)
        time.sleep(2.0)
        self.assertFalse(self.started("H"))
        self.assertFalse(self.lock_free(), "base version was expected to hold the lock")
        self.finish(L, H)

    def test_small_heavy_job_runs_while_a_big_one_waits(self):
        L = self.start(NEW, "light", "L", 9, 6)
        self.wait_event("start", "L")
        H = self.start(NEW, "cpu", "H", 8, 0.3)
        time.sleep(1.5)
        self.assertTrue(self.lock_free())
        S = self.start(NEW, "build", "S", 3, 0.5)
        self.finish(S)
        iv = self.intervals()
        self.assertNotIn("start", iv.get("H", {}))
        self.assertNotIn("end", iv["L"], "small heavy job waited for the big one's blocker")
        self.finish(L, H)
        iv = self.intervals()
        self.assertGreaterEqual(iv["H"]["start"], iv["S"]["end"])
        self.assertEqual(self.tickets(), [])

    def test_no_admission_past_the_budget_and_one_heavy_job_at_a_time(self):
        self.stress_new_only()

    def test_fifo_on_small_heavy_job_runs_while_a_big_one_waits_for_live_memory(self):
        """FIFO on: a waiter blocked only by live MemAvailable (unguarded processes)
        holds no reservation, so a smaller heavy job that fits goes ahead."""
        self.fifo_on()
        self.meminfo.write_text(meminfo_text(avail_gib=8.5))  # H needs 8 + 1 margin
        H = self.start(NEW, "cpu", "H", 8, 0.3)
        tk = self.wait_ticket("H", state="waiting")
        self.assertFalse(tk["priority"])
        self.assertTrue(self.lock_free())
        S = self.start(NEW, "build", "S", 3, 0.5)
        self.finish(S)
        self.assertFalse(self.started("H"))
        self.meminfo.write_text(meminfo_text())
        self.finish(H)
        iv = self.intervals()
        self.assertGreaterEqual(iv["H"]["start"], iv["S"]["end"])

    def test_fifo_on_small_heavy_job_runs_while_a_gpu_job_waits_for_the_card(self):
        self.fifo_on()
        self.smi_out.write_text("3000, 8188\n")  # card busy (outside the guard)
        G = self.start(NEW, "gpu", "G", 5, 0.3)
        tk = self.wait_ticket("G", state="waiting")
        self.assertFalse(tk["priority"])
        self.assertTrue(self.lock_free())
        S = self.start(NEW, "build", "S", 3, 0.5)
        self.finish(S)
        self.assertFalse(self.started("G"))
        self.smi_out.write_text("0, 8188\n")
        self.finish(G)


# ---------------------------------------------------- re-check, in process --------
class TestRecheckInProcess(Base):
    """Deterministic: the admission function is scripted, the guard runs in this
    process against the private paths, the command is `true`."""

    def setUp(self):
        super().setUp()
        self.g = load_new_module()
        g = self.g
        for name, val in (("STATE_DIR", self.state), ("HEAVY_LOCK", self.heavy),
                          ("BUILD_LOCK", self.build), ("HISTORY", self.history),
                          ("MEMINFO", str(self.meminfo)), ("NVIDIA_SMI", str(self.smi)),
                          ("LOCKS", {"heavy": self.heavy, "build": self.build}),
                          ("ADMIT_POLL_SECS", 0.05), ("FIFO_ENV", "1")):
            p = mock.patch.object(g, name, val)
            p.start()
            self.addCleanup(p.stop)
        p = mock.patch.dict(os.environ)
        p.start()
        self.addCleanup(p.stop)
        for k in ("ZK60_GUARD_JOB", "ZK60_GUARD_HELD_LOCKS"):
            os.environ.pop(k, None)

    def test_recheck_runs_under_the_locks_and_releases_them_when_it_fails(self):
        calls = []

        def scripted(cls, need, jobs_dir, ahead=()):
            n = len(calls) + 1
            calls.append((n, self.lock_free(self.heavy), self.lock_free(self.build)))
            return [("budget", "budget: scripted")] if n == 2 else []

        with mock.patch.object(self.g, "_admission_reasons", scripted):
            rc = self.g.main(["run", "--class", "build", "--label", "B", "--no-cgroup",
                              "--wait-secs", "30", "--", "true"])
        self.assertEqual(rc, 0)
        # 1 pre-check: nothing held; 2 re-check: both held, fails; 3 pre-check again:
        # both released; 4 re-check: held, admitted.
        self.assertEqual([c[1:] for c in calls],
                         [(True, True), (False, False), (True, True), (False, False)])
        self.assertTrue(self.lock_free(self.heavy) and self.lock_free(self.build))
        self.assertEqual(list((self.state / "queue").glob("*.ticket")), [])

    def test_a_heavy_job_decides_twice_and_runs_registered(self):
        seen = []

        def scripted(cls, need, jobs_dir, ahead=()):
            seen.append(sorted(p.name for p in (self.state / "jobs").glob("*.json")))
            return []

        res = self.t / "r.json"
        with mock.patch.object(self.g, "_admission_reasons", scripted):
            rc = self.g.main(["run", "--class", "cpu", "--no-cgroup", "--result-json", str(res),
                              "--", sys.executable, "-c",
                              "import os, json; print(json.load(open(os.environ['ZK60_GUARD_JOB']))['class'])"])
        self.assertEqual(rc, 0)
        self.assertEqual(len(seen), 2)  # pre-check + re-check
        rec = json.loads(res.read_text())
        self.assertEqual((rec["exit"], rec["child_rc"]), (0, 0))

    def test_termination_while_waiting_for_memory_is_a_refusal_and_drops_the_ticket(self):
        calls, tickets_seen = [], []
        res = self.t / "r.json"

        def scripted(cls, need, jobs_dir, ahead=()):
            calls.append(1)
            if len(calls) == 3:
                tickets_seen.extend(self.tickets())
                # what the SIGTERM handler would do; a direct call, no signal is sent
                signal.getsignal(signal.SIGTERM)(signal.SIGTERM, None)
            return [("budget", "budget: scripted")]

        with mock.patch.object(self.g, "_admission_reasons", scripted):
            rc = self.g.main(["run", "--class", "cpu", "--label", "W", "--no-cgroup",
                              "--wait-secs", "30", "--result-json", str(res), "--", "true"])
        self.assertEqual(rc, 70)
        self.assertIn("terminated by signal 15 while waiting to start",
                      json.loads(res.read_text())["refused"])
        self.assertEqual(len(tickets_seen), 1)
        self.assertTrue(tickets_seen[0]["priority"])      # budget-blocked: reserves
        self.assertEqual(tickets_seen[0]["state"], "waiting")
        self.assertEqual(self.tickets(), [])
        self.assertTrue(self.lock_free())

    def test_fifo_off_writes_no_ticket_and_env_0_beats_the_file(self):
        for fifo_env, file_on in (("", False), ("0", True)):
            if file_on:
                self.fifo_on()
            seen = []

            def scripted(cls, need, jobs_dir, ahead=()):
                seen.append((len(self.tickets()), list(ahead)))
                return [("budget", "budget: scripted")]

            name, fd = self.hold_ticket(need=12)  # an older reserving waiter
            try:
                with mock.patch.object(self.g, "FIFO_ENV", fifo_env), \
                        mock.patch.object(self.g, "_admission_reasons", scripted):
                    rc = self.g.main(["run", "--class", "light", "--no-cgroup",
                                      "--wait-secs", "0.5", "--", "true"])
            finally:
                os.close(fd)
                name.unlink()
            self.assertEqual(rc, 70)
            self.assertTrue(seen)
            self.assertTrue(all(n == 1 and ahead == [] for n, ahead in seen),
                            f"env={fifo_env!r} file={file_on}: {seen}")

    def test_termination_while_blocked_on_the_heavy_lock_is_a_refusal(self):
        fd = os.open(self.heavy, os.O_RDWR | os.O_CREAT, 0o666)
        fcntl.flock(fd, fcntl.LOCK_EX)  # a legacy `flock /tmp/zk-heavy.lock cmd` holder
        res = self.t / "r.json"
        timer = threading.Timer(
            1.5, lambda: signal.getsignal(signal.SIGTERM)(signal.SIGTERM, None))
        try:
            with mock.patch.object(self.g, "_admission_reasons", lambda *a, **k: []):
                timer.start()
                rc = self.g.main(["run", "--class", "cpu", "--no-cgroup", "--wait-secs", "30",
                                  "--result-json", str(res), "--", "true"])
        finally:
            timer.cancel()
            os.close(fd)
        self.assertEqual(rc, 70)
        self.assertIn("terminated by signal", json.loads(res.read_text())["refused"])
        self.assertEqual(self.tickets(), [])

    def test_wait_secs_still_bounds_the_memory_wait_and_the_lock_wait(self):
        res = self.t / "r.json"
        with mock.patch.object(self.g, "_admission_reasons",
                               lambda *a, **k: [("budget", "budget: scripted")]):
            t0 = time.time()
            rc = self.g.main(["run", "--class", "cpu", "--no-cgroup", "--wait-secs", "1",
                              "--result-json", str(res), "--", "true"])
        self.assertEqual(rc, 70)
        self.assertLess(time.time() - t0, 5)
        self.assertTrue(json.loads(res.read_text())["refused"].startswith("after waiting: budget"))
        fd = os.open(self.heavy, os.O_RDWR | os.O_CREAT, 0o666)
        fcntl.flock(fd, fcntl.LOCK_EX)
        try:
            with mock.patch.object(self.g, "_admission_reasons", lambda *a, **k: []):
                rc = self.g.main(["run", "--class", "cpu", "--no-cgroup", "--wait-secs", "1",
                                  "--result-json", str(res), "--", "true"])
        finally:
            os.close(fd)
        self.assertEqual(rc, 70)
        self.assertTrue(json.loads(res.read_text())["refused"].startswith("could not take"))
        self.assertEqual(self.tickets(), [])

    def test_reason_kinds_that_reserve(self):
        r = self.g._reserves
        self.assertTrue(r({"budget"}))
        self.assertTrue(r({"budget", "mem"}))
        self.assertTrue(r({"fifo-budget", "fifo-heavy"}))
        self.assertFalse(r({"mem"}))                 # live memory alone never reserves
        self.assertFalse(r({"fifo-heavy"}))
        self.assertFalse(r({"budget", "heavy"}))     # a heavy job is live: lights backfill
        self.assertFalse(r({"budget", "gpu"}))
        self.assertFalse(r(set()))


# ------------------------------------------------------- FIFO switches --------
class TestFifoSwitches(Base):
    """budget 12.5: L(7) running; H(8) does not fit; N(5) fits beside L (7+5=12) but
    not beside H's reservation (8+5=13)."""

    def scenario(self, env_h=None, env_n=None):
        L = self.start(NEW, "light", "L", 7, 4)
        self.wait_event("start", "L")
        H = self.start(NEW, "cpu", "H", 8, 0.5, env=env_h)
        time.sleep(1.0)
        N = self.start(NEW, "light", "N", 5, 0.3, env=env_n)
        self.finish(L, H, N)
        return self.intervals()

    def test_fifo_is_off_by_default(self):
        iv = self.scenario()
        self.assertLess(iv["N"]["start"], iv["H"]["start"])  # N jumps H, as before
        self.assertFalse((self.state / "queue").exists())

    def test_env_1_turns_fifo_on_for_that_process(self):
        on = dict(self.env, ZK60_GUARD_FIFO="1")
        iv = self.scenario(env_h=on, env_n=on)
        self.assertGreaterEqual(iv["H"]["start"], iv["L"]["end"])
        self.assertGreaterEqual(iv["N"]["start"], iv["H"]["end"])

    def test_env_0_keeps_a_process_out_even_with_the_file(self):
        self.fifo_on()
        iv = self.scenario(env_n=dict(self.env, ZK60_GUARD_FIFO="0"))
        self.assertLess(iv["N"]["start"], iv["H"]["start"])  # N ignores H's reservation


# --------------------------------------------------------------- FIFO (b) ---------
class TestFifo(Base):
    """FIFO switched on with <state>/fifo.on."""

    def setUp(self):
        super().setUp()
        self.fifo_on()

    def test_an_older_budget_blocked_job_starts_before_a_newer_smaller_one(self):
        # budget 12.5: L(7) running; H(8) does not fit; N(5) would fit beside L (7+5=12)
        # and, without FIFO, would jump H.  With FIFO N fits only beside H's reservation,
        # which it does not (8+5=13), so the order is strictly L, H, N.
        L = self.start(NEW, "light", "L", 7, 4)
        self.wait_event("start", "L")
        H = self.start(NEW, "cpu", "H", 8, 1.0)
        self.wait_ticket("H", state="waiting", priority=True)
        N = self.start(NEW, "light", "N", 5, 0.3)
        self.wait_ticket("N", state="waiting")
        c = self.cli(NEW, "check", "--class", "light", "--need-gib", "5")
        self.assertEqual(c.returncode, 1)
        self.assertIn("fifo", c.stdout)
        self.assertTrue(self.lock_free())
        self.finish(L, H, N)
        iv = self.intervals()
        self.assertGreaterEqual(iv["H"]["start"], iv["L"]["end"])
        self.assertGreaterEqual(iv["N"]["start"], iv["H"]["end"])
        self.assertEqual(self.tickets(), [])

    def test_a_newer_tiny_job_waits_while_an_older_one_is_budget_blocked(self):
        L = self.start(NEW, "light", "L", 9, 4)
        self.wait_event("start", "L")
        H = self.start(NEW, "cpu", "H", 8, 1.0)
        self.wait_ticket("H", state="waiting", priority=True)
        N = self.start(NEW, "light", "N", 0.5, 0.3)  # 9+0.5 fits: would have jumped
        self.wait_ticket("N", state="waiting")
        self.finish(L, H, N)
        iv = self.intervals()
        self.assertGreaterEqual(iv["N"]["start"], iv["L"]["end"])

    def test_removing_the_switch_turns_fifo_off_at_the_next_poll(self):
        L = self.start(NEW, "light", "L", 7, 5)
        self.wait_event("start", "L")
        H = self.start(NEW, "cpu", "H", 8, 0.3)
        self.wait_ticket("H", state="waiting", priority=True)
        N = self.start(NEW, "light", "N", 5, 0.3)
        self.wait_ticket("N", state="waiting")
        t_off = time.time()
        (self.state / "fifo.on").unlink()
        self.finish(N)
        iv = self.intervals()
        self.assertLess(iv["N"]["start"] - t_off, 2.0)
        self.assertNotIn("start", iv.get("H", {}))
        t0 = time.time()
        while self.tickets() and time.time() - t0 < 3:
            time.sleep(0.1)
        self.assertEqual(self.tickets(), [], "waiters keep tickets after FIFO was turned off")
        self.finish(L, H)

    def test_a_ticket_whose_holder_dies_stops_blocking_at_once(self):
        name, fd = self.hold_ticket(need=12)
        N = self.start(NEW, "light", "N", 1, 0.3)
        time.sleep(1.5)
        self.assertFalse(self.started("N"))
        self.assertIn("fifo", self.cli(NEW, "check", "--class", "light", "--need-gib", "1").stdout)
        t_dead = time.time()
        os.close(fd)  # the holder exits: the kernel drops its flock
        self.finish(N)
        self.assertLess(self.intervals()["N"]["start"] - t_dead, 3.0)
        self.assertFalse(name.exists(), "dead ticket was not reaped")

    def test_an_unlocked_ticket_is_ignored_and_reaped(self):
        name, _ = self.hold_ticket(need=12, lock=False)
        t0 = time.time()
        self.finish(self.start(NEW, "light", "N", 1, 0.2))
        self.assertLess(self.intervals()["N"]["start"] - t0, 3.0)
        self.assertFalse(name.exists())

    def test_a_ticket_with_a_stale_heartbeat_is_ignored_but_kept(self):
        name, fd = self.hold_ticket(need=12, heartbeat_age=120)
        try:
            t0 = time.time()
            self.finish(self.start(NEW, "light", "N", 1, 0.2))
            self.assertLess(self.intervals()["N"]["start"] - t0, 3.0)
            self.assertTrue(name.exists(), "a live holder's ticket must not be deleted")
        finally:
            os.close(fd)

    def test_a_non_reserving_ticket_never_blocks(self):
        name, fd = self.hold_ticket(need=12, priority=False)
        try:
            t0 = time.time()
            self.finish(self.start(NEW, "light", "N", 1, 0.2))
            self.assertLess(self.intervals()["N"]["start"] - t0, 3.0)
        finally:
            os.close(fd)

    def test_a_reservation_is_released_after_its_time_cap(self):
        L = self.start(NEW, "light", "L", 9, 7)
        self.wait_event("start", "L")
        H = self.start(NEW, "cpu", "H", 8, 0.3,
                       env=dict(self.env, ZK60_GUARD_FIFO_MAX_PRIORITY_SECS="1.5"))
        t_h = self.wait_ticket("H", state="waiting", priority=True)["heartbeat"]
        N = self.start(NEW, "light", "N", 0.5, 0.3)
        self.wait_ticket("H", priority_expired=True)
        self.finish(N)
        iv = self.intervals()
        self.assertGreater(iv["N"]["start"], t_h + 1.0)   # held back while H reserved
        self.assertNotIn("end", iv["L"])                   # ...but not until H could start
        self.finish(L, H)
        iv = self.intervals()
        self.assertLess(iv["N"]["start"], iv["H"]["start"])

    def test_no_admission_past_the_budget_and_one_heavy_job_at_a_time(self):
        self.stress_new_only()


# ---------------------------------------------------- old and new together --------
@unittest.skipUnless(HAVE_OLD, NO_OLD)
class TestMixedVersions(Base):
    def mixed_stress(self):
        meta, procs = {}, []
        plan = ([("o-l", OLD, "light", 4)] * 4 + [("n-l", NEW, "light", 4)] * 4
                + [("o-b", OLD, "build", 3)] * 2 + [("n-b", NEW, "build", 3)] * 2
                + [("o-c", OLD, "cpu", 5), ("n-c", NEW, "cpu", 5)])
        for i, (stem, ver, cls, need) in enumerate(plan):
            label = f"{stem}{i}"
            meta[label] = (cls, need)
            procs.append(self.start(ver, cls, label, need, 0.8))
        self.finish(*procs, timeout=240)
        worst = self.assert_invariants(meta)
        self.assertGreaterEqual(worst[1], 2)
        self.assertEqual(self.tickets(), [])

    def test_old_and_new_guards_share_the_budget_and_the_heavy_lock(self):
        self.mixed_stress()

    def test_old_and_new_guards_share_the_budget_and_the_heavy_lock_fifo_on(self):
        self.fifo_on()
        self.mixed_stress()

    def test_an_old_guard_holding_the_lock_while_it_waits_does_not_deadlock_new_ones(self):
        L = self.start(NEW, "light", "L", 9, 3)
        self.wait_event("start", "L")
        H = self.start(OLD, "cpu", "H", 8, 0.5)  # old code: takes the lock, then waits
        time.sleep(1.5)
        self.assertFalse(self.lock_free())
        S = self.start(NEW, "build", "S", 3, 0.5)
        L2 = self.start(NEW, "light", "L2", 0.3, 0.3)  # lights are never behind the lock
        self.finish(L2)
        self.finish(L, H, S)
        iv = self.intervals()
        self.assertGreaterEqual(iv["S"]["start"], iv["H"]["end"])  # no overlap, both ran
        self.assertLess(iv["L2"]["start"], iv["H"]["start"])

    def test_job_files_and_status_are_read_across_versions(self):
        show = [sys.executable, "-c",
                "import os, json, time; print(json.dumps(sorted(json.load("
                "open(os.environ['ZK60_GUARD_JOB'])))))"]
        keys = {}
        for ver in (OLD, NEW):
            r = self.cli(ver, "run", "--class", "light", "--no-cgroup", "--", *show)
            self.assertEqual(r.returncode, 0, r.stderr)
            keys[ver] = json.loads(r.stdout.strip().splitlines()[-1])
        self.assertEqual(keys[OLD], keys[NEW])
        for writer, reader, tag in ((NEW, OLD, "new"), (OLD, NEW, "old")):
            p = self.start(writer, "light", f"live-{tag}", 2, 3)
            self.wait_event("start", f"live-{tag}")
            s = json.loads(self.cli(reader, "status", "--json").stdout)
            self.assertEqual([j["label"] for j in s["live_guarded_jobs"]], [f"live-{tag}"])
            self.assertEqual(s["committed_gib"], 2)
            self.finish(p)

    def test_old_status_and_check_ignore_the_queue(self):
        name, fd = self.hold_ticket(need=12)
        try:
            so = self.cli(OLD, "status", "--json")
            sn = self.cli(NEW, "status", "--json")
            self.assertEqual((so.returncode, sn.returncode), (0, 0))
            self.assertEqual(sorted(json.loads(so.stdout)), sorted(json.loads(sn.stdout)))
            # held 12 + 1 > 12.5: only a new guard with FIFO on honours the reservation
            chk = ("check", "--class", "light", "--need-gib", "1")
            self.assertEqual(self.cli(OLD, *chk).returncode, 0)
            self.assertEqual(self.cli(NEW, *chk).returncode, 0)  # FIFO off by default
            self.fifo_on()
            self.assertEqual(self.cli(OLD, *chk).returncode, 0)
            cn = self.cli(NEW, *chk)
            self.assertEqual(cn.returncode, 1)
            self.assertIn("fifo", cn.stdout)
            self.assertLessEqual({p.name for p in self.state.iterdir()},
                                 {"admit.lock", "jobs", "queue", "fifo.on"})
            self.assertTrue(name.exists())
        finally:
            os.close(fd)


# ------------------------------------------------------------ record shapes --------
@unittest.skipUnless(HAVE_OLD, NO_OLD)
class TestRecordShape(Base):
    SCENARIOS = {
        "light-ok": (["--class", "light"], ["true"], {}),
        "cpu-ok": (["--class", "cpu", "--need-gib", "2"], ["true"], {}),
        "gpu-ok": (["--class", "gpu"], ["true"], {}),
        "refused-memory": (["--class", "cpu", "--wait-secs", "1"], ["true"], {"avail": 3}),
        "refused-lock": (["--class", "cpu", "--wait-secs", "2"], ["true"], {"hold": True}),
        "refused-number": (["--class", "light", "--need-gib", "nan"], ["true"], {}),
        "launch-failed": (["--class", "cpu"], ["/nonexistent/binary"], {}),
        "killed-max-secs": (["--class", "light", "--max-secs", "1"], ["sleep", "20"], {}),
        "rc-3": (["--class", "light"], [sys.executable, "-c", "import sys; sys.exit(3)"], {}),
    }

    def test_history_and_result_json_have_the_same_shape_in_both_versions(self):
        got = {}
        for ver, tag in ((OLD, "old"), (NEW, "new")):
            hist = self.t / f"history-{tag}.jsonl"
            env = dict(self.env, ZK60_GUARD_HISTORY=str(hist))
            for name, (flags, cmd, opt) in self.SCENARIOS.items():
                self.meminfo.write_text(meminfo_text(avail_gib=opt.get("avail", 12)))
                res = self.t / f"{name}-{tag}.json"
                fd = None
                if opt.get("hold"):
                    fd = os.open(self.heavy, os.O_RDWR | os.O_CREAT, 0o666)
                    fcntl.flock(fd, fcntl.LOCK_EX)
                try:
                    r = self.cli(ver, "run", *flags, "--no-cgroup", "--result-json", str(res),
                                 "--", *cmd, env=env)
                finally:
                    if fd is not None:
                        os.close(fd)
                rec = json.loads(res.read_text())
                got[(tag, name)] = (r.returncode, rec, self.records(hist)[-1])
        for name in self.SCENARIOS:
            (rc_o, res_o, hist_o), (rc_n, res_n, hist_n) = got[("old", name)], got[("new", name)]
            self.assertEqual(rc_o, rc_n, name)
            self.assertEqual(sorted(res_o), sorted(res_n), name)
            self.assertEqual(sorted(hist_o), sorted(hist_n), name)
            self.assertEqual(res_n, hist_n, name)
            for k in ("exit", "child_rc", "class", "need_gib", "cap_gib", "enforcement"):
                self.assertEqual(repr(res_o.get(k)), repr(res_n.get(k)), f"{name}.{k}")  # nan
            for k in ("refused", "guard_killed", "guard_error"):
                a, b = res_o.get(k), res_n.get(k)
                self.assertEqual(a is None, b is None, f"{name}.{k}")
                if a:
                    self.assertEqual(a.split(":")[0], b.split(":")[0], f"{name}.{k}")
        print("\nscenario exit codes (old == new):",
              {n: got[("new", n)][0] for n in self.SCENARIOS}, file=sys.stderr)


if __name__ == "__main__":
    unittest.main()

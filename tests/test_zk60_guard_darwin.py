"""The resource guard's macOS backend (2026-10-31, M3 Ultra Mac Studio).

The parser tests feed recorded macOS command output through the guard's own
probe functions and run on any host. The live tests run only on Darwin and
check the probes against the machine itself; the existing guard suites cover
admission, kills and records end to end (on Darwin their fake /proc/meminfo and
fake nvidia-smi still exercise the Linux parsers, while process tracking uses
the macOS ps backend)."""
import importlib.machinery
import importlib.util
import os
import subprocess
import sys
import time
import unittest
from pathlib import Path
from unittest import mock

PATH = Path(__file__).resolve().parents[1] / "scripts/zk60_resource_guard.py"
loader = importlib.machinery.SourceFileLoader("guard_darwin_backend", str(PATH))
spec = importlib.util.spec_from_loader(loader.name, loader)
guard = importlib.util.module_from_spec(spec)
loader.exec_module(guard)

ON_DARWIN = sys.platform == "darwin"

# Recorded on the M3 Ultra, 2026-10-31 (trimmed).
VM_STAT = """Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                                 13675133.
Pages active:                                1364899.
Pages inactive:                               939932.
Pages speculative:                            443690.
Pages throttled:                                   0.
Pages wired down:                             277079.
Pages purgeable:                               85466.
"Translation faults":                       27823456.
File-backed pages:                           1513614.
Anonymous pages:                             1234907.
Pages occupied by compressor:                      0.
"""
IOREG = ('    | |   "PerformanceStatistics" = {"In use system memory (driver)"=0,'
         '"Alloc system memory"=2140733440,"Device Utilization %"=3,'
         '"In use system memory"=1204289536}\n')
PS_TABLE = "    1     0     1  32720\n  332     1   332  71952\n 4242   332  4242      8\n"
PS_STAT = "    1 Ss\n  332 Ss\n 4242 Z\n 4243 R+\n"


def fake_run(outputs):
    """A _run_text stand-in: answers by the probe's program (and sysctl name)."""
    def run(argv, timeout=5):
        key = argv[-1] if argv[0].endswith("sysctl") else os.path.basename(argv[0])
        if argv[0].endswith("ps"):
            key = "ps:" + argv[2]
        if key not in outputs:
            raise OSError(f"no fake output for {argv}")
        return outputs[key]
    return run


class DarwinParsers(unittest.TestCase):
    def setUp(self):
        guard._DARWIN_MEMSIZE = None
        guard._DARWIN_GPU_BUDGET_MIB = None

    def meminfo(self, swap="total = 0.00M  used = 0.00M  free = 0.00M  (encrypted)",
                vm=VM_STAT):
        outs = {"vm_stat": vm, "hw.memsize": "274877906944\n", "vm.swapusage": swap}
        with mock.patch.object(guard, "_run_text", side_effect=fake_run(outs)):
            return guard._darwin_meminfo()

    def test_meminfo_keys_and_available_is_free_speculative_reclaimable_inactive(self):
        m = self.meminfo()
        page = 16384
        self.assertEqual(m["MemTotal"], 256 * guard.GIB)
        self.assertEqual(m["MemFree"], 13675133 * page)
        # inactive (939,932) is below file-backed (1,513,614): all of it counts
        self.assertEqual(m["MemAvailable"], (13675133 + 443690 + 939932) * page)
        self.assertEqual((m["SwapTotal"], m["SwapFree"]), (0, 0))

    def test_anonymous_inactive_pages_are_not_counted_as_available(self):
        # under anonymous-memory pressure: little free, a big inactive queue that is
        # mostly anonymous, few file-backed pages left -> MemAvailable stays small
        vm = VM_STAT.replace("13675133.", "20000.").replace("939932.", "9000000.") \
                    .replace("443690.", "1000.").replace("1513614.", "30000.")
        m = self.meminfo(vm=vm)
        # free + speculative + (file-backed - speculative): no page counted twice
        self.assertEqual(m["MemAvailable"], (20000 + 1000 + (30000 - 1000)) * 16384)
        self.assertLess(m["MemAvailable"], guard.FLOOR_GIB * guard.GIB)

    def test_swap_units_are_parsed(self):
        m = self.meminfo("total = 3.00G  used = 1.50G  free = 1536.00M  (encrypted)")
        self.assertEqual(m["SwapTotal"], 3 * guard.GIB)
        self.assertEqual(m["SwapTotal"] - m["SwapFree"], int(1.5 * guard.GIB))

    def test_unparsable_vm_stat_is_an_oserror_like_a_missing_proc_meminfo(self):
        with self.assertRaises(OSError):
            self.meminfo(vm="Mach Virtual Memory Statistics: (page size of 16384 bytes)\n")
        with self.assertRaises(OSError):
            self.meminfo(vm="garbage\n")

    def test_apple_gpu_used_and_budget(self):
        outs = {"ioreg": IOREG, "iogpu.wired_limit_mb": "0\n", "hw.memsize": "274877906944\n"}
        with mock.patch.object(guard, "_run_text", side_effect=fake_run(outs)):
            self.assertEqual(guard._darwin_gpu_mib(), (1204289536 // guard.MIB, 196608))

    def test_apple_gpu_budget_prefers_the_admin_wired_limit(self):
        outs = {"ioreg": IOREG, "iogpu.wired_limit_mb": "229376\n"}
        with mock.patch.object(guard, "_run_text", side_effect=fake_run(outs)):
            self.assertEqual(guard._darwin_gpu_mib()[1], 229376)

    def test_apple_gpu_unreadable_is_none(self):
        outs = {"ioreg": "no accelerator here\n", "iogpu.wired_limit_mb": "0\n",
                "hw.memsize": "274877906944\n"}
        with mock.patch.object(guard, "_run_text", side_effect=fake_run(outs)):
            self.assertIsNone(guard._darwin_gpu_mib())
        with mock.patch.object(guard, "_run_text", side_effect=fake_run({})):
            self.assertIsNone(guard._darwin_gpu_mib())

    def test_ps_table_and_zombies(self):
        outs = {"ps:pid=,ppid=,pgid=,rss=": PS_TABLE, "ps:pid=,stat=": PS_STAT}
        with mock.patch.object(guard, "_run_text", side_effect=fake_run(outs)):
            t = guard._darwin_proc_table()
            alive = guard._darwin_alive_pids()
        self.assertEqual(t[332], (1, 332, 71952 * 1024))   # ps RSS is KiB
        self.assertEqual(t[4242], (332, 4242, 8 * 1024))
        self.assertEqual(alive, {1, 332, 4243})            # the zombie is not alive

    def test_ps_failure_raises_instead_of_an_empty_table(self):
        # an empty table would read as "every job process is gone" (review 2026-10-31)
        with mock.patch.object(guard, "_run_text", side_effect=fake_run({})):
            with self.assertRaises(OSError):
                guard._darwin_proc_table()
            with self.assertRaises(OSError):
                guard._darwin_alive_pids()
            self.assertEqual(guard.top_processes(), []) if guard.DARWIN else None

    def test_a_short_ps_blip_reuses_the_last_sample_then_fails_closed(self):
        outs = {"ps:pid=,ppid=,pgid=,rss=": PS_TABLE}
        with mock.patch.object(guard, "DARWIN", True):
            tr = guard.Tracker(332, None)
            with mock.patch.object(guard, "_run_text", side_effect=fake_run(outs)):
                good = tr.sample()
            self.assertEqual(good, ((71952 + 8) * 1024, {332, 4242}))
            with mock.patch.object(guard, "_run_text", side_effect=fake_run({})):
                for _ in range(guard.PS_BLIND_LIMIT - 1):
                    self.assertEqual(tr.sample(), good)
                with self.assertRaises(OSError):
                    tr.sample()

    def test_a_failed_gpu_budget_probe_is_not_cached(self):
        with mock.patch.dict(os.environ, {"ZK60_GUARD_GPU_BUDGET_MIB": ""}), \
             mock.patch.object(guard, "_run_text", side_effect=fake_run({})):
            self.assertEqual(guard._darwin_gpu_budget_mib(), 0)
        self.assertIsNone(guard._DARWIN_GPU_BUDGET_MIB)
        outs = {"iogpu.wired_limit_mb": "0\n", "hw.memsize": "274877906944\n"}
        with mock.patch.dict(os.environ, {"ZK60_GUARD_GPU_BUDGET_MIB": ""}), \
             mock.patch.object(guard, "_run_text", side_effect=fake_run(outs)):
            self.assertEqual(guard._darwin_gpu_budget_mib(), 196608)

    def test_probe_output_that_is_not_utf8_is_replaced_not_fatal(self):
        out = guard._run_text(["/usr/bin/printf", "ok \\377\\n"])
        self.assertTrue(out.startswith("ok "))
        self.assertIn("�", out)

    def test_thresholds_follow_the_telemetry_source(self):
        # a fake nvidia-smi (any host) keeps the 8 GB card's Linux thresholds
        with mock.patch.object(guard, "NVIDIA_SMI", "/fake/nvidia-smi"):
            self.assertFalse(guard.darwin_gpu_source())
            self.assertEqual(guard.vram_idle_mib(), guard.VRAM_IDLE_MIB)
            self.assertEqual(guard.vram_cap_mib(), guard.VRAM_CAP_MIB)
        with mock.patch.object(guard, "DARWIN", True), \
             mock.patch.object(guard, "NVIDIA_SMI", "nvidia-smi"), \
             mock.patch.object(guard, "_darwin_gpu_budget_mib", return_value=196608):
            self.assertTrue(guard.darwin_gpu_source())
            self.assertEqual(guard.vram_idle_mib(), 4096)
            self.assertEqual(guard.vram_cap_mib(), 196608 * 9 // 10)

    def test_fake_meminfo_still_uses_the_linux_parser_on_darwin(self):
        with mock.patch.object(guard, "DARWIN", True), \
             mock.patch.object(guard, "MEMINFO", "/fake/meminfo"), \
             mock.patch.object(guard, "_darwin_meminfo", side_effect=AssertionError("used")), \
             mock.patch("builtins.open", mock.mock_open(read_data="MemTotal: 1024 kB\n")):
            self.assertEqual(guard.meminfo(), {"MemTotal": 1024 * 1024})


@unittest.skipUnless(ON_DARWIN, "macOS host only")
class DarwinLive(unittest.TestCase):
    def test_meminfo_matches_the_machine(self):
        m = guard.meminfo()
        total = int(subprocess.run(["/usr/sbin/sysctl", "-n", "hw.memsize"],
                                   capture_output=True, text=True).stdout)
        self.assertEqual(m["MemTotal"], total)
        self.assertTrue(0 < m["MemAvailable"] <= m["MemTotal"])
        self.assertTrue(0 <= m["SwapFree"] <= m["SwapTotal"] or m["SwapTotal"] == 0)

    def test_process_table_sees_this_process(self):
        t = guard.proc_table()
        self.assertIn(os.getpid(), t)
        ppid, pgrp, rss = t[os.getpid()]
        self.assertEqual(ppid, os.getppid())
        self.assertEqual(pgrp, os.getpgrp())
        self.assertGreater(rss, 1 * guard.MIB)

    def test_alive_distinguishes_live_and_reaped_pids(self):
        self.assertTrue(guard._alive(os.getpid()))
        p = subprocess.Popen(["/usr/bin/true"])
        p.wait()
        self.assertFalse(guard._alive(p.pid))

    def test_tracker_follows_a_detached_grandchild_and_kills_it(self):
        # the job double-forks a sleeper into the job's own process group
        p = subprocess.Popen(["/bin/sh", "-c", "sleep 60 & sleep 60"], start_new_session=True)
        try:
            tr = guard.Tracker(p.pid, None)
            deadline = __import__("time").time() + 5
            while len(tr.live()) < 3 and __import__("time").time() < deadline:
                __import__("time").sleep(0.1)
            self.assertGreaterEqual(len(tr.live()), 3)
            with mock.patch.object(guard, "TERM_GRACE_SECS", 3):
                tr.kill()
            p.wait(timeout=10)
            self.assertEqual(tr.live(), set())
        finally:
            if p.poll() is None:
                p.kill()

    def test_kill_still_lands_when_ps_cannot_run(self):
        # the reviewer's reproduction: ps fails (e.g. fork exhaustion) during a kill
        p = subprocess.Popen(["/bin/sh", "-c", "sleep 60 & sleep 60"], start_new_session=True)
        try:
            time.sleep(0.5)
            tr = guard.Tracker(p.pid, None)
            real = guard._run_text

            def no_ps(argv, timeout=5):
                if argv[0] == "/bin/ps":
                    raise OSError("simulated: ps cannot fork")
                return real(argv, timeout)

            with mock.patch.object(guard, "_run_text", side_effect=no_ps), \
                 mock.patch.object(guard, "TERM_GRACE_SECS", 3):
                tr.kill()
            p.wait(timeout=10)
            deadline = time.time() + 5
            while time.time() < deadline:
                try:
                    os.killpg(p.pid, 0)       # the background sleep keeps the group alive
                except ProcessLookupError:
                    break
                time.sleep(0.1)
            with self.assertRaises(ProcessLookupError):
                os.killpg(p.pid, 0)
        finally:
            try:
                os.killpg(p.pid, 9)
            except ProcessLookupError:
                pass

    def test_alive_without_ps_says_alive_for_a_live_pid_and_dead_for_a_reaped_one(self):
        with mock.patch.object(guard, "_run_text", side_effect=OSError("no ps")):
            self.assertTrue(guard._alive(os.getpid()))
            p = subprocess.Popen(["/usr/bin/true"])
            p.wait()
            self.assertFalse(guard._alive(p.pid))

    def test_identity_has_a_boot_id_and_start_time(self):
        ident = guard.identity()
        self.assertTrue(ident["boot_id"])
        # on Darwin the field holds the start in epoch seconds (see identity())
        self.assertLessEqual(abs(ident["guard_starttime_ticks"] - __import__("time").time()), 3600 * 24)
        self.assertIsNone(ident["pid_ns"])

    def test_status_snapshot_reads_the_apple_gpu(self):
        s = guard.snapshot()
        self.assertGreater(s["mem_total_gib"], 0)
        self.assertIsNotNone(s["gpu_used_mib"])
        self.assertFalse(s["kernel_memory_cap_available"])


if __name__ == "__main__":
    unittest.main()

"""[ZK60-CL11] Tests for the fail-closed RTX 5090 preflight.

No GPU, no nvidia-smi, no git, no /proc, no planner beyond its arithmetic:
every test hands `evaluate` (or `main --facts-json`) a facts document that
describes a READY 5090 box and flips exactly one fact or argument, then
asserts that `go` is False and that the failing check is the one named. The
few cascades (a missing device or export starves other checks of a fact) are
asserted in full, so a new cascade is a test failure, not a surprise. The
live probes are exercised only by the operator's dry run; nothing here
depends on this box.
"""

import contextlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

_HERE = os.path.dirname(os.path.abspath(__file__))
_SRC = os.path.join(os.path.dirname(_HERE), "scripts", "hashline_cl_5090_preflight.py")
_spec = importlib.util.spec_from_file_location("hashline_cl_5090_preflight", _SRC)
pf = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = pf
_spec.loader.exec_module(pf)

GIB_KIB = 1024 ** 2
CHECK_NAMES = ["device_present", "compute_capability", "driver_version", "nvrtc_toolkit", "cudarc_feature",
               "device_idle", "host_memory", "host_idle", "source_identity", "binary_identity", "shape_supported",
               "planner_margin", "verified_artifact", "coverage_eligibility"]
# Everything that needs a device fails without one; the version gates do NOT
# (they bind only once a Blackwell part is identified), nor does anything host-side.
NO_DEVICE_CASCADE = ["device_present", "compute_capability", "driver_version", "device_idle", "planner_margin"]
BINARY_MTIME = 2000.0
BASE_ARGV = ["--repo", "/r", "--binary", "/r/hashline/target-gpu/release/hashline", "--export", "/e",
             "--floors-log", "/r/results/5090_floors.log"]


def ready_facts():
    """A ready RTX 5090 box: every fact the fourteen checks need, all green."""
    return {
        "schema": 1, "gathered_at": 0.0,
        "gpus": [{"index": 0, "name": "NVIDIA GeForce RTX 5090", "uuid": "GPU-5090", "driver": "570.86",
                  "compute_cap": "12.0", "memory_total_mib": 32607, "memory_used_mib": 100}],
        "compute_apps": [],
        "nvrtc_version": "12.8",
        "cudarc_feature": "cuda-12080",
        "arch_arms": {"8.9": "compute_89", "9.0": "compute_90", "10.0": "compute_100", "12.0": "compute_120"},
        "host": {"mem_total_kib": 128 * GIB_KIB, "mem_available_kib": 64 * GIB_KIB, "loadavg1": 0.5, "logical_cpus": 32},
        "heavy_lock_free": True,
        "git": {"head": "0123abcd", "branch": "zk60-cl1", "dirty_paths": []},
        "binary": {"path": "/r/hashline/target-gpu/release/hashline", "exists": True, "size": 5318584, "mtime": BINARY_MTIME,
                   "sha256": "ab" * 32, "mentions_nvrtc": True, "mentions_cu_module_load": True},
        "sources": {"newest_mtime": BINARY_MTIME - 1000.0, "newest_path": "hashline/src/gpu/cuda.rs"},
        "export": {"path": "/e", "exists": True, "sidecar_sha256": "cd" * 32, "dims": [512, 4096, 14336, 32],
                   "profile": "v3-widened", "model": "hf-model"},
        "floors_log": {"path": "/r/results/5090_floors.log", "exists": True, "mtime": BINARY_MTIME + 1000.0, "green": True,
                       "cases": 12, "cases_expected": 12, "done_marker_exit": 0},
    }


def ada_facts():
    """The WSL laptop today (runbook §3): the non-Blackwell fixture. A 4070 at
    8 GB, driver 566, NVRTC 12.1, cuda-12040; everything else as ready."""
    facts = ready_facts()
    facts["gpus"][0].update({"name": "NVIDIA GeForce RTX 4070 Laptop GPU", "compute_cap": "8.9", "driver": "566.14",
                             "memory_total_mib": 8188})
    facts["nvrtc_version"] = "12.1"
    facts["cudarc_feature"] = "cuda-12040"
    return facts


def flipped(**changes):
    """ready_facts() with whole top-level facts REPLACED, the shape a probe returns
    (a missing binary is {"path", "exists": False} with no mtime, not a patched row)."""
    facts = ready_facts()
    facts.update(changes)
    return facts


def patched(section, **fields):
    """ready_facts() with single fields changed inside one section; "gpu" is the
    selected device row."""
    facts = ready_facts()
    target = facts["gpus"][0] if section == "gpu" else facts[section]
    target.update(fields)
    return facts


def evaluate(facts, extra=()):
    args = pf.build_parser().parse_args(BASE_ARGV + list(extra))
    return pf.evaluate(facts, args)


def check(report, name):
    return next(c for c in report["checks"] if c["check"] == name)


class Refusals(unittest.TestCase):
    def refused(self, facts, expected, extra=(), cascade=()):
        report = evaluate(facts, extra)
        self.assertFalse(report["go"], expected)
        self.assertEqual(report["failed"], [expected, *cascade])
        failed = check(report, expected)
        self.assertFalse(failed["ok"])
        self.assertTrue(failed["reason"])
        return report

    # ------------------------------------------------------------ ready box
    def test_ready_box_is_go_with_every_check_ok(self):
        report = evaluate(ready_facts())
        self.assertTrue(report["go"])
        self.assertEqual(report["failed"], [])
        self.assertEqual([c["check"] for c in report["checks"]], CHECK_NAMES)
        self.assertTrue(all(c["ok"] and c["reason"] is None for c in report["checks"]))
        self.assertTrue(report["blackwell"])
        self.assertEqual(report["device"]["name"], "NVIDIA GeForce RTX 5090")
        pm = check(report, "planner_margin")["evidence"]
        self.assertEqual(pm["w_rows"], 10774)                     # Mistral width at log_cols 14
        self.assertAlmostEqual(pm["w_component_mib"], 1563.5, places=1)
        self.assertEqual(pm["reserve_mib"], pf.DEFAULT_RESERVE_MIB)
        self.assertTrue(pm["fits"])
        self.assertEqual(check(report, "host_memory")["evidence"]["required_gib"], 16)   # FFN-only at width 4096
        # the report is a JSON document (allow_nan=False is what main uses)
        json.dumps(report, allow_nan=False)

    def test_ready_box_still_authorizes_nothing_it_does_not_check(self):
        report = evaluate(ready_facts())
        self.assertIn("installing a driver or toolkit", report["does_not_authorize"])
        self.assertIn("a target-eligible claim from FFN-only coverage", report["does_not_authorize"])

    # -------------------------------------------------------------- device
    def test_no_device(self):
        self.refused(flipped(gpus=[]), "device_present", cascade=NO_DEVICE_CASCADE[1:])

    def test_two_devices_selected(self):
        facts = ready_facts()
        facts["gpus"].append(dict(facts["gpus"][0], index=1, uuid="GPU-other"))
        self.refused(facts, "device_present", cascade=NO_DEVICE_CASCADE[1:])

    def test_unnamed_device(self):
        # only device_present fails: the row still carries cap/driver/memory
        self.refused(patched("gpu", name=""), "device_present")

    def test_unsupported_compute_capability(self):
        report = self.refused(patched("gpu", compute_cap="7.5"), "compute_capability")
        self.assertFalse(report["blackwell"])

    def test_capability_without_an_arch_arm(self):
        arms = {k: v for k, v in ready_facts()["arch_arms"].items() if k != "12.0"}
        report = self.refused(flipped(arch_arms=arms), "compute_capability")
        self.assertIsNone(check(report, "compute_capability")["evidence"]["arch_arm"])

    def test_require_cc_mismatch(self):
        self.refused(ready_facts(), "compute_capability", extra=["--require-cc", "8.9"])

    def test_require_cc_match_is_go(self):
        self.assertTrue(evaluate(ready_facts(), ["--require-cc", "12.0"])["go"])

    # ------------------------------------------------- versions (Blackwell)
    def test_driver_566_on_blackwell(self):
        self.refused(patched("gpu", driver="566.14"), "driver_version")

    def test_nvrtc_12_1_on_blackwell(self):
        self.refused(flipped(nvrtc_version="12.1"), "nvrtc_toolkit")

    def test_nvrtc_missing_fails_even_off_blackwell(self):
        # a missing fact fails the check that needs it, Blackwell or not
        facts = ada_facts()
        facts["nvrtc_version"] = None
        self.refused(facts, "nvrtc_toolkit")

    def test_cudarc_12040_on_blackwell(self):
        self.refused(flipped(cudarc_feature="cuda-12040"), "cudarc_feature")

    def test_version_gates_do_not_bind_off_blackwell(self):
        report = evaluate(ada_facts())
        self.assertFalse(report["blackwell"])
        for name in ("driver_version", "nvrtc_toolkit", "cudarc_feature", "compute_capability"):
            self.assertTrue(check(report, name)["ok"], name)
        # and an 8 GB card fits at the default 0.8 margin: the laptop did run this shape
        self.assertEqual(report["failed"], [])

    def test_datacenter_blackwell_binds_the_same_gates(self):
        # sm_100 codegen also lands in CUDA 12.8 on R570: (10, 0) is Blackwell here
        report = self.refused(patched("gpu", compute_cap="10.0", driver="566.14"), "driver_version")
        self.assertTrue(report["blackwell"])

    def test_bare_driver_string_meets_the_floor(self):
        # Python orders (570,) below (570, 0); the gate pads, so "570" passes
        self.assertTrue(evaluate(patched("gpu", driver="570"))["go"])
        self.assertTrue(pf.at_least((570,), (570, 0)))
        self.assertFalse(pf.at_least((569, 99), (570,)))
        self.assertFalse(pf.at_least((), (570,)))

    # ---------------------------------------------------------------- idle
    def test_busy_device_memory(self):
        self.refused(patched("gpu", memory_used_mib=pf.IDLE_DEVICE_USED_MIB + 1), "device_idle")

    def test_compute_apps_present(self):
        self.refused(flipped(compute_apps=[{"pid": 4242, "used_mib": 300}]), "device_idle")

    def test_compute_apps_unknown(self):
        self.refused(flipped(compute_apps=None), "device_idle")

    # ---------------------------------------------------------------- host
    def test_low_host_memory(self):
        self.refused(patched("host", mem_available_kib=8 * GIB_KIB), "host_memory")

    def test_full_coverage_wants_64_gib(self):
        # 48 GiB carries the FFN-only shape (16 GiB rule) but not the full-layer statement
        self.assertTrue(evaluate(patched("host", mem_available_kib=48 * GIB_KIB))["go"])
        report = self.refused(patched("host", mem_available_kib=48 * GIB_KIB), "host_memory", extra=["--coverage", "full"])
        self.assertEqual(check(report, "host_memory")["evidence"]["required_gib"], 64)

    def test_host_min_override(self):
        self.refused(ready_facts(), "host_memory", extra=["--host-min-gib", "65"])

    def test_heavy_lock_held(self):
        self.refused(flipped(heavy_lock_free=False), "host_idle")

    def test_high_load(self):
        self.refused(patched("host", loadavg1=17.0), "host_idle")   # 32 CPUs: the line is 16

    # ------------------------------------------------------------- sources
    def test_dirty_tree(self):
        self.refused(patched("git", dirty_paths=["hashline/src/gpu/cuda.rs"]), "source_identity")

    def test_git_unreadable(self):
        self.refused(flipped(git=None), "source_identity")

    # -------------------------------------------------------------- binary
    def test_missing_binary(self):
        # no binary also means nothing the floors log could have verified
        self.refused(flipped(binary={"path": "/r/none", "exists": False}), "binary_identity", cascade=["verified_artifact"])

    def test_stale_binary(self):
        self.refused(flipped(sources={"newest_mtime": BINARY_MTIME + 1.0, "newest_path": "hashline/src/pcs.rs"}), "binary_identity")

    def test_binary_not_gpu_featured(self):
        self.refused(patched("binary", mentions_nvrtc=False), "binary_identity")

    # --------------------------------------------------------------- shape
    def test_export_missing(self):
        self.refused(flipped(export={"path": "/e", "exists": False}), "shape_supported", cascade=["planner_margin"])

    def test_export_null_fact_does_not_crash(self):
        self.refused(flipped(export=None), "shape_supported", cascade=["planner_margin"])

    def test_wrong_profile(self):
        self.refused(patched("export", profile="v2"), "shape_supported")

    def test_tokens_not_a_power_of_two(self):
        self.refused(ready_facts(), "shape_supported", extra=["--tokens", "500"])

    def test_tokens_beyond_export(self):
        self.refused(ready_facts(), "shape_supported", extra=["--tokens", "1024"])

    def test_layers_beyond_export(self):
        self.refused(ready_facts(), "shape_supported", extra=["--layers", "33"])

    # ------------------------------------------------------------- planner
    def test_planner_margin_exceeded(self):
        # an 8 GB card at Mistral width: 1,563.5 MiB chunked W + 3,619 MiB reserve
        # fits 80% of 8,188 MiB, not 50%
        report = self.refused(patched("gpu", memory_total_mib=8188), "planner_margin", extra=["--margin-fraction", "0.5"])
        ev = check(report, "planner_margin")["evidence"]
        self.assertGreater(ev["need_mib"], ev["allowed_mib"])
        self.assertEqual(ev["mode"], "chunked")

    def test_planner_margin_reserve_argument(self):
        self.refused(ready_facts(), "planner_margin", extra=["--reserve-mib", "30000"])

    def test_resident_mode_is_the_larger_component(self):
        chunked = check(evaluate(ready_facts()), "planner_margin")["evidence"]
        resident = check(evaluate(ready_facts(), ["--chunk-mode", "resident"]), "planner_margin")["evidence"]
        self.assertGreater(resident["w_component_mib"], 8 * chunked["w_component_mib"])
        self.assertTrue(resident["fits"])   # 32 GB carries the resident path at 0.8

    def test_planner_refusal_on_shape(self):
        report = self.refused(patched("export", dims=[512, 4100, 14336, 32]), "planner_margin")
        self.assertIn("refused", check(report, "planner_margin")["reason"])

    def test_planner_refusal_on_argument(self):
        self.refused(ready_facts(), "planner_margin", extra=["--inv-rate", "3"])

    # ------------------------------------------------------------ artifact
    def test_floors_log_missing(self):
        self.refused(flipped(floors_log={"path": "/r/none.log", "exists": False}), "verified_artifact")

    def test_floors_log_not_green(self):
        self.refused(patched("floors_log", green=False), "verified_artifact")

    def test_floors_cases_mismatch(self):
        self.refused(patched("floors_log", cases=11), "verified_artifact")

    def test_floors_done_marker_nonzero(self):
        self.refused(patched("floors_log", done_marker_exit=1), "verified_artifact")

    def test_floors_done_marker_missing(self):
        self.refused(patched("floors_log", done_marker_exit=None), "verified_artifact")

    def test_floors_log_older_than_binary(self):
        self.refused(patched("floors_log", mtime=BINARY_MTIME - 1.0), "verified_artifact")

    # ------------------------------------------------------------ coverage
    def test_target_claim_needs_full_coverage(self):
        self.refused(ready_facts(), "coverage_eligibility", extra=["--claim", "target"])

    def test_target_claim_refuses_a_seed(self):
        self.refused(ready_facts(), "coverage_eligibility", extra=["--claim", "target", "--coverage", "full", "--seed", "1"])

    def test_target_claim_with_full_coverage_and_no_seed_is_go(self):
        report = evaluate(ready_facts(), ["--claim", "target", "--coverage", "full"])
        self.assertTrue(report["go"])
        self.assertEqual(report["request"]["claim"], "target")

    def test_diagnostic_claim_tolerates_a_seed(self):
        self.assertTrue(evaluate(ready_facts(), ["--seed", "1"])["go"])


class Parsing(unittest.TestCase):
    def test_version_and_capability_tuples(self):
        self.assertEqual(pf.version_tuple("570.86.16"), (570, 86, 16))
        self.assertEqual(pf.version_tuple("12.8"), (12, 8))
        self.assertEqual(pf.version_tuple(None), ())
        self.assertEqual(pf.cc_tuple("12.0"), (12, 0))
        self.assertEqual(pf.cc_tuple("sm_89"), ())      # not a dotted capability
        self.assertEqual(pf.cc_tuple("570.86.16"), ())

    def test_export_and_floors_probes_read_the_real_formats(self):
        # the sidecar and floors-log formats are the collector's and cl1_floors.sh's
        with tempfile.TemporaryDirectory() as root:
            export = os.path.join(root, "export")
            os.mkdir(export)
            with open(os.path.join(export, "digests.txt"), "w", encoding="utf-8") as fh:
                fh.write("00 model hf-model\n00 dims 512 4096 14336 32\n00 profile v3-widened\n01 layer00 deadbeef\n")
            ex = pf.probe_export(export)
            self.assertEqual(ex["dims"], [512, 4096, 14336, 32])
            self.assertEqual(ex["profile"], "v3-widened")
            self.assertEqual(ex["model"], "hf-model")
            log = os.path.join(root, "floors.log")
            with open(log, "w", encoding="utf-8") as fh:
                fh.write("gate 1 ok\nexecuted byte-gate cases: 12 (expect 12)\nALL CL1 FLOORS GREEN (12 byte gates + oracle suite + tests + both builds)\n")
            with open(os.path.join(root, "floors.done"), "w", encoding="utf-8") as fh:
                fh.write("0\n")
            fl = pf.probe_floors_log(log)
            self.assertTrue(fl["green"])
            self.assertEqual((fl["cases"], fl["cases_expected"], fl["done_marker_exit"]), (12, 12, 0))
            self.assertFalse(pf.probe_export(os.path.join(root, "nowhere"))["exists"])
            self.assertFalse(pf.probe_floors_log(os.path.join(root, "nowhere.log"))["exists"])


class Cli(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.TemporaryDirectory()
        self.addCleanup(self.root.cleanup)

    def facts_path(self, facts, name="facts.json"):
        path = os.path.join(self.root.name, name)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(facts, fh)
        return path

    def run_main(self, argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = pf.main(argv)
        return code, json.loads(out.getvalue())

    def test_go_returns_zero_and_no_probe_runs(self):
        with mock.patch.object(pf, "gather_facts", side_effect=AssertionError("a probe ran")) as probe:
            code, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts())])
        self.assertEqual(code, 0)
        self.assertTrue(report["go"])
        self.assertEqual(report["facts"]["source"], "injected")
        probe.assert_not_called()

    def test_not_go_returns_three(self):
        code, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(patched("gpu", driver="566.14"))])
        self.assertEqual(code, 3)
        self.assertEqual(report["failed"], ["driver_version"])

    def test_bad_margin_fraction_exits_two(self):
        for bad in ("0", "1.5", "-0.1"):
            with self.assertRaises(SystemExit) as error:
                with contextlib.redirect_stderr(io.StringIO()):
                    pf.main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts()), "--margin-fraction", bad])
            self.assertEqual(error.exception.code, 2, bad)

    def test_missing_facts_file_exits_two(self):
        with self.assertRaises(SystemExit) as error:
            with contextlib.redirect_stderr(io.StringIO()):
                pf.main(BASE_ARGV + ["--facts-json", os.path.join(self.root.name, "absent.json")])
        self.assertEqual(error.exception.code, 2)

    def test_out_refuses_to_overwrite(self):
        out = os.path.join(self.root.name, "report.json")
        with open(out, "w", encoding="utf-8") as fh:
            fh.write("keep me\n")
        with mock.patch.object(pf, "gather_facts", side_effect=AssertionError("a probe ran")):
            with self.assertRaises(SystemExit) as error:
                with contextlib.redirect_stderr(io.StringIO()):
                    pf.main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts()), "--out", out])
        self.assertEqual(error.exception.code, 2)
        with open(out, encoding="utf-8") as fh:
            self.assertEqual(fh.read(), "keep me\n")

    def test_out_writes_a_new_file(self):
        out = os.path.join(self.root.name, "report.json")
        code, printed = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts()), "--out", out])
        self.assertEqual(code, 0)
        with open(out, encoding="utf-8") as fh:
            self.assertEqual(json.load(fh), printed)

    def test_emit_plan_orders_the_ladder_and_detaches_every_heavy_stage(self):
        code, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts()), "--emit-plan",
                                                  "--layers", "32", "--tokens", "512"])
        self.assertEqual(code, 0)
        plan = report["campaign_plan"]
        self.assertTrue(plan["preflight_go"])
        stages = plan["ordered_stages"]
        self.assertEqual([s["stage"] for s in stages], list(range(7)))
        self.assertIn("BEFORE any timing", stages[0]["name"])     # byte gates first (runbook §4)
        for s in stages:
            if not s["heavy"]:
                self.assertNotIn("detached", s)
                continue
            self.assertIn("setsid nohup", s["detached"])
            self.assertIn(".done", s["detached"])
            self.assertTrue(s["done_marker"].endswith(".done"))
            self.assertIn("/tmp/zk-heavy.lock", s["lock"])
        # raw hashline / floors stages take the lock in the wrapper
        for i in (0, 1, 2):
            self.assertIn("flock /tmp/zk-heavy.lock", stages[i]["detached"], i)
        # collector stages: the runner holds the lock itself; an outer flock would deadlock
        for i in (3, 4, 5):
            self.assertIn("hashline_benchmark.py run", stages[i]["detached"], i)
            self.assertNotIn("flock", stages[i]["detached"], i)
            self.assertIn("INSIDE", stages[i]["lock"], i)
            self.assertIn("--warm-runs 20", stages[i]["detached"], i)
            self.assertIn("--layers 32 --tokens 512", stages[i]["detached"], i)
        self.assertIn("--privacy P1", stages[3]["command"])
        self.assertIn("--privacy P3", stages[4]["command"])
        self.assertIn("NOT RUNNABLE", stages[6]["command"])
        self.assertFalse(stages[6]["heavy"])
        self.assertEqual(plan["device"]["name"], "NVIDIA GeForce RTX 5090")

    def test_plan_is_emitted_even_when_not_go_and_says_so(self):
        code, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(flipped(heavy_lock_free=False)), "--emit-plan"])
        self.assertEqual(code, 3)
        self.assertFalse(report["campaign_plan"]["preflight_go"])

    def test_no_plan_without_the_flag(self):
        _, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts())])
        self.assertNotIn("campaign_plan", report)


if __name__ == "__main__":
    unittest.main()

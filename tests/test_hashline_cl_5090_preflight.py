"""[ZK60-CL11] Tests for the fail-closed RTX 5090 preflight.

No GPU, no nvidia-smi, no git, no /proc, no planner beyond its arithmetic:
every test hands `evaluate` (or `main --facts-json`) a facts document that
describes a READY 5090 box and flips exactly one fact or argument, then
asserts that `go` is False and that the failing check is the one named. The
few cascades (a missing device or export starves other checks of a fact) are
asserted in full, so a new cascade is a test failure, not a surprise. The
live probes are exercised only by the operator's dry run; nothing here
depends on this box.

[ZK60-CL13] The ready box now carries a RUN MANIFEST (the CL13 evidence, a
complete suite-version-1 manifest built through the gates module's real
record path, bound to the fixture HEAD `0123abcd` and the fixture GPU binary
digest `ab..`). Fixtures that changed meaning: an absent or unrelated binary
digest, zero executed oracle cases and a manifest whose HEAD/binary differ
now REFUSE; `--coverage full --claim target` with nothing recorded behind it
REFUSES (it used to be go); a missing git fact also fails verified_artifact
(nothing to bind the manifest to). The floors-log fixtures became
deprecated-hint fixtures: a green log alone can never pass.

[ZK60-CL21] The ready box also carries a SOURCE IDENTITY fact (both crates'
tree ids, deltas, lockfile hashes, the core's presence — the gates module's
synthetic identity, which the fixture manifest records too). `source_identity`
now also needs the core present with an empty delta and both lockfiles
readable; `verified_artifact` binds the manifest's crate trees and lockfile
hashes to that fact, so a mismatched dependency identity, a missing core, an
unreadable identity and a pre-CL21 manifest (records none) all refuse. A
complete v4 manifest (the core cases included) is go.
"""

import contextlib
import importlib.util
import io
import json
import os
import shlex
import sys
import tempfile
import unittest
from unittest import mock

_HERE = os.path.dirname(os.path.abspath(__file__))
_SCRIPTS = os.path.join(os.path.dirname(_HERE), "scripts")
_SRC = os.path.join(_SCRIPTS, "hashline_cl_5090_preflight.py")
_spec = importlib.util.spec_from_file_location("hashline_cl_5090_preflight", _SRC)
pf = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = pf
_spec.loader.exec_module(pf)
_gspec = importlib.util.spec_from_file_location("hashline_cl_gpu_gates", os.path.join(_SCRIPTS, "hashline_cl_gpu_gates.py"))
gg = importlib.util.module_from_spec(_gspec)
_gspec.loader.exec_module(gg)

GIB_KIB = 1024 ** 2
CHECK_NAMES = ["device_present", "compute_capability", "driver_version", "nvrtc_toolkit", "cudarc_feature",
               "device_idle", "host_memory", "host_idle", "source_identity", "binary_identity", "shape_supported",
               "planner_margin", "verified_artifact", "coverage_eligibility"]
# Everything that needs a device fails without one; the version gates do NOT
# (they bind only once a Blackwell part is identified), nor does anything host-side.
NO_DEVICE_CASCADE = ["device_present", "compute_capability", "driver_version", "device_idle", "planner_margin"]
BINARY_MTIME = 2000.0
HEAD, GPU_SHA, CPU_SHA = "0123abcd", "ab" * 32, "ee" * 32
DEVICE = "gpu: ON — NVIDIA GeForce RTX 5090 (sm_120, 170 SMs, 34.1 GB)"
MANIFEST_PATH = "/r/results/floors/manifest.json"
BASE_ARGV = ["--repo", "/r", "--binary", "/r/hashline/target-gpu/release/hashline", "--export", "/e",
             "--run-manifest", MANIFEST_PATH]


def green_manifest(**kw):
    """A complete, green suite-v1 manifest bound to the fixture HEAD and binary."""
    params = {"suite_version": 1, "head": HEAD, "gpu_sha256": GPU_SHA, "cpu_sha256": CPU_SHA, "device": DEVICE}
    params.update(kw)
    return gg.synthetic_manifest(**params)


def manifest_fact(manifest):
    return {"path": MANIFEST_PATH, "exists": True, "mtime": BINARY_MTIME + 1000.0, "manifest": manifest}


def identity_fact():
    """[CL21] the tree in hand: the same synthetic identity the fixture manifest records."""
    ident = json.loads(json.dumps(gg.SYNTHETIC_SOURCE))
    ident.update({"repo": "/r", "head": HEAD, "branch": "zk60-cl1", "dirty_tracked_count": 0, "dirty_delta_sha256": gg.EMPTY_SHA256})
    return ident


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
        "git": {"head": HEAD, "branch": "zk60-cl1", "dirty_paths": [], "core_dirty_paths": []},
        "source_identity": identity_fact(),
        "binary": {"path": "/r/hashline/target-gpu/release/hashline", "exists": True, "size": 5318584, "mtime": BINARY_MTIME,
                   "sha256": GPU_SHA, "mentions_nvrtc": True, "mentions_cu_module_load": True},
        "sources": {"newest_mtime": BINARY_MTIME - 1000.0, "newest_path": "hashline/src/gpu/cuda.rs", "zkp_core_present": True,
                    "crates": {"hashline": {"newest_mtime": BINARY_MTIME - 1000.0, "newest_path": "hashline/src/gpu/cuda.rs", "files": 40},
                               "zkp_core": {"newest_mtime": BINARY_MTIME - 2000.0, "newest_path": "zkp-core/src/sumcheck.rs", "files": 11}}},
        "export": {"path": "/e", "exists": True, "sidecar_sha256": "cd" * 32, "dims": [512, 4096, 14336, 32],
                   "profile": "v3-widened", "model": "hf-model"},
        # the deprecated hint, green, present — and never sufficient
        "floors_log": {"path": "/r/results/5090_floors.log", "exists": True, "mtime": BINARY_MTIME + 1000.0, "green": True,
                       "cases": 12, "cases_expected": 12, "done_marker_exit": 0},
        "run_manifest": manifest_fact(green_manifest()),
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


def with_manifest(**kw):
    return flipped(run_manifest=manifest_fact(green_manifest(**kw)))


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
        self.assertTrue(report["go"], report["failed"])
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
        va = check(report, "verified_artifact")["evidence"]
        self.assertTrue(va["validator"]["ok"])
        self.assertEqual(va["validator"]["summary"]["oracle_executed_cases"], 49)
        # [CL21] bound to HEAD, the binary, AND both crates' trees and lockfiles
        self.assertEqual(va["bound_to"], {"head": HEAD, "gpu_binary_sha256": GPU_SHA,
                                          "crate_trees": {"hashline": "1" * 40, "zkp_core": "2" * 40},
                                          "lockfiles": {"hashline": "3" * 64, "zkp_core": "4" * 64}})
        si = check(report, "source_identity")["evidence"]
        self.assertTrue(si["identity_readable"])
        self.assertEqual(si["crates"]["zkp_core"]["tree"], "2" * 40)
        self.assertEqual(si["core_layout"], {"manifest": True, "src": True, "example": True})
        self.assertTrue(check(report, "binary_identity")["evidence"]["digest_matches_manifest"])
        # the report is a JSON document (allow_nan=False is what main uses)
        json.dumps(report, allow_nan=False)

    def test_ready_box_is_a_diagnostic_claim_only(self):
        report = evaluate(ready_facts())
        self.assertEqual(report["request"]["claim"], "diagnostic")
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
        # the manifest still binds (same HEAD); the tree itself is the refusal
        self.refused(patched("git", dirty_paths=["hashline/src/gpu/cuda.rs"]), "source_identity")

    def test_git_unreadable(self):
        # [CL13] no HEAD fact also means nothing to bind the manifest to
        self.refused(flipped(git=None), "source_identity", cascade=["verified_artifact"])

    # ------------------------------------------------- [CL21] the extracted core
    def test_dirty_core_path_refuses(self):
        # a dirty zkp-core file is a dirty tracked tree (the core is a build input)
        report = self.refused(patched("git", dirty_paths=["zkp-core/src/field.rs"], core_dirty_paths=["zkp-core/src/field.rs"]), "source_identity")
        self.assertEqual(check(report, "source_identity")["evidence"]["git"]["core_dirty_paths"], ["zkp-core/src/field.rs"])

    def test_dirty_core_delta_refuses(self):
        # the probe's own reading: a nonempty delta under zkp-core/ with a clean status
        # cannot happen, but the identity check does not rely on the status alone
        facts = ready_facts()
        facts["source_identity"]["crates"]["zkp_core"]["dirty_delta_sha256"] = "ab" * 32
        self.refused(facts, "source_identity", cascade=["verified_artifact"])

    def test_missing_core_refuses(self):
        # no zkp-core/ in the tree in hand: the identity fails, and the manifest's
        # recorded core tree cannot be the (absent) one in hand
        facts = ready_facts()
        facts["source_identity"]["crates"]["zkp_core"].update({"present": False, "tree": None, "manifest": False, "src": False, "example": False})
        facts["source_identity"]["lockfiles"]["zkp_core"]["sha256"] = None
        facts["sources"]["zkp_core_present"] = False
        report = self.refused(facts, "source_identity", cascade=["verified_artifact"])
        self.assertTrue(any("zkp-core/ tree" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))

    def test_incomplete_core_refuses(self):
        facts = ready_facts()
        facts["source_identity"]["crates"]["zkp_core"].update({"present": False, "example": False})
        report = self.refused(facts, "source_identity", cascade=["verified_artifact"])
        self.assertEqual(check(report, "source_identity")["evidence"]["core_layout"]["example"], False)

    def test_mismatched_lockfile_identity_refuses(self):
        # the tree is clean at the manifest's HEAD, but zkp-core/Cargo.lock is not the one the run built against
        facts = ready_facts()
        facts["source_identity"]["lockfiles"]["zkp_core"]["sha256"] = "ff" * 32
        report = self.refused(facts, "verified_artifact")
        self.assertTrue(any("zkp-core/Cargo.lock sha256" in r and "lockfile in hand" in r
                            for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))
        facts = ready_facts()
        facts["source_identity"]["lockfiles"]["hashline"]["sha256"] = "ff" * 32
        self.refused(facts, "verified_artifact")

    def test_mismatched_crate_tree_refuses(self):
        for name in ("hashline", "zkp_core"):
            facts = ready_facts()
            facts["source_identity"]["crates"][name]["tree"] = "f" * 40
            report = self.refused(facts, "verified_artifact")
            self.assertTrue(any("tree in hand" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]), name)

    def test_source_identity_unreadable_refuses(self):
        report = self.refused(flipped(source_identity=None), "source_identity", cascade=["verified_artifact"])
        self.assertFalse(check(report, "source_identity")["evidence"]["identity_readable"])
        self.assertIn("no source identity", check(report, "verified_artifact")["evidence"]["validator"]["reasons"][0])

    def test_unreadable_lockfile_refuses(self):
        facts = ready_facts()
        facts["source_identity"]["lockfiles"]["hashline"]["sha256"] = None
        self.refused(facts, "source_identity", cascade=["verified_artifact"])

    def test_pre_cl21_manifest_cannot_be_bound(self):
        # an archived v1–v3 manifest records no crate identity: valid on its own, not bindable here
        report = self.refused(with_manifest(source_identity=None), "verified_artifact")
        self.assertTrue(any("records no crate tree ids" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))
        self.assertTrue(gg.validate_manifest(green_manifest(source_identity=None), require_production=True)["ok"])

    def test_v4_manifest_with_the_core_cases_is_go(self):
        report = evaluate(with_manifest(suite_version=4))
        self.assertTrue(report["go"], report["failed"])
        summary = check(report, "verified_artifact")["evidence"]["validator"]["summary"]
        self.assertEqual((summary["suite_version"], summary["cases_recorded"], summary["core_tests_passed"]), (4, 23, 19))

    def test_v4_manifest_missing_core_cases_refuses(self):
        def drop(m):
            m["cases"] = [c for c in m["cases"] if c["id"] != "core_tests"]
        report = self.refused(with_manifest(suite_version=4, mutate=drop), "verified_artifact")
        self.assertTrue(any("missing case core_tests" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))

    def test_v4_manifest_recording_a_dirty_core_refuses(self):
        def dirty(m):
            m["source"]["crates"]["zkp_core"]["dirty_delta_sha256"] = "ab" * 32
        self.refused(with_manifest(suite_version=4, mutate=dirty), "verified_artifact")

    def test_stale_binary_against_the_core_sources(self):
        # [CL21] a core source newer than the binary is a stale binary too
        facts = ready_facts()
        facts["sources"]["newest_mtime"] = BINARY_MTIME + 1.0
        facts["sources"]["newest_path"] = "zkp-core/src/field.rs"
        self.refused(facts, "binary_identity")

    # -------------------------------------------------------------- binary
    def test_missing_binary(self):
        # no binary also means no digest the manifest could be bound to
        self.refused(flipped(binary={"path": "/r/none", "exists": False}), "binary_identity", cascade=["verified_artifact"])

    def test_stale_binary(self):
        self.refused(flipped(sources={"newest_mtime": BINARY_MTIME + 1.0, "newest_path": "hashline/src/pcs.rs"}), "binary_identity")

    def test_binary_not_gpu_featured(self):
        self.refused(patched("binary", mentions_nvrtc=False), "binary_identity")

    def test_absent_binary_digest_refuses(self):
        # [CL13 probe 1] round-9: this returned go with no failed check
        for absent in (None, "", "not-a-digest"):
            report = self.refused(patched("binary", sha256=absent), "binary_identity", cascade=["verified_artifact"])
            self.assertFalse(check(report, "binary_identity")["evidence"]["digest_present"])

    def test_unrelated_binary_digest_refuses(self):
        # [CL13 probe 2] a digest that is not the manifest's GPU binary
        report = self.refused(patched("binary", sha256="ff" * 32), "binary_identity", cascade=["verified_artifact"])
        ev = check(report, "binary_identity")["evidence"]
        self.assertTrue(ev["digest_present"])
        self.assertFalse(ev["digest_matches_manifest"])
        self.assertEqual(ev["manifest_gpu_sha256"], GPU_SHA)
        self.assertTrue(any("binary in hand" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))

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

    def test_memory_budget_binds_the_planner(self):
        # [CL13] an explicit budget below the need refuses; one above it passes and is recorded
        report = self.refused(ready_facts(), "planner_margin", extra=["--memory-budget-mib", "4000"])
        ev = check(report, "planner_margin")["evidence"]
        self.assertEqual((ev["memory_budget_mib"], ev["allowed_mib"]), (4000, 4000.0))
        report = evaluate(ready_facts(), ["--memory-budget-mib", "20000"])
        self.assertTrue(report["go"])
        self.assertEqual(check(report, "planner_margin")["evidence"]["allowed_mib"], 20000.0)
        self.assertEqual(report["request"]["memory_budget_mib"], 20000)

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
    # Without a manifest there is also no recorded GPU-binary digest for the
    # binary in hand to be bound to, so binary_identity fails alongside.
    NO_MANIFEST_CASCADE = ["verified_artifact"]

    def test_run_manifest_missing(self):
        report = self.refused(flipped(run_manifest={"path": MANIFEST_PATH, "exists": False}), "binary_identity", cascade=self.NO_MANIFEST_CASCADE)
        self.assertIn("--run-manifest", check(report, "verified_artifact")["evidence"]["validator"]["reasons"][0])
        self.assertIsNone(check(report, "binary_identity")["evidence"]["manifest_gpu_sha256"])

    def test_run_manifest_not_json(self):
        self.refused(flipped(run_manifest={"path": MANIFEST_PATH, "exists": True, "error": "not a JSON document: x"}),
                     "binary_identity", cascade=self.NO_MANIFEST_CASCADE)

    def test_green_floors_log_alone_cannot_pass(self):
        # the deprecated hint is present and green in ready_facts(); without the manifest it counts for nothing
        report = self.refused(flipped(run_manifest={"path": MANIFEST_PATH, "exists": False}), "binary_identity", cascade=self.NO_MANIFEST_CASCADE)
        ev = check(report, "verified_artifact")["evidence"]
        self.assertTrue(ev["deprecated_floors_log_hint"]["green"])
        self.assertIn("deprecated", check(report, "verified_artifact")["reason"])
        self.assertIn("never sufficient", check(report, "verified_artifact")["reason"])

    def test_manifest_head_mismatch(self):
        # the tree is clean at a different HEAD: the manifest tested another source
        report = self.refused(patched("git", head="deadbeef"), "verified_artifact")
        self.assertTrue(any("!= the current HEAD deadbeef" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))

    def test_manifest_binary_mismatch(self):
        # the manifest recorded another GPU binary than the one in hand
        report = self.refused(with_manifest(gpu_sha256="12" * 32), "binary_identity", cascade=["verified_artifact"])
        self.assertTrue(any("binary in hand" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))

    def test_zero_executed_oracle_cases_refuses(self):
        # [CL13 probe 3a] a manifest whose oracle executed nothing
        def zero(m):
            r = next(c for c in m["cases"] if c["id"] == "oracle_gpu")
            r["oracle_summary"] = json.dumps({"executed_cases": 0, "gpu_enabled": True, "gpu_required": True, "device": DEVICE})
        report = self.refused(with_manifest(mutate=zero), "verified_artifact")
        self.assertTrue(any("zero-case" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))

    def test_zero_expected_cases_refuses(self):
        # [CL13 probe 3b] a manifest with no cases at all
        report = self.refused(with_manifest(mutate=lambda m: m["cases"].clear()), "verified_artifact")
        self.assertTrue(any("missing case" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))

    def test_oracle_count_not_the_suites_refuses(self):
        def off(m):
            r = next(c for c in m["cases"] if c["id"] == "oracle_gpu")
            r["oracle_summary"] = json.dumps({"executed_cases": 20, "gpu_enabled": True, "gpu_required": True, "device": DEVICE})
        self.refused(with_manifest(mutate=off), "verified_artifact")

    def test_incomplete_manifest_refuses(self):
        self.refused(with_manifest(mutate=lambda m: m["started"].update({"gpu-v2": 1.0})), "verified_artifact")
        self.refused(with_manifest(finalize=False), "verified_artifact")

    def test_missing_negative_control_refuses(self):
        def drop(m):
            m["cases"] = [c for c in m["cases"] if c["id"] != "cache_p3_refusal"]
        self.refused(with_manifest(mutate=drop), "verified_artifact")

    def test_failed_case_refuses(self):
        def fail(m):
            next(c for c in m["cases"] if c["id"] == "gpu-zkchunk-zkv3")["gpu_on"] = False
        self.refused(with_manifest(mutate=fail), "verified_artifact")

    def test_synthetic_suite_manifest_is_not_evidence(self):
        report = self.refused(with_manifest(suite_version=0), "verified_artifact")
        self.assertTrue(any("not production" in r for r in check(report, "verified_artifact")["evidence"]["validator"]["reasons"]))

    def test_non_frozen_shape_manifest_refuses(self):
        self.refused(with_manifest(layers=32), "verified_artifact")

    # ------------------------------------------------------------ coverage
    def test_target_claim_needs_full_coverage(self):
        self.refused(ready_facts(), "coverage_eligibility", extra=["--claim", "target"])

    def test_target_claim_refuses_a_seed(self):
        self.refused(ready_facts(), "coverage_eligibility", extra=["--claim", "target", "--coverage", "full", "--seed", "1"])

    def test_flag_only_full_target_is_refused(self):
        # [CL13 probe 4] `--coverage full --claim target` with nothing recorded behind
        # it used to be go; the flag cannot supply coverage
        report = self.refused(ready_facts(), "coverage_eligibility", extra=["--claim", "target", "--coverage", "full"])
        c = check(report, "coverage_eligibility")
        self.assertIn("flag cannot supply coverage", c["reason"])
        self.assertEqual(c["evidence"]["coverage_recorded"], "ffn-only")
        self.assertFalse(c["evidence"]["recorded_full_and_decoded"])

    def test_manifest_claiming_full_coverage_is_refused_by_the_validator(self):
        # a hand-edited coverage block fails the suite (v1 covers FFN-only) and still
        # does not carry decoded verification, so both checks refuse
        def claim(m):
            m["coverage"]["coverage"] = "full"
        self.refused(with_manifest(mutate=claim), "verified_artifact", extra=["--claim", "target", "--coverage", "full"],
                     cascade=["coverage_eligibility"])

    def test_recorded_full_and_decoded_evidence_passes_coverage_but_needs_a_suite_that_covers_it(self):
        def claim(m):
            m["coverage"] = {"coverage": "full", "verification": "decoded-full-relation"}
        report = self.refused(with_manifest(mutate=claim), "verified_artifact", extra=["--claim", "target", "--coverage", "full"])
        self.assertTrue(check(report, "coverage_eligibility")["ok"])

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

    def test_export_floors_and_manifest_probes_read_the_real_formats(self):
        # the sidecar and floors-log formats are the collector's and cl1_floors.sh's;
        # the manifest is the gates module's document
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
            man = os.path.join(root, "manifest.json")
            with open(man, "w", encoding="utf-8") as fh:
                json.dump(green_manifest(), fh)
            rm = pf.probe_run_manifest(man)
            self.assertTrue(rm["exists"])
            self.assertEqual(rm["manifest"]["suite_version"], 1)
            with open(man, "w", encoding="utf-8") as fh:
                fh.write("{not json")
            self.assertIn("error", pf.probe_run_manifest(man))
            self.assertFalse(pf.probe_export(os.path.join(root, "nowhere"))["exists"])
            self.assertFalse(pf.probe_floors_log(os.path.join(root, "nowhere.log"))["exists"])
            self.assertFalse(pf.probe_run_manifest(os.path.join(root, "nowhere.json"))["exists"])

    def test_sources_probe_covers_both_crates(self):
        # [CL21] the newest source is taken over hashline AND zkp-core (src, Cargo.toml,
        # Cargo.lock, the examples); the core's presence is a fact of its own
        with tempfile.TemporaryDirectory() as repo:
            files = ["hashline/src/main.rs", "hashline/Cargo.toml", "hashline/Cargo.lock",
                     "zkp-core/src/lib.rs", "zkp-core/Cargo.toml", "zkp-core/Cargo.lock", "zkp-core/examples/public_sumcheck.rs"]
            for i, rel in enumerate(files):
                path = os.path.join(repo, rel)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w", encoding="utf-8") as fh:
                    fh.write("x\n")
                os.utime(path, (1000.0 + i, 1000.0 + i))
            s = pf.probe_sources(repo)
            self.assertEqual(s["newest_path"], "zkp-core/examples/public_sumcheck.rs")
            self.assertEqual(s["newest_mtime"], 1006.0)
            self.assertTrue(s["zkp_core_present"])
            self.assertEqual(s["crates"]["hashline"]["files"], 3)
            self.assertEqual(s["crates"]["zkp_core"]["files"], 4)
            self.assertEqual(s["crates"]["hashline"]["newest_path"], "hashline/Cargo.lock")
            os.remove(os.path.join(repo, "zkp-core", "examples", "public_sumcheck.rs"))
            s = pf.probe_sources(repo)
            self.assertFalse(s["zkp_core_present"])
            self.assertEqual(s["newest_path"], "zkp-core/Cargo.lock")
        self.assertIsNone(pf.probe_source_identity(os.path.join(tempfile.gettempdir(), "no-such-dir-cl21"))["head"])


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

    def test_bad_threads_or_budget_exit_two(self):
        for extra in (["--threads", "0"], ["--memory-budget-mib", "0"], ["--parity-layers", "0"]):
            with self.assertRaises(SystemExit) as error:
                with contextlib.redirect_stderr(io.StringIO()):
                    pf.main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts()), *extra])
            self.assertEqual(error.exception.code, 2, extra)

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

    def test_plan_propagates_shape_threads_and_budget_into_every_command(self):
        # [CL13] no 32-layer campaign is hardcoded: the request is what the commands carry
        code, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts()), "--emit-plan",
                                                  "--layers", "8", "--tokens", "256", "--threads", "4", "--memory-budget-mib", "20000",
                                                  "--chunk-rows", "256"])
        self.assertEqual(code, 0)
        plan = report["campaign_plan"]
        heavy = [s for s in plan["ordered_stages"] if s["heavy"]]
        self.assertEqual(len(heavy), 6)
        for s in heavy:
            self.assertIn("HL_GPU_CHUNK_ROWS=256", s["command"], s["stage"])
            self.assertIn("--threads 4", s["command"], s["stage"])
            self.assertEqual(s["memory_budget_mib"], 20000, s["stage"])
            self.assertEqual(s["chunk_rows"], 256)
            self.assertIn("HL_GPU_CHUNK_ROWS=256", s["detached"])
        # the campaign stages carry the requested shape
        self.assertIn(" pass 8 256 ", heavy[2]["command"])
        for i in (3, 4, 5):
            self.assertIn("--layers 8 --tokens 256", heavy[i]["command"])
        # stage 0 runs the suite's FROZEN shape and says so; stage 1 the one-layer gate
        self.assertIn("--layers 12 --tokens 512", heavy[0]["command"])
        self.assertIn("--threads 4 --build-jobs 4 --rayon-threads 4", heavy[0]["command"])
        self.assertEqual(heavy[0]["shape"]["layers"], 12)
        self.assertIn("FROZEN", heavy[0]["shape"]["why"])
        self.assertIn(" pass 1 256 ", heavy[1]["command"])
        self.assertEqual(plan["request"]["memory_budget_mib"], 20000)
        text = json.dumps(plan)
        self.assertNotIn("/home/victor/wt-zk60-cl1", text)
        self.assertNotIn("pass 32", text)
        self.assertNotIn("--threads 8", text)
        # without an explicit budget the planner's allowance is the budget
        _, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts()), "--emit-plan"])
        pm = check(report, "planner_margin")["evidence"]
        self.assertEqual(report["campaign_plan"]["request"]["memory_budget_mib"], pm["allowed_mib"])
        self.assertEqual(report["campaign_plan"]["request"]["threads"], 2)

    def test_plan_quotes_paths_with_spaces(self):
        repo, export, scratch = "/tmp/a b/repo", "/tmp/a b/export dir", "/tmp/a b/scratch"
        binary = repo + "/hashline/target-gpu/release/hashline"
        argv = ["--repo", repo, "--binary", binary, "--export", export, "--scratch", scratch, "--run-manifest", MANIFEST_PATH,
                "--facts-json", self.facts_path(ready_facts()), "--emit-plan"]
        code, report = self.run_main(argv)
        self.assertEqual(code, 0)
        for s in report["campaign_plan"]["ordered_stages"]:
            if not s["heavy"]:
                continue
            toks = shlex.split(s["command"])
            self.assertTrue(any(t.startswith(scratch + "/") for t in toks), s["command"])
            if "pass" in toks:
                self.assertEqual(toks[toks.index("pass") - 1], binary)
                self.assertEqual(toks[toks.index("--export") + 1], export)
            elif "run" in toks:
                self.assertEqual(toks[toks.index("--binary") + 1], binary)
                self.assertEqual(toks[toks.index("--export") + 1], export)
            else:
                self.assertEqual(toks[toks.index("--repo") + 1], repo)
                self.assertEqual(toks[toks.index("--v3-export") + 1], export)
            wrapper = shlex.split(s["detached"])
            self.assertEqual(wrapper[:4], ["setsid", "nohup", "bash", "-c"])
            body = shlex.split(wrapper[4])
            self.assertIn(binary if "cl1_floors.sh" not in s["command"] else repo, body)
            self.assertTrue(s["done_marker"].startswith(scratch + "/"))

    def test_dry_run_emits_no_hardware_job(self):
        # facts injected, plan emitted: no probe, no subprocess, no lock, no file under the scratch dir
        with tempfile.TemporaryDirectory() as scratch:
            with mock.patch.object(pf, "gather_facts", side_effect=AssertionError("a probe ran")), \
                 mock.patch.object(pf.subprocess, "run", side_effect=AssertionError("a process ran")), \
                 mock.patch.object(pf.subprocess, "Popen", side_effect=AssertionError("a process ran")):
                code, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts()), "--emit-plan",
                                                          "--scratch", scratch])
            self.assertEqual(code, 0)
            self.assertEqual(os.listdir(scratch), [])
            for s in report["campaign_plan"]["ordered_stages"]:
                if s["heavy"]:
                    self.assertIsInstance(s["detached"], str)

    def test_plan_is_emitted_even_when_not_go_and_says_so(self):
        code, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(flipped(heavy_lock_free=False)), "--emit-plan"])
        self.assertEqual(code, 3)
        self.assertFalse(report["campaign_plan"]["preflight_go"])

    def test_no_plan_without_the_flag(self):
        _, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(ready_facts())])
        self.assertNotIn("campaign_plan", report)

    def test_round9_probes_end_to_end(self):
        # the four reproduced acceptances, through main: every one is exit 3 now
        probes = {
            "missing_binary_digest": (patched("binary", sha256=None), []),
            "wrong_binary_digest": (patched("binary", sha256="ff" * 32), []),
            "zero_floor_cases": (with_manifest(mutate=lambda m: m["cases"].clear()), []),
            "flag_only_full_target": (ready_facts(), ["--coverage", "full", "--claim", "target"]),
        }
        for name, (facts, extra) in probes.items():
            code, report = self.run_main(BASE_ARGV + ["--facts-json", self.facts_path(facts, name + ".json"), *extra])
            self.assertEqual(code, 3, name)
            self.assertFalse(report["go"], name)
            self.assertTrue(report["failed"], name)


if __name__ == "__main__":
    unittest.main()

"""[ZK60-CL13] Tests for the floors suite definition, run manifest, validator
and the portable floors runner — CPU only.

No cargo, no prover, no device, no lock: the parser is fed the archived
summary formats (and the two bash expansions of the JSON default, through a
real `bash -c`), the validator is fed complete synthetic manifests with
exactly one thing broken at a time, the record/finalize CLI is round-tripped
over synthetic logs and tiny proof files under the synthetic suite (version
0), and results/cl1_floors.sh is exercised ONLY with `bash -n` and
`--dry-run` — on paths with spaces — so every command it would run is
inspected without running one.

[ZK60-CL21] Added: the source identity of BOTH crates (tree ids, deltas,
lockfile hashes, the core's presence) and suite version 4's core cases. The
four refusals (dirty core, missing core, mismatched dependency identity,
missing core cases), archived v1–v3 manifests without the identity still
validating, a complete synthetic v4 manifest passing, the core-test and
example log parsers (valid — the round-11 logs themselves —, empty, failed,
ignored), the dry-run plan carrying the core commands with quoted paths, and
the runner refusing to START on a missing or dirty core (a real `git init`
checkout under a temp dir; the refusal lands before any cargo command).
"""

import copy
import hashlib
import importlib.util
import io
import json
import os
import shlex
import subprocess
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stdout, redirect_stderr

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
_SRC = os.path.join(_ROOT, "scripts", "hashline_cl_gpu_gates.py")
_FLOORS = os.path.join(_ROOT, "results", "cl1_floors.sh")
_spec = importlib.util.spec_from_file_location("hashline_cl_gpu_gates", _SRC)
gg = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = gg
_spec.loader.exec_module(gg)

GOOD = '{"executed_cases":49,"gpu_enabled":true,"gpu_required":true,"device":"gpu: ON — NVIDIA GeForce RTX 4070 Laptop GPU (sm_89, 36 SMs, 8.6 GB)"}'
EXPECTED_V1 = ["build_cpu", "build_gpu", "cargo_test_cpu", "oracle_gpu", "nofeature_required_refuses", "nofeature_plain_reports_zero",
               "cpu-v2", "cpu-v3", "cpu-zk", "cpu-zkv3", "gpu-v2", "gpu-v3", "gpu-zk", "gpu-zkv3",
               "gpu-zkchunk-v2", "gpu-zkchunk-v3", "gpu-zkchunk-zk", "gpu-zkchunk-zkv3",
               "cache_cold_zkv3", "cache_warm_zkv3", "cache_p3_refusal"]
# [ZK60-CL21] v4 = v3 + the two core cases, placed after the hashline crate tests
EXPECTED_V4 = EXPECTED_V1[:3] + ["core_tests", "core_example"] + EXPECTED_V1[3:]
HEAD, GPU_SHA, CPU_SHA = "0123abcd", "ab" * 32, "ee" * 32
DEVICE = "gpu: ON — synthetic device (sm_00, 1 SMs, 0.0 GB)"
_R11 = os.path.join(_ROOT, "results", "zk60_round11_evidence")
CORE_LINE = "public dot-product sumcheck verified; altered round refused (primitive example, no privacy claim)"
GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
           "GIT_CONFIG_NOSYSTEM": "1", "HOME": tempfile.gettempdir()}


def git(repo, *args):
    """A read/write git call on a TEMP repository the test created (never on the
    project's checkout); --no-pager and captured output, so it cannot hang."""
    return subprocess.run(["git", "--no-pager", "-C", repo, "-c", "commit.gpgsign=false", *args], check=True,
                          capture_output=True, text=True, env=dict(os.environ, **GIT_ENV)).stdout.strip()


def make_checkout(root, core=True):
    """A committed two-crate layout (hashline/ + zkp-core/ with Cargo.toml,
    Cargo.lock, src/, the example) under `root`; `core=False` omits zkp-core."""
    os.makedirs(root, exist_ok=True)
    git(root, "init", "-q")
    files = {"hashline/Cargo.toml": "[package]\nname = \"hashline\"\n", "hashline/Cargo.lock": "# lock\n",
             "hashline/src/main.rs": "fn main() {}\n"}
    if core:
        files.update({"zkp-core/Cargo.toml": "[package]\nname = \"zkp-core\"\n", "zkp-core/Cargo.lock": "# core lock\n",
                      "zkp-core/src/lib.rs": "pub fn f() {}\n", "zkp-core/examples/public_sumcheck.rs": "fn main() {}\n"})
    for rel, text in files.items():
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "fixture")
    return root


def bash_expand(template, value):
    """The expansion a floors run performs, through a real bash."""
    return subprocess.run(["bash", "-c", 'S=$1; printf %s "' + template + '"', "_", value],
                          check=True, capture_output=True, text=True).stdout


def green(**kw):
    kw.setdefault("suite_version", 1)
    return gg.synthetic_manifest(head=HEAD, gpu_sha256=GPU_SHA, cpu_sha256=CPU_SHA, device=DEVICE, **kw)


def record_of(manifest, case_id):
    return next(r for r in manifest["cases"] if r["id"] == case_id)


class OracleSummary(unittest.TestCase):
    def test_valid_summary_parses(self):
        s = gg.parse_oracle_summary(GOOD, 49)
        self.assertEqual(s["executed_cases"], 49)
        self.assertIn("RTX 4070", s["device"])
        # with or without the tag, and without an expected count
        self.assertEqual(gg.parse_oracle_summary("ZK60_CL4_SUMMARY " + GOOD)["executed_cases"], 49)

    def test_empty_and_missing_data_refused(self):
        for bad in ("", "   ", None, "{}", "[]", '{"executed_cases": null}', '{"executed_cases": "49"}',
                    '{"executed_cases": true, "gpu_enabled": true, "gpu_required": true, "device": "x"}',
                    GOOD.replace('"device":"gpu', '"device":"').replace("(sm_89, 36 SMs, 8.6 GB)", "")[:0] or "not json"):
            with self.assertRaises(gg.GatesError, msg=repr(bad)):
                gg.parse_oracle_summary(bad, 49)

    def test_zero_executed_cases_refused(self):
        with self.assertRaisesRegex(gg.GatesError, "zero-case"):
            gg.parse_oracle_summary(GOOD.replace('"executed_cases":49', '"executed_cases":0'), 49)

    def test_count_is_the_suites_not_a_floor(self):
        # 48 would pass a floor of 20; it is not the suite's 49
        with self.assertRaisesRegex(gg.GatesError, "48 != the suite's expected 49"):
            gg.parse_oracle_summary(GOOD.replace('"executed_cases":49', '"executed_cases":48'), 49)
        with self.assertRaisesRegex(gg.GatesError, "50 != the suite's expected 49"):
            gg.parse_oracle_summary(GOOD.replace('"executed_cases":49', '"executed_cases":50'), 49)

    def test_disabled_or_unrequired_device_refused(self):
        with self.assertRaisesRegex(gg.GatesError, "gpu_enabled"):
            gg.parse_oracle_summary(GOOD.replace('"gpu_enabled":true', '"gpu_enabled":false'), 49)
        with self.assertRaisesRegex(gg.GatesError, "gpu_required"):
            gg.parse_oracle_summary(GOOD.replace('"gpu_required":true', '"gpu_required":false'), 49)

    def test_former_extra_brace_expansion_is_detected_and_the_quoted_form_passes(self):
        # `${S:-{}}` ends the default at the first `}` and appends a literal one
        unquoted = bash_expand("${S:-{}}", GOOD)
        self.assertEqual(unquoted, GOOD + "}")
        with self.assertRaisesRegex(gg.GatesError, "not valid JSON"):
            gg.parse_oracle_summary(unquoted, 49)
        quoted = bash_expand('${S:-"{}"}', GOOD)
        self.assertEqual(quoted, GOOD)
        self.assertEqual(gg.parse_oracle_summary(quoted, 49)["executed_cases"], 49)
        # and with NO summary at all both forms yield "{}", which is refused as missing data
        for template in ("${S:-{}}", '${S:-"{}"}'):
            with self.assertRaises(gg.GatesError, msg=template):
                gg.parse_oracle_summary(bash_expand(template, ""), 49)

    def test_cli_exit_codes(self):
        def run(text):
            return subprocess.run([sys.executable, _SRC, "oracle-summary", "--expected-cases", "49", text],
                                  capture_output=True, text=True).returncode
        self.assertEqual(run(GOOD), 0)
        self.assertEqual(run(GOOD + "}"), 2)
        self.assertEqual(run(""), 2)
        self.assertEqual(run(GOOD.replace("49", "0")), 2)


class SuiteDefinition(unittest.TestCase):
    def test_v1_case_identities(self):
        self.assertEqual(gg.expected_cases(1), EXPECTED_V1)
        self.assertEqual(len(set(EXPECTED_V1)), 21)
        s = gg.suite(1)
        self.assertTrue(s["production"])
        self.assertEqual(s["coverage"], "ffn-only")
        self.assertEqual(s["shape"], [12, 512])
        self.assertEqual(sorted(s["controls"]), ["cache_p3_refusal", "nofeature_plain_reports_zero", "nofeature_required_refuses"])

    def test_frozen_digests_are_the_archived_runs(self):
        # results/cl_round7_floors.log, all twelve GATE OK lines
        self.assertEqual(gg.FROZEN["v2"], ("50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d", 66844928))
        self.assertEqual(gg.FROZEN["v3"], ("5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d", 70758084))
        self.assertEqual(gg.FROZEN["zk"], ("021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d", 87228528))
        self.assertEqual(gg.FROZEN["zkv3"], ("40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17", 87697008))
        for label in ("cpu", "gpu", "gpu-zkchunk"):
            for profile, (sha, length) in gg.FROZEN.items():
                c = gg.case_definition(1, f"{label}-{profile}")
                self.assertEqual(c["expect"], {"sha256": sha, "bytes": length})
                self.assertEqual(c["gpu_on"], label != "cpu")
                self.assertEqual(c["binary"], "cpu" if label == "cpu" else "gpu")
        self.assertEqual(gg.case_definition(1, "gpu-zkchunk-zk")["env"], {"HL_GPU": "1", "HL_ZK_CHUNK": "1"})

    def test_oracle_count_is_tied_to_the_suite_version(self):
        self.assertEqual(gg.case_definition(1, "oracle_gpu")["expect"]["executed_cases"], 49)
        self.assertEqual(gg.case_definition(0, "oracle_gpu")["expect"]["executed_cases"], 3)
        with self.assertRaisesRegex(gg.GatesError, "unknown suite version"):
            gg.suite(7)
        out = subprocess.run([sys.executable, _SRC, "expected-cases", "--suite-version", "1", "--oracle-count"],
                             check=True, capture_output=True, text=True).stdout
        self.assertEqual(out.strip(), "49")
        out = subprocess.run([sys.executable, _SRC, "expected-cases"], check=True, capture_output=True, text=True).stdout
        self.assertEqual(out.split(), EXPECTED_V4)      # [CL21] the default is v4
        out = subprocess.run([sys.executable, _SRC, "expected-cases", "--suite-version", "3"], check=True, capture_output=True, text=True).stdout
        self.assertEqual(out.split(), EXPECTED_V1)

    def test_cache_cases_follow_the_cache_tests_flags(self):
        # zk60_gpu_cache.rs `prover()`: pass 12 512 --threads N --profile v3 --seed 1 --export <v3> + --zk --wcache DIR
        for cid, mode in (("cache_cold_zkv3", "cold"), ("cache_warm_zkv3", "warm")):
            c = gg.case_definition(1, cid)
            self.assertEqual(c["args"], ["--zk", "--seed", "1", "--profile", "v3", "--export", "{v3_export}", "--wcache", "{wcache_dir}"])
            self.assertEqual(c["env"], {"HL_WCACHE_VERBOSE": "1"})
            self.assertEqual(c["expect"], dict(zip(("sha256", "bytes"), gg.FROZEN["zkv3"])))
            self.assertEqual((c["binary"], c["wcache"]), ("cpu", mode))
        p3 = gg.case_definition(1, "cache_p3_refusal")
        self.assertEqual(p3["exit"], 2)
        self.assertEqual(p3["stderr_starts"], "REFUSED: --wcache with --p3.")
        self.assertIn("--p3", p3["args"])
        self.assertIn("/nonexistent/zk60-cl13-export", p3["args"])

    def test_v2_expects_cl15s_141_oracle_cases_and_is_the_default(self):
        # [ZK60-CL15 -> CL13 follow-up] CL15 (lane 6dce8a9) grew the device oracle
        # from 49 to 141 executed cases; the count is the SUITE'S, so that cut v2.
        # v1 keeps 82314a1's 49 — the archived round-7 manifest-less run is still
        # describable — and everything but the oracle expectation is identical.
        v1, v2, v3 = gg.suite(1), gg.suite(2), gg.suite(3)
        # [ZK60-CL18] v3 = CL18's 189; [ZK60-CL21] v4 = v3 + the core cases is the default
        self.assertEqual(gg.DEFAULT_SUITE, 4)
        self.assertEqual(gg.case_definition(1, "oracle_gpu")["expect"]["executed_cases"], 49)
        self.assertEqual(gg.case_definition(2, "oracle_gpu")["expect"]["executed_cases"], 141)
        self.assertEqual(gg.case_definition(3, "oracle_gpu")["expect"]["executed_cases"], 189)
        self.assertEqual(gg.case_definition(4, "oracle_gpu")["expect"]["executed_cases"], 189)
        self.assertIn("6dce8a9", gg.case_definition(2, "oracle_gpu")["established"])
        self.assertIn("cl18_oracle.log", gg.case_definition(3, "oracle_gpu")["established"])
        self.assertEqual(gg.expected_cases(1), gg.expected_cases(2))
        self.assertEqual(gg.expected_cases(2), gg.expected_cases(3))
        self.assertTrue(v2["production"] and v3["production"])
        for c1, c2, c3 in zip(v1["cases"], v2["cases"], v3["cases"]):
            if c1["id"] != "oracle_gpu":
                self.assertEqual(c1, c2, c1["id"])
                self.assertEqual(c2, c3, c2["id"])
        # v1–v3 never required the crate identity (archived meanings preserved)
        for v in (1, 2, 3):
            self.assertFalse(gg.suite(v).get("requires_source_identity"), v)

    def test_v4_gates_the_extracted_core_with_tied_expectations(self):
        # [ZK60-CL21] hashline depends on zkp-core by path; v4 = v3 plus the core's
        # own tests and example, each with the SUITE'S expectation from round 11
        v3, v4 = gg.suite(3), gg.suite(4)
        self.assertEqual(gg.expected_cases(4), EXPECTED_V4)
        self.assertEqual(len(EXPECTED_V4), 23)
        self.assertTrue(v4["production"] and v4["requires_source_identity"])
        self.assertEqual([c for c in v4["cases"] if c["id"] not in ("core_tests", "core_example")], v3["cases"])
        ct = gg.case_definition(4, "core_tests")
        self.assertEqual(ct["expect"], {"passed": 19, "failed": 0, "ignored": 0})
        self.assertEqual((ct["kind"], ct["exit"], ct["manifest_path"]), ("core_tests", 0, "zkp-core/Cargo.toml"))
        self.assertIn("c8a342f", ct["established"])
        self.assertIn("v5", ct["established"])          # a changed core test set cuts v5, the count does not move
        ce = gg.case_definition(4, "core_example")
        self.assertEqual((ce["kind"], ce["exit"], ce["example"]), ("core_example", 0, "public_sumcheck"))
        self.assertEqual(ce["expect"], {"line": CORE_LINE})
        self.assertEqual(gg.CORE_EXAMPLE_LINE, CORE_LINE)
        # the synthetic suite mirrors v4's structure with a count that cannot pass as the core's
        self.assertEqual(gg.expected_cases(0), EXPECTED_V4)
        self.assertEqual(gg.case_definition(0, "core_tests")["expect"]["passed"], 2)
        self.assertFalse(gg.suite(0)["requires_source_identity"])
        out = subprocess.run([sys.executable, _SRC, "expected-cases", "--suite-version", "4"], check=True, capture_output=True, text=True).stdout
        self.assertEqual(out.split(), EXPECTED_V4)
        self.assertEqual(gg.CRATES, {"hashline": "hashline", "zkp_core": "zkp-core"})
        # 49 is a REFUSAL against the default suite; the default's own count passes
        want = gg.case_definition(gg.DEFAULT_SUITE, "oracle_gpu")["expect"]["executed_cases"]
        with self.assertRaisesRegex(gg.GatesError, f"49 != the suite's expected {want}"):
            gg.parse_oracle_summary(GOOD, want)
        self.assertEqual(gg.parse_oracle_summary(GOOD.replace('"executed_cases":49', f'"executed_cases":{want}'), want)["executed_cases"], want)

    def test_synthetic_suite_is_not_production(self):
        self.assertFalse(gg.suite(0)["production"])
        for c in gg.suite(0)["cases"]:
            if c["kind"] in ("byte_gate", "cache"):
                self.assertEqual(c["expect"]["sha256"], hashlib.sha256(gg.SYNTHETIC_PROOF[c["profile"]]).hexdigest())

    def test_self_test_is_green(self):
        self.assertEqual(gg.self_test()["synthetic_round_trip"], "green")


class Validator(unittest.TestCase):
    def refused(self, needle, mutate=None, **validate_kw):
        m = green(mutate=mutate)
        v = gg.validate_manifest(m, **validate_kw)
        self.assertFalse(v["ok"], needle)
        self.assertTrue(any(needle in r for r in v["reasons"]), f"{needle!r} not in {v['reasons']}")
        return v

    def test_complete_supported_diagnostic_manifest_passes(self):
        m = green()
        v = gg.validate_manifest(m, expect_head=HEAD, expect_gpu_sha256=GPU_SHA, expect_device=DEVICE, require_production=True)
        self.assertTrue(v["ok"], v["reasons"])
        self.assertEqual(v["summary"]["cases_recorded"], 21)
        self.assertEqual(v["summary"]["oracle_executed_cases"], 49)
        self.assertEqual(v["summary"]["device"], DEVICE)
        self.assertTrue(m["verdict"]["green"])
        self.assertEqual(m["verdict"]["computed_by"], "hashline_cl_gpu_gates.validate_manifest")
        json.dumps(m, allow_nan=False)

    # ------------------------------------------------------------ identities
    def test_missing_case(self):
        self.refused("missing case cache_p3_refusal", lambda m: m["cases"].pop())

    def test_duplicate_case(self):
        self.refused("duplicate case record cpu-v2", lambda m: m["cases"].append(copy.deepcopy(record_of(m, "cpu-v2"))))

    def test_unexpected_case(self):
        self.refused("unexpected case extra", lambda m: m["cases"].append(dict(record_of(m, "cpu-v2"), id="extra")))

    def test_missing_negative_control(self):
        v = self.refused("missing negative control nofeature_required_refuses",
                         lambda m: m["cases"].remove(record_of(m, "nofeature_required_refuses")))
        self.assertTrue(any("missing case nofeature_required_refuses" in r for r in v["reasons"]))

    # ------------------------------------------------------------- bindings
    def test_head_mismatch(self):
        self.refused("!= the current HEAD ffff", expect_head="ffff")

    def test_binary_mismatch_against_the_binary_in_hand(self):
        self.refused("!= the binary in hand", expect_gpu_sha256="00" * 32)

    def test_binary_mismatch_between_records(self):
        self.refused("ran binary", lambda m: record_of(m, "gpu-v2").update(binary_sha256="11" * 32))

    def test_device_mismatch_between_records(self):
        self.refused("the oracle on", lambda m: record_of(m, "gpu-zkchunk-zk").update(device_label="gpu: ON — another card"))

    def test_device_mismatch_against_expectation(self):
        self.refused("oracle device", expect_device="gpu: ON — RTX 5090")

    def test_source_delta_not_empty(self):
        self.refused("uncommitted changes under hashline/", lambda m: m["source"].update(dirty_delta_sha256="ab" * 32))

    def test_missing_binary_identity(self):
        self.refused("gpu binary identity missing", lambda m: m["binaries"]["gpu"].update(sha256=None))

    # ------------------------------------------------------------ artifacts
    def test_digest_mismatch(self):
        self.refused("!= frozen", lambda m: record_of(m, "cpu-v2")["proof"].update(sha256="00" * 32))

    def test_length_mismatch(self):
        self.refused("!= frozen", lambda m: record_of(m, "gpu-zkv3")["proof"].update(bytes=1))

    def test_expectation_not_the_suites(self):
        self.refused("is not the suite's", lambda m: record_of(m, "cpu-zk")["expected"].update(bytes=5))

    def test_nonzero_exit(self):
        self.refused("cpu-v3 exit 1 != 0", lambda m: record_of(m, "cpu-v3").update(exit=1))

    def test_control_that_did_not_refuse(self):
        self.refused("exited 0 but must refuse", lambda m: record_of(m, "nofeature_required_refuses").update(exit=0))

    def test_non_accept_verdict(self):
        self.refused("verdict REJECT is not ACCEPT", lambda m: record_of(m, "gpu-v3").update(verdict="REJECT"))

    def test_gpu_case_without_gpu_on(self):
        self.refused("shows no 'gpu: ON'", lambda m: record_of(m, "gpu-zkchunk-v2").update(gpu_on=False))

    def test_zero_executed_oracle_cases(self):
        self.refused("zero-case", lambda m: record_of(m, "oracle_gpu").update(
            oracle_summary=json.dumps({"executed_cases": 0, "gpu_enabled": True, "gpu_required": True, "device": DEVICE})))

    def test_oracle_count_off_by_one_is_not_the_suites(self):
        self.refused("48 != the suite's expected 49", lambda m: record_of(m, "oracle_gpu").update(
            oracle_summary=json.dumps({"executed_cases": 48, "gpu_enabled": True, "gpu_required": True, "device": DEVICE})))

    def test_zero_expected_cases_is_impossible_but_an_empty_record_list_is_refused(self):
        v = self.refused("missing case build_cpu", lambda m: m["cases"].clear())
        self.assertEqual(sum(1 for r in v["reasons"] if r.startswith("missing case")), 21)

    # --------------------------------------------------------- completeness
    def test_started_but_unrecorded_case(self):
        self.refused("started but never recorded", lambda m: m["started"].update({"gpu-v2": 1.0}))

    def test_not_finalized(self):
        m = green(finalize=False)
        v = gg.validate_manifest(m)
        self.assertFalse(v["ok"])
        self.assertIn("manifest not finalized", v["reasons"])
        self.assertIn("no verdict recorded (finalize was not run)", v["reasons"])

    def test_hand_written_verdict_disagrees(self):
        m = green()
        record_of(m, "cpu-zk")["exit"] = 1          # broken AFTER finalize; the stored verdict still says green
        v = gg.validate_manifest(m)
        self.assertFalse(v["ok"])
        self.assertTrue(any("disagrees with the recomputed verdict" in r for r in v["reasons"]))
        m2 = green(finalize=False)
        m2["verdict"] = {"green": True, "reasons": []}
        m2["finalized_at"] = "hand"
        record_of(m2, "cpu-zk")["exit"] = 1
        self.assertFalse(gg.validate_manifest(m2)["ok"])

    def test_coverage_claim_beyond_the_suite(self):
        self.refused("not what suite version 1 covers", lambda m: m["coverage"].update(coverage="full"))

    def test_non_frozen_shape_has_no_expectation(self):
        m = green(layers=32, tokens=512)
        v = gg.validate_manifest(m)
        self.assertFalse(v["ok"])
        self.assertTrue(any("no_frozen_expectation" in r for r in v["reasons"]))
        self.assertEqual(record_of(m, "cpu-v2")["expected"], "no_frozen_expectation")
        self.assertFalse(record_of(m, "cpu-v2")["ok"])

    def test_synthetic_suite_is_refused_as_production(self):
        m = gg.synthetic_manifest(suite_version=0)
        self.assertTrue(gg.validate_manifest(m)["ok"])
        v = gg.validate_manifest(m, require_production=True)
        self.assertFalse(v["ok"])
        self.assertTrue(any("not production evidence" in r for r in v["reasons"]))

    def test_not_a_manifest(self):
        self.assertFalse(gg.validate_manifest({"schema": 1})["ok"])
        self.assertFalse(gg.validate_manifest([])["ok"])
        self.assertFalse(gg.validate_manifest(dict(green(), suite_version=9))["ok"])
        self.assertFalse(gg.validate_manifest(dict(green(), schema=3))["ok"])

    # ------------------------------------------------ [CL21] source identity
    def refused4(self, needle, mutate=None, **kw):
        m = green(suite_version=4, mutate=mutate)
        v = gg.validate_manifest(m, **kw)
        self.assertFalse(v["ok"], needle)
        self.assertTrue(any(needle in r for r in v["reasons"]), f"{needle!r} not in {v['reasons']}")
        return v

    def test_complete_v4_manifest_passes_and_binds_to_its_identity(self):
        m = green(suite_version=4)
        trees, locks = gg.identity_expectations(gg.SYNTHETIC_SOURCE)
        v = gg.validate_manifest(m, expect_head=HEAD, expect_gpu_sha256=GPU_SHA, expect_device=DEVICE, require_production=True,
                                 expect_trees=trees, expect_lockfiles=locks)
        self.assertTrue(v["ok"], v["reasons"])
        self.assertEqual(v["summary"]["cases_recorded"], 23)
        self.assertEqual(v["summary"]["crate_trees"], {"hashline": "1" * 40, "zkp_core": "2" * 40})
        self.assertEqual(v["summary"]["lockfiles"], {"hashline": "3" * 64, "zkp_core": "4" * 64})
        self.assertEqual(v["summary"]["core_tests_passed"], 19)
        self.assertEqual(m["schema"], 2)
        self.assertEqual(m["source"]["crates"]["zkp_core"]["path"], "zkp-core")
        self.assertEqual(record_of(m, "core_tests")["core_tests"]["result_lines"][0]["passed"], 19)
        self.assertEqual(record_of(m, "core_example")["example_line"], CORE_LINE)
        json.dumps(m, allow_nan=False)

    def test_dirty_core_refuses(self):
        self.refused4("uncommitted changes under zkp-core/", lambda m: m["source"]["crates"]["zkp_core"].update(dirty_delta_sha256="ab" * 32))

    def test_missing_core_refuses(self):
        v = self.refused4("crate zkp-core/ is missing from the source tree",
                          lambda m: m["source"]["crates"]["zkp_core"].update(present=False, src=False, tree=None))
        self.assertTrue(any("no tree id" in r for r in v["reasons"]))
        self.refused4("crate hashline/ is missing", lambda m: m["source"]["crates"]["hashline"].update(present=False))

    def test_missing_lockfile_identity_refuses(self):
        self.refused4("lockfile identity missing for zkp-core/Cargo.lock", lambda m: m["source"]["lockfiles"]["zkp_core"].update(sha256=None))
        self.refused4("lockfile identity missing for hashline/Cargo.lock", lambda m: m["source"]["lockfiles"].pop("hashline"))

    def test_mismatched_dependency_identity_refuses(self):
        self.refused4("zkp-core/Cargo.lock sha256", expect_lockfiles={"zkp_core": "f" * 64})
        self.refused4("hashline/Cargo.lock sha256", expect_lockfiles={"hashline": "f" * 64, "zkp_core": "4" * 64})
        self.refused4("zkp-core/ tree", expect_trees={"zkp_core": "f" * 40})
        self.refused4("hashline/ tree", expect_trees={"hashline": "f" * 40})
        # a None expectation (the tree in hand has no such crate) is a mismatch, not a pass
        self.refused4("zkp-core/ tree", expect_trees={"zkp_core": None})

    def test_missing_core_cases_refuses(self):
        v = self.refused4("missing case core_tests", lambda m: m["cases"].remove(record_of(m, "core_tests")))
        self.refused4("missing case core_example", lambda m: m["cases"].remove(record_of(m, "core_example")))

    def test_core_test_totals_not_the_suites_refuses(self):
        self.refused4("core tests: 18 passed", lambda m: record_of(m, "core_tests")["test_results"][0].update(passed=18))
        self.refused4("core tests: 19 passed / 1 failed", lambda m: record_of(m, "core_tests")["test_results"][0].update(failed=1))
        self.refused4("/ 1 ignored", lambda m: record_of(m, "core_tests")["test_results"][1].update(ignored=1))
        self.refused4("core tests: 0 passed", lambda m: record_of(m, "core_tests").update(test_results=[]))

    def test_core_example_line_missing_refuses(self):
        self.refused4("core example: its identifying line was not recorded", lambda m: record_of(m, "core_example").update(example_line=None))

    def test_v4_without_the_identity_refuses(self):
        m = gg.synthetic_manifest(suite_version=4, head=HEAD, gpu_sha256=GPU_SHA, cpu_sha256=CPU_SHA, device=DEVICE, source_identity=None)
        v = gg.validate_manifest(m)
        self.assertFalse(v["ok"])
        self.assertTrue(any("requires the recorded source identity" in r for r in v["reasons"]), v["reasons"])
        self.assertIsNone(m["source"]["crates"])

    def test_archived_v1_to_v3_manifests_without_the_identity_still_validate(self):
        # the pre-CL21 form (results/zk60_round11_evidence/floors/manifest.json is one)
        for v in (1, 2, 3):
            m = gg.synthetic_manifest(suite_version=v, head=HEAD, gpu_sha256=GPU_SHA, cpu_sha256=CPU_SHA, device=DEVICE, source_identity=None)
            m["schema"] = 1          # as written by the round 9–11 runner
            self.assertTrue(gg.validate_manifest(m, expect_head=HEAD, expect_gpu_sha256=GPU_SHA, require_production=True)["ok"], v)
            # ... but such a manifest cannot be BOUND to a tree: nothing recorded to compare
            r = gg.validate_manifest(m, expect_trees={"hashline": "1" * 40, "zkp_core": "2" * 40})
            self.assertFalse(r["ok"])
            self.assertTrue(any("cannot bind" in x for x in r["reasons"]), r["reasons"])
        # and whenever the identity IS recorded at an old suite version, it is validated
        m = green(suite_version=3, mutate=lambda m: m["source"]["crates"]["zkp_core"].update(dirty_delta_sha256="ab" * 32))
        self.assertFalse(gg.validate_manifest(m)["ok"])

    def test_the_round11_archived_manifest_validates_and_cannot_be_bound(self):
        path = os.path.join(_R11, "floors", "manifest.json")
        if not os.path.isfile(path):
            self.skipTest("round-11 evidence not present")
        m = gg.load_manifest(path)
        self.assertEqual((m["schema"], m["suite_version"]), (1, 3))
        self.assertTrue(gg.validate_manifest(m, require_production=True)["ok"])
        self.assertFalse(gg.validate_manifest(m, expect_trees={"zkp_core": "2" * 40})["ok"])


class Parsers(unittest.TestCase):
    """[ZK60-CL21] the core-test and example log parsers."""

    def test_core_test_log_valid_is_the_round11_log(self):
        path = os.path.join(_R11, "core_tests.log")
        if not os.path.isfile(path):
            self.skipTest("round-11 evidence not present")
        with open(path, encoding="utf-8") as fh:
            t = gg.parse_core_test_log(fh.read())
        self.assertEqual((t["passed"], t["failed"], t["ignored"], t["all_ok"]), (19, 0, 0, True))
        self.assertEqual(len(t["result_lines"]), 2)      # the lib suite and the example's zero-test binary
        self.assertFalse(t["panicked"])

    def test_core_test_log_synthetic_and_totals_are_summed(self):
        case = gg.case_definition(4, "core_tests")
        log = gg.synthetic_log(case, gg.synthetic_manifest(suite_version=4, finalize=False))
        t = gg.parse_core_test_log(log)
        self.assertEqual((t["passed"], t["failed"], t["ignored"], t["all_ok"]), (19, 0, 0, True))
        # a doc-test section with its own zero line changes nothing; a second passing suite changes the total
        self.assertEqual(gg.parse_core_test_log(log + "test result: ok. 1 passed; 0 failed; 0 ignored\n")["passed"], 20)

    def test_core_test_log_empty_failed_ignored(self):
        e = gg.parse_core_test_log("")
        self.assertEqual((e["passed"], e["all_ok"], e["result_lines"]), (0, False, []))
        self.assertFalse(gg.parse_core_test_log(None)["all_ok"])
        f = gg.parse_core_test_log("running 19 tests\ntest x ... FAILED\ntest result: FAILED. 18 passed; 1 failed; 0 ignored; 0 measured\n")
        self.assertEqual((f["passed"], f["failed"], f["all_ok"]), (18, 1, False))
        i = gg.parse_core_test_log("test result: ok. 18 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out\n")
        self.assertEqual((i["passed"], i["ignored"], i["all_ok"]), (18, 1, True))
        # the old two-field form still parses (ignored defaults to 0)
        self.assertEqual(gg.parse_core_test_log("test result: ok. 3 passed; 0 failed\n")["result_lines"], [{"ok": True, "passed": 3, "failed": 0, "ignored": 0}])
        p = gg.parse_core_test_log("thread 'main' panicked at 'x'\n")
        self.assertTrue(p["panicked"])

    def test_core_example_log(self):
        path = os.path.join(_R11, "core_example.log")
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as fh:
                self.assertTrue(gg.parse_core_example_log(fh.read())["line_present"])
        self.assertTrue(gg.parse_core_example_log("   Compiling x\n" + CORE_LINE + "\n")["line_present"])
        self.assertFalse(gg.parse_core_example_log("")["line_present"])
        self.assertFalse(gg.parse_core_example_log(None)["line_present"])
        self.assertFalse(gg.parse_core_example_log(CORE_LINE[:-5] + "\n")["line_present"])          # a prefix is not the line
        self.assertFalse(gg.parse_core_example_log("x " + CORE_LINE + "\n")["line_present"])         # nor a line containing it
        self.assertTrue(gg.parse_core_example_log("other\n", line="other")["line_present"])


class SourceIdentityProbe(unittest.TestCase):
    """[ZK60-CL21] `probe_source_identity` and `init --repo` on a real temp checkout."""

    def setUp(self):
        self.root = tempfile.TemporaryDirectory()
        self.addCleanup(self.root.cleanup)
        self.repo = make_checkout(os.path.join(self.root.name, "repo with space"))

    def cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = gg.main(list(argv))
        return code, out.getvalue() + err.getvalue()

    def test_probe_reads_both_crates(self):
        ident = gg.probe_source_identity(self.repo)
        self.assertEqual(ident["head"], git(self.repo, "rev-parse", "HEAD"))
        self.assertEqual(ident["crates"]["hashline"]["tree"], git(self.repo, "rev-parse", "HEAD:hashline"))
        self.assertEqual(ident["crates"]["zkp_core"]["tree"], git(self.repo, "rev-parse", "HEAD:zkp-core"))
        for name in ("hashline", "zkp_core"):
            self.assertEqual(ident["crates"][name]["dirty_delta_sha256"], gg.EMPTY_SHA256)
            self.assertTrue(ident["crates"][name]["present"])
            lock = os.path.join(self.repo, gg.CRATES[name], "Cargo.lock")
            self.assertEqual(ident["lockfiles"][name], {"path": f"{gg.CRATES[name]}/Cargo.lock", "sha256": gg.sha256_file(lock), "size": os.stat(lock).st_size})
        self.assertEqual({k: ident["crates"]["zkp_core"][k] for k in ("manifest", "src", "example")}, {"manifest": True, "src": True, "example": True})
        self.assertEqual(ident["dirty_tracked_count"], 0)
        self.assertEqual(ident["dirty_delta_sha256"], gg.EMPTY_SHA256)
        # the CLI form prints the same document
        code, out = self.cli("source-identity", "--repo", self.repo)
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["crates"], ident["crates"])

    def test_probe_sees_a_dirty_core_and_a_missing_core(self):
        with open(os.path.join(self.repo, "zkp-core", "src", "lib.rs"), "a", encoding="utf-8") as fh:
            fh.write("// edited\n")
        ident = gg.probe_source_identity(self.repo)
        self.assertNotEqual(ident["crates"]["zkp_core"]["dirty_delta_sha256"], gg.EMPTY_SHA256)
        self.assertEqual(ident["crates"]["hashline"]["dirty_delta_sha256"], gg.EMPTY_SHA256)
        self.assertEqual(ident["dirty_tracked_count"], 1)
        # the delta hashes exactly as the runner's `git diff HEAD -- zkp-core | sha256sum`
        diff = subprocess.run(["git", "--no-pager", "-C", self.repo, "diff", "HEAD", "--", "zkp-core"], check=True, capture_output=True).stdout
        self.assertEqual(ident["crates"]["zkp_core"]["dirty_delta_sha256"], hashlib.sha256(diff).hexdigest())
        # remove the example: present flips, the tree id at HEAD stays
        os.remove(os.path.join(self.repo, "zkp-core", "examples", "public_sumcheck.rs"))
        ident = gg.probe_source_identity(self.repo)
        self.assertFalse(ident["crates"]["zkp_core"]["present"])
        self.assertFalse(ident["crates"]["zkp_core"]["example"])
        self.assertTrue(ident["crates"]["zkp_core"]["tree"])
        # a checkout that never had the core: no tree, not present, no lockfile
        bare = make_checkout(os.path.join(self.root.name, "no core"), core=False)
        ident = gg.probe_source_identity(bare)
        self.assertIsNone(ident["crates"]["zkp_core"]["tree"])
        self.assertFalse(ident["crates"]["zkp_core"]["present"])
        self.assertIsNone(ident["lockfiles"]["zkp_core"]["sha256"])
        # not a checkout at all: every fact None
        ident = gg.probe_source_identity(self.root.name)
        self.assertIsNone(ident["head"])
        self.assertIsNone(ident["crates"]["hashline"]["tree"])
        self.assertIsNone(ident["crates"]["hashline"]["dirty_delta_sha256"])

    def test_init_with_repo_records_the_identity_and_cross_checks_the_runner(self):
        head = git(self.repo, "rev-parse", "HEAD")
        out_path = os.path.join(self.root.name, "manifest.json")
        base = ["init", "--out", out_path, "--suite-version", "4", "--repo", self.repo, "--branch", "b", "--dirty-count", "0",
                "--layers", "12", "--tokens", "512", "--prover-threads", "2", "--build-jobs", "2", "--rayon-threads", "2",
                "--cpu-target-dir", "/t", "--gpu-target-dir", "/tg", "--v3-export", "/e", "--m125-export", "/m", "--cuda-root", "/c",
                "--scratch", self.root.name]
        code, out = self.cli(*base, "--head", head, "--dirty-delta-sha256", gg.EMPTY_SHA256)
        self.assertEqual(code, 0, out)
        self.assertIn("zkp-core tree", out)
        m = gg.load_manifest(out_path)
        self.assertEqual(m["schema"], 2)
        self.assertEqual(m["build"]["repo"], self.repo)
        self.assertEqual(m["source"]["crates"]["zkp_core"]["tree"], git(self.repo, "rev-parse", "HEAD:zkp-core"))
        self.assertEqual(m["source"]["lockfiles"]["hashline"]["sha256"], gg.sha256_file(os.path.join(self.repo, "hashline", "Cargo.lock")))
        # the runner's HEAD or hashline delta disagreeing with the tree is refused (the checkout moved)
        os.remove(out_path)
        code, out = self.cli(*base, "--head", "0" * 40, "--dirty-delta-sha256", gg.EMPTY_SHA256)
        self.assertEqual(code, 2)
        self.assertIn("checkout moved", out)
        self.assertFalse(os.path.exists(out_path))
        code, out = self.cli(*base, "--head", head, "--dirty-delta-sha256", "ab" * 32)
        self.assertEqual(code, 2)
        self.assertIn("the tree changed", out)
        # validate/finalize --repo bind to the tree; a lockfile edited afterwards is a mismatch
        code, _ = self.cli(*base, "--head", head, "--dirty-delta-sha256", gg.EMPTY_SHA256)
        self.assertEqual(code, 0)
        m = gg.load_manifest(out_path)
        v = gg.validate_manifest(m, expect_trees=gg.identity_expectations(gg.probe_source_identity(self.repo))[0])
        self.assertFalse(any("tree in hand" in r for r in v["reasons"]), v["reasons"])
        with open(os.path.join(self.repo, "zkp-core", "Cargo.lock"), "a", encoding="utf-8") as fh:
            fh.write("# bumped\n")
        trees, locks = gg.identity_expectations(gg.probe_source_identity(self.repo))
        v = gg.validate_manifest(m, expect_trees=trees, expect_lockfiles=locks)
        self.assertTrue(any("zkp-core/Cargo.lock sha256" in r and "lockfile in hand" in r for r in v["reasons"]), v["reasons"])
        code, out = self.cli("finalize", "--manifest", out_path, "--repo", self.repo)
        self.assertEqual(code, 1)
        self.assertIn("lockfile in hand", out)


class RoundTrip(unittest.TestCase):
    """The CLI over real files under the synthetic suite (version 0)."""

    def setUp(self):
        self.root = tempfile.TemporaryDirectory()
        self.addCleanup(self.root.cleanup)
        self.sp = os.path.join(self.root.name, "scratch dir")
        os.mkdir(self.sp)
        self.manifest = os.path.join(self.sp, "manifest.json")
        self.cpu = os.path.join(self.root.name, "cpu-hashline")
        self.gpu = os.path.join(self.root.name, "gpu-hashline")
        for p, blob in ((self.cpu, b"cpu binary"), (self.gpu, b"gpu binary")):
            with open(p, "wb") as fh:
                fh.write(blob)

    def cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = gg.main(list(argv))
        return code, out.getvalue() + err.getvalue()

    def init(self, layers=12, tokens=512, suite="0"):
        return self.cli("init", "--out", self.manifest, "--suite-version", suite, "--head", HEAD, "--branch", "zk60-cl1",
                        "--dirty-count", "0", "--dirty-delta-sha256", gg.EMPTY_SHA256, "--layers", str(layers), "--tokens", str(tokens),
                        "--prover-threads", "2", "--build-jobs", "2", "--rayon-threads", "2", "--cpu-target-dir", "/r/t",
                        "--gpu-target-dir", "/r/tg", "--v3-export", "/e", "--m125-export", "/m", "--cuda-root", "/c",
                        "--scratch", self.sp, "--device-selection", "", "--nvidia-smi", "synthetic, 000")

    def run_case(self, case, manifest, proof_blob=None, exit_code=None, log_text=None):
        cid = case["id"]
        code, _ = self.cli("start", "--manifest", self.manifest, "--case", cid)
        self.assertEqual(code, 0, cid)
        log = os.path.join(self.sp, cid + ".out")
        with open(log, "w", encoding="utf-8") as fh:
            fh.write(log_text if log_text is not None else gg.synthetic_log(case, manifest, device=DEVICE))
        argv = gg.synthetic_argv(case, manifest, binary_path=self.gpu if case.get("binary") == "gpu" else self.cpu)
        extra = []
        if case["kind"] in ("byte_gate", "cache"):
            proof = os.path.join(self.sp, cid + ".proof")
            with open(proof, "wb") as fh:
                fh.write(proof_blob if proof_blob is not None else gg.SYNTHETIC_PROOF[case["profile"]])
            extra += ["--proof", proof]
        if case.get("binary"):
            extra += ["--binary-role", case["binary"], "--binary-path", self.gpu if case["binary"] == "gpu" else self.cpu]
        ec = exit_code if exit_code is not None else (101 if case["exit"] == "nonzero" else case["exit"])
        return self.cli("record", "--manifest", self.manifest, "--case", cid, "--exit", str(ec), "--log", log, *extra, "--", *argv)

    def test_full_round_trip_is_green_and_validates(self):
        code, out = self.init()
        self.assertEqual(code, 0, out)
        self.assertIn("frozen", out)
        code, out = self.cli("binaries", "--manifest", self.manifest, "--cpu", self.cpu, "--gpu", self.gpu)
        self.assertEqual(code, 0, out)
        self.assertIn(hashlib.sha256(b"gpu binary").hexdigest(), out)
        m = gg.load_manifest(self.manifest)
        for case in gg.suite(0)["cases"]:
            code, out = self.run_case(case, m)
            self.assertEqual(code, 0, f"{case['id']}: {out}")
            self.assertIn("CASE OK", out)
        code, out = self.cli("finalize", "--manifest", self.manifest)
        self.assertEqual(code, 0, out)
        self.assertIn("MANIFEST GREEN", out)
        code, out = self.cli("validate", self.manifest, "--expect-head", HEAD,
                             "--expect-gpu-sha256", hashlib.sha256(b"gpu binary").hexdigest(), "--expect-device", DEVICE)
        self.assertEqual(code, 0, out)
        m = gg.load_manifest(self.manifest)
        self.assertTrue(m["verdict"]["green"])
        self.assertEqual(len(m["cases"]), 23)       # [CL21] the synthetic suite mirrors v4: the two core cases included
        self.assertEqual(m["started"], {})
        self.assertEqual(record_of(m, "core_tests")["core_tests"]["passed"], 2)
        self.assertEqual(record_of(m, "core_example")["example_line"], CORE_LINE)
        self.assertIsNone(m["source"]["crates"])    # no --repo: the synthetic suite does not require the identity
        rec = record_of(m, "gpu-zkv3")
        self.assertEqual(rec["binary_sha256"], hashlib.sha256(b"gpu binary").hexdigest())
        self.assertTrue(rec["log"]["path"].startswith(self.sp))
        self.assertEqual(rec["log"]["sha256"], gg.sha256_file(rec["log"]["path"]))
        self.assertTrue(rec["started_at"] and rec["ended_at"])
        self.assertEqual(m["device"]["oracle_label"], DEVICE)
        self.assertEqual(record_of(m, "cache_warm_zkv3")["wcache"]["hits"], 12)
        # the synthetic suite is never production evidence
        code, _ = self.cli("validate", self.manifest, "--require-production")
        self.assertEqual(code, 1)
        # a second init must not overwrite
        code, out = self.init()
        self.assertEqual(code, 2)
        self.assertIn("refusing to overwrite", out)

    def test_wrong_proof_bytes_fail_the_record_and_the_verdict(self):
        self.init()
        self.cli("binaries", "--manifest", self.manifest, "--cpu", self.cpu, "--gpu", self.gpu)
        m = gg.load_manifest(self.manifest)
        for case in gg.suite(0)["cases"]:
            if case["id"] == "cpu-v2":
                code, out = self.run_case(case, m, proof_blob=b"not the proof")
                self.assertEqual(code, 1)
                self.assertIn("frozen_digest", out)
            else:
                self.assertEqual(self.run_case(case, m)[0], 0, case["id"])
        code, out = self.cli("finalize", "--manifest", self.manifest)
        self.assertEqual(code, 1)
        self.assertIn("MANIFEST RED", out)
        self.assertIn("cpu-v2", out)
        self.assertEqual(self.cli("validate", self.manifest)[0], 1)

    def test_incomplete_run_is_red(self):
        self.init()
        self.cli("binaries", "--manifest", self.manifest, "--cpu", self.cpu, "--gpu", self.gpu)
        m = gg.load_manifest(self.manifest)
        cases = gg.suite(0)["cases"]
        for case in cases[:-1]:
            self.assertEqual(self.run_case(case, m)[0], 0, case["id"])
        self.assertEqual(self.cli("start", "--manifest", self.manifest, "--case", cases[-1]["id"])[0], 0)
        code, out = self.cli("finalize", "--manifest", self.manifest)
        self.assertEqual(code, 1)
        self.assertIn("started but never recorded", out)
        self.assertIn("missing case cache_p3_refusal", out)

    def test_record_needs_start_and_refuses_duplicates(self):
        self.init()
        self.cli("binaries", "--manifest", self.manifest, "--cpu", self.cpu, "--gpu", self.gpu)
        m = gg.load_manifest(self.manifest)
        case = gg.case_definition(0, "build_cpu")
        log = os.path.join(self.sp, "build_cpu.out")
        with open(log, "w", encoding="utf-8") as fh:
            fh.write(gg.synthetic_log(case, m))
        code, out = self.cli("record", "--manifest", self.manifest, "--case", "build_cpu", "--exit", "0", "--log", log, "--", "cargo", "build")
        self.assertEqual(code, 2)
        self.assertIn("was not started", out)
        self.assertEqual(self.run_case(case, m)[0], 0)
        code, out = self.cli("start", "--manifest", self.manifest, "--case", "build_cpu")
        self.assertEqual(code, 2)
        self.assertIn("already recorded", out)
        code, out = self.cli("start", "--manifest", self.manifest, "--case", "nonsense")
        self.assertEqual(code, 2)
        self.assertIn("not in suite version 0", out)

    def test_failure_modes_of_single_records(self):
        self.init()
        self.cli("binaries", "--manifest", self.manifest, "--cpu", self.cpu, "--gpu", self.gpu)
        m = gg.load_manifest(self.manifest)
        # a GPU gate whose log shows no device
        case = gg.case_definition(0, "gpu-v2")
        log = gg.synthetic_log(case, m).replace(DEVICE, "gpu: off (no device)")
        code, out = self.run_case(case, m, log_text=log)
        self.assertEqual(code, 1)
        self.assertIn("gpu_on", out)
        # a nonzero prover exit
        code, out = self.run_case(gg.case_definition(0, "cpu-v3"), m, exit_code=139)
        self.assertEqual(code, 1)
        self.assertIn("exit 139", out)
        # the control that passed instead of refusing
        code, out = self.run_case(gg.case_definition(0, "nofeature_required_refuses"), m, exit_code=0)
        self.assertEqual(code, 1)
        self.assertIn("nonzero required", out)
        # the oracle with zero cases
        case = gg.case_definition(0, "oracle_gpu")
        code, out = self.run_case(case, m, log_text=gg.synthetic_log(case, m, device=DEVICE, executed=0))
        self.assertEqual(code, 1)
        self.assertIn("zero-case", out)
        # the warm cache run with no hits
        case = gg.case_definition(0, "cache_warm_zkv3")
        code, out = self.run_case(case, m, log_text=gg.synthetic_log(case, m).replace("hits 12 | misses 0", "hits 0 | misses 12"))
        self.assertEqual(code, 1)
        self.assertIn("wcache_warm", out)
        # the P3 refusal that printed a proof
        case = gg.case_definition(0, "cache_p3_refusal")
        code, out = self.run_case(case, m, log_text="PROOF sha256 " + "00" * 32 + " (5 B)\nPASS-V3 ACCEPT [ZK]\n", exit_code=0)
        self.assertEqual(code, 1)
        self.assertIn("refusal_first", out)
        # a stale proof (older than the case's start)
        case = gg.case_definition(0, "cpu-zk")
        self.assertEqual(self.cli("start", "--manifest", self.manifest, "--case", "cpu-zk")[0], 0)
        m = gg.load_manifest(self.manifest)
        log = os.path.join(self.sp, "cpu-zk.out")
        proof = os.path.join(self.sp, "cpu-zk.proof")
        with open(log, "w", encoding="utf-8") as fh:
            fh.write(gg.synthetic_log(case, m))
        with open(proof, "wb") as fh:
            fh.write(gg.SYNTHETIC_PROOF["zk"])
        os.utime(proof, (time.time() - 3600, time.time() - 3600))
        code, out = self.cli("record", "--manifest", self.manifest, "--case", "cpu-zk", "--exit", "0", "--log", log, "--proof", proof,
                             "--binary-role", "cpu", "--binary-path", self.cpu, "--", *gg.synthetic_argv(case, m, self.cpu))
        self.assertEqual(code, 1)
        self.assertIn("proof_fresh", out)

    def test_non_frozen_shape_records_no_expectation(self):
        code, out = self.init(layers=4, tokens=256)
        self.assertEqual(code, 0)
        self.assertIn("NOT the frozen shape", out)
        self.cli("binaries", "--manifest", self.manifest, "--cpu", self.cpu, "--gpu", self.gpu)
        m = gg.load_manifest(self.manifest)
        code, out = self.run_case(gg.case_definition(0, "cpu-v2"), m)
        self.assertEqual(code, 1)
        self.assertIn("no_frozen_expectation", out)

    def test_core_record_failure_modes(self):
        # [CL21] a failed suite, an ignored test, a missing example line, and argv
        # that does not name the core's manifest or carry --locked all fail the record
        self.init()
        self.cli("binaries", "--manifest", self.manifest, "--cpu", self.cpu, "--gpu", self.gpu)
        m = gg.load_manifest(self.manifest)
        ct = gg.case_definition(0, "core_tests")
        good = gg.synthetic_log(ct, m)
        code, out = self.run_case(ct, m, log_text=good.replace("test result: ok. 2 passed; 0 failed; 0 ignored", "test result: FAILED. 1 passed; 1 failed; 0 ignored"))
        self.assertEqual(code, 1)
        self.assertIn("core_test_totals", out)
        self.assertIn("1 passed / 1 failed", out)
        ce = gg.case_definition(0, "core_example")
        code, out = self.run_case(ce, m, log_text="    Finished `release`\n     Running `x`\n")
        self.assertEqual(code, 1)
        self.assertIn("example_output", out)
        # the argv bindings, through the CLI with hand-built argv
        for cid, case, argv, needle in (
                ("core_tests", ct, ["cargo", "test", "--release", "--locked", "--manifest-path", "/r/hashline/Cargo.toml"], "argv_core_manifest"),
                ("core_example", ce, ["cargo", "run", "--release", "--manifest-path", "/r/zkp-core/Cargo.toml", "--example", "public_sumcheck"], "argv_locked")):
            sp2 = os.path.join(self.root.name, "sp2 " + cid)
            os.makedirs(sp2, exist_ok=True)
            man = os.path.join(sp2, "manifest.json")
            self.cli("init", "--out", man, "--suite-version", "0", "--head", HEAD, "--branch", "b", "--dirty-count", "0",
                     "--dirty-delta-sha256", gg.EMPTY_SHA256, "--layers", "12", "--tokens", "512", "--prover-threads", "2",
                     "--build-jobs", "2", "--rayon-threads", "2", "--cpu-target-dir", "/t", "--gpu-target-dir", "/tg",
                     "--v3-export", "/e", "--m125-export", "/m", "--cuda-root", "/c", "--scratch", sp2)
            self.assertEqual(self.cli("start", "--manifest", man, "--case", cid)[0], 0)
            log = os.path.join(sp2, cid + ".out")
            with open(log, "w", encoding="utf-8") as fh:
                fh.write(gg.synthetic_log(case, gg.load_manifest(man)))
            code, out = self.cli("record", "--manifest", man, "--case", cid, "--exit", "0", "--log", log, "--", *argv)
            self.assertEqual(code, 1, out)
            self.assertIn(needle, out)
        # the example's artifact is recorded informationally when present
        case = gg.case_definition(0, "core_example")
        sp3 = os.path.join(self.root.name, "sp3")
        os.makedirs(sp3)
        man = os.path.join(sp3, "manifest.json")
        self.cli("init", "--out", man, "--suite-version", "0", "--head", HEAD, "--branch", "b", "--dirty-count", "0",
                 "--dirty-delta-sha256", gg.EMPTY_SHA256, "--layers", "12", "--tokens", "512", "--prover-threads", "2",
                 "--build-jobs", "2", "--rayon-threads", "2", "--cpu-target-dir", "/t", "--gpu-target-dir", "/tg",
                 "--v3-export", "/e", "--m125-export", "/m", "--cuda-root", "/c", "--scratch", sp3)
        self.cli("start", "--manifest", man, "--case", "core_example")
        log = os.path.join(sp3, "core_example.out")
        with open(log, "w", encoding="utf-8") as fh:
            fh.write(gg.synthetic_log(case, gg.load_manifest(man)))
        art = os.path.join(sp3, "public_sumcheck")
        with open(art, "wb") as fh:
            fh.write(b"example binary")
        code, out = self.cli("record", "--manifest", man, "--case", "core_example", "--exit", "0", "--log", log, "--artifact", art,
                             "--", *gg.synthetic_argv(case, gg.load_manifest(man)))
        self.assertEqual(code, 0, out)
        rec = record_of(gg.load_manifest(man), "core_example")
        self.assertEqual(rec["artifact"]["sha256"], hashlib.sha256(b"example binary").hexdigest())
        self.assertEqual(rec["artifact"]["size"], 14)


class FloorsRunner(unittest.TestCase):
    """results/cl1_floors.sh under `bash -n` and `--dry-run` only."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.repo = os.path.join(cls.tmp.name, "repo with space")
        cls.export = os.path.join(cls.tmp.name, "export dir")
        cls.scratch = os.path.join(cls.tmp.name, "scratch dir")
        os.makedirs(cls.repo)
        os.makedirs(cls.export)
        cls.plan = os.path.join(cls.tmp.name, "plan.txt")
        cls.result = cls.dry_run(cls, "--plan", cls.plan)
        cls.lines = [l[2:] for l in cls.result.stdout.splitlines() if l.startswith("+ ")]

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def dry_run(self, *extra, env=None, scratch=None):
        e = dict(os.environ)
        for k in ("HL_FLOORS_GATES", "HL_FLOORS_THREADS", "CARGO_BUILD_JOBS", "RAYON_NUM_THREADS", "HL_FLOORS_LAYERS", "HL_FLOORS_TOKENS",
                  "CUDA_VISIBLE_DEVICES", "HL_FLOORS_REPO"):
            e.pop(k, None)
        e.update(env or {})
        argv = ["bash", _FLOORS, "--dry-run", "--repo", self.repo, "--gates", _SRC, "--v3-export", self.export, *extra,
                scratch or self.scratch]
        return subprocess.run(argv, capture_output=True, text=True, env=e)

    def first(self, predicate):
        return next(i for i, l in enumerate(self.lines) if predicate(l))

    def test_bash_syntax(self):
        self.assertEqual(subprocess.run(["bash", "-n", _FLOORS], capture_output=True).returncode, 0)

    def test_dry_run_exits_zero_and_writes_nothing_under_scratch(self):
        self.assertEqual(self.result.returncode, 0, self.result.stdout + self.result.stderr)
        self.assertFalse(os.path.exists(self.scratch), "the dry run must not create the scratch dir")
        self.assertIn("DRY RUN COMPLETE", self.result.stdout)
        self.assertIn("nothing built, nothing launched", self.result.stdout)
        self.assertTrue(os.path.isfile(self.plan))
        with open(self.plan, encoding="utf-8") as fh:
            self.assertEqual(fh.read().splitlines(), [l for l in self.lines])

    def test_every_emitted_command_survives_shell_splitting_with_spaced_paths(self):
        self.assertGreater(len(self.lines), 80)
        provers = 0
        for line in self.lines:
            toks = shlex.split(line.split(" > ")[0])
            for t in toks:
                self.assertNotIn("\\", t, line)
            if "pass" in toks:
                provers += 1
                b = toks[toks.index("pass") - 1]
                self.assertTrue(b.startswith(self.repo + "/hashline/target"), b)
                if "--export" in toks:
                    self.assertEqual(toks[toks.index("--export") + 1], self.export if "--p3" not in toks else "/nonexistent/zk60-cl13-export")
                self.assertEqual(toks[toks.index("--threads") + 1], "2")
                self.assertEqual(toks[toks.index("pass") + 1:toks.index("pass") + 3], ["12", "512"])
                self.assertIn("CARGO_BUILD_JOBS=2", toks)
                self.assertIn("RAYON_NUM_THREADS=2", toks)
            if "cargo" in toks:
                self.assertIn("CARGO_BUILD_JOBS=2", toks)
                self.assertIn("/tmp/zk-build.lock", toks)
                # [CL21] the two core steps name the core's manifest; everything else hashline's
                want = self.repo + ("/zkp-core/Cargo.toml" if "--locked" in toks else "/hashline/Cargo.toml")
                self.assertEqual(toks[toks.index("--manifest-path") + 1], want)
        # 12 byte gates + cold + warm + the P3 refusal, each emitted once as a run and once inside its `record`
        self.assertEqual(provers, 15 * 2)
        self.assertNotIn("--threads 8", self.result.stdout)
        # nothing repo-derived points at the archived checkout (the helper path is the test's own --gates)
        for needle in ("/home/victor/wt-zk60-cl1/hashline", "/home/victor/wt-zk60-cl1/results"):
            self.assertNotIn(needle, self.result.stdout)

    def test_required_order_self_test_before_build_before_hardware(self):
        selftest = self.first(lambda l: l.endswith("self-test"))
        build_cpu = self.first(lambda l: "cargo build --release --manifest-path" in l and "gpu-cuda" not in l)
        build_gpu = self.first(lambda l: "cargo build --release --features gpu-cuda" in l)
        tests = self.first(lambda l: "cargo test --release" in l and "--test-threads=2" in l and "zkp-core" not in l)
        core_tests = self.first(lambda l: "cargo test --release --locked --offline" in l and "zkp-core/Cargo.toml" in l)
        core_example = self.first(lambda l: "cargo run --release --locked --offline" in l and "--example public_sumcheck" in l)
        oracle = self.first(lambda l: "HL_GPU_REQUIRED=1" in l and "--features gpu-cuda" in l and "zk60_gpu_commit" in l)
        refusal = self.first(lambda l: "HL_GPU_REQUIRED=1" in l and "--features gpu-cuda" not in l and "zk60_gpu_commit" in l)
        gate = self.first(lambda l: " pass 12 512 " in l and "--proof-out" in l)
        cache = self.first(lambda l: "--wcache" in l)
        p3 = self.first(lambda l: "--p3 --wcache" in l)
        manifest = os.path.join(self.scratch, "manifest.json")
        finalize = self.first(lambda l: " finalize --manifest " in l and shlex.split(l)[shlex.split(l).index("--manifest") + 1] == manifest)
        self.assertLess(selftest, build_cpu)
        self.assertLess(build_cpu, build_gpu)
        self.assertLess(build_gpu, tests)
        self.assertLess(tests, core_tests)          # [CL21] the core after the hashline crate tests, before the device
        self.assertLess(core_tests, core_example)
        self.assertLess(core_example, oracle)
        self.assertLess(oracle, refusal)
        self.assertLess(refusal, gate)
        self.assertLess(gate, cache)
        self.assertLess(cache, p3)
        self.assertLess(p3, finalize)
        self.assertEqual(finalize, len(self.lines) - 1)
        # the self-test actually RAN in the dry run (it is CPU-only) and passed
        self.assertIn("gates self-test OK", self.result.stdout)
        # [CL13 follow-up] the runner announces the DEFAULT suite's expectation (v2: CL15's 141)
        expected = gg.case_definition(gg.DEFAULT_SUITE, "oracle_gpu")["expect"]["executed_cases"]
        self.assertIn(f"suite version {gg.DEFAULT_SUITE} expects {expected} executed oracle cases", self.result.stdout)

    def test_gpu_gates_carry_the_device_env_and_the_cpu_gates_do_not(self):
        gpu = [l for l in self.lines if " pass 12 512 " in l and "HL_GPU=1" in l and "record" not in l]
        cpu = [l for l in self.lines if " pass 12 512 " in l and "HL_GPU=1" not in l and "record" not in l]
        self.assertEqual(len(gpu), 8)
        self.assertEqual(len(cpu), 7)      # 4 CPU gates + cold + warm + the P3 refusal
        self.assertEqual(sum("HL_ZK_CHUNK=1" in l for l in gpu), 4)
        for l in gpu:
            self.assertIn("LD_LIBRARY_PATH=", l)
            self.assertIn("target-gpu/release/hashline", l)
        for l in cpu:
            self.assertNotIn("LD_LIBRARY_PATH=", l)
            self.assertIn("target/release/hashline", l)
        self.assertEqual(sum("HL_WCACHE_VERBOSE=1" in l and "--wcache" in l and "--zk" in l and "record" not in l for l in self.lines), 2)

    def test_manifest_lifecycle_is_emitted_for_every_case(self):
        starts = [shlex.split(l)[-1] for l in self.lines if " start --manifest " in l]
        records = [shlex.split(l.split(" -- ")[0])[shlex.split(l.split(" -- ")[0]).index("--case") + 1] for l in self.lines if " record --manifest " in l]
        self.assertEqual(starts, EXPECTED_V4)        # [CL21] the default suite is v4
        self.assertEqual(records, EXPECTED_V4)
        init = self.first(lambda l: " init --out " in l)
        self.assertLess(init, self.first(lambda l: "cargo build" in l))
        self.assertIn("--layers 12 --tokens 512", self.lines[init])
        self.assertIn("--prover-threads 2 --build-jobs 2 --rayon-threads 2", self.lines[init])
        # [CL21] init records both crates from the checkout; finalize re-binds to it
        toks = shlex.split(self.lines[init])
        self.assertEqual(toks[toks.index("--repo") + 1], self.repo)
        fin = shlex.split(self.lines[-1])
        self.assertEqual(fin[fin.index("--repo") + 1], self.repo)
        self.assertIn("finalize", fin)
        binaries = self.first(lambda l: " binaries --manifest " in l)
        self.assertLess(self.first(lambda l: "--features gpu-cuda" in l and "cargo build" in l), binaries)
        self.assertLess(binaries, self.first(lambda l: "cargo test" in l))

    def test_missing_helper_fails_before_any_build(self):
        r = self.dry_run(env={"HL_FLOORS_GATES": "/nonexistent/gates.py"}, scratch=os.path.join(self.tmp.name, "s2"))
        # env override loses to --gates on the command line; use --gates explicitly
        r = subprocess.run(["bash", _FLOORS, "--dry-run", "--repo", self.repo, "--gates", "/nonexistent/gates.py",
                            os.path.join(self.tmp.name, "s2")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("FAILURE: the gates helper does not run", r.stdout)
        self.assertNotIn("cargo build", r.stdout)
        self.assertNotIn("cargo test", r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.tmp.name, "s2")))

    def test_broken_parser_fails_before_any_build(self):
        # a Python that refuses everything stands in for a helper that does not parse
        r = subprocess.run(["bash", _FLOORS, "--dry-run", "--repo", self.repo, "--python", "/bin/false",
                            os.path.join(self.tmp.name, "s3")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 1)
        self.assertIn("FAILURE", r.stdout)
        self.assertNotIn("cargo", r.stdout.split("FAILURE")[1])
        self.assertEqual(sum("cargo build" in l for l in r.stdout.splitlines()), 0)

    def test_threads_and_shape_overrides_reach_every_prover_command(self):
        r = self.dry_run("--threads", "3", "--build-jobs", "1", "--rayon-threads", "4", "--layers", "4", "--tokens", "256",
                         "--device", "1", scratch=os.path.join(self.tmp.name, "s4"))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        lines = [l for l in r.stdout.splitlines() if l.startswith("+ ") and " pass " in l and "record" not in l]
        self.assertEqual(len(lines), 15)
        for l in lines:
            toks = shlex.split(l.split(" > ")[0])
            self.assertEqual(toks[toks.index("pass") + 1:toks.index("pass") + 3], ["4", "256"])
            self.assertEqual(toks[toks.index("--threads") + 1], "3")
            self.assertIn("CARGO_BUILD_JOBS=1", toks)
            self.assertIn("RAYON_NUM_THREADS=4", toks)
        self.assertIn("NOT the frozen shape", r.stdout)
        gpu = [l for l in lines if "HL_GPU=1" in l]
        self.assertEqual(len(gpu), 8)
        for l in gpu:
            self.assertIn("CUDA_VISIBLE_DEVICES=1", l)
        self.assertIn("--layers 4 --tokens 256", r.stdout)

    def test_env_defaults_are_honoured(self):
        r = self.dry_run(env={"HL_FLOORS_THREADS": "5", "CUDA_VISIBLE_DEVICES": "0"}, scratch=os.path.join(self.tmp.name, "s5"))
        self.assertEqual(r.returncode, 0)
        self.assertIn("--threads 5", r.stdout)
        self.assertIn("CUDA_VISIBLE_DEVICES=0", r.stdout)

    def test_usage_states_the_shape_rule(self):
        r = subprocess.run(["bash", _FLOORS, "--help"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0)
        self.assertIn("no_frozen_expectation", r.stdout)
        self.assertIn("CANNOT be green", r.stdout)
        r = subprocess.run(["bash", _FLOORS], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)

    def test_header_documents_the_lock_ownership(self):
        with open(_FLOORS, encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("OUTER heavy lock (/tmp/zk-heavy.lock) is the LAUNCHER's job", text)
        self.assertIn("NEVER wrap this script in the build lock", text)
        # both builds, the crate tests, [CL21] the two core steps, the oracle and the two controls take the build lock INSIDE
        self.assertEqual(text.count("flock /tmp/zk-build.lock"), 8)
        self.assertEqual(sum("/tmp/zk-build.lock" in l for l in self.lines if "cargo" in l and " record " not in l), 8)
        self.assertNotIn("zk-heavy.lock", " ".join(self.lines))   # the heavy lock is never taken here
        # `--threads 8` survives only in the history comment that says it was removed
        self.assertEqual([l for l in text.splitlines() if "--threads 8" in l and not l.lstrip().startswith("#")], [])
        self.assertNotIn("ORACLE_MIN_CASES", text)
        self.assertIn('"${SUMMARY:-"{}"}"', text)
        self.assertIn('"${SELFTEST:-"{}"}"', text)

    # ------------------------------------------------------------- [CL21]
    def test_core_commands_are_emitted_with_quoted_paths_locked_and_offline(self):
        core = [l for l in self.lines if "zkp-core/Cargo.toml" in l and " record " not in l]
        self.assertEqual(len(core), 2)
        test_toks = shlex.split(core[0].split(" > ")[0])
        run_toks = shlex.split(core[1].split(" > ")[0])
        for toks in (test_toks, run_toks):
            self.assertEqual(toks[toks.index("--manifest-path") + 1], self.repo + "/zkp-core/Cargo.toml")
            self.assertIn("--locked", toks)
            self.assertIn("--offline", toks)
            self.assertIn("--release", toks)
            self.assertEqual(toks[:5], ["env", "CARGO_BUILD_JOBS=2", "RAYON_NUM_THREADS=2", "flock", "/tmp/zk-build.lock"])
        self.assertEqual(test_toks[test_toks.index("cargo") + 1], "test")
        self.assertEqual(test_toks[-2:], ["--", "--test-threads=2"])
        self.assertEqual(run_toks[run_toks.index("cargo") + 1], "run")
        self.assertEqual(run_toks[run_toks.index("--example") + 1], "public_sumcheck")
        # the retained per-case logs, `printf %q`-quoted (a space survives the shell split)
        self.assertEqual(shlex.split(core[0].split(" > ")[1]), [os.path.join(self.scratch, "core_tests.out"), "2>&1"])
        self.assertEqual(shlex.split(core[1].split(" > ")[1]), [os.path.join(self.scratch, "core_example.out"), "2>&1"])
        # the records carry the same argv and the example's artifact path
        rec = next(l for l in self.lines if " record --manifest " in l and "--case core_example" in l)
        toks = shlex.split(rec)
        self.assertEqual(toks[toks.index("--artifact") + 1], self.repo + "/zkp-core/target/release/examples/public_sumcheck")
        self.assertEqual(toks[toks.index("--") + 1:], run_toks)
        self.assertIn("zkp-core cases: core_tests + core_example", self.result.stdout)

    def test_dry_run_reports_both_crates_identity(self):
        # read-only in the dry run; on a non-checkout every fact is absent and said so
        out = self.result.stdout
        self.assertIn("hashline/  tree <none>", out)
        self.assertIn("zkp-core/  tree <none>", out)
        self.assertIn("present 0 (Cargo.toml + src/ + examples/public_sumcheck.rs)", out)
        self.assertIn("Cargo.lock sha256 <missing>", out)
        self.assertIn("identity -> builds -> tests -> zkp-core -> oracle", out)
        self.assertNotIn("FAILURE", out)

    def test_suite_v3_dry_run_has_no_core_cases_but_records_the_identity(self):
        r = self.dry_run("--suite-version", "3", scratch=os.path.join(self.tmp.name, "s6"))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        lines = [l[2:] for l in r.stdout.splitlines() if l.startswith("+ ")]
        self.assertEqual([shlex.split(l)[-1] for l in lines if " start --manifest " in l], EXPECTED_V1)
        self.assertEqual([l for l in lines if "zkp-core/Cargo.toml" in l], [])
        self.assertIn("zkp-core cases: none (v1-v3)", r.stdout)
        self.assertIn("none in suite version 3", r.stdout)
        init = next(l for l in lines if " init --out " in l)
        self.assertIn("--suite-version 3", init)
        self.assertIn("--repo", init)

    def test_usage_and_success_line_name_the_core(self):
        r = subprocess.run(["bash", _FLOORS, "--help"], capture_output=True, text=True)
        self.assertIn("default 4 = CL21", r.stdout)
        self.assertIn("zkp-core tests/example", r.stdout)
        with open(_FLOORS, encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("+ zkp-core tests + zkp-core example", text)
        self.assertIn("identity: hashline + zkp-core trees, both lockfiles", text)

    def test_missing_or_dirty_core_refuses_to_start_before_any_build(self):
        # NOT a dry run: a real temp checkout, the self-test runs, the identity is
        # read, and the run stops with FAILURE before any cargo command; the
        # scratch dir holds no manifest. Nothing here builds anything.
        def real_run(repo, scratch):
            e = {k: v for k, v in os.environ.items() if k not in ("HL_FLOORS_GATES", "HL_FLOORS_REPO", "HL_FLOORS_SUITE_VERSION")}
            return subprocess.run(["bash", _FLOORS, "--repo", repo, "--gates", _SRC, "--v3-export", self.export, scratch],
                                  capture_output=True, text=True, env=e, timeout=120)
        cases = {}
        cases["missing core"] = (make_checkout(os.path.join(self.tmp.name, "nc repo"), core=False), "the extracted core is missing or incomplete")
        dirty = make_checkout(os.path.join(self.tmp.name, "dc repo"))
        with open(os.path.join(dirty, "zkp-core", "src", "lib.rs"), "a", encoding="utf-8") as fh:
            fh.write("// edited\n")
        cases["dirty core"] = (dirty, "uncommitted changes under zkp-core/")
        dirty_hl = make_checkout(os.path.join(self.tmp.name, "dh repo"))
        with open(os.path.join(dirty_hl, "hashline", "src", "main.rs"), "a", encoding="utf-8") as fh:
            fh.write("// edited\n")
        cases["dirty hashline"] = (dirty_hl, "uncommitted changes under hashline/")
        cases["not a checkout"] = (os.path.join(self.tmp.name, "plain dir"), "is not a git checkout")
        os.makedirs(cases["not a checkout"][0])
        for name, (repo, needle) in cases.items():
            scratch = os.path.join(self.tmp.name, "real " + name)
            r = real_run(repo, scratch)
            self.assertEqual(r.returncode, 1, f"{name}: {r.stdout}{r.stderr}")
            self.assertIn("FAILURE: " if name == "not a checkout" else "FAILURE: " + needle[:20], r.stdout, name)
            self.assertIn(needle, r.stdout, name)
            self.assertIn("gates self-test OK", r.stdout, name)
            self.assertNotIn("cargo", r.stdout.split("=== source identity ===")[1], name)
            self.assertFalse(os.path.exists(os.path.join(scratch, "manifest.json")), name)
            if name != "not a checkout":
                self.assertIn("nothing was built", r.stdout, name)
        # a clean two-crate checkout passes the identity gate: the FIRST command after it is the manifest init
        # (the init runs for real — it only reads the checkout — and then cargo build would follow; we stop
        # the run there by pointing cargo at nothing: PATH without cargo makes build_cpu fail, after init)
        clean = make_checkout(os.path.join(self.tmp.name, "ok repo"))
        scratch = os.path.join(self.tmp.name, "real ok")
        e = {k: v for k, v in os.environ.items() if k not in ("HL_FLOORS_GATES", "HL_FLOORS_REPO", "HL_FLOORS_SUITE_VERSION")}
        e["PATH"] = os.pathsep.join(p for p in e.get("PATH", "").split(os.pathsep) if not os.path.isfile(os.path.join(p, "cargo")))
        r = subprocess.run(["bash", _FLOORS, "--repo", clean, "--gates", _SRC, "--v3-export", self.export, scratch],
                           capture_output=True, text=True, env=e, timeout=120)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("present 1", r.stdout)
        self.assertNotIn("nothing was built", r.stdout)
        self.assertIn("FAILURE: build_cpu", r.stdout)
        m = gg.load_manifest(os.path.join(scratch, "manifest.json"))
        self.assertEqual(m["source"]["crates"]["zkp_core"]["tree"], git(clean, "rev-parse", "HEAD:zkp-core"))
        self.assertEqual(m["source"]["head"], git(clean, "rev-parse", "HEAD"))
        self.assertEqual(m["suite_version"], 4)


if __name__ == "__main__":
    unittest.main()

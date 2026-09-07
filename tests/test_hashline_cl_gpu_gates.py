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
HEAD, GPU_SHA, CPU_SHA = "0123abcd", "ab" * 32, "ee" * 32
DEVICE = "gpu: ON — synthetic device (sm_00, 1 SMs, 0.0 GB)"


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
        v1, v2 = gg.suite(1), gg.suite(2)
        self.assertEqual(gg.DEFAULT_SUITE, 2)
        self.assertEqual(gg.case_definition(1, "oracle_gpu")["expect"]["executed_cases"], 49)
        self.assertEqual(gg.case_definition(2, "oracle_gpu")["expect"]["executed_cases"], 141)
        self.assertIn("6dce8a9", gg.case_definition(2, "oracle_gpu")["established"])
        self.assertEqual(gg.expected_cases(1), gg.expected_cases(2))
        self.assertTrue(v2["production"])
        for c1, c2 in zip(v1["cases"], v2["cases"]):
            if c1["id"] != "oracle_gpu":
                self.assertEqual(c1, c2, c1["id"])
        # 49 is now a REFUSAL against the default suite, 141 passes
        with self.assertRaisesRegex(gg.GatesError, "49 != the suite's expected 141"):
            gg.parse_oracle_summary(GOOD, gg.case_definition(gg.DEFAULT_SUITE, "oracle_gpu")["expect"]["executed_cases"])
        self.assertEqual(gg.parse_oracle_summary(GOOD.replace('"executed_cases":49', '"executed_cases":141'), 141)["executed_cases"], 141)

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
        self.assertEqual(len(m["cases"]), 21)
        self.assertEqual(m["started"], {})
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
                self.assertEqual(toks[toks.index("--manifest-path") + 1], self.repo + "/hashline/Cargo.toml")
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
        tests = self.first(lambda l: "cargo test --release" in l and "--test-threads=2" in l)
        oracle = self.first(lambda l: "HL_GPU_REQUIRED=1" in l and "--features gpu-cuda" in l and "zk60_gpu_commit" in l)
        refusal = self.first(lambda l: "HL_GPU_REQUIRED=1" in l and "--features gpu-cuda" not in l and "zk60_gpu_commit" in l)
        gate = self.first(lambda l: " pass 12 512 " in l and "--proof-out" in l)
        cache = self.first(lambda l: "--wcache" in l)
        p3 = self.first(lambda l: "--p3 --wcache" in l)
        manifest = os.path.join(self.scratch, "manifest.json")
        finalize = self.first(lambda l: " finalize --manifest " in l and shlex.split(l)[-1] == manifest)
        self.assertLess(selftest, build_cpu)
        self.assertLess(build_cpu, build_gpu)
        self.assertLess(build_gpu, tests)
        self.assertLess(tests, oracle)
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
        self.assertEqual(starts, EXPECTED_V1)
        self.assertEqual(records, EXPECTED_V1)
        init = self.first(lambda l: " init --out " in l)
        self.assertLess(init, self.first(lambda l: "cargo build" in l))
        self.assertIn("--layers 12 --tokens 512", self.lines[init])
        self.assertIn("--prover-threads 2 --build-jobs 2 --rayon-threads 2", self.lines[init])
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
        # both builds, the crate tests, the oracle and the two controls take the build lock INSIDE
        self.assertEqual(text.count("flock /tmp/zk-build.lock"), 6)
        self.assertEqual(sum("/tmp/zk-build.lock" in l for l in self.lines if "cargo" in l and " record " not in l), 6)
        self.assertNotIn("zk-heavy.lock", " ".join(self.lines))   # the heavy lock is never taken here
        # `--threads 8` survives only in the history comment that says it was removed
        self.assertEqual([l for l in text.splitlines() if "--threads 8" in l and not l.lstrip().startswith("#")], [])
        self.assertNotIn("ORACLE_MIN_CASES", text)
        self.assertIn('"${SUMMARY:-"{}"}"', text)
        self.assertIn('"${SELFTEST:-"{}"}"', text)


if __name__ == "__main__":
    unittest.main()

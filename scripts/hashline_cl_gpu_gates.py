#!/usr/bin/env python3
"""[ZK60-CL13] The floors suite definition, the run manifest and its validator.

`results/cl1_floors.sh` used to be its own evidence: a green substring, a
case COUNT equal to a number printed by the same script, a `.done` marker and
an mtime. Codex's round-9 review reproduced four acceptances that evidence
could not refuse (absent binary digest, unrelated binary digest, zero
expected/executed cases, flag-only full/target coverage). This module is the
replacement: a VERSIONED suite definition (which cases must run and what each
must produce), a run MANIFEST the runner writes case by case, and a VALIDATOR
whose verdict is computed, never written by hand. The preflight
(`hashline_cl_5090_preflight.py`) binds its `verified_artifact` check to a
manifest this validator accepts whose HEAD and GPU-binary digest equal the
ones it is about to use.

Stdlib only; CPU only. Nothing here builds, proves or touches a device: the
runner does, and reports each case through `start` / `record`.

Suite versions
  10 Native private attention/block, capture and row-fold regressions:
     37 core tests; 288 storage-enabled hashline tests, 2 ignored capture
     writer entry points (their explicit capture runs are separate evidence).
  9  Bound FFN regressions: storage-enabled hashline count 227.
  7  Fresh paired-mask FFN regressions: storage-enabled hashline count 218.
  8  Fresh FFN wire regressions: storage-enabled hashline count 220.
  6  Corrected typed FFN extraction: 32 core tests and 215 storage-enabled
     hashline tests. Same 24 cases and live-source requirements as v5.
  5  Round 15: 22 core tests and a separate 210-test stable-weight-storage
     case. Both crates must also have no untracked, non-ignored files.
     Live checkout binding checks HEAD, presence, deltas and untracked files,
     as well as committed trees and lockfiles; cached clean facts are insufficient.
  4  [ZK60-CL21] v3 plus the EXTRACTED CORE: `zkp-core` is a path dependency
     of hashline (hashline/Cargo.toml), so its tree, its delta and both
     Cargo.lock files are build inputs of every binary gated here. v4 adds
     two cases with tied expectations — `core_tests` (zkp-core's own
     `cargo test --release --locked --offline`, exactly 19 passed / 0 failed /
     0 ignored at round 11's c8a342f) and `core_example` (`cargo run
     --example public_sumcheck`, exit 0 and its identifying line) — and
     REQUIRES the recorded source identity of both crates (`source.crates`:
     tree id at HEAD + delta sha256 + presence; `source.lockfiles`: sha256 of
     each Cargo.lock as built). A changed zkp-core test set cuts v5.
  3  v2 with the oracle at CL18's 189 executed cases.
  2  v1 with the oracle at CL15's 141 executed cases.
  1  the CL1 floors on the frozen 12x512 fixtures: 12 byte gates
     ({v2,v3,zk,zkv3} x {cpu,gpu,gpu-zkchunk}) with their frozen full SHA-256
     and exact byte length, the device oracle (`zk60_gpu_commit.rs`, 49
     executed cases at the source this version was cut from), the two
     missing-feature controls, the CPU crate tests, both builds, and the
     three separate-process cache cases modelled on `zk60_gpu_cache.rs`
     (cold, warm with hits > 0, and the P3 + cache refusal).
  0  the synthetic self-check suite: the same case structure with tiny fixed
     byte strings standing in for proofs. `self-test` round-trips it through
     the real record/validate path before any build or hardware step; it is
     NEVER production evidence (`production: false`; the preflight refuses it).

The oracle's expected executed-case count is part of the suite version, not a
floor: a test file that gains or loses cases must cut a new version here (with
its count) or the gate goes red — which is the point (round-9: a floor of 20
would not have noticed removed cases in a 49-case suite). The same rule holds
for zkp-core's test count from v4 on.

Archived meanings are preserved: a v1–v3 manifest written before CL21 carries
no `source.crates` / `source.lockfiles` and still validates under its own
suite version; a v4 manifest without them refuses. Whenever the identity IS
recorded (any manifest the CL21 runner writes), a dirty or missing core, a
missing lockfile identity, and — when the validator is given the tree in hand
(`expect_trees` / `expect_lockfiles`, the preflight's binding) — a mismatched
crate tree or lockfile all refuse.

CLI (what the runner calls; every write is atomic, every path quoted by the caller)
  self-test                          parser + round-trip self-check; exit 0 iff sound
  expected-cases [--suite-version V] [--json | --oracle-count]
  oracle-summary --expected-cases N JSON   the ZK60_CL4_SUMMARY parse; exit 0 iff ok
  source-identity --repo DIR         [CL21] both crates' tree ids, deltas, lockfile hashes, core presence (JSON)
  init --out M [--repo DIR] ...      the manifest skeleton (identity, build config); --repo records both crates
  binaries --manifest M --cpu P --gpu P    sha256 + size of both binaries
  start --manifest M --case ID       marks a case started (an unrecorded start = incomplete)
  record --manifest M --case ID --exit N --log L [--proof P] [--artifact A] [--binary-role R --binary-path P] -- ARGV...
  finalize --manifest M [--repo DIR] validates (bound to DIR's live clean source when given), writes the verdict; exit 0 iff green
  validate M [--expect-head H] [--expect-gpu-sha256 S] [--expect-device D] [--require-production] [--repo DIR]
"""

import argparse
import copy
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time

# [ZK60-CL21] schema 2 adds `source.crates` / `source.lockfiles` and the core
# cases' record fields; schema-1 manifests (round 9 – round 11) stay readable
# under their own suite versions.
SCHEMA = 2
ACCEPTED_SCHEMAS = (1, 2)
MANIFEST_KIND = "zk60-floors-run-manifest"
EMPTY_SHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
HEX_TREE = re.compile(r"^[0-9a-f]{40}([0-9a-f]{24})?$")     # a git tree id (sha1, or sha256 repos)
# The two crates whose source identifies the build inputs: hashline and the
# core it depends on (hashline/Cargo.toml: `zkp-core = { path = "../zkp-core" }`).
CRATES = {"hashline": "hashline", "zkp_core": "zkp-core"}
CORE_EXAMPLE = "public_sumcheck"
CORE_EXAMPLE_LINE = "public dot-product sumcheck verified; altered round refused (primitive example, no privacy claim)"

# The frozen 12x512 fixtures (TASK_BOARD / CL5 matrix / cl1_floors.sh as archived
# in results/cl_round7_floors.log): full SHA-256 and exact length, per profile.
FROZEN = {
    "v2":   ("50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d", 66844928),
    "v3":   ("5f368db6240e061428a90eccdb22ff456b1507708ef95f1bed39615042973c1d", 70758084),
    "zk":   ("021485e4f80ec695ddc0b05423a941e1a165c222efe12aca5bf3cd2f0d02282d", 87228528),
    "zkv3": ("40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17", 87697008),
}
# The prover flags per profile; `{v3_export}` is the runner's export directory.
PROFILE_ARGS = {
    "v2": [],
    "v3": ["--profile", "v3", "--export", "{v3_export}"],
    "zk": ["--zk", "--seed", "1"],
    "zkv3": ["--zk", "--seed", "1", "--profile", "v3", "--export", "{v3_export}"],
}
LABEL_ENV = {"cpu": {}, "gpu": {"HL_GPU": "1"}, "gpu-zkchunk": {"HL_GPU": "1", "HL_ZK_CHUNK": "1"}}
GPU_LABELS = ("gpu", "gpu-zkchunk")
FROZEN_SHAPE = (12, 512)
NOFEATURE_REASON = "built WITHOUT --features gpu-cuda"
P3_REFUSAL = "REFUSED: --wcache with --p3."
# Fixed strings for the synthetic suite (version 0): sha256 of these bytes
# stand in for the frozen proofs so the record/validate path is exercised end
# to end without a prover.
SYNTHETIC_PROOF = {p: ("zk60-cl13-synthetic-proof-" + p).encode() for p in FROZEN}


class GatesError(ValueError):
    pass


# ------------------------------------------------------------------- suites

def _byte_gate(label, profile, sha, length):
    return {"id": f"{label}-{profile}", "kind": "byte_gate", "label": label, "profile": profile,
            "binary": "cpu" if label == "cpu" else "gpu", "env": dict(LABEL_ENV[label]),
            "args": list(PROFILE_ARGS[profile]), "expect": {"sha256": sha, "bytes": length},
            "exit": 0, "verdict": "ACCEPT", "gpu_on": label in GPU_LABELS}


def _suite_v1():
    cases = [{"id": "build_cpu", "kind": "build", "exit": 0},
             {"id": "build_gpu", "kind": "build", "exit": 0},
             {"id": "cargo_test_cpu", "kind": "cargo_test", "exit": 0},
             {"id": "oracle_gpu", "kind": "oracle", "exit": 0,
              "expect": {"executed_cases": 49, "gpu_enabled": True, "gpu_required": True},
              "established": "49 executed cases on 82314a1 (results/cl_round7_floors.log); the test file is "
                             "unchanged through ac5ff0f. A changed hashline/tests/zk60_gpu_commit.rs cuts a new version."},
             {"id": "nofeature_required_refuses", "kind": "control", "exit": "nonzero", "log_contains": NOFEATURE_REASON},
             {"id": "nofeature_plain_reports_zero", "kind": "control", "exit": 0,
              "expect": {"executed_cases": 0, "gpu_enabled": False}}]
    for label in ("cpu",) + GPU_LABELS:
        for profile, (sha, length) in FROZEN.items():
            cases.append(_byte_gate(label, profile, sha, length))
    # [ZK60-CL13] The three cache cases, modelled on zk60_gpu_cache.rs (its
    # `prover()` helper runs the CPU binary: `pass 12 512 --threads 4 --profile
    # v3 --seed 1 --export <v3>` + extras, HL_GPU unset, HL_WCACHE_VERBOSE=1;
    # `--threads` does not enter the proof bytes, the runner uses its own).
    # Cold: every layer MISSes, warm: every layer HITs, both produce the frozen
    # zkv3 proof; the P3 + cache request is refused (exit 2, first stderr line
    # `REFUSED: --wcache with --p3.`) before any proof — the export it names
    # does not exist, so a refusal that came AFTER opening it would not hold.
    zkv3_sha, zkv3_len = FROZEN["zkv3"]
    cache_args = ["--zk", "--seed", "1", "--profile", "v3", "--export", "{v3_export}", "--wcache", "{wcache_dir}"]
    cases += [
        {"id": "cache_cold_zkv3", "kind": "cache", "label": "cpu", "profile": "zkv3", "binary": "cpu",
         "env": {"HL_WCACHE_VERBOSE": "1"}, "args": list(cache_args), "expect": {"sha256": zkv3_sha, "bytes": zkv3_len},
         "exit": 0, "verdict": "ACCEPT", "gpu_on": False, "wcache": "cold"},
        {"id": "cache_warm_zkv3", "kind": "cache", "label": "cpu", "profile": "zkv3", "binary": "cpu",
         "env": {"HL_WCACHE_VERBOSE": "1"}, "args": list(cache_args), "expect": {"sha256": zkv3_sha, "bytes": zkv3_len},
         "exit": 0, "verdict": "ACCEPT", "gpu_on": False, "wcache": "warm"},
        {"id": "cache_p3_refusal", "kind": "cache_refusal", "label": "cpu", "profile": "p3", "binary": "cpu", "env": {},
         "args": ["--profile", "v3", "--seed", "1", "--export", "/nonexistent/zk60-cl13-export", "--p3", "--wcache", "{wcache_dir}-p3-must-not-exist"],
         "exit": 2, "stderr_starts": P3_REFUSAL},
    ]
    return {"version": 1, "production": True, "coverage": "ffn-only", "shape": list(FROZEN_SHAPE),
            "verification": "in-memory verifier ACCEPT per pass; no decoded full-relation verification",
            "controls": ["nofeature_required_refuses", "nofeature_plain_reports_zero", "cache_p3_refusal"],
            "cases": cases}


def _suite_v4():
    """[ZK60-CL21] v3 plus the extracted core. hashline depends on zkp-core by
    path, so the core's source is a build input of every gated binary; round
    11's outer validator (results/zk60_round11_evidence/validate.py) hashed
    both crates and ran the core's tests and example, but the standalone
    floors manifest still identified hashline alone. v4 records both crates'
    identities (validated below) and gates the core with two cases whose
    expectations are the suite's: `core_tests` = 19 passed / 0 failed / 0
    ignored over every `test result:` line (results/zk60_round11_evidence/
    core_tests.log at c8a342f: field 5, merkle 1, mle 4, ntt 2, rng 2,
    sumcheck 4, transcript 1; the example's zero-test binary and the doc-test
    section add 0), `core_example` = exit 0 and the example's identifying
    line (core_example.log). Both run `--locked`: cargo refuses rather than
    rewrites zkp-core/Cargo.lock, so the lockfile the manifest hashed is the
    one that was built. A changed zkp-core test set or example cuts v5."""
    suite = copy.deepcopy(_suite_v3())
    suite["version"] = 4
    suite["requires_source_identity"] = True
    core = [
        {"id": "core_tests", "kind": "core_tests", "exit": 0, "crate": "zkp_core", "manifest_path": "zkp-core/Cargo.toml",
         "expect": {"passed": 19, "failed": 0, "ignored": 0},
         "established": ("19 passed / 0 failed / 0 ignored at c8a342f (results/zk60_round11_evidence/core_tests.log, round 11's "
                         "outer validator: field 5, merkle 1, mle 4, ntt 2, rng 2, sumcheck 4, transcript 1). The totals are summed "
                         "over every `test result:` line. A changed zkp-core test set cuts a new suite version (v5); this count does not move.")},
        {"id": "core_example", "kind": "core_example", "exit": 0, "crate": "zkp_core", "manifest_path": "zkp-core/Cargo.toml",
         "example": CORE_EXAMPLE, "expect": {"line": CORE_EXAMPLE_LINE},
         "established": ("exit 0 and this exact output line at c8a342f (results/zk60_round11_evidence/core_example.log). "
                         "A changed example cuts a new suite version.")},
    ]
    after = next(i for i, c in enumerate(suite["cases"]) if c["id"] == "cargo_test_cpu") + 1
    suite["cases"][after:after] = core
    return suite


def _suite_v5():
    s = copy.deepcopy(_suite_v4())
    s.update(version=5, requires_untracked_identity=True)
    for c in s["cases"]:
        if c["id"] == "core_tests":
            c["expect"]["passed"] = 22
            c["established"] = "Round 14 PCS extraction: 22 tests (results/zk60_round14_evidence/core_tests.log)."
    after = next(i for i, c in enumerate(s["cases"]) if c["id"] == "core_example") + 1
    s["cases"].insert(after, {
        "id": "storage_tests", "kind": "storage_tests", "exit": 0,
        "crate": "hashline", "manifest_path": "hashline/Cargo.toml", "feature": "stable-weight-storage",
        "expect": {"passed": 210, "failed": 0, "ignored": 0},
        "established": "Round 14's 197 hashline tests plus two Fable CFS, six Fable arithmetic, three CFS guard and two registration/width regressions; includes doc tests.",
    })
    return s


def _suite_v6():
    s = copy.deepcopy(_suite_v5())
    s["version"] = 6
    for c in s["cases"]:
        if c["id"] == "core_tests":
            c["expect"]["passed"] = 32
            c["established"] = "Typed FFN core and decoder corrections at 50f1ea5: 32 standalone tests."
        if c["id"] == "storage_tests":
            c["expect"]["passed"] = 215
            c["established"] = "v5's 210 plus six codec tests, minus one table registry test moved into the core."
    return s


def _suite_v7():
    s = copy.deepcopy(_suite_v6())
    s["version"] = 7
    for c in s["cases"]:
        if c["id"] == "storage_tests":
            c["expect"]["passed"] = 218
            c["established"] = "v6's 215 plus three executable paired-mask FFN repair regressions."
    return s


def _suite_v8():
    s = copy.deepcopy(_suite_v7())
    s["version"] = 8
    for c in s["cases"]:
        if c["id"] == "storage_tests":
            c["expect"]["passed"] = 220
            c["established"] = "v7's 218 plus two bounded fresh FFN wire regressions."
    return s


def _suite_v9():
    s = copy.deepcopy(_suite_v8())
    s["version"] = 9
    for c in s["cases"]:
        if c["id"] == "storage_tests":
            c["expect"]["passed"] = 227
            c["established"] = "v8's 220 plus six bound FFN regressions and one consuming-owner compile-fail doctest."
    return s


def _suite_v10():
    s = copy.deepcopy(_suite_v9())
    s["version"] = 10
    for c in s["cases"]:
        if c["id"] == "core_tests":
            c["expect"] = {"passed": 37, "failed": 0, "ignored": 0}
            c["established"] = (
                "2026-09-19 row-fold integration: 35 lib plus 2 integration tests; "
                "results/zk60_rowfold_20260919/integration/core-tests.log. Includes three exact integer-fold regressions.")
        if c["id"] == "storage_tests":
            c["expect"] = {"passed": 288, "failed": 0, "ignored": 2}
            c["established"] = (
                "2026-09-19 integrated native private profiles and captures: "
                "results/zk60_rowfold_20260919/storage-gate/storage-tests.log (includes 12 doctests). "
                "The two ignored tests are explicit native attention/block capture writers; "
                "their source-pinned, fresh-process capture validation is separate evidence. "
                "All other test results must pass; these exact counts are fixed to v10.")
    return s


def _suite_v0():
    # [ZK60-CL21] derived from the newest production suite (v10) so the synthetic
    # round trip exercises every case kind, the core's included. The synthetic
    # suite records identity when the runner gives it one but does not REQUIRE
    # it: it is never evidence and the CLI round trip runs without a checkout.
    suite = copy.deepcopy(_suite_v10())
    suite.update({"version": 0, "production": False, "requires_source_identity": False, "requires_untracked_identity": False,
                  "note": "synthetic self-check suite: tiny fixed byte strings stand in for proofs; never evidence"})
    for case in suite["cases"]:
        if case["kind"] in ("byte_gate", "cache"):
            blob = SYNTHETIC_PROOF[case["profile"]]
            case["expect"] = {"sha256": hashlib.sha256(blob).hexdigest(), "bytes": len(blob)}
        if case["id"] == "oracle_gpu":
            case["expect"]["executed_cases"] = 3
        if case["id"] in ("core_tests", "storage_tests"):
            case["expect"] = {"passed": 2, "failed": 0, "ignored": 0}
            case["established"] = "synthetic: two passing tests stand in for the core's suite"
    return suite


def _suite_v2():
    """[ZK60-CL15 -> CL13 follow-up] The oracle's expected executed-case count
    is the SUITE'S, so a changed hashline/tests/zk60_gpu_commit.rs cuts a new
    version rather than moving v1's number. CL15 (lane 6dce8a9) added the
    empty-query boundary, the allocation-scoped open probes, duplicate /
    out-of-range / ragged / below-fusion-threshold cases on every route: the
    device oracle went from 49 to 141 executed cases (31 tests) on the RTX
    4070 Laptop GPU under HL_GPU_REQUIRED=1 (results/cl15_oracle_gpu.log).
    Everything else — the 12 frozen byte gates, the controls, the cache cases —
    is unchanged from v1; CL15's own v2/zk gates at --threads 2 reproduced the
    frozen digests (results/cl15_frozen_gates.log)."""
    suite = copy.deepcopy(_suite_v1())
    suite["version"] = 2
    for case in suite["cases"]:
        if case["id"] == "oracle_gpu":
            case["expect"]["executed_cases"] = 141
            case["established"] = ("141 executed cases / 31 tests at lane 6dce8a9 (CL15: results/cl15_oracle_gpu.log, "
                                   "RTX 4070 Laptop GPU, HL_GPU_REQUIRED=1). v1's 49 was the count at 82314a1. "
                                   "A changed hashline/tests/zk60_gpu_commit.rs cuts a new version.")
    return suite


def _suite_v3():
    """[ZK60-CL18 -> CL13 follow-up] CL18 added the compact pad/scale oracle
    cases (switch ON and OFF across the routes, the width refusal, the
    allocation probes): 189 executed device cases / 34 tests on the RTX 4070
    Laptop GPU under HL_GPU_REQUIRED=1 (results/cl18_oracle.log). Everything
    else is v2's."""
    suite = copy.deepcopy(_suite_v2())
    suite["version"] = 3
    for case in suite["cases"]:
        if case["id"] == "oracle_gpu":
            case["expect"]["executed_cases"] = 189
            case["established"] = ("189 executed cases / 34 tests at the CL18 source (results/cl18_oracle.log, RTX 4070 "
                                   "Laptop GPU, HL_GPU_REQUIRED=1). v2's 141 was CL15's count at 6dce8a9; v1's 49 was 82314a1's. "
                                   "A changed hashline/tests/zk60_gpu_commit.rs cuts a new version.")
    return suite


SUITES = {10: _suite_v10(), 9: _suite_v9(), 8: _suite_v8(), 7: _suite_v7(), 6: _suite_v6(), 5: _suite_v5(), 4: _suite_v4(), 3: _suite_v3(), 2: _suite_v2(), 1: _suite_v1(), 0: _suite_v0()}
DEFAULT_SUITE = 10


def suite(version):
    try:
        return SUITES[int(version)]
    except (KeyError, ValueError, TypeError):
        raise GatesError(f"unknown suite version {version!r}; known: {sorted(SUITES)}") from None


def expected_cases(version=DEFAULT_SUITE):
    return [c["id"] for c in suite(version)["cases"]]


def case_definition(version, case_id):
    for c in suite(version)["cases"]:
        if c["id"] == case_id:
            return c
    raise GatesError(f"case {case_id!r} is not in suite version {version} (expected: {', '.join(expected_cases(version))})")


# ------------------------------------------------------------------ parsers

SUMMARY_TAG = "ZK60_CL4_SUMMARY"
_PROOF_LINE = re.compile(r"^PROOF sha256 ([0-9a-f]{64}) \((\d+) B\)", re.MULTILINE)
_GPU_ON = re.compile(r"(gpu: ON — .*)$", re.MULTILINE)
_TEST_RESULT = re.compile(r"^test result: (ok|FAILED)\. (\d+) passed; (\d+) failed(?:; (\d+) ignored)?", re.MULTILINE)
_WCACHE_REPORT = re.compile(r"wcache .*?: hits (\d+) \| misses (\d+) \| rejected (\d+)")
_WORD_ACCEPT = re.compile(r"\bACCEPT\b")
_WORD_REJECT = re.compile(r"\bREJECT\b")


def parse_oracle_summary(text, expected_cases_count=None):
    """The `ZK60_CL4_SUMMARY {...}` JSON (the payload only). Refuses empty or
    missing data, trailing garbage (the former `${SUMMARY:-{}}` extra brace
    surfaces here as "Extra data"), a boolean or non-integer count, a count
    that differs from the suite's expectation, or a disabled/unrequired device."""
    if text is None or not str(text).strip():
        raise GatesError("empty oracle summary: the suite emitted no ZK60_CL4_SUMMARY line")
    text = str(text).strip()
    if text.startswith(SUMMARY_TAG):
        text = text[len(SUMMARY_TAG):].strip()
    try:
        s = json.loads(text)
    except ValueError as error:
        raise GatesError(f"oracle summary is not valid JSON ({error}); text was: {text!r}") from None
    if not isinstance(s, dict):
        raise GatesError("oracle summary must be a JSON object")
    cases = s.get("executed_cases")
    if isinstance(cases, bool) or not isinstance(cases, int):
        raise GatesError(f"oracle summary has no integer executed_cases (got {cases!r})")
    problems = []
    if cases <= 0:
        problems.append(f"executed_cases is {cases}: a zero-case run is not evidence")
    if expected_cases_count is not None and cases != int(expected_cases_count):
        problems.append(f"executed_cases {cases} != the suite's expected {expected_cases_count}")
    if s.get("gpu_enabled") is not True:
        problems.append(f"gpu_enabled is {s.get('gpu_enabled')!r}, not true")
    if s.get("gpu_required") is not True:
        problems.append(f"gpu_required is {s.get('gpu_required')!r}, not true")
    device = s.get("device")
    if not isinstance(device, str) or not device.strip():
        problems.append("no device string")
    if problems:
        raise GatesError("; ".join(problems))
    return {"executed_cases": cases, "gpu_enabled": True, "gpu_required": True, "device": device}


def last_summary_line(text):
    hits = [line[line.index(SUMMARY_TAG) + len(SUMMARY_TAG):].strip() for line in (text or "").splitlines() if SUMMARY_TAG in line]
    return hits[-1] if hits else None


def _test_result_lines(text):
    return [{"ok": ok == "ok", "passed": int(p), "failed": int(f), "ignored": int(i or 0)}
            for ok, p, f, i in _TEST_RESULT.findall(text or "")]


def parse_core_test_log(text):
    """[ZK60-CL21] zkp-core's `cargo test` log: every `test result:` line
    (the lib unit tests, the example's zero-test binary, the doc-test section)
    with the totals summed. `all_ok` needs at least one line and every line
    `ok`; an empty log is not a passing suite. The case check compares the
    totals with the suite's tied expectation (v4: 19 / 0 / 0)."""
    lines = _test_result_lines(text)
    return {"result_lines": lines, "passed": sum(l["passed"] for l in lines), "failed": sum(l["failed"] for l in lines),
            "ignored": sum(l["ignored"] for l in lines), "all_ok": bool(lines) and all(l["ok"] for l in lines),
            "panicked": "panicked" in (text or "")}


def parse_core_example_log(text, line=CORE_EXAMPLE_LINE):
    """[ZK60-CL21] the example's identifying line, present as a whole line."""
    present = any(l.strip() == line for l in (text or "").splitlines())
    return {"line_present": present, "line": line if present else None}


def parse_prover_log(text):
    """Everything a case record needs from one retained log (stdout+stderr)."""
    text = text or ""
    verdict = None
    if _WORD_REJECT.search(text):
        verdict = "REJECT"
    elif _WORD_ACCEPT.search(text):
        verdict = "ACCEPT"
    gpu = _GPU_ON.search(text)
    proof = _PROOF_LINE.search(text)
    tests = _test_result_lines(text)
    wc = _WCACHE_REPORT.search(text)
    first = text.strip().splitlines()[0].strip() if text.strip() else ""
    return {"verdict": verdict, "gpu_on": gpu is not None, "device_label": gpu.group(1).strip() if gpu else None,
            "proof_line": {"sha256": proof.group(1), "bytes": int(proof.group(2))} if proof else None,
            "test_results": tests, "summary_line": last_summary_line(text),
            "wcache": ({"hits": int(wc.group(1)), "misses": int(wc.group(2)), "rejected": int(wc.group(3))} if wc else None),
            "wcache_verbose": {"hit_lines": text.count("wcache HIT"), "miss_lines": text.count("wcache MISS")},
            "first_line": first, "contains_nofeature_reason": NOFEATURE_REASON in text}


# ----------------------------------------------------------------- manifest

def _now():
    return time.time()


def _iso(ts):
    return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).isoformat()


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def _git(repo, *args):
    """stdout BYTES of a read-only git command, None when it fails (not a
    checkout, no such tree). Bytes, so a delta hashes exactly as the runner's
    `git diff HEAD -- <crate> | sha256sum` does."""
    try:
        r = subprocess.run(["git", "--no-pager", "-C", repo, *args], capture_output=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout if r.returncode == 0 else None


def probe_source_identity(repo):
    """[ZK60-CL21] What identifies the build inputs of BOTH crates, read from
    the checkout: HEAD, branch, the dirty tracked-file count; per crate the
    tree id at HEAD (`git rev-parse HEAD:<crate>`), the sha256 of its
    uncommitted delta (`git diff HEAD -- <crate>`; empty = e3b0c442..) and its
    presence; per crate the sha256 + size of its Cargo.lock as it is in the
    working tree (what `--locked` builds against). For the core, presence
    means Cargo.toml + src/ + the example. Missing facts are None, never
    guessed; the validator refuses them."""
    repo = os.path.abspath(repo)

    def text(out):
        return out.decode("utf-8", errors="replace").strip() if out is not None else None

    head = text(_git(repo, "rev-parse", "HEAD"))
    branch = text(_git(repo, "rev-parse", "--abbrev-ref", "HEAD"))
    status = _git(repo, "status", "--porcelain", "--untracked-files=no")
    dirty = len([l for l in status.decode("utf-8", errors="replace").splitlines() if l.strip()]) if status is not None else None
    crates, lockfiles = {}, {}
    for name, path in CRATES.items():
        diff = _git(repo, "diff", "HEAD", "--", path)
        untracked = _git(repo, "ls-files", "--others", "--exclude-standard", "-z", "--", path)
        entry = {"path": path, "tree": text(_git(repo, "rev-parse", f"HEAD:{path}")),
                 "dirty_delta_sha256": hashlib.sha256(diff).hexdigest() if diff is not None else None,
                 "untracked_paths": sorted(p.decode("utf-8", errors="replace") for p in untracked.split(b"\0") if p)
                                    if untracked is not None else None,
                 "present": os.path.isfile(os.path.join(repo, path, "Cargo.toml"))}
        if name == "zkp_core":
            layout = {"manifest": os.path.isfile(os.path.join(repo, path, "Cargo.toml")),
                      "src": os.path.isdir(os.path.join(repo, path, "src")),
                      "example": os.path.isfile(os.path.join(repo, path, "examples", CORE_EXAMPLE + ".rs"))}
            entry.update(layout)
            entry["present"] = all(layout.values())
        crates[name] = entry
        lock = os.path.join(repo, path, "Cargo.lock")
        if os.path.isfile(lock):
            lockfiles[name] = {"path": f"{path}/Cargo.lock", "sha256": sha256_file(lock), "size": os.stat(lock).st_size}
        else:
            lockfiles[name] = {"path": f"{path}/Cargo.lock", "sha256": None, "size": None}
    return {"repo": repo, "head": head, "branch": branch, "dirty_tracked_count": dirty,
            "dirty_delta_sha256": crates["hashline"]["dirty_delta_sha256"], "crates": crates, "lockfiles": lockfiles}


def identity_expectations(identity):
    """The `expect_trees` / `expect_lockfiles` a probed identity binds a
    manifest to (None entries stay None and therefore mismatch a recorded id)."""
    return ({name: (identity.get("crates") or {}).get(name, {}).get("tree") for name in CRATES},
            {name: (identity.get("lockfiles") or {}).get(name, {}).get("sha256") for name in CRATES})


def new_manifest(*, suite_version, head, branch, dirty_tracked_count, dirty_delta_sha256, layers, tokens,
                 prover_threads, cargo_build_jobs, rayon_num_threads, cpu_target_dir, gpu_target_dir, v3_export,
                 m125_export, cuda_root, scratch, device_selection=None, nvidia_smi=None, features=("gpu-cuda",),
                 created_at=None, crates=None, lockfiles=None, repo=None):
    s = suite(suite_version)
    frozen = [int(layers), int(tokens)] == s["shape"]
    return {"schema": SCHEMA, "kind": MANIFEST_KIND, "suite_version": s["version"], "suite_production": s["production"],
            "created_at": _iso(created_at if created_at is not None else _now()),
            "source": {"head": head, "branch": branch, "dirty_tracked_count": int(dirty_tracked_count),
                       "dirty_delta_sha256": dirty_delta_sha256,
                       "crates": copy.deepcopy(crates) if crates is not None else None,
                       "lockfiles": copy.deepcopy(lockfiles) if lockfiles is not None else None,
                       "note": ("HEAD identifies the build inputs only when the deltas under hashline/ AND zkp-core/ are empty "
                                "(e3b0c442..); `crates` records each crate's tree id at HEAD, its delta and its presence, "
                                "`lockfiles` the sha256 of each Cargo.lock as built (CL21)")},
            "build": {"features_gpu": list(features), "repo": repo, "cpu_target_dir": cpu_target_dir, "gpu_target_dir": gpu_target_dir,
                      "cargo_build_jobs": int(cargo_build_jobs), "rayon_num_threads": int(rayon_num_threads),
                      "prover_threads": int(prover_threads), "layers": int(layers), "tokens": int(tokens),
                      "shape_frozen": frozen, "v3_export": v3_export, "m125_export": m125_export, "cuda_root": cuda_root,
                      "scratch": scratch},
            "binaries": None,
            "device": {"selection": device_selection, "nvidia_smi": nvidia_smi, "oracle_label": None},
            "coverage": {"coverage": s["coverage"], "verification": s["verification"]},
            "started": {}, "cases": [], "verdict": None, "finalized_at": None}


def set_binaries(manifest, cpu, gpu):
    """`cpu`/`gpu` are {"path", "sha256", "size"} (the CLI hashes the files)."""
    manifest["binaries"] = {"cpu": dict(cpu), "gpu": dict(gpu)}


def binary_facts(path):
    if not os.path.isfile(path):
        raise GatesError(f"binary not found: {path}")
    return {"path": os.path.abspath(path), "sha256": sha256_file(path), "size": os.stat(path).st_size}


def start_case(manifest, case_id, at=None):
    case_definition(manifest["suite_version"], case_id)
    if any(c["id"] == case_id for c in manifest["cases"]):
        raise GatesError(f"case {case_id} is already recorded")
    manifest["started"][case_id] = at if at is not None else _now()


def _expected_shape_args(manifest):
    return ["pass", str(manifest["build"]["layers"]), str(manifest["build"]["tokens"])]


def _argv_option(argv, flag):
    argv = list(argv)
    if flag in argv:
        i = argv.index(flag)
        return argv[i + 1] if i + 1 < len(argv) else None
    return None


def build_case_record(case, manifest, *, exit_code, log_text, log_path, log_sha256, argv=(), proof=None,
                      binary_sha256=None, started_at=None, ended_at=None, proof_mtime=None, artifact=None):
    """The pure core of `record`: one case record with its per-case checks.
    `proof` is {"sha256", "bytes"} of the produced file (None when none was
    produced); `argv` is the full prover/cargo command line as executed;
    `artifact` is an informational {"path", "sha256", "size"} of a produced
    binary (the core example) with no expectation attached."""
    parsed = parse_prover_log(log_text)
    kind = case["kind"]
    checks = []
    core_tests = example_line = None

    def chk(name, ok, detail):
        checks.append({"check": name, "ok": bool(ok), "detail": detail})

    def core_argv_checks():
        # the case is bound to the CORE crate's manifest and to `--locked`
        # (cargo refuses rather than rewrites the lockfile the manifest hashed)
        want = case["manifest_path"]
        got = _argv_option(argv, "--manifest-path")
        ok = got is not None and (got.replace(os.sep, "/") == want or got.replace(os.sep, "/").endswith("/" + want))
        chk("argv_core_manifest", ok, f"--manifest-path must name {want} (argv carries {got!r})")
        chk("argv_locked", "--locked" in list(argv), "--locked required: the lockfile the manifest hashed is the one built against")

    want_exit = case["exit"]
    if want_exit == "nonzero":
        chk("exit", exit_code != 0, f"exit {exit_code} (nonzero required)")
    else:
        chk("exit", exit_code == want_exit, f"exit {exit_code} (want {want_exit})")

    expected = None
    if kind in ("byte_gate", "cache"):
        frozen = manifest["build"]["shape_frozen"]
        expected = dict(case["expect"]) if frozen else "no_frozen_expectation"
        chk("verdict", parsed["verdict"] == "ACCEPT", f"verifier verdict {parsed['verdict']}")
        if case["gpu_on"]:
            chk("gpu_on", parsed["gpu_on"], "gpu: ON observed" if parsed["gpu_on"] else
                "ran WITHOUT a device (no 'gpu: ON'); a CPU fallback is not a GPU gate")
        chk("proof_produced", proof is not None, "proof file hashed" if proof else "no proof file")
        if proof is not None and started_at is not None and proof_mtime is not None:
            chk("proof_fresh", proof_mtime >= started_at - 1.0, f"proof mtime {proof_mtime:.0f} vs start {started_at:.0f}")
        if proof is not None and parsed["proof_line"] is not None:
            chk("proof_line_matches_file", parsed["proof_line"] == proof, f"log says {parsed['proof_line']}, file is {proof}")
        if frozen:
            got = proof or {}
            chk("frozen_digest", got.get("sha256") == expected["sha256"] and got.get("bytes") == expected["bytes"],
                f"got {got.get('sha256')} / {got.get('bytes')} B, want {expected['sha256']} / {expected['bytes']} B")
        else:
            chk("frozen_digest", False, "no_frozen_expectation: the requested shape is not the frozen fixtures' shape; "
                                        "the byte expectations do not apply and the verdict cannot be green")
        shape = _expected_shape_args(manifest)
        argv = list(argv)
        chk("argv_shape", any(argv[i:i + 3] == shape for i in range(len(argv))), f"argv must contain {' '.join(shape)}: {argv}")
        need = [a for a in case["args"] if not a.startswith("{")]
        chk("argv_profile_flags", all(a in argv for a in need), f"argv must carry {need}")
        ti = argv.index("--threads") if "--threads" in argv else -1
        chk("argv_threads", ti >= 0 and argv[ti + 1:ti + 2] == [str(manifest["build"]["prover_threads"])],
            f"--threads must be {manifest['build']['prover_threads']} (the shared-laptop rule); argv carries {argv[ti + 1:ti + 2] if ti >= 0 else 'none'}")
        if kind == "cache":
            wc = parsed["wcache"]
            if case["wcache"] == "cold":
                chk("wcache_cold", wc is not None and wc["hits"] == 0 and wc["misses"] > 0,
                    f"report line {wc}; verbose {parsed['wcache_verbose']}")
            else:
                chk("wcache_warm", wc is not None and wc["hits"] > 0 and wc["misses"] == 0,
                    f"report line {wc} (hits > 0 required); verbose {parsed['wcache_verbose']}")
    elif kind == "cache_refusal":
        chk("refusal_first", parsed["first_line"].startswith(case["stderr_starts"]), f"first line: {parsed['first_line']!r}")
        chk("no_proof", proof is None and parsed["proof_line"] is None and parsed["verdict"] is None,
            "nothing proved or printed before the refusal")
    elif kind == "oracle":
        try:
            summary = parse_oracle_summary(parsed["summary_line"], case["expect"]["executed_cases"])
            chk("oracle_summary", True, summary)
        except GatesError as error:
            summary = None
            chk("oracle_summary", False, str(error))
        chk("suite_results", bool(parsed["test_results"]) and all(t["ok"] for t in parsed["test_results"]),
            parsed["test_results"])
    elif kind == "control":
        if case["id"] == "nofeature_required_refuses":
            chk("refusal_reason", parsed["contains_nofeature_reason"], f"log must contain {NOFEATURE_REASON!r}")
        else:
            line = parsed["summary_line"]
            try:
                s = json.loads(line) if line else None
            except ValueError:
                s = None
            ok = (isinstance(s, dict) and s.get("executed_cases") == 0 and s.get("gpu_enabled") is False)
            chk("plain_reports_zero", ok, f"summary {s}")
    elif kind == "cargo_test":
        chk("test_results", bool(parsed["test_results"]) and all(t["ok"] for t in parsed["test_results"]),
            f"{len(parsed['test_results'])} result lines; failed suites: {sum(1 for t in parsed['test_results'] if not t['ok'])}")
    elif kind in ("core_tests", "storage_tests"):
        # [ZK60-CL21] the totals are the SUITE'S, summed over every result line
        core_tests = parse_core_test_log(log_text)
        want = case["expect"]
        expected = dict(want)
        got = (core_tests["passed"], core_tests["failed"], core_tests["ignored"])
        chk("core_test_totals", core_tests["all_ok"] and got == (want["passed"], want["failed"], want["ignored"]),
            f"{len(core_tests['result_lines'])} result line(s), every line ok: {core_tests['all_ok']}; "
            f"{got[0]} passed / {got[1]} failed / {got[2]} ignored, want {want['passed']} / {want['failed']} / {want['ignored']}")
        core_argv_checks()
        if kind == "storage_tests":
            chk("argv_storage_feature", _argv_option(argv, "--features") == case["feature"],
                "the protected-storage feature must be explicitly exercised")
            chk("argv_offline", "--offline" in argv, "offline dependency resolution required")
    elif kind == "core_example":
        ex = parse_core_example_log(log_text, case["expect"]["line"])
        example_line = ex["line"]
        expected = dict(case["expect"])
        chk("example_output", ex["line_present"], f"the example must print the line {case['expect']['line']!r}")
        chk("argv_example", _argv_option(argv, "--example") == case["example"], f"--example must be {case['example']}")
        core_argv_checks()
    elif kind == "build":
        pass
    else:
        chk("kind", False, f"unknown case kind {kind}")

    record = {"id": case["id"], "kind": kind, "label": case.get("label"), "profile": case.get("profile"),
              "binary_role": case.get("binary"), "binary_sha256": binary_sha256, "argv": list(argv), "exit": exit_code,
              "verdict": parsed["verdict"], "gpu_on": parsed["gpu_on"], "device_label": parsed["device_label"],
              "proof": proof, "expected": expected, "log": {"path": log_path, "sha256": log_sha256},
              "started_at": _iso(started_at) if started_at is not None else None,
              "ended_at": _iso(ended_at if ended_at is not None else _now()),
              "oracle_summary": parsed["summary_line"], "wcache": parsed["wcache"], "wcache_verbose": parsed["wcache_verbose"],
              "test_results": parsed["test_results"], "core_tests": core_tests, "example_line": example_line,
              "artifact": dict(artifact) if artifact else None, "checks": checks, "ok": all(c["ok"] for c in checks)}
    return record


def add_record(manifest, record):
    if any(c["id"] == record["id"] for c in manifest["cases"]):
        raise GatesError(f"duplicate case record {record['id']}")
    manifest["cases"].append(record)
    manifest["started"].pop(record["id"], None)
    if record["kind"] == "oracle" and record["ok"]:
        manifest["device"]["oracle_label"] = json.loads(record["oracle_summary"])["device"]


# ---------------------------------------------------------------- validator

def _validate_source_identity(src, s, expect_trees, expect_lockfiles, say):
    """[ZK60-CL21] The crates/lockfiles block. Absent: allowed only for a
    suite that does not require it (archived v1–v3) and only when nothing is
    to be bound. Present: both crates present, tree ids recorded, deltas
    empty, lockfile identities recorded; bound to the tree in hand when
    expectations are given."""
    crates, locks = src.get("crates"), src.get("lockfiles")
    if crates is None and locks is None:
        if s.get("requires_source_identity"):
            say(f"suite version {s['version']} requires the recorded source identity of both crates "
                "(source.crates / source.lockfiles): this manifest records none (pre-CL21 runner)")
        if expect_trees is not None or expect_lockfiles is not None:
            say("cannot bind the manifest to the tree in hand: it records no crate tree ids or lockfile identities (pre-CL21 manifest)")
        return
    crates, locks = crates or {}, locks or {}
    for name, path in CRATES.items():
        c = crates.get(name) or {}
        if not c.get("present"):
            layout = (f" (Cargo.toml {c.get('manifest')}, src {c.get('src')}, example {c.get('example')})" if name == "zkp_core" else "")
            say(f"crate {path}/ is missing from the source tree{layout}: the build inputs are incomplete")
        if not HEX_TREE.match(str(c.get("tree") or "")):
            say(f"crate {path}/ has no tree id at HEAD")
        delta = c.get("dirty_delta_sha256")
        if delta != EMPTY_SHA256 and not (name == "hashline" and delta == src.get("dirty_delta_sha256")):
            say(f"uncommitted changes under {path}/ (delta sha256 {delta}): HEAD does not identify the build inputs")
        if s.get("requires_untracked_identity") or "untracked_paths" in c:
            if c.get("untracked_paths") != []:
                say(f"untracked build inputs under {path}/: {c.get('untracked_paths')!r}; a recorded empty list is required")
        l = locks.get(name) or {}
        if not HEX64.match(str(l.get("sha256") or "")) or not l.get("path"):
            say(f"lockfile identity missing for {path}/Cargo.lock (sha256/path)")
    if (crates.get("hashline") or {}).get("dirty_delta_sha256") != src.get("dirty_delta_sha256"):
        say("source.dirty_delta_sha256 and source.crates.hashline.dirty_delta_sha256 disagree")
    for name, want in (expect_trees or {}).items():
        got = (crates.get(name) or {}).get("tree")
        if got != want:
            say(f"{CRATES.get(name, name)}/ tree {got} != the tree in hand {want}")
    for name, want in (expect_lockfiles or {}).items():
        got = (locks.get(name) or {}).get("sha256")
        if got != want:
            say(f"{CRATES.get(name, name)}/Cargo.lock sha256 {got} != the lockfile in hand {want}")


def source_identity_errors(identity):
    """Fail closed on the live inputs; never substitute cached clean facts."""
    errors = []
    if not re.fullmatch(r"[0-9a-f]{7,64}", str(identity.get("head") or "")):
        errors.append("HEAD is missing or invalid")
    if identity.get("dirty_delta_sha256") != EMPTY_SHA256:
        errors.append("uncommitted changes under hashline/")
    _validate_source_identity(identity, {"version": 5, "requires_source_identity": True,
                                        "requires_untracked_identity": True}, None, None, errors.append)
    return errors


def validate_manifest(manifest, *, expect_head=None, expect_gpu_sha256=None, expect_device=None, require_production=False,
                      expect_trees=None, expect_lockfiles=None, expect_source=None):
    """Recomputes the verdict from the records. Returns {"ok", "reasons",
    "summary"}; `ok` only when there is nothing to say. Never trusts a verdict
    the manifest carries: a stored verdict that disagrees is itself a reason.
    [CL21] `expect_trees` / `expect_lockfiles` ({"hashline": .., "zkp_core": ..})
    bind the recorded crate tree ids and lockfile hashes to the tree in hand."""
    reasons = []
    say = reasons.append
    if not isinstance(manifest, dict):
        return {"ok": False, "reasons": ["manifest is not a JSON object"], "summary": {}}
    if manifest.get("schema") not in ACCEPTED_SCHEMAS or manifest.get("kind") != MANIFEST_KIND:
        say(f"not a schema-{'/'.join(map(str, ACCEPTED_SCHEMAS))} {MANIFEST_KIND}")
        return {"ok": False, "reasons": reasons, "summary": {}}
    try:
        s = suite(manifest.get("suite_version"))
    except GatesError as error:
        return {"ok": False, "reasons": [str(error)], "summary": {}}
    if require_production and not s["production"]:
        say(f"suite version {s['version']} is not production evidence ({s.get('note', 'synthetic')})")

    src = manifest.get("source") or {}
    head = src.get("head")
    if not head or not re.match(r"^[0-9a-f]{7,64}$", str(head)):
        say("source HEAD is missing")
    if expect_head is not None and head != expect_head:
        say(f"source HEAD {head} != the current HEAD {expect_head}")
    if src.get("dirty_delta_sha256") != EMPTY_SHA256:
        say(f"uncommitted changes under hashline/ (delta sha256 {src.get('dirty_delta_sha256')}): HEAD does not identify the build inputs")
    _validate_source_identity(src, s, expect_trees, expect_lockfiles, say)
    if expect_source is not None:
        # Trees describe HEAD, not the files Cargo currently reads. Check live
        # cleanliness and layout too, including a newly added automatic build.rs.
        live_reasons = source_identity_errors(expect_source)
        reasons.extend("live checkout: " + reason for reason in live_reasons)
        if head != expect_source.get("head"):
            say(f"source HEAD {head} != live checkout HEAD {expect_source.get('head')}")
        live_trees, live_locks = identity_expectations(expect_source)
        _validate_source_identity(src, s, live_trees, live_locks, say)

    bins = manifest.get("binaries") or {}
    for role in ("cpu", "gpu"):
        b = bins.get(role) or {}
        if not HEX64.match(str(b.get("sha256") or "")) or not b.get("size") or not b.get("path"):
            say(f"{role} binary identity missing (sha256/size/path)")
    gpu_sha = (bins.get("gpu") or {}).get("sha256")
    if expect_gpu_sha256 is not None and gpu_sha != expect_gpu_sha256:
        say(f"GPU binary sha256 {gpu_sha} != the binary in hand {expect_gpu_sha256}")

    cov = manifest.get("coverage") or {}
    if cov.get("coverage") != s["coverage"]:
        say(f"coverage {cov.get('coverage')!r} is not what suite version {s['version']} covers ({s['coverage']!r})")

    build = manifest.get("build") or {}
    if not build.get("shape_frozen"):
        say(f"shape {build.get('layers')}x{build.get('tokens')} is not the frozen fixtures' {s['shape'][0]}x{s['shape'][1]}: "
            "no byte expectation applies (no_frozen_expectation)")

    expected = expected_cases(s["version"])
    records = manifest.get("cases") or []
    ids = [r.get("id") for r in records]
    seen = set()
    for i in ids:
        if i in seen:
            say(f"duplicate case record {i}")
        seen.add(i)
    for i in expected:
        if i not in seen:
            say(f"missing case {i}")
    for i in ids:
        if i not in expected:
            say(f"unexpected case {i}")
    for cid in s["controls"]:
        if cid not in seen:
            say(f"missing negative control {cid}")
    for cid in (manifest.get("started") or {}):
        say(f"case {cid} was started but never recorded (incomplete run)")

    by_id = {}
    for r in records:
        by_id.setdefault(r.get("id"), r)
    oracle = by_id.get("oracle_gpu")
    device_label = None
    if oracle:
        try:
            device_label = json.loads(oracle.get("oracle_summary") or "null")["device"]
        except (ValueError, TypeError, KeyError):
            device_label = None
    if expect_device is not None and device_label != expect_device:
        say(f"oracle device {device_label!r} != expected {expect_device!r}")
    for r in records:
        cid = r.get("id")
        if cid not in expected:
            continue
        case = case_definition(s["version"], cid)
        if not r.get("ok"):
            failed = [c["check"] for c in r.get("checks", []) if not c.get("ok")]
            say(f"case {cid} failed its checks: {', '.join(failed) or 'record not ok'}")
        want_exit = case["exit"]
        if want_exit == "nonzero":
            if r.get("exit") == 0:
                say(f"case {cid} exited 0 but must refuse")
        elif r.get("exit") != want_exit:
            say(f"case {cid} exit {r.get('exit')} != {want_exit}")
        if case.get("verdict") == "ACCEPT" and r.get("verdict") != "ACCEPT":
            say(f"case {cid} verdict {r.get('verdict')} is not ACCEPT")
        if case.get("gpu_on") and not r.get("gpu_on"):
            say(f"GPU-labelled case {cid} shows no 'gpu: ON'")
        if case.get("gpu_on") and device_label and r.get("device_label") and r["device_label"] != device_label:
            say(f"case {cid} ran on {r['device_label']!r}, the oracle on {device_label!r}")
        exp = r.get("expected")
        if case["kind"] in ("byte_gate", "cache"):
            if exp == "no_frozen_expectation" or exp is None:
                say(f"case {cid} has no frozen expectation")
            else:
                if exp != case["expect"]:
                    say(f"case {cid} records an expectation {exp} that is not the suite's {case['expect']}")
                got = r.get("proof") or {}
                if got.get("sha256") != case["expect"]["sha256"] or got.get("bytes") != case["expect"]["bytes"]:
                    say(f"case {cid} proof {got.get('sha256')} / {got.get('bytes')} B != frozen "
                        f"{case['expect']['sha256']} / {case['expect']['bytes']} B")
        if case["kind"] == "oracle":
            try:
                parse_oracle_summary(r.get("oracle_summary"), case["expect"]["executed_cases"])
            except GatesError as error:
                say(f"oracle: {error}")
        if case["kind"] in ("core_tests", "storage_tests"):
            # [CL21] recomputed from the recorded result lines, not from the record's own checks
            lines = r.get("test_results") or []
            got = tuple(sum(int(t.get(k) or 0) for t in lines) for k in ("passed", "failed", "ignored"))
            all_ok = bool(lines) and all(t.get("ok") for t in lines)
            want = case["expect"]
            if not all_ok or got != (want["passed"], want["failed"], want["ignored"]):
                label = "core tests" if case["kind"] == "core_tests" else "storage tests"
                say(f"{label}: {got[0]} passed / {got[1]} failed / {got[2]} ignored over {len(lines)} result line(s) "
                    f"(every line ok: {all_ok}) != the suite's {want['passed']} / {want['failed']} / {want['ignored']}")
        if case["kind"] == "core_example" and r.get("example_line") != case["expect"]["line"]:
            say(f"core example: its identifying line was not recorded ({r.get('example_line')!r})")
        if s["version"] >= 5 and case["kind"] in ("core_tests", "core_example", "storage_tests"):
            argv = r.get("argv") or []
            manifest_path = (_argv_option(argv, "--manifest-path") or "").replace(os.sep, "/")
            want_path = case["manifest_path"]
            if manifest_path != want_path and not manifest_path.endswith("/" + want_path):
                say(f"case {cid}: argv must name {want_path}")
            if not all(flag in argv for flag in ("--locked", "--offline")):
                say(f"case {cid}: argv requires --locked --offline")
            if case.get("feature") and _argv_option(argv, "--features") != case["feature"]:
                say(f"case {cid}: argv requires --features {case['feature']}")
            if case.get("example") and _argv_option(argv, "--example") != case["example"]:
                say(f"case {cid}: argv requires --example {case['example']}")
        role = case.get("binary")
        if role:
            want = (bins.get(role) or {}).get("sha256")
            if r.get("binary_sha256") != want:
                say(f"case {cid} ran binary {r.get('binary_sha256')} but the manifest's {role} binary is {want}")
        log = r.get("log") or {}
        if not log.get("path") or not HEX64.match(str(log.get("sha256") or "")):
            say(f"case {cid} has no retained log identity")

    if manifest.get("finalized_at") is None:
        say("manifest not finalized")
    stored = manifest.get("verdict")
    computed_green = not reasons
    if stored is None:
        say("no verdict recorded (finalize was not run)")
    elif stored.get("green") is not computed_green:
        say(f"stored verdict green={stored.get('green')} disagrees with the recomputed verdict ({computed_green}); verdicts are computed, not written")
    core = by_id.get("core_tests") or {}
    summary = {"suite_version": s["version"], "production": s["production"], "cases_recorded": len(records),
               "cases_expected": len(expected), "head": head, "gpu_binary_sha256": gpu_sha, "device": device_label,
               "oracle_executed_cases": (json.loads(oracle["oracle_summary"]).get("executed_cases")
                                         if oracle and oracle.get("oracle_summary") else None),
               "crate_trees": {name: ((src.get("crates") or {}).get(name) or {}).get("tree") for name in CRATES},
               "lockfiles": {name: ((src.get("lockfiles") or {}).get(name) or {}).get("sha256") for name in CRATES},
               "core_tests_passed": (core.get("core_tests") or {}).get("passed") if core else None}
    return {"ok": not reasons, "reasons": reasons, "summary": summary}


def finalize_manifest(manifest, at=None, expect_trees=None, expect_lockfiles=None, expect_source=None):
    """Computes the verdict on the records as they stand and stores it. The
    stored verdict is what `validate` recomputes and compares against.
    [CL21] with expectations (the runner passes the tree as re-probed at the
    end), a crate or lockfile that changed during the run makes the verdict red."""
    manifest["finalized_at"] = _iso(at if at is not None else _now())
    manifest["verdict"] = None
    probe = validate_manifest(manifest, expect_trees=expect_trees, expect_lockfiles=expect_lockfiles, expect_source=expect_source)
    reasons = [r for r in probe["reasons"] if r != "no verdict recorded (finalize was not run)"]
    manifest["verdict"] = {"green": not reasons, "reasons": reasons, "computed_by": "hashline_cl_gpu_gates.validate_manifest",
                           "summary": probe["summary"]}
    return manifest["verdict"]


# ---------------------------------------------------------------- file i/o

def load_manifest(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save_manifest(manifest, path, new=False):
    text = json.dumps(manifest, indent=2, allow_nan=False) + "\n"
    if new:
        with open(path, "x", encoding="utf-8") as fh:
            fh.write(text)
        return
    d = os.path.dirname(os.path.abspath(path)) or "."
    fd, tmp = tempfile.mkstemp(prefix=".manifest-", suffix=".tmp", dir=d)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


# ------------------------------------------------------------- self-check

def synthetic_log(case, manifest, device="gpu: ON — synthetic device (sm_00, 1 SMs, 0.0 GB)", executed=None):
    """A log in the formats the parsers read, for the case as the suite defines
    it. Used by `self-test` and the unit tests; a real run never writes one."""
    kind = case["kind"]
    if kind == "build":
        return "   Compiling hashline\n    Finished `release` profile [optimized] target(s) in 1.00s\n"
    if kind == "cargo_test":
        return "test result: ok. 59 passed; 0 failed; 0 ignored\ntest result: ok. 3 passed; 0 failed; 0 ignored\n"
    if kind == "oracle":
        n = executed if executed is not None else case["expect"]["executed_cases"]
        return (f"test result: ok. 19 passed; 0 failed; 0 ignored\n{SUMMARY_TAG} " +
                json.dumps({"executed_cases": n, "gpu_enabled": True, "gpu_required": True, "device": device}) + "\n")
    if kind == "control":
        if case["id"] == "nofeature_required_refuses":
            return ("thread 'device::zzz' panicked: HL_GPU_REQUIRED=1 but this test binary was " + NOFEATURE_REASON +
                    ": every case would be skipped\ntest result: FAILED. 0 passed; 1 failed\n")
        return (SUMMARY_TAG + ' {"executed_cases":0,"gpu_enabled":false,"gpu_required":false,"device":"built without --features gpu-cuda"}\n'
                "test result: ok. 1 passed; 0 failed; 0 ignored\n")
    if kind == "cache_refusal":
        return P3_REFUSAL + " P3 hides the weights; a cached public commitment is recoverable by linear algebra.\n"
    if kind in ("core_tests", "storage_tests"):
        n = case["expect"]["passed"]
        ignored = case["expect"]["ignored"]
        return (f"     Running unittests src/lib.rs (zkp-core/target/release/deps/zkp_core-0000)\n\nrunning {n + ignored} tests\n"
                + "".join(f"test synthetic::t{i} ... ok\n" for i in range(n))
                + "".join(f"test synthetic::ignored{i} ... ignored\n" for i in range(ignored))
                + f"\ntest result: ok. {n} passed; 0 failed; {ignored} ignored; 0 measured; 0 filtered out; finished in 0.01s\n\n"
                "   Doc-tests zkp_core\n\nrunning 0 tests\n\n"
                "test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s\n")
    if kind == "core_example":
        return ("    Finished `release` profile [optimized] target(s) in 0.05s\n"
                f"     Running `zkp-core/target/release/examples/{case['example']}`\n" + case["expect"]["line"] + "\n")
    exp = case["expect"]
    gpu_line = f"  {device}\n" if case.get("gpu_on") else "  gpu: off (built without --features gpu-cuda)\n"
    lines = [gpu_line, "  layer  0: prove 0.3 s, 100 B\n", f"PROOF sha256 {exp['sha256']} ({exp['bytes']} B)\n"]
    if kind == "cache":
        n = manifest["build"]["layers"]
        if case["wcache"] == "cold":
            lines += ["[wcache] wcache MISS -> wrote v3-l00\n" * n, f"  wcache /c: hits 0 | misses {n} | rejected 0 | read 0.0 MB\n"]
        else:
            lines += ["[wcache] wcache HIT v3-l00\n" * n, f"  wcache /c: hits {n} | misses 0 | rejected 0 | read 1.0 MB\n"]
    lines.append("PASS-V3 ACCEPT [ZK]: 12 x 512 | PROVE 1.0 s\n")
    return "".join(lines)


SYNTHETIC_SOURCE = {
    "crates": {"hashline": {"path": "hashline", "tree": "1" * 40, "dirty_delta_sha256": EMPTY_SHA256, "present": True, "untracked_paths": []},
               "zkp_core": {"path": "zkp-core", "tree": "2" * 40, "dirty_delta_sha256": EMPTY_SHA256, "present": True,
                            "manifest": True, "src": True, "example": True, "untracked_paths": []}},
    "lockfiles": {"hashline": {"path": "hashline/Cargo.lock", "sha256": "3" * 64, "size": 40000},
                  "zkp_core": {"path": "zkp-core/Cargo.lock", "sha256": "4" * 64, "size": 3465}},
}


def synthetic_argv(case, manifest, binary_path="/bin/hashline"):
    repo = manifest["build"].get("repo") or "/r"
    if case["kind"] in ("core_tests", "storage_tests"):
        return ["env", "CARGO_BUILD_JOBS=2", "RAYON_NUM_THREADS=2", "cargo", "test", "--release", "--locked", "--offline",
                "--manifest-path", f"{repo}/{case['manifest_path']}",
                *(["--features", case["feature"]] if case.get("feature") else []), "--", "--test-threads=2"]
    if case["kind"] == "core_example":
        return ["env", "CARGO_BUILD_JOBS=2", "RAYON_NUM_THREADS=2", "cargo", "run", "--release", "--locked", "--offline",
                "--manifest-path", f"{repo}/{case['manifest_path']}", "--example", case["example"]]
    if case["kind"] in ("build", "cargo_test", "oracle", "control"):
        return ["cargo", "test" if case["kind"] != "build" else "build", "--release"]
    args = [a.replace("{v3_export}", manifest["build"]["v3_export"] or "/export").replace("{wcache_dir}", "/scratch/wcache")
            for a in case["args"]]
    return [binary_path, *_expected_shape_args(manifest), "--threads", str(manifest["build"]["prover_threads"]),
            "--proof-out", "/scratch/out.proof", *args]


def synthetic_manifest(*, suite_version=0, head="0123abcd", gpu_sha256="ab" * 32, cpu_sha256="cd" * 32,
                       device="gpu: ON — synthetic device (sm_00, 1 SMs, 0.0 GB)", finalize=True, layers=None, tokens=None,
                       mutate=None, source_identity="synthetic"):
    """A complete manifest for the suite, every record built through the real
    `build_case_record` path from synthetic logs. `mutate(manifest)` runs before
    finalize so tests can break exactly one thing. Production suites get their
    frozen digests as the "produced" proof — this is a FIXTURE for validator
    tests, never evidence (nothing was proved). [CL21] `source_identity`:
    "synthetic" records SYNTHETIC_SOURCE's crates/lockfiles, None records
    nothing (an archived, pre-CL21 manifest), or a dict of your own."""
    s = suite(suite_version)
    ident = SYNTHETIC_SOURCE if source_identity == "synthetic" else source_identity
    m = new_manifest(suite_version=suite_version, head=head, branch="zk60-cl1", dirty_tracked_count=0,
                     dirty_delta_sha256=EMPTY_SHA256, layers=layers if layers is not None else s["shape"][0],
                     tokens=tokens if tokens is not None else s["shape"][1], prover_threads=2, cargo_build_jobs=2,
                     rayon_num_threads=2, cpu_target_dir="/r/hashline/target", gpu_target_dir="/r/hashline/target-gpu",
                     v3_export="/e", m125_export="/m125", cuda_root="/cuda", scratch="/scratch", device_selection=None,
                     nvidia_smi="synthetic device, 000.00", created_at=1.0, repo="/r",
                     crates=ident["crates"] if ident else None, lockfiles=ident["lockfiles"] if ident else None)
    set_binaries(m, cpu={"path": "/r/hashline/target/release/hashline", "sha256": cpu_sha256, "size": 4629656},
                 gpu={"path": "/r/hashline/target-gpu/release/hashline", "sha256": gpu_sha256, "size": 5326472})
    t = 10.0
    for case in s["cases"]:
        start_case(m, case["id"], at=t)
        log = synthetic_log(case, m, device=device)
        proof = dict(case["expect"]) if case["kind"] in ("byte_gate", "cache") and m["build"]["shape_frozen"] else None
        exit_code = 101 if case["exit"] == "nonzero" else case["exit"]
        role = case.get("binary")
        rec = build_case_record(case, m, exit_code=exit_code, log_text=log, log_path=f"/scratch/{case['id']}.out",
                                log_sha256=hashlib.sha256(log.encode()).hexdigest(), argv=synthetic_argv(case, m),
                                proof=proof, binary_sha256=(gpu_sha256 if role == "gpu" else cpu_sha256 if role == "cpu" else None),
                                started_at=t, ended_at=t + 1.0, proof_mtime=t + 0.5)
        add_record(m, rec)
        t += 2.0
    if mutate:
        mutate(m)
    if finalize:
        finalize_manifest(m, at=t)
    return m


def self_test():
    """Exit-0-or-raise: the parser on valid, empty, missing, extra-brace and
    non-ASCII input, the suite tables, and a full synthetic round trip."""
    good = '{"executed_cases":99,"gpu_enabled":true,"gpu_required":true,"device":"self-test — non-ASCII on purpose"}'
    assert parse_oracle_summary(good, 99)["executed_cases"] == 99
    for bad, why in ((good + "}", "extra brace"), ("", "empty"), ("{}", "missing fields"), (None, "None"),
                     (good.replace("99", "0"), "zero cases"), (good.replace("true", "false", 1), "gpu disabled"),
                     (good, "count 98 vs 99")):
        try:
            parse_oracle_summary(bad, 98 if why.startswith("count") else 99)
        except GatesError:
            continue
        raise GatesError(f"self-test: the parser accepted {why}")
    for v, s in SUITES.items():
        ids = expected_cases(v)
        assert len(ids) == len(set(ids)), f"suite {v} has duplicate ids"
        for c in s["cases"]:
            if "expect" in c and "sha256" in c["expect"]:
                assert HEX64.match(c["expect"]["sha256"]) and c["expect"]["bytes"] > 0, c["id"]
        assert all(cid in ids for cid in s["controls"])
    m = synthetic_manifest(suite_version=0)
    v = validate_manifest(m)
    if not v["ok"]:
        raise GatesError("self-test: the synthetic round trip is not green: " + "; ".join(v["reasons"]))
    if validate_manifest(m, require_production=True)["ok"]:
        raise GatesError("self-test: the synthetic suite passed as production")
    if validate_manifest(m, expect_head="ffff")["ok"] or validate_manifest(m, expect_gpu_sha256="00" * 32)["ok"]:
        raise GatesError("self-test: a HEAD/binary mismatch passed")
    # [CL21] the core parsers on valid / empty / failed / ignored input
    if parse_core_test_log(synthetic_log(case_definition(4, "core_tests"), m))["passed"] != 19:
        raise GatesError("self-test: the core-test parser does not sum the v4 log to 19")
    for bad, why in (("", "empty"), ("test result: FAILED. 18 passed; 1 failed; 0 ignored\n", "failed"),
                     ("test result: ok. 18 passed; 0 failed; 1 ignored\n", "ignored")):
        t = parse_core_test_log(bad)
        if t["all_ok"] and (t["passed"], t["failed"], t["ignored"]) == (19, 0, 0):
            raise GatesError(f"self-test: the core-test parser accepted {why}")
    if parse_core_example_log("")["line_present"] or not parse_core_example_log(CORE_EXAMPLE_LINE + "\n")["line_present"]:
        raise GatesError("self-test: the core-example parser is wrong")
    # [CL21] the v4 fixture round-trips green; the four refusals refuse; a
    # pre-CL21 v3 manifest still validates; v4 without the identity does not
    m4 = synthetic_manifest(suite_version=4)
    v = validate_manifest(m4)
    if not v["ok"]:
        raise GatesError("self-test: the v4 fixture is not green: " + "; ".join(v["reasons"]))
    trees, locks = identity_expectations(SYNTHETIC_SOURCE)
    if not validate_manifest(m4, expect_trees=trees, expect_lockfiles=locks)["ok"]:
        raise GatesError("self-test: the v4 fixture does not bind to its own identity")
    for why, kw in (("dirty core", dict(mutate=lambda m: m["source"]["crates"]["zkp_core"].update(dirty_delta_sha256="ab" * 32))),
                    ("missing core", dict(mutate=lambda m: m["source"]["crates"]["zkp_core"].update(present=False, src=False))),
                    ("missing core cases", dict(mutate=lambda m: m["cases"].__delitem__(next(i for i, c in enumerate(m["cases"]) if c["id"] == "core_tests")))),
                    ("no identity at v4", dict(source_identity=None))):
        if validate_manifest(synthetic_manifest(suite_version=4, **kw))["ok"]:
            raise GatesError(f"self-test: a v4 manifest with {why} passed")
    if validate_manifest(m4, expect_lockfiles={"zkp_core": "f" * 64})["ok"] or validate_manifest(m4, expect_trees={"hashline": "f" * 40})["ok"]:
        raise GatesError("self-test: a dependency identity mismatch passed")
    if not validate_manifest(synthetic_manifest(suite_version=3, source_identity=None))["ok"]:
        raise GatesError("self-test: an archived (pre-CL21) v3 manifest no longer validates")
    return {"suite_versions": sorted(SUITES), "synthetic_round_trip": "green", "cases": len(expected_cases(0)),
            "v4_round_trip": "green", "v4_cases": len(expected_cases(4))}


# -------------------------------------------------------------------- cli

def _p_manifest(sub, name, help_text):
    p = sub.add_parser(name, help=help_text)
    p.add_argument("--manifest", required=True)
    return p


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("self-test", help="parser + suite tables + synthetic round trip")
    p = sub.add_parser("expected-cases", help="case ids of a suite version")
    p.add_argument("--suite-version", type=int, default=DEFAULT_SUITE)
    p.add_argument("--json", action="store_true")
    p.add_argument("--oracle-count", action="store_true", help="print only the expected oracle executed-case count")
    p = sub.add_parser("oracle-summary", help="parse one ZK60_CL4_SUMMARY payload")
    p.add_argument("--expected-cases", type=int, required=True)
    p.add_argument("summary", nargs="?", default="")
    p = sub.add_parser("source-identity", help="[CL21] both crates' tree ids, deltas, lockfile hashes and the core's presence")
    p.add_argument("--repo", required=True)
    p = sub.add_parser("init", help="write the manifest skeleton (a new file)")
    p.add_argument("--out", required=True)
    p.add_argument("--suite-version", type=int, default=DEFAULT_SUITE)
    p.add_argument("--repo", help="[CL21] record both crates' identity from this checkout (cross-checked against --head/--dirty-delta-sha256)")
    for name in ("--head", "--branch", "--dirty-delta-sha256", "--cpu-target-dir", "--gpu-target-dir", "--v3-export",
                 "--m125-export", "--cuda-root", "--scratch"):
        p.add_argument(name, required=True)
    p.add_argument("--dirty-count", type=int, required=True)
    for name in ("--layers", "--tokens", "--prover-threads", "--build-jobs", "--rayon-threads"):
        p.add_argument(name, type=int, required=True)
    p.add_argument("--device-selection", default=None, help="CUDA_VISIBLE_DEVICES as seen by the runner")
    p.add_argument("--nvidia-smi", default=None, help="`nvidia-smi --query-gpu=name,driver_version` output, if any")
    p = _p_manifest(sub, "binaries", "record sha256/size of both binaries")
    p.add_argument("--cpu", required=True)
    p.add_argument("--gpu", required=True)
    p = _p_manifest(sub, "start", "mark a case started")
    p.add_argument("--case", required=True)
    p = _p_manifest(sub, "record", "record one finished case from its log/exit/argv")
    p.add_argument("--case", required=True)
    p.add_argument("--exit", type=int, required=True)
    p.add_argument("--log", required=True)
    p.add_argument("--proof", help="the produced proof file (hashed here; the runner deletes it afterwards)")
    p.add_argument("--artifact", help="[CL21] a produced binary to record informationally (sha256/size; no expectation)")
    p.add_argument("--binary-role", choices=("cpu", "gpu"))
    p.add_argument("--binary-path")
    p.add_argument("argv", nargs=argparse.REMAINDER, help="-- the command line as executed")
    p = _p_manifest(sub, "finalize", "compute and store the verdict; exit 0 iff green")
    p.add_argument("--repo", help="[CL21] re-probe this checkout and bind the verdict to its trees/lockfiles (a change during the run is red)")
    p = sub.add_parser("validate", help="exit 0 iff complete and green")
    p.add_argument("manifest")
    p.add_argument("--expect-head")
    p.add_argument("--expect-gpu-sha256")
    p.add_argument("--expect-device")
    p.add_argument("--require-production", action="store_true")
    p.add_argument("--repo", help="[CL21] bind the recorded crate trees and lockfile hashes to this checkout's")
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.cmd == "self-test":
            print("gates self-test OK " + json.dumps(self_test()))
            return 0
        if args.cmd == "expected-cases":
            s = suite(args.suite_version)
            if args.oracle_count:
                print(case_definition(s["version"], "oracle_gpu")["expect"]["executed_cases"])
            elif args.json:
                print(json.dumps(s, indent=2))
            else:
                print("\n".join(expected_cases(s["version"])))
            return 0
        if args.cmd == "oracle-summary":
            s = parse_oracle_summary(args.summary, args.expected_cases)
            print(f"oracle cases executed: {s['executed_cases']} (expected {args.expected_cases}); device: {s['device']}")
            return 0
        if args.cmd == "source-identity":
            print(json.dumps(probe_source_identity(args.repo), indent=2))
            return 0
        if args.cmd == "init":
            if os.path.exists(args.out):
                raise GatesError(f"refusing to overwrite {args.out}")
            crates = lockfiles = None
            if args.repo:
                ident = probe_source_identity(args.repo)
                # the runner's own git reading and the helper's must agree, or the
                # tree moved between the two (a commit landing mid-run)
                if ident["head"] != args.head:
                    raise GatesError(f"--head {args.head} but {args.repo} is at {ident['head']}: the checkout moved")
                if ident["dirty_delta_sha256"] != args.dirty_delta_sha256:
                    raise GatesError(f"--dirty-delta-sha256 {args.dirty_delta_sha256} but the delta under hashline/ hashes to "
                                     f"{ident['dirty_delta_sha256']}: the tree changed")
                errors = source_identity_errors(ident)
                if errors:
                    raise GatesError("live checkout: " + "; ".join(errors))
                crates, lockfiles = ident["crates"], ident["lockfiles"]
            m = new_manifest(suite_version=args.suite_version, head=args.head, branch=args.branch,
                             dirty_tracked_count=args.dirty_count, dirty_delta_sha256=args.dirty_delta_sha256,
                             layers=args.layers, tokens=args.tokens, prover_threads=args.prover_threads,
                             cargo_build_jobs=args.build_jobs, rayon_num_threads=args.rayon_threads,
                             cpu_target_dir=args.cpu_target_dir, gpu_target_dir=args.gpu_target_dir,
                             v3_export=args.v3_export, m125_export=args.m125_export, cuda_root=args.cuda_root,
                             scratch=args.scratch, device_selection=args.device_selection, nvidia_smi=args.nvidia_smi,
                             crates=crates, lockfiles=lockfiles, repo=os.path.abspath(args.repo) if args.repo else None)
            save_manifest(m, args.out, new=True)
            ident_note = ""
            if crates:
                ident_note = (f"; hashline tree {crates['hashline']['tree']} lock {(lockfiles['hashline']['sha256'] or '<missing>')[:16]}.., "
                              f"zkp-core tree {crates['zkp_core']['tree']} lock {(lockfiles['zkp_core']['sha256'] or '<missing>')[:16]}.. "
                              f"present {crates['zkp_core']['present']} delta {crates['zkp_core']['dirty_delta_sha256'] == EMPTY_SHA256 and 'empty' or 'NONEMPTY'}")
            print(f"manifest {args.out}: suite version {m['suite_version']}, {len(expected_cases(m['suite_version']))} expected cases, "
                  f"shape {args.layers}x{args.tokens} ({'frozen' if m['build']['shape_frozen'] else 'NOT the frozen shape: no byte expectations apply'})"
                  + ident_note)
            return 0
        m = load_manifest(args.manifest)
        if args.cmd == "binaries":
            set_binaries(m, binary_facts(args.cpu), binary_facts(args.gpu))
            save_manifest(m, args.manifest)
            for role in ("cpu", "gpu"):
                b = m["binaries"][role]
                print(f"{role.upper()} binary  {b['sha256']}  {b['size']} B  {b['path']}")
            return 0
        if args.cmd == "start":
            start_case(m, args.case)
            save_manifest(m, args.manifest)
            return 0
        if args.cmd == "record":
            case = case_definition(m["suite_version"], args.case)
            started = m["started"].get(args.case)
            if started is None:
                raise GatesError(f"case {args.case} was not started (call `start` first)")
            with open(args.log, encoding="utf-8", errors="replace") as fh:
                log_text = fh.read()
            proof = proof_mtime = artifact = None
            if args.proof and os.path.isfile(args.proof):
                proof = {"sha256": sha256_file(args.proof), "bytes": os.stat(args.proof).st_size}
                proof_mtime = os.stat(args.proof).st_mtime
            if args.artifact and os.path.isfile(args.artifact):
                artifact = binary_facts(args.artifact)
            bsha = None
            if args.binary_role:
                if not args.binary_path:
                    raise GatesError("--binary-role needs --binary-path")
                bsha = sha256_file(args.binary_path)
            argv_rest = list(args.argv)
            if argv_rest[:1] == ["--"]:
                argv_rest = argv_rest[1:]
            rec = build_case_record(case, m, exit_code=args.exit, log_text=log_text, log_path=os.path.abspath(args.log),
                                    log_sha256=sha256_file(args.log), argv=argv_rest, proof=proof, binary_sha256=bsha,
                                    started_at=started, ended_at=_now(), proof_mtime=proof_mtime, artifact=artifact)
            add_record(m, rec)
            save_manifest(m, args.manifest)
            failed = [f"{c['check']}: {c['detail']}" for c in rec["checks"] if not c["ok"]]
            if rec["ok"]:
                got = rec["proof"] or {}
                extra = f"  {got['sha256']}  {got['bytes']} B" if got else ""
                print(f"CASE OK   {rec['id']}{extra}  (log retained: {rec['log']['path']})")
                return 0
            print(f"FAILURE: {rec['id']}: " + " | ".join(failed))
            return 1
        if args.cmd == "finalize":
            live = probe_source_identity(args.repo) if args.repo else None
            verdict = finalize_manifest(m, expect_source=live)
            save_manifest(m, args.manifest)
            if verdict["green"]:
                crates = (m["source"].get("crates") or {})
                ident = (f"  trees hashline {crates.get('hashline', {}).get('tree')} zkp-core {crates.get('zkp_core', {}).get('tree')}"
                         if crates else "  (no crate identity recorded: pre-CL21 form)")
                print(f"MANIFEST GREEN  suite v{m['suite_version']}  {len(m['cases'])} cases  head {m['source']['head']}  "
                      f"gpu binary {m['binaries']['gpu']['sha256']}  device {m['device']['oracle_label']}{ident}")
                return 0
            print("MANIFEST RED:")
            for r in verdict["reasons"]:
                print("  - " + r)
            return 1
        if args.cmd == "validate":
            live = probe_source_identity(args.repo) if args.repo else None
            v = validate_manifest(m, expect_head=args.expect_head, expect_gpu_sha256=args.expect_gpu_sha256,
                                  expect_device=args.expect_device, require_production=args.require_production,
                                  expect_source=live)
            print(json.dumps(v, indent=2))
            return 0 if v["ok"] else 1
    except (GatesError, OSError, ValueError) as error:
        print(f"gates: {error}", file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

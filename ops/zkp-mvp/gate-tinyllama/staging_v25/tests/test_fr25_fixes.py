#!/usr/bin/env python3
"""[v25 staging, 2026-11-02, v25 freeze fixes] Tests of the fixes gate round
27's freeze review (`results/zk60_gate_tinyllama_20261017/round27/
FREEZE_REVIEW_V25.md`) requires: FR25-01 / -02 (the pinned Rust s25 printout,
HASH-2), FR25-03 / -04 (the status: the run flags, the accepted residuals, the
W16 cap), FR25-05 (the writer's exact pin set), FR25-06 (no 48-bit prefix
reads a pin; control P-3), FR25-11 (not applicable is not fired) and FR25-14
(the status computed directly, and the driver run end to end on stubbed
parts).

Everything here runs on the repository's own records (the retained bundle
manifests, the committed gzipped printout, the round-25 W16 records) and
in-memory copies; nothing is written outside a temporary directory.  The
bundle tests at the end need a registered R13 D55 bundle
(`ZK60_D55_R13_BUNDLE`, as in `test_d55_r13_gate`) and skip without it.
NOTHING HERE IS A PRIVACY STATEMENT."""

import contextlib
import copy
import glob
import gzip
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import types
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(os.path.dirname(HERE), "scripts")
sys.path.insert(0, SCRIPTS)

import zk60_native_rg_d55 as D  # noqa: E402
import zk60_native_rg_d55hash as H  # noqa: E402
import zk60_native_rg_d55ts as S  # noqa: E402
import zk60_native_rg_r26readings as R26  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402
import zk60_native_rg_w16 as W  # noqa: E402

BUNDLE = os.environ.get("ZK60_D55_R13_BUNDLE", "")
G_K = "G_k in the clear: recovered on SC_FZC, not read from a bound line"
RUNG_MANIFEST_REL = "results/zk60_d60_20261102/privacy_gate_r26/bundle_manifests/d55-r13_rung_h24-s0/manifest.json"
RUNG_MANIFEST_SHA = "789f4548cd984242b2c09dfe3447f7591f7595e02a3242b2411a7c09b310b170"   # the review's pins.log input
RUN_CAPTURE_REL = "ops/zkp-mvp/gpu-metal/hashline/src/private_block/run_capture.rs"


def _repo():
    d = HERE
    for _ in range(8):
        if os.path.isfile(os.path.join(d, RUNG_MANIFEST_REL)):
            return d
        d = os.path.dirname(d)
    return None


REPO = _repo()


def _rung_manifest():
    with open(os.path.join(REPO, RUNG_MANIFEST_REL), "rb") as fh:
        raw = fh.read()
    assert hashlib.sha256(raw).hexdigest() == RUNG_MANIFEST_SHA
    return json.loads(raw)


def _classify(man):
    return W.classify_pins(types.SimpleNamespace(manifest=man), W.default_r19b_manifest())


def _blake3_present():
    try:
        import blake3  # noqa: F401
        return True
    except ImportError:
        return False


ALL_TRUE = {"D55-0 integrity": True, "D55-3 replay": True, "HASH-2 hash census": True}


# ---------------------------------------------------------------- FR25-03 / -04 / -14: the status, directly
class Status(unittest.TestCase):
    def test_the_genuine_shape_is_pass_and_names_its_accepted_residual(self):
        s = D.d55_status(ALL_TRUE, True, "R13", [G_K], True, True)
        self.assertEqual(s["status"], "D55-PASS")
        self.assertEqual(s["status_reasons"], [])
        self.assertEqual(s["not_here_accepted"], {G_K: "round 27 freeze review, §3 Q5 (to be recorded in the D60 row)"})
        self.assertIn("accepted by round 27 freeze review", s["status_means"])
        self.assertEqual((s["controls_run"], s["joint_run"]), (True, True))

    def test_no_controls_or_no_joint_never_gives_pass(self):
        for controls, joint in ((False, True), (True, False), (False, False)):
            s = D.d55_status(ALL_TRUE, True, "R13", [G_K], controls, joint)
            self.assertEqual(s["status"], "D55-DEV-PASS", (controls, joint))
            self.assertEqual((s["controls_run"], s["joint_run"]), (controls, joint))
            self.assertEqual(any("--no-controls" in r for r in s["status_reasons"]), not controls)
            self.assertEqual(any("--no-joint" in r for r in s["status_reasons"]), not joint)
        # the driver's own --no-joint not_here line is not an accepted residual either
        s = D.d55_status(ALL_TRUE, True, "R13", [G_K, "the run-level joint rank (D55-J), not requested"], True, True)
        self.assertEqual(s["status"], "D55-DEV-PASS")

    def test_an_unaccepted_not_here_entry_blocks_pass(self):
        for item in ("NL-1 S1-S5 (the non-linear table checks) on the R13 slots", "the hash census on the Python side",
                     "the independent check of the self-read readings (READINGS_R26_WIRING.json) at the v25 freeze review",
                     G_K + " ", "g_k in the clear: recovered on SC_FZC, not read from a bound line"):
            s = D.d55_status(ALL_TRUE, True, "R13", [G_K, item], True, True)
            self.assertEqual(s["status"], "D55-DEV-PASS", item)
            self.assertEqual(s["not_here_unaccepted"], [item])
        self.assertEqual(D.d55_status(ALL_TRUE, True, "R13", [], True, True)["status"], "D55-PASS")

    def test_the_accepted_residuals_are_the_one_review_verdict(self):
        self.assertEqual(D.ACCEPTED_RESIDUALS, {G_K: "round 27 freeze review, §3 Q5 (to be recorded in the D60 row)"})
        # the entry is the driver's R13 not_here string verbatim
        with open(os.path.join(SCRIPTS, "zk60_native_rg_d55.py"), encoding="utf-8") as fh:
            self.assertGreaterEqual(fh.read().count(f'"{G_K}"'), 2)

    def test_the_w16_family_is_capped(self):
        for fam in ("W16", "W16R2", "", None):
            s = D.d55_status(ALL_TRUE, True, fam, [], True, True)
            self.assertEqual(s["status"], "D55-DEV-PASS", fam)
        s = D.d55_status(ALL_TRUE, True, "W16", [], True, True)
        self.assertIn(D.W16_FAMILY_CAP, s["status_reasons"])

    def test_pins_not_ok_is_dev_pass_and_a_false_or_missing_part_is_not_ok(self):
        self.assertEqual(D.d55_status(ALL_TRUE, False, "R13", [G_K], True, True)["status"], "D55-DEV-PASS")
        for k in ALL_TRUE:
            parts = dict(ALL_TRUE, **{k: False})
            for flags in ((True, True), (False, False)):
                self.assertEqual(D.d55_status(parts, True, "R13", [G_K], *flags)["status"], "NOT-OK", k)
        self.assertEqual(D.d55_status({}, True, "R13", [G_K], True, True)["status"], "NOT-OK")


# ---------------------------------------------------------------- FR25-05: the writer's exact pin set
def _const_list(src, name):
    m = re.search(r"pub\(super\) const " + name + r": \[&str; (\d+)\] = \[(.*?)\n\];", src, re.S)
    body = "\n".join(line.split("//", 1)[0] for line in m.group(2).splitlines())
    items = re.findall(r'"([^"]+)"', body)
    assert len(items) == int(m.group(1)), (name, len(items), m.group(1))
    return items


def _run_capture_at_the_read_digest():
    """run_capture.rs at RUN_CAPTURE_RS_READ: the checkout's file when it is at
    that digest, else the git blob; the bytes are hashed before they are
    parsed.  None when neither is available."""
    p = os.path.join(REPO, RUN_CAPTURE_REL)
    raw = None
    if os.path.isfile(p):
        with open(p, "rb") as fh:
            raw = fh.read()
    if raw is None or hashlib.sha256(raw).hexdigest() != D.RUN_CAPTURE_RS_READ:
        try:
            raw = subprocess.run(["git", "-C", REPO, "cat-file", "blob", D.RUN_CAPTURE_RS_READ_BLOB],
                                 capture_output=True, check=True, timeout=60).stdout
        except (OSError, subprocess.SubprocessError):
            return None
    return raw if hashlib.sha256(raw).hexdigest() == D.RUN_CAPTURE_RS_READ else None


@unittest.skipUnless(REPO, "the retained bundle manifests are not in this checkout")
class PinSet(unittest.TestCase):
    def test_the_registered_list_is_run_captures_own_plus_shared_at_the_read_digest(self):
        raw = _run_capture_at_the_read_digest()
        if raw is None:
            self.skipTest("run_capture.rs at 10b6d3be is neither on disk nor in git")
        src = raw.decode()
        own, shared = _const_list(src, "OWN_SOURCE_FILES"), _const_list(src, "SHARED_SOURCE_FILES")
        self.assertEqual((len(own), len(shared)), (44, 31))
        self.assertEqual(D.REGISTERED_WRITER_PINS, tuple(own + shared))
        self.assertEqual(len(set(D.REGISTERED_WRITER_PINS)), 75)
        # the two writer strings, verbatim in the Rust writers
        self.assertIn(f'\\"writer\\":\\"{D.REGISTERED_WRITER}\\"', src)
        tests_rs = os.path.join(REPO, "ops/zkp-mvp/gpu-metal/hashline/src/private_block/w16_privacy_gate_tests.rs")
        if os.path.isfile(tests_rs):
            with open(tests_rs, encoding="utf-8") as fh:
                t = fh.read()
            self.assertIn(f'\\"writer\\":\\"{D.TEST_ONLY_WRITER}\\"', t)
            self.assertIn("for extra in [" + ", ".join(f'"{x}"' for x in D.TEST_ONLY_EXTRA_PINS) + "]", t)

    def test_the_honest_manifest_is_exactly_the_registered_set(self):
        s = D.pin_set_check(_rung_manifest())
        self.assertTrue(s["ok"], s)
        self.assertEqual((s["declared"], s["expected"], s["missing"], s["unexpected"], s["duplicates"]), (75, 75, [], [], []))

    def test_every_retained_d55_manifest_is_its_writers_set(self):
        paths = sorted(glob.glob(os.path.join(REPO, "results/zk60_d60_20261102/privacy_gate_r26/bundle_manifests/*/manifest.json"))
                       + glob.glob(os.path.join(REPO, "results/zk60_d60_20261102/privacy_gate_tsbases/bundle_manifests/*/manifest.json")))
        self.assertEqual(len(paths), 13)
        for p in paths:
            with open(p) as fh:
                self.assertTrue(D.pin_set_check(json.load(fh))["ok"], p)

    def test_a_list_cut_to_six_pins_is_refused(self):
        """the review's exp_pins shape: only the terminal port's four plus two
        kept; the classification alone still says ok, the pin set does not"""
        man = _rung_manifest()
        keep = set(T.PORTED_FROM) | set(T.PINNED_IF_PRESENT)
        man["source_pins"] = [p for p in man["source_pins"] if p["file"] in keep]
        self.assertEqual(len(man["source_pins"]), 6)
        self.assertTrue(_classify(man)["ok"])            # FR25-05's hole, as the review found it
        s = D.pin_set_check(man)
        self.assertFalse(s["ok"])
        self.assertEqual(len(s["missing"]), 69)
        for f in ("src/private_block/run_fork.rs", "src/private_block/run_fork_wire.rs", "src/private_block/run_capture.rs",
                  "../zkp-core/src/pcs.rs", "../zkp-core/src/rng.rs", "src/gpu/metal.rs", "src/gpu/metal_kernels.metal"):
            self.assertIn(f, s["missing"])
        man["source_pins"] = []
        self.assertFalse(D.pin_set_check(man)["ok"])

    def test_an_extra_or_a_duplicate_pin_is_refused(self):
        man = _rung_manifest()
        man["source_pins"].append({"file": "src/private_block/s25_tests.rs", "sha256": "0" * 64})
        s = D.pin_set_check(man)
        self.assertFalse(s["ok"])
        self.assertEqual(s["unexpected"], ["src/private_block/s25_tests.rs"])
        man = _rung_manifest()
        man["source_pins"].append(dict(man["source_pins"][0]))
        s = D.pin_set_check(man)
        self.assertFalse(s["ok"])
        self.assertEqual(s["duplicates"], [man["source_pins"][0]["file"]])
        # the test-only writer's own file is unexpected for the registered writer
        man = _rung_manifest()
        man["source_pins"].append({"file": "src/private_block/w16_privacy_gate_tests.rs", "sha256": "0" * 64})
        self.assertFalse(D.pin_set_check(man)["ok"])

    def test_the_writer_must_be_known_and_selects_its_set(self):
        man = _rung_manifest()
        for w in (None, "", "run_capture::write_bundle", D.REGISTERED_WRITER + " ", 7):
            m = copy.deepcopy(man)
            if w is None:
                m.pop("writer")
            else:
                m["writer"] = w
            s = D.pin_set_check(m)
            self.assertFalse(s["ok"], w)
            self.assertFalse(s["writer_known"], w)
        # the test-only writer expects the 75 plus its test file (76 as a set)
        m = copy.deepcopy(man)
        m["writer"] = D.TEST_ONLY_WRITER
        s = D.pin_set_check(m)
        self.assertFalse(s["ok"])
        self.assertEqual(s["missing"], ["src/private_block/w16_privacy_gate_tests.rs"])
        m["source_pins"].append({"file": "src/private_block/w16_privacy_gate_tests.rs", "sha256": "0" * 64})
        self.assertTrue(D.pin_set_check(m)["ok"])
        self.assertEqual(len(D.EXPECTED_PINS[D.TEST_ONLY_WRITER]), 76)

    def test_controls_p4_and_p5_fire_on_the_rung_manifest(self):
        c = D.pin_controls(types.SimpleNamespace(manifest=_rung_manifest()), W.default_r19b_manifest())
        self.assertTrue(c["controls"]["P-4 a pin removed"]["fires"])
        self.assertTrue(c["controls"]["P-5 an extra pin"]["fires"])
        self.assertTrue(c["ok"], {k: v["fires"] for k, v in c["controls"].items()})


# ---------------------------------------------------------------- FR25-06: no 48-bit prefix reads a pin
class W16FullDigests(unittest.TestCase):
    def test_every_w16_reading_is_a_full_digest_and_agrees_with_round_26(self):
        for f, (d, text) in W.W16_READINGS.items():
            self.assertRegex(d, r"^[0-9a-f]{64}$", f)
            self.assertTrue(text)
            r = R26.R26_READINGS.get((f, d[:12]))
            if r is not None:
                self.assertEqual(r[0], d, f)
        self.assertEqual(sorted(f for f, (d, _t) in W.W16_READINGS.items() if (f, d[:12]) not in R26.R26_READINGS),
                         ["src/private_block/run.rs", "src/private_block/run_capture.rs"])

    @unittest.skipUnless(REPO and glob.glob(os.path.join(REPO or "", "results/zk60_gate_tinyllama_20261017/round25/w16/*.json")),
                         "the round-25 W16 records are not in this checkout")
    def test_the_full_digests_are_the_ones_the_round25_w16_bundles_declared(self):
        recs = sorted(glob.glob(os.path.join(REPO, "results/zk60_gate_tinyllama_20261017/round25/w16/*.json")))
        self.assertEqual(len(recs), 5)
        for p in recs:
            with open(p) as fh:
                d = json.load(fh)
            declared = {x["file"]: x["sha256"] for x in d["W16-0 integrity"]["source_pins"]}
            for f, (full, _t) in W.W16_READINGS.items():
                self.assertEqual(declared[f], full, (p, f))
            # and each was READ by that record (the W16 reading these digests carry)
            self.assertEqual(sorted(d["PINS"]["readings"]), sorted(W.W16_READINGS))

    def test_a_prefix_twin_of_a_w16_read_pin_is_unread(self):
        """the review's exp_prefix (a): the 12-hex prefix and 52 zeros"""
        for f in ("src/private_block/run.rs", "src/private_block/run_capture.rs"):
            full = W.W16_READINGS[f][0]
            p = _classify({"source_pins": [{"file": f, "sha256": full}], "proved_on_gpu": False})
            self.assertEqual(p["read_here"], [f])
            self.assertTrue(p["ok"])
            for twin in (full[:12] + "0" * 52, full[:-1] + ("0" if full[-1] != "0" else "1")):
                p = _classify({"source_pins": [{"file": f, "sha256": twin}], "proved_on_gpu": False})
                self.assertEqual(p["read_here"], [], (f, twin))
                self.assertEqual([u["file"] for u in p["unread"]], [f])
                self.assertFalse(p["ok"])

    @unittest.skipUnless(REPO, "the retained bundle manifests are not in this checkout")
    def test_control_p3_fires_and_catches_a_prefix_rule(self):
        man = _rung_manifest()
        c = D.pin_controls(types.SimpleNamespace(manifest=man), W.default_r19b_manifest())
        p3 = c["controls"]["P-3 W16 reading, prefix twin"]
        self.assertTrue(p3["fires"], p3)
        self.assertTrue(p3["injected"])                  # no pin of the registered rung bundle is W16-read
        self.assertTrue(p3["read_at_the_full_digest"] and p3["twin_unread"])
        # with the pre-fix prefix rule put back, P-3 must NOT fire (and so PINS controls fail)
        real = W.classify_pins

        def prefix_rule(bundle, r19b):
            p = real(bundle, r19b)
            pins = {x["file"]: x["sha256"] for x in bundle.manifest.get("source_pins", [])}
            moved = [u for u in p["unread"] if u["file"] in W.W16_READINGS
                     and pins[u["file"]].startswith(W.W16_READINGS[u["file"]][0][:12])]
            for u in moved:
                p["unread"].remove(u)
                p["read_here"].append(u["file"])
            p["ok"] = bool(p["r19b_manifest_found"] and not p["unread"] and p["backend"]["admissible"])
            return p
        with mock.patch.object(W, "classify_pins", prefix_rule):
            c2 = D.pin_controls(types.SimpleNamespace(manifest=_rung_manifest()), W.default_r19b_manifest())
        self.assertFalse(c2["controls"]["P-3 W16 reading, prefix twin"]["fires"])
        self.assertFalse(c2["ok"])


# ---------------------------------------------------------------- FR25-11: not applicable is not fired
class NotApplicable(unittest.TestCase):
    def test_p1_p2_without_an_object_are_not_applicable_not_fired(self):
        """the review's exp_prefix (b): no pin read by an R26 reading"""
        m = {"source_pins": [{"file": "src/private_block/run.rs", "sha256": "ab" * 32}], "proved_on_gpu": False}
        c = D.pin_controls(types.SimpleNamespace(manifest=m), W.default_r19b_manifest())
        for k in ("P-1 prefix only", "P-2 unknown digest", "P-4 a pin removed", "P-5 an extra pin"):
            self.assertIsNone(c["controls"][k]["fires"], k)
            self.assertIn(k, c["not_applicable"])
        self.assertTrue(c["controls"]["P-3 W16 reading, prefix twin"]["fires"])

    def test_a_family_of_only_not_applicable_controls_is_not_ok(self):
        ok = D._control_family_ok
        self.assertTrue(ok({"B-1": {"fires": True}, "P-1": {"fires": None}, "P-3": {"fires": True}}))
        self.assertFalse(ok({"B-1": {"fires": True}, "P-1": {"fires": None}, "P-2": {"fires": None}}))
        self.assertFalse(ok({"B-1": {"fires": True}, "P-1": {"fires": False}, "P-3": {"fires": True}}))
        self.assertFalse(ok({}))

    def test_ts1f_without_a_row_is_not_applicable_and_a_limit_below_1_is_refused(self):
        good = {"forms_agree": True, "equals_the_ts1_original_form": True}
        self.assertIs(S.fidelity_control([good], 2, 1)["ok"], True)
        self.assertIs(S.fidelity_control([dict(good, forms_agree=False)], 2, 1)["ok"], False)
        na = S.fidelity_control([], 2, 1)
        self.assertIsNone(na["ok"])
        self.assertTrue(na["not_applicable"])
        for rows, count in ((0, 1), (2, 0), (-1, 5)):
            r = S.fidelity_control([], rows, count)
            self.assertIs(r["ok"], False, (rows, count))
            self.assertIn("refused", r)
        # the family verdict: not applicable neither passes nor fails; one applicable control must hold
        self.assertTrue(S.controls_ok({"TS-1": {"ok": True}, "TS-1F": na, "TS-RC": {"ok": True}}))
        self.assertFalse(S.controls_ok({"TS-1F": na}))
        self.assertFalse(S.controls_ok({"TS-1": {"ok": True}, "TS-1F": S.fidelity_control([], 0, 1)}))
        self.assertFalse(S.controls_ok({"TS-1": {"ok": False}, "TS-1F": na}))


# ---------------------------------------------------------------- FR25-01 / -02: the pinned printout
@contextlib.contextmanager
def _env(**kw):
    with mock.patch.dict(os.environ, {}, clear=False):
        for k, v in kw.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        yield


class Printout(unittest.TestCase):
    PROFILE = "hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1"

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.genuine = None
        gz = os.path.join(REPO, H.S25_W2_PRINTOUT_COPY) if REPO else ""
        if gz and os.path.isfile(gz):
            with gzip.open(gz, "rb") as fh:
                raw = fh.read()
            cls.genuine = os.path.join(cls.tmp.name, "s25_w2_printout_v2.log")
            with open(cls.genuine, "wb") as fh:
                fh.write(raw)
            cls.raw = raw

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_not_set_or_unreadable_is_refused(self):
        with _env(ZK60_S25_W2_PRINTOUT=None):
            rust, why = H.load_rust(self.PROFILE)
        self.assertIsNone(rust)
        self.assertIn("is not set", why["refused"])
        with _env(ZK60_S25_W2_PRINTOUT=""):
            self.assertIsNone(H.load_rust(self.PROFILE)[0])
        for p in (os.path.join(self.tmp.name, "absent.log"), self.tmp.name):
            rust, why = H.load_rust(self.PROFILE, path=p)
            self.assertIsNone(rust, p)
            self.assertIn("cannot be read", why["refused"])

    @unittest.skipUnless(REPO, "the committed printout is not in this checkout")
    def test_the_genuine_printout_is_the_pin_and_parses_as_before(self):
        self.assertIsNotNone(self.genuine)
        self.assertEqual(hashlib.sha256(self.raw).hexdigest(), H.S25_W2_PRINTOUT_PIN)
        with open(os.path.join(REPO, os.path.dirname(H.S25_W2_PRINTOUT_COPY), "PRINTOUTS_SHA256.txt")) as fh:
            self.assertIn(H.S25_W2_PRINTOUT_PIN + "  ", fh.read())
        with _env(ZK60_S25_W2_PRINTOUT=self.genuine):
            rust, why = H.load_rust(self.PROFILE)
        self.assertIsNone(why)
        self.assertEqual((rust["sha256"], rust["pin"], rust["made_by"]), (H.S25_W2_PRINTOUT_PIN, H.S25_W2_PRINTOUT_PIN, H.S25_W2_PRINTOUT_MADE_BY))
        self.assertTrue(rust["table"])
        self.assertEqual(rust["table"], H.rust_table(self.genuine, self.PROFILE))     # the bytes hashed are the bytes parsed

    @unittest.skipUnless(REPO, "the committed printout is not in this checkout")
    def test_a_wrong_digest_printout_is_refused(self):
        """an edited copy that lists one more kind (the review's FR25-02 scenario)"""
        bad = os.path.join(self.tmp.name, "edited.log")
        extra = f"--- {self.PROFILE} (L = 3)\n    999 B  F_T the transcript absorb of `parameters` with 999 bytes of data\n".encode()
        with open(bad, "wb") as fh:
            fh.write(self.raw + extra)
        rust, why = H.load_rust(self.PROFILE, path=bad)
        self.assertIsNone(rust)
        self.assertIn("is not the pinned", why["refused"])
        self.assertEqual(why["printout_sha256"], hashlib.sha256(self.raw + extra).hexdigest())

    def test_the_printout_names_the_s25_tests_rs_that_made_it(self):
        mb = H.S25_W2_PRINTOUT_MADE_BY
        self.assertEqual(mb["commit"][:8], "076a485f")
        p = os.path.join(REPO or "", mb["file"])
        if not (REPO and os.path.isfile(p)):
            self.skipTest("s25_tests.rs is not in this checkout")
        try:
            raw = subprocess.run(["git", "-C", REPO, "show", f"{mb['commit']}:{mb['file']}"],
                                 capture_output=True, check=True, timeout=60).stdout
        except (OSError, subprocess.SubprocessError):
            self.skipTest("git is not available")
        self.assertEqual(hashlib.sha256(raw).hexdigest(), mb["sha256"])
        self.assertEqual(len(raw), mb["bytes"])

    def test_hash2_is_false_without_the_pinned_table(self):
        why = {"refused": "ZK60_S25_W2_PRINTOUT is not set", "ok": False}
        hc = H.hash2_verdict({"ok": True, "findings": []}, None, why, True, True)
        self.assertFalse(hc["ok"])
        self.assertFalse(hc["rust_table_compared"])
        self.assertTrue(any("HASH-2:" in f for f in hc["findings"]))
        rust = {"table": {("F_T", 1, "x")}}
        self.assertTrue(H.hash2_verdict({"ok": True, "findings": [], "rust_table": {"ok": True}}, rust, None, True, True)["ok"])
        self.assertFalse(H.hash2_verdict({"ok": True, "findings": [], "rust_table": {"ok": False}}, rust, None, True, True)["ok"])
        self.assertFalse(H.hash2_verdict({"ok": True, "findings": []}, rust, None, True, True)["ok"])      # no comparison recorded
        self.assertFalse(H.hash2_verdict({"ok": True, "findings": [], "rust_table": {"ok": True}}, rust, None, False, True)["ok"])
        self.assertFalse(H.hash2_verdict({"ok": False, "findings": [], "rust_table": {"ok": True}}, rust, None, True, True)["ok"])


# ---------------------------------------------------------------- FR25-14: the driver end to end, stubbed parts
class _Replay:
    def __init__(self, b, drop_fork_index=False):
        self.run_binding_ok = True

    def run(self):
        return self

    def summary(self):
        return {"ok": True}


@unittest.skipUnless(REPO, "the retained bundle manifests are not in this checkout")
class StubbedDriver(unittest.TestCase):
    """`d55_gate` with every figure part stubbed true (and one made false), the
    REAL pin classification, pin-set check and PINS controls on the retained
    rung manifest, and the real status: every flag combination."""

    def gate(self, family="R13", manifest=None, controls=True, joint=True, false_part=None):
        import zk60_native_rg_d55joint as J
        import zk60_native_rg_d55nl as NLX
        import zk60_native_rg_d55preimage as PRX
        import zk60_native_rg_d55r13 as X
        import zk60_native_rg_mask as M
        import zk60_native_rg_mcontrols as MC
        man = manifest if manifest is not None else _rung_manifest()
        fake = types.SimpleNamespace(name="stub", dir="/nonexistent/stub", profile=man.get("profile"), blocks=3, manifest=man)

        def ok(name):
            return {"ok": name != false_part}
        stubs = [
            (D, "D55Bundle", lambda d: fake), (D, "d55_integrity", lambda b: ok("D55-0")),
            (D, "d55_facts", lambda b: {"family": "R13"} if family == "R13" else {}), (D, "D55Replay", _Replay),
            (D, "d55_stage3", lambda b, rp, do_controls=True, return_views=False: (ok("stage3"), {})),
            (D, "io_claims_from_terminals", lambda b, doctor=None: {"ok": doctor is None, "findings": [] if doctor is None else ["moved"]}),
            (D, "replay_controls", lambda b: ok("D55-C")),
            (W, "check_layout", lambda b, f: ok("W16-4")), (W, "check_tab_tables", lambda b, f, k: ok("W16-5")),
            (W, "tab_control", lambda b, f: {"ok": True}), (W, "tool_hashes", lambda: {}),
            (X, "registered_header", lambda *a, **k: ok("R13-H")), (X, "r13_layout", lambda b: ok("R13-2")),
            (X, "r13_terminals", lambda *a, **k: dict(ok("R13-3"), source_pins={})),
            (M, "mask_cfs_stage", lambda b, rp, k: ok("mask")), (MC, "mask_controls_at_shape", lambda b, rp, k=0: {"ok": True}),
            (J, "d55_joint", lambda *a, **k: ok("D55-J")),
            (NLX, "d55_nl1", lambda *a, **k: ok("NL-1")), (NLX, "gates_from_r13_3", lambda r: None),
            (PRX, "d55_full_preimage", lambda *a, **k: ok("PRE")),
            (S, "d55_ts_census", lambda d, controls=True: (ok("TS-1"), ok("CENSUS"))),
            (H, "d55_hash", lambda b, controls=True: (ok("HASH-1"), ok("HASH-2"))),
        ]
        with contextlib.ExitStack() as st:
            for mod, name, fn in stubs:
                st.enter_context(mock.patch.object(mod, name, fn))
            return D.d55_gate("/nonexistent/stub", controls=controls, joint=joint)

    def test_the_genuine_shape_is_d55_pass_with_its_record_fields(self):
        r = self.gate()
        self.assertEqual(r["status"], "D55-PASS", r.get("status_reasons"))
        self.assertEqual((r["controls_run"], r["joint_run"]), (True, True))
        self.assertEqual(r["not_here"], [G_K])
        self.assertEqual(r["not_here_accepted"], {G_K: D.ACCEPTED_RESIDUALS[G_K]})
        self.assertTrue(r["PINS"]["ok"] and r["PINS"]["pin_set"]["ok"])
        self.assertEqual(r["PINS"]["self_read_pending_independent_check"], [])      # FR25-13
        self.assertTrue(r["parts"]["PINS controls"])
        self.assertEqual(len(r["parts"]), 18)

    def test_no_controls_and_no_joint_are_capped(self):
        for controls, joint in ((False, True), (True, False), (False, False)):
            r = self.gate(controls=controls, joint=joint)
            self.assertEqual(r["status"], "D55-DEV-PASS", (controls, joint))
            self.assertEqual((r["controls_run"], r["joint_run"]), (controls, joint))
            self.assertEqual("D55-J joint rank" in r["parts"], joint)
            self.assertEqual("PINS controls" in r["parts"], controls)

    def test_the_w16_family_is_capped(self):
        r = self.gate(family="W16")
        self.assertEqual(r["family"], "W16")
        self.assertEqual(r["status"], "D55-DEV-PASS")
        self.assertIn(D.W16_FAMILY_CAP, r["status_reasons"])

    def test_a_cut_or_extended_pin_list_is_refused(self):
        man = _rung_manifest()
        keep = set(T.PORTED_FROM) | set(T.PINNED_IF_PRESENT)
        man["source_pins"] = [p for p in man["source_pins"] if p["file"] in keep]
        r = self.gate(manifest=man)
        self.assertEqual(r["status"], "D55-DEV-PASS")
        self.assertEqual(len(r["PINS"]["pin_set"]["missing"]), 69)
        man = _rung_manifest()
        man["source_pins"].append({"file": "src/private_block/s25_tests.rs", "sha256": "0" * 64})
        self.assertEqual(self.gate(manifest=man)["status"], "D55-DEV-PASS")
        man = _rung_manifest()
        man["writer"] = "some other writer"
        self.assertEqual(self.gate(manifest=man)["status"], "D55-DEV-PASS")

    def test_a_self_read_reading_is_owed_and_blocks_pass(self):
        key = ("src/gpu/metal.rs", "a96882bcc671")
        row = R26.R26_READINGS[key]
        with mock.patch.dict(R26.R26_READINGS, {key: (row[0], row[1], R26.SELF_READ, row[3], row[4])}):
            r = self.gate()
        self.assertEqual(r["status"], "D55-DEV-PASS")
        self.assertEqual(r["PINS"]["self_read_pending_independent_check"], ["src/gpu/metal.rs"])

    def test_a_false_part_is_not_ok(self):
        for p in ("HASH-2", "NL-1", "D55-J", "D55-0"):
            r = self.gate(false_part=p)
            self.assertEqual(r["status"], "NOT-OK", p)


# ---------------------------------------------------------------- on a real bundle (light: the hash parts only)
@unittest.skipUnless(BUNDLE and os.path.isdir(BUNDLE) and _blake3_present() and REPO,
                     "set ZK60_D55_R13_BUNDLE to a registered R13 D55 capture (and install blake3)")
class OnABundle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.b = D.D55Bundle(BUNDLE)
        cls.tmp = tempfile.TemporaryDirectory()
        with gzip.open(os.path.join(REPO, H.S25_W2_PRINTOUT_COPY), "rb") as fh:
            raw = fh.read()
        cls.genuine = os.path.join(cls.tmp.name, "s25_w2_printout_v2.log")
        with open(cls.genuine, "wb") as fh:
            fh.write(raw)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_hash2_without_the_printout_is_false_and_hc7_is_not_fired(self):
        with _env(ZK60_S25_W2_PRINTOUT=None):
            _hl, hc = H.d55_hash(self.b, controls=True)
        self.assertFalse(hc["ok"])
        self.assertFalse(hc["s25_printout"]["accepted"])
        self.assertIs(hc["controls"]["HC-7 a parameters absorb 64 bytes longer than the run's"]["fires"], False)
        # the gate's own conditions still hold: only the missing table makes it false
        self.assertTrue(hc["W-2_holds"] and hc["W-2g_holds"] and hc["ACC_every_call_attributed"])

    def test_hash2_with_the_pinned_printout_holds(self):
        with _env(ZK60_S25_W2_PRINTOUT=self.genuine):
            _hl, hc = H.d55_hash(self.b, controls=True)
        self.assertTrue(hc["ok"], hc["findings"])
        self.assertTrue(hc["s25_printout"]["accepted"])
        self.assertEqual(hc["rust_table"]["printout_sha256"], H.S25_W2_PRINTOUT_PIN)
        self.assertTrue(hc["controls"]["HC-7 a parameters absorb 64 bytes longer than the run's"]["fires"])

    def test_the_bundles_pins_and_controls(self):
        p = W.classify_pins(self.b, W.default_r19b_manifest())
        self.assertTrue(p["ok"])
        self.assertTrue(D.pin_set_check(self.b.manifest)["ok"])
        c = D.pin_controls(self.b, W.default_r19b_manifest())
        self.assertTrue(c["ok"], {k: v["fires"] for k, v in c["controls"].items()})
        self.assertEqual(c["not_applicable"], [])


if __name__ == "__main__":
    unittest.main()

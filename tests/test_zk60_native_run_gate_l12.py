"""Tests for round 9m: the gate reads a TWELVE-block 125M run.

Run:
  python3 -m unittest tests.test_zk60_native_run_gate_l12

WHAT ROUND 9m CHANGED IN THE TOOLS, AND WHAT IS ASSERTED HERE.

Lane stage 48 wrote the first two twelve-block 125M run bundles
(`m125-capture-{dense,zero}-l12`, `source_commit` `17830dc`).  The unedited
gate refused them at load on two counts, both by name
(`results/zk60_native_run_gate_9m/probe_before_repin/`):

* `run.rs` is pinned at `f5f4d571`, a digest the run-layer table had not
  read.  It was read whole against rung-K8's `99a8de8` (stages 40-43:
  refusals CS-1 / CS-4 / CS-6 / CS-7 and CS-8's sealed fields) and pinned
  with that reading; a THIRD digest is still refused.
* `validation.json` sits beside the capture and is not in the manifest (a
  fresh process writes it AFTER the manifest).  It is now read and compared
  with what IS pinned, never trusted for a figure, and the receipt's
  segments under `run/` are checked against the length and SHA-256 each
  stage file pins.  A bundle that carries neither gains no leaf.

FOUR ARMS: the pin table (pure); the refusal of a third digest (on the
twelve-block manifest when it is on this box, else on a stand-in); the
validation / `run/` reader on a synthetic directory (every way it can
refuse, and the silence of a bundle that has neither); and the twelve-block
RECORDS once they are committed (skipped until then).

Nothing here asserts a privacy property.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

from zk60_native_rg_bundle import (  # noqa: E402
    RUN_DIR,
    STATEMENT_DIR,
    STATEMENT_FILE,
    VALIDATION_FILE,
    VALIDATION_FLAGS,
    VALIDATION_KIND,
    validation_and_run_directory,
)
from zk60_native_rg_runpins import (  # noqa: E402
    ALL_STAGES,
    READINGS,
    RUN_LAYER_PINS,
    check_run_layer_pins,
)

M125_DIR = os.environ.get("ZK60_M125_BUNDLES", "/home/victor/zk60-artifacts")
L12 = ("m125-capture-dense-l12", "m125-capture-zero-l12")
HAVE_L12 = all(os.path.isfile(os.path.join(M125_DIR, b, "manifest.json"))
               for b in L12)
EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_9m")

RUN_RS = "src/private_block/run.rs"
NEW_RUN_RS = "f5f4d571e04b8bd1b024478e9a477c75b3bbc93a9ef71b43b18510793b76367a"
K8_RUN_RS = "f39aec7925ba27d51361cd3935e874b1301d7595be81f3199d9d2941c0f818e0"
CAPTURE_COMMIT = "17830dcc9f24b0d19e212b0344476e299cfd9be0"
STAGE43 = "601e97f41aa321c4de32873ee53e980a44b739e6"


class _Manifest:
    """Only what the pin checks read."""

    def __init__(self, manifest):
        self.manifest = manifest


def _l12_manifest():
    with open(os.path.join(M125_DIR, L12[0], "manifest.json")) as fh:
        return json.load(fh)


def _stand_in_manifest():
    """The three run-layer pins at the twelve-block digests, and nothing
    else: enough for `check_run_layer_pins` when the bundles are absent."""
    return {"source_pins": [
        {"file": "src/private_block/run_capture.rs", "sha256":
         "d09f385315cac8e7b7fb16a65b0243219e4ba78c09af99b88a84782fe8082dd6"},
        {"file": RUN_RS, "sha256": NEW_RUN_RS},
        {"file": "src/private_block/boundary.rs", "sha256":
         "5b1c85feefacf61fd97fa6e60b9f72d737f1dd56349ecaa650fc93d3ad0e6581"},
    ]}


# =====================================================================
#  the PURE arm -- the pin table
# =====================================================================
class TheRunRsDigestOfTheTwelveBlockBundles(unittest.TestCase):

    def test_the_new_digest_is_read_with_its_commits_and_bundles(self):
        e = RUN_LAYER_PINS[RUN_RS][NEW_RUN_RS]
        self.assertEqual(e["commits"], (STAGE43, CAPTURE_COMMIT))
        self.assertEqual(set(e["bundles"]), set(L12))
        self.assertEqual(e["bytes"], 56374)
        self.assertEqual(e["blob"], "9a2194457489e682e6a08fd5b58964a7e5984152")

    def test_its_reading_says_what_moved_and_what_did_not(self):
        text = READINGS[(RUN_RS, NEW_RUN_RS)]
        for needle in ("198 added, 17 removed, 10 hunks", "99a8de8",
                       "CS-8", "CS-7", "CS-6", "CS-1 / CS-4",
                       "byte-identical as a sequence", "601e97f",
                       "zk60_native_rg_replay"):
            self.assertIn(needle, text, needle)

    def test_the_two_unmoved_run_layer_files_name_the_capture_commit(self):
        for path, digest in (
                ("src/private_block/run_capture.rs",
                 "d09f385315cac8e7b7fb16a65b0243219e4ba78c09af99b88a84782fe8082dd6"),
                ("src/private_block/boundary.rs",
                 "5b1c85feefacf61fd97fa6e60b9f72d737f1dd56349ecaa650fc93d3ad0e6581")):
            e = RUN_LAYER_PINS[path][digest]
            self.assertEqual(e["commits"][-1], CAPTURE_COMMIT, path)
            self.assertTrue(set(L12) <= set(e["bundles"]), path)

    def test_run_rs_now_has_ten_read_digests_and_every_one_a_reading(self):
        self.assertEqual(len(RUN_LAYER_PINS[RUN_RS]), 10)
        for d in RUN_LAYER_PINS[RUN_RS]:
            self.assertIn((RUN_RS, d), READINGS)


# =====================================================================
#  the REFUSAL arm -- a third digest is still refused
# =====================================================================
class AThirdDigestIsStillRefused(unittest.TestCase):

    def setUp(self):
        self.man = _l12_manifest() if HAVE_L12 else _stand_in_manifest()

    def _with(self, digest):
        man = copy.deepcopy(self.man)
        for p in man["source_pins"]:
            if p["file"] == RUN_RS:
                p["sha256"] = digest
        return _Manifest(man)

    def test_the_twelve_block_pins_are_all_read_digests(self):
        r = check_run_layer_pins(_Manifest(self.man))
        self.assertTrue(r["ok"], r["pins_that_moved"])
        self.assertEqual(len(r["pins_at_a_read_digest"]), 3)
        self.assertEqual(r["stages_not_checked"], {})
        if HAVE_L12:
            # the shared files: every one at a digest this gate read (rng.rs
            # and transcript.rs at round 9i's accepted second digests)
            sh = r["shared_files"]
            self.assertTrue(sh["ok"], sh["pins_that_moved"])
            self.assertEqual(sh["pins_at_an_accepted_second_digest"],
                             ["../zkp-core/src/rng.rs",
                              "../zkp-core/src/transcript.rs"])

    def test_the_previous_digest_is_still_accepted(self):
        self.assertTrue(check_run_layer_pins(self._with(K8_RUN_RS))["ok"])

    def test_a_third_digest_is_refused_by_name_and_suspends_every_stage(self):
        # a digest of REAL-looking bytes: the new digest's hex with one
        # nibble changed, so it differs from every read digest by construction
        third = ("0" if NEW_RUN_RS[0] != "0" else "1") + NEW_RUN_RS[1:]
        self.assertNotIn(third, RUN_LAYER_PINS[RUN_RS])
        r = check_run_layer_pins(self._with(third))
        self.assertFalse(r["ok"])
        self.assertEqual(len(r["pins_that_moved"]), 1)
        self.assertTrue(r["pins_that_moved"][0].startswith(RUN_RS))
        self.assertIn("not one of the 10 digests this gate has read",
                      r["pins_that_moved"][0])
        self.assertEqual(set(r["stages_not_checked"]), set(ALL_STAGES))


# =====================================================================
#  the VALIDATION / run/ arm -- a synthetic directory
# =====================================================================
class _St:
    def __init__(self, k, seg):
        self.index = k
        self.name = f"stage-{k:02d}.json"
        self.doc = {"segment_bytes": len(seg),
                    "segment_sha256": hashlib.sha256(seg).hexdigest()}


class _B:
    def __init__(self, directory, stages):
        self.dir = directory
        self.stages = stages
        self.blocks = len(stages)
        self.schema = "hashline-native-capture/5-run"
        self.profile = "hashline-zk-mr1/private-run-test/1"
        self.run = {"source_commit": "c" * 40}


class TheValidationFileAndTheRunDirectory(unittest.TestCase):
    """Every way `validation_and_run_directory` must refuse, each on its own
    perturbation, and its silence on a bundle that has neither."""

    SEGS = (b"segment zero bytes", b"segment one, a little longer")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        d = self.tmp.name
        self.dir = d
        with open(os.path.join(d, "manifest.json"), "wb") as fh:
            fh.write(b'{"kind": "a manifest"}')
        man_sha = hashlib.sha256(b'{"kind": "a manifest"}').hexdigest()
        os.makedirs(os.path.join(d, RUN_DIR, STATEMENT_DIR))
        for k, seg in enumerate(self.SEGS):
            with open(os.path.join(d, RUN_DIR, f"segment-{k:03d}.bin"), "wb") as fh:
                fh.write(seg)
        stmt = b'{"statement": 1}'
        with open(os.path.join(d, RUN_DIR, STATEMENT_DIR, STATEMENT_FILE), "wb") as fh:
            fh.write(stmt)
        self.bundle = _B(d, [_St(k, s) for k, s in enumerate(self.SEGS)])
        self.v = {
            "schema": self.bundle.schema, "kind": VALIDATION_KIND,
            "profile": self.bundle.profile, "blocks": 2,
            "source_commit": "c" * 40, "reverified_at_commit": "d" * 40,
            "manifest_sha256": man_sha,
            "run_statement_sha256": hashlib.sha256(stmt).hexdigest(),
            "receipt_bytes": sum(len(s) for s in self.SEGS),
            **{k: True for k in VALIDATION_FLAGS},
        }
        self._write_v()

    def tearDown(self):
        self.tmp.cleanup()

    def _write_v(self):
        with open(os.path.join(self.dir, VALIDATION_FILE), "w") as fh:
            json.dump(self.v, fh)

    def _run(self):
        return validation_and_run_directory(self.bundle)

    def test_the_honest_directory_has_no_finding(self):
        v, r, f = self._run()
        self.assertEqual(f, [])
        self.assertTrue(all(v["flags"].values()))
        for k in ("kind_matches", "schema_matches", "profile_matches",
                  "blocks_match", "manifest_sha256_matches",
                  "source_commit_matches"):
            self.assertTrue(v[k], k)
        self.assertEqual(v["reverified_at_commit"], "d" * 40)
        self.assertEqual(r["segments_matching_their_stage_pins"], 2)
        self.assertEqual(r["segment_bytes_total"], sum(len(s) for s in self.SEGS))
        self.assertTrue(r["run_statement"]["matches_validation"])
        self.assertEqual(r["unexpected_entries"], [])

    def test_a_bundle_with_neither_is_silent(self):
        os.remove(os.path.join(self.dir, VALIDATION_FILE))
        import shutil
        shutil.rmtree(os.path.join(self.dir, RUN_DIR))
        self.assertEqual(self._run(), (None, None, []))

    def test_each_flag_false_is_a_finding(self):
        for flag in VALIDATION_FLAGS:
            with self.subTest(flag=flag):
                keep = dict(self.v)
                self.v[flag] = False
                self._write_v()
                _v, _r, f = self._run()
                self.assertEqual(len(f), 1, f)
                self.assertIn("a flag is not true", f[0])
                self.v = keep
                self._write_v()

    def test_a_validation_file_for_another_bundle_is_a_finding(self):
        for key, bad in (("manifest_sha256", "0" * 64), ("source_commit", "e" * 40),
                         ("blocks", 3), ("profile", "another"),
                         ("schema", "hashline-native-capture/4-run"),
                         ("kind", "zk60-block-capture-validation")):
            with self.subTest(key=key):
                keep = dict(self.v)
                self.v[key] = bad
                self._write_v()
                _v, _r, f = self._run()
                self.assertEqual(len(f), 1, f)
                self.assertIn("does not name this bundle", f[0])
                self.v = keep
                self._write_v()

    def test_a_changed_segment_byte_is_refused_by_the_segment_name(self):
        p = os.path.join(self.dir, RUN_DIR, "segment-001.bin")
        with open(p, "r+b") as fh:
            b = fh.read(1)
            fh.seek(0)
            fh.write(bytes([b[0] ^ 1]))
        _v, r, f = self._run()
        self.assertEqual(r["segments_matching_their_stage_pins"], 1)
        self.assertEqual(len(f), 1, f)
        self.assertIn("segment-001.bin", f[0])
        self.assertIn("is not the segment stage-01.json pins", f[0])

    def test_a_missing_segment_and_a_stray_entry_are_findings(self):
        os.remove(os.path.join(self.dir, RUN_DIR, "segment-000.bin"))
        with open(os.path.join(self.dir, RUN_DIR, "segment-002.bin"), "wb") as fh:
            fh.write(b"x")
        _v, r, f = self._run()
        self.assertEqual(len(f), 2, f)
        self.assertTrue(any("segment-000.bin: absent" in x for x in f))
        self.assertTrue(any("segment-002.bin: neither a segment" in x for x in f))
        self.assertEqual(r["unexpected_entries"], ["segment-002.bin"])

    def test_a_statement_that_is_not_the_validated_one_is_a_finding(self):
        with open(os.path.join(self.dir, RUN_DIR, STATEMENT_DIR, STATEMENT_FILE),
                  "wb") as fh:
            fh.write(b'{"statement": 2}')
        _v, r, f = self._run()
        self.assertFalse(r["run_statement"]["matches_validation"])
        self.assertEqual(len(f), 1, f)
        self.assertIn("run_statement_sha256", f[0])

    def test_a_validation_file_that_is_not_json_is_a_finding(self):
        with open(os.path.join(self.dir, VALIDATION_FILE), "w") as fh:
            fh.write("{not json")
        v, _r, f = self._run()
        self.assertTrue(v["present"])
        self.assertTrue(any("not JSON" in x for x in f), f)


if __name__ == "__main__":
    unittest.main()

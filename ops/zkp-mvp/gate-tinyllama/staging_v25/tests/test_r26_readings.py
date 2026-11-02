#!/usr/bin/env python3
"""[v25 staging, 2026-11-02, gate round 26] Tests of the round-26 pin readings
wired into `zk60_native_rg_w16.classify_pins` (`zk60_native_rg_r26readings`)
and of finding F-B1's backend rule.  The table tests read the round-26 JSON
records and run anywhere; the bundle tests need a fresh registered R13 D55
bundle (`ZK60_D55_R13_BUNDLE`, written at the round-26 tree) and an old D60
one (`ZK60_D60_OLD_BUNDLE`, written before F-B1's fix) and skip without
them.  NOTHING HERE IS A PRIVACY STATEMENT."""

import copy
import json
import os
import sys
import types
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "scripts"))

import zk60_native_rg_r26readings as R26  # noqa: E402
import zk60_native_rg_w16 as W  # noqa: E402


def _repo():
    d = HERE
    for _ in range(8):
        if os.path.isdir(os.path.join(d, R26.R26_DIR)):
            return d
        d = os.path.dirname(d)
    return None


REPO = _repo()
BUNDLE = os.environ.get("ZK60_D55_R13_BUNDLE", "")
OLD = os.environ.get("ZK60_D60_OLD_BUNDLE", "")


def _record(rel):
    with open(os.path.join(REPO, rel)) as fh:
        return json.load(fh)


def _classify(manifest):
    return W.classify_pins(types.SimpleNamespace(manifest=manifest), W.default_r19b_manifest())


def _manifest(pins, gpu="absent"):
    m = {"source_pins": [{"file": f, "sha256": d} for f, d in pins]}
    if gpu != "absent":
        m["proved_on_gpu"] = gpu
    return m


def _full(f, prefix):
    return R26.R26_READINGS[(f, prefix)][0]


METAL = ("src/gpu/metal.rs", _full("src/gpu/metal.rs", "a96882bcc671"))
KERNELS = ("src/gpu/metal_kernels.metal", _full("src/gpu/metal_kernels.metal", "be9682364115"))
RUN_RS = ("src/private_block/run.rs", _full("src/private_block/run.rs", "0a8f261578cb"))
MERKLE = ("../zkp-core/src/merkle.rs", _full("../zkp-core/src/merkle.rs", "6b66c0bcf200"))


@unittest.skipUnless(REPO, "the round-26 records are not in this checkout")
class R26Table(unittest.TestCase):
    def test_every_reader_entry_is_wired_at_its_full_digest(self):
        """each (file, prefix) of both readers' wiring tables is in R26_READINGS
        with the FULL digest the reader's `readings` names, and every
        independent R26 entry is in a reader's table"""
        seen = set()
        for rel, reader in ((R26.R26_RUN, R26.RUN_READER), (R26.R26_BLOCK, R26.BLOCK_READER)):
            doc = _record(rel)
            for f, rows in doc["wiring_w16_readings_style"].items():
                if not isinstance(rows, list):
                    continue
                full_digests = set(doc["readings"][f]["readings"])
                for prefix, _text in rows:
                    key = (f, prefix)
                    self.assertIn(key, R26.R26_READINGS, key)
                    full, scope, who, summary, pointer = R26.R26_READINGS[key]
                    self.assertIn(full, full_digests, key)
                    self.assertTrue(full.startswith(prefix))
                    self.assertEqual((scope, who), (R26.FULL, reader), key)
                    self.assertTrue(pointer.startswith(rel), key)
                    self.assertTrue(summary and "\n" not in summary)
                    seen.add(key)
        independent = {k for k, v in R26.R26_READINGS.items() if v[2] != R26.SELF_READ}
        self.assertEqual(independent, seen)
        self.assertEqual(len(seen), 39)

    def test_the_self_read_entries_are_the_wiring_record(self):
        doc = _record(R26.R26_WIRING)
        self.assertTrue(doc["self_read"])
        self_read = {k: v for k, v in R26.R26_READINGS.items() if v[2] == R26.SELF_READ}
        self.assertEqual(sorted(f for f, _p in self_read), sorted(doc["summary"]["new_digests"]))
        for (f, prefix), (full, scope, _who, _s, pointer) in self_read.items():
            self.assertEqual(doc["summary"]["new_digests"][f], full)
            self.assertIn(full, doc["readings"][f]["readings"])
            self.assertEqual(scope, R26.CPU_PATH if f in R26.GPU_BACKEND_SOURCES else R26.FULL)
            self.assertTrue(pointer.startswith(R26.R26_WIRING))
        # the run_capture.rs chain: r19b -> cbb78dc0 (run-level reader) -> the wiring's digest
        rc = doc["readings"]["src/private_block/run_capture.rs"]
        self.assertEqual(rc["base"], _full("src/private_block/run_capture.rs", "cbb78dc04ac5"))

    def test_a_file_on_disk_at_a_wired_digest_rehashes(self):
        """the HEAD digests the table wires are this checkout's files (a pin
        written here classifies as read)"""
        import hashlib
        hl = os.path.join(REPO, "ops/zkp-mvp/gpu-metal/hashline")
        for f, prefix in [("src/private_block/protocol.rs", "6f4d60f5d7fe"), ("src/gpu/metal.rs", "a96882bcc671"),
                          ("src/private_block/run_capture.rs", "10b6d3be860c"), ("../zkp-core/src/rng.rs", "f6728bd2d520")]:
            with open(os.path.join(hl, f), "rb") as fh:
                self.assertEqual(hashlib.sha256(fh.read()).hexdigest(), _full(f, prefix), f)


class R26Classification(unittest.TestCase):
    def test_a_full_digest_is_read_and_a_prefix_twin_or_unknown_digest_is_not(self):
        p = _classify(_manifest([RUN_RS], gpu=False))
        self.assertEqual(p["read_here"], ["src/private_block/run.rs"])
        self.assertTrue(p["ok"])
        twin = RUN_RS[1][:12] + ("0" if RUN_RS[1][12] != "0" else "1") + RUN_RS[1][13:]
        for d in (twin, "ab" * 32):
            p = _classify(_manifest([(RUN_RS[0], d)], gpu=False))
            self.assertEqual([u["file"] for u in p["unread"]], ["src/private_block/run.rs"])
            self.assertFalse(p["ok"])

    def test_a_w16_prefix_reading_does_not_read_a_digest_round_26_reread(self):
        """W16_READINGS names 6b66c0bcf200 for zkp-core's merkle.rs by prefix
        only; round 26 re-read it at its full digest, so a prefix twin stays
        unread"""
        self.assertTrue(W.W16_READINGS["../zkp-core/src/merkle.rs"][0] == "6b66c0bcf200")
        twin = MERKLE[1][:-1] + ("0" if MERKLE[1][-1] != "0" else "1")
        p = _classify(_manifest([(MERKLE[0], twin)], gpu=False))
        self.assertEqual([u["file"] for u in p["unread"]], [MERKLE[0]])
        p = _classify(_manifest([MERKLE], gpu=False))
        self.assertEqual(p["read_here"], [MERKLE[0]])
        self.assertIn(MERKLE[0], p["readings_r26"])

    def test_the_backend_absent_is_refused_as_unknown(self):
        p = _classify(_manifest([RUN_RS]))
        self.assertEqual(p["unread"], [])
        self.assertIsNone(p["backend"]["proved_on_gpu"])
        self.assertFalse(p["backend"]["admissible"])
        self.assertIn("UNKNOWN PROVER BACKEND", p["backend"]["refused"])
        self.assertFalse(p["ok"])

    def test_a_gpu_made_bundle_is_refused_and_its_metal_pins_are_unread(self):
        p = _classify(_manifest([RUN_RS, METAL, KERNELS], gpu=True))
        self.assertFalse(p["backend"]["admissible"])
        self.assertIn("GPU-MADE BUNDLE", p["backend"]["refused"])
        self.assertEqual(sorted(u["file"] for u in p["unread"]), sorted([METAL[0], KERNELS[0]]))
        self.assertTrue(all("CPU-PATH" in u["why"] for u in p["unread"]))
        self.assertFalse(p["ok"])
        # and a GPU-made bundle that does not pin them at all
        p = _classify(_manifest([RUN_RS], gpu=True))
        self.assertIn("not pinned", p["backend"]["refused"])
        self.assertFalse(p["ok"])

    def test_a_cpu_made_bundle_reads_the_metal_pins_at_the_cpu_path_scope_only(self):
        p = _classify(_manifest([RUN_RS, METAL, KERNELS], gpu=False))
        self.assertTrue(p["backend"]["admissible"])
        self.assertEqual(p["unread"], [])
        self.assertEqual(p["readings_r26"][METAL[0]]["scope"], R26.CPU_PATH)
        self.assertEqual(p["self_read_pending_independent_check"], sorted([METAL[0], KERNELS[0]]))
        self.assertTrue(p["ok"])
        # a Metal file at another digest is UNREAD even on a CPU-made bundle
        p = _classify(_manifest([(METAL[0], "cd" * 32)], gpu=False))
        self.assertEqual([u["file"] for u in p["unread"]], [METAL[0]])
        self.assertFalse(p["ok"])

    def test_a_non_boolean_backend_is_refused(self):
        for v in ("false", 0, None):
            p = _classify(_manifest([RUN_RS], gpu=v))
            self.assertFalse(p["backend"]["admissible"], v)
            self.assertFalse(p["ok"], v)


@unittest.skipUnless(BUNDLE and os.path.isdir(BUNDLE), "set ZK60_D55_R13_BUNDLE to a registered R13 D55 bundle of the round-26 tree")
class R26FreshBundle(unittest.TestCase):
    def test_every_moved_pin_is_read_and_the_backend_is_admissible(self):
        with open(os.path.join(BUNDLE, "manifest.json")) as fh:
            man = json.load(fh)
        p = _classify(man)
        self.assertIs(man.get("proved_on_gpu"), False)
        self.assertEqual(p["unread"], [])
        self.assertTrue(p["backend"]["admissible"])
        self.assertTrue(p["ok"])
        self.assertEqual(p["pins"], p["at_r19b"] + len(p["read_here"]))
        files = [x["file"] for x in man["source_pins"]]
        self.assertIn(METAL[0], files)
        self.assertIn(KERNELS[0], files)
        # the D55 driver's controls on doctored copies of this manifest
        import zk60_native_rg_d55 as D
        c = D.pin_controls(types.SimpleNamespace(manifest=copy.deepcopy(man)), W.default_r19b_manifest())
        self.assertTrue(c["ok"], {k: v["fires"] for k, v in c["controls"].items()})


@unittest.skipUnless(OLD and os.path.isdir(OLD), "set ZK60_D60_OLD_BUNDLE to a D60 bundle written before F-B1's fix")
class R26OldD60Bundle(unittest.TestCase):
    def test_every_pin_is_read_but_the_backend_is_unknown(self):
        with open(os.path.join(OLD, "manifest.json")) as fh:
            man = json.load(fh)
        self.assertNotIn("proved_on_gpu", man)
        p = _classify(man)
        self.assertEqual(p["unread"], [])
        self.assertFalse(p["backend"]["admissible"])
        self.assertFalse(p["ok"])


if __name__ == "__main__":
    unittest.main()

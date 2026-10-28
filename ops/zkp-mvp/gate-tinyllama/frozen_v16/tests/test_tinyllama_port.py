"""Tests of the TinyLlama port of the run gate (privacy-gate lane,
2026-10-17).  They pin what the port PROMISES: at every frozen shape it
computes exactly what the original tools computed, and at a trained shape it
reads the constants the Rust relations were built with.

    python3 -m unittest discover -s ops/zkp-mvp/gate-tinyllama/tests

Pure reading of committed / retained bundles; no proof is made.
"""

import importlib.util
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = os.path.join(os.path.dirname(HERE), "scripts")
ORIG = os.path.join(os.path.dirname(HERE), "original")
sys.path.insert(0, PORT)

import zk60_native_rg_terminals as T  # noqa: E402
import zk60_native_rg_tinyllama_pins as TP  # noqa: E402

K4 = "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-i-dense-k4"
M125 = "/home/victor/zk60-artifacts/m125-capture-dense-l2"
TL = "/home/victor/zk60-artifacts/tinyllama-trained-capture-dense-l2"


def _load_original(name):
    """the ORIGINAL module, from the untouched copy, under another name"""
    spec = importlib.util.spec_from_file_location(
        "orig_" + name, os.path.join(ORIG, name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    saved = list(sys.path)
    sys.path.insert(0, ORIG)
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.path[:] = saved
    return mod


def _shape(path):
    with open(os.path.join(path, "run.json")) as fh:
        return json.load(fh)["shape"]


def _counts(sh):
    """the byte-limb counts `lookups_at` takes: ceil(window / 8)"""
    return {"ln": -(-sh["norm_wrho"] // 8), "ls": -(-sh["wrho_s"] // 8),
            "lp": -(-(T.F_P + 1) // 8)}


class Calibration(unittest.TestCase):
    def test_a_frozen_shape_reads_the_frozen_literals(self):
        c = T.Calibration({"name": "x"})
        self.assertFalse(c.trained)
        self.assertEqual(c.values, T.FROZEN_CALIBRATION)
        self.assertEqual((c.norm_tn, c.norm_cn_a, c.norm_cn_m, c.norm_ceps),
                         (11, 1024, 1024, 1))
        self.assertEqual((c.sh_ao, c.sh_qkv, c.sh_s, c.sh_o, c.sh_g, c.sh_h,
                          c.sh_z), (7, 7, 6, 9, 7, 14, 6))

    def test_the_frozen_top_limb_pins_are_the_historical_literals(self):
        one, two, f = T.Calibration.one, T.Calibration.two, T.FROZEN_CALIBRATION
        self.assertEqual([one(f["sh_ao"]), one(f["sh_z"]), one(f["sh_g"]),
                          two(f["sh_h"]), one(f["sh_qkv"]), two(f["sh_o"]),
                          one(f["sh_s"])], [2, 4, 2, 4, 2, 128, 4])
        self.assertEqual(T.Calibration.half(0), 0)
        self.assertEqual(T.Calibration.half(7), 64)

    @unittest.skipUnless(os.path.isdir(TL), "the trained bundle is not on disk")
    def test_the_trained_bundle_declares_pg_rot1(self):
        c = T.Calibration(_shape(TL))
        self.assertTrue(c.trained)
        self.assertEqual(c.values, {"norm_tn": 10, "norm_cn_a": 3999,
                                    "norm_cn_m": 3122, "norm_ceps": 91255,
                                    "sh_ao": 3, "sh_qkv": 8, "sh_s": 6,
                                    "sh_o": 9, "sh_g": 8, "sh_h": 14,
                                    "sh_z": 5})

    def test_a_mixed_declaration_is_refused(self):
        with self.assertRaises(ValueError):
            T.Calibration({"norm_tn": 10})
        with self.assertRaises(ValueError):
            T.Calibration({"trained_calibration": True, "norm_tn": 10})
        with self.assertRaises(ValueError):
            T.Calibration({**T.FROZEN_CALIBRATION, "trained_calibration": False})


class FrozenShapesUnchanged(unittest.TestCase):
    """the port's `lookups_at` equals the ORIGINAL's at every frozen shape"""

    def _compare(self, path):
        orig = _load_original("zk60_native_rg_terminals")
        sh = _shape(path)
        counts = _counts(sh)
        for dom in ("L", "D", "F", "Q", "Kv", "S"):
            self.assertEqual(T.lookups_at(dom, counts, sh),
                             orig.lookups_at(dom, counts, sh), dom)

    @unittest.skipUnless(os.path.isdir(K4), "rung-K4 bundle not on disk")
    def test_rung_k4(self):
        self._compare(K4)

    @unittest.skipUnless(os.path.isdir(M125), "125M bundle not on disk")
    def test_m125(self):
        self._compare(M125)

    @unittest.skipUnless(os.path.isdir(TL), "the trained bundle is not on disk")
    def test_the_trained_shape_moves_exactly_the_windowed_pins(self):
        orig = _load_original("zk60_native_rg_terminals")
        sh = _shape(TL)
        counts = _counts(sh)
        moved = {}
        for dom in ("D", "F", "Q", "Kv", "S"):
            a, b = T.lookups_at(dom, counts, sh), orig.lookups_at(dom, counts, sh)
            self.assertEqual(len(a), len(b))
            for x, y in zip(a, b):
                if x != y:
                    moved[x[0][0][0]] = (y[0][0][1], x[0][0][1])
        # pg_rot1: sh_ao 3, sh_z 5, sh_g 8, sh_qkv 8 move; sh_h 14, sh_o 9,
        # sh_s 6 coincide with the frozen shifts
        self.assertEqual(moved, {"A_RAL": (2, 32), "A_RDL": (4, 8),
                                 "A_RGL": (2, 1), "A_RQL": (2, 1),
                                 "A_RKL": (2, 1), "A_RVL": (2, 1)})


class Pins(unittest.TestCase):
    def test_every_tinyllama_digest_carries_a_reading(self):
        for path, digests in TP.RUN_LAYER_PINS.items():
            for d in digests:
                self.assertIn((path, d), TP.READINGS)
                self.assertTrue(TP.READINGS[(path, d)].startswith("[TINYLLAMA PORT"))
        for table in (TP.SHARED_ALSO_READ, TP.TERMINALS_ALSO_ACCEPTED,
                      TP.TERMINALS_PINNED_IF_PRESENT):
            for path, digests in table.items():
                for d, reading in digests.items():
                    self.assertEqual(len(d), 64)
                    self.assertIn("TINYLLAMA PORT", reading)
        for d, (name, reading) in TP.ARGUMENT_DEFINITIONS.items():
            self.assertEqual(name, "repaired")
            self.assertIn("TINYLLAMA PORT", reading)

    def test_the_merge_never_replaces_a_reading(self):
        table = {"f": {"a" * 64: "old"}}
        with self.assertRaises(ValueError):
            TP.merge_two_level(table, {"f": {"a" * 64: "new"}}, "t")
        self.assertEqual(table["f"]["a" * 64], "old")
        with self.assertRaises(ValueError):
            TP.merge_one_level({"k": 1}, {"k": 2}, "t")

    def test_every_original_pin_survives_the_merge(self):
        for mod, names in (("zk60_native_rg_runpins",
                            ("RUN_LAYER_PINS", "READINGS", "SHARED_ALSO_READ",
                             "SHARED_LAYER_PINS")),
                           ("zk60_native_rg_terminals",
                            ("ALSO_ACCEPTED", "PINNED_IF_PRESENT", "PORTED_FROM")),
                           ("zk60_native_rg_gqa", ("ARGUMENT_DEFINITIONS",)),
                           ("zk60_native_rg_mask", ("MASK_LAYER_PINS",))):
            orig = _load_original(mod)
            port = __import__(mod)
            for n in names:
                o, p = getattr(orig, n), getattr(port, n)
                for k, v in o.items():
                    self.assertIn(k, p, f"{mod}.{n} lost {k}")
                    if isinstance(v, dict):
                        for kk, vv in v.items():
                            self.assertEqual(p[k][kk], vv, f"{mod}.{n}[{k}][{kk}]")
                    else:
                        self.assertEqual(p[k], v, f"{mod}.{n}[{k}]")


if __name__ == "__main__":
    unittest.main()

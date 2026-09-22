"""Tests for round 9c, task C: the LANE's slot-expression IR export read as
a CROSS-CHECK of this gate's hand port.

Run:
  python3 -m unittest discover -s tests \
      -p "test_zk60_native_run_gate_slotir.py"

WHAT THIS IS.  Lane stage 34 exported every registered shape's twenty-three
slot polynomials as canonical JSON (`zk60-slot-ir/1`), each file pinned by
SHA-256 and by length in a Rust test.  It carries table ids, kinds, field
kinds, degrees and coefficient PROVENANCE, and no challenge value.  This
gate's evaluator is, and stays, the hand port (ruling I-8 of
`ZK60_SLOT_EXPRESSION_IR_DISPOSITION.md`): the export is read here as a
second opinion about the SHAPE of every slot polynomial, never as an input
to a figure.

EIGHT COMPARISONS PER SLOT, at every shape a bundle exists for: the table
count, the table kind sequence in push order, the private plane sequence
against the plane index, the public table sequence against this port's
`PUBLIC_SPEC`, the declared degree, the main and extension round counts,
`pad_on` against `PadGeometry.pads` over the domains the slot hosts, the
two bilinear slots' group bits, and the byte-limb LogUp helper count
against `lookups_at`.

THREE ARMS.

* A PURE arm that needs no bundle: the export files themselves, read and
  checked against the lane's own pinned length and digest, and the
  shape-to-shape statements a reader can make from them alone (correction
  C-6 moves slot 14 and nothing else; the pad rule moves slots 02, 16 and
  18 and nothing else).
* The RECORDED arm: the committed cross-check record.
* The LIVE arm, skipped when the bundles are absent: the comparison re-run.

Nothing here asserts a privacy property, and nothing here is evaluated.
"""

from __future__ import annotations

import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_9c")
RECORD = os.path.join(EVIDENCE, "slot_ir_crosscheck.json")
BUNDLES = os.environ.get(
    "ZK60_RUN_BUNDLES",
    "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920",
)
ARTIFACTS = os.environ.get("ZK60_ARTIFACTS", "/home/victor/zk60-artifacts")

import zk60_native_rg_slotir as sir  # noqa: E402

HAVE_EXPORT = os.path.isdir(sir.EXPORT_DIR)
HAVE_RECORD = os.path.isfile(RECORD)

# (export key, bundle directory) for every shape this lane has a bundle for.
PAIRS = (
    ("rung_g", os.path.join(BUNDLES, "run-g-dense-s20")),
    ("rung_k4", os.path.join(BUNDLES, "run-i-dense-k4")),
    ("rung_p2", os.path.join(BUNDLES, "run-k-dense-p2")),
    ("rung_c6", os.path.join(BUNDLES, "run-m-dense-c6")),
    ("rung_w14", os.path.join(ARTIFACTS, "run-o-dense-w14")),
    ("rung_e32", os.path.join(BUNDLES, "run-q-dense-e32")),
    ("m125", os.path.join(ARTIFACTS, "m125-capture-dense-l2")),
)
LIVE = tuple((k, d) for k, d in PAIRS if os.path.isdir(d))


@unittest.skipUnless(HAVE_EXPORT, "the lane's x34-slot-ir export is absent")
class TheExportItself(unittest.TestCase):
    """The pure arm: the nine files, at the lane's own pins."""

    def test_every_export_matches_the_lane_pin(self):
        for key in sir.PINNED:
            with self.subTest(key):
                d = sir.load_export(key)      # raises on a pin mismatch
                self.assertEqual(d["schema"], "zk60-slot-ir/1")
                self.assertEqual(d["slot_count"], 23)
                self.assertEqual(len(d["slots"]), 23)
                self.assertTrue(d["_pin_checked"])

    def test_nine_shapes_are_exported(self):
        self.assertEqual(len(sir.PINNED), 9)

    def test_correction_C6_moves_slot_14_and_nothing_else(self):
        """C-6 drops four `Dom::D` lookups, so slot 14 loses two tables and
        two terminals -- and no other slot's table count moves between a
        shape where C-6 is off and one where it is on."""
        off = sir.load_export("rung_p2")
        on = sir.load_export("rung_c6")
        moved = [s for s in range(23)
                 if len(off["slots"][s]["tables"])
                 != len(on["slots"][s]["tables"])]
        self.assertEqual(moved, [14])
        self.assertEqual(len(off["slots"][14]["tables"]) -
                         len(on["slots"][14]["tables"]), 2)

    def test_the_pad_rule_moves_slots_02_16_and_18_and_nothing_else(self):
        """rung-K4 pads every domain; rung-P2 is the same padded layout with
        T, Kv and F sitting exactly on their pads.  `pad_on` must differ at
        exactly their three host slots -- finding M-F1's own statement, made
        against the lane's export rather than against this port."""
        k4 = sir.load_export("rung_k4")
        p2 = sir.load_export("rung_p2")
        moved = [s for s in range(23)
                 if k4["slots"][s]["pad_on"] != p2["slots"][s]["pad_on"]]
        self.assertEqual(moved, [2, 16, 18])
        for s in moved:
            self.assertTrue(k4["slots"][s]["pad_on"])
            self.assertFalse(p2["slots"][s]["pad_on"])

    def test_the_three_new_shapes_carry_125Ms_pad_set_and_C6(self):
        m125 = sir.load_export("m125")
        for key in ("rung_c6", "rung_w14", "rung_e32"):
            with self.subTest(key):
                d = sir.load_export(key)
                self.assertEqual([s["pad_on"] for s in d["slots"]],
                                 [s["pad_on"] for s in m125["slots"]])
                # C-6: slot 14 carries 60 tables and 125M carries 60 too
                self.assertEqual(len(d["slots"][14]["tables"]),
                                 len(m125["slots"][14]["tables"]))

    def test_no_coefficient_carries_a_challenge_value(self):
        """A value appears beside a coefficient ONLY where the provenance
        says it is a public constant of the shape.  That is what makes the
        export pinnable per shape; a challenge-dependent value would make it
        a transcript."""
        public = ("one", "neg-one")
        for key in ("rung_c6", "rung_w14", "rung_e32"):
            d = sir.load_export(key)
            for slot in d["slots"]:
                for coef in _every_coefficient(slot):
                    if "value" in coef:
                        prov = coef["prov"]
                        self.assertTrue(
                            prov in public or prov.startswith("kbase:"),
                            f"{key} slot {slot['slot']}: a value beside "
                            f"provenance {prov!r}",
                        )


def _every_coefficient(slot):
    for n in slot["nodes"]:
        if "konst" in n:
            yield n["konst"]
        for t in n.get("terms", []):
            yield t["coef"]
        for st in n.get("subterms", []):
            yield st["coef"]
    for t in slot["terms"]:
        yield t["coef"]


@unittest.skipUnless(HAVE_RECORD, "the cross-check record is not committed")
class TheRecord(unittest.TestCase):
    """The recorded arm: what round 9c committed."""

    @classmethod
    def setUpClass(cls):
        with open(RECORD) as fh:
            cls.r = json.load(fh)

    def test_seven_shapes_were_compared(self):
        self.assertEqual(self.r["shapes"], 7)
        self.assertEqual(
            sorted(x["shape"] for x in self.r["per_shape"]),
            ["m125", "rung_c6", "rung_e32", "rung_g", "rung_k4", "rung_p2",
             "rung_w14"],
        )

    def test_the_comparison_count_is_eight_per_slot_per_shape(self):
        self.assertEqual(self.r["comparisons"], 7 * 8 * 23)

    def test_zero_disagreements(self):
        self.assertEqual(self.r["disagreements"], 0, self.r["per_shape"])
        self.assertTrue(self.r["ok"])

    def test_every_export_read_was_pin_checked(self):
        for x in self.r["per_shape"]:
            self.assertTrue(x["export_pin_checked"], x["shape"])

    def test_the_record_says_it_is_a_cross_check_and_not_the_evaluator(self):
        self.assertIn("CROSS-CHECK", self.r["what"])
        self.assertIn("not a replacement for the hand port",
                      self.r["what_this_is_not"])


@unittest.skipUnless(HAVE_EXPORT and LIVE, "no bundle on this box")
class TheComparisonReRun(unittest.TestCase):
    """The live arm: the comparison itself, on whatever bundles are here."""

    def test_no_disagreement_at_any_shape_with_a_bundle(self):
        out = sir.run(list(LIVE))
        self.assertEqual(out["disagreements"], 0,
                         [x["disagreements"] for x in out["per_shape"]])
        self.assertEqual(out["comparisons"], 8 * 23 * len(LIVE))

    def test_the_declared_degree_agrees_three_ways(self):
        """Export, capture and the shape's own `slots` triple."""
        out = sir.run(list(LIVE))
        for x in out["per_shape"]:
            for row in x["slots"]:
                with self.subTest(shape=x["shape"], slot=row["slot"]):
                    d = row["declared_degree"]
                    self.assertEqual(d["export"], d["capture"])
                    self.assertEqual(d["export"], d["shape"])

    def test_pad_on_agrees_with_this_ports_pad_geometry(self):
        out = sir.run(list(LIVE))
        for x in out["per_shape"]:
            for row in x["slots"]:
                with self.subTest(shape=x["shape"], slot=row["slot"]):
                    self.assertTrue(row["pad_on"]["equal"])

    def test_the_two_bilinear_slots_carry_log2_kv_heads_group_bits(self):
        out = sir.run(list(LIVE))
        for x in out["per_shape"]:
            for row in x["slots"]:
                if row["slot"] in (8, 9):
                    with self.subTest(shape=x["shape"], slot=row["slot"]):
                        self.assertTrue(row["group_bits"]["equal"])
                        self.assertIsNotNone(row["group_bits"]["export"])


@unittest.skipUnless(HAVE_EXPORT and LIVE, "no bundle on this box")
class TheControls(unittest.TestCase):
    """SIX perturbations of the export, each of which MUST be refused by
    name.  A comparison that reports zero disagreements is worth nothing
    unless a wrong export would have produced one -- the K4-F1 rule.  The
    export on disk is never touched: each control mutates an in-memory
    copy.
    """

    @classmethod
    def setUpClass(cls):
        from zk60_native_rg_bundle import RunBundle
        cls.key, cls.dir = LIVE[0]
        cls.bundle = RunBundle(cls.dir)

    def _fires(self, mutate, slot, what):
        import copy
        e = copy.deepcopy(sir.load_export(self.key))
        mutate(e)
        out = sir.compare(e, self.bundle)
        hits = [d for d in out["disagreements"]
                if d["slot"] == slot and d["what"] == what]
        self.assertTrue(
            hits, f"the perturbation at slot {slot} ({what}) was NOT caught; "
            f"disagreements reported: {out['disagreements']}")
        self.assertFalse(out["ok"])

    def test_a_dropped_table_is_caught(self):
        self._fires(lambda e: e["slots"][14]["tables"].pop(), 14,
                    "table count")

    def test_a_swapped_private_plane_is_caught(self):
        def m(e):
            t = e["slots"][14]["tables"]
            priv = [i for i, x in enumerate(t) if x["kind"] in ("A", "H")]
            a, b = priv[0], priv[1]
            t[a], t[b] = t[b], t[a]
        self._fires(m, 14, "the private plane sequence")

    def test_a_flipped_pad_on_is_caught(self):
        self._fires(lambda e: e["slots"][14].__setitem__(
            "pad_on", not e["slots"][14]["pad_on"]), 14, "pad_on")

    def test_a_moved_declared_degree_is_caught(self):
        self._fires(lambda e: e["slots"][17].__setitem__(
            "declared_degree", e["slots"][17]["declared_degree"] + 1), 17,
            "declared degree")

    def test_a_moved_group_bit_count_is_caught(self):
        self._fires(lambda e: e["slots"][8].__setitem__(
            "group_bits", e["slots"][8]["group_bits"] + 1), 8, "group_bits")

    def test_a_dropped_logup_helper_is_caught(self):
        def m(e):
            t = e["slots"][14]["tables"]
            i = next(i for i, x in enumerate(t) if x["kind"] == "H")
            t[i] = dict(t[i], kind="pub", label="supp(D)", prov="x")
        # the helper count AND the kind sequence both move; the LogUp
        # comparison is the one this control is about
        self._fires(m, 14, "the LogUp byte-limb helper count")

    def test_a_pin_mismatch_refuses_before_a_byte_is_compared(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            src = os.path.join(sir.EXPORT_DIR, f"slot_ir_{self.key}.json")
            dst = os.path.join(d, f"slot_ir_{self.key}.json")
            with open(src) as fh:
                raw = fh.read()
            with open(dst, "w") as fh:
                fh.write(raw + " ")
            with self.assertRaises(ValueError) as cm:
                sir.load_export(self.key, directory=d)
            self.assertIn("the lane pins", str(cm.exception))


if __name__ == "__main__":
    unittest.main()

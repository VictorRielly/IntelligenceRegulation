"""Tests for round 9k: control C3c -- one blinding row shared between the two
external endpoints of a STANDALONE block (ruling HB-4 of
`ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK_DISPOSITION.md`, finding F-8 of the
check beside it).

Run:
  python3 -m unittest discover -s tests -p "test_zk60_native_run_gate_c3c.py"

THREE ARMS.

* A PURE arm: the mechanism on a small model with an endpoint's geometry
  (data rows, one claim pair, a proximity pair, one spare row): sharing the
  claim row raises the joint by one message width; sharing the spare row
  does not move it.
* The RECORDED arm: the rung-G block records re-taken this round and the two
  125M C3c records carry exactly the figures written in
  `results/zk60_native_run_gate_9k/prediction_by_hand.json` BEFORE the
  control first ran, and the honest bundle still passes every stage.
* The LIVE arm, skipped when the rung-G bundles are absent: the control on
  real bytes, that it leaves the honest stage-4 figure untouched, and that a
  shared SPARE row leaves the real figure where it was (the ledger's R9k.2
  says so; here it is computed).

Nothing here asserts a privacy property.
"""

from __future__ import annotations

import json
import os
import random
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

BLOCK_EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_block")
EVIDENCE = os.path.join(ROOT, "results", "zk60_native_run_gate_9k")
LANE = os.environ.get("ZK60_BLOCK125M_LANE", "/home/victor/wt-zk60-block125m")
RUNG_G = os.path.join(LANE, "results", "zk60_block_captures_20260923", "rung-g")
DENSE = os.path.join(RUNG_G, "rung-g-dense")
ZERO = os.path.join(RUNG_G, "rung-g-zero")
HAVE_BLOCKS = os.path.isdir(DENSE) and os.path.isdir(ZERO)

import zk60_native_run_gate as gate  # noqa: E402
import zk60_native_rg_block as blk  # noqa: E402
from zk60_native_jv_field import P  # noqa: E402
from zk60_native_jv_joint import Block, JointSystem  # noqa: E402

C3C = "C3c_a_blinding_row_shared_between_the_two_external_endpoints"
FIGURE_KEYS = ("identified_rows", "rank_all", "rank_on_non_data", "k0",
               "joint_fp", "sum_of_parts_fp", "block_diagonal")


def _prediction():
    with open(os.path.join(EVIDENCE, "prediction_by_hand.json")) as fh:
        return json.load(fh)


def _load(path):
    if not os.path.exists(path):
        return None
    with open(path) as fh:
        return json.load(fh)


def _matches(test, got, want, where):
    test.assertEqual(got["matrix"],
                     f"{want['generators']} x {want['coordinate_classes']}", where)
    for k in FIGURE_KEYS:
        test.assertEqual(got[k], want[k], f"{where}: {k}")
    if "u_row_term_fp" in want:
        test.assertEqual(got["u_row_term_fp"], want["u_row_term_fp"], where)


# =====================================================================
#  the PURE arm
# =====================================================================
def _endpoint(name, rng, data=4):
    """An endpoint's geometry: `data` data rows, the claim pair (s, s+1),
    the proximity pair and one spare row.  The one claim reads the data rows
    and the claim pair only; the proximity combination reads every row."""
    rows = data + 5
    s = data

    def f2():
        return (rng.randrange(P), rng.randrange(P))

    claim = [f2() if i <= s + 1 else (0, 0) for i in range(rows)]
    prox = [f2() for _ in range(rows)]
    return Block(name, rows, list(range(data)), [], [claim, prox]), s, rows - 1


class TheMechanismOnASmallModel(unittest.TestCase):
    W = 16  # a message width; any positive value

    def setUp(self):
        rng = random.Random(9)
        self.ei, self.s, self.spare = _endpoint("I", rng)
        self.eo, _, _ = _endpoint("O", rng)

    def _joint(self, ids=()):
        return JointSystem([self.ei, self.eo], identifications=ids).disclosed(
            msg_width=self.W)

    def test_honest_the_two_endpoints_disclose_nothing_jointly(self):
        f = self._joint()
        self.assertEqual((f["rank_all"], f["rank_on_non_data"], f["k0"],
                          f["disclosed_fp"]), (8, 8, 0, 0))

    def test_a_shared_claim_row_unmasks_one_functional(self):
        f = self._joint([(("I", self.s), ("O", self.s))])
        self.assertEqual((f["rank_all"], f["rank_on_non_data"], f["k0"],
                          f["disclosed_fp"]), (8, 7, 1, self.W))

    def test_a_shared_spare_row_unmasks_nothing(self):
        f = self._joint([(("I", self.spare), ("O", self.spare))])
        self.assertEqual((f["rank_on_non_data"], f["k0"], f["disclosed_fp"]),
                         (8, 0, 0))


# =====================================================================
#  the RECORDED arm
# =====================================================================
class ThePredictionWasWrittenFirst(unittest.TestCase):
    def test_the_prediction_names_the_control_and_both_shapes(self):
        p = _prediction()
        self.assertEqual(p["control"], C3C)
        self.assertIn("before the control ran", p["written"])
        for shape, w in (("rung-g", 1024), ("m125", 16384)):
            self.assertEqual(p["msg_width"][shape], w)
            for system in ("pair", "whole_block"):
                h = p[system][shape]["honest"]
                q = p[system][shape]["perturbed"]
                self.assertEqual(q["joint_fp"] - h["joint_fp"], w)
                self.assertEqual(q["sum_of_parts_fp"], h["sum_of_parts_fp"])
                self.assertEqual(q["rank_on_non_data"], h["rank_on_non_data"] - 1)
                self.assertEqual(q["rank_all"], h["rank_all"])


class TheRecordedC3cAtRungG(unittest.TestCase):
    NAMES = ("block-rung-g-dense", "block-rung-g-zero")

    def _recs(self):
        out = {n: _load(os.path.join(BLOCK_EVIDENCE, f"{n}.json")) for n in self.NAMES}
        out = {k: v for k, v in out.items() if v is not None}
        if not out:
            self.skipTest("no rung-G block record is in the tree")
        return out

    def test_the_records_came_from_the_tool_bytes_now_in_the_tree(self):
        now = gate.tool_hashes()
        for n, r in self._recs().items():
            self.assertEqual(r["tool_sha256"], now, n)

    def test_the_prediction_held(self):
        p = _prediction()
        for n, r in self._recs().items():
            c = r["stage6_negative_controls"][C3C]
            self.assertTrue(c["fires"], n)
            self.assertTrue(c["marginals_unchanged"], n)
            self.assertEqual(c["one_message_width_fp"], 1024, n)
            self.assertIn(f"E-Input[{p['shared_row']['rung-g']}]", c["what"])
            self.assertIn(f"E-Output[{p['shared_row']['rung-g']}]", c["what"])
            for system in ("pair", "whole_block"):
                for side in ("honest", "perturbed"):
                    _matches(self, c[system][side], p[system]["rung-g"][side],
                             f"{n} {system} {side}")
                self.assertEqual(c[system]["rise_fp"], 1024)
            self.assertEqual(c["whole_block"]["perturbed"]["parts_fp"],
                             p["parts_fp"])

    def test_the_honest_figure_is_stage_4s_and_every_stage_still_passes(self):
        for n, r in self._recs().items():
            with self.subTest(n):
                self.assertTrue(r["ok"])
                for k in [k for k in r if k.startswith("stage")]:
                    self.assertTrue(r[k]["ok"], k)
                w = r["stage4_the_boundary"]["whole_run"]
                h = r["stage6_negative_controls"][C3C]["whole_block"]["honest"]
                self.assertEqual((h["matrix"], h["joint_fp"], h["sum_of_parts_fp"]),
                                 (w["matrix"], w["joint_fp"], w["sum_of_parts_fp"]))
                s6 = r["stage6_negative_controls"]
                self.assertTrue(s6["all_fire"])
                self.assertEqual(s6["controls"][-1], C3C)
                self.assertEqual(len(s6["controls"]), 6)
                self.assertFalse(r["privacy_property_established"])

    def test_dense_and_zero_read_the_same(self):
        recs = self._recs()
        if len(recs) != 2:
            self.skipTest("one of the two rung-G records is missing")
        a, b = (recs[n]["stage6_negative_controls"][C3C] for n in self.NAMES)
        for system in ("pair", "whole_block"):
            self.assertEqual(a[system], b[system], system)


class TheRecordedC3cAt125M(unittest.TestCase):
    NAMES = ("block-m125-dense-c3c", "block-m125-zero-c3c")

    def _recs(self):
        out = {n: _load(os.path.join(EVIDENCE, f"{n}.json")) for n in self.NAMES}
        out = {k: v for k, v in out.items() if v is not None}
        if not out:
            self.skipTest("no 125M C3c record is in the tree")
        return out

    def test_the_prediction_held(self):
        p = _prediction()
        for n, r in self._recs().items():
            s6 = r["stage6_negative_controls"]["run_controls"]
            c = s6[C3C]
            self.assertTrue(c["fires"], n)
            self.assertTrue(c["marginals_unchanged"], n)
            self.assertEqual(c["one_message_width_fp"], 16384, n)
            self.assertIn(f"E-Input[{p['shared_row']['m125']}]", c["what"])
            for system in ("pair", "whole_block"):
                for side in ("honest", "perturbed"):
                    _matches(self, c[system][side], p[system]["m125"][side],
                             f"{n} {system} {side}")
                self.assertEqual(c[system]["rise_fp"], 16384)
            self.assertTrue(s6["all_fire"], n)
            self.assertEqual(len(s6["controls"]), 6, n)

    def test_the_honest_whole_block_is_the_records_stage_4(self):
        for n, r in self._recs().items():
            w = r["stage4_the_boundary"]["whole_run"]
            h = r["stage6_negative_controls"]["run_controls"][C3C]["whole_block"]["honest"]
            self.assertEqual((h["matrix"], h["joint_fp"], h["sum_of_parts_fp"]),
                             (w["matrix"], w["joint_fp"], w["sum_of_parts_fp"]), n)
            self.assertEqual((w["joint_fp"], w["sum_of_parts_fp"]), (2, 2), n)
            self.assertFalse(r["privacy_property_established"], n)


# =====================================================================
#  the LIVE arm
# =====================================================================
@unittest.skipUnless(HAVE_BLOCKS, "the rung-G block bundles are not on this machine")
class TheLiveRungGControl(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from zk60_native_rg_joint import discover_shared_planes
        cls.b = blk.load_bundle(DENSE)
        cls.replay = blk.BlockReplay(cls.b).run()
        _, cls.views = gate.stage3(cls.b, cls.replay, pad_rank=False,
                                   terminal_note=dict(gate.PER_SLOT_TERMINAL_OPEN))
        cls.shared = discover_shared_planes(cls.b)

    def test_it_fires_and_leaves_the_honest_figure_where_it_was(self):
        before = gate._stage4_block(self.b, self.views, self.shared)["whole_run"]
        out = blk.block_controls(self.b, None, self.views, self.replay, self.shared)
        after = gate._stage4_block(self.b, self.views, self.shared)["whole_run"]
        c = out[C3C]
        self.assertTrue(c["fires"])
        p = _prediction()
        for system in ("pair", "whole_block"):
            for side in ("honest", "perturbed"):
                _matches(self, c[system][side], p[system]["rung-g"][side],
                         f"{system} {side}")
        for k in ("matrix", "joint_fp", "sum_of_parts_fp", "identified_rows", "ok"):
            self.assertEqual(before[k], after[k], k)
        self.assertEqual((after["joint_fp"], after["sum_of_parts_fp"]), (2, 2))

    def test_a_shared_spare_row_leaves_the_real_figure_where_it_was(self):
        from zk60_native_rg_joint import run_wide_figure
        st = self.b.stages[0]
        spares = [self.views[k].facts["spare_mask_rows"] for k in ("E-Input", "E-Output")]
        self.assertEqual(len(spares[0]), 1)
        self.assertEqual(len(spares[1]), 1)
        one = [(("E-Input", spares[0][0]), ("E-Output", spares[1][0]))]
        self.assertNotIn(spares[0][0], st.role("Input")["site_rows"])
        w = run_wide_figure(self.b, self.views, self.shared, extra_identifications=one)
        self.assertEqual((w["joint_fp"], w["sum_of_parts_fp"]), (2, 2))
        self.assertEqual(w["joint_detail"]["rank_on_non_data"], 104)
        self.assertFalse(w["non_data_block_is_block_diagonal_by_role"])


if __name__ == "__main__":
    unittest.main()

"""[ZK60-CL8] Tests for the symbolic pending-block memory accounting tool.

No GPU, no datasets, no tensors. The calibration tests are the important ones:
if the resident model stops reproducing the independently derived 13,492 MiB,
the model has drifted from the source and every other number it prints is
suspect.
"""

import importlib.util
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_SRC = os.path.join(os.path.dirname(_HERE), "scripts", "hashline_cl_pending_memory.py")
_spec = importlib.util.spec_from_file_location("hashline_cl_pending_memory", _SRC)
mem = importlib.util.module_from_spec(_spec)
# register before exec: dataclasses resolve annotations through sys.modules, and
# on 3.10 a module loaded by path without this raises inside @dataclass
sys.modules[_spec.name] = mem
_spec.loader.exec_module(mem)


class Calibration(unittest.TestCase):
    """Reproduce counts that were derived independently, by other routes."""

    def test_resident_reproduces_the_m1_planner_figure(self):
        # M1's pure planner and CL1's hand derivation both give 13,492.043 MiB
        # for the Mistral W commitment. A third route must agree exactly.
        plan = mem.resident_hiding_commit(rows=10774, log_cols=14, inv_rate=4,
                                          q_pad=256, ntt_max_log=16)
        r = plan.report()
        self.assertTrue(r["complete"])
        self.assertEqual(r["peak_event"], "column_hashes")
        self.assertAlmostEqual(r["peak_accounted_mib"], 13492.042953491211, places=6)

    def test_release_is_not_free(self):
        """The whole point: a released buffer is still counted until a drain."""
        plan = mem.resident_hiding_commit(rows=10774, log_cols=14, inv_rate=4,
                                          q_pad=256, ntt_max_log=16)
        stages = {s["event"]: s for s in plan.report()["stages"]}
        # inverse_coefficients is released at forward_ntt; it must appear as
        # POOLED there, not vanish.
        self.assertGreater(stages["forward_ntt"]["pooled_bytes"], 0)
        self.assertEqual(stages["forward_ntt"]["pooled_bytes"], 10774 * (1 << 14) * 8)
        # and by column_hashes BOTH released buffers are pooled
        self.assertEqual(
            stages["column_hashes"]["pooled_bytes"],
            10774 * (1 << 14) * 8 + 10774 * (1 << 16) * 8,
        )

    def test_a_drain_actually_frees(self):
        plan = mem.resident_hiding_commit(rows=64, log_cols=8, inv_rate=4, q_pad=16)
        plan.schedule = plan.schedule + ["drain"]
        plan.drains = {"drain"}
        stages = {s["event"]: s for s in plan.report()["stages"]}
        self.assertGreater(stages["column_hashes"]["pooled_bytes"], 0)
        self.assertEqual(stages["drain"]["pooled_bytes"], 0)

    def test_chunked_is_far_smaller_and_allocates_no_full_expanded_buffer(self):
        res = mem.resident_hiding_commit(10774, 14, 4, 256, 16).report()
        chu = mem.chunked_hiding_commit(10774, 14, 4, 256, 128, 16).report()
        self.assertTrue(chu["complete"])
        self.assertLess(chu["peak_accounted_mib"], res["peak_accounted_mib"] / 8)
        # no buffer in the chunked plan is a full rows*nn
        full = 10774 * (1 << 16)
        for b in mem.chunked_hiding_commit(10774, 14, 4, 256, 128, 16).buffers:
            if not b.symbolic:
                self.assertNotEqual(b.count, full, f"{b.key} is a full rows*nn buffer")


class Validation(unittest.TestCase):
    """The acceptance asks that the tool DETECT bad plans, not just sum good ones."""

    def test_double_ownership_is_rejected(self):
        plan = mem.resident_hiding_commit(64, 8, 4, 16)
        dup = plan.buffers[1]
        plan.buffers.append(dup)
        with self.assertRaises(mem.PlanError) as cm:
            plan.validate()
        self.assertIn("double ownership", str(cm.exception))

    def test_release_before_birth_is_rejected(self):
        plan = mem.resident_hiding_commit(64, 8, 4, 16)
        plan.buffers.append(mem.Buffer("backwards", "test", 10, "column_hashes", "upload"))
        with self.assertRaises(mem.PlanError) as cm:
            plan.validate()
        self.assertIn("before it is born", str(cm.exception))

    def test_unknown_events_are_rejected(self):
        plan = mem.resident_hiding_commit(64, 8, 4, 16)
        plan.buffers.append(mem.Buffer("ghost", "test", 10, "no_such_event", None))
        with self.assertRaises(mem.PlanError):
            plan.validate()

    def test_symbolic_buffers_have_no_byte_count(self):
        b = mem.Buffer("x", "o", "some_symbol", "a", None)
        self.assertTrue(b.symbolic)
        with self.assertRaises(mem.PlanError):
            _ = b.nbytes


class PendingBlocks(unittest.TestCase):
    def test_one_block_is_incomplete_and_refuses_a_peak(self):
        r = mem.pending_private_block(1).report()
        self.assertFalse(r["complete"])
        # the single most important behaviour: no quotable peak
        self.assertIsNone(r["peak_accounted_mib"])
        self.assertIsNone(r["peak_event"])
        self.assertIn("peak_refused_because", r)

    def test_attention_terms_stay_symbolic(self):
        r = mem.pending_private_block(1).report()
        attn = [s for s in r["symbolic_buffers"] if "attn_" in s]
        self.assertEqual(len(attn), 3, "W/A/H attention retentions must all be symbolic")

    def test_two_blocks_double_the_symbolic_surface(self):
        one = mem.pending_private_block(1).report()
        two = mem.pending_private_block(2).report()
        self.assertEqual(two["symbolic_count"], 2 * one["symbolic_count"])
        self.assertFalse(two["complete"])

    def test_composition_overlaps_rather_than_reusing(self):
        """A03 warns composition can INCREASE overlap. Every commitment must be
        live simultaneously at the final opening, not released between blocks."""
        plan = mem.pending_private_block(2)
        idx = plan.schedule.index("final_open")
        st = plan.state_at(idx - 1)
        live = st["live_symbolic"]
        self.assertTrue(any("block0" in x for x in live), "block 0 must still be live")
        self.assertTrue(any("block1" in x for x in live), "block 1 must be live too")

    def test_supplying_ffn_rows_reduces_the_symbolic_surface(self):
        """Dimensions that DO exist can be supplied; the rest stay symbolic."""
        r = mem.pending_private_block(1, ffn_rows={"W": 10774 * (1 << 16)}).report()
        self.assertNotIn("block0::ffn_W_retained", r["symbolic_buffers"])
        self.assertFalse(r["complete"], "attention is still symbolic")


if __name__ == "__main__":
    unittest.main()

"""[ZK60-CL10] Tests for the proof-artifact component profile.

No GPU, no proof generation, no sensitive exports. The artifact sizes used
here are the frozen, published byte-gate and lane-AM values, so these tests
pin the model against numbers that were measured elsewhere and independently.
"""

import importlib.util
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_SRC = os.path.join(os.path.dirname(_HERE), "scripts", "hashline_cl_artifact_profile.py")
_spec = importlib.util.spec_from_file_location("hashline_cl_artifact_profile", _SRC)
prof = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = prof
_spec.loader.exec_module(prof)

# Measured, published elsewhere: lane AM rung 2 / CL1 rung 4.
P1_BYTES = 40186228
P3_BYTES = 40251860


class Reconciliation(unittest.TestCase):
    def test_both_modes_reconcile_exactly(self):
        for name, obs in (("mistral-v3-layer-P1", P1_BYTES), ("mistral-v3-layer-P3", P3_BYTES)):
            r = prof.profile(prof.get_layout(name), obs)
            self.assertTrue(r["reconciles_exactly"], name)
            total = r["components"]["derived_total_bytes"] + r["residual_bytes"]
            self.assertEqual(total, obs, f"{name} must reconcile to the observed artifact")

    def test_opened_column_data_dominates(self):
        r = prof.profile(prof.get_layout("mistral-v3-layer-P3"), P3_BYTES)
        self.assertGreater(r["shares"]["opened_column_data"], 0.85)
        self.assertLess(r["shares"]["opened_column_framing"], 0.02)

    def test_the_hiding_cost_lands_entirely_in_the_residual(self):
        """The strongest check available: the published P1->P3 delta is
        +65,632 B, and the column term is mode-independent (same rows, same
        columns). So the whole delta must appear in the argument residual. If
        the model were wrong about what the columns contain, this would drift."""
        p1 = prof.profile(prof.get_layout("mistral-v3-layer-P1"), P1_BYTES)
        p3 = prof.profile(prof.get_layout("mistral-v3-layer-P3"), P3_BYTES)
        self.assertEqual(
            p1["components"]["opened_columns_total_bytes"],
            p3["components"]["opened_columns_total_bytes"],
            "the opened-column term must not depend on the privacy mode",
        )
        self.assertEqual(p3["residual_bytes"] - p1["residual_bytes"], P3_BYTES - P1_BYTES)
        self.assertEqual(p3["residual_bytes"] - p1["residual_bytes"], 65632)


class Refusals(unittest.TestCase):
    """CL10: unknown legacy layouts are REFUSED rather than guessed."""

    def test_unknown_layout_is_refused(self):
        with self.assertRaises(prof.ProfileError) as cm:
            prof.get_layout("some-legacy-v1-thing")
        self.assertIn("REFUSED", str(cm.exception))

    def test_underspecified_layout_is_refused(self):
        bad = prof.Layout(
            name="bad",
            commitments=(prof.CommitmentOpening(role="W", rows=0, columns=256, path_len=16),),
            commitment_headers=1,
        )
        with self.assertRaises(prof.ProfileError) as cm:
            prof.profile(bad, 1000)
        self.assertIn("refused, not defaulted", str(cm.exception))

    def test_a_model_that_exceeds_the_artifact_is_refused(self):
        """If the derived components do not fit inside the observed artifact the
        model has drifted; a breakdown that cannot be true must not be printed."""
        with self.assertRaises(prof.ProfileError) as cm:
            prof.profile(prof.get_layout("mistral-v3-layer-P3"), 1_000_000)
        self.assertIn("EXCEED", str(cm.exception))

    def test_non_positive_observed_size_is_refused(self):
        with self.assertRaises(prof.ProfileError):
            prof.profile(prof.get_layout("mistral-v3-layer-P3"), 0)


class Components(unittest.TestCase):
    def test_data_and_framing_sum_to_the_column_total(self):
        c = prof.CommitmentOpening(role="W", rows=10774, columns=256, path_len=16)
        self.assertEqual(c.data_only_bytes() + c.framing_bytes(), c.column_bytes())

    def test_framing_is_independent_of_rows(self):
        """Per-column index + salt + path do not scale with committed rows, so
        framing cannot be reduced by changing the shape — only by opening
        fewer columns, which is a protocol change with a soundness cost."""
        a = prof.CommitmentOpening(role="A", rows=100, columns=256, path_len=16)
        b = prof.CommitmentOpening(role="B", rows=100000, columns=256, path_len=16)
        self.assertEqual(a.framing_bytes(), b.framing_bytes())


if __name__ == "__main__":
    unittest.main()

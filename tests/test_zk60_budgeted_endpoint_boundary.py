"""Forced-challenge boundary of the archived Fable two-use endpoint model.

The advertised per-use refusals allow a pair of challenges whose proximity
vectors cancel every mask and reveal both data rows. This refutes the memo's
universal A4 premise; it is NOT an efficient attack on random Fiat-Shamir,
a native full-proof attack, or a privacy acceptance test. The control uses
separate proximity mask pairs and checks the complete small field system.
"""

import hashlib
import importlib.util
from pathlib import Path
import random
import sys
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
DELIVERY = (
    ROOT / "results/zk60_loop_20260918/reviews/fable_reuse/scripts"
    / "zk60_reusable_endpoint_probe.py"
)
# Archived fable_reuse/index.json, source_files entry for this exact delivery.
DELIVERY_SHA256 = "b77a5e97fc8de7a7e909eb3f537201fb89b663ee1546673a8925a7c1e174422e"


class BudgetedEndpointBoundary(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = DELIVERY.read_bytes()
        if hashlib.sha256(source).hexdigest() != DELIVERY_SHA256:
            raise AssertionError("archived endpoint model delivery pin mismatch")
        name = "_reviewed_zk60_budgeted_endpoint_boundary"
        spec = importlib.util.spec_from_file_location(name, DELIVERY)
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module  # dataclasses consult their defining module.
        cls.addClassCleanup(sys.modules.pop, name, None)
        with patch.object(sys, "dont_write_bytecode", True):
            spec.loader.exec_module(module)
        cls.model = module
        # Do not call check_source_pins(): the archive-relative ROOT is not
        # the source checkout. The unchanged delivered model itself is pinned.

    def fixture(self, shared_proximity_masks):
        m = self.model
        layout = m.SMALL_BUDGET2
        rng = random.Random(20260918)
        data = m.synthetic_data(layout, rng)
        endpoint = m.Endpoint(layout, data, rng)
        challenges = [m.draw_challenge(layout, use, rng) for use in (0, 1)]
        for ch in challenges:
            ch.prox = [m.F2_ZERO] * layout.rows
            uses = (0, 1) if shared_proximity_masks else (ch.use,)
            for use in uses:
                a, b = layout.prox_pair(use)
                ch.prox[a], ch.prox[b] = m.F2_ONE, m.F2_U
        challenges[1].prox[0] = m.F2_ONE
        challenges[1].prox[1] = m.F2_U

        # These are precisely the draw_challenge refusal predicates in the
        # delivered model: nonzero lambda/e and its designated pair spanning
        # Fp2. A full-rank pair separately at each use need not span jointly.
        for ch in challenges:
            self.assertFalse(m.f2_is_zero(ch.lam))
            self.assertFalse(m.f2_is_zero(ch.e))
            a, b = layout.prox_pair(ch.use)
            self.assertEqual(m.determinant(ch.prox[a], ch.prox[b]), 1)
        openings = [m.open_field(endpoint, ch) for ch in challenges]
        for opening in openings:
            self.assertIsNone(m.verify_field(layout, opening))
        return layout, data, challenges, openings

    def test_allowed_forced_challenges_cancel_masks_within_two_use_budget(self):
        m = self.model
        layout, data, challenges, openings = self.fixture(True)
        self.assertEqual([ch.use for ch in challenges], [0, 1])
        self.assertEqual(layout.uses, 2)
        # At each message coordinate, prox2 - prox1 = x0 + U*x1.
        # Recovery reads public vectors only; no owner, pads, or salts.
        recovered = [
            m.f2_sub(openings[1].prox_vec[k], openings[0].prox_vec[k])
            for k in range(layout.n)
        ]
        self.assertEqual(recovered, list(zip(data[:layout.n], data[layout.n:])))
        self.assertEqual(
            m.per_coordinate_disclosure(layout, challenges, ("prox",)), 2
        )

    def test_separate_proximity_masks_do_not_cancel_in_the_control(self):
        m = self.model
        layout, data, challenges, openings = self.fixture(False)
        difference = [
            m.f2_sub(openings[1].prox_vec[k], openings[0].prox_vec[k])
            for k in range(layout.n)
        ]
        self.assertNotEqual(difference, list(zip(data[:layout.n], data[layout.n:])))
        self.assertEqual(
            m.per_coordinate_disclosure(layout, challenges, ("prox",)), 0
        )
        # This includes group vectors, proximity vectors and all opened
        # columns. It is one deterministic control, not a universal theorem.
        self.assertEqual(m.disclosed_dimension(layout, openings), 0)


if __name__ == "__main__":
    unittest.main()

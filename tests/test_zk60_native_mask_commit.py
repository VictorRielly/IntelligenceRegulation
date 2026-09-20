"""Tests for the masking commitment's port (scripts/zk60_native_mask_commit.py).

Run:
  python3 -m unittest discover -s tests -p "test_zk60_native_mask_commit.py"

Three kinds of test, the same discipline as the P10 gate's own file:

  * the PORT against the Rust it transcribes -- the source pins, the two
    CfsMask weight formulas, and the declared functional order checked on the
    real capture position by position, value by value and weight by weight;
  * the real captures, where a preimage for M's opening is constructed at a
    chosen coefficient vector and the recomputed opening is compared with the
    capture entry by entry;
  * the criterion itself: every negative control must fire, and must not fire
    on the honest capture.

Nothing here establishes a privacy property.  The four source-pinned captures
are tracked in the repository, so a missing capture is a FAILURE, never a
silent skip.
"""

from __future__ import annotations

import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

CAPTURES = os.path.join(ROOT, "results", "zk60_native_captures_20260919")

from zk60_native_jv_capture import load_all  # noqa: E402
from zk60_native_jv_field import F2_ONE, P, f2_add, f2_mul, f2_mul_base  # noqa: E402
from zk60_native_jv_replay import Replay  # noqa: E402
import zk60_native_mask_commit as mc  # noqa: E402


def _caps():
    caps = load_all(CAPTURES)
    assert caps, f"no captures under {CAPTURES}"
    return caps


class ThePort(unittest.TestCase):
    def test_every_source_pin_is_present_and_unchanged(self):
        pins = mc.check_source_pins()
        self.assertEqual(len(pins), len(mc.SOURCE_PINS))
        for p in mc.SOURCE_PINS:
            self.assertEqual(pins[p.path]["sha256"], p.sha256)
            self.assertTrue(pins[p.path]["ported"])

    def test_a_changed_pin_is_a_hard_error_not_a_warning(self):
        bad = (mc.Pin("hashline/src/zk.rs", "00" * 32, "11" * 20, "x"),)
        with self.assertRaises(mc.SourcePinError):
            mc.check_source_pins(pins=bad)
        missing = (mc.Pin("hashline/src/nope.rs", "00" * 32, "11" * 20, "x"),)
        with self.assertRaises(mc.SourcePinError):
            mc.check_source_pins(pins=missing)

    def test_the_two_cfsmask_weight_formulas(self):
        # CfsMask::len, sum_weights (sumcheck.rs:197-227)
        self.assertEqual(mc.mask_len(10, 3), 32)
        w = mc.sum_weights(10, 3)
        self.assertEqual(len(w), 32)
        self.assertEqual(w[0], ((1 << 10) % P, 0))
        self.assertEqual(w[1], F2_ONE)
        self.assertTrue(all(x == ((1 << 9) % P, 0) for x in w[2:]))
        # CfsMask::eval_weights (sumcheck.rs:230-243): 1, prod(rho), then
        # rho_j^1..rho_j^degree for each j, in that order
        rho = [(3, 1), (5, 2)]
        e = mc.eval_weights(rho, 3)
        self.assertEqual(len(e), mc.mask_len(2, 3))
        self.assertEqual(e[0], F2_ONE)
        self.assertEqual(e[1], f2_mul(rho[0], rho[1]))
        self.assertEqual(e[2], rho[0])
        self.assertEqual(e[3], f2_mul(rho[0], rho[0]))
        self.assertEqual(e[5], rho[1])

    def test_encode_coeffs_coset_is_evaluation_at_the_coset(self):
        """`encode_coeffs_coset` must give P(7 * omega_4096^j) (zk.rs:424-428)."""
        ntt = mc.Ntt(mc.MASK_LOG_DOM)
        pows = mc.coset_powers(mc.COSET_GEN, mc.DOM_N)
        coeffs = [1, 2, 3, 0, 5]
        enc = mc.encode_coeffs_coset(ntt, coeffs, pows)
        w = mc.two_adic_root(mc.MASK_LOG_DOM)
        for j in (0, 1, 17, 4095):
            x = mc.COSET_GEN * pow(w, j, P) % P
            want = 0
            for i, c in enumerate(coeffs):
                want = (want + c * pow(x, i, P)) % P
            self.assertEqual(enc[j], want, f"node {j}")

    def test_poly_mul_512_is_the_convolution(self):
        ntt = mc.Ntt(mc.MASK_LOG_DOM)
        a = [0] * mc.MSG_N
        b = [0] * mc.MSG_N
        a[0], a[3], a[511] = 7, 11, 13
        b[1], b[2], b[500] = 2, 5, 3
        got = mc.poly_mul_512(a, b, ntt)
        self.assertEqual(len(got), 2 * mc.MSG_N)
        want = [0] * (2 * mc.MSG_N)
        for i, x in enumerate(a):
            if x:
                for j, y in enumerate(b):
                    if y:
                        want[i + j] = (want[i + j] + x * y) % P
        self.assertEqual(got, want)


class TheDeclaredOrder(unittest.TestCase):
    """The order an earlier memo got wrong, pinned to the code and checked."""

    def test_the_order_matches_the_capture_on_every_capture(self):
        for cap in _caps():
            with self.subTest(capture=cap.proof_sha256[:12]):
                rp = Replay(cap).run()
                o = mc.declared_functional_order(cap, rp)
                self.assertEqual(o["failures"], [])
                self.assertTrue(o["ok"])
                n = o["captured_functionals"]
                self.assertEqual(o["expected_functionals"], n)
                self.assertEqual(o["position_matches"], n)
                self.assertEqual(o["value_matches"], n)
                self.assertEqual(o["weight_matches"], n)

    def test_a_standalone_gamma_sits_immediately_before_its_own_evaluation(self):
        cap = _caps()[0]
        rp = Replay(cap).run()
        names = mc.declared_functional_order(cap, rp)["order_as_declared"]
        kinds = {a["slot"]: a["kind"] for a in cap.doc["arguments"]}
        for s, k in kinds.items():
            if k == "Standalone":
                i = names.index(f"Gamma_{s:02d}")
                self.assertEqual(names[i + 1], f"eval_{s:02d}", f"slot {s}")

    def test_every_host_gamma_comes_last_and_in_slot_order(self):
        cap = _caps()[0]
        rp = Replay(cap).run()
        names = mc.declared_functional_order(cap, rp)["order_as_declared"]
        hosts = [a["slot"] for a in cap.doc["arguments"] if a["kind"] == "Host"]
        self.assertTrue(hosts)
        tail = names[-len(hosts):]
        self.assertEqual(tail, [f"Gamma_{s:02d}" for s in hosts])
        self.assertTrue(all(n.startswith("eval_") or "Gamma" in n for n in names))

    def test_swapping_two_functionals_is_seen(self):
        """The order is load-bearing: a swap moves the batched value."""
        cap = _caps()[0]
        rp = Replay(cap).run()
        m = mc.MaskModel(cap, rp)
        fns = list(cap.mask["functionals"])
        fns[0], fns[1] = fns[1], fns[0]
        _, v_p, fail = mc.combined_weights(m.specs, fns, m.theta)
        self.assertEqual(fail, [])
        self.assertNotEqual(v_p, m.v)


class TheModelOnTheRealCaptures(unittest.TestCase):
    def test_the_shape_facts_hold_on_every_capture(self):
        for cap in _caps():
            with self.subTest(capture=cap.proof_sha256[:12]):
                m = mc.MaskModel(cap, Replay(cap).run())
                s = m.shape()
                self.assertEqual(m.failures, [])
                self.assertEqual(s["failed"], [])
                self.assertTrue(s["ok"])
                self.assertEqual(s["rows"], 2 * s["slots"] + 4)
                self.assertTrue(s["weights_vanish_above_L"])
                self.assertGreaterEqual(s["pad_margin"], 0)
                self.assertTrue(s["nodes_off_G512"])

    def test_the_verifiers_own_sum_identity_holds(self):
        """512 (q[0] + q[512]) == sum_i theta^i value_i (zk.rs:560-561)."""
        for cap in _caps():
            with self.subTest(capture=cap.proof_sha256[:12]):
                m = mc.MaskModel(cap, Replay(cap).run())
                q = [mc.f2_from_list(x) for x in cap.mask["q"]]
                got = f2_mul_base(f2_add(q[0], q[mc.MSG_N]), mc.MSG_N % P)
                self.assertEqual(got, m.v)

    def test_the_disclosed_dimension_is_two_fp_on_every_capture(self):
        for cap in _caps():
            with self.subTest(capture=cap.proof_sha256[:12]):
                m = mc.MaskModel(cap, Replay(cap).run())
                d = mc.disclosed_dimension(m)
                self.assertEqual(d["disclosed_fp_computed"], 2)
                self.assertEqual(d["disclosed_fp_predicted"], 2)
                self.assertTrue(d["matches_prediction"])
                self.assertEqual(
                    d["fibre_dimension_fp"], d["coefficient_unknowns_fp"] - 2
                )

    def test_a_preimage_reproduces_the_captured_opening_entry_by_entry(self):
        for cap in _caps():
            with self.subTest(capture=cap.proof_sha256[:12]):
                m = mc.MaskModel(cap, Replay(cap).run())
                co, where = mc.force_functional(
                    m, mc.synthetic_coefficients(m, "a1"), m.v
                )
                self.assertIsNotNone(where)
                p = mc.MaskPreimage(m, co).build()
                self.assertEqual(p.failures, [])
                v = p.verify()
                self.assertTrue(v["b_admissible"])
                self.assertTrue(v["q_sum_identity_holds"])
                self.assertEqual(v["q_mismatches"], 0)
                self.assertEqual(v["prox_mismatches"], 0)
                self.assertEqual(v["column_mismatches"], 0)
                self.assertEqual(
                    v["column_entries"], len(cap.mask["columns"]) * m.n_base
                )
                self.assertTrue(v["all_entries_equal"])

    def test_two_preimages_at_coefficient_vectors_that_share_only_V(self):
        cap = _caps()[0]
        m = mc.MaskModel(cap, Replay(cap).run())
        made = []
        for tag in ("a1", "a2"):
            co, _ = mc.force_functional(m, mc.synthetic_coefficients(m, tag), m.v)
            p = mc.MaskPreimage(m, co).build()
            self.assertTrue(p.verify(columns=6)["all_entries_equal"])
            made.append((co, p))
        (c1, p1), (c2, p2) = made
        differ = sum(
            1 for s in range(m.S) for t in range(m.L[s]) if c1[s][t] != c2[s][t]
        )
        self.assertEqual(differ, sum(m.L))  # they agree NOWHERE
        self.assertEqual(p1.functional_value(), p2.functional_value())
        self.assertNotEqual(p1.blinding_digest(), p2.blinding_digest())

    def test_off_the_V_plane_the_fibre_is_empty(self):
        """The other half of "disclosed exactly 2 Fp": b has no admissible value."""
        cap = _caps()[0]
        m = mc.MaskModel(cap, Replay(cap).run())
        off, _ = mc.force_functional(
            m, mc.synthetic_coefficients(m, "a3"), f2_add(m.v, F2_ONE)
        )
        v = mc.MaskPreimage(m, off).build().verify(columns=4)
        self.assertFalse(v["b_admissible"])
        self.assertFalse(v["q_sum_identity_holds"])
        self.assertFalse(v["all_entries_equal"])
        # ... and the columns are untouched: the pads absorb every vector
        self.assertEqual(v["column_mismatches"], 0)

    def test_the_pads_are_the_only_freedom_the_a_rows_have(self):
        """A pad solved from the capture must re-encode to the captured column."""
        cap = _caps()[0]
        m = mc.MaskModel(cap, Replay(cap).run())
        co, _ = mc.force_functional(m, mc.synthetic_coefficients(m, "a1"), m.v)
        p = mc.MaskPreimage(m, co).build()
        self.assertEqual(len(p.pads), 2 * m.S)
        self.assertTrue(all(len(x) == mc.MASK_Q for x in p.pads))
        # the row's message really is [coefficients | pads | zeros]
        data = [co[0][t][0] for t in range(m.L[0])]
        msg = m.a_row_message(data, p.pads[0])
        self.assertEqual(msg[: m.L[0]], data)
        self.assertEqual(msg[m.L[0] : m.L[0] + mc.MASK_Q], p.pads[0])
        self.assertTrue(all(x == 0 for x in msg[m.L[0] + mc.MASK_Q :]))
        enc = m.encode_row(m.a_coefs(msg))
        for c in cap.mask["columns"][:12]:
            self.assertEqual(enc[c["index"]], c["values"][0])


class TheControls(unittest.TestCase):
    """Each must fire when perturbed and NOT fire on the honest capture."""

    @classmethod
    def setUpClass(cls):
        cap = _caps()[0]
        cls.m = mc.MaskModel(cap, Replay(cap).run())
        cls.out = mc.mask_controls(cls.m)

    def test_every_control_fires_and_the_honest_capture_passes(self):
        self.assertTrue(self.out["honest"]["preimage_exhibited"])
        self.assertEqual(self.out["honest"]["column_mismatches"], 0)
        self.assertEqual(len(self.out["control_names"]), 3)
        for n in self.out["control_names"]:
            with self.subTest(control=n):
                self.assertTrue(self.out[n]["fires"], n)
                self.assertTrue(self.out[n]["honest_passes"], n)
        self.assertTrue(self.out["all_fire"])
        self.assertTrue(self.out["ok"])

    def test_a_pad_removed_leaves_exactly_the_unmet_nodes_wrong(self):
        c = self.out["one_pad_fewer_than_the_distinct_opened_columns"]
        # one node short of the distinct count, so one node's whole column
        # (every base row) fails and nothing else does
        self.assertEqual(c["column_mismatches"], self.m.n_base)

    def test_the_permuted_order_is_caught_by_the_columns_not_only_the_sum(self):
        c = self.out["functional_order_permuted"]
        self.assertTrue(c["batched_value_changed"])
        self.assertFalse(c["same_coefficients_b_admissible"])
        # the sharp half: b is admissible and the view STILL has no preimage
        self.assertTrue(c["forced_to_the_captured_sum_b_admissible"])
        self.assertEqual(c["forced_to_the_captured_sum_column_mismatches"], 4 * 256)
        self.assertGreaterEqual(
            c["forced_to_the_captured_sum_first_mismatch"]["row"], 2 * self.m.S
        )

    def test_leaking_a_second_functional_raises_the_disclosed_dimension(self):
        c = self.out["second_functional_leaked"]
        self.assertEqual(c["disclosed_fp_honest"], 2)
        self.assertEqual(c["disclosed_fp_leaked"], 6)
        self.assertEqual(c["fibre_fp_honest"] - c["fibre_fp_leaked"], 4)


class TheRecordCarriesNoSecret(unittest.TestCase):
    def test_the_blinding_is_a_digest_and_the_coefficients_are_public(self):
        cap = _caps()[0]
        m = mc.MaskModel(cap, Replay(cap).run())
        co, _ = mc.force_functional(m, mc.synthetic_coefficients(m, "a1"), m.v)
        p = mc.MaskPreimage(m, co).build()
        d = p.blinding_digest()
        self.assertEqual(len(d), 64)
        self.assertEqual(int(d, 16).bit_length() > 0, True)
        # deterministic from the published seed: a second run gives the same
        co2, _ = mc.force_functional(m, mc.synthetic_coefficients(m, "a1"), m.v)
        self.assertEqual(co, co2)
        self.assertEqual(mc.MaskPreimage(m, co2).build().blinding_digest(), d)


if __name__ == "__main__":
    unittest.main()

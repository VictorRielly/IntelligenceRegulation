"""FA8 tests: the three exact facts behind the transcript simulator of
ZK60_FABLE_TRANSCRIPT_REVIEW.md (fibre, k slots, pad budget), the exact
reduction bias, and the disposition record.  Reviewer: Claude Fable 5.1,
2026-09-08 session.

    python3 -m unittest discover -s tests -p 'test_zk60_fable_transcript_sim.py' -v
"""
import importlib.util
import json
import tempfile
import unittest
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("transcript_sim", ROOT / "scripts/zk60_fable_transcript_sim.py")
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)
R, C = T.R, T.C
P = T.P
ONE, ZERO = T.ONE, T.ZERO


class Fibre(unittest.TestCase):
    """Section B step 5: (G, g(rho)) independent and the last-round map onto
    Fp2 for EVERY challenge sequence, including the degenerate ones."""

    def test_functional_pair_rank_two_for_degenerate_and_random_sequences(self):
        rng = R.Rng(3)
        for n, d in ((2, 2), (3, 2), (4, 3), (6, 4), (13, 2), (18, 4)):
            for name, rho in T.degenerate_sequences(n, rng).items():
                self.assertEqual(T.functional_pair_rank(n, d, rho), 2, f"({n},{d}) {name}")

    def test_last_round_map_onto_for_every_small_and_random_last_challenge(self):
        rng = R.Rng(4)
        for d in (2, 3, 4):
            for r in [T.f2(x) for x in range(0, d + 3)] + [rng.fp2() for _ in range(5)] + [T.f2(C.HALF)]:
                coefs = T.last_round_map(d, r)
                self.assertEqual(len(coefs), d)
                self.assertTrue(any(not T.f2_is_zero(x) for x in coefs), f"d {d} r {r}")

    def test_degree_one_would_fail_only_at_r_equal_half_which_no_slot_has(self):
        # the d = 1 map is [L_1(r) - 1/2] = [r - 1/2]: zero at r = 1/2; every slot has d >= 2
        coefs = T.last_round_map(1, T.f2(C.HALF))
        self.assertTrue(all(T.f2_is_zero(x) for x in coefs))

    def test_batched_pair_four_functionals_independent(self):
        rep = T.fibre_report(R.Rng(5))
        self.assertTrue(rep["all_ok"])
        self.assertTrue(all(b["rank"] == 4 for b in rep["batched_pairs"]))

    def test_fibre_sampling_reproduces_a_real_mask_distribution_projection(self):
        """A round-trip on one tiny slot: draw a random mask, compute its
        (G, g(rho)); the pair of functionals is invertible on the (a_0, a')
        plane, so ANY target (G*, fin*) has a mask attaining it -- the fibre is
        never empty."""
        n, d = 3, 2
        rng = R.Rng(9)
        rho = [rng.fp2() for _ in range(n)]
        sw, ew = C.cfs_sum_weights(n, d), C.cfs_eval_weights(rho, d)
        self.assertEqual(C.f2_rank([list(sw), list(ew)]), 2)
        # restricted to (a_0, a'): 2 x 2 minor 2^n * prod(rho) - 1
        prod = ONE
        for r in rho:
            prod = T.f2_mul(prod, r)
        minor = T.f2_sub(T.f2_mul(T.f2(1 << n), prod), ONE)
        self.assertFalse(T.f2_is_zero(minor))


class KSlots(unittest.TestCase):
    """Section F2: k proofs against one budgeted W commitment."""

    def test_distinct_slots_disclose_nothing_jointly(self):
        for k, proofs in ((1, [0]), (2, [0, 1]), (3, [0, 1, 2]), (3, [0, 2])):
            res = R.analyze(T.stable_w_model(4, 2, k, proofs, seed=21))
            self.assertEqual(res["disclosed_dim"], 0, (k, proofs))
            # exactly one Fp2 identity per group per proof (2 groups) = 4 base rows per proof (FA7: "4 for W")
            self.assertEqual(res["observation_functionals_killing_masks_but_not_data"], 4 * len(proofs))

    def test_reused_slot_discloses_w(self):
        res = R.analyze(T.stable_w_model(4, 2, 2, [0, 0], seed=21))
        self.assertGreater(res["disclosed_dim"], 0)
        # every W block is touched: reuse leaks the difference of two evaluations of each block
        touched = set(x.split("/")[0] for x in res["summary"]["disclosed"] + res["summary"]["recovered"])
        self.assertEqual(touched, {"Wg", "Wu", "Wd"})

    def test_copied_slot_rows_disclose_w(self):
        res = R.analyze(T.stable_w_model(4, 2, 2, [0, 1], seed=21, copy_slot_from=1))
        self.assertGreater(res["disclosed_dim"], 0)

    def test_report_verdicts(self):
        rep = T.k_slot_report()
        self.assertTrue(rep["all_ok"])
        self.assertEqual([c["verdict"] for c in rep["cases"]], ["PASS"] * len(rep["cases"]))
        self.assertEqual(sum(1 for c in rep["cases"] if c["expected"] == "> 0"), 3)


class PadBudget(unittest.TestCase):
    """Section B step 10 / F2: |J| <= q_pad hides, beyond it leaks |J| - q_pad."""

    def test_within_budget_hidden_and_beyond_budget_leaks_exactly(self):
        res = T.pad_budget(3, 4, 8, [[0, 5, 9, 13], [2, 5, 20, 31]])
        self.assertTrue(res["hidden"])
        self.assertEqual(res["distinct_positions"], 7)
        res = T.pad_budget(3, 4, 4, [[0, 5, 9, 13], [2, 5, 20, 31]])
        self.assertEqual(res["leaked_functionals_of_the_row"], 3)   # 7 distinct, 4 pads
        self.assertEqual(res["expected_leak"], 3)

    def test_duplicates_only_shrink_the_distinct_set(self):
        res = T.pad_budget(2, 4, 2, [[3, 3], [3, 3], [3, 7]])
        self.assertEqual(res["distinct_positions"], 2)
        self.assertTrue(res["hidden"])

    def test_report(self):
        rep = T.pad_budget_report()
        self.assertTrue(rep["all_ok"])


class ReductionBias(unittest.TestCase):
    def test_two_pow_128_mod_p_and_exact_distance(self):
        rb = T.reduction_bias()
        self.assertTrue(rb["p_minus_m_is_2_pow_32"])
        sd = Fraction(rb["sd_fp_from_uniform"]["numerator"], rb["sd_fp_from_uniform"]["denominator"])
        self.assertEqual(sd, Fraction((P - (1 << 32)) * (1 << 32), P * (1 << 128)))
        self.assertLess(sd, Fraction(1, 1 << 96))
        self.assertGreater(sd, Fraction(1, 1 << 97))


class Records(unittest.TestCase):
    def test_disposition_record_matches_generator(self):
        path = ROOT / "results/zk60_fable_fa8_disposition.json"
        self.assertTrue(path.exists(), "run: python3 scripts/zk60_fable_transcript_sim.py disposition -o results/zk60_fable_fa8_disposition.json")
        self.assertEqual(json.loads(path.read_text()), T.disposition())

    def test_disposition_every_blocker_cited_is_defined_and_every_channel_covers_every_profile(self):
        d = T.disposition()
        for row in d["channels"]:
            self.assertEqual(set(row["profiles"]), set(T.PROFILES))
            for prof, cell in row["profiles"].items():
                if cell["status"] == "blocker":
                    self.assertTrue(cell["blockers"], (row["id"], prof))
                    for b in cell["blockers"]:
                        self.assertIn(b, d["blockers"])
        # the legacy profile leaks on the PCS side; the repaired standalone profiles have no 'leaks' cell
        self.assertGreater(d["counts"]["legacy_v3"]["leaks"], 0)
        for prof in ("repaired_P1", "repaired_P3_fresh_W", "repaired_P3_stable_W_k_slots", "block_profile"):
            self.assertEqual(d["counts"][prof]["leaks"], 0, prof)
        # the stable-W profile's W channels are gated on enforcement, never accepted outright
        w = next(r for r in d["channels"] if r["id"] == "w.vectors")
        self.assertEqual(w["profiles"]["repaired_P3_stable_W_k_slots"]["status"], "blocker")
        self.assertIn("E1", w["profiles"]["repaired_P3_stable_W_k_slots"]["blockers"])
        seam = next(r for r in d["channels"] if r["id"] == "seam.attn")
        self.assertEqual(seam["profiles"]["block_profile"]["blockers"], ["A3"])

    def test_report_roundtrip_and_committed_record(self):
        rep = T.build_report(seed=6)
        self.assertTrue(rep["all_ok"])
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "r.json"
            self.assertEqual(T.main(["report", "-o", str(out), "--seed", "6"]), 0)
            again = json.loads(out.read_text())
        for key in ("fibre", "k_slots", "pad_budget", "reduction_bias"):
            self.assertEqual(again[key], rep[key], key)
        committed = ROOT / "results/zk60_fable_fa8_transcript_sim.json"
        if committed.exists():
            c = json.loads(committed.read_text())
            for key in ("fibre", "k_slots", "pad_budget", "reduction_bias"):
                self.assertEqual(c[key], rep[key], key)
            self.assertEqual(c["tool_sha256"], rep["tool_sha256"], "the tool changed after the committed record was produced")


if __name__ == "__main__":
    unittest.main()

"""Rung R0 tests: the token I/O reference semantics and its vectors (no proof). One thread, a few seconds.

Run: python3 -B -m unittest discover -s results/zk60_token_io_design_20261017/r0 -p 'test_*.py'
"""
from __future__ import annotations

import json
import os
import random
import sys
import unittest

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import token_io_ref as R  # noqa: E402
import token_io_vectors as TV  # noqa: E402

CAL_DIR = "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929"


class Vectors(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.built = TV.build()
        with open(os.path.join(HERE, "vectors.json")) as fh:
            cls.stored = json.load(fh)

    def test_vectors_regenerate_identically(self):
        self.assertEqual(json.loads(json.dumps(self.built, sort_keys=True)), self.stored)

    def test_honest_vectors_accept_everywhere(self):
        for name in ("V01_honest_public_row", "V02_honest_hidden_length"):
            v = self.stored["vectors"][name]
            for check, res in v["checks"].items():
                self.assertTrue(res["ok"], (name, check, res))
            self.assertTrue(v["owner_input"]["ok"], name)
            self.assertTrue(v["owner_output"]["ok"], name)

    def test_hidden_length_is_causal_and_the_selector_matters(self):
        v = self.stored["vectors"]["V02_honest_hidden_length"]
        self.assertEqual(v["next_token"], v["next_token_unpadded_run"])
        self.assertNotEqual(v["next_token"], v["token_at_last_row_instead"])
        self.assertEqual(v["input_plane_words"], 256)

    def test_tie_goes_to_the_lowest_id(self):
        v = self.stored["vectors"]["V03_tie_lowest_id"]
        self.assertEqual(v["tie_value"], v["max_logit"])
        self.assertEqual(v["first_argmax"], 17)
        self.assertTrue(v["honest"]["ok"])
        self.assertFalse(v["forged_higher_id"]["ok"])

    def test_non_maximal_and_non_one_hot_rejected(self):
        v4 = self.stored["vectors"]["V04_non_maximal_token"]
        self.assertFalse(v4["forged_second"]["ok"])
        self.assertFalse(v4["forged_random"]["ok"])
        v5 = self.stored["vectors"]["V05_selector_not_one_hot"]["results"]
        self.assertEqual(v5["two_hot"]["reason"], "A2 row sum of the selector is not 1")
        self.assertEqual(v5["fractional_halves"]["reason"], "A1 booleanity of the selector")
        self.assertEqual(v5["two_minus_one"]["reason"], "A1 booleanity of the selector")

    def test_stage_in_tampers_rejected(self):
        vs = self.stored["vectors"]
        for name, keys in (("V06_wrong_embedding_row", ("wrong_row", "one_word")),
                           ("V07_histogram_off_by_one", ("plus_one", "moved_count")),
                           ("V08_token_outside_vocabulary", ("forged_hist_unchanged", "forged_hist_on_pad")),
                           ("V09_bos_missing", ("forged",))):
            for k in keys:
                self.assertFalse(vs[name][k]["ok"], (name, k))
        self.assertTrue(vs["V08_token_outside_vocabulary"]["honest_prover"].startswith("refused"))
        self.assertTrue(vs["V09_bos_missing"]["honest_prover"].startswith("refused"))

    def test_f1_attack_needs_the_seal(self):
        v = self.stored["vectors"]["V10_F1_attack_wrong_prefix"]
        for check, res in v["verifier_side_relations"].items():
            self.assertTrue(res["ok"], check)          # the attack satisfies every slot relation
        self.assertNotEqual(v["attack_token"], v["honest_token"])
        self.assertFalse(v["sealed_owner_input_check"]["ok"])

    def test_final_norm_overflow_and_windows(self):
        v11 = self.stored["vectors"]["V11_final_norm_overflow"]
        self.assertTrue(v11["calibrated_style_cn"].startswith("refused"))
        self.assertLessEqual(v11["refusal_free_cn_y_max"], 127)
        self.assertEqual(v11["refusal_free_extremes"], [127, -127])
        v12 = self.stored["vectors"]["V12_limb_not_a_byte_and_windows"]
        self.assertEqual(v12["result"]["reason"], "A4 a delta limb is not a byte")
        self.assertEqual(v12["windows"]["Llama-3-8B"]["max_honest_delta_bits"], 44)
        self.assertEqual(v12["windows"]["TinyLlama"]["max_honest_delta_bits"], 41)
        for w in v12["windows"].values():
            self.assertTrue(w["six_limbs_cover"] and w["sound_margin"])


class VectorsV3(unittest.TestCase):
    """CHECK2 N-1, N-2, N-10..N-14 and the R1 controls of DESIGN v3 6.1"""

    @classmethod
    def setUpClass(cls):
        with open(os.path.join(HERE, "vectors.json")) as fh:
            cls.v = json.load(fh)["vectors"]

    def test_honest_io_relations(self):
        for name, keys in (("V01_honest_public_row", ("io_in", "io_out")), ("V02_honest_hidden_length", ("io_in", "io_s", "io_out"))):
            for k in keys:
                self.assertTrue(self.v[name]["io"][k]["ok"], (name, k))

    def test_argmax_relations_each_load_bearing(self):
        v13, v14, v15 = self.v["V13_overstated_max_A6_only"], self.v["V14_selector_on_padded_entry"], self.v["V15_tok_not_selected_index"]
        self.assertTrue(v13["all_deltas_in_six_bytes"])
        self.assertTrue(v13["result"]["reason"].startswith("A6"))
        self.assertTrue(v13["accepted_without_A6"])
        self.assertTrue(v14["result"]["reason"].startswith("A1 pad-zero"))
        self.assertTrue(v14["accepted_without_pad_zero"])
        self.assertEqual(v14["output_id"], v14["V"])
        self.assertTrue(v15["result"]["reason"].startswith("A3"))
        self.assertTrue(v15["accepted_without_A3"])

    def test_bos_clause_needs_its_own_coefficient(self):
        r = self.v["V16_bos_absorption_N1"]["results"]
        self.assertTrue(r["honest_unweighted"]["ok"] and r["honest_fresh"]["ok"])
        self.assertTrue(r["attack_unweighted"]["ok"])          # the v2 text's hole (CHECK2 N-1)
        self.assertFalse(r["attack_fresh"]["ok"])              # the v3 repair
        for wt, res in self.v["V17_tok0_not_bos"]["results"].items():
            self.assertFalse(res["ok"], wt)

    def test_final_norm_field_forgeries(self):
        r = self.v["V18_final_norm_field_forgeries"]["results"]
        self.assertTrue(r["honest"]["ok"])
        self.assertEqual(r["y_off_by_one"]["reason"], "remainder window")
        self.assertTrue(r["D_off_by_one"]["reason"].startswith("isqrt limb windows"))
        self.assertTrue(r["D16_field_alias"]["reason"].startswith("isqrt limb windows"))
        self.assertTrue(r["y_outside_int8_in_window"]["reason"].startswith("norm output outside int8"))
        self.assertGreater(r["y_outside_int8_in_window"]["max_abs_y"], 127)
        self.assertTrue(r["x_not_int16"]["reason"].startswith("x int16 window"))
        self.assertTrue(r["x_not_int16"]["int_relations_hold_otherwise"])

    def test_position_selector_and_io_forgeries(self):
        v19 = self.v["V19_selector_two_minus_one"]
        self.assertTrue(v19["selection_relation_alone"]["ok"])
        self.assertFalse(v19["selector_check"]["ok"])
        v20 = self.v["V20_sealed_right_used_wrong"]
        self.assertTrue(v20["owner_input_check"]["ok"])
        self.assertFalse(v20["io_s"]["ok"])
        v21 = self.v["V21_consistent_relookup_honest_seal"]
        self.assertTrue(v21["stage_in_on_relookup"]["ok"])
        self.assertFalse(v21["io_in"]["ok"])
        v22 = self.v["V22_output_plane_other_id"]
        self.assertTrue(v22["owner_output_check_told_sealed_id"]["ok"])
        self.assertFalse(v22["io_out"]["ok"])
        v23 = self.v["V23_endpoint_pad_word"]
        self.assertFalse(v23["io_in"]["ok"])
        self.assertFalse(v23["owner_input_check"]["ok"])

    def test_bos_profile_constant(self):
        v24 = self.v["V24_bos_profile_constant"]
        self.assertEqual(v24["llama3_8b"]["bos"], 128000)
        self.assertTrue(v24["tinyllama"]["check"][0] and v24["llama3_8b"]["check"][0])
        self.assertFalse(v24["llama3_bos_under_tinyllama_vocab"][0])


class Properties(unittest.TestCase):
    def test_limb_count_is_derived_tf1(self):
        """TF-1: ceil(window / 8) over the declared class; 6 at the R1 rung (d 384, V 300) and at
        TinyLlama / 8B under the per-tensor head (mult_bits 0), 7 at TinyLlama (53 bits) and 8B (56 bits)
        with the 12-bit multipliers; the R0 synthetic profile (d 16, V 300, multipliers 1) needs 4 and the
        stored vectors' fixed 6 covers it; 16-bit limbs wrap the field under the 12-bit class (v4 finding)."""
        self.assertEqual(R.limbs_for(384, 300)[:2], (6, 45))
        self.assertEqual(R.limbs_for(2048, 32000)[:2], (7, 53))
        self.assertEqual(R.limbs_for(4096, 128256)[:2], (7, 56))
        self.assertEqual(R.limbs_for(2048, 32000, mult_bits=0)[:2], (6, 41))
        self.assertEqual(R.limbs_for(4096, 128256, mult_bits=0)[:2], (6, 44))
        n, w, ok = R.limbs_for(TV.D_MODEL, TV.V, mult_bits=0)
        self.assertTrue(ok and n <= R.DELTA_LIMBS and w < 8 * R.DELTA_LIMBS)
        for d, V in ((2048, 32000), (4096, 128256)):
            self.assertTrue(R.limbs_for(d, V)[2])                       # 7 byte limbs: 2^56 + 2^56 < p
            self.assertFalse(R.limbs_for(d, V, limb_bits=16)[2])       # 4 x 16-bit limbs: 2^64 + 2^53 >= p

    def test_helper_level_stage_in_on_random_sequences(self):
        """honest witnesses pass the helper-level relations; the N-1 forgery fails with fresh
        coefficients for every random sequence tried, and passes the v2 unweighted form"""
        E, W = TV.model()
        V, Vp = TV.V, R.npow2(TV.V)
        rng = random.Random(77)
        for _ in range(4):
            toks = [R.BOS] + [rng.randrange(0, V) for _ in range(7)]
            x = R.embed(toks, E, V)
            m = R.histogram(toks, Vp)
            hq, ht = R.stage_in_helpers(toks, x, m, E, V, L=16)
            plane = toks + [0] * 8
            self.assertTrue(R.check_stage_in_helpers(plane, x, m, hq, ht, E, V, 8, R.BOS, "fresh")[0])
            at = [R.BOS + 1] + toks[1:]
            ax = [[rng.randint(-1000, 1000) for _ in range(TV.D_MODEL)]] + x[1:]
            am = R.histogram(toks[1:], Vp)
            hqa, hta = R.stage_in_helpers(at, ax, am, E, V, L=16)
            hqa[0] = 0
            aplane = at + [0] * 8
            self.assertTrue(R.check_stage_in_helpers(aplane, ax, am, hqa, hta, E, V, 8, R.BOS, "unweighted")[0])
            self.assertFalse(R.check_stage_in_helpers(aplane, ax, am, hqa, hta, E, V, 8, R.BOS, "fresh")[0])
            bad = list(hq)
            bad[9] = 5                                           # a nonzero helper on a lifted pad position
            self.assertFalse(R.check_stage_in_helpers(plane, x, m, bad, ht, E, V, 8, R.BOS, "fresh")[0])

    def test_only_the_first_maximum_admits_a_witness(self):
        """every candidate index of random logit vectors (extremes at the 8B bound, forced ties, near
        ties, all equal): the honest witness accepts, a forged one accepts iff it is numpy's first max"""
        rng = random.Random(1017)
        B = 4096 * 127 * 127
        trials = 0
        for trial in range(60):
            V = rng.choice([3, 5, 17, 37])
            kind = trial % 4
            if kind == 0:
                l = [rng.choice([-B, B, rng.randint(-B, B)]) for _ in range(V)]
            elif kind == 1:
                l = [rng.randint(-B, B) for _ in range(V)]
                mx = max(l)
                for i in rng.sample(range(V), min(V, 3)):
                    l[i] = mx
            elif kind == 2:
                mx = rng.randint(-B + 1, B)
                l = [rng.choice([mx, mx - 1, -B]) for _ in range(V)]
            else:
                l = [rng.randint(-B, B)] * V
            want = R.first_argmax(l)
            self.assertTrue(R.check_argmax(l, R.keyed_witness(l, V), V)[0])
            for j in range(V):
                ok, _ = R.check_argmax(l, R.forged_witness(l, V, j), V)
                self.assertEqual(ok, j == want, (l, j, want))
                trials += 1
        self.assertGreater(trials, 500)

    def test_first_argmax_equals_numpy(self):
        try:
            import numpy as np
        except ImportError:
            self.skipTest("numpy not available")
        rng = np.random.default_rng(5)
        for _ in range(200):
            l = rng.integers(-50, 50, size=int(rng.integers(2, 300))).tolist()
            self.assertEqual(R.first_argmax(l), int(np.argmax(l)))

    def test_any_single_word_change_in_the_embedding_is_caught(self):
        E, W = TV.model()
        tokens = [R.BOS] + [10, 20, 30, 40, 2, 2, 2]
        x = R.embed(tokens, E, TV.V)
        m = R.histogram(tokens, R.npow2(TV.V))
        self.assertTrue(R.check_stage_in(tokens, x, m, E, TV.V)[0])
        rng = random.Random(3)
        for _ in range(12):
            xb = [list(r) for r in x]
            t, i = rng.randrange(len(tokens)), rng.randrange(TV.D_MODEL)
            xb[t][i] += rng.choice([-1, 1, 1000])
            self.assertFalse(R.check_stage_in(tokens, xb, m, E, TV.V)[0])

    def test_owner_check_binds_salt_and_plane(self):
        tokens = [R.BOS, 9, 8, 2]
        plane = R.input_plane(tokens, 3, 4, True)
        root = R.commit_standin(plane, b"s" * 32)
        self.assertTrue(R.owner_check_input(root, plane, b"s" * 32, tokens[:3], 2, 4, True)[0])
        self.assertFalse(R.owner_check_input(root, plane, b"t" * 32, tokens[:3], 2, 4, True)[0])
        bad = list(plane)
        bad[200] = 1                                   # a pad word of half 1... is the selector half
        self.assertFalse(R.owner_check_input(R.commit_standin(bad, b"s" * 32), bad, b"s" * 32, tokens[:3], 2, 4, True)[0])
        self.assertFalse(R.owner_check_input(root, plane, b"s" * 32, tokens[:2], 2, 4, True)[0])  # wrong length

    def test_final_norm_matches_the_calibration_tool(self):
        """cross-check against tlcalib.i_norm (uniform gain) and its window at TinyLlama's width;
        skipped if the calibration tool cannot be imported here"""
        try:
            import numpy as np
            sys.path.insert(0, CAL_DIR)
            import tlcalib as tc
        except Exception as exc:  # pragma: no cover
            self.skipTest("calibration tool not importable: %s" % exc)
        d, tn, ceps = 2048, 10, 74429
        self.assertEqual(R.norm_window(d, tn, ceps), tc.norm_window(d, tn))
        rng = np.random.default_rng(11)
        X = rng.integers(-3000, 3000, size=(6, d), dtype=np.int64)
        X[0, 0] = 32767
        X[1, 5] = -32768
        g8 = np.full(d, 127, dtype=np.int8)
        compared = 0
        for cn in (1 << tn, 3583):
            q, D = tc.i_norm(X[None], g8, cn, tn, ceps, tc.norm_window(d, tn), tc.Rec(1), "t", 0, clamp=True)
            for r in range(X.shape[0]):
                row = [int(v) for v in X[r]]
                try:
                    fn = R.final_norm(row, 127, cn, tn, ceps)
                except R.Refusal:
                    continue          # tlcalib clamps diagnostically; the reference refuses
                self.assertEqual(fn["y"], [int(v) for v in q[0, r]])
                self.assertEqual(fn["D"], int(D[0, r]))
                compared += 1
        self.assertGreaterEqual(compared, 10)


if __name__ == "__main__":
    unittest.main()

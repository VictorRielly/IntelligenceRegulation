"""FA2 rank-tool tests: the contract fixtures (a)-(d) against INDEPENDENT hand
calculations (FA1's L_b / det formulas re-derived here, not read back from the
tool), the group-with-values rank rule, the joint tiny layouts, JSON I/O and
the layout predicate.  Reviewer: Claude Fable 5.1, 2026-09-07 session.

    python3 -m unittest discover -s tests -p 'test_zk60_fable_joint_rank.py' -v
"""
import importlib.util
import json
import os
import random
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("joint_rank", Path(__file__).resolve().parents[1] / "scripts/zk60_fable_joint_rank.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)

P = R.P


def hand_det(a, b):
    """Independent det[a; b] = a.c0 b.c1 - a.c1 b.c0 (FA1 section 6)."""
    return (a[0] * b[1] - a[1] * b[0]) % P


def hand_mul(a, b):
    """Independent Fp2 product with u^2 = 7."""
    return ((a[0] * b[0] + 7 * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def rand_fp2(rng):
    return (rng.randrange(P), rng.randrange(1, P))


class SingletonFixtureA(unittest.TestCase):
    """(a) one base mask, one Fp2 observation: disclosure, matching FA1's T2 algebra."""

    def test_singleton_p1_recovers_the_row_and_matches_L_b(self):
        model, exp = R.fixture_singleton(seed=1)
        res = R.analyze(model)
        self.assertEqual(res["disclosed_dim"], 1)
        self.assertEqual(res["rank_mask"], 1)
        self.assertEqual(res["status"], {"D": "recovered"})
        self.assertEqual(res["surviving_data_functionals"], [{"D": 1}])
        # the mask-killing observation functional is L_b up to a scalar: (b.c1, -b.c0)
        (y,) = res["mask_killing_observation_functionals"]
        b = exp["b"]
        lb = {"v.re": b[1] % P, "v.im": (-b[0]) % P}
        scale = None
        for k, v in lb.items():
            yk = y.get(k, 0)
            s = (yk * pow(v, P - 2, P)) % P
            if scale is None:
                scale = s
            self.assertEqual(s, scale, "observation functional is not proportional to L_b")
        self.assertNotEqual(scale, 0)
        # numeric cross-check independent of the tool: D = L_b(v) / w0 with v = lambda*(a D + c R)
        rng = random.Random(99)
        lam, e = exp["lambda"], exp["e"]
        a, c = ((1 - e[0]) % P, (-e[1]) % P), e
        for _ in range(5):
            D, Rm = rng.randrange(P), rng.randrange(P)
            v = hand_mul(lam, ((a[0] * D + c[0] * Rm) % P, (a[1] * D + c[1] * Rm) % P))
            bb = hand_mul(lam, c)
            w0 = hand_det(hand_mul(lam, a), bb)
            self.assertEqual((hand_det(v, bb) * pow(w0, P - 2, P)) % P, D)
            # and FA1's sharpening: w0 = N(lambda) * e.c1 for the P1 pair
            n_lam = (lam[0] * lam[0] - 7 * lam[1] * lam[1]) % P
            self.assertEqual(w0, (n_lam * e[1]) % P)

    def test_singleton_p3_has_the_same_structure(self):
        model, exp = R.fixture_singleton(seed=1, p3=True)
        res = R.analyze(model)
        self.assertEqual(res["disclosed_dim"], 1)
        self.assertEqual(res["status"], {"D": "recovered"})
        # w0 = N(lambda) N(1 - e2) e.c1 (FA1 section 6(i))
        lam, e, e2 = exp["lambda"], exp["e"], exp["e2"]
        s = ((1 - e2[0]) % P, (-e2[1]) % P)
        n = lambda z: (z[0] * z[0] - 7 * z[1] * z[1]) % P
        self.assertEqual(exp["w0"], (n(lam) * n(s) * e[1]) % P)

    def test_degenerate_base_field_e_is_not_disclosed_by_L_b(self):
        # e in the base field: a and c are Fp-dependent, so det(a, c) = 0 and the
        # single vector hides D (FA1's degeneracy case, probability ~2^-64).
        m = R.Model("degenerate")
        m.data_unknown("D")
        m.mask_unknown("R")
        lam = (5, 9)
        e = (3, 0)
        m.observe("v", {"D": R.f2_mul(lam, R.f2_sub(R.ONE, e)), "R": R.f2_mul(lam, e)})
        res = R.analyze(m)
        self.assertEqual(res["disclosed_dim"], 0)


class PairFixtureB(unittest.TestCase):
    """(b) an independent Fp2 mask pair: protection (the zk60_mask_rank.rs control)."""

    def test_pair_protects(self):
        res = R.analyze(R.fixture_pair(seed=2))
        self.assertEqual(res["disclosed_dim"], 0)
        self.assertEqual(res["rank_mask"], 2)
        self.assertEqual(res["status"], {"D": "protected"})
        self.assertEqual(res["surviving_data_functionals"], [])

    def test_degenerate_pair_discloses(self):
        res = R.analyze(R.fixture_pair(seed=2, degenerate=True))
        self.assertEqual(res["disclosed_dim"], 1)
        self.assertEqual(res["status"], {"D": "recovered"})

    def test_pair_is_a_one_time_pad_numerically(self):
        # independent of the tool: for fixed v, every D has exactly one (R_re, R_im)
        lam, e = (11, 13), (17, 19)
        a, c = ((1 - e[0]) % P, (-e[1]) % P), e
        b = hand_mul(lam, c)
        bu = hand_mul(b, (0, 1))
        la = hand_mul(lam, a)
        detb = hand_det(b, bu)
        self.assertNotEqual(detb, 0)
        rng = random.Random(5)
        v = rand_fp2(rng)
        for D in (0, 1, 12345, P - 1):
            t = ((v[0] - la[0] * D) % P, (v[1] - la[1] * D) % P)
            # solve r*b + s*bu = t
            r = (hand_det(t, bu) * pow(detb, P - 2, P)) % P
            s = (hand_det(b, t) * pow(detb, P - 2, P)) % P
            back = ((r * b[0] + s * bu[0]) % P, (r * b[1] + s * bu[1]) % P)
            self.assertEqual(back, t)


class TwoRowFixtureC(unittest.TestCase):
    """(c) T32: two data rows under one base mask -> one functional per column, (1, kappa)."""

    def test_one_functional_with_fa1_kappa(self):
        model, exp = R.fixture_two_rows(seed=3)
        res = R.analyze(model)
        self.assertEqual(res["disclosed_dim"], 1)
        self.assertEqual(res["status"], {"D0": "disclosed", "D1": "disclosed"})
        (f,) = res["surviving_data_functionals"]
        self.assertEqual(f["D0"], 1)
        # independent: kappa = det(lambda a p0, lambda c) / det(lambda a (1 - p0), lambda c)
        lam, e, p0 = exp["lambda"], exp["e"], exp["p0"]
        a, c = ((1 - e[0]) % P, (-e[1]) % P), e
        la, lc = hand_mul(lam, a), hand_mul(lam, c)
        w0 = hand_det(hand_mul(la, ((1 - p0[0]) % P, (-p0[1]) % P)), lc)
        w1 = hand_det(hand_mul(la, p0), lc)
        kappa = (w1 * pow(w0, P - 2, P)) % P
        self.assertEqual(f["D1"], kappa)
        # and w0 + w1 = det(lambda a, lambda c) (FA1 section 6(ii))
        self.assertEqual((w0 + w1) % P, hand_det(la, lc))


class ReuseFixtureD(unittest.TestCase):
    """(d) one mask row in two observations."""

    def test_reuse_recovers_both_rows_control_recovers_one(self):
        res = R.analyze(R.fixture_reuse(seed=4, reuse=True))
        self.assertEqual(res["disclosed_dim"], 2)
        self.assertEqual(res["status"], {"D1": "recovered", "D2": "recovered"})
        ctl = R.analyze(R.fixture_reuse(seed=4, reuse=False))
        self.assertEqual(ctl["disclosed_dim"], 1)
        self.assertEqual(ctl["status"], {"D1": "recovered", "D2": "protected"})


class GroupWithValuesRule(unittest.TestCase):
    """vector + terminal values of one group: rank(B) = 2m + 2n - 4 and exactly two
    surviving data functionals for an all-base group with m >= 2; n for m = 1;
    zero once any member's mask is Fp2-effective."""

    def test_all_base_groups_leak_two(self):
        for m, n in ((2, 2), (2, 4), (3, 4), (7, 4), (7, 8), (9, 4)):
            res = R.analyze(R.group_with_values(m, n, ["base1"] * m, seed=100 + m + n))
            self.assertEqual(res["rank_mask"], 2 * m + 2 * n - 4, (m, n))
            self.assertEqual(res["disclosed_dim"], 2, (m, n))
            self.assertEqual(res["observation_functionals_killing_masks_but_not_data"], 2, (m, n))
            self.assertEqual(len(res["summary"]["protected"]), 0, (m, n))

    def test_singleton_with_value_leaks_n(self):
        for n in (2, 4, 8):
            res = R.analyze(R.group_with_values(1, n, ["base1"], seed=200 + n))
            self.assertEqual(res["disclosed_dim"], n)
            self.assertEqual(len(res["summary"]["recovered"]), n)

    def test_fp2_effective_member_covers(self):
        self.assertEqual(R.analyze(R.group_with_values(3, 4, ["pair"] * 3, seed=41))["disclosed_dim"], 0)
        self.assertEqual(R.analyze(R.group_with_values(3, 4, ["base1", "base2", "base1"], seed=42))["disclosed_dim"], 0)
        self.assertEqual(R.analyze(R.group_with_values(2, 4, ["pair", "base1"], seed=43))["disclosed_dim"], 0)
        res = R.analyze(R.group_with_values(3, 4, ["pair"] * 3, seed=41))
        self.assertEqual(res["rank_mask"], 2 * 3 + 2 * 4 - 2)

    def test_kernel_count_matches_the_hand_derivation(self):
        # kernel of B for the all-base case = K1 (x) K2, dim (m-2)(n-2)
        for m, n in ((3, 4), (4, 4), (7, 8)):
            res = R.analyze(R.group_with_values(m, n, ["base1"] * m, seed=300 + m + n))
            self.assertEqual(m * n - res["rank_mask"], (m - 2) * (n - 2))


class JointTinyLayouts(unittest.TestCase):
    """whole-commitment small-n models of the tiny d16/f16 layouts."""

    TINY = {"nb_d": 1, "nb_f": 1, "rows_per_f_plane": 1, "rows_per_d_plane": 1, "table_rows": [1, 2, 1, 1, 2, 1], "n": 4, "log_n": 2, "rows_per_w_block": 1}

    def test_A_joint_equals_two_singletons_plus_two_value_leaks(self):
        n = 4
        for rows in (1, 2):
            lay = dict(self.TINY, rows_per_f_plane=rows, rows_per_d_plane=rows)
            for p3 in (False, True):
                res = R.analyze(R.commitment_with_values("A", R.a_commitment_groups(lay, p3=p3), n))
                # 2 singletons x n columns + 2 (rho_f values) + 2 (rho_d values) + 0 (tables: INT16 slot is 2 rows)
                self.assertEqual(res["disclosed_dim"], 2 * n + 2 + 2, (rows, p3))
                self.assertEqual(res["observation_functionals_killing_masks_but_not_data"], 2 * 5)
                if rows == 1:
                    rec = set(res["summary"]["recovered"])
                    self.assertEqual(rec, {f"rho_d/X0/D0[{j}]" for j in range(n)} | {f"rho_f/h160/D0[{j}]" for j in range(n)})
                else:
                    self.assertEqual(res["summary"]["recovered"], [])

    def test_A_per_column_only_the_singletons(self):
        for family in ((2, 16, 16, 5), (32, 16, 16, 8), (32, 768, 2048, 14), (32, 4096, 14336, 14)):
            lay = R.layout_v3(*family)
            res = R.analyze(R.per_column_commitment("A", R.a_commitment_groups(lay), seed=11))
            singles = int(lay["nb_d"] == 1) + int(lay["nb_f"] == 1)
            self.assertEqual(res["disclosed_dim"], singles, family)
            touched = {k.rsplit("/", 1)[0] for k in res["summary"]["recovered"] + res["summary"]["disclosed"]}
            want = set()
            if lay["nb_d"] == 1:
                want.add("rho_d/X0")
            if lay["nb_f"] == 1:
                want.add("rho_f/h160")
            self.assertEqual(touched, want, family)

    def test_H_joint_and_per_column_are_covered(self):
        for rows in (1, 2):
            lay = dict(self.TINY, rows_per_f_plane=rows, rows_per_d_plane=rows)
            self.assertEqual(R.analyze(R.commitment_with_values("H", R.h_commitment_groups(lay), 4))["disclosed_dim"], 0)
        for family in ((2, 16, 16, 5), (32, 16, 16, 8), (32, 768, 2048, 14), (32, 4096, 14336, 14)):
            lay = R.layout_v3(*family)
            self.assertEqual(R.analyze(R.per_column_commitment("H", R.h_commitment_groups(lay), seed=12))["disclosed_dim"], 0, family)

    def test_H_logup_sum_residual_is_exactly_the_public_identity(self):
        for n, nh, nt in ((4, 2, 1), (8, 3, 2)):
            model, ident = R.fixture_logup_sum(n, nh, nt)
            res = R.analyze(model)
            self.assertEqual(res["disclosed_dim"], 2)
            F = [[f.get(x, 0) for x in model.data] for f in res["surviving_data_functionals"]]
            I = [[r.get(x, 0) for x in model.data] for r in ident]
            self.assertEqual(R.rank(I), 2)
            self.assertEqual(R.rank(F + I), 2, "the surviving functionals are not the LogUp identity")

    def test_W_p3_tiny_and_125M_like(self):
        n = 4
        res = R.analyze(R.commitment_with_values("W", R.w_commitment_groups(self.TINY), n))
        # Wd whole (n) + one (Wg, Wu) functional per column (n) + two p3 value functionals
        self.assertEqual(res["disclosed_dim"], 2 * n + 2)
        self.assertEqual(set(res["summary"]["recovered"]), {f"p6/Wd_0_0/D0[{j}]" for j in range(n)})
        res3 = R.analyze(R.commitment_with_values("W", R.w_commitment_groups(dict(self.TINY, nb_d=3)), n))
        self.assertEqual(res3["disclosed_dim"], 4)
        self.assertEqual(res3["summary"]["recovered"], [])
        # per column: the tiny W prox is starved (4 masks vs 6 dims), 125M/8B are not
        for family, want in (((32, 16, 16, 8), 2), ((2, 16, 16, 5), 2), ((32, 768, 2048, 14), 0), ((32, 4096, 14336, 14), 0)):
            lay = R.layout_v3(*family)
            self.assertEqual(R.analyze(R.per_column_commitment("W", R.w_commitment_groups(lay), seed=13))["disclosed_dim"], want, family)


class LayoutPredicate(unittest.TestCase):
    def test_nb_and_rows(self):
        lay = R.layout_v3(2, 16, 16, 5)
        self.assertEqual((lay["nb_d"], lay["nb_f"], lay["log_n"], lay["rows_per_d_plane"], lay["rows_per_f_plane"], lay["rows_per_w_block"]), (1, 1, 5, 1, 1, 8))
        self.assertEqual(lay["table_rows"], [8, 2048, 4, 1, 512, 2])
        lay = R.layout_v3(32, 16, 16, 8)
        self.assertEqual((lay["nb_d"], lay["nb_f"], lay["log_n"], lay["rows_per_d_plane"], lay["rows_per_f_plane"], lay["rows_per_w_block"]), (1, 1, 8, 2, 2, 1))
        self.assertEqual(lay["table_rows"], [1, 256, 1, 1, 64, 1])
        lay = R.layout_v3(32, 768, 2048, 14)
        self.assertEqual((lay["nb_d"], lay["nb_f"], lay["log_n"]), (3, 1, 13))
        lay = R.layout_v3(64, 768, 2048, 14)
        self.assertEqual((lay["log_n"], lay["rows_per_f_plane"], lay["rows_per_d_plane"]), (14, 8, 1))
        lay = R.layout_v3(32, 4096, 14336, 14)
        self.assertEqual((lay["nb_d"], lay["nb_f"], lay["log_n"], lay["rows_per_d_plane"], lay["rows_per_f_plane"]), (1, 7, 14, 8, 4))
        lay = R.layout_v3(8, 4096, 14336, 14)
        self.assertEqual((lay["log_n"], lay["rows_per_d_plane"]), (14, 2))

    def test_classification_rule(self):
        self.assertEqual(R.classify_group(1, True, 256, 2)["functionals_per_proof"], 256)
        self.assertEqual(R.classify_group(3, True, 256, 2)["functionals_per_proof"], 2)
        self.assertEqual(R.classify_group(3, False, 256, 2)["functionals_per_proof"], 0)
        self.assertIn("NOT unique", R.range_note(16, 8))
        self.assertIn("exact", R.range_note(1, 8))
        self.assertIn("enumerable", R.range_note(2, 8))


class RepairedAllocationFA3(unittest.TestCase):
    """FA3 (ZK60_FABLE_MASK_REPAIR.md): the repaired allocation -- every single-row
    mask an Fp2 pair, every proximity row a pair, seam terminals pair-masked on the
    actual A commitment -- evaluated on every FA2 group shape, with the legacy
    number beside it and the negative controls that show which rule carries what."""

    TINY = JointTinyLayouts.TINY

    def test_pairmask_pair_is_a_one_time_pad_for_the_p3_coefficient_pair(self):
        # independent of the tool: with (k1, k1 u) on (R_re, R_im), for fixed v every D
        # has exactly one mask pair -- ALSO when the P3 second-extension factor is present
        lam, e, e2 = (11, 13), (17, 19), (23, 29)
        s = ((1 - e2[0]) % P, (-e2[1]) % P)
        k0 = hand_mul(s, ((1 - e[0]) % P, (-e[1]) % P))
        k1 = hand_mul(s, e)
        b = hand_mul(lam, k1)
        bu = hand_mul(b, (0, 1))
        self.assertNotEqual(hand_det(b, bu), 0)
        la = hand_mul(lam, k0)
        rng = random.Random(9)
        v = rand_fp2(rng)
        detb = hand_det(b, bu)
        for D in (0, 1, 4242, P - 1):
            t = ((v[0] - la[0] * D) % P, (v[1] - la[1] * D) % P)
            r = (hand_det(t, bu) * pow(detb, P - 2, P)) % P
            s_ = (hand_det(b, t) * pow(detb, P - 2, P)) % P
            self.assertEqual(((r * b[0] + s_ * bu[0]) % P, (r * b[1] + s_ * bu[1]) % P), t)
        # and the base-field-e degeneracy of FA1 is gone: e in Fp still gives an independent pair
        e_base = (17, 0)
        b2 = hand_mul(lam, hand_mul(s, e_base))
        self.assertNotEqual(hand_det(b2, hand_mul(b2, (0, 1))), 0)

    def test_all_pairmask_groups_disclose_nothing_with_rank_2m_plus_2n_minus_2(self):
        for m, n in ((1, 4), (2, 2), (2, 4), (3, 4), (7, 4), (7, 8), (9, 4)):
            res = R.analyze(R.group_with_values(m, n, ["pairmask"] * m, seed=700 + m + n))
            self.assertEqual(res["rank_mask"], 2 * m + 2 * n - 2, (m, n))
            self.assertEqual(res["disclosed_dim"], 0, (m, n))
            self.assertEqual(res["observation_functionals_killing_masks_but_not_data"], 2, (m, n))
            self.assertEqual(len(res["summary"]["protected"]), m * n, (m, n))
            with_prox = R.analyze(R.group_with_values(m, n, ["pairmask"] * m, seed=700 + m + n, with_prox=True, prox_pair=True))
            self.assertEqual(with_prox["disclosed_dim"], 0, (m, n))
            # the legacy all-base group beside it: n (singleton) or 2 (FA2 14.1 / 14.2)
            legacy = R.analyze(R.group_with_values(m, n, ["base1"] * m, seed=700 + m + n))["disclosed_dim"]
            self.assertEqual(legacy, n if m == 1 else 2, (m, n))

    def test_prox_pair_is_required_not_optional(self):
        single = [{"name": "g", "members": [{"name": "D", "data_rows": 1, "mask_rows": 1, "kind": "pairmask"}]}]
        self.assertEqual(R.analyze(R.per_column_commitment("x", single, seed=71))["disclosed_dim"], 1)
        self.assertEqual(R.analyze(R.per_column_commitment("x", single, seed=71, prox_pair=True))["disclosed_dim"], 0)

    def test_seam_only_pairs_do_not_repair_the_legacy_A(self):
        n = 4
        legacy = R.a_commitment_groups(self.TINY)
        seams = [g for g in R.a_commitment_groups_repaired(self.TINY, seams=True) if g["name"] in ("sx", "sz")]
        res = R.analyze(R.commitment_with_values("legacy + seams", legacy + seams, n, seed=81))
        self.assertEqual(res["disclosed_dim"], 2 * n + 2 + 2)
        rec = set(res["summary"]["recovered"])
        self.assertEqual(rec, {f"rho_d/X0/D0[{j}]" for j in range(n)} | {f"rho_f/h160/D0[{j}]" for j in range(n)})

    def test_whole_tiny_commitments_repaired_are_covered(self):
        n = 4
        for rows in (1, 2):
            lay = dict(self.TINY, rows_per_f_plane=rows, rows_per_d_plane=rows)
            for p3 in (False, True):
                for seams in (False, True):
                    res = R.analyze(R.commitment_with_values("A", R.a_commitment_groups_repaired(lay, p3=p3, seams=seams), n, seed=90, prox_pair=True))
                    self.assertEqual(res["disclosed_dim"], 0, (rows, p3, seams))
                    # every group's trivial identity survives, nothing else: 5 groups (+2 seams)
                    self.assertEqual(res["observation_functionals_killing_masks_but_not_data"], 2 * (5 + (2 if seams else 0)), (rows, p3, seams))
            self.assertEqual(R.analyze(R.commitment_with_values("H", R.h_commitment_groups_repaired(lay), n, seed=91, prox_pair=True))["disclosed_dim"], 0)
        self.assertEqual(R.analyze(R.commitment_with_values("W", R.w_commitment_groups_repaired(self.TINY), n, seed=92, prox_pair=True))["disclosed_dim"], 0)
        self.assertEqual(R.analyze(R.commitment_with_values("W", R.w_commitment_groups_repaired(dict(self.TINY, nb_d=3)), n, seed=93, prox_pair=True))["disclosed_dim"], 0)
        self.assertEqual(R.analyze(R.commitment_with_values("A f2", R.a_commitment_groups_repaired(self.TINY, predicate=True, seams=True), n, seed=96, prox_pair=True))["disclosed_dim"], 0)

    def test_logup_sum_residual_is_still_exactly_the_identity_with_the_prox_pair(self):
        for n, nh, nt in ((4, 2, 1), (8, 3, 2)):
            model, ident = R.fixture_logup_sum(n, nh, nt, seed=94, prox_pair=True)
            res = R.analyze(model)
            self.assertEqual(res["disclosed_dim"], 2)
            F = [[f.get(x, 0) for x in model.data] for f in res["surviving_data_functionals"]]
            I = [[r.get(x, 0) for x in model.data] for r in ident]
            self.assertEqual(R.rank(I), 2)
            self.assertEqual(R.rank(F + I), 2)

    def test_per_column_families_repaired_are_covered_and_legacy_numbers_unchanged(self):
        for family, legacy_a, legacy_w in (((2, 16, 16, 5), 2, 2), ((32, 16, 16, 8), 2, 2), ((32, 768, 2048, 14), 1, 0), ((32, 4096, 14336, 14), 1, 0)):
            lay = R.layout_v3(*family)
            for groups in (R.a_commitment_groups_repaired(lay), R.a_commitment_groups_repaired(lay, seams=True), R.a_commitment_groups_repaired(lay, p3=True, seams=True), R.a_commitment_groups_repaired(lay, predicate=True, seams=True), R.h_commitment_groups_repaired(lay), R.w_commitment_groups_repaired(lay)):
                self.assertEqual(R.analyze(R.per_column_commitment("m", groups, seed=5, prox_pair=True))["disclosed_dim"], 0, family)
            self.assertEqual(R.analyze(R.per_column_commitment("A", R.a_commitment_groups(lay), seed=11))["disclosed_dim"], legacy_a, family)
            self.assertEqual(R.analyze(R.per_column_commitment("W", R.w_commitment_groups(lay), seed=13))["disclosed_dim"], legacy_w, family)

    def test_log_cols_16_pairs_every_table_slot(self):
        lay16 = R.layout_v3(32, 4096, 14336, 16)
        self.assertEqual(lay16["log_n"], 16)
        self.assertEqual(lay16["table_rows"], [1, 1, 1, 1, 1, 1])
        rep = R.a_commitment_groups_repaired(lay16, seams=True)
        tab = next(g for g in rep if g["name"] == "tab")
        self.assertTrue(all(m["kind"] == "pairmask" for m in tab["members"]))
        self.assertEqual(R.analyze(R.group_with_values(6, 4, ["base1"] * 6, seed=120))["disclosed_dim"], 2)
        self.assertEqual(R.analyze(R.group_with_values(6, 4, ["pairmask"] * 6, seed=120, with_prox=True, prox_pair=True))["disclosed_dim"], 0)
        self.assertEqual(R.analyze(R.per_column_commitment("A16", rep, seed=121, prox_pair=True))["disclosed_dim"], 0)

    def test_repaired_kinds_rule_pairs_exactly_the_single_row_sites(self):
        lay = R.layout_v3(32, 16, 16, 8)   # table rows [1, 256, 1, 1, 64, 1]
        rep = R.a_commitment_groups_repaired(lay, seams=True)
        kinds = {g["name"]: [m["kind"] for m in g["members"]] for g in rep}
        self.assertEqual(kinds["rho_f"], ["pairmask"] * 7)
        self.assertEqual(kinds["rho_d"], ["pairmask"] * 3)
        self.assertEqual(kinds["p2"], ["pairmask"])
        self.assertEqual(kinds["p5"], ["pairmask"])
        self.assertEqual(kinds["tab"], ["pairmask", "base", "pairmask", "pairmask", "base", "pairmask"])
        self.assertEqual(kinds["sx"], ["pairmask"])
        self.assertEqual(kinds["sz"], ["pairmask"])
        sx = next(g for g in rep if g["name"] == "sx")
        self.assertEqual(sx["members"][0]["data_alias"], "rho_d/X0")
        sz = next(g for g in rep if g["name"] == "sz")
        self.assertEqual(sz["members"][0]["data_alias"], "rho_d/z0")
        self.assertTrue(all(m["kind"] == "pairmask" for g in R.w_commitment_groups_repaired(lay) for m in g["members"]))

    def test_commitment_rows_match_the_pinned_legacy_counts_and_give_the_delta(self):
        t2 = R.commitment_rows(R.layout_v3(2, 16, 16, 5))
        self.assertEqual(t2["A"]["legacy_rows"], 5173)          # FA1 section 4.3
        t32 = R.commitment_rows(R.layout_v3(32, 16, 16, 8), seams=True)
        self.assertEqual((t32["A"]["legacy_rows"], t32["H"]["legacy_rows"], t32["W_P3"]["legacy_rows"]), (681, 1325, 7))   # zk60_pending_layout.rs
        self.assertEqual((t32["A"]["extra_rows"], t32["H"]["extra_rows"], t32["W_P3"]["extra_rows_per_slot"]), (21, 1, 4))
        self.assertEqual(R.commitment_rows(R.layout_v3(32, 16, 16, 8))["A"]["extra_rows"], 17)   # standalone: no seam pairs
        b8 = R.commitment_rows(R.layout_v3(512, 4096, 14336, 14))
        self.assertEqual((b8["W_P3"]["data_rows"], b8["W_P3"]["legacy_rows"]), (10752, 10774))   # zk60_memory_layout.rs
        m125 = R.commitment_rows(R.layout_v3(512, 768, 2048, 14))
        self.assertEqual((m125["W_P3"]["data_rows"], m125["W_P3"]["legacy_rows"]), (288, 298))
        # the function-2 layout adds one bit row + two masks (legacy) / two pairs (repaired)
        f2 = R.commitment_rows(R.layout_v3(32, 16, 16, 8), predicate=True)
        self.assertEqual(f2["A"]["legacy_mask_rows"] - t32["A"]["legacy_mask_rows"], 2)
        self.assertEqual(f2["A"]["extra_breakdown"]["predicate_pairs"], 2)

    def test_repair_report_passes_and_carries_the_schedule(self):
        rep = R.repair_report()
        self.assertEqual(rep["failures"], 0)
        self.assertTrue(all(v["verdict"] == "PASS" for v in rep["rank_verdicts"].values()))
        self.assertTrue(all(m["verdict"] == "PASS" for e in rep["families"].values() for m in e["models"].values()))
        self.assertEqual(rep["rank_verdicts"]["negative_control_one_pairmask_claim_single_prox_row"]["disclosed_dim"], 1)
        self.assertEqual(rep["rank_verdicts"]["negative_control_seam_only_pairs_on_legacy_A"]["disclosed_dim"], 12)
        sch = rep["schedule"]
        self.assertEqual(sch["profile"], "ffn-v3-mr1")
        self.assertEqual({r["role"] for r in sch["commitments"]["A"]["mask_roles_in_allocation_order"]}, {"a_mf[k]", "a_md[k]", "a_mgu[c]", "a_mdd[b]", "a_prox", "tab[i].a_mask", "a_pmz, a_pmb", "a_sx[c]", "a_sz[c]"})
        self.assertIn("SC_SEAM_Z", " ".join(sch["commitments"]["M_cfs"]["slots_in_order"]))
        self.assertIn("not a simulation proof", R.analyze(R.fixture_pair())["caveat"])

    def test_repair_cli(self):
        with tempfile.TemporaryDirectory() as td:
            out = os.path.join(td, "repair.json")
            self.assertEqual(R.main(["repair", "-o", out]), 0)
            with open(out) as fh:
                back = json.load(fh)
            self.assertEqual(back["failures"], 0)
            self.assertIn("schedule", back)


class JsonInterface(unittest.TestCase):
    def test_roundtrip_and_cli(self):
        model, _ = R.fixture_two_rows(seed=3)
        d = model.to_json()
        res_direct = R.analyze(model)
        res_json = R.analyze_json(json.loads(json.dumps(d)))
        self.assertEqual(res_direct["surviving_data_functionals"], res_json["surviving_data_functionals"])
        with tempfile.TemporaryDirectory() as td:
            inp = os.path.join(td, "m.json")
            out = os.path.join(td, "r.json")
            with open(inp, "w") as fh:
                json.dump(d, fh)
            self.assertEqual(R.main(["analyze", inp, "-o", out]), 0)
            with open(out) as fh:
                back = json.load(fh)
            self.assertEqual(back["disclosed_dim"], 1)

    def test_hand_written_model_with_fp_rows(self):
        d = {"name": "x", "data": ["D"], "masks": ["R"], "observations": [
            {"name": "o1", "domain": "Fp", "coeffs": {"D": 3, "R": 5}},
            {"name": "o2", "domain": "Fp", "coeffs": {"D": 7, "R": 5}},
        ]}
        res = R.analyze_json(d)
        self.assertEqual(res["disclosed_dim"], 1)
        self.assertEqual(res["status"], {"D": "recovered"})

    def test_reports_carry_the_caveat(self):
        self.assertIn("not a simulation proof", R.analyze(R.fixture_pair())["caveat"])


if __name__ == "__main__":
    unittest.main()

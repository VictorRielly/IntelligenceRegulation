"""Tests for scripts/zk60_joint_cfs_view.py (the joint CFS view).

Synthetic fixtures only; the real round-22 captures are a separate mandatory CLI run
(results/zk60_mvp_joint_view_evidence/cfs_view/).  Covered: the sparse elimination
against FA6's dense Fp2 rank, the (n=3, d=2) slot against a brute-force enumeration
over F_5, the batched matmul/zero-check pair, the refused cases (c = 0, zero terminal
challenge) and degenerate challenge sequences, corrupted round messages, the M pad /
blinder controls at toy size against FA6's exact models, the 14-functional assignment
and the challenge derivation on a synthetic capture, and the challenge-file loader.

    python3 -m unittest discover -s tests -p 'test_zk60_joint_cfs_view.py' -v
"""
import importlib.util
import itertools
import json
import sys
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("zk60_joint_cfs_view", Path(__file__).resolve().parents[1] / "scripts/zk60_joint_cfs_view.py")
T = importlib.util.module_from_spec(SPEC)
sys.modules["zk60_joint_cfs_view"] = T
SPEC.loader.exec_module(T)
C = T.C
ZERO, ONE = T.ZERO, T.ONE

P1_SPECS = [[5, 2], [5, 2], [10, 4], [10, 4], [9, 2], [17, 3], [10, 2], [10, 2]]
SMALL_SPECS = [[3, 2], [3, 2], [4, 4], [4, 4], [3, 2], [4, 3], [10, 2], [10, 2]]


def nonzero(rng):
    x = rng.fp2()
    while x == ZERO:
        x = rng.fp2()
    return x


def challenges(specs, rng):
    ch = {}
    for name, s in T.FFN_SLOTS.items():
        n, d = specs[s]
        rho = [rng.fp2() for _ in range(n - 1)] + [nonzero(rng)]
        ch[name] = {"c": nonzero(rng), "rho": rho, "n": n, "d": d}
    ch["zc20"]["nu"], ch["zc17"]["nu"] = nonzero(rng), nonzero(rng)
    return ch


def synthetic_models(specs, rng):
    """All eight slots synthetic (the FFN six through the tool's stand-in path, the IO two as zero-claimed (10, 2) slots)."""
    ch = challenges(specs, rng)
    models = T.stand_in_ffn_models({"mask": {"specs": specs}}, ch, rng)
    for side in (0, 1):
        rho = [rng.fp2() for _ in range(9)] + [nonzero(rng)]
        models[f"io{side}"] = T.synthetic_slot(f"io{side}", 6 + side, 10, 2, nonzero(rng), rho, rng, "zero")
    return models, ch


def synthetic_capture(specs, rng):
    """A capture-shaped dict whose functionals, rounds, claims and gammas follow zk.rs mask_functionals /
    zk_ffn_fresh_io.rs functionals exactly (transcript order for ffn_arguments / ffn_gammas)."""
    models, ch = synthetic_models(specs, rng)
    sw = lambda m, scale: [list(C.f2_mul(scale, w)) for w in m.sum_weights]
    ew = lambda m: [list(w) for w in m.eval_weights]
    F = [{"terms": [{"slot": s, "weights": ew(models[n])}], "value": list(models[n].eval_value)} for n, s in T.FFN_SLOTS.items()]
    F += [
        {"terms": [{"slot": 2, "weights": sw(models["zc20"], models["zc20"].c)}, {"slot": 0, "weights": sw(models["gu"], C.f2_neg(C.f2_mul(ch["zc20"]["nu"], models["gu"].c)))}], "value": list(models["zc20"].claim)},
        {"terms": [{"slot": 3, "weights": sw(models["zc17"], models["zc17"].c)}, {"slot": 1, "weights": sw(models["d"], C.f2_neg(C.f2_mul(ch["zc17"]["nu"], models["d"].c)))}], "value": list(models["zc17"].claim)},
        {"terms": [{"slot": 4, "weights": sw(models["zs"], models["zs"].c)}], "value": list(models["zs"].claim)},
        {"terms": [{"slot": 5, "weights": sw(models["tab"], models["tab"].c)}], "value": list(models["tab"].claim)},
    ]
    io_args = []
    for side in (0, 1):
        m = models[f"io{side}"]
        F.append({"terms": [{"slot": 6 + side, "weights": sw(m, m.c)}], "value": list(m.claim)})
        F.append({"terms": [{"slot": 6 + side, "weights": ew(m)}], "value": list(m.eval_value)})
        io_args.append({"side": side, "slot": 6 + side, "c": list(m.c), "rho": [list(r) for r in m.rho], "gamma": list(m.claim),
                        "mask_eval": list(m.eval_value), "rounds": [[list(x) for x in r] for r in m.rounds]})
    cap = {
        "proof_sha256": "synthetic", "privacy": "P1", "profile": T.PROFILE, "kind": "zk60-verifier-observations",
        "mask": {"specs": specs, "theta": list(rng.fp2()), "functionals": F},
        "io_arguments": io_args,
        "ffn_arguments": [{"name": n, "rounds": [[list(x) for x in r] for r in models[n].rounds]} for n in ("gu", "d", "zc20", "zc17", "tab", "zs")],
        "ffn_matmul_claims": [list(models["gu"].claim), list(models["d"].claim)],
        "ffn_gammas": [list(models["zc20"].claim), list(models["zc17"].claim), list(models["tab"].claim), list(models["zs"].claim)],
    }
    return cap, models, ch


class SparseElimination(unittest.TestCase):
    def test_sparse_echelon_matches_dense_fp2_rank_and_block_split(self):
        rng = C.Rng(11)
        for _ in range(6):
            dense = [[rng.fp2() if rng.r.random() < 0.6 else ZERO for _ in range(9)] for _ in range(6)]
            dense.append([C.f2_add(a, b) for a, b in zip(dense[0], dense[1])])   # a dependent row
            sparse = [{k: v for k, v in enumerate(r) if v != ZERO} for r in dense]
            piv = T.echelon(sparse)
            self.assertEqual(len(piv), C.f2_rank(dense))
            self.assertEqual(sum(1 for c in piv if c < 4), C.f2_rank([r[:4] for r in dense]))

    def test_back_substitution_solves_a_consistent_system_and_detects_inconsistency(self):
        rng = C.Rng(12)
        ncols, rhs = 7, 7
        rows = [{k: rng.fp2() for k in range(ncols) if rng.r.random() < 0.7} for _ in range(5)]
        x0 = [rng.fp2() for _ in range(ncols)]
        for r in rows:
            r[rhs] = C.f2_dot([r.get(k, ZERO) for k in range(ncols)], x0)
        x = T.back_substitute(T.echelon(rows), ncols + 1, rhs, free=lambda c: rng.fp2())
        for r in rows:
            self.assertEqual(C.f2_dot([r.get(k, ZERO) for k in range(ncols)], x), r[rhs])
        bad_row = dict(rows[0])
        bad_row[rhs] = C.f2_add(rows[0][rhs], ONE)
        self.assertIsNone(T.back_substitute(T.echelon([dict(r) for r in rows] + [bad_row]), ncols + 1, rhs))


def brute_view(a, rho, n, d, q):
    """(G, g(rho), rounds) of the CFS mask over the prime field F_q by definition (sums over the boolean cube)."""

    def g(pt):
        val, prod = a[0], 1
        for r in pt:
            prod = prod * r % q
        val += a[1] * prod
        for j in range(n):
            xp = 1
            for e in range(1, d + 1):
                xp = xp * pt[j] % q
                val += a[2 + j * d + e - 1] * xp
        return val % q

    total = sum(g([(idx >> (n - 1 - i)) & 1 for i in range(n)]) for idx in range(1 << n)) % q
    view = [total, g(rho)]
    for j in range(n):
        for x in range(d + 1):
            acc = 0
            for rest in range(1 << (n - 1 - j)):
                acc += g(list(rho[:j]) + [x] + [(rest >> (n - 2 - j - i)) & 1 for i in range(n - 1 - j)])
            view.append(acc % q)
    return view


def lagrange_q(d, r, q):
    out = []
    for i in range(d + 1):
        num, den = 1, 1
        for m in range(d + 1):
            if m != i:
                num = num * (r - m) % q
                den = den * (i - m) % q
        out.append(num * pow(den, q - 2, q) % q)
    return out


class BruteForceFibre(unittest.TestCase):
    """n = 3, d = 2 over F_5: every mask vector enumerated; the fibre sizes and the image size of the
    coefficient fibre must be the powers of 5 given by the tool's elimination (over F_5 on the same
    map, and over Goldilocks F_{p^2} on the synthetic slot)."""

    def test_enumeration_agrees_with_linear_algebra(self):
        q, n, d = 5, 3, 2
        L = n * d + 2
        rho = [2, 3, 4]
        units = [brute_view([1 if k == i else 0 for k in range(L)], rho, n, d, q) for i in range(L)]
        width = len(units[0])
        half = L // 2
        partial = {}
        for half_index in (0, 1):
            table = {}
            for coords in itertools.product(range(q), repeat=half):
                v = [0] * width
                for k, a in enumerate(coords):
                    if a:
                        u = units[half_index * half + k]
                        v = [(x + a * y) % q for x, y in zip(v, u)]
                table[coords] = v
            partial[half_index] = table
        buckets = {}
        for c0, v0 in partial[0].items():
            for c1, v1 in partial[1].items():
                key = tuple((x + y) % q for x, y in zip(v0, v1))
                buckets[key] = buckets.get(key, 0) + 1
        sizes = set(buckets.values())
        self.assertEqual(sizes, {q ** 1}, "every fibre has 5^1 elements")
        by_functionals = {}
        for key in buckets:
            by_functionals.setdefault(key[:2], set()).add(key[2:])
        self.assertEqual(len(by_functionals), q ** 2)
        self.assertEqual({len(s) for s in by_functionals.values()}, {q ** 5}, "the image of each coefficient fibre has 5^5 round vectors")
        for (total, ev), rounds_set in by_functionals.items():
            for rounds in list(rounds_set)[:50]:
                current = total
                for j in range(n):
                    h = rounds[j * (d + 1):(j + 1) * (d + 1)]
                    self.assertEqual((h[0] + h[1]) % q, current)
                    current = sum(l * x for l, x in zip(lagrange_q(d, rho[j], q), h)) % q
                self.assertEqual(current, ev)
        # the same map through the tool's elimination over F_5
        F5 = T.prime_field(q)
        rows = [{k: units[k][i] for k in range(L) if units[k][i]} for i in range(width)]
        rank_full = len(T.echelon(rows, F5))
        rank_functionals = len(T.echelon(rows[:2], F5))
        self.assertEqual(L - rank_full, 1)
        self.assertEqual(rank_full - rank_functionals, 5)
        chain = [{0: 1, 1: 1}]
        for j in range(1, n):
            row = {j * (d + 1): 1, j * (d + 1) + 1: 1}
            for x, lx in enumerate(lagrange_q(d, rho[j - 1], q)):
                row[(j - 1) * (d + 1) + x] = (-lx) % q
            chain.append(row)
        chain.append({(n - 1) * (d + 1) + x: lx for x, lx in enumerate(lagrange_q(d, rho[-1], q))})
        self.assertEqual(n * (d + 1) - len(T.echelon(chain, F5)), 5, "dim S(claim, final) = N d - 1")
        # and the Goldilocks F_{p^2} synthetic slot of the same shape
        rng = C.Rng(21)
        m = T.synthetic_slot("s", 0, n, d, nonzero(rng), [rng.fp2(), rng.fp2(), nonzero(rng)], rng, "zero")
        res = T.analyze_system(T.JointSystem([m]))
        self.assertEqual((res["mask_fibre_dim_fp2"], res["honest_subspace_dim_fp2"], res["honest_disclosed_dim_fp2"]), (1, 5, 0))


class SlotSystems(unittest.TestCase):
    def test_zero_claimed_slot_and_preimages(self):
        rng = C.Rng(31)
        for n, d in ((4, 3), (6, 2), (5, 4)):
            m = T.synthetic_slot("s", 0, n, d, nonzero(rng), [rng.fp2() for _ in range(n - 1)] + [nonzero(rng)], rng, "zero")
            system = T.JointSystem([m])
            res = T.analyze_system(system)
            self.assertEqual(res["mask_fibre_dim_fp2"], 1)
            self.assertEqual(res["honest_subspace_dim_fp2"], n * d - 1)
            self.assertEqual(res["honest_disclosed_dim_fp2"], 0)
            self.assertTrue(res["observations_consistent"] and res["honest_unconstrained"])
            pre = T.preimage_check(system, rng, samples=3)
            self.assertTrue(pre["preimages_verified"] and pre["same_fibre_dim"])
            self.assertEqual(pre["fibre_dims"], [1, 1, 1])
            m.replay_chain()

    def test_batched_matmul_pair_as_coded(self):
        rng = C.Rng(32)
        gu = T.synthetic_slot("gu", 0, 4, 2, nonzero(rng), [rng.fp2() for _ in range(3)] + [nonzero(rng)], rng, "matmul")
        zc = T.synthetic_slot("zc20", 2, 5, 4, nonzero(rng), [rng.fp2() for _ in range(4)] + [nonzero(rng)], rng, "batched", nu=nonzero(rng), partner=gu)
        system = T.JointSystem([gu, zc], pairs=[{"a": gu, "b": zc}])
        res = T.analyze_system(system)
        self.assertEqual(res["mask_fibre_dim_fp2"], 2)
        self.assertEqual(res["honest_subspace_dim_fp2"], 4 * 2 + 5 * 4 - 1)
        self.assertEqual(res["honest_disclosed_dim_fp2"], 0)
        self.assertTrue(res["honest_unconstrained"])
        pre = T.preimage_check(system, rng)
        self.assertEqual(pre["fibre_dims"], [2, 2])
        # the verifier's batched claimed sum nu gu_claim + Gamma20 holds on the zero-check
        self.assertEqual(C.f2_add(zc.rounds[0][0], zc.rounds[0][1]), C.f2_add(C.f2_mul(zc.nu, gu.claim), zc.claim))
        zc.replay_chain()
        with self.assertRaises(ValueError):
            T.JointSystem([zc])   # a batched zero-check needs its pair

    def test_composed_eight_slots_with_v_row(self):
        rng = C.Rng(33)
        cap, models, ch = synthetic_capture(SMALL_SPECS, rng)
        res = T.run_message_channel(cap, models, rng, "test")
        self.assertEqual(res["failures"], [])
        exp = T.expected_numbers(models)
        for key, r in res["systems"].items():
            for k, v in exp[key].items():
                self.assertEqual(r[k], v, f"{key}.{k}")
        comp = res["composed"]
        self.assertEqual(comp["mask_fibre_dim_fp2"], 8)
        self.assertEqual(comp["n_mask_unknowns_fp2"], sum(n * d + 2 for n, d in SMALL_SPECS))
        self.assertEqual(comp["mask_rank_fp2"], comp["n_mask_unknowns_fp2"] - 8)
        self.assertEqual(comp["honest_subspace_dim_fp2"], sum(n * d for n, d in SMALL_SPECS) - 6)
        self.assertEqual(comp["honest_disclosed_dim_fp2"], 0)
        self.assertTrue(comp["observations_consistent"] and comp["preimage"]["preimages_verified"])


class Controls(unittest.TestCase):
    def test_zero_mask_challenge_is_refused_and_discloses_the_honest_rounds_when_forced(self):
        rng = C.Rng(41)
        rho = [rng.fp2() for _ in range(3)] + [nonzero(rng)]
        with self.assertRaisesRegex(ValueError, "refused: zero mask challenge"):
            T.synthetic_slot("s", 0, 4, 3, ZERO, rho, rng, "zero")
        m = T.synthetic_slot("s", 0, 4, 3, ZERO, rho, rng, "zero", allow_degenerate=True)
        res = T.analyze_system(T.JointSystem([m]))
        self.assertEqual(res["honest_disclosed_dim_fp2"], res["honest_subspace_dim_fp2"])
        self.assertGreater(res["honest_subspace_dim_fp2"], 0)
        self.assertGreater(res["mask_fibre_dim_fp2"], 1)

    def test_zero_terminal_challenge_is_refused_and_degenerate_sequences_keep_the_fibre(self):
        rng = C.Rng(42)
        c = nonzero(rng)
        with self.assertRaisesRegex(ValueError, "refused: zero terminal mask challenge"):
            T.synthetic_slot("s", 0, 4, 3, c, [rng.fp2() for _ in range(3)] + [ZERO], rng, "zero")
        for chal in ([ZERO] * 4, [ONE] * 4, [(C.HALF, 0)] * 4, [ZERO, ZERO, ONE, (C.HALF, 0)]):
            m = T.synthetic_slot("s", 0, 4, 3, c, chal, rng, "zero", allow_degenerate=True)
            system = T.JointSystem([m])
            res = T.analyze_system(system)
            self.assertEqual((res["mask_fibre_dim_fp2"], res["honest_subspace_dim_fp2"], res["honest_disclosed_dim_fp2"]), (1, 11, 0))
            self.assertTrue(T.preimage_check(system, rng, samples=1)["preimages_verified"])

    def test_corrupted_round_message_fails_the_verifier_chain_and_leaves_the_subspace(self):
        rng = C.Rng(43)
        m = T.synthetic_slot("s", 0, 5, 2, nonzero(rng), [rng.fp2() for _ in range(4)] + [nonzero(rng)], rng, "zero")
        m.replay_chain()
        for j, x in ((0, 0), (2, 2), (4, 1)):
            bad = T.SlotModel("s", 0, 5, 2, m.c, m.rho, [list(r) for r in m.rounds], m.claim, m.eval_value, "zero")
            bad.rounds[j][x] = C.f2_add(bad.rounds[j][x], ONE)
            bad.want = m.want   # the honest final value is fixed by the masked terminals
            with self.assertRaises(ValueError):
                bad.replay_chain()
            self.assertFalse(T.analyze_system(T.JointSystem([bad]))["observations_consistent"])

    def test_message_channel_controls_run_on_synthetic_models(self):
        rng = C.Rng(44)
        models, _ = synthetic_models(SMALL_SPECS, rng)
        ctl = T.message_channel_controls(models, rng)
        self.assertTrue(ctl["nc_zero_mask_challenge"]["refused"] and ctl["nc_zero_mask_challenge"]["ok"])
        self.assertTrue(ctl["nc_zero_terminal_challenge"]["refused"] and ctl["nc_zero_terminal_challenge"]["ok"])
        self.assertTrue(ctl["nc_corrupted_round_messages"]["ok"])
        self.assertEqual(len([k for k in ctl["nc_corrupted_round_messages"] if k != "ok"]), 6)
        self.assertTrue(ctl["all_ok"])


class MOpeningBlocks(unittest.TestCase):
    """The pad / coefficient Lagrange blocks at FA6's toy size (m = 8, 3 coefficients, 3 pads) against
    FA6's exact m_columns_model, and the no-pad / exceed-pad controls."""

    def test_pad_block_disclosure_matches_fa6_toy_models(self):
        log_m, m, L, pads = 3, 8, 3, 3
        pts = C.coset_points(log_m)
        rng = C.Rng(51)
        idx = list(rng.r.sample(range(8 * m), 3))
        idx4 = idx + [next(j for j in range(8 * m) if j not in idx)]
        for indices, npads, expect in ((idx, pads, 0), (idx4, pads, 1), (idx, 0, L), (idx[:2] + [idx[0]], pads, 0)):
            distinct = sorted(set(indices))
            lag = {j: C.lagrange_on_subgroup(m, pts[j]) for j in distinct}
            mb = [[lag[j][i] for i in range(L, L + npads)] for j in distinct]
            db = [[lag[j][i] for i in range(L)] for j in distinct]
            r = T.block_disclosed(mb, db)
            self.assertEqual(r["disclosed_fp"], expect)
            self.assertEqual(r["disclosed_fp"], C.m_columns_model(log_m, L, npads, indices)["disclosed_coefficient_functionals"])

    def test_fp_rank_matches_fa2_rank(self):
        rng = C.Rng(52)
        rows = [[rng.fp() if rng.r.random() < 0.7 else 0 for _ in range(7)] for _ in range(5)]
        rows.append([(a + b) % C.P for a, b in zip(rows[0], rows[1])])
        self.assertEqual(T.fp_rank(rows), C.R.rank(rows))


class CaptureDerivation(unittest.TestCase):
    def test_functional_assignment_and_challenge_derivation_on_a_synthetic_capture(self):
        rng = C.Rng(61)
        cap, models, ch = synthetic_capture(P1_SPECS, rng)
        report = T.verify_functional_assignment(cap)
        self.assertEqual(len(report), 14)
        self.assertTrue(all(r["verified"] for r in report))
        derived = T.ffn_challenges_from_capture(cap)
        for name in T.FFN_SLOTS:
            self.assertEqual(derived[name]["rho"], ch[name]["rho"], name)
            self.assertEqual(derived[name]["c"], ch[name]["c"], name)
        self.assertEqual(derived["zc20"]["nu"], ch["zc20"]["nu"])
        self.assertEqual(derived["zc17"]["nu"], ch["zc17"]["nu"])
        rebuilt = T.captured_ffn_models(cap, derived)
        for m in rebuilt.values():
            m.replay_chain()
        ios = T.io_models(cap)
        res = T.run_message_channel(cap, dict(rebuilt, **ios), rng, "derived")
        self.assertEqual(res["failures"], [])
        # a tampered functional is caught
        bad = json.loads(json.dumps(cap))
        bad["mask"]["functionals"][6]["terms"][1]["slot"] = 1
        with self.assertRaises(ValueError):
            T.verify_functional_assignment(bad)
        bad = json.loads(json.dumps(cap))
        bad["mask"]["functionals"][3]["terms"][0]["weights"][5][0] ^= 1
        with self.assertRaises(ValueError):
            T.ffn_challenges_from_capture(bad)

    def test_challenge_file_loader_matches_and_flags_differences(self):
        rng = C.Rng(62)
        cap, models, ch = synthetic_capture(P1_SPECS, rng)
        derived = T.ffn_challenges_from_capture(cap)
        doc = {"tool": "zk60_transcript_replay.py", "captures": [{"sha": "synthetic", "privacy": "P1", "ffn_slots": [
            {"name": n, "mask_slot": s, "c": list(ch[n]["c"]), "rho": [list(r) for r in ch[n]["rho"]]} for n, s in T.FFN_SLOTS.items()]}]}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "replay.json"
            path.write_text(json.dumps(doc))
            _, entries = T.challenge_file_entries(path)
            filed = T.ffn_challenges_from_file(entries, cap)
            self.assertEqual(T.compare_challenges(derived, filed), [])
            doc["captures"][0]["ffn_slots"][2]["rho"][4][1] ^= 1
            path.write_text(json.dumps(doc))
            _, entries = T.challenge_file_entries(path)
            self.assertEqual(T.compare_challenges(derived, T.ffn_challenges_from_file(entries, cap)), ["zc20.rho"])
            with self.assertRaises(ValueError):
                T.ffn_challenges_from_file(entries, {"proof_sha256": "other"})


if __name__ == "__main__":
    unittest.main()

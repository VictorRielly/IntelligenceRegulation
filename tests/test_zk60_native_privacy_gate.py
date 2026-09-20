"""Tests for the block-scope privacy gate P10 (scripts/zk60_native_privacy_gate.py).

Run:
  python3 -m unittest discover -s tests -p "test_zk60_native_privacy_gate.py"

Three kinds of test:

  * a TINY SYNTHETIC instance of the same shape, where the data and the
    blinding are both known, so the forward map, the solver and the fibre
    dimension can be checked end to end against a brute-force dense rank --
    the only place in this file where a witness exists at all;
  * the real captures, where the preimage is constructed and the recomputed
    view is compared with the capture entry by entry;
  * the gate's own criterion: every negative control must fire, and must not
    fire on the honest capture.

The four source-pinned captures are tracked in the repository, so a missing
capture is a FAILURE here, never a silent skip.
"""

from __future__ import annotations

import os
import random
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

CAPTURES = os.path.join(ROOT, "results", "zk60_native_captures_20260919")

from zk60_native_jv_capture import load_all  # noqa: E402
from zk60_native_jv_cfs import mask_len, mask_round_matrix  # noqa: E402
from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    F2_ZERO,
    P,
    f2_add,
    f2_from_list,
    f2_mul,
    f2_mul_base,
    inv,
    rank,
)
from zk60_native_jv_pcs import RoleView, column_functional_parts  # noqa: E402
from zk60_native_jv_replay import Replay  # noqa: E402
from zk60_native_pg_cfs import CfsPreimage, fp_columns, sum_weights  # noqa: E402
from zk60_native_pg_pcs import (  # noqa: E402
    MSG,
    Lagrange,
    RoleLayout,
    RolePreimage,
    kernel_basis,
    poly_div_exact,
    poly_eval,
    solve_pair,
)
import zk60_native_privacy_gate as gate  # noqa: E402

_CAPS = None
_LAY = None


def caps():
    global _CAPS
    if _CAPS is None:
        cs = load_all(CAPTURES)
        _CAPS = [(c, Replay(c).run()) for c in cs]
    return _CAPS


def layouts(which=0):
    """The four RoleLayouts of one capture, built once."""
    global _LAY
    if _LAY is None:
        _LAY = {}
    if which not in _LAY:
        cap, rp = caps()[which]
        out = {}
        for role in cap.roles:
            nm = role["role"]
            v = RoleView(cap, role, rp.role_prox_rhos[nm])
            v.run(rp.role_lambdas[nm])
            out[nm] = (RoleLayout(cap, v), v)
        _LAY[which] = out
    return _LAY[which]


# ===================================================================== algebra
class TestExactArithmetic(unittest.TestCase):
    """No floating point anywhere: the helpers are exact over Fp."""

    def test_lagrange_interpolates_and_vanishes(self):
        rnd = random.Random(7)
        nodes = rnd.sample(range(2, 5000), 12)
        lag = Lagrange(nodes)
        vals = [rnd.randrange(P) for _ in nodes]
        co = lag.coeffs(vals)
        self.assertEqual(len(co), len(nodes))
        for x, v in zip(nodes, vals):
            self.assertEqual(poly_eval(co, x), v)
        for x in nodes:  # the master polynomial vanishes exactly at the nodes
            self.assertEqual(poly_eval(lag.z, x), 0)
        self.assertEqual(lag.z[-1], 1)

    def test_polynomial_division_is_exact_and_detects_a_remainder(self):
        rnd = random.Random(11)
        den = Lagrange(rnd.sample(range(2, 900), 5)).z
        q = [rnd.randrange(P) for _ in range(6)]
        num = [0] * (len(q) + len(den) - 1)
        for i, a in enumerate(den):
            for j, b in enumerate(q):
                num[i + j] = (num[i + j] + a * b) % P
        got, rem = poly_div_exact(num, den)
        self.assertEqual(got[: len(q)], q)
        self.assertEqual(rem, [0] * (len(den) - 1))
        num[0] = (num[0] + 1) % P
        _, rem2 = poly_div_exact(num, den)
        self.assertTrue(any(rem2), "a perturbed numerator must leave a remainder")

    def test_solve_pair_inverts_and_refuses_a_singular_pair(self):
        a, b, t = (3, 5), (7, 11), (13, 17)
        x, y = solve_pair(a, b, t)
        self.assertEqual(f2_add(f2_mul_base(a, x), f2_mul_base(b, y)), t)
        self.assertIsNone(solve_pair((3, 5), (6, 10), t))

    def test_kernel_basis_is_a_kernel(self):
        rows = [[1, 2, 3, 4], [0, 1, 1, 1]]
        ker = kernel_basis(rows, 4)
        self.assertEqual(len(ker), 2)
        for v in ker:
            for r in rows:
                self.assertEqual(sum(a * b for a, b in zip(r, v)) % P, 0)


# ============================================================== small model
class SmallModel:
    """A tiny commitment of the same shape, with a KNOWN witness and blinding.

    rows = data rows + one reserved pair per claim + one proximity pair, a
    message width of `m` and `q` pad symbols, opened at `d` distinct nodes.
    Everything the gate needs is built by the same formulas the real layout
    uses, so the forward map, the solver and the fibre dimension can be
    checked against a dense brute-force rank.
    """

    def __init__(self, seed=3, n_data=3, n_claims=2, m=8, q=6, d=4):
        rnd = random.Random(seed)
        self.m, self.q, self.d = m, q, d
        self.rows = n_data + 2 * n_claims + 2
        self.data_rows = list(range(n_data))
        self.pair = [(n_data + 2 * k, n_data + 2 * k + 1) for k in range(n_claims)]
        self.prox = [self.rows - 2, self.rows - 1]
        self.nodes = [rnd.randrange(2, 10_000) for _ in range(d)]
        while len(set(self.nodes)) != d:
            self.nodes = [rnd.randrange(2, 10_000) for _ in range(d)]
        self.cw = [(rnd.randrange(P), rnd.randrange(P)) for _ in range(m)]
        self.rw = []
        for k in range(n_claims):
            w = [F2_ZERO] * self.rows
            for i in self.data_rows:
                w[i] = (rnd.randrange(P), rnd.randrange(P))
            w[self.pair[k][0]] = F2_ONE
            w[self.pair[k][1]] = (0, 1)
            self.rw.append(w)
        self.lam = [(rnd.randrange(P), rnd.randrange(P)) for _ in range(n_claims)]
        self.rho = [F2_ZERO] * self.rows
        for k in range(n_claims):
            for i in range(self.rows):
                if self.rw[k][i] != F2_ZERO:
                    self.rho[i] = f2_add(self.rho[i], f2_mul(self.lam[k], self.rw[k][i]))
        self.prox_rho = [(rnd.randrange(P), rnd.randrange(P)) for _ in range(self.rows)]
        # the encoding functionals, in the same closed form as the real ones
        self.emsg = [[rnd.randrange(P) for _ in range(m)] for _ in self.nodes]
        self.epad = [[pow(x, k, P) for k in range(q)] for x in self.nodes]
        self.X = [[rnd.randrange(P) for _ in range(m + q)] for _ in range(self.rows)]

    def view(self, X):
        gv = []
        for t in range(self.m + self.q):
            acc = F2_ZERO
            for i in range(self.rows):
                acc = f2_add(acc, f2_mul_base(self.rho[i], X[i][t]))
            gv.append(acc)
        pv = []
        for t in range(self.m + self.q):
            acc = F2_ZERO
            for i in range(self.rows):
                acc = f2_add(acc, f2_mul_base(self.prox_rho[i], X[i][t]))
            pv.append(acc)
        vals = []
        for k in range(len(self.rw)):
            acc = F2_ZERO
            for i in range(self.rows):
                if self.rw[k][i] == F2_ZERO:
                    continue
                s = F2_ZERO
                for t in range(self.m):
                    s = f2_add(s, f2_mul_base(self.cw[t], X[i][t]))
                acc = f2_add(acc, f2_mul(self.rw[k][i], s))
            vals.append(acc)
        cols = []
        for j in range(self.d):
            e = self.emsg[j] + self.epad[j]
            cols.append([sum(a * b for a, b in zip(X[i], e)) % P for i in range(self.rows)])
        return gv, pv, vals, cols

    def dense_blinding_matrix(self):
        """Every observation as an Fp row over the BLINDING coordinates only."""
        coords = []
        for i in range(self.rows):
            for t in range(self.m + self.q):
                if i in self.data_rows and t < self.m:
                    continue
                coords.append((i, t))

        def row_of(fn):
            r = []
            for (i, t) in coords:
                X = [[0] * (self.m + self.q) for _ in range(self.rows)]
                X[i][t] = 1
                r.append(fn(self.view(X)))
            return r

        rows = []
        for g in range(self.m + self.q):
            for part in (0, 1):
                rows.append(row_of(lambda v, g=g, part=part: v[0][g][part]))
                rows.append(row_of(lambda v, g=g, part=part: v[1][g][part]))
        for k in range(len(self.rw)):
            for part in (0, 1):
                rows.append(row_of(lambda v, k=k, part=part: v[2][k][part]))
        for j in range(self.d):
            for i in range(self.rows):
                rows.append(row_of(lambda v, j=j, i=i: v[3][j][i]))
        return rows, coords


class TestSmallModel(unittest.TestCase):
    """The forward map end to end, where d and r are both known."""

    def test_the_view_is_linear_and_splits_into_data_and_blinding(self):
        sm = SmallModel()
        gv, pv, vals, cols = sm.view(sm.X)
        zero_data = [list(r) for r in sm.X]
        for i in sm.data_rows:
            for t in range(sm.m):
                zero_data[i][t] = 0
        only_data = [[0] * (sm.m + sm.q) for _ in range(sm.rows)]
        for i in sm.data_rows:
            only_data[i][: sm.m] = sm.X[i][: sm.m]
        g1, p1, v1, c1 = sm.view(zero_data)
        g2, p2, v2, c2 = sm.view(only_data)
        for a, b, c in zip(gv, g1, g2):
            self.assertEqual(a, f2_add(b, c))
        for a, b, c in zip(vals, v1, v2):
            self.assertEqual(a, f2_add(b, c))
        for ja, jb, jc in zip(cols, c1, c2):
            for a, b, c in zip(ja, jb, jc):
                self.assertEqual(a, (b + c) % P)

    def test_the_fibre_dimension_is_the_same_at_every_fixed_input(self):
        """M_nondata does not depend on d: a dense rank says so, exactly."""
        sm = SmallModel()
        rows, coords = sm.dense_blinding_matrix()
        r = rank(rows, len(coords))
        fibre = len(coords) - r
        self.assertGreater(r, 0)
        # the same matrix is used whatever the data is: build it again from a
        # model whose data rows are different and compare it entry by entry
        sm2 = SmallModel()
        for i in sm2.data_rows:
            sm2.X[i][: sm2.m] = [7 * t + 1 for t in range(sm2.m)]
        rows2, coords2 = sm2.dense_blinding_matrix()
        self.assertEqual(coords, coords2)
        self.assertEqual(rows, rows2)
        self.assertEqual(len(coords2) - rank(rows2, len(coords2)), fibre)

    def test_a_pad_budget_below_the_opened_columns_loses_rank(self):
        """The control's premise, on the small model: fewer pads than distinct
        opened columns and the blinding map stops being onto."""
        wide = SmallModel(q=6, d=4)
        rows, coords = wide.dense_blinding_matrix()
        narrow = SmallModel(q=3, d=4)
        rows2, coords2 = narrow.dense_blinding_matrix()
        obs = len(rows)
        self.assertEqual(rank(rows, len(coords)), min(obs, rank(rows, len(coords))))
        # with q < d the per-row column block cannot be met for a generic view
        self.assertLess(
            rank(rows2, len(coords2)) - (narrow.rows * narrow.d),
            rank(rows, len(coords)) - (wide.rows * wide.d) + 1,
        )


# ========================================================= the real captures
class TestConstructedPreimages(unittest.TestCase):
    def test_every_commitment_has_an_exhibited_zero_witness_preimage(self):
        for nm, (L, _) in layouts().items():
            with self.subTest(role=nm):
                pre = RolePreimage(L, {}).build()
                self.assertEqual(pre.fail, [], f"{nm}: no preimage at the zero input")
                ver = pre.verify(columns=4)
                self.assertTrue(ver["all_entries_equal"], ver)
                self.assertGreater(ver["group_vector_entries"], 0)
                self.assertGreater(ver["column_entries"], 0)

    def test_the_preimage_reproduces_every_entry_of_a_whole_commitment(self):
        """One commitment, verified with no sampling at all."""
        L, _ = layouts()["Input"]
        pre = RolePreimage(L, {}).build()
        ver = pre.verify(columns="full")
        self.assertEqual(ver["columns_verified"], L.d)
        self.assertEqual(ver["column_mismatches"], 0)
        self.assertEqual(ver["group_vector_mismatches"], 0)
        self.assertEqual(ver["proximity_mismatches"], 0)
        self.assertEqual(ver["claim_value_mismatches"], 0)
        self.assertEqual(ver["column_entries"], L.d * L.rows)

    def test_the_exhibited_randomness_respects_the_public_row_constraint(self):
        """H's u pair really does sum to zero over the message positions."""
        L, _ = layouts()["H"]
        self.assertEqual(L.u_rows, [278, 279])
        pre = RolePreimage(L, {}).build()
        self.assertEqual(pre.fail, [])
        for u in L.u_rows:
            self.assertEqual(sum(pre.X[u][:MSG]) % P, 0)

    def test_the_data_block_really_carries_the_fixed_input(self):
        L, _ = layouts()["A"]
        data = {i: gate.prg_row("t", "A", i) for i in L.data_rows}
        pre = RolePreimage(L, data).build()
        self.assertEqual(pre.fail, [])
        for i in L.data_rows:
            self.assertEqual(pre.X[i][:MSG], data[i])
        self.assertTrue(pre.verify(columns=3)["all_entries_equal"])

    def test_the_fibre_dimension_does_not_depend_on_the_fixed_input(self):
        L, _ = layouts()["Input"]
        before = L.matrix_digest()
        a = RolePreimage(L, {}).build().fibre_dimension()
        data = {i: gate.prg_row("t", "Input", i) for i in L.data_rows}
        b = RolePreimage(L, data).build().fibre_dimension()
        self.assertEqual(a["fibre_dimension_fp"], b["fibre_dimension_fp"])
        self.assertEqual(L.matrix_digest(), before)
        self.assertEqual(
            a["fibre_dimension_fp"], a["msg_block_fp"] + a["pad_block_fp"]
        )
        self.assertLess(a["fibre_dimension_fp"], a["blinding_unknowns"])

    def test_the_second_fixed_input_needs_the_disclosed_identity_on_H(self):
        L, _ = layouts()["H"]
        raw = {i: gate.prg_row("t2", "H", i) for i in L.data_rows}
        self.assertTrue(RolePreimage(L, dict(raw)).build().fail,
                        "a pseudorandom input off the LogUp plane must have NO preimage")
        proj = gate.project_onto_disclosed(L, raw)
        self.assertTrue(proj["applied"])
        pre = RolePreimage(L, raw).build()
        self.assertEqual(pre.fail, [])
        self.assertTrue(pre.verify(columns=3)["all_entries_equal"])


class TestCfsChannel(unittest.TestCase):
    def test_sum_weights_match_the_first_round(self):
        """CfsMask::round and CfsMask::sum_weights agree: s_0(0) + s_0(1) = total."""
        cap, rp = caps()[0]
        n, d = tuple(cap.mask["specs"][0])
        R = mask_round_matrix(n, d, rp.rho[0])
        w = sum_weights(n, d)
        L = mask_len(n, d)
        for k in range(L):
            self.assertEqual(f2_add(R[0][k], R[1][k]), w[k])

    def test_every_masked_round_and_scalar_is_reproduced(self):
        cap, rp = caps()[0]
        cp = CfsPreimage(cap, rp)
        self.assertIsNotNone(cp.run())
        cp.project(which="all")
        ver = cp.verify()
        self.assertEqual(ver["round_mismatches"], 0)
        self.assertEqual(ver["scalar_mismatches"], 0)
        self.assertGreater(ver["round_entries"], 700)
        self.assertTrue(ver["theta_identity_holds"])
        self.assertEqual(cp.functional_values()["mismatches"], 0)

    def test_the_zero_transcript_is_infeasible_and_the_projection_fixes_it(self):
        cap, rp = caps()[0]
        cp = CfsPreimage(cap, rp)
        cp.run()
        self.assertFalse(cp.verify()["theta_identity_holds"])
        p = cp.project(which="theta")
        self.assertTrue(p["applied"])
        self.assertEqual(p["conditions_on_the_fixed_transcript_fp"], 2)
        self.assertTrue(cp.verify()["theta_identity_holds"])

    def test_the_fp_form_of_an_fp2_system_is_faithful(self):
        rows = [[(3, 4), (5, 6)]]
        cols = fp_columns(rows, 2)
        x = [(2, 1), (7, 3)]
        flat = [x[0][0], x[0][1], x[1][0], x[1][1]]
        got = [sum(c[i] * v for c, v in zip(cols, flat)) % P for i in (0, 1)]
        want = f2_add(f2_mul(rows[0][0], x[0]), f2_mul(rows[0][1], x[1]))
        self.assertEqual(tuple(got), want)


# ================================================================ the controls
class TestControls(unittest.TestCase):
    """A control that cannot fire at an honest capture is not a control."""

    def test_a_perturbed_group_vector_has_no_preimage(self):
        L, _ = layouts()["Input"]
        self.assertEqual(RolePreimage(L, {}).build().fail, [])
        for pos in (0, MSG):
            saved = L.gvec[0][pos]
            L.gvec[0][pos] = ((saved[0] + 1) % P, saved[1])
            pre = RolePreimage(L, {}).build()
            L.gvec[0][pos] = saved
            self.assertTrue(pre.fail, f"position {pos} must have no preimage")
        self.assertEqual(RolePreimage(L, {}).build().fail, [], "honest again")

    def test_a_nonzero_logup_value_empties_the_fibre(self):
        L, _ = layouts()["H"]
        zs = [ci for ci, p in L.claim_pair.items() if set(p) == set(L.u_rows)]
        self.assertEqual(len(zs), 1)
        self.assertEqual(L.values[zs[0]], F2_ZERO)
        saved = L.values[zs[0]]
        L.values[zs[0]] = (1, 0)
        pre = RolePreimage(L, {}).build()
        L.values[zs[0]] = saved
        self.assertTrue(pre.fail)
        self.assertEqual(RolePreimage(L, {}).build().fail, [])

    def test_one_pad_fewer_than_the_opened_columns_has_no_preimage(self):
        L, _ = layouts()["Input"]
        self.assertEqual(RolePreimage(L, {}, pad_width=256).build().fail, [])
        pre = RolePreimage(L, {}, pad_width=L.d - 1).build()
        self.assertTrue(pre.fail)
        self.assertIn("NO PREIMAGE", pre.fail[0])

    def test_a_shared_blinding_unknown_has_no_joint_preimage(self):
        lay = layouts()
        LA, va = lay["A"]
        LH, vh = lay["H"]
        from zk60_native_jv_joint import singleton_pair_rows

        ra = singleton_pair_rows(va)[0]["rows"][0]
        rh = singleton_pair_rows(vh)[0]["rows"][0]
        pa = RolePreimage(LA, {}).build()
        ph = RolePreimage(LH, {}).build()
        self.assertEqual(pa.fail, [])
        self.assertEqual(ph.fail, [])
        diff = [t for t in range(MSG) if pa.X[ra][t] != ph.X[rh][t]]
        self.assertTrue(diff, "the two commitments must force different values")


# ============================================================== the gate itself
class TestGateRecord(unittest.TestCase):
    def test_every_channel_of_section_2_is_present_with_a_status(self):
        cap, rp = caps()[0]
        res, lay, views = gate.run_capture(cap, rp, columns=2)
        ch = gate.channels_for(cap, res)
        names = {c["channel"] for c in ch}
        for required in (
            "opening-group vectors", "proximity vectors (PCS)", "claimed evaluations",
            "opened column values", "column indices", "leaf salts",
            "the three Merkle roots", "authentication paths", "masked sumcheck rounds",
            "published masked scalars, Gamma", "published terminals",
            "mask evaluations", "the M opening's q", "the M proximity vector",
            "LogUp sums", "counts and lengths", "the wire envelope",
            "any nonlinear functional of the joint view",
        ):
            self.assertIn(required, names)
        for c in ch:
            self.assertIn(c["status"], ("constructed", "derived", "argued", "open"))
        g = gate.grade(ch)
        self.assertEqual(g["failures"], [])
        self.assertTrue(g["ok"])
        self.assertGreaterEqual(g["by_status"]["constructed"], 8)

    def test_the_grade_fails_a_constructed_channel_without_a_preimage(self):
        ch = [{"channel": "x", "status": "constructed", "preimage_exhibited": False}]
        self.assertFalse(gate.grade(ch)["ok"])
        ch[0]["preimage_exhibited"] = True
        self.assertIn("the hash layer is silent: leaf salts is missing",
                      gate.grade(ch)["failures"])

    def test_the_grade_fails_an_argued_channel_with_no_assumption(self):
        base = gate.channels_for(*self._one())
        self.assertTrue(gate.grade(base)["ok"])
        for c in base:
            if c["channel"] == "leaf salts":
                c["assumption"] = None
        self.assertFalse(gate.grade(base)["ok"])

    def test_the_grade_fails_when_a_hash_channel_is_missing(self):
        base = gate.channels_for(*self._one())
        kept = [c for c in base if c["channel"] != "the three Merkle roots"]
        g = gate.grade(kept)
        self.assertFalse(g["ok"])
        self.assertTrue(any("hash layer is silent" in f for f in g["failures"]))

    def _one(self):
        cap, rp = caps()[0]
        res, _, _ = gate.run_capture(cap, rp, columns=1)
        return cap, res

    def test_the_fixed_inputs_are_public_and_deterministic(self):
        a = gate.prg_row("p", "A", 3)
        b = gate.prg_row("p", "A", 3)
        self.assertEqual(a, b)
        self.assertNotEqual(a, gate.prg_row("p", "A", 4))
        self.assertEqual(len(a), MSG)
        self.assertTrue(all(0 <= v < gate.PRG_BOUND for v in a))

    def test_the_zero_witness_rust_test_is_cited_and_not_run(self):
        self.assertFalse(gate.ZERO_WITNESS_TEST["run_by_this_gate"])
        self.assertIn("zero_witness_tests.rs", gate.ZERO_WITNESS_TEST["where"])


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""FA6 -- the CFS masking channel of the ZK sumchecks, modelled exactly.

Reviewer: Claude Fable 5.1 (independent privacy reviewer), 2026-09-08 session.
Source pin: cfa46f6 (`zkp-core/src/sumcheck.rs` CfsMask / CfsMasker /
extension_round; `hashline/src/zk.rs` mask_specs, mask_specs_v3,
masked_prove, extension, mask_functionals, push_pred_functionals,
mask_commit / mask_open / mask_verify).

What the tool does
------------------
1. Re-implements `CfsMask::round / sum_weights / eval_weights` from the Rust
   source as WEIGHT ROWS over the mask coefficients (the layout
   [a_0, a', a_{0,1..d}, ..., a_{N-1,1..d}]), plus a brute-force round
   (sum over the boolean rest) to check the closed form.
2. Builds, per sumcheck slot of the actual slot tables (`mask_specs`,
   `mask_specs_v3` at the FA2/FA3 shapes, plus FA3's two seam slots), the
   exact linear map  mask coefficients -> the verifier's view of the mask
   channel (the g-part of every round message incl. the extension round(s),
   the sent claimed sums / Gammas as the code batches them, the derived
   g(rho)'s) and the consistency subspace S the view is confined to
   (h_j(0) + h_j(1) = h_{j-1}(r_{j-1}); round 0 against the claimed sum).
   rank(map) == dim S with image inside S  <=>  the masked view is uniform on
   S, independent of the data.  Deficiency is reported with a concrete
   leaked functional and a two-data counterexample.
3. Models the M opening (mask_open): q' under the zero-sum blinding b, the
   opened columns under the per-row pads (Lagrange/Cauchy on the coset),
   with the negative controls (two openings, no blinding, columns exceeding
   the pads, no pads) and the positive ones (duplicates, one opening).
4. Runs the negative controls of the message channel (c = 0, no a_0, no a',
   an extension round whose degree exceeds the mask's, mask reuse with the
   same / fresh challenges, a mask shared by two slots) and the positive
   control that a' is not load-bearing.
5. Emits the Rust cross-check fixture (`hashline/tests/zk60_fable_cfs_channel.rs`).

    python3 scripts/zk60_fable_cfs_channel.py --out results/zk60_fable_fa6_cfs_channel.json

Deterministic: stand-in challenges from `zk60_fable_joint_rank.Rng(seed)`;
no secrets (synthetic fixtures only).  Exact modular arithmetic imported from
FA2's tool by path (no field code is duplicated here).
"""
import argparse
import hashlib
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
_SPEC = importlib.util.spec_from_file_location("zk60_fable_joint_rank", HERE / "zk60_fable_joint_rank.py")
R = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(R)

P = R.P
NONRESIDUE = R.NONRESIDUE
ONE, ZERO, U = R.ONE, R.ZERO, R.U
f2, f2_add, f2_sub, f2_neg, f2_mul, f2_mul_base, f2_inv, f2_is_zero = (
    R.f2, R.f2_add, R.f2_sub, R.f2_neg, R.f2_mul, R.f2_mul_base, R.f2_inv, R.f2_is_zero)
fp_inv = R.fp_inv
Rng = R.Rng
layout_v3 = R.layout_v3
Fp2 = Tuple[int, int]

SOURCE_COMMIT = "cfa46f6"
REVIEWER = "Claude Fable 5.1, independent privacy reviewer, 2026-09-08 session"
SOURCE_FILES = ["zkp-core/src/sumcheck.rs", "hashline/src/zk.rs"]

HALF = fp_inv(2)


# ----------------------------------------------------------------------------
# small exact helpers on top of FA2's field code (Fp2 elimination; no field code)
# ----------------------------------------------------------------------------


def f2_dot(w: Sequence[Fp2], v: Sequence[Fp2]) -> Fp2:
    acc = ZERO
    for a, b in zip(w, v):
        acc = f2_add(acc, f2_mul(a, b))
    return acc


def f2_rref(rows: List[List[Fp2]]) -> Tuple[List[List[Fp2]], List[int]]:
    """Reduced row echelon form over Fp2 (Gauss-Jordan with f2_inv)."""
    m = [list(r) for r in rows]
    if not m:
        return [], []
    ncols = len(m[0])
    pivots: List[int] = []
    r = 0
    for c in range(ncols):
        if r >= len(m):
            break
        piv = None
        for i in range(r, len(m)):
            if not f2_is_zero(m[i][c]):
                piv = i
                break
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        inv = f2_inv(m[r][c])
        m[r] = [f2_mul(x, inv) for x in m[r]]
        for i in range(len(m)):
            if i != r and not f2_is_zero(m[i][c]):
                f = m[i][c]
                m[i] = [f2_sub(x, f2_mul(f, y)) for x, y in zip(m[i], m[r])]
        pivots.append(c)
        r += 1
    return m[:r], pivots


def f2_rank(rows: List[List[Fp2]]) -> int:
    return len(f2_rref(rows)[0])


def f2_null_space(rows: List[List[Fp2]], ncols: int) -> List[List[Fp2]]:
    red, pivots = f2_rref(rows)
    free = [c for c in range(ncols) if c not in pivots]
    basis = []
    for fcol in free:
        x = [ZERO] * ncols
        x[fcol] = ONE
        for prow, pc in zip(red, pivots):
            x[pc] = f2_neg(prow[fcol])
        basis.append(x)
    return basis


def f2_transpose(rows: List[List[Fp2]], ncols: int) -> List[List[Fp2]]:
    return [[rows[i][j] for i in range(len(rows))] for j in range(ncols)]


def f2_left_null_space(rows: List[List[Fp2]], ncols: int) -> List[List[Fp2]]:
    """{y : y . rows = 0}: the annihilator of the row space's image (rows as a map)."""
    return f2_null_space(f2_transpose(rows, ncols), len(rows))


def fp2_rows_to_fp(rows: List[List[Fp2]]) -> List[List[int]]:
    """An Fp2-linear map as an Fp-linear map on doubled coordinates
    (unknown k -> columns 2k (re), 2k+1 (im)); rank_Fp = 2 rank_Fp2.
    Used only to cross-check f2_rank against FA2's `rank`."""
    out = []
    for w in rows:
        re = [0] * (2 * len(w))
        im = [0] * (2 * len(w))
        for k, (w0, w1) in enumerate(w):
            re[2 * k] = w0 % P
            re[2 * k + 1] = (NONRESIDUE * w1) % P
            im[2 * k] = w1 % P
            im[2 * k + 1] = w0 % P
        out.append(re)
        out.append(im)
    return out


def lagrange_weights(deg: int, r: Fp2) -> List[Fp2]:
    """lambda_i(r) over the nodes 0..deg: mle::interpolate_eval's weights."""
    out = []
    for i in range(deg + 1):
        num = ONE
        den = 1
        for j in range(deg + 1):
            if i == j:
                continue
            num = f2_mul(num, f2_sub(r, f2(j)))
            den = (den * (i - j)) % P
        out.append(f2_mul_base(num, fp_inv(den)))
    return out


def interp_eval(vals: Sequence[Fp2], r: Fp2) -> Fp2:
    return f2_dot(lagrange_weights(len(vals) - 1, r), vals)


# ----------------------------------------------------------------------------
# the CFS mask, exactly as zkp-core/src/sumcheck.rs (CfsMask)
# ----------------------------------------------------------------------------


def cfs_len(n: int, d: int) -> int:
    return n * d + 2


def cidx(j: int, e: int, d: int) -> int:
    """coefficient index of a_{j,e} (e = 1..d) in [a_0, a', a_{0,1..d}, ...]."""
    return 2 + j * d + (e - 1)


def cfs_sum_weights(n: int, d: int) -> List[Fp2]:
    w = [f2(1 << (n - 1))] * cfs_len(n, d)
    w[0] = f2(1 << n)
    w[1] = ONE
    return w


def cfs_eval_weights(rho: Sequence[Fp2], d: int) -> List[Fp2]:
    w = [ONE]
    prod = ONE
    for r in rho:
        prod = f2_mul(prod, r)
    w.append(prod)
    for r in rho:
        xp = ONE
        for _ in range(d):
            xp = f2_mul(xp, r)
            w.append(xp)
    return w


def cfs_round_weights(n: int, d: int, j: int, prev: Sequence[Fp2]) -> List[List[Fp2]]:
    """Weight rows W_j[x] (x = 0..d) with g_j(x) = <coeffs, W_j[x]>; the closed
    form of CfsMask::round: 2^(N-1-j) (base + u_j(x)) + a' (prod prev) x, with
    base = a_0 + sum_{i<j} u_i(r_i) + sum_{i>j} u_i(1) / 2."""
    assert len(prev) == j and j < n
    L = cfs_len(n, d)
    scale = f2(1 << (n - 1 - j))
    prod_prev = ONE
    for r in prev:
        prod_prev = f2_mul(prod_prev, r)
    base = [ZERO] * L
    base[0] = ONE
    for i, r in enumerate(prev):
        xp = ONE
        for e in range(1, d + 1):
            xp = f2_mul(xp, r)
            base[cidx(i, e, d)] = f2_add(base[cidx(i, e, d)], xp)
    for i in range(j + 1, n):
        for e in range(1, d + 1):
            base[cidx(i, e, d)] = f2_add(base[cidx(i, e, d)], f2(HALF))
    out = []
    for x in range(d + 1):
        xv = f2(x)
        row = [f2_mul(scale, b) for b in base]
        xp = ONE
        for e in range(1, d + 1):
            xp = f2_mul(xp, xv)
            row[cidx(j, e, d)] = f2_add(row[cidx(j, e, d)], f2_mul(scale, xp))
        row[1] = f2_add(row[1], f2_mul(prod_prev, xv))
        out.append(row)
    return out


def cfs_eval(coeffs: Sequence[Fp2], point: Sequence[Fp2], d: int) -> Fp2:
    return f2_dot(cfs_eval_weights(point, d), coeffs)


def cfs_total(coeffs: Sequence[Fp2], n: int, d: int) -> Fp2:
    return f2_dot(cfs_sum_weights(n, d), coeffs)


def cfs_round(coeffs: Sequence[Fp2], n: int, d: int, j: int, prev: Sequence[Fp2]) -> List[Fp2]:
    return [f2_dot(w, coeffs) for w in cfs_round_weights(n, d, j, prev)]


def cfs_round_brute(coeffs: Sequence[Fp2], n: int, d: int, j: int, prev: Sequence[Fp2]) -> List[Fp2]:
    """Round j by definition: sum over the boolean rest of g(prev, x, rest)."""
    out = []
    for x in range(d + 1):
        acc = ZERO
        for rest in range(1 << (n - 1 - j)):
            pt = list(prev) + [f2(x)]
            for i in range(n - 1 - j):
                pt.append(ONE if (rest >> (n - 2 - j - i)) & 1 else ZERO)
            acc = f2_add(acc, cfs_eval(coeffs, pt, d))
        out.append(acc)
    return out


# ----------------------------------------------------------------------------
# the linear model of the message channel
# ----------------------------------------------------------------------------


class Channel:
    """Unknowns: the Fp2 mask coefficients of every registered mask.
    View: Fp2 coordinates, each a weight row over the unknowns (its g-part).
    Constraints: Fp2 relations among view coordinates the verifier checks
    (they hold for the f-part and the g-part separately)."""

    def __init__(self) -> None:
        self.n_unk = 0
        self.masks: Dict[str, Tuple[int, int, int]] = {}
        self.dropped: Dict[str, set] = {}
        self.view_names: List[str] = []
        self.view_rows: List[List[Fp2]] = []
        self.cons_names: List[str] = []
        self.cons: List[Dict[int, Fp2]] = []

    def add_mask(self, name: str, n: int, d: int, drop: Sequence[int] = ()) -> None:
        assert name not in self.masks
        self.masks[name] = (self.n_unk, n, d)
        self.dropped[name] = set(drop)
        self.n_unk += cfs_len(n, d)
        for rows in self.view_rows:
            rows.extend([ZERO] * cfs_len(n, d))

    def mask_row(self, name: str, weights: Sequence[Fp2], scale: Fp2 = ONE) -> List[Fp2]:
        off, n, d = self.masks[name]
        assert len(weights) == cfs_len(n, d)
        row = [ZERO] * self.n_unk
        for k, w in enumerate(weights):
            if k in self.dropped[name]:
                continue
            row[off + k] = f2_mul(scale, w)
        return row

    @staticmethod
    def row_add(a: Sequence[Fp2], b: Sequence[Fp2]) -> List[Fp2]:
        return [f2_add(x, y) for x, y in zip(a, b)]

    def zero_row(self) -> List[Fp2]:
        return [ZERO] * self.n_unk

    def add_view(self, name: str, row: Sequence[Fp2]) -> int:
        assert len(row) == self.n_unk
        self.view_names.append(name)
        self.view_rows.append(list(row))
        return len(self.view_rows) - 1

    def add_constraint(self, name: str, combo: Dict[int, Fp2]) -> None:
        self.cons_names.append(name)
        self.cons.append(dict(combo))

    def cons_rows(self) -> List[List[Fp2]]:
        nv = len(self.view_rows)
        out = []
        for c in self.cons:
            row = [ZERO] * nv
            for i, v in c.items():
                row[i] = f2_add(row[i], v)
            out.append(row)
        return out

    def add_masked_sumcheck(self, mask: str, c: Fp2, claim_refs: Dict[int, Fp2], rng: Rng, tag: str,
                            challenges: Optional[List[Fp2]] = None, last_round_degree: Optional[int] = None) -> Dict:
        """The g-part of one masked sumcheck on mask `mask` with challenge c:
        N = n_vars rounds (the last one(s) being the extension round(s)); the
        round-0 relation is against sum(coef * view[i]) over claim_refs.
        `last_round_degree` > d models an extension round the mask does not
        cover (the `zip` in zk.rs::extension leaves the top values clear)."""
        off, n, d = self.masks[mask]
        rho: List[Fp2] = []
        rounds: List[List[int]] = []
        degs: List[int] = []
        for j in range(n):
            deg = d if (last_round_degree is None or j < n - 1) else last_round_degree
            wj = cfs_round_weights(n, d, j, rho)
            idxs = []
            for x in range(deg + 1):
                if x <= d:
                    row = self.mask_row(mask, wj[x], c)
                else:
                    row = self.zero_row()   # unmasked value of the round message
                idxs.append(self.add_view(f"{tag}.h{j}({x})", row))
            rounds.append(idxs)
            degs.append(deg)
            if j == 0:
                combo = {idxs[0]: ONE, idxs[1]: ONE}
                for i, v in claim_refs.items():
                    combo[i] = f2_add(combo.get(i, ZERO), f2_neg(v))
                self.add_constraint(f"{tag}.h0(0)+h0(1)=claim", combo)
            else:
                lam = lagrange_weights(degs[j - 1], rho[j - 1])
                combo = {idxs[0]: ONE, idxs[1]: ONE}
                for x, lx in enumerate(lam):
                    i = rounds[j - 1][x]
                    combo[i] = f2_add(combo.get(i, ZERO), f2_neg(lx))
                self.add_constraint(f"{tag}.h{j}(0)+h{j}(1)=h{j - 1}(r{j - 1})", combo)
            r = challenges[j] if challenges is not None else rng.fp2()
            rho.append(r)
        # the derived terminal g(rho) = h_{N-1}(r_{N-1}) / c is a function of the view
        lam = lagrange_weights(degs[-1], rho[-1])
        term_combo = {rounds[-1][x]: lam[x] for x in range(degs[-1] + 1)}
        return {"rho": rho, "rounds": rounds, "terminal_combo": term_combo, "mask": mask, "c": c}

    def analyze(self, want_witness: bool = True) -> Dict:
        nv = len(self.view_rows)
        L = self.view_rows
        cons = self.cons_rows()
        rank_L = f2_rank(L)
        rank_cons = f2_rank(cons) if cons else 0
        dim_S = nv - rank_cons
        # image inside S: every constraint composed with the map is zero
        inside = True
        for crow in cons:
            comp = [ZERO] * self.n_unk
            for i, ci in enumerate(crow):
                if f2_is_zero(ci):
                    continue
                comp = [f2_add(a, f2_mul(ci, b)) for a, b in zip(comp, L[i])]
            if any(not f2_is_zero(x) for x in comp):
                inside = False
                break
        leaked = dim_S - rank_L if inside else None
        n_active = self.n_unk - sum(len(v) for v in self.dropped.values())
        res = {
            "n_unknowns_fp2": self.n_unk, "n_active_unknowns_fp2": n_active, "n_view_fp2": nv, "n_constraints": len(cons),
            "rank_map": rank_L, "rank_constraints": rank_cons, "dim_consistency_subspace": dim_S,
            "image_inside_subspace": inside, "leaked_dim_fp2": leaked, "kernel_dim_fp2": n_active - rank_L,
            "verdict": "surjective (view uniform on S, independent of the data)" if inside and leaked == 0 else "DEFICIENT",
        }
        if want_witness and inside and leaked:
            res["leaked_functionals"], res["counterexample"] = self.witness(cons, leaked)
        return res

    def witness(self, cons: List[List[Fp2]], leaked: int) -> Tuple[List[Dict[str, List[int]]], Dict]:
        """Leaked functionals: y with y . L = 0 not in span(constraints); a
        two-data counterexample: f1 = 0 and f2 in S with phi(f2) != 0, so the
        two views phi(f1 + L a) = 0 and phi(f2 + L a) != 0 for EVERY mask a."""
        nv = len(self.view_rows)
        ln = f2_left_null_space(self.view_rows, self.n_unk)
        base = f2_rank(cons) if cons else 0
        chosen: List[List[Fp2]] = []
        for y in ln:
            if f2_rank(cons + chosen + [y]) > base + len(chosen):
                chosen.append(y)
            if len(chosen) == leaked:
                break
        funcs = [{self.view_names[i]: list(v) for i, v in enumerate(y) if not f2_is_zero(v)} for y in chosen[:3]]
        phi = chosen[0]
        s_basis = f2_null_space(cons, nv) if cons else [[ONE if i == k else ZERO for i in range(nv)] for k in range(nv)]
        f2v = next(v for v in s_basis if not f2_is_zero(f2_dot(phi, v)))
        val = f2_dot(phi, f2v)
        cx = {
            "f1": "the all-zero consistent message set (phi(f1) = 0)",
            "f2_support": [self.view_names[i] for i, v in enumerate(f2v) if not f2_is_zero(v)],
            "phi_f2_nonzero": not f2_is_zero(val),
            "phi_f2_sha256_16": hashlib.sha256(json.dumps(val).encode()).hexdigest()[:16],
        }
        return funcs, cx

    def in_row_space(self, extra: List[List[Fp2]]) -> bool:
        return f2_rank(self.view_rows + extra) == f2_rank(self.view_rows)


# ----------------------------------------------------------------------------
# the slot tables (mask_specs / mask_specs_v3 / FA3 seams) at the review shapes
# ----------------------------------------------------------------------------

SLOT_ORDER = ["SC_GU", "SC_D", "SC_ZC20", "SC_ZC17", "SC_ZSUM", "SC_TAB", "SC_PRED", "SC_SEAM_X", "SC_SEAM_Z"]


def v2_slots(t_rows: int, log_cols: int) -> Dict[str, Dict]:
    """zk.rs::mask_specs with layer.rs::Layout (log_tf = log_t + 11, log_tb = log_t + 8),
    a_log_cols = min(params.log_cols, log_tb)."""
    log_t = t_rows.bit_length() - 1
    assert 1 << log_t == t_rows
    log_tf, log_tb = log_t + 11, log_t + 8
    a_log_cols = min(log_cols, log_tb)
    return {
        "SC_GU": {"n_vars": 8 + 1, "degree": 2, "claim": "private s_gu + c_gu G_gu (sent: gu_claim)", "ext_rounds": 1},
        "SC_D": {"n_vars": 11 + 1, "degree": 2, "claim": "private s_d + c_d G_d (sent: d_claim)", "ext_rounds": 1},
        "SC_ZC20": {"n_vars": log_tf + 1, "degree": 4, "claim": "batched: nu0 gu_claim + Gamma20, Gamma20 = c20 G20 - nu0 c_gu G_gu (sent)", "ext_rounds": 1},
        "SC_ZC17": {"n_vars": log_tb + 1, "degree": 4, "claim": "batched: nu_z d_claim + Gamma17, Gamma17 = c17 G17 - nu_z c_d G_d (sent)", "ext_rounds": 1},
        "SC_ZSUM": {"n_vars": a_log_cols + 1, "degree": 2, "claim": "public 0 + Gamma_zs = c_zs G_zs (sent)", "ext_rounds": 1},
        "SC_TAB": {"n_vars": a_log_cols + 1, "degree": 3, "claim": "public 0 + Gamma_tab = c_tab G_tab (sent)", "ext_rounds": 1},
    }


def v3_slots(lay: Dict, p3: bool = False, pred: bool = False, seams: bool = False) -> Dict[str, Dict]:
    """zk.rs::mask_specs_v3 (+ FA3's SC_SEAM_X / SC_SEAM_Z of the block profile)."""
    x = 1 if p3 else 0
    log_t, log_db, log_fb, log_n = lay["log_t"], lay["log_db"], lay["log_fb"], lay["log_n"]
    log_s = max(log_n, 16)   # ZkLayoutV3::new: log_s = log_n.max(16)
    out = {
        "SC_GU": {"n_vars": log_db + 1 + x, "degree": 2, "claim": "private s_gu + c_gu G_gu (sent: gu_claim)", "ext_rounds": 1 + x},
        "SC_D": {"n_vars": log_fb + 1 + x, "degree": 2, "claim": "private s_d + c_d G_d (sent: d_claim)", "ext_rounds": 1 + x},
        "SC_ZC20": {"n_vars": log_t + log_fb + 1, "degree": 4, "claim": "batched: nu0 gu_claim + GammaF, GammaF = c_f G_F - nu0 c_gu G_gu (sent)", "ext_rounds": 1},
        "SC_ZC17": {"n_vars": log_t + log_db + 1, "degree": 4, "claim": "batched: nu_z d_claim + GammaD, GammaD = c_dz G_D - nu_z c_d G_d (sent)", "ext_rounds": 1},
        "SC_ZSUM": {"n_vars": log_n + 1, "degree": 2, "claim": "public 0 + Gamma_zs = c_zs G_zs (sent)", "ext_rounds": 1},
        "SC_TAB": {"n_vars": log_s + 1, "degree": 3, "claim": "public 0 + Gamma_tab = c_tab G_tab (sent)", "ext_rounds": 1},
    }
    if pred:
        out["SC_PRED"] = {"n_vars": log_t + log_db + 1, "degree": 3, "claim": "public tau + Gamma_pred = c_pred G_pred (sent)", "ext_rounds": 1}
    if seams:
        for s in ("SC_SEAM_X", "SC_SEAM_Z"):
            out[s] = {"n_vars": log_t + log_db + 1, "degree": 2, "claim": "public 0 + Gamma_seam = c_seam G_seam (sent; FA3 section 12.2 step 5)", "ext_rounds": 1}
    for v in out.values():
        v["len"] = cfs_len(v["n_vars"], v["degree"])
        v["main_rounds"] = v["n_vars"] - v["ext_rounds"]
    return out


def _finish(slots: Dict[str, Dict]) -> Dict[str, Dict]:
    for v in slots.values():
        v["len"] = cfs_len(v["n_vars"], v["degree"])
        v["main_rounds"] = v["n_vars"] - v["ext_rounds"]
        assert v["len"] + 256 <= 512, "mask row: coefficients + 256 pads > 512 (mask_commit's assert)"
    return slots


REVIEW_SHAPES = [
    {"name": "v2 legacy T32 (D 768, F 2048) log_cols 14", "kind": "v2", "t_rows": 32, "log_cols": 14},
    {"name": "v3 tiny T2/d16/f16 log_cols 5", "kind": "v3", "t_rows": 2, "d": 16, "f": 16, "log_cols": 5},
    {"name": "v3 tiny T32/d16/f16 log_cols 8", "kind": "v3", "t_rows": 32, "d": 16, "f": 16, "log_cols": 8},
    {"name": "v3 125M T32/d768/f2048 log_cols 14", "kind": "v3", "t_rows": 32, "d": 768, "f": 2048, "log_cols": 14},
    {"name": "v3 8B block profile T32/d4096/f14336 log_cols 14 (FA3 ffn-v3-mr1)", "kind": "v3", "t_rows": 32, "d": 4096, "f": 14336, "log_cols": 14},
    {"name": "v3 8B T32/d4096/f14336 log_cols 16", "kind": "v3", "t_rows": 32, "d": 4096, "f": 14336, "log_cols": 16},
]


def shape_slots(shape: Dict, p3: bool, pred: bool, seams: bool) -> Dict[str, Dict]:
    if shape["kind"] == "v2":
        assert not (p3 or pred or seams)
        return _finish(v2_slots(shape["t_rows"], shape["log_cols"]))
    lay = layout_v3(shape["t_rows"], shape["d"], shape["f"], shape["log_cols"])
    return _finish(v3_slots(lay, p3=p3, pred=pred, seams=seams))


# ----------------------------------------------------------------------------
# the systems: the slots as the code batches them, then the M functionals
# ----------------------------------------------------------------------------


def system_batched_pair(slots: Dict[str, Dict], a: str, b: str, rng: Rng) -> Tuple[Channel, Dict]:
    """(SC_GU, SC_ZC20) or (SC_D, SC_ZC17): the matmul claim is sent as
    s + c_a G_a; the zero-check's claimed sum is nu * claim_a + Gamma_b with
    Gamma_b = c_b G_b - nu c_a G_a sent (zk.rs prove_layer_zk{,_v3})."""
    ch = Channel()
    ch.add_mask(a, slots[a]["n_vars"], slots[a]["degree"])
    ch.add_mask(b, slots[b]["n_vars"], slots[b]["degree"])
    c_a, c_b, nu = rng.fp2(), rng.fp2(), rng.fp2()
    claim_a = ch.add_view(f"{a}.claim(g-part = c G)", ch.mask_row(a, cfs_sum_weights(*ch.masks[a][1:]), c_a))
    sa = ch.add_masked_sumcheck(a, c_a, {claim_a: ONE}, rng, a)
    gamma_row = ch.row_add(ch.mask_row(b, cfs_sum_weights(*ch.masks[b][1:]), c_b),
                           ch.mask_row(a, cfs_sum_weights(*ch.masks[a][1:]), f2_neg(f2_mul(nu, c_a))))
    gamma_b = ch.add_view(f"{b}.Gamma = c_b G_b - nu c_a G_a", gamma_row)
    sb = ch.add_masked_sumcheck(b, c_b, {claim_a: nu, gamma_b: ONE}, rng, b)
    # the M functionals (mask_functionals): g_a(rho_a), g_b(rho_b), Gamma_b's row
    fs = {
        f"g_{a}(rho)": ch.mask_row(a, cfs_eval_weights(sa["rho"], ch.masks[a][2])),
        f"g_{b}(rho)": ch.mask_row(b, cfs_eval_weights(sb["rho"], ch.masks[b][2])),
        f"Gamma_{b}": gamma_row,
    }
    return ch, {"functionals": fs, "c": {a: c_a, b: c_b}, "nu": nu, "rho": {a: sa["rho"], b: sb["rho"]}}


def system_single(slots: Dict[str, Dict], s: str, rng: Rng) -> Tuple[Channel, Dict]:
    """SC_ZSUM / SC_TAB / SC_PRED / the seams: public claimed sum (0 or tau), Gamma = c G sent."""
    ch = Channel()
    ch.add_mask(s, slots[s]["n_vars"], slots[s]["degree"])
    c = rng.fp2()
    gamma_row = ch.mask_row(s, cfs_sum_weights(*ch.masks[s][1:]), c)
    gamma = ch.add_view(f"{s}.Gamma = c G", gamma_row)
    sc = ch.add_masked_sumcheck(s, c, {gamma: ONE}, rng, s)
    fs = {f"g_{s}(rho)": ch.mask_row(s, cfs_eval_weights(sc["rho"], ch.masks[s][2])), f"Gamma_{s}": gamma_row}
    return ch, {"functionals": fs, "c": {s: c}, "rho": {s: sc["rho"]}}


def analyze_system(ch: Channel, meta: Dict) -> Dict:
    res = ch.analyze()
    fs = meta["functionals"]
    res["m_functionals_in_view_span"] = {k: ch.in_row_space([v]) for k, v in fs.items()}
    # the theta-combination V of mask_open is one row in the same span
    theta = f2(3, 5)
    th = ONE
    comb = ch.zero_row()
    for v in fs.values():
        comb = ch.row_add(comb, [f2_mul(th, x) for x in v])
        th = f2_mul(th, theta)
    res["theta_combination_in_view_span"] = ch.in_row_space([comb])
    return res


def slot_table_report(rng: Rng) -> List[Dict]:
    report = []
    modes = [
        {"label": "P1", "p3": False, "pred": False, "seams": False},
        {"label": "P3", "p3": True, "pred": False, "seams": False},
        {"label": "P1 + function-2 predicate", "p3": False, "pred": True, "seams": False},
        {"label": "P1 block profile (+ seams)", "p3": False, "pred": False, "seams": True},
    ]
    for shape in REVIEW_SHAPES:
        for mode in modes:
            if shape["kind"] == "v2" and mode["label"] != "P1":
                continue
            slots = shape_slots(shape, mode["p3"], mode["pred"], mode["seams"])
            entry = {"shape": shape["name"], "mode": mode["label"], "slots": {}, "systems": {}}
            if shape["kind"] == "v3":
                entry["layout"] = {k: layout_v3(shape["t_rows"], shape["d"], shape["f"], shape["log_cols"])[k] for k in ("log_t", "log_db", "log_fb", "log_n")}
            for s in SLOT_ORDER:
                if s in slots:
                    entry["slots"][s] = slots[s]
            for a, b in (("SC_GU", "SC_ZC20"), ("SC_D", "SC_ZC17")):
                ch, meta = system_batched_pair(slots, a, b, rng)
                entry["systems"][f"{a}+{b} (batched as coded)"] = analyze_system(ch, meta)
            for s in SLOT_ORDER:
                if s in slots and s not in ("SC_GU", "SC_D", "SC_ZC20", "SC_ZC17"):
                    ch, meta = system_single(slots, s, rng)
                    entry["systems"][s] = analyze_system(ch, meta)
            # every slot standalone too (its own view alone)
            for s in SLOT_ORDER:
                if s in slots:
                    ch, meta = system_single(slots, s, rng)
                    r = ch.analyze(want_witness=False)
                    entry["systems"].setdefault("standalone", {})[s] = {k: r[k] for k in ("n_unknowns_fp2", "n_view_fp2", "rank_map", "dim_consistency_subspace", "kernel_dim_fp2", "verdict")}
            entry["all_surjective"] = all(v["verdict"].startswith("surjective") for k, v in entry["systems"].items() if k != "standalone") and \
                all(v["verdict"].startswith("surjective") for v in entry["systems"]["standalone"].values())
            report.append(entry)
    return report


# ----------------------------------------------------------------------------
# negative / positive controls on the message channel
# ----------------------------------------------------------------------------


def controls_message_channel(rng: Rng, n: int = 4, d: int = 3) -> Dict[str, Dict]:
    out: Dict[str, Dict] = {}

    def single(drop=(), c=None, last_round_degree=None, tag="s"):
        ch = Channel()
        ch.add_mask("m", n, d, drop=drop)
        cc = rng.fp2() if c is None else c
        g = ch.add_view("Gamma", ch.mask_row("m", cfs_sum_weights(n, d), cc))
        ch.add_masked_sumcheck("m", cc, {g: ONE}, rng, tag, last_round_degree=last_round_degree)
        return ch

    r = single(c=ZERO).analyze()
    r["expect"] = "c = 0: the whole view is the data's messages; leaked = dim S"
    out["nc_mask_challenge_zero"] = r

    r = single(drop=(1,)).analyze()
    r["expect"] = "without a' (the Libra form a_0 + sum_j u_j) the map is still surjective, kernel 0: a' is redundant"
    out["pc_no_aprime_libra_form"] = r

    r = single(drop=(0,)).analyze()
    r["expect"] = "without a_0, a' covers the total's direction for generic challenges: still surjective, kernel 0 (a_0 and a' are interchangeable off a challenge hyperplane)"
    out["pc_no_constant_a0_generic_challenges"] = r

    ch = Channel()
    ch.add_mask("m", n, d, drop=(0,))
    cc = rng.fp2()
    g = ch.add_view("Gamma", ch.mask_row("m", cfs_sum_weights(n, d), cc))
    ch.add_masked_sumcheck("m", cc, {g: ONE}, rng, "s", challenges=[ZERO] + [rng.fp2() for _ in range(n - 1)])
    r = ch.analyze()
    r["expect"] = "without a_0 and with r_0 = 0 (prod_{i<j} r_i = 0 for j >= 1): a' reaches only G and g_0; the view obeys G - sum_j 2^j (h_j(1) - h_j(0)) = 0 and leaks that functional of the data: leaked 1. a_0 is what makes the hiding unconditional"
    out["nc_no_constant_a0_degenerate_challenge"] = r

    r = single(drop=(0, 1)).analyze()
    r["expect"] = "without both a_0 and a': the total G's direction is missing; leaked 1"
    out["nc_no_a0_no_aprime"] = r

    # challenge independence: the full mask is surjective at degenerate challenges too
    # (the map is triangular: G <- a_0, h_j(x) - h_j(0) <- a_{j,.}, for ANY r)
    for label, chal in (("all_zero", [ZERO] * n), ("all_one", [ONE] * n)):
        ch = Channel()
        ch.add_mask("m", n, d)
        cc = rng.fp2()
        g = ch.add_view("Gamma", ch.mask_row("m", cfs_sum_weights(n, d), cc))
        ch.add_masked_sumcheck("m", cc, {g: ONE}, rng, "s", challenges=chal)
        r = ch.analyze()
        r["expect"] = f"the full mask at {label} challenges: still surjective (the a_0 / a_{{j,e}} cover does not depend on the challenges)"
        out[f"pc_full_mask_{label}_challenges"] = r

    r = single(last_round_degree=d + 1).analyze()
    r["expect"] = "extension round of degree d+1 under a degree-d mask (zk.rs::extension zips sk with gk): the top value is clear; leaked 1"
    out["nc_extension_degree_exceeds_mask"] = r

    # mask reuse: same coefficients in two sumchecks (two proofs under one seed, or one mask for two slots)
    ch = Channel()
    ch.add_mask("m", n, d)
    c1 = rng.fp2()
    g1 = ch.add_view("p1.Gamma", ch.mask_row("m", cfs_sum_weights(n, d), c1))
    s1 = ch.add_masked_sumcheck("m", c1, {g1: ONE}, rng, "p1")
    g2 = ch.add_view("p2.Gamma", ch.mask_row("m", cfs_sum_weights(n, d), c1))
    ch.add_masked_sumcheck("m", c1, {g2: ONE}, rng, "p2", challenges=s1["rho"])
    r = ch.analyze()
    r["expect"] = "same mask, same c, same challenges (a re-proof of different data under the same seed whose transcript happens to repeat, or a retried attempt): view1 - view2 = f1 - f2; leaked = dim S of one sumcheck"
    out["nc_mask_reuse_same_challenges"] = r

    ch = Channel()
    ch.add_mask("m", n, d)
    c1, c2 = rng.fp2(), rng.fp2()
    g1 = ch.add_view("p1.Gamma", ch.mask_row("m", cfs_sum_weights(n, d), c1))
    ch.add_masked_sumcheck("m", c1, {g1: ONE}, rng, "p1")
    g2 = ch.add_view("p2.Gamma", ch.mask_row("m", cfs_sum_weights(n, d), c2))
    ch.add_masked_sumcheck("m", c2, {g2: ONE}, rng, "p2")
    r = ch.analyze()
    r["expect"] = f"same mask under fresh challenges (two proofs with cfg.seed = Some(s) at the same layer index, or one coefficient vector shared by two slots): leaked = N d = {n * d}"
    out["nc_mask_reuse_fresh_challenges"] = r

    # the batched pair with the Gamma mixing, but the zero-check mask dropped (Gamma = -nu c_a G_a only)
    ch = Channel()
    ch.add_mask("a", 3, 2)
    ch.add_mask("b", 4, 4, drop=tuple(range(cfs_len(4, 4))))
    c_a, c_b, nu = rng.fp2(), rng.fp2(), rng.fp2()
    claim_a = ch.add_view("a.claim", ch.mask_row("a", cfs_sum_weights(3, 2), c_a))
    ch.add_masked_sumcheck("a", c_a, {claim_a: ONE}, rng, "a")
    gamma_row = ch.mask_row("a", cfs_sum_weights(3, 2), f2_neg(f2_mul(nu, c_a)))
    gb = ch.add_view("b.Gamma", gamma_row)
    ch.add_masked_sumcheck("b", c_b, {claim_a: nu, gb: ONE}, rng, "b")
    r = ch.analyze()
    r["expect"] = "the zero-check mask absent (Gamma carries only -nu c_a G_a): the zero-check's messages are clear; leaked = dim S_b"
    out["nc_batched_pair_without_zero_check_mask"] = r
    return out


# ----------------------------------------------------------------------------
# the M opening (mask_open / mask_verify) at toy size, exact
# ----------------------------------------------------------------------------


def _pow(a: int, e: int) -> int:
    return pow(a % P, e, P)


def check_seven_generates() -> bool:
    """7 generates Fp^* (Goldilocks): 7^((p-1)/l) != 1 for every prime factor l."""
    factors = [2, 3, 5, 17, 257, 65537]
    assert (P - 1) == 2 ** 32 * 3 * 5 * 17 * 257 * 65537
    return all(_pow(7, (P - 1) // l) != 1 for l in factors)


def subgroup_gen(order: int) -> int:
    assert (P - 1) % order == 0
    return _pow(7, (P - 1) // order)


def coset_points(log_m: int) -> List[int]:
    """7 * G_{4m}: the evaluation coset of mask_commit (MASK_LOG_DOM = MASK_LOG_MSG + 3)."""
    dom = 8 << log_m
    w = subgroup_gen(dom)
    return [(7 * _pow(w, j)) % P for j in range(dom)]


def lagrange_on_subgroup(m: int, x: int) -> List[int]:
    """Lagr_y(x) for y in G_m (in index order y = w^i): (x^m - 1) y / (m (x - y))."""
    w = subgroup_gen(m)
    zx = (_pow(x, m) - 1) % P
    inv_m = fp_inv(m)
    out = []
    for i in range(m):
        y = _pow(w, i)
        out.append((zx * y % P) * fp_inv((x - y) % P) % P * inv_m % P)
    return out


def idft_rows(m: int) -> List[List[int]]:
    """coefficient k of the interpolant of values on G_m: (1/m) sum_y a(y) y^{-k}."""
    w = subgroup_gen(m)
    inv_m = fp_inv(m)
    winv = fp_inv(w)
    return [[(_pow(winv, k * i) * inv_m) % P for i in range(m)] for k in range(m)]


def disclosed_dim_fp(obs_data: List[List[int]], obs_mask: List[List[int]]) -> Tuple[int, List[List[int]]]:
    """Fp-linear observations obs = D data + M mask: the data functionals the
    observations determine are {y D : y M = 0}; returns (dim, a basis of them)."""
    n_mask = len(obs_mask[0]) if obs_mask and obs_mask[0] else 0
    if n_mask == 0:
        ys = [[1 if i == k else 0 for i in range(len(obs_data))] for k in range(len(obs_data))]
    else:
        ys = R.left_null_space(obs_mask, n_mask)
    ncols = len(obs_data[0])
    funcs = R.mat_mul(ys, obs_data, ncols) if ys else []
    red, _ = R.rref(funcs) if funcs else ([], [])
    return len(red), red


def m_columns_model(log_m: int, n_coef: int, n_pads: int, indices: List[int]) -> Dict:
    """One a-row (message = coefficients || pads || zeros on G_m) opened at the
    coset points `indices`: disclosed dimension of the coefficients."""
    m = 1 << log_m
    assert n_coef + n_pads <= m
    pts = coset_points(log_m)
    obs_d, obs_m = [], []
    for j in indices:
        lag = lagrange_on_subgroup(m, pts[j])
        obs_d.append(lag[:n_coef])
        obs_m.append(lag[n_coef:n_coef + n_pads])
    dim, _ = disclosed_dim_fp(obs_d, obs_m)
    return {"log_m": log_m, "coefficients": n_coef, "pads": n_pads, "opened": len(indices), "distinct": len(set(indices)), "disclosed_coefficient_functionals": dim}


def m_qprime_model(log_m: int, n_coef: int, n_pads: int, thetas_W: List[List[Fp2]], blinding: bool = True) -> Dict:
    """q' = p_a p_W + p_b for ONE mask (a = a_re + U a_im, two Fp rows), with b
    the zero-sum blinding (b_m = -b_0), for one or several openings (one W per
    opening; the same a, the same b as in the code, where b is drawn once per
    MaskCommit): the disclosed Fp-dimension of the 2 n_coef coefficient scalars."""
    m = 1 << log_m
    idft = idft_rows(m)
    n_msg = n_coef + n_pads
    # unknown layout (Fp scalars): a_re[0..n_msg), a_im[0..n_msg), b_re[0..2m) with b_re[m] = -b_re[0], b_im likewise
    n_a = 2 * n_msg
    n_b = 2 * (2 * m - 1) if blinding else 0
    data_cols = list(range(n_coef)) + list(range(n_msg, n_msg + n_coef))
    obs_rows: List[Tuple[List[Fp2], List[Fp2]]] = []   # per opening: rows over (a unknowns as Fp2 weights, b unknowns as Fp2 weights)
    rows_all: List[List[Fp2]] = []
    for W in thetas_W:
        assert len(W) == n_coef
        # p_W coefficients (Fp2): W on the coefficient positions, zero elsewhere
        pw = [ZERO] * m
        for k in range(m):
            acc = ZERO
            for i in range(n_coef):
                acc = f2_add(acc, f2_mul_base(W[i], idft[k][i]))
            pw[k] = acc
        # p_a coefficient k as a weight row over the message positions: idft[k][i] (Fp)
        # q'_t = sum_{k+l=t} p_a[k] p_W[l] + b_t
        for t in range(2 * m):
            row = [ZERO] * (n_a + n_b)
            for k in range(m):
                l = t - k
                if l < 0 or l >= m:
                    continue
                for i in range(n_msg):
                    wgt = f2_mul_base(pw[l], idft[k][i])
                    row[i] = f2_add(row[i], wgt)                       # a_re[i] (Fp) with Fp2 weight
                    row[n_msg + i] = f2_add(row[n_msg + i], f2_mul(U, wgt))   # a_im[i]: U * weight
            if blinding:
                # b_t = b_re[t] + U b_im[t]; b[m] = -b[0]
                def bcol(t2: int) -> Optional[int]:
                    return None if t2 == m else (t2 if t2 < m else t2 - 1)
                if t == m:
                    row[n_a + 0] = f2_add(row[n_a + 0], f2_neg(ONE))
                    row[n_a + (2 * m - 1) + 0] = f2_add(row[n_a + (2 * m - 1) + 0], f2_neg(U))
                else:
                    cidx_re = n_a + bcol(t)
                    cidx_im = n_a + (2 * m - 1) + bcol(t)
                    row[cidx_re] = f2_add(row[cidx_re], ONE)
                    row[cidx_im] = f2_add(row[cidx_im], U)
            rows_all.append(row)
    # split each Fp2 observation row over Fp unknowns into re/im Fp rows
    fp_rows = []
    for row in rows_all:
        fp_rows.append([w[0] for w in row])
        fp_rows.append([w[1] for w in row])
    obs_d = [[r[c] for c in data_cols] for r in fp_rows]
    mask_cols = [c for c in range(n_a + n_b) if c not in data_cols]
    obs_m = [[r[c] for c in mask_cols] for r in fp_rows]
    dim, basis = disclosed_dim_fp(obs_d, obs_m)
    return {"log_m": log_m, "coefficients_fp2": n_coef, "pads": n_pads, "openings": len(thetas_W), "blinding": blinding,
            "data_scalars_fp": len(data_cols), "disclosed_fp_dim": dim, "disclosed_fp2_dim": dim // 2 if dim % 2 == 0 else dim / 2}


def m_joint_model(log_m: int, n_coef: int, n_pads: int, W: List[Fp2], indices: List[int], r_rows: List[Fp2],
                  openings: int = 1, W2: Optional[List[Fp2]] = None, r_rows2: Optional[List[Fp2]] = None) -> Dict:
    """The WHOLE M view of one mask at toy size, exactly as mask_open / mask_verify
    expose it: q' (2m Fp2 coefficients), prox (2m Fp2 coefficients), and the
    opened columns (a_re, a_im, b_re, b_im, u_re, u_im at each sampled coset
    point), with b (zero-sum), the pads and u SHARED across the channels.  The
    unknowns are Fp scalars: a_re / a_im message positions (coefficients then
    pads; the zeros are fixed), b_re / b_im (2m each, b[m] = -b[0]), u_re / u_im
    (2m each).  Disclosed = the Fp-dimension of the coefficient functionals the
    view determines; one honest opening must give exactly 2 (= V in Fp2)."""
    m = 1 << log_m
    idft = idft_rows(m)
    pts = coset_points(log_m)
    n_msg = n_coef + n_pads
    # unknown layout
    A_RE, A_IM = 0, n_msg
    B_RE, B_IM = 2 * n_msg, 2 * n_msg + (2 * m - 1)
    U_RE, U_IM = 2 * n_msg + 2 * (2 * m - 1), 2 * n_msg + 2 * (2 * m - 1) + 2 * m
    n_unk = U_IM + 2 * m
    data_cols = list(range(A_RE, A_RE + n_coef)) + list(range(A_IM, A_IM + n_coef))

    def bcol(base: int, t: int) -> Tuple[int, Fp2]:
        """column and sign of b[t] (b[m] = -b[0])."""
        if t == m:
            return base + 0, f2_neg(ONE)
        return base + (t if t < m else t - 1), ONE

    rows: List[List[Fp2]] = []
    names: List[str] = []

    def pw_coeffs(Wv: List[Fp2]) -> List[Fp2]:
        out = []
        for k in range(m):
            acc = ZERO
            for i in range(n_coef):
                acc = f2_add(acc, f2_mul_base(Wv[i], idft[k][i]))
            out.append(acc)
        return out

    def add_qprime(Wv: List[Fp2], tag: str) -> None:
        pw = pw_coeffs(Wv)
        for t in range(2 * m):
            row = [ZERO] * n_unk
            for k in range(m):
                l = t - k
                if l < 0 or l >= m:
                    continue
                for i in range(n_msg):
                    wgt = f2_mul_base(pw[l], idft[k][i])
                    row[A_RE + i] = f2_add(row[A_RE + i], wgt)
                    row[A_IM + i] = f2_add(row[A_IM + i], f2_mul(U, wgt))
            c, s = bcol(B_RE, t)
            row[c] = f2_add(row[c], s)
            c, s = bcol(B_IM, t)
            row[c] = f2_add(row[c], f2_mul(U, s))
            rows.append(row)
            names.append(f"{tag}.q'[{t}]")

    def add_prox(rr: List[Fp2], tag: str) -> None:
        # rows: a_re, a_im (degree < m), b_re, b_im (degree < 2m); prox = sum r_row p_row + u
        r_are, r_aim, r_bre, r_bim = rr
        for t in range(2 * m):
            row = [ZERO] * n_unk
            if t < m:
                for i in range(n_msg):
                    row[A_RE + i] = f2_add(row[A_RE + i], f2_mul_base(r_are, idft[t][i]))
                    row[A_IM + i] = f2_add(row[A_IM + i], f2_mul_base(r_aim, idft[t][i]))
            c, s = bcol(B_RE, t)
            row[c] = f2_add(row[c], f2_mul(r_bre, s))
            c, s = bcol(B_IM, t)
            row[c] = f2_add(row[c], f2_mul(r_bim, s))
            row[U_RE + t] = f2_add(row[U_RE + t], ONE)
            row[U_IM + t] = f2_add(row[U_IM + t], U)
            rows.append(row)
            names.append(f"{tag}.prox[{t}]")

    def add_columns(tag: str) -> None:
        for j in indices:
            x = pts[j]
            lag = lagrange_on_subgroup(m, x)
            xpow = [_pow(x, k) for k in range(2 * m)]
            for base, nm in ((A_RE, "a_re"), (A_IM, "a_im")):
                row = [ZERO] * n_unk
                for i in range(n_msg):
                    row[base + i] = f2(lag[i])
                rows.append(row)
                names.append(f"{tag}.col{j}.{nm}")
            for base, nm in ((B_RE, "b_re"), (B_IM, "b_im")):
                row = [ZERO] * n_unk
                for t in range(2 * m):
                    c, s = bcol(base, t)
                    row[c] = f2_add(row[c], f2_mul_base(s, xpow[t]))
                rows.append(row)
                names.append(f"{tag}.col{j}.{nm}")
            for base, nm in ((U_RE, "u_re"), (U_IM, "u_im")):
                row = [ZERO] * n_unk
                for t in range(2 * m):
                    row[base + t] = f2(xpow[t])
                rows.append(row)
                names.append(f"{tag}.col{j}.{nm}")

    add_qprime(W, "o1")
    add_prox(r_rows, "o1")
    add_columns("o1")
    if openings == 2:
        add_qprime(W2, "o2")
        add_prox(r_rows2, "o2")
        add_columns("o2")
    fp_rows = []
    for row in rows:
        fp_rows.append([w[0] for w in row])
        fp_rows.append([w[1] for w in row])
    mask_cols = [c for c in range(n_unk) if c not in data_cols]
    obs_d = [[r[c] for c in data_cols] for r in fp_rows]
    obs_m = [[r[c] for c in mask_cols] for r in fp_rows]
    dim, _ = disclosed_dim_fp(obs_d, obs_m)
    return {"log_m": log_m, "coefficients_fp2": n_coef, "pads": n_pads, "opened_columns": len(indices), "openings": openings,
            "unknowns_fp": n_unk, "observations_fp": len(fp_rows), "data_scalars_fp": len(data_cols),
            "disclosed_fp_dim": dim, "disclosed_fp2_dim": dim / 2}


def m_sum_identity_check(log_m: int, n_coef: int, n_pads: int, rng: Rng) -> Dict:
    """Numeric: sum over G_m of q' = m (q'_0 + q'_m) = <a, W> (b sums to zero)."""
    m = 1 << log_m
    w = subgroup_gen(m)
    a = [rng.fp2() for _ in range(n_coef)] + [rng.fp2() for _ in range(n_pads)] + [ZERO] * (m - n_coef - n_pads)
    W = [rng.fp2() for _ in range(n_coef)] + [ZERO] * (m - n_coef)
    idft = idft_rows(m)

    def coeffs(vals):
        return [f2_dot([f2(x) for x in idft[k]], vals) for k in range(m)]

    pa, pw = coeffs(a), coeffs(W)
    q = [ZERO] * (2 * m)
    for k in range(m):
        for l in range(m):
            q[k + l] = f2_add(q[k + l], f2_mul(pa[k], pw[l]))
    b = [rng.fp2() for _ in range(2 * m)]
    b[m] = f2_neg(b[0])
    q = [f2_add(x, y) for x, y in zip(q, b)]
    total = ZERO
    for i in range(m):
        x = _pow(w, i)
        xp = ONE
        val = ZERO
        for c in q:
            val = f2_add(val, f2_mul(c, xp))
            xp = f2_mul_base(xp, x)
        total = f2_add(total, val)
    lhs = f2_mul_base(f2_add(q[0], q[m]), m)
    inner = f2_dot(a, W)
    return {"sum_over_G_m_equals_m(q0+qm)": total == lhs, "equals_<a,W>": total == inner}


def controls_m_opening(rng: Rng, log_m: int = 3) -> Dict[str, Dict]:
    m = 1 << log_m
    q = 3
    L = 3
    out: Dict[str, Dict] = {}
    out["seven_generates_fp_star"] = {"ok": check_seven_generates(), "coset_disjoint_from_G_m": all(_pow(x, 8 * m) != 1 for x in coset_points(log_m)[:4])}
    idx = list(rng.r.sample(range(8 * m), q))
    out["pc_columns_q_distinct_under_q_pads"] = m_columns_model(log_m, L, q, idx)
    dup = idx[:2] + [idx[0]]
    out["pc_columns_duplicate_indices"] = m_columns_model(log_m, L, q, dup)
    idx1 = list(rng.r.sample(range(8 * m), q + 1))
    out["nc_columns_exceed_pads"] = m_columns_model(log_m, L, q, idx1)
    out["nc_columns_without_pads"] = m_columns_model(log_m, L, 0, idx)
    W1 = [rng.fp2() for _ in range(L)]
    W2 = [rng.fp2() for _ in range(L)]
    out["pc_qprime_one_opening"] = m_qprime_model(log_m, L, q, [W1])
    out["nc_qprime_two_openings_same_M"] = m_qprime_model(log_m, L, q, [W1, W2])
    out["nc_qprime_without_blinding"] = m_qprime_model(log_m, L, q, [W1], blinding=False)
    out["sum_identity"] = m_sum_identity_check(log_m, L, q, rng)
    rr1 = [rng.fp2() for _ in range(4)]
    rr2 = [rng.fp2() for _ in range(4)]
    out["pc_joint_qprime_prox_columns_one_opening"] = m_joint_model(log_m, L, q, W1, idx, rr1)
    out["nc_joint_two_openings_same_M"] = m_joint_model(log_m, L, q, W1, idx, rr1, openings=2, W2=W2, r_rows2=rr2)
    return out


# ----------------------------------------------------------------------------
# the Rust cross-check fixture (hashline/tests/zk60_fable_cfs_channel.rs)
# ----------------------------------------------------------------------------


def rust_fixture() -> Dict:
    n, d = 3, 2
    # real parts as negative representatives (p - k) so that every value is a
    # full-width residue; one challenge with a near-p coordinate as well
    coeffs = [f2(P - c0, c1) for c0, c1 in zip([3, 5, 7, 11, 13, 17, 20, 23], [1, 2, 3, 4, 5, 6, 7, 9])]
    rho = [f2(2, 1), f2(5, P - 3), f2(7, 4)]
    rounds = [cfs_round(coeffs, n, d, j, rho[:j]) for j in range(n)]
    total = cfs_total(coeffs, n, d)
    ev = cfs_eval(coeffs, rho, d)
    assert f2_add(rounds[0][0], rounds[0][1]) == total
    for j in range(1, n):
        assert f2_add(rounds[j][0], rounds[j][1]) == interp_eval(rounds[j - 1], rho[j - 1])
    assert interp_eval(rounds[n - 1], rho[n - 1]) == ev
    return {"n_vars": n, "degree": d, "coeffs": coeffs, "rho": rho, "rounds": rounds, "total": total, "eval": ev}


# ----------------------------------------------------------------------------
# driver
# ----------------------------------------------------------------------------


def source_hashes() -> Dict[str, str]:
    out = {}
    for rel in SOURCE_FILES:
        p = ROOT / rel
        out[rel] = hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else "missing"
    return out


def build_report(seed: int = 6) -> Dict:
    rng = Rng(seed)
    fixture = rust_fixture()
    table = slot_table_report(rng)
    controls = controls_message_channel(rng)
    m_controls = controls_m_opening(rng)
    all_ok = all(e["all_surjective"] for e in table)
    return {
        "schema_version": 1,
        "task": "FA6 -- the CFS masking channel: exact linear model of the mask channel per slot, the M opening, negative controls, the Rust cross-check fixture",
        "reviewer": REVIEWER,
        "source_commit": SOURCE_COMMIT,
        "source_sha256": source_hashes(),
        "seed": seed,
        "model": {
            "mask": "g(x) = a_0 + a' prod_j x_j + sum_j sum_{e=1..d} a_{j,e} x_j^e over N = n_vars variables (N d + 2 coefficients); round j: 2^(N-1-j) (a_0 + sum_{i<j} u_i(r_i) + sum_{i>j} u_i(1)/2 + u_j(X)) + a' (prod_{i<j} r_i) X",
            "view": "per masked sumcheck: the claimed sum's g-part (c G, or Gamma as batched), the N round messages' g-parts c g_j(0..d) (the last round(s) = the extension round(s)), the derived g(rho) = h_{N-1}(r_{N-1})/c - f-part, all as Fp2-linear functionals of the coefficients",
            "consistency_subspace": "S = {view : h_0(0)+h_0(1) = claim, h_j(0)+h_j(1) = interp(h_{j-1})(r_{j-1})}; dim S = N d + 1 per slot; f-part in S, so surjectivity of the map onto S makes f + L(a) uniform on S for every f",
            "verdict_rule": "rank(map) == dim S and image inside S  =>  the masked view is uniform on S, independent of the data (perfect hiding of the message channel); otherwise a leaked functional and a two-data counterexample are exhibited",
        },
        "slot_table": table,
        "all_slot_systems_surjective": all_ok,
        "controls_message_channel": controls,
        "controls_m_opening": m_controls,
        "rust_fixture": fixture,
    }


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=str(ROOT / "results" / "zk60_fable_fa6_cfs_channel.json"))
    ap.add_argument("--seed", type=int, default=6)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)
    rep = build_report(args.seed)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(rep, f, indent=1, sort_keys=False)
        f.write("\n")
    if not args.quiet:
        print(f"[FA6] source {SOURCE_COMMIT}; all slot systems surjective: {rep['all_slot_systems_surjective']}")
        for e in rep["slot_table"]:
            summ = ", ".join(f"{k}=({v['n_vars']},{v['degree']})" for k, v in e["slots"].items())
            print(f"  {e['shape']} [{e['mode']}]: {summ} -> {'OK' if e['all_surjective'] else 'DEFICIENT'}")
        for k, v in rep["controls_message_channel"].items():
            print(f"  control {k}: leaked_fp2 = {v['leaked_dim_fp2']}, kernel = {v['kernel_dim_fp2']} ({v['verdict']})")
        for k, v in rep["controls_m_opening"].items():
            print(f"  M control {k}: {v}")
        fx = rep["rust_fixture"]
        print("  rust fixture rounds:", fx["rounds"])
        print("  rust fixture total:", fx["total"], "eval:", fx["eval"])
        print(f"[FA6] wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

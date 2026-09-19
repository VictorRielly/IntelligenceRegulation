"""A small synthetic commitment of the SAME shape, where the disclosed
dimension is computed by BRUTE FORCE, to validate the stage-2 reduction and
to carry the negative controls.

The reduction used on the real captures (see `zk60_native_jv_pcs`) replaces
one dense rank over roughly 10^5 unknowns with small rank computations plus
three checked hypotheses.  Here the same view is built for a toy geometry
(n = 4 message columns, Q pads, a handful of rows) where the dense matrix is
tiny, and

    disclosed = rank([M_randomness | M_data]) - rank(M_randomness)

is computed directly from the definition.  The honest instance must agree
with the reduction; each control must DISCLOSE (a control that does not fire
is a blocking finding).

Nothing here touches a receipt: the toy instance is generated from a seeded
PRNG and carries no captured material.
"""

from __future__ import annotations

import random

from zk60_native_jv_field import (
    F2_ONE,
    F2_ZERO,
    P,
    f2_add,
    f2_mul,
    inv,
    rank,
    two_adic_root,
)

N = 4  # message columns per row
LOG_N = 2
INV_RATE = 4
NN = N * INV_RATE  # 16 encoded positions
COSET = 7


def col_functional(j, n=N, nn=NN, q=None):
    """E_j as (msg part, pad part), the toy analogue of encode_row_zk."""
    q = n if q is None else q
    w_nn = two_adic_root(nn.bit_length() - 1)
    w_n = two_adic_root(n.bit_length() - 1)
    xj = COSET * pow(w_nn, j, P) % P
    zn = (pow(xj, n, P) - 1) % P
    ninv = inv(n)
    msg, wns, w_n_inv = [], 1, inv(w_n)
    for _ in range(n):
        msg.append(zn * ninv % P * inv((xj * wns - 1) % P) % P)
        wns = wns * w_n_inv % P
    pad, xp = [], 1
    for _ in range(q):
        pad.append(zn * xp % P)
        xp = xp * xj % P
    return msg, pad


class ToyView:
    """Rows: `data` data rows, then one reserved pair per claim, then a
    proximity pair (and optionally a zero-sum u pair, as H has)."""

    def __init__(self, seed=1, n_data=3, n_claims=3, q_pad=4, n_cols=3, u_pair=False):
        self.rng = random.Random(seed)
        self.n_data = n_data
        self.n_claims = n_claims
        self.q_pad = q_pad
        self.n_cols = n_cols
        self.u_pair = u_pair
        self.share_pair = False
        self.no_masks = False
        self.extra_helper_sum = False
        self.opened_twice = False

    # ------------------------------------------------------------- build
    def _f2(self):
        return (self.rng.randrange(1, P), self.rng.randrange(P))

    def build(self):
        nd = self.n_data
        pairs = []
        row = nd
        if self.u_pair:
            self.u_rows = [row, row + 1]
            row += 2
        else:
            self.u_rows = []
        for c in range(self.n_claims):
            if self.share_pair and c == 1:
                pairs.append(pairs[0])
            else:
                pairs.append((row, row + 1))
                row += 2
        self.prox = (row, row + 1)
        rows = row + 2
        self.rows = rows
        self.pairs = pairs
        self.data_rows = list(range(nd)) + ([] if not self.u_pair else [])
        if self.no_masks:
            # every row but the proximity pair counts as data (masks removed)
            self.other_rows = [self.prox[0], self.prox[1]]
            self.data_rows = [r for r in range(rows) if r not in self.other_rows]
        else:
            self.other_rows = [r for r in range(rows) if r not in self.data_rows]

        # claim row weights: random data support + its reserved pair (kappa, kappa*U)
        self.rw = []
        self.cw = []
        for c in range(self.n_claims):
            w = [F2_ZERO] * rows
            for r in range(nd):
                w[r] = (self.rng.randrange(P), self.rng.randrange(P))
            if self.u_pair and c == 0:
                for r in self.u_rows:
                    w[r] = (self.rng.randrange(P), self.rng.randrange(P))
            k = self._f2()
            w[pairs[c][0]] = f2_add(w[pairs[c][0]], k)
            w[pairs[c][1]] = f2_add(w[pairs[c][1]], f2_mul(k, (0, 1)))
            self.rw.append(w)
            self.cw.append([self._f2() for _ in range(N)])
        if self.u_pair:
            # the LogUp-style sum claim: data rows + the u pair only
            w = [F2_ZERO] * rows
            for r in range(nd):
                w[r] = (self.rng.randrange(P), 0)
            k = self._f2()
            w[self.u_rows[0]] = k
            w[self.u_rows[1]] = f2_mul(k, (0, 1))
            self.rw.append(w)
            self.cw.append([F2_ONE] * N)  # a sum claim: all-ones column weights
        self.n_all = len(self.rw)
        # one group per claim (distinct keys), plus the proximity combination
        self.rhos = [list(w) for w in self.rw]
        self.rhos.append([self._f2() for _ in range(rows)])
        if self.opened_twice:
            self.rhos.append([self._f2() for _ in range(rows)])
        # the sampled columns
        pool = list(range(NN))
        self.rng.shuffle(pool)
        self.cols = sorted(pool[: self.n_cols])
        if self.opened_twice:
            rest = [j for j in pool if j not in self.cols]
            self.cols2 = sorted(rest[: self.n_cols])
        return self

    # --------------------------------------------- the dense observation map
    def observation_rows(self):
        """Every Fp observation functional as a vector over rows x (N + q)."""
        rows, q = self.rows, self.q_pad
        width = N + q
        out = []

        def zero():
            return [0] * (rows * width)

        def add_f2(vec_re, vec_im, i, t, coef):
            vec_re[i * width + t] = (vec_re[i * width + t] + coef[0]) % P
            vec_im[i * width + t] = (vec_im[i * width + t] + coef[1]) % P

        # (a) the claim values
        for c in range(self.n_all):
            re, im = zero(), zero()
            for i in range(rows):
                if self.rw[c][i] == F2_ZERO:
                    continue
                for t in range(N):
                    add_f2(re, im, i, t, f2_mul(self.rw[c][i], self.cw[c][t]))
            out.append(re)
            out.append(im)
        # (b)/(c) the group and proximity vectors, every one of their entries
        for rho in self.rhos:
            for t in range(width):
                re, im = zero(), zero()
                for i in range(rows):
                    add_f2(re, im, i, t, rho[i])
                out.append(re)
                out.append(im)
        # (d) the sampled columns, one functional per (row, distinct column)
        colsets = [self.cols] + ([self.cols2] if self.opened_twice else [])
        for cs in colsets:
            for j in cs:
                msg, pad = col_functional(j, q=q)
                for i in range(rows):
                    v = zero()
                    for t in range(N):
                        v[i * width + t] = msg[t]
                    for k in range(q):
                        v[i * width + N + k] = pad[k]
                    out.append(v)
        # the public linear constraint on the u rows (a randomness constraint,
        # equivalently an observation with a known value)
        for u in self.u_rows:
            v = zero()
            for t in range(N):
                v[u * width + t] = 1
            out.append(v)
        # a control: an extra published helper sum over a data row
        if self.extra_helper_sum:
            v = zero()
            for t in range(N):
                v[0 * width + t] = 1
            out.append(v)
        return out

    def data_columns(self):
        width = N + self.q_pad
        cols = set()
        for i in self.data_rows:
            for t in range(N):
                cols.add(i * width + t)
        return cols

    def disclosed_bruteforce(self):
        obs = self.observation_rows()
        dcols = self.data_columns()
        width = N + self.q_pad
        total = self.rows * width
        keep = [c for c in range(total) if c not in dcols]
        full = rank(obs, total)
        randonly = rank([[r[c] for c in keep] for r in obs], len(keep))
        return full - randonly

    # ------------------------------------------------ the stage-2 reduction
    def disclosed_reduction(self):
        gens = []
        for rho in self.rhos:
            gens.append([v[0] for v in rho])
            gens.append([v[1] for v in rho])
        r1 = rank(gens, self.rows)
        r_other = rank([[g[i] for i in self.other_rows] for g in gens], len(self.other_rows))
        k0 = r1 - r_other
        free = N * k0
        u_dim = 0
        if self.u_rows and not self.no_masks:
            from zk60_native_jv_field import solve

            xis = []
            for u in self.u_rows:
                t = [1 if i == u else 0 for i in self.other_rows]
                x, _ = solve([[g[i] for i in self.other_rows] for g in gens], t)
                if x is None:
                    continue
                xi = [0] * len(self.data_rows)
                for k, c in enumerate(x):
                    if c:
                        for a, i in enumerate(self.data_rows):
                            xi[a] = (xi[a] + c * gens[k][i]) % P
                xis.append(xi)
            u_dim = rank(xis, len(self.data_rows))
        return free + u_dim, {"k0": k0, "rank_P1": r1, "u_dim": u_dim}

    def hypotheses(self):
        """The three checked hypotheses of the reduction, on the toy instance."""
        d = len(set(self.cols) | set(self.cols2 if self.opened_twice else []))
        h_pad = d <= self.q_pad
        seen, h_pair = {}, True
        for c in range(self.n_all):
            touched = [
                r
                for r in self.other_rows
                if self.rw[c][r] != F2_ZERO and r not in self.u_rows
            ]
            if len(touched) != 2 or touched[1] != touched[0] + 1:
                if not (self.u_rows and not touched):
                    h_pair = False
                    continue
                touched = self.u_rows
            key = tuple(touched)
            if key in seen:
                h_pair = False
            seen[key] = c
        a, b = self.rhos[-1][self.prox[0]], self.rhos[-1][self.prox[1]]
        h_prox = (a[0] * b[1] - a[1] * b[0]) % P != 0
        return {"H-pad": h_pad, "H-pair": h_pair, "H-prox": h_prox, "distinct_columns": d}


def honest(seed=1, u_pair=False):
    return ToyView(seed=seed, u_pair=u_pair).build()


def controls():
    """Every negative control, with the brute-force disclosed dimension."""
    out = {}
    base = honest()
    out["honest"] = {
        "bruteforce": base.disclosed_bruteforce(),
        "reduction": base.disclosed_reduction()[0],
        "hypotheses": base.hypotheses(),
    }
    baseu = honest(u_pair=True)
    out["honest_with_zero_sum_pair"] = {
        "bruteforce": baseu.disclosed_bruteforce(),
        "reduction": baseu.disclosed_reduction()[0],
        "hypotheses": baseu.hypotheses(),
    }
    v = ToyView(seed=2)
    v.no_masks = True
    v.build()
    out["masks_removed"] = {"bruteforce": v.disclosed_bruteforce(), "hypotheses": v.hypotheses()}
    v = ToyView(seed=3)
    v.share_pair = True
    v.build()
    out["two_claims_share_one_pair"] = {
        "bruteforce": v.disclosed_bruteforce(),
        "hypotheses": v.hypotheses(),
    }
    v = ToyView(seed=4, n_cols=3, q_pad=4)
    v.opened_twice = True
    v.build()
    out["commitment_opened_twice"] = {
        "bruteforce": v.disclosed_bruteforce(),
        "hypotheses": v.hypotheses(),
    }
    v = ToyView(seed=5)
    v.extra_helper_sum = True
    v.build()
    out["extra_published_helper_sum"] = {
        "bruteforce": v.disclosed_bruteforce(),
        "hypotheses": v.hypotheses(),
    }
    v = ToyView(seed=6, n_cols=4, q_pad=3).build()
    out["one_pad_fewer_than_opened_columns"] = {
        "bruteforce": v.disclosed_bruteforce(),
        "hypotheses": v.hypotheses(),
    }
    return out

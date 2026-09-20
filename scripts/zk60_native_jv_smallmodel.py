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

THE PAD-BUDGET GUARD (moved here 2026-09-20).  The reduction's message-half
step is valid only while the DISTINCT opened positions fit inside the pad
count; case (f) of `zk60_native_jv_groups` exhibits an instance one position
beyond the budget where the reduction answers 0 and the dense rank does not.
The guard used to live only in the subclass, because editing this module
changes the hash recorded in evidence already committed.  It is now in the
base class, where it belongs: `disclosed_reduction` REFUSES outside the
budget and `disclosed_reduction_unguarded` is the way to see what the
reduction would have said.  Regenerating the two affected records changed
their `tool_sha256` and their timings and nothing else.
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


class PadBudgetRefusal(Exception):
    """The reduction refuses: more distinct opened positions than pads.

    `zk60_native_jv_groups` re-exports this name; the two are the same class,
    so every existing `except groups.PadBudgetRefusal` still catches it.
    """


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
        """The reduction, behind the pad-budget guard (see the header).

        Outside the budget the message-half step is not valid and the answer
        this method would give is WRONG, not merely unproven, so it refuses
        rather than returning a number.
        """
        hyp = self.hypotheses()
        if not hyp["H-pad"]:
            d = hyp.get("distinct_opened_positions", hyp.get("distinct_columns"))
            raise PadBudgetRefusal(
                f"{d} distinct opened positions exceed the {self.q_pad} pads: "
                "the message-half reduction is not valid outside the pad budget"
            )
        return self.disclosed_reduction_unguarded()

    def disclosed_reduction_unguarded(self):
        """The same reduction with the guard removed, to SHOW what it misses."""
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


# ------------------------------------------- the pad-budget boundary (§9b)
# The real source sets `q_pad = num_col_checks` exactly (pcs.rs::ZkOpts::
# standard, line 543; commit_zk_owned_with asserts q_pad >= num_col_checks,
# line 670), so on a receipt the opened positions can at most EQUAL the pads,
# and do so only if the 256 draws collide nowhere.  The report's §9 question 2
# asserted that the columns would then "stop being absorbed".  These checks
# settle it in the model, where the dense rank is computable.
#
# PREDICTIONS, recorded before the runs (the pad half of E_j is
# diag(x_j^n - 1) times a Vandermonde in the distinct nodes x_j, so its rank
# is the number of DISTINCT opened positions whenever that number is <= q_pad):
#   (a) q_pad == distinct opened positions  -> disclosed 0
#   (b) q_pad == distinct + 1               -> disclosed 0
#   (c) q_pad == distinct - 1               -> disclosed > 0 (the rank is one
#                                              short, the columns leak)
# and the group vectors consume NO pad freedom, because each group's row
# combination is nonzero on its own fresh reserved pair: the pad entries of a
# group vector are already explained by the mask rows' pads.
def group_pad_freedom(view):
    """Do the opening-group vectors spend the pads the columns need?

    A group vector contributes, per pad coordinate k, the functional
    z -> sum_i rho_g[i] pad_i[k].  It constrains the DATA rows' pads only in
    the directions it does not already reach through the mask rows, i.e. by
    rank(over all rows) - rank(restricted to the non-data rows).  That
    difference is q_pad * k0 of the stage-2 reduction; here it is measured
    directly from the functionals rather than taken from the formula."""
    rows, q = view.rows, view.q_pad
    data = set(view.data_rows)
    mask_coords = [(i, k) for i in range(rows) if i not in data for k in range(q)]
    obs_all, obs_mask = [], []
    for rho in view.rhos:
        for part in (0, 1):
            for k in range(q):
                v = [0] * (rows * q)
                for i in range(rows):
                    v[i * q + k] = rho[i][part]
                obs_all.append(v)
                obs_mask.append([v[i * q + kk] for (i, kk) in mask_coords])
    r_all = rank(obs_all, rows * q)
    r_mask = rank(obs_mask, len(mask_coords))
    # the UNGUARDED entry point on purpose: `k0` is a rank of the row-space
    # generators alone (rank over all rows minus rank over the non-data rows)
    # and has nothing to do with the pad budget, while this function is called
    # on the deliberately out-of-budget case (c) of `pad_boundary`.  Only the
    # message-half DISCLOSED figure is invalid there, and that figure is not
    # read here.
    k0 = view.disclosed_reduction_unguarded()[1]["k0"]
    return {
        "pad_functionals": len(obs_all),
        "rank_over_all_rows": r_all,
        "rank_over_the_non_data_rows": r_mask,
        "pad_freedom_consumed": r_all - r_mask,
        "equals_q_pad_times_k0": r_all - r_mask == q * k0,
        "k0": k0,
    }


def pad_boundary(seed=6, n_cols=4):
    """(a) q_pad == distinct, (b) q_pad == distinct + 1, (c) q_pad ==
    distinct - 1, each as a named check with its prediction beside it.  The
    toy draws its columns without replacement, so `distinct == n_cols`: the
    'no collisions' case the receipts only approach."""
    out = {}
    for name, q_pad, prediction in (
        ("q_pad_equals_distinct", n_cols, 0),
        ("q_pad_equals_distinct_plus_one", n_cols + 1, 0),
        ("q_pad_equals_distinct_minus_one", n_cols - 1, "> 0"),
    ):
        v = ToyView(seed=seed, n_cols=n_cols, q_pad=q_pad).build()
        hyp = v.hypotheses()
        disclosed = v.disclosed_bruteforce()
        out[name] = {
            "distinct_opened_positions": hyp["distinct_columns"],
            "q_pad": q_pad,
            "prediction": prediction,
            "bruteforce_disclosed": disclosed,
            "as_predicted": (disclosed == 0) if prediction == 0 else (disclosed > 0),
            "H-pad": hyp["H-pad"],
            "group_vectors": group_pad_freedom(v),
        }
    out["ok"] = all(out[k]["as_predicted"] for k in out if k != "ok") and all(
        out[k]["group_vectors"]["pad_freedom_consumed"] == 0 for k in out if k != "ok"
    )
    return out


# ------------------------------------- the JOINT reduction, brute-forced
# The stage-4 reduction (`zk60_native_jv_joint`) says the joint disclosed
# dimension of several commitments is
#     N * (rank(gens_joint) - rank(gens_joint | non-data classes)) + u-term
# over the JOINT row set, with a shared row merging two columns into their
# sum.  On a receipt that rank is over ~900 classes and the dense
# alternative is a rank over ~400,000 unknowns, so the reduction cannot be
# checked there.  Here two toy commitments are stacked and BOTH are
# computed: the dense joint rank from the definition, and the reduction.
#
# The identification is of MESSAGE coordinates only.  "The same blinding row
# in two commitments" means the same committed row values; each commitment
# still draws its own pads (pcs.rs::commit_zk_owned_with), and the toy keeps
# that distinction.
def _joint_coordinates(views, ident):
    """Joint coordinate index per (view, row, position), message rows merged."""
    width = N + views[0].q_pad
    parent = {}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for vi, v in enumerate(views):
        for i in range(v.rows):
            for t in range(width):
                parent[(vi, i, t)] = (vi, i, t)
    for (v0, r0), (v1, r1) in ident:
        for t in range(N):  # message positions only: the pads stay private
            a, b = find((v0, r0, t)), find((v1, r1, t))
            if a != b:
                parent[a] = b
    index, order = {}, []
    for vi, v in enumerate(views):
        for i in range(v.rows):
            for t in range(width):
                root = find((vi, i, t))
                if root not in index:
                    index[root] = len(order)
                    order.append(root)
                index[(vi, i, t)] = index[root]
    return index, len(order), width


def joint_bruteforce(views, ident):
    """The joint disclosed dimension from the DEFINITION, densely."""
    index, total, width = _joint_coordinates(views, ident)
    obs = []
    for vi, v in enumerate(views):
        for row in v.observation_rows():
            out = [0] * total
            for i in range(v.rows):
                for t in range(width):
                    x = row[i * width + t]
                    if x % P:
                        c = index[(vi, i, t)]
                        out[c] = (out[c] + x) % P
            obs.append(out)
    dcols = set()
    for vi, v in enumerate(views):
        for i in v.data_rows:
            for t in range(N):
                dcols.add(index[(vi, i, t)])
    keep = [c for c in range(total) if c not in dcols]
    return rank(obs, total) - rank([[r[c] for c in keep] for r in obs], len(keep))


def joint_reduction(views, ident):
    """The same number through the stage-4 reduction."""
    import zk60_native_jv_joint as joint

    blocks = [
        joint.Block(
            name=str(vi),
            rows=v.rows,
            data_rows=v.data_rows,
            u_rows=v.u_rows,
            gens_f2=v.rhos,
        )
        for vi, v in enumerate(views)
    ]
    ids = [((str(a[0]), a[1]), (str(b[0]), b[1])) for a, b in ident]
    return joint.JointSystem(blocks, identifications=ids).disclosed(msg_width=N)


def joint_controls():
    """Honest, one blinding row shared, one data row shared -- each with the
    dense joint rank beside the reduction's."""
    out = {}
    cases = []
    a, b = honest(seed=11), honest(seed=12)
    cases.append(("honest_two_commitments", [a, b], []))
    a2, b2 = honest(seed=11), honest(seed=12)
    # a reserved-pair row of the first claim of each: where the non-data
    # block is square, so the model can see the sharing at all
    cases.append(
        ("one_blinding_row_shared", [a2, b2], [((0, a2.pairs[0][0]), (1, b2.pairs[0][0]))])
    )
    a3, b3 = honest(seed=11), honest(seed=12)
    cases.append(("one_data_row_shared", [a3, b3], [((0, 0), (1, 0))]))
    for name, views, ident in cases:
        marginals = [v.disclosed_bruteforce() for v in views]
        bf = joint_bruteforce(views, ident)
        red = joint_reduction(views, ident)
        out[name] = {
            "marginals_bruteforce": marginals,
            "sum_of_marginals": sum(marginals),
            "joint_bruteforce": bf,
            "joint_reduction": red["disclosed_fp"],
            "joint_k0": red["k0"],
            "reduction_agrees_with_bruteforce": bf == red["disclosed_fp"],
            "joint_minus_sum": bf - sum(marginals),
        }
    out["ok"] = (
        all(out[c[0]]["reduction_agrees_with_bruteforce"] for c in cases)
        and out["honest_two_commitments"]["joint_minus_sum"] == 0
        and out["one_blinding_row_shared"]["joint_minus_sum"] > 0
        and out["one_data_row_shared"]["joint_minus_sum"] <= 0
    )
    return out


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

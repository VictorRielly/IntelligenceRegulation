"""The small model, extended with real OPENING GROUPS (review change R-8).

WHY THIS MODULE EXISTS.  The joint-view gate validates its stage-2 reduction
against a brute-force dense rank on a toy instance (`zk60_native_jv_smallmodel`).
That toy has **one opening group per claim**.  The real receipts do not: the
prover batches several claims that share a column-weight key into ONE group
with a challenge coefficient `lambda_c` per member, and publishes one group
vector for the batch plus every member's claim value separately.  The
independent review of the terminal-surjection step (2026-09-20,
`docs/zkmatrix-poc/ZK60_TERMINAL_SURJECTION_REVIEW.md`, change R-8, accepted
by the security owner in `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`) found
that the batched case -- the whole subject of that step -- had never been
machine-validated inside the gate, and neither had a group whose members
share a reserved mask pair.

WHAT IS ADDED.  Six cases, each computed TWO ways and compared:

    a  a MULTI-MEMBER group: m >= 3 claims batched by lambda_c into one
       group, one reserved pair per claim site
    b  a SHARED-PAIR group: two ordinary terminals on one reserved pair
    c  the H-style LEGITIMATE sharing: two groups sharing a zero-sum pair
       whose claims are tied by a public identity
    d  a pair with the WRONG SHAPE: base-field-dependent weights in place of
       (cm, cm*U), with cm != 0 (and, beside it, the pair removed entirely)
    e  lambda_c = 0 for one member
    f  one opened position beyond the pad budget

HOW THE TWO FIGURES ARE PRODUCED.  `GroupedToyView` SUBCLASSES the gate's own
`zk60_native_jv_smallmodel.ToyView` and overrides only `build()` (the group
schedule) and `hypotheses()` (the group-aware hypothesis checks).  The dense
forward map (`observation_rows`), the dense disclosed dimension
(`disclosed_bruteforce`) and THE REDUCTION UNDER TEST (`disclosed_reduction`)
are the existing tool's code, inherited unmodified.  So "reduction" below
really is the gate's reduction and "dense" really is a rank of the full
forward map with no reduction at all.

THE GUARD.  The real-capture path refuses when the number of DISTINCT opened
columns exceeds the pad count (`zk60_native_jv_pcs.py`,
`distinct_opened_columns_within_pad_count`, which feeds stage 2's verdict).
The small-model path did not: `ToyView.disclosed_reduction` computed a figure
whatever the pad budget was, and case (f) below shows that figure is WRONG
there.  `GroupedToyView.disclosed_reduction` raised `PadBudgetRefusal` on
exactly that condition before computing anything.  **Since 2026-09-20 the
guard is in the BASE class** (`zk60_native_jv_smallmodel.ToyView`), where the
condition belongs; the override here is kept because its message names the
group-aware hypothesis key, and `PadBudgetRefusal` below is now an alias of
the base module's class, so both paths raise the same exception.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.  Every number is a rank of an
explicitly stated linear model on a synthetic instance whose data and
blinding are both known and both public.  No receipt, capture or Rust source
is read or written.
"""

from __future__ import annotations

import random

from zk60_native_jv_field import (
    F2_ONE,
    F2_ZERO,
    P,
    eq_table_msb,
    f2_add,
    f2_mul,
    f2_mul_base,
    rank,
    solve,
)
import zk60_native_jv_smallmodel as smallmodel

N = smallmodel.N  # message columns per row (4)
NN = smallmodel.NN  # encoded positions (16)
U = (0, 1)  # the Fp2 generator u, u^2 = 7; the second weight of a reserved pair


# The reduction's refusal: more distinct opened positions than pads.  The same
# condition the real-capture path already checks
# (`zk60_native_jv_pcs.RoleView._check_pad_budget`, fact
# `distinct_opened_columns_within_pad_count`).  Case (f) is why it has to be a
# refusal and not a warning: beyond the budget the reduction's answer is 0 and
# the truth is not.  Defined in the base module since 2026-09-20 and ALIASED
# here, so `groups.PadBudgetRefusal` keeps working and is the same class.
PadBudgetRefusal = smallmodel.PadBudgetRefusal


# --------------------------------------------------------------- the schedule
class Claim:
    """One claim of one group.

    `site`        which reserved pair site the claim's mask sits on; two
                  claims with the SAME site share a pair (the forbidden case).
                  None means the claim has no site pair of its own.
    `shape`       "pair"          weights (cm, cm*U)   -- an Fp-basis of Fp2
                  "fp_dependent"  weights (cm, s*cm), s in Fp, cm != 0
                  "none"          no pair at all (cm = 0)
    `on_u`        the claim also EVALUATES the zero-sum rows, with ordinary
                  weights, as H's zsum slot does
    `u_is_pair`   the claim's reserved pair IS the zero-sum pair, as H's
                  LogUp sum claim's is
    `base_data`   the claim's data-row weights are in Fp rather than Fp2
    """

    def __init__(self, site=None, shape="pair", on_u=False, u_is_pair=False, base_data=False):
        self.site = site
        self.shape = shape
        self.on_u = on_u
        self.u_is_pair = u_is_pair
        self.base_data = base_data


class Group:
    """One opening group: members batched by `lambdas`, one shared `cw`.

    `cw` is "eq" (an equality tensor at random Fp2 points, what every
    evaluation claim gets) or "ones" (all-ones, what a sum claim gets).
    `lambdas` may name explicit coefficients; None draws nonzero ones.
    """

    def __init__(self, members, cw="eq", lambdas=None):
        self.members = list(members)
        self.cw = cw
        self.lambdas = lambdas


# ------------------------------------------------------------------ the view
class GroupedToyView(smallmodel.ToyView):
    """`ToyView` with an explicit group schedule; everything else inherited."""

    def __init__(self, claims, groups, seed=1, n_data=3, q_pad=4, n_cols=3, u_pair=False):
        super().__init__(
            seed=seed,
            n_data=n_data,
            n_claims=len(claims),
            q_pad=q_pad,
            n_cols=n_cols,
            u_pair=u_pair,
        )
        self.claims = list(claims)
        self.group_specs = list(groups)

    # ------------------------------------------------------------- build
    def build(self):
        nd = self.n_data
        row = nd
        if self.u_pair:
            self.u_rows = [row, row + 1]
            row += 2
        else:
            self.u_rows = []
        sites = sorted({c.site for c in self.claims if c.site is not None})
        self.site_rows = {}
        for s in sites:
            self.site_rows[s] = (row, row + 1)
            row += 2
        self.prox = (row, row + 1)
        self.rows = row + 2
        rows = self.rows
        self.data_rows = list(range(nd))
        self.other_rows = [r for r in range(rows) if r not in self.data_rows]
        self.pairs = [
            self.site_rows[c.site]
            if c.site is not None
            else (tuple(self.u_rows) if c.u_is_pair else ())
            for c in self.claims
        ]

        # ---- the claims' row weights
        self.rw = []
        for c in self.claims:
            w = [F2_ZERO] * rows
            for r in range(nd):
                w[r] = (self.rng.randrange(P), 0) if c.base_data else self._f2()
            if c.on_u:
                for r in self.u_rows:
                    w[r] = f2_add(w[r], self._f2())
            pair = None
            if c.site is not None:
                pair = self.site_rows[c.site]
            elif c.u_is_pair:
                pair = tuple(self.u_rows)
            if pair and c.shape != "none":
                k = self._f2()  # cm, nonzero by construction
                second = f2_mul(k, U) if c.shape == "pair" else f2_mul_base(
                    k, self.rng.randrange(1, P)
                )
                w[pair[0]] = f2_add(w[pair[0]], k)
                w[pair[1]] = f2_add(w[pair[1]], second)
            self.rw.append(w)
        self.n_all = len(self.rw)

        # ---- one column-weight vector per GROUP, shared by its members
        self.group_cw = []
        for g in self.group_specs:
            if g.cw == "ones":
                self.group_cw.append([F2_ONE] * N)
            else:
                self.group_cw.append(eq_table_msb([self._f2() for _ in range(2)]))
        # the inherited observation map wants one cw per CLAIM
        self.cw = [None] * self.n_all
        for gi, g in enumerate(self.group_specs):
            for m in g.members:
                self.cw[m] = self.group_cw[gi]
        assert all(v is not None for v in self.cw), "every claim must be in a group"

        # ---- lambda per member, and the group row-combination (pcs.rs::zk_rhos
        #      then RoleView.run: rho_g = sum_c lambda_c * rw_c)
        self.lambdas = []
        self.rhos = []
        for gi, g in enumerate(self.group_specs):
            lams = g.lambdas if g.lambdas is not None else [self._f2() for _ in g.members]
            self.lambdas.append(list(lams))
            rho = [F2_ZERO] * rows
            for m, lam in zip(g.members, lams):
                for i in range(rows):
                    if self.rw[m][i] != F2_ZERO:
                        rho[i] = f2_add(rho[i], f2_mul(lam, self.rw[m][i]))
            self.rhos.append(rho)
        self.rhos.append([self._f2() for _ in range(rows)])  # the proximity vector

        # ---- the sampled columns
        pool = list(range(NN))
        self.rng.shuffle(pool)
        self.cols = sorted(pool[: self.n_cols])
        self.cols2 = []
        return self

    # -------------------------------------------------------- hypotheses
    def hypotheses(self):
        """The reduction's hypotheses, group-aware.

        `H-pair` reproduces `RoleView._check_pair_schedule` line for line,
        INCLUDING its allowance that a claim may evaluate the zero-sum rows
        as well as carry its own pair.  That is why it passes on the H-style
        case (c): the real check never noticed the cross-group sharing
        either, which is the review's section 3.4 finding.  The extra key
        `groups_pairwise_disjoint_off_data` is the review's assembly premise
        (a) -- the one that actually fails there.
        """
        d = len(set(self.cols) | set(self.cols2 or []))
        h_pad = d <= self.q_pad
        used, h_pair = {}, True
        shared_pairs, bad_shape, no_pair = [], [], []
        for c in range(self.n_all):
            rw = self.rw[c]
            touched = [r for r in self.other_rows if rw[r] != F2_ZERO]
            if any(r in self.prox for r in touched):
                h_pair = False
            rest = [r for r in touched if r not in self.u_rows]
            if not rest and self.u_rows and set(touched) == set(self.u_rows):
                pair = tuple(sorted(self.u_rows))
            elif len(rest) == 2 and rest[1] == rest[0] + 1:
                pair = (rest[0], rest[1])
            else:
                h_pair = False
                no_pair.append(c)
                continue
            if pair in used:
                h_pair = False
                shared_pairs.append([used[pair], c])
            used[pair] = c
            a, b = rw[pair[0]], rw[pair[1]]
            if (a[0] * b[1] - a[1] * b[0]) % P == 0:
                h_pair = False
                bad_shape.append(c)

        # the review's premise (a): no two GROUPS share a non-data row
        supports = []
        for g in self.group_specs:
            s = set()
            for m in g.members:
                s |= {r for r in self.other_rows if self.rw[m][r] != F2_ZERO}
            supports.append(s)
        overlap = []
        for i in range(len(supports)):
            for j in range(i + 1, len(supports)):
                if supports[i] & supports[j]:
                    overlap.append([i, j])

        a, b = self.rhos[-1][self.prox[0]], self.rhos[-1][self.prox[1]]
        h_prox = (a[0] * b[1] - a[1] * b[0]) % P != 0
        return {
            "H-pad": h_pad,
            "H-pair": h_pair,
            "H-prox": h_prox,
            "distinct_opened_positions": d,
            "pad_count": self.q_pad,
            "claims_sharing_a_pair": shared_pairs,
            "claims_whose_pair_is_not_an_Fp_basis": bad_shape,
            "claims_with_no_reserved_pair": no_pair,
            "groups_pairwise_disjoint_off_data": overlap == [],
            "group_pairs_that_overlap_off_data": overlap,
        }

    # ------------------------------------------------- the guarded reduction
    def disclosed_reduction(self):
        """The tool's reduction, behind the pad-budget guard (see the header).

        Since 2026-09-20 the base class carries the same guard; this override
        is kept only so the message names the group-aware hypothesis key.
        """
        hyp = self.hypotheses()
        if not hyp["H-pad"]:
            raise PadBudgetRefusal(
                f"{hyp['distinct_opened_positions']} distinct opened positions "
                f"exceed the {self.q_pad} pads: the message-half reduction is "
                f"not valid outside the pad budget"
            )
        return super().disclosed_reduction()

    # ------------------------------------------ the per-group message-half system
    def per_group_systems(self, with_u_constraint=False):
        """The review's section 1.4 system, one group at a time.

        Observations: the group vector's N message entries and the group's
        member claim values, each as two Fp functionals.  Unknowns: msg over
        rows x N.  `with_u_constraint=False` is the step's OWN model, in which
        a reserved pair is an unconstrained pair of uniform rows; the
        zero-sum pair is not one, and leaving the constraint out is exactly
        the blind spot case (c) exhibits.
        """
        rows, total = self.rows, self.rows * N
        data = set(self.data_rows)
        blind = [c for c in range(total) if c // N not in data]
        out = []
        for gi, spec in enumerate(self.group_specs):
            rho, cw = self.rhos[gi], self.group_cw[gi]
            obs = []
            for t in range(N):
                re, im = [0] * total, [0] * total
                for i in range(rows):
                    if rho[i] != F2_ZERO:
                        re[i * N + t], im[i * N + t] = rho[i][0], rho[i][1]
                obs += [re, im]
            for m in spec.members:
                rw = self.rw[m]
                re, im = [0] * total, [0] * total
                for i in range(rows):
                    if rw[i] == F2_ZERO:
                        continue
                    for t in range(N):
                        prod = f2_mul(rw[i], cw[t])
                        re[i * N + t] = (re[i * N + t] + prod[0]) % P
                        im[i * N + t] = (im[i * N + t] + prod[1]) % P
                obs += [re, im]
            touches_u = any(
                self.rw[m][u] != F2_ZERO for m in spec.members for u in self.u_rows
            ) or any(rho[u] != F2_ZERO for u in self.u_rows)
            if with_u_constraint and touches_u:
                for u in self.u_rows:
                    v = [0] * total
                    for t in range(N):
                        v[u * N + t] = 1
                    obs.append(v)
            r_all = rank(obs, total)
            r_blind = rank([[r[c] for c in blind] for r in obs], len(blind))
            m = len(spec.members)
            out.append(
                {
                    "group": gi,
                    "members": m,
                    "observations_fp": len(obs),
                    "blinding_rank": r_blind,
                    "rank_with_data": r_all,
                    "disclosed_fp": r_all - r_blind,
                    "rank_equals_2_n_plus_m_minus_2": r_blind == 2 * (N + m) - 2,
                    "touches_the_zero_sum_rows": touches_u,
                }
            )
        return out

    def per_group_figure(self, with_u_constraint=False):
        return sum(g["disclosed_fp"] for g in self.per_group_systems(with_u_constraint))

    # ------------------------------------------------ the disclosed space itself
    def disclosed_space(self):
        """A basis of F intersect T, densely: which functionals of the DATA the
        whole view determines.  `rank` of what comes back is exactly
        `disclosed_bruteforce()`; the basis is what lets the H-style case be
        compared with the public identity, as `RoleView._disclosed` does on the
        real captures (`equals_public_logup_identity`)."""
        obs = self.observation_rows()
        dcols = self.data_columns()
        total = self.rows * (N + self.q_pad)
        bcols = [c for c in range(total) if c not in dcols]
        dlist = sorted(dcols)
        _, kern = solve([[r[c] for c in bcols] for r in obs], [0] * len(bcols))
        out = []
        for coef in kern:
            phi = [0] * len(dlist)
            for k, ck in enumerate(coef):
                if ck:
                    row = obs[k]
                    for t, c in enumerate(dlist):
                        phi[t] = (phi[t] + ck * row[c]) % P
            if any(phi):
                out.append(phi)
        return out, dlist

    def claim_data_functionals(self, claim_index):
        """The claim's own data-row weights, as two Fp functionals over the
        data rectangle: the public identity candidate."""
        width = N + self.q_pad
        dlist = sorted(self.data_columns())
        pos = {c: t for t, c in enumerate(dlist)}
        rw, cw = self.rw[claim_index], self.cw[claim_index]
        re, im = [0] * len(dlist), [0] * len(dlist)
        for i in self.data_rows:
            if rw[i] == F2_ZERO:
                continue
            for t in range(N):
                prod = f2_mul(rw[i], cw[t])
                k = pos[i * width + t]
                re[k] = (re[k] + prod[0]) % P
                im[k] = (im[k] + prod[1]) % P
        return [re, im]

    def disclosure_equals_claim_identity(self, claim_index):
        """Span equality between what is disclosed and one claim's identity."""
        disc, dlist = self.disclosed_space()
        ident = self.claim_data_functionals(claim_index)
        rd, ri = rank(disc, len(dlist)), rank(ident, len(dlist))
        return {
            "rank_disclosed": rd,
            "rank_public_identity": ri,
            "rank_of_both_together": rank(disc + ident, len(dlist)),
            "spans_are_equal": rd == ri == rank(disc + ident, len(dlist)),
        }

    # ------------------------------------------- marginal vs joint terminal law
    def _terminal_functionals(self, claim_indices):
        """The Fp observation rows of the named claim values, over rows x width."""
        width = N + self.q_pad
        total = self.rows * width
        out = []
        for c in claim_indices:
            rw, cw = self.rw[c], self.cw[c]
            re, im = [0] * total, [0] * total
            for i in range(self.rows):
                if rw[i] == F2_ZERO:
                    continue
                for t in range(N):
                    prod = f2_mul(rw[i], cw[t])
                    re[i * width + t] = (re[i * width + t] + prod[0]) % P
                    im[i * width + t] = (im[i * width + t] + prod[1]) % P
            out += [re, im]
        return out, total, width

    def terminal_law(self, claim_indices):
        """The law of a SET of published terminals, as blinding rank + residue.

        y = A b + B d with b the blinding coordinates and d the data ones.  The
        law of y is uniform on the affine subspace col(A) + B d, so
        `support_dim = rank(A)`; the law moves with the data exactly when some
        functional annihilating col(A) is nonzero on B.  Everything here is
        exact linear algebra over Fp on a synthetic instance.
        """
        obs, total, width = self._terminal_functionals(claim_indices)
        dcols = self.data_columns()
        bcols = [c for c in range(total) if c not in dcols]
        dlist = sorted(dcols)
        a_rows = [[r[c] for c in bcols] for r in obs]
        b_rows = [[r[c] for c in dlist] for r in obs]
        r_a = rank(a_rows, len(bcols))
        _, kern = solve(a_rows, [0] * len(bcols))
        survivors = []
        for coef in kern:
            phi = [0] * len(dlist)
            for k, ck in enumerate(coef):
                if ck:
                    for t in range(len(dlist)):
                        phi[t] = (phi[t] + ck * b_rows[k][t]) % P
            if any(phi):
                survivors.append(phi)
        return {
            "terminals": list(claim_indices),
            "observations_fp": len(obs),
            "support_dim": r_a,
            "full_support": r_a == len(obs),
            "annihilator_dim": len(kern),
            "surviving_data_functionals": rank(survivors, len(dlist)) if survivors else 0,
            "_survivors": survivors,
            "_data_index": dlist,
        }

    def law_separates_two_data_vectors(self, claim_indices):
        """Two data vectors whose joint laws have DISJOINT supports, or none.

        d1 is the all-zero data (the zero-witness); d2 is the unit vector at
        one coordinate the surviving functional does not kill.  Both are
        synthetic and public.  The returned `supports_disjoint` says the two
        laws are different measures, not merely differently parameterised.
        """
        law = self.terminal_law(claim_indices)
        if not law["_survivors"]:
            return {
                "terminals": list(claim_indices),
                "support_dim": law["support_dim"],
                "separating_coordinate": None,
                "supports_disjoint": False,
                "why": "no functional survives: the law is the same for every data vector",
            }
        phi = law["_survivors"][0]
        j = next(t for t, v in enumerate(phi) if v)
        d1_value = 0  # phi . 0
        d2_value = phi[j] % P  # phi . e_j
        return {
            "terminals": list(claim_indices),
            "support_dim": law["support_dim"],
            "observations_fp": law["observations_fp"],
            "separating_coordinate": law["_data_index"][j],
            "separating_coordinate_row": law["_data_index"][j] // (N + self.q_pad),
            "supports_disjoint": d1_value != d2_value,
            "surviving_data_functionals": law["surviving_data_functionals"],
        }


def _clean(d):
    """Drop the private working fields; evidence keeps counts and booleans."""
    return {k: v for k, v in d.items() if not k.startswith("_")}


# ------------------------------------------------------------------- builders
def multi_member(m=3, seed=1, zero_lambda=None, n_data=3, q_pad=4, n_cols=3):
    """Case (a)/(e): ONE group, m claims, one reserved pair per claim site."""
    claims = [Claim(site=c) for c in range(m)]
    lambdas = None
    if zero_lambda is not None:
        rng = random.Random(seed * 7919 + 13)
        lambdas = [
            F2_ZERO if c == zero_lambda else (rng.randrange(1, P), rng.randrange(P))
            for c in range(m)
        ]
    return GroupedToyView(
        claims,
        [Group(range(m), lambdas=lambdas)],
        seed=seed,
        n_data=n_data,
        q_pad=q_pad,
        n_cols=n_cols,
    ).build()


def shared_pair_in_one_group(m=3, seed=1):
    """Case (b): members 0 and 1 of one group sit on the SAME reserved pair."""
    claims = [Claim(site=0), Claim(site=0)] + [Claim(site=c) for c in range(1, m - 1)]
    return GroupedToyView(claims, [Group(range(m))], seed=seed).build()


def shared_pair_across_two_groups(seed=1):
    """Case (b), variant: two ORDINARY terminals in different groups, one pair."""
    claims = [Claim(site=0), Claim(site=0), Claim(site=1)]
    groups = [Group([0, 2]), Group([1])]
    return GroupedToyView(claims, groups, seed=seed).build()


def h_style_sharing(seed=1):
    """Case (c): H's two groups on the zero-sum pair.

    Claim 0 is the `zsum` slot's claim: it EVALUATES the zero-sum rows with
    ordinary weights and carries its own reserved pair, and its group has an
    ordinary (equality-tensor) column weight.  Claim 1 is the LogUp sum
    claim: its reserved pair IS the zero-sum pair and its group's column
    weight is all-ones, so the pair's contribution to its value is
    cm * sum_t msg_u0[t] + cm*U * sum_t msg_u1[t] = 0 under the public
    constraint -- the value is pure data, and that is the public identity.
    """
    claims = [Claim(site=0, on_u=True), Claim(site=None, u_is_pair=True)]
    groups = [Group([0], cw="eq"), Group([1], cw="ones")]
    return GroupedToyView(claims, groups, seed=seed, u_pair=True).build()


def wrong_pair_shape(m=1, seed=1, shape="fp_dependent"):
    """Case (d): member 0's pair weights are (cm, s*cm) with s in Fp, cm != 0.

    `shape="none"` removes the pair instead (cm = 0), the review's A4.
    """
    claims = [Claim(site=0, shape=shape)] + [Claim(site=c) for c in range(1, m)]
    return GroupedToyView(claims, [Group(range(m))], seed=seed).build()


def beyond_the_pad_budget(m=3, seed=1, q_pad=4, extra=1):
    """Case (f): `extra` more DISTINCT opened positions than there are pads."""
    return multi_member(m=m, seed=seed, q_pad=q_pad, n_cols=q_pad + extra)


# ------------------------------------------------------------------ the cases
def _two_figures(view, expect_dense, expect_reduction, note):
    """Both figures of one instance, plus the per-group ones and the hypotheses."""
    hyp = view.hypotheses()
    dense = view.disclosed_bruteforce()
    refused, red = False, None
    try:
        red = view.disclosed_reduction()[0]
    except PadBudgetRefusal:
        refused = True
    out = {
        "rows": view.rows,
        "claims": view.n_all,
        "groups": len(view.group_specs),
        "group_sizes": [len(g.members) for g in view.group_specs],
        "message_columns": N,
        "pads": view.q_pad,
        "distinct_opened_positions": hyp["distinct_opened_positions"],
        "dense_disclosed_fp": dense,
        "reduction_refused": refused,
        "reduction_disclosed_fp": red,
        "reduction_disclosed_fp_unguarded": view.disclosed_reduction_unguarded()[0],
        "agree": (not refused) and red == dense,
        "per_group_step_figure_fp": view.per_group_figure(False),
        "per_group_figure_with_the_public_constraint_fp": view.per_group_figure(True),
        "per_group_systems": view.per_group_systems(False),
        "hypotheses": hyp,
        "expected_dense_fp": expect_dense,
        "expected_reduction_fp": expect_reduction,
        "as_expected": (dense > 0 if expect_dense == "> 0" else dense == expect_dense)
        and (expect_reduction == "refused" if refused else red == expect_reduction),
        "note": note,
    }
    return out


def case_a_multi_member(ms=(3, 4, 5), seeds=(1, 2, 3, 4)):
    """(a) honest multi-member groups: reduction == dense == 0, every draw."""
    runs = []
    for m in ms:
        for s in seeds:
            v = multi_member(m=m, seed=s)
            r = _two_figures(v, 0, 0, f"m={m}, seed={s}")
            r["m"] = m
            r["seed"] = s
            runs.append(r)
    return {
        "what": "m >= 3 claims batched into ONE group by lambda_c, one reserved "
        "pair per claim site; the case the real receipts use and the small "
        "model never had",
        "runs": runs,
        "all_agree": all(r["agree"] for r in runs),
        "all_zero": all(r["dense_disclosed_fp"] == 0 for r in runs),
        "per_group_rank_formula_holds": all(
            g["rank_equals_2_n_plus_m_minus_2"] for r in runs for g in r["per_group_systems"]
        ),
        "ok": all(r["as_expected"] for r in runs),
    }


def case_b_shared_pair(seed=1):
    """(b) two ordinary terminals on one reserved pair: marginals vs joint."""
    v = shared_pair_in_one_group(m=3, seed=seed)
    fig = _two_figures(v, 2, 0, "two members of one group on one pair")
    marginals = [_clean(v.terminal_law([c])) for c in (0, 1)]
    joint = _clean(v.terminal_law([0, 1]))
    sep = v.law_separates_two_data_vectors([0, 1])
    across = shared_pair_across_two_groups(seed=seed)
    fig_across = _two_figures(across, 2, 0, "two groups, one pair")
    return {
        "what": "two ordinary terminals sharing one reserved pair: every "
        "marginal stays uniform, the JOINT law does not",
        "in_one_group": fig,
        "marginal_laws": marginals,
        "every_marginal_has_full_support": all(m["full_support"] for m in marginals),
        "every_marginal_discloses_nothing": all(
            m["surviving_data_functionals"] == 0 for m in marginals
        ),
        "joint_law": joint,
        "joint_support_is_short_by_fp": joint["observations_fp"] - joint["support_dim"],
        "joint_moves_with_the_data": sep,
        "across_two_groups": fig_across,
        "the_gate_refuses_it": not fig["hypotheses"]["H-pair"],
        "the_reduction_alone_does_not_see_it": fig["reduction_disclosed_fp"] == 0,
        "ok": (
            fig["dense_disclosed_fp"] > 0
            and all(m["full_support"] for m in marginals)
            and joint["support_dim"] < joint["observations_fp"]
            and sep["supports_disjoint"]
            and not fig["hypotheses"]["H-pair"]
        ),
    }


def case_c_h_style(seed=1):
    """(c) the legitimate sharing: jointly 2 Fp, and they are the identity."""
    v = h_style_sharing(seed=seed)
    fig = _two_figures(v, 2, 2, "two groups on the zero-sum pair, tied by a public identity")
    # is what is disclosed exactly the public identity the statement announces?
    # (the same span comparison RoleView._disclosed makes on the real captures)
    identity = v.disclosure_equals_claim_identity(1)
    return {
        "what": "H's two opening groups share the zero-sum pair; the per-group "
        "decomposition is not licensed there, and the joint answer is the "
        "public LogUp-style identity",
        "figures": fig,
        "ranked_jointly_fp": fig["dense_disclosed_fp"],
        "the_tools_reduction_fp": fig["reduction_disclosed_fp"],
        "per_group_step_figure_fp": fig["per_group_step_figure_fp"],
        "per_group_step_figure_is_wrong": fig["per_group_step_figure_fp"]
        != fig["dense_disclosed_fp"],
        "the_gates_own_H_pair_check_passes": fig["hypotheses"]["H-pair"],
        "but_the_groups_are_not_disjoint": not fig["hypotheses"][
            "groups_pairwise_disjoint_off_data"
        ],
        "the_disclosure_is_the_public_identity": identity,
        "ok": (
            fig["dense_disclosed_fp"] == 2
            and fig["reduction_disclosed_fp"] == 2
            and fig["per_group_step_figure_fp"] == 0
            and not fig["hypotheses"]["groups_pairwise_disjoint_off_data"]
            and identity["spans_are_equal"]
            and identity["rank_disclosed"] == 2
        ),
    }


def case_d_wrong_pair_shape(seed=1):
    """(d) base-field-dependent pair weights with cm != 0, and cm = 0 beside it."""
    single = _two_figures(
        wrong_pair_shape(m=1, seed=seed), N, N, "singleton group, Fp-dependent pair"
    )
    multi = _two_figures(
        wrong_pair_shape(m=4, seed=seed), 0, 0, "4-member group, one Fp-dependent pair"
    )
    removed = _two_figures(
        wrong_pair_shape(m=1, seed=seed, shape="none"), 2 * N, 2 * N, "singleton, pair removed"
    )
    return {
        "what": "the condition that carries privacy is the SHAPE of the pair's "
        "weights, (cm, cm*U), not merely cm != 0",
        "singleton_fp_dependent": single,
        "multi_member_fp_dependent": multi,
        "singleton_pair_removed": removed,
        "cm_is_nonzero_throughout": True,
        "singleton_discloses_one_message_width": single["dense_disclosed_fp"] == N,
        "removing_the_pair_discloses_two": removed["dense_disclosed_fp"] == 2 * N,
        "the_other_members_cover_the_loss": multi["dense_disclosed_fp"] == 0,
        "ok": single["as_expected"] and multi["as_expected"] and removed["as_expected"],
    }


def case_e_zero_lambda(ms=(3, 5), seeds=(1, 2, 3)):
    """(e) lambda_c = 0 on one member: nothing is disclosed."""
    runs = []
    for m in ms:
        for s in seeds:
            v = multi_member(m=m, seed=s, zero_lambda=0)
            r = _two_figures(v, 0, 0, f"m={m}, seed={s}, lambda_0 = 0")
            r["m"] = m
            r["seed"] = s
            r["lambda_0_is_zero"] = v.lambdas[0][0] == F2_ZERO
            runs.append(r)
    return {
        "what": "lambda_c = 0 is a SOUNDNESS refusal (it stops a claim being "
        "discarded from the batch), not a privacy condition",
        "runs": runs,
        "all_zero": all(r["dense_disclosed_fp"] == 0 for r in runs),
        "all_agree": all(r["agree"] for r in runs),
        "ok": all(r["as_expected"] for r in runs),
    }


def case_f_beyond_the_pad_budget(seeds=(1, 2, 3)):
    """(f) one opened position more than pads: the dense rank sees it, the
    reduction does not -- so the reduction now REFUSES."""
    runs = []
    for s in seeds:
        v = beyond_the_pad_budget(m=3, seed=s, q_pad=4, extra=1)
        # the prediction is a SIGN, not a value: the leaked functional is one
        # per data row and the toy has three, but the point is only that the
        # dense rank is positive where the reduction's is not
        r = _two_figures(v, "> 0", "refused", f"seed={s}")
        r["seed"] = s
        r["as_expected"] = (
            r["reduction_refused"]
            and r["dense_disclosed_fp"] > 0
            and r["reduction_disclosed_fp_unguarded"] == 0
        )
        runs.append(r)
    inside = _two_figures(
        beyond_the_pad_budget(m=3, seed=1, q_pad=4, extra=0), 0, 0, "exactly at the budget"
    )
    return {
        "what": "the message-half reduction is valid only inside the pad "
        "budget; beyond it the reduction answers 0 and the truth is not 0",
        "runs": runs,
        "at_the_budget": inside,
        "the_reduction_misses_it": all(
            r["reduction_disclosed_fp_unguarded"] == 0 and r["dense_disclosed_fp"] > 0
            for r in runs
        ),
        "the_guard_refuses_it": all(r["reduction_refused"] for r in runs),
        "the_guard_is_silent_inside_the_budget": not inside["reduction_refused"],
        "guard_condition": "distinct_opened_positions > pad_count, the same "
        "condition as zk60_native_jv_pcs.RoleView._check_pad_budget "
        "(fact `distinct_opened_columns_within_pad_count`)",
        "ok": all(r["as_expected"] for r in runs) and inside["as_expected"],
    }


def run_cases():
    """All six, as one record."""
    out = {
        "what": "R-8: the gate's small model, extended with real opening groups",
        "model": "synthetic and public; data and blinding both known; no "
        "receipt, capture or Rust source is read",
        "privacy_property_established": False,
        "message_columns": N,
        "encoded_positions": NN,
        "a_multi_member_group": case_a_multi_member(),
        "b_shared_pair": case_b_shared_pair(),
        "c_h_style_legitimate_sharing": case_c_h_style(),
        "d_wrong_pair_shape": case_d_wrong_pair_shape(),
        "e_zero_lambda": case_e_zero_lambda(),
        "f_beyond_the_pad_budget": case_f_beyond_the_pad_budget(),
    }
    out["ok"] = all(
        out[k]["ok"] for k in out if isinstance(out[k], dict) and "ok" in out[k]
    )
    return out


SUMMARY_ROWS = [
    # case, where the two figures live, what the case is
    ("a", "a_multi_member_group", "m >= 3 claims batched by lambda_c into one group"),
    ("b", "b_shared_pair", "two ordinary terminals on one reserved pair"),
    ("c", "c_h_style_legitimate_sharing", "two groups on the zero-sum pair"),
    ("d", "d_wrong_pair_shape", "base-field-dependent pair weights, cm != 0"),
    ("e", "e_zero_lambda", "lambda_c = 0 on one member"),
    ("f", "f_beyond_the_pad_budget", "one opened position beyond the pad budget"),
]


def summary(rec):
    """The six-row table: reduction against dense, expected against observed."""
    pick = {
        "a": lambda r: r["runs"][0],
        "b": lambda r: r["in_one_group"],
        "c": lambda r: r["figures"],
        "d": lambda r: r["singleton_fp_dependent"],
        "e": lambda r: r["runs"][0],
        "f": lambda r: r["runs"][0],
    }
    rows = []
    for tag, key, what in SUMMARY_ROWS:
        fig = pick[tag](rec[key])
        rows.append(
            {
                "case": tag,
                "what": what,
                "dense_disclosed_fp": fig["dense_disclosed_fp"],
                "reduction_disclosed_fp": "refused"
                if fig["reduction_refused"]
                else fig["reduction_disclosed_fp"],
                "reduction_unguarded_fp": fig["reduction_disclosed_fp_unguarded"],
                "per_group_step_figure_fp": fig["per_group_step_figure_fp"],
                "agree": fig["agree"],
                "H-pair": fig["hypotheses"]["H-pair"],
                "H-pad": fig["hypotheses"]["H-pad"],
                "groups_disjoint_off_data": fig["hypotheses"][
                    "groups_pairwise_disjoint_off_data"
                ],
                "case_ok": rec[key]["ok"],
            }
        )
    return rows


def main(argv=None):
    import argparse
    import hashlib
    import json
    import os
    import time

    ap = argparse.ArgumentParser(description="R-8: the small model with groups")
    ap.add_argument("--evidence", required=True)
    args = ap.parse_args(argv)

    t0 = time.time()
    cases = run_cases()
    here = os.path.dirname(os.path.abspath(__file__))
    tools = {}
    for t in ("zk60_native_jv_groups.py", "zk60_native_jv_smallmodel.py",
              "zk60_native_jv_field.py"):
        with open(os.path.join(here, t), "rb") as fh:
            tools[t] = hashlib.sha256(fh.read()).hexdigest()
    rec = {
        "gate": "zk60-native-small-model-groups",
        "review_change": "R-8 (ZK60_TERMINAL_SURJECTION_REVIEW.md section 5), "
        "accepted in ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md",
        "privacy_property_established": False,
        "privacy_review_complete": False,
        "tool_sha256": tools,
        "summary": summary(cases),
        "cases": cases,
        "ok": cases["ok"],
    }
    os.makedirs(args.evidence, exist_ok=True)
    out = os.path.join(args.evidence, "small_model_groups.json")
    with open(out, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(args.evidence, "small_model_groups.done"), "w") as fh:
        fh.write("0\n" if rec["ok"] else "1\n")
    for row in rec["summary"]:
        print(
            f"{row['case']}: dense {row['dense_disclosed_fp']}, "
            f"reduction {row['reduction_disclosed_fp']}, "
            f"per-group {row['per_group_step_figure_fp']}, "
            f"{'ok' if row['case_ok'] else 'FAIL'}"
        )
    print(f"record: {out} ({round(time.time() - t0, 1)} s)")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

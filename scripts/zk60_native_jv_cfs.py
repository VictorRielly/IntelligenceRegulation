"""Stages 3 and 4: the joint masking-commitment (CFS / M) view, and the
three systems stacked.

MODEL.  Slot s runs a sumcheck of N_s = main + extension rounds and degree
d_s over a CFS masking polynomial g_s with L_s = N_s d_s + 2 uniform Fp2
coefficients (zkp-core/src/sumcheck.rs::CfsMask).  What the receipt publishes
for that slot is

    masked_round_j = honest_round_j + c_s * g_s.round(j, rho_<j)      (N_s vectors
                                                                   of d_s+1 Fp2)

with c_s and rho the challenges stage 1 re-derived, plus the slot's terminals
and the derived mask evaluation.  The M commitment then opens, ONCE, a set of
published linear functionals of the mask coefficients (`mask.functionals` in
the capture: weights per slot, and a value).

The hidden data of this channel is the HONEST round messages.  They live in
the consistency subspace C_s of the published-round space,
dim_Fp2 C_s = N_s d_s + 1 (each round after the first is pinned by
s_j(0) + s_j(1) = interpolate(s_{j-1}, rho_{j-1})).  Writing R_s for the
Fp2-linear map coefficients -> the N_s round vectors of g_s and F_s for the
published functionals,

    disclosed_s = (dim C_s - rank R_s) + dim( rowspace(R_s) ∩ rowspace(F_s) )

- the first term is the part of the honest rounds the mask does not cover,
  the second is the part of a published functional that the rounds already
  determine, and therefore reveals the same combination of the honest rounds.

THE M OPENING itself (q, the proximity vector, the 256 sampled columns) is
handled by three source facts, each CHECKED here on the capture:

  M-q     q = sum_s p_{a_s} p_{W_s} + p_b with b uniform on 2*512
          coefficients subject to b[512] = -b[0] (zk.rs::mask_commit), so the
          b rows mask every coefficient of q except the ONE Fp2 functional
          q[0] + q[512], which is the public combined value
          512 (q[0] + q[512]) = sum_i theta^i value_i.  That functional is
          the theta-combination of the published F values and adds nothing.
  M-prox  the proximity vector is  u + sum_row r_row p_row  with u uniform on
          2*512 coefficients and coefficient 1, so it is perfectly masked.
  M-cols  each a-row's message is (its L_s coefficients, MASK_Q = 256 pads,
          zeros).  The d DISTINCT sampled columns give d Lagrange functionals
          per row; their restriction to the 256 pad positions is a Cauchy
          matrix in distinct nodes, hence of rank d <= 256, so the columns are
          absorbed by the pads.  The b and u rows' column values are
          determined by q, the proximity vector and the a rows (they are the
          verifier's own two column identities), so they add nothing.

STACKING (stage 4).  A, H, the two endpoints and M draw their pads, mask
rows and mask coefficients as disjoint parts of one prover randomness
vector.  A functional supported on data coordinates that is a sum of
functionals of several channels must therefore have each channel's part
separately supported on data coordinates, so the joint disclosed space is
the SUM of the per-channel disclosed spaces (equality unless two channels
disclose the same functional under data aliasing, which can only lower it).

BOUNDARY, carried into the report: the terminal identity
fin - c_s g_s(rho) = poly(terminals) links this channel to the commitment
channel NONLINEARLY (poly has degree up to 4 in the terminals).  A linear
model cannot see that link; nothing here rules out a nonlinear functional
of the joint view.
"""

from __future__ import annotations

from zk60_native_jv_capture import MASK_LOG_DOM, MASK_LOG_MSG, MASK_Q
from zk60_native_jv_field import (
    F2_ONE,
    F2_ZERO,
    P,
    f2_add,
    f2_from_list,
    f2_inv,
    f2_is_zero,
    f2_mul,
    f2_mul_base,
    f2_sub,
    inv,
    rank,
    two_adic_root,
)


# ------------------------------------------------------ Fp2 linear algebra
def rank2(rows, ncols=None):
    return len(rref2(rows, ncols)[0])


def rref2(rows, ncols=None):
    mat = [list(r) for r in rows]
    if not mat:
        return [], []
    ncols = ncols if ncols is not None else len(mat[0])
    pivots, r = [], 0
    for c in range(ncols):
        piv = None
        for i in range(r, len(mat)):
            if not f2_is_zero(mat[i][c]):
                piv = i
                break
        if piv is None:
            continue
        mat[r], mat[piv] = mat[piv], mat[r]
        pinv = f2_inv(mat[r][c])
        mat[r] = [f2_mul(x, pinv) for x in mat[r]]
        for i in range(len(mat)):
            if i != r and not f2_is_zero(mat[i][c]):
                f = mat[i][c]
                mat[i] = [f2_sub(a, f2_mul(f, b)) for a, b in zip(mat[i], mat[r])]
        pivots.append(c)
        r += 1
        if r == len(mat):
            break
    return mat[:r], pivots


def reduce2(vec, basis, pivots):
    out = list(vec)
    for row, pc in zip(basis, pivots):
        if not f2_is_zero(out[pc]):
            f = out[pc]
            out = [f2_sub(a, f2_mul(f, b)) for a, b in zip(out, row)]
    return out


# The order the M functionals are declared in, taken from the code and not
# from an earlier memo (private_block/argument.rs:361-376 and 924-925; the
# attention profile's argument.rs says the same).  `zk60_native_mask_commit.
# declared_functional_order` checks it against every capture, position by
# position, value by value and weight by weight.
M_DECLARED_ORDER = (
    "for each slot s in slot order: [Gamma_s, if slot s is Standalone] then "
    "eval_s; then every Host slot's Gamma, in slot order, last"
)


# ------------------------------------------------------------- CfsMask ops
def mask_len(n_vars, degree):
    return n_vars * degree + 2


def mask_round_matrix(n_vars, degree, rho):
    """The Fp2 matrix of  coefficients -> the N round vectors of g, at rho.

    Rows are indexed (j, x) for round j and evaluation point x = 0..degree;
    columns are the L mask coefficients.  Ported from CfsMask::round.
    """
    L = mask_len(n_vars, degree)
    half = inv(2)
    rows = []
    for j in range(n_vars):
        prod_prev = F2_ONE
        for r in rho[:j]:
            prod_prev = f2_mul(prod_prev, r)
        scale = (pow(2, n_vars - 1 - j) % P, 0)
        # base as a functional of the coefficients
        base = [F2_ZERO] * L
        base[0] = F2_ONE
        for i, r in enumerate(rho[:j]):
            xp = F2_ONE
            for e in range(1, degree + 1):
                xp = f2_mul(xp, r)
                base[2 + i * degree + (e - 1)] = f2_add(base[2 + i * degree + (e - 1)], xp)
        for i in range(j + 1, n_vars):
            for e in range(1, degree + 1):
                base[2 + i * degree + (e - 1)] = f2_add(
                    base[2 + i * degree + (e - 1)], (half, 0)
                )
        for x in range(degree + 1):
            xv = (x % P, 0)
            row = [f2_mul(scale, b) for b in base]
            xp = F2_ONE
            for e in range(1, degree + 1):
                xp = f2_mul(xp, xv)
                k = 2 + j * degree + (e - 1)
                row[k] = f2_add(row[k], f2_mul(scale, xp))
            row[1] = f2_add(row[1], f2_mul(prod_prev, xv))
            rows.append(row)
    return rows


def lagrange_eval_weights(degree, r):
    """interpolate_eval: the weights w with sum_x w[x] s(x) = s(r), x = 0..degree."""
    w = []
    for i in range(degree + 1):
        num, den = F2_ONE, 1
        for jx in range(degree + 1):
            if jx == i:
                continue
            num = f2_mul(num, f2_sub(r, (jx % P, 0)))
            den = den * ((i - jx) % P) % P
        w.append(f2_mul_base(num, inv(den)))
    return w


# ------------------------------- the derived mask evaluation (report §3.1)
# The verifier NEVER observes a slot's mask evaluation: it COMPUTES it, as
#     g_val = (fin - poly(vals)) * c^-1           (argument.rs, both profiles)
# i.e. the final check  fin_s = c_s * mask_eval_s + poly_s(terminals_s)
# solved for mask_eval_s.  The functions below make that a CHECKED fact of
# every slot of every capture instead of a paragraph.
#
# WHAT THE CAPTURE ALLOWS, exactly.  `native_capture.rs` writes the field
# `terminal_polynomial` as `fin.sub(c.mul(mask_eval))` -- the ALREADY
# EVALUATED value of poly_s, not its inputs.  The slot's composition
# polynomial `def.poly` is a Rust closure (`Poly = Box<dyn Fn(&[Fp2]) ->
# Fp2>`, argument.rs) and is NOT in the capture, so `poly_s(terminals_s)`
# cannot be recomputed here from the terminals: the STRONG form of the check
# is unavailable (report §3.1 says which field would restore it).  What IS
# recomputed, and therefore what the assertion rests on:
#   * `claimed_sum_s` from the published scalars and the hosted coefficients;
#   * every round's own check  s_j(0) + s_j(1) == claim_j  (sumcheck.rs);
#   * `fin_s` itself, by iterated `interpolate_eval` at the REPLAYED round
#     challenges -- compared with the capture's `sumcheck_final`;
#   * `c_s`, the replayed mask challenge, checked nonzero (the verifier
#     refuses c = 0: private_block/argument.rs:275,
#     private_attention/argument.rs:261);
#   * the identity  mask_eval_s == (fin_s - terminal_polynomial_s) / c_s;
#   * and, independently of all that, that every published terminal is
#     REPUBLISHED as the value of the PCS claim the slot's private table
#     names (`build_claim(..., value = terms[k])`, argument.rs:223) -- the
#     link that makes a perturbed terminal detectable here at all.
def sumcheck_final(rounds, degree, rho, claimed):
    """zkp-core/src/sumcheck.rs::verify, without the transcript: the final
    claim from the published rounds, plus whether every round's own
    s(0) + s(1) == claim check holds."""
    claim = claimed
    consistent = True
    for j, rnd in enumerate(rounds):
        vals = [f2_from_list(v) for v in rnd]
        if len(vals) != degree + 1:
            return None, False
        if f2_add(vals[0], vals[1]) != claim:
            consistent = False
        w = lagrange_eval_weights(degree, rho[j])
        acc = F2_ZERO
        for x in range(degree + 1):
            acc = f2_add(acc, f2_mul(w[x], vals[x]))
        claim = acc
    return claim, consistent


def terminal_identity(capture, replay):
    """Per slot: the derived-mask-evaluation identity, and the terminals'
    republication as PCS claim values.  Every count is a count of slots (or
    of terminals) that PASS; a FAILURE is reported in `findings`."""
    facts = {
        "slots": len(capture.slots),
        "claimed_sum_recomputed": 0,
        "round_consistency_holds": 0,
        "final_matches_the_capture": 0,
        "mask_challenge_nonzero": 0,
        "derived_mask_evaluation_identity": 0,
        "terminals": 0,
        "terminals_republished_as_claim_values": 0,
        "strong_form_available": False,
        "strong_form_missing_input": (
            "the slot's composition polynomial def.poly (a Rust closure); the "
            "capture holds terminal_polynomial only as fin - c*mask_eval"
        ),
        "findings": [],
    }
    scalars = [f2_from_list(a["scalar"]) for a in capture.slots]
    tables = {"eq": 0, "public": 0, "private": 0, "public_tables_of_full_length": 0}
    for arg in capture.slots:
        s = arg["slot"]
        degree = arg["degree"]
        claimed = scalars[s]
        for h in arg["hosted"]:
            claimed = f2_add(claimed, f2_mul(f2_from_list(h["coefficient"]), scalars[h["slot"]]))
        if claimed == f2_from_list(arg["claimed_sum"]):
            facts["claimed_sum_recomputed"] += 1
        else:
            facts["findings"].append(f"slot {s}: claimed sum differs from scalar + hosted")
        fin, consistent = sumcheck_final(arg["rounds"], degree, replay.rho[s], claimed)
        if consistent:
            facts["round_consistency_holds"] += 1
        else:
            facts["findings"].append(f"slot {s}: a round message fails s(0) + s(1) == claim")
        if fin is not None and fin == f2_from_list(arg["sumcheck_final"]):
            facts["final_matches_the_capture"] += 1
        else:
            facts["findings"].append(f"slot {s}: the recomputed sumcheck final differs")
        c = replay.slot_c.get(s, f2_from_list(arg["c"]))
        if f2_is_zero(c):
            facts["findings"].append(f"slot {s}: zero mask challenge (the verifier refuses it)")
        else:
            facts["mask_challenge_nonzero"] += 1
            derived = f2_mul(f2_sub(fin, f2_from_list(arg["terminal_polynomial"])), f2_inv(c))
            if derived == f2_from_list(arg["mask_eval"]):
                facts["derived_mask_evaluation_identity"] += 1
            else:
                facts["findings"].append(
                    f"slot {s}: mask_eval != (fin - terminal_polynomial) / c"
                )
        k = 0
        for t in arg["tables"]:
            tables[t["kind"]] += 1
            if t["kind"] == "public" and len(t["values"]) == 1 << arg["main"]:
                tables["public_tables_of_full_length"] += 1
            if t["kind"] != "private":
                continue
            facts["terminals"] += 1
            claim = capture.role(t["role"])["claims"][t["claim"]]
            if k < len(arg["terminals"]) and f2_from_list(claim["value"]) == f2_from_list(
                arg["terminals"][k]
            ):
                facts["terminals_republished_as_claim_values"] += 1
            else:
                facts["findings"].append(
                    f"slot {s} terminal {k}: not the value of the PCS claim it names"
                )
            k += 1
        if k != len(arg["terminals"]):
            facts["findings"].append(
                f"slot {s}: {k} private tables for {len(arg['terminals'])} terminals"
            )
    facts["tables"] = tables
    facts["ok"] = (
        not facts["findings"]
        and facts["derived_mask_evaluation_identity"] == facts["slots"]
        and facts["terminals_republished_as_claim_values"] == facts["terminals"]
    )
    return facts


def terminal_identity_controls(capture, replay, slot=0, replay_check=False):
    """Negative controls for the identity above.  Each perturbs ONE published
    field of one slot by one and re-runs the check; the perturbation is undone
    before returning.  The terminal perturbation is the interesting one: the
    per-slot mask-evaluation identity CANNOT see it (the capture stores the
    already-evaluated terminal polynomial), while the terminal's republication
    as a PCS claim value and the transcript replay both do."""
    arg = capture.slots[slot]
    out = {"slot": slot}

    def fires():
        return not terminal_identity(capture, replay)["ok"]

    for name, key, index in (
        ("last_round_coefficient", "rounds", -1),
        ("mask_eval", "mask_eval", None),
        ("terminal_polynomial", "terminal_polynomial", None),
    ):
        if index is None:
            arg[key][0] = (arg[key][0] + 1) % P
            out[name] = fires()
            arg[key][0] = (arg[key][0] - 1) % P
        else:
            arg[key][index][0][0] = (arg[key][index][0][0] + 1) % P
            out[name] = fires()
            arg[key][index][0][0] = (arg[key][index][0][0] - 1) % P

    arg["terminals"][0][0] = (arg["terminals"][0][0] + 1) % P
    facts = terminal_identity(capture, replay)
    out["terminal_mask_evaluation_identity"] = (
        facts["derived_mask_evaluation_identity"] != facts["slots"]
    )
    out["terminal_claim_value_cross_check"] = (
        facts["terminals_republished_as_claim_values"] != facts["terminals"]
    )
    if replay_check:
        from zk60_native_jv_replay import Replay

        out["terminal_transcript_replay"] = not Replay(capture).run().summary()["ok"]
    arg["terminals"][0][0] = (arg["terminals"][0][0] - 1) % P
    out["honest_again"] = terminal_identity(capture, replay)["ok"]
    out["ok"] = (
        out["last_round_coefficient"]
        and out["mask_eval"]
        and out["terminal_polynomial"]
        and out["terminal_claim_value_cross_check"]
        and out["honest_again"]
        and (not replay_check or out["terminal_transcript_replay"])
    )
    return out


def consistency_dim(n_vars, degree):
    return n_vars * degree + 1


def consistency_constraints(n_vars, degree, rho):
    """The N-1 functionals that cut the consistency subspace out of the
    published round space (coordinates (j, x))."""
    width = n_vars * (degree + 1)
    out = []
    for j in range(1, n_vars):
        row = [F2_ZERO] * width
        row[j * (degree + 1) + 0] = F2_ONE
        row[j * (degree + 1) + 1] = F2_ONE
        w = lagrange_eval_weights(degree, rho[j - 1])
        for x in range(degree + 1):
            k = (j - 1) * (degree + 1) + x
            row[k] = f2_sub(row[k], w[x])
        out.append(row)
    return out


# ---------------------------------------------------------------- analysis
class CfsView:
    def __init__(self, capture, replay):
        self.cap = capture
        self.rp = replay
        self.findings = []

    def fail(self, what):
        self.findings.append(what)

    def run(self):
        cap, rp = self.cap, self.rp
        specs = [tuple(s) for s in cap.mask["specs"]]
        slots = cap.slots
        facts = {"slots": len(slots), "functionals": len(cap.mask["functionals"])}
        per_slot = []
        bases, pivots, offsets, total = [], [], [], 0
        uncovered = 0
        for s, (n_vars, degree) in enumerate(specs):
            arg = slots[s]
            if (arg["main"] + arg["extension"], arg["degree"]) != (n_vars, degree):
                self.fail(f"slot {s}: capture geometry differs from the mask spec")
            rho = rp.rho[s]
            R = mask_round_matrix(n_vars, degree, rho)
            L = mask_len(n_vars, degree)
            # the round functionals live in the coefficient space: rank R
            basis, piv = rref2(R, L)
            rr = len(basis)
            dimC = consistency_dim(n_vars, degree)
            # sanity: the mask's own rounds must satisfy the consistency relations
            cons = consistency_constraints(n_vars, degree, rho)
            bad = 0
            for cst in cons:
                for k in range(L):
                    acc = F2_ZERO
                    for idx, coef in enumerate(cst):
                        if not f2_is_zero(coef):
                            acc = f2_add(acc, f2_mul(coef, R[idx][k]))
                    if not f2_is_zero(acc):
                        bad += 1
                        break
            if bad:
                self.fail(f"slot {s}: the mask's rounds leave the consistency subspace")
            per_slot.append(
                {
                    "slot": s,
                    "n_vars": n_vars,
                    "degree": degree,
                    "L": L,
                    "dim_C": dimC,
                    "rank_R": rr,
                    "uncovered": dimC - rr,
                }
            )
            uncovered += dimC - rr
            bases.append(basis)
            pivots.append(piv)
            offsets.append(total)
            total += L
        facts["per_slot"] = per_slot
        facts["coefficients_total"] = total
        facts["uncovered_consistency_directions"] = uncovered

        # the published functionals, as vectors over all slots' coefficients
        fvecs = []
        for f in cap.mask["functionals"]:
            v = [F2_ZERO] * total
            for term in f["terms"]:
                s = term["slot"]
                w = [f2_from_list(x) for x in term["weights"]]
                if len(w) != mask_len(*specs[s]):
                    self.fail(f"functional: {len(w)} weights for slot {s}")
                    continue
                for k, x in enumerate(w):
                    v[offsets[s] + k] = f2_add(v[offsets[s] + k], x)
            fvecs.append(v)
        rank_F = rank2(fvecs, total)
        reduced = []
        for v in fvecs:
            out = list(v)
            for s, (n_vars, degree) in enumerate(specs):
                L = mask_len(n_vars, degree)
                blk = reduce2(out[offsets[s] : offsets[s] + L], bases[s], pivots[s])
                out[offsets[s] : offsets[s] + L] = blk
            reduced.append(out)
        rank_F_mod_R = rank2(reduced, total)
        overlap = rank_F - rank_F_mod_R
        facts["rank_F"] = rank_F
        facts["rank_F_mod_rounds"] = rank_F_mod_R
        facts["functional_round_overlap"] = overlap
        # TWO ACCOUNTINGS, both reported (see the report's stage 3):
        # (i) every derived mask evaluation counted as an observation of the
        #     mask coefficients -- the upper bound;
        # (ii) only what the M OPENING independently reveals, the single Fp2
        #     functional q[0]+q[512] = the theta-combination of the values.
        theta_vec = self._theta_combination(fvecs)
        theta_mod = list(theta_vec)
        for s, (n_vars, degree) in enumerate(specs):
            L = mask_len(n_vars, degree)
            theta_mod[offsets[s] : offsets[s] + L] = reduce2(
                theta_mod[offsets[s] : offsets[s] + L], bases[s], pivots[s]
            )
        theta_overlap = rank2([theta_vec], total) - rank2([theta_mod], total)
        facts["theta_combination_in_round_span"] = theta_overlap == 1
        facts["disclosed_all_values_fp2"] = uncovered + overlap
        facts["disclosed_all_values_fp"] = 2 * (uncovered + overlap)
        facts["disclosed_opening_only_fp2"] = uncovered + theta_overlap
        facts["disclosed_opening_only_fp"] = 2 * (uncovered + theta_overlap)

        facts.update(self._mask_opening_checks(specs))
        facts["findings"] = self.findings
        return facts

    def _theta_combination(self, fvecs):
        """sum_i theta^i F_i: the ONE Fp2 functional the q channel reveals."""
        theta = self.rp.theta
        out = [F2_ZERO] * len(fvecs[0])
        th = F2_ONE
        for v in fvecs:
            for k, x in enumerate(v):
                if not f2_is_zero(x):
                    out[k] = f2_add(out[k], f2_mul(th, x))
            th = f2_mul(th, theta)
        return out

    # --------------------------------------------------- the M opening
    def _mask_opening_checks(self, specs):
        cap, rp = self.cap, self.rp
        m = cap.mask
        out = {}
        # M-q: the public combined value.  512 (q[0] + q[512]) == sum theta^i value_i
        mm = 1 << MASK_LOG_MSG
        q0 = f2_from_list(m["q"][0])
        qm = f2_from_list(m["q"][mm])
        got = f2_mul_base(f2_add(q0, qm), mm % P)
        want, th = F2_ZERO, F2_ONE
        theta = rp.theta
        for f in m["functionals"]:
            want = f2_add(want, f2_mul(th, f2_from_list(f["value"])))
            th = f2_mul(th, theta)
        out["q_public_sum_identity"] = got == want
        if got != want:
            self.fail("M: 512*(q[0]+q[512]) != the theta-combined functional value")
        out["q_disclosed_functionals_fp2"] = 1  # exactly the identity above
        # ... and since 2026-09-20 that 1 is COMPUTED, not asserted: the port
        # of M's row layout (`zk60_native_mask_commit`, pinned to zk.rs) builds
        # the Fp matrix of the theta-batched functional over the coefficient
        # unknowns and takes its exact rank.  The P10 gate goes further and
        # exhibits preimages at two coefficient vectors on that plane; here we
        # only cross-check the figure this stage hands to stage 4.
        from zk60_native_mask_commit import MaskModel, disclosed_dimension

        mmodel = MaskModel(cap, rp)
        dd = disclosed_dimension(mmodel)
        out["m_row_layout_ported"] = True
        out["m_declared_functional_order"] = M_DECLARED_ORDER
        out["m_coefficient_unknowns_fp"] = dd["coefficient_unknowns_fp"]
        out["m_disclosed_fp_computed"] = dd["disclosed_fp_computed"]
        out["m_fibre_dimension_fp"] = dd["fibre_dimension_fp"]
        out["m_computed_matches_the_asserted_one_fp2"] = (
            dd["disclosed_fp_computed"] == 2 * out["q_disclosed_functionals_fp2"]
        )
        if not out["m_computed_matches_the_asserted_one_fp2"]:
            self.fail(
                "M: the ported row layout computes a disclosed dimension of "
                f"{dd['disclosed_fp_computed']} Fp, not the 2 this stage asserts"
            )
        # M-cols: the pad budget of the a-rows
        idx = [c["index"] for c in m["columns"]]
        distinct = sorted(set(idx))
        dom = 1 << MASK_LOG_DOM
        w_dom = two_adic_root(MASK_LOG_DOM)
        nodes = {7 * pow(w_dom, j, P) % P for j in distinct}
        zn_zero = sum(1 for y in nodes if (pow(y, mm, P) - 1) % P == 0)
        out.update(
            {
                "m_sampled_columns": len(idx),
                "m_distinct_columns": len(distinct),
                "m_pads_per_a_row": MASK_Q,
                "m_pad_margin": MASK_Q - len(distinct),
                "m_nodes_distinct": len(nodes) == len(distinct),
                "m_vanishing_Z_nodes": zn_zero,
                "m_rows": len(m["columns"][0]["values"]),
                "m_expected_rows": 2 * len(specs) + 4,
            }
        )
        if not (len(distinct) <= MASK_Q and len(nodes) == len(distinct) and zn_zero == 0):
            self.fail("M: the a-row pad budget is not met by the sampled columns")
        if out["m_rows"] != out["m_expected_rows"]:
            self.fail("M: column height differs from 2*slots + 4")
        # M-prox: the proximity combination draws one coefficient per a/b row
        out["m_proximity_rhos"] = len(m["proximity_rhos"])
        if len(m["proximity_rhos"]) != 2 * len(specs) + 2:
            self.fail("M: the proximity draw count differs from 2*slots + 2")
        out["prox_disclosed_functionals_fp2"] = 0
        return out


def m_pad_block_rank(capture, limit=None):
    """Exact rank of the a-row pad block of the M column functionals.

    Column t of an a-row message contributes the Lagrange weight L_t(y_j);
    over the 256 pad positions this is a Cauchy matrix in distinct nodes.
    """
    mm = 1 << MASK_LOG_MSG
    dom = 1 << MASK_LOG_DOM
    w_dom = two_adic_root(MASK_LOG_DOM)
    w_msg = two_adic_root(MASK_LOG_MSG)
    distinct = sorted({c["index"] for c in capture.mask["columns"]})
    if limit:
        distinct = distinct[:limit]
    minv = inv(mm)
    rows = []
    for j in distinct:
        y = 7 * pow(w_dom, j, P) % P
        z = (pow(y, mm, P) - 1) % P
        row = []
        for t in range(MASK_Q):  # any 256 consecutive message positions
            wt = pow(w_msg, t, P)
            row.append(z * minv % P * wt % P * inv((y - wt) % P) % P)
        rows.append(row)
    return rank(rows, MASK_Q), len(distinct)

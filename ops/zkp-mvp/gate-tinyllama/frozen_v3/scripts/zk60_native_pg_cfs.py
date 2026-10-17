"""P10, the masking-commitment side: the masked sumcheck rounds and scalars.

THE CHANNEL.  Slot s publishes `masked_round_j = honest_round_j + c_s *
g_s.round(j, rho_<j)` for every round, and a masked scalar `scalar_s =
honest_scalar_s + c_s * g_s.total()` (`sumcheck.rs::CfsMasker`,
`CfsMask::sum_weights`).  The HIDDEN DATA of this channel is the honest round
messages and the honest scalar; the BLINDING is the L_s = N_s d_s + 2 uniform
Fp2 coefficients of the CFS mask, which the M commitment holds.

  y            the published masked rounds and masked scalars, plus the one
               functional value the M opening independently publishes
  M_data       the identity on the honest transcript
  M_nondata    c_s * [R_s ; sum_weights], with R_s the coefficient-to-rounds
               matrix of `CfsMask::round` at the replayed challenges

WHAT THE GATE CONSTRUCTS.  For a FIXED honest transcript it solves
[R_s ; w_sum] coef_s = [(masked_s - h_s)/c_s ; (scalar_s - sigma_s)/c_s]
exactly over Fp (each Fp2 unknown split into its two Fp components), then
recomputes the published rounds and scalar from (h, coef) and compares them
with the capture entry by entry.

THE ONE CONDITION ON THE FIXED DATA.  The M opening publishes one functional
of the mask coefficients that is not derived from anything else: the
theta-combination, pinned by `512 (q[0] + q[512]) = sum_i theta^i value_i`
(`zk.rs::mask_verify`).  Stage 3 of the joint-view tool measures that this
functional lies in the round span (`theta_combination_in_round_span`), which
is exactly the statement that its value is determined by the transcript and
the honest data.  So a preimage exists only for fixed data satisfying that
ONE Fp2 identity -- disclosed dimension 2 over Fp, which is the figure stage
3 reports as `disclosed_opening_only_fp`.  The gate:

  * solves at the canonical zero transcript (h = 0, sigma = 0) and reports
    whether the theta identity then holds -- it does not, and that failure IS
    the disclosed dimension made visible;
  * projects the fixed transcript onto the identity (a public, deterministic
    correction) and exhibits the preimage there, verified entry by entry.

The UPPER-BOUND accounting -- treating all 34 published functional values as
independent observations of the coefficients rather than as values DERIVED
from the rounds and the terminals -- is reported beside it, as stage 3 does.

WHAT THE CAPTURE DOES NOT CARRY, and what it would take.  The honest
(unmasked) round messages of any slot are not in the capture, so the fixed
transcript used here is a named, publicly computable element of the
channel's data space, not the zero witness's own transcript.  The privacy
case asks for exactly this input -- "the unmasked honest round messages of
one slot on a synthetic fixture, labelled a test fixture"
(`ZK60_PRIVACY_CASE_FIRST_MVP.md` section 4.3) -- and it belongs to the
capture writer, i.e. to the integrator.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.
"""

from __future__ import annotations

from zk60_native_jv_cfs import consistency_dim, mask_len, mask_round_matrix
from zk60_native_jv_field import (
    F2_ONE,
    F2_ZERO,
    P,
    f2_add,
    f2_from_list,
    f2_is_zero,
    f2_mul,
    f2_sub,
    inv,
    solve,
)

NONRESIDUE = 7


def sum_weights(n_vars, degree):
    """CfsMask::sum_weights: 2^N on a_0, 1 on a', 2^(N-1) on every a_{j,e}."""
    L = mask_len(n_vars, degree)
    w = [((1 << (n_vars - 1)) % P, 0)] * L
    w[0] = ((1 << n_vars) % P, 0)
    w[1] = F2_ONE
    return w


def fp_columns(rows_f2, n_unknowns):
    """An Fp2 system as an Fp system: unknown k becomes (k.re, k.im).

    A row of Fp2 coefficients a_k acting on x_k = x_re + U x_im (U^2 = 7)
    contributes two Fp equations; the column of x_re is (a0, a1) and the
    column of x_im is (7 a1, a0).
    """
    cols = [[] for _ in range(2 * n_unknowns)]
    for row in rows_f2:
        for k in range(n_unknowns):
            a = row[k]
            cols[2 * k].extend([a[0], a[1]])
            cols[2 * k + 1].extend([a[1] * NONRESIDUE % P, a[0]])
    return cols


def f2_target(vals):
    out = []
    for v in vals:
        out.extend([v[0] % P, v[1] % P])
    return out


def f2_apply(row, coef):
    acc = F2_ZERO
    for a, x in zip(row, coef):
        if not f2_is_zero(a) and not f2_is_zero(x):
            acc = f2_add(acc, f2_mul(a, x))
    return acc


class CfsPreimage:
    """The mask coefficients that reproduce every slot's published rounds."""

    def __init__(self, capture, replay):
        self.cap = capture
        self.rp = replay
        self.specs = [tuple(s) for s in capture.mask["specs"]]
        self.slots = capture.slots
        self.offsets, total = [], 0
        for n, d in self.specs:
            self.offsets.append(total)
            total += mask_len(n, d)
        self.total = total
        self.R = []
        self.W = []
        for s, (n, d) in enumerate(self.specs):
            self.R.append(mask_round_matrix(n, d, replay.rho[s]))
            self.W.append(sum_weights(n, d))
        self.c = [replay.slot_c.get(s, f2_from_list(a["c"])) for s, a in enumerate(self.slots)]
        self.theta_vec = self._theta_vector()
        self.theta_value = self._theta_value()
        self.findings: list[str] = []

    # ------------------------------------------------------------- pieces
    def _functional_vectors(self):
        out = []
        for f in self.cap.mask["functionals"]:
            v = [F2_ZERO] * self.total
            for term in f["terms"]:
                s = term["slot"]
                for k, x in enumerate(term["weights"]):
                    v[self.offsets[s] + k] = f2_add(v[self.offsets[s] + k], f2_from_list(x))
            out.append((v, f2_from_list(f["value"])))
        return out

    def _theta_vector(self):
        th, out = F2_ONE, [F2_ZERO] * self.total
        for v, _ in self._functional_vectors():
            for k, x in enumerate(v):
                if not f2_is_zero(x):
                    out[k] = f2_add(out[k], f2_mul(th, x))
            th = f2_mul(th, self.rp.theta)
        return out

    def _theta_value(self):
        th, acc = F2_ONE, F2_ZERO
        for _, val in self._functional_vectors():
            acc = f2_add(acc, f2_mul(th, val))
            th = f2_mul(th, self.rp.theta)
        return acc

    def flat_transcript(self, s):
        """The canonical honest transcript of a slot whose own tables are zero.

        Its claimed sum is what the slots it HOSTS force (`argument.rs`: a
        host's claimed sum consumes the hosted slots' published scalars), and
        each round message is the constant halving of the running claim --
        one explicit element of the consistency subspace, named in the record.
        """
        arg = self.slots[s]
        deg = arg["degree"]
        claim = F2_ZERO
        for h in arg["hosted"]:
            claim = f2_add(
                claim,
                f2_mul(f2_from_list(h["coefficient"]), f2_from_list(self.slots[h["slot"]]["scalar"])),
            )
        rounds = []
        half = inv(2)
        cur = claim
        for j in range(len(arg["rounds"])):
            val = (cur[0] * half % P, cur[1] * half % P)
            rounds.append([val] * (deg + 1))
            cur = val  # interpolate_eval of a constant polynomial is that constant
        return rounds, F2_ZERO

    # -------------------------------------------------------------- solve
    def solve_slot(self, s, rounds_h, sigma):
        """coef_s with c (R coef) = masked - h and c (w . coef) = scalar - sigma."""
        arg = self.slots[s]
        L = mask_len(*self.specs[s])
        c = self.c[s]
        if f2_is_zero(c):
            return None, [], "zero mask challenge"
        ci = None
        from zk60_native_jv_field import f2_inv

        ci = f2_inv(c)
        rows, targets = [], []
        idx = 0
        for j, rnd in enumerate(arg["rounds"]):
            for x, v in enumerate(rnd):
                rows.append(self.R[s][idx])
                targets.append(f2_mul(f2_sub(f2_from_list(v), rounds_h[j][x]), ci))
                idx += 1
        rows.append(self.W[s])
        targets.append(f2_mul(f2_sub(f2_from_list(arg["scalar"]), sigma), ci))
        cols = fp_columns(rows, L)
        x, ker = solve(cols, f2_target(targets))
        if x is None:
            return None, ker, "no solution"
        coef = [(x[2 * k] % P, x[2 * k + 1] % P) for k in range(L)]
        return coef, ker, None

    def run(self, fixed="zero", perturb=None):
        """Solve every slot at the fixed transcript, then report the theta test."""
        data, coef, kers = [], [], []
        for s in range(len(self.slots)):
            h, sig = self.flat_transcript(s)
            if perturb is not None:
                h, sig = perturb(s, h, sig)
            data.append((h, sig))
            cs, ker, err = self.solve_slot(s, h, sig)
            if cs is None:
                self.findings.append(f"slot {s}: {err}")
                return None
            coef.append(cs)
            kers.append(len(ker))
        self.data, self.coef, self.kernels = data, coef, kers
        return self

    def theta_residual(self):
        acc = F2_ZERO
        for s, cs in enumerate(self.coef):
            off = self.offsets[s]
            acc = f2_add(acc, f2_apply(self.theta_vec[off : off + len(cs)], cs))
        return f2_sub(self.theta_value, acc)

    def project(self, which="all"):
        """Move the fixed transcript onto the identities the M opening pins.

        A change of the mask coefficients by delta moves the fixed transcript
        by (-c R delta, -c w.delta), so the set of fixed transcripts with a
        preimage is exactly the image of {delta : F delta = residual}.  The
        gate solves that system exactly and applies the solution.

        `which = "all"` (the conservative default) requires every one of the
        34 published functional values -- treating each DERIVED mask
        evaluation as if it were an independent observation of the
        coefficients, which is stage 3's upper-bound accounting.
        `which = "theta"` requires only the combination the M opening really
        pins, `512 (q[0] + q[512]) = sum_i theta^i value_i`, which is stage
        3's opening-only accounting.
        """
        fs = self._functional_vectors()
        if which == "theta":
            fs = [(self.theta_vec, self.theta_value)]
        rows, targets = [], []
        for v, val in fs:
            acc = F2_ZERO
            for s, cs in enumerate(self.coef):
                off = self.offsets[s]
                acc = f2_add(acc, f2_apply(v[off : off + len(cs)], cs))
            rows.append(v)
            targets.append(f2_sub(val, acc))
        before = sum(1 for t in targets if not f2_is_zero(t))
        if before == 0:
            return {"which": which, "conditions": len(fs), "unmet_before": 0,
                    "needed": False, "applied": True}
        cols = fp_columns(rows, self.total)
        x, ker = solve(cols, f2_target(targets))
        if x is None:
            self.findings.append(f"the fixed transcript cannot be projected ({which})")
            return {"which": which, "conditions": len(fs), "unmet_before": before,
                    "needed": True, "applied": False}
        delta = [(x[2 * k] % P, x[2 * k + 1] % P) for k in range(self.total)]
        for s in range(len(self.slots)):
            off, L = self.offsets[s], len(self.coef[s])
            ds = delta[off : off + L]
            if all(f2_is_zero(v) for v in ds):
                continue
            self.coef[s] = [f2_add(a, b) for a, b in zip(self.coef[s], ds)]
            h, sig = self.data[s]
            idx, newh = 0, []
            for rnd in h:
                row = []
                for x_ in range(len(rnd)):
                    row.append(f2_sub(rnd[x_], f2_mul(self.c[s], f2_apply(self.R[s][idx], ds))))
                    idx += 1
                newh.append(row)
            self.data[s] = (newh, f2_sub(sig, f2_mul(self.c[s], f2_apply(self.W[s], ds))))
        return {
            "which": which,
            "conditions": len(fs),
            "unmet_before": before,
            "needed": True,
            "applied": True,
            # the number of Fp conditions the fixed transcript must satisfy for
            # a preimage to exist at all: the rank of the functional system
            "conditions_on_the_fixed_transcript_fp": 2 * self.total - len(ker),
        }

    # --------------------------------------------------------- verification
    def verify(self):
        """Recompute every published masked round and scalar, entry by entry."""
        out = {"round_entries": 0, "round_mismatches": 0, "scalars": 0,
               "scalar_mismatches": 0}
        for s, arg in enumerate(self.slots):
            h, sig = self.data[s]
            coef = self.coef[s]
            idx = 0
            for j, rnd in enumerate(arg["rounds"]):
                for x, v in enumerate(rnd):
                    got = f2_add(h[j][x], f2_mul(self.c[s], f2_apply(self.R[s][idx], coef)))
                    out["round_entries"] += 1
                    if got != f2_from_list(v):
                        out["round_mismatches"] += 1
                    idx += 1
            got = f2_add(sig, f2_mul(self.c[s], f2_apply(self.W[s], coef)))
            out["scalars"] += 1
            if got != f2_from_list(arg["scalar"]):
                out["scalar_mismatches"] += 1
        out["theta_identity_holds"] = f2_is_zero(self.theta_residual())
        out["all_entries_equal"] = (
            out["round_mismatches"] == 0
            and out["scalar_mismatches"] == 0
            and out["theta_identity_holds"]
        )
        return out

    def functional_values(self):
        """The 34 published values, recomputed from the solved coefficients."""
        bad = 0
        for v, val in self._functional_vectors():
            acc = F2_ZERO
            for s, cs in enumerate(self.coef):
                off = self.offsets[s]
                acc = f2_add(acc, f2_apply(v[off : off + len(cs)], cs))
            if acc != val:
                bad += 1
        return {"functionals": len(self.cap.mask["functionals"]), "mismatches": bad}

    def fibre_dimension(self):
        per = [
            {"slot": s, "L_fp2": mask_len(*self.specs[s]),
             "dim_C_fp2": consistency_dim(*self.specs[s]),
             "free_fp": self.kernels[s]}
            for s in range(len(self.slots))
        ]
        return {
            "blinding_unknowns_fp": 2 * self.total,
            "fibre_dimension_fp": sum(self.kernels),
            "per_slot": per,
            "independent_of_the_fixed_input": True,
            "why": "R_s and the sum weights are functions of the replayed challenges "
            "and the slot geometry only; the fixed transcript enters the right-hand "
            "side alone",
        }

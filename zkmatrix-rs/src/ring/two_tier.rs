// [UPERF3-FF] Spike S4: the sqrt (two-tier / Greyhound-shape) front
// end for the group opening — U_PERF3_HEADLINE_ROUTES.md Section 4.2,
// built VERBATIM behind the `uperf-t` selector. NOTHING in this module
// is called by any shipped path; the frozen pass (bg_prove_group /
// bg_verify_group, eval_proof.rs — READ-ONLY reuse) is the ORACLE.
//
// SHAPE (memo 2.1/4.2): view the group's n_0 digit rings as a
// two-tier grid; commit each row group under an inner Ajtai
// commitment (the EXISTING expand_level_matrix / matvec machinery);
// draw the challenge fold w = sum_i c_i row_i from the transcript;
// feed the EXISTING recursion (plan_schedule + the group prove path)
// the sqrt-sized folded relation. The differential leg is the point:
// at fixed seeds the evaluation claims this front end serves must
// EQUAL the built opening's claim values (the per-tensor MLE
// evaluations at the batched point, the b_row images).
//
// Rungs (lane FF, PROGRESS_UPERF3.md "Agent FF status"):
//   1. planner  — two-tier sizing + per-tier exact-digit gates at
//                 2^20/22/23 and the 8B group shapes (no proving).
//   2. differential — synthetic group at 2^20, both ways, claims
//                 bit-for-bit (STOP + record divergence if not).
//   3. scale    — 2^22-2^23 synthetic + the real 12x512 act group;
//                 fold wall 1T/8T, prove-group-equivalent, verifier
//                 1T, bytes.

use super::digits::{gamma_max_exact, OP_CONC};
use super::eval_proof::{adaptive_base_opt, plan_schedule, EvalSchedule, KAPPA_AGG};
use super::D;

// ---------------------------------------------------------------------------
// Rung 1 — THE PLANNER (design-in-code; no proving).
//
// The two-tier object map, per group of n0 digit rings at level-0
// base e0 (memo 2.1 shape, counted here honestly):
//
//   grid   : G row groups x S rings (S*G >= n0, zero-padded).
//   tier 1 : per row group i, the inner Ajtai commitment
//            u_i = A_tt * w_row_i, A_tt = kappa x S seed-expanded
//            (the EXISTING expand_level_matrix machinery; kappa =
//            KAPPA_AGG = 11). Total commit matvec volume =
//            kappa * n0 ring-MACs — the same class as today's
//            level-0 A matvec (the memo's "commit is UNCHANGED").
//   tier 2 : the u_i are NOT sent (G*kappa rings would be MBs); their
//            digit rings (l_t limbs at e_next, full mod-q values)
//            form the tier-2 witness n2 = G*kappa*l_t rings, bound by
//            the outer commitment U = B_tt * u-digits (kappa rings on
//            the wire) — the existing u0-binding shape.
//   fold   : G quinary transcript challenges; w = sum_i c_i row_i
//            (ONE weighted pass over the n0 rings). Honest coeff
//            bound = the house concentration bound at r = G; l_z
//            limbs at e_next.
//   feed   : the EXISTING recursion (plan_schedule + the bg group
//            prove path) takes the sqrt-sized relation. Two variants
//            counted side by side:
//              V-clear   (the spike build): w is SENT (S rings, 4B/
//                coord) and publicly digit-checked; the recursion
//                witness is the tier-2 u-digits only (n2 rings) —
//                bindings: U-binding + the fold binding
//                sum_i c_i u_i = A_tt w (public target, kappa rows).
//              V-recursed (the production shape the memo prices): w's
//                digits ride the recursion too — witness n_w + n2.
//
// Exact-digit gates (row H-gate-ed semantics, the W-3 dissolution
// made a counted row): gamma = OP_CONC * 2^(e-1) * sqrt(n*D) <=
// gamma_max_exact(q), per OPENED object — per row group (S at e0),
// the folded row (n_w at e_next), the tier-2 witness (n2 at e_next)
// — vs the built single-tier gate at (n0, e0) printed for contrast.

/// Balanced-digit limb count covering [-b, b] at base e.
/// (eval_proof::limbs_for_bound is private to the frozen module —
/// the formula is reproduced VERBATIM; differential-checked against
/// the frozen planner through `plan_schedule` reuse below.)
fn limbs_for_bound(bound: i128, e: u32) -> usize {
    let mut l = 1usize;
    loop {
        let (lo, hi) = super::digits::representable(e, l);
        if lo <= -bound && bound <= hi {
            return l;
        }
        l += 1;
        assert!(l <= 64, "limb derivation diverged");
    }
}

/// Concentration inf-bound of one G-way fold coefficient (house
/// TAIL = 1.3, quinary E[c^2] = 2, digit E[d^2] = (2/3)*4^(e-1), +2
/// bits restart headroom) — eval_proof::fold_coeff_bound reproduced
/// VERBATIM at r = G.
fn fold_coeff_bound(r: usize, e_in: u32) -> i128 {
    let var = 2.0 * (r as f64) * (D as f64) * (2.0 / 3.0) * 4f64.powi(e_in as i32 - 1);
    let conc = 1.3 * var.sqrt();
    let bits = conc.log2().ceil() as u32 + 2;
    1i128 << bits.min(62)
}

/// Exact-digit-gate headroom in bits of an opened object of n rings
/// at base e (>= 0 green; the frozen gate is `gamma <= gamma_max`).
pub fn gate_headroom_bits(n_rings: usize, e: u32, q: u64) -> f64 {
    let gamma = OP_CONC * 2f64.powi(e as i32 - 1) * ((n_rings * D) as f64).sqrt();
    gamma_max_exact(q).log2() - gamma.log2()
}

#[derive(Clone, Debug)]
pub struct TwoTierPlan {
    pub n0: usize,
    pub e0: u32,
    pub s: usize,
    pub g: usize,
    pub e_next: u32,
    pub l_z: usize,
    pub l_t: usize,
    /// folded-row witness rings (S * l_z) — V-recursed only.
    pub n_w: usize,
    /// tier-2 witness rings (G * KAPPA_AGG * l_t).
    pub n2: usize,
    /// recursion input rings: V-clear = n2; V-recursed = n_w + n2.
    pub n_rec_clear: usize,
    pub n_rec_full: usize,
    /// gate headrooms (bits; >= 0 green).
    pub head_single: f64,
    pub head_rowgroup: f64,
    pub head_w: f64,
    pub head_u: f64,
    /// clear-w wire bytes (S * D * 4B) — the spike variant's cost.
    pub w_clear_bytes: usize,
}

impl TwoTierPlan {
    pub fn gate_green(&self) -> bool {
        self.head_rowgroup >= 0.0 && self.head_w >= 0.0 && self.head_u >= 0.0
    }
}

/// The two-tier plan at a given inner width S (rings per row group).
/// e_next fixed-point mirrors the frozen `plan_level` exactly, with
/// n_pairs = 0 (the pair cross-garbage is what two-tier removes) and
/// the V-recursed witness as the sizing object.
pub fn plan_two_tier_at(n0: usize, e0: u32, q: u64, s: usize) -> Option<TwoTierPlan> {
    let g = n0.div_ceil(s);
    let mut e_next = 2u32;
    for _ in 0..8 {
        let l_z = limbs_for_bound(fold_coeff_bound(g, e0), e_next);
        let l_t = limbs_for_bound((q as i128 - 1) / 2, e_next);
        let n_w = s * l_z;
        let n2 = g * KAPPA_AGG * l_t;
        let n_out = n_w + n2;
        let e_ok = adaptive_base_opt(n_out, q)?;
        if e_ok < 2 {
            return None;
        }
        if e_ok <= e_next {
            let e_final = e_next.min(e_ok);
            let l_z = limbs_for_bound(fold_coeff_bound(g, e0), e_final);
            let l_t = limbs_for_bound((q as i128 - 1) / 2, e_final);
            let n_w = s * l_z;
            let n2 = g * KAPPA_AGG * l_t;
            return Some(TwoTierPlan {
                n0,
                e0,
                s,
                g,
                e_next: e_final,
                l_z,
                l_t,
                n_w,
                n2,
                n_rec_clear: n2,
                n_rec_full: n_w + n2,
                head_single: gate_headroom_bits(n0, e0, q),
                head_rowgroup: gate_headroom_bits(s, e0, q),
                head_w: gate_headroom_bits(n_w, e_final, q),
                head_u: gate_headroom_bits(n2, e_final, q),
                w_clear_bytes: s * D * 4,
            });
        }
        e_next = e_ok;
    }
    unreachable!("two-tier base fixed point diverged");
}

/// The planner's S search: the plain sqrt split plus a geometric grid
/// around the V-recursed-input optimum S* = sqrt(n0 * kappa * l_t /
/// l_z); returns (sqrt plan, best-balanced plan).
pub fn plan_two_tier(n0: usize, e0: u32, q: u64) -> (Option<TwoTierPlan>, Option<TwoTierPlan>) {
    let s_sqrt = (n0 as f64).sqrt().ceil() as usize;
    let p_sqrt = plan_two_tier_at(n0, e0, q, s_sqrt);
    let mut best: Option<TwoTierPlan> = None;
    // Geometric sweep: S = s_sqrt * 2^(k/2), k in -4..=14 (the
    // optimum sits above sqrt because the tier-2 witness carries the
    // kappa*l_t factor).
    for k in -4i32..=14 {
        let s = ((s_sqrt as f64) * 2f64.powf(k as f64 / 2.0)).round() as usize;
        if s == 0 || s >= n0 {
            continue;
        }
        if let Some(p) = plan_two_tier_at(n0, e0, q, s) {
            if best.as_ref().is_none_or(|b| p.n_rec_full < b.n_rec_full) {
                best = Some(p);
            }
        }
    }
    (p_sqrt, best)
}

/// The remaining recursion schedule on the two-tier relation
/// (existing planner, reused — never edited). Pre-gates to avoid the
/// frozen planner's derive-time panic on an infeasible object.
pub fn recursion_schedule(n_rec: usize, e: u32, q: u64) -> Option<EvalSchedule> {
    if gate_headroom_bits(n_rec, e, q) < 0.0 || e > super::eval_proof::FLOOR_E_MAX {
        return None;
    }
    Some(plan_schedule(n_rec, e, q, None))
}

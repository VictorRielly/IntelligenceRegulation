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

// ---------------------------------------------------------------------------
// Rung 2 — THE FRONT END (the differential's subject).
//
// Per-tensor two-tier grid: for an ALIGNED tensor (cols % D == 0 —
// every real-rig tensor; the misaligned battery shapes are OUT of the
// front end, recorded in the lane ledger), the digit rings of g_rows
// consecutive matrix rows form the CONTIGUOUS slice
// [base + i*width, base + (i+1)*width), width = g_rows * nb * l0 —
// the two-tier "row group" is plain contiguous chunking of the
// tensor's ring range, so the fold and the inner commitments ride
// the EXISTING fold_chunks_ntt / matvec machinery unchanged.
//
// THE CLAIM FACTORIZATION (the load-bearing semantics; every identity
// below is pinned bit-for-bit by the `uperf-t diff` differential):
// the [UAGB1-BH] row-column split gives, per contrib and per digit
// ring v = (row, cb, limb) of an aligned tensor,
//   Phi_0[v] = radix_limb * sum_d beta[row][d] * conjQ[cb][d],
//   beta[row][d] = sum_c (scale *K row_ker[row] *K Y^d)[c] * alpha_c.
// With the row kernel in FACTORED eq form  scale *K row_ker[i*g + r]
// = hi[i] *K lo[r]  (the production structure: sumcheck eq points
// factor across the row bits; the GroupClaims API materializes the
// product — the oracle path consumes the product, the front end the
// factors), K-bilinearity over the coordinate basis splits beta:
//   beta[i*g+r][d] = sum_e (lo[r] *K Y^d)[e] * alphaHi[i][e],
//   alphaHi[i][e]  = sum_c (hi[i] *K Y^e)[c] * alpha_c,
// and Phi_0 factors RANK-16 over the (row-group i) x (in-group j)
// grid:
//   Phi_0[i, j=(r,cb,l)] = sum_e b_e[i] * a_e[j],
//   b_e[i] = alphaHi[i][e]            (outer functional, polys),
//   a_e[j] = radix_l * sum_d (lo[r] *K Y^d)[e] * conjQ[cb][d].
// The front end serves the batched opening target
//   h_cur = sum_v Phi_0[v] w0[v]  =  sum_m sum_e sum_i b_e[i] v_e[i]
// through the Greyhound two-check structure (v before c — Fiat-
// Shamir order is load-bearing):
//   (a) binding      : A_t w_t == sum_i c_i u_{t,i}  (+ U rebind),
//   (b) claim        : sum_{m,e} sum_i b^m_e[i] v^m_e[i] == h_cur,
//   (c) consistency  : sum_j a^m_e[j] w_j == sum_i c_i v^m_e[i]
//                      per (m, e).

use super::eval_proof::{AggGroup, AggTensor, SmallRings};
use super::kfield::{KElem, KField};
use super::{poly_add, poly_from_small, poly_scale, poly_zero, ring_mul_split_kara_fast, Poly, RingCtx, Zq};

/// One tensor's grid block: g_rows matrix rows per row group.
#[derive(Clone, Debug)]
pub struct TtGridTensor {
    pub tensor_idx: usize,
    pub g_rows: usize,
    /// rings per row group = g_rows * (cols/D) * l0.
    pub width: usize,
    pub n_groups: usize,
}

/// Per-tensor grids at a common width target (the largest power-of-2
/// g_rows dividing rows with width <= s_target; g_rows >= 1 always).
pub fn build_tt_grid(group: &AggGroup, s_target: usize) -> Vec<TtGridTensor> {
    group
        .tensors
        .iter()
        .enumerate()
        .map(|(ti, t)| {
            assert!(t.cols % super::D == 0, "two-tier front end: tensor {} misaligned (cols % D != 0)", t.name);
            let row_rings = (t.cols / super::D) * t.l0;
            let mut g = 1usize;
            while g * 2 <= t.rows && t.rows % (g * 2) == 0 && (g * 2) * row_rings <= s_target {
                g *= 2;
            }
            TtGridTensor { tensor_idx: ti, g_rows: g, width: g * row_rings, n_groups: t.rows / g }
        })
        .collect()
}

/// The factored claim contrib the front end consumes: scale *K
/// row_ker[i*g + r] == hi[i] *K lo[r] (asserted by the differential),
/// col as in ClaimContrib.
#[derive(Clone)]
pub struct TtContrib {
    pub tensor_idx: usize,
    pub hi: Vec<KElem>,
    pub lo: Vec<KElem>,
    pub col: std::rc::Rc<Vec<KElem>>,
}

/// conjQ[cb][d] = conj_poly(c1 -> col[cb*D + c1][d]) — the aligned-
/// branch column slices of psi_level0_factored, reproduced.
pub fn tt_conjq(zq: &Zq, col: &[KElem], nb: usize) -> Vec<Vec<Poly>> {
    (0..nb)
        .map(|cb| {
            (0..super::kfield::K_DEG)
                .map(|d| {
                    let mut base = poly_zero();
                    for c1 in 0..super::D {
                        base[c1] = col[cb * super::D + c1][d];
                    }
                    super::eval_proof::conj_poly(zq, &base)
                })
                .collect()
        })
        .collect()
}

/// loY[r][d] = lo[r] *K Y^d (K-elements; coordinate e of loY[r][d] is
/// the a-side scalar).
pub fn tt_lo_y(kf: &KField, lo: &[KElem]) -> Vec<Vec<KElem>> {
    let ybasis: Vec<KElem> = (0..super::kfield::K_DEG)
        .map(|d| {
            let mut e = kf.zero();
            e[d] = 1;
            e
        })
        .collect();
    lo.iter().map(|l| ybasis.iter().map(|y| kf.mul(l, y)).collect()).collect()
}

/// Inner functionals a_e[j] over one row group's width rings:
/// a[e][(r*nb + cb)*l0 + limb] = radix_limb * sum_d loY[r][d][e] *
/// conjQ[cb][d].
pub fn tt_inner_functionals(
    ctx: &RingCtx,
    t: &AggTensor,
    g_rows: usize,
    lo_y: &[Vec<KElem>],
    conjq: &[Vec<Poly>],
) -> Vec<Vec<Poly>> {
    let zq = &ctx.zq;
    let kd = super::kfield::K_DEG;
    let nb = t.cols / super::D;
    let radixes: Vec<u64> = (0..t.l0).map(|l| zq.to_mod(1i64 << (t.e0 as usize * l))).collect();
    let mut a = vec![vec![poly_zero(); g_rows * nb * t.l0]; kd];
    for r in 0..g_rows {
        for cb in 0..nb {
            // combo[e] = sum_d loY[r][d][e] * conjQ[cb][d]
            let mut combo = vec![poly_zero(); kd];
            for d in 0..kd {
                for (e, cmb) in combo.iter_mut().enumerate() {
                    let s = lo_y[r][d][e];
                    if s != 0 {
                        *cmb = poly_add(zq, cmb, &poly_scale(zq, s, &conjq[cb][d]));
                    }
                }
            }
            for (e, cmb) in combo.iter().enumerate() {
                for (l, &rad) in radixes.iter().enumerate() {
                    a[e][(r * nb + cb) * t.l0 + l] = poly_scale(zq, rad, cmb);
                }
            }
        }
    }
    a
}

/// Outer functionals b[i][e] = alphaHi[i][e] = sum_c (hi[i] *K Y^e)[c]
/// * alphas[c].
pub fn tt_outer_functionals(zq: &Zq, kf: &KField, hi: &[KElem], alphas: &[Poly]) -> Vec<Vec<Poly>> {
    let kd = super::kfield::K_DEG;
    let ybasis: Vec<KElem> = (0..kd)
        .map(|e| {
            let mut y = kf.zero();
            y[e] = 1;
            y
        })
        .collect();
    hi.iter()
        .map(|h| {
            (0..kd)
                .map(|e| {
                    let hy = kf.mul(h, &ybasis[e]);
                    let mut acc = poly_zero();
                    for (c, a) in alphas.iter().enumerate() {
                        if hy[c] != 0 {
                            acc = poly_add(zq, &acc, &poly_scale(zq, hy[c], a));
                        }
                    }
                    acc
                })
                .collect()
        })
        .collect()
}

/// The heavy half of the v-pass, shareable across contribs on the
/// same (tensor, col kernel): QR[row][d] = sum_cb conjQ[cb][d] *
/// Fl[row*nb+cb], with Fl the radix-recombined limb rings. The
/// per-(cb,d) products ride `mul_modq_small_many` (one forward NTT of
/// the conjQ poly, windowed MACs over the row smalls — the commit
/// path's batching); exact mod-q regroupings only, pinned by the
/// differential.
pub fn tt_qr_pass(
    ctx: &RingCtx,
    t: &AggTensor,
    w0: &[i8],
    conjq: &[Vec<Poly>],
) -> Vec<Vec<Poly>> {
    let zq = &ctx.zq;
    let kd = super::kfield::K_DEG;
    let nb = t.cols / super::D;
    let mut qr = vec![vec![poly_zero(); kd]; t.rows];
    let mut buf = [0i64; super::D];
    let mut fl_cb: Vec<Vec<i64>> = Vec::with_capacity(t.rows);
    for cb in 0..nb {
        fl_cb.clear();
        for row in 0..t.rows {
            let vr = row * nb + cb;
            let mut fl = vec![0i64; super::D];
            for l in 0..t.l0 {
                let u = t.digit_ring_base + vr * t.l0 + l;
                let ring = SmallRings::ring(w0, u, &mut buf);
                let rad = 1i64 << (t.e0 as usize * l);
                for (f, &x) in fl.iter_mut().zip(ring.iter()) {
                    if x != 0 {
                        *f += rad * x;
                    }
                }
            }
            fl_cb.push(fl);
        }
        for d in 0..kd {
            let prods = super::eval_proof::mul_modq_small_many(ctx, &conjq[cb][d], &fl_cb);
            for (row, p) in prods.into_iter().enumerate() {
                if p.iter().all(|&x| x == 0) {
                    continue;
                }
                qr[row][d] = poly_add(zq, &qr[row][d], &p);
            }
        }
    }
    qr
}

/// The light half of the v-pass: v[e][i] = sum_{r,d} loY[r][d][e] *
/// QR[i*g + r][d] (scalar-scaled ring sums; per-contrib).
pub fn tt_v_from_qr(
    zq: &Zq,
    gt: &TtGridTensor,
    lo_y: &[Vec<KElem>],
    qr: &[Vec<Poly>],
) -> Vec<Vec<Poly>> {
    let kd = super::kfield::K_DEG;
    let g = gt.g_rows;
    let mut v = vec![vec![poly_zero(); gt.n_groups]; kd];
    for i in 0..gt.n_groups {
        for r in 0..g {
            let row = i * g + r;
            for d in 0..kd {
                let src = &qr[row][d];
                if src.iter().all(|&x| x == 0) {
                    continue;
                }
                for e in 0..kd {
                    let s = lo_y[r][d][e];
                    if s != 0 {
                        v[e][i] = poly_add(zq, &v[e][i], &poly_scale(zq, s, src));
                    }
                }
            }
        }
    }
    v
}

// ---------------------------------------------------------------------------
// [UPERF3-QQ] Round 10, rung 2 — THE FACTORED v-PASS (redesign memo §2 R1,
// the C-R1 swap-order form), written out over value rings:
//
//   v[e][i] = sum_{j=(r,cb)} P_e[j] (x) Fl_i[j],
//   P_e[(r,cb)] = sum_d loY[r][d][e] * conjQ[cb][d]     (mod-q rings),
//   Fl_i[(r,cb)] = sum_l radix_l * digit_l              (the recombined value ring),
//
// which is ONE call of the built `ntt_gemm_modq_small_gen` contract
// (a = 16 slices of nb*g mod-q rings, b = G slices of nb*g small
// rings, out[e * G + i]) — the kernel the level-0 commitment rides
// (AVX2 body, GPU hook). The same D-domain MAC count as `tt_qr_pass`
// (16 Nv D) with one forward transform per value ring instead of one
// forward + one inverse per (row, cb, d) product. Exact mod-q
// regrouping only: pinned bit-for-bit by the FF differential legs
// (`uperf-t r1 diff`). The S4 functions above are untouched.
//
// The DIGIT form (`R1Form::Digit`) is the same GEMM over the tensor's
// digit rings with the radix folded into P (a = 16 x width rings, b =
// the flat i8 row-group slices, the pack fast path): l0x the MACs of
// the value form, used where the recombined value would overflow the
// single-prime exact-integer window (act-class tensors at l0 >= ~12).

/// Which operand layout the R1 GEMM uses for a tensor.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum R1Form {
    /// b = recombined value rings (i64), a = P over (r, cb).
    Value,
    /// b = the flat i8 digit rings, a = radix_l * P over (r, cb, l).
    Digit,
}

/// The largest |Fl| a tensor's recombined value ring can carry
/// (alphabet(e0) bound x sum of radices).
pub fn tt_value_bound(t: &AggTensor) -> u128 {
    let (lo, hi) = super::digits::alphabet(t.e0);
    let dmax = lo.unsigned_abs().max(hi.unsigned_abs()) as u128;
    let mut s: u128 = 0;
    for l in 0..t.l0 {
        s += 1u128 << (t.e0 as usize * l);
    }
    dmax * s
}

/// The form the R1 pass takes for a tensor: the value form whenever
/// the recombined bound fits at least one exact-integer window of
/// the GEMM (every CLASS_W8S weight tensor; the act classes up to
/// l0 ~11), else the digit form.
pub fn tt_r1_form_for(q: u64, t: &AggTensor) -> R1Form {
    if super::eval_proof::ntt_window_terms(q, tt_value_bound(t)) >= 1 {
        R1Form::Value
    } else {
        R1Form::Digit
    }
}

/// P over value positions: P[e][r*nb + cb] = sum_d loY[r][d][e] *
/// conjQ[cb][d] (no radix) — `tt_inner_functionals` without the limb
/// axis.
pub fn tt_inner_value_functionals(zq: &Zq, g_rows: usize, nb: usize, lo_y: &[Vec<KElem>], conjq: &[Vec<Poly>]) -> Vec<Vec<Poly>> {
    let kd = super::kfield::K_DEG;
    let n = g_rows * nb;
    // One position j = (r, cb): combo[e] = sum_d loY[r][d][e] * conjQ[cb][d]
    // (a fixed-order mod-q sum; the same values in any thread layout).
    let one = |j: usize| -> Vec<Poly> {
        let (r, cb) = (j / nb, j % nb);
        let mut combo = vec![poly_zero(); kd];
        for d in 0..kd {
            for (e, cmb) in combo.iter_mut().enumerate() {
                let s = lo_y[r][d][e];
                if s != 0 {
                    *cmb = poly_add(zq, cmb, &poly_scale(zq, s, &conjq[cb][d]));
                }
            }
        }
        combo
    };
    let per_j: Vec<Vec<Poly>> = if super::eval_proof::threads() > 1 && n >= 64 {
        tt_pool().install(|| {
            use rayon::prelude::*;
            (0..n).into_par_iter().map(one).collect()
        })
    } else {
        (0..n).map(one).collect()
    };
    let mut p = vec![vec![poly_zero(); n]; kd];
    for (j, combo) in per_j.into_iter().enumerate() {
        for (e, c) in combo.into_iter().enumerate() {
            p[e][j] = c;
        }
    }
    p
}

/// The recombined value rings of row groups [i_lo, i_hi) of a tensor,
/// one Vec<i64> per (row, cb) position: Fl = sum_l radix_l * digit_l
/// (the `tt_qr_pass` recombination, batched per row group).
pub fn tt_fl_row_groups(t: &AggTensor, w0: &[i8], gt: &TtGridTensor, i_lo: usize, i_hi: usize) -> Vec<Vec<Vec<i64>>> {
    let nb = t.cols / super::D;
    let g = gt.g_rows;
    let mut buf = [0i64; super::D];
    (i_lo..i_hi)
        .map(|i| {
            let mut out = Vec::with_capacity(g * nb);
            for r in 0..g {
                let row = i * g + r;
                for cb in 0..nb {
                    let vr = row * nb + cb;
                    let mut fl = vec![0i64; super::D];
                    for l in 0..t.l0 {
                        let u = t.digit_ring_base + vr * t.l0 + l;
                        let ring = SmallRings::ring(w0, u, &mut buf);
                        let rad = 1i64 << (t.e0 as usize * l);
                        for (f, &x) in fl.iter_mut().zip(ring.iter()) {
                            if x != 0 {
                                *f += rad * x;
                            }
                        }
                    }
                    out.push(fl);
                }
            }
            out
        })
        .collect()
}

/// Row groups per GEMM call (bounds the materialized Fl batch to
/// ~64K value rings = 64 MiB of i64 rings).
fn tt_r1_batch_groups(gt: &TtGridTensor, nb: usize) -> usize {
    let per_group = gt.g_rows * nb;
    ((1usize << 16) / per_group.max(1)).clamp(1, gt.n_groups.max(1))
}

// ---- [UPERF3-QQ rung 3] the device-side shape of the R1 pass ----------------
//
// Attribution counters (ns) for the R1 pass: P precompute, Fl
// materialization, the GEMM (host+device through the hook), the
// output scatter; and the R1 fold. Read-and-reset by `tt_r1_prof_take`.

use std::sync::atomic::{AtomicU64, Ordering as AtOrd};
use std::sync::OnceLock;

static TT_R1_NS: [AtomicU64; 5] = [AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0), AtomicU64::new(0)];
pub const TT_R1_P: usize = 0;
pub const TT_R1_FL: usize = 1;
pub const TT_R1_GEMM: usize = 2;
pub const TT_R1_OUT: usize = 3;
pub const TT_R1_FOLD: usize = 4;

fn tt_r1_add(slot: usize, t0: std::time::Instant) {
    TT_R1_NS[slot].fetch_add(t0.elapsed().as_nanos() as u64, AtOrd::Relaxed);
}

/// The accumulated R1 attribution in seconds [P, Fl, GEMM, out, fold], reset on read.
pub fn tt_r1_prof_take() -> [f64; 5] {
    let mut out = [0f64; 5];
    for (o, c) in out.iter_mut().zip(TT_R1_NS.iter()) {
        *o = c.swap(0, AtOrd::Relaxed) as f64 * 1e-9;
    }
    out
}

/// The lane's own pool at the house thread count (eval_proof's POOL is
/// private to the frozen module; same size, same discipline).
fn tt_pool() -> &'static rayon::ThreadPool {
    static P: OnceLock<rayon::ThreadPool> = OnceLock::new();
    P.get_or_init(|| rayon::ThreadPoolBuilder::new().num_threads(super::eval_proof::threads()).build().expect("two-tier pool"))
}

/// One row group's recombined value rings, flat i64 (g*nb*D words),
/// and the max |value| seen.
fn tt_fl_group_flat(t: &AggTensor, w0: &[i8], gt: &TtGridTensor, i: usize) -> (Vec<i64>, i64) {
    let nb = t.cols / super::D;
    let g = gt.g_rows;
    let mut out = vec![0i64; g * nb * super::D];
    let mut buf = [0i64; super::D];
    let mut mx = 0i64;
    for r in 0..g {
        let row = i * g + r;
        for cb in 0..nb {
            let vr = row * nb + cb;
            let dst = &mut out[(r * nb + cb) * super::D..(r * nb + cb + 1) * super::D];
            for l in 0..t.l0 {
                let u = t.digit_ring_base + vr * t.l0 + l;
                let ring = SmallRings::ring(w0, u, &mut buf);
                let rad = 1i64 << (t.e0 as usize * l);
                for (f, &x) in dst.iter_mut().zip(ring.iter()) {
                    if x != 0 {
                        *f += rad * x;
                    }
                }
            }
            for &f in dst.iter() {
                mx = mx.max(f.abs());
            }
        }
    }
    (out, mx)
}

/// The Fl batch for row groups [i_lo, i_hi): either every value fits an
/// i8 (the flat store the GEMM packs on its fast path — every real
/// int8 weight tensor) or the boxed i64 rings.
enum TtFlBatch {
    I8(Vec<Vec<i8>>),
    I64(Vec<Vec<Vec<i64>>>),
}

fn tt_fl_batch(t: &AggTensor, w0: &[i8], gt: &TtGridTensor, i_lo: usize, i_hi: usize) -> TtFlBatch {
    let groups: Vec<(Vec<i64>, i64)> = if super::eval_proof::threads() > 1 && i_hi - i_lo > 1 {
        tt_pool().install(|| {
            use rayon::prelude::*;
            (i_lo..i_hi).into_par_iter().map(|i| tt_fl_group_flat(t, w0, gt, i)).collect()
        })
    } else {
        (i_lo..i_hi).map(|i| tt_fl_group_flat(t, w0, gt, i)).collect()
    };
    let mx = groups.iter().map(|(_, m)| *m).max().unwrap_or(0);
    if mx <= 127 {
        TtFlBatch::I8(groups.into_iter().map(|(v, _)| v.into_iter().map(|x| x as i8).collect()).collect())
    } else {
        TtFlBatch::I64(groups.into_iter().map(|(v, _)| v.chunks(super::D).map(|c| c.to_vec()).collect()).collect())
    }
}

/// [rung 4] The PER-MODEL value layout of a tensor: every row group's
/// recombined value rings as one flat i8 vector (g*nb*D bytes), built
/// on the pool; None when any value does not fit an i8 (then the pass
/// builds i64 batches per proof). Alpha-independent: the int8 weights
/// themselves, in row-group order.
pub fn tt_fl_layout_i8(t: &AggTensor, w0: &[i8], gt: &TtGridTensor) -> Option<Vec<Vec<i8>>> {
    let n = gt.n_groups;
    let groups: Vec<(Vec<i64>, i64)> = if super::eval_proof::threads() > 1 && n > 1 {
        tt_pool().install(|| {
            use rayon::prelude::*;
            (0..n).into_par_iter().map(|i| tt_fl_group_flat(t, w0, gt, i)).collect()
        })
    } else {
        (0..n).map(|i| tt_fl_group_flat(t, w0, gt, i)).collect()
    };
    if groups.iter().any(|(_, m)| *m > 127) {
        return None;
    }
    Some(groups.into_iter().map(|(v, _)| v.into_iter().map(|x| x as i8).collect()).collect())
}

/// THE R1 v-PASS, device shape: the same GEMM as `tt_v_pass_r1`'s value
/// form with the Fl batch built on the pool and packed flat-i8 when it
/// fits (the GEMM hook's `as_i8` fast path: no scan, i8 staging), or
/// taken from the per-model layout `fl_cache` when one is held.
/// Values identical to `tt_v_pass_r1` (exact mod-q regrouping).
pub fn tt_v_pass_r1_dev(
    ctx: &RingCtx,
    t: &AggTensor,
    gt: &TtGridTensor,
    w0: &[i8],
    lo_y: &[Vec<KElem>],
    conjq: &[Vec<Poly>],
    fl_cache: Option<&[Vec<i8>]>,
) -> Vec<Vec<Poly>> {
    let zq = &ctx.zq;
    let kd = super::kfield::K_DEG;
    let nb = t.cols / super::D;
    let g = gt.g_rows;
    let n_groups = gt.n_groups;
    let mut v = vec![vec![poly_zero(); n_groups]; kd];
    let t0 = std::time::Instant::now();
    let p = tt_inner_value_functionals(zq, g, nb, lo_y, conjq);
    let a: Vec<&[Poly]> = p.iter().map(|pe| pe.as_slice()).collect();
    tt_r1_add(TT_R1_P, t0);
    let len = g * nb;
    let batch = tt_r1_batch_groups(gt, nb);
    let mut i_lo = 0;
    while i_lo < n_groups {
        let i_hi = (i_lo + batch).min(n_groups);
        let t1 = std::time::Instant::now();
        let fl = match fl_cache {
            Some(_) => None,
            None => Some(tt_fl_batch(t, w0, gt, i_lo, i_hi)),
        };
        tt_r1_add(TT_R1_FL, t1);
        let t2 = std::time::Instant::now();
        let out = match (&fl, fl_cache) {
            (_, Some(cache)) => {
                let b: Vec<&[i8]> = cache[i_lo..i_hi].iter().map(|f| f.as_slice()).collect();
                super::eval_proof::ntt_gemm_modq_small_gen::<[i8]>(ctx, &a, &b, len)
            }
            (Some(TtFlBatch::I8(gs)), None) => {
                let b: Vec<&[i8]> = gs.iter().map(|f| f.as_slice()).collect();
                super::eval_proof::ntt_gemm_modq_small_gen::<[i8]>(ctx, &a, &b, len)
            }
            (Some(TtFlBatch::I64(gs)), None) => {
                let b: Vec<&[Vec<i64>]> = gs.iter().map(|f| f.as_slice()).collect();
                super::eval_proof::ntt_gemm_modq_small_gen::<[Vec<i64>]>(ctx, &a, &b, len)
            }
            (None, None) => unreachable!(),
        };
        tt_r1_add(TT_R1_GEMM, t2);
        let t3 = std::time::Instant::now();
        let nbatch = i_hi - i_lo;
        for e in 0..kd {
            for (k, i) in (i_lo..i_hi).enumerate() {
                v[e][i] = out[e * nbatch + k].clone();
            }
        }
        tt_r1_add(TT_R1_OUT, t3);
        i_lo = i_hi;
    }
    v
}

/// A strided column of the flat i8 witness: ring u = position `ib` of
/// row group u (rings at base + u*width + ib), n_rings = G. The GEMM's
/// B operand for the fold-as-GEMM (`tt_fold_r1`): the GEMM never calls
/// `sub` (only the fold helpers do), so it is unreachable here.
pub struct TtStridedCol<'a> {
    pub flat: &'a [i8],
    pub base: usize,
    pub width: usize,
    pub n_groups: usize,
    pub ib: usize,
}

impl SmallRings for TtStridedCol<'_> {
    #[inline(always)]
    fn n_rings(&self) -> usize {
        self.n_groups
    }
    #[inline(always)]
    fn ring<'a>(&'a self, u: usize, buf: &'a mut [i64; super::D]) -> &'a [i64] {
        let s = &self.flat[(self.base + u * self.width + self.ib) * super::D..][..super::D];
        for (b, &x) in buf.iter_mut().zip(s.iter()) {
            *b = x as i64;
        }
        &buf[..]
    }
    fn max_abs(&self) -> u128 {
        let mut m = 0u8;
        for u in 0..self.n_groups {
            let s = &self.flat[(self.base + u * self.width + self.ib) * super::D..][..super::D];
            for &x in s {
                m = m.max(x.unsigned_abs());
            }
        }
        m as u128
    }
    fn is_zero(&self, u: usize) -> bool {
        self.flat[(self.base + u * self.width + self.ib) * super::D..][..super::D].iter().all(|&x| x == 0)
    }
    fn sub(&self, _lo: usize, _hi: usize) -> &Self {
        unreachable!("TtStridedCol::sub: the GEMM contract never sub-slices its B operand")
    }
}

/// THE R1 FOLD: w[ib] = sum_i c_i (x) row_i[ib] as ONE GEMM per tensor
/// (a = the G fold challenges as mod-q rings, one slice; b = the width
/// strided columns; len = G) — the device GEMM class instead of the
/// combine class (tuned for r <= 64 challenges x many outputs; the
/// two-tier fold is G ~ 10^3-10^4 challenges x width outputs). The
/// output is centered back to the EXACT i64 fold (|w| <= the honest
/// bound << q/2): identical to `fold_chunks_ntt_gen`.
pub fn tt_fold_r1(ctx: &RingCtx, t: &AggTensor, gt: &TtGridTensor, w0: &[i8], cs: &[Vec<i64>]) -> Vec<Vec<i64>> {
    let zq = &ctx.zq;
    let q = zq.q;
    let t0 = std::time::Instant::now();
    assert_eq!(cs.len(), gt.n_groups, "one fold challenge per row group");
    let c_polys: Vec<Poly> = cs.iter().map(|c| poly_from_small(zq, c)).collect();
    let a: Vec<&[Poly]> = vec![c_polys.as_slice()];
    let cols: Vec<TtStridedCol> = (0..gt.width)
        .map(|ib| TtStridedCol { flat: w0, base: t.digit_ring_base, width: gt.width, n_groups: gt.n_groups, ib })
        .collect();
    let b: Vec<&TtStridedCol> = cols.iter().collect();
    let out = super::eval_proof::ntt_gemm_modq_small_gen::<TtStridedCol>(ctx, &a, &b, gt.n_groups);
    let half = q / 2;
    let w: Vec<Vec<i64>> = out.iter().map(|p| p.iter().map(|&x| if x > half { x as i64 - q as i64 } else { x as i64 }).collect()).collect();
    tt_r1_add(TT_R1_FOLD, t0);
    w
}

/// THE R1 v-PASS: v[e][i] for one contrib on tensor `t` (grid `gt`),
/// as GEMM calls over batches of row groups. Returns [e][i] like
/// `tt_v_from_qr`.
pub fn tt_v_pass_r1(
    ctx: &RingCtx,
    t: &AggTensor,
    gt: &TtGridTensor,
    w0: &[i8],
    lo_y: &[Vec<KElem>],
    conjq: &[Vec<Poly>],
    form: R1Form,
) -> Vec<Vec<Poly>> {
    let zq = &ctx.zq;
    let kd = super::kfield::K_DEG;
    let nb = t.cols / super::D;
    let g = gt.g_rows;
    let n_groups = gt.n_groups;
    let mut v = vec![vec![poly_zero(); n_groups]; kd];
    match form {
        R1Form::Value => {
            let p = tt_inner_value_functionals(zq, g, nb, lo_y, conjq);
            let a: Vec<&[Poly]> = p.iter().map(|pe| pe.as_slice()).collect();
            let len = g * nb;
            let batch = tt_r1_batch_groups(gt, nb);
            let mut i_lo = 0;
            while i_lo < n_groups {
                let i_hi = (i_lo + batch).min(n_groups);
                let fl = tt_fl_row_groups(t, w0, gt, i_lo, i_hi);
                let b: Vec<&[Vec<i64>]> = fl.iter().map(|f| f.as_slice()).collect();
                let out = super::eval_proof::ntt_gemm_modq_small_gen::<[Vec<i64>]>(ctx, &a, &b, len);
                for e in 0..kd {
                    for (k, i) in (i_lo..i_hi).enumerate() {
                        v[e][i] = out[e * b.len() + k].clone();
                    }
                }
                i_lo = i_hi;
            }
        }
        R1Form::Digit => {
            // a = radix_l * P over (r, cb, l) = the S4 inner functional
            // (digit rings); b = the flat i8 row-group slices.
            let a_dig = tt_inner_functionals(ctx, t, g, lo_y, conjq);
            let a: Vec<&[Poly]> = a_dig.iter().map(|pe| pe.as_slice()).collect();
            let len = gt.width;
            let batch = tt_r1_batch_groups(gt, nb * t.l0);
            let mut i_lo = 0;
            while i_lo < n_groups {
                let i_hi = (i_lo + batch).min(n_groups);
                let b: Vec<&[i8]> = (i_lo..i_hi)
                    .map(|i| SmallRings::sub(w0, t.digit_ring_base + i * len, t.digit_ring_base + (i + 1) * len))
                    .collect();
                let out = super::eval_proof::ntt_gemm_modq_small_gen::<[i8]>(ctx, &a, &b, len);
                for e in 0..kd {
                    for (k, i) in (i_lo..i_hi).enumerate() {
                        v[e][i] = out[e * b.len() + k].clone();
                    }
                }
                i_lo = i_hi;
            }
        }
    }
    v
}

/// The claim-row images recovered from v (the count's fact (2)):
/// b_rows[c] += sum_i sum_e (hi[i] *K Y^e)[c] * v[e][i] — accumulated
/// into `acc` (16 rings) for one contrib. With row_ker = hi *K lo this
/// equals the built kernel pass's contribution POLY-EXACTLY (pinned by
/// DIFF 1 against GroupEvalProof.b_rows).
pub fn tt_rows_from_v(zq: &Zq, kf: &KField, hi: &[KElem], v: &[Vec<Poly>], acc: &mut [Poly]) {
    let kd = super::kfield::K_DEG;
    let ybasis: Vec<KElem> = (0..kd)
        .map(|e| {
            let mut y = kf.zero();
            y[e] = 1;
            y
        })
        .collect();
    // Per row group i: the 16 partial rows (a fixed-order sum over e);
    // the partials are added in index order i (mod-q addition is
    // associative and commutative — the same values in any layout).
    let one = |i: usize| -> Vec<Poly> {
        let h = &hi[i];
        let mut part = vec![poly_zero(); kd];
        for e in 0..kd {
            let src = &v[e][i];
            if src.iter().all(|&x| x == 0) {
                continue;
            }
            let hy = kf.mul(h, &ybasis[e]);
            for (c, a) in part.iter_mut().enumerate() {
                if hy[c] != 0 {
                    *a = poly_add(zq, a, &poly_scale(zq, hy[c], src));
                }
            }
        }
        part
    };
    let n = hi.len();
    let parts: Vec<Vec<Poly>> = if super::eval_proof::threads() > 1 && n >= 64 {
        tt_pool().install(|| {
            use rayon::prelude::*;
            (0..n).into_par_iter().map(one).collect()
        })
    } else {
        (0..n).map(one).collect()
    };
    for part in parts {
        for (c, a) in acc.iter_mut().enumerate() {
            *a = poly_add(zq, a, &part[c]);
        }
    }
}

/// sum_e sum_i b[i][e] * v[e][i] — the contrib's claim reconstruction
/// H_m (and, summed over contribs, the served opening target).
pub fn tt_claim_sum(ctx: &RingCtx, b: &[Vec<Poly>], v: &[Vec<Poly>]) -> Poly {
    let zq = &ctx.zq;
    let kd = super::kfield::K_DEG;
    let mut acc = poly_zero();
    for (i, bi) in b.iter().enumerate() {
        for e in 0..kd {
            if bi[e].iter().all(|&x| x == 0) || v[e][i].iter().all(|&x| x == 0) {
                continue;
            }
            acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, &bi[e], &v[e][i]));
        }
    }
    acc
}

/// The honest-fold coefficient bound at a G-way fold of base-e0
/// digits (fold_coeff_bound at r = G) — the prover asserts the honest
/// fold fits (restart discipline), the verifier range-checks the
/// clear w against it.
pub fn tt_fold_bound(g: usize, e0: u32) -> i128 {
    fold_coeff_bound(g, e0)
}

/// [UPERF3-QQ] The folded-row digit limb count at interior base `e`:
/// limbs_for_bound(fold_coeff_bound(G, e0), e) — the planner's l_z for
/// a G-way fold of base-e0 rings, exposed for the per-tensor count
/// (the planner works on one global split; the front end folds per
/// tensor grid).
pub fn tt_w_digit_limbs(g: usize, e0: u32, e: u32) -> usize {
    limbs_for_bound(fold_coeff_bound(g, e0), e)
}

/// The tier-2 u-digit base: the largest exact-digit-gate-green base
/// for the u-digit witness (G_all * KAPPA_AGG * l_t rings), resolved
/// by the same fixed point as the planner (a deterministic public
/// function of (g_all, q) — Fiat-Shamir-safe).
pub fn tt_u_digit_base(g_all: usize, q: u64) -> (u32, usize) {
    let mut e = 2u32;
    for _ in 0..8 {
        let l_t = limbs_for_bound((q as i128 - 1) / 2, e);
        let n2 = g_all * KAPPA_AGG * l_t;
        let e_ok = adaptive_base_opt(n2, q).expect("tier-2 u witness infeasible at every base");
        assert!(e_ok >= 2, "tier-2 u witness needs a balanced base");
        if e_ok <= e {
            let e_final = e.min(e_ok);
            let l_t = limbs_for_bound((q as i128 - 1) / 2, e_final);
            return (e_final, l_t);
        }
        e = e_ok;
    }
    unreachable!("u-digit base fixed point diverged");
}

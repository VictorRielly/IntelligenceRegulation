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

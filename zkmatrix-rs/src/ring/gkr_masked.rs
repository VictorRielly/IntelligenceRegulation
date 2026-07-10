// U-K5a/b (M4_LOOKUP_ZK_DESIGN.md Sections 3, 6): the MASKED fractional
// GKR descent — the E3-Z construction that makes the lookup transcript
// HVZK. Every equation here is the engine transcription of
// scripts/logup_zk_mask_spike.py (11/11 OK), which is itself the
// machine-checked form of the design document; variable and mask names
// follow the spike for reviewability.
//
// Three mask families, ALL committed in the statement wave BEFORE
// alpha (h0_lkp binds them — the amended alpha edge):
//
//   M1  g^(j): one "sum of univariates" polynomial per layer sumcheck
//       (a0 + sum_t g_t(x_t), degrees matching the round pattern);
//       drawn nu_j-combined into the running claim, opened at the
//       final point, hypersum G_j sent and E4-pinned.
//   M2  (Rp_j, Rq_j): degree-(1,2) boundary masks for INTERIOR layers
//       2 <= j <= K-1. The masked child is
//       p^dot(pt) = MLE(p)(pt) + pt_1(1 - pt_1) * SP(pt_0),
//       SP(z) := R(z, 0) + R(z, 1)  (pt_0 = the child bit, pt_1 = the
//       layer's first bound variable) — the vanishing factor kills the
//       mask on the hypercube, so summed relations see the true tree
//       while boundary points see a one-time pad. The incoming claim's
//       mask deposit is repaid by a correction summand supported on
//       b = 0, carried by the dummy w variable.
//   M3  blinder leaves (U-K5c): committed (a, u) pairs at fixed
//       positions padding the tops and the final boundary.
//
// Round-degree pattern per layer-j sumcheck (ell = #b-vars + 1 with
// the trailing w): [5 if the children are masked else 3] on the first
// b-variable (the Z-hat factor rides it), 3 on the other b-variables,
// 2 on w. The prover works on FOLDED multilinear tables plus ANALYTIC
// mask terms: after the first b-round binds r_1, the child-mask
// contribution zz * SP(c) (zz = r_1(1 - r_1)) is a CONSTANT folded
// into the child tables, and everything downstream is the standard
// multilinear machinery; the g-mask and the correction term are summed
// in closed form per round (g_hypersum style).

use super::gkr::{FracTree, eq_eval, eq_table};
use super::kfield::{KElem, KField};
use super::sumcheck::{LkpTranscript, lagrange_eval};

// ---------------------------------------------------------------------------
// Mask objects (M1/M2).

/// M1: g(pt) = a0 + sum_t sum_i a_{t,i} pt_t^i (no per-variable
/// constant). Committed coefficient count: 1 + sum of degrees.
pub struct GMask {
    pub a0: KElem,
    pub uni: Vec<Vec<KElem>>, // per variable: coefficients of x^1..x^d
}

/// M2: R(z1, w) = sum_{i<2, j<3} c[i][j] z1^i w^j (6 coefficients).
pub type RMask = [[KElem; 3]; 2];

/// The per-descent mask set: g^(j) for sumchecks j = 1..K-1, (Rp, Rq)
/// for interior layers j = 2..K-1.
pub struct MaskSet {
    pub g: Vec<GMask>,           // index j-1 for sumcheck j (1-based)
    pub r: Vec<(RMask, RMask)>,  // index j-2 for layer j (2-based)
}

/// Round degrees of the layer-j sumcheck (ell variables total).
pub fn sc_degrees(n_bvars: usize, child_masked: bool) -> Vec<usize> {
    let mut d = vec![3usize; n_bvars];
    if child_masked {
        d[0] = 5;
    }
    d.push(2); // the w-round
    d
}

impl GMask {
    pub fn draw(kf: &KField, tr: &mut LkpTranscript, degs: &[usize]) -> GMask {
        GMask {
            a0: tr.challenge_k(kf),
            uni: degs.iter().map(|&d| (0..d).map(|_| tr.challenge_k(kf)).collect()).collect(),
        }
    }

    pub fn zero(kf: &KField, degs: &[usize]) -> GMask {
        GMask { a0: kf.zero(), uni: degs.iter().map(|&d| vec![kf.zero(); d]).collect() }
    }

    pub fn eval(&self, kf: &KField, pt: &[KElem]) -> KElem {
        assert_eq!(pt.len(), self.uni.len());
        let mut acc = self.a0.clone();
        for (coeffs, x) in self.uni.iter().zip(pt.iter()) {
            let mut xp = x.clone();
            for a in coeffs {
                acc = kf.add(&acc, &kf.mul(a, &xp));
                xp = kf.mul(&xp, x);
            }
        }
        acc
    }

    /// sum over {0,1}^ell = 2^ell a0 + 2^(ell-1) sum_t g_t(1).
    pub fn hypersum(&self, kf: &KField) -> KElem {
        let ell = self.uni.len();
        let mut acc = kf.scale(kf.zq.to_mod(1i64 << ell), &self.a0);
        let half = kf.zq.to_mod(1i64 << (ell - 1));
        for coeffs in &self.uni {
            let mut s = kf.zero();
            for a in coeffs {
                s = kf.add(&s, a);
            }
            acc = kf.add(&acc, &kf.scale(half, &s));
        }
        acc
    }

    /// The committed coefficient vector (a0 then the univariates, in
    /// variable order) — the layout the mask commitment and its E4
    /// pinning rows use (freeze row LKP-6 pins the counts).
    pub fn coeffs(&self) -> Vec<KElem> {
        let mut out = vec![self.a0.clone()];
        for c in &self.uni {
            out.extend(c.iter().cloned());
        }
        out
    }
}

pub fn draw_rmask(kf: &KField, tr: &mut LkpTranscript) -> RMask {
    std::array::from_fn(|_| std::array::from_fn(|_| tr.challenge_k(kf)))
}

pub fn zero_rmask(kf: &KField) -> RMask {
    std::array::from_fn(|_| std::array::from_fn(|_| kf.zero()))
}

pub fn eval_r(kf: &KField, r: &RMask, z1: &KElem, w: &KElem) -> KElem {
    let mut acc = kf.zero();
    let mut z1p = kf.one();
    for row in r.iter() {
        let mut wp = kf.one();
        for c in row.iter() {
            acc = kf.add(&acc, &kf.mul(c, &kf.mul(&z1p, &wp)));
            wp = kf.mul(&wp, w);
        }
        z1p = kf.mul(&z1p, z1);
    }
    acc
}

/// SP(z1) = R(z1, 0) + R(z1, 1) — the boundary pad polynomial (linear
/// in z1).
pub fn eval_sp(kf: &KField, r: &RMask, z1: &KElem) -> KElem {
    kf.add(&eval_r(kf, r, z1, &kf.zero()), &eval_r(kf, r, z1, &kf.one()))
}

/// Draw the full mask set for a depth-K descent with n_extra instance
/// variables per layer (ell_j = j + n_extra + 1). MUST be called
/// against transcript state that precedes alpha (the caller commits
/// the coefficients and binds them into h0_lkp — mask freshness is
/// per-pass, battery E3Z-N3).
pub fn draw_masks(kf: &KField, tr: &mut LkpTranscript, depth: usize, n_extra: usize) -> MaskSet {
    let g = (1..depth)
        .map(|j| {
            let degs = sc_degrees(j + n_extra, j <= depth - 2);
            GMask::draw(kf, tr, &degs)
        })
        .collect();
    let r = (2..depth).map(|_| (draw_rmask(kf, tr), draw_rmask(kf, tr))).collect();
    MaskSet { g, r }
}

/// The all-zero mask set (the pre-E3-Z engine, kept live for the
/// leak-demonstration batteries).
pub fn zero_masks(kf: &KField, depth: usize, n_extra: usize) -> MaskSet {
    let g = (1..depth)
        .map(|j| {
            let degs = sc_degrees(j + n_extra, j <= depth - 2);
            GMask::zero(kf, &degs)
        })
        .collect();
    let r = (2..depth).map(|_| (zero_rmask(kf), zero_rmask(kf))).collect();
    MaskSet { g, r }
}

/// LKP-6 arithmetic: committed mask K-element counts for one descent
/// (g: 1 + sum degs per sumcheck; R: 6 per polynomial, two per
/// interior layer).
pub fn mask_coeff_counts(depth: usize, n_extra: usize) -> (usize, usize) {
    let g: usize = (1..depth)
        .map(|j| 1 + sc_degrees(j + n_extra, j <= depth - 2).iter().sum::<usize>())
        .sum();
    let r = if depth >= 2 { 12 * (depth - 2) } else { 0 };
    (g, r)
}

// ---------------------------------------------------------------------------
// The masked descent.

pub struct MaskedLayerProof {
    /// The E4-pinned hypersum of g^(j).
    pub g_sum: KElem,
    /// Round polynomials, degree pattern sc_degrees (evals at 0..=d).
    pub rounds: Vec<Vec<KElem>>,
    /// Masked boundary quadruple (vp0, vp1, vq0, vq1).
    pub boundary: [KElem; 4],
    /// Openings at the final point: g^(j)(r, c), and for j >= 2 the
    /// correction openings (Rp_j(mu_prev, c), Rq_j(mu_prev, c)). Every
    /// opening is E4-pinned against the mask commitments.
    pub open_g: KElem,
    pub open_r: Option<(KElem, KElem)>,
}

pub struct MaskedDescentProof {
    /// The layer-1 quadruple per instance tree (p1(0), p1(1), q1(0),
    /// q1(1)) — the verifier DERIVES the roots from it (they are never
    /// sent; the M3 blinders randomize them).
    pub layer1: Vec<[KElem; 4]>,
    pub layers: Vec<MaskedLayerProof>,
}

/// One analytic g-mask round evaluation: the sum over the suffix
/// hypercube of g at (prefix r's, X at variable t, suffix free), i.e.
///   2^(n_suffix) [ a0 + sum_{s<t} g_s(r_s) + g_t(X) ]
///   + 2^(n_suffix - 1) sum_{s>t} g_s(1).
fn g_round_eval(
    kf: &KField,
    gm: &GMask,
    prefix_sum: &KElem, // a0 + sum_{s<t} g_s(r_s)
    t: usize,
    x: &KElem,
    tail_ones: &KElem, // sum_{s>t} g_s(1)
) -> KElem {
    let ell = gm.uni.len();
    let n_suffix = ell - t - 1;
    let mut gt_x = kf.zero();
    let mut xp = x.clone();
    for a in &gm.uni[t] {
        gt_x = kf.add(&gt_x, &kf.mul(a, &xp));
        xp = kf.mul(&xp, x);
    }
    let mut acc = kf.scale(kf.zq.to_mod(1i64 << n_suffix), &kf.add(prefix_sum, &gt_x));
    if n_suffix >= 1 {
        acc = kf.add(&acc, &kf.scale(kf.zq.to_mod(1i64 << (n_suffix - 1)), tail_ones));
    }
    acc
}

/// The correction term's round evaluation (layer j >= 2, supported on
/// b = 0): sum over the suffix of eq(b, 0) * E * cv(w) where
/// cv(w) = Rp(mu_prev, w) + lambda Rq(mu_prev, w). During b-rounds the
/// w-suffix contributes cv(0) + cv(1) = SP-type sums; the b-suffix
/// contributes factor 1; the prefix contributes prod (1 - r_s); the
/// free variable contributes (1 - X). During the w-round cv(X) is
/// evaluated directly.
struct CorrCtx {
    e: KElem,           // z_2 (1 - z_2) of the incoming claim point
    mu_prev: KElem,     // the incoming claim's first coordinate
    cv0_plus_cv1: KElem, // cv(0) + cv(1)
}

/// Prove the masked descent for L same-shape trees (blinder-extended
/// leaves included by the caller). The transcript must already bind
/// the mask commitments (before alpha, upstream) and everything the
/// unmasked descent binds. Returns (proof, z*, p-claim, q-claim) over
/// the concatenated leaf table — the AGGREGATE leaf interface: the
/// caller pins the claims with the P-pin/Q-pin E4 rows (U-K5c); no
/// per-column MLE value is ever sent.
pub fn masked_gkr_prove(
    kf: &KField,
    trees: &[FracTree],
    masks: &MaskSet,
    tr: &mut LkpTranscript,
) -> (MaskedDescentProof, Vec<KElem>, KElem, KElem) {
    let l = trees.len();
    assert!(l.is_power_of_two());
    let e_bits = l.trailing_zeros() as usize;
    let depth = trees[0].depth();
    assert!(depth >= 2, "masked descent needs depth >= 2");
    // Layer-1 quadruples; roots are derived, never sent.
    let layer1: Vec<[KElem; 4]> = trees
        .iter()
        .map(|t| {
            [
                t.layers_p[1][0].clone(),
                t.layers_p[1][1].clone(),
                t.layers_q[1][0].clone(),
                t.layers_q[1][1].clone(),
            ]
        })
        .collect();
    for q in &layer1 {
        tr.absorb_k(kf, "mgkr-layer1", q);
    }
    // Instance coordinates + the first fold: claims start at layer 1.
    let z_e: Vec<KElem> = (0..e_bits).map(|_| tr.challenge_k(kf)).collect();
    let mu0 = tr.challenge_k(kf);
    // p_1 viewed over (child bit, e): fold e at z_e then the bit at mu0.
    let fold_layer1 = |idx: usize| -> KElem {
        // entries: per instance e, child c: layer1[e][idx*2 + c]
        let at_c = |c: usize| -> KElem {
            let col: Vec<KElem> = layer1.iter().map(|q| q[idx * 2 + c].clone()).collect();
            super::sumcheck::mle_eval(kf, &col, &z_e)
        };
        let (v0, v1) = (at_c(0), at_c(1));
        kf.add(&v0, &kf.mul(&mu0, &kf.sub(&v1, &v0)))
    };
    let mut p_claim = fold_layer1(0);
    let mut q_claim = fold_layer1(1);
    let mut zeta = vec![mu0];
    zeta.extend(z_e.clone());
    let mut layers = Vec::with_capacity(depth - 1);
    for j in 1..depth {
        let lambda = tr.challenge_k(kf);
        let mut c_run = kf.add(&p_claim, &kf.mul(&lambda, &q_claim));
        let n_bvars = j + e_bits;
        let child_masked = j <= depth - 2;
        // Child tables over (e << j | b), c in {0, 1} split out.
        let size = l << j;
        let eqt = eq_table(kf, &zeta);
        assert_eq!(eqt.len(), size);
        let (mut p0, mut p1, mut q0, mut q1) =
            (Vec::with_capacity(size), Vec::with_capacity(size), Vec::with_capacity(size), Vec::with_capacity(size));
        for i in 0..size {
            let (e, b) = (i >> j, i & ((1 << j) - 1));
            p0.push(trees[e].layers_p[j + 1][2 * b].clone());
            p1.push(trees[e].layers_p[j + 1][2 * b + 1].clone());
            q0.push(trees[e].layers_q[j + 1][2 * b].clone());
            q1.push(trees[e].layers_q[j + 1][2 * b + 1].clone());
        }
        // Child-mask constants: SP_{j+1}(c) for c in {0,1}, p and q.
        let (spp, spq) = if child_masked {
            let (rp, rq) = &masks.r[j + 1 - 2];
            (
                [eval_sp(kf, rp, &kf.zero()), eval_sp(kf, rp, &kf.one())],
                [eval_sp(kf, rq, &kf.zero()), eval_sp(kf, rq, &kf.one())],
            )
        } else {
            ([kf.zero(), kf.zero()], [kf.zero(), kf.zero()])
        };
        // Correction context (j >= 2): repays the incoming claim's mask.
        let corr = if j >= 2 {
            let (rp_j, rq_j) = &masks.r[j - 2];
            let e_fac = kf.mul(&zeta[1], &kf.sub(&kf.one(), &zeta[1]));
            assert!(!kf.is_zero(&e_fac), "degenerate suffix challenge (restart guard)");
            let cv = |w: &KElem| {
                kf.add(&eval_r(kf, rp_j, &zeta[0], w), &kf.mul(&lambda, &eval_r(kf, rq_j, &zeta[0], w)))
            };
            Some(CorrCtx {
                e: e_fac,
                mu_prev: zeta[0].clone(),
                cv0_plus_cv1: kf.add(&cv(&kf.zero()), &cv(&kf.one())),
            })
        } else {
            None
        };
        // nu and the pinned hypersum.
        let gm = &masks.g[j - 1];
        let g_sum = gm.hypersum(kf);
        tr.absorb_k(kf, "mgkr-gsum", std::slice::from_ref(&g_sum));
        let nu = {
            let mut e = tr.challenge_k(kf);
            while kf.is_zero(&e) {
                e = tr.challenge_k(kf);
            }
            e
        };
        c_run = kf.add(&c_run, &kf.mul(&nu, &g_sum));
        // The rounds. State: multilinear tables (folded per b-round),
        // eq-prefix factor, corr-prefix factor, g partial sums.
        let degs = sc_degrees(n_bvars, child_masked);
        let mut rounds: Vec<Vec<KElem>> = Vec::with_capacity(n_bvars + 1);
        let mut rs: Vec<KElem> = Vec::with_capacity(n_bvars + 1);
        let mut g_prefix = gm.a0.clone();
        let mut g_tail: Vec<KElem> = {
            // tail_ones[t] = sum_{s>t} g_s(1)
            let ones: Vec<KElem> = gm
                .uni
                .iter()
                .map(|c| c.iter().fold(kf.zero(), |a, x| kf.add(&a, x)))
                .collect();
            let mut tail = vec![kf.zero(); ones.len()];
            for t in (0..ones.len().saturating_sub(1)).rev() {
                tail[t] = kf.add(&tail[t + 1], &ones[t + 1]);
            }
            tail
        };
        if g_tail.is_empty() {
            g_tail = vec![kf.zero()];
        }
        let mut corr_prefix = kf.one(); // prod over bound b vars of (1 - r)
        let mut eq_cur = eqt;
        let (mut p0c, mut p1c, mut q0c, mut q1c) = (p0, p1, q0, q1);
        for t in 0..=n_bvars {
            let d = degs[t];
            let mut evals = vec![kf.zero(); d + 1];
            if t < n_bvars {
                // A b-round: fold-extrapolate the multilinear tables.
                let half = eq_cur.len() / 2;
                for (x, ev) in evals.iter_mut().enumerate() {
                    let xk = kf.embed(x as u64);
                    let zz = if t == 0 && child_masked {
                        // Z-hat(X) = X(1 - X) — the child-mask factor
                        // rides the FIRST b-variable.
                        kf.mul(&xk, &kf.sub(&kf.one(), &xk))
                    } else {
                        kf.zero()
                    };
                    let mut acc = kf.zero();
                    for i in 0..half.max(1) {
                        let ext = |tb: &Vec<KElem>| -> KElem {
                            if half == 0 {
                                return tb[0].clone();
                            }
                            let dlt = kf.sub(&tb[2 * i + 1], &tb[2 * i]);
                            kf.add(&tb[2 * i], &kf.mul(&xk, &dlt))
                        };
                        let eqv = ext(&eq_cur);
                        let (mut vp0, mut vp1, mut vq0, mut vq1) =
                            (ext(&p0c), ext(&p1c), ext(&q0c), ext(&q1c));
                        if t == 0 && child_masked {
                            vp0 = kf.add(&vp0, &kf.mul(&zz, &spp[0]));
                            vp1 = kf.add(&vp1, &kf.mul(&zz, &spp[1]));
                            vq0 = kf.add(&vq0, &kf.mul(&zz, &spq[0]));
                            vq1 = kf.add(&vq1, &kf.mul(&zz, &spq[1]));
                        }
                        let wire = kf.add(
                            &kf.add(&kf.mul(&vp0, &vq1), &kf.mul(&vp1, &vq0)),
                            &kf.mul(&lambda, &kf.mul(&vq0, &vq1)),
                        );
                        acc = kf.add(&acc, &kf.mul(&eqv, &wire));
                    }
                    // The (1 - w) suffix over w sums to 1 — wire term
                    // unchanged. Correction: prefix * (1 - X) * E *
                    // (cv(0) + cv(1)).
                    if let Some(cc) = &corr {
                        let fx = kf.mul(&corr_prefix, &kf.sub(&kf.one(), &xk));
                        acc = kf.add(&acc, &kf.mul(&fx, &kf.mul(&cc.e, &cc.cv0_plus_cv1)));
                    }
                    // g-mask: analytic suffix sum.
                    let gv = g_round_eval(kf, gm, &g_prefix, t, &xk, &g_tail[t]);
                    acc = kf.add(&acc, &kf.mul(&nu, &gv));
                    *ev = acc;
                }
            } else {
                // The w-round: tables are folded to constants.
                let (bp0, bp1, bq0, bq1) =
                    (p0c[0].clone(), p1c[0].clone(), q0c[0].clone(), q1c[0].clone());
                // These constants ALREADY include the child-mask
                // constant folded in after round 0.
                let eqv = eq_cur[0].clone();
                let wire = kf.add(
                    &kf.add(&kf.mul(&bp0, &bq1), &kf.mul(&bp1, &bq0)),
                    &kf.mul(&lambda, &kf.mul(&bq0, &bq1)),
                );
                for (x, ev) in evals.iter_mut().enumerate() {
                    let xk = kf.embed(x as u64);
                    let mut acc = kf.mul(&kf.sub(&kf.one(), &xk), &kf.mul(&eqv, &wire));
                    if let Some(cc) = &corr {
                        let (rp_j, rq_j) = &masks.r[j - 2];
                        let cv = kf.add(
                            &eval_r(kf, rp_j, &cc.mu_prev, &xk),
                            &kf.mul(&lambda, &eval_r(kf, rq_j, &cc.mu_prev, &xk)),
                        );
                        acc = kf.add(&acc, &kf.mul(&corr_prefix, &kf.mul(&cc.e, &cv)));
                    }
                    let gv = g_round_eval(kf, gm, &g_prefix, t, &xk, &kf.zero());
                    acc = kf.add(&acc, &kf.mul(&nu, &gv));
                    *ev = acc;
                }
            }
            debug_assert_eq!(kf.add(&evals[0], &evals[1]), c_run, "honest round broke");
            tr.absorb_k(kf, "mgkr-round", &evals);
            let r = tr.challenge_k(kf);
            c_run = lagrange_eval(kf, &evals, &r);
            if t < n_bvars {
                let fold = |tb: &Vec<KElem>| -> Vec<KElem> { super::sumcheck::fold(kf, tb, &r) };
                eq_cur = fold(&eq_cur);
                p0c = fold(&p0c);
                p1c = fold(&p1c);
                q0c = fold(&q0c);
                q1c = fold(&q1c);
                if t == 0 && child_masked {
                    // Fold the child-mask constant zz * SP(c) into the
                    // tables — downstream rounds see plain multilinears.
                    let zz = kf.mul(&r, &kf.sub(&kf.one(), &r));
                    for e in p0c.iter_mut() {
                        *e = kf.add(e, &kf.mul(&zz, &spp[0]));
                    }
                    for e in p1c.iter_mut() {
                        *e = kf.add(e, &kf.mul(&zz, &spp[1]));
                    }
                    for e in q0c.iter_mut() {
                        *e = kf.add(e, &kf.mul(&zz, &spq[0]));
                    }
                    for e in q1c.iter_mut() {
                        *e = kf.add(e, &kf.mul(&zz, &spq[1]));
                    }
                }
                // g prefix: absorb g_t(r).
                let mut gt_r = kf.zero();
                let mut xp = r.clone();
                for a in &gm.uni[t] {
                    gt_r = kf.add(&gt_r, &kf.mul(a, &xp));
                    xp = kf.mul(&xp, &r);
                }
                g_prefix = kf.add(&g_prefix, &gt_r);
                corr_prefix = kf.mul(&corr_prefix, &kf.sub(&kf.one(), &r));
            }
            rounds.push(evals);
            rs.push(r);
        }
        let c_w = rs[n_bvars].clone();
        let r_b: Vec<KElem> = rs[0..n_bvars].to_vec();
        // Boundary values: masked child MLEs at (c, r_b) — the folded
        // tables hold exactly these.
        let boundary =
            [p0c[0].clone(), p1c[0].clone(), q0c[0].clone(), q1c[0].clone()];
        tr.absorb_k(kf, "mgkr-boundary", &boundary);
        // Openings (E4-pinned by the caller).
        let mut open_pt = r_b.clone();
        open_pt.push(c_w.clone());
        let open_g = gm.eval(kf, &open_pt);
        let open_r = corr.as_ref().map(|cc| {
            let (rp_j, rq_j) = &masks.r[j - 2];
            (eval_r(kf, rp_j, &cc.mu_prev, &c_w), eval_r(kf, rq_j, &cc.mu_prev, &c_w))
        });
        tr.absorb_k(kf, "mgkr-open-g", std::slice::from_ref(&open_g));
        if let Some((a, b)) = &open_r {
            tr.absorb_k(kf, "mgkr-open-rp", std::slice::from_ref(a));
            tr.absorb_k(kf, "mgkr-open-rq", std::slice::from_ref(b));
        }
        let mu = tr.challenge_k(kf);
        p_claim = kf.add(&boundary[0], &kf.mul(&mu, &kf.sub(&boundary[1], &boundary[0])));
        q_claim = kf.add(&boundary[2], &kf.mul(&mu, &kf.sub(&boundary[3], &boundary[2])));
        let mut nz = vec![mu];
        nz.extend(r_b);
        zeta = nz;
        layers.push(MaskedLayerProof { g_sum, rounds, boundary, open_g, open_r });
    }
    (MaskedDescentProof { layer1, layers }, zeta, p_claim, q_claim)
}

/// Verify the masked descent. `masks` = the committed mask set (the
/// verifier evaluates the pins itself here; in the full protocol the
/// openings are E4-pinned against the mask COMMITMENTS and this
/// function receives the opened values as claims — the battery models
/// commitment pinning by exact recomputation, the U-K5c wiring routes
/// them through the psi batch). Returns (derived per-instance roots,
/// z*, p-claim, q-claim); the caller runs the root cross-check and
/// the aggregate leaf pins.
#[allow(clippy::type_complexity)]
pub fn masked_gkr_verify(
    kf: &KField,
    l: usize,
    depth: usize,
    masks: &MaskSet,
    proof: &MaskedDescentProof,
    tr: &mut LkpTranscript,
    pin: bool,
) -> Option<(Vec<[KElem; 2]>, Vec<KElem>, KElem, KElem)> {
    if !l.is_power_of_two() || proof.layer1.len() != l || proof.layers.len() != depth - 1 {
        return None;
    }
    let e_bits = l.trailing_zeros() as usize;
    // Derived roots + cross-check material.
    let roots: Vec<[KElem; 2]> = proof
        .layer1
        .iter()
        .map(|q| {
            [
                kf.add(&kf.mul(&q[0], &q[3]), &kf.mul(&q[1], &q[2])),
                kf.mul(&q[2], &q[3]),
            ]
        })
        .collect();
    for q in &proof.layer1 {
        tr.absorb_k(kf, "mgkr-layer1", q);
    }
    let z_e: Vec<KElem> = (0..e_bits).map(|_| tr.challenge_k(kf)).collect();
    let mu0 = tr.challenge_k(kf);
    let fold_layer1 = |idx: usize| -> KElem {
        let at_c = |c: usize| -> KElem {
            let col: Vec<KElem> = proof.layer1.iter().map(|q| q[idx * 2 + c].clone()).collect();
            super::sumcheck::mle_eval(kf, &col, &z_e)
        };
        let (v0, v1) = (at_c(0), at_c(1));
        kf.add(&v0, &kf.mul(&mu0, &kf.sub(&v1, &v0)))
    };
    let mut p_claim = fold_layer1(0);
    let mut q_claim = fold_layer1(1);
    let mut zeta = vec![mu0];
    zeta.extend(z_e);
    for j in 1..depth {
        let lp = &proof.layers[j - 1];
        let lambda = tr.challenge_k(kf);
        let mut c_run = kf.add(&p_claim, &kf.mul(&lambda, &q_claim));
        let n_bvars = j + e_bits;
        let child_masked = j <= depth - 2;
        let degs = sc_degrees(n_bvars, child_masked);
        if lp.rounds.len() != n_bvars + 1 {
            return None;
        }
        if pin && lp.g_sum != masks.g[j - 1].hypersum(kf) {
            return None;
        }
        tr.absorb_k(kf, "mgkr-gsum", std::slice::from_ref(&lp.g_sum));
        let nu = {
            let mut e = tr.challenge_k(kf);
            while kf.is_zero(&e) {
                e = tr.challenge_k(kf);
            }
            e
        };
        c_run = kf.add(&c_run, &kf.mul(&nu, &lp.g_sum));
        let mut rs: Vec<KElem> = Vec::with_capacity(n_bvars + 1);
        for (t, evals) in lp.rounds.iter().enumerate() {
            if evals.len() != degs[t] + 1 {
                return None;
            }
            if kf.add(&evals[0], &evals[1]) != c_run {
                return None;
            }
            tr.absorb_k(kf, "mgkr-round", evals);
            let r = tr.challenge_k(kf);
            c_run = lagrange_eval(kf, evals, &r);
            rs.push(r);
        }
        let c_w = rs[n_bvars].clone();
        let r_b: Vec<KElem> = rs[0..n_bvars].to_vec();
        let [vp0, vp1, vq0, vq1] = lp.boundary.clone();
        let eqzr = eq_eval(kf, &zeta, &r_b);
        let wire = kf.add(
            &kf.add(&kf.mul(&vp0, &vq1), &kf.mul(&vp1, &vq0)),
            &kf.mul(&lambda, &kf.mul(&vq0, &vq1)),
        );
        let mut expect = kf.mul(&kf.sub(&kf.one(), &c_w), &kf.mul(&eqzr, &wire));
        if j >= 2 {
            let e_fac = kf.mul(&zeta[1], &kf.sub(&kf.one(), &zeta[1]));
            let mut eqb0 = kf.one();
            for rt in &r_b {
                eqb0 = kf.mul(&eqb0, &kf.sub(&kf.one(), rt));
            }
            let Some((orp, orq)) = &lp.open_r else { return None };
            if pin {
                let (rp_j, rq_j) = &masks.r[j - 2];
                if *orp != eval_r(kf, rp_j, &zeta[0], &c_w)
                    || *orq != eval_r(kf, rq_j, &zeta[0], &c_w)
                {
                    return None;
                }
            }
            let cv = kf.add(orp, &kf.mul(&lambda, orq));
            expect = kf.add(&expect, &kf.mul(&eqb0, &kf.mul(&e_fac, &cv)));
        } else if lp.open_r.is_some() {
            return None;
        }
        if pin {
            let mut open_pt = r_b.clone();
            open_pt.push(c_w.clone());
            if lp.open_g != masks.g[j - 1].eval(kf, &open_pt) {
                return None;
            }
        }
        expect = kf.add(&expect, &kf.mul(&nu, &lp.open_g));
        if c_run != expect {
            return None;
        }
        tr.absorb_k(kf, "mgkr-boundary", &lp.boundary);
        tr.absorb_k(kf, "mgkr-open-g", std::slice::from_ref(&lp.open_g));
        if let Some((a, b)) = &lp.open_r {
            tr.absorb_k(kf, "mgkr-open-rp", std::slice::from_ref(a));
            tr.absorb_k(kf, "mgkr-open-rq", std::slice::from_ref(b));
        }
        let mu = tr.challenge_k(kf);
        p_claim = kf.add(&vp0, &kf.mul(&mu, &kf.sub(&vp1, &vp0)));
        q_claim = kf.add(&vq0, &kf.mul(&mu, &kf.sub(&vq1, &vq0)));
        let mut nz = vec![mu];
        nz.extend(r_b);
        zeta = nz;
    }
    Some((roots, zeta, p_claim, q_claim))
}

// ---------------------------------------------------------------------------
// M3: blinder leaves (U-K5c).

/// One blinder: a committed fraction (a, u), u != 0. Its mass a/u is
/// constant in alpha, so it can never alias a table pole.
#[derive(Clone)]
pub struct Blinder {
    pub a: KElem,
    pub u: KElem,
}

/// Per-tree blinder block: tL, tR (top — randomize the layer-1 values
/// and hence the derived roots), f0, f1 (final — pad the last
/// boundary; one per parity).
pub struct BlinderSet {
    pub tl: Blinder,
    pub tr: Blinder,
    pub f0: Blinder,
    pub f1: Blinder,
}

impl BlinderSet {
    pub fn draw(kf: &KField, t: &mut LkpTranscript) -> BlinderSet {
        let mut mk = || {
            let a = t.challenge_k(kf);
            let mut u = t.challenge_k(kf);
            while kf.is_zero(&u) {
                u = t.challenge_k(kf);
            }
            Blinder { a, u }
        };
        BlinderSet { tl: mk(), tr: mk(), f0: mk(), f1: mk() }
    }

    pub fn mass(&self, kf: &KField) -> KElem {
        [&self.tl, &self.tr, &self.f0, &self.f1]
            .iter()
            .fold(kf.zero(), |acc, b| kf.add(&acc, &kf.mul(&b.a, &kf.inv(&b.u))))
    }

    /// The completeness solve: set self.tr.a so this set's mass equals
    /// beta_target (the witness side's mass) — the modified root
    /// cross-check's condition.
    pub fn solve_mass(&mut self, kf: &KField, beta_target: &KElem) {
        let rest = [&self.tl, &self.f0, &self.f1]
            .iter()
            .fold(kf.zero(), |acc, b| kf.add(&acc, &kf.mul(&b.a, &kf.inv(&b.u))));
        self.tr.a = kf.mul(&self.tr.u, &kf.sub(beta_target, &rest));
    }
}

/// The fixed public blinder positions in a 2^depth leaf layer (freeze
/// row LKP-6): tL in the left half, tR in the right half, f0 at an
/// even index, f1 at an odd index.
pub fn blinder_positions(n: usize) -> [usize; 4] {
    [n / 2 - 4, n - 4, n / 2 - 2, n - 3] // tL, tR, f0, f1
}

/// Install a blinder set into (p, q) leaf vectors (dummies (0,1)
/// elsewhere are the caller's padding).
pub fn install_blinders(kf: &KField, p: &mut [KElem], q: &mut [KElem], bl: &BlinderSet) {
    let _ = kf;
    let pos = blinder_positions(p.len());
    let items = [&bl.tl, &bl.tr, &bl.f0, &bl.f1];
    for (k, b) in items.iter().enumerate() {
        p[pos[k]] = b.a.clone();
        q[pos[k]] = b.u.clone();
    }
}

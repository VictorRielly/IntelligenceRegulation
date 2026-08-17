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

use super::ct_engine::prof;
use super::gkr::{FracTree, eq_eval, eq_table, extract_children, extract_children_par};
use super::kfield::{KElem, KField, KL, k9_addc_blocks, k9_round_g5_par, k9_round_g_blocks, kop};
use super::sumcheck::{LkpTranscript, lagrange_eval};
use super::{ProverRng, rng_below};

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
///
/// FRESHNESS IS STRUCTURAL, NOT FLAGGED (C-01 remediation, U-S P1-D2).
/// A mask set is CONSUMED BY VALUE by `masked_gkr_prove`: after a pass
/// the object is moved and cannot be used again — a second prove with
/// the same binding is a COMPILE error, not a runtime flag check. There
/// is deliberately no `Clone`; the sole way to obtain a second identical
/// set is [`MaskSet::harness_clone`], whose name marks it as an
/// attack-modelling tool. Per-session freshness comes from OS entropy
/// (`draw_masks` requires a `ProverRng`, seeded from the kernel CSPRNG
/// on production paths); the leak returns only when an attacker reuses
/// the SAME coefficients (the E3Z-N3 / [U-S1] demonstrations clone
/// explicitly to model exactly that).
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
    pub fn draw(kf: &KField, rng: &mut ProverRng, degs: &[usize]) -> GMask {
        GMask {
            a0: random_k(kf, rng),
            uni: degs.iter().map(|&d| (0..d).map(|_| random_k(kf, rng)).collect()).collect(),
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

fn random_k(kf: &KField, rng: &mut ProverRng) -> KElem {
    (0..super::kfield::K_DEG).map(|_| rng_below(rng, kf.zq.q)).collect()
}

pub fn draw_rmask(kf: &KField, rng: &mut ProverRng) -> RMask {
    std::array::from_fn(|_| std::array::from_fn(|_| random_k(kf, rng)))
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
/// from prover-private CSPRNG state. The caller commits the coefficients
/// before alpha and binds those commitments into h0_lkp. Fiat-Shamir state
/// is deliberately not accepted here: public statement data is not entropy.
pub fn draw_masks(kf: &KField, rng: &mut ProverRng, depth: usize, n_extra: usize) -> MaskSet {
    let g = (1..depth)
        .map(|j| {
            let degs = sc_degrees(j + n_extra, j <= depth - 2);
            GMask::draw(kf, rng, &degs)
        })
        .collect();
    let r = (2..depth).map(|_| (draw_rmask(kf, rng), draw_rmask(kf, rng))).collect();
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

impl MaskSet {
    /// HARNESS/ATTACK-MODELLING ONLY: deep-copy the mask coefficients.
    /// The shipped prover has NO reuse path — it consumes a `MaskSet` by
    /// value and there is no `Clone`; this named method is the only way
    /// to obtain a second identical set, and every caller is a battery
    /// that MODELS reuse (the E3Z-N3 / [U-S1] leak demonstrations and the
    /// rank-canary probes that perturb one coefficient and re-run). Gated
    /// behind `cfg(test)` / the `harness` feature (audit 2026-07-14
    /// H-01): a production `--no-default-features` build has no
    /// mask-duplication symbol at all.
    #[cfg(any(test, feature = "harness"))]
    pub fn harness_clone(&self) -> MaskSet {
        MaskSet {
            g: self
                .g
                .iter()
                .map(|g| GMask { a0: g.a0.clone(), uni: g.uni.clone() })
                .collect(),
            r: self.r.clone(),
        }
    }

    /// The committed flattening (the layout every pin row uses, pinned
    /// by LKP-6): g_1.coeffs(), .., g_{K-1}.coeffs(), then per interior
    /// layer j = 2..K-1: Rp_j then Rq_j, each row-major
    /// (c[0][0..3], c[1][0..3] — the eval_r loop order).
    pub fn flatten(&self) -> Vec<KElem> {
        let mut out = Vec::new();
        for g in &self.g {
            out.extend(g.coeffs());
        }
        for (rp, rq) in &self.r {
            for r in [rp, rq] {
                for row in r.iter() {
                    out.extend(row.iter().cloned());
                }
            }
        }
        out
    }

    /// Flat offset of g_j's coefficient block (j is 1-based).
    pub fn g_offset(&self, j: usize) -> usize {
        self.g[..j - 1].iter().map(|g| 1 + g.uni.iter().map(|c| c.len()).sum::<usize>()).sum()
    }

    pub fn g_len(&self, j: usize) -> usize {
        1 + self.g[j - 1].uni.iter().map(|c| c.len()).sum::<usize>()
    }

    /// Flat offset of Rp_j (Rq_j = +6); j is 2-based.
    pub fn r_offset(&self, j: usize) -> usize {
        let g_total: usize =
            self.g.iter().map(|g| 1 + g.uni.iter().map(|c| c.len()).sum::<usize>()).sum();
        g_total + 12 * (j - 2)
    }
}

/// The pin weights of one opened value over its coefficient block
/// (kappa per committed K-element): G_j = integer weights (2^ell on
/// a0, 2^(ell-1) on every univariate coefficient); open_g at pt =
/// powers (1 on a0, pt_t^(i+1) on coefficient (t, i)); open_R at
/// (z1, w) = z1^i w^j per coefficient, row-major.
pub fn g_hypersum_weights(kf: &KField, gm: &GMask) -> Vec<KElem> {
    let ell = gm.uni.len();
    let mut w = vec![kf.embed(kf.zq.to_mod(1i64 << ell))];
    let half = kf.embed(kf.zq.to_mod(1i64 << (ell - 1)));
    for c in &gm.uni {
        for _ in c {
            w.push(half.clone());
        }
    }
    w
}

pub fn g_open_weights(kf: &KField, gm: &GMask, pt: &[KElem]) -> Vec<KElem> {
    let mut w = vec![kf.one()];
    for (c, x) in gm.uni.iter().zip(pt.iter()) {
        let mut xp = x.clone();
        for _ in c {
            w.push(xp.clone());
            xp = kf.mul(&xp, x);
        }
    }
    w
}

pub fn r_open_weights(kf: &KField, z1: &KElem, w: &KElem) -> Vec<KElem> {
    let mut out = Vec::with_capacity(6);
    let mut z1p = kf.one();
    for _ in 0..2 {
        let mut wp = kf.one();
        for _ in 0..3 {
            out.push(kf.mul(&z1p, &wp));
            wp = kf.mul(&wp, w);
        }
        z1p = kf.mul(&z1p, z1);
    }
    out
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

/// The descent's public endpoint, shared by prover and verifier: the
/// final point and claims (the aggregate leaf pins' subjects) plus the
/// per-layer opening points the E4 pin rows are built at — for layer
/// j: (the g opening point r_b ++ c_w, z1 = the incoming claim's first
/// coordinate = mu_{j-1} for the R openings, and c_w itself).
pub struct DescentEnd {
    pub zstar: Vec<KElem>,
    pub p_claim: KElem,
    pub q_claim: KElem,
    pub layer_pts: Vec<(Vec<KElem>, KElem, KElem)>,
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

/// U-K9: the per-layer inputs shared by the scalar and bulk rounds
/// implementations (bit-identical transcripts).
struct MaskedLayerCtx<'a> {
    j: usize,
    child_masked: bool,
    lambda: &'a KElem,
    spp: &'a [KElem; 2],
    spq: &'a [KElem; 2],
    corr: Option<&'a CorrCtx>,
    masks: &'a MaskSet,
    gm: &'a GMask,
    nu: &'a KElem,
}

/// tail_ones[t] = sum_{s>t} g_s(1) — the analytic g-mask suffix table.
fn g_tail_ones(kf: &KField, gm: &GMask) -> Vec<KElem> {
    let ones: Vec<KElem> =
        gm.uni.iter().map(|c| c.iter().fold(kf.zero(), |a, x| kf.add(&a, x))).collect();
    let mut tail = vec![kf.zero(); ones.len()];
    for t in (0..ones.len().saturating_sub(1)).rev() {
        tail[t] = kf.add(&tail[t + 1], &ones[t + 1]);
    }
    if tail.is_empty() {
        tail = vec![kf.zero()];
    }
    tail
}

/// One masked b-round's evaluations, scalar (the original loop body).
#[allow(clippy::too_many_arguments)]
fn masked_b_round_evals(
    kf: &KField,
    d: usize,
    t: usize,
    lay: &MaskedLayerCtx,
    eq_cur: &[KElem],
    p0c: &[KElem],
    p1c: &[KElem],
    q0c: &[KElem],
    q1c: &[KElem],
    corr_prefix: &KElem,
    g_prefix: &KElem,
    g_tail_t: &KElem,
) -> Vec<KElem> {
    let mut evals = vec![kf.zero(); d + 1];
    let half = eq_cur.len() / 2;
    for (x, ev) in evals.iter_mut().enumerate() {
        let xk = kf.embed(x as u64);
        let zz = if t == 0 && lay.child_masked {
            // Z-hat(X) = X(1 - X) — the child-mask factor rides the
            // FIRST b-variable.
            kf.mul(&xk, &kf.sub(&kf.one(), &xk))
        } else {
            kf.zero()
        };
        let mut acc = kf.zero();
        for i in 0..half.max(1) {
            let ext = |tb: &[KElem]| -> KElem {
                if half == 0 {
                    return tb[0].clone();
                }
                let dlt = kf.sub(&tb[2 * i + 1], &tb[2 * i]);
                kf.add(&tb[2 * i], &kf.mul(&xk, &dlt))
            };
            let eqv = ext(eq_cur);
            let (mut vp0, mut vp1, mut vq0, mut vq1) =
                (ext(p0c), ext(p1c), ext(q0c), ext(q1c));
            if t == 0 && lay.child_masked {
                vp0 = kf.add(&vp0, &kf.mul(&zz, &lay.spp[0]));
                vp1 = kf.add(&vp1, &kf.mul(&zz, &lay.spp[1]));
                vq0 = kf.add(&vq0, &kf.mul(&zz, &lay.spq[0]));
                vq1 = kf.add(&vq1, &kf.mul(&zz, &lay.spq[1]));
            }
            let wire = kf.add(
                &kf.add(&kf.mul(&vp0, &vq1), &kf.mul(&vp1, &vq0)),
                &kf.mul(lay.lambda, &kf.mul(&vq0, &vq1)),
            );
            acc = kf.add(&acc, &kf.mul(&eqv, &wire));
        }
        // The (1 - w) suffix over w sums to 1 — wire term unchanged.
        // Correction: prefix * (1 - X) * E * (cv(0) + cv(1)).
        if let Some(cc) = lay.corr {
            let fx = kf.mul(corr_prefix, &kf.sub(&kf.one(), &xk));
            acc = kf.add(&acc, &kf.mul(&fx, &kf.mul(&cc.e, &cc.cv0_plus_cv1)));
        }
        // g-mask: analytic suffix sum.
        let gv = g_round_eval(kf, lay.gm, g_prefix, t, &xk, g_tail_t);
        acc = kf.add(&acc, &kf.mul(lay.nu, &gv));
        *ev = acc;
    }
    evals
}

/// The masked w-round's evaluations (tables folded to constants).
#[allow(clippy::too_many_arguments)]
fn masked_w_round_evals(
    kf: &KField,
    d: usize,
    t: usize,
    lay: &MaskedLayerCtx,
    bp0: &KElem,
    bp1: &KElem,
    bq0: &KElem,
    bq1: &KElem,
    eqv: &KElem,
    corr_prefix: &KElem,
    g_prefix: &KElem,
) -> Vec<KElem> {
    let mut evals = vec![kf.zero(); d + 1];
    let wire = kf.add(
        &kf.add(&kf.mul(bp0, bq1), &kf.mul(bp1, bq0)),
        &kf.mul(lay.lambda, &kf.mul(bq0, bq1)),
    );
    for (x, ev) in evals.iter_mut().enumerate() {
        let xk = kf.embed(x as u64);
        let mut acc = kf.mul(&kf.sub(&kf.one(), &xk), &kf.mul(eqv, &wire));
        if let Some(cc) = lay.corr {
            let (rp_j, rq_j) = &lay.masks.r[lay.j - 2];
            let cv = kf.add(
                &eval_r(kf, rp_j, &cc.mu_prev, &xk),
                &kf.mul(lay.lambda, &eval_r(kf, rq_j, &cc.mu_prev, &xk)),
            );
            acc = kf.add(&acc, &kf.mul(corr_prefix, &kf.mul(&cc.e, &cv)));
        }
        let gv = g_round_eval(kf, lay.gm, g_prefix, t, &xk, &kf.zero());
        acc = kf.add(&acc, &kf.mul(lay.nu, &gv));
        *ev = acc;
    }
    evals
}

/// The original scalar rounds loop of one masked layer (the U-K9
/// differential-oracle path; also q46-class moduli and sub-block sizes).
fn masked_rounds_scalar(
    kf: &KField,
    trees: &[FracTree],
    e_bits: usize,
    zeta: &[KElem],
    lay: &MaskedLayerCtx,
    mut c_run: KElem,
    tr: &mut LkpTranscript,
) -> (Vec<Vec<KElem>>, Vec<KElem>, [KElem; 4]) {
    let j = lay.j;
    let n_bvars = j + e_bits;
    let size = trees.len() << j;
    let eqt = eq_table(kf, zeta);
    assert_eq!(eqt.len(), size);
    let (mut p0, mut p1, mut q0, mut q1) = (
        Vec::with_capacity(size),
        Vec::with_capacity(size),
        Vec::with_capacity(size),
        Vec::with_capacity(size),
    );
    for i in 0..size {
        let (e, b) = (i >> j, i & ((1 << j) - 1));
        p0.push(trees[e].p_elem(j + 1, 2 * b));
        p1.push(trees[e].p_elem(j + 1, 2 * b + 1));
        q0.push(trees[e].q_elem(j + 1, 2 * b));
        q1.push(trees[e].q_elem(j + 1, 2 * b + 1));
    }
    let degs = sc_degrees(n_bvars, lay.child_masked);
    let mut rounds: Vec<Vec<KElem>> = Vec::with_capacity(n_bvars + 1);
    let mut rs: Vec<KElem> = Vec::with_capacity(n_bvars + 1);
    let mut g_prefix = lay.gm.a0.clone();
    let g_tail = g_tail_ones(kf, lay.gm);
    let mut corr_prefix = kf.one(); // prod over bound b vars of (1 - r)
    let mut eq_cur = eqt;
    let (mut p0c, mut p1c, mut q0c, mut q1c) = (p0, p1, q0, q1);
    for t in 0..=n_bvars {
        let d = degs[t];
        let evals = if t < n_bvars {
            masked_b_round_evals(
                kf, d, t, lay, &eq_cur, &p0c, &p1c, &q0c, &q1c, &corr_prefix, &g_prefix,
                &g_tail[t],
            )
        } else {
            masked_w_round_evals(
                kf, d, t, lay, &p0c[0], &p1c[0], &q0c[0], &q1c[0], &eq_cur[0], &corr_prefix,
                &g_prefix,
            )
        };
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
            if t == 0 && lay.child_masked {
                // Fold the child-mask constant zz * SP(c) into the
                // tables — downstream rounds see plain multilinears.
                let zz = kf.mul(&r, &kf.sub(&kf.one(), &r));
                for e in p0c.iter_mut() {
                    *e = kf.add(e, &kf.mul(&zz, &lay.spp[0]));
                }
                for e in p1c.iter_mut() {
                    *e = kf.add(e, &kf.mul(&zz, &lay.spp[1]));
                }
                for e in q0c.iter_mut() {
                    *e = kf.add(e, &kf.mul(&zz, &lay.spq[0]));
                }
                for e in q1c.iter_mut() {
                    *e = kf.add(e, &kf.mul(&zz, &lay.spq[1]));
                }
            }
            // g prefix: absorb g_t(r).
            let mut gt_r = kf.zero();
            let mut xp = r.clone();
            for a in &lay.gm.uni[t] {
                gt_r = kf.add(&gt_r, &kf.mul(a, &xp));
                xp = kf.mul(&xp, &r);
            }
            g_prefix = kf.add(&g_prefix, &gt_r);
            corr_prefix = kf.mul(&corr_prefix, &kf.sub(&kf.one(), &r));
        }
        rounds.push(evals);
        rs.push(r);
    }
    let boundary = [p0c[0].clone(), p1c[0].clone(), q0c[0].clone(), q1c[0].clone()];
    (rounds, rs, boundary)
}

/// U-K9: the bulk-kernel rounds loop of one masked layer. The table part
/// of every full-block b-round runs on the packed kernels (successive-add
/// extrapolation, 3-product wire with the QL = lambda*q0 table, one
/// deferred reduction per node); the analytic mask/correction terms are
/// the same O(1) scalar arithmetic as the oracle path; g(1) is produced
/// through the round identity g(0) + g(1) = C. Values are bit-identical
/// to masked_rounds_scalar.
///
/// [UPERF2-A] This is the PRE-CHANGE body (the differential oracle of the
/// fast rounds below; `ZK_UPERF_ORACLE=1` routes here). Only the
/// observation-only prof timers were added.
fn masked_rounds_bulk_ref(
    kf: &KField,
    trees: &[FracTree],
    zeta: &[KElem],
    lay: &MaskedLayerCtx,
    mut c_run: KElem,
    tr: &mut LkpTranscript,
) -> (Vec<Vec<KElem>>, Vec<KElem>, [KElem; 4]) {
    let kern = kf.kern.as_ref().expect("bulk masked layer requires the kernel");
    let j = lay.j;
    let n_bvars = zeta.len();
    let mut eq_cur = {
        let _t = prof::timer(prof::A_EQ_TABLE);
        kf.kt_eq_table(zeta)
    };
    let (mut p0c, mut p1c, mut q0c, mut q1c, mut ql) = {
        let _t = prof::timer(prof::A_EXTRACT);
        let (p0c, p1c, q0c, q1c) = extract_children(trees, j);
        let ql = kf.kt_mul_fixed(&q0c, lay.lambda);
        (p0c, p1c, q0c, q1c, ql)
    };
    debug_assert_eq!(eq_cur.n, p0c.n);
    let degs = sc_degrees(n_bvars, lay.child_masked);
    let mut rounds: Vec<Vec<KElem>> = Vec::with_capacity(n_bvars + 1);
    let mut rs: Vec<KElem> = Vec::with_capacity(n_bvars + 1);
    let mut g_prefix = lay.gm.a0.clone();
    let g_tail = g_tail_ones(kf, lay.gm);
    let mut corr_prefix = kf.one();
    for t in 0..=n_bvars {
        let d = degs[t];
        let evals: Vec<KElem> = if t == n_bvars {
            let _t = prof::timer(prof::A_SCALAR_TAIL);
            masked_w_round_evals(
                kf,
                d,
                t,
                lay,
                &p0c.get(0),
                &p1c.get(0),
                &q0c.get(0),
                &q1c.get(0),
                &eq_cur.get(0),
                &corr_prefix,
                &g_prefix,
            )
        } else if eq_cur.n >= 2 * KL {
            // Bulk b-round: nodes {0, 2, .., d}; node 1 via the identity.
            let masked_now = t == 0 && lay.child_masked;
            let nodes: Vec<u64> = (0..=d as u64).filter(|&x| x != 1).collect();
            let consts: Option<Vec<[[u32; super::kfield::K_DEG]; 5]>> = if masked_now {
                Some(
                    nodes
                        .iter()
                        .map(|&x| {
                            let xk = kf.embed(x);
                            let zz = kf.mul(&xk, &kf.sub(&kf.one(), &xk));
                            let cq0 = kf.mul(&zz, &lay.spq[0]);
                            [
                                kop(&kf.mul(&zz, &lay.spp[0])),
                                kop(&kf.mul(&zz, &lay.spp[1])),
                                kop(&cq0),
                                kop(&kf.mul(&zz, &lay.spq[1])),
                                kop(&kf.mul(lay.lambda, &cq0)),
                            ]
                        })
                        .collect(),
                )
            } else {
                None
            };
            let mut acc_lo = vec![0u64; nodes.len() * 31 * KL];
            let mut acc_hi = vec![0u64; nodes.len() * 31 * KL];
            {
                let _t = prof::timer(prof::A_ROUND_G);
                k9_round_g_blocks(
                    kern,
                    &eq_cur.d,
                    &p0c.d,
                    &p1c.d,
                    &q0c.d,
                    &q1c.d,
                    &ql.d,
                    eq_cur.n / 2 / KL,
                    &nodes,
                    consts.as_deref(),
                    &mut acc_lo,
                    &mut acc_hi,
                );
            }
            let mut evals = vec![kf.zero(); d + 1];
            for (ni, &x) in nodes.iter().enumerate() {
                let xk = kf.embed(x);
                let mut acc = kf.kt_round_g_finalize(
                    &acc_lo[ni * 31 * KL..(ni + 1) * 31 * KL],
                    &acc_hi[ni * 31 * KL..(ni + 1) * 31 * KL],
                );
                if let Some(cc) = lay.corr {
                    let fx = kf.mul(&corr_prefix, &kf.sub(&kf.one(), &xk));
                    acc = kf.add(&acc, &kf.mul(&fx, &kf.mul(&cc.e, &cc.cv0_plus_cv1)));
                }
                let gv = g_round_eval(kf, lay.gm, &g_prefix, t, &xk, &g_tail[t]);
                acc = kf.add(&acc, &kf.mul(lay.nu, &gv));
                evals[x as usize] = acc;
            }
            evals[1] = kf.sub(&c_run, &evals[0]);
            evals
        } else {
            // Sub-block tail rounds: scalar body on extracted tables.
            let _t = prof::timer(prof::A_SCALAR_TAIL);
            masked_b_round_evals(
                kf,
                d,
                t,
                lay,
                &eq_cur.to_kelems(),
                &p0c.to_kelems(),
                &p1c.to_kelems(),
                &q0c.to_kelems(),
                &q1c.to_kelems(),
                &corr_prefix,
                &g_prefix,
                &g_tail[t],
            )
        };
        debug_assert_eq!(kf.add(&evals[0], &evals[1]), c_run, "honest bulk round broke");
        tr.absorb_k(kf, "mgkr-round", &evals);
        let r = tr.challenge_k(kf);
        c_run = lagrange_eval(kf, &evals, &r);
        if t < n_bvars {
            let _tf = prof::timer(prof::A_FOLD);
            kf.kt_fold_inplace(&mut eq_cur, &r);
            kf.kt_fold_inplace(&mut p0c, &r);
            kf.kt_fold_inplace(&mut p1c, &r);
            kf.kt_fold_inplace(&mut q0c, &r);
            kf.kt_fold_inplace(&mut q1c, &r);
            kf.kt_fold_inplace(&mut ql, &r);
            if t == 0 && lay.child_masked {
                let zz = kf.mul(&r, &kf.sub(&kf.one(), &r));
                let cq0 = kf.mul(&zz, &lay.spq[0]);
                let adds = [
                    (&mut p0c, kf.mul(&zz, &lay.spp[0])),
                    (&mut p1c, kf.mul(&zz, &lay.spp[1])),
                    (&mut q0c, cq0.clone()),
                    (&mut q1c, kf.mul(&zz, &lay.spq[1])),
                    (&mut ql, kf.mul(lay.lambda, &cq0)),
                ];
                for (tab, c) in adds {
                    if tab.n >= KL {
                        debug_assert_eq!(tab.n % KL, 0);
                        let nblk = tab.n / KL;
                        k9_addc_blocks(kern, &mut tab.d, &kop(&c), nblk);
                    } else {
                        for i in 0..tab.n {
                            let v = kf.add(&tab.get(i), &c);
                            tab.set(i, &v);
                        }
                    }
                }
            }
            // g prefix: absorb g_t(r).
            let mut gt_r = kf.zero();
            let mut xp = r.clone();
            for a in &lay.gm.uni[t] {
                gt_r = kf.add(&gt_r, &kf.mul(a, &xp));
                xp = kf.mul(&xp, &r);
            }
            g_prefix = kf.add(&g_prefix, &gt_r);
            corr_prefix = kf.mul(&corr_prefix, &kf.sub(&kf.one(), &r));
        }
        rounds.push(evals);
        rs.push(r);
    }
    let boundary = [p0c.get(0), p1c.get(0), q0c.get(0), q1c.get(0)];
    (rounds, rs, boundary)
}

/// [UPERF2-A] The fast bulk rounds loop — bit-identical transcript to
/// `masked_rounds_bulk_ref` (which `oracle_mode()` routes to):
///
///   * FIVE work tables instead of six: PL := p0 + lambda*q0 replaces
///     both p0 and ql = lambda*q0. Every extrapolated node sees PL(x) =
///     P0(x) + lambda Q0(x) (linearity of the extrapolation, the fold and
///     the masked add-constants), so wire = PL Q1 + P1 Q0 is the same
///     field element as P0 Q1 + P1 Q0 + lambda Q0 Q1 — one MAC fewer per
///     node in the round kernel, one fold fewer per round, one table less
///     of memory. p0 is recovered where it is needed (boundary, scalar
///     tail, w-round) as PL - lambda Q0, exactly.
///   * Deterministic ZK_THREADS splits: the eq build, the extraction, the
///     round kernel (per-chunk lazy planes summed in index order — exact
///     integers), the folds (out-of-place into a per-layer scratch that
///     is swapped in), the masked add-constants.
///   * NEUTRAL PADS ARE NOT COMPUTED: a `neutral_tree` instance's slice
///     of every table is (0, 0, 1, 1) — a constant across the slice at
///     every b-round (folding a constant slice yields the constant, the
///     masked add-constants shift it uniformly), so its share of every
///     round-poly node is a closed form: sum over the pad's remaining
///     hypercube of EQ(x, i) * wire_pad(x) = wire_pad(x) * F_t *
///     eq(zeta_t, x) * E(e), with F_t = prod_{s<t} eq(zeta_s, r_s) (the
///     bound prefix every eq entry carries), eq(z, x) = (1-z)(1-x) + z x
///     (the extrapolated current variable; the free suffix sums to 1)
///     and E(e) = prod_u eq(zeta_{j+u}, e_u) (the instance coordinates).
///     The kernels run over the REAL instances' block ranges only; the
///     pad slices are materialized once the per-instance size drops
///     below two blocks (tiny) and the plain path finishes the layer.
///     The eq table is built as (b-part table) x E(e) per real slice
///     instead of the joint doubling — the same field elements
///     (associativity), pads skipped.
///
/// The analytic mask/correction terms, the round identity for g(1), the
/// absorb order and every challenge are the reference path's.
fn masked_rounds_bulk(
    kf: &KField,
    trees: &[FracTree],
    zeta: &[KElem],
    lay: &MaskedLayerCtx,
    mut c_run: KElem,
    tr: &mut LkpTranscript,
) -> (Vec<Vec<KElem>>, Vec<KElem>, [KElem; 4]) {
    if super::eval_proof::oracle_mode() {
        return masked_rounds_bulk_ref(kf, trees, zeta, lay, c_run, tr);
    }
    let kern = kf.kern.as_ref().expect("bulk masked layer requires the kernel");
    let j = lay.j;
    let n_bvars = zeta.len();
    let l = trees.len();
    let e_bits = n_bvars - j;
    debug_assert_eq!(1usize << e_bits, l);
    let per = 1usize << j; // per-instance elements at round 0
    let size = l << j;
    let real: Vec<usize> = (0..l).filter(|&e| !trees[e].is_neutral()).collect();
    let pads: Vec<usize> = (0..l).filter(|&e| trees[e].is_neutral()).collect();
    // Pad skipping needs whole pair-blocks per instance; below that the
    // pads are simply materialized (tiny layers, tiny tails).
    let skip = !pads.is_empty() && per >= 2 * KL;
    let eq_z = |z: &KElem, bit: bool| -> KElem { if bit { z.clone() } else { kf.sub(&kf.one(), z) } };
    // E(e) = prod_u eq(zeta_{j+u}, e_u).
    let e_of = |e: usize| -> KElem {
        let mut acc = kf.one();
        for u in 0..e_bits {
            acc = kf.mul(&acc, &eq_z(&zeta[j + u], (e >> u) & 1 == 1));
        }
        acc
    };
    let mut eq_cur = {
        let _t = prof::timer(prof::A_EQ_TABLE);
        if e_bits == 0 || per < KL {
            kf.kt_eq_table_par(zeta)
        } else {
            // b-part table x E(e) per real slice.
            let eqb = kf.kt_eq_table_par(&zeta[..j]);
            let mut full = super::kfield::KTab::zeroed(size);
            let nblk = per / KL;
            let all: Vec<usize> = (0..l).collect();
            for &e in if skip { &real } else { &all } {
                let ee = e_of(e);
                let w0 = e * nblk * super::kfield::KBLK;
                super::kfield::k9_mul_fixed_par(kern, &eqb.d, &kop(&ee), &mut full.d[w0..w0 + nblk * super::kfield::KBLK], nblk);
            }
            full
        }
    };
    // [UPERF2-G] FUSION. The five work tables are folded INSIDE the next
    // round's kernel pass (`kfield::k9_fused_round_par`, FUSE_FOLD) and the
    // extraction of layer j+1 into (PL, p1, q0, q1) is fused into rounds 0
    // and 1 (FUSE_EXTRACT / FUSE_EXTRACT_FOLD: the tree layer is read
    // directly; the first materialized work tables are state 1). A round's
    // fold is therefore PENDING until the next round consumes it — or is
    // FLUSHED (applied eagerly, exactly lane A's fold + add-constants) when
    // the next round cannot fuse it: the scalar tail, the w-round, the pad
    // materialization. With the knob off every fold is flushed right after
    // its challenge (lane A's HEAD path). Values are identical either way:
    // each stored element is the canonical result of the same field
    // expression and the node planes are exact integer sums of the same
    // terms.
    let fuse = super::kfield::k9_fuse_enabled();
    // The extract may be fused when every state-1 pair-block (32 state-0
    // elements) lies inside one instance's slice and any pads are skipped
    // (their slices are never touched); otherwise (tiny layers) the tables
    // are extracted eagerly.
    let fuse_extract = fuse && super::kfield::k9_fuse_extract_enabled() && per >= 4 * KL && (pads.is_empty() || skip);
    let mut tabs: Option<(super::kfield::KTab, super::kfield::KTab, super::kfield::KTab, super::kfield::KTab)> = None;
    let mut pending: Option<PendingFold> = None;
    let mut scratch: Vec<u32> = Vec::new();
    if !fuse_extract {
        flush_state(kf, kern, trees, j, skip, per, &real, lay.lambda, &mut tabs, &mut eq_cur, &mut scratch, &mut pending);
    }
    let lambda_k = kop(lay.lambda);
    let degs = sc_degrees(n_bvars, lay.child_masked);
    let mut rounds: Vec<Vec<KElem>> = Vec::with_capacity(n_bvars + 1);
    let mut rs: Vec<KElem> = Vec::with_capacity(n_bvars + 1);
    let mut g_prefix = lay.gm.a0.clone();
    let g_tail = g_tail_ones(kf, lay.gm);
    let mut corr_prefix = kf.one();
    // Pad bookkeeping: the pad slices' constant table values (p0, p1,
    // q0, q1), the bound-prefix eq factor F_t, and S_pad = sum_pads E(e).
    let mut pad_vals = [kf.zero(), kf.zero(), kf.one(), kf.one()];
    let mut f_t = kf.one();
    let s_pad = pads.iter().fold(kf.zero(), |acc, &e| kf.add(&acc, &e_of(e)));
    let mut materialized = !skip;
    // p0 = PL - lambda*Q0 (exact), element i.
    let p0_of = |pl: &super::kfield::KTab, q0: &super::kfield::KTab, i: usize| -> KElem {
        kf.sub(&pl.get(i), &kf.mul(lay.lambda, &q0.get(i)))
    };
    for t in 0..=n_bvars {
        let d = degs[t];
        // Elements at state t, per-instance size at this round (b-rounds
        // only), and whether the pad slices are still being skipped.
        let n_t = size >> t;
        let per_t = if t < j { per >> t } else { 1 };
        let skipping = skip && t < j && per_t >= 2 * KL;
        let need_mat = !materialized && !skipping;
        let bulk = t < n_bvars && n_t >= 2 * KL;
        // The kernel's block ranges (state-t blocks of the current tables).
        let ranges_blk: Vec<(usize, usize)> = if skipping {
            let nb = per_t / KL;
            real.iter().map(|&e| (e * nb, (e + 1) * nb)).collect()
        } else {
            vec![(0, n_t / KL)]
        };
        // The fused mode this round can take (None = plain kernel on
        // materialized state-t tables, or not a bulk round).
        let mut fuse_mode: Option<u8> = if !bulk {
            None
        } else if tabs.is_none() {
            if t == 0 {
                Some(super::kfield::FUSE_EXTRACT)
            } else if t == 1 && pending.is_some() {
                Some(super::kfield::FUSE_EXTRACT_FOLD)
            } else {
                None
            }
        } else if pending.is_some() {
            Some(super::kfield::FUSE_FOLD)
        } else {
            None
        };
        if need_mat || fuse_mode.is_none() {
            // Eager path: the tables are brought to state t now (the
            // pending fold is consumed), so this round's kernel is plain.
            flush_state(kf, kern, trees, j, skip, per, &real, lay.lambda, &mut tabs, &mut eq_cur, &mut scratch, &mut pending);
            fuse_mode = None;
        }
        if need_mat {
            // Materialize the pad slices (per_t elements each, per_t < 16):
            // eq = F_t * eq(zeta[t..j], b) * E(e); tables = the constants.
            let (pl, p1c, q0c, q1c) = tabs.as_mut().expect("flushed");
            let small: Vec<KElem> = eq_table(kf, &zeta[t..j]);
            debug_assert_eq!(small.len(), per_t);
            let plv = kf.add(&pad_vals[0], &kf.mul(lay.lambda, &pad_vals[2]));
            for &e in &pads {
                let ee = kf.mul(&f_t, &e_of(e));
                for b in 0..per_t {
                    let i = e * per_t + b;
                    eq_cur.set(i, &kf.mul(&ee, &small[b]));
                    pl.set(i, &plv);
                    p1c.set(i, &pad_vals[1]);
                    q0c.set(i, &pad_vals[2]);
                    q1c.set(i, &pad_vals[3]);
                }
            }
            materialized = true;
        }
        let evals: Vec<KElem> = if t == n_bvars {
            let _t = prof::timer(prof::A_SCALAR_TAIL);
            let (pl, p1c, q0c, q1c) = tabs.as_ref().expect("flushed");
            let p0 = p0_of(pl, q0c, 0);
            masked_w_round_evals(
                kf,
                d,
                t,
                lay,
                &p0,
                &p1c.get(0),
                &q0c.get(0),
                &q1c.get(0),
                &eq_cur.get(0),
                &corr_prefix,
                &g_prefix,
            )
        } else if bulk {
            let masked_now = t == 0 && lay.child_masked;
            let nodes: Vec<u64> = (0..=d as u64).filter(|&x| x != 1).collect();
            // Per node: the child-mask add-constants (p0, p1, q0, q1) — zero
            // unless masked_now.
            let node_consts: Vec<[KElem; 4]> = nodes
                .iter()
                .map(|&x| {
                    if masked_now {
                        let xk = kf.embed(x);
                        let zz = kf.mul(&xk, &kf.sub(&kf.one(), &xk));
                        [
                            kf.mul(&zz, &lay.spp[0]),
                            kf.mul(&zz, &lay.spp[1]),
                            kf.mul(&zz, &lay.spq[0]),
                            kf.mul(&zz, &lay.spq[1]),
                        ]
                    } else {
                        [kf.zero(), kf.zero(), kf.zero(), kf.zero()]
                    }
                })
                .collect();
            let consts: Option<Vec<[[u32; super::kfield::K_DEG]; 4]>> = if masked_now {
                Some(
                    node_consts
                        .iter()
                        .map(|c| {
                            [
                                kop(&kf.add(&c[0], &kf.mul(lay.lambda, &c[2]))),
                                kop(&c[1]),
                                kop(&c[2]),
                                kop(&c[3]),
                            ]
                        })
                        .collect(),
                )
            } else {
                None
            };
            let mut acc_lo = vec![0u64; nodes.len() * 31 * KL];
            let mut acc_hi = vec![0u64; nodes.len() * 31 * KL];
            {
                let _t = prof::timer(prof::A_ROUND_G);
                match fuse_mode {
                    None => {
                        let (pl, p1c, q0c, q1c) = tabs.as_ref().expect("flushed");
                        for &(lo, hi) in &ranges_blk {
                            let (w0, w1) = (lo * super::kfield::KBLK, hi * super::kfield::KBLK);
                            k9_round_g5_par(
                                kern,
                                &eq_cur.d[w0..w1],
                                &pl.d[w0..w1],
                                &p1c.d[w0..w1],
                                &q0c.d[w0..w1],
                                &q1c.d[w0..w1],
                                (hi - lo) / 2,
                                &nodes,
                                consts.as_deref(),
                                &mut acc_lo,
                                &mut acc_hi,
                            );
                        }
                    }
                    Some(mode) => {
                        use super::kfield::{FUSE_EXTRACT, FUSE_EXTRACT_FOLD, FUSE_FOLD, FusedLayer, FusedPlan, KTab};
                        let n_pairs = n_t / (2 * KL);
                        // Live state-t pair-block ranges (+ the tree layers
                        // per range for the extract modes).
                        let (pranges, layers): (Vec<(usize, usize)>, Vec<FusedLayer>) = if mode == FUSE_FOLD {
                            (ranges_blk.iter().map(|&(lo, hi)| (lo / 2, hi / 2)).collect(), Vec::new())
                        } else {
                            let ppe = per_t / (2 * KL);
                            let all: Vec<usize> = (0..l).collect();
                            let live: &[usize] = if skip { &real } else { &all };
                            (
                                live.iter().map(|&e| (e * ppe, (e + 1) * ppe)).collect(),
                                live.iter()
                                    .map(|&e| FusedLayer {
                                        p: &trees[e].p_layer(j + 1).d,
                                        q: &trees[e].q_layer(j + 1).d,
                                        first_pair: e * ppe,
                                    })
                                    .collect(),
                            )
                        };
                        let (r_prev, fold_consts) = match &pending {
                            Some(p) => (
                                kop(&p.r),
                                p.consts.as_ref().map(|c| {
                                    if mode == FUSE_FOLD {
                                        [kop(&kf.add(&c[0], &kf.mul(lay.lambda, &c[2]))), kop(&c[1]), kop(&c[2]), kop(&c[3])]
                                    } else {
                                        [kop(&c[0]), kop(&c[1]), kop(&c[2]), kop(&c[3])]
                                    }
                                }),
                            ),
                            None => ([0u32; super::kfield::K_DEG], None),
                        };
                        if mode == FUSE_EXTRACT_FOLD {
                            tabs = Some((KTab::zeroed(n_t), KTab::zeroed(n_t), KTab::zeroed(n_t), KTab::zeroed(n_t)));
                        }
                        let plan = FusedPlan { mode, ranges: &pranges, layers: &layers, r_prev, lambda: lambda_k, fold_consts };
                        match tabs.as_mut() {
                            Some((pl, p1c, q0c, q1c)) => {
                                super::kfield::k9_fused_round_par(
                                    kern,
                                    &plan,
                                    n_pairs,
                                    &mut eq_cur.d,
                                    [&mut pl.d, &mut p1c.d, &mut q0c.d, &mut q1c.d],
                                    &nodes,
                                    consts.as_deref(),
                                    &mut acc_lo,
                                    &mut acc_hi,
                                    &mut scratch,
                                );
                                if mode == FUSE_FOLD {
                                    for tb in [pl, p1c, q0c, q1c] {
                                        tb.n = n_t;
                                        tb.d.truncate(n_t / KL * super::kfield::KBLK);
                                    }
                                }
                            }
                            None => {
                                debug_assert_eq!(mode, FUSE_EXTRACT);
                                super::kfield::k9_fused_round_par(
                                    kern,
                                    &plan,
                                    n_pairs,
                                    &mut eq_cur.d,
                                    [Default::default(), Default::default(), Default::default(), Default::default()],
                                    &nodes,
                                    consts.as_deref(),
                                    &mut acc_lo,
                                    &mut acc_hi,
                                    &mut scratch,
                                );
                            }
                        }
                        if mode != FUSE_EXTRACT {
                            // The pending fold is consumed: every table is at state t.
                            eq_cur.n = n_t;
                            eq_cur.d.truncate(n_t / KL * super::kfield::KBLK);
                            pending = None;
                        }
                    }
                }
            }
            let mut evals = vec![kf.zero(); d + 1];
            for (ni, &x) in nodes.iter().enumerate() {
                let xk = kf.embed(x);
                let mut acc = kf.kt_round_g_finalize(
                    &acc_lo[ni * 31 * KL..(ni + 1) * 31 * KL],
                    &acc_hi[ni * 31 * KL..(ni + 1) * 31 * KL],
                );
                if skipping {
                    // The pads' closed form: wire_pad(x) * F_t * eq(zeta_t, x) * S_pad.
                    let c = &node_consts[ni];
                    let vp0 = kf.add(&pad_vals[0], &c[0]);
                    let vp1 = kf.add(&pad_vals[1], &c[1]);
                    let vq0 = kf.add(&pad_vals[2], &c[2]);
                    let vq1 = kf.add(&pad_vals[3], &c[3]);
                    let wire = kf.add(
                        &kf.add(&kf.mul(&vp0, &vq1), &kf.mul(&vp1, &vq0)),
                        &kf.mul(lay.lambda, &kf.mul(&vq0, &vq1)),
                    );
                    let eqx = kf.add(
                        &kf.mul(&kf.sub(&kf.one(), &zeta[t]), &kf.sub(&kf.one(), &xk)),
                        &kf.mul(&zeta[t], &xk),
                    );
                    let pad_term = kf.mul(&wire, &kf.mul(&f_t, &kf.mul(&eqx, &s_pad)));
                    acc = kf.add(&acc, &pad_term);
                }
                if let Some(cc) = lay.corr {
                    let fx = kf.mul(&corr_prefix, &kf.sub(&kf.one(), &xk));
                    acc = kf.add(&acc, &kf.mul(&fx, &kf.mul(&cc.e, &cc.cv0_plus_cv1)));
                }
                let gv = g_round_eval(kf, lay.gm, &g_prefix, t, &xk, &g_tail[t]);
                acc = kf.add(&acc, &kf.mul(lay.nu, &gv));
                evals[x as usize] = acc;
            }
            evals[1] = kf.sub(&c_run, &evals[0]);
            evals
        } else {
            let _t = prof::timer(prof::A_SCALAR_TAIL);
            debug_assert!(materialized);
            let (pl, p1c, q0c, q1c) = tabs.as_ref().expect("flushed");
            let p0k: Vec<KElem> = (0..pl.n).map(|i| p0_of(pl, q0c, i)).collect();
            masked_b_round_evals(
                kf,
                d,
                t,
                lay,
                &eq_cur.to_kelems(),
                &p0k,
                &p1c.to_kelems(),
                &q0c.to_kelems(),
                &q1c.to_kelems(),
                &corr_prefix,
                &g_prefix,
                &g_tail[t],
            )
        };
        debug_assert_eq!(kf.add(&evals[0], &evals[1]), c_run, "honest fast round broke");
        tr.absorb_k(kf, "mgkr-round", &evals);
        let r = tr.challenge_k(kf);
        c_run = lagrange_eval(kf, &evals, &r);
        if t < n_bvars {
            // The fold of round t is PENDING (consumed by round t+1's fused
            // kernel, or flushed); with the knob off it is applied now.
            let consts = if t == 0 && lay.child_masked {
                let zz = kf.mul(&r, &kf.sub(&kf.one(), &r));
                Some([
                    kf.mul(&zz, &lay.spp[0]),
                    kf.mul(&zz, &lay.spp[1]),
                    kf.mul(&zz, &lay.spq[0]),
                    kf.mul(&zz, &lay.spq[1]),
                ])
            } else {
                None
            };
            if let Some(c) = &consts {
                // The pad slices shift by the same constants.
                pad_vals = [
                    kf.add(&pad_vals[0], &c[0]),
                    kf.add(&pad_vals[1], &c[1]),
                    kf.add(&pad_vals[2], &c[2]),
                    kf.add(&pad_vals[3], &c[3]),
                ];
            }
            pending = Some(PendingFold { r: r.clone(), consts, ranges: ranges_blk, skipping });
            if !fuse {
                flush_state(kf, kern, trees, j, skip, per, &real, lay.lambda, &mut tabs, &mut eq_cur, &mut scratch, &mut pending);
            }
            if t < j {
                // F_{t+1} = F_t * eq(zeta_t, r_t).
                let eqr = kf.add(
                    &kf.mul(&kf.sub(&kf.one(), &zeta[t]), &kf.sub(&kf.one(), &r)),
                    &kf.mul(&zeta[t], &r),
                );
                f_t = kf.mul(&f_t, &eqr);
            }
            let mut gt_r = kf.zero();
            let mut xp = r.clone();
            for a in &lay.gm.uni[t] {
                gt_r = kf.add(&gt_r, &kf.mul(a, &xp));
                xp = kf.mul(&xp, &r);
            }
            g_prefix = kf.add(&g_prefix, &gt_r);
            corr_prefix = kf.mul(&corr_prefix, &kf.sub(&kf.one(), &r));
        }
        rounds.push(evals);
        rs.push(r);
    }
    let (pl, p1c, q0c, q1c) = tabs.as_ref().expect("flushed");
    let boundary = [p0_of(pl, q0c, 0), p1c.get(0), q0c.get(0), q1c.get(0)];
    (rounds, rs, boundary)
}

/// [UPERF2-G] A round's fold awaiting the next round's fused kernel: the
/// challenge, the masked t == 0 add-constants [c_p0, c_p1, c_q0, c_q1] (if
/// any), and the source (state-t) block ranges / skipping flag of the round
/// that produced it.
struct PendingFold {
    r: KElem,
    consts: Option<[KElem; 4]>,
    ranges: Vec<(usize, usize)>,
    skipping: bool,
}

/// [UPERF2-G] Bring the work tables to the current state EAGERLY: extract
/// layer j+1 into (PL, p1, q0, q1) if they do not exist yet (lane A's
/// threaded block-copy extract + PL := p0 + lambda q0), then apply the
/// pending fold (lane A's out-of-place threaded folds + the masked
/// add-constants over the real ranges) — the pre-fusion path, byte for byte.
#[allow(clippy::too_many_arguments)]
fn flush_state(
    kf: &KField,
    kern: &super::kfield::KKern,
    trees: &[FracTree],
    j: usize,
    skip: bool,
    per: usize,
    real: &[usize],
    lambda: &KElem,
    tabs: &mut Option<(super::kfield::KTab, super::kfield::KTab, super::kfield::KTab, super::kfield::KTab)>,
    eq_cur: &mut super::kfield::KTab,
    scratch: &mut Vec<u32>,
    pending: &mut Option<PendingFold>,
) {
    if tabs.is_none() {
        let _t = prof::timer(prof::A_EXTRACT);
        let (mut p0c, p1c, q0c, q1c) = extract_children_par(trees, j, !skip);
        // PL = p0 + lambda*q0, in place on the extracted p0 (real ranges).
        if !skip {
            kf.kt_mul_fixed_add_inplace(&mut p0c, &q0c, lambda);
        } else {
            let nblk = per / KL;
            for &e in real {
                let w0 = e * nblk * super::kfield::KBLK;
                super::kfield::k9_mul_fixed_add_par(kern, &mut p0c.d[w0..w0 + nblk * super::kfield::KBLK], &q0c.d[w0..w0 + nblk * super::kfield::KBLK], &kop(lambda), nblk);
            }
        }
        *tabs = Some((p0c, p1c, q0c, q1c));
    }
    if let Some(p) = pending.take() {
        let _tf = prof::timer(prof::A_FOLD);
        let (pl, p1c, q0c, q1c) = tabs.as_mut().expect("extracted");
        if p.skipping {
            kf.kt_fold_par_ranges(eq_cur, scratch, &p.r, &p.ranges);
            kf.kt_fold_par_ranges(pl, scratch, &p.r, &p.ranges);
            kf.kt_fold_par_ranges(p1c, scratch, &p.r, &p.ranges);
            kf.kt_fold_par_ranges(q0c, scratch, &p.r, &p.ranges);
            kf.kt_fold_par_ranges(q1c, scratch, &p.r, &p.ranges);
        } else {
            kf.kt_fold_par(eq_cur, scratch, &p.r);
            kf.kt_fold_par(pl, scratch, &p.r);
            kf.kt_fold_par(p1c, scratch, &p.r);
            kf.kt_fold_par(q0c, scratch, &p.r);
            kf.kt_fold_par(q1c, scratch, &p.r);
        }
        if let Some(c) = &p.consts {
            let cpl = kf.add(&c[0], &kf.mul(lambda, &c[2]));
            if p.skipping {
                // Real ranges of the FOLDED tables: half the source blocks.
                for &(lo, hi) in &p.ranges {
                    let (w0, w1) = ((lo / 2) * super::kfield::KBLK, (hi / 2) * super::kfield::KBLK);
                    let nb = (hi - lo) / 2;
                    super::kfield::k9_addc_par(kern, &mut pl.d[w0..w1], &kop(&cpl), nb);
                    super::kfield::k9_addc_par(kern, &mut p1c.d[w0..w1], &kop(&c[1]), nb);
                    super::kfield::k9_addc_par(kern, &mut q0c.d[w0..w1], &kop(&c[2]), nb);
                    super::kfield::k9_addc_par(kern, &mut q1c.d[w0..w1], &kop(&c[3]), nb);
                }
            } else {
                kf.kt_addc(pl, &cpl);
                kf.kt_addc(p1c, &c[1]);
                kf.kt_addc(q0c, &c[2]);
                kf.kt_addc(q1c, &c[3]);
            }
        }
    }
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
    masks: MaskSet,
    tr: &mut LkpTranscript,
) -> (MaskedDescentProof, DescentEnd) {
    // Freshness is STRUCTURAL: the mask set is CONSUMED BY VALUE here
    // (C-01 remediation, U-S P1-D2). The object is moved into this call
    // and cannot be reused — a second prove with the same binding is a
    // compile error, so there is no runtime flag to bypass by
    // reconstruction. Per-session freshness rests on the OS-entropy
    // `ProverRng` that drew the coefficients.
    let _tp = prof::timer(prof::A_GKR_PROVE); // observation only
    let masks = &masks;
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
                t.p_elem(1, 0),
                t.p_elem(1, 1),
                t.q_elem(1, 0),
                t.q_elem(1, 1),
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
    let mut layer_pts = Vec::with_capacity(depth - 1);
    let bulk_ok = kf.kern.is_some() && trees.iter().all(|t| t.is_packed());
    for j in 1..depth {
        let lambda = tr.challenge_k(kf);
        let mut c_run = kf.add(&p_claim, &kf.mul(&lambda, &q_claim));
        let n_bvars = j + e_bits;
        let child_masked = j <= depth - 2;
        let size = l << j;
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
        // The rounds (U-K9: bulk kernels when the packed layer is live and
        // the tables have full lane blocks; the scalar path otherwise —
        // identical transcript either way).
        let lay = MaskedLayerCtx {
            j,
            child_masked,
            lambda: &lambda,
            spp: &spp,
            spq: &spq,
            corr: corr.as_ref(),
            masks,
            gm,
            nu: &nu,
        };
        let (rounds, rs, boundary) = if bulk_ok && size >= 2 * KL {
            masked_rounds_bulk(kf, trees, &zeta, &lay, c_run, tr)
        } else {
            masked_rounds_scalar(kf, trees, e_bits, &zeta, &lay, c_run, tr)
        };
        let c_w = rs[n_bvars].clone();
        let r_b: Vec<KElem> = rs[0..n_bvars].to_vec();
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
        layer_pts.push((open_pt, zeta[0].clone(), c_w.clone()));
        let mu = tr.challenge_k(kf);
        p_claim = kf.add(&boundary[0], &kf.mul(&mu, &kf.sub(&boundary[1], &boundary[0])));
        q_claim = kf.add(&boundary[2], &kf.mul(&mu, &kf.sub(&boundary[3], &boundary[2])));
        let mut nz = vec![mu];
        nz.extend(r_b);
        zeta = nz;
        layers.push(MaskedLayerProof { g_sum, rounds, boundary, open_g, open_r });
    }
    (
        MaskedDescentProof { layer1, layers },
        DescentEnd { zstar: zeta, p_claim, q_claim, layer_pts },
    )
}

/// Verify the masked descent. `masks` = the committed mask set (the
/// verifier evaluates the pins itself here; in the full protocol the
/// openings are E4-pinned against the mask COMMITMENTS and this
/// function receives the opened values as claims — the battery models
/// commitment pinning by exact recomputation, the U-K5c wiring routes
/// them through the psi batch). Returns (derived per-instance roots,
/// z*, p-claim, q-claim); the caller runs the root cross-check and
/// the aggregate leaf pins.
pub fn masked_gkr_verify(
    kf: &KField,
    l: usize,
    depth: usize,
    masks: &MaskSet,
    proof: &MaskedDescentProof,
    tr: &mut LkpTranscript,
    pin: bool,
) -> Option<(Vec<[KElem; 2]>, DescentEnd)> {
    let _tv = prof::timer(prof::A_GKR_VERIFY); // observation only
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
    let mut layer_pts = Vec::with_capacity(depth - 1);
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
        let mut open_pt = r_b.clone();
        open_pt.push(c_w.clone());
        layer_pts.push((open_pt, zeta[0].clone(), c_w.clone()));
        let mu = tr.challenge_k(kf);
        p_claim = kf.add(&vp0, &kf.mul(&mu, &kf.sub(&vp1, &vp0)));
        q_claim = kf.add(&vq0, &kf.mul(&mu, &kf.sub(&vq1, &vq0)));
        let mut nz = vec![mu];
        nz.extend(r_b);
        zeta = nz;
    }
    Some((roots, DescentEnd { zstar: zeta, p_claim, q_claim, layer_pts }))
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
    pub fn draw(kf: &KField, rng: &mut ProverRng) -> BlinderSet {
        let mut mk = || {
            let a = random_k(kf, rng);
            let mut u = random_k(kf, rng);
            while kf.is_zero(&u) {
                u = random_k(kf, rng);
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

/// [UAGB1-BH wave 3, BF-F3] The public witness-leaf position map of
/// `blinded_witness_tree`: honest leaf j sits at
///   j                      for j <  n/2 - 4   (the left block), and
///   n/2 + (j - (n/2 - 4))  for j >= n/2 - 4   (the right block),
/// i.e. the contiguous front fill up to the first blinder position,
/// then the right half from n/2 — the `table_row_positions` split
/// discipline extended to witness columns. Capacity is n - 8: each
/// half keeps its top blinder (tL/tR randomize the layer-1 values)
/// and final-pad blinder (f0/f1) plus two spare dummies, exactly the
/// dummy budget the split table layout already runs with. For
/// n_used <= n/2 - 4 the map is the identity — the historical layout,
/// BIT-IDENTICAL (the pre-wave-3 builder asserted that bound; there
/// was no behavior above it to preserve). Pin builders consume this
/// map; the 2^20-class pass tensors fit at depth 21 instead of the
/// BF-F3 dummy-padded depth 22 (~2x tree work).
pub fn witness_leaf_positions(n_used: usize, n: usize) -> Vec<usize> {
    let cap_half = n / 2 - 4;
    assert!(n_used <= n - 8, "witness exceeds the split capacity n - 8");
    (0..n_used).map(|j| if j < cap_half { j } else { n / 2 + (j - cap_half) }).collect()
}

/// Blinder-extended witness tree: n_used honest fused leaves at the
/// `witness_leaf_positions` map (front-contiguous below n/2 - 4 — the
/// historical layout, bit-identical; split into the right half beyond
/// it, capacity n - 8), dummies (0, 1) elsewhere, the blinder set at
/// the fixed positions.
pub fn blinded_witness_tree(
    kf: &KField,
    alpha: &KElem,
    w_fused: &[KElem],
    depth: usize,
    bl: &BlinderSet,
) -> FracTree {
    let n = 1usize << depth;
    let pos = witness_leaf_positions(w_fused.len(), n);
    debug_assert!({
        let blp = blinder_positions(n);
        pos.iter().all(|p| !blp.contains(p))
    });
    if kf.kern.is_some() && !super::eval_proof::oracle_mode() {
        // [UPERF2-A] sparse packed build: the same leaf sequence without
        // the boxed 2 x 2^depth Vec<u64> pair (bit-identical tree).
        let (zero, one) = (kf.zero(), kf.one());
        let honest = w_fused.iter().zip(pos.iter()).map(|(w, &i)| (i, one.clone(), kf.sub(alpha, w)));
        let blp = blinder_positions(n);
        let blinders = [&bl.tl, &bl.tr, &bl.f0, &bl.f1]
            .into_iter()
            .enumerate()
            .map(|(k, b)| (blp[k], b.a.clone(), b.u.clone()));
        return super::gkr::build_tree_sparse(kf, n, (&zero, &one), honest.chain(blinders));
    }
    let mut p = vec![kf.zero(); n];
    let mut q = vec![kf.one(); n];
    for (w, &i) in w_fused.iter().zip(pos.iter()) {
        p[i] = kf.one();
        q[i] = kf.sub(alpha, w);
    }
    install_blinders(kf, &mut p, &mut q, bl);
    super::gkr::build_tree(kf, p, q)
}

/// The frozen table-row placement in a blinded 2^depth leaf layer:
/// rows are SPLIT across the halves — row j at j for j < ceil(T/2),
/// at n/2 + (j - ceil(T/2)) otherwise. A front-packed 2^k-row table
/// would fill the whole left half of its depth-(k+1) blinded tree and
/// leave no dummy space for the left top blinder (whose job is to
/// randomize the left layer-1 value); the split gives both halves
/// dummy space. Public statement layout — the T Q-pin's fused-row MLE
/// and the T P-pin's multiplicity weights use exactly these positions.
pub fn table_row_positions(t_rows: usize, n: usize) -> Vec<usize> {
    let left = t_rows.div_ceil(2);
    (0..t_rows).map(|j| if j < left { j } else { n / 2 + (j - left) }).collect()
}

/// Blinder-extended table tree: the fused rows with their multiplicity
/// numerators at the split positions (the blinders push a full 2^k
/// table one level deeper — depth 9 for the 256-row SiLU table).
pub fn blinded_table_tree(
    kf: &KField,
    alpha: &KElem,
    tab_fused: &[KElem],
    m: &[KElem],
    depth: usize,
    bl: &BlinderSet,
) -> FracTree {
    let n = 1usize << depth;
    let pos = table_row_positions(tab_fused.len(), n);
    let blp = blinder_positions(n);
    assert!(
        pos.iter().all(|p| *p < n && !blp.contains(p)),
        "table rows would collide with a blinder position"
    );
    if kf.kern.is_some() && !super::eval_proof::oracle_mode() {
        // [UPERF2-A] sparse packed build (bit-identical tree; see
        // blinded_witness_tree).
        let (zero, one) = (kf.zero(), kf.one());
        let rows = tab_fused.iter().enumerate().map(|(j, t)| (pos[j], m[j].clone(), kf.sub(alpha, t)));
        let blinders = [&bl.tl, &bl.tr, &bl.f0, &bl.f1]
            .into_iter()
            .enumerate()
            .map(|(k, b)| (blp[k], b.a.clone(), b.u.clone()));
        return super::gkr::build_tree_sparse(kf, n, (&zero, &one), rows.chain(blinders));
    }
    let mut p = vec![kf.zero(); n];
    let mut q = vec![kf.one(); n];
    for (j, t) in tab_fused.iter().enumerate() {
        p[pos[j]] = m[j].clone();
        q[pos[j]] = kf.sub(alpha, t);
    }
    install_blinders(kf, &mut p, &mut q, bl);
    super::gkr::build_tree(kf, p, q)
}

/// LKP-7 arithmetic: the masked transcript shape of one descent —
/// (rounds, round-poly K-element count) with the 6/4/3 evaluation
/// pattern (first b-round 6 evals on child-masked layers, 4 else;
/// other b-rounds 4; w-round 3).
pub fn masked_transcript_shape(depth: usize, n_extra: usize) -> (usize, usize) {
    let mut rounds = 0usize;
    let mut kelems = 0usize;
    for j in 1..depth {
        let n_bvars = j + n_extra;
        let degs = sc_degrees(n_bvars, j <= depth - 2);
        rounds += degs.len();
        kelems += degs.iter().map(|d| d + 1).sum::<usize>();
    }
    (rounds, kelems)
}

/// LKP-7 arithmetic, whole descent: (rounds, total transcript
/// K-elements) of one masked descent over n_inst instances — round
/// polynomials (masked_transcript_shape) plus the per-instance layer-1
/// quadruples, and per layer sumcheck: G_j, the boundary quadruple,
/// the g opening, and (j >= 2) the two R openings. Wire bytes are 64
/// per K-element (16 base coefficients x 4 bytes at q < 2^31).
pub fn masked_transcript_totals(depth: usize, n_extra: usize, n_inst: usize) -> (usize, usize) {
    let (rounds, mut kelems) = masked_transcript_shape(depth, n_extra);
    kelems += 4 * n_inst; // layer-1 quadruples (roots are derived)
    kelems += (depth - 1) * 6; // per layer: G_j + 4 boundary + open_g
    kelems += 2 * (depth - 2); // open_rp/open_rq for j >= 2
    (rounds, kelems)
}

/// Bytes-on-the-wire of one masked PASS at (witness depth, table
/// depth, e_bits, instances): both descents at 64 B per K-element.
pub fn masked_pass_bytes(dw: usize, dt: usize, e_bits: usize, n_inst: usize) -> usize {
    let (_, kw) = masked_transcript_totals(dw, e_bits, n_inst);
    let (_, kt) = masked_transcript_totals(dt, e_bits, n_inst);
    64 * (kw + kt)
}

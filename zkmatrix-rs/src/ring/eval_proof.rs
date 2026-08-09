// [UAGB1-BD] U-AG-B1 wave 2, lane BD: the batched-opening / eval-proof
// layer — the aggregation stack that replaces the wave-1 statement's
// per-wave ct-round opening volume (99.8% of 117,396,459 counted B at
// the 512x768x2048 statement) with, per commitment GROUP (W-C two-group
// discipline: T_W = weights, T_act = activations/accumulator):
//
//   1. CR-L4-class BATCHING: the statement's terminal MLE-evaluation
//      claims are nu_g-RLC'd per group (nu drawn AFTER all terminal
//      values are absorbed — the CRB-N5 edge; AFS-L8 hypothesis (iii)),
//      then coordinate-decomposed into K_DEG = 16 base-field rows (the
//      IA-O1-2 / k_weight_coords fallback, AGGREGATION_CLAIM_REDUCTION
//      10.3) and ring-embedded by conj-packing (ct(conj(a)*b) = <a,b>,
//      SOUNDNESS_REFERENCE 1.2 fact 3): row c becomes the full-ring
//      claim F_c(w) = B_c with B_c on the wire and ct(B_c) publicly
//      pinned to coordinate c of the batched K-value.
//   2. THE DESCENT / EVAL PROOF (bare): a LaBRADOR-form recursion at
//      kappa = 11 (KAP-11) over the group's EXACT-DIGIT witness
//      (committed digit columns; the triple-mandated exact-digit
//      branch — deterministic, Gaussian-free, JL-free, I-6-consistent).
//      Per level: full-entropy R_q constraint aggregation (the R-EB3
//      K-draw class, per-slot mass q^-16 — row EB3-kdraw), chunk split
//      r_i (derive-time search), functional cross-garbage h_jk
//      (r(r+1)/2 pairs — the load-bearing claim-transport family; the
//      quadratic g-family of the JL branch is NOT carried, see the
//      module note below), ONE outer commitment u_i binding (t-hat ||
//      h-hat) BEFORE the fold challenge (AZ-L4(a)/AZB-6 ordering),
//      quinary fold challenges resampled-until-under T_cap = 33
//      (row EB1-tcap, deterministic FS counter), adaptive digit base
//      e_{i+1}: the largest e <= 7 (row EB4-emax) whose fold norm
//      gamma_z = OP_CONC * 2^(e-1) * sqrt(n*D) clears the exact-digit
//      gate 2^22.12 (row H-gate-ed). The FLOOR is sent bare
//      (1 B/coordinate at e <= 7); the verifier evaluates every
//      transported constraint family on it directly.
//
// MODULE NOTE (g-family): the frozen byte-model recurrence (R-EB2 row
// EB2-count) carries r(r+1) garbage rings/level = g (quadratic
// <s_j,s_k>) + h (functional cross terms), r(r+1)/2 each. On the
// exact-digit branch the g-family serves the JL/quadratic-constraint
// machinery this stack does not have: norms are SYNTACTIC (digit
// alphabets bound every recomposed value — PARAMS 3.4 row 2's no-JL
// reading), and no in-protocol check of this implementation consumes
// g. Carrying it as dead committed data to match a modeled byte count
// would be dishonest padding; the implemented witness chain therefore
// carries the h-family only, the byte tables report implemented-vs-
// model rows side by side, and NO NS22-style shrink of the h count is
// applied (R-EB2's actual prohibition — respected).
//
// ONE-PROOF-PER-WITNESS (AGGREGATION_ZK_DESIGN 4.6): the bare floor is
// a challenge-keyed deterministic witness image (AZ-L3); this module
// implements the proof system, the deployment rule lives one layer up.
//
// Verifier-scaling wall (recorded, not hidden): the transported
// constraint chain materializes the aggregated level-0 functional at
// O(N_limb) ring-mults on BOTH sides (the claim kernel has no
// Greyhound row-column split in this implementation). Bytes and
// soundness structure are unaffected; the a (x) b factored kernel
// (PARAMS 2.2/5.3) is the recorded fix for the 7B-scale verifier.

use super::digits::{gamma_max_exact, OP_CONC};
use super::kfield::{KElem, KField, K_DEG};
use super::sumcheck::LkpTranscript;
use super::{
    poly_add, poly_from_small, poly_mul_small, poly_zero, ring_mul_split_kara_fast, Poly, RingCtx,
    XofReader, Zq, D,
};

/// s * p over R_q (argument-order shim over the house poly_scale).
fn scale(zq: &Zq, p: &Poly, s: u64) -> Poly {
    super::poly_scale(zq, s, p)
}

/// The constant polynomial v * X^0.
fn constant(v: u64) -> Poly {
    let mut p = poly_zero();
    p[0] = v;
    p
}

pub const KAPPA_AGG: usize = 11; // freeze row KAP-11 (SC 2.4(b)/5.1)
pub const T_CAP: f64 = 33.0; // freeze row EB1-tcap (SC 1.3/5.4)
pub const FLOOR_E_MAX: u32 = 7; // freeze row EB4-emax (SC 2.4(a))
pub const KDRAW_SLOT_EXP: u32 = 496; // freeze row EB3-kdraw (16*31)

// ---------------------------------------------------------------------------
// Group specs (W-C two-group discipline) and the E-O2-BB opening budget.

#[derive(Clone, Debug)]
pub struct AggTensor {
    pub name: &'static str,
    pub rows: usize,
    pub cols: usize,
    /// Exact-digit class parameters for the VALUE range (frozen class
    /// table UAGB1-1a semantics: the declared e0/l0 the statement
    /// binds).
    pub e0: u32,
    pub l0: usize,
    /// First value-ring index of this tensor inside the group's dense
    /// value space (128 values/ring, row-major).
    pub value_ring_base: usize,
    /// First digit-ring index inside the group's level-0 witness.
    pub digit_ring_base: usize,
}

impl AggTensor {
    pub fn n_values(&self) -> usize {
        self.rows * self.cols
    }
    pub fn n_value_rings(&self) -> usize {
        self.n_values().div_ceil(D)
    }
    pub fn n_digit_rings(&self) -> usize {
        self.n_value_rings() * self.l0
    }
}

/// One commitment group. E-O2' (AGGREGATION_ENCODING_DESIGN 8.2): one
/// batched evaluation proof per group — the builder REFUSES a second
/// (`begin_opening` errors; battery leg asserts it).
#[derive(Debug)]
pub struct AggGroup {
    pub name: &'static str,
    pub tensors: Vec<AggTensor>,
    pub n_digit_rings: usize,
    openings_begun: usize,
}

#[derive(Debug, PartialEq, Eq)]
pub enum AggBuildError {
    /// E-O2-BB: a second batched opening inside one commitment group.
    SecondOpeningInGroup { group: &'static str },
}

impl std::fmt::Display for AggBuildError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AggBuildError::SecondOpeningInGroup { group } => write!(
                f,
                "E-O2-BB build error: second batched opening requested in commitment group '{group}' \
                 (E-O2' allows exactly one per group)"
            ),
        }
    }
}

impl AggGroup {
    pub fn new(name: &'static str) -> AggGroup {
        AggGroup { name, tensors: Vec::new(), n_digit_rings: 0, openings_begun: 0 }
    }

    /// Tensors are appended value-ring/digit-ring contiguously (dense
    /// D-1, no-tail discipline: every tensor must pack rings exactly).
    pub fn add_tensor(&mut self, name: &'static str, rows: usize, cols: usize, e0: u32, l0: usize) {
        assert!(
            (rows * cols) % D == 0,
            "no-tail discipline: tensor {name} must fill value rings exactly"
        );
        let value_ring_base = self.tensors.iter().map(|t| t.n_value_rings()).sum();
        let t = AggTensor { name, rows, cols, e0, l0, value_ring_base, digit_ring_base: self.n_digit_rings };
        self.n_digit_rings += t.n_digit_rings();
        self.tensors.push(t);
    }

    /// E-O2-BB gate: exactly one batched opening per group.
    pub fn begin_opening(&mut self) -> Result<(), AggBuildError> {
        if self.openings_begun >= 1 {
            return Err(AggBuildError::SecondOpeningInGroup { group: self.name });
        }
        self.openings_begun += 1;
        Ok(())
    }

    pub fn openings_begun(&self) -> usize {
        self.openings_begun
    }
}

// ---------------------------------------------------------------------------
// Schedule derivation (the 125M-shape rows are DERIVED here, never
// extrapolated). Every gate cites its freeze row id.

#[derive(Clone, Debug)]
pub struct LevelPlan {
    pub n_in: usize,
    pub e_in: u32,
    pub r: usize,
    pub chunk: usize,
    pub e_next: u32,
    /// Limb counts of the three next-witness families.
    pub l_z: usize,
    pub l_t: usize,
    pub l_h: usize,
    pub n_pairs: usize,
    pub n_out: usize,
}

#[derive(Clone, Debug)]
pub struct EvalSchedule {
    pub levels: Vec<LevelPlan>,
    pub floor_rings: usize,
    pub floor_e: u32,
    pub gamma_headrooms: Vec<f64>,
}

impl EvalSchedule {
    pub fn floor_coords(&self) -> usize {
        self.floor_rings * D
    }
}

/// Adaptive digit base: the largest e with OP_CONC * 2^(e-1) *
/// sqrt(n*D) <= gamma_max(exact-digit) — row H-gate-ed — capped at
/// e <= 7 — row EB4-emax. Panics (derive-time) if even e = 1 fails.
pub fn adaptive_base(n_rings: usize, q: u64) -> u32 {
    let gmax = gamma_max_exact(q);
    let mut e = 1u32;
    while e < FLOOR_E_MAX {
        let gamma = OP_CONC * 2f64.powi(e as i32) * ((n_rings * D) as f64).sqrt();
        if gamma > gmax {
            break;
        }
        e += 1;
    }
    let gamma_e = OP_CONC * 2f64.powi(e as i32 - 1) * ((n_rings * D) as f64).sqrt();
    assert!(
        gamma_e <= gmax,
        "level fold norm {gamma_e:.3e} exceeds the exact-digit gate (row H-gate-ed) even at e0 = 1"
    );
    e
}

/// Balanced-digit limb count covering the symmetric interval [-b, b]
/// (digits.rs semantics: [-2^(e-1), 2^(e-1)-1] per limb).
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

/// Concentration inf-bound of one fold coefficient (house TAIL = 1.3,
/// quinary E[c^2] = 2, digit E[d^2] = (2/3)*4^(e-1) — the spike-EB
/// digit_l2 convention), with +2 bits of restart headroom. The prover
/// asserts the honest fold fits (restart discipline); the adversarial
/// side is bounded by the digit-representable range (R-EB4 chain).
fn fold_coeff_bound(r: usize, e_in: u32) -> i128 {
    let var = 2.0 * (r as f64) * (D as f64) * (2.0 / 3.0) * 4f64.powi(e_in as i32 - 1);
    let conc = 1.3 * var.sqrt();
    let bits = conc.log2().ceil() as u32 + 2;
    1i128 << bits.min(62)
}

/// One level's plan at split r. Interior digit bases are >= 2 (the
/// balanced decomposition; e = 1 is the sign-binary CLASS base of
/// level-0 inputs only) and <= 7 (row EB4-emax via adaptive_base).
fn plan_level(n_in: usize, e_in: u32, r: usize, q: u64) -> LevelPlan {
    let chunk = n_in.div_ceil(r);
    // The next base is chosen against the NEXT witness size, which
    // depends on the limb counts, which depend on the base — resolve by
    // fixed-point from the smallest interior base upward.
    let mut e_next = 2u32;
    for _ in 0..8 {
        let l_z = limbs_for_bound(fold_coeff_bound(r, e_in), e_next);
        let l_t = limbs_for_bound((q as i128 - 1) / 2, e_next);
        let l_h = l_t;
        let n_pairs = r * (r + 1) / 2;
        let n_out = chunk * l_z + r * KAPPA_AGG * l_t + n_pairs * l_h;
        let e_ok = adaptive_base(n_out, q);
        assert!(e_ok >= 2, "interior witness too large for a balanced base");
        if e_ok <= e_next {
            let e_final = e_next.min(e_ok);
            let l_z = limbs_for_bound(fold_coeff_bound(r, e_in), e_final);
            let l_t = limbs_for_bound((q as i128 - 1) / 2, e_final);
            let l_h = l_t;
            let n_out = chunk * l_z + r * KAPPA_AGG * l_t + n_pairs * l_h;
            return LevelPlan { n_in, e_in, r, chunk, e_next: e_final, l_z, l_t, l_h, n_pairs, n_out };
        }
        e_next = e_ok;
    }
    unreachable!("base fixed point diverged");
}

/// Derive the whole schedule: at each level search r for the smallest
/// next witness; stop when recursing stops paying (floor bytes at
/// 1 B/coordinate vs one more 5,680 B level message + the smaller
/// floor). Every level's base and fold norm re-checked against the
/// frozen gates. `force_levels` (battery use) runs exactly that many
/// levels regardless of the byte rule — gates still asserted.
pub fn plan_schedule(n0: usize, e0: u32, q: u64, force_levels: Option<usize>) -> EvalSchedule {
    let gmax = gamma_max_exact(q);
    let mut levels = Vec::new();
    let mut headrooms = Vec::new();
    let mut n = n0;
    let mut e = e0;
    loop {
        // Gate the CURRENT witness (row H-gate-ed + EB4-emax).
        assert!(e <= FLOOR_E_MAX, "digit base {e} exceeds the floor cap (row EB4-emax)");
        let gamma = OP_CONC * 2f64.powi(e as i32 - 1) * ((n * D) as f64).sqrt();
        assert!(gamma <= gmax, "gamma_z 2^{:.2} exceeds the exact-digit gate (row H-gate-ed)", gamma.log2());
        headrooms.push(gmax.log2() - gamma.log2());
        if let Some(k) = force_levels {
            if levels.len() >= k {
                return EvalSchedule { levels, floor_rings: n, floor_e: e, gamma_headrooms: headrooms };
            }
        }
        // Best split.
        let mut best: Option<LevelPlan> = None;
        for r in 2..=n.min(64) {
            let lp = plan_level(n, e, r, q);
            if best.as_ref().is_none_or(|b| lp.n_out < b.n_out) {
                best = Some(lp);
            }
        }
        let best = best.expect("some split exists");
        if force_levels.is_none() {
            // Stop rule: bytes(stop now) vs level wire + bytes(stop next).
            let bytes_now = n * D; // 1 B/coordinate at e <= 7
            let bytes_next = LEVEL_WIRE_BYTES + best.n_out * D;
            if best.n_out >= n || bytes_next >= bytes_now {
                return EvalSchedule { levels, floor_rings: n, floor_e: e, gamma_headrooms: headrooms };
            }
        }
        n = best.n_out;
        e = best.e_next;
        levels.push(best);
    }
}

/// One level message = the combined outer commitment u_i (kappa rings)
/// with the counted 4-byte length prefix: 4 + kappa * 516.
pub const LEVEL_WIRE_BYTES: usize = 4 + KAPPA_AGG * (4 + D * 4);

/// The Tier-Z floor base cap: the F-Z1 masking corner exists only at
/// e_L <= 4 with no limb growth (AGGREGATION_FOLD_PRIVACY_PRICING 3.1;
/// AZB_BATTERY_PLAN Section 4).
pub const TIER_Z_FLOOR_E: u32 = 4;

/// The F-Z1 corner bound (BC's recipe, AZB_BATTERY_PLAN Section 4):
/// b = 27.2 + 0.5*log2(floor_coords / 81,920); the corner survives iff
/// b < 28.00 = log2(q/8), and the limb-growth branch (28.6 + the same
/// scaling) must stay dead.
pub fn fz1_corner_log2(floor_coords: usize) -> f64 {
    27.2 + 0.5 * ((floor_coords as f64) / 81_920.0).log2()
}

/// Tier-Z schedule: the bare schedule with the LAST level re-derived
/// at the corner base e = 4 (interior levels keep their adaptive
/// bases; only the floor is masked). Derive-time asserts: the corner
/// survives at the resulting floor and the growth branch stays dead.
pub fn plan_schedule_tier_z(n0: usize, e0: u32, q: u64, force_levels: Option<usize>) -> EvalSchedule {
    let bare = plan_schedule(n0, e0, q, force_levels);
    assert!(
        !bare.levels.is_empty(),
        "Tier-Z floor treatment needs at least one level (mask the level-0 witness directly is \
         not a designed mode)"
    );
    let mut levels = bare.levels;
    let last = levels.last().unwrap().clone();
    // Re-derive the last level at the forced corner base.
    let l_z = {
        let bound = {
            // Same concentration bound the bare planner uses.
            let var = 2.0 * (last.r as f64) * (D as f64) * (2.0 / 3.0)
                * 4f64.powi(last.e_in as i32 - 1);
            let conc = 1.3 * var.sqrt();
            let bits = conc.log2().ceil() as u32 + 2;
            1i128 << bits.min(62)
        };
        limbs_for_bound(bound, TIER_Z_FLOOR_E)
    };
    let l_t = limbs_for_bound((q as i128 - 1) / 2, TIER_Z_FLOOR_E);
    let l_h = l_t;
    let n_out = last.chunk * l_z + last.r * KAPPA_AGG * l_t + last.n_pairs * l_h;
    let forced = LevelPlan {
        e_next: TIER_Z_FLOOR_E,
        l_z,
        l_t,
        l_h,
        n_out,
        ..last
    };
    *levels.last_mut().unwrap() = forced;
    let floor_rings = n_out;
    let floor_coords = floor_rings * D;
    let b = fz1_corner_log2(floor_coords);
    assert!(
        b < 28.0,
        "F-Z1: the masking corner is CLOSED at this floor ({floor_coords} coords, b = 2^{b:.2})"
    );
    assert!(
        28.6 + 0.5 * ((floor_coords as f64) / 81_920.0).log2() > 28.0,
        "F-Z1: the limb-growth branch must stay dead"
    );
    EvalSchedule {
        levels,
        floor_rings,
        floor_e: TIER_Z_FLOOR_E,
        gamma_headrooms: bare.gamma_headrooms,
    }
}

// ---------------------------------------------------------------------------
// The Tier-Z masked floor (the E2/E4 carve-out under Amendment A1;
// FP 1.4 reconciliation): the ONLY rejection-sampled Gaussian-masked
// object in the aggregate layer — everywhere else I-6 stands. The
// mask is PROVER-INTERNAL (never committed; no hash edge exists or is
// needed — FP-L2 row A8); the response is sent after ALL of the
// group's level challenges (AZB-6 unchanged). The sampler follows the
// F-Z3 discipline: rejection-sampled, abort counts logged; the exact
// FS-with-aborts transcription is obligation F-Z2 (Q4.2a' class), not
// discharged here.

/// The masked-floor response bound (per coefficient): the F-Z1 corner
/// line 2^b at this floor, the verifier's acceptance gate. 4 B/coord
/// wire class (29 bits + sign).
pub fn tier_z_response_bound(floor_coords: usize) -> i64 {
    2f64.powf(fz1_corner_log2(floor_coords)) as i64
}

/// Mask sigma: the corner bound over 8 (a >= 8-sigma clip margin for
/// the honest response; the shift |c (x) w|_inf at e <= 4 digits is
/// 2^11-class, ~2^13 under sigma — the rejection test removes the
/// shift dependence, F-Z2's transcription owing the exact constant).
pub fn tier_z_sigma(floor_coords: usize) -> f64 {
    2f64.powf(fz1_corner_log2(floor_coords)) / 8.0
}

// ---------------------------------------------------------------------------
// Exact operator norm of a negacyclic multiplier (T_cap acceptance).
// A negacyclic circulant diagonalizes over C at the 128 primitive odd
// 256th roots of unity; the spectral norm is max_j |c(w_j)|.

pub fn opnorm_negacyclic(c: &[i64]) -> f64 {
    let mut max_sq = 0f64;
    for j in 0..D {
        let theta = std::f64::consts::PI * (2 * j + 1) as f64 / (D as f64);
        let (mut re, mut im) = (0f64, 0f64);
        // c(w) = sum c_k w^k, w = e^{i theta} (w^128 = e^{i pi (2j+1)} = -1).
        let (dc, ds) = (theta.cos(), theta.sin());
        let (mut cr, mut ci) = (1f64, 0f64);
        for &ck in c {
            re += ck as f64 * cr;
            im += ck as f64 * ci;
            let nr = cr * dc - ci * ds;
            ci = cr * ds + ci * dc;
            cr = nr;
        }
        let sq = re * re + im * im;
        if sq > max_sq {
            max_sq = sq;
        }
    }
    max_sq.sqrt()
}

/// Quinary fold challenge under the R-EB1 cap: coefficients uniform in
/// {-2..2}, resampled (deterministic FS counter) until the exact
/// operator norm is <= T_cap = 33 (row EB1-tcap; ~38% acceptance, ~3
/// attempts expected — SC 1.3's MC row). Returns (challenge, attempts).
pub fn draw_quinary_capped(state: &[u8; 32], label: &str, index: u64) -> (Vec<i64>, u32) {
    let mut attempt = 0u32;
    loop {
        let mut rd = XofReader::new(
            "agg-quinary",
            &[state, label.as_bytes(), &index.to_le_bytes(), &attempt.to_le_bytes()],
        );
        let c: Vec<i64> = (0..D).map(|_| rd.next_field(5) as i64 - 2).collect();
        if opnorm_negacyclic(&c) <= T_CAP + 1e-9 {
            return (c, attempt + 1);
        }
        attempt += 1;
        assert!(attempt < 64, "T_cap resampling diverged (p ~ 0.38/attempt)");
    }
}

/// Full-entropy R_q aggregation challenge (the R-EB3 K-draw class:
/// per-slot mass q^-16 — row EB3-kdraw).
pub fn draw_alpha(state: &[u8; 32], label: &str, index: u64, q: u64) -> Poly {
    let mut rd = XofReader::new("agg-alpha", &[state, label.as_bytes(), &index.to_le_bytes()]);
    (0..D).map(|_| rd.next_field(q)).collect()
}

// ---------------------------------------------------------------------------
// conj-packing: sigma_{-1}(a)(X) = a(X^{-1}) in R_q; ct(conj(a) * b) =
// <coeffs(a), coeffs(b)> (SOUNDNESS_REFERENCE 1.2 fact 3; asserted by
// the module self-check in the bin battery).

pub fn conj_poly(zq: &Zq, a: &Poly) -> Poly {
    let mut out = poly_zero();
    out[0] = a[0];
    for i in 1..D {
        out[i] = zq.neg(a[D - i]);
    }
    out
}

// ---------------------------------------------------------------------------
// The witness layout of one level's OUTPUT (= next level's input):
// [ z-hat | t-hat | h-hat ], each family limb-major per source ring.
// Public function of the plan; both sides derive it identically.

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Fam {
    Z,
    T,
    H,
}

#[derive(Clone, Debug)]
pub struct NextLayout {
    pub plan: LevelPlan,
    pub z_base: usize,
    pub t_base: usize,
    pub h_base: usize,
    pub n_total: usize,
}

impl NextLayout {
    pub fn new(plan: &LevelPlan) -> NextLayout {
        let z_len = plan.chunk * plan.l_z;
        let t_len = plan.r * KAPPA_AGG * plan.l_t;
        let h_len = plan.n_pairs * plan.l_h;
        NextLayout {
            plan: plan.clone(),
            z_base: 0,
            t_base: z_len,
            h_base: z_len + t_len,
            n_total: z_len + t_len + h_len,
        }
    }
    /// (family, source ring index within the family, limb index).
    pub fn locate(&self, u: usize) -> (Fam, usize, usize) {
        if u < self.t_base {
            let (src, limb) = (u / self.plan.l_z, u % self.plan.l_z);
            (Fam::Z, src, limb)
        } else if u < self.h_base {
            let v = u - self.t_base;
            let (src, limb) = (v / self.plan.l_t, v % self.plan.l_t);
            (Fam::T, src, limb)
        } else {
            let v = u - self.h_base;
            let (src, limb) = (v / self.plan.l_h, v % self.plan.l_h);
            (Fam::H, src, limb)
        }
    }
    pub fn z_ring(&self, src: usize, limb: usize) -> usize {
        self.z_base + src * self.plan.l_z + limb
    }
    pub fn t_ring(&self, j: usize, kap: usize, limb: usize) -> usize {
        self.t_base + (j * KAPPA_AGG + kap) * self.plan.l_t + limb
    }
    pub fn h_ring(&self, pair: usize, limb: usize) -> usize {
        self.h_base + pair * self.plan.l_h + limb
    }
}

/// Pair index of (j, k), j <= k, in the upper-triangular order.
pub fn pair_index(r: usize, j: usize, k: usize) -> usize {
    debug_assert!(j <= k && k < r);
    j * r - j * (j + 1) / 2 + k
}

// ---------------------------------------------------------------------------
// Level CRS expansion (seed-expanded, statement-bound; the A_i inner
// matrix is kappa x chunk, the B_i outer matrix is kappa x (t+h) —
// both derived from (seed, group, level) so prover and verifier agree
// without wire cost).

pub fn expand_level_matrix(seed: u64, group: &str, level: usize, which: &str, rows: usize, cols: usize, q: u64) -> Vec<Poly> {
    let mut rd = XofReader::new(
        "agg-level-crs",
        &[
            &seed.to_le_bytes(),
            group.as_bytes(),
            &(level as u64).to_le_bytes(),
            which.as_bytes(),
            &(rows as u64).to_le_bytes(),
            &(cols as u64).to_le_bytes(),
        ],
    );
    (0..rows * cols).map(|_| (0..D).map(|_| rd.next_field(q)).collect()).collect()
}

/// t = M s over R_q: rows x cols mod-q matrix times a small (digit)
/// ring column vector.
pub fn matvec_modq_small(ctx: &RingCtx, m: &[Poly], rows: usize, cols: usize, s: &[Vec<i64>]) -> Vec<Poly> {
    assert_eq!(s.len(), cols);
    assert_eq!(m.len(), rows * cols);
    let zq = &ctx.zq;
    (0..rows)
        .map(|r| {
            let mut acc = poly_zero();
            for (c, sc) in s.iter().enumerate() {
                if sc.iter().all(|&x| x == 0) {
                    continue;
                }
                let p = ring_mul_split_kara_fast(ctx, &m[r * cols + c], &poly_from_small(zq, sc));
                acc = poly_add(zq, &acc, &p);
            }
            acc
        })
        .collect()
}

/// <phi, s> = sum_u phi_u * s_u over R_q (mod-q functional times small
/// witness slice).
pub fn ring_ip_modq_small(ctx: &RingCtx, phi: &[Poly], s: &[Vec<i64>]) -> Poly {
    assert_eq!(phi.len(), s.len());
    let zq = &ctx.zq;
    let mut acc = poly_zero();
    for (p, sc) in phi.iter().zip(s.iter()) {
        if sc.iter().all(|&x| x == 0) {
            continue;
        }
        let m = ring_mul_split_kara_fast(ctx, p, &poly_from_small(zq, sc));
        acc = poly_add(zq, &acc, &m);
    }
    acc
}

/// Centered digit decomposition of a mod-q polynomial at base e, l
/// limbs (limb-major output: out[limb][coeff]).
pub fn decompose_poly_modq(zq: &Zq, p: &Poly, e: u32, l: usize) -> Vec<Vec<i64>> {
    let mut out = vec![vec![0i64; D]; l];
    for c in 0..D {
        let digs = super::digits::exact_digit_decompose(zq.center(p[c]), e.max(2), l);
        for (a, d) in digs.into_iter().enumerate() {
            out[a][c] = d;
        }
    }
    out
}

/// Centered digit decomposition of a small integer polynomial.
pub fn decompose_poly_small(p: &[i64], e: u32, l: usize) -> Vec<Vec<i64>> {
    let mut out = vec![vec![0i64; D]; l];
    for c in 0..D {
        let digs = super::digits::exact_digit_decompose(p[c], e.max(2), l);
        for (a, d) in digs.into_iter().enumerate() {
            out[a][c] = d;
        }
    }
    out
}

/// Recompose limb-major digit rings into a centered i64 polynomial.
pub fn recompose_rings(digs: &[&Vec<i64>], e: u32) -> Vec<i64> {
    let mut out = vec![0i64; D];
    for (a, ring) in digs.iter().enumerate() {
        let w = 1i64 << (e as usize * a);
        for c in 0..D {
            out[c] += ring[c] * w;
        }
    }
    out
}

// ---------------------------------------------------------------------------
// The per-level constraint system over the NEXT witness, in the form
// both sides materialize identically. Each level's four families:
//   T1: sum_j rec(h_jj)                       = H_i          (1 row)
//   L1: Psi(rec(z)) - sum_{j<=k} cpair rec(h) = 0            (1 row)
//   T4: A_i rec(z) - sum_j c_j rec(t_j)       = 0        (kappa rows)
//   T5: B_i (t-hat || h-hat)                  = u_i      (kappa rows)
// aggregated with fresh full-entropy alphas into (Phi_{i+1}, H_{i+1}).
// Coefficient vectors are materialized aggregated-only (memory).

pub struct LevelTransport {
    pub phi_next: Vec<Poly>,
    pub h_next: Poly,
}

/// One outer-commitment binding of a level: u = b_mat x (the witness
/// slice [col_base, col_base + cols) of the NEXT witness, positions
/// relative to the t-hat base). Level 0 carries two bindings (u_0 over
/// t-hat, u_gh0 over h-hat); deeper levels one combined binding.
pub struct OuterBinding<'a> {
    pub b_mat: &'a [Poly], // kappa x cols
    pub col_base: usize,   // relative to layout.t_base
    pub cols: usize,
    pub u: &'a [Poly], // kappa rings
}

/// Aggregation rows of one level: T1 (1) + L1 (1) + T4 (kappa) + T5
/// (kappa per binding).
pub fn transport_rows(n_bindings: usize) -> usize {
    2 + KAPPA_AGG + KAPPA_AGG * n_bindings
}

#[allow(clippy::too_many_arguments)]
pub fn transport_level(
    ctx: &RingCtx,
    phi: &[Poly],       // aggregated functional over w^(i) (n_in rings)
    h_target: &Poly,    // H_i
    plan: &LevelPlan,
    layout: &NextLayout,
    a_mat: &[Poly],     // kappa x chunk
    bindings: &[OuterBinding],
    c: &[Vec<i64>],     // r quinary fold challenges
    alphas: &[Poly],    // transport_rows(bindings.len()) aggregation challenges
) -> LevelTransport {
    let zq = &ctx.zq;
    let n_rows = transport_rows(bindings.len());
    assert_eq!(alphas.len(), n_rows);
    let (a_t1, a_l1) = (&alphas[0], &alphas[1]);
    let a_t4 = &alphas[2..2 + KAPPA_AGG];
    let a_t5 = &alphas[2 + KAPPA_AGG..];
    let psi = compute_psi(ctx, phi, plan.chunk, c);
    let cpair = compute_cpairs(zq, c);
    // T5 contribution of a next-witness position (relative to t_base).
    let t5_at = |pos: usize, acc: &mut Poly| {
        for (bi, b) in bindings.iter().enumerate() {
            if pos >= b.col_base && pos < b.col_base + b.cols {
                let rel = pos - b.col_base;
                for kap2 in 0..KAPPA_AGG {
                    let coeff = &b.b_mat[kap2 * b.cols + rel];
                    let ak = &a_t5[bi * KAPPA_AGG + kap2];
                    *acc = poly_add(zq, acc, &ring_mul_split_kara_fast(ctx, ak, coeff));
                }
            }
        }
    };
    // Aggregated coefficient per next-witness ring.
    let phi_next: Vec<Poly> = (0..layout.n_total)
        .map(|u| {
            let (fam, src, limb) = layout.locate(u);
            let mut acc = poly_zero();
            match fam {
                Fam::Z => {
                    let radix = zq.to_mod(1i64 << (plan.e_next as usize * limb));
                    // L1: + radix * Psi_src
                    let l1 = scale(zq, &psi[src], radix);
                    acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, a_l1, &l1));
                    // T4 row kap: + radix * A[kap][src]
                    for (kap, ak) in a_t4.iter().enumerate() {
                        let t4 = scale(zq, &a_mat[kap * plan.chunk + src], radix);
                        acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, ak, &t4));
                    }
                }
                Fam::T => {
                    let (j, kap) = (src / KAPPA_AGG, src % KAPPA_AGG);
                    let radix = 1i64 << (plan.e_next as usize * limb);
                    // T4 row kap: - radix * c_j
                    let neg_c: Vec<i64> = c[j].iter().map(|&x| -x * radix).collect();
                    let t4 = poly_from_small(zq, &neg_c);
                    acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, &a_t4[kap], &t4));
                    t5_at(u - layout.t_base, &mut acc);
                }
                Fam::H => {
                    let radix_u = zq.to_mod(1i64 << (plan.e_next as usize * limb));
                    let (j, k) = pair_from_index(plan.r, src);
                    // T1: + radix on diagonal pairs
                    if j == k {
                        let t1 = constant(radix_u);
                        acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, a_t1, &t1));
                    }
                    // L1: - radix * cpair
                    let l1 = scale(zq, &cpair[src], zq.neg(radix_u));
                    acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, a_l1, &l1));
                    t5_at(u - layout.t_base, &mut acc);
                }
            }
            acc
        })
        .collect();
    // Aggregated target: alpha_T1 * H_i + sum over bindings alpha_T5 * u.
    let mut h_next = ring_mul_split_kara_fast(ctx, a_t1, h_target);
    for (bi, b) in bindings.iter().enumerate() {
        for (kap, uk) in b.u.iter().enumerate() {
            let ak = &a_t5[bi * KAPPA_AGG + kap];
            h_next = poly_add(zq, &h_next, &ring_mul_split_kara_fast(ctx, ak, uk));
        }
    }
    LevelTransport { phi_next, h_next }
}

/// Psi over the chunk-position space: Psi_u = sum_k c_k phi[k*chunk+u]
/// (tail chunks zero-padded) — the c-weighted fold of the aggregated
/// functional's chunk slices.
pub fn compute_psi(ctx: &RingCtx, phi: &[Poly], chunk: usize, c: &[Vec<i64>]) -> Vec<Poly> {
    let zq = &ctx.zq;
    (0..chunk)
        .map(|u| {
            let mut acc = poly_zero();
            for (k, ck) in c.iter().enumerate() {
                let idx = k * chunk + u;
                if idx < phi.len() {
                    let m = ring_mul_split_kara_fast(ctx, &phi[idx], &poly_from_small(zq, ck));
                    acc = poly_add(zq, &acc, &m);
                }
            }
            acc
        })
        .collect()
}

/// cpair_{jk} = c_j * c_k in pair order (j <= k; j = k gives c_j^2 —
/// the h-family's symmetric-definition weights).
pub fn compute_cpairs(zq: &Zq, c: &[Vec<i64>]) -> Vec<Poly> {
    let r = c.len();
    let mut v = Vec::with_capacity(r * (r + 1) / 2);
    for j in 0..r {
        for k in j..r {
            let prod = poly_mul_small(&c[j], &c[k]);
            v.push(poly_from_small(zq, &prod));
        }
    }
    v
}

/// Inverse of pair_index.
pub fn pair_from_index(r: usize, mut idx: usize) -> (usize, usize) {
    for j in 0..r {
        let row = r - j;
        if idx < row {
            return (j, j + idx);
        }
        idx -= row;
    }
    panic!("pair index out of range");
}

// ---------------------------------------------------------------------------
// The proof object (wire) and its counted-byte accounting (64 B/K-el,
// 4 B/q31 coeff, poly = 4 + 512; counted-not-serialized — the
// canonical wire format is the stage-5 stretch).

pub struct GroupEvalProof {
    /// Level-0 outer commitment over t-hat(0) (pre-h0_agg: binds data).
    pub u0: Vec<Poly>,
    /// Level-0 garbage commitment over h-hat(0) (post-alpha, pre-c).
    pub ugh0: Vec<Poly>,
    /// The 16 claim-row ring values B_c (ct pinned to the K-claim).
    pub b_rows: Vec<Poly>,
    /// Levels >= 1: one combined outer commitment each.
    pub level_us: Vec<Vec<Poly>>,
    /// The bare floor witness (digit rings, centered).
    pub floor: Vec<Vec<i64>>,
    pub floor_e: u32,
    /// T_cap resample attempts per fold draw (diagnostics; FS counter
    /// is deterministic, no wire).
    pub tcap_attempts: Vec<u32>,
}

impl GroupEvalProof {
    pub fn counted_bytes(&self) -> GroupEvalBytes {
        let polyb = 4 + D * 4;
        let n_outer = 1 + usize::from(!self.ugh0.is_empty());
        GroupEvalBytes {
            outer_identities: n_outer * (4 + KAPPA_AGG * polyb),
            claim_rows: 4 + self.b_rows.len() * polyb,
            level_msgs: self.level_us.len() * (4 + KAPPA_AGG * polyb),
            floor: 4 + self.floor.len() * D * byte_per_coord(self.floor_e),
        }
    }
}

pub fn byte_per_coord(e: u32) -> usize {
    ((e as usize + 1) + 7) / 8
}

#[derive(Clone, Copy, Debug)]
pub struct GroupEvalBytes {
    pub outer_identities: usize,
    pub claim_rows: usize,
    pub level_msgs: usize,
    pub floor: usize,
}

impl GroupEvalBytes {
    pub fn total(&self) -> usize {
        self.outer_identities + self.claim_rows + self.level_msgs + self.floor
    }
}

// ---------------------------------------------------------------------------
// The claim layer: per-tensor product-form kernels. A tensor claim is
// MLE(T)(z) = v with weight of value f = row_kernel[f / cols] *
// col_kernel[f % cols] (both K-element tables, nu folded in by the
// caller). Multi-claim-per-tensor inputs ADD their weight tables (the
// CR-L4a mu-RLC lands additively in the same rows) — a folded instance
// family therefore remains a valid input (F-IF1 not foreclosed).

pub struct TensorClaimKernel {
    pub tensor_idx: usize,
    pub row_kernel: Vec<KElem>,
    pub col_kernel: Vec<KElem>,
}

/// The batched K-weight of value f of tensor t (product form).
fn value_weight(kf: &KField, ker: &TensorClaimKernel, cols: usize, f: usize) -> KElem {
    kf.mul(&ker.row_kernel[f / cols], &ker.col_kernel[f % cols])
}

/// Per digit-ring K-weight row: kw[c1] = radix_l * W(value at (u, c1)),
/// where u is the tensor's digit ring (value-ring vr, limb l).
/// Returns None for rings whose values are all out of range (never
/// happens under no-tail).
pub struct ClaimKernelCtx<'a> {
    pub kf: &'a KField,
    pub group: &'a AggGroup,
    pub kernels: Vec<TensorClaimKernel>,
}

impl ClaimKernelCtx<'_> {
    /// K-weight row of digit ring u (length D).
    pub fn kw_row(&self, u: usize) -> Vec<KElem> {
        let kf = self.kf;
        for (ti, t) in self.group.tensors.iter().enumerate() {
            let lo = t.digit_ring_base;
            let hi = lo + t.n_digit_rings();
            if u >= lo && u < hi {
                let rel = u - lo;
                let (vr, limb) = (rel / t.l0, rel % t.l0);
                let radix = kf.zq.to_mod(1i64 << (t.e0 as usize * limb));
                let ker = self.kernels.iter().find(|k| k.tensor_idx == ti);
                let mut out = vec![kf.zero(); D];
                if let Some(ker) = ker {
                    for (c1, o) in out.iter_mut().enumerate() {
                        let f = vr * D + c1;
                        if f < t.n_values() {
                            *o = kf.scale(radix, &value_weight(kf, ker, t.cols, f));
                        }
                    }
                }
                return out;
            }
        }
        panic!("digit ring {u} outside group");
    }

    /// The 16 base-field conj-packed weight polys of ring u: row c is
    /// conj_pack(coordinate-c slice of the kw row), so that
    /// ct(bpoly_c * w_u) = sum_c1 kw[c1][c] * w_u[c1].
    pub fn bpolys(&self, zq: &Zq, u: usize) -> Vec<Poly> {
        let kw = self.kw_row(u);
        (0..K_DEG)
            .map(|cd| {
                let mut base = poly_zero();
                for (c1, w) in kw.iter().enumerate() {
                    base[c1] = w[cd];
                }
                conj_poly(zq, &base)
            })
            .collect()
    }
}

// ---------------------------------------------------------------------------

/// Absorb a poly list into the transcript (canonical bytes).
pub fn absorb_polys(tr: &mut LkpTranscript, label: &str, polys: &[Poly]) {
    tr.absorb(label, &super::polys_bytes(polys));
}

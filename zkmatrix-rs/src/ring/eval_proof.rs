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
// Verifier-scaling wall — CLOSED FOR THE VERIFIER at wave 3 ([UAGB1-BH]):
// the wave-2 implementation materialized the aggregated level-0
// functional at O(N_limb) ring-mults on BOTH sides. The verifier-side
// fix is the Greyhound row-column split (PARAMS 2.2/5.3), implemented
// here as `psi_level0_factored` + `transport_level_from_psi`: in the
// recursed path Phi_0 is consumed ONLY through Psi_0 = compute_psi(
// Phi_0, chunk_0, c_0) (the level-1 L1 rows; the floor/Tier-Z L1 for
// one-level schedules), and Psi_0 is computed DIRECTLY from the
// rank-1 kernel factors without materializing Phi_0 or the N-value
// weight table. Exact mod-q identity (sum regrouping only): the wire,
// the transcript, and every verdict are bit-identical — asserted by
// the [UAGB1-BH] differential battery. The PROVER still materializes
// Phi_0 (its h-garbage consumes phi chunk slices); the prover-side
// constant is a separate item.

use super::ct_engine::prof; // [UPERF-PC] phase counters (observation only)
use super::digits::{gamma_max_exact, OP_CONC};
use super::kfield::{KElem, KField, K_DEG};
use super::sumcheck::LkpTranscript;
use super::{
    poly_add, poly_from_small, poly_mul_small, poly_zero, ring_mul_split_kara_fast, Poly, RingCtx,
    XofReader, Zq, D,
};
use std::collections::HashMap;
use std::sync::{Arc, LazyLock, Mutex};

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
//
// [UPERF-PC O1] Memoized: prove-then-verify of the same group reuses
// the XOF image. Values are byte-identical to the uncached expansion
// (`expand_level_matrix_raw`). The cache is process-global and does
// not touch the transcript.

#[derive(Clone, Eq, PartialEq, Hash)]
struct CrsKey {
    seed: u64,
    group: String,
    level: u64,
    which: String,
    rows: u64,
    cols: u64,
    q: u64,
}

static CRS_CACHE: LazyLock<Mutex<HashMap<CrsKey, Arc<Vec<Poly>>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// Drop cached CRS matrices (tests / differential battery).
pub fn clear_crs_cache() {
    CRS_CACHE.lock().expect("crs cache").clear();
}

/// Uncached XOF expansion — the O1 oracle. Public so `uperf-pc
/// diff-battery` can assert byte identity against the memoized path.
pub fn expand_level_matrix_raw(
    seed: u64,
    group: &str,
    level: usize,
    which: &str,
    rows: usize,
    cols: usize,
    q: u64,
) -> Vec<Poly> {
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
    (0..rows * cols)
        .map(|_| (0..D).map(|_| rd.next_field(q)).collect())
        .collect()
}

pub fn expand_level_matrix(
    seed: u64,
    group: &str,
    level: usize,
    which: &str,
    rows: usize,
    cols: usize,
    q: u64,
) -> Vec<Poly> {
    let key = CrsKey {
        seed,
        group: group.to_string(),
        level: level as u64,
        which: which.to_string(),
        rows: rows as u64,
        cols: cols as u64,
        q,
    };
    {
        let cache = CRS_CACHE.lock().expect("crs cache");
        if let Some(hit) = cache.get(&key) {
            prof::bump(prof::EP_CRS_HIT);
            return hit.as_ref().clone();
        }
    }
    let _t = prof::timer(prof::EP_CRS); // miss: time the XOF
    let v = expand_level_matrix_raw(seed, group, level, which, rows, cols, q);
    CRS_CACHE
        .lock()
        .expect("crs cache")
        .insert(key, Arc::new(v.clone()));
    v
}

/// t = M s over R_q: rows x cols mod-q matrix times a small (digit)
/// ring column vector. [UPERF-PC O3] NTT-domain body (`ntt_gemm_modq_small`
/// with one small vector); `matvec_modq_small_ref` is the Karatsuba
/// oracle it is bit-identical to (diff-battery leg O3).
pub fn matvec_modq_small(ctx: &RingCtx, m: &[Poly], rows: usize, cols: usize, s: &[Vec<i64>]) -> Vec<Poly> {
    let _t = prof::timer(prof::EP_MATVEC); // [UPERF-PC] observation only
    assert_eq!(s.len(), cols);
    assert_eq!(m.len(), rows * cols);
    if oracle_mode() {
        return matvec_modq_small_ref(ctx, m, rows, cols, s);
    }
    let a: Vec<&[Poly]> = (0..rows).map(|r| &m[r * cols..(r + 1) * cols]).collect();
    ntt_gemm_modq_small(ctx, &a, &[s], cols)
}

/// One mod-q matrix against MANY small vectors (the level matvecs
/// `A x w_j` for all r chunk slices j): M is transformed once and every
/// small ring once. Returns `out[i][row]` = (M s_i)[row], i.e. one
/// rows-vector per input vector, in input order. Bit-identical to
/// calling `matvec_modq_small` per vector.
pub fn matvec_modq_small_multi(
    ctx: &RingCtx,
    m: &[Poly],
    rows: usize,
    cols: usize,
    s_list: &[&[Vec<i64>]],
) -> Vec<Vec<Poly>> {
    let _t = prof::timer(prof::EP_MATVEC); // [UPERF-PC] observation only
    assert_eq!(m.len(), rows * cols);
    for s in s_list {
        assert_eq!(s.len(), cols);
    }
    if oracle_mode() {
        return s_list.iter().map(|s| matvec_modq_small_ref(ctx, m, rows, cols, s)).collect();
    }
    let a: Vec<&[Poly]> = (0..rows).map(|r| &m[r * cols..(r + 1) * cols]).collect();
    let flat = ntt_gemm_modq_small(ctx, &a, s_list, cols); // [row][i]
    let n_s = s_list.len();
    (0..n_s)
        .map(|i| (0..rows).map(|row| flat[row * n_s + i].clone()).collect())
        .collect()
}

/// The Karatsuba oracle for `matvec_modq_small` (the pre-O3 body; battery
/// use only — every call site rides the NTT-domain body).
pub fn matvec_modq_small_ref(ctx: &RingCtx, m: &[Poly], rows: usize, cols: usize, s: &[Vec<i64>]) -> Vec<Poly> {
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
/// witness slice). [UPERF-PC O3] NTT-domain body; `ring_ip_modq_small_ref`
/// is the oracle.
pub fn ring_ip_modq_small(ctx: &RingCtx, phi: &[Poly], s: &[Vec<i64>]) -> Poly {
    let _t = prof::timer(prof::EP_IP); // [UPERF-PC] observation only
    assert_eq!(phi.len(), s.len());
    if oracle_mode() {
        return ring_ip_modq_small_ref(ctx, phi, s);
    }
    let mut out = ntt_gemm_modq_small(ctx, &[phi], &[s], phi.len());
    out.pop().expect("one output")
}

/// The Karatsuba oracle for `ring_ip_modq_small` (battery use only).
pub fn ring_ip_modq_small_ref(ctx: &RingCtx, phi: &[Poly], s: &[Vec<i64>]) -> Poly {
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

// ---------------------------------------------------------------------------
// [UPERF-PC O2/O3] The NTT-domain multiply-accumulate kernel.
//
// Every hot loop of the composed prover's eval proof (the level h
// cross-garbage, the A / B outer matvecs, ring inner products) is a
// contraction of MOD-q rings against SMALL rings:
//
//     out[ia][ib] = sum_{u < len} a[ia][u] * b[ib][u]        over R_q,
//
// a = na slices of len mod-q rings, b = nb slices of len small rings
// (|coeff| <= s_max). Evaluated as D = 128 independent (na x len) x
// (len x nb) integer GEMMs in the Goldilocks NTT domain (aux_ntt_core):
// every ring is transformed exactly ONCE, products accumulate with the A1
// split-halves discipline (low/high u128 halves, no per-product
// reduction), and the accumulation leaves the NTT domain once per
// (output, window). A window is the largest run of terms that keeps the
// exact-integer contract  n * D * (q-1)/2 * s_max <= (p-1)/2
// (`aux::max_n_acc`) — every recovered coefficient is then the TRUE
// integer of the partial sum, reduced mod q and added; the result is
// BIT-IDENTICAL to the Karatsuba oracles above. Windows are fixed by
// (q, s_max, len) — never by thread count or data order — so a later
// parallel split (TASK_BOARD T6) cannot move a byte. If even one product
// exceeds capacity (s_max too large for q) the kernel falls back to the
// oracle rather than limb-split; the composed pass never hits that
// (digits |w| <= 64 at q31: windows of 2^20 terms).
//
// Cost model at 125M level 0 (act group, r = 64, chunk 122K): 2 * n_0
// forward transforms (~0.35 us each) + r^2 * chunk * D = 64G split-halves
// MACs, vs 500M Karatsuba ring-mults (~2 us each, ~11 allocations each).

static NTT: LazyLock<super::aux::NttTables> = LazyLock::new(super::aux::build_tables);

/// [UPERF-PC] `ZK_UPERF_ORACLE=1` routes every Phase-0 kernel entry
/// point (matvec / ring-ip / level-h / kernel passes / factored psi) to
/// its pre-optimization oracle at runtime — the one-binary A/B: the
/// EVAL-PROOF DIGEST must be identical with and without it, and the
/// walls give the before/after at the same box state. Read once.
static ORACLE_MODE: LazyLock<std::sync::atomic::AtomicBool> = LazyLock::new(|| {
    std::sync::atomic::AtomicBool::new(std::env::var("ZK_UPERF_ORACLE").map(|v| v == "1").unwrap_or(false))
});

#[inline(always)]
pub fn oracle_mode() -> bool {
    ORACLE_MODE.load(std::sync::atomic::Ordering::Relaxed)
}

/// Harness-only: flip the oracle routing at runtime (the in-process
/// end-to-end differential in `uperf-pc diff-battery` proves the same
/// group under both routings; production never calls this).
pub fn set_oracle_mode(on: bool) {
    ORACLE_MODE.store(on, std::sync::atomic::Ordering::Relaxed);
}

/// [UPERF-PC T6] `ZK_THREADS=n` (default 1 — the ledger's 1T baseline
/// convention) sizes the kernel thread pool. Every parallel split below
/// is over INDEPENDENT exact-integer work (coefficient positions t of
/// the NTT-domain GEMM; value rings of the factored passes) with a fixed
/// serial reduction order, so the result is bit-identical for any n.
static THREADS: LazyLock<usize> = LazyLock::new(|| {
    std::env::var("ZK_THREADS").ok().and_then(|v| v.parse::<usize>().ok()).filter(|&n| n >= 1).unwrap_or(1)
});

pub fn threads() -> usize {
    *THREADS
}

static POOL: LazyLock<rayon::ThreadPool> = LazyLock::new(|| {
    rayon::ThreadPoolBuilder::new().num_threads(threads()).build().expect("ZK_THREADS pool")
});

/// Run `f` on the kernel pool when threads() > 1, inline otherwise.
fn pooled<R: Send>(f: impl FnOnce() -> R + Send) -> R {
    if threads() > 1 { POOL.install(f) } else { f() }
}

/// Positions per u-block: the transformed block (na + nb) * B rings x 1 KiB
/// must stay cache-resident next to the accumulators.
const GEMM_BLOCK: usize = 64;

/// sum_i a[i]*b[i] as (low-halves sum, high-halves sum) — the A1
/// split-halves accumulator (each product's u64 halves summed in
/// separate u128s; exact for < 2^31 terms). Measured ~1.6 ns/term on
/// the WSL box; 2- and 4-chain unrolls were not faster (register
/// pressure), so the plain loop stays.
#[inline(always)]
fn dot_split_halves(a: &[u64], b: &[u64]) -> (u128, u128) {
    let (mut lo, mut hi) = (0u128, 0u128);
    for (&av, &bv) in a.iter().zip(b.iter()) {
        let prod = av as u128 * bv as u128;
        lo += prod as u64 as u128;
        hi += (prod >> 64) as u128;
    }
    (lo, hi)
}

/// The largest number of (mod-q ring) x (small ring, |coeff| <= s_max)
/// products that may accumulate in Z_p before an exact recovery; 0 = a
/// single product does not fit (the caller falls back to the oracle).
pub fn ntt_window_terms(q: u64, s_max: u128) -> usize {
    super::aux::max_n_acc(((q - 1) / 2) as u128, s_max.max(1)).min(1 << 31) as usize
}

/// out[ia * nb + ib] = sum_u a[ia][u] * b[ib][u] over R_q — see the module
/// note above. `a[ia].len() == b[ib].len() == len` for every slice.
pub fn ntt_gemm_modq_small(ctx: &RingCtx, a: &[&[Poly]], b: &[&[Vec<i64>]], len: usize) -> Vec<Poly> {
    use super::aux::{
        balanced_mod_q, center_from_p, lift_to_p, mod_q_centered, ntt_fwd, ntt_inv, reduce128, EPS,
    };
    let zq = &ctx.zq;
    let q = zq.q;
    let (na, nb) = (a.len(), b.len());
    for s in a {
        assert_eq!(s.len(), len, "a slice length");
    }
    for s in b {
        assert_eq!(s.len(), len, "b slice length");
    }
    let mut out = vec![poly_zero(); na * nb];
    if na == 0 || nb == 0 || len == 0 {
        return out;
    }
    // Operand bound of the small side (exact, from the data — the
    // window is then a function of (q, s_max, len) only).
    let s_max: u128 = b
        .iter()
        .flat_map(|s| s.iter())
        .flat_map(|ring| ring.iter())
        .map(|&x| x.unsigned_abs() as u128)
        .max()
        .unwrap_or(0);
    let window = ntt_window_terms(q, s_max);
    if window == 0 {
        // Over capacity for the single-prime contract: exact oracle.
        for (ia, sa) in a.iter().enumerate() {
            for (ib, sb) in b.iter().enumerate() {
                out[ia * nb + ib] = ring_ip_modq_small_ref(ctx, sa, sb);
            }
        }
        return out;
    }
    let t = &*NTT;
    let bsz = GEMM_BLOCK.min(len).min(window);
    // With threads, a larger u-block amortizes the fork/join per block
    // (each block is a fixed unit of work; results are block-order
    // independent because the accumulators are exact integers).
    let bsz = if threads() > 1 { (bsz * 4).min(len).min(window) } else { bsz };
    // NTT-domain blocks, both ub-contiguous so the (t, ia, ib) cell is a
    // dot product over two contiguous streams with register accumulators:
    // a_blk[(t*na + ia)*bsz + ub], b_blk[(t*nb + ib)*bsz + ub].
    let mut a_blk = vec![0u64; D * na * bsz];
    let mut b_blk = vec![0u64; D * nb * bsz];
    // Split-halves accumulators: [(t*na + ia)*nb + ib].
    let mut acc_lo = vec![0u128; D * na * nb];
    let mut acc_hi = vec![0u128; D * na * nb];
    // Per-ring forward transforms of one block (computed in parallel,
    // then scattered into the t-major blocks serially).
    let mut fa_rings: Vec<[u64; D]> = vec![[0u64; D]; (na + nb) * bsz];
    let mut u0 = 0usize;
    pooled(|| {
        use rayon::prelude::*;
        while u0 < len {
            // One capacity window: [u0, u1).
            let u1 = (u0 + window).min(len);
            acc_lo.iter_mut().for_each(|x| *x = 0);
            acc_hi.iter_mut().for_each(|x| *x = 0);
            let mut ub0 = u0;
            while ub0 < u1 {
                let nb_u = bsz.min(u1 - ub0);
                // Forward transforms: a rings (mod q -> balanced -> Z_p),
                // then b rings (small -> Z_p); slot (ia*bsz + ub) / ((na + ib)*bsz + ub).
                let n_a = na * bsz;
                let work = |slot: usize, out: &mut [u64; D]| {
                    let (is_b, sl) = if slot < n_a { (false, slot) } else { (true, slot - n_a) };
                    let (idx, ub) = (sl / bsz, sl % bsz);
                    if ub >= nb_u {
                        return; // beyond the block's tail; never read
                    }
                    if !is_b {
                        let ring = &a[idx][ub0 + ub];
                        if ring.iter().all(|&x| x == 0) {
                            *out = [0u64; D];
                            return;
                        }
                        for i in 0..D {
                            out[i] = lift_to_p(balanced_mod_q(ring[i], q));
                        }
                    } else {
                        let ring = &b[idx][ub0 + ub];
                        if ring.iter().all(|&x| x == 0) {
                            *out = [0u64; D];
                            return;
                        }
                        for i in 0..D {
                            out[i] = lift_to_p(ring[i]);
                        }
                    }
                    ntt_fwd(out, t);
                };
                if threads() > 1 {
                    fa_rings.par_iter_mut().enumerate().for_each(|(slot, o)| work(slot, o));
                } else {
                    fa_rings.iter_mut().enumerate().for_each(|(slot, o)| work(slot, o));
                }
                // Scatter into the t-major blocks (per-t chunks; O(rings x D)).
                let fa_ref = &fa_rings;
                let scat_a = |tt: usize, chunk: &mut [u64]| {
                    for ia in 0..na {
                        for ub in 0..nb_u {
                            chunk[ia * bsz + ub] = fa_ref[ia * bsz + ub][tt];
                        }
                    }
                };
                let scat_b = |tt: usize, chunk: &mut [u64]| {
                    for ib in 0..nb {
                        for ub in 0..nb_u {
                            chunk[ib * bsz + ub] = fa_ref[(na + ib) * bsz + ub][tt];
                        }
                    }
                };
                if threads() > 1 {
                    a_blk.par_chunks_mut(na * bsz).enumerate().for_each(|(tt, c)| scat_a(tt, c));
                    b_blk.par_chunks_mut(nb * bsz).enumerate().for_each(|(tt, c)| scat_b(tt, c));
                } else {
                    a_blk.chunks_mut(na * bsz).enumerate().for_each(|(tt, c)| scat_a(tt, c));
                    b_blk.chunks_mut(nb * bsz).enumerate().for_each(|(tt, c)| scat_b(tt, c));
                }
                // D independent GEMMs: acc[t][ia][ib] += sum_ub a[t][ia][ub] * b[t][ib][ub]
                // — each cell a dot product over two contiguous streams,
                // accumulated in registers (split halves), stored once.
                // Threads split the t range (per-t accumulator chunks).
                let a_blk = &a_blk;
                let b_blk = &b_blk;
                let cell = |tt: usize, acc_l: &mut [u128], acc_h: &mut [u128]| {
                    for ia in 0..na {
                        let arow = &a_blk[(tt * na + ia) * bsz..(tt * na + ia) * bsz + nb_u];
                        for ib in 0..nb {
                            let brow = &b_blk[(tt * nb + ib) * bsz..(tt * nb + ib) * bsz + nb_u];
                            let (lo, hi) = dot_split_halves(arow, brow);
                            acc_l[ia * nb + ib] += lo;
                            acc_h[ia * nb + ib] += hi;
                        }
                    }
                };
                if threads() > 1 {
                    acc_lo
                        .par_chunks_mut(na * nb)
                        .zip(acc_hi.par_chunks_mut(na * nb))
                        .enumerate()
                        .for_each(|(tt, (al, ah))| cell(tt, al, ah));
                } else {
                    for (tt, (al, ah)) in acc_lo.chunks_mut(na * nb).zip(acc_hi.chunks_mut(na * nb)).enumerate() {
                        cell(tt, al, ah);
                    }
                }
                ub0 += nb_u;
            }
            // Leave the NTT domain once per output for this window: exact
            // integer recovery (capacity contract), reduce mod q, add.
            let acc_lo = &acc_lo;
            let acc_hi = &acc_hi;
            let flush = |o_idx: usize, o: &mut Poly| {
                let (ia, ib) = (o_idx / nb, o_idx % nb);
                let mut v = [0u64; D];
                for tt in 0..D {
                    let idx = (tt * na + ia) * nb + ib;
                    v[tt] = reduce128(acc_lo[idx] + EPS as u128 * acc_hi[idx]);
                }
                ntt_inv(&mut v, t);
                for tt in 0..D {
                    let c = mod_q_centered(center_from_p(v[tt]), q);
                    o[tt] = zq.add(o[tt], c);
                }
            };
            if threads() > 1 {
                out.par_iter_mut().enumerate().for_each(|(i, o)| flush(i, o));
            } else {
                out.iter_mut().enumerate().for_each(|(i, o)| flush(i, o));
            }
            u0 = u1;
        }
    });
    out
}

/// [UPERF-PC O2] The h cross-garbage of one level, pair order (j <= k):
/// h_jj = <phi_j, w_j>, h_jk = <phi_j, w_k> + <phi_k, w_j>. `phi` = r
/// slices of `chunk` mod-q rings (the aggregated functional's chunk
/// slices, zero-padded by the caller), `w` = r slices of `chunk` small
/// rings. One `ntt_gemm_modq_small` call (r x r outputs), bit-identical to
/// `level_h_pairs_ref`.
pub fn level_h_pairs(ctx: &RingCtx, phi: &[&[Poly]], w: &[&[Vec<i64>]], chunk: usize) -> Vec<Poly> {
    let _t = prof::timer(prof::EP_LEVELH); // [UPERF-PC] observation only
    let r = phi.len();
    assert_eq!(w.len(), r, "phi/w slice counts");
    if oracle_mode() {
        return level_h_pairs_ref(ctx, phi, w, chunk);
    }
    let zq = &ctx.zq;
    let g = ntt_gemm_modq_small(ctx, phi, w, chunk); // g[j*r + k] = <phi_j, w_k>
    let mut h = Vec::with_capacity(r * (r + 1) / 2);
    for j in 0..r {
        for k in j..r {
            if j == k {
                h.push(g[j * r + j].clone());
            } else {
                h.push(poly_add(zq, &g[j * r + k], &g[k * r + j]));
            }
        }
    }
    h
}

/// The Karatsuba oracle for `level_h_pairs` (the pre-O2 loop; battery
/// use only).
pub fn level_h_pairs_ref(ctx: &RingCtx, phi: &[&[Poly]], w: &[&[Vec<i64>]], chunk: usize) -> Vec<Poly> {
    let r = phi.len();
    assert_eq!(w.len(), r);
    let zq = &ctx.zq;
    let mut h = Vec::with_capacity(r * (r + 1) / 2);
    for j in 0..r {
        assert_eq!(phi[j].len(), chunk);
        assert_eq!(w[j].len(), chunk);
        for k in j..r {
            let mut hp = ring_ip_modq_small_ref(ctx, phi[j], w[k]);
            if j != k {
                hp = poly_add(zq, &hp, &ring_ip_modq_small_ref(ctx, phi[k], w[j]));
            }
            h.push(hp);
        }
    }
    h
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
    let psi = compute_psi(ctx, phi, plan.chunk, c);
    transport_level_from_psi(ctx, &psi, h_target, plan, layout, a_mat, bindings, c, alphas)
}

/// [UAGB1-BH] `transport_level` with Psi precomputed — phi enters the
/// transport ONLY through Psi, so a caller holding the factored Psi_0
/// (`psi_level0_factored`) never materializes Phi_0. Values are
/// identical to `transport_level` by construction.
#[allow(clippy::too_many_arguments)]
pub fn transport_level_from_psi(
    ctx: &RingCtx,
    psi: &[Poly],       // compute_psi(phi, plan.chunk, c) — chunk rings
    h_target: &Poly,    // H_i
    plan: &LevelPlan,
    layout: &NextLayout,
    a_mat: &[Poly],     // kappa x chunk
    bindings: &[OuterBinding],
    c: &[Vec<i64>],     // r quinary fold challenges
    alphas: &[Poly],    // transport_rows(bindings.len()) aggregation challenges
) -> LevelTransport {
    let _t = prof::timer(prof::EP_TRANSPORT); // [UPERF-PC] observation only
    let zq = &ctx.zq;
    assert_eq!(psi.len(), plan.chunk);
    let n_rows = transport_rows(bindings.len());
    assert_eq!(alphas.len(), n_rows);
    let (a_t1, a_l1) = (&alphas[0], &alphas[1]);
    let a_t4 = &alphas[2..2 + KAPPA_AGG];
    let a_t5 = &alphas[2 + KAPPA_AGG..];
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
    let _t = prof::timer(prof::EP_PSI); // [UPERF-PC] observation only
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

/// [UPERF-PC] Absorb a GroupEvalProof's wire fields (declaration order)
/// into the differential digest — the composed-pass EVAL-PROOF DIGEST
/// printed by `uperf-pc pass-profile`. No-op unless the digest is on.
pub fn prof_digest_group_eval_proof(label: &str, proof: &GroupEvalProof) {
    if !prof::digest_on() {
        return;
    }
    let pb = |what: &str, polys: &[Poly]| {
        prof::digest_absorb(&format!("{label}.{what}"), &super::polys_bytes(polys))
    };
    pb("u0", &proof.u0);
    pb("ugh0", &proof.ugh0);
    pb("b_rows", &proof.b_rows);
    for (i, u) in proof.level_us.iter().enumerate() {
        pb(&format!("u{}", i + 1), u);
    }
    for ring in &proof.floor {
        prof::digest_i64s(&format!("{label}.floor"), ring);
    }
    prof::digest_absorb(&format!("{label}.floor_e"), &proof.floor_e.to_le_bytes());
    let mut att = Vec::with_capacity(proof.tcap_attempts.len() * 4);
    for a in &proof.tcap_attempts {
        att.extend(a.to_le_bytes());
    }
    prof::digest_absorb(&format!("{label}.tcap"), &att);
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
// [UAGB1-BH] The Greyhound row-column split of the claim kernel
// (PARAMS 2.2/5.3) — the wave-3 verifier fix of the recorded
// O(N_limb) wall.
//
// STRUCTURE. In the recursed path the verifier consumes the
// aggregated level-0 functional Phi_0 ONLY through
// Psi_0[u] = sum_k c_k * Phi_0[k*chunk + u] (compute_psi): the
// level-1 transport's L1 rows, and — for one-level schedules — the
// floor/Tier-Z L1 family. Phi_0 itself is
//   Phi_0[v] = sum_c alpha_c * conj(row_c of digit ring v),
// with the kw row of ring v = radix_limb * (row_ker[row] *_K
// col_ker[col]) per coefficient slot. Two exact facts collapse it:
//   (1) K-multiplication is F_q-bilinear over the coordinate basis
//       {Y^d}: (s *_K x)[c] = sum_d x[d] * (s *_K Y^d)[c];
//   (2) conj_poly is Z_q-linear over coefficients.
// Hence, whenever a tensor's cols is a multiple of D (each value
// ring lies inside ONE matrix row: f = row*cols + cb*D + c1),
//   Phi_0[v] = radix_limb * sum_d beta[row][d] * conjQ[cb][d],
//   beta[row][d] = sum_c (row_ker[row] *_K Y^d)[c] * alpha_c,
//   conjQ[cb][d] = conj_poly(c1 -> col_ker[cb*D + c1][d]),
// and Psi_0 assembles at O(rows * 16) scalar-scaled alpha sums +
// O(n_value_rings * 16) ring-mults + O(n_0) radix-scale-adds —
// never materializing Phi_0 (n_0 ring elements) or the N-value
// weight table. Every step is an exact mod-q regrouping of the
// reference sum, so Psi_0 is BIT-IDENTICAL to
// compute_psi(Phi_0, chunk, c) — asserted by the [UAGB1-BH]
// differential battery. Tensors with cols % D != 0 (battery-small
// shapes) take the per-ring generic branch below, same values.

/// Reference Phi_0 of one digit ring (the kw-row/bpolys formula of
/// `ClaimKernelCtx`, kernels borrowed) — the generic branch of the
/// factored Psi_0 and the differential oracle's per-ring form.
fn phi0_ring(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[TensorClaimKernel],
    alphas: &[Poly],
    u: usize,
) -> Poly {
    let zq = &ctx.zq;
    for (ti, t) in group.tensors.iter().enumerate() {
        let lo = t.digit_ring_base;
        let hi = lo + t.n_digit_rings();
        if u >= lo && u < hi {
            let rel = u - lo;
            let (vr, limb) = (rel / t.l0, rel % t.l0);
            let radix = zq.to_mod(1i64 << (t.e0 as usize * limb));
            let mut acc = poly_zero();
            let Some(ker) = kernels.iter().find(|k| k.tensor_idx == ti) else {
                return acc;
            };
            // kw row of ring u, coordinate-sliced and conj-packed
            // (bpolys), contracted with the alphas.
            let mut rows = vec![poly_zero(); K_DEG];
            for c1 in 0..D {
                let f = vr * D + c1;
                if f < t.n_values() {
                    let w = kf.scale(
                        radix,
                        &kf.mul(&ker.row_kernel[f / t.cols], &ker.col_kernel[f % t.cols]),
                    );
                    for (cd, row) in rows.iter_mut().enumerate() {
                        row[c1] = w[cd];
                    }
                }
            }
            for (a, r) in alphas.iter().zip(rows.iter()) {
                let bp = conj_poly(zq, r);
                acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, a, &bp));
            }
            return acc;
        }
    }
    panic!("digit ring {u} outside group");
}

/// [UAGB1-BH] Psi_0 by the row-column split: exactly
/// `compute_psi(Phi_0, chunk, c)` for the level-0 claim-kernel
/// functional Phi_0(kernels, alphas), computed WITHOUT materializing
/// Phi_0. `chunk`/`c` are the level-0 plan's split (chunk >= 1,
/// r = c.len(), r * chunk >= n_digit_rings).
pub fn psi_level0_factored(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[TensorClaimKernel],
    alphas: &[Poly],
    c: &[Vec<i64>],
    chunk: usize,
) -> Vec<Poly> {
    let _t = prof::timer(prof::EP_PSI0F); // [UPERF-PC] observation only
    assert_eq!(alphas.len(), K_DEG);
    let zq = &ctx.zq;
    let r = c.len();
    let c_polys: Vec<Poly> = c.iter().map(|ck| poly_from_small(zq, ck)).collect();
    let mut psi = vec![poly_zero(); chunk];
    // Scatter one digit ring's Phi_0 value into Psi (lazy per-(k,
    // ring-source) fold products are the caller's job; here v is the
    // global digit-ring index).
    for (ti, t) in group.tensors.iter().enumerate() {
        let ker = kernels.iter().find(|k| k.tensor_idx == ti);
        let aligned = t.cols % D == 0 && ker.is_some();
        if !aligned {
            // Generic branch (misaligned cols or absent kernel):
            // per-ring reference values, folded directly.
            for rel in 0..t.n_digit_rings() {
                let v = t.digit_ring_base + rel;
                let (k, u) = (v / chunk, v % chunk);
                debug_assert!(k < r);
                let ph = phi0_ring(ctx, kf, group, kernels, alphas, v);
                if ph.iter().all(|&x| x == 0) {
                    continue;
                }
                let m = ring_mul_split_kara_fast(ctx, &ph, &c_polys[k]);
                psi[u] = poly_add(zq, &psi[u], &m);
            }
            continue;
        }
        let ker = ker.unwrap();
        let nb = t.cols / D;
        // conjQ[cb][d]: conj-packed d-coordinate slice of the
        // col-kernel block cb.
        let conjq: Vec<Vec<Poly>> = (0..nb)
            .map(|cb| {
                (0..K_DEG)
                    .map(|d| {
                        let mut base = poly_zero();
                        for c1 in 0..D {
                            base[c1] = ker.col_kernel[cb * D + c1][d];
                        }
                        conj_poly(zq, &base)
                    })
                    .collect()
            })
            .collect();
        // Coordinate basis powers Y^d.
        let ybasis: Vec<KElem> = (0..K_DEG)
            .map(|d| {
                let mut e = kf.zero();
                e[d] = 1;
                e
            })
            .collect();
        let radixes: Vec<u64> =
            (0..t.l0).map(|l| zq.to_mod(1i64 << (t.e0 as usize * l))).collect();
        for row in 0..t.rows {
            let rk = &ker.row_kernel[row];
            // beta[d] = sum_c (rk *_K Y^d)[c] * alpha_c — scalar-
            // scaled alpha sums, no ring-mults.
            let beta: Vec<Poly> = (0..K_DEG)
                .map(|d| {
                    let l_col = kf.mul(rk, &ybasis[d]);
                    let mut acc = poly_zero();
                    for (cd, a) in alphas.iter().enumerate() {
                        if l_col[cd] != 0 {
                            acc = poly_add(zq, &acc, &super::poly_scale(zq, l_col[cd], a));
                        }
                    }
                    acc
                })
                .collect();
            for cb in 0..nb {
                let vr = row * nb + cb;
                // RQ = sum_d beta[d] * conjQ[cb][d] = Phi_0 of this
                // value ring's limb-0 (radix folded in below).
                let mut rq = poly_zero();
                for d in 0..K_DEG {
                    if beta[d].iter().all(|&x| x == 0) {
                        continue;
                    }
                    rq = poly_add(
                        zq,
                        &rq,
                        &ring_mul_split_kara_fast(ctx, &beta[d], &conjq[cb][d]),
                    );
                }
                // The l0 digit rings of this value ring: fold by the
                // chunk split with a lazily-cached c_k * RQ product
                // (k changes at most once inside a value ring).
                let mut cached: Option<(usize, Poly)> = None;
                for limb in 0..t.l0 {
                    let v = t.digit_ring_base + vr * t.l0 + limb;
                    let (k, u) = (v / chunk, v % chunk);
                    debug_assert!(k < r);
                    let s = match &cached {
                        Some((ck, s)) if *ck == k => s.clone(),
                        _ => {
                            let s = ring_mul_split_kara_fast(ctx, &rq, &c_polys[k]);
                            cached = Some((k, s.clone()));
                            s
                        }
                    };
                    psi[u] = poly_add(zq, &psi[u], &super::poly_scale(zq, radixes[limb], &s));
                }
            }
        }
    }
    psi
}

/// [UAGB1-BH] Reference Phi_0 materialization over the whole group
/// (the wave-2 verifier's object) — the differential oracle for
/// `psi_level0_factored`; battery use.
pub fn phi0_reference(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[TensorClaimKernel],
    alphas: &[Poly],
) -> Vec<Poly> {
    (0..group.n_digit_rings).map(|u| phi0_ring(ctx, kf, group, kernels, alphas, u)).collect()
}

// ---------------------------------------------------------------------------
// [UAGB1-BJ wave 4, R-BG1] The ADDITIVE multi-claim kernel API — lane
// BG's wave-3 export against this file (UAGB1_PASS_AGG_REPORT 7.4):
// `ClaimKernelCtx` supports ONE product-form kernel per tensor
// (`kernels.find`); the composed pass batches MANY claims onto the
// same per-layer tensor, and their weight tables ADD (the CR-L4a/b
// mu/nu batching lands additively in the same rows —
// ring/pass_agg.rs::GroupClaims is the built-around form). This block
// is the additive ENTRY POINT: `MultiClaimKernel` carries one scaled
// product-form contribution (weight of value f = scale *_K
// row[f / cols] *_K col[f % cols]; any number of contributions per
// tensor), and `psi_level0_factored_multi` is the row-column split of
// the SUMMED weight — per kernel the scale folds into the row factor
// (K is a field: scale * (row * col) = (scale * row) * col exactly),
// so each contribution keeps the rank-1 shape the split needs, and
// kernel contributions add ring-linearly into Psi_0. No O(N_values)
// weight table and no Phi_0 materialization exist on this path (the
// vw-free form — BG export item 2 subsumed). `ClaimKernelCtx`,
// `psi_level0_factored`, `transport_level`, `transport_level_from_psi`
// and every BD/BH call site are UNTOUCHED — bit-identical behavior.

/// One additive claim contribution to tensor `tensor_idx` (the
/// pass_agg::ClaimContrib shape, here as the eval-proof-owned API).
pub struct MultiClaimKernel {
    pub tensor_idx: usize,
    pub scale: KElem,
    pub row_kernel: std::rc::Rc<Vec<KElem>>,
    pub col_kernel: std::rc::Rc<Vec<KElem>>,
}

/// Reference Phi_0 of one digit ring under the ADDITIVE multi-claim
/// weight (sum over every kernel of tensor u's contribution) — the
/// generic branch of `psi_level0_factored_multi` and the per-ring
/// differential oracle.
fn phi0_ring_multi(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[MultiClaimKernel],
    alphas: &[Poly],
    u: usize,
) -> Poly {
    let zq = &ctx.zq;
    for (ti, t) in group.tensors.iter().enumerate() {
        let lo = t.digit_ring_base;
        let hi = lo + t.n_digit_rings();
        if u >= lo && u < hi {
            let rel = u - lo;
            let (vr, limb) = (rel / t.l0, rel % t.l0);
            let radix = zq.to_mod(1i64 << (t.e0 as usize * limb));
            let mut acc = poly_zero();
            for ker in kernels.iter().filter(|k| k.tensor_idx == ti) {
                let mut rows = vec![poly_zero(); K_DEG];
                for c1 in 0..D {
                    let f = vr * D + c1;
                    if f < t.n_values() {
                        let w = kf.scale(
                            radix,
                            &kf.mul(
                                &ker.scale,
                                &kf.mul(
                                    &ker.row_kernel[f / t.cols],
                                    &ker.col_kernel[f % t.cols],
                                ),
                            ),
                        );
                        for (cd, row) in rows.iter_mut().enumerate() {
                            row[c1] = w[cd];
                        }
                    }
                }
                for (a, r) in alphas.iter().zip(rows.iter()) {
                    let bp = conj_poly(zq, r);
                    acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, a, &bp));
                }
            }
            return acc;
        }
    }
    panic!("digit ring {u} outside group");
}

/// [UAGB1-BJ] Psi_0 by the row-column split under the ADDITIVE
/// multi-claim weight: exactly `compute_psi(Phi_0, chunk, c)` for
/// Phi_0 = sum-over-kernels of the per-kernel level-0 functional,
/// computed WITHOUT materializing Phi_0 or any weight table. The
/// multi-claim generalization of `psi_level0_factored` (which is the
/// one-kernel-per-tensor special case at scale = 1); that function
/// and its callers are not modified.
pub fn psi_level0_factored_multi(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[MultiClaimKernel],
    alphas: &[Poly],
    c: &[Vec<i64>],
    chunk: usize,
) -> Vec<Poly> {
    psi_level0_multi_impl(ctx, kf, group, kernels, alphas, c, chunk, oracle_mode())
}

/// The pre-O5 form of `psi_level0_factored_multi` (BJ's beta x conjQ
/// aligned branch), callable directly for the battery / A/B.
pub fn psi_level0_factored_multi_pre_o5(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[MultiClaimKernel],
    alphas: &[Poly],
    c: &[Vec<i64>],
    chunk: usize,
) -> Vec<Poly> {
    psi_level0_multi_impl(ctx, kf, group, kernels, alphas, c, chunk, true)
}

#[allow(clippy::too_many_arguments)]
fn psi_level0_multi_impl(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[MultiClaimKernel],
    alphas: &[Poly],
    c: &[Vec<i64>],
    chunk: usize,
    pre_o5: bool,
) -> Vec<Poly> {
    let _t = prof::timer(prof::EP_PSI0F); // [UPERF-PC] observation only
    assert_eq!(alphas.len(), K_DEG);
    let zq = &ctx.zq;
    let r = c.len();
    let c_polys: Vec<Poly> = c.iter().map(|ck| poly_from_small(zq, ck)).collect();
    let mut psi = vec![poly_zero(); chunk];
    let mut cache = ColBlockCache::new(); // [UPERF-PC O5] per-(col kernel, cb) G blocks
    for (ti, t) in group.tensors.iter().enumerate() {
        let kers: Vec<&MultiClaimKernel> =
            kernels.iter().filter(|k| k.tensor_idx == ti).collect();
        if kers.is_empty() {
            continue; // zero contribution (matches the additive weight)
        }
        let aligned = t.cols % D == 0;
        if aligned && pre_o5 {
            // ZK_UPERF_ORACLE=1 (or the explicit pre-O5 entry): BJ's
            // beta x conjQ per value ring — the honest verifier "before".
            psi_level0_aligned_pre_o5(ctx, kf, t, &kers, alphas, &c_polys, chunk, &mut psi);
            continue;
        }
        if !aligned {
            // Generic branch (misaligned cols): per-ring reference
            // values of the SUMMED weight, folded directly.
            for rel in 0..t.n_digit_rings() {
                let v = t.digit_ring_base + rel;
                let (k, u) = (v / chunk, v % chunk);
                debug_assert!(k < r);
                let ph = phi0_ring_multi(ctx, kf, group, kernels, alphas, v);
                if ph.iter().all(|&x| x == 0) {
                    continue;
                }
                let m = ring_mul_split_kara_fast(ctx, &ph, &c_polys[k]);
                psi[u] = poly_add(zq, &psi[u], &m);
            }
            continue;
        }
        let nb = t.cols / D;
        let radixes: Vec<u64> =
            (0..t.l0).map(|l| zq.to_mod(1i64 << (t.e0 as usize * l))).collect();
        // [UPERF-PC O5] the factored form (PhiFactored: PHI_vr from the
        // hoisted row factors against the cached alpha-contracted col
        // blocks — no per-row K-mults, no per-value-ring ring-mults);
        // exactly the pre-O5 beta x conjQ value (bit-identical, asserted
        // by the diff-battery leg O5 against compute_psi(phi0_reference_multi)).
        let pf = PhiFactored::new(ctx, kf, &kers, nb, alphas, &mut cache);
        let n_vr = t.rows * nb;
        // Per value ring: RQ, then its l0 digit rings' contributions
        // (u, radix_limb * (c_k * RQ)) with the c_k product cached per
        // k-run — computed in parallel per value-ring block, folded
        // into psi serially in (vr, limb) order.
        let contrib_of = |vr: usize| -> Vec<(usize, Poly)> {
            let rq = pf.value_ring(vr);
            let mut out = Vec::with_capacity(t.l0);
            let mut cached: Option<(usize, Poly)> = None;
            for limb in 0..t.l0 {
                let v = t.digit_ring_base + vr * t.l0 + limb;
                let (k, u) = (v / chunk, v % chunk);
                debug_assert!(k < r);
                let s = match &cached {
                    Some((ck, s)) if *ck == k => s.clone(),
                    _ => {
                        let s = ring_mul_split_kara_fast(ctx, &rq, &c_polys[k]);
                        cached = Some((k, s.clone()));
                        s
                    }
                };
                out.push((u, super::poly_scale(zq, radixes[limb], &s)));
            }
            out
        };
        const VR_BLOCK: usize = 4096;
        let mut vr0 = 0;
        while vr0 < n_vr {
            let vr1 = (vr0 + VR_BLOCK).min(n_vr);
            let blocks: Vec<Vec<(usize, Poly)>> = pooled(|| {
                use rayon::prelude::*;
                if threads() > 1 {
                    (vr0..vr1).into_par_iter().map(contrib_of).collect()
                } else {
                    (vr0..vr1).map(contrib_of).collect()
                }
            });
            for b in &blocks {
                for (u, p) in b {
                    psi[*u] = poly_add(zq, &psi[*u], p);
                }
            }
            vr0 = vr1;
        }
    }
    psi
}

/// The pre-O5 aligned branch of `psi_level0_factored_multi` (BJ's form:
/// per row beta[d] = sum_cd (scale *_K row *_K Y^d)[cd] alpha_cd, per
/// value ring RQ = sum over kernels of sum_d beta[d] * conjQ[cb][d]),
/// kept verbatim as the `ZK_UPERF_ORACLE=1` path — the honest verifier
/// "before" for the one-binary A/B. Adds into `psi`.
#[allow(clippy::too_many_arguments)]
fn psi_level0_aligned_pre_o5(
    ctx: &RingCtx,
    kf: &KField,
    t: &AggTensor,
    kers: &[&MultiClaimKernel],
    alphas: &[Poly],
    c_polys: &[Poly],
    chunk: usize,
    psi: &mut [Poly],
) {
    let zq = &ctx.zq;
    let r = c_polys.len();
    let ybasis: Vec<KElem> = (0..K_DEG)
        .map(|d| {
            let mut e = kf.zero();
            e[d] = 1;
            e
        })
        .collect();
    let nb = t.cols / D;
    let conjq: Vec<Vec<Vec<Poly>>> = kers
        .iter()
        .map(|ker| {
            (0..nb)
                .map(|cb| {
                    (0..K_DEG)
                        .map(|d| {
                            let mut base = poly_zero();
                            for c1 in 0..D {
                                base[c1] = ker.col_kernel[cb * D + c1][d];
                            }
                            conj_poly(zq, &base)
                        })
                        .collect()
                })
                .collect()
        })
        .collect();
    let radixes: Vec<u64> = (0..t.l0).map(|l| zq.to_mod(1i64 << (t.e0 as usize * l))).collect();
    for row in 0..t.rows {
        let betas: Vec<Vec<Poly>> = kers
            .iter()
            .map(|ker| {
                let rk_eff = kf.mul(&ker.scale, &ker.row_kernel[row]);
                (0..K_DEG)
                    .map(|d| {
                        let l_col = kf.mul(&rk_eff, &ybasis[d]);
                        let mut acc = poly_zero();
                        for (cd, a) in alphas.iter().enumerate() {
                            if l_col[cd] != 0 {
                                acc = poly_add(zq, &acc, &super::poly_scale(zq, l_col[cd], a));
                            }
                        }
                        acc
                    })
                    .collect()
            })
            .collect();
        for cb in 0..nb {
            let vr = row * nb + cb;
            let mut rq = poly_zero();
            for (ki, beta) in betas.iter().enumerate() {
                for d in 0..K_DEG {
                    if beta[d].iter().all(|&x| x == 0) {
                        continue;
                    }
                    rq = poly_add(zq, &rq, &ring_mul_split_kara_fast(ctx, &beta[d], &conjq[ki][cb][d]));
                }
            }
            let mut cached: Option<(usize, Poly)> = None;
            for limb in 0..t.l0 {
                let v = t.digit_ring_base + vr * t.l0 + limb;
                let (k, u) = (v / chunk, v % chunk);
                debug_assert!(k < r);
                let s = match &cached {
                    Some((ck, s)) if *ck == k => s.clone(),
                    _ => {
                        let s = ring_mul_split_kara_fast(ctx, &rq, &c_polys[k]);
                        cached = Some((k, s.clone()));
                        s
                    }
                };
                psi[u] = poly_add(zq, &psi[u], &super::poly_scale(zq, radixes[limb], &s));
            }
        }
    }
}

/// [UAGB1-BJ] Reference Phi_0 materialization under the additive
/// multi-claim weight — the differential oracle for
/// `psi_level0_factored_multi` (`pass-agg seam` differential;
/// battery use).
pub fn phi0_reference_multi(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[MultiClaimKernel],
    alphas: &[Poly],
) -> Vec<Poly> {
    (0..group.n_digit_rings)
        .map(|u| phi0_ring_multi(ctx, kf, group, kernels, alphas, u))
        .collect()
}

// ---------------------------------------------------------------------------
// [UPERF-PC O5] The prover's two claim-kernel passes, FACTORED
// (TASK_BOARD T5). The oracle is the bin's `bg_kernel_pass`: per digit
// ring u = (value ring vr, limb) it builds the K-weight row
// kw_u[c1] = sum_c scale_c *_K row_c[f/cols] *_K col_c[f%cols]
// (f = vr*D + c1; ~128 x n_contrib x 2 K-mults per value ring), then
// bp_u[cd] = radix_u * conj(sum_{c1} kw_u[c1][cd] X^{c1}) and
//   rows pass:  b_rows[cd] += bp_u[cd] * w_u            (16 ring-mults / ring)
//   phi  pass:  phi_u       = sum_cd alpha_cd * bp_u[cd] (16 ring-mults / ring).
//
// Everything below re-associates the SAME mod-q / K-field sums (K is a
// field, conj is a Z_q-linear ring automorphism, radix is a scalar), so
// the outputs are bit-identical by construction — asserted by the
// diff-battery leg "O5 kernel-pass" against the oracle. For a tensor
// with cols % D == 0 (every 125M tensor) a value ring vr = (row, cb)
// never straddles rows, and with K-bilinearity
//     kf.mul(a, b)[cd] = sum_{d1} a[d1] * (Y^{d1} *_K b)[cd]
// and the hoist sr_c[row] = scale_c *_K row_c[row]:
//
//   PHI_vr := sum_cd alpha_cd * conj(sum_{c1} kw(vr,c1)[cd] X^{c1})
//           = sum_c sum_{d1} sr_c[row][d1] * G_c[cb][d1],
//   G_c[cb][d1] = sum_{c1} conj(X^{c1}) * sum_cd (Y^{d1} *_K col_c[cb*D+c1])[cd] * alpha_cd,
//   phi_u = radix_limb * PHI_vr;
//
//   b_rows[cd] = sum_c sum_cb sum_{d1} CQ_c[cb][d1][cd] * T_c[d1][cb],
//   CQ_c[cb][d1][cd] = conj(sum_{c1} (Y^{d1} *_K col_c[cb*D+c1])[cd] X^{c1}),
//   T_c[d1][cb]      = sum_row sr_c[row][d1] * V_(row,cb),
//   V_vr             = sum_limb radix_limb * w_(vr,limb)   (the value ring, mod q).
//
// G / CQ depend only on (col kernel, cb, d1[, cd]) and are cached by
// the col kernel's Rc identity — the folded IXF claims share col
// kernels across the 12 layers' tensors — so the per-value-ring work is
// 16 x n_contrib scalar-x-ring MACs (u128 lazy, one reduction), no
// K-mults, no ring-mults. Misaligned tensors (cols % D != 0) and the
// no-kernel case ride the per-ring reference below.

/// One kernel's hoisted row factors: sr[row] = scale *_K row_kernel[row].
fn kernel_row_factors(kf: &KField, ker: &MultiClaimKernel) -> Vec<KElem> {
    ker.row_kernel.iter().map(|rk| kf.mul(&ker.scale, rk)).collect()
}

/// CQ0[e] = conj(sum_{c1} col[cb*D + c1][e] X^{c1}) — the conj-packed
/// coordinate slices of one column block (16 rings; the verifier's
/// `conjq`). Because Y^{d1} *_K col only SHIFTS coordinates in
/// K = Z_q[Y]/(Y^16 - s) — (Y^{d1} col)[cd] = col[cd - d1] for cd >= d1,
/// s * col[cd - d1 + 16] otherwise — every (Y^{d1} col)-derived slice
/// is a scaled copy of a CQ0 entry: CQ[d1][cd] = sigma(cd, d1) *
/// CQ0[(cd - d1) mod 16] with sigma = s if cd < d1 else 1.
fn cq0_block(zq: &Zq, col: &[KElem], cb: usize) -> Vec<Poly> {
    (0..K_DEG)
        .map(|e| {
            let mut base = poly_zero();
            for c1 in 0..D {
                base[c1] = col[cb * D + c1][e];
            }
            conj_poly(zq, &base)
        })
        .collect()
}

/// G[d1] = sum_e CQ0[e] * A_{d1}[e] with A_{d1}[e] = sigma(e, d1) *
/// alpha_{(e + d1) mod 16}, sigma = s if e + d1 >= 16 else 1 — i.e.
/// sum_{c1} conj(X^{c1}) * sum_cd (Y^{d1} *_K col[c1])[cd] * alpha_cd,
/// the alpha-contracted conj-packed col block (16 rings; 256 ring
/// products per block, cached per col kernel).
fn g_block(ctx: &RingCtx, s: u64, cq0: &[Poly], alphas: &[Poly]) -> Vec<Poly> {
    let zq = &ctx.zq;
    // P[e][f] = CQ0[e] * alpha_f (mod q rings; 256 products, parallel over e).
    let row_of = |c: &Poly| -> Vec<Poly> {
        alphas
            .iter()
            .map(|a| {
                if c.iter().all(|&x| x == 0) || a.iter().all(|&x| x == 0) {
                    poly_zero()
                } else {
                    ring_mul_split_kara_fast(ctx, c, a)
                }
            })
            .collect()
    };
    let prods: Vec<Vec<Poly>> = pooled(|| {
        use rayon::prelude::*;
        if threads() > 1 { cq0.par_iter().map(row_of).collect() } else { cq0.iter().map(row_of).collect() }
    });
    (0..K_DEG)
        .map(|d1| {
            let mut g = poly_zero();
            for e in 0..K_DEG {
                let f = (e + d1) % K_DEG;
                let term = if e + d1 >= K_DEG { super::poly_scale(zq, s, &prods[e][f]) } else { prods[e][f].clone() };
                g = poly_add(zq, &g, &term);
            }
            g
        })
        .collect()
}

/// Per-(col kernel, cb) cache of the derived blocks, keyed by the col
/// kernel's Rc identity (the IXF-folded claims share col kernels across
/// the 12 layers' tensors).
struct ColBlockCache {
    cq0: HashMap<(usize, usize), Arc<Vec<Poly>>>,
    g: HashMap<(usize, usize), Arc<Vec<Poly>>>,
}

impl ColBlockCache {
    fn new() -> Self {
        ColBlockCache { cq0: HashMap::new(), g: HashMap::new() }
    }
    fn key(ker: &MultiClaimKernel, cb: usize) -> (usize, usize) {
        (std::rc::Rc::as_ptr(&ker.col_kernel) as *const u8 as usize, cb)
    }
    fn cq0(&mut self, zq: &Zq, ker: &MultiClaimKernel, cb: usize) -> Arc<Vec<Poly>> {
        let k = Self::key(ker, cb);
        if let Some(v) = self.cq0.get(&k) {
            return v.clone();
        }
        let v = Arc::new(cq0_block(zq, &ker.col_kernel, cb));
        self.cq0.insert(k, v.clone());
        v
    }
    fn g(&mut self, ctx: &RingCtx, s: u64, ker: &MultiClaimKernel, cb: usize, alphas: &[Poly]) -> Arc<Vec<Poly>> {
        let k = Self::key(ker, cb);
        if let Some(v) = self.g.get(&k) {
            return v.clone();
        }
        let cq0 = self.cq0(&ctx.zq, ker, cb);
        let v = Arc::new(g_block(ctx, s, &cq0, alphas));
        self.g.insert(k, v.clone());
        v
    }
}

/// The factored level-0 functional of ONE aligned tensor, radix-free:
/// PHI_vr = sum_c sum_{d1} sr_c[row][d1] * G_c[cb][d1] for value ring
/// vr = (row, cb). Shared by the prover's phi pass and the verifier's
/// `psi_level0_factored_multi`.
struct PhiFactored {
    q: u64,
    nb: usize,
    srs: Vec<Vec<KElem>>,                    // [kernel][row] hoisted row factors
    gs: Vec<Vec<Arc<Vec<Poly>>>>,     // [kernel][cb] -> 16 G rings
}

impl PhiFactored {
    fn new(
        ctx: &RingCtx,
        kf: &KField,
        kers: &[&MultiClaimKernel],
        nb: usize,
        alphas: &[Poly],
        cache: &mut ColBlockCache,
    ) -> Self {
        let srs = kers.iter().map(|k| kernel_row_factors(kf, k)).collect();
        let gs = kers
            .iter()
            .map(|k| (0..nb).map(|cb| cache.g(ctx, kf.s, k, cb, alphas)).collect())
            .collect();
        PhiFactored { q: ctx.zq.q, nb, srs, gs }
    }

    /// PHI of value ring vr (mod q; 16 x n_kernels scalar-x-ring MACs).
    fn value_ring(&self, vr: usize) -> Poly {
        let (row, cb) = (vr / self.nb, vr % self.nb);
        let mut acc = [0u128; D];
        for (ki, sr) in self.srs.iter().enumerate() {
            let g = &self.gs[ki][cb];
            let s_row = &sr[row];
            for d1 in 0..K_DEG {
                let s = s_row[d1];
                if s == 0 {
                    continue;
                }
                let s = s as u128;
                let gp = &g[d1];
                for j in 0..D {
                    acc[j] += s * gp[j] as u128; // < 2^62 per term, <= 2^12 terms
                }
            }
        }
        let q = self.q as u128;
        acc.iter().map(|&x| (x % q) as u64).collect()
    }
}

/// The per-ring reference K-weight row of value ring vr under the
/// additive multi-claim weight (radix-free): kw[c1] = sum over kernels
/// of scale *_K row[f/cols] *_K col[f%cols], f = vr*D + c1 (zero past
/// the tensor tail) — the bin's `GroupClaims::kw_value_row` over
/// MultiClaimKernel; the misaligned-tensor path.
fn kw_row_multi(kf: &KField, t: &AggTensor, kers: &[&MultiClaimKernel], vr: usize) -> Vec<KElem> {
    let mut out = vec![kf.zero(); D];
    let n = t.n_values();
    for ker in kers {
        for (c1, o) in out.iter_mut().enumerate() {
            let f = vr * D + c1;
            if f < n {
                let w = kf.mul(&ker.row_kernel[f / t.cols], &ker.col_kernel[f % t.cols]);
                *o = kf.add(o, &kf.mul(&ker.scale, &w));
            }
        }
    }
    out
}

/// conj-packed claim-row polys of one digit ring from its value-row
/// K-weights (radix-scaled) — `pass_agg::bpolys_from_kw` verbatim.
fn bpolys_from_kw_local(zq: &Zq, kw: &[KElem], radix: u64) -> Vec<Poly> {
    let mut rows = vec![poly_zero(); K_DEG];
    for (c1, w) in kw.iter().enumerate() {
        for (cd, row) in rows.iter_mut().enumerate() {
            row[c1] = zq.mul(radix, w[cd]);
        }
    }
    rows.iter().map(|r| conj_poly(zq, r)).collect()
}

/// [UPERF-PC O5] The factored claim-kernel pass — the drop-in for the
/// bin's `bg_kernel_pass` (same contract): `w0 = Some(witness)` runs the
/// ROWS pass (returns b_rows, 16 rings), `alphas = Some(alphas0)` runs
/// the PHI pass (returns the aggregated per-digit-ring functional,
/// group.n_digit_rings rings). Bit-identical to the oracle.
pub fn kernel_pass_factored(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[MultiClaimKernel],
    w0: Option<&[Vec<i64>]>,
    alphas: Option<&[Poly]>,
) -> (Vec<Poly>, Vec<Poly>) {
    let _t = prof::timer(if alphas.is_some() { prof::BG_KPHI } else { prof::BG_KROWS });
    let zq = &ctx.zq;
    let q = zq.q;
    let phi_mode = alphas.is_some();
    if let Some(a) = alphas {
        assert_eq!(a.len(), K_DEG);
    }
    let mut b_rows = vec![poly_zero(); K_DEG];
    let mut phi: Vec<Poly> = if phi_mode { Vec::with_capacity(group.n_digit_rings) } else { Vec::new() };
    let mut cache = ColBlockCache::new();
    for (ti, t) in group.tensors.iter().enumerate() {
        let kers: Vec<&MultiClaimKernel> = kernels.iter().filter(|k| k.tensor_idx == ti).collect();
        let n_vr = t.n_value_rings();
        if kers.is_empty() {
            // Zero weight: phi rings zero, no row contribution.
            if phi_mode {
                phi.extend(std::iter::repeat_n(poly_zero(), t.n_digit_rings()));
            }
            continue;
        }
        let radixes: Vec<u64> = (0..t.l0).map(|l| zq.to_mod(1i64 << (t.e0 as usize * l))).collect();
        if t.cols % D != 0 || oracle_mode() {
            // Misaligned (rare; synthetic shapes) — or ZK_UPERF_ORACLE=1:
            // the per-ring reference (kw row + bpolys + Karatsuba, the
            // pre-O5 `bg_kernel_pass` arithmetic).
            for vr in 0..n_vr {
                let kw = kw_row_multi(kf, t, &kers, vr);
                let kw_zero = kw.iter().all(|k| kf.is_zero(k));
                for limb in 0..t.l0 {
                    let u = t.digit_ring_base + vr * t.l0 + limb;
                    if phi_mode {
                        if kw_zero {
                            phi.push(poly_zero());
                        } else {
                            let bp = bpolys_from_kw_local(zq, &kw, radixes[limb]);
                            let mut acc = poly_zero();
                            for (a, b) in alphas.unwrap().iter().zip(bp.iter()) {
                                acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, a, b));
                            }
                            phi.push(acc);
                        }
                    } else {
                        let w = &w0.expect("witness for the rows pass")[u];
                        if kw_zero || w.iter().all(|&x| x == 0) {
                            continue;
                        }
                        let bp = bpolys_from_kw_local(zq, &kw, radixes[limb]);
                        let wsm = poly_from_small(zq, w);
                        for (c, row) in b_rows.iter_mut().enumerate() {
                            *row = poly_add(zq, row, &ring_mul_split_kara_fast(ctx, &bp[c], &wsm));
                        }
                    }
                }
            }
            continue;
        }
        // ---- Aligned fast path. ----
        let nb = t.cols / D;
        debug_assert_eq!(n_vr, t.rows * nb);
        let srs: Vec<Vec<KElem>> = kers.iter().map(|k| kernel_row_factors(kf, k)).collect();
        if phi_mode {
            let alphas = alphas.unwrap();
            let pf = PhiFactored::new(ctx, kf, &kers, nb, alphas, &mut cache);
            // Value rings in blocks (parallel map inside a block, serial
            // radix scaling/push in vr order — bit-identical for any
            // thread count).
            const VR_BLOCK: usize = 4096;
            let mut vr0 = 0;
            while vr0 < n_vr {
                let vr1 = (vr0 + VR_BLOCK).min(n_vr);
                let scaled = |vr: usize| -> Vec<Poly> {
                    let phi_vr = pf.value_ring(vr);
                    radixes.iter().map(|&radix| super::poly_scale(zq, radix, &phi_vr)).collect()
                };
                let phis: Vec<Vec<Poly>> = pooled(|| {
                    use rayon::prelude::*;
                    if threads() > 1 {
                        (vr0..vr1).into_par_iter().map(scaled).collect()
                    } else {
                        (vr0..vr1).map(scaled).collect()
                    }
                });
                for limbs in phis {
                    phi.extend(limbs);
                }
                vr0 = vr1;
            }
        } else {
            let w0 = w0.expect("witness for the rows pass");
            // T[ki][d1][cb] accumulators (u128 lazy over rows) — per
            // thread-range partials summed in range order (exact
            // integers: any split gives the same sums).
            let n_k = kers.len();
            let flat = n_k * K_DEG * nb * D;
            let tidx = |ki: usize, d1: usize, cb: usize| ((ki * K_DEG + d1) * nb + cb) * D;
            let range_work = |lo: usize, hi: usize| -> Vec<u128> {
                let mut tacc = vec![0u128; flat];
                let mut v_ring = vec![0i128; D];
                for vr in lo..hi {
                    let (row, cb) = (vr / nb, vr % nb);
                    // V_vr = sum_limb radix_limb * w — exact, then mod q.
                    v_ring.iter_mut().for_each(|x| *x = 0);
                    let mut any = false;
                    for (limb, &radix) in radixes.iter().enumerate() {
                        let w = &w0[t.digit_ring_base + vr * t.l0 + limb];
                        for j in 0..D {
                            if w[j] != 0 {
                                any = true;
                                v_ring[j] += radix as i128 * w[j] as i128;
                            }
                        }
                    }
                    if !any {
                        continue;
                    }
                    let v_modq: Vec<u64> = v_ring.iter().map(|&x| super::aux::mod_q_i128(x, q)).collect();
                    for (ki, sr) in srs.iter().enumerate() {
                        let s_row = &sr[row];
                        for d1 in 0..K_DEG {
                            let s = s_row[d1];
                            if s == 0 {
                                continue;
                            }
                            let s = s as u128;
                            let base = tidx(ki, d1, cb);
                            let ta = &mut tacc[base..base + D];
                            for j in 0..D {
                                ta[j] += s * v_modq[j] as u128; // < 2^62 per term, <= 2^11 rows
                            }
                        }
                    }
                }
                tacc
            };
            let tacc: Vec<u128> = if threads() > 1 && n_vr >= 2 * threads() {
                let nt = threads();
                let per = n_vr.div_ceil(nt);
                let partials: Vec<Vec<u128>> = pooled(|| {
                    use rayon::prelude::*;
                    (0..nt)
                        .into_par_iter()
                        .map(|i| range_work((i * per).min(n_vr), ((i + 1) * per).min(n_vr)))
                        .collect()
                });
                let mut tot = vec![0u128; flat];
                for p in &partials {
                    for (a, b) in tot.iter_mut().zip(p.iter()) {
                        *a += b;
                    }
                }
                tot
            } else {
                range_work(0, n_vr)
            };
            // b_rows[cd] += sum_ki sum_cb sum_d1 CQ[ki][cb][d1][cd] * T[ki][d1][cb],
            // CQ[d1][cd] = sigma(cd, d1) * CQ0[(cd - d1) mod 16] (sigma = s
            // if cd < d1): 16 x 16 ring products per (kernel, cb) block —
            // computed per block (in parallel), summed into b_rows in
            // block order.
            let s = kf.s;
            let cq0s: Vec<Vec<Arc<Vec<Poly>>>> =
                kers.iter().map(|k| (0..nb).map(|cb| cache.cq0(zq, k, cb)).collect()).collect();
            let tacc = &tacc;
            let block_rows = |bi: usize| -> Vec<Poly> {
                let (ki, cb) = (bi / nb, bi % nb);
                let cq0 = &cq0s[ki][cb];
                let mut rows = vec![poly_zero(); K_DEG];
                for d1 in 0..K_DEG {
                    let base = tidx(ki, d1, cb);
                    let t_ring: Poly = tacc[base..base + D].iter().map(|&x| (x % q as u128) as u64).collect();
                    if t_ring.iter().all(|&x| x == 0) {
                        continue;
                    }
                    // prods[e] = CQ0[e] * T (16 ring products), then
                    // rows[cd] += sigma * prods[(cd - d1) mod 16].
                    let prods: Vec<Poly> = cq0
                        .iter()
                        .map(|c| {
                            if c.iter().all(|&x| x == 0) {
                                poly_zero()
                            } else {
                                ring_mul_split_kara_fast(ctx, c, &t_ring)
                            }
                        })
                        .collect();
                    for cd in 0..K_DEG {
                        let e = (cd + K_DEG - d1) % K_DEG;
                        let term = if cd < d1 { super::poly_scale(zq, s, &prods[e]) } else { prods[e].clone() };
                        rows[cd] = poly_add(zq, &rows[cd], &term);
                    }
                }
                rows
            };
            let n_blocks = n_k * nb;
            let per_block: Vec<Vec<Poly>> = pooled(|| {
                use rayon::prelude::*;
                if threads() > 1 {
                    (0..n_blocks).into_par_iter().map(block_rows).collect()
                } else {
                    (0..n_blocks).map(block_rows).collect()
                }
            });
            for rows in &per_block {
                for cd in 0..K_DEG {
                    b_rows[cd] = poly_add(zq, &b_rows[cd], &rows[cd]);
                }
            }
        }
    }
    (b_rows, phi)
}

/// Absorb a poly list into the transcript (canonical bytes).
pub fn absorb_polys(tr: &mut LkpTranscript, label: &str, polys: &[Poly]) {
    tr.absorb(label, &super::polys_bytes(polys));
}

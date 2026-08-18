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

/// [U-PERF2 orchestrator, 2026-08-17] The SAME XOF stream as
/// `expand_level_matrix_raw`, generated block-parallel: XofReader's
/// stream is SHA-256 counter mode (block i = SHA256(key || i_le), 32 B
/// each, consumed byte-sequentially by `next_field`'s rejection sampler),
/// so the blocks can be produced on the pool and walked in order —
/// byte-identical output by construction (asserted by the O1 battery
/// leg raw == par at both moduli). The CRS expansion was ~17% of the
/// 8-thread 3x16 wall (one serial SHA-256 stream per matrix).
pub fn expand_level_matrix_par(
    seed: u64,
    group: &str,
    level: usize,
    which: &str,
    rows: usize,
    cols: usize,
    q: u64,
) -> Vec<Poly> {
    use sha2::{Digest, Sha256};
    // The key exactly as XofReader::new derives it.
    let items: [&[u8]; 6] = [
        &seed.to_le_bytes(),
        group.as_bytes(),
        &(level as u64).to_le_bytes(),
        which.as_bytes(),
        &(rows as u64).to_le_bytes(),
        &(cols as u64).to_le_bytes(),
    ];
    let mut hasher = Sha256::new();
    hasher.update(b"route-r-v1");
    hasher.update("agg-level-crs".as_bytes());
    for item in items {
        hasher.update((item.len() as u64).to_le_bytes());
        hasher.update(item);
    }
    let key: [u8; 32] = hasher.finalize().into();
    let n_el = rows * cols * D;
    // Rejection sampling accepts all but ~q/2^bits of the draws; 8 bytes
    // per accepted element plus a small margin, extended on demand.
    let mut n_blocks = ((n_el as u128 * 8 * 1002 / 1000) / 32) as usize + 16;
    let gen_blocks = |lo: usize, hi: usize| -> Vec<u8> {
        let mk = |i: usize| -> [u8; 32] {
            let mut h = Sha256::new();
            h.update(key);
            h.update((i as u64).to_le_bytes());
            h.finalize().into()
        };
        let blocks: Vec<[u8; 32]> = pooled(|| {
            use rayon::prelude::*;
            if threads() > 1 { (lo..hi).into_par_iter().map(mk).collect() } else { (lo..hi).map(mk).collect() }
        });
        let mut out = Vec::with_capacity((hi - lo) * 32);
        for b in blocks {
            out.extend_from_slice(&b);
        }
        out
    };
    let mut stream = {
        let _tb = prof::timer(prof::M_CRS_BLOCKS); // [UPERF2-M] observation only
        gen_blocks(0, n_blocks)
    };
    let _tw = prof::timer(prof::M_CRS_WALK); // [UPERF2-M] observation only
    let shift = q.leading_zeros();
    let mut pos = 0usize;
    let mut out: Vec<Poly> = Vec::with_capacity(rows * cols);
    for _ in 0..rows * cols {
        let mut p = poly_zero();
        for c in p.iter_mut() {
            loop {
                if pos + 8 > stream.len() {
                    let more = gen_blocks(n_blocks, n_blocks + 1024);
                    n_blocks += 1024;
                    stream.extend_from_slice(&more);
                }
                let v = u64::from_le_bytes(stream[pos..pos + 8].try_into().unwrap()) >> shift;
                pos += 8;
                if v < q {
                    *c = v;
                    break;
                }
            }
        }
        out.push(p);
    }
    out
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
    expand_level_matrix_arc(seed, group, level, which, rows, cols, q).as_ref().clone()
}

/// [UPERF2-F] `ZK_CRS_MEMO=0` turns the process-global CRS memo OFF: every
/// expansion is computed on demand and freed with its last handle (the
/// values are the same expansion; only residency changes). Default ON
/// (prove-then-verify in one process reuses the level-0 matrices).
static CRS_MEMO: LazyLock<bool> =
    LazyLock::new(|| std::env::var("ZK_CRS_MEMO").map(|v| v != "0").unwrap_or(true));

/// [UPERF2-F] `expand_level_matrix` handing out the memo's `Arc` handle
/// (no clone: the level-0 A matrices are ~1 GB each at 12x512, and the
/// memo + the clone were two copies). Values identical to
/// `expand_level_matrix` (which is this plus a clone).
pub fn expand_level_matrix_arc(
    seed: u64,
    group: &str,
    level: usize,
    which: &str,
    rows: usize,
    cols: usize,
    q: u64,
) -> Arc<Vec<Poly>> {
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
            return hit.clone();
        }
    }
    let _t = prof::timer(prof::EP_CRS); // miss: time the XOF
    let v = if oracle_mode() {
        expand_level_matrix_raw(seed, group, level, which, rows, cols, q)
    } else {
        expand_level_matrix_par(seed, group, level, which, rows, cols, q)
    };
    let a = Arc::new(v);
    if *CRS_MEMO {
        CRS_CACHE.lock().expect("crs cache").insert(key, a.clone());
    }
    a
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
    matvec_modq_small_multi_gen::<[Vec<i64>]>(ctx, m, rows, cols, s_list)
}

/// [UPERF2-F] `matvec_modq_small_multi` over either small-ring store
/// (`SmallRings`): the body; identical values on both.
pub fn matvec_modq_small_multi_gen<B: SmallRings + ?Sized>(
    ctx: &RingCtx,
    m: &[Poly],
    rows: usize,
    cols: usize,
    s_list: &[&B],
) -> Vec<Vec<Poly>> {
    let _t = prof::timer(prof::EP_MATVEC); // [UPERF-PC] observation only
    assert_eq!(m.len(), rows * cols);
    for s in s_list {
        assert_eq!(s.n_rings(), cols);
    }
    if oracle_mode() {
        return s_list.iter().map(|s| matvec_modq_small_ref_gen(ctx, m, rows, cols, *s)).collect();
    }
    let a: Vec<&[Poly]> = (0..rows).map(|r| &m[r * cols..(r + 1) * cols]).collect();
    let flat = ntt_gemm_modq_small_gen(ctx, &a, s_list, cols); // [row][i]
    let n_s = s_list.len();
    (0..n_s)
        .map(|i| (0..rows).map(|row| flat[row * n_s + i].clone()).collect())
        .collect()
}

/// The Karatsuba oracle for `matvec_modq_small` (the pre-O3 body; battery
/// use only — every call site rides the NTT-domain body).
pub fn matvec_modq_small_ref(ctx: &RingCtx, m: &[Poly], rows: usize, cols: usize, s: &[Vec<i64>]) -> Vec<Poly> {
    matvec_modq_small_ref_gen::<[Vec<i64>]>(ctx, m, rows, cols, s)
}

/// [UPERF2-F] `matvec_modq_small_ref` over either small-ring store.
pub fn matvec_modq_small_ref_gen<B: SmallRings + ?Sized>(
    ctx: &RingCtx,
    m: &[Poly],
    rows: usize,
    cols: usize,
    s: &B,
) -> Vec<Poly> {
    assert_eq!(s.n_rings(), cols);
    assert_eq!(m.len(), rows * cols);
    let zq = &ctx.zq;
    let mut buf = [0i64; D];
    (0..rows)
        .map(|r| {
            let mut acc = poly_zero();
            for c in 0..cols {
                let sc = s.ring(c, &mut buf);
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
    ring_ip_modq_small_ref_gen::<[Vec<i64>]>(ctx, phi, s)
}

/// [UPERF2-F] `ring_ip_modq_small_ref` over either small-ring store.
pub fn ring_ip_modq_small_ref_gen<B: SmallRings + ?Sized>(ctx: &RingCtx, phi: &[Poly], s: &B) -> Poly {
    assert_eq!(phi.len(), s.n_rings());
    let zq = &ctx.zq;
    let mut acc = poly_zero();
    let mut buf = [0i64; D];
    for (u, p) in phi.iter().enumerate() {
        let sc = s.ring(u, &mut buf);
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
    ntt_gemm_modq_small_gen::<[Vec<i64>]>(ctx, a, b, len)
}

/// [UPERF2-F] The kernel body over either small-ring store
/// (`SmallRings`: boxed `[Vec<i64>]` or the flat i8 `DigitCols` view).
/// Every small ring is lifted per ring exactly as before (`lift_to_p` of
/// the same i64 coefficients), so the values are identical on both.
pub fn ntt_gemm_modq_small_gen<B: SmallRings + ?Sized>(ctx: &RingCtx, a: &[&[Poly]], b: &[&B], len: usize) -> Vec<Poly> {
    use super::aux::{
        balanced_mod_q, center_from_p, gl_reduce128, lift_to_p, mod_q_centered, ntt_fwd_best, ntt_inv_best, EPS,
    };
    let zq = &ctx.zq;
    let q = zq.q;
    let (na, nb) = (a.len(), b.len());
    for s in a {
        assert_eq!(s.len(), len, "a slice length");
    }
    for s in b {
        assert_eq!(s.n_rings(), len, "b slice length");
    }
    let mut out = vec![poly_zero(); na * nb];
    if na == 0 || nb == 0 || len == 0 {
        return out;
    }
    // [UPERF2-K] THE GPU HOOK (the only one in this file): with the
    // `gpu-cuda` feature, `ZK_GPU=1` and a live device, the CUDA port
    // computes the same exact-integer windows (bit-identical output; the
    // body below is its oracle). `None` = declined -> the body runs.
    if super::gpu::enabled() {
        if let Some(gout) = super::gpu::ntt_gemm_modq_small(ctx, a, b, len) {
            return gout;
        }
    }
    // Operand bound of the small side (exact, from the data — the
    // window is then a function of (q, s_max, len) only).
    let s_max: u128 = b.iter().map(|s| s.max_abs()).max().unwrap_or(0);
    let window = ntt_window_terms(q, s_max);
    if window == 0 {
        // Over capacity for the single-prime contract: exact oracle.
        for (ia, sa) in a.iter().enumerate() {
            for (ib, sb) in b.iter().enumerate() {
                out[ia * nb + ib] = ring_ip_modq_small_ref_gen(ctx, sa, *sb);
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
                        let mut buf = [0i64; D]; // [UPERF2-F] per-ring lift from either store
                        let ring = b[idx].ring(ub0 + ub, &mut buf);
                        if ring.iter().all(|&x| x == 0) {
                            *out = [0u64; D];
                            return;
                        }
                        for i in 0..D {
                            out[i] = lift_to_p(ring[i]);
                        }
                    }
                    ntt_fwd_best(out, t); // [UPERF2-C]/[UPERF2-I] branchless transform, SIMD when available; identical values
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
                    v[tt] = gl_reduce128(acc_lo[idx] + EPS as u128 * acc_hi[idx]);
                }
                ntt_inv_best(&mut v, t); // [UPERF2-C]
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
    level_h_pairs_gen::<[Vec<i64>]>(ctx, phi, w, chunk)
}

/// [UPERF2-F] `level_h_pairs` over either small-ring store (the body).
pub fn level_h_pairs_gen<B: SmallRings + ?Sized>(ctx: &RingCtx, phi: &[&[Poly]], w: &[&B], chunk: usize) -> Vec<Poly> {
    let _t = prof::timer(prof::EP_LEVELH); // [UPERF-PC] observation only
    let r = phi.len();
    assert_eq!(w.len(), r, "phi/w slice counts");
    if oracle_mode() {
        return level_h_pairs_ref_gen(ctx, phi, w, chunk);
    }
    let g = ntt_gemm_modq_small_gen(ctx, phi, w, chunk); // g[j*r + k] = <phi_j, w_k>
    level_h_from_g(&ctx.zq, &g, r)
}

/// h pairs from the r x r inner-product table: h_jj = g_jj, h_jk =
/// g_jk + g_kj (j < k), pair order.
fn level_h_from_g(zq: &Zq, g: &[Poly], r: usize) -> Vec<Poly> {
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
    level_h_pairs_ref_gen::<[Vec<i64>]>(ctx, phi, w, chunk)
}

/// [UPERF2-F] `level_h_pairs_ref` over either small-ring store.
pub fn level_h_pairs_ref_gen<B: SmallRings + ?Sized>(ctx: &RingCtx, phi: &[&[Poly]], w: &[&B], chunk: usize) -> Vec<Poly> {
    let r = phi.len();
    assert_eq!(w.len(), r);
    let zq = &ctx.zq;
    let mut h = Vec::with_capacity(r * (r + 1) / 2);
    for j in 0..r {
        assert_eq!(phi[j].len(), chunk);
        assert_eq!(w[j].n_rings(), chunk);
        for k in j..r {
            let mut hp = ring_ip_modq_small_ref_gen(ctx, phi[j], w[k]);
            if j != k {
                hp = poly_add(zq, &hp, &ring_ip_modq_small_ref_gen(ctx, phi[k], w[j]));
            }
            h.push(hp);
        }
    }
    h
}

/// Centered digit decomposition of a mod-q polynomial at base e, l
/// limbs (limb-major output: out[limb][coeff]).
/// [UPERF2-M] the digits are written straight into the limb rows
/// (`digits_into_local` == `digits::exact_digit_decompose`, the same
/// arithmetic without the per-coefficient Vec); `decompose_poly_modq_ref`
/// is the pre-change body.
pub fn decompose_poly_modq(zq: &Zq, p: &Poly, e: u32, l: usize) -> Vec<Vec<i64>> {
    let mut out = vec![vec![0i64; D]; l];
    let mut tmp = [0i64; 64];
    assert!(l <= 64, "limb count");
    for c in 0..D {
        digits_into_local(zq.center(p[c]), e.max(2), &mut tmp[..l]);
        for a in 0..l {
            out[a][c] = tmp[a];
        }
    }
    out
}

/// The pre-[UPERF2-M] `decompose_poly_modq` (battery oracle).
pub fn decompose_poly_modq_ref(zq: &Zq, p: &Poly, e: u32, l: usize) -> Vec<Vec<i64>> {
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
/// [UPERF2-M] allocation-free digits (see `decompose_poly_modq`);
/// `decompose_poly_small_ref` is the pre-change body.
pub fn decompose_poly_small(p: &[i64], e: u32, l: usize) -> Vec<Vec<i64>> {
    let mut out = vec![vec![0i64; D]; l];
    let mut tmp = [0i64; 64];
    assert!(l <= 64, "limb count");
    for c in 0..D {
        digits_into_local(p[c], e.max(2), &mut tmp[..l]);
        for a in 0..l {
            out[a][c] = tmp[a];
        }
    }
    out
}

/// The pre-[UPERF2-M] `decompose_poly_small` (battery oracle).
pub fn decompose_poly_small_ref(p: &[i64], e: u32, l: usize) -> Vec<Vec<i64>> {
    let mut out = vec![vec![0i64; D]; l];
    for c in 0..D {
        let digs = super::digits::exact_digit_decompose(p[c], e.max(2), l);
        for (a, d) in digs.into_iter().enumerate() {
            out[a][c] = d;
        }
    }
    out
}

/// [UPERF2-M] `digits::exact_digit_decompose(x, e0, out.len())` written
/// into `out` — the same arithmetic (sign-binary at e0 = 1, the balanced
/// base-2^e0 digits otherwise, the same range panics), no allocation.
#[inline]
fn digits_into_local(x: i64, e0: u32, out: &mut [i64]) {
    let l = out.len();
    if e0 == 1 {
        let s = x.signum();
        let a = x.unsigned_abs();
        assert!(a < (1u64 << l), "sign-binary range exhausted for {x}");
        for (j, o) in out.iter_mut().enumerate() {
            *o = s * (((a >> j) & 1) as i64);
        }
    } else {
        let base = 1i64 << e0;
        let half = base >> 1;
        let mut rem = x;
        for o in out.iter_mut() {
            let mut d = rem % base;
            if d >= half {
                d -= base;
            }
            if d < -half {
                d += base;
            }
            *o = d;
            rem = (rem - d) / base;
        }
        assert!(rem == 0, "digit range exhausted for {x}");
    }
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
///
/// [UPERF2-C T3b] The body is now `transport_level_from_psi_fast` (the
/// general x general products in the limb-split Goldilocks NTT domain,
/// see the [UPERF2-C] section); `transport_level_from_psi_ref` is the
/// pre-change body, bit-identical (diff-battery leg `uperf-c`), and
/// `ZK_UPERF_ORACLE=1` routes here at runtime.
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
    if oracle_mode() {
        return transport_level_from_psi_ref(ctx, psi, h_target, plan, layout, a_mat, bindings, c, alphas);
    }
    transport_level_from_psi_fast(ctx, psi, h_target, plan, layout, a_mat, bindings, c, alphas)
}

/// The pre-[UPERF2-C] body of `transport_level_from_psi` (per next-
/// witness ring, Karatsuba ring products against the radix-scaled
/// operands) — the T3b oracle; battery use and `ZK_UPERF_ORACLE=1`.
#[allow(clippy::too_many_arguments)]
pub fn transport_level_from_psi_ref(
    ctx: &RingCtx,
    psi: &[Poly],
    h_target: &Poly,
    plan: &LevelPlan,
    layout: &NextLayout,
    a_mat: &[Poly],
    bindings: &[OuterBinding],
    c: &[Vec<i64>],
    alphas: &[Poly],
) -> LevelTransport {
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
/// functional's chunk slices. [UPERF2-C] NTT-domain body
/// (`compute_psi_ntt`, threads over u); `compute_psi_ref` is the
/// Karatsuba oracle it is bit-identical to; `ZK_UPERF_ORACLE=1` routes
/// to the oracle.
pub fn compute_psi(ctx: &RingCtx, phi: &[Poly], chunk: usize, c: &[Vec<i64>]) -> Vec<Poly> {
    let _t = prof::timer(prof::EP_PSI); // [UPERF-PC] observation only
    if oracle_mode() {
        return compute_psi_ref(ctx, phi, chunk, c);
    }
    compute_psi_ntt(ctx, phi, chunk, c)
}

/// The pre-[UPERF2-C] body of `compute_psi` (one Karatsuba product per
/// (k, u) term) — the oracle; battery use and `ZK_UPERF_ORACLE=1`.
pub fn compute_psi_ref(ctx: &RingCtx, phi: &[Poly], chunk: usize, c: &[Vec<i64>]) -> Vec<Poly> {
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
    let mut ntt_tensors: Vec<PsiAlignedTensor> = Vec::new(); // [UPERF2-M]
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
            // Generic branch (misaligned cols — the BK aux tensors have
            // cols = 16): per VALUE ring the K-weight row once, PHI once
            // (radix 1), then per limb radix * (c_k * PHI) with the c_k
            // product cached per k-run. Identical values to the per-digit
            // -ring reference `phi0_ring_multi` (radix is a scalar; the
            // K-weight row does not depend on the limb) — the pre-fix
            // code recomputed 256 K-mults x 16 kara-muls PER DIGIT RING
            // (l0 = 16 limbs for the q-range aux tensors: 137 of the 142 s
            // verify at 3x16). Under `pre_o5` (oracle) the reference runs.
            let _te = prof::timer(prof::E_PSI0_SMALL); // [UPERF2-E] observation only
            if pre_o5 {
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
            let radixes: Vec<u64> =
                (0..t.l0).map(|l| zq.to_mod(1i64 << (t.e0 as usize * l))).collect();
            let n_vr = t.n_value_rings();
            // [UPERF2-E] hoisted K-weight rows (see kw_hoist); the
            // pre-change per-value-ring body is `kw_row_sync`.
            let ks = kw_hoist(kf, t, &kers);
            let contrib_of = |vr: usize| -> Vec<(usize, Poly)> {
                let kw = kw_row_hoisted(kf, &ks, vr);
                let mut out = Vec::with_capacity(t.l0);
                if kw.iter().all(|k| kf.is_zero(k)) {
                    return out;
                }
                // PHI at radix 1: sum_cd alpha_cd * bp_cd(kw).
                let bp = bpolys_from_kw_local(zq, &kw, 1);
                let mut ph = poly_zero();
                for (a, b) in alphas.iter().zip(bp.iter()) {
                    if b.iter().all(|&x| x == 0) {
                        continue;
                    }
                    ph = poly_add(zq, &ph, &ring_mul_split_kara_fast(ctx, a, b));
                }
                if ph.iter().all(|&x| x == 0) {
                    return out;
                }
                let mut cached: Option<(usize, Poly)> = None;
                for limb in 0..t.l0 {
                    let v = t.digit_ring_base + vr * t.l0 + limb;
                    let (k, u) = (v / chunk, v % chunk);
                    debug_assert!(k < r);
                    let s = match &cached {
                        Some((ck, s)) if *ck == k => s.clone(),
                        _ => {
                            let s = ring_mul_split_kara_fast(ctx, &ph, &c_polys[k]);
                            cached = Some((k, s.clone()));
                            s
                        }
                    };
                    out.push((u, super::poly_scale(zq, radixes[limb], &s)));
                }
                out
            };
            const VR_BLOCK_G: usize = 1024;
            let mut vr0 = 0;
            while vr0 < n_vr {
                let vr1 = (vr0 + VR_BLOCK_G).min(n_vr);
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
            continue;
        }
        let nb = t.cols / D;
        // [UPERF-PC O5] the factored form (PhiFactored: PHI_vr from the
        // hoisted row factors against the cached alpha-contracted col
        // blocks — no per-row K-mults, no per-value-ring ring-mults);
        // exactly the pre-O5 beta x conjQ value (bit-identical, asserted
        // by the diff-battery leg O5 against compute_psi(phi0_reference_multi)).
        let pf = PhiFactored::new(ctx, kf, &kers, nb, alphas, &mut cache);
        // [UPERF2-M] the u-major NTT-domain accumulation takes every
        // aligned tensor whose integer radix fits the capacity analysis;
        // the rest (and `ZK_PSI0NTT=0`) ride today's body below.
        if psi0_ntt_enabled() && psi_ntt_tensor_fits(t) {
            ntt_tensors.push(PsiAlignedTensor { t: t.clone(), pf });
            continue;
        }
        psi_level0_aligned_today(ctx, t, &pf, &c_polys, chunk, &mut psi);
    }
    if !ntt_tensors.is_empty() {
        let _tn = prof::timer(prof::M_PSI0_NTT); // [UPERF2-M] observation only
        if !psi_level0_aligned_ntt(ctx, &ntt_tensors, c, chunk, &mut psi) {
            // Over capacity for the single-prime contract at this (q, c,
            // radix) — today's body per tensor (identical values).
            for at in &ntt_tensors {
                psi_level0_aligned_today(ctx, &at.t, &at.pf, &c_polys, chunk, &mut psi);
            }
        }
    }
    psi
}

/// The pre-[UPERF2-M] aligned fast body of `psi_level0_factored_multi`
/// (O5's form): per value ring RQ = PHI_vr, then its l0 digit rings'
/// contributions radix_limb * (c_k * RQ) with the c_k product cached per
/// k-run — computed in parallel per value-ring block, folded into psi
/// serially in (vr, limb) order. Kept verbatim as the NTT body's oracle
/// (`ZK_PSI0NTT=0`) and the over-capacity fallback. Adds into `psi`.
fn psi_level0_aligned_today(
    ctx: &RingCtx,
    t: &AggTensor,
    pf: &PhiFactored,
    c_polys: &[Poly],
    chunk: usize,
    psi: &mut [Poly],
) {
    let zq = &ctx.zq;
    let r = c_polys.len();
    let nb = t.cols / D;
    let radixes: Vec<u64> = (0..t.l0).map(|l| zq.to_mod(1i64 << (t.e0 as usize * l))).collect();
    let n_vr = t.rows * nb;
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

/// [UPERF2-M] One aligned tensor queued for the u-major NTT accumulation.
struct PsiAlignedTensor {
    t: AggTensor,
    pf: PhiFactored,
}

/// The integer radix cap of the NTT accumulation: 2^(e0*(l0-1)) < 2^40
/// keeps (R c) an i64 small ring and the capacity product in u128 range.
const PSI_NTT_RADIX_BITS_MAX: usize = 40;

/// Positions per u-block of the NTT accumulation (one `NttAcc` per u: 1 KiB
/// canonical on x86_64 / 4 KiB split-halves elsewhere; the block's planes
/// stay L2-resident next to the c-hat table; the value ring straddling a
/// block edge is recomputed once per (k, block) — l0/block of the work).
pub const PSI_NTT_UBLOCK: usize = 256;

fn psi_ntt_tensor_fits(t: &AggTensor) -> bool {
    t.cols % D == 0 && t.l0 >= 1 && (t.e0 as usize) * (t.l0 - 1) < PSI_NTT_RADIX_BITS_MAX
}

/// [UPERF2-M] The u-major NTT-domain accumulation of the aligned tensors'
/// share of Psi_0 (see the section note): per u-block, per k, the digit
/// rings [k*chunk + u0, k*chunk + u1) walk the tensors, PHI-hat once per
/// value ring, split-halves MAC of PHI-hat x (R c_k)-hat into the block's
/// planes, flush at the window and at the end. Adds into `psi`. Returns
/// false (nothing added) when the capacity contract cannot be met.
fn psi_level0_aligned_ntt(
    ctx: &RingCtx,
    tensors: &[PsiAlignedTensor],
    c: &[Vec<i64>],
    chunk: usize,
    psi: &mut [Poly],
) -> bool {
    use super::aux::{balanced_mod_q, center_from_p, lift_to_p, mod_q_centered, ntt_fwd_best};
    let zq = &ctx.zq;
    let q = zq.q;
    let r = c.len();
    if r == 0 || chunk == 0 || tensors.is_empty() {
        return true;
    }
    assert!(psi.len() >= chunk);
    // The integer radixes: per tensor per limb -> an index into the
    // distinct-radix table.
    let mut radix_vals: Vec<u128> = Vec::new();
    let mut radix_idx: Vec<Vec<usize>> = Vec::with_capacity(tensors.len());
    for at in tensors {
        let t = &at.t;
        let mut idx = Vec::with_capacity(t.l0);
        for limb in 0..t.l0 {
            let rv = 1u128 << (t.e0 as usize * limb);
            let i = match radix_vals.iter().position(|&x| x == rv) {
                Some(i) => i,
                None => {
                    radix_vals.push(rv);
                    radix_vals.len() - 1
                }
            };
            idx.push(i);
        }
        radix_idx.push(idx);
    }
    let radix_max = radix_vals.iter().copied().max().unwrap_or(1);
    let cmax: u128 = c.iter().flat_map(|ck| ck.iter()).map(|&x| x.unsigned_abs() as u128).max().unwrap_or(0);
    let window = ntt_window_terms(q, cmax * radix_max);
    if window == 0 {
        return false;
    }
    let t = &*NTT;
    // (R c_k)-hat for every (radix, k).
    let n_rad = radix_vals.len();
    let c_hat: Vec<[u64; D]> = (0..n_rad * r)
        .map(|i| {
            let (ri, k) = (i / r, i % r);
            let rv = radix_vals[ri] as i64; // < 2^40
            let ck: Vec<i64> = c[k].iter().map(|&x| x * rv).collect();
            fwd_small(&ck, t)
        })
        .collect();
    let block = PSI_NTT_UBLOCK;
    let one_block = |bi: usize, psi_blk: &mut [Poly]| {
        let u0 = bi * block;
        let n = psi_blk.len();
        let mut acc: Vec<NttAcc> = vec![NttAcc::new(); n];
        let mut cnt = vec![0usize; n];
        let mut phi_hat = [0u64; D];
        let flush = |i: usize, acc: &mut [NttAcc], cnt: &mut [usize], psi_blk: &mut [Poly]| {
            let v = acc[i].flush(t);
            let o = &mut psi_blk[i];
            for tt in 0..D {
                let cq = mod_q_centered(center_from_p(v[tt]), q);
                o[tt] = zq.add(o[tt], cq);
            }
            acc[i].reset();
            cnt[i] = 0;
        };
        for k in 0..r {
            let v_lo = k * chunk + u0;
            let v_hi = v_lo + n;
            for (ti, at) in tensors.iter().enumerate() {
                let tt = &at.t;
                let base = tt.digit_ring_base;
                let (lo, hi) = (base.max(v_lo), (base + tt.n_digit_rings()).min(v_hi));
                if lo >= hi {
                    continue;
                }
                let l0 = tt.l0;
                let (rel_lo, rel_hi) = (lo - base, hi - base);
                let ridx = &radix_idx[ti];
                let mut vr = rel_lo / l0;
                while vr * l0 < rel_hi {
                    at.pf.value_ring_into(vr, &mut phi_hat);
                    let zero = phi_hat.iter().all(|&x| x == 0);
                    if !zero {
                        for j in 0..D {
                            phi_hat[j] = lift_to_p(balanced_mod_q(phi_hat[j], q));
                        }
                        ntt_fwd_best(&mut phi_hat, t);
                    }
                    let a = rel_lo.max(vr * l0);
                    let b = rel_hi.min((vr + 1) * l0);
                    for rel in a..b {
                        let limb = rel - vr * l0;
                        let i = base + rel - v_lo;
                        if !zero {
                            acc[i].mac(&phi_hat, &c_hat[ridx[limb] * r + k]);
                        }
                        cnt[i] += 1;
                        if cnt[i] == window {
                            flush(i, &mut acc, &mut cnt, psi_blk);
                        }
                    }
                    vr += 1;
                }
            }
        }
        for i in 0..n {
            if cnt[i] > 0 {
                flush(i, &mut acc, &mut cnt, psi_blk);
            }
        }
    };
    let psi = &mut psi[..chunk];
    if threads() > 1 {
        pooled(|| {
            use rayon::prelude::*;
            psi.par_chunks_mut(block).enumerate().for_each(|(bi, blk)| one_block(bi, blk));
        });
    } else {
        psi.chunks_mut(block).enumerate().for_each(|(bi, blk)| one_block(bi, blk));
    }
    true
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
/// [UPERF2-M] parallel over rows (independent K-mults, order kept) on the
/// fold-reduced K-mult (`kmul_fast` == `kf.mul`).
fn kernel_row_factors(kf: &KField, ker: &MultiClaimKernel) -> Vec<KElem> {
    let qf = QFold::new(kf.zq.q);
    let rows: &[KElem] = &ker.row_kernel;
    let scale: &KElem = &ker.scale;
    map_ordered_min(rows.len(), MAP_MIN_PAR, |i| kmul_fast(kf, &qf, scale, &rows[i]))
}

// ---------------------------------------------------------------------------
// [UPERF2-M] The fold-reduced mod-q scalar and K-field helpers used by the
// hoisted claim-kernel paths (row factors, the misaligned tensors' K-weight
// rows, the conj-packed bpolys). `kf.mul` = `slot_mul_g` reduces its 32
// u128 column sums with `% q` (a libcall per coefficient) and its 16 fold
// mults with `zq.mul` (another); on the house moduli q = 2^b - c with a
// tiny c (q31: b 31, c 399; q46: b 46, c 1103) the same canonical
// residues come from the exact identity 2^b == c (mod q):
//   x -> (x mod 2^b) + c (x >> b)   (== x mod q)
// applied twice from x < 2^(2b+4) (the 16-term column sum of products of
// canonical operands): after the first fold x < 2^b + c 2^(b+4) <
// 2^(b+17); after the second < 2^b + c 2^17 < 2q (b >= 30, c < 2^12); one
// conditional subtract lands the canonical value. `QFold::new` checks the
// class and falls back to `% q` otherwise. Canonical residues of equal
// integers are equal — identical bytes; `uperf-m battery` leg E asserts
// `kmul_fast == kf.mul` and `mulmod_fold == zq.mul` on extremes + random.

/// Modulus class constants for the fold reduction (None = use `% q`).
#[derive(Clone, Copy)]
struct QFold {
    q: u64,
    b: u32,
    c: u64,
    ok: bool,
}

impl QFold {
    fn new(q: u64) -> QFold {
        let b = 64 - q.leading_zeros(); // 2^(b-1) <= q < 2^b
        let c = (1u128 << b) as u128 - q as u128; // 2^b - q
        let ok = b >= 30 && b <= 46 && c < (1u128 << 12) && q > (1u64 << (b - 1));
        QFold { q, b, c: c as u64, ok }
    }
    /// x mod q, canonical, for x < 2^(2b + 4).
    #[inline(always)]
    fn reduce(&self, x: u128) -> u64 {
        if !self.ok {
            return (x % self.q as u128) as u64;
        }
        debug_assert!(x < (1u128 << (2 * self.b + 4)));
        let mask = (1u64 << self.b) - 1;
        let x1: u64 = ((x as u64) & mask) + self.c * ((x >> self.b) as u64);
        let x2: u64 = (x1 & mask) + self.c * (x1 >> self.b);
        if x2 >= self.q { x2 - self.q } else { x2 }
    }
    /// a * b mod q, canonical (a, b < q).
    #[inline(always)]
    fn mulmod(&self, a: u64, b: u64) -> u64 {
        self.reduce(a as u128 * b as u128)
    }
}

/// `kf.mul` (schoolbook in F_q[Y]/(Y^16 - s)) with the fold reduction —
/// identical values.
fn kmul_fast(kf: &KField, qf: &QFold, a: &KElem, b: &KElem) -> KElem {
    let m = K_DEG;
    let mut wide = [0u128; 2 * K_DEG];
    for i in 0..m {
        if a[i] == 0 {
            continue;
        }
        let ai = a[i] as u128;
        for j in 0..m {
            wide[i + j] += ai * b[j] as u128;
        }
    }
    let q = qf.q;
    (0..m)
        .map(|t| {
            let lo = qf.reduce(wide[t]);
            let hi = qf.reduce(wide[t + m]);
            let sh = qf.mulmod(kf.s, hi);
            let v = lo + sh;
            if v >= q { v - q } else { v }
        })
        .collect()
}

/// [UPERF2-M] Battery entries: the fold-reduced K-mult / mulmod.
pub fn kmul_fast_pub(kf: &KField, a: &KElem, b: &KElem) -> KElem {
    kmul_fast(kf, &QFold::new(kf.zq.q), a, b)
}
pub fn mulmod_fold_pub(q: u64, a: u64, b: u64) -> u64 {
    QFold::new(q).mulmod(a, b)
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
///
/// [UPERF2-M] The 256 products ride `ntt_combine_pool` (alphas = the 16
/// CQ0 rings, pool = the 16 alphas and their s-multiples, idx(e, d1) =
/// (e + d1) mod 16 [+ 16 when e + d1 >= 16]): out[d1] = sum_e CQ0[e] *
/// (sigma * alpha_f) — the same mod-q sum of the same ring products
/// (sigma is a scalar), so identical canonical values; `g_block_ref` is
/// the pre-change body (`ZK_GBLOCKNTT=0`; `ZK_UPERF_ORACLE=1` routes the
/// pool kernel to its Karatsuba oracle as well).
fn g_block(ctx: &RingCtx, s: u64, cq0: &[Poly], alphas: &[Poly]) -> Vec<Poly> {
    if !gblock_ntt_enabled() {
        return g_block_ref(ctx, s, cq0, alphas);
    }
    g_block_pool(ctx, s, cq0, alphas)
}

/// [UPERF2-M] The pool form of `g_block` (battery entry; what `g_block`
/// runs by default).
pub fn g_block_pool(ctx: &RingCtx, s: u64, cq0: &[Poly], alphas: &[Poly]) -> Vec<Poly> {
    g_block_pool_impl(ctx, s, cq0, alphas, true)
}

fn g_block_pool_impl(ctx: &RingCtx, s: u64, cq0: &[Poly], alphas: &[Poly], par: bool) -> Vec<Poly> {
    let zq = &ctx.zq;
    let mut pool: Vec<Poly> = Vec::with_capacity(2 * K_DEG);
    pool.extend(alphas.iter().cloned());
    pool.extend(alphas.iter().map(|a| super::poly_scale(zq, s, a)));
    let idx = |e: usize, d1: usize| -> usize { (e + d1) % K_DEG + if e + d1 >= K_DEG { K_DEG } else { 0 } };
    ntt_combine_pool_impl(ctx, cq0, &pool, &idx, K_DEG, par)
}

/// [UPERF2-M] `ZK_GBLOCKNTT=0` keeps the Karatsuba G blocks (read once).
static GBLOCK_NTT: LazyLock<bool> =
    LazyLock::new(|| std::env::var("ZK_GBLOCKNTT").map(|v| v != "0").unwrap_or(true));

#[inline(always)]
fn gblock_ntt_enabled() -> bool {
    *GBLOCK_NTT
}

/// The pre-[UPERF2-M] `g_block` body verbatim (256 Karatsuba products,
/// then the sigma-scaled sums) — the oracle of the pool form.
pub fn g_block_ref(ctx: &RingCtx, s: u64, cq0: &[Poly], alphas: &[Poly]) -> Vec<Poly> {
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

    /// [UPERF2-M] Every G block of `kers` x 0..nb not yet cached, built
    /// BLOCK-PARALLEL (each block's cq0 + pool combine inline; blocks are
    /// independent, so the order cannot move a value), then inserted.
    /// After this, `g(..)` for those keys hits.
    fn g_prepare(&mut self, ctx: &RingCtx, s: u64, kers: &[&MultiClaimKernel], nb: usize, alphas: &[Poly]) {
        let mut todo: Vec<(usize, usize)> = Vec::new(); // (kernel index, cb)
        let mut seen: std::collections::HashSet<(usize, usize)> = std::collections::HashSet::new();
        for (ki, k) in kers.iter().enumerate() {
            for cb in 0..nb {
                let key = Self::key(k, cb);
                if self.g.contains_key(&key) || !seen.insert(key) {
                    continue;
                }
                todo.push((ki, cb));
            }
        }
        if todo.is_empty() {
            return;
        }
        // The col kernels as plain slices (Rc is not Sync; the data is).
        let cols: Vec<&[KElem]> = kers.iter().map(|k| k.col_kernel.as_slice()).collect();
        let zq = &ctx.zq;
        let built: Vec<(Vec<Poly>, Vec<Poly>)> = map_ordered_min(todo.len(), 2, |i| {
            let (ki, cb) = todo[i];
            let cq0 = cq0_block(zq, cols[ki], cb);
            let g = if gblock_ntt_enabled() { g_block_pool_impl(ctx, s, &cq0, alphas, false) } else { g_block_ref(ctx, s, &cq0, alphas) };
            (cq0, g)
        });
        for ((ki, cb), (cq0, g)) in todo.into_iter().zip(built) {
            let key = Self::key(kers[ki], cb);
            self.cq0.entry(key).or_insert_with(|| Arc::new(cq0));
            self.g.insert(key, Arc::new(g));
        }
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
    /// [UPERF2-M] the AVX2 MAC's modulus constants when the SIMD body
    /// applies to this q (see `psi_mac_simd_params`); None = scalar body.
    simd: Option<PsiMacParams>,
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
        let _t = prof::timer(prof::M_PHI_SETUP); // [UPERF2-M] observation only
        let srs = kers.iter().map(|k| kernel_row_factors(kf, k)).collect();
        cache.g_prepare(ctx, kf.s, kers, nb, alphas); // [UPERF2-M] block-parallel build
        let gs = kers
            .iter()
            .map(|k| (0..nb).map(|cb| cache.g(ctx, kf.s, k, cb, alphas)).collect())
            .collect();
        let simd = if psi_simd_enabled() { psi_mac_simd_params(ctx.zq.q) } else { None };
        PhiFactored { q: ctx.zq.q, nb, srs, gs, simd }
    }

    /// PHI of value ring vr (mod q; 16 x n_kernels scalar-x-ring MACs).
    fn value_ring(&self, vr: usize) -> Poly {
        let mut out = [0u64; D];
        self.value_ring_into(vr, &mut out);
        out.to_vec()
    }

    /// [UPERF2-M] `value_ring` into a stack buffer: the AVX2 MAC body when
    /// `simd` is set (canonical residues of the SAME exact sum — see the
    /// [UPERF2-M] section note), else the pre-change scalar u128 body
    /// (`value_ring_scalar_into`).
    #[inline]
    fn value_ring_into(&self, vr: usize, out: &mut [u64; D]) {
        #[cfg(target_arch = "x86_64")]
        if let Some(p) = &self.simd {
            // SAFETY: `simd` is Some only when AVX2 was detected (the
            // psi_simd_enabled() gate) and the modulus meets the bounds
            // the body relies on (psi_mac_simd_params).
            unsafe { self.value_ring_avx2(vr, p, out) };
            return;
        }
        self.value_ring_scalar_into(vr, out);
    }

    /// The pre-[UPERF2-M] body verbatim (u128 lazy MACs, `% q`): the
    /// SIMD body's oracle (`ZK_PSISIMD=0` routes here).
    fn value_ring_scalar_into(&self, vr: usize, out: &mut [u64; D]) {
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
        for j in 0..D {
            out[j] = (acc[j] % q) as u64;
        }
    }

    /// [UPERF2-M] The AVX2 body: `vpmuludq` u32 x u32 -> u64 exact products
    /// (s, g < q < 2^31) in bursts of 4 (< 2^64), each burst folded by
    /// 2^32 == c32 (mod q) into ONE u64 plane, then the fold-by-2^31 ==
    /// c31 reduction to the canonical residue — `psi_mac_avx2` on the
    /// (s, G ring) term list of the value ring.
    #[cfg(target_arch = "x86_64")]
    #[target_feature(enable = "avx2")]
    unsafe fn value_ring_avx2(&self, vr: usize, p: &PsiMacParams, out: &mut [u64; D]) {
        let (row, cb) = (vr / self.nb, vr % self.nb);
        // The term list (s != 0) — n_kernels x 16 at most; a stack list
        // for up to 16 kernels, a Vec beyond.
        const STACK_TERMS: usize = 16 * K_DEG;
        let n_max = self.srs.len() * K_DEG;
        let mut ss_st = [0u64; STACK_TERMS];
        let mut gg_st = [std::ptr::null::<u64>(); STACK_TERMS];
        let mut ss_v: Vec<u64> = Vec::new();
        let mut gg_v: Vec<*const u64> = Vec::new();
        let on_stack = n_max <= STACK_TERMS;
        if !on_stack {
            ss_v.reserve(n_max);
            gg_v.reserve(n_max);
        }
        let mut n = 0usize;
        for (ki, sr) in self.srs.iter().enumerate() {
            let g = &self.gs[ki][cb];
            let s_row = &sr[row];
            for d1 in 0..K_DEG {
                let s = s_row[d1];
                if s == 0 {
                    continue;
                }
                if on_stack {
                    ss_st[n] = s;
                    gg_st[n] = g[d1].as_ptr();
                } else {
                    ss_v.push(s);
                    gg_v.push(g[d1].as_ptr());
                }
                n += 1;
            }
        }
        if n > PSI_MAC_MAX_TERMS {
            // Beyond the analyzed bound (never in the designed shapes):
            // the scalar body.
            self.value_ring_scalar_into(vr, out);
            return;
        }
        if on_stack {
            unsafe { psi_avx2::mac_mod_q(&ss_st[..n], &gg_st[..n], p, out) };
        } else {
            unsafe { psi_avx2::mac_mod_q(&ss_v, &gg_v, p, out) };
        }
    }
}

// ---------------------------------------------------------------------------
// [UPERF2-M] The level-0 factored psi (U-PERF2 lane M): (a) the PHI MAC
// loop of `PhiFactored::value_ring` on AVX2 lanes and (b) the per-digit-
// ring `c_k * PHI` products of `psi_level0_factored_multi` as u-major
// NTT-domain accumulation. Both are DIFFERENTIAL: (a)'s oracle is the
// scalar u128 body (`ZK_PSISIMD=0`), (b)'s oracles are today's aligned
// body (`ZK_PSI0NTT=0`) and the pre-O5 kara form (`ZK_UPERF_ORACLE=1`).
//
// (a) WHY THE BYTES CANNOT MOVE. The scalar body computes, per
// coefficient j, the exact integer S_j = sum_t s_t * g_t[j] in u128 and
// returns S_j mod q (canonical). The AVX2 body computes canonical
// residues of the SAME S_j by exact-mod-q arithmetic on u64 lanes:
//   * s_t, g_t[j] < q < 2^31, so `vpmuludq` (low 32 bits x low 32 bits)
//     is the exact product P < 2^62, and a burst of <= 4 products is
//     exact in u64 (4 (q-1)^2 < 2^64);
//   * a burst B is folded as B' = (B mod 2^32) + c32 * (B >> 32) with
//     c32 = 2^32 mod q — B' == B (mod q) exactly (2^32 == c32), and B' <
//     2^32 + c32 * 2^32; the u64 plane sums the B' of all bursts:
//     acc_j == S_j (mod q), acc_j < n_bursts * 2^32 (1 + c32) < 2^63
//     for c32 < 2^16 and n_terms <= 2^16 (both asserted at dispatch);
//   * the finalize folds acc by 2^31 == c31 (c31 = 2^31 - q; q in
//     (2^30, 2^31)) twice — x -> (x mod 2^31) + c31 (x >> 31), each ==
//     x (mod q), the first from < 2^63 to < 2^31 + c31 2^32 < 2^41 (c31
//     < 2^10), the second to < 2^31 + c31 2^10 < 2q — then one
//     conditional subtract of q lands the CANONICAL residue.
// Canonical residues of equal integers are equal, hence identical bytes;
// `uperf-m battery` asserts it on planted extremes (all-(q-1) operands,
// term counts across every burst tail) and random term lists. The body
// runs only when q is in the analyzed class (2^30 < q < 2^31, c32 < 2^16,
// c31 < 2^10 — the house q31 = 2^31 - 399: c32 = 798, c31 = 399), AVX2 is
// detected and `ZK_PSISIMD` != 0; otherwise the scalar body runs
// (q46 always takes the scalar body — its operands do not fit u32 lanes).
//
// (b) WHY THE BYTES CANNOT MOVE. Today's aligned body adds, per digit
// ring v = (vr, limb) of an aligned tensor, radix_limb * (c_k * PHI_vr)
// mod q into psi[u], u = v mod chunk, k = v / chunk, radix_limb =
// 2^(e0*limb) mod q. Over the exact integers, with PHI in balanced form
// (|PHI| <= (q-1)/2), c quinary (|c| <= cmax) and the INTEGER radix
// R = 2^(e0*limb): every coefficient of (R c_k) (x) PHI is bounded by
// D * (q-1)/2 * cmax * R, and a sum of n such terms by n times that;
// n <= window := ntt_window_terms(q, cmax * R_max) keeps it under (p-1)/2,
// so its Goldilocks image (the split-halves NTT-domain accumulation, one
// forward transform of PHI per value ring, the (R c_k) transforms
// precomputed) determines the true integer, `center_from_p` recovers it,
// and reducing it mod q gives the residue of that partial sum; the mod-q
// sum of the partials over the fixed window schedule (terms counted per
// u in k order; flush at `window`, then at the end) is the residue of the
// whole aligned sum — the same integer today's body reduces term by term
// (radix_limb == R mod q). psi[u]'s other contributions (small-cols and
// generic tensors: today's bodies, unchanged) add their canonical residues
// into the same slot; mod-q addition is associative and commutative, so
// the final canonical psi[u] is identical. Threads: the u range is split
// into blocks, every block computed whole from the same term list — the
// window schedule depends on (u, k) only, never on the block or thread.
// Over capacity (window == 0, or an integer radix >= 2^40 — never in the
// designed shapes: e0 <= 2, l0 <= 8 for the aligned 125M tensors) the
// tensor rides today's body.

/// [UPERF2-M] `ZK_PSISIMD=0` forces the scalar PHI MAC (default: AVX2 when
/// detected). Read once; harness override via `set_psi_simd`.
static PSI_SIMD: LazyLock<std::sync::atomic::AtomicBool> = LazyLock::new(|| {
    let knob = std::env::var("ZK_PSISIMD").map(|v| v != "0").unwrap_or(true);
    std::sync::atomic::AtomicBool::new(knob && psi_simd_available())
});

/// Whether the box has the AVX2 PHI MAC body.
pub fn psi_simd_available() -> bool {
    #[cfg(target_arch = "x86_64")]
    {
        std::arch::is_x86_feature_detected!("avx2")
    }
    #[cfg(not(target_arch = "x86_64"))]
    {
        false
    }
}

#[inline(always)]
pub fn psi_simd_enabled() -> bool {
    PSI_SIMD.load(std::sync::atomic::Ordering::Relaxed)
}

/// Harness-only: flip the PHI MAC body at runtime (bench / battery A/B;
/// the AVX2 body is only ever taken when the box has it).
pub fn set_psi_simd(on: bool) {
    PSI_SIMD.store(on && psi_simd_available(), std::sync::atomic::Ordering::Relaxed);
}

/// [UPERF2-M] `ZK_PSI0NTT=0` keeps today's aligned psi0 body (kara per
/// value ring); default: the u-major NTT-domain accumulation. Harness
/// override via `set_psi0_ntt`.
static PSI0_NTT: LazyLock<std::sync::atomic::AtomicBool> = LazyLock::new(|| {
    std::sync::atomic::AtomicBool::new(std::env::var("ZK_PSI0NTT").map(|v| v != "0").unwrap_or(true))
});

#[inline(always)]
pub fn psi0_ntt_enabled() -> bool {
    PSI0_NTT.load(std::sync::atomic::Ordering::Relaxed)
}

/// Harness-only: flip the psi0 NTT routing at runtime (battery A/B).
pub fn set_psi0_ntt(on: bool) {
    PSI0_NTT.store(on, std::sync::atomic::Ordering::Relaxed);
}

/// The largest term count (nonzero (kernel, d1) pairs of one value ring)
/// the AVX2 MAC's plane bound covers (n_bursts * 2^32 (1 + c32) < 2^63 at
/// c32 < 2^16); beyond it the scalar body runs.
pub const PSI_MAC_MAX_TERMS: usize = 1 << 16;

/// [UPERF2-M] Modulus constants of the AVX2 PHI MAC.
#[derive(Clone, Copy, Debug)]
pub struct PsiMacParams {
    pub q: u64,
    /// 2^32 mod q (< 2^16 required).
    pub c32: u64,
    /// 2^31 - q (q in (2^30, 2^31); < 2^10 required).
    pub c31: u64,
}

/// The AVX2 MAC's modulus class: 2^30 < q < 2^31, c32 = 2^32 mod q < 2^16,
/// c31 = 2^31 - q < 2^10 (the house q31 qualifies; q46 does not).
pub fn psi_mac_simd_params(q: u64) -> Option<PsiMacParams> {
    if q <= (1u64 << 30) || q >= (1u64 << 31) {
        return None;
    }
    let c32 = (1u64 << 32) % q;
    let c31 = (1u64 << 31) - q;
    if c32 >= (1u64 << 16) || c31 >= (1u64 << 10) {
        return None;
    }
    Some(PsiMacParams { q, c32, c31 })
}

/// [UPERF2-M] Battery/bench entry: out[j] = (sum_t s[t] * g[t][j]) mod q by
/// the AVX2 body (None when the body does not apply to this box / q /
/// term count).
pub fn psi_mac_mod_q_simd(s: &[u64], g: &[&[u64]], q: u64) -> Option<[u64; D]> {
    assert_eq!(s.len(), g.len());
    if !psi_simd_available() || s.len() > PSI_MAC_MAX_TERMS {
        return None;
    }
    let p = psi_mac_simd_params(q)?;
    for (&sv, gv) in s.iter().zip(g.iter()) {
        assert!(sv < q, "psi_mac: s out of range");
        assert_eq!(gv.len(), D);
        debug_assert!(gv.iter().all(|&x| x < q), "psi_mac: g out of range");
    }
    #[cfg(target_arch = "x86_64")]
    {
        let ptrs: Vec<*const u64> = g.iter().map(|r| r.as_ptr()).collect();
        let mut out = [0u64; D];
        // SAFETY: AVX2 detected (psi_simd_available); every g[t] has D
        // lanes (asserted); the params bound the lane arithmetic (the
        // battery feeds canonical operands; the callers' G rings are
        // canonical by construction).
        unsafe { psi_avx2::mac_mod_q(s, &ptrs, &p, &mut out) };
        Some(out)
    }
    #[cfg(not(target_arch = "x86_64"))]
    {
        None
    }
}

/// [UPERF2-M] Battery/bench entry: the scalar u128 body on the same term list.
pub fn psi_mac_mod_q_scalar(s: &[u64], g: &[&[u64]], q: u64) -> [u64; D] {
    assert_eq!(s.len(), g.len());
    let mut acc = [0u128; D];
    for (&sv, gv) in s.iter().zip(g.iter()) {
        let sv = sv as u128;
        for j in 0..D {
            acc[j] += sv * gv[j] as u128;
        }
    }
    let mut out = [0u64; D];
    for j in 0..D {
        out[j] = (acc[j] % q as u128) as u64;
    }
    out
}

#[cfg(target_arch = "x86_64")]
mod psi_avx2 {
    use super::{PsiMacParams, D};
    use core::arch::x86_64::*;

    /// `vpmuludq` as one opaque instruction (lane I's finding: through the
    /// intrinsic LLVM re-lowers the loop-invariant broadcast operand as a
    /// 64-bit multiply idiom).
    #[target_feature(enable = "avx2")]
    #[inline]
    unsafe fn mul32(a: __m256i, b: __m256i) -> __m256i {
        let r: __m256i;
        unsafe {
            core::arch::asm!(
                "vpmuludq {r}, {a}, {b}",
                r = lateout(ymm_reg) r,
                a = in(ymm_reg) a,
                b = in(ymm_reg) b,
                options(pure, nomem, nostack, preserves_flags)
            );
        }
        r
    }

    /// acc[o + 4i ..] += (b_i mod 2^32) + c32 * (b_i >> 32) for the 8
    /// burst vectors of one 32-lane quarter.
    #[target_feature(enable = "avx2")]
    #[inline]
    unsafe fn fold_burst(acc: *mut u64, b: &[__m256i; 8], m32: __m256i, c32v: __m256i) {
        unsafe {
            for i in 0..8 {
                let lo = _mm256_and_si256(b[i], m32);
                let hi = _mm256_srli_epi64::<32>(b[i]);
                let f = _mm256_add_epi64(lo, mul32(c32v, hi));
                let p = acc.add(4 * i) as *mut __m256i;
                _mm256_storeu_si256(p, _mm256_add_epi64(_mm256_loadu_si256(p), f));
            }
        }
    }

    /// out[j] = (sum_t s[t] * g[t][j]) mod q, canonical — see the section
    /// note for the bounds. `g[t]` points at D canonical u64 lanes.
    #[target_feature(enable = "avx2")]
    pub unsafe fn mac_mod_q(s: &[u64], g: &[*const u64], p: &PsiMacParams, out: &mut [u64; D]) {
        unsafe {
            let n = s.len();
            let mut acc = [0u64; D];
            let m32 = _mm256_set1_epi64x(0xFFFF_FFFFu64 as i64);
            let c32v = _mm256_set1_epi64x(p.c32 as i64);
            let zero = _mm256_setzero_si256();
            for quarter in 0..4 {
                let o = quarter * 32;
                let mut b = [zero; 8];
                let mut cnt = 0usize;
                for t in 0..n {
                    let sv = _mm256_set1_epi64x(s[t] as i64);
                    let gp = g[t].add(o);
                    for i in 0..8 {
                        let gv = _mm256_loadu_si256(gp.add(4 * i) as *const __m256i);
                        b[i] = _mm256_add_epi64(b[i], mul32(sv, gv));
                    }
                    cnt += 1;
                    if cnt == 4 {
                        fold_burst(acc.as_mut_ptr().add(o), &b, m32, c32v);
                        b = [zero; 8];
                        cnt = 0;
                    }
                }
                if cnt > 0 {
                    fold_burst(acc.as_mut_ptr().add(o), &b, m32, c32v);
                }
            }
            // Finalize: fold by 2^31 == c31 twice, then one conditional
            // subtract -> canonical.
            let m31 = _mm256_set1_epi64x(0x7FFF_FFFFu64 as i64);
            let c31v = _mm256_set1_epi64x(p.c31 as i64);
            let qm1 = _mm256_set1_epi64x((p.q - 1) as i64);
            let qv = _mm256_set1_epi64x(p.q as i64);
            for j in (0..D).step_by(4) {
                let x = _mm256_loadu_si256(acc.as_ptr().add(j) as *const __m256i);
                let x = _mm256_add_epi64(_mm256_and_si256(x, m31), mul32(c31v, _mm256_srli_epi64::<31>(x)));
                let x = _mm256_add_epi64(_mm256_and_si256(x, m31), mul32(c31v, _mm256_srli_epi64::<31>(x)));
                // x < 2q < 2^32: signed compare is exact.
                let ge = _mm256_cmpgt_epi64(x, qm1);
                let x = _mm256_sub_epi64(x, _mm256_and_si256(ge, qv));
                _mm256_storeu_si256(out.as_mut_ptr().add(j) as *mut __m256i, x);
            }
        }
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

/// A Send/Sync copy of one kernel (Rc -> owned) so the generic
/// (misaligned-tensor) per-value-ring work can run on the thread pool.
struct KerSync {
    scale: KElem,
    row: Vec<KElem>,
    col: Vec<KElem>,
}

fn kers_sync(kers: &[&MultiClaimKernel]) -> Vec<KerSync> {
    kers.iter()
        .map(|k| KerSync { scale: k.scale.clone(), row: (*k.row_kernel).clone(), col: (*k.col_kernel).clone() })
        .collect()
}

/// `kw_row_multi` over the Sync copies (identical arithmetic).
/// [UPERF2-E] This was the per-value-ring body of both generic
/// (misaligned) branches before the hoisted form below replaced it;
/// kept verbatim as the pre-change reference (`kw_value_row_sync_ref`
/// exposes it to the `uperf-e diff-battery`).
fn kw_row_sync(kf: &KField, t: &AggTensor, kers: &[KerSync], vr: usize) -> Vec<KElem> {
    let mut out = vec![kf.zero(); D];
    let n = t.n_values();
    for ker in kers {
        for (c1, o) in out.iter_mut().enumerate() {
            let f = vr * D + c1;
            if f < n {
                let w = kf.mul(&ker.row[f / t.cols], &ker.col[f % t.cols]);
                *o = kf.add(o, &kf.mul(&ker.scale, &w));
            }
        }
    }
    out
}

/// [UPERF2-E] The HOISTED K-weight row of a misaligned tensor (the BK
/// aux tensors: cols = 16, ~4 x depth mask-opening kernels per tensor
/// whose row kernels are nonzero on ONE coefficient block each). Per
/// kernel, once: scol[c] = scale *_K col[c] (cols K-mults) and the
/// nonzero row-kernel bounds [lo, hi). Per value ring: one K-mult per
/// (kernel, c1) whose row factor is nonzero — instead of two K-mults per
/// (kernel, c1) for every kernel (`kw_row_sync`: 128 x n_kernels x 2 per
/// value ring; 7.3 s of the 3x16 prove's kernel passes and 3.5 s of its
/// verify sat here). Identical values: K is a field, so
/// scale *_K (row *_K col) = row *_K (scale *_K col) with canonical
/// coordinates, and every skipped term is an exact zero (0 *_K x = 0,
/// o + 0 = o); the per-c1 sums run in the same kernel order.
struct KwHoistKer {
    scol: Vec<KElem>,
    row: Vec<KElem>,
    lo: usize,
    hi: usize,
}

struct KwHoist {
    cols: usize,
    n_values: usize,
    kers: Vec<KwHoistKer>,
}

fn kw_hoist(kf: &KField, t: &AggTensor, kers: &[&MultiClaimKernel]) -> KwHoist {
    let cols = t.cols;
    let n_values = t.n_values();
    let n_rows_used = if cols == 0 { 0 } else { n_values.div_ceil(cols) };
    let kers = kers
        .iter()
        .map(|k| {
            // [UPERF2-M] the fold-reduced K-mult (== kf.mul), parallel over cols.
            let qf = QFold::new(kf.zq.q);
            let n_c = cols.min(k.col_kernel.len());
            let colk: &[KElem] = &k.col_kernel;
            let scale: &KElem = &k.scale;
            let scol: Vec<KElem> = map_ordered_min(n_c, MAP_MIN_PAR, |c| kmul_fast(kf, &qf, scale, &colk[c]));
            let row: Vec<KElem> = (*k.row_kernel).clone();
            // Rows [0, n_rows_used) are the ones the reference indexes
            // (row_kernel[f / cols] for every f < n_values) — a short row
            // kernel panics here as it would there.
            let used = n_rows_used;
            let lo = (0..used).find(|&r| !kf.is_zero(&row[r])).unwrap_or(used);
            let hi = (lo..used).rev().find(|&r| !kf.is_zero(&row[r])).map(|r| r + 1).unwrap_or(lo);
            KwHoistKer { scol, row, lo, hi }
        })
        .collect();
    KwHoist { cols, n_values, kers }
}

fn kw_row_hoisted(kf: &KField, h: &KwHoist, vr: usize) -> Vec<KElem> {
    let mut out = vec![kf.zero(); D];
    let f0 = vr * D;
    if f0 >= h.n_values || h.cols == 0 {
        return out;
    }
    let f1 = (f0 + D).min(h.n_values);
    let qf = QFold::new(kf.zq.q); // [UPERF2-M] fold-reduced K-mult (== kf.mul)
    for ker in &h.kers {
        // rows [lo, hi) <=> f in [lo*cols, hi*cols); intersect with [f0, f1).
        let (a, b) = (f0.max(ker.lo * h.cols), f1.min(ker.hi * h.cols));
        if a >= b {
            continue;
        }
        for f in a..b {
            let rk = &ker.row[f / h.cols];
            if rk.iter().all(|&x| x == 0) {
                continue;
            }
            let c1 = f - f0;
            out[c1] = kf.add(&out[c1], &kmul_fast(kf, &qf, rk, &ker.scol[f % h.cols]));
        }
    }
    out
}

/// [UPERF2-E] Battery entry: the pre-change generic K-weight row of value
/// ring `vr` of tensor `t` under `kers` (`kw_row_sync` verbatim).
pub fn kw_value_row_sync_ref(kf: &KField, t: &AggTensor, kers: &[&MultiClaimKernel], vr: usize) -> Vec<KElem> {
    let ks = kers_sync(kers);
    kw_row_sync(kf, t, &ks, vr)
}

/// [UPERF2-E] Battery entry: the hoisted K-weight row (what both generic
/// branches now run per value ring).
pub fn kw_value_row_hoisted(kf: &KField, t: &AggTensor, kers: &[&MultiClaimKernel], vr: usize) -> Vec<KElem> {
    let h = kw_hoist(kf, t, kers);
    kw_row_hoisted(kf, &h, vr)
}

/// [UPERF2-E] Bench entry: every value ring's hoisted K-weight row with ONE
/// hoist per tensor (what the branches do); the per-call entry above
/// rebuilds the hoist per value ring.
pub fn kw_value_rows_hoisted_all(kf: &KField, t: &AggTensor, kers: &[&MultiClaimKernel]) -> Vec<Vec<KElem>> {
    let h = kw_hoist(kf, t, kers);
    (0..t.n_value_rings()).map(|vr| kw_row_hoisted(kf, &h, vr)).collect()
}

/// [UPERF2-E] Battery entry: the per-ring reference row (`kw_row_multi`).
pub fn kw_value_row_ref(kf: &KField, t: &AggTensor, kers: &[&MultiClaimKernel], vr: usize) -> Vec<KElem> {
    kw_row_multi(kf, t, kers, vr)
}

/// conj-packed claim-row polys of one digit ring from its value-row
/// K-weights (radix-scaled) — `pass_agg::bpolys_from_kw` verbatim.
fn bpolys_from_kw_local(zq: &Zq, kw: &[KElem], radix: u64) -> Vec<Poly> {
    let mut rows = vec![poly_zero(); K_DEG];
    let qf = QFold::new(zq.q); // [UPERF2-M] fold-reduced mulmod (== zq.mul)
    for (c1, w) in kw.iter().enumerate() {
        for (cd, row) in rows.iter_mut().enumerate() {
            row[c1] = qf.mulmod(radix, w[cd]);
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
    kernel_pass_factored_gen::<[Vec<i64>]>(ctx, kf, group, kernels, w0, alphas)
}

/// [UPERF2-F] `kernel_pass_factored` over either small-ring store for the
/// rows pass's witness (the body; the phi pass does not read w0).
pub fn kernel_pass_factored_gen<B: SmallRings + ?Sized>(
    ctx: &RingCtx,
    kf: &KField,
    group: &AggGroup,
    kernels: &[MultiClaimKernel],
    w0: Option<&B>,
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
        if oracle_mode() {
            // ZK_UPERF_ORACLE=1: the per-DIGIT-ring reference (kw row +
            // bpolys + Karatsuba per limb, the pre-O5 `bg_kernel_pass`
            // arithmetic).
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
                        let mut buf = [0i64; D];
                        let w = w0.expect("witness for the rows pass").ring(u, &mut buf);
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
        if t.cols % D != 0 {
            // Misaligned (the BK aux tensors, cols = 16): per VALUE ring
            // the K-weight row once and the radix-1 products once —
            // phi_(vr,limb) = radix_limb * PHI_vr, and the rows pass uses
            // the value ring recomposed mod q (sum_limb radix_limb * w)
            // against the radix-1 bpolys. Identical mod q to the per-limb
            // reference above (radix is a scalar), 16x fewer ring-mults
            // and K-mults at l0 = 16.
            let _te = prof::timer(prof::E_KPASS_SMALL); // [UPERF2-E] observation only
            // [UPERF2-E] the hoisted K-weight rows (kw_hoist / kw_row_hoisted:
            // scaled col kernels + nonzero row bounds once per kernel);
            // the pre-change per-value-ring body is `kw_row_sync`.
            let ks = kw_hoist(kf, t, &kers);
            if phi_mode {
                // [UPERF2-F] the per-tensor phi rings of a small-cols tensor
                // (the same body, shared with `Phi0Source`).
                phi.extend(phi_small_cols_tensor(ctx, kf, t, &ks, alphas.unwrap(), &radixes));
                continue;
            }
            let mut vr0 = 0;
            const VR_BLOCK_M: usize = 1024;
            while vr0 < n_vr {
                let vr1 = (vr0 + VR_BLOCK_M).min(n_vr);
                {
                    let w0 = w0.expect("witness for the rows pass");
                    let one_vr = |vr: usize| -> Option<Vec<Poly>> {
                        // V_vr = sum_limb radix_limb * w — exact, then mod q.
                        let mut v_ring = vec![0i128; D];
                        let mut any = false;
                        let mut buf = [0i64; D];
                        for (limb, &radix) in radixes.iter().enumerate() {
                            let w = w0.ring(t.digit_ring_base + vr * t.l0 + limb, &mut buf);
                            for j in 0..D {
                                if w[j] != 0 {
                                    any = true;
                                    v_ring[j] += radix as i128 * w[j] as i128;
                                }
                            }
                        }
                        if !any {
                            return None;
                        }
                        let kw = kw_row_hoisted(kf, &ks, vr);
                        if kw.iter().all(|k| kf.is_zero(k)) {
                            return None;
                        }
                        let v_modq: Poly = v_ring.iter().map(|&x| super::aux::mod_q_i128(x, q)).collect();
                        let bp = bpolys_from_kw_local(zq, &kw, 1);
                        Some(bp.iter().map(|b| ring_mul_split_kara_fast(ctx, b, &v_modq)).collect())
                    };
                    let blocks: Vec<Option<Vec<Poly>>> = pooled(|| {
                        use rayon::prelude::*;
                        if threads() > 1 { (vr0..vr1).into_par_iter().map(one_vr).collect() } else { (vr0..vr1).map(one_vr).collect() }
                    });
                    for rows in blocks.into_iter().flatten() {
                        for (c, row) in b_rows.iter_mut().enumerate() {
                            *row = poly_add(zq, row, &rows[c]);
                        }
                    }
                }
                vr0 = vr1;
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
                let mut buf = [0i64; D];
                for vr in lo..hi {
                    let (row, cb) = (vr / nb, vr % nb);
                    // V_vr = sum_limb radix_limb * w — exact, then mod q.
                    v_ring.iter_mut().for_each(|x| *x = 0);
                    let mut any = false;
                    for (limb, &radix) in radixes.iter().enumerate() {
                        let w = w0.ring(t.digit_ring_base + vr * t.l0 + limb, &mut buf);
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

// ---------------------------------------------------------------------------
// [UPERF2-C] The eval-proof leftovers (U-PERF2 lane C): the quinary fold
// (T7), the transport levels' general x general products (T3b), the
// prover's compute_psi, and the per-ring digit splits — the last hot
// loops of the composed eval proof still written on `poly_mul_small` /
// `ring_mul_split_kara_fast`. Same discipline as Phase 0: exact-integer
// evaluation in the Goldilocks NTT domain (aux_ntt_core), the pre-change
// body kept as `*_ref`, `oracle_mode()` honored at every entry point,
// threads only over INDEPENDENT outputs (rayon's indexed collect keeps
// output order; every output is computed whole by one thread from the
// same term list), so every result is bit-identical for any ZK_THREADS.
//
// The exact identities each item relies on (all sum regroupings in the
// exact integers or in Z_q — the wire cannot move):
//
//   T7   z_u = sum_j c_j (x) w_{j,u}  over Z (negacyclic; |c| <= 2,
//        |w| <= 2^(e-1) <= 64): every coefficient of the true integer
//        result is bounded by r * D * cmax * wmax (<= 2^21 in the composed
//        pass; checked exactly against (p-1)/2 from the DATA bounds — the
//        oracle runs when it does not fit), so its image mod p determines
//        it and `center_from_p` recovers it exactly.
//   T3b  in Z_q, with radix a scalar and c_j small:
//          a * (radix * X)        = radix * (a * X)
//          a * (-radix * c_j)     = (-radix) * (a * c_j)
//          a * (const radix)      = radix * a
//        so a next-witness ring is a scalar multiple of a per-SOURCE ring:
//          Z-ring (src, limb) = radix_limb * S[src],
//            S[src]  = a_l1 * psi[src] + sum_kap a_t4[kap] * A[kap][src]
//          T-ring (j, kap, limb) = (-radix_limb) * (a_t4[kap] * c_j)
//                                  + T5[pos]
//          H-ring (pair, limb)   = [j = k] radix_limb * a_t1
//                                  + (-radix_limb) * (a_l1 * cpair[pair])
//                                  + T5[pos]
//          T5[pos] = sum_kap2 a_t5[bi][kap2] * B_bi[kap2][pos - col_base]
//        S and T5 are GEMV-shaped contractions of a few FIXED alphas
//        against GENERAL mod-q operands: `ntt_combine_general` (below)
//        evaluates them in the NTT domain under the limb-split contract
//        (both limbs bounded, sub-products exact by capacity, recompose
//        mod q — the `A1LimbCommitKernel` precedent). The two small-
//        operand product families ride `ntt_gemm_modq_small`.
//   psi  Psi_u = sum_k c_k * phi[k*chunk + u]: small x general, r terms —
//        the single-prime window (`ntt_window_terms(q, |c|max)`) covers
//        r <= 64 at both moduli with the oracle as the over-capacity
//        fallback.

/// Ordered parallel map: out[u] = f(u) for u in 0..n on the kernel pool
/// when threads() > 1 (rayon's indexed collect preserves order), inline
/// otherwise. Every f(u) is independent exact work — identical for any
/// ZK_THREADS.
fn map_ordered<T: Send>(n: usize, f: impl Fn(usize) -> T + Sync + Send) -> Vec<T> {
    map_ordered_min(n, 1, f)
}

/// [UPERF2-M] Below `min_par` items the map runs inline (a rayon fork/join
/// per call costs tens of microseconds — the K-mult hoists are called tens
/// of thousands of times on 16-row tensors at small T). Same values.
const MAP_MIN_PAR: usize = 256;

fn map_ordered_min<T: Send>(n: usize, min_par: usize, f: impl Fn(usize) -> T + Sync + Send) -> Vec<T> {
    if threads() > 1 && n >= min_par {
        pooled(|| {
            use rayon::prelude::*;
            (0..n).into_par_iter().map(f).collect()
        })
    } else {
        (0..n).map(f).collect()
    }
}

/// s * p over R_q, exact (== `poly_scale`): the u64 product path when q
/// < 2^32 (x, s < q so x*s < 2^64), the u128 path otherwise.
fn scale_exact(zq: &Zq, p: &[u64], s: u64) -> Poly {
    let q = zq.q;
    if q < (1u64 << 32) {
        p.iter().map(|&x| (x * s) % q).collect()
    } else {
        p.iter().map(|&x| ((x as u128 * s as u128) % q as u128) as u64).collect()
    }
}

/// Forward transform of a SMALL integer ring (|v| < p/2).
#[inline]
fn fwd_small(ring: &[i64], t: &super::aux::NttTables) -> [u64; D] {
    let mut f = [0u64; D];
    for i in 0..D {
        f[i] = super::aux::lift_to_p(ring[i]);
    }
    super::aux::ntt_fwd_best(&mut f, t);
    f
}

/// Forward transform of a mod-q ring through its balanced representative.
#[inline]
fn fwd_modq(ring: &[u64], q: u64, t: &super::aux::NttTables) -> [u64; D] {
    let mut f = [0u64; D];
    for i in 0..D {
        f[i] = super::aux::lift_to_p(super::aux::balanced_mod_q(ring[i], q));
    }
    super::aux::ntt_fwd_best(&mut f, t);
    f
}

/// Limb-split forward transforms of a mod-q ring at limb base l:
/// [lo, hi, lo + hi] (the mid transform by linearity, in-domain).
#[inline]
fn fwd_modq_limbs(ring: &[u64], q: u64, l: u32, t: &super::aux::NttTables) -> [[u64; D]; 3] {
    use super::aux::{balanced_mod_q, gl_add, lift_to_p, ntt_fwd_best, split_limbs};
    let mut lo = [0u64; D];
    let mut hi = [0u64; D];
    let mut mid = [0u64; D];
    for i in 0..D {
        let (lv, hv) = split_limbs(balanced_mod_q(ring[i], q), l);
        lo[i] = lift_to_p(lv);
        hi[i] = lift_to_p(hv);
    }
    ntt_fwd_best(&mut lo, t);
    ntt_fwd_best(&mut hi, t);
    for i in 0..D {
        mid[i] = gl_add(lo[i], hi[i]);
    }
    [lo, hi, mid]
}

/// Split-halves MAC of one NTT-domain product into (lo, hi) u128
/// accumulators (the A1 discipline; exact for < 2^31 terms).
#[cfg(not(target_arch = "x86_64"))]
#[inline(always)]
fn mac_split(acc_lo: &mut [u128; D], acc_hi: &mut [u128; D], a: &[u64; D], b: &[u64; D]) {
    for k in 0..D {
        let prod = a[k] as u128 * b[k] as u128;
        acc_lo[k] += prod as u64 as u128;
        acc_hi[k] += (prod >> 64) as u128;
    }
}

/// Leave the NTT domain: the exact Z_p image of the accumulated sum
/// (standard order).
#[cfg(not(target_arch = "x86_64"))]
#[inline]
fn flush_split(acc_lo: &[u128; D], acc_hi: &[u128; D], t: &super::aux::NttTables) -> [u64; D] {
    use super::aux::{gl_reduce128, ntt_inv_best, EPS};
    let mut v = [0u64; D];
    for k in 0..D {
        v[k] = gl_reduce128(acc_lo[k] + EPS as u128 * acc_hi[k]);
    }
    ntt_inv_best(&mut v, t);
    v
}

// [UPERF2-M] THE NTT-DOMAIN ACCUMULATOR. Every NTT-domain kernel of this
// file accumulates ring products a-hat (.) b-hat over a term list and then
// leaves the domain once (inverse transform) — the exact-integer contract
// of each kernel bounds the TRUE integer the Z_p image determines, so ANY
// correct Z_p accumulation gives the same image. Two bodies, one API:
//   * x86_64: CANONICAL u64 lanes, acc[j] = (acc[j] + a[j] b[j]) mod p by
//     the AVX2 `gl_mac_lanes_avx2` (lane I's `mul`/`add`: 4 x u64 lanes,
//     four `vpmuludq` partial products, the same reduce identity) when
//     detected and `ZK_NTTMAC` != 0, else the scalar `gl_add(acc,
//     gl_mul(a, b))` — both return the canonical representative of the
//     same field element; the flush is the inverse transform of the
//     canonical vector;
//   * elsewhere (the Mac): the pre-change split-halves u128 pair (lo/hi
//     sums, `gl_reduce128(lo + EPS hi)` at the flush) — verbatim.
// Canonical representatives are unique, so the flushed image is
// identical on every body — the batteries (uperf-c fold/psi/combine/
// transport, uperf-f, uperf-pc E2E, uperf-m) are the witnesses; the
// kernels' oracles remain their Karatsuba `_ref` bodies.

/// [UPERF2-M] `ZK_NTTMAC=0` forces the scalar canonical MAC on x86_64
/// (default: AVX2 when detected). Read once.
#[cfg(target_arch = "x86_64")]
static NTT_MAC_SIMD: LazyLock<bool> = LazyLock::new(|| {
    let knob = std::env::var("ZK_NTTMAC").map(|v| v != "0").unwrap_or(true);
    knob && super::aux::simd_ntt_available()
});

#[cfg(target_arch = "x86_64")]
#[inline(always)]
pub fn ntt_mac_simd_enabled() -> bool {
    *NTT_MAC_SIMD
}

#[cfg(not(target_arch = "x86_64"))]
#[inline(always)]
pub fn ntt_mac_simd_enabled() -> bool {
    false
}

/// The NTT-domain accumulator (see the note above): x86_64 canonical lanes.
#[cfg(target_arch = "x86_64")]
#[derive(Clone, Copy)]
pub struct NttAcc {
    v: [u64; D],
}

#[cfg(target_arch = "x86_64")]
impl NttAcc {
    #[inline(always)]
    pub fn new() -> Self {
        NttAcc { v: [0u64; D] }
    }
    #[inline(always)]
    pub fn reset(&mut self) {
        self.v = [0u64; D];
    }
    /// acc += a (.) b in Z_p (canonical lanes).
    #[inline(always)]
    pub fn mac(&mut self, a: &[u64; D], b: &[u64; D]) {
        if ntt_mac_simd_enabled() {
            super::aux::gl_mac_lanes_avx2(&mut self.v, a, b);
        } else {
            super::aux::gl_mac_lanes_scalar(&mut self.v, a, b);
        }
    }
    /// Leave the NTT domain: the exact Z_p image of the accumulated sum
    /// (standard order).
    #[inline]
    pub fn flush(&self, t: &super::aux::NttTables) -> [u64; D] {
        let mut v = self.v;
        super::aux::ntt_inv_best(&mut v, t);
        v
    }
}

/// The NTT-domain accumulator: the pre-change split-halves u128 pair
/// (non-x86 targets).
#[cfg(not(target_arch = "x86_64"))]
#[derive(Clone, Copy)]
pub struct NttAcc {
    lo: [u128; D],
    hi: [u128; D],
}

#[cfg(not(target_arch = "x86_64"))]
impl NttAcc {
    #[inline(always)]
    pub fn new() -> Self {
        NttAcc { lo: [0u128; D], hi: [0u128; D] }
    }
    #[inline(always)]
    pub fn reset(&mut self) {
        self.lo = [0u128; D];
        self.hi = [0u128; D];
    }
    #[inline(always)]
    pub fn mac(&mut self, a: &[u64; D], b: &[u64; D]) {
        mac_split(&mut self.lo, &mut self.hi, a, b);
    }
    #[inline]
    pub fn flush(&self, t: &super::aux::NttTables) -> [u64; D] {
        flush_split(&self.lo, &self.hi, t)
    }
}

impl Default for NttAcc {
    fn default() -> Self {
        NttAcc::new()
    }
}

// ---- T7: the quinary fold. ----

/// [UPERF2-C T7] The exact i64 fold z_u = sum_j c_j * w[j][u] over Z
/// (negacyclic) for u in 0..chunk — the level fold of `bg_fold` /
/// `agg_fold` — in the Goldilocks NTT domain: c transformed once, each w
/// ring once, r-term pointwise MAC, one inverse and `center_from_p` per
/// output. Capacity r * D * cmax * wmax <= (p-1)/2 is checked EXACTLY
/// from the data bounds; otherwise (never in the composed pass: quinary
/// c, |w| <= 64) the oracle `fold_chunks_ref` runs. Threads over u.
/// Bit-identical to the oracle (uperf-c diff-battery leg T7).
pub fn fold_chunks_ntt(cs: &[Vec<i64>], w: &[&[Vec<i64>]], chunk: usize) -> Vec<Vec<i64>> {
    fold_chunks_ntt_gen::<[Vec<i64>]>(cs, w, chunk)
}

/// [UPERF2-F] `fold_chunks_ntt` over either small-ring store (the body).
pub fn fold_chunks_ntt_gen<B: SmallRings + ?Sized>(cs: &[Vec<i64>], w: &[&B], chunk: usize) -> Vec<Vec<i64>> {
    use super::aux::{capacity, center_from_p};
    let r = cs.len();
    assert_eq!(w.len(), r, "one w slice per fold challenge");
    for s in w {
        assert_eq!(s.n_rings(), chunk, "w slice length");
    }
    if oracle_mode() {
        return fold_chunks_ref_gen(cs, w, chunk);
    }
    if r == 0 || chunk == 0 {
        return vec![vec![0i64; D]; chunk];
    }
    let cmax: u128 = cs.iter().flat_map(|c| c.iter()).map(|&x| x.unsigned_abs() as u128).max().unwrap_or(0);
    let wmax: u128 = w.iter().map(|s| s.max_abs()).max().unwrap_or(0);
    // (bounds beyond 2^48 are outside every designed regime — quinary c,
    // digits |w| <= 64 — and could overflow the u128 capacity product:
    // straight to the oracle)
    if cmax >= (1u128 << 48) || wmax >= (1u128 << 48) {
        return fold_chunks_ref_gen(cs, w, chunk);
    }
    let (fits, _) = capacity(r as u128, cmax.max(1), wmax.max(1));
    if !fits {
        return fold_chunks_ref_gen(cs, w, chunk);
    }
    let _tm = prof::timer(prof::M_FOLD_NTT); // [UPERF2-M] observation only
    let t = &*NTT;
    let c_hat: Vec<[u64; D]> = cs.iter().map(|c| fwd_small(c, t)).collect();
    let one = |u: usize| -> Vec<i64> {
        let mut acc = NttAcc::new(); // [UPERF2-M]
        let mut any = false;
        let mut buf = [0i64; D];
        for j in 0..r {
            let ring = w[j].ring(u, &mut buf);
            if ring.iter().all(|&x| x == 0) {
                continue;
            }
            any = true;
            let f = fwd_small(ring, t);
            acc.mac(&f, &c_hat[j]);
        }
        if !any {
            return vec![0i64; D];
        }
        let v = acc.flush(t);
        v.iter().map(|&x| center_from_p(x) as i64).collect()
    };
    map_ordered(chunk, one)
}

/// The pre-[UPERF2-C] fold loop (`poly_mul_small` per (j, u) term,
/// exact i64 accumulation) — the T7 oracle.
pub fn fold_chunks_ref(cs: &[Vec<i64>], w: &[&[Vec<i64>]], chunk: usize) -> Vec<Vec<i64>> {
    fold_chunks_ref_gen::<[Vec<i64>]>(cs, w, chunk)
}

/// [UPERF2-F] `fold_chunks_ref` over either small-ring store.
pub fn fold_chunks_ref_gen<B: SmallRings + ?Sized>(cs: &[Vec<i64>], w: &[&B], chunk: usize) -> Vec<Vec<i64>> {
    let r = cs.len();
    assert_eq!(w.len(), r);
    let mut buf = [0i64; D];
    (0..chunk)
        .map(|u| {
            let mut z = vec![0i64; D];
            for (j, c) in cs.iter().enumerate() {
                let prod = poly_mul_small(c, w[j].ring(u, &mut buf));
                for (a, p) in z.iter_mut().zip(prod.iter()) {
                    *a += p;
                }
            }
            z
        })
        .collect()
}

// ---- The parallel digit splits. ----

/// `decompose_poly_modq` over a list of rings, ring order preserved (the
/// flat limb-major-per-ring output the callers `extend` into), computed
/// in parallel per ring when threads() > 1. Identical to the serial loop.
pub fn decompose_polys_modq(zq: &Zq, polys: &[Poly], e: u32, l: usize) -> Vec<Vec<i64>> {
    let per: Vec<Vec<Vec<i64>>> = map_ordered(polys.len(), |i| decompose_poly_modq(zq, &polys[i], e, l));
    let mut out = Vec::with_capacity(polys.len() * l);
    for d in per {
        out.extend(d);
    }
    out
}

/// `decompose_poly_small` over a list of small rings, ring order
/// preserved, in parallel per ring when threads() > 1.
pub fn decompose_polys_small(polys: &[Vec<i64>], e: u32, l: usize) -> Vec<Vec<i64>> {
    let per: Vec<Vec<Vec<i64>>> = map_ordered(polys.len(), |i| decompose_poly_small(&polys[i], e, l));
    let mut out = Vec::with_capacity(polys.len() * l);
    for d in per {
        out.extend(d);
    }
    out
}

// ---- compute_psi. ----

/// [UPERF2-C] NTT-domain `compute_psi`: c_k transformed once, per output
/// u the r in-range phi rings transformed once and MAC'd against c-hat,
/// one inverse; exact by the single-prime window (r <= window(q, |c|max);
/// the oracle runs otherwise). Threads over u.
pub fn compute_psi_ntt(ctx: &RingCtx, phi: &[Poly], chunk: usize, c: &[Vec<i64>]) -> Vec<Poly> {
    use super::aux::{center_from_p, mod_q_centered};
    let q = ctx.zq.q;
    let r = c.len();
    if r == 0 || chunk == 0 {
        return vec![poly_zero(); chunk];
    }
    let s_max: u128 = c.iter().flat_map(|ck| ck.iter()).map(|&x| x.unsigned_abs() as u128).max().unwrap_or(0);
    let window = ntt_window_terms(q, s_max);
    if window < r {
        return compute_psi_ref(ctx, phi, chunk, c);
    }
    let t = &*NTT;
    let c_hat: Vec<[u64; D]> = c.iter().map(|ck| fwd_small(ck, t)).collect();
    let one = |u: usize| -> Poly {
        let mut acc = NttAcc::new(); // [UPERF2-M]
        let mut any = false;
        for k in 0..r {
            let idx = k * chunk + u;
            if idx >= phi.len() {
                break;
            }
            let ring = &phi[idx];
            if ring.iter().all(|&x| x == 0) {
                continue;
            }
            any = true;
            let f = fwd_modq(ring, q, t);
            acc.mac(&f, &c_hat[k]);
        }
        if !any {
            return poly_zero();
        }
        let v = acc.flush(t);
        v.iter().map(|&x| mod_q_centered(center_from_p(x), q)).collect()
    };
    map_ordered(chunk, one)
}

// ---- T3b: the transport's general x general contractions. ----

/// [UPERF2-C T3b] out[u] = sum_i alphas[i] * ops[i][u] over R_q for u in
/// 0..m — n FIXED mod-q rings against n slices of m GENERAL mod-q rings,
/// in the limb-split NTT domain. Two exact regimes, chosen by the
/// capacity contract for the term count n (never by data):
///   ONE-SIDED (fits at q31 for n <= 2048): only the alphas are split,
///     a = a1 2^L + a0 (balanced limbs at L = limb_bits(q)); per operand
///     ONE forward transform; two in-domain accumulations a0*b, a1*b
///     (each exact: n * D * limb * (q-1)/2 <= (p-1)/2); two inverses;
///     out = V0 + 2^L V1 mod q.
///   TWO-SIDED (fits at q46 for n <= 1024): both split, 3 Karatsuba
///     sub-products (P0, P2, PM = (a0+a1)(b0+b1); the mid transform by
///     linearity), 3 inverses, out = P0 + 2^L (PM - P0 - P2) + 2^2L P2
///     mod q — the `A1LimbCommitKernel` contract.
/// If neither fits the oracle `ntt_combine_general_ref` runs. Threads
/// over u. Bit-identical to the oracle (uperf-c diff-battery leg T3b).
pub fn ntt_combine_general(ctx: &RingCtx, alphas: &[Poly], ops: &[&[Poly]], m: usize) -> Vec<Poly> {
    use super::aux::{capacity, center_from_p, limb_bits, mod_q_centered, mul_q};
    let q = ctx.zq.q;
    let n = alphas.len();
    assert_eq!(ops.len(), n, "one operand slice per alpha");
    for o in ops {
        assert_eq!(o.len(), m, "operand slice length");
    }
    if oracle_mode() || n == 0 || m == 0 {
        return ntt_combine_general_ref(ctx, alphas, ops, m);
    }
    let l = limb_bits(q);
    let a_lo = 1u128 << (l - 1);
    let a_hi = (((q as u128 - 1) / 2 + a_lo) >> l) + 1;
    let half_q = ((q - 1) / 2) as u128;
    let one_sided = capacity(n as u128, a_lo.max(a_hi), half_q).0;
    let two_sided = capacity(n as u128, a_lo + a_hi, a_lo + a_hi).0;
    if !one_sided && !two_sided {
        return ntt_combine_general_ref(ctx, alphas, ops, m);
    }
    let t = &*NTT;
    let a_hat: Vec<[[u64; D]; 3]> = alphas.iter().map(|a| fwd_modq_limbs(a, q, l, t)).collect();
    let two_l = (1u64 << l) % q;
    let two_2l = mul_q(two_l, two_l, q);
    let one = |u: usize| -> Poly {
        let mut acc = [NttAcc::new(); 3]; // [UPERF2-M]
        let mut any = false;
        for i in 0..n {
            let ring = &ops[i][u];
            if ring.iter().all(|&x| x == 0) {
                continue;
            }
            any = true;
            if one_sided {
                let f = fwd_modq(ring, q, t);
                acc[0].mac(&a_hat[i][0], &f);
                acc[1].mac(&a_hat[i][1], &f);
            } else {
                let oh = fwd_modq_limbs(ring, q, l, t);
                for s in 0..3 {
                    acc[s].mac(&a_hat[i][s], &oh[s]);
                }
            }
        }
        if !any {
            return poly_zero();
        }
        let p0 = acc[0].flush(t);
        let p1 = acc[1].flush(t);
        let mut out = poly_zero();
        if one_sided {
            for k in 0..D {
                let v0 = mod_q_centered(center_from_p(p0[k]), q);
                let v1 = mod_q_centered(center_from_p(p1[k]), q);
                out[k] = (v0 + mul_q(two_l, v1, q)) % q;
            }
        } else {
            let pm = acc[2].flush(t);
            for k in 0..D {
                let v0 = mod_q_centered(center_from_p(p0[k]), q);
                let v2 = mod_q_centered(center_from_p(p1[k]), q);
                let vm = mod_q_centered(center_from_p(pm[k]), q);
                let mid = (vm + 2 * q - v0 - v2) % q;
                out[k] = (v0 + mul_q(two_l, mid, q) + mul_q(two_2l, v2, q)) % q;
            }
        }
        out
    };
    map_ordered(m, one)
}

/// [UPERF2-M] `ntt_combine_general` with the operands drawn from a POOL:
/// out[u] = sum_i alphas[i] * pool[idx(i, u)] over R_q for u in 0..m —
/// the same two exact regimes (one-sided at q31, two-sided at q46, the
/// oracle when neither fits), the pool transformed ONCE (the operands of
/// `ntt_combine_general` are transformed per (i, u); when many (i, u)
/// share a ring — the G blocks: 256 (e, d1) cells over 32 distinct
/// rings — this saves the repeated transforms). Bit-identical to
/// `ntt_combine_general_ref` on the materialized operand table (the same
/// exact-integer contract; `uperf-m battery` leg C). Threads over u.
pub fn ntt_combine_pool(
    ctx: &RingCtx,
    alphas: &[Poly],
    pool: &[Poly],
    idx: &(dyn Fn(usize, usize) -> usize + Sync),
    m: usize,
) -> Vec<Poly> {
    ntt_combine_pool_impl(ctx, alphas, pool, idx, m, true)
}

/// The body; `par` = false runs inline (callers already inside a parallel
/// split — the G blocks are built block-parallel by `PhiFactored::new`).
fn ntt_combine_pool_impl(
    ctx: &RingCtx,
    alphas: &[Poly],
    pool: &[Poly],
    idx: &(dyn Fn(usize, usize) -> usize + Sync),
    m: usize,
    par: bool,
) -> Vec<Poly> {
    use super::aux::{capacity, center_from_p, limb_bits, mod_q_centered, mul_q};
    let q = ctx.zq.q;
    let n = alphas.len();
    let materialize = |ctx: &RingCtx| -> Vec<Poly> {
        let ops_store: Vec<Vec<Poly>> = (0..n).map(|i| (0..m).map(|u| pool[idx(i, u)].clone()).collect()).collect();
        let ops: Vec<&[Poly]> = ops_store.iter().map(|v| v.as_slice()).collect();
        ntt_combine_general_ref(ctx, alphas, &ops, m)
    };
    if oracle_mode() || n == 0 || m == 0 || pool.is_empty() {
        return materialize(ctx);
    }
    let l = limb_bits(q);
    let a_lo = 1u128 << (l - 1);
    let a_hi = (((q as u128 - 1) / 2 + a_lo) >> l) + 1;
    let half_q = ((q - 1) / 2) as u128;
    let one_sided = capacity(n as u128, a_lo.max(a_hi), half_q).0;
    let two_sided = capacity(n as u128, a_lo + a_hi, a_lo + a_hi).0;
    if !one_sided && !two_sided {
        return materialize(ctx);
    }
    let t = &*NTT;
    let a_hat: Vec<[[u64; D]; 3]> = alphas.iter().map(|a| fwd_modq_limbs(a, q, l, t)).collect();
    // The pool, transformed once (zero rings flagged).
    let pool_zero: Vec<bool> = pool.iter().map(|p| p.iter().all(|&x| x == 0)).collect();
    let pool_hat: Vec<[[u64; D]; 3]> = pool
        .iter()
        .map(|p| {
            if one_sided {
                [fwd_modq(p, q, t), [0u64; D], [0u64; D]]
            } else {
                fwd_modq_limbs(p, q, l, t)
            }
        })
        .collect();
    let two_l = (1u64 << l) % q;
    let two_2l = mul_q(two_l, two_l, q);
    let one = |u: usize| -> Poly {
        let mut acc = [NttAcc::new(); 3];
        let mut any = false;
        for i in 0..n {
            let pi = idx(i, u);
            if pool_zero[pi] {
                continue;
            }
            any = true;
            let ph = &pool_hat[pi];
            if one_sided {
                acc[0].mac(&a_hat[i][0], &ph[0]);
                acc[1].mac(&a_hat[i][1], &ph[0]);
            } else {
                for s in 0..3 {
                    acc[s].mac(&a_hat[i][s], &ph[s]);
                }
            }
        }
        if !any {
            return poly_zero();
        }
        let p0 = acc[0].flush(t);
        let p1 = acc[1].flush(t);
        let mut out = poly_zero();
        if one_sided {
            for k in 0..D {
                let v0 = mod_q_centered(center_from_p(p0[k]), q);
                let v1 = mod_q_centered(center_from_p(p1[k]), q);
                out[k] = (v0 + mul_q(two_l, v1, q)) % q;
            }
        } else {
            let pm = acc[2].flush(t);
            for k in 0..D {
                let v0 = mod_q_centered(center_from_p(p0[k]), q);
                let v2 = mod_q_centered(center_from_p(p1[k]), q);
                let vm = mod_q_centered(center_from_p(pm[k]), q);
                let mid = (vm + 2 * q - v0 - v2) % q;
                out[k] = (v0 + mul_q(two_l, mid, q) + mul_q(two_2l, v2, q)) % q;
            }
        }
        out
    };
    if par { map_ordered(m, one) } else { (0..m).map(one).collect() }
}

/// The Karatsuba oracle of `ntt_combine_general` (per output, n ring
/// products summed in alpha order).
pub fn ntt_combine_general_ref(ctx: &RingCtx, alphas: &[Poly], ops: &[&[Poly]], m: usize) -> Vec<Poly> {
    let zq = &ctx.zq;
    assert_eq!(ops.len(), alphas.len());
    (0..m)
        .map(|u| {
            let mut acc = poly_zero();
            for (a, o) in alphas.iter().zip(ops.iter()) {
                acc = poly_add(zq, &acc, &ring_mul_split_kara_fast(ctx, a, &o[u]));
            }
            acc
        })
        .collect()
}

/// [UPERF2-C T3b] The fast body of `transport_level_from_psi` — the
/// regrouped form of the module note above: the per-source rings S (Z
/// family), T5 (T and H families), a_t4[kap] * c_j (T family's T4 term)
/// and a_l1 * cpair (H family's L1 term) are computed ONCE each in the
/// NTT domain, then every next-witness ring is assembled as a fixed-
/// order mod-q sum of scalar multiples (radix and sign). h_next is the
/// reference sum (1 + kappa * n_bindings products — negligible).
#[allow(clippy::too_many_arguments)]
pub fn transport_level_from_psi_fast(
    ctx: &RingCtx,
    psi: &[Poly],
    h_target: &Poly,
    plan: &LevelPlan,
    layout: &NextLayout,
    a_mat: &[Poly],
    bindings: &[OuterBinding],
    c: &[Vec<i64>],
    alphas: &[Poly],
) -> LevelTransport {
    let zq = &ctx.zq;
    let chunk = plan.chunk;
    let r = c.len();
    assert_eq!(psi.len(), chunk);
    assert!(a_mat.len() >= KAPPA_AGG * chunk, "A_i is kappa x chunk");
    let n_rows = transport_rows(bindings.len());
    assert_eq!(alphas.len(), n_rows);
    let (a_t1, a_l1) = (&alphas[0], &alphas[1]);
    let a_t4 = &alphas[2..2 + KAPPA_AGG];
    let a_t5 = &alphas[2 + KAPPA_AGG..];
    for b in bindings {
        assert!(b.b_mat.len() >= KAPPA_AGG * b.cols, "B is kappa x cols");
    }
    // (i) S[src] = a_l1 * psi[src] + sum_kap a_t4[kap] * A[kap][src].
    let s_rings: Vec<Poly> = {
        let mut al: Vec<Poly> = Vec::with_capacity(1 + KAPPA_AGG);
        al.push(a_l1.clone());
        al.extend(a_t4.iter().cloned());
        let mut ops: Vec<&[Poly]> = Vec::with_capacity(1 + KAPPA_AGG);
        ops.push(psi);
        for kap in 0..KAPPA_AGG {
            ops.push(&a_mat[kap * chunk..(kap + 1) * chunk]);
        }
        ntt_combine_general(ctx, &al, &ops, chunk)
    };
    // (ii) T5_bi[rel] = sum_kap2 a_t5[bi][kap2] * B_bi[kap2][rel].
    let t5_rings: Vec<Vec<Poly>> = bindings
        .iter()
        .enumerate()
        .map(|(bi, b)| {
            let al = &a_t5[bi * KAPPA_AGG..(bi + 1) * KAPPA_AGG];
            let ops: Vec<&[Poly]> = (0..KAPPA_AGG).map(|k2| &b.b_mat[k2 * b.cols..(k2 + 1) * b.cols]).collect();
            ntt_combine_general(ctx, al, &ops, b.cols)
        })
        .collect();
    // (iii) P[kap * r + j] = a_t4[kap] * c_j (small operand).
    let p_rings: Vec<Poly> = {
        let a: Vec<&[Poly]> = a_t4.iter().map(std::slice::from_ref).collect();
        let b: Vec<&[Vec<i64>]> = c.iter().map(std::slice::from_ref).collect();
        ntt_gemm_modq_small(ctx, &a, &b, 1)
    };
    // (iv) Q[pair] = a_l1 * cpair[pair], cpair = c_j (x) c_k over Z (small).
    let cp_small: Vec<Vec<i64>> = {
        let mut v = Vec::with_capacity(r * (r + 1) / 2);
        for j in 0..r {
            for k in j..r {
                v.push(poly_mul_small(&c[j], &c[k]));
            }
        }
        v
    };
    let q_rings: Vec<Poly> = {
        let b: Vec<&[Vec<i64>]> = cp_small.iter().map(std::slice::from_ref).collect();
        ntt_gemm_modq_small(ctx, &[std::slice::from_ref(a_l1)], &b, 1)
    };
    // (v) Assemble every next-witness ring (fixed order: family term(s),
    // then the bindings in order — a mod-q sum, so identical to the
    // oracle's per-term accumulation).
    let t5_at = |pos: usize, acc: &mut Poly| {
        for (bi, b) in bindings.iter().enumerate() {
            if pos >= b.col_base && pos < b.col_base + b.cols {
                *acc = poly_add(zq, acc, &t5_rings[bi][pos - b.col_base]);
            }
        }
    };
    let e_next = plan.e_next as usize;
    let one = |u: usize| -> Poly {
        let (fam, src, limb) = layout.locate(u);
        match fam {
            Fam::Z => {
                let radix = zq.to_mod(1i64 << (e_next * limb));
                scale_exact(zq, &s_rings[src], radix)
            }
            Fam::T => {
                let (j, kap) = (src / KAPPA_AGG, src % KAPPA_AGG);
                let radix = 1i64 << (e_next * limb);
                let mut acc = scale_exact(zq, &p_rings[kap * r + j], zq.to_mod(-radix));
                t5_at(u - layout.t_base, &mut acc);
                acc
            }
            Fam::H => {
                let radix_u = zq.to_mod(1i64 << (e_next * limb));
                let (j, k) = pair_from_index(plan.r, src);
                let mut acc = if j == k { scale_exact(zq, a_t1, radix_u) } else { poly_zero() };
                acc = poly_add(zq, &acc, &scale_exact(zq, &q_rings[src], zq.neg(radix_u)));
                t5_at(u - layout.t_base, &mut acc);
                acc
            }
        }
    };
    let phi_next: Vec<Poly> = map_ordered(layout.n_total, one);
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

// ---------------------------------------------------------------------------
// [UPERF2-F] MEMORY DIET (U-PERF2 lane F): the level-0 digit witness as a
// flat i8 store, consumed per ring inside the kernels.
//
// The composed pass's level-0 witness is millions of digit rings (12x512:
// ~7.6M act + ~3.5M weight rings). As `Vec<Vec<i64>>` every ring is a
// 1 KiB heap block plus header (~1,064 B): ~12 GB for both groups, alive
// from the commit phase through the descents to the group eval proofs —
// and, because glibc keeps freed 1 KiB chunks in its arena, `w0.clear()`
// does not even lower the resident set afterwards. Every level-0 digit
// alphabet is |w| <= 64 (row EB4-emax caps e at 7; the class table's e0
// is 1 or 2), so one byte per digit is exact: `DigitCols` holds n x D
// bytes in ONE allocation (an mmap'd block that returns to the OS on
// drop) — 128 B per ring, 8.3x smaller.
//
// The kernels do not care where the small operand lives — every one of
// them lifts the ring to Z_p (or to R_q via `poly_from_small`) per ring
// anyway. `SmallRings` is that per-ring lift as a trait over BOTH stores:
// the boxed `[Vec<i64>]` (the historical form — the deeper levels'
// witnesses, the floors, the batteries, the synthetic agg_* rig) and the
// flat `[i8]` (n * D bytes; `DigitCols::rings()`). A kernel body written
// once over `B: SmallRings + ?Sized` computes IDENTICAL values on either
// store (the same i64 coefficients reach the same arithmetic); the
// pre-change entry points keep their names as `[Vec<i64>]` wrappers, so
// no battery, oracle or rig code path changes its bytes. This is a
// STRUCTURAL change (a storage type has no arithmetic oracle) — its gate
// is the rig digests, the E2E leg and `uperf-f diff-battery` (both
// stores through every kernel, byte-identical).

/// A slice of small (digit) rings — n rings of D coefficients — behind
/// either store. `ring(u, buf)` yields ring u as i64 coefficients: a
/// borrow of the storage when it is i64 already, else widened into `buf`.
pub trait SmallRings: Sync {
    /// Number of rings in the slice.
    fn n_rings(&self) -> usize;
    /// Ring u as i64 coefficients (length D).
    fn ring<'a>(&'a self, u: usize, buf: &'a mut [i64; D]) -> &'a [i64];
    /// max |coefficient| over the whole slice (0 when empty).
    fn max_abs(&self) -> u128;
    /// true if ring u is all zeros.
    fn is_zero(&self, u: usize) -> bool;
    /// The sub-slice of rings [lo, hi).
    fn sub(&self, lo: usize, hi: usize) -> &Self;
}

impl SmallRings for [Vec<i64>] {
    #[inline(always)]
    fn n_rings(&self) -> usize {
        self.len()
    }
    #[inline(always)]
    fn ring<'a>(&'a self, u: usize, _buf: &'a mut [i64; D]) -> &'a [i64] {
        self[u].as_slice()
    }
    fn max_abs(&self) -> u128 {
        self.iter().flat_map(|r| r.iter()).map(|&x| x.unsigned_abs() as u128).max().unwrap_or(0)
    }
    #[inline(always)]
    fn is_zero(&self, u: usize) -> bool {
        self[u].iter().all(|&x| x == 0)
    }
    #[inline(always)]
    fn sub(&self, lo: usize, hi: usize) -> &Self {
        &self[lo..hi]
    }
}

impl SmallRings for [i8] {
    #[inline(always)]
    fn n_rings(&self) -> usize {
        self.len() / D
    }
    #[inline(always)]
    fn ring<'a>(&'a self, u: usize, buf: &'a mut [i64; D]) -> &'a [i64] {
        let s = &self[u * D..(u + 1) * D];
        for i in 0..D {
            buf[i] = s[i] as i64;
        }
        &buf[..]
    }
    fn max_abs(&self) -> u128 {
        self.iter().map(|&x| x.unsigned_abs() as u128).max().unwrap_or(0)
    }
    #[inline(always)]
    fn is_zero(&self, u: usize) -> bool {
        self[u * D..(u + 1) * D].iter().all(|&x| x == 0)
    }
    #[inline(always)]
    fn sub(&self, lo: usize, hi: usize) -> &Self {
        &self[lo * D..hi * D]
    }
}

/// The flat i8 digit store: n rings x D digits in one allocation. Ring
/// u = bytes [u*D, (u+1)*D). `rings()` is the `SmallRings` view every
/// kernel consumes; `sub`-slices are plain byte sub-slices.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct DigitCols {
    data: Vec<i8>,
}

impl DigitCols {
    /// n zero rings.
    pub fn zeros(n: usize) -> DigitCols {
        DigitCols { data: vec![0i8; n * D] }
    }
    /// From boxed rings (every coefficient must fit an i8 — asserted).
    pub fn from_vecs(v: &[Vec<i64>]) -> DigitCols {
        let mut d = DigitCols::zeros(v.len());
        for (u, r) in v.iter().enumerate() {
            d.set_ring(u, r);
        }
        d
    }
    /// To boxed rings (adapters / the degenerate no-level floor).
    pub fn to_vecs(&self) -> Vec<Vec<i64>> {
        (0..self.len()).map(|u| self.ring_i64(u)).collect()
    }
    /// Number of rings.
    pub fn len(&self) -> usize {
        self.data.len() / D
    }
    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }
    /// The flat `SmallRings` view (all rings).
    #[inline(always)]
    pub fn rings(&self) -> &[i8] {
        &self.data
    }
    pub fn rings_mut(&mut self) -> &mut [i8] {
        &mut self.data
    }
    /// Ring u as bytes.
    #[inline(always)]
    pub fn ring(&self, u: usize) -> &[i8] {
        &self.data[u * D..(u + 1) * D]
    }
    pub fn ring_mut(&mut self, u: usize) -> &mut [i8] {
        &mut self.data[u * D..(u + 1) * D]
    }
    /// Ring u widened to i64.
    pub fn ring_i64(&self, u: usize) -> Vec<i64> {
        self.ring(u).iter().map(|&x| x as i64).collect()
    }
    /// Write ring u from i64 coefficients (|x| <= 127 asserted; the
    /// designed alphabets are |w| <= 64).
    pub fn set_ring(&mut self, u: usize, r: &[i64]) {
        assert_eq!(r.len(), D, "DigitCols::set_ring: ring length");
        for (o, &x) in self.ring_mut(u).iter_mut().zip(r.iter()) {
            *o = i8::try_from(x).unwrap_or_else(|_| panic!("DigitCols: digit {x} outside i8"));
        }
    }
    /// Zero-pad or truncate to n rings.
    pub fn resize(&mut self, n: usize) {
        self.data.resize(n * D, 0);
    }
    pub fn truncate(&mut self, n: usize) {
        self.data.truncate(n * D);
    }
    pub fn clear(&mut self) {
        self.data.clear();
    }
    pub fn shrink_to_fit(&mut self) {
        self.data.shrink_to_fit();
    }
    /// Heap bytes held (capacity).
    pub fn heap_bytes(&self) -> usize {
        self.data.capacity()
    }
}

/// `DigitCols == Vec<Vec<i64>>` by value (the batteries compare stores).
impl PartialEq<Vec<Vec<i64>>> for DigitCols {
    fn eq(&self, other: &Vec<Vec<i64>>) -> bool {
        self.len() == other.len()
            && (0..self.len()).all(|u| {
                other[u].len() == D && self.ring(u).iter().zip(other[u].iter()).all(|(&a, &b)| a as i64 == b)
            })
    }
}

// ---------------------------------------------------------------------------
// [UPERF2-F] Phi_0 NEVER MATERIALIZED at level 0.
//
// The prover's level-0 aggregated functional Phi_0 (n_0 mod-q rings — at
// 12x512 ~7.6M act rings = ~8 GB boxed) was materialized by the phi pass
// (`kernel_pass_factored(.., Some(alphas0))`) and consumed by exactly two
// things: the level-0 h cross-garbage (`bg_level_h` -> `level_h_pairs`,
// r x r inner products of phi chunk slices against w chunk slices) and
// the level-1 transport (which consumes Phi_0 ONLY through Psi_0 =
// compute_psi(Phi_0, chunk_0, c_0)). Both are served here without the
// object:
//   * `Phi0Source` is the FACTORED functional (per aligned tensor the O5
//     `PhiFactored` value rings x the limb radix; per small-cols tensor
//     its few phi rings kept; zero for kernel-less tensors) with a
//     `fill(v0, n, out)` that produces any window of consecutive digit
//     rings — one PHI_vr per value ring cached across its l0 limbs, the
//     same arithmetic (`poly_scale(radix, PhiFactored::value_ring)`) as
//     the phi pass, so the fill IS the phi pass restricted to a window;
//   * `level_h_pairs_with` feeds the r slices' windows into the NTT-domain
//     GEMM per u-block and accumulates the r x r table mod q. Every
//     block's GEMM output is an EXACT integer partial sum reduced mod q
//     (the kernel's own capacity contract per window), and mod-q addition
//     of true partial sums is the true total mod q — so the table is
//     bit-identical to the single-call `level_h_pairs` on the materialized
//     phi (the kernel already does this across its capacity windows);
//   * the level-1 transport takes `psi_level0_factored_multi(..)` through
//     `transport_level_from_psi` — exactly what `bg_verify_group` does
//     (Psi_0 factored == compute_psi(Phi_0) by the O5 battery leg).
// The materialized path stays reachable under `oracle_mode()`.

/// The phi rings of one SMALL-COLS (misaligned) tensor under its kernels:
/// per value ring the hoisted K-weight row once, PHI at radix 1, then
/// radix_limb * PHI per limb — `kernel_pass_factored`'s misaligned phi
/// branch, in (vr, limb) order (t.n_digit_rings() rings).
fn phi_small_cols_tensor(
    ctx: &RingCtx,
    kf: &KField,
    t: &AggTensor,
    ks: &KwHoist,
    alphas: &[Poly],
    radixes: &[u64],
) -> Vec<Poly> {
    let zq = &ctx.zq;
    let n_vr = t.n_value_rings();
    let mut phi: Vec<Poly> = Vec::with_capacity(t.n_digit_rings());
    let one_vr = |vr: usize| -> Vec<Poly> {
        let kw = kw_row_hoisted(kf, ks, vr);
        if kw.iter().all(|k| kf.is_zero(k)) {
            return vec![poly_zero(); t.l0];
        }
        let bp = bpolys_from_kw_local(zq, &kw, 1);
        let mut ph = poly_zero();
        for (a, b) in alphas.iter().zip(bp.iter()) {
            if b.iter().all(|&x| x == 0) {
                continue;
            }
            ph = poly_add(zq, &ph, &ring_mul_split_kara_fast(ctx, a, b));
        }
        radixes.iter().map(|&rx| super::poly_scale(zq, rx, &ph)).collect()
    };
    const VR_BLOCK_M: usize = 1024;
    let mut vr0 = 0;
    while vr0 < n_vr {
        let vr1 = (vr0 + VR_BLOCK_M).min(n_vr);
        let blocks: Vec<Vec<Poly>> = pooled(|| {
            use rayon::prelude::*;
            if threads() > 1 { (vr0..vr1).into_par_iter().map(one_vr).collect() } else { (vr0..vr1).map(one_vr).collect() }
        });
        for limbs in blocks {
            phi.extend(limbs);
        }
        vr0 = vr1;
    }
    phi
}

/// One tensor's share of the factored Phi_0.
enum Phi0Tensor {
    /// No kernel touches the tensor: zero rings.
    Zero,
    /// Aligned (cols % D == 0): PhiFactored value rings x limb radix.
    Aligned { pf: PhiFactored, radixes: Vec<u64>, l0: usize },
    /// Small-cols (misaligned): the tensor's phi rings, materialized
    /// (these tensors are the BK aux tensors — a few hundred value rings).
    Small { rings: Vec<Poly> },
}

/// The level-0 aggregated functional as a SOURCE of windows (see the
/// section note). Built once per group from the multi-claim kernels and
/// the 16 level-0 alphas; `fill` produces Phi_0[v0 .. v0 + n] for any
/// window (zero beyond the group's digit rings — the chunk-grid pad).
pub struct Phi0Source {
    n_digit_rings: usize,
    /// per tensor: (digit_ring_base, n_digit_rings, form)
    tensors: Vec<(usize, usize, Phi0Tensor)>,
}

impl Phi0Source {
    pub fn new(ctx: &RingCtx, kf: &KField, group: &AggGroup, kernels: &[MultiClaimKernel], alphas: &[Poly]) -> Phi0Source {
        let _t = prof::timer(prof::BG_KPHI); // [UPERF-PC] observation only (the phi pass's slot)
        assert_eq!(alphas.len(), K_DEG);
        let zq = &ctx.zq;
        let mut cache = ColBlockCache::new();
        let mut tensors = Vec::with_capacity(group.tensors.len());
        for (ti, t) in group.tensors.iter().enumerate() {
            let kers: Vec<&MultiClaimKernel> = kernels.iter().filter(|k| k.tensor_idx == ti).collect();
            let n = t.n_digit_rings();
            if kers.is_empty() {
                tensors.push((t.digit_ring_base, n, Phi0Tensor::Zero));
                continue;
            }
            let radixes: Vec<u64> = (0..t.l0).map(|l| zq.to_mod(1i64 << (t.e0 as usize * l))).collect();
            if t.cols % D != 0 {
                let _te = prof::timer(prof::E_KPASS_SMALL); // [UPERF2-E] observation only
                let ks = kw_hoist(kf, t, &kers);
                let rings = phi_small_cols_tensor(ctx, kf, t, &ks, alphas, &radixes);
                tensors.push((t.digit_ring_base, n, Phi0Tensor::Small { rings }));
                continue;
            }
            let nb = t.cols / D;
            let pf = PhiFactored::new(ctx, kf, &kers, nb, alphas, &mut cache);
            tensors.push((t.digit_ring_base, n, Phi0Tensor::Aligned { pf, radixes, l0: t.l0 }));
        }
        Phi0Source { n_digit_rings: group.n_digit_rings, tensors }
    }

    pub fn n_digit_rings(&self) -> usize {
        self.n_digit_rings
    }

    /// out[i] = Phi_0[v0 + i] for i in 0..n (zero rings past the group).
    /// One PHI_vr per value ring touched, scaled per limb — the phi pass
    /// on the window.
    pub fn fill(&self, zq: &Zq, v0: usize, n: usize, out: &mut [Poly]) {
        assert!(out.len() >= n);
        let v1 = v0 + n;
        // Tensors are contiguous and sorted by digit_ring_base.
        for (base, cnt, form) in &self.tensors {
            let (lo, hi) = ((*base).max(v0), (base + cnt).min(v1));
            if lo >= hi {
                continue;
            }
            match form {
                Phi0Tensor::Zero => {
                    for v in lo..hi {
                        out[v - v0] = poly_zero();
                    }
                }
                Phi0Tensor::Small { rings } => {
                    for v in lo..hi {
                        out[v - v0] = rings[v - base].clone();
                    }
                }
                Phi0Tensor::Aligned { pf, radixes, l0 } => {
                    let (rel_lo, rel_hi) = (lo - base, hi - base);
                    let mut vr = rel_lo / l0;
                    while vr * l0 < rel_hi {
                        let phi_vr = pf.value_ring(vr);
                        let a = rel_lo.max(vr * l0);
                        let b = rel_hi.min((vr + 1) * l0);
                        for rel in a..b {
                            out[base + rel - v0] = super::poly_scale(zq, radixes[rel - vr * l0], &phi_vr);
                        }
                        vr += 1;
                    }
                }
            }
        }
        // Past the group: the chunk-grid pad is zero.
        let tail0 = self.n_digit_rings.max(v0).min(v1);
        for v in tail0..v1 {
            out[v - v0] = poly_zero();
        }
    }

    /// The whole functional (battery use — must equal the phi pass).
    pub fn materialize(&self, zq: &Zq) -> Vec<Poly> {
        let mut out = vec![poly_zero(); self.n_digit_rings];
        self.fill(zq, 0, self.n_digit_rings, &mut out);
        out
    }
}

/// u-block of `level_h_pairs_with` (positions per block; r x block rings
/// of phi are alive at a time — 64 MB at r = 64).
pub const LEVELH_BLOCK: usize = 1024;

/// [UPERF2-F] `level_h_pairs` with the phi slices supplied per u-block by
/// a `Phi0Source` (slice j = digit rings [j*chunk, (j+1)*chunk)); the
/// r x r inner-product table accumulates mod q over the blocks (exact
/// partial sums, see the section note) — bit-identical to
/// `level_h_pairs(materialized slices, w, chunk)`. Threads: the fill is
/// parallel over slices j, the GEMM over positions (the kernel's own
/// split); every value is exact-integer work with a fixed reduction
/// order, identical for any ZK_THREADS.
pub fn level_h_pairs_with<B: SmallRings + ?Sized>(ctx: &RingCtx, src: &Phi0Source, w: &[&B], chunk: usize) -> Vec<Poly> {
    level_h_pairs_with_block(ctx, src, w, chunk, LEVELH_BLOCK)
}

/// The block-size-parameterized body (the battery drives ragged blocks).
pub fn level_h_pairs_with_block<B: SmallRings + ?Sized>(
    ctx: &RingCtx,
    src: &Phi0Source,
    w: &[&B],
    chunk: usize,
    block: usize,
) -> Vec<Poly> {
    let _t = prof::timer(prof::EP_LEVELH); // [UPERF-PC] observation only
    let zq = &ctx.zq;
    let r = w.len();
    for s in w {
        assert_eq!(s.n_rings(), chunk, "w slice length");
    }
    assert!(block >= 1);
    let mut g = vec![poly_zero(); r * r];
    if r == 0 || chunk == 0 {
        return level_h_from_g(zq, &g, r);
    }
    let mut phi_buf: Vec<Poly> = vec![poly_zero(); r * block];
    let mut u0 = 0usize;
    while u0 < chunk {
        let n = block.min(chunk - u0);
        // Fill slice j's window [u0, u0 + n) = digit rings j*chunk + u0 ..
        // (parallel over slices; each slice's window is one thread's own).
        {
            let fill = |j: usize, buf: &mut [Poly]| src.fill(zq, j * chunk + u0, n, &mut buf[..n]);
            if threads() > 1 {
                pooled(|| {
                    use rayon::prelude::*;
                    phi_buf.par_chunks_mut(block).enumerate().for_each(|(j, buf)| fill(j, buf));
                });
            } else {
                phi_buf.chunks_mut(block).enumerate().for_each(|(j, buf)| fill(j, buf));
            }
        }
        let phi_sl: Vec<&[Poly]> = (0..r).map(|j| &phi_buf[j * block..j * block + n]).collect();
        let w_sl: Vec<&B> = (0..r).map(|k| w[k].sub(u0, u0 + n)).collect();
        let gb = ntt_gemm_modq_small_gen(ctx, &phi_sl, &w_sl, n);
        for (gi, gbi) in g.iter_mut().zip(gb.iter()) {
            *gi = poly_add(zq, gi, gbi);
        }
        u0 += n;
    }
    level_h_from_g(zq, &g, r)
}

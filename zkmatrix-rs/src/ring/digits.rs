// U-AG-B1 lane BB, Deliverable 1 (F-N2): the EXACT-DIGIT decomposition
// path of the engine's digit/commitment layer — config-gated ALONGSIDE
// the existing balanced-digit path (sigma.rs Q2 chain / DigitOpening),
// which is left untouched.
//
// What "exact-digit" means here (the trench's triple-mandated
// configuration — AGGREGATION_PARAMS_DESIGN.md 3.4/3.5,
// AGGREGATION_ZK_DESIGN.md 4.3 item 2, AGGREGATION_FOLDING_DESIGN.md
// F-N2): a committed value column is decomposed into balanced
// base-2^e0 digit columns that are THEMSELVES committed, and every
// range fact about them is proven by DETERMINISTIC committed relations
// — no Gaussian-masked digit responses (the Balanced path's transport),
// no JL projections, no statistical slack. At q31 the engine's exact
// range mechanism is the range-table lookup (the U-R2 machinery — the
// EXACT argument, no ARP, no wrap side condition; the M2 binary
// ct-claims' side-condition budget closes only at q46-class moduli),
// so the exact-digit rig grounds digit alphabets by a lookup into the
// tiny public alphabet table and ties digits to values by exact
// recomposition RingClaims (constant public coefficients, no reveal).
//
// Alphabets. For e0 >= 2 the digits are the house balanced digits
// (super::digit_decompose): d in [-2^(e0-1), 2^(e0-1) - 1], unique.
// For e0 = 1 the design's weight-group base is SIGN-BINARY {-1, 0, 1}
// (F-IF1.5: weight group e0 = 1) — the balanced base-2 arithmetic
// cannot represent positive values (its digit set is {-1, 0}), so this
// module supplies the canonical sign-binary decomposition
// d_j = sign(x) * bit_j(|x|). Recorded as a lane finding: the Balanced
// (Q2) path has NO e0 = 1 base for general values; exact-digit is the
// engine's only sign-binary path, matching F-N2's "load-bearing for
// the weight group".
//
// Constants cited from the trench (freeze-checked in freeze_check_uagb1):
// - exact-digit recursion slack 2 * 29.4 = 58.8 (PARAMS 3.4 row 2), so
//   gamma_max(exact) = (q/8) / 58.8 ~ 2^22.12 at q31.
// - the fold-norm law gamma_z = OP_CONC * 2^(e0-1) * sqrt(n_limb * D)
//   with OP_CONC = 20.79 (PARAMS 3.2 / F-IF1.5).
// - class bases: weight int8 e0 = 1; activation int8 e0 = 2
//   (F-IF1.5's adopted pass-scale bases, applied here as the
//   per-class defaults the statement layer declares).

use super::ct_engine::RingClaim;
use super::{D, Poly, Zq, digit_decompose, poly_zero};

/// The config gate. `Balanced` = the existing Q2 chain (sigma.rs
/// derive_digit_params / prove_opening_digits) — Gaussian-masked digit
/// responses, approximate norm transport, UNCHANGED by this module.
/// `Exact` = committed digit columns + deterministic relations (this
/// module) — the trench-mandated configuration.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DigitMode {
    Balanced,
    Exact,
}

/// One value class under the exact-digit configuration: the inclusive
/// raw integer range it must cover, the digit base exponent e0, and the
/// pinned limb count l0 (always equal to derive_l0(min, max, e0) — the
/// freeze row asserts this both directions).
#[derive(Clone, Copy, Debug)]
pub struct ExactDigitClass {
    pub name: &'static str,
    pub min: i64,
    pub max: i64,
    pub e0: u32,
    pub l0: usize,
    /// Recomposition semantics. `false` (narrow value classes): the
    /// mod-q recomposition claim + alphabet facts imply the INTEGER
    /// identity — gated by recomposition_nonwrap_ok at derive time.
    /// `true` (the full-column class): the value IS a mod-q residue and
    /// the recomposition is mod-q NATIVE (Greyhound's own decomposition
    /// semantic, PARAMS 2.2: s = sum 2^(e0 j) s_j mod q with the digit
    /// alphabet carrying the norm control); the non-wrap gate is
    /// structurally violated there (representable(2,16) exceeds the
    /// centered window) and that violation is PINNED, not hidden.
    pub mod_q: bool,
}

/// Weight-class int8 (signed), sign-binary base — the F-N2 group.
pub const CLASS_W8S: ExactDigitClass =
    ExactDigitClass { name: "w8s-weight-int8", min: -128, max: 127, e0: 1, l0: 8, mod_q: false };
/// Activation-class int8 (signed), balanced base-4.
pub const CLASS_A8S: ExactDigitClass =
    ExactDigitClass { name: "a8s-act-int8", min: -128, max: 127, e0: 2, l0: 5, mod_q: false };
/// Activation offset codes [0, 255] (the lookup rigs' dense X form).
pub const CLASS_A8U: ExactDigitClass =
    ExactDigitClass { name: "a8u-act-offset8", min: 0, max: 255, e0: 2, l0: 5, mod_q: false };
/// Matmul accumulator at inner dimension 768 (the 125M layer shape
/// 512x768x2048): |sum| <= 768 * 128 * 128 = 12,582,912 (asymmetric
/// signed-int8 worst case, manifest v3 interval arithmetic).
pub const CLASS_ACC24_768: ExactDigitClass = ExactDigitClass {
    name: "acc24-inner768",
    min: -12_484_608, // 768 * (-128 * 127) = worst-case lower product sum
    max: 12_582_912,  // 768 * (-128 * -128) = worst-case upper product sum
    e0: 2,
    l0: 13,
    mod_q: false,
};
/// Full centered mod-q residue at q31 (the aggregate layer's column
/// class; l0 = 16 = ceil(31/2), PARAMS 2.2's convention).
pub const CLASS_Q31C: ExactDigitClass = ExactDigitClass {
    name: "q31c-full-column",
    min: -((super::Q8 as i64 - 1) / 2),
    max: (super::Q8 as i64 - 1) / 2,
    e0: 2,
    l0: 16,
    mod_q: true,
};

/// The four classes the freeze row pins (Q31C's l0 additionally matches
/// the design table's ceil(31/e0)).
pub const EXACT_DIGIT_CLASSES: [&ExactDigitClass; 5] =
    [&CLASS_W8S, &CLASS_A8S, &CLASS_A8U, &CLASS_ACC24_768, &CLASS_Q31C];

/// Inclusive digit alphabet of base e0: sign-binary {-1, 0, 1} at
/// e0 = 1; balanced [-2^(e0-1), 2^(e0-1) - 1] at e0 >= 2.
pub fn alphabet(e0: u32) -> (i64, i64) {
    if e0 == 1 {
        (-1, 1)
    } else {
        let half = 1i64 << (e0 - 1);
        (-half, half - 1)
    }
}

/// The shifted-alphabet table rows: digit + shift lands in [0, rows).
/// shift = -alphabet_lo; rows = alphabet size (3 at e0 = 1, 2^e0 else).
pub fn alphabet_shift(e0: u32) -> i64 {
    -alphabet(e0).0
}
pub fn alphabet_rows(e0: u32) -> usize {
    let (lo, hi) = alphabet(e0);
    (hi - lo + 1) as usize
}

/// Representable inclusive range of l digits in base e0 (i128 — the
/// Q31C endpoints overflow the i64 partial sums at intermediate limbs).
pub fn representable(e0: u32, l: usize) -> (i128, i128) {
    let (lo, hi) = alphabet(e0);
    let base = 1i128 << e0;
    // sum_{j<l} base^j = (base^l - 1) / (base - 1)
    let geo = ((base.pow(l as u32)) - 1) / (base - 1);
    (lo as i128 * geo, hi as i128 * geo)
}

/// The smallest l covering [min, max] in base e0 — the derivation the
/// class table's pinned l0 is checked against (both directions).
pub fn derive_l0(min: i64, max: i64, e0: u32) -> usize {
    let mut l = 1usize;
    loop {
        let (lo, hi) = representable(e0, l);
        if lo <= min as i128 && max as i128 <= hi {
            return l;
        }
        l += 1;
        assert!(l <= 64, "derive_l0 diverged");
    }
}

/// Canonical exact-digit decomposition. e0 >= 2: the house balanced
/// digits (unique). e0 = 1: canonical sign-binary d_j = sign(x) *
/// bit_j(|x|). Panics when x is not representable in l digits — the
/// class table guarantees representability for in-class values.
pub fn exact_digit_decompose(x: i64, e0: u32, l: usize) -> Vec<i64> {
    if e0 == 1 {
        let s = x.signum();
        let a = x.unsigned_abs();
        assert!(a < (1u64 << l), "sign-binary range exhausted for {x}");
        (0..l).map(|j| s * (((a >> j) & 1) as i64)).collect()
    } else {
        digit_decompose(x, e0, l)
    }
}

/// Exact recomposition sum_j 2^(e0 j) d_j (i128 accumulator).
pub fn exact_digit_recompose(digs: &[i64], e0: u32) -> i64 {
    let mut acc: i128 = 0;
    for (j, &d) in digs.iter().enumerate() {
        acc += (d as i128) << (e0 as usize * j);
    }
    i64::try_from(acc).expect("recomposition fits i64")
}

/// gamma_max under the exact-digit slack reading (PARAMS 3.4 row 2:
/// slack = 2 * 29.4 = 58.8; gamma_max = (q/8) / slack ~ 2^22.12 at q31).
pub fn gamma_max_exact(q: u64) -> f64 {
    (q as f64 / 8.0) / 58.8
}

/// The level-0 fold-norm law at the exact-digit gate (PARAMS 3.2 /
/// F-IF1.5): gamma_z = OP_CONC * 2^(e0-1) * sqrt(n_limb_rings * D),
/// OP_CONC = 20.79. (At e0 = 1 the sign-binary |d| <= 1 = 2^0 keeps
/// the same formula.)
pub const OP_CONC: f64 = 20.79;
pub fn fold_norm_gamma(e0: u32, n_limb_rings: usize) -> f64 {
    OP_CONC * 2f64.powi(e0 as i32 - 1) * ((n_limb_rings * D) as f64).sqrt()
}

/// Derive-time non-wrap gate for the recomposition claims: the exact
/// recomposition of ANY in-alphabet digit vector must sit strictly
/// inside the centered mod-q window, so the mod-q RingClaim identity
/// plus the digit alphabet facts imply the integer identity.
pub fn recomposition_nonwrap_ok(e0: u32, l0: usize, q: u64) -> bool {
    let (lo, hi) = representable(e0, l0);
    let half_q = (q as i128 - 1) / 2;
    -half_q < lo && hi < half_q
}

/// The exact recomposition claims: per message slot u,
///     sum_j 2^(e0 j) * d_(j,u)  -  x_u  =  0        over R_q,
/// with d_(j,u) the digit-j column commitment's slot u and x_u the
/// value commitment's slot u. Ring-valued linear claims with CONSTANT
/// public coefficients — no reveal, no g-slot, W_rl simulatable
/// (ct_engine's RingClaim contract). Sound over Z given the alphabet
/// facts and the non-wrap gate (asserted here at derive time).
pub fn digit_recomposition_claims(
    zq: &Zq,
    val_commit: usize,
    digit_commits: &[usize],
    slots: usize,
    e0: u32,
    mod_q: bool,
) -> Vec<RingClaim> {
    // Narrow (integer-exact) classes must clear the non-wrap gate;
    // mod-q classes (the full-column decomposition) are mod-q native
    // and skip it BY DECLARED SEMANTICS (see ExactDigitClass::mod_q).
    assert!(
        mod_q || recomposition_nonwrap_ok(e0, digit_commits.len(), zq.q),
        "recomposition non-wrap gate rejected (e0 = {e0}, l0 = {})",
        digit_commits.len()
    );
    let const_poly = |v: u64| -> Poly {
        let mut p = poly_zero();
        p[0] = v;
        p
    };
    (0..slots)
        .map(|u| {
            let mut msg_coeffs: Vec<(usize, usize, Poly)> = digit_commits
                .iter()
                .enumerate()
                .map(|(j, &ci)| (ci, u, const_poly(zq.to_mod(1i64 << (e0 as usize * j)))))
                .collect();
            msg_coeffs.push((val_commit, u, const_poly(zq.neg(1))));
            RingClaim { msg_coeffs, constant: poly_zero() }
        })
        .collect()
}

/// Canonical decomposition digest over a fixed input battery — the
/// freeze row's arithmetic pin. Any drift in the decomposition
/// arithmetic (alphabet, ordering, sign convention) moves this digest.
pub fn decomposition_digest() -> [u8; 32] {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    h.update(b"uagb1-exact-digit-battery-v1");
    for class in EXACT_DIGIT_CLASSES {
        h.update(class.name.as_bytes());
        h.update(class.e0.to_le_bytes());
        h.update((class.l0 as u64).to_le_bytes());
        // Endpoints, zero, +-1, and a deterministic LCG sweep inside the
        // class range.
        let mut probes: Vec<i64> = vec![class.min, class.max, 0, 1, -1];
        let span = (class.max as i128 - class.min as i128 + 1) as u128;
        let mut s = 0x9e37_79b9_7f4a_7c15u64;
        for _ in 0..64 {
            s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            probes.push((class.min as i128 + (s as u128 % span) as i128) as i64);
        }
        for x in probes {
            if x < class.min || x > class.max {
                continue;
            }
            let digs = exact_digit_decompose(x, class.e0, class.l0);
            assert_eq!(exact_digit_recompose(&digs, class.e0), x);
            h.update(x.to_le_bytes());
            for d in digs {
                h.update(d.to_le_bytes());
            }
        }
    }
    h.finalize().into()
}

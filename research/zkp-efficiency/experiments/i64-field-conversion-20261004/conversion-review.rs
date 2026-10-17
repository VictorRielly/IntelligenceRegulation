// Uncompiled review sketch; no production changes or benchmark claims.
// Existing Fp is a canonical transparent u64 wrapper. Keep new/from_u128,
// mask generation, challenges, arithmetic, all protocol code unchanged.
// Interface candidate for zkp-core/src/field.rs::Fp::from_i64 only:
#[inline(always)]
pub fn from_i64_candidate(v: i64) -> Fp {
    const EPSILON: u64 = 0xFFFF_FFFF;
    let sign_mask = (v >> 63) as u64;
    Fp((v as u64).wrapping_sub(sign_mask & EPSILON))
}

// Proof of canonical value: positives <=i64MAX<p need no adjustment.
// For negative v, raw=2^64+v >=2^63>EPSILON; raw-EPSILON=p+v,
// in [p-2^63,p-1]. The wrapping operation neither overflows nor
// underflows in that case. i64MIN needs no abs or signed negation.
// This must not be extended to u64/i128/u128 or random field draws.
// No unsafe, SIMD, in-place reinterpretation, narrow casts or RNG changes.

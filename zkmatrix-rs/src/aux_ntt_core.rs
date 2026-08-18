//! A1 auxiliary-modulus NTT kernels, shared by the Route R backends.
//!
//! Origin: the A1 prototype bin (`bin/aux_ntt.rs`, workstream A1 of
//! `docs/zkmatrix-poc/RING_MULT_BOTTLENECK.md` Section 4; report:
//! `docs/zkmatrix-poc/A1_AUX_NTT_REPORT.md`). This module is the reusable
//! arithmetic promoted out of that bin per the report's Section 5
//! integration plan: Goldilocks primitives, the psi-twisted negacyclic
//! length-128 NTT, protocol-domain lifts, the capacity contract, the
//! limb-split fallback, and the GEMM-shaped commit kernels. It is shared by
//! `#[path]` inclusion from each binary (the `manifest.rs` precedent — the
//! crate is a collection of stand-alone bins, so a library target is
//! deliberately avoided; the module has no dependencies).
//!
//! Soundness note (unchanged from the report): the helper prime p carries no
//! protocol role. A ring product over R_q = Z_q[X]/(X^128 + 1) is an exact
//! integer polynomial with bounded coefficients; any modulus large enough to
//! determine that integer can host the computation. Every kernel here
//! produces mod-q outputs BIT-IDENTICAL to schoolbook — an evaluation
//! strategy, not a protocol change. The exact-integer contract
//! (`capacity`) is a static property of the operand-norm regime, asserted at
//! kernel construction, never assumed from data.
//!
//! All value-path arithmetic is exact integer (u64/u128/i128).

#![allow(dead_code)]

// ---------------------------------------------------------------------------
// Ring degree (matches ring_lattice.rs / ROUTE_R_DESIGN.md).

pub const D: usize = 128;
pub const LOG2_D: u32 = 7;

// ---------------------------------------------------------------------------
// Goldilocks arithmetic: p = 2^64 - 2^32 + 1.
//
// Facts used (verified in the aux_ntt bin's self-test): p is prime;
// p - 1 = 2^32 * (2^32 - 1) = 2^32 * 3 * 5 * 17 * 257 * 65537, so
// v2(p-1) = 32 and 256th roots of unity exist; 7 generates Z_p^*.

pub const P: u64 = 0xFFFF_FFFF_0000_0001;
pub const EPS: u64 = 0xFFFF_FFFF; // 2^32 - 1 = 2^64 mod p
pub const GEN: u64 = 7;

/// Branchless canonicalization to [0, p): subtract p if possible. Compiles
/// to a cmov — data-dependent branches cost ~3x NTT throughput here.
#[inline(always)]
pub fn canon_p(r: u64) -> u64 {
    let (d, borrow) = r.overflowing_sub(P);
    if borrow { r } else { d }
}

#[inline(always)]
pub fn add_p(a: u64, b: u64) -> u64 {
    // a, b < p. a + b < 2p < 2^65: on carry, a+b-2^64 + (2^32-1) = a+b-p,
    // and the EPS adjustment cannot re-carry (a+b-2^64 < 2^64 - 2^33 + 2).
    let (s, carry) = a.overflowing_add(b);
    canon_p(s.wrapping_add((carry as u64) * EPS))
}

#[inline(always)]
pub fn sub_p(a: u64, b: u64) -> u64 {
    // a, b < p. On borrow: a-b+2^64 - (2^32-1) = a-b+p (no re-borrow:
    // a-b+2^64 >= 2^64-p+1 = 2^32 > EPS).
    let (d, borrow) = a.overflowing_sub(b);
    d.wrapping_sub((borrow as u64) * EPS)
}

/// Reduce a full u128 mod p, branchless. With x = lo + 2^64*hi_lo +
/// 2^96*hi_hi and 2^64 = 2^32 - 1, 2^96 = -1 (mod p):
/// x = lo + (2^32-1)*hi_lo - hi_hi. Neither adjustment can double-wrap
/// (borrow case: t >= 2^64 - 2^32 + 1 > EPS; carry case:
/// t + t1 - 2^64 <= 2^64 - 2^33, + EPS < 2^64). Cross-checked against the
/// slow `% p` path over random and structured edge values in the aux_ntt
/// bin's self-test.
#[inline(always)]
pub fn reduce128(x: u128) -> u64 {
    let lo = x as u64;
    let hi = (x >> 64) as u64;
    let hi_lo = hi & EPS;
    let hi_hi = hi >> 32;
    let (t, borrow) = lo.overflowing_sub(hi_hi);
    let t = t.wrapping_sub((borrow as u64) * EPS);
    let t1 = (hi_lo << 32).wrapping_sub(hi_lo); // hi_lo * (2^32 - 1), exact
    let (r, carry) = t.overflowing_add(t1);
    canon_p(r.wrapping_add((carry as u64) * EPS))
}

#[inline(always)]
pub fn mul_p(a: u64, b: u64) -> u64 {
    reduce128(a as u128 * b as u128)
}

pub fn pow_p(mut base: u64, mut e: u64) -> u64 {
    let mut acc = 1u64;
    while e > 0 {
        if e & 1 == 1 {
            acc = mul_p(acc, base);
        }
        base = mul_p(base, base);
        e >>= 1;
    }
    acc
}

pub fn inv_p(a: u64) -> u64 {
    pow_p(a, P - 2)
}

// ---------------------------------------------------------------------------
// Negacyclic NTT over Z_p, length 128, via the merged psi-twist
// (Longa-Naehrig 2016, the SEAL/NFLlib convention): forward = Cooley-Tukey
// DIT with psi powers in bit-reversed order (standard-order input,
// bit-reversed output), inverse = Gentleman-Sande DIF with inverse psi
// powers (bit-reversed input, standard-order output, final scale by 1/n).
// Multiplication in Z_p[X]/(X^128 + 1) is then: fwd(a), fwd(b), pointwise,
// inv — no zero-padding, no separate twist pass.

pub struct NttTables {
    psi_brv: [u64; D],  // psi^bitrev7(i)
    ipsi_brv: [u64; D], // psi^{-bitrev7(i)}
    n_inv: u64,
    // [UPERF2-I] SIMD-layout copies of the m = 32 stage twiddles (the
    // 4-lane split of `ntt_fwd_avx2` / `ntt_inv_avx2` pairs lanes
    // (0,1) and (2,3) of consecutive vectors, so its twiddle vector for
    // vectors (2k, 2k+1) is (s_2k, s_2k, s_2k+1, s_2k+1) with s_i =
    // psi_brv[32 + i]): psi_l2[4k..4k+4]. Same values, no new constants.
    psi_l2: [u64; 64],
    ipsi_l2: [u64; 64],
    // [UPERF2-I] Signed power-of-two form of the outer-stage twiddles.
    // 2 has order 192 in Z_p^* (2^96 = -1: 2^96 = 2^64 2^32 == EPS 2^32 =
    // 2^64 - 2^32 == -1), so every root of unity of order dividing 64 is
    // +-2^k with 0 <= k < 96 — that is every twiddle of the forward
    // stages m <= 16 (psi_brv[1..32]: 64th roots and below), of the
    // inverse stages h <= 16 (ipsi_brv[1..32]) and 1/n = 2^-7 = -2^89.
    // The SIMD bodies multiply by those with shifts + the same
    // reduction instead of the four-partial-product u64 x u64 (values
    // identical: the same field element, canonical). psi_pw2[i] /
    // ipsi_pw2[i] describe psi_brv[i] / ipsi_brv[i] for i in 1..32;
    // index 0 is unused (psi_brv[0] = 1 is never a twiddle).
    psi_pw2: [Pw2; 32],
    ipsi_pw2: [Pw2; 32],
    n_inv_pw2: Pw2,
}

/// [UPERF2-I] w = (-1)^neg * 2^k mod p, 0 <= k < 96.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Pw2 {
    pub k: u8,
    pub neg: bool,
}

/// [UPERF2-I] Solve w = +-2^k (k < 96) by search over the 192 powers of 2;
/// None if w is not in the subgroup generated by 2.
pub fn pow2_form(w: u64) -> Option<Pw2> {
    let mut x = 1u64;
    for k in 0..192u32 {
        if x == w {
            return Some(if k < 96 { Pw2 { k: k as u8, neg: false } } else { Pw2 { k: (k - 96) as u8, neg: true } });
        }
        x = mul_p(x, 2);
    }
    None
}

impl NttTables {
    /// The signed power-of-two form of a forward outer-stage twiddle
    /// (index into psi_brv, 1 <= i < 32).
    pub fn psi_pw2(&self, i: usize) -> Pw2 {
        self.psi_pw2[i]
    }
    pub fn ipsi_pw2(&self, i: usize) -> Pw2 {
        self.ipsi_pw2[i]
    }
    pub fn n_inv_pw2(&self) -> Pw2 {
        self.n_inv_pw2
    }
    pub fn psi_brv(&self, i: usize) -> u64 {
        self.psi_brv[i]
    }
    pub fn ipsi_brv(&self, i: usize) -> u64 {
        self.ipsi_brv[i]
    }
    pub fn n_inv(&self) -> u64 {
        self.n_inv
    }
}

pub fn bitrev7(mut i: u32) -> u32 {
    let mut r = 0u32;
    for _ in 0..LOG2_D {
        r = (r << 1) | (i & 1);
        i >>= 1;
    }
    r
}

pub fn build_tables() -> NttTables {
    // psi: primitive 256th root of unity (psi^128 = -1).
    let psi = pow_p(GEN, (P - 1) / (2 * D as u64));
    let psi_inv = inv_p(psi);
    let mut psi_brv = [0u64; D];
    let mut ipsi_brv = [0u64; D];
    // Powers by repeated multiplication (exact; D = 128 steps).
    let mut fwd = [0u64; D];
    let mut bwd = [0u64; D];
    let mut f = 1u64;
    let mut b = 1u64;
    for i in 0..D {
        fwd[i] = f;
        bwd[i] = b;
        f = mul_p(f, psi);
        b = mul_p(b, psi_inv);
    }
    for i in 0..D {
        psi_brv[i] = fwd[bitrev7(i as u32) as usize];
        ipsi_brv[i] = bwd[bitrev7(i as u32) as usize];
    }
    // [UPERF2-I] the 4-lane layout of the m = 32 stage twiddles.
    let mut psi_l2 = [0u64; 64];
    let mut ipsi_l2 = [0u64; 64];
    for k in 0..16 {
        for j in 0..4 {
            psi_l2[4 * k + j] = psi_brv[32 + 2 * k + j / 2];
            ipsi_l2[4 * k + j] = ipsi_brv[32 + 2 * k + j / 2];
        }
    }
    // [UPERF2-I] the signed power-of-two forms of the outer-stage
    // twiddles and 1/n (asserted to exist: they are 64th roots of unity
    // and below, inside <2> of order 192; the value equality is
    // re-checked here — the SIMD bodies rely on it).
    let n_inv = inv_p(D as u64);
    let mut psi_pw2 = [Pw2 { k: 0, neg: false }; 32];
    let mut ipsi_pw2 = [Pw2 { k: 0, neg: false }; 32];
    let check = |w: u64, f: Pw2| {
        let mut x = pow_p(2, f.k as u64);
        if f.neg {
            x = sub_p(0, x);
        }
        assert_eq!(x, w, "pow2 form mismatch");
    };
    for i in 1..32 {
        psi_pw2[i] = pow2_form(psi_brv[i]).expect("psi_brv[i] (i < 32) must be +-2^k");
        ipsi_pw2[i] = pow2_form(ipsi_brv[i]).expect("ipsi_brv[i] (i < 32) must be +-2^k");
        check(psi_brv[i], psi_pw2[i]);
        check(ipsi_brv[i], ipsi_pw2[i]);
    }
    let n_inv_pw2 = pow2_form(n_inv).expect("1/n must be +-2^k");
    check(n_inv, n_inv_pw2);
    NttTables { psi_brv, ipsi_brv, n_inv, psi_l2, ipsi_l2, psi_pw2, ipsi_pw2, n_inv_pw2 }
}

/// Forward negacyclic NTT, in place. Input standard order, output
/// bit-reversed order (consistent order is all pointwise mult needs).
pub fn ntt_fwd(a: &mut [u64; D], t: &NttTables) {
    let mut len = D;
    let mut m = 1;
    while m < D {
        len >>= 1;
        for i in 0..m {
            let s = t.psi_brv[m + i];
            let j1 = 2 * i * len;
            for j in j1..j1 + len {
                let u = a[j];
                let v = mul_p(a[j + len], s);
                a[j] = add_p(u, v);
                a[j + len] = sub_p(u, v);
            }
        }
        m <<= 1;
    }
}

/// Inverse negacyclic NTT, in place. Bit-reversed input, standard output.
pub fn ntt_inv(a: &mut [u64; D], t: &NttTables) {
    let mut len = 1;
    let mut m = D;
    while m > 1 {
        let h = m >> 1;
        let mut j1 = 0;
        for i in 0..h {
            let s = t.ipsi_brv[h + i];
            for j in j1..j1 + len {
                let u = a[j];
                let v = a[j + len];
                a[j] = add_p(u, v);
                a[j + len] = mul_p(sub_p(u, v), s);
            }
            j1 += 2 * len;
        }
        len <<= 1;
        m = h;
    }
    for x in a.iter_mut() {
        *x = mul_p(*x, t.n_inv);
    }
}

// ---------------------------------------------------------------------------
// [UPERF2-C] Branchless Goldilocks arithmetic and the SAME transforms on
// it. Identical VALUES to canon_p / add_p / sub_p / reduce128 / mul_p /
// ntt_fwd / ntt_inv above (asserted by `ring_matmul uperf-c diff-battery`
// on random rings and planted extremes) — a pure code-generation change:
// the data-dependent `if` selects of the forms above compile to
// mispredicted branches inside the butterfly loops (measured 4.35 us per
// length-128 forward transform on the WSL box, ~40 cycles per butterfly);
// the mask forms below and the bounds-check-free butterfly iteration
// bring the transform to the sub-microsecond class the NTT-domain
// kernels were costed at. Every eval_proof.rs kernel rides these.

/// == add_p (a, b < p): the u128 sum with one compare-based conditional
/// subtract (no carry-flag selects — those compile to branches here).
#[inline(always)]
pub fn gl_add(a: u64, b: u64) -> u64 {
    let s = a as u128 + b as u128;
    let s = if s >= P as u128 { s - P as u128 } else { s };
    s as u64
}

/// == sub_p (a, b < p): a + (p - b), then the same conditional subtract.
#[inline(always)]
pub fn gl_sub(a: u64, b: u64) -> u64 {
    let s = a as u128 + (P - b) as u128;
    let s = if s >= P as u128 { s - P as u128 } else { s };
    s as u64
}

/// == reduce128: x = lo + 2^64 hi, hi = 2^32 hi_hi + hi_lo, 2^64 = EPS
/// and 2^96 = -1 (mod p), so x = lo + EPS*hi_lo + (p - hi_hi) — three
/// non-negative terms each < 2^64 summed in u128 (< 3p + 2^32), then two
/// compare-based conditional subtracts (2p, then p) canonicalize.
#[inline(always)]
pub fn gl_reduce128(x: u128) -> u64 {
    let lo = x as u64;
    let hi = (x >> 64) as u64;
    let hi_lo = hi & EPS;
    let hi_hi = hi >> 32;
    let r = lo as u128 + (hi_lo * EPS) as u128 + (P - hi_hi) as u128;
    let r = if r >= 2 * P as u128 { r - 2 * P as u128 } else { r };
    let r = if r >= P as u128 { r - P as u128 } else { r };
    r as u64
}

/// == mul_p.
#[inline(always)]
pub fn gl_mul(a: u64, b: u64) -> u64 {
    gl_reduce128(a as u128 * b as u128)
}

/// == ntt_fwd (same butterflies, same twiddle order, same output order),
/// on the branchless ops with bounds-check-free half-block iteration.
pub fn ntt_fwd_fast(a: &mut [u64; D], t: &NttTables) {
    let mut len = D;
    let mut m = 1;
    while m < D {
        len >>= 1;
        for i in 0..m {
            let s = t.psi_brv[m + i];
            let j1 = 2 * i * len;
            let (lo, hi) = a[j1..j1 + 2 * len].split_at_mut(len);
            for (u, v) in lo.iter_mut().zip(hi.iter_mut()) {
                let x = *u;
                let y = gl_mul(*v, s);
                *u = gl_add(x, y);
                *v = gl_sub(x, y);
            }
        }
        m <<= 1;
    }
}

/// == ntt_inv (same butterflies, same twiddle order, same final scale).
pub fn ntt_inv_fast(a: &mut [u64; D], t: &NttTables) {
    let mut len = 1;
    let mut m = D;
    while m > 1 {
        let h = m >> 1;
        let mut j1 = 0;
        for i in 0..h {
            let s = t.ipsi_brv[h + i];
            let (lo, hi) = a[j1..j1 + 2 * len].split_at_mut(len);
            for (u, v) in lo.iter_mut().zip(hi.iter_mut()) {
                let x = *u;
                let y = *v;
                *u = gl_add(x, y);
                *v = gl_mul(gl_sub(x, y), s);
            }
            j1 += 2 * len;
        }
        len <<= 1;
        m = h;
    }
    for x in a.iter_mut() {
        *x = gl_mul(*x, t.n_inv);
    }
}

// ---------------------------------------------------------------------------
// [UPERF2-I] SIMD transforms: the SAME DIT forward / GS inverse (same
// butterflies, same twiddle order, same output order, same final 1/n
// scale) on 4 x u64 AVX2 lanes (x86_64, runtime-detected) or 2 x u64 NEON
// lanes (aarch64, [UNTESTED-NEON] — written to mirror the AVX2 body, not
// run here). Every vector op yields the CANONICAL value in [0, p) of the
// same field expression the scalar `gl_*` op computes (the u64 x u64
// product from four 32 x 32 partial products, then `lo + EPS*hi_lo -
// hi_hi` mod p with compare-based conditional subtracts), so the
// transforms' outputs are identical to `ntt_fwd_fast` / `ntt_inv_fast`
// by the uniqueness of canonical representatives — asserted by
// `ring_matmul uperf-i battery` (planted extremes + random rings, fwd,
// inv, round trip). Safety: the only `unsafe` is the SIMD intrinsics
// themselves — loads/stores at fixed in-bounds offsets of a `[u64; 128]`,
// and the AVX2 entry points are reached only after
// `is_x86_feature_detected!("avx2")`. `ZK_NTT_SIMD=0` forces the scalar
// body in `ntt_fwd_best` / `ntt_inv_best` (the one-binary A/B knob).

/// True when the box has the SIMD body and `ZK_NTT_SIMD` is not "0"
/// (read once).
pub fn simd_ntt_enabled() -> bool {
    static ON: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *ON.get_or_init(|| {
        let knob = std::env::var("ZK_NTT_SIMD").map(|v| v != "0").unwrap_or(true);
        knob && simd_ntt_available()
    })
}

/// Whether this box can run the SIMD body at all (independent of the knob).
pub fn simd_ntt_available() -> bool {
    #[cfg(target_arch = "x86_64")]
    {
        std::arch::is_x86_feature_detected!("avx2")
    }
    #[cfg(target_arch = "aarch64")]
    {
        true
    }
    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        false
    }
}

/// The SIMD body's name for reports: "avx2" | "neon" | "scalar".
pub fn simd_ntt_label() -> &'static str {
    if !simd_ntt_available() {
        return "scalar";
    }
    #[cfg(target_arch = "x86_64")]
    {
        "avx2"
    }
    #[cfg(target_arch = "aarch64")]
    {
        "neon"
    }
    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        "scalar"
    }
}

/// The transform every eval_proof.rs kernel calls: the SIMD body when
/// available and enabled, else `ntt_fwd_fast` (identical values).
#[inline]
pub fn ntt_fwd_best(a: &mut [u64; D], t: &NttTables) {
    if simd_ntt_enabled() {
        ntt_fwd_simd(a, t);
    } else {
        ntt_fwd_fast(a, t);
    }
}

/// == ntt_inv_fast, dispatched like `ntt_fwd_best`.
#[inline]
pub fn ntt_inv_best(a: &mut [u64; D], t: &NttTables) {
    if simd_ntt_enabled() {
        ntt_inv_simd(a, t);
    } else {
        ntt_inv_fast(a, t);
    }
}

/// The SIMD forward body directly (battery / bench). Falls back to the
/// scalar body only where no SIMD body exists for the architecture.
#[inline]
pub fn ntt_fwd_simd(a: &mut [u64; D], t: &NttTables) {
    #[cfg(target_arch = "x86_64")]
    {
        // SAFETY: AVX2 is present (checked by the caller through
        // `simd_ntt_available`; asserted again here — the check is a
        // cached load); the body indexes a fixed [u64; 128].
        assert!(std::arch::is_x86_feature_detected!("avx2"), "ntt_fwd_simd: no AVX2");
        unsafe { gl_avx2::ntt_fwd(a, t) }
    }
    #[cfg(target_arch = "aarch64")]
    {
        // SAFETY: NEON is the aarch64 baseline; fixed [u64; 128].
        unsafe { gl_neon::ntt_fwd(a, t) }
    }
    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        ntt_fwd_fast(a, t)
    }
}

/// The SIMD inverse body directly (battery / bench).
#[inline]
pub fn ntt_inv_simd(a: &mut [u64; D], t: &NttTables) {
    #[cfg(target_arch = "x86_64")]
    {
        assert!(std::arch::is_x86_feature_detected!("avx2"), "ntt_inv_simd: no AVX2");
        unsafe { gl_avx2::ntt_inv(a, t) }
    }
    #[cfg(target_arch = "aarch64")]
    {
        unsafe { gl_neon::ntt_inv(a, t) }
    }
    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        ntt_inv_fast(a, t)
    }
}

/// [UPERF2-I] AVX2 body: 4 x u64 lanes. Stages with len >= 4 are
/// whole-vector butterflies with one broadcast twiddle per (stage,
/// group); the two stages with len < 4 (forward m = 32, 64; inverse
/// len = 1, 2) run chained on a lane split of each 8-element block
/// (permute2x128 / unpack in, the reverse out) with contiguous twiddle
/// loads (`psi_l2` / `ipsi_l2` for the len-2 stage, `psi_brv[64..]` /
/// `ipsi_brv[64..]` for the len-1 stage).
#[cfg(target_arch = "x86_64")]
mod gl_avx2 {
    use super::{NttTables, D, EPS, P};
    use core::arch::x86_64::*;

    const SIGN: u64 = 1 << 63;

    /// Lane constants (broadcast once per transform).
    #[derive(Clone, Copy)]
    struct K {
        p: __m256i,
        eps: __m256i,  // EPS = 2^32 - 1: the reduction constant AND the low-32 mask
        sign: __m256i, // 2^63: unsigned compare = signed compare of sign-flipped values
        pm1s: __m256i, // (p - 1) ^ SIGN
    }

    #[inline(always)]
    unsafe fn consts() -> K {
        unsafe {
            K {
                p: _mm256_set1_epi64x(P as i64),
                eps: _mm256_set1_epi64x(EPS as i64),
                sign: _mm256_set1_epi64x(SIGN as i64),
                pm1s: _mm256_set1_epi64x(((P - 1) ^ SIGN) as i64),
            }
        }
    }

    /// A twiddle operand: the lanes' twiddles and their high 32-bit
    /// halves (`_mm256_mul_epu32` reads the low halves itself).
    #[derive(Clone, Copy)]
    struct Tw {
        w: __m256i,
        w_hi: __m256i,
    }

    #[inline(always)]
    unsafe fn tw_splat(w: u64) -> Tw {
        unsafe { Tw { w: _mm256_set1_epi64x(w as i64), w_hi: _mm256_set1_epi64x((w >> 32) as i64) } }
    }

    #[inline(always)]
    unsafe fn tw_load(p: *const u64) -> Tw {
        unsafe {
            let w = _mm256_loadu_si256(p as *const __m256i);
            Tw { w, w_hi: _mm256_srli_epi64::<32>(w) }
        }
    }

    /// `vpmuludq`: the low 32 bits of each lane of a times the low 32 bits
    /// of each lane of b, full 64-bit products — as ONE opaque
    /// instruction. Through the `_mm256_mul_epu32` intrinsic LLVM sees a
    /// generic zext/mul pattern and, for the loop-invariant broadcast
    /// twiddles of the outer stages, re-lowers it as a 64-bit multiply
    /// idiom (two extra `vpmuludq` by a known-zero half plus shifts/adds
    /// per butterfly) and strength-reduces `hi_lo * EPS` to
    /// shift-and-subtract (seen in the disassembly of the first build).
    /// The asm form keeps exactly 4 + 1 multiplies per butterfly. (The
    /// `ymm_reg` operand class needs the feature on the function itself;
    /// the crate is built for the x86-64 baseline — cargo does not read
    /// zkmatrix-rs/.cargo/config.toml when invoked from the repo root —
    /// so this helper carries it and inlines into the AVX2 bodies.)
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

    #[inline(always)]
    unsafe fn ld(a: *const u64, i: usize) -> __m256i {
        unsafe { _mm256_loadu_si256(a.add(i) as *const __m256i) }
    }

    #[inline(always)]
    unsafe fn st(a: *mut u64, i: usize, v: __m256i) {
        unsafe { _mm256_storeu_si256(a.add(i) as *mut __m256i, v) }
    }

    /// == gl_add: (a + b) mod p canonical for a, b < p. a + b >= p iff
    /// a > (p - 1) - b (no wrap: b < p); the unsigned compare is the
    /// signed compare of the sign-flipped values, and
    /// ((p - 1) - b) ^ SIGN == ((p - 1) ^ SIGN) - b (mod 2^64) because
    /// x ^ SIGN == x + 2^63 (mod 2^64). Then a + b - p (mod 2^64) is the
    /// exact canonical value when a + b >= p (it lies in [0, p)).
    #[inline(always)]
    unsafe fn add(a: __m256i, b: __m256i, k: K) -> __m256i {
        unsafe {
            let ge = _mm256_cmpgt_epi64(_mm256_xor_si256(a, k.sign), _mm256_sub_epi64(k.pm1s, b));
            _mm256_sub_epi64(_mm256_add_epi64(a, b), _mm256_and_si256(ge, k.p))
        }
    }

    /// == gl_sub: (a - b) mod p canonical for a, b < p: a - b, plus p on
    /// borrow (b > a), all mod 2^64 (a - b + p lies in (0, p) then).
    #[inline(always)]
    unsafe fn sub(a: __m256i, b: __m256i, k: K) -> __m256i {
        unsafe {
            let br = _mm256_cmpgt_epi64(_mm256_xor_si256(b, k.sign), _mm256_xor_si256(a, k.sign));
            _mm256_add_epi64(_mm256_sub_epi64(a, b), _mm256_and_si256(br, k.p))
        }
    }

    /// == gl_mul: a * w mod p canonical for a, w < p.
    #[inline(always)]
    unsafe fn mul(a: __m256i, t: Tw, k: K) -> __m256i {
        unsafe {
            // 64 x 64 -> 128 from four 32 x 32 partial products
            // (a = a1 2^32 + a0, w = w1 2^32 + w0):
            //   x = a0 w0 + 2^32 (a0 w1 + a1 w0) + 2^64 a1 w1,
            // carried in 32-bit columns; every intermediate < 2^64
            // (partial products <= (2^32 - 1)^2, column carries < 2^32).
            let a_hi = _mm256_srli_epi64::<32>(a);
            let ll = mul32(a, t.w);
            let lh = mul32(a, t.w_hi);
            let hl = mul32(a_hi, t.w);
            let hh = mul32(a_hi, t.w_hi);
            let t0 = _mm256_add_epi64(hl, _mm256_srli_epi64::<32>(ll));
            let t1 = _mm256_add_epi64(lh, _mm256_and_si256(t0, k.eps));
            let hi = _mm256_add_epi64(_mm256_add_epi64(hh, _mm256_srli_epi64::<32>(t0)), _mm256_srli_epi64::<32>(t1));
            let lo = _mm256_blend_epi32::<0xAA>(ll, _mm256_slli_epi64::<32>(t1));
            // == gl_reduce128: x = lo + 2^64 hi == lo + EPS hi_lo - hi_hi
            // (mod p) with 2^64 == EPS and 2^96 == -1; each term brought
            // to canonical form: c = lo mod p (lo < 2^64 < 2p: one
            // conditional subtract), e = EPS hi_lo (< p: hi_lo < 2^32),
            // hi_hi < 2^32 < p; then r = ((c + e) mod p - hi_hi) mod p.
            let hi_hi = _mm256_srli_epi64::<32>(hi);
            let e = mul32(hi, k.eps);
            let c_ge = _mm256_cmpgt_epi64(_mm256_xor_si256(lo, k.sign), k.pm1s);
            let c = _mm256_sub_epi64(lo, _mm256_and_si256(c_ge, k.p));
            sub(add(c, e, k), hi_hi, k)
        }
    }

    /// The DIT butterfly: (u + v w, u - v w).
    #[inline(always)]
    unsafe fn dit(u: __m256i, v: __m256i, t: Tw, k: K) -> (__m256i, __m256i) {
        unsafe {
            let y = mul(v, t, k);
            (add(u, y, k), sub(u, y, k))
        }
    }

    /// The GS butterfly: (u + v, (u - v) w).
    #[inline(always)]
    unsafe fn gs(u: __m256i, v: __m256i, t: Tw, k: K) -> (__m256i, __m256i) {
        unsafe { (add(u, v, k), mul(sub(u, v, k), t, k)) }
    }

    /// A signed power-of-two twiddle +-2^k (0 <= k < 96) as shift counts.
    #[derive(Clone, Copy)]
    struct Pw {
        cls: u8, // 0: k <= 32; 1: 32 < k < 64; 2: 64 <= k < 96
        neg: bool,
        cl: __m128i, // left count: k (cls 0/1), k - 64 (cls 2)
        cr: __m128i, // right count 64 - k (cls 0/1)
        c2: __m128i, // right count 96 - k (cls 1/2)
    }

    #[inline(always)]
    unsafe fn pw(f: super::Pw2) -> Pw {
        let k = f.k as i32;
        let cls = if k <= 32 { 0 } else if k < 64 { 1 } else { 2 };
        unsafe {
            Pw {
                cls,
                neg: f.neg,
                cl: _mm_cvtsi32_si128(if k >= 64 { k - 64 } else { k }),
                cr: _mm_cvtsi32_si128(64 - k),
                c2: _mm_cvtsi32_si128(96 - k),
            }
        }
    }

    /// == gl_mul(x, 2^k) (or gl_mul(x, p - 2^k) when `neg`) for x < p, by
    /// shifts and the same canonical reduction as `mul`. With
    /// x 2^k = L + 2^64 H (L = (x << k) mod 2^64, H = x 2^k >> 64 < 2^k),
    /// H = 2^32 H_hi + H_lo, 2^64 == EPS and 2^96 == -1 (mod p):
    ///   x 2^k == L + EPS H_lo - H_hi.
    ///   k <= 32:      H < 2^32, H_hi = 0:   r = (L mod p) + EPS H;
    ///   32 < k < 64:  H_hi = x >> (96-k):   r = ((L mod p) + EPS H_lo) - H_hi;
    ///   64 <= k < 96: L = 0, and with y = x 2^(k-64) < 2^95 (y_lo = the
    ///                 low 32 bits of x << (k-64), y_hi = x >> (96-k)):
    ///                 x 2^k = y 2^64 == EPS y_lo - y_hi.
    /// Every term is canonical (EPS * (< 2^32) < p; the shifted-down
    /// terms are < 2^63 < p; L mod p by one conditional subtract), so the
    /// `add` / `sub` contracts hold. The sign is folded into the final
    /// subtraction where there is one, else costs one (0 - r) mod p.
    #[inline(always)]
    unsafe fn mul_pow2(x: __m256i, w: Pw, k: K) -> __m256i {
        unsafe {
            if w.cls == 2 {
                let y = _mm256_sll_epi64(x, w.cl);
                let y_hi = _mm256_srl_epi64(x, w.c2);
                let e = mul32(y, k.eps);
                return if w.neg { sub(y_hi, e, k) } else { sub(e, y_hi, k) };
            }
            let l = _mm256_sll_epi64(x, w.cl);
            let h = _mm256_srl_epi64(x, w.cr);
            let e = mul32(h, k.eps);
            let c_ge = _mm256_cmpgt_epi64(_mm256_xor_si256(l, k.sign), k.pm1s);
            let c = _mm256_sub_epi64(l, _mm256_and_si256(c_ge, k.p));
            let s = add(c, e, k);
            if w.cls == 1 {
                let h_hi = _mm256_srl_epi64(x, w.c2);
                if w.neg { sub(h_hi, s, k) } else { sub(s, h_hi, k) }
            } else if w.neg {
                sub(_mm256_setzero_si256(), s, k)
            } else {
                s
            }
        }
    }

    /// The DIT butterfly with a +2^k twiddle: y = v 2^k, (u + y, u - y).
    /// (A -2^k twiddle is the same pair stored swapped — the stage loop
    /// swaps the store offsets per group.)
    #[inline(always)]
    unsafe fn dit_pow2(u: __m256i, v: __m256i, w: Pw, k: K) -> (__m256i, __m256i) {
        unsafe {
            let y = mul_pow2(v, w, k);
            (add(u, y, k), sub(u, y, k))
        }
    }

    /// The GS butterfly with a +2^k twiddle: (u + v, (u - v) 2^k). (A
    /// -2^k twiddle is the same butterfly on the swapped operands: (v + u,
    /// (v - u) 2^k) — the stage loop swaps the load offsets per group.)
    #[inline(always)]
    unsafe fn gs_pow2(u: __m256i, v: __m256i, w: Pw, k: K) -> (__m256i, __m256i) {
        unsafe { (add(u, v, k), mul_pow2(sub(u, v, k), w, k)) }
    }

    /// One forward outer stage: M groups of len = D / 2M, twiddle
    /// psi_brv[M + i] = +-2^k (the same (m, i, j) order as ntt_fwd_fast,
    /// four j at a time). Const M so the j loop has a fixed trip count.
    #[inline(always)]
    unsafe fn fwd_stage<const M: usize>(p: *mut u64, t: &NttTables, k: K) {
        let len = D / (2 * M);
        unsafe {
            for i in 0..M {
                let f = t.psi_pw2[M + i];
                let mut w = pw(f);
                w.neg = false;
                let (os, od) = if f.neg { (len, 0) } else { (0, len) };
                let j1 = 2 * i * len;
                let mut j = j1;
                while j < j1 + len {
                    let (s, d) = dit_pow2(ld(p, j), ld(p, j + len), w, k);
                    st(p, j + os, s);
                    st(p, j + od, d);
                    j += 4;
                }
            }
        }
    }

    /// One inverse outer stage: H groups of len = D / 2H, twiddle
    /// ipsi_brv[H + i] = +-2^k (the same (h, i, j) order as ntt_inv_fast).
    #[inline(always)]
    unsafe fn inv_stage<const H: usize>(p: *mut u64, t: &NttTables, k: K) {
        let len = D / (2 * H);
        unsafe {
            for i in 0..H {
                let f = t.ipsi_pw2[H + i];
                let mut w = pw(f);
                w.neg = false;
                let (ou, ov) = if f.neg { (len, 0) } else { (0, len) };
                let j1 = 2 * i * len;
                let mut j = j1;
                while j < j1 + len {
                    let (s, d) = gs_pow2(ld(p, j + ou), ld(p, j + ov), w, k);
                    st(p, j, s);
                    st(p, j + len, d);
                    j += 4;
                }
            }
        }
    }

    /// == ntt_fwd_fast on AVX2 (caller guarantees AVX2 is present).
    #[target_feature(enable = "avx2")]
    pub unsafe fn ntt_fwd(a: &mut [u64; D], t: &NttTables) {
        unsafe {
            let k = consts();
            let p = a.as_mut_ptr();
            // Stages m = 1..16 (len = 64..4): +-2^k twiddles.
            fwd_stage::<1>(p, t, k);
            fwd_stage::<2>(p, t, k);
            fwd_stage::<4>(p, t, k);
            fwd_stage::<8>(p, t, k);
            fwd_stage::<16>(p, t, k);
            // Stages m = 32 (len 2) and m = 64 (len 1), chained on the lane
            // split of a[8k..8k+8] = vectors (x, y):
            //   m = 32 pairs (a[8k+j], a[8k+2+j]) with s_2k and
            //              (a[8k+4+j], a[8k+6+j]) with s_2k+1, j < 2;
            //   m = 64 pairs (a[8k+2i], a[8k+2i+1]) with s'_4k+i, i < 4.
            for kk in 0..16 {
                let x = ld(p, 8 * kk);
                let y = ld(p, 8 * kk + 4);
                let u = _mm256_permute2x128_si256::<0x20>(x, y); // (a0, a1, a4, a5)
                let v = _mm256_permute2x128_si256::<0x31>(x, y); // (a2, a3, a6, a7)
                let tw = tw_load(t.psi_l2.as_ptr().add(4 * kk)); // (s_2k, s_2k, s_2k+1, s_2k+1)
                let (u, v) = dit(u, v, tw, k);
                let u2 = _mm256_unpacklo_epi64(u, v); // (a0, a2, a4, a6)
                let v2 = _mm256_unpackhi_epi64(u, v); // (a1, a3, a5, a7)
                let tw = tw_load(t.psi_brv.as_ptr().add(64 + 4 * kk)); // (s'_4k .. s'_4k+3)
                let (u2, v2) = dit(u2, v2, tw, k);
                let lo = _mm256_unpacklo_epi64(u2, v2); // (a0, a1, a4, a5)
                let hi = _mm256_unpackhi_epi64(u2, v2); // (a2, a3, a6, a7)
                st(p, 8 * kk, _mm256_permute2x128_si256::<0x20>(lo, hi));
                st(p, 8 * kk + 4, _mm256_permute2x128_si256::<0x31>(lo, hi));
            }
        }
    }

    /// == ntt_inv_fast on AVX2 (caller guarantees AVX2 is present).
    #[target_feature(enable = "avx2")]
    pub unsafe fn ntt_inv(a: &mut [u64; D], t: &NttTables) {
        unsafe {
            let k = consts();
            let p = a.as_mut_ptr();
            // Stages len = 1 (h = 64) and len = 2 (h = 32), chained on the
            // same lane split of a[8k..8k+8]:
            //   len 1 pairs (a[8k+2i], a[8k+2i+1]) with s'_4k+i (ipsi_brv[64 + 4k + i]);
            //   len 2 pairs (a[8k+j], a[8k+2+j]) with s_2k and
            //               (a[8k+4+j], a[8k+6+j]) with s_2k+1 (ipsi_brv[32 + ..]).
            for kk in 0..16 {
                let x = ld(p, 8 * kk);
                let y = ld(p, 8 * kk + 4);
                let lo = _mm256_permute2x128_si256::<0x20>(x, y); // (a0, a1, a4, a5)
                let hi = _mm256_permute2x128_si256::<0x31>(x, y); // (a2, a3, a6, a7)
                let u = _mm256_unpacklo_epi64(lo, hi); // (a0, a2, a4, a6)
                let v = _mm256_unpackhi_epi64(lo, hi); // (a1, a3, a5, a7)
                let tw = tw_load(t.ipsi_brv.as_ptr().add(64 + 4 * kk));
                let (u, v) = gs(u, v, tw, k);
                let u2 = _mm256_unpacklo_epi64(u, v); // (a0, a1, a4, a5)
                let v2 = _mm256_unpackhi_epi64(u, v); // (a2, a3, a6, a7)
                let tw = tw_load(t.ipsi_l2.as_ptr().add(4 * kk)); // (s_2k, s_2k, s_2k+1, s_2k+1)
                let (u2, v2) = gs(u2, v2, tw, k);
                st(p, 8 * kk, _mm256_permute2x128_si256::<0x20>(u2, v2)); // (a0, a1, a2, a3)
                st(p, 8 * kk + 4, _mm256_permute2x128_si256::<0x31>(u2, v2)); // (a4 .. a7)
            }
            // Stages len = 4..64 (h = 16..1): +-2^k twiddles.
            inv_stage::<16>(p, t, k);
            inv_stage::<8>(p, t, k);
            inv_stage::<4>(p, t, k);
            inv_stage::<2>(p, t, k);
            inv_stage::<1>(p, t, k);
            // Final scale by 1/n = -2^89.
            let w = pw(t.n_inv_pw2);
            let mut j = 0;
            while j < D {
                st(p, j, mul_pow2(ld(p, j), w, k));
                j += 4;
            }
        }
    }

    /// [UPERF2-M] acc[j] = (acc[j] + a[j] * b[j]) mod p, canonical, for
    /// j in 0..D — the NTT-domain multiply-accumulate of the eval-proof
    /// kernels on the same `mul` / `add` (a, b, acc canonical).
    #[target_feature(enable = "avx2")]
    pub unsafe fn mac(acc: &mut [u64; D], a: &[u64; D], b: &[u64; D]) {
        unsafe {
            let k = consts();
            let pa = a.as_ptr();
            let pb = b.as_ptr();
            let pc = acc.as_mut_ptr();
            let mut j = 0;
            while j < D {
                let prod = mul(ld(pa, j), tw_load(pb.add(j)), k);
                st(pc, j, add(ld(pc, j), prod, k));
                j += 4;
            }
        }
    }
}

/// [UPERF2-M] Canonical NTT-domain MAC on AVX2 lanes: acc[j] = (acc[j] +
/// a[j] * b[j]) mod p for j in 0..D (every operand and result canonical
/// in [0, p) — the same field elements the scalar `gl_add(acc, gl_mul(a,
/// b))` returns). The caller guarantees AVX2 (`simd_ntt_available()`).
#[cfg(target_arch = "x86_64")]
#[inline]
pub fn gl_mac_lanes_avx2(acc: &mut [u64; D], a: &[u64; D], b: &[u64; D]) {
    debug_assert!(std::arch::is_x86_feature_detected!("avx2"));
    // SAFETY: AVX2 present per the caller's contract; three fixed
    // [u64; 128] arrays, in-bounds loads/stores at offsets 0..128 step 4.
    unsafe { gl_avx2::mac(acc, a, b) }
}

/// [UPERF2-M] The scalar body of the canonical MAC (== the AVX2 lanes).
#[inline]
pub fn gl_mac_lanes_scalar(acc: &mut [u64; D], a: &[u64; D], b: &[u64; D]) {
    for j in 0..D {
        acc[j] = gl_add(acc[j], gl_mul(a[j], b[j]));
    }
}

/// [UPERF2-I] NEON body: 2 x u64 lanes, the AVX2 body's mirror
/// ([UNTESTED-NEON]: written for the Mac, compiled out on x86; the same
/// canonical arithmetic — `vcgtq_u64` gives the unsigned compares
/// directly, `vmull_u32` the 32 x 32 partial products, `vsliq_n_u64` the
/// low-word assembly). Stages with len >= 2 are whole-vector butterflies
/// with one broadcast twiddle per group; the len-1 stage (forward m = 64,
/// inverse h = 64) runs on a zip split of each 4-element block with
/// contiguous twiddle loads.
#[cfg(target_arch = "aarch64")]
mod gl_neon {
    use super::{NttTables, D, EPS, P};
    use core::arch::aarch64::*;

    #[derive(Clone, Copy)]
    struct K {
        p: uint64x2_t,
        pm1: uint64x2_t,
        eps: uint64x2_t,
        eps32: uint32x2_t,
    }

    #[inline(always)]
    unsafe fn consts() -> K {
        unsafe { K { p: vdupq_n_u64(P), pm1: vdupq_n_u64(P - 1), eps: vdupq_n_u64(EPS), eps32: vdup_n_u32(EPS as u32) } }
    }

    /// A twiddle operand: low and high 32-bit halves per lane.
    #[derive(Clone, Copy)]
    struct Tw {
        lo: uint32x2_t,
        hi: uint32x2_t,
    }

    #[inline(always)]
    unsafe fn tw_splat(w: u64) -> Tw {
        unsafe { Tw { lo: vdup_n_u32(w as u32), hi: vdup_n_u32((w >> 32) as u32) } }
    }

    #[inline(always)]
    unsafe fn tw_load(p: *const u64) -> Tw {
        unsafe {
            let w = vld1q_u64(p);
            Tw { lo: vmovn_u64(w), hi: vshrn_n_u64::<32>(w) }
        }
    }

    #[inline(always)]
    unsafe fn ld(a: *const u64, i: usize) -> uint64x2_t {
        unsafe { vld1q_u64(a.add(i)) }
    }

    #[inline(always)]
    unsafe fn st(a: *mut u64, i: usize, v: uint64x2_t) {
        unsafe { vst1q_u64(a.add(i), v) }
    }

    /// == gl_add (a, b < p): a + b - p when a > (p - 1) - b, else a + b.
    #[inline(always)]
    unsafe fn add(a: uint64x2_t, b: uint64x2_t, k: K) -> uint64x2_t {
        unsafe {
            let ge = vcgtq_u64(a, vsubq_u64(k.pm1, b));
            vsubq_u64(vaddq_u64(a, b), vandq_u64(ge, k.p))
        }
    }

    /// == gl_sub (a, b < p): a - b, plus p on borrow.
    #[inline(always)]
    unsafe fn sub(a: uint64x2_t, b: uint64x2_t, k: K) -> uint64x2_t {
        unsafe {
            let br = vcgtq_u64(b, a);
            vaddq_u64(vsubq_u64(a, b), vandq_u64(br, k.p))
        }
    }

    /// == gl_mul (a, w < p): the same 32-bit-column product and canonical
    /// reduction as the AVX2 body.
    #[inline(always)]
    unsafe fn mul(a: uint64x2_t, t: Tw, k: K) -> uint64x2_t {
        unsafe {
            let a_lo = vmovn_u64(a);
            let a_hi = vshrn_n_u64::<32>(a);
            let ll = vmull_u32(a_lo, t.lo);
            let lh = vmull_u32(a_lo, t.hi);
            let hl = vmull_u32(a_hi, t.lo);
            let hh = vmull_u32(a_hi, t.hi);
            let t0 = vaddq_u64(hl, vshrq_n_u64::<32>(ll));
            let t1 = vaddq_u64(lh, vandq_u64(t0, k.eps));
            let hi = vaddq_u64(vaddq_u64(hh, vshrq_n_u64::<32>(t0)), vshrq_n_u64::<32>(t1));
            let lo = vsliq_n_u64::<32>(ll, t1); // (ll & 0xFFFFFFFF) | (t1 << 32)
            let hi_hi = vshrq_n_u64::<32>(hi);
            let e = vmull_u32(vmovn_u64(hi), k.eps32); // hi_lo * EPS < p
            let c = vsubq_u64(lo, vandq_u64(vcgtq_u64(lo, k.pm1), k.p)); // lo mod p
            sub(add(c, e, k), hi_hi, k)
        }
    }

    #[inline(always)]
    unsafe fn dit(u: uint64x2_t, v: uint64x2_t, t: Tw, k: K) -> (uint64x2_t, uint64x2_t) {
        unsafe {
            let y = mul(v, t, k);
            (add(u, y, k), sub(u, y, k))
        }
    }

    #[inline(always)]
    unsafe fn gs(u: uint64x2_t, v: uint64x2_t, t: Tw, k: K) -> (uint64x2_t, uint64x2_t) {
        unsafe { (add(u, v, k), mul(sub(u, v, k), t, k)) }
    }

    /// A signed power-of-two twiddle +-2^k as NEON shift counts
    /// (`vshlq_u64` shifts each lane left by a signed count; a negative
    /// count shifts right; |count| >= 64 gives 0 — so the three counts
    /// below are one instruction each, no class-specific shift ops).
    #[derive(Clone, Copy)]
    struct Pw {
        cls: u8, // 0: k <= 32; 1: 32 < k < 64; 2: 64 <= k < 96
        neg: bool,
        cl: int64x2_t, // left by k (cls 0/1) or k - 64 (cls 2)
        cr: int64x2_t, // right by 64 - k (cls 0/1)
        c2: int64x2_t, // right by 96 - k (cls 1/2)
    }

    #[inline(always)]
    unsafe fn pw(f: super::Pw2) -> Pw {
        let k = f.k as i64;
        let cls = if k <= 32 { 0 } else if k < 64 { 1 } else { 2 };
        unsafe {
            Pw {
                cls,
                neg: f.neg,
                cl: vdupq_n_s64(if k >= 64 { k - 64 } else { k }),
                cr: vdupq_n_s64(k - 64),
                c2: vdupq_n_s64(k - 96),
            }
        }
    }

    /// == the AVX2 `mul_pow2` (same cases, same terms): x * (+-2^k) mod p.
    #[inline(always)]
    unsafe fn mul_pow2(x: uint64x2_t, w: Pw, k: K) -> uint64x2_t {
        unsafe {
            if w.cls == 2 {
                let y = vshlq_u64(x, w.cl);
                let y_hi = vshlq_u64(x, w.c2);
                let e = vmull_u32(vmovn_u64(y), k.eps32);
                return if w.neg { sub(y_hi, e, k) } else { sub(e, y_hi, k) };
            }
            let l = vshlq_u64(x, w.cl);
            let h = vshlq_u64(x, w.cr);
            let e = vmull_u32(vmovn_u64(h), k.eps32);
            let c = vsubq_u64(l, vandq_u64(vcgtq_u64(l, k.pm1), k.p));
            let s = add(c, e, k);
            if w.cls == 1 {
                let h_hi = vshlq_u64(x, w.c2);
                if w.neg { sub(h_hi, s, k) } else { sub(s, h_hi, k) }
            } else if w.neg {
                sub(vdupq_n_u64(0), s, k)
            } else {
                s
            }
        }
    }

    #[inline(always)]
    unsafe fn dit_pow2(u: uint64x2_t, v: uint64x2_t, w: Pw, k: K) -> (uint64x2_t, uint64x2_t) {
        unsafe {
            let y = mul_pow2(v, w, k);
            (add(u, y, k), sub(u, y, k))
        }
    }

    #[inline(always)]
    unsafe fn gs_pow2(u: uint64x2_t, v: uint64x2_t, w: Pw, k: K) -> (uint64x2_t, uint64x2_t) {
        unsafe { (add(u, v, k), mul_pow2(sub(u, v, k), w, k)) }
    }

    /// One forward outer stage (== the AVX2 `fwd_stage`, two j at a time;
    /// the sign of the twiddle swaps the store offsets per group).
    #[inline(always)]
    unsafe fn fwd_stage<const M: usize>(p: *mut u64, t: &NttTables, k: K) {
        let len = D / (2 * M);
        unsafe {
            for i in 0..M {
                let f = t.psi_pw2[M + i];
                let mut w = pw(f);
                w.neg = false;
                let (os, od) = if f.neg { (len, 0) } else { (0, len) };
                let j1 = 2 * i * len;
                let mut j = j1;
                while j < j1 + len {
                    let (s, d) = dit_pow2(ld(p, j), ld(p, j + len), w, k);
                    st(p, j + os, s);
                    st(p, j + od, d);
                    j += 2;
                }
            }
        }
    }

    /// One inverse outer stage (== the AVX2 `inv_stage`; the sign swaps
    /// the load offsets per group).
    #[inline(always)]
    unsafe fn inv_stage<const H: usize>(p: *mut u64, t: &NttTables, k: K) {
        let len = D / (2 * H);
        unsafe {
            for i in 0..H {
                let f = t.ipsi_pw2[H + i];
                let mut w = pw(f);
                w.neg = false;
                let (ou, ov) = if f.neg { (len, 0) } else { (0, len) };
                let j1 = 2 * i * len;
                let mut j = j1;
                while j < j1 + len {
                    let (s, d) = gs_pow2(ld(p, j + ou), ld(p, j + ov), w, k);
                    st(p, j, s);
                    st(p, j + len, d);
                    j += 2;
                }
            }
        }
    }

    /// == ntt_fwd_fast on NEON.
    pub unsafe fn ntt_fwd(a: &mut [u64; D], t: &NttTables) {
        unsafe {
            let k = consts();
            let p = a.as_mut_ptr();
            // Stages m = 1..16 (len = 64..4): +-2^k twiddles.
            fwd_stage::<1>(p, t, k);
            fwd_stage::<2>(p, t, k);
            fwd_stage::<4>(p, t, k);
            fwd_stage::<8>(p, t, k);
            fwd_stage::<16>(p, t, k);
            // Stage m = 32 (len 2): general twiddles psi_brv[32 + i], one
            // whole-vector butterfly per group: (a[4i], a[4i+1]) x (a[4i+2], a[4i+3]).
            for i in 0..32 {
                let tw = tw_splat(t.psi_brv[32 + i]);
                let (u, v) = dit(ld(p, 4 * i), ld(p, 4 * i + 2), tw, k);
                st(p, 4 * i, u);
                st(p, 4 * i + 2, v);
            }
            // Stage m = 64 (len 1): pairs (a[4k+2i], a[4k+2i+1]), i < 2,
            // twiddles psi_brv[64 + 2k + i], on the zip split of a[4k..4k+4].
            for kk in 0..32 {
                let x = ld(p, 4 * kk);
                let y = ld(p, 4 * kk + 2);
                let u = vzip1q_u64(x, y); // (a0, a2)
                let v = vzip2q_u64(x, y); // (a1, a3)
                let tw = tw_load(t.psi_brv.as_ptr().add(64 + 2 * kk));
                let (u, v) = dit(u, v, tw, k);
                st(p, 4 * kk, vzip1q_u64(u, v)); // (a0, a1)
                st(p, 4 * kk + 2, vzip2q_u64(u, v)); // (a2, a3)
            }
        }
    }

    /// == ntt_inv_fast on NEON.
    pub unsafe fn ntt_inv(a: &mut [u64; D], t: &NttTables) {
        unsafe {
            let k = consts();
            let p = a.as_mut_ptr();
            // Stage len = 1 (h = 64): the zip split, twiddles ipsi_brv[64 + 2k + i].
            for kk in 0..32 {
                let x = ld(p, 4 * kk);
                let y = ld(p, 4 * kk + 2);
                let u = vzip1q_u64(x, y); // (a0, a2)
                let v = vzip2q_u64(x, y); // (a1, a3)
                let tw = tw_load(t.ipsi_brv.as_ptr().add(64 + 2 * kk));
                let (u, v) = gs(u, v, tw, k);
                st(p, 4 * kk, vzip1q_u64(u, v));
                st(p, 4 * kk + 2, vzip2q_u64(u, v));
            }
            // Stage len = 2 (h = 32): general twiddles ipsi_brv[32 + i].
            for i in 0..32 {
                let tw = tw_splat(t.ipsi_brv[32 + i]);
                let (u, v) = gs(ld(p, 4 * i), ld(p, 4 * i + 2), tw, k);
                st(p, 4 * i, u);
                st(p, 4 * i + 2, v);
            }
            // Stages len = 4..64 (h = 16..1): +-2^k twiddles.
            inv_stage::<16>(p, t, k);
            inv_stage::<8>(p, t, k);
            inv_stage::<4>(p, t, k);
            inv_stage::<2>(p, t, k);
            inv_stage::<1>(p, t, k);
            // Final scale by 1/n = -2^89.
            let w = pw(t.n_inv_pw2);
            let mut j = 0;
            while j < D {
                st(p, j, mul_pow2(ld(p, j), w, k));
                j += 2;
            }
        }
    }
}

/// Negacyclic product over Z_p via NTT (the A1 primitive).
pub fn negacyclic_mul_p(a: &[u64; D], b: &[u64; D], t: &NttTables) -> [u64; D] {
    let mut fa = *a;
    let mut fb = *b;
    ntt_fwd(&mut fa, t);
    ntt_fwd(&mut fb, t);
    let mut fc = [0u64; D];
    for i in 0..D {
        fc[i] = mul_p(fa[i], fb[i]);
    }
    ntt_inv(&mut fc, t);
    fc
}

/// Reference: negacyclic schoolbook over Z_p (per-product reduction, then
/// u128 accumulation of reduced values — exact for any inputs < p).
pub fn negacyclic_schoolbook_p(a: &[u64; D], b: &[u64; D]) -> [u64; D] {
    let mut pos = [0u128; D];
    let mut neg = [0u128; D];
    for i in 0..D {
        if a[i] == 0 {
            continue;
        }
        for j in 0..D {
            let prod = mul_p(a[i], b[j]) as u128;
            let k = i + j;
            if k < D {
                pos[k] += prod;
            } else {
                neg[k - D] += prod;
            }
        }
    }
    let mut out = [0u64; D];
    for k in 0..D {
        out[k] = sub_p(reduce128(pos[k]), reduce128(neg[k]));
    }
    out
}

// ---------------------------------------------------------------------------
// Lifts between the protocol domain (balanced representatives mod q) and the
// helper domain Z_p, plus exact recovery.
//
// The exact-integer contract: if every coefficient of the true integer
// product/accumulation satisfies |c| <= (p-1)/2, then its value mod p
// determines it uniquely, and `center_from_p` recovers it. Whether the
// contract holds is a static property of the operand-norm regime — the
// capacity analysis below — never of the data.

/// Balanced representative of v mod q, |result| <= (q-1)/2.
#[inline(always)]
pub fn balanced_mod_q(v: u64, q: u64) -> i64 {
    if v > q / 2 { v as i64 - q as i64 } else { v as i64 }
}

/// Lift a balanced integer (|v| < p/2) into Z_p.
#[inline(always)]
pub fn lift_to_p(v: i64) -> u64 {
    if v >= 0 { v as u64 } else { P.wrapping_sub(v.unsigned_abs()) }
}

/// Centered representative of u in Z_p, in (-(p-1)/2, (p-1)/2].
#[inline(always)]
pub fn center_from_p(u: u64) -> i128 {
    if u > P / 2 { u as i128 - P as i128 } else { u as i128 }
}

/// Reduce an exact integer to [0, q).
#[inline(always)]
pub fn mod_q_i128(x: i128, q: u64) -> u64 {
    let r = x % q as i128;
    if r < 0 { (r + q as i128) as u64 } else { r as u64 }
}

/// Reduce a centered value |x| < 2^63 to [0, q) with a single u64 division
/// (the i128 remainder is a slow libcall; every recovered Z_p value is
/// centered below 2^63 by the capacity contract).
#[inline(always)]
pub fn mod_q_centered(x: i128, q: u64) -> u64 {
    debug_assert!(x.unsigned_abs() < 1 << 63);
    let r = (x.unsigned_abs() as u64) % q;
    if x < 0 && r != 0 { q - r } else { r }
}

// ---------------------------------------------------------------------------
// Capacity analysis. Exact u128 checks of the single-prime contract
//     n_acc * d * A * B <= (p-1)/2
// where A, B are the operand magnitude bounds (balanced representatives) and
// n_acc is how many ring products are accumulated before leaving the NTT
// domain (the module dimension N_r for the commit kernel).

/// Returns (fits_single_prime, bit_length_of_bound). Exact integer math.
pub fn capacity(n_acc: u128, a_max: u128, b_max: u128) -> (bool, u32) {
    // Largest case used: 2^11 * 2^7 * 2^45 * 2^45 = 2^108 — no u128 overflow.
    let bound = n_acc
        .checked_mul(D as u128)
        .and_then(|x| x.checked_mul(a_max))
        .and_then(|x| x.checked_mul(b_max))
        .expect("capacity bound overflows u128 — regime out of scope");
    (bound <= (P as u128 - 1) / 2, 128 - bound.leading_zeros())
}

/// Largest n_acc that keeps the single-prime contract for (A, B).
pub fn max_n_acc(a_max: u128, b_max: u128) -> u128 {
    (P as u128 - 1) / 2 / (D as u128) / a_max / b_max
}

// ---------------------------------------------------------------------------
// Mod-q scalar helpers (used by the limb recompose and the k = 2 baselines).

pub fn mul_q(a: u64, b: u64, q: u64) -> u64 {
    ((a as u128 * b as u128) % q as u128) as u64
}

pub fn pow_q(mut base: u64, mut e: u64, q: u64) -> u64 {
    let mut acc = 1u64;
    while e > 0 {
        if e & 1 == 1 {
            acc = mul_q(acc, base, q);
        }
        base = mul_q(base, base, q);
        e >>= 1;
    }
    acc
}

/// sqrt(-1) mod q for q = 5 mod 8: 2^((q-1)/4) works because 2 is a
/// quadratic nonresidue there; asserted on construction.
pub fn sqrt_m1(q: u64) -> u64 {
    let r = pow_q(2, (q - 1) / 4, q);
    assert_eq!(mul_q(r, r, q), q - 1, "sqrt(-1) construction failed");
    r
}

// ---------------------------------------------------------------------------
// The general-regime fallback: balanced limb-splitting with 3 Karatsuba
// sub-products over the SAME Goldilocks prime (chosen over two-prime CRT:
// op counts are a wash — 3 Goldilocks pointwise muls vs 1 Goldilocks + 1
// Montgomery mul + Garner reconstruction — and limb-split reuses the one
// NTT/reduction path; estimate documented in A1_AUX_NTT_REPORT.md).
//
// a = a1*2^L + a0 with |a0| <= 2^(L-1), |a1| <= q/2^(L+1) + 1; likewise b.
//   a*b = P0 + 2^L*(PM - P0 - P2) + 2^2L*P2,  P0 = a0 b0, P2 = a1 b1,
//   PM = (a0+a1)(b0+b1).
// The mid transform comes from NTT linearity (NTT(a0)+NTT(a1)) — only 2
// forward transforms per operand. Recombination MUST happen on exact
// integers (3 inverse transforms, centered recovery), then mod q: scaling
// by 2^L / 2^2L inside Z_p would overflow the capacity contract.

/// Limb size: half the bit length of (q-1)/2, rounded up.
pub fn limb_bits(q: u64) -> u32 {
    let bits = 64 - ((q - 1) / 2).leading_zeros();
    bits.div_ceil(2)
}

/// Split a balanced value into balanced limbs (v = hi*2^L + lo).
#[inline(always)]
pub fn split_limbs(v: i64, l: u32) -> (i64, i64) {
    let half = 1i64 << (l - 1);
    let full = 1i64 << l;
    let lo = (v % full + full + half) % full - half; // balanced remainder
    let hi = (v - lo) >> l;
    (lo, hi)
}

/// General mod-q x mod-q negacyclic ring product via the limb-split path.
/// Inputs/outputs in [0, q). Exact for any q with limb sub-products inside
/// the capacity contract (checked once by the caller/self-test).
pub fn ring_mul_q_limbsplit(a: &[u64], b: &[u64], q: u64, t: &NttTables) -> Vec<u64> {
    let l = limb_bits(q);
    let mut a0 = [0u64; D];
    let mut a1 = [0u64; D];
    let mut b0 = [0u64; D];
    let mut b1 = [0u64; D];
    for i in 0..D {
        let (lo, hi) = split_limbs(balanced_mod_q(a[i], q), l);
        a0[i] = lift_to_p(lo);
        a1[i] = lift_to_p(hi);
        let (lo, hi) = split_limbs(balanced_mod_q(b[i], q), l);
        b0[i] = lift_to_p(lo);
        b1[i] = lift_to_p(hi);
    }
    ntt_fwd(&mut a0, t);
    ntt_fwd(&mut a1, t);
    ntt_fwd(&mut b0, t);
    ntt_fwd(&mut b1, t);
    let mut p0 = [0u64; D];
    let mut p2 = [0u64; D];
    let mut pm = [0u64; D];
    for i in 0..D {
        p0[i] = mul_p(a0[i], b0[i]);
        p2[i] = mul_p(a1[i], b1[i]);
        pm[i] = mul_p(add_p(a0[i], a1[i]), add_p(b0[i], b1[i]));
    }
    ntt_inv(&mut p0, t);
    ntt_inv(&mut p2, t);
    ntt_inv(&mut pm, t);
    // Recompose mod q: each recovered sub-product is exact (|v| <= d*2^2L
    // <= 2^53 at q46), so reduce each mod q and combine with 2^L, 2^2L mod q.
    let two_l = (1u64 << l) % q;
    let two_2l = mul_q(two_l, two_l, q);
    let mut out = vec![0u64; D];
    for k in 0..D {
        let v0 = mod_q_centered(center_from_p(p0[k]), q);
        let v2 = mod_q_centered(center_from_p(p2[k]), q);
        let vm = mod_q_centered(center_from_p(pm[k]), q);
        // mid = vm - v0 - v2 (mod q); all sums stay far below 2^63.
        let mid = (vm + 2 * q - v0 - v2) % q;
        out[k] = (v0 + mul_q(two_l, mid, q) + mul_q(two_2l, v2, q)) % q;
    }
    out
}

/// Short-operand (regime a/b') single-prime ring product: a general mod q,
/// b balanced small (|b| <= b_max with d*q/2*b_max within capacity).
pub fn ring_mul_q_single(a: &[u64], b_small: &[i64], q: u64, t: &NttTables) -> Vec<u64> {
    let mut fa = [0u64; D];
    let mut fb = [0u64; D];
    for i in 0..D {
        fa[i] = lift_to_p(balanced_mod_q(a[i], q));
        fb[i] = lift_to_p(b_small[i]);
    }
    ntt_fwd(&mut fa, t);
    ntt_fwd(&mut fb, t);
    let mut fc = [0u64; D];
    for i in 0..D {
        fc[i] = mul_p(fa[i], fb[i]);
    }
    ntt_inv(&mut fc, t);
    fc.iter().map(|&u| mod_q_centered(center_from_p(u), q)).collect()
}

/// Ternary-specialized schoolbook single ring mult (regime (a) operands,
/// the Tier-1 add/sub lever): skip zeros, add/sub key coefficients in i128.
pub fn ring_mul_q_ternary_schoolbook(a: &[u64], b: &[i64], q: u64) -> Vec<u64> {
    let mut acc = [0i128; D];
    for i in 0..D {
        let xi = b[i];
        if xi == 0 {
            continue;
        }
        if xi == 1 {
            for j in 0..D {
                let k = i + j;
                if k < D {
                    acc[k] += a[j] as i128;
                } else {
                    acc[k - D] -= a[j] as i128;
                }
            }
        } else {
            for j in 0..D {
                let k = i + j;
                if k < D {
                    acc[k] -= a[j] as i128;
                } else {
                    acc[k - D] += a[j] as i128;
                }
            }
        }
    }
    acc.iter().map(|&v| mod_q_centered(v, q)).collect()
}

/// Reference: negacyclic schoolbook mod q, inputs in [0, q). u128 lazy
/// accumulation is exact: 128 * (q46-1)^2 < 2^99.
pub fn ring_mul_q_schoolbook(a: &[u64], b: &[u64], q: u64) -> Vec<u64> {
    let mut pos = [0u128; D];
    let mut neg = [0u128; D];
    for i in 0..D {
        if a[i] == 0 {
            continue;
        }
        for j in 0..D {
            let prod = a[i] as u128 * b[j] as u128;
            let k = i + j;
            if k < D {
                pos[k] += prod;
            } else {
                neg[k - D] += prod;
            }
        }
    }
    (0..D)
        .map(|k| {
            let p = (pos[k] % q as u128) as u64;
            let n = (neg[k] % q as u128) as u64;
            if p >= n { p - n } else { p + q - n }
        })
        .collect()
}

// ---------------------------------------------------------------------------
// The GEMM-shaped commitment kernel. C = G * R over R_q, where
// G ((kappa + msg_r) x N_r) is the FIXED commitment key and R packs many
// bounded columns (N_r ring elements each): ternary randomness (regime a,
// the dominant LLM-scale cost), Gaussian masks (regime b), digit witnesses.
//
// A1 evaluation: transform G once (cached), transform each column of R once,
// multiply-accumulate POINTWISE in the NTT domain, one inverse transform per
// output element, centered recovery, reduce mod q.
//
// Accumulator discipline: NTT-domain values are < 2^64, so a raw pointwise
// product fills a u128 and two of them cannot be added there. Split-halves
// lazy accumulation: accumulate the LOW and HIGH 64-bit halves of each raw
// product in separate u128s (no per-product reduction — one widening mul and
// two adds per term). Since 2^64 = EPS (mod p), the sum is recovered as
// reduce128(acc_lo + EPS * acc_hi), exact while acc_hi < 2^96 — i.e. for up
// to ~2^31 accumulated terms, and N_r <= 72 here. The EXACT-INTEGER contract
// (coefficients of the true integer result < p/2) is asserted from the
// regime bound at construction, never assumed from data; the worst-case
// self-tests drive the accumulator to the exact bound.

pub struct A1CommitKernel {
    pub rows: usize,
    pub inner: usize,
    pub q: u64,
    pub b_max: u128, // column-operand contract bound (|column coeff| <= b_max)
    g_hat: Vec<[u64; D]>, // rows * inner cached forward transforms
}

impl A1CommitKernel {
    /// g: rows*inner ring elements (row-major, coefficients in [0, q)).
    /// b_max is the CONTRACT bound on the column operands this kernel will
    /// ever see (1 for ternary/binary randomness, 12*sigma for Gaussian
    /// masks, ...). The single-prime capacity contract
    /// inner * d * (q-1)/2 * b_max <= (p-1)/2 is asserted here — a static
    /// regime property.
    pub fn new(g: &[Vec<u64>], rows: usize, inner: usize, q: u64, b_max: u128, t: &NttTables) -> Self {
        let (fits, bits) = capacity(inner as u128, ((q - 1) / 2) as u128, b_max);
        assert!(
            fits,
            "A1 commit kernel outside single-prime capacity ({bits} bits; n_acc={inner}, b_max={b_max}) — use A1GemmKernel for automatic limb-split fallback"
        );
        let g_hat = g
            .iter()
            .map(|poly| {
                let mut f = [0u64; D];
                for i in 0..D {
                    f[i] = lift_to_p(balanced_mod_q(poly[i], q));
                }
                ntt_fwd(&mut f, t);
                f
            })
            .collect();
        A1CommitKernel { rows, inner, q, b_max, g_hat }
    }

    /// Bytes held by the cached NTT-domain key rows.
    pub fn cached_bytes(&self) -> usize {
        self.g_hat.len() * D * 8
    }

    /// One column of R (inner bounded ring elements, |coeff| <= b_max) ->
    /// rows output elements.
    pub fn commit_column(&self, r_col: &[Vec<i64>], t: &NttTables) -> Vec<Vec<u64>> {
        debug_assert_eq!(r_col.len(), self.inner);
        // Forward transforms of the column (once per column, shared by rows).
        let r_hat: Vec<[u64; D]> = r_col
            .iter()
            .map(|poly| {
                let mut f = [0u64; D];
                for i in 0..D {
                    debug_assert!(poly[i].unsigned_abs() as u128 <= self.b_max);
                    f[i] = lift_to_p(poly[i]);
                }
                ntt_fwd(&mut f, t);
                f
            })
            .collect();
        (0..self.rows)
            .map(|row| {
                let mut acc_lo = [0u128; D];
                let mut acc_hi = [0u128; D];
                for c in 0..self.inner {
                    let gh = &self.g_hat[row * self.inner + c];
                    let rh = &r_hat[c];
                    for k in 0..D {
                        let prod = gh[k] as u128 * rh[k] as u128;
                        acc_lo[k] += prod as u64 as u128;
                        acc_hi[k] += (prod >> 64) as u128;
                    }
                }
                let mut v = [0u64; D];
                for k in 0..D {
                    // sum = acc_lo + 2^64*acc_hi = acc_lo + EPS*acc_hi (mod p);
                    // < 2^71 + 2^103 at N_r = 72 — fits u128 with margin.
                    v[k] = reduce128(acc_lo[k] + EPS as u128 * acc_hi[k]);
                }
                ntt_inv(&mut v, t);
                v.iter().map(|&u| mod_q_centered(center_from_p(u), self.q)).collect()
            })
            .collect()
    }
}

/// A1 commit kernel for the GENERAL/bounded regime (regime (b)/(c) columns —
/// e.g. Gaussian mask commitments at q46, where key x mask exceeds one
/// prime): both operands limb-split, 3 Karatsuba sub-products, all three
/// accumulated in the NTT domain (the sub-product bounds leave ~10+ bits of
/// headroom, so the full module dimension accumulates in-domain), 3 inverse
/// transforms per output element, exact recompose mod q.
///
/// Cached per key element: 3 transforms (lo, hi, lo+hi). Per column element:
/// 2 forward transforms + one NTT-domain add (linearity gives the mid
/// transform). Pointwise: 3 muls per coefficient per term.
pub struct A1LimbCommitKernel {
    pub rows: usize,
    pub inner: usize,
    pub q: u64,
    pub b_max: u128,
    l: u32,                    // COMMON limb base (Karatsuba needs one base)
    g_hat: Vec<[[u64; D]; 3]>, // per key element: [lo, hi, lo+hi] transforms
}

impl A1LimbCommitKernel {
    pub fn new(g: &[Vec<u64>], rows: usize, inner: usize, q: u64, b_max: u128, t: &NttTables) -> Self {
        // One base for BOTH operands: with a = a1*2^l + a0, b = b1*2^l + b0,
        // PM - P0 - P2 = a0 b1 + a1 b0 carries the single scale 2^l only if
        // both splits use the same l. l halves the key (the wider operand).
        let l = limb_bits(q);
        // PM dominates capacity: operand bounds are sums of the limb bounds.
        let a_pm = (1u128 << (l - 1)) + (((q as u128 - 1) / 2 + (1u128 << (l - 1))) >> l) + 1;
        let b_pm = (1u128 << (l - 1)) + ((b_max + (1u128 << (l - 1))) >> l) + 1;
        let (fits, bits) = capacity(inner as u128, a_pm, b_pm);
        assert!(
            fits,
            "limb commit kernel outside capacity ({bits} bits; n_acc={inner}, b_max={b_max}) — parameter regime fits NOTHING; the derive-time chain must reject it"
        );
        let g_hat = g
            .iter()
            .map(|poly| {
                let mut lo = [0u64; D];
                let mut hi = [0u64; D];
                let mut mid = [0u64; D];
                for i in 0..D {
                    let (lv, hv) = split_limbs(balanced_mod_q(poly[i], q), l);
                    lo[i] = lift_to_p(lv);
                    hi[i] = lift_to_p(hv);
                }
                ntt_fwd(&mut lo, t);
                ntt_fwd(&mut hi, t);
                for i in 0..D {
                    mid[i] = add_p(lo[i], hi[i]);
                }
                [lo, hi, mid]
            })
            .collect();
        A1LimbCommitKernel { rows, inner, q, b_max, l, g_hat }
    }

    pub fn cached_bytes(&self) -> usize {
        self.g_hat.len() * 3 * D * 8
    }

    /// One column of bounded integer ring elements (|v| <= b_max).
    pub fn commit_column(&self, col: &[Vec<i64>], t: &NttTables) -> Vec<Vec<u64>> {
        debug_assert_eq!(col.len(), self.inner);
        let col_hat: Vec<[[u64; D]; 3]> = col
            .iter()
            .map(|poly| {
                let mut lo = [0u64; D];
                let mut hi = [0u64; D];
                let mut mid = [0u64; D];
                for i in 0..D {
                    debug_assert!(poly[i].unsigned_abs() as u128 <= self.b_max);
                    let (lv, hv) = split_limbs(poly[i], self.l);
                    lo[i] = lift_to_p(lv);
                    hi[i] = lift_to_p(hv);
                }
                ntt_fwd(&mut lo, t);
                ntt_fwd(&mut hi, t);
                for i in 0..D {
                    mid[i] = add_p(lo[i], hi[i]);
                }
                [lo, hi, mid]
            })
            .collect();
        let q = self.q;
        let two_l = (1u64 << self.l) % q;
        let two_2l = mul_q(two_l, two_l, q);
        (0..self.rows)
            .map(|row| {
                let mut acc = [[[0u128; D]; 2]; 3]; // [P0|P2|PM][lo|hi][k]
                for c in 0..self.inner {
                    let gh = &self.g_hat[row * self.inner + c];
                    let rh = &col_hat[c];
                    for s in 0..3 {
                        for k in 0..D {
                            let prod = gh[s][k] as u128 * rh[s][k] as u128;
                            acc[s][0][k] += prod as u64 as u128;
                            acc[s][1][k] += (prod >> 64) as u128;
                        }
                    }
                }
                let mut parts = [[0u64; D]; 3];
                for s in 0..3 {
                    let mut v = [0u64; D];
                    for k in 0..D {
                        v[k] = reduce128(acc[s][0][k] + EPS as u128 * acc[s][1][k]);
                    }
                    ntt_inv(&mut v, t);
                    parts[s] = v;
                }
                (0..D)
                    .map(|k| {
                        let v0 = mod_q_centered(center_from_p(parts[0][k]), q);
                        let v2 = mod_q_centered(center_from_p(parts[1][k]), q);
                        let vm = mod_q_centered(center_from_p(parts[2][k]), q);
                        let mid = (vm + 2 * q - v0 - v2) % q;
                        (v0 + mul_q(two_l, mid, q) + mul_q(two_2l, v2, q)) % q
                    })
                    .collect()
            })
            .collect()
    }
}

// ---------------------------------------------------------------------------
// Regime-dispatching kernel: the integration entry point. Chooses the
// single-prime path when the (n_acc, q, b_max) regime fits the capacity
// contract and falls back to the limb-split path AUTOMATICALLY otherwise —
// over-capacity regimes are an expected configuration (e.g. Gaussian masks
// at q46, verifier response bounds at q31), never a panic. Construction
// panics only if the regime fits NOTHING (even limb sub-products overflow),
// which the derive-time parameter chain must have rejected already.

pub enum A1GemmKernel {
    Single(A1CommitKernel),
    Limb(A1LimbCommitKernel),
}

impl A1GemmKernel {
    pub fn new(g: &[Vec<u64>], rows: usize, inner: usize, q: u64, b_max: u128, t: &NttTables) -> Self {
        let (fits_single, _) = capacity(inner as u128, ((q - 1) / 2) as u128, b_max);
        if fits_single {
            A1GemmKernel::Single(A1CommitKernel::new(g, rows, inner, q, b_max, t))
        } else {
            A1GemmKernel::Limb(A1LimbCommitKernel::new(g, rows, inner, q, b_max, t))
        }
    }

    pub fn commit_column(&self, col: &[Vec<i64>], t: &NttTables) -> Vec<Vec<u64>> {
        match self {
            A1GemmKernel::Single(k) => k.commit_column(col, t),
            A1GemmKernel::Limb(k) => k.commit_column(col, t),
        }
    }

    pub fn path(&self) -> &'static str {
        match self {
            A1GemmKernel::Single(_) => "single-prime",
            A1GemmKernel::Limb(_) => "limb-split x3",
        }
    }

    pub fn cached_bytes(&self) -> usize {
        match self {
            A1GemmKernel::Single(k) => k.cached_bytes(),
            A1GemmKernel::Limb(k) => k.cached_bytes(),
        }
    }
}

/// The path `A1GemmKernel::new` would choose for a regime, without building
/// anything: `Some("single-prime" | "limb-split x3")`, or `None` if the
/// regime fits nothing (derive-time chains use this to fail loudly).
pub fn a1_regime_path(n_acc: usize, q: u64, b_max: u128) -> Option<&'static str> {
    if capacity(n_acc as u128, ((q - 1) / 2) as u128, b_max).0 {
        return Some("single-prime");
    }
    let l = limb_bits(q);
    let a_pm = (1u128 << (l - 1)) + (((q as u128 - 1) / 2 + (1u128 << (l - 1))) >> l) + 1;
    let b_pm = (1u128 << (l - 1)) + ((b_max + (1u128 << (l - 1))) >> l) + 1;
    if capacity(n_acc as u128, a_pm, b_pm).0 { Some("limb-split x3") } else { None }
}

// ---------------------------------------------------------------------------
// Regime (b'): challenge-combination sums. sum_i s_i * a_i over R_q with
// small s_i (|s| <= s_max, e.g. quinary challenges) and general mod-q a_i.
// Single-prime NTT-domain accumulation, AUTOMATICALLY chunked at the
// capacity-derived term limit (1023 terms at q46; ~2^25 at q31) with exact
// recovery + partial mod-q reduction between chunks. Panics only if even a
// single term exceeds capacity — a derive-time parameter failure, not a
// data condition (quinary s_max = 2 fits any q below ~2^54).

pub fn a1_combination_sum(a: &[Vec<u64>], s: &[Vec<i64>], s_max: u128, q: u64, t: &NttTables) -> Vec<u64> {
    assert_eq!(a.len(), s.len());
    let n_max = max_n_acc(((q - 1) / 2) as u128, s_max).min(1 << 31);
    assert!(
        n_max >= 1,
        "combination-sum single term exceeds single-prime capacity (s_max={s_max}) — the derive-time chain must reject this regime"
    );
    let n_max = n_max as usize;
    let mut out = vec![0u64; D];
    let mut idx = 0;
    while idx < a.len() {
        let end = (idx + n_max).min(a.len());
        let mut acc_lo = [0u128; D];
        let mut acc_hi = [0u128; D];
        for i in idx..end {
            let mut fa = [0u64; D];
            let mut fs = [0u64; D];
            for k in 0..D {
                fa[k] = lift_to_p(balanced_mod_q(a[i][k], q));
                debug_assert!(s[i][k].unsigned_abs() as u128 <= s_max);
                fs[k] = lift_to_p(s[i][k]);
            }
            ntt_fwd(&mut fa, t);
            ntt_fwd(&mut fs, t);
            for k in 0..D {
                let prod = fa[k] as u128 * fs[k] as u128;
                acc_lo[k] += prod as u64 as u128;
                acc_hi[k] += (prod >> 64) as u128;
            }
        }
        let mut v = [0u64; D];
        for k in 0..D {
            v[k] = reduce128(acc_lo[k] + EPS as u128 * acc_hi[k]);
        }
        ntt_inv(&mut v, t);
        for k in 0..D {
            let c = mod_q_centered(center_from_p(v[k]), q);
            let sum = out[k] + c;
            out[k] = if sum >= q { sum - q } else { sum };
        }
        idx = end;
    }
    out
}

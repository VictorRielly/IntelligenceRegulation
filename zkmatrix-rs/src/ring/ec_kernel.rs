//! [UPERF3-DD] Stage A round 4 — the production E_c MAC kernels.
//!
//! The spike's E_4 kernel runs ~8x below K9's MAC throughput (spike
//! report §5: "kernel quality is the open wall risk"), so the counted
//! 13.5x zero-check advantage lands as a measured 1.6x wall. This
//! module closes the gap with explicit AVX2 paths for the four MAC
//! families of `zc_range` (u32 x u32 -> u64 widening MACs into split
//! lo/hi u64 planes; KL = 8 lanes per block), runtime-detected, with
//! the scalar bodies in zc_range.rs as the byte-identity oracle — the
//! arithmetic is exact integers accumulated in the same order-free
//! split-plane form, so outputs are IDENTICAL by construction and the
//! uperf-s 48-leg battery digest must not move.
//!
//! `uperf-s kernel-bench [c] [log2_pairs] [reps]` prints the ns/MAC
//! table (scalar vs avx2 per family) — the rung-0/1 record.

use super::kfield::KL;
use super::zc_range::{e_mac, e_mac_base, e_mac_base_fixed, e_mac_fixed};
use std::time::Instant;

/// AVX2 availability, checked once.
pub fn avx2() -> bool {
    #[cfg(target_arch = "x86_64")]
    {
        is_x86_feature_detected!("avx2")
    }
    #[cfg(not(target_arch = "x86_64"))]
    {
        false
    }
}

/// The dispatch decision, cached: AVX2 present and not disabled by
/// `ZK_EC_SCALAR=1` (the A/B + debugging kill-switch).
pub fn avx2_active() -> bool {
    static F: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *F.get_or_init(|| avx2() && std::env::var("ZK_EC_SCALAR").map_or(true, |v| v != "1"))
}

// The auto-dispatched family (the zc_range call sites; byte-identical
// paths, so the uperf-s battery digest is invariant to the dispatch).
#[inline(always)]
pub fn mac_auto(c: usize, a: &[u32], b: &[u32], lo: &mut [u64], hi: &mut [u64]) {
    mac(c, a, b, lo, hi, avx2_active());
}
#[inline(always)]
pub fn mac_base_auto(c: usize, a: &[u32], f: &[u32; KL], lo: &mut [u64], hi: &mut [u64]) {
    mac_base(c, a, f, lo, hi, avx2_active());
}
#[inline(always)]
pub fn mac_fixed_auto(c: usize, a: &[u32], r: &[u32], lo: &mut [u64], hi: &mut [u64]) {
    mac_fixed(c, a, r, lo, hi, avx2_active());
}
#[inline(always)]
pub fn mac_base_fixed_auto(c: usize, a: &[u32; KL], r: &[u32], lo: &mut [u64], hi: &mut [u64]) {
    mac_base_fixed(c, a, r, lo, hi, avx2_active());
}

// ---------------------------------------------------------------------------
// AVX2 bodies. Layout: an E element is c * KL u32 (lane-blocked); the
// accumulator planes are (2c-1) * KL u64 (e_mac/e_mac_fixed) or c * KL
// u64 (the base families). KL = 8: one lane block = 8 u32 = 32 bytes =
// one 256-bit load; products split into 4-lane u64 halves via
// _mm256_mul_epu32 on the even/odd u32 positions.
// ---------------------------------------------------------------------------

#[cfg(target_arch = "x86_64")]
mod avx {
    use super::KL;
    #[cfg(target_arch = "x86_64")]
    use std::arch::x86_64::*;

    const M32V: i64 = 0xFFFF_FFFF;

    /// One lane block: lo/hi[base..base+KL] += a[ab..ab+KL] * b[bb..bb+KL]
    /// (elementwise u32 x u32 -> u64, split). Caller guarantees AVX2.
    #[inline(always)]
    unsafe fn mac_block(a: *const u32, b: *const u32, lo: *mut u64, hi: *mut u64) {
        unsafe {
            let av = _mm256_loadu_si256(a.cast());
            let bv = _mm256_loadu_si256(b.cast());
            let mask = _mm256_set1_epi64x(M32V);
            // even u32 lanes (0,2,4,6) as u64 products
            let pe = _mm256_mul_epu32(av, bv);
            // odd u32 lanes shifted down
            let ao = _mm256_srli_epi64::<32>(av);
            let bo = _mm256_srli_epi64::<32>(bv);
            let po = _mm256_mul_epu32(ao, bo);
            // split planes: interleave back to lane order. Lane l of the
            // output = product of u32 lane l. Even products pe cover
            // lanes 0,2,4,6; odd po cover 1,3,5,7. Store as two
            // interleaved u64x4 groups: unpack keeps 128-bit halves, so
            // recombine via unpacklo/hi on the 64-bit granulariy.
            let lo_e = _mm256_and_si256(pe, mask);
            let hi_e = _mm256_srli_epi64::<32>(pe);
            let lo_o = _mm256_and_si256(po, mask);
            let hi_o = _mm256_srli_epi64::<32>(po);
            // lanes (0,2,4,6) and (1,3,5,7) -> accumulate into
            // lo[0..8]/hi[0..8] at positions matching the scalar order:
            // scalar index l maps even l -> lo_e lane l/2, odd l ->
            // lo_o lane l/2. unpacklo_epi64(lo_e, lo_o) gives lanes
            // (0,1,4,5); unpackhi gives (2,3,6,7).
            let l01 = _mm256_unpacklo_epi64(lo_e, lo_o);
            let l23 = _mm256_unpackhi_epi64(lo_e, lo_o);
            let h01 = _mm256_unpacklo_epi64(hi_e, hi_o);
            let h23 = _mm256_unpackhi_epi64(hi_e, hi_o);
            let a0 = _mm256_loadu_si256(lo.cast());
            let a1 = _mm256_loadu_si256(lo.add(4).cast());
            let b0 = _mm256_loadu_si256(hi.cast());
            let b1 = _mm256_loadu_si256(hi.add(4).cast());
            // memory order for unpack pairs: l01 holds lanes 0,1,4,5 and
            // l23 lanes 2,3,6,7 — permute into linear 0..3 / 4..7.
            let lin0 = _mm256_permute2x128_si256::<0x20>(l01, l23); // 0,1,2,3
            let lin1 = _mm256_permute2x128_si256::<0x31>(l01, l23); // 4,5,6,7
            let hin0 = _mm256_permute2x128_si256::<0x20>(h01, h23);
            let hin1 = _mm256_permute2x128_si256::<0x31>(h01, h23);
            _mm256_storeu_si256(lo.cast(), _mm256_add_epi64(a0, lin0));
            _mm256_storeu_si256(lo.add(4).cast(), _mm256_add_epi64(a1, lin1));
            _mm256_storeu_si256(hi.cast(), _mm256_add_epi64(b0, hin0));
            _mm256_storeu_si256(hi.add(4).cast(), _mm256_add_epi64(b1, hin1));
        }
    }

    /// One lane block with a BROADCAST u64 scalar rj: lo/hi += a * rj.
    #[inline(always)]
    unsafe fn mac_block_bcast(a: *const u32, rj: u32, lo: *mut u64, hi: *mut u64) {
        unsafe {
            let av = _mm256_loadu_si256(a.cast());
            let rv = _mm256_set1_epi64x(rj as i64);
            let mask = _mm256_set1_epi64x(M32V);
            let pe = _mm256_mul_epu32(av, rv);
            let ao = _mm256_srli_epi64::<32>(av);
            let po = _mm256_mul_epu32(ao, rv);
            let lo_e = _mm256_and_si256(pe, mask);
            let hi_e = _mm256_srli_epi64::<32>(pe);
            let lo_o = _mm256_and_si256(po, mask);
            let hi_o = _mm256_srli_epi64::<32>(po);
            let l01 = _mm256_unpacklo_epi64(lo_e, lo_o);
            let l23 = _mm256_unpackhi_epi64(lo_e, lo_o);
            let h01 = _mm256_unpacklo_epi64(hi_e, hi_o);
            let h23 = _mm256_unpackhi_epi64(hi_e, hi_o);
            let lin0 = _mm256_permute2x128_si256::<0x20>(l01, l23);
            let lin1 = _mm256_permute2x128_si256::<0x31>(l01, l23);
            let hin0 = _mm256_permute2x128_si256::<0x20>(h01, h23);
            let hin1 = _mm256_permute2x128_si256::<0x31>(h01, h23);
            let a0 = _mm256_loadu_si256(lo.cast());
            let a1 = _mm256_loadu_si256(lo.add(4).cast());
            let b0 = _mm256_loadu_si256(hi.cast());
            let b1 = _mm256_loadu_si256(hi.add(4).cast());
            _mm256_storeu_si256(lo.cast(), _mm256_add_epi64(a0, lin0));
            _mm256_storeu_si256(lo.add(4).cast(), _mm256_add_epi64(a1, lin1));
            _mm256_storeu_si256(hi.cast(), _mm256_add_epi64(b0, hin0));
            _mm256_storeu_si256(hi.add(4).cast(), _mm256_add_epi64(b1, hin1));
        }
    }

    #[target_feature(enable = "avx2")]
    pub unsafe fn e_mac(c: usize, a: &[u32], b: &[u32], lo: &mut [u64], hi: &mut [u64]) {
        for i in 0..c {
            for j in 0..c {
                let t = i + j;
                unsafe {
                    mac_block(
                        a.as_ptr().add(i * KL),
                        b.as_ptr().add(j * KL),
                        lo.as_mut_ptr().add(t * KL),
                        hi.as_mut_ptr().add(t * KL),
                    );
                }
            }
        }
    }

    #[target_feature(enable = "avx2")]
    pub unsafe fn e_mac_base(c: usize, a: &[u32], f: &[u32; KL], lo: &mut [u64], hi: &mut [u64]) {
        for j in 0..c {
            unsafe {
                mac_block(
                    a.as_ptr().add(j * KL),
                    f.as_ptr(),
                    lo.as_mut_ptr().add(j * KL),
                    hi.as_mut_ptr().add(j * KL),
                );
            }
        }
    }

    #[target_feature(enable = "avx2")]
    pub unsafe fn e_mac_fixed(c: usize, a: &[u32], r: &[u32], lo: &mut [u64], hi: &mut [u64]) {
        for i in 0..c {
            for j in 0..c {
                let t = i + j;
                unsafe {
                    mac_block_bcast(
                        a.as_ptr().add(i * KL),
                        r[j],
                        lo.as_mut_ptr().add(t * KL),
                        hi.as_mut_ptr().add(t * KL),
                    );
                }
            }
        }
    }

    #[target_feature(enable = "avx2")]
    pub unsafe fn e_mac_base_fixed(c: usize, a: &[u32; KL], r: &[u32], lo: &mut [u64], hi: &mut [u64]) {
        for j in 0..c {
            unsafe {
                mac_block_bcast(
                    a.as_ptr(),
                    r[j],
                    lo.as_mut_ptr().add(j * KL),
                    hi.as_mut_ptr().add(j * KL),
                );
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Dispatched entry points (the zc_range call sites move here in rung 2).
// ---------------------------------------------------------------------------

#[inline(always)]
pub fn mac(c: usize, a: &[u32], b: &[u32], lo: &mut [u64], hi: &mut [u64], use_avx2: bool) {
    #[cfg(target_arch = "x86_64")]
    if use_avx2 {
        unsafe { avx::e_mac(c, a, b, lo, hi) };
        return;
    }
    let _ = use_avx2;
    e_mac(c, a, b, lo, hi);
}

#[inline(always)]
pub fn mac_base(c: usize, a: &[u32], f: &[u32; KL], lo: &mut [u64], hi: &mut [u64], use_avx2: bool) {
    #[cfg(target_arch = "x86_64")]
    if use_avx2 {
        unsafe { avx::e_mac_base(c, a, f, lo, hi) };
        return;
    }
    let _ = use_avx2;
    e_mac_base(c, a, f, lo, hi);
}

#[inline(always)]
pub fn mac_fixed(c: usize, a: &[u32], r: &[u32], lo: &mut [u64], hi: &mut [u64], use_avx2: bool) {
    #[cfg(target_arch = "x86_64")]
    if use_avx2 {
        unsafe { avx::e_mac_fixed(c, a, r, lo, hi) };
        return;
    }
    let _ = use_avx2;
    e_mac_fixed(c, a, r, lo, hi);
}

#[inline(always)]
pub fn mac_base_fixed(c: usize, a: &[u32; KL], r: &[u32], lo: &mut [u64], hi: &mut [u64], use_avx2: bool) {
    #[cfg(target_arch = "x86_64")]
    if use_avx2 {
        unsafe { avx::e_mac_base_fixed(c, a, r, lo, hi) };
        return;
    }
    let _ = use_avx2;
    e_mac_base_fixed(c, a, r, lo, hi);
}

// ---------------------------------------------------------------------------
// [rung 3] Fused modular LANE primitives. The round loop's other half:
// the extrapolation / f-chain / recomposition loops are scalar
// mulm/addm32/subm32 chains in zc_range's body — at w = 8, deg_f = 3,
// c = 4 they are ~half the counted round MACs, untouched by rungs 0-2
// (the measured Amdahl gap: kernel 2.6x but wall 1.9x). Each primitive
// has an EXACT scalar body (the loop moved verbatim from zc_range) and
// an AVX2 body producing IDENTICAL canonical residues lane-for-lane
// (same fold31/canon32 formulas in vector form) — the transcript
// depends on exact values, so the identity gate + the battery digest
// are the acceptance.
// ---------------------------------------------------------------------------

/// Scalar reference ops (duplicated from zc_range's private helpers —
/// the duplicated-constant discipline; zc_range's stay the callers'
/// oracle via ZK_EC_SCALAR=1).
#[inline(always)]
fn fold31(v: u64, c31: u64) -> u64 {
    (v & 0x7FFF_FFFF) + c31 * (v >> 31)
}
#[inline(always)]
fn canon32(v: u64, q32: u32) -> u32 {
    let r = v as u32;
    let r = r.min(r.wrapping_sub(q32));
    r.min(r.wrapping_sub(q32))
}
#[inline(always)]
fn addm32(a: u32, b: u32, q32: u32) -> u32 {
    let s = a + b;
    s.min(s.wrapping_sub(q32))
}
#[inline(always)]
fn subm32(a: u32, b: u32, q32: u32) -> u32 {
    let d = a.wrapping_sub(b);
    d.min(d.wrapping_add(q32))
}
#[inline(always)]
fn mulm(a: u32, b: u32, c31: u64, q32: u32) -> u32 {
    let p = a as u64 * b as u64;
    canon32(fold31(fold31(p, c31), c31), q32)
}

#[cfg(target_arch = "x86_64")]
mod lanes_avx {
    #[cfg(target_arch = "x86_64")]
    use std::arch::x86_64::*;

    /// 8-lane modular helpers on u32 ymm vectors. All values canonical
    /// (< q < 2^31); q32/c31 broadcast. Same formulas as the scalar
    /// bodies — min-trick canon, double fold31 — so results are
    /// IDENTICAL, not merely congruent.
    #[inline(always)]
    pub unsafe fn vsub(a: __m256i, b: __m256i, q: __m256i) -> __m256i {
        unsafe {
            let d = _mm256_sub_epi32(a, b);
            _mm256_min_epu32(d, _mm256_add_epi32(d, q))
        }
    }
    #[inline(always)]
    pub unsafe fn vadd(a: __m256i, b: __m256i, q: __m256i) -> __m256i {
        unsafe {
            let s = _mm256_add_epi32(a, b);
            _mm256_min_epu32(s, _mm256_sub_epi32(s, q))
        }
    }
    /// One 4-lane u64 half of the modular product: p = a64 * b64 (both
    /// < 2^31 in the low u32 of each u64 lane), double fold31, then the
    /// result stays in u64 lanes (< 2^32, canon applied by caller after
    /// the halves are packed back to u32 lanes).
    #[inline(always)]
    unsafe fn vmul_fold_half(a64: __m256i, b64: __m256i, c31: __m256i) -> __m256i {
        unsafe {
            let m31 = _mm256_set1_epi64x(0x7FFF_FFFF);
            let p = _mm256_mul_epu32(a64, b64);
            // fold 1
            let lo = _mm256_and_si256(p, m31);
            let hi = _mm256_srli_epi64::<31>(p);
            let f1 = _mm256_add_epi64(lo, _mm256_mul_epu32(hi, c31));
            // fold 2
            let lo2 = _mm256_and_si256(f1, m31);
            let hi2 = _mm256_srli_epi64::<31>(f1);
            _mm256_add_epi64(lo2, _mm256_mul_epu32(hi2, c31))
        }
    }
    /// bv = ba + xr (bb - ba) over 8n lanes, AVX2-attributed.
    #[target_feature(enable = "avx2")]
    pub unsafe fn extrap_avx(ba: &[u32], bb: &[u32], xr: u32, c31: u64, q32: u32, bv: &mut [u32]) {
        unsafe {
            let q = _mm256_set1_epi32(q32 as i32);
            let c31v = _mm256_set1_epi64x(c31 as i64);
            let xv = _mm256_set1_epi32(xr as i32);
            for blk in 0..ba.len() / super::KL {
                let s = blk * super::KL;
                let av = _mm256_loadu_si256(ba.as_ptr().add(s).cast());
                let bvv = _mm256_loadu_si256(bb.as_ptr().add(s).cast());
                let d = vsub(bvv, av, q);
                let xd = vmulm(xv, d, c31v, q);
                _mm256_storeu_si256(bv.as_mut_ptr().add(s).cast(), vadd(av, xd, q));
            }
        }
    }

    /// f = prod_a (bv - a) over KL lanes, AVX2-attributed.
    #[target_feature(enable = "avx2")]
    pub unsafe fn f_chain_avx(bv: &[u32; super::KL], alphabet: &[u32], c31: u64, q32: u32, bf: &mut [u32; super::KL]) {
        unsafe {
            let q = _mm256_set1_epi32(q32 as i32);
            let c31v = _mm256_set1_epi64x(c31 as i64);
            let v = _mm256_loadu_si256(bv.as_ptr().cast());
            let mut f = vsub(v, _mm256_set1_epi32(alphabet[0] as i32), q);
            for &a in &alphabet[1..] {
                let t = vsub(v, _mm256_set1_epi32(a as i32), q);
                f = vmulm(f, t, c31v, q);
            }
            _mm256_storeu_si256(bf.as_mut_ptr().cast(), f);
        }
    }

    /// rec -= p2k * v over 8n lanes, AVX2-attributed.
    #[target_feature(enable = "avx2")]
    pub unsafe fn rec_sub_scaled_avx(rec: &mut [u32], p2k: u32, v: &[u32], c31: u64, q32: u32) {
        unsafe {
            let q = _mm256_set1_epi32(q32 as i32);
            let c31v = _mm256_set1_epi64x(c31 as i64);
            let pv = _mm256_set1_epi32(p2k as i32);
            for blk in 0..rec.len() / super::KL {
                let s = blk * super::KL;
                let rv = _mm256_loadu_si256(rec.as_ptr().add(s).cast());
                let vv = _mm256_loadu_si256(v.as_ptr().add(s).cast());
                _mm256_storeu_si256(rec.as_mut_ptr().add(s).cast(), vsub(rv, vmulm(pv, vv, c31v, q), q));
            }
        }
    }

    /// rec += v over 8n lanes, AVX2-attributed.
    #[target_feature(enable = "avx2")]
    pub unsafe fn rec_add_avx(rec: &mut [u32], v: &[u32], q32: u32) {
        unsafe {
            let q = _mm256_set1_epi32(q32 as i32);
            for blk in 0..rec.len() / super::KL {
                let s = blk * super::KL;
                let rv = _mm256_loadu_si256(rec.as_ptr().add(s).cast());
                let vv = _mm256_loadu_si256(v.as_ptr().add(s).cast());
                _mm256_storeu_si256(rec.as_mut_ptr().add(s).cast(), vadd(rv, vv, q));
            }
        }
    }

    /// 8-lane modular multiply a*b -> canonical, all lanes.
    #[inline(always)]
    pub unsafe fn vmulm(a: __m256i, b: __m256i, c31: __m256i, q: __m256i) -> __m256i {
        unsafe {
            let ae = a;
            let be = b;
            let ao = _mm256_srli_epi64::<32>(a);
            let bo = _mm256_srli_epi64::<32>(b);
            let fe = vmul_fold_half(ae, be, c31); // lanes 0,2,4,6 in u64 slots
            let fo = vmul_fold_half(ao, bo, c31); // lanes 1,3,5,7
            // pack u64 lanes (< 2^32) back into u32 lane order: even
            // results sit in the low u32 of each u64 slot; odd results
            // shifted up 32 recreate the odd u32 positions.
            let packed = _mm256_or_si256(fe, _mm256_slli_epi64::<32>(fo));
            // canon32 twice (min-trick)
            let r = _mm256_min_epu32(packed, _mm256_sub_epi32(packed, q));
            _mm256_min_epu32(r, _mm256_sub_epi32(r, q))
        }
    }
}

/// bv = ba + xr * (bb - ba) over 8n lanes (the round extrapolation;
/// base path n = 1 block, ext path n = c blocks).
#[inline]
pub fn extrap_lanes(ba: &[u32], bb: &[u32], xr: u32, c31: u64, q32: u32, bv: &mut [u32]) {
    debug_assert!(ba.len() == bb.len() && ba.len() == bv.len() && ba.len() % KL == 0);
    #[cfg(target_arch = "x86_64")]
    if avx2_active() {
        unsafe { lanes_avx::extrap_avx(ba, bb, xr, c31, q32, bv) };
        return;
    }
    for l in 0..ba.len() {
        let d = subm32(bb[l], ba[l], q32);
        bv[l] = addm32(ba[l], mulm(xr, d, c31, q32), q32);
    }
}

/// The base-path f chain over KL lanes: f = prod_a (bv - a) with the
/// SCALAR alphabet (the sign-binary node values).
#[inline]
pub fn f_chain_lanes(bv: &[u32; KL], alphabet: &[u32], c31: u64, q32: u32, bf: &mut [u32; KL]) {
    #[cfg(target_arch = "x86_64")]
    if avx2_active() {
        unsafe { lanes_avx::f_chain_avx(bv, alphabet, c31, q32, bf) };
        return;
    }
    for l in 0..KL {
        let mut f = subm32(bv[l], alphabet[0], q32);
        for &a in &alphabet[1..] {
            f = mulm(f, subm32(bv[l], a, q32), c31, q32);
        }
        bf[l] = f;
    }
}

/// rec -= p2k * v over 8n lanes (the recomposition's scaled subtract).
#[inline]
pub fn rec_sub_scaled(rec: &mut [u32], p2k: u32, v: &[u32], c31: u64, q32: u32) {
    debug_assert!(rec.len() == v.len() && rec.len() % KL == 0);
    #[cfg(target_arch = "x86_64")]
    if avx2_active() {
        unsafe { lanes_avx::rec_sub_scaled_avx(rec, p2k, v, c31, q32) };
        return;
    }
    for l in 0..rec.len() {
        rec[l] = subm32(rec[l], mulm(p2k, v[l], c31, q32), q32);
    }
}

/// rec += v over 8n lanes.
#[inline]
pub fn rec_add(rec: &mut [u32], v: &[u32], q32: u32) {
    debug_assert!(rec.len() == v.len() && rec.len() % KL == 0);
    #[cfg(target_arch = "x86_64")]
    if avx2_active() {
        unsafe { lanes_avx::rec_add_avx(rec, v, q32) };
        return;
    }
    for l in 0..rec.len() {
        rec[l] = addm32(rec[l], v[l], q32);
    }
}

// ---------------------------------------------------------------------------
// [rung 4] The fused base-round NODE: per (block m, node x) the whole
// k loop — deinterleave, extrapolate, f-chain, eq x f MAC, and the
// recomposition — in ONE #[target_feature] body, register-resident
// (eq blocks loaded once per node; bv/bf/rec never touch memory).
// Rung 3 measured the per-call setup of the 8-lane primitives as the
// remaining bound; this removes it for the dominant round.
// ---------------------------------------------------------------------------

#[cfg(target_arch = "x86_64")]
mod node_avx {
    use super::KL;
    use super::lanes_avx::{vadd, vmulm, vsub};
    #[cfg(target_arch = "x86_64")]
    use std::arch::x86_64::*;

    const M32V: i64 = 0xFFFF_FFFF;

    /// Deinterleave 16 consecutive u32 at src[16 m..] into (even, odd)
    /// 8-lane vectors — b_deint_pair's exact lane order.
    #[inline(always)]
    unsafe fn deint16(src: *const u32) -> (__m256i, __m256i) {
        unsafe {
            let v0 = _mm256_loadu_si256(src.cast());
            let v1 = _mm256_loadu_si256(src.add(8).cast());
            // per 128-bit half: [0,1,2,3] -> [0,2,1,3]
            let s0 = _mm256_shuffle_epi32::<0xD8>(v0);
            let s1 = _mm256_shuffle_epi32::<0xD8>(v1);
            let elo = _mm256_unpacklo_epi64(s0, s1); // lanes 0,2 8,10 | 4,6 12,14
            let ehi = _mm256_unpackhi_epi64(s0, s1); // lanes 1,3 9,11 | 5,7 13,15
            // 64-bit groups [0,2][8,10][4,6][12,14] -> [0,2][4,6][8,10][12,14]
            let even = _mm256_permute4x64_epi64::<0xD8>(elo);
            let odd = _mm256_permute4x64_epi64::<0xD8>(ehi);
            (even, odd)
        }
    }

    /// One eq-block MAC with a REGISTER operand f: lo/hi[.. KL] += eq * f
    /// (elementwise, split planes, scalar lane order).
    #[inline(always)]
    unsafe fn mac_block_reg(eq: __m256i, f: __m256i, lo: *mut u64, hi: *mut u64) {
        unsafe {
            let mask = _mm256_set1_epi64x(M32V);
            let pe = _mm256_mul_epu32(eq, f);
            let po = _mm256_mul_epu32(_mm256_srli_epi64::<32>(eq), _mm256_srli_epi64::<32>(f));
            let lo_e = _mm256_and_si256(pe, mask);
            let hi_e = _mm256_srli_epi64::<32>(pe);
            let lo_o = _mm256_and_si256(po, mask);
            let hi_o = _mm256_srli_epi64::<32>(po);
            let l01 = _mm256_unpacklo_epi64(lo_e, lo_o);
            let l23 = _mm256_unpackhi_epi64(lo_e, lo_o);
            let h01 = _mm256_unpacklo_epi64(hi_e, hi_o);
            let h23 = _mm256_unpackhi_epi64(hi_e, hi_o);
            let lin0 = _mm256_permute2x128_si256::<0x20>(l01, l23);
            let lin1 = _mm256_permute2x128_si256::<0x31>(l01, l23);
            let hin0 = _mm256_permute2x128_si256::<0x20>(h01, h23);
            let hin1 = _mm256_permute2x128_si256::<0x31>(h01, h23);
            let a0 = _mm256_loadu_si256(lo.cast());
            let a1 = _mm256_loadu_si256(lo.add(4).cast());
            let b0 = _mm256_loadu_si256(hi.cast());
            let b1 = _mm256_loadu_si256(hi.add(4).cast());
            _mm256_storeu_si256(lo.cast(), _mm256_add_epi64(a0, lin0));
            _mm256_storeu_si256(lo.add(4).cast(), _mm256_add_epi64(a1, lin1));
            _mm256_storeu_si256(hi.cast(), _mm256_add_epi64(b0, hin0));
            _mm256_storeu_si256(hi.add(4).cast(), _mm256_add_epi64(b1, hin1));
        }
    }

    /// The whole base-path node (see the section header). `tabs` = the
    /// w+1 base planes; slice k of lo/hi is at (k*nn + ni)*planes and
    /// receives c*KL split-accumulated products (planes = the caller's
    /// slice stride). Values are IDENTICAL to the scalar path (same
    /// canonical formulas; the split-plane sums are order-free exact
    /// integers).
    #[target_feature(enable = "avx2")]
    #[allow(clippy::too_many_arguments)]
    pub unsafe fn base_node(
        tabs: &[&[u32]],
        m: usize,
        xr: u32,
        alphabet: &[u32],
        pow2: &[u32],
        eqb: &[u32],
        c: usize,
        nn: usize,
        ni: usize,
        planes: usize,
        c31: u64,
        q32: u32,
        lo: &mut [u64],
        hi: &mut [u64],
    ) {
        unsafe {
            let w = tabs.len() - 1;
            debug_assert!(eqb.len() == c * KL && alphabet.len() >= 1 && pow2.len() >= w);
            let q = _mm256_set1_epi32(q32 as i32);
            let c31v = _mm256_set1_epi64x(c31 as i64);
            let xv = _mm256_set1_epi32(xr as i32);
            // eq blocks, loaded once per node
            let mut eq = [_mm256_setzero_si256(); 16];
            for (j, e) in eq.iter_mut().enumerate().take(c) {
                *e = _mm256_loadu_si256(eqb.as_ptr().add(j * KL).cast());
            }
            let mut rec = _mm256_setzero_si256();
            for (k, t) in tabs.iter().enumerate() {
                debug_assert!(t.len() >= 16 * m + 16);
                let (a_v, b_v) = deint16(t.as_ptr().add(16 * m));
                let v = vadd(a_v, vmulm(xv, vsub(b_v, a_v, q), c31v, q), q);
                if k < w {
                    let mut f = vsub(v, _mm256_set1_epi32(alphabet[0] as i32), q);
                    for &a in &alphabet[1..] {
                        f = vmulm(f, vsub(v, _mm256_set1_epi32(a as i32), q), c31v, q);
                    }
                    let sl = (k * nn + ni) * planes;
                    for (j, &e) in eq.iter().enumerate().take(c) {
                        mac_block_reg(
                            e,
                            f,
                            lo.as_mut_ptr().add(sl + j * KL),
                            hi.as_mut_ptr().add(sl + j * KL),
                        );
                    }
                    let p2 = _mm256_set1_epi32(pow2[k] as i32);
                    rec = vsub(rec, vmulm(p2, v, c31v, q), q);
                } else {
                    rec = vadd(rec, v, q);
                    let sl = (w * nn + ni) * planes;
                    for (j, &e) in eq.iter().enumerate().take(c) {
                        mac_block_reg(
                            e,
                            rec,
                            lo.as_mut_ptr().add(sl + j * KL),
                            hi.as_mut_ptr().add(sl + j * KL),
                        );
                    }
                }
            }
        }
    }
}

/// The fused base-round node (rung 4): caller must have checked
/// `avx2_active()`. See node_avx::base_node.
#[cfg(target_arch = "x86_64")]
#[allow(clippy::too_many_arguments)]
pub fn base_node_fused(
    tabs: &[&[u32]],
    m: usize,
    xr: u32,
    alphabet: &[u32],
    pow2: &[u32],
    eqb: &[u32],
    c: usize,
    nn: usize,
    ni: usize,
    planes: usize,
    c31: u64,
    q32: u32,
    lo: &mut [u64],
    hi: &mut [u64],
) {
    debug_assert!(avx2_active());
    unsafe {
        node_avx::base_node(tabs, m, xr, alphabet, pow2, eqb, c, nn, ni, planes, c31, q32, lo, hi)
    };
}

// ---------------------------------------------------------------------------
// The kernel-bench harness (rung 0/1 record) + the identity check.
// ---------------------------------------------------------------------------

/// Deterministic canonical values below q (no RNG dependence).
fn synth(n: usize, q: u64, salt: u64) -> Vec<u32> {
    (0..n)
        .map(|i| (((i as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15) ^ salt) % q) as u32)
        .collect()
}

/// Byte-identity of every AVX2 family vs its scalar oracle at width c
/// (random-ish canonical operands, accumulate 3 times to exercise the
/// running-sum path). Panics on any diff.
pub fn identity_check(c: usize, q: u64) {
    let pairs = 257;
    let a = synth(pairs * c * KL, q, 11);
    let b = synth(pairs * c * KL, q, 22);
    let r = synth(c, q, 33);
    let f: [u32; KL] = synth(KL, q, 44).try_into().unwrap();
    let planes = (2 * c - 1) * KL;
    for use_avx2 in [false, true] {
        if use_avx2 && !avx2() {
            continue;
        }
        // family 1: e_mac
        let (mut lo, mut hi) = (vec![0u64; planes], vec![0u64; planes]);
        let (mut lo2, mut hi2) = (vec![0u64; planes], vec![0u64; planes]);
        for p in 0..pairs {
            let (ab, bb) = (&a[p * c * KL..(p + 1) * c * KL], &b[p * c * KL..(p + 1) * c * KL]);
            for _ in 0..3 {
                e_mac(c, ab, bb, &mut lo, &mut hi);
                mac(c, ab, bb, &mut lo2, &mut hi2, use_avx2);
            }
        }
        assert!(lo == lo2 && hi == hi2, "e_mac identity FAILS (avx2={use_avx2}, c={c})");
        // family 2: e_mac_fixed
        let (mut lo, mut hi) = (vec![0u64; planes], vec![0u64; planes]);
        let (mut lo2, mut hi2) = (vec![0u64; planes], vec![0u64; planes]);
        for p in 0..pairs {
            let ab = &a[p * c * KL..(p + 1) * c * KL];
            e_mac_fixed(c, ab, &r, &mut lo, &mut hi);
            mac_fixed(c, ab, &r, &mut lo2, &mut hi2, use_avx2);
        }
        assert!(lo == lo2 && hi == hi2, "e_mac_fixed identity FAILS (avx2={use_avx2}, c={c})");
        // family 3: e_mac_base (c*KL planes)
        let (mut lo, mut hi) = (vec![0u64; c * KL], vec![0u64; c * KL]);
        let (mut lo2, mut hi2) = (vec![0u64; c * KL], vec![0u64; c * KL]);
        for p in 0..pairs {
            let ab = &a[p * c * KL..(p + 1) * c * KL];
            e_mac_base(c, ab, &f, &mut lo, &mut hi);
            mac_base(c, ab, &f, &mut lo2, &mut hi2, use_avx2);
        }
        assert!(lo == lo2 && hi == hi2, "e_mac_base identity FAILS (avx2={use_avx2}, c={c})");
        // family 4: e_mac_base_fixed
        let fa: [u32; KL] = synth(KL, q, 55).try_into().unwrap();
        let (mut lo, mut hi) = (vec![0u64; c * KL], vec![0u64; c * KL]);
        let (mut lo2, mut hi2) = (vec![0u64; c * KL], vec![0u64; c * KL]);
        for _ in 0..pairs {
            e_mac_base_fixed(c, &fa, &r, &mut lo, &mut hi);
            mac_base_fixed(c, &fa, &r, &mut lo2, &mut hi2, use_avx2);
        }
        assert!(lo == lo2 && hi == hi2, "e_mac_base_fixed identity FAILS (avx2={use_avx2}, c={c})");
    }
}

/// ns/MAC table, scalar vs AVX2, per family. `pairs` operand pairs per
/// rep, `reps` passes (the accumulators are re-zeroed per rep so the
/// split planes cannot overflow: each lane sees pairs*3 products
/// < 2^38 additions of < 2^32 halves for any pairs <= 2^26).
pub fn kernel_bench(c: usize, log2_pairs: usize, reps: usize, q: u64) {
    identity_check(c, q);
    println!("[UPERF3-DD] identity: 4 families x scalar/avx2 byte-identical at c = {c}");
    let pairs = 1usize << log2_pairs;
    let a = synth(pairs * c * KL, q, 1);
    let b = synth(pairs * c * KL, q, 2);
    let r = synth(c, q, 3);
    let f: [u32; KL] = synth(KL, q, 4).try_into().unwrap();
    let planes = (2 * c - 1) * KL;
    let modes: &[(&str, bool)] =
        if avx2() { &[("scalar", false), ("avx2", true)] } else { &[("scalar", false)] };
    println!(
        "[UPERF3-DD] kernel-bench c = {c}, pairs = 2^{log2_pairs}, reps = {reps} (1T; MAC = one u32xu32->u64 split accumulate)"
    );
    let mut sink = 0u64;
    for (label, use_avx2) in modes {
        // e_mac: c*c*KL MACs per pair
        let (mut lo, mut hi) = (vec![0u64; planes], vec![0u64; planes]);
        let t0 = Instant::now();
        for _ in 0..reps {
            lo.iter_mut().for_each(|v| *v = 0);
            hi.iter_mut().for_each(|v| *v = 0);
            for p in 0..pairs {
                let s = p * c * KL;
                mac(c, &a[s..s + c * KL], &b[s..s + c * KL], &mut lo, &mut hi, *use_avx2);
            }
        }
        let el = t0.elapsed().as_secs_f64();
        sink ^= lo[0] ^ hi[planes - 1];
        let macs = (reps * pairs * c * c * KL) as f64;
        let full = el * 1e9 / macs;
        // e_mac_fixed: c*c*KL
        let t0 = Instant::now();
        for _ in 0..reps {
            lo.iter_mut().for_each(|v| *v = 0);
            hi.iter_mut().for_each(|v| *v = 0);
            for p in 0..pairs {
                let s = p * c * KL;
                mac_fixed(c, &a[s..s + c * KL], &r, &mut lo, &mut hi, *use_avx2);
            }
        }
        let el = t0.elapsed().as_secs_f64();
        sink ^= lo[0] ^ hi[planes - 1];
        let fixed = el * 1e9 / macs;
        // e_mac_base: c*KL
        let (mut lo_b, mut hi_b) = (vec![0u64; c * KL], vec![0u64; c * KL]);
        let t0 = Instant::now();
        for _ in 0..reps {
            lo_b.iter_mut().for_each(|v| *v = 0);
            hi_b.iter_mut().for_each(|v| *v = 0);
            for p in 0..pairs {
                let s = p * c * KL;
                mac_base(c, &a[s..s + c * KL], &f, &mut lo_b, &mut hi_b, *use_avx2);
            }
        }
        let el = t0.elapsed().as_secs_f64();
        sink ^= lo_b[0] ^ hi_b[c * KL - 1];
        let base = el * 1e9 / ((reps * pairs * c * KL) as f64);
        println!(
            "  {label:<6}  e_mac {full:7.3} ns/MAC   e_mac_fixed {fixed:7.3}   e_mac_base {base:7.3}"
        );
    }
    println!("  (sink {sink:x})");
}

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

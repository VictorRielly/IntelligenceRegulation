//! R13 public output-channel coefficients are folded at Boolean channels.
//! Multiplying two interpolated values afterwards would change the relation.
use super::accuracy_public::{AccuracyPublic,Geometry};
use super::shape::Shape;
use crate::field::{Fp,Fp2,P};
use crate::mle::{fold_rows_i8,fold_cols_i8};

#[derive(Clone,Copy,Debug,PartialEq,Eq)]
pub(crate) enum Site { Q,K,V,O,Gate,Up,Down }
#[derive(Clone,Copy,Debug,PartialEq,Eq)]
pub(crate) enum Axis { Rows,Columns }

/// Only the public data's validator admits coefficients. This helper maps
/// their logical output channels into the native padded/head-permuted axis;
/// the outer profile gate must also check stack, registry and calibration.
pub(crate) fn coefficients(sh:&Shape,a:&AccuracyPublic,site:Site)->Result<Vec<u64>,String> {
    let geo=Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    if geo!=a.geometry() {return Err("R13 matrix fold: geometry context mismatch".into());}
    let m=a.multipliers();
    if site==Site::Q {
        let mut out=vec![0;sh.q_pad()];
        for h in 0..sh.q_heads {for i in 0..sh.head_dim {
            out[sh.head_slot(h)*sh.head_dim+i]=m.q[h*sh.head_dim+i] as u64;
        }}
        return Ok(out);
    }
    let (words,len):(Vec<u64>,usize)=match site {
        Site::Q=>unreachable!(),
        Site::K=>(m.k.iter().map(|&v|v as u64).collect(),geo.kv_width),
        Site::V=>(m.v.iter().map(|&v|v as u64).collect(),geo.kv_width),
        Site::O=>(m.o.iter().map(|&v|v as u64).collect(),sh.d_pad),
        Site::Gate=>(a.folds().gate.multipliers.clone(),sh.f_pad),
        Site::Up=>(m.u.iter().map(|&v|v as u64).collect(),sh.f_pad),
        Site::Down=>(m.d.iter().map(|&v|v as u64).collect(),sh.d_pad),
    };
    let mut out=words;out.resize(len,0);Ok(out)
}

const FOLD_ERR: &str = "R13 matrix fold: matrix/axis/coefficients outside the declared class";
const HOST_FAST_MAX_DIM: usize = 1 << 20;

/// [ZK60-METAL M8] `matrix.contains(&i8::MIN)`, over 1 MiB chunks in
/// parallel: the same predicate (and so the same refusal), without one thread
/// scanning every weight of the layer at every fold (an 8B layer is 218 MB)
fn has_i8_min(matrix:&[i8])->bool {
    use rayon::prelude::*;
    matrix.par_chunks(1<<20).any(|c|c.contains(&i8::MIN))
}

/// **[HOST-FAST H4]** Split a canonical Goldilocks element `a` (`0 <= a.0 < P`)
/// into signed 32-bit limbs `(lo, hi)` with `(lo as i128) + ((hi as i128) << 32) ≡ a.0 (mod P)`.
///
/// For `a.0 <= 0x7FFF_FFFF_7FFF_FFFF` (`2^63 - 2^31 - 1`): `s = a.0 as i64 >= 0`,
/// `lo = s as i32 ∈ [-2^31, 2^31 - 1]`, `hi = ((s - lo as i64) >> 32) as i32 ∈ [0, 2^31 - 1]`.
/// For `a.0 >= 0x7FFF_FFFF_8000_0000`: `s = -((P - a.0) as i64) ∈ [-2^63 + 2^31 - 1, -1]`,
/// `lo = s as i32 ∈ [-2^31, 2^31 - 1]`, `hi = ((s - lo as i64) >> 32) as i32 ∈ [-2^31, 0]`.
///
/// Since `|lo|, |hi| <= 2^31` and `|v| <= 128` for every `v: i8` (even `i8::MIN`),
/// summing up to `2^20` products `v * lo` or `v * hi` stays strictly within
/// `[-2^58, 2^58] ⊂ [i64::MIN, i64::MAX]` with zero overflow, and directly feeds
/// AArch64 NEON `SMLAL`/`SMLAL2` (`vmlal_s32`/`vmlal_high_s32`).
#[inline(always)]
fn split_signed_fp(a: Fp) -> (i32, i32) {
    const HALF_LO: u64 = 0x7FFF_FFFF_7FFF_FFFF;
    let u = a.0;
    let s: i64 = if u <= HALF_LO {
        u as i64
    } else {
        -((P - u) as i64)
    };
    let lo = s as i32;
    let hi = ((s - (lo as i64)) >> 32) as i32;
    (lo, hi)
}

#[inline(always)]
fn reduce_i128(s: i128) -> Fp {
    if s == 0 {
        return Fp::ZERO;
    }
    let mag = Fp::from_u128(s.unsigned_abs());
    if s < 0 { Fp::ZERO.sub(mag) } else { mag }
}

/// Branchless SIMD check for `i8::MIN` (`-128`) on a byte slice (used for
/// skipped zero-weighted rows/columns so refusal parity is 100% identical).
#[inline]
fn slice_has_i8_min(s: &[i8]) -> bool {
    #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
    {
        use core::arch::aarch64::{vdupq_n_s8, vld1q_s8, vminq_s8, vminvq_s8};
        let mut chunks = s.chunks_exact(64);
        // SAFETY: `target_feature = "neon"` is enabled at compile time; slice lengths match exact load widths.
        unsafe {
            let mut m0 = vdupq_n_s8(0);
            let mut m1 = vdupq_n_s8(0);
            let mut m2 = vdupq_n_s8(0);
            let mut m3 = vdupq_n_s8(0);
            for c in &mut chunks {
                let p = c.as_ptr();
                m0 = vminq_s8(m0, vld1q_s8(p));
                m1 = vminq_s8(m1, vld1q_s8(p.add(16)));
                m2 = vminq_s8(m2, vld1q_s8(p.add(32)));
                m3 = vminq_s8(m3, vld1q_s8(p.add(48)));
            }
            let mut rem = chunks.remainder().chunks_exact(16);
            for c in &mut rem {
                m0 = vminq_s8(m0, vld1q_s8(c.as_ptr()));
            }
            let m = vminq_s8(vminq_s8(m0, m1), vminq_s8(m2, m3));
            if vminvq_s8(m) == i8::MIN {
                return true;
            }
            rem.remainder().contains(&i8::MIN)
        }
    }
    #[cfg(not(all(target_arch = "aarch64", target_feature = "neon")))]
    {
        s.contains(&i8::MIN)
    }
}

fn has_i8_min_fast(matrix: &[i8]) -> bool {
    use rayon::prelude::*;
    if matrix.len() < (1 << 16) {
        return slice_has_i8_min(matrix);
    }
    matrix.par_chunks(1 << 20).any(slice_has_i8_min)
}

#[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
#[inline(always)]
#[allow(clippy::too_many_arguments)]
fn accum_row_chunk_neon(
    row: &[i8],
    w0l: i32,
    w0h: i32,
    w1l: i32,
    w1h: i32,
    a0l: &mut [i64],
    a0h: &mut [i64],
    a1l: &mut [i64],
    a1h: &mut [i64],
    min_v: &mut core::arch::aarch64::int8x16_t,
) -> usize {
    use core::arch::aarch64::{
        vdup_n_s32, vdupq_n_s32, vget_low_s16, vget_low_s32, vget_low_s8, vld1q_s64, vld1q_s8,
        vminq_s8, vmlal_high_s32, vmlal_s32, vmovl_high_s16, vmovl_high_s8, vmovl_s16, vmovl_s8,
        vst1q_s64,
    };
    let len = row.len();
    assert!(a0l.len() >= len && a0h.len() >= len && a1l.len() >= len && a1h.len() >= len);
    let rp = row.as_ptr();
    let (p0l, p0h, p1l, p1h) = (a0l.as_mut_ptr(), a0h.as_mut_ptr(), a1l.as_mut_ptr(), a1h.as_mut_ptr());
    let mut k = 0usize;
    // SAFETY: `target_feature = "neon"` is enabled at compile time; `k + 16 <= len <= a*.len()`.
    unsafe {
        let (w0l_lo, w0l_q) = (vdup_n_s32(w0l), vdupq_n_s32(w0l));
        let (w0h_lo, w0h_q) = (vdup_n_s32(w0h), vdupq_n_s32(w0h));
        let (w1l_lo, w1l_q) = (vdup_n_s32(w1l), vdupq_n_s32(w1l));
        let (w1h_lo, w1h_q) = (vdup_n_s32(w1h), vdupq_n_s32(w1h));
        let mut mv = *min_v;
        while k + 16 <= len {
            let v = vld1q_s8(rp.add(k));
            mv = vminq_s8(mv, v);
            let lo16 = vmovl_s8(vget_low_s8(v));
            let hi16 = vmovl_high_s8(v);
            let xs = [
                vmovl_s16(vget_low_s16(lo16)),
                vmovl_high_s16(lo16),
                vmovl_s16(vget_low_s16(hi16)),
                vmovl_high_s16(hi16),
            ];
            for (t, &x) in xs.iter().enumerate() {
                let off = k + t * 4;
                let x_lo = vget_low_s32(x);
                let q0 = vld1q_s64(p0l.add(off));
                let q1 = vld1q_s64(p0l.add(off + 2));
                vst1q_s64(p0l.add(off), vmlal_s32(q0, x_lo, w0l_lo));
                vst1q_s64(p0l.add(off + 2), vmlal_high_s32(q1, x, w0l_q));

                let q0 = vld1q_s64(p0h.add(off));
                let q1 = vld1q_s64(p0h.add(off + 2));
                vst1q_s64(p0h.add(off), vmlal_s32(q0, x_lo, w0h_lo));
                vst1q_s64(p0h.add(off + 2), vmlal_high_s32(q1, x, w0h_q));

                let q0 = vld1q_s64(p1l.add(off));
                let q1 = vld1q_s64(p1l.add(off + 2));
                vst1q_s64(p1l.add(off), vmlal_s32(q0, x_lo, w1l_lo));
                vst1q_s64(p1l.add(off + 2), vmlal_high_s32(q1, x, w1l_q));

                let q0 = vld1q_s64(p1h.add(off));
                let q1 = vld1q_s64(p1h.add(off + 2));
                vst1q_s64(p1h.add(off), vmlal_s32(q0, x_lo, w1h_lo));
                vst1q_s64(p1h.add(off + 2), vmlal_high_s32(q1, x, w1h_q));
            }
            k += 16;
        }
        *min_v = mv;
    }
    k
}

/// **[HOST-FAST-W2 W2-6a]** 4-row unrolled NEON column-chunk accumulator for
/// `fold_rows_fast`: loads/stores `a0l..a1h` ONCE per 4 active rows instead of
/// per row, cutting stack accumulator load/store traffic 4x.
#[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
#[inline(always)]
#[allow(clippy::too_many_arguments)]
fn accum_4rows_chunk_neon(
    rows: [&[i8]; 4],
    w0l: [i32; 4],
    w0h: [i32; 4],
    w1l: [i32; 4],
    w1h: [i32; 4],
    a0l: &mut [i64],
    a0h: &mut [i64],
    a1l: &mut [i64],
    a1h: &mut [i64],
    min_v: &mut core::arch::aarch64::int8x16_t,
) -> usize {
    use core::arch::aarch64::{
        vdup_n_s32, vdupq_n_s32, vget_low_s16, vget_low_s32, vget_low_s8, vld1q_s64, vld1q_s8,
        vminq_s8, vmlal_high_s32, vmlal_s32, vmovl_high_s16, vmovl_high_s8, vmovl_s16, vmovl_s8,
        vst1q_s64,
    };
    let len = rows[0].len();
    assert!(
        rows[1].len() == len
            && rows[2].len() == len
            && rows[3].len() == len
            && a0l.len() >= len
            && a0h.len() >= len
            && a1l.len() >= len
            && a1h.len() >= len
    );
    let rps = [rows[0].as_ptr(), rows[1].as_ptr(), rows[2].as_ptr(), rows[3].as_ptr()];
    let (p0l, p0h, p1l, p1h) = (a0l.as_mut_ptr(), a0h.as_mut_ptr(), a1l.as_mut_ptr(), a1h.as_mut_ptr());
    let mut k = 0usize;
    // SAFETY: `target_feature = "neon"` is enabled at compile time; `k + 16 <= len <= a*.len()`.
    unsafe {
        let mut mv = *min_v;
        macro_rules! accum_limb {
            ($ptr:expr, $off:expr, $xs:expr, $ws:expr) => {{
                let mut q0 = vld1q_s64($ptr.add($off));
                let mut q1 = vld1q_s64($ptr.add($off + 2));
                for r in 0..4 {
                    let x = $xs[r];
                    let w = $ws[r];
                    q0 = vmlal_s32(q0, vget_low_s32(x), vdup_n_s32(w));
                    q1 = vmlal_high_s32(q1, x, vdupq_n_s32(w));
                }
                vst1q_s64($ptr.add($off), q0);
                vst1q_s64($ptr.add($off + 2), q1);
            }};
        }
        macro_rules! step4 {
            ($xs:expr, $off:expr) => {{
                let off = k + $off;
                accum_limb!(p0l, off, $xs, w0l);
                accum_limb!(p0h, off, $xs, w0h);
                accum_limb!(p1l, off, $xs, w1l);
                accum_limb!(p1h, off, $xs, w1h);
            }};
        }
        while k + 16 <= len {
            let v0 = vld1q_s8(rps[0].add(k));
            let v1 = vld1q_s8(rps[1].add(k));
            let v2 = vld1q_s8(rps[2].add(k));
            let v3 = vld1q_s8(rps[3].add(k));
            mv = vminq_s8(mv, vminq_s8(vminq_s8(v0, v1), vminq_s8(v2, v3)));

            let lo0 = vmovl_s8(vget_low_s8(v0));
            let lo1 = vmovl_s8(vget_low_s8(v1));
            let lo2 = vmovl_s8(vget_low_s8(v2));
            let lo3 = vmovl_s8(vget_low_s8(v3));
            step4!(
                [
                    vmovl_s16(vget_low_s16(lo0)),
                    vmovl_s16(vget_low_s16(lo1)),
                    vmovl_s16(vget_low_s16(lo2)),
                    vmovl_s16(vget_low_s16(lo3)),
                ],
                0
            );
            step4!(
                [vmovl_high_s16(lo0), vmovl_high_s16(lo1), vmovl_high_s16(lo2), vmovl_high_s16(lo3)],
                4
            );

            let hi0 = vmovl_high_s8(v0);
            let hi1 = vmovl_high_s8(v1);
            let hi2 = vmovl_high_s8(v2);
            let hi3 = vmovl_high_s8(v3);
            step4!(
                [
                    vmovl_s16(vget_low_s16(hi0)),
                    vmovl_s16(vget_low_s16(hi1)),
                    vmovl_s16(vget_low_s16(hi2)),
                    vmovl_s16(vget_low_s16(hi3)),
                ],
                8
            );
            step4!(
                [vmovl_high_s16(hi0), vmovl_high_s16(hi1), vmovl_high_s16(hi2), vmovl_high_s16(hi3)],
                12
            );
            k += 16;
        }
        *min_v = mv;
    }
    k
}

#[allow(clippy::too_many_arguments)]
#[cold]
#[inline(never)]
fn fold_rows_fast_w2(
    matrix: &[i8],
    rows: usize,
    cols: usize,
    weighted: &[Fp2],
    skip_pad_i8_scan: bool,
) -> Result<Vec<Fp2>, String> {
    use rayon::prelude::*;
    use std::sync::atomic::{AtomicBool, Ordering};

    let mut active_rows: Vec<(usize, i32, i32, i32, i32)> = Vec::with_capacity(rows);
    let mut zero_rows: Vec<usize> = Vec::new();
    for (i, &w) in weighted.iter().enumerate() {
        if w.is_zero() {
            zero_rows.push(i);
        } else {
            let (w0l, w0h) = split_signed_fp(w.c0);
            let (w1l, w1h) = split_signed_fp(w.c1);
            active_rows.push((i, w0l, w0h, w1l, w1h));
        }
    }
    if active_rows.is_empty() {
        if !skip_pad_i8_scan && has_i8_min_fast(matrix) {
            return Err(FOLD_ERR.into());
        }
        return Ok(vec![Fp2::ZERO; cols]);
    }

    let chunk = 256usize.min(cols);
    let mut out = vec![Fp2::ZERO; cols];
    let found_min = AtomicBool::new(false);

    let run_chunk = |ci: usize, oc: &mut [Fp2]| {
        if found_min.load(Ordering::Relaxed) {
            return;
        }
        let c0 = ci * chunk;
        let len = oc.len();
        let mut a0l = [0i64; 256];
        let mut a0h = [0i64; 256];
        let mut a1l = [0i64; 256];
        let mut a1h = [0i64; 256];
        let mut min_scalar = 0i8;

        #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
        // SAFETY: `target_feature = "neon"` is enabled at compile time.
        let mut min_v = unsafe { core::arch::aarch64::vdupq_n_s8(0) };

        #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
        let active_rem: &[(usize, i32, i32, i32, i32)] = if len >= 16 {
            let mut quads = active_rows.chunks_exact(4);
            for q in &mut quads {
                let r0 = &matrix[q[0].0 * cols + c0..q[0].0 * cols + c0 + len];
                let r1 = &matrix[q[1].0 * cols + c0..q[1].0 * cols + c0 + len];
                let r2 = &matrix[q[2].0 * cols + c0..q[2].0 * cols + c0 + len];
                let r3 = &matrix[q[3].0 * cols + c0..q[3].0 * cols + c0 + len];
                let k = accum_4rows_chunk_neon(
                    [r0, r1, r2, r3],
                    [q[0].1, q[1].1, q[2].1, q[3].1],
                    [q[0].2, q[1].2, q[2].2, q[3].2],
                    [q[0].3, q[1].3, q[2].3, q[3].3],
                    [q[0].4, q[1].4, q[2].4, q[3].4],
                    &mut a0l[..len],
                    &mut a0h[..len],
                    &mut a1l[..len],
                    &mut a1h[..len],
                    &mut min_v,
                );
                if k < len {
                    for &(i, w0l, w0h, w1l, w1h) in q {
                        let row = &matrix[i * cols + c0..i * cols + c0 + len];
                        let (w0l, w0h, w1l, w1h) = (w0l as i64, w0h as i64, w1l as i64, w1h as i64);
                        for j in k..len {
                            let b = row[j];
                            min_scalar = min_scalar.min(b);
                            let v = b as i64;
                            a0l[j] += v * w0l;
                            a0h[j] += v * w0h;
                            a1l[j] += v * w1l;
                            a1h[j] += v * w1h;
                        }
                    }
                }
            }
            quads.remainder()
        } else {
            &active_rows
        };
        #[cfg(not(all(target_arch = "aarch64", target_feature = "neon")))]
        let active_rem: &[(usize, i32, i32, i32, i32)] = &active_rows;

        for &(i, w0l, w0h, w1l, w1h) in active_rem {
            let row = &matrix[i * cols + c0..i * cols + c0 + len];
            #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
            let k = if len >= 16 {
                accum_row_chunk_neon(
                    row,
                    w0l,
                    w0h,
                    w1l,
                    w1h,
                    &mut a0l[..len],
                    &mut a0h[..len],
                    &mut a1l[..len],
                    &mut a1h[..len],
                    &mut min_v,
                )
            } else {
                0
            };
            #[cfg(not(all(target_arch = "aarch64", target_feature = "neon")))]
            let k = 0usize;
            if k < len {
                let (w0l, w0h, w1l, w1h) = (w0l as i64, w0h as i64, w1l as i64, w1h as i64);
                for j in k..len {
                    let b = row[j];
                    min_scalar = min_scalar.min(b);
                    let v = b as i64;
                    a0l[j] += v * w0l;
                    a0h[j] += v * w0h;
                    a1l[j] += v * w1l;
                    a1h[j] += v * w1h;
                }
            }
        }

        #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
        {
            // SAFETY: `target_feature = "neon"` is enabled at compile time.
            min_scalar = min_scalar.min(unsafe { core::arch::aarch64::vminvq_s8(min_v) });
        }
        let mut saw_min = min_scalar == i8::MIN;
        if !skip_pad_i8_scan && !saw_min && !found_min.load(Ordering::Relaxed) {
            for &i in &zero_rows {
                let row = &matrix[i * cols + c0..i * cols + c0 + len];
                if slice_has_i8_min(row) {
                    saw_min = true;
                    break;
                }
            }
        }
        if saw_min {
            found_min.store(true, Ordering::Relaxed);
            return;
        }
        for k in 0..len {
            let s0 = (a0l[k] as i128) + ((a0h[k] as i128) << 32);
            let s1 = (a1l[k] as i128) + ((a1h[k] as i128) << 32);
            oc[k] = Fp2::new(reduce_i128(s0), reduce_i128(s1));
        }
    };

    if matrix.len() < (1 << 15) {
        for (ci, oc) in out.chunks_mut(chunk).enumerate() {
            run_chunk(ci, oc);
        }
    } else {
        out.par_chunks_mut(chunk)
            .enumerate()
            .for_each(|(ci, oc)| run_chunk(ci, oc));
    }

    if found_min.load(Ordering::Relaxed) {
        return Err(FOLD_ERR.into());
    }
    Ok(out)
}

fn fold_rows_fast(
    matrix: &[i8],
    rows: usize,
    cols: usize,
    weighted: &[Fp2],
) -> Result<Vec<Fp2>, String> {
    use rayon::prelude::*;
    use std::sync::atomic::{AtomicBool, Ordering};

    let mut active_rows: Vec<(usize, i32, i32, i32, i32)> = Vec::with_capacity(rows);
    let mut zero_rows: Vec<usize> = Vec::new();
    for (i, &w) in weighted.iter().enumerate() {
        if w.is_zero() {
            zero_rows.push(i);
        } else {
            let (w0l, w0h) = split_signed_fp(w.c0);
            let (w1l, w1h) = split_signed_fp(w.c1);
            active_rows.push((i, w0l, w0h, w1l, w1h));
        }
    }
    if active_rows.is_empty() {
        if has_i8_min_fast(matrix) {
            return Err(FOLD_ERR.into());
        }
        return Ok(vec![Fp2::ZERO; cols]);
    }

    let chunk = 256usize.min(cols);
    let mut out = vec![Fp2::ZERO; cols];
    let found_min = AtomicBool::new(false);

    let run_chunk = |ci: usize, oc: &mut [Fp2]| {
        if found_min.load(Ordering::Relaxed) {
            return;
        }
        let c0 = ci * chunk;
        let len = oc.len();
        let mut a0l = [0i64; 256];
        let mut a0h = [0i64; 256];
        let mut a1l = [0i64; 256];
        let mut a1h = [0i64; 256];
        let mut min_scalar = 0i8;

        #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
        // SAFETY: `target_feature = "neon"` is enabled at compile time.
        let mut min_v = unsafe { core::arch::aarch64::vdupq_n_s8(0) };

        for &(i, w0l, w0h, w1l, w1h) in &active_rows {
            let row = &matrix[i * cols + c0..i * cols + c0 + len];
            #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
            let k = if len >= 16 {
                accum_row_chunk_neon(
                    row,
                    w0l,
                    w0h,
                    w1l,
                    w1h,
                    &mut a0l[..len],
                    &mut a0h[..len],
                    &mut a1l[..len],
                    &mut a1h[..len],
                    &mut min_v,
                )
            } else {
                0
            };
            #[cfg(not(all(target_arch = "aarch64", target_feature = "neon")))]
            let k = 0usize;
            if k < len {
                let (w0l, w0h, w1l, w1h) = (w0l as i64, w0h as i64, w1l as i64, w1h as i64);
                for j in k..len {
                    let b = row[j];
                    min_scalar = min_scalar.min(b);
                    let v = b as i64;
                    a0l[j] += v * w0l;
                    a0h[j] += v * w0h;
                    a1l[j] += v * w1l;
                    a1h[j] += v * w1h;
                }
            }
        }

        #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
        {
            // SAFETY: `target_feature = "neon"` is enabled at compile time.
            min_scalar = min_scalar.min(unsafe { core::arch::aarch64::vminvq_s8(min_v) });
        }
        let mut saw_min = min_scalar == i8::MIN;
        if !saw_min && !found_min.load(Ordering::Relaxed) {
            for &i in &zero_rows {
                let row = &matrix[i * cols + c0..i * cols + c0 + len];
                if slice_has_i8_min(row) {
                    saw_min = true;
                    break;
                }
            }
        }
        if saw_min {
            found_min.store(true, Ordering::Relaxed);
            return;
        }
        for k in 0..len {
            let s0 = (a0l[k] as i128) + ((a0h[k] as i128) << 32);
            let s1 = (a1l[k] as i128) + ((a1h[k] as i128) << 32);
            oc[k] = Fp2::new(reduce_i128(s0), reduce_i128(s1));
        }
    };

    if matrix.len() < (1 << 15) {
        for (ci, oc) in out.chunks_mut(chunk).enumerate() {
            run_chunk(ci, oc);
        }
    } else {
        out.par_chunks_mut(chunk).enumerate().for_each(|(ci, oc)| run_chunk(ci, oc));
    }

    if found_min.load(Ordering::Relaxed) {
        return Err(FOLD_ERR.into());
    }
    Ok(out)
}

#[inline]
fn dot_active_slice(
    row: &[i8],
    w0l: &[i32],
    w0h: &[i32],
    w1l: &[i32],
    w1h: &[i32],
) -> (Fp2, bool) {
    let n = row.len();
    assert!(w0l.len() == n && w0h.len() == n && w1l.len() == n && w1h.len() == n);

    #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
    let (mut s0l, mut s0h, mut s1l, mut s1h, mut min_scalar, mut j) = {
        use core::arch::aarch64::{
            vaddq_s64, vaddvq_s64, vdupq_n_s64, vdupq_n_s8, vget_low_s16, vget_low_s32,
            vget_low_s8, vld1q_s32, vld1q_s8, vminq_s8, vminvq_s8, vmlal_high_s32, vmlal_s32,
            vmovl_high_s16, vmovl_high_s8, vmovl_s16, vmovl_s8,
        };
        let rp = row.as_ptr();
        let (p0l, p0h, p1l, p1h) = (w0l.as_ptr(), w0h.as_ptr(), w1l.as_ptr(), w1h.as_ptr());
        let mut j = 0usize;
        // SAFETY: `target_feature = "neon"` is enabled at compile time; `j + 16 <= n` and all 5 slices have length `n`.
        unsafe {
            let mut mv = vdupq_n_s8(0);
            let (mut a0l_a, mut a0l_b) = (vdupq_n_s64(0), vdupq_n_s64(0));
            let (mut a0h_a, mut a0h_b) = (vdupq_n_s64(0), vdupq_n_s64(0));
            let (mut a1l_a, mut a1l_b) = (vdupq_n_s64(0), vdupq_n_s64(0));
            let (mut a1h_a, mut a1h_b) = (vdupq_n_s64(0), vdupq_n_s64(0));
            while j + 16 <= n {
                let v = vld1q_s8(rp.add(j));
                mv = vminq_s8(mv, v);
                let lo16 = vmovl_s8(vget_low_s8(v));
                let hi16 = vmovl_high_s8(v);
                let x0 = vmovl_s16(vget_low_s16(lo16));
                let x1 = vmovl_high_s16(lo16);
                let x2 = vmovl_s16(vget_low_s16(hi16));
                let x3 = vmovl_high_s16(hi16);

                macro_rules! step {
                    ($x:expr, $off:expr) => {{
                        let x = $x;
                        let x_lo = vget_low_s32(x);
                        let off = j + $off;
                        let wl0 = vld1q_s32(p0l.add(off));
                        let wh0 = vld1q_s32(p0h.add(off));
                        let wl1 = vld1q_s32(p1l.add(off));
                        let wh1 = vld1q_s32(p1h.add(off));
                        a0l_a = vmlal_s32(a0l_a, x_lo, vget_low_s32(wl0));
                        a0l_b = vmlal_high_s32(a0l_b, x, wl0);
                        a0h_a = vmlal_s32(a0h_a, x_lo, vget_low_s32(wh0));
                        a0h_b = vmlal_high_s32(a0h_b, x, wh0);
                        a1l_a = vmlal_s32(a1l_a, x_lo, vget_low_s32(wl1));
                        a1l_b = vmlal_high_s32(a1l_b, x, wl1);
                        a1h_a = vmlal_s32(a1h_a, x_lo, vget_low_s32(wh1));
                        a1h_b = vmlal_high_s32(a1h_b, x, wh1);
                    }};
                }
                step!(x0, 0);
                step!(x1, 4);
                step!(x2, 8);
                step!(x3, 12);
                j += 16;
            }
            (
                vaddvq_s64(vaddq_s64(a0l_a, a0l_b)),
                vaddvq_s64(vaddq_s64(a0h_a, a0h_b)),
                vaddvq_s64(vaddq_s64(a1l_a, a1l_b)),
                vaddvq_s64(vaddq_s64(a1h_a, a1h_b)),
                vminvq_s8(mv),
                j,
            )
        }
    };
    #[cfg(not(all(target_arch = "aarch64", target_feature = "neon")))]
    let (mut s0l, mut s0h, mut s1l, mut s1h, mut min_scalar, mut j) = (0i64, 0i64, 0i64, 0i64, 0i8, 0usize);

    while j < n {
        let b = row[j];
        min_scalar = min_scalar.min(b);
        let v = b as i64;
        s0l += v * (w0l[j] as i64);
        s0h += v * (w0h[j] as i64);
        s1l += v * (w1l[j] as i64);
        s1h += v * (w1h[j] as i64);
        j += 1;
    }
    let s0 = (s0l as i128) + ((s0h as i128) << 32);
    let s1 = (s1l as i128) + ((s1h as i128) << 32);
    (Fp2::new(reduce_i128(s0), reduce_i128(s1)), min_scalar == i8::MIN)
}

/// **[HOST-FAST-W2 W2-6a]** 4-row L1-tiled NEON dot product for `fold_cols_fast`:
/// processes 4 matrix rows simultaneously over `COL_TILE = 1024` tiles of
/// `w0l..w1h` (16 KiB weights + 4 KiB rows = 20 KiB L1 working set), loading
/// each weight vector ONCE per 4 rows (cutting L2 weight traffic 4x).
#[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
#[inline]
fn dot_4rows_tiled_neon(
    rows: [&[i8]; 4],
    w0l: &[i32],
    w0h: &[i32],
    w1l: &[i32],
    w1h: &[i32],
) -> ([Fp2; 4], bool) {
    use core::arch::aarch64::{
        vaddvq_s64, vdupq_n_s64, vdupq_n_s8, vget_low_s16, vget_low_s32, vget_low_s8, vld1q_s32,
        vld1q_s8, vminq_s8, vminvq_s8, vmlal_high_s32, vmlal_s32, vmovl_high_s16, vmovl_high_s8,
        vmovl_s16, vmovl_s8,
    };
    const COL_TILE: usize = 1024;
    let n = rows[0].len();
    assert!(
        rows[1].len() == n
            && rows[2].len() == n
            && rows[3].len() == n
            && w0l.len() == n
            && w0h.len() == n
            && w1l.len() == n
            && w1h.len() == n
    );
    let rps = [rows[0].as_ptr(), rows[1].as_ptr(), rows[2].as_ptr(), rows[3].as_ptr()];
    let (p0l, p0h, p1l, p1h) = (w0l.as_ptr(), w0h.as_ptr(), w1l.as_ptr(), w1h.as_ptr());

    // SAFETY: `target_feature = "neon"` is enabled at compile time; `COL_TILE = 1024` is a
    // multiple of 16 so every tile runs `j + 16 <= t1 <= n` and covers `[0, n & !15)` exactly.
    let (mut s0l, mut s0h, mut s1l, mut s1h, mut min_scalar) = unsafe {
        let mut mv = vdupq_n_s8(0);
        let mut a0l = [vdupq_n_s64(0); 4];
        let mut a0h = [vdupq_n_s64(0); 4];
        let mut a1l = [vdupq_n_s64(0); 4];
        let mut a1h = [vdupq_n_s64(0); 4];

        let mut t0 = 0usize;
        while t0 < n {
            let t1 = (t0 + COL_TILE).min(n);
            let mut j = t0;
            while j + 16 <= t1 {
                let v0 = vld1q_s8(rps[0].add(j));
                let v1 = vld1q_s8(rps[1].add(j));
                let v2 = vld1q_s8(rps[2].add(j));
                let v3 = vld1q_s8(rps[3].add(j));
                mv = vminq_s8(mv, vminq_s8(vminq_s8(v0, v1), vminq_s8(v2, v3)));

                macro_rules! step4 {
                    ($xs:expr, $off:expr) => {{
                        let off = j + $off;
                        let wl0 = vld1q_s32(p0l.add(off));
                        let wh0 = vld1q_s32(p0h.add(off));
                        let wl1 = vld1q_s32(p1l.add(off));
                        let wh1 = vld1q_s32(p1h.add(off));
                        let wl0_lo = vget_low_s32(wl0);
                        let wh0_lo = vget_low_s32(wh0);
                        let wl1_lo = vget_low_s32(wl1);
                        let wh1_lo = vget_low_s32(wh1);
                        for r in 0..4 {
                            let x = $xs[r];
                            let x_lo = vget_low_s32(x);
                            a0l[r] = vmlal_s32(a0l[r], x_lo, wl0_lo);
                            a0l[r] = vmlal_high_s32(a0l[r], x, wl0);
                            a0h[r] = vmlal_s32(a0h[r], x_lo, wh0_lo);
                            a0h[r] = vmlal_high_s32(a0h[r], x, wh0);
                            a1l[r] = vmlal_s32(a1l[r], x_lo, wl1_lo);
                            a1l[r] = vmlal_high_s32(a1l[r], x, wl1);
                            a1h[r] = vmlal_s32(a1h[r], x_lo, wh1_lo);
                            a1h[r] = vmlal_high_s32(a1h[r], x, wh1);
                        }
                    }};
                }

                let lo0 = vmovl_s8(vget_low_s8(v0));
                let lo1 = vmovl_s8(vget_low_s8(v1));
                let lo2 = vmovl_s8(vget_low_s8(v2));
                let lo3 = vmovl_s8(vget_low_s8(v3));
                step4!(
                    [
                        vmovl_s16(vget_low_s16(lo0)),
                        vmovl_s16(vget_low_s16(lo1)),
                        vmovl_s16(vget_low_s16(lo2)),
                        vmovl_s16(vget_low_s16(lo3)),
                    ],
                    0
                );
                step4!(
                    [vmovl_high_s16(lo0), vmovl_high_s16(lo1), vmovl_high_s16(lo2), vmovl_high_s16(lo3)],
                    4
                );

                let hi0 = vmovl_high_s8(v0);
                let hi1 = vmovl_high_s8(v1);
                let hi2 = vmovl_high_s8(v2);
                let hi3 = vmovl_high_s8(v3);
                step4!(
                    [
                        vmovl_s16(vget_low_s16(hi0)),
                        vmovl_s16(vget_low_s16(hi1)),
                        vmovl_s16(vget_low_s16(hi2)),
                        vmovl_s16(vget_low_s16(hi3)),
                    ],
                    8
                );
                step4!(
                    [vmovl_high_s16(hi0), vmovl_high_s16(hi1), vmovl_high_s16(hi2), vmovl_high_s16(hi3)],
                    12
                );
                j += 16;
            }
            t0 = t1;
        }
        (
            [vaddvq_s64(a0l[0]), vaddvq_s64(a0l[1]), vaddvq_s64(a0l[2]), vaddvq_s64(a0l[3])],
            [vaddvq_s64(a0h[0]), vaddvq_s64(a0h[1]), vaddvq_s64(a0h[2]), vaddvq_s64(a0h[3])],
            [vaddvq_s64(a1l[0]), vaddvq_s64(a1l[1]), vaddvq_s64(a1l[2]), vaddvq_s64(a1l[3])],
            [vaddvq_s64(a1h[0]), vaddvq_s64(a1h[1]), vaddvq_s64(a1h[2]), vaddvq_s64(a1h[3])],
            vminvq_s8(mv),
        )
    };

    let mut j = n & !15usize;
    while j < n {
        let (wl0, wh0, wl1, wh1) = (w0l[j] as i64, w0h[j] as i64, w1l[j] as i64, w1h[j] as i64);
        for r in 0..4 {
            let b = rows[r][j];
            min_scalar = min_scalar.min(b);
            let v = b as i64;
            s0l[r] += v * wl0;
            s0h[r] += v * wh0;
            s1l[r] += v * wl1;
            s1h[r] += v * wh1;
        }
        j += 1;
    }

    let out = std::array::from_fn(|r| {
        let s0 = (s0l[r] as i128) + ((s0h[r] as i128) << 32);
        let s1 = (s1l[r] as i128) + ((s1h[r] as i128) << 32);
        Fp2::new(reduce_i128(s0), reduce_i128(s1))
    });
    (out, min_scalar == i8::MIN)
}

#[cold]
#[inline(never)]
fn fold_cols_fast_w2(
    matrix: &[i8],
    rows: usize,
    cols: usize,
    weighted: &[Fp2],
    skip_pad_i8_scan: bool,
) -> Result<Vec<Fp2>, String> {
    use rayon::prelude::*;
    use std::sync::atomic::{AtomicBool, Ordering};

    let Some(active_start) = weighted.iter().position(|w| !w.is_zero()) else {
        if !skip_pad_i8_scan && has_i8_min_fast(matrix) {
            return Err(FOLD_ERR.into());
        }
        return Ok(vec![Fp2::ZERO; rows]);
    };
    let active_end = weighted.iter().rposition(|w| !w.is_zero()).expect("at least one nonzero weight") + 1;
    let active_len = active_end - active_start;
    let mut w0l = Vec::with_capacity(active_len);
    let mut w0h = Vec::with_capacity(active_len);
    let mut w1l = Vec::with_capacity(active_len);
    let mut w1h = Vec::with_capacity(active_len);
    for &w in &weighted[active_start..active_end] {
        let (l0, h0) = split_signed_fp(w.c0);
        let (l1, h1) = split_signed_fp(w.c1);
        w0l.push(l0);
        w0h.push(h0);
        w1l.push(l1);
        w1h.push(h1);
    }

    let mut out = vec![Fp2::ZERO; rows];
    let found_min = AtomicBool::new(false);

    let run_rows = |r0: usize, oc: &mut [Fp2]| {
        if found_min.load(Ordering::Relaxed) {
            return;
        }
        let mut saw_min = false;
        let mut dr = 0usize;
        #[cfg(all(target_arch = "aarch64", target_feature = "neon"))]
        {
            while dr + 4 <= oc.len() {
                let i0 = r0 + dr;
                let row0 = &matrix[i0 * cols..(i0 + 1) * cols];
                let row1 = &matrix[(i0 + 1) * cols..(i0 + 2) * cols];
                let row2 = &matrix[(i0 + 2) * cols..(i0 + 3) * cols];
                let row3 = &matrix[(i0 + 3) * cols..(i0 + 4) * cols];
                let (vals, active_min) = dot_4rows_tiled_neon(
                    [
                        &row0[active_start..active_end],
                        &row1[active_start..active_end],
                        &row2[active_start..active_end],
                        &row3[active_start..active_end],
                    ],
                    &w0l,
                    &w0h,
                    &w1l,
                    &w1h,
                );
                let pad_min = !skip_pad_i8_scan
                    && [row0, row1, row2, row3].iter().any(|row| {
                        (active_start > 0 && slice_has_i8_min(&row[..active_start]))
                            || (active_end < cols && slice_has_i8_min(&row[active_end..cols]))
                    });
                if active_min || pad_min {
                    saw_min = true;
                    break;
                }
                oc[dr..dr + 4].copy_from_slice(&vals);
                dr += 4;
            }
        }
        if !saw_min {
            while dr < oc.len() {
                let i = r0 + dr;
                let row = &matrix[i * cols..(i + 1) * cols];
                let (val, active_min) = dot_active_slice(
                    &row[active_start..active_end],
                    &w0l,
                    &w0h,
                    &w1l,
                    &w1h,
                );
                if active_min
                    || (!skip_pad_i8_scan
                        && ((active_start > 0 && slice_has_i8_min(&row[..active_start]))
                            || (active_end < cols && slice_has_i8_min(&row[active_end..cols]))))
                {
                    saw_min = true;
                    break;
                }
                oc[dr] = val;
                dr += 1;
            }
        }
        if saw_min {
            found_min.store(true, Ordering::Relaxed);
        }
    };

    if matrix.len() < (1 << 15) {
        run_rows(0, &mut out);
    } else {
        let row_chunk = 16usize.min(rows);
        out.par_chunks_mut(row_chunk)
            .enumerate()
            .for_each(|(ci, oc)| run_rows(ci * row_chunk, oc));
    }

    if found_min.load(Ordering::Relaxed) {
        return Err(FOLD_ERR.into());
    }
    Ok(out)
}

fn fold_cols_fast(
    matrix: &[i8],
    rows: usize,
    cols: usize,
    weighted: &[Fp2],
) -> Result<Vec<Fp2>, String> {
    use rayon::prelude::*;
    use std::sync::atomic::{AtomicBool, Ordering};

    let Some(active_start) = weighted.iter().position(|w| !w.is_zero()) else {
        if has_i8_min_fast(matrix) {
            return Err(FOLD_ERR.into());
        }
        return Ok(vec![Fp2::ZERO; rows]);
    };
    let active_end = weighted.iter().rposition(|w| !w.is_zero()).expect("at least one nonzero weight") + 1;
    let active_len = active_end - active_start;
    let mut w0l = Vec::with_capacity(active_len);
    let mut w0h = Vec::with_capacity(active_len);
    let mut w1l = Vec::with_capacity(active_len);
    let mut w1h = Vec::with_capacity(active_len);
    for &w in &weighted[active_start..active_end] {
        let (l0, h0) = split_signed_fp(w.c0);
        let (l1, h1) = split_signed_fp(w.c1);
        w0l.push(l0);
        w0h.push(h0);
        w1l.push(l1);
        w1h.push(h1);
    }

    let mut out = vec![Fp2::ZERO; rows];
    let found_min = AtomicBool::new(false);

    let run_rows = |r0: usize, oc: &mut [Fp2]| {
        if found_min.load(Ordering::Relaxed) {
            return;
        }
        let mut saw_min = false;
        for (dr, slot) in oc.iter_mut().enumerate() {
            let i = r0 + dr;
            let row = &matrix[i * cols..(i + 1) * cols];
            let (val, active_min) = dot_active_slice(
                &row[active_start..active_end],
                &w0l,
                &w0h,
                &w1l,
                &w1h,
            );
            if active_min
                || (active_start > 0 && slice_has_i8_min(&row[..active_start]))
                || (active_end < cols && slice_has_i8_min(&row[active_end..cols]))
            {
                saw_min = true;
                break;
            }
            *slot = val;
        }
        if saw_min {
            found_min.store(true, Ordering::Relaxed);
        }
    };

    if matrix.len() < (1 << 15) {
        run_rows(0, &mut out);
    } else {
        let row_chunk = 16usize.min(rows);
        out.par_chunks_mut(row_chunk)
            .enumerate()
            .for_each(|(ci, oc)| run_rows(ci * row_chunk, oc));
    }

    if found_min.load(Ordering::Relaxed) {
        return Err(FOLD_ERR.into());
    }
    Ok(out)
}

fn fold_with_mode(
    matrix: &[i8],
    rows: usize,
    cols: usize,
    axis: Axis,
    coefficients: &[u64],
    eq: &[Fp2],
    fast: bool,
) -> Result<Vec<Fp2>, String> {
    let outputs = if axis == Axis::Rows { rows } else { cols };
    if !rows.is_power_of_two()
        || !cols.is_power_of_two()
        || rows.checked_mul(cols) != Some(matrix.len())
        || outputs != coefficients.len()
        || outputs != eq.len()
        || coefficients.iter().any(|&m| m > 1 << 14)
    {
        return Err(FOLD_ERR.into());
    }
    if fast && rows <= HOST_FAST_MAX_DIM && cols <= HOST_FAST_MAX_DIM {
        let weighted: Vec<Fp2> = eq
            .iter()
            .zip(coefficients)
            .map(|(&e, &m)| e.mul_base(Fp2::from_i64(m as i64).c0))
            .collect();
        return match axis {
            Axis::Rows => fold_rows_fast(matrix, rows, cols, &weighted),
            Axis::Columns => fold_cols_fast(matrix, rows, cols, &weighted),
        };
    }
    if has_i8_min(matrix) {
        return Err(FOLD_ERR.into());
    }
    let weighted: Vec<Fp2> = eq
        .iter()
        .zip(coefficients)
        .map(|(&e, &m)| e.mul_base(Fp2::from_i64(m as i64).c0))
        .collect();
    Ok(match axis {
        Axis::Rows => fold_rows_i8(matrix, rows, cols, &weighted),
        Axis::Columns => fold_cols_i8(matrix, rows, cols, &weighted),
    })
}

#[cold]
#[inline(never)]
fn fold_w2(
    matrix: &[i8],
    rows: usize,
    cols: usize,
    axis: Axis,
    coefficients: &[u64],
    eq: &[Fp2],
    skip_pad_i8_scan: bool,
) -> Result<Vec<Fp2>, String> {
    let outputs = if axis == Axis::Rows { rows } else { cols };
    if !rows.is_power_of_two()
        || !cols.is_power_of_two()
        || rows.checked_mul(cols) != Some(matrix.len())
        || outputs != coefficients.len()
        || outputs != eq.len()
        || coefficients.iter().any(|&m| m > 1 << 14)
    {
        return Err(FOLD_ERR.into());
    }
    let fast = crate::zk::host_fast_on();
    let in_dim = rows <= HOST_FAST_MAX_DIM && cols <= HOST_FAST_MAX_DIM;
    let out = if in_dim {
        let weighted: Vec<Fp2> = eq
            .iter()
            .zip(coefficients)
            .map(|(&e, &m)| e.mul_base(Fp2::from_i64(m as i64).c0))
            .collect();
        match axis {
            Axis::Rows => fold_rows_fast_w2(matrix, rows, cols, &weighted, skip_pad_i8_scan)?,
            Axis::Columns => fold_cols_fast_w2(matrix, rows, cols, &weighted, skip_pad_i8_scan)?,
        }
    } else {
        fold_with_mode(matrix, rows, cols, axis, coefficients, eq, false)?
    };
    if fast {
        if in_dim {
            crate::zk::record_host_fast_hit(crate::zk::HF_H4_ACC_FOLD);
        } else {
            crate::zk::record_host_fast_fallback(crate::zk::HF_FB_H4_DIM, "H4 acc_fold: rows or cols > HOST_FAST_MAX_DIM");
        }
    }
    if in_dim {
        crate::zk::record_host_fast_w2_hit(crate::zk::HF_W2_FOLD_TILED);
    }
    Ok(out)
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn fold_checked(
    matrix: &[i8],
    rows: usize,
    cols: usize,
    axis: Axis,
    coefficients: &[u64],
    eq: &[Fp2],
    registry_checked: bool,
    prove_side: bool,
) -> Result<Vec<Fp2>, String> {
    // Verifier side (and direct non-prover callers) NEVER read speed switches,
    // ALWAYS run the base fold, and NEVER increment any speed-switch counter.
    if !prove_side {
        return fold_with_mode(matrix, rows, cols, axis, coefficients, eq, false);
    }
    if crate::zk::host_fast_w2_on() {
        return fold_w2(matrix, rows, cols, axis, coefficients, eq, registry_checked);
    }
    let fast = crate::zk::host_fast_on();
    let out = fold_with_mode(matrix, rows, cols, axis, coefficients, eq, fast)?;
    if fast {
        if rows <= HOST_FAST_MAX_DIM && cols <= HOST_FAST_MAX_DIM {
            crate::zk::record_host_fast_hit(crate::zk::HF_H4_ACC_FOLD);
        } else {
            crate::zk::record_host_fast_fallback(crate::zk::HF_FB_H4_DIM, "H4 acc_fold: rows or cols > HOST_FAST_MAX_DIM");
        }
    }
    Ok(out)
}

#[allow(dead_code)]
pub(crate) fn fold(
    matrix:&[i8],rows:usize,cols:usize,axis:Axis,coefficients:&[u64],eq:&[Fp2],
)->Result<Vec<Fp2>,String> {
    fold_checked(matrix, rows, cols, axis, coefficients, eq, false, false)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::accuracy_precision::{Stack,BaseShifts};
    use crate::private_block::accuracy_public::Multipliers;
    use crate::private_block::accuracy_groups::Group;
    use crate::private_block::accuracy_tables::silu_table;
    use crate::mle::eq_table_msb;

    fn fixture()->(Shape,AccuracyPublic) {
        let sh=Shape::new("R13 scaled-fold fixture","r13-scaled-fold-fixture",32,48,6,6,8,2,8,8,9,13,None,None,None,None).unwrap();
        let values=|n:usize,max:usize|(0..n).map(|i|(i%max+1) as u16).collect();
        let m=Multipliers{q:values(48,32),k:values(16,32),v:values(16,64),o:values(48,256),
            g:values(6,64),u:values(6,16),d:values(48,64)};
        let groups=vec![Group{e_in:-4,e_out:-13},Group{e_in:-1,e_out:-11}];
        let tables=groups.iter().map(|g|silu_table(g.e_in,g.e_out,12).unwrap()).collect();
        let data=AccuracyPublic::new(Stack::LowH24,Geometry{width:48,query_width:48,kv_width:16,hidden:6},
            BaseShifts{norm_tn:10,qkv:8,score:6,pv:9,ao:7,gate:8,up:0,product:14,down:6},
            (-3,-11),m,groups,vec![0,1,0,1,0,1],tables).unwrap();
        (sh,data)
    }

    #[test]
    fn every_axis_uses_exact_channel_coefficients_and_query_head_permutation() {
        let (sh,a)=fixture();
        for site in [Site::Q,Site::K,Site::V,Site::O,Site::Gate,Site::Up,Site::Down] {
            let c=coefficients(&sh,&a,site).unwrap();
            if site==Site::Q {
                for h in 0..sh.q_heads {for i in 0..sh.head_dim {
                    assert_eq!(c[sh.head_slot(h)*sh.head_dim+i],a.multipliers().q[h*sh.head_dim+i] as u64);
                }}
                assert!(c[24..32].iter().chain(&c[56..64]).all(|&v|v==0));
            } else {
                let expected:Vec<u64>=match site {Site::K=>&a.multipliers().k,Site::V=>&a.multipliers().v,
                    Site::O=>&a.multipliers().o,Site::Up=>&a.multipliers().u,Site::Down=>&a.multipliers().d,
                    Site::Gate=>{assert_eq!(&c[..6],a.folds().gate.multipliers.as_slice());assert!(c[6..].iter().all(|&v|v==0));continue},
                    Site::Q=>unreachable!()}.iter().map(|&v|v as u64).collect();
                assert_eq!(&c[..expected.len()],&expected);assert!(c[expected.len()..].iter().all(|&v|v==0));
            }
        }
    }

    #[test]
    fn all_seven_native_matrix_folds_equal_an_independent_scaled_coefficient_sum() {
        let (sh,a)=fixture();
        for site in [Site::Q,Site::K,Site::V,Site::O,Site::Gate,Site::Up,Site::Down] {
            let coefficients=coefficients(&sh,&a,site).unwrap();
            let axis=if matches!(site,Site::Gate|Site::Up|Site::Down) {Axis::Columns} else {Axis::Rows};
            let outputs=coefficients.len();let inner=if matches!(site,Site::O) {sh.q_pad()} else if site==Site::Down {sh.f_pad} else {sh.d_pad};
            let (rows,cols)=if axis==Axis::Rows {(outputs,inner)} else {(inner,outputs)};
            let matrix:Vec<i8>=(0..rows*cols).map(|i|((i*73+19)%255) as i16-127).map(|v|v as i8).collect();
            let r:Vec<_>=(0..outputs.trailing_zeros()).map(|i|Fp2::from_i64(i as i64+2)).collect();
            let eq=eq_table_msb(&r);
            let got=fold(&matrix,rows,cols,axis,&coefficients,&eq).unwrap();
            let expected:Vec<_>=(0..inner).map(|i| (0..outputs).fold(Fp2::ZERO,|acc,j| {
                let w=matrix[if axis==Axis::Rows {j*cols+i} else {i*cols+j}];
                acc.add(eq[j].mul(Fp2::from_i64(w as i64*coefficients[j] as i64)))
            })).collect();
            assert_eq!(got,expected,"{site:?}");
        }
    }

    #[test]
    fn multiplying_interpolants_after_folding_is_rejected_by_the_differential_case() {
        let eq=eq_table_msb(&[Fp2::from_i64(2)]);
        let correct=fold(&[1,3],2,1,Axis::Rows,&[2,5],&eq).unwrap()[0];
        let wrong=fold_rows_i8(&[1,3],2,1,&eq)[0].mul(eq[0].mul(Fp2::from_i64(2)).add(eq[1].mul(Fp2::from_i64(5))));
        assert_ne!(correct,wrong);
        assert_eq!(correct,Fp2::from_i64(28));
        assert!(fold(&[-128,3],2,1,Axis::Rows,&[2,5],&eq).is_err());
        assert!(fold(&[1,3],2,1,Axis::Rows,&[2,1<<15],&eq).is_err());
        assert!(fold(&[1,3],2,1,Axis::Rows,&[2],&eq).is_err());
    }

    fn splitmix64(s: &mut u64) -> u64 {
        *s = s.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = *s;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    #[test]
    fn h4_split_signed_fp_exact_on_boundaries_and_random() {
        let mut cases = vec![
            0u64,
            1,
            2,
            0x7FFF_FFFF,
            0x8000_0000,
            0xFFFF_FFFF,
            0x1_0000_0000,
            0x7FFF_FFFE_8000_0000,
            0x7FFF_FFFE_FFFF_FFFF,
            0x7FFF_FFFF_0000_0000,
            0x7FFF_FFFF_7FFF_FFFE,
            0x7FFF_FFFF_7FFF_FFFF,
            0x7FFF_FFFF_8000_0000,
            0x7FFF_FFFF_8000_0001,
            0x8000_0000_0000_0000,
            P - 0x8000_0001,
            P - 0x8000_0000,
            P - 0x7FFF_FFFF,
            P - 2,
            P - 1,
        ];
        let mut rng = 0x4444_5555_6666_7777u64;
        for _ in 0..50_000 {
            cases.push(splitmix64(&mut rng) % P);
        }
        for u in cases {
            let a = Fp(u);
            let (lo, hi) = split_signed_fp(a);
            let recon = (lo as i128) + ((hi as i128) << 32);
            assert_eq!(reduce_i128(recon), a, "u={u:#x}, lo={lo}, hi={hi}");
        }
    }

    #[test]
    fn h4_fast_matches_baseline_across_all_seven_sites_and_extremes() {
        let (sh, a) = fixture();
        let mut rng = 0xA11_5EED_0004u64;
        for site in [Site::Q, Site::K, Site::V, Site::O, Site::Gate, Site::Up, Site::Down] {
            let coeffs = coefficients(&sh, &a, site).unwrap();
            let axis = if matches!(site, Site::Gate | Site::Up | Site::Down) {
                Axis::Columns
            } else {
                Axis::Rows
            };
            let outputs = coeffs.len();
            let inner = if matches!(site, Site::O) {
                sh.q_pad()
            } else if site == Site::Down {
                sh.f_pad
            } else {
                sh.d_pad
            };
            let (rows, cols) = if axis == Axis::Rows {
                (outputs, inner)
            } else {
                (inner, outputs)
            };
            let r: Vec<Fp2> = (0..outputs.trailing_zeros())
                .map(|_| Fp2::new(Fp(splitmix64(&mut rng) % P), Fp(splitmix64(&mut rng) % P)))
                .collect();
            let eq = eq_table_msb(&r);
            let rand_mat: Vec<i8> = (0..rows * cols)
                .map(|_| ((splitmix64(&mut rng) % 255) as i16 - 127) as i8)
                .collect();
            let alt_mat: Vec<i8> = (0..rows * cols)
                .map(|i| if i % 2 == 0 { 127 } else { -127 })
                .collect();
            for (tag, mat) in [
                ("random", rand_mat),
                ("all-zero", vec![0i8; rows * cols]),
                ("all-+127", vec![127i8; rows * cols]),
                ("all--127", vec![-127i8; rows * cols]),
                ("alt-+-127", alt_mat),
            ] {
                let want = fold_with_mode(&mat, rows, cols, axis, &coeffs, &eq, false).unwrap();
                let got = fold_with_mode(&mat, rows, cols, axis, &coeffs, &eq, true).unwrap();
                assert_eq!(got, want, "site={site:?} case={tag}");
            }
        }
    }

    #[test]
    fn h4_fast_matches_baseline_large_parallel_and_padded_layouts() {
        let mut rng = 0x51D_4F01_D999u64;
        // Exercise small sequential + large parallel (>= 32768) shapes, non-multiple-of-16
        // active spans, leading/middle/trailing zero-coefficient padding, all-zero weights,
        // and extreme field elements near the signed-limb split boundary.
        let extreme_eq = [
            Fp2::new(Fp(0x7FFF_FFFF_7FFF_FFFF), Fp(0x7FFF_FFFF_8000_0000)),
            Fp2::new(Fp(P - 1), Fp(1)),
            Fp2::new(Fp(0x8000_0000), Fp(0x7FFF_FFFF)),
            Fp2::new(Fp(0), Fp(P - 0x8000_0001)),
        ];
        for &(rows, cols, axis) in &[
            (1usize, 1usize, Axis::Rows),
            (1, 1, Axis::Columns),
            (4, 2, Axis::Rows),
            (2, 4, Axis::Columns),
            (16, 8, Axis::Rows),
            (8, 16, Axis::Columns),
            (32, 32, Axis::Rows),
            (32, 32, Axis::Columns),
            (128, 512, Axis::Rows),
            (128, 512, Axis::Columns),
            (256, 256, Axis::Rows),
            (256, 256, Axis::Columns),
            (512, 128, Axis::Rows),
            (512, 128, Axis::Columns),
        ] {
            let outputs = if axis == Axis::Rows { rows } else { cols };
            let mat: Vec<i8> = (0..rows * cols)
                .map(|_| ((splitmix64(&mut rng) % 255) as i16 - 127) as i8)
                .collect();
            let eq: Vec<Fp2> = (0..outputs)
                .map(|j| {
                    if j < extreme_eq.len() {
                        extreme_eq[j]
                    } else {
                        Fp2::new(Fp(splitmix64(&mut rng) % P), Fp(splitmix64(&mut rng) % P))
                    }
                })
                .collect();
            let patterns: Vec<(&str, Vec<u64>)> = vec![
                ("all-active", (0..outputs).map(|j| (j as u64 % 16384) + 1).collect()),
                ("all-zero", vec![0u64; outputs]),
                (
                    "prefix-active-odd",
                    (0..outputs)
                        .map(|j| if j < (outputs * 3 / 5).max(1) { ((j * 13) % 16384 + 1) as u64 } else { 0 })
                        .collect(),
                ),
                (
                    "middle-span-with-holes",
                    (0..outputs)
                        .map(|j| {
                            if j >= outputs / 4 && j < (outputs * 3 / 4).max(1) && j % 5 != 0 {
                                ((j * 7) % 16384 + 1) as u64
                            } else {
                                0
                            }
                        })
                        .collect(),
                ),
            ];
            for (name, coeffs) in patterns {
                let want = fold_with_mode(&mat, rows, cols, axis, &coeffs, &eq, false).unwrap();
                let got = fold_with_mode(&mat, rows, cols, axis, &coeffs, &eq, true).unwrap();
                assert_eq!(got, want, "rows={rows} cols={cols} axis={axis:?} pat={name}");
            }
        }
    }

    #[test]
    fn h4_fast_refuses_i8_min_in_both_active_and_zero_padded_positions() {
        let mut rng = 0xBAD_18_0000_0128u64;
        for &(rows, cols, axis) in &[
            (16usize, 16usize, Axis::Rows),
            (16, 16, Axis::Columns),
            (128, 512, Axis::Rows),
            (128, 512, Axis::Columns),
            (256, 256, Axis::Rows),
            (256, 256, Axis::Columns),
        ] {
            let outputs = if axis == Axis::Rows { rows } else { cols };
            let eq: Vec<Fp2> = (0..outputs)
                .map(|_| Fp2::new(Fp(splitmix64(&mut rng) % P), Fp(splitmix64(&mut rng) % P)))
                .collect();
            // Leading zero prefix, active middle with zero holes, trailing zero suffix.
            let start = outputs / 4;
            let end = (outputs * 3 / 4).saturating_sub(3).max(start + 1);
            let coeffs: Vec<u64> = (0..outputs)
                .map(|j| if j >= start && j < end && j != start + 2 { 17 } else { 0 })
                .collect();
            let base: Vec<i8> = (0..rows * cols)
                .map(|_| ((splitmix64(&mut rng) % 255) as i16 - 127) as i8)
                .collect();

            // Inject i8::MIN into leading zero-padded, active start, active hole,
            // active scalar tail, trailing zero-padded, and final byte.
            let probe_outputs = [
                0usize,
                start.saturating_sub(1),
                start,
                (start + 2).min(outputs - 1),
                end - 1,
                end.min(outputs - 1),
                outputs - 1,
            ];
            let inner = if axis == Axis::Rows { cols } else { rows };
            let probe_inners = [0usize, 15.min(inner - 1), inner / 2, inner - 1];
            for &po in &probe_outputs {
                for &pi in &probe_inners {
                    let idx = if axis == Axis::Rows { po * cols + pi } else { pi * cols + po };
                    let mut bad = base.clone();
                    bad[idx] = i8::MIN;
                    let r0 = fold_with_mode(&bad, rows, cols, axis, &coeffs, &eq, false);
                    let r1 = fold_with_mode(&bad, rows, cols, axis, &coeffs, &eq, true);
                    assert_eq!(r0, Err(FOLD_ERR.into()), "baseline must refuse ({rows}x{cols} {axis:?} idx={idx})");
                    assert_eq!(r1, Err(FOLD_ERR.into()), "fast must refuse ({rows}x{cols} {axis:?} idx={idx})");
                }
            }

            // Also verify all-zero coefficients still refuse i8::MIN.
            let zeros = vec![0u64; outputs];
            let mut bad = base.clone();
            bad[rows * cols - 1] = i8::MIN;
            assert_eq!(fold_with_mode(&bad, rows, cols, axis, &zeros, &eq, false), Err(FOLD_ERR.into()));
            assert_eq!(fold_with_mode(&bad, rows, cols, axis, &zeros, &eq, true), Err(FOLD_ERR.into()));
        }
    }

    #[test]
    fn w2_tiled_4row_neon_matches_baseline_and_refuses_i8_min() {
        let _lock = crate::zk::host_fast_test_lock();
        struct Reset {
            prev_hf: Option<bool>,
            prev_w2: Option<bool>,
        }
        impl Drop for Reset {
            fn drop(&mut self) {
                crate::zk::set_host_fast_for_test(self.prev_hf);
                crate::zk::set_host_fast_w2_for_test(self.prev_w2);
            }
        }
        let _guard = Reset {
            prev_hf: crate::zk::set_host_fast_for_test(Some(false)),
            prev_w2: crate::zk::set_host_fast_w2_for_test(Some(false)),
        };

        let mut rng = 0x2026_1123_4426_0001u64;
        let extreme_eq = [
            Fp2::new(Fp(0x7FFF_FFFF_7FFF_FFFF), Fp(0x7FFF_FFFF_8000_0000)),
            Fp2::new(Fp(P - 1), Fp(1)),
            Fp2::new(Fp(0x8000_0000), Fp(0x7FFF_FFFF)),
            Fp2::new(Fp(0), Fp(P - 0x8000_0001)),
        ];

        // Shapes spanning tiny, non-multiple-of-4 rows, multi-COL_TILE (> 1024),
        // non-multiple-of-16 active spans, and parallel chunk thresholds.
        for &(rows, cols, axis) in &[
            (1usize, 1usize, Axis::Rows),
            (1, 1, Axis::Columns),
            (2, 16, Axis::Rows),
            (2, 16, Axis::Columns),
            (4, 32, Axis::Rows),
            (4, 32, Axis::Columns),
            (8, 2048, Axis::Columns),
            (16, 2048, Axis::Columns),
            (32, 2048, Axis::Columns),
            (64, 128, Axis::Rows),
            (256, 512, Axis::Rows),
            (256, 512, Axis::Columns),
        ] {
            let outputs = if axis == Axis::Rows { rows } else { cols };
            let mat: Vec<i8> = (0..rows * cols)
                .map(|_| ((splitmix64(&mut rng) % 255) as i16 - 127) as i8)
                .collect();
            let eq: Vec<Fp2> = (0..outputs)
                .map(|j| {
                    if j < extreme_eq.len() {
                        extreme_eq[j]
                    } else {
                        Fp2::new(Fp(splitmix64(&mut rng) % P), Fp(splitmix64(&mut rng) % P))
                    }
                })
                .collect();
            let start = outputs / 5;
            let end = (outputs * 4 / 5).saturating_sub(3).max(start + 1).min(outputs);
            let coeffs_span: Vec<u64> = (0..outputs)
                .map(|j| if j >= start && j < end && j != start + 2 { ((j * 13) % 16384 + 1) as u64 } else { 0 })
                .collect();
            let coeffs_all: Vec<u64> = (0..outputs).map(|j| (j as u64 % 16384) + 1).collect();
            let coeffs_zero = vec![0u64; outputs];

            for (tag, coeffs) in [("span", &coeffs_span), ("all", &coeffs_all), ("zero", &coeffs_zero)] {
                let want = fold_with_mode(&mat, rows, cols, axis, coeffs, &eq, false).unwrap();

                // hw0 parity (strict zero-hit check lives in fresh-process `host_fast_w2_all_call_sites_byte_identical`)
                crate::zk::set_host_fast_w2_for_test(Some(false));
                let got0 = fold_checked(&mat, rows, cols, axis, coeffs, &eq, false, true).unwrap();
                assert_eq!(got0, want, "hw0 mismatch {rows}x{cols} {axis:?} {tag}");

                // prove_side = false (verifier) MUST match baseline and never take W2/H4 path even when both switches are ON
                crate::zk::set_host_fast_for_test(Some(true));
                crate::zk::set_host_fast_w2_for_test(Some(true));
                let got_verify = fold_checked(&mat, rows, cols, axis, coeffs, &eq, true, false).unwrap();
                assert_eq!(got_verify, want, "verifier prove_side=false mismatch {rows}x{cols} {axis:?} {tag}");
                crate::zk::set_host_fast_for_test(Some(false));

                // hw1 with registry_checked = false AND true must both match baseline bit-for-bit
                crate::zk::set_host_fast_w2_for_test(Some(true));
                for &reg_chk in &[false, true] {
                    let hb1 = crate::zk::host_fast_w2_hits_for_test();
                    let got1 = fold_checked(&mat, rows, cols, axis, coeffs, &eq, reg_chk, true).unwrap();
                    let ha1 = crate::zk::host_fast_w2_hits_for_test();
                    assert_eq!(got1, want, "hw1 reg_chk={reg_chk} mismatch {rows}x{cols} {axis:?} {tag}");
                    assert!(
                        ha1[crate::zk::HF_W2_FOLD_TILED] > hb1[crate::zk::HF_W2_FOLD_TILED],
                        "hw1 must bump HF_W2_FOLD_TILED"
                    );
                }
            }

            // Unchecked (registry_checked = false) MUST refuse i8::MIN in active AND zero-padded positions!
            crate::zk::set_host_fast_w2_for_test(Some(true));
            let inner = if axis == Axis::Rows { cols } else { rows };
            let probe_outputs = [0usize, start, (start + 2).min(outputs - 1), end - 1, outputs - 1];
            let probe_inners = [0usize, 15.min(inner - 1), inner / 2, inner - 1];
            for &po in &probe_outputs {
                for &pi in &probe_inners {
                    let idx = if axis == Axis::Rows { po * cols + pi } else { pi * cols + po };
                    let mut bad = mat.clone();
                    bad[idx] = i8::MIN;
                    assert_eq!(
                        fold_checked(&bad, rows, cols, axis, &coeffs_span, &eq, false, true),
                        Err(FOLD_ERR.into()),
                        "hw1 unchecked must refuse i8::MIN at ({rows}x{cols} {axis:?} po={po} pi={pi})"
                    );
                }
            }
            // Active-span i8::MIN is still refused even when registry_checked = true (NEON vminq_s8 guard)
            let active_idx = if axis == Axis::Rows { start * cols } else { start };
            let mut bad_active = mat.clone();
            bad_active[active_idx] = i8::MIN;
            assert_eq!(
                fold_checked(&bad_active, rows, cols, axis, &coeffs_span, &eq, true, true),
                Err(FOLD_ERR.into()),
                "hw1 active i8::MIN must be refused even when registry_checked=true"
            );
            // All-zero weights with unchecked MUST still refuse i8::MIN
            let mut bad_z = mat.clone();
            bad_z[rows * cols - 1] = i8::MIN;
            assert_eq!(
                fold_checked(&bad_z, rows, cols, axis, &coeffs_zero, &eq, false, true),
                Err(FOLD_ERR.into()),
                "hw1 zero-weights unchecked must refuse i8::MIN"
            );
        }
    }
}

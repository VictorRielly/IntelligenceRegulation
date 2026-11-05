//! The exact-integer witness of the private block, recomputed from the private
//! input with the semantics of `private-block-kernel` /
//! `causal_oracle::FixedCausalOracle`: no clamping, a value outside its class
//! is a refusal naming a static site, and the refusal ORDER is the kernel's.
//!
//! `build` fills the WHOLE BLOCK: norm_a, QKV, RoPE, causal softmax, PV, O,
//! residual 1, then `norm_m`, the SiLU feed-forward (gate, activation lookup,
//! up, product, down) and residual 2, on the planes of `Layout::new` (T1
//! sections C.1-C.2, T2 sections A-B).
//!
//! **STEP S6: shape-driven.** Every loop bound, every stride and the three
//! calibration WINDOWS (`norm_wrho`, `f_e`, `wrho_s`) come from a
//! [`Shape`](super::shape::Shape); `build` is `build_shaped` at
//! `Shape::toy()` and nothing else. A plane of a padded domain is laid out at
//! the domain's PADDED stride — `(t, i)` at `t * d_pad + i`, `(t, kv, i')` at
//! `t * kv_width + kv * head_dim + i'`, `(h, t, j)` at
//! `(h * t_pad + t) * t_pad + j` — and only TRUE coordinates are written, in
//! the same relative order the toy visits them, so the toy (where every
//! padded stride equals its true width) is bit for bit what it always was.
//!
//! **The pad is left at zero and nothing here claims that is enough.** What
//! a pad position must contain, and which planes are exempt, is the pad rule
//! of memo section 3.7a — step S9, not this one. Until it lands, a padded
//! shape has an unconstrained pad and cannot be proved.
//!
//! **GROUPED-QUERY ATTENTION (step S7).** Query head `h` reads key-value head
//! `h / group` with `group = q_heads / kv_heads`, and the key rotation runs
//! over `kv_heads` heads. Three sites carry it: the `KR` rotation, the score
//! accumulator and the PV accumulator. At the toy there is ONE key-value
//! head, so the group is every query head, the offset is always 0 and the
//! rotation runs over one head — bit for bit what the ungrouped code did.
//!
//! The returned planes are SECRET. Nothing here prints, hashes or serializes
//! them; a refusal carries a site name only (the refusal itself still depends
//! on the input, exactly as the kernel's does).

use super::layout::*;
use super::shape::{Shape, LIMBS_ISQRT};
use super::{AttentionPublic, FeedForwardPublic};

// R13 execution is tested independently before any proof profile activates it.
#[path = "witness_accuracy.rs"]
mod accuracy;
/// H124c: the builder's sequential reference paths, for the equality tests
#[cfg(test)]
pub(crate) use accuracy::with_sequential;

/// R13 component construction. The shared prover/verifier validation still
/// controls whether a profile can produce or accept a proof.
pub(crate) fn build_accuracy(sh:&Shape,public:&AttentionPublic,ff:&FeedForwardPublic,
    data:&super::accuracy_public::AccuracyPublic,input:&[i16])->Result<Witness,String> {
    sh.check_constructed()?;
    let geometry=super::accuracy_public::Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    data.check_for_registry(sh.accuracy_registry(),geometry,sh.accuracy_base(),sh.accuracy_stack())?;
    if data.folds().gate.shift!=sh.accuracy_gate_shift {
        return Err("R13 witness: folded gate shift differs from the shape".into());
    }
    accuracy::assign(sh,public,data,accuracy::build(sh,public,ff,data,input)?)
}

/// The block-aware component builder validates the complete public
/// context independently of proof availability.
pub(crate) fn build_for_block(sh:&Shape,blk:&super::BlockPublic,input:&[i16])->Result<Witness,String> {
    if sh.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
        // Component construction is valid independently of proof availability,
        // including when Rayon builds it off the invoking test's thread.
        blk.check_accuracy_for_shape(sh)?;
        build_accuracy(sh,blk.attention(),blk.feed_forward(),blk.accuracy().expect("validated public data"),input)
    } else {
        blk.check_for_shape(sh)?;
        build_shaped(sh,blk.attention(),blk.feed_forward(),input)
    }
}

#[derive(Clone)]
pub(crate) struct Witness {
    /// one vector per A plane, `N_A` of them, indexed by the `A_*` ids. A
    /// lookup histogram (which the prover derives, not this builder) is an
    /// EMPTY vector, never a zero plane.
    pub planes: Vec<Vec<i64>>,
    pub(crate) output_plane: usize,
}

impl Witness {
    /// The block's output plane `xres2` (secret): what `SC_IO_OUT` binds and
    /// what an honest endpoint owner commits.
    ///
    /// The builder records the profile-derived output plane; norm limb
    /// changes must never silently move the endpoint onto another role.
    pub(crate) fn output(&self) -> Result<Vec<i16>, String> {
        self.planes.get(self.output_plane).ok_or("private block: output plane is absent")?.iter().map(|v| i16::try_from(*v).map_err(|_| "fixed oracle range refusal: residual 2".to_string())).collect()
    }
}

// NATIVE R9, TEST BUILDS ONLY: which dictionary mutation the witness
// builder applies (0 = none)
#[cfg(test)]
thread_local! {
    static DD_CHEAT: std::cell::Cell<u8> = const { std::cell::Cell::new(0) };
}

/// TEST ONLY. 1 = CHECK.md D-3 (an e = 0 PADDING slot, the last of row
/// (0, 0), holds the wrong tuple (Sum, 0, 1) with one count moved onto it
/// from the honest e = 0 slot, and the masked entry (0, 0, 1) claims P = 1);
/// 2 = D-4 (an entry of row (0, ta) presents row (0, tb)'s quotient for the
/// same e, one count moved between the two rows' slots); 3 = an entry's P off
/// by one with NO count moved (caught only by the value-0 sum claim)
#[cfg(test)]
pub(crate) fn set_dd_cheat(v: u8) {
    DD_CHEAT.with(|c| c.set(v));
}

#[cfg(test)]
#[allow(clippy::too_many_arguments)]
fn dd_cheat(shape: &Shape, g: &Geom, ids: &Ids, pl: &mut [Vec<i64>], oacc: &mut [i64], v8: &[i64], ecol: &[i64]) -> Result<(), String> {
    let mode = DD_CHEAT.with(|c| c.get());
    if mode == 0 {
        return Ok(());
    }
    let cap = shape.dd_cap;
    let (p, e, sum) = (ids.at(A_P), ids.at(A_E), ids.at(A_SUM));
    let hs = g.slot(0);
    let kv = 0usize;
    let dix = |t: usize, k: usize| (hs * g.t_pad + t) * cap + k;
    let mut rows: Vec<usize> = Vec::new();
    match mode {
        1 => {
            // the masked entry (t 0, j 1) looks up e = 0; the last slot of
            // its row is an e = 0 padding slot (n_col < cap)
            pl[p][g.six(hs, 0, 1)] = 1;
            pl[ids.pdict()][dix(0, cap - 1)] = 1;
            pl[ids.pl(0)][dix(0, cap - 1)] = 1;
            for kk in 1..g.lp {
                pl[ids.pl(kk)][dix(0, cap - 1)] = 0;
            }
            pl[ids.mdd()][dix(0, 0)] -= 1;
            pl[ids.mdd()][dix(0, cap - 1)] += 1;
            rows.push(0);
        }
        2 | 3 => {
            // the first pair of rows with different Sums, and an on-support
            // entry of row ta whose e's quotient differs between them
            let mut found = None;
            'outer: for ta in 1..g.t {
                for tb in 0..g.t {
                    if tb == ta || pl[sum][g.htix(hs, ta)] == pl[sum][g.htix(hs, tb)] {
                        continue;
                    }
                    for j in 0..=ta.min(tb) {
                        let ev = pl[e][g.six(hs, ta, j)];
                        if ev == 0 {
                            continue;
                        }
                        let qb = (ev << F_P) / pl[sum][g.htix(hs, tb)];
                        if qb != pl[p][g.six(hs, ta, j)] {
                            found = Some((ta, tb, j, ev, qb));
                            break 'outer;
                        }
                    }
                }
            }
            let (ta, tb, j, ev, qb) = found.ok_or("dd cheat: no two rows with different quotients")?;
            if mode == 2 {
                // the count sits on the FIRST slot holding e, in both rows
                let k = ecol.iter().position(|v| *v == ev).ok_or("dd cheat: e is not in the column")?;
                pl[p][g.six(hs, ta, j)] = qb;
                pl[ids.mdd()][dix(ta, k)] -= 1;
                pl[ids.mdd()][dix(tb, k)] += 1;
            } else {
                pl[p][g.six(hs, ta, j)] += 1;
            }
            rows.push(ta);
        }
        _ => return Err("dd cheat: unknown mode".into()),
    }
    for t in rows {
        for i in 0..g.dh {
            oacc[g.qix(t, hs, i)] = (0..g.t_pad).map(|j| pl[p][g.six(hs, t, j)] * v8[g.kvix(j, kv, i)]).sum();
        }
    }
    Ok(())
}

/// floor integer square root (integer only)
pub(crate) fn isqrt(v: u64) -> u64 {
    let mut rem = v;
    let mut res = 0u64;
    let mut bit = 1u64 << 62;
    while bit > v {
        bit >>= 2;
    }
    while bit != 0 {
        if rem >= res + bit {
            rem -= res + bit;
            res = (res >> 1) + bit;
        } else {
            res >>= 1;
        }
        bit >>= 2;
    }
    res
}

/// The rounding bias `2^(sh-1)`, and ZERO at `sh = 0`.
///
/// Defect D-2 of the code review: written inline as `1i64 << (sh - 1)` with
/// `sh: u32`, the subtraction underflows to `u32::MAX` at `sh = 0` and the
/// shift then panics in debug and is masked in release. No call reaches
/// `sh = 0` today — the up matmul, the one site with `SH_U = 0`, deliberately
/// bypasses `quantize` (T2 section A.4) — but `SH_U` is a calibration constant,
/// so the trap is one constant away. At `sh = 0` the kernel's own rule is exact
/// up-scaling by `2^0` (`private-block-kernel::requant`, the `sh <= 0` branch):
/// the identity map with nothing to round and no remainder, which is what a
/// zero bias gives here.
pub(super) fn half(sh: u32) -> i64 {
    if sh == 0 {
        0
    } else {
        1i64 << (sh - 1)
    }
}

/// round to nearest, ties toward +inf: (y, remainder in [-2^(s-1), 2^(s-1)));
/// at `sh = 0` the identity `(acc, 0)`
pub(super) fn requant(acc: i64, sh: u32) -> (i64, i64) {
    let y = (acc + half(sh)) >> sh;
    (y, acc - (y << sh))
}

fn range(site: &'static str) -> String {
    format!("fixed oracle range refusal: {site}")
}

fn limbs(v: i64, count: usize) -> Vec<i64> {
    (0..count).map(|k| if k + 1 == count { v >> (8 * k) } else { (v >> (8 * k)) & 255 }).collect()
}

// ---------------------------------------------------------------- geometry

/// The strides and windows one shape gives the witness. Every plane is a
/// vector of the PADDED domain's length; a true coordinate lands at the
/// padded stride and every other position stays zero.
pub(super) struct Geom<'a> {
    s: &'a Shape,
    /// true extents
    t: usize,
    d: usize,
    f: usize,
    hq: usize,
    hkv: usize,
    dh: usize,
    half: usize,
    /// padded strides
    t_pad: usize,
    d_pad: usize,
    /// NATIVE R12 (F2): the padded QUERY width `h_pad * head_dim`, the row
    /// stride of `Dom::Q` (equal to `d_pad` at every profile before R12)
    q_pad: usize,
    f_pad: usize,
    h_pad: usize,
    kvw: usize,
    group: usize,
    /// byte-limb counts of the two integer windows
    ln: usize,
    ls: usize,
    lp: usize,
}

impl<'a> Geom<'a> {
    pub(super) fn new(s: &'a Shape) -> Geom<'a> {
        Geom {
            s,
            t: s.tokens,
            d: s.width,
            f: s.hidden,
            hq: s.q_heads,
            hkv: s.kv_heads,
            dh: s.head_dim,
            half: s.head_dim / 2,
            t_pad: s.t_pad,
            d_pad: s.d_pad,
            q_pad: s.q_pad(),
            f_pad: s.f_pad,
            h_pad: s.h_pad,
            kvw: s.kv_heads * s.head_dim,
            group: s.q_heads / s.kv_heads,
            ln: s.limbs_norm(),
            ls: s.limbs_sigma_s(),
            lp: s.limbs_p(),
        }
    }

    pub(super) fn len(&self, dom: Dom) -> usize {
        self.s.size(dom)
    }
    /// `(t, i)` of `Dom::D` (NATIVE R12: `Dom::Q` has its own row stride,
    /// `q_pad`, read with the head axis PERMUTED — see [`Geom::qix`])
    fn dix(&self, t: usize, i: usize) -> usize {
        t * self.d_pad + i
    }
    /// **The head permutation (correction C-1).** The padded head slot logical
    /// query head `h` occupies: the key-value group owns a contiguous block of
    /// slots and each group's padding falls at the END of its own block, so
    /// the padded slots interleave (`{3, 7}` at the rung) instead of forming a
    /// tail. At the toy this is the identity and no byte moves.
    pub(super) fn slot(&self, h: usize) -> usize {
        self.s.head_slot(h)
    }
    /// `(t, slot, i')` of `Dom::Q`
    fn qix(&self, t: usize, sl: usize, i: usize) -> usize {
        t * self.q_pad + sl * self.dh + i
    }
    /// `(t, kv, i')` of `Dom::Kv`
    fn kvix(&self, t: usize, kv: usize, i: usize) -> usize {
        t * self.kvw + kv * self.dh + i
    }
    /// `(h, t, j)` of `Dom::S`
    fn six(&self, h: usize, t: usize, j: usize) -> usize {
        (h * self.t_pad + t) * self.t_pad + j
    }
    /// `(t, j)` of `Dom::F`
    fn fix(&self, t: usize, j: usize) -> usize {
        t * self.f_pad + j
    }
    /// `(h, t)` of `Dom::Ht`
    fn htix(&self, h: usize, t: usize) -> usize {
        h * self.t_pad + t
    }
    /// limb sub-plane `k` of `Dom::L`, position `t`
    fn lix(&self, k: usize, t: usize) -> usize {
        k * self.t_pad + t
    }
    /// The true positions of a domain, in the order the toy visits them —
    /// which is also the order the reference kernel lays its dense buffers
    /// out in, so this doubles as the kernel-index-to-plane-index map the
    /// parity test needs.
    pub(super) fn support(&self, dom: Dom) -> Vec<usize> {
        let mut v = Vec::with_capacity(self.s.true_size(dom));
        match dom {
            Dom::D => {
                for t in 0..self.t {
                    for i in 0..self.d {
                        v.push(self.dix(t, i));
                    }
                }
            }
            // `Dom::Q` (row stride `q_pad`; `== d_pad` before R12) is NOT
            // `Dom::D`'s support (§3.7a note 1): `D` pads the top of each token's row,
            // `Q` pads one head slot per key-value group. The order is
            // `(t, h, i')` with `h` the LOGICAL head, which is the order the
            // reference kernel lays its `q8` / `o8` buffers out in.
            Dom::Q => {
                for t in 0..self.t {
                    for h in 0..self.hq {
                        for i in 0..self.dh {
                            v.push(self.qix(t, self.slot(h), i));
                        }
                    }
                }
            }
            Dom::Kv => {
                for t in 0..self.t {
                    for kv in 0..self.hkv {
                        for i in 0..self.dh {
                            v.push(self.kvix(t, kv, i));
                        }
                    }
                }
            }
            Dom::S => {
                for h in 0..self.hq {
                    for t in 0..self.t {
                        for j in 0..self.t {
                            v.push(self.six(self.slot(h), t, j));
                        }
                    }
                }
            }
            Dom::F => {
                for t in 0..self.t {
                    for j in 0..self.f {
                        v.push(self.fix(t, j));
                    }
                }
            }
            Dom::T => v.extend(0..self.t),
            Dom::Ht => {
                for h in 0..self.hq {
                    for t in 0..self.t {
                        v.push(self.htix(self.slot(h), t));
                    }
                }
            }
            Dom::L => {
                for k in 0..3 * LIMBS_ISQRT {
                    for t in 0..self.t {
                        v.push(self.lix(k, t));
                    }
                }
            }
            Dom::Tab => v.extend(0..U8_LEN),
            // NATIVE R9: a DD profile's dictionary is unpadded
            // (`Shape::check_dd_geometry`): every slot of every row is support
            Dom::Dd => v.extend(0..self.s.size(Dom::Dd)),
        }
        v
    }
}

/// Requantize the true positions of `acc` into a class, leaving every pad at
/// zero. Returns `(values, biased remainder limb r + 2^(s-1))`, both laid out
/// on the destination domain.
fn quantize(acc: &[i64], sup: &[usize], sh: u32, lo: i64, hi: i64, site: &'static str) -> Result<(Vec<i64>, Vec<i64>), String> {
    let mut y = vec![0i64; acc.len()];
    let mut r = vec![0i64; acc.len()];
    for &k in sup {
        let (q, rem) = requant(acc[k], sh);
        if !(lo..=hi).contains(&q) {
            return Err(range(site));
        }
        y[k] = q;
        r[k] = rem + half(sh);
    }
    Ok((y, r))
}

// ROUND 3 (R3-1, 2026-10-17): the matrix products are PARALLEL (rayon, over
// chunks of each output row) and cache-friendly. They are EXACT integer sums,
// so neither the order nor the split of the accumulation can change a value:
// every plane is bit-identical to the sequential form (`matmul_reference`,
// kept for the equality test). The `x` words of every call site are inside
// int16 (`y`, `o8`, `nm` are int8, `h16` int16), so one product `x w` fits an
// i32 and is widened to i64 before it is accumulated; a word outside
// `|x| < 2^23` sends the call to the i64 path, so the result is exact for any
// input.

/// the output-chunk length the parallel products split a row into: a
/// power-of-two divisor of the row stride, so no chunk straddles two rows
fn out_chunk(os: usize, want: usize) -> usize {
    let mut c = want.min(os).max(1);
    while c > 1 && os % c != 0 {
        c /= 2;
    }
    c
}

/// the `x` words as i32 when every product `x w` (|w| <= 128) fits an i32
fn narrow(x: &[i64]) -> Option<Vec<i32>> {
    if x.iter().all(|v| v.unsigned_abs() < 1 << 23) {
        Some(x.iter().map(|v| *v as i32).collect())
    } else {
        None
    }
}

/// H124: the `x` words as i16 when every one fits (|x| < 2^15). Then every
/// product `x w` (|w| <= 128) has |x w| <= 2^22, so a block of [`I16_BLOCK`]
/// products sums exactly in an i32 (|sum| <= 2^30), which the compiler turns
/// into NEON widening multiply-accumulates. The result is the same integer.
fn narrow16(x: &[i64]) -> Option<Vec<i16>> {
    if x.iter().all(|v| v.unsigned_abs() < 1 << 15) {
        Some(x.iter().map(|v| *v as i16).collect())
    } else {
        None
    }
}

/// products summed exactly in i32 per block before widening (see [`narrow16`])
const I16_BLOCK: usize = 256;

/// `sum_i x[i] * w[i]` for i16 `x`, exact: i32 partial sums over blocks of
/// [`I16_BLOCK`], widened to i64 between blocks
#[inline]
fn dot16(x: &[i16], w: &[i8]) -> i64 {
    x.chunks(I16_BLOCK)
        .zip(w.chunks(I16_BLOCK))
        .map(|(xc, wc)| i64::from(xc.iter().zip(wc).map(|(a, b)| i32::from(*a) * i32::from(*b)).sum::<i32>()))
        .sum()
}

/// H124 step 2: the i16 products TILED by output columns, so each weight row is read
/// once for all `t_rows` tokens instead of once per token (the untiled loops re-read
/// the whole matrix 128 times per block and were memory-bound). Each task owns a
/// block of output columns for every token; partial sums are i32 over blocks of
/// [`I16_BLOCK`] input indices (each |sum| <= 2^30), widened to i64 between blocks.
/// Exact integer sums, so the plane equals the untiled one entry for entry.
/// `in_out`: `w` stored (input, output), else (output, input).
#[allow(clippy::too_many_arguments)]
fn tiled16(t_rows: usize, x16: &[i16], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize, in_out: bool) -> Vec<i64> {
    use rayon::prelude::*;
    let threads = rayon::current_num_threads().max(1);
    let jb = (outer / (4 * threads)).clamp(16, 256) / 16 * 16;
    let blocks: Vec<usize> = (0..outer).step_by(jb).collect();
    let parts: Vec<(usize, usize, Vec<i64>)> = blocks
        .par_iter()
        .map(|&j0| {
            let jn = jb.min(outer - j0);
            let mut acc = vec![0i64; t_rows * jn];
            if in_out {
                let mut acc32 = vec![0i32; t_rows * jn];
                for i0 in (0..inner).step_by(I16_BLOCK) {
                    for i in i0..(i0 + I16_BLOCK).min(inner) {
                        let wr = &w[i * outer + j0..i * outer + j0 + jn];
                        for t in 0..t_rows {
                            let xv = i32::from(x16[t * xs + i]);
                            if xv != 0 {
                                for (a, wv) in acc32[t * jn..(t + 1) * jn].iter_mut().zip(wr) {
                                    *a += xv * i32::from(*wv);
                                }
                            }
                        }
                    }
                    for (a, a32) in acc.iter_mut().zip(acc32.iter_mut()) {
                        *a += i64::from(*a32);
                        *a32 = 0;
                    }
                }
            } else {
                for dj in 0..jn {
                    let wr = &w[(j0 + dj) * inner..(j0 + dj + 1) * inner];
                    for t in 0..t_rows {
                        acc[t * jn + dj] = dot16(&x16[t * xs..t * xs + inner], wr);
                    }
                }
            }
            (j0, jn, acc)
        })
        .collect();
    let mut out = vec![0i64; out_len];
    for (j0, jn, acc) in parts {
        for t in 0..t_rows {
            out[t * os + j0..t * os + j0 + jn].copy_from_slice(&acc[t * jn..(t + 1) * jn]);
        }
    }
    out
}

// **A4 (2026-11-05): the weight products on the Metal GPU, exactly.** Under
// `gpu::enabled()` (a gpu-metal build with HL_GPU=1), a product of at least
// `HL_GPU_WITNESS_MIN_MACS` multiply-adds (default [`DEVICE_MIN_MACS`]) whose
// activations fit i16 runs on the device (`gpu::witness_product`: exact integer
// arithmetic there too, with its bounds proved in `gpu/metal.rs`), so every word
// is the integer the CPU path computes. The CPU path below stays the reference and
// the default; `HL_GPU_WITNESS=0` keeps every product on it. A device failure is
// a decline (`gpu::declined`: the CPU path, or a panic under HL_GPU_REQUIRED=1).
// The products never refuse; every refusal is still the CPU builder's own.

/// below this many multiply-adds a product stays on the CPU (where it costs less
/// than a millisecond); every 8B product is above it
const DEVICE_MIN_MACS: usize = 1 << 28;

#[cfg(test)]
thread_local! {
    /// tests: `Some(true)` sends this thread's products to the device at any size
    /// and whatever `HL_GPU` says; `Some(false)` keeps them on the CPU
    static DEVICE: std::cell::Cell<Option<bool>> = const { std::cell::Cell::new(None) };
    /// tests: how many products this thread has had made on the device
    static DEVICE_MADE: std::cell::Cell<usize> = const { std::cell::Cell::new(0) };
}

/// run `f` with this thread's weight products forced onto the device (`true`) or
/// onto the CPU (`false`)
#[cfg(test)]
pub(crate) fn with_device_products<R>(on: bool, f: impl FnOnce() -> R) -> R {
    let before = DEVICE.with(|d| d.replace(Some(on)));
    let r = f();
    DEVICE.with(|d| d.set(before));
    r
}

/// tests: the number of products made on the device by this thread so far
#[cfg(test)]
pub(crate) fn device_products_made() -> usize {
    DEVICE_MADE.with(|c| c.get())
}

fn device_wanted(macs: usize) -> bool {
    #[cfg(test)]
    if let Some(on) = DEVICE.with(|d| d.get()) {
        return on;
    }
    if std::env::var("HL_GPU_WITNESS").map(|v| v == "0").unwrap_or(false) {
        return false;
    }
    let min = std::env::var("HL_GPU_WITNESS_MIN_MACS").ok().and_then(|v| v.parse().ok()).unwrap_or(DEVICE_MIN_MACS);
    macs >= min && crate::gpu::enabled()
}

/// the product on the device, or `None` for the CPU path
#[allow(clippy::too_many_arguments)]
fn on_device(t_rows: usize, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize, in_out: bool) -> Option<Vec<i64>> {
    if !device_wanted(t_rows.saturating_mul(inner).saturating_mul(outer)) {
        return None;
    }
    match crate::gpu::witness_product(t_rows, x, xs, w, inner, outer, os, out_len, in_out) {
        Ok(out) => {
            #[cfg(test)]
            if out.is_some() {
                DEVICE_MADE.with(|c| c.set(c.get() + 1));
            }
            out
        }
        Err(e) => {
            crate::gpu::declined("[A4] witness weight product", &e);
            None
        }
    }
}

/// `out[t, j] = sum_i x[t, i] * w[j, i]`, `w` stored (output, input), reading
/// `x` at stride `xs` and writing at stride `os` on a plane of `out_len`.
fn matmul(g: &Geom, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize) -> Vec<i64> {
    use rayon::prelude::*;
    if let Some(out) = on_device(g.t, x, xs, w, inner, outer, os, out_len, false) {
        return out;
    }
    if let Some(x16) = narrow16(x) {
        return tiled16(g.t, &x16, xs, w, inner, outer, os, out_len, false);
    }
    let mut out = vec![0i64; out_len];
    let c = out_chunk(os, 256);
    let x32 = narrow(x);
    out.par_chunks_mut(c).enumerate().for_each(|(ci, chunk)| {
        let start = ci * c;
        let (t, j0) = (start / os, start % os);
        if t >= g.t || j0 >= outer {
            return;
        }
        let jn = (outer - j0).min(chunk.len());
        for (dj, o) in chunk[..jn].iter_mut().enumerate() {
            let wr = &w[(j0 + dj) * inner..(j0 + dj + 1) * inner];
            *o = match &x32 {
                Some(x32) => x32[t * xs..t * xs + inner].iter().zip(wr).map(|(a, b)| i64::from(a * i32::from(*b))).sum(),
                None => x[t * xs..t * xs + inner].iter().zip(wr).map(|(a, b)| a * i64::from(*b)).sum(),
            };
        }
    });
    out
}

/// `out[t, j] = sum_i x[t, i] * w[i, j]`, `w` stored (input, output) — the
/// feed-forward orientation, the kernel's `matmul_in_out`. ROUND 3: the
/// loop order is (row, i, j) so each weight row is read contiguously (the
/// sequential form walked `w` at stride `outer`).
fn matmul_in_out(g: &Geom, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize) -> Vec<i64> {
    use rayon::prelude::*;
    if let Some(out) = on_device(g.t, x, xs, w, inner, outer, os, out_len, true) {
        return out;
    }
    if let Some(x16) = narrow16(x) {
        return tiled16(g.t, &x16, xs, w, inner, outer, os, out_len, true);
    }
    let mut out = vec![0i64; out_len];
    let c = out_chunk(os, 512);
    let x32 = narrow(x);
    out.par_chunks_mut(c).enumerate().for_each(|(ci, chunk)| {
        let start = ci * c;
        let (t, j0) = (start / os, start % os);
        if t >= g.t || j0 >= outer {
            return;
        }
        let jn = (outer - j0).min(chunk.len());
        let acc = &mut chunk[..jn];
        for i in 0..inner {
            let wr = &w[i * outer + j0..i * outer + j0 + jn];
            match &x32 {
                Some(x32) => {
                    let xv = x32[t * xs + i];
                    if xv != 0 {
                        for (a, wv) in acc.iter_mut().zip(wr) {
                            *a += i64::from(xv * i32::from(*wv));
                        }
                    }
                }
                None => {
                    let xv = x[t * xs + i];
                    if xv != 0 {
                        for (a, wv) in acc.iter_mut().zip(wr) {
                            *a += xv * i64::from(*wv);
                        }
                    }
                }
            }
        }
    });
    out
}

/// the SEQUENTIAL products of the round-2 builder, verbatim: the reference
/// the parallel ones are tested equal to (`witness_speed_tests`)
#[cfg(test)]
pub(super) fn matmul_reference(t_true: usize, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize, in_out: bool) -> Vec<i64> {
    let mut out = vec![0i64; out_len];
    for t in 0..t_true {
        for j in 0..outer {
            out[t * os + j] = if in_out {
                (0..inner).map(|i| x[t * xs + i] * i64::from(w[i * outer + j])).sum()
            } else {
                (0..inner).map(|i| x[t * xs + i] * i64::from(w[j * inner + i])).sum()
            };
        }
    }
    out
}

/// the parallel products at a shape, for the equality test
#[cfg(test)]
pub(super) fn matmul_parallel(sh: &Shape, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize, in_out: bool) -> Vec<i64> {
    let g = Geom::new(sh);
    if in_out {
        matmul_in_out(&g, x, xs, w, inner, outer, os, out_len)
    } else {
        matmul(&g, x, xs, w, inner, outer, os, out_len)
    }
}

/// half-split RoPE over `heads` heads per row, at stride `ws` on a plane of
/// `out_len`
fn rotate(g: &Geom, x: &[i64], heads: usize, ws: usize, out_len: usize, cos: &[i64], sin: &[i64]) -> Vec<i64> {
    let mut out = vec![0i64; out_len];
    for t in 0..g.t {
        for h in 0..heads {
            let base = t * ws + h * g.dh;
            for i in 0..g.half {
                let (c, s) = (cos[t * g.half + i], sin[t * g.half + i]);
                let (a, b) = (x[base + i], x[base + g.half + i]);
                out[base + i] = c * a - s * b;
                out[base + g.half + i] = s * a + c * b;
            }
        }
    }
    out
}

/// One RMSNorm site (round mode), planes and all: `D = isqrt(sum x^2 + Ceps)`,
/// `y = floor((2 x g Cn + D 2^tn) / (D 2^(tn+1)))`, with the isqrt witness
/// `a1 = ss - D^2`, `a2 = 2D - a1` and the byte limbs of `D`, `a1`, `a2`,
/// `rho`, `sigma`. Used for norm_a and, unchanged, for norm_m (T1 section C.1:
/// "the IDENTICAL relation, with gamma_m for gamma_a and xres1 for x_in").
struct NormPlanes {
    d: Vec<i64>,
    dsq: Vec<i64>,
    limb: Vec<i64>,
    y: Vec<i64>,
    rho: Vec<Vec<i64>>,
    sigma: Vec<Vec<i64>>,
}

/// NATIVE LANE: `tn`, `ceps` and `cn` are the SHAPE's (the frozen
/// `NORM_TN` / `NORM_CEPS` / `NORM_CN` at every registered profile); `cn` is
/// passed per site because norm_a and norm_m carry separate multipliers.
fn rms_norm(g: &Geom, x: &[i64], gamma: &[i8], norm_wrho: u32, cn: i64) -> Result<NormPlanes, String> {
    let (tn, ceps) = (g.s.norm_tn, g.s.norm_ceps);
    let wrho = 1i64 << norm_wrho;
    let dl = g.len(Dom::D);
    // the isqrt witness is proved through `LIMBS_ISQRT` byte limbs each
    let isqrt_win = 1i64 << (8 * LIMBS_ISQRT);
    let mut out = NormPlanes {
        d: vec![0i64; g.len(Dom::T)],
        dsq: vec![0i64; g.len(Dom::T)],
        limb: vec![0i64; g.len(Dom::L)],
        y: vec![0i64; dl],
        rho: vec![vec![0i64; dl]; g.ln],
        sigma: vec![vec![0i64; dl]; g.ln],
    };
    for t in 0..g.t {
        let row = &x[t * g.d_pad..t * g.d_pad + g.d];
        let ss: i64 = ceps + row.iter().map(|v| v * v).sum::<i64>();
        let d = isqrt(ss as u64) as i64;
        let a1 = ss - d * d;
        let a2 = 2 * d - a1;
        if d >= isqrt_win || !(0..isqrt_win).contains(&a1) || !(0..isqrt_win).contains(&a2) {
            return Err(range("norm denominator"));
        }
        out.d[t] = d;
        out.dsq[t] = d * d;
        for (base, v) in [(0usize, d), (LIMBS_ISQRT, a1), (2 * LIMBS_ISQRT, a2)] {
            for (k, l) in limbs(v, LIMBS_ISQRT).into_iter().enumerate() {
                out.limb[g.lix(base + k, t)] = l;
            }
        }
        let dv = d << tn;
        let den = 2 * dv;
        if den <= 0 {
            return Err(range("norm denominator"));
        }
        for i in 0..g.d {
            let num = 2 * row[i] * i64::from(gamma[i]) * cn + dv;
            let q = num.div_euclid(den);
            let rho = num.rem_euclid(den);
            let sigma = den - 1 - rho;
            if !(-127..=127).contains(&q) || rho >= wrho || sigma >= wrho {
                return Err(range("norm quotient/remainder"));
            }
            let idx = g.dix(t, i);
            out.y[idx] = q;
            for (k, l) in limbs(rho, g.ln).into_iter().enumerate() {
                out.rho[k][idx] = l;
            }
            for (k, l) in limbs(sigma, g.ln).into_iter().enumerate() {
                out.sigma[k][idx] = l;
            }
        }
    }
    Ok(out)
}

/// The whole block at the toy shape, on the planes of `Layout::new`.
pub(crate) fn build(public: &AttentionPublic, ff: &FeedForwardPublic, input: &[i16]) -> Result<Witness, String> {
    build_shaped(&Shape::toy(), public, ff, input)
}

/// **The plane table, before step S8.** The `A_*` constants of `layout.rs`
/// are the toy's literal indices, and this refused any shape whose plane LIST
/// differed. **S8 replaced it with [`Ids`], which MAPS the ids instead of
/// refusing**, so a third `sigma_s` limb (the rung's and 125M's) is now
/// expressible. `Ids::new` keeps the refusal for a list this map cannot
/// express, and `norm_limbs_are_the_pinned_count` below keeps the one
/// remaining literal honest.
///
/// **The one literal left: [`Witness::output`] reads `A_X2`**, whose id sits
/// above the norm limb groups, so it is stable only while `limbs_norm` is the
/// toy's four — which it is at the toy, the rung and 125M (`D_max` is
/// 908,065 at 125M and the window is 32 bits, four limbs). A shape with a
/// fifth norm limb is refused BY NAME here rather than silently reading the
/// wrong plane; the fix, when a shape needs it, is to carry the output
/// plane's id in the `Witness` (finding S8-F3).
fn norm_limbs_are_the_pinned_count(shape: &Shape) -> Result<(), String> {
    if shape.limbs_norm() != LN_TOY {
        return Err("private block: this shape's norm remainder needs a different number of byte limbs".into());
    }
    Ok(())
}

/// the whole block, on the planes of `Layout::new` at `shape`
pub(crate) fn build_shaped(shape: &Shape, public: &AttentionPublic, ff: &FeedForwardPublic, input: &[i16]) -> Result<Witness, String> {
    let ids = Ids::new(shape)?;
    norm_limbs_are_the_pinned_count(shape)?;
    // RULINGS CS-1 and CS-4 (ported from the 125M lane): the two halves are
    // checked against the shape they are built at, attention first, before
    // the input is read
    public.check_for_shape(shape)?;
    ff.check_for_shape(shape)?;
    let ap = |toy_id: usize| ids.at(toy_id);
    let g = Geom::new(shape);
    if input.len() != g.t * g.d {
        return Err("private block: input shape".into());
    }
    let (f_e, wrho_s) = (shape.f_e, shape.wrho_s);
    let sup_d = g.support(Dom::D);
    let sup_q = g.support(Dom::Q);
    let sup_kv = g.support(Dom::Kv);
    let sup_s = g.support(Dom::S);
    let sup_f = g.support(Dom::F);
    let mut pl: Vec<Vec<i64>> = (0..ids.n_a()).map(|q| if ids.is_multiplicity(q) { Vec::new() } else { vec![0i64; g.len(ids.dom(q))] }).collect();
    let mut x = vec![0i64; g.len(Dom::D)];
    for t in 0..g.t {
        for i in 0..g.d {
            x[g.dix(t, i)] = i64::from(input[t * g.d + i]);
        }
    }

    // ---- norm_a (round mode) ----
    let na = rms_norm(&g, &x, &public.gamma_a, shape.norm_wrho, shape.norm_cn_a)?;
    pl[ap(A_D)] = na.d;
    pl[ap(A_DSQ)] = na.dsq;
    pl[ap(A_LIMB)] = na.limb;
    pl[ap(A_Y)] = na.y;
    for (k, v) in na.rho.into_iter().enumerate() {
        pl[ids.nr(k)] = v;
    }
    for (k, v) in na.sigma.into_iter().enumerate() {
        pl[ids.ns(k)] = v;
    }
    for &idx in &sup_d {
        pl[ap(A_X)][idx] = x[idx];
        let l = limbs(x[idx] + 32768, 2);
        pl[ap(A_XL0)][idx] = l[0];
        pl[ap(A_XL1)][idx] = l[1];
    }

    // ---- QKV, RoPE ----
    let y = pl[ap(A_Y)].clone();
    let (dl, kvl, sl) = (g.len(Dom::D), g.len(Dom::Kv), g.len(Dom::S));
    // NATIVE R12 (F2): the query planes live on `Dom::Q`, of row stride
    // `q_pad` (`ql == dl` and `q_pad == d_pad` at every profile before R12)
    let ql = g.len(Dom::Q);
    // S9: the QKV weights are the PADDED, head-permuted matrices (ruling
    // P-2), so every matmul folds over the padded inner index and `Wq` writes
    // the `Dom::Q` axis in SLOT order. The padded rows and columns are zero
    // by construction check, so the accumulation is unchanged on the support.
    let (q8, rql) = quantize(&matmul(&g, &y, g.d_pad, &public.wq, g.d_pad, g.q_pad, g.q_pad, ql), &sup_q, shape.sh_qkv, -127, 127, "Q")?;
    let (k8, rkl) = quantize(&matmul(&g, &y, g.d_pad, &public.wk, g.d_pad, g.kvw, g.kvw, kvl), &sup_kv, shape.sh_qkv, -127, 127, "K")?;
    let (v8, rvl) = quantize(&matmul(&g, &y, g.d_pad, &public.wv, g.d_pad, g.kvw, g.kvw, kvl), &sup_kv, shape.sh_qkv, -127, 127, "V")?;
    // the rotation runs over every padded head SLOT; a padded slot holds
    // zeros, so it rotates to zero and the pad stays zero
    let (qr8, rqrl) = quantize(&rotate(&g, &q8, g.h_pad, g.q_pad, ql, &public.rope_cos, &public.rope_sin), &sup_q, SH_ROPE, -127, 127, "QR")?;
    // S7: the key rotation runs over the KEY-VALUE heads, not over one head
    let (kr8, rkrl) = quantize(&rotate(&g, &k8, g.hkv, g.kvw, kvl, &public.rope_cos, &public.rope_sin), &sup_kv, SH_ROPE, -127, 127, "KR")?;

    // ---- scores over ALL (h, t, j): an out-of-range masked score still refuses ----
    let mut sacc = vec![0i64; sl];
    // ROUND 3: one parallel task per padded head SLOT (each slot owns the
    // contiguous `t_pad x t_pad` block of `Dom::S`); a padding slot stays zero
    {
        use rayon::prelude::*;
        let mut head_of_slot: Vec<Option<usize>> = vec![None; g.h_pad];
        for h in 0..g.hq {
            head_of_slot[g.slot(h)] = Some(h);
        }
        let blk = g.t_pad * g.t_pad;
        sacc.par_chunks_mut(blk).enumerate().for_each(|(hs, ch)| {
            // S9: the logical head sits at its padded SLOT, and its key-value
            // head is the slot's HIGH bits (correction C-1)
            let Some(h) = head_of_slot.get(hs).copied().flatten() else { return };
            let kv = h / g.group;
            for t in 0..g.t {
                for j in 0..g.t {
                    ch[t * g.t_pad + j] = (0..g.dh).map(|i| qr8[g.qix(t, hs, i)] * kr8[g.kvix(j, kv, i)]).sum();
                }
            }
        });
    }
    let (s8, rsl) = quantize(&sacc, &sup_s, shape.sh_s, -127, 127, "score")?;

    // ---- causal softmax, PV ----
    let mut oacc = vec![0i64; ql];
    for h in 0..g.hq {
        // S7: the value mixing reads the same key-value head as the scores
        let hs = g.slot(h);
        let kv = h / g.group;
        for t in 0..g.t {
            let masked = |j: usize| if j <= t { s8[g.six(hs, t, j)] } else { MASK_SCORE };
            let mut best = i64::MIN;
            let mut arg = 0usize;
            for j in 0..g.t {
                if masked(j) > best {
                    best = masked(j);
                    arg = j;
                }
            }
            if arg > t {
                return Err("fixed oracle relation failure: causal maximum attainment".into());
            }
            pl[ap(A_MX)][g.htix(hs, t)] = best;
            pl[ap(A_ZSEL)][g.six(hs, t, arg)] = 1;
            let mut total = 0i64;
            for j in 0..g.t {
                let delta = best - masked(j);
                if !(0..256).contains(&delta) {
                    return Err(range("exp difference"));
                }
                pl[ap(A_E)][g.six(hs, t, j)] = public.exp[delta as usize];
                if j <= t {
                    total += pl[ap(A_E)][g.six(hs, t, j)];
                }
            }
            if !((1i64 << f_e)..=((g.t as i64) << f_e)).contains(&total) {
                return Err("fixed oracle relation failure: softmax denominator".into());
            }
            pl[ap(A_SUM)][g.htix(hs, t)] = total;
            for j in 0..g.t {
                let idx = g.six(hs, t, j);
                let (q, rho) = if j <= t {
                    let num = pl[ap(A_E)][idx] << F_P;
                    (num / total, num % total)
                } else {
                    (0, 0)
                };
                let sigma = total - 1 - rho;
                if !(0..1i64 << wrho_s).contains(&sigma) || !(0..=1i64 << F_P).contains(&q) {
                    return Err(range("softmax quotient/remainder"));
                }
                // review finding F-1 (D24 review), TEST BUILDS ONLY: the
                // reviewer's hook that replaces ONE softmax quotient by a
                // chosen forgery AFTER the honest prover's own range check (a
                // cheating prover skips it); identity when unset
                #[cfg(test)]
                let (q, rho, sigma) = super::review_d24_tests::forge_softmax(h, t, j, total, q, rho, sigma);
                pl[ap(A_P)][idx] = q;
                // NATIVE R9: on a DD profile a score entry carries no limbs of
                // its own (the dictionary below does, per slot)
                if shape.dd_cap == 0 {
                    let (lp, lr, ls) = (limbs(q, g.lp), limbs(rho, g.ls), limbs(sigma, g.ls));
                    for k in 0..g.lp {
                        pl[ids.pl(k)][idx] = lp[k];
                    }
                    for k in 0..g.ls {
                        pl[ids.sr(k)][idx] = lr[k];
                        pl[ids.sg(k)][idx] = ls[k];
                    }
                }
            }
            // **NATIVE R9 (D30): this row's division dictionary.** Slot k of
            // row (h, t) holds the public e_k (the sorted column {0} U the exp
            // table's outputs, padded with 0 — B-7), the quotient
            // floor(e_k 2^F_P / Sum) with its limbs, and the remainder pair
            // (rho_s, sigma_s) with theirs: today's exact division, at EVERY
            // slot, padding slots included (B-1). `M_dd` counts the row's score
            // entries whose (mask E) is e_k, all of them on the FIRST slot
            // holding that value (the padding zeros carry no count).
            if shape.dd_cap > 0 {
                let cap = shape.dd_cap;
                let ecol = public.dd_e_column(cap)?;
                let base = (hs * g.t_pad + t) * cap;
                for (k, ek) in ecol.iter().enumerate() {
                    let num = ek << F_P;
                    let (q, rho) = (num / total, num % total);
                    let sigma = total - 1 - rho;
                    if !(0..1i64 << wrho_s).contains(&sigma) || !(0..=1i64 << F_P).contains(&q) {
                        return Err(range("dictionary quotient/remainder"));
                    }
                    pl[ids.pdict()][base + k] = q;
                    let (lq, lr, ls) = (limbs(q, g.lp), limbs(rho, g.ls), limbs(sigma, g.ls));
                    for kk in 0..g.lp {
                        pl[ids.pl(kk)][base + k] = lq[kk];
                    }
                    for kk in 0..g.ls {
                        pl[ids.sr(kk)][base + k] = lr[kk];
                        pl[ids.sg(kk)][base + k] = ls[kk];
                    }
                }
                for j in 0..g.t_pad {
                    let me = if j <= t { pl[ap(A_E)][g.six(hs, t, j)] } else { 0 };
                    let k = ecol.iter().position(|v| *v == me).ok_or_else(|| range("dictionary column"))?;
                    pl[ids.mdd()][base + k] += 1;
                }
            }
            for i in 0..g.dh {
                // (t, h, i') order, the Q-domain layout of o8
                oacc[g.qix(t, hs, i)] = (0..=t).map(|j| pl[ap(A_P)][g.six(hs, t, j)] * v8[g.kvix(j, kv, i)]).sum();
            }
        }
    }
    // NATIVE R9, TEST BUILDS ONLY: the D30 / CHECK.md mutation witnesses
    // (identity when unset). Each edits the honest witness CONSISTENTLY —
    // the PV accumulator is recomputed over every key position of the edited
    // rows — so that only the dictionary relation the mutation targets can
    // object.
    #[cfg(test)]
    if shape.dd_cap > 0 {
        dd_cheat(shape, &g, &ids, &mut pl, &mut oacc, &v8, &public.dd_e_column(shape.dd_cap)?)?;
    }
    // **S12a, finding S12-F3: `A_E` is EXEMPT from the pad rule and its
    // PADDED positions must still be genuine exp-table rows.** The LogUp arm
    // is never gated (§3.7a), so `protocol::exp_deltas` reads the WHOLE
    // padded `Dom::S` cube and the prover's histogram folds any pair that is
    // not a table row into entry 0, where only the value-0 identity notices
    // it — which is what the first honest rung proof failed on ("H: pcs zk:
    // group 8"). At a padded token row `A_MX` is 0 and `A_S8` is 0, so the
    // pair would be `(delta 0, e 0)` while `exp[0] = 2^F_E != 0`. That is
    // exactly the reason the memo's table EXEMPTS `A_E` (`pad::a_rule`).
    //
    // One pass over the whole cube, with `protocol::exp_deltas`' own formula,
    // fills it. On a TRUE position it recomputes the value the loop above
    // already wrote (`best` IS `A_MX`, and the mask is the same predicate),
    // so the toy — where `t_pad == tokens`, `h_pad == q_heads` and every
    // position is true — does not move by one word.
    // The pass itself is BELOW, after `A_S8`'s plane is written: it reads the
    // committed plane, exactly as `protocol::exp_deltas` does.
    let (o8, ro) = quantize(&oacc, &sup_q, shape.sh_o, -127, 127, "O")?;
    // `Wo` reads the head-permuted `Dom::Q` axis (`q_pad`) and writes
    // `Dom::D` (`d_pad`): both PADDED, with the padded head columns and the padded
    // output rows zero (ruling P-2, checked at construction)
    let (ao, ral) = quantize(&matmul(&g, &o8, g.q_pad, &public.wo, g.q_pad, g.d_pad, g.d_pad, dl), &sup_d, shape.sh_ao, -32768, 32767, "AO")?;

    // ---- residual 1 (all three shifts are 0: xres1 = x + ao exactly) ----
    for &idx in &sup_d {
        let x1 = x[idx] + ao[idx];
        if !(-32768..=32767).contains(&x1) {
            return Err(range("residual 1"));
        }
        pl[ap(A_X1)][idx] = x1;
        let l = limbs(x1 + 32768, 2);
        pl[ap(A_X1L0)][idx] = l[0];
        pl[ap(A_X1L1)][idx] = l[1];
        let l = limbs(ao[idx] + 32768, 2);
        pl[ap(A_AL0)][idx] = l[0];
        pl[ap(A_AL1)][idx] = l[1];
    }
    // `A_RO0` / `A_RO1` are `Dom::Q` planes, so they are written on the
    // head-permuted support, not on `Dom::D`'s (at the toy the two coincide)
    for &idx in &sup_q {
        let l = limbs(ro[idx], 2);
        pl[ap(A_RO0)][idx] = l[0];
        pl[ap(A_RO1)][idx] = l[1];
    }
    pl[ap(A_AO)] = ao;
    pl[ap(A_RAL)] = ral;
    pl[ap(A_Q8)] = q8;
    pl[ap(A_RQL)] = rql;
    pl[ap(A_QR8)] = qr8;
    pl[ap(A_RQRL)] = rqrl;
    pl[ap(A_O8)] = o8;
    pl[ap(A_K8)] = k8;
    pl[ap(A_RKL)] = rkl;
    pl[ap(A_V8)] = v8;
    pl[ap(A_RVL)] = rvl;
    pl[ap(A_KR8)] = kr8;
    pl[ap(A_RKRL)] = rkrl;
    pl[ap(A_S8)] = s8;
    pl[ap(A_RSL)] = rsl;
    // the `A_E` pad pass promised above, on the committed `A_S8` plane
    {
        let (tp, mx, s8p, ep) = (g.t_pad, ap(A_MX), ap(A_S8), ap(A_E));
        for x in 0..shape.size(Dom::S) {
            let (ht, j) = (x / tp, x % tp);
            let masked = if j <= ht % tp { pl[s8p][x] } else { MASK_SCORE };
            let delta = pl[mx][ht] - masked;
            if !(0..256).contains(&delta) {
                return Err(range("exp difference"));
            }
            pl[ep][x] = public.exp[delta as usize];
        }
    }

    // ================= the block half (kernel lib.rs:616-663) =================
    // ---- norm_m: the same relation, with gamma_m and xres1 ----
    let x1 = pl[ap(A_X1)].clone();
    let nmp = rms_norm(&g, &x1, &ff.gamma_m, shape.norm_wrho, shape.norm_cn_m)?;
    pl[ap(A_DM)] = nmp.d;
    pl[ap(A_DSQM)] = nmp.dsq;
    pl[ap(A_LIMBM)] = nmp.limb;
    pl[ap(A_YM)] = nmp.y;
    for (k, v) in nmp.rho.into_iter().enumerate() {
        pl[ids.mr(k)] = v;
    }
    for (k, v) in nmp.sigma.into_iter().enumerate() {
        pl[ids.ms(k)] = v;
    }

    // ---- the SiLU feed-forward, in the kernel's order so the FIRST refusal matches ----
    let nm = pl[ap(A_YM)].clone();
    let fl = g.len(Dom::F);
    // R1: the gate. Its class is the kernel's `I8`, which INCLUDES -128, not
    // the attention subset: the activation table has 256 rows, so `sym()`
    // would prove the wrong window (T2 section A.2).
    let (g8, rgl) = quantize(&matmul_in_out(&g, &nm, g.d_pad, &ff.wg_t, g.d_pad, g.f_pad, g.f_pad, fl), &sup_f, shape.sh_g, -128, 127, "FFN gate")?;
    // R3: up. SH_U = 0, so `requant` is the identity: no remainder plane, no
    // limbs for it, only the int16 class (T2 section A.4).
    let u16 = matmul_in_out(&g, &nm, g.d_pad, &ff.wu_t, g.d_pad, g.f_pad, g.f_pad, fl);
    if sup_f.iter().any(|k| !(-32768..=32767).contains(&u16[*k])) {
        return Err(range("FFN up"));
    }
    // R2: the activation lookup. `g8 + 128` is a valid index because R1's
    // class check already passed; the kernel names the same site if it is not.
    let mut a16 = vec![0i64; fl];
    for &k in &sup_f {
        let slot = usize::try_from(g8[k] + 128).map_err(|_| range("FFN gate"))?;
        a16[k] = ff.act.get(slot).map(|v| i64::from(*v)).ok_or_else(|| range("FFN gate"))?;
    }
    // R4: the product
    let hacc: Vec<i64> = a16.iter().zip(u16.iter()).map(|(a, u)| a * u).collect();
    let (h16, rh) = quantize(&hacc, &sup_f, shape.sh_h, -32768, 32767, "FFN product")?;
    // R5: down
    let (z16, rdl) = quantize(&matmul_in_out(&g, &h16, g.f_pad, &ff.wd_t, g.f_pad, g.d_pad, g.d_pad, dl), &sup_d, shape.sh_z, -32768, 32767, "FFN down")?;

    for &idx in &sup_f {
        let l = limbs(u16[idx] + 32768, 2);
        pl[ap(A_UL0)][idx] = l[0];
        pl[ap(A_UL1)][idx] = l[1];
        let l = limbs(h16[idx] + 32768, 2);
        pl[ap(A_HL0)][idx] = l[0];
        pl[ap(A_HL1)][idx] = l[1];
        let l = limbs(rh[idx], 2);
        pl[ap(A_RH0)][idx] = l[0];
        pl[ap(A_RH1)][idx] = l[1];
    }
    pl[ap(A_G8)] = g8;
    pl[ap(A_RGL)] = rgl;
    pl[ap(A_A16)] = a16;
    pl[ap(A_U16)] = u16;
    pl[ap(A_H16)] = h16;

    // ---- residual 2 (all three shifts are 0: xres2 = xres1 + z16 exactly) ----
    for &idx in &sup_d {
        let x2 = x1[idx] + z16[idx];
        if !(-32768..=32767).contains(&x2) {
            return Err(range("residual 2"));
        }
        pl[ap(A_X2)][idx] = x2;
        let l = limbs(x2 + 32768, 2);
        pl[ap(A_X2L0)][idx] = l[0];
        pl[ap(A_X2L1)][idx] = l[1];
        let l = limbs(z16[idx] + 32768, 2);
        pl[ap(A_ZL0)][idx] = l[0];
        pl[ap(A_ZL1)][idx] = l[1];
    }
    pl[ap(A_Z16)] = z16;
    pl[ap(A_RDL)] = rdl;

    Ok(Witness { planes: pl, output_plane: ids.at(A_X2) })
}

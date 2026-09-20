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
//! **GROUPED-QUERY ATTENTION IS NOT HERE YET (step S7).** Three sites still
//! read key-value head 0 for every query head and rotate one key head: the
//! `KR` rotation, the score accumulator and the PV accumulator, each marked
//! `NOT YET GROUPED`. At the toy (one key-value head) that is correct; at any
//! shape with `kv_heads > 1` it computes the wrong attention, which is what
//! `grow_tests::the_ungrouped_witness_disagrees_with_the_kernel_at_the_rung`
//! is for.
//!
//! The returned planes are SECRET. Nothing here prints, hashes or serializes
//! them; a refusal carries a site name only (the refusal itself still depends
//! on the input, exactly as the kernel's does).

use super::layout::*;
use super::shape::{Shape, LIMBS_ISQRT};
use super::{AttentionPublic, FeedForwardPublic};

pub(crate) struct Witness {
    /// one vector per A plane, `N_A` of them, indexed by the `A_*` ids. A
    /// lookup histogram (which the prover derives, not this builder) is an
    /// EMPTY vector, never a zero plane.
    pub planes: Vec<Vec<i64>>,
}

impl Witness {
    /// The block's output plane `xres2` (secret): what `SC_IO_OUT` binds and
    /// what an honest endpoint owner commits.
    pub(crate) fn output(&self) -> Result<Vec<i16>, String> {
        self.planes[A_X2].iter().map(|v| i16::try_from(*v).map_err(|_| "fixed oracle range refusal: residual 2".to_string())).collect()
    }
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
    f_pad: usize,
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
            f_pad: s.f_pad,
            kvw: s.kv_heads * s.head_dim,
            group: s.q_heads / s.kv_heads,
            ln: s.limbs_norm(),
            ls: s.limbs_sigma_s(),
            lp: s.limbs_p(),
        }
    }

    fn len(&self, dom: Dom) -> usize {
        self.s.size(dom)
    }
    /// `(t, i)` of `Dom::D`, and `(t, h, i')` of `Dom::Q` (the same flat index)
    fn dix(&self, t: usize, i: usize) -> usize {
        t * self.d_pad + i
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
    /// the true positions of a domain, in the order the toy visits them
    fn support(&self, dom: Dom) -> Vec<usize> {
        let mut v = Vec::with_capacity(self.s.true_size(dom));
        match dom {
            Dom::D | Dom::Q => {
                for t in 0..self.t {
                    for i in 0..self.d {
                        v.push(self.dix(t, i));
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
                            v.push(self.six(h, t, j));
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
                        v.push(self.htix(h, t));
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

/// `out[t, j] = sum_i x[t, i] * w[j, i]`, `w` stored (output, input), reading
/// `x` at stride `xs` and writing at stride `os` on a plane of `out_len`.
fn matmul(g: &Geom, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize) -> Vec<i64> {
    let mut out = vec![0i64; out_len];
    for t in 0..g.t {
        for j in 0..outer {
            out[t * os + j] = (0..inner).map(|i| x[t * xs + i] * i64::from(w[j * inner + i])).sum();
        }
    }
    out
}

/// `out[t, j] = sum_i x[t, i] * w[i, j]`, `w` stored (input, output) — the
/// feed-forward orientation, the kernel's `matmul_in_out`
fn matmul_in_out(g: &Geom, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize) -> Vec<i64> {
    let mut out = vec![0i64; out_len];
    for t in 0..g.t {
        for j in 0..outer {
            out[t * os + j] = (0..inner).map(|i| x[t * xs + i] * i64::from(w[i * outer + j])).sum();
        }
    }
    out
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

fn rms_norm(g: &Geom, x: &[i64], gamma: &[i8], norm_wrho: u32) -> Result<NormPlanes, String> {
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
        let ss: i64 = NORM_CEPS + row.iter().map(|v| v * v).sum::<i64>();
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
        let dv = d << NORM_TN;
        let den = 2 * dv;
        if den <= 0 {
            return Err(range("norm denominator"));
        }
        for i in 0..g.d {
            let num = 2 * row[i] * i64::from(gamma[i]) * NORM_CN + dv;
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

/// **The pinned plane table.** The `A_*` constants of `layout.rs` are literal
/// indices, so a shape whose plane LIST differs from the toy's would silently
/// write the wrong planes. The two windows that move it are the norm's limb
/// count and the softmax remainder's; both are four and two at the toy, the
/// rung and 125M, and step S8 is where a third `sigma_s` limb shifts every
/// index above `A_SG1`. Until then this refusal is what stops a shape the
/// plane table cannot express.
fn check_plane_table(shape: &Shape) -> Result<(), String> {
    let doms = shape.a_plane_doms();
    if doms.len() != N_A || (0..N_A).any(|p| doms[p] != a_dom(p)) {
        return Err("private block: this shape's A plane list differs from the pinned one".into());
    }
    Ok(())
}

/// the whole block, on the planes of `Layout::new` at `shape`
pub(crate) fn build_shaped(shape: &Shape, public: &AttentionPublic, ff: &FeedForwardPublic, input: &[i16]) -> Result<Witness, String> {
    check_plane_table(shape)?;
    let g = Geom::new(shape);
    if input.len() != g.t * g.d {
        return Err("private block: input shape".into());
    }
    let (f_e, wrho_s) = (shape.f_e, shape.wrho_s);
    let sup_d = g.support(Dom::D);
    let sup_kv = g.support(Dom::Kv);
    let sup_s = g.support(Dom::S);
    let sup_f = g.support(Dom::F);
    let mut pl: Vec<Vec<i64>> = (0..N_A).map(|p| if is_multiplicity(p) { Vec::new() } else { vec![0i64; g.len(a_dom(p))] }).collect();
    let mut x = vec![0i64; g.len(Dom::D)];
    for t in 0..g.t {
        for i in 0..g.d {
            x[g.dix(t, i)] = i64::from(input[t * g.d + i]);
        }
    }

    // ---- norm_a (round mode) ----
    let na = rms_norm(&g, &x, &public.gamma_a, shape.norm_wrho)?;
    pl[A_D] = na.d;
    pl[A_DSQ] = na.dsq;
    pl[A_LIMB] = na.limb;
    pl[A_Y] = na.y;
    for (k, v) in na.rho.into_iter().enumerate() {
        pl[A_NR0 + k] = v;
    }
    for (k, v) in na.sigma.into_iter().enumerate() {
        pl[A_NS0 + k] = v;
    }
    for &idx in &sup_d {
        pl[A_X][idx] = x[idx];
        let l = limbs(x[idx] + 32768, 2);
        pl[A_XL0][idx] = l[0];
        pl[A_XL1][idx] = l[1];
    }

    // ---- QKV, RoPE ----
    let y = pl[A_Y].clone();
    let (dl, kvl, sl) = (g.len(Dom::D), g.len(Dom::Kv), g.len(Dom::S));
    let (q8, rql) = quantize(&matmul(&g, &y, g.d_pad, &public.wq, g.d, g.d, g.d_pad, dl), &sup_d, SH_QKV, -127, 127, "Q")?;
    let (k8, rkl) = quantize(&matmul(&g, &y, g.d_pad, &public.wk, g.d, g.kvw, g.kvw, kvl), &sup_kv, SH_QKV, -127, 127, "K")?;
    let (v8, rvl) = quantize(&matmul(&g, &y, g.d_pad, &public.wv, g.d, g.kvw, g.kvw, kvl), &sup_kv, SH_QKV, -127, 127, "V")?;
    let (qr8, rqrl) = quantize(&rotate(&g, &q8, g.hq, g.d_pad, dl, &public.rope_cos, &public.rope_sin), &sup_d, SH_ROPE, -127, 127, "QR")?;
    // NOT YET GROUPED (step S7): the key rotation runs over ONE head and
    // every query head reads key-value head 0, which is what the toy's
    // `rotate(&k8, 1, ..)` and `kr8[j * KV + i]` did.
    let (kr8, rkrl) = quantize(&rotate(&g, &k8, 1, g.kvw, kvl, &public.rope_cos, &public.rope_sin), &sup_kv, SH_ROPE, -127, 127, "KR")?;

    // ---- scores over ALL (h, t, j): an out-of-range masked score still refuses ----
    let mut sacc = vec![0i64; sl];
    for h in 0..g.hq {
        for t in 0..g.t {
            for j in 0..g.t {
                sacc[g.six(h, t, j)] = (0..g.dh).map(|i| qr8[g.dix(t, h * g.dh + i)] * kr8[g.kvix(j, 0, i)]).sum();
            }
        }
    }
    let (s8, rsl) = quantize(&sacc, &sup_s, SH_S, -127, 127, "score")?;

    // ---- causal softmax, PV ----
    let mut oacc = vec![0i64; dl];
    for h in 0..g.hq {
        for t in 0..g.t {
            let masked = |j: usize| if j <= t { s8[g.six(h, t, j)] } else { MASK_SCORE };
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
            pl[A_MX][g.htix(h, t)] = best;
            pl[A_ZSEL][g.six(h, t, arg)] = 1;
            let mut total = 0i64;
            for j in 0..g.t {
                let delta = best - masked(j);
                if !(0..256).contains(&delta) {
                    return Err(range("exp difference"));
                }
                pl[A_E][g.six(h, t, j)] = public.exp[delta as usize];
                if j <= t {
                    total += pl[A_E][g.six(h, t, j)];
                }
            }
            if !((1i64 << f_e)..=((g.t as i64) << f_e)).contains(&total) {
                return Err("fixed oracle relation failure: softmax denominator".into());
            }
            pl[A_SUM][g.htix(h, t)] = total;
            for j in 0..g.t {
                let idx = g.six(h, t, j);
                let (q, rho) = if j <= t {
                    let num = pl[A_E][idx] << F_P;
                    (num / total, num % total)
                } else {
                    (0, 0)
                };
                let sigma = total - 1 - rho;
                if !(0..1i64 << wrho_s).contains(&sigma) || !(0..=1i64 << F_P).contains(&q) {
                    return Err(range("softmax quotient/remainder"));
                }
                pl[A_P][idx] = q;
                let (lp, lr, ls) = (limbs(q, g.lp), limbs(rho, g.ls), limbs(sigma, g.ls));
                for k in 0..g.lp {
                    pl[A_PL0 + k][idx] = lp[k];
                }
                for k in 0..g.ls {
                    pl[A_SR0 + k][idx] = lr[k];
                    pl[A_SG0 + k][idx] = ls[k];
                }
            }
            for i in 0..g.dh {
                // (t, h, i') order, the Q-domain layout of o8
                // NOT YET GROUPED (step S7): key-value head 0 for every query head
                oacc[g.dix(t, h * g.dh + i)] = (0..=t).map(|j| pl[A_P][g.six(h, t, j)] * v8[g.kvix(j, 0, i)]).sum();
            }
        }
    }
    let (o8, ro) = quantize(&oacc, &sup_d, SH_O, -127, 127, "O")?;
    let (ao, ral) = quantize(&matmul(&g, &o8, g.d_pad, &public.wo, g.d, g.d, g.d_pad, dl), &sup_d, SH_AO, -32768, 32767, "AO")?;

    // ---- residual 1 (all three shifts are 0: xres1 = x + ao exactly) ----
    for &idx in &sup_d {
        let x1 = x[idx] + ao[idx];
        if !(-32768..=32767).contains(&x1) {
            return Err(range("residual 1"));
        }
        pl[A_X1][idx] = x1;
        let l = limbs(x1 + 32768, 2);
        pl[A_X1L0][idx] = l[0];
        pl[A_X1L1][idx] = l[1];
        let l = limbs(ao[idx] + 32768, 2);
        pl[A_AL0][idx] = l[0];
        pl[A_AL1][idx] = l[1];
        let l = limbs(ro[idx], 2);
        pl[A_RO0][idx] = l[0];
        pl[A_RO1][idx] = l[1];
    }
    pl[A_AO] = ao;
    pl[A_RAL] = ral;
    pl[A_Q8] = q8;
    pl[A_RQL] = rql;
    pl[A_QR8] = qr8;
    pl[A_RQRL] = rqrl;
    pl[A_O8] = o8;
    pl[A_K8] = k8;
    pl[A_RKL] = rkl;
    pl[A_V8] = v8;
    pl[A_RVL] = rvl;
    pl[A_KR8] = kr8;
    pl[A_RKRL] = rkrl;
    pl[A_S8] = s8;
    pl[A_RSL] = rsl;

    // ================= the block half (kernel lib.rs:616-663) =================
    // ---- norm_m: the same relation, with gamma_m and xres1 ----
    let x1 = pl[A_X1].clone();
    let nmp = rms_norm(&g, &x1, &ff.gamma_m, shape.norm_wrho)?;
    pl[A_DM] = nmp.d;
    pl[A_DSQM] = nmp.dsq;
    pl[A_LIMBM] = nmp.limb;
    pl[A_YM] = nmp.y;
    for (k, v) in nmp.rho.into_iter().enumerate() {
        pl[A_MR0 + k] = v;
    }
    for (k, v) in nmp.sigma.into_iter().enumerate() {
        pl[A_MS0 + k] = v;
    }

    // ---- the SiLU feed-forward, in the kernel's order so the FIRST refusal matches ----
    let nm = pl[A_YM].clone();
    let fl = g.len(Dom::F);
    // R1: the gate. Its class is the kernel's `I8`, which INCLUDES -128, not
    // the attention subset: the activation table has 256 rows, so `sym()`
    // would prove the wrong window (T2 section A.2).
    let (g8, rgl) = quantize(&matmul_in_out(&g, &nm, g.d_pad, &ff.wg_t, g.d, g.f, g.f_pad, fl), &sup_f, SH_G, -128, 127, "FFN gate")?;
    // R3: up. SH_U = 0, so `requant` is the identity: no remainder plane, no
    // limbs for it, only the int16 class (T2 section A.4).
    let u16 = matmul_in_out(&g, &nm, g.d_pad, &ff.wu_t, g.d, g.f, g.f_pad, fl);
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
    let (h16, rh) = quantize(&hacc, &sup_f, SH_H_PROD, -32768, 32767, "FFN product")?;
    // R5: down
    let (z16, rdl) = quantize(&matmul_in_out(&g, &h16, g.f_pad, &ff.wd_t, g.f, g.d, g.d_pad, dl), &sup_d, SH_Z, -32768, 32767, "FFN down")?;

    for &idx in &sup_f {
        let l = limbs(u16[idx] + 32768, 2);
        pl[A_UL0][idx] = l[0];
        pl[A_UL1][idx] = l[1];
        let l = limbs(h16[idx] + 32768, 2);
        pl[A_HL0][idx] = l[0];
        pl[A_HL1][idx] = l[1];
        let l = limbs(rh[idx], 2);
        pl[A_RH0][idx] = l[0];
        pl[A_RH1][idx] = l[1];
    }
    pl[A_G8] = g8;
    pl[A_RGL] = rgl;
    pl[A_A16] = a16;
    pl[A_U16] = u16;
    pl[A_H16] = h16;

    // ---- residual 2 (all three shifts are 0: xres2 = xres1 + z16 exactly) ----
    for &idx in &sup_d {
        let x2 = x1[idx] + z16[idx];
        if !(-32768..=32767).contains(&x2) {
            return Err(range("residual 2"));
        }
        pl[A_X2][idx] = x2;
        let l = limbs(x2 + 32768, 2);
        pl[A_X2L0][idx] = l[0];
        pl[A_X2L1][idx] = l[1];
        let l = limbs(z16[idx] + 32768, 2);
        pl[A_ZL0][idx] = l[0];
        pl[A_ZL1][idx] = l[1];
    }
    pl[A_Z16] = z16;
    pl[A_RDL] = rdl;

    Ok(Witness { planes: pl })
}

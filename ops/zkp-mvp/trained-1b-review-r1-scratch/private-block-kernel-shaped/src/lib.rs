//! **The reference block kernel as a function of a SHAPE** (step S6 of the
//! 125M change list, moved out of `private-block-kernel` by job K).
//!
//! This is computation only, NOT a proof and NOT a privacy claim. It is the
//! same integer semantics the fixed crate `private-block-kernel` implements
//! at the toy geometry (T32 d16 f16, 2 heads of 8 over 1 key-value head),
//! written once over a [`Shape`].
//!
//! **Why it is not a module of that crate.** `private-block-kernel` is
//! compiled into the project's zkVM guest, whose image identity is an
//! approved recorded artifact; it is therefore byte-frozen at commit
//! `11c01b2` and this crate may not depend on it, so that the frozen crate
//! stays a leaf the guest compiles alone. The price is that [`calib`] and
//! the scalar primitives below are COPIES. The copy is guarded, not
//! trusted: `hashline::private_block::parity` asserts at [`Shape::toy()`]
//! that every constant, `isqrt`, `requant` and every trace plane of
//! [`run_shaped`] equal the frozen crate's, on every existing fixture case.
//!
//! **`no_std`, no dependencies, no allocation, no floats, no I/O, no GPU and
//! no proof-library coupling.** The general path cannot size its own
//! intermediates, so the CALLER supplies one flat scratch buffer of
//! [`Shape::scratch_len`] `i64` words and (for parity tests only) one flat
//! trace buffer of [`Shape::trace_len`] words.
//!
//! **What is shape-driven and what is not.** The geometry (`tokens`,
//! `width`, `hidden`, `q_heads`, `kv_heads`, `head_dim`) and the four
//! calibration WINDOWS (`f_e`, `f_p`, `wrho_s`, `norm_wrho`) come from the
//! shape. The requantization SHIFTS and the masked-score constant are still
//! the single approved calibration of [`calib`] (memo section 3.8 keeps them
//! fixed across shapes); a shape that needed different shifts would be a
//! different calibration and so a different trusted image.
//!
//! **NATIVE LANE (2026-10-17), the one exception:** the norm's `tn`, the two
//! norms' `Cn` (norm_a and norm_m separately), `Ceps` and the attention-output
//! shift `sh_ao` are fields of [`Shape`], at the frozen [`calib`] values unless
//! [`Shape::with_norm_calibration`] sets a trained calibration (the TinyLlama
//! trained profile). The toy keeps the frozen values, so its parity against
//! the frozen crate is unchanged.
//!
//! **Grouped-query attention** is expressed here for any group: query head
//! `h` reads key-value head `h / group` with `group = q_heads / kv_heads`,
//! and the key/value rotation runs over `kv_heads` heads. At the toy
//! (`kv_heads = 1`) every query head reads head 0 and the offset is always
//! 0, which is what the fixed path always did.
//!
//! Arithmetic rules, as in the fixed crate: every intermediate is recomputed
//! here (nothing claimed by a caller is consumed), i64 with checked
//! add/mul/shift (an overflow is a [`KernelError::Overflow`], never a wrap),
//! checked narrowing, and NO clamping: an out-of-class value is a refusal,
//! never a saturated result. Structural validation of the public weights and
//! tables is NOT authentication.
//!
//! The trace holds SECRET intermediate activations and exists for native
//! parity tests only; nothing here prints, hashes or serializes it.

#![no_std]
#![forbid(unsafe_code)]

#[cfg(test)]
extern crate std;

use core::fmt;

/// Fixed public calibration, a COPY of `private_block_kernel::calib` (see the
/// crate header for why it is copied and how the copy is guarded).
/// Deliberately not configurable: a different calibration is a different
/// kernel (and a different trusted image).
pub mod calib {
    pub const NORM_TN: u32 = 11;
    pub const NORM_CN: i64 = 1024;
    pub const NORM_CEPS: i64 = 1;
    pub const NORM_WRHO: u32 = 29;
    pub const SH_Q: i32 = 7;
    pub const SH_K: i32 = 7;
    pub const SH_V: i32 = 7;
    pub const SH_QR: i32 = 7;
    pub const SH_KR: i32 = 7;
    pub const SH_S: i32 = 6;
    pub const SH_O: i32 = 9;
    pub const SH_AO: i32 = 7;
    pub const SH_X1: u32 = 0;
    pub const SH_A1: u32 = 0;
    pub const SH_R1: i32 = 0;
    pub const F_E: u32 = 9;
    pub const F_P: u32 = 9;
    pub const F_RO: u32 = 7;
    pub const WRHO_S: u32 = 14;
    /// FFN (gate, up, product, down) shifts.
    pub const SH_G: i32 = 7;
    pub const SH_U: i32 = 0;
    pub const SH_H: i32 = 14;
    pub const SH_Z: i32 = 6;
    pub const SH_X2: u32 = 0;
    pub const SH_Z2: u32 = 0;
    pub const SH_R2: i32 = 0;
    /// Score written at masked (future) positions before the max.
    pub const MASK: i64 = -127;
}
use calib::*;

/// Refusal. Carries only a static site name (never data), so it is safe to
/// display. `Range`/`Relation` sites use the oracle's exact strings, and the
/// `Display` text is character for character the frozen crate's, because the
/// parity tests compare refusals as strings.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum KernelError {
    Shape(&'static str),
    Table(&'static str),
    Range(&'static str),
    Relation(&'static str),
    Overflow(&'static str),
}

impl fmt::Display for KernelError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Shape(s) => write!(f, "kernel shape refusal: {s}"),
            Self::Table(s) => write!(f, "kernel public table refusal: {s}"),
            Self::Range(s) => write!(f, "fixed oracle range refusal: {s}"),
            Self::Relation(s) => write!(f, "fixed oracle relation failure: {s}"),
            Self::Overflow(s) => write!(f, "kernel checked arithmetic overflow: {s}"),
        }
    }
}

pub type Res<V> = Result<V, KernelError>;

// ---------------------------------------------------------------- scalars

fn add(a: i64, b: i64, site: &'static str) -> Res<i64> {
    a.checked_add(b).ok_or(KernelError::Overflow(site))
}
fn sub(a: i64, b: i64, site: &'static str) -> Res<i64> {
    a.checked_sub(b).ok_or(KernelError::Overflow(site))
}
fn mul(a: i64, b: i64, site: &'static str) -> Res<i64> {
    a.checked_mul(b).ok_or(KernelError::Overflow(site))
}
/// Exact `v * 2^s` (never a wrapping shift).
fn shl(v: i64, s: u32, site: &'static str) -> Res<i64> {
    if s >= 63 {
        return Err(KernelError::Overflow(site));
    }
    mul(v, 1i64 << s, site)
}

/// Requantization at a SIGNED shift, as `export_v3::requant_round`:
/// `s > 0`: `y = floor((acc + 2^(s-1)) / 2^s)` (round to nearest, ties toward
/// +inf, remainder `acc - y 2^s` in `[-2^(s-1), 2^(s-1))`);
/// `s <= 0`: exact up-scaling `y = acc * 2^-s`.
///
/// `pub` so that the cross-parity test can compare it against the frozen
/// crate's directly, primitive for primitive, and not only through a block.
pub fn requant(acc: i64, sh: i32, site: &'static str) -> Res<i64> {
    if sh <= 0 {
        return shl(acc, sh.unsigned_abs(), site);
    }
    let s = sh as u32;
    if s >= 63 {
        return Err(KernelError::Overflow(site));
    }
    // Arithmetic shift of a signed value is floor division by 2^s.
    Ok(add(acc, 1i64 << (s - 1), site)? >> s)
}

/// Floor integer square root, integer-only (no float seed). `pub` for the
/// same reason as [`requant`].
pub fn isqrt(v: u64) -> u64 {
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

/// Attention int8 subset `[-127, 127]` (excludes -128, as the oracle does).
const I8N: (i64, i64) = (-127, 127);
const I8: (i64, i64) = (-128, 127);
const I16: (i64, i64) = (-32768, 32767);

/// ONE block geometry plus the four calibration windows that move with it.
///
/// Built through [`Shape::new`], which refuses by name every geometry this
/// computation cannot express. The three named shapes are the toy (the only
/// one that proves anything today), the development rung of ruling P-7 and
/// the 125M-class block.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Shape {
    pub tokens: usize,
    pub width: usize,
    pub hidden: usize,
    pub q_heads: usize,
    pub kv_heads: usize,
    pub head_dim: usize,
    /// the exponential table's fractional bits (`Sum` lives in `[2^f_e, T 2^f_e]`)
    pub f_e: u32,
    /// the softmax quotient's fractional bits (`p` lives in `[0, 2^f_p]`)
    pub f_p: u32,
    /// the softmax remainder window: `sigma_s < 2^wrho_s`
    pub wrho_s: u32,
    /// the norm remainder window: `rho, sigma < 2^norm_wrho`
    pub norm_wrho: u32,
    /// **NATIVE LANE (2026-10-17): the per-profile norm / attention-output
    /// calibration.** [`Shape::new`] sets the frozen [`calib`] values, so every
    /// existing caller (and the toy parity against the frozen crate) is bit
    /// for bit unchanged; [`Shape::with_norm_calibration`] is the only way to
    /// set a trained calibration, and [`Shape::check`] refuses a value outside
    /// the declared class. norm_a and norm_m carry separate multipliers.
    pub norm_tn: u32,
    pub norm_cn_a: i64,
    pub norm_cn_m: i64,
    pub norm_ceps: i64,
    pub sh_ao: i32,
}

impl Shape {
    #[allow(clippy::too_many_arguments)]
    pub const fn new(
        tokens: usize,
        width: usize,
        hidden: usize,
        q_heads: usize,
        kv_heads: usize,
        head_dim: usize,
        f_e: u32,
        f_p: u32,
        wrho_s: u32,
        norm_wrho: u32,
    ) -> Shape {
        Shape { tokens, width, hidden, q_heads, kv_heads, head_dim, f_e, f_p, wrho_s, norm_wrho, norm_tn: NORM_TN, norm_cn_a: NORM_CN, norm_cn_m: NORM_CN, norm_ceps: NORM_CEPS, sh_ao: SH_AO }
    }

    /// **NATIVE LANE: a trained norm calibration** — `tn`, the two norms'
    /// multipliers, `Ceps` and the attention-output shift. The caller states
    /// the window (`norm_wrho`) separately; [`Shape::check`] refuses a class
    /// violation.
    pub const fn with_norm_calibration(mut self, tn: u32, cn_a: i64, cn_m: i64, ceps: i64, sh_ao: i32) -> Shape {
        self.norm_tn = tn;
        self.norm_cn_a = cn_a;
        self.norm_cn_m = cn_m;
        self.norm_ceps = ceps;
        self.sh_ao = sh_ao;
        self
    }

    /// THE TOY, bit for bit the frozen crate's geometry and calibration.
    pub const fn toy() -> Shape {
        Shape::new(32, 16, 16, 2, 1, 8, F_E, F_P, WRHO_S, NORM_WRHO)
    }

    /// Every geometry this computation cannot express, refused by name. The
    /// checks are the kernel's own; the layout's construction-time refusals
    /// (`private_block::shape::Shape::new`) are a superset that also covers
    /// the padded widths, which this crate never sees.
    pub fn check(&self) -> Res<()> {
        if self.tokens == 0 || self.width == 0 || self.hidden == 0 || self.q_heads == 0 || self.kv_heads == 0 || self.head_dim == 0 {
            return Err(KernelError::Shape("shape: an axis is zero"));
        }
        if self.head_dim % 2 != 0 {
            return Err(KernelError::Shape("shape: the head dimension is odd"));
        }
        if self.width != self.q_heads * self.head_dim {
            return Err(KernelError::Shape("shape: width differs from q_heads * head_dim"));
        }
        if self.q_heads % self.kv_heads != 0 {
            return Err(KernelError::Shape("shape: the query heads do not divide into the key-value heads"));
        }
        if self.f_e >= 32 || self.f_p >= 32 || self.wrho_s >= 63 || self.norm_wrho >= 63 {
            return Err(KernelError::Shape("shape: a calibration window is out of range"));
        }
        // NATIVE LANE: the declared class of a trained calibration (the same
        // bounds the prover's validator enforces)
        if !(1..=16).contains(&self.norm_tn)
            || !(1..=1i64 << 20).contains(&self.norm_cn_a)
            || !(1..=1i64 << 20).contains(&self.norm_cn_m)
            || !(1..=1i64 << 40).contains(&self.norm_ceps)
            || !(0..=8).contains(&self.sh_ao)
        {
            return Err(KernelError::Shape("shape: a norm calibration constant is out of its class"));
        }
        Ok(())
    }

    pub const fn half_dim(&self) -> usize {
        self.head_dim / 2
    }
    /// the key/value axis width: `kv_heads * head_dim`
    pub const fn kv_width(&self) -> usize {
        self.kv_heads * self.head_dim
    }
    /// query heads per key-value head
    pub const fn group(&self) -> usize {
        self.q_heads / self.kv_heads
    }
    pub const fn x_len(&self) -> usize {
        self.tokens * self.width
    }
    pub const fn kv_len(&self) -> usize {
        self.tokens * self.kv_width()
    }
    pub const fn ff_len(&self) -> usize {
        self.tokens * self.hidden
    }
    pub const fn score_len(&self) -> usize {
        self.q_heads * self.tokens * self.tokens
    }
    /// attention rows `(h, t)`
    pub const fn rows(&self) -> usize {
        self.q_heads * self.tokens
    }
    pub const fn rope_len(&self) -> usize {
        self.tokens * self.half_dim()
    }

    /// `i64` words of scratch [`run_shaped`] needs. Eleven `x`-sized planes,
    /// three key/value planes, one score cube, four feed-forward planes and
    /// four token-sized rows.
    pub const fn scratch_len(&self) -> usize {
        11 * self.x_len() + 3 * self.kv_len() + self.score_len() + 4 * self.ff_len() + 4 * self.tokens
    }

    /// `i64` words of the (parity-test only) trace buffer. Nine `x`-sized
    /// parts, three key/value parts, two score cubes, three `(h, t)` rows,
    /// four feed-forward parts and the two isqrt columns; a unit test checks
    /// this closed form against the sum over [`PARTS`].
    pub const fn trace_len(&self) -> usize {
        9 * self.x_len() + 3 * self.kv_len() + 2 * self.score_len() + 3 * self.rows() + 4 * self.ff_len() + 2 * self.tokens
    }

    pub fn part_len(&self, p: Part) -> usize {
        match p {
            Part::NaDd | Part::NmDd => self.tokens,
            Part::NaY | Part::Q8 | Part::Qr8 | Part::O8 | Part::Ao8 | Part::Xres1 | Part::NmY | Part::Z16 | Part::Xres2 => self.x_len(),
            Part::K8 | Part::V8 | Part::Kr8 => self.kv_len(),
            Part::S8 | Part::P => self.score_len(),
            Part::MRow | Part::Arg | Part::Sum => self.rows(),
            Part::G8 | Part::A16 | Part::U16 | Part::H16 => self.ff_len(),
        }
    }

    /// `(offset, length)` of one trace part inside a [`Shape::trace_len`]
    /// buffer, in the fixed order of [`PARTS`].
    pub fn part(&self, want: Part) -> (usize, usize) {
        let mut off = 0usize;
        for p in PARTS {
            let n = self.part_len(p);
            if p == want {
                return (off, n);
            }
            off += n;
        }
        unreachable!()
    }
}

/// One named secret intermediate of the trace. Names and layouts follow the
/// frozen crate's `Trace`: `S8` and `P` are head-major `(h, t, j)` over ALL
/// `j`, `MRow`/`Arg`/`Sum` are `(h, t)`, `K8`/`V8`/`Kr8` are `(t, kv, i')`
/// and everything else is row-major `(t, *)`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Part {
    NaDd,
    NaY,
    Q8,
    K8,
    V8,
    Qr8,
    Kr8,
    S8,
    MRow,
    Arg,
    Sum,
    P,
    O8,
    Ao8,
    Xres1,
    NmDd,
    NmY,
    G8,
    A16,
    U16,
    H16,
    Z16,
    Xres2,
}

/// the fixed order the trace buffer is laid out in
pub const PARTS: [Part; 23] = [
    Part::NaDd,
    Part::NaY,
    Part::Q8,
    Part::K8,
    Part::V8,
    Part::Qr8,
    Part::Kr8,
    Part::S8,
    Part::MRow,
    Part::Arg,
    Part::Sum,
    Part::P,
    Part::O8,
    Part::Ao8,
    Part::Xres1,
    Part::NmDd,
    Part::NmY,
    Part::G8,
    Part::A16,
    Part::U16,
    Part::H16,
    Part::Z16,
    Part::Xres2,
];

/// PUBLIC block weights as borrowed slices. Attention matrices are
/// `(output, input)` row-major, feed-forward matrices `(input, output)`,
/// exactly as the frozen crate's `PublicWeights`. Structural validation is
/// NOT authentication (see the crate header).
#[derive(Clone, Copy)]
pub struct WeightsRef<'a> {
    pub wq: &'a [i8],
    pub wk: &'a [i8],
    pub wv: &'a [i8],
    pub wo: &'a [i8],
    pub gamma_a: &'a [i8],
    pub gamma_m: &'a [i8],
    pub wg_t: &'a [i8],
    pub wu_t: &'a [i8],
    pub wd_t: &'a [i8],
}

impl WeightsRef<'_> {
    pub fn check(&self, sh: &Shape) -> Res<()> {
        let (d, f, kv) = (sh.width, sh.hidden, sh.kv_width());
        for (got, want, site) in [
            (self.wq.len(), d * d, "wq"),
            (self.wk.len(), kv * d, "wk"),
            (self.wv.len(), kv * d, "wv"),
            (self.wo.len(), d * d, "wo"),
            (self.gamma_a.len(), d, "gamma_a"),
            (self.gamma_m.len(), d, "gamma_m"),
            (self.wg_t.len(), d * f, "wg_t"),
            (self.wu_t.len(), d * f, "wu_t"),
            (self.wd_t.len(), f * d, "wd_t"),
        ] {
            if got != want {
                return Err(KernelError::Shape(site));
            }
        }
        Ok(())
    }
}

/// PUBLIC lookup tables as borrowed slices: RoPE cos/sin (`tokens x
/// head_dim/2` row-major at `2^-F_RO`), the 256-entry exp-neg table at
/// `2^-f_e` and the 256-entry int16-output activation table indexed by
/// `gate + 128`.
#[derive(Clone, Copy)]
pub struct TablesRef<'a> {
    pub rope_cos: &'a [i64],
    pub rope_sin: &'a [i64],
    pub exp: &'a [i64],
    pub act: &'a [i16],
}

impl TablesRef<'_> {
    /// The same shape and STRUCTURE checks the frozen crate's `PublicTables`
    /// makes, at this shape's rope length and this shape's `f_e`.
    pub fn check(&self, sh: &Shape) -> Res<()> {
        if self.rope_cos.len() != sh.rope_len() {
            return Err(KernelError::Shape("rope_cos"));
        }
        if self.rope_sin.len() != sh.rope_len() {
            return Err(KernelError::Shape("rope_sin"));
        }
        if self.exp.len() != 256 {
            return Err(KernelError::Shape("exp"));
        }
        if self.act.len() != 256 {
            return Err(KernelError::Shape("act"));
        }
        let half = sh.half_dim();
        let one_ro = 1i64 << F_RO;
        if self.rope_cos.iter().chain(self.rope_sin.iter()).any(|v| !(-one_ro..=one_ro).contains(v)) {
            return Err(KernelError::Table("rope range"));
        }
        if self.rope_cos[..half].iter().any(|c| *c != one_ro) || self.rope_sin[..half].iter().any(|s| *s != 0) {
            return Err(KernelError::Table("rope position 0"));
        }
        let one_e = 1i64 << sh.f_e;
        if self.exp[0] != one_e {
            return Err(KernelError::Table("exp E[0]"));
        }
        if self.exp.iter().any(|e| !(0..=one_e).contains(e)) {
            return Err(KernelError::Table("exp range"));
        }
        if self.exp.windows(2).any(|w| w[0] < w[1]) {
            return Err(KernelError::Table("exp monotone"));
        }
        Ok(())
    }
}

// ------------------------------------------------------------------ scratch

/// Carve `n` words off the front of a scratch buffer, no allocation.
fn take<'a>(buf: &mut &'a mut [i64], n: usize) -> &'a mut [i64] {
    let all = core::mem::take(buf);
    let (head, tail) = all.split_at_mut(n);
    *buf = tail;
    head
}

fn zero(buf: &mut [i64]) {
    for v in buf.iter_mut() {
        *v = 0;
    }
}

// ------------------------------------------------------------------ tensors
//
// VISIBILITY, deliberately: the five items the frozen crate also exports
// (`matmul_out_in`, `matmul_in_out`, `requant`, `isqrt`, and `softmax_row`,
// whose counterpart here is `softmax_row_into`) are `pub`, so the
// cross-parity test can compare the two crates function for function and
// not only end to end. `rms_norm` and `rotate` are private in the frozen
// crate, have no counterpart to compare against, and stay `pub(crate)`.

/// `out[t, j] = sum_i x[t, i] * w[j, i]` with `w` stored (output, input).
pub fn matmul_out_in(rows: usize, x: &[i64], w: &[i8], inner: usize, outer: usize, out: &mut [i64]) -> Res<()> {
    if x.len() != rows * inner || w.len() != inner * outer || out.len() != rows * outer {
        return Err(KernelError::Shape("matmul_out_in"));
    }
    for t in 0..rows {
        for j in 0..outer {
            let mut acc = 0i64;
            for i in 0..inner {
                acc = add(acc, mul(x[t * inner + i], i64::from(w[j * inner + i]), "matmul")?, "matmul")?;
            }
            out[t * outer + j] = acc;
        }
    }
    Ok(())
}

/// `out[t, j] = sum_i x[t, i] * w[i, j]` with `w` stored (input, output).
pub fn matmul_in_out(rows: usize, x: &[i64], w: &[i8], inner: usize, outer: usize, out: &mut [i64]) -> Res<()> {
    if x.len() != rows * inner || w.len() != inner * outer || out.len() != rows * outer {
        return Err(KernelError::Shape("matmul_in_out"));
    }
    for t in 0..rows {
        for j in 0..outer {
            let mut acc = 0i64;
            for i in 0..inner {
                acc = add(acc, mul(x[t * inner + i], i64::from(w[i * outer + j]), "matmul")?, "matmul")?;
            }
            out[t * outer + j] = acc;
        }
    }
    Ok(())
}

fn requant_all(buf: &mut [i64], sh: i32, (lo, hi): (i64, i64), site: &'static str) -> Res<()> {
    for v in buf.iter_mut() {
        let y = requant(*v, sh, site)?;
        if !(lo..=hi).contains(&y) {
            return Err(KernelError::Range(site));
        }
        *v = y;
    }
    Ok(())
}

/// Round-mode RMSNorm over `tokens` rows of `width`, at this shape's norm
/// window: `D = isqrt(sum x^2 + Ceps)`,
/// `y = floor((2 x g Cn + D 2^tn) / (D 2^(tn+1)))`.
pub(crate) fn rms_norm(sh: &Shape, x: &[i64], g: &[i8], cn: i64, y: &mut [i64], dd: &mut [i64]) -> Res<()> {
    const SITE: &str = "norm quotient/remainder";
    let wrho = 1i64 << sh.norm_wrho;
    let d_w = sh.width;
    for t in 0..sh.tokens {
        let row = &x[t * d_w..(t + 1) * d_w];
        let mut ss = sh.norm_ceps;
        for v in row {
            ss = add(ss, mul(*v, *v, "norm")?, "norm")?;
        }
        let ss = u64::try_from(ss).map_err(|_| KernelError::Range("norm denominator"))?;
        let d = i64::try_from(isqrt(ss)).map_err(|_| KernelError::Overflow("norm"))?;
        let dv = shl(d, sh.norm_tn, "norm")?;
        let den = mul(dv, 2, "norm")?;
        if den <= 0 {
            return Err(KernelError::Range("norm denominator"));
        }
        for i in 0..d_w {
            let num = add(mul(mul(mul(2, row[i], "norm")?, i64::from(g[i]), "norm")?, cn, "norm")?, dv, "norm")?;
            let q = num.div_euclid(den);
            let rho = num.rem_euclid(den);
            let sigma = den - 1 - rho;
            if !(I8N.0..=I8N.1).contains(&q) || rho >= wrho || sigma >= wrho {
                return Err(KernelError::Range(SITE));
            }
            y[t * d_w + i] = q;
        }
        dd[t] = d;
    }
    Ok(())
}

/// Half-split RoPE (pairs `i` and `i + head_dim/2`) over `heads` heads per row.
pub(crate) fn rotate(sh: &Shape, x: &[i64], heads: usize, tab: &TablesRef, out: &mut [i64]) -> Res<()> {
    let (dh, half) = (sh.head_dim, sh.half_dim());
    let width = heads * dh;
    if x.len() != sh.tokens * width || out.len() != sh.tokens * width {
        return Err(KernelError::Shape("rope"));
    }
    for t in 0..sh.tokens {
        for h in 0..heads {
            let base = t * width + h * dh;
            for i in 0..half {
                let (c, s) = (tab.rope_cos[t * half + i], tab.rope_sin[t * half + i]);
                let (a, b) = (x[base + i], x[base + half + i]);
                out[base + i] = sub(mul(c, a, "rope")?, mul(s, b, "rope")?, "rope")?;
                out[base + half + i] = add(mul(s, a, "rope")?, mul(c, b, "rope")?, "rope")?;
            }
        }
    }
    Ok(())
}

/// One causal softmax row at query position `t`, writing `p` (length
/// `tokens`) in place. Returns `(max, arg, sum)`. Refusal sites and order
/// match the frozen crate's `softmax_row`.
pub fn softmax_row_into(sh: &Shape, scores: &[i64], t: usize, exp: &[i64], e: &mut [i64], p: &mut [i64]) -> Res<(i64, usize, i64)> {
    let n = sh.tokens;
    if t >= n || scores.len() != n || e.len() != n || p.len() != n {
        return Err(KernelError::Shape("softmax row"));
    }
    let masked = |j: usize| if j <= t { scores[j] } else { MASK };
    let mut best = i64::MIN;
    let mut arg = 0usize;
    for j in 0..n {
        let s = masked(j);
        if s > best {
            best = s;
            arg = j;
        }
    }
    if arg > t {
        return Err(KernelError::Relation("causal maximum attainment"));
    }
    let mut total = 0i64;
    for j in 0..n {
        let delta = sub(best, masked(j), "softmax")?;
        if !(0..256).contains(&delta) {
            return Err(KernelError::Range("exp difference"));
        }
        e[j] = exp[delta as usize];
        if j <= t {
            total = add(total, e[j], "softmax")?;
        }
    }
    if !((1i64 << sh.f_e)..=((n as i64) << sh.f_e)).contains(&total) {
        return Err(KernelError::Relation("softmax denominator"));
    }
    for j in 0..n {
        let (q, rho) = if j <= t {
            let num = shl(e[j], sh.f_p, "softmax")?;
            (num / total, num % total)
        } else {
            (0, 0)
        };
        let sigma = total - 1 - rho;
        if !(0..1i64 << sh.wrho_s).contains(&sigma) || !(0..=1i64 << sh.f_p).contains(&q) {
            return Err(KernelError::Range("softmax quotient/remainder"));
        }
        p[j] = q;
    }
    Ok((best, arg, total))
}

// -------------------------------------------------------------------- block

fn put(trace: &mut Option<&mut [i64]>, sh: &Shape, part: Part, src: &[i64]) {
    if let Some(buf) = trace.as_deref_mut() {
        let (off, len) = sh.part(part);
        debug_assert_eq!(len, src.len());
        buf[off..off + len].copy_from_slice(src);
    }
}

/// THE BLOCK, at any shape this crate can express: norm_a, QKV, grouped-query
/// RoPE attention, O, residual 1, norm_m, the SiLU feed-forward and residual
/// 2, in the frozen path's exact order so that the FIRST refusal is the same.
///
/// `out` receives `xres2` as `i16`. `scratch` must hold
/// [`Shape::scratch_len`] words and `trace`, when present,
/// [`Shape::trace_len`]; the trace is filled progressively and is partial on
/// refusal.
pub fn run_shaped(sh: &Shape, input: &[i16], w: &WeightsRef, tab: &TablesRef, scratch: &mut [i64], mut trace: Option<&mut [i64]>, out: &mut [i16]) -> Res<()> {
    sh.check()?;
    w.check(sh)?;
    tab.check(sh)?;
    if input.len() != sh.x_len() {
        return Err(KernelError::Shape("input"));
    }
    if out.len() != sh.x_len() {
        return Err(KernelError::Shape("output"));
    }
    if scratch.len() != sh.scratch_len() {
        return Err(KernelError::Shape("scratch"));
    }
    if let Some(buf) = trace.as_deref() {
        if buf.len() != sh.trace_len() {
            return Err(KernelError::Shape("trace"));
        }
    }
    zero(scratch);

    let (tokens, d_w, f_w, dh) = (sh.tokens, sh.width, sh.hidden, sh.head_dim);
    let (kvw, group) = (sh.kv_width(), sh.group());
    let mut rest: &mut [i64] = scratch;
    let x = take(&mut rest, sh.x_len());
    let na = take(&mut rest, sh.x_len());
    let q = take(&mut rest, sh.x_len());
    let qr = take(&mut rest, sh.x_len());
    let o = take(&mut rest, sh.x_len());
    let o8 = take(&mut rest, sh.x_len());
    let ao = take(&mut rest, sh.x_len());
    let x1 = take(&mut rest, sh.x_len());
    let nm = take(&mut rest, sh.x_len());
    let z = take(&mut rest, sh.x_len());
    let x2 = take(&mut rest, sh.x_len());
    let k = take(&mut rest, sh.kv_len());
    let v = take(&mut rest, sh.kv_len());
    let kr = take(&mut rest, sh.kv_len());
    let s = take(&mut rest, sh.score_len());
    let g = take(&mut rest, sh.ff_len());
    let u = take(&mut rest, sh.ff_len());
    let a = take(&mut rest, sh.ff_len());
    let hh = take(&mut rest, sh.ff_len());
    let na_dd = take(&mut rest, tokens);
    let nm_dd = take(&mut rest, tokens);
    let erow = take(&mut rest, tokens);
    let prow = take(&mut rest, tokens);
    debug_assert!(rest.is_empty());

    for (dst, src) in x.iter_mut().zip(input.iter()) {
        *dst = i64::from(*src);
    }

    rms_norm(sh, x, w.gamma_a, sh.norm_cn_a, na, na_dd)?;

    matmul_out_in(tokens, na, w.wq, d_w, d_w, q)?;
    matmul_out_in(tokens, na, w.wk, d_w, kvw, k)?;
    matmul_out_in(tokens, na, w.wv, d_w, kvw, v)?;
    requant_all(q, SH_Q, I8N, "Q")?;
    requant_all(k, SH_K, I8N, "K")?;
    requant_all(v, SH_V, I8N, "V")?;

    rotate(sh, q, sh.q_heads, tab, qr)?;
    rotate(sh, k, sh.kv_heads, tab, kr)?;
    requant_all(qr, SH_QR, I8N, "QR")?;
    requant_all(kr, SH_KR, I8N, "KR")?;

    // Scores over ALL (t, j), so an out-of-range masked score still refuses.
    // GROUPED-QUERY: query head h reads key-value head h / group.
    for h in 0..sh.q_heads {
        let kvo = (h / group) * dh;
        for t in 0..tokens {
            for j in 0..tokens {
                let mut acc = 0i64;
                for i in 0..dh {
                    acc = add(acc, mul(qr[t * d_w + h * dh + i], kr[j * kvw + kvo + i], "score")?, "score")?;
                }
                s[(h * tokens + t) * tokens + j] = acc;
            }
        }
    }
    requant_all(s, SH_S, I8N, "score")?;
    put(&mut trace, sh, Part::NaDd, na_dd);
    put(&mut trace, sh, Part::NaY, na);
    put(&mut trace, sh, Part::Q8, q);
    put(&mut trace, sh, Part::K8, k);
    put(&mut trace, sh, Part::V8, v);
    put(&mut trace, sh, Part::Qr8, qr);
    put(&mut trace, sh, Part::Kr8, kr);
    put(&mut trace, sh, Part::S8, s);

    // Head-major (h, t, i) accumulator, as the oracle's oacc.
    for h in 0..sh.q_heads {
        let kvo = (h / group) * dh;
        for t in 0..tokens {
            let base = (h * tokens + t) * tokens;
            let (max, arg, sum) = softmax_row_into(sh, &s[base..base + tokens], t, tab.exp, erow, prow)?;
            for i in 0..dh {
                let mut acc = 0i64;
                for j in 0..=t {
                    acc = add(acc, mul(prow[j], v[j * kvw + kvo + i], "PV")?, "PV")?;
                }
                o[(h * tokens + t) * dh + i] = acc;
            }
            if let Some(buf) = trace.as_deref_mut() {
                let row = h * tokens + t;
                for (part, val) in [(Part::MRow, max), (Part::Arg, arg as i64), (Part::Sum, sum)] {
                    let (off, _) = sh.part(part);
                    buf[off + row] = val;
                }
                let (off, _) = sh.part(Part::P);
                buf[off + base..off + base + tokens].copy_from_slice(prow);
            }
        }
    }
    requant_all(o, SH_O, I8N, "O")?;
    for h in 0..sh.q_heads {
        for t in 0..tokens {
            for i in 0..dh {
                o8[t * d_w + h * dh + i] = o[(h * tokens + t) * dh + i];
            }
        }
    }

    matmul_out_in(tokens, o8, w.wo, d_w, d_w, ao)?;
    requant_all(ao, sh.sh_ao, I16, "AO")?;

    for idx in 0..sh.x_len() {
        x1[idx] = add(shl(x[idx], SH_X1, "residual 1")?, shl(ao[idx], SH_A1, "residual 1")?, "residual 1")?;
    }
    requant_all(x1, SH_R1, I16, "residual 1")?;

    rms_norm(sh, x1, w.gamma_m, sh.norm_cn_m, nm, nm_dd)?;
    put(&mut trace, sh, Part::O8, o8);
    put(&mut trace, sh, Part::Ao8, ao);
    put(&mut trace, sh, Part::Xres1, x1);
    put(&mut trace, sh, Part::NmDd, nm_dd);
    put(&mut trace, sh, Part::NmY, nm);

    matmul_in_out(tokens, nm, w.wg_t, d_w, f_w, g)?;
    requant_all(g, SH_G, I8, "FFN gate")?;
    matmul_in_out(tokens, nm, w.wu_t, d_w, f_w, u)?;
    requant_all(u, SH_U, I16, "FFN up")?;
    for idx in 0..sh.ff_len() {
        let slot = usize::try_from(g[idx] + 128).map_err(|_| KernelError::Range("FFN gate"))?;
        a[idx] = i64::from(*tab.act.get(slot).ok_or(KernelError::Range("FFN gate"))?);
    }
    for idx in 0..sh.ff_len() {
        hh[idx] = mul(a[idx], u[idx], "FFN product")?;
    }
    requant_all(hh, SH_H, I16, "FFN product")?;
    matmul_in_out(tokens, hh, w.wd_t, f_w, d_w, z)?;
    requant_all(z, SH_Z, I16, "FFN down")?;

    for idx in 0..sh.x_len() {
        x2[idx] = add(shl(x1[idx], SH_X2, "residual 2")?, shl(z[idx], SH_Z2, "residual 2")?, "residual 2")?;
    }
    requant_all(x2, SH_R2, I16, "residual 2")?;

    for (dst, src) in out.iter_mut().zip(x2.iter()) {
        *dst = i16::try_from(*src).map_err(|_| KernelError::Range("residual 2"))?;
    }
    put(&mut trace, sh, Part::G8, g);
    put(&mut trace, sh, Part::A16, a);
    put(&mut trace, sh, Part::U16, u);
    put(&mut trace, sh, Part::H16, hh);
    put(&mut trace, sh, Part::Z16, z);
    put(&mut trace, sh, Part::Xres2, x2);
    Ok(())
}

#[cfg(test)]
mod tests;

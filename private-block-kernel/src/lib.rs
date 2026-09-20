//! Portable exact-integer kernel for ONE fixed ZK60 T32 transformer block.
//!
//! This is computation only, NOT a proof and NOT a privacy claim. It is meant
//! to run unchanged natively and inside a zkVM guest, so it is `no_std`, has
//! no dependencies, no allocation, no floats, no I/O, no GPU/rayon and no
//! proof-library coupling.
//!
//! Shape and calibration are fixed to the approved public fixture
//! (`hashline::causal_oracle::public_synthetic_registration`): T32 d16 f16,
//! H2 Hkv1 dh8. The result must equal `FixedCausalOracle::build` exactly,
//! including WHICH site refuses ([`KernelError`] `Range`/`Relation` carry the
//! oracle's `OracleError` site strings verbatim).
//!
//! Inputs:
//! * PRIVATE activation `input: [i16; 512]` (row-major `(t, d)`); every i16
//!   is accepted as input, refusals only happen at downstream range sites.
//! * PUBLIC weights ([`PublicWeights`]) and PUBLIC tables ([`PublicTables`]),
//!   shape-checked and structurally validated here. Structural validation
//!   is NOT authentication: the caller (host or guest image) MUST
//!   authenticate the exact weight words (against the approved commitments)
//!   and the exact table words (against the registered rope/exp/activation
//!   digests or constants baked into the trusted image) before trusting
//!   any output of this kernel.
//!
//! Arithmetic rules: every intermediate is recomputed here (nothing claimed
//! by a caller is consumed), i64 with checked add/mul/shift (an overflow is a
//! [`KernelError::Overflow`], never a wrap), checked narrowing, and NO
//! clamping: an out-of-class value is a refusal, never a saturated result.
//!
//! The optional [`Trace`] holds secret intermediate activations and exists
//! for native parity tests only. Do not print, publish or hash it as a
//! private-proof artifact. Nothing in this crate prints anything.

#![no_std]
#![forbid(unsafe_code)]

#[cfg(test)]
extern crate std;

pub mod shaped;

use core::fmt;

pub const T: usize = 32;
pub const D: usize = 16;
pub const F: usize = 16;
pub const H: usize = 2;
pub const HKV: usize = 1;
pub const DH: usize = 8;
pub const KV: usize = HKV * DH;
pub const HALF: usize = DH / 2;
pub const X_LEN: usize = T * D;
pub const KV_LEN: usize = T * KV;
pub const FF_LEN: usize = T * F;
pub const ROPE_LEN: usize = T * HALF;
pub const SCORE_LEN: usize = H * T * T;
pub const ROWS: usize = H * T;

/// Fixed public calibration, copied from `public_synthetic_registration`.
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
/// display. `Range`/`Relation` sites use the oracle's exact strings.
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

pub(crate) type Res<V> = Result<V, KernelError>;

fn fixed<V: Copy, const N: usize>(s: &[V], site: &'static str) -> Res<[V; N]> {
    <[V; N]>::try_from(s).map_err(|_| KernelError::Shape(site))
}

/// PUBLIC block weights. Attention matrices are (output, input) row-major,
/// FFN matrices are (input, output) row-major, exactly as
/// `causal_oracle::PublicBlockWeights`. Any i8 word (including -128) is
/// accepted; the caller must authenticate the words.
#[derive(Clone)]
pub struct PublicWeights {
    wq: [i8; D * D],
    wk: [i8; KV * D],
    wv: [i8; KV * D],
    wo: [i8; D * D],
    gamma_a: [i8; D],
    gamma_m: [i8; D],
    wg_t: [i8; D * F],
    wu_t: [i8; D * F],
    wd_t: [i8; F * D],
}

impl PublicWeights {
    /// The same words as borrowed slices, for the shape-driven path.
    pub fn as_ref(&self) -> shaped::WeightsRef<'_> {
        shaped::WeightsRef {
            wq: &self.wq,
            wk: &self.wk,
            wv: &self.wv,
            wo: &self.wo,
            gamma_a: &self.gamma_a,
            gamma_m: &self.gamma_m,
            wg_t: &self.wg_t,
            wu_t: &self.wu_t,
            wd_t: &self.wd_t,
        }
    }

    /// Shape-checked construction (256,128,128,256,16,16,256,256,256 words).
    #[allow(clippy::too_many_arguments)]
    pub fn from_slices(
        wq: &[i8],
        wk: &[i8],
        wv: &[i8],
        wo: &[i8],
        gamma_a: &[i8],
        gamma_m: &[i8],
        wg_t: &[i8],
        wu_t: &[i8],
        wd_t: &[i8],
    ) -> Res<Self> {
        Ok(Self {
            wq: fixed(wq, "wq")?,
            wk: fixed(wk, "wk")?,
            wv: fixed(wv, "wv")?,
            wo: fixed(wo, "wo")?,
            gamma_a: fixed(gamma_a, "gamma_a")?,
            gamma_m: fixed(gamma_m, "gamma_m")?,
            wg_t: fixed(wg_t, "wg_t")?,
            wu_t: fixed(wu_t, "wu_t")?,
            wd_t: fixed(wd_t, "wd_t")?,
        })
    }
}

/// PUBLIC lookup tables: RoPE cos/sin (`T x DH/2` row-major at 2^-F_RO),
/// the exp-neg table (256 entries at 2^-F_E) and the int16-output activation
/// (SiLU) table indexed by `gate + 128`. The kernel never generates them
/// (that needs floats); it checks shape and structure only. Structure is NOT
/// provenance: authenticate these words against the trusted fixture.
#[derive(Clone)]
pub struct PublicTables {
    rope_cos: [i64; ROPE_LEN],
    rope_sin: [i64; ROPE_LEN],
    exp: [i64; 256],
    act: [i16; 256],
}

impl PublicTables {
    /// The same words as borrowed slices, for the shape-driven path.
    pub fn as_ref(&self) -> shaped::TablesRef<'_> {
        shaped::TablesRef { rope_cos: &self.rope_cos, rope_sin: &self.rope_sin, exp: &self.exp, act: &self.act }
    }

    pub fn from_slices(rope_cos: &[i64], rope_sin: &[i64], exp: &[i64], act: &[i16]) -> Res<Self> {
        let tab = Self {
            rope_cos: fixed(rope_cos, "rope_cos")?,
            rope_sin: fixed(rope_sin, "rope_sin")?,
            exp: fixed(exp, "exp")?,
            act: fixed(act, "act")?,
        };
        let one_ro = 1i64 << F_RO;
        if tab.rope_cos.iter().chain(tab.rope_sin.iter()).any(|v| !(-one_ro..=one_ro).contains(v)) {
            return Err(KernelError::Table("rope range"));
        }
        if tab.rope_cos[..HALF].iter().any(|c| *c != one_ro) || tab.rope_sin[..HALF].iter().any(|s| *s != 0) {
            return Err(KernelError::Table("rope position 0"));
        }
        let one_e = 1i64 << F_E;
        if tab.exp[0] != one_e {
            return Err(KernelError::Table("exp E[0]"));
        }
        if tab.exp.iter().any(|e| !(0..=one_e).contains(e)) {
            return Err(KernelError::Table("exp range"));
        }
        if tab.exp.windows(2).any(|w| w[0] < w[1]) {
            return Err(KernelError::Table("exp monotone"));
        }
        Ok(tab)
    }
}

/// Secret intermediates for native parity tests only (no Debug on purpose).
/// Names and layouts follow the oracle's `AttnWitness`/`V3Witness`/`Resid2`:
/// `s8` and `p` are head-major `(h, t, j)` over ALL j (s8 unmasked; p zero
/// off the causal support), `m_row`/`arg`/`sum` are `(h, t)` where `arg` is
/// the index of the oracle's one-hot `zsel`, everything else row-major `(t, *)`.
pub struct Trace {
    pub na_dd: [i64; T],
    pub na_y: [i64; X_LEN],
    pub q8: [i64; X_LEN],
    pub k8: [i64; KV_LEN],
    pub v8: [i64; KV_LEN],
    pub qr8: [i64; X_LEN],
    pub kr8: [i64; KV_LEN],
    pub s8: [i64; SCORE_LEN],
    pub m_row: [i64; ROWS],
    pub arg: [i64; ROWS],
    pub sum: [i64; ROWS],
    pub p: [i64; SCORE_LEN],
    pub o8: [i64; X_LEN],
    pub ao8: [i64; X_LEN],
    pub xres1: [i64; X_LEN],
    pub nm_dd: [i64; T],
    pub nm_y: [i64; X_LEN],
    pub g8: [i64; FF_LEN],
    pub a16: [i64; FF_LEN],
    pub u16: [i64; FF_LEN],
    pub h16: [i64; FF_LEN],
    pub z16: [i64; X_LEN],
    pub xres2: [i64; X_LEN],
}

impl Trace {
    pub const fn zeroed() -> Self {
        Self {
            na_dd: [0; T],
            na_y: [0; X_LEN],
            q8: [0; X_LEN],
            k8: [0; KV_LEN],
            v8: [0; KV_LEN],
            qr8: [0; X_LEN],
            kr8: [0; KV_LEN],
            s8: [0; SCORE_LEN],
            m_row: [0; ROWS],
            arg: [0; ROWS],
            sum: [0; ROWS],
            p: [0; SCORE_LEN],
            o8: [0; X_LEN],
            ao8: [0; X_LEN],
            xres1: [0; X_LEN],
            nm_dd: [0; T],
            nm_y: [0; X_LEN],
            g8: [0; FF_LEN],
            a16: [0; FF_LEN],
            u16: [0; FF_LEN],
            h16: [0; FF_LEN],
            z16: [0; X_LEN],
            xres2: [0; X_LEN],
        }
    }

    /// Copy the shape-driven run's flat trace buffer into the fixed fields.
    /// Parts the run never reached are still zero, so a refusal leaves a
    /// partial trace exactly as the fixed path always did.
    fn load(&mut self, sh: &shaped::Shape, buf: &[i64]) {
        use shaped::Part;
        let get = |p: Part| {
            let (o, n) = sh.part(p);
            &buf[o..o + n]
        };
        self.na_dd.copy_from_slice(get(Part::NaDd));
        self.na_y.copy_from_slice(get(Part::NaY));
        self.q8.copy_from_slice(get(Part::Q8));
        self.k8.copy_from_slice(get(Part::K8));
        self.v8.copy_from_slice(get(Part::V8));
        self.qr8.copy_from_slice(get(Part::Qr8));
        self.kr8.copy_from_slice(get(Part::Kr8));
        self.s8.copy_from_slice(get(Part::S8));
        self.m_row.copy_from_slice(get(Part::MRow));
        self.arg.copy_from_slice(get(Part::Arg));
        self.sum.copy_from_slice(get(Part::Sum));
        self.p.copy_from_slice(get(Part::P));
        self.o8.copy_from_slice(get(Part::O8));
        self.ao8.copy_from_slice(get(Part::Ao8));
        self.xres1.copy_from_slice(get(Part::Xres1));
        self.nm_dd.copy_from_slice(get(Part::NmDd));
        self.nm_y.copy_from_slice(get(Part::NmY));
        self.g8.copy_from_slice(get(Part::G8));
        self.a16.copy_from_slice(get(Part::A16));
        self.u16.copy_from_slice(get(Part::U16));
        self.h16.copy_from_slice(get(Part::H16));
        self.z16.copy_from_slice(get(Part::Z16));
        self.xres2.copy_from_slice(get(Part::Xres2));
    }
}

// ---------------------------------------------------------------- scalars

pub(crate) fn add(a: i64, b: i64, site: &'static str) -> Res<i64> {
    a.checked_add(b).ok_or(KernelError::Overflow(site))
}
pub(crate) fn sub(a: i64, b: i64, site: &'static str) -> Res<i64> {
    a.checked_sub(b).ok_or(KernelError::Overflow(site))
}
pub(crate) fn mul(a: i64, b: i64, site: &'static str) -> Res<i64> {
    a.checked_mul(b).ok_or(KernelError::Overflow(site))
}
/// Exact `v * 2^s` (never a wrapping shift).
pub(crate) fn shl(v: i64, s: u32, site: &'static str) -> Res<i64> {
    if s >= 63 {
        return Err(KernelError::Overflow(site));
    }
    mul(v, 1i64 << s, site)
}

/// Requantization at a SIGNED shift, as `export_v3::requant_round`:
/// `s > 0`: `y = floor((acc + 2^(s-1)) / 2^s)` (round to nearest, ties toward
/// +inf, remainder `acc - y 2^s` in `[-2^(s-1), 2^(s-1))`);
/// `s <= 0`: exact up-scaling `y = acc * 2^-s`.
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

/// Floor integer square root, integer-only (no float seed).
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

// ---------------------------------------------------------------- tensors

/// `out[t, j] = sum_i x[t, i] * w[j, i]` with `w` stored (output, input),
/// over the toy's `T` rows ([`shaped::matmul_out_in`] at any row count).
pub fn matmul_out_in(x: &[i64], w: &[i8], inner: usize, outer: usize, out: &mut [i64]) -> Res<()> {
    shaped::matmul_out_in(T, x, w, inner, outer, out)
}

/// `out[t, j] = sum_i x[t, i] * w[i, j]` with `w` stored (input, output),
/// over the toy's `T` rows ([`shaped::matmul_in_out`] at any row count).
pub fn matmul_in_out(x: &[i64], w: &[i8], inner: usize, outer: usize, out: &mut [i64]) -> Res<()> {
    shaped::matmul_in_out(T, x, w, inner, outer, out)
}

/// Round-mode RMSNorm (norm::rmsnorm_chain with DivMode::Round plus the
/// oracle's `checked_norm` refusals), per row:
/// `D = isqrt(sum x^2 + Ceps)`, `y = floor((2 x g Cn + D 2^tn) / (D 2^(tn+1)))`.
#[cfg(test)]
fn rms_norm(x: &[i64; X_LEN], g: &[i8; D], y: &mut [i64; X_LEN], dd: &mut [i64; T]) -> Res<()> {
    shaped::rms_norm(&shaped::Shape::toy(), x, g, y, dd)
}

/// Half-split RoPE (pairs `i` and `i + DH/2`) over `heads` heads per row.
#[cfg(test)]
fn rotate(x: &[i64], heads: usize, tab: &PublicTables, out: &mut [i64]) -> Res<()> {
    shaped::rotate(&shaped::Shape::toy(), x, heads, &tab.as_ref(), out)
}

/// One causal softmax row (query position `t`).
pub struct SoftmaxRow {
    pub max: i64,
    /// First attainer of the maximum (the oracle's one-hot zsel index).
    pub arg: usize,
    pub sum: i64,
    /// `floor(E[max - s_j] 2^F_P / sum)` for `j <= t`, 0 for masked `j > t`.
    pub p: [i64; T],
}

/// Masked max with a strict `>` (first attainer wins; masked positions hold
/// [`calib::MASK`] and can never be chosen over an equal earlier score),
/// exp lookup of `max - s_j`, denominator over `j <= t`, integer quotient.
/// Refusal sites and order match the oracle.
pub fn softmax_row(scores: &[i64; T], t: usize, exp: &[i64; 256]) -> Res<SoftmaxRow> {
    let mut e = [0i64; T];
    let mut p = [0i64; T];
    let (max, arg, sum) = shaped::softmax_row_into(&shaped::Shape::toy(), scores, t, exp, &mut e, &mut p)?;
    Ok(SoftmaxRow { max, arg, sum, p })
}

// ---------------------------------------------------------------- block

/// Length-checked entry for callers holding a slice.
pub fn run_block_slice(
    input: &[i16],
    w: &PublicWeights,
    tab: &PublicTables,
    trace: Option<&mut Trace>,
) -> Res<[i16; X_LEN]> {
    let x: &[i16; X_LEN] = input.try_into().map_err(|_| KernelError::Shape("input"))?;
    run_block(x, w, tab, trace)
}

/// `i64` words of scratch the toy needs, sized from `Shape::toy()`. A guest
/// that must bound its stack calls [`shaped::run_shaped`] with a buffer of
/// its own instead of [`run_block`], which puts both buffers in its frame.
pub const TOY_SCRATCH_I64: usize = shaped::Shape::toy().scratch_len();
/// `i64` words of trace buffer the toy needs.
pub const TOY_TRACE_I64: usize = shaped::Shape::toy().trace_len();

/// Compute the block: norm_a, QKV, RoPE, causal attention, O, residual 1,
/// norm_m, SiLU FFN, residual 2. Returns `xres2` as i16 or the first refusal
/// in the oracle's order. `trace` (tests only) is filled progressively and
/// is partial on refusal.
///
/// This is [`shaped::run_shaped`] at [`shaped::Shape::toy()`] and nothing
/// else: one integer semantics, one refusal order, one set of sites.
pub fn run_block(
    input: &[i16; X_LEN],
    w: &PublicWeights,
    tab: &PublicTables,
    trace: Option<&mut Trace>,
) -> Res<[i16; X_LEN]> {
    const SH: shaped::Shape = shaped::Shape::toy();
    let mut scratch = [0i64; TOY_SCRATCH_I64];
    let mut tbuf = [0i64; TOY_TRACE_I64];
    let mut out = [0i16; X_LEN];
    let want = trace.is_some();
    let res = shaped::run_shaped(&SH, input, &w.as_ref(), &tab.as_ref(), &mut scratch, if want { Some(&mut tbuf[..]) } else { None }, &mut out);
    if let Some(tr) = trace {
        tr.load(&SH, &tbuf);
    }
    res?;
    Ok(out)
}

#[cfg(test)]
mod shaped_tests;
#[cfg(test)]
mod tests;

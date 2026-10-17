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

/// Attention int8 subset [-127,127] (excludes -128, as the oracle does).
const I8N: (i64, i64) = (-127, 127);
const I8: (i64, i64) = (-128, 127);
const I16: (i64, i64) = (-32768, 32767);

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

type Res<V> = Result<V, KernelError>;

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
}

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

/// Requantize every element in place; any result outside `[lo, hi]` refuses
/// the whole site (no clamping).
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

/// `out[t, j] = sum_i x[t, i] * w[j, i]` with `w` stored (output, input).
pub fn matmul_out_in(x: &[i64], w: &[i8], inner: usize, outer: usize, out: &mut [i64]) -> Res<()> {
    if x.len() != T * inner || w.len() != inner * outer || out.len() != T * outer {
        return Err(KernelError::Shape("matmul_out_in"));
    }
    for t in 0..T {
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
pub fn matmul_in_out(x: &[i64], w: &[i8], inner: usize, outer: usize, out: &mut [i64]) -> Res<()> {
    if x.len() != T * inner || w.len() != inner * outer || out.len() != T * outer {
        return Err(KernelError::Shape("matmul_in_out"));
    }
    for t in 0..T {
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

/// Round-mode RMSNorm (norm::rmsnorm_chain with DivMode::Round plus the
/// oracle's `checked_norm` refusals), per row:
/// `D = isqrt(sum x^2 + Ceps)`, `y = floor((2 x g Cn + D 2^tn) / (D 2^(tn+1)))`.
fn rms_norm(x: &[i64; X_LEN], g: &[i8; D], y: &mut [i64; X_LEN], dd: &mut [i64; T]) -> Res<()> {
    const SITE: &str = "norm quotient/remainder";
    let wrho = 1i64 << NORM_WRHO;
    for t in 0..T {
        let row = &x[t * D..(t + 1) * D];
        let mut ss = NORM_CEPS;
        for v in row {
            ss = add(ss, mul(*v, *v, "norm")?, "norm")?;
        }
        let ss = u64::try_from(ss).map_err(|_| KernelError::Range("norm denominator"))?;
        let d = i64::try_from(isqrt(ss)).map_err(|_| KernelError::Overflow("norm"))?;
        let dv = shl(d, NORM_TN, "norm")?;
        let den = mul(dv, 2, "norm")?;
        if den <= 0 {
            return Err(KernelError::Range("norm denominator"));
        }
        for i in 0..D {
            let num = add(mul(mul(mul(2, row[i], "norm")?, i64::from(g[i]), "norm")?, NORM_CN, "norm")?, dv, "norm")?;
            let q = num.div_euclid(den);
            let rho = num.rem_euclid(den);
            let sigma = den - 1 - rho;
            if !(I8N.0..=I8N.1).contains(&q) || rho >= wrho || sigma >= wrho {
                return Err(KernelError::Range(SITE));
            }
            y[t * D + i] = q;
        }
        dd[t] = d;
    }
    Ok(())
}

/// Half-split RoPE (pairs `i` and `i + DH/2`) over `heads` heads per row.
fn rotate(x: &[i64], heads: usize, tab: &PublicTables, out: &mut [i64]) -> Res<()> {
    let width = heads * DH;
    if x.len() != T * width || out.len() != T * width {
        return Err(KernelError::Shape("rope"));
    }
    for t in 0..T {
        for h in 0..heads {
            let base = t * width + h * DH;
            for i in 0..HALF {
                let (c, s) = (tab.rope_cos[t * HALF + i], tab.rope_sin[t * HALF + i]);
                let (a, b) = (x[base + i], x[base + HALF + i]);
                out[base + i] = sub(mul(c, a, "rope")?, mul(s, b, "rope")?, "rope")?;
                out[base + HALF + i] = add(mul(s, a, "rope")?, mul(c, b, "rope")?, "rope")?;
            }
        }
    }
    Ok(())
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
    if t >= T {
        return Err(KernelError::Shape("softmax row"));
    }
    let masked = |j: usize| if j <= t { scores[j] } else { MASK };
    let mut best = i64::MIN;
    let mut arg = 0;
    for j in 0..T {
        let s = masked(j);
        if s > best {
            best = s;
            arg = j;
        }
    }
    if arg > t {
        return Err(KernelError::Relation("causal maximum attainment"));
    }
    let mut e = [0i64; T];
    let mut total = 0i64;
    for j in 0..T {
        let delta = sub(best, masked(j), "softmax")?;
        if !(0..256).contains(&delta) {
            return Err(KernelError::Range("exp difference"));
        }
        e[j] = exp[delta as usize];
        if j <= t {
            total = add(total, e[j], "softmax")?;
        }
    }
    if !((1i64 << F_E)..=((T as i64) << F_E)).contains(&total) {
        return Err(KernelError::Relation("softmax denominator"));
    }
    let mut p = [0i64; T];
    for j in 0..T {
        let (q, rho) = if j <= t {
            let num = shl(e[j], F_P, "softmax")?;
            (num / total, num % total)
        } else {
            (0, 0)
        };
        let sigma = total - 1 - rho;
        if !(0..1i64 << WRHO_S).contains(&sigma) || !(0..=1i64 << F_P).contains(&q) {
            return Err(KernelError::Range("softmax quotient/remainder"));
        }
        p[j] = q;
    }
    Ok(SoftmaxRow { max: best, arg, sum: total, p })
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

/// Compute the block: norm_a, QKV, RoPE, causal attention, O, residual 1,
/// norm_m, SiLU FFN, residual 2. Returns `xres2` as i16 or the first refusal
/// in the oracle's order. `trace` (tests only) is filled progressively and
/// is partial on refusal.
pub fn run_block(
    input: &[i16; X_LEN],
    w: &PublicWeights,
    tab: &PublicTables,
    mut trace: Option<&mut Trace>,
) -> Res<[i16; X_LEN]> {
    let mut x = [0i64; X_LEN];
    for (d, s) in x.iter_mut().zip(input.iter()) {
        *d = i64::from(*s);
    }

    let mut na = [0i64; X_LEN];
    let mut na_dd = [0i64; T];
    rms_norm(&x, &w.gamma_a, &mut na, &mut na_dd)?;

    let mut q = [0i64; X_LEN];
    let mut k = [0i64; KV_LEN];
    let mut v = [0i64; KV_LEN];
    matmul_out_in(&na, &w.wq, D, D, &mut q)?;
    matmul_out_in(&na, &w.wk, D, KV, &mut k)?;
    matmul_out_in(&na, &w.wv, D, KV, &mut v)?;
    requant_all(&mut q, SH_Q, I8N, "Q")?;
    requant_all(&mut k, SH_K, I8N, "K")?;
    requant_all(&mut v, SH_V, I8N, "V")?;

    let mut qr = [0i64; X_LEN];
    let mut kr = [0i64; KV_LEN];
    rotate(&q, H, tab, &mut qr)?;
    rotate(&k, HKV, tab, &mut kr)?;
    requant_all(&mut qr, SH_QR, I8N, "QR")?;
    requant_all(&mut kr, SH_KR, I8N, "KR")?;

    // Scores over ALL (t, j), so an out-of-range masked score still refuses.
    let group = H / HKV;
    let mut s = [0i64; SCORE_LEN];
    for h in 0..H {
        let kvo = (h / group) * DH;
        for t in 0..T {
            for j in 0..T {
                let mut acc = 0i64;
                for i in 0..DH {
                    acc = add(acc, mul(qr[t * D + h * DH + i], kr[j * KV + kvo + i], "score")?, "score")?;
                }
                s[(h * T + t) * T + j] = acc;
            }
        }
    }
    requant_all(&mut s, SH_S, I8N, "score")?;
    if let Some(tr) = trace.as_deref_mut() {
        tr.na_dd = na_dd;
        tr.na_y = na;
        tr.q8 = q;
        tr.k8 = k;
        tr.v8 = v;
        tr.qr8 = qr;
        tr.kr8 = kr;
        tr.s8 = s;
    }

    // Head-major (h, t, i) accumulators, as the oracle's oacc.
    let mut o = [0i64; H * T * DH];
    for h in 0..H {
        let kvo = (h / group) * DH;
        for t in 0..T {
            let row: &[i64; T] = s[(h * T + t) * T..(h * T + t + 1) * T]
                .try_into()
                .map_err(|_| KernelError::Shape("score row"))?;
            let sm = softmax_row(row, t, &tab.exp)?;
            for i in 0..DH {
                let mut acc = 0i64;
                for j in 0..=t {
                    acc = add(acc, mul(sm.p[j], v[j * KV + kvo + i], "PV")?, "PV")?;
                }
                o[(h * T + t) * DH + i] = acc;
            }
            if let Some(tr) = trace.as_deref_mut() {
                tr.m_row[h * T + t] = sm.max;
                tr.arg[h * T + t] = sm.arg as i64;
                tr.sum[h * T + t] = sm.sum;
                tr.p[(h * T + t) * T..(h * T + t + 1) * T].copy_from_slice(&sm.p);
            }
        }
    }
    requant_all(&mut o, SH_O, I8N, "O")?;
    let mut o8 = [0i64; X_LEN];
    for h in 0..H {
        for t in 0..T {
            for i in 0..DH {
                o8[t * D + h * DH + i] = o[(h * T + t) * DH + i];
            }
        }
    }

    let mut ao = [0i64; X_LEN];
    matmul_out_in(&o8, &w.wo, D, D, &mut ao)?;
    requant_all(&mut ao, SH_AO, I16, "AO")?;

    let mut x1 = [0i64; X_LEN];
    for idx in 0..X_LEN {
        x1[idx] = add(shl(x[idx], SH_X1, "residual 1")?, shl(ao[idx], SH_A1, "residual 1")?, "residual 1")?;
    }
    requant_all(&mut x1, SH_R1, I16, "residual 1")?;

    let mut nm = [0i64; X_LEN];
    let mut nm_dd = [0i64; T];
    rms_norm(&x1, &w.gamma_m, &mut nm, &mut nm_dd)?;
    if let Some(tr) = trace.as_deref_mut() {
        tr.o8 = o8;
        tr.ao8 = ao;
        tr.xres1 = x1;
        tr.nm_dd = nm_dd;
        tr.nm_y = nm;
    }

    let mut g = [0i64; FF_LEN];
    matmul_in_out(&nm, &w.wg_t, D, F, &mut g)?;
    requant_all(&mut g, SH_G, I8, "FFN gate")?;
    let mut u = [0i64; FF_LEN];
    matmul_in_out(&nm, &w.wu_t, D, F, &mut u)?;
    requant_all(&mut u, SH_U, I16, "FFN up")?;
    let mut a = [0i64; FF_LEN];
    for idx in 0..FF_LEN {
        let slot = usize::try_from(g[idx] + 128).map_err(|_| KernelError::Range("FFN gate"))?;
        a[idx] = i64::from(*tab.act.get(slot).ok_or(KernelError::Range("FFN gate"))?);
    }
    let mut hh = [0i64; FF_LEN];
    for idx in 0..FF_LEN {
        hh[idx] = mul(a[idx], u[idx], "FFN product")?;
    }
    requant_all(&mut hh, SH_H, I16, "FFN product")?;
    let mut z = [0i64; X_LEN];
    matmul_in_out(&hh, &w.wd_t, F, D, &mut z)?;
    requant_all(&mut z, SH_Z, I16, "FFN down")?;

    let mut x2 = [0i64; X_LEN];
    for idx in 0..X_LEN {
        x2[idx] = add(shl(x1[idx], SH_X2, "residual 2")?, shl(z[idx], SH_Z2, "residual 2")?, "residual 2")?;
    }
    requant_all(&mut x2, SH_R2, I16, "residual 2")?;

    let mut out = [0i16; X_LEN];
    for (dst, src) in out.iter_mut().zip(x2.iter()) {
        *dst = i16::try_from(*src).map_err(|_| KernelError::Range("residual 2"))?;
    }
    if let Some(tr) = trace {
        tr.g8 = g;
        tr.a16 = a;
        tr.u16 = u;
        tr.h16 = hh;
        tr.z16 = z;
        tr.xres2 = x2;
    }
    Ok(out)
}

#[cfg(test)]
mod tests;

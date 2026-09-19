//! EXPERIMENTAL exact-integer kernel for a fixed SYNTHETIC ZK60 token model:
//! embedding gather -> block 0 -> block 1 -> final RMS norm (last row) ->
//! int8 output head -> greedy next token.
//!
//! This is computation for a future, separately versioned guest image. It is
//! NOT a trained model, NOT a proof, NOT a privacy claim, NOT 125M/8B
//! coverage and NOT MVP completion. `no_std`, no allocation, no floats, no
//! I/O, `unsafe` forbidden; the only dependency is the unchanged
//! `private-block-kernel`, which performs both block computations.
//!
//! Fixed shape: context exactly [`CTX`] = 32 PRIVATE token IDs (no padding,
//! no empty prompt, no truncation), vocabulary [`VOCAB`] = 32, d16. All 32
//! positions use the block kernel's zero-based RoPE tables. There is no KV
//! cache, no sampling, no EOS convention and no multi-token decoding here:
//! the output is ONE greedy next-token ID for the full fixed context.
//!
//! PUBLIC inputs ([`PublicModel`]): signed-i16 embeddings `(vocab, d)`
//! row-major, two independently supplied blocks (weights + lookup tables),
//! final-norm gamma (i8, d16) and signed-int8 head `(vocab, d)` row-major.
//! Construction checks shape and table structure only. That is NOT
//! authentication: the caller (host or guest image) MUST authenticate every
//! public word against approved commitments or trusted-image constants.
//!
//! Arithmetic: every value is recomputed from the tokens and public words;
//! nothing claimed by a caller (activations, logits, token) is consumed.
//! Checked i64 arithmetic, checked narrowing, no clamping, refusal on range.
//! Greedy selection is a strict `>` scan in increasing vocabulary index, so
//! ties resolve to the LOWEST index. Control flow depends on secret data
//! (argmax, refusals); nothing here claims constant time.
//!
//! [`ModelTrace`] holds secret intermediates for native tests only. It has
//! no `Debug`; nothing in this crate prints anything.

#![no_std]
#![forbid(unsafe_code)]

use core::fmt;

pub use private_block_kernel::{KernelError, PublicTables, PublicWeights, D, F, ROPE_LEN, T, X_LEN};
use private_block_kernel::{calib, isqrt, run_block};

pub mod synthetic;

/// Fixed context length: exactly one token per block-kernel position.
pub const CTX: usize = T;
/// Fixed vocabulary size.
pub const VOCAB: usize = 32;
/// Embedding / head words, `(vocab, d)` row-major.
pub const TABLE_LEN: usize = VOCAB * D;
/// Number of sequential blocks.
pub const LAYERS: usize = 2;

/// Refusal. Carries only static site names and a layer index (never data,
/// never a token position or value), so it is safe to display.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ModelError {
    /// Wrong length of a public component or of the private token slice.
    Shape(&'static str),
    /// Some private token ID is outside `0..VOCAB` (which one is not said).
    Token,
    /// Block `layer` (0 or 1) refused at construction or at run time.
    Layer(u8, KernelError),
    /// Final norm or head refusal.
    Final(KernelError),
}

impl fmt::Display for ModelError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Shape(s) => write!(f, "model shape refusal: {s}"),
            Self::Token => write!(f, "model token refusal: token id outside vocabulary"),
            Self::Layer(l, e) => write!(f, "model block {l} refusal: {e}"),
            Self::Final(e) => write!(f, "model final norm/head refusal: {e}"),
        }
    }
}

type Res<V> = Result<V, ModelError>;

fn fixed<V: Copy, const N: usize>(s: &[V], site: &'static str) -> Res<[V; N]> {
    <[V; N]>::try_from(s).map_err(|_| ModelError::Shape(site))
}

/// One PUBLIC block: kernel weights plus its own lookup tables.
#[derive(Clone)]
pub struct PublicBlock {
    pub weights: PublicWeights,
    pub tables: PublicTables,
}

/// Raw PUBLIC words of one block, in the block kernel's layouts (attention
/// (out, in), FFN (in, out)). A convenience for building a [`PublicBlock`].
#[derive(Clone)]
pub struct RawBlock {
    pub wq: [i8; 256],
    pub wk: [i8; 128],
    pub wv: [i8; 128],
    pub wo: [i8; 256],
    pub gamma_a: [i8; D],
    pub gamma_m: [i8; D],
    pub wg_t: [i8; D * F],
    pub wu_t: [i8; D * F],
    pub wd_t: [i8; F * D],
    pub rope_cos: [i64; ROPE_LEN],
    pub rope_sin: [i64; ROPE_LEN],
    pub exp: [i64; 256],
    pub act: [i16; 256],
}

impl RawBlock {
    pub fn to_block(&self) -> Result<PublicBlock, KernelError> {
        Ok(PublicBlock {
            weights: PublicWeights::from_slices(
                &self.wq,
                &self.wk,
                &self.wv,
                &self.wo,
                &self.gamma_a,
                &self.gamma_m,
                &self.wg_t,
                &self.wu_t,
                &self.wd_t,
            )?,
            tables: PublicTables::from_slices(&self.rope_cos, &self.rope_sin, &self.exp, &self.act)?,
        })
    }
}

/// Raw PUBLIC words of the whole model.
#[derive(Clone)]
pub struct RawModel {
    pub embed: [i16; TABLE_LEN],
    pub blocks: [RawBlock; LAYERS],
    pub gamma_f: [i8; D],
    pub head: [i8; TABLE_LEN],
}

impl RawModel {
    pub fn build(&self) -> Res<PublicModel> {
        PublicModel::from_parts(
            &self.embed,
            self.blocks[0].to_block().map_err(|e| ModelError::Layer(0, e))?,
            self.blocks[1].to_block().map_err(|e| ModelError::Layer(1, e))?,
            &self.gamma_f,
            &self.head,
        )
    }
}

/// PUBLIC model components (shape-checked, NOT authenticated).
#[derive(Clone)]
pub struct PublicModel {
    embed: [i16; TABLE_LEN],
    blocks: [PublicBlock; LAYERS],
    gamma_f: [i8; D],
    head: [i8; TABLE_LEN],
}

impl PublicModel {
    /// `embed`: i16 `(vocab, d)`, 512 words; `gamma_f`: i8, 16 words;
    /// `head`: i8 `(vocab, d)`, 512 words. Blocks run in argument order.
    pub fn from_parts(embed: &[i16], block0: PublicBlock, block1: PublicBlock, gamma_f: &[i8], head: &[i8]) -> Res<Self> {
        Ok(Self {
            embed: fixed(embed, "embed")?,
            blocks: [block0, block1],
            gamma_f: fixed(gamma_f, "gamma_f")?,
            head: fixed(head, "head")?,
        })
    }
}

/// Secret intermediates for native tests only (no Debug on purpose). Filled
/// progressively; partial on refusal.
pub struct ModelTrace {
    /// Embedding gather, `(t, d)` row-major (block 0 input).
    pub embedded: [i16; X_LEN],
    /// Block 0 output = block 1 input.
    pub layer0: [i16; X_LEN],
    /// Block 1 output; its last row feeds the final norm.
    pub layer1: [i16; X_LEN],
    /// Final norm denominator `isqrt(sum x^2 + Ceps)` of the last row.
    pub final_dd: i64,
    /// Final norm output of the last row.
    pub final_y: [i64; D],
    /// Head logits of the last row.
    pub logits: [i64; VOCAB],
}

impl ModelTrace {
    pub const fn zeroed() -> Self {
        Self {
            embedded: [0; X_LEN],
            layer0: [0; X_LEN],
            layer1: [0; X_LEN],
            final_dd: 0,
            final_y: [0; D],
            logits: [0; VOCAB],
        }
    }
}

fn kadd(a: i64, b: i64, site: &'static str) -> Res<i64> {
    a.checked_add(b).ok_or(ModelError::Final(KernelError::Overflow(site)))
}
fn kmul(a: i64, b: i64, site: &'static str) -> Res<i64> {
    a.checked_mul(b).ok_or(ModelError::Final(KernelError::Overflow(site)))
}

/// Final RMS norm of ONE row with exactly the block kernel's fixed norm
/// calibration and refusal rules (`calib::NORM_*`, round mode):
/// `D = isqrt(sum x^2 + Ceps)`, `den = 2 D 2^tn`,
/// `y = floor((2 x g Cn + D 2^tn) / den)` with remainder `rho` and
/// `sigma = den - 1 - rho` both `< 2^wrho` and `y` in `[-127, 127]`.
/// Returns `(D, y)`.
pub fn final_norm_row(x: &[i16; D], g: &[i8; D]) -> Res<(i64, [i64; D])> {
    const SITE: &str = "final norm quotient/remainder";
    let mut ss = calib::NORM_CEPS;
    for v in x {
        let v = i64::from(*v);
        ss = kadd(ss, kmul(v, v, "final norm")?, "final norm")?;
    }
    let ss = u64::try_from(ss).map_err(|_| ModelError::Final(KernelError::Range("final norm denominator")))?;
    let d = i64::try_from(isqrt(ss)).map_err(|_| ModelError::Final(KernelError::Overflow("final norm")))?;
    let dv = kmul(d, 1i64 << calib::NORM_TN, "final norm")?;
    let den = kmul(dv, 2, "final norm")?;
    if den <= 0 {
        return Err(ModelError::Final(KernelError::Range("final norm denominator")));
    }
    let wrho = 1i64 << calib::NORM_WRHO;
    let mut y = [0i64; D];
    for i in 0..D {
        let num = kmul(kmul(2, i64::from(x[i]), "final norm")?, i64::from(g[i]), "final norm")?;
        let num = kadd(kmul(num, calib::NORM_CN, "final norm")?, dv, "final norm")?;
        let q = num.div_euclid(den);
        let rho = num.rem_euclid(den);
        let sigma = den - 1 - rho;
        if !(-127..=127).contains(&q) || rho >= wrho || sigma >= wrho {
            return Err(ModelError::Final(KernelError::Range(SITE)));
        }
        y[i] = q;
    }
    Ok((d, y))
}

/// `logits[v] = sum_i y[i] * head[v * D + i]` (head is `(vocab, d)`),
/// exact checked i64.
pub fn head_logits(y: &[i64; D], head: &[i8; TABLE_LEN]) -> Res<[i64; VOCAB]> {
    let mut out = [0i64; VOCAB];
    for (v, o) in out.iter_mut().enumerate() {
        let mut acc = 0i64;
        for i in 0..D {
            acc = kadd(acc, kmul(y[i], i64::from(head[v * D + i]), "head")?, "head")?;
        }
        *o = acc;
    }
    Ok(out)
}

/// Greedy argmax: strict `>` in increasing index, so the LOWEST index among
/// equal maxima wins.
pub fn greedy(logits: &[i64; VOCAB]) -> u32 {
    let mut best = 0usize;
    for v in 1..VOCAB {
        if logits[v] > logits[best] {
            best = v;
        }
    }
    best as u32
}

/// Length-checked entry for a token slice: exactly [`CTX`] tokens.
pub fn next_token_slice(tokens: &[u32], model: &PublicModel, trace: Option<&mut ModelTrace>) -> Res<u32> {
    let t: &[u32; CTX] = tokens.try_into().map_err(|_| ModelError::Shape("tokens"))?;
    next_token_traced(t, model, trace)
}

/// The default API: PRIVATE tokens in, the single greedy next-token ID out.
pub fn next_token(tokens: &[u32; CTX], model: &PublicModel) -> Res<u32> {
    next_token_traced(tokens, model, None)
}

/// As [`next_token`], optionally filling a test-only [`ModelTrace`].
/// All tokens are validated before any computation.
pub fn next_token_traced(tokens: &[u32; CTX], model: &PublicModel, mut trace: Option<&mut ModelTrace>) -> Res<u32> {
    if tokens.iter().any(|t| *t as usize >= VOCAB) {
        return Err(ModelError::Token);
    }
    let mut x = [0i16; X_LEN];
    for (t, tok) in tokens.iter().enumerate() {
        let row = *tok as usize * D;
        x[t * D..(t + 1) * D].copy_from_slice(&model.embed[row..row + D]);
    }
    if let Some(tr) = trace.as_deref_mut() {
        tr.embedded = x;
    }
    for (layer, blk) in model.blocks.iter().enumerate() {
        x = run_block(&x, &blk.weights, &blk.tables, None).map_err(|e| ModelError::Layer(layer as u8, e))?;
        if let Some(tr) = trace.as_deref_mut() {
            if layer == 0 {
                tr.layer0 = x;
            } else {
                tr.layer1 = x;
            }
        }
    }
    let last: &[i16; D] = x[(CTX - 1) * D..].try_into().map_err(|_| ModelError::Shape("last row"))?;
    let (dd, y) = final_norm_row(last, &model.gamma_f)?;
    let logits = head_logits(&y, &model.head)?;
    if let Some(tr) = trace {
        tr.final_dd = dd;
        tr.final_y = y;
        tr.logits = logits;
    }
    Ok(greedy(&logits))
}

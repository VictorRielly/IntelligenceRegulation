//! WORK IN PROGRESS: the private BLOCK module under construction at ONE fixed
//! geometry (T32 / d16 / 2 heads / 1 KV head / head_dim 8 / F16), profile
//! `hashline-zk-mr1/private-block-t32-wip/0`.
//!
//! STATE (read this first). This module is a copy of the accepted private
//! attention component (`crate::private_attention`, untouched) grown into a
//! complete private transformer block — attention, `norm_m`, the SiLU
//! feed-forward and residual 2 in ONE proof with no seam — per
//! `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md`. The
//! whole-block ARGUMENT is present: twenty-three slots, six host groups, the
//! chain `x_in -> ... -> nm -> (g8, u16) -> a16 -> h16 -> z16 -> xres2` closed
//! link by link. What is NOT yet here, and what condition 1 (erratum E-1) of
//! that disposition holds back to ONE later commit: the block profile string,
//! a `BlockPublic` whose single statement digest covers the feed-forward words,
//! the output endpoint on `xres2`, the calibration binding and the
//! `block_output_cannot_be_chosen` tripwire. Until then this profile's OUTPUT
//! ENDPOINT still carries `xres1`, the feed-forward words are absorbed under
//! their own transcript label rather than folded into the statement digest,
//! and the profile is not registered, not accepted and not for use.
//!
//! WHAT IT IS. A custom prover and verifier for the fixed ZK60 block with the
//! exact integer semantics of `private-block-kernel`
//! (`causal_oracle::FixedCausalOracle`): RMSNorm (isqrt, rounded division),
//! Q/K/V projections, half-split RoPE, causal scores, the integer softmax
//! (masked max, exp table, masked row sum, quotient), PV, the output
//! projection, residual 1, the second RMSNorm, the SiLU feed-forward (gate,
//! activation table lookup, up, product, down) and residual 2. The private
//! input `x_in` and the private output are bound to two CALLER-FIXED hiding
//! endpoint commitments by masked equality sumchecks; weights and tables are
//! public (P1).
//!
//! WHAT IT IS NOT. Not an accepted whole-proof privacy result, not an MVP
//! claim, not a registered block format and not a speed claim. Open, and NOT
//! addressed by anything in this module:
//!  * D8 / D11: simulation against caller-fixed endpoint roots with prior
//!    public history (an earlier authentication path or root-child hash query)
//!    is NOT established. One-use consumption of the endpoint owners is
//!    necessary for this opening design; it does not erase prior history and
//!    is not claimed to. The general privacy game is unchanged.
//!  * the forced-challenge counterexample of
//!    ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md: the refusals here are
//!    per-opening (zero coefficients, dependent proximity pair); no joint-rank
//!    refusal across DIFFERENT uses of one commitment exists, because this
//!    profile never opens any commitment twice. It does not repair a two-use
//!    scheme.
//!  * a written simulator / the captured-receipt joint-view gate of the
//!    construction (section 7), the `fp()` reduction bias (D9), and the
//!    composition with norm_m, the FFN and residual 2 (A3 / A4 seams).
//!  * refusals of the integer witness builder depend on the private input,
//!    exactly as the kernel's do.
//!
//! The public receipt carries: three roots, per slot ONE mask-bearing scalar,
//! CFS-masked round messages and pair-masked terminals, the M opening and one
//! opening per hiding commitment. No plaintext input, output, activation,
//! histogram, helper sum or claimed scalar sum is in it.
//!
//! Layout and schedule: `layout.rs`. The shared argument: `argument.rs`.
//! Transcript, ownership and openings: `protocol.rs`. Bounded codec: `wire.rs`.

mod argument;
mod layout;
mod protocol;
mod wire;
mod witness;

#[cfg(test)]
mod parity;
#[cfg(test)]
mod refusals;
#[cfg(test)]
mod tamper;
#[cfg(test)]
mod tests;

use crate::field::Fp;
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::OpeningZk;
use crate::private_seam::{self, PreparedPlane, SeamSpec, Side};
use crate::zk::MaskOpening;
use layout::{D, DH, F, F_E, F_RO, HALF, KV, T};

pub const PROFILE: &[u8] = b"hashline-zk-mr1/private-block-t32-wip/0";
pub use wire::MAX_WIRE_BYTES;
pub const EXPECTED_BYTES: usize = 8 + 32 + 4 + 4 + 2 * 32;

/// The PUBLIC statement: attention weights ((output, input) row-major, as
/// `causal_oracle::PublicBlockWeights`), the norm gain and the three public
/// tables. Shape and structure are checked; structure is NOT provenance: the
/// caller must authenticate these words (approved model, registered table
/// digests) before trusting a verdict. The digest is transcript-bound.
#[derive(Clone)]
pub struct AttentionPublic {
    wq: Vec<i8>,
    wk: Vec<i8>,
    wv: Vec<i8>,
    wo: Vec<i8>,
    gamma_a: Vec<i8>,
    rope_cos: Vec<i64>,
    rope_sin: Vec<i64>,
    exp: Vec<i64>,
}

impl AttentionPublic {
    #[allow(clippy::too_many_arguments)]
    pub fn new(wq: &[i8], wk: &[i8], wv: &[i8], wo: &[i8], gamma_a: &[i8], rope_cos: &[i64], rope_sin: &[i64], exp: &[i64]) -> Result<Self, String> {
        if [wq.len(), wo.len()] != [D * D; 2] || [wk.len(), wv.len()] != [KV * D; 2] || gamma_a.len() != D {
            return Err("private block: public weight shape".into());
        }
        if [rope_cos.len(), rope_sin.len()] != [T * HALF; 2] || exp.len() != 256 {
            return Err("private block: public table shape".into());
        }
        let one_ro = 1i64 << F_RO;
        let one_e = 1i64 << F_E;
        if rope_cos.iter().chain(rope_sin.iter()).any(|v| !(-one_ro..=one_ro).contains(v))
            || rope_cos[..HALF].iter().any(|c| *c != one_ro)
            || rope_sin[..HALF].iter().any(|s| *s != 0)
        {
            return Err("private block: rope table structure".into());
        }
        if exp[0] != one_e || exp.iter().any(|e| !(0..=one_e).contains(e)) || exp.windows(2).any(|w| w[0] < w[1]) {
            return Err("private block: exp table structure".into());
        }
        Ok(Self {
            wq: wq.to_vec(),
            wk: wk.to_vec(),
            wv: wv.to_vec(),
            wo: wo.to_vec(),
            gamma_a: gamma_a.to_vec(),
            rope_cos: rope_cos.to_vec(),
            rope_sin: rope_sin.to_vec(),
            exp: exp.to_vec(),
        })
    }

    pub fn digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-block-wip-public/0");
        for w in [&self.wq, &self.wk, &self.wv, &self.wo, &self.gamma_a] {
            h.update(&(w.len() as u64).to_le_bytes());
            h.update(&w.iter().map(|v| *v as u8).collect::<Vec<u8>>());
        }
        for t in [&self.rope_cos, &self.rope_sin, &self.exp] {
            h.update(&(t.len() as u64).to_le_bytes());
            for v in t.iter() {
                h.update(&v.to_le_bytes());
            }
        }
        *h.finalize().as_bytes()
    }

    /// The PUBLIC SYNTHETIC fixture of `causal_oracle::public_synthetic_fixture`
    /// (weights, tables, input). Deliberately public test data: NOT an approved
    /// model, NOT a real input, and no privacy is at stake for these values.
    pub fn synthetic_fixture() -> (Self, Vec<i16>) {
        let (_, w, input) = crate::causal_oracle::public_synthetic_fixture();
        let (cos, sin) = crate::tables_attn::rope_tables_generate(T, DH, 10000.0, F_RO);
        let (exp, _) = crate::tables_attn::exp_member(0, DH, F_E);
        let public = Self::new(&w.wq, &w.wk, &w.wv, &w.wo, &w.gamma_a, &cos, &sin, &exp).expect("public synthetic fixture");
        (public, input)
    }
}

/// The feed-forward half's PUBLIC words: the second norm gain `gamma_m`, the
/// three `(input, output)` row-major matrices `Wg`, `Wu`, `Wd` exactly as the
/// kernel stores them, and the 256-entry int16-output activation table.
///
/// Every relation of the feed-forward half reads these words, and they are
/// absorbed into the transcript under their own `"feed-forward-statement"`
/// label. They are NOT yet part of the single public-statement digest: the
/// commit that lands `BlockPublic` folds them into one digest under the
/// block's own domain and drops the second absorb (disposition condition 1 /
/// erratum E-1 keeps `BlockPublic` and the block profile string out until the
/// output endpoint moves to `xres2` in that same commit).
///
/// The activation table is held as `i16`, which is erratum E-2's requirement
/// ("refuses an activation table with any value outside [-32768, 32767], or
/// holds it as `[i16; 256]`") discharged by the type rather than by a check.
#[derive(Clone)]
pub struct FeedForwardPublic {
    gamma_m: Vec<i8>,
    wg_t: Vec<i8>,
    wu_t: Vec<i8>,
    wd_t: Vec<i8>,
    act: Vec<i16>,
}

impl FeedForwardPublic {
    pub fn new(gamma_m: &[i8], wg_t: &[i8], wu_t: &[i8], wd_t: &[i8], act: &[i16]) -> Result<Self, String> {
        if gamma_m.len() != D || [wg_t.len(), wu_t.len()] != [D * F; 2] || wd_t.len() != F * D {
            return Err("private block: feed-forward weight shape".into());
        }
        if act.len() != 256 {
            return Err("private block: activation table shape".into());
        }
        Ok(Self { gamma_m: gamma_m.to_vec(), wg_t: wg_t.to_vec(), wu_t: wu_t.to_vec(), wd_t: wd_t.to_vec(), act: act.to_vec() })
    }

    /// The feed-forward half of the PUBLIC SYNTHETIC fixture
    /// (`causal_oracle::public_synthetic_fixture` plus the frozen int16-out
    /// SiLU member `(-3, -11)`). Deliberately public test data: NOT an
    /// approved model and no privacy is at stake for these values.
    pub fn synthetic_fixture() -> Self {
        let (_, w, _) = crate::causal_oracle::public_synthetic_fixture();
        let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member (-3, -11)");
        Self::new(&w.gamma_m, &w.wg_t, &w.wu_t, &w.wd_t, &act).expect("feed-forward synthetic fixture")
    }

    pub fn digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-block-wip-feedforward/0");
        for w in [&self.gamma_m, &self.wg_t, &self.wu_t, &self.wd_t] {
            h.update(&(w.len() as u64).to_le_bytes());
            h.update(&w.iter().map(|v| *v as u8).collect::<Vec<u8>>());
        }
        h.update(&(self.act.len() as u64).to_le_bytes());
        for v in self.act.iter() {
            h.update(&v.to_le_bytes());
        }
        *h.finalize().as_bytes()
    }
}

/// Trusted request/connection metadata (context must authenticate model,
/// calibration and request). Scales describe the integer words only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct IoSpec {
    context: Digest,
    input_scale: i32,
    output_scale: i32,
}

impl IoSpec {
    pub fn new(context: Digest, input_scale: i32, output_scale: i32) -> Result<Self, String> {
        let spec = Self { context, input_scale, output_scale };
        spec.seams()?;
        Ok(spec)
    }
    // Endpoint slots 21..24 are this profile's; an FFN-IO endpoint (slots 1..4) does not fit.
    fn seams(&self) -> Result<[SeamSpec; 2], String> {
        Ok([SeamSpec::new(self.context, T, D, self.input_scale, 21, 22)?, SeamSpec::new(self.context, T, D, self.output_scale, 23, 24)?])
    }
}

/// Public endpoint policy, fixed by the endpoint owner BEFORE proving and
/// obtained by the verifier independently of any candidate receipt. Reading it
/// from an untrusted producer does NOT authorize those endpoints.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExpectedIo {
    spec: IoSpec,
    input: Digest,
    output: Digest,
}

impl ExpectedIo {
    pub fn from_roots(spec: IoSpec, input: Digest, output: Digest) -> Self {
        Self { spec, input, output }
    }
    pub fn input_root(&self) -> Digest {
        self.input
    }
    pub fn output_root(&self) -> Digest {
        self.output
    }
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut b = Vec::with_capacity(EXPECTED_BYTES);
        b.extend_from_slice(b"HPBWEXP0");
        b.extend_from_slice(&self.spec.context);
        b.extend_from_slice(&self.spec.input_scale.to_le_bytes());
        b.extend_from_slice(&self.spec.output_scale.to_le_bytes());
        b.extend_from_slice(&self.input);
        b.extend_from_slice(&self.output);
        b
    }
    pub fn from_bytes(b: &[u8]) -> Result<Self, String> {
        if b.len() != EXPECTED_BYTES || &b[..8] != b"HPBWEXP0" {
            return Err("private block: expected-policy frame".into());
        }
        let d = |at: usize| -> Digest { b[at..at + 32].try_into().expect("32 bytes") };
        let i = |at: usize| i32::from_le_bytes(b[at..at + 4].try_into().expect("4 bytes"));
        Ok(Self::from_roots(IoSpec::new(d(8), i(40), i(44))?, d(48), d(80)))
    }
}

/// Private endpoint owners: no Clone, no serialization, no value getter.
/// `prove` takes them BY VALUE, so a second proof against the same hiding
/// commitments does not type-check:
///
/// ```compile_fail
/// use hashline::private_block::{prove, AttentionPublic, Endpoints, ExpectedIo, FeedForwardPublic};
/// fn twice(p: &AttentionPublic, f: &FeedForwardPublic, x: &[i16], e: &ExpectedIo, owners: Endpoints) {
///     let _ = prove(p, f, x, e, owners);
///     let _ = prove(p, f, x, e, owners); // the first attempt consumed the owners
/// }
/// ```
pub struct Endpoints {
    input: PreparedPlane,
    output: PreparedPlane,
}

/// The endpoint owner's step: commit the private input and output planes with
/// fresh OS randomness. `output` is whatever the owner fixes; a value other
/// than the attention output makes every later proof fail verification.
pub fn prepare_endpoints(spec: IoSpec, input: &[i16], output: &[i16]) -> Result<(ExpectedIo, Endpoints), String> {
    let [si, so] = spec.seams()?;
    if input.len() != T * D || output.len() != T * D {
        return Err("private block: endpoint shape".into());
    }
    let ntt = NttTables::new(12);
    let words = |v: &[i16]| -> Vec<Fp> { v.iter().map(|x| Fp::from_i64(i64::from(*x))).collect() };
    let input = private_seam::prepare(&si, Side::Right, &words(input), &ntt)?;
    let output = private_seam::prepare(&so, Side::Right, &words(output), &ntt)?;
    let expected = ExpectedIo::from_roots(spec, input.commitment().root, output.commitment().root);
    Ok((expected, Endpoints { input, output }))
}

/// The SECRET value this profile's OUTPUT ENDPOINT carries, `xres1` (what an
/// honest endpoint owner commits). It moves to `xres2` in the commit that
/// lands the block profile (disposition condition 1). Do not publish, log or
/// hash it as a proof artifact.
pub fn compute_output(public: &AttentionPublic, ff: &FeedForwardPublic, input: &[i16]) -> Result<Vec<i16>, String> {
    witness::build(public, ff, input)?.output()
}

/// The SECRET whole-block output `xres2` of `private-block-kernel::run_block`,
/// recomputed by this module's own integer witness. Every relation that
/// derives it IS proved, but no endpoint binds it yet (disposition condition
/// 1), so it is a reference value and not a proof artifact. Do not publish,
/// log or hash it.
pub fn compute_block_output(public: &AttentionPublic, ff: &FeedForwardPublic, input: &[i16]) -> Result<Vec<i16>, String> {
    witness::build(public, ff, input)?.block_output()
}

/// A candidate receipt. Parsing or holding one establishes nothing; acceptance
/// requires `verify` / `verify_bytes` against the caller's own statement.
#[derive(Debug)]
pub struct Receipt {
    a_root: Digest,
    h_root: Digest,
    mask_root: Digest,
    slots: Vec<argument::SlotProof>,
    mask_open: MaskOpening,
    a_open: OpeningZk,
    h_open: OpeningZk,
    io_open: [OpeningZk; 2],
}

/// Shape facts and wall-clock phases of one proving attempt. Contains no
/// witness-dependent value (the lookup totals are fixed by the geometry).
/// Shared-box timings are diagnostic only.
#[derive(Clone, Debug)]
pub struct ProveStats {
    pub phases: Vec<(String, f64)>,
    pub a_rows: usize,
    pub h_rows: usize,
    pub m_rows: usize,
    pub u8_lookups: usize,
    pub exp_lookups: usize,
    pub act_lookups: usize,
    pub transcript_order: Vec<String>,
}

/// Prove the whole block for the private `input`, bound to the caller-fixed
/// endpoints. Consumes the endpoint owners on success and on failure; draws
/// one fresh OS randomness stream; publishes nothing on failure.
pub fn prove(public: &AttentionPublic, ff: &FeedForwardPublic, input: &[i16], expected: &ExpectedIo, endpoints: Endpoints) -> Result<Receipt, String> {
    prove_with_stats(public, ff, input, expected, endpoints).map(|(r, _)| r)
}

pub fn prove_with_stats(public: &AttentionPublic, ff: &FeedForwardPublic, input: &[i16], expected: &ExpectedIo, endpoints: Endpoints) -> Result<(Receipt, ProveStats), String> {
    // `endpoints` is dropped on the refusal path too: the owners never outlive the attempt
    let wit = witness::build(public, ff, input)?;
    protocol::prove_inner(public, ff, &wit, expected, endpoints)
}

/// Verify against the caller's public statement and endpoint policy only.
pub fn verify(public: &AttentionPublic, ff: &FeedForwardPublic, expected: &ExpectedIo, receipt: &Receipt) -> Result<(), String> {
    protocol::verify_inner(public, ff, expected, receipt).map(|_| ())
}

/// The exact frame length of this profile (a constant of the geometry).
pub fn encoded_len() -> usize {
    wire::encoded_len(&layout::Layout::new())
}

impl Receipt {
    /// Canonical bounded frame. Encoding checks representation, not validity.
    pub fn to_bytes(&self, public: &AttentionPublic, ff: &FeedForwardPublic, expected: &ExpectedIo) -> Result<Vec<u8>, String> {
        let lay = layout::Layout::new();
        wire::encode(self, &protocol::transcript(public, ff, expected, &lay).state(), &lay)
    }
    /// Decode only: no count or length in the bytes controls allocation or loops.
    pub fn from_bytes(public: &AttentionPublic, ff: &FeedForwardPublic, expected: &ExpectedIo, bytes: &[u8]) -> Result<Self, String> {
        let lay = layout::Layout::new();
        wire::decode(bytes, &protocol::transcript(public, ff, expected, &lay).state(), &lay)
    }
    /// Logical payload bytes (frame minus the 40-byte envelope).
    pub fn payload_size(&self) -> usize {
        encoded_len() - wire::HEADER
    }
}

pub fn verify_bytes(public: &AttentionPublic, ff: &FeedForwardPublic, expected: &ExpectedIo, bytes: &[u8]) -> Result<(), String> {
    verify(public, ff, expected, &Receipt::from_bytes(public, ff, expected, bytes)?)
}

/// The declared mask/CFS schedule of the whole block, line by line: 455 `A`
/// rows, 384 `H` rows, 23 slots, 50 `M` rows (its digest is transcript-bound).
pub fn schedule() -> Vec<String> {
    layout::Layout::new().describe()
}

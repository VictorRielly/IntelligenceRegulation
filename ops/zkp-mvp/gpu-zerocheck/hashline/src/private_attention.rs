//! EXPERIMENTAL native private attention at ONE fixed geometry
//! (T32 / d16 / 2 heads / 1 KV head / head_dim 8), profile
//! `hashline-zk-mr1/private-attention-t32-poc/1`.
//!
//! WHAT IT IS. A custom prover and verifier for the attention half of the
//! fixed ZK60 block with the exact integer semantics of `private-block-kernel`
//! (`causal_oracle::FixedCausalOracle`): RMSNorm (isqrt, rounded division),
//! Q/K/V projections, half-split RoPE, causal scores, the integer softmax
//! (masked max, exp table, masked row sum, quotient), PV, the output
//! projection and residual 1. The private input `x_in` and the private output
//! `xres1` are bound to two CALLER-FIXED hiding endpoint commitments by masked
//! equality sumchecks; weights and tables are public (P1).
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
mod tests;

use crate::field::Fp;
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::OpeningZk;
use crate::private_seam::{self, PreparedPlane, SeamSpec, Side};
use crate::zk::MaskOpening;
use layout::{D, DH, F_E, F_RO, HALF, KV, T};

pub const PROFILE: &[u8] = b"hashline-zk-mr1/private-attention-t32-poc/1";
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
            return Err("private attention: public weight shape".into());
        }
        if [rope_cos.len(), rope_sin.len()] != [T * HALF; 2] || exp.len() != 256 {
            return Err("private attention: public table shape".into());
        }
        let one_ro = 1i64 << F_RO;
        let one_e = 1i64 << F_E;
        if rope_cos.iter().chain(rope_sin.iter()).any(|v| !(-one_ro..=one_ro).contains(v))
            || rope_cos[..HALF].iter().any(|c| *c != one_ro)
            || rope_sin[..HALF].iter().any(|s| *s != 0)
        {
            return Err("private attention: rope table structure".into());
        }
        if exp[0] != one_e || exp.iter().any(|e| !(0..=one_e).contains(e)) || exp.windows(2).any(|w| w[0] < w[1]) {
            return Err("private attention: exp table structure".into());
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
        h.update(b"hashline/private-attention-public/1");
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
        b.extend_from_slice(b"HATTEXP1");
        b.extend_from_slice(&self.spec.context);
        b.extend_from_slice(&self.spec.input_scale.to_le_bytes());
        b.extend_from_slice(&self.spec.output_scale.to_le_bytes());
        b.extend_from_slice(&self.input);
        b.extend_from_slice(&self.output);
        b
    }
    pub fn from_bytes(b: &[u8]) -> Result<Self, String> {
        if b.len() != EXPECTED_BYTES || &b[..8] != b"HATTEXP1" {
            return Err("private attention: expected-policy frame".into());
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
/// use hashline::private_attention::{prove, AttentionPublic, Endpoints, ExpectedIo};
/// fn twice(p: &AttentionPublic, x: &[i16], e: &ExpectedIo, owners: Endpoints) {
///     let _ = prove(p, x, e, owners);
///     let _ = prove(p, x, e, owners); // the first attempt consumed the owners
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
        return Err("private attention: endpoint shape".into());
    }
    let ntt = NttTables::new(12);
    let words = |v: &[i16]| -> Vec<Fp> { v.iter().map(|x| Fp::from_i64(i64::from(*x))).collect() };
    let input = private_seam::prepare(&si, Side::Right, &words(input), &ntt)?;
    let output = private_seam::prepare(&so, Side::Right, &words(output), &ntt)?;
    let expected = ExpectedIo::from_roots(spec, input.commitment().root, output.commitment().root);
    Ok((expected, Endpoints { input, output }))
}

/// The SECRET attention output xres1 for `input` (the value an honest endpoint
/// owner commits). Do not publish, log or hash it as a proof artifact.
pub fn compute_output(public: &AttentionPublic, input: &[i16]) -> Result<Vec<i16>, String> {
    witness::build(public, input)?.output()
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
    pub transcript_order: Vec<String>,
}

/// Prove the attention half for the private `input`, bound to the caller-fixed
/// endpoints. Consumes the endpoint owners on success and on failure; draws
/// one fresh OS randomness stream; publishes nothing on failure.
pub fn prove(public: &AttentionPublic, input: &[i16], expected: &ExpectedIo, endpoints: Endpoints) -> Result<Receipt, String> {
    prove_with_stats(public, input, expected, endpoints).map(|(r, _)| r)
}

pub fn prove_with_stats(public: &AttentionPublic, input: &[i16], expected: &ExpectedIo, endpoints: Endpoints) -> Result<(Receipt, ProveStats), String> {
    // `endpoints` is dropped on the refusal path too: the owners never outlive the attempt
    let started = std::time::Instant::now();
    let wit = witness::build(public, input)?;
    let witness_seconds = started.elapsed().as_secs_f64();
    let (receipt, mut stats) = protocol::prove_inner(public, &wit, expected, endpoints)?;
    stats.phases.insert(0, ("integer witness".into(), witness_seconds));
    Ok((receipt, stats))
}

/// Verify against the caller's public statement and endpoint policy only.
pub fn verify(public: &AttentionPublic, expected: &ExpectedIo, receipt: &Receipt) -> Result<(), String> {
    protocol::verify_inner(public, expected, receipt).map(|_| ())
}

/// The exact frame length of this profile (a constant of the geometry).
pub fn encoded_len() -> usize {
    wire::encoded_len(&layout::Layout::new())
}

impl Receipt {
    /// Canonical bounded frame. Encoding checks representation, not validity.
    pub fn to_bytes(&self, public: &AttentionPublic, expected: &ExpectedIo) -> Result<Vec<u8>, String> {
        let lay = layout::Layout::new();
        wire::encode(self, &protocol::transcript(public, expected, &lay).state(), &lay)
    }
    /// Decode only: no count or length in the bytes controls allocation or loops.
    pub fn from_bytes(public: &AttentionPublic, expected: &ExpectedIo, bytes: &[u8]) -> Result<Self, String> {
        let lay = layout::Layout::new();
        wire::decode(bytes, &protocol::transcript(public, expected, &lay).state(), &lay)
    }
    /// Logical payload bytes (frame minus the 40-byte envelope).
    pub fn payload_size(&self) -> usize {
        encoded_len() - wire::HEADER
    }
}

pub fn verify_bytes(public: &AttentionPublic, expected: &ExpectedIo, bytes: &[u8]) -> Result<(), String> {
    #[cfg(test)]
    capture::begin();
    verify(public, expected, &Receipt::from_bytes(public, expected, bytes)?)
}

/// The declared mask/CFS schedule, line by line (its digest is transcript-bound).
pub fn schedule() -> Vec<String> {
    layout::Layout::new().describe()
}

// Public synthetic receipt diagnostics; compiled out of production builds.
#[cfg(test)]
mod capture {
    type Public = super::AttentionPublic;
    const SLOT_LABEL: &[u8] = b"pa-slot";
    const SCALAR_LABEL: &[u8] = b"pa-scalar";
    const TERM_LABEL: &[u8] = b"pa-term";
    include!("native_capture.rs");
}

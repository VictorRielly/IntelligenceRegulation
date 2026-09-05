//! Experimental PUBLIC fixed-block receipt. All inputs/outputs are public.
//! This does not satisfy P1 privacy, prove token generation, certify integer
//! no-wrap, or authorize sensitive data. The expected request is independent
//! verifier state, never an assertion copied from the candidate receipt.
use crate::attention::{self as at, AttnLayout, Cc};
use crate::causal_oracle::{public_synthetic_registration, FixedCausalOracle, PublicBlockWeights};
use crate::field::Fp;
use crate::layer::{prove_layer_v3, v3_zcd_point, verify_layer_v3};
use crate::merkle::Digest;
use crate::mle::eval_mle_base;
use crate::ntt::NttTables;
use crate::private_block_contract::ApprovedP1BlockContract;
use crate::public_block_oracle::{lift_public_weight_claims, PublicBlockProof};
use crate::public_block_wire::{decode_components, encode_components, validate_structure};
use crate::transcript::Transcript;

pub const WORDS: usize = 512;
pub const EXPECTED_BYTES: usize = 8 + 64 + 4 * WORDS;
pub const MAX_RECEIPT_BYTES: usize = 8 * 1024 * 1024 + 44;
pub const RECEIPT_DOMAIN: &[u8] = b"zk60-public-block-receipt-v1";
const EXPECTED_MAGIC: &[u8; 8] = b"HLB4REQ1";
const RECEIPT_MAGIC: &[u8; 8] = b"HLB4RCP1";

/// Immutable public tensors and request context, approved independently of
/// the proof. Exact repeated bytes/context intentionally remain valid to a
/// stateless verifier; application nonce consumption is a separate operation.
#[derive(Clone)]
pub struct ExpectedPublicBlock {
    contract: Digest,
    context: Digest,
    input: Vec<i16>,
    output: Vec<i16>,
    digest: Digest,
}
impl ExpectedPublicBlock {
    pub fn new(
        approved: &ApprovedP1BlockContract,
        context: Digest,
        input: &[i16],
        output: &[i16],
    ) -> Result<Self, String> {
        check_profile(approved)?;
        if context == [0; 32] || input.len() != WORDS || output.len() != WORDS {
            return Err("public request requires context and two fixed T32/d16 tensors".into());
        }
        let mut s = Self {
            contract: approved.public_digest(),
            context,
            input: input.to_vec(),
            output: output.to_vec(),
            digest: [0; 32],
        };
        s.digest = *blake3::hash(&s.to_bytes()).as_bytes();
        Ok(s)
    }
    pub fn digest(&self) -> Digest {
        self.digest
    }
    pub fn context(&self) -> Digest {
        self.context
    }
    pub fn input(&self) -> &[i16] {
        &self.input
    }
    pub fn output(&self) -> &[i16] {
        &self.output
    }
    /// Public expected state, not a receipt or model-authorization artifact.
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(EXPECTED_BYTES);
        out.extend_from_slice(EXPECTED_MAGIC);
        out.extend_from_slice(&self.contract);
        out.extend_from_slice(&self.context);
        for values in [&self.input, &self.output] {
            for x in values {
                out.extend_from_slice(&x.to_le_bytes());
            }
        }
        out
    }
    /// The caller must trust this file's provenance independently of the proof.
    pub fn from_bytes(approved: &ApprovedP1BlockContract, bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() != EXPECTED_BYTES || &bytes[..8] != EXPECTED_MAGIC {
            return Err("public expected-state frame".into());
        }
        if bytes[8..40] != approved.public_digest() {
            return Err("public expected-state approval mismatch".into());
        }
        let context = bytes[40..72].try_into().map_err(|_| "context")?;
        let read = |s: &[u8]| -> Vec<i16> {
            s.chunks_exact(2)
                .map(|x| i16::from_le_bytes([x[0], x[1]]))
                .collect()
        };
        Self::new(
            approved,
            context,
            &read(&bytes[72..72 + 2 * WORDS]),
            &read(&bytes[72 + 2 * WORDS..]),
        )
    }
}

#[derive(Clone, Debug)]
pub struct PublicBlockReceipt {
    pub request_digest: Digest,
    pub block: PublicBlockProof,
}
impl PublicBlockReceipt {
    pub fn to_bytes(&self) -> Result<Vec<u8>, String> {
        let body = encode_components(&self.block)?;
        let mut out = Vec::with_capacity(44 + body.len());
        out.extend_from_slice(RECEIPT_MAGIC);
        out.extend_from_slice(&self.request_digest);
        out.extend_from_slice(&(body.len() as u32).to_le_bytes());
        out.extend_from_slice(&body);
        Ok(out)
    }
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() < 44 || bytes.len() > MAX_RECEIPT_BYTES || &bytes[..8] != RECEIPT_MAGIC {
            return Err("public receipt frame/version/size".into());
        }
        let n = u32::from_le_bytes(bytes[40..44].try_into().map_err(|_| "length")?) as usize;
        if n != bytes.len() - 44 {
            return Err("public receipt length/trailing bytes".into());
        }
        Ok(Self {
            request_digest: bytes[8..40].try_into().map_err(|_| "digest")?,
            block: decode_components(&bytes[44..])?,
        })
    }
}

/// Pin the B3 fixed calibration and layer0. Approved model/calibration IDs and
/// W roots may differ, but are trusted inputs and bound by the contract digest.
/// This is intentionally narrower than all A00 contracts. No proof is executed
/// to discover schema bounds, and no weights are generated during this check.
fn check_profile(approved: &ApprovedP1BlockContract) -> Result<(), String> {
    let r = approved.registration();
    let mut reference =
        public_synthetic_registration(r.attention_weights.clone(), r.ffn_weights.clone());
    reference.model_identity = r.model_identity;
    reference.calibration_identity = r.calibration_identity;
    reference.mode = r.mode.clone();
    let reference = ApprovedP1BlockContract::from_trusted_registration(reference)
        .map_err(|_| "public receipt profile")?;
    if reference.public_digest() != approved.public_digest() {
        return Err("unsupported public receipt calibration/layer".into());
    }
    Ok(())
}

fn runtime_policy() -> Result<(), String> {
    // The legacy GPU request is cached in a OnceLock. Clearing HL_GPU after
    // initialization cannot prove that a GPU-enabled binary is CPU-only.
    // Refuse this experimental profile in such builds without probing hardware.
    if cfg!(feature = "gpu-cuda") {
        return Err("public receipt requires a CPU-only build".into());
    }
    if crate::pcs_compact::selected()
        || at::tamper_mode()
        || ["HL_FOLD", "HL_NO_FOLD", "HL_GPU"]
            .iter()
            .any(|k| std::env::var_os(k).is_some_and(|s| !s.is_empty()))
    {
        return Err("public receipt requires CPU, default folding and honest Ligero mode".into());
    }
    Ok(())
}

/// Public domain for fixture-level protocol tests; not the legacy B3 domain.
pub fn public_receipt_transcript(expected: &ExpectedPublicBlock) -> Transcript {
    let mut tr = Transcript::new(RECEIPT_DOMAIN);
    tr.absorb(b"receipt-format", RECEIPT_MAGIC);
    tr.absorb(b"proof-mode", b"P0-public-arithmetic-only");
    tr.absorb(b"short-W-adapter", b"tiny-KV-subcube-128-to-256-v1");
    tr.absorb(b"approved-contract", &expected.contract);
    tr.absorb(b"expected-public-request", &expected.digest);
    tr
}

pub struct PublicReceiptOracle<'a> {
    approved: &'a ApprovedP1BlockContract,
    oracle: FixedCausalOracle,
}
impl<'a> PublicReceiptOracle<'a> {
    pub fn new(
        approved: &'a ApprovedP1BlockContract,
        weights: PublicBlockWeights,
    ) -> Result<Self, String> {
        check_profile(approved)?;
        runtime_policy()?;
        Ok(Self {
            approved,
            oracle: FixedCausalOracle::new(approved, weights).map_err(|e| e.to_string())?,
        })
    }
    pub fn prove(&self, expected: &ExpectedPublicBlock) -> Result<PublicBlockReceipt, String> {
        runtime_policy()?;
        if expected.contract != self.approved.public_digest() {
            return Err("request approval mismatch".into());
        }
        let b = self
            .oracle
            .build(&expected.input)
            .map_err(|e| e.to_string())?;
        if b.residual
            .xres2
            .iter()
            .copied()
            .ne(expected.output.iter().map(|x| i64::from(*x)))
        {
            return Err("expected public output differs from fixed oracle".into());
        }
        let r = self.approved.registration();
        let ntt = NttTables::new(11);
        let mut tr = public_receipt_transcript(expected);
        let (mut attention, mut pending, _) =
            at::prove_attn(&b.attention, &b.residual, &r.params, &ntt, &mut tr);
        let before = Transcript::clone_state(&tr);
        let ffn = prove_layer_v3(&b.ffn, 32, &r.params, &ntt, &mut tr).proof;
        let rho = v3_zcd_point(&r.ffn, &ffn, &before);
        at::attn_seam(
            &mut pending.cc,
            &mut tr,
            &pending.lay,
            Some(&pending.a_data),
            &[rho],
            &ffn.zcd_term[..1],
            &ffn.zcd_term[1..2],
        )
        .map_err(|_| "internal public seam")?;
        bind_endpoints(
            &mut pending.cc,
            &mut tr,
            &pending.lay,
            Some(&pending.a_data),
            expected,
        )?;
        lift_public_weight_claims(&pending.lay, &mut pending.cc).map_err(|e| e.to_string())?;
        at::attn_open(pending, &mut attention, &mut tr);
        let receipt = PublicBlockReceipt {
            request_digest: expected.digest,
            block: PublicBlockProof {
                contract_digest: expected.contract,
                attention,
                ffn,
            },
        };
        validate_structure(&receipt.block)?;
        Ok(receipt)
    }
}

fn bind_endpoints(
    cc: &mut Cc,
    tr: &mut Transcript,
    lay: &AttnLayout,
    data: Option<&[Fp]>,
    expected: &ExpectedPublicBlock,
) -> Result<(), String> {
    // Expected full tensors are committed by the request digest BEFORE either
    // A root. Fresh points are drawn after both arithmetic commitments and
    // their internal seam, before the attention A opening. cls_claim performs
    // signed INT16 reconstruction of the actual committed class plane.
    for (role, plane, values) in [
        (b"external-input".as_slice(), &lay.x_in, &expected.input),
        (b"external-output".as_slice(), &lay.xres2, &expected.output),
    ] {
        tr.absorb(b"public-boundary-role", role);
        let pt = tr.challenge_fp2_vec(lay.log_d as usize);
        let actual = at::cls_claim(cc, tr, data, plane, lay.log_d, &pt);
        let words: Vec<Fp> = values.iter().map(|x| Fp::from_i64(i64::from(*x))).collect();
        if actual != eval_mle_base(&words, &pt) {
            return Err("external public boundary".into());
        }
    }
    Ok(())
}

pub fn verify_public_receipt(
    approved: &ApprovedP1BlockContract,
    expected: &ExpectedPublicBlock,
    receipt: &PublicBlockReceipt,
) -> Result<(), String> {
    runtime_policy()?;
    check_profile(approved)?;
    if expected.contract != approved.public_digest()
        || receipt.block.contract_digest != expected.contract
        || receipt.request_digest != expected.digest
    {
        return Err("public receipt request/approval mismatch".into());
    }
    // Bounded canonical shape validation must precede any generic verifier.
    validate_structure(&receipt.block)?;
    let proof = &receipt.block;
    if proof.attention.vals.len() != 135
        || proof.attention.sc.len() != 12
        || proof.attention.collapse.len() != 4
        || !proof.attention.helper_sums.is_empty()
    {
        return Err("public receipt exact attention schedule".into());
    }
    let r = approved.registration();
    for (got, want) in [
        (&proof.attention.w_com, &r.attention_weights),
        (&proof.ffn.w_com, &r.ffn_weights),
    ] {
        let got = got.as_ref().ok_or("missing approved W")?;
        if got.root != want.root || got.rows != want.rows || got.log_cols != want.log_cols {
            return Err("public receipt unapproved W root/shape".into());
        }
    }
    let ntt = NttTables::new(11);
    let mut tr = public_receipt_transcript(expected);
    let (lay, mut cc) = at::verify_attn(
        &proof.attention,
        &r.attention,
        &r.residual,
        &r.params,
        &mut tr,
    )
    .map_err(|_| "receipt attention argument")?;
    let before = Transcript::clone_state(&tr);
    verify_layer_v3(&r.ffn, &proof.ffn, &r.params, &ntt, &mut tr)
        .map_err(|_| "receipt FFN argument/openings")?;
    let rho = v3_zcd_point(&r.ffn, &proof.ffn, &before);
    at::attn_seam(
        &mut cc,
        &mut tr,
        &lay,
        None,
        &[rho],
        &proof.ffn.zcd_term[..1],
        &proof.ffn.zcd_term[1..2],
    )
    .map_err(|_| "receipt internal seam")?;
    bind_endpoints(&mut cc, &mut tr, &lay, None, expected)?;
    lift_public_weight_claims(&lay, &mut cc).map_err(|e| e.to_string())?;
    at::verify_attn_open(&proof.attention, &lay, &cc, &r.params, &ntt, &mut tr)
        .map_err(|_| "receipt attention openings".into())
}

/// Byte-facing verifier: all supplied expected state is independent of bytes.
pub fn verify_public_receipt_bytes(
    approved: &ApprovedP1BlockContract,
    expected: &ExpectedPublicBlock,
    bytes: &[u8],
) -> Result<(), String> {
    let proof = PublicBlockReceipt::from_bytes(bytes)?;
    verify_public_receipt(approved, expected, &proof)
}

//! Experimental PUBLIC P0 arithmetic validation of the fixed T32 block oracle.
//!
//! The approved object still describes a P1 policy. This separate wrapper does
//! NOT satisfy that privacy policy: ordinary attention/FFN commitments, claims,
//! histograms and opening columns are public. No private proof, no-wrap theorem,
//! decoder, external input/output binding, multi-block chain or LLM generation.

use crate::attention::{self as at, AttnProof};
use crate::causal_oracle::{FixedCausalOracle, OracleError, PublicBlockWeights};
use crate::field::Fp2;
use crate::layer::{prove_layer_v3, v3_zcd_point, verify_layer_v3, LayerProofV3, LayoutV3};
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::Commitment;
use crate::private_block_contract::ApprovedP1BlockContract;
use crate::transcript::Transcript;

pub const PUBLIC_BLOCK_DOMAIN: &[u8] = b"zk60-public-arithmetic-block-v1";

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PublicBlockError {
    Oracle(OracleError),
    ContractDigest,
    AttentionWeights,
    FfnWeights,
    Verification(&'static str),
}
impl std::fmt::Display for PublicBlockError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Oracle(e) => write!(f, "{e}"),
            Self::ContractDigest => write!(f, "unapproved public block metadata"),
            Self::AttentionWeights => write!(f, "unapproved attention/gamma root"),
            Self::FfnWeights => write!(f, "unapproved FFN root"),
            Self::Verification(stage) => write!(f, "public block refusal: {stage}"),
        }
    }
}
impl std::error::Error for PublicBlockError {}
impl From<OracleError> for PublicBlockError {
    fn from(e: OracleError) -> Self {
        Self::Oracle(e)
    }
}

/// Public proof objects, NOT a secret-preserving artifact. No byte decoder is
/// supplied, and this typed API is not an audited hostile-input parser.
#[derive(Clone, Debug)]
pub struct PublicBlockProof {
    pub contract_digest: Digest,
    pub attention: AttnProof,
    pub ffn: LayerProofV3,
}
impl PublicBlockProof {
    /// Existing component encodings only; excludes public contract and framing.
    /// This is measured proof payload size, not a complete transport encoding.
    pub fn payload_size_bytes(&self) -> usize {
        self.attention.size_bytes() + self.ffn.size_bytes()
    }
}

pub struct PublicBlockOracle<'a> {
    approved: &'a ApprovedP1BlockContract,
    oracle: FixedCausalOracle,
}
impl<'a> PublicBlockOracle<'a> {
    /// The approval must be independently trusted, never copied from a proof.
    pub fn new(
        approved: &'a ApprovedP1BlockContract,
        weights: PublicBlockWeights,
    ) -> Result<Self, PublicBlockError> {
        Ok(Self {
            approved,
            oracle: FixedCausalOracle::new(approved, weights)?,
        })
    }

    /// Build the checked fixed-calibration witness, then the existing P0 proof.
    /// Proving accepts input, not an arbitrarily mutable witness, because the
    /// legacy prover asserts honest relations and release panics may abort.
    pub fn prove(&self, input: &[i16]) -> Result<PublicBlockProof, PublicBlockError> {
        let b = self.oracle.build(input)?;
        let r = self.approved.registration();
        let ntt = NttTables::new(r.params.log_cols + r.params.inv_rate.trailing_zeros());
        let mut tr = public_block_transcript(self.approved);
        let (mut attention, mut pending, _) =
            at::prove_attn(&b.attention, &b.residual, &r.params, &ntt, &mut tr);
        let before = Transcript::clone_state(&tr);
        let ffn = prove_layer_v3(&b.ffn, r.ffn.t_rows, &r.params, &ntt, &mut tr).proof;
        let lay3 = LayoutV3::new(r.ffn.t_rows, r.ffn.d, r.ffn.f);
        let rho = v3_zcd_point(&r.ffn, &ffn, &before);
        let pts = seam_points(&rho, pending.lay.log_t, pending.lay.log_dp, &lay3);
        let wx = &ffn.zcd_term[..lay3.nb_d];
        let wz = &ffn.zcd_term[lay3.nb_d..2 * lay3.nb_d];
        at::attn_seam(
            &mut pending.cc,
            &mut tr,
            &pending.lay,
            Some(&pending.a_data),
            &pts,
            wx,
            wz,
        )
        .map_err(|_| PublicBlockError::Verification("internal seam"))?;
        lift_public_weight_claims(&pending.lay, &mut pending.cc)?;
        at::attn_open(pending, &mut attention, &mut tr);
        let proof = PublicBlockProof {
            contract_digest: b.contract_digest,
            attention,
            ffn,
        };
        check_roots(self.approved, &proof)?;
        Ok(proof)
    }
}

/// Domain-separated PUBLIC proof context. Including the P1 contract digest pins
/// its metadata but does not imply P1 verification or alter that approved object.
pub fn public_block_transcript(approved: &ApprovedP1BlockContract) -> Transcript {
    let mut tr = Transcript::new(PUBLIC_BLOCK_DOMAIN);
    tr.absorb(b"proof-mode", b"P0-public-arithmetic-only");
    tr.absorb(b"short-W-adapter", b"tiny-KV-subcube-128-to-256-v1");
    approved.bind_public_statement(&mut tr);
    tr
}

fn same_commitment(a: Option<&Commitment>, b: &Commitment) -> bool {
    a.is_some_and(|a| a.root == b.root && a.rows == b.rows && a.log_cols == b.log_cols)
}
fn check_roots(
    approved: &ApprovedP1BlockContract,
    proof: &PublicBlockProof,
) -> Result<(), PublicBlockError> {
    if proof.contract_digest != approved.public_digest() {
        return Err(PublicBlockError::ContractDigest);
    }
    let r = approved.registration();
    if !same_commitment(proof.attention.w_com.as_ref(), &r.attention_weights) {
        return Err(PublicBlockError::AttentionWeights);
    }
    if !same_commitment(proof.ffn.w_com.as_ref(), &r.ffn_weights) {
        return Err(PublicBlockError::FfnWeights);
    }
    Ok(())
}

/// Verify both P0 arithmetic arguments, both internal FFN seams and every PCS
/// opening. Statements and expected W/gamma roots come only from trusted state.
/// Success is NOT acceptance under the original P1 privacy policy.
pub fn verify_public_block(
    approved: &ApprovedP1BlockContract,
    proof: &PublicBlockProof,
) -> Result<(), PublicBlockError> {
    check_roots(approved, proof)?;
    let r = approved.registration();
    let ntt = NttTables::new(r.params.log_cols + r.params.inv_rate.trailing_zeros());
    let mut tr = public_block_transcript(approved);
    let (lay, mut cc) = at::verify_attn(
        &proof.attention,
        &r.attention,
        &r.residual,
        &r.params,
        &mut tr,
    )
    .map_err(|_| PublicBlockError::Verification("attention argument"))?;
    let before = Transcript::clone_state(&tr);
    verify_layer_v3(&r.ffn, &proof.ffn, &r.params, &ntt, &mut tr)
        .map_err(|_| PublicBlockError::Verification("FFN argument/openings"))?;
    let lay3 = LayoutV3::new(r.ffn.t_rows, r.ffn.d, r.ffn.f);
    let rho = v3_zcd_point(&r.ffn, &proof.ffn, &before);
    let pts = seam_points(&rho, lay.log_t, lay.log_dp, &lay3);
    let wx = &proof.ffn.zcd_term[..lay3.nb_d];
    let wz = &proof.ffn.zcd_term[lay3.nb_d..2 * lay3.nb_d];
    at::attn_seam(&mut cc, &mut tr, &lay, None, &pts, wx, wz)
        .map_err(|_| PublicBlockError::Verification("internal seam"))?;
    lift_public_weight_claims(&lay, &mut cc)?;
    at::verify_attn_open(&proof.attention, &lay, &cc, &r.params, &ntt, &mut tr)
        .map_err(|_| PublicBlockError::Verification("attention openings"))
}

/// The tiny profile packs 128-value K/V matrices into the two halves of one
/// 256-value PCS row. Legacy PCS cannot directly open a sub-row slice. Lift
/// each such W claim to the enclosing row by fixing its leading point bit.
/// This changes neither the packed vector/root nor the claimed evaluation.
/// Apply identically on both sides, after argument collection, before opening.
/// Other short shapes/linear combinations are explicitly unsupported here.
pub fn lift_public_weight_claims(
    lay: &at::AttnLayout,
    cc: &mut at::Cc,
) -> Result<usize, PublicBlockError> {
    let mut lifted = 0;
    for claim in &mut cc.ww {
        if claim.parts.is_empty() {
            return Err(PublicBlockError::Verification("empty weight claim"));
        }
        if claim
            .parts
            .iter()
            .all(|(sl, _)| sl.log_size >= lay.cols_log)
        {
            continue;
        }
        if lay.cols_log != 8
            || lay.log_wkv != 7
            || lay.wk != 256
            || lay.wv != 384
            || lay.w_len != 1024
            || claim.sum
            || claim.parts.len() != 1
            || claim.point.len() != 7
            || claim.parts[0].0.log_size != 7
            || ![lay.wk, lay.wv].contains(&claim.parts[0].0.offset)
            || claim.parts[0].1 != Fp2::ONE
        {
            return Err(PublicBlockError::Verification(
                "unsupported short weight claim",
            ));
        }
        let sl = &mut claim.parts[0].0;
        let base = sl.offset / 256 * 256;
        if base.checked_add(256).is_none_or(|end| end > lay.w_len)
            || sl.offset % 128 != 0
            || sl.offset + 128 > base + 256
        {
            return Err(PublicBlockError::Verification("short weight row bounds"));
        }
        claim.point = at::sub_point(base, 8, sl.offset, 7, &claim.point);
        sl.offset = base;
        sl.log_size = 8;
        lifted += 1;
    }
    Ok(lifted)
}

fn seam_points(rho: &[Fp2], log_t: u32, log_dp: u32, lay3: &LayoutV3) -> Vec<Vec<Fp2>> {
    let extra = log_dp - lay3.log_db;
    (0..lay3.nb_d)
        .map(|b| {
            let mut pt = rho[..log_t as usize].to_vec();
            for bit in (0..extra).rev() {
                pt.push(if (b >> bit) & 1 == 1 {
                    Fp2::ONE
                } else {
                    Fp2::ZERO
                });
            }
            pt.extend_from_slice(&rho[log_t as usize..]);
            pt
        })
        .collect()
}

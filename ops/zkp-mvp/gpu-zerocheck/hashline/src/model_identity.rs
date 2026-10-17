//! Opt-in approved-weight verification for ONE v3 P1 FFN layer.
//!
//! `verify_layer_zk_v3` verifies against the W root supplied in a proof. It
//! cannot decide whether an application approved those weights. This module
//! supplies that missing caller check for PUBLIC weights: register the expected
//! statement, parameters, W commitment and transcript domain independently,
//! then compare every candidate claim before invoking the existing verifier.
//!
//! TRUST BOUNDARY: registration is an application authorization operation.
//! Load its arguments from authenticated application configuration, or compute
//! the W commitment from independently approved public weights. Copying the
//! candidate proof's W root into registration provides NO model authentication.
//! This module does not authenticate a registry, sign manifests or derive trust
//! from a `model_id` string. Registration fields are private after construction.
//!
//! Scope is deliberately limited to P1, v3, Ligero at inverse rate 4, and the
//! committed-output claim. P3 and predicates are refused. The statement pins
//! the signed shifts, activation family and complete frozen table, not an
//! external calibration file's provenance or exponents absent from StatementV3.
//! Input/output identity, layer seams, complete generation, wire decoding,
//! deployment soundness parameters and the composed ZK argument remain separate
//! obligations. In particular, this verifier cannot detect public/reused prover
//! randomness. Deterministic fixtures remain verifiable and are NOT private.

use crate::field::Fp;
use crate::layer::{LayerParams, StatementV3};
use crate::ntt::NttTables;
use crate::pcs::Commitment;
use crate::tables_v3::int16out_member;
use crate::transcript::Transcript;
use crate::zk::{
    verify_layer_zk_v3, LayerProofZk, OutputClaim, ZkPrivacy, ZkStatementMode, MASK_LOG_DOM,
};

/// Refusal at the identity boundary, or rejection by the underlying proof.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum IdentityError {
    UnsupportedPolicy(&'static str),
    InvalidRegistration(&'static str),
    StatementMismatch(&'static str),
    ParameterMismatch,
    ModeMismatch,
    MissingWeightCommitment,
    WeightCommitmentMismatch,
    IncompatibleNtt(&'static str),
    ProofRejected(String),
}

impl std::fmt::Display for IdentityError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UnsupportedPolicy(reason) => write!(f, "unsupported identity policy: {reason}"),
            Self::InvalidRegistration(reason) => {
                write!(f, "invalid trusted registration: {reason}")
            }
            Self::StatementMismatch(field) => write!(f, "unapproved statement field: {field}"),
            Self::ParameterMismatch => write!(f, "unapproved proof parameters"),
            Self::ModeMismatch => write!(f, "unapproved statement mode or model declaration"),
            Self::MissingWeightCommitment => write!(f, "missing W commitment"),
            Self::WeightCommitmentMismatch => write!(
                f,
                "W commitment differs from independently approved weights"
            ),
            Self::IncompatibleNtt(reason) => {
                write!(f, "incompatible verifier NTT tables: {reason}")
            }
            Self::ProofRejected(reason) => write!(f, "proof rejected: {reason}"),
        }
    }
}

impl std::error::Error for IdentityError {}

/// An application's independently approved ONE-layer P1 relation.
///
/// This is an immutable local policy object, not a cryptographic certificate.
/// No constructor reads a candidate proof or treats its root as approval.
pub struct ApprovedP1Layer {
    statement: StatementV3,
    params: LayerParams,
    weights: Commitment,
    mode: ZkStatementMode,
    transcript_domain: Vec<u8>,
    required_ntt_log: u32,
}

impl ApprovedP1Layer {
    /// Register an expected relation from an INDEPENDENT, TRUSTED source.
    ///
    /// The application must authenticate this source before calling. The full
    /// W commitment must have been computed/approved for these public weights
    /// and PCS parameters, never extracted from the proof about to be checked.
    /// `transcript_domain` must be the application's fixed single-layer domain;
    /// this API does not accept prover-supplied or chained transcript state.
    ///
    /// Structural checks below are not an assessment of security bits: the
    /// caller must approve `num_col_checks` using the whole-proof analysis.
    pub fn from_trusted_registration(
        statement: StatementV3,
        params: LayerParams,
        weights: Commitment,
        mode: ZkStatementMode,
        transcript_domain: &[u8],
    ) -> Result<Self, IdentityError> {
        require_p1_commit(&mode)?;
        if transcript_domain.is_empty() {
            return Err(IdentityError::InvalidRegistration(
                "empty transcript domain",
            ));
        }
        if !statement.t_rows.is_power_of_two()
            || statement.d < 16
            || statement.f < 16
            || statement.d % 16 != 0
            || statement.f % 16 != 0
        {
            return Err(IdentityError::InvalidRegistration(
                "v3 shape requires power-of-two rows and positive widths divisible by 16",
            ));
        }
        let (sg, su, sh, sz) = statement.shifts;
        if !(1..=16).contains(&sg)
            || !(-8..=16).contains(&su)
            || !(0..=16).contains(&sh)
            || !(1..=16).contains(&sz)
        {
            return Err(IdentityError::InvalidRegistration(
                "signed shifts outside the frozen v3 export bands",
            ));
        }
        if params.inv_rate != 4 || !(1..=16).contains(&params.log_cols) {
            return Err(IdentityError::UnsupportedPolicy(
                "requires Ligero inverse rate 4 and log_cols in 1..=16",
            ));
        }
        let log_db = statement.d.trailing_zeros().min(12);
        let log_fb = statement.f.trailing_zeros().min(12);
        let a_log = params
            .log_cols
            .min(statement.t_rows.trailing_zeros() + log_db.min(log_fb));
        // Limit this boundary to pads that fit the existing encoder's first
        // message block. This is a structural condition, not a security floor.
        if params.num_col_checks == 0 || params.num_col_checks > (1usize << a_log) {
            return Err(IdentityError::InvalidRegistration(
                "column checks must be positive and no wider than an activation message row",
            ));
        }
        let w_log = params.log_cols.min(log_db + log_fb);
        let w_len = statement
            .d
            .checked_mul(statement.f)
            .and_then(|n| n.checked_mul(3))
            .ok_or(IdentityError::InvalidRegistration(
                "weight layout length overflows",
            ))?;
        // The verifier forms activation/helper offsets from these lengths.
        statement
            .t_rows
            .checked_mul(statement.d.checked_add(statement.f).ok_or(
                IdentityError::InvalidRegistration("activation widths overflow"),
            )?)
            .and_then(|n| n.checked_mul(16))
            .ok_or(IdentityError::InvalidRegistration(
                "activation layout length overflows",
            ))?;
        if weights.log_cols != w_log || weights.rows != w_len / (1usize << w_log) {
            return Err(IdentityError::InvalidRegistration(
                "W commitment shape disagrees with the approved layout",
            ));
        }
        // Pin BOTH the registry digest and its exact bytes. A matching label
        // alone must not admit a different supplied activation table.
        let (members, digests) = statement.act.members();
        let member = digests
            .iter()
            .position(|digest| *digest == statement.table_digest)
            .ok_or(IdentityError::InvalidRegistration(
                "activation digest is not a frozen member of this family",
            ))?;
        let (e_in, e_out) = members[member];
        let (table, digest) = int16out_member(statement.act, e_in, e_out).ok_or(
            IdentityError::InvalidRegistration("unavailable frozen activation table"),
        )?;
        if statement.table != table || statement.table_digest != digest {
            return Err(IdentityError::InvalidRegistration(
                "activation table bytes disagree with the frozen digest",
            ));
        }
        let required_ntt_log = (w_log.max(a_log) + 2).max(MASK_LOG_DOM);
        Ok(Self {
            statement,
            params,
            weights,
            mode,
            transcript_domain: transcript_domain.to_vec(),
            required_ntt_log,
        })
    }

    /// Check the candidate against independent approval, then verify its proof.
    ///
    /// Claimed metadata is untrusted. All comparisons and NTT checks happen
    /// before a fresh local transcript is constructed. The existing verifier
    /// receives the REGISTERED statement/parameters/mode, not candidate copies.
    /// Its structured-proof validation and security assumptions still apply;
    /// this is not an untrusted-wire decoder or a general panic/DoS boundary.
    pub fn verify(
        &self,
        claimed_statement: &StatementV3,
        claimed_params: &LayerParams,
        claimed_mode: &ZkStatementMode,
        proof: &LayerProofZk,
        ntt: &NttTables,
    ) -> Result<(), IdentityError> {
        require_p1_commit(claimed_mode)?;
        if claimed_mode != &self.mode {
            return Err(IdentityError::ModeMismatch);
        }
        let expected = &self.statement;
        let actual = claimed_statement;
        for (matches, field) in [
            (actual.l == expected.l, "layer"),
            (actual.t_rows == expected.t_rows, "t_rows"),
            (actual.d == expected.d, "d"),
            (actual.f == expected.f, "f"),
            (actual.shifts == expected.shifts, "shifts"),
            (actual.act == expected.act, "activation family"),
            (actual.table_digest == expected.table_digest, "table digest"),
            (actual.table == expected.table, "table bytes"),
        ] {
            if !matches {
                return Err(IdentityError::StatementMismatch(field));
            }
        }
        if claimed_params.log_cols != self.params.log_cols
            || claimed_params.inv_rate != self.params.inv_rate
            || claimed_params.num_col_checks != self.params.num_col_checks
        {
            return Err(IdentityError::ParameterMismatch);
        }
        let supplied_weights = proof
            .w_com
            .as_ref()
            .ok_or(IdentityError::MissingWeightCommitment)?;
        if supplied_weights.root != self.weights.root
            || supplied_weights.rows != self.weights.rows
            || supplied_weights.log_cols != self.weights.log_cols
        {
            return Err(IdentityError::WeightCommitmentMismatch);
        }
        validate_ntt(ntt, self.required_ntt_log)?;
        let mut transcript = Transcript::new(&self.transcript_domain);
        verify_layer_zk_v3(
            &self.statement,
            proof,
            &self.params,
            ntt,
            &mut transcript,
            &self.mode,
        )
        .map_err(IdentityError::ProofRejected)
    }
}

fn require_p1_commit(mode: &ZkStatementMode) -> Result<(), IdentityError> {
    if mode.privacy != ZkPrivacy::P1 {
        return Err(IdentityError::UnsupportedPolicy(
            "P3 approved-model consistency is not implemented",
        ));
    }
    if mode.output != OutputClaim::Committed || mode.pred.is_some() {
        return Err(IdentityError::UnsupportedPolicy(
            "only committed output without a predicate is supported",
        ));
    }
    Ok(())
}

fn validate_ntt(ntt: &NttTables, required_log: u32) -> Result<(), IdentityError> {
    if ntt.max_log < required_log || ntt.max_log > 32 || ntt.max_log >= usize::BITS {
        return Err(IdentityError::IncompatibleNtt("transform capacity"));
    }
    let roots = ntt.max_log as usize + 1;
    let twiddles = (1usize << ntt.max_log) / 2;
    let (forward, inverse) = ntt.twiddle_tables();
    if ntt.roots.len() != roots
        || ntt.inv_roots.len() != roots
        || forward.len() != twiddles.max(1)
        || inverse.len() != twiddles.max(1)
    {
        return Err(IdentityError::IncompatibleNtt(
            "inconsistent table dimensions",
        ));
    }
    for log in 0..=ntt.max_log {
        let root = Fp::two_adic_root(log);
        if ntt.roots[log as usize] != root || ntt.inv_roots[log as usize] != root.inv() {
            return Err(IdentityError::IncompatibleNtt("noncanonical roots"));
        }
    }
    Ok(())
}

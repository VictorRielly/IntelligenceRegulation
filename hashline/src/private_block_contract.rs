//! Experimental fixed-calibration P1 block PRECHECK, not a block verifier.
//!
//! Register this object only from authenticated application configuration and
//! independently approved public attention/FFN weight commitments. Registering
//! a candidate proof's metadata/root as "trusted" gives no authentication.
//! The owned registration is immutable; all candidate metadata must match its
//! canonical digest, including exponents absent from current proof statements.
//!
//! Scope: T=32,d=f=16,H=2,Hkv=1,dh=8, INT16 residual classes, round RMSNorm,
//! fixed tables/shifts, P1 committed output, PCS (log_cols=8,rate inverse=8,
//! checks=256). This deliberately small profile accommodates 256 pad symbols
//! even in the attention KV domain. It neither enables a CLI mode nor proves
//! witness ranges, field-to-integer uniqueness, model inference, seams, zero
//! knowledge or a concrete security level. The host arithmetic envelope below
//! is CONDITIONAL on bounded integer witnesses, not a malicious-field-witness
//! soundness argument. No secret witness is accepted or printed by this API.

use crate::attention::{attn_layout_of, AttnConsts, Cls, FullConsts, NormConsts};
use crate::export_v3::V3Exps;
use crate::layer::{LayerParams, StatementV3};
use crate::merkle::Digest;
use crate::pcs::Commitment;
use crate::tables_attn::{exp_member, rope_digest, rope_tables_generate};
use crate::tables_v3::int16out_member;
use crate::transcript::Transcript;
use crate::zk::{OutputClaim, ZkPrivacy, ZkStatementMode};

pub const PROFILE: &[u8] = b"zk60-fixed-tiny-p1-block-contract-v1";

/// Missing scale metadata from AttnConsts, explicitly approved here.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AttentionExponents {
    pub e_wq: i32,
    pub e_wk: i32,
    pub e_wv: i32,
    pub e_wo: i32,
    pub e_q: i32,
    pub e_k: i32,
    pub e_v: i32,
    pub e_qr: i32,
    pub e_kr: i32,
    pub e_o: i32,
    pub e_gamma_a: i32,
    pub e_gamma_m: i32,
}

/// Public metadata, supplied independently at registration or untrusted at
/// preflight. IDs identify authenticated external artifacts, not certificates.
#[derive(Clone, Debug)]
pub struct BlockRegistration {
    pub attention: AttnConsts,
    pub residual: FullConsts,
    pub ffn: StatementV3,
    pub attention_exponents: AttentionExponents,
    pub ffn_exponents: V3Exps,
    pub params: LayerParams,
    pub mode: ZkStatementMode,
    pub model_identity: Digest,
    pub calibration_identity: Digest,
    /// Includes Wq/Wk/Wv/Wo AND both gamma vectors, in AttnLayout's order.
    pub attention_weights: Commitment,
    pub ffn_weights: Commitment,
}

/// Static error categories contain no supplied field values or witnesses.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ContractError {
    Unsupported(&'static str),
    Invalid(&'static str),
    UnapprovedMetadata,
    BoundaryMismatch(&'static str),
}

impl std::fmt::Display for ContractError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Unsupported(k) => write!(f, "unsupported block contract: {k}"),
            Self::Invalid(k) => write!(f, "invalid block contract: {k}"),
            Self::UnapprovedMetadata => {
                write!(f, "block metadata differs from trusted registration")
            }
            Self::BoundaryMismatch(k) => write!(f, "incompatible block boundary: {k}"),
        }
    }
}
impl std::error::Error for ContractError {}

/// Bounds on selected HONEST INTEGER operations, conditional on the declared
/// ranges. Not a field-alias exclusion proof or complete arithmetic certificate.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct HostArithmeticEnvelope {
    pub norm_square_sum_with_epsilon: u64,
    pub max_norm_d: u64,
    pub max_round_norm_denominator: u64,
    pub max_doubled_norm_numerator: u64,
    pub max_scaled_residual_sum: u64,
}

pub struct ApprovedP1BlockContract {
    registration: BlockRegistration,
    digest: Digest,
    envelope: HostArithmeticEnvelope,
}

impl ApprovedP1BlockContract {
    /// Application authorization operation, NOT proof-derived registration.
    pub fn from_trusted_registration(
        registration: BlockRegistration,
    ) -> Result<Self, ContractError> {
        let envelope = validate(&registration)?;
        let digest = digest_registration(&registration);
        Ok(Self {
            registration,
            digest,
            envelope,
        })
    }

    /// Snapshot only: changing it cannot alter approved state.
    pub fn registration(&self) -> BlockRegistration {
        self.registration.clone()
    }
    pub fn public_digest(&self) -> Digest {
        self.digest
    }
    pub fn host_arithmetic_envelope(&self) -> HostArithmeticEnvelope {
        self.envelope
    }

    /// Check only public metadata. Success does NOT establish any proof or
    /// witness property; a future block verifier must still run every argument.
    pub fn preflight_candidate(&self, candidate: &BlockRegistration) -> Result<(), ContractError> {
        validate(candidate)?;
        if digest_registration(candidate) != self.digest {
            return Err(ContractError::UnapprovedMetadata);
        }
        Ok(())
    }

    /// Domain-bind this exact approved contract before commitments/challenges.
    /// Binding metadata alone is not a substitute for verification.
    pub fn bind_public_statement(&self, transcript: &mut Transcript) {
        transcript.absorb(b"block-contract-profile", PROFILE);
        transcript.absorb(b"block-contract", &self.digest);
    }

    /// Public preconditions for a future private residual equality argument.
    /// This does NOT compare or prove equality of any committed tensor.
    pub fn preflight_next_boundary(&self, next: &Self) -> Result<(), ContractError> {
        let (a, b) = (&self.registration, &next.registration);
        if a.model_identity != b.model_identity || a.calibration_identity != b.calibration_identity
        {
            return Err(ContractError::BoundaryMismatch(
                "approved model/calibration",
            ));
        }
        if a.attention.layer.checked_add(1) != Some(b.attention.layer) {
            return Err(ContractError::BoundaryMismatch("layer order"));
        }
        if a.residual.e_r2 != b.attention.e_r || a.residual.r2_cls != b.attention.x_cls {
            return Err(ContractError::BoundaryMismatch("residual scale/class"));
        }
        // All tensor shapes and proof parameters are fixed by this profile.
        Ok(())
    }
}

fn require(ok: bool, field: &'static str) -> Result<(), ContractError> {
    if ok {
        Ok(())
    } else {
        Err(ContractError::Invalid(field))
    }
}

fn validate(r: &BlockRegistration) -> Result<HostArithmeticEnvelope, ContractError> {
    let (c, f, st, e, x) = (
        &r.attention,
        &r.residual,
        &r.ffn,
        &r.attention_exponents,
        &r.ffn_exponents,
    );
    if r.mode.privacy != ZkPrivacy::P1
        || r.mode.output != OutputClaim::Committed
        || r.mode.pred.is_some()
    {
        return Err(ContractError::Unsupported(
            "only P1 committed output; no predicate",
        ));
    }
    require(
        r.model_identity != [0; 32] && r.calibration_identity != [0; 32],
        "missing artifact identity",
    )?;
    require(
        r.mode.model_id.as_deref() == Some(crate::silu::hex(&r.model_identity).as_str()),
        "model identity declaration",
    )?;
    let s = c.shape;
    if (s.t, s.d, s.f, s.heads, s.kv_heads, s.head_dim) != (32, 16, 16, 2, 1, 8) {
        return Err(ContractError::Unsupported(
            "tiny shape T32 d16 f16 H2 Hkv1 dh8",
        ));
    }
    require(
        c.layer < 32 && (st.l, st.t_rows, st.d, st.f) == (c.layer, s.t, s.d, s.f),
        "FFN/block shape or layer",
    )?;
    if (
        r.params.log_cols,
        r.params.inv_rate,
        r.params.num_col_checks,
    ) != (8, 8, 256)
    {
        return Err(ContractError::Unsupported(
            "fixed PCS log8 inverse-rate8 checks256",
        ));
    }
    if !c.norm_round {
        return Err(ContractError::Unsupported("only round RMSNorm"));
    }
    if [c.x_cls, c.ao_cls, c.r1_cls, f.r2_cls]
        .iter()
        .any(|v| *v != Cls::Int16)
    {
        return Err(ContractError::Unsupported(
            "only INT16 input/projection/residual classes",
        ));
    }
    require(
        (c.f_e, c.f_p, c.f_ro) == (9, 9, 7),
        "fixed attention resolutions",
    )?;
    require(
        c.rope_base.to_bits() == 10000.0f64.to_bits(),
        "fixed RoPE base",
    )?;
    let exponents = [
        c.e_r,
        c.e_xn,
        c.e_r1,
        c.e_ao,
        c.e_xm,
        c.e_s_raw,
        f.e_r2,
        f.e_z16,
        e.e_wq,
        e.e_wk,
        e.e_wv,
        e.e_wo,
        e.e_q,
        e.e_k,
        e.e_v,
        e.e_qr,
        e.e_kr,
        e.e_o,
        e.e_gamma_a,
        e.e_gamma_m,
        x.e_x,
        x.e_g,
        x.e_a16,
        x.e_u16,
        x.e_h16,
        x.e_z16,
        x.e_wg,
        x.e_wu,
        x.e_wd,
    ];
    require(
        exponents.iter().all(|v| (-16..=16).contains(v)),
        "bounded scale exponents",
    )?;
    require(
        [c.sh_q, c.sh_k, c.sh_v, c.sh_s, c.sh_o, c.sh_ao]
            .iter()
            .all(|v| (0..=16).contains(v)),
        "projection/score shifts",
    )?;
    require(c.sh_qr == 7 && c.sh_kr == 7, "scale-preserving RoPE shifts")?;
    require(
        [c.sh_r1, f.sh_r2].iter().all(|v| (0..=8).contains(v))
            && [c.sh_x1, c.sh_a1, f.sh_x2, f.sh_z2].iter().all(|v| *v <= 8),
        "residual shifts",
    )?;
    require(
        c.sh_q == e.e_q - c.e_xn - e.e_wq
            && c.sh_k == e.e_k - c.e_xn - e.e_wk
            && c.sh_v == e.e_v - c.e_xn - e.e_wv,
        "QKV scale equations",
    )?;
    require(
        c.sh_qr == e.e_qr - e.e_q + 7
            && c.sh_kr == e.e_kr - e.e_k + 7
            && c.e_s_raw == e.e_qr + e.e_kr + c.sh_s,
        "RoPE/score scale equations",
    )?;
    require(
        c.sh_o == e.e_o - e.e_v + 9 && c.sh_ao == c.e_ao - e.e_o - e.e_wo,
        "output projection scales",
    )?;
    let (base1, base2) = (c.e_r.min(c.e_ao), c.e_r1.min(f.e_z16));
    require(
        c.sh_x1 == (c.e_r - base1) as u32
            && c.sh_a1 == (c.e_ao - base1) as u32
            && c.e_r1 == base1 + c.sh_r1,
        "first residual scales",
    )?;
    require(
        f.sh_x2 == (c.e_r1 - base2) as u32
            && f.sh_z2 == (f.e_z16 - base2) as u32
            && f.e_r2 == base2 + f.sh_r2,
        "second residual scales",
    )?;
    require(
        x.e_x == c.e_xm && x.e_z16 == f.e_z16 && x.shifts() == st.shifts,
        "FFN internal boundary scales",
    )?;
    let (sg, su, sh, sz) = st.shifts;
    require(
        (1..=16).contains(&sg)
            && (0..=16).contains(&su)
            && (0..=16).contains(&sh)
            && (1..=16).contains(&sz),
        "FFN shifts",
    )?;
    let (table, digest) = int16out_member(st.act, x.e_g, x.e_a16)
        .ok_or(ContractError::Invalid("frozen activation member"))?;
    require(
        st.table == table && st.table_digest == digest,
        "activation table bytes/digest",
    )?;
    require(
        c.exp_digest == exp_member(c.e_s_raw, s.head_dim, c.f_e).1,
        "exp member digest",
    )?;
    let (ct, sn) = rope_tables_generate(s.t, s.head_dim, c.rope_base, c.f_ro);
    require(
        c.rope_digest == rope_digest(s.t, s.head_dim, c.rope_base, c.f_ro, &ct, &sn),
        "RoPE member digest",
    )?;
    require(
        c.wrho_s == c.f_e + s.t.trailing_zeros(),
        "softmax remainder width",
    )?;
    let (d_a, den_a, num_a) = validate_norm(&c.anorm, e.e_gamma_a, c.e_xn)?;
    let (d_m, den_m, num_m) = validate_norm(&c.mnorm, e.e_gamma_m, c.e_xm)?;
    // All untrusted dimensions, shifts and limb counts were bounded above.
    // The existing layout constructor is now safe to use for public W shapes.
    let layout = attn_layout_of(c, f, r.params.log_cols);
    require(
        r.attention_weights.log_cols == layout.cols_log
            && r.attention_weights.rows == layout.w_len / (1usize << layout.cols_log),
        "attention W/gamma commitment shape",
    )?;
    require(
        r.ffn_weights.log_cols == 8 && r.ffn_weights.rows == 3,
        "FFN W commitment shape",
    )?;
    let scaled = 32768u64
        .checked_mul((1u64 << c.sh_x1) + (1u64 << c.sh_a1))
        .and_then(|a| {
            32768u64
                .checked_mul((1u64 << f.sh_x2) + (1u64 << f.sh_z2))
                .map(|b| a.max(b))
        })
        .ok_or(ContractError::Invalid("host residual arithmetic overflow"))?;
    Ok(HostArithmeticEnvelope {
        norm_square_sum_with_epsilon: 16 * 32768u64.pow(2) + c.anorm.ceps.max(c.mnorm.ceps) as u64,
        max_norm_d: d_a.max(d_m),
        max_round_norm_denominator: den_a.max(den_m),
        max_doubled_norm_numerator: num_a.max(num_m),
        max_scaled_residual_sum: scaled,
    })
}

fn validate_norm(
    n: &NormConsts,
    gamma_exp: i32,
    output_exp: i32,
) -> Result<(u64, u64, u64), ContractError> {
    // sqrt(d)=4 exactly in this profile, so avoid floating-point rounding and
    // assertion-prone window_rule on hostile parameters.
    let power = gamma_exp - output_exp + 2;
    let tn = (10 - power).max(0);
    require(
        tn <= 12 && (10..=11).contains(&(power + tn)),
        "norm calibration window",
    )?;
    require(
        n.tn == tn as u32 && n.cn == 1i64 << (power + tn),
        "norm tn/Cn",
    )?;
    require((1..=16).contains(&n.ceps), "norm epsilon integer")?;
    let sum = 16 * 32768i64.pow(2) + n.ceps;
    let d = crate::norm::isqrt(sum) as u64;
    let denominator = d
        .checked_shl(n.tn + 1)
        .ok_or(ContractError::Invalid("norm denominator overflow"))?;
    let width = 64 - (denominator - 1).leading_zeros();
    require(
        n.wrho == width && n.n_limbs == width.div_ceil(16) as usize,
        "fixed worst-case norm remainder width",
    )?;
    let numerator = 2u64 * 32768 * 128 * n.cn as u64;
    Ok((d, denominator, numerator))
}

// Stable, explicitly ordered and length-framed public encoding. Do not use
// Debug output, native endianness or unbound exponent documentation as identity.
fn digest_registration(r: &BlockRegistration) -> Digest {
    let mut bytes = Vec::new();
    fn u(b: &mut Vec<u8>, x: u64) {
        b.extend_from_slice(&x.to_le_bytes());
    }
    fn i(b: &mut Vec<u8>, x: i64) {
        b.extend_from_slice(&x.to_le_bytes());
    }
    fn blob(b: &mut Vec<u8>, x: &[u8]) {
        u(b, x.len() as u64);
        b.extend_from_slice(x);
    }
    fn cls(c: Cls) -> u64 {
        match c {
            Cls::Int8 => 8,
            Cls::Int16 => 16,
            Cls::Int24 => 24,
        }
    }
    let (c, f, st, e, x) = (
        &r.attention,
        &r.residual,
        &r.ffn,
        &r.attention_exponents,
        &r.ffn_exponents,
    );
    blob(&mut bytes, PROFILE);
    blob(&mut bytes, b"P1:private-input-activations-output;public-approved-weights;committed-output;round-norm;prefill-block-only");
    bytes.extend_from_slice(&r.model_identity);
    bytes.extend_from_slice(&r.calibration_identity);
    for v in [
        c.shape.t,
        c.shape.d,
        c.shape.heads,
        c.shape.kv_heads,
        c.shape.head_dim,
        c.shape.f,
        c.layer,
    ] {
        u(&mut bytes, v as u64);
    }
    for v in [c.f_e, c.f_p, c.f_ro, c.wrho_s, c.sh_x1, c.sh_a1] {
        u(&mut bytes, v as u64);
    }
    u(&mut bytes, c.rope_base.to_bits());
    u(&mut bytes, u64::from(c.norm_round));
    for v in [c.x_cls, c.ao_cls, c.r1_cls, f.r2_cls] {
        u(&mut bytes, cls(v));
    }
    for v in [
        c.e_r, c.e_xn, c.e_r1, c.e_ao, c.e_xm, c.sh_q, c.sh_k, c.sh_v, c.sh_qr, c.sh_kr, c.sh_s,
        c.e_s_raw, c.sh_o, c.sh_ao, c.sh_r1, f.sh_r2, f.e_r2, f.e_z16,
    ] {
        i(&mut bytes, v as i64);
    }
    for n in [&c.anorm, &c.mnorm] {
        u(&mut bytes, n.tn as u64);
        i(&mut bytes, n.cn);
        i(&mut bytes, n.ceps);
        u(&mut bytes, n.wrho as u64);
        u(&mut bytes, n.n_limbs as u64);
    }
    blob(&mut bytes, c.exp_digest.as_bytes());
    blob(&mut bytes, c.rope_digest.as_bytes());
    u(&mut bytes, f.sh_x2 as u64);
    u(&mut bytes, f.sh_z2 as u64);
    for v in [st.l, st.t_rows, st.d, st.f] {
        u(&mut bytes, v as u64);
    }
    for v in [st.shifts.0, st.shifts.1, st.shifts.2, st.shifts.3] {
        i(&mut bytes, v as i64);
    }
    blob(&mut bytes, st.act.spec_name().as_bytes());
    blob(&mut bytes, st.table_digest.as_bytes());
    for v in st.table {
        bytes.extend_from_slice(&v.to_le_bytes());
    }
    for v in [
        e.e_wq,
        e.e_wk,
        e.e_wv,
        e.e_wo,
        e.e_q,
        e.e_k,
        e.e_v,
        e.e_qr,
        e.e_kr,
        e.e_o,
        e.e_gamma_a,
        e.e_gamma_m,
        x.e_x,
        x.e_g,
        x.e_a16,
        x.e_u16,
        x.e_h16,
        x.e_z16,
        x.e_wg,
        x.e_wu,
        x.e_wd,
    ] {
        i(&mut bytes, v as i64);
    }
    u(&mut bytes, r.params.log_cols as u64);
    u(&mut bytes, r.params.inv_rate as u64);
    u(&mut bytes, r.params.num_col_checks as u64);
    // Mode has already been constrained to the fixed P1 policy; its model ID
    // must equal the canonical hex of the raw model identity encoded above.
    for w in [&r.attention_weights, &r.ffn_weights] {
        bytes.extend_from_slice(&w.root);
        u(&mut bytes, w.rows as u64);
        u(&mut bytes, w.log_cols as u64);
    }
    *blake3::hash(&bytes).as_bytes()
}

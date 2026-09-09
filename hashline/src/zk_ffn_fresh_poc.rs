//! Experimental paired-mask FFN proof with fresh commitments on every attempt.
//!
//! This is the first executable repair rung, not the registered/block `ffn-v3-mr1`
//! format: no stable private model identity, attention/seams, or wire decoder.
//! The public API fixes T32/d16/f16, log_cols=8, inverse rate=8, Q=256 and function 1.
//! Its private proof representation prevents callers from using it as a legacy
//! receipt. All witness-bearing commitments are dropped before `prove` returns.
use super::*;

pub const PROFILE: &[u8] = b"hashline-zk-mr1/ffn-v3-mr1-fresh-poc/1";

/// The verifier chooses the weight claim independently of the producer.
pub enum WeightStatement {
    /// A root computed from the verifier's trusted public weights.
    Public(Digest),
    /// Fresh hidden weights; this does NOT authenticate a previously named model.
    FreshPrivate,
}

pub struct Proof {
    pub(super) inner: LayerProofZk,
}

impl Proof {
    pub fn weight_root(&self) -> Digest {
        self.inner.w_com.as_ref().unwrap().root
    }
    pub fn activation_root(&self) -> Digest {
        self.inner.a_com.as_ref().unwrap().root
    }
    pub fn helper_root(&self) -> Digest {
        self.inner.h_com.as_ref().unwrap().root
    }
    /// Logical payload bytes, excluding a future transport envelope.
    pub fn payload_size(&self) -> usize {
        self.inner.size_bytes()
    }
}

pub fn parameters() -> LayerParams {
    LayerParams {
        log_cols: 8,
        inv_rate: 8,
        num_col_checks: 256,
    }
}

fn statement(w: &V3Witness) -> StatementV3 {
    StatementV3 {
        l: w.l,
        t_rows: w.t_rows,
        d: w.dims.d,
        f: w.dims.f,
        shifts: w.shifts,
        act: w.act,
        table: w.table,
        table_digest: w.table_digest.clone(),
    }
}

fn preflight(st: &StatementV3) -> Result<(), String> {
    st.check()?;
    if (st.t_rows, st.d, st.f) != (32, 16, 16) {
        return Err("fresh FFN PoC requires T32/d16/f16".into());
    }
    Ok(())
}

fn transcript(context: &[u8]) -> Transcript {
    let mut tr = Transcript::new(PROFILE);
    tr.absorb(b"request-context", context);
    tr.absorb(
        b"fixed-parameters",
        b"T32/d16/f16/log_cols8/inv_rate8/Q256/function1",
    );
    tr
}

/// No seed, reusable RNG, prepared commitment, or late opening is accepted.
/// Randomness failures return before any public proof is produced.
pub fn prove(w: &V3Witness, privacy: ZkPrivacy, context: &[u8]) -> Result<Proof, String> {
    let st = statement(w);
    preflight(&st)?;
    if privacy == ZkPrivacy::P3 && crate::wcache::dir().is_some() {
        return Err("fresh private weights cannot use the public weight cache".into());
    }
    for len in [
        w.x.len(),
        w.g8.len(),
        w.rg.len(),
        w.a16.len(),
        w.u16v.len(),
        w.ru.len(),
        w.h16.len(),
        w.rh.len(),
        w.z16.len(),
        w.rd.len(),
    ] {
        if len != 512 {
            return Err("fresh FFN PoC witness plane length".into());
        }
    }
    for weights in [&w.wg_t, &w.wu_t, &w.wd_t] {
        if weights.len() != 256 {
            return Err("fresh FFN PoC weight length".into());
        }
    }
    let rng = ZkRng::from_os(PROFILE).map_err(|e| format!("fresh proof randomness: {e}"))?;
    let cfg = ZkConfig {
        enabled: true,
        seed: None,
        mode: ZkStatementMode {
            privacy,
            ..Default::default()
        },
    };
    let out = prove_layer_zk_v3_inner(
        w,
        32,
        &parameters(),
        &NttTables::new(16),
        &cfg,
        &mut transcript(context),
        true,
        rng,
    )?;
    Ok(Proof { inner: out.proof })
}

/// Verify using only the public statement, weight claim, request context and proof.
pub fn verify(
    st: &StatementV3,
    weights: WeightStatement,
    proof: &Proof,
    context: &[u8],
) -> Result<(), String> {
    preflight(st)?;
    let privacy = match weights {
        WeightStatement::Public(root) => {
            if proof.inner.w_com.as_ref().ok_or("missing W")?.root != root {
                return Err("public weight root mismatch".into());
            }
            let unused = &proof.inner.w_open_zk;
            if !unused.group_vecs.is_empty()
                || !unused.prox_vec.is_empty()
                || !unused.columns.is_empty()
            {
                return Err("unused hiding W opening".into());
            }
            ZkPrivacy::P1
        }
        WeightStatement::FreshPrivate => {
            let unused = &proof.inner.w_open;
            if !unused.group_vecs.is_empty()
                || !unused.prox_vec.is_empty()
                || !unused.columns.is_empty()
            {
                return Err("unused public W opening".into());
            }
            ZkPrivacy::P3
        }
    };
    let mode = ZkStatementMode {
        privacy,
        ..Default::default()
    };
    verify_layer_zk_v3_inner(
        st,
        &proof.inner,
        &parameters(),
        &NttTables::new(16),
        &mut transcript(context),
        &mode,
        true,
    )
}

fn determinant(a: Fp2, b: Fp2) -> Fp {
    a.c0.mul(b.c1).sub(a.c1.mul(b.c0))
}

#[cfg(test)]
pub(super) fn check_generated_rows(data: &[Fp], n: usize, rows: &[usize]) {
    let mut seen = std::collections::BTreeSet::new();
    for &row in rows {
        let values = &data[row * n..(row + 1) * n];
        assert!(
            values.iter().any(|v| *v != values[0]),
            "constant repaired mask row"
        );
        let key: Vec<_> = values.iter().map(|v| v.0).collect();
        assert!(seen.insert(key), "reused repaired mask row values");
    }
}

pub(super) fn draw_mask_challenge(
    mut draw: impl FnMut() -> Fp2,
    repaired: bool,
) -> Result<Fp2, String> {
    if !repaired {
        return Ok(super::mask_challenge(draw));
    }
    let c = draw();
    if c.is_zero() {
        return Err("zero CFS mask challenge; discard attempt".into());
    }
    Ok(c)
}

pub(super) fn check_table_point(zl: &ZkLayoutV3, point: &[Fp2]) -> Result<(), String> {
    for t in &zl.tabs {
        if t.rows > 1 {
            let start = zl.log_s - t.log_size as usize;
            if point[start..point.len() - zl.log_n]
                .iter()
                .any(|r| r.c1.is_zero())
            {
                return Err("degenerate table mask row coordinate; discard attempt".into());
            }
        }
    }
    Ok(())
}

// Replay only the PCS challenge prefix, without advancing the live transcript.
// Claims are constructed internally, have full-width column tails, and are never
// accepted from the proof. Match PCS's first-occurrence grouping order exactly.
pub(super) fn check_masks(
    claims: &[ZClaim],
    rows: usize,
    log_n: usize,
    mask_rows: &[usize],
    prox: usize,
    tr: &Transcript,
) -> Result<(), String> {
    let n = 1usize << log_n;
    let mut groups: Vec<(Vec<Fp2>, usize)> = Vec::new();
    for claim in claims {
        let mut key = None;
        let mut coefficients = vec![Fp2::ZERO; rows];
        for part in &claim.parts {
            let bits = part.slice.log_size as usize;
            if bits < log_n
                || part.slice.offset % n != 0
                || (!part.point.is_empty() && part.point.len() != bits)
            {
                return Err("unsupported repaired claim mapping".into());
            }
            let tail = if part.point.is_empty() {
                vec![]
            } else {
                part.point[bits - log_n..].to_vec()
            };
            if let Some(k) = &key {
                if k != &tail {
                    return Err("repaired claim column mismatch".into());
                }
            }
            key = Some(tail);
            let weights = if part.point.is_empty() {
                vec![Fp2::ONE; 1usize << (bits - log_n)]
            } else {
                eq_table_msb(&part.point[..bits - log_n])
            };
            let offset = part.slice.offset / n;
            if offset + weights.len() > rows {
                return Err("repaired claim row bounds".into());
            }
            for (i, weight) in weights.into_iter().enumerate() {
                coefficients[offset + i] = coefficients[offset + i].add(part.coef.mul(weight));
            }
        }
        let masked: Vec<_> = mask_rows.iter().map(|&r| coefficients[r]).collect();
        let pivot = masked
            .iter()
            .copied()
            .find(|c| !c.is_zero())
            .ok_or("zero terminal mask challenge; discard attempt")?;
        if !masked.iter().any(|&c| !determinant(pivot, c).is_zero()) {
            return Err("mask coefficients do not span Fp2; discard attempt".into());
        }
        let key = key.ok_or("empty repaired claim")?;
        if let Some((_, count)) = groups.iter_mut().find(|(k, _)| k == &key) {
            *count += 1;
        } else {
            groups.push((key, 1));
        }
    }
    let mut replay = Transcript::clone_state(tr);
    for (_, count) in groups {
        if replay.challenge_fp2_vec(count).iter().any(|c| c.is_zero()) {
            return Err("zero group member coefficient; discard attempt".into());
        }
    }
    let rho = replay.challenge_fp2_vec(rows);
    if prox + 1 >= rows || determinant(rho[prox], rho[prox + 1]).is_zero() {
        return Err("dependent proximity mask coefficients; discard attempt".into());
    }
    Ok(())
}

//! **THE TOKEN-I/O RUN** (DESIGN v3 2.1, 3.3, 4.1): ONE transcript,
//! `L + 2` stages — stage IN, the `L` blocks (unchanged), stage OUT — under a
//! NEW run profile (D17: its own string and transcript; registered in the
//! run-profile registry, CS-7). The run's two external endpoints are the two
//! TOKEN endpoints; `x_in_L00` and the last block's output are the internal
//! two-site boundaries `B_in` and `B_out` (D12a), opened once each, in the
//! stage after their second claim exists.
//!
//! The statement binds (DESIGN 4.1, D12 item 5, D26 C-a): the block shape and
//! `L`, the block digests, the trained-model statement's identity, every
//! token-I/O constant (`V`, BOS, the final norm's constants, the head's
//! multiplier class, the derived limb count), the embedding and head digests,
//! the selector variant, the output mode and the tier's levers (D27). A
//! receipt read under any other value derives another transcript.

use super::super::boundary::{self, BoundarySpec, PreparedBoundary};
use super::super::endpoint_g::{self, EndpointRole, EndpointSpecG};
use super::super::layout::{Ids, Layout, A_X, A_X2};
use super::super::protocol::{self, CoreView};
use super::super::run::RunShape;
use super::super::shape::Shape;
use super::super::timing;
use super::super::trained_statement::TrainedModelStatement;
use super::super::wire::{self, SegGeom, Segment};
use super::super::witness::Witness;
use super::super::BlockPublic;
use super::stage_in::{self, StageInWitness};
use super::stage_out::{self, OutValues, StageOutWitness};
use super::*;
use crate::ntt::NttTables;
use crate::pcs::{self, CommittedZk, ZkOpts};
use crate::zk::ZkRng;

/// the input / output token endpoint's two digest slot fields (distinct, so
/// the two specs never share a digest; the role byte separates their seeds)
const IN_EP_SLOTS: (u64, u64) = (0x746f_6b2d_696e, 0);
const OUT_EP_SLOTS: (u64, u64) = (0x746f_6b2d_6f75_74, 10);
pub(crate) const STAGE_IN_MAGIC: &[u8; 8] = b"HLPTKIN1";
pub(crate) const STAGE_OUT_MAGIC: &[u8; 8] = b"HLPTKOT1";

/// THE TOKEN-I/O RUN STATEMENT. Everything a verifier needs, nothing a prover
/// chooses. Built only through [`TokenRunStatement::new`] (both sides).
pub(crate) struct TokenRunStatement {
    rs: RunShape,
    context: Digest,
    block_digests: Vec<Digest>,
    model_identity: Digest,
    pub(crate) tp: TokenProfile,
    pub(crate) in_spec: EndpointSpecG,
    pub(crate) out_spec: EndpointSpecG,
    in_root: Digest,
    out_root: Digest,
    /// the one boundary scale (M-4), the trained calibration's
    scale: i32,
}

/// the two token endpoints' statements at a profile (public inputs only)
pub(crate) fn endpoint_specs(sh: &Shape, context: Digest, tp: &TokenProfile) -> Result<(EndpointSpecG, EndpointSpecG), String> {
    let t = tp.tier;
    let tag = sh.hash_tag();
    let i = EndpointSpecG::new_with_tag(context, 1, tp.in_ep_words(), 0, IN_EP_SLOTS.0, IN_EP_SLOTS.1, t.ep_log_n, t.ep_inv_rate, t.opened_cols, &tag)?;
    let o = EndpointSpecG::new_with_tag(context, 1, tp.out_ep_words(), 0, OUT_EP_SLOTS.0, OUT_EP_SLOTS.1, t.ep_log_n, t.ep_inv_rate, t.opened_cols, &tag)?;
    Ok((i, o))
}

impl TokenRunStatement {
    /// The token-I/O door and the trained-model binding, in one constructor.
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new(
        rs: RunShape,
        context: Digest,
        block_digests: Vec<Digest>,
        model: &TrainedModelStatement,
        tables: &TokenTables,
        bos: u64,
        norm: FinalNorm,
        variant: SelectorVariant,
        tier: Tier,
        roots: (Digest, Digest),
    ) -> Result<TokenRunStatement, String> {
        if rs.profile() != super::super::run::RUN_PROFILE_TOKEN_IO_RUNG_TC {
            return Err(format!("token I/O run: {} is not a token-I/O run profile", rs.profile()));
        }
        if context == [0; 32] {
            return Err("token I/O run: a nonempty context is required".into());
        }
        let sh = rs.sh();
        if !sh.trained_calibration {
            return Err("token I/O run: the blocks must be a trained-calibration shape bound to its trained-model statement".into());
        }
        let l = rs.l();
        let scales = model.calibration.block_scales;
        if scales.0 != scales.1 {
            return Err("token I/O run: a boundary has ONE scale (M-4); the calibration's block scales differ".into());
        }
        model.check_against(sh, rs.profile(), &block_digests, &vec![scales; l])?;
        let tp = TokenProfile::new(sh, tables, bos, norm, variant, tier)?;
        let (in_spec, out_spec) = endpoint_specs(sh, context, &tp)?;
        Ok(TokenRunStatement { rs, context, block_digests, model_identity: model.identity(), tp, in_spec, out_spec, in_root: roots.0, out_root: roots.1, scale: scales.0 })
    }

    pub(crate) fn sh(&self) -> &Shape {
        self.rs.sh()
    }
    pub(crate) fn l(&self) -> usize {
        self.rs.l()
    }
    pub(crate) fn roots(&self) -> (Digest, Digest) {
        (self.in_root, self.out_root)
    }

    /// boundary `j` of the run (`0 ..= L`): `B_in` is 0, `B_out` is `L`; the
    /// block's internal-boundary geometry, two sites, its index `j + 1`
    pub(crate) fn boundary_spec(&self, j: usize) -> Result<BoundarySpec, String> {
        let sh = self.sh();
        if j > self.l() {
            return Err(format!("token I/O run: boundary {j} is not one of this run's {}", self.l() + 1));
        }
        BoundarySpec::new_with_tag(self.context, sh.t_pad, sh.d_pad, self.scale, (j + 1) as u64, 2, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows + 1, &sh.hash_tag())
    }

    fn expected_bytes(&self) -> Vec<u8> {
        let mut v = Vec::with_capacity(16 + 4 * 32);
        v.extend_from_slice(b"token-io-expected/v1");
        v.extend_from_slice(&self.in_spec.digest());
        v.extend_from_slice(&self.in_root);
        v.extend_from_slice(&self.out_spec.digest());
        v.extend_from_slice(&self.out_root);
        v
    }

    fn public_statement(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/token-io-run-blocks/v1");
        for d in &self.block_digests {
            h.update(d);
        }
        h.update(&self.tp.emb_digest);
        h.update(&self.tp.head_digest);
        *h.finalize().as_bytes()
    }

    fn calibration(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/token-io-calibration/v1");
        h.update(&self.model_identity);
        h.update(&self.tp.digest());
        *h.finalize().as_bytes()
    }

    pub(crate) fn parameter_line(&self) -> Result<String, String> {
        let sh = self.sh();
        let b = self.boundary_spec(0)?;
        let t = self.tp.tier;
        Ok(format!(
            "{}/L{}/boundaries-B_in-B_out-and-interior-log_n{}-rate{}-pad{}-rows{}-sites2/token-endpoints-log_n{}-rate{}-pad{}-in-words{}-in-rows{}-out-words{}-out-rows{}-sites1/stages-log_n{}-rate{}-pad{}/{}/one-run-one-transcript",
            protocol::parameter_line(sh),
            self.l(),
            sh.endpoint_log_n,
            sh.endpoint_inv_rate,
            sh.opened_cols,
            b.commitment_rows(),
            t.ep_log_n,
            t.ep_inv_rate,
            t.opened_cols,
            self.tp.in_ep_words(),
            self.in_spec.commitment_rows(),
            self.tp.out_ep_words(),
            self.out_spec.commitment_rows(),
            t.stage_log_n,
            t.stage_inv_rate,
            t.opened_cols,
            self.tp.describe()
        ))
    }

    /// what each stage commits, which pair each claim takes, what it opens
    /// (D26 C-a / C-b: the verifier reads the opening places from here)
    pub(crate) fn stage_lines(&self) -> Result<Vec<String>, String> {
        let l = self.l();
        let mut out = Vec::with_capacity(l + 2);
        let b0 = self.boundary_spec(0)?;
        out.push(format!(
            "stage 00 (IN): commits boundary 1 = B_in; IN-01 claims B_in at pair row {}; IN-00 claims the input token endpoint at pair row {}; opens M A H then the input token endpoint",
            b0.mask_row(0)?,
            self.in_spec.data_rows()
        ));
        for k in 0..l {
            let (p, q) = (self.boundary_spec(k)?, self.boundary_spec(k + 1)?);
            out.push(format!(
                "stage {:02} (block {k}): commits boundary {}{}; slot 21 claims boundary {} at pair row {}; slot 22 claims boundary {} at pair row {}; opens M A H then boundary {}; data rows {}",
                k + 1,
                k + 2,
                if k + 1 == l { " = B_out" } else { "" },
                k + 1,
                p.mask_row(1)?,
                k + 2,
                q.mask_row(0)?,
                k + 1,
                p.data_rows()
            ));
        }
        let bl = self.boundary_spec(l)?;
        out.push(format!(
            "stage {:02} (OUT): OUT-00 claims boundary {} = B_out at the fixed public row {} at pair row {}; OUT-10 claims the output token endpoint at pair row {}; opens M A H then B_out then the output token endpoint",
            l + 1,
            l + 1,
            self.tp.tokens - 1,
            bl.mask_row(1)?,
            self.out_spec.data_rows()
        ));
        Ok(out)
    }

    fn schedule_digest(&self) -> Result<Digest, String> {
        let sh = self.sh();
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/token-io-run-schedule/v1");
        let mut line = |s: &str| {
            h.update(&(s.len() as u64).to_le_bytes());
            h.update(s.as_bytes());
        };
        line(&self.parameter_line()?);
        for s in Layout::for_shape(sh)?.describe() {
            line(&s);
        }
        for s in stage_in::layout(sh, &self.tp).describe() {
            line(&s);
        }
        for s in stage_out::layout(sh, &self.tp).describe() {
            line(&s);
        }
        for s in self.stage_lines()? {
            line(&s);
        }
        Ok(*h.finalize().as_bytes())
    }

    /// the run header, absorbed before any commitment exists
    pub(crate) fn transcript(&self) -> Result<Transcript, String> {
        let sh = self.sh();
        let mut tr = protocol::tagged_transcript(sh, self.rs.profile().as_bytes());
        let mut shape_bytes = Vec::with_capacity(8 * 8);
        for v in [self.l(), sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim, self.tp.v] {
            shape_bytes.extend_from_slice(&(v as u64).to_le_bytes());
        }
        tr.absorb(b"run-shape", &shape_bytes);
        tr.absorb(b"expected-IO", &self.expected_bytes());
        tr.absorb(b"public-statement", &self.public_statement());
        tr.absorb(b"parameters", self.parameter_line()?.as_bytes());
        tr.absorb(b"calibration", &self.calibration());
        tr.absorb(b"schedule", &self.schedule_digest()?);
        Ok(tr)
    }

    /// the NTT domain one run needs: the block's, the boundaries', the
    /// stages', the token endpoints' and the mask commitment's
    fn ntt_log(&self) -> u32 {
        let sh = self.sh();
        let t = self.tp.tier;
        [
            protocol::ntt_log_at(sh),
            (sh.endpoint_log_n + sh.endpoint_inv_rate.trailing_zeros() as usize) as u32,
            (t.stage_log_n + t.stage_inv_rate.trailing_zeros() as usize) as u32,
            (t.ep_log_n + t.ep_inv_rate.trailing_zeros() as usize) as u32,
            crate::zk::MASK_LOG_DOM,
        ]
        .into_iter()
        .max()
        .unwrap_or(crate::zk::MASK_LOG_DOM)
    }

    fn in_geom<'a>(&self, lay: &'a StageLayout) -> StageSegGeom<'a> {
        let ed = Dim::of(&self.in_spec.params());
        StageSegGeom { magic: STAGE_IN_MAGIC, lay, has_b_root: true, a_groups: stage_in::A_GROUPS, h_groups: stage_in::H_GROUPS, closes: vec![(ed, 1, self.in_spec.commitment_rows())], total: self.l() + 2, index: 0 }
    }

    fn out_geom<'a>(&self, lay: &'a StageLayout) -> Result<StageSegGeom<'a>, String> {
        let b = self.boundary_spec(self.l())?;
        let (bd, ed) = (Dim::of(&b.params()), Dim::of(&self.out_spec.params()));
        Ok(StageSegGeom {
            magic: STAGE_OUT_MAGIC,
            lay,
            has_b_root: false,
            a_groups: stage_out::A_GROUPS,
            h_groups: stage_out::H_GROUPS,
            closes: vec![(bd, 2, b.commitment_rows()), (ed, 1, self.out_spec.commitment_rows())],
            total: self.l() + 2,
            index: self.l() + 1,
        })
    }

    fn block_geom(&self, k: usize) -> Result<SegGeom, String> {
        Ok(SegGeom { l: self.l() + 2, k: k + 1, boundary_rows: self.boundary_spec(0)?.commitment_rows(), sites: 2 })
    }

    fn block_layout(&self, k: usize) -> Result<Layout, String> {
        Ok(Layout::for_shape(self.sh())?.with_io_mask_rows([self.boundary_spec(k)?.mask_row(1)?, self.boundary_spec(k + 1)?.mask_row(0)?]))
    }

    /// the counted byte length of every segment, in order
    pub(crate) fn segment_lens(&self) -> Result<Vec<usize>, String> {
        let sh = self.sh();
        let mut v = vec![self.in_geom(&stage_in::layout(sh, &self.tp)).len()];
        for k in 0..self.l() {
            v.push(wire::segment_len(&self.block_layout(k)?, self.block_geom(k)?));
        }
        v.push(self.out_geom(&stage_out::layout(sh, &self.tp))?.len());
        Ok(v)
    }
}

/// a transcript position tag (`run::position_tag`): squeezed from a clone
fn position_tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

/// The two token endpoints' private owners (D18: the prover seals both before
/// the run header exists; the whole forward pass has run by then, ruling H-1).
pub(crate) struct TokenOwners {
    pub input: CommittedZk,
    pub output: CommittedZk,
}

/// Seal both token endpoints: `(roots, owners)`.
pub(crate) fn seal_endpoints(in_spec: &EndpointSpecG, out_spec: &EndpointSpecG, in_plane: &[Fp], out_plane: &[Fp], tag: &zkp_core::hashtag::HashTag) -> Result<((Digest, Digest), TokenOwners), String> {
    let log = in_spec.enc_log().max(out_spec.enc_log());
    let ntt = NttTables::new(log);
    let i = endpoint_g::prepare(in_spec, in_plane, &ntt, tag, EndpointRole::Input)?.into_endpoint(in_spec)?;
    let o = endpoint_g::prepare(out_spec, out_plane, &ntt, tag, EndpointRole::Output)?.into_endpoint(out_spec)?;
    Ok(((i.commitment().root, o.commitment().root), TokenOwners { input: i, output: o }))
}

/// The private inputs of a token run, one stage at a time (a test source may
/// lie about any of them: the tamper controls).
pub(crate) trait TokenRunSource {
    /// `A_in`'s planes and the `B_in` plane
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String>;
    /// block `k`'s integer witness
    fn witness(&mut self, k: usize) -> Result<Witness, String>;
    /// the padded plane after block `k` (boundary `k + 1`; `B_out` at `L - 1`)
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String>;
    /// `A_out`'s planes
    fn stage_out(&mut self) -> Result<StageOutWitness, String>;
}

#[derive(Debug, Default)]
pub(crate) struct TokenRunStats {
    pub prove_s: Vec<f64>,
    pub segment_bytes: Vec<usize>,
    pub hwm_mib: Vec<f64>,
}

/// What the run prover hands the two endpoint OWNERS privately (D25 T5, D21).
pub(crate) struct OwnerHandoff {
    pub input: Decommitment,
    pub output: Decommitment,
}

/// **THE TOKEN-I/O RUN PROVER.** One transcript, one OS stream, `L + 2`
/// segments, each handed to `sink` and dropped (M-3).
pub(crate) fn prove_token_run(
    st: &TokenRunStatement,
    blocks: &[BlockPublic],
    tables: &TokenTables,
    src: &mut dyn TokenRunSource,
    owners: TokenOwners,
    sink: &mut dyn FnMut(usize, Vec<u8>) -> Result<(), String>,
) -> Result<(TokenRunStats, OwnerHandoff), String> {
    use std::time::Instant;
    let (sh, l, tp) = (st.sh(), st.l(), &st.tp);
    #[cfg(test)]
    let cheating = protocol::cheating_prover_is_on();
    #[cfg(not(test))]
    let cheating = false;
    if tp.variant != SelectorVariant::PublicRow {
        return Err(format!("token I/O run: the {} variant is not built at R1 (D26's two-site endpoint is the next rung)", tp.variant.tag()));
    }
    if blocks.len() != l {
        return Err(format!("token I/O run: the statement names {l} blocks and {} were handed", blocks.len()));
    }
    protocol::fits_the_ntt_tables(sh)?;
    for (k, b) in blocks.iter().enumerate() {
        b.check_for_shape(sh).map_err(|e| format!("token I/O run: block {k}: {e}"))?;
        if !cheating && b.digest() != st.block_digests[k] {
            return Err(format!("token I/O run: ruling CS-6 — block {k} is not the block the statement names"));
        }
    }
    if tables.emb_digest() != tp.emb_digest || tables.head_digest() != tp.head_digest {
        return Err("token I/O run: the tables handed are not the ones the statement names".into());
    }
    if owners.input.commitment().root != st.in_root || owners.output.commitment().root != st.out_root || owners.input.cm.rows != st.in_spec.commitment_rows() || owners.output.cm.rows != st.out_spec.commitment_rows() {
        return Err("token I/O run: the token endpoint owners are not the statement's".into());
    }
    let mut rng = ZkRng::from_os(&super::super::hash_domain::run_seed_domain(st.rs.profile())).map_err(|e| format!("token I/O run randomness: {e}"))?;
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript()?;
    let binding = tr.state();
    let mut stats = TokenRunStats::default();
    let TokenOwners { input: in_ep, output: out_ep } = owners;

    // ---- stage IN
    let t0 = Instant::now();
    let start = position_tag(&tr);
    let (win, b_in_plane) = src.stage_in()?;
    let in_lay = stage_in::layout(sh, tp);
    let b0 = st.boundary_spec(0)?;
    let inp = stage_in::prove(&in_lay, tp, tables, win, &b0, &b_in_plane, in_ep, &ntt, &mut rng, &mut tr, &tag)?;
    let end = position_tag(&tr);
    let bytes = st.in_geom(&in_lay).encode(&inp.seg, &binding, &start, &end)?;
    stats.segment_bytes.push(bytes.len());
    sink(0, bytes)?;
    stats.prove_s.push(t0.elapsed().as_secs_f64());
    stats.hwm_mib.push(super::super::run::peak_rss_mib());
    let in_dec = inp.decommitment;
    let mut pending: Vec<ZClaim> = inp.pending_b;
    let mut prev: (BoundarySpec, PreparedBoundary) = (b0, inp.b_owner);

    // ---- the blocks, unchanged
    for k in 0..l {
        let t0 = Instant::now();
        let mut ph = timing::Phases::start();
        let mut phases: Vec<(&'static str, f64)> = Vec::new();
        let mut tick = Instant::now();
        let start = position_tag(&tr);
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let spec = st.boundary_spec(k + 1)?;
        let plane = src.boundary_plane(k)?;
        if plane.len() != spec.len() {
            return Err(format!("token I/O run: boundary {}'s plane is {} words, the padded plane is {}", k + 1, plane.len(), spec.len()));
        }
        let words: Vec<Fp> = plane.iter().map(|x| Fp::from_i64(i64::from(*x))).collect();
        let cur = boundary::prepare(&spec, &words, &ntt, &mut rng, &tag)?;
        protocol::absorb_root(&mut tr, b"B", &cur.root(), spec.commitment_rows(), spec.log_n());
        let lay = st.block_layout(k)?;
        let wit = src.witness(k)?;
        let core = protocol::prove_core(sh, &lay, &blocks[k], wit, [prev.1.data(), cur.data()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)?;
        let [ic, oc] = core.io_claims;
        let mut claims = std::mem::take(&mut pending);
        claims.extend(ic);
        let (pspec, powner) = prev;
        let in_open = powner.into_opening(&pspec, &claims, &mut tr)?;
        pending = oc;
        let end = position_tag(&tr);
        let seg = Segment { b_root: Some(cur.root()), a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open, in_open, out_open: None };
        let bytes = wire::encode_segment(&seg, &lay, st.block_geom(k)?, &binding, &start, &end)?;
        drop(seg);
        stats.segment_bytes.push(bytes.len());
        sink(k + 1, bytes)?;
        prev = (spec, cur);
        stats.prove_s.push(t0.elapsed().as_secs_f64());
        stats.hwm_mib.push(super::super::run::peak_rss_mib());
    }

    // ---- stage OUT
    let t0 = Instant::now();
    let start = position_tag(&tr);
    let wout = src.stage_out()?;
    let out_lay = stage_out::layout(sh, tp);
    let (bspec, bowner) = prev;
    let outp = stage_out::prove(&out_lay, tp, tables, wout, &bspec, bowner, pending, out_ep, (l + 1) as u64, &ntt, &mut rng, &mut tr, &tag)?;
    let end = position_tag(&tr);
    let bytes = st.out_geom(&out_lay)?.encode(&outp.seg, &binding, &start, &end)?;
    stats.segment_bytes.push(bytes.len());
    sink(l + 1, bytes)?;
    stats.prove_s.push(t0.elapsed().as_secs_f64());
    stats.hwm_mib.push(super::super::run::peak_rss_mib());
    Ok((stats, OwnerHandoff { input: in_dec, output: outp.decommitment }))
}

/// **THE TOKEN-I/O RUN VERIFIER.** Exactly `L + 2` segments, `L` being its
/// own; every geometry, opening place and claim from its own statement.
pub(crate) fn verify_token_run(st: &TokenRunStatement, blocks: &[BlockPublic], tables: &TokenTables, segments: &[Vec<u8>]) -> Result<(), String> {
    let (sh, l, tp) = (st.sh(), st.l(), &st.tp);
    if blocks.len() != l || segments.len() != l + 2 {
        return Err(format!("token I/O run: {} blocks and {} segments were offered, this run has {l} blocks and {} segments", blocks.len(), segments.len(), l + 2));
    }
    protocol::fits_the_ntt_tables(sh)?;
    for (k, b) in blocks.iter().enumerate() {
        b.check_for_shape(sh).map_err(|e| format!("token I/O run: block {k}: {e}"))?;
        if b.digest() != st.block_digests[k] {
            return Err(format!("token I/O run: ruling CS-6 — block {k} is not the block the statement names"));
        }
    }
    if tables.emb_digest() != tp.emb_digest || tables.head_digest() != tp.head_digest {
        return Err("token I/O run: the tables handed are not the ones the statement names".into());
    }
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript()?;
    let binding = tr.state();

    // ---- stage IN
    let in_lay = stage_in::layout(sh, tp);
    let start = position_tag(&tr);
    let (seg, end) = st.in_geom(&in_lay).decode(&segments[0], &binding, &start)?;
    let b0 = st.boundary_spec(0)?;
    let (mut pending, b_root) = stage_in::verify(&in_lay, tp, tables, &seg, &b0, &st.in_spec, &st.in_root, &ntt, &mut tr, &tag)?;
    if position_tag(&tr) != end {
        return Err("token I/O run: stage IN's trailer is not the verifier's own transcript position".into());
    }
    let mut prev: (BoundarySpec, Digest) = (b0, b_root);

    // ---- the blocks
    for k in 0..l {
        let mut ph = timing::Phases::start();
        let lay = st.block_layout(k)?;
        let start = position_tag(&tr);
        let (seg, end) = wire::decode_segment(&segments[k + 1], &lay, st.block_geom(k)?, &binding, &start)?;
        super::super::hash_domain::segment_paths_are_the_tree_depth(&seg, sh)?;
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let spec = st.boundary_spec(k + 1)?;
        let root = seg.b_root.ok_or_else(|| format!("token I/O run: block segment {k} carries no boundary root"))?;
        protocol::absorb_root(&mut tr, b"B", &root, spec.commitment_rows(), spec.log_n());
        let view = CoreView { a_root: seg.a_root, h_root: seg.h_root, mask_root: seg.mask_root, slots: &seg.slots, mask_open: &seg.mask_open, a_open: &seg.a_open, h_open: &seg.h_open };
        let ([ic, oc], _) = protocol::verify_core(sh, &lay, &blocks[k], view, &ntt, &mut tr, &mut ph).map_err(|e| format!("block {k}: {e}"))?;
        let mut claims = std::mem::take(&mut pending);
        claims.extend(ic);
        let (pspec, proot) = prev;
        boundary::check_opening(&pspec, &claims, &tr)?;
        let bp = pspec.params();
        pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(proot, pspec.commitment_rows(), pspec.log_n()), &claims, &seg.in_open, &ntt, &mut tr, &tag).map_err(|e| format!("boundary {k}{}: {e}", if k == 0 { " (B_in)" } else { "" }))?;
        pending = oc;
        prev = (spec, root);
        if position_tag(&tr) != end {
            return Err(format!("token I/O run: block segment {k}'s trailer is not the verifier's own transcript position"));
        }
    }

    // ---- stage OUT
    let out_lay = stage_out::layout(sh, tp);
    let start = position_tag(&tr);
    let (seg, end) = st.out_geom(&out_lay)?.decode(&segments[l + 1], &binding, &start)?;
    let (bspec, broot) = prev;
    stage_out::verify(&out_lay, tp, tables, &seg, &bspec, &broot, pending, &st.out_spec, &st.out_root, (l + 1) as u64, &ntt, &mut tr, &tag)?;
    if position_tag(&tr) != end {
        return Err("token I/O run: stage OUT's trailer is not the verifier's own transcript position".into());
    }
    Ok(())
}

// ---------------------------------------------------------------- the honest pipeline

/// The whole forward pass a production caller runs BEFORE sealing the
/// endpoints (ruling H-1): prompt -> `B_in` -> each block's witness -> `B_out`
/// -> the final norm, the head and the greedy token. Every refusal of every
/// witness builder fires here, before any header exists.
pub(crate) struct HonestPipeline {
    pub tokens: Vec<u64>,
    pub stage_in: StageInWitness,
    pub b_in: Vec<i16>,
    pub witnesses: Vec<Option<Witness>>,
    /// the padded plane after each block (`B_out` last)
    pub planes: Vec<Vec<i16>>,
    pub out_values: OutValues,
    pub stage_out: StageOutWitness,
    pub in_plane: Vec<Fp>,
    pub out_plane: Vec<Fp>,
}

pub(crate) fn honest_pipeline(sh: &Shape, tp: &TokenProfile, tables: &TokenTables, blocks: &[BlockPublic], tokens: &[u64]) -> Result<HonestPipeline, String> {
    let (wit_in, b_in, in_plane) = stage_in::honest_inputs(tp, tables, tokens)?;
    let (witnesses, planes, ov, wout, out_plane) = downstream(sh, tp, tables, blocks, &b_in, true)?;
    Ok(HonestPipeline { tokens: tokens.to_vec(), stage_in: wit_in, b_in, witnesses, planes, out_values: ov, stage_out: wout, in_plane, out_plane })
}

/// Everything downstream of a `B_in` plane: the blocks' witnesses, the plane
/// after each block, the stage-OUT values and witness, the output endpoint's
/// plane. `check` = false lets a cheating prover past the final norm's
/// refusals (the tamper controls).
#[allow(clippy::type_complexity)]
pub(crate) fn downstream(sh: &Shape, tp: &TokenProfile, tables: &TokenTables, blocks: &[BlockPublic], b_in: &[i16], check: bool) -> Result<(Vec<Option<Witness>>, Vec<Vec<i16>>, OutValues, StageOutWitness, Vec<Fp>), String> {
    let ids = Ids::new(sh)?;
    let mut x: Vec<i16> = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| b_in[t * sh.d_pad + i]).collect();
    let mut witnesses = Vec::with_capacity(blocks.len());
    let mut planes = Vec::with_capacity(blocks.len());
    for (k, b) in blocks.iter().enumerate() {
        let w = super::super::witness::build_shaped(sh, b.attention(), b.feed_forward(), &x).map_err(|e| format!("token I/O pipeline: block {k}: {e}"))?;
        let plane: Vec<i16> = w.planes[ids.at(A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| "token I/O pipeline: a block output outside int16".to_string())).collect::<Result<Vec<i16>, String>>()?;
        if k == 0 && w.planes[ids.at(A_X)].iter().zip(b_in.iter()).any(|(a, b)| *a != i64::from(*b)) {
            return Err("token I/O pipeline: block 0's input plane is not B_in".into());
        }
        x = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect();
        planes.push(plane);
        witnesses.push(Some(w));
    }
    let b_out = planes.last().ok_or("token I/O pipeline: no block")?;
    let ov = stage_out::out_values(tp, tables, &stage_out::row_of(tp, b_out, tp.tokens - 1), check)?;
    let wout = stage_out::witness_from_values(tp, &ov)?;
    let out_plane = stage_out::endpoint_plane(tp, ov.tok as u64);
    Ok((witnesses, planes, ov, wout, out_plane))
}

/// the honest source: hands out the pipeline's own values, each once
pub(crate) struct PipelineSource<'a>(pub &'a mut HonestPipeline);

impl TokenRunSource for PipelineSource<'_> {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        Ok((self.0.stage_in.clone(), self.0.b_in.clone()))
    }
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.0.witnesses.get_mut(k).and_then(|w| w.take()).ok_or_else(|| format!("token I/O pipeline: block {k}'s witness was already consumed"))
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.0.planes.get(k).cloned().ok_or_else(|| format!("token I/O pipeline: no plane after block {k}"))
    }
    fn stage_out(&mut self) -> Result<StageOutWitness, String> {
        Ok(self.0.stage_out.clone())
    }
}

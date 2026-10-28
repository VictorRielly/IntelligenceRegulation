//! **THE CLASSIFIER RUN** (DESIGN_CLASSIFIER v2, rung R-C1): ONE transcript,
//! `L + 2` stages — stage IN-C, the `L` blocks (unchanged), stage OUT-C —
//! under the classifier run profile. One external endpoint (the input token
//! plane: template and content); the PUBLIC verdict in the statement.
//!
//! **The sealing pass (ruling H-1, the t34 lesson applied up front).** Before
//! the run header exists the prover checks every input-provokable refusal:
//! stage IN-C's lookup, template ids and control-id rule, the input
//! endpoint's sealed plane, every block's CS-1 / CS-4 / CS-6 check and its
//! CS-3 lookup-miss check, and stage OUT-C's bytes, limb pads and the
//! verdict-margin identity. A refused run builds no header and hands the sink
//! nothing. A new file; the frozen next-token run is untouched.

use super::super::boundary::{self, BoundarySpec, PreparedBoundary};
use super::super::layout::{Ids, A_X, A_X2};
use super::super::protocol::{self, CoreView};
use super::super::timing;
use super::super::wire::{self, Segment};
use super::super::witness::Witness;
use super::super::BlockPublic;
use super::classify::*;
use super::run::{ResidentBlocks, TokenBlocks, VerifierPolicy};
use super::stage_in::StageInWitness;
use super::stage_out_c::{OutCValues, StageOutCWitness};
use super::*;
use crate::ntt::NttTables;
use crate::pcs::{self, CommittedZk, ZkOpts};
use crate::zk::ZkRng;

fn position_tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

/// The private inputs of a classifier run, one stage at a time (a test
/// source may lie about any of them: the tamper controls).
pub(crate) trait ClassifyRunSource {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String>;
    fn witness(&mut self, k: usize, blk: &BlockPublic, sh: &Shape) -> Result<Witness, String>;
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String>;
    fn stage_out(&mut self) -> Result<StageOutCWitness, String>;
    fn seal_check(&mut self, k: usize, blk: &BlockPublic, sh: &Shape, check: &mut dyn FnMut(&Witness) -> Result<(), String>) -> Result<(), String>;
}

#[derive(Debug, Default)]
pub(crate) struct ClassifyRunStats {
    pub prove_s: Vec<f64>,
    pub segment_bytes: Vec<usize>,
}

#[cfg(test)]
thread_local! {
    /// test only: classifier run headers built on this thread
    static CLASSIFY_HEADERS: std::cell::Cell<u64> = const { std::cell::Cell::new(0) };
}

/// test only: classifier run headers built on this thread so far
#[cfg(test)]
pub(crate) fn classify_headers() -> u64 {
    CLASSIFY_HEADERS.with(|c| c.get())
}

fn stage_block_is_the_statements(st: &ClassifyRunStatement, k: usize, blk: &BlockPublic, cs6: bool) -> Result<(), String> {
    blk.check_for_shape(&st.stage_shape(k)?).map_err(|e| format!("classifier run: block {k}: {e}"))?;
    if cs6 && blk.digest() != st.block_digests[k] {
        return Err(format!("classifier run: ruling CS-6 — block {k} is not the block the statement names"));
    }
    Ok(())
}

fn endpoint_is_the_witnesss(ep: &CommittedZk, spec: &super::super::endpoint_g::EndpointSpecG, plane: &[Fp]) -> Result<(), String> {
    if plane.len() != spec.len() || ep.data.len() < spec.len() || ep.data[..spec.len()] != *plane {
        return Err("classifier: the input token endpoint's sealed plane is not stage IN-C's (refused in the sealing pass, before any header)".into());
    }
    Ok(())
}

/// **THE CLASSIFIER RUN PROVER** over a resident slice of blocks
pub(crate) fn prove_classify_run(
    st: &ClassifyRunStatement,
    blocks: &[BlockPublic],
    tables: &ClassifierTables,
    src: &mut dyn ClassifyRunSource,
    owner: CommittedZk,
    sink: &mut dyn FnMut(usize, Vec<u8>) -> Result<(), String>,
) -> Result<(ClassifyRunStats, Decommitment), String> {
    prove_classify_run_with(st, &mut ResidentBlocks(blocks), tables, src, owner, sink)
}

/// **THE CLASSIFIER RUN PROVER.** One transcript, `L + 2` segments handed to
/// `sink` (UNPUBLISHED until this returns Ok), block `k` at its own stage.
pub(crate) fn prove_classify_run_with(
    st: &ClassifyRunStatement,
    blocks: &mut dyn TokenBlocks,
    tables: &ClassifierTables,
    src: &mut dyn ClassifyRunSource,
    owner: CommittedZk,
    sink: &mut dyn FnMut(usize, Vec<u8>) -> Result<(), String>,
) -> Result<(ClassifyRunStats, Decommitment), String> {
    use std::time::Instant;
    let (sh, l, cp) = (st.sh(), st.l(), &st.cp);
    #[cfg(test)]
    let cheating = protocol::cheating_prover_is_on();
    #[cfg(not(test))]
    let cheating = false;
    rulings_are_built()?;
    if blocks.count() != l {
        return Err(format!("classifier run: the statement names {l} blocks and {} were handed", blocks.count()));
    }
    protocol::fits_the_ntt_tables(sh)?;
    if tables.emb_digest() != cp.emb_digest || tables.w_digest() != cp.w_digest {
        return Err("classifier run: the tables handed are not the ones the statement names".into());
    }
    if owner.commitment().root != st.in_root() || owner.cm.rows != st.in_spec.commitment_rows() {
        return Err("classifier run: the input endpoint owner is not the statement's".into());
    }
    // ---- THE SEALING PASS (H-1): every refusal before the run header
    let (win, b_in_plane) = src.stage_in()?;
    if !cheating {
        super::stage_in_c::lookup_misses(cp, tables, &win, &b_in_plane).map_err(|e| format!("{e} (refused in the sealing pass, before any header)"))?;
        let toks: Vec<u64> = win.tok[..cp.tokens].iter().map(|x| x.0).collect();
        endpoint_is_the_witnesss(&owner, &st.in_spec, &input_plane(cp, &toks))?;
    }
    for k in 0..l {
        let blk = blocks.block(k)?;
        stage_block_is_the_statements(st, k, &blk, !cheating)?;
        let (ssh, lay) = (st.stage_shape(k)?, st.block_layout(k)?);
        src.seal_check(k, &blk, &ssh, &mut |w| if cheating { Ok(()) } else { protocol::check_lookup_misses(&ssh, &lay, &blk, w).map_err(|e| format!("block {k}: {e} (refused in the sealing pass, before any header)")) })?;
    }
    let wout = src.stage_out()?;
    let out_lay = super::stage_out_c::layout(sh, cp);
    if !cheating {
        super::stage_out_c::seal_check(&out_lay, cp, tables, &wout, st.verdict()).map_err(|e| format!("{e} (refused in the sealing pass, before any header)"))?;
    }
    let mut rng = ZkRng::from_os(&super::super::hash_domain::run_seed_domain(st.profile())).map_err(|e| format!("classifier run randomness: {e}"))?;
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript()?;
    #[cfg(test)]
    CLASSIFY_HEADERS.with(|c| c.set(c.get() + 1));
    let binding = tr.state();
    let mut stats = ClassifyRunStats::default();

    // ---- stage IN-C
    let t0 = Instant::now();
    let start = position_tag(&tr);
    let in_lay = super::stage_in_c::layout(sh, cp);
    let b0 = st.boundary_spec(0)?;
    let inp = super::stage_in_c::prove(&in_lay, cp, tables, win, &b0, &b_in_plane, owner, &ntt, &mut rng, &mut tr, &tag)?;
    let end = position_tag(&tr);
    let bytes = st.in_geom(&in_lay).encode(&inp.seg, &binding, &start, &end)?;
    stats.segment_bytes.push(bytes.len());
    sink(0, bytes)?;
    stats.prove_s.push(t0.elapsed().as_secs_f64());
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
        let blk = blocks.block(k)?;
        stage_block_is_the_statements(st, k, &blk, !cheating)?;
        let spec = st.boundary_spec(k + 1)?;
        let plane = src.boundary_plane(k)?;
        if plane.len() != spec.len() {
            return Err(format!("classifier run: boundary {}'s plane is {} words, the padded plane is {}", k + 1, plane.len(), spec.len()));
        }
        let words: Vec<Fp> = plane.iter().map(|x| Fp::from_i64(i64::from(*x))).collect();
        let cur = boundary::prepare(&spec, &words, &ntt, &mut rng, &tag)?;
        protocol::absorb_root(&mut tr, b"B", &cur.root(), spec.commitment_rows(), spec.log_n());
        let lay = st.block_layout(k)?;
        let ssh = st.stage_shape(k)?;
        let wit = src.witness(k, &blk, &ssh)?;
        let core = protocol::prove_core(&ssh, &lay, &blk, wit, [prev.1.data(), cur.data()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)?;
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
        drop(blk);
        stats.prove_s.push(t0.elapsed().as_secs_f64());
    }

    // ---- stage OUT-C
    let t0 = Instant::now();
    let start = position_tag(&tr);
    let (bspec, bowner) = prev;
    let outp = super::stage_out_c::prove(&out_lay, cp, tables, wout, st.verdict(), &bspec, bowner, pending, (l + 1) as u64, &ntt, &mut rng, &mut tr, &tag)?;
    let end = position_tag(&tr);
    let bytes = st.out_geom(&out_lay)?.encode(&outp.seg, &binding, &start, &end)?;
    stats.segment_bytes.push(bytes.len());
    sink(l + 1, bytes)?;
    stats.prove_s.push(t0.elapsed().as_secs_f64());
    Ok((stats, in_dec))
}

/// **THE CLASSIFIER RUN VERIFIER** over a resident slice of blocks
pub(crate) fn verify_classify_run(st: &ClassifyRunStatement, blocks: &[BlockPublic], tables: &ClassifierTables, segments: &[Vec<u8>], policy: VerifierPolicy) -> Result<(), String> {
    verify_classify_run_with(st, &mut ResidentBlocks(blocks), tables, segments, policy)
}

/// **THE CLASSIFIER RUN VERIFIER.** Exactly `L + 2` segments; every geometry,
/// opening place and claim from its own statement, the verdict the
/// statement's.
pub(crate) fn verify_classify_run_with(st: &ClassifyRunStatement, blocks: &mut dyn TokenBlocks, tables: &ClassifierTables, segments: &[Vec<u8>], policy: VerifierPolicy) -> Result<(), String> {
    let (sh, l, cp) = (st.sh(), st.l(), &st.cp);
    rulings_are_built()?;
    cp.tier.check()?;
    if st.whole_run().floor_bits < policy.min_whole_run_bits {
        return Err(format!("classifier run: the statement's derived whole-run figure ({} bits) is below the verifier's minimum of {} bits (D27 policy)", st.whole_run().floor_bits, policy.min_whole_run_bits));
    }
    if blocks.count() != l || segments.len() != l + 2 {
        return Err(format!("classifier run: {} blocks and {} segments were offered, this run has {l} blocks and {} segments", blocks.count(), segments.len(), l + 2));
    }
    protocol::fits_the_ntt_tables(sh)?;
    if tables.emb_digest() != cp.emb_digest || tables.w_digest() != cp.w_digest {
        return Err("classifier run: the tables handed are not the ones the statement names".into());
    }
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript()?;
    let binding = tr.state();

    // ---- stage IN-C
    let in_lay = super::stage_in_c::layout(sh, cp);
    let start = position_tag(&tr);
    let (seg, end) = st.in_geom(&in_lay).decode(&segments[0], &binding, &start)?;
    let b0 = st.boundary_spec(0)?;
    let (mut pending, b_root) = super::stage_in_c::verify(&in_lay, cp, tables, &seg, &b0, &st.in_spec, &st.in_root(), &ntt, &mut tr, &tag)?;
    if position_tag(&tr) != end {
        return Err("classifier run: stage IN-C's trailer is not the verifier's own transcript position".into());
    }
    let mut prev: (BoundarySpec, Digest) = (b0, b_root);

    // ---- the blocks
    for k in 0..l {
        let blk = blocks.block(k)?;
        stage_block_is_the_statements(st, k, &blk, true)?;
        let mut ph = timing::Phases::start();
        let lay = st.block_layout(k)?;
        let start = position_tag(&tr);
        let (seg, end) = wire::decode_segment(&segments[k + 1], &lay, st.block_geom(k)?, &binding, &start)?;
        super::super::hash_domain::segment_paths_are_the_tree_depth(&seg, sh)?;
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let spec = st.boundary_spec(k + 1)?;
        let root = seg.b_root.ok_or_else(|| format!("classifier run: block segment {k} carries no boundary root"))?;
        protocol::absorb_root(&mut tr, b"B", &root, spec.commitment_rows(), spec.log_n());
        let view = CoreView { a_root: seg.a_root, h_root: seg.h_root, mask_root: seg.mask_root, slots: &seg.slots, mask_open: &seg.mask_open, a_open: &seg.a_open, h_open: &seg.h_open };
        let ssh = st.stage_shape(k)?;
        let ([ic, oc], _) = protocol::verify_core(&ssh, &lay, &blk, view, &ntt, &mut tr, &mut ph).map_err(|e| format!("block {k}: {e}"))?;
        drop(blk);
        let mut claims = std::mem::take(&mut pending);
        claims.extend(ic);
        let (pspec, proot) = prev;
        boundary::check_opening(&pspec, &claims, &tr)?;
        let bp = pspec.params();
        pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(proot, pspec.commitment_rows(), pspec.log_n()), &claims, &seg.in_open, &ntt, &mut tr, &tag).map_err(|e| format!("boundary {k}{}: {e}", if k == 0 { " (B_in)" } else { "" }))?;
        pending = oc;
        prev = (spec, root);
        if position_tag(&tr) != end {
            return Err(format!("classifier run: block segment {k}'s trailer is not the verifier's own transcript position"));
        }
    }

    // ---- stage OUT-C
    let out_lay = super::stage_out_c::layout(sh, cp);
    let start = position_tag(&tr);
    let (seg, end) = st.out_geom(&out_lay)?.decode(&segments[l + 1], &binding, &start)?;
    let (bspec, broot) = prev;
    super::stage_out_c::verify(&out_lay, cp, tables, st.verdict(), &seg, &bspec, &broot, pending, (l + 1) as u64, &ntt, &mut tr, &tag)?;
    if position_tag(&tr) != end {
        return Err("classifier run: stage OUT-C's trailer is not the verifier's own transcript position".into());
    }
    Ok(())
}

// ---------------------------------------------------------------- the input owner's check

/// **THE INPUT OWNER'S CHECK (design §6.1, the B-8 binding option R)**, under
/// the VERIFIED statement: the decommitment rebuilds the input root, and the
/// plane is the policy's template around the owner's own content, every
/// content id in the vocabulary and no control id, pad words zero.
pub(crate) fn owner_check_input(st: &ClassifyRunStatement, dec: &Decommitment, content: &[u64]) -> Result<(), String> {
    let cp = &st.cp;
    let words = owner_rebuild_root(&st.in_spec, &st.in_root(), dec, &st.sh().hash_tag())?;
    if content.len() != cp.n {
        return Err(format!("owner check: the owner's content has {} ids; the statement seals n = {}", content.len(), cp.n));
    }
    if words.len() != cp.in_ep_words() {
        return Err("owner check: the input plane is not of the statement's length".into());
    }
    let want = item_tokens(&cp.policy, content);
    for (t, w) in words.iter().enumerate() {
        if t >= cp.tokens {
            if !w.is_zero() {
                return Err("owner check: a sealed input pad word is not zero".into());
            }
            continue;
        }
        if cp.is_template(t) && w.0 != cp.kappa(t) {
            return Err("owner check: a sealed template position is not the policy's id".into());
        }
        if !cp.is_template(t) && (w.0 >= cp.v as u64 || cp.ctl(w.0)) {
            return Err("owner check: a sealed content id is outside the vocabulary or a control id".into());
        }
        if w.0 != want[t] {
            return Err("owner check: the sealed input plane is not the owner's content".into());
        }
    }
    Ok(())
}

// ---------------------------------------------------------------- the honest pipeline

/// The whole forward pass a production caller runs BEFORE sealing (H-1):
/// item tokens -> `B_in` -> each block -> `B_out` -> the final norm, the
/// margin and the verdict.
pub(crate) struct HonestClassify {
    pub tokens: Vec<u64>,
    pub stage_in: StageInWitness,
    pub b_in: Vec<i16>,
    pub witnesses: Vec<Option<Witness>>,
    pub planes: Vec<Vec<i16>>,
    pub out_values: OutCValues,
    pub stage_out: StageOutCWitness,
    pub in_plane: Vec<Fp>,
}

pub(crate) fn honest_classify(shapes: &[Shape], cp: &ClassifierProfile, tables: &ClassifierTables, blocks: &[BlockPublic], tokens: &[u64]) -> Result<HonestClassify, String> {
    let (wit_in, b_in, in_plane) = super::stage_in_c::honest_inputs(cp, tables, tokens)?;
    let (witnesses, planes, ov, wout) = downstream(shapes, cp, tables, blocks, &b_in, true)?;
    Ok(HonestClassify { tokens: tokens.to_vec(), stage_in: wit_in, b_in, witnesses, planes, out_values: ov, stage_out: wout, in_plane })
}

/// everything downstream of a `B_in` plane (`check` = false lets a cheating
/// prover past the final norm's refusals)
#[allow(clippy::type_complexity)]
pub(crate) fn downstream(shapes: &[Shape], cp: &ClassifierProfile, tables: &ClassifierTables, blocks: &[BlockPublic], b_in: &[i16], check: bool) -> Result<(Vec<Option<Witness>>, Vec<Vec<i16>>, OutCValues, StageOutCWitness), String> {
    let sh = shapes.first().ok_or("classifier pipeline: no block")?;
    if shapes.len() != blocks.len() {
        return Err("classifier pipeline: one stage shape per block".into());
    }
    let ids = Ids::new(sh)?;
    let mut x: Vec<i16> = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| b_in[t * sh.d_pad + i]).collect();
    let mut witnesses = Vec::with_capacity(blocks.len());
    let mut planes = Vec::with_capacity(blocks.len());
    for (k, b) in blocks.iter().enumerate() {
        let w = super::super::witness::build_shaped(&shapes[k], b.attention(), b.feed_forward(), &x).map_err(|e| format!("classifier pipeline: block {k}: {e}"))?;
        let plane: Vec<i16> = w.planes[ids.at(A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| "classifier pipeline: a block output outside int16".to_string())).collect::<Result<Vec<i16>, String>>()?;
        if k == 0 && w.planes[ids.at(A_X)].iter().zip(b_in.iter()).any(|(a, b)| *a != i64::from(*b)) {
            return Err("classifier pipeline: block 0's input plane is not B_in".into());
        }
        x = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect();
        planes.push(plane);
        witnesses.push(Some(w));
    }
    let b_out = planes.last().ok_or("classifier pipeline: no block")?;
    let ov = super::stage_out_c::out_values(cp, tables, &super::stage_out_c::row_of(cp, b_out, cp.tokens - 1), check)?;
    let wout = super::stage_out_c::witness_from_values(cp, &ov)?;
    Ok((witnesses, planes, ov, wout))
}

/// the honest source: the pipeline's own values, each once
pub(crate) struct ClassifySource<'a>(pub &'a mut HonestClassify);

impl ClassifyRunSource for ClassifySource<'_> {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        Ok((self.0.stage_in.clone(), self.0.b_in.clone()))
    }
    fn witness(&mut self, k: usize, _blk: &BlockPublic, _sh: &Shape) -> Result<Witness, String> {
        self.0.witnesses.get_mut(k).and_then(|w| w.take()).ok_or_else(|| format!("classifier pipeline: block {k}'s witness was already consumed"))
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.0.planes.get(k).cloned().ok_or_else(|| format!("classifier pipeline: no plane after block {k}"))
    }
    fn stage_out(&mut self) -> Result<StageOutCWitness, String> {
        Ok(self.0.stage_out.clone())
    }
    fn seal_check(&mut self, k: usize, _blk: &BlockPublic, _sh: &Shape, check: &mut dyn FnMut(&Witness) -> Result<(), String>) -> Result<(), String> {
        check(self.0.witnesses.get(k).and_then(|w| w.as_ref()).ok_or_else(|| format!("classifier pipeline: no witness for block {k}"))?)
    }
}

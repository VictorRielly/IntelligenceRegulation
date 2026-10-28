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
use super::super::shape::NormCalibration;
use super::super::trained_statement::{apply_own, cal_field, has_own, TrainedModelStatement, OWN_FIELDS};
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
    /// the derived whole-run figure (D27; review TR-1), bound through the
    /// parameter line; PRIVATE (review R2-3): the constructor is its only
    /// source, read through [`TokenRunStatement::whole_run`]
    whole_run: WholeRun,
    /// NATIVE R8 ported (round 7; R6 for `sh_s`): each block stage's
    /// calibration, the run shape's unless the trained statement's layer
    /// record carries own constants (`LayerRecord::own`: any of the eleven
    /// export-chosen fields, bound by the model identity the header absorbs);
    /// block stage `k` is proved and verified at
    /// [`TokenRunStatement::stage_shape`]`(k)`. The token stages' own final
    /// norm and head constants are the token profile's, never these.
    stage_cal: Vec<NormCalibration>,
}

/// **THE DERIVED WHOLE-RUN FIGURE (D27; review TR-1).** A union bound over
/// the run (MEMO_G02 section 2):
/// * the column test of every commitment the run opens (each opened once);
/// * the LogUp identity of every lookup argument, in the DERIVED convention
///   `(N + 3 R - 1) / |F_p^2|` for the byte / exp / act tables (`N` queries,
///   `R` distinct rows; D27's "derived lookup bound"), and, for stage IN's
///   embedding lookup, whose table is compressed with the challenge-dependent
///   column point `r_emb` (review R2-2), `(N + R (2 + log2 d_pad) + T log2
///   d_pad) / |F_p^2|`: a row collision is a polynomial of degree
///   `1 + log2 d_pad` in `(beta, r_emb)`, plus the `B_in` binding term;
/// * **the PCS field terms and the sumchecks, bounded EXPLICITLY (review
///   R2-1)** before the floor: MEMO_G02's per-unit figures at its largest
///   geometry (Llama-3-8B T512, row width 2^15, which every registered
///   token run is at or below in rows, claims and rounds): 2^-113 per opening
///   (proximity combination and claim batching) and 2^-117.2 per stage (the
///   zero-check sumchecks), i.e. `openings * 2^-113 + (L + 2) * 2^-117.2`.
/// The total is FLOORED to whole bits; floats never reach a transcript, only
/// the whole-bit floor does.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct WholeRun {
    pub openings: usize,
    pub column_log2: f64,
    pub logup_log2: f64,
    /// the explicit bound of the PCS field and sumcheck terms (review R2-1)
    pub omitted_log2: f64,
    pub total_log2: f64,
    pub floor_bits: u32,
}

/// MEMO_G02's per-opening PCS field term and per-stage sumcheck term, log2
/// (review R2-1: the bound added before the floor)
pub(crate) const PCS_FIELD_PER_OPENING_LOG2: f64 = -113.0;
pub(crate) const SUMCHECK_PER_STAGE_LOG2: f64 = -117.2;

/// one block's LogUp size: the `U8` lookups of every lookup domain over its
/// padded (lifted) extent, plus the exponential pair over `S` and the
/// activation pair over `F`; three 256-row tables (MEMO_G02 section 2)
pub(crate) fn block_logup_size(sh: &Shape) -> (u128, u128) {
    use super::super::layout::{Dom, LOOKUP_DOMS};
    let u8: u128 = LOOKUP_DOMS.iter().map(|d| sh.lookups_per_position(*d) as u128 * sh.size(*d) as u128).sum();
    (u8 + sh.size(Dom::S) as u128 + sh.size(Dom::F) as u128, 3 * U8_LEN as u128)
}

/// the whole-run figure of a token run of `L` blocks of `sh` under `tp`
pub(crate) fn whole_run_of(sh: &Shape, l: usize, tp: &TokenProfile) -> WholeRun {
    let t = tp.tier;
    let mut col: Vec<f64> = Vec::new();
    // stage IN and stage OUT: A and H at the tier's stage geometry, then M
    for _ in 0..2 {
        col.push(t.per_opening_log2(t.stage_log_n, t.stage_inv_rate));
        col.push(t.per_opening_log2(t.stage_log_n, t.stage_inv_rate));
        col.push(mask_opening_log2());
    }
    // the two token endpoints at the tier's endpoint geometry
    for _ in 0..2 {
        col.push(t.per_opening_log2(t.ep_log_n, t.ep_inv_rate));
    }
    // the L blocks: A and H at the block shape's geometry, then M
    for _ in 0..l {
        col.push(hiding_opening_log2(sh.log_cols, sh.inv_rate, sh.opened_cols));
        col.push(hiding_opening_log2(sh.log_cols, sh.inv_rate, sh.opened_cols));
        col.push(mask_opening_log2());
    }
    // the L + 1 boundaries B_in, B_1 .. B_out
    for _ in 0..=l {
        col.push(hiding_opening_log2(sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols));
    }
    // the byte / exp / act lookup arguments: stage OUT and the L blocks
    let mut lk = vec![stage_out::logup_size(&stage_out::layout(sh, tp), tp)];
    let blk = block_logup_size(sh);
    lk.extend(vec![blk; l]);
    let field_log2 = 2.0 * (P as f64).log2();
    let column: f64 = col.iter().map(|x| x.exp2()).sum();
    let mut num: f64 = lk.iter().map(|(n, r)| (*n + 3 * *r - 1) as f64).sum::<f64>();
    // stage IN's compressed-row embedding lookup (review R2-2)
    let (n_in, r_in) = stage_in::logup_size(&stage_in::layout(sh, tp), tp);
    let lg = clog2(tp.d_pad) as u128;
    num += (n_in + r_in * (2 + lg) + tp.tokens as u128 * lg) as f64;
    let logup = num * (-field_log2).exp2();
    let omitted = col.len() as f64 * PCS_FIELD_PER_OPENING_LOG2.exp2() + (l + 2) as f64 * SUMCHECK_PER_STAGE_LOG2.exp2();
    let total_log2 = (column + logup + omitted).log2();
    WholeRun { openings: col.len(), column_log2: column.log2(), logup_log2: logup.log2(), omitted_log2: omitted.log2(), total_log2, floor_bits: (-total_log2).floor() as u32 }
}

/// **THE VERIFIER'S POLICY (D27; review TR-1):** the minimum derived
/// whole-run figure, in whole bits; a statement below it is refused by name
/// before any segment is read.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct VerifierPolicy {
    pub min_whole_run_bits: u32,
}

/// review TR-3 (D26 C-a): only the public-row variant is built; P and F (the
/// sealed selector, D26's two-site endpoint) are refused by name by the
/// endpoint specs, the statement, the prover and the verifier
pub(crate) fn variant_is_built(tp: &TokenProfile) -> Result<(), String> {
    if tp.variant != SelectorVariant::PublicRow {
        return Err(format!("token I/O run: the {} variant is not built (D26's two-site endpoint is the next rung; review TR-3)", tp.variant.tag()));
    }
    Ok(())
}

/// the two token endpoints' statements at a profile (public inputs only)
pub(crate) fn endpoint_specs(sh: &Shape, context: Digest, tp: &TokenProfile) -> Result<(EndpointSpecG, EndpointSpecG), String> {
    variant_is_built(tp)?;
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
        if !super::super::run::TOKEN_IO_RUN_PROFILES.contains(&rs.profile()) {
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
        variant_is_built(&tp)?;
        let (in_spec, out_spec) = endpoint_specs(sh, context, &tp)?;
        let whole_run = whole_run_of(sh, l, &tp);
        // NATIVE R8 ported (R6 for sh_s): a layer's own constants, its whole
        // calibration validated at the trained door
        // (`Shape::with_layer_calibration`: every class, the plane list
        // unmoved, the constructor's rebuild, the trained class)
        let base = sh.norm_calibration();
        let mut stage_cal = vec![base; l];
        for (k, r) in model.layers.iter().enumerate() {
            // review TR3-3: the record read for stage k IS block k's (made
            // local here; `check_against` above already aligns them)
            if block_digests.get(k) != Some(&r.block_digest) {
                return Err(format!("token I/O run: layer record {k} (layer {}) is not block {k}'s digest (review TR3-3)", r.index));
            }
            if has_own(&r.own) {
                let cal = apply_own(&base, &r.own).map_err(|e| format!("token I/O run: layer {}: {e}", r.index))?;
                sh.with_layer_calibration(&cal).map_err(|e| format!("token I/O run: layer {}'s own calibration: {e}", r.index))?;
                stage_cal[k] = cal;
            }
        }
        Ok(TokenRunStatement { rs, context, block_digests, model_identity: model.identity(), tp, in_spec, out_spec, in_root: roots.0, out_root: roots.1, scale: scales.0, whole_run, stage_cal })
    }

    pub(crate) fn sh(&self) -> &Shape {
        self.rs.sh()
    }
    /// the run profile this statement is under (one of the token-I/O profiles)
    pub(crate) fn profile(&self) -> &'static str {
        self.rs.profile()
    }
    /// the statement's derived whole-run figure (review R2-3: read-only)
    pub(crate) fn whole_run(&self) -> &WholeRun {
        &self.whole_run
    }
    /// **NATIVE R8 ported (R6 for sh_s): the shape block stage `k` is proved
    /// and verified at** — the run shape, or (a layer with its own constants)
    /// the same shape with that layer's calibration, rebuilt through the
    /// trained door
    pub(crate) fn stage_shape(&self, k: usize) -> Result<Shape, String> {
        let cal = *self.stage_cal.get(k).ok_or_else(|| format!("token I/O run: no block stage {k}"))?;
        if cal == self.sh().norm_calibration() {
            Ok(self.sh().clone())
        } else {
            self.sh().with_layer_calibration(&cal)
        }
    }
    pub(crate) fn l(&self) -> usize {
        self.rs.l()
    }
    /// the run's context (the deployment's, bound by the endpoint specs)
    pub(crate) fn context(&self) -> Digest {
        self.context
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
        h.update(&self.tp.digest_under(self.profile()));
        *h.finalize().as_bytes()
    }

    pub(crate) fn parameter_line(&self) -> Result<String, String> {
        let sh = self.sh();
        let b = self.boundary_spec(0)?;
        let t = self.tp.tier;
        // review R2-6: inside a token run the block's two IO roles are
        // internal boundaries, and the figure carries the explicit bound of
        // review R2-1; the R1 / R2 profiles keep their texts byte for byte
        // (their floors are unchanged by the bound)
        let legacy = legacy_profile_text(self.profile());
        let block_line = if legacy { protocol::parameter_line(sh) } else { protocol::parameter_line(sh).replace("/two-private-endpoints/", "/two-internal-boundaries/") };
        let figure = if legacy { "column-plus-logup-derived" } else { "column-plus-logup-derived-plus-pcs-field-and-sumcheck-bound" };
        Ok(format!(
            "{}/L{}/boundaries-B_in-B_out-and-interior-log_n{}-rate{}-pad{}-rows{}-sites2/token-endpoints-log_n{}-rate{}-pad{}-in-words{}-in-rows{}-out-words{}-out-rows{}-sites1/stages-log_n{}-rate{}-pad{}/{}/whole-run-floor-{}-bits-{}-openings-{figure}/one-run-one-transcript",
            block_line,
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
            self.tp.describe_under(self.profile()),
            self.whole_run.floor_bits,
            self.whole_run.openings
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
            // NATIVE R8 ported (R6 for sh_s): a block stage whose layer has its
            // own constants says so, one clause per constant in the canonical
            // order with R8's labels (and so in the schedule digest the header
            // absorbs); a run-wide run's lines are what they were, and an
            // sh_s-only clause is R6's text
            let base = self.sh().norm_calibration();
            let mut own = String::new();
            for (i, (_, _, label)) in OWN_FIELDS.iter().enumerate() {
                let (v, b) = (cal_field(&self.stage_cal[k], i), cal_field(&base, i));
                if v != b {
                    own.push_str(&format!("; {label} {v} (the layer's own; the run's is {b})"));
                }
            }
            out.push(format!(
                "stage {:02} (block {k}): commits boundary {}{}; slot 21 claims boundary {} at pair row {}; slot 22 claims boundary {} at pair row {}; opens M A H then boundary {}; data rows {}{own}",
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

    /// **TOKEN I/O (round 7; the gate lane's capture request 2.3): the
    /// run's public words for the run capture** — the block part exactly as
    /// `RunStatement::capture_header` gives it (every word the token header
    /// absorbs, in absorb order, so the recorder rebuilds the header from
    /// this alone and compares it with the binding), plus the token facts.
    /// Test-only, like the capture itself.
    #[cfg(test)]
    pub(crate) fn capture_header(&self) -> Result<super::super::run_capture::RunHeader, String> {
        use super::super::run_capture::{BoundaryFacts, RunHeader, TokenEndpointFacts, TokenFacts};
        let sh = self.sh();
        let tp = &self.tp;
        let t = tp.tier;
        let mut boundaries = Vec::with_capacity(self.l() + 1);
        for j in 0..=self.l() {
            let spec = self.boundary_spec(j)?;
            boundaries.push(BoundaryFacts {
                index: j,
                scale: spec.scale(),
                sites: spec.sites(),
                data_rows: spec.data_rows(),
                rows: spec.commitment_rows(),
                site_rows: spec.site_rows(),
                prox_row: spec.prox_row(),
                log_n: spec.log_n(),
                inv_rate: sh.endpoint_inv_rate,
                checks: sh.opened_cols,
                digest: spec.digest(),
                plane: (sh.t_pad, sh.d_pad),
            });
        }
        let ep = |e: &EndpointSpecG| {
            let d = e.data_rows();
            TokenEndpointFacts { rows: e.commitment_rows(), data_rows: d, sites: 1, site_rows: vec![d, d + 1], prox_row: d + 2, log_n: t.ep_log_n, inv_rate: t.ep_inv_rate, checks: t.opened_cols, plane: (1, e.len()), digest: e.digest(), scale: 0 }
        };
        let token = TokenFacts {
            run_profile: self.profile(),
            v: tp.v,
            v_pad: tp.v_pad,
            tokens: tp.tokens,
            t_pad: tp.t_pad,
            d: tp.d,
            d_pad: tp.d_pad,
            variant: tp.variant.tag(),
            mode: "i",
            limbs: tp.limbs,
            window_bits: tp.window_bits,
            mult_bits: tp.mult_bits,
            emb_digest: tp.emb_digest,
            head_digest: tp.head_digest,
            bos: tp.bos,
            final_norm: (tp.norm.g0, tp.norm.cn, tp.norm.tn, tp.norm.ceps),
            scales: (self.scale, self.scale),
            tier: (t.name, t.opened_cols, t.stage_log_n, t.stage_inv_rate, t.ep_log_n, t.ep_inv_rate),
            endpoints: [ep(&self.in_spec), ep(&self.out_spec)],
            input_root: self.in_root,
            output_root: self.out_root,
            boundaries: boundaries.clone(),
            r_emb_len: clog2(tp.d_pad),
            stage_layouts: [stage_in::layout(sh, tp).describe(), stage_out::layout(sh, tp).describe()],
        };
        Ok(RunHeader {
            profile: self.profile(),
            l: self.l(),
            sh: sh.clone(),
            run_shape_words: [self.l(), sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim, tp.v].iter().map(|v| *v as u64).collect(),
            expected_bytes: self.expected_bytes(),
            public_statement: self.public_statement(),
            parameter_line: self.parameter_line()?,
            calibration: self.calibration(),
            schedule_digest: self.schedule_digest()?,
            context: self.context,
            block_digests: self.block_digests.clone(),
            boundary_scales: vec![self.scale; self.l() + 1],
            external_input_root: self.in_root,
            external_output_root: self.out_root,
            external_rows: self.in_spec.commitment_rows(),
            external_data_rows: self.in_spec.data_rows(),
            external_log_n: t.ep_log_n,
            external_inv_rate: t.ep_inv_rate,
            stage_lines: self.stage_lines()?,
            layout_description: Layout::for_shape(sh)?.describe(),
            boundaries,
            external_scales: (0, 0),
            token: Some(token),
        })
    }

    /// the run binding (the header transcript's state), for the capture
    #[cfg(test)]
    pub(crate) fn binding(&self) -> Result<Digest, String> {
        Ok(self.transcript()?.state())
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
        Ok(Layout::for_shape(&self.stage_shape(k)?)?.with_io_mask_rows([self.boundary_spec(k)?.mask_row(1)?, self.boundary_spec(k + 1)?.mask_row(0)?]))
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
    /// block `k`'s integer witness (`blk` is the stage's block, handed by the
    /// prover after its shape and digest checks: one load per stage; `sh` the
    /// stage's shape, which carries a layer's own score shift)
    fn witness(&mut self, k: usize, blk: &BlockPublic, sh: &Shape) -> Result<Witness, String>;
    /// the padded plane after block `k` (boundary `k + 1`; `B_out` at `L - 1`)
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String>;
    /// `A_out`'s planes (asked FIRST, before any segment exists: review R2-5)
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

/// **THE RUN'S PUBLIC BLOCKS, ONE STAGE AT A TIME (R3).** Thirty-two
/// Llama-3-8B blocks (about 7.8 GB) cannot all be resident, so the prover and
/// the verifier ask for block `k` at its own stage; each block handed is
/// checked against the run's shape (CS-1 / CS-4) and against the statement's
/// digest for that position (CS-6) BEFORE anything of its stage is absorbed.
/// R1 and R2 hand a resident slice.
pub(crate) trait TokenBlocks {
    /// how many blocks the source holds
    fn count(&self) -> usize;
    /// block `k` (borrowed from a slice, or shared out of a one-block cache)
    fn block(&mut self, k: usize) -> Result<super::super::run::BlockRef<'_>, String>;
}

/// a resident slice of blocks (R1, R2)
pub(crate) struct ResidentBlocks<'a>(pub &'a [BlockPublic]);

impl TokenBlocks for ResidentBlocks<'_> {
    fn count(&self) -> usize {
        self.0.len()
    }
    fn block(&mut self, k: usize) -> Result<super::super::run::BlockRef<'_>, String> {
        self.0.get(k).map(super::super::run::BlockRef::Borrowed).ok_or_else(|| format!("token I/O run: no block {k}"))
    }
}

/// RULINGS CS-1 / CS-4 / CS-6 for the block of stage `k`, before the stage
/// absorbs anything (the cheating prover of the tamper controls skips CS-6)
fn stage_block_is_the_statements(st: &TokenRunStatement, k: usize, blk: &BlockPublic, cs6: bool) -> Result<(), String> {
    blk.check_for_shape(&st.stage_shape(k)?).map_err(|e| format!("token I/O run: block {k}: {e}"))?;
    if cs6 && blk.digest() != st.block_digests[k] {
        return Err(format!("token I/O run: ruling CS-6 — block {k} is not the block the statement names"));
    }
    Ok(())
}

/// **THE TOKEN-I/O RUN PROVER** over a resident slice of blocks.
pub(crate) fn prove_token_run(
    st: &TokenRunStatement,
    blocks: &[BlockPublic],
    tables: &TokenTables,
    src: &mut dyn TokenRunSource,
    owners: TokenOwners,
    sink: &mut dyn FnMut(usize, Vec<u8>) -> Result<(), String>,
) -> Result<(TokenRunStats, OwnerHandoff), String> {
    prove_token_run_with(st, &mut ResidentBlocks(blocks), tables, src, owners, sink)
}

/// **THE TOKEN-I/O RUN PROVER.** One transcript, one OS stream, `L + 2`
/// segments, each handed to `sink` and dropped (M-3); block `k` asked for
/// at its own stage (R3 streaming).
///
/// **The sink contract (reviews R2-5 / TR3-1).** Before the FIRST segment
/// exists the prover has (1) taken the stage-OUT witness and run its
/// byte-lookup refusal and (2) checked EVERY block against the run's stage
/// shape and the statement's digest (CS-1 / CS-4 / CS-6), so the refusals a
/// caller can provoke with its inputs leave the sink empty. What remains
/// possible mid-run (a block file that changes between the pre-check and its
/// stage's reload, which the per-stage check refuses by name; a resource
/// failure) can still come after earlier segments, so a sink must treat what
/// it receives as UNPUBLISHED until this function returns `Ok` (the CLI's
/// sink writes `<out>.incomplete/` and renames it only then).
#[cfg(test)]
thread_local! {
    /// ROUND 9 (F-T1), test only: how many token run headers the prover
    /// built on this thread (the header is the first thing a run writes)
    static RUN_HEADERS: std::cell::Cell<u64> = const { std::cell::Cell::new(0) };
}

/// ROUND 9 (F-T1), test only: the run headers built on this thread so far
#[cfg(test)]
pub(crate) fn run_headers() -> u64 {
    RUN_HEADERS.with(|c| c.get())
}

pub(crate) fn prove_token_run_with(
    st: &TokenRunStatement,
    blocks: &mut dyn TokenBlocks,
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
    variant_is_built(tp)?;
    if blocks.count() != l {
        return Err(format!("token I/O run: the statement names {l} blocks and {} were handed", blocks.count()));
    }
    protocol::fits_the_ntt_tables(sh)?;
    if tables.emb_digest() != tp.emb_digest || tables.head_digest() != tp.head_digest {
        return Err("token I/O run: the tables handed are not the ones the statement names".into());
    }
    if owners.input.commitment().root != st.in_root || owners.output.commitment().root != st.out_root || owners.input.cm.rows != st.in_spec.commitment_rows() || owners.output.cm.rows != st.out_spec.commitment_rows() {
        return Err("token I/O run: the token endpoint owners are not the statement's".into());
    }
    // review R2-5: the stage-OUT witness is taken, and its byte-lookup
    // refusal run, BEFORE the first segment reaches the sink, so a refused
    // witness publishes nothing. (D20's final-norm refusals already fire in
    // the honest pipeline, before any header.) A sink must still treat what
    // it receives as unpublished until this function returns Ok.
    let wout = src.stage_out()?;
    if !cheating && stage_out::byte_misses(&stage_out::layout(sh, tp), tp, &wout)? > 0 {
        return Err("token I/O stage OUT: the witness looks up a value that is not a byte (the class of the miss only)".into());
    }
    // review TR3-1: every block's CS-1 / CS-4 / CS-6 check BEFORE the first
    // segment (the per-stage check below stays: a block that changes between
    // the two is refused at its stage)
    for k in 0..l {
        let blk = blocks.block(k)?;
        stage_block_is_the_statements(st, k, &blk, !cheating)?;
    }
    let mut rng = ZkRng::from_os(&super::super::hash_domain::run_seed_domain(st.rs.profile())).map_err(|e| format!("token I/O run randomness: {e}"))?;
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript()?;
    // ROUND 9 (F-T1): the test-only count of run headers this thread has
    // built, so a test can show a refused run built none
    #[cfg(test)]
    RUN_HEADERS.with(|c| c.set(c.get() + 1));
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
        let blk = blocks.block(k)?;
        stage_block_is_the_statements(st, k, &blk, !cheating)?;
        let spec = st.boundary_spec(k + 1)?;
        let plane = src.boundary_plane(k)?;
        if plane.len() != spec.len() {
            return Err(format!("token I/O run: boundary {}'s plane is {} words, the padded plane is {}", k + 1, plane.len(), spec.len()));
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
        stats.hwm_mib.push(super::super::run::peak_rss_mib());
    }

    // ---- stage OUT
    let t0 = Instant::now();
    let start = position_tag(&tr);
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
pub(crate) fn verify_token_run(st: &TokenRunStatement, blocks: &[BlockPublic], tables: &TokenTables, segments: &[Vec<u8>], policy: VerifierPolicy) -> Result<(), String> {
    verify_token_run_with(st, &mut ResidentBlocks(blocks), tables, segments, policy)
}

/// **THE TOKEN-I/O RUN VERIFIER**, block `k` asked for at its own stage
/// (R3 streaming), checked (CS-1 / CS-4 / CS-6) before its stage absorbs.
pub(crate) fn verify_token_run_with(st: &TokenRunStatement, blocks: &mut dyn TokenBlocks, tables: &TokenTables, segments: &[Vec<u8>], policy: VerifierPolicy) -> Result<(), String> {
    let (sh, l, tp) = (st.sh(), st.l(), &st.tp);
    // review TR-3 and TR-1 (D27): the statement's variant and its derived
    // whole-run figure, before any segment is read
    variant_is_built(tp)?;
    tp.tier.check()?;
    if st.whole_run.floor_bits < policy.min_whole_run_bits {
        return Err(format!(
            "token I/O run: the statement's derived whole-run figure ({} bits, tier {}) is below the verifier's minimum of {} bits (D27 policy)",
            st.whole_run.floor_bits, tp.tier.name, policy.min_whole_run_bits
        ));
    }
    if blocks.count() != l || segments.len() != l + 2 {
        return Err(format!("token I/O run: {} blocks and {} segments were offered, this run has {l} blocks and {} segments", blocks.count(), segments.len(), l + 2));
    }
    protocol::fits_the_ntt_tables(sh)?;
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
    // TOKEN I/O (round 7; capture request 2.2): the run capture opens stage
    // IN where `RunVerifier::step` opens a stage (decoded, before the stage
    // words). A no-op unless a recorder is attached.
    #[cfg(test)]
    super::super::run_capture::stage_begin_stage(0, "IN", &segments[0], start, seg.b_root, seg.a_root, seg.h_root, seg.mask_root, stage_in::capture_planes(&in_lay), &tr);
    let (mut pending, b_root) = stage_in::verify(&in_lay, tp, tables, &seg, &b0, &st.in_spec, &st.in_root, &ntt, &mut tr, &tag)?;
    if position_tag(&tr) != end {
        return Err("token I/O run: stage IN's trailer is not the verifier's own transcript position".into());
    }
    #[cfg(test)]
    super::super::run_capture::stage_end(0, end, &tr);
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
        #[cfg(test)]
        super::super::run_capture::stage_begin_stage(k + 1, "BLOCK", &segments[k + 1], start, seg.b_root, seg.a_root, seg.h_root, seg.mask_root, super::super::run_capture::StagePlanes::Block(&lay), &tr);
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let spec = st.boundary_spec(k + 1)?;
        let root = seg.b_root.ok_or_else(|| format!("token I/O run: block segment {k} carries no boundary root"))?;
        protocol::absorb_root(&mut tr, b"B", &root, spec.commitment_rows(), spec.log_n());
        let view = CoreView { a_root: seg.a_root, h_root: seg.h_root, mask_root: seg.mask_root, slots: &seg.slots, mask_open: &seg.mask_open, a_open: &seg.a_open, h_open: &seg.h_open };
        let ssh = st.stage_shape(k)?;
        let ([ic, oc], _) = protocol::verify_core(&ssh, &lay, &blk, view, &ntt, &mut tr, &mut ph).map_err(|e| format!("block {k}: {e}"))?;
        drop(blk);
        let mut claims = std::mem::take(&mut pending);
        #[cfg(test)]
        let (pending_n, incoming_n) = (claims.len(), ic.len());
        claims.extend(ic);
        let (pspec, proot) = prev;
        boundary::check_opening(&pspec, &claims, &tr)?;
        let bp = pspec.params();
        #[cfg(test)]
        let rc_before = super::super::run_capture::checkpoint(&tr);
        pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(proot, pspec.commitment_rows(), pspec.log_n()), &claims, &seg.in_open, &ntt, &mut tr, &tag).map_err(|e| format!("boundary {k}{}: {e}", if k == 0 { " (B_in)" } else { "" }))?;
        // TOKEN I/O (round 7): the boundary opening, as `RunVerifier::step`
        // wraps it; B_in (k = 0) carries stage IN's IN-01 claims, a later
        // boundary the previous block's outgoing equality slot's
        #[cfg(test)]
        super::super::run_capture::pcs(
            super::super::run_capture::Geom {
                role: "Input",
                commitment_kind: if k == 0 { "B-in" } else { "internal-boundary" },
                params: bp,
                root: proot,
                rows: pspec.commitment_rows(),
                data_rows: pspec.data_rows(),
                site_rows: pspec.site_rows(),
                sum_rows: None,
                prox_row: pspec.prox_row(),
                boundary: Some(k),
                claim_sources: vec![if k == 0 { (0, stage_in::SI_QZC, pending_n) } else { (k, super::super::layout::SC_IO_OUT, pending_n) }, (k + 1, super::super::layout::SC_IO_IN, incoming_n)],
            },
            &claims,
            &seg.in_open,
            &ntt,
            rc_before,
            &tr,
        );
        pending = oc;
        prev = (spec, root);
        if position_tag(&tr) != end {
            return Err(format!("token I/O run: block segment {k}'s trailer is not the verifier's own transcript position"));
        }
        #[cfg(test)]
        super::super::run_capture::stage_end(k + 1, end, &tr);
    }

    // ---- stage OUT
    let out_lay = stage_out::layout(sh, tp);
    let start = position_tag(&tr);
    let (seg, end) = st.out_geom(&out_lay)?.decode(&segments[l + 1], &binding, &start)?;
    let (bspec, broot) = prev;
    #[cfg(test)]
    super::super::run_capture::stage_begin_stage(l + 1, "OUT", &segments[l + 1], start, seg.b_root, seg.a_root, seg.h_root, seg.mask_root, stage_out::capture_planes(&out_lay, tp), &tr);
    stage_out::verify(&out_lay, tp, tables, &seg, &bspec, &broot, pending, &st.out_spec, &st.out_root, (l + 1) as u64, &ntt, &mut tr, &tag)?;
    if position_tag(&tr) != end {
        return Err("token I/O run: stage OUT's trailer is not the verifier's own transcript position".into());
    }
    #[cfg(test)]
    {
        super::super::run_capture::stage_end(l + 1, end, &tr);
        super::super::run_capture::run_accepted();
    }
    Ok(())
}

// ---------------------------------------------------------------- the owner checks

/// **THE INPUT OWNER'S CHECK (DESIGN 3.4, D26 C-d; review TR-4)**, under the
/// VERIFIED statement: the decommitment rebuilds the input token endpoint's
/// root, and the plane is the public-row variant's: the owner's own prompt
/// (`T` ids, BOS at 0, every id in the vocabulary) and zero pad words.
pub(crate) fn owner_check_input(st: &TokenRunStatement, dec: &Decommitment, prompt: &[u64]) -> Result<(), String> {
    let tp = &st.tp;
    variant_is_built(tp)?;
    let words = owner_rebuild_root(&st.in_spec, &st.in_root, dec, &st.sh().hash_tag())?;
    if prompt.len() != tp.tokens {
        return Err(format!("owner check: the owner's prompt has {} ids; the public-row variant seals exactly T = {}", prompt.len(), tp.tokens));
    }
    if words.len() != tp.in_ep_words() {
        return Err("owner check: the input plane is not of the statement's length".into());
    }
    if words[0] != Fp::new(tp.bos) {
        return Err("owner check: the sealed position 0 is not the profile's BOS".into());
    }
    if words[..tp.tokens].iter().any(|w| w.0 >= tp.v as u64) {
        return Err("owner check: a sealed input id is outside the vocabulary".into());
    }
    if words[tp.tokens..].iter().any(|w| !w.is_zero()) {
        return Err("owner check: a sealed input pad word is not zero".into());
    }
    if words[..tp.tokens].iter().zip(prompt.iter()).any(|(w, t)| w.0 != *t) {
        return Err("owner check: the sealed input plane is not the owner's prompt".into());
    }
    Ok(())
}

/// **THE OUTPUT OWNER'S CHECK (DESIGN 3.4, D26 C-d; review TR-4)**, under
/// the VERIFIED statement: the decommitment rebuilds the output token
/// endpoint's root, word 0 is an id below `V` and every other word is zero.
/// Returns the next token.
pub(crate) fn owner_check_output(st: &TokenRunStatement, dec: &Decommitment) -> Result<usize, String> {
    let tp = &st.tp;
    variant_is_built(tp)?;
    let words = owner_rebuild_root(&st.out_spec, &st.out_root, dec, &st.sh().hash_tag())?;
    if words.len() != tp.out_ep_words() {
        return Err("owner check: the output plane is not of the statement's length".into());
    }
    if words[0].0 >= tp.v as u64 {
        return Err("owner check: the sealed next token is outside the vocabulary".into());
    }
    if words[1..].iter().any(|w| !w.is_zero()) {
        return Err("owner check: a sealed output pad word is not zero".into());
    }
    Ok(words[0].0 as usize)
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
    honest_pipeline_at(&vec![sh.clone(); blocks.len()], tp, tables, blocks, tokens)
}

/// [`honest_pipeline`] with each block at its STAGE shape (NATIVE R6 ported)
pub(crate) fn honest_pipeline_at(shapes: &[Shape], tp: &TokenProfile, tables: &TokenTables, blocks: &[BlockPublic], tokens: &[u64]) -> Result<HonestPipeline, String> {
    let (wit_in, b_in, in_plane) = stage_in::honest_inputs(tp, tables, tokens)?;
    let (witnesses, planes, ov, wout, out_plane) = downstream_at(shapes, tp, tables, blocks, &b_in, true)?;
    Ok(HonestPipeline { tokens: tokens.to_vec(), stage_in: wit_in, b_in, witnesses, planes, out_values: ov, stage_out: wout, in_plane, out_plane })
}

/// Everything downstream of a `B_in` plane: the blocks' witnesses, the plane
/// after each block, the stage-OUT values and witness, the output endpoint's
/// plane. `check` = false lets a cheating prover past the final norm's
/// refusals (the tamper controls).
#[allow(clippy::type_complexity)]
pub(crate) fn downstream(sh: &Shape, tp: &TokenProfile, tables: &TokenTables, blocks: &[BlockPublic], b_in: &[i16], check: bool) -> Result<(Vec<Option<Witness>>, Vec<Vec<i16>>, OutValues, StageOutWitness, Vec<Fp>), String> {
    downstream_at(&vec![sh.clone(); blocks.len()], tp, tables, blocks, b_in, check)
}

/// [`downstream`] with each block's witness at its STAGE shape (a layer with
/// its own score shift: NATIVE R6 ported)
#[allow(clippy::type_complexity)]
pub(crate) fn downstream_at(shapes: &[Shape], tp: &TokenProfile, tables: &TokenTables, blocks: &[BlockPublic], b_in: &[i16], check: bool) -> Result<(Vec<Option<Witness>>, Vec<Vec<i16>>, OutValues, StageOutWitness, Vec<Fp>), String> {
    let sh = shapes.first().ok_or("token I/O pipeline: no block")?;
    if shapes.len() != blocks.len() {
        return Err("token I/O pipeline: one stage shape per block".into());
    }
    let ids = Ids::new(sh)?;
    let mut x: Vec<i16> = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| b_in[t * sh.d_pad + i]).collect();
    let mut witnesses = Vec::with_capacity(blocks.len());
    let mut planes = Vec::with_capacity(blocks.len());
    for (k, b) in blocks.iter().enumerate() {
        let w = super::super::witness::build_shaped(&shapes[k], b.attention(), b.feed_forward(), &x).map_err(|e| format!("token I/O pipeline: block {k}: {e}"))?;
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
    fn witness(&mut self, k: usize, _blk: &BlockPublic, _sh: &Shape) -> Result<Witness, String> {
        self.0.witnesses.get_mut(k).and_then(|w| w.take()).ok_or_else(|| format!("token I/O pipeline: block {k}'s witness was already consumed"))
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.0.planes.get(k).cloned().ok_or_else(|| format!("token I/O pipeline: no plane after block {k}"))
    }
    fn stage_out(&mut self) -> Result<StageOutWitness, String> {
        Ok(self.0.stage_out.clone())
    }
}

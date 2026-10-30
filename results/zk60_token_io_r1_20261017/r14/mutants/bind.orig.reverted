//! **TOKEN I/O ROUND 13, RUNG R-C2: THE CLASSIFIER'S TABLES TIED TO THE
//! PINNED TENSOR** (coordinator notes 2026-10-26 20:11 "F1 widened to the
//! classifier tables" and 2026-10-28 21:35, conditions 1-3).
//!
//! R-C1's loader checked every table file only against the digest its OWN
//! manifest declared: a doctored margin row or embedding shipped with a
//! rehashed `classifier.json` / `token_io.json` was accepted, and the BOS and
//! final norm of `classifier.json` were not compared with the export's. R-C2
//! RE-DERIVES them, on the prover's and the verifier's side alike:
//!
//! * the margin row `w = q((E[yes] - E[no]) * g)` from the pinned tied tensor,
//!   with `yes` / `no`, the public `scale` and `threshold_c` taken ONLY from the
//!   statement-bound export profile's `classifier_margin_parameters` (the
//!   registered policy, B-6, must name the same values; `classifier.json`'s
//!   copies must equal them). `margin_int16.bin` is COMPARED with the row and
//!   never trusted: the run's `w` is the recomputed row (REVIEW_R12B §5,
//!   requirements 1-5);
//! * the int16 embedding table's SHA-256 from the same tensor; the table file
//!   must have exactly that digest;
//! * BOS and the classifier final norm from the export's
//!   `profile.json.token_io_parameters` (inside the profile digest the trained
//!   statement binds; the derivation's own read of `profile.json` must have the
//!   loaded export's digest); `classifier.json`'s copies must equal them.
//!
//! Any disagreement is a refusal (no "prefer the file" fallback); a margin
//! word outside `[-32767, 32767]` is a refusal, never a clamp.
//!
//! The tied source is fixed per block profile ([`TiedSource::of`]):
//! * **Shieldstral-1.0-3B** (every registered Shieldstral block profile):
//!   native R12b's public `tied_tables::recompute_tied_tables(export,
//!   Some((yes, no, scale)))` — the authenticated 7.7 GB checkpoint is streamed
//!   (about a minute; callers run under the resource guard).
//! * **the development rung**: a pinned SYNTHETIC BF16 tensor
//!   ([`DEV_TIED_TENSOR_FILE`] in the tables directory, its SHA-256 pinned in
//!   [`DEV_TIED_TENSOR_SHA256`]: `V x d` rows, then the `d` final-norm
//!   weights), quantized with R12b's OWN `quantize` / `bf16` (half-up
//!   `floor(x / scale + 0.5)`, refusal outside the class, no clipping). The rung
//!   has no rotation; an export that declares one is refused here.
//!
//! **ROUND 14 (REVIEW_R13 N-r13-1): the binding moves into the library.** The
//! classifier run's entry points (`ClassifyRunStatement::new` / `new_chunk`,
//! `prove_classify_run_with`, `verify_classify_run_with`, and through them the
//! run capture's replay) take [`BoundClassifierTables`], whose fields are
//! private to this module: outside it, a value exists only as
//! [`load_bound_tables`] returns it, re-derived from the pinned tensor under
//! the trained statement's own profile digest and residual unit and compared
//! with the files. The statement constructor checks the tables are bound to
//! ITS trained statement and policy and that the block and run profiles name
//! the same tied source (N-r13-6); prove and verify check they are the
//! statement's. Test builds alone carry a second constructor for the relation
//! tests' synthetic fixtures, marked so, which the capture replay refuses.
//!
//! No privacy claim and no classifier acceptance: this closes the
//! declared-not-checked gap of the classifier tables (R12-F1's classifier side)
//! and nothing else.

use super::classify::{ClassifierTables, Policy};
use super::super::shape::Shape;
use super::super::trained_statement::TrainedModelStatement;
use super::Digest;
use super::super::run::read_regular_file_bounded;
use super::super::tied_tables;
use super::super::trained_block::{parse_json, sha256, J};
use super::FinalNorm;
use std::path::Path;

/// the development rung's tied tensor file, in the classifier tables directory
pub(crate) const DEV_TIED_TENSOR_FILE: &str = "dev_tied_tensor_bf16.bin";
/// **the development rung's tensor pin**: SHA-256 of the 2 (V d + d) bytes
/// (V = 300, d = 384; BF16 little-endian), recomputed independently by
/// `results/zk60_token_io_r1_20261017/r13/tools/dev_tied_reference.py`
pub(crate) const DEV_TIED_TENSOR_SHA256: &str = "bba6d094831861aa0b207ae5ca46938e2115e02c81215ba95e27e2bad1cc1dd6";
/// the development rung's tensor geometry (its policy's V, the rung's d)
pub(crate) const DEV_TIED_V: usize = 300;
pub(crate) const DEV_TIED_D: usize = 384;
const MAX_PROFILE_BYTES: u64 = 4 << 20;

/// Where a classifier profile's tables come from (fixed per block profile).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum TiedSource {
    /// the pinned Shieldstral checkpoint, through native R12b's recompute
    Shieldstral,
    /// the development rung's pinned synthetic tensor (R12b's quantizer)
    DevRung,
}

impl TiedSource {
    /// the tied source of a BLOCK profile; anything unregistered is refused
    pub(crate) fn of(block_profile: &str) -> Result<TiedSource, String> {
        use super::super::shape::TRAINED_CALIB_RUNG_PROFILE;
        if super::super::trained_statement::tied_tensor_for_profile(block_profile).is_some() {
            Ok(TiedSource::Shieldstral)
        } else if block_profile == TRAINED_CALIB_RUNG_PROFILE {
            Ok(TiedSource::DevRung)
        } else {
            Err(format!("classifier (R-C2): no tied source is registered for the block profile {block_profile}; the margin row and embedding cannot be re-derived, so no classifier tables are admitted"))
        }
    }
    /// the tied source of a CLASSIFIER RUN profile (its canonical text)
    pub(crate) fn of_run_profile(run_profile: &str) -> Result<TiedSource, String> {
        match run_profile {
            super::super::run::RUN_PROFILE_CLASSIFY_RUNG_TC => Ok(TiedSource::DevRung),
            p => Err(format!("classifier (R-C2): no tied source is registered for the classifier run profile {p}")),
        }
    }
    /// the canonical text (bound through the classifier profile digest)
    pub(crate) fn describe(self) -> String {
        match self {
            TiedSource::Shieldstral => format!(
                "tied-source=shieldstral-checkpoint tensor={} sha256={} derivation=native-R12b-recompute_tied_tables(rotate-then-floor(x/scale+0.5),refuse-outside-int16,no-clip)",
                super::super::trained_statement::SHIELDSTRAL_TIED_TENSOR,
                super::super::trained_statement::SHIELDSTRAL_TIED_TENSOR_SHA256
            ),
            TiedSource::DevRung => format!(
                "tied-source=dev-rung-synthetic-bf16 file={DEV_TIED_TENSOR_FILE} V={DEV_TIED_V} d={DEV_TIED_D} sha256={DEV_TIED_TENSOR_SHA256} derivation=R12b-quantize(floor(x/scale+0.5),refuse-outside-int16,no-clip,no-rotation)"
            ),
        }
    }
}

/// **The classifier's tables as re-derived from the pinned tensor** (no
/// exported table was read to make them).
#[derive(Clone, Debug)]
pub(crate) struct TiedClassifier {
    pub source: TiedSource,
    /// SHA-256 of the int16 little-endian embedding table (`V x d`)
    pub emb_sha256: [u8; 32],
    /// the derived embedding itself, when the derivation keeps it (the dev
    /// rung's; Shieldstral's is digest-only, 805 MB)
    pub emb: Option<Vec<i16>>,
    /// the recomputed margin row (`d` words, each in `[-32767, 32767]`)
    pub w: Vec<i16>,
    /// `token_io_parameters.bos`
    pub bos: u64,
    /// `token_io_parameters.classifier_final_norm`
    pub norm: FinalNorm,
    /// SHA-256 of the `profile.json` bytes the derivation read (its authority)
    pub profile_sha256: [u8; 32],
    /// the bound profile's margin parameters the row was derived with
    pub margin: MarginParameters,
}

fn i16_le(v: &[i16]) -> Vec<u8> {
    v.iter().flat_map(|x| x.to_le_bytes()).collect()
}

fn final_norm_of(n: &tied_tables::TiedFinalNorm) -> FinalNorm {
    FinalNorm { g0: n.g0, cn: n.cn, tn: n.tn, ceps: n.ceps }
}

/// **The margin parameters** (reviewer requirement 1, REVIEW_R12B §5): the
/// verdict ids, the public scale and the threshold, read ONLY from the
/// statement-bound export profile's `classifier_margin_parameters`
/// (`yes_id`, `no_id`, `public_scale`, `threshold_c`). The registered policy
/// (B-6) must name the same four values, and any copy in `classifier.json`
/// (outside the profile digest) must equal them; otherwise the run is refused.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct MarginParameters {
    pub yes: u64,
    pub no: u64,
    /// `public_scale` as binary64 bits (used EXACTLY, N-r12b-6)
    pub scale_bits: u64,
    pub c: i64,
}

impl MarginParameters {
    pub(crate) fn scale(&self) -> f64 {
        f64::from_bits(self.scale_bits)
    }
    fn of_profile(profile: &J) -> Result<MarginParameters, String> {
        let m = profile.get("classifier_margin_parameters").map_err(|_| "classifier (R-C2): profile.json must supply classifier_margin_parameters (yes_id, no_id, public_scale, threshold_c) inside the statement-bound profile digest".to_string())?;
        let id = |k: &str| m.get(k).and_then(J::i64).map_err(|e| format!("classifier_margin_parameters.{k}: {e}")).and_then(|v| u64::try_from(v).map_err(|_| format!("classifier_margin_parameters.{k} is negative")));
        let scale = m.get("public_scale").and_then(J::f64).map_err(|e| format!("classifier_margin_parameters.public_scale: {e}"))?;
        if !scale.is_finite() || scale <= 0.0 {
            return Err("classifier (R-C2): classifier_margin_parameters.public_scale is not a finite positive scale".into());
        }
        let c = m.get("threshold_c").and_then(J::i64).map_err(|e| format!("classifier_margin_parameters.threshold_c: {e}"))?;
        Ok(MarginParameters { yes: id("yes_id")?, no: id("no_id")?, scale_bits: scale.to_bits(), c })
    }
    /// the registered policy must name exactly these values
    pub(crate) fn check_policy(&self, policy: &Policy) -> Result<(), String> {
        if (policy.yes, policy.no, policy.margin_scale_bits, policy.c) != (self.yes, self.no, self.scale_bits, self.c) {
            return Err(format!(
                "classifier (R-C2): the registered policy {:?} (yes {}, no {}, scale {:e}, c {}) is not the export profile's classifier_margin_parameters (yes {}, no {}, scale {:e}, c {})",
                policy.id, policy.yes, policy.no, policy.margin_scale(), policy.c, self.yes, self.no, self.scale(), self.c
            ));
        }
        Ok(())
    }
    /// `classifier.json`'s copies (Astra's writer carries `yes_id`, `no_id`,
    /// `threshold_c` and `margin_vector.scale`): each one present must be equal
    pub(crate) fn check_copies(&self, cj: &J) -> Result<(), String> {
        let bad = |k: &str| Err(format!("classifier (R-C2): classifier.json's {k} is not the export profile's classifier_margin_parameters (the file is outside the profile digest and never an authority)"));
        for (k, want) in [("yes_id", self.yes as i64), ("no_id", self.no as i64), ("threshold_c", self.c)] {
            if let Some(v) = cj.opt(k) {
                if v.i64().ok() != Some(want) {
                    return bad(k);
                }
            }
        }
        if let Some(v) = cj.opt("margin_vector").and_then(|m| m.opt("scale")) {
            if v.f64().ok().map(f64::to_bits) != Some(self.scale_bits) {
                return bad("margin_vector.scale");
            }
        }
        Ok(())
    }
}

/// the export's `profile.json`, read once and required to be the bytes the
/// trained statement binds (reviewer requirement 2)
fn bound_profile(export: &Path, statement_profile_sha256: &[u8; 32]) -> Result<(Vec<u8>, J), String> {
    let bytes = read_regular_file_bounded(&export.join("profile.json"), MAX_PROFILE_BYTES, false)?;
    if sha256(&bytes) != *statement_profile_sha256 {
        return Err("classifier (R-C2): profile.json is not the profile the trained statement binds (export_profile_sha256)".into());
    }
    let profile = parse_json(&bytes).map_err(|e| format!("profile.json: {e}"))?;
    Ok((bytes, profile))
}

/// **R-C2: re-derive the classifier's tables from the pinned tensor.**
/// `statement_profile_sha256` is the trained statement's
/// `export_profile_sha256`; `residual_unit` the export's embedding scale (in
/// the statement's provenance); `d` the block width. The margin parameters
/// come from the bound profile; `policy` must agree with them. Reads no
/// exported integer table.
pub(crate) fn recompute_tied_classifier(source: TiedSource, export: &Path, tables: &Path, policy: &Policy, residual_unit: f64, d: usize, statement_profile_sha256: &[u8; 32]) -> Result<TiedClassifier, String> {
    let (pbytes, profile) = bound_profile(export, statement_profile_sha256)?;
    let mp = MarginParameters::of_profile(&profile)?;
    mp.check_policy(policy)?;
    let id = |x: u64| u32::try_from(x).map_err(|_| format!("classifier (R-C2): the verdict id {x} is out of range"));
    let tied = match source {
        TiedSource::Shieldstral => {
            // requirement 3 / 4: the native row (refusals propagate, never clamped)
            let r = shieldstral_recompute(export, (id(mp.yes)?, id(mp.no)?, mp.scale()))?;
            let w = r.margin.ok_or("classifier (R-C2): the R12b recompute returned no margin row")?;
            if w.len() != d {
                return Err(format!("classifier (R-C2): the recomputed margin row has {} words; the block width is {d}", w.len()));
            }
            TiedClassifier { source, emb_sha256: r.embedding_sha256, emb: None, w, bos: u64::from(r.calibration.bos), norm: final_norm_of(&r.calibration.classifier_final_norm), profile_sha256: r.calibration.profile_sha256, margin: mp }
        }
        TiedSource::DevRung => derive_dev(&profile, &pbytes, tables, policy.v, mp, residual_unit, d)?,
    };
    // requirement 2, after the derivation's own read: the same bound bytes
    if tied.profile_sha256 != *statement_profile_sha256 {
        return Err("classifier (R-C2): the derivation read a profile.json other than the one the trained statement binds".into());
    }
    Ok(tied)
}

/// native R12b's recompute (it reads `profile.json` and streams the pinned
/// checkpoint itself). Test builds may put a stub in its place
/// ([`stub_shieldstral_recompute`]: REVIEW_R13 N-r13-2, so the
/// post-derivation digest check above has a test that fails without it).
fn shieldstral_recompute(export: &Path, m: (u32, u32, f64)) -> Result<tied_tables::RecomputedTiedTables, String> {
    #[cfg(test)]
    if let Some(r) = SHIELDSTRAL_STUB.with(|s| s.borrow().as_ref().map(|f| f(export, m))) {
        return r;
    }
    tied_tables::recompute_tied_tables(export, Some(m))
}

#[cfg(test)]
type ShieldstralStubFn = Box<dyn Fn(&Path, (u32, u32, f64)) -> Result<tied_tables::RecomputedTiedTables, String>>;

#[cfg(test)]
thread_local! {
    /// test only: a stand-in for native R12b's recompute on this thread
    static SHIELDSTRAL_STUB: std::cell::RefCell<Option<ShieldstralStubFn>> = const { std::cell::RefCell::new(None) };
}

/// test only: native R12b's recompute is replaced by `f` on this thread until
/// the returned guard drops (no checkpoint is read)
#[cfg(test)]
pub(crate) fn stub_shieldstral_recompute(f: ShieldstralStubFn) -> ShieldstralStubGuard {
    SHIELDSTRAL_STUB.with(|s| *s.borrow_mut() = Some(f));
    ShieldstralStubGuard
}

#[cfg(test)]
pub(crate) struct ShieldstralStubGuard;

#[cfg(test)]
impl Drop for ShieldstralStubGuard {
    fn drop(&mut self) {
        SHIELDSTRAL_STUB.with(|s| *s.borrow_mut() = None);
    }
}

/// the development rung's derivation (R12b's quantizer, no rotation; the
/// final-norm weights folded in ONCE, here, as at Shieldstral: requirement 5)
fn derive_dev(profile: &J, pbytes: &[u8], tables: &Path, v: usize, mp: MarginParameters, residual_unit: f64, d: usize) -> Result<TiedClassifier, String> {
    let (yes, no) = (mp.yes as usize, mp.no as usize);
    if (v, d) != (DEV_TIED_V, DEV_TIED_D) {
        return Err(format!("classifier (R-C2): the development rung's tied tensor is {DEV_TIED_V} x {DEV_TIED_D}; the policy and block give {v} x {d}"));
    }
    if yes == no || yes >= v || no >= v {
        return Err("classifier (R-C2): invalid yes / no ids for the tied tensor".into());
    }
    if profile.opt("metadata_out_of_proof").and_then(|m| m.opt("rotation")).is_some() {
        return Err("classifier (R-C2): the development rung's tied source has no rotation, but this export declares one".into());
    }
    let tp = profile.get("token_io_parameters").map_err(|_| "classifier (R-C2): profile.json must supply token_io_parameters (bos, classifier_final_norm, head_final_norm): the calibration authority (native R12b)".to_string())?;
    let bos = tp.get("bos").and_then(J::i64).map_err(|e| format!("token_io_parameters.bos: {e}"))?;
    let bos = u64::try_from(bos).ok().filter(|b| (*b as usize) < v).ok_or("classifier (R-C2): token_io_parameters.bos is not an id below V")?;
    // R12b's own class check (the head's declared class; the classifier door
    // then pins the 32-bit remainder window at this d)
    let norm = tied_tables::norm(tp.get("classifier_final_norm").map_err(|e| format!("token_io_parameters.classifier_final_norm: {e}"))?, false)?;
    tied_tables::norm(tp.get("head_final_norm").map_err(|e| format!("token_io_parameters.head_final_norm: {e}"))?, false)?;
    // the pinned tensor: exact length, then the pin
    let words = v * d + d;
    let tbytes = read_regular_file_bounded(&tables.join(DEV_TIED_TENSOR_FILE), 2 * words as u64, true)?;
    if super::super::trained_block::hex(&sha256(&tbytes)) != DEV_TIED_TENSOR_SHA256 {
        return Err(format!("classifier (R-C2): {DEV_TIED_TENSOR_FILE} is not the pinned development tensor"));
    }
    let vals = tied_tables::bf16(&tbytes)?;
    let (rows, g) = vals.split_at(v * d);
    let mut emb: Vec<i16> = Vec::with_capacity(v * d);
    for row in rows.chunks_exact(d) {
        let widened: Vec<f64> = row.iter().map(|x| f64::from(*x as f32)).collect();
        emb.extend(tied_tables::quantize(&widened, residual_unit, -32768, 32767)?.into_iter().map(|q| q as i16));
    }
    let diff: Vec<f64> = (0..d).map(|i| (rows[yes * d + i] - rows[no * d + i]) * g[i]).collect();
    let w: Vec<i16> = tied_tables::quantize(&diff, mp.scale(), -32767, 32767)?.into_iter().map(|q| q as i16).collect();
    Ok(TiedClassifier { source: TiedSource::DevRung, emb_sha256: sha256(&i16_le(&emb)), emb: Some(emb), w, bos, norm: final_norm_of(&norm), profile_sha256: sha256(pbytes), margin: mp })
}

/// **R-C2's comparison**: the files (already length- and manifest-checked by
/// the R-C1 reader) against the re-derivation. Every disagreement refused.
pub(crate) fn check_files_against(tied: &TiedClassifier, w_file: &[i16], emb_file_sha256: &[u8; 32], bos: u64, norm: FinalNorm) -> Result<(), String> {
    if *emb_file_sha256 != tied.emb_sha256 {
        return Err("classifier (R-C2): embedding_int16.bin is not the table derived from the pinned tied tensor (its manifest's digest is consistent, but the table is not the model's)".into());
    }
    if w_file != tied.w.as_slice() {
        return Err("classifier (R-C2): margin_int16.bin is not the margin row recomputed from the pinned tensor with the bound profile's yes / no ids and public scale (the file is compared, never trusted)".into());
    }
    if bos != tied.bos {
        return Err(format!("classifier (R-C2): classifier.json's bos {bos} is not the export's token_io_parameters.bos {}", tied.bos));
    }
    if norm != tied.norm {
        return Err("classifier (R-C2): classifier.json's final_norm is not the export's token_io_parameters.classifier_final_norm".into());
    }
    Ok(())
}

/// **ROUND 14 (REVIEW_R13 N-r13-1): THE CLASSIFIER'S TABLES, BOUND.** The
/// one form every classifier run entry point takes. The fields are private to
/// this module, so outside it a value exists only as [`load_bound_tables`]
/// returns it: the embedding and the margin row RE-DERIVED from the pinned
/// tensor for one trained statement (its identity and its
/// `export_profile_sha256`, the bound profile's margin parameters, BOS and the
/// final norm), every table file compared with them.
#[derive(Clone, Debug)]
pub(crate) struct BoundClassifierTables {
    tables: ClassifierTables,
    bos: u64,
    norm: FinalNorm,
    source: TiedSource,
    margin: MarginParameters,
    /// the trained statement's `export_profile_sha256`, the profile the
    /// derivation read
    profile_sha256: [u8; 32],
    /// the trained statement the tables were derived for
    model_identity: Digest,
    /// test builds: the relation tests' synthetic binding (not derived)
    #[cfg(test)]
    synthetic: bool,
}

impl BoundClassifierTables {
    /// the tables (the RECOMPUTED margin row; the derived embedding)
    pub(crate) fn tables(&self) -> &ClassifierTables {
        &self.tables
    }
    /// BOS, the export's `token_io_parameters.bos`
    pub(crate) fn bos(&self) -> u64 {
        self.bos
    }
    /// the classifier final norm, the export's `token_io_parameters`'
    pub(crate) fn norm(&self) -> FinalNorm {
        self.norm
    }
    pub(crate) fn source(&self) -> TiedSource {
        self.source
    }
    pub(crate) fn margin(&self) -> MarginParameters {
        self.margin
    }
    pub(crate) fn profile_sha256(&self) -> [u8; 32] {
        self.profile_sha256
    }
    pub(crate) fn model_identity(&self) -> Digest {
        self.model_identity
    }
    /// derived from the pinned tensor (always, outside test builds)
    pub(crate) fn is_derived(&self) -> bool {
        #[cfg(test)]
        {
            !self.synthetic
        }
        #[cfg(not(test))]
        {
            true
        }
    }

    /// **THE LIBRARY'S BINDING CHECK** (the classifier statement's
    /// constructor, on both sides): the block profile and the run profile name
    /// the same tied source (N-r13-6), the tables' source is it, they were
    /// derived for THIS trained statement (identity and profile digest), the
    /// policy names the bound profile's margin parameters, the width is the
    /// block's.
    pub(crate) fn check_for(&self, sh: &Shape, run_profile: &str, model: &TrainedModelStatement, policy: &Policy) -> Result<(), String> {
        let (block_src, run_src) = (TiedSource::of(sh.profile)?, TiedSource::of_run_profile(run_profile)?);
        if block_src != run_src {
            return Err(format!("classifier (N-r13-6): the block profile {} has the tied source {:?}, the run profile {run_profile} names {:?}", sh.profile, block_src, run_src));
        }
        if self.source != block_src {
            return Err(format!("classifier (N-r13-1): the tables come from the tied source {:?}; the block profile's is {:?}", self.source, block_src));
        }
        if self.model_identity != model.identity() || self.profile_sha256 != model.calibration.export_profile_sha256 {
            return Err("classifier (N-r13-1): the classifier tables were derived for another trained statement (identity or export_profile_sha256), not this run's".into());
        }
        self.margin.check_policy(policy)?;
        if self.tables.d != sh.width {
            return Err(format!("classifier (N-r13-1): the tables are {} wide, the block width is {}", self.tables.d, sh.width));
        }
        Ok(())
    }

    /// **TEST BUILDS ONLY: the relation tests' synthetic binding** (R-C1's
    /// forgery tests and the s25 census prove the stage relations on a generic
    /// embedding and a random margin row). Marked as not derived: the capture
    /// replay refuses such a run, and no production build has this function.
    #[cfg(test)]
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn synthetic_for_relation_tests(tables: ClassifierTables, bos: u64, norm: FinalNorm, sh: &Shape, run_profile: &str, model: &TrainedModelStatement, policy: &Policy) -> Result<BoundClassifierTables, String> {
        let source = TiedSource::of_run_profile(run_profile)?;
        if TiedSource::of(sh.profile)? != source {
            return Err("synthetic binding: the block and run profiles name different tied sources".into());
        }
        Ok(BoundClassifierTables {
            tables,
            bos,
            norm,
            source,
            margin: MarginParameters { yes: policy.yes, no: policy.no, scale_bits: policy.margin_scale_bits, c: policy.c },
            profile_sha256: model.calibration.export_profile_sha256,
            model_identity: model.identity(),
            synthetic: true,
        })
    }
}

/// **THE R-C2 LOADER, BOUND (round 14: the library's only table
/// constructor)**: the re-derivation under the trained statement `model`'s own
/// `export_profile_sha256` and residual unit, the R-C1 file reader, the
/// comparison (and `classifier.json`'s parameter copies). The returned tables
/// carry the RECOMPUTED margin row; BOS and the final norm are the export's;
/// they are bound to `model`.
pub(crate) fn load_bound_tables(sh: &Shape, model: &TrainedModelStatement, export: &Path, tables: &Path, policy: &Policy) -> Result<BoundClassifierTables, String> {
    let source = TiedSource::of(sh.profile)?;
    let bound = model.calibration.export_profile_sha256;
    let residual_unit = f64::from_bits(model.calibration.residual_unit_f64_bits);
    let tied = recompute_tied_classifier(source, export, tables, policy, residual_unit, sh.width, &bound)?;
    let cp = tables.join("classifier.json");
    let cj = parse_json(&read_regular_file_bounded(&cp, MAX_PROFILE_BYTES, false)?).map_err(|e| format!("{}: {e}", cp.display()))?;
    tied.margin.check_copies(&cj)?;
    let (files, bos, norm, emb_sha) = super::classify_cli::read_classifier_files(tables, sh.width)?;
    check_files_against(&tied, &files.w_delta, &emb_sha, bos, norm)?;
    let ClassifierTables { v, d, emb, .. } = files;
    Ok(BoundClassifierTables {
        tables: ClassifierTables::new(v, d, emb, tied.w)?,
        bos: tied.bos,
        norm: tied.norm,
        source,
        margin: tied.margin,
        profile_sha256: tied.profile_sha256,
        model_identity: model.identity(),
        #[cfg(test)]
        synthetic: false,
    })
}

/// **THE R-C2 LOADER at the CLI** (prove and verify): [`load_bound_tables`]
/// for an export loaded under its classifier run profile; the export's
/// residual unit must be the one its trained statement records
pub(crate) fn load_tied_classifier_tables(p: &super::load::ExportPublic, export: &Path, tables: &Path, policy: &Policy) -> Result<BoundClassifierTables, String> {
    if p.ex.residual_unit.to_bits() != p.model.calibration.residual_unit_f64_bits {
        return Err("classifier (R-C2): the export's residual unit is not the one its trained statement records".into());
    }
    load_bound_tables(&p.sh, &p.model, export, tables, policy)
}

/// D27: the verifier's lowest admissible `--min-bits` per classifier run
/// profile — 93 only at the development rung, 95 at every other profile
pub(crate) fn min_bits_floor(run_profile: &str) -> u32 {
    if run_profile == super::super::run::RUN_PROFILE_CLASSIFY_RUNG_TC {
        93
    } else {
        95
    }
}

/// the development rung's synthetic tied tensor (TEST ONLY: its digest is
/// the production pin [`DEV_TIED_TENSOR_SHA256`]). Rows: BF16 with a random
/// sign, exponent 2^-7 .. 2^4 and mantissa; final-norm weights in [0.5, 2).
#[cfg(test)]
pub(crate) fn dev_tied_tensor_bytes() -> Vec<u8> {
    let mut s: u64 = 0x7469_6564_2d64_6576;
    let n = DEV_TIED_V * DEV_TIED_D;
    let mut out = Vec::with_capacity(2 * (n + DEV_TIED_D));
    for k in 0..n + DEV_TIED_D {
        s = s.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        let r = s >> 33;
        let bits = if k < n { ((r & 1) << 15) | ((120 + (r >> 1) % 12) << 7) | ((r >> 5) & 0x7f) } else { ((126 + (r & 1)) << 7) | ((r >> 1) & 0x7f) };
        out.extend_from_slice(&(bits as u16).to_le_bytes());
    }
    out
}

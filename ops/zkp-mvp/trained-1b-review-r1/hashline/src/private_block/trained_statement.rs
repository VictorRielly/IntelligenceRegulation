//! **LANE C SCRATCH PROTOTYPE (2026-09-30) — NOT IN THE MAIN TREE.**
//!
//! The separately versioned MODEL / PROFILE / CALIBRATION statement of a
//! trained-model run, and the one digest of it a run binds.
//!
//! **Why it exists.** Every existing profile absorbs the same calibration
//! identity, `calibration_identity()` = `blake3("B3 public fixed calibration
//! v1")` (`private_block.rs`), which names the synthetic fixture's calibration
//! and says nothing about where the public words came from. A trained-model
//! run must bind, in a form a verifier checks against its OWN trusted copy:
//!
//! 1. the SOURCE identity — repository, immutable revision, the tensor file's
//!    SHA-256, the config's SHA-256, the checkpoint's parameter and layer
//!    counts, and every source tensor the importer read (name + SHA-256 of its
//!    raw bytes);
//! 2. the INTEGER CALIBRATION — every constant the proof relations use
//!    (`layout.rs:62-80` plus the shape's two windows), the endpoint/boundary
//!    scale labels, the float value of one residual unit, and the digests of
//!    the quantizer and of the public calibration token set;
//! 3. the INTEGER MODEL — per proved layer, the `BlockPublic::digest()` the run
//!    header absorbs, and the SHA-256 of each of the nine padded integer words
//!    and of the three public tables, so a single tensor can be audited
//!    without re-running the proof;
//! 4. the PROFILE and GEOMETRY strings, and the D13 coverage sentence.
//!
//! **How it is bound.** `run::RunStatement::new_bound` absorbs
//! [`TrainedModelStatement::identity`] in the run header's existing
//! `"calibration"` slot (32 bytes, the same label and length every run
//! already absorbs there, so no hash-length guard moves), after checking the
//! statement against the run: same run and block profile, same geometry,
//! `L` layer records whose block digests equal the run's own, and scales equal
//! to the calibration's. The toy, every development rung and 125M keep the
//! literal identity byte for byte: they never call this module.
//!
//! **What it does NOT do.** It proves nothing about the float model. The
//! proof is about the INTEGER model whose words the digests name; how close
//! that integer model is to the BF16 checkpoint is a calibration-validation
//! measurement, separate from any proof. A statement names the source it was
//! imported from; the verifier must still hold (or recompute) the integer
//! words it trusts. It is not a privacy statement.

use super::shape::Shape;
use super::BlockPublic;
use crate::merkle::Digest;
use sha2::{Digest as _, Sha256};

/// the statement's schema tag, the first field of its encoding
/// NATIVE LANE: version 2 — two norm multipliers, export provenance and the
/// per-layer export manifest digest
pub(crate) const SCHEMA: &str = "zk60-trained-model-statement/2";
/// the identity's hash domain (the repository's convention: a versioned
/// literal prefix under the plain hash, then length-prefixed fields)
const DOMAIN: &[u8] = b"hashline/private-run/trained-model-statement/v2";
/// the D13 coverage sentence every v1 statement carries verbatim
pub(crate) const COVERAGE_D13: &str =
    "proves the hidden transformer blocks listed below and nothing else: embedding, final norm, output head and token selection are NOT covered (D13)";

/// Where the public words came from.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum SourceKind {
    /// an immutable Hugging Face checkpoint revision
    HfCheckpoint,
    /// a public synthetic recipe (test and development runs only). A statement
    /// of this kind may never carry a trained profile string.
    PublicSyntheticRecipe,
}

impl SourceKind {
    fn tag(&self) -> &'static str {
        match self {
            SourceKind::HfCheckpoint => "hf-checkpoint",
            SourceKind::PublicSyntheticRecipe => "public-synthetic-recipe",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct ModelSource {
    pub kind: SourceKind,
    pub repo: String,
    /// 40 lowercase hex characters for a checkpoint; the recipe name otherwise
    pub revision: String,
    pub weights_sha256: [u8; 32],
    pub config_sha256: [u8; 32],
    pub checkpoint_parameters: u64,
    pub checkpoint_layers: u32,
}

fn hex32(s: &str) -> [u8; 32] {
    assert_eq!(s.len(), 64, "a SHA-256 is 64 hex characters");
    let mut out = [0u8; 32];
    for (i, b) in out.iter_mut().enumerate() {
        *b = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).expect("hex");
    }
    out
}

impl ModelSource {
    /// **The pinned TinyLlama source** (`results/zk60_mvp_20260929/
    /// tinyllama-1.1b/source.json`, local SHA-256 re-verified 2026-09-29):
    /// 22 layers, 1,100,048,384 parameters, 201 tensors.
    pub(crate) fn tinyllama_chat_v1_0() -> ModelSource {
        ModelSource {
            kind: SourceKind::HfCheckpoint,
            repo: "TinyLlama/TinyLlama-1.1B-Chat-v1.0".into(),
            revision: "fe8a4ea1ffedaf415f4da2f062534de366a451e6".into(),
            weights_sha256: hex32("6e6001da2106d4757498752a021df6c2bdc332c650aae4bae6b0c004dcf14933"),
            config_sha256: hex32("486bedda3a6988332e60d9638a09ca4b260d34ebcf1b19e22cf3b140b63d8fe9"),
            checkpoint_parameters: 1_100_048_384,
            checkpoint_layers: 22,
        }
    }

    fn check(&self) -> Result<(), String> {
        if self.kind == SourceKind::HfCheckpoint {
            let hex_ok = self.revision.len() == 40 && self.revision.bytes().all(|c| c.is_ascii_digit() || (b'a'..=b'f').contains(&c));
            if !hex_ok {
                return Err("trained statement: a checkpoint revision is 40 lowercase hex characters (a branch name is not immutable)".into());
            }
            if self.weights_sha256 == [0; 32] || self.config_sha256 == [0; 32] {
                return Err("trained statement: a checkpoint source needs its tensor-file and config SHA-256".into());
            }
        }
        if self.repo.is_empty() || self.checkpoint_layers == 0 {
            return Err("trained statement: the source names no repository or no layers".into());
        }
        Ok(())
    }
}

/// **Every constant the proof relations use**, as the statement declares it.
///
/// v1 has ONE set for every block, because the code has no per-layer
/// constants: `layout.rs:62-80` are `const`s read by `witness.rs`,
/// `argument.rs` and `slot_ir.rs`. [`IntegerCalibration::check_honoured_by_code`]
/// refuses a record that declares anything the relations do not actually use,
/// so a statement can never claim a calibration the proof did not prove.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct IntegerCalibration {
    pub label: String,
    pub norm_tn: u32,
    /// NATIVE LANE: norm_a's and norm_m's multipliers are separate
    pub norm_cn_a: i64,
    pub norm_cn_m: i64,
    pub norm_ceps: i64,
    pub norm_wrho: u32,
    pub sh_qkv: u32,
    pub sh_rope: u32,
    pub sh_s: u32,
    pub sh_o: u32,
    pub sh_ao: u32,
    pub sh_g: u32,
    pub sh_u: u32,
    pub sh_h: u32,
    pub sh_z: u32,
    pub residual_shifts: [u32; 6],
    pub f_e: u32,
    pub f_p: u32,
    pub f_ro: u32,
    pub wrho_s: u32,
    pub mask_score: i64,
    /// the `(input, output)` scale label every block declares (`IoSpec`)
    pub block_scales: (i32, i32),
    /// provenance only: the float value of one residual-stream integer unit,
    /// IEEE-754 binary64 bits (the proof is about the integer model)
    pub residual_unit_f64_bits: u64,
    pub quantizer_sha256: [u8; 32],
    pub calibration_set_sha256: [u8; 32],
    /// NATIVE LANE, export provenance (zero for a synthetic recipe): the
    /// SHA-256 of the calibration export's `profile.json` and of the
    /// calibration tool it names
    pub export_profile_sha256: [u8; 32],
    pub calibration_tool_sha256: [u8; 32],
    /// provenance of the public tables (they are bound by value through the
    /// block digest; these say which generator member they are): the SiLU
    /// registry member `(e_in, e_out)`, the exp table's score exponent `e_s`
    /// and the RoPE base as IEEE-754 binary64 bits
    pub silu_member: (i32, i32),
    pub exp_e_s: i32,
    pub rope_theta_f64_bits: u64,
}

/// The out-of-relation provenance a calibration record carries (none of it is
/// a constant the relations read; all of it is bound by the identity).
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Provenance {
    pub label: String,
    pub residual_unit: f64,
    pub quantizer_sha256: [u8; 32],
    pub calibration_set_sha256: [u8; 32],
    pub export_profile_sha256: [u8; 32],
    pub calibration_tool_sha256: [u8; 32],
    pub silu_member: (i32, i32),
    pub exp_e_s: i32,
    pub rope_theta: f64,
}

impl Provenance {
    /// a synthetic recipe's provenance (no export): the frozen SiLU member
    /// `(-3, -11)`, `e_s = 0` and RoPE base 10000, as `parity::shaped_case`
    /// and `dense_tests::dense_case` generate them
    pub(crate) fn recipe(label: &str, residual_unit: f64, quantizer_sha256: [u8; 32], calibration_set_sha256: [u8; 32]) -> Provenance {
        Provenance {
            label: label.into(),
            residual_unit,
            quantizer_sha256,
            calibration_set_sha256,
            export_profile_sha256: [0; 32],
            calibration_tool_sha256: [0; 32],
            silu_member: (-3, -11),
            exp_e_s: 0,
            rope_theta: 10000.0,
        }
    }
}

impl IntegerCalibration {
    /// The constants the CURRENT code proves with, read from the code's own
    /// `const`s and the shape's fields — not retyped. NATIVE LANE: the norm
    /// calibration (`tn`, both `Cn`, `Ceps`) and `sh_ao` are the SHAPE's
    /// (the frozen literals at every registered profile).
    pub(crate) fn as_the_code_proves(sh: &Shape, prov: &Provenance) -> IntegerCalibration {
        use super::layout::*;
        IntegerCalibration {
            label: prov.label.clone(),
            norm_tn: sh.norm_tn,
            norm_cn_a: sh.norm_cn_a,
            norm_cn_m: sh.norm_cn_m,
            norm_ceps: sh.norm_ceps,
            norm_wrho: sh.norm_wrho,
            sh_qkv: SH_QKV,
            sh_rope: SH_ROPE,
            sh_s: SH_S,
            sh_o: SH_O,
            sh_ao: sh.sh_ao,
            sh_g: SH_G,
            sh_u: 0,
            sh_h: SH_H_PROD,
            sh_z: SH_Z,
            residual_shifts: [0; 6],
            f_e: sh.f_e,
            f_p: F_P,
            f_ro: F_RO,
            wrho_s: sh.wrho_s,
            mask_score: MASK_SCORE,
            block_scales: super::ENDPOINT_SCALES,
            residual_unit_f64_bits: prov.residual_unit.to_bits(),
            quantizer_sha256: prov.quantizer_sha256,
            calibration_set_sha256: prov.calibration_set_sha256,
            export_profile_sha256: prov.export_profile_sha256,
            calibration_tool_sha256: prov.calibration_tool_sha256,
            silu_member: prov.silu_member,
            exp_e_s: prov.exp_e_s,
            rope_theta_f64_bits: prov.rope_theta.to_bits(),
        }
    }

    /// this record's out-of-relation provenance
    pub(crate) fn provenance(&self) -> Provenance {
        Provenance {
            label: self.label.clone(),
            residual_unit: f64::from_bits(self.residual_unit_f64_bits),
            quantizer_sha256: self.quantizer_sha256,
            calibration_set_sha256: self.calibration_set_sha256,
            export_profile_sha256: self.export_profile_sha256,
            calibration_tool_sha256: self.calibration_tool_sha256,
            silu_member: self.silu_member,
            exp_e_s: self.exp_e_s,
            rope_theta: f64::from_bits(self.rope_theta_f64_bits),
        }
    }

    /// Refuse, by name, any declared constant the relations do not use at
    /// this shape. NATIVE LANE: the norm calibration is read from the shape's
    /// fields, so a record declaring a `tn`, `Cn`, `Ceps` or `sh_ao` other
    /// than the shape's is refused here, before any run is built.
    pub(crate) fn check_honoured_by_code(&self, sh: &Shape) -> Result<(), String> {
        let code = IntegerCalibration::as_the_code_proves(sh, &self.provenance());
        if *self != code {
            return Err(format!(
                "trained statement: the calibration '{}' declares constants the proof relations at {} do not use (the relations prove the code's constants; see PLAN.md C-1)",
                self.label, sh.profile
            ));
        }
        if !f64::from_bits(self.residual_unit_f64_bits).is_finite() || f64::from_bits(self.residual_unit_f64_bits) <= 0.0 {
            return Err("trained statement: the residual unit is not a positive finite number".into());
        }
        if !f64::from_bits(self.rope_theta_f64_bits).is_finite() || f64::from_bits(self.rope_theta_f64_bits) <= 0.0 {
            return Err("trained statement: the RoPE base is not a positive finite number".into());
        }
        Ok(())
    }
}

/// One proved layer: the digest the run header absorbs, plus its parts.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct LayerRecord {
    /// the checkpoint's own layer index
    pub index: u32,
    pub block_digest: Digest,
    /// SHA-256 of the nine PADDED integer words, in the kernel's order
    /// `[Wq, Wk, Wv, Wo, gamma_a, gamma_m, Wg^T, Wu^T, Wd^T]`
    pub word_sha256: [[u8; 32]; 9],
    /// SHA-256 of the three public tables `[rope cos||sin, exp, act]`
    pub table_sha256: [[u8; 32]; 3],
    /// every source tensor the importer read for this layer: name and the
    /// SHA-256 of its raw (BF16) bytes, sorted by name
    pub source_tensors: Vec<(String, [u8; 32])>,
    /// NATIVE LANE: the SHA-256 of the calibration export's
    /// `layer_NN/manifest.json` this layer was loaded from (zero for a recipe)
    pub manifest_sha256: [u8; 32],
}

fn sha(bytes: &[u8]) -> [u8; 32] {
    Sha256::digest(bytes).into()
}

fn i8_bytes(v: &[i8]) -> Vec<u8> {
    v.iter().map(|x| *x as u8).collect()
}

fn i64_bytes(vs: &[&[i64]]) -> Vec<u8> {
    vs.iter().flat_map(|v| v.iter().flat_map(|x| x.to_le_bytes())).collect()
}

impl LayerRecord {
    /// The record of one block's PUBLIC statement, computed from the words
    /// the prover and the verifier actually use.
    pub(crate) fn of_block(index: u32, blk: &BlockPublic, source_tensors: Vec<(String, [u8; 32])>) -> LayerRecord {
        let (a, f) = (blk.attention(), blk.feed_forward());
        let word_sha256 = [
            sha(&i8_bytes(&a.wq)),
            sha(&i8_bytes(&a.wk)),
            sha(&i8_bytes(&a.wv)),
            sha(&i8_bytes(&a.wo)),
            sha(&i8_bytes(&a.gamma_a)),
            sha(&i8_bytes(&f.gamma_m)),
            sha(&i8_bytes(&f.wg_t)),
            sha(&i8_bytes(&f.wu_t)),
            sha(&i8_bytes(&f.wd_t)),
        ];
        let act: Vec<u8> = f.act.iter().flat_map(|v| v.to_le_bytes()).collect();
        let table_sha256 = [sha(&i64_bytes(&[&a.rope_cos, &a.rope_sin])), sha(&i64_bytes(&[&a.exp])), sha(&act)];
        let mut source_tensors = source_tensors;
        source_tensors.sort();
        LayerRecord { index, block_digest: blk.digest(), word_sha256, table_sha256, source_tensors, manifest_sha256: [0; 32] }
    }
}

/// THE STATEMENT. Built by the importer/calibrator, pinned by whoever
/// approves the model, handed to the verifier through its trusted policy —
/// never read from a receipt.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct TrainedModelStatement {
    pub block_profile: String,
    pub run_profile: String,
    /// `[tokens, width, hidden, q_heads, kv_heads, head_dim, log_cols, inv_rate, opened_cols]`
    pub geometry: [u64; 9],
    pub source: ModelSource,
    pub calibration: IntegerCalibration,
    pub layers: Vec<LayerRecord>,
    pub coverage: String,
}

fn geometry_of(sh: &Shape) -> [u64; 9] {
    [sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim, sh.log_cols, sh.inv_rate, sh.opened_cols].map(|v| v as u64)
}

/// the canonical field writer: `label_len || label || value_len || value`
struct Enc(Vec<u8>);

impl Enc {
    fn field(&mut self, label: &str, value: &[u8]) {
        self.0.extend_from_slice(&(label.len() as u64).to_le_bytes());
        self.0.extend_from_slice(label.as_bytes());
        self.0.extend_from_slice(&(value.len() as u64).to_le_bytes());
        self.0.extend_from_slice(value);
    }
    fn u64(&mut self, label: &str, v: u64) {
        self.field(label, &v.to_le_bytes());
    }
    fn i64(&mut self, label: &str, v: i64) {
        self.field(label, &v.to_le_bytes());
    }
}

impl TrainedModelStatement {
    pub(crate) fn new(sh: &Shape, run_profile: &str, source: ModelSource, calibration: IntegerCalibration, layers: Vec<LayerRecord>) -> Result<TrainedModelStatement, String> {
        let st = TrainedModelStatement {
            block_profile: sh.profile.into(),
            run_profile: run_profile.into(),
            geometry: geometry_of(sh),
            source,
            calibration,
            layers,
            coverage: COVERAGE_D13.into(),
        };
        st.check_self(sh)?;
        Ok(st)
    }

    fn check_self(&self, sh: &Shape) -> Result<(), String> {
        self.source.check()?;
        self.calibration.check_honoured_by_code(sh)?;
        if self.layers.is_empty() {
            return Err("trained statement: no layer is listed".into());
        }
        for (k, w) in self.layers.windows(2).enumerate() {
            if w[1].index != w[0].index + 1 {
                return Err(format!("trained statement: layer record {} is checkpoint layer {}, not {} (records are consecutive)", k + 1, w[1].index, w[0].index + 1));
            }
        }
        let last = self.layers.last().map(|r| r.index).unwrap_or(0);
        if last >= self.source.checkpoint_layers {
            return Err(format!("trained statement: layer {last} does not exist in a {}-layer checkpoint", self.source.checkpoint_layers));
        }
        if self.source.kind == SourceKind::PublicSyntheticRecipe && self.block_profile.contains("tinyllama") && !self.block_profile.ends_with("-dev/1") {
            return Err("trained statement: a synthetic recipe may not carry a trained (non-development) profile".into());
        }
        if self.coverage != COVERAGE_D13 {
            return Err("trained statement: the coverage sentence is not the D13 one".into());
        }
        Ok(())
    }

    /// The canonical bytes. Every field is length-prefixed and labelled, in
    /// one fixed order; nothing here depends on a hash map or a float's
    /// formatting.
    pub(crate) fn encode(&self) -> Vec<u8> {
        let mut e = Enc(Vec::new());
        e.field("schema", SCHEMA.as_bytes());
        e.field("block-profile", self.block_profile.as_bytes());
        e.field("run-profile", self.run_profile.as_bytes());
        for (name, v) in ["tokens", "width", "hidden", "q-heads", "kv-heads", "head-dim", "log-cols", "inv-rate", "opened-cols"].iter().zip(self.geometry.iter()) {
            e.u64(name, *v);
        }
        let s = &self.source;
        e.field("source-kind", s.kind.tag().as_bytes());
        e.field("source-repo", s.repo.as_bytes());
        e.field("source-revision", s.revision.as_bytes());
        e.field("source-weights-sha256", &s.weights_sha256);
        e.field("source-config-sha256", &s.config_sha256);
        e.u64("source-parameters", s.checkpoint_parameters);
        e.u64("source-layers", u64::from(s.checkpoint_layers));
        let c = &self.calibration;
        e.field("calibration-label", c.label.as_bytes());
        for (name, v) in [
            ("norm-tn", c.norm_tn),
            ("norm-wrho", c.norm_wrho),
            ("sh-qkv", c.sh_qkv),
            ("sh-rope", c.sh_rope),
            ("sh-score", c.sh_s),
            ("sh-o", c.sh_o),
            ("sh-ao", c.sh_ao),
            ("sh-gate", c.sh_g),
            ("sh-up", c.sh_u),
            ("sh-product", c.sh_h),
            ("sh-down", c.sh_z),
            ("f-e", c.f_e),
            ("f-p", c.f_p),
            ("f-ro", c.f_ro),
            ("wrho-s", c.wrho_s),
        ] {
            e.u64(name, u64::from(v));
        }
        for (k, v) in c.residual_shifts.iter().enumerate() {
            e.u64(&format!("residual-shift-{k}"), u64::from(*v));
        }
        e.i64("norm-cn-a", c.norm_cn_a);
        e.i64("norm-cn-m", c.norm_cn_m);
        e.i64("norm-ceps", c.norm_ceps);
        e.i64("mask-score", c.mask_score);
        e.i64("block-scale-in", i64::from(c.block_scales.0));
        e.i64("block-scale-out", i64::from(c.block_scales.1));
        e.u64("residual-unit-f64-bits", c.residual_unit_f64_bits);
        e.field("quantizer-sha256", &c.quantizer_sha256);
        e.field("calibration-set-sha256", &c.calibration_set_sha256);
        e.field("export-profile-sha256", &c.export_profile_sha256);
        e.field("calibration-tool-sha256", &c.calibration_tool_sha256);
        e.i64("silu-member-e-in", i64::from(c.silu_member.0));
        e.i64("silu-member-e-out", i64::from(c.silu_member.1));
        e.i64("exp-e-s", i64::from(c.exp_e_s));
        e.u64("rope-theta-f64-bits", c.rope_theta_f64_bits);
        e.u64("layer-records", self.layers.len() as u64);
        for r in &self.layers {
            e.u64("layer-index", u64::from(r.index));
            e.field("block-digest", &r.block_digest);
            e.field("export-manifest-sha256", &r.manifest_sha256);
            for (k, d) in r.word_sha256.iter().enumerate() {
                e.field(&format!("word-{k}-sha256"), d);
            }
            for (k, d) in r.table_sha256.iter().enumerate() {
                e.field(&format!("table-{k}-sha256"), d);
            }
            e.u64("source-tensors", r.source_tensors.len() as u64);
            for (name, d) in &r.source_tensors {
                e.field("source-tensor-name", name.as_bytes());
                e.field("source-tensor-sha256", d);
            }
        }
        e.field("coverage", self.coverage.as_bytes());
        e.0
    }

    /// THE ONE DIGEST a run binds (as its `"calibration"` absorb).
    pub(crate) fn identity(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(DOMAIN);
        h.update(&self.encode());
        *h.finalize().as_bytes()
    }

    /// Is this the statement of THIS run? Every check is against the run's
    /// own quantities (never against a receipt).
    pub(crate) fn check_against(&self, sh: &Shape, run_profile: &str, block_digests: &[Digest], block_scales: &[(i32, i32)]) -> Result<(), String> {
        self.check_self(sh)?;
        if self.block_profile != sh.profile || self.run_profile != run_profile {
            return Err(format!("trained statement: it is for profiles ({}, {}), this run is ({}, {run_profile})", self.block_profile, self.run_profile, sh.profile));
        }
        if self.geometry != geometry_of(sh) {
            return Err("trained statement: its geometry is not this shape's".into());
        }
        if self.layers.len() != block_digests.len() {
            return Err(format!("trained statement: it lists {} layers, the run has {} blocks", self.layers.len(), block_digests.len()));
        }
        for (k, (r, d)) in self.layers.iter().zip(block_digests.iter()).enumerate() {
            if r.block_digest != *d {
                return Err(format!("trained statement: block {k}'s public digest is not the statement's layer {} digest", r.index));
            }
        }
        if block_scales.iter().any(|p| *p != self.calibration.block_scales) {
            return Err(format!("trained statement: a block declares a scale pair other than the calibration's {:?}", self.calibration.block_scales));
        }
        Ok(())
    }
}

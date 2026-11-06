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

use super::shape::{NormCalibration, Shape};
use super::BlockPublic;
use crate::merkle::Digest;
use sha2::{Digest as _, Sha256};

/// the statement's schema tag, the first field of its encoding
/// NATIVE LANE: version 2 — two norm multipliers, export provenance and the
/// per-layer export manifest digest
pub(crate) const SCHEMA: &str = "zk60-trained-model-statement/3";
/// the identity's hash domain (the repository's convention: a versioned
/// literal prefix under the plain hash, then length-prefixed fields)
const DOMAIN: &[u8] = b"hashline/private-run/trained-model-statement/v3";
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

/// the four Llama-3-8B shards and their SHA-256 (source.json, inventory)
pub(crate) const LLAMA3_8B_SHARDS: [(&str, &str); 4] = [
    ("model-00001-of-00004.safetensors", "f2c144103072514542e327fa8080bd375cb300f2d453fba9ca3aea81d0d4cf33"),
    ("model-00002-of-00004.safetensors", "d9eee5f23d94405d90b7e9ff88b9443fee42f8528a658f54214c2aba7530d80c"),
    ("model-00003-of-00004.safetensors", "4b8fbc5e113f69768dd8de84661ea20af8a32b734a9976144b4236c447b40ccc"),
    ("model-00004-of-00004.safetensors", "5dc34e6bdf2da9e35f0d93b5c333c870f3677dc43dc3a91ea3a8ad28a1fe1acb"),
];

/// **The digest of a sharded checkpoint**: SHA-256 of `name hex\n` per shard,
/// sorted by name, hex lower case (the loader computes the same from an
/// export's `model.shards_sha256`)
pub(crate) fn shards_digest(shards: &[(&str, &str)]) -> [u8; 32] {
    let mut v: Vec<(String, String)> = shards.iter().map(|(n, h)| (n.to_string(), h.to_ascii_lowercase())).collect();
    v.sort();
    let text: String = v.iter().map(|(n, x)| format!("{n} {x}\n")).collect();
    sha(text.as_bytes())
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

    /// **ROUND 4 (R4-1): the pinned Llama-3-8B source**
    /// (`results/zk60_mvp_20260929/llama3-8b/source.json` and the inventory
    /// of 2026-10-17): four safetensors shards, so the weights digest is the
    /// SHA-256 of the canonical shard list — `name hex\n` per shard in name
    /// order ([`shards_digest`]); 32 layers, 8,030,261,248 parameters.
    pub(crate) fn llama3_8b() -> ModelSource {
        ModelSource {
            kind: SourceKind::HfCheckpoint,
            repo: "NousResearch/Meta-Llama-3-8B".into(),
            revision: "315b20096dc791d381d514deb5f8bd9c8d6d3061".into(),
            weights_sha256: shards_digest(&LLAMA3_8B_SHARDS),
            config_sha256: hex32("2430cee764b6530ff8673cf9ba8561e1d5a33152d503cd0de909ff5718261441"),
            checkpoint_parameters: 8_030_261_248,
            checkpoint_layers: 32,
        }
    }

    /// **NATIVE R12 (D38): the pinned Shieldstral-1.0-3B source** (the HF API
    /// and the files at revision 003ec7e2b0bab5f0e6307edbaf186fa5822b76f5,
    /// read 2026-10-21; copies under `results/zk60_1b_native_20261017/r12/
    /// reference/`): `model.safetensors` (the transformers-format single
    /// file; LFS SHA-256 below), `config.json` (SHA-256 of its 1,654 bytes,
    /// git blob 87bb9aef...), 3,849,090,048 parameters (the checkpoint's own
    /// count, the Pixtral image tower included; only the 26 text layers are
    /// proved, D38 (a))
    pub(crate) fn shieldstral_1_0_3b() -> ModelSource {
        ModelSource {
            kind: SourceKind::HfCheckpoint,
            repo: "mistralai/Shieldstral-1.0-3B".into(),
            revision: "003ec7e2b0bab5f0e6307edbaf186fa5822b76f5".into(),
            weights_sha256: hex32("87753e30c8c321da478b83bbabebcd813cc9b3d0cee5c5b3d64349a8ee4172f7"),
            config_sha256: hex32("a0b1122916b629ab9c3b54a422476e3f4bf4f2b66353a82c43c349c4fe2257ad"),
            checkpoint_parameters: 3_849_090_048,
            checkpoint_layers: 26,
        }
    }

    /// the pinned source a trained-model profile carries, if it has one
    pub(crate) fn pinned_for_profile(profile: &str) -> Option<ModelSource> {
    let profile=super::shape::accuracy_spec(profile).map(|spec|spec.legacy).unwrap_or(profile);
        if super::shape::TINYLLAMA_TRAINED_PROFILES.contains(&profile) || super::shape::TINYLLAMA_DD_PROFILES.contains(&profile) {
            Some(ModelSource::tinyllama_chat_v1_0())
        } else if super::shape::LLAMA3_8B_TRAINED_PROFILES.contains(&profile) || super::shape::LLAMA3_8B_DD_PROFILES.contains(&profile) {
            Some(ModelSource::llama3_8b())
        } else if super::shape::SHIELDSTRAL_PROFILES.contains(&profile) {
            Some(ModelSource::shieldstral_1_0_3b())
        } else {
            None
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
    /// the RoPE base as IEEE-754 binary64 bits (one per statement: the RoPE
    /// tables are the generator's at this base for every layer). ROUND 2: the
    /// SiLU member and the exp `e_s` moved to [`LayerRecord`], because an
    /// export may choose them per layer (they are per-block public tables)
    pub rope_theta_f64_bits: u64,
    /// **NATIVE R12 (F1): the RoPE frequency transform**, as its canonical
    /// bytes ([`super::rope::RopeScaling::encode`]; `b"none"` before R12). A
    /// model fact pinned per profile, like the base; encoded in the statement
    /// ONLY when it is not `none`, so every statement before R12 keeps its
    /// bytes.
    pub rope_scaling: Vec<u8>,
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
    pub rope_theta: f64,
    /// NATIVE R12 (F1)
    pub rope_scaling: super::rope::RopeScaling,
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
            rope_theta: 10000.0,
            rope_scaling: super::rope::RopeScaling::None,
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
            norm_wrho: if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {sh.norm_wrho} else {24},
            sh_qkv: sh.sh_qkv,
            sh_rope: SH_ROPE,
            sh_s: sh.sh_s,
            sh_o: sh.sh_o,
            sh_ao: sh.sh_ao,
            sh_g: sh.sh_g,
            sh_u: if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {0} else {12},
            sh_h: sh.sh_h,
            sh_z: sh.sh_z,
            residual_shifts: [0; 6],
            f_e: sh.f_e,
            f_p: sh.f_p(),
            f_ro: F_RO,
            wrho_s: sh.wrho_s,
            mask_score: MASK_SCORE,
            block_scales: super::ENDPOINT_SCALES,
            residual_unit_f64_bits: prov.residual_unit.to_bits(),
            quantizer_sha256: prov.quantizer_sha256,
            calibration_set_sha256: prov.calibration_set_sha256,
            export_profile_sha256: prov.export_profile_sha256,
            calibration_tool_sha256: prov.calibration_tool_sha256,
            rope_theta_f64_bits: prov.rope_theta.to_bits(),
            rope_scaling: prov.rope_scaling.encode(),
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
            rope_theta: f64::from_bits(self.rope_theta_f64_bits),
            rope_scaling: super::rope::RopeScaling::decode(&self.rope_scaling).unwrap_or(super::rope::RopeScaling::None),
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
        // the review's general rule: at a trained shape the RoPE base is the
        // geometry's (a model fact, not a calibration choice)
        // ROUND 4: pinned PER PROFILE (10000 TinyLlama / rung, 500000 8B)
        if sh.trained_calibration {
            let want = super::shape::trained_rope_theta(sh.profile).ok_or("trained statement: a trained shape with no pinned RoPE base")?;
            if self.rope_theta_f64_bits != want.to_bits() {
                return Err(format!("trained statement: the RoPE base {} is not the profile's {want}", f64::from_bits(self.rope_theta_f64_bits)));
            }
            // NATIVE R12 (F1): so is the frequency transform
            let pin = super::shape::trained_rope_scaling(sh.profile).ok_or("trained statement: a trained shape with no pinned RoPE transform")?;
            if self.rope_scaling != pin.encode() {
                let got = super::rope::RopeScaling::decode(&self.rope_scaling).map(|r| r.describe()).unwrap_or_else(|_| "an unreadable encoding".into());
                return Err(format!("trained statement: the RoPE transform {got} is not the profile's {}", pin.describe()));
            }
        } else if super::rope::RopeScaling::decode(&self.rope_scaling) != Ok(super::rope::RopeScaling::None) {
            return Err("trained statement: a RoPE transform at a profile that pins none".into());
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
    /// ROUND 2: which generator members this block's tables are (the tables
    /// themselves are bound by value through the block digest and
    /// `table_sha256`): the SiLU registry member `(e_in, e_out)` and the exp
    /// table's score exponent `e_s`
    pub silu_member: (i32, i32),
    pub exp_e_s: i32,
    /// **NATIVE R8 (R6 for `sh_s` alone): this layer's OWN calibration
    /// constants**, one entry per [`OWN_FIELDS`] in that order, each `Some`
    /// only where the layer's value is not the run's: all `None` for every
    /// layer of a run-wide export (so its encoding, and every identity made
    /// before R6, does not move); a value equal to the run's is refused
    /// (one encoding per statement); the layer's whole calibration
    /// ([`apply_own`]) must pass the trained door
    /// (`Shape::with_layer_calibration`). The run proves that block's stage at
    /// that shape.
    pub own: [Option<i64>; 11],
    /// R13's verifier-derived common gate denominator. Always present for
    /// R13 and absent for legacy; its scalar also determines the stage shape.
    pub accuracy_gate_shift:Option<u32>,
}

/// **NATIVE R8: the eleven export-chosen calibration constants a layer may
/// carry as its own**, in their canonical order: the export key, the
/// identity encoding's label, the stage schedule line's label. `sh_s` is
/// FIRST and keeps R6's labels, so a statement or schedule whose only
/// per-layer constant is `sh_s` encodes exactly as in R6 (the b7 identity
/// 97c4acda... and its stage lines do not move).
pub(crate) const OWN_FIELDS: [(&str, &str, &str); 11] = [
    ("sh_s", "sh-score-layer", "score shift"),
    ("norm_tn", "norm-tn-layer", "norm tn"),
    ("norm_cn_a", "norm-cn-a-layer", "norm cn_a"),
    ("norm_cn_m", "norm-cn-m-layer", "norm cn_m"),
    ("norm_ceps", "norm-ceps-layer", "norm ceps"),
    ("sh_ao", "sh-ao-layer", "ao shift"),
    ("sh_qkv", "sh-qkv-layer", "qkv shift"),
    ("sh_o", "sh-o-layer", "o shift"),
    ("sh_g", "sh-gate-layer", "gate shift"),
    ("sh_h", "sh-product-layer", "product shift"),
    ("sh_z", "sh-down-layer", "down shift"),
];

/// field `i` of [`OWN_FIELDS`] in a calibration
pub(crate) fn cal_field(c: &NormCalibration, i: usize) -> i64 {
    match i {
        0 => i64::from(c.sh_s),
        1 => i64::from(c.tn),
        2 => c.cn_a,
        3 => c.cn_m,
        4 => c.ceps,
        5 => i64::from(c.sh_ao),
        6 => i64::from(c.sh_qkv),
        7 => i64::from(c.sh_o),
        8 => i64::from(c.sh_g),
        9 => i64::from(c.sh_h),
        _ => i64::from(c.sh_z),
    }
}

/// the run's calibration with a layer's own values applied (a `u32` field
/// out of range is refused, never wrapped)
pub(crate) fn apply_own(base: &NormCalibration, own: &[Option<i64>; 11]) -> Result<NormCalibration, String> {
    let mut c = *base;
    for (i, v) in own.iter().enumerate() {
        let Some(v) = *v else { continue };
        let u = || u32::try_from(v).map_err(|_| format!("trained calibration: a per-layer {} {v} is out of range", OWN_FIELDS[i].0));
        match i {
            0 => c.sh_s = u()?,
            1 => c.tn = u()?,
            2 => c.cn_a = v,
            3 => c.cn_m = v,
            4 => c.ceps = v,
            5 => c.sh_ao = u()?,
            6 => c.sh_qkv = u()?,
            7 => c.sh_o = u()?,
            8 => c.sh_g = u()?,
            9 => c.sh_h = u()?,
            _ => c.sh_z = u()?,
        }
    }
    Ok(c)
}

/// a layer's own values against the run's: `Some` exactly where they differ
pub(crate) fn own_of(base: &NormCalibration, layer: &NormCalibration) -> [Option<i64>; 11] {
    let mut own = [None; 11];
    for (i, o) in own.iter_mut().enumerate() {
        let v = cal_field(layer, i);
        if v != cal_field(base, i) {
            *o = Some(v);
        }
    }
    own
}

/// whether a layer record carries any own constant
pub(crate) fn has_own(own: &[Option<i64>; 11]) -> bool {
    own.iter().any(|v| v.is_some())
}

fn sha(bytes: &[u8]) -> [u8; 32] {
    Sha256::digest(bytes).into()
}

fn i8_bytes(v: &[i8]) -> Vec<u8> {
    v.iter().map(|x| *x as u8).collect()
}

/// [A20] exactly `i8_bytes(v)`'s bytes, without the copy
fn i8_as_bytes(v: &[i8]) -> &[u8] {
    // SAFETY: `i8` and `u8` have the same size and alignment and every bit pattern is a
    // valid `u8`; the slice borrows `v` for its own lifetime. `x as u8` of an `i8` is the
    // same bits (two's complement), so these are the bytes `i8_bytes(v)` copies out.
    unsafe { std::slice::from_raw_parts(v.as_ptr().cast::<u8>(), v.len()) }
}

fn i64_bytes(vs: &[&[i64]]) -> Vec<u8> {
    vs.iter().flat_map(|v| v.iter().flat_map(|x| x.to_le_bytes())).collect()
}

// ---------------------------------------- [A20] the layer record's hashing
//
// (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A20;
// `results/zk60_effplan_20261105/a20/README.md`.) Production's sealing pass loads
// each layer beside the previous layer's witness build, and every load makes the
// layer's record ([`LayerRecord::of_block`]): nine SHA-256s of the padded words,
// three of the tables and the block digest. Two forms, each restored by its switch
// at `0`:
// * `HL_A20_CAST`: each padded word is hashed IN PLACE, as the bytes it already is,
//   instead of as a fresh `i8_bytes` copy (about 218 MB of copies per 8B layer);
// * `HL_A20_RECPAR`: the block digest (`BlockPublic::digest`, one BLAKE3 pass on one
//   thread) runs BESIDE the SHA-256s instead of after them.
// **Why no byte can move.** `x as u8` of an `i8` is its two's-complement bits, so the
// borrowed slice is the copy's bytes and SHA-256 of it is the same digest. Every
// field of the record is a pure function of the block, so the order (or the threads)
// in which they are computed changes no value. Nothing a check reads is skipped.

/// [A20] a switch, read once from the environment variable `name` (unset, empty or
/// not a number: `default`), with a test override (`usize::MAX`: the environment's)
pub(crate) fn a20_switch(test: &std::sync::atomic::AtomicUsize, env: &std::sync::OnceLock<usize>, name: &str, default: usize) -> usize {
    match test.load(std::sync::atomic::Ordering::Relaxed) {
        usize::MAX => *env.get_or_init(|| std::env::var(name).ok().and_then(|v| v.trim().parse::<usize>().ok()).unwrap_or(default)),
        t => t,
    }
}

static A20_CAST_TEST: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(usize::MAX);
static A20_RECPAR_TEST: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(usize::MAX);

/// [A20] `HL_A20_CAST` (default on; `0`: each word's `i8_bytes` copy is hashed, the
/// path before A20)
pub(crate) fn a20_cast() -> bool {
    static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    a20_switch(&A20_CAST_TEST, &ENV, "HL_A20_CAST", 1) != 0
}

/// [A20] `HL_A20_RECPAR` (default on; `0`: the block digest after the SHA-256s, the
/// path before A20)
pub(crate) fn a20_recpar() -> bool {
    static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    a20_switch(&A20_RECPAR_TEST, &ENV, "HL_A20_RECPAR", 1) != 0
}

/// tests: the two record forms on (`Some(true)`), off (`Some(false)`) or as the
/// environment says (`None`). Changes no byte (see above).
#[cfg(test)]
pub(crate) fn set_a20_record_for_test(cast: Option<bool>, recpar: Option<bool>) {
    let v = |b: Option<bool>| b.map(usize::from).unwrap_or(usize::MAX);
    A20_CAST_TEST.store(v(cast), std::sync::atomic::Ordering::Relaxed);
    A20_RECPAR_TEST.store(v(recpar), std::sync::atomic::Ordering::Relaxed);
}

// ---------------------------------------- [A20] end

impl LayerRecord {
    /// Reconstruct the trusted layer's entire stage context, including the
    /// R13 denominator that is not a base calibration shift.
    pub(crate) fn shape_at(&self,base:&Shape)->Result<Shape,String> {
        self.check_accuracy_gate(base)?;
        let shape=if has_own(&self.own) {base.with_layer_calibration(&apply_own(&base.norm_calibration(),&self.own)?)?} else {base.clone()};
        match self.accuracy_gate_shift {Some(g)=>shape.with_accuracy_gate_shift(g),None=>Ok(shape)}
    }

    pub(crate) fn check_accuracy_gate(&self,sh:&Shape)->Result<(),String> {
        match (sh.accuracy_stack(),self.accuracy_gate_shift) {
            (super::accuracy_precision::Stack::Legacy,None)=>Ok(()),
            (super::accuracy_precision::Stack::Legacy,Some(_))=>Err("trained statement: legacy layer carries an R13 gate denominator".into()),
            (_,None)=>Err("trained statement: R13 layer is missing its common gate denominator".into()),
            (_,Some(g))=>sh.clone().with_accuracy_gate_shift(g).map(|_|()),
        }
    }

    /// The record of one block's PUBLIC statement, computed from the words
    /// the prover and the verifier actually use.
    /// ROUND 5 (R5-2): the record of a proving-pass RELOAD, which keeps only
    /// the block (its digest is compared with the digest pass's record)
    pub(crate) fn unhashed(index: u32) -> LayerRecord {
        LayerRecord { index, block_digest: [0; 32], word_sha256: [[0; 32]; 9], table_sha256: [[0; 32]; 3], source_tensors: vec![], manifest_sha256: [0; 32], silu_member: (0, 0), exp_e_s: 0, own: [None; 11], accuracy_gate_shift:None }
    }

    pub(crate) fn of_block(index: u32, blk: &BlockPublic, source_tensors: Vec<(String, [u8; 32])>) -> LayerRecord {
        let (a, f) = (blk.attention(), blk.feed_forward());
        // ROUND 5 (R5-2): the nine padded-word SHA-256s IN PARALLEL (the
        // same bytes, the same digests, in the same order)
        let words: [&Vec<i8>; 9] = [&a.wq, &a.wk, &a.wv, &a.wo, &a.gamma_a, &f.gamma_m, &f.wg_t, &f.wu_t, &f.wd_t];
        // [A20] HL_A20_CAST: each word hashed in place (the bytes of its `i8_bytes` copy)
        let cast = a20_cast();
        let hash_words = || -> [[u8; 32]; 9] {
            let hashed: Vec<[u8; 32]> = {
                use rayon::prelude::*;
                words.par_iter().map(|w| if cast { sha(i8_as_bytes(w)) } else { sha(&i8_bytes(w)) }).collect()
            };
            hashed.try_into().expect("nine digests")
        };
        let hash_tables = || -> [[u8; 32]; 3] {
            let act:Vec<u8>=match blk.accuracy() {
                Some(data)=>data.raw_tables().iter().flatten().flat_map(|v|v.to_le_bytes()).collect(),
                None=>f.act.iter().flat_map(|v|v.to_le_bytes()).collect(),
            };
            [sha(&i64_bytes(&[&a.rope_cos, &a.rope_sin])), sha(&i64_bytes(&[&a.exp])), sha(&act)]
        };
        // [A20] HL_A20_RECPAR: the block digest beside the SHA-256s (each field a pure
        // function of the block; off, the order before A20: words, tables, digest)
        let ((word_sha256, table_sha256), block_digest) = if a20_recpar() {
            rayon::join(|| (hash_words(), hash_tables()), || blk.digest())
        } else {
            let w = hash_words();
            let t = hash_tables();
            ((w, t), blk.digest())
        };
        let mut source_tensors = source_tensors;
        source_tensors.sort();
        // a recipe block's tables are the frozen SiLU member (-3, -11) and
        // `exp_member(0, ..)` (`dense_tests::statement_of_words`); the export
        // loader overwrites both with the manifest's members
        LayerRecord { index, block_digest, word_sha256, table_sha256, source_tensors, manifest_sha256: [0; 32],
            silu_member:blk.accuracy().map(|a|a.member()).unwrap_or((-3,-11)),exp_e_s:0,own:[None;11],
            accuracy_gate_shift:blk.accuracy().map(|a|a.folds().gate.shift) }
    }
}

/// **NATIVE R12 (F3, D38): a TIED embedding / output head.** The model's
/// embedding table and its output head are ONE published tensor
/// (`tie_word_embeddings`); the run's integer embedding table and integer head
/// may be different quantisations of it (the embedding int16 rows, the head
/// int8 rows with per-row multipliers), and BOTH are bound here to that one
/// tensor's digest. R12b's export loader recomputes their bytes from the
/// authenticated checkpoint before constructing this record. The token
/// stages require their own relations and checks; a declaration alone does
/// not establish a tie. Present
/// exactly at a profile whose model is tied (Shieldstral), absent everywhere
/// else, so no statement before R12 moves.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct TiedEmbedding {
    /// the tensor's name in the pinned weights file
    pub tensor: String,
    /// SHA-256 of the tensor's raw bytes in the pinned weights file
    pub tensor_sha256: [u8; 32],
    /// SHA-256 of the integer embedding table the token stage reads
    pub embedding_table_sha256: [u8; 32],
    /// SHA-256 of the integer head rows and of their per-row multipliers
    pub head_table_sha256: [u8; 32],
    pub head_mult_sha256: [u8; 32],
}

/// **NATIVE R12 (F3): the pinned tied tensor of a profile** — its name and
/// the SHA-256 of its raw bytes in the pinned weights file, a model fact
/// (Shieldstral: `language_model.model.embed_tokens.weight`, BF16 [131072,
/// 3072], bytes [61008, 805367376) of `model.safetensors` at the pinned
/// revision, digested on 2026-10-21 by streaming exactly that range); `None`
/// for an untied model.
pub(crate) fn tied_tensor_for_profile(profile: &str) -> Option<(&'static str, [u8; 32])> {
    let profile=super::shape::accuracy_spec(profile).map(|spec|spec.legacy).unwrap_or(profile);
    if super::shape::SHIELDSTRAL_PROFILES.contains(&profile) {
        Some((SHIELDSTRAL_TIED_TENSOR, hex32(SHIELDSTRAL_TIED_TENSOR_SHA256)))
    } else {
        None
    }
}
pub(crate) const SHIELDSTRAL_TIED_TENSOR: &str = "language_model.model.embed_tokens.weight";
pub(crate) const SHIELDSTRAL_TIED_TENSOR_SHA256: &str = "67a138c1c483b89874526ef523f5f0c30f161808076561730193d1de2093dd19";

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
    /// NATIVE R12 (F3): the tied embedding / head record (tied models only)
    pub tied: Option<TiedEmbedding>,
    /// re-review R2-b: set ONLY by the test-only constructor
    /// [`TrainedModelStatement::new_synthetic_at_trained_profile_for_tests`];
    /// every other statement, in test builds too, is checked by the strict
    /// production rule. Not part of the encoding (not a statement field).
    #[cfg(test)]
    pub test_synthetic_waiver: bool,
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
        Self::new_with_tied(sh, run_profile, source, calibration, layers, None)
    }

    /// NATIVE R12 (F3): the same with the tied embedding / head record a
    /// tied model's profile requires (and an untied one refuses)
    pub(crate) fn new_with_tied(sh: &Shape, run_profile: &str, source: ModelSource, calibration: IntegerCalibration, layers: Vec<LayerRecord>, tied: Option<TiedEmbedding>) -> Result<TrainedModelStatement, String> {
        let st = TrainedModelStatement {
            block_profile: sh.profile.into(),
            run_profile: run_profile.into(),
            geometry: geometry_of(sh),
            source,
            calibration,
            layers,
            coverage: COVERAGE_D13.into(),
            tied,
            #[cfg(test)]
            test_synthetic_waiver: false,
        };
        st.check_self(sh)?;
        Ok(st)
    }

    /// **TEST ONLY (round 2, R2-4).** Single-block proofs at a trained
    /// profile are refused, so synthetic-weight tests at the TinyLlama trained
    /// geometry prove as one-block runs bound to a statement that says
    /// honestly that its words are a PUBLIC SYNTHETIC RECIPE. Production
    /// refuses a synthetic recipe at a trained (non-development) profile; this
    /// constructor waives exactly that one rule, in test builds only.
    #[cfg(test)]
    pub(crate) fn new_synthetic_at_trained_profile_for_tests(sh: &Shape, run_profile: &str, source: ModelSource, calibration: IntegerCalibration, layers: Vec<LayerRecord>) -> Result<TrainedModelStatement, String> {
        // NATIVE R12 (F3): a tied profile's synthetic statement carries a
        // synthetic tied record under the pinned tensor NAME
        let tied = tied_tensor_for_profile(sh.profile).map(|(name, _)| TiedEmbedding { tensor: name.into(), tensor_sha256: [7; 32], embedding_table_sha256: [8; 32], head_table_sha256: [9; 32], head_mult_sha256: [10; 32] });
        Self::new_synthetic_at_trained_profile_for_tests_tied(sh, run_profile, source, calibration, layers, tied)
    }

    /// **TEST ONLY (R12):** the same with a chosen tied record (or none)
    #[cfg(test)]
    pub(crate) fn new_synthetic_at_trained_profile_for_tests_tied(sh: &Shape, run_profile: &str, source: ModelSource, calibration: IntegerCalibration, layers: Vec<LayerRecord>, tied: Option<TiedEmbedding>) -> Result<TrainedModelStatement, String> {
        if source.kind != SourceKind::PublicSyntheticRecipe {
            return Err("trained statement: the test-only constructor takes a synthetic recipe only".into());
        }
        let st = TrainedModelStatement {
            block_profile: sh.profile.into(),
            run_profile: run_profile.into(),
            geometry: geometry_of(sh),
            source,
            calibration,
            layers,
            coverage: COVERAGE_D13.into(),
            tied,
            test_synthetic_waiver: true,
        };
        st.check_self_with(sh, true)?;
        Ok(st)
    }

    /// re-review R2-b: true only for a statement from the test-only
    /// constructor, and never in a production build
    fn waived_for_tests(&self) -> bool {
        #[cfg(test)]
        {
            self.test_synthetic_waiver
        }
        #[cfg(not(test))]
        {
            false
        }
    }

    fn check_self(&self, sh: &Shape) -> Result<(), String> {
        self.check_self_with(sh, false)
    }

    fn check_self_with(&self, sh: &Shape, synthetic_at_trained_ok: bool) -> Result<(), String> {
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
        // review finding F-3: keyed on the profile's IDENTITY (it was a
        // substring test): the trained TinyLlama profile is the pinned
        // checkpoint's, and nothing else's
        // ROUND 4: every trained-model profile (TinyLlama at T32/T64/T128,
        // Llama-3-8B at T32) carries ITS pinned checkpoint and nothing else
        let pinned = ModelSource::pinned_for_profile(&self.block_profile);
        let tiny = pinned.is_some();
        if let Some(pin) = &pinned {
            if !synthetic_at_trained_ok && self.source != *pin {
                return Err(format!("trained statement: the profile {} is the pinned {} checkpoint's; this statement names another source", self.block_profile, pin.repo));
            }
        }
        if tiny && self.source.kind == SourceKind::PublicSyntheticRecipe && !synthetic_at_trained_ok {
            return Err("trained statement: a synthetic recipe may not carry a trained (non-development) profile".into());
        }
        // ROUND 2 / the review's general rule: the per-block table keys are
        // inside their declared classes (the tables themselves are bound by
        // value through each block digest, and the loader checks them against
        // these generator members)
        for r in &self.layers {
            r.check_accuracy_gate(sh)?;
            // NATIVE R8 (R6 for sh_s): a layer's own constants are canonical
            // (never equal to the run's, which would be a second encoding of
            // one statement) and its whole calibration passes the trained
            // door at the run's shape (every class, the four-limb norm window,
            // the plane list unmoved)
            if has_own(&r.own) {
                let base = sh.norm_calibration();
                for (i, v) in r.own.iter().enumerate() {
                    if let Some(v) = v {
                        if *v == cal_field(&base, i) {
                            return Err(format!("trained statement: layer {}'s own {} {v} equals the run's; a run-wide value is recorded once, in the calibration", r.index, OWN_FIELDS[i].0));
                        }
                    }
                }
                let cal = apply_own(&base, &r.own).map_err(|e| format!("trained statement: layer {}: {e}", r.index))?;
                sh.with_layer_calibration(&cal).map_err(|e| format!("trained statement: layer {}'s own calibration: {e}", r.index))?;
            }
            if !super::shape::TRAINED_EXP_E_S_RANGE.contains(&r.exp_e_s) {
                return Err(format!("trained statement: layer {}'s exp e_s {} is outside its declared class {:?}", r.index, r.exp_e_s, super::shape::TRAINED_EXP_E_S_RANGE));
            }
            let member_ok=if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {
                crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu,r.silu_member.0,r.silu_member.1).is_some()
            } else {sh.accuracy_registry().permits(r.silu_member)};
            if !member_ok {
                return Err(format!("trained statement: layer {}'s SiLU member {:?} is not in the frozen registry", r.index, r.silu_member));
            }
        }
        if self.coverage != COVERAGE_D13 {
            return Err("trained statement: the coverage sentence is not the D13 one".into());
        }
        // NATIVE R12 (F3): a tied model's record, by name; none elsewhere
        match (tied_tensor_for_profile(&self.block_profile), &self.tied) {
            (None, None) => {}
            (None, Some(_)) => return Err(format!("trained statement: {} is an untied model's profile; a tied embedding record is refused", self.block_profile)),
            (Some((name, _)), None) => return Err(format!("trained statement: {}'s model ties its embedding and head ({name}); the statement must bind both integer tables to that tensor", self.block_profile)),
            (Some((name, digest)), Some(t)) => {
                if t.tensor != name {
                    return Err(format!("trained statement: the tied record names tensor {:?}, not the profile's {name:?}", t.tensor));
                }
                if [t.tensor_sha256, t.embedding_table_sha256, t.head_table_sha256, t.head_mult_sha256].contains(&[0u8; 32]) {
                    return Err("trained statement: a tied record carries a zero digest".into());
                }
                // the pinned checkpoint's tensor is the ONE published digest
                // both tables must name (a synthetic test recipe has no pin)
                if self.source.kind == SourceKind::HfCheckpoint && t.tensor_sha256 != digest {
                    return Err(format!("trained statement: the tied tensor's SHA-256 is not the pinned checkpoint's {name}"));
                }
            }
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
        // NATIVE R12 (F3): present ONLY for a tied model
        if let Some(t) = &self.tied {
            e.field("tied-embedding-tensor", t.tensor.as_bytes());
            e.field("tied-embedding-tensor-sha256", &t.tensor_sha256);
            e.field("tied-embedding-table-sha256", &t.embedding_table_sha256);
            e.field("tied-head-table-sha256", &t.head_table_sha256);
            e.field("tied-head-mult-sha256", &t.head_mult_sha256);
        }
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
        e.u64("rope-theta-f64-bits", c.rope_theta_f64_bits);
        // NATIVE R12 (F1): present ONLY for a scaled RoPE
        if c.rope_scaling != super::rope::RopeScaling::None.encode() {
            e.field("rope-scaling", &c.rope_scaling);
        }
        e.u64("layer-records", self.layers.len() as u64);
        for r in &self.layers {
            e.u64("layer-index", u64::from(r.index));
            e.field("block-digest", &r.block_digest);
            e.field("export-manifest-sha256", &r.manifest_sha256);
            e.i64("silu-member-e-in", i64::from(r.silu_member.0));
            e.i64("silu-member-e-out", i64::from(r.silu_member.1));
            e.i64("exp-e-s", i64::from(r.exp_e_s));
            // NATIVE R8 (R6 for sh_s): present ONLY for a layer's own
            // constants, in the canonical order, so a run-wide statement's
            // bytes are what they were and an sh_s-only one is R6's
            for (i, v) in r.own.iter().enumerate() {
                if let Some(v) = v {
                    e.u64(OWN_FIELDS[i].1, u64::try_from(*v).unwrap_or(u64::MAX));
                }
            }
            if let Some(g)=r.accuracy_gate_shift {e.u64("accuracy-gate-layer",u64::from(g));}
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
        // re-review R2-b: the waiver reaches the run constructor ONLY for a
        // statement built by the test-only constructor (a field that exists
        // in test builds only); every other statement, in `cargo test` too,
        // is checked exactly as production checks it
        self.check_self_with(sh, self.waived_for_tests())?;
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

#[cfg(test)]
pub(super) fn accuracy_hash_model(sh:&Shape,l:usize)->TrainedModelStatement {
    accuracy_metadata_tests::hash_census_model(sh,l)
}

#[cfg(test)]
mod accuracy_metadata_tests {
    use super::*;

    fn provenance(sh:&Shape)->Provenance {
        let mut p=Provenance::recipe("R13 metadata fixture",1.0,[3;32],[4;32]);
        p.rope_theta=super::super::shape::trained_rope_theta(sh.profile).unwrap();
        p.rope_scaling=super::super::shape::trained_rope_scaling(sh.profile).unwrap();p
    }

    #[test]
    fn accuracy_calibration_describes_fp12_three_byte_norm_remainders_and_up_shift12() {
        for sh in super::super::accuracy_profile_tests::registered_shapes() {
            let p=provenance(&sh);let c=IntegerCalibration::as_the_code_proves(&sh,&p);
            assert_eq!((c.f_p,c.norm_wrho,c.sh_u),(12,24,12));
            assert_eq!(c.norm_tn,sh.norm_tn,"base calibration remains the source of effective precision");
            c.check_honoured_by_code(&sh).unwrap();
            for field in 0..3 {
                let mut forged=c.clone();match field {0=>forged.f_p=9,1=>forged.norm_wrho=32,_=>forged.sh_u=0};
                assert!(forged.check_honoured_by_code(&sh).is_err());
            }
        }
        let sh=Shape::toy();let c=IntegerCalibration::as_the_code_proves(&sh,&Provenance::recipe("legacy",1.0,[3;32],[4;32]));
        assert_eq!((c.f_p,c.norm_wrho,c.sh_u),(9,sh.norm_wrho,0));
    }

    #[test]
    fn accuracy_layer_records_require_exactly_one_class_checked_gate_scalar() {
        let mut r=LayerRecord::unhashed(0);
        r.check_accuracy_gate(&Shape::toy()).unwrap();r.accuracy_gate_shift=Some(17);
        assert!(r.check_accuracy_gate(&Shape::toy()).is_err());
        for sh in super::super::accuracy_profile_tests::registered_shapes() {
            r.accuracy_gate_shift=None;assert!(r.check_accuracy_gate(&sh).is_err());
            for g in 17..=24 {r.accuracy_gate_shift=Some(g);r.check_accuracy_gate(&sh).unwrap();}
            for g in [0,16,25,u32::MAX] {r.accuracy_gate_shift=Some(g);assert!(r.check_accuracy_gate(&sh).is_err());}
        }
    }

    fn model(sh:&Shape,gates:&[u32])->TrainedModelStatement {
        let source=ModelSource{kind:SourceKind::PublicSyntheticRecipe,repo:"synthetic/r13-metadata".into(),revision:"r13-test".into(),
            weights_sha256:[0;32],config_sha256:[0;32],checkpoint_parameters:0,checkpoint_layers:gates.len() as u32};
        let layers=gates.iter().enumerate().map(|(k,&g)| {
            let mut r=LayerRecord::unhashed(k as u32);r.accuracy_gate_shift=Some(g);r.block_digest=[k as u8+1;32];
            r.silu_member=(-3,-11);r
        }).collect();
        TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(sh,super::super::run::accuracy_run_profile(sh.profile).unwrap(),
            source,IntegerCalibration::as_the_code_proves(sh,&provenance(sh)),layers).unwrap()
    }

    pub(super) fn hash_census_model(sh:&Shape,l:usize)->TrainedModelStatement {model(sh,&vec![sh.accuracy_gate_shift;l])}

    #[test]
    fn accuracy_same_calibration_layers_reconstruct_distinct_bound_stage_denominators() {
        use super::super::{run,IoSpec,ExpectedIo,layout::Layout};
        for sh in super::super::accuracy_profile_tests::registered_shapes().into_iter().filter(|s|s.tokens==32) {
            let m=model(&sh,&[17,24]);let rs=run::RunShape::accuracy(sh.clone(),2).unwrap();let context=[7;32];
            let spec=IoSpec::new_shaped(&sh,context,0,0).unwrap();let expected=ExpectedIo::from_roots(spec,[1;32],[2;32]);
            let digests=m.layers.iter().map(|r|r.block_digest).collect::<Vec<_>>();
            let st=run::RunStatement::new_bound_from_digests(rs,context,expected,digests,&[super::super::ENDPOINT_SCALES;2],&m).unwrap();
            let(a,b)=(st.stage_shape(0).unwrap(),st.stage_shape(1).unwrap());
            assert_eq!(a.norm_calibration(),b.norm_calibration());
            assert_eq!((a.accuracy_gate_shift,b.accuracy_gate_shift),(17,24));
            assert_ne!(Layout::for_shape(&a).unwrap().schedule_digest(),Layout::for_shape(&b).unwrap().schedule_digest());
            let mut changed=m.clone();changed.layers[1].accuracy_gate_shift=Some(23);
            changed.check_self_with(&sh,true).unwrap();assert_ne!(changed.identity(),m.identity());
            assert_eq!(String::from_utf8_lossy(&m.encode()).matches("accuracy-gate-layer").count(),2);
            changed.layers[1].accuracy_gate_shift=None;assert!(changed.check_self_with(&sh,true).is_err());
        }
    }

    #[test]
    fn accuracy_profiles_keep_their_legacy_model_and_tied_tensor_pins() {
        for spec in &super::super::shape::ACCURACY_PROFILES {
            assert_eq!(ModelSource::pinned_for_profile(spec.profile),ModelSource::pinned_for_profile(spec.legacy));
            assert_eq!(tied_tensor_for_profile(spec.profile),tied_tensor_for_profile(spec.legacy));
        }
    }
}

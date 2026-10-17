//! **NATIVE LANE (2026-10-17): THE TRAINED-BLOCK LOADER AND ITS CLI BRIDGE.**
//! Production code; the CLI is `examples/zk60_trained_block.rs`.
//!
//! **What it reads.** A calibration export written by the calibration lane
//! (`results/zk60_1b_calibration_20260929/export/<variant>/`, schema
//! `zk60-trained-profile-export/1`; this module OWNS THE READER ONLY):
//!
//! * `profile.json` — the model pin `{repo, revision, sha256}`, the
//!   calibration tool `{path, sha256}`, `T`, the profile constants (`norm_tn`,
//!   `norm_cn_a`, `norm_cn_m`, `norm_ceps`, the shifts, `f_e`, `f_p`, `f_ro`,
//!   `sh_r2`, `silu_member`, `exp_e_s`, `rope_theta`) and the layer list;
//! * `layer_NN/manifest.json` — the layer index, its constants (equal to the
//!   profile's: per-layer constants are refused, the per-layer variation is
//!   folded into each block's words), and `arrays {name: {file, dtype, shape,
//!   sha256}}`;
//! * `layer_NN/<name>.bin` — raw little-endian, UNPADDED, native orientations;
//! * `seq_<id>/x_in_LNN.bin`, `x_out_LNN.bin` — int16 `[T, d]`, the Python
//!   integer reference's hidden input and output of layer `NN` (PRIVATE: read
//!   by the prover only; never printed, hashed into a record or copied).
//!
//! **What it checks** (every refusal names its file and field): the schema;
//! the model pin equals the pinned TinyLlama source; every constant the
//! relations hold fixed equals the code's; the trained constants pass the
//! shape validator; every array's SHA-256, dtype, shape and byte length; the
//! exp and act tables equal the generator members the profile names; the
//! RoPE tables equal the native generator at `rope_theta` (or, if the caller
//! opts in, the exported ones are used and the mismatch is recorded); file
//! names are plain names inside their directory; sizes are bounded.
//!
//! **What it builds.** The padded `BlockPublic` (ruling P-2), the trained
//! `Shape`, and the trained-model statement (`trained_statement.rs`, schema
//! v2) with `profile.json`'s SHA-256, the calibration tool's SHA-256 and each
//! layer manifest's SHA-256 bound into its identity — which a bound run
//! absorbs as its `"calibration"` word.
//!
//! **Scope, said in every result.** One TRAINED block (one of 22) of
//! TinyLlama-1.1B-Chat at T = 32 on the CPU, a correctness result for the
//! integer model the export names. NOT a model pass, NOT a privacy acceptance
//! (D22 covers only the toy), and the float fidelity of the integer model is
//! the calibration lane's measurement, not this proof's.

use super::layout::{Ids, A_X, A_X2, F_RO};
use super::run::{self, RunShape, RunStatement, RunWitnessSource, RUN_PROFILE_RUNG_TC, RUN_PROFILE_TINYLLAMA_T32_TRAINED};
use super::shape::{NormCalibration, Shape};
use super::trained_statement::{IntegerCalibration, LayerRecord, ModelSource, Provenance, SourceKind, TrainedModelStatement};
use super::witness::{self, Witness};
use super::{prepare_endpoints, AttentionPublic, BlockPublic, ExpectedIo, FeedForwardPublic, IoSpec};
use crate::merkle::Digest;
use sha2::{Digest as _, Sha256};
use std::path::{Path, PathBuf};
use std::time::Instant;

pub(crate) const PROFILE_SCHEMA: &str = "zk60-trained-profile-export/1";
const MAX_JSON_BYTES: u64 = 4 * 1024 * 1024;
const MAX_ARRAY_BYTES: u64 = 256 * 1024 * 1024;
const SCOPE: &str = "ONE trained TinyLlama-1.1B-Chat block (of 22) at T=32, CPU; the integer model the calibration export names; NOT a model pass; NO privacy acceptance at this shape (D22 covers only the toy); float fidelity is the calibration lane's measurement";
const SCOPE_RUNG: &str = "SYNTHETIC development export at the trained-calibration rung (rung-TC, width 384): NOT a trained model, NOT TinyLlama; a test of the export reader and the driver only; no privacy acceptance";

// ------------------------------------------------------------------ JSON

/// A strict, bounded JSON value. Numbers keep their text; duplicate keys,
/// trailing bytes, depth above 32 and non-ASCII control bytes are refused.
#[derive(Clone, Debug, PartialEq)]
pub(crate) enum J {
    Null,
    Bool(bool),
    Num(String),
    Str(String),
    Arr(Vec<J>),
    Obj(Vec<(String, J)>),
}

impl J {
    pub(crate) fn opt(&self, k: &str) -> Option<&J> {
        match self {
            J::Obj(kv) => kv.iter().find(|(key, _)| key == k).map(|(_, v)| v),
            _ => None,
        }
    }
    pub(crate) fn get(&self, k: &str) -> Result<&J, String> {
        self.opt(k).ok_or_else(|| format!("missing key `{k}`"))
    }
    /// the first of several accepted names (the writer is another lane's)
    pub(crate) fn get_any(&self, ks: &[&str]) -> Result<&J, String> {
        ks.iter().find_map(|k| self.opt(k)).ok_or_else(|| format!("missing key (one of {ks:?})"))
    }
    pub(crate) fn str(&self) -> Result<&str, String> {
        match self {
            J::Str(s) => Ok(s),
            _ => Err("expected a string".into()),
        }
    }
    pub(crate) fn i64(&self) -> Result<i64, String> {
        match self {
            J::Num(s) => s.parse::<i64>().map_err(|_| format!("expected an integer, got `{s}`")),
            _ => Err("expected an integer".into()),
        }
    }
    pub(crate) fn f64(&self) -> Result<f64, String> {
        match self {
            J::Num(s) => s.parse::<f64>().map_err(|_| format!("expected a number, got `{s}`")),
            _ => Err("expected a number".into()),
        }
    }
    pub(crate) fn arr(&self) -> Result<&[J], String> {
        match self {
            J::Arr(v) => Ok(v),
            _ => Err("expected an array".into()),
        }
    }
    pub(crate) fn obj(&self) -> Result<&[(String, J)], String> {
        match self {
            J::Obj(v) => Ok(v),
            _ => Err("expected an object".into()),
        }
    }
}

struct Parser<'a> {
    b: &'a [u8],
    i: usize,
}

impl Parser<'_> {
    fn ws(&mut self) {
        while self.i < self.b.len() && matches!(self.b[self.i], b' ' | b'\t' | b'\n' | b'\r') {
            self.i += 1;
        }
    }
    fn err<T>(&self, m: &str) -> Result<T, String> {
        Err(format!("JSON: {m} at byte {}", self.i))
    }
    fn value(&mut self, depth: usize) -> Result<J, String> {
        if depth > 32 {
            return self.err("nesting too deep");
        }
        self.ws();
        match self.b.get(self.i) {
            Some(b'{') => {
                self.i += 1;
                let mut kv: Vec<(String, J)> = Vec::new();
                self.ws();
                if self.b.get(self.i) == Some(&b'}') {
                    self.i += 1;
                    return Ok(J::Obj(kv));
                }
                loop {
                    self.ws();
                    let k = self.string()?;
                    if kv.iter().any(|(x, _)| *x == k) {
                        return self.err(&format!("duplicate key `{k}`"));
                    }
                    self.ws();
                    if self.b.get(self.i) != Some(&b':') {
                        return self.err("expected `:`");
                    }
                    self.i += 1;
                    let v = self.value(depth + 1)?;
                    kv.push((k, v));
                    self.ws();
                    match self.b.get(self.i) {
                        Some(b',') => self.i += 1,
                        Some(b'}') => {
                            self.i += 1;
                            return Ok(J::Obj(kv));
                        }
                        _ => return self.err("expected `,` or `}`"),
                    }
                }
            }
            Some(b'[') => {
                self.i += 1;
                let mut v = Vec::new();
                self.ws();
                if self.b.get(self.i) == Some(&b']') {
                    self.i += 1;
                    return Ok(J::Arr(v));
                }
                loop {
                    v.push(self.value(depth + 1)?);
                    self.ws();
                    match self.b.get(self.i) {
                        Some(b',') => self.i += 1,
                        Some(b']') => {
                            self.i += 1;
                            return Ok(J::Arr(v));
                        }
                        _ => return self.err("expected `,` or `]`"),
                    }
                }
            }
            Some(b'"') => Ok(J::Str(self.string()?)),
            Some(b't') if self.b[self.i..].starts_with(b"true") => {
                self.i += 4;
                Ok(J::Bool(true))
            }
            Some(b'f') if self.b[self.i..].starts_with(b"false") => {
                self.i += 5;
                Ok(J::Bool(false))
            }
            Some(b'n') if self.b[self.i..].starts_with(b"null") => {
                self.i += 4;
                Ok(J::Null)
            }
            Some(c) if *c == b'-' || c.is_ascii_digit() => {
                let s = self.i;
                while self.i < self.b.len() && matches!(self.b[self.i], b'-' | b'+' | b'.' | b'e' | b'E' | b'0'..=b'9') {
                    self.i += 1;
                }
                Ok(J::Num(String::from_utf8_lossy(&self.b[s..self.i]).into_owned()))
            }
            _ => self.err("unexpected byte"),
        }
    }
    fn string(&mut self) -> Result<String, String> {
        if self.b.get(self.i) != Some(&b'"') {
            return self.err("expected a string");
        }
        self.i += 1;
        let mut out = String::new();
        loop {
            match self.b.get(self.i) {
                None => return self.err("unterminated string"),
                Some(b'"') => {
                    self.i += 1;
                    return Ok(out);
                }
                Some(b'\\') => {
                    let e = *self.b.get(self.i + 1).ok_or("JSON: dangling escape")?;
                    self.i += 2;
                    match e {
                        b'"' => out.push('"'),
                        b'\\' => out.push('\\'),
                        b'/' => out.push('/'),
                        b'n' => out.push('\n'),
                        b't' => out.push('\t'),
                        b'r' => out.push('\r'),
                        b'b' => out.push('\u{8}'),
                        b'f' => out.push('\u{c}'),
                        b'u' => {
                            let h = self.b.get(self.i..self.i + 4).ok_or("JSON: short \\u escape")?;
                            let c = u32::from_str_radix(std::str::from_utf8(h).map_err(|_| "JSON: bad \\u escape")?, 16).map_err(|_| "JSON: bad \\u escape")?;
                            out.push(char::from_u32(c).ok_or("JSON: \\u escape is not a scalar value")?);
                            self.i += 4;
                        }
                        _ => return self.err("unknown escape"),
                    }
                }
                Some(c) if *c < 0x20 => return self.err("control byte in a string"),
                Some(_) => {
                    let s = self.i;
                    while self.i < self.b.len() && self.b[self.i] != b'"' && self.b[self.i] != b'\\' && self.b[self.i] >= 0x20 {
                        self.i += 1;
                    }
                    out.push_str(std::str::from_utf8(&self.b[s..self.i]).map_err(|_| "JSON: a string is not UTF-8")?);
                }
            }
        }
    }
}

pub(crate) fn parse_json(bytes: &[u8]) -> Result<J, String> {
    let mut p = Parser { b: bytes, i: 0 };
    let v = p.value(0)?;
    p.ws();
    if p.i != bytes.len() {
        return p.err("trailing bytes");
    }
    Ok(v)
}

// ------------------------------------------------------------------ files

pub(crate) fn sha256(bytes: &[u8]) -> [u8; 32] {
    Sha256::digest(bytes).into()
}

pub(crate) fn hex(d: &[u8]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

pub(crate) fn unhex32(s: &str) -> Result<[u8; 32], String> {
    if s.len() != 64 || !s.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err(format!("`{s}` is not a 64-hex-digit SHA-256"));
    }
    let mut out = [0u8; 32];
    for (k, b) in out.iter_mut().enumerate() {
        *b = u8::from_str_radix(&s[2 * k..2 * k + 2], 16).map_err(|_| "bad hex")?;
    }
    Ok(out)
}

fn read_bounded(path: &Path, max: u64) -> Result<Vec<u8>, String> {
    let meta = std::fs::metadata(path).map_err(|e| format!("{}: {e}", path.display()))?;
    if !meta.is_file() {
        return Err(format!("{}: not a regular file", path.display()));
    }
    if meta.len() > max {
        return Err(format!("{}: {} bytes exceeds the bound {max}", path.display(), meta.len()));
    }
    std::fs::read(path).map_err(|e| format!("{}: {e}", path.display()))
}

/// a file name from a manifest: one plain path component, no traversal
fn plain_name(name: &str) -> Result<&str, String> {
    if name.is_empty() || name.contains('/') || name.contains('\\') || name == "." || name == ".." || name.starts_with('.') {
        return Err(format!("manifest file name `{name}` is not a plain file name"));
    }
    Ok(name)
}

/// The array kinds the reader accepts, and their element size.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Dtype {
    I8,
    I16,
    I64,
}

impl Dtype {
    fn parse(s: &str) -> Result<Dtype, String> {
        match s {
            "int8" | "i8" => Ok(Dtype::I8),
            "int16" | "i16" | "<i2" => Ok(Dtype::I16),
            "int64" | "i64" | "<i8" => Ok(Dtype::I64),
            _ => Err(format!("dtype `{s}` is not one of int8 / int16 / int64")),
        }
    }
    fn size(self) -> usize {
        match self {
            Dtype::I8 => 1,
            Dtype::I16 => 2,
            Dtype::I64 => 8,
        }
    }
}

/// One verified array: its bytes passed the manifest's SHA-256, dtype, shape
/// and length.
struct Array {
    dtype: Dtype,
    shape: Vec<usize>,
    bytes: Vec<u8>,
    sha256: [u8; 32],
}

impl Array {
    fn i8s(&self) -> Vec<i8> {
        self.bytes.iter().map(|b| *b as i8).collect()
    }
    fn i16s(&self) -> Vec<i16> {
        self.bytes.chunks_exact(2).map(|c| i16::from_le_bytes([c[0], c[1]])).collect()
    }
    fn i64s(&self) -> Vec<i64> {
        self.bytes.chunks_exact(8).map(|c| i64::from_le_bytes(c.try_into().expect("8 bytes"))).collect()
    }
    fn expect(&self, name: &str, dtype: Dtype, shape: &[usize]) -> Result<(), String> {
        if self.dtype != dtype || self.shape != shape {
            return Err(format!("array `{name}`: {:?} {:?}, expected {dtype:?} {shape:?}", self.dtype, self.shape));
        }
        Ok(())
    }
}

fn load_array(dir: &Path, name: &str, spec: &J) -> Result<Array, String> {
    let ctx = |e: String| format!("array `{name}`: {e}");
    let file = plain_name(spec.get("file").and_then(J::str).map_err(ctx)?).map_err(ctx)?;
    let dtype = Dtype::parse(spec.get("dtype").and_then(J::str).map_err(ctx)?).map_err(ctx)?;
    let shape: Vec<usize> = spec.get("shape").and_then(J::arr).map_err(ctx)?.iter().map(|v| v.i64().and_then(|x| usize::try_from(x).map_err(|_| "a negative dimension".to_string()))).collect::<Result<_, _>>().map_err(ctx)?;
    let want = unhex32(spec.get("sha256").and_then(J::str).map_err(ctx)?).map_err(ctx)?;
    let n: usize = shape.iter().product::<usize>().checked_mul(dtype.size()).ok_or_else(|| ctx("size overflow".into()))?;
    let bytes = read_bounded(&dir.join(file), MAX_ARRAY_BYTES)?;
    if bytes.len() != n {
        return Err(ctx(format!("{} bytes on disk, the manifest's dtype and shape give {n}", bytes.len())));
    }
    let got = sha256(&bytes);
    if got != want {
        return Err(ctx(format!("SHA-256 mismatch: the manifest says {}, the file is {}", hex(&want), hex(&got))));
    }
    Ok(Array { dtype, shape, bytes, sha256: got })
}

// ------------------------------------------------------------------ the export

/// the profile constants the relations hold FIXED, and the code's values
fn fixed_constants() -> [(&'static str, i64); 11] {
    use super::layout::*;
    [
        ("sh_qkv", i64::from(SH_QKV)),
        ("sh_rope", i64::from(SH_ROPE)),
        ("sh_s", i64::from(SH_S)),
        ("sh_o", i64::from(SH_O)),
        ("sh_g", i64::from(SH_G)),
        ("sh_u", 0),
        ("sh_h", i64::from(SH_H_PROD)),
        ("sh_z", i64::from(SH_Z)),
        ("f_p", i64::from(F_P)),
        ("f_ro", i64::from(F_RO)),
        ("sh_r2", 0),
    ]
}

/// The constants of one record (`profile.json`'s or a layer manifest's),
/// checked: fixed ones equal the code's; returns the trained ones.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Constants {
    pub cal: NormCalibration,
    pub f_e: u32,
    pub silu: (i32, i32),
    pub exp_e_s: i32,
    pub rope_theta: f64,
}

fn constants_of(c: &J, what: &str) -> Result<Constants, String> {
    let ctx = |e: String| format!("{what}: {e}");
    let int = |k: &str| -> Result<i64, String> { c.get(k).and_then(J::i64).map_err(|e| format!("{what}: constant `{k}`: {e}")) };
    for (k, want) in fixed_constants() {
        let got = int(k)?;
        if got != want {
            return Err(format!("{what}: constant `{k}` = {got}, but the proof relations hold it at {want} (a different value is a different layout or kernel, not a calibration)"));
        }
    }
    let silu = c.get("silu_member").and_then(J::arr).map_err(ctx)?;
    if silu.len() != 2 {
        return Err(ctx("silu_member is not [e_in, e_out]".into()));
    }
    let u32_of = |k: &str| -> Result<u32, String> { u32::try_from(int(k)?).map_err(|_| format!("{what}: `{k}` is out of range")) };
    let i32_of = |v: &J| -> Result<i32, String> { v.i64().and_then(|x| i32::try_from(x).map_err(|_| "out of range".into())).map_err(ctx) };
    Ok(Constants {
        cal: NormCalibration { tn: u32_of("norm_tn")?, cn_a: int("norm_cn_a")?, cn_m: int("norm_cn_m")?, ceps: int("norm_ceps")?, sh_ao: u32_of("sh_ao")? },
        f_e: u32_of("f_e")?,
        silu: (i32_of(&silu[0])?, i32_of(&silu[1])?),
        exp_e_s: i32::try_from(int("exp_e_s")?).map_err(|_| ctx("exp_e_s is out of range".into()))?,
        rope_theta: c.get("rope_theta").and_then(J::f64).map_err(ctx)?,
    })
}

/// The geometries an export may name. The TRAINED TinyLlama profile is the
/// deliverable; the trained-calibration development rung exists so that the
/// loader, the driver and their controls are exercised end to end on a
/// small export in the ordinary test filter. A rung export must name a
/// synthetic source (repository `synthetic/...`); a TinyLlama export must
/// name THE pinned checkpoint.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Geometry {
    TinyLlamaT32,
    RungTcDev,
}

impl Geometry {
    fn parse(s: &str) -> Result<Geometry, String> {
        match s {
            "tinyllama-1.1b-t32" => Ok(Geometry::TinyLlamaT32),
            "rung-tc-t32-dev" => Ok(Geometry::RungTcDev),
            _ => Err(format!("geometry `{s}` is not one of tinyllama-1.1b-t32 / rung-tc-t32-dev")),
        }
    }
    pub(crate) fn run_profile(self) -> &'static str {
        match self {
            Geometry::TinyLlamaT32 => RUN_PROFILE_TINYLLAMA_T32_TRAINED,
            Geometry::RungTcDev => RUN_PROFILE_RUNG_TC,
        }
    }
    pub(crate) fn run_shape(self, sh: &Shape, l: usize) -> Result<RunShape, String> {
        match self {
            Geometry::TinyLlamaT32 => RunShape::tinyllama_t32_trained(sh.clone(), l),
            Geometry::RungTcDev => RunShape::rung_tc(sh.clone(), l),
        }
    }
    /// the shape at a calibration (the controls rebuild it at other ones)
    pub(crate) fn scope(self) -> &'static str {
        match self {
            Geometry::TinyLlamaT32 => SCOPE,
            Geometry::RungTcDev => SCOPE_RUNG,
        }
    }
    pub(crate) fn shape_at(self, cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        match self {
            Geometry::TinyLlamaT32 => Shape::tinyllama_t32_trained(cal, f_e),
            Geometry::RungTcDev => {
                if f_e != 12 {
                    return Err(format!("trained export: the rung-TC geometry fixes f_e = 12, the export declares {f_e}"));
                }
                Shape::rung_tc(cal)
            }
        }
    }
}

/// The export's `profile.json`, read and checked.
pub(crate) struct TrainedExport {
    pub dir: PathBuf,
    pub geometry: Geometry,
    pub source: ModelSource,
    pub variant: String,
    pub profile_sha256: [u8; 32],
    pub tool_sha256: [u8; 32],
    pub tokens: usize,
    /// the profile's constants when every one of them is uniform across the
    /// layers; `None` when the writer marks some per-layer (`null` in
    /// `profile_constants`, named in `per_layer_constants_differ`) — then a
    /// run takes ITS layers' manifest constants, which must agree with each
    /// other (one calibration per run)
    pub constants: Option<Constants>,
    pub per_layer_differ: Vec<String>,
    pub layers: Vec<u32>,
    /// `profile.json`'s own digest of each layer manifest, where it gives one
    pub layer_manifest_sha256: Vec<(u32, [u8; 32])>,
    pub residual_unit: f64,
    pub calibration_set_sha256: [u8; 32],
}

/// One loaded layer: the padded public statement and its record.
pub(crate) struct TrainedLayer {
    pub index: u32,
    pub manifest_sha256: [u8; 32],
    pub blk: BlockPublic,
    pub record: LayerRecord,
    /// how the RoPE tables were chosen, for the run record
    pub rope_note: String,
}

impl TrainedExport {
    /// Read `<dir>/profile.json` (`dir` is the variant directory).
    pub(crate) fn load(dir: &Path) -> Result<TrainedExport, String> {
        let path = dir.join("profile.json");
        let bytes = read_bounded(&path, MAX_JSON_BYTES)?;
        let p = parse_json(&bytes).map_err(|e| format!("{}: {e}", path.display()))?;
        let ctx = |e: String| format!("{}: {e}", path.display());
        let schema = p.get("schema").and_then(J::str).map_err(ctx)?;
        if schema != PROFILE_SCHEMA {
            return Err(ctx(format!("schema `{schema}`, this reader reads `{PROFILE_SCHEMA}`")));
        }
        let geometry = match p.opt("geometry") {
            None => Geometry::TinyLlamaT32,
            Some(g) => Geometry::parse(g.str().map_err(ctx)?).map_err(ctx)?,
        };
        // the model pin: THE pinned source for TinyLlama, a synthetic recipe
        // for the development rung
        let m = p.get("model").map_err(ctx)?;
        let pin = ModelSource::tinyllama_chat_v1_0();
        let (repo, rev, msha) = (m.get("repo").and_then(J::str).map_err(ctx)?, m.get("revision").and_then(J::str).map_err(ctx)?, unhex32(m.get("sha256").and_then(J::str).map_err(ctx)?).map_err(ctx)?);
        let source = match geometry {
            Geometry::TinyLlamaT32 => {
                if repo != pin.repo || rev != pin.revision || msha != pin.weights_sha256 {
                    return Err(ctx(format!("the model pin ({repo}, {rev}, {}) is not the pinned TinyLlama source ({}, {}, {})", hex(&msha), pin.repo, pin.revision, hex(&pin.weights_sha256))));
                }
                pin
            }
            Geometry::RungTcDev => {
                if !repo.starts_with("synthetic/") || rev.is_empty() {
                    return Err(ctx("a rung-TC export must name a synthetic source (`synthetic/...`) and a revision".into()));
                }
                ModelSource { kind: SourceKind::PublicSyntheticRecipe, repo: repo.into(), revision: rev.into(), weights_sha256: msha, config_sha256: [0; 32], checkpoint_parameters: 0, checkpoint_layers: 0 }
            }
        };
        let tool = p.get_any(&["calibration_tool", "tool", "calibration"]).map_err(ctx)?;
        // one SHA-256, or an object of per-file SHA-256s: then the tool's
        // digest is the SHA-256 of the canonical text `path\n` followed by
        // `name hex\n` per file in name order (every file digest checked to be
        // 64 hex digits)
        let tool_sha256 = match tool.get("sha256").map_err(ctx)? {
            J::Str(h) => unhex32(h).map_err(ctx)?,
            J::Obj(files) => {
                let mut v: Vec<(String, String)> = Vec::new();
                for (name, h) in files {
                    let h = h.str().map_err(ctx)?;
                    unhex32(h).map_err(ctx)?;
                    v.push((name.clone(), h.to_ascii_lowercase()));
                }
                v.sort();
                let mut text = format!("{}\n", tool.opt("path").and_then(|x| x.str().ok()).unwrap_or(""));
                for (n, h) in v {
                    text.push_str(&format!("{n} {h}\n"));
                }
                sha256(text.as_bytes())
            }
            _ => return Err(ctx("calibration_tool.sha256 is neither a digest nor an object of digests".into())),
        };
        let tokens = usize::try_from(p.get_any(&["T", "tokens"]).and_then(J::i64).map_err(ctx)?).map_err(|_| ctx("T is negative".into()))?;
        let pc = p.get_any(&["constants", "profile", "profile_constants"]).map_err(ctx)?;
        let nulls: Vec<String> = pc.obj().map_err(ctx)?.iter().filter(|(_, v)| *v == J::Null).map(|(k, _)| k.clone()).collect();
        let mut per_layer_differ: Vec<String> = match p.opt("per_layer_constants_differ") {
            Some(v) => v.arr().map_err(ctx)?.iter().map(|x| x.str().map(String::from)).collect::<Result<_, _>>().map_err(ctx)?,
            None => Vec::new(),
        };
        per_layer_differ.sort();
        let mut sorted_nulls = nulls.clone();
        sorted_nulls.sort();
        if sorted_nulls != per_layer_differ {
            return Err(ctx(format!("profile_constants has null {sorted_nulls:?} but per_layer_constants_differ names {per_layer_differ:?}")));
        }
        let constants = if nulls.is_empty() { Some(constants_of(pc, &path.display().to_string())?) } else { None };
        let mut layers = Vec::new();
        let mut layer_manifest_sha256 = Vec::new();
        for l in p.get("layers").and_then(J::arr).map_err(ctx)? {
            let idx = match l {
                J::Num(_) => l.i64(),
                _ => l.get_any(&["index", "layer"]).and_then(J::i64),
            }
            .map_err(ctx)?;
            let idx = u32::try_from(idx).map_err(|_| ctx("a negative layer index".into()))?;
            if let Some(dir) = l.opt("dir") {
                if dir.str().map_err(ctx)? != format!("layer_{idx:02}") {
                    return Err(ctx(format!("layer {idx}'s dir is not layer_{idx:02}")));
                }
            }
            if let Some(h) = l.opt("manifest_sha256") {
                layer_manifest_sha256.push((idx, unhex32(h.str().map_err(ctx)?).map_err(ctx)?));
            }
            if layers.contains(&idx) {
                return Err(ctx(format!("layer {idx} is listed twice")));
            }
            layers.push(idx);
        }
        let residual_unit = match p.opt("residual_unit").or_else(|| p.opt("s_x")).or_else(|| p.opt("metadata_out_of_proof").and_then(|m| m.opt("residual_scale_s_x"))) {
            Some(J::Null) | None => 1.0,
            Some(v) => v.f64().map_err(ctx)?,
        };
        let calibration_set_sha256 = match p.opt("calibration_set_sha256") {
            Some(v) => unhex32(v.str().map_err(ctx)?).map_err(ctx)?,
            None => [0; 32],
        };
        let variant = dir.file_name().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
        let mut source = source;
        if geometry == Geometry::RungTcDev {
            source.checkpoint_layers = layers.iter().max().map(|m| m + 1).unwrap_or(0);
        }
        Ok(TrainedExport {
            dir: dir.to_path_buf(),
            geometry,
            source,
            variant,
            profile_sha256: sha256(&bytes),
            tool_sha256,
            tokens,
            constants,
            per_layer_differ,
            layers,
            layer_manifest_sha256,
            residual_unit,
            calibration_set_sha256,
        })
    }

    /// One layer manifest, read, digest-checked against `profile.json`'s
    /// record of it, and parsed.
    fn manifest(&self, index: u32) -> Result<(PathBuf, Vec<u8>, J), String> {
        if !self.layers.contains(&index) {
            return Err(format!("trained export: layer {index} is not in profile.json's layer list"));
        }
        let mpath = self.layer_dir(index).join("manifest.json");
        let mbytes = read_bounded(&mpath, MAX_JSON_BYTES)?;
        if let Some((_, want)) = self.layer_manifest_sha256.iter().find(|(i, _)| *i == index) {
            let got = sha256(&mbytes);
            if got != *want {
                return Err(format!("{}: SHA-256 {} is not profile.json's {}", mpath.display(), hex(&got), hex(want)));
            }
        }
        let m = parse_json(&mbytes).map_err(|e| format!("{}: {e}", mpath.display()))?;
        Ok((mpath, mbytes, m))
    }

    /// **The ONE calibration of a run over `layers`.** The profile's uniform
    /// constants, or, where the writer marked some per-layer, the layers'
    /// own manifest constants — which must then agree across the run (a run
    /// has one shape). Every layer's manifest constants must equal the result.
    pub(crate) fn run_constants(&self, layers: &[u32]) -> Result<Constants, String> {
        let mut out = self.constants.clone();
        for &l in layers {
            let (mpath, _, m) = self.manifest(l)?;
            let c = constants_of(m.get("constants").map_err(|e| format!("{}: {e}", mpath.display()))?, &mpath.display().to_string())?;
            match &out {
                Some(o) if *o != c => {
                    return Err(format!(
                        "{}: this layer's constants differ from the {} (one calibration per run; fold the variation into the words or prove the layers in separate runs)",
                        mpath.display(),
                        if self.constants.is_some() { "profile's" } else { "run's other layers'" }
                    ))
                }
                Some(_) => {}
                None => out = Some(c),
            }
        }
        out.ok_or_else(|| "trained export: no layer given and no uniform profile constants".to_string())
    }

    /// The trained shape of a run with these constants (only T = 32 is
    /// registered).
    pub(crate) fn shape_for(&self, c: &Constants) -> Result<Shape, String> {
        if self.tokens != 32 {
            return Err(format!("trained export: T = {}; only T = 32 is registered", self.tokens));
        }
        self.geometry.shape_at(&c.cal, c.f_e)
    }

    fn layer_dir(&self, index: u32) -> PathBuf {
        self.dir.join(format!("layer_{index:02}"))
    }

    /// Load one layer: every array verified, the tables cross-checked, the
    /// words padded per the shape (ruling P-2) into the public statement.
    pub(crate) fn load_layer(&self, sh: &Shape, c: &Constants, index: u32, rope_from_export: bool) -> Result<TrainedLayer, String> {
        let dir = self.layer_dir(index);
        let (mpath, mbytes, m) = self.manifest(index)?;
        let ctx = |e: String| format!("{}: {e}", mpath.display());
        let mi = m.get_any(&["layer", "index"]).and_then(J::i64).map_err(ctx)?;
        if mi != i64::from(index) {
            return Err(ctx(format!("the manifest is for layer {mi}, not {index}")));
        }
        let lc = constants_of(m.get("constants").map_err(ctx)?, &mpath.display().to_string())?;
        if lc != *c {
            return Err(ctx("this layer's constants are not the run's (one calibration per run)".into()));
        }
        if sh.norm_calibration() != c.cal || sh.f_e != c.f_e {
            return Err(ctx("the shape was not built from the run's constants".into()));
        }
        let arrays = m.get("arrays").map_err(ctx)?;
        let get = |name: &str| -> Result<Array, String> { load_array(&dir, name, arrays.get(name).map_err(ctx)?) };
        let (d, f, kvw, half) = (sh.width, sh.hidden, sh.kv_heads * sh.head_dim, sh.head_dim / 2);
        let wq = get("wq")?;
        wq.expect("wq", Dtype::I8, &[d, d])?;
        let wk = get("wk")?;
        wk.expect("wk", Dtype::I8, &[kvw, d])?;
        let wv = get("wv")?;
        wv.expect("wv", Dtype::I8, &[kvw, d])?;
        let wo = get("wo")?;
        wo.expect("wo", Dtype::I8, &[d, d])?;
        let ga = get("gamma_a")?;
        ga.expect("gamma_a", Dtype::I8, &[d])?;
        let gm = get("gamma_m")?;
        gm.expect("gamma_m", Dtype::I8, &[d])?;
        let wg = get("wg_t")?;
        wg.expect("wg_t", Dtype::I8, &[d, f])?;
        let wu = get("wu_t")?;
        wu.expect("wu_t", Dtype::I8, &[d, f])?;
        let wd = get("wd_t")?;
        wd.expect("wd_t", Dtype::I8, &[f, d])?;
        let exp = get("exp")?;
        exp.expect("exp", Dtype::I64, &[256])?;
        let act = get("act")?;
        act.expect("act", Dtype::I16, &[256])?;
        // the tables against the generators the run's constants name
        let (gexp, _) = crate::tables_attn::exp_member(c.exp_e_s, sh.head_dim, c.f_e);
        if exp.i64s() != gexp.to_vec() {
            return Err(ctx(format!("the exported exp table is not exp_member(e_s = {}, head_dim = {}, f_e = {})", c.exp_e_s, sh.head_dim, c.f_e)));
        }
        let (gact, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, c.silu.0, c.silu.1).ok_or_else(|| ctx(format!("silu_member {:?} is not in the frozen SiLU registry", c.silu)))?;
        if act.i16s() != gact.to_vec() {
            return Err(ctx(format!("the exported act table is not the frozen SiLU member {:?}", c.silu)));
        }
        let (gcos, gsin) = crate::tables_attn::rope_tables_generate(sh.tokens, sh.head_dim, c.rope_theta, F_RO);
        let exported = match (arrays.opt("rope_cos").or_else(|| arrays.opt("cos")), arrays.opt("rope_sin").or_else(|| arrays.opt("sin"))) {
            (Some(cs), Some(ss)) => {
                let (ca, sa) = (load_array(&dir, "rope_cos", cs)?, load_array(&dir, "rope_sin", ss)?);
                ca.expect("rope_cos", Dtype::I64, &[sh.tokens, half]).or_else(|_| ca.expect("rope_cos", Dtype::I64, &[sh.tokens * half]))?;
                sa.expect("rope_sin", Dtype::I64, &[sh.tokens, half]).or_else(|_| sa.expect("rope_sin", Dtype::I64, &[sh.tokens * half]))?;
                Some((ca.i64s(), sa.i64s()))
            }
            _ => None,
        };
        let (cos, sin, rope_note) = match exported {
            None => (gcos, gsin, format!("native generator at theta {} (the export carries no RoPE tables)", c.rope_theta)),
            Some((ec, es)) => {
                let diff = ec.iter().zip(gcos.iter()).chain(es.iter().zip(gsin.iter())).filter(|(a, b)| a != b).count();
                if diff == 0 {
                    (gcos, gsin, format!("native generator at theta {}, equal to the export's tables", c.rope_theta))
                } else if rope_from_export {
                    (ec, es, format!("the EXPORT's tables, which differ from the native generator at theta {} in {diff} entries (caller opted in)", c.rope_theta))
                } else {
                    let first = ec.iter().zip(gcos.iter()).position(|(a, b)| a != b).map(|k| format!("cos[{k}]")).or_else(|| es.iter().zip(gsin.iter()).position(|(a, b)| a != b).map(|k| format!("sin[{k}]"))).unwrap_or_default();
                    return Err(ctx(format!("the exported RoPE tables differ from the native generator at theta {} in {diff} entries (first {first}); pass --rope-from-export to prove with the export's tables", c.rope_theta)));
                }
            }
        };
        // pad per the shape (ruling P-2): Wq writes the head-permuted Q axis,
        // Wo reads it; Wk / Wv do not pad on their width axis
        let (dp, fp) = (sh.d_pad, sh.f_pad);
        let id = |i: usize| i;
        let q = |j: usize| sh.head_slot(j / sh.head_dim) * sh.head_dim + j % sh.head_dim;
        let aw = [
            pad_matrix(&wq.i8s(), d, d, dp, dp, &q, &id),
            pad_matrix(&wk.i8s(), kvw, d, kvw, dp, &id, &id),
            pad_matrix(&wv.i8s(), kvw, d, kvw, dp, &id, &id),
            pad_matrix(&wo.i8s(), d, d, dp, dp, &id, &q),
            pad_matrix(&ga.i8s(), 1, d, 1, dp, &id, &id),
        ];
        let fw = [pad_matrix(&gm.i8s(), 1, d, 1, dp, &id, &id), pad_matrix(&wg.i8s(), d, f, dp, fp, &id, &id), pad_matrix(&wu.i8s(), d, f, dp, fp, &id, &id), pad_matrix(&wd.i8s(), f, d, fp, dp, &id, &id)];
        let public = AttentionPublic::new_shaped(sh, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp.i64s()).map_err(ctx)?;
        let ff = FeedForwardPublic::new_shaped(sh, &fw[0], &fw[1], &fw[2], &fw[3], &act.i16s()).map_err(ctx)?;
        let blk = BlockPublic::new(public, ff);
        // the source tensors the manifest names, if it names any
        let mut source_tensors: Vec<(String, [u8; 32])> = Vec::new();
        if let Some(st) = m.opt("source_tensors") {
            for (name, v) in st.obj().map_err(ctx)? {
                source_tensors.push((name.clone(), unhex32(v.str().map_err(ctx)?).map_err(ctx)?));
            }
        }
        let mut record = LayerRecord::of_block(index, &blk, source_tensors);
        let manifest_sha256 = sha256(&mbytes);
        record.manifest_sha256 = manifest_sha256;
        let _ = (wq.sha256, exp.sha256);
        Ok(TrainedLayer { index, manifest_sha256, blk, record, rope_note })
    }

    /// The PRIVATE hidden input and the Python reference's output of layer
    /// `index` on sequence `seq`, true-sized `[T, d]`. Prover only.
    pub(crate) fn load_seq(&self, sh: &Shape, seq: &str, index: u32) -> Result<(Vec<i16>, Vec<i16>), String> {
        plain_name(seq)?;
        let dir = self.dir.join(format!("seq_{seq}"));
        let n = sh.tokens * sh.width * 2;
        // the sequence manifest, when the writer gives one: every array is
        // then SHA-256-, dtype- and shape-checked like a layer's (the digests
        // are the writer's; this reader never prints or records them)
        let mpath = dir.join("manifest.json");
        if mpath.exists() {
            let m = parse_json(&read_bounded(&mpath, MAX_JSON_BYTES)?).map_err(|e| format!("{}: {e}", mpath.display()))?;
            let arrays = m.get("arrays").map_err(|e| format!("{}: {e}", mpath.display()))?;
            let get = |name: String| -> Result<Vec<i16>, String> {
                let a = load_array(&dir, &name, arrays.get(&name).map_err(|e| format!("{}: {e}", mpath.display()))?)?;
                a.expect(&name, Dtype::I16, &[sh.tokens, sh.width])?;
                Ok(a.i16s())
            };
            return Ok((get(format!("x_in_L{index:02}"))?, get(format!("x_out_L{index:02}"))?));
        }
        let read = |name: String| -> Result<Vec<i16>, String> {
            let b = read_bounded(&dir.join(&name), n as u64)?;
            if b.len() != n {
                return Err(format!("{}/{name}: {} bytes, expected int16 [{}, {}] = {n}", dir.display(), b.len(), sh.tokens, sh.width));
            }
            Ok(b.chunks_exact(2).map(|c| i16::from_le_bytes([c[0], c[1]])).collect())
        };
        Ok((read(format!("x_in_L{index:02}.bin"))?, read(format!("x_out_L{index:02}.bin"))?))
    }

    /// THE STATEMENT a run over these layers binds: the pinned source, the
    /// shape's calibration, the export provenance, one record per layer.
    pub(crate) fn statement(&self, sh: &Shape, c: &Constants, layers: &[&TrainedLayer]) -> Result<TrainedModelStatement, String> {
        let prov = Provenance {
            label: format!("export:{}", self.variant),
            residual_unit: self.residual_unit,
            quantizer_sha256: self.tool_sha256,
            calibration_set_sha256: self.calibration_set_sha256,
            export_profile_sha256: self.profile_sha256,
            calibration_tool_sha256: self.tool_sha256,
            silu_member: c.silu,
            exp_e_s: c.exp_e_s,
            rope_theta: c.rope_theta,
        };
        let cal = IntegerCalibration::as_the_code_proves(sh, &prov);
        TrainedModelStatement::new(sh, self.geometry.run_profile(), self.source.clone(), cal, layers.iter().map(|l| l.record.clone()).collect())
    }
}

/// a true `(to, ti)` row-major matrix placed into the padded `(po, pi)` one
/// through the two index maps (ruling P-2; the same map as the driver's)
fn pad_matrix(w: &[i8], to: usize, ti: usize, po: usize, pi: usize, omap: &dyn Fn(usize) -> usize, imap: &dyn Fn(usize) -> usize) -> Vec<i8> {
    let mut out = vec![0i8; po * pi];
    for o in 0..to {
        for i in 0..ti {
            out[omap(o) * pi + imap(i)] = w[o * ti + i];
        }
    }
    out
}

// ------------------------------------------------------------------ parity

/// **THE PARITY CHECK.** The native witness on the exported `x_in` must
/// reproduce the exported `x_out` bit for bit. On a mismatch the report gives
/// counts and the first differing position, never a value.
pub(crate) fn parity(sh: &Shape, blk: &BlockPublic, x_in: &[i16], x_out: &[i16]) -> Result<Witness, String> {
    let w = witness::build_shaped(sh, blk.attention(), blk.feed_forward(), x_in).map_err(|e| format!("parity: the native witness REFUSES the exported input: {e}"))?;
    let ids = Ids::new(sh)?;
    let x2 = &w.planes[ids.at(A_X2)];
    let mut first: Option<(usize, usize)> = None;
    let mut n = 0usize;
    for t in 0..sh.tokens {
        for i in 0..sh.width {
            if x2[t * sh.d_pad + i] != i64::from(x_out[t * sh.width + i]) {
                n += 1;
                first.get_or_insert((t, i));
            }
        }
    }
    if let Some((t, i)) = first {
        return Err(format!("parity: the native block output differs from the exported x_out in {n} of {} words (first at token {t}, channel {i}); no value is printed", sh.tokens * sh.width));
    }
    Ok(w)
}

// ------------------------------------------------------------------ the CLI

fn padded_plane(w: &Witness, p: usize) -> Result<Vec<i16>, String> {
    w.planes[p].iter().map(|v| i16::try_from(*v).map_err(|_| "a plane word outside int16".to_string())).collect()
}

/// the one-block witness source of a bound run
struct OneBlock<'a> {
    sh: &'a Shape,
    blk: &'a BlockPublic,
    w: Option<Witness>,
}

impl RunWitnessSource for OneBlock<'_> {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        if k != 0 {
            return Err("trained block: a one-block run has one stage".into());
        }
        let _ = (self.sh, self.blk);
        self.w.take().ok_or_else(|| "trained block: the witness was already consumed".into())
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        Err("trained block: a one-block run has no internal boundary".into())
    }
}

/// the request context of a trained-block run: a public function of the
/// variant, the layer and a caller label, never of the hidden input
fn context_of(variant: &str, layer: u32, label: &str) -> Digest {
    let mut b = Vec::new();
    for s in ["hashline/zk60-trained-block-context/1", variant, label] {
        b.extend_from_slice(&(s.len() as u64).to_le_bytes());
        b.extend_from_slice(s.as_bytes());
    }
    b.extend_from_slice(&u64::from(layer).to_le_bytes());
    *blake3::hash(&b).as_bytes()
}

fn flags(args: &[String], allowed: &[&str], switches: &[&str]) -> Result<Vec<(String, String)>, String> {
    let mut out = Vec::new();
    let mut i = 0;
    while i < args.len() {
        let a = &args[i];
        if switches.contains(&a.as_str()) {
            out.push((a.clone(), String::new()));
            i += 1;
        } else if allowed.contains(&a.as_str()) {
            let v = args.get(i + 1).ok_or_else(|| format!("{a} needs a value"))?;
            out.push((a.clone(), v.clone()));
            i += 2;
        } else {
            return Err(format!("unknown argument `{a}`"));
        }
    }
    Ok(out)
}

fn flag<'a>(f: &'a [(String, String)], k: &str) -> Option<&'a str> {
    f.iter().find(|(x, _)| x == k).map(|(_, v)| v.as_str())
}

fn need<'a>(f: &'a [(String, String)], k: &str) -> Result<&'a str, String> {
    flag(f, k).ok_or_else(|| format!("{k} is required"))
}

fn js(s: &str) -> String {
    let mut o = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o.push('"');
    o
}

fn peak_rss_mib() -> f64 {
    run::peak_rss_mib()
}

/// The public record of a trained-block run (`statement.json`): everything a
/// verifier pins, the shape INCLUDING the norm calibration (for a later gate
/// port), and no hidden value.
fn render_statement(ex: &TrainedExport, sh: &Shape, layer: &TrainedLayer, st: &TrainedModelStatement, ctx: &Digest, expected: &ExpectedIo, label: &str) -> String {
    let c = sh.norm_calibration();
    format!(
        "{{\n \"schema\": \"zk60-trained-block-run/1\",\n \"scope\": {},\n \"block_profile\": {},\n \"run_profile\": {},\n \"export_variant\": {},\n \"export_profile_sha256\": {},\n \"calibration_tool_sha256\": {},\n \"layer\": {},\n \"layer_manifest_sha256\": {},\n \"block_digest\": {},\n \"trained_statement_identity\": {},\n \"context_label\": {},\n \"context\": {},\n \"expected_io\": {},\n \"rope_tables\": {},\n \"constants_source\": {},\n \"shape\": {{\"tokens\": {}, \"width\": {}, \"hidden\": {}, \"q_heads\": {}, \"kv_heads\": {}, \"head_dim\": {}, \"log_cols\": {}, \"inv_rate\": {}, \"opened_cols\": {}, \"f_e\": {}, \"wrho_s\": {}, \"norm_wrho\": {}, \"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_ao\": {}, \"d_max\": {}}}\n}}\n",
        js(ex.geometry.scope()),
        js(sh.profile),
        js(ex.geometry.run_profile()),
        js(&ex.variant),
        js(&hex(&ex.profile_sha256)),
        js(&hex(&ex.tool_sha256)),
        layer.index,
        js(&hex(&layer.manifest_sha256)),
        js(&hex(&layer.blk.digest())),
        js(&hex(&st.identity())),
        js(label),
        js(&hex(ctx)),
        js(&hex(&expected.to_bytes())),
        js(&layer.rope_note),
        js(&if ex.constants.is_some() { "profile.json (uniform across the export's layers)".to_string() } else { format!("this layer's manifest (the export marks {:?} per-layer); one calibration for this one-block run", ex.per_layer_differ) }),
        sh.tokens,
        sh.width,
        sh.hidden,
        sh.q_heads,
        sh.kv_heads,
        sh.head_dim,
        sh.log_cols,
        sh.inv_rate,
        sh.opened_cols,
        sh.f_e,
        sh.wrho_s,
        sh.norm_wrho,
        c.tn,
        c.cn_a,
        c.cn_m,
        c.ceps,
        c.sh_ao,
        sh.d_max
    )
}

fn write_new(path: &Path, bytes: &[u8]) -> Result<(), String> {
    use std::io::Write;
    let mut f = std::fs::OpenOptions::new().write(true).create_new(true).open(path).map_err(|e| format!("{}: {e}", path.display()))?;
    f.write_all(bytes).and_then(|_| f.sync_all()).map_err(|e| format!("{}: {e}", path.display()))
}

/// `prove --export DIR --layer N --seq ID --out DIR [--label L] [--rope-from-export]`
///
/// Loads the export (every digest verified), runs the PARITY check, proves
/// ONE trained block as a one-block run BOUND to the trained-model statement,
/// verifies it in-process, and writes `segment-000.bin`, `expected.bin` and
/// `statement.json` into a NEW directory. JSON lines on stdout; exit 0 =
/// proved and verified, 1 = refused or failed, 2 = bad arguments.
pub fn trained_prove_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--layer", "--seq", "--out", "--label"], &["--rope-from-export", "--controls"]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_trained_block prove: {e}");
            return 2;
        }
    };
    match prove_inner(&f) {
        Ok(()) => 0,
        Err(e) => {
            println!("{{\"event\":\"refused\",\"error\":{}}}", js(&e));
            1
        }
    }
}

fn prove_inner(f: &[(String, String)]) -> Result<(), String> {
    let t_total = Instant::now();
    let export = PathBuf::from(need(f, "--export")?);
    let layer_ix: u32 = need(f, "--layer")?.parse().map_err(|_| "--layer is not an integer")?;
    let seq = need(f, "--seq")?;
    let out = PathBuf::from(need(f, "--out")?);
    let label = flag(f, "--label").unwrap_or("zk60-trained-block");
    if out.exists() {
        return Err(format!("{} exists; the output directory must be new", out.display()));
    }
    let t0 = Instant::now();
    let ex = TrainedExport::load(&export)?;
    let c = ex.run_constants(&[layer_ix])?;
    let sh = ex.shape_for(&c)?;
    let layer = ex.load_layer(&sh, &c, layer_ix, flag(f, "--rope-from-export").is_some())?;
    let load_s = t0.elapsed().as_secs_f64();
    println!(
        "{{\"event\":\"loaded\",\"variant\":{},\"layer\":{},\"block_digest\":{},\"rope\":{},\"seconds\":{load_s:.3},\"scope\":{}}}",
        js(&ex.variant),
        layer.index,
        js(&hex(&layer.blk.digest())),
        js(&layer.rope_note),
        js(ex.geometry.scope())
    );
    let t1 = Instant::now();
    let (x_in, x_out) = ex.load_seq(&sh, seq, layer_ix)?;
    let w = parity(&sh, &layer.blk, &x_in, &x_out)?;
    drop((x_in, x_out));
    let parity_s = t1.elapsed().as_secs_f64();
    println!("{{\"event\":\"parity\",\"result\":\"bit-exact\",\"words\":{},\"seconds\":{parity_s:.3}}}", sh.tokens * sh.width);
    let st = ex.statement(&sh, &c, &[&layer])?;
    let ids = Ids::new(&sh)?;
    let ctx = context_of(&ex.variant, layer_ix, label);
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &padded_plane(&w, ids.at(A_X))?, &padded_plane(&w, ids.at(A_X2))?)?;
    let blocks = vec![layer.blk.clone()];
    let rst = RunStatement::new_bound(ex.geometry.run_shape(&sh, 1)?, ctx, expected.clone(), &blocks, &[(0, 0)], &st)?;
    let t2 = Instant::now();
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let mut src = OneBlock { sh: &sh, blk: &layer.blk, w: Some(w) };
    run::prove_run(&rst, &blocks, &mut src, owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })?;
    let prove_s = t2.elapsed().as_secs_f64();
    let hwm_prove = peak_rss_mib();
    let t3 = Instant::now();
    run::verify_run(&rst, &blocks, &segs)?;
    let verify_s = t3.elapsed().as_secs_f64();
    std::fs::create_dir(&out).map_err(|e| format!("{}: {e}", out.display()))?;
    write_new(&out.join("segment-000.bin"), &segs[0])?;
    write_new(&out.join("expected.bin"), &expected.to_bytes())?;
    write_new(&out.join("statement.json"), render_statement(&ex, &sh, &layer, &st, &ctx, &expected, label).as_bytes())?;
    println!(
        "{{\"event\":\"proved\",\"segment_bytes\":{},\"segment_sha256\":{},\"prove_seconds\":{prove_s:.3},\"in_process_verify_seconds\":{verify_s:.3},\"peak_rss_mib_after_prove\":{hwm_prove:.0},\"total_seconds\":{:.3},\"statement_identity\":{},\"out\":{}}}",
        segs[0].len(),
        js(&hex(&sha256(&segs[0]))),
        t_total.elapsed().as_secs_f64(),
        js(&hex(&st.identity())),
        js(&out.display().to_string())
    );
    if flag(f, "--controls").is_some() {
        let (x_in, _) = ex.load_seq(&sh, seq, layer_ix)?;
        inconsistent_witness_controls(&ex, &sh, &layer, &st, &x_in, label)?;
        let _ = &c;
    }
    Ok(())
}

/// **THE INCONSISTENT-WITNESS CONTROLS** (prover side; each must be REJECTED
/// by the verifier). The endpoint owner commits whatever the tampered
/// witness carries, so the endpoint equality is not what rejects: (a) one
/// norm_a output word moved by one, (b) one query activation moved by one,
/// (c) a witness that is honest under OTHER constants (`norm_cn_m + 7`),
/// proved under the declared ones.
fn inconsistent_witness_controls(ex: &TrainedExport, sh: &Shape, layer: &TrainedLayer, st: &TrainedModelStatement, x_in: &[i16], label: &str) -> Result<(), String> {
    use super::layout::{A_Q8, A_Y};
    let ids = Ids::new(sh)?;
    let ctx = context_of(&ex.variant, layer.index, label);
    let blocks = vec![layer.blk.clone()];
    let attempt = |w: Witness| -> Result<(), String> {
        let spec = IoSpec::new_shaped(sh, ctx, 0, 0)?;
        let (expected, owners) = prepare_endpoints(spec, &padded_plane(&w, ids.at(A_X))?, &padded_plane(&w, ids.at(A_X2))?)?;
        let rst = RunStatement::new_bound(ex.geometry.run_shape(sh, 1)?, ctx, expected, &blocks, &[(0, 0)], st)?;
        let mut segs: Vec<Vec<u8>> = Vec::new();
        let mut src = OneBlock { sh, blk: &layer.blk, w: Some(w) };
        run::prove_run(&rst, &blocks, &mut src, owners, &mut |_, b| {
            segs.push(b);
            Ok(())
        })?;
        run::verify_run(&rst, &blocks, &segs)
    };
    let honest = || witness::build_shaped(sh, layer.blk.attention(), layer.blk.feed_forward(), x_in);
    let mid = (sh.tokens / 2) * sh.d_pad + sh.width / 3;
    let mut cases: Vec<(&str, Witness)> = Vec::new();
    let mut w = honest()?;
    w.planes[ids.at(A_Y)][mid] += if w.planes[ids.at(A_Y)][mid] < 127 { 1 } else { -1 };
    cases.push(("one norm_a output word moved by one", w));
    let mut w = honest()?;
    w.planes[ids.at(A_Q8)][mid] += if w.planes[ids.at(A_Q8)][mid] < 127 { 1 } else { -1 };
    cases.push(("one query activation moved by one", w));
    let c = sh.norm_calibration();
    let other = ex.geometry.shape_at(&NormCalibration { cn_m: c.cn_m + 7, ..c }, sh.f_e)?;
    cases.push(("a witness honest under norm_cn_m + 7", witness::build_shaped(&other, layer.blk.attention(), layer.blk.feed_forward(), x_in)?));
    let mut n = 0usize;
    for (name, w) in cases {
        match attempt(w) {
            Ok(()) => return Err(format!("CONTROL FAILED: the inconsistent witness `{name}` was ACCEPTED")),
            Err(e) => {
                n += 1;
                println!("{{\"event\":\"control-refused\",\"control\":{},\"error\":{}}}", js(name), js(&e.chars().take(160).collect::<String>()));
            }
        }
    }
    println!("{{\"event\":\"inconsistent-witness-controls\",\"refused\":{n}}}");
    Ok(())
}

/// `verify --export DIR --layer N --artifact DIR --expect-statement HEX [--label L] [--rope-from-export] [--controls]`
///
/// A FRESH process: rebuilds the shape, the public statement and the
/// trained-model statement from the export's PUBLIC files only (it never
/// opens a `seq_*` directory), refuses unless the rebuilt statement identity
/// equals the caller's pin, reads the expected endpoint policy and the
/// segment from the artifact, and verifies. `--controls` then runs the
/// statement-mismatch and receipt-mutation controls, each of which must
/// REFUSE.
pub fn trained_verify_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--layer", "--artifact", "--expect-statement", "--label"], &["--rope-from-export", "--controls"]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_trained_block verify: {e}");
            return 2;
        }
    };
    match verify_inner(&f) {
        Ok(()) => 0,
        Err(e) => {
            println!("{{\"event\":\"rejected\",\"error\":{}}}", js(&e));
            1
        }
    }
}

fn verify_inner(f: &[(String, String)]) -> Result<(), String> {
    let export = PathBuf::from(need(f, "--export")?);
    let layer_ix: u32 = need(f, "--layer")?.parse().map_err(|_| "--layer is not an integer")?;
    let art = PathBuf::from(need(f, "--artifact")?);
    let pin = unhex32(need(f, "--expect-statement")?)?;
    let label = flag(f, "--label").unwrap_or("zk60-trained-block");
    let t0 = Instant::now();
    let ex = TrainedExport::load(&export)?;
    let c = ex.run_constants(&[layer_ix])?;
    let sh = ex.shape_for(&c)?;
    let layer = ex.load_layer(&sh, &c, layer_ix, flag(f, "--rope-from-export").is_some())?;
    let st = ex.statement(&sh, &c, &[&layer])?;
    if st.identity() != pin {
        return Err(format!("the rebuilt trained statement {} is not the pinned {}", hex(&st.identity()), hex(&pin)));
    }
    let ctx = context_of(&ex.variant, layer_ix, label);
    let expected = ExpectedIo::from_bytes_at(&sh, &read_bounded(&art.join("expected.bin"), 4096)?)?;
    if expected.to_bytes()[8..40] != ctx {
        return Err("the artifact's endpoint policy carries another context".into());
    }
    let seg = read_bounded(&art.join("segment-000.bin"), super::wire::MAX_WIRE_BYTES_ANY as u64)?;
    let blocks = vec![layer.blk.clone()];
    let rst = RunStatement::new_bound(ex.geometry.run_shape(&sh, 1)?, ctx, expected.clone(), &blocks, &[(0, 0)], &st)?;
    let load_s = t0.elapsed().as_secs_f64();
    let t1 = Instant::now();
    run::verify_run(&rst, &blocks, std::slice::from_ref(&seg))?;
    let verify_s = t1.elapsed().as_secs_f64();
    println!(
        "{{\"event\":\"verified\",\"segment_bytes\":{},\"segment_sha256\":{},\"load_seconds\":{load_s:.3},\"verify_seconds\":{verify_s:.3},\"peak_rss_mib\":{:.0},\"statement_identity\":{},\"scope\":{}}}",
        seg.len(),
        js(&hex(&sha256(&seg))),
        peak_rss_mib(),
        js(&hex(&st.identity())),
        js(ex.geometry.scope())
    );
    if flag(f, "--controls").is_some() {
        controls(&ex, &c, &sh, &layer, &st, ctx, &expected, &seg)?;
    }
    Ok(())
}

/// Every control must REFUSE; an acceptance is an error.
#[allow(clippy::too_many_arguments)]
fn controls(ex: &TrainedExport, rc: &Constants, sh: &Shape, layer: &TrainedLayer, st: &TrainedModelStatement, ctx: Digest, expected: &ExpectedIo, seg: &[u8]) -> Result<(), String> {
    let blocks = vec![layer.blk.clone()];
    let mut n = 0usize;
    let mut refuse = |name: &str, r: Result<(), String>| -> Result<(), String> {
        match r {
            Ok(()) => Err(format!("CONTROL FAILED: `{name}` was ACCEPTED")),
            Err(e) => {
                n += 1;
                println!("{{\"event\":\"control-refused\",\"control\":{},\"error\":{}}}", js(name), js(&e.chars().take(160).collect::<String>()));
                Ok(())
            }
        }
    };
    // (1) statement mismatch: a verifier whose shape carries one other
    //     calibration constant (its statement is rebuilt for that shape)
    let c = sh.norm_calibration();
    for (name, v) in [
        ("verifier statement with norm_tn - 1", NormCalibration { tn: c.tn - 1, ..c }),
        ("verifier statement with norm_cn_a + 1", NormCalibration { cn_a: c.cn_a + 1, ..c }),
        ("verifier statement with norm_cn_m + 1", NormCalibration { cn_m: c.cn_m + 1, ..c }),
        ("verifier statement with norm_ceps + 1", NormCalibration { ceps: c.ceps + 1, ..c }),
        ("verifier statement with sh_ao + 1", NormCalibration { sh_ao: c.sh_ao + 1, ..c }),
    ] {
        let r = (|| -> Result<(), String> {
            let s2 = ex.geometry.shape_at(&v, rc.f_e)?;
            let mut l2 = TrainedLayer { index: layer.index, manifest_sha256: layer.manifest_sha256, blk: layer.blk.clone(), record: layer.record.clone(), rope_note: String::new() };
            l2.record = { let mut r = LayerRecord::of_block(layer.index, &l2.blk, layer.record.source_tensors.clone()); r.manifest_sha256 = layer.manifest_sha256; r };
            let st2 = ex.statement(&s2, &Constants { cal: v, ..rc.clone() }, &[&l2])?;
            let e2 = ExpectedIo::from_bytes_at(&s2, &expected.to_bytes())?;
            let r2 = RunStatement::new_bound(ex.geometry.run_shape(&s2, 1)?, ctx, e2, &blocks, &[(0, 0)], &st2)?;
            run::verify_run(&r2, &blocks, &[seg.to_vec()])
        })();
        refuse(name, r)?;
    }
    // (2) statement mismatch: another export provenance (one byte of the
    //     profile digest), and another layer index
    {
        let mut st2 = st.clone();
        st2.calibration.export_profile_sha256[0] ^= 1;
        let r = RunStatement::new_bound(ex.geometry.run_shape(sh, 1)?, ctx, expected.clone(), &blocks, &[(0, 0)], &st2).and_then(|r2| run::verify_run(&r2, &blocks, &[seg.to_vec()]));
        refuse("verifier statement with another export profile digest", r)?;
        let mut st3 = st.clone();
        st3.layers[0].index = (st.layers[0].index + 1) % 22;
        let r = RunStatement::new_bound(ex.geometry.run_shape(sh, 1)?, ctx, expected.clone(), &blocks, &[(0, 0)], &st3).and_then(|r2| run::verify_run(&r2, &blocks, &[seg.to_vec()]));
        refuse("verifier statement naming another layer", r)?;
    }
    // (3) statement mismatch: one public weight word moved
    {
        let a = layer.blk.attention();
        let mut gamma = a.gamma_a.clone();
        gamma[0] = if gamma[0] == 127 { 126 } else { gamma[0] + 1 };
        let pub2 = AttentionPublic::new_shaped(sh, &a.wq, &a.wk, &a.wv, &a.wo, &gamma, &a.rope_cos, &a.rope_sin, &a.exp)?;
        let blk2 = BlockPublic::new(pub2, layer.blk.feed_forward().clone());
        let mut rec2 = LayerRecord::of_block(layer.index, &blk2, layer.record.source_tensors.clone());
        rec2.manifest_sha256 = layer.manifest_sha256;
        let l2 = TrainedLayer { index: layer.index, manifest_sha256: layer.manifest_sha256, blk: blk2.clone(), record: rec2, rope_note: String::new() };
        let st2 = ex.statement(sh, rc, &[&l2])?;
        let r = RunStatement::new_bound(ex.geometry.run_shape(sh, 1)?, ctx, expected.clone(), &[blk2.clone()], &[(0, 0)], &st2).and_then(|r2| run::verify_run(&r2, &[blk2], &[seg.to_vec()]));
        refuse("verifier statement with one gamma_a word moved", r)?;
    }
    // (4) receipt mutation and truncation
    let rst = RunStatement::new_bound(ex.geometry.run_shape(sh, 1)?, ctx, expected.clone(), &blocks, &[(0, 0)], st)?;
    for at in [seg.len() / 5, seg.len() / 2, seg.len() - 40] {
        let mut bad = seg.to_vec();
        bad[at] ^= 0x01;
        refuse(&format!("segment with byte {at} flipped"), run::verify_run(&rst, &blocks, &[bad]))?;
    }
    refuse("segment truncated by one byte", run::verify_run(&rst, &blocks, &[seg[..seg.len() - 1].to_vec()]))?;
    // and the honest segment still verifies beside them
    run::verify_run(&rst, &blocks, &[seg.to_vec()])?;
    println!("{{\"event\":\"controls\",\"refused\":{n},\"honest_still_verifies\":true}}");
    Ok(())
}

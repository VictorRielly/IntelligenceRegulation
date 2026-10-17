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
const SCOPE: &str = "ONE trained TinyLlama-1.1B-Chat block (of 22) at the export's T (32, 64 or 128), CPU unless the run line says gpu; the integer model the calibration export names; NOT a model pass; NO privacy acceptance at this shape (D22 covers only the toy); float fidelity is the calibration lane's measurement";
const SCOPE_8B: &str = "ONE trained Llama-3-8B block (of 32) at T=32, CPU unless the run line says gpu; the integer model the calibration export names; NOT a model pass; NO privacy acceptance at this shape (D22 covers only the toy); float fidelity is the calibration lane's measurement";
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
    // ROUND 3: a symbolic link is refused (the B4 writer shares weight files
    // between exports by HARD link, which are ordinary files; every array is
    // still SHA-256-checked against its manifest exactly as before)
    let meta = std::fs::symlink_metadata(path).map_err(|e| format!("{}: {e}", path.display()))?;
    if meta.file_type().is_symlink() {
        return Err(format!("{}: a symbolic link (the reader reads regular files only)", path.display()));
    }
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
    load_array_checked(dir, name, spec, true)
}

/// ROUND 5 (R5-2): `check_sha = false` is the proving-pass RELOAD of a block
/// the digest pass already hashed: every dtype / shape / size check still
/// runs, the per-array SHA-256 is skipped, and the caller compares the
/// rebuilt block's digest with the digest pass's — the bytes proved are the
/// bytes digested (no time-of-check/time-of-use gap: the digest is taken of
/// the very block that is proved).
fn load_array_checked(dir: &Path, name: &str, spec: &J, check_sha: bool) -> Result<Array, String> {
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
    let got = if check_sha { sha256(&bytes) } else { want };
    if got != want {
        return Err(ctx(format!("SHA-256 mismatch: the manifest says {}, the file is {}", hex(&want), hex(&got))));
    }
    Ok(Array { dtype, shape, bytes, sha256: got })
}

// ------------------------------------------------------------------ the export

/// the profile constants the relations hold FIXED, and the code's values
/// the constants the relations hold FIXED (a different value is a different
/// layout or kernel), and the code's values. ROUND 2: the windowed
/// requantization shifts left this list for the calibration.
fn fixed_constants() -> [(&'static str, i64); 5] {
    use super::layout::*;
    [("sh_rope", i64::from(SH_ROPE)), ("sh_u", 0), ("f_p", i64::from(F_P)), ("f_ro", i64::from(F_RO)), ("sh_r2", 0)]
}

/// The RUN-LEVEL constants of one record (`profile.json`'s or a layer
/// manifest's): the fixed ones checked equal to the code's, the trained
/// calibration (norm constants and the windowed shifts), `f_e` and the RoPE
/// base. One run has ONE set (its blocks share one shape).
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Constants {
    pub cal: NormCalibration,
    pub f_e: u32,
    pub rope_theta: f64,
}

/// The PER-BLOCK table keys of a layer: which SiLU registry member and which
/// exp `e_s` its two public tables are. They may differ between the blocks
/// of one run (each block's tables are its own public words).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct TableKeys {
    pub silu: (i32, i32),
    pub exp_e_s: i32,
}

/// the run-level keys of a constants object (the table keys excluded)
pub(crate) const RUN_LEVEL_KEYS: [&str; 18] = [
    "norm_tn", "norm_cn_a", "norm_cn_m", "norm_ceps", "sh_ao", "sh_qkv", "sh_s", "sh_o", "sh_g", "sh_h", "sh_z", "f_e", "rope_theta", "sh_rope", "sh_u", "f_p", "f_ro", "sh_r2",
];

fn constants_of(c: &J, what: &str, rope_pin: f64) -> Result<Constants, String> {
    let ctx = |e: String| format!("{what}: {e}");
    let int = |k: &str| -> Result<i64, String> { c.get(k).and_then(J::i64).map_err(|e| format!("{what}: constant `{k}`: {e}")) };
    for (k, want) in fixed_constants() {
        let got = int(k)?;
        if got != want {
            return Err(format!("{what}: constant `{k}` = {got}, but the proof relations hold it at {want} (a different value is a different layout or kernel, not a calibration)"));
        }
    }
    let u32_of = |k: &str| -> Result<u32, String> { u32::try_from(int(k)?).map_err(|_| format!("{what}: `{k}` is out of range")) };
    // review finding F-1 and its general rule: every constant an export
    // chooses is inside a DECLARED class, checked here (prover and verifier
    // both load through this function), again at the shape door and again in
    // `Layout::for_shape`
    let f_e = u32_of("f_e")?;
    if !super::shape::TRAINED_F_E_RANGE.contains(&f_e) {
        return Err(format!("{what}: f_e {f_e} is outside its declared class {:?} (the softmax quotient relation's no-wrap premise is derived for that class only; review finding F-1)", super::shape::TRAINED_F_E_RANGE));
    }
    let rope_theta = c.get("rope_theta").and_then(J::f64).map_err(ctx)?;
    if rope_theta != rope_pin {
        return Err(format!("{what}: rope_theta {rope_theta} is not the trained geometry's RoPE base {rope_pin} (a model fact, not a calibration choice; pinned per profile)"));
    }
    Ok(Constants {
        cal: NormCalibration {
            tn: u32_of("norm_tn")?,
            cn_a: int("norm_cn_a")?,
            cn_m: int("norm_cn_m")?,
            ceps: int("norm_ceps")?,
            sh_ao: u32_of("sh_ao")?,
            sh_qkv: u32_of("sh_qkv")?,
            sh_s: u32_of("sh_s")?,
            sh_o: u32_of("sh_o")?,
            sh_g: u32_of("sh_g")?,
            sh_h: u32_of("sh_h")?,
            sh_z: u32_of("sh_z")?,
        },
        f_e,
        rope_theta,
    })
}

fn table_keys_of(c: &J, what: &str) -> Result<TableKeys, String> {
    let ctx = |e: String| format!("{what}: {e}");
    let silu = c.get("silu_member").and_then(J::arr).map_err(ctx)?;
    if silu.len() != 2 {
        return Err(ctx("silu_member is not [e_in, e_out]".into()));
    }
    let i32_of = |v: &J| -> Result<i32, String> { v.i64().and_then(|x| i32::try_from(x).map_err(|_| "out of range".into())).map_err(ctx) };
    let tk = TableKeys { silu: (i32_of(&silu[0])?, i32_of(&silu[1])?), exp_e_s: i32_of(c.get("exp_e_s").map_err(ctx)?)? };
    // the declared classes of the per-block table keys (the tables are then
    // checked against these generator members by value)
    if !super::shape::TRAINED_EXP_E_S_RANGE.contains(&tk.exp_e_s) {
        return Err(ctx(format!("exp_e_s {} is outside its declared class {:?}", tk.exp_e_s, super::shape::TRAINED_EXP_E_S_RANGE)));
    }
    if crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, tk.silu.0, tk.silu.1).is_none() {
        return Err(ctx(format!("silu_member {:?} is not in the frozen SiLU registry", tk.silu)));
    }
    Ok(tk)
}

/// The geometries an export may name. The TRAINED TinyLlama profile is the
/// deliverable; the trained-calibration development rung exists so that the
/// loader, the driver and their controls are exercised end to end on a
/// small export in the ordinary test filter. A rung export must name a
/// synthetic source (repository `synthetic/...`); a TinyLlama export must
/// name THE pinned checkpoint.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Geometry {
    /// ROUND 3 (R3-2): the trained TinyLlama geometry at a registered
    /// context length (32, 64 or 128), each its own profile
    TinyLlama(usize),
    /// ROUND 4 (R4-1): Llama-3-8B at T = 32
    Llama3_8B,
    RungTcDev,
}

impl Geometry {
    fn parse(s: &str) -> Result<Geometry, String> {
        match s {
            "tinyllama-1.1b-t32" => Ok(Geometry::TinyLlama(32)),
            "tinyllama-1.1b-t64" => Ok(Geometry::TinyLlama(64)),
            "tinyllama-1.1b-t128" => Ok(Geometry::TinyLlama(128)),
            "llama-3-8b-t32" => Ok(Geometry::Llama3_8B),
            "rung-tc-t32-dev" => Ok(Geometry::RungTcDev),
            _ => Err(format!("geometry `{s}` is not one of tinyllama-1.1b-t32 / -t64 / -t128 / llama-3-8b-t32 / rung-tc-t32-dev")),
        }
    }
    /// the context length the geometry fixes
    pub(crate) fn tokens(self) -> usize {
        match self {
            Geometry::TinyLlama(t) => t,
            Geometry::Llama3_8B | Geometry::RungTcDev => 32,
        }
    }
    /// the RoPE base the geometry's model fixes (pinned per profile)
    pub(crate) fn rope_theta(self) -> f64 {
        match self {
            Geometry::Llama3_8B => super::shape::LLAMA3_8B_ROPE_THETA,
            _ => super::shape::TRAINED_ROPE_THETA,
        }
    }
    pub(crate) fn run_profile(self) -> &'static str {
        match self {
            Geometry::TinyLlama(64) => super::run::RUN_PROFILE_TINYLLAMA_T64_TRAINED,
            Geometry::TinyLlama(128) => super::run::RUN_PROFILE_TINYLLAMA_T128_TRAINED,
            Geometry::TinyLlama(_) => RUN_PROFILE_TINYLLAMA_T32_TRAINED,
            Geometry::Llama3_8B => super::run::RUN_PROFILE_LLAMA3_8B_T32_TRAINED,
            Geometry::RungTcDev => RUN_PROFILE_RUNG_TC,
        }
    }
    pub(crate) fn run_shape(self, sh: &Shape, l: usize) -> Result<RunShape, String> {
        match self {
            Geometry::TinyLlama(_) | Geometry::Llama3_8B => RunShape::tinyllama_trained(sh.clone(), l),
            Geometry::RungTcDev => RunShape::rung_tc(sh.clone(), l),
        }
    }
    /// the shape at a calibration (the controls rebuild it at other ones)
    pub(crate) fn scope(self) -> &'static str {
        match self {
            Geometry::TinyLlama(_) => SCOPE,
            Geometry::Llama3_8B => SCOPE_8B,
            Geometry::RungTcDev => SCOPE_RUNG,
        }
    }
    pub(crate) fn shape_at(self, cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        match self {
            Geometry::TinyLlama(t) => Shape::tinyllama_trained(t, cal, f_e),
            Geometry::Llama3_8B => Shape::llama3_8b_t32_trained(cal, f_e),
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
    /// the profile's RUN-LEVEL constants when every one of them is uniform
    /// across the layers (the per-block table keys may still be per layer);
    /// `None` when the writer marks a run-level one per-layer (`null` in
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
        // ROUND 3 (R3-2): the context length decides the TinyLlama profile.
        // An export that names no geometry (the B4 writer) is the TinyLlama
        // geometry at its own `T`; one that names a geometry must name the
        // one its `T` is
        let tokens = usize::try_from(p.get_any(&["T", "tokens"]).and_then(J::i64).map_err(ctx)?).map_err(|_| ctx("T is negative".into()))?;
        // ROUND 4: an export naming no geometry is the geometry of its
        // MODEL (the pinned Llama-3-8B repository -> Llama-3-8B; otherwise
        // TinyLlama) at its `T`
        let m = p.get("model").map_err(ctx)?;
        let repo = m.get("repo").and_then(J::str).map_err(ctx)?;
        let llama_pin = ModelSource::llama3_8b();
        let geometry = match p.opt("geometry") {
            None if repo == llama_pin.repo => Geometry::Llama3_8B,
            None => match tokens {
                32 | 64 | 128 => Geometry::TinyLlama(tokens),
                _ => return Err(ctx(format!("T = {tokens}: no trained TinyLlama profile is registered at this context length (32, 64 and 128 are)"))),
            },
            Some(g) => Geometry::parse(g.str().map_err(ctx)?).map_err(ctx)?,
        };
        if geometry.tokens() != tokens {
            return Err(ctx(format!("the geometry fixes T = {}, the profile declares T = {tokens}", geometry.tokens())));
        }
        // the model pin: THE pinned source for TinyLlama, a synthetic recipe
        // for the development rung
        let pin = ModelSource::tinyllama_chat_v1_0();
        let rev = m.get("revision").and_then(J::str).map_err(ctx)?;
        // the weights digest: one file's SHA-256 (`sha256`), or, for a sharded
        // checkpoint, the canonical digest of its shard list
        // (`shards_sha256`: `name hex\n` per shard in name order)
        let msha = match (m.opt("sha256"), m.opt("shards_sha256")) {
            (Some(h), None) => unhex32(h.str().map_err(ctx)?).map_err(ctx)?,
            (None, Some(sh)) => {
                let mut v: Vec<(String, String)> = Vec::new();
                for (name, h) in sh.obj().map_err(ctx)? {
                    let h = h.str().map_err(ctx)?;
                    unhex32(h).map_err(ctx)?;
                    v.push((name.clone(), h.to_string()));
                }
                let r: Vec<(&str, &str)> = v.iter().map(|(a, b)| (a.as_str(), b.as_str())).collect();
                super::trained_statement::shards_digest(&r)
            }
            _ => return Err(ctx("model: exactly one of `sha256` / `shards_sha256` is required".into())),
        };
        let source = match geometry {
            Geometry::Llama3_8B => {
                if repo != llama_pin.repo || rev != llama_pin.revision || msha != llama_pin.weights_sha256 {
                    return Err(ctx(format!("the model pin ({repo}, {rev}, {}) is not the pinned Llama-3-8B source ({}, {}, {})", hex(&msha), llama_pin.repo, llama_pin.revision, hex(&llama_pin.weights_sha256))));
                }
                llama_pin
            }
            Geometry::TinyLlama(_) => {
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
        let constants = if nulls.iter().all(|k| !RUN_LEVEL_KEYS.contains(&k.as_str())) { Some(constants_of(pc, &path.display().to_string(), geometry.rope_theta())?) } else { None };
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
        // ROUND 2: a Hadamard-rotated export names its rotation's sign vector
        // by SHA-256; the file beside profile.json must be that file (public
        // weight preparation only, bound through the profile digest)
        if let Some(rot) = p.opt("metadata_out_of_proof").and_then(|m| m.opt("rotation")) {
            if *rot != J::Null {
                let want = unhex32(rot.get("sign_sha256").and_then(J::str).map_err(ctx)?).map_err(ctx)?;
                let sp = dir.join("rotation_sign.bin");
                let got = sha256(&read_bounded(&sp, 1 << 20)?);
                if got != want {
                    return Err(ctx(format!("rotation_sign.bin SHA-256 {} is not the profile's {}", hex(&got), hex(&want))));
                }
            }
        }
        let calibration_set_sha256 = match p.opt("calibration_set_sha256") {
            Some(v) => unhex32(v.str().map_err(ctx)?).map_err(ctx)?,
            None => [0; 32],
        };
        // review finding F-4: the variant is the PROFILE's own name for
        // itself, not the local directory's (renaming or copying an export
        // must not change any identity it proves under)
        let variant = p.get("variant").and_then(J::str).map_err(ctx)?.to_string();
        plain_name(&variant).map_err(|e| ctx(format!("variant: {e}")))?;
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
            let c = constants_of(m.get("constants").map_err(|e| format!("{}: {e}", mpath.display()))?, &mpath.display().to_string(), self.geometry.rope_theta())?;
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

    /// The trained shape of a run with these constants, at the export's T
    /// (round 3: 32, 64 or 128 for TinyLlama, each its own profile).
    pub(crate) fn shape_for(&self, c: &Constants) -> Result<Shape, String> {
        if self.tokens != self.geometry.tokens() {
            return Err(format!("trained export: T = {} is not the geometry's {}", self.tokens, self.geometry.tokens()));
        }
        // review finding F-1, mirrored before any shape is built
        Shape::check_f_e_class(self.tokens, c.f_e)?;
        let sh = self.geometry.shape_at(&c.cal, c.f_e)?;
        sh.check_trained_class()?;
        Ok(sh)
    }

    fn layer_dir(&self, index: u32) -> PathBuf {
        self.dir.join(format!("layer_{index:02}"))
    }

    /// Load one layer: every array verified, the tables cross-checked, the
    /// words padded per the shape (ruling P-2) into the public statement.
    pub(crate) fn load_layer(&self, sh: &Shape, c: &Constants, index: u32, rope_from_export: bool) -> Result<TrainedLayer, String> {
        self.load_layer_mode(sh, c, index, rope_from_export, true)
    }

    /// **ROUND 5 (R5-2): the proving-pass RELOAD.** The same block built by
    /// the same code as [`TrainedExport::load_layer`], with the per-array
    /// SHA-256s and the layer record (the padded-word SHA-256s) skipped; the
    /// caller refuses it unless its digest is the digest pass's.
    pub(crate) fn reload_block(&self, sh: &Shape, c: &Constants, index: u32, rope_from_export: bool) -> Result<BlockPublic, String> {
        Ok(self.load_layer_mode(sh, c, index, rope_from_export, false)?.blk)
    }

    fn load_layer_mode(&self, sh: &Shape, c: &Constants, index: u32, rope_from_export: bool, full: bool) -> Result<TrainedLayer, String> {
        let dir = self.layer_dir(index);
        let (mpath, mbytes, m) = self.manifest(index)?;
        let ctx = |e: String| format!("{}: {e}", mpath.display());
        let mi = m.get_any(&["layer", "index"]).and_then(J::i64).map_err(ctx)?;
        if mi != i64::from(index) {
            return Err(ctx(format!("the manifest is for layer {mi}, not {index}")));
        }
        let lc = constants_of(m.get("constants").map_err(ctx)?, &mpath.display().to_string(), self.geometry.rope_theta())?;
        if lc != *c {
            return Err(ctx("this layer's constants are not the run's (one calibration per run)".into()));
        }
        // the per-block table keys: this layer's own
        let tk = table_keys_of(m.get("constants").map_err(ctx)?, &mpath.display().to_string())?;
        if sh.norm_calibration() != c.cal || sh.f_e != c.f_e {
            return Err(ctx("the shape was not built from the run's constants".into()));
        }
        let arrays = m.get("arrays").map_err(ctx)?;
        // ROUND 5 (R5-2): the eleven arrays read and hashed IN PARALLEL (the
        // same bytes, the same digests, the same checks)
        let names = ["wq", "wk", "wv", "wo", "gamma_a", "gamma_m", "wg_t", "wu_t", "wd_t", "exp", "act"];
        let mut loaded: std::collections::VecDeque<Result<Array, String>> = {
            use rayon::prelude::*;
            names.par_iter().map(|name| load_array_checked(&dir, name, arrays.get(name).map_err(ctx)?, full)).collect::<Vec<_>>().into()
        };
        let mut get = |_name: &str| -> Result<Array, String> { loaded.pop_front().expect("one result per name") };
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
        let (gexp, _) = crate::tables_attn::exp_member(tk.exp_e_s, sh.head_dim, c.f_e);
        if exp.i64s() != gexp.to_vec() {
            return Err(ctx(format!("the exported exp table is not exp_member(e_s = {}, head_dim = {}, f_e = {})", tk.exp_e_s, sh.head_dim, c.f_e)));
        }
        let (gact, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, tk.silu.0, tk.silu.1).ok_or_else(|| ctx(format!("silu_member {:?} is not in the frozen SiLU registry", tk.silu)))?;
        if act.i16s() != gact.to_vec() {
            return Err(ctx(format!("the exported act table is not the frozen SiLU member {:?}", tk.silu)));
        }
        let (gcos, gsin) = crate::tables_attn::rope_tables_generate(sh.tokens, sh.head_dim, c.rope_theta, F_RO);
        let exported = match (arrays.opt("rope_cos").or_else(|| arrays.opt("cos")), arrays.opt("rope_sin").or_else(|| arrays.opt("sin"))) {
            (Some(cs), Some(ss)) => {
                let (ca, sa) = (load_array_checked(&dir, "rope_cos", cs, full)?, load_array_checked(&dir, "rope_sin", ss, full)?);
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
        let mut record = if full { LayerRecord::of_block(index, &blk, source_tensors) } else { LayerRecord::unhashed(index) };
        let manifest_sha256 = sha256(&mbytes);
        record.manifest_sha256 = manifest_sha256;
        record.silu_member = tk.silu;
        record.exp_e_s = tk.exp_e_s;
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
        self.statement_of_records(sh, c, layers.iter().map(|l| l.record.clone()).collect())
    }

    /// the same statement from the layer RECORDS alone (the stack keeps its
    /// blocks once and its records beside them)
    pub(crate) fn statement_of_records(&self, sh: &Shape, c: &Constants, records: Vec<LayerRecord>) -> Result<TrainedModelStatement, String> {
        let prov = Provenance {
            label: format!("export:{}", self.variant),
            residual_unit: self.residual_unit,
            quantizer_sha256: self.tool_sha256,
            calibration_set_sha256: self.calibration_set_sha256,
            export_profile_sha256: self.profile_sha256,
            calibration_tool_sha256: self.tool_sha256,
            rope_theta: c.rope_theta,
        };
        let cal = IntegerCalibration::as_the_code_proves(sh, &prov);
        TrainedModelStatement::new(sh, self.geometry.run_profile(), self.source.clone(), cal, records)
    }
}

/// a true `(to, ti)` row-major matrix placed into the padded `(po, pi)` one
/// through the two index maps (ruling P-2; the same map as the driver's)
fn pad_matrix(w: &[i8], to: usize, ti: usize, po: usize, pi: usize, omap: &(dyn Fn(usize) -> usize + Sync), imap: &(dyn Fn(usize) -> usize + Sync)) -> Vec<i8> {
    // ROUND 5 (R5-2): the same placement, made row by row in PARALLEL over
    // the destination rows, with a straight row copy where the inner map is
    // the identity (every map here is injective; the pad stays zero)
    use rayon::prelude::*;
    let mut out = vec![0i8; po * pi];
    let mut src_of: Vec<Option<usize>> = vec![None; po];
    for o in 0..to {
        src_of[omap(o)] = Some(o);
    }
    let inner: Vec<usize> = (0..ti).map(imap).collect();
    let identity = inner.iter().enumerate().all(|(i, j)| i == *j);
    out.par_chunks_mut(pi).enumerate().for_each(|(r, row)| {
        let Some(o) = src_of[r] else { return };
        let src = &w[o * ti..(o + 1) * ti];
        if identity {
            row[..ti].copy_from_slice(src);
        } else {
            for (i, v) in src.iter().enumerate() {
                row[inner[i]] = *v;
            }
        }
    });
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
    let seg = read_bounded(&art.join("segment-000.bin"), super::wire::wire_ceiling(&sh) as u64)?;
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

/// a shift moved by one, staying inside its window `lo..=hi`
fn nudge(v: u32, lo: u32, hi: u32) -> u32 {
    if v < hi {
        v + 1
    } else {
        debug_assert!(v > lo);
        v - 1
    }
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
        ("verifier statement with sh_ao moved by one", NormCalibration { sh_ao: if c.sh_ao < 8 { c.sh_ao + 1 } else { c.sh_ao - 1 }, ..c }),
        // ROUND 2: each windowed shift moved by one, inside its window
        ("verifier statement with sh_qkv moved by one", NormCalibration { sh_qkv: nudge(c.sh_qkv, 1, 8), ..c }),
        ("verifier statement with sh_s moved by one", NormCalibration { sh_s: nudge(c.sh_s, 1, 8), ..c }),
        ("verifier statement with sh_o moved by one", NormCalibration { sh_o: nudge(c.sh_o, 9, 16), ..c }),
        ("verifier statement with sh_g moved by one", NormCalibration { sh_g: nudge(c.sh_g, 1, 8), ..c }),
        ("verifier statement with sh_h moved by one", NormCalibration { sh_h: nudge(c.sh_h, 9, 16), ..c }),
        ("verifier statement with sh_z moved by one", NormCalibration { sh_z: nudge(c.sh_z, 1, 8), ..c }),
    ] {
        let r = (|| -> Result<(), String> {
            let s2 = ex.geometry.shape_at(&v, rc.f_e)?;
            let mut l2 = TrainedLayer { index: layer.index, manifest_sha256: layer.manifest_sha256, blk: layer.blk.clone(), record: layer.record.clone(), rope_note: String::new() };
            l2.record = {
                let mut r = LayerRecord::of_block(layer.index, &l2.blk, layer.record.source_tensors.clone());
                r.manifest_sha256 = layer.manifest_sha256;
                r.silu_member = layer.record.silu_member;
                r.exp_e_s = layer.record.exp_e_s;
                r
            };
            let st2 = ex.statement(&s2, &Constants { cal: v, ..rc.clone() }, &[&l2])?;
            let e2 = ExpectedIo::from_bytes_at(&s2, &expected.to_bytes())?;
            let r2 = RunStatement::new_bound(ex.geometry.run_shape(&s2, 1)?, ctx, e2, &blocks, &[(0, 0)], &st2)?;
            run::verify_run(&r2, &blocks, &[seg.to_vec()])
        })();
        refuse(name, r)?;
    }
    // (1b) review finding F-1: the softmax exp precision moved by one, inside
    //      its declared class
    {
        let fe2 = nudge(rc.f_e, *super::shape::TRAINED_F_E_RANGE.start(), *super::shape::TRAINED_F_E_RANGE.end());
        let r = (|| -> Result<(), String> {
            let s2 = ex.geometry.shape_at(&c, fe2)?;
            let st2 = ex.statement(&s2, &Constants { f_e: fe2, ..rc.clone() }, &[layer])?;
            let e2 = ExpectedIo::from_bytes_at(&s2, &expected.to_bytes())?;
            let r2 = RunStatement::new_bound(ex.geometry.run_shape(&s2, 1)?, ctx, e2, &blocks, &[(0, 0)], &st2)?;
            run::verify_run(&r2, &blocks, &[seg.to_vec()])
        })();
        refuse("verifier statement with f_e moved by one", r)?;
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
        rec2.silu_member = layer.record.silu_member;
        rec2.exp_e_s = layer.record.exp_e_s;
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

// ================================================================== THE STACK
//
// ROUND 2, R2-3: ALL the export's blocks as ONE bound run — one transcript,
// block k's hidden output is block k+1's hidden input through an internal
// boundary commitment (`boundary.rs`), each boundary claimed by block k's
// output-equality slot and block k+1's input-equality slot. The run statement
// binds the trained-model statement (every layer's block digest, manifest
// digest and table members; the export profile and tool digests; the one
// calibration) as its `"calibration"` word.

/// **THE STACK'S STREAMING SOURCE.** Retains ONE current input and at most
/// ONE witness (between `boundary_plane(k)` and `witness(k)`), exactly as the
/// MVP driver's source does. `lie_at` (a control only) adds one to one word of
/// the boundary plane handed out after block `lie_at`, so the boundary
/// commitment no longer holds block `lie_at`'s output.
struct StackSource<'a> {
    sh: &'a Shape,
    /// ROUND 4: the shared one-block cache (and the run's block count)
    blocks: SharedCache<'a>,
    n: usize,
    ids: Ids,
    x: Vec<i16>,
    next: usize,
    cached: Option<(usize, Witness)>,
    lie_at: Option<usize>,
    busy_s: f64,
    /// ROUND 3 (R3-1): the export's checks, made AS EACH WITNESS IS BUILT
    /// (one witness pass instead of a sealing pass and a proving pass)
    parity: Option<StackParity>,
}

/// **R3-1: parity inside the proving pass.** Layer k's native output must
/// equal the export's `x_out` of that layer bit for bit before block k is
/// proved; the committed endpoints (taken from the export) must be the first
/// witness's input plane and the last witness's output plane. A failure
/// aborts the run before that block's segment exists.
struct StackParity {
    layers: Vec<u32>,
    x_outs: Vec<Vec<i16>>,
    first: Vec<i16>,
    last: Vec<i16>,
    checked: usize,
}

/// **ROUND 4 (R4-3): the stack's public blocks, ONE resident at a time.**
/// Block k is reloaded from the export when first asked for (every array
/// SHA-256-checked against its manifest, the tables against their generator
/// members, exactly as the digest pass loaded it) and refused unless its
/// digest is the statement's; the witness source and the prover share the
/// one cache, so each block is loaded once per pass. `order` maps a run
/// position to a layer position (the swapped-block controls).
struct BlockCache<'a> {
    ex: &'a TrainedExport,
    sh: &'a Shape,
    c: &'a Constants,
    layers: Vec<u32>,
    digests: Vec<Digest>,
    rope_from_export: bool,
    cur: Option<(usize, std::sync::Arc<BlockPublic>)>,
    loads: usize,
    load_s: f64,
}

type SharedCache<'a> = std::rc::Rc<std::cell::RefCell<BlockCache<'a>>>;

impl<'a> BlockCache<'a> {
    fn shared(ex: &'a TrainedExport, sh: &'a Shape, c: &'a Constants, layers: Vec<u32>, digests: Vec<Digest>, rope_from_export: bool) -> SharedCache<'a> {
        std::rc::Rc::new(std::cell::RefCell::new(BlockCache { ex, sh, c, layers, digests, rope_from_export, cur: None, loads: 0, load_s: 0.0 }))
    }
    fn get(&mut self, k: usize) -> Result<std::sync::Arc<BlockPublic>, String> {
        if let Some((j, a)) = &self.cur {
            if *j == k {
                return Ok(a.clone());
            }
        }
        if k >= self.layers.len() {
            return Err(format!("trained stack: no block {k} in a {}-block run", self.layers.len()));
        }
        // drop the previous block BEFORE the next one is read
        self.cur = None;
        let t = Instant::now();
        // ROUND 5 (R5-2): the reload skips the per-array and padded-word
        // SHA-256s; the digest of the block it built — the bytes about to be
        // proved — must be the digest pass's
        let blk = self.ex.reload_block(self.sh, self.c, self.layers[k], self.rope_from_export)?;
        if blk.digest() != self.digests[k] {
            return Err(format!("trained stack: layer {}'s reloaded public statement is not the one the run statement binds", self.layers[k]));
        }
        let a = std::sync::Arc::new(blk);
        self.cur = Some((k, a.clone()));
        self.loads += 1;
        self.load_s += t.elapsed().as_secs_f64();
        Ok(a)
    }
}

/// the cache as the run prover's / verifier's block source
struct CacheBlocks<'a>(SharedCache<'a>);

impl run::BlockSource for CacheBlocks<'_> {
    fn block(&mut self, k: usize) -> Result<run::BlockRef<'_>, String> {
        let a = self.0.borrow_mut().get(k)?;
        Ok(run::BlockRef::Shared(a))
    }
    fn count(&self) -> usize {
        self.0.borrow().layers.len()
    }
    /// RULINGS CS-1 / CS-4 for a STREAMING source: each block is built by
    /// the loader through `new_shaped` at the run's shape (the constructor's
    /// one check), and `prove_core` / `verify_core` re-run the check on it
    /// before its stage commits or absorbs anything of it; the cache was
    /// built for this shape, which is compared here.
    fn fit_the_shape(&mut self, sh: &Shape) -> Result<(), String> {
        let c = self.0.borrow();
        if c.sh != sh {
            return Err(format!("private run: the block cache was built for the shape {:?}, the run's is {:?}", c.sh.name, sh.name));
        }
        Ok(())
    }
    /// RULING CS-6 for a STREAMING source: the digest list the cache enforces
    /// on every load (a reloaded block whose digest is not its entry is
    /// refused) is the statement's, entry for entry
    fn are_the_statements(&mut self, st: &RunStatement) -> Result<(), String> {
        let c = self.0.borrow();
        let want = st.block_digests();
        if c.digests.len() != want.len() {
            return Err(format!("private run: ruling CS-6 — the run statement holds {} block digests and {} blocks were handed", want.len(), c.digests.len()));
        }
        for (k, (got, w)) in c.digests.iter().zip(want).enumerate() {
            run::digest_is_the_statements(k, got, w)?;
        }
        Ok(())
    }
}

impl<'a> StackSource<'a> {
    fn new(sh: &'a Shape, blocks: SharedCache<'a>, n: usize, x0: Vec<i16>, lie_at: Option<usize>) -> Result<StackSource<'a>, String> {
        if x0.len() != sh.tokens * sh.width {
            return Err("trained stack: the first input is not tokens x width".into());
        }
        Ok(StackSource { sh, blocks, n, ids: Ids::new(sh)?, x: x0, next: 0, cached: None, lie_at, busy_s: 0.0, parity: None })
    }
    fn advance(&mut self, k: usize) -> Result<(Witness, Vec<i16>), String> {
        if k != self.next || k >= self.n {
            return Err(format!("trained stack: block {k} was asked for out of order (next is {})", self.next));
        }
        let blk = self.blocks.borrow_mut().get(k)?;
        let t = Instant::now();
        let w = witness::build_shaped(self.sh, blk.attention(), blk.feed_forward(), &self.x)?;
        drop(blk);
        let out = padded_plane(&w, self.ids.at(A_X2))?;
        self.x = true_words(self.sh, &out);
        self.next = k + 1;
        if let Some(p) = self.parity.as_mut() {
            let layer = p.layers[k];
            if k == 0 && padded_plane(&w, self.ids.at(A_X))? != p.first {
                return Err(format!("trained stack: the committed input endpoint is not block 0's input plane (layer {layer})"));
            }
            let n = self.x.iter().zip(p.x_outs[k].iter()).filter(|(a, b)| a != b).count();
            if n != 0 {
                let q = self.x.iter().zip(p.x_outs[k].iter()).position(|(a, b)| a != b).unwrap_or(0);
                return Err(format!("parity: layer {layer}'s native output differs from the export's x_out in {n} words (first at token {}, channel {}); no value is printed", q / self.sh.width, q % self.sh.width));
            }
            if k + 1 == p.x_outs.len() && out != p.last {
                return Err(format!("trained stack: the committed output endpoint is not the last block's output plane (layer {layer})"));
            }
            p.checked += 1;
        }
        self.busy_s += t.elapsed().as_secs_f64();
        Ok((w, out))
    }
}

/// the true `[T, d]` words of a padded `Dom::D` plane
fn true_words(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// the padded `Dom::D` plane of true `[T, d]` words (zero on the pad): the
/// inverse of [`true_words`], and what `padded_plane(witness, A_X / A_X2)`
/// holds for an honest witness (asserted per run on the first and last block)
fn pad_d_plane(sh: &Shape, words: &[i16]) -> Result<Vec<i16>, String> {
    if words.len() != sh.tokens * sh.width {
        return Err("trained stack: an endpoint is not tokens x width".into());
    }
    let mut v = vec![0i16; sh.size(super::layout::Dom::D)];
    for t in 0..sh.tokens {
        v[t * sh.d_pad..t * sh.d_pad + sh.width].copy_from_slice(&words[t * sh.width..(t + 1) * sh.width]);
    }
    Ok(v)
}

impl RunWitnessSource for StackSource<'_> {
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        if self.cached.is_some() {
            return Err("trained stack: a witness is still cached".into());
        }
        let (w, mut out) = self.advance(k)?;
        self.cached = Some((k, w));
        if self.lie_at == Some(k) {
            let i = self.sh.d_pad + 3;
            out[i] = out[i].wrapping_add(1);
        }
        Ok(out)
    }
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        match self.cached.take() {
            Some((j, w)) if j == k => Ok(w),
            Some(_) => Err("trained stack: the cached witness is for another block".into()),
            None => self.advance(k).map(|(w, _)| w),
        }
    }
}

fn parse_layers(spec: Option<&str>, all: &[u32]) -> Result<Vec<u32>, String> {
    match spec {
        None => Ok(all.to_vec()),
        Some(s) => {
            let (a, b) = s.split_once("..").ok_or("--layers is A..B (B exclusive)")?;
            let (a, b): (u32, u32) = (a.parse().map_err(|_| "--layers: A is not an integer")?, b.parse().map_err(|_| "--layers: B is not an integer")?);
            if a >= b {
                return Err("--layers: an empty range".into());
            }
            let v: Vec<u32> = (a..b).collect();
            if let Some(m) = v.iter().find(|l| !all.contains(l)) {
                return Err(format!("--layers: layer {m} is not in the export"));
            }
            Ok(v)
        }
    }
}

fn stack_context(variant: &str, layers: &[u32], label: &str) -> Digest {
    let mut b = Vec::new();
    for s in ["hashline/zk60-trained-stack-context/1", variant, label] {
        b.extend_from_slice(&(s.len() as u64).to_le_bytes());
        b.extend_from_slice(s.as_bytes());
    }
    for l in layers {
        b.extend_from_slice(&u64::from(*l).to_le_bytes());
    }
    *blake3::hash(&b).as_bytes()
}

/// one loaded layer's public record, the block itself moved out (22 padded
/// TinyLlama blocks are about 1.25 GB; the stack holds them ONCE)
struct LayerMeta {
    index: u32,
    manifest_sha256: [u8; 32],
    record: LayerRecord,
}

/// **THE DIGEST PASS (ROUND 4).** The export's public side for a run over
/// `layers`: the run constants, the shape, every layer's record and block
/// digest (each block loaded, digested and DROPPED: one resident at a time),
/// and the trained-model statement. The blocks are reloaded one at a time by
/// [`BlockCache`] when they are proved or verified.
#[allow(clippy::type_complexity)]
fn stack_records(ex: &TrainedExport, layers: &[u32], rope_from_export: bool) -> Result<(Constants, Shape, Vec<LayerMeta>, Vec<Digest>, TrainedModelStatement), String> {
    let c = ex.run_constants(layers)?;
    let sh = ex.shape_for(&c)?;
    let mut metas = Vec::with_capacity(layers.len());
    let mut digests = Vec::with_capacity(layers.len());
    // ROUND 5 (R5-2): the digest pass loads DIGEST_PASS_WIDTH layers at a
    // time, in parallel — the same loads and the same checks, the records and
    // digests kept in layer order, and the first error IN LAYER ORDER is the
    // one returned (what the sequential loop returned). Two at a time keeps
    // the pass's transient memory at about two layers' (about 2 GiB at 8B).
    const DIGEST_PASS_WIDTH: usize = 2;
    for chunk in layers.chunks(DIGEST_PASS_WIDTH) {
        let loaded: Vec<Result<TrainedLayer, String>> = {
            use rayon::prelude::*;
            chunk.par_iter().map(|&l| ex.load_layer(&sh, &c, l, rope_from_export)).collect()
        };
        for t in loaded {
            let t = t?;
            // the record already holds the block's digest (one blake3 pass)
            digests.push(t.record.block_digest);
            metas.push(LayerMeta { index: t.index, manifest_sha256: t.manifest_sha256, record: t.record });
        }
    }
    let st = ex.statement_of_records(&sh, &c, metas.iter().map(|m| m.record.clone()).collect())?;
    Ok((c, sh, metas, digests, st))
}

fn render_stack_statement(ex: &TrainedExport, sh: &Shape, layers: &[LayerMeta], st: &TrainedModelStatement, ctx: &Digest, expected: &ExpectedIo, label: &str) -> String {
    let c = sh.norm_calibration();
    let recs: Vec<String> = layers
        .iter()
        .map(|l| format!("{{\"layer\": {}, \"block_digest\": {}, \"manifest_sha256\": {}, \"silu_member\": [{}, {}], \"exp_e_s\": {}}}", l.index, js(&hex(&l.record.block_digest)), js(&hex(&l.manifest_sha256)), l.record.silu_member.0, l.record.silu_member.1, l.record.exp_e_s))
        .collect();
    format!(
        "{{\n \"schema\": \"zk60-trained-stack-run/1\",\n \"scope\": {},\n \"block_profile\": {},\n \"run_profile\": {},\n \"blocks\": {},\n \"export_variant\": {},\n \"export_profile_sha256\": {},\n \"calibration_tool_sha256\": {},\n \"trained_statement_identity\": {},\n \"context_label\": {},\n \"context\": {},\n \"expected_io\": {},\n \"layers\": [\n  {}\n ],\n \"shape\": {{\"tokens\": {}, \"width\": {}, \"hidden\": {}, \"q_heads\": {}, \"kv_heads\": {}, \"head_dim\": {}, \"log_cols\": {}, \"inv_rate\": {}, \"opened_cols\": {}, \"f_e\": {}, \"wrho_s\": {}, \"norm_wrho\": {}, \"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_ao\": {}, \"sh_qkv\": {}, \"sh_s\": {}, \"sh_o\": {}, \"sh_g\": {}, \"sh_h\": {}, \"sh_z\": {}, \"d_max\": {}}}\n}}\n",
        js(STACK_SCOPE),
        js(sh.profile),
        js(ex.geometry.run_profile()),
        layers.len(),
        js(&ex.variant),
        js(&hex(&ex.profile_sha256)),
        js(&hex(&ex.tool_sha256)),
        js(&hex(&st.identity())),
        js(label),
        js(&hex(ctx)),
        js(&hex(&expected.to_bytes())),
        recs.join(",\n  "),
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
        c.sh_qkv,
        c.sh_s,
        c.sh_o,
        c.sh_g,
        c.sh_h,
        c.sh_z,
        sh.d_max
    )
}

const STACK_SCOPE: &str = "ALL the listed trained blocks of the export's model (TinyLlama-1.1B-Chat or Llama-3-8B) as ONE bound run at the export's T (one transcript, hidden internal boundaries); embedding, final norm, LM head and token selection are NOT covered (D13); CPU unless the run line says gpu; NO privacy acceptance at this shape (D22 covers only the toy); float fidelity is the calibration lane's measurement";

/// `stack-prove --export DIR --seq ID --out DIR [--layers A..B] [--label L]
/// [--rope-from-export] [--lie-at-boundary K]`
///
/// The SEALING pass builds every block's witness once (one resident at a
/// time), checks each layer's output against the export's `x_out` bit for bit
/// and the chain (block k's output IS block k+1's input by construction), and
/// yields the two external endpoint planes; the endpoints are committed; the
/// run statement is bound to the trained-model statement; the PROVING pass
/// rebuilds the witnesses one at a time and `run::prove_run` writes one
/// segment per block into `--out` (a NEW directory); the run is verified in
/// process from the directory; the public statement goes into
/// `<out>/statement/`. `--lie-at-boundary K` is a CONTROL: the boundary
/// plane after block K is off by one word, and the run must then FAIL to
/// verify (exit 0 means the control behaved).
pub fn trained_stack_prove_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--seq", "--out", "--layers", "--label", "--lie-at-boundary"], &["--rope-from-export", "--verify-in-process"]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_trained_block stack-prove: {e}");
            return 2;
        }
    };
    match stack_prove_inner(&f) {
        Ok(()) => 0,
        Err(e) => {
            println!("{{\"event\":\"refused\",\"error\":{}}}", js(&e));
            1
        }
    }
}

fn stack_prove_inner(f: &[(String, String)]) -> Result<(), String> {
    let t_total = Instant::now();
    let export = PathBuf::from(need(f, "--export")?);
    let seq = need(f, "--seq")?;
    let out = PathBuf::from(need(f, "--out")?);
    let label = flag(f, "--label").unwrap_or("zk60-trained-stack");
    let lie_at: Option<usize> = match flag(f, "--lie-at-boundary") {
        Some(v) => Some(v.parse().map_err(|_| "--lie-at-boundary is not an integer")?),
        None => None,
    };
    if out.exists() {
        return Err(format!("{} exists; the run directory must be new", out.display()));
    }
    // ROUND 2 (R2-5): a claimed GPU run refuses to start unless the device
    // path is live, and any later decline aborts it (`gpu::declined`)
    crate::gpu::require_live()?;
    println!("{{\"event\":\"run_header\",\"gpu\":{},\"hl_gpu_required\":{}}}", js(&crate::gpu::label()), crate::gpu::required());
    let t = Instant::now();
    let ex = TrainedExport::load(&export)?;
    let layers = parse_layers(flag(f, "--layers"), &ex.layers)?;
    let l = layers.len();
    if let Some(k) = lie_at {
        if k + 1 >= l {
            return Err("--lie-at-boundary: there is no boundary after the last block".into());
        }
    }
    let rope = flag(f, "--rope-from-export").is_some();
    let (c, sh, loaded, digests, st) = stack_records(&ex, &layers, rope)?;
    let load_s = t.elapsed().as_secs_f64();
    println!(
        "{{\"event\":\"loaded\",\"variant\":{},\"layers\":\"{}..{}\",\"blocks\":{l},\"statement_identity\":{},\"seconds\":{load_s:.3},\"hl_gpu\":{},\"scope\":{}}}",
        js(&ex.variant),
        layers[0],
        layers[l - 1] + 1,
        js(&hex(&st.identity())),
        js(&std::env::var("HL_GPU").unwrap_or_else(|_| "unset".into())),
        js(STACK_SCOPE)
    );
    // ---- ROUND 3 (R3-1): ONE witness pass. The endpoints are sealed from
    //      the export's own words (layer 0's x_in, the last layer's x_out);
    //      every block's witness is then built ONCE, in the proving pass, and
    //      checked against the export's x_out of its layer (and the two
    //      endpoints against the first input / last output plane) BEFORE its
    //      segment is proved. Parity stays mandatory at every layer; a
    //      mismatch aborts the run and removes the run directory.
    let t = Instant::now();
    let (x_in0, _) = ex.load_seq(&sh, seq, layers[0])?;
    let mut x_outs = Vec::with_capacity(l);
    for &layer in &layers {
        x_outs.push(ex.load_seq(&sh, seq, layer)?.1);
    }
    let first = pad_d_plane(&sh, &x_in0)?;
    let last = pad_d_plane(&sh, &x_outs[l - 1])?;
    let cache = BlockCache::shared(&ex, &sh, &c, layers.clone(), digests.clone(), rope);
    let mut src = StackSource::new(&sh, cache.clone(), l, x_in0, lie_at)?;
    let seal_s = t.elapsed().as_secs_f64();
    println!(
        "{{\"event\":\"sealed\",\"from\":\"the export's layer-{} x_in and layer-{} x_out (parity is checked per layer in the proving pass)\",\"seconds\":{seal_s:.3},\"rayon_threads\":{}}}",
        layers[0],
        layers[l - 1],
        rayon::current_num_threads()
    );
    // ---- endpoints and the bound run statement
    let ctx = stack_context(&ex.variant, &layers, label);
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &first, &last)?;
    src.parity = Some(StackParity { layers: layers.clone(), x_outs, first, last, checked: 0 });
    let rst = RunStatement::new_bound_from_digests(ex.geometry.run_shape(&sh, l)?, ctx, expected.clone(), digests.clone(), &vec![(0, 0); l], &st)?;
    // ---- the proving pass
    std::fs::create_dir(&out).map_err(|e| format!("{}: {e}", out.display()))?;
    let mut disk = super::run_sink::DirSink::create(&out, l)?;
    let t = Instant::now();
    let stats = {
        let mut sink = |k: usize, bytes: Vec<u8>| -> Result<(), String> {
            let n = bytes.len();
            super::run_sink::SegmentSink::accept(&mut disk, k, bytes)?;
            println!("{{\"event\":\"segment\",\"index\":{k},\"layer\":{},\"bytes\":{n},\"elapsed_seconds\":{:.3},\"vmhwm_mib\":{:.0}}}", layers[k], t.elapsed().as_secs_f64(), peak_rss_mib());
            Ok(())
        };
        run::prove_run_with(&rst, &mut CacheBlocks(cache.clone()), &mut src, owners, &mut sink)
    };
    let prove_s = t.elapsed().as_secs_f64();
    let witness_s = src.busy_s;
    let parity_layers = src.parity.as_ref().map(|p| p.checked).unwrap_or(0);
    drop(src);
    if let Err(e) = stats {
        // the run directory is this process's own, created above: a run
        // that did not complete leaves nothing a verifier could mistake
        let _ = std::fs::remove_dir_all(&out);
        return Err(format!("prove_run: {e}"));
    }
    if parity_layers != l {
        let _ = std::fs::remove_dir_all(&out);
        return Err(format!("trained stack: parity was checked at {parity_layers} of {l} layers"));
    }
    println!("{{\"event\":\"parity\",\"result\":\"bit-exact at every layer\",\"layers\":{l},\"words_per_layer\":{},\"checked_in_the_proving_pass\":true}}", sh.tokens * sh.width);
    let hwm = peak_rss_mib();
    let (block_loads, block_load_s) = {
        let cb = cache.borrow();
        (cb.loads, cb.load_s)
    };
    drop(cache);
    // ---- in-process verification from the directory (a fresh cache).
    //      ROUND 5 (R5-2): OFF by default — the fresh-process verify is the
    //      check; `--verify-in-process` turns it on, and the boundary-lie
    //      control always runs it (its verdict IS the control)
    let in_process = flag(f, "--verify-in-process").is_some() || lie_at.is_some();
    let t = Instant::now();
    let verdict = if in_process {
        let vcache = BlockCache::shared(&ex, &sh, &c, layers.clone(), digests.clone(), rope);
        run::verify_run_from_dir_with(&rst, &mut CacheBlocks(vcache), &out)
    } else {
        Ok(())
    };
    let verify_s = t.elapsed().as_secs_f64();
    if let Some(k) = lie_at {
        return match verdict {
            Ok(()) => Err(format!("CONTROL FAILED: a run whose boundary after block {k} was off by one word VERIFIED")),
            Err(e) => {
                println!("{{\"event\":\"control-refused\",\"control\":\"the boundary plane after block {k} off by one word\",\"error\":{}}}", js(&e.chars().take(200).collect::<String>()));
                Ok(())
            }
        };
    }
    verdict.map_err(|e| format!("in-process verification of the run directory: {e}"))?;
    let sdir = out.join(super::run_sink::STATEMENT_DIR);
    std::fs::create_dir(&sdir).map_err(|e| format!("{}: {e}", sdir.display()))?;
    write_new(&sdir.join("expected.bin"), &expected.to_bytes())?;
    write_new(&sdir.join("statement.json"), render_stack_statement(&ex, &sh, &loaded, &st, &ctx, &expected, label).as_bytes())?;
    let segs: Vec<String> = (0..l).map(|k| format!("{{\"file\":{},\"bytes\":{},\"sha256\":{}}}", js(&super::run_sink::segment_file_name(k)), disk.lengths()[k], js(&disk.digests()[k]))).collect();
    write_new(&sdir.join("segments.json"), format!("[\n {}\n]\n", segs.join(",\n ")).as_bytes())?;
    println!(
        "{{\"event\":\"proved\",\"gpu\":{},\"gpu_declines\":{},\"blocks\":{l},\"receipt_bytes\":{},\"prove_run_seconds\":{prove_s:.3},\"of_which_witness_seconds\":{witness_s:.3},\"witness_seconds_per_block\":{:.3},\"of_which_block_load_seconds\":{block_load_s:.3},\"block_loads\":{block_loads},\"rayon_threads\":{},\"in_process_verified\":{in_process},\"in_process_verify_seconds\":{verify_s:.3},\"sealing_pass_seconds\":{seal_s:.3},\"load_seconds\":{load_s:.3},\"total_seconds\":{:.3},\"vmhwm_mib\":{hwm:.0},\"statement_identity\":{},\"out\":{}}}",
        js(&crate::gpu::label()),
        crate::gpu::declines(),
        disk.total_bytes(),
        witness_s / l as f64,
        rayon::current_num_threads(),
        t_total.elapsed().as_secs_f64(),
        js(&hex(&st.identity())),
        js(&out.display().to_string())
    );
    Ok(())
}

/// `stack-verify --export DIR --artifact DIR --expect-statement HEX
/// [--layers A..B] [--label L] [--rope-from-export] [--controls]`
///
/// A FRESH process: rebuilds the shape, every block and the trained-model
/// statement from the export's PUBLIC files (never a `seq_*` directory),
/// refuses unless the statement identity equals the pin, reads the endpoint
/// policy from `<artifact>/statement/expected.bin`, and verifies the run
/// directory one segment at a time. `--controls` then runs the run-level
/// controls, each of which must REFUSE: a statement with two blocks swapped,
/// a statement with one calibration constant moved, a statement with another
/// export digest, one block fewer, a mutated segment, two segments swapped,
/// a truncated segment.
pub fn trained_stack_verify_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--artifact", "--expect-statement", "--layers", "--label"], &["--rope-from-export", "--controls"]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_trained_block stack-verify: {e}");
            return 2;
        }
    };
    match stack_verify_inner(&f) {
        Ok(()) => 0,
        Err(e) => {
            println!("{{\"event\":\"rejected\",\"error\":{}}}", js(&e));
            1
        }
    }
}

fn stack_verify_inner(f: &[(String, String)]) -> Result<(), String> {
    let export = PathBuf::from(need(f, "--export")?);
    let art = PathBuf::from(need(f, "--artifact")?);
    let pin = unhex32(need(f, "--expect-statement")?)?;
    let label = flag(f, "--label").unwrap_or("zk60-trained-stack");
    let t = Instant::now();
    let ex = TrainedExport::load(&export)?;
    let layers = parse_layers(flag(f, "--layers"), &ex.layers)?;
    let l = layers.len();
    let rope = flag(f, "--rope-from-export").is_some();
    let (c, sh, loaded, digests, st) = stack_records(&ex, &layers, rope)?;
    if st.identity() != pin {
        return Err(format!("the rebuilt trained statement {} is not the pinned {}", hex(&st.identity()), hex(&pin)));
    }
    let ctx = stack_context(&ex.variant, &layers, label);
    let expected = ExpectedIo::from_bytes_at(&sh, &read_bounded(&art.join(super::run_sink::STATEMENT_DIR).join("expected.bin"), 4096)?)?;
    if expected.to_bytes()[8..40] != ctx {
        return Err("the artifact's endpoint policy carries another context".into());
    }
    let rst = RunStatement::new_bound_from_digests(ex.geometry.run_shape(&sh, l)?, ctx, expected.clone(), digests.clone(), &vec![(0, 0); l], &st)?;
    let load_s = t.elapsed().as_secs_f64();
    let t = Instant::now();
    let vcache = BlockCache::shared(&ex, &sh, &c, layers.clone(), digests.clone(), rope);
    run::verify_run_from_dir_with(&rst, &mut CacheBlocks(vcache.clone()), &art)?;
    let verify_s = t.elapsed().as_secs_f64();
    let block_load_s = vcache.borrow().load_s;
    let total: u64 = super::run_sink::segment_paths(&art, l)?.iter().map(|p| std::fs::metadata(p).map(|m| m.len()).unwrap_or(0)).sum();
    println!(
        "{{\"event\":\"verified\",\"blocks\":{l},\"receipt_bytes\":{total},\"load_seconds\":{load_s:.3},\"verify_seconds\":{verify_s:.3},\"of_which_block_load_seconds\":{block_load_s:.3},\"vmhwm_mib\":{:.0},\"statement_identity\":{},\"scope\":{}}}",
        peak_rss_mib(),
        js(&hex(&st.identity())),
        js(STACK_SCOPE)
    );
    if flag(f, "--controls").is_some() {
        stack_controls(&ex, &c, &sh, &layers, &digests, rope, &loaded, &st, ctx, &expected, &art)?;
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn stack_controls(ex: &TrainedExport, rc: &Constants, sh: &Shape, layers: &[u32], digests: &[Digest], rope: bool, loaded: &[LayerMeta], st: &TrainedModelStatement, ctx: Digest, expected: &ExpectedIo, art: &Path) -> Result<(), String> {
    let l = layers.len();
    if l < 2 {
        return Err("trained stack: the run-level controls need at least two blocks".into());
    }
    let mut segs: Vec<Vec<u8>> = super::run_sink::segment_paths(art, l)?.iter().map(|p| std::fs::read(p).map_err(|e| e.to_string())).collect::<Result<_, _>>()?;
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
    // ROUND 4: every control verifies with ONE block resident; `order` is
    // the run position -> layer position map of the verifier's block list
    let cache_for = |order: &[usize]| BlockCache::shared(ex, sh, rc, order.iter().map(|&p| layers[p]).collect(), order.iter().map(|&p| digests[p]).collect(), rope);
    let run_with = |order: &[usize], stm: &TrainedModelStatement, s: &Shape, e: &ExpectedIo, sg: &[Vec<u8>]| -> Result<(), String> {
        let d: Vec<Digest> = order.iter().map(|&p| digests[p]).collect();
        let r = RunStatement::new_bound_from_digests(ex.geometry.run_shape(s, order.len())?, ctx, e.clone(), d, &vec![(0, 0); order.len()], stm)?;
        run::verify_run_with(&r, &mut CacheBlocks(cache_for(order)), sg)
    };
    let ident: Vec<usize> = (0..l).collect();
    let (a, b) = (l / 2 - 1, l / 2);
    // (1) a statement (and the verifier's block list) with two adjacent
    //     blocks swapped, and the honest statement over the swapped list
    {
        let mut recs: Vec<LayerRecord> = loaded.iter().map(|x| x.record.clone()).collect();
        recs.swap(a, b);
        for (k, r) in recs.iter_mut().enumerate() {
            r.index = layers[k];
        }
        let mut st2 = st.clone();
        st2.layers = recs;
        let mut sw = ident.clone();
        sw.swap(a, b);
        refuse(&format!("a statement with blocks {a} and {b} swapped"), run_with(&sw, &st2, sh, expected, &segs))?;
        refuse(&format!("the honest statement with the verifier's block list {a} <-> {b} swapped"), run_with(&sw, st, sh, expected, &segs))?;
    }
    // (2) one calibration constant moved (the verifier's shape and statement)
    for (name, v) in [("norm_cn_a + 1", NormCalibration { cn_a: rc.cal.cn_a + 1, ..rc.cal }), ("sh_z moved by one", NormCalibration { sh_z: nudge(rc.cal.sh_z, 1, 8), ..rc.cal }), ("sh_qkv moved by one", NormCalibration { sh_qkv: nudge(rc.cal.sh_qkv, 1, 8), ..rc.cal })] {
        let r = (|| -> Result<(), String> {
            let s2 = ex.geometry.shape_at(&v, rc.f_e)?;
            let st2 = ex.statement_of_records(&s2, &Constants { cal: v, ..rc.clone() }, loaded.iter().map(|m| m.record.clone()).collect())?;
            let e2 = ExpectedIo::from_bytes_at(&s2, &expected.to_bytes())?;
            run_with(&ident, &st2, &s2, &e2, &segs)
        })();
        refuse(&format!("a verifier statement with {name}"), r)?;
    }
    // (2b) review finding F-1: f_e moved by one inside its declared class
    {
        let fe2 = nudge(rc.f_e, *super::shape::TRAINED_F_E_RANGE.start(), *super::shape::TRAINED_F_E_RANGE.end());
        let r = (|| -> Result<(), String> {
            let s2 = ex.geometry.shape_at(&rc.cal, fe2)?;
            let st2 = ex.statement_of_records(&s2, &Constants { f_e: fe2, ..rc.clone() }, loaded.iter().map(|m| m.record.clone()).collect())?;
            let e2 = ExpectedIo::from_bytes_at(&s2, &expected.to_bytes())?;
            run_with(&ident, &st2, &s2, &e2, &segs)
        })();
        refuse("a verifier statement with f_e moved by one", r)?;
    }
    // (3) another export digest
    {
        let mut st2 = st.clone();
        st2.calibration.export_profile_sha256[0] ^= 1;
        refuse("a verifier statement with another export profile digest", run_with(&ident, &st2, sh, expected, &segs))?;
    }
    // (4) one block fewer (the last one dropped)
    {
        let mut st2 = st.clone();
        st2.layers.pop();
        refuse("a verifier statement and block list one block shorter", run_with(&ident[..l - 1], &st2, sh, expected, &segs[..l - 1]))?;
    }
    // (5) segment mutations, each made IN PLACE and undone
    let rst = RunStatement::new_bound_from_digests(ex.geometry.run_shape(sh, l)?, ctx, expected.clone(), digests.to_vec(), &vec![(0, 0); l], st)?;
    {
        let m = segs[b].len() / 2;
        segs[b][m] ^= 0x01;
        let r = run::verify_run_with(&rst, &mut CacheBlocks(cache_for(&ident)), &segs);
        segs[b][m] ^= 0x01;
        refuse(&format!("segment {b} with one byte flipped"), r)?;
        segs.swap(a, b);
        let r = run::verify_run_with(&rst, &mut CacheBlocks(cache_for(&ident)), &segs);
        segs.swap(a, b);
        refuse(&format!("segments {a} and {b} swapped"), r)?;
        let last = segs[l - 1].pop().ok_or("an empty last segment")?;
        let r = run::verify_run_with(&rst, &mut CacheBlocks(cache_for(&ident)), &segs);
        segs[l - 1].push(last);
        refuse("the last segment truncated by one byte", r)?;
    }
    run::verify_run_with(&rst, &mut CacheBlocks(cache_for(&ident)), &segs)?;
    println!("{{\"event\":\"stack-controls\",\"refused\":{n},\"honest_still_verifies\":true}}");
    Ok(())
}

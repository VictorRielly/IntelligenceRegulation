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

use super::layout::{Ids, A_X, A_X2};
use super::run::{self, RunShape, RunStatement, RunWitnessSource, RUN_PROFILE_RUNG_TC, RUN_PROFILE_TINYLLAMA_T32_TRAINED};
use super::rope::RopeScaling;
use super::shape::{NormCalibration, Shape};
use super::trained_statement::{apply_own, cal_field, has_own, own_of, tied_tensor_for_profile, IntegerCalibration, LayerRecord, ModelSource, Provenance, SourceKind, TiedEmbedding, TrainedModelStatement, OWN_FIELDS};
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
const SCOPE_8B_LONGER: &str = "ONE trained Llama-3-8B block (of 32) at the export's T (64 or 128; both profiles accepted by the independent review, round 5), CPU unless the run line says gpu; the integer model the calibration export names; NOT a model pass; NO privacy acceptance at this shape (D22 covers only the toy); float fidelity is the calibration lane's measurement";
const SCOPE_RUNG: &str = "SYNTHETIC development export at the trained-calibration rung (rung-TC, width 384): NOT a trained model, NOT TinyLlama; a test of the export reader and the driver only; no privacy acceptance";
/// NATIVE R12 (D38): the single-block scope at a Shieldstral profile
const SCOPE_SHIELDSTRAL: &str = "ONE trained Shieldstral-1.0-3B text block (of 26; d 3072, a 4096-wide query axis, YaRN RoPE) at the export's T (128 or 256), CPU unless the run line says gpu; the integer model the calibration export names; NOT a model pass; NOT a soundness or privacy acceptance (the D24 review of the R12 profiles follows); float fidelity is the calibration lane's measurement";
/// NATIVE R12 (F2): the decoupled-head development rung's
const SCOPE_RUNG_HD: &str = "SYNTHETIC development export at the decoupled-head rung (rung-HD, width 192, query axis 512): NOT a trained model; a test of the export reader and the driver only; no privacy acceptance";
/// NATIVE R9: the single-block scope at a DD profile (D30)
const SCOPE_DD: &str = "ONE trained block under DD, the per-row division dictionary (D30; TinyLlama-1.1B or Llama-3-8B at T128, or the synthetic DD rung): the integer model the calibration export names; NOT a model pass; NOT a soundness or privacy acceptance (D30 requires an independent soundness review and the gate first); float fidelity is the calibration lane's measurement";

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
    // still SHA-256-checked against its manifest exactly as before).
    // R5b (review r4 finding r4_B): the check-then-open race is closed by the
    // run module's bounded reader (no link followed, no FIFO blocked on, the
    // opened file re-checked, the read capped)
    run::read_regular_file_bounded(path, max, false)
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

fn load_array(dir: &Path, name: &str, spec: &J, expect: &[(Dtype, &[usize])]) -> Result<Array, String> {
    load_array_checked(dir, name, spec, true, expect)
}

/// ROUND 5 (R5-2): `check_sha = false` is the proving-pass RELOAD of a block
/// the digest pass already hashed: every dtype / shape / size check still
/// runs, the per-array SHA-256 is skipped, and the caller compares the
/// rebuilt block's digest with the digest pass's — the bytes proved are the
/// bytes digested (no time-of-check/time-of-use gap: the digest is taken of
/// the very block that is proved).
///
/// R5b (review r4 finding r4_A, verifier DoS): BEFORE any byte is read, the
/// manifest's dtype and shape must be one the code expects for this array
/// (`expect`, the same alternatives the caller's `Array::expect` checks
/// after), and the file is read with its EXACT length as the bound (refused
/// from metadata otherwise) — so a crafted export makes the reader hold no
/// more than the honest arrays' sizes, however many loads run in parallel.
fn load_array_checked(dir: &Path, name: &str, spec: &J, check_sha: bool, expect: &[(Dtype, &[usize])]) -> Result<Array, String> {
    let ctx = |e: String| format!("array `{name}`: {e}");
    let file = plain_name(spec.get("file").and_then(J::str).map_err(ctx)?).map_err(ctx)?;
    let dtype = Dtype::parse(spec.get("dtype").and_then(J::str).map_err(ctx)?).map_err(ctx)?;
    let shape: Vec<usize> = spec.get("shape").and_then(J::arr).map_err(ctx)?.iter().map(|v| v.i64().and_then(|x| usize::try_from(x).map_err(|_| "a negative dimension".to_string()))).collect::<Result<_, _>>().map_err(ctx)?;
    if !expect.is_empty() && !expect.iter().any(|(dt, sh)| *dt == dtype && *sh == shape.as_slice()) {
        return Err(ctx(format!("the manifest declares {dtype:?} {shape:?}, expected one of {expect:?} (refused before it is read: review r4_A)")));
    }
    let want = unhex32(spec.get("sha256").and_then(J::str).map_err(ctx)?).map_err(ctx)?;
    let n: usize = shape.iter().product::<usize>().checked_mul(dtype.size()).ok_or_else(|| ctx("size overflow".into()))?;
    if n as u64 > MAX_ARRAY_BYTES {
        return Err(ctx(format!("the manifest's dtype and shape give {n} bytes, above the bound {MAX_ARRAY_BYTES}")));
    }
    let bytes = run::read_regular_file_bounded(&dir.join(file), n as u64, true).map_err(|e| ctx(format!("{e} (the manifest's dtype and shape give {n})")))?;
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

/// **NATIVE R12 (F1): the export's declared RoPE transform** — `profile.
/// json`'s `rope_scaling` object in transformers' own keys (`rope_type`
/// `"yarn"`: `factor`, `original_max_position_embeddings`, `beta_fast`,
/// `beta_slow`, `mscale`, `mscale_all_dim`, optional `truncate`; `"llama3"`:
/// `factor`, `low_freq_factor`, `high_freq_factor`,
/// `original_max_position_embeddings`). Absent, `null` or `rope_type
/// "default"` is no transform.
pub(super) fn rope_scaling_of(v: Option<&J>) -> Result<RopeScaling, String> {
    let v = match v {
        None | Some(J::Null) => return Ok(RopeScaling::None),
        Some(v) => v,
    };
    let f = |k: &str| v.get(k).and_then(J::f64).map_err(|e| format!("rope_scaling.{k}: {e}"));
    let u = |k: &str| v.get(k).and_then(J::i64).and_then(|x| u64::try_from(x).map_err(|_| "negative".to_string())).map_err(|e| format!("rope_scaling.{k}: {e}"));
    let out = match v.get("rope_type").and_then(J::str).map_err(|e| format!("rope_scaling.rope_type: {e}"))? {
        "default" => RopeScaling::None,
        "yarn" => RopeScaling::Yarn {
            factor: f("factor")?,
            original_max: u("original_max_position_embeddings")?,
            beta_fast: f("beta_fast")?,
            beta_slow: f("beta_slow")?,
            mscale: f("mscale")?,
            mscale_all_dim: f("mscale_all_dim")?,
            truncate: match v.opt("truncate") {
                None | Some(J::Null) => true,
                Some(J::Bool(b)) => *b,
                Some(_) => return Err("rope_scaling.truncate is not a boolean".into()),
            },
        },
        "llama3" => RopeScaling::Llama3 { factor: f("factor")?, low_freq_factor: f("low_freq_factor")?, high_freq_factor: f("high_freq_factor")?, original_max: u("original_max_position_embeddings")? },
        t => return Err(format!("rope_scaling.rope_type {t:?} is not one of default / yarn / llama3")),
    };
    out.check()?;
    Ok(out)
}

/// **NATIVE R12 (F3): a tied model's embedding / head record.** At a
/// geometry whose model ties its embedding and head, `profile.json` names the
/// tied tensor (`tied_embeddings: {tensor, sha256}`), and BOTH integer tables
/// of `token_io/` name that same tensor as their source
/// (`token_io.json` `embedding_table.source_tensor` and `head_manifest.json`
/// `source_tensor`, each `{name, sha256}`); the name is the profile's pin and,
/// for the pinned checkpoint, so is the digest. R12b checks the three table
/// files' dtype, shape, exact length and SHA-256, then recomputes their
/// digests from the authenticated BF16 checkpoint and profile quantizer.
/// Manifest consistency alone is insufficient. An untied geometry's export
/// may not declare a tie.
pub(super) fn tied_of(dir: &Path, p: &J, geometry: Geometry, source: &ModelSource) -> Result<Option<TiedEmbedding>, String> {
    let profile = geometry.shape_profile();
    let decl = p.opt("tied_embeddings").filter(|v| **v != J::Null);
    let pin = tied_tensor_for_profile(profile);
    let (name, digest) = match (pin, decl) {
        (None, None) => return Ok(None),
        (None, Some(_)) => return Err(format!("the export declares tied_embeddings, but its geometry's model ({profile}) is untied")),
        (Some((n, _)), None) => return Err(format!("the geometry's model ties its embedding and head ({n}); profile.json must name the tied tensor (tied_embeddings)")),
        (Some((pn, pd)), Some(d)) => {
            let n = d.get("tensor").and_then(J::str).map_err(|e| format!("tied_embeddings.tensor: {e}"))?;
            let h = unhex32(d.get("sha256").and_then(J::str).map_err(|e| format!("tied_embeddings.sha256: {e}"))?)?;
            if n != pn {
                return Err(format!("tied_embeddings names tensor {n:?}, not the profile's {pn:?}"));
            }
            if source.kind == SourceKind::HfCheckpoint && h != pd {
                return Err(format!("tied_embeddings' SHA-256 {} is not the pinned checkpoint's {pn} ({})", hex(&h), hex(&pd)));
            }
            (pn, h)
        }
    };
    let td = dir.join("token_io");
    let read = |f: &str| -> Result<J, String> {
        let path = td.join(f);
        parse_json(&read_bounded(&path, MAX_JSON_BYTES)?).map_err(|e| format!("{}: {e}", path.display()))
    };
    let (tio, hm) = (read("token_io.json")?, read("head_manifest.json")?);
    let same_source = |what: &str, st: Option<&J>| -> Result<(), String> {
        let st = st.ok_or_else(|| format!("{what} names no source_tensor (a tied model's tables must name the tied tensor)"))?;
        let n = st.get("name").and_then(J::str).map_err(|e| format!("{what}.source_tensor.name: {e}"))?;
        let h = unhex32(st.get("sha256").and_then(J::str).map_err(|e| format!("{what}.source_tensor.sha256: {e}"))?)?;
        if n != name || h != digest {
            return Err(format!("{what}'s source tensor ({n}, {}) is not the tied tensor ({name}, {})", hex(&h), hex(&digest)));
        }
        Ok(())
    };
    let et = tio.get("embedding_table").map_err(|e| format!("token_io.json: {e}"))?;
    same_source("token_io.json embedding_table", et.opt("source_tensor"))?;
    same_source("head_manifest.json", hm.opt("source_tensor"))?;
    let digest_of = |j: &J, what: &str| -> Result<[u8; 32], String> { unhex32(j.get("sha256").and_then(J::str).map_err(|e| format!("{what}.sha256: {e}"))?) };
    let emb = digest_of(et, "token_io.json embedding_table")?;
    let head = digest_of(hm.get("head_int8_perrow.bin").map_err(|e| format!("head_manifest.json: {e}"))?, "head_manifest.json head_int8_perrow.bin")?;
    let mult = digest_of(hm.get("head_mult12.bin").map_err(|e| format!("head_manifest.json: {e}"))?, "head_manifest.json head_mult12.bin")?;
    let he = hm.get("head_int8_perrow.bin")?;
    let mu = hm.get("head_mult12.bin")?;
    let checked_length = |j: &J, kind: Dtype, shape: &[usize], what: &str| -> Result<u64, String> {
        let got_kind = Dtype::parse(j.get("dtype").and_then(J::str)?)?;
        let got_shape = j.get("shape").and_then(J::arr)?.iter().map(|x| x.i64().and_then(|n| usize::try_from(n).map_err(|_| "negative shape".into()))).collect::<Result<Vec<_>, _>>()?;
        if got_kind != kind || got_shape != shape {
            return Err(format!("{what}: dtype/shape {:?} {got_shape:?}, expected {kind:?} {shape:?}", got_kind));
        }
        Ok(shape.iter().product::<usize>() as u64 * kind.size() as u64)
    };
    let emb_len = checked_length(et, Dtype::I16, &[131072, 3072], "embedding_table")?;
    let head_len = checked_length(he, Dtype::I8, &[131072, 3072], "head_int8_perrow.bin")?;
    let mult_len = checked_length(mu, Dtype::I64, &[131072], "head_mult12.bin")?;
    for (file, want, length) in [(et.get("file").and_then(J::str).unwrap_or("embedding_int16.bin"), emb, emb_len), ("head_int8_perrow.bin", head, head_len), ("head_mult12.bin", mult, mult_len)] {
        plain_name(file)?;
        let got = super::tied_tables::hash_regular_exact(&td.join(file), length)?;
        if got != want {
            return Err(format!("token_io/{file}: SHA-256 {} is not its manifest's {}", hex(&got), hex(&want)));
        }
    }
    let derived = super::tied_tables::recompute_declared_tied_tables(dir, p)?;
    for (what, actual, expected) in [("embedding", emb, derived.embedding_sha256), ("head", head, derived.head_sha256), ("head multipliers", mult, derived.multipliers_sha256)] {
        if actual != expected {
            return Err(format!("tied {what}: integer table is not derived from the pinned tensor under the export's quantizer"));
        }
    }
    Ok(Some(TiedEmbedding { tensor: name.into(), tensor_sha256: digest, embedding_table_sha256: emb, head_table_sha256: head, head_mult_sha256: mult }))
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
    /// ROUND 4 (R4-1): Llama-3-8B at T = 32; task 3 (2026-10-17 evening):
    /// also T = 64 and 128 (PENDING REVIEW), each its own profile
    Llama3_8B(usize),
    RungTcDev,
    /// **NATIVE R9 (D30): the DD profiles' geometries** — chosen by the CLI's
    /// `--dd` (an export names its model and T, not the relation it is
    /// proved under); the DD rung is a DD-only development geometry
    /// (`rung-dd-t32-dev`)
    TinyLlamaDd,
    Llama3_8BDd,
    RungDdDev,
    /// **NATIVE R12 (D38): Shieldstral-1.0-3B's text decoder** at T128 or
    /// T256, without and with DD (`--dd`), and the decoupled-head development
    /// rung (`rung-hd-t32-dev`, F2)
    Shieldstral(usize),
    ShieldstralDd(usize),
    RungHdDev,
}

impl Geometry {
    fn parse(s: &str) -> Result<Geometry, String> {
        match s {
            "tinyllama-1.1b-t32" => Ok(Geometry::TinyLlama(32)),
            "tinyllama-1.1b-t64" => Ok(Geometry::TinyLlama(64)),
            "tinyllama-1.1b-t128" => Ok(Geometry::TinyLlama(128)),
            "llama-3-8b-t32" => Ok(Geometry::Llama3_8B(32)),
            "llama-3-8b-t64" => Ok(Geometry::Llama3_8B(64)),
            "llama-3-8b-t128" => Ok(Geometry::Llama3_8B(128)),
            "rung-tc-t32-dev" => Ok(Geometry::RungTcDev),
            "rung-dd-t32-dev" => Ok(Geometry::RungDdDev),
            "shieldstral-3b-t128" => Ok(Geometry::Shieldstral(128)),
            "shieldstral-3b-t256" => Ok(Geometry::Shieldstral(256)),
            "rung-hd-t32-dev" => Ok(Geometry::RungHdDev),
            _ => Err(format!("geometry `{s}` is not one of tinyllama-1.1b-t32 / -t64 / -t128 / llama-3-8b-t32 / -t64 / -t128 / shieldstral-3b-t128 / -t256 / rung-tc-t32-dev / rung-dd-t32-dev / rung-hd-t32-dev")),
        }
    }
    /// **NATIVE R9: the same model and T under DD (D30)**, refused by name at
    /// a geometry with no DD profile
    pub(crate) fn dd(self) -> Result<Geometry, String> {
        match self {
            Geometry::TinyLlama(128) | Geometry::TinyLlamaDd => Ok(Geometry::TinyLlamaDd),
            Geometry::Llama3_8B(128) | Geometry::Llama3_8BDd => Ok(Geometry::Llama3_8BDd),
            Geometry::RungDdDev => Ok(Geometry::RungDdDev),
            Geometry::Shieldstral(t) | Geometry::ShieldstralDd(t) => Ok(Geometry::ShieldstralDd(t)),
            g => Err(format!("trained export: DD (D30) is registered only at TinyLlama T128, Llama-3-8B T128, Shieldstral T128 / T256 and the DD development rung, not at {g:?}")),
        }
    }
    /// NATIVE R12: the block profile string of the geometry (its registry
    /// entry; the shape itself is built at the run's calibration)
    pub(crate) fn shape_profile(self) -> &'static str {
        use super::shape::*;
        match self {
            Geometry::TinyLlama(64) => TINYLLAMA_T64_TRAINED_PROFILE,
            Geometry::TinyLlama(128) => TINYLLAMA_T128_TRAINED_PROFILE,
            Geometry::TinyLlama(_) => TINYLLAMA_T32_TRAINED_PROFILE,
            Geometry::Llama3_8B(64) => LLAMA3_8B_T64_TRAINED_PROFILE,
            Geometry::Llama3_8B(128) => LLAMA3_8B_T128_TRAINED_PROFILE,
            Geometry::Llama3_8B(_) => LLAMA3_8B_T32_TRAINED_PROFILE,
            Geometry::RungTcDev => TRAINED_CALIB_RUNG_PROFILE,
            Geometry::TinyLlamaDd => TINYLLAMA_T128_DD_TRAINED_PROFILE,
            Geometry::Llama3_8BDd => LLAMA3_8B_T128_DD_TRAINED_PROFILE,
            Geometry::RungDdDev => TRAINED_DD_RUNG_PROFILE,
            Geometry::Shieldstral(256) => SHIELDSTRAL_T256_TRAINED_PROFILE,
            Geometry::Shieldstral(_) => SHIELDSTRAL_T128_TRAINED_PROFILE,
            Geometry::ShieldstralDd(256) => SHIELDSTRAL_T256_DD_TRAINED_PROFILE,
            Geometry::ShieldstralDd(_) => SHIELDSTRAL_T128_DD_TRAINED_PROFILE,
            Geometry::RungHdDev => TRAINED_HD_RUNG_PROFILE,
        }
    }
    /// whether this geometry proves under DD
    pub(crate) fn is_dd(self) -> bool {
        matches!(self, Geometry::TinyLlamaDd | Geometry::Llama3_8BDd | Geometry::RungDdDev | Geometry::ShieldstralDd(_))
    }
    /// NATIVE R12: whether the geometry's model is Shieldstral
    pub(crate) fn is_shieldstral(self) -> bool {
        matches!(self, Geometry::Shieldstral(_) | Geometry::ShieldstralDd(_))
    }
    /// the context length the geometry fixes
    pub(crate) fn tokens(self) -> usize {
        match self {
            Geometry::TinyLlama(t) | Geometry::Llama3_8B(t) | Geometry::Shieldstral(t) | Geometry::ShieldstralDd(t) => t,
            Geometry::RungTcDev | Geometry::RungDdDev | Geometry::RungHdDev => 32,
            Geometry::TinyLlamaDd | Geometry::Llama3_8BDd => 128,
        }
    }
    /// the RoPE base the geometry's model fixes (pinned per profile)
    pub(crate) fn rope_theta(self) -> f64 {
        match self {
            Geometry::Llama3_8B(_) | Geometry::Llama3_8BDd => super::shape::LLAMA3_8B_ROPE_THETA,
            Geometry::Shieldstral(_) | Geometry::ShieldstralDd(_) => super::shape::SHIELDSTRAL_ROPE_THETA,
            _ => super::shape::TRAINED_ROPE_THETA,
        }
    }
    /// NATIVE R12 (F1): the RoPE transform the geometry's model fixes
    pub(crate) fn rope_scaling(self) -> RopeScaling {
        if self.is_shieldstral() {
            RopeScaling::shieldstral()
        } else {
            RopeScaling::None
        }
    }
    pub(crate) fn run_profile(self) -> &'static str {
        match self {
            Geometry::TinyLlama(64) => super::run::RUN_PROFILE_TINYLLAMA_T64_TRAINED,
            Geometry::TinyLlama(128) => super::run::RUN_PROFILE_TINYLLAMA_T128_TRAINED,
            Geometry::TinyLlama(_) => RUN_PROFILE_TINYLLAMA_T32_TRAINED,
            Geometry::Llama3_8B(64) => super::run::RUN_PROFILE_LLAMA3_8B_T64_TRAINED,
            Geometry::Llama3_8B(128) => super::run::RUN_PROFILE_LLAMA3_8B_T128_TRAINED,
            Geometry::Llama3_8B(_) => super::run::RUN_PROFILE_LLAMA3_8B_T32_TRAINED,
            Geometry::RungTcDev => RUN_PROFILE_RUNG_TC,
            Geometry::TinyLlamaDd => super::run::RUN_PROFILE_TINYLLAMA_T128_DD,
            Geometry::Llama3_8BDd => super::run::RUN_PROFILE_LLAMA3_8B_T128_DD,
            Geometry::RungDdDev => super::run::RUN_PROFILE_RUNG_DD,
            Geometry::Shieldstral(256) => super::run::RUN_PROFILE_SHIELDSTRAL_T256_TRAINED,
            Geometry::Shieldstral(_) => super::run::RUN_PROFILE_SHIELDSTRAL_T128_TRAINED,
            Geometry::ShieldstralDd(256) => super::run::RUN_PROFILE_SHIELDSTRAL_T256_DD,
            Geometry::ShieldstralDd(_) => super::run::RUN_PROFILE_SHIELDSTRAL_T128_DD,
            Geometry::RungHdDev => super::run::RUN_PROFILE_RUNG_HD,
        }
    }
    pub(crate) fn run_shape(self, sh: &Shape, l: usize) -> Result<RunShape, String> {
        match self {
            Geometry::TinyLlama(_) | Geometry::Llama3_8B(_) | Geometry::TinyLlamaDd | Geometry::Llama3_8BDd | Geometry::Shieldstral(_) | Geometry::ShieldstralDd(_) => RunShape::tinyllama_trained(sh.clone(), l),
            Geometry::RungTcDev => RunShape::rung_tc(sh.clone(), l),
            Geometry::RungDdDev => RunShape::rung_dd(sh.clone(), l),
            Geometry::RungHdDev => RunShape::rung_hd(sh.clone(), l),
        }
    }
    /// the shape at a calibration (the controls rebuild it at other ones)
    pub(crate) fn scope(self) -> &'static str {
        match self {
            Geometry::TinyLlama(_) => SCOPE,
            Geometry::Llama3_8B(32) => SCOPE_8B,
            Geometry::Llama3_8B(_) => SCOPE_8B_LONGER,
            Geometry::RungTcDev => SCOPE_RUNG,
            Geometry::TinyLlamaDd | Geometry::Llama3_8BDd | Geometry::RungDdDev => SCOPE_DD,
            Geometry::Shieldstral(_) | Geometry::ShieldstralDd(_) => SCOPE_SHIELDSTRAL,
            Geometry::RungHdDev => SCOPE_RUNG_HD,
        }
    }
    pub(crate) fn shape_at(self, cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        match self {
            Geometry::TinyLlama(t) => Shape::tinyllama_trained(t, cal, f_e),
            Geometry::Llama3_8B(t) => Shape::llama3_8b_trained(t, cal, f_e),
            Geometry::RungTcDev => {
                if f_e != 12 {
                    return Err(format!("trained export: the rung-TC geometry fixes f_e = 12, the export declares {f_e}"));
                }
                Shape::rung_tc(cal)
            }
            Geometry::TinyLlamaDd => Shape::tinyllama_t128_trained_dd(cal, f_e),
            Geometry::Llama3_8BDd => Shape::llama3_8b_t128_trained_dd(cal, f_e),
            Geometry::RungDdDev => {
                if f_e != 12 {
                    return Err(format!("trained export: the DD rung geometry fixes f_e = 12, the export declares {f_e}"));
                }
                Shape::rung_dd(cal)
            }
            Geometry::Shieldstral(t) => Shape::shieldstral_trained(t, cal, f_e),
            Geometry::ShieldstralDd(t) => Shape::shieldstral_trained_dd(t, cal, f_e),
            Geometry::RungHdDev => {
                if f_e != 12 {
                    return Err(format!("trained export: the decoupled-head rung geometry fixes f_e = 12, the export declares {f_e}"));
                }
                Shape::rung_hd(cal)
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
    /// NATIVE R12 (F1): the RoPE transform the export declares (checked equal
    /// to its geometry's pin)
    pub rope_scaling: RopeScaling,
    /// NATIVE R12 (F3): a tied model's embedding / head record, read from the
    /// export's `token_io/` manifests and checked against the pinned tensor
    pub tied: Option<TiedEmbedding>,
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
        let shield_pin = ModelSource::shieldstral_1_0_3b();
        let geometry = match p.opt("geometry") {
            None if repo == shield_pin.repo => match tokens {
                128 | 256 => Geometry::Shieldstral(tokens),
                _ => return Err(ctx(format!("T = {tokens}: no trained Shieldstral profile is registered at this context length (128 and 256 are)"))),
            },
            None if repo == llama_pin.repo => match tokens {
                32 | 64 | 128 => Geometry::Llama3_8B(tokens),
                _ => return Err(ctx(format!("T = {tokens}: no trained Llama-3-8B profile is registered at this context length (32, 64 and 128 are)"))),
            },
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
            Geometry::Llama3_8B(_) | Geometry::Llama3_8BDd => {
                if repo != llama_pin.repo || rev != llama_pin.revision || msha != llama_pin.weights_sha256 {
                    return Err(ctx(format!("the model pin ({repo}, {rev}, {}) is not the pinned Llama-3-8B source ({}, {}, {})", hex(&msha), llama_pin.repo, llama_pin.revision, hex(&llama_pin.weights_sha256))));
                }
                llama_pin
            }
            Geometry::TinyLlama(_) | Geometry::TinyLlamaDd => {
                if repo != pin.repo || rev != pin.revision || msha != pin.weights_sha256 {
                    return Err(ctx(format!("the model pin ({repo}, {rev}, {}) is not the pinned TinyLlama source ({}, {}, {})", hex(&msha), pin.repo, pin.revision, hex(&pin.weights_sha256))));
                }
                pin
            }
            Geometry::Shieldstral(_) | Geometry::ShieldstralDd(_) => {
                if repo != shield_pin.repo || rev != shield_pin.revision || msha != shield_pin.weights_sha256 {
                    return Err(ctx(format!("the model pin ({repo}, {rev}, {}) is not the pinned Shieldstral source ({}, {}, {})", hex(&msha), shield_pin.repo, shield_pin.revision, hex(&shield_pin.weights_sha256))));
                }
                shield_pin
            }
            Geometry::RungTcDev | Geometry::RungDdDev | Geometry::RungHdDev => {
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
        if geometry == Geometry::RungTcDev || geometry == Geometry::RungDdDev || geometry == Geometry::RungHdDev {
            source.checkpoint_layers = layers.iter().max().map(|m| m + 1).unwrap_or(0);
        }
        // NATIVE R12 (F1): the declared RoPE transform is the geometry's pin
        // (an export of an unscaled model declares none, or `default`)
        let rope_scaling = rope_scaling_of(p.opt("rope_scaling")).map_err(ctx)?;
        if rope_scaling != geometry.rope_scaling() {
            return Err(ctx(format!("the export declares the RoPE transform {}, but its geometry's model fixes {} (a model fact, pinned per profile)", rope_scaling.describe(), geometry.rope_scaling().describe())));
        }
        // NATIVE R12 (F3): a tied model's embedding / head record
        let tied = tied_of(dir, &p, geometry, &source).map_err(ctx)?;
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
            rope_scaling,
            tied,
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

    /// **NATIVE R8 (R6 for `sh_s`): which of the eleven calibration
    /// constants ([`OWN_FIELDS`]) this export names per layer** — the indices
    /// of those `profile.json` lists in `per_layer_constants_differ` (with
    /// `null` in `profile_constants`, as it already does for the table keys).
    pub(crate) fn per_layer_cal_fields(&self) -> Vec<usize> {
        (0..OWN_FIELDS.len()).filter(|i| self.per_layer_differ.iter().any(|k| k == OWN_FIELDS[*i].0)).collect()
    }

    /// a calibration with every per-layer field set to `base`'s
    fn masked(&self, c: &Constants, base: &NormCalibration) -> Result<Constants, String> {
        let fields = self.per_layer_cal_fields();
        let mut own = [None; 11];
        for i in fields {
            own[i] = Some(cal_field(base, i));
        }
        Ok(Constants { cal: apply_own(&c.cal, &own)?, ..c.clone() })
    }

    /// **The ONE calibration of a run over `layers`.** The profile's uniform
    /// constants, or, where the writer marked some per-layer, the layers'
    /// own manifest constants — which must then agree across the run (a run
    /// has one shape). Every layer's manifest constants must equal the result.
    ///
    /// NATIVE R8 (R6 for `sh_s`): with per-layer calibration fields, the
    /// RUN's calibration is the one most of the run's layers carry in those
    /// fields together (ties: the smallest in the canonical [`OWN_FIELDS`]
    /// order, `sh_s` first — so an `sh_s`-only export gets R6's base); each
    /// other layer records its differing fields (`LayerRecord::own`). Every
    /// other run-level constant must agree across the run's layers, as before.
    pub(crate) fn run_constants(&self, layers: &[u32]) -> Result<Constants, String> {
        let mut out = self.constants.clone();
        let fields = self.per_layer_cal_fields();
        let mut all: Vec<(PathBuf, Constants)> = Vec::with_capacity(layers.len());
        for &l in layers {
            let (mpath, _, m) = self.manifest(l)?;
            let c = constants_of(m.get("constants").map_err(|e| format!("{}: {e}", mpath.display()))?, &mpath.display().to_string(), self.geometry.rope_theta())?;
            all.push((mpath, c));
        }
        let base: Option<NormCalibration> = if !fields.is_empty() && out.is_none() {
            let key = |c: &NormCalibration| -> Vec<i64> { fields.iter().map(|i| cal_field(c, *i)).collect() };
            let mut counts: std::collections::BTreeMap<Vec<i64>, (usize, NormCalibration)> = std::collections::BTreeMap::new();
            for (_, c) in &all {
                counts.entry(key(&c.cal)).or_insert((0, c.cal)).0 += 1;
            }
            let best = counts.values().map(|(n, _)| *n).max().unwrap_or(0);
            counts.values().find(|(n, _)| *n == best).map(|(_, c)| *c)
        } else {
            None
        };
        for (mpath, c) in &all {
            let c = match &base {
                Some(b) => self.masked(c, b)?,
                None => c.clone(),
            };
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
        if rope_from_export && self.rope_scaling != RopeScaling::None {
            return Err("--rope-from-export is refused at a profile with a pinned RoPE transform".into());
        }
        let dir = self.layer_dir(index);
        let (mpath, mbytes, m) = self.manifest(index)?;
        let ctx = |e: String| format!("{}: {e}", mpath.display());
        let mi = m.get_any(&["layer", "index"]).and_then(J::i64).map_err(ctx)?;
        if mi != i64::from(index) {
            return Err(ctx(format!("the manifest is for layer {mi}, not {index}")));
        }
        let lc = constants_of(m.get("constants").map_err(ctx)?, &mpath.display().to_string(), self.geometry.rope_theta())?;
        // NATIVE R8 (R6 for sh_s): a profile that names calibration fields
        // per layer lets this layer's values of THOSE fields differ from the
        // run's; every other constant is the run's (one calibration per run)
        let lc_run = self.masked(&lc, &c.cal).map_err(ctx)?;
        if lc_run != *c {
            return Err(ctx("this layer's constants are not the run's (one calibration per run)".into()));
        }
        let own = own_of(&c.cal, &lc.cal);
        if has_own(&own) {
            // the layer's whole calibration, validated at the trained door
            sh.with_layer_calibration(&lc.cal).map_err(|e| ctx(format!("layer {index}'s own calibration: {e}")))?;
        }
        // the per-block table keys: this layer's own
        let tk = table_keys_of(m.get("constants").map_err(ctx)?, &mpath.display().to_string())?;
        if sh.norm_calibration() != c.cal || sh.f_e != c.f_e {
            return Err(ctx("the shape was not built from the run's constants".into()));
        }
        let arrays = m.get("arrays").map_err(ctx)?;
        // ROUND 5 (R5-2): the eleven arrays read and hashed IN PARALLEL (the
        // same bytes, the same digests, the same checks)
        let (d, f, kvw, half) = (sh.width, sh.hidden, sh.kv_heads * sh.head_dim, sh.head_dim / 2);
        // NATIVE R12 (F2): the TRUE query width `q_heads * head_dim` (4096 at
        // Shieldstral's d 3072; `d` at every profile before R12)
        let qw = sh.q_width();
        // R5b (review r4_A): each array's expected dtype and shape, checked
        // from the manifest BEFORE its bytes are read (and the read bounded
        // by that exact length)
        let (qd, dq, kd, dv, df, fd, t256) = ([qw, d], [d, qw], [kvw, d], [d], [d, f], [f, d], [256usize]);
        let expect: [(&str, Dtype, &[usize]); 11] = [
            ("wq", Dtype::I8, &qd),
            ("wk", Dtype::I8, &kd),
            ("wv", Dtype::I8, &kd),
            ("wo", Dtype::I8, &dq),
            ("gamma_a", Dtype::I8, &dv),
            ("gamma_m", Dtype::I8, &dv),
            ("wg_t", Dtype::I8, &df),
            ("wu_t", Dtype::I8, &df),
            ("wd_t", Dtype::I8, &fd),
            ("exp", Dtype::I64, &t256),
            ("act", Dtype::I16, &t256),
        ];
        let mut loaded: std::collections::VecDeque<Result<Array, String>> = {
            use rayon::prelude::*;
            expect.par_iter().map(|(name, dt, shp)| load_array_checked(&dir, name, arrays.get(name).map_err(ctx)?, full, &[(*dt, *shp)]).map_err(|e| format!("layer {index}: {e}"))).collect::<Vec<_>>().into()
        };
        // the results come back in `expect`'s order, which is the order of the
        // `get` calls below
        let mut get = |_name: &str| -> Result<Array, String> { loaded.pop_front().expect("one result per name") };
        let wq = get("wq")?;
        wq.expect("wq", Dtype::I8, &[qw, d])?;
        let wk = get("wk")?;
        wk.expect("wk", Dtype::I8, &[kvw, d])?;
        let wv = get("wv")?;
        wv.expect("wv", Dtype::I8, &[kvw, d])?;
        let wo = get("wo")?;
        wo.expect("wo", Dtype::I8, &[d, qw])?;
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
        // NATIVE R12 (F1): the generator at the profile's pinned transform
        // (the frozen generator itself at every unscaled profile)
        let (gcos, gsin) = super::shape::rope_tables_for(sh, c.rope_theta).map_err(ctx)?;
        let exported = match (arrays.opt("rope_cos").or_else(|| arrays.opt("cos")), arrays.opt("rope_sin").or_else(|| arrays.opt("sin"))) {
            (Some(cs), Some(ss)) => {
                let (r2, r1) = ([sh.tokens, half], [sh.tokens * half]);
                let rope_expect: [(Dtype, &[usize]); 2] = [(Dtype::I64, &r2), (Dtype::I64, &r1)];
                let (ca, sa) = (load_array_checked(&dir, "rope_cos", cs, full, &rope_expect)?, load_array_checked(&dir, "rope_sin", ss, full, &rope_expect)?);
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
        let (dp, qp, fp) = (sh.d_pad, sh.q_pad(), sh.f_pad);
        let id = |i: usize| i;
        let q = |j: usize| sh.head_slot(j / sh.head_dim) * sh.head_dim + j % sh.head_dim;
        let aw = [
            pad_matrix(&wq.i8s(), qw, d, qp, dp, &q, &id),
            pad_matrix(&wk.i8s(), kvw, d, kvw, dp, &id, &id),
            pad_matrix(&wv.i8s(), kvw, d, kvw, dp, &id, &id),
            pad_matrix(&wo.i8s(), d, qw, dp, qp, &id, &q),
            pad_matrix(&ga.i8s(), 1, d, 1, dp, &id, &id),
        ];
        let fw = [pad_matrix(&gm.i8s(), 1, d, 1, dp, &id, &id), pad_matrix(&wg.i8s(), d, f, dp, fp, &id, &id), pad_matrix(&wu.i8s(), d, f, dp, fp, &id, &id), pad_matrix(&wd.i8s(), f, d, fp, dp, &id, &id)];
        let public = AttentionPublic::new_shaped(sh, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp.i64s()).map_err(ctx)?;
        let ff = FeedForwardPublic::new_shaped(sh, &fw[0], &fw[1], &fw[2], &fw[3], &act.i16s()).map_err(ctx)?;
        let blk = BlockPublic::new(public, ff);
        // NATIVE R9 (D30 condition 6, CHECK.md B-8): at a DD profile the
        // trained door refuses a layer whose exp table needs more than `cap`
        // dictionary slots — by name (the layer and its table key), from the
        // public table, before any header
        if sh.dd_cap > 0 {
            blk.attention().dd_e_column(sh.dd_cap).map_err(|e| ctx(format!("layer {index} (exp_e_s {}): {e}", tk.exp_e_s)))?;
        }
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
        record.own = own;
        let _ = (wq.sha256, exp.sha256);
        Ok(TrainedLayer { index, manifest_sha256, blk, record, rope_note })
    }

    /// The PRIVATE hidden input and the Python reference's output of layer
    /// `index` on sequence `seq`, true-sized `[T, d]`. Prover only.
    pub(crate) fn load_seq(&self, sh: &Shape, seq: &str, index: u32) -> Result<(Vec<i16>, Vec<i16>), String> {
        plain_name(seq)?;
        Self::load_seq_dir(&self.dir.join(format!("seq_{seq}")), sh, index)
    }

    /// R5b (privacy review P-5): the same files from a PROVER-PRIVATE
    /// directory outside the export (`--seq-dir`), so the export a verifier
    /// is given need not hold any hidden plane. Refusals name the check, never
    /// a digest, a size or a value of the hidden files (P-6 / K-2).
    pub(crate) fn load_seq_dir(dir: &Path, sh: &Shape, index: u32) -> Result<(Vec<i16>, Vec<i16>), String> {
        Self::load_seq_dir_inner(dir, sh, index).map_err(|_| format!("the prover-private sequence files of layer {index} (x_in_L{index:02} / x_out_L{index:02}) are missing or fail their dtype / shape / SHA-256 check; no digest, size or value is printed (ruling K-2)"))
    }

    fn load_seq_dir_inner(dir: &Path, sh: &Shape, index: u32) -> Result<(Vec<i16>, Vec<i16>), String> {
        let n = sh.tokens * sh.width * 2;
        // the sequence manifest, when the writer gives one: every array is
        // then SHA-256-, dtype- and shape-checked like a layer's (the digests
        // are the writer's; this reader never prints or records them)
        let mpath = dir.join("manifest.json");
        if mpath.exists() {
            let m = parse_json(&read_bounded(&mpath, MAX_JSON_BYTES)?).map_err(|e| format!("{}: {e}", mpath.display()))?;
            let arrays = m.get("arrays").map_err(|e| format!("{}: {e}", mpath.display()))?;
            let get = |name: String| -> Result<Vec<i16>, String> {
                let a = load_array(dir, &name, arrays.get(&name).map_err(|e| format!("{}: {e}", mpath.display()))?, &[(Dtype::I16, &[sh.tokens, sh.width])])?;
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
            rope_scaling: self.rope_scaling,
        };
        let cal = IntegerCalibration::as_the_code_proves(sh, &prov);
        TrainedModelStatement::new_with_tied(sh, self.geometry.run_profile(), self.source.clone(), cal, records, self.tied.clone())
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
/// reproduce the exported `x_out` bit for bit.
///
/// R5b (privacy review P-6, ruling K-2): a mismatch is refused WITHOUT a
/// count, a position or a value — all three are functions of the hidden
/// input; the refusal names the check (and, in a stack, the layer) only.
pub(crate) fn parity(sh: &Shape, blk: &BlockPublic, x_in: &[i16], x_out: &[i16]) -> Result<Witness, String> {
    let w = witness::build_shaped(sh, blk.attention(), blk.feed_forward(), x_in).map_err(|e| format!("parity: the native witness REFUSES the exported input: {e}"))?;
    let ids = Ids::new(sh)?;
    let x2 = &w.planes[ids.at(A_X2)];
    let differs = (0..sh.tokens).any(|t| (0..sh.width).any(|i| x2[t * sh.d_pad + i] != i64::from(x_out[t * sh.width + i])));
    if differs {
        return Err(PARITY_REFUSAL.to_string());
    }
    Ok(w)
}

/// R5b (P-6 / K-2): the one parity refusal text — no count, position or value
pub(crate) const PARITY_REFUSAL: &str = "parity: the native block output differs from the exported x_out (no count, position or value is printed: ruling K-2)";

/// **R5b (privacy review P-3, run hash-layer condition C-R4): the context
/// label is a DEPLOYMENT CONSTANT**, never derived from a request or a hidden
/// input: the CLI admits only these labels (the defaults), refused by name
/// otherwise. (The label enters the published context, so a free label would
/// let a deployment make the public statement a function of the input.)
pub(crate) const BLOCK_LABELS: [&str; 1] = ["zk60-trained-block"];
pub(crate) const STACK_LABELS: [&str; 1] = ["zk60-trained-stack"];

fn label_of<'a>(f: &'a [(String, String)], allowed: &[&'static str]) -> Result<&'a str, String> {
    let label = flag(f, "--label").unwrap_or(allowed[0]);
    if !allowed.contains(&label) {
        return Err(format!("--label: ruling C-R4 (privacy review P-3) — the run context label is a deployment constant; this build admits {allowed:?}, not {label:?}"));
    }
    Ok(label)
}

/// **R5b (P-3, condition C-R1): no 40-byte input to the unkeyed hash.** The
/// context digests are the run's only unkeyed blake3 calls on caller data;
/// their inputs are length-prefixed and at least 61 bytes, and this check
/// makes the condition a refusal rather than an observation.
fn c_r1(b: &[u8]) -> Result<(), String> {
    if b.len() == 40 {
        return Err("context: condition C-R1 — a 40-byte input to the unkeyed hash is refused".into());
    }
    Ok(())
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
fn context_of(variant: &str, layer: u32, label: &str) -> Result<Digest, String> {
    let mut b = Vec::new();
    for s in ["hashline/zk60-trained-block-context/1", variant, label] {
        b.extend_from_slice(&(s.len() as u64).to_le_bytes());
        b.extend_from_slice(s.as_bytes());
    }
    b.extend_from_slice(&u64::from(layer).to_le_bytes());
    c_r1(&b)?;
    Ok(*blake3::hash(&b).as_bytes())
}

pub(crate) fn flags(args: &[String], allowed: &[&str], switches: &[&str]) -> Result<Vec<(String, String)>, String> {
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

pub(crate) fn flag<'a>(f: &'a [(String, String)], k: &str) -> Option<&'a str> {
    f.iter().find(|(x, _)| x == k).map(|(_, v)| v.as_str())
}

pub(crate) fn need<'a>(f: &'a [(String, String)], k: &str) -> Result<&'a str, String> {
    flag(f, k).ok_or_else(|| format!("{k} is required"))
}

pub(crate) fn js(s: &str) -> String {
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
        "{{\n \"schema\": \"zk60-trained-block-run/2\",\n \"scope\": {},\n \"prover_reported\": {{\"backend\": {}, \"gpu_declines\": {}, \"what\": {}}},\n \"block_profile\": {},\n \"run_profile\": {},\n \"export_variant\": {},\n \"export_profile_sha256\": {},\n \"calibration_tool_sha256\": {},\n \"layer\": {},\n \"layer_manifest_sha256\": {},\n \"block_digest\": {},\n \"trained_statement_identity\": {},\n \"context_label\": {},\n \"context\": {},\n \"expected_io\": {},\n \"rope_tables\": {},\n \"constants_source\": {},\n \"shape\": {{\"tokens\": {}, \"width\": {}, \"hidden\": {}, \"q_heads\": {}, \"kv_heads\": {}, \"head_dim\": {}, \"log_cols\": {}, \"inv_rate\": {}, \"opened_cols\": {}, \"f_e\": {}, \"wrho_s\": {}, \"norm_wrho\": {}, \"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_ao\": {}, \"d_max\": {}}}\n}}\n",
        js(ex.geometry.scope()),
        js(backend_of_this_process()),
        crate::gpu::declines(),
        js(PROVER_REPORTED_WHAT),
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

/// **R5b (privacy review P-5): where the prover-private hidden input and its
/// parity reference come from.** `--seq ID` reads the export's `seq_<ID>/`
/// (the calibration lane's layout; the prover's own copy); `--seq-dir DIR`
/// reads a prover-private directory OUTSIDE the export. Exactly one.
enum SeqSource {
    InExport(String),
    Dir(PathBuf),
}

impl SeqSource {
    fn of(f: &[(String, String)]) -> Result<SeqSource, String> {
        match (flag(f, "--seq"), flag(f, "--seq-dir")) {
            (Some(s), None) => Ok(SeqSource::InExport(s.to_string())),
            (None, Some(d)) => Ok(SeqSource::Dir(PathBuf::from(d))),
            _ => Err("exactly one of --seq ID (the export's seq_<ID>/) or --seq-dir DIR (a prover-private directory; privacy review P-5) is required".into()),
        }
    }
    fn load(&self, ex: &TrainedExport, sh: &Shape, index: u32) -> Result<(Vec<i16>, Vec<i16>), String> {
        match self {
            SeqSource::InExport(s) => ex.load_seq(sh, s, index),
            SeqSource::Dir(d) => TrainedExport::load_seq_dir(d, sh, index),
        }
    }
}

/// **R5b (privacy review P-5): a VERIFIER refuses an export directory that
/// holds a prover-private `seq_*` entry**, so that "the export" handed to a
/// verifier can never carry the hidden input and its per-layer activations.
/// (The verifier never opened them; this makes shipping them a refusal.)
pub(crate) fn refuse_prover_private_entries(export: &Path) -> Result<(), String> {
    let rd = std::fs::read_dir(export).map_err(|e| format!("{}: {e}", export.display()))?;
    for e in rd {
        let e = e.map_err(|e| format!("{}: {e}", export.display()))?;
        if e.file_name().to_string_lossy().starts_with("seq_") {
            return Err(format!(
                "privacy review P-5: the export directory {} holds the prover-private entry {:?}; a verifier's copy of the export holds the public files only (copy it without seq_*)",
                export.display(),
                e.file_name()
            ));
        }
    }
    Ok(())
}

pub(crate) fn write_new(path: &Path, bytes: &[u8]) -> Result<(), String> {
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
    let f = match flags(args, &["--export", "--layer", "--seq", "--seq-dir", "--out", "--label"], &["--rope-from-export", "--controls", "--dd"]) {
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
    let seq = SeqSource::of(f)?;
    let out = PathBuf::from(need(f, "--out")?);
    let label = label_of(f, &BLOCK_LABELS)?;
    if out.exists() {
        return Err(format!("{} exists; the output directory must be new", out.display()));
    }
    let t0 = Instant::now();
    let mut ex = TrainedExport::load(&export)?;
    // NATIVE R9 (D30): `--dd` proves / verifies under the DD profile of the
    // export's model and T (refused by name where none is registered)
    if flag(f, "--dd").is_some() {
        ex.geometry = ex.geometry.dd()?;
    }
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
    let (x_in, x_out) = seq.load(&ex, &sh, layer_ix)?;
    let w = parity(&sh, &layer.blk, &x_in, &x_out)?;
    drop((x_in, x_out));
    let parity_s = t1.elapsed().as_secs_f64();
    println!("{{\"event\":\"parity\",\"result\":\"bit-exact\",\"words\":{},\"seconds\":{parity_s:.3}}}", sh.tokens * sh.width);
    let st = ex.statement(&sh, &c, &[&layer])?;
    let ids = Ids::new(&sh)?;
    let ctx = context_of(&ex.variant, layer_ix, label)?;
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
    // NATIVE R7 (Q-2): the prover writes only the build's constants
    check_prover_reported(backend_of_this_process(), crate::gpu::declines() as u64)?;
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
        let (x_in, _) = seq.load(&ex, &sh, layer_ix)?;
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
    let ctx = context_of(&ex.variant, layer.index, label)?;
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
    let f = match flags(args, &["--export", "--layer", "--artifact", "--expect-statement", "--label"], &["--rope-from-export", "--controls", "--dd"]) {
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
    let label = label_of(f, &BLOCK_LABELS)?;
    let t0 = Instant::now();
    // R5b (P-5): the verifier's export holds no prover-private seq_* entry
    refuse_prover_private_entries(&export)?;
    let mut ex = TrainedExport::load(&export)?;
    // NATIVE R9 (D30): `--dd` proves / verifies under the DD profile of the
    // export's model and T (refused by name where none is registered)
    if flag(f, "--dd").is_some() {
        ex.geometry = ex.geometry.dd()?;
    }
    let c = ex.run_constants(&[layer_ix])?;
    let sh = ex.shape_for(&c)?;
    let layer = ex.load_layer(&sh, &c, layer_ix, flag(f, "--rope-from-export").is_some())?;
    let st = ex.statement(&sh, &c, &[&layer])?;
    if st.identity() != pin {
        return Err(format!("the rebuilt trained statement {} is not the pinned {}", hex(&st.identity()), hex(&pin)));
    }
    let ctx = context_of(&ex.variant, layer_ix, label)?;
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

/// **THE STACK'S WITNESS SOURCE (R5b).** The chain was SEALED before the
/// run header by the witness builder's own pass ([`seal_and_record`]): every
/// block's output plane is known, parity held at every layer, and the
/// witnesses that fit the cache budget were kept. The proving pass hands out
/// the sealed boundary planes and the kept witnesses; a witness that was not
/// kept is rebuilt from its sealed input (the same code on the same words —
/// deterministic) and refused, loudly, unless its output is the sealed one.
/// `lie_at` (a control only) adds one to one word of the boundary plane
/// handed out after block `lie_at`, so the boundary commitment no longer
/// holds block `lie_at`'s output.
struct StackSource<'a> {
    sh: &'a Shape,
    /// ROUND 4: the shared one-block cache (and the run's block count)
    blocks: SharedCache<'a>,
    n: usize,
    ids: Ids,
    chain: SealedChain,
    lie_at: Option<usize>,
    /// seconds spent REBUILDING witnesses in the proving pass
    busy_s: f64,
}

/// **R5b (privacy review P-1, ruling H-1): THE SEALED CHAIN.** Built by the
/// witness builder's own pass, with its refusals and the parity check at
/// every layer, BEFORE the run header is absorbed and before the run
/// directory exists, so an inadmissible chain is refused before anything of
/// the run exists. The endpoints are the builder's own planes (block 0's
/// input plane, the last block's output plane), each also equal to the
/// export's words.
struct SealedChain {
    /// block 0's true input words (a rebuild of witness 0 starts from them)
    x_in0: Vec<i16>,
    /// NATIVE R6: the shape each block's witness is built at (the run shape,
    /// or its layer's own score shift)
    shapes: Vec<Shape>,
    /// block k's padded output plane, sealed
    outs: Vec<Vec<i16>>,
    /// the witnesses kept from the sealing pass (within the budget)
    kept: Vec<Option<Witness>>,
    kept_bytes: u64,
    first: Vec<i16>,
    last: Vec<i16>,
    rebuilt: usize,
}

fn witness_bytes(w: &Witness) -> u64 {
    w.planes.iter().map(|p| 8 * p.len() as u64).sum()
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
    ///
    /// ROUND 5 (evening, 19:20 UTC): compared on the block statement's
    /// GEOMETRY (profile, axes, padded axes) — not on the whole shape. The
    /// calibration constants and windowed shifts are not in a block's words,
    /// so a verifier at another calibration is handed the very same blocks
    /// and must be refused by the run's transcript binding; the first port
    /// compared whole shapes and so refused the run-level calibration
    /// controls here, before the binding they test was reached (the R5 8B
    /// stack's controls said "the block cache was built for the shape ..."
    /// where R4's said "this segment belongs to another run"). `f_e` (the
    /// exp table's top) is CS-4's, re-checked on every loaded block by
    /// `prove_core` / `verify_core` before its stage commits or absorbs.
    fn fit_the_shape(&mut self, sh: &Shape) -> Result<(), String> {
        let c = self.0.borrow();
        let geometry = |s: &Shape| (s.profile, s.tokens, s.width, s.hidden, s.q_heads, s.head_dim, s.kv_heads, s.t_pad, s.d_pad, s.h_pad, s.f_pad);
        if geometry(c.sh) != geometry(sh) {
            return Err(format!("private run: the block cache was built for the block geometry of {:?}, the run's shape is {:?}", c.sh.name, sh.name));
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
    fn new(sh: &'a Shape, blocks: SharedCache<'a>, n: usize, chain: SealedChain, lie_at: Option<usize>) -> Result<StackSource<'a>, String> {
        if chain.outs.len() != n || chain.kept.len() != n {
            return Err("trained stack: the sealed chain is not this run's".into());
        }
        Ok(StackSource { sh, blocks, n, ids: Ids::new(sh)?, chain, lie_at, busy_s: 0.0 })
    }
    /// block k's witness: the one kept from the sealing pass, or a rebuild
    /// from the sealed input whose output must be the sealed output
    fn witness_of(&mut self, k: usize) -> Result<Witness, String> {
        if k >= self.n {
            return Err(format!("trained stack: no block {k} in a {}-block run", self.n));
        }
        if let Some(w) = self.chain.kept[k].take() {
            return Ok(w);
        }
        let t = Instant::now();
        let x = if k == 0 { self.chain.x_in0.clone() } else { true_words(self.sh, &self.chain.outs[k - 1]) };
        let blk = self.blocks.borrow_mut().get(k)?;
        let w = witness::build_shaped(&self.chain.shapes[k], blk.attention(), blk.feed_forward(), &x)?;
        drop(blk);
        if padded_plane(&w, self.ids.at(A_X2))? != self.chain.outs[k] {
            return Err(format!("trained stack: the rebuilt witness of block {k} is not the sealed one (the builder is not deterministic?); the run is abandoned"));
        }
        self.chain.rebuilt += 1;
        self.busy_s += t.elapsed().as_secs_f64();
        Ok(w)
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
        if k + 1 >= self.n {
            return Err(format!("trained stack: no boundary after block {k}"));
        }
        let mut out = self.chain.outs[k].clone();
        if self.lie_at == Some(k) {
            let i = self.sh.d_pad + 3;
            out[i] = out[i].wrapping_add(1);
        }
        Ok(out)
    }
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.witness_of(k)
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

pub(crate) fn stack_context(variant: &str, layers: &[u32], label: &str) -> Result<Digest, String> {
    let mut b = Vec::new();
    for s in ["hashline/zk60-trained-stack-context/1", variant, label] {
        b.extend_from_slice(&(s.len() as u64).to_le_bytes());
        b.extend_from_slice(s.as_bytes());
    }
    for l in layers {
        b.extend_from_slice(&u64::from(*l).to_le_bytes());
    }
    c_r1(&b)?;
    Ok(*blake3::hash(&b).as_bytes())
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

/// the sealing pass's timings
struct SealTimes {
    wall_s: f64,
    load_s: f64,
    witness_s: f64,
}

/// **R5b (privacy review P-1, ruling H-1): THE DIGEST PASS AND THE SEALING
/// PASS IN ONE, BEFORE THE RUN HEADER.** For each layer in order: the layer
/// is loaded with every check of [`stack_records`] (array SHA-256s, tables,
/// padded-word record, block digest) and its witness is built by the witness
/// builder from the previous block's output, with the builder's refusals and
/// the parity check against the export's `x_out` of that layer; the next
/// layer's load runs beside the current witness build (two blocks resident,
/// as the two-wide digest pass of R5-2). Every refusal happens here, before
/// the endpoints are committed, the run header is absorbed or the run
/// directory exists. The endpoints are the builder's own planes. Witnesses
/// are kept while their total stays within `budget_bytes`; the proving pass
/// rebuilds the others.
#[allow(clippy::type_complexity)]
fn seal_and_record(ex: &TrainedExport, layers: &[u32], rope_from_export: bool, seq: &SeqSource, budget_bytes: u64) -> Result<(Constants, Shape, Vec<LayerMeta>, Vec<Digest>, TrainedModelStatement, SealedChain, SealTimes), String> {
    let t0 = Instant::now();
    let c = ex.run_constants(layers)?;
    let sh = ex.shape_for(&c)?;
    let ids = Ids::new(&sh)?;
    let l = layers.len();
    let (x_in0, _) = seq.load(ex, &sh, layers[0])?;
    if x_in0.len() != sh.tokens * sh.width {
        return Err("trained stack: the first input is not tokens x width".into());
    }
    let mut metas = Vec::with_capacity(l);
    let mut digests = Vec::with_capacity(l);
    let mut outs: Vec<Vec<i16>> = Vec::with_capacity(l);
    let mut kept: Vec<Option<Witness>> = Vec::with_capacity(l);
    let (mut kept_bytes, mut load_s, mut witness_s) = (0u64, 0.0f64, 0.0f64);
    let mut first: Option<Vec<i16>> = None;
    let mut shapes: Vec<Shape> = Vec::with_capacity(l);
    let mut lays: Vec<(NormCalibration, super::layout::Layout)> = Vec::new();
    let mut x = x_in0.clone();
    let timed_load = |k: usize| -> (Result<TrainedLayer, String>, f64) {
        let t = Instant::now();
        let r = ex.load_layer(&sh, &c, layers[k], rope_from_export);
        (r, t.elapsed().as_secs_f64())
    };
    let mut next = Some(timed_load(0));
    for k in 0..l {
        let (cur, ls) = next.take().expect("one load per layer");
        load_s += ls;
        let cur = cur?;
        let layer = layers[k];
        // NATIVE R8 (R6 for sh_s): the block's witness at its layer's own
        // calibration
        let ssh = if has_own(&cur.record.own) { sh.with_layer_calibration(&apply_own(&sh.norm_calibration(), &cur.record.own)?)? } else { sh.clone() };
        let ((wres, ws), nxt) = rayon::join(
            || {
                let t = Instant::now();
                let r = witness::build_shaped(&ssh, cur.blk.attention(), cur.blk.feed_forward(), &x);
                (r, t.elapsed().as_secs_f64())
            },
            || if k + 1 < l { Some(timed_load(k + 1)) } else { None },
        );
        next = nxt;
        witness_s += ws;
        let w = wres.map_err(|e| format!("the witness builder refuses layer {layer} (before the run header; ruling H-1): {e}"))?;
        // NATIVE R6 (review r5 note N-r5-a): ruling CS-3's lookup-miss
        // refusal on the sealed witness, here in the sealing pass, so that no
        // refusal of an admissible-looking chain is left to `prove_core`
        // mid-run (H-1 as a fact of the code). One layout per score shift.
        let lay = match lays.iter().position(|(v, _)| *v == ssh.norm_calibration()) {
            Some(i) => &lays[i].1,
            None => {
                lays.push((ssh.norm_calibration(), super::layout::Layout::for_shape(&ssh)?));
                &lays[lays.len() - 1].1
            }
        };
        super::protocol::check_lookup_misses(&ssh, lay, &cur.blk, &w).map_err(|e| format!("layer {layer}, in the sealing pass (before the run header; ruling H-1): {e}"))?;
        let out = padded_plane(&w, ids.at(A_X2))?;
        if k == 0 {
            first = Some(padded_plane(&w, ids.at(A_X))?);
        }
        let xt = true_words(&sh, &out);
        let (_, x_out_ref) = seq.load(ex, &sh, layer)?;
        if xt != x_out_ref {
            return Err(format!("layer {layer}: {PARITY_REFUSAL} (before the run header; ruling H-1)"));
        }
        x = xt;
        digests.push(cur.record.block_digest);
        metas.push(LayerMeta { index: cur.index, manifest_sha256: cur.manifest_sha256, record: cur.record });
        let wb = witness_bytes(&w);
        if kept_bytes + wb <= budget_bytes {
            kept_bytes += wb;
            kept.push(Some(w));
        } else {
            kept.push(None);
        }
        outs.push(out);
        shapes.push(ssh);
    }
    let first = first.expect("at least one block");
    if first != pad_d_plane(&sh, &x_in0)? {
        return Err("trained stack: the builder's block-0 input plane is not the export's x_in (before the run header)".into());
    }
    let last = outs[l - 1].clone();
    let st = ex.statement_of_records(&sh, &c, metas.iter().map(|m| m.record.clone()).collect())?;
    let chain = SealedChain { x_in0, shapes, outs, kept, kept_bytes, first, last, rebuilt: 0 };
    Ok((c, sh, metas, digests, st, chain, SealTimes { wall_s: t0.elapsed().as_secs_f64(), load_s, witness_s }))
}

/// **R5b (P-1): a run that did not complete is removed, and a removal that
/// fails is an error the caller sees** (it was `let _ = remove_dir_all`).
fn fail_run(out: &Path, why: String) -> String {
    match std::fs::remove_dir_all(out) {
        Ok(()) => format!("{why} (the incomplete run directory was removed)"),
        Err(e) => {
            let msg = format!("{why}; AND THE INCOMPLETE RUN DIRECTORY {} COULD NOT BE REMOVED ({e}): it must not be verified, published or retained", out.display());
            eprintln!("zk60_trained_block stack-prove: {msg}");
            msg
        }
    }
}

/// **R5b (P-1, rulings M-9 / D12b(1)): where an UNVERIFIED run's prover-
/// written statement goes** — beside the run directory, never inside it:
/// `<out>.unverified-statement/`. Only `stack-verify`, after a fresh-process
/// verification of the directory passes, writes `<out>/statement/` — ITSELF,
/// from its own rendering and the hashes of the bytes it verified (NATIVE R6,
/// review r5_A) — and then removes this directory, so `statement/` always
/// means "this run verified, and these are the verified bytes".
fn unverified_statement_dir(out: &Path) -> Result<PathBuf, String> {
    let name = out.file_name().ok_or_else(|| format!("{}: the run directory has no name", out.display()))?;
    Ok(out.with_file_name(format!("{}.unverified-statement", name.to_string_lossy())))
}

/// the marker inside an unverified statement directory
const UNVERIFIED_MARKER: &str = "UNVERIFIED.txt";

/// NATIVE R6 (review r5 finding r5_A): the stack statement's schema. `/2`:
/// the writer is named (`statement_written_by`) and the prover's
/// self-reports are grouped and labelled (`prover_reported`, note N-r5-c).
const STACK_STATEMENT_SCHEMA: &str = "zk60-trained-stack-run/2";

/// NATIVE R6 (review r5 note N-r5-c): what the `prover_reported` fields are
const PROVER_REPORTED_WHAT: &str = "self-reports of the prover (privacy review P-7): a CPU proof and a GPU proof have the same form, so no verifier can check these fields";

/// **NATIVE R6 (review r5 finding r5_A): who wrote a stack statement.**
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum StatementWriter {
    /// `stack-prove` without a verification: `<run>.unverified-statement/`
    Unverified,
    /// `stack-prove --verify-in-process`, after its in-process verification
    /// of the run directory: `<run>/statement/`
    InProcess,
    /// `stack-verify`, after its fresh-process verification of the run
    /// directory: `<run>/statement/`, written by the verifier itself
    FreshVerify,
}

impl StatementWriter {
    const ALL: [StatementWriter; 3] = [StatementWriter::Unverified, StatementWriter::InProcess, StatementWriter::FreshVerify];
    fn text(self) -> &'static str {
        match self {
            StatementWriter::Unverified => "stack-prove, WITHOUT a verification (unverified: only stack-verify publishes a statement for this run)",
            StatementWriter::InProcess => "stack-prove, after its in-process verification of the run directory (--verify-in-process)",
            StatementWriter::FreshVerify => "stack-verify, after its fresh-process verification of the run directory, from its own data and the hashes of the bytes it verified",
        }
    }
}

/// **NATIVE R7 (privacy review round 2, Q-2): the backend names a statement
/// may carry** — build constants, never request- or input-derived text (the
/// class C-R4 closed for the context label). The first is byte for byte
/// what every R5b / R6 CPU build wrote, so their statements stay valid; the
/// device's own description (`gpu::label()`, with its name and memory) goes
/// to the prover's stdout only.
pub(crate) const BACKEND_CPU_BUILD: &str = "gpu: off (built without --features gpu-cuda)";
/// a `gpu-cuda` build whose device path is not live: the proof is the CPU's
pub(crate) const BACKEND_CUDA_BUILD_CPU_PATH: &str = "gpu: off (built with gpu-cuda; the device path not live)";
/// a `gpu-cuda` build whose device path is live
pub(crate) const BACKEND_CUDA: &str = "gpu: on (built with gpu-cuda; the device path live)";
pub(crate) const BACKENDS: [&str; 3] = [BACKEND_CPU_BUILD, BACKEND_CUDA_BUILD_CPU_PATH, BACKEND_CUDA];
/// the most GPU declines a statement may report (a count of declined device
/// calls; a backend on the CPU path reports none)
pub(crate) const MAX_GPU_DECLINES: u64 = 4096;

/// this process's backend name, from the build and the device state only
pub(crate) fn backend_of_this_process() -> &'static str {
    if !cfg!(feature = "gpu-cuda") {
        BACKEND_CPU_BUILD
    } else if crate::gpu::enabled() {
        BACKEND_CUDA
    } else {
        BACKEND_CUDA_BUILD_CPU_PATH
    }
}

/// **NATIVE R7 (Q-2): the `prover_reported` fields a statement may carry**,
/// checked by the prover before it writes one and by the verifier before it
/// publishes one: `backend` one of [`BACKENDS`] exactly, `gpu_declines` 0 on
/// the CPU path and at most [`MAX_GPU_DECLINES`] with the device. Anything
/// else is refused by name, and the prover-chosen text is not echoed.
pub(crate) fn check_prover_reported(backend: &str, gpu_declines: u64) -> Result<(), String> {
    if !BACKENDS.contains(&backend) {
        return Err(format!("prover_reported.backend ({} bytes) is not one of the build's backend names {BACKENDS:?} (privacy review round 2, Q-2)", backend.len()));
    }
    if backend != BACKEND_CUDA && gpu_declines != 0 {
        return Err(format!("prover_reported.gpu_declines is {gpu_declines} with a CPU-path backend; it must be 0 (privacy review round 2, Q-2)"));
    }
    if gpu_declines > MAX_GPU_DECLINES {
        return Err(format!("prover_reported.gpu_declines exceeds {MAX_GPU_DECLINES} (privacy review round 2, Q-2)"));
    }
    Ok(())
}

/// **NATIVE R6 (review r5 note N-r5-c): the prover's self-reports** (privacy
/// review P-7). Copied into a verifier-written statement only under
/// `prover_reported`, and only from a prover statement that is byte for byte
/// the canonical rendering with these values.
#[derive(Clone, Debug, PartialEq, Eq)]
struct ProverClaims {
    backend: String,
    gpu_declines: u64,
}

impl ProverClaims {
    fn of_this_process() -> ProverClaims {
        ProverClaims { backend: backend_of_this_process().to_string(), gpu_declines: crate::gpu::declines() as u64 }
    }

    /// the writer and the claims a stack `statement.json` names (the strict
    /// parser refuses duplicate keys and trailing bytes); the caller then
    /// re-renders with them and compares byte for byte
    fn of_statement(bytes: &[u8]) -> Result<(StatementWriter, ProverClaims), String> {
        let j = parse_json(bytes).map_err(|e| format!("statement.json: {e}"))?;
        if j.get("schema").and_then(J::str).map_err(|e| format!("statement.json: {e}"))? != STACK_STATEMENT_SCHEMA {
            return Err(format!("statement.json: not schema {STACK_STATEMENT_SCHEMA}"));
        }
        let by = j.get("statement_written_by").and_then(J::str).map_err(|e| format!("statement.json: {e}"))?;
        let writer = StatementWriter::ALL.iter().copied().find(|w| w.text() == by).ok_or("statement.json: an unknown writer")?;
        let pr = j.get("prover_reported").map_err(|e| format!("statement.json: {e}"))?;
        let backend = pr.get("backend").and_then(J::str).map_err(|e| format!("statement.json: prover_reported: {e}"))?;
        let d = pr.get("gpu_declines").and_then(J::i64).map_err(|e| format!("statement.json: prover_reported: {e}"))?;
        let gpu_declines = u64::try_from(d).map_err(|_| "statement.json: prover_reported.gpu_declines is negative".to_string())?;
        // NATIVE R7 (privacy review round 2, Q-2): build constants only
        check_prover_reported(backend, gpu_declines).map_err(|e| format!("statement.json: {e}"))?;
        Ok((writer, ProverClaims { backend: backend.to_string(), gpu_declines }))
    }
}

/// the `segments.json` of a run: one entry per segment, its file name, length
/// and SHA-256 (from the prover's sink, or from the bytes a verification
/// consumed)
pub(crate) fn render_segments_json(seen: &[(u64, String)]) -> String {
    let segs: Vec<String> = seen.iter().enumerate().map(|(k, (n, h))| format!("{{\"file\":{},\"bytes\":{n},\"sha256\":{}}}", js(&super::run_sink::segment_file_name(k)), js(h))).collect();
    format!("[\n {}\n]\n", segs.join(",\n "))
}

/// the text of the marker inside an unverified statement directory
const UNVERIFIED_TEXT: &[u8] = b"The prover wrote this statement WITHOUT verifying the run. It is not a public statement: only `stack-verify`, after a fresh-process verification of the run directory passes, writes <run>/statement/ itself (rulings M-9 / D12b(1); review r5_A).\n";

/// **NATIVE R6 (review r5 finding r5_A, (c) and (d)).** A statement directory
/// as found: a REAL directory (a symbolic link is refused by name, never
/// followed) holding exactly `names`, each a regular file. Anything else —
/// an extra file, a link, a FIFO, a subdirectory — is refused.
pub(crate) fn check_statement_dir(dir: &Path, names: &[&str]) -> Result<(), String> {
    let m = std::fs::symlink_metadata(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
    if m.file_type().is_symlink() {
        return Err(format!("{} is a symbolic link; a statement directory is never followed (review r5_A)", dir.display()));
    }
    if !m.is_dir() {
        return Err(format!("{} is not a directory", dir.display()));
    }
    let mut found: Vec<String> = Vec::new();
    for e in std::fs::read_dir(dir).map_err(|e| format!("{}: {e}", dir.display()))? {
        let e = e.map_err(|e| format!("{}: {e}", dir.display()))?;
        let name = e.file_name().to_string_lossy().to_string();
        let fm = std::fs::symlink_metadata(e.path()).map_err(|er| format!("{}: {er}", e.path().display()))?;
        if !fm.file_type().is_file() {
            return Err(format!("{}: `{name}` is not a regular file (review r5_A)", dir.display()));
        }
        found.push(name);
    }
    found.sort();
    let mut want: Vec<String> = names.iter().map(|s| s.to_string()).collect();
    want.sort();
    if found != want {
        return Err(format!("{} holds {found:?}, not exactly {want:?} (review r5_A)", dir.display()));
    }
    Ok(())
}

/// **NATIVE R7 (review r6 note N-r6-b): a `statement.writing-<pid>` left in
/// a run directory.** `publish_statement_dir` writes into
/// `<run>/statement.writing-<pid>` and renames it; a verifier killed in
/// between leaves the directory behind, and the run directory's own listing
/// (`run_sink::segment_paths`) then refuses the run as "not one of this
/// run's segments" — every later verification blocked until a person
/// removes it. Before anything of the run is read, each such entry is:
///
/// * REMOVED when it is a real directory (never a link: refused by name),
///   holding only files this function's writer writes (`expected.bin`,
///   `statement.json`, `segments.json`, each a regular file) and its pid is
///   not a live process (`/proc/<pid>` absent); a removal publishes nothing
///   and cannot make another writer publish anything (a writer in another
///   pid namespace whose directory is removed fails its own rename);
/// * REFUSED by name, with what to do, otherwise: a live pid (a verifier of
///   this run is publishing now, or the pid was reused), a link, a
///   non-directory, or other contents.
///
/// Returns the paths removed (stdout names each).
pub(crate) fn clear_stale_writing_dirs(art: &Path) -> Result<Vec<PathBuf>, String> {
    let prefix = format!("{}.writing-", super::run_sink::STATEMENT_DIR);
    let mut removed = Vec::new();
    let rd = match std::fs::read_dir(art) {
        Ok(rd) => rd,
        // the run directory's own checks name a missing directory
        Err(_) => return Ok(removed),
    };
    for e in rd {
        let e = e.map_err(|er| format!("{}: {er}", art.display()))?;
        let name = e.file_name().to_string_lossy().to_string();
        let Some(rest) = name.strip_prefix(&prefix) else { continue };
        let path = e.path();
        let hint = format!("remove {} by hand once no verifier of this run is running (review N-r6-b)", path.display());
        let pid: u32 = match rest.parse() {
            Ok(p) if !rest.is_empty() && rest.bytes().all(|b| b.is_ascii_digit()) => p,
            _ => return Err(format!("{} is not a statement directory this verifier writes (`{prefix}<pid>`); {hint}", path.display())),
        };
        let m = std::fs::symlink_metadata(&path).map_err(|er| format!("{}: {er}", path.display()))?;
        if m.file_type().is_symlink() || !m.is_dir() {
            return Err(format!("{} is not a real directory (a link or a file); it is never followed; {hint}", path.display()));
        }
        if Path::new("/proc").join(pid.to_string()).exists() {
            return Err(format!("{}: process {pid} is alive — a verifier of this run may be publishing its statement now, or the pid was reused; wait for it, or {hint}", path.display()));
        }
        for f in std::fs::read_dir(&path).map_err(|er| format!("{}: {er}", path.display()))? {
            let f = f.map_err(|er| format!("{}: {er}", path.display()))?;
            let fname = f.file_name().to_string_lossy().to_string();
            let fm = std::fs::symlink_metadata(f.path()).map_err(|er| format!("{}: {er}", f.path().display()))?;
            if !["expected.bin", "statement.json", "segments.json"].contains(&fname.as_str()) || !fm.file_type().is_file() {
                return Err(format!("{} holds `{fname}`, which this verifier never writes; it is left in place; {hint}", path.display()));
            }
        }
        std::fs::remove_dir_all(&path).map_err(|er| format!("{}: {er}; {hint}", path.display()))?;
        println!("{{\"event\":\"stale-statement-writing-removed\",\"path\":{},\"pid\":{pid},\"why\":\"left by a verifier that is no longer running (review N-r6-b)\"}}", js(&path.display().to_string()));
        removed.push(path);
    }
    Ok(removed)
}

/// **NATIVE R6 (review r5 finding r5_A): publish `files` as `<run>/statement/`.**
/// The files are written into a NEW directory `<run>/statement.writing-<pid>`
/// (`create_dir` fails if it exists), then renamed to `statement/` after a
/// check that nothing is there. (Without `renameat2(RENAME_NOREPLACE)` — this
/// crate takes no `libc` — a writer of the run directory racing the check can
/// only make the rename replace an EMPTY directory or a link entry, or fail:
/// nothing of theirs is published.) On any failure the new directory is
/// removed.
pub(crate) fn publish_statement_dir(art: &Path, files: &[(&str, &[u8])]) -> Result<PathBuf, String> {
    let target = art.join(super::run_sink::STATEMENT_DIR);
    let tmp = art.join(format!("{}.writing-{}", super::run_sink::STATEMENT_DIR, std::process::id()));
    std::fs::create_dir(&tmp).map_err(|e| format!("{}: {e}", tmp.display()))?;
    let res = (|| -> Result<(), String> {
        for (name, bytes) in files {
            write_new(&tmp.join(name), bytes)?;
        }
        match std::fs::symlink_metadata(&target) {
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Ok(_) => return Err(format!("{} exists; a statement is never replaced (review r5_A)", target.display())),
            Err(e) => return Err(format!("{}: {e}", target.display())),
        }
        std::fs::rename(&tmp, &target).map_err(|e| format!("{} -> {}: {e}", tmp.display(), target.display()))
    })();
    if let Err(e) = res {
        let _ = std::fs::remove_dir_all(&tmp);
        return Err(e);
    }
    Ok(target)
}

#[cfg(test)]
thread_local! {
    static AFTER_VERIFY_HOOK: std::cell::RefCell<Option<Box<dyn FnOnce()>>> = const { std::cell::RefCell::new(None) };
}

/// NATIVE R6, TEST ONLY (review r5_3 (b)): `f` runs once, in this thread's
/// next `stack-verify`, between its verification and its statement checks —
/// the point where a writer of the run directory races the publication
#[cfg(test)]
pub(crate) fn after_verify_hook_for_tests(f: Box<dyn FnOnce()>) {
    AFTER_VERIFY_HOOK.with(|h| *h.borrow_mut() = Some(f));
}

/// NATIVE R6, TEST ONLY: the trained statement identity a stack verifier
/// over every layer of this export would pin (the digest pass alone)
#[cfg(test)]
pub(crate) fn stack_identity_for_tests(export: &Path) -> Result<Digest, String> {
    let ex = TrainedExport::load(export)?;
    let layers = ex.layers.clone();
    let (_, _, _, _, st) = stack_records(&ex, &layers, false)?;
    Ok(st.identity())
}

#[allow(clippy::too_many_arguments)]
fn render_stack_statement(ex: &TrainedExport, sh: &Shape, layers: &[LayerMeta], st: &TrainedModelStatement, ctx: &Digest, expected: &ExpectedIo, label: &str, writer: StatementWriter, claims: &ProverClaims) -> String {
    let c = sh.norm_calibration();
    let recs: Vec<String> = layers
        .iter()
        .map(|l| {
            // NATIVE R8 (R6 for sh_s): a layer's own constants, when it has
            // any, under their export keys in the canonical order (`sh_s`
            // first, so an sh_s-only record renders as in R6)
            let own: String = l.record.own.iter().enumerate().filter_map(|(i, v)| v.map(|v| format!(", \"{}\": {v}", OWN_FIELDS[i].0))).collect();
            format!("{{\"layer\": {}, \"block_digest\": {}, \"manifest_sha256\": {}, \"silu_member\": [{}, {}], \"exp_e_s\": {}{own}}}", l.index, js(&hex(&l.record.block_digest)), js(&hex(&l.manifest_sha256)), l.record.silu_member.0, l.record.silu_member.1, l.record.exp_e_s)
        })
        .collect();
    format!(
        "{{\n \"schema\": \"{}\",\n \"scope\": {},\n \"statement_written_by\": {},\n \"prover_reported\": {{\"backend\": {}, \"gpu_declines\": {}, \"what\": {}}},\n \"block_profile\": {},\n \"run_profile\": {},\n \"blocks\": {},\n \"export_variant\": {},\n \"export_profile_sha256\": {},\n \"calibration_tool_sha256\": {},\n \"trained_statement_identity\": {},\n \"context_label\": {},\n \"context\": {},\n \"expected_io\": {},\n \"layers\": [\n  {}\n ],\n \"shape\": {{\"tokens\": {}, \"width\": {}, \"hidden\": {}, \"q_heads\": {}, \"kv_heads\": {}, \"head_dim\": {}, \"log_cols\": {}, \"inv_rate\": {}, \"opened_cols\": {}, \"f_e\": {}, \"wrho_s\": {}, \"norm_wrho\": {}, \"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_ao\": {}, \"sh_qkv\": {}, \"sh_s\": {}, \"sh_o\": {}, \"sh_g\": {}, \"sh_h\": {}, \"sh_z\": {}, \"d_max\": {}}}\n}}\n",
        STACK_STATEMENT_SCHEMA,
        js(stack_scope(ex.geometry)),
        js(writer.text()),
        js(&claims.backend),
        claims.gpu_declines,
        js(PROVER_REPORTED_WHAT),
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

/// NATIVE R12 (D38): the stack scope of a Shieldstral run (every earlier
/// model keeps [`STACK_SCOPE`] byte for byte)
const STACK_SCOPE_SHIELDSTRAL: &str = "ALL the listed trained blocks of Shieldstral-1.0-3B's text decoder as ONE bound run at the export's T (one transcript, hidden internal boundaries); the image encoder, the embedding, final norm, LM head and the verdict are NOT covered (D13, D38: the loader checks tied-table derivation from the pinned tensor; token-stage relations require their own review); CPU unless the run line says gpu; NOT a soundness or privacy acceptance; float fidelity is the calibration lane's measurement";

/// the stack scope of a geometry's run
fn stack_scope(g: Geometry) -> &'static str {
    if g.is_shieldstral() {
        STACK_SCOPE_SHIELDSTRAL
    } else {
        STACK_SCOPE
    }
}

const STACK_SCOPE: &str = "ALL the listed trained blocks of the export's model (TinyLlama-1.1B-Chat or Llama-3-8B) as ONE bound run at the export's T (one transcript, hidden internal boundaries); embedding, final norm, LM head and token selection are NOT covered (D13); CPU unless the run line says gpu; NO privacy acceptance at this shape (D22 covers only the toy); float fidelity is the calibration lane's measurement";

/// `stack-prove --export DIR (--seq ID | --seq-dir DIR) --out DIR
/// [--layers A..B] [--label L] [--rope-from-export] [--verify-in-process]
/// [--witness-cache-gib G] [--lie-at-boundary K]`
///
/// R5b (privacy review P-1). (1) THE DIGEST AND SEALING PASS, before
/// anything of the run exists: every layer loaded with all its checks and
/// digested, every block's witness built by the witness builder from the
/// previous block's output, with the builder's refusals and the parity check
/// against the export's `x_out` at EVERY layer ([`seal_and_record`]); an
/// inadmissible chain is refused here (ruling H-1). (2) The endpoints — the
/// builder's own first-input and last-output planes — are committed, the run
/// statement is bound to the trained-model statement. (3) THE PROVING PASS:
/// `run::prove_run_with` writes one segment per block into `--out` (a NEW
/// directory), handing out the sealed boundary planes and the kept witnesses
/// (rebuilding, and checking, any the `--witness-cache-gib` budget did not
/// keep; default 4). (4) With `--verify-in-process` the run is verified from
/// the directory and its public statement written to `<out>/statement/`;
/// WITHOUT it (the default since R5-2) the prover-written statement goes to
/// `<out>.unverified-statement/` and only `stack-verify`'s fresh-process
/// verification publishes `<out>/statement/`, written by the verifier itself
/// (rulings M-9 / D12b(1); NATIVE R6, review r5_A).
/// A run that fails after `--out` exists is removed, and a failed removal is
/// reported. `--lie-at-boundary K` is a CONTROL: the boundary plane after
/// block K is off by one word, and the run must then FAIL to verify (exit 0
/// means the control behaved). stdout from a run on a hidden input is
/// prover-private (privacy review P-6).
pub fn trained_stack_prove_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--seq", "--seq-dir", "--out", "--layers", "--label", "--lie-at-boundary", "--witness-cache-gib"], &["--rope-from-export", "--verify-in-process", "--dd"]) {
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
    let seq = SeqSource::of(f)?;
    let out = PathBuf::from(need(f, "--out")?);
    let label = label_of(f, &STACK_LABELS)?;
    let lie_at: Option<usize> = match flag(f, "--lie-at-boundary") {
        Some(v) => Some(v.parse().map_err(|_| "--lie-at-boundary is not an integer")?),
        None => None,
    };
    let budget_gib: f64 = match flag(f, "--witness-cache-gib") {
        Some(v) => v.parse().map_err(|_| "--witness-cache-gib is not a number")?,
        None => 4.0,
    };
    if !(0.0..=64.0).contains(&budget_gib) {
        return Err("--witness-cache-gib is outside 0..=64".into());
    }
    let unverified = unverified_statement_dir(&out)?;
    if out.exists() || unverified.exists() {
        return Err(format!("{} (or its unverified statement directory) exists; the run directory must be new", out.display()));
    }
    // ROUND 2 (R2-5): a claimed GPU run refuses to start unless the device
    // path is live, and any later decline aborts it (`gpu::declined`)
    crate::gpu::require_live()?;
    // NATIVE R6 (review r5 note N-r5-d): this stdout event is the prover's
    // START (the backend it runs on), printed before the sealing pass; it was
    // called `run_header`, which is the transcript's name for something that
    // happens only after the sealing pass
    println!("{{\"event\":\"prover_start\",\"gpu\":{},\"hl_gpu_required\":{}}}", js(&crate::gpu::label()), crate::gpu::required());
    let mut ex = TrainedExport::load(&export)?;
    // NATIVE R9 (D30): `--dd` proves / verifies under the DD profile of the
    // export's model and T (refused by name where none is registered)
    if flag(f, "--dd").is_some() {
        ex.geometry = ex.geometry.dd()?;
    }
    let layers = parse_layers(flag(f, "--layers"), &ex.layers)?;
    let l = layers.len();
    if let Some(k) = lie_at {
        if k + 1 >= l {
            return Err("--lie-at-boundary: there is no boundary after the last block".into());
        }
    }
    let rope = flag(f, "--rope-from-export").is_some();
    // ---- (1) the digest and sealing pass (ruling H-1): every refusal of an
    //      inadmissible chain happens here, before anything of the run exists
    let (c, sh, loaded, digests, st, chain, seal) = seal_and_record(&ex, &layers, rope, &seq, (budget_gib * (1u64 << 30) as f64) as u64)?;
    println!(
        "{{\"event\":\"loaded\",\"variant\":{},\"layers\":\"{}..{}\",\"blocks\":{l},\"statement_identity\":{},\"seconds\":{:.3},\"hl_gpu\":{},\"scope\":{}}}",
        js(&ex.variant),
        layers[0],
        layers[l - 1] + 1,
        js(&hex(&st.identity())),
        seal.wall_s,
        js(&std::env::var("HL_GPU").unwrap_or_else(|_| "unset".into())),
        js(stack_scope(ex.geometry))
    );
    let (kept_n, kept_bytes) = (chain.kept.iter().filter(|w| w.is_some()).count(), chain.kept_bytes);
    println!(
        "{{\"event\":\"sealed\",\"from\":\"the witness builder's own pass over layers {}..{} (parity bit-exact at every layer, before the run header: ruling H-1)\",\"seconds\":{:.3},\"of_which_load_seconds\":{:.3},\"of_which_witness_seconds\":{:.3},\"kept_witnesses\":{kept_n},\"kept_witness_bytes\":{kept_bytes},\"rayon_threads\":{}}}",
        layers[0],
        layers[l - 1] + 1,
        seal.wall_s,
        seal.load_s,
        seal.witness_s,
        rayon::current_num_threads()
    );
    println!("{{\"event\":\"parity\",\"result\":\"bit-exact at every layer\",\"layers\":{l},\"words_per_layer\":{},\"checked_before_the_run_header\":true}}", sh.tokens * sh.width);
    // ---- (2) the endpoints (the builder's own planes) and the bound run statement
    let ctx = stack_context(&ex.variant, &layers, label)?;
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &chain.first, &chain.last)?;
    let rst = RunStatement::new_bound_from_digests(ex.geometry.run_shape(&sh, l)?, ctx, expected.clone(), digests.clone(), &vec![(0, 0); l], &st)?;
    let cache = BlockCache::shared(&ex, &sh, &c, layers.clone(), digests.clone(), rope);
    let mut src = StackSource::new(&sh, cache.clone(), l, chain, lie_at)?;
    // ---- (3) the proving pass
    std::fs::create_dir(&out).map_err(|e| format!("{}: {e}", out.display()))?;
    let mut disk = match super::run_sink::DirSink::create(&out, l) {
        Ok(d) => d,
        Err(e) => return Err(fail_run(&out, e)),
    };
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
    let (rebuild_s, rebuilt) = (src.busy_s, src.chain.rebuilt);
    drop(src);
    if let Err(e) = stats {
        return Err(fail_run(&out, format!("prove_run: {e}")));
    }
    let hwm = peak_rss_mib();
    let (block_loads, block_load_s) = {
        let cb = cache.borrow();
        (cb.loads, cb.load_s)
    };
    drop(cache);
    // ---- (4) in-process verification from the directory (a fresh cache):
    //      OFF by default (R5-2) — then the statement is NOT published here
    let in_process = flag(f, "--verify-in-process").is_some() || lie_at.is_some();
    let t = Instant::now();
    let verdict = if in_process {
        let vcache = BlockCache::shared(&ex, &sh, &c, layers.clone(), digests.clone(), rope);
        run::verify_run_from_dir_hashed_with(&rst, &mut CacheBlocks(vcache), &out).map(Some)
    } else {
        Ok(None)
    };
    let verify_s = t.elapsed().as_secs_f64();
    if let Some(k) = lie_at {
        return match verdict {
            Ok(_) => Err(format!("CONTROL FAILED: a run whose boundary after block {k} was off by one word VERIFIED")),
            Err(e) => {
                println!("{{\"event\":\"control-refused\",\"control\":\"the boundary plane after block {k} off by one word\",\"error\":{}}}", js(&e.chars().take(200).collect::<String>()));
                Ok(())
            }
        };
    }
    let verified_seen = match verdict {
        Err(e) => return Err(fail_run(&out, format!("in-process verification of the run directory: {e}"))),
        Ok(v) => v,
    };
    // ---- the run's public statement: in <out>/statement/ only after a
    //      verification (M-9 / D12b(1)); otherwise beside the run, unverified.
    //      NATIVE R6 (review r5_A): an in-process verification's segments.json
    //      is the hashes of the bytes it verified, which must be the sink's
    let sunk: Vec<(u64, String)> = (0..l).map(|k| (disk.lengths()[k] as u64, disk.digests()[k].clone())).collect();
    let claims = ProverClaims::of_this_process();
    // NATIVE R7 (Q-2): the prover writes only the build's constants
    check_prover_reported(&claims.backend, claims.gpu_declines).map_err(|e| fail_run(&out, e))?;
    let sdir = match verified_seen {
        Some(seen) => {
            if seen != sunk {
                return Err(fail_run(&out, "in-process verification: the bytes it verified are not the bytes the prover wrote".into()));
            }
            let stmt = render_stack_statement(&ex, &sh, &loaded, &st, &ctx, &expected, label, StatementWriter::InProcess, &claims);
            publish_statement_dir(&out, &[("expected.bin", &expected.to_bytes()), ("statement.json", stmt.as_bytes()), ("segments.json", render_segments_json(&seen).as_bytes())]).map_err(|e| fail_run(&out, e))?
        }
        None => {
            std::fs::create_dir(&unverified).map_err(|e| format!("{}: {e}", unverified.display()))?;
            write_new(&unverified.join(UNVERIFIED_MARKER), UNVERIFIED_TEXT)?;
            write_new(&unverified.join("expected.bin"), &expected.to_bytes())?;
            write_new(&unverified.join("statement.json"), render_stack_statement(&ex, &sh, &loaded, &st, &ctx, &expected, label, StatementWriter::Unverified, &claims).as_bytes())?;
            write_new(&unverified.join("segments.json"), render_segments_json(&sunk).as_bytes())?;
            unverified.clone()
        }
    };
    println!(
        "{{\"event\":\"proved\",\"gpu\":{},\"gpu_declines\":{},\"blocks\":{l},\"receipt_bytes\":{},\"prove_run_seconds\":{prove_s:.3},\"of_which_witness_seconds\":{rebuild_s:.3},\"rebuilt_witnesses\":{rebuilt},\"witness_seconds_per_block\":{:.3},\"of_which_block_load_seconds\":{block_load_s:.3},\"block_loads\":{block_loads},\"rayon_threads\":{},\"in_process_verified\":{in_process},\"in_process_verify_seconds\":{verify_s:.3},\"sealing_pass_seconds\":{:.3},\"sealing_witness_seconds\":{:.3},\"load_seconds\":{:.3},\"total_seconds\":{:.3},\"vmhwm_mib\":{hwm:.0},\"statement_identity\":{},\"statement_dir\":{},\"out\":{}}}",
        js(&crate::gpu::label()),
        crate::gpu::declines(),
        disk.total_bytes(),
        (seal.witness_s + rebuild_s) / l as f64,
        rayon::current_num_threads(),
        seal.wall_s,
        seal.witness_s,
        seal.load_s,
        t_total.elapsed().as_secs_f64(),
        js(&hex(&st.identity())),
        js(&sdir.display().to_string()),
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
///
/// NATIVE R6 (review r5 finding r5_A): the statement found — the prover's
/// `<artifact>.unverified-statement/` or an existing `<artifact>/statement/`
/// — must be a real directory holding exactly its files, its
/// `statement.json` byte for byte this verifier's rendering (with the writer
/// and the prover's self-reports it names) and its `segments.json` the
/// hashes of the bytes this verification consumed. An unverified statement
/// is then replaced by one the VERIFIER writes into a fresh directory and
/// renames to `<artifact>/statement/` (never over an existing one); an
/// existing `statement/` is only checked.
pub fn trained_stack_verify_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--artifact", "--expect-statement", "--layers", "--label"], &["--rope-from-export", "--controls", "--dd"]) {
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
    let label = label_of(f, &STACK_LABELS)?;
    let t = Instant::now();
    // R5b (P-5): the verifier's export holds no prover-private seq_* entry
    refuse_prover_private_entries(&export)?;
    let mut ex = TrainedExport::load(&export)?;
    // NATIVE R9 (D30): `--dd` proves / verifies under the DD profile of the
    // export's model and T (refused by name where none is registered)
    if flag(f, "--dd").is_some() {
        ex.geometry = ex.geometry.dd()?;
    }
    let layers = parse_layers(flag(f, "--layers"), &ex.layers)?;
    let l = layers.len();
    let rope = flag(f, "--rope-from-export").is_some();
    let (c, sh, loaded, digests, st) = stack_records(&ex, &layers, rope)?;
    if st.identity() != pin {
        return Err(format!("the rebuilt trained statement {} is not the pinned {}", hex(&st.identity()), hex(&pin)));
    }
    let ctx = stack_context(&ex.variant, &layers, label)?;
    // NATIVE R7 (review r6 note N-r6-b): a statement directory a killed
    // verifier left half-written is removed (dead pid, only our files) or
    // refused by name with what to do, before the run directory is listed
    clear_stale_writing_dirs(&art)?;
    // R5b (P-1, M-9) and NATIVE R6 (review r5 finding r5_A): the policy comes
    // from <art>/statement/ (a run that verified before; checked byte for byte
    // against this verifier's own rendering below) or from the prover's
    // UNVERIFIED statement beside the run. Either must be a REAL directory
    // holding exactly its files (a symbolic link, an extra file or a
    // non-regular entry is refused before anything is read from it).
    let verified_dir = art.join(super::run_sink::STATEMENT_DIR);
    let unverified = unverified_statement_dir(&art)?;
    let present = |p: &Path| -> Result<bool, String> {
        match std::fs::symlink_metadata(p) {
            Ok(_) => Ok(true),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(false),
            Err(e) => Err(format!("{}: {e}", p.display())),
        }
    };
    let (sdir, promote) = match (present(&verified_dir)?, present(&unverified)?) {
        (true, true) => return Err(format!("{} and {} both exist; refused", verified_dir.display(), unverified.display())),
        (true, false) => (verified_dir.clone(), false),
        (false, true) => (unverified.clone(), true),
        (false, false) => return Err(format!("no statement: neither {} nor {} exists", verified_dir.display(), unverified.display())),
    };
    if promote {
        check_statement_dir(&sdir, &[UNVERIFIED_MARKER, "expected.bin", "statement.json", "segments.json"])?;
    } else {
        check_statement_dir(&sdir, &["expected.bin", "statement.json", "segments.json"])?;
    }
    // the policy bytes are read ONCE; the published copy is these bytes
    let expected_bytes = read_bounded(&sdir.join("expected.bin"), 4096)?;
    let expected = ExpectedIo::from_bytes_at(&sh, &expected_bytes)?;
    if expected.to_bytes() != expected_bytes {
        return Err("expected.bin is not the canonical encoding of its policy".into());
    }
    if expected.to_bytes()[8..40] != ctx {
        return Err("the artifact's endpoint policy carries another context".into());
    }
    let rst = RunStatement::new_bound_from_digests(ex.geometry.run_shape(&sh, l)?, ctx, expected.clone(), digests.clone(), &vec![(0, 0); l], &st)?;
    let load_s = t.elapsed().as_secs_f64();
    let t = Instant::now();
    let vcache = BlockCache::shared(&ex, &sh, &c, layers.clone(), digests.clone(), rope);
    // NATIVE R6 (r5_A (b)): the hashes of EXACTLY the bytes verified
    let seen = run::verify_run_from_dir_hashed_with(&rst, &mut CacheBlocks(vcache.clone()), &art)?;
    let verify_s = t.elapsed().as_secs_f64();
    let block_load_s = vcache.borrow().load_s;
    let total: u64 = seen.iter().map(|(n, _)| *n).sum();
    println!(
        "{{\"event\":\"verified\",\"blocks\":{l},\"receipt_bytes\":{total},\"load_seconds\":{load_s:.3},\"verify_seconds\":{verify_s:.3},\"of_which_block_load_seconds\":{block_load_s:.3},\"vmhwm_mib\":{:.0},\"statement_identity\":{},\"scope\":{}}}",
        peak_rss_mib(),
        js(&hex(&st.identity())),
        js(stack_scope(ex.geometry))
    );
    if flag(f, "--controls").is_some() {
        stack_controls(&ex, &c, &sh, &layers, &digests, rope, &loaded, &st, ctx, &expected, &art)?;
    }
    // review r5_3 (b), test builds only: a writer of the run directory acts
    // HERE, after the verification and before the statement checks
    #[cfg(test)]
    if let Some(h) = AFTER_VERIFY_HOOK.with(|h| h.borrow_mut().take()) {
        h();
    }
    // ---- NATIVE R6 (review r5 finding r5_A): the statement is bound to what
    //      was verified. The found statement.json must be, byte for byte, this
    //      verifier's rendering (its own export, shape, identity, context and
    //      policy) with the writer and prover self-reports it names, and the
    //      found segments.json must be the hashes of the verified bytes.
    let segs_json = render_segments_json(&seen);
    let found_stmt = read_bounded(&sdir.join("statement.json"), MAX_JSON_BYTES)?;
    let found_segs = read_bounded(&sdir.join("segments.json"), MAX_JSON_BYTES)?;
    let (writer, claims) = ProverClaims::of_statement(&found_stmt).map_err(|e| format!("{}: {e} (review r5_A)", sdir.display()))?;
    let allowed: &[StatementWriter] = if promote { &[StatementWriter::Unverified] } else { &[StatementWriter::InProcess, StatementWriter::FreshVerify] };
    if !allowed.contains(&writer) {
        return Err(format!("{}: statement.json names the writer \"{}\", which does not write this directory (review r5_A)", sdir.display(), writer.text()));
    }
    if render_stack_statement(&ex, &sh, &loaded, &st, &ctx, &expected, label, writer, &claims).as_bytes() != found_stmt.as_slice() {
        return Err(format!("{}: statement.json is not, byte for byte, this verifier's rendering of the verified run (review r5_A)", sdir.display()));
    }
    if found_segs != segs_json.as_bytes() {
        return Err(format!("{}: segments.json does not name the bytes this verification consumed (review r5_A)", sdir.display()));
    }
    if !promote {
        println!("{{\"event\":\"statement-checked\",\"dir\":{},\"writer\":{},\"result\":\"byte for byte this verifier's rendering of the verified run\"}}", js(&sdir.display().to_string()), js(writer.text()));
        return Ok(());
    }
    if read_bounded(&sdir.join(UNVERIFIED_MARKER), 4096)? != UNVERIFIED_TEXT {
        return Err(format!("{}: the marker is not the prover's marker (review r5_A)", sdir.display()));
    }
    // ---- publication: the VERIFIER writes <run>/statement/ itself, from its
    //      own rendering and the bytes it verified, into a fresh directory
    let stmt = render_stack_statement(&ex, &sh, &loaded, &st, &ctx, &expected, label, StatementWriter::FreshVerify, &claims);
    let published = publish_statement_dir(&art, &[("expected.bin", &expected_bytes), ("statement.json", stmt.as_bytes()), ("segments.json", segs_json.as_bytes())])?;
    // then the prover's unverified directory goes: re-checked as a real
    // directory, never followed (`remove_dir_all` removes a link itself)
    let um = std::fs::symlink_metadata(&unverified).map_err(|e| format!("{}: {e}", unverified.display()))?;
    if um.file_type().is_symlink() || !um.is_dir() {
        return Err(format!("{} changed into a non-directory after the verification; the published statement stands, the entry is left in place (review r5_A)", unverified.display()));
    }
    std::fs::remove_dir_all(&unverified).map_err(|e| format!("{}: {e}", unverified.display()))?;
    println!("{{\"event\":\"statement-published\",\"by\":\"stack-verify, from its own rendering and the hashes of the verified bytes\",\"to\":{},\"prover_statement_removed\":{}}}", js(&published.display().to_string()), js(&unverified.display().to_string()));
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn stack_controls(ex: &TrainedExport, rc: &Constants, sh: &Shape, layers: &[u32], digests: &[Digest], rope: bool, loaded: &[LayerMeta], st: &TrainedModelStatement, ctx: Digest, expected: &ExpectedIo, art: &Path) -> Result<(), String> {
    let l = layers.len();
    if l < 2 {
        return Err("trained stack: the run-level controls need at least two blocks".into());
    }
    // REVIEW r3_6: the segments are read through the run verifier's BOUNDED
    // reader, each against its counted length in the honest run statement
    // (checked from metadata before the file is opened)
    let honest = RunStatement::new_bound_from_digests(ex.geometry.run_shape(sh, l)?, ctx, expected.clone(), digests.to_vec(), &vec![(0, 0); l], st)?;
    let mut segs: Vec<Vec<u8>> = super::run_sink::segment_paths(art, l)?.iter().enumerate().map(|(k, p)| run::read_segment_bounded(&honest, k, p)).collect::<Result<_, _>>()?;
    drop(honest);
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
    // ROUND 5 (evening): a calibration control whose verifier CAN be built
    // (shape, statement, policy at the moved constant) must be refused by
    // the WIRE's binding of that verifier's own statement (the segment
    // header's run tag, or the counted length when the layout moves), never
    // by an earlier API guard, so a control that stops reaching the binding
    // fails the run. (A verifier that cannot be built at all — e.g. the
    // rung-TC geometry fixes f_e — is a refusal of its own, as before.)
    let by_the_binding = |name: &str, built: Result<Result<(), String>, String>| -> Result<Result<(), String>, String> {
        match built {
            Err(e) => Ok(Err(e)),
            Ok(Err(e)) if !e.starts_with("private run wire:") => Err(format!("CONTROL WEAK: `{name}` was refused by `{}`, before the run binding it tests", e.chars().take(160).collect::<String>())),
            Ok(r) => Ok(r),
        }
    };
    // (2) one calibration constant moved (the verifier's shape and statement)
    for (name, v) in [("norm_cn_a + 1", NormCalibration { cn_a: rc.cal.cn_a + 1, ..rc.cal }), ("sh_z moved by one", NormCalibration { sh_z: nudge(rc.cal.sh_z, 1, 8), ..rc.cal }), ("sh_qkv moved by one", NormCalibration { sh_qkv: nudge(rc.cal.sh_qkv, 1, 8), ..rc.cal })] {
        let built = (|| -> Result<Result<(), String>, String> {
            let s2 = ex.geometry.shape_at(&v, rc.f_e)?;
            let st2 = ex.statement_of_records(&s2, &Constants { cal: v, ..rc.clone() }, loaded.iter().map(|m| m.record.clone()).collect())?;
            let e2 = ExpectedIo::from_bytes_at(&s2, &expected.to_bytes())?;
            Ok(run_with(&ident, &st2, &s2, &e2, &segs))
        })();
        let name = format!("a verifier statement with {name}");
        let r = by_the_binding(&name, built)?;
        refuse(&name, r)?;
    }
    // (2b) review finding F-1: f_e moved by one inside its declared class
    {
        let fe2 = nudge(rc.f_e, *super::shape::TRAINED_F_E_RANGE.start(), *super::shape::TRAINED_F_E_RANGE.end());
        let built = (|| -> Result<Result<(), String>, String> {
            let s2 = ex.geometry.shape_at(&rc.cal, fe2)?;
            let st2 = ex.statement_of_records(&s2, &Constants { f_e: fe2, ..rc.clone() }, loaded.iter().map(|m| m.record.clone()).collect())?;
            let e2 = ExpectedIo::from_bytes_at(&s2, &expected.to_bytes())?;
            Ok(run_with(&ident, &st2, &s2, &e2, &segs))
        })();
        let r = by_the_binding("a verifier statement with f_e moved by one", built)?;
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

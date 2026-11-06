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

#[path = "trained_accuracy.rs"]
mod accuracy;

pub(crate) const PROFILE_SCHEMA: &str = "zk60-trained-profile-export/1";
pub(crate) const ACCURACY_PROFILE_SCHEMA:&str="zk60-trained-profile-export/2";
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

fn constants_of(c:&J,what:&str,rope_pin:f64)->Result<Constants,String> {
    constants_for_stack(c,what,rope_pin,super::accuracy_precision::Stack::Legacy)
}
fn constants_for_stack(c:&J,what:&str,rope_pin:f64,stack:super::accuracy_precision::Stack)->Result<Constants,String> {
    let ctx = |e: String| format!("{what}: {e}");
    let int = |k: &str| -> Result<i64, String> { c.get(k).and_then(J::i64).map_err(|e| format!("{what}: constant `{k}`: {e}")) };
    for (k, want) in fixed_constants() {
        // sh_u=0 remains the BASE export shift; R13 derives effective12.
        // F_P is a fixed arithmetic constant and v2 must declare12.
        let want=if k=="f_p" && stack!=super::accuracy_precision::Stack::Legacy {12} else {want};
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
    tied_of_with_derivation(dir, p, geometry, source).map(|(t, _)| t)
}

/// **TOKEN ROUND 16 (token review N-r13-5): the loader's tied-table
/// derivation, kept.** A tied export whose `profile.json` names well-formed
/// `classifier_margin_parameters` (`yes_id`, `no_id` below the vocabulary and
/// distinct, a finite positive `public_scale`) has the classifier difference
/// row derived in the SAME authenticated pass; the classifier loader then
/// reuses it (after every one of its own checks) instead of streaming the
/// 7.7 GB checkpoint a second time. The admission rule of the load is
/// unchanged: if the pass with the row is refused, the pass without it
/// decides (the classifier's own derivation then refuses the row by name).
pub(crate) struct TiedDerivation {
    /// the `(yes, no, public_scale bits)` the row was derived with, if any
    pub margin: Option<(u32, u32, u64)>,
    pub tables: super::tied_tables::RecomputedTiedTables,
}

fn declared_classifier_margin(p: &J) -> Option<(u32, u32, f64)> {
    let m = p.opt("classifier_margin_parameters")?;
    let id = |k: &str| m.opt(k).and_then(|v| v.i64().ok()).and_then(|v| u32::try_from(v).ok());
    let (yes, no) = (id("yes_id")?, id("no_id")?);
    let scale = m.opt("public_scale").and_then(|v| v.f64().ok())?;
    (yes != no && (yes as usize) < 131_072 && (no as usize) < 131_072 && scale.is_finite() && scale > 0.0).then_some((yes, no, scale))
}

pub(crate) fn tied_of_with_derivation(dir: &Path, p: &J, geometry: Geometry, source: &ModelSource) -> Result<(Option<TiedEmbedding>, Option<TiedDerivation>), String> {
    let profile = geometry.shape_profile();
    let decl = p.opt("tied_embeddings").filter(|v| **v != J::Null);
    let pin = tied_tensor_for_profile(profile);
    let (name, digest) = match (pin, decl) {
        (None, None) => return Ok((None, None)),
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
    // TOKEN ROUND 16 (N-r13-5): with the classifier row when the profile
    // names its parameters; the pass without it decides when that is refused
    let margin = declared_classifier_margin(p);
    let (derived, kept_margin) = match margin.map(|m| super::tied_tables::recompute_declared_tied_tables_with_margin(dir, p, Some(m))) {
        Some(Ok(d)) => (d, margin.map(|(y, n, s)| (y, n, s.to_bits()))),
        _ => (super::tied_tables::recompute_declared_tied_tables(dir, p)?, None),
    };
    for (what, actual, expected) in [("embedding", emb, derived.embedding_sha256), ("head", head, derived.head_sha256), ("head multipliers", mult, derived.multipliers_sha256)] {
        if actual != expected {
            return Err(format!("tied {what}: integer table is not derived from the pinned tensor under the export's quantizer"));
        }
    }
    Ok((Some(TiedEmbedding { tensor: name.into(), tensor_sha256: digest, embedding_table_sha256: emb, head_table_sha256: head, head_mult_sha256: mult }), Some(TiedDerivation { margin: kept_margin, tables: derived })))
}

fn table_keys_of(c:&J,what:&str)->Result<TableKeys,String> {
    table_keys_for_registry(c,what,None)
}
fn table_keys_for_registry(c:&J,what:&str,registry:Option<super::accuracy_tables::Registry>)->Result<TableKeys,String> {
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
    let member_ok=match registry {
        Some(r)=>r.permits(tk.silu),
        None=>crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu,tk.silu.0,tk.silu.1).is_some(),
    };
    if !member_ok {
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
        if sh.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {return RunShape::accuracy(sh.clone(),l);}

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
    pub accuracy_stack:super::accuracy_precision::Stack,
    pub accuracy_dd:bool,
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
    /// TOKEN ROUND 16 (N-r13-5): the load's tied derivation (tied models
    /// only), reused by the classifier loader
    pub tied_derivation: Option<TiedDerivation>,
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
    pub(crate) fn run_profile(&self)->&'static str {
        match accuracy::profile_for(self.geometry,self.accuracy_stack,self.accuracy_dd) {
            Ok(block)=>super::run::accuracy_run_profile(block).expect("registered R13 run profile"),
            Err(_) if self.accuracy_stack==super::accuracy_precision::Stack::Legacy=>self.geometry.run_profile(),
            Err(e)=>panic!("invalid R13 export geometry/stack: {e}"),
        }
    }
    fn enable_dd(&mut self)->Result<(),String> {
        if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {self.geometry=self.geometry.dd()?;}
        else {accuracy::profile_for(self.geometry,self.accuracy_stack,true)?;self.accuracy_dd=true;}
        Ok(())
    }

    /// Read `<dir>/profile.json` (`dir` is the variant directory).
    pub(crate) fn load(dir: &Path) -> Result<TrainedExport, String> {
        let path = dir.join("profile.json");
        let bytes = read_bounded(&path, MAX_JSON_BYTES)?;
        let p = parse_json(&bytes).map_err(|e| format!("{}: {e}", path.display()))?;
        let ctx = |e: String| format!("{}: {e}", path.display());
        let schema = p.get("schema").and_then(J::str).map_err(ctx)?;
        let accuracy_stack=match schema {
            PROFILE_SCHEMA=>{
                if p.opt("accuracy_stack").is_some() {return Err(ctx("legacy export cannot select R13 arithmetic".into()));}
                super::accuracy_precision::Stack::Legacy
            },
            ACCURACY_PROFILE_SCHEMA=>super::accuracy_precision::Stack::from_export_name(p.get("accuracy_stack").and_then(J::str).map_err(ctx)?).map_err(ctx)?,
            _=>return Err(ctx(format!("unsupported schema `{schema}`"))),
        };
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
        if accuracy_stack!=super::accuracy_precision::Stack::Legacy {
            accuracy::profile_for(geometry,accuracy_stack,false).map_err(ctx)?;
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
        let constants = if nulls.iter().all(|k| !RUN_LEVEL_KEYS.contains(&k.as_str())) { Some(constants_for_stack(pc,&path.display().to_string(),geometry.rope_theta(),accuracy_stack)?) } else { None };
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
        let (tied, tied_derivation) = tied_of_with_derivation(dir, &p, geometry, &source).map_err(ctx)?;
        Ok(TrainedExport {
            dir: dir.to_path_buf(),
            geometry,
            accuracy_stack,
            accuracy_dd:false,
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
            tied_derivation,
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
            let c = constants_for_stack(m.get("constants").map_err(|e|format!("{}: {e}",mpath.display()))?,&mpath.display().to_string(),self.geometry.rope_theta(),self.accuracy_stack)?;
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
        let sh=if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {
            self.geometry.shape_at(&c.cal,c.f_e)?
        } else {
            // Geometry seed only. A loaded layer's record carries its G.
            Shape::accuracy_trained(accuracy::profile_for(self.geometry,self.accuracy_stack,self.accuracy_dd)?,&c.cal,c.f_e,17)?
        };
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
        let lc = constants_for_stack(m.get("constants").map_err(ctx)?,&mpath.display().to_string(),self.geometry.rope_theta(),self.accuracy_stack)?;
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
        let tk=table_keys_for_registry(m.get("constants").map_err(ctx)?,&mpath.display().to_string(),
            if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {None} else {Some(sh.accuracy_registry())})?;
        if sh.norm_calibration() != c.cal || sh.f_e != c.f_e {
            return Err(ctx("the shape was not built from the run's constants".into()));
        }
        let arrays = m.get("arrays").map_err(ctx)?;
        let accuracy_loaded=if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {
            for key in ["m_q","m_k","m_v","m_o","m_g","m_u","m_d","silu_groups","silu_group_ids"] {
                if arrays.opt(key).is_some() {return Err(ctx(format!("legacy export carries R13 array `{key}`")));}
            }
            None
        } else {
            let local=sh.with_layer_calibration(&lc.cal).map_err(ctx)?;
            let geometry=super::accuracy_public::Geometry{width:local.width,query_width:local.q_width(),kv_width:local.kv_heads*local.head_dim,hidden:local.hidden};
            // Read/hash narrow public data before any large weight array.
            Some(accuracy::load_for_registry(local.accuracy_registry(),&dir,arrays,self.accuracy_stack,geometry,local.accuracy_base(),tk.silu).map_err(ctx)?)
        };

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
            expect.par_iter().filter(|(name,_,_)|self.accuracy_stack==super::accuracy_precision::Stack::Legacy || *name!="act").map(|(name, dt, shp)| load_array_checked(&dir, name, arrays.get(name).map_err(ctx)?, full, &[(*dt, *shp)]).map_err(|e| format!("layer {index}: {e}"))).collect::<Vec<_>>().into()
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
        let act=if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {
            let a=get("act")?;a.expect("act",Dtype::I16,&[256])?;Some(a)
        } else {None};
        // the tables against the generators the run's constants name
        let (gexp, _) = crate::tables_attn::exp_member(tk.exp_e_s, sh.head_dim, c.f_e);
        if exp.i64s() != gexp.to_vec() {
            return Err(ctx(format!("the exported exp table is not exp_member(e_s = {}, head_dim = {}, f_e = {})", tk.exp_e_s, sh.head_dim, c.f_e)));
        }
        // R13's ACT relation uses AccuracyPublic exclusively. Keep the old
        // typed field at one canonical, fixed member; its bytes remain bound
        // by the block digest, and the actual raw ACT tables are recorded.
        let member=if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {tk.silu} else {(-3,-11)};
        let(gact,_)=crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu,member.0,member.1)
            .ok_or_else(||ctx(format!("unknown SiLU member {member:?}")))?;
        if let Some(act)=&act {if act.i16s()!=gact.to_vec() {
            return Err(ctx(format!("the exported act table is not the frozen SiLU member {:?}",tk.silu)));
        }}
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
        let ff=FeedForwardPublic::new_shaped(sh,&fw[0],&fw[1],&fw[2],&fw[3],&gact).map_err(ctx)?;
        let mut blk=BlockPublic::new(public,ff);
        if let Some(loaded)=accuracy_loaded {
            let g=loaded.accuracy.folds().gate.shift;
            blk=blk.with_accuracy(loaded.accuracy);
            let local=sh.with_layer_calibration(&lc.cal)?.with_accuracy_gate_shift(g)?;
            blk.check_accuracy_for_shape(&local).map_err(ctx)?;
        }
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
        record.accuracy_gate_shift=blk.accuracy().map(|a|a.folds().gate.shift);
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
        TrainedModelStatement::new_with_tied(sh, self.run_profile(), self.source.clone(), cal, records, self.tied.clone())
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
fn witness_for_block(sh:&Shape,blk:&BlockPublic,input:&[i16])->Result<Witness,String> {
    match blk.accuracy() {
        Some(data)=>{
            let local=sh.clone().with_accuracy_gate_shift(data.folds().gate.shift)?;
            witness::build_for_block(&local,blk,input)
        },
        None=>witness::build_shaped(sh,blk.attention(),blk.feed_forward(),input),
    }
}

pub(crate) fn parity(sh: &Shape, blk: &BlockPublic, x_in: &[i16], x_out: &[i16]) -> Result<Witness, String> {
    let w = witness_for_block(sh,blk,x_in).map_err(|e| format!("parity: the native witness REFUSES the exported input: {e}"))?;
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
        js(ex.run_profile()),
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
        // D65(2): one constant external refusal; the detail goes to the owner's private log
        Err(e) => refusal::refuse("trained-prove", &e),
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
        ex.enable_dd()?;
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
    let honest = || witness_for_block(sh,&layer.blk,x_in);
    let mid = (sh.tokens / 2) * sh.d_pad + sh.width / 3;
    let mut cases: Vec<(&str, Witness)> = Vec::new();
    let mut w = honest()?;
    w.planes[ids.at(A_Y)][mid] += if w.planes[ids.at(A_Y)][mid] < 127 { 1 } else { -1 };
    cases.push(("one norm_a output word moved by one", w));
    let mut w = honest()?;
    w.planes[ids.at(A_Q8)][mid] += if w.planes[ids.at(A_Q8)][mid] < 127 { 1 } else { -1 };
    cases.push(("one query activation moved by one", w));
    let c = sh.norm_calibration();
    let other = sh.with_layer_calibration(&NormCalibration { cn_m: c.cn_m + 7, ..c })?;
    cases.push(("a witness honest under norm_cn_m + 7", witness_for_block(&other,&layer.blk,x_in)?));
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
        ex.enable_dd()?;
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
        let mut blk2 = BlockPublic::new(pub2, layer.blk.feed_forward().clone());
        if let Some(a)=layer.blk.accuracy() {blk2=blk2.with_accuracy(a.clone());}
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
    /// ROUND 4: the shared one-block cache (and the run's block count);
    /// [A19] a D55 run's: the sealing pass's own blocks, or the model's reloads
    blocks: StackBlocks<'a>,
    n: usize,
    ids: Ids,
    chain: SealedChain,
    lie_at: Option<usize>,
    /// seconds spent REBUILDING witnesses in the proving pass
    busy_s: f64,
    /// [A15] the pool a rebuild runs in (the sealing pass's)
    pool: SealPool,
    /// [A19] the model's reloads for rebuilds (`StackBlocks::Model`) and their seconds
    reloads: (usize, f64),
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
    /// [A19] the witnesses handed to a D55 run's window (each now a fork's
    /// before-challenge part), and the bytes the budget counted for them
    handed: usize,
    part_bytes: u64,
}

/// **[A19] where a stack source's rebuilds take their block**: D12a's
/// one-block cache (unchanged), or a D55 run's: the blocks the sealing pass
/// loaded and keeps for the fork run, or (`HL_A19_SHARE=0`) the model's reload,
/// refused unless its digest is the statement's (the cache's own check)
enum StackBlocks<'a> {
    Cache(SharedCache<'a>),
    Sealed(&'a run::fork::SealedBlocks),
    Model(&'a dyn StackModel, &'a [Digest]),
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
    fn new(sh: &'a Shape, blocks: StackBlocks<'a>, n: usize, chain: SealedChain, lie_at: Option<usize>) -> Result<StackSource<'a>, String> {
        if chain.outs.len() != n || chain.kept.len() != n {
            return Err("trained stack: the sealed chain is not this run's".into());
        }
        Ok(StackSource { sh, blocks, n, ids: Ids::new(sh)?, chain, lie_at, busy_s: 0.0, pool: SealPool::get()?, reloads: (0, 0.0) })
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
        // [A15] a rebuild in the sealing pass's pool (on the fork feeder, beside the forks' own pools)
        let ssh = &self.chain.shapes[k];
        let w = match &self.blocks {
            StackBlocks::Cache(cache) => {
                let blk = cache.borrow_mut().get(k)?;
                let w = self.pool.run(|| witness_for_block(ssh,&blk,&x))?;
                drop(blk);
                w
            }
            // [A19] a D55 run's: the block the sealing pass loaded, or the model's reload
            StackBlocks::Sealed(blocks) => {
                let blk = run::fork::ForkBlocks::get(*blocks, k)?;
                self.pool.run(|| witness_for_block(ssh,blk,&x))?
            }
            StackBlocks::Model(m, digests) => {
                let tl = Instant::now();
                let blk = reload_checked(*m, k, digests)?;
                self.reloads.0 += 1;
                self.reloads.1 += tl.elapsed().as_secs_f64();
                self.pool.run(|| witness_for_block(ssh,&blk,&x))?
            }
        };
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
    /// [A15] the threads of the pool the witnesses were built in (0: the global pool)
    pool_threads: usize,
    /// [A20] the loads ahead of the build (0: one, beside it in a `rayon::join`), and
    /// the seconds the pass waited for a load (0 at `HL_A20_LOADS=0`, where the wait is
    /// inside the join)
    loads_ahead: usize,
    load_wait_s: f64,
}

// ---------------------------------------- [A15] the sealing pass's own rayon pool
//
// (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A15;
// `results/zk60_effplan_20261105/a15/README.md`.) The sealing pass is a chain of
// serial witness builds, each a run of many short parallel regions (the limb
// planes, the requantizations, the softmax heads, the weight scans: some 70 to 90
// per 8B block, an estimate from the code). On the 32-thread global pool each region
// wakes workers through rayon's sleep lock, and when it ends every idle worker
// spins on `yield_now` (a system call on macOS) before it sleeps again: the W16R2
// 8B pass alone took 4.0 s and 15 + 25 CPU-seconds (user + system), in a pool of 8
// threads 2.9 s and 7 + 2 (A15 stage 1, measured). Each build now runs inside a
// dedicated pool of `seal_pool_threads()` threads, every region inside it on that
// pool only; in a stream, the next request's sealing pass no longer shares the
// global pool with the current request's work. `HL_SEAL_POOL=0` restores the
// global pool.
//
// **Why no byte can move.** Which threads run the builder's parallel regions, and
// how many, changes no word: every one is an indexed write or an exact integer
// sum read back in order, with the sequential loop's first error (H124c); the
// products' split follows `current_num_threads` but each output word is one exact
// sum. `w16r2_tests::a15_*` compares every plane of a chain's witnesses built in
// pools of 1, 4, 8 and 16 threads and on the global pool, at the W16R2 rung and the
// 8B block. Test builds: thread-local builder switches do not cross into the pool
// (`seal_and_record`'s `rayon::join` already moved the build off the caller).

/// `HL_SEAL_POOL`: unset, empty or `auto`, the default ([`default_seal_pool_threads`]);
/// `0`, the global pool (the path before A15); `t`, a pool of `t` threads. As a test
/// override: `usize::MAX` none, [`SEAL_POOL_AUTO`] the default.
static SEAL_POOL_TEST: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(usize::MAX);
const SEAL_POOL_AUTO: usize = usize::MAX - 1;

/// [A15] the default size of the sealing pool on a machine of `cores` logical CPUs: a
/// quarter of them, at least 1 and at most 8. Measured on the 32-CPU M3 Ultra (A15
/// stage 2, in-process at N = 6, both orders, every pair): 8 threads gave one request
/// -11.0% and the 4-request stream's steady state +19.2% against the global pool; 12
/// gave -11.3% / +19.0% at 35% more sealing CPU, 16 -9.6% / +16.0%, 6 -11.3% / +16.0%,
/// 4 -5.4% / +8.7%. The builder's parallel work stops paying beyond about 8 threads
/// (the sealing pass alone: 2.94 s at 8, 3.05 at 12, 3.15 at 16), hence the cap.
fn default_seal_pool_threads(cores: usize) -> usize {
    (cores / 4).clamp(1, 8)
}

/// [A15] the threads of the sealing pass's pool (0: the global pool)
pub(crate) fn seal_pool_threads() -> usize {
    static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    let t = match SEAL_POOL_TEST.load(std::sync::atomic::Ordering::Relaxed) {
        usize::MAX => *ENV.get_or_init(|| match std::env::var("HL_SEAL_POOL").as_deref() {
            Err(_) | Ok("auto") | Ok("") => SEAL_POOL_AUTO,
            Ok(v) => v.parse::<usize>().map(|t| t.min(1024)).unwrap_or(SEAL_POOL_AUTO),
        }),
        t => t,
    };
    if t != SEAL_POOL_AUTO {
        return t;
    }
    default_seal_pool_threads(std::thread::available_parallelism().map(|n| n.get()).unwrap_or(1))
}

/// tests: the sealing pool of `t` threads (`Some(0)`: the global pool; `None`: as the
/// environment says). Changes no byte (see above).
#[cfg(test)]
pub(crate) fn set_seal_pool_for_test(threads: Option<usize>) {
    SEAL_POOL_TEST.store(threads.map(|t| t.min(1024)).unwrap_or(usize::MAX), std::sync::atomic::Ordering::Relaxed);
}

/// tests: the default rule
#[cfg(test)]
pub(crate) fn set_seal_pool_auto_for_test() {
    SEAL_POOL_TEST.store(SEAL_POOL_AUTO, std::sync::atomic::Ordering::Relaxed);
}

/// tests: the default rule's size at `cores` logical CPUs
#[cfg(test)]
pub(crate) fn default_seal_pool_threads_for_test(cores: usize) -> usize {
    default_seal_pool_threads(cores)
}

/// **[A15] the sealing pass's pool** (`None`: the global pool), made once per size
/// and kept for the process (an idle rayon thread sleeps)
#[derive(Clone)]
pub(crate) struct SealPool(Option<std::sync::Arc<rayon::ThreadPool>>);

impl SealPool {
    /// the pool `seal_pool_threads()` names
    pub(crate) fn get() -> Result<SealPool, String> {
        let t = seal_pool_threads();
        if t == 0 {
            return Ok(SealPool(None));
        }
        static POOLS: std::sync::Mutex<Vec<(usize, std::sync::Arc<rayon::ThreadPool>)>> = std::sync::Mutex::new(Vec::new());
        let mut g = POOLS.lock().map_err(|_| "the sealing pools' lock is poisoned".to_string())?;
        if let Some((_, p)) = g.iter().find(|(n, _)| *n == t) {
            return Ok(SealPool(Some(p.clone())));
        }
        let p = rayon::ThreadPoolBuilder::new().num_threads(t).thread_name(move |i| format!("hl-seal{t}-{i}")).build().map_err(|e| format!("the sealing pool of {t} threads: {e}"))?;
        let p = std::sync::Arc::new(p);
        g.push((t, p.clone()));
        Ok(SealPool(Some(p)))
    }
    /// the pool's threads (0: the global pool)
    pub(crate) fn threads(&self) -> usize {
        self.0.as_ref().map_or(0, |p| p.current_num_threads())
    }
    /// `f` (one witness build) on a thread of this pool, its parallel regions on this
    /// pool's threads only; on the caller's own pool when this is the global one
    pub(crate) fn run<R: Send>(&self, f: impl FnOnce() -> R + Send) -> R {
        match &self.0 {
            Some(p) => p.install(f),
            None => f(),
        }
    }
}

// ---------------------------------------- [A15] end

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
    // [A19] the model the pass reads (the export's run constants and shape,
    // first, as before); the pass itself is `seal_chain`, with nothing handed over
    let m = ExportStack::new(ex, seq, layers, rope_from_export, "")?;
    let (metas, digests, chain, mut times) = seal_chain(&m, budget_bytes, &mut NoHand)?;
    let st = m.statement_of_records(metas.iter().map(|m| m.record.clone()).collect())?;
    times.wall_s = t0.elapsed().as_secs_f64();
    let ExportStack { c, sh, .. } = m;
    Ok((c, sh, metas, digests, st, chain, times))
}

// ---------------------------------------- [A19] production's D55 path: the window and the shared blocks
//
// (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A19;
// `results/zk60_effplan_20261105/a19/README.md`.) Before A19 a D55 `stack-prove`
// ran the whole sealing pass, then built the bound statement (its endpoints are the
// sealed chain's first and last planes), the fork run and the run directory, then
// LOADED EVERY BLOCK AGAIN (`load_fork_blocks`) and proved. Now its D55 path is
// [`d55_seal_and_prove`]:
// * **the blocks are shared** (`HL_A19_SHARE`, default on; `0` restores the
//   reload): each block the sealing pass loaded, with every check, and built its
//   witness against is kept in a [`run::fork::SealedBlocks`] and is the object the
//   fork proves with (its digest is the statement's: the sealing pass's record);
// * **A13's window** (`HL_D55_AHEAD`, `run_fork.rs`): the first `W` admitted
//   witnesses are handed, as each block's checks pass, to side workers that make
//   each fork's before-challenge part during the sealing pass, from a
//   [`run::fork::ForkPlan`] made from the run shape before the pass; the
//   continuation builds the statement and the fork run, checks the plan against it
//   (before the run directory exists) and proves with the parts. The witness cache's
//   budget counts each part at its estimated host and device bytes.
// **H-1** (D29) is kept: every refusal of an inadmissible chain is still the sealing
// pass's (the builder's, CS-3's, the parity check, the first-plane check, the
// statement's), before anything of the run exists; a part is made only from a
// witness whose block passed every check, reads no transcript, absorbs nothing and
// leaves the process only as its fork's frame; a refused chain stops the side
// workers and drops every part before `stack-prove` returns. The model the pass
// reads is a [`StackModel`]: production's export ([`ExportStack`]) or, in the
// tests, the D55 harness's synthetic stack.

/// **[A19] what production's sealing pass, and its D55 proof, read of a
/// model**: the trained export with the run's private sequence
/// ([`ExportStack`]), or (tests) a synthetic stack.
pub(crate) trait StackModel: Sync {
    /// the run's block shape (its run constants')
    fn shape(&self) -> &Shape;
    /// the run's layer indices, in run order
    fn layers(&self) -> &[u32];
    /// run position `k`'s layer, loaded with every check (the digest pass's)
    fn load_layer(&self, k: usize) -> Result<TrainedLayer, String>;
    /// run position `k`'s public block again, the per-array hashes skipped
    /// (the proving pass's reload; [`reload_checked`] compares its digest)
    fn reload_block(&self, k: usize) -> Result<BlockPublic, String>;
    /// the private input and the reference output of layer `layer`
    fn seq(&self, layer: u32) -> Result<(Vec<i16>, Vec<i16>), String>;
    /// the trained-model statement of the run's layer records
    fn statement_of_records(&self, records: Vec<LayerRecord>) -> Result<TrainedModelStatement, String>;
    /// the run shape (CS-7)
    fn run_shape(&self) -> Result<RunShape, String>;
    /// the run's context digest
    fn context(&self) -> Result<Digest, String>;
    /// the variant and the scope line the CLI's events print
    fn variant(&self) -> &str;
    fn scope(&self) -> &'static str;
}

/// [A19] production's model: the trained export, the run's private sequence
/// and its constants and shape (computed first, as the sealing pass always did)
struct ExportStack<'a> {
    ex: &'a TrainedExport,
    seq: &'a SeqSource,
    layers: &'a [u32],
    rope: bool,
    label: &'a str,
    c: Constants,
    sh: Shape,
}

impl<'a> ExportStack<'a> {
    fn new(ex: &'a TrainedExport, seq: &'a SeqSource, layers: &'a [u32], rope: bool, label: &'a str) -> Result<ExportStack<'a>, String> {
        let c = ex.run_constants(layers)?;
        let sh = ex.shape_for(&c)?;
        Ok(ExportStack { ex, seq, layers, rope, label, c, sh })
    }
}

impl StackModel for ExportStack<'_> {
    fn shape(&self) -> &Shape {
        &self.sh
    }
    fn layers(&self) -> &[u32] {
        self.layers
    }
    fn load_layer(&self, k: usize) -> Result<TrainedLayer, String> {
        self.ex.load_layer(&self.sh, &self.c, self.layers[k], self.rope)
    }
    fn reload_block(&self, k: usize) -> Result<BlockPublic, String> {
        self.ex.reload_block(&self.sh, &self.c, self.layers[k], self.rope)
    }
    fn seq(&self, layer: u32) -> Result<(Vec<i16>, Vec<i16>), String> {
        self.seq.load(self.ex, &self.sh, layer)
    }
    fn statement_of_records(&self, records: Vec<LayerRecord>) -> Result<TrainedModelStatement, String> {
        self.ex.statement_of_records(&self.sh, &self.c, records)
    }
    fn run_shape(&self) -> Result<RunShape, String> {
        self.ex.geometry.run_shape(&self.sh, self.layers.len())
    }
    fn context(&self) -> Result<Digest, String> {
        stack_context(&self.ex.variant, self.layers, self.label)
    }
    fn variant(&self) -> &str {
        &self.ex.variant
    }
    fn scope(&self) -> &'static str {
        stack_scope(self.ex.geometry)
    }
}

/// [A19] run position `k`'s block reloaded, refused unless its digest is the
/// statement's (the block cache's and `load_fork_blocks`' check, by name)
fn reload_checked(m: &dyn StackModel, k: usize, digests: &[Digest]) -> Result<BlockPublic, String> {
    let blk = m.reload_block(k)?;
    if digests.get(k) != Some(&blk.digest()) {
        return Err(format!("trained stack: layer {}'s reloaded public statement is not the one the run statement binds", m.layers()[k]));
    }
    Ok(blk)
}

/// **[A19] what the sealing pass does with each admitted block**, after every
/// check of that block (the builder's, CS-3's lookup misses, the parity check)
trait SealHand {
    /// block `k`'s public block: kept for the fork run, or dropped
    fn block(&mut self, k: usize, blk: BlockPublic) -> Result<(), String>;
    /// block `k`'s witness, built at `ssh`: taken (`Ok(None)`: a fork's
    /// before-challenge part is made from it) or handed back
    fn witness(&mut self, k: usize, w: Witness, ssh: &Shape) -> Result<Option<Witness>, String>;
}

/// the sealing pass of D12a (and of a D55 run before A19): every block
/// dropped, every witness handed back
struct NoHand;

impl SealHand for NoHand {
    fn block(&mut self, _k: usize, _blk: BlockPublic) -> Result<(), String> {
        Ok(())
    }
    fn witness(&mut self, _k: usize, w: Witness, _ssh: &Shape) -> Result<Option<Witness>, String> {
        Ok(Some(w))
    }
}

/// [A19] a D55 run's: each block kept for the fork run (when shared), each
/// witness offered to the window
struct D55Hand<'h> {
    blocks: Option<&'h run::fork::SealedBlocks>,
    push: &'h mut dyn FnMut(usize, Witness, &Shape) -> Result<Option<Witness>, String>,
}

impl SealHand for D55Hand<'_> {
    fn block(&mut self, k: usize, blk: BlockPublic) -> Result<(), String> {
        match self.blocks {
            Some(b) => b.put(k, blk),
            None => Ok(()),
        }
    }
    fn witness(&mut self, k: usize, w: Witness, ssh: &Shape) -> Result<Option<Witness>, String> {
        // a part needs its block in the shared store
        if self.blocks.is_none() {
            return Ok(Some(w));
        }
        (self.push)(k, w, ssh)
    }
}

// ---------------------------------------- [A20] the sealing pass's loads, ahead of its builds
//
// (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A20;
// `results/zk60_effplan_20261105/a20/README.md`.) Before A20 the sealing pass loaded
// layer `k + 1` in a `rayon::join` beside layer `k`'s witness build: one load ahead,
// and the pass waited for whichever of the two was longer. Each load checks and hashes
// a whole layer (its record's nine SHA-256s and the block digest; the export's arrays'
// SHA-256s too), and at 8B a load is several times a build, so the pass ran at the
// loads' pace. `HL_A20_LOADS = n > 0` runs the loads on `n` threads of their own, each
// taking the next layer in order, at most `n` layers ahead of the layer being built:
// `n` loads run at once, beside the build, and the pass takes layer `k`'s load when it
// reaches layer `k`. `0` restores the path before A20.
//
// **H-1 and the refusals.** The pass consumes the loads IN LAYER ORDER, at the place
// it always did: layer `k`'s load result (and its refusal, `cur?`) is looked at only
// after every check of layer `k - 1` passed, exactly as before. A load further ahead
// that fails is held until its turn, and is dropped unseen if an earlier layer refuses
// (before A20, layer `k + 1`'s load already ran beside layer `k`'s build and was dropped
// the same way). So the same refusal string comes back, from the same layer, in the
// same order, before anything of the run exists. The loads read public data only; a
// load ahead adds no output and creates nothing. When the pass returns (a refusal or
// the end) the loaders start nothing new and the scope joins them before
// `seal_chain` returns. **Memory**: the layer being built and up to `n` loaded ahead
// are resident (before A20: two).

static A20_LOADS_TEST: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(usize::MAX);

/// [A20] `HL_A20_LOADS`: how many layers the sealing pass loads ahead of its build,
/// each on a thread of its own (`0`: one, in a `rayon::join` beside the build, the
/// path before A20); at most 8
pub(crate) fn a20_loads() -> usize {
    static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    super::trained_statement::a20_switch(&A20_LOADS_TEST, &ENV, "HL_A20_LOADS", A20_LOADS_DEFAULT).min(8)
}

/// [A20] the measured default (`results/zk60_effplan_20261105/a20/README.md`)
const A20_LOADS_DEFAULT: usize = 3;

/// tests: `n` loads ahead (`Some(0)`: the path before A20; `None`: as the environment
/// says). Changes no byte (see above).
#[cfg(test)]
pub(crate) fn set_a20_loads_for_test(n: Option<usize>) {
    A20_LOADS_TEST.store(n.map(|n| n.min(8)).unwrap_or(usize::MAX), std::sync::atomic::Ordering::Relaxed);
}

/// [A20] one layer's load, its result and its seconds
type TimedLoad = (Result<TrainedLayer, String>, f64);

/// [A20] the loads ahead: `n` loader threads, each taking the next layer, at most `n`
/// ahead of the layer the pass has taken
struct LoadAhead<'m> {
    m: &'m dyn StackModel,
    l: usize,
    n: usize,
    st: std::sync::Mutex<AheadState>,
    cv: std::sync::Condvar,
}

struct AheadState {
    /// the next layer a loader starts
    next: usize,
    /// how many layers the pass has taken
    taken: usize,
    ready: Vec<Option<TimedLoad>>,
    /// the pass has returned: start nothing new
    stop: bool,
    /// a loader thread ended in a panic
    lost: bool,
}

/// [A20] marks the loads lost if a loader thread unwinds (a test build: the release
/// profile aborts on a panic), so the pass never waits for a load that will not come
struct LoaderGuard<'a, 'm>(&'a LoadAhead<'m>);

impl Drop for LoaderGuard<'_, '_> {
    fn drop(&mut self) {
        if std::thread::panicking() {
            self.0.lock().lost = true;
            self.0.cv.notify_all();
        }
    }
}

impl<'m> LoadAhead<'m> {
    fn new(m: &'m dyn StackModel, n: usize) -> LoadAhead<'m> {
        let l = m.layers().len();
        LoadAhead { m, l, n, st: std::sync::Mutex::new(AheadState { next: 0, taken: 0, ready: (0..l).map(|_| None).collect(), stop: false, lost: false }), cv: std::sync::Condvar::new() }
    }
    fn lock(&self) -> std::sync::MutexGuard<'_, AheadState> {
        self.st.lock().unwrap_or_else(|e| e.into_inner())
    }
    /// one loader thread's loop
    fn run(&self) {
        let _guard = LoaderGuard(self);
        loop {
            let k = {
                let mut s = self.lock();
                loop {
                    if s.stop || s.next >= self.l {
                        return;
                    }
                    if s.next < s.taken + self.n {
                        break;
                    }
                    s = self.cv.wait(s).unwrap_or_else(|e| e.into_inner());
                }
                s.next += 1;
                s.next - 1
            };
            let t = Instant::now();
            let r = self.m.load_layer(k);
            let ls = t.elapsed().as_secs_f64();
            let mut s = self.lock();
            s.ready[k] = Some((r, ls));
            self.cv.notify_all();
        }
    }
    /// layer `k`'s load (the pass takes the layers in order), and the seconds the
    /// pass waited for it
    fn take(&self, k: usize) -> (TimedLoad, f64) {
        let t = Instant::now();
        let mut s = self.lock();
        loop {
            if let Some(r) = s.ready[k].take() {
                s.taken = k + 1;
                self.cv.notify_all();
                return (r, t.elapsed().as_secs_f64());
            }
            assert!(!s.lost, "the sealing pass's loader thread ended in a panic before layer {k} was loaded");
            s = self.cv.wait(s).unwrap_or_else(|e| e.into_inner());
        }
    }
    fn stop(&self) {
        self.lock().stop = true;
        self.cv.notify_all();
    }
}

/// [A20] stops the loads ahead when the pass returns, however it returns (before the
/// scope joins the loader threads)
struct StopLoads<'a, 'm>(&'a LoadAhead<'m>);

impl Drop for StopLoads<'_, '_> {
    fn drop(&mut self) {
        self.0.stop();
    }
}

// ---------------------------------------- [A20] end

/// **[A19] THE SEALING PASS** (R5b's, the body `seal_and_record` always had),
/// over any [`StackModel`], each admitted block and witness offered to `hand`
/// after every check of that block. The returned times' `wall_s` is the
/// caller's to set (it ends after the model's statement). [A20] Each layer's
/// load runs ahead of the builds on its own threads (`HL_A20_LOADS`), taken in
/// layer order at the place it always was.
#[allow(clippy::type_complexity)]
fn seal_chain(m: &dyn StackModel, budget_bytes: u64, hand: &mut dyn SealHand) -> Result<(Vec<LayerMeta>, Vec<Digest>, SealedChain, SealTimes), String> {
    let sh = m.shape().clone();
    let layers = m.layers();
    let ids = Ids::new(&sh)?;
    let l = layers.len();
    // [A15] the witness builds in the sealing pass's own pool
    let pool = SealPool::get()?;
    let (x_in0, _) = m.seq(layers[0])?;
    if x_in0.len() != sh.tokens * sh.width {
        return Err("trained stack: the first input is not tokens x width".into());
    }
    let mut metas = Vec::with_capacity(l);
    let mut digests = Vec::with_capacity(l);
    let mut outs: Vec<Vec<i16>> = Vec::with_capacity(l);
    let mut kept: Vec<Option<Witness>> = Vec::with_capacity(l);
    let (mut kept_bytes, mut load_s, mut witness_s) = (0u64, 0.0f64, 0.0f64);
    // [A19] the witnesses handed to a D55 run's window, and the bytes counted for them
    let (mut handed, mut part_bytes) = (0usize, 0u64);
    let mut first: Option<Vec<i16>> = None;
    let mut shapes: Vec<Shape> = Vec::with_capacity(l);
    let mut lays:Vec<(Shape,super::layout::Layout)>=Vec::new();
    let mut x = x_in0.clone();
    let timed_load = |k: usize| -> (Result<TrainedLayer, String>, f64) {
        let t = Instant::now();
        let r = m.load_layer(k);
        (r, t.elapsed().as_secs_f64())
    };
    // [A20] the loads ahead, on threads of their own (none at `HL_A20_LOADS=0`)
    let ahead = LoadAhead::new(m, if l > 1 { a20_loads() } else { 0 });
    let mut load_wait_s = 0.0f64;
    std::thread::scope(|scope| -> Result<(Vec<LayerMeta>, Vec<Digest>, SealedChain, SealTimes), String> {
    for _ in 0..ahead.n {
        scope.spawn(|| ahead.run());
    }
    let _stop = StopLoads(&ahead);
    let mut next = if ahead.n == 0 { Some(timed_load(0)) } else { None };
    for k in 0..l {
        let (cur, ls) = if ahead.n == 0 {
            next.take().expect("one load per layer")
        } else {
            let (r, waited) = ahead.take(k);
            load_wait_s += waited;
            r
        };
        load_s += ls;
        let cur = cur?;
        let layer = layers[k];
        // NATIVE R8 (R6 for sh_s): the block's witness at its layer's own
        // calibration
        let ssh=cur.record.shape_at(&sh)?;
        let build = || {
            let t = Instant::now();
            // [A15] on the sealing pool (the next layer's load stays on the global pool)
            let r = pool.run(|| witness_for_block(&ssh,&cur.blk,&x));
            (r, t.elapsed().as_secs_f64())
        };
        let (wres, ws) = if ahead.n == 0 {
            let ((wres, ws), nxt) = rayon::join(build, || if k + 1 < l { Some(timed_load(k + 1)) } else { None });
            next = nxt;
            (wres, ws)
        } else {
            // [A20] the loads ahead run on their own threads; the build here
            build()
        };
        witness_s += ws;
        let w = wres.map_err(|e| format!("the witness builder refuses layer {layer} (before the run header; ruling H-1): {e}"))?;
        // NATIVE R6 (review r5 note N-r5-a): ruling CS-3's lookup-miss
        // refusal on the sealed witness, here in the sealing pass, so that no
        // refusal of an admissible-looking chain is left to `prove_core`
        // mid-run (H-1 as a fact of the code). One layout per score shift.
        let lay = match lays.iter().position(|(v,_)|*v==ssh) {
            Some(i) => &lays[i].1,
            None => {
                lays.push((ssh.clone(),super::layout::Layout::for_shape(&ssh)?));
                &lays[lays.len() - 1].1
            }
        };
        super::protocol::check_lookup_misses(&ssh, lay, &cur.blk, &w).map_err(|e| format!("layer {layer}, in the sealing pass (before the run header; ruling H-1): {e}"))?;
        // [A19] what a fork's before-challenge part holds beyond the witness: `A`'s
        // host rows and its encoding (the device's copy on Metal), an estimate
        let part_extra = 8 * (lay.a_rows * lay.n()) as u64 * (1 + ssh.inv_rate as u64);
        let out = padded_plane(&w, ids.at(A_X2))?;
        if k == 0 {
            first = Some(padded_plane(&w, ids.at(A_X))?);
        }
        let xt = true_words(&sh, &out);
        let (_, x_out_ref) = m.seq(layer)?;
        if xt != x_out_ref {
            return Err(format!("layer {layer}: {PARITY_REFUSAL} (before the run header; ruling H-1)"));
        }
        x = xt;
        digests.push(cur.record.block_digest);
        metas.push(LayerMeta { index: cur.index, manifest_sha256: cur.manifest_sha256, record: cur.record });
        // [A19] every check of block `k` has passed: its block is kept for a D55
        // run's forks (dropped otherwise, as before), and its witness is offered to
        // the window when the budget holds it as a part
        hand.block(k, cur.blk)?;
        let wb = witness_bytes(&w);
        let w = if kept_bytes + part_bytes + wb + part_extra <= budget_bytes {
            match hand.witness(k, w, &ssh)? {
                None => {
                    handed += 1;
                    part_bytes += wb + part_extra;
                    None
                }
                back => back,
            }
        } else {
            Some(w)
        };
        match w {
            Some(w) if kept_bytes + part_bytes + wb <= budget_bytes => {
                kept_bytes += wb;
                kept.push(Some(w));
            }
            _ => kept.push(None),
        }
        outs.push(out);
        shapes.push(ssh);
    }
    let first = first.expect("at least one block");
    if first != pad_d_plane(&sh, &x_in0)? {
        return Err("trained stack: the builder's block-0 input plane is not the export's x_in (before the run header)".into());
    }
    let last = outs[l - 1].clone();
    let chain = SealedChain { x_in0, shapes, outs, kept, kept_bytes, first, last, rebuilt: 0, handed, part_bytes };
    Ok((metas, digests, chain, SealTimes { wall_s: 0.0, load_s, witness_s, pool_threads: pool.threads(), loads_ahead: ahead.n, load_wait_s }))
    })
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

/// **D60: the `segments.json` of a D55 fork run** — one entry per FRAME of
/// its receipt (the head, every fork, the tail; `run::fork::d55_file_names`),
/// its file name, length and SHA-256, in the same form as a D12a run's
pub(crate) fn render_fork_frames_json(seen: &[(u64, String)]) -> String {
    let names = run::fork::d55_file_names(seen.len().saturating_sub(2));
    let segs: Vec<String> = seen.iter().zip(names.iter()).map(|((n, h), f)| format!("{{\"file\":{},\"bytes\":{n},\"sha256\":{}}}", js(f), js(h))).collect();
    format!("[\n {}\n]\n", segs.join(",\n "))
}

/// **D60 review F3: the operator's explicit acknowledgement that a D55 fork
/// run is a TEST receipt, not for publication** (`stack-prove` only). While
/// `run::fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is `false`,
/// `stack-prove --d55-workers N` refuses to run without it.
pub(crate) const D55_TEST_RECEIPT_FLAG: &str = "--d55-test-receipt-not-for-publication";

/// **D60 review F3: whether `stack-prove` may run, and whether its receipt is
/// a D55 TEST receipt** (`Ok(true)`: the run directory gets the marker
/// `run::fork::D55_TEST_RECEIPT_MARKER_FILE`). `gate_passed` is
/// `run::fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED` in production (a
/// parameter only so the tests read both arms). Refused: a D55 fork run
/// without the acknowledgement while the gate has not passed, and the
/// acknowledgement without `--d55-workers`. A D12a run is never affected.
pub(crate) fn d55_prove_admission(d55_workers: Option<usize>, acknowledged: bool, gate_passed: bool) -> Result<bool, String> {
    match (d55_workers.is_some(), acknowledged) {
        (false, false) => Ok(false),
        (false, true) => Err(format!("{D55_TEST_RECEIPT_FLAG} acknowledges a D55 fork run's test receipt; it is given only with --d55-workers")),
        (true, true) => Ok(true),
        (true, false) if gate_passed => Ok(false),
        (true, false) => Err(format!(
            "D60 review F3: a D55 fork run is refused in this build — ruling D60 requires the privacy gate on a capture under a REGISTERED D55 run profile before any receipt for real content, and that gate has not passed (run_fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED is false); to prove a TEST receipt on public data, pass {D55_TEST_RECEIPT_FLAG}: the run directory is then marked {} and must not be published",
            run::fork::D55_TEST_RECEIPT_MARKER_FILE
        )),
    }
}

/// `--d55-workers N` (D60): `None` without the flag; a fork run's worker
/// count, 1 ..= 64, with it
fn d55_workers_of(f: &[(String, String)]) -> Result<Option<usize>, String> {
    match flag(f, "--d55-workers") {
        None => Ok(None),
        Some(v) => {
            let n: usize = v.parse().map_err(|_| "--d55-workers is not an integer")?;
            if !(1..=64).contains(&n) {
                return Err("--d55-workers is outside 1..=64".into());
            }
            Ok(Some(n))
        }
    }
}

/// **D60: every block of a fork run, resident at once** (a fork run's
/// workers share them read-only), each reloaded from the export exactly as
/// the D12a block cache reloads one and refused unless its digest is the run
/// statement's. Returns the blocks and the load seconds.
fn load_fork_blocks(ex: &TrainedExport, sh: &Shape, c: &Constants, layers: &[u32], digests: &[Digest], rope_from_export: bool) -> Result<(Vec<BlockPublic>, f64), String> {
    let t = Instant::now();
    let mut v = Vec::with_capacity(layers.len());
    for (k, &layer) in layers.iter().enumerate() {
        let blk = ex.reload_block(sh, c, layer, rope_from_export)?;
        if blk.digest() != digests[k] {
            return Err(format!("trained stack: layer {layer}'s reloaded public statement is not the one the run statement binds"));
        }
        v.push(blk);
    }
    Ok((v, t.elapsed().as_secs_f64()))
}

/// [A19] `load_fork_blocks` over any [`StackModel`] (a D55 run's blocks
/// reloaded after the sealing pass, `HL_A19_SHARE=0`: the path before A19)
fn load_fork_blocks_of(m: &dyn StackModel, digests: &[Digest]) -> Result<(Vec<BlockPublic>, f64), String> {
    let t = Instant::now();
    let v = (0..m.layers().len()).map(|k| reload_checked(m, k, digests)).collect::<Result<Vec<_>, String>>()?;
    Ok((v, t.elapsed().as_secs_f64()))
}

/// `HL_A19_SHARE`: unset or `1`, a D55 run proves with the blocks its sealing
/// pass loaded (the default); `0`, it loads every block again after the
/// sealing pass (the path before A19; A13's window then stays off). As a test
/// override: 0 off, 1 on, `usize::MAX` as the environment says.
static A19_SHARE_TEST: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(usize::MAX);

/// [A19] whether a D55 run proves with the sealing pass's own blocks
pub(crate) fn a19_share_blocks() -> bool {
    static ENV: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    match A19_SHARE_TEST.load(std::sync::atomic::Ordering::Relaxed) {
        0 => false,
        1 => true,
        _ => *ENV.get_or_init(|| !matches!(std::env::var("HL_A19_SHARE").as_deref(), Ok("0"))),
    }
}

/// tests: the blocks shared (`Some(true)`), reloaded (`Some(false)`) or as the
/// environment says (`None`). Changes no byte.
#[cfg(test)]
pub(crate) fn set_a19_share_for_test(on: Option<bool>) {
    A19_SHARE_TEST.store(on.map(usize::from).unwrap_or(usize::MAX), std::sync::atomic::Ordering::Relaxed);
}

/// [A19] how production's D55 proof ran: the CLI prints these, the harness reads them
#[derive(Clone, Debug, Default)]
#[cfg_attr(not(test), allow(dead_code))]
pub(crate) struct D55Times {
    /// the sealing pass (its model's statement included), as R5b's `sealed` event
    pub seal_s: f64,
    pub seal_load_s: f64,
    pub seal_witness_s: f64,
    pub seal_pool_threads: usize,
    /// the window, and the witnesses handed to it with the bytes the budget counted
    pub window: usize,
    pub handed: usize,
    pub part_bytes: u64,
    pub kept: usize,
    pub kept_bytes: u64,
    /// whether the fork run proved with the sealing pass's blocks, and (when it
    /// did not) the seconds it took to load them again
    pub shared: bool,
    pub block_load_s: f64,
    /// from the run directory's creation to the receipt written
    pub prove_s: f64,
    pub rebuilt: usize,
    pub rebuild_s: f64,
    pub reloads: usize,
    pub reload_s: f64,
    pub receipt_bytes: usize,
    pub fork: run::fork::ForkStats,
    /// [A20] the sealing pass's loads ahead and its wait for them; the receipt
    /// write's seconds and its writer threads
    pub seal_loads_ahead: usize,
    pub seal_load_wait_s: f64,
    pub write_s: f64,
    pub writers: usize,
}

/// [A19] what production's D55 proof leaves for `stack-prove`'s statement
pub(crate) struct D55Proved {
    metas: Vec<LayerMeta>,
    digests: Vec<Digest>,
    st: TrainedModelStatement,
    ctx: Digest,
    expected: ExpectedIo,
    rst: RunStatement,
    written: Vec<(u64, String)>,
    times: D55Times,
}

#[cfg_attr(not(test), allow(dead_code))]
impl D55Proved {
    pub(crate) fn times(&self) -> &D55Times {
        &self.times
    }
    pub(crate) fn statement(&self) -> &RunStatement {
        &self.rst
    }
}

/// [A19] how production's D55 proof is run: the fork workers, the run
/// directory (new), the witness cache's budget, whether the receipt is a
/// test receipt (D60 review F3's marker) and whether the CLI's events print
#[derive(Clone, Copy)]
pub(crate) struct D55Run<'a> {
    pub workers: usize,
    pub out: &'a Path,
    pub budget: u64,
    pub test_receipt: bool,
    pub events: bool,
}

/// **[A19] PRODUCTION'S D55 PROOF** (`stack-prove --d55-workers N`, from the
/// sealing pass to the receipt in the run directory): the sealing pass (each
/// fork's before-challenge part beside it when A13's window is on; each block
/// kept for the fork run when shared), then the trained-model statement, the
/// endpoints (the sealed chain's own planes), the bound run statement, the
/// fork run (D60's door), the plan's check, the run directory, the fork run's
/// proof and its frames (and D60 review F3's marker). The steps, their
/// refusals and their events are the D55 path's before A19, in its order; a
/// failure after the run directory exists removes it.
pub(crate) fn d55_seal_and_prove(m: &dyn StackModel, opt_in: run::fork::D55OptIn, run: &D55Run) -> Result<D55Proved, String> {
    let t0 = Instant::now();
    let (sh, layers) = (m.shape(), m.layers());
    let l = layers.len();
    let shared = a19_share_blocks();
    // the plan, before the sealing pass: none when the window is off or the
    // blocks are not shared; a run that cannot make one proves without it and
    // meets any refusal where it always did
    let window = if shared { run::fork::ahead_window().min(l) } else { 0 };
    let plan = if window > 0 { m.run_shape().ok().zip(m.context().ok()).and_then(|(rs, ctx)| run::fork::ForkPlan::for_run(&rs, ctx, &opt_in).ok()) } else { None };
    let window = if plan.is_some() { window } else { 0 };
    let blocks = run::fork::SealedBlocks::new(l);
    run::fork::prove_run_with_forks_planned(
        plan.as_ref(),
        &blocks,
        // ---- (1) the sealing pass (ruling H-1): every refusal of an inadmissible
        //      chain happens here, before anything of the run exists
        |push| {
            let mut hand = D55Hand { blocks: shared.then_some(&blocks), push };
            let r = seal_chain(m, run.budget, &mut hand)?;
            #[cfg(test)]
            a19_after_the_sealing_pass();
            Ok(r)
        },
        |(metas, digests, chain, mut seal), planned| {
            let st = m.statement_of_records(metas.iter().map(|m| m.record.clone()).collect())?;
            seal.wall_s = t0.elapsed().as_secs_f64();
            let (kept_n, kept_bytes) = (chain.kept.iter().filter(|w| w.is_some()).count(), chain.kept_bytes);
            let (handed, part_bytes) = (chain.handed, chain.part_bytes);
            if run.events {
                println!(
                    "{{\"event\":\"loaded\",\"variant\":{},\"layers\":\"{}..{}\",\"blocks\":{l},\"statement_identity\":{},\"seconds\":{:.3},\"hl_gpu\":{},\"scope\":{}}}",
                    js(m.variant()),
                    layers[0],
                    layers[l - 1] + 1,
                    js(&hex(&st.identity())),
                    seal.wall_s,
                    js(&std::env::var("HL_GPU").unwrap_or_else(|_| "unset".into())),
                    js(m.scope())
                );
                println!(
                    "{{\"event\":\"sealed\",\"from\":\"the witness builder's own pass over layers {}..{} (parity bit-exact at every layer, before the run header: ruling H-1)\",\"seconds\":{:.3},\"of_which_load_seconds\":{:.3},\"of_which_witness_seconds\":{:.3},\"kept_witnesses\":{kept_n},\"kept_witness_bytes\":{kept_bytes},\"rayon_threads\":{},\"seal_pool_threads\":{},\"d55_window\":{window},\"d55_parts\":{handed},\"d55_part_bytes\":{part_bytes},\"d55_shared_blocks\":{shared}}}",
                    layers[0],
                    layers[l - 1] + 1,
                    seal.wall_s,
                    seal.load_s,
                    seal.witness_s,
                    rayon::current_num_threads(),
                    seal.pool_threads
                );
                println!("{{\"event\":\"parity\",\"result\":\"bit-exact at every layer\",\"layers\":{l},\"words_per_layer\":{},\"checked_before_the_run_header\":true}}", sh.tokens * sh.width);
            }
            // ---- (2) the endpoints (the builder's own planes) and the bound run statement
            let ctx = m.context()?;
            let spec = IoSpec::new_shaped(sh, ctx, 0, 0)?;
            let (expected, owners) = prepare_endpoints(spec, &chain.first, &chain.last)?;
            let rst = RunStatement::new_bound_from_digests(m.run_shape()?, ctx, expected.clone(), digests.clone(), &vec![(0, 0); l], &st)?;
            // D60: the fork run's door, BEFORE the run directory exists (an
            // ineligible base is refused by name here)
            let fr = run::fork::ForkRun::new(&rst, opt_in)?;
            if run.events {
                println!("{{\"event\":\"d55\",\"run_profile\":{},\"base_run_profile\":{},\"workers\":{},\"test_receipt_not_for_publication\":{}}}", js(fr.profile()), js(rst.rs().profile()), run.workers, run.test_receipt);
            }
            // [A19] the plan the parts were made under is this fork run's (before
            // the run directory exists)
            planned.check(&fr)?;
            let mut src = StackSource::new(sh, if shared { StackBlocks::Sealed(&blocks) } else { StackBlocks::Model(m, &digests) }, l, chain, None)?;
            // ---- (3) the proving pass
            std::fs::create_dir(run.out).map_err(|e| format!("{}: {e}", run.out.display()))?;
            let t = Instant::now();
            let proved = (|| -> Result<(Vec<(u64, String)>, usize, run::fork::ForkStats, f64, f64), String> {
                // the blocks the fork run proves with: the sealing pass's own, or
                // (`HL_A19_SHARE=0`, the path before A19) every one loaded again
                let reloaded;
                let (b, load_s): (&dyn run::fork::ForkBlocks, f64) = if shared {
                    (&blocks as &dyn run::fork::ForkBlocks, 0.0)
                } else {
                    let (v, s) = load_fork_blocks_of(m, &digests)?;
                    reloaded = v;
                    (&reloaded as &dyn run::fork::ForkBlocks, s)
                };
                let (rc, fs) = planned.prove(&fr, b, &mut src, owners, run.workers)?;
                #[cfg(test)]
                a19_after_the_proof(&fr, b, &rc, &fs);
                let tw = Instant::now();
                let written = run::fork::write_fork_receipt(run.out, &rc)?;
                let write_s = tw.elapsed().as_secs_f64();
                // D60 review F3: the not-for-publication marker, after the frames
                // and before any verification or statement (a run that fails
                // later is removed with it)
                if run.test_receipt {
                    let p = run::fork::write_d55_test_receipt_marker(run.out)?;
                    if run.events {
                        println!("{{\"event\":\"d55-test-receipt\",\"not_for_publication\":true,\"marker\":{},\"why\":\"D60 review F3: run_fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED is false in this build; the operator passed {D55_TEST_RECEIPT_FLAG}\"}}", js(&p.display().to_string()));
                    }
                }
                if run.events {
                    let core: Vec<String> = fs.fork_core_s.iter().map(|s| format!("{s:.3}")).collect();
                    println!(
                        "{{\"event\":\"d55-proved\",\"workers\":{},\"frames\":{},\"receipt_bytes\":{},\"block_load_seconds\":{load_s:.3},\"preflight_seconds\":{:.3},\"commit_seconds\":{:.3},\"forks_seconds\":{:.3},\"join_seconds\":{:.3},\"total_seconds\":{:.3},\"fork_prove_core_seconds\":[{}],\"generators\":{},\"join_claim_bytes\":{},\"ahead_parked\":{},\"ahead_taken_back\":{},\"vmhwm_mib\":{:.0}}}",
                        fs.workers,
                        written.len(),
                        rc.bytes(),
                        fs.preflight_s,
                        fs.commit_s,
                        fs.forks_s,
                        fs.join_s,
                        fs.total_s,
                        core.join(","),
                        fs.generators,
                        fs.join_claim_bytes.iter().map(|c| c[0] + c[1]).sum::<usize>(),
                        fs.ahead_parked,
                        fs.ahead_taken_back,
                        peak_rss_mib()
                    );
                }
                Ok((written, rc.bytes(), fs, load_s, write_s))
            })();
            let prove_s = t.elapsed().as_secs_f64();
            let (rebuild_s, rebuilt, reloads) = (src.busy_s, src.chain.rebuilt, src.reloads);
            drop(src);
            let (written, receipt_bytes, fork, block_load_s, write_s) = proved.map_err(|e| fail_run(run.out, format!("prove_run: {e}")))?;
            drop(fr);
            let times = D55Times {
                seal_s: seal.wall_s,
                seal_load_s: seal.load_s,
                seal_witness_s: seal.witness_s,
                seal_pool_threads: seal.pool_threads,
                window,
                handed,
                part_bytes,
                kept: kept_n,
                kept_bytes,
                shared,
                block_load_s,
                prove_s,
                rebuilt,
                rebuild_s,
                reloads: reloads.0,
                reload_s: reloads.1,
                receipt_bytes,
                fork,
                seal_loads_ahead: seal.loads_ahead,
                seal_load_wait_s: seal.load_wait_s,
                write_s,
                writers: run::fork::a20_writers(),
            };
            Ok(D55Proved { metas, digests, st, ctx, expected, rst, written, times })
        },
    )
}

// [A19] TEST BUILDS ONLY: a hook run on the calling thread right after the
// sealing pass (the harness's clock and usage of the pass), and one run after
// the fork run's proof with that fork run, its blocks, receipt and stats (the
// production-path byte tests)
#[cfg(test)]
type A19ProvedHook = Box<dyn FnMut(&run::fork::ForkRun<'_>, &dyn run::fork::ForkBlocks, &run::fork::ForkReceipt, &run::fork::ForkStats)>;

#[cfg(test)]
thread_local! {
    static A19_SEALED_HOOK: std::cell::RefCell<Option<Box<dyn FnMut()>>> = const { std::cell::RefCell::new(None) };
    static A19_PROVED_HOOK: std::cell::RefCell<Option<A19ProvedHook>> = const { std::cell::RefCell::new(None) };
}

/// tests: the hook run on this thread right after each D55 sealing pass
#[cfg(test)]
pub(crate) fn a19_sealed_hook_for_tests(f: Option<Box<dyn FnMut()>>) {
    A19_SEALED_HOOK.with(|h| *h.borrow_mut() = f);
}

/// tests: the hook run on this thread after each D55 fork run's proof
#[cfg(test)]
pub(crate) fn a19_proved_hook_for_tests(f: Option<A19ProvedHook>) {
    A19_PROVED_HOOK.with(|h| *h.borrow_mut() = f);
}

#[cfg(test)]
fn a19_after_the_sealing_pass() {
    A19_SEALED_HOOK.with(|h| {
        if let Some(f) = h.borrow_mut().as_mut() {
            f()
        }
    });
}

#[cfg(test)]
fn a19_after_the_proof(fr: &run::fork::ForkRun<'_>, b: &dyn run::fork::ForkBlocks, rc: &run::fork::ForkReceipt, fs: &run::fork::ForkStats) {
    A19_PROVED_HOOK.with(|h| {
        if let Some(f) = h.borrow_mut().as_mut() {
            f(fr, b, rc, fs)
        }
    });
}

/// [A19] `stack-prove --d55-workers N`: [`d55_seal_and_prove`] on the export,
/// then the D55 run's statement (in-process verification or the unverified
/// statement beside the run) and its `proved` event, as before A19
#[allow(clippy::too_many_arguments)]
fn stack_prove_d55(f: &[(String, String)], ex: &TrainedExport, layers: &[u32], rope: bool, seq: &SeqSource, label: &str, budget: u64, workers: usize, test_receipt: bool, out: &Path, unverified: &Path, t_total: Instant) -> Result<(), String> {
    let l = layers.len();
    let m = ExportStack::new(ex, seq, layers, rope, label)?;
    let p = d55_seal_and_prove(&m, run::fork::D55OptIn::registered_profile(), &D55Run { workers, out, budget, test_receipt, events: true })?;
    let tm = &p.times;
    // the fork run again (its door is deterministic: it admitted this statement)
    let fr = run::fork::ForkRun::new(&p.rst, run::fork::D55OptIn::registered_profile())?;
    let fork_names = Some((fr.profile(), p.rst.rs().profile()));
    let hwm = peak_rss_mib();
    // ---- (4) in-process verification from the directory (a fresh copy of
    //      every block): OFF by default (R5-2) — then the statement is NOT published here
    let in_process = flag(f, "--verify-in-process").is_some();
    let t = Instant::now();
    let verdict = if in_process { load_fork_blocks(ex, &m.sh, &m.c, layers, &p.digests, rope).and_then(|(b, _)| run::fork::verify_run_with_forks_from_dir(&fr, &b, out, workers)).map(Some) } else { Ok(None) };
    let verify_s = t.elapsed().as_secs_f64();
    let verified_seen = match verdict {
        Err(e) => return Err(fail_run(out, format!("in-process verification of the run directory: {e}"))),
        Ok(v) => v,
    };
    let claims = ProverClaims::of_this_process();
    // NATIVE R7 (Q-2): the prover writes only the build's constants
    check_prover_reported(&claims.backend, claims.gpu_declines).map_err(|e| fail_run(out, e))?;
    let sdir = match verified_seen {
        Some(seen) => {
            if seen != p.written {
                return Err(fail_run(out, "in-process verification: the bytes it verified are not the bytes the prover wrote".into()));
            }
            let stmt = render_stack_statement_for(ex, &m.sh, &p.metas, &p.st, &p.ctx, &p.expected, label, StatementWriter::InProcess, &claims, fork_names);
            publish_statement_dir(out, &[("expected.bin", &p.expected.to_bytes()), ("statement.json", stmt.as_bytes()), ("segments.json", render_fork_frames_json(&seen).as_bytes())]).map_err(|e| fail_run(out, e))?
        }
        None => {
            std::fs::create_dir(unverified).map_err(|e| format!("{}: {e}", unverified.display()))?;
            write_new(&unverified.join(UNVERIFIED_MARKER), UNVERIFIED_TEXT)?;
            write_new(&unverified.join("expected.bin"), &p.expected.to_bytes())?;
            write_new(&unverified.join("statement.json"), render_stack_statement_for(ex, &m.sh, &p.metas, &p.st, &p.ctx, &p.expected, label, StatementWriter::Unverified, &claims, fork_names).as_bytes())?;
            write_new(&unverified.join("segments.json"), render_fork_frames_json(&p.written).as_bytes())?;
            unverified.to_path_buf()
        }
    };
    println!(
        "{{\"event\":\"proved\",\"gpu\":{},\"gpu_declines\":{},\"blocks\":{l},\"receipt_bytes\":{},\"prove_run_seconds\":{:.3},\"of_which_witness_seconds\":{:.3},\"rebuilt_witnesses\":{},\"witness_seconds_per_block\":{:.3},\"of_which_block_load_seconds\":{:.3},\"block_loads\":{},\"rayon_threads\":{},\"in_process_verified\":{in_process},\"in_process_verify_seconds\":{verify_s:.3},\"sealing_pass_seconds\":{:.3},\"sealing_witness_seconds\":{:.3},\"load_seconds\":{:.3},\"total_seconds\":{:.3},\"vmhwm_mib\":{hwm:.0},\"statement_identity\":{},\"statement_dir\":{},\"out\":{}}}",
        js(&crate::gpu::label()),
        crate::gpu::declines(),
        p.written.iter().map(|(n, _)| *n).sum::<u64>(),
        tm.prove_s,
        tm.rebuild_s,
        tm.rebuilt,
        (tm.seal_witness_s + tm.rebuild_s) / l as f64,
        tm.reload_s,
        tm.reloads,
        rayon::current_num_threads(),
        tm.seal_s,
        tm.seal_witness_s,
        tm.seal_load_s,
        t_total.elapsed().as_secs_f64(),
        js(&hex(&p.st.identity())),
        js(&sdir.display().to_string()),
        js(&out.display().to_string())
    );
    Ok(())
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

/// [A20] TEST ONLY: the sealing pass (`seal_chain`, D12a's `NoHand`) over `m`, as one
/// line of everything it returns but its clocks (the model's statement identity, the
/// block digests, every layer record, every sealed plane and endpoint, the stage
/// shapes, which witnesses were kept and every plane of each), and the loads it ran
/// ahead of its builds
#[cfg(test)]
pub(crate) fn a20_seal_summary_for_tests(m: &dyn StackModel, budget_bytes: u64) -> Result<(String, usize), String> {
    let (metas, digests, chain, times) = seal_chain(m, budget_bytes, &mut NoHand)?;
    let st = m.statement_of_records(metas.iter().map(|m| m.record.clone()).collect())?;
    let planes = |v: &[i16]| hex(&sha256(&v.iter().flat_map(|x| x.to_le_bytes()).collect::<Vec<u8>>()))[..16].to_string();
    let kept: Vec<String> = chain
        .kept
        .iter()
        .map(|w| match w {
            None => "-".to_string(),
            Some(w) => hex(&sha256(&w.planes.iter().flat_map(|p| p.iter().flat_map(|x| x.to_le_bytes())).collect::<Vec<u8>>()))[..16].to_string(),
        })
        .collect();
    let line = format!(
        "identity {} | block digests {} | records {} | outs {} | first {} | last {} | x_in0 {} | shapes {} | kept {} ({} B): {}",
        hex(&st.identity()),
        digests.iter().map(|d| hex(d)[..16].to_string()).collect::<Vec<_>>().join(","),
        hex(&sha256(format!("{:?}", metas.iter().map(|m| (&m.record, m.index, m.manifest_sha256)).collect::<Vec<_>>()).as_bytes())),
        chain.outs.iter().map(|o| planes(o)).collect::<Vec<_>>().join(","),
        planes(&chain.first),
        planes(&chain.last),
        planes(&chain.x_in0),
        chain.shapes.iter().map(|s| s.name.to_string()).collect::<Vec<_>>().join(","),
        chain.kept.iter().filter(|w| w.is_some()).count(),
        chain.kept_bytes,
        kept.join(",")
    );
    Ok((line, times.loads_ahead))
}

/// [A20] TEST ONLY: [`a20_seal_summary_for_tests`] over a trained export, its sequence
/// `seq` and every layer (production's model, [`ExportStack`])
#[cfg(test)]
pub(crate) fn a20_export_seal_summary_for_tests(export: &Path, seq: &str, budget_bytes: u64) -> Result<(String, usize), String> {
    let ex = TrainedExport::load(export)?;
    let layers = ex.layers.clone();
    let seq = SeqSource::InExport(seq.to_string());
    let m = ExportStack::new(&ex, &seq, &layers, false, "")?;
    a20_seal_summary_for_tests(&m, budget_bytes)
}

#[allow(clippy::too_many_arguments)]
/// D60: what a D55 fork run's statement says it is, beside its two profiles
const D55_RUN_CONSTRUCTION: &str = "D55 commit, fork, join (a registered opt-in run profile, ruling D60): every internal boundary committed before any block challenge, each block proved on its own fork of that transcript, one joined opening phase; the frames are d55-head.bin, d55-fork-NNN.bin and d55-tail.bin";

/// **The stack statement, for a D12a run (`fork` = `None`: byte for byte the
/// statement every earlier round wrote) or (D60) for a D55 fork run** —
/// `fork` = `(the D55 run profile, its base run profile)`: `run_profile` is
/// then the D55 string and the statement also names the base and the
/// construction, so a D12a statement and a D55 statement of the same run
/// never render alike.
#[allow(clippy::too_many_arguments)]
fn render_stack_statement_for(ex: &TrainedExport, sh: &Shape, layers: &[LayerMeta], st: &TrainedModelStatement, ctx: &Digest, expected: &ExpectedIo, label: &str, writer: StatementWriter, claims: &ProverClaims, fork: Option<(&str, &str)>) -> String {
    let run_fragment = match fork {
        None => format!("\"run_profile\": {}", js(ex.run_profile())),
        Some((d55, base)) => format!("\"run_profile\": {},\n \"base_run_profile\": {},\n \"run_construction\": {}", js(d55), js(base), js(D55_RUN_CONSTRUCTION)),
    };
    let c = sh.norm_calibration();
    let recs: Vec<String> = layers
        .iter()
        .map(|l| {
            // NATIVE R8 (R6 for sh_s): a layer's own constants, when it has
            // any, under their export keys in the canonical order (`sh_s`
            // first, so an sh_s-only record renders as in R6)
            let mut own: String = l.record.own.iter().enumerate().filter_map(|(i, v)| v.map(|v| format!(", \"{}\": {v}", OWN_FIELDS[i].0))).collect();
            if let Some(g)=l.record.accuracy_gate_shift {own.push_str(&format!(", \"accuracy_gate_shift\": {g}"));}
            format!("{{\"layer\": {}, \"block_digest\": {}, \"manifest_sha256\": {}, \"silu_member\": [{}, {}], \"exp_e_s\": {}{own}}}", l.index, js(&hex(&l.record.block_digest)), js(&hex(&l.manifest_sha256)), l.record.silu_member.0, l.record.silu_member.1, l.record.exp_e_s)
        })
        .collect();
    format!(
        "{{\n \"schema\": \"{}\",\n \"scope\": {},\n \"statement_written_by\": {},\n \"prover_reported\": {{\"backend\": {}, \"gpu_declines\": {}, \"what\": {}}},\n \"block_profile\": {},\n {},\n \"blocks\": {},\n \"export_variant\": {},\n \"export_profile_sha256\": {},\n \"calibration_tool_sha256\": {},\n \"trained_statement_identity\": {},\n \"context_label\": {},\n \"context\": {},\n \"expected_io\": {},\n \"layers\": [\n  {}\n ],\n \"shape\": {{\"tokens\": {}, \"width\": {}, \"hidden\": {}, \"q_heads\": {}, \"kv_heads\": {}, \"head_dim\": {}, \"log_cols\": {}, \"inv_rate\": {}, \"opened_cols\": {}, \"f_e\": {}, \"wrho_s\": {}, \"norm_wrho\": {}, \"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_ao\": {}, \"sh_qkv\": {}, \"sh_s\": {}, \"sh_o\": {}, \"sh_g\": {}, \"sh_h\": {}, \"sh_z\": {}, \"d_max\": {}}}\n}}\n",
        STACK_STATEMENT_SCHEMA,
        js(stack_scope(ex.geometry)),
        js(writer.text()),
        js(&claims.backend),
        claims.gpu_declines,
        js(PROVER_REPORTED_WHAT),
        js(sh.profile),
        run_fragment,
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
/// keep; default an eighth of the machine's RAM, at least 4 and at most 64 GiB:
/// [`default_witness_cache_gib`]). (4) With `--verify-in-process` the run is verified from
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
///
/// **D60: `--d55-workers N`** proves the run under its base's REGISTERED D55
/// "commit, fork, join" profile instead (refused by name over a base with
/// none), the blocks on `N` fork workers, and writes the receipt's `L + 2`
/// frames (`d55-head.bin`, `d55-fork-NNN.bin`, `d55-tail.bin`) into `--out`;
/// the statement names the D55 profile and its base. Every other step is the
/// D12a run's. Not with `--lie-at-boundary` (a D12a control).
///
/// **D60 review F3:** while `run::fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED`
/// is `false`, `--d55-workers` is REFUSED (before anything is read or
/// created) unless `--d55-test-receipt-not-for-publication` is also given;
/// with it, the run directory gets the marker
/// `D55_TEST_RECEIPT_NOT_FOR_PUBLICATION.txt` after its frames (no frame,
/// `segments.json` or `statement.json` byte carries it), and
/// `stack-verify --d55-workers` reports it.
pub fn trained_stack_prove_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--seq", "--seq-dir", "--out", "--layers", "--label", "--lie-at-boundary", "--witness-cache-gib", "--d55-workers"], &["--rope-from-export", "--verify-in-process", "--dd", D55_TEST_RECEIPT_FLAG]) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("zk60_trained_block stack-prove: {e}");
            return 2;
        }
    };
    match stack_prove_inner(&f) {
        Ok(()) => 0,
        // D65(2): one constant external refusal; the detail goes to the owner's private log
        Err(e) => refusal::refuse("stack-prove", &e),
    }
}

/// TEST BUILDS ONLY: `stack-prove`'s inner result (the refusal's detail, which
/// the CLI keeps in the owner's private log; D65(2)), for the controls that
/// compare refusals under two settings
#[cfg(test)]
pub(crate) fn stack_prove_inner_for_tests(args: &[String]) -> Result<(), String> {
    let f = flags(args, &["--export", "--seq", "--seq-dir", "--out", "--layers", "--label", "--lie-at-boundary", "--witness-cache-gib", "--d55-workers"], &["--rope-from-export", "--verify-in-process", "--dd", D55_TEST_RECEIPT_FLAG])?;
    stack_prove_inner(&f)
}

/// **Efficiency plan A3: the witness cache's default budget, sized to the machine.** An
/// eighth of physical RAM, at least the old 4 GiB and at most 64 (the flag's ceiling). On the
/// 256 GB Mac that is 32 GiB, which keeps every witness of a 32-block 8B run (about 0.3 GB
/// each), so the proving pass rebuilds none. A 16 GB laptop keeps the old 4. A machine whose
/// RAM cannot be read keeps 4. The budget only decides what is kept or rebuilt; a rebuilt
/// witness is checked against the sealed output, so the receipt is the same either way.
fn default_witness_cache_gib() -> f64 {
    total_ram_gib().map(|g| (g / 8.0).clamp(4.0, 64.0)).unwrap_or(4.0)
}

/// physical RAM in GiB: `sysctl hw.memsize` on macOS, `MemTotal` on Linux
fn total_ram_gib() -> Option<f64> {
    #[cfg(target_os = "macos")]
    {
        let out = std::process::Command::new("/usr/sbin/sysctl").args(["-n", "hw.memsize"]).output().ok()?;
        let bytes: f64 = String::from_utf8(out.stdout).ok()?.trim().parse().ok()?;
        return Some(bytes / (1u64 << 30) as f64);
    }
    #[cfg(target_os = "linux")]
    {
        let s = std::fs::read_to_string("/proc/meminfo").ok()?;
        let kb: f64 = s.lines().find(|l| l.starts_with("MemTotal:"))?.split_whitespace().nth(1)?.parse().ok()?;
        return Some(kb / (1u64 << 20) as f64);
    }
    #[allow(unreachable_code)]
    None
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
        // efficiency plan A3: sized to the machine (the old fixed 4 GiB kept only about 13 of
        // an 8B run's 32 witnesses and rebuilt the rest serially on the fork feeder)
        None if cfg!(not(test)) => default_witness_cache_gib(),
        None => 4.0,
    };
    if !(0.0..=64.0).contains(&budget_gib) {
        return Err("--witness-cache-gib is outside 0..=64".into());
    }
    // D60: a D55 fork run (the registered profile of the run's base)
    let d55_workers = d55_workers_of(f)?;
    if d55_workers.is_some() && lie_at.is_some() {
        return Err("--lie-at-boundary is a D12a control; it does not combine with --d55-workers".into());
    }
    // D60 review F3: a D55 fork run fails CLOSED until the real-content
    // privacy gate has passed, unless the operator acknowledges a TEST receipt
    // (refused here, before anything is read or created)
    let test_receipt = d55_prove_admission(d55_workers, flag(f, D55_TEST_RECEIPT_FLAG).is_some(), run::fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED)?;
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
        ex.enable_dd()?;
    }
    let layers = parse_layers(flag(f, "--layers"), &ex.layers)?;
    let l = layers.len();
    if let Some(k) = lie_at {
        if k + 1 >= l {
            return Err("--lie-at-boundary: there is no boundary after the last block".into());
        }
    }
    let rope = flag(f, "--rope-from-export").is_some();
    // [A19] a D55 fork run (D60) takes production's D55 path: the sealing pass
    // with each fork's before-challenge part beside it when A13's window is on,
    // the fork run on the sealing pass's own blocks
    if let Some(n) = d55_workers {
        return stack_prove_d55(f, &ex, &layers, rope, &seq, label, (budget_gib * (1u64 << 30) as f64) as u64, n, test_receipt, &out, &unverified, t_total);
    }
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
        "{{\"event\":\"sealed\",\"from\":\"the witness builder's own pass over layers {}..{} (parity bit-exact at every layer, before the run header: ruling H-1)\",\"seconds\":{:.3},\"of_which_load_seconds\":{:.3},\"of_which_witness_seconds\":{:.3},\"kept_witnesses\":{kept_n},\"kept_witness_bytes\":{kept_bytes},\"rayon_threads\":{},\"seal_pool_threads\":{}}}",
        layers[0],
        layers[l - 1] + 1,
        seal.wall_s,
        seal.load_s,
        seal.witness_s,
        rayon::current_num_threads(),
        seal.pool_threads
    );
    println!("{{\"event\":\"parity\",\"result\":\"bit-exact at every layer\",\"layers\":{l},\"words_per_layer\":{},\"checked_before_the_run_header\":true}}", sh.tokens * sh.width);
    // ---- (2) the endpoints (the builder's own planes) and the bound run statement
    let ctx = stack_context(&ex.variant, &layers, label)?;
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &chain.first, &chain.last)?;
    let rst = RunStatement::new_bound_from_digests(ex.geometry.run_shape(&sh, l)?, ctx, expected.clone(), digests.clone(), &vec![(0, 0); l], &st)?;
    // [A19] (a D55 fork run took `stack_prove_d55` above; this is D12a's path)
    let cache = BlockCache::shared(&ex, &sh, &c, layers.clone(), digests.clone(), rope);
    let mut src = StackSource::new(&sh, StackBlocks::Cache(cache.clone()), l, chain, lie_at)?;
    // ---- (3) the proving pass
    std::fs::create_dir(&out).map_err(|e| format!("{}: {e}", out.display()))?;
    let t = Instant::now();
    // the frames written (length, SHA-256), in file order: D12a's segments
    let proved: Result<Vec<(u64, String)>, String> = {
        let mut disk = match super::run_sink::DirSink::create(&out, l) {
            Ok(d) => d,
            Err(e) => return Err(fail_run(&out, e)),
        };
        let stats = {
            let mut sink = |k: usize, bytes: Vec<u8>| -> Result<(), String> {
                let n = bytes.len();
                super::run_sink::SegmentSink::accept(&mut disk, k, bytes)?;
                println!("{{\"event\":\"segment\",\"index\":{k},\"layer\":{},\"bytes\":{n},\"elapsed_seconds\":{:.3},\"vmhwm_mib\":{:.0}}}", layers[k], t.elapsed().as_secs_f64(), peak_rss_mib());
                Ok(())
            };
            run::prove_run_with(&rst, &mut CacheBlocks(cache.clone()), &mut src, owners, &mut sink)
        };
        stats.map(|_| (0..l).map(|k| (disk.lengths()[k] as u64, disk.digests()[k].clone())).collect())
    };
    let prove_s = t.elapsed().as_secs_f64();
    let (rebuild_s, rebuilt) = (src.busy_s, src.chain.rebuilt);
    drop(src);
    let sunk = match proved {
        Ok(s) => s,
        Err(e) => return Err(fail_run(&out, format!("prove_run: {e}"))),
    };
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
    // ([A19] a D55 fork run's, which names its frames, is `stack_prove_d55`'s)
    let frames_json = render_segments_json;
    let fork_names: Option<(&str, &str)> = None;
    let claims = ProverClaims::of_this_process();
    // NATIVE R7 (Q-2): the prover writes only the build's constants
    check_prover_reported(&claims.backend, claims.gpu_declines).map_err(|e| fail_run(&out, e))?;
    let sdir = match verified_seen {
        Some(seen) => {
            if seen != sunk {
                return Err(fail_run(&out, "in-process verification: the bytes it verified are not the bytes the prover wrote".into()));
            }
            let stmt = render_stack_statement_for(&ex, &sh, &loaded, &st, &ctx, &expected, label, StatementWriter::InProcess, &claims, fork_names);
            publish_statement_dir(&out, &[("expected.bin", &expected.to_bytes()), ("statement.json", stmt.as_bytes()), ("segments.json", frames_json(&seen).as_bytes())]).map_err(|e| fail_run(&out, e))?
        }
        None => {
            std::fs::create_dir(&unverified).map_err(|e| format!("{}: {e}", unverified.display()))?;
            write_new(&unverified.join(UNVERIFIED_MARKER), UNVERIFIED_TEXT)?;
            write_new(&unverified.join("expected.bin"), &expected.to_bytes())?;
            write_new(&unverified.join("statement.json"), render_stack_statement_for(&ex, &sh, &loaded, &st, &ctx, &expected, label, StatementWriter::Unverified, &claims, fork_names).as_bytes())?;
            write_new(&unverified.join("segments.json"), frames_json(&sunk).as_bytes())?;
            unverified.clone()
        }
    };
    println!(
        "{{\"event\":\"proved\",\"gpu\":{},\"gpu_declines\":{},\"blocks\":{l},\"receipt_bytes\":{},\"prove_run_seconds\":{prove_s:.3},\"of_which_witness_seconds\":{rebuild_s:.3},\"rebuilt_witnesses\":{rebuilt},\"witness_seconds_per_block\":{:.3},\"of_which_block_load_seconds\":{block_load_s:.3},\"block_loads\":{block_loads},\"rayon_threads\":{},\"in_process_verified\":{in_process},\"in_process_verify_seconds\":{verify_s:.3},\"sealing_pass_seconds\":{:.3},\"sealing_witness_seconds\":{:.3},\"load_seconds\":{:.3},\"total_seconds\":{:.3},\"vmhwm_mib\":{hwm:.0},\"statement_identity\":{},\"statement_dir\":{},\"out\":{}}}",
        js(&crate::gpu::label()),
        crate::gpu::declines(),
        sunk.iter().map(|(n, _)| *n).sum::<u64>(),
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
///
/// **D60: `--d55-workers N`** verifies a D55 fork receipt (the registered
/// D55 profile of the run's base; its `L + 2` frames, each read bounded
/// against its counted length) with the forks on `N` threads, and checks the
/// statement as the D55 prover renders it. Without the flag the verifier is
/// D12a's and refuses a fork run's directory; with it, a D12a run's. Not with
/// `--controls` (D12a's run-level controls). **D60 review F3:** every D55
/// verification prints a `d55-publication` event: whether the run directory
/// carries the test-receipt marker (`present` / `ABSENT`) and whether this
/// build's real-content privacy gate has passed; the verifier stays usable
/// either way.
pub fn trained_stack_verify_command(args: &[String]) -> i32 {
    let f = match flags(args, &["--export", "--artifact", "--expect-statement", "--layers", "--label", "--d55-workers"], &["--rope-from-export", "--controls", "--dd"]) {
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
    // D60: a D55 fork receipt's verifier
    let d55_workers = d55_workers_of(f)?;
    if d55_workers.is_some() && flag(f, "--controls").is_some() {
        return Err("--controls are D12a's run-level controls; they do not combine with --d55-workers".into());
    }
    let t = Instant::now();
    // R5b (P-5): the verifier's export holds no prover-private seq_* entry
    refuse_prover_private_entries(&export)?;
    let mut ex = TrainedExport::load(&export)?;
    // NATIVE R9 (D30): `--dd` proves / verifies under the DD profile of the
    // export's model and T (refused by name where none is registered)
    if flag(f, "--dd").is_some() {
        ex.enable_dd()?;
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
    // D60: the fork run's door (an ineligible base is refused by name)
    let fork = match d55_workers {
        Some(n) => Some((run::fork::ForkRun::new(&rst, run::fork::D55OptIn::registered_profile())?, n)),
        None => None,
    };
    let fork_names = fork.as_ref().map(|(fr, _)| (fr.profile().to_string(), rst.rs().profile().to_string()));
    let fork_names = fork_names.as_ref().map(|(d, b)| (d.as_str(), b.as_str()));
    let load_s = t.elapsed().as_secs_f64();
    let t = Instant::now();
    // NATIVE R6 (r5_A (b)): the hashes of EXACTLY the bytes verified
    let (seen, block_load_s) = match &fork {
        None => {
            let vcache = BlockCache::shared(&ex, &sh, &c, layers.clone(), digests.clone(), rope);
            let seen = run::verify_run_from_dir_hashed_with(&rst, &mut CacheBlocks(vcache.clone()), &art)?;
            let s = vcache.borrow().load_s;
            (seen, s)
        }
        Some((fr, workers)) => {
            let (blocks, s) = load_fork_blocks(&ex, &sh, &c, &layers, &digests, rope)?;
            (run::fork::verify_run_with_forks_from_dir(fr, &blocks, &art, *workers)?, s)
        }
    };
    let verify_s = t.elapsed().as_secs_f64();
    let total: u64 = seen.iter().map(|(n, _)| *n).sum();
    println!(
        "{{\"event\":\"verified\",\"blocks\":{l},\"receipt_bytes\":{total},\"load_seconds\":{load_s:.3},\"verify_seconds\":{verify_s:.3},\"of_which_block_load_seconds\":{block_load_s:.3},\"vmhwm_mib\":{:.0},\"statement_identity\":{},\"scope\":{}}}",
        peak_rss_mib(),
        js(&hex(&st.identity())),
        js(stack_scope(ex.geometry))
    );
    // D60 review F3: on EVERY verification of a D55 fork receipt, whether it
    // is a test receipt (its marker) and whether this build's real-content
    // privacy gate has passed; while it has not, no D55 receipt is for
    // publication, marked or not
    if fork.is_some() {
        let marked = run::fork::d55_test_receipt_marker(&art)?;
        let gate = run::fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED;
        println!(
            "{{\"event\":\"d55-publication\",\"not_for_publication\":{},\"test_receipt_marker\":{},\"real_content_privacy_gate_passed\":{gate},\"why\":{}}}",
            marked || !gate,
            js(if marked { "present" } else { "ABSENT" }),
            js(match (marked, gate) {
                (true, _) => "the run directory carries the D55 test-receipt marker (stack-prove --d55-test-receipt-not-for-publication): a TEST receipt, not for publication (D60 review F3)",
                (false, false) => "the run directory carries no test-receipt marker, but this build's D60 real-content privacy gate has not passed (run_fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED is false): no D55 receipt is for publication (D60 review F3)",
                (false, true) => "no test-receipt marker; the D60 real-content privacy gate has passed in this build",
            })
        );
    }
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
    let segs_json = if fork.is_some() { render_fork_frames_json(&seen) } else { render_segments_json(&seen) };
    let found_stmt = read_bounded(&sdir.join("statement.json"), MAX_JSON_BYTES)?;
    let found_segs = read_bounded(&sdir.join("segments.json"), MAX_JSON_BYTES)?;
    let (writer, claims) = ProverClaims::of_statement(&found_stmt).map_err(|e| format!("{}: {e} (review r5_A)", sdir.display()))?;
    let allowed: &[StatementWriter] = if promote { &[StatementWriter::Unverified] } else { &[StatementWriter::InProcess, StatementWriter::FreshVerify] };
    if !allowed.contains(&writer) {
        return Err(format!("{}: statement.json names the writer \"{}\", which does not write this directory (review r5_A)", sdir.display(), writer.text()));
    }
    if render_stack_statement_for(&ex, &sh, &loaded, &st, &ctx, &expected, label, writer, &claims, fork_names).as_bytes() != found_stmt.as_slice() {
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
    let stmt = render_stack_statement_for(&ex, &sh, &loaded, &st, &ctx, &expected, label, StatementWriter::FreshVerify, &claims, fork_names);
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

/// **D65(2) (Victor, 2026-11-04): one constant external refusal.**
///
/// A refusal's text can be a function of the hidden input: the witness builder's
/// "fixed oracle range refusal: <site>" names one of 12 sites, CS-3 names the table
/// family that missed, and the dictionary checks say which tuple failed. By
/// `formal/ZK60Formal/HidingRefusal.lean`, `refusal_output_must_be_leaked`, any such
/// detail in the prover's external output breaks the approved ZeroKnowledge, whose
/// declared leakage is only "whether it is served" (L4 finding 1).
///
/// So every prove command (token I/O, classify, classify batch, trained block, trained
/// stack) prints the same event when it refuses after its arguments parsed:
/// `{"event":"refused","command":<the command>,"error":"refused","detail":"owner-private"}`.
/// The command name is public. Argument errors (exit 2, before anything is read) and
/// verifier refusals (about public receipts) keep their text.
///
/// The detail goes ONLY to the owner's private log: `refusals.log` in
/// `$HL_OWNER_PRIVATE_DIR`, or by default `$HOME/zk60-owner-private`. That is outside
/// every run directory; the directory is created 0700 and the file 0600, and the log is
/// appended, never printed. If the log cannot be written, the detail is dropped and the
/// external line is unchanged.
///
/// Not covered, on purpose: the MVP diagnostic driver (`mvp_driver.rs`), whose scope
/// string says it proves a synthetic input with no privacy claim made or implied.
pub(crate) mod refusal {
    use std::io::Write;
    use std::path::{Path, PathBuf};

    /// the one external refusal text
    pub(crate) const EXTERNAL_REFUSAL: &str = "refused";

    /// where the owner's private refusal log lives (`None`: no `$HOME` and no override)
    pub(crate) fn private_log_dir() -> Option<PathBuf> {
        if let Some(d) = std::env::var_os("HL_OWNER_PRIVATE_DIR") {
            return Some(PathBuf::from(d));
        }
        // tests never write into the real owner directory
        if cfg!(test) {
            return Some(std::env::temp_dir().join("zk60-test-owner-private"));
        }
        std::env::var_os("HOME").map(|h| PathBuf::from(h).join("zk60-owner-private"))
    }

    /// Append `{command, detail}` to `<dir>/refusals.log` (directory 0700, file 0600).
    pub(crate) fn log_private_at(dir: &Path, command: &str, detail: &str) -> Result<PathBuf, String> {
        use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};
        std::fs::DirBuilder::new().recursive(true).mode(0o700).create(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
        let path = dir.join("refusals.log");
        let stamp = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
        let line = format!(
            "{{\"unix_s\":{stamp},\"pid\":{},\"command\":{},\"detail\":{}}}\n",
            std::process::id(),
            super::js(command),
            super::js(detail)
        );
        let mut f = std::fs::OpenOptions::new().create(true).append(true).mode(0o600).open(&path).map_err(|e| format!("{}: {e}", path.display()))?;
        // an existing file keeps its mode; make sure it is the owner's alone
        let _ = std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600));
        f.write_all(line.as_bytes()).and_then(|_| f.sync_all()).map_err(|e| format!("{}: {e}", path.display()))?;
        Ok(path)
    }

    /// the external event line for a refused `command`: identical for every detail
    pub(crate) fn external_event(command: &str) -> String {
        format!("{{\"event\":\"refused\",\"command\":{},\"error\":{},\"detail\":\"owner-private\"}}", super::js(command), super::js(EXTERNAL_REFUSAL))
    }

    /// Refuse `command` externally: log `detail` privately and print the constant event.
    /// Returns the exit code, 1.
    pub(crate) fn refuse(command: &str, detail: &str) -> i32 {
        if let Some(dir) = private_log_dir() {
            let _ = log_private_at(&dir, command, detail);
        }
        println!("{}", external_event(command));
        1
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        /// The external line does not depend on the detail; the detail reaches only the
        /// private log, which is the owner's alone.
        #[test]
        fn d65_the_external_refusal_is_constant_and_the_detail_stays_private() {
            let a = "fixed oracle range refusal: score";
            let b = "CS-3: a lookup missed the exp table family";
            assert_eq!(external_event("prove"), external_event("prove"));
            let line = external_event("prove");
            for d in [a, b] {
                assert!(!line.contains(d), "the external line carries the detail");
            }
            assert!(line.contains("\"error\":\"refused\""));
            let dir = std::env::temp_dir().join(format!("zk60-d65-refusal-test-{}", std::process::id()));
            let _ = std::fs::remove_dir_all(&dir);
            let p = log_private_at(&dir, "prove", a).unwrap();
            log_private_at(&dir, "prove", b).unwrap();
            let text = std::fs::read_to_string(&p).unwrap();
            assert!(text.contains(a) && text.contains(b), "the private log lost a detail");
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(std::fs::metadata(&p).unwrap().permissions().mode() & 0o777, 0o600, "the log is not 0600");
            assert_eq!(std::fs::metadata(&dir).unwrap().permissions().mode() & 0o777, 0o700, "the log directory is not 0700");
            let _ = std::fs::remove_dir_all(&dir);
        }
    }
}

/// Efficiency plan A3: the default witness-cache budget is sized to the machine, inside the
/// flag's bounds.
#[cfg(test)]
mod a3_tests {
    #[test]
    fn a3_the_default_witness_cache_is_sized_to_the_machine() {
        let g = super::default_witness_cache_gib();
        assert!((4.0..=64.0).contains(&g), "the default budget {g} GiB is outside 4..=64");
        match super::total_ram_gib() {
            Some(r) => {
                assert!(r > 1.0, "the machine reports {r} GiB of RAM");
                assert_eq!(g, (r / 8.0).clamp(4.0, 64.0));
                eprintln!("A3: {r:.0} GiB of RAM, default witness cache {g:.1} GiB");
            }
            None => assert_eq!(g, 4.0),
        }
    }
}

//! **TOKEN I/O: THE PRODUCTION LOADERS (review TR3-2, 2026-10-19).** What a
//! token-I/O run reads from disk, moved out of the R3 tests and hardened:
//!
//! * the token tables in the calibration lanes' format (the TinyLlama R2
//!   inputs, the Llama-3-8B `<export>/token_io/`): `embedding_int16.bin`
//!   ([V, d] int16 LE) described by `token_io.json`, `head_int8_perrow.bin`
//!   ([V, d] int8) and `head_mult12.bin` ([V] int64 LE) described by
//!   `head_manifest.json` (each file's SHA-256, V, d, BOS and the final norm).
//!   The two manifests are read BOUNDED from regular files (no link followed;
//!   `run::read_regular_file_bounded`) and parsed by the strict JSON parser
//!   (`trained_block::parse_json`): a truncated or malformed manifest is an
//!   error naming the file, never a panic. The three tables are read with the
//!   metadata-length check first, then exactly that many bytes in 16 MiB
//!   chunks, the SHA-256 streamed and compared with the manifest's, and built
//!   once (no second copy of a 1.05 GB table). The binding does not rest on
//!   the manifests: the tables enter the run statement by their own digests
//!   (D25 T7);
//! * the export's public side of a token run (the digest pass: every layer
//!   loaded, its record and block digest kept, the block dropped) and the
//!   trained-model statement under a token-I/O run profile;
//! * the streaming block source: block `k` reloaded at its stage and refused
//!   unless its digest is the digest pass's (CS-6 on reload), ONE resident.

use super::run::TokenBlocks;
use super::*;
use super::super::run::{read_regular_file_bounded, BlockRef};
use super::super::trained_block::{parse_json, Constants, TrainedExport, J};
use super::super::trained_statement::{IntegerCalibration, LayerRecord, Provenance, TrainedModelStatement};
use super::super::BlockPublic;
use std::path::{Path, PathBuf};

/// the largest manifest a loader reads
pub(crate) const MAX_MANIFEST_BYTES: u64 = 1 << 20;
/// the read chunk of the table files
const CHUNK: usize = 16 << 20;
/// `O_NOFOLLOW | O_NONBLOCK` (x86-64 Linux), as `run::read_regular_file_bounded`
#[cfg(all(target_os = "linux", target_arch = "x86_64"))]
const TABLE_OPEN_FLAGS: i32 = 0o400000 | 0o4000;

/// where the token tables are: the embedding's directory (with
/// `token_io.json`) and the head's (with `head_manifest.json`); the same
/// directory for the 8B exports
#[derive(Clone, Debug)]
pub(crate) struct TableFiles {
    pub emb_dir: PathBuf,
    pub head_dir: PathBuf,
}

/// what the two manifests declare
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct TableManifest {
    pub v: usize,
    pub d: usize,
    pub bos: u64,
    pub emb_sha256: String,
    pub head_sha256: String,
    pub mult_sha256: String,
    /// the final norm with the CALIBRATED `Cn` (`cn_calibrated`)
    pub norm: FinalNorm,
}

fn manifest(path: &Path) -> Result<J, String> {
    let b = read_regular_file_bounded(path, MAX_MANIFEST_BYTES, false)?;
    parse_json(&b).map_err(|e| format!("{}: {e}", path.display()))
}

fn sha_hex(j: Result<&J, String>, path: &Path, what: &str) -> Result<String, String> {
    let s = j.and_then(J::str).map_err(|e| format!("{}: {what}: {e}", path.display()))?;
    if s.len() != 64 || !s.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err(format!("{}: {what} is not a 64-hex-digit SHA-256", path.display()));
    }
    Ok(s.to_ascii_lowercase())
}

fn uint(j: Result<&J, String>, path: &Path, what: &str) -> Result<u64, String> {
    let v = j.and_then(J::i64).map_err(|e| format!("{}: {what}: {e}", path.display()))?;
    u64::try_from(v).map_err(|_| format!("{}: {what} is negative", path.display()))
}

/// **The two manifests, parsed** (strict JSON, bounded reads), and their
/// cross-checks: V and d agree between the embedding's shape and the head
/// manifest; a BOS in `token_io.json`, when present, is the head manifest's.
pub(crate) fn read_manifests(files: &TableFiles) -> Result<TableManifest, String> {
    let tp = files.emb_dir.join("token_io.json");
    let hp = files.head_dir.join("head_manifest.json");
    let tio = manifest(&tp)?;
    let hm = manifest(&hp)?;
    let et = tio.get("embedding_table").map_err(|e| format!("{}: {e}", tp.display()))?;
    let emb_sha256 = sha_hex(et.get("sha256"), &tp, "embedding_table.sha256")?;
    let shape = et.get("shape").and_then(J::arr).map_err(|e| format!("{}: embedding_table.shape: {e}", tp.display()))?;
    if shape.len() != 2 {
        return Err(format!("{}: embedding_table.shape is not [V, d]", tp.display()));
    }
    let (ev, ed) = (uint(Ok(&shape[0]), &tp, "embedding_table.shape[0]")?, uint(Ok(&shape[1]), &tp, "embedding_table.shape[1]")?);
    let v = uint(hm.get("V"), &hp, "V")?;
    let d = uint(hm.get("d"), &hp, "d")?;
    let bos = uint(hm.get("bos"), &hp, "bos")?;
    if (ev, ed) != (v, d) {
        return Err(format!("{}: the embedding is [{ev}, {ed}] and {} declares V {v}, d {d}", tp.display(), hp.display()));
    }
    if let Some(b) = tio.opt("bos") {
        if uint(Ok(b), &tp, "bos")? != bos {
            return Err(format!("{} and {} declare different BOS ids", tp.display(), hp.display()));
        }
    }
    let head_sha256 = sha_hex(hm.get("head_int8_perrow.bin").and_then(|h| h.get("sha256")), &hp, "head_int8_perrow.bin.sha256")?;
    let mult_sha256 = sha_hex(hm.get("head_mult12.bin").and_then(|h| h.get("sha256")), &hp, "head_mult12.bin.sha256")?;
    let fnm = hm.get("final_norm").map_err(|e| format!("{}: {e}", hp.display()))?;
    let int = |k: &str| fnm.get(k).and_then(J::i64).map_err(|e| format!("{}: final_norm.{k}: {e}", hp.display()));
    let tn = u32::try_from(int("tn")?).map_err(|_| format!("{}: final_norm.tn is out of range", hp.display()))?;
    let norm = FinalNorm { g0: int("g0")?, cn: int("cn_calibrated")?, tn, ceps: int("ceps")? };
    let us = |x: u64, what: &str| usize::try_from(x).map_err(|_| format!("{}: {what} is out of range", hp.display()));
    Ok(TableManifest { v: us(v, "V")?, d: us(d, "d")?, bos, emb_sha256, head_sha256, mult_sha256, norm })
}

/// read EXACTLY `len` bytes of a regular file (no link followed; its length
/// checked before it is read), in chunks, the SHA-256 streamed and compared
/// with `want`; `each` receives every chunk
pub(crate) fn read_exact_streamed(path: &Path, len: usize, want: &str, mut each: impl FnMut(&[u8])) -> Result<(), String> {
    use sha2::Digest as _;
    use std::io::Read;
    let meta = std::fs::symlink_metadata(path).map_err(|e| format!("{}: {e}", path.display()))?;
    if !meta.file_type().is_file() {
        return Err(format!("{}: not a regular file (a link, FIFO or directory is refused before it is opened)", path.display()));
    }
    if meta.len() != len as u64 {
        return Err(format!("{}: {} bytes, the table is {len}", path.display(), meta.len()));
    }
    // review TR4-4: the open follows no link and does not block on a FIFO
    // (R7's segment open flags, `O_NOFOLLOW | O_NONBLOCK` on x86-64 Linux);
    // the opened file is re-checked below
    let mut opts = std::fs::OpenOptions::new();
    opts.read(true);
    #[cfg(all(target_os = "linux", target_arch = "x86_64"))]
    {
        use std::os::unix::fs::OpenOptionsExt;
        opts.custom_flags(TABLE_OPEN_FLAGS);
    }
    let mut f = opts.open(path).map_err(|e| format!("{}: cannot be opened as a regular file: {e}", path.display()))?;
    let fm = f.metadata().map_err(|e| format!("{}: {e}", path.display()))?;
    if !fm.file_type().is_file() || fm.len() != len as u64 {
        return Err(format!("{}: changed after its check; refused", path.display()));
    }
    let mut h = sha2::Sha256::new();
    let mut buf = vec![0u8; CHUNK.min(len.max(1))];
    let mut left = len;
    while left > 0 {
        let n = left.min(buf.len());
        f.read_exact(&mut buf[..n]).map_err(|e| format!("{}: {e}", path.display()))?;
        h.update(&buf[..n]);
        each(&buf[..n]);
        left -= n;
    }
    let got: [u8; 32] = h.finalize().into();
    if hex(&got) != want {
        return Err(format!("{}: not the recorded table (sha256 {} != {want})", path.display(), hex(&got)));
    }
    Ok(())
}

/// **THE TOKEN TABLES' LOADER**: the manifests, then the three tables at the
/// manifest's V x d, which must be the caller's `(v, d)`
pub(crate) fn load_token_tables(files: &TableFiles, v: usize, d: usize) -> Result<(TokenTables, TableManifest), String> {
    let m = read_manifests(files)?;
    if (m.v, m.d) != (v, d) {
        return Err(format!("token tables: the manifests declare V {} x d {}, the run needs V {v} x d {d}", m.v, m.d));
    }
    let n = v.checked_mul(d).ok_or("token tables: V x d overflows")?;
    let mut emb: Vec<i16> = Vec::with_capacity(n);
    read_exact_streamed(&files.emb_dir.join("embedding_int16.bin"), 2 * n, &m.emb_sha256, |b| emb.extend(b.chunks_exact(2).map(|c| i16::from_le_bytes([c[0], c[1]]))))?;
    let mut head: Vec<i8> = Vec::with_capacity(n);
    read_exact_streamed(&files.head_dir.join("head_int8_perrow.bin"), n, &m.head_sha256, |b| head.extend(b.iter().map(|x| *x as i8)))?;
    let mut mult: Vec<i64> = Vec::with_capacity(v);
    read_exact_streamed(&files.head_dir.join("head_mult12.bin"), 8 * v, &m.mult_sha256, |b| mult.extend(b.chunks_exact(8).map(|c| i64::from_le_bytes([c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7]]))))?;
    Ok((TokenTables::new(v, d, emb, head, mult)?, m))
}

/// the token-I/O run profile of an export's block shape
pub(crate) fn token_run_profile_of(sh: &Shape) -> Result<&'static str, String> {
    use super::super::run::{RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32, RUN_PROFILE_TOKEN_IO_RUNG_TC, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32};
    use super::super::shape::{LLAMA3_8B_T128_TRAINED_PROFILE, LLAMA3_8B_T32_TRAINED_PROFILE, TINYLLAMA_T128_TRAINED_PROFILE, TINYLLAMA_T32_TRAINED_PROFILE, TRAINED_CALIB_RUNG_PROFILE};
    match sh.profile {
        p if p == TRAINED_CALIB_RUNG_PROFILE => Ok(RUN_PROFILE_TOKEN_IO_RUNG_TC),
        p if p == TINYLLAMA_T32_TRAINED_PROFILE => Ok(RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32),
        p if p == LLAMA3_8B_T32_TRAINED_PROFILE => Ok(RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32),
        // TOKEN I/O ROUND 8: the T128 next-token profiles
        p if p == TINYLLAMA_T128_TRAINED_PROFILE => Ok(RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128),
        p if p == LLAMA3_8B_T128_TRAINED_PROFILE => Ok(RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128),
        p => Err(format!("token I/O: no token-I/O run profile is registered for the block profile {p}")),
    }
}

/// **THE EXPORT'S PUBLIC SIDE OF A TOKEN RUN** (the digest pass): every layer
/// loaded (every array SHA-256-checked by the native loader), its record and
/// block digest kept, the block DROPPED; the trained-model statement under
/// the token-I/O run profile of the export's shape
pub(crate) struct ExportPublic {
    pub ex: TrainedExport,
    pub c: Constants,
    pub sh: Shape,
    pub layers: Vec<u32>,
    pub digests: Vec<Digest>,
    pub model: TrainedModelStatement,
    pub profile: &'static str,
}

impl ExportPublic {
    pub(crate) fn load(export: &Path) -> Result<ExportPublic, String> {
        let ex = TrainedExport::load(export)?;
        let layers = ex.layers.clone();
        let c = ex.run_constants(&layers)?;
        let sh = ex.shape_for(&c)?;
        let profile = token_run_profile_of(&sh)?;
        let mut digests = Vec::with_capacity(layers.len());
        let mut records: Vec<LayerRecord> = Vec::with_capacity(layers.len());
        for &k in &layers {
            let t = ex.load_layer(&sh, &c, k, false)?;
            digests.push(t.record.block_digest);
            records.push(t.record);
        }
        let prov = Provenance {
            label: format!("export:{}", ex.variant),
            residual_unit: ex.residual_unit,
            quantizer_sha256: ex.tool_sha256,
            calibration_set_sha256: ex.calibration_set_sha256,
            export_profile_sha256: ex.profile_sha256,
            calibration_tool_sha256: ex.tool_sha256,
            rope_theta: c.rope_theta,
            // native R12 (F1): the export's RoPE transform (encoded only when not `none`)
            rope_scaling: ex.rope_scaling,
        };
        let cal = IntegerCalibration::as_the_code_proves(&sh, &prov);
        let model = TrainedModelStatement::new(&sh, profile, ex.source.clone(), cal, records)?;
        Ok(ExportPublic { ex, c, sh, layers, digests, model, profile })
    }
}

/// **THE STREAMING BLOCK SOURCE**: block `k` reloaded from the export at its
/// stage (`reload_block`, the native proving-pass reload) and refused unless
/// its digest is the digest pass's; ONE block resident
pub(crate) struct ExportTokenBlocks<'a> {
    p: &'a ExportPublic,
    cur: Option<(usize, std::sync::Arc<BlockPublic>)>,
    pub load_s: f64,
    pub loads: usize,
}

impl<'a> ExportTokenBlocks<'a> {
    pub(crate) fn new(p: &'a ExportPublic) -> ExportTokenBlocks<'a> {
        ExportTokenBlocks { p, cur: None, load_s: 0.0, loads: 0 }
    }
}

impl TokenBlocks for ExportTokenBlocks<'_> {
    fn count(&self) -> usize {
        self.p.layers.len()
    }
    fn block(&mut self, k: usize) -> Result<BlockRef<'_>, String> {
        if let Some((j, a)) = &self.cur {
            if *j == k {
                return Ok(BlockRef::Shared(a.clone()));
            }
        }
        // drop the previous block BEFORE the next one is read
        self.cur = None;
        let t = std::time::Instant::now();
        let layer = *self.p.layers.get(k).ok_or_else(|| format!("token I/O: no block {k}"))?;
        let blk = self.p.ex.reload_block(&self.p.sh, &self.p.c, layer, false)?;
        if blk.digest() != self.p.digests[k] {
            return Err(format!("token I/O: layer {layer}'s reloaded public statement is not the digest pass's (ruling CS-6)"));
        }
        let a = std::sync::Arc::new(blk);
        self.cur = Some((k, a.clone()));
        self.load_s += t.elapsed().as_secs_f64();
        self.loads += 1;
        Ok(BlockRef::Shared(a))
    }
}

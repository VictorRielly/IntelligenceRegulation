//! [UPERF3-AC] The per-model WEIGHT-COMMITMENT CACHE (`--wcache DIR`).
//!
//! Under mode P1 (weights public) a layer's W commitment is per-MODEL
//! work: the same int8 weights, the same layout, the same PCS parameters
//! give the same Ligero matrix, the same column leaves and the same Merkle
//! root on every proof. What a proof needs from that commitment is (a) the
//! root (absorbed into the transcript) and (b), at the opening, the row
//! combinations over the SYSTEMATIC data, the Q sampled encoded columns and
//! their Merkle authentication paths.
//!
//! WHAT IS CACHED (tier 1): the whole Merkle tree (every level, leaves
//! first; 2 x nn x 32 B — 4.2 MB at nn = 2^16) under a key that binds the
//! profile, the layer index, (d, f), the PCS parameters (log_cols,
//! inv_rate), the matrix shape and a digest of the ACTUAL int8 weight planes
//! the prover holds (so a tampered witness never reuses an honest tree).
//! On a hit the tree is VERIFIED ON LOAD: every level is re-hashed pairwise
//! into the next and the last level must equal the stored root; the leaf
//! count must equal nn. A corrupted or foreign entry is a miss (re-committed
//! and re-written), never a silent reuse.
//!
//! WHAT IS NOT CACHED and why: the encoded matrix itself. The Q sampled
//! columns are chosen by the transcript AFTER the commitment, so the prover
//! must be able to produce ANY column at opening time: either from the
//! resident encoding (the CPU store `pcs::Store::Host` holds rows x nn — the
//! same memory as an uncached run; pcs.rs is read-only for this lane) or by
//! re-encoding on demand (the device path re-encodes in row chunks at the
//! opening and never holds the full encoding — see gpu/cuda.rs). So a warm
//! cache removes the HASHING (blake3 over the 4x-expanded matrix) and the
//! tree build from the commit phase; the NTT is paid once more at the
//! opening on the CPU path and once (chunked) on the device path. The
//! counted alternative — persisting the encoded rows (5.6 GB per 7B layer,
//! 180 GB per model) — is recorded in the lane's status section, not built.
//!
//! BYTE IDENTITY: the cached tree has the same root (the transcript absorbs
//! the same bytes), the same leaves and paths (the opening's paths are the
//! same digests), and the opened columns are the same field elements by the
//! uniqueness of canonical representatives (an RS codeword symbol is one
//! field value however it is evaluated). The proof bytes of a cached run
//! equal the uncached run's — the gate is `PROOF sha256` on both.
//!
//! File format (`<dir>/<profile>-l<NN>-<key16>.wc`, little-endian):
//!   magic "HLWCACH1" | key [32] | rows u64 | log_cols u32 | inv_rate u32 |
//!   nn u64 | n_levels u32 | root [32] | level 0 (nn x 32 B) | level 1 | ...

use crate::field::Fp;
use crate::merkle::{hash_pair, Digest, MerkleTree};
use crate::ntt::NttTables;
use crate::pcs::{self, Committed, PcsParams, Store};
use rayon::prelude::*;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::Instant;

static DIR: OnceLock<Option<PathBuf>> = OnceLock::new();

/// Set once by the driver (`--wcache DIR`); `None` keeps every W commit on
/// the plain `pcs::commit` path (byte-identical, no file I/O).
pub fn configure(dir: Option<&str>) {
    let d = dir.map(PathBuf::from);
    if let Some(p) = &d {
        std::fs::create_dir_all(p).unwrap_or_else(|e| panic!("wcache: cannot create {} ({e})", p.display()));
    }
    if DIR.set(d).is_err() {
        panic!("wcache: configured twice");
    }
}

pub fn dir() -> Option<&'static Path> {
    DIR.get().and_then(|d| d.as_deref())
}

/// Per-process accounting for the driver's report.
#[derive(Clone, Debug, Default)]
pub struct Stats {
    pub hits: usize,
    pub misses: usize,
    pub rejected: usize,
    pub bytes_read: u64,
    pub bytes_written: u64,
    pub secs_key: f64,
    pub secs_load: f64,
    pub secs_save: f64,
    pub secs_reencode: f64,
    pub secs_commit: f64,
}
static STATS: Mutex<Stats> = Mutex::new(Stats {
    hits: 0, misses: 0, rejected: 0, bytes_read: 0, bytes_written: 0, secs_key: 0.0, secs_load: 0.0, secs_save: 0.0, secs_reencode: 0.0, secs_commit: 0.0,
});
pub fn stats() -> Stats {
    STATS.lock().unwrap().clone()
}
fn stat<F: FnOnce(&mut Stats)>(f: F) {
    f(&mut STATS.lock().unwrap());
}

/// The identity of one layer's weight commitment: the statement profile,
/// the layer, (d, f) and the three int8 planes the layout is built from.
/// The digest is computed lazily (only when a cache dir is configured).
pub struct WKey<'a> {
    pub profile: &'a str,
    pub l: usize,
    pub d: usize,
    pub f: usize,
    pub planes: [&'a [i8]; 3],
}

impl<'a> WKey<'a> {
    pub fn new(profile: &'a str, l: usize, d: usize, f: usize, wg_t: &'a [i8], wu_t: &'a [i8], wd_t: &'a [i8]) -> WKey<'a> {
        WKey { profile, l, d, f, planes: [wg_t, wu_t, wd_t] }
    }

    /// blake3 over: the layout/version tag, the profile, l, d, f, log_cols,
    /// inv_rate, rows, len, then per plane its length and the plane digest
    /// (the plane digested in 16 MB pieces in parallel, the piece digests
    /// chained — a fixed, deterministic tree).
    fn digest(&self, params: &PcsParams, rows: usize, len: usize) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline-wcache-v1");
        h.update(self.profile.as_bytes());
        for v in [self.l as u64, self.d as u64, self.f as u64, params.log_cols as u64, params.inv_rate as u64, rows as u64, len as u64] {
            h.update(&v.to_le_bytes());
        }
        for p in self.planes {
            h.update(&(p.len() as u64).to_le_bytes());
            // SAFETY: i8 and u8 have identical layout.
            let bytes: &[u8] = unsafe { std::slice::from_raw_parts(p.as_ptr() as *const u8, p.len()) };
            let piece = 16usize << 20;
            let parts: Vec<Digest> = bytes.par_chunks(piece).map(|c| *blake3::hash(c).as_bytes()).collect();
            for d in &parts {
                h.update(d);
            }
        }
        *h.finalize().as_bytes()
    }
}

const MAGIC: &[u8; 8] = b"HLWCACH1";

fn hex(d: &[u8]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

fn entry_path(dir: &Path, key: &WKey, kd: &Digest) -> PathBuf {
    dir.join(format!("{}-l{:02}-{}.wc", key.profile, key.l, &hex(kd)[..16]))
}

static NEXT_TEMP: AtomicU64 = AtomicU64::new(0);

/// A writer owns its temporary file exclusively. Readers see only complete
/// entries: publishing renames this file within the same directory. A stale
/// temporary file (including PID reuse) is never opened or truncated.
struct PendingEntry {
    path: PathBuf,
    file: Option<std::fs::File>,
}

impl PendingEntry {
    fn create(destination: &Path) -> std::io::Result<Self> {
        for _ in 0..128 {
            let id = NEXT_TEMP.fetch_add(1, Ordering::Relaxed);
            let path = destination.with_extension(format!("wc.tmp.{}.{id}", std::process::id()));
            match std::fs::OpenOptions::new().write(true).create_new(true).open(&path) {
                Ok(file) => return Ok(Self { path, file: Some(file) }),
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(error) => return Err(error),
            }
        }
        Err(std::io::Error::new(std::io::ErrorKind::AlreadyExists, "wcache: temporary filename collisions"))
    }

    fn publish(&mut self, destination: &Path) -> std::io::Result<()> {
        // write_all uses an unbuffered File; close it before rename for hosts
        // that disallow renaming open files. This is atomic publication, not
        // a durable-storage promise: a lost cache entry can be recomputed.
        drop(self.file.take());
        std::fs::rename(&self.path, destination)?;
        self.path.clear(); // This pathname can now belong to another writer.
        Ok(())
    }
}

impl Drop for PendingEntry {
    fn drop(&mut self) {
        drop(self.file.take());
        // Only remove an unpublished file owned by this writer.
        if !self.path.as_os_str().is_empty() {
            let _ = std::fs::remove_file(&self.path);
        }
    }
}

/// Serialize the tree (all levels) under its key.
fn save_tree(path: &Path, kd: &Digest, params: &PcsParams, rows: usize, tree: &MerkleTree) -> std::io::Result<u64> {
    let nn = tree.num_leaves();
    let mut out: Vec<u8> = Vec::with_capacity(8 + 32 + 8 + 4 + 4 + 8 + 4 + 32 + 2 * nn * 32);
    out.extend_from_slice(MAGIC);
    out.extend_from_slice(kd);
    out.extend_from_slice(&(rows as u64).to_le_bytes());
    out.extend_from_slice(&params.log_cols.to_le_bytes());
    out.extend_from_slice(&(params.inv_rate as u32).to_le_bytes());
    out.extend_from_slice(&(nn as u64).to_le_bytes());
    out.extend_from_slice(&(tree.levels.len() as u32).to_le_bytes());
    out.extend_from_slice(&tree.root());
    for lvl in &tree.levels {
        for d in lvl {
            out.extend_from_slice(d);
        }
    }
    let mut pending = PendingEntry::create(path)?;
    pending.file.as_mut().unwrap().write_all(&out)?;
    pending.publish(path)?;
    Ok(out.len() as u64)
}

/// Read + VERIFY an entry: key, shape, then every level re-hashed into the
/// next and the last level == the stored root. Err(reason) on any failure.
fn load_tree(path: &Path, kd: &Digest, params: &PcsParams, rows: usize) -> Result<(MerkleTree, u64), String> {
    let bytes = std::fs::read(path).map_err(|e| format!("read: {e}"))?;
    let mut at = 0usize;
    let take = |at: &mut usize, n: usize| -> Result<&[u8], String> {
        if *at + n > bytes.len() { return Err("truncated".into()); }
        let s = &bytes[*at..*at + n];
        *at += n;
        Ok(s)
    };
    if take(&mut at, 8)? != MAGIC { return Err("bad magic".into()); }
    if take(&mut at, 32)? != kd { return Err("key mismatch".into()); }
    let f_rows = u64::from_le_bytes(take(&mut at, 8)?.try_into().unwrap()) as usize;
    let f_log_cols = u32::from_le_bytes(take(&mut at, 4)?.try_into().unwrap());
    let f_inv_rate = u32::from_le_bytes(take(&mut at, 4)?.try_into().unwrap()) as usize;
    let f_nn = u64::from_le_bytes(take(&mut at, 8)?.try_into().unwrap()) as usize;
    let n_levels = u32::from_le_bytes(take(&mut at, 4)?.try_into().unwrap()) as usize;
    let root: Digest = take(&mut at, 32)?.try_into().unwrap();
    if f_rows != rows || f_log_cols != params.log_cols || f_inv_rate != params.inv_rate || f_nn != params.enc_cols() {
        return Err(format!("shape mismatch (file rows {f_rows} log_cols {f_log_cols} inv_rate {f_inv_rate} nn {f_nn})"));
    }
    if !f_nn.is_power_of_two() || n_levels != f_nn.trailing_zeros() as usize + 1 {
        return Err("level count".into());
    }
    let mut levels: Vec<Vec<Digest>> = Vec::with_capacity(n_levels);
    let mut width = f_nn;
    for _ in 0..n_levels {
        let raw = take(&mut at, width * 32)?;
        let lvl: Vec<Digest> = raw.chunks_exact(32).map(|c| c.try_into().unwrap()).collect();
        levels.push(lvl);
        width /= 2;
    }
    if at != bytes.len() { return Err("trailing bytes".into()); }
    // the tree verifies bottom-up; the top must be the stored root
    for k in 0..n_levels - 1 {
        let (lo, hi) = levels.split_at(k + 1);
        let prev = &lo[k];
        let next = &hi[0];
        if next.len() * 2 != prev.len() { return Err(format!("level {k} width")); }
        let bad = prev.par_chunks(2).zip(next.par_iter()).filter(|(pair, up)| hash_pair(&pair[0], &pair[1]) != **up).count();
        if bad > 0 { return Err(format!("level {k}: {bad} nodes do not hash to their parent")); }
    }
    if levels[n_levels - 1].len() != 1 || levels[n_levels - 1][0] != root {
        return Err("root mismatch".into());
    }
    Ok((MerkleTree { levels }, bytes.len() as u64))
}

/// The systematic encoding of `data` with NO hashing: the store the opening
/// reads (rows x nn on the host — the same rows `pcs::commit` builds; the
/// device-resident form when `HL_GPU=1`).
fn reencode_store(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Store {
    let n = params.cols();
    let nn = params.enc_cols();
    let rows = data.len() / n;
    #[cfg(feature = "gpu-cuda")]
    if crate::gpu::enabled() {
        match crate::gpu::dev_encode_only(params, data, ntt) {
            Ok(dc) => return Store::Device(dc),
            Err(e) => eprintln!("[UPERF3-AC] gpu encode (cached W) declined ({e}); CPU path"),
        }
    }
    let mut encoded = vec![Fp::ZERO; rows * nn];
    encoded.par_chunks_mut(nn).zip(data.par_chunks(n)).for_each(|(erow, drow)| {
        let mut coeffs = drow.to_vec();
        ntt.inverse(&mut coeffs);
        ntt.rs_encode(&coeffs, erow);
    });
    Store::Host { encoded }
}

/// THE HOOK: commit `data` (a layer's W matrix) through the cache when one
/// is configured, else `pcs::commit` unchanged.
pub fn commit_w(params: &PcsParams, data: &[Fp], ntt: &NttTables, key: &WKey) -> Committed {
    let Some(dir) = dir() else { return pcs::commit(params, data, ntt) };
    let n = params.cols();
    assert!(data.len() % n == 0 && !data.is_empty());
    let rows = data.len() / n;
    let t0 = Instant::now();
    let kd = key.digest(params, rows, data.len());
    stat(|s| s.secs_key += t0.elapsed().as_secs_f64());
    let path = entry_path(dir, key, &kd);
    let verbose = std::env::var("HL_WCACHE_VERBOSE").map(|v| v == "1").unwrap_or(false);
    if path.exists() {
        let t1 = Instant::now();
        match load_tree(&path, &kd, params, rows) {
            Ok((tree, nbytes)) => {
                stat(|s| { s.hits += 1; s.bytes_read += nbytes; s.secs_load += t1.elapsed().as_secs_f64(); });
                let t2 = Instant::now();
                let store = reencode_store(params, data, ntt);
                stat(|s| s.secs_reencode += t2.elapsed().as_secs_f64());
                if verbose {
                    eprintln!("[UPERF3-AC] wcache HIT {} (rows {rows}, {:.1} MB, load+verify {:.3} s, re-encode {:.3} s)", path.display(), nbytes as f64 / 1e6, (t2 - t1).as_secs_f64(), t2.elapsed().as_secs_f64());
                }
                return Committed { params: *params, rows, store, tree };
            }
            Err(reason) => {
                stat(|s| { s.rejected += 1; s.secs_load += t1.elapsed().as_secs_f64(); });
                eprintln!("[UPERF3-AC] wcache entry {} REJECTED ({reason}); re-committing", path.display());
            }
        }
    }
    let t3 = Instant::now();
    let cm = pcs::commit(params, data, ntt);
    stat(|s| { s.misses += 1; s.secs_commit += t3.elapsed().as_secs_f64(); });
    let t4 = Instant::now();
    match save_tree(&path, &kd, params, rows, &cm.tree) {
        Ok(nbytes) => {
            stat(|s| { s.bytes_written += nbytes; s.secs_save += t4.elapsed().as_secs_f64(); });
            if verbose {
                eprintln!("[UPERF3-AC] wcache MISS -> wrote {} ({:.1} MB, commit {:.3} s, write {:.3} s)", path.display(), nbytes as f64 / 1e6, (t4 - t3).as_secs_f64(), t4.elapsed().as_secs_f64());
            }
        }
        Err(e) => eprintln!("[UPERF3-AC] wcache: cannot write {} ({e}); continuing uncached", path.display()),
    }
    cm
}

/// [FSP-HOST] ITEM (a) THROUGH THE CACHE. `commit_w`'s hook, with the int8
/// planes as the commitment's source instead of the `Vec<Fp>` tiling of
/// them. `None` is a DECLINE: the caller builds that `Vec<Fp>` and calls
/// `commit_w` unchanged.
///
/// The three routes, and why a cache HIT and a cache MISS stay
/// byte-identical:
///
/// * **no cache configured** (every byte gate, and the 8B pass as it was
///   run) — straight to `pcs::commit_planes`;
/// * **configured, entry present (a HIT)** — DECLINED here. The hit route
///   rebuilds the store with `reencode_store`, which needs the `Vec<Fp>`;
///   rather than add a second encode path that no gate exercises, the
///   caller builds the buffer and takes the inherited hit route, so a hit
///   produces exactly the bytes it produces today. (The cost is that the
///   key digest is then computed twice on that route — a blake3 over the
///   three planes — and `secs_key` counts it twice.)
/// * **configured, entry absent (a MISS)** — the plane commitment, then
///   the SAME `save_tree` of the SAME Merkle tree. The key itself needs no
///   change: `WKey` already hashes the three int8 planes and never
///   `w_data`, so an entry written by either arm is the same entry.
pub fn commit_w_planes(params: &PcsParams, pt: &crate::gpu::PlaneTiling, ntt: &NttTables, key: &WKey) -> Option<Committed> {
    let Some(dir) = dir() else { return pcs::commit_planes(params, pt, ntt) };
    let n = params.cols();
    let len = pt.len();
    if len == 0 || len % n != 0 {
        return None;
    }
    let rows = len / n;
    let t0 = Instant::now();
    let kd = key.digest(params, rows, len);
    stat(|s| s.secs_key += t0.elapsed().as_secs_f64());
    let path = entry_path(dir, key, &kd);
    if path.exists() {
        return None; // the HIT route re-encodes from the Vec<Fp>; let the caller build it
    }
    let t3 = Instant::now();
    let cm = pcs::commit_planes(params, pt, ntt)?;
    stat(|s| {
        s.misses += 1;
        s.secs_commit += t3.elapsed().as_secs_f64();
    });
    let t4 = Instant::now();
    match save_tree(&path, &kd, params, rows, &cm.tree) {
        Ok(nbytes) => stat(|s| {
            s.bytes_written += nbytes;
            s.secs_save += t4.elapsed().as_secs_f64();
        }),
        Err(e) => eprintln!("[UPERF3-AC] wcache: cannot write {} ({e}); continuing uncached", path.display()),
    }
    Some(cm)
}

/// One line for the driver's report.
pub fn report() -> Option<String> {
    let d = dir()?;
    let s = stats();
    Some(format!(
        "wcache {}: hits {} | misses {} | rejected {} | read {:.1} MB | wrote {:.1} MB | key {:.3} s | load+verify {:.3} s | re-encode {:.3} s | commit(miss) {:.3} s | save {:.3} s",
        d.display(), s.hits, s.misses, s.rejected, s.bytes_read as f64 / 1e6, s.bytes_written as f64 / 1e6, s.secs_key, s.secs_load, s.secs_reencode, s.secs_commit, s.secs_save
    ))
}

#[cfg(test)]
#[path = "wcache_atomic_tests.rs"]
mod atomic_tests;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field::P;

    fn data(seed: u64, len: usize) -> Vec<Fp> {
        let mut s = seed;
        (0..len).map(|_| { s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407); Fp::new((s >> 1) % 256) }).collect()
    }

    /// The tree round-trips through the file, verifies on load, and every
    /// corruption (a flipped leaf byte, a flipped inner node, a flipped root,
    /// a wrong key, a wrong shape, truncation) is REJECTED.
    #[test]
    fn tree_roundtrip_and_every_corruption_rejected() {
        let p = PcsParams { log_cols: 4, inv_rate: 4, num_col_checks: 8 };
        let ntt = NttTables::new(6);
        let rows = 5usize;
        let d = data(7, rows * p.cols());
        let cm = pcs::commit(&p, &d, &ntt);
        let tmp = std::env::temp_dir().join(format!("hl-wcache-test-{}", std::process::id()));
        std::fs::create_dir_all(&tmp).unwrap();
        let path = tmp.join("t.wc");
        let kd = [7u8; 32];
        save_tree(&path, &kd, &p, rows, &cm.tree).unwrap();
        let (t2, _) = load_tree(&path, &kd, &p, rows).unwrap();
        assert_eq!(t2.root(), cm.tree.root());
        assert_eq!(t2.levels.len(), cm.tree.levels.len());
        for (a, b) in t2.levels.iter().zip(cm.tree.levels.iter()) { assert_eq!(a, b); }
        let good = std::fs::read(&path).unwrap();
        let hdr = 8 + 32 + 8 + 4 + 4 + 8 + 4;
        // flip: a root byte, a leaf byte, an inner-node byte, the last byte
        for off in [hdr, hdr + 32 + 5, hdr + 32 + p.enc_cols() * 32 + 3, good.len() - 1] {
            let mut bad = good.clone();
            bad[off] ^= 1;
            std::fs::write(&path, &bad).unwrap();
            assert!(load_tree(&path, &kd, &p, rows).is_err(), "corruption at {off} accepted");
        }
        std::fs::write(&path, &good[..good.len() - 7]).unwrap();
        assert!(load_tree(&path, &kd, &p, rows).is_err());
        std::fs::write(&path, &good).unwrap();
        assert!(load_tree(&path, &[8u8; 32], &p, rows).is_err());
        assert!(load_tree(&path, &kd, &p, rows + 1).is_err());
        let p2 = PcsParams { log_cols: 4, inv_rate: 2, num_col_checks: 8 };
        assert!(load_tree(&path, &kd, &p2, rows).is_err());
        assert!(load_tree(&path, &kd, &p, rows).is_ok());
        let _ = std::fs::remove_dir_all(&tmp);
        let _ = P;
    }
}

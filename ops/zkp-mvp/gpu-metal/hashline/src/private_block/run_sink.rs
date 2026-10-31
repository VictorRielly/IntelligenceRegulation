//! **STAGE 13: WHERE a private run's segments go.**
//!
//! Not WHAT is in one. The wire format of a segment is `wire.rs` and no byte
//! of it moves here: a sink is about the destination of the bytes the run
//! prover has already finished.
//!
//! `prove_run` hands each finished segment over EXACTLY ONCE, as an owned
//! `Vec<u8>`, and afterwards keeps nothing of it but its length (ruling M-3:
//! segments are flushed, not held — eleven unflushed 125M segments are 423
//! MiB). This module is the two places the bytes can go:
//!
//! * [`MemorySink`] — keeps them, which is what the development-rung tests do
//!   (a twelve-block rung run is 49 MB in all);
//! * [`DirSink`] — writes each one to its own file in a directory, ATOMICALLY
//!   (a temporary name, flushed to the device, then renamed), and keeps only
//!   its length and its SHA-256. That is what a twelve-block 125M run needs:
//!   484 MB of receipt against a 12 GiB memory ceiling, and evidence that can
//!   be committed as hashes and lengths instead of half a gigabyte of bytes.
//!
//! The verifier's side of the same rule is [`segment_paths`], which names the
//! `L` files a run directory must hold — `L` being the VERIFIER'S OWN — and
//! refuses anything else in it before a byte is read. `run::verify_run_from_dir`
//! then reads them ONE AT A TIME, so that no more than one segment's bytes are
//! ever resident.
//!
//! SHA-256 is the crate's existing `export_v3::sha256_hex` (the `sha2`
//! dependency the library already carries); no dependency is added.

use crate::export_v3::sha256_hex;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

/// A place a finished segment goes. The prover calls [`SegmentSink::accept`]
/// once per segment, in order, and holds nothing of it afterwards.
pub(crate) trait SegmentSink {
    /// Take segment `k`'s bytes. The sink OWNS them: whatever it does with
    /// them, they are gone from the prover.
    fn accept(&mut self, k: usize, bytes: Vec<u8>) -> Result<(), String>;
}

/// `segment-000.bin`, `segment-001.bin`, … — the one name a run's segment
/// has, written by the sink and expected by the verifier.
pub(crate) fn segment_file_name(k: usize) -> String {
    format!("segment-{k:03}.bin")
}

/// the SHA-256 of some bytes, as lower-case hex
pub(crate) fn digest_hex(bytes: &[u8]) -> String {
    sha256_hex(bytes)
}

/// what is in a run directory: entry names only, sorted
pub(crate) fn dir_entry_names(dir: &Path) -> Result<Vec<String>, String> {
    let read = fs::read_dir(dir).map_err(|e| format!("private run: the run directory {} cannot be read: {e}", dir.display()))?;
    let mut names: Vec<String> = Vec::new();
    for e in read {
        let e = e.map_err(|e| format!("private run: the run directory {} cannot be read: {e}", dir.display()))?;
        names.push(e.file_name().to_string_lossy().into_owned());
    }
    names.sort();
    Ok(names)
}

/// **STAGE 18.** The ONE entry a run directory may hold beside its `L`
/// segment files: the directory in which the run's PUBLIC STATEMENT is
/// retained after the run has verified
/// (`run_statement_file.rs`, `<dir>/statement/run-statement.json`). The
/// segments keep their names and their bytes; nothing is written into this
/// directory unless the whole run verified in process (ruling D21).
pub(crate) const STATEMENT_DIR: &str = "statement";

/// **THE `L` SEGMENT FILES OF A RUN DIRECTORY, IN ORDER.** Exactly `L` files
/// must be there and nothing else may be except the one
/// [`STATEMENT_DIR`] directory: a missing segment is named, and any other
/// entry — an extra segment beyond `L`, a leftover `.partial`, a foreign file,
/// or a plain FILE called `statement` — is refused before a byte of any
/// segment is read. `l` is the VERIFIER'S OWN, from its statement, never from
/// the directory.
///
/// **Why the one exception.** The public run statement has to be retained
/// BESIDE the segments so that a fresh process can rebuild the verifier's
/// statement from the files on disk; putting it inside the directory the
/// verifier scans is the only place that is unambiguously "this run's". It is
/// a single allowed NAME which must be a DIRECTORY, it is never read by
/// `verify_run_from_dir`, and it widens nothing else: every other foreign
/// entry is refused exactly as before
/// (`a_missing_truncated_swapped_duplicated_or_foreign_segment_file_is_rejected`
/// still fires on `notes.txt`).
pub(crate) fn segment_paths(dir: &Path, l: usize) -> Result<Vec<PathBuf>, String> {
    let names = dir_entry_names(dir)?;
    let want: Vec<String> = (0..l).map(segment_file_name).collect();
    for n in &names {
        if n == STATEMENT_DIR {
            if dir.join(n).is_dir() {
                continue;
            }
            return Err(format!("private run: the run directory {} holds a FILE called {n}; the only entry allowed beside this run's {l} segments is the {STATEMENT_DIR} DIRECTORY", dir.display()));
        }
        if !want.contains(n) {
            return Err(format!("private run: the run directory {} holds {n}, which is not one of this run's {l} segments", dir.display()));
        }
    }
    for n in &want {
        if !names.contains(n) {
            return Err(format!("private run: the run directory {} is missing {n}", dir.display()));
        }
    }
    Ok(want.iter().map(|n| dir.join(n)).collect())
}

/// The sink the development-rung tests use: it KEEPS the bytes. Behaviour
/// unchanged from the closure those tests used before — segments in order,
/// nothing else.
#[derive(Default)]
pub(crate) struct MemorySink {
    segments: Vec<Vec<u8>>,
}

impl MemorySink {
    pub(crate) fn segments(&self) -> &[Vec<u8>] {
        &self.segments
    }
}

impl SegmentSink for MemorySink {
    fn accept(&mut self, k: usize, bytes: Vec<u8>) -> Result<(), String> {
        if k != self.segments.len() {
            return Err(format!("private run: the sink was handed segment {k} after {} segments", self.segments.len()));
        }
        self.segments.push(bytes);
        Ok(())
    }
}

/// **THE DIRECTORY SINK.** One file per segment, written as it is finished
/// and then forgotten: what stays is the length and the SHA-256, which is the
/// evidence a run leaves in the repository.
pub(crate) struct DirSink {
    dir: PathBuf,
    l: usize,
    lengths: Vec<usize>,
    digests: Vec<String>,
}

impl DirSink {
    /// The directory must EXIST and be EMPTY. A run never writes into a
    /// directory that already holds something, so that no half-run's segments
    /// can be mistaken for this run's — and the caller, not this code, decides
    /// where hundreds of megabytes land.
    pub(crate) fn create(dir: &Path, l: usize) -> Result<DirSink, String> {
        if !dir.is_dir() {
            return Err(format!("private run: the run directory {} does not exist; create it before the run", dir.display()));
        }
        let names = dir_entry_names(dir)?;
        if !names.is_empty() {
            return Err(format!("private run: the run directory {} is not empty (it holds {} entries, the first being {})", dir.display(), names.len(), names[0]));
        }
        Ok(DirSink { dir: dir.to_path_buf(), l, lengths: Vec::with_capacity(l), digests: Vec::with_capacity(l) })
    }

    /// the length of each segment written so far
    pub(crate) fn lengths(&self) -> &[usize] {
        &self.lengths
    }
    /// the SHA-256 of each segment written so far, as lower-case hex
    pub(crate) fn digests(&self) -> &[String] {
        &self.digests
    }
    pub(crate) fn total_bytes(&self) -> usize {
        self.lengths.iter().sum()
    }
}

impl SegmentSink for DirSink {
    /// **ATOMIC.** The bytes go to a temporary name, are flushed to the
    /// device, and only then are RENAMED into place, so that a file under a
    /// segment's own name either is the whole segment or does not exist —
    /// a run killed by the memory ceiling leaves no half-segment that a later
    /// verifier could take for a whole one.
    fn accept(&mut self, k: usize, bytes: Vec<u8>) -> Result<(), String> {
        if k != self.lengths.len() {
            return Err(format!("private run: the sink was handed segment {k} after {} segments", self.lengths.len()));
        }
        if k >= self.l {
            return Err(format!("private run: the sink was handed segment {k} and this run has {}", self.l));
        }
        let name = segment_file_name(k);
        let final_path = self.dir.join(&name);
        let tmp_path = self.dir.join(format!("{name}.partial"));
        if final_path.exists() {
            return Err(format!("private run: {} already exists", final_path.display()));
        }
        {
            let mut f = fs::File::create(&tmp_path).map_err(|e| format!("private run: {} cannot be created: {e}", tmp_path.display()))?;
            f.write_all(&bytes).map_err(|e| format!("private run: {} cannot be written: {e}", tmp_path.display()))?;
            f.sync_all().map_err(|e| format!("private run: {} cannot be flushed: {e}", tmp_path.display()))?;
        }
        fs::rename(&tmp_path, &final_path).map_err(|e| format!("private run: {} cannot be renamed to {}: {e}", tmp_path.display(), final_path.display()))?;
        self.lengths.push(bytes.len());
        self.digests.push(digest_hex(&bytes));
        Ok(())
    }
}

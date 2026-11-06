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

/// the SHA-256 of some bytes, as lower-case hex. [A21] With `HL_A21_SHA` on (the
/// default) through [`a21_sha::sha256`], the same digest; `0`, `sha256_hex` as before.
pub(crate) fn digest_hex(bytes: &[u8]) -> String {
    if a21_sha::on() {
        let _scope = crate::phase_profile::span("hash.sha256");
        return crate::silu::hex(&a21_sha::sha256(bytes));
    }
    sha256_hex(bytes)
}

// ---------------------------------------- [A21] SHA-256 on the Arm SHA-2 instructions
//
// (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A21;
// `results/zk60_effplan_20261105/a21/README.md`.) `sha2 0.10.9` hashes in software on
// aarch64, about 0.5 GB/s on the M3 Ultra: its Arm SHA-2 backend is compiled only with its
// `asm` feature (crate `sha2-asm`, not in the offline registry; on x86_64 that feature would
// REPLACE the SHA-NI intrinsics with plain assembly, so it is not enabled). A20 found
// production's per-request host work SHA-256-bound: the layer record's word hashes, the
// export loader's array hashes, the receipt frames' hashes and the verifier's.
//
// This module is FIPS 180-4 SHA-256 with its compression function on the stable
// `core::arch::aarch64` SHA-2 intrinsics (`vsha256hq_u32`, `vsha256h2q_u32`,
// `vsha256su0q_u32`, `vsha256su1q_u32`), taken only after
// `is_aarch64_feature_detected!("sha2")`; on every other target, on a CPU without the
// extension and with `HL_A21_SHA=0`, `sha2::Sha256::digest` exactly as before. No crate and
// no `Cargo.toml` / `Cargo.lock` change. Production's SHA-256 call sites on the request path
// go through [`a21_sha::sha256`]: `trained_statement::sha` (the layer record),
// `trained_block::sha256` (the export loader's arrays and files) and [`digest_hex`] (the
// receipt frames, written and verified).
//
// **Why no byte can move**: SHA-256 is a function and this computes the same one (the
// differential tests: the NIST vectors, every length 0..=1100, random lengths to 16 MB,
// unaligned sub-slices and the 8B words, against `sha2`). **Its time depends on the input's
// length only**: the four instructions are data-independent, and the code branches on the
// length alone (the full blocks, then the one or two padded blocks), so a prover-private
// file hashed through it (`load_seq_dir`'s manifest form) shows nothing new.

/// **[A21] the one SHA-256 of production's request path** (see the section above)
pub(crate) mod a21_sha {
    use sha2::Digest as _;
    use std::sync::atomic::AtomicUsize;

    static A21_SHA_TEST: AtomicUsize = AtomicUsize::new(usize::MAX);

    /// [A21] the measured default (`results/zk60_effplan_20261105/a21/README.md`)
    const A21_SHA_DEFAULT: usize = 1;

    /// [A21] `HL_A21_SHA` (default on; `0`: `sha2` in software, the path before A21)
    pub(crate) fn on() -> bool {
        static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
        super::super::trained_statement::a20_switch(&A21_SHA_TEST, &ENV, "HL_A21_SHA", A21_SHA_DEFAULT) != 0
    }

    /// tests: the instructions on (`Some(true)`), off (`Some(false)`) or as the
    /// environment says (`None`). Changes no byte (see above).
    #[cfg(test)]
    pub(crate) fn set_for_test(on: Option<bool>) {
        A21_SHA_TEST.store(on.map(usize::from).unwrap_or(usize::MAX), std::sync::atomic::Ordering::Relaxed);
    }

    /// whether this process's SHA-256s run on the instructions (the switch on and the
    /// CPU has them)
    #[cfg_attr(not(test), allow(dead_code))]
    pub(crate) fn hardware() -> bool {
        on() && detected()
    }

    /// whether the CPU has the Arm SHA-2 instructions
    #[cfg(target_arch = "aarch64")]
    fn detected() -> bool {
        std::arch::is_aarch64_feature_detected!("sha2")
    }

    #[cfg(not(target_arch = "aarch64"))]
    fn detected() -> bool {
        false
    }

    /// **[A21] SHA-256**: on the Arm SHA-2 instructions when the switch is on and the CPU
    /// has them, `sha2` otherwise. The same 32 bytes either way.
    pub(crate) fn sha256(bytes: &[u8]) -> [u8; 32] {
        if on() {
            if let Some(d) = instructions(bytes) {
                return d;
            }
        }
        sha2::Sha256::digest(bytes).into()
    }

    /// the instruction path alone, whatever the switch says (`None`: this CPU or target
    /// has no Arm SHA-2 instructions)
    #[cfg(target_arch = "aarch64")]
    pub(crate) fn instructions(bytes: &[u8]) -> Option<[u8; 32]> {
        if !detected() {
            return None;
        }
        // SAFETY: `arm::digest` is `#[target_feature(enable = "sha2")]` and its one
        // precondition is that the CPU has the SHA-2 extension, detected on the line above
        Some(unsafe { arm::digest(bytes) })
    }

    #[cfg(not(target_arch = "aarch64"))]
    pub(crate) fn instructions(_bytes: &[u8]) -> Option<[u8; 32]> {
        None
    }

    #[cfg(target_arch = "aarch64")]
    mod arm {
        use core::arch::aarch64::{uint32x4_t, vaddq_u32, vld1q_u32, vld1q_u8, vreinterpretq_u32_u8, vrev32q_u8, vsha256h2q_u32, vsha256hq_u32, vsha256su0q_u32, vsha256su1q_u32, vst1q_u32};

        /// FIPS 180-4 §4.2.2: the 64 round constants
        static K: [u32; 64] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
        ];

        /// FIPS 180-4 §5.3.3: the initial hash value
        const H0: [u32; 8] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];

        /// the 16 bytes at `b[at..at + 16]` as four big-endian words
        #[target_feature(enable = "sha2")]
        fn words(b: &[u8; 64], at: usize) -> uint32x4_t {
            let b16: &[u8; 16] = b[at..at + 16].try_into().expect("16 bytes");
            // SAFETY: `b16` is 16 readable bytes, exactly what `vld1q_u8` reads (it has no
            // alignment requirement)
            vreinterpretq_u32_u8(vrev32q_u8(unsafe { vld1q_u8(b16.as_ptr()) }))
        }

        /// the 4 round constants of rounds `4 g .. 4 g + 3`
        #[target_feature(enable = "sha2")]
        fn constants(g: usize) -> uint32x4_t {
            let k: &[u32; 4] = K[4 * g..4 * g + 4].try_into().expect("4 constants");
            // SAFETY: `k` is 4 readable `u32`s, exactly what `vld1q_u32` reads
            unsafe { vld1q_u32(k.as_ptr()) }
        }

        /// FIPS 180-4 §6.2.2 over each 64-byte block of `blocks`, in order: the message
        /// schedule by SHA256SU0 / SHA256SU1, four rounds per SHA256H / SHA256H2 pair
        #[target_feature(enable = "sha2")]
        fn compress(state: &mut [u32; 8], blocks: &[u8]) {
            assert_eq!(blocks.len() % 64, 0, "whole blocks only");
            let (lo, hi): (&[u32; 4], &[u32; 4]) = (state[..4].try_into().expect("4 words"), state[4..].try_into().expect("4 words"));
            // SAFETY: `lo` and `hi` are 4 readable `u32`s each, exactly what `vld1q_u32` reads
            let (mut abcd, mut efgh) = unsafe { (vld1q_u32(lo.as_ptr()), vld1q_u32(hi.as_ptr())) };
            for b in blocks.chunks_exact(64) {
                let b: &[u8; 64] = b.try_into().expect("64 bytes");
                let (abcd0, efgh0) = (abcd, efgh);
                let mut w = [words(b, 0), words(b, 16), words(b, 32), words(b, 48)];
                for g in 0..16 {
                    let wk = vaddq_u32(w[g % 4], constants(g));
                    let abcd_in = abcd;
                    abcd = vsha256hq_u32(abcd, efgh, wk);
                    efgh = vsha256h2q_u32(efgh, abcd_in, wk);
                    if g < 12 {
                        // W[4g+16 .. 4g+19] from W[4g .. 4g+15]
                        w[g % 4] = vsha256su1q_u32(vsha256su0q_u32(w[g % 4], w[(g + 1) % 4]), w[(g + 2) % 4], w[(g + 3) % 4]);
                    }
                }
                abcd = vaddq_u32(abcd, abcd0);
                efgh = vaddq_u32(efgh, efgh0);
            }
            let (lo, hi) = state.split_at_mut(4);
            // SAFETY: `lo` and `hi` are 4 writable `u32`s each, exactly what `vst1q_u32` writes
            unsafe {
                vst1q_u32(lo.as_mut_ptr(), abcd);
                vst1q_u32(hi.as_mut_ptr(), efgh);
            }
        }

        /// FIPS 180-4 SHA-256 of `bytes`: the whole blocks in place, then the last
        /// partial block with its padding (§5.1.1) in one or two blocks
        #[target_feature(enable = "sha2")]
        pub(super) fn digest(bytes: &[u8]) -> [u8; 32] {
            let mut st = H0;
            let whole = bytes.len() - bytes.len() % 64;
            compress(&mut st, &bytes[..whole]);
            let rest = &bytes[whole..];
            let mut last = [0u8; 128];
            last[..rest.len()].copy_from_slice(rest);
            last[rest.len()] = 0x80;
            let n = if rest.len() < 56 { 64 } else { 128 };
            last[n - 8..n].copy_from_slice(&(bytes.len() as u64).wrapping_mul(8).to_be_bytes());
            compress(&mut st, &last[..n]);
            let mut out = [0u8; 32];
            for (o, w) in out.chunks_exact_mut(4).zip(st) {
                o.copy_from_slice(&w.to_be_bytes());
            }
            out
        }
    }
}

// ---------------------------------------- [A21] end

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

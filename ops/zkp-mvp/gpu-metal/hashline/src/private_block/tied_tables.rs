//! R12b: bounded public-table reads and checkpoint-derived tied tables.
//!
//! Token tables are calibration outputs, not independent model weights.
//! Their manifests alone cannot establish that they came from the tied tensor.

use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;
use sha2::{Digest, Sha256};

mod derive;
pub use derive::{recompute_tied_tables, tied_token_calibration, RecomputedTiedTables, TiedFinalNorm, TiedTokenCalibration};
pub(crate) use derive::recompute_declared_tied_tables;
/// TOKEN ROUND 16 (N-r13-5): the loader's pass with the classifier row
pub(crate) use derive::recompute_declared_tied_tables_with_margin;
/// Token R-C2 uses the same quantizer for its development tied source.
pub(crate) use derive::{bf16, norm, quantize};

/// Open without following a final symlink or blocking on a raced-in FIFO.
/// Recheck the opened descriptor, including its identity on Unix.
fn regular(path: &Path, bound: u64, exact: bool) -> Result<File, String> {
    let fail = |s: String| format!("{}: {s}", path.display());
    let before = std::fs::symlink_metadata(path).map_err(|e| fail(e.to_string()))?;
    if !before.is_file() { return Err(fail("not a regular file".into())); }
    if before.len() > bound || (exact && before.len() != bound) {
        return Err(fail(format!("{} bytes; expected {} {bound}", before.len(), if exact { "exactly" } else { "at most" })));
    }
    let mut options = OpenOptions::new();
    options.read(true);
    #[cfg(all(target_os = "linux", target_arch = "x86_64"))]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(0x20000 | 0x800); // O_NOFOLLOW | O_NONBLOCK
    }
    let file = options.open(path).map_err(|e| fail(e.to_string()))?;
    let after = file.metadata().map_err(|e| fail(e.to_string()))?;
    if !after.is_file() || after.len() != before.len() {
        return Err(fail("file changed while opening".into()));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        if before.dev() != after.dev() || before.ino() != after.ino() {
            return Err(fail("file identity changed while opening".into()));
        }
    }
    Ok(file)
}

fn range_hash(file: &mut File, offset: u64, length: u64) -> Result<[u8; 32], String> {
    file.seek(SeekFrom::Start(offset)).map_err(|e| e.to_string())?;
    let mut remaining = length;
    let mut hash = Sha256::new();
    let mut buffer = vec![0u8; 1 << 20];
    while remaining > 0 {
        let n = remaining.min(buffer.len() as u64) as usize;
        file.read_exact(&mut buffer[..n]).map_err(|e| format!("short bounded read: {e}"))?;
        hash.update(&buffer[..n]);
        remaining -= n as u64;
    }
    Ok(hash.finalize().into())
}

/// Hash exactly `length` bytes with bounded memory; reject links, special
/// files, truncation and growth. No read continues until an unbounded EOF.
pub(crate) fn hash_regular_exact(path: &Path, length: u64) -> Result<[u8; 32], String> {
    let mut file = regular(path, length, true)?;
    let digest = range_hash(&mut file, 0, length).map_err(|e| format!("{}: {e}", path.display()))?;
    let mut extra = [0];
    if file.read(&mut extra).map_err(|e| e.to_string())? != 0 || file.metadata().map_err(|e| e.to_string())?.len() != length {
        return Err(format!("{}: changed during bounded hashing", path.display()));
    }
    Ok(digest)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn evidence(name: &str) -> std::path::PathBuf {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../results/r12b-tests");
        std::fs::create_dir_all(&root).unwrap();
        root.join(format!("{}-{name}", std::process::id()))
    }

    #[test]
    fn bounded_hash_rejects_wrong_sizes_and_special_files() {
        let path = evidence("bounded.bin");
        std::fs::write(&path, b"abc").unwrap();
        assert_eq!(hash_regular_exact(&path, 3).unwrap(), <[u8;32]>::from(Sha256::digest(b"abc")));
        assert!(hash_regular_exact(&path, 2).unwrap_err().contains("expected exactly"));
        assert!(hash_regular_exact(&path, 4).unwrap_err().contains("expected exactly"));
        #[cfg(unix)]
        {
            let link = evidence("bounded.link");
            if !link.symlink_metadata().is_ok() { std::os::unix::fs::symlink(&path, &link).unwrap(); }
            assert!(hash_regular_exact(&link, 3).unwrap_err().contains("not a regular file"));
            assert!(hash_regular_exact(Path::new("/dev/zero"), 0).unwrap_err().contains("not a regular file"));
            let fifo = evidence("bounded.fifo");
            if !fifo.exists() { assert!(std::process::Command::new("mkfifo").arg(&fifo).status().unwrap().success()); }
            assert!(hash_regular_exact(&fifo, 0).unwrap_err().contains("not a regular file"));
        }
    }
}

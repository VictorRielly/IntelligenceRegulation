//! Pinned provenance check for the native RISC Zero Groth16 tools.
//!
//! The wrappers call [`validate_tool_directory`] before running any tool in
//! the directory. Each pinned file must be a regular file (not a symlink) at
//! exactly its pinned length and SHA-256; the files that get executed must have
//! an execute bit set. Contents are hashed in fixed-size chunks, so the 2.2 GB
//! proving key is never held in memory.
//!
//! This checks that the bytes match the official release at the moment of
//! validation. It does not verify the trusted setup ceremony, and it cannot
//! stop a process running as the same user from changing a file between
//! validation and execution.

use sha2::{Digest, Sha256};
use std::fmt;
use std::fs::{self, File};
use std::io::{self, Read};
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};

/// Source of [`PINS`]: the official prover image and its manifest digest.
pub const PINNED_SOURCE: &str = "risczero/risc0-groth16-prover:v2025-04-03.1 \
     manifest sha256:7f173963196570b7a71816ed70565a4579264c5d2e3e0ecb028102538ad0e331";

/// Expected public metadata for one tool file.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ToolPin {
    pub name: &'static str,
    pub len: u64,
    /// Lowercase hex SHA-256.
    pub sha256: &'static str,
    /// The wrappers execute this file directly.
    pub executable: bool,
}

/// The five files from [`PINNED_SOURCE`] that the wrappers use.
pub const PINS: [ToolPin; 5] = [
    ToolPin {
        name: "prover",
        len: 14_627_939,
        sha256: "a30a45c2f38b116fd123fee219ec3e40925670b64585f196e291a22d3cef281e",
        executable: true,
    },
    ToolPin {
        name: "stark_verify.cs",
        len: 260_664_474,
        sha256: "0670f7c8ce8fe757d0cf4808c5d5cd92c85ac7a96ea98170c2f6f756d49e80b5",
        executable: false,
    },
    ToolPin {
        name: "stark_verify_final.pk.dmp",
        len: 2_255_766_633,
        sha256: "6d76b07e187e3329b1d82498a5f826366c3b2e04fc6d99de3d790248eb1ea71f",
        executable: false,
    },
    ToolPin {
        name: "stark_verify",
        len: 148_060_624,
        sha256: "e407f61d2c6b9ee338e8194e10bef6ed815bd7497f9fac4687aa4944faa169c9",
        executable: true,
    },
    ToolPin {
        name: "stark_verify.dat",
        len: 46_203_464,
        sha256: "f120ed88d4d090f7b4b78aef7dcc94bd98ecff6e592ea9f7a629c4279231b8b4",
        executable: false,
    },
];

/// A file that matched its pin.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ValidatedTool {
    pub name: &'static str,
    pub path: PathBuf,
    pub len: u64,
    pub sha256: String,
}

/// A canonical tool directory whose pinned files all matched.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ValidatedTools {
    pub dir: PathBuf,
    pub files: Vec<ValidatedTool>,
}

impl ValidatedTools {
    /// Path of a validated file, e.g. `tools.path("prover")`.
    pub fn path(&self, name: &str) -> Option<&Path> {
        self.files.iter().find(|f| f.name == name).map(|f| f.path.as_path())
    }
}

#[derive(Debug)]
pub enum ToolError {
    Io(PathBuf, io::Error),
    NotDirectory(PathBuf),
    Symlink(PathBuf),
    NotRegular(PathBuf),
    NotExecutable(PathBuf),
    /// File changed identity between the metadata check and open.
    Replaced(PathBuf),
    Length { path: PathBuf, expected: u64, actual: u64 },
    Digest { path: PathBuf, expected: &'static str, actual: String },
}

impl fmt::Display for ToolError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(p, e) => write!(f, "native tool {}: {e}", p.display()),
            Self::NotDirectory(p) => write!(f, "native tool path {} is not a directory", p.display()),
            Self::Symlink(p) => write!(f, "native tool {} is a symlink", p.display()),
            Self::NotRegular(p) => write!(f, "native tool {} is not a regular file", p.display()),
            Self::NotExecutable(p) => write!(f, "native tool {} is not executable", p.display()),
            Self::Replaced(p) => write!(f, "native tool {} changed during validation", p.display()),
            Self::Length { path, expected, actual } => write!(
                f,
                "native tool {} has {actual} bytes, pinned {expected}",
                path.display()
            ),
            Self::Digest { path, expected, actual } => write!(
                f,
                "native tool {} has sha256 {actual}, pinned {expected}",
                path.display()
            ),
        }
    }
}

impl std::error::Error for ToolError {}

/// Canonicalizes `dir` and checks every file in [`PINS`].
pub fn validate_tool_directory(dir: &Path) -> Result<ValidatedTools, ToolError> {
    validate_with_pins(dir, &PINS)
}

/// Same check against caller-supplied pins; the wrappers should use
/// [`validate_tool_directory`]. Exposed so tests can use tiny files.
pub fn validate_with_pins(dir: &Path, pins: &[ToolPin]) -> Result<ValidatedTools, ToolError> {
    let dir = dir
        .canonicalize()
        .map_err(|e| ToolError::Io(dir.to_path_buf(), e))?;
    let meta = fs::metadata(&dir).map_err(|e| ToolError::Io(dir.clone(), e))?;
    if !meta.is_dir() {
        return Err(ToolError::NotDirectory(dir));
    }
    let files = pins
        .iter()
        .map(|pin| validate_file(&dir.join(pin.name), pin))
        .collect::<Result<_, _>>()?;
    Ok(ValidatedTools { dir, files })
}

fn validate_file(path: &Path, pin: &ToolPin) -> Result<ValidatedTool, ToolError> {
    let io_err = |e| ToolError::Io(path.to_path_buf(), e);
    // lstat: the final component itself must be a regular file.
    let meta = fs::symlink_metadata(path).map_err(io_err)?;
    if meta.file_type().is_symlink() {
        return Err(ToolError::Symlink(path.into()));
    }
    if !meta.is_file() {
        return Err(ToolError::NotRegular(path.into()));
    }
    if pin.executable && meta.permissions().mode() & 0o111 == 0 {
        return Err(ToolError::NotExecutable(path.into()));
    }
    // Reject a wrong length before reading anything.
    if meta.len() != pin.len {
        return Err(ToolError::Length { path: path.into(), expected: pin.len, actual: meta.len() });
    }
    let file = File::open(path).map_err(io_err)?;
    let opened = file.metadata().map_err(io_err)?;
    if (opened.dev(), opened.ino()) != (meta.dev(), meta.ino()) {
        return Err(ToolError::Replaced(path.into()));
    }
    // Read at most one byte past the pin so growth is detected without
    // unbounded reads.
    let mut reader = file.take(pin.len.saturating_add(1));
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 1 << 16];
    let mut total = 0u64;
    loop {
        let n = match reader.read(&mut buf) {
            Ok(0) => break,
            Ok(n) => n,
            Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(e) => return Err(io_err(e)),
        };
        hasher.update(&buf[..n]);
        total += n as u64;
    }
    if total != pin.len {
        return Err(ToolError::Length { path: path.into(), expected: pin.len, actual: total });
    }
    let actual = hex(&hasher.finalize());
    if actual != pin.sha256 {
        return Err(ToolError::Digest { path: path.into(), expected: pin.sha256, actual });
    }
    Ok(ValidatedTool { name: pin.name, path: path.into(), len: total, sha256: actual })
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

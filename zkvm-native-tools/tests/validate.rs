//! Tiny-file tests of the same helper that checks the real pins. Nothing here
//! reads or hashes the native tools.

use std::fs;
use std::os::unix::fs::{symlink, PermissionsExt};
use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};
use zk60_native_tools::{validate_with_pins, ToolError, ToolPin, PINS};

const ABC: &str = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
const PIN: ToolPin = ToolPin { name: "tool", len: 3, sha256: ABC, executable: true };

struct Scratch(PathBuf);

impl Scratch {
    fn new() -> Self {
        static N: AtomicUsize = AtomicUsize::new(0);
        let dir = std::env::temp_dir().join(format!(
            "zk60-native-tools-test-{}-{}",
            std::process::id(),
            N.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&dir).unwrap();
        Scratch(dir)
    }

    fn file(&self, name: &str, contents: &[u8], mode: u32) -> PathBuf {
        let path = self.0.join(name);
        fs::write(&path, contents).unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(mode)).unwrap();
        path
    }
}

impl Drop for Scratch {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn check(contents: &[u8]) -> Result<zk60_native_tools::ValidatedTools, ToolError> {
    let s = Scratch::new();
    s.file("tool", contents, 0o700);
    validate_with_pins(&s.0, &[PIN])
}

#[test]
fn matching_file_passes_with_canonical_paths() {
    let s = Scratch::new();
    s.file("tool", b"abc", 0o700);
    let dotted = s.0.join(".");
    let tools = validate_with_pins(&dotted, &[PIN]).unwrap();
    assert_eq!(tools.dir, s.0.canonicalize().unwrap());
    assert_eq!(tools.path("tool"), Some(tools.dir.join("tool").as_path()));
    assert_eq!(tools.files[0].len, 3);
    assert_eq!(tools.files[0].sha256, ABC);
}

#[test]
fn wrong_same_size_contents_fail_digest() {
    assert!(matches!(check(b"abd"), Err(ToolError::Digest { .. })));
}

#[test]
fn truncated_and_oversized_fail_length() {
    assert!(matches!(check(b"ab"), Err(ToolError::Length { actual: 2, .. })));
    assert!(matches!(check(b"abcd"), Err(ToolError::Length { actual: 4, .. })));
}

#[test]
fn symlink_is_refused_even_to_matching_file() {
    let s = Scratch::new();
    let real = s.file("real", b"abc", 0o700);
    symlink(&real, s.0.join("tool")).unwrap();
    assert!(matches!(validate_with_pins(&s.0, &[PIN]), Err(ToolError::Symlink(_))));
}

#[test]
fn nonregular_and_missing_are_refused() {
    let s = Scratch::new();
    fs::create_dir(s.0.join("tool")).unwrap();
    assert!(matches!(validate_with_pins(&s.0, &[PIN]), Err(ToolError::NotRegular(_))));
    let empty = Scratch::new();
    assert!(matches!(validate_with_pins(&empty.0, &[PIN]), Err(ToolError::Io(..))));
}

#[test]
fn executable_bit_required_only_for_executed_tools() {
    let s = Scratch::new();
    s.file("tool", b"abc", 0o600);
    assert!(matches!(validate_with_pins(&s.0, &[PIN]), Err(ToolError::NotExecutable(_))));
    let data = ToolPin { executable: false, ..PIN };
    assert!(validate_with_pins(&s.0, &[data]).is_ok());
}

#[test]
fn file_path_is_not_a_directory() {
    let s = Scratch::new();
    let file = s.file("tool", b"abc", 0o700);
    assert!(matches!(validate_with_pins(&file, &[PIN]), Err(ToolError::NotDirectory(_))));
}

#[test]
fn shipped_pins_are_well_formed() {
    let names: Vec<_> = PINS.iter().map(|p| p.name).collect();
    assert_eq!(
        names,
        ["prover", "stark_verify.cs", "stark_verify_final.pk.dmp", "stark_verify", "stark_verify.dat"]
    );
    for pin in PINS {
        assert_eq!(pin.sha256.len(), 64);
        assert!(pin.sha256.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f')));
    }
    let exec: Vec<_> = PINS.iter().filter(|p| p.executable).map(|p| p.name).collect();
    assert_eq!(exec, ["prover", "stark_verify"]);
}

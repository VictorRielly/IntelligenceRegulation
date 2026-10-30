//! Test-only source enumeration shared by the source-pin and hash/RNG audits.
//! Keep attributes attached to declarations: `#[path]` may follow `#[cfg(test)]`.
use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

fn children(text: &str, parent: &Path) -> Vec<PathBuf> {
    let (mut test, mut override_path) = (false, None);
    let mut out = Vec::new();
    for line in text.lines() {
        let t = line.trim();
        if t.is_empty() || t.starts_with("//") { continue; }
        if t == "#[cfg(test)]" { test = true; continue; }
        if t.starts_with("#[path") {
            let first = t.find('"').expect("path attribute opening quote");
            let rest = &t[first + 1..];
            let end = rest.find('"').expect("path attribute closing quote");
            override_path = Some(rest[..end].to_string());
            continue;
        }
        if t.starts_with("#[") { continue; }
        let declaration = t.strip_prefix("mod ")
            .or_else(|| t.strip_prefix("pub mod "))
            .or_else(|| t.strip_prefix("pub(crate) mod "))
            .or_else(|| t.strip_prefix("pub(super) mod "));
        if let Some(rest) = declaration {
            if !test {
                let name = rest.strip_suffix(';').expect("production inline modules need explicit audit support");
                assert!(name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_'));
                out.push(match override_path.take() {
                    Some(path) => parent.parent().unwrap().join(path),
                    None => parent.with_extension("").join(format!("{name}.rs")),
                });
            }
        }
        test = false;
        override_path = None;
    }
    out
}

pub(super) fn production_sources() -> Vec<(String, String)> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let mut pending = vec![PathBuf::from("src/private_block.rs")];
    let mut seen = BTreeSet::new();
    let mut out = Vec::new();
    while let Some(path) = pending.pop() {
        assert!(seen.insert(path.clone()), "duplicate/cyclic module {path:?}");
        let text = std::fs::read_to_string(root.join(&path)).expect("production source resolves");
        pending.extend(children(&text, &path));
        out.push((path.to_str().unwrap().to_string(), text));
    }
    // The endpoints also reach the frozen seam outside private_block.
    out.push(("src/private_seam.rs".into(), std::fs::read_to_string(root.join("src/private_seam.rs")).unwrap()));
    out.sort_by(|a, b| a.0.cmp(&b.0));
    out
}

#[test]
fn test_attributes_and_public_children_are_enumerated_without_scanning_test_modules() {
    let text = "#[path = \"arithmetic.rs\"]\nmod accuracy;\n#[cfg(test)]\n#[path=\"fixture.rs\"]\nmod fixture;\n#[path=\"split.rs\"]\npub(crate) mod split;\nmod plain;\n#[cfg(test)]\nmod tests {\n}\n";
    assert_eq!(children(text, Path::new("src/p.rs")), vec![
        PathBuf::from("src/arithmetic.rs"), PathBuf::from("src/split.rs"), PathBuf::from("src/p/plain.rs"),
    ]);
    assert!(std::panic::catch_unwind(|| children("mod hidden {", Path::new("src/p.rs"))).is_err());
}

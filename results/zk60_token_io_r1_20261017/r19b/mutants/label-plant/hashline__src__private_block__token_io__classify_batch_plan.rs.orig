//! Transport preflight only. No proof, model, or acceptance cache.
//! Standalone light tests: rustc --test classify_batch_plan.rs -o /tmp/a5-plan-tests
use std::collections::BTreeSet;
use std::path::{Component, Path, PathBuf};

pub(super) const POLICIES: [&str; 3] = [
    "shieldstral-1.0-3b-moderate-sexual/1",
    "shieldstral-1.0-3b-moderate-violence/1",
    "shieldstral-1.0-3b-moderate-hate/1",
];
pub(super) const MAX_JOBS: usize = 24;

#[derive(Clone, Debug)]
pub(super) struct Row {
    pub name: String,
    pub policy: String,
    pub chunk: usize,
    pub sequence: PathBuf,
    pub out: PathBuf,
    pub owner: PathBuf,
}

/// The caller derives expected from the WHOLE content and native ChunkRef.
/// Canonical ordering also makes log routing independent of worker timing.
/// TOKEN ROUND 18: `policies` is the caller's run profile's ONE fixed policy
/// list (D45(2)); production passes [`POLICIES`].
pub(super) fn check_coverage(rows: &[Row], expected: &[(String, usize)], policies: &[&str]) -> Result<(), String> {
    if rows.is_empty() || rows.len() > MAX_JOBS || rows.len() != expected.len() {
        return Err("batch: requires the complete post plan (1..24 runs)".into());
    }
    let mut names = BTreeSet::new();
    for (r, (policy, chunk)) in rows.iter().zip(expected) {
        if r.name.is_empty() || r.name.len() > 48
            || !r.name.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_' || c == b'-')
            || !names.insert(&r.name)
        {
            return Err("batch: job names must be distinct simple names of at most 48 bytes".into());
        }
        if &r.policy != policy || r.chunk != *chunk || !policies.contains(&r.policy.as_str()) {
            return Err("batch: missing, repeated, reordered, or unexpected policy/chunk".into());
        }
    }
    Ok(())
}

fn canonical(p: &Path) -> Result<PathBuf, String> {
    if !p.is_absolute() || p.components().any(|c| matches!(c, Component::ParentDir | Component::CurDir)) {
        return Err("batch: paths must be absolute and contain no dot components".into());
    }
    std::fs::canonicalize(p).map_err(|e| format!("batch: {}: {e}", p.display()))
}

fn new_path(p: &Path) -> Result<PathBuf, String> {
    if !p.is_absolute() || p.components().any(|c| matches!(c, Component::ParentDir | Component::CurDir)) {
        return Err("batch: output paths must be absolute and contain no dot components".into());
    }
    let name = p.file_name().ok_or("batch: output names no directory")?;
    let parent = canonical(p.parent().ok_or("batch: output has no parent")?)?;
    let result = parent.join(name);
    match std::fs::symlink_metadata(&result) {
        Ok(_) => Err(format!("batch: {} already exists; no overwrite or automatic retry", result.display())),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(result),
        Err(e) => Err(format!("batch: {}: {e}", result.display())),
    }
}

pub(super) fn sibling(p: &Path, suffix: &str) -> PathBuf {
    let mut s = p.as_os_str().to_owned();
    s.push(suffix);
    PathBuf::from(s)
}

fn overlaps(a: &Path, b: &Path) -> bool {
    a.starts_with(b) || b.starts_with(a)
}

/// Resolve existing parents before comparing: symlink aliases must not
/// turn distinct-looking jobs into the same receipt or private directory.
/// No files/directories are created here. The native owner_dir_at check
/// additionally refuses owners inside a git tree.
pub(super) fn check_paths(rows: &mut [Row], protected: &[PathBuf]) -> Result<(), String> {
    let mut inputs = protected.iter().map(|p| canonical(p)).collect::<Result<Vec<_>, _>>()?;
    let mut outputs = Vec::new();
    for r in rows.iter_mut() {
        r.sequence = canonical(&r.sequence)?;
        if !r.sequence.is_dir() {
            return Err("batch: sequence path is not a directory".into());
        }
        inputs.push(r.sequence.clone());
        r.out = new_path(&r.out)?;
        r.owner = new_path(&r.owner)?;
        outputs.push(r.out.clone());
        outputs.push(new_path(&sibling(&r.out, ".incomplete"))?);
        outputs.push(new_path(&sibling(&r.out, ".unverified-statement"))?);
        outputs.push(r.owner.clone());
    }
    for (i, a) in outputs.iter().enumerate() {
        if outputs[..i].iter().any(|b| overlaps(a, b)) || inputs.iter().any(|b| overlaps(a, b)) {
            return Err("batch: output/private paths overlap another job or an input".into());
        }
    }
    for owner in rows.iter().map(|r| &r.owner) {
        if rows.iter().any(|r| owner.starts_with(r.out.parent().expect("canonical output parent"))) {
            return Err("batch: an owner directory lies inside a receipt parent".into());
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    static SERIAL: AtomicUsize = AtomicUsize::new(0);
    struct Fixture { root: PathBuf, rows: Vec<Row>, expected: Vec<(String, usize)> }
    impl Fixture {
        fn new() -> Self {
            let root = std::env::temp_dir().join(format!("a5-batch-plan-{}-{}", std::process::id(), SERIAL.fetch_add(1, Ordering::Relaxed)));
            std::fs::create_dir(&root).unwrap();
            for d in ["receipts", "private", "sequences", "export"] { std::fs::create_dir(root.join(d)).unwrap(); }
            let rows = POLICIES.iter().enumerate().map(|(i, p)| {
                let sequence = root.join(format!("sequences/c{i}")); std::fs::create_dir(&sequence).unwrap();
                Row { name: format!("c{i}"), policy: p.to_string(), chunk: 0, sequence,
                    out: root.join(format!("receipts/c{i}")), owner: root.join(format!("private/c{i}")) }
            }).collect();
            let expected = POLICIES.iter().map(|p| (p.to_string(), 0)).collect();
            Self { root, rows, expected }
        }
        fn check(&mut self) -> Result<(), String> {
            check_coverage(&self.rows, &self.expected, &POLICIES)?;
            check_paths(&mut self.rows, &[self.root.join("export")])
        }
    }
    impl Drop for Fixture { fn drop(&mut self) { std::fs::remove_dir_all(&self.root).unwrap(); } }
    #[test] fn complete_plan_creates_nothing() {
        let mut f = Fixture::new(); f.check().unwrap();
        assert!(f.rows.iter().all(|r| !r.out.exists() && !r.owner.exists()));
    }
    #[test] fn missing_category_refused() { let mut f = Fixture::new(); f.rows.pop(); assert!(f.check().is_err()); }
    #[test] fn repeated_chunk_refused() { let mut f = Fixture::new(); f.rows[1].policy = POLICIES[0].into(); assert!(f.check().is_err()); }
    #[test] fn reordered_plan_refused() { let mut f = Fixture::new(); f.rows.swap(0, 1); assert!(f.check().is_err()); }
    #[test] fn prefix_subset_refused() {
        let mut f = Fixture::new(); f.expected.insert(1, (POLICIES[0].into(), 1)); assert!(f.check().is_err());
    }
    #[test] fn distinct_names_required() { let mut f = Fixture::new(); f.rows[1].name = f.rows[0].name.clone(); assert!(f.check().is_err()); }
    #[test] fn existing_receipt_and_sidecar_refused() {
        for suffix in ["", ".incomplete", ".unverified-statement"] {
            let mut f = Fixture::new(); std::fs::create_dir(sibling(&f.rows[0].out, suffix)).unwrap(); assert!(f.check().is_err());
        }
    }
    #[test] fn owner_under_other_receipt_parent_refused() {
        let mut f = Fixture::new(); f.rows[0].owner = f.root.join("receipts/secret"); assert!(f.check().is_err());
    }
    #[test] fn symlink_parent_alias_refused() {
        let mut f = Fixture::new(); std::os::unix::fs::symlink(f.root.join("receipts"), f.root.join("alias")).unwrap();
        f.rows[1].out = f.root.join("alias/c0"); assert!(f.check().is_err());
    }
    #[test] fn dangling_symlink_refused() {
        let mut f = Fixture::new(); std::os::unix::fs::symlink(f.root.join("absent"), &f.rows[0].out).unwrap(); assert!(f.check().is_err());
    }
    #[test] fn output_in_model_refused() { let mut f = Fixture::new(); f.rows[0].out = f.root.join("export/run"); assert!(f.check().is_err()); }
    #[test] fn output_sidecar_alias_refused() {
        let mut f = Fixture::new(); f.rows[1].out = sibling(&f.rows[0].out, ".unverified-statement"); assert!(f.check().is_err());
    }
    #[test] fn dotdot_path_refused() { let mut f = Fixture::new(); f.rows[0].owner = f.root.join("private/../secret"); assert!(f.check().is_err()); }
}

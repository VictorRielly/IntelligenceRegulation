//! **INDEPENDENT ADVERSARIAL REVIEW, ROUND 6 (2026-10-19): the token lane's
//! rounds 6 and 7 — TR5-1 / TR5-3 closure at the CLI.** TEST CODE ONLY,
//! reviewer's scratch copy; a child of `token_io::cli`. Public synthetic data
//! (the native lane's tiny export, generic tables planted with its x_in rows).
//! `REVIEW-R6 CONTROL` lines are asserted; `REVIEW-R6 NOTE` lines are printed.

use super::*;
use super::super::r3_tests::write_token_tables;
use super::super::super::trained_block::sha256;
use super::super::super::trained_block_tests::{write_export, Fault};
use super::super::tests::{generic_tables, norm};

fn a(pairs: &[(&str, &str)]) -> Vec<(String, String)> {
    pairs.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect()
}

fn copy_dir(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for e in std::fs::read_dir(from).unwrap() {
        let e = e.unwrap();
        let (src, dst) = (e.path(), to.join(e.file_name()));
        if e.file_type().unwrap().is_dir() {
            copy_dir(&src, &dst);
        } else {
            std::fs::copy(&src, &dst).unwrap();
        }
    }
}

struct H {
    root: PathBuf,
    export: PathBuf,
    tables: PathBuf,
    prompt: String,
}

impl H {
    fn new(tag: &str) -> H {
        let root = std::env::temp_dir().join(format!("tio-rv6-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).unwrap();
        let (export, _) = write_export(&root, "tiny", &Fault::default());
        let ex = TrainedExport::load(&export).unwrap();
        let c = ex.run_constants(&ex.layers).unwrap();
        let sh = ex.shape_for(&c).unwrap();
        let (x_in, _) = ex.load_seq(&sh, "s0", 0).unwrap();
        let tokens: Vec<u64> = (1..=sh.tokens as u64).collect();
        let mut t = generic_tables(sh.width, 0x7276_3631);
        for (pos, id) in tokens.iter().enumerate() {
            let at = *id as usize * t.d;
            t.emb[at..at + t.d].copy_from_slice(&x_in[pos * sh.width..(pos + 1) * sh.width]);
        }
        let tables = root.join("tables");
        write_token_tables(&tables, &t, norm());
        let prompt = tokens.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",");
        for d in ["owners", "runs", "p1", "p2"] {
            std::fs::create_dir_all(root.join(d)).unwrap();
        }
        H { root, export, tables, prompt }
    }
    fn prove_at(&self, out: &Path, od: &Path, seq_dir: Option<&Path>) -> Result<(), String> {
        let (ex, tb, o, ods) = (self.export.to_str().unwrap(), self.tables.to_str().unwrap(), out.to_str().unwrap(), od.to_str().unwrap());
        let mut f = a(&[("--export", ex), ("--emb", tb), ("--head", tb), ("--prompt", &self.prompt), ("--out", o), ("--owner-dir", ods)]);
        match seq_dir {
            Some(d) => f.push(("--seq-dir".into(), d.to_str().unwrap().into())),
            None => f.push(("--seq".into(), "s0".into())),
        }
        prove_inner(&f)
    }
}

impl Drop for H {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.root);
    }
}

fn outcome(r: &Result<(), String>) -> String {
    match r {
        Ok(()) => "ACCEPTED (exit 0)".into(),
        Err(e) => format!("refused: {}", e.chars().take(220).collect::<String>()),
    }
}

fn control(id: &str, what: &str, ok: bool, detail: &str) {
    eprintln!("REVIEW-R6 CONTROL {id} | {what} | {detail} | {}", if ok { "AS PREDICTED" } else { "NOT AS PREDICTED" });
    assert!(ok, "REVIEW-R6 {id} ({what}): {detail}");
}

fn sib(p: &Path, suffix: &str) -> PathBuf {
    let mut s = p.as_os_str().to_owned();
    s.push(suffix);
    PathBuf::from(s)
}

/// RV6-1 (TR5-1): two REAL proves at once (two threads), first naming the
/// same owner directory from runs in different parents (round 5's
/// reproduction), then naming the same `--out`.
#[test]
fn rv6_1_concurrent_proves_never_remove_a_rivals_directories() {
    let h = std::sync::Arc::new(H::new("race"));
    for round in 0..2 {
        // (a) the same owner directory, runs `same` in p1/ and p2/
        let shared = h.root.join("owners").join(format!("same{round}.owner-private"));
        let (o1, o2) = (h.root.join("p1").join(format!("same{round}")), h.root.join("p2").join(format!("same{round}")));
        let (ha, hb, sa, sb, oa, ob) = (h.clone(), h.clone(), shared.clone(), shared.clone(), o1.clone(), o2.clone());
        let t1 = std::thread::spawn(move || ha.prove_at(&oa, &sa, None));
        let t2 = std::thread::spawn(move || hb.prove_at(&ob, &sb, None));
        let (r1, r2) = (t1.join().unwrap(), t2.join().unwrap());
        let oks = [r1.is_ok(), r2.is_ok()];
        let survived = shared.join("output.dec").is_file() && shared.join("input.dec").is_file();
        let loser = if r1.is_ok() { &o2 } else { &o1 };
        let loser_left: Vec<String> = [loser.clone(), sib(loser, ".incomplete"), sib(loser, ".unverified-statement")].iter().filter(|p| p.exists()).map(|p| p.display().to_string()).collect();
        control(
            &format!("RV6-1a.{round}"),
            "two proves naming the SAME owner directory at once (round-5 TR5-1 reproduction)",
            oks.iter().filter(|x| **x).count() == 1 && survived && loser_left.is_empty(),
            &format!("{} | {} | winner's decommitments present: {survived} | loser left: {loser_left:?}", outcome(&r1), outcome(&r2)),
        );
        // (b) the same --out, distinct owner directories
        let out = h.root.join("runs").join(format!("one{round}"));
        let (oda, odb) = (h.root.join("owners").join(format!("a{round}.owner-private")), h.root.join("owners").join(format!("b{round}.owner-private")));
        let (ha, hb, xa, xb, oa, ob) = (h.clone(), h.clone(), out.clone(), out.clone(), oda.clone(), odb.clone());
        let t1 = std::thread::spawn(move || ha.prove_at(&xa, &oa, None));
        let t2 = std::thread::spawn(move || hb.prove_at(&xb, &ob, None));
        let (r1, r2) = (t1.join().unwrap(), t2.join().unwrap());
        let (wod, lod) = if r1.is_ok() { (&oda, &odb) } else { (&odb, &oda) };
        let intact = out.is_dir() && sib(&out, ".unverified-statement").join("statement.json").is_file() && wod.join("output.dec").is_file();
        control(
            &format!("RV6-1b.{round}"),
            "two proves naming the SAME --out at once",
            [r1.is_ok(), r2.is_ok()].iter().filter(|x| **x).count() == 1 && intact && !lod.exists() && !sib(&out, ".incomplete").exists(),
            &format!("{} | {} | winner's run, statement and decommitments intact: {intact} | loser's owner dir left: {}", outcome(&r1), outcome(&r2), lod.exists()),
        );
    }
}

/// RV6-2 (TR5-1): a prove refused MID-RUN (parity at block 0, after stage IN's
/// segment was written) leaves none of its claimed directories; a stale
/// `<out>.incomplete/` (a crashed prove) is refused and left as it was.
#[test]
fn rv6_2_a_mid_run_refusal_leaves_nothing_and_a_stale_claim_is_untouched() {
    let h = H::new("partial");
    let bad = h.root.join("seq-bad");
    copy_dir(&h.export.join("seq_s0"), &bad);
    let xo = bad.join("x_out_L00.bin");
    let orig = std::fs::read(&xo).unwrap();
    let mut b = orig.clone();
    b[10] ^= 1;
    std::fs::write(&xo, &b).unwrap();
    let man = bad.join("manifest.json");
    let text = std::fs::read_to_string(&man).unwrap();
    let (old, new) = (hex(&sha256(&orig)), hex(&sha256(&b)));
    assert!(text.contains(&old));
    std::fs::write(&man, text.replace(&old, &new)).unwrap();
    let out = h.root.join("runs").join("partial");
    let od = h.root.join("owners").join("partial.owner-private");
    let r = h.prove_at(&out, &od, Some(&bad));
    let left: Vec<String> = [out.clone(), sib(&out, ".incomplete"), sib(&out, ".unverified-statement"), od.clone()].iter().filter(|p| p.exists()).map(|p| p.display().to_string()).collect();
    control("RV6-2a", "a prove refused mid-run (parity at block 0)", r.is_err() && left.is_empty(), &format!("{} | left behind: {left:?}", outcome(&r)));
    let out = h.root.join("runs").join("stale");
    let inc = sib(&out, ".incomplete");
    std::fs::create_dir(&inc).unwrap();
    std::fs::write(inc.join("segment-000.bin"), b"a crashed prove's segment").unwrap();
    let od = h.root.join("owners").join("stale.owner-private");
    let r = h.prove_at(&out, &od, None);
    control(
        "RV6-2b",
        "a stale <out>.incomplete/ from a crashed prove",
        r.is_err() && inc.join("segment-000.bin").is_file() && !od.exists() && !sib(&out, ".unverified-statement").exists(),
        &format!("{} | stale segment kept: {}", outcome(&r), inc.join("segment-000.bin").is_file()),
    );
}

/// RV6-3 (TR5-3): the owner-directory placement rules at their edges.
#[test]
fn rv6_3_owner_dir_placement_edges() {
    let h = H::new("place");
    let out = h.root.join("runs").join("run");
    // (a) an explicit owner directory reached THROUGH A SYMLINK into a git
    // working tree
    let repo = h.root.join("repo");
    std::fs::create_dir_all(repo.join(".git")).unwrap();
    std::fs::create_dir_all(repo.join("deep").join("er")).unwrap();
    std::os::unix::fs::symlink(repo.join("deep"), h.root.join("link-into-repo")).unwrap();
    let r = owner_dir_at(&a(&[("--owner-dir", h.root.join("link-into-repo").join("er").join("x.owner-private").to_str().unwrap())]), &out, None).map(|_| ());
    control("RV6-3a", "an explicit --owner-dir reached through a symlink into a git working tree", r.is_err(), &outcome(&r));
    // (b) the default for a run directly under $HOME, $HOME reached through a symlink
    let home = h.root.join("home");
    std::fs::create_dir_all(&home).unwrap();
    std::os::unix::fs::symlink(&home, h.root.join("home-link")).unwrap();
    let r = owner_dir_at(&[], &h.root.join("home-link").join("run"), Some(&home)).map(|_| ());
    control("RV6-3b", "the default owner dir, run directly under $HOME (named through a symlink)", r.is_ok(), &outcome(&r));
    let r = owner_dir_at(&[], &home.join("zk60-artifacts").join("run"), Some(&home)).map(|_| ());
    control("RV6-3c", "the default owner dir, run in $HOME/zk60-artifacts (an ancestor of the base, not $HOME)", r.is_err(), &outcome(&r));
    // (d) INFO: the DEFAULT directory is never checked for a git working tree
    let ghome = h.root.join("git-home");
    std::fs::create_dir_all(ghome.join(".git")).unwrap();
    std::fs::create_dir_all(h.root.join("elsewhere")).unwrap();
    let r = owner_dir_at(&[], &h.root.join("elsewhere").join("run"), Some(&ghome)).map(|_| ());
    eprintln!("REVIEW-R6 NOTE | the DEFAULT owner directory when $HOME itself is a git working tree: {}", outcome(&r));
    let r = owner_dir_at(&a(&[("--owner-dir", ghome.join("x.owner-private").to_str().unwrap())]), &h.root.join("elsewhere").join("run"), Some(&ghome)).map(|_| ());
    eprintln!("REVIEW-R6 NOTE | an EXPLICIT owner directory in the same $HOME: {}", outcome(&r));
    // (e) INFO: the default path given EXPLICITLY for a run directly under $HOME
    let dflt = default_owner_dir(&home.join("zk60-artifacts").join("token-io"), &home.join("run2")).unwrap();
    let r = owner_dir_at(&a(&[("--owner-dir", dflt.to_str().unwrap())]), &home.join("run2"), Some(&home)).map(|_| ());
    eprintln!("REVIEW-R6 NOTE | the default owner directory's path given explicitly for a run directly under $HOME: {}", outcome(&r));
}

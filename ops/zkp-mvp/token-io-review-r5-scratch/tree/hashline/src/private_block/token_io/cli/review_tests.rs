//! **INDEPENDENT ADVERSARIAL REVIEW, ROUND 5 (2026-10-19): confirmation of
//! the TR4 fixes.** TEST CODE ONLY, reviewer's scratch copy; a child of
//! `token_io::cli`. The round-4 reproductions against the fixed commands, on
//! the native lane's tiny export (public synthetic data).

use super::*;
use super::super::r3_tests::write_token_tables;
use super::super::super::trained_block_tests::{write_export, Fault};
use super::super::tests::{generic_tables, norm};

fn a(pairs: &[(&str, &str)]) -> Vec<(String, String)> {
    pairs.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect()
}

fn copy_public(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for e in std::fs::read_dir(from).unwrap() {
        let e = e.unwrap();
        let name = e.file_name().to_string_lossy().to_string();
        if name.starts_with("seq_") {
            continue;
        }
        let (src, dst) = (e.path(), to.join(&name));
        if e.file_type().unwrap().is_dir() {
            copy_public(&src, &dst);
        } else {
            std::fs::copy(&src, &dst).unwrap();
        }
    }
}

struct H {
    root: PathBuf,
    export: PathBuf,
    vcopy: PathBuf,
    tables: PathBuf,
    t: TokenTables,
    prompt: String,
    identity: String,
}

impl H {
    fn new(tag: &str) -> H {
        let root = std::env::temp_dir().join(format!("tio-rv5-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).unwrap();
        let (export, _) = write_export(&root, "tiny", &Fault::default());
        let ex = TrainedExport::load(&export).unwrap();
        let c = ex.run_constants(&ex.layers).unwrap();
        let sh = ex.shape_for(&c).unwrap();
        let (x_in, _) = ex.load_seq(&sh, "s0", 0).unwrap();
        let tokens: Vec<u64> = (1..=sh.tokens as u64).collect();
        let mut t = generic_tables(sh.width, 0x7276_3531);
        for (pos, id) in tokens.iter().enumerate() {
            let at = *id as usize * t.d;
            t.emb[at..at + t.d].copy_from_slice(&x_in[pos * sh.width..(pos + 1) * sh.width]);
        }
        let tables = root.join("tables");
        write_token_tables(&tables, &t, norm());
        let vcopy = root.join("verifier-copy");
        copy_public(&export, &vcopy);
        let p = ExportPublic::load(&export).unwrap();
        let prompt = tokens.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",");
        std::fs::create_dir_all(root.join("owners")).unwrap();
        std::fs::create_dir_all(root.join("runs")).unwrap();
        H { root, export, vcopy, tables, t, prompt, identity: hex(&p.model.identity()) }
    }
    /// the token-profile pin of a table directory (what `profile` prints)
    fn pin_of(&self, tables: &Path) -> String {
        let p = ExportPublic::load(&self.export).unwrap();
        let files = TableFiles { emb_dir: tables.to_path_buf(), head_dir: tables.to_path_buf() };
        let (t, tm) = load_token_tables(&files, super::super::load::read_manifests(&files).unwrap().v, p.sh.width).unwrap();
        let tp = TokenProfile::new(&p.sh, &t, tm.bos, tm.norm, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
        hex(&tp.digest_under(p.profile))
    }
    fn owner_dir(&self, out: &Path) -> PathBuf {
        self.root.join("owners").join(format!("{}.owner-private", out.file_name().unwrap().to_string_lossy()))
    }
    fn prove_with(&self, out: &Path, tables: &Path, owner_dir: Option<&Path>) -> Result<(), String> {
        let (ex, tb, o) = (self.export.to_str().unwrap().to_string(), tables.to_str().unwrap().to_string(), out.to_str().unwrap().to_string());
        let od = owner_dir.map(|p| p.to_path_buf()).unwrap_or_else(|| self.owner_dir(out));
        let ods = od.to_str().unwrap().to_string();
        prove_inner(&a(&[("--export", &ex), ("--emb", &tb), ("--head", &tb), ("--seq", "s0"), ("--prompt", &self.prompt), ("--out", &o), ("--owner-dir", &ods)]))
    }
    fn prove(&self, out: &Path) -> Result<(), String> {
        self.prove_with(out, &self.tables, None)
    }
    fn pins(&self, art: &Path, tables: &Path, tp: &str) -> Vec<(String, String)> {
        a(&[("--export", self.vcopy.to_str().unwrap()), ("--emb", tables.to_str().unwrap()), ("--head", tables.to_str().unwrap()), ("--artifact", art.to_str().unwrap()), ("--expect-statement", &self.identity), ("--expect-token-profile", tp), ("--min-bits", "93")])
    }
    fn verify(&self, art: &Path, tables: &Path, tp: &str) -> Result<(), String> {
        verify_inner(&self.pins(art, tables, tp))
    }
    fn owner(&self, art: &Path, tp: &str, dec: &Path) -> Result<(), String> {
        let mut f = self.pins(art, &self.tables, tp);
        f.push(("--decommitment".into(), dec.to_str().unwrap().into()));
        owner_inner(&f)
    }
    fn input_owner(&self, art: &Path, tp: &str, dec: &Path, prompt: &str) -> Result<(), String> {
        let mut f = self.pins(art, &self.tables, tp);
        f.push(("--decommitment".into(), dec.to_str().unwrap().into()));
        f.push(("--prompt".into(), prompt.into()));
        input_owner_inner(&f)
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
        Err(e) => format!("refused: {}", e.chars().take(200).collect::<String>()),
    }
}

fn control(id: &str, what: &str, want_refused: bool, r: &Result<(), String>) {
    let ok = r.is_err() == want_refused;
    eprintln!("REVIEW-R5 CONTROL {id} | {what} | {} | {}", outcome(r), if ok { "AS PREDICTED" } else { "NOT AS PREDICTED" });
    assert!(ok, "REVIEW-R5 {id} ({what}): {}", outcome(r));
}

fn flip_byte(path: &Path) {
    let mut b = std::fs::read(path).unwrap();
    let at = b.len() / 2;
    b[at] ^= 1;
    std::fs::write(path, &b).unwrap();
}

/// RV5-1 (TR4-1): the owner and input-owner re-verify: refused over a
/// tampered receipt and over a prover-written statement; honest ones pass.
#[test]
fn rv5_1_owner_and_input_owner_reverify() {
    let h = H::new("owner");
    let tp = h.pin_of(&h.tables);
    let out = h.root.join("runs").join("run");
    h.prove(&out).unwrap();
    let od = h.owner_dir(&out);
    control("RV5-1a", "owner before any verifier published", true, &h.owner(&out, &tp, &od.join("output.dec")));
    h.verify(&out, &h.tables, &tp).expect("the honest verify");
    control("RV5-1b", "owner after an honest verify", false, &h.owner(&out, &tp, &od.join("output.dec")));
    control("RV5-1c", "input-owner after an honest verify, the owner's own prompt", false, &h.input_owner(&out, &tp, &od.join("input.dec"), &h.prompt));
    let mut other: Vec<String> = h.prompt.split(',').map(|s| s.to_string()).collect();
    other[4] = "250".into();
    control("RV5-1d", "input-owner with another prompt", true, &h.input_owner(&out, &tp, &od.join("input.dec"), &other.join(",")));
    flip_byte(&out.join(run_sink::segment_file_name(2)));
    control("RV5-1e", "owner after a segment was tampered (round-4 TR4-1 reproduction)", true, &h.owner(&out, &tp, &od.join("output.dec")));
    control("RV5-1f", "input-owner after the same tampering", true, &h.input_owner(&out, &tp, &od.join("input.dec"), &h.prompt));
    let out2 = h.root.join("runs").join("run2");
    h.prove(&out2).unwrap();
    let forged = std::fs::read_to_string(unverified_dir(&out2).join("statement.json")).unwrap().replace(Writer::Unverified.text(), Writer::FreshVerify.text());
    let sd = out2.join(run_sink::STATEMENT_DIR);
    std::fs::create_dir(&sd).unwrap();
    std::fs::write(sd.join("statement.json"), forged).unwrap();
    std::fs::write(sd.join("segments.json"), b"not the hashes of anything\n").unwrap();
    control("RV5-1g", "owner over a statement/ the PROVER wrote (round-4 TR4-1 reproduction)", true, &h.owner(&out2, &tp, &h.owner_dir(&out2).join("output.dec")));
}

/// RV5-2 (TR4-2): another head, half the Cn: refused under the approved
/// token-profile pin; the pin is required; a verifier handed the OTHER
/// tables' own pin accepts (the pin is the verifier's choice, by design).
#[test]
fn rv5_2_the_token_profile_pin() {
    let h = H::new("pin");
    let tp = h.pin_of(&h.tables);
    let mut tb = h.t.clone();
    for m in tb.mult.iter_mut() {
        *m = if *m == 4096 { 1 } else { *m + 1 };
    }
    let dir_b = h.root.join("tables-b");
    write_token_tables(&dir_b, &tb, norm());
    let dir_c = h.root.join("tables-c");
    write_token_tables(&dir_c, &h.t, FinalNorm { cn: norm().cn / 2, ..norm() });
    for (id, what, dir) in [("RV5-2a", "another head (every multiplier changed) under the APPROVED token-profile pin (round-4 TR4-2 reproduction)", &dir_b), ("RV5-2b", "half the Cn under the APPROVED token-profile pin (round-4 TR4-2 reproduction)", &dir_c)] {
        let out = h.root.join("runs").join(format!("run-{id}"));
        h.prove_with(&out, dir, None).unwrap();
        let r = h.verify(&out, dir, &tp);
        control(id, what, true, &r);
        assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "{id}: published");
        let own = h.pin_of(dir);
        eprintln!("REVIEW-R5 NOTE | {id} | the same run under its OWN tables' pin (a verifier configured with the substituted tables' pin): {}", outcome(&h.verify(&out, dir, &own)));
    }
    let out = h.root.join("runs").join("run-nopin");
    h.prove(&out).unwrap();
    let mut f = h.pins(&out, &h.tables, &tp);
    f.retain(|(k, _)| k != "--expect-token-profile");
    control("RV5-2c", "verify with no --expect-token-profile", true, &verify_inner(&f));
}

/// RV5-3 (TR4-3): owner-dir placement and modes; and two concurrent proves
/// that name the SAME owner directory (the default is keyed by the run's
/// base name): does the loser's cleanup remove the winner's decommitments?
#[test]
fn rv5_3_owner_dir_placement_and_a_same_name_collision() {
    let h = H::new("place");
    let out = h.root.join("runs").join("run");
    control("RV5-3a", "--owner-dir inside the run's parent", true, &h.prove_with(&out, &h.tables, Some(&h.root.join("runs").join("x.owner-private"))));
    std::fs::create_dir_all(h.root.join("runs").join("sub")).unwrap();
    let r = h.prove_with(&out, &h.tables, Some(&h.root.join("runs").join("sub").join("x.owner-private")));
    control("RV5-3b", "--owner-dir in an existing subdirectory of the run's parent", true, &r);
    assert!(r.unwrap_err().contains("inside the run's parent"), "RV5-3b refused for another reason");
    // through a symlink: an owner dir whose parent is a link INTO the run's parent
    std::os::unix::fs::symlink(h.root.join("runs"), h.root.join("link-to-runs")).unwrap();
    let r = h.prove_with(&out, &h.tables, Some(&h.root.join("link-to-runs").join("y.owner-private")));
    control("RV5-3c", "--owner-dir whose parent is a symlink to the run's parent", true, &r);
    eprintln!("REVIEW-R5 PLACE | an --owner-dir elsewhere (not under the run's parent) is accepted wherever it is, e.g. beside the export: {}", outcome(&h.prove_with(&h.root.join("runs").join("run-elsewhere"), &h.tables, Some(&h.root.join("tables-owner.owner-private")))));
    assert!(!out.exists());
    h.prove(&out).expect("the honest prove");
    use std::os::unix::fs::PermissionsExt;
    let od = h.owner_dir(&out);
    let dm = std::fs::metadata(&od).unwrap().permissions().mode() & 0o777;
    let fm: Vec<u32> = ["input.dec", "output.dec"].iter().map(|n| std::fs::metadata(od.join(n)).unwrap().permissions().mode() & 0o777).collect();
    eprintln!("REVIEW-R5 PLACE | owner dir {} mode {dm:o}, files {:o} / {:o}; run dir entries: {:?}", od.display(), fm[0], fm[1], std::fs::read_dir(&out).unwrap().count());
    assert_eq!((dm, fm), (0o700, vec![0o600, 0o600]));
    // the collision: two proves of runs with the same base name in different
    // parents, both naming the same owner directory, started together
    let shared = h.root.join("owners").join("same.owner-private");
    let (o1, o2) = (h.root.join("p1").join("same"), h.root.join("p2").join("same"));
    std::fs::create_dir_all(o1.parent().unwrap()).unwrap();
    std::fs::create_dir_all(o2.parent().unwrap()).unwrap();
    let h = std::sync::Arc::new(h);
    let (ha, hb, sa, sb, oa, ob) = (h.clone(), h.clone(), shared.clone(), shared.clone(), o1.clone(), o2.clone());
    let t1 = std::thread::spawn(move || ha.prove_with(&oa, &ha.tables, Some(&sa)));
    let t2 = std::thread::spawn(move || hb.prove_with(&ob, &hb.tables, Some(&sb)));
    let (r1, r2) = (t1.join().unwrap(), t2.join().unwrap());
    let winner = if r1.is_ok() { Some(&o1) } else if r2.is_ok() { Some(&o2) } else { None };
    let survived = shared.join("output.dec").is_file() && shared.join("input.dec").is_file();
    eprintln!(
        "REVIEW-R5 FINDING TR5-collision | two proves naming the same owner directory at once: {} | {} | winner run present: {:?} | the owner directory's decommitments after both: {}",
        outcome(&r1),
        outcome(&r2),
        winner.map(|w| w.is_dir()),
        if survived { "PRESENT" } else { "GONE (a completed run without its owners' decommitments)" }
    );
}

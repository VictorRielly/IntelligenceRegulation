//! **THE TOKEN-I/O CLI END TO END (2026-10-19).** TEST CODE ONLY, public
//! synthetic data: the native lane's tiny export (the trained-calibration
//! rung, one layer, one sequence) and a generic table set whose rows at the
//! prompt's ids are that sequence's x_in_L00 rows. `prove` -> `verify` (the
//! verifier publishes the statement, a second verify re-checks it byte for
//! byte) -> `owner` (the output decommitment against the published
//! statement); and the refusals: an export holding seq_* handed to a
//! verifier, a wrong pin, a tampered segment, a backend outside the build's
//! names, an existing output directory, an owner before publication. A
//! refused verification publishes nothing.

use super::cli::{token_input_owner_command, token_owner_command, token_profile_command, token_prove_command, token_verify_command};
use super::load::ExportPublic;
use super::r3_tests::write_token_tables;
use super::stage_out;
use super::tests::*;
use super::*;
use super::super::run_sink;
use super::super::trained_block::TrainedExport;
use super::super::trained_block_tests::{write_export, Fault};
use std::path::{Path, PathBuf};

fn s(v: &[&str]) -> Vec<String> {
    v.iter().map(|x| x.to_string()).collect()
}

fn sib(p: &Path, suffix: &str) -> PathBuf {
    let mut o = p.as_os_str().to_owned();
    o.push(suffix);
    PathBuf::from(o)
}

/// copy an export's PUBLIC files (every entry but `seq_*`), as a verifier's copy
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

struct Cli {
    root: PathBuf,
    /// where the owners' decommitments go: OUTSIDE the run's parent (TR4-3)
    owners: PathBuf,
    export: PathBuf,
    verifier_copy: PathBuf,
    tables: PathBuf,
    prompt: String,
    identity: String,
    /// the approved token profile's digest (the TR4-2 pin)
    token_profile: String,
    want_token: usize,
    t: TokenTables,
}

impl Cli {
    fn new(tag: &str) -> Cli {
        let root = std::env::temp_dir().join(format!("tio-cli-{tag}-{}", std::process::id()));
        let owners = std::env::temp_dir().join(format!("tio-cli-owners-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let _ = std::fs::remove_dir_all(&owners);
        std::fs::create_dir_all(&root).unwrap();
        std::fs::create_dir_all(&owners).unwrap();
        let (export, _) = write_export(&root, "tiny", &Fault::default());
        let ex = TrainedExport::load(&export).unwrap();
        let c = ex.run_constants(&ex.layers).unwrap();
        let sh = ex.shape_for(&c).unwrap();
        let (x_in, x_out) = ex.load_seq(&sh, "s0", 0).unwrap();
        // the prompt: BOS 1 then 31 distinct ids, each embedded to its x_in_L00 row
        let tokens: Vec<u64> = (1..=sh.tokens as u64).collect();
        let mut t = generic_tables(sh.width, 0x636c_6931);
        for (pos, id) in tokens.iter().enumerate() {
            let at = *id as usize * t.d;
            t.emb[at..at + t.d].copy_from_slice(&x_in[pos * sh.width..(pos + 1) * sh.width]);
        }
        let tables = root.join("tables");
        write_token_tables(&tables, &t, norm());
        let verifier_copy = root.join("verifier-copy");
        copy_public(&export, &verifier_copy);
        let p = ExportPublic::load(&export).unwrap();
        // the reference next token on the export's own last-layer row
        let tp = TokenProfile::new(&sh, &t, 1, norm(), SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
        let mut row = vec![0i64; tp.d_pad];
        for i in 0..tp.d {
            row[i] = i64::from(x_out[(tp.tokens - 1) * tp.d + i]);
        }
        let want_token = stage_out::out_values(&tp, &t, &row, true).unwrap().tok;
        let token_profile = hex(&tp.digest_under(p.profile));
        let prompt = tokens.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",");
        Cli { root, owners, export, verifier_copy, tables, prompt, identity: hex(&p.model.identity()), token_profile, want_token, t }
    }
    /// the owners' directory of a run (TR4-3: given explicitly, outside the run's parent)
    fn owner_dir(&self, out: &Path) -> PathBuf {
        self.owners.join(format!("{}.owner-private", out.file_name().unwrap().to_string_lossy()))
    }
    /// where `prove` actually put the output decommitment (the owners' directory,
    /// or, before TR4-3, the run's sibling)
    fn dec(&self, out: &Path, which: &str) -> PathBuf {
        let d = self.owner_dir(out).join(which);
        if d.exists() {
            d
        } else {
            sib(out, ".owner-private").join(which)
        }
    }
    fn prove_tables(&self, out: &Path, tables: &Path) -> i32 {
        let od = self.owner_dir(out);
        token_prove_command(&s(&["--export", self.export.to_str().unwrap(), "--emb", tables.to_str().unwrap(), "--head", tables.to_str().unwrap(), "--seq", "s0", "--prompt", &self.prompt, "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]))
    }
    fn prove(&self, out: &Path) -> i32 {
        self.prove_tables(out, &self.tables)
    }
    fn verify_full(&self, export: &Path, tables: &Path, out: &Path, pin: &str, token_pin: &str) -> i32 {
        token_verify_command(&s(&["--export", export.to_str().unwrap(), "--emb", tables.to_str().unwrap(), "--head", tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", pin, "--expect-token-profile", token_pin, "--min-bits", "93"]))
    }
    fn verify_with(&self, export: &Path, out: &Path, pin: &str) -> i32 {
        self.verify_full(export, &self.tables, out, pin, &self.token_profile)
    }
    fn verify(&self, out: &Path) -> i32 {
        self.verify_with(&self.verifier_copy, out, &self.identity)
    }
    fn input_owner(&self, out: &Path, prompt: &str) -> i32 {
        let dec = self.dec(out, "input.dec");
        token_input_owner_command(&s(&["--export", self.verifier_copy.to_str().unwrap(), "--emb", self.tables.to_str().unwrap(), "--head", self.tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", &self.identity, "--expect-token-profile", &self.token_profile, "--decommitment", dec.to_str().unwrap(), "--prompt", prompt, "--min-bits", "93"]))
    }
    fn owner(&self, out: &Path) -> i32 {
        let dec = self.dec(out, "output.dec");
        token_owner_command(&s(&["--export", self.verifier_copy.to_str().unwrap(), "--emb", self.tables.to_str().unwrap(), "--head", self.tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", &self.identity, "--expect-token-profile", &self.token_profile, "--decommitment", dec.to_str().unwrap(), "--min-bits", "93"]))
    }
}

impl Drop for Cli {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.root);
        let _ = std::fs::remove_dir_all(&self.owners);
    }
}

/// **The token CLI end to end**: prove (segments renamed into place only
/// after Ok; the unverified statement beside the run; the owners'
/// decommitments private), the verifier publishes the statement and removes
/// the unverified one, a second verify re-checks it byte for byte, the owner
/// reads the next token from the published statement.
#[test]
fn cli_the_token_run_proves_the_verifier_publishes_rechecks_and_the_owner_reads_the_token() {
    let cli = Cli::new("e2e");
    let out = cli.root.join("run");
    assert_eq!(cli.prove(&out), 0, "prove");
    assert!(out.is_dir() && !sib(&out, ".incomplete").exists(), "the run directory is in place, the incomplete one gone");
    assert!(sib(&out, ".unverified-statement").join("statement.json").is_file(), "the prover's statement is beside the run, unverified");
    let dec = cli.dec(&out, "output.dec");
    {
        use std::os::unix::fs::PermissionsExt;
        assert_eq!(std::fs::metadata(&dec).unwrap().permissions().mode() & 0o777, 0o600, "the owner's decommitment is private");
    }
    assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "the prover published nothing");
    assert_eq!(cli.owner(&out), 1, "the owner refuses a run nobody verified");
    assert_eq!(cli.verify_with(&cli.export, &out, &cli.identity), 1, "P-5: a verifier handed the export with seq_* refuses");
    assert_eq!(cli.verify_with(&cli.verifier_copy, &out, &"0".repeat(64)), 1, "a wrong pin is refused");
    assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "the refusals published nothing");
    assert_eq!(cli.verify(&out), 0, "the fresh-process verify");
    assert!(out.join(run_sink::STATEMENT_DIR).join("statement.json").is_file(), "the verifier published the statement");
    assert!(!sib(&out, ".unverified-statement").exists(), "and removed the unverified one");
    let stmt = std::fs::read_to_string(out.join(run_sink::STATEMENT_DIR).join("statement.json")).unwrap();
    assert!(stmt.contains("zk60_token_io verify, after its fresh-process verification"), "{stmt}");
    assert_eq!(cli.verify(&out), 0, "a second verify re-checks the published statement byte for byte");
    assert_eq!(cli.owner(&out), 0, "the owner's check against the published statement");
    // review TR4-4: the input owner's check (its own prompt; another one refused)
    assert_eq!(cli.input_owner(&out, &cli.prompt), 0, "the input owner's check");
    let other = cli.prompt.replacen(",2,", ",3,", 1);
    assert_ne!(other, cli.prompt);
    assert_eq!(cli.input_owner(&out, &other), 1, "another prompt is refused by the input owner's check");
    // `profile` prints the pins (exit 0; the values are the fixture's)
    assert_eq!(token_profile_command(&s(&["--export", cli.verifier_copy.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap()])), 0);
    let d = Decommitment::from_bytes(&std::fs::read(&dec).unwrap()).unwrap();
    assert_eq!(d.data[0].0 as usize, cli.want_token, "the decommitted id is the reference next token");
    eprintln!("TOKEN-IO CLI | prove -> verify (published by the verifier) -> re-check -> owner: token {} = the reference | refused: owner before publication, P-5 export, wrong pin", cli.want_token);
}

/// **A refused verification publishes nothing**: a tampered segment, and a
/// prover statement naming a backend outside the build's names (R7 / Q-2);
/// and a prove into an existing directory is refused.
#[test]
fn cli_a_tampered_segment_or_an_unlisted_backend_is_refused_and_nothing_is_published() {
    let cli = Cli::new("refuse");
    let out1 = cli.root.join("run1");
    assert_eq!(cli.prove(&out1), 0);
    let seg = out1.join(run_sink::segment_file_name(2));
    let mut b = std::fs::read(&seg).unwrap();
    let at = b.len() / 2;
    b[at] ^= 1;
    std::fs::write(&seg, &b).unwrap();
    assert_eq!(cli.verify(&out1), 1, "a tampered segment is refused");
    assert!(!out1.join(run_sink::STATEMENT_DIR).exists() && sib(&out1, ".unverified-statement").exists(), "and nothing was published");
    let out2 = cli.root.join("run2");
    assert_eq!(cli.prove(&out2), 0);
    let sp = sib(&out2, ".unverified-statement").join("statement.json");
    let text = std::fs::read_to_string(&sp).unwrap();
    let edited = text.replace("gpu: off (built without --features gpu-cuda)", "gpu: on (a prover's own words)");
    assert_ne!(edited, text, "the statement names the CPU build's backend");
    std::fs::write(&sp, edited).unwrap();
    assert_eq!(cli.verify(&out2), 1, "a backend outside the build's names is refused");
    assert!(!out2.join(run_sink::STATEMENT_DIR).exists(), "and nothing was published");
    assert_eq!(cli.prove(&out2), 1, "a prove into an existing directory is refused");
    eprintln!("TOKEN-IO CLI | refused, nothing published: a tampered segment; an unlisted backend | refused: prove into an existing directory");
}

// ------------------------------------------------------------------ review round 4 (TR4-1 .. TR4-3), failing first

/// **REVIEW TR4-1, FAILING FIRST: `owner` verifies before it prints.** After
/// an honest publication one segment is flipped: `owner` must refuse (it
/// re-reads and re-verifies the run and compares `segments.json`). A
/// `statement/` the PROVER wrote (the unverified statement with its writer
/// line changed, no verifier ever ran) must be refused too.
#[test]
fn tr4_1_the_owner_verifies_before_it_prints_and_refuses_a_tampered_or_unverified_run() {
    let cli = Cli::new("tr4-1");
    let out = cli.root.join("run");
    assert_eq!(cli.prove(&out), 0);
    assert_eq!(cli.verify(&out), 0);
    assert_eq!(cli.owner(&out), 0, "the honest owner check");
    let seg = out.join(run_sink::segment_file_name(1));
    let mut b = std::fs::read(&seg).unwrap();
    let at = b.len() / 3;
    b[at] ^= 1;
    std::fs::write(&seg, &b).unwrap();
    assert_eq!(cli.owner(&out), 1, "REVIEW TR4-1: the owner printed a token over a run whose segment was flipped after publication");
    // the prover writes statement/ itself
    let out2 = cli.root.join("run2");
    assert_eq!(cli.prove(&out2), 0);
    let text = std::fs::read_to_string(sib(&out2, ".unverified-statement").join("statement.json")).unwrap();
    let forged = text.replace(
        "zk60_token_io prove, WITHOUT a verification (unverified: only zk60_token_io verify publishes a statement for this run)",
        "zk60_token_io verify, after its fresh-process verification of the run directory, from its own data and the hashes of the bytes it verified",
    );
    assert_ne!(forged, text);
    let sd = out2.join(run_sink::STATEMENT_DIR);
    std::fs::create_dir(&sd).unwrap();
    std::fs::write(sd.join("statement.json"), forged).unwrap();
    std::fs::write(sd.join("segments.json"), "[]\n").unwrap();
    assert_eq!(cli.owner(&out2), 1, "REVIEW TR4-1: the owner trusted a statement/ the prover wrote");
    eprintln!("TOKEN-IO CLI REVIEW TR4-1 | owner over a run flipped after publication: refused | owner over a prover-written statement/: refused");
}

/// **REVIEW TR4-2, FAILING FIRST: the token stages are pinned.** A run
/// proved with every head multiplier changed, handed to a verifier with
/// those tables, and one whose head manifest names half the Cn, are refused
/// under the approved token profile's pin; nothing is published.
#[test]
fn tr4_2_a_run_with_another_head_or_cn_is_refused_under_the_token_profile_pin() {
    let cli = Cli::new("tr4-2");
    // another head: every multiplier moved inside its class
    let mut t2 = cli.t.clone();
    for m in t2.mult.iter_mut() {
        *m = if *m == 4096 { 4095 } else { *m + 1 };
    }
    let tdir2 = cli.root.join("tables-other-head");
    write_token_tables(&tdir2, &t2, norm());
    let out = cli.root.join("run-other-head");
    assert_eq!(cli.prove_tables(&out, &tdir2), 0);
    assert_eq!(cli.verify_full(&cli.verifier_copy, &tdir2, &out, &cli.identity, &cli.token_profile), 1, "REVIEW TR4-2: a run with another head verified under the approved token profile's pin");
    assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "nothing published");
    // half the calibrated Cn
    let tdir3 = cli.root.join("tables-half-cn");
    write_token_tables(&tdir3, &cli.t, FinalNorm { cn: norm().cn / 2, ..norm() });
    let out3 = cli.root.join("run-half-cn");
    assert_eq!(cli.prove_tables(&out3, &tdir3), 0);
    assert_eq!(cli.verify_full(&cli.verifier_copy, &tdir3, &out3, &cli.identity, &cli.token_profile), 1, "REVIEW TR4-2: a run with half the Cn verified under the approved token profile's pin");
    assert!(!out3.join(run_sink::STATEMENT_DIR).exists(), "nothing published");
    eprintln!("TOKEN-IO CLI REVIEW TR4-2 | another head; half the Cn | refused under the token-profile pin, nothing published");
}

/// **REVIEW TR4-3, FAILING FIRST: the owners' decommitments go to a private
/// directory** (mode 0700, files 0600) named by `--owner-dir`, outside the
/// run's parent; an owner directory inside the run's parent is refused.
#[test]
fn tr4_3_the_owner_files_go_to_a_private_directory_outside_the_runs_parent() {
    use std::os::unix::fs::PermissionsExt;
    let cli = Cli::new("tr4-3");
    let out = cli.root.join("run");
    assert_eq!(cli.prove(&out), 0);
    let od = cli.owner_dir(&out);
    assert!(od.join("output.dec").is_file() && od.join("input.dec").is_file(), "REVIEW TR4-3: the decommitments are not in the given owner directory");
    assert_eq!(std::fs::metadata(&od).unwrap().permissions().mode() & 0o777, 0o700, "REVIEW TR4-3: the owner directory is not 0700");
    assert!(!sib(&out, ".owner-private").exists(), "REVIEW TR4-3: a sibling owner directory beside the run");
    let out2 = cli.root.join("run2");
    let inside = cli.root.join("owners-inside");
    let code = token_prove_command(&s(&["--export", cli.export.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--seq", "s0", "--prompt", &cli.prompt, "--out", out2.to_str().unwrap(), "--owner-dir", inside.to_str().unwrap()]));
    assert_eq!(code, 1, "REVIEW TR4-3: an owner directory inside the run's parent was accepted");
    assert!(!out2.exists() && !inside.exists(), "and nothing was written");
    eprintln!("TOKEN-IO CLI REVIEW TR4-3 | decommitments in the given owner directory (0700, files 0600), none beside the run; an owner directory inside the run's parent refused");
}

/// play a second prove that claims `dir` (as `prove` does) and writes its own
/// file there; true when it won the directory
fn rival_claims(dir: &Path, file: &str) -> bool {
    if std::fs::create_dir(dir).is_err() {
        return false;
    }
    std::fs::write(dir.join(file), b"the rival prove's file").unwrap();
    true
}

/// **REVIEW TR5-1, FAILING FIRST: a prove never removes an owner directory or
/// an unverified-statement directory it did not create.** A second prove
/// claims the directory in the window before the owners' files are written
/// (the test seam `hooks::BEFORE_OWNER_FILES`). Whichever prove wins, its
/// files must survive: the owner directory and the unverified statement
/// directory still exist afterwards with the winner's files in them.
#[test]
fn tr5_1_a_prove_never_removes_an_owner_or_statement_directory_it_did_not_create() {
    use super::cli::hooks::BEFORE_OWNER_FILES;
    use std::cell::Cell;
    use std::rc::Rc;
    let cli = Cli::new("tr5-1");
    for (case, which) in [("owner", 0usize), ("unverified", 1usize)] {
        let out = cli.root.join(format!("run-{case}"));
        let won = Rc::new(Cell::new(false));
        let w = won.clone();
        BEFORE_OWNER_FILES.with(|h| {
            *h.borrow_mut() = Some(Box::new(move |od: &Path, unverified: &Path| {
                let dir = if which == 0 { od } else { unverified };
                w.set(rival_claims(dir, "rival.txt"));
            }))
        });
        let code = cli.prove(&out);
        BEFORE_OWNER_FILES.with(|h| *h.borrow_mut() = None);
        let dir = if which == 0 { cli.owner_dir(&out) } else { sib(&out, ".unverified-statement") };
        assert!(dir.is_dir(), "REVIEW TR5-1 ({case}): the directory a rival prove created is GONE after this prove's error path");
        if won.get() {
            assert_ne!(code, 0, "{case}: the rival won the directory, this prove must refuse");
            assert!(dir.join("rival.txt").is_file(), "REVIEW TR5-1 ({case}): the rival's file was removed");
        } else {
            assert_eq!(code, 0, "{case}: this prove claimed the directory first and completes");
            let want = if which == 0 { "output.dec" } else { "statement.json" };
            assert!(dir.join(want).is_file(), "{case}: this prove's files are in place");
        }
    }
    // an owner directory that already exists (a finished rival): refused by
    // its claim, left as it was, and nothing of this prove is left behind
    let out = cli.root.join("run-existing");
    let od = cli.owner_dir(&out);
    assert!(rival_claims(&od, "input.dec"));
    assert_eq!(cli.prove(&out), 1, "an existing owner directory is refused");
    assert!(od.join("input.dec").is_file(), "the existing owner directory is untouched");
    assert!(!out.exists() && !sib(&out, ".incomplete").exists() && !sib(&out, ".unverified-statement").exists(), "nothing of the refused prove is left");
    eprintln!("TOKEN-IO CLI REVIEW TR5-1 | a rival prove racing for the owner / unverified-statement directory, or an existing owner directory: no prove removes a directory it did not create");
}

/// **REVIEW TR5-1, FAILING FIRST: the default owner directory is keyed by the
/// run's path**, not by its base name alone: two runs named alike in
/// different directories get different owner directories; the same run, the
/// same one.
#[test]
fn tr5_1_the_default_owner_directory_is_keyed_by_the_runs_path() {
    use super::cli::default_owner_dir;
    let cli = Cli::new("tr5-1-key");
    let base = cli.owners.join("base");
    std::fs::create_dir_all(&base).unwrap();
    let (p1, p2) = (cli.root.join("p1"), cli.root.join("p2"));
    std::fs::create_dir_all(&p1).unwrap();
    std::fs::create_dir_all(&p2).unwrap();
    let (d1, d2) = (default_owner_dir(&base, &p1.join("same")).unwrap(), default_owner_dir(&base, &p2.join("same")).unwrap());
    assert_ne!(d1, d2, "REVIEW TR5-1: two runs named `same` in different directories share one default owner directory");
    for d in [&d1, &d2] {
        assert_eq!(d.parent().unwrap(), base.as_path());
        let n = d.file_name().unwrap().to_string_lossy().to_string();
        assert!(n.starts_with("same-") && n.ends_with(".owner-private"), "{n}");
    }
    assert_eq!(default_owner_dir(&base, &p1.join("same")).unwrap(), d1, "the same run, the same directory");
    assert_eq!(default_owner_dir(&base, &cli.root.join("p1/../p1/same")).unwrap(), d1, "keyed by the canonical path");
    eprintln!("TOKEN-IO CLI REVIEW TR5-1 | the default owner directory is keyed by the run's canonical path");
}

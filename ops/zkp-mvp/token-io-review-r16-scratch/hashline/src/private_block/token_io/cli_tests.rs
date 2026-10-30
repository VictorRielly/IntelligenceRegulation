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
    /// ROUND 9: a counter naming each helper call's prompt / token file
    calls: std::cell::Cell<usize>,
}

/// **TOKEN ROUND 15 (REVIEW_R14 N-r14-4): where the next-token fixtures
/// write** — `TMPDIR` when it is set (the guarded runs set it to a directory
/// outside the repository), else `$HOME/zk60-artifacts/token-io/test-fixtures/`:
/// never `/tmp` by default (the classifier fixtures' rule, round 14 N-r13-9).
pub(super) fn next_token_fixture_root() -> PathBuf {
    fixture_root_from(std::env::var_os("TMPDIR"), std::env::var_os("HOME"))
}

/// [`next_token_fixture_root`] on given `TMPDIR` / `HOME` values (an empty
/// `TMPDIR` counts as unset)
pub(super) fn fixture_root_from(tmpdir: Option<std::ffi::OsString>, home: Option<std::ffi::OsString>) -> PathBuf {
    match tmpdir.filter(|d| !d.is_empty()) {
        Some(d) => PathBuf::from(d),
        None => PathBuf::from(home.expect("neither TMPDIR nor HOME is set: set TMPDIR to an absolute directory outside any git work tree")).join("zk60-artifacts").join("token-io").join("test-fixtures"),
    }
}

/// **N-r14-4:** the next-token fixtures default to
/// `~/zk60-artifacts/token-io/test-fixtures/` when `TMPDIR` is unset (or
/// empty), and take `TMPDIR` when set; and no next-token test file still
/// takes its fixture root from the standard library's temporary directory
/// (which is `/tmp` without TMPDIR).
#[test]
fn r15_the_next_token_fixtures_default_off_tmp_when_tmpdir_is_unset() {
    let home = || Some(std::ffi::OsString::from("/home/someone"));
    let want = PathBuf::from("/home/someone/zk60-artifacts/token-io/test-fixtures");
    assert_eq!(fixture_root_from(None, home()), want, "TMPDIR unset");
    assert_eq!(fixture_root_from(Some("".into()), home()), want, "TMPDIR empty");
    assert_eq!(fixture_root_from(Some("/x/tmp-r15".into()), home()), PathBuf::from("/x/tmp-r15"), "TMPDIR set");
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("src/private_block/token_io");
    for f in ["cli_tests.rs", "r3_tests.rs"] {
        let src = std::fs::read_to_string(dir.join(f)).unwrap();
        let call = ["std::env::", "temp_dir()"].concat();
        assert!(!src.contains(&call), "{f} still takes its fixture root from the standard library's temporary directory (/tmp without TMPDIR)");
    }
}

impl Cli {
    fn new(tag: &str) -> Cli {
        Cli::new_with(tag, &Fault::default())
    }
    /// the CLI fixture over an export written with `fault`
    fn new_with(tag: &str, fault: &Fault) -> Cli {
        // N-r14-4 (round 15): TMPDIR, else ~/zk60-artifacts/token-io/test-fixtures/ (never /tmp by default)
        let root = next_token_fixture_root().join(format!("tio-cli-{tag}-{}", std::process::id()));
        let owners = next_token_fixture_root().join(format!("tio-cli-owners-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let _ = std::fs::remove_dir_all(&owners);
        std::fs::create_dir_all(&root).unwrap();
        std::fs::create_dir_all(&owners).unwrap();
        let (export, _) = write_export(&root, "tiny", fault);
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
        Cli { root, owners, export, verifier_copy, tables, prompt, identity: hex(&p.model.identity()), token_profile, want_token, t, calls: std::cell::Cell::new(0) }
    }
    /// ROUND 9 (PR4-17): a prompt file of `text` with `mode`
    fn prompt_file(&self, name: &str, text: &str, mode: u32) -> PathBuf {
        use std::io::Write;
        use std::os::unix::fs::OpenOptionsExt;
        let p = self.owners.join(format!("{name}.prompt"));
        let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(mode).open(&p).unwrap();
        f.write_all(text.as_bytes()).unwrap();
        p
    }
    /// ROUND 9: a prove reading the prompt from a 0600 file; `(exit code,
    /// run headers the prover built)`
    fn prove_file(&self, export: &Path, seq: &[&str], out: &Path, name: &str) -> (i32, u64) {
        let pf = self.prompt_file(name, &self.prompt, 0o600);
        let od = self.owner_dir(out);
        let mut args = vec!["--export", export.to_str().unwrap(), "--emb", self.tables.to_str().unwrap(), "--head", self.tables.to_str().unwrap()];
        args.extend_from_slice(seq);
        args.extend_from_slice(&["--prompt-file", pf.to_str().unwrap(), "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]);
        let h0 = super::run::run_headers();
        let code = token_prove_command(&s(&args));
        (code, super::run::run_headers() - h0)
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
    /// the next unique helper file name
    fn next(&self, what: &str) -> String {
        self.calls.set(self.calls.get() + 1);
        format!("{what}-{}", self.calls.get())
    }
    fn prove_tables(&self, out: &Path, tables: &Path) -> i32 {
        let od = self.owner_dir(out);
        // PR4-17: the prompt from a 0600 file, never the command line
        let pf = self.prompt_file(&self.next("prove"), &self.prompt, 0o600);
        token_prove_command(&s(&["--export", self.export.to_str().unwrap(), "--emb", tables.to_str().unwrap(), "--head", tables.to_str().unwrap(), "--seq", "s0", "--prompt-file", pf.to_str().unwrap(), "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]))
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
        token_input_owner_command(&s(&["--export", self.verifier_copy.to_str().unwrap(), "--emb", self.tables.to_str().unwrap(), "--head", self.tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", &self.identity, "--expect-token-profile", &self.token_profile, "--decommitment", dec.to_str().unwrap(), "--prompt-file", self.prompt_file(&self.next("input-owner"), prompt, 0o600).to_str().unwrap(), "--min-bits", "93"]))
    }
    fn owner(&self, out: &Path) -> i32 {
        let dec = self.dec(out, "output.dec");
        token_owner_command(&s(&["--export", self.verifier_copy.to_str().unwrap(), "--emb", self.tables.to_str().unwrap(), "--head", self.tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", &self.identity, "--expect-token-profile", &self.token_profile, "--decommitment", dec.to_str().unwrap(), "--min-bits", "93", "--token-out", self.owners.join(self.next("token")).to_str().unwrap()]))
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
    let pf = cli.prompt_file("tr4-3", &cli.prompt, 0o600);
    let code = token_prove_command(&s(&["--export", cli.export.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--seq", "s0", "--prompt-file", pf.to_str().unwrap(), "--out", out2.to_str().unwrap(), "--owner-dir", inside.to_str().unwrap()]));
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

fn od_flag(p: &Path) -> Vec<(String, String)> {
    vec![("--owner-dir".to_string(), p.to_str().unwrap().to_string())]
}

/// **REVIEW TR5-3 (a), FAILING FIRST: an explicit owner directory inside a
/// git working tree is refused**, by name: the canonical path's ancestors are
/// walked for a `.git` entry (a directory, or a worktree's `.git` file), so
/// the owners' decommitments never land in a repository; nothing is written.
/// The same directory name outside any working tree is accepted.
#[test]
fn tr5_3_a_an_explicit_owner_dir_inside_a_git_working_tree_is_refused() {
    use super::cli::owner_dir_at;
    let cli = Cli::new("tr5-3a");
    let repo = cli.owners.join("a-repo");
    std::fs::create_dir_all(repo.join(".git")).unwrap();
    // TR6-3: a repository by git's own rule (`HEAD` in `.git`)
    std::fs::write(repo.join(".git").join("HEAD"), "ref: refs/heads/main\n").unwrap();
    std::fs::create_dir_all(repo.join("sub")).unwrap();
    let od = repo.join("sub").join("run.owner-private");
    let out = cli.root.join("run");
    let pf = cli.prompt_file("tr5-3a", &cli.prompt, 0o600);
    let code = token_prove_command(&s(&["--export", cli.export.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--seq", "s0", "--prompt-file", pf.to_str().unwrap(), "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]));
    assert_eq!(code, 1, "REVIEW TR5-3 (a): an owner directory inside a git working tree was accepted");
    assert!(!od.exists() && !out.exists() && !sib(&out, ".incomplete").exists() && !sib(&out, ".unverified-statement").exists(), "and nothing was written");
    let e = owner_dir_at(&od_flag(&od), &out, None).unwrap_err();
    let canon_repo = std::fs::canonicalize(&repo).unwrap();
    assert!(e.contains(".git") && e.contains(canon_repo.to_str().unwrap()), "the refusal names the working tree: {e}");
    // a worktree's `.git` FILE marks a working tree too
    let wt = cli.owners.join("a-worktree");
    std::fs::create_dir_all(&wt).unwrap();
    std::fs::write(wt.join(".git"), "gitdir: /elsewhere/.git/worktrees/x\n").unwrap();
    assert!(owner_dir_at(&od_flag(&wt.join("x.owner-private")), &out, None).unwrap_err().contains(".git"), "a worktree's .git file");
    // outside any working tree: accepted
    let plain = cli.owners.join("plain.owner-private");
    assert_eq!(owner_dir_at(&od_flag(&plain), &out, None).unwrap(), plain);
    eprintln!("TOKEN-IO CLI REVIEW TR5-3 (a) | an explicit owner directory inside a git working tree (.git directory or file) refused by name, nothing written");
}

/// **REVIEW TR5-3 (b), FAILING FIRST: the default owner directory is accepted
/// for a run directly under `$HOME`** (the run's parent is then an ancestor of
/// `$HOME/zk60-owner-private/token-io` since PR4-16, which the parent rule
/// refused). Still
/// refused: a run inside that base directory itself (its owners' directories
/// would sit beside it), and an explicit owner directory inside the run's
/// parent.
#[test]
fn tr5_3_b_the_default_owner_dir_is_accepted_for_a_run_directly_under_home() {
    use super::cli::owner_dir_at;
    let cli = Cli::new("tr5-3b");
    let home = cli.owners.join("home");
    std::fs::create_dir_all(&home).unwrap();
    let out = home.join("run");
    let od = owner_dir_at(&[], &out, Some(&home)).unwrap_or_else(|e| panic!("REVIEW TR5-3 (b): the default owner directory was refused for a run directly under $HOME: {e}"));
    // PR4-16: the owners' base is its own tree
    let base = std::fs::canonicalize(home.join("zk60-owner-private").join("token-io")).unwrap();
    assert_eq!(std::fs::canonicalize(od.parent().unwrap()).unwrap(), base, "the default lives in the base directory");
    assert!(owner_dir_at(&[], &home.join("zk60-owner-private").join("token-io").join("run"), Some(&home)).is_err(), "a run inside the base directory is refused");
    assert!(owner_dir_at(&od_flag(&home.join("x.owner-private")), &out, Some(&home)).is_err(), "an explicit owner directory inside the run's parent is refused");
    eprintln!("TOKEN-IO CLI REVIEW TR5-3 (b) | the default owner directory accepted for a run directly under $HOME; a run inside the base, or an explicit directory in the run's parent, refused");
}


/// **REVIEW TR6-3, FAILING FIRST: the DEFAULT owner directory is checked for
/// a git working tree too** (a `$HOME` that is itself a repository, e.g.
/// dotfiles), by git's own rule: a `.git` directory holding `HEAD`, or a
/// `.git` file starting `gitdir:`. A stub `.git` without `HEAD` (what this
/// box's real `$HOME` holds: `info/` only), which git walks past, does not
/// count, for the default or an explicit directory.
#[test]
fn tr6_3_the_default_owner_directory_is_checked_for_a_git_working_tree() {
    use super::cli::owner_dir_at;
    let cli = Cli::new("tr6-3");
    let home = cli.owners.join("home-repo");
    std::fs::create_dir_all(home.join(".git")).unwrap();
    std::fs::write(home.join(".git").join("HEAD"), "ref: refs/heads/main\n").unwrap();
    std::fs::create_dir_all(home.join("runs")).unwrap();
    let e = owner_dir_at(&[], &home.join("runs").join("run"), Some(&home)).err().unwrap_or_else(|| panic!("REVIEW TR6-3: the default owner directory inside a git working tree ($HOME a repository) was accepted"));
    assert!(e.contains("git working tree") && e.contains("TR6-3"), "the refusal names the rule: {e}");
    // a `$HOME` holding a `.git` FILE (a worktree): refused too
    let home_wt = cli.owners.join("home-worktree");
    std::fs::create_dir_all(home_wt.join("runs")).unwrap();
    std::fs::write(home_wt.join(".git"), "gitdir: /elsewhere/.git/worktrees/h\n").unwrap();
    assert!(owner_dir_at(&[], &home_wt.join("runs").join("run"), Some(&home_wt)).is_err(), "REVIEW TR6-3: a $HOME holding a worktree's .git file");
    // a stub `.git` without HEAD (git's rule: not a repository): accepted
    let home_stub = cli.owners.join("home-stub");
    std::fs::create_dir_all(home_stub.join(".git").join("info")).unwrap();
    std::fs::create_dir_all(home_stub.join("runs")).unwrap();
    let out = home_stub.join("runs").join("run");
    owner_dir_at(&[], &out, Some(&home_stub)).expect("a stub .git without HEAD is not a repository: the default is accepted");
    let ex = home_stub.join("owners").join("run.owner-private");
    std::fs::create_dir_all(ex.parent().unwrap()).unwrap();
    assert_eq!(owner_dir_at(&od_flag(&ex), &out, Some(&home_stub)).unwrap(), ex, "and so is an explicit directory beside it");
    eprintln!("TOKEN-IO CLI REVIEW TR6-3 | the default owner directory inside a git working tree refused (a .git directory with HEAD, or a .git file); a stub .git without HEAD accepted for both");
}

// ------------------------------------------------------------------ ROUND 9: privacy review round 4

fn nothing_of(out: &Path, od: &Path) -> bool {
    !out.exists() && !sib(out, ".incomplete").exists() && !sib(out, ".unverified-statement").exists() && !od.exists()
}

/// **PR4-4, FAILING FIRST: parity is checked in the SEALING PASS.** An export
/// whose `x_out_L00` differs from the builder's output in one word (row 0,
/// so the export's last row and the next token are untouched): the CLI's
/// prove refuses BEFORE any header; nothing is left.
#[test]
fn pr4_4_a_parity_mismatch_is_refused_before_the_header() {
    let cli = Cli::new_with("pr4-4-parity", &Fault { x_out_flip: true, ..Default::default() });
    let out = cli.root.join("run");
    let (code, headers) = cli.prove_file(&cli.export, &["--seq", "s0"], &out, "parity");
    assert_eq!(code, 1, "a parity mismatch was not refused");
    assert_eq!(headers, 0, "PR4-4: the parity mismatch was refused only AFTER the run header was built");
    assert!(nothing_of(&out, &cli.owner_dir(&out)), "a refused prove left a directory");
    eprintln!("TOKEN-IO CLI PR4-4 | a parity mismatch refused before the header");
}

/// **PR4-4, FAILING FIRST: the builder's refusals and the int16 range are
/// in the SEALING PASS.** A prover-private sequence directory whose input
/// plane is extreme (every word 30,000; the tables embed the prompt to it,
/// so stage IN admits it) and whose `x_out` is the honest one: whatever the
/// builder makes of it (a refusal, an output outside int16, or a parity
/// mismatch), the prove refuses BEFORE any header; nothing is left.
#[test]
fn pr4_4_an_extreme_input_is_refused_before_the_header() {
    let mut cli = Cli::new("pr4-4-extreme");
    let sh = TrainedExport::load(&cli.export).unwrap();
    let c = sh.run_constants(&sh.layers).unwrap();
    let shape = sh.shape_for(&c).unwrap();
    let seq = cli.owners.join("seq-extreme");
    std::fs::create_dir_all(&seq).unwrap();
    let src = cli.export.join("seq_s0");
    let xin_old = std::fs::read(src.join("x_in_L00.bin")).unwrap();
    let xin_new: Vec<u8> = (0..xin_old.len() / 2).flat_map(|_| 30_000i16.to_le_bytes()).collect();
    std::fs::write(seq.join("x_in_L00.bin"), &xin_new).unwrap();
    std::fs::copy(src.join("x_out_L00.bin"), seq.join("x_out_L00.bin")).unwrap();
    let man = std::fs::read_to_string(src.join("manifest.json")).unwrap().replace(&crate::export_v3::sha256_hex(&xin_old), &crate::export_v3::sha256_hex(&xin_new));
    std::fs::write(seq.join("manifest.json"), man).unwrap();
    // tables embedding every prompt id to the extreme row
    let mut t = cli.t.clone();
    for id in 1..=shape.tokens {
        for i in 0..t.d {
            t.emb[id * t.d + i] = 30_000;
        }
    }
    let tables = cli.root.join("tables-extreme");
    write_token_tables(&tables, &t, norm());
    cli.tables = tables;
    let out = cli.root.join("run");
    let (code, headers) = cli.prove_file(&cli.export, &["--seq-dir", seq.to_str().unwrap()], &out, "extreme");
    assert_eq!(code, 1, "an extreme input was not refused");
    assert_eq!(headers, 0, "PR4-4: the extreme input was refused only AFTER the run header was built");
    assert!(nothing_of(&out, &cli.owner_dir(&out)), "a refused prove left a directory");
    eprintln!("TOKEN-IO CLI PR4-4 | an extreme input refused before the header");
}

/// **PR4-4, FAILING FIRST: the CLI's sealing pass runs CS-3 on every witness
/// and the next token comes from the BUILDER's chain** (the source, as native
/// r6_tests reads the trained CLI's): `seal_chain` builds each witness,
/// checks int16, parity and `check_lookup_misses`, and `prove_inner` takes
/// the last row from it before calling the prover.
#[test]
fn pr4_4_the_cli_sealing_pass_runs_cs3_and_takes_the_token_from_the_builder() {
    let src = include_str!("cli.rs");
    let at = src.find("fn seal_chain(").expect("PR4-4: the token CLI has no sealing pass (`seal_chain`)");
    let seal = &src[at..at + src[at..].find("\n}\n").unwrap()];
    for want in ["build_shaped(", "i16::try_from", "parity", "check_lookup_misses(&ssh, &lay, &blk, &w)"] {
        assert!(seal.contains(want), "PR4-4: the sealing pass does not contain `{want}`");
    }
    let at = src.find("fn prove_inner(").unwrap();
    let prove = &src[at..at + src[at..].find("\n}\n").unwrap()];
    let (sealed, proved) = (prove.find("let x_last = seal_chain(").expect("PR4-4: the next token is not computed from the builder's chain"), prove.find("prove_token_run_with(").unwrap());
    assert!(sealed < proved, "the sealing pass does not run before the prover");
    assert!(!prove.contains("let x_last = seq.load("), "PR4-4: the next token is still taken from the export's reference");
}

/// **PR4-15, FAILING FIRST: a killed run's leftovers are refused BY NAME,
/// and a refused run says what it removed.** A `<out>.incomplete/` holding a
/// partial segment: the next prove refuses, leaves it untouched, and the
/// refusal names it, says how to clear it and the sync rule. A prove refused
/// after its directories were claimed reports each one it removed.
#[test]
fn pr4_15_leftovers_are_refused_by_name_and_removals_are_reported() {
    use super::cli::{leftover_refusal, removals};
    let cli = Cli::new("pr4-15");
    let out = cli.root.join("run");
    let inc = sib(&out, ".incomplete");
    std::fs::create_dir_all(&inc).unwrap();
    std::fs::write(inc.join("segment-000.bin"), b"a killed prove's partial segment").unwrap();
    let (code, _) = cli.prove_file(&cli.export, &["--seq", "s0"], &out, "leftover");
    assert_eq!(code, 1, "a prove over a leftover <out>.incomplete/ was not refused");
    assert!(inc.join("segment-000.bin").is_file(), "the leftover was touched");
    let msg = leftover_refusal(&inc, "a token run's directories");
    for want in [inc.to_str().unwrap(), "rm -r", "killed", "never sync"] {
        assert!(msg.contains(want), "PR4-15: the leftover refusal does not say `{want}`: {msg}");
    }
    let cli2 = Cli::new_with("pr4-15-removed", &Fault { x_out_flip: true, ..Default::default() });
    let out2 = cli2.root.join("run");
    let before = removals().len();
    let (code, _) = cli2.prove_file(&cli2.export, &["--seq", "s0"], &out2, "removed");
    assert_eq!(code, 1);
    let r = removals()[before..].to_vec();
    for d in [sib(&out2, ".incomplete"), sib(&out2, ".unverified-statement"), cli2.owner_dir(&out2)] {
        assert!(r.contains(&d.display().to_string()), "PR4-15: the refused prove did not report removing {}: {r:?}", d.display());
    }
    eprintln!("TOKEN-IO CLI PR4-15 | a leftover refused by name ({msg}); a refused prove reported {} removals", r.len());
}

/// **PR4-16, FAILING FIRST: the owners' default base is its own tree**,
/// `$HOME/zk60-owner-private/token-io/` (both levels 0700), never inside the
/// artifacts tree that holds captures.
#[test]
fn pr4_16_the_default_owner_base_is_outside_the_artifacts_tree() {
    use super::cli::owner_dir_at;
    use std::os::unix::fs::PermissionsExt;
    let cli = Cli::new("pr4-16");
    let home = cli.owners.join("home");
    std::fs::create_dir_all(home.join("runs")).unwrap();
    let od = owner_dir_at(&[], &home.join("runs").join("run"), Some(&home)).unwrap();
    let base = home.join("zk60-owner-private");
    assert_eq!(std::fs::canonicalize(od.parent().unwrap()).unwrap(), std::fs::canonicalize(base.join("token-io")).unwrap_or_default(), "PR4-16: the default owner directory {} is not under {}/token-io", od.display(), base.display());
    for d in [base.clone(), base.join("token-io")] {
        assert_eq!(std::fs::metadata(&d).unwrap().permissions().mode() & 0o777, 0o700, "{} is not 0700", d.display());
    }
    assert!(!home.join("zk60-artifacts").exists(), "PR4-16: the default owner base made the artifacts tree");
}

/// **PR4-17, FAILING FIRST: the hidden prompt never goes on the command
/// line.** `--prompt` is refused (exit 2); a prompt file readable by others
/// (0644) is refused; a 0600 file is accepted.
#[test]
fn pr4_17_the_prompt_never_goes_on_the_command_line() {
    let cli = Cli::new("pr4-17-prompt");
    let out = cli.root.join("run-cli");
    let od = cli.owner_dir(&out);
    let code = token_prove_command(&s(&["--export", cli.export.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--seq", "s0", "--prompt", &cli.prompt, "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]));
    assert_eq!(code, 2, "PR4-17: a prompt on the command line was accepted");
    assert!(nothing_of(&out, &od));
    let out = cli.root.join("run-644");
    let od = cli.owner_dir(&out);
    let pf = cli.prompt_file("p644", &cli.prompt, 0o644);
    let code = token_prove_command(&s(&["--export", cli.export.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--seq", "s0", "--prompt-file", pf.to_str().unwrap(), "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]));
    assert_eq!(code, 1, "PR4-17: a prompt file readable by others was accepted");
    assert!(nothing_of(&out, &od));
    let out = cli.root.join("run-600");
    let (code, headers) = cli.prove_file(&cli.export, &["--seq", "s0"], &out, "p600");
    assert_eq!((code, headers), (0, 1), "a 0600 prompt file");
    eprintln!("TOKEN-IO CLI PR4-17 | --prompt refused (exit 2), a 0644 prompt file refused, a 0600 file proves");
}

/// **PR4-17, FAILING FIRST: the owner writes the token to a 0600 file**
/// (`--token-out`) and prints it on stdout only with `--print`.
#[test]
fn pr4_17_the_owner_writes_the_token_to_a_0600_file() {
    use std::os::unix::fs::PermissionsExt;
    let cli = Cli::new("pr4-17-owner");
    let out = cli.root.join("run");
    let (code, _) = cli.prove_file(&cli.export, &["--seq", "s0"], &out, "owner");
    assert_eq!(code, 0);
    assert_eq!(cli.verify(&out), 0);
    let dec = cli.dec(&out, "output.dec");
    for (name, print) in [("tok-quiet", false), ("tok-print", true)] {
        let tf = cli.owners.join(name);
        let mut args = vec!["--export", cli.verifier_copy.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", &cli.identity, "--expect-token-profile", &cli.token_profile, "--decommitment", dec.to_str().unwrap(), "--min-bits", "93", "--token-out", tf.to_str().unwrap()];
        if print {
            args.push("--print");
        }
        assert_eq!(token_owner_command(&s(&args)), 0, "PR4-17: the owner with --token-out ({name})");
        assert_eq!(std::fs::metadata(&tf).unwrap().permissions().mode() & 0o777, 0o600, "PR4-17: the token file is not 0600");
        assert_eq!(std::fs::read_to_string(&tf).unwrap().trim(), cli.want_token.to_string(), "the token file holds the next token");
    }
    eprintln!("TOKEN-IO CLI PR4-17 | the owner writes the token to a 0600 file (printed only with --print)");
}

// ------------------------------------------------------------------ ROUND 11: review REVIEW6

/// **REVIEW TR7-6, FAILING FIRST: `owner` refuses an existing token file
/// BEFORE re-verifying** (the full re-check takes ~80 s at 8B). An explicit
/// `--token-out` that exists and the default `next_token` beside the
/// decommitment that exists are each refused with no re-verification started
/// and the file untouched; a fresh path re-verifies once and is written.
#[test]
fn tr7_6_owner_refuses_an_existing_token_file_before_re_verifying() {
    use super::cli::check_runs;
    let cli = Cli::new("tr7-6");
    let out = cli.root.join("run");
    let (code, _) = cli.prove_file(&cli.export, &["--seq", "s0"], &out, "tr7-6");
    assert_eq!(code, 0);
    assert_eq!(cli.verify(&out), 0);
    let dec = cli.dec(&out, "output.dec");
    let owner_args = |token_out: Option<&Path>| -> Vec<String> {
        let mut a = vec!["--export", cli.verifier_copy.to_str().unwrap(), "--emb", cli.tables.to_str().unwrap(), "--head", cli.tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", &cli.identity, "--expect-token-profile", &cli.token_profile, "--decommitment", dec.to_str().unwrap(), "--min-bits", "93"]
            .into_iter()
            .map(String::from)
            .collect::<Vec<String>>();
        if let Some(t) = token_out {
            a.push("--token-out".into());
            a.push(t.to_str().unwrap().into());
        }
        a
    };
    // an explicit --token-out that exists
    let tf = cli.owners.join("tok-exists");
    std::fs::write(&tf, b"an earlier token\n").unwrap();
    let before = check_runs();
    assert_eq!(token_owner_command(&owner_args(Some(&tf))), 1, "an existing --token-out was not refused");
    assert_eq!(check_runs(), before, "REVIEW TR7-6: the owner re-verified BEFORE refusing the existing --token-out");
    assert_eq!(std::fs::read(&tf).unwrap(), b"an earlier token\n", "the existing token file was touched");
    // the default path, `next_token` beside the decommitment, that exists
    let def = dec.parent().unwrap().join("next_token");
    std::fs::write(&def, b"an earlier token\n").unwrap();
    let before = check_runs();
    assert_eq!(token_owner_command(&owner_args(None)), 1, "an existing default token file was not refused");
    assert_eq!(check_runs(), before, "REVIEW TR7-6: the owner re-verified BEFORE refusing the existing default token file");
    std::fs::remove_file(&def).unwrap();
    // control: a fresh path re-verifies once and is written
    let fresh = cli.owners.join("tok-fresh");
    let before = check_runs();
    assert_eq!(token_owner_command(&owner_args(Some(&fresh))), 0);
    assert_eq!(check_runs(), before + 1, "the owner's full re-verification");
    assert_eq!(std::fs::read_to_string(&fresh).unwrap().trim(), cli.want_token.to_string());
    eprintln!("TOKEN-IO CLI REVIEW TR7-6 | an existing token file (explicit or default) refused with no re-verification; a fresh one re-verified once and written");
}

/// **REVIEW TR7-7, FAILING FIRST: a pre-existing owner base with a looser
/// mode is TIGHTENED to 0700** (both levels, `$HOME/zk60-owner-private` and
/// its `token-io/`), on use, and said so on stdout; a base that is not a
/// directory is refused.
#[test]
fn tr7_7_a_looser_pre_existing_owner_base_is_tightened_to_0700() {
    use super::cli::owner_dir_at;
    use std::os::unix::fs::PermissionsExt;
    let cli = Cli::new("tr7-7");
    let home = cli.owners.join("home-loose");
    let (top, base) = (home.join("zk60-owner-private"), home.join("zk60-owner-private").join("token-io"));
    std::fs::create_dir_all(&base).unwrap();
    std::fs::set_permissions(&top, std::fs::Permissions::from_mode(0o755)).unwrap();
    std::fs::set_permissions(&base, std::fs::Permissions::from_mode(0o750)).unwrap();
    std::fs::create_dir_all(home.join("runs")).unwrap();
    owner_dir_at(&[], &home.join("runs").join("run"), Some(&home)).expect("the default owner directory under a loose pre-existing base");
    for d in [&top, &base] {
        assert_eq!(std::fs::metadata(d).unwrap().permissions().mode() & 0o777, 0o700, "REVIEW TR7-7: the pre-existing base {} was left looser than 0700", d.display());
    }
    // a base that is a file, not a directory: refused
    let home2 = cli.owners.join("home-file");
    std::fs::create_dir_all(home2.join("runs")).unwrap();
    std::fs::write(home2.join("zk60-owner-private"), b"not a directory").unwrap();
    assert!(owner_dir_at(&[], &home2.join("runs").join("run"), Some(&home2)).is_err(), "a base that is a file was accepted");
    eprintln!("TOKEN-IO CLI REVIEW TR7-7 | a pre-existing owner base at 0755 / 0750 tightened to 0700 at both levels; a base that is a file refused");
}

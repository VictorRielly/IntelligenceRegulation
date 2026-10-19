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

use super::cli::{token_owner_command, token_prove_command, token_verify_command};
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
    export: PathBuf,
    verifier_copy: PathBuf,
    tables: PathBuf,
    prompt: String,
    identity: String,
    want_token: usize,
}

impl Cli {
    fn new(tag: &str) -> Cli {
        let root = std::env::temp_dir().join(format!("tio-cli-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).unwrap();
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
        let prompt = tokens.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",");
        Cli { root, export, verifier_copy, tables, prompt, identity: hex(&p.model.identity()), want_token }
    }
    fn prove(&self, out: &Path) -> i32 {
        token_prove_command(&s(&["--export", self.export.to_str().unwrap(), "--emb", self.tables.to_str().unwrap(), "--head", self.tables.to_str().unwrap(), "--seq", "s0", "--prompt", &self.prompt, "--out", out.to_str().unwrap()]))
    }
    fn verify_with(&self, export: &Path, out: &Path, pin: &str) -> i32 {
        token_verify_command(&s(&["--export", export.to_str().unwrap(), "--emb", self.tables.to_str().unwrap(), "--head", self.tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", pin, "--min-bits", "93"]))
    }
    fn verify(&self, out: &Path) -> i32 {
        self.verify_with(&self.verifier_copy, out, &self.identity)
    }
    fn owner(&self, out: &Path) -> i32 {
        let dec = sib(out, ".owner-private").join("output.dec");
        token_owner_command(&s(&["--export", self.verifier_copy.to_str().unwrap(), "--emb", self.tables.to_str().unwrap(), "--head", self.tables.to_str().unwrap(), "--artifact", out.to_str().unwrap(), "--expect-statement", &self.identity, "--decommitment", dec.to_str().unwrap()]))
    }
}

impl Drop for Cli {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.root);
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
    let dec = sib(&out, ".owner-private").join("output.dec");
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

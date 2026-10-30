//! **TOKEN I/O ROUND 18: THE A5 ONE-LOAD BATCH (`zk60_classify prove-batch`),
//! ADOPTED FROM ASTRA'S STAGED CANDIDATE.** TEST CODE ONLY. A child of the
//! batch module (`classify_batch.rs`, registered by one `#[cfg(test)]
//! #[path]` line at its end), so these tests reach the batch's private items,
//! and, through `classify_cli_tests`, the development rung's classifier
//! fixture (`Cc`: the tiny export, L = 1, T = 32, chunk size 23, overlap 4).
//! The batch runs here under the rung's [`Spec`] (`RUNG`); the CLI admits only
//! the Shieldstral T128 one (`SHIELD_T128`), checked below by name.
//!
//! * **REVIEW A5 finding 1 (Fix 1).** A batch whose job 1 is refused before
//!   its header (an empty activation directory, the review's §4.3 step 10)
//!   leaves NOTHING: no run directory, `.incomplete`, `.unverified-statement`
//!   or owner directory (with its `input.dec`) of job 0 either. Failing first
//!   on Astra's staged code (job 0's three directories stayed).
//! * **One post per process** (the coordinator's reading of rule 3): a second
//!   `--content-file` (or any repeated flag) is refused before anything is
//!   read. Failing first (the staged code took the first and ignored the rest).
//! * A complete rung batch proves every job; each receipt verifies in the
//!   verifier's own pass, the input owner's check holds on the whole content,
//!   and the category label over both chunks is accepted (`--expect-total`).
//! * The production command refuses the rung post (the fixed policy list and
//!   profile) and creates nothing.
//! * REVIEW A5 note 7: the request reader refuses a symlink and a FIFO, and
//!   the FIFO is refused without blocking.
//! * **The byte-identity rule at the rung, under FIXED TEST ENTROPY** (ignored;
//!   run only under `r18/tools/run_fixed.sh`): the batch's receipts,
//!   unverified statements and `input.dec` equal two single proves' byte for
//!   byte when each proof is handed the same two 32-byte blocks.

use super::*;
use super::super::super::classify_cli_tests::{Cc, POLICY_RUNG_DEV};
use super::super::super::super::trained_block::sha256;
use std::path::{Path, PathBuf};

/// the development rung's batch spec (test only): its run profile, T = 32 and
/// its one policy
const RUNG: Spec = Spec { profile: RUN_PROFILE_CLASSIFY_RUNG_TC, tokens: 32, policies: &[POLICY_RUNG_DEV] };

fn s(v: &[&str]) -> Vec<String> {
    v.iter().map(|x| x.to_string()).collect()
}

fn sib(p: &Path, suffix: &str) -> PathBuf {
    let mut s = p.as_os_str().to_owned();
    s.push(suffix);
    PathBuf::from(s)
}

fn write_0600(path: &Path, bytes: &[u8]) {
    use std::io::Write;
    use std::os::unix::fs::OpenOptionsExt;
    let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(path).unwrap();
    f.write_all(bytes).unwrap();
}

/// one rung post of 27 ids (two chunks: [0, 23) and [4, 27)) with its
/// prover-private activations per chunk and a batch request; the runs under
/// the fixture root, the owners, activations, content and request under the
/// owners' directory
struct Post {
    whole: String,
    content: PathBuf,
    request: PathBuf,
    outs: Vec<PathBuf>,
    owners: Vec<PathBuf>,
    seqs: Vec<PathBuf>,
}

impl Post {
    /// `empty_job`: that job's activation directory exists and is EMPTY (the
    /// review's step 10: it passes the batch's preflight and is refused by
    /// the job itself, before its header)
    fn new(cc: &Cc, tag: &str, empty_job: Option<usize>) -> Post {
        let whole = format!("{},33,34,35,36", cc.content);
        let p = policy_rung_dev();
        let ids: Vec<u64> = whole.split(',').map(|x| x.parse().unwrap()).collect();
        assert_eq!(ids.len(), 27);
        let items = [item_tokens(&p, &ids[0..23]), item_tokens(&p, &ids[4..27])];
        let content = cc.content_file(&whole);
        let (mut outs, mut owners, mut seqs) = (Vec::new(), Vec::new(), Vec::new());
        for (i, item) in items.iter().enumerate() {
            assert_eq!(item.len(), 32);
            let out = cc.root.join(format!("{tag}-c{i}"));
            let seq = cc.owners.join(format!("{tag}-seq-c{i}"));
            if empty_job == Some(i) {
                std::fs::create_dir(&seq).unwrap();
            } else {
                cc.write_seq_dir(&seq, item);
            }
            owners.push(cc.owner_dir(&out));
            outs.push(out);
            seqs.push(seq);
        }
        let jobs: Vec<String> = (0..2)
            .map(|i| format!("{{\"name\": \"c{i}\", \"policy_id\": {}, \"chunk_index\": {i}, \"sequence_dir\": {}, \"out\": {}, \"owner_dir\": {}}}", js(POLICY_RUNG_DEV), js(seqs[i].to_str().unwrap()), js(outs[i].to_str().unwrap()), js(owners[i].to_str().unwrap())))
            .collect();
        let request = cc.owners.join(format!("{tag}-batch-request.json"));
        let body = format!("{{\"schema\": \"zk60-classify-prove-batch/1\", \"expect_statement\": {}, \"content_total\": 27, \"jobs\": [{}]}}", js(&cc.identity), jobs.join(", "));
        write_0600(&request, body.as_bytes());
        Post { whole, content, request, outs, owners, seqs }
    }
    fn args(&self, cc: &Cc) -> Vec<String> {
        s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--content-file", self.content.to_str().unwrap(), "--batch-file", self.request.to_str().unwrap()])
    }
    /// every path a job of this post may create, with whether it exists
    fn created(&self) -> Vec<(PathBuf, bool)> {
        let mut v = Vec::new();
        for (out, owner) in self.outs.iter().zip(&self.owners) {
            for p in [out.clone(), sib(out, ".incomplete"), sib(out, ".unverified-statement"), owner.clone()] {
                let e = std::fs::symlink_metadata(&p).is_ok();
                v.push((p, e));
            }
        }
        v
    }
}

/// the names in a directory that start with `tag`
fn named(dir: &Path, tag: &str) -> Vec<String> {
    let mut v: Vec<String> = std::fs::read_dir(dir).unwrap().map(|e| e.unwrap().file_name().to_string_lossy().into_owned()).filter(|n| n.starts_with(tag)).collect();
    v.sort();
    v
}

// ------------------------------------------------------------------ Fix 1

/// **REVIEW A5 FINDING 1 (Fix 1): a failed batch leaves nothing that looks
/// finished** — the native control of the review's §4.3 step 10 at the rung.
/// Job 0 proves; job 1's activation directory is empty, so job 1 is refused
/// before its header. Afterwards no path either job may create exists: in
/// particular job 0's run directory (all its segments), its unverified
/// `statement.json` and its owner's `input.dec`, which a fresh `verify` would
/// accept. Failing first on Astra's staged code (r18/logs/red.log): job 0's
/// three directories stayed behind.
#[test]
fn r18_a_failed_batch_leaves_no_receipt_statement_or_decommitment_behind() {
    let cc = Cc::new("r18-fail");
    let post = Post::new(&cc, "r18f", Some(1));
    assert_eq!(batch_command(&post.args(&cc), &RUNG), 1, "the batch must be refused at job 1");
    let left: Vec<(PathBuf, bool)> = post.created().into_iter().filter(|(_, e)| *e).collect();
    assert!(left.is_empty(), "A FAILED BATCH LEFT RUN / STATEMENT / OWNER DIRECTORIES BEHIND (REVIEW A5 finding 1): {left:?}");
    // nothing else of this post under the runs' parent; under the owners'
    // directory only the inputs this test wrote
    assert_eq!(named(&cc.root, "r18f"), Vec::<String>::new());
    assert_eq!(named(&cc.owners, "r18f"), vec!["r18f-batch-request.json".to_string(), "r18f-seq-c0".to_string(), "r18f-seq-c1".to_string()]);
    eprintln!("TOKEN-IO R18 | Fix 1 | job 0 proved, job 1 refused before its header: no run, .incomplete, .unverified-statement or owner directory of either job is left");
}

// ------------------------------------------------------------------ one post per process

/// **One post per process** (the coordinator's reading of rule 3, register
/// "A5 one-load batch"): a second `--content-file` is refused before anything
/// is read, and so is any other repeated flag; nothing is created. Failing
/// first on the staged code (it proved the FIRST content and ignored the
/// second).
#[test]
fn r18_a_second_post_or_any_repeated_flag_is_refused_before_anything_is_read() {
    let cc = Cc::new("r18-two");
    let post = Post::new(&cc, "r18t", None);
    let other = cc.content_file(&post.whole);
    for (k, v) in [("--content-file", other.to_str().unwrap()), ("--batch-file", post.request.to_str().unwrap()), ("--export", cc.export.to_str().unwrap()), ("--label", "zk60-classify-verdict")] {
        let mut a = post.args(&cc);
        a.extend(s(&[k, v]));
        assert_eq!(batch_command(&a, &RUNG), 2, "a repeated {k} is refused as a bad argument (one post per process)");
        assert!(post.created().iter().all(|(_, e)| !*e), "a refused batch created {:?}", post.created());
    }
    eprintln!("TOKEN-IO R18 | one post per process: a second --content-file, --batch-file, --export or --label is refused (exit 2), nothing created");
}

// ------------------------------------------------------------------ the batch works

/// A complete rung batch: exit 0; each job's run directory, unverified
/// statement and owner `input.dec` (0600) exist and no `.incomplete` is left;
/// each receipt verifies in the verifier's own pass, the input owner's check
/// holds on the WHOLE content, and the category label over both chunks is
/// accepted with `--expect-total 27`.
#[test]
fn r18_a_rung_batch_proves_every_job_and_each_receipt_verifies_owner_checks_and_labels() {
    use std::os::unix::fs::PermissionsExt;
    let cc = Cc::new("r18-ok");
    let post = Post::new(&cc, "r18k", None);
    assert_eq!(batch_command(&post.args(&cc), &RUNG), 0, "the rung batch");
    for (out, owner) in post.outs.iter().zip(&post.owners) {
        assert!(out.is_dir() && !sib(out, ".incomplete").exists(), "{}", out.display());
        assert!(sib(out, ".unverified-statement").join("statement.json").is_file());
        let dec = owner.join("input.dec");
        assert_eq!(std::fs::metadata(&dec).unwrap().permissions().mode() & 0o777, 0o600, "{}", dec.display());
        assert_eq!(std::fs::metadata(owner).unwrap().permissions().mode() & 0o777, 0o700, "{}", owner.display());
    }
    for out in &post.outs {
        assert_eq!(cc.verify(out, &cc.tables), 0, "{} verifies", out.display());
        assert_eq!(cc.input_owner(out, &cc.tables, &post.whole), 0, "{}: the owner's check on the whole content", out.display());
    }
    assert_eq!(cc.label(&[&post.outs[0], &post.outs[1]], 27), 0, "the label over both chunks");
    assert!(post.seqs.iter().all(|d| d.is_dir()), "the batch never removes its inputs");
    eprintln!("TOKEN-IO R18 | rung batch: 2 jobs proved, both verify, both owner-check on the whole content, label --expect-total 27 accepted");
}

/// The CLI's production command admits only the Shieldstral T128 profile's
/// three moderate policies: the rung post (its one dev policy) is refused
/// before any load, and nothing is created.
#[test]
fn r18_the_production_batch_command_refuses_a_rung_post_and_creates_nothing() {
    let cc = Cc::new("r18-prod");
    let post = Post::new(&cc, "r18p", None);
    assert_eq!(classify_prove_batch_command(&post.args(&cc)), 1, "the production batch refuses the rung post");
    assert!(post.created().iter().all(|(_, e)| !*e), "a refused batch created {:?}", post.created());
    assert_eq!(SHIELD_T128.policies, &POLICIES[..]);
    assert_eq!((SHIELD_T128.profile, SHIELD_T128.tokens), (super::super::super::super::run::RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, 128));
    eprintln!("TOKEN-IO R18 | the production prove-batch refuses the rung post (policy list, profile); nothing created");
}

// ------------------------------------------------------------------ note 7

/// REVIEW A5 note 7: the request reader opens with O_NOFOLLOW | O_NONBLOCK, so
/// a symlink to a valid request is refused, and a FIFO is refused at once
/// (not read, not waited on); the valid request itself is read.
#[test]
fn r18_the_request_reader_refuses_a_symlink_and_a_fifo_without_blocking() {
    let cc = Cc::new("r18-req");
    let post = Post::new(&cc, "r18q", None);
    assert!(read_request(&post.request).is_ok(), "the valid request");
    let link = cc.owners.join("r18q-link.json");
    std::os::unix::fs::symlink(&post.request, &link).unwrap();
    assert!(read_request(&link).is_err(), "a symlinked request is refused");
    let fifo = cc.owners.join("r18q-fifo.json");
    let made = std::process::Command::new("mkfifo").arg("-m").arg("600").arg(&fifo).status().unwrap();
    assert!(made.success());
    let t = std::time::Instant::now();
    assert!(read_request(&fifo).is_err(), "a FIFO request is refused");
    assert!(t.elapsed().as_secs_f64() < 5.0, "the FIFO was waited on");
    eprintln!("TOKEN-IO R18 | note 7: a symlinked request and a FIFO request are refused (the FIFO at once)");
}

// ------------------------------------------------------------------ byte identity

/// the files of a directory tree with their SHA-256 (relative paths)
fn tree(d: &Path) -> Vec<(String, String)> {
    fn walk(root: &Path, d: &Path, out: &mut Vec<(String, String)>) {
        for e in std::fs::read_dir(d).unwrap() {
            let p = e.unwrap().path();
            if p.is_dir() {
                walk(root, &p, out);
            } else {
                out.push((p.strip_prefix(root).unwrap().to_string_lossy().into_owned(), hex(&sha256(&std::fs::read(&p).unwrap()))));
            }
        }
    }
    let mut out = Vec::new();
    walk(d, d, &mut out);
    out.sort();
    out
}

/// **THE BYTE-IDENTITY RULE AT THE RUNG, UNDER FIXED TEST ENTROPY.** IGNORED:
/// it holds only when run as
/// `r18/tools/run_fixed.sh rung8.bin -- env HL_R18_FIXED_ENTROPY=rung8 <the lib test binary> <this test> --exact --ignored`,
/// with `rung8.bin` = the 32-byte blocks e0 r0 e1 r1 (the batch's two jobs:
/// each the input-endpoint seal's draw, then the run stream's), e0 r0 (single
/// prove 0), e1 r1 (single prove 1); the harness exits 97 if a block is left
/// unread. Then each batch job's run directory (every segment), unverified
/// `statement.json` and `input.dec` equal the single prove's byte for byte.
/// These receipts hide nothing (public entropy): test only, removed with the
/// fixture.
#[test]
#[ignore]
fn r18_rung_batch_receipts_equal_single_proves_under_fixed_entropy() {
    assert_eq!(std::env::var("HL_R18_FIXED_ENTROPY").as_deref(), Ok("rung8"), "run only under r18/tools/run_fixed.sh with rung8.bin (HL_R18_FIXED_ENTROPY=rung8)");
    let cc = Cc::new("r18-eq");
    let post = Post::new(&cc, "r18e", None);
    assert_eq!(batch_command(&post.args(&cc), &RUNG), 0, "the batch (blocks e0 r0 e1 r1)");
    let singles: Vec<PathBuf> = (0..2).map(|i| cc.root.join(format!("r18e-single-c{i}"))).collect();
    for (i, out) in singles.iter().enumerate() {
        let cf = cc.content_file(&post.whole);
        let od = cc.owner_dir(out);
        let ck = i.to_string();
        let code = classify_prove_command(&s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--content-file", cf.to_str().unwrap(), "--chunk", &ck, "--seq-dir", post.seqs[i].to_str().unwrap(), "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]));
        assert_eq!(code, 0, "single prove {i}");
    }
    for i in 0..2 {
        let (b, o) = (&post.outs[i], &singles[i]);
        let (tb, to) = (tree(b), tree(o));
        assert!(!tb.is_empty());
        assert_eq!(tb, to, "job {i}: the batch's run directory is not the single prove's byte for byte");
        let st = |r: &Path| std::fs::read(sib(r, ".unverified-statement").join("statement.json")).unwrap();
        assert_eq!(st(b), st(o), "job {i}: the unverified statements differ");
        let dec = |r: &Path| std::fs::read(cc.owner_dir(r).join("input.dec")).unwrap();
        assert_eq!(dec(b), dec(o), "job {i}: the owners' input.dec differ");
        eprintln!("TOKEN-IO R18 | byte identity | job {i}: {} receipt files, statement.json and input.dec equal the single prove's", tb.len());
    }
    assert_ne!(tree(&post.outs[0]), tree(&post.outs[1]), "the two jobs' receipts are equal: the harness is not feeding distinct blocks");
}

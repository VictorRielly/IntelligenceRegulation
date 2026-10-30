//! **TOKEN I/O ROUND 15: REVIEW_R14 N-r14-1, the label's whole-post check.**
//! TEST CODE ONLY, public synthetic data (the development rung's pinned
//! tensor and tiny export, `classify_cli_tests`' fixture).
//!
//! Written FAILING-FIRST against round 14's code (run r15-red: the tree as
//! frozen in frozen-r14 plus this file and the F18-1 capture tests):
//!
//! * **N-r14-1** (REVIEW_R14 §9): `label` cannot know how long the post is.
//!   A proof set of only the FIRST k < N ids of an N-id post labels cleanly,
//!   with `content_total` = k (round 14 widened this: a short item of any
//!   k >= 1 is one chunk). `label --expect-total N` (N = the post's own token
//!   count from the pinned tokenizer; public by D45(1)) must refuse such a set
//!   and admit the honest full set. Round 14's CLI has no such argument
//!   (exit 2) and labels the truncated set without one (exit 0).
//!
//! The `#[ignore]`d binary test runs the same cases through the NAMED
//! `zk60_classify` binary, each command its own process (the r14 binary
//! fails them; the r15 binary passes).

use super::classify::*;
use super::classify_cli::classify_label_command;
use super::classify_cli_tests::{Cc, POLICY_RUNG_DEV};
use std::path::PathBuf;

/// the development policy's public pad id (DESIGN v2.4 §15)
const DEV_PAD: u64 = 2;

fn s(v: &[&str]) -> Vec<String> {
    v.iter().map(|x| x.to_string()).collect()
}

fn text(v: &[u64]) -> String {
    v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
}

/// the padded item of a content: template prefix, the content, the suffix,
/// then the public pad id up to `t` (a full-length content gets no pad)
fn padded(content: &[u64], t: usize) -> Vec<u64> {
    let p = policy_rung_dev();
    let mut v: Vec<u64> = p.prefix.iter().chain(content.iter()).chain(p.suffix.iter()).copied().collect();
    while v.len() < t {
        v.push(DEV_PAD);
    }
    v
}

/// `zk60_classify label` over `runs` from the fixture's verifier copy, with
/// `--expect-total` when `expect` is given (a raw value, so bad values are
/// testable)
fn label_with(cc: &Cc, runs: &[&PathBuf], expect: Option<&str>) -> i32 {
    let joined = runs.iter().map(|r| r.to_str().unwrap()).collect::<Vec<_>>().join(",");
    let mut args = vec!["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--runs", &joined, "--expect-statement", &cc.identity, "--min-bits", "93"];
    if let Some(n) = expect {
        args.extend_from_slice(&["--expect-total", n]);
    }
    classify_label_command(&s(&args))
}

/// the four proved and verified runs of the cases below: the 23-id post's
/// one chunk, the first 22 ids of that post (a short item), and the 27-id
/// post's two chunks `[0, 23)` and `[4, 27)`
struct Runs {
    full23: PathBuf,
    first22: PathBuf,
    c0: PathBuf,
    c1: PathBuf,
}

fn prove_runs(cc: &Cc) -> Runs {
    let p = policy_rung_dev();
    // the 23-id post (9..=31): one chunk [0, 23), the export's s0
    let full23 = cc.root.join("post23");
    assert_eq!(cc.prove_chunk(&full23, &cc.content, 0, None), 0, "the 23-id post");
    // the first 22 ids of that post, proved as a short item (round 14)
    let first22: Vec<u64> = (9..=30).collect();
    let sd = cc.owners.join("seq-first22");
    cc.write_seq_dir(&sd, &padded(&first22, 32));
    let r22 = cc.root.join("first22");
    assert_eq!(cc.prove_chunk(&r22, &text(&first22), 0, Some(sd.as_path())), 0, "the first 22 ids as a short item");
    // the 27-id post (9..=31, 33..=36): chunk 0 = the export's s0, chunk 1 [4, 27)
    let whole27 = format!("{},33,34,35,36", cc.content);
    let chunk1: Vec<u64> = p.prefix.iter().copied().chain((13..=31).chain(33..=36)).chain(p.suffix.iter().copied()).collect();
    let sd1 = cc.owners.join("seq-chunk1");
    cc.write_seq_dir(&sd1, &chunk1);
    let (c0, c1) = (cc.root.join("post27-c0"), cc.root.join("post27-c1"));
    assert_eq!(cc.prove_chunk(&c0, &whole27, 0, None), 0, "chunk 0 of the 27-id post");
    assert_eq!(cc.prove_chunk(&c1, &whole27, 1, Some(sd1.as_path())), 0, "chunk 1 of the 27-id post");
    for r in [&full23, &r22, &c0, &c1] {
        assert_eq!(cc.verify(r, &cc.tables), 0, "{} verifies (and is published)", r.display());
    }
    Runs { full23, first22: r22, c0, c1 }
}

/// **N-r14-1: a truncated proof set is refused against the post's own
/// total; the honest full set passes.** Truncated: the first 22 ids of the
/// 23-id post (a short item, `content_total` 22) under `--expect-total 23`;
/// the first 23 ids of the 27-id post (`content_total` 23) under 27; the
/// first 22 ids under 27; chunk 0 of the 27-id post alone. Also refused: the
/// truncated set with no `--expect-total` (the post's count is required),
/// and the values 0 and `x`. Honest: the 23-id post's set under 23, the
/// 27-id post's two chunks under 27 (either order), the 22-id post's own set
/// under 22.
#[test]
fn r15_label_refuses_a_truncated_proof_set_against_the_posts_own_total() {
    let cc = Cc::new("r15-trunc");
    let r = prove_runs(&cc);
    let cases: Vec<(&str, Vec<&PathBuf>, Option<&str>, i32)> = vec![
        ("truncated: the first 22 ids of the 23-id post, --expect-total 23", vec![&r.first22], Some("23"), 1),
        ("truncated: the first 23 ids of the 27-id post, --expect-total 27", vec![&r.full23], Some("27"), 1),
        ("truncated: the first 22 ids of the 27-id post, --expect-total 27", vec![&r.first22], Some("27"), 1),
        ("truncated: chunk 0 of the 27-id post alone, --expect-total 27", vec![&r.c0], Some("27"), 1),
        ("truncated: the first 22 ids with no --expect-total", vec![&r.first22], None, 1),
        ("bad value: --expect-total 0", vec![&r.full23], Some("0"), 1),
        ("bad value: --expect-total x", vec![&r.full23], Some("x"), 1),
        ("honest: the 23-id post's one chunk, --expect-total 23", vec![&r.full23], Some("23"), 0),
        ("honest: the 27-id post's two chunks, --expect-total 27", vec![&r.c0, &r.c1], Some("27"), 0),
        ("honest: the 27-id post's two chunks in the other order", vec![&r.c1, &r.c0], Some("27"), 0),
        ("honest: the 22-id post's own one chunk, --expect-total 22", vec![&r.first22], Some("22"), 0),
    ];
    let mut wrong = Vec::new();
    for (what, runs, expect, want) in &cases {
        let got = label_with(&cc, runs, *expect);
        eprintln!("TOKEN-IO R15 | N-r14-1 | {what}: exit {got} (want {want})");
        if got != *want {
            wrong.push(format!("{what}: exit {got}, want {want}"));
        }
    }
    assert!(wrong.is_empty(), "N-r14-1: THE LABEL ADMITTED A TRUNCATED PROOF SET OR REFUSED THE HONEST ONE ({} of {} cases): {wrong:#?}", wrong.len(), cases.len());
}

/// **The same cases through the NAMED binary, each command its own process**
/// (`HL_PB_CLI_BIN`): the runs proved and verified in-process as above, then
/// every `label` call is the binary's own process.
#[test]
#[ignore = "runs the named zk60_classify binary; set HL_PB_CLI_BIN"]
fn r15_label_expect_total_through_the_named_binary_in_fresh_processes() {
    let bin = PathBuf::from(std::env::var("HL_PB_CLI_BIN").expect("HL_PB_CLI_BIN is not set: the named zk60_classify binary"));
    assert!(bin.is_absolute() && bin.is_file(), "HL_PB_CLI_BIN must be an absolute path to the binary");
    let cc = Cc::new("r15-bin");
    let r = prove_runs(&cc);
    let cases: Vec<(&str, Vec<&PathBuf>, Option<&str>, i32)> = vec![
        ("truncated: the first 22 ids of the 23-id post, --expect-total 23", vec![&r.first22], Some("23"), 1),
        ("truncated: the first 23 ids of the 27-id post, --expect-total 27", vec![&r.full23], Some("27"), 1),
        ("truncated: the first 22 ids with no --expect-total", vec![&r.first22], None, 1),
        ("honest: the 23-id post's one chunk, --expect-total 23", vec![&r.full23], Some("23"), 0),
        ("honest: the 27-id post's two chunks, --expect-total 27", vec![&r.c0, &r.c1], Some("27"), 0),
        ("honest: the 22-id post's own one chunk, --expect-total 22", vec![&r.first22], Some("22"), 0),
    ];
    let mut wrong = Vec::new();
    for (what, runs, expect, want) in &cases {
        let joined = runs.iter().map(|r| r.to_str().unwrap()).collect::<Vec<_>>().join(",");
        let mut args = s(&["label", "--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--runs", &joined, "--expect-statement", &cc.identity, "--min-bits", "93"]);
        if let Some(n) = expect {
            args.extend(s(&["--expect-total", n]));
        }
        let out = std::process::Command::new(&bin).args(&args).output().expect("the CLI binary runs");
        let got = out.status.code().unwrap_or(-1);
        eprintln!("TOKEN-IO R15 | binary {} | {what}: exit {got} (want {want}) | stdout {}", bin.display(), String::from_utf8_lossy(&out.stdout).trim());
        if got != *want {
            wrong.push(format!("{what}: exit {got}, want {want}"));
        }
    }
    assert!(wrong.is_empty(), "N-r14-1 through the named binary {}: {wrong:#?}", bin.display());
}

// ------------------------------------------------------------------ added after the red run (GREEN)

/// **N-r14-1 in the library: `aggregate_label(seen, expect_total)`** (the
/// parameter round 15 adds; a library caller hands `ChunkRef` values it may
/// have built itself). Honest sets pass at their post's total; refused: a
/// set of another total (the first 23 or 22 ids of a 27-id post, the first 22
/// of a 23-id post), a run whose range is not its index's range in the split
/// of `[0, N)`, a chunk count that is not the split's, an index beyond the
/// split, and `expect_total` 0.
#[test]
fn r15_the_library_label_checks_the_posts_total_and_every_range() {
    use super::classify_cli::aggregate_label;
    let plan = ChunkPlan { size: 23, overlap: 4 };
    let c = |j: usize, total: usize| ChunkRef::derive(total, j, plan).unwrap();
    let m = [7u8; 32];
    let pol = || POLICY_RUNG_DEV.to_string();
    let set = |cs: &[ChunkRef]| cs.iter().map(|x| (*x, 0u8, pol(), m)).collect::<Vec<_>>();
    // honest: each post's whole split at its own total
    assert_eq!(aggregate_label(&set(&[c(0, 27), c(1, 27)]), 27), Ok(0));
    assert_eq!(aggregate_label(&set(&[c(0, 23)]), 23), Ok(0));
    assert_eq!(aggregate_label(&set(&[c(0, 22)]), 22), Ok(0));
    assert_eq!(aggregate_label(&set(&[c(0, 1)]), 1), Ok(0));
    assert_eq!(aggregate_label(&set(&[c(2, 43), c(0, 43), c(1, 43)]), 43), Ok(0));
    // truncated: a set of another total
    for (cs, n) in [(vec![c(0, 23)], 27), (vec![c(0, 22)], 27), (vec![c(0, 22)], 23), (vec![c(0, 1)], 23), (vec![c(0, 27), c(1, 27)], 43), (vec![c(0, 27), c(1, 27)], 26)] {
        let e = aggregate_label(&set(&cs), n).unwrap_err();
        assert!(e.contains(&format!("but the post has {n}")), "{e}");
    }
    // a library caller's own ChunkRef: a range that is not the split's, a count that is not, an index beyond it
    let good = c(1, 27);
    let shifted = ChunkRef { a: 5, ..good };
    assert!(aggregate_label(&set(&[c(0, 27), shifted]), 27).unwrap_err().contains("names the range [5, 27)"));
    let short_b = ChunkRef { b: 26, ..good };
    assert!(aggregate_label(&set(&[c(0, 27), short_b]), 27).unwrap_err().contains("names the range [4, 26)"));
    let one = ChunkRef { count: 1, ..c(0, 27) };
    assert!(aggregate_label(&set(&[one]), 27).unwrap_err().contains("the split of [0, 27) has 2"));
    let beyond = ChunkRef { index: 2, ..good };
    assert!(aggregate_label(&set(&[c(0, 27), good, beyond]), 27).unwrap_err().contains("chunk 2 of a 2-chunk split"));
    assert!(aggregate_label(&set(&[c(0, 1)]), 0).is_err(), "expect_total 0");
    eprintln!("TOKEN-IO R15 | N-r14-1 | the library's aggregate_label refuses another total, a range off the split, a wrong count and an index beyond it");
}

/// **Round 15 changes no receipt, statement or profile byte**: a receipt
/// proved by one named binary verifies with the other (`HL_PB_CLI_BIN`, this
/// round's; `HL_PB_CLI_BIN_OTHER`, e.g. the frozen r14 binary), both ways, for
/// the 23-id item and a 22-id short item; each command its own process, each
/// verify on its own fresh copy of the run directory.
#[test]
#[ignore = "runs two named zk60_classify binaries; set HL_PB_CLI_BIN and HL_PB_CLI_BIN_OTHER"]
fn r15_receipts_cross_verify_between_two_named_binaries() {
    let bin_of = |k: &str| {
        let b = PathBuf::from(std::env::var(k).unwrap_or_else(|_| panic!("{k} is not set: a named zk60_classify binary")));
        assert!(b.is_absolute() && b.is_file(), "{k} must be an absolute path to the binary");
        b
    };
    let (this, other) = (bin_of("HL_PB_CLI_BIN"), bin_of("HL_PB_CLI_BIN_OTHER"));
    let cc = Cc::new("r15-xbin");
    let first22: Vec<u64> = (9..=30).collect();
    let sd = cc.owners.join("seq-xbin-22");
    cc.write_seq_dir(&sd, &padded(&first22, 32));
    fn copy_dir(from: &std::path::Path, to: &std::path::Path) {
        std::fs::create_dir_all(to).unwrap();
        for e in std::fs::read_dir(from).unwrap() {
            let e = e.unwrap();
            let dst = to.join(e.file_name());
            if e.file_type().unwrap().is_dir() {
                copy_dir(&e.path(), &dst);
            } else {
                std::fs::copy(e.path(), &dst).unwrap();
            }
        }
    }
    let mut wrong = Vec::new();
    for (pname, prover, vname, verifier) in [("this", &this, "other", &other), ("other", &other, "this", &this)] {
        for (item, content, seq) in [("23", cc.content.clone(), None), ("22", text(&first22), Some(sd.clone()))] {
            let run = cc.root.join(format!("x-{pname}-{item}"));
            let od = cc.owner_dir(&run);
            let cf = cc.content_file(&content);
            let mut args = s(&["prove", "--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--content-file", cf.to_str().unwrap(), "--out", run.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]);
            match &seq {
                Some(d) => args.extend(s(&["--seq-dir", d.to_str().unwrap()])),
                None => args.extend(s(&["--seq", "s0"])),
            }
            let code = std::process::Command::new(prover).args(&args).output().expect("the CLI binary runs").status.code();
            assert_eq!(code, Some(0), "{pname} binary's prove of the {item}-id item");
            // a fresh copy of the run (and its unverified statement) for the other binary's verify
            let vrun = cc.root.join(format!("x-{pname}-{item}-by-{vname}"));
            copy_dir(&run, &vrun);
            copy_dir(&PathBuf::from(format!("{}.unverified-statement", run.display())), &PathBuf::from(format!("{}.unverified-statement", vrun.display())));
            let out = std::process::Command::new(verifier).args(s(&["verify", "--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--artifact", vrun.to_str().unwrap(), "--expect-statement", &cc.identity, "--min-bits", "93"])).output().expect("the CLI binary runs");
            let got = out.status.code().unwrap_or(-1);
            eprintln!("TOKEN-IO R15 | cross-binary | {item}-id item proved by {pname} ({}), verified by {vname} ({}): exit {got} | {}", prover.display(), verifier.display(), String::from_utf8_lossy(&out.stdout).trim());
            if got != 0 {
                wrong.push(format!("{item}-id item proved by {pname}, verified by {vname}: exit {got}"));
            }
        }
    }
    assert!(wrong.is_empty(), "round 15 moved a receipt or statement byte: {wrong:#?}");
}

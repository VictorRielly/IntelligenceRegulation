//! **TOKEN I/O ROUND 14: the R-C2 review's N-r13-1 and short items.** TEST
//! CODE ONLY, public synthetic data (the development rung's pinned tensor and
//! tiny export, `classify_cli_tests`' fixture).
//!
//! Written FAILING-FIRST against round 13's code (run r14-red, the tree as
//! frozen in frozen-r13 plus this file):
//!
//! * **N-r13-1** (REVIEW_R13 §9): a LIBRARY caller (no CLI) handed a tables
//!   directory whose margin row is doctored and whose `classifier.json` was
//!   rehashed (a consistent manifest) must be refused. Round 13's library took
//!   any `ClassifierTables`, so this proved and verified.
//! * **Short items** (Astra's 2026-10-29 00:29:56 finding; DESIGN v2.2 §13.1):
//!   a dev-rung item shorter than one chunk (22 ids against a chunk of 23) is
//!   ONE chunk of its true length, its trailing positions pinned to the
//!   policy's public pad id; it must prove, verify, owner-check and label.
//!   Round 13 refused it by name ("short content is not built").
//!
//! The `#[ignore]`d binary test runs the same short item through the NAMED
//! `zk60_classify` binary, prove and verify each in its own process (the r13
//! binary refuses the prove; the r14 binary proves and verifies).
//!
//! GREEN (round 14): the library helper [`lib_run`] obtains its tables the
//! only way round 14's library admits (`classify_tied::load_bound_tables`:
//! derived from the pinned tensor for the export's trained statement and
//! compared with the files); the test bodies are the failing-first ones. Added
//! after the red run: tables bound to ANOTHER trained statement are refused by
//! the statement constructor, the prover and the verifier; the block and run
//! profiles must name one tied source (N-r13-6); only the tied derivation
//! constructs bound tables (source scan); a short item's statement re-read
//! under another length is refused.

use super::classify::*;
use super::classify_cli::load_export;
use super::classify_cli_tests::{Cc, POLICY_RUNG_DEV, POLICY_RUNG_DEV_SWAPPED};
use super::classify_tied::{load_bound_tables, BoundClassifierTables};
use super::classify_run::*;
use super::cli::cli_stage_shape;
use super::load::ExportTokenBlocks;
use super::run::{TokenBlocks, VerifierPolicy};
use super::*;
use super::super::run::RunShape;
use super::super::run_sink;
use super::super::trained_block::{sha256, stack_context};
use super::super::BlockPublic;
use std::path::{Path, PathBuf};

/// the development policy's public pad id (DESIGN v2.4 §15: the trailing
/// positions of a short item)
pub(super) const DEV_PAD: u64 = 2;

/// change a table file and REHASH its manifest (as `classify_tied_tests`)
fn rehash(dir: &Path, file: &str, manifest: &str, edit: impl FnOnce(&mut Vec<u8>)) {
    let fp = dir.join(file);
    let mut b = std::fs::read(&fp).unwrap();
    let old = hex(&sha256(&b));
    edit(&mut b);
    let new = hex(&sha256(&b));
    assert_ne!(old, new, "the edit changes the table");
    std::fs::write(&fp, &b).unwrap();
    let mp = dir.join(manifest);
    let m = std::fs::read_to_string(&mp).unwrap();
    assert_eq!(m.matches(&old).count(), 1, "{manifest} names the table's digest once");
    std::fs::write(&mp, m.replace(&old, &new)).unwrap();
}

/// **THE LIBRARY CALLER** (no CLI): the export, the library's classifier
/// tables for `tables_dir`, the honest pipeline on the export's blocks, the
/// sealed input, the statement, `prove_classify_run_with`, then
/// `verify_classify_run_with` on the receipt. Returns the verified verdict.
fn lib_run(export: &Path, tables_dir: &Path, policy_id: &str, content: &[u64]) -> Result<u8, String> {
    let p = load_export(export)?;
    let policy = policy_by_id(policy_id)?;
    let sh = p.sh.clone();
    // ROUND 14's library: the ONLY table constructor (derived from the pinned
    // tensor for this export's trained statement, compared with the files)
    let bound = load_bound_tables(&sh, &p.model, export, tables_dir, &policy)?;
    let (tables, bos, nm) = (bound.tables(), bound.bos(), bound.norm());
    let mut eb = ExportTokenBlocks::new(&p);
    let blks: Vec<BlockPublic> = (0..p.layers.len()).map(|k| eb.block(k).map(|b| (*b).clone())).collect::<Result<_, _>>()?;
    drop(eb);
    let shapes: Vec<Shape> = p.model.layers.iter().map(|r| cli_stage_shape(&sh, &r.own)).collect::<Result<_, _>>()?;
    let cp = ClassifierProfile::new(&sh, tables, bos, nm, &policy, content.len(), Tier::R1_MVP)?;
    let tokens = cp.tokens_of(content)?;
    let mut hp = honest_classify(&shapes, &cp, tables, &blks, &tokens)?;
    let ctx = stack_context(&p.ex.variant, &p.layers, super::classify_cli::CLASSIFY_LABELS[0])?;
    let spec = input_endpoint_spec(&sh, ctx, &cp)?;
    let (root, owner) = seal_input(&spec, &hp.in_plane, &sh.hash_tag())?;
    let st = ClassifyRunStatement::new_chunk(RunShape::new(sh.clone(), p.layers.len(), p.profile)?, ctx, p.digests.clone(), &p.model, &bound, &policy, content.len(), Tier::R1_MVP, root, hp.out_values.verdict, content.len(), 0)?;
    let mut segs = Vec::new();
    let mut blocks = ExportTokenBlocks::new(&p);
    prove_classify_run_with(&st, &mut blocks, &bound, &mut ClassifySource(&mut hp), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })?;
    drop(blocks);
    let mut blocks = ExportTokenBlocks::new(&p);
    verify_classify_run_with(&st, &mut blocks, &bound, &segs, VerifierPolicy { min_whole_run_bits: 93 })?;
    Ok(st.verdict())
}

/// a library-proved honest run of the fixture item (the dev policy, the
/// export's own bound tables): the statement, the receipt, the export
struct LibRun {
    st: ClassifyRunStatement,
    segs: Vec<Vec<u8>>,
}

fn lib_prove(export: &Path, bound: &BoundClassifierTables, policy: &Policy, content: &[u64]) -> Result<LibRun, String> {
    let p = load_export(export)?;
    let sh = p.sh.clone();
    let mut eb = ExportTokenBlocks::new(&p);
    let blks: Vec<BlockPublic> = (0..p.layers.len()).map(|k| eb.block(k).map(|b| (*b).clone())).collect::<Result<_, _>>()?;
    drop(eb);
    let shapes: Vec<Shape> = p.model.layers.iter().map(|r| cli_stage_shape(&sh, &r.own)).collect::<Result<_, _>>()?;
    let cp = ClassifierProfile::new(&sh, bound.tables(), bound.bos(), bound.norm(), policy, content.len(), Tier::R1_MVP)?;
    let mut hp = honest_classify(&shapes, &cp, bound.tables(), &blks, &cp.tokens_of(content)?)?;
    let ctx = stack_context(&p.ex.variant, &p.layers, super::classify_cli::CLASSIFY_LABELS[0])?;
    let (root, owner) = seal_input(&input_endpoint_spec(&sh, ctx, &cp)?, &hp.in_plane, &sh.hash_tag())?;
    let st = ClassifyRunStatement::new_chunk(RunShape::new(sh.clone(), p.layers.len(), p.profile)?, ctx, p.digests.clone(), &p.model, bound, policy, content.len(), Tier::R1_MVP, root, hp.out_values.verdict, content.len(), 0)?;
    let mut segs = Vec::new();
    let mut blocks = ExportTokenBlocks::new(&p);
    prove_classify_run_with(&st, &mut blocks, bound, &mut ClassifySource(&mut hp), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })?;
    Ok(LibRun { st, segs })
}

fn ids(text: &str) -> Vec<u64> {
    text.split(',').map(|x| x.parse().unwrap()).collect()
}

/// **N-r13-1: a library caller handed doctored tables with a consistent
/// manifest is refused.** The honest tables directory proves and verifies
/// through the library (the control); a margin row with one word changed and
/// `classifier.json` rehashed, and an embedding row changed with
/// `token_io.json` rehashed, are refused (nothing is proved).
#[test]
fn r14_a_library_call_with_doctored_tables_and_a_consistent_manifest_is_refused() {
    let cc = Cc::new("r14-lib");
    let content = ids(&cc.content);
    let v = lib_run(&cc.export, &cc.tables, POLICY_RUNG_DEV, &content).unwrap_or_else(|e| panic!("the honest library run: {e}"));
    assert_eq!(v, 0, "the dev rung's registered policy gives verdict 0 on the fixture item (N-r13-3)");
    rehash(&cc.tables, "margin_int16.bin", "classifier.json", |b| b[10] ^= 0x04);
    let e = lib_run(&cc.export, &cc.tables, POLICY_RUNG_DEV, &content).err().expect("THE LIBRARY PROVED AND VERIFIED A DOCTORED MARGIN ROW (N-r13-1)");
    eprintln!("TOKEN-IO R14 | N-r13-1 | doctored margin row + rehashed classifier.json refused by the library path: {e}");
    let cc = Cc::new("r14-lib-emb");
    rehash(&cc.tables, "embedding_int16.bin", "token_io.json", |b| b[200 * 384 * 2] ^= 0x01);
    let e = lib_run(&cc.export, &cc.tables, POLICY_RUNG_DEV, &content).err().expect("THE LIBRARY PROVED AND VERIFIED A DOCTORED EMBEDDING (N-r13-1)");
    eprintln!("TOKEN-IO R14 | N-r13-1 | doctored embedding row 200 + rehashed token_io.json refused by the library path: {e}");
}

/// the padded item of a short content: template prefix, the content, the
/// suffix, then the public pad id up to T
fn padded(content: &[u64], t: usize) -> Vec<u64> {
    let p = policy_rung_dev();
    let mut v: Vec<u64> = p.prefix.iter().chain(content.iter()).chain(p.suffix.iter()).copied().collect();
    while v.len() < t {
        v.push(DEV_PAD);
    }
    v
}

fn text(v: &[u64]) -> String {
    v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
}

/// **A short dev-rung item (22 ids, one chunk is 23) is ONE chunk of its
/// true length**: it proves (the activations of the padded item: prefix, the
/// 22 ids, the suffix, one pad id), verifies, owner-checks against the whole
/// content and labels (one chunk covers [0, 22)); the statement names
/// `content_length_n` 22 and the chunk `[0, 22]` of 22 under the plan (23, 4).
/// A one-id item too. Round 13 refused both by name.
#[test]
fn r14_a_short_dev_rung_item_is_one_chunk_of_its_true_length() {
    let cc = Cc::new("r14-short");
    for (name, short) in [("short-22", (9..=30).collect::<Vec<u64>>()), ("short-1", vec![200u64])] {
        let n = short.len();
        let sd = cc.owners.join(format!("seq-{name}"));
        cc.write_seq_dir(&sd, &padded(&short, 32));
        let whole = text(&short);
        let r = cc.root.join(name);
        assert_eq!(cc.prove_chunk(&r, &whole, 0, Some(sd.as_path())), 0, "{name}: a short item proves as one chunk of its true length");
        let unv = std::fs::read_to_string(PathBuf::from(format!("{}.unverified-statement", r.display())).join("statement.json")).unwrap();
        assert!(unv.contains(&format!("\"content_length_n\": {n},")), "{unv}");
        assert!(unv.contains(&format!("\"chunk\": {{\"index\": 0, \"count\": 1, \"range\": [0, {n}], \"content_total\": {n}, \"chunk_size\": 23, \"overlap\": 4")), "{unv}");
        assert_eq!(cc.verify(&r, &cc.tables), 0, "{name}: verify");
        assert!(r.join(run_sink::STATEMENT_DIR).join("statement.json").is_file(), "{name}: the verifier published the statement");
        assert_eq!(cc.input_owner(&r, &cc.tables, &whole), 0, "{name}: the owner's check on the whole (short) content");
        let other: Vec<u64> = short.iter().map(|x| if *x == 200 { 201 } else { *x }).collect();
        let other = if other == short { short.iter().rev().copied().collect() } else { other };
        if other != short {
            assert_eq!(cc.input_owner(&r, &cc.tables, &text(&other)), 1, "{name}: another content of the same length is refused");
        }
        let longer: Vec<u64> = short.iter().copied().chain([300 - 1]).collect();
        assert_eq!(cc.input_owner(&r, &cc.tables, &text(&longer)), 1, "{name}: a content of another total is refused");
        assert_eq!(cc.label(&[&r]), 0, "{name}: the label over the one chunk");
        eprintln!("TOKEN-IO R14 | short item {name}: {n} ids as one chunk [0, {n}) of a 23-id plan; proved, verified, owner-checked, labelled");
    }
}

/// **The same short item through the NAMED binary, each command its own
/// process** (`HL_PB_CLI_BIN`): `prove`, then `verify` from the verifier copy
/// (pinned, `--min-bits 93`), then `input-owner` and `label`. Exit 0 each.
#[test]
#[ignore = "runs the named zk60_classify binary; set HL_PB_CLI_BIN"]
fn r14_a_short_item_proves_and_verifies_through_the_named_binary_in_fresh_processes() {
    let bin = PathBuf::from(std::env::var("HL_PB_CLI_BIN").expect("HL_PB_CLI_BIN is not set: the named zk60_classify binary"));
    assert!(bin.is_absolute() && bin.is_file(), "HL_PB_CLI_BIN must be an absolute path to the binary");
    let cc = Cc::new("r14-bin");
    let short: Vec<u64> = (9..=30).collect();
    let sd = cc.owners.join("seq-bin");
    cc.write_seq_dir(&sd, &padded(&short, 32));
    let run = cc.root.join("run-short-bin");
    let od = cc.owner_dir(&run);
    let cf = cc.content_file(&text(&short));
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let out = std::process::Command::new(&bin).arg("prove").args(s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--content-file", cf.to_str().unwrap(), "--seq-dir", sd.to_str().unwrap(), "--out", run.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()])).output().expect("the CLI binary runs");
    eprintln!("prove stdout: {}", String::from_utf8_lossy(&out.stdout));
    assert_eq!(out.status.code(), Some(0), "the named binary's prove of a 22-id item");
    let pub_flags = s(&["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--expect-statement", &cc.identity, "--min-bits", "93"]);
    let out = std::process::Command::new(&bin).arg("verify").args(&pub_flags).args(["--artifact", run.to_str().unwrap()]).output().expect("the CLI binary runs");
    eprintln!("verify stdout: {}", String::from_utf8_lossy(&out.stdout));
    assert_eq!(out.status.code(), Some(0), "the named binary's verify, a fresh process (it publishes <run>/statement/)");
    let stmt = std::fs::read_to_string(run.join(run_sink::STATEMENT_DIR).join("statement.json")).unwrap();
    assert!(stmt.contains("\"content_length_n\": 22,") && stmt.contains("\"range\": [0, 22]"), "{stmt}");
    let cf2 = cc.content_file(&text(&short));
    let out = std::process::Command::new(&bin).arg("input-owner").args(&pub_flags).args(["--artifact", run.to_str().unwrap(), "--decommitment", od.join("input.dec").to_str().unwrap(), "--content-file", cf2.to_str().unwrap()]).output().expect("the CLI binary runs");
    assert_eq!(out.status.code(), Some(0), "the named binary's input-owner: {}", String::from_utf8_lossy(&out.stdout));
    let out = std::process::Command::new(&bin).arg("label").args(&pub_flags).args(["--runs", run.to_str().unwrap()]).output().expect("the CLI binary runs");
    eprintln!("label stdout: {}", String::from_utf8_lossy(&out.stdout));
    assert_eq!(out.status.code(), Some(0), "the named binary's label over the one chunk");
    eprintln!("TOKEN-IO R14 | the named binary {}: a 22-id item proved, verified (fresh process, published), owner-checked and labelled", bin.display());
}

// ------------------------------------------------------------------ added after the red run (GREEN)

/// **N-r13-1 at the entry points: tables bound to ANOTHER trained statement
/// are refused.** The swapped export's honestly derived tables (its own
/// trained statement, its own profile) handed with the dev export's
/// statement: refused by `ClassifyRunStatement::new_chunk`; handed to the
/// prover or the verifier of a dev-export statement: refused by both before
/// any segment. Tables derived from the VERIFIER'S COPY of the dev export (the
/// same trained statement identity, another path) verify the run.
#[test]
fn r14_tables_bound_to_another_trained_statement_are_refused_at_every_entry_point() {
    let cc = Cc::new("r14-other");
    let content = ids(&cc.content);
    let p = load_export(&cc.export).unwrap();
    let pn = load_export(&cc.export_neg).unwrap();
    let dev = policy_rung_dev();
    let swapped = policy_by_id(POLICY_RUNG_DEV_SWAPPED).unwrap();
    let bound = load_bound_tables(&p.sh, &p.model, &cc.export, &cc.tables, &dev).unwrap();
    let bound_neg = load_bound_tables(&pn.sh, &pn.model, &cc.export_neg, &cc.tables_neg, &swapped).unwrap();
    assert!(bound.is_derived() && bound_neg.is_derived());
    assert_ne!(bound.model_identity(), bound_neg.model_identity());
    // the statement constructor: the other export's tables, under either policy
    let ctx = stack_context(&p.ex.variant, &p.layers, super::classify_cli::CLASSIFY_LABELS[0]).unwrap();
    for pol in [&dev, &swapped] {
        let e = ClassifyRunStatement::new_chunk(RunShape::new(p.sh.clone(), 1, p.profile).unwrap(), ctx, p.digests.clone(), &p.model, &bound_neg, pol, content.len(), Tier::R1_MVP, [9; 32], 0, content.len(), 0).err().expect("A STATEMENT WAS BUILT ON ANOTHER TRAINED STATEMENT'S TABLES");
        assert!(e.contains("derived for another trained statement"), "{}: {e}", pol.id);
    }
    // the prover and the verifier of an honest dev statement
    let r = lib_prove(&cc.export, &bound, &dev, &content).unwrap();
    let e = lib_prove(&cc.export, &bound_neg, &dev, &content).err().expect("the other export's tables proved");
    assert!(e.contains("derived for another trained statement"), "{e}");
    let mut blocks = ExportTokenBlocks::new(&p);
    let e = verify_classify_run_with(&r.st, &mut blocks, &bound_neg, &r.segs, VerifierPolicy { min_whole_run_bits: 93 }).err().expect("A VERIFIER ACCEPTED ANOTHER TRAINED STATEMENT'S TABLES");
    assert!(e.contains("bound to another trained statement than the statement's"), "{e}");
    drop(blocks);
    let pv = load_export(&cc.verifier_copy).unwrap();
    let bound_v = load_bound_tables(&pv.sh, &pv.model, &cc.verifier_copy, &cc.tables, &dev).unwrap();
    assert_eq!(bound_v.model_identity(), bound.model_identity());
    let mut blocks = ExportTokenBlocks::new(&pv);
    verify_classify_run_with(&r.st, &mut blocks, &bound_v, &r.segs, VerifierPolicy { min_whole_run_bits: 93 }).expect("tables derived from the verifier's copy verify the run");
    // the prover side too: a statement built on `bound`, the prover handed `bound_neg`
    eprintln!("TOKEN-IO R14 | N-r13-1 | another trained statement's tables refused by the statement, the prover and the verifier; the verifier copy's tables verify");
}

/// **N-r13-6: the block profile and the run profile must name ONE tied
/// source.** The dev tables checked for a Shieldstral block shape under the
/// rung's classifier run profile are refused by name; an unregistered run
/// profile has no tied source.
#[test]
fn r14_the_block_and_run_profiles_must_name_one_tied_source() {
    let cc = Cc::new("r14-src");
    let p = load_export(&cc.export).unwrap();
    let dev = policy_rung_dev();
    let bound = load_bound_tables(&p.sh, &p.model, &cc.export, &cc.tables, &dev).unwrap();
    bound.check_for(&p.sh, p.profile, &p.model, &dev).expect("the dev export under its own profiles");
    let mut sh = p.sh.clone();
    sh.profile = super::super::shape::SHIELDSTRAL_T256_TRAINED_PROFILE;
    let e = bound.check_for(&sh, p.profile, &p.model, &dev).unwrap_err();
    assert!(e.contains("N-r13-6"), "{e}");
    let e = bound.check_for(&p.sh, super::super::run::RUN_PROFILE_TOKEN_IO_RUNG_TC, &p.model, &dev).unwrap_err();
    assert!(e.contains("no tied source is registered for the classifier run profile"), "{e}");
    eprintln!("TOKEN-IO R14 | N-r13-6 | a block profile whose tied source is not the run profile's is refused; an unregistered run profile has none");
}

fn source_of(rel: &str) -> String {
    std::fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join(rel)).unwrap_or_else(|e| panic!("{rel}: {e}"))
}

/// the text of `fn name(` (its first occurrence after `anchor`) up to its
/// body's opening brace
fn signature<'a>(src: &'a str, anchor: &str, name: &str) -> &'a str {
    let from = src.find(anchor).unwrap_or_else(|| panic!("no {anchor}"));
    let at = from + src[from..].find(name).unwrap_or_else(|| panic!("no {name}"));
    let end = at + src[at..].find('{').expect("a body");
    &src[at..end]
}

/// **N-r13-1, structurally: only the tied derivation constructs bound
/// tables, and every classifier run entry point takes them.** In
/// `classify_tied.rs` the struct has exactly two literals, one in
/// `load_bound_tables` (the derivation and the file comparison) and one in the
/// `#[cfg(test)]` relation-test binding; no other source names a literal (the
/// private fields make it a compile error anyway). The four entry points'
/// signatures take `&BoundClassifierTables` (or `&super::classify_tied::
/// BoundClassifierTables`), never `&ClassifierTables`.
#[test]
fn r14_only_the_tied_derivation_constructs_bound_tables() {
    let tied = source_of("src/private_block/token_io/classify_tied.rs");
    let lits: Vec<usize> = tied.match_indices("BoundClassifierTables {").map(|(i, _)| i).filter(|i| !tied[..*i].ends_with("struct ") && !tied[..*i].ends_with("impl ")).collect();
    assert_eq!(lits.len(), 2, "classify_tied.rs constructs BoundClassifierTables at {} places", lits.len());
    let owner = |i: usize| tied[..i].rfind("fn ").map(|f| tied[f..].split('(').next().unwrap().to_string()).unwrap();
    let mut owners: Vec<String> = lits.iter().map(|i| owner(*i)).collect();
    owners.sort();
    assert_eq!(owners, vec!["fn load_bound_tables".to_string(), "fn synthetic_for_relation_tests".to_string()]);
    let syn = tied.find("pub(crate) fn synthetic_for_relation_tests(").unwrap();
    assert!(tied[..syn].trim_end().ends_with("#[cfg(test)]\n    #[allow(clippy::too_many_arguments)]"), "the relation-test binding is not cfg(test)");
    for f in ["classify.rs", "classify_run.rs", "classify_cli.rs", "stage_in_c.rs", "stage_out_c.rs", "../run_capture.rs"] {
        let src = source_of(&format!("src/private_block/token_io/{f}"));
        assert!(!src.contains("BoundClassifierTables {"), "{f} names a BoundClassifierTables literal");
    }
    let run = source_of("src/private_block/token_io/classify_run.rs");
    let cls = source_of("src/private_block/token_io/classify.rs");
    for (src, anchor, name) in [(&run, "", "pub(crate) fn prove_classify_run_with("), (&run, "", "pub(crate) fn verify_classify_run_with("), (&run, "", "pub(crate) fn prove_classify_run("), (&run, "", "pub(crate) fn verify_classify_run("), (&cls, "impl ClassifyRunStatement {", "pub(crate) fn new("), (&cls, "impl ClassifyRunStatement {", "pub(crate) fn new_chunk(")] {
        let sig = signature(src, anchor, name);
        assert!(sig.contains("BoundClassifierTables") && !sig.contains("&ClassifierTables"), "{name} does not take bound tables: {sig}");
    }
    eprintln!("TOKEN-IO R14 | N-r13-1 | BoundClassifierTables: 2 literals (the tied loader; the cfg(test) relation binding); the six entry points take it");
}

/// **A short item's statement re-read under another length is refused**
/// (the CLI): `content_length_n` 22 edited to 23 (the chunk then holds 22 ids:
/// refused at the door), and `n` with the chunk record rewritten as a 23-id
/// item (refused: the verifier re-derives every length-dependent field, the
/// profile text naming n, the item length and the verdict row, and the
/// transcript binds n); nothing is published; the honest statement verifies.
#[test]
fn r14_a_short_items_statement_read_under_another_length_is_refused() {
    let cc = Cc::new("r14-short-len");
    let short: Vec<u64> = (9..=30).collect();
    let sd = cc.owners.join("seq");
    cc.write_seq_dir(&sd, &padded(&short, 32));
    let r = cc.root.join("short");
    assert_eq!(cc.prove_chunk(&r, &text(&short), 0, Some(sd.as_path())), 0);
    let sp = PathBuf::from(format!("{}.unverified-statement", r.display())).join("statement.json");
    let honest = std::fs::read_to_string(&sp).unwrap();
    assert!(honest.contains("\"item_length\": 31,\n \"pad_id\": 2,\n \"pad_positions\": 1,\n \"verdict_row\": 30,"), "{honest}");
    std::fs::write(&sp, honest.replacen("\"content_length_n\": 22,", "\"content_length_n\": 23,", 1)).unwrap();
    assert_eq!(cc.verify(&r, &cc.tables), 1, "n edited alone: refused");
    let as23 = honest.replacen("\"content_length_n\": 22,", "\"content_length_n\": 23,", 1).replacen("\"range\": [0, 22], \"content_total\": 22", "\"range\": [0, 23], \"content_total\": 23", 1);
    std::fs::write(&sp, &as23).unwrap();
    assert_eq!(cc.verify(&r, &cc.tables), 1, "a consistent 23-id reading: refused");
    assert!(!r.join(run_sink::STATEMENT_DIR).exists(), "nothing published");
    std::fs::write(&sp, &honest).unwrap();
    assert_eq!(cc.verify(&r, &cc.tables), 0, "the honest statement verifies");
    eprintln!("TOKEN-IO R14 | a 22-id item's statement read as n = 23 (alone, or as a consistent 23-id chunk) is refused; the honest one verifies");
}

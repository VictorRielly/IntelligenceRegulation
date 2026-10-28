//! **TOKEN I/O ROUND 12, RUNG R-C1: THE CLASSIFIER CLI END TO END.** TEST
//! CODE ONLY, public synthetic data: the native lane's tiny export (the
//! trained-calibration rung, one layer, one sequence), a generic embedding
//! whose rows at the item's ids are that sequence's x_in_L00 rows, and a
//! random int16 margin vector `w` (its negation `-w` gives the other
//! verdict on the same export). `prove` -> `verify` (the verifier publishes
//! the statement, a second verify re-checks it byte for byte) ->
//! `input-owner`; and the refusals: `--content` on the command line, a
//! verifier handed other tables (B-3), a statement whose verdict was flipped
//! consistently (the transcript binds the verdict), an unregistered policy,
//! a content control id (refused before any header), another content at the
//! owner's check. A refused verification publishes nothing.

use super::classify::*;
use super::classify_cli::{aggregate_label, classify_input_owner_command, classify_label_command, classify_prove_command, classify_verify_command, load_classifier_tables, load_export};
use super::cli::cli_stage_shape;
use super::load::ExportTokenBlocks;
use super::run::TokenBlocks;
use super::super::layout::{Ids, A_X2};
use super::classify_run::classify_headers;
use super::r3_tests::write_token_tables;
use super::tests::{generic_tables, lcg, norm};
use super::*;
use super::super::run_sink;
use super::super::trained_block::{sha256, TrainedExport};
use super::super::trained_block_tests::{write_export, Fault};
use std::path::{Path, PathBuf};

/// the rung's development policy (pre-registered, B-6)
const POLICY_RUNG_DEV: &str = "rung-tc-synthetic-policy-dev/1";

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

/// the classifier tables directory: token_io.json + embedding_int16.bin (the
/// token run's format, via R3's writer) and classifier.json + margin_int16.bin
fn write_classifier_tables(dir: &Path, t: &TokenTables, w: &[i16], bos: u64, nm: FinalNorm) {
    write_token_tables(dir, t, nm);
    let wb: Vec<u8> = w.iter().flat_map(|x| x.to_le_bytes()).collect();
    std::fs::write(dir.join("margin_int16.bin"), &wb).unwrap();
    std::fs::write(
        dir.join("classifier.json"),
        format!(
            "{{\"schema\": \"zk60-classifier-tables/1\", \"margin_vector\": {{\"dtype\": \"int16\", \"file\": \"margin_int16.bin\", \"sha256\": \"{}\", \"d\": {}}}, \"bos\": {bos}, \"final_norm\": {{\"g0\": {}, \"cn\": {}, \"tn\": {}, \"ceps\": {}}}}}\n",
            hex(&sha256(&wb)),
            w.len(),
            nm.g0,
            nm.cn,
            nm.tn,
            nm.ceps
        ),
    )
    .unwrap();
}

struct Cc {
    root: PathBuf,
    owners: PathBuf,
    export: PathBuf,
    verifier_copy: PathBuf,
    /// the margin vector `w` and its negation `-w`
    tables: PathBuf,
    tables_neg: PathBuf,
    content: String,
    identity: String,
    calls: std::cell::Cell<usize>,
    /// the generic embedding (ids 33..=36 embed to s0's rows 27..=30: D41's
    /// second chunk)
    t: TokenTables,
}

impl Cc {
    fn new(tag: &str) -> Cc {
        let root = std::env::temp_dir().join(format!("tio-cls-{tag}-{}", std::process::id()));
        let owners = std::env::temp_dir().join(format!("tio-cls-owners-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let _ = std::fs::remove_dir_all(&owners);
        std::fs::create_dir_all(&root).unwrap();
        std::fs::create_dir_all(&owners).unwrap();
        let (export, _) = write_export(&root, "tiny", &Fault::default());
        let ex = TrainedExport::load(&export).unwrap();
        let c = ex.run_constants(&ex.layers).unwrap();
        let sh = ex.shape_for(&c).unwrap();
        let (x_in, _) = ex.load_seq(&sh, "s0", 0).unwrap();
        // the item: the rung policy's template (1..=8 | content | 32) with the
        // content 9..=31, so the item is 1..=32 and each id embeds to its row
        let policy = policy_rung_dev();
        assert_eq!(policy.id, POLICY_RUNG_DEV);
        let content: Vec<u64> = (policy.prefix.len() as u64 + 1..=(sh.tokens - policy.suffix.len()) as u64).collect();
        let tokens = item_tokens(&policy, &content);
        assert_eq!(tokens, (1..=sh.tokens as u64).collect::<Vec<_>>(), "the fixture's item");
        let mut t = generic_tables(sh.width, 0x636c_6363);
        for (pos, id) in tokens.iter().enumerate() {
            let at = *id as usize * t.d;
            t.emb[at..at + t.d].copy_from_slice(&x_in[pos * sh.width..(pos + 1) * sh.width]);
        }
        for (k, id) in (33..=36usize).enumerate() {
            let row = 27 + k;
            t.emb[id * t.d..(id + 1) * t.d].copy_from_slice(&x_in[row * sh.width..(row + 1) * sh.width]);
        }
        let mut sd = 0x6d61_7267u64;
        let w: Vec<i16> = (0..sh.width).map(|_| ((lcg(&mut sd) % 65_535) as i64 - 32_767) as i16).collect();
        let wn: Vec<i16> = w.iter().map(|x| -x).collect();
        let (tables, tables_neg) = (root.join("tables"), root.join("tables-neg"));
        write_classifier_tables(&tables, &t, &w, 1, norm());
        write_classifier_tables(&tables_neg, &t, &wn, 1, norm());
        let verifier_copy = root.join("verifier-copy");
        copy_public(&export, &verifier_copy);
        let identity = hex(&load_export(&export).unwrap().model.identity());
        let content = content.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",");
        Cc { root, owners, export, verifier_copy, tables, tables_neg, content, identity, calls: std::cell::Cell::new(0), t }
    }
    fn next(&self, what: &str) -> String {
        self.calls.set(self.calls.get() + 1);
        format!("{what}-{}", self.calls.get())
    }
    /// a content file of `text`, mode 0600, in the owners' directory
    fn content_file(&self, text: &str) -> PathBuf {
        use std::io::Write;
        use std::os::unix::fs::OpenOptionsExt;
        let p = self.owners.join(format!("{}.content", self.next("c")));
        let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(&p).unwrap();
        f.write_all(text.as_bytes()).unwrap();
        p
    }
    fn owner_dir(&self, out: &Path) -> PathBuf {
        self.owners.join(format!("{}.owner-private", out.file_name().unwrap().to_string_lossy()))
    }
    fn prove_full(&self, out: &Path, tables: &Path, policy: &str, content: &str) -> i32 {
        let cf = self.content_file(content);
        let od = self.owner_dir(out);
        classify_prove_command(&s(&["--export", self.export.to_str().unwrap(), "--tables", tables.to_str().unwrap(), "--policy", policy, "--content-file", cf.to_str().unwrap(), "--seq", "s0", "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()]))
    }
    /// D41: chunk `chunk` of the whole content `content`, the activations
    /// from `seq_dir` (a prover-private directory) or the export's `s0`
    fn prove_chunk(&self, out: &Path, content: &str, chunk: usize, seq_dir: Option<&Path>) -> i32 {
        let cf = self.content_file(content);
        let od = self.owner_dir(out);
        let ck = chunk.to_string();
        let mut args = vec!["--export", self.export.to_str().unwrap(), "--tables", self.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--content-file", cf.to_str().unwrap(), "--chunk", &ck, "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()];
        match seq_dir {
            Some(d) => args.extend_from_slice(&["--seq-dir", d.to_str().unwrap()]),
            None => args.extend_from_slice(&["--seq", "s0"]),
        }
        classify_prove_command(&s(&args))
    }
    /// a prover-private sequence directory for `tokens`: x_in from the
    /// embedding, x_out from the builder on the export's block (test only)
    fn write_seq_dir(&self, dir: &Path, tokens: &[u64]) {
        let p = load_export(&self.export).unwrap();
        let sh = &p.sh;
        let d = self.t.d;
        let x_in: Vec<i16> = tokens.iter().flat_map(|id| self.t.emb[*id as usize * d..(*id as usize + 1) * d].iter().copied()).collect();
        let mut blocks = ExportTokenBlocks::new(&p);
        let blk = blocks.block(0).unwrap();
        let ssh = cli_stage_shape(sh, &p.model.layers[0].own).unwrap();
        let w = super::super::witness::build_shaped(&ssh, blk.attention(), blk.feed_forward(), &x_in).unwrap();
        let ids = Ids::new(sh).unwrap();
        let plane = &w.planes[ids.at(A_X2)];
        let x_out: Vec<i16> = (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| i16::try_from(plane[t * sh.d_pad + i]).unwrap()).collect();
        std::fs::create_dir_all(dir).unwrap();
        std::fs::write(dir.join("x_in_L00.bin"), x_in.iter().flat_map(|v| v.to_le_bytes()).collect::<Vec<u8>>()).unwrap();
        std::fs::write(dir.join("x_out_L00.bin"), x_out.iter().flat_map(|v| v.to_le_bytes()).collect::<Vec<u8>>()).unwrap();
    }
    fn label(&self, runs: &[&PathBuf]) -> i32 {
        let joined = runs.iter().map(|r| r.to_str().unwrap()).collect::<Vec<_>>().join(",");
        classify_label_command(&s(&["--export", self.verifier_copy.to_str().unwrap(), "--tables", self.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--runs", &joined, "--expect-statement", &self.identity, "--min-bits", "93"]))
    }
    fn prove(&self, out: &Path, tables: &Path) -> i32 {
        self.prove_full(out, tables, POLICY_RUNG_DEV, &self.content)
    }
    fn verify_full(&self, export: &Path, tables: &Path, out: &Path, pin: &str) -> i32 {
        classify_verify_command(&s(&["--export", export.to_str().unwrap(), "--tables", tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--artifact", out.to_str().unwrap(), "--expect-statement", pin, "--min-bits", "93"]))
    }
    fn verify(&self, out: &Path, tables: &Path) -> i32 {
        self.verify_full(&self.verifier_copy, tables, out, &self.identity)
    }
    fn input_owner(&self, out: &Path, tables: &Path, content: &str) -> i32 {
        let dec = self.owner_dir(out).join("input.dec");
        let cf = self.content_file(content);
        classify_input_owner_command(&s(&["--export", self.verifier_copy.to_str().unwrap(), "--tables", tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--artifact", out.to_str().unwrap(), "--expect-statement", &self.identity, "--decommitment", dec.to_str().unwrap(), "--content-file", cf.to_str().unwrap(), "--min-bits", "93"]))
    }
}

impl Drop for Cc {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.root);
        let _ = std::fs::remove_dir_all(&self.owners);
    }
}

fn published(out: &Path) -> String {
    std::fs::read_to_string(out.join(run_sink::STATEMENT_DIR).join("statement.json")).unwrap()
}

fn verdict_bit_of(stmt: &str) -> u8 {
    let j = super::super::trained_block::parse_json(stmt.as_bytes()).unwrap();
    j.get("verdict_bit").unwrap().i64().unwrap() as u8
}

/// **The classifier CLI end to end at BOTH verdicts** (`w` and `-w` on the
/// same export): prove (nothing published by the prover; the owner's
/// decommitment private), the verifier publishes the statement and removes
/// the unverified one, a second verify re-checks it byte for byte, the input
/// owner's check holds with the owner's content and refuses another one.
#[test]
fn r12_cli_the_classifier_proves_at_both_verdicts_the_verifier_publishes_and_the_owner_checks() {
    let cc = Cc::new("e2e");
    let mut bits = Vec::new();
    for (name, tables) in [("run-w", &cc.tables), ("run-negw", &cc.tables_neg)] {
        let out = cc.root.join(name);
        assert_eq!(cc.prove(&out, tables), 0, "prove ({name})");
        assert!(out.is_dir() && !sib(&out, ".incomplete").exists(), "the run directory is in place");
        assert!(sib(&out, ".unverified-statement").join("statement.json").is_file(), "the prover's statement is beside the run, unverified");
        assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "the prover published nothing");
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(std::fs::metadata(cc.owner_dir(&out).join("input.dec")).unwrap().permissions().mode() & 0o777, 0o600, "the owner's decommitment is private");
        }
        assert_eq!(cc.verify_full(&cc.export, tables, &out, &cc.identity), 1, "a verifier handed the export with seq_* refuses");
        assert_eq!(cc.verify_full(&cc.verifier_copy, tables, &out, &"0".repeat(64)), 1, "a wrong pin is refused");
        assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "the refusals published nothing");
        assert_eq!(cc.verify(&out, tables), 0, "verify ({name})");
        assert!(!sib(&out, ".unverified-statement").exists(), "the unverified statement is retired");
        let stmt = published(&out);
        assert!(stmt.contains("zk60_classify verify, after its fresh-process verification"), "{stmt}");
        assert!(stmt.contains(&rulings_text()), "the ruling switches are in the statement");
        assert_eq!(cc.verify(&out, tables), 0, "a second verify re-checks the published statement byte for byte");
        assert_eq!(cc.input_owner(&out, tables, &cc.content), 0, "the input owner's check");
        let other = cc.content.replacen("9,", "10,", 1);
        assert_ne!(other, cc.content);
        assert_eq!(cc.input_owner(&out, tables, &other), 1, "another content is refused by the input owner's check");
        bits.push(verdict_bit_of(&stmt));
    }
    assert_eq!(bits.len(), 2);
    assert_ne!(bits[0], bits[1], "w and -w give the two verdicts on the same export (the margin is not zero)");
    eprintln!("TOKEN-IO R-C1 CLI | prove -> verify (published) -> re-check -> input-owner at verdicts {bits:?} | refused: seq_* export, wrong pin, another content");
}

/// **The B-3 door and the bound verdict at the CLI**: a verifier handed the
/// other margin vector refuses (the statement is re-rendered from the
/// verifier's own tables); a statement whose verdict text AND bit were both
/// flipped passes the re-render and is refused by the proof (the transcript
/// absorbed the verdict); a tampered segment is refused; nothing published.
#[test]
fn r12_cli_other_tables_a_consistently_flipped_verdict_or_a_tampered_segment_are_refused() {
    let cc = Cc::new("door");
    let out = cc.root.join("run");
    assert_eq!(cc.prove(&out, &cc.tables), 0);
    assert_eq!(cc.verify(&out, &cc.tables_neg), 1, "B-3: the verifier's own margin vector is not the run's");
    assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "nothing published");
    let sp = sib(&out, ".unverified-statement").join("statement.json");
    let text = std::fs::read_to_string(&sp).unwrap();
    let b = verdict_bit_of(&text);
    let (from, to) = if b == 1 { (("\"flagged\"", "\"verdict_bit\": 1"), ("\"not-flagged\"", "\"verdict_bit\": 0")) } else { (("\"not-flagged\"", "\"verdict_bit\": 0"), ("\"flagged\"", "\"verdict_bit\": 1")) };
    let flipped = text.replacen(&format!("\"verdict\": {}", from.0), &format!("\"verdict\": {}", to.0), 1).replacen(from.1, to.1, 1);
    assert_ne!(flipped, text);
    assert_eq!(verdict_bit_of(&flipped), 1 - b);
    std::fs::write(&sp, &flipped).unwrap();
    assert_eq!(cc.verify(&out, &cc.tables), 1, "a consistently flipped verdict is refused by the proof (the transcript binds it)");
    assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "nothing published");
    std::fs::write(&sp, &text).unwrap();
    let seg = out.join(run_sink::segment_file_name(1));
    let mut bytes = std::fs::read(&seg).unwrap();
    let at = bytes.len() / 2;
    bytes[at] ^= 1;
    std::fs::write(&seg, &bytes).unwrap();
    assert_eq!(cc.verify(&out, &cc.tables), 1, "a tampered segment is refused");
    assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "nothing published");
    eprintln!("TOKEN-IO R-C1 CLI | refused, nothing published: the other margin vector (B-3), a consistently flipped verdict (transcript), a tampered segment");
}

/// **The prover's refusals**: `--content` on the command line (exit 2), an
/// unregistered policy, a content control id (refused before any header,
/// every claimed directory removed), a prove into an existing directory.
#[test]
fn r12_cli_the_prover_refuses_content_on_the_command_line_an_unknown_policy_and_a_control_id() {
    let cc = Cc::new("prover");
    let out = cc.root.join("run-a");
    assert_eq!(classify_prove_command(&s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--content", &cc.content, "--seq", "s0", "--out", out.to_str().unwrap()])), 2, "--content is refused");
    assert_eq!(cc.prove_full(&out, &cc.tables, "no-such-policy", &cc.content), 1, "an unregistered policy is refused");
    assert!(!out.exists() && !sib(&out, ".incomplete").exists() && !sib(&out, ".unverified-statement").exists() && !cc.owner_dir(&out).exists(), "every claimed directory removed");
    let h0 = classify_headers();
    let ctl = cc.content.replacen("9,", "3,", 1);
    assert_eq!(cc.prove_full(&out, &cc.tables, POLICY_RUNG_DEV, &ctl), 1, "a content control id is refused");
    assert_eq!(classify_headers(), h0, "before any header");
    assert!(!out.exists() && !cc.owner_dir(&out).exists(), "every claimed directory removed");
    let short = cc.content.replacen("9,", "", 1);
    assert_eq!(cc.prove_full(&out, &cc.tables, POLICY_RUNG_DEV, &short), 1, "a content of the wrong length is refused (n is public: B-5)");
    assert_eq!(cc.prove(&out, &cc.tables), 0);
    assert_eq!(cc.prove(&out, &cc.tables), 1, "a prove into an existing directory is refused");
    eprintln!("TOKEN-IO R-C1 CLI | refused: --content (exit 2), unknown policy, content control id (before any header), wrong length, existing directory");
}

/// **The tables loader** round-trips and refuses a margin vector that is not
/// the recorded one, a width that is not the block's, and a BOS that
/// disagrees with `token_io.json`'s.
#[test]
fn r12_cli_the_classifier_tables_loader_refuses_a_changed_margin_vector() {
    let cc = Cc::new("loader");
    let d = TrainedExport::load(&cc.export).map(|ex| ex.shape_for(&ex.run_constants(&ex.layers).unwrap()).unwrap().width).unwrap();
    let (t, bos, nm) = load_classifier_tables(&cc.tables, d).expect("the written set loads");
    assert_eq!((bos, nm), (1, norm()));
    let (tn, _, _) = load_classifier_tables(&cc.tables_neg, d).unwrap();
    assert_ne!(t.w_digest(), tn.w_digest(), "the two margin vectors differ");
    assert_eq!(t.emb_digest(), tn.emb_digest(), "on one embedding");
    assert!(load_classifier_tables(&cc.tables, d + 1).unwrap_err().contains("the block width is"));
    let mp = cc.tables.join("margin_int16.bin");
    let mut w = std::fs::read(&mp).unwrap();
    w[3] ^= 1;
    std::fs::write(&mp, &w).unwrap();
    assert!(load_classifier_tables(&cc.tables, d).unwrap_err().contains("not the recorded table"));
    let tp = cc.tables_neg.join("token_io.json");
    let tio = std::fs::read_to_string(&tp).unwrap();
    std::fs::write(&tp, tio.replacen("{\"embedding_table\"", "{\"bos\": 2, \"embedding_table\"", 1)).unwrap();
    assert!(load_classifier_tables(&cc.tables_neg, d).unwrap_err().contains("different BOS ids"));
}

// ------------------------------------------------------------------ D41: chunks (DESIGN v2.2 §13)

/// **D41 at the CLI:** a 27-id item splits into 2 chunks of 23 (overlap 4,
/// the last end-aligned: [0, 23) and [4, 27)); each chunk is proved from the
/// WHOLE content file; `verify` re-derives each range; `input-owner` checks
/// each chunk's slice of the whole content (another total refused); `label`
/// over both runs prints the OR; refused (fail-closed): a missing chunk, a
/// repeated chunk, a tampered chunk, and a chunk-1 statement re-labelled as
/// chunk 0 (the transcript binds the chunk).
#[test]
fn r12_cli_chunks_prove_verify_owner_check_and_label_fail_closed() {
    let cc = Cc::new("chunks");
    let whole = format!("{},33,34,35,36", cc.content);
    let p = policy_rung_dev();
    let chunk1: Vec<u64> = p.prefix.iter().copied().chain((13..=31).chain(33..=36)).chain(p.suffix.iter().copied()).collect();
    assert_eq!(chunk1.len(), 32);
    let sd = cc.owners.join("seq-chunk1");
    cc.write_seq_dir(&sd, &chunk1);
    let (r0, r1) = (cc.root.join("item-c0"), cc.root.join("item-c1"));
    assert_eq!(cc.prove_chunk(&r0, &whole, 0, None), 0, "chunk 0");
    assert_eq!(cc.prove_chunk(&r1, &whole, 1, Some(sd.as_path())), 0, "chunk 1");
    assert_eq!(cc.prove_chunk(&cc.root.join("item-c2"), &whole, 2, Some(sd.as_path())), 1, "no chunk 2 of 2");
    let unv = std::fs::read_to_string(sib(&r1, ".unverified-statement").join("statement.json")).unwrap();
    assert!(unv.contains("\"chunk\": {\"index\": 1, \"count\": 2, \"range\": [4, 27], \"content_total\": 27, \"chunk_size\": 23, \"overlap\": 4"), "{unv}");
    // a chunk-1 statement re-labelled consistently as chunk 0: refused by the proof
    let sp = sib(&r1, ".unverified-statement").join("statement.json");
    let relabelled = unv.replacen("\"index\": 1, \"count\": 2, \"range\": [4, 27]", "\"index\": 0, \"count\": 2, \"range\": [0, 23]", 1);
    assert_ne!(relabelled, unv);
    std::fs::write(&sp, &relabelled).unwrap();
    assert_eq!(cc.verify(&r1, &cc.tables), 1, "a chunk-1 receipt read as chunk 0 is refused");
    std::fs::write(&sp, &unv).unwrap();
    assert_eq!(cc.verify(&r0, &cc.tables), 0);
    assert_eq!(cc.verify(&r1, &cc.tables), 0);
    assert_eq!(cc.input_owner(&r1, &cc.tables, &whole), 0, "the owner's check on chunk 1's slice of the whole content");
    assert_eq!(cc.input_owner(&r0, &cc.tables, &whole), 0, "and on chunk 0's");
    assert_eq!(cc.input_owner(&r1, &cc.tables, &cc.content), 1, "a content of another total is refused");
    assert_eq!(cc.label(&[&r0, &r1]), 0, "the label over both chunks");
    assert_eq!(cc.label(&[&r1, &r0]), 0, "in any order");
    assert_eq!(cc.label(&[&r0]), 1, "a missing chunk fails closed");
    assert_eq!(cc.label(&[&r0, &r1, &r1]), 1, "a repeated chunk fails closed");
    let seg = r1.join(run_sink::segment_file_name(1));
    let mut b = std::fs::read(&seg).unwrap();
    let at = b.len() / 2;
    b[at] ^= 1;
    std::fs::write(&seg, &b).unwrap();
    assert_eq!(cc.label(&[&r0, &r1]), 1, "a chunk that does not verify fails closed");
    eprintln!("TOKEN-IO R-C1 CLI | D41: 27 ids -> chunks [0, 23) + [4, 27) proved, verified, owner-checked, labelled | fail-closed: missing, repeated, tampered chunk; re-labelled chunk refused");
}

/// **D41's aggregation rule** on its own: the OR of the verdicts over every
/// index exactly once, the same public fields; anything else refused.
#[test]
fn r12_cli_the_label_is_the_or_over_every_chunk_exactly_once() {
    let plan = ChunkPlan { size: 23, overlap: 4 };
    let c = |j: usize, total: usize| ChunkRef::derive(total, j, plan).unwrap();
    let m = [7u8; 32];
    let pol = || "rung-tc-synthetic-policy-dev/1".to_string();
    assert_eq!(aggregate_label(&[(c(0, 43), 0, pol(), m), (c(1, 43), 0, pol(), m), (c(2, 43), 0, pol(), m)]).unwrap(), 0);
    assert_eq!(aggregate_label(&[(c(2, 43), 0, pol(), m), (c(0, 43), 1, pol(), m), (c(1, 43), 0, pol(), m)]).unwrap(), 1, "any flagged chunk flags the item");
    assert!(aggregate_label(&[(c(0, 43), 0, pol(), m), (c(2, 43), 0, pol(), m)]).unwrap_err().contains("chunk 1 of 3 has no accepted proof"));
    assert!(aggregate_label(&[(c(0, 43), 0, pol(), m), (c(0, 43), 0, pol(), m), (c(1, 43), 0, pol(), m), (c(2, 43), 0, pol(), m)]).unwrap_err().contains("appears twice"));
    assert!(aggregate_label(&[(c(0, 43), 0, pol(), m), (c(1, 42), 0, pol(), m)]).unwrap_err().contains("not one item's chunks"));
    assert!(aggregate_label(&[(c(0, 27), 0, pol(), m), (c(1, 27), 0, "another/1".to_string(), m)]).unwrap_err().contains("not one item's chunks"));
    assert!(aggregate_label(&[(c(0, 27), 0, pol(), m), (c(1, 27), 0, pol(), [8u8; 32])]).unwrap_err().contains("not one item's chunks"));
    assert!(aggregate_label(&[]).is_err());
}

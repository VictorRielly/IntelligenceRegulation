//! **INDEPENDENT ADVERSARIAL REVIEW, ROUND 4 (2026-10-19): the token CLI.**
//! TEST CODE ONLY, reviewer's scratch copy only; a child of `token_io::cli`
//! so the commands' own error strings can be read (`prove_inner`,
//! `verify_inner`, `owner_inner`). Public synthetic data: the native lane's
//! tiny export (one trained-calibration layer, sequence s0) and generic
//! tables planted with its x_in_L00 rows, exactly as the lane's CLI tests.
//!
//! `REVIEW-R4 CONTROL` lines are asserted; `REVIEW-R4 FINDING` lines are
//! printed demonstrations. No privacy claim.

use super::*;
use super::super::r3_tests::write_token_tables;
use super::super::super::trained_block::sha256;
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
    vcopy: PathBuf,
    tables: PathBuf,
    t: TokenTables,
    prompt: String,
    identity: String,
}

impl H {
    fn new(tag: &str) -> H {
        let root = std::env::temp_dir().join(format!("tio-rv4-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).unwrap();
        let (export, _) = write_export(&root, "tiny", &Fault::default());
        let ex = TrainedExport::load(&export).unwrap();
        let c = ex.run_constants(&ex.layers).unwrap();
        let sh = ex.shape_for(&c).unwrap();
        let (x_in, _) = ex.load_seq(&sh, "s0", 0).unwrap();
        let tokens: Vec<u64> = (1..=sh.tokens as u64).collect();
        let mut t = generic_tables(sh.width, 0x7276_3431);
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
        H { root, export, vcopy, tables, t, prompt, identity: hex(&p.model.identity()) }
    }
    fn prove_with(&self, out: &Path, tables: &Path, prompt: &str, seq: Option<&Path>) -> Result<(), String> {
        let (ex, tb, o) = (self.export.to_str().unwrap().to_string(), tables.to_str().unwrap().to_string(), out.to_str().unwrap().to_string());
        let mut f = a(&[("--export", &ex), ("--emb", &tb), ("--head", &tb), ("--prompt", prompt), ("--out", &o)]);
        match seq {
            Some(d) => f.push(("--seq-dir".into(), d.to_str().unwrap().into())),
            None => f.push(("--seq".into(), "s0".into())),
        }
        prove_inner(&f)
    }
    fn prove(&self, out: &Path) -> Result<(), String> {
        self.prove_with(out, &self.tables, &self.prompt, None)
    }
    fn verify_with(&self, export: &Path, art: &Path, tables: &Path, pin: &str) -> Result<(), String> {
        verify_inner(&a(&[("--export", export.to_str().unwrap()), ("--emb", tables.to_str().unwrap()), ("--head", tables.to_str().unwrap()), ("--artifact", art.to_str().unwrap()), ("--expect-statement", pin), ("--min-bits", "93")]))
    }
    fn verify(&self, art: &Path) -> Result<(), String> {
        self.verify_with(&self.vcopy, art, &self.tables, &self.identity)
    }
    fn owner_with(&self, art: &Path, tables: &Path, dec: &Path) -> Result<(), String> {
        owner_inner(&a(&[("--export", self.vcopy.to_str().unwrap()), ("--emb", tables.to_str().unwrap()), ("--head", tables.to_str().unwrap()), ("--artifact", art.to_str().unwrap()), ("--expect-statement", &self.identity), ("--decommitment", dec.to_str().unwrap())]))
    }
    fn owner(&self, art: &Path) -> Result<(), String> {
        self.owner_with(art, &self.tables, &sibling(art, ".owner-private").join("output.dec"))
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
    eprintln!("REVIEW-R4 CONTROL {id} | {what} | {} | {}", outcome(r), if ok { "AS PREDICTED" } else { "NOT AS PREDICTED" });
    assert!(ok, "REVIEW-R4 {id} ({what}): {}", outcome(r));
}

fn finding(id: &str, what: &str, out: &str) {
    eprintln!("REVIEW-R4 FINDING {id} | {what} | {out}");
}

fn flip_byte(path: &Path) {
    let mut b = std::fs::read(path).unwrap();
    let at = b.len() / 2;
    b[at] ^= 1;
    std::fs::write(path, &b).unwrap();
}

// =================================================================== the pin

/// RV4-1: what `--expect-statement` pins. It is the TRAINED-MODEL identity
/// (blocks, calibration, source); the token stages' constants (embedding,
/// head, multipliers, BOS, the final norm) come from the manifests the
/// verifier is handed. A run proved with ANOTHER head (or another final
/// norm), handed to a verifier together with those tables, verifies and is
/// PUBLISHED under the same pin.
#[test]
fn rv4_1_what_the_verifier_pin_covers() {
    let h = H::new("pin");
    // tables B: the same planted embedding, every head multiplier changed
    let mut tb = h.t.clone();
    for m in tb.mult.iter_mut() {
        *m = if *m == 4096 { 1 } else { *m + 1 };
    }
    let dir_b = h.root.join("tables-b");
    write_token_tables(&dir_b, &tb, norm());
    // tables C: the same tables, another (in-class) final-norm Cn in the manifest
    let dir_c = h.root.join("tables-c");
    write_token_tables(&dir_c, &h.t, FinalNorm { cn: norm().cn / 2, ..norm() });
    for (id, what, dir) in [("RV4-1a", "a run proved with another head (every multiplier changed), verified with those tables under the SAME identity pin", &dir_b), ("RV4-1b", "a run proved with another final-norm Cn (half), verified with those tables under the SAME identity pin", &dir_c)] {
        let out = h.root.join(format!("run-{id}"));
        h.prove_with(&out, dir, &h.prompt, None).expect("the prover with the other tables");
        let r = h.verify_with(&h.vcopy, &out, dir, &h.identity);
        let published = out.join(run_sink::STATEMENT_DIR).join("statement.json");
        let txt = std::fs::read_to_string(&published).unwrap_or_default();
        let head = txt.lines().find(|l| l.contains("head_mult12_sha256") || l.contains("\"cn\"")).unwrap_or("").trim().chars().take(160).collect::<String>();
        finding("TR4-pin", what, &format!("verify {}; published: {}; statement line: {head}", outcome(&r), published.is_file()));
    }
}

// =================================================================== the owner

/// RV4-2: the owner command checks the decommitment against `<run>/statement/`
/// but does not verify the run itself. (a) After a verifier published, a
/// segment is tampered: `verify` (re-check) refuses, `owner` still answers.
/// (b) A `statement/` written by the PROVER (the unverified statement with its
/// writer line changed; no verifier ever ran): `owner` answers.
#[test]
fn rv4_2_the_owner_does_not_establish_that_the_run_verified() {
    let h = H::new("owner");
    let out = h.root.join("run");
    h.prove(&out).unwrap();
    h.verify(&out).expect("the honest verify");
    control("RV4-2", "owner after an honest verify", false, &h.owner(&out));
    flip_byte(&out.join(run_sink::segment_file_name(2)));
    control("RV4-2a", "verify (re-check) after a segment was tampered", true, &h.verify(&out));
    finding("TR4-owner", "owner after the same tampering (no re-verification by the owner)", &outcome(&h.owner(&out)));
    let out2 = h.root.join("run2");
    h.prove(&out2).unwrap();
    let un = unverified_dir(&out2).join("statement.json");
    let forged = std::fs::read_to_string(&un).unwrap().replace(Writer::Unverified.text(), Writer::FreshVerify.text());
    let sd = out2.join(run_sink::STATEMENT_DIR);
    std::fs::create_dir(&sd).unwrap();
    std::fs::write(sd.join("statement.json"), forged).unwrap();
    std::fs::write(sd.join("segments.json"), b"not the hashes of anything\n").unwrap();
    finding("TR4-owner", "owner over a statement/ the PROVER wrote (writer line changed; no verifier ran)", &outcome(&h.owner(&out2)));
    control("RV4-2b", "verify (re-check) over the prover-written statement/", true, &h.verify(&out2));
}

// =================================================================== refusal texts

/// RV4-3: refusal texts echo no hidden value: a prompt with a non-BOS first
/// id, an id outside the vocabulary, a malformed list; the owner given the
/// input decommitment; a verifier given a tampered segment.
#[test]
fn rv4_3_refusal_texts_echo_no_hidden_value() {
    let h = H::new("texts");
    let mut ids: Vec<String> = h.prompt.split(',').map(|s| s.to_string()).collect();
    let mut nobos = ids.clone();
    nobos[0] = "263".into();
    let r = h.prove_with(&h.root.join("r-nobos"), &h.tables, &nobos.join(","), None);
    let e = r.clone().unwrap_err();
    control("RV4-3a", "prompt whose position 0 is 263 (not BOS)", true, &r);
    assert!(!e.contains("263"), "the refusal echoes the hidden id: {e}");
    ids[5] = "4321".into();
    let r = h.prove_with(&h.root.join("r-oov"), &h.tables, &ids.join(","), None);
    let e = r.clone().unwrap_err();
    control("RV4-3b", "prompt with id 4321 >= V", true, &r);
    assert!(!e.contains("4321"), "the refusal echoes the hidden id: {e}");
    let r = h.prove_with(&h.root.join("r-bad"), &h.tables, "1,2,x9y,4", None);
    let e = r.clone().unwrap_err();
    control("RV4-3c", "a malformed prompt list (an entry x9y)", true, &r);
    assert!(!e.contains("x9y"), "the refusal echoes the prompt text: {e}");
    for d in ["r-nobos", "r-oov", "r-bad"] {
        let o = h.root.join(d);
        assert!(!o.exists() && !sibling(&o, ".incomplete").exists() && !sibling(&o, ".owner-private").exists() && !unverified_dir(&o).exists(), "a refused prove left something behind: {d}");
    }
    let out = h.root.join("run");
    h.prove(&out).unwrap();
    h.verify(&out).unwrap();
    let r = h.owner_with(&out, &h.tables, &sibling(&out, ".owner-private").join("input.dec"));
    control("RV4-3d", "owner given the INPUT decommitment", true, &r);
    let ok_tok = {
        let d = Decommitment::from_bytes(&std::fs::read(sibling(&out, ".owner-private").join("output.dec")).unwrap()).unwrap();
        d.data[0].0
    };
    let e = r.unwrap_err();
    eprintln!("REVIEW-R4 TEXT | owner refusal text: {e} | the hidden token {ok_tok} in it: {}", e.contains(&format!(" {ok_tok} ")) || e.ends_with(&format!(" {ok_tok}")));
}

// =================================================================== partial runs and placement

/// RV4-4: a prove refused MID-RUN (parity fails at block 0, after stage IN's
/// segment was written) leaves nothing behind; the owners' decommitments are
/// outside the run directory, files 0600 (the directory's own mode printed);
/// a prove whose owner-private sibling already exists is refused.
#[test]
fn rv4_4_partial_runs_and_where_the_decommitments_go() {
    let h = H::new("partial");
    // a prover-private seq dir whose x_out_L00 disagrees with the native output
    let bad = h.root.join("seq-bad");
    copy_dir(&h.export.join("seq_s0"), &bad);
    let xo = bad.join("x_out_L00.bin");
    let orig = std::fs::read(&xo).expect("seq_s0/x_out_L00.bin");
    let mut b = orig.clone();
    b[10] ^= 1;
    std::fs::write(&xo, &b).unwrap();
    // keep the sequence manifest's SHA-256 consistent, so the refusal is the
    // PARITY check inside the run (after stage IN's segment), not the loader
    let man = bad.join("manifest.json");
    let text = std::fs::read_to_string(&man).unwrap();
    let (old, new) = (hex(&sha256(&orig)), hex(&sha256(&b)));
    assert!(text.contains(&old), "the sequence manifest does not record x_out_L00.bin's SHA-256 as hex");
    std::fs::write(&man, text.replace(&old, &new)).unwrap();
    let out = h.root.join("run-partial");
    let r = h.prove_with(&out, &h.tables, &h.prompt, Some(&bad));
    control("RV4-4a", "a prove refused mid-run (parity at block 0, after stage IN's segment)", true, &r);
    let left: Vec<String> = [out.clone(), sibling(&out, ".incomplete"), unverified_dir(&out), sibling(&out, ".owner-private")].iter().filter(|p| p.exists()).map(|p| p.display().to_string()).collect();
    eprintln!("REVIEW-R4 PARTIAL | refusal: {} | left behind: {left:?}", r.unwrap_err().chars().take(160).collect::<String>());
    assert!(left.is_empty(), "a refused prove left {left:?}");
    let out = h.root.join("run");
    h.prove(&out).unwrap();
    let names: Vec<String> = std::fs::read_dir(&out).unwrap().map(|e| e.unwrap().file_name().to_string_lossy().to_string()).collect();
    assert!(names.iter().all(|n| n.starts_with("segment-")), "the run directory holds something other than segments: {names:?}");
    use std::os::unix::fs::PermissionsExt;
    let od = sibling(&out, ".owner-private");
    let dm = std::fs::metadata(&od).unwrap().permissions().mode() & 0o777;
    let fm: Vec<u32> = ["input.dec", "output.dec"].iter().map(|n| std::fs::metadata(od.join(n)).unwrap().permissions().mode() & 0o777).collect();
    finding("TR4-place", "where prove puts the owners' decommitments", &format!("the run directory holds only {} segment files; `<out>.owner-private/` is a SIBLING in the same parent, directory mode {dm:o}, files {:o} / {:o}", names.len(), fm[0], fm[1]));
    assert_eq!(fm, vec![0o600, 0o600]);
    let out3 = h.root.join("run3");
    std::fs::create_dir(sibling(&out3, ".owner-private")).unwrap();
    control("RV4-4b", "a prove whose <out>.owner-private already exists", true, &h.prove(&out3));
    assert!(!out3.exists() && !sibling(&out3, ".incomplete").exists());
}

// =================================================================== the wrong export, races

/// RV4-5: a verifier handed another export (another variant name, otherwise
/// identical) with its own pin, or with the run's pin; and two verifiers
/// racing to publish one run (two threads of one process).
#[test]
fn rv4_5_wrong_export_and_a_publication_race() {
    let h = H::new("race");
    let out = h.root.join("run");
    h.prove(&out).unwrap();
    let (other, _) = write_export(&h.root.join("other"), "tiny-other", &Fault::default());
    let ocopy = h.root.join("other-copy");
    copy_public(&other, &ocopy);
    let oid = hex(&ExportPublic::load(&other).unwrap().model.identity());
    control("RV4-5a", "a verifier with another export (variant tiny-other) and the run's pin", true, &h.verify_with(&ocopy, &out, &h.tables, &h.identity));
    control("RV4-5b", "a verifier with another export and ITS OWN pin", true, &h.verify_with(&ocopy, &out, &h.tables, &oid));
    assert!(!out.join(run_sink::STATEMENT_DIR).exists(), "a refused verify published");
    let (h1, h2) = (std::sync::Arc::new(h), ());
    let _ = h2;
    let out1 = out.clone();
    let ha = h1.clone();
    let t1 = std::thread::spawn(move || ha.verify(&out1));
    let hb = h1.clone();
    let out2 = out.clone();
    let t2 = std::thread::spawn(move || hb.verify(&out2));
    let (r1, r2) = (t1.join().unwrap(), t2.join().unwrap());
    eprintln!("REVIEW-R4 RACE | two verifiers at once: {} | {}", outcome(&r1), outcome(&r2));
    assert!(r1.is_ok() || r2.is_ok(), "neither racing verifier succeeded");
    control("RV4-5c", "after the race: exactly one statement/, which re-checks", false, &h1.verify(&out));
    let names: Vec<String> = std::fs::read_dir(&out).unwrap().map(|e| e.unwrap().file_name().to_string_lossy().to_string()).filter(|n| !n.starts_with("segment-")).collect();
    eprintln!("REVIEW-R4 RACE | non-segment entries left in the run directory: {names:?}");
    assert_eq!(names, vec![run_sink::STATEMENT_DIR.to_string()], "the race left {names:?}");
}

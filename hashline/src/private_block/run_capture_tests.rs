//! **STAGE 14: the tests of the RUN CAPTURE.**
//!
//! What they establish, and nothing more: a three-block run at the
//! development rung is captured; the recorder's INDEPENDENT replay re-derives
//! every challenge of the whole run and refuses on the first mismatch; no
//! bundle exists for a run the verifier did not accept; every key a bundle
//! contains is on the declared allow-list; and a run verifies identically with
//! a recorder attached and with none, on the same segment bytes.
//!
//! **A capture is not a gate.** Nothing here says anything about privacy: the
//! tools that would read a bundle are the Python joint-view gates, they have
//! never seen a run, and ruling M-8 is not met by writing the input to it.

use super::layout::*;
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::run_capture::{self, Bundle};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::{prepare_endpoints, AttentionPublic, BlockPublic, Endpoints, FeedForwardPublic, IoSpec};
use crate::merkle::Digest;
use std::path::{Path, PathBuf};

fn run_context() -> Digest {
    *blake3::hash(b"stage 14: the run capture's own test context").as_bytes()
}

fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// The honest chain of `l` blocks, exactly as `run_tests.rs` builds one: the
/// hidden inputs and the `l + 1` padded planes the run's IO commitments carry.
/// None of it reaches a capture.
struct Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl Chain {
    fn honest(sh: &Shape, l: usize, zero: bool) -> Chain {
        let (public, ff, tame) = super::grow_tests::tame_case(sh);
        let ids = Ids::new(sh).expect("the shape has a plane map");
        let mut inputs = Vec::with_capacity(l);
        let mut planes = Vec::with_capacity(l + 1);
        let mut x = if zero { vec![0i16; sh.tokens * sh.width] } else { tame };
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness of the chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().expect("the block's hidden output"));
        }
        Chain { sh: sh.clone(), public, ff, inputs, planes }
    }
}

impl RunWitnessSource for Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

fn blocks_of(sh: &Shape, l: usize) -> Vec<BlockPublic> {
    (0..l)
        .map(|_| {
            let (public, ff, _) = super::grow_tests::tame_case(sh);
            BlockPublic::new(public, ff)
        })
        .collect()
}

fn statement_of(c: &Chain, l: usize, blocks: &[BlockPublic]) -> (RunStatement, Endpoints) {
    let rs = RunShape::rung_g(l).expect("the rung-G run shape");
    let spec = IoSpec::new_shaped(&c.sh, run_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &c.planes[0], &c.planes[l]).expect("the run's external endpoint owners");
    let st = RunStatement::new(rs, run_context(), expected, blocks, &vec![(0, 0); l]).expect("the run statement");
    (st, owners)
}

fn prove_to_vec(st: &RunStatement, blocks: &[BlockPublic], src: &mut dyn RunWitnessSource, owners: Endpoints) -> Vec<Vec<u8>> {
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(st, blocks, src, owners, &mut |k, b| {
        assert_eq!(k, segs.len(), "the sink was handed the segments out of order");
        segs.push(b);
        Ok(())
    })
    .expect("the honest run proves");
    segs
}

/// Prove an honest `l`-block rung-G run and CAPTURE its verification.
fn prove_and_capture(l: usize, zero: bool) -> (Vec<Vec<u8>>, Bundle) {
    let sh = Shape::rung_g();
    let mut c = Chain::honest(&sh, l, zero);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    let segs = prove_to_vec(&st, &blocks, &mut c, owners);
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run(st.capture_header().expect("the run's capture header"), st.binding().expect("the run binding"));
    run::verify_run(&st, &blocks, &segs).expect("the honest run verifies");
    let bundle = run_capture::take().expect("a bundle for an accepted run");
    drop(guard);
    (segs, bundle)
}

fn count(haystack: &[u8], needle: &str) -> usize {
    let n = needle.as_bytes();
    if n.is_empty() || haystack.len() < n.len() {
        return 0;
    }
    (0..=haystack.len() - n.len()).filter(|i| &haystack[*i..*i + n.len()] == n).count()
}

fn contains(haystack: &[u8], needle: &str) -> bool {
    count(haystack, needle) > 0
}

struct TempDir(PathBuf);

impl TempDir {
    fn new(tag: &str) -> TempDir {
        let p = std::env::temp_dir().join(format!("zk60-run-capture-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&p);
        TempDir(p)
    }
    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

// ---------------------------------------------------------------- the acceptance

/// **THE CAPTURE OF A THREE-BLOCK RUN AT THE DEVELOPMENT RUNG** — the geometry
/// ruling M-8 names. The bundle is written, read back and checked file by
/// file: every file listed in the manifest with its length and SHA-256, the
/// schema version, the stage count, and the sizes that are functions of the
/// shape (twenty-three slots a stage, `256` opened columns per opening,
/// `1024 + 256` entries in every group and proximity vector, two internal
/// boundaries of ten rows with their two reserved pairs).
///
/// It reports the bundle's size, which is the number that decides whether a
/// gate bundle can be committed.
#[test]
fn a_three_block_rung_g_run_is_captured_and_the_bundle_is_self_consistent() {
    let sh = Shape::rung_g();
    let (segs, bundle) = prove_and_capture(3, false);
    assert_eq!(bundle.l, 3);
    assert_eq!(bundle.stages.len(), 3, "one file per stage");
    // the run file: the schema, the shape as DATA, and the two boundaries
    let run = &bundle.run_json;
    assert!(contains(run, "\"schema\":\"hashline-native-capture/4-run\""), "the run file does not declare the run schema");
    assert!(contains(run, "\"kind\":\"zk60-run-verifier-observations\""));
    assert!(contains(run, &format!("\"profile\":\"{}\"", bundle.profile)));
    for (field, value) in [("tokens", sh.tokens), ("width", sh.width), ("hidden", sh.hidden), ("q_heads", sh.q_heads), ("kv_heads", sh.kv_heads), ("head_dim", sh.head_dim), ("log_cols", sh.log_cols), ("opened_cols", sh.opened_cols), ("endpoint_rows", sh.endpoint_rows)] {
        assert!(contains(run, &format!("\"{field}\":{value}")), "the run file does not carry the shape's {field}");
    }
    assert_eq!(count(run, "\"row_rule\":"), 2, "a three-block run has two internal boundaries");
    assert_eq!(count(run, "\"statement_digest\":"), 2);
    // the derived boundary geometry of ruling M-1 at the rung-G plane:
    // 4 data rows + 2*2 site rows + 2 proximity rows = 10
    assert!(contains(run, "\"data_rows\":4,\"rows\":10,\"site_rows\":[4, 5, 6, 7],\"prox_row\":8"), "the boundary geometry is not the derived one");
    assert!(contains(run, "\"transcript_labels\":") && contains(run, "\"pb-run-stage\""), "the run file does not carry the transcript labels as data");
    // per stage
    let q = sh.opened_cols;
    for (k, stage) in bundle.stages.iter().enumerate() {
        let roles = if k + 1 == 3 { 4 } else { 3 };
        assert_eq!(count(stage, "\"definition_challenges\":"), N_SLOTS, "stage {k} does not carry twenty-three slot transcripts");
        assert_eq!(count(stage, "\"row_roles\":"), roles, "stage {k} does not carry {roles} openings");
        assert_eq!(count(stage, "\"salt\":"), q * (roles + 1), "stage {k} does not carry {q} opened columns per opening (the M opening and {roles} commitments)");
        assert_eq!(count(stage, "\"proximity_vector\":"), roles);
        assert!(contains(stage, &format!("\"stage\":{k},")), "stage {k} is not labelled");
        assert!(contains(stage, "\"commitment_kind\":\"block\""));
        let boundary_openings = count(stage, "\"commitment_kind\":\"internal-boundary\"");
        assert_eq!(boundary_openings, usize::from(k > 0), "stage {k} opens {boundary_openings} boundaries");
        assert_eq!(count(stage, "\"commitment_kind\":\"external-endpoint\""), usize::from(k == 0) + usize::from(k + 1 == 3));
        assert!(contains(stage, &format!("\"segment_bytes\":{}", segs[k].len())), "stage {k} does not carry its segment's length");
        assert!(contains(stage, &format!("\"segment_sha256\":\"{}\"", crate::export_v3::sha256_hex(&segs[k]))), "stage {k} is not pinned to the bytes that were verified");
    }
    // the bundle on disk, read back
    let dir = TempDir::new("l3");
    run_capture::write_bundle(dir.path(), &bundle, &segs, "A self-consistency test bundle; deleted when the test ends.", "cargo test --lib private_block::run_capture_tests").expect("the bundle is written");
    let manifest = std::fs::read(dir.path().join("manifest.json")).expect("a manifest");
    let mut names: Vec<String> = vec!["run.json".into(), "stage-00.json".into(), "stage-01.json".into(), "stage-02.json".into(), "README.md".into()];
    if run_capture::segments_wanted() {
        names.extend((0..3).map(|k| format!("segments/segment-{k:02}.bin")));
    }
    let mut total = 0usize;
    for name in &names {
        let bytes = std::fs::read(dir.path().join(name)).unwrap_or_else(|e| panic!("{name}: {e}"));
        let sha = crate::export_v3::sha256_hex(&bytes);
        assert!(contains(&manifest, &format!("{{\"file\":\"{name}\",\"bytes\":{},\"sha256\":\"{sha}\"}}", bytes.len())), "{name} is not in the manifest with its own length and digest");
        total += bytes.len();
    }
    assert_eq!(count(&manifest, "\"sha256\":"), names.len() + run_capture::SOURCE_FILES.len(), "the manifest does not pin every file and every source file");
    assert_eq!(dir.path().join("segments").exists(), run_capture::segments_wanted(), "the segments are written exactly when they are asked for");
    eprintln!(
        "RUN CAPTURE L=3 at the rung-G shape: run.json {} B, stages {:?} B, bundle on disk {total} B ({:.1} MB); segments {} B ({}); public tables carried as length + digest only",
        bundle.run_json.len(),
        bundle.stages.iter().map(|s| s.len()).collect::<Vec<_>>(),
        total as f64 / 1e6,
        segs.iter().map(|s| s.len()).sum::<usize>(),
        if run_capture::segments_wanted() { "included" } else { "pinned by digest, not written" }
    );
}

/// **THE ALLOW-LIST.** A retained capture counts as publishing, so the writer
/// may emit only the declared fields. This fails if a key outside the
/// allow-list ever appears in any file of a bundle — the test that has to be
/// re-read whenever the writer grows a field.
#[test]
fn every_key_of_a_bundle_is_on_the_allow_list() {
    let (segs, bundle) = prove_and_capture(2, false);
    let dir = TempDir::new("keys");
    run_capture::write_bundle(dir.path(), &bundle, &segs, "An allow-list test bundle.", "cargo test").expect("the bundle is written");
    let mut checked = 0usize;
    for name in ["run.json", "stage-00.json", "stage-01.json", "manifest.json"] {
        let bytes = std::fs::read(dir.path().join(name)).expect("a bundle file");
        for key in run_capture::keys_of(&bytes) {
            assert!(run_capture::ALLOWED_KEYS.contains(&key.as_str()), "{name} carries the field {key:?}, which is not on the capture allow-list");
            checked += 1;
        }
    }
    assert!(checked > 1000, "only {checked} fields were scanned; the scanner is not reading the bundle");
    // and the words a capture must never contain, by name. `run.json`'s own
    // declaration of what it does NOT contain is the one place those words
    // legitimately appear, so the scan stops where it begins.
    for name in ["run.json", "stage-00.json", "stage-01.json"] {
        let bytes = std::fs::read(dir.path().join(name)).expect("a bundle file");
        let end = (0..bytes.len()).find(|i| bytes[*i..].starts_with(b"\"not_in_a_capture\"")).unwrap_or(bytes.len());
        // ("hidden" alone is not one of them: `"hidden":192` is the shape's
        // feed-forward width, a public number.)
        for forbidden in ["witness", "plaintext", "hidden_input", "hidden_plane", "plane_values", "mask_coefficient", "unopened", "ZkRng", "seed", "secret"] {
            assert!(!contains(&bytes[..end], forbidden), "{name} contains the word {forbidden:?}");
        }
    }
}

/// **NO BUNDLE FOR A RUN THE VERIFIER DID NOT ACCEPT.** A single flipped bit
/// in the last segment is rejected by the verifier; the recorder then refuses
/// to hand over a bundle, naming how many stages closed, and nothing is
/// written.
#[test]
fn a_tampered_run_is_refused_and_no_bundle_is_written() {
    let sh = Shape::rung_g();
    let l = 2;
    let mut c = Chain::honest(&sh, l, false);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    let mut segs = prove_to_vec(&st, &blocks, &mut c, owners);
    let last = segs[l - 1].len() - 1;
    segs[l - 1][last] ^= 1;
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run(st.capture_header().expect("the capture header"), st.binding().expect("the run binding"));
    let verdict = run::verify_run(&st, &blocks, &segs);
    assert!(verdict.is_err(), "the tampered run was accepted");
    let refusal = match run_capture::take() {
        Ok(b) => panic!("a tampered run produced a bundle of {} stages", b.stages.len()),
        Err(e) => e,
    };
    assert!(refusal.contains("did not accept") || refusal.contains("replay"), "the refusal does not say why: {refusal}");
    drop(guard);
    // and the capture is gone: a second take finds no recorder at all
    assert!(run_capture::take().is_err());
}

/// **THE RECORDER'S REPLAY IS LOAD-BEARING.** Seed it with a header that is
/// not the verifier's (one word of the run statement changed) and it refuses
/// at the first comparison instead of writing a bundle that describes a
/// different run.
#[test]
fn the_replay_refuses_a_header_that_is_not_the_verifiers() {
    let sh = Shape::rung_g();
    let l = 2;
    let mut c = Chain::honest(&sh, l, false);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    let segs = prove_to_vec(&st, &blocks, &mut c, owners);
    let mut header = st.capture_header().expect("the capture header");
    header.calibration[0] ^= 1;
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run(header, st.binding().expect("the run binding"));
    run::verify_run(&st, &blocks, &segs).expect("the honest run still verifies");
    let refusal = match run_capture::take() {
        Ok(_) => panic!("a header the recorder cannot rebuild produced a bundle"),
        Err(e) => e,
    };
    assert!(refusal.contains("binding") || refusal.contains("transcript"), "the refusal does not name the replay: {refusal}");
    drop(guard);
}

/// **A RECORDER OBSERVES, IT NEVER PARTICIPATES.** The same segment bytes
/// verify with a recorder attached and with none, and the verdict, the
/// segments and the run's closing check are identical either way.
#[test]
fn a_run_verifies_the_same_with_and_without_a_recorder() {
    let sh = Shape::rung_g();
    let l = 2;
    let mut c = Chain::honest(&sh, l, false);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    let segs = prove_to_vec(&st, &blocks, &mut c, owners);
    let before = segs.clone();
    // with none
    run::verify_run(&st, &blocks, &segs).expect("the run verifies with no recorder");
    // with one
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run(st.capture_header().expect("the capture header"), st.binding().expect("the run binding"));
    run::verify_run(&st, &blocks, &segs).expect("the run verifies with a recorder");
    let bundle = run_capture::take().expect("a bundle");
    drop(guard);
    // and with none again, on the very same bytes
    run::verify_run(&st, &blocks, &segs).expect("the run verifies with no recorder, after a capture");
    assert_eq!(segs, before, "a recorder changed a segment");
    assert_eq!(bundle.stages.len(), l);
    // a rejected run is rejected identically either way
    let mut bad = segs.clone();
    bad[0][40] ^= 1;
    let without = run::verify_run(&st, &blocks, &bad).expect_err("the tampered run is rejected");
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run(st.capture_header().expect("the capture header"), st.binding().expect("the run binding"));
    let with = run::verify_run(&st, &blocks, &bad).expect_err("the tampered run is rejected with a recorder too");
    run_capture::discard();
    drop(guard);
    assert_eq!(without, with, "a recorder changed a refusal");
}

/// **THE SOURCE PINS** a bundle carries: every file whose bytes decide what a
/// capture contains, with its SHA-256 at capture time.
#[test]
fn the_bundle_pins_every_source_file_that_decides_its_contents() {
    let pins = run_capture::source_pins().expect("the source pins");
    assert_eq!(pins.len(), run_capture::SOURCE_FILES.len());
    for (name, sha) in &pins {
        assert_eq!(sha.len(), 64, "{name}'s pin is not a SHA-256");
        assert!(sha.bytes().all(|b| b.is_ascii_hexdigit()));
    }
    assert!(pins.iter().any(|(n, _)| n.ends_with("run_capture.rs")), "the writer does not pin itself");
}

// ---------------------------------------------------------------- the gate bundles

/// **WRITE THE TWO GATE BUNDLES** of ruling M-8, into `HL_RUN_CAPTURE_DIR`.
/// `#[ignore]`d because it writes a directory of evidence and must be asked
/// for by name; the command is in the lane ledger's stage 14 section.
///
/// Two INDEPENDENT honest three-block runs at the development rung, each with
/// fresh OS randomness and its own external endpoints: the first on the lane
/// fixture's tame hidden input, the second on the all-zero hidden input, so
/// that the Python side has two runs of the same public statement shape whose
/// hidden values differ.
#[test]
#[ignore = "writes the gate bundles; set HL_RUN_CAPTURE_DIR"]
fn write_the_gate_bundles() {
    let root = PathBuf::from(std::env::var("HL_RUN_CAPTURE_DIR").expect("HL_RUN_CAPTURE_DIR is not set: this test writes a directory of evidence and will not choose one for you"));
    let mut total = 0usize;
    for (tag, zero) in [("run-a-tame", false), ("run-b-zero", true)] {
        let (segs, bundle) = prove_and_capture(3, zero);
        let dir = root.join(tag);
        let note = format!(
            "Bundle `{tag}`: one honest three-block run at the development rung\n(`Shape::rung_g`: 24 tokens, width 96, hidden 192, 6 query heads over 2\nkey-value heads), hidden input = {}. Fresh OS randomness; the public weights\nare the lane's synthetic tame fixture. This is the geometry ruling M-8 names\nfor the run privacy gate.",
            if zero { "the all-zero plane" } else { "the lane fixture's tame plane" }
        );
        run_capture::write_bundle(&dir, &bundle, &segs, &note, "HL_RUN_CAPTURE_DIR=<dir> cargo test --release --lib private_block::run_capture_tests::write_the_gate_bundles -- --ignored --nocapture").expect("the gate bundle is written");
        let n: usize = std::fs::read_dir(&dir).expect("the bundle directory").filter_map(|e| e.ok()).map(|e| e.metadata().map(|m| m.len() as usize).unwrap_or(0)).sum();
        total += n;
        eprintln!("GATE BUNDLE {tag}: {} B run file, {} B of stage files, {} B of segments (pinned by digest; written only with HL_RUN_CAPTURE_SEGMENTS=1), {n} B on disk ({:.1} MB)", bundle.run_json.len(), bundle.stages.iter().map(|s| s.len()).sum::<usize>(), segs.iter().map(|s| s.len()).sum::<usize>(), n as f64 / 1e6);
    }
    eprintln!("GATE BUNDLES total about {:.1} MB in {}", total as f64 / 1e6, root.display());
}

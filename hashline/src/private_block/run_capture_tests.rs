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
use super::plane_index::{self, Ref};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::run_capture::{self, Bundle};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::{prepare_endpoints, AttentionPublic, BlockPublic, Endpoints, FeedForwardPublic, IoSpec};
// STAGE 23 (gap GS-2): the refusal replay is driven over recorded field
// elements, so the test half of this module needs the base field.
use crate::field::{Fp, Fp2};
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
        Chain::from_parts(sh, l, public, ff, if zero { vec![0i16; sh.tokens * sh.width] } else { tame })
    }
    /// **STAGE 21.** The same honest chain from ANY public weights and any
    /// first hidden input, so the fully dense recipe drives a capture through
    /// this module's harness rather than a second one.
    fn from_parts(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> Chain {
        let ids = Ids::new(sh).expect("the shape has a plane map");
        let mut inputs = Vec::with_capacity(l);
        let mut planes = Vec::with_capacity(l + 1);
        let mut x = x0;
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
    statement_of_at(c, l, blocks, RunShape::rung_g(l).expect("the rung-G run shape"))
}

/// **STAGE 22.** The same statement at ANY run shape, so that the
/// four-key-value-head profile drives this module's capture harness rather
/// than a second one. `statement_of` is this at `RunShape::rung_g`.
fn statement_of_at(c: &Chain, l: usize, blocks: &[BlockPublic], rs: RunShape) -> (RunStatement, Endpoints) {
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

/// **STAGE 21.** Prove and capture an honest `l`-block rung-G run on the
/// FULLY DENSE recipe at its measured chain band — every entry of all nine
/// public words nonzero, a non-constant hidden input, and the key-value
/// groups carrying DIFFERENT data, which is the regime finding S19-F1
/// rejected outright and which no capture has ever been taken in.
fn prove_and_capture_dense(l: usize) -> (Vec<Vec<u8>>, Bundle) {
    let sh = Shape::rung_g();
    let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
    let blocks = blocks_from(&public, &ff, l);
    let mut c = Chain::from_parts(&sh, l, public, ff, x0);
    let (st, owners) = statement_of(&c, l, &blocks);
    let segs = prove_to_vec(&st, &blocks, &mut c, owners);
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run(st.capture_header().expect("the run's capture header"), st.binding().expect("the run binding"));
    run::verify_run(&st, &blocks, &segs).expect("the honest fully dense run verifies");
    let bundle = run_capture::take().expect("a bundle for an accepted run");
    drop(guard);
    (segs, bundle)
}

/// **STAGE 22.** Prove and capture an honest `l`-block run at
/// `Shape::rung_k4` — twelve query heads of eight over FOUR key-value heads,
/// so the repaired bilinear slots sum over TWO group bits and their public
/// `eq(r_g, .)` factor carries a two-element point. `dense` takes the fully
/// dense run recipe with a generic hidden input; otherwise it is the
/// all-zero input on the tame fixture, the degenerate case.
fn prove_and_capture_k4(l: usize, dense: bool) -> (Vec<Vec<u8>>, Bundle) {
    let sh = Shape::rung_k4();
    let (public, ff, x0) = if dense {
        super::dense_tests::dense_run_case(&sh)
    } else {
        let (p, f, _) = super::grow_tests::tame_case(&sh);
        (p, f, vec![0i16; sh.tokens * sh.width])
    };
    let blocks = blocks_from(&public, &ff, l);
    let mut c = Chain::from_parts(&sh, l, public, ff, x0);
    let (st, owners) = statement_of_at(&c, l, &blocks, RunShape::rung_k4(l).expect("the rung-K4 run shape"));
    let segs = prove_to_vec(&st, &blocks, &mut c, owners);
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run(st.capture_header().expect("the run's capture header"), st.binding().expect("the run binding"));
    run::verify_run(&st, &blocks, &segs).expect("the honest rung-K4 run verifies");
    let bundle = run_capture::take().expect("a bundle for an accepted run");
    drop(guard);
    (segs, bundle)
}

/// the run's `l` public blocks from ONE pair of statements
fn blocks_from(public: &AttentionPublic, ff: &FeedForwardPublic, l: usize) -> Vec<BlockPublic> {
    (0..l).map(|_| BlockPublic::new(public.clone(), ff.clone())).collect()
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

// ---------------------------------------------------------------- reading a bundle's JSON

/// Where the `i`-th occurrence of `needle` starts.
fn find_nth(haystack: &[u8], needle: &str, i: usize) -> usize {
    let n = needle.as_bytes();
    assert!(haystack.len() >= n.len(), "the file is shorter than {needle:?}");
    let mut seen = 0usize;
    for p in 0..=haystack.len() - n.len() {
        if &haystack[p..p + n.len()] == n {
            if seen == i {
                return p;
            }
            seen += 1;
        }
    }
    panic!("the file has {seen} occurrences of {needle:?}, not {}", i + 1);
}

/// The number of top-level elements of the `i`-th `"<key>":[ … ]` array. The
/// writer emits no string containing a bracket inside the arrays this reads
/// (`terminals` is `Fp2` pairs), so a depth count over the brackets is exact.
fn array_len(bytes: &[u8], key: &str, i: usize) -> usize {
    let pat = format!("\"{key}\":[");
    let mut j = find_nth(bytes, &pat, i) + pat.len();
    let (mut depth, mut items, mut any) = (0usize, 0usize, false);
    loop {
        match bytes[j] {
            b'[' | b'{' => depth += 1,
            b']' if depth == 0 => break,
            b']' | b'}' => depth -= 1,
            b',' if depth == 0 => items += 1,
            _ => {}
        }
        any = true;
        j += 1;
    }
    if any {
        items + 1
    } else {
        0
    }
}

/// The `"<key>": { … }` member, key included, from the key to the matching
/// brace. Used on the plane index table, none of whose strings holds a brace.
fn object(bytes: &[u8], key: &str) -> Vec<u8> {
    let pat = format!("\"{key}\":{{");
    let start = find_nth(bytes, &pat, 0);
    let mut j = start + pat.len() - 1;
    let mut depth = 0usize;
    loop {
        match bytes[j] {
            b'{' => depth += 1,
            b'}' => {
                depth -= 1;
                if depth == 0 {
                    return bytes[start..=j].to_vec();
                }
            }
            _ => {}
        }
        j += 1;
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
    assert_eq!(count(&manifest, "\"sha256\":"), names.len() + run_capture::source_files().len(), "the manifest does not pin every file and every source file");
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
    assert_eq!(pins.len(), run_capture::source_files().len());
    for (name, sha) in &pins {
        assert_eq!(sha.len(), 64, "{name}'s pin is not a SHA-256");
        assert!(sha.bytes().all(|b| b.is_ascii_hexdigit()));
    }
    assert!(pins.iter().any(|(n, _)| n.ends_with("run_capture.rs")), "the writer does not pin itself");
    assert!(pins.iter().any(|(n, _)| n.ends_with("plane_index.rs")), "the plane index table's own source is not pinned");
    assert!(pins.iter().any(|(n, _)| n.ends_with("shape.rs")), "the hash tag's own source is not pinned");
}

/// **STAGE 17 (ruling T-1 / T-7): the run file NAMES the hash rule that made
/// the bundle**, and the capture's own independently rebuilt header matched
/// the verifier's binding under that rule.
///
/// The second half is the load-bearing one and it needs no assertion of its
/// own: `begin_run` rebuilds the run header on the recorder's OWN transcript
/// and fails the capture with "the rebuilt run header is not the verifier's
/// binding" if the state differs, and `take` refuses a failed capture. A
/// recorder still on the legacy rule at a tagged profile would diverge at the
/// header's very first hash, so a bundle existing at all is that check.
///
/// The four keys are public functions of public strings — the Python tools
/// re-derive them from the contexts and the profile and compare — and no key
/// is ever an INPUT to anything.
#[test]
fn the_run_file_names_the_hash_rule_and_the_rebuilt_header_matched_under_it() {
    let (_segs, bundle) = prove_and_capture(2, false);
    let j = &bundle.run_json;
    assert!(contains(j, "\"hash_tag\":{\"rule\":\"blake3-keyed/1\""), "the run file does not name the keyed rule");
    assert!(contains(j, "\"profile\":\"hashline-zk-mr1/private-block-rung-g-t24-dev/1\""), "the tag does not name the profile it is derived from");
    for c in ["hashline-zk-mr1 2026-09-20 fiat-shamir transcript", "hashline-zk-mr1 2026-09-20 pcs column digest", "hashline-zk-mr1 2026-09-20 pcs salted merkle leaf", "hashline-zk-mr1 2026-09-20 pcs merkle inner node"] {
        assert!(contains(j, c), "the tag does not carry the context string {c:?}");
    }
    for k in [
        "51b7d0b0171d54b5bb45fd42c3f9369cad87894b625e0569b89fac0036d20dbe",
        "2295498fd6fd5e41320da717e9da89462e5c90a5b3b2d72ac496bcc157c2cd2c",
        "fe211417895c73c4a70430cb9bfb7081289ec7532f2716d2a86f609b0de54032",
        "8c4d2cfe7b8528d350f20dece1250c8d81596eb25d26bffda1247238f0f71fcc",
    ] {
        assert!(contains(j, k), "the tag does not carry the derived key {k}");
    }
    // a run file is valid JSON and every key is on the allow-list: the two
    // existing gates cover the four new members, so nothing here re-asserts
    // them. What IS asserted is that no bundle leaks a rule SELECTOR: the
    // word "legacy" must not appear at a tagged profile.
    assert!(!contains(j, "\"rule\":\"legacy\""), "a tagged bundle claims the legacy rule");
}

// ---------------------------------------------------------------- stage 15: the plane index table

/// **THE TABLE'S ROW RANGES TILE `A` AND `H` EXACTLY.** No gap, no overlap,
/// and the totals are the layout's own counted data rows at the rung — read
/// from the layout, never written here as literals. Each `H` plane is two
/// equal runs of rows, `re` then `im`, and no two planes share a name.
#[test]
fn the_plane_index_tiles_the_a_and_h_commitments_of_the_rung_layout() {
    let sh = Shape::rung_g();
    let lay = Layout::for_shape(&sh).expect("the rung-G layout");
    let idx = plane_index::build(&lay).expect("the plane index of the rung-G layout");
    assert_eq!(idx.a.len(), lay.ids().n_a(), "the table does not list every A plane of the shape");
    assert_eq!(idx.h.len(), lay.hids().n_h(), "the table does not list every H plane of the shape");
    let mut row = 0usize;
    for p in &idx.a {
        assert_eq!(p.id, idx.a[p.id].id, "the A plane ids are not the table's own indices");
        assert_eq!(p.first_row, row, "A plane {} starts at row {}, leaving a gap or an overlap at {row}", p.name, p.first_row);
        assert_eq!(p.offset, row * lay.n(), "A plane {}'s element offset is not its row times the row width", p.name);
        assert_eq!(p.rows, sh.rows_of(p.dom), "A plane {} does not take its domain's rows", p.name);
        row += p.rows;
    }
    assert_eq!(row, lay.a_data_rows, "the A planes tile {row} rows and the layout counts {}", lay.a_data_rows);
    let mut row = 0usize;
    for p in &idx.h {
        assert_eq!((p.re_first_row, p.im_first_row), (row, row + p.rows), "H plane {}'s two halves are not the next two runs of rows", p.name);
        assert_eq!((p.re_offset, p.im_offset), (p.re_first_row * lay.n(), p.im_first_row * lay.n()), "H plane {}'s offsets are not its rows", p.name);
        row += 2 * p.rows;
    }
    assert_eq!(row, lay.h_data_rows, "the H planes tile {row} rows and the layout counts {}", lay.h_data_rows);
    let mut names: Vec<&str> = idx.a.iter().map(|p| p.name.as_str()).chain(idx.h.iter().map(|p| p.name.as_str())).collect();
    let total = names.len();
    names.sort_unstable();
    names.dedup();
    assert_eq!(names.len(), total, "two planes of the table share a name");
    eprintln!(
        "PLANE INDEX at the rung: {} A planes tiling {} rows, {} H planes tiling {} rows, row width {}",
        idx.a.len(),
        lay.a_data_rows,
        idx.h.len(),
        lay.h_data_rows,
        lay.n()
    );
}

/// **EVERY PLANE A SLOT REFERENCES IS IN THE TABLE**, the per-slot list is as
/// long as the schedule's own terminal count, and — the other direction —
/// every committed plane is read by at least one slot.
#[test]
fn every_plane_a_slot_references_is_in_the_plane_index() {
    let lay = Layout::for_shape(&Shape::rung_g()).expect("the rung-G layout");
    let idx = plane_index::build(&lay).expect("the plane index of the rung-G layout");
    assert_eq!(idx.slots.len(), N_SLOTS);
    let mut a_seen = vec![false; idx.a.len()];
    let mut h_seen = vec![false; idx.h.len()];
    for (s, refs) in idx.slots.iter().enumerate() {
        assert_eq!(refs.len(), lay.slot_terms(s), "slot {s} [{}] lists {} planes and publishes {} terminals", SLOT_NAMES[s], refs.len(), lay.slot_terms(s));
        for r in refs {
            match r {
                Ref::A(p) => {
                    assert!(*p < idx.a.len(), "slot {s} [{}] references A plane {p}, which this shape does not have", SLOT_NAMES[s]);
                    a_seen[*p] = true;
                }
                Ref::H(p) => {
                    assert!(*p < idx.h.len(), "slot {s} [{}] references H plane {p}, which this shape does not have", SLOT_NAMES[s]);
                    h_seen[*p] = true;
                }
                _ => assert!(s >= SC_IO_IN, "slot {s} [{}] reads an IO commitment", SLOT_NAMES[s]),
            }
        }
    }
    for (p, seen) in a_seen.iter().enumerate() {
        assert!(seen, "A plane {} is committed and no slot ever opens it", idx.a[p].name);
    }
    for (p, seen) in h_seen.iter().enumerate() {
        assert!(seen, "H plane {} is committed and no slot ever opens it", idx.h[p].name);
    }
}

/// **THE TABLE IS TIED TO A REAL CAPTURE.** In every stage of a captured run,
/// every slot's published terminal vector is exactly as long as that slot's
/// plane list. (The recorder goes further and refuses a capture whose private
/// tables are not in the table's order, plane by plane; this is the part a
/// reader of the bundle can check for itself.)
#[test]
fn each_slots_terminal_vector_is_as_long_as_its_plane_list() {
    let lay = Layout::for_shape(&Shape::rung_g()).expect("the rung-G layout");
    let idx = plane_index::build(&lay).expect("the plane index of the rung-G layout");
    let (_segs, bundle) = prove_and_capture(2, false);
    for (k, stage) in bundle.stages.iter().enumerate() {
        for s in 0..N_SLOTS {
            let got = array_len(stage, "terminals", s);
            assert_eq!(got, idx.slots[s].len(), "stage {k} slot {s} [{}] published {got} terminals and the plane index lists {} planes", SLOT_NAMES[s], idx.slots[s].len());
        }
    }
    assert_eq!(count(&bundle.run_json, "\"plane_index\":"), 1, "the table is a property of the shape and belongs in the run file exactly once");
    for stage in &bundle.stages {
        assert!(!contains(stage, "\"plane_index\":"), "a stage file carries its own copy of the table");
    }
}

/// **THE TABLE IS THE SAME ACROSS STAGES AND ACROSS BUNDLES.** Across stages
/// by construction and by refusal: `run.json` carries one copy and
/// `stage_begin` rebuilds it from every stage's own layout and compares it.
/// Across bundles, here: two INDEPENDENT runs of the same shape, on different
/// hidden inputs and with fresh randomness, carry the same bytes — and those
/// bytes are what this code derives from the layout alone.
#[test]
fn the_plane_index_is_the_same_in_two_independent_bundles() {
    let (_a_segs, a) = prove_and_capture(2, false);
    let (_b_segs, b) = prove_and_capture(2, true);
    let ta = object(&a.run_json, "plane_index");
    let tb = object(&b.run_json, "plane_index");
    assert!(ta.len() > 1000, "the table is only {} B; it is not being written", ta.len());
    assert_eq!(ta, tb, "the plane index table differs between two independent runs of one shape");
    let lay = Layout::for_shape(&Shape::rung_g()).expect("the rung-G layout");
    let idx = plane_index::build(&lay).expect("the plane index of the rung-G layout");
    assert_eq!(ta, idx.render(), "the bundle's plane index is not the table the layout derives");
    eprintln!("PLANE INDEX TABLE: {} B in run.json, run.json {} B in all", ta.len(), a.run_json.len());
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
///
/// **STAGE 15: the tags are `run-c-tame` and `run-d-zero`.** Stage 14's
/// `run-a-tame` and `run-b-zero` predate the plane index table and are left
/// exactly where they are; nothing here deletes or rewrites a bundle, and
/// `write_bundle` creates every file with `create_new`, so a re-run into an
/// existing directory refuses rather than overwrites.
#[test]
#[ignore = "writes the gate bundles; set HL_RUN_CAPTURE_DIR"]
fn write_the_gate_bundles() {
    let root = PathBuf::from(std::env::var("HL_RUN_CAPTURE_DIR").expect("HL_RUN_CAPTURE_DIR is not set: this test writes a directory of evidence and will not choose one for you"));
    let mut total = 0usize;
    for (tag, zero) in [("run-c-tame", false), ("run-d-zero", true)] {
        let (segs, bundle) = prove_and_capture(3, zero);
        let dir = root.join(tag);
        let note = format!(
            "Bundle `{tag}`: one honest three-block run at the development rung\n(`Shape::rung_g`: 24 tokens, width 96, hidden 192, 6 query heads over 2\nkey-value heads), hidden input = {}. Fresh OS randomness; the public weights\nare the lane's synthetic tame fixture. This is the geometry ruling M-8 names\nfor the run privacy gate.\n\nSTAGE 15: `run.json` carries the PLANE INDEX TABLE — for every committed A\nand H plane its id, name, domain and row range, and per slot the ordered list\nof planes its terminal vector evaluates. Public layout data; no plane content.\nThe stage-14 bundles `run-a-tame` and `run-b-zero` predate it.",
            if zero { "the all-zero plane" } else { "the lane fixture's tame plane" }
        );
        run_capture::write_bundle(&dir, &bundle, &segs, &note, "HL_RUN_CAPTURE_DIR=<dir> cargo test --release --lib private_block::run_capture_tests::write_the_gate_bundles -- --ignored --nocapture").expect("the gate bundle is written");
        let n: usize = std::fs::read_dir(&dir).expect("the bundle directory").filter_map(|e| e.ok()).map(|e| e.metadata().map(|m| m.len() as usize).unwrap_or(0)).sum();
        total += n;
        eprintln!("GATE BUNDLE {tag}: {} B run file, {} B of stage files, {} B of segments (pinned by digest; written only with HL_RUN_CAPTURE_SEGMENTS=1), {n} B on disk ({:.1} MB)", bundle.run_json.len(), bundle.stages.iter().map(|s| s.len()).sum::<usize>(), segs.iter().map(|s| s.len()).sum::<usize>(), n as f64 / 1e6);
    }
    eprintln!("GATE BUNDLES total about {:.1} MB in {}", total as f64 / 1e6, root.display());
}

// -------------------- STAGE 18: the TAGGED gate bundles, with the public tables

/// **WRITE THE TWO TAGGED GATE BUNDLES** of ruling M-8, into
/// `HL_RUN_CAPTURE_DIR`. `#[ignore]`d for the same reason as the stage-15
/// writer: it writes a directory of evidence and must be asked for by name.
///
/// **Why they had to be re-taken.** Stage 17's D19 separating hash tag moved
/// every proof byte of the two TAGGED profiles, so the stage-14 and stage-15
/// bundles (`run-a-tame` … `run-d-zero`) are LEGACY-RULE bundles and are not
/// evidence about anything the code produces now. And the Python run gate
/// could not close eleven of its twenty-three per-slot terminal checks
/// because those four bundles were taken with `public_tables_included: false`
/// and it would not guess at a public table's values.
///
/// So these two are taken **with `HL_RUN_CAPTURE_PUBLIC_TABLES=1`**. A public
/// table is a function of the public statement and the stage's challenges —
/// weights are public under this project's privacy model — so including its
/// values publishes nothing that is not already implied by the statement and
/// the transcript. It is the single largest thing in a bundle, which is the
/// only reason it is opt-in.
///
/// Nothing here deletes or rewrites a bundle: `write_bundle` creates every
/// file with `create_new`, so a re-run into an existing directory refuses.
#[test]
#[ignore = "writes the tagged gate bundles; set HL_RUN_CAPTURE_DIR and HL_RUN_CAPTURE_PUBLIC_TABLES=1"]
fn write_the_tagged_gate_bundles() {
    let root = PathBuf::from(std::env::var("HL_RUN_CAPTURE_DIR").expect("HL_RUN_CAPTURE_DIR is not set: this test writes a directory of evidence and will not choose one for you"));
    assert!(
        std::env::var("HL_RUN_CAPTURE_PUBLIC_TABLES").map(|v| v == "1").unwrap_or(false),
        "HL_RUN_CAPTURE_PUBLIC_TABLES=1 is not set: the whole point of these two bundles is that the public tables carry their VALUES, so the run gate can close the eleven slots it could not"
    );
    let sh = Shape::rung_g();
    assert!(!sh.hashes_under_the_legacy_rule(), "these bundles are meant to be TAGGED and this shape is not");
    let mut total = 0usize;
    for (tag, zero) in [("run-e-tame-tagged", false), ("run-f-zero-tagged", true)] {
        let (segs, bundle) = prove_and_capture(3, zero);
        // the bundle says which rule made it, and it is the keyed one
        assert!(contains(&bundle.run_json, "\"hash_tag\":{\"rule\":\"blake3-keyed/1\""), "{tag}: the run file does not name the keyed hash rule");
        assert!(contains(&bundle.run_json, "\"public_tables_included\":true"), "{tag}: the run file does not declare that the public tables are included");
        let dir = root.join(tag);
        let note = format!(
            "Bundle `{tag}`: one honest three-block run at the development rung\n(`Shape::rung_g`: 24 tokens, width 96, hidden 192, 6 query heads over 2\nkey-value heads), hidden input = {}. Fresh OS randomness; the public weights\nare the lane's synthetic tame fixture. This is the geometry ruling M-8 names\nfor the run privacy gate.\n\nSTAGE 18, and this is what is new about it:\n\n* the run is proved and verified under the **D19 SEPARATING HASH TAG**\n  (stage 17, ruling T-1): every hash of every stage is keyed BLAKE3 under one\n  of the four public keys derived from the block profile string. `run.json`\n  carries `hash_tag` with the rule name `blake3-keyed/1`, the profile, the\n  four context strings and the four keys as hex. A reader must RE-DERIVE\n  those keys from the contexts and the profile and COMPARE; it must never\n  take a key from a bundle (ruling T-7).\n* it was taken with `HL_RUN_CAPTURE_PUBLIC_TABLES=1`, so every public table\n  carries its **values** as well as its length and SHA-256. That is what the\n  run gate needs to close the per-slot terminal identity at every slot.\n\nThe four earlier bundles `run-a-tame`, `run-b-zero`, `run-c-tame` and\n`run-d-zero` are LEGACY-RULE bundles taken before the tag and without the\npublic tables' values; the parent README says so.\n\nStill not a privacy result: no gate has read this.",
            if zero { "the all-zero plane" } else { "the lane fixture's tame plane" }
        );
        run_capture::write_bundle(
            &dir,
            &bundle,
            &segs,
            &note,
            "HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_tagged_gate_bundles -- --ignored --nocapture",
        )
        .expect("the tagged gate bundle is written");
        let n: usize = std::fs::read_dir(&dir).expect("the bundle directory").filter_map(|e| e.ok()).map(|e| e.metadata().map(|m| m.len() as usize).unwrap_or(0)).sum();
        total += n;
        assert!(n < 120_000_000, "{tag} is {n} B, past the 120 MB ceiling this stage was given");
        eprintln!(
            "TAGGED GATE BUNDLE {tag}: {} B run file, {} B of stage files, {} B of segments (pinned by digest; written only with HL_RUN_CAPTURE_SEGMENTS=1), {n} B on disk ({:.1} MB)",
            bundle.run_json.len(),
            bundle.stages.iter().map(|s| s.len()).sum::<usize>(),
            segs.iter().map(|s| s.len()).sum::<usize>(),
            n as f64 / 1e6
        );
    }
    eprintln!("TAGGED GATE BUNDLES total about {:.1} MB in {}", total as f64 / 1e6, root.display());
}

// ============================================================
// STAGE 21: the bundles re-taken for the REPAIRED argument
// ============================================================

/// **STAGE 21: `run-g-dense-s20` and `run-h-zero-s20`.**
///
/// **Why they had to be re-taken, and why `g` is the one that matters.** The
/// stage-18 pair `run-e-tame-tagged` / `run-f-zero-tagged` predates the
/// repair of finding S19-F1: slots 08 and 09 gained `log2(kv_heads)` main
/// rounds, one degree and a public `eq(r_g, .)` factor, so at rung-G — which
/// has two key-value heads — every segment of those bundles is 336 bytes per
/// block short of what the code now produces, and their `arguments[8]` /
/// `arguments[9]` carry the pre-repair schedule. A gate judging them would
/// be judging bytes nothing produces.
///
/// And the stage-18 pair, like every bundle before it, was taken on the
/// DIAGONAL fixture (`run-e`) or on the all-zero input (`run-f`). Both are
/// DEGENERATE in exactly the way that hid S19-F1 for nineteen stages: the
/// hidden state is identical in every head, the two key-value groups carry
/// the same data, the upper hidden half `[d, f)` is identically zero, and
/// `A_RQL` is identically zero. **The privacy gate has therefore never seen
/// a non-degenerate witness.** `run-g-dense-s20` is a FULLY DENSE run at the
/// chain band: every entry of all nine public words nonzero, a non-constant
/// hidden input, the upper hidden half live and the two key-value groups
/// carrying different data in every block. It is the important one.
/// `run-h-zero-s20` keeps the all-zero input, which is the fixed input the
/// privacy case is stated at, under the repaired argument.
///
/// **The new public factor needs nothing new in the format**, and that is
/// checked here rather than assumed: `Tab::Eq` already serialises as
/// `{"kind":"eq","start":int,"point":[Fp2]}` (`run_capture.rs`'s table arm),
/// so the group `eq` appears at position 0 of slots 08 and 09's `tables`
/// with `start: 0` and the `lkv` group entries of that slot's head challenge
/// as its point — everything a Python tool needs to RE-DERIVE it from the
/// slot's own `rho` and compare. The private tables are unchanged in number
/// and order, so `plane_index.slot_planes[8]` / `[9]` still list exactly
/// `[A_QR8, A_KR8]` and `[A_P, A_V8]` in the as-built push order, which the
/// recorder's replay independently enforces at every stage.
///
/// Nothing here deletes or rewrites a bundle: `write_bundle` creates every
/// file with `create_new`, so a re-run into an existing directory refuses.
#[test]
#[ignore = "writes the stage-21 gate bundles; set HL_RUN_CAPTURE_DIR and HL_RUN_CAPTURE_PUBLIC_TABLES=1"]
fn write_the_s20_gate_bundles() {
    let root = PathBuf::from(std::env::var("HL_RUN_CAPTURE_DIR").expect("HL_RUN_CAPTURE_DIR is not set: this test writes a directory of evidence and will not choose one for you"));
    assert!(
        std::env::var("HL_RUN_CAPTURE_PUBLIC_TABLES").map(|v| v == "1").unwrap_or(false),
        "HL_RUN_CAPTURE_PUBLIC_TABLES=1 is not set: these bundles exist so the run gate can close every slot's terminal identity, which needs the public tables' VALUES"
    );
    let sh = Shape::rung_g();
    assert!(!sh.hashes_under_the_legacy_rule(), "these bundles are meant to be TAGGED and this shape is not");
    let lkv = (sh.kv_heads as u32).trailing_zeros() as usize;
    assert!(lkv > 0, "this shape does not group, so there would be no repaired slot to capture");
    let mut total = 0usize;
    for (tag, dense) in [("run-g-dense-s20", true), ("run-h-zero-s20", false)] {
        let (segs, bundle) = if dense { prove_and_capture_dense(3) } else { prove_and_capture(3, true) };
        assert!(contains(&bundle.run_json, "\"hash_tag\":{\"rule\":\"blake3-keyed/1\""), "{tag}: the run file does not name the keyed hash rule");
        assert!(contains(&bundle.run_json, "\"public_tables_included\":true"), "{tag}: the run file does not declare that the public tables are included");
        // THE REPAIRED SLOTS, checked in the bytes before anything is
        // written: the schedule the capture reports for slots 08 and 09 is
        // the repaired one, and each of them carries the group `eq` at
        // `start: 0` in every stage.
        let (score, pv) = (sh.slots()[SC_SCORE], sh.slots()[SC_PV]);
        for (k, stage) in bundle.stages.iter().enumerate() {
            for (s, (main, ext, degree)) in [(SC_SCORE, score), (SC_PV, pv)] {
                let head = format!("{{\"slot\":{s},\"name\":{:?},\"kind\":\"Private\",\"main\":{main},\"extension\":{ext},\"degree\":{degree},", SLOT_NAMES[s]);
                assert!(contains(stage, &head), "{tag} stage {k}: slot {s} does not report the repaired schedule ({main}, {ext}, {degree})");
            }
            assert!(
                count(stage, "\"tables\":[{\"kind\":\"eq\",\"start\":0,\"point\":[") >= 2,
                "{tag} stage {k}: the two bilinear slots do not both open their table list with the group eq at start 0"
            );
        }
        let dir = root.join(tag);
        let note = format!(
            "Bundle `{tag}`: one honest three-block run at the development rung\n(`Shape::rung_g`: 24 tokens, width 96, hidden 192, 6 query heads over 2\nkey-value heads), under the D19 separating hash tag, with the public\ntables' values, and — this is what is new — **under the REPAIRED bilinear\nattention argument** (lane stage 20, finding S19-F1).\n\nHidden input and public weights: {}\n\nWHAT CHANGED IN THE BYTES. Slots 08 (`10 score matmul`) and 09 (`11 PV\nmatmul`) now SUM over the {lkv} key-value group bit(s) instead of fixing\nthem on both private factors. In this bundle that means:\n\n* `arguments[8]` is (main {}, extension {}, degree {}) and `arguments[9]` is\n  (main {}, extension {}, degree {}); their `rounds` arrays are longer and\n  each round message carries one more value.\n* each of those two slots' `tables` begins with\n  `{{\"kind\":\"eq\",\"start\":0,\"point\":[...]}}` — the PUBLIC group factor. Its\n  point is the leading {lkv} entrie(s) of that slot's head challenge, which a\n  reader RE-DERIVES from the slot's own `definition_challenges`; `start: 0`\n  says it reads the leading {lkv} sumcheck variable(s) of `rho`. It is a\n  verifier-computed table: never take a value from it, re-derive and compare.\n* the PRIVATE tables are unchanged in number, order and role, so\n  `plane_index.slot_planes[8]` and `[9]` are the same two-plane lists as\n  before and `len(slot_planes[s]) == len(terminals)` still holds.\n* every segment is 336 B per block longer than the stage-18 pair's.\n\nThe stage-18 bundles `run-e-tame-tagged` and `run-f-zero-tagged` are\ntherefore SUPERSEDED for gate purposes, as the parent README says.\n\nStill not a privacy result: no gate has read this.",
            if dense {
                "the FULLY DENSE recipe at the chain band (`private_block::dense_tests::dense_run_case`): every entry of all nine public words nonzero, a non-constant hidden input, the upper hidden half of the feed-forward planes live and the two key-value groups carrying DIFFERENT data in every block. THIS IS THE FIRST CAPTURE EVER TAKEN ON A NON-DEGENERATE WITNESS at a grouped profile"
            } else {
                "the ALL-ZERO hidden plane on the lane's synthetic tame fixture — the fixed input the privacy case is stated at, under the repaired argument"
            },
            score.0,
            score.1,
            score.2,
            pv.0,
            pv.1,
            pv.2
        );
        run_capture::write_bundle(
            &dir,
            &bundle,
            &segs,
            &note,
            "HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_s20_gate_bundles -- --ignored --nocapture",
        )
        .expect("the stage-21 gate bundle is written");
        let n: usize = std::fs::read_dir(&dir).expect("the bundle directory").filter_map(|e| e.ok()).map(|e| e.metadata().map(|m| m.len() as usize).unwrap_or(0)).sum();
        total += n;
        assert!(n < 120_000_000, "{tag} is {n} B, past the 120 MB ceiling this stage was given");
        eprintln!(
            "S20 GATE BUNDLE {tag}: {} B run file, {} B of stage files, {} B of segments (pinned by digest; written only with HL_RUN_CAPTURE_SEGMENTS=1), {n} B on disk ({:.1} MB)",
            bundle.run_json.len(),
            bundle.stages.iter().map(|s| s.len()).sum::<usize>(),
            segs.iter().map(|s| s.len()).sum::<usize>(),
            n as f64 / 1e6
        );
    }
    eprintln!("S20 GATE BUNDLES total about {:.1} MB in {}", total as f64 / 1e6, root.display());
}

// ============================================================
// STAGE 22: the bundles at the FOUR-key-value-head shape
// ============================================================

/// **STAGE 22: `run-i-dense-k4` and `run-j-zero-k4`.**
///
/// **Why they exist.** Every bundle this project has ever written is at
/// `lkv <= 1`: the four legacy-rule ones and the stage-18 pair at rung-G
/// (two key-value heads), the stage-21 pair likewise. The repaired bilinear
/// slots sum over `lkv = log2(kv_heads)` group bits under a public
/// `eq(r_g, .)`, so at every bundle so far that `eq` has a ONE-element point
/// and the sum has two terms. **The Python run gate's ports have therefore
/// never seen more than one group bit**, and the only shape with two is
/// 125M, whose runs are 484 MB and which the gate cannot ingest.
///
/// `Shape::rung_k4` is that case at a size a gate can read: the same 24
/// tokens, width 96 and hidden 192 as rung-G, with the heads recut as twelve
/// query heads of eight over FOUR key-value heads and the padded head slots
/// at `{3, 7, 11, 15}` — 125M's own head geometry. In these bundles slots 08
/// and 09 carry `{"kind":"eq","start":0,"point":[<TWO Fp2>]}`, the sum has
/// four terms, and `point` is the leading TWO entries of that slot's head
/// challenge, which a reader re-derives from `definition_challenges` and
/// COMPARES (ruling T-7).
///
/// `run-i-dense-k4` is the one that matters: the fully dense recipe at the
/// chain band, a generic hidden input, all four key-value groups carrying
/// different data. `run-j-zero-k4` is the all-zero input, the degenerate
/// case, kept because it is the fixed input the privacy case is stated at.
///
/// Nothing here deletes or rewrites a bundle: `write_bundle` creates every
/// file with `create_new`, so a re-run into an existing directory refuses.
#[test]
#[ignore = "writes the stage-22 rung-K4 gate bundles; set HL_RUN_CAPTURE_DIR and HL_RUN_CAPTURE_PUBLIC_TABLES=1"]
fn write_the_k4_gate_bundles() {
    let root = PathBuf::from(std::env::var("HL_RUN_CAPTURE_DIR").expect("HL_RUN_CAPTURE_DIR is not set: this test writes a directory of evidence and will not choose one for you"));
    assert!(
        std::env::var("HL_RUN_CAPTURE_PUBLIC_TABLES").map(|v| v == "1").unwrap_or(false),
        "HL_RUN_CAPTURE_PUBLIC_TABLES=1 is not set: these bundles exist so the run gate can close every slot's terminal identity at TWO group bits, which needs the public tables' VALUES"
    );
    let sh = Shape::rung_k4();
    assert!(!sh.hashes_under_the_legacy_rule(), "these bundles are meant to be TAGGED and this shape is not");
    let lkv = (sh.kv_heads as u32).trailing_zeros() as usize;
    assert_eq!(lkv, 2, "this shape does not carry two group bits, which is the only reason these bundles exist");
    let mut total = 0usize;
    for (tag, dense) in [("run-i-dense-k4", true), ("run-j-zero-k4", false)] {
        let (segs, bundle) = prove_and_capture_k4(3, dense);
        assert!(contains(&bundle.run_json, "\"hash_tag\":{\"rule\":\"blake3-keyed/1\""), "{tag}: the run file does not name the keyed hash rule");
        assert!(contains(&bundle.run_json, "\"public_tables_included\":true"), "{tag}: the run file does not declare that the public tables are included");
        assert!(contains(&bundle.run_json, "hashline-zk-mr1/private-run-rung-k4-t24-dev/1"), "{tag}: the run file does not carry the rung-K4 run profile");
        // THE TWO GROUP BITS, CHECKED IN THE BYTES before anything is
        // written: the repaired schedule of slots 08 and 09 at this shape,
        // and a group `eq` at `start: 0` whose point has TWO entries — which
        // is the whole difference from every bundle taken before.
        let (score, pv) = (sh.slots()[SC_SCORE], sh.slots()[SC_PV]);
        assert_eq!((score, pv), ((5, 2, 3), (7, 2, 3)), "the rung-K4 bilinear schedule moved");
        for (k, stage) in bundle.stages.iter().enumerate() {
            for (s, (main, ext, degree)) in [(SC_SCORE, score), (SC_PV, pv)] {
                let head = format!("{{\"slot\":{s},\"name\":{:?},\"kind\":\"Private\",\"main\":{main},\"extension\":{ext},\"degree\":{degree},", SLOT_NAMES[s]);
                assert!(contains(stage, &head), "{tag} stage {k}: slot {s} does not report the repaired schedule ({main}, {ext}, {degree})");
            }
            // a two-element `Fp2` point renders as `[[a,b],[c,d]]`, so the
            // group eq's table opens with a `[[` and the slot's table list
            // is the eq followed by its two private factors
            assert!(
                count(stage, "\"tables\":[{\"kind\":\"eq\",\"start\":0,\"point\":[") >= 2,
                "{tag} stage {k}: the two bilinear slots do not both open their table list with the group eq at start 0"
            );
        }
        let dir = root.join(tag);
        let note = format!(
            "Bundle `{tag}`: one honest three-block run at the FOUR-KEY-VALUE-HEAD\ndevelopment shape (`Shape::rung_k4`: 24 tokens, width 96, hidden 192, 12 query\nheads of 8 over 4 key-value heads, padded head slots {{3, 7, 11, 15}} — 125M's\nown head geometry), under the D19 separating hash tag, with the public tables'\nvalues.\n\nWHY THIS PAIR EXISTS, AND WHAT IS NEW IN IT. Every bundle written before this\none is at log2(kv_heads) <= 1. The repaired bilinear attention argument (lane\nstage 20, finding S19-F1) SUMS over the {lkv} key-value group bit(s) under a\npublic eq(r_g, .), so at one group bit that eq carries a ONE-element point and\nthe sum has two terms — and no tool has ever read a bundle where it carries\nmore. Here:\n\n* `arguments[8]` (`10 score matmul`) is (main {}, extension {}, degree {}) and\n  `arguments[9]` (`11 PV matmul`) is (main {}, extension {}, degree {});\n* each of those two slots' `tables` begins with\n  `{{\"kind\":\"eq\",\"start\":0,\"point\":[<TWO Fp2 values>]}}`. The point is the\n  leading {lkv} entries of that slot's head challenge, which a reader\n  RE-DERIVES from the slot's own `definition_challenges` and COMPARES; it must\n  never take a value from it (ruling T-7). `start: 0` says the factor reads\n  the leading {lkv} sumcheck variables of `rho`.\n* the PRIVATE tables are unchanged in number, order and role, so\n  `plane_index.slot_planes[8]` and `[9]` are the same two-plane lists as at\n  rung-G and `len(slot_planes[s]) == len(terminals)` still holds.\n\nHidden input and public weights: {}\n\nThis is a NEW PROFILE (D17): `hashline-zk-mr1/private-block-rung-k4-t24-dev/1`\nfor the block and `hashline-zk-mr1/private-run-rung-k4-t24-dev/1` for the run,\nwith their own hash-tag key set. No byte of any earlier profile moves.\n\nDevelopment grade (ruling P-7). Still not a privacy result: no gate has read\nthis.",
            score.0, score.1, score.2, pv.0, pv.1, pv.2,
            if dense {
                "the FULLY DENSE recipe at the chain band (`private_block::dense_tests::dense_run_case`): every entry of all nine public words nonzero, a non-constant hidden input from its own unpublished stream, the upper hidden half of the feed-forward planes live, twelve of twelve head slots live and ALL FOUR key-value groups carrying PAIRWISE DIFFERENT rotated keys in every block. THIS IS THE FIRST CAPTURE EVER TAKEN WITH MORE THAN ONE GROUP BIT"
            } else {
                "the ALL-ZERO hidden plane on the lane's synthetic tame fixture — the fixed input the privacy case is stated at, and a DEGENERATE witness: every key-value group is identically zero, so it says nothing about the group bits and is kept as the pair's control"
            }
        );
        run_capture::write_bundle(
            &dir,
            &bundle,
            &segs,
            &note,
            "HL_RUN_CAPTURE_DIR=<dir> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::write_the_k4_gate_bundles -- --ignored --nocapture",
        )
        .expect("the stage-22 rung-K4 gate bundle is written");
        let n: usize = std::fs::read_dir(&dir).expect("the bundle directory").filter_map(|e| e.ok()).map(|e| e.metadata().map(|m| m.len() as usize).unwrap_or(0)).sum();
        total += n;
        assert!(n < 120_000_000, "{tag} is {n} B, past the 120 MB ceiling this stage was given");
        eprintln!(
            "K4 GATE BUNDLE {tag}: {} B run file, {} B of stage files, {} B of segments (pinned by digest; written only with HL_RUN_CAPTURE_SEGMENTS=1), {n} B on disk ({:.1} MB)",
            bundle.run_json.len(),
            bundle.stages.iter().map(|s| s.len()).sum::<usize>(),
            segs.iter().map(|s| s.len()).sum::<usize>(),
            n as f64 / 1e6
        );
    }
    eprintln!("K4 GATE BUNDLES total about {:.1} MB in {}", total as f64 / 1e6, root.display());
}

// ===========================================================================
// STAGE 23, GAP GS-2 — THE REFUSAL REPLAY ORDER, PINNED ON A REAL BLOCK
// ===========================================================================

/// One integer field of a capture record, read where it is written.
fn cap_int(rec: &str, key: &str) -> usize {
    let pat = format!("\"{key}\":");
    let i = rec.find(&pat).unwrap_or_else(|| panic!("the capture record carries no `{key}`"));
    let after = &rec[i + pat.len()..];
    let j = after.find(|c: char| !c.is_ascii_digit()).unwrap_or(after.len());
    after[..j].parse().unwrap_or_else(|_| panic!("`{key}` is not an integer"))
}

/// The record of ONE opening of one stage file, from `{"role":"<role>",` to
/// the next role record (`run_capture::write_pcs` writes them in the order the
/// verifier performs them).
fn cap_role<'a>(stage: &'a [u8], role: &str) -> &'a str {
    let s = std::str::from_utf8(stage).expect("a capture stage file is ASCII JSON");
    let head = format!("{{\"role\":\"{role}\",");
    let start = s.find(&head).unwrap_or_else(|| panic!("the stage carries no `{role}` opening"));
    let rest = &s[start + 1..];
    let end = rest.find("{\"role\":\"").map(|i| start + 1 + i).unwrap_or(s.len());
    &s[start..end]
}

/// The member count of every opening group of one record, IN THE ORDER the
/// recorder's independent replay formed them — which is the order
/// `pcs::open_zk` and `pcs::verify_zk_tagged` draw their lambdas in
/// (`zkp-core/src/pcs.rs:947,961`: one `challenge_fp2_vec(members.len())` per
/// group, then one `challenge_fp2_vec(rows)` for the proximity coefficients).
fn cap_group_members(rec: &str) -> Vec<usize> {
    let mut out = Vec::new();
    let mut rest = rec;
    while let Some(i) = rest.find("\"members\":[") {
        let after = &rest[i + "\"members\":[".len()..];
        let j = after.find(']').expect("a members list");
        let body = after[..j].trim();
        out.push(if body.is_empty() { 0 } else { body.matches(',').count() + 1 });
        rest = &after[j..];
    }
    out
}

/// How many `Fp2` entries a recorded list of field elements holds (each is
/// written as `[c0, c1]`).
fn cap_fp2_list_len(rec: &str, key: &str) -> usize {
    let pat = format!("\"{key}\":[");
    let i = rec.find(&pat).unwrap_or_else(|| panic!("the capture record carries no `{key}`"));
    let mut depth = 1usize;
    let mut n = 0usize;
    for ch in rec[i + pat.len()..].chars() {
        match ch {
            '[' => {
                depth += 1;
                if depth == 2 {
                    n += 1;
                }
            }
            ']' => {
                depth -= 1;
                if depth == 0 {
                    break;
                }
            }
            _ => {}
        }
    }
    n
}

/// A deterministic sequence of pairwise-independent nonzero `Fp2` draws.
/// `(i + 1, 1)` and `(j + 1, 1)` have determinant `i - j`, so no two of them
/// are dependent and no honest prefix is ever refused by accident.
fn stand_in_draws(n: usize) -> Vec<Fp2> {
    (0..n).map(|i| Fp2::new(Fp::new(i as u64 + 1), Fp::new(1))).collect()
}

/// Run the prover's own refusal replay over a fixed draw list, and report the
/// verdict together with **how many draws it consumed**. The consumption
/// count is the observable: `check_opening_challenges` draws each challenge
/// immediately before testing it, so the number of draws taken before a
/// refusal says at which position in the challenge stream the condition was
/// evaluated.
fn replay_with(draws: &[Fp2], groups: &[usize], rows: usize, prox: usize) -> (Result<(), String>, usize) {
    let mut used = 0usize;
    let mut it = draws.iter().copied();
    let r = super::protocol::check_opening_challenges(groups, rows, prox, || {
        used += 1;
        it.next().expect("the replay drew past the recorded challenge stream")
    });
    (r, used)
}

/// **STAGE 23 — GAP GS-2 of the shaped generic-rank lemma: the refusal replay
/// order, pinned against the order the opening's challenges are drawn.**
///
/// **What the gap is.** The Python privacy tools replay the prover's refusal
/// checks in the order the opening's challenges are drawn, and the argument's
/// reading of a refused run depends on that order. Nothing in Rust pinned it.
///
/// **What is observable today, and through which existing hook.** The run
/// capture recorder (`run_capture::Recorder::attach`, a `#[cfg(test)]`
/// facility that already exists and is not touched here) records, for every
/// opening of every stage, the transcript state BEFORE the opening and its
/// own INDEPENDENT replay of that opening's challenges from that state:
/// the lambdas of each group in group order, then the `rows` proximity
/// coefficients (`run_capture::replay`, whose own comment names the source
/// order). That replay is the prover's and the verifier's draw order, because
/// the recorder re-verifies the opening on its own transcript and the whole
/// bundle is refused on the first mismatch. So the recorded record IS the
/// challenge order, and this test drives the prover's refusal logic
/// (`protocol::check_opening_challenges`, whose injectable draw exists for
/// deterministic negative controls) over exactly that partition.
///
/// **What is pinned, on a real two-block fully dense rung-G run — generic
/// weights, a non-constant hidden input, both key-value groups live.**
///
/// 1. **The partition.** The `A` and `H` openings of the first block draw
///    `sum(members) + rows` challenges, partitioned as one per group member in
///    GROUP ORDER and then one per commitment row; the recorder's own record
///    of that opening has exactly that shape, and the group count is the
///    schedule's `a_groups()` / `h_groups()`.
/// 2. **The honest path consumes the whole partition and no more.**
/// 3. **Every group member's coefficient is tested for zero, in order, and
///    the check SHORT-CIRCUITS.** A zero at stream position `i` of the group
///    block refuses with `zero group member coefficient` after exactly
///    `i + 1` draws — so the proximity coefficients are never drawn on a run
///    discarded for a zero lambda.
/// 4. **The proximity determinant reads exactly two positions**, the ones at
///    offsets `prox` and `prox + 1` of the row block, i.e. stream positions
///    `sum(members) + prox` and `+ prox + 1`. A zero at either refuses with
///    `dependent proximity mask coefficients`; a zero at any other row
///    position is accepted. Both are swept over every row position.
/// 5. **Precedence.** When a zero group coefficient and a degenerate
///    proximity pair hold at once, the GROUP message wins — the group block
///    is drawn first.
/// 6. **The external endpoint's opening** replays the same way with a single
///    one-member group, at its own row count and proximity row.
///
/// **What is NOT pinned, and the hook that is missing.** Nothing here reads
/// the refusal checks' order from inside a live `prove_core` / `verify_core`:
/// `check_opening` clones the transcript and discards the clone, so a session
/// that wanted to observe the live evaluation order would need a test-only
/// observer inside `protocol::check_opening_challenges` — a
/// `#[cfg(test)] fn observe(condition: &str, draw_index: usize)` beside the
/// two refusals, called on every evaluation and not only on a refusal. That
/// is a PRODUCTION-FILE change (`protocol.rs`) and ruling GS-2's instruction
/// is not to add one. What replaces it is the equality above: the partition
/// this test drives is read out of a real block's real capture, not declared.
#[test]
fn the_refusal_replay_evaluates_in_the_order_the_openings_challenges_are_drawn() {
    let sh = Shape::rung_g();
    let (_segs, bundle) = prove_and_capture_dense(2);
    let stage = &bundle.stages[0];
    let lay = super::layout::Layout::for_shape(&sh).expect("the rung-G layout");

    for (role, want_groups, want_rows, want_prox) in [
        ("A", sh.a_groups(), lay.a_rows, lay.a_prox),
        ("H", sh.h_groups(), lay.h_rows, lay.h_prox),
    ] {
        let rec = cap_role(stage, role);
        // (1) the recorded partition IS the schedule's
        let members = cap_group_members(rec);
        let rows = cap_int(rec, "rows");
        let prox = cap_int(rec, "prox_row");
        assert_eq!(members.len(), want_groups, "{role}: the capture records {} opening groups, the schedule declares {want_groups}", members.len());
        assert_eq!(rows, want_rows, "{role}: the capture's commitment row count");
        assert_eq!(prox, want_prox, "{role}: the capture's proximity row");
        assert_eq!(cap_fp2_list_len(rec, "proximity_rhos"), rows, "{role}: the replay drew one proximity coefficient per commitment row");
        let lambdas: usize = rec.matches("\"lambdas\":[").count();
        assert_eq!(lambdas, members.len(), "{role}: one lambda list per group");
        let total: usize = members.iter().sum();
        assert!(total > members.len(), "{role}: no group has more than one member, so group order is untested here");

        // (2) the honest path consumes the whole partition and no more
        let good = stand_in_draws(total + rows);
        let (verdict, used) = replay_with(&good, &members, rows, prox);
        verdict.expect("the honest replay is accepted");
        assert_eq!(used, total + rows, "{role}: the replay consumes one draw per group member and one per row, and nothing else");

        // (3) every group position is tested for zero, in order, short-circuiting
        for i in 0..total {
            let mut d = good.clone();
            d[i] = Fp2::ZERO;
            let (verdict, used) = replay_with(&d, &members, rows, prox);
            let e = verdict.expect_err(&format!("{role}: a zero group coefficient at stream position {i} was accepted"));
            assert!(e.contains("zero group member coefficient"), "{role}: position {i}: {e}");
            assert_eq!(used, i + 1, "{role}: the replay did not stop at the zero coefficient's own draw");
        }

        // (4) the determinant reads exactly the two rows at `prox`, `prox + 1`
        for r in 0..rows {
            let mut d = good.clone();
            d[total + r] = Fp2::ZERO;
            let (verdict, used) = replay_with(&d, &members, rows, prox);
            assert_eq!(used, total + rows, "{role}: a zero row coefficient must not short-circuit the row block");
            if r == prox || r == prox + 1 {
                let e = verdict.expect_err(&format!("{role}: a zero proximity coefficient at row {r} was accepted"));
                assert!(e.contains("dependent proximity mask coefficients"), "{role}: row {r}: {e}");
            } else {
                verdict.unwrap_or_else(|e| panic!("{role}: row {r} is not a proximity row but was refused: {e}"));
            }
        }
        // and a DEPENDENT (not zero) pair is refused too, which is what says
        // the check is the determinant and not a zero test
        let mut dep = good.clone();
        dep[total + prox] = Fp2::new(Fp::new(2), Fp::new(4));
        dep[total + prox + 1] = Fp2::new(Fp::new(1), Fp::new(2));
        let (verdict, used) = replay_with(&dep, &members, rows, prox);
        assert!(verdict.expect_err("a dependent proximity pair was accepted").contains("dependent proximity"), "{role}: the dependent pair");
        assert_eq!(used, total + rows);

        // (5) precedence: the group block is drawn first, so its message wins
        let mut both = good.clone();
        both[total - 1] = Fp2::ZERO;
        both[total + prox] = Fp2::ZERO;
        let (verdict, used) = replay_with(&both, &members, rows, prox);
        let e = verdict.expect_err("two refusal conditions held and neither fired");
        assert!(e.contains("zero group member coefficient"), "{role}: the proximity message won over the group message: {e}");
        assert_eq!(used, total, "{role}: the replay reached the row block although a group coefficient was zero");
    }

    // (6) the external endpoint: one group of one member, at its own geometry
    let rec = cap_role(stage, "Input");
    let members = cap_group_members(rec);
    let rows = cap_int(rec, "rows");
    let prox = cap_int(rec, "prox_row");
    assert_eq!(members, vec![1], "the endpoint opening is one group of one claim");
    assert_eq!(rows, sh.endpoint_rows, "the endpoint's commitment rows");
    assert_eq!((rows, prox), (9, 6), "the rung-G endpoint geometry (rows, prox) of `protocol::endpoint_geometry`");
    assert_eq!(cap_fp2_list_len(rec, "proximity_rhos"), rows);
    let good = stand_in_draws(1 + rows);
    let (verdict, used) = replay_with(&good, &members, rows, prox);
    verdict.expect("the honest endpoint replay is accepted");
    assert_eq!(used, 1 + rows);
    let mut zero_lambda = good.clone();
    zero_lambda[0] = Fp2::ZERO;
    let (verdict, used) = replay_with(&zero_lambda, &members, rows, prox);
    assert!(verdict.expect_err("a zero endpoint lambda was accepted").contains("zero group member coefficient"));
    assert_eq!(used, 1, "the endpoint replay drew its rows although its single lambda was zero");

    eprintln!(
        "GS-2 (rung-G, two-block fully dense run, stage 0): A = {} groups over {} rows, H = {} groups over {} rows, endpoint = 1 group over {} rows; every group position and every row position swept",
        sh.a_groups(),
        lay.a_rows,
        sh.h_groups(),
        lay.h_rows,
        sh.endpoint_rows
    );
}

// ===========================================================================
// STAGE 27 — A RUN CAPTURE MADE POSSIBLE AT THE 125M SHAPE
// ===========================================================================
//
// **The problem.** The Python privacy gate has read a private run's every
// linear channel on real bytes at two DEVELOPMENT shapes and its standing
// limit is that nothing has been measured at 125M. A capture records the
// VERIFIER'S VIEW, which is small beside a 40 MB-per-block receipt — but not
// if the writer renders multi-million-element field arrays as decimal JSON.
// MEASURED on the committed rung bundles: a uniformly random `Fp` costs 21.4
// bytes of text and an `Fp2` 44.8, against 8 and 16 bytes little-endian.
//
// **What this section adds**: the `/5-run` array store's tests, one shared
// capture body, the development-shape dress rehearsal that runs here, and
// the `#[ignore]`d 125M capture the security owner launches himself.

/// Prove an honest `l`-block run at ANY shape on either recipe and capture
/// its verification, with the array encoding stated outright. The body of
/// every capture from stage 27 on, including the heavy one.
fn prove_and_capture_any(sh: &Shape, rs: RunShape, l: usize, dense: bool, opts: run_capture::CaptureOpts) -> (Vec<Vec<u8>>, Bundle, Digest) {
    let (public, ff, x0) = if dense {
        super::dense_tests::dense_run_case(sh)
    } else {
        let (p, f, _) = super::grow_tests::tame_case(sh);
        (p, f, vec![0i16; sh.tokens * sh.width])
    };
    let blocks = blocks_from(&public, &ff, l);
    let mut c = Chain::from_parts(sh, l, public, ff, x0);
    let (st, owners) = statement_of_at(&c, l, &blocks, rs);
    let segs = prove_to_vec(&st, &blocks, &mut c, owners);
    let binding = st.binding().expect("the run binding");
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(st.capture_header().expect("the capture header"), binding, opts);
    run::verify_run(&st, &blocks, &segs).expect("the honest run verifies");
    let bundle = run_capture::take().expect("a bundle for an accepted run");
    drop(guard);
    (segs, bundle, binding)
}

// -------------------------------------------------- resolving `arrays.bin`

/// One `{"array":…}` reference, read where the writer wrote it.
#[derive(Debug, PartialEq)]
struct ArrayRef {
    sha: String,
    elem: String,
    len: usize,
    offset: usize,
    bytes: usize,
    /// the reference's own span in the file
    at: (usize, usize),
}

/// Every array reference of a file, in order of appearance. The writer emits
/// the five members in this fixed order with no whitespace, so a scan is
/// exact and needs no JSON parser.
fn array_refs(bytes: &[u8]) -> Vec<ArrayRef> {
    let head = b"{\"array\":\"";
    let mut out = Vec::new();
    let mut i = 0usize;
    while i + head.len() < bytes.len() {
        if !bytes[i..].starts_with(head) {
            i += 1;
            continue;
        }
        let end = i + bytes[i..].iter().position(|b| *b == b'}').expect("an array reference is closed");
        let body = std::str::from_utf8(&bytes[i..=end]).expect("an array reference is ASCII");
        let field = |k: &str| -> String {
            let p = format!("\"{k}\":");
            let s = body.find(&p).unwrap_or_else(|| panic!("the array reference {body} has no {k}")) + p.len();
            let rest = &body[s..];
            let t = rest.trim_start_matches('"');
            let n = t.find(['"', ',', '}']).expect("a terminated field");
            t[..n].to_string()
        };
        out.push(ArrayRef {
            sha: field("array"),
            elem: field("elem"),
            len: field("len").parse().expect("len is an integer"),
            offset: field("offset").parse().expect("offset is an integer"),
            bytes: field("bytes").parse().expect("bytes is an integer"),
            at: (i, end + 1),
        });
        i = end + 1;
    }
    out
}

/// The JSON key an array reference is the value of: the nearest `"<key>":`
/// that ends where the reference begins. The writer emits no whitespace, so
/// this is exact.
fn ref_owner(file: &[u8], at: usize) -> String {
    assert_eq!(file[at - 1], b':', "an array reference is not a member's value");
    let close = at - 2;
    assert_eq!(file[close], b'"', "an array reference is not a member's value");
    let open = (0..close).rev().find(|i| file[*i] == b'"').expect("a quoted key");
    String::from_utf8_lossy(&file[open + 1..close]).into_owned()
}

/// **THE PER-MEMBER STORE TABLE.** For every JSON key whose value is an
/// array in `arrays.bin`: how many references, how many DISTINCT arrays
/// behind them, and how many bytes those distinct arrays take. This is the
/// table the 125M size model is built from, measured here at a development
/// shape so the model has something to be wrong against.
fn store_breakdown(files: &[&[u8]]) -> std::collections::BTreeMap<String, (usize, std::collections::BTreeSet<String>, usize)> {
    let mut out: std::collections::BTreeMap<String, (usize, std::collections::BTreeSet<String>, usize)> = std::collections::BTreeMap::new();
    let mut seen: std::collections::BTreeSet<String> = std::collections::BTreeSet::new();
    for file in files {
        for r in array_refs(file) {
            let e = out.entry(ref_owner(file, r.at.0)).or_default();
            e.0 += 1;
            if e.1.insert(r.sha.clone()) && seen.insert(r.sha.clone()) {
                e.2 += r.bytes;
            }
        }
    }
    out
}

/// How many bytes one entry of an element type takes.
fn elem_width(elem: &str) -> usize {
    match elem {
        "fp" => 8,
        "fp2" => 16,
        other => panic!("the array store wrote an element type this reader does not know: {other:?}"),
    }
}

/// Rewrite a `/5-run` file into the `/4-run` text it would have been: every
/// array reference replaced by the inline JSON list of the values it names,
/// rendered exactly as Rust's `{:?}` renders a `Vec<u64>` / `Vec<[u64; 2]>`.
/// Byte-for-byte equality with the classic bundle is then the statement that
/// the store changed the ENCODING and nothing else.
fn expand_arrays(file: &[u8], blob: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(file.len());
    let mut cut = 0usize;
    for r in array_refs(file) {
        out.extend_from_slice(&file[cut..r.at.0]);
        let w = elem_width(&r.elem);
        assert_eq!(r.bytes, r.len * w, "the reference {} says {} entries and {} bytes", r.sha, r.len, r.bytes);
        assert!(r.offset + r.bytes <= blob.len(), "the reference {} points past the end of arrays.bin", r.sha);
        let raw = &blob[r.offset..r.offset + r.bytes];
        assert_eq!(crate::export_v3::sha256_hex(raw), r.sha, "the bytes at offset {} are not the array the reference names", r.offset);
        let word = |j: usize| u64::from_le_bytes(raw[j * 8..j * 8 + 8].try_into().expect("eight bytes"));
        let text = if r.elem == "fp" {
            format!("{:?}", (0..r.len).map(word).collect::<Vec<u64>>())
        } else {
            format!("{:?}", (0..r.len).map(|j| [word(2 * j), word(2 * j + 1)]).collect::<Vec<[u64; 2]>>())
        };
        out.extend_from_slice(text.as_bytes());
        cut = r.at.1;
    }
    out.extend_from_slice(&file[cut..]);
    out
}

// -------------------------------------------------- the bundle on disk

/// Read a written bundle back and check it against itself, exactly as the
/// development capture tests do, plus the array store: the manifest's
/// lengths and digests, the plane index table, the hash tag, the rebuilt run
/// binding, every stage's segment pin, the allow-list, and every array
/// reference resolved and re-hashed. Returns the bundle's size on disk.
fn check_bundle_on_disk(dir: &Path, l: usize, binding: Digest, segs: &[Vec<u8>], arrays_on: bool) -> usize {
    let manifest = std::fs::read(dir.join("manifest.json")).expect("a manifest");
    let mut names: Vec<String> = vec!["run.json".into()];
    names.extend((0..l).map(|k| run_capture::stage_file(k)));
    if arrays_on {
        names.push(run_capture::ARRAYS_FILE.into());
    }
    names.push("README.md".into());
    if run_capture::segments_wanted() {
        names.extend((0..l).map(|k| format!("segments/segment-{k:02}.bin")));
    }
    let mut total = 0usize;
    for name in &names {
        let bytes = std::fs::read(dir.join(name)).unwrap_or_else(|e| panic!("{name}: {e}"));
        let sha = crate::export_v3::sha256_hex(&bytes);
        assert!(
            contains(&manifest, &format!("{{\"file\":\"{name}\",\"bytes\":{},\"sha256\":\"{sha}\"}}", bytes.len())),
            "{name} is not in the manifest with its own length and digest"
        );
        total += bytes.len();
    }
    assert_eq!(count(&manifest, "\"sha256\":"), names.len() + run_capture::source_files().len(), "the manifest does not pin every file and every source file");
    assert!(contains(&manifest, &format!("\"total_bytes\":{total}")), "the manifest's total is not the bytes on disk");
    let blob = if arrays_on { std::fs::read(dir.join(run_capture::ARRAYS_FILE)).expect("arrays.bin") } else { Vec::new() };
    let schema = if arrays_on { "hashline-native-capture/5-run" } else { "hashline-native-capture/4-run" };
    // the run file
    let run = std::fs::read(dir.join("run.json")).expect("run.json");
    assert!(contains(&run, &format!("\"schema\":\"{schema}\"")), "run.json does not declare {schema}");
    assert!(contains(&run, &format!("\"blocks\":{l},")), "run.json does not declare {l} blocks");
    assert!(contains(&run, &format!("\"run_binding\":{binding:?}")), "run.json does not carry the run binding the statement computed");
    assert_eq!(count(&run, "\"plane_index\":"), 1, "the plane index table belongs in the run file exactly once");
    assert!(contains(&run, "\"hash_tag\":{\"rule\":\"blake3-keyed/1\""), "run.json does not name the keyed hash rule");
    assert!(!contains(&run, "\"rule\":\"legacy\""), "a tagged bundle claims the legacy rule");
    // the stage files
    for k in 0..l {
        let stage = std::fs::read(dir.join(run_capture::stage_file(k))).expect("a stage file");
        assert!(contains(&stage, &format!("\"schema\":\"{schema}\"")), "stage {k} does not declare {schema}");
        assert!(!contains(&stage, "\"plane_index\":"), "stage {k} carries its own copy of the plane index");
        assert!(contains(&stage, &format!("\"segment_bytes\":{}", segs[k].len())), "stage {k} does not carry its segment's length");
        assert!(contains(&stage, &format!("\"segment_sha256\":\"{}\"", crate::export_v3::sha256_hex(&segs[k]))), "stage {k} is not pinned to the bytes that were verified");
        assert_eq!(count(&stage, "\"definition_challenges\":"), N_SLOTS, "stage {k} does not carry twenty-three slot transcripts");
    }
    // the allow-list, over every JSON file of the bundle
    let mut checked = 0usize;
    for name in names.iter().filter(|n| n.ends_with(".json")).cloned().chain(std::iter::once("manifest.json".to_string())) {
        let bytes = std::fs::read(dir.join(&name)).expect("a bundle file");
        for key in run_capture::keys_of(&bytes) {
            assert!(run_capture::ALLOWED_KEYS.contains(&key.as_str()), "{name} carries the field {key:?}, which is not on the capture allow-list");
            checked += 1;
        }
    }
    assert!(checked > 1000, "only {checked} fields were scanned; the scanner is not reading the bundle");
    // every array reference resolves, and its bytes hash to the digest that
    // names them (`expand_arrays` asserts both, one reference at a time)
    let mut refs = 0usize;
    for name in names.iter().filter(|n| n.ends_with(".json")) {
        let bytes = std::fs::read(dir.join(name)).expect("a bundle file");
        refs += array_refs(&bytes).len();
        let _ = expand_arrays(&bytes, &blob);
    }
    assert_eq!(refs > 0, arrays_on, "the array references and the declared encoding disagree ({refs} references, store {arrays_on})");
    total
}

/// `HL_PB_CAPTURE_DIR`, refused unless it is an absolute path OUTSIDE the
/// repository: a 125M bundle is hundreds of megabytes and is never a
/// committed artifact.
fn capture_dir_from_env() -> PathBuf {
    let raw = std::env::var("HL_PB_CAPTURE_DIR").expect("HL_PB_CAPTURE_DIR is not set: this test writes a bundle of evidence and will not choose a directory for you");
    capture_dir_checked(&raw)
}

/// The check itself, over a path given outright, so the refusal has a test.
fn capture_dir_checked(raw: &str) -> PathBuf {
    let dir = PathBuf::from(raw);
    assert!(dir.is_absolute(), "HL_PB_CAPTURE_DIR must be an absolute path, not {raw:?}");
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().expect("the crate has a parent").to_path_buf();
    let repo = std::fs::canonicalize(&repo).unwrap_or(repo);
    // judge where the directory WOULD be, so a path that does not exist yet
    // is still refused for being inside the tree
    let mut probe = dir.clone();
    let resolved = loop {
        if let Ok(c) = std::fs::canonicalize(&probe) {
            break c.join(dir.strip_prefix(&probe).expect("a path is a prefix of itself"));
        }
        match probe.parent() {
            Some(p) => probe = p.to_path_buf(),
            None => break dir.clone(),
        }
    };
    assert!(
        !resolved.starts_with(&repo),
        "HL_PB_CAPTURE_DIR={} is inside the repository at {}; a run capture bundle is written outside the tree and never committed",
        resolved.display(),
        repo.display()
    );
    dir
}

/// `HL_PB_CAPTURE_BLOCKS`, defaulting to two.
fn capture_blocks_from_env(default: usize) -> usize {
    match std::env::var("HL_PB_CAPTURE_BLOCKS") {
        Ok(v) => v.parse().unwrap_or_else(|_| panic!("HL_PB_CAPTURE_BLOCKS={v:?} is not a number")),
        Err(_) => default,
    }
}

/// `HL_PB_INPUT`: `dense` (the fully dense recipe with its non-constant
/// hidden input — the GENERIC witness, and the one that matters) or `zero`
/// (the all-zero hidden input, the named degenerate partner).
fn capture_dense_from_env() -> bool {
    match std::env::var("HL_PB_INPUT").unwrap_or_else(|_| "dense".into()).as_str() {
        "dense" => true,
        "zero" => false,
        other => panic!("HL_PB_INPUT={other:?} is not a witness this test knows; it is `dense` (the default) or `zero`"),
    }
}

/// The one capture body both the rehearsal and the 125M run go through:
/// prove, verify with a recorder, WRITE ONLY THEN, report, check.
#[allow(clippy::too_many_arguments)]
fn capture_a_run_into(tag: &str, sh: &Shape, rs: RunShape, l: usize, dense: bool, public_tables: bool, dir: &Path, note: &str, command: &str) -> usize {
    let opts = run_capture::CaptureOpts { arrays: true, public_tables };
    let t0 = std::time::Instant::now();
    let (segs, bundle, binding) = prove_and_capture_any(sh, rs, l, dense, opts);
    let capture_s = t0.elapsed().as_secs_f64();
    let (distinct, stored, deduped, inline, blob) = bundle.arrays.stats();
    eprintln!(
        "CAPTURE {tag}: L={l}, witness={}, public tables={}, prove+verify+record {capture_s:.2} s, high-water mark {:.2} GiB",
        if dense { "dense (generic)" } else { "all-zero (degenerate)" },
        if public_tables { "values" } else { "length + digest only" },
        run::peak_rss_mib() / 1024.0
    );
    eprintln!("CAPTURE {tag}: run.json {} B, stage files {:?} B", bundle.run_json.len(), bundle.stages.iter().map(|s| s.len()).collect::<Vec<_>>());
    eprintln!("CAPTURE {tag}: arrays.bin {blob} B over {distinct} distinct arrays; {stored} references ({deduped} deduplicated), {inline} small arrays inline");
    eprintln!("CAPTURE {tag}: segments {} B (pinned by digest, written only with HL_RUN_CAPTURE_SEGMENTS=1)", segs.iter().map(|s| s.len()).sum::<usize>());
    run_capture::write_bundle(dir, &bundle, &segs, note, command).unwrap_or_else(|e| panic!("{tag}: {e}"));
    let total = check_bundle_on_disk(dir, l, binding, &segs, true);
    eprintln!("CAPTURE {tag}: {total} B on disk ({:.1} MB) in {}, self-consistent, every key on the allow-list, every array reference resolved", total as f64 / 1e6, dir.display());
    total
}

// -------------------------------------------------- the three tests that run here

/// **THE ENCODING CHANGED AND NOTHING ELSE DID.** One run, captured TWICE in
/// one process — once with the classic inline lists and once with the array
/// store — and the store bundle EXPANDED back into text is byte for byte the
/// classic bundle. Two captures of one set of segments are comparable
/// because a recorder only observes: the same bytes verify the same way and
/// the recorder re-derives every challenge from them, so the only difference
/// between the two bundles is how their arrays are written.
#[test]
fn the_array_store_and_the_classic_encoding_carry_the_same_values() {
    let sh = Shape::rung_k4();
    let l = 2usize;
    let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
    let blocks = blocks_from(&public, &ff, l);
    let mut c = Chain::from_parts(&sh, l, public, ff, x0);
    let (st, owners) = statement_of_at(&c, l, &blocks, RunShape::rung_k4(l).expect("the rung-K4 run shape"));
    let segs = prove_to_vec(&st, &blocks, &mut c, owners);
    let take_one = |arrays: bool| -> Bundle {
        let guard = run_capture::Recorder::attach();
        let opts = run_capture::CaptureOpts { arrays, public_tables: true };
        run_capture::begin_run_with(st.capture_header().expect("the capture header"), st.binding().expect("the run binding"), opts);
        run::verify_run(&st, &blocks, &segs).expect("the honest run verifies");
        let b = run_capture::take().expect("a bundle for an accepted run");
        drop(guard);
        b
    };
    let classic = take_one(false);
    let stored = take_one(true);
    assert!(!classic.arrays.is_on() && stored.arrays.is_on());
    assert_eq!(classic.arrays.blob().len(), 0, "the classic encoding wrote an array store");
    let blob = stored.arrays.blob();
    assert!(blob.len() > 1_000_000, "the store holds only {} B at a shape whose openings are megabytes", blob.len());
    // the schema strings differ, and that is the ONLY textual difference
    // outside the arrays themselves
    assert!(contains(&stored.run_json, "\"schema\":\"hashline-native-capture/5-run\""));
    assert!(contains(&classic.run_json, "\"schema\":\"hashline-native-capture/4-run\""));
    let unschema = |v: &[u8]| String::from_utf8_lossy(v).replace("hashline-native-capture/5-run", "hashline-native-capture/4-run").into_bytes();
    assert_eq!(expand_arrays(&unschema(&stored.run_json), blob), classic.run_json, "run.json differs between the two encodings");
    let mut total_refs = 0usize;
    for k in 0..l {
        let refs = array_refs(&stored.stages[k]);
        total_refs += refs.len();
        assert!(!refs.is_empty(), "stage {k} externalised no array at all");
        assert_eq!(expand_arrays(&unschema(&stored.stages[k]), blob), classic.stages[k], "stage {k} differs between the two encodings");
    }
    // and the store really is smaller, by the factor the model rests on
    let (big, small) = (classic.stages.iter().map(|s| s.len()).sum::<usize>(), stored.stages.iter().map(|s| s.len()).sum::<usize>() + blob.len());
    assert!(small < big, "the store made the bundle bigger: {small} B against {big} B");
    let (distinct, stored_n, deduped, _inline, _blob) = stored.arrays.stats();
    eprintln!(
        "ARRAY STORE at rung-K4, L={l}: {total_refs} references in the stage files, {stored_n} arrays stored over {distinct} distinct ({deduped} deduplicated), {} B of arrays.bin; stage JSON {big} B classic -> {} B + arrays = {small} B ({:.2}x)",
        blob.len(),
        stored.stages.iter().map(|s| s.len()).sum::<usize>(),
        big as f64 / small as f64
    );
    let mut files: Vec<&[u8]> = vec![&stored.run_json];
    files.extend(stored.stages.iter().map(|s| s.as_slice()));
    let table = store_breakdown(&files);
    let mut sum = 0usize;
    for (key, (refs, shas, bytes)) in &table {
        sum += bytes;
        eprintln!("ARRAY STORE  member {key:<20} {refs:5} references, {:5} distinct, {bytes:10} B", shas.len());
    }
    assert_eq!(sum, blob.len(), "the per-member table does not add up to arrays.bin");
    assert_eq!(table.keys().cloned().collect::<Vec<String>>(), ["prox", "proximity_rhos", "proximity_vector", "q", "values", "vector"], "the set of externalised members moved");
}

/// **THE DRESS REHEARSAL: the heavy test's own code path, at a development
/// shape.** `capture_a_run_into` is what the 125M capture runs; here it runs
/// at `Shape::rung_k4` with three blocks, into a scratch directory outside
/// the repository that is removed when the test ends. What it establishes is
/// that the path the security owner will launch — prove, verify with the
/// recorder attached, write only after the run has verified, read the bundle
/// back and check it against itself and against the allow-list — works end
/// to end, so the only thing the 125M run adds is the shape.
#[test]
fn the_heavy_captures_code_path_works_at_a_development_shape() {
    let dir = TempDir::new("s27-rehearsal");
    let l = 3usize;
    let sh = Shape::rung_k4();
    let total = capture_a_run_into(
        "rehearsal rung-K4",
        &sh,
        RunShape::rung_k4(l).expect("the rung-K4 run shape"),
        l,
        true,
        true,
        &dir.path().join("m125-rehearsal"),
        "A dress rehearsal of the 125M capture path at the four-key-value-head development shape; deleted when the test ends.",
        "cargo test --release --lib private_block::run_capture_tests::the_heavy_captures_code_path_works_at_a_development_shape",
    );
    assert!(total > 1_000_000, "a three-block rung-K4 bundle is {total} B; the writer is not writing");
}

/// **THE CAPTURE DIRECTORY IS REFUSED INSIDE THE REPOSITORY.** The one guard
/// that cannot be tested by running the heavy test.
#[test]
fn a_capture_directory_inside_the_repository_is_refused() {
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().expect("the crate has a parent").to_path_buf();
    let inside = repo.join("results").join("zk60_block125m_lane").join("would-be-a-bundle");
    let hushed = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    let refused = std::panic::catch_unwind(|| capture_dir_checked(inside.to_str().expect("an ASCII path")));
    let relative = std::panic::catch_unwind(|| capture_dir_checked("some/relative/place"));
    let accepted = std::panic::catch_unwind(|| capture_dir_checked("/home/victor/zk60-artifacts/s27-guard-probe"));
    std::panic::set_hook(hushed);
    let msg = |e: Box<dyn std::any::Any + Send>| e.downcast_ref::<String>().map(|s| s.clone()).unwrap_or_default();
    let m = msg(refused.expect_err("a directory inside the repository was accepted"));
    assert!(m.contains("inside the repository"), "the refusal does not say why: {m}");
    let m = msg(relative.expect_err("a relative path was accepted"));
    assert!(m.contains("absolute"), "the relative-path refusal does not say why: {m}");
    accepted.expect("a directory outside the repository is accepted although it does not exist yet");
    let _ = repo;
}

// -------------------------------------------------- the heavy one, written and NOT run

/// **STAGE 27: CAPTURE ONE PRIVATE RUN AT THE 125M SHAPE.**
///
/// **Why this test exists.** The Python privacy gate has replayed every
/// challenge, re-hashed every opened column, closed every per-slot terminal
/// identity and constructed a per-commitment and a joint preimage — on real
/// bytes, at two DEVELOPMENT shapes. Its standing limit is one sentence:
/// nothing has been measured at the 125M shape. That was assumed out of
/// reach because a 125M receipt is 40 MB a block, but a capture is not the
/// receipt: it is the VERIFIER'S VIEW, and the gate's per-commitment work
/// scales with the message length `2^14`, not with the 45 KB columns.
///
/// **This lane does not run it.** It is `#[ignore]`d, it must be launched
/// detached under the heavy lock inside a memory ceiling on a quiesced box,
/// and the security owner launches it himself. The exact commands are in the
/// lane ledger's stage 27 section.
///
/// **What it does, in order.** Builds the chain, PROVES the run with the
/// production prover, VERIFIES it with the production verifier through the
/// capture's verifier-side hooks exactly as every development capture does,
/// and writes the bundle **only after the run has verified** (ruling D21 /
/// M-9: `take` refuses unless `L` stages closed, the replay never failed and
/// the run's closing check passed, and nothing reaches the disk before that).
/// It then reads the bundle back and checks it against itself: the manifest's
/// lengths and SHA-256, the plane index table present once in `run.json` and
/// in no stage file, the hash tag, the rebuilt run binding, each stage's
/// segment pin, every key on the allow-list, and every `arrays.bin`
/// reference resolved and re-hashed.
///
/// **The environment it reads.**
///
/// | variable | what | default |
/// |---|---|---|
/// | `HL_PB_CAPTURE_DIR` | where the bundle goes | **required**, absolute, and refused inside the repository |
/// | `HL_PB_CAPTURE_BLOCKS` | `L` | 2 |
/// | `HL_PB_INPUT` | `dense` (the generic witness) or `zero` (the degenerate partner) | `dense` |
/// | `HL_RUN_CAPTURE_PUBLIC_TABLES` | `1` carries the public tables' values, `0` their length and digest only | **required**, no default |
/// | `HL_TEST_SOURCE_COMMIT` | the commit the bundle records | `uncommitted-test` |
///
/// The array store is always on here: it is the whole reason a 125M capture
/// is possible, and `the_array_store_and_the_classic_encoding_carry_the_same_values`
/// is what says it costs nothing in content.
///
/// **What to expect** (all [MODEL], from the committed rung bundles' measured
/// per-element costs and the shape's own counts — the ledger's stage 27
/// table has the per-member breakdown): with the public tables' values,
/// about 350 MB for `L = 2`, of which about 258 MB is `arrays.bin` and
/// about 256 MB of that is the shape-only public tables, which are stored
/// ONCE for the whole bundle — so a third block costs about 46 MB, not 175.
/// Without them, about 92 MB for `L = 2`. Proving is about 2 x 31 s and
/// verifying about 2 s; the capture adds a few hundred megabytes of
/// resident memory during the verify, against a proving peak of 10.05 GiB.
#[test]
#[ignore = "captures a 125M run; heavy. set HL_PB_CAPTURE_DIR (outside the repo) and HL_RUN_CAPTURE_PUBLIC_TABLES"]
fn capture_a_125m_run() {
    let sh = Shape::m125();
    let l = capture_blocks_from_env(2);
    let dense = capture_dense_from_env();
    let dir = capture_dir_from_env();
    let public_tables = match std::env::var("HL_RUN_CAPTURE_PUBLIC_TABLES").as_deref() {
        Ok("1") => true,
        Ok("0") => false,
        _ => panic!(
            "HL_RUN_CAPTURE_PUBLIC_TABLES is not set to 1 or 0: whether a bundle carries the public tables' VALUES decides both what the run gate can close and how large the bundle is (about 350 MB with them at L = 2, about 92 MB without), so this test will not pick for you"
        ),
    };
    assert!(!sh.hashes_under_the_legacy_rule(), "the 125M profile is meant to be TAGGED and this shape is not");
    eprintln!("CAPTURE 125M: {}", if std::env::var("MALLOC_MMAP_THRESHOLD_").is_ok() { "MALLOC_MMAP_THRESHOLD_ is pinned" } else { "MALLOC_MMAP_THRESHOLD_ is NOT SET (expect the high-water mark to rise across blocks)" });
    let note = format!(
        "Bundle: one honest {l}-block private run at the **125M shape**\n(`Shape::m125`: 512 tokens, width 768, hidden 2048, 12 query heads of 64 over\n4 key-value heads, row width 2^14, rate 4, 256 opened columns, a generalised\nendpoint of 37 rows over the padded Dom::D cube), under the D19 separating\nhash tag, profile `hashline-zk-mr1/private-run-m125/1`.\n\nWHY IT EXISTS. Every capture before this one is at a DEVELOPMENT shape. The\nPython privacy gate's standing limit is that nothing has been measured at the\n125M shape; this bundle is the first object at that shape a gate can read.\n\nHidden input and public weights: {}\n\nTHE ENCODING IS NEW (schema `hashline-native-capture/5-run`). Every\nfield-element array of at least 256 entries is written in the JSON as\n`{{\"array\":\"<sha256>\",\"elem\":\"fp\"|\"fp2\",\"len\":N,\"offset\":O,\"bytes\":B}}` and its\nvalues are the B bytes at offset O of `arrays.bin`, little-endian: eight bytes\nper `fp`, sixteen per `fp2` (`c0` then `c1`). Identical arrays are stored once.\nEverything else is byte for byte what `hashline-native-capture/4-run` writes,\nand a Rust test decodes one run captured BOTH ways and compares the two\nbundles byte for byte. Format note: `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md` §12.\n\nWHAT IS NOT HERE, as in every bundle: no witness value, no pad, no mask\ncoefficient, no unopened column, no unpublished salt, no unmasked sumcheck\nround, no prover log and no timing of a witness-dependent step. The verifier's\nview and nothing else.\n\nDevelopment-grade nothing: the 125M profile is the real one, but a capture is\nthe INPUT to the privacy gate of ruling M-8 and is NOT a privacy result. No\ngate has read this.",
        if dense {
            "the FULLY DENSE run recipe (`private_block::dense_tests::dense_run_case`) at 125M's measured chain band (down band 1): every entry of all nine public words nonzero, a non-constant hidden input from its own unpublished stream, the upper hidden half live, twelve of sixteen head slots live and all four key-value groups carrying different data. THE GENERIC WITNESS"
        } else {
            "the ALL-ZERO hidden plane on the lane's synthetic tame fixture - the fixed input the privacy case is stated at, and the named DEGENERATE partner of the dense run"
        }
    );
    let total = capture_a_run_into(
        "125M",
        &sh,
        RunShape::m125(l).expect("the 125M run shape"),
        l,
        dense,
        public_tables,
        &dir,
        &note,
        "HL_PB_CAPTURE_DIR=<dir> HL_PB_INPUT=<dense|zero> HL_PB_CAPTURE_BLOCKS=<L> HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=<commit> cargo test --release --lib private_block::run_capture_tests::capture_a_125m_run -- --ignored --nocapture",
    );
    // a runaway guard, an order of magnitude above the modelled 350 MB: a
    // bundle this large means the encoding did not do what it was built for
    assert!(total < 2_000_000_000, "the 125M bundle is {total} B, past the 2 GB runaway ceiling");
    eprintln!("CAPTURE 125M RESULT: {total} B ({:.1} MB) at {} — a CAPTURE, not a privacy result; no gate has read it", total as f64 / 1e6, dir.display());
}

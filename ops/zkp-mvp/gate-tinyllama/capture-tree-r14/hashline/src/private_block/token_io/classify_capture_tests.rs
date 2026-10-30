//! **TOKEN I/O ROUND 12: RUN CAPTURES OF CLASSIFIER RUNS** (the privacy gate
//! lane's round-16 request `results/zk60_gate_tinyllama_20261017/round16/
//! CLASSIFY_CAPTURE_HOOK_REQUEST.md`, its §4 minimal subset). TEST CODE ONLY.
//!
//! A capture is the VERIFIER'S VIEW of one accepted classifier run, written by
//! `run_capture.rs` (schema `hashline-native-capture/7-classify-run`): stage
//! IN-C, the `L` blocks and stage OUT-C, each with its slot transcripts, its
//! M opening and every PCS opening (A-in / H-in / the input token endpoint;
//! A / H / the boundary before each block, `B_in` at block 0; A-out / H-out /
//! `B_out`; NO output endpoint). The hooks fire only on the verifier's side
//! and only when a recorder is attached; they are `cfg(test)`, so no
//! production build carries them. A capture never holds a content id, the
//! margin, a limb, an activation or the owner's decommitment; the verdict is
//! public.
//!
//! Here: the rung run captured and checked against itself and the
//! allow-list (verdict 1, and a D41 chunk at the tie); the prover's path
//! records nothing with a recorder attached; a tampered run writes no
//! bundle. And the `#[ignore]`d, environment-driven capture the gate reads:
//! the rung at `L` = 1 / 2, verdict 0 / 1 / tie, the whole content or a D41
//! chunk (round 14: or a SHORT item, one chunk of fewer ids than the plan's).
//!
//! **ROUND 14 (REVIEW_R13 N-r13-1, §10 item 1): the fixture's tables are
//! R-C2's**, derived from the development rung's pinned tensor through the
//! CLI's own tied loader under a tiny dev export's profile (each policy with
//! its c placed gets its own export profile: one parameter set per export,
//! N-r13-3). The replay refuses a run whose tables are the relation tests'
//! synthetic binding.

use super::classify::*;
use super::classify_cli_tests::{add_classifier_parameters, fixture_root, write_classifier_tables};
use super::classify_run::*;
use super::classify_tied::{dev_tied_tensor_bytes, load_bound_tables, recompute_tied_classifier, BoundClassifierTables, TiedSource, DEV_TIED_TENSOR_FILE};
use super::run::VerifierPolicy;
use super::tests::{blocks, ctx, generic_tables, lcg, model_at, model_with_records_prov, norm, rung};
use super::super::trained_block::TrainedExport;
use super::super::trained_block_tests::{write_export, Fault};
use super::super::trained_statement::LayerRecord;
use super::*;
use super::super::run::{RunShape, RUN_PROFILE_CLASSIFY_RUNG_TC};
use super::super::run_capture::{self, Bundle, CaptureOpts};
use super::super::trained_statement::TrainedModelStatement;
use super::super::BlockPublic;
use std::path::{Path, PathBuf};

const POLICY_93: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 93 };
const SCHEMA: &str = "hashline-native-capture/7-classify-run";

fn contains(hay: &[u8], needle: &str) -> bool {
    hay.windows(needle.len()).any(|w| w == needle.as_bytes())
}

fn count(hay: &[u8], needle: &str) -> usize {
    hay.windows(needle.len()).filter(|w| *w == needle.as_bytes()).count()
}

/// the rung fixture: `l` generic dense blocks under the classifier run
/// profile and (ROUND 14) the rung policy's R-C2 tables: its trained
/// statement names a tiny dev export's profile (with the classifier's
/// authorities) and residual unit, and the tables are derived from the pinned
/// tensor under it through the tied loader
struct Fx {
    sh: Shape,
    blocks: Vec<BlockPublic>,
    model: TrainedModelStatement,
    bound: BoundClassifierTables,
    dir: FxDir,
}

/// the fixture's directory under the fixture root, removed on drop
struct FxDir(PathBuf);

impl Drop for FxDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

static FX_SEQ: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

/// **one export profile for `policy`** (a tiny dev export carrying the
/// classifier's authorities: BOS, the final norm, and `policy`'s yes / no /
/// scale / c), the synthetic trained statement of `blocks` naming that
/// profile, and its tables derived from the pinned tensor and loaded through
/// the tied loader
fn bind_policy(dir: &Path, sh: &Shape, blocks: &[BlockPublic], policy: &Policy) -> (TrainedModelStatement, BoundClassifierTables) {
    let tag: String = policy.id.chars().map(|c| if c.is_ascii_alphanumeric() { c } else { '_' }).collect();
    let (export, _) = write_export(&dir.join(format!("x-{tag}")), "tiny", &Fault::default());
    add_classifier_parameters(&export, 1, norm(), policy);
    let x = TrainedExport::load(&export).unwrap();
    let recs: Vec<LayerRecord> = blocks.iter().enumerate().map(|(k, b)| LayerRecord::of_block(k as u32, b, vec![])).collect();
    let model = model_with_records_prov(sh, recs, RUN_PROFILE_CLASSIFY_RUNG_TC, x.residual_unit, x.profile_sha256);
    let tables = dir.join(format!("t-{tag}"));
    std::fs::create_dir_all(&tables).unwrap();
    std::fs::write(tables.join(DEV_TIED_TENSOR_FILE), dev_tied_tensor_bytes()).unwrap();
    let tied = recompute_tied_classifier(TiedSource::DevRung, &export, &tables, policy, x.residual_unit, sh.width, &x.profile_sha256).expect("the dev derivation");
    let g = generic_tables(sh.width, 0x636c_6363);
    let t = TokenTables::new(g.v, g.d, tied.emb.clone().expect("the dev embedding"), g.head, g.mult).unwrap();
    write_classifier_tables(&tables, &t, &tied.w, tied.bos, tied.norm, policy);
    let bound = load_bound_tables(sh, &model, &export, &tables, policy).expect("the derived tables load through the tied loader");
    (model, bound)
}

fn fx(l: usize) -> Fx {
    let sh = rung();
    let blocks = blocks(&sh, l);
    let dir = FxDir(fixture_root().join(format!("cls-capture-fx-{}-{}", std::process::id(), FX_SEQ.fetch_add(1, std::sync::atomic::Ordering::SeqCst))));
    let _ = std::fs::remove_dir_all(&dir.0);
    std::fs::create_dir_all(&dir.0).unwrap();
    let (model, bound) = bind_policy(&dir.0, &sh, &blocks, &policy_rung_dev());
    Fx { sh, blocks, model, bound, dir }
}

/// `n` content ids in `[num_special, V)` from a seed
fn content(p: &Policy, n: usize, seed: u64) -> Vec<u64> {
    let mut s = seed;
    (0..n).map(|_| p.num_special + lcg(&mut s) % (p.v as u64 - p.num_special)).collect()
}

/// One honest classifier run, proved: the statement, the receipt, the
/// owner's decommitment (round 14: and the policy's own trained statement
/// and bound tables).
struct Run {
    st: ClassifyRunStatement,
    segs: Vec<Vec<u8>>,
    dec: Decommitment,
    margin: i64,
    policy: Policy,
    chunk: ChunkRef,
    model: TrainedModelStatement,
    bound: BoundClassifierTables,
}

/// **An honest run at a wanted verdict** (`"0"`, `"1"` or `"tie"`) of the
/// whole content (`chunk = None`) or of chunk `j` of a `total`-id content
/// (D41; round 14: `total` below the plan's size is a SHORT item, one chunk
/// of its length). The margin of the item is taken first under the rung
/// policy; then c is placed as `classify_tests` places it (a registered test
/// policy with ITS OWN export profile, N-r13-3): `margin - 1` for verdict 1,
/// `margin` for the tie (verdict 0, delta 0), `margin + 1` for verdict 0.
fn honest_run(f: &Fx, want: &str, chunk: Option<(usize, usize)>) -> Run {
    let base = policy_rung_dev();
    let size = f.sh.tokens - base.prefix.len() - base.suffix.len();
    let (total, index) = chunk.unwrap_or((size, 0));
    let mut whole = content(&base, total.min(size), 0x6361_7031);
    if total > size {
        whole.extend(content(&base, total - size, 0x6361_7032));
    }
    assert_eq!(whole.len(), total);
    let ch = ChunkRef::derive(total, index, ChunkPlan { size, overlap: chunk_overlap_of(RUN_PROFILE_CLASSIFY_RUNG_TC).unwrap() }).expect("the chunk");
    let n = ch.b - ch.a;
    let shapes = vec![f.sh.clone(); f.blocks.len()];
    let cp0 = ClassifierProfile::new(&f.sh, f.bound.tables(), f.bound.bos(), f.bound.norm(), &base, n, Tier::R1_MVP).unwrap();
    let tokens = cp0.tokens_of(&whole[ch.a..ch.b]).unwrap();
    let margin = honest_classify(&shapes, &cp0, f.bound.tables(), &f.blocks, &tokens).expect("the honest pipeline").out_values.margin;
    let c = match want {
        "1" => margin - 1,
        "tie" => margin,
        "0" => margin + 1,
        other => panic!("HL_PB_CLASSIFY_VERDICT={other:?} is 0, 1 or tie"),
    };
    let mut policy = base.clone();
    policy.id = format!("rung-tc-capture-test-policy/{c}");
    policy.c = c;
    register_test_policy(policy.clone());
    let (model, bound) = bind_policy(&f.dir.0, &f.sh, &f.blocks, &policy);
    let cp = ClassifierProfile::new(&f.sh, bound.tables(), bound.bos(), bound.norm(), &policy, n, Tier::R1_MVP).unwrap();
    let mut p = honest_classify(&shapes, &cp, bound.tables(), &f.blocks, &tokens).expect("the honest pipeline under the placed c");
    let verdict = p.out_values.verdict;
    assert_eq!(verdict, u8::from(want == "1"), "the placed c gives the wanted verdict");
    let spec = input_endpoint_spec(&f.sh, ctx(), &cp).unwrap();
    let (root, owner) = seal_input(&spec, &p.in_plane, &f.sh.hash_tag()).unwrap();
    let st = ClassifyRunStatement::new_chunk(RunShape::new(f.sh.clone(), f.blocks.len(), RUN_PROFILE_CLASSIFY_RUNG_TC).unwrap(), ctx(), f.blocks.iter().map(|b| b.digest()).collect(), &model, &bound, &policy, n, Tier::R1_MVP, root, verdict, total, index).expect("the statement");
    let mut segs = Vec::new();
    let (_, dec) = prove_classify_run(&st, &f.blocks, &bound, &mut ClassifySource(&mut p), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the honest classifier run proves");
    assert!(st.tables_derived(), "the capture fixture's tables are derived");
    Run { st, segs, dec, margin, policy, chunk: ch, model, bound }
}

/// what the bundle checks read (a proved [`Run`] or a CLI run directory)
struct Parts<'a> {
    st: &'a ClassifyRunStatement,
    segs: &'a [Vec<u8>],
    dec: &'a Decommitment,
    chunk: ChunkRef,
    policy: &'a Policy,
}

/// verify `segs` with a recorder attached; the bundle only for an accepted run
fn capture(st: &ClassifyRunStatement, blocks: &[BlockPublic], tables: &BoundClassifierTables, segs: &[Vec<u8>], opts: CaptureOpts) -> Result<Bundle, String> {
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(st.capture_header()?, st.binding()?, opts);
    let out = match verify_classify_run(st, blocks, tables, segs, POLICY_93) {
        Ok(()) => run_capture::take(),
        Err(e) => {
            run_capture::discard();
            Err(e)
        }
    };
    drop(guard);
    out
}

/// every key of every file of a bundle is on the allow-list
fn keys_allowed(b: &Bundle) -> usize {
    let mut n = 0usize;
    let mut files: Vec<(&str, &[u8])> = vec![("run.json", &b.run_json)];
    for s in &b.stages {
        files.push(("stage", s));
    }
    for (name, bytes) in files {
        for key in run_capture::keys_of(bytes) {
            assert!(run_capture::ALLOWED_KEYS.contains(&key.as_str()), "{name} carries the field {key:?}, which is not on the capture allow-list");
            n += 1;
        }
    }
    n
}

/// every `"salt":[...]` value and every unsigned integer of a JSON file
fn index_json(bytes: &[u8], salts: &mut std::collections::HashSet<Vec<u8>>, numbers: &mut std::collections::HashSet<u64>) {
    const KEY: &[u8] = b"\"salt\":";
    let mut i = 0usize;
    while i < bytes.len() {
        if bytes[i] == b'"' && bytes[i..].starts_with(KEY) {
            let start = i + KEY.len();
            if let Some(end) = bytes[start..].iter().position(|&c| c == b']') {
                salts.insert(bytes[start..start + end + 1].to_vec());
                i = start + end + 1;
                continue;
            }
        }
        if bytes[i].is_ascii_digit() {
            let (mut j, mut v, mut ok) = (i, 0u64, true);
            while j < bytes.len() && bytes[j].is_ascii_digit() {
                match v.checked_mul(10).and_then(|x| x.checked_add(u64::from(bytes[j] - b'0'))) {
                    Some(x) => v = x,
                    None => ok = false,
                }
                j += 1;
            }
            if ok {
                numbers.insert(v);
            }
            i = j;
            continue;
        }
        i += 1;
    }
}

/// **the checks every classifier bundle must pass**, whatever its geometry
fn check_classify_bundle(b: &Bundle, r: &Run, l: usize) {
    check_classify_bundle_parts(b, &r.st, &r.segs, &r.dec, l);
}

/// the same checks from a statement, its segments and the owner's decommitment
fn check_classify_bundle_parts(b: &Bundle, st: &ClassifyRunStatement, segs: &[Vec<u8>], dec: &Decommitment, l: usize) {
    let r = Parts { st, segs, dec, chunk: st.chunk(), policy: &st.cp.policy };
    let binding = r.st.binding().unwrap();
    assert_eq!(b.stages.len(), l + 2, "a classifier bundle has L + 2 stage files");
    assert!(contains(&b.run_json, &format!("\"schema\":\"{SCHEMA}\"")), "run.json does not declare the classifier schema");
    assert!(contains(&b.run_json, &format!("\"blocks\":{l},\"stages\":{}", l + 2)), "run.json does not declare L and L + 2");
    assert!(contains(&b.run_json, &format!("\"run_binding\":{binding:?}")), "run.json does not carry the run binding the statement computed");
    assert!(contains(&b.run_json, &format!("\"classify\":{{\"run_profile\":\"{RUN_PROFILE_CLASSIFY_RUNG_TC}\"")), "run.json carries no classifier facts");
    assert!(contains(&b.run_json, &format!("\"verdict\":{},", r.st.verdict())), "run.json does not carry the public verdict");
    let c = r.chunk;
    assert!(contains(&b.run_json, &format!("\"chunk\":{{\"index\":{},\"count\":{},\"a\":{},\"b\":{},\"total\":{},\"size\":{},\"overlap\":{}}}", c.index, c.count, c.a, c.b, c.total, c.size, c.overlap)), "run.json does not carry the chunk");
    assert!(contains(&b.run_json, &format!("\"id\":{:?}", r.policy.id)) && contains(&b.run_json, &format!("\"c\":{},", r.policy.c)), "run.json does not carry the policy and its c");
    assert!(contains(&b.run_json, &format!("\"margin_vector\":{{\"digest\":{:?}", r.st.cp.w_digest)), "run.json does not carry the margin vector's digest");
    assert!(contains(&b.run_json, "\"output_endpoint\":null"), "a classifier run has no output endpoint");
    // the header's last two absorbs, in order, right after `schedule` (the gate's MC-7)
    let labels = b.run_json.windows(b"\"label\":\"schedule\"".len()).position(|w| w == b"\"label\":\"schedule\"").expect("the schedule label");
    let tail = &b.run_json[labels..];
    let (v, ch, stage) = (tail.windows(18).position(|w| w == b"\"classify-verdict\"").expect("classify-verdict"), tail.windows(16).position(|w| w == b"\"classify-chunk\"").expect("classify-chunk"), tail.windows(14).position(|w| w == b"\"pb-run-stage\"").expect("pb-run-stage"));
    assert!(v < ch && ch < stage, "classify-verdict and classify-chunk are not the header's last two absorbs");
    assert_eq!(count(&b.run_json, "\"plane_index\":"), 1, "the block plane index belongs in run.json exactly once");
    assert!(contains(&b.run_json, "\"owner decommitments\"") && contains(&b.run_json, "\"the content's token ids\""), "not_in_a_capture is incomplete");
    for (k, s) in b.stages.iter().enumerate() {
        let (kind, slots, order) = if k == 0 {
            ("IN-C", 4, "[\"M\", \"A-in\", \"H-in\", \"E-token-in\"]")
        } else if k == l + 1 {
            ("OUT-C", 8, "[\"M\", \"A-out\", \"H-out\", \"B-out\"]")
        } else {
            ("BLOCK", 23, "[\"M\", \"A\", \"H\", \"Input\"]")
        };
        assert!(contains(s, &format!("\"schema\":\"{SCHEMA}\"")), "stage {k} does not declare the classifier schema");
        assert!(contains(s, &format!("\"stage\":{k},\"stage_kind\":\"{kind}\"")), "stage {k} is not {kind}");
        assert_eq!(count(s, "\"definition_challenges\":"), slots, "stage {k} ({kind}) does not carry {slots} slot transcripts");
        assert!(contains(s, &format!("\"opening_order\":{order}")), "stage {k}'s opening order is not {order}");
        assert!(contains(s, &format!("\"segment_bytes\":{}", r.segs[k].len())), "stage {k} does not carry its segment's length");
        assert!(contains(s, &format!("\"segment_sha256\":\"{}\"", crate::export_v3::sha256_hex(&r.segs[k]))), "stage {k} is not pinned to the bytes that were verified");
        assert_eq!(contains(s, "\"stage_plane_index\":"), kind != "BLOCK", "stage {k}'s plane table");
        assert!(!contains(s, "\"plane_index\":"), "stage {k} carries a copy of the block plane index");
        assert!(!contains(s, "E-token-out"), "stage {k} names an output endpoint");
    }
    assert!(contains(&b.stages[0], "\"r_emb\":[["), "stage IN-C records no r_emb challenge");
    assert!(contains(&b.stages[0], "\"commitment_kind\":\"stage-in-c\""), "stage IN-C's openings are not marked stage-in-c");
    assert!(contains(&b.stages[l + 1], "\"commitment_kind\":\"stage-out-c\""), "stage OUT-C's openings are not marked stage-out-c");
    assert!(contains(&b.stages[1], "\"commitment_kind\":\"B-in\""), "block 0's stage does not open B_in");
    assert!(contains(&b.stages[l + 1], "\"commitment_kind\":\"B-out\""), "stage OUT-C does not open B_out");
    // NO OWNER DECOMMITMENT: at most Q of the owner's salts (the opened
    // columns' salts are in the receipt) and none of its pad words
    let (mut salts, mut numbers) = (std::collections::HashSet::new(), std::collections::HashSet::new());
    for f in std::iter::once(&b.run_json).chain(b.stages.iter()) {
        index_json(f, &mut salts, &mut numbers);
    }
    let words: std::collections::HashSet<u64> = b.arrays.blob().chunks_exact(8).map(|c| u64::from_le_bytes(c.try_into().expect("8 bytes"))).collect();
    let d = r.dec;
    let found = d.salts.iter().filter(|salt| salts.contains(format!("{salt:?}").as_bytes())).count();
    assert!(found <= Tier::R1_MVP.opened_cols && found < d.salts.len(), "the owner's decommitment: {found} of its {} salts are in the bundle", d.salts.len());
    for pad in d.pads.iter().filter(|p| p.0 >= 1_000_000_000_000) {
        assert!(!numbers.contains(&pad.0), "an owner's pad word is in the bundle's JSON");
        assert!(!words.contains(&pad.0), "an owner's pad word is in arrays.bin");
    }
    let n = keys_allowed(b);
    assert!(n > 1000, "only {n} keys were scanned");
}

// -------------------------------------------------- the rung (fast)

/// **A CLASSIFIER RUN IS CAPTURED AND ITS BUNDLE IS SELF-CONSISTENT** (the
/// rung, `L = 2`, verdict 1): `L + 2` stage files, IN-C / BLOCK / OUT-C in
/// order with their slot counts and opening orders, no output endpoint,
/// every segment pinned, the classifier facts (policy, c, the margin
/// vector's digest, the verdict, the chunk) and the header's last two
/// labels, the plane tables, every key on the allow-list, and no owner
/// decommitment anywhere.
#[test]
fn r12_a_classify_run_is_captured_and_its_bundle_is_self_consistent() {
    let f = fx(2);
    let r = honest_run(&f, "1", None);
    let b = capture(&r.st, &f.blocks, &r.bound, &r.segs, CaptureOpts { arrays: false, public_tables: true }).expect("a bundle for an accepted classifier run");
    check_classify_bundle(&b, &r, 2);
    assert!(run_capture::bundle_is_classify(&b));
    eprintln!("CLASSIFY CAPTURE rung L=2 verdict 1 (margin {}): run.json {} B, stage files {:?} B", r.margin, b.run_json.len(), b.stages.iter().map(|s| s.len()).collect::<Vec<_>>());
}

/// **D41: a chunk at the tie is captured** (`L = 1`, chunk 1 of a 27-id
/// content, `[4, 27)`, c = the margin, so verdict 0): the chunk and the
/// verdict in run.json, the same checks.
#[test]
fn r12_a_classify_chunk_at_the_tie_is_captured() {
    let f = fx(1);
    let r = honest_run(&f, "tie", Some((27, 1)));
    assert_eq!((r.chunk.a, r.chunk.b, r.st.verdict()), (4, 27, 0));
    let b = capture(&r.st, &f.blocks, &r.bound, &r.segs, CaptureOpts { arrays: true, public_tables: false }).expect("a bundle for the chunk");
    check_classify_bundle(&b, &r, 1);
    eprintln!("CLASSIFY CAPTURE rung L=1 chunk 1 of 2 [4, 27) at the tie: run.json {} B, arrays.bin {} B", b.run_json.len(), b.arrays.blob().len());
}

/// **THE HOOKS ARE NO-OPS ON THE PROVER'S PATH, AND A RUN VERIFIES THE SAME
/// WITH AND WITHOUT A RECORDER.** A classifier run proved while a recorder is
/// attached and seeded with its header records nothing; the receipt verifies
/// without a recorder, with one (a bundle), and again without.
#[test]
fn r12_the_classify_hooks_are_inert_on_the_prover_and_a_run_verifies_the_same_with_and_without_a_recorder() {
    let f = fx(1);
    let r0 = honest_run(&f, "0", None);
    // re-prove the same item with a recorder attached and seeded
    let cp = r0.st.cp.clone();
    let tokens = cp.tokens_of(&content(&r0.policy, cp.n, 0x6361_7031)).unwrap();
    let mut p = honest_classify(&[f.sh.clone()], &cp, r0.bound.tables(), &f.blocks, &tokens).unwrap();
    let spec = input_endpoint_spec(&f.sh, ctx(), &cp).unwrap();
    let (root, owner) = seal_input(&spec, &p.in_plane, &f.sh.hash_tag()).unwrap();
    let st = ClassifyRunStatement::new(RunShape::new(f.sh.clone(), 1, RUN_PROFILE_CLASSIFY_RUNG_TC).unwrap(), ctx(), f.blocks.iter().map(|b| b.digest()).collect(), &r0.model, &r0.bound, &r0.policy, cp.n, Tier::R1_MVP, root, p.out_values.verdict).unwrap();
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(st.capture_header().unwrap(), st.binding().unwrap(), CaptureOpts { arrays: false, public_tables: false });
    let mut segs = Vec::new();
    prove_classify_run(&st, &f.blocks, &r0.bound, &mut ClassifySource(&mut p), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the honest run proves with a recorder attached");
    assert_eq!(run_capture::recorded(), Some((0, false, None)), "the prover's path touched the recorder");
    run_capture::discard();
    drop(guard);
    assert_eq!(segs.iter().map(|s| s.len()).collect::<Vec<_>>(), st.segment_lens().unwrap(), "the receipt's segments are not the counted lengths");
    verify_classify_run(&st, &f.blocks, &r0.bound, &segs, POLICY_93).expect("verifies without a recorder");
    let b = capture(&st, &f.blocks, &r0.bound, &segs, CaptureOpts { arrays: false, public_tables: false }).expect("verifies with a recorder");
    assert_eq!(b.stages.len(), 3);
    verify_classify_run(&st, &f.blocks, &r0.bound, &segs, POLICY_93).expect("and again without");
    eprintln!("CLASSIFY CAPTURE | the prover records nothing with a recorder attached; the receipt verifies with and without one");
}

/// **A TAMPERED CLASSIFIER RUN WRITES NO BUNDLE**, and a receipt read under
/// the other verdict is refused by the replay as by the verifier.
#[test]
fn r12_a_tampered_or_reverdicted_classify_run_is_refused_and_no_bundle_is_written() {
    let f = fx(1);
    let r = honest_run(&f, "1", None);
    let mut segs = r.segs.clone();
    let mid = segs[1].len() / 2;
    segs[1][mid] ^= 1;
    let e = capture(&r.st, &f.blocks, &r.bound, &segs, CaptureOpts { arrays: false, public_tables: false }).err().expect("A TAMPERED CLASSIFIER RUN WAS CAPTURED");
    assert!(!run_capture::active(), "a recorder was left attached");
    let other = ClassifyRunStatement::new(RunShape::new(f.sh.clone(), 1, RUN_PROFILE_CLASSIFY_RUNG_TC).unwrap(), ctx(), f.blocks.iter().map(|b| b.digest()).collect(), &r.model, &r.bound, &r.policy, r.st.cp.n, Tier::R1_MVP, r.st.in_root(), 0).unwrap();
    let e2 = capture(&other, &f.blocks, &r.bound, &r.segs, CaptureOpts { arrays: false, public_tables: false }).err().expect("A RE-VERDICTED CLASSIFIER RUN WAS CAPTURED");
    assert!(!run_capture::active());
    eprintln!("CLASSIFY CAPTURE | a tampered run refused ({e}); read as verdict 0 refused ({e2}); no bundle");
}

/// the public tables the capture fixture proves with
fn fx_tables(f: &Fx) -> &ClassifierTables {
    f.bound.tables()
}

/// **ROUND 14 (N-r13-1): the replay refuses a run on the relation tests'
/// synthetic binding** (a generic embedding and a random margin row, test
/// builds only): the run verifies (it is a relation test), but no bundle is
/// written for it.
#[test]
fn r14_a_capture_of_relation_test_tables_is_refused_by_the_replay() {
    let sh = rung();
    let blks = blocks(&sh, 1);
    let model = model_at(&sh, &blks, RUN_PROFILE_CLASSIFY_RUNG_TC);
    let tt = generic_tables(sh.width, 0x636c_6173);
    let mut s = 0x6d61_7267u64;
    let w: Vec<i16> = (0..sh.width).map(|_| ((lcg(&mut s) % 65_535) as i64 - 32_767) as i16).collect();
    let dev = policy_rung_dev();
    let bound = BoundClassifierTables::synthetic_for_relation_tests(ClassifierTables::new(tt.v, tt.d, tt.emb.clone(), w).unwrap(), 1, norm(), &sh, RUN_PROFILE_CLASSIFY_RUNG_TC, &model, &dev).unwrap();
    assert!(!bound.is_derived());
    let n = sh.tokens - dev.prefix.len() - dev.suffix.len();
    let cp = ClassifierProfile::new(&sh, bound.tables(), 1, norm(), &dev, n, Tier::R1_MVP).unwrap();
    let mut p = honest_classify(&[sh.clone()], &cp, bound.tables(), &blks, &cp.tokens_of(&content(&dev, n, 0x7273)).unwrap()).unwrap();
    let (root, owner) = seal_input(&input_endpoint_spec(&sh, ctx(), &cp).unwrap(), &p.in_plane, &sh.hash_tag()).unwrap();
    let st = ClassifyRunStatement::new(RunShape::new(sh.clone(), 1, RUN_PROFILE_CLASSIFY_RUNG_TC).unwrap(), ctx(), blks.iter().map(|b| b.digest()).collect(), &model, &bound, &dev, n, Tier::R1_MVP, root, p.out_values.verdict).unwrap();
    let mut segs = Vec::new();
    prove_classify_run(&st, &blks, &bound, &mut ClassifySource(&mut p), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .unwrap();
    verify_classify_run(&st, &blks, &bound, &segs, POLICY_93).expect("the relation-test run verifies (test builds)");
    let e = capture(&st, &blks, &bound, &segs, CaptureOpts { arrays: false, public_tables: false }).err().expect("A CAPTURE OF NON-DERIVED TABLES WAS WRITTEN (N-r13-1)");
    assert!(e.contains("not derived from the pinned tied tensor"), "{e}");
    assert!(!run_capture::active());
    eprintln!("TOKEN-IO R14 | N-r13-1 | the replay refuses a run on the relation tests' synthetic tables: {e}");
}

/// **ROUND 14 (DESIGN v2.4 §15): a SHORT item is captured** (`L = 1`, 20
/// ids, one chunk of a 23-id plan, at the tie): the chunk `[0, 20)` of 20 in
/// run.json, the profile text naming the item length, the pad id, the three
/// pad positions and the verdict row 28; the same bundle checks.
#[test]
fn r14_a_short_item_is_captured() {
    let f = fx(1);
    let r = honest_run(&f, "tie", Some((20, 0)));
    assert_eq!((r.chunk.count, r.chunk.a, r.chunk.b, r.chunk.size, r.st.verdict()), (1, 0, 20, 23, 0));
    let b = capture(&r.st, &f.blocks, &r.bound, &r.segs, CaptureOpts { arrays: false, public_tables: false }).expect("a bundle for the short item");
    check_classify_bundle(&b, &r, 1);
    assert!(contains(&b.run_json, "n=20 S=1 item-length=29 pad-id=2 pad-positions=3 verdict-row=28"), "run.json's profile text does not name the short item's layout");
    eprintln!("CLASSIFY CAPTURE rung L=1 short item (20 ids, chunk [0, 20) of a 23-id plan) at the tie: run.json {} B", b.run_json.len());
}

/// **ROUND 14 (REVIEW_R13 N-r13-1, §10 item 1): the gate's capture fixture
/// proves with the R-C2 tables**, i.e. the embedding and margin row DERIVED
/// from the development rung's pinned tensor (`bba6d094…`) under the rung's
/// registered policy, exactly the tables the CLI's tied loader admits; not a
/// generic embedding and a random margin row (round 13's fixture).
#[test]
fn r14_the_gate_capture_fixture_proves_with_the_tables_derived_from_the_pinned_tensor() {
    let cc = super::classify_cli_tests::Cc::new("r14-fx");
    let x = super::super::trained_block::TrainedExport::load(&cc.export).unwrap();
    let tied = super::classify_tied::recompute_tied_classifier(super::classify_tied::TiedSource::DevRung, &cc.export, &cc.tables, &policy_rung_dev(), x.residual_unit, 384, &x.profile_sha256).unwrap();
    for l in [1, 2] {
        let f = fx(l);
        let t = fx_tables(&f);
        assert_eq!(t.w_delta, tied.w, "L = {l}: the capture fixture's margin row is not the one derived from the pinned tensor (N-r13-1)");
        assert_eq!(Some(&t.emb), tied.emb.as_ref(), "L = {l}: the capture fixture's embedding is not the one derived from the pinned tensor");
    }
    eprintln!("TOKEN-IO R14 | the gate's capture fixture (L = 1, 2) proves with the dev rung's derived tables (embedding c0e816c9…, margin 24e6ff4c…)");
}

// -------------------------------------------------- the gate's captures (environment-driven)

fn env_or(k: &str, default: &str) -> String {
    std::env::var(k).unwrap_or_else(|_| default.to_string())
}

/// `HL_PB_CAPTURE_DIR`: absolute and outside the repository
fn capture_dir() -> PathBuf {
    let raw = std::env::var("HL_PB_CAPTURE_DIR").expect("HL_PB_CAPTURE_DIR is not set: this test writes a bundle of evidence and will not choose a directory for you");
    let dir = PathBuf::from(&raw);
    assert!(dir.is_absolute(), "HL_PB_CAPTURE_DIR must be an absolute path, not {raw:?}");
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).ancestors().nth(4).expect("the repository root").to_path_buf();
    let repo = std::fs::canonicalize(&repo).unwrap_or(repo);
    let parent = dir.parent().map(|p| std::fs::canonicalize(p).unwrap_or_else(|_| p.to_path_buf())).unwrap_or_default();
    assert!(!parent.starts_with(&repo), "HL_PB_CAPTURE_DIR={raw} is inside the repository at {}; a capture bundle is written outside the tree", repo.display());
    dir
}

fn public_tables_from_env() -> bool {
    match std::env::var("HL_RUN_CAPTURE_PUBLIC_TABLES").as_deref() {
        Ok("1") => true,
        Ok("0") => false,
        _ => panic!("HL_RUN_CAPTURE_PUBLIC_TABLES is not set to 1 or 0: whether a bundle carries the public tables' VALUES changes what the gate can check and how large the bundle is; this test will not pick for you"),
    }
}

/// **CAPTURE A CLASSIFIER RUN AT THE RUNG** (T32, d384, the synthetic policy
/// with c placed per verdict; round 14: the R-C2 tables, derived from the
/// pinned dev tensor through the tied loader, each placed policy with its own
/// export profile). `#[ignore]`d: launched under the guard by whoever wants a
/// bundle.
///
/// | variable | what | default |
/// |---|---|---|
/// | `HL_PB_CAPTURE_DIR` | where the bundle goes | **required**, absolute, outside the repository |
/// | `HL_PB_CAPTURE_BLOCKS` | `L` (1 or 2) | 2 |
/// | `HL_PB_CLASSIFY_VERDICT` | `0`, `1` or `tie` (c placed as in `classify_tests`) | **required** |
/// | `HL_PB_CLASSIFY_CHUNK` | `whole`, or `<j>/<total>` (D41; e.g. `1/27` = `[4, 27)`; round 14: `0/20` = a short item of 20 ids) | `whole` |
/// | `HL_RUN_CAPTURE_PUBLIC_TABLES` | `1` the public tables' values, `0` length + digest | **required** |
/// | `HL_TEST_SOURCE_COMMIT` | the commit the bundle records | `uncommitted-test` |
#[test]
#[ignore = "writes a classifier rung capture; set HL_PB_CAPTURE_DIR (outside the repo), HL_PB_CLASSIFY_VERDICT and HL_RUN_CAPTURE_PUBLIC_TABLES"]
fn capture_a_classify_rung_run() {
    let t0 = std::time::Instant::now();
    let dir = capture_dir();
    let l: usize = env_or("HL_PB_CAPTURE_BLOCKS", "2").parse().expect("HL_PB_CAPTURE_BLOCKS is a number");
    assert!(l == 1 || l == 2, "HL_PB_CAPTURE_BLOCKS is 1 or 2 at the rung");
    let want = std::env::var("HL_PB_CLASSIFY_VERDICT").expect("HL_PB_CLASSIFY_VERDICT is not set: 0, 1 or tie");
    let chunk_s = env_or("HL_PB_CLASSIFY_CHUNK", "whole");
    let chunk = if chunk_s == "whole" {
        None
    } else {
        let (j, t) = chunk_s.split_once('/').expect("HL_PB_CLASSIFY_CHUNK is `whole` or `<j>/<total>`");
        Some((t.parse::<usize>().expect("a total"), j.parse::<usize>().expect("a chunk index")))
    };
    let public_tables = public_tables_from_env();
    let f = fx(l);
    let r = honest_run(&f, &want, chunk);
    let prove_s = t0.elapsed().as_secs_f64();
    let t1 = std::time::Instant::now();
    let bundle = capture(&r.st, &f.blocks, &r.bound, &r.segs, CaptureOpts { arrays: true, public_tables }).unwrap_or_else(|e| panic!("the capture: {e}"));
    let verify_s = t1.elapsed().as_secs_f64();
    check_classify_bundle(&bundle, &r, l);
    let c = r.chunk;
    let command = "HL_PB_CAPTURE_DIR=<dir> HL_PB_CAPTURE_BLOCKS=<1|2> HL_PB_CLASSIFY_VERDICT=<0|1|tie> HL_PB_CLASSIFY_CHUNK=<whole|j/total> HL_RUN_CAPTURE_PUBLIC_TABLES=<1|0> cargo test --release --lib private_block::token_io::classify_capture_tests::capture_a_classify_rung_run -- --ignored --nocapture";
    let note = format!(
        "Bundle: one honest CLASSIFIER run at the development rung (T = 32, d = 384, generic dense blocks) with R-C2's TABLES (token round 14): the embedding and the int16 margin row derived from the pinned development tensor (bba6d094…) through the tied loader, under the export profile its policy names. {l} block(s), profile `{RUN_PROFILE_CLASSIFY_RUNG_TC}`, tier `{}`. Policy `{}` (the rung's synthetic template, c = {} placed {} the item's margin; a test-registered policy with its own export profile, N-r13-3), verdict {} ({}). Chunk {} of {} (`[{}, {})` of a {}-id content; size {}, overlap {}; a chunk shorter than its size is a short item whose trailing positions hold the public pad id). Context: the rung's test context.\n\nPublic weights and tables (synthetic); the content, the margin, its limbs and every activation are prover-side and NOT here; neither is the owner's decommitment.",
        Tier::R1_MVP.name,
        r.policy.id,
        r.policy.c,
        match want.as_str() {
            "1" => "one below",
            "tie" => "at",
            _ => "one above",
        },
        r.st.verdict(),
        if r.st.verdict() == 1 { "flagged" } else { "not flagged" },
        c.index,
        c.count,
        c.a,
        c.b,
        c.total,
        c.size,
        c.overlap
    );
    run_capture::write_bundle(&dir, &bundle, &r.segs, &note, command).unwrap_or_else(|e| panic!("{e}"));
    // read back: every file in the manifest with its own length and digest
    let manifest = std::fs::read(dir.join("manifest.json")).expect("a manifest");
    assert!(contains(&manifest, &format!("\"schema\":\"{SCHEMA}\"")), "the manifest does not declare the classifier schema");
    for f in ["src/private_block/token_io/classify.rs", "src/private_block/token_io/stage_out_c.rs"] {
        assert!(contains(&manifest, &format!("{{\"file\":\"{f}\",")), "the manifest does not pin {f}");
    }
    let mut names = vec!["run.json".to_string(), "README.md".to_string(), run_capture::ARRAYS_FILE.to_string()];
    names.extend((0..l + 2).map(run_capture::stage_file));
    let mut total = 0usize;
    for name in &names {
        let bytes = std::fs::read(dir.join(name)).unwrap_or_else(|e| panic!("{name}: {e}"));
        assert!(contains(&manifest, &format!("{{\"file\":\"{name}\",\"bytes\":{},\"sha256\":\"{}\"}}", bytes.len(), crate::export_v3::sha256_hex(&bytes))), "{name} is not in the manifest with its own length and digest");
        if name.ends_with(".json") {
            for key in run_capture::keys_of(&bytes) {
                assert!(run_capture::ALLOWED_KEYS.contains(&key.as_str()), "{name} carries {key:?}, not on the allow-list");
            }
        }
        total += bytes.len();
    }
    eprintln!(
        "CLASSIFY CAPTURE rung L={l} verdict {want} ({}), chunk {}/{} [{}, {}), public tables {}: prove {prove_s:.1} s, verify+record {verify_s:.1} s, peak RSS {:.2} GiB; {total} B in {} ({:?} B stage files, arrays.bin {} B)",
        r.st.verdict(),
        c.index,
        c.count,
        c.a,
        c.b,
        if public_tables { "values" } else { "length + digest" },
        super::super::run::peak_rss_mib() / 1024.0,
        dir.display(),
        bundle.stages.iter().map(|s| s.len()).collect::<Vec<_>>(),
        bundle.arrays.blob().len()
    );
}

/// **THE CLI PATH (P-18)**: the NAMED `zk60_classify` binary's own `prove` and
/// `verify` run as its own processes on the rung's tiny export
/// (`classify_cli_tests`' fixture: the export with `seq_s0`, its verifier
/// copy without, the classifier tables, a 0600 content file); then, with NO
/// CLI hook, the run directory is read through the CLI's own door
/// (`classify_cli::door`: the B-3 re-render, the segment reads) and verified
/// with the recorder attached; this is that verification's bundle.
///
/// | variable | what | default |
/// |---|---|---|
/// | `HL_PB_CAPTURE_DIR` | where the bundle goes | **required**, absolute, outside the repository |
/// | `HL_PB_CLI_BIN` / `HL_PB_CLI_BIN_SHA256` | the named binary and its SHA-256 | **required** |
/// | `HL_RUN_CAPTURE_PUBLIC_TABLES` | `1` values, `0` length + digest | **required** |
/// | `HL_TEST_SOURCE_COMMIT` | the commit the bundle records | `uncommitted-test` |
#[test]
#[ignore = "writes the classifier CLI-path capture; set HL_PB_CAPTURE_DIR, HL_PB_CLI_BIN, HL_PB_CLI_BIN_SHA256 and HL_RUN_CAPTURE_PUBLIC_TABLES"]
fn capture_the_classify_cli_verify_path() {
    let dir = capture_dir();
    let public_tables = public_tables_from_env();
    let bin = PathBuf::from(std::env::var("HL_PB_CLI_BIN").expect("HL_PB_CLI_BIN is not set: the named zk60_classify binary"));
    let bin_sha = std::env::var("HL_PB_CLI_BIN_SHA256").expect("HL_PB_CLI_BIN_SHA256 is not set");
    assert!(bin.is_absolute() && bin.is_file(), "HL_PB_CLI_BIN must be an absolute path to the binary");
    assert!(bin_sha.len() == 64 && bin_sha.bytes().all(|c| c.is_ascii_hexdigit()), "HL_PB_CLI_BIN_SHA256 must be the binary's SHA-256");
    let cc = super::classify_cli_tests::Cc::new("p18");
    let run = cc.root.join("run-p18");
    let od = cc.owner_dir(&run);
    let cf = cc.content_file(&cc.content);
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let policy = policy_rung_dev().id;
    let t0 = std::time::Instant::now();
    let code = std::process::Command::new(&bin).arg("prove").args(s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", &policy, "--content-file", cf.to_str().unwrap(), "--seq", "s0", "--out", run.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()])).status().expect("the CLI binary runs").code();
    assert_eq!(code, Some(0), "the named binary's prove");
    let prove_s = t0.elapsed().as_secs_f64();
    let pub_flags = s(&["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", &policy, "--artifact", run.to_str().unwrap(), "--expect-statement", &cc.identity, "--min-bits", "93"]);
    let t1 = std::time::Instant::now();
    let code = std::process::Command::new(&bin).arg("verify").args(&pub_flags).status().expect("the CLI binary runs").code();
    assert_eq!(code, Some(0), "the named binary's verify (it publishes <run>/statement/)");
    let cli_verify_s = t1.elapsed().as_secs_f64();
    // P-18: NO CLI hook — the CLI's own door, then the verifier with the recorder attached
    let t2 = std::time::Instant::now();
    let pairs: Vec<(String, String)> = pub_flags.chunks(2).map(|kv| (kv[0].clone(), kv[1].clone())).collect();
    let d = super::classify_cli::door(&pairs, &run).expect("the CLI's door on the published run directory");
    assert!(d.published, "the door read the verifier's published statement");
    let mut blocks = super::load::ExportTokenBlocks::new(&d.p);
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(d.st.capture_header().unwrap(), d.st.binding().unwrap(), CaptureOpts { arrays: true, public_tables });
    let bundle = match verify_classify_run_with(&d.st, &mut blocks, &d.tables, &d.segs, POLICY_93) {
        Ok(()) => run_capture::take().expect("a bundle for the accepted verification"),
        Err(e) => {
            run_capture::discard();
            panic!("the recorded verification of the CLI's run directory refused: {e}");
        }
    };
    drop(guard);
    drop(blocks);
    let verify_s = t2.elapsed().as_secs_f64();
    let dec = Decommitment::from_bytes(&std::fs::read(od.join("input.dec")).unwrap()).unwrap();
    let l = d.st.l();
    check_classify_bundle_parts(&bundle, &d.st, &d.segs, &dec, l);
    let note = format!(
        "Bundle: a capture through the CLASSIFIER CLI PATH (the native P-18 pattern): the named binary {} (sha256 {bin_sha}) ran `zk60_classify prove` and `zk60_classify verify` as its own processes (verify from a verifier copy without seq_*, pinned by --expect-statement; it published the statement); then, with no CLI hook, the run directory was read through the CLI's own door (classify_cli::door: the B-3 re-render and the segment reads) and verified with the round-7 recorder attached, and this is that verification's bundle. The rung's tiny export (one layer, seq_s0), the synthetic policy `{policy}` (c = 0), verdict {} ({}). The content, every activation and the owner's decommitment are prover-side and NOT here.",
        bin.display(),
        d.st.verdict(),
        if d.st.verdict() == 1 { "flagged" } else { "not flagged" }
    );
    run_capture::write_bundle(&dir, &bundle, &d.segs, &note, "HL_PB_CAPTURE_DIR=<dir> HL_PB_CLI_BIN=<zk60_classify binary> HL_PB_CLI_BIN_SHA256=<its sha256> HL_RUN_CAPTURE_PUBLIC_TABLES=<1|0> cargo test --release --lib private_block::token_io::classify_capture_tests::capture_the_classify_cli_verify_path -- --ignored --nocapture").unwrap();
    eprintln!(
        "CLASSIFY CAPTURE THROUGH THE CLI (the named binary, sha256 {}): rung L={l}, verdict {}, CLI prove {prove_s:.1} s, CLI verify {cli_verify_s:.1} s, recorded verify {verify_s:.1} s; bundle {} B run.json + {:?} B stage files + {} B arrays.bin in {}",
        &bin_sha[..12],
        d.st.verdict(),
        bundle.run_json.len(),
        bundle.stages.iter().map(|s| s.len()).collect::<Vec<_>>(),
        bundle.arrays.blob().len(),
        dir.display()
    );
}

// ---------------------------------------------------------------------------
// [PRIVACY GATE ROUND 18, TEST-ONLY PATCH H18-1, the gate lane's copy
// `ops/zkp-mvp/gate-tinyllama/capture-tree-r14` only; NOT in token frozen-r14]
// REVIEW_R14 §10 item 4: the P-18 CLI path for ONE SHORT item. This file is
// not a source pin of any capture; the named binary, the recorder
// (`run_capture.rs`) and every pinned file are frozen-r14's bytes.

/// **THE CLI PATH (P-18) FOR A SHORT ITEM**: as
/// [`capture_the_classify_cli_verify_path`], with the content `9 .. 9 + n`
/// (`HL_PB_CLI_SHORT_N`, default 22; `1 <= n < 23`), proved by the named
/// binary from a seq dir of the padded item (prefix, content, suffix, the
/// policy's public pad id up to T), as the r14 binary test does.
#[test]
#[ignore = "gate round 18 (H18-1): writes the classifier CLI-path capture of a SHORT item; set HL_PB_CAPTURE_DIR, HL_PB_CLI_BIN, HL_PB_CLI_BIN_SHA256, HL_RUN_CAPTURE_PUBLIC_TABLES and HL_PB_CLI_SHORT_N"]
fn gate18_capture_a_short_item_through_the_cli() {
    let dir = capture_dir();
    let public_tables = public_tables_from_env();
    let bin = PathBuf::from(std::env::var("HL_PB_CLI_BIN").expect("HL_PB_CLI_BIN is not set: the named zk60_classify binary"));
    let bin_sha = std::env::var("HL_PB_CLI_BIN_SHA256").expect("HL_PB_CLI_BIN_SHA256 is not set");
    assert!(bin.is_absolute() && bin.is_file(), "HL_PB_CLI_BIN must be an absolute path to the binary");
    assert!(bin_sha.len() == 64 && bin_sha.bytes().all(|c| c.is_ascii_hexdigit()), "HL_PB_CLI_BIN_SHA256 must be the binary's SHA-256");
    let n: usize = env_or("HL_PB_CLI_SHORT_N", "22").parse().expect("HL_PB_CLI_SHORT_N is a number");
    assert!((1..23).contains(&n), "HL_PB_CLI_SHORT_N is a short item's length, 1 ..= 22 at the rung");
    let cc = super::classify_cli_tests::Cc::new("g18");
    let pol = policy_rung_dev();
    let short: Vec<u64> = (9..9 + n as u64).collect();
    let mut toks: Vec<u64> = pol.prefix.iter().chain(short.iter()).chain(pol.suffix.iter()).copied().collect();
    while toks.len() < 32 {
        toks.push(pol.pad);
    }
    let sd = cc.owners.join("seq-g18");
    cc.write_seq_dir(&sd, &toks);
    let run = cc.root.join("run-g18");
    let od = cc.owner_dir(&run);
    let text = short.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",");
    let cf = cc.content_file(&text);
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let policy = pol.id.clone();
    let t0 = std::time::Instant::now();
    let code = std::process::Command::new(&bin).arg("prove").args(s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", &policy, "--content-file", cf.to_str().unwrap(), "--seq-dir", sd.to_str().unwrap(), "--out", run.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()])).status().expect("the CLI binary runs").code();
    assert_eq!(code, Some(0), "the named binary's prove of the short item");
    let prove_s = t0.elapsed().as_secs_f64();
    let pub_flags = s(&["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", &policy, "--artifact", run.to_str().unwrap(), "--expect-statement", &cc.identity, "--min-bits", "93"]);
    let t1 = std::time::Instant::now();
    let code = std::process::Command::new(&bin).arg("verify").args(&pub_flags).status().expect("the CLI binary runs").code();
    assert_eq!(code, Some(0), "the named binary's verify (it publishes <run>/statement/)");
    let cli_verify_s = t1.elapsed().as_secs_f64();
    let stmt = std::fs::read_to_string(run.join(super::super::run_sink::STATEMENT_DIR).join("statement.json")).unwrap();
    assert!(stmt.contains(&format!("\"content_length_n\": {n},")) && stmt.contains(&format!("\"range\": [0, {n}]")), "{stmt}");
    // the published /3 statement (public), for the gate's allow-list check, where the caller asks
    if let Ok(out) = std::env::var("HL_GATE18_STATEMENT_OUT") {
        std::fs::write(out, &stmt).expect("the statement copy");
    }
    let t2 = std::time::Instant::now();
    let pairs: Vec<(String, String)> = pub_flags.chunks(2).map(|kv| (kv[0].clone(), kv[1].clone())).collect();
    let d = super::classify_cli::door(&pairs, &run).expect("the CLI's door on the published run directory");
    assert!(d.published, "the door read the verifier's published statement");
    let mut blocks = super::load::ExportTokenBlocks::new(&d.p);
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(d.st.capture_header().unwrap(), d.st.binding().unwrap(), CaptureOpts { arrays: true, public_tables });
    let bundle = match verify_classify_run_with(&d.st, &mut blocks, &d.tables, &d.segs, POLICY_93) {
        Ok(()) => run_capture::take().expect("a bundle for the accepted verification"),
        Err(e) => {
            run_capture::discard();
            panic!("the recorded verification of the CLI's run directory refused: {e}");
        }
    };
    drop(guard);
    drop(blocks);
    let verify_s = t2.elapsed().as_secs_f64();
    let dec = Decommitment::from_bytes(&std::fs::read(od.join("input.dec")).unwrap()).unwrap();
    let l = d.st.l();
    check_classify_bundle_parts(&bundle, &d.st, &d.segs, &dec, l);
    let note = format!(
        "Bundle: [privacy gate round 18, test-only patch H18-1 in the gate's copy] a capture through the CLASSIFIER CLI PATH (the native P-18 pattern) of a SHORT item: the named binary {} (sha256 {bin_sha}) ran `zk60_classify prove` (from a seq dir of the padded item) and `zk60_classify verify` as its own processes (verify from a verifier copy without seq_*, pinned by --expect-statement; it published the statement); then, with no CLI hook, the run directory was read through the CLI's own door and verified with the round-7 recorder attached, and this is that verification's bundle. The rung's tiny export, the synthetic policy `{policy}` (c = 0), a {n}-id item (one chunk [0, {n}) of a 23-id plan; {} pad positions), verdict {} ({}). The content, every activation and the owner's decommitment are prover-side and NOT here.",
        bin.display(),
        32 - 8 - n - 1,
        d.st.verdict(),
        if d.st.verdict() == 1 { "flagged" } else { "not flagged" }
    );
    run_capture::write_bundle(&dir, &bundle, &d.segs, &note, "HL_PB_CAPTURE_DIR=<dir> HL_PB_CLI_BIN=<zk60_classify binary> HL_PB_CLI_BIN_SHA256=<its sha256> HL_RUN_CAPTURE_PUBLIC_TABLES=<1|0> HL_PB_CLI_SHORT_N=<n> cargo test --release --lib private_block::token_io::classify_capture_tests::gate18_capture_a_short_item_through_the_cli -- --ignored --nocapture (gate patch H18-1)").unwrap();
    eprintln!(
        "GATE18 CLASSIFY CAPTURE THROUGH THE CLI, SHORT ITEM n={n} (the named binary, sha256 {}): rung L={l}, verdict {}, CLI prove {prove_s:.1} s, CLI verify {cli_verify_s:.1} s, recorded verify {verify_s:.1} s; segments {:?} B; bundle in {}",
        &bin_sha[..12],
        d.st.verdict(),
        d.segs.iter().map(|s| s.len()).collect::<Vec<_>>(),
        dir.display()
    );
}

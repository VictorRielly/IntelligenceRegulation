//! **GATE ROUND 19 (privacy gate lane), TEST-ONLY PATCH H19** in the gate's
//! copy `ops/zkp-mvp/gate-tinyllama/capture-tree-r16b` (= token frozen-r16b,
//! 301 files, list sha256 04d94bc0...). Registered by one `#[path]` line at the
//! end of `classify_capture_tests.rs`, which is not a capture source pin. No
//! production file changes; every hook is `#[ignore]`d and only writes a bundle
//! (the verifier's view) outside the repository.
//!
//! REVIEW_R16 §10 item 1 asks for R13-stack classifier captures. Token
//! frozen-r16b's capture hooks bind the LEGACY rung only
//! (`RUN_PROFILE_CLASSIFY_RUNG_TC`), and its two-stage R13 rung test uses the
//! relation tests' synthetic tables, which the gate's replay refuses (B-3). So:
//!
//! * **H19-1** [`gate19_capture_an_r13_rung_classify_run`]: a classifier run at
//!   the test-only R13 h24 development rung
//!   (`RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST`, Sol's public loader fixture
//!   `r13-h24-dense`, cn 4000; attempt 1 used `r13-h24-wide`, cn 10000, which the
//!   derived embedding overflows), with R-C2's DERIVED tables (the dev tensor through the
//!   tied loader, under a per-policy copy of the export carrying the
//!   classifier parameters: one parameter set per export, N-r13-3), at L = 1
//!   or L = 2 (layer 1 = layer 0 with another SiLU member, so the two stages
//!   carry DIFFERENT gate denominators, as round 16's two-stage test), verdict
//!   0 / 1 / tie (c placed from the item's own margin), the whole content, a
//!   D41 chunk or a short item.
//! * **H19-2** [`gate19_capture_a_real_classify_cli_run`]: the P-18 pattern on a
//!   run directory the NAMED binary proved and verified as its own processes
//!   (the real Shieldstral T128 export): the CLI's own door (B-3 re-render,
//!   segment reads) and the verification with the recorder attached.
//!
//! **TOKEN I/O ROUND 17: ADOPTED** into the token tree (`ops/zkp-mvp/token-io-r17`)
//! from the gate's patch `round19/cap/H19-1-2.gate19_capture_tests.patch`, with
//! ONE addition to each hook: a capture with public-table values
//! (`HL_RUN_CAPTURE_PUBLIC_TABLES=1`) at an R13 shape records the values of its
//! STATEMENT tables (the weight folds, gains, RoPE pairs, group column, exp /
//! ACT3 tables and ACT support the gate takes), and the recorder writes no
//! such bundle until `run_capture::export_replay` has derived each of them
//! again from the export's layer data and found it byte-equal. H19-1 replays
//! against the rung fixture's own blocks (layer 1 is a synthetic variant of
//! layer 0, not in the fixture); H19-2 against a SECOND load of the real
//! export's layers (`ExportTokenBlocks`, independent of the verifier's). The
//! round's tests are the child module `r17` (`classify_r17_tests.rs`).

use super::*;
use crate::private_block::accuracy_public::AccuracyPublic;
use crate::private_block::run::RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST;
use crate::private_block::shape::R13_RUNG_H24;
use crate::private_block::trained_statement::{IntegerCalibration, Provenance};

type BlockShape = crate::private_block::shape::Shape;

fn r13_fixtures() -> PathBuf {
    std::env::var_os("HL_R13_LOADER_FIXTURES").map(PathBuf::from).unwrap_or_else(|| Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures"))
}

fn copy_tree(src: &Path, dst: &Path) {
    std::fs::create_dir_all(dst).unwrap();
    for e in std::fs::read_dir(src).unwrap_or_else(|e| panic!("{}: {e}", src.display())) {
        let e = e.unwrap();
        let ft = e.file_type().unwrap();
        let t = dst.join(e.file_name());
        if ft.is_dir() {
            copy_tree(&e.path(), &t);
        } else if ft.is_file() {
            std::fs::copy(e.path(), &t).unwrap();
        }
    }
}

/// one policy's R13-rung binding: its own copy of the loader fixture with the
/// classifier parameters, the blocks (L = 1, or 2 with two gate
/// denominators), the trained statement under the R13 rung's test classifier
/// profile, and the tables DERIVED from the pinned dev tensor through the tied
/// loader (R-C2)
struct R13Bound {
    seed: BlockShape,
    blocks: Vec<BlockPublic>,
    model: TrainedModelStatement,
    bound: BoundClassifierTables,
}

fn r13_bind(dir: &Path, policy: &Policy, l: usize) -> R13Bound {
    let tag: String = policy.id.chars().map(|c| if c.is_ascii_alphanumeric() { c } else { '_' }).collect();
    let export = dir.join(format!("x13-{tag}"));
    let _ = std::fs::remove_dir_all(&export);
    // attempt 2 (11:23Z): r13-h24-wide declares norm_cn_a = norm_cn_m = 10000, under which the R13 norm
    // quotient of 102 of the dev tensor's 300 derived rows leaves int16 (the honest pipeline refuses:
    // "norm quotient/remainder"); Sol's r13-h24-dense (the same rung-hd geometry, dense weights, four
    // SiLU groups) declares 4000, under which none does. `HL_PB_R13_FIXTURE` names another one.
    let fixture = std::env::var("HL_PB_R13_FIXTURE").unwrap_or_else(|_| "r13-h24-dense".to_string());
    let src = r13_fixtures().join(&fixture);
    assert!(src.join("profile.json").exists(), "the R13 loader fixture {} is missing: set HL_R13_LOADER_FIXTURES", src.display());
    copy_tree(&src, &export);
    // the fixture's residual unit is 1.0, under which the dev tensor's values (|x| < 32) quantize to
    // an embedding with about half its words zero; the copy declares the legacy dev rung's unit
    // (trained_block_tests.rs, 0.0053663705198366135; the gate reads the same constant). The norm is
    // scale-free, and the blocks' constants do not read it.
    let pj = export.join("profile.json");
    let text = std::fs::read_to_string(&pj).unwrap();
    assert_eq!(text.matches("\"residual_unit\": 1.0,").count(), 1, "the fixture's residual unit line");
    std::fs::write(&pj, text.replace("\"residual_unit\": 1.0,", "\"residual_unit\": 0.0053663705198366135,")).unwrap();
    add_classifier_parameters(&export, 1, norm(), policy);
    let mut ex = TrainedExport::load(&export).unwrap_or_else(|e| panic!("the R13 loader fixture with the classifier parameters: {e}"));
    ex.source.checkpoint_layers = l as u32;
    let c = ex.run_constants(&[0]).unwrap();
    let seed = ex.shape_for(&c).unwrap();
    assert_eq!(seed.profile, R13_RUNG_H24);
    let first = ex.load_layer(&seed, &c, 0, false).unwrap();
    let mut blocks = vec![first.blk.clone()];
    let mut records = vec![first.record.clone()];
    if l == 2 {
        // round 16's two-stage construction: layer 1 = layer 0 with another
        // SiLU member, so its bound gate denominator differs
        let a = first.blk.accuracy().unwrap();
        let changed = AccuracyPublic::new(a.stack(), a.geometry(), a.base(), (-4, -13), a.multipliers().clone(), a.groups().to_vec(), a.group_ids().to_vec(), a.raw_tables().to_vec()).unwrap();
        let second = first.blk.clone().with_accuracy(changed);
        let mut r2 = LayerRecord::of_block(1, &second, vec![]);
        r2.manifest_sha256 = [53; 32];
        assert_ne!(records[0].accuracy_gate_shift, r2.accuracy_gate_shift, "the two layers must carry different gate denominators");
        blocks.push(second);
        records.push(r2);
    }
    let prov = Provenance {
        label: format!("export:{}", ex.variant),
        residual_unit: ex.residual_unit,
        quantizer_sha256: ex.tool_sha256,
        calibration_set_sha256: ex.calibration_set_sha256,
        export_profile_sha256: ex.profile_sha256,
        calibration_tool_sha256: ex.tool_sha256,
        rope_theta: c.rope_theta,
        rope_scaling: ex.rope_scaling,
    };
    let model = TrainedModelStatement::new_with_tied(&seed, RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST, ex.source.clone(), IntegerCalibration::as_the_code_proves(&seed, &prov), records, None).expect("the R13 rung's trained statement under the test classifier profile");
    let tables = dir.join(format!("t13-{tag}"));
    let _ = std::fs::remove_dir_all(&tables);
    std::fs::create_dir_all(&tables).unwrap();
    std::fs::write(tables.join(DEV_TIED_TENSOR_FILE), dev_tied_tensor_bytes()).unwrap();
    let tied = recompute_tied_classifier(TiedSource::DevRung, &export, &tables, policy, ex.residual_unit, seed.width, &ex.profile_sha256).expect("the dev derivation at the R13 rung");
    let g = generic_tables(seed.width, 0x636c_6363);
    let t = TokenTables::new(g.v, g.d, tied.emb.clone().expect("the dev embedding"), g.head, g.mult).unwrap();
    write_classifier_tables(&tables, &t, &tied.w, tied.bos, tied.norm, policy);
    let bound = load_bound_tables(&seed, &model, &export, &tables, policy).expect("the derived tables load through the tied loader at the R13 rung");
    R13Bound { seed, blocks, model, bound }
}

struct R13Run {
    st: ClassifyRunStatement,
    segs: Vec<Vec<u8>>,
    dec: Decommitment,
    margin: i64,
    policy: Policy,
    chunk: ChunkRef,
    blocks: Vec<BlockPublic>,
    bound: BoundClassifierTables,
    gates: Vec<Option<u32>>,
}

/// **An honest R13-rung run at a wanted verdict**, as `honest_run` at the
/// legacy rung: the margin first under the dev policy, then c placed
/// (`margin - 1` verdict 1, `margin` the tie, `margin + 1` verdict 0) under a
/// test-registered policy with its own export profile
fn r13_honest_run(dir: &Path, l: usize, want: &str, chunk: Option<(usize, usize)>) -> R13Run {
    let base = policy_rung_dev();
    let fx0 = r13_bind(dir, &base, l);
    let sh = fx0.seed.clone();
    let size = sh.tokens - base.prefix.len() - base.suffix.len();
    let (total, index) = chunk.unwrap_or((size, 0));
    let mut whole = content(&base, total.min(size), 0x6361_7031);
    if total > size {
        whole.extend(content(&base, total - size, 0x6361_7032));
    }
    assert_eq!(whole.len(), total);
    let ch = ChunkRef::derive(total, index, ChunkPlan { size, overlap: chunk_overlap_of(RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST).unwrap() }).expect("the chunk");
    let n = ch.b - ch.a;
    let shapes: Vec<BlockShape> = fx0.model.layers.iter().map(|r| r.shape_at(&sh).unwrap()).collect();
    let cp0 = ClassifierProfile::new(&sh, fx0.bound.tables(), fx0.bound.bos(), fx0.bound.norm(), &base, n, Tier::R1_MVP).unwrap();
    let tokens = cp0.tokens_of(&whole[ch.a..ch.b]).unwrap();
    let margin = honest_classify(&shapes, &cp0, fx0.bound.tables(), &fx0.blocks, &tokens).expect("the honest R13 pipeline").out_values.margin;
    let c = match want {
        "1" => margin - 1,
        "tie" => margin,
        "0" => margin + 1,
        other => panic!("HL_PB_CLASSIFY_VERDICT={other:?} is 0, 1 or tie"),
    };
    let mut policy = base.clone();
    policy.id = format!("r13-rung-capture-test-policy/{c}");
    policy.c = c;
    register_test_policy(policy.clone());
    let fx = r13_bind(dir, &policy, l);
    let cp = ClassifierProfile::new(&sh, fx.bound.tables(), fx.bound.bos(), fx.bound.norm(), &policy, n, Tier::R1_MVP).unwrap();
    let mut p = honest_classify(&shapes, &cp, fx.bound.tables(), &fx.blocks, &tokens).expect("the honest R13 pipeline under the placed c");
    let verdict = p.out_values.verdict;
    assert_eq!(verdict, u8::from(want == "1"), "the placed c gives the wanted verdict");
    let spec = input_endpoint_spec(&sh, ctx(), &cp).unwrap();
    let (root, owner) = seal_input(&spec, &p.in_plane, &sh.hash_tag()).unwrap();
    let digests: Vec<Digest> = fx.model.layers.iter().map(|r| r.block_digest).collect();
    let st = ClassifyRunStatement::new_chunk(RunShape::new(sh.clone(), l, RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST).unwrap(), ctx(), digests, &fx.model, &fx.bound, &policy, n, Tier::R1_MVP, root, verdict, total, index).expect("the statement");
    let gates: Vec<Option<u32>> = (0..l).map(|k| st.stage_gate(k)).collect();
    let mut segs = Vec::new();
    let (_, dec) = prove_classify_run(&st, &fx.blocks, &fx.bound, &mut ClassifySource(&mut p), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the honest R13 classifier run proves");
    assert!(st.tables_derived(), "the capture fixture's tables are derived");
    R13Run { st, segs, dec, margin, policy, chunk: ch, blocks: fx.blocks, bound: fx.bound, gates }
}

/// the checks every gate-19 bundle must pass (the parent's
/// `check_classify_bundle_parts`, with the run profile and the block slot
/// count taken from the statement instead of the legacy rung's constants)
fn check_bundle_19(b: &Bundle, st: &ClassifyRunStatement, segs: &[Vec<u8>], dec: &Decommitment, l: usize, n_block_slots: usize) {
    let binding = st.binding().unwrap();
    let policy = &st.cp.policy;
    assert_eq!(b.stages.len(), l + 2, "a classifier bundle has L + 2 stage files");
    assert!(contains(&b.run_json, &format!("\"schema\":\"{SCHEMA}\"")), "run.json does not declare the classifier schema");
    assert!(contains(&b.run_json, &format!("\"blocks\":{l},\"stages\":{}", l + 2)), "run.json does not declare L and L + 2");
    assert!(contains(&b.run_json, &format!("\"run_binding\":{binding:?}")), "run.json does not carry the run binding");
    assert!(contains(&b.run_json, &format!("\"classify\":{{\"run_profile\":\"{}\"", st.profile())), "run.json carries no classifier facts for this run profile");
    assert!(contains(&b.run_json, &format!("\"verdict\":{},", st.verdict())), "run.json does not carry the public verdict");
    let c = st.chunk();
    assert!(contains(&b.run_json, &format!("\"chunk\":{{\"index\":{},\"count\":{},\"a\":{},\"b\":{},\"total\":{},\"size\":{},\"overlap\":{}}}", c.index, c.count, c.a, c.b, c.total, c.size, c.overlap)), "run.json does not carry the chunk");
    assert!(contains(&b.run_json, &format!("\"id\":{:?}", policy.id)) && contains(&b.run_json, &format!("\"c\":{},", policy.c)), "run.json does not carry the policy and its c");
    assert!(contains(&b.run_json, "\"output_endpoint\":null"), "a classifier run has no output endpoint");
    assert_eq!(count(&b.run_json, "\"plane_index\":"), 1, "the block plane index belongs in run.json exactly once");
    let (slots, n_slots) = shape_slot_list(&b.run_json);
    assert_eq!(slots.len(), n_slots, "F18-1: the run file lists exactly n_slots slot triples");
    assert_eq!(n_slots, n_block_slots, "run.json's n_slots is not the block shape's");
    for (k, s) in b.stages.iter().enumerate() {
        let (kind, n) = if k == 0 {
            ("IN-C", 4)
        } else if k == l + 1 {
            ("OUT-C", 8)
        } else {
            ("BLOCK", n_block_slots)
        };
        assert!(contains(s, &format!("\"stage\":{k},\"stage_kind\":\"{kind}\"")), "stage {k} is not {kind}");
        assert_eq!(count(s, "\"definition_challenges\":"), n, "stage {k} ({kind}) does not carry {n} slot transcripts");
        assert!(contains(s, &format!("\"segment_bytes\":{}", segs[k].len())), "stage {k} does not carry its segment's length");
        assert!(contains(s, &format!("\"segment_sha256\":\"{}\"", crate::export_v3::sha256_hex(&segs[k]))), "stage {k} is not pinned to the bytes that were verified");
        assert!(!contains(s, "E-token-out"), "stage {k} names an output endpoint");
    }
    // NO OWNER DECOMMITMENT: at most Q of the owner's salts and none of its pad words
    let (mut salts, mut numbers) = (std::collections::HashSet::new(), std::collections::HashSet::new());
    for f in std::iter::once(&b.run_json).chain(b.stages.iter()) {
        index_json(f, &mut salts, &mut numbers);
    }
    let words: std::collections::HashSet<u64> = b.arrays.blob().chunks_exact(8).map(|c| u64::from_le_bytes(c.try_into().expect("8 bytes"))).collect();
    let found = dec.salts.iter().filter(|salt| salts.contains(format!("{salt:?}").as_bytes())).count();
    assert!(found <= Tier::R1_MVP.opened_cols && found < dec.salts.len(), "the owner's decommitment: {found} of its {} salts are in the bundle", dec.salts.len());
    for pad in dec.pads.iter().filter(|p| p.0 >= 1_000_000_000_000) {
        assert!(!numbers.contains(&pad.0), "an owner's pad word is in the bundle's JSON");
        assert!(!words.contains(&pad.0), "an owner's pad word is in arrays.bin");
    }
    assert!(keys_allowed(b) > 1000, "too few keys were scanned");
}

fn sizes_line(b: &Bundle) -> String {
    format!("run.json {} B, stages {:?} B, arrays.bin {} B", b.run_json.len(), b.stages.iter().map(|s| s.len()).collect::<Vec<_>>(), b.arrays.blob().len())
}

/// **H19-1: CAPTURE A CLASSIFIER RUN AT THE R13 h24 RUNG** (T32, width 384,
/// Sol's public loader fixture, R-C2 derived tables). `#[ignore]`d.
///
/// | variable | what | default |
/// |---|---|---|
/// | `HL_PB_CAPTURE_DIR` | where the bundle goes | **required**, absolute, outside the repository |
/// | `HL_PB_CAPTURE_BLOCKS` | `L` (1, or 2 = two gate denominators) | 2 |
/// | `HL_PB_CLASSIFY_VERDICT` | `0`, `1` or `tie` | **required** |
/// | `HL_PB_CLASSIFY_CHUNK` | `whole`, or `<j>/<total>` (a total below 23 = a short item) | `whole` |
/// | `HL_RUN_CAPTURE_PUBLIC_TABLES` | `1` values, `0` length + digest | **required** |
/// | `HL_R13_LOADER_FIXTURES` | Sol's R13 loader fixtures | `../../loader-fixtures` |
/// | `HL_TEST_SOURCE_COMMIT` | the commit the bundle records | `uncommitted-test` |
#[test]
#[ignore = "gate round 19 (H19-1): writes an R13-rung classifier capture; set HL_PB_CAPTURE_DIR, HL_PB_CLASSIFY_VERDICT, HL_RUN_CAPTURE_PUBLIC_TABLES and HL_R13_LOADER_FIXTURES"]
fn gate19_capture_an_r13_rung_classify_run() {
    let t0 = std::time::Instant::now();
    let dir = capture_dir();
    let l: usize = env_or("HL_PB_CAPTURE_BLOCKS", "2").parse().expect("HL_PB_CAPTURE_BLOCKS is a number");
    assert!(l == 1 || l == 2, "HL_PB_CAPTURE_BLOCKS is 1 or 2 at the R13 rung");
    let want = std::env::var("HL_PB_CLASSIFY_VERDICT").expect("HL_PB_CLASSIFY_VERDICT is not set: 0, 1 or tie");
    let chunk_s = env_or("HL_PB_CLASSIFY_CHUNK", "whole");
    let chunk = if chunk_s == "whole" {
        None
    } else {
        let (j, t) = chunk_s.split_once('/').expect("HL_PB_CLASSIFY_CHUNK is `whole` or `<j>/<total>`");
        Some((t.parse::<usize>().expect("a total"), j.parse::<usize>().expect("a chunk index")))
    };
    let public_tables = public_tables_from_env();
    let fxdir = FxDir(fixture_root().join(format!("gate19-r13-fx-{}-{}", std::process::id(), FX_SEQ.fetch_add(1, std::sync::atomic::Ordering::SeqCst))));
    let _ = std::fs::remove_dir_all(&fxdir.0);
    std::fs::create_dir_all(&fxdir.0).unwrap();
    let r = r13_honest_run(&fxdir.0, l, &want, chunk);
    let prove_s = t0.elapsed().as_secs_f64();
    let t1 = std::time::Instant::now();
    let mut bundle = capture(&r.st, &r.blocks, &r.bound, &r.segs, CaptureOpts { arrays: true, public_tables }).unwrap_or_else(|e| panic!("the capture: {e}"));
    // TOKEN ROUND 17: the statement tables' values, replayed against the fixture's layers
    let replay = if bundle.statement.is_empty() {
        None
    } else {
        let blocks = r.blocks.clone();
        Some(run_capture::export_replay(&mut bundle, &mut |k| blocks.get(k).cloned().ok_or_else(|| format!("the fixture has no layer {k}"))).unwrap_or_else(|e| panic!("the export replay: {e}")))
    };
    let verify_s = t1.elapsed().as_secs_f64();
    let n_slots = r.st.stage_shape(0).unwrap().n_slots();
    check_bundle_19(&bundle, &r.st, &r.segs, &r.dec, l, n_slots);
    let c = r.chunk;
    let command = "HL_PB_CAPTURE_DIR=<dir> HL_PB_CAPTURE_BLOCKS=<1|2> HL_PB_CLASSIFY_VERDICT=<0|1|tie> HL_PB_CLASSIFY_CHUNK=<whole|j/total> HL_RUN_CAPTURE_PUBLIC_TABLES=<1|0> HL_R13_LOADER_FIXTURES=<dir> cargo test --release --lib private_block::token_io::classify_capture_tests::gate19::gate19_capture_an_r13_rung_classify_run -- --ignored --exact --nocapture";
    let note = format!(
        "Bundle (privacy gate round 19, test-only patch H19-1 in the gate's copy of token frozen-r16b): one honest CLASSIFIER run at the R13 h24 DEVELOPMENT RUNG (`{}`, T = {}, width {}; Sol's public synthetic loader fixture {} (dense weights, four SiLU groups) in a copy declaring the residual unit 0.0053663705198366135, accuracy stack LOW + h24) with R-C2's DERIVED tables (the embedding and the int16 margin row derived from the pinned development tensor bba6d094... through the tied loader, under a per-policy copy of the export carrying the classifier parameters). {l} block(s) under the run profile `{RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST}` (test builds only), the stages' R13 gate denominators {:?}{}. Policy `{}` (the dev template, c = {} placed {} the item's margin {}), verdict {} ({}). Chunk {} of {} (`[{}, {})` of a {}-id content; size {}, overlap {}; a chunk shorter than its size is a short item whose trailing positions hold the public pad id {}). The content, the margin, its limbs, every activation and the owner's decommitment are prover-side and NOT here.",
        r.st.stage_shape(0).unwrap().profile,
        r.st.stage_shape(0).unwrap().tokens,
        r.st.stage_shape(0).unwrap().width,
        std::env::var("HL_PB_R13_FIXTURE").unwrap_or_else(|_| "r13-h24-dense".to_string()),
        r.gates,
        if l == 2 { " (layer 1 = layer 0 with the SiLU member (-4, -13): another gate denominator)" } else { "" },
        r.policy.id,
        r.policy.c,
        match want.as_str() {
            "1" => "one below",
            "tie" => "at",
            _ => "one above",
        },
        r.margin,
        r.st.verdict(),
        if r.st.verdict() == 1 { "flagged" } else { "not flagged" },
        c.index,
        c.count,
        c.a,
        c.b,
        c.total,
        c.size,
        c.overlap,
        r.policy.pad
    );
    run_capture::write_bundle(&dir, &bundle, &r.segs, &note, command).unwrap_or_else(|e| panic!("{e}"));
    let manifest = std::fs::read(dir.join("manifest.json")).expect("a manifest");
    assert!(contains(&manifest, &format!("\"schema\":\"{SCHEMA}\"")), "the manifest does not declare the classifier schema");
    for f in ["src/private_block/token_io/classify.rs", "src/private_block/argument_accuracy.rs"] {
        assert!(contains(&manifest, &format!("{{\"file\":\"{f}\",")), "the manifest does not pin {f}");
    }
    eprintln!(
        "GATE19 CAPTURE R13 rung L={l} gates {:?} verdict {want} ({}) margin {} c {}, chunk {}/{} [{}, {}) of {}, public tables {}{}: prove {prove_s:.1} s, verify+record {verify_s:.1} s, peak RSS {:.2} GiB; segments {:?} B; {} in {}",
        r.gates,
        r.st.verdict(),
        r.margin,
        r.policy.c,
        c.index,
        c.count,
        c.a,
        c.b,
        c.total,
        if public_tables { "values" } else { "length + digest" },
        replay.as_ref().map(|x| format!(" (export replay: {} statement tables, {} entries, {} blocks)", x.tables, x.entries, x.blocks)).unwrap_or_default(),
        crate::private_block::run::peak_rss_mib() / 1024.0,
        r.segs.iter().map(|s| s.len()).collect::<Vec<_>>(),
        sizes_line(&bundle),
        dir.display()
    );
}

/// **H19-2: THE P-18 CLI PATH ON A REAL RUN DIRECTORY.** The named
/// `zk60_classify` binary has already run `prove` and `verify` as its own
/// guarded processes (verify published `<run>/statement/`). Here, with no CLI
/// hook, the run directory is read through the CLI's own door
/// (`classify_cli::door`: the export load with its one checkpoint stream, the
/// R-C2 re-derivation, the B-3 re-render, the segment reads) and verified with
/// the recorder attached; this is that verification's bundle. The owner's
/// decommitment is read only for the bundle check (none of its salts beyond
/// Q, none of its pad words in the bundle); it is never copied.
///
/// | variable | what |
/// |---|---|
/// | `HL_PB_CAPTURE_DIR` | where the bundle goes (absolute, outside the repository) |
/// | `HL_PB_REAL_EXPORT` / `HL_PB_REAL_TABLES` | the export and its `token_io/` |
/// | `HL_PB_REAL_POLICY` | the registered policy id |
/// | `HL_PB_REAL_RUN` | the run directory (proved and verified by the named binary) |
/// | `HL_PB_REAL_EXPECT` | the trained statement identity (`--expect-statement`) |
/// | `HL_PB_REAL_DEC` | the owner's `input.dec` (read only) |
/// | `HL_PB_CLI_BIN` / `HL_PB_CLI_BIN_SHA256` | the named binary (recorded in the note) |
/// | `HL_RUN_CAPTURE_PUBLIC_TABLES` | `1` values, `0` length + digest |
#[test]
#[ignore = "gate round 19 (H19-2): records the verification of a REAL classifier run directory; set HL_PB_CAPTURE_DIR, HL_PB_REAL_* , HL_PB_CLI_BIN(_SHA256) and HL_RUN_CAPTURE_PUBLIC_TABLES"]
fn gate19_capture_a_real_classify_cli_run() {
    let dir = capture_dir();
    let public_tables = public_tables_from_env();
    let var = |k: &str| std::env::var(k).unwrap_or_else(|_| panic!("{k} is not set"));
    let (export, tables, policy, run, ident, dec_path) = (var("HL_PB_REAL_EXPORT"), var("HL_PB_REAL_TABLES"), var("HL_PB_REAL_POLICY"), PathBuf::from(var("HL_PB_REAL_RUN")), var("HL_PB_REAL_EXPECT"), PathBuf::from(var("HL_PB_REAL_DEC")));
    let (bin, bin_sha) = (var("HL_PB_CLI_BIN"), var("HL_PB_CLI_BIN_SHA256"));
    assert!(bin_sha.len() == 64 && bin_sha.bytes().all(|c| c.is_ascii_hexdigit()), "HL_PB_CLI_BIN_SHA256 must be the binary's SHA-256");
    let pub_flags: Vec<String> = ["--export", &export, "--tables", &tables, "--policy", &policy, "--artifact", run.to_str().unwrap(), "--expect-statement", &ident, "--min-bits", "95"].iter().map(|x| x.to_string()).collect();
    let pairs: Vec<(String, String)> = pub_flags.chunks(2).map(|kv| (kv[0].clone(), kv[1].clone())).collect();
    let t0 = std::time::Instant::now();
    let d = super::super::classify_cli::door(&pairs, &run).unwrap_or_else(|e| panic!("the CLI's door on the real run directory: {e}"));
    assert!(d.published, "the door read the named binary's published statement");
    let door_s = t0.elapsed().as_secs_f64();
    let t1 = std::time::Instant::now();
    let mut blocks = super::super::load::ExportTokenBlocks::new(&d.p);
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(d.st.capture_header().unwrap(), d.st.binding().unwrap(), CaptureOpts { arrays: true, public_tables });
    let mut bundle = match verify_classify_run_with(&d.st, &mut blocks, &d.tables, &d.segs, VerifierPolicy { min_whole_run_bits: 95 }) {
        Ok(()) => run_capture::take().expect("a bundle for the accepted verification"),
        Err(e) => {
            run_capture::discard();
            panic!("the recorded verification of the real run directory refused: {e}");
        }
    };
    drop(guard);
    drop(blocks);
    let verify_s = t1.elapsed().as_secs_f64();
    // TOKEN ROUND 17: the statement tables' values, replayed against a SECOND
    // load of the export's layers (not the verifier's)
    let t2 = std::time::Instant::now();
    let replay = if bundle.statement.is_empty() {
        None
    } else {
        use super::super::run::TokenBlocks as _;
        let mut src = super::super::load::ExportTokenBlocks::new(&d.p);
        Some(run_capture::export_replay(&mut bundle, &mut |k| src.block(k).map(|b| (*b).clone())).unwrap_or_else(|e| panic!("the export replay of the real run's statement tables: {e}")))
    };
    let replay_s = t2.elapsed().as_secs_f64();
    let dec = Decommitment::from_bytes(&std::fs::read(&dec_path).expect("the owner's input.dec")).expect("the owner's decommitment");
    let l = d.st.l();
    let n_slots = d.st.stage_shape(0).unwrap().n_slots();
    check_bundle_19(&bundle, &d.st, &d.segs, &dec, l, n_slots);
    let gates: Vec<Option<u32>> = (0..l).map(|k| d.st.stage_gate(k)).collect();
    let c = d.st.chunk();
    let note = format!(
        "Bundle (privacy gate round 19, test-only patch H19-2 in the gate's copy of token frozen-r16b): a capture through the CLASSIFIER CLI PATH (the P-18 pattern) of a REAL run. The named binary {bin} (sha256 {bin_sha}) ran `zk60_classify prove` and `zk60_classify verify` as its own guarded processes (verify published the statement); then, with no CLI hook, the run directory was read through the CLI's own door (classify_cli::door: the export load with one checkpoint stream, the R-C2 re-derivation of the margin row and the embedding digest from the pinned checkpoint, the B-3 re-render byte for byte, the segment reads) and verified with the recorder attached; this is that verification's bundle. Run profile `{}`, {l} blocks at their own R13 gate denominators {:?}, policy `{}` (c = {}), n = {} (chunk [{}, {}) of {}), verdict {} ({}). The content, every activation and the owner's decommitment are prover-side and NOT here.",
        d.st.profile(),
        gates,
        d.st.cp.policy.id,
        d.st.cp.policy.c,
        d.st.cp.n,
        c.a,
        c.b,
        c.total,
        d.st.verdict(),
        if d.st.verdict() == 1 { "flagged" } else { "not flagged" }
    );
    run_capture::write_bundle(&dir, &bundle, &d.segs, &note, "HL_PB_CAPTURE_DIR=<dir> HL_PB_REAL_EXPORT=<export> HL_PB_REAL_TABLES=<export>/token_io HL_PB_REAL_POLICY=<id> HL_PB_REAL_RUN=<run> HL_PB_REAL_EXPECT=<identity> HL_PB_REAL_DEC=<owner input.dec> HL_PB_CLI_BIN=<bin> HL_PB_CLI_BIN_SHA256=<sha> HL_RUN_CAPTURE_PUBLIC_TABLES=<1|0> cargo test --release --lib private_block::token_io::classify_capture_tests::gate19::gate19_capture_a_real_classify_cli_run -- --ignored --exact --nocapture").unwrap_or_else(|e| panic!("{e}"));
    eprintln!(
        "GATE19 CAPTURE REAL CLI RUN {} L={l} gates {:?} policy {} n {} verdict {}: door {door_s:.1} s, recorded verify {verify_s:.1} s, export replay {replay_s:.1} s{}, peak RSS {:.2} GiB; segments {} B in {}; {} in {}",
        d.st.profile(),
        gates,
        d.st.cp.policy.id,
        d.st.cp.n,
        d.st.verdict(),
        replay.as_ref().map(|x| format!(" ({} statement tables, {} entries, {} blocks)", x.tables, x.entries, x.blocks)).unwrap_or_default(),
        crate::private_block::run::peak_rss_mib() / 1024.0,
        d.segs.iter().map(|s| s.len()).sum::<usize>(),
        d.segs.len(),
        sizes_line(&bundle),
        dir.display()
    );
}

// TOKEN I/O ROUND 17: the round's tests, a child module so that they read the
// helpers above (this file adopted from the gate's H19-1 / H19-2)
#[path = "classify_r17_tests.rs"]
mod r17;

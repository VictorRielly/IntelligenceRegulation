//! **LANE C SCRATCH PROTOTYPE TESTS (2026-09-30) — NOT IN THE MAIN TREE.**
//!
//! The TinyLlama-1.1B geometry (width 2048, FFN 5632, 32 query heads of 64
//! over 4 key-value heads, T = 32) against the restored unpromoted candidate:
//!
//! * the layout counts at the TRUE geometry reproduce the retained Sol probe
//!   (`results/zk60_1b_model_20260927/layout_probe.log`), and the frozen toy,
//!   the calibration literal and 125M do not move;
//! * the TRUE geometry has a layout and NO witness: its norm window is 33
//!   bits, five remainder limbs, and the witness builder refuses by name;
//! * the development shape (norm window 32) builds an admissible DENSE
//!   SYNTHETIC witness, and one block of it proves and verifies (heavy,
//!   `#[ignore]`d) — public synthetic weights, NOT a trained model;
//! * the trained-model statement: every field moves its identity, a
//!   calibration the relations do not use is refused, and a run bound to it
//!   absorbs its identity, verifies under it, and is rejected under any other.
//!
//! **Capture rule.** Everything here is public synthetic test data. Only
//! counts, fractions, sizes, times and memory marks are printed; no witness
//! value, position or hidden word is printed or written anywhere.

use super::dense_tests::{dense_case, statement_of_words};
use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::trained_statement::*;
use super::witness::{self, Witness};
use super::*;

// ------------------------------------------------------------ layout counts

/// The Sol probe's retained counts, `layout_probe.log` lines 150 and 160.
#[test]
fn the_true_geometry_reproduces_the_retained_sol_layout_counts() {
    for (lc, a, h, receipt, u8s) in [(12usize, 1801usize, 1934usize, 12_053_320usize, 6_496_256usize), (13, 1031, 1026, 11_959_304, 6_504_448)] {
        let sh = Shape::tinyllama_t32_probe(lc).expect("the true TinyLlama geometry constructs at this row width");
        let t = sh.totals();
        assert_eq!((t.a_rows, t.h_rows, t.m_rows, t.receipt_bytes.total, t.u8_lookups), (a, h, 50, receipt, u8s), "log_cols {lc}: the counts moved from the retained probe");
        let lay = Layout::for_shape(&sh).expect("the layout builds");
        assert_eq!((lay.a_rows, lay.h_rows), (a, h), "log_cols {lc}: Layout::for_shape disagrees with Shape::totals");
        eprintln!("TinyLlama true geometry log_cols {lc}: A {a} rows, H {h} rows, M 50, receipt {receipt} B, u8 lookups {u8s}, norm window {} bits = {} limbs", sh.norm_wrho, sh.limbs_norm());
    }
    let e = Shape::tinyllama_t32_probe(14).expect_err("log_cols 14 must be refused at T32");
    assert!(e.contains("Kv domain is lifted by P-3"), "the refusal is not F-2's: {e}");
}

/// Nothing that exists moves: the toy's pinned counts and receipt length,
/// the calibration literal, 125M's rows.
#[test]
fn the_frozen_toy_the_calibration_literal_and_125m_do_not_move() {
    let t = Shape::toy().totals();
    assert_eq!((t.a_rows, t.h_rows, t.receipt_bytes.total), (455, 384, 2_816_472), "the frozen toy moved");
    assert_eq!(calibration_identity(), *blake3::hash(b"B3 public fixed calibration v1").as_bytes(), "the calibration literal moved");
    let m = Shape::m125().totals();
    assert_eq!((m.a_rows, m.h_rows), (5_681, 7_120), "125M moved");
    assert_ne!(Shape::tinyllama_t32_dev().profile, Shape::m125().profile);
    assert!(!Shape::tinyllama_t32_dev().hashes_under_the_legacy_rule(), "a new profile is tagged (D19a)");
}

/// The development shape: one override, and what it does to the counts.
#[test]
fn the_development_shape_has_four_norm_limbs_and_its_own_counts() {
    let sh = Shape::tinyllama_t32_dev();
    assert_eq!((sh.norm_wrho, sh.limbs_norm(), sh.norm_top_is_full_byte()), (32, 4, true), "the development window");
    assert_eq!((sh.d_pad, sh.h_pad, sh.f_pad, sh.t_pad), (2048, 32, 8192, 32));
    // TinyLlama pads only the limb, feed-forward and table domains
    assert_eq!(sh.padded_domains(), vec![Dom::L, Dom::F, Dom::Tab]);
    let t = sh.totals();
    let lay = Layout::for_shape(&sh).expect("the development layout builds");
    assert_eq!((lay.a_rows, lay.h_rows), (t.a_rows, t.h_rows));
    eprintln!(
        "TinyLlama dev shape: A {} rows ({} data), H {} rows ({} data), A planes {}, H planes {}, receipt {} B (slots {} / mask {} / A {} / H {} / endpoints {}), largest slot message {} of 256",
        t.a_rows,
        t.a_data_rows,
        t.h_rows,
        t.h_data_rows,
        t.a_planes,
        t.h_planes,
        t.receipt_bytes.total,
        t.receipt_bytes.slots,
        t.receipt_bytes.mask_opening,
        t.receipt_bytes.a_opening,
        t.receipt_bytes.h_opening,
        t.receipt_bytes.endpoint_openings,
        t.largest_slot_length
    );
}

// ------------------------------------------------------- the witness blocker

fn zero_words(s: &Shape) -> [Vec<i8>; 9] {
    let (d, f, kvw) = (s.width, s.hidden, s.kv_heads * s.head_dim);
    [vec![0; d * d], vec![0; kvw * d], vec![0; kvw * d], vec![0; d * d], vec![1; d], vec![1; d], vec![0; d * f], vec![0; d * f], vec![0; f * d]]
}

/// **BLOCKER B-W1, demonstrated.** At the TRUE geometry the witness builder
/// refuses before computing anything, by name, whatever the weights are.
#[test]
fn the_true_geometry_has_a_layout_but_no_witness() {
    let sh = Shape::tinyllama_t32_probe(12).expect("the probe shape");
    assert_eq!((sh.norm_wrho, sh.limbs_norm()), (33, 5));
    let (public, ff) = statement_of_words(&sh, &zero_words(&sh));
    let input = vec![0i16; sh.tokens * sh.width];
    let e = match witness::build_shaped(&sh, &public, &ff, &input) {
        Ok(_) => panic!("a five-limb witness was built"),
        Err(e) => e,
    };
    assert!(e.contains("different number of byte limbs"), "the refusal is not the pinned-limb one: {e}");
}

// ------------------------------------------- the dense synthetic block proof

fn upper_fraction(sh: &Shape, plane: &[i64]) -> f64 {
    let (d, f, fp) = (sh.width, sh.hidden, sh.f_pad);
    let live = (0..sh.tokens).flat_map(|t| (d..f).map(move |j| t * fp + j)).filter(|i| plane[*i] != 0).count();
    live as f64 / (sh.tokens * (f - d)) as f64
}

fn dense_witness(sh: &Shape) -> (BlockPublic, Witness) {
    let (public, ff, input) = dense_case(sh);
    let t0 = std::time::Instant::now();
    let w = witness::build_shaped(sh, &public, &ff, &input).unwrap_or_else(|m| panic!("the dense recipe is not admissible at {}: {m}", sh.name));
    let ids = Ids::new(sh).expect("the plane map");
    assert!(super::pad::every_checkable_relation_holds(sh, &ids, &w), "the dense witness is inconsistent");
    eprintln!(
        "TinyLlama dev dense witness built in {:.2} s; upper hidden half gate {:.1}% / act {:.1}% nonzero; peak RSS {:.0} MiB",
        t0.elapsed().as_secs_f64(),
        100.0 * upper_fraction(sh, &w.planes[ids.at(A_G8)]),
        100.0 * upper_fraction(sh, &w.planes[ids.at(A_A16)]),
        run::peak_rss_mib()
    );
    (BlockPublic::new(public, ff), w)
}

/// Admissibility only (no proof): the dense recipe survives width 2048.
#[test]
#[ignore = "lane C heavy: builds a width-2048 witness"]
fn lane_c_the_dense_recipe_is_admissible_at_the_tinyllama_dev_shape() {
    let sh = Shape::tinyllama_t32_dev();
    let _ = dense_witness(&sh);
}

fn lane_c_context() -> Digest {
    *blake3::hash(b"lane C scratch: the TinyLlama geometry, dense synthetic").as_bytes()
}

/// **ONE BLOCK AT THE TINYLLAMA GEOMETRY PROVES AND VERIFIES** — dense public
/// SYNTHETIC weights, development calibration, CPU. With the three controls a
/// trained-block acceptance would need: a statement mutation, a receipt
/// mutation and a truncation are refused.
#[test]
#[ignore = "lane C heavy: one width-2048 block proof"]
fn lane_c_one_dense_block_proves_and_verifies_at_the_tinyllama_dev_shape() {
    let sh = Shape::tinyllama_t32_dev();
    let (blk, w) = dense_witness(&sh);
    let ids = Ids::new(&sh).expect("the plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| i16::try_from(*v).expect("an endpoint word outside int16")).collect() };
    let spec = IoSpec::new_shaped(&sh, lane_c_context(), 0, 0).expect("the endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &plane(ids.at(A_X)), &plane(ids.at(A_X2))).expect("the endpoint owners");
    let t0 = std::time::Instant::now();
    let (receipt, _) = prove_inner_at(&sh, &blk, w, &expected, owners).expect("the honest dense TinyLlama-geometry block proves");
    let prove_s = t0.elapsed().as_secs_f64();
    let bytes = receipt.to_bytes_at(&sh, &blk, &expected).expect("the receipt encodes");
    let hwm_prove = run::peak_rss_mib();
    assert_eq!(bytes.len(), sh.receipt_bytes().total, "the receipt is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the receipt verifies in typed form");
    drop(receipt);
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the receipt verifies from bytes");
    let verify_s = t1.elapsed().as_secs_f64();
    // control 1: truncation
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short receipt was accepted");
    // control 2: receipt mutation, one byte in the middle of the frame
    let mut bad = bytes.clone();
    let mid = bad.len() / 2;
    bad[mid] ^= 1;
    assert!(verify_bytes_at(&sh, &blk, &expected, &bad).is_err(), "a mutated receipt was accepted");
    // control 3: statement mutation, one public weight word moved
    let (mut public2, ff2, _) = dense_case(&sh);
    public2.gamma_a[0] = public2.gamma_a[0].wrapping_add(1).max(1);
    let blk2 = BlockPublic::new(public2, ff2);
    assert_ne!(blk2.digest(), blk.digest());
    assert!(verify_bytes_at(&sh, &blk2, &expected, &bytes).is_err(), "a receipt verified under another public statement");
    eprintln!(
        "LANE C TinyLlama dev shape, ONE dense synthetic block: prove {prove_s:.2} s, verify from bytes {verify_s:.2} s, receipt {} B (counted {}), peak RSS after prove {hwm_prove:.0} MiB, at end {:.0} MiB (shared box, diagnostic only; NOT a trained model)",
        bytes.len(),
        sh.receipt_bytes().total,
        run::peak_rss_mib()
    );
}

// ------------------------------------------------ the trained statement

fn synthetic_source(name: &str, layers: u32) -> ModelSource {
    ModelSource {
        kind: SourceKind::PublicSyntheticRecipe,
        repo: "hashline/private-block/tame-fixture".into(),
        revision: name.into(),
        weights_sha256: [0; 32],
        config_sha256: [0; 32],
        checkpoint_parameters: 0,
        checkpoint_layers: layers,
    }
}

fn calib(sh: &Shape) -> IntegerCalibration {
    IntegerCalibration::as_the_code_proves(sh, &Provenance::recipe("lane-c/scratch-dev/0", 1.0 / 1024.0, [7; 32], [9; 32]))
}

/// The pinned TinyLlama source record, and its refusals.
#[test]
fn the_tinyllama_source_record_is_the_pinned_one_and_is_checked() {
    let s = ModelSource::tinyllama_chat_v1_0();
    assert_eq!((s.checkpoint_parameters, s.checkpoint_layers), (1_100_048_384, 22));
    let sh = Shape::tinyllama_t32_dev();
    let (public, ff) = statement_of_words(&sh, &zero_words(&sh));
    let blk = BlockPublic::new(public, ff);
    let rec = LayerRecord::of_block(0, &blk, vec![("model.layers.0.self_attn.q_proj.weight".into(), [1; 32])]);
    let st = TrainedModelStatement::new(&sh, run::RUN_PROFILE_TINYLLAMA_T32_DEV, s.clone(), calib(&sh), vec![rec.clone()]).expect("a one-layer statement");
    let id = st.identity();
    assert_eq!(id, TrainedModelStatement::new(&sh, run::RUN_PROFILE_TINYLLAMA_T32_DEV, s.clone(), calib(&sh), vec![rec.clone()]).unwrap().identity(), "the identity is not deterministic");
    let mut branch = s.clone();
    branch.revision = "main".into();
    assert!(TrainedModelStatement::new(&sh, run::RUN_PROFILE_TINYLLAMA_T32_DEV, branch, calib(&sh), vec![rec.clone()]).is_err(), "a branch name was accepted as a revision");
    let mut nohash = s.clone();
    nohash.weights_sha256 = [0; 32];
    assert!(TrainedModelStatement::new(&sh, run::RUN_PROFILE_TINYLLAMA_T32_DEV, nohash, calib(&sh), vec![rec.clone()]).is_err(), "a source without its tensor-file digest was accepted");
    let mut far = rec.clone();
    far.index = 22;
    assert!(TrainedModelStatement::new(&sh, run::RUN_PROFILE_TINYLLAMA_T32_DEV, s.clone(), calib(&sh), vec![far]).is_err(), "layer 22 of a 22-layer checkpoint was accepted");
    eprintln!("the one-layer TinyLlama dev statement: {} encoded bytes", st.encode().len());
}

/// Every field moves the identity; a constant the relations do not use is
/// refused rather than hashed.
#[test]
fn every_statement_field_moves_the_identity_and_an_unused_constant_is_refused() {
    let sh = Shape::tinyllama_t32_dev();
    let (public, ff) = statement_of_words(&sh, &zero_words(&sh));
    let blk = BlockPublic::new(public, ff);
    let rec = LayerRecord::of_block(0, &blk, vec![]);
    let base = TrainedModelStatement::new(&sh, run::RUN_PROFILE_TINYLLAMA_T32_DEV, ModelSource::tinyllama_chat_v1_0(), calib(&sh), vec![rec.clone()]).unwrap();
    let mut ids = vec![base.identity()];
    let mut push = |st: TrainedModelStatement| ids.push(st.identity());
    let mut v = base.clone();
    v.source.revision = "0000000000000000000000000000000000000000".into();
    push(v);
    let mut v = base.clone();
    v.source.weights_sha256[0] ^= 1;
    push(v);
    let mut v = base.clone();
    v.source.config_sha256[31] ^= 1;
    push(v);
    let mut v = base.clone();
    v.layers[0].block_digest[0] ^= 1;
    push(v);
    let mut v = base.clone();
    v.layers[0].word_sha256[8][0] ^= 1;
    push(v);
    let mut v = base.clone();
    v.layers[0].table_sha256[1][0] ^= 1;
    push(v);
    let mut v = base.clone();
    v.calibration.quantizer_sha256[0] ^= 1;
    push(v);
    let mut v = base.clone();
    v.calibration.calibration_set_sha256[0] ^= 1;
    push(v);
    let mut v = base.clone();
    v.calibration.residual_unit_f64_bits ^= 1;
    push(v);
    let mut v = base.clone();
    v.calibration.label.push('x');
    push(v);
    let mut v = base.clone();
    v.run_profile.push('x');
    push(v);
    let mut v = base.clone();
    v.layers[0].source_tensors.push(("model.layers.0.mlp.down_proj.weight".into(), [3; 32]));
    push(v);
    let n = ids.len();
    ids.sort();
    ids.dedup();
    assert_eq!(ids.len(), n, "two different statements share an identity");
    // a calibration constant the relations do not use is REFUSED, not hashed
    let mut c = calib(&sh);
    c.norm_cn_a = 4096;
    assert!(TrainedModelStatement::new(&sh, run::RUN_PROFILE_TINYLLAMA_T32_DEV, ModelSource::tinyllama_chat_v1_0(), c, vec![rec.clone()]).is_err(), "a norm constant the relations do not use was accepted");
    let mut c = calib(&sh);
    c.sh_qkv = 10;
    assert!(TrainedModelStatement::new(&sh, run::RUN_PROFILE_TINYLLAMA_T32_DEV, ModelSource::tinyllama_chat_v1_0(), c, vec![rec]).is_err(), "a shift the relations do not use was accepted");
}

// ------------------------------------------- a run BOUND to its statement

fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// the honest chain at a small shape, ONE plane per boundary kept
struct Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl Chain {
    fn honest(sh: &Shape, l: usize) -> Chain {
        let (public, ff, x0) = super::grow_tests::tame_case(sh);
        let ids = Ids::new(sh).unwrap();
        let (mut inputs, mut planes, mut x) = (vec![], vec![], x0);
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().unwrap());
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

fn bound_statement(sh: &Shape, profile: &str, blocks: &[BlockPublic], quantizer: u8) -> TrainedModelStatement {
    let recs = blocks.iter().enumerate().map(|(k, b)| LayerRecord::of_block(k as u32, b, vec![])).collect();
    let mut c = calib(sh);
    c.quantizer_sha256 = [quantizer; 32];
    TrainedModelStatement::new(sh, profile, synthetic_source("tame", blocks.len() as u32), c, recs).expect("the statement")
}

/// **THE BINDING, end to end at the rung-G development shape (small and
/// fast).** A run bound to a statement absorbs that statement's identity,
/// which is NOT the literal, proves and verifies; the same segments are
/// REJECTED under a statement that differs in one provenance byte, and a
/// statement that does not describe the run does not construct.
#[test]
fn a_run_bound_to_its_statement_verifies_and_is_rejected_under_any_other() {
    let sh = Shape::rung_g();
    let l = 2;
    let mut chain = Chain::honest(&sh, l);
    let blocks: Vec<BlockPublic> = (0..l).map(|_| BlockPublic::new(chain.public.clone(), chain.ff.clone())).collect();
    let ctx = *blake3::hash(b"lane C: a bound run").as_bytes();
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &chain.planes[0], &chain.planes[l]).unwrap();
    let model = bound_statement(&sh, run::RUN_PROFILE_RUNG_G, &blocks, 1);
    let st = RunStatement::new_bound(RunShape::rung_g(l).unwrap(), ctx, expected.clone(), &blocks, &vec![(0, 0); l], &model).expect("the bound run statement");
    let plain = RunStatement::new(RunShape::rung_g(l).unwrap(), ctx, expected.clone(), &blocks, &vec![(0, 0); l]).unwrap();
    assert_ne!(st.binding().unwrap(), plain.binding().unwrap(), "the bound run absorbs the literal calibration");
    let mut segs: Vec<Vec<u8>> = vec![];
    run::prove_run(&st, &blocks, &mut chain, owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the bound run proves");
    run::verify_run(&st, &blocks, &segs).expect("the bound run verifies under its own statement");
    // one provenance byte moved: same blocks, same scales, other identity
    let other = bound_statement(&sh, run::RUN_PROFILE_RUNG_G, &blocks, 2);
    let st2 = RunStatement::new_bound(RunShape::rung_g(l).unwrap(), ctx, expected.clone(), &blocks, &vec![(0, 0); l], &other).unwrap();
    assert!(run::verify_run(&st2, &blocks, &segs).is_err(), "the segments verified under a different model statement");
    assert!(run::verify_run(&plain, &blocks, &segs).is_err(), "the segments verified under the literal calibration");
    // statements that do not describe this run do not construct
    let short = bound_statement(&sh, run::RUN_PROFILE_RUNG_G, &blocks[..1], 1);
    assert!(RunStatement::new_bound(RunShape::rung_g(l).unwrap(), ctx, expected.clone(), &blocks, &vec![(0, 0); l], &short).is_err(), "a one-layer statement bound a two-block run");
    let wrong_profile = bound_statement(&sh, run::RUN_PROFILE_RUNG_K4, &blocks, 1);
    assert!(RunStatement::new_bound(RunShape::rung_g(l).unwrap(), ctx, expected.clone(), &blocks, &vec![(0, 0); l], &wrong_profile).is_err(), "a statement for another run profile was accepted");
    let mut foreign = model.clone();
    foreign.layers[1].block_digest[0] ^= 1;
    assert!(RunStatement::new_bound(RunShape::rung_g(l).unwrap(), ctx, expected.clone(), &blocks, &vec![(0, 0); l], &foreign).is_err(), "a statement naming another block was accepted");
    assert!(RunStatement::new_bound(RunShape::rung_g(l).unwrap(), ctx, expected, &blocks, &[(0, 0), (1, 1)], &model).is_err(), "a scale the calibration does not approve was accepted");
}

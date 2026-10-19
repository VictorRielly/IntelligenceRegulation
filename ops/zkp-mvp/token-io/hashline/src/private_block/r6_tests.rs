//! **NATIVE LANE, ROUND 6: the PER-LAYER softmax score shift `sh_s`.** TEST
//! CODE ONLY. Public synthetic data only.
//!
//! * `Shape::with_score_shift`: trained shapes only, the one-limb window,
//!   CS-8's rebuild and the trained class; the layout moves only in its
//!   calibration line;
//! * the trained statement records a layer's own `sh_s` canonically (never
//!   equal to the run's, inside the window) and binds it; a statement with no
//!   per-layer value encodes exactly as before R6;
//! * the no-wrap clauses of the score requantization over the whole class
//!   (`sh_s` 1..=8) at the 8B T128 shape;
//! * a two-block bound run at the trained rung with block 1 at its own
//!   `sh_s`: proves and verifies; a verifier whose statement drops the
//!   per-layer value refuses; a block-1 witness built at the run's shift and
//!   proved under the per-layer statement is rejected.

use super::layout::*;
use super::shape::Shape;
use super::trained_statement::*;
use super::witness::{self, Witness};
use super::*;

fn rung() -> Shape {
    Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).expect("the trained-calibration rung")
}

#[test]
fn with_score_shift_admits_the_window_at_trained_shapes_only() {
    let sh = rung();
    assert_eq!(sh.sh_s, 5);
    for v in 1..=8u32 {
        let s = sh.with_score_shift(v).unwrap_or_else(|e| panic!("sh_s {v}: {e}"));
        assert_eq!(s.sh_s, v);
        s.check_constructed().expect("CS-8 rebuild");
        let (a, b) = (Layout::for_shape(&sh).unwrap(), Layout::for_shape(&s).unwrap());
        assert_eq!((a.a_rows, a.h_rows), (b.a_rows, b.h_rows), "sh_s {v} moved the layout's counts");
        let (da, db) = (a.describe(), b.describe());
        let differ: Vec<usize> = (0..da.len()).filter(|i| da[*i] != db[*i]).collect();
        if v == sh.sh_s {
            assert!(differ.is_empty());
        } else {
            assert!(!differ.is_empty() && differ.iter().all(|i| da[*i].contains("calibration")), "sh_s {v} moved a schedule line other than the calibration line: {differ:?}");
        }
    }
    for v in [0u32, 9, 16] {
        assert!(sh.with_score_shift(v).unwrap_err().contains("window"), "sh_s {v} was admitted");
    }
    assert!(Shape::rung_c6().with_score_shift(6).unwrap_err().contains("frozen"), "a frozen shape took a per-layer shift");
    // the 8B T128 profile too (the b7 export's)
    let l8 = Shape::llama3_8b_trained(128, &super::trained_calib_tests::llama3_8b_calibration(), 9).unwrap();
    assert_eq!(l8.with_score_shift(7).unwrap().sh_s, 7);
}

/// The score requantization relation `2^sh_s s8 + rsl - 2^(sh_s-1) - acc`
/// at the top of the class, with the adversarial facts (`s8` int8, `rsl` in
/// `[0, 2^sh_s)` by its byte limb and scaled top, `acc` the score product of
/// int8 q and k over `head_dim`): below p/2 at every `sh_s` in 1..=8 at the
/// 8B T128 shape (head_dim 128), as the reviewer's class-wide checker
/// (`results/zk60_d24_review_20261017/reviewer_nowrap_r5.py`, host "score
/// (sum over head_dim, sh_s 1..8)") already says for every 8B T.
#[test]
fn the_score_requant_no_wrap_holds_over_the_class_at_8b_t128() {
    let half_p = (zkp_core::field::P / 2) as i128;
    let base = Shape::llama3_8b_trained(128, &super::trained_calib_tests::llama3_8b_calibration(), 9).unwrap();
    for v in 1..=8u32 {
        let s = base.with_score_shift(v).unwrap();
        let hd = s.head_dim as i128;
        let host = (1i128 << v) * 127 + ((1i128 << v) - 1) + (1i128 << (v - 1)) + hd * 127 * 127;
        assert!(host < half_p, "sh_s {v}: the score host relation reaches p/2 ({host})");
        assert!(host < 1i128 << 22, "sh_s {v}: {host}");
    }
}

fn source(l: usize) -> ModelSource {
    ModelSource {
        kind: SourceKind::PublicSyntheticRecipe,
        repo: "hashline/private-block/r6-per-layer".into(),
        revision: "native-round-6".into(),
        weights_sha256: [0; 32],
        config_sha256: [0; 32],
        checkpoint_parameters: 0,
        checkpoint_layers: l as u32,
    }
}

fn statement(sh: &Shape, blocks: &[BlockPublic], own: &[Option<u32>]) -> Result<TrainedModelStatement, String> {
    let mut prov = Provenance::recipe("native/r6", 1.0 / 512.0, [5; 32], [6; 32]);
    prov.rope_theta = super::shape::trained_rope_theta(sh.profile).unwrap_or(prov.rope_theta);
    let cal = IntegerCalibration::as_the_code_proves(sh, &prov);
    let recs = blocks.iter().enumerate().map(|(k, b)| LayerRecord { sh_s: own[k], ..LayerRecord::of_block(k as u32, b, vec![]) }).collect();
    let rp = super::trained_calib_tests::run_shape_for(sh, blocks.len()).profile();
    TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(sh, rp, source(blocks.len()), cal, recs)
}

#[test]
fn the_statement_records_a_layers_own_shift_canonically_and_binds_it() {
    let sh = rung();
    let (blk, _) = super::trained_calib_tests::trained_dense_block(&sh);
    let blocks = vec![blk.clone(), blk];
    let none = statement(&sh, &blocks, &[None, None]).unwrap();
    let own = statement(&sh, &blocks, &[None, Some(6)]).unwrap();
    assert_ne!(none.identity(), own.identity(), "a layer's own sh_s is not bound by the identity");
    // a statement without per-layer values encodes exactly as before R6:
    // no `sh-score-layer` field anywhere
    assert!(!String::from_utf8_lossy(&none.encode()).contains("sh-score-layer"));
    assert!(String::from_utf8_lossy(&own.encode()).contains("sh-score-layer"));
    // canonical: a per-layer value equal to the run's is refused, and so is
    // one outside the window
    assert!(statement(&sh, &blocks, &[None, Some(5)]).unwrap_err().contains("equals the run's"));
    assert!(statement(&sh, &blocks, &[None, Some(9)]).unwrap_err().contains("window"));
}

/// two witnesses in order, with block 0's output as the one boundary
struct Two(Vec<Option<Witness>>, Vec<i16>);

impl super::run::RunWitnessSource for Two {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.0[k].take().ok_or_else(|| "consumed".to_string())
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        if k == 0 {
            Ok(self.1.clone())
        } else {
            Err("one boundary".into())
        }
    }
}

fn plane(w: &Witness, p: usize) -> Vec<i16> {
    w.planes[p].iter().map(|v| i16::try_from(*v).unwrap()).collect()
}

fn true_words(sh: &Shape, padded: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| padded[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// prove the two-block chain (block 1's witness built at `w1_shift`) under
/// a run statement whose layer 1 carries `own1`; returns the segments
fn prove_two(sh: &Shape, blocks: &[BlockPublic], input: &[i16], w1_shift: u32, own1: Option<u32>) -> Result<(ExpectedIo, Vec<Vec<u8>>), String> {
    let ids = Ids::new(sh)?;
    let w0 = witness::build_shaped(sh, blocks[0].attention(), blocks[0].feed_forward(), input)?;
    let x1 = true_words(sh, &plane(&w0, ids.at(A_X2)));
    let s1 = if w1_shift == sh.sh_s { sh.clone() } else { sh.with_score_shift(w1_shift)? };
    let w1 = witness::build_shaped(&s1, blocks[1].attention(), blocks[1].feed_forward(), &x1)?;
    let ctx = *blake3::hash(b"native r6: per-layer sh_s").as_bytes();
    let spec = IoSpec::new_shaped(sh, ctx, 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &plane(&w0, ids.at(A_X)), &plane(&w1, ids.at(A_X2)))?;
    let st = super::run::RunStatement::new_bound(super::trained_calib_tests::run_shape_for(sh, 2), ctx, expected.clone(), blocks, &[(0, 0), (0, 0)], &statement(sh, blocks, &[None, own1])?)?;
    let boundary = plane(&w0, ids.at(A_X2));
    let mut segs = Vec::new();
    super::run::prove_run(&st, blocks, &mut Two(vec![Some(w0), Some(w1)], boundary), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })?;
    Ok((expected, segs))
}

fn verify_two(sh: &Shape, blocks: &[BlockPublic], expected: &ExpectedIo, segs: &[Vec<u8>], own1: Option<u32>) -> Result<(), String> {
    let ctx = *blake3::hash(b"native r6: per-layer sh_s").as_bytes();
    let e = ExpectedIo::from_bytes_at(sh, &expected.to_bytes())?;
    let st = super::run::RunStatement::new_bound(super::trained_calib_tests::run_shape_for(sh, 2), ctx, e, blocks, &[(0, 0), (0, 0)], &statement(sh, blocks, &[None, own1])?)?;
    super::run::verify_run(&st, blocks, segs)
}

#[test]
fn a_two_block_run_with_block_1_at_its_own_shift_proves_verifies_and_is_bound() {
    let sh = rung();
    let (w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    let mut w1 = w.clone();
    for (i, m) in w1.iter_mut().enumerate() {
        let len = m.len();
        m.rotate_left((7 + i) % len);
    }
    let blocks: Vec<BlockPublic> = [w, w1].iter().map(|ws| {
        let (p, f) = super::dense_tests::statement_of_words(&sh, ws);
        BlockPublic::new(p, f)
    }).collect();
    // the honest per-layer run: block 1's witness at sh_s 6, statement layer 1 = 6
    let (expected, segs) = prove_two(&sh, &blocks, &input, 6, Some(6)).expect("the per-layer run proves");
    verify_two(&sh, &blocks, &expected, &segs, Some(6)).expect("the per-layer run verifies");
    // a verifier whose statement says layer 1 runs at the run's shift refuses
    let e = verify_two(&sh, &blocks, &expected, &segs, None).expect_err("a run proved with block 1 at sh_s 6 VERIFIED under a run-wide statement");
    eprintln!("R6 per-layer sh_s, run-wide verifier: refused: {}", e.chars().take(120).collect::<String>());
    // and another per-layer value refuses too
    assert!(verify_two(&sh, &blocks, &expected, &segs, Some(7)).is_err(), "a run proved with block 1 at sh_s 6 VERIFIED as sh_s 7");
    // a CHEATING prover: block 1's witness built at the run's shift (5) and
    // proved under the per-layer statement (6) is rejected by the verifier
    let _cheat = super::protocol::CheatingProver::on();
    let (expected, segs) = prove_two(&sh, &blocks, &input, 5, Some(6)).expect("a cheating prover produces segments");
    let e = verify_two(&sh, &blocks, &expected, &segs, Some(6)).expect_err("a block-1 witness at sh_s 5 VERIFIED under layer 1's own sh_s 6");
    eprintln!("R6 per-layer sh_s, witness at the wrong shift: rejected: {}", e.chars().take(120).collect::<String>());
}

#[test]
fn a_runs_stage_shape_follows_its_layers_own_shift() {
    let sh = rung();
    let (blk, _) = super::trained_calib_tests::trained_dense_block(&sh);
    let blocks = vec![blk.clone(), blk];
    let ctx = *blake3::hash(b"native r6: stage shapes").as_bytes();
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap();
    let e = ExpectedIo::from_roots(spec, [1; 32], [2; 32]);
    let st = super::run::RunStatement::new_bound(super::trained_calib_tests::run_shape_for(&sh, 2), ctx, e.clone(), &blocks, &[(0, 0), (0, 0)], &statement(&sh, &blocks, &[None, Some(7)]).unwrap()).unwrap();
    assert_eq!(st.stage_shape(0).unwrap().sh_s, 5);
    assert_eq!(st.stage_shape(1).unwrap().sh_s, 7);
    let flat = super::run::RunStatement::new_bound(super::trained_calib_tests::run_shape_for(&sh, 2), ctx, e, &blocks, &[(0, 0), (0, 0)], &statement(&sh, &blocks, &[None, None]).unwrap()).unwrap();
    assert_eq!(flat.stage_shape(1).unwrap().sh_s, 5);
}

/// **Review r5 note N-r5-a: ruling CS-3's lookup-miss refusal, run before
/// any proof exists.** `protocol::check_lookup_misses` (which the trained
/// stack's sealing pass calls on every sealed witness) admits an honest
/// witness and refuses, by the one CS-3 name and the table family only, a
/// witness that looks up a byte, an exp pair or an activation pair that is
/// not a row of its table; and the sealing pass does call it.
#[test]
fn the_sealing_pass_lookup_miss_check_refuses_by_the_cs3_name() {
    let sh = rung();
    let (blk, input) = super::trained_calib_tests::trained_dense_block(&sh);
    let mut w = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the honest witness");
    let lay = Layout::for_shape(&sh).unwrap();
    super::protocol::check_lookup_misses(&sh, &lay, &blk, &w).expect("an honest witness misses no lookup");
    let ids = Ids::new(&sh).unwrap();
    for (plane, delta, family) in [(ids.at(A_X2L0), 256i64, "the byte table"), (ids.at(A_E), 1, "the exp table"), (ids.at(A_A16), 1, "the activation table")] {
        w.planes[plane][0] += delta;
        let e = super::protocol::check_lookup_misses(&sh, &lay, &blk, &w).expect_err("a lookup miss was admitted");
        assert!(e.starts_with(super::protocol::LOOKUP_MISS_REFUSAL) && e.contains(family), "{e}");
        w.planes[plane][0] -= delta;
    }
    super::protocol::check_lookup_misses(&sh, &lay, &blk, &w).expect("the restored witness");
    let src = include_str!("trained_block.rs");
    let seal = src.split("fn seal_and_record(").nth(1).expect("seal_and_record").split("\nfn ").next().unwrap();
    assert!(seal.contains("super::protocol::check_lookup_misses(&ssh, lay, &cur.blk, &w)"), "the sealing pass does not run the CS-3 miss check");
}

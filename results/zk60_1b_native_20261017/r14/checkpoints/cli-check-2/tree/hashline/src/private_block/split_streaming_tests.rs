//! Native source admission and reload controls, plus separately guarded proofs.
use super::split_run_tests::fixture;
use crate::private_block::{run::BlockRef, split_run, BlockPublic};
use std::{
    cell::RefCell,
    rc::Rc,
    sync::{Arc, Weak},
};

#[derive(Default)]
pub(super) struct Metrics {
    pub loads: Vec<usize>,
    pub allocated: Vec<Weak<BlockPublic>>,
    pub max_live: usize,
}

/// A test cache owning exactly one newly allocated public block. The original
/// fixture is resident: this tests cache lifetimes, not whole-model RSS.
pub(super) struct OneBlockSource<'a> {
    blocks: &'a [BlockPublic],
    reported: usize,
    order: Vec<usize>,
    cache: Option<(usize, Arc<BlockPublic>)>,
    metrics: Rc<RefCell<Metrics>>,
    change_on_call: Option<usize>,
    bad_shape_on_call: Option<usize>,
}
impl<'a> OneBlockSource<'a> {
    pub(super) fn new(blocks: &'a [BlockPublic]) -> (Self, Rc<RefCell<Metrics>>) {
        let metrics = Rc::new(RefCell::new(Metrics::default()));
        (
            Self {
                blocks,
                reported: blocks.len(),
                order: (0..blocks.len()).collect(),
                cache: None,
                metrics: metrics.clone(),
                change_on_call: None,
                bad_shape_on_call: None,
            },
            metrics,
        )
    }
}
impl split_run::PublicBlockSource for OneBlockSource<'_> {
    fn count(&self) -> usize {
        self.reported
    }
    fn block(&mut self, k: usize) -> Result<BlockRef<'_>, String> {
        self.metrics.borrow_mut().loads.push(k);
        let call = self.metrics.borrow().loads.len();
        if let Some((index, block)) = &self.cache {
            if *index == k && self.change_on_call != Some(call) {
                return Ok(BlockRef::Shared(block.clone()));
            }
            assert_eq!(
                Arc::strong_count(block),
                1,
                "previous public block still leased"
            );
        }
        self.cache = None;
        let index = *self.order.get(k).ok_or("test source index absent")?;
        let mut block = self
            .blocks
            .get(index)
            .ok_or("test source block absent")?
            .clone();
        if self.change_on_call == Some(call) {
            block.feed_forward.wg_t[0] ^= 1;
        }
        if self.bad_shape_on_call == Some(call) {
            block.feed_forward.gamma_m.pop();
        }
        let block = Arc::new(block);
        {
            let mut metrics = self.metrics.borrow_mut();
            metrics.allocated.push(Arc::downgrade(&block));
            let live = metrics
                .allocated
                .iter()
                .filter(|w| w.strong_count() > 0)
                .count();
            metrics.max_live = metrics.max_live.max(live);
            assert_eq!(live, 1, "source owns more than one public block");
        }
        self.cache = Some((k, block.clone()));
        Ok(BlockRef::Shared(block))
    }
}

fn distinct_fixture(
    dd: bool,
) -> (
    crate::private_block::shape::Shape,
    Vec<BlockPublic>,
    crate::private_block::trained_statement::TrainedModelStatement,
) {
    let (shape, mut blocks, mut model) = fixture(dd);
    blocks[1].feed_forward.wg_t[0] ^= 1;
    model.layers[1].block_digest = blocks[1].digest();
    (shape, blocks, model)
}

#[test]
fn split_streaming_record_plan_matches_resident_plan_and_refuses_invalid_metadata() {
    for dd in [false, true] {
        let (shape, blocks, model) = distinct_fixture(dd);
        let scales = [model.calibration.block_scales; 2];
        let resident =
            split_run::Plan::new(shape.clone(), [113; 32], &model, &blocks, &scales).unwrap();
        let records =
            split_run::Plan::from_records(shape.clone(), [113; 32], &model, &scales).unwrap();
        assert_eq!(resident.digest(), records.digest());
        for k in 0..2 {
            assert_eq!(
                resident.stage(k).unwrap().digest(),
                records.stage(k).unwrap().digest()
            );
        }
        for out in [false, true] {
            assert_eq!(
                resident.endpoint(out).unwrap().digest(),
                records.endpoint(out).unwrap().digest()
            );
        }
        assert!(split_run::Plan::from_records(shape.clone(), [0; 32], &model, &scales).is_err());
        assert!(
            split_run::Plan::from_records(shape.clone(), [113; 32], &model, &scales[..1]).is_err()
        );
        let mut bad = scales;
        bad[1].0 += 1;
        assert!(split_run::Plan::from_records(shape, [113; 32], &model, &bad).is_err());
    }
}

#[test]
fn split_streaming_source_count_and_digest_are_checked_before_verifier_header() {
    let (shape, blocks, model) = distinct_fixture(false);
    let scales = [model.calibration.block_scales; 2];
    let statement = split_run::Plan::from_records(shape, [113; 32], &model, &scales)
        .unwrap()
        .bind([1; 32], [2; 32])
        .unwrap();
    for count in [0, 1, 3] {
        let (mut source, metrics) = OneBlockSource::new(&blocks);
        source.reported = count;
        let error = match split_run::Verifier::with_source(&statement, Box::new(source)) {
            Ok(_) => panic!("source count accepted"),
            Err(e) => e,
        };
        assert!(error.contains("public block count differs"));
        assert!(metrics.borrow().loads.is_empty());
    }
    let (mut source, metrics) = OneBlockSource::new(&blocks);
    source.order = vec![1, 0];
    let error = match split_run::Verifier::with_source(&statement, Box::new(source)) {
        Ok(_) => panic!("wrong public block order accepted"),
        Err(e) => e,
    };
    assert!(error.contains("stage public block differs"));
    assert_eq!(metrics.borrow().loads, vec![0]);
    let (mut source, metrics) = OneBlockSource::new(&blocks);
    source.bad_shape_on_call = Some(1);
    let error = match split_run::Verifier::with_source(&statement, Box::new(source)) {
        Ok(_) => panic!("wrong public block shape accepted"),
        Err(e) => e,
    };
    assert!(
        !error.is_empty() && !error.contains("stage public block differs"),
        "shape validation was skipped: {error}"
    );
    assert_eq!(metrics.borrow().loads, vec![0]);
    let (source, metrics) = OneBlockSource::new(&blocks);
    let verifier = split_run::Verifier::with_source(&statement, Box::new(source)).unwrap();
    assert_eq!(metrics.borrow().loads, vec![0, 1]);
    assert_eq!(metrics.borrow().max_live, 1);
    assert!(
        verifier.finish().is_err(),
        "a source preflight is not a verified proof"
    );
    assert!(metrics
        .borrow()
        .allocated
        .iter()
        .all(|w| w.strong_count() == 0));
}

pub(super) fn verify_source_controls(
    statement: &split_run::Statement,
    blocks: &[BlockPublic],
    frames: &[Vec<u8>],
) -> Result<(), String> {
    let (source, metrics) = OneBlockSource::new(blocks);
    let mut verifier = split_run::Verifier::with_source(statement, Box::new(source))?;
    for frame in frames {
        verifier.verify_next(frame)?;
    }
    verifier.finish()?;
    assert_eq!(metrics.borrow().max_live, 1);
    assert!(metrics
        .borrow()
        .allocated
        .iter()
        .all(|w| w.strong_count() == 0));
    for bad_stage in 0..frames.len() {
        let (mut source, _) = OneBlockSource::new(blocks);
        source.change_on_call = Some(blocks.len() + bad_stage + 1);
        let mut verifier = split_run::Verifier::with_source(statement, Box::new(source))?;
        for frame in &frames[..bad_stage] {
            verifier.verify_next(frame)?;
        }
        let error = verifier
            .verify_next(&frames[bad_stage])
            .expect_err("changed public block accepted after preflight");
        assert!(
            error.contains("stage public block differs"),
            "unexpected reload refusal: {error}"
        );
        assert!(verifier.finish().is_err());
    }
    eprintln!(
        "R14_STREAM_SOURCE_VERIFY stages={} peak_owned_public_blocks=1 reload_changes_refused={}",
        frames.len(),
        frames.len()
    );
    Ok(())
}

#[test]
#[ignore = "guarded native source-based R14 prover/resident+cache verifiers; explicit DD and source-control env"]
fn split_streaming_t128_source_prover_and_both_verifiers() {
    assert_eq!(std::env::var("HL_R14_STREAM_SOURCE_CONTROLS").unwrap(), "1");
    let dd = match std::env::var("HL_R14_DD").unwrap().as_str() {
        "0" => false,
        "1" => true,
        _ => panic!("DD0/1"),
    };
    super::split_run_tests::prove_case(dd, false);
}

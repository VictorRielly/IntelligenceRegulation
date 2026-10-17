//! **NATIVE LANE, ROUND 5 (R5-1): the 125M lane's later rulings, ported**
//! (finding G-1 of the privacy-gate lane): CS-1, CS-3, CS-4, CS-6, CS-7,
//! CS-8, CS-9 and S38-F1(a), as built at the 125M lane's stages 39–44
//! (`docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS.md` §9–§13 on branch
//! `zk60-private-block-125m`). TEST CODE ONLY.
//!
//! The lane's named tests (`s40_tests` … `s44_tests`) lean on fixtures this
//! tree does not carry (rung-K8, the stage-36 draw observers, the census
//! module); each test here is the same claim on this tree's fixtures: the
//! refusal fires BY NAME at each place the ruling puts it, and the honest
//! control still proves and verifies. Public synthetic data only.

use super::layout::*;
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::{NormCalibration, Shape, TOY_PROFILE};
use super::witness::{self, Witness};
use super::*;

fn ctx() -> Digest {
    *blake3::hash(b"cs port").as_bytes()
}

fn plane(sh: &Shape, w: &Witness, p: usize) -> Vec<i16> {
    let ids = Ids::new(sh).unwrap();
    w.planes[ids.at(p)].iter().map(|v| *v as i16).collect()
}

/// a block and its honest witness at `sh`, on the tame recipe
fn tame(sh: &Shape) -> (BlockPublic, Witness) {
    let (public, ff, input) = super::grow_tests::tame_case(sh);
    let w = witness::build_shaped(sh, &public, &ff, &input).expect("the tame witness");
    (BlockPublic::new(public, ff), w)
}

// ------------------------------------------------------------- CS-1 / S38-F1(a)

/// **CS-1 + S38-F1(a).** A feed-forward half built at one shape and proved
/// inside a block of another is refused by CS-1's name at the builder, the
/// prover's entry, the verifier's entry and the run statement; at a shape
/// whose `Dom::F` pads, an activation table with `act[128] != 0` is refused
/// by S38-F1(a)'s name (where `Dom::F` does not pad it is admitted).
#[test]
fn cs1_and_s38_f1a_the_feed_forward_statement_is_checked_against_the_shape_it_is_proved_at() {
    // S38-F1(a)
    let rung = Shape::rung();
    assert!(rung.pads(Dom::F), "the fixture shape must pad its feed-forward domain");
    let (_, ff, _) = super::grow_tests::tame_case(&rung);
    let mut act = ff.act.to_vec();
    assert_eq!(act[128], 0, "the frozen SiLU member has act[128] = 0");
    act[128] = 1;
    let e = FeedForwardPublic::new_shaped(&rung, &ff.gamma_m, &ff.wg_t, &ff.wu_t, &ff.wd_t, &act).err().expect("act[128] = 1 admitted where F pads");
    assert!(e.contains("S38-F1(a)"), "{e}");
    let toy = Shape::toy();
    assert!(!toy.pads(Dom::F));
    let (_, tff, _) = super::grow_tests::tame_case(&toy);
    let mut tact = tff.act.to_vec();
    tact[128] = 1;
    FeedForwardPublic::new_shaped(&toy, &tff.gamma_m, &tff.wg_t, &tff.wu_t, &tff.wd_t, &tact).expect("admitted where F does not pad");
    // CS-1: rung-P2's feed-forward half inside a rung-K4 block
    let (k4, p2) = (Shape::rung_k4(), Shape::rung_p2());
    let (att, _, input) = super::grow_tests::tame_case(&k4);
    let (_, ff_p2, _) = super::dense_tests::dense_case(&p2);
    let blk = BlockPublic::new(att.clone(), ff_p2.clone());
    let e = blk.check_for_shape(&k4).err().expect("a rung-P2 feed-forward half fits rung-K4");
    assert!(e.contains("ruling CS-1"), "{e}");
    let e = witness::build_shaped(&k4, &att, &ff_p2, &input).err().expect("the builder admitted the cross-shape half");
    assert!(e.contains("ruling CS-1"), "{e}");
    // the prover's entry, on an honest k4 witness handed with the foreign block
    let (honest, w) = tame(&k4);
    let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&k4, ctx(), 0, 0).unwrap(), &plane(&k4, &w, A_X), &plane(&k4, &w, A_X2)).unwrap();
    let e = super::protocol::prove_inner_at(&k4, &blk, w, &expected, owners).err().expect("the prover admitted the cross-shape half");
    assert!(e.contains("ruling CS-1"), "{e}");
    let e = verify_bytes_at(&k4, &blk, &expected, &[0u8; 64]).err().unwrap();
    assert!(e.contains("ruling CS-1"), "{e}");
    let e = RunStatement::new(RunShape::rung_k4(1).unwrap(), ctx(), expected.clone(), &[blk], &[(0, 0)]).err().unwrap();
    assert!(e.contains("private run: block 0") && e.contains("ruling CS-1"), "{e}");
    honest.check_for_shape(&k4).expect("the control fits");
}

// ------------------------------------------------------------------ CS-3

/// **CS-3.** A witness that looks up a value off its table is refused by the
/// honest prover, by name and by table FAMILY (never a count); the cheating
/// prover (the test-only switch) still reaches the verifier, which rejects.
#[test]
fn cs3_a_lookup_miss_is_refused_by_the_honest_prover_and_rejected_by_the_verifier() {
    let toy = Shape::toy();
    let (public, input) = AttentionPublic::synthetic_fixture();
    let ff = FeedForwardPublic::synthetic_fixture();
    let blk = BlockPublic::new(public.clone(), ff.clone());
    let ids = Ids::new(&toy).unwrap();
    for (name, p, family) in [("a byte limb at 300", A_XL0, "the byte table"), ("an exp word off its row", A_E, "the exp table"), ("an activation word off its row", A_A16, "the activation table")] {
        let mk = || {
            let mut w = witness::build(&public, &ff, &input).unwrap();
            let idx = ids.at(p);
            w.planes[idx][0] = if p == A_XL0 { 300 } else { w.planes[idx][0] + 1 };
            w
        };
        let w = mk();
        let (expected, owners) = prepare_endpoints(IoSpec::new(ctx(), 0, 0).unwrap(), &plane(&toy, &w, A_X), &plane(&toy, &w, A_X2)).unwrap();
        let e = super::protocol::prove_inner_at(&toy, &blk, w, &expected, owners).err().unwrap_or_else(|| panic!("{name}: the honest prover proved a lookup miss"));
        let w = mk();
        assert!(e.contains("ruling CS-3") && e.contains(family), "{name}: {e}");
        // the cheating prover reaches the verifier, which rejects
        let _cheat = super::protocol::CheatingProver::on();
        let (expected, owners) = prepare_endpoints(IoSpec::new(ctx(), 0, 0).unwrap(), &plane(&toy, &w, A_X), &plane(&toy, &w, A_X2)).unwrap();
        match super::protocol::prove_inner_at(&toy, &blk, w, &expected, owners) {
            Ok((r, _)) => {
                let bytes = r.to_bytes_at(&toy, &blk, &expected).unwrap();
                assert!(verify_bytes_at(&toy, &blk, &expected, &bytes).is_err(), "{name}: the verifier ACCEPTED the cheating prover's lookup miss");
            }
            Err(e) => assert!(!e.contains("ruling CS-3"), "{name}: the cheating prover ran CS-3: {e}"),
        }
    }
}

// ------------------------------------------------------------------ CS-4

/// **CS-4.** An attention half or an endpoint policy made for another shape
/// is refused by CS-4's name wherever it meets the shape it is proved at.
#[test]
fn cs4_an_attention_half_or_a_policy_from_another_shape_is_refused() {
    let (g, k4) = (Shape::rung_g(), Shape::rung_k4());
    let (att_g, _, _) = super::dense_tests::dense_case(&g);
    let (_, ff_k4, input) = super::grow_tests::tame_case(&k4);
    let blk = BlockPublic::new(att_g.clone(), ff_k4.clone());
    let e = blk.check_for_shape(&k4).err().expect("a rung-G attention half fits rung-K4");
    assert!(e.contains("ruling CS-4"), "{e}");
    let e = witness::build_shaped(&k4, &att_g, &ff_k4, &input).err().expect("the builder admitted it");
    assert!(e.contains("ruling CS-4"), "{e}");
    // the policy: rung-G's spec at rung-K4
    let spec_g = IoSpec::new_shaped(&g, ctx(), 0, 0).unwrap();
    let e = spec_g.check_for_shape(&k4).err().expect("rung-G's policy fits rung-K4");
    assert!(e.contains("ruling CS-4") && e.contains("endpoint policy"), "{e}");
    let (honest, w) = tame(&k4);
    let (expected_g, owners) = prepare_endpoints(spec_g, &plane(&k4, &w, A_X), &plane(&k4, &w, A_X2)).unwrap();
    let e = super::protocol::prove_inner_at(&k4, &honest, w, &expected_g, owners).err().expect("the prover admitted another shape's policy");
    assert!(e.contains("ruling CS-4"), "{e}");
    let e = RunStatement::new(RunShape::rung_k4(1).unwrap(), ctx(), expected_g, &[honest], &[(0, 0)]).err().unwrap();
    assert!(e.contains("ruling CS-4"), "{e}");
}

// ------------------------------------------------------------------ CS-6

/// a one-block run's witness source that counts what it is asked for
struct Counting {
    w: Option<Witness>,
    asked: usize,
}

impl RunWitnessSource for Counting {
    fn witness(&mut self, _k: usize) -> Result<Witness, String> {
        self.asked += 1;
        self.w.take().ok_or_else(|| "consumed".to_string())
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        self.asked += 1;
        Err("a one-block run has no boundary".into())
    }
}

/// **CS-6.** A run is about the blocks its statement NAMES: the run prover,
/// the in-memory verifier and the streaming verifier refuse, by name and
/// before anything is absorbed (0 witnesses asked, 0 segments sunk, no file
/// read), a block other than the statement's, and the wrong COUNT both ways;
/// the statement's own block proves and verifies.
#[test]
fn cs6_the_run_prover_and_verifiers_refuse_blocks_that_are_not_the_statements() {
    let g = Shape::rung_g();
    let (x, w) = tame(&g);
    let (pd, fd, _) = super::dense_tests::dense_case(&g);
    let y = BlockPublic::new(pd, fd);
    assert_ne!(x.digest(), y.digest());
    let spec = IoSpec::new_shaped(&g, ctx(), 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &plane(&g, &w, A_X), &plane(&g, &w, A_X2)).unwrap();
    let st = RunStatement::new(RunShape::rung_g(1).unwrap(), ctx(), expected.clone(), &[x.clone()], &[(0, 0)]).unwrap();
    // the prover handed Y under a statement over X
    let mut src = Counting { w: None, asked: 0 };
    let mut sunk = 0usize;
    let e = run::prove_run(&st, &[y.clone()], &mut src, owners, &mut |_, _| {
        sunk += 1;
        Ok(())
    })
    .err()
    .expect("the run prover proved a block the statement does not name");
    assert!(e.contains("ruling CS-6") && e.contains("block 0"), "{e}");
    assert_eq!((src.asked, sunk), (0, 0), "something was asked or sunk before the refusal");
    // the count, both ways
    let (_, owners) = prepare_endpoints(IoSpec::new_shaped(&g, ctx(), 0, 0).unwrap(), &plane(&g, &w, A_X), &plane(&g, &w, A_X2)).unwrap();
    let e = run::prove_run(&st, &[x.clone(), x.clone()], &mut Counting { w: None, asked: 0 }, owners, &mut |_, _| Ok(())).err().unwrap();
    assert!(e.contains("ruling CS-6") && e.contains("2 public statements"), "{e}");
    assert!(run::verify_run(&st, &[], &[]).err().unwrap().contains("ruling CS-6"));
    // the verifiers handed Y: refused before a byte of the receipt is looked at
    let e = run::verify_run(&st, &[y.clone()], &[vec![0u8; 64]]).err().unwrap();
    assert!(e.contains("ruling CS-6"), "{e}");
    let nowhere = std::env::temp_dir().join(format!("cs6-no-such-dir-{}", std::process::id()));
    let e = run::verify_run_from_dir(&st, &[y], &nowhere).err().unwrap();
    assert!(e.contains("ruling CS-6"), "{e}: the streaming verifier read the directory first");
    // the control: the statement's own block
    let (_, owners) = prepare_endpoints(IoSpec::new_shaped(&g, ctx(), 0, 0).unwrap(), &plane(&g, &w, A_X), &plane(&g, &w, A_X2)).unwrap();
    let mut segs = Vec::new();
    run::prove_run(&st, &[x.clone()], &mut Counting { w: Some(w), asked: 0 }, owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the statement's own block proves");
    run::verify_run(&st, &[x], &segs).expect("and verifies");
}

// ------------------------------------------------------------------ CS-7

/// **CS-7.** A run profile names exactly one block shape: every registered
/// pair constructs, every cross pair and an unregistered profile are refused
/// by name (the trained profiles: their geometry at the shape's own
/// calibration, through the door).
#[test]
fn cs7_a_run_profile_names_exactly_one_block_shape() {
    use super::run::*;
    let frozen = [
        (RUN_PROFILE_RUNG_G, Shape::rung_g()),
        (RUN_PROFILE_RUNG_K4, Shape::rung_k4()),
        (RUN_PROFILE_RUNG_P2, Shape::rung_p2()),
        (RUN_PROFILE_RUNG_C6, Shape::rung_c6()),
        (RUN_PROFILE_RUNG_W14, Shape::rung_w14()),
        (RUN_PROFILE_RUNG_E32, Shape::rung_e32()),
        (RUN_PROFILE_M125, Shape::m125()),
    ];
    let mut others: Vec<Shape> = frozen.iter().map(|(_, s)| s.clone()).collect();
    others.push(Shape::toy());
    others.push(Shape::rung());
    let mut refused = 0usize;
    for (p, sh) in &frozen {
        for l in [1usize, 3] {
            RunShape::new(sh.clone(), l, *p).unwrap_or_else(|e| panic!("{p} over its own shape: {e}"));
        }
        for o in &others {
            if o == sh {
                continue;
            }
            let e = RunShape::new(o.clone(), 1, *p).err().unwrap_or_else(|| panic!("{p} admitted {}", o.name));
            assert!(e.contains("ruling CS-7"), "{e}");
            refused += 1;
        }
    }
    assert_eq!(refused, 7 * 8);
    let e = RunShape::new(Shape::rung_g(), 1, "hashline-zk-mr1/private-run-not-registered/1").err().unwrap();
    assert!(e.contains("ruling CS-7") && e.contains("not a run profile this build registers"), "{e}");
    // the trained profiles
    let tc = Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap();
    RunShape::new(tc.clone(), 1, RUN_PROFILE_RUNG_TC).expect("the trained rung's own pair");
    assert!(RunShape::new(Shape::rung_c6(), 1, RUN_PROFILE_RUNG_TC).err().unwrap().contains("ruling CS-7"));
    assert!(RunShape::new(tc, 1, RUN_PROFILE_RUNG_C6).err().unwrap().contains("ruling CS-7"));
    let (t32, t64) = (super::trained_calib_tests::tinyllama_at(32), super::trained_calib_tests::tinyllama_at(64));
    RunShape::new(t32.clone(), 22, RUN_PROFILE_TINYLLAMA_T32_TRAINED).expect("T32's own pair");
    assert!(RunShape::new(t64, 1, RUN_PROFILE_TINYLLAMA_T32_TRAINED).err().unwrap().contains("ruling CS-7"));
    let mut edited = t32;
    edited.d_max += 1;
    assert!(RunShape::new(edited, 1, RUN_PROFILE_TINYLLAMA_T32_TRAINED).err().unwrap().contains("ruling CS-7"));
}

// ------------------------------------------------------------------ CS-8

/// **CS-8.** A shape, a layout or an endpoint policy whose fields were
/// WRITTEN after its constructor is refused by name at the entries.
#[test]
fn cs8_written_fields_are_refused_at_the_entries() {
    let g = Shape::rung_g();
    g.check_constructed().expect("a constructed shape");
    let mut w30 = g.clone();
    w30.norm_wrho = 30;
    assert!(w30.check_constructed().err().unwrap().contains("ruling CS-8"));
    let mut q128 = g.clone();
    q128.opened_cols = 128;
    assert!(q128.check_constructed().err().unwrap().contains("ruling CS-8"));
    let (blk, w) = tame(&g);
    let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&g, ctx(), 0, 0).unwrap(), &plane(&g, &w, A_X), &plane(&g, &w, A_X2)).unwrap();
    assert!(super::protocol::prove_inner_at(&w30, &blk, w, &expected, owners).err().unwrap().contains("ruling CS-8"));
    assert!(verify_bytes_at(&w30, &blk, &expected, &[0u8; 64]).err().unwrap().contains("ruling CS-8"));
    // a trained shape: a field the door derives, written
    let mut tc = Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap();
    tc.check_constructed().expect("the door's shape");
    tc.d_max += 1;
    assert!(tc.check_constructed().err().unwrap().contains("ruling CS-8"));
    let mut tq = Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap();
    tq.sh_qkv = 9;
    assert!(tq.check_constructed().err().unwrap().contains("ruling CS-8"));
    // the layout
    let lay = Layout::for_shape(&g).unwrap();
    lay.check_is_for_shape(&g).expect("its own layout");
    let mut swapped = Layout::for_shape(&g).unwrap();
    swapped.a_off.swap(0, 1);
    assert!(swapped.check_is_for_shape(&g).err().unwrap().contains("ruling CS-8"));
    assert!(Layout::for_shape(&Shape::toy()).unwrap().check_is_for_shape(&g).err().unwrap().contains("ruling CS-8"));
    // the policy's pinned scales
    let mut spec = IoSpec::new_shaped(&g, ctx(), 0, 0).unwrap();
    spec.input_scale = 3;
    assert!(spec.check_for_shape(&g).err().unwrap().contains("ruling CS-8"));
    assert!(spec.validate().err().unwrap().contains("ruling CS-8"));
}

// ------------------------------------------------------------------ CS-9

/// **CS-9.** A block profile string names exactly one shape: a registered
/// string with another geometry is refused by `Shape::new`; every registered
/// shape (the trained ones included) is one `Shape::new` builds; a value
/// whose profile was written is refused at the entries; an unregistered
/// string is refused outside test builds.
#[test]
fn cs9_a_block_profile_string_names_exactly_one_shape() {
    let g = Shape::rung_g();
    let e = Shape::new(g.name, TOY_PROFILE, g.tokens, g.width, g.hidden, g.q_heads, g.head_dim, g.kv_heads, g.log_cols, g.inv_rate, g.f_e, g.endpoint_rows, Some(g.endpoint_log_n), Some(g.endpoint_inv_rate), Some(g.norm_wrho), Some(g.wrho_s)).err().expect("the toy's string at rung-G's geometry");
    assert!(e.contains("ruling CS-9"), "{e}");
    let cal = super::trained_calib_tests::t3_calibration();
    let registered = [
        Shape::toy(),
        Shape::rung(),
        Shape::rung_g(),
        Shape::rung_k4(),
        Shape::rung_p2(),
        Shape::rung_c6(),
        Shape::rung_w14(),
        Shape::rung_e32(),
        Shape::m125(),
        Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).unwrap(),
        Shape::tinyllama_trained(32, &cal, 9).unwrap(),
        Shape::tinyllama_trained(64, &cal, 12).unwrap(),
        Shape::tinyllama_trained(128, &cal, 16).unwrap(),
        super::trained_calib_tests::llama3_8b(),
    ];
    for sh in &registered {
        sh.check_constructed().unwrap_or_else(|e| panic!("{}: {e}", sh.name));
        // the registry check itself compares a shape BEFORE the trained door
        // (`Shape::new`); a door-built shape is checked through
        // `check_constructed`, which rebuilds it through `Shape::new`
        if !sh.trained_calibration {
            sh.check_block_profile_as_a_release_build().unwrap_or_else(|e| panic!("{}: {e}", sh.name));
        }
    }
    let mut written = Shape::rung_g();
    written.profile = TOY_PROFILE;
    let e = written.check_constructed().err().unwrap();
    assert!(e.contains("ruling CS-8") && e.contains("ruling CS-9"), "{e}");
    let probe = Shape::new("probe", "unregistered-probe/1", 32, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None).expect("a test build admits an unregistered probe");
    let e = probe.check_block_profile_as_a_release_build().err().unwrap();
    assert!(e.contains("ruling CS-9") && e.contains("not a block profile this build registers"), "{e}");
    // a trained profile string over another geometry
    let t64 = Shape::tinyllama_trained(64, &cal, 9).unwrap();
    let e = Shape::new(t64.name, super::shape::TINYLLAMA_T32_TRAINED_PROFILE, t64.tokens, t64.width, t64.hidden, t64.q_heads, t64.head_dim, t64.kv_heads, t64.log_cols, t64.inv_rate, t64.f_e, t64.endpoint_rows, None, None, None, None).err().unwrap();
    assert!(e.contains("ruling CS-9"), "{e}");
    let _ = NormCalibration::FROZEN;
}

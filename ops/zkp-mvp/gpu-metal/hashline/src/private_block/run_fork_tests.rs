//! **D55 PROTOTYPE TESTS (2026-11-01).** TEST CODE ONLY.
//!
//! At the cheapest run shape that already has a run test — native R13's h24
//! development rung (`R13_RUNG_H24`, T32, width 384), from Sol's public
//! synthetic loader fixture `r13-h24-wide`, as D12a's
//! `accuracy_two_stage_private_boundary_with_different_gate_shifts_verifies`
//! builds it (`HL_R13_LOADER_FIXTURES`, or the native tree's sibling
//! `loader-fixtures/`) — three stages that alternate layer 0's block and its
//! other-gate twin:
//!
//! * honest fork runs verify at every worker count, with the verifier's forks
//!   on one thread and on three; a changed byte in the head, a fork or the
//!   tail is refused;
//! * D12a's run on the same statement still proves and verifies; the fork
//!   profile is another transcript (binding, parameter line), CS-7 does not
//!   register it, and neither receipt verifies under the other profile;
//! * the four malicious-receipt controls the ruling names (a fork-index swap,
//!   a stale fork state, a boundary root absorbed after a fork, a claim raised
//!   on a fork but not joined) are each REJECTED, first with the cheater's own
//!   position tags and then with forged honest tags (so the rejection comes
//!   from the Fiat-Shamir chain itself); a claim neither joined nor opened is
//!   refused by the prover's own boundary audit.
//!
//! The `#[ignore]`d `d55_ab_one_request_serial_against_forks` is the A/B: one
//! request, W16 8B T128 at its true geometry with synthetic (diagonal) public
//! weights, a `HL_D55_L`-block run (default 32), D12a serial against the fork
//! run at `HL_D55_WORKERS` (default 1,2,4,6). Run it guarded, alone, with
//! `HL_GPU=1 HL_PB_ORACLE=0` and never with `HL_METAL_TIMING=1`.

use super::*;
use crate::private_block::accuracy_public::AccuracyPublic;
use crate::private_block::layout::{Ids, A_X};
use crate::private_block::run::{self as run, RunShape, RunStatement, RunWitnessSource};
use crate::private_block::trained_block::TrainedExport;
use crate::private_block::trained_statement::{IntegerCalibration, LayerRecord, ModelSource, Provenance, SourceKind, TrainedModelStatement};
use crate::private_block::witness::{self, Witness};
use crate::private_block::{prepare_endpoints, BlockPublic, Endpoints, IoSpec};
use std::path::PathBuf;
use std::time::Instant;

fn fixtures() -> PathBuf {
    std::env::var_os("HL_R13_LOADER_FIXTURES").map(PathBuf::from).unwrap_or_else(|| std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures"))
}

/// the run's private inputs, built before the run (the sealing pass): every
/// witness and every padded boundary plane
struct Chain {
    witnesses: Vec<Option<Witness>>,
    planes: Vec<Vec<i16>>,
}

impl RunWitnessSource for Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.witnesses.get_mut(k).and_then(Option::take).ok_or_else(|| format!("witness {k} was consumed"))
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.planes.get(k).cloned().ok_or_else(|| format!("no boundary {k}"))
    }
}

/// a padded `[t_pad, d_pad]` plane's true `[T, width]` words
fn unpad(sh: &crate::private_block::shape::Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect()
}

struct Rung {
    st: RunStatement,
    blocks: Vec<BlockPublic>,
    src: Chain,
    owners: Option<Endpoints>,
}

/// An `l`-stage run at the R13 h24 rung: stage 0 is the fixture's layer 0,
/// odd stages its other-gate twin (`(-4, -13)`, as the D12a two-stage test),
/// even stages layer 0's block again; the witness chain is built honestly
/// from the fixture's public sequence.
fn rung(l: usize, context: u8) -> Rung {
    let path = fixtures().join("r13-h24-wide");
    assert!(path.join("profile.json").exists(), "the R13 loader fixture {} is missing: set HL_R13_LOADER_FIXTURES (results/zk60_1b_native_20261017/r13/loader-fixtures)", path.display());
    let mut ex = TrainedExport::load(&path).unwrap();
    ex.accuracy_dd = false;
    ex.source.checkpoint_layers = l as u32;
    let c = ex.run_constants(&[0]).unwrap();
    let seed = ex.shape_for(&c).unwrap();
    let first = ex.load_layer(&seed, &c, 0, false).unwrap();
    let a = first.blk.accuracy().unwrap();
    let changed = AccuracyPublic::new(a.stack(), a.geometry(), a.base(), (-4, -13), a.multipliers().clone(), a.groups().to_vec(), a.group_ids().to_vec(), a.raw_tables().to_vec()).unwrap();
    let twin = first.blk.clone().with_accuracy(changed);
    let (mut blocks, mut records) = (Vec::with_capacity(l), Vec::with_capacity(l));
    for k in 0..l {
        if k == 0 {
            blocks.push(first.blk.clone());
            records.push(first.record.clone());
            continue;
        }
        let b = if k % 2 == 1 { twin.clone() } else { first.blk.clone() };
        let mut r = LayerRecord::of_block(k as u32, &b, vec![]);
        r.manifest_sha256 = [52 + k as u8; 32];
        records.push(r);
        blocks.push(b);
    }
    let shapes: Vec<_> = records.iter().map(|r| r.shape_at(&seed).unwrap()).collect();
    let (mut x, _) = ex.load_seq(&shapes[0], "public", 0).unwrap();
    let ids = Ids::new(&seed).unwrap();
    let (mut witnesses, mut planes, mut input, mut output) = (Vec::new(), Vec::new(), Vec::new(), Vec::new());
    for k in 0..l {
        let w = witness::build_for_block(&shapes[k], &blocks[k], &x).unwrap_or_else(|e| panic!("stage {k} of the R13 rung chain is not admissible: {e}"));
        if k == 0 {
            input = w.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect();
        }
        let out = w.output().unwrap();
        x = unpad(&seed, &out);
        if k + 1 < l {
            planes.push(out);
        } else {
            output = out;
        }
        witnesses.push(Some(w));
    }
    let model = ex.statement_of_records(&seed, &c, records).unwrap();
    let ctx = [context; 32];
    let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&seed, ctx, 0, 0).unwrap(), &input, &output).unwrap();
    let st = RunStatement::new_bound(RunShape::accuracy(seed, l).unwrap(), ctx, expected, &blocks, &vec![(0, 0); l], &model).unwrap();
    Rung { st, blocks, src: Chain { witnesses, planes }, owners: Some(owners) }
}

fn prove_forks(r: &mut Rung, workers: usize) -> (ForkReceipt, ForkStats) {
    let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
    prove_run_with_forks(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), workers, ForkRandomness::Os).expect("the honest D55 fork run proves")
}

fn flipped(v: &[u8]) -> Vec<u8> {
    let mut b = v.to_vec();
    let mid = b.len() / 2;
    b[mid] ^= 1;
    b
}

// ------------------------------------------------------------------ honest runs

/// **Honest fork runs verify**, at two and three stages, at every worker
/// count, with the verifier's forks serial and parallel; a changed byte in
/// the head, in a fork frame or in the tail is refused.
#[test]
fn d55_honest_fork_runs_verify_at_every_worker_count() {
    for (l, workers) in [(2usize, 2usize), (3, 1), (3, 2), (3, 3)] {
        let mut r = rung(l, 70 + (10 * l + workers) as u8);
        let (rc, stats) = prove_forks(&mut r, workers);
        let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
        for vw in [1usize, 3] {
            verify_run_with_forks(&fr, &r.blocks, &rc, vw).unwrap_or_else(|e| panic!("L{l} workers {workers}: the honest D55 fork run does not verify (verifier threads {vw}): {e}"));
        }
        assert_eq!(rc.head.len(), super::super::super::wire::fork::head_len(l));
        let mut refusals = Vec::new();
        let bad_head = ForkReceipt { head: flipped(&rc.head), ..rc.clone() };
        let mut bad_fork = rc.clone();
        bad_fork.forks[l - 1] = flipped(&rc.forks[l - 1]);
        let bad_tail = ForkReceipt { tail: flipped(&rc.tail), ..rc.clone() };
        for (what, bad) in [("head", bad_head), ("last fork", bad_fork), ("tail", bad_tail)] {
            let e = verify_run_with_forks(&fr, &r.blocks, &bad, 3).err().unwrap_or_else(|| panic!("L{l}: A CHANGED BYTE IN THE {what} VERIFIED"));
            refusals.push(format!("{what}: {}", e.chars().take(90).collect::<String>()));
        }
        eprintln!(
            "D55 | honest | L{l} workers {workers}: {} B (head {} B, forks {:?} B, tail {} B); preflight {:.2} s, commit {:.2} s, forks {:.2} s (core {:?}), join {:.2} s; verifies with 1 and 3 verifier threads; changed bytes refused ({})",
            rc.bytes(),
            rc.head.len(),
            rc.forks.iter().map(Vec::len).collect::<Vec<_>>(),
            rc.tail.len(),
            stats.preflight_s,
            stats.commit_s,
            stats.forks_s,
            stats.fork_core_s.iter().map(|s| format!("{s:.2}")).collect::<Vec<_>>(),
            stats.join_s,
            refusals.join("; ")
        );
    }
}

// ------------------------------------------------------------------ D12a and the profile boundary

/// **D12a is untouched, and the two profiles do not cross.** The D12a run on
/// the same rung statement proves and verifies as before; the fork profile of
/// that statement has another binding and another parameter line, CS-7
/// refuses its string, and neither receipt verifies under the other profile.
#[test]
fn d55_the_d12a_run_is_unchanged_and_the_two_profiles_do_not_cross() {
    let mut a = rung(3, 81);
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(&a.st, &a.blocks, &mut a.src, a.owners.take().unwrap(), &mut |k, b| {
        assert_eq!(k, segs.len());
        segs.push(b);
        Ok(())
    })
    .expect("the D12a run proves");
    run::verify_run(&a.st, &a.blocks, &segs).expect("the D12a run verifies");
    let fra = ForkRun::new(&a.st, D55OptIn::unreviewed_prototype()).unwrap();
    eprintln!("D55 | census | {}", fra.census().unwrap());
    assert_ne!(fra.binding().unwrap(), a.st.binding().unwrap(), "the fork profile shares D12a's run binding");
    let (pl_a, pl_f) = (a.st.parameter_line().unwrap(), fra.parameter_line().unwrap());
    assert!(pl_a.ends_with("/one-run-one-transcript") && pl_f.ends_with("/d55-commit-fork-join-prototype-unregistered"), "{pl_a} / {pl_f}");
    assert_eq!(pl_a.strip_suffix("/one-run-one-transcript"), pl_f.strip_suffix("/d55-commit-fork-join-prototype-unregistered"), "the fork line moved more than its construction clause");
    // the fork string is no run profile CS-7 registers
    let leaked: &'static str = Box::leak(fra.profile().to_string().into_boxed_str());
    let e = RunShape::new(a.st.rs().sh().clone(), 3, leaked).err().expect("THE D55 FORK PROFILE IS A REGISTERED RUN PROFILE");
    assert!(e.contains("CS-7"), "{e}");
    // a fork receipt is not a D12a receipt, and D12a segments are not forks
    let mut b = rung(3, 82);
    let (rc, _) = prove_forks(&mut b, 3);
    let e1 = run::verify_run(&b.st, &b.blocks, &rc.forks).err().expect("D55 FORK FRAMES VERIFIED AS D12a SEGMENTS");
    let frb = ForkRun::new(&b.st, D55OptIn::unreviewed_prototype()).unwrap();
    let e2 = verify_run_with_forks(&frb, &b.blocks, &ForkReceipt { forks: segs.clone(), ..rc.clone() }, 3).err().expect("D12a SEGMENTS VERIFIED AS D55 FORKS");
    verify_run_with_forks(&frb, &b.blocks, &rc, 3).expect("the fork receipt itself verifies");
    eprintln!("D55 | profiles | D12a L3 proves and verifies ({} B); fork binding and line differ; CS-7: {}; fork frames as D12a segments: {e1}; D12a segments as forks: {e2}", segs.iter().map(Vec::len).sum::<usize>(), e.chars().take(80).collect::<String>());
}

// ------------------------------------------------------------------ the four controls

/// a cheating prover's complete receipt, verified by the honest verifier;
/// returns the rejection
fn control(t: ForkTamper, forge: bool, context: u8) -> String {
    let mut r = rung(3, context);
    let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
    let (rc, _) = prove_run_with_forks_tampered(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), 3, t, forge).unwrap_or_else(|e| panic!("the cheating prover ({t:?}) did not make a receipt: {e}"));
    let e = verify_run_with_forks(&fr, &r.blocks, &rc, 3).err().unwrap_or_else(|| panic!("THE D55 CONTROL {t:?} (forged tags: {forge}) VERIFIED"));
    eprintln!("D55 CONTROL | {t:?} | forged tags {forge} | REJECTED: {e}");
    e
}

/// the forged-tag variant must be refused by the chain, not by a tag compare
fn not_a_tag_refusal(t: ForkTamper, e: &str) {
    assert!(!e.contains(" tag "), "{t:?} with forged tags was refused only by a position-tag comparison: {e}");
}

/// **Control 1: a fork-index swap.** Blocks 0 and 1 are each proved on the
/// other's fork (index and block digest) and emitted at their own positions.
#[test]
fn d55_control_a_fork_index_swap_is_rejected() {
    let t = ForkTamper::ForkIndexSwap { a: 0, b: 1 };
    let e = control(t, false, 101);
    assert!(e.contains("fork 0") && e.contains("start tag"), "{e}");
    let t = ForkTamper::ForkIndexSwap { a: 1, b: 2 };
    let e = control(t, true, 102);
    assert!(e.contains("fork 1"), "{e}");
    not_a_tag_refusal(t, &e);
}

/// **Control 2: a stale fork state.** The join absorbs fork 1's START state,
/// which binds none of its messages.
#[test]
fn d55_control_a_stale_fork_state_is_rejected() {
    let t = ForkTamper::StaleForkState { block: 1 };
    let e = control(t, false, 103);
    assert!(e.contains("S1 tag"), "{e}");
    let e = control(t, true, 104);
    assert!(e.contains("boundary 0"), "{e}");
    not_a_tag_refusal(t, &e);
}

/// **Control 3: a boundary root absorbed after a fork.** `B_1`'s root is left
/// out of `S0` and absorbed at the join, after every fork's challenges.
#[test]
fn d55_control_a_boundary_root_absorbed_after_a_fork_is_rejected() {
    let t = ForkTamper::RootAfterFork { boundary: 1 };
    let e = control(t, false, 105);
    assert!(e.contains("S0 tag"), "{e}");
    let e = control(t, true, 106);
    assert!(e.contains("fork 0"), "{e}");
    not_a_tag_refusal(t, &e);
}

/// **Control 4: a claim raised on a fork but not joined.** Fork 1's slot-22
/// claims (on `B_1`) are opened but left out of the join; and, as a second
/// case, a cheater that also leaves them out of `B_0`'s opening is refused by
/// its own boundary audit before any receipt exists.
#[test]
fn d55_control_a_claim_raised_on_a_fork_but_not_joined_is_rejected() {
    let t = ForkTamper::ClaimNotJoined { block: 1 };
    let e = control(t, false, 107);
    assert!(e.contains("S1 tag"), "{e}");
    let e = control(t, true, 108);
    assert!(e.contains("boundary 0"), "{e}");
    not_a_tag_refusal(t, &e);
    // neither joined nor opened: the one opening of B_0 is audited for both sites
    let mut r = rung(3, 109);
    let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
    let t = ForkTamper::ClaimNotJoinedNorOpened { block: 0 };
    let e = prove_run_with_forks_tampered(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), 3, t, true).err().expect("A BOUNDARY WAS OPENED WITHOUT ONE OF ITS TWO CLAIM SITES");
    assert!(e.contains("boundary 0"), "{e}");
    eprintln!("D55 CONTROL | {t:?} | REFUSED BY THE PROVER'S OWN AUDIT: {e}");
}

/// a receipt's frames swapped in place (a reordering, not a cheating prover)
#[test]
fn d55_swapped_fork_frames_are_rejected() {
    let mut r = rung(3, 110);
    let (mut rc, _) = prove_forks(&mut r, 3);
    rc.forks.swap(0, 1);
    let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
    let e = verify_run_with_forks(&fr, &r.blocks, &rc, 3).err().expect("SWAPPED FORK FRAMES VERIFIED");
    assert!(e.contains("fork 0"), "{e}");
    eprintln!("D55 | swapped frames | REJECTED: {e}");
}

// ------------------------------------------------------------------ the A/B

fn env_or<T: std::str::FromStr>(name: &str, default: T) -> T {
    std::env::var(name).ok().and_then(|v| v.parse().ok()).unwrap_or(default)
}

/// **THE D55 A/B ON ONE REQUEST** (`#[ignore]`d; run guarded, alone): a W16
/// 8B T128 stack of `HL_D55_L` layers (default 32) at its true geometry, ONE
/// public synthetic block (M10's recipe: `range16_tests::case`, diagonal
/// weights) at every layer, an honest witness chain from M10's admissible
/// input; D12a serial (`run::prove_run_with`) against the fork run at each
/// `HL_D55_WORKERS` (default 1,2,4,6), `HL_D55_PASSES` warm passes each
/// (default 2) after one cold serial pass, interleaved. Every witness is
/// built BEFORE the timed call (the sealing pass), so both arms time the same
/// thing: the prove call, statement checks to last byte. The first warm pass
/// of every arm is verified. Proved tokens/s per request = T / wall.
#[test]
#[ignore = "heavy: W16 8B T128 32-block runs; guarded, alone, HL_GPU=1 HL_PB_ORACLE=0"]
fn d55_ab_one_request_serial_against_forks() {
    use crate::private_block::shape;
    let name: String = env_or("HL_D55_PROFILE", "W16_8B_T128_H24".to_string());
    let spec = shape::W16_PROFILES.iter().find(|s| s.name == name).expect("a W16 profile name");
    let l: usize = env_or("HL_D55_L", 32usize);
    let workers: Vec<usize> = std::env::var("HL_D55_WORKERS").unwrap_or_else(|_| "1,2,4,6".into()).split(',').filter_map(|v| v.trim().parse().ok()).collect();
    let passes: usize = env_or("HL_D55_PASSES", 2usize).max(1);
    let builders: usize = env_or("HL_D55_BUILDERS", 8usize).max(1);
    let t0 = Instant::now();
    let original = crate::private_block::range16_tests::built(spec.profile);
    let (sh, data, public, ff) = crate::private_block::range16_tests::case(original, 3);
    let blk = BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
    let build = |x: &[i16]| witness::build_accuracy(&sh, &public, &ff, &data, x);
    // M10's admissible input, then the honest chain through every layer
    let mut s = 0usize;
    let x0 = loop {
        let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + s) % (41 + 20 * (s % 3))) as i16 - 20).collect();
        match build(&input) {
            Ok(_) => break input,
            Err(_) if s < 6 => s += 1,
            Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
        }
    };
    let ids = Ids::new(&sh).unwrap();
    let (mut xs, mut planes) = (vec![x0], Vec::with_capacity(l));
    let (mut input, mut output, mut witness_bytes) = (Vec::new(), Vec::new(), 0usize);
    for k in 0..l {
        let w = build(&xs[k]).unwrap_or_else(|e| panic!("{}: layer {k} of the synthetic chain is not admissible: {e}", sh.name));
        if k == 0 {
            input = w.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect::<Vec<i16>>();
            witness_bytes = w.planes.iter().map(|p| p.len() * 8).sum();
        }
        let out = w.output().unwrap();
        xs.push(unpad(&sh, &out));
        if k + 1 < l {
            planes.push(out);
        } else {
            output = out;
        }
    }
    let digest = blk.digest();
    let run_profile = crate::private_block::w16_privacy_gate_tests::W16_TEST_RUN_PROFILES.iter().find(|(_, b)| *b == sh.profile).map(|(r, _)| *r).expect("a W16 test-only run identity");
    let mut prov = Provenance::recipe("D55 A/B fixture (public synthetic)", 1.0, [3; 32], [4; 32]);
    prov.rope_theta = shape::trained_rope_theta(sh.profile).expect("a W16 profile's pinned RoPE base");
    prov.rope_scaling = shape::trained_rope_scaling(sh.profile).expect("a W16 profile's pinned RoPE transform");
    let source = ModelSource { kind: SourceKind::PublicSyntheticRecipe, repo: "synthetic/d55-ab".into(), revision: "d55".into(), weights_sha256: [0; 32], config_sha256: [0; 32], checkpoint_parameters: 0, checkpoint_layers: l as u32 };
    let r0 = LayerRecord::of_block(0, &blk, vec![]);
    let records: Vec<LayerRecord> = (0..l)
        .map(|i| {
            let mut r = r0.clone();
            r.index = i as u32;
            r
        })
        .collect();
    let model = TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(&sh, run_profile, source, IntegerCalibration::as_the_code_proves(&sh, &prov), records).unwrap_or_else(|e| panic!("the synthetic {l}-layer statement: {e}"));
    let rep = RepeatBlock::new(&blk, l);
    eprintln!("D55-AB {name} L{l} T{}: setup {:.1} s (one witness {:.2} GB; {l} alive per call)", sh.tokens, t0.elapsed().as_secs_f64(), witness_bytes as f64 / 1e9);
    // every witness of one call, built before the call on `builders` threads
    let witnesses = || -> Chain {
        let next = std::sync::atomic::AtomicUsize::new(0);
        let mut got: Vec<(usize, Witness)> = std::thread::scope(|sc| {
            let hs: Vec<_> = (0..builders.min(l))
                .map(|_| {
                    let (next, xs, build) = (&next, &xs, &build);
                    sc.spawn(move || {
                        let mut mine = Vec::new();
                        loop {
                            let k = next.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
                            if k >= l {
                                break;
                            }
                            mine.push((k, build(&xs[k]).expect("the chain was admissible")));
                        }
                        mine
                    })
                })
                .collect();
            hs.into_iter().flat_map(|h| h.join().expect("a witness builder")).collect()
        });
        got.sort_by_key(|(k, _)| *k);
        Chain { witnesses: got.into_iter().map(|(_, w)| Some(w)).collect(), planes: planes.clone() }
    };
    let statement = |ctx: u8| -> (RunStatement, Endpoints) {
        let c = [ctx; 32];
        let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&sh, c, 0, 0).unwrap(), &input, &output).unwrap();
        let st = RunStatement::new_bound_from_digests(RunShape::new(sh.clone(), l, run_profile).unwrap(), c, expected, vec![digest; l], &vec![(0, 0); l], &model).unwrap();
        (st, owners)
    };
    let tok = |wall: f64| sh.tokens as f64 / wall;
    // arm 0 = D12a serial, arm n = forks on n workers
    let serial = |ctx: u8, verify: bool| -> (f64, usize) {
        let mut src = witnesses();
        let (st, owners) = statement(ctx);
        let mut rep_d12a = RepeatBlock::new(&blk, l);
        let mut segs: Vec<Vec<u8>> = Vec::new();
        let mut bytes = 0usize;
        let t = Instant::now();
        run::prove_run_with(&st, &mut rep_d12a, &mut src, owners, &mut |_, b| {
            bytes += b.len();
            if verify {
                segs.push(b);
            }
            Ok(())
        })
        .expect("the D12a serial run proves");
        let wall = t.elapsed().as_secs_f64();
        if verify {
            let tv = Instant::now();
            run::verify_run_with(&st, &mut rep_d12a, &segs).expect("the D12a serial run verifies");
            eprintln!("D55-AB {name} L{l} serial: verified (D12a verifier, one thread) in {:.2} s", tv.elapsed().as_secs_f64());
        }
        (wall, bytes)
    };
    let forked = |ctx: u8, n: usize, verify: bool| -> (f64, usize, ForkStats) {
        let mut src = witnesses();
        let (st, owners) = statement(ctx);
        let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).unwrap();
        let t = Instant::now();
        let (rc, stats) = prove_run_with_forks(&fr, &rep, &mut src, owners, n, ForkRandomness::Os).expect("the D55 fork run proves");
        let wall = t.elapsed().as_secs_f64();
        if verify {
            let tv = Instant::now();
            verify_run_with_forks(&fr, &rep, &rc, 6).expect("the D55 fork run verifies");
            eprintln!("D55-AB {name} L{l} forks N{n}: verified (D55 verifier, 6 threads) in {:.2} s", tv.elapsed().as_secs_f64());
        }
        (wall, rc.bytes(), stats)
    };
    let (cold, _) = serial(1, false);
    eprintln!("D55-AB {name} L{l} serial cold (kernel compiles): wall {cold:.3} s = {:.2} proved tok/s", tok(cold));
    let mut table: Vec<(String, Vec<f64>)> = std::iter::once(("serial (D12a)".to_string(), Vec::new())).chain(workers.iter().map(|n| (format!("forks N={n}"), Vec::new()))).collect();
    let mut ctx = 2u8;
    for p in 0..passes {
        let (wall, bytes) = serial(ctx, p == 0);
        ctx += 1;
        eprintln!("D55-AB {name} L{l} T{} serial pass {p}: wall {wall:.3} s = {:.2} proved tok/s; receipt {bytes} B", sh.tokens, tok(wall));
        table[0].1.push(wall);
        for (i, &n) in workers.iter().enumerate() {
            let (wall, bytes, st) = forked(ctx, n, p == 0);
            ctx += 1;
            let mut core = st.fork_core_s.clone();
            core.sort_by(|a, b| a.partial_cmp(b).unwrap());
            eprintln!(
                "D55-AB {name} L{l} T{} forks N{n} pass {p}: wall {wall:.3} s = {:.2} proved tok/s; {} workers; preflight {:.3} s, commit {:.3} s, forks {:.3} s, join {:.3} s; fork prove_core min {:.3} median {:.3} max {:.3} s; receipt {bytes} B",
                sh.tokens,
                tok(wall),
                st.workers,
                st.preflight_s,
                st.commit_s,
                st.forks_s,
                st.join_s,
                core[0],
                core[core.len() / 2],
                core[core.len() - 1]
            );
            table[i + 1].1.push(wall);
        }
    }
    let base = table[0].1.iter().cloned().fold(f64::INFINITY, f64::min);
    eprintln!("D55-AB SUMMARY {name} L{l} T{} ({passes} warm passes; best and mean wall; proved tokens/s per request = T / wall):", sh.tokens);
    for (arm, walls) in &table {
        let best = walls.iter().cloned().fold(f64::INFINITY, f64::min);
        let mean = walls.iter().sum::<f64>() / walls.len() as f64;
        eprintln!("D55-AB SUMMARY | {arm:<14} | best {best:.3} s = {:.2} tok/s | mean {mean:.3} s = {:.2} tok/s | {:.2}x serial (best)", tok(best), tok(mean), base / best);
    }
    #[cfg(feature = "gpu-metal")]
    {
        let (compile, rounds) = crate::gpu::metal_sumcheck_stats();
        eprintln!("D55-AB device evidence: HL_GPU={:?}, Metal kernel compile {compile:.3} s, device sumcheck rounds {rounds:.3} s", std::env::var("HL_GPU").ok());
    }
    eprintln!("D55-AB {name} L{l}: total {:.1} s", t0.elapsed().as_secs_f64());
}

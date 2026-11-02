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
//! * **D55 review F2**: a fork-index swap of two forks that carry the SAME
//!   block is rejected, and VERIFIES under the mutation that drops the index
//!   from the derivation — so the index, and nothing else, separates them.
//! * **D55 review F1**: FALSE statements through the fork path, at the rung-G
//!   development run (`L = 3`, D12a's own harness): the headline negative
//!   test at the interior boundary `B_1` (both variants) and all twenty-seven
//!   single-block tamper families on the interior fork, each REJECTED by
//!   `verify_run_with_forks` while the (cheating) prover makes the receipt;
//!   and the F5 control that the CS-3 switch really reaches the fork worker.
//! * **F3 / F4 / F5** in every honest proof's stats: `L + 1` generators, the
//!   calling thread's switches in every fork, the joined claim lists at the
//!   census formula's length.
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
    let (rc, stats) = prove_run_with_forks(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), workers).expect("the honest D55 fork run proves");
    honest_stats_hold(&r.st, &stats);
    (rc, stats)
}

/// What every honest proof's stats must say (D55 review F3, F4, F5): `L + 1`
/// generators; every fork's worker held exactly the calling thread's test
/// switches; every joined claim list is the census formula's length.
fn honest_stats_hold(st: &RunStatement, stats: &ForkStats) {
    let l = st.rs().l();
    assert_eq!(stats.generators, l + 1, "an L{l} fork run did not construct exactly L + 1 generators (F4)");
    let here = ForkHooks::capture();
    assert_eq!(stats.fork_hooks.len(), l, "not every fork reported its switches (F5)");
    assert!(stats.fork_hooks.iter().all(|h| *h == here), "a fork worker did not hold the calling thread's switches (F5): {:?} against {here:?}", stats.fork_hooks);
    let want = io_claim_list_len(st.rs().sh());
    assert!(stats.join_claim_bytes.iter().all(|c| *c == [want, want]), "a joined claim list is not the census formula's {want} bytes (F3): {:?}", stats.join_claim_bytes);
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
    // F3: the fork run's header is D12a's six absorbs under its OWN
    // constructor — rebuilt here from the public words under the D55 profile
    // string it is the binding, and under the base profile string it is not
    assert_eq!(fra.profile(), d55_profile_of(a.st.rs().profile()), "the D55 profile string is not the prefix and the base");
    assert_ne!(fra.profile(), a.st.rs().profile());
    let header_under = |domain: &str| -> Digest {
        let st = &a.st;
        let sh = &st.rs.sh;
        let mut tr = protocol::tagged_transcript(sh, domain.as_bytes());
        let mut shape_bytes = Vec::new();
        for v in [st.rs.l, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim] {
            shape_bytes.extend_from_slice(&(v as u64).to_le_bytes());
        }
        tr.absorb(b"run-shape", &shape_bytes);
        tr.absorb(b"expected-IO", &st.expected.to_bytes());
        tr.absorb(b"public-statement", &st.public_statement());
        tr.absorb(b"parameters", fra.parameter_line().unwrap().as_bytes());
        tr.absorb(b"calibration", &st.calibration);
        tr.absorb(b"schedule", &fra.schedule_digest().unwrap());
        tr.state()
    };
    assert_eq!(header_under(fra.profile()), fra.binding().unwrap(), "the fork run's transcript is not constructed under its own D55 profile string (F3)");
    assert_ne!(header_under(a.st.rs().profile()), fra.binding().unwrap(), "the fork run's transcript is constructed under the BASE profile string (F3)");
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

/// **Control 1b (D55 review F2): a fork-index swap of two forks that carry
/// the SAME block.** At this rung stages 0 and 2 are both layer 0's block,
/// so the two forks' block digests are equal and the index is the only thing
/// that separates their derivations. With forged tags the swap is REJECTED by
/// the chain. Then the MUTATION the review names — the index dropped from the
/// fork derivation on both sides ([`DropForkIndex`], carried into every
/// worker by the F5 hooks) — makes the very same cheat VERIFY, so this
/// control is the one that shows the index is in the derivation; and under
/// that mutation a swap of two forks with DIFFERENT blocks (1 and 2) is still
/// rejected, by the digest.
#[test]
fn d55_control_a_same_block_fork_swap_is_caught_only_by_the_index() {
    let t = ForkTamper::ForkIndexSwap { a: 0, b: 2 };
    let mut r = rung(3, 111);
    assert_eq!(r.st.block_digests[0], r.st.block_digests[2], "forks 0 and 2 do not carry the same block, so this control would not isolate the index");
    assert_ne!(r.st.block_digests[1], r.st.block_digests[2]);
    let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
    let (rc, _) = prove_run_with_forks_tampered(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), 3, t, true).expect("the cheating prover made a receipt");
    let e = verify_run_with_forks(&fr, &r.blocks, &rc, 3).err().unwrap_or_else(|| panic!("THE SAME-BLOCK FORK SWAP {t:?} (forged tags) VERIFIED"));
    assert!(e.contains("fork 0"), "{e}");
    not_a_tag_refusal(t, &e);
    eprintln!("D55 CONTROL | {t:?} (one block at both forks) | forged tags true | REJECTED: {e}");
    // the mutation: no index in the derivation, prover and verifier alike
    let _m = DropForkIndex::on();
    let mut r = rung(3, 112);
    let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
    let (rc, stats) = prove_run_with_forks_tampered(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), 3, t, true).expect("the cheating prover made a receipt");
    assert!(stats.fork_hooks.iter().all(|h| h.drop_fork_index), "the mutation did not reach every fork worker (F5)");
    verify_run_with_forks(&fr, &r.blocks, &rc, 3).unwrap_or_else(|e| panic!("under a derivation WITHOUT the index the same-block swap is still rejected ({e}), so this control does not isolate the index"));
    eprintln!("D55 CONTROL | {t:?} | the index dropped from the derivation (mutation) | VERIFIES — the control fails as it must: only the index separates two forks of one block");
    let t2 = ForkTamper::ForkIndexSwap { a: 1, b: 2 };
    let mut r = rung(3, 113);
    let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
    let (rc, _) = prove_run_with_forks_tampered(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), 3, t2, true).expect("the cheating prover made a receipt");
    let e = verify_run_with_forks(&fr, &r.blocks, &rc, 3).err().unwrap_or_else(|| panic!("UNDER THE MUTATION THE DIFFERENT-BLOCK SWAP {t2:?} VERIFIED"));
    assert!(e.contains("fork 1"), "{e}");
    eprintln!("D55 CONTROL | {t2:?} (two different blocks) | the index dropped (mutation) | REJECTED by the digest: {e}");
}

// ------------------------------------------------------------------ F1: false statements through the fork path

/// **D55 review F1: the rung-G development run's private side**, kept as
/// D12a's `run_tests::Chain` keeps it (that harness is private to its own
/// module, so this is the same few lines): `inputs[k]` is block `k`'s true
/// hidden input, `planes` holds the `L + 1` padded planes (the external
/// input, the `L - 1` boundaries, the external output), and a tamper
/// `(block, plane, position, delta)` is applied to that block's witness
/// after it is built. Every negative case is one deliberate disagreement
/// between the two lists, or one tampered witness word.
struct GChain {
    sh: crate::private_block::shape::Shape,
    public: crate::private_block::AttentionPublic,
    ff: crate::private_block::FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
    tamper: Option<(usize, usize, usize, i64)>,
}

fn g_padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

fn g_true_input(sh: &crate::private_block::shape::Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

impl GChain {
    /// the honest `l`-block chain from the rung's tame fixture
    fn honest(l: usize) -> GChain {
        let sh = crate::private_block::shape::Shape::rung_g();
        let (public, ff, x0) = crate::private_block::grow_tests::tame_case(&sh);
        let ids = Ids::new(&sh).expect("the rung-G plane map");
        let (mut inputs, mut planes, mut x) = (Vec::new(), Vec::new(), x0);
        for k in 0..l {
            let w = witness::build_shaped(&sh, &public, &ff, &x).expect("an honest witness of the chain");
            if k == 0 {
                planes.push(g_padded(&w, ids.at(A_X)));
            }
            planes.push(g_padded(&w, ids.at(crate::private_block::layout::A_X2)));
            inputs.push(x);
            x = g_true_input(&sh, &w.output().expect("the block's hidden output"));
        }
        GChain { sh, public, ff, inputs, planes, tamper: None }
    }
    /// rebuild `planes[k+1 ..]` from `inputs[k]` (everything downstream of a
    /// changed input honest again)
    fn rechain_from(&mut self, k: usize) {
        let ids = Ids::new(&self.sh).expect("the rung-G plane map");
        let mut x = self.inputs[k].clone();
        for j in k..self.inputs.len() {
            let w = witness::build_shaped(&self.sh, &self.public, &self.ff, &x).expect("an honest witness of the chain");
            self.inputs[j] = x;
            self.planes[j + 1] = g_padded(&w, ids.at(crate::private_block::layout::A_X2));
            x = g_true_input(&self.sh, &w.output().expect("the block's hidden output"));
        }
    }
    fn blocks(&self) -> Vec<BlockPublic> {
        (0..self.inputs.len()).map(|_| BlockPublic::new(self.public.clone(), self.ff.clone())).collect()
    }
    /// the rung-G run statement of this chain's planes, and its endpoint owners
    fn statement(&self, context: u8) -> (RunStatement, Endpoints) {
        let l = self.inputs.len();
        let ctx = [context; 32];
        let spec = IoSpec::new_shaped(&self.sh, ctx, 0, 0).expect("the run's endpoint spec");
        let (expected, owners) = prepare_endpoints(spec, &self.planes[0], &self.planes[l]).expect("the run's external endpoint owners");
        let st = RunStatement::new(RunShape::rung_g(l).expect("the rung-G run shape"), ctx, expected, &self.blocks(), &vec![(0, 0); l]).expect("the run statement");
        (st, owners)
    }
}

impl RunWitnessSource for GChain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        let mut w = witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])?;
        if let Some((blk, plane, at, delta)) = self.tamper {
            if blk == k {
                w.planes[plane][at] += delta;
            }
        }
        Ok(w)
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

/// prove a rung-G chain as a D55 fork run on `workers` workers (a cheating
/// prover: no honest check of the chain, as D12a's negative tests), then
/// verify it on three threads; `Err` is the PROVER's refusal, `Ok` the
/// verifier's verdict and the stats
fn g_fork_run(c: &mut GChain, context: u8, workers: usize) -> Result<(Result<(), String>, ForkStats), String> {
    let (st, owners) = c.statement(context);
    let blocks = c.blocks();
    let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype())?;
    let (rc, stats) = prove_run_with_forks(&fr, &blocks, c, owners, workers)?;
    Ok((verify_run_with_forks(&fr, &blocks, &rc, 3), stats))
}

/// **THE HEADLINE NEGATIVE TEST, PORTED TO THE FORK PATH (D55 review F1).**
/// D12a's `the_headline_negative_test_a_second_block_on_another_input_is_rejected_by_the_verifier`
/// at an INTERIOR boundary of an `L = 3` rung-G run, the forks on two and on
/// three workers. First the honest chain verifies (so the rejections below
/// are about the change and nothing else), then both variants, which fail at
/// different slots of different forks:
///
/// (i) `B_1` moved, at a true support position: block 2 is rebuilt on what
///     `B_1` holds and everything downstream is honest, so only block 1's
///     outgoing equality (fork 1, slot 22, `IO-out`) can object;
/// (ii) block 2 run on something other than block 1's output, `B_1` keeping
///     block 1's TRUE output: block 2's incoming equality (fork 2, slot 21,
///     `IO-in`) objects.
///
/// In both the PROVER succeeds; only a refusal by `verify_run_with_forks` is
/// a soundness statement (finding F-8's rule), and "the PROVER refused" fails
/// the test.
#[test]
fn d55_the_headline_negative_test_a_block_on_another_input_is_rejected_through_the_fork_path() {
    let mut honest = GChain::honest(3);
    let (v, stats) = g_fork_run(&mut honest, 120, 3).expect("the honest rung-G fork run proves");
    v.unwrap_or_else(|e| panic!("the honest L3 rung-G fork run does not verify: {e}"));
    assert_eq!(stats.generators, 4);
    for (variant, workers, fork, slot, context) in [
        ("(i) B_1 moved: block 1's output is not what the boundary holds", 2usize, "fork 1", "IO-out", 121u8),
        ("(ii) block 2 run on something other than block 1's output", 3, "fork 2", "IO-in", 122),
    ] {
        let mut c = GChain::honest(3);
        let honest_b1 = c.planes[2].clone();
        if variant.starts_with("(i)") {
            c.planes[2][0] += 1;
            c.inputs[2] = g_true_input(&c.sh, &c.planes[2]);
            c.rechain_from(2);
            assert_ne!(c.planes[2], honest_b1);
        } else {
            c.inputs[2][0] += 1;
            c.rechain_from(2);
            assert_eq!(c.planes[2], honest_b1, "variant (ii) must keep B_1 at block 1's true output");
        }
        let (v, _) = match g_fork_run(&mut c, context, workers) {
            Err(e) => panic!("{variant}: the PROVER refused, so this case says nothing about the verifier: {e}"),
            Ok(v) => v,
        };
        let e = v.err().unwrap_or_else(|| panic!("{variant}: A FORK RUN WHOSE BLOCKS ARE NOT CHAINED VERIFIED"));
        assert!(e.contains(fork) && e.contains(slot), "{variant}: expected {fork}'s {slot} slot to object, got: {e}");
        eprintln!("D55 F1 HEADLINE | {variant} | {workers} prover workers | REJECTED by the verifier: {e}");
    }
}

/// **EVERY SINGLE-BLOCK TAMPER FAMILY, ON AN INTERIOR FORK (D55 review F1).**
/// D12a's `every_single_block_tamper_family_is_still_rejected_inside_a_run`,
/// its twenty-seven families on a true support position, applied to block 1
/// of an `L = 3` rung-G fork run — the fork with a boundary on both sides —
/// with every fork on its own worker. The prover is a cheating prover (CS-3's
/// switch on, which the F5 hooks carry into the worker that proves fork 1:
/// the stats must show it there, or the case says nothing); it must make the
/// receipt, and `verify_run_with_forks` must refuse it.
///
/// And the F5 control: the one family the honest CS-3 check refuses (a byte
/// limb of 300) is proved again with the switch OFF, and the fork prover on
/// its worker refuses it by CS-3's name. So the check really runs inside the
/// fork, and the switch the cheating cases rely on really reached it.
#[test]
fn d55_every_single_block_tamper_family_is_rejected_on_an_interior_fork() {
    use crate::private_block::layout::*;
    let sh = crate::private_block::shape::Shape::rung_g();
    let ids = Ids::new(&sh).expect("the rung-G plane map");
    // the F5 control first, with no switch on this thread
    {
        let mut c = GChain::honest(3);
        c.tamper = Some((1, ids.at(A_LIMB), 0, 300));
        let e = g_fork_run(&mut c, 130, 3).err().expect("WITHOUT THE CHEATING SWITCH THE FORK PROVER MADE A RECEIPT FOR A LOOKUP MISS");
        assert!(e.contains("fork 1") && e.contains(crate::private_block::protocol::LOOKUP_MISS_REFUSAL), "{e}");
        eprintln!("D55 F1 TAMPER | a norm_a byte limb (300) in block 1, NO cheating switch | REFUSED BY THE FORK PROVER on its worker: {}", e.chars().take(160).collect::<String>());
    }
    let cases: Vec<(&str, usize, i64)> = vec![
        ("the norm_a denominator", ids.at(A_D), 1),
        ("a norm_a byte limb", ids.at(A_LIMB), 300),
        ("the norm_a quotient", ids.at(A_Y), 1),
        ("residual 1", ids.at(A_X1), 1),
        ("the input plane", ids.at(A_X), 1),
        ("an int16 byte limb of x", ids.at(A_XL0), 300),
        ("the Q projection", ids.at(A_Q8), 1),
        ("the rotated query", ids.at(A_QR8), 1),
        ("the K projection", ids.at(A_K8), 1),
        ("the V projection", ids.at(A_V8), 1),
        ("the score", ids.at(A_S8), 1),
        ("the row maximum", ids.at(A_MX), 1),
        ("the exp value", ids.at(A_E), 1),
        ("the softmax quotient", ids.at(A_P), 1),
        ("the output projection", ids.at(A_O8), 1),
        ("the attention output", ids.at(A_AO), 1),
        ("a biased attention remainder", ids.at(A_RAL), 1),
        ("the norm_m denominator", ids.at(A_DM), 1),
        ("a norm_m byte limb", ids.at(A_LIMBM), 300),
        ("the norm_m quotient", ids.at(A_YM), 1),
        ("the gate output", ids.at(A_G8), 1),
        ("a biased gate remainder", ids.at(A_RGL), 1),
        ("the activation value", ids.at(A_A16), 1),
        ("the up output", ids.at(A_U16), 1),
        ("the gate-up product", ids.at(A_H16), 1),
        ("the feed-forward output", ids.at(A_Z16), 1),
        ("residual 2", ids.at(A_X2), 1),
    ];
    let _cheating = crate::private_block::protocol::CheatingProver::on();
    let mut in_fork_1 = 0usize;
    for (i, (name, plane, delta)) in cases.iter().enumerate() {
        let mut c = GChain::honest(3);
        c.tamper = Some((1, *plane, 0, *delta));
        let (v, stats) = match g_fork_run(&mut c, 131 + i as u8, 3) {
            Err(e) => panic!("{name} in block 1: the PROVER refused, so this case says nothing about the verifier: {e}"),
            Ok(v) => v,
        };
        assert!(stats.fork_hooks.iter().all(|h| h.block.cheating_prover), "{name}: the cheating switch did not reach every fork worker (F5): {:?}", stats.fork_hooks);
        let e = v.err().unwrap_or_else(|| panic!("{name} in block 1 of a fork run: A TAMPERED FORK RUN VERIFIED"));
        in_fork_1 += usize::from(e.contains("fork 1"));
        eprintln!("D55 F1 TAMPER | {name} in block 1 (interior fork) | REJECTED by the verifier: {e}");
    }
    eprintln!("D55 F1 TAMPER | all {} families rejected by verify_run_with_forks, {in_fork_1} of them inside fork 1's own verify_core", cases.len());
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
    // D59: a W16R2 (rate 1/2) base too
    let spec = shape::W16_PROFILES.iter().chain(shape::W16R2_PROFILES.iter()).find(|s| s.name == name).expect("a W16 or W16R2 profile name");
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
        let (rc, stats) = prove_run_with_forks(&fr, &rep, &mut src, owners, n).expect("the D55 fork run proves");
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

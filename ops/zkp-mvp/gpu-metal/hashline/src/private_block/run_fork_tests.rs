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
    /// D60 (a cheating prover's witness, test only): `(block, plane, word)`
    /// has its low bit flipped when the block's witness is handed out (a
    /// byte limb stays a byte, so every lookup still hits)
    tamper: Option<(usize, usize, usize)>,
}

impl RunWitnessSource for Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        let mut w = self.witnesses.get_mut(k).and_then(Option::take).ok_or_else(|| format!("witness {k} was consumed"))?;
        if let Some((blk, plane, at)) = self.tamper {
            if blk == k {
                w.planes[plane][at] ^= 1;
            }
        }
        Ok(w)
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

/// The PUBLIC side of an `l`-stage run at the R13 h24 rung (what a verifier
/// in a fresh process rebuilds from the fixture alone): stage 0 is the
/// fixture's layer 0, odd stages its other-gate twin (`(-4, -13)`, as the
/// D12a two-stage test), even stages layer 0's block again.
struct RungPublic {
    ex: TrainedExport,
    seed: crate::private_block::shape::Shape,
    shapes: Vec<crate::private_block::shape::Shape>,
    blocks: Vec<BlockPublic>,
    model: TrainedModelStatement,
}

fn rung_public(l: usize) -> RungPublic {
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
    let model = ex.statement_of_records(&seed, &c, records).unwrap();
    RungPublic { ex, seed, shapes, blocks, model }
}

/// D60: how a rung chain departs from the honest one (the false statements)
#[derive(Clone, Copy, Debug, PartialEq)]
enum Tweak {
    Honest,
    /// `B_k` holds block `k`'s output with word 0 (a true support position)
    /// moved by one, and block `k + 1` is run on what `B_k` holds: only block
    /// `k`'s outgoing equality (fork `k`, slot 22) can object
    MoveBoundary(usize),
    /// `B_k` holds block `k`'s TRUE output, and block `k + 1` is run on it
    /// with word 0 moved by one: block `k + 1`'s incoming equality (fork
    /// `k + 1`, slot 21) objects
    OffInput(usize),
}

/// An `l`-stage run at the R13 h24 rung ([`rung_public`]); the witness chain
/// is built honestly from the fixture's public sequence.
fn rung(l: usize, context: u8) -> Rung {
    rung_with(l, context, Tweak::Honest)
}

fn rung_with(l: usize, context: u8, tweak: Tweak) -> Rung {
    let RungPublic { ex, seed, shapes, blocks, model } = rung_public(l);
    let (mut x, _) = ex.load_seq(&shapes[0], "public", 0).unwrap();
    let ids = Ids::new(&seed).unwrap();
    let (mut witnesses, mut planes, mut input, mut output) = (Vec::new(), Vec::new(), Vec::new(), Vec::new());
    for k in 0..l {
        let w = witness::build_for_block(&shapes[k], &blocks[k], &x).unwrap_or_else(|e| panic!("stage {k} of the R13 rung chain ({tweak:?}) is not admissible: {e}"));
        if k == 0 {
            input = w.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect();
        }
        let mut out = w.output().unwrap();
        if tweak == Tweak::MoveBoundary(k) {
            out[0] += 1;
        }
        x = unpad(&seed, &out);
        if tweak == Tweak::OffInput(k) {
            x[0] += 1;
        }
        if k + 1 < l {
            planes.push(out);
        } else {
            output = out;
        }
        witnesses.push(Some(w));
    }
    let ctx = [context; 32];
    let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&seed, ctx, 0, 0).unwrap(), &input, &output).unwrap();
    let st = RunStatement::new_bound(RunShape::accuracy(seed, l).unwrap(), ctx, expected, &blocks, &vec![(0, 0); l], &model).unwrap();
    Rung { st, blocks, src: Chain { witnesses, planes, tamper: None }, owners: Some(owners) }
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
    // D60: the R13 rung is an eligible base, so its fork run hashes under its
    // REGISTERED D55 profile, the marker and the base
    assert_eq!(fra.profile(), run::RUN_PROFILE_D55_R13_RUNG_H24, "the R13 rung's fork run is not under its registered D55 profile");
    assert_eq!(fra.profile(), fork_profile_for(a.st.rs().profile()));
    assert!(fra.is_registered());
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
    assert!(pl_a.ends_with("/one-run-one-transcript") && pl_f.ends_with("/d55-commit-fork-join-registered-d60"), "{pl_a} / {pl_f}");
    assert_eq!(pl_a.strip_suffix("/one-run-one-transcript"), pl_f.strip_suffix("/d55-commit-fork-join-registered-d60"), "the fork line moved more than its construction clause");
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

// ------------------------------------------------------------------ D60: the registered profiles

/// **D60: the registry.** Every registered D55 run profile is the marker and
/// its base (an R13 blocks-only run profile of `ACCURACY_RUN_PROFILES`, each
/// base exactly once); none is a D12a run profile CS-7 admits, a base, a
/// token-I/O or classifier profile, or another D55 string; and the door
/// admits each base under its registered string at `L` = 1, 2 and 32 (the
/// constructor census holds at each).
#[test]
fn d60_every_registered_d55_profile_is_the_marker_and_its_base() {
    use crate::private_block::trained_statement::accuracy_hash_model;
    let mut seen: Vec<&str> = Vec::new();
    for (d55, base) in run::D55_RUN_PROFILES {
        let tail = base.strip_prefix("hashline-zk-mr1/").expect("a hashline-zk-mr1 base");
        assert_eq!(d55, format!("hashline-zk-mr1/{}{tail}", run::D55_REGISTERED_MARKER), "{d55} is not the marker and its base");
        assert!(run::ACCURACY_RUN_PROFILES.iter().any(|(r, _)| *r == base), "{base} is not an R13 blocks-only run profile");
        assert!(!run::TOKEN_IO_RUN_PROFILES.contains(&base) && !run::is_classify_run_profile(base));
        assert!(!run::ACCURACY_RUN_PROFILES.iter().any(|(r, b)| *r == d55 || *b == d55), "{d55} is also a D12a run or block profile");
        assert!(!seen.contains(&d55) && !seen.contains(&base), "a D55 string or base appears twice");
        seen.push(d55);
        seen.push(base);
        assert_eq!(run::d55_run_profile(base), Some(d55));
    }
    assert_eq!(run::D55_RUN_PROFILES.len(), run::ACCURACY_RUN_PROFILES.len(), "an R13 blocks-only base has no registered D55 profile (or one too many)");
    let mut n = 0usize;
    for (p, sh) in crate::private_block::accuracy_profile_tests::registered_runs() {
        let d55 = run::d55_run_profile(p).expect("every R13 run profile is an eligible base");
        // CS-7: a D12a run cannot carry the D55 string
        let e = RunShape::new(sh.clone(), 2, d55).err().expect("CS-7 ADMITTED A D55 STRING AS A D12a RUN PROFILE");
        assert!(e.contains("CS-7"), "{e}");
        for l in [1usize, 2, 32] {
            let spec = IoSpec::new_shaped(&sh, [9; 32], 0, 0).unwrap();
            let model = accuracy_hash_model(&sh, l);
            let st = RunStatement::new_bound_from_digests(RunShape::accuracy(sh.clone(), l).unwrap(), [9; 32], crate::private_block::ExpectedIo::from_roots(spec, [1; 32], [2; 32]), model.layers.iter().map(|r| r.block_digest).collect(), &vec![crate::private_block::ENDPOINT_SCALES; l], &model).unwrap();
            let fr = ForkRun::new(&st, D55OptIn::registered_profile()).unwrap_or_else(|e| panic!("{p} L{l}: the registered door refuses an eligible base: {e}"));
            assert_eq!(fr.profile(), d55);
            assert!(fr.is_registered());
            assert!(fr.parameter_line().unwrap().ends_with("/d55-commit-fork-join-registered-d60"));
            let (lit, lines) = fr.schedule_lines().unwrap();
            assert_eq!(lit, b"hashline/private-run-fork-schedule/d55-registered-d60/1");
            assert!(lines.iter().any(|s| s.starts_with(&format!("phase 1 (commit): the {} internal boundaries", l - 1))), "{p} L{l}: F6's counted phase-1 line is missing");
            if l == 32 {
                eprintln!("D60 | registered | {d55} over {p}: {}", fr.census().unwrap());
            }
            n += 1;
        }
    }
    eprintln!("D60 | registry | {} registered D55 run profiles, each the marker and its R13 base; CS-7 refuses every one as a D12a profile; the registered door admits all {n} (base, L) statements", run::D55_RUN_PROFILES.len());
}

/// **D60: the registered door refuses an ineligible base by name**, and only
/// a test build's `unreviewed_prototype()` gives such a base its TEST-ONLY
/// identity (here the rung-G development run, a D12a-registered pre-R13
/// profile with no registered D55 profile).
#[test]
fn d60_the_registered_door_refuses_a_base_with_no_registered_d55_profile() {
    let c = GChain::honest(2);
    let (st, _owners) = c.statement(140);
    let e = ForkRun::new(&st, D55OptIn::registered_profile()).err().expect("THE REGISTERED DOOR ADMITTED A BASE WITH NO REGISTERED D55 PROFILE");
    assert!(e.contains("D60") && e.contains("no registered D55 profile"), "{e}");
    let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).expect("the test-only fallback");
    assert!(!fr.is_registered());
    assert_eq!(fr.profile(), d55_profile_of(st.rs().profile()));
    assert!(fr.parameter_line().unwrap().ends_with("/d55-commit-fork-join-prototype-unregistered"));
    // and a registered base takes its registered string under either opt-in
    let r = rung(2, 141);
    let a = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
    let b = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
    assert_eq!(a.profile(), run::RUN_PROFILE_D55_R13_RUNG_H24);
    assert_eq!(a.profile(), b.profile());
    assert_eq!(a.binding().unwrap(), b.binding().unwrap());
    eprintln!("D60 | door | rung-G refused by the registered door ({}); its test-only identity is {}; the R13 rung takes {} under both opt-ins", e.chars().take(110).collect::<String>(), fr.profile(), a.profile());
}

/// the binding at `[8..40]` of every frame, the start tag at `[56..88]` of a
/// fork frame, the S0 tag at the head's end, the S1 tag at `[48..80]` of the
/// tail (`run_fork_wire.rs`)
fn rewrite(frame: &[u8], at: usize, with: &[u8]) -> Vec<u8> {
    let mut b = frame.to_vec();
    b[at..at + with.len()].copy_from_slice(with);
    b
}

/// **D55 review F7 / D60: a foreign fork frame from a second honest run of
/// the same base and context** (fresh endpoint commitments and boundaries,
/// since an endpoint owner opens once and cannot be reused) spliced in at
/// fork 1: refused by the binding as it stands; with the binding rewritten to
/// this run's, by the fork's start tag (the second run's roots made another
/// `S0`); and with the start tag rewritten too, by fork 1's own
/// `verify_core` — the chain, not a tag compare.
#[test]
fn d60_f7_a_foreign_fork_frame_from_a_second_run_is_rejected_by_the_tag_and_then_by_the_chain() {
    let mut a = rung(3, 150);
    let (rc, _) = prove_forks(&mut a, 3);
    let mut b = rung(3, 150);
    let (other, _) = prove_forks(&mut b, 3);
    let fr = ForkRun::new(&a.st, D55OptIn::registered_profile()).unwrap();
    let binding = fr.binding().unwrap();
    let (roots, _) = super::super::super::wire::fork::decode_head(&rc.head, &binding, 3).unwrap();
    let start1 = position_tag(&fr.fork(&roots, 1, None).unwrap());
    let cases = [
        ("as it stands", other.forks[1].clone(), "another run"),
        ("its binding rewritten", rewrite(&other.forks[1], 8, &binding), "start tag"),
        ("its binding and start tag rewritten", rewrite(&rewrite(&other.forks[1], 8, &binding), 56, &start1), "fork 1"),
    ];
    for (what, frame, want) in cases {
        let mut bad = rc.clone();
        bad.forks[1] = frame;
        let e = verify_run_with_forks(&fr, &a.blocks, &bad, 3).err().unwrap_or_else(|| panic!("A FOREIGN FORK FRAME ({what}) VERIFIED"));
        assert!(e.contains(want), "{what}: {e}");
        if what.ends_with("start tag rewritten") {
            assert!(!e.contains(" tag "), "{what}: refused by a tag compare, not by the chain: {e}");
        }
        eprintln!("D60 F7 | a foreign fork frame from a second run, {what} | REJECTED: {e}");
    }
}

/// **D55 review F7 / D60: `L = 1`** — one fork, no internal boundary (the
/// head carries no root), the join and both endpoint openings: an honest run
/// verifies on one and three verifier threads, and a changed byte in each
/// frame is refused.
#[test]
fn d60_f7_a_one_block_fork_run_verifies_and_a_changed_byte_is_refused() {
    let mut r = rung(1, 151);
    let (rc, stats) = prove_forks(&mut r, 2);
    assert_eq!((stats.workers, stats.generators), (1, 2));
    let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
    assert_eq!(rc.head.len(), super::super::super::wire::fork::head_len(1));
    for vw in [1usize, 3] {
        verify_run_with_forks(&fr, &r.blocks, &rc, vw).unwrap_or_else(|e| panic!("the honest L1 fork run does not verify ({vw} threads): {e}"));
    }
    for (what, bad) in [("head", ForkReceipt { head: flipped(&rc.head), ..rc.clone() }), ("fork", ForkReceipt { forks: vec![flipped(&rc.forks[0])], ..rc.clone() }), ("tail", ForkReceipt { tail: flipped(&rc.tail), ..rc.clone() })] {
        let e = verify_run_with_forks(&fr, &r.blocks, &bad, 1).err().unwrap_or_else(|| panic!("L1: A CHANGED BYTE IN THE {what} VERIFIED"));
        eprintln!("D60 F7 | L1 | a changed byte in the {what} | REJECTED: {}", e.chars().take(120).collect::<String>());
    }
    eprintln!("D60 F7 | L1 | the honest one-block fork run verifies: {} B (head {} B, fork {} B, tail {} B)", rc.bytes(), rc.head.len(), rc.forks[0].len(), rc.tail.len());
}

/// **D55 review F7 / D60: one statement under ANOTHER fork profile, and a
/// D12a stage body re-wrapped as a fork.** (i) The R13 rung's registered
/// receipt checked under the same statement's TEST-ONLY identity (another
/// constructor domain): refused by the binding; with every frame's binding
/// and the head's S0 tag and each fork's start tag rewritten to that
/// profile's own, by fork 0's `verify_core`. (ii) A D12a run's stage-1 body
/// (its three roots, slots and `M` / `A` / `H` openings) re-wrapped to the
/// fork frame's length with the D55 verifier's own header and tags: refused
/// by fork 1's `verify_core` — so neither crossing rests on a length.
#[test]
fn d60_f7_a_receipt_under_another_profile_and_a_rewrapped_d12a_body_are_rejected_by_the_chain() {
    let fw = super::super::super::wire::fork::head_len;
    let mut r = rung(3, 152);
    let (rc, _) = prove_forks(&mut r, 3);
    let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
    let other = ForkRun::new_test_identity(&r.st).unwrap();
    assert_ne!(fr.profile(), other.profile());
    let e = verify_run_with_forks(&other, &r.blocks, &rc, 3).err().expect("A REGISTERED RECEIPT VERIFIED UNDER ANOTHER D55 PROFILE");
    assert!(e.contains("another run"), "{e}");
    eprintln!("D60 F7 | the registered receipt under the test-only profile, as it stands | REJECTED: {e}");
    let ob = other.binding().unwrap();
    let (roots, _) = super::super::super::wire::fork::decode_head(&rc.head, &fr.binding().unwrap(), 3).unwrap();
    let s0 = position_tag(&other.s0(&roots, None).unwrap());
    let mut forged = ForkReceipt { head: rewrite(&rewrite(&rc.head, 8, &ob), fw(3) - 32, &s0), forks: Vec::new(), tail: rewrite(&rc.tail, 8, &ob) };
    for (k, f) in rc.forks.iter().enumerate() {
        let start = position_tag(&other.fork(&roots, k, None).unwrap());
        forged.forks.push(rewrite(&rewrite(f, 8, &ob), 56, &start));
    }
    let e = verify_run_with_forks(&other, &r.blocks, &forged, 3).err().expect("A REGISTERED RECEIPT WITH ITS HEADERS REWRITTEN VERIFIED UNDER ANOTHER D55 PROFILE");
    assert!(e.contains("fork 0") && !e.contains(" tag "), "the crossing was refused by a tag, not by the chain: {e}");
    eprintln!("D60 F7 | the registered receipt under the test-only profile, every binding and S0 / start tag rewritten | REJECTED by the chain: {e}");
    // (ii) a D12a stage body in a fork frame
    let mut d = rung(3, 152);
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(&d.st, &d.blocks, &mut d.src, d.owners.take().unwrap(), &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the D12a run proves");
    // a D55 receipt of the SAME statement is impossible (an endpoint owner
    // opens once), so the fork receipt is proved on a twin of the same base
    // and context, whose statement the verifier then uses, and the D12a body
    // is spliced into it
    let mut e2 = rung(3, 152);
    let (rc2, _) = prove_forks(&mut e2, 3);
    let f = ForkRun::new(&e2.st, D55OptIn::registered_profile()).unwrap();
    let honest = &rc2.forks[1];
    let body_len = honest.len() - 88 - 32;
    // segment 1 carries its boundary root (32 B) after the 88-byte header
    let body = &segs[1][88 + 32..88 + 32 + body_len];
    let mut wrapped = honest[..88].to_vec();
    wrapped.extend_from_slice(body);
    wrapped.extend_from_slice(&honest[honest.len() - 32..]);
    assert_eq!(wrapped.len(), honest.len(), "the re-wrapped body is not the fork frame's length");
    let mut bad = rc2.clone();
    bad.forks[1] = wrapped;
    let e = verify_run_with_forks(&f, &e2.blocks, &bad, 3).err().expect("A D12a STAGE BODY RE-WRAPPED AS A FORK VERIFIED");
    assert!(e.contains("fork 1") && !e.contains(" tag "), "the re-wrapped D12a body was refused by a tag, not by the chain: {e}");
    eprintln!("D60 F7 | a D12a stage-1 body re-wrapped to fork 1's length with the D55 verifier's own header and tags | REJECTED by the chain: {e}");
}

/// **D60: THE HEADLINE NEGATIVE TEST UNDER A REGISTERED PROFILE.** The rung-G
/// port above runs under a test-only identity; this is the same two
/// variants at the R13 h24 rung, an eligible base, under its REGISTERED D55
/// profile, the forks on two and three workers: (i) `B_1` moved (fork 1's
/// slot 22, `IO-out`, objects); (ii) block 2 run on something other than
/// block 1's output, `B_1` keeping the true output (fork 2's slot 21,
/// `IO-in`). The PROVER must make the receipt; only the verifier may refuse.
#[test]
fn d60_the_headline_negative_test_is_rejected_under_the_registered_profile() {
    for (tweak, workers, fork, slot, context) in [(Tweak::MoveBoundary(1), 2usize, "fork 1", "IO-out", 160u8), (Tweak::OffInput(1), 3, "fork 2", "IO-in", 161)] {
        let mut r = rung_with(3, context, tweak);
        let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
        assert!(fr.is_registered());
        let (rc, _) = prove_run_with_forks(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), workers).unwrap_or_else(|e| panic!("{tweak:?}: the PROVER refused, so this case says nothing about the verifier: {e}"));
        let e = verify_run_with_forks(&fr, &r.blocks, &rc, 3).err().unwrap_or_else(|| panic!("{tweak:?}: A REGISTERED FORK RUN WHOSE BLOCKS ARE NOT CHAINED VERIFIED"));
        assert!(e.contains(fork) && e.contains(slot), "{tweak:?}: expected {fork}'s {slot} slot to object, got: {e}");
        eprintln!("D60 HEADLINE | {} | {tweak:?} | {workers} prover workers | REJECTED by the verifier: {e}", fr.profile());
    }
}

/// **D60: the R13 byte-limb tamper families on an INTERIOR fork, under the
/// registered profile.** Native R13's relation mutations
/// (`accuracy_proof_tests`' byte attacks: one limb byte of a quotient,
/// projection, remainder or product plane has its low bit flipped, so it
/// stays a byte and every lookup still hits) applied to block 1 of an
/// `L = 3` R13-rung fork run, the cheating switch carried into every fork
/// worker (asserted from the stats), the receipt made by the prover and
/// refused by `verify_run_with_forks`.
#[test]
fn d60_the_r13_limb_tamper_families_on_an_interior_fork_are_rejected_under_the_registered_profile() {
    use crate::private_block::accuracy_layout::Limbs as L;
    let probe = rung_public(1);
    let ids = Ids::new(&probe.seed).unwrap();
    let acc = ids.accuracy().expect("an R13 layout");
    let roles = [(L::Y, 1), (L::Ym, 1), (L::Q, 1), (L::K, 1), (L::V, 1), (L::O, 1), (L::Rao, 2), (L::Rs, 2), (L::Rg, 2), (L::Up, 1), (L::H, 2), (L::Rh, 1), (L::Rd, 2)];
    let _cheating = crate::private_block::protocol::CheatingProver::on();
    let (mut rejected, mut in_fork_1, mut skipped) = (0usize, 0usize, Vec::new());
    for (i, (role, k)) in roles.iter().enumerate() {
        if acc.count(*role) <= *k {
            skipped.push(format!("{role:?}[{k}]"));
            continue;
        }
        let mut r = rung(3, 170 + i as u8);
        r.src.tamper = Some((1, acc.limb(*role, *k), 0));
        let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
        let (rc, stats) = prove_run_with_forks(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), 3).unwrap_or_else(|e| panic!("{role:?}[{k}] in block 1: the PROVER refused: {e}"));
        assert!(stats.fork_hooks.iter().all(|h| h.block.cheating_prover), "{role:?}[{k}]: the cheating switch did not reach every fork worker");
        let e = verify_run_with_forks(&fr, &r.blocks, &rc, 3).err().unwrap_or_else(|| panic!("{role:?}[{k}] in block 1: A TAMPERED REGISTERED FORK RUN VERIFIED"));
        rejected += 1;
        in_fork_1 += usize::from(e.contains("fork 1"));
        eprintln!("D60 TAMPER | {role:?}[{k}] low bit in block 1 (interior fork) | REJECTED by the verifier: {}", e.chars().take(160).collect::<String>());
    }
    assert!(rejected >= 10, "only {rejected} R13 families were exercised (skipped: {skipped:?})");
    eprintln!("D60 TAMPER | {rejected} R13 limb families rejected by verify_run_with_forks under {}, {in_fork_1} of them inside fork 1; not in this layout: {skipped:?}", run::RUN_PROFILE_D55_R13_RUNG_H24);
}

/// **D60: the capture writer and a fork run.** A registered R13-rung D55 run
/// (`L = 3`), captured by the fork-run recorder (each fork on its own
/// verifier worker) and export-replayed, is WRITTEN by
/// `run_capture::write_bundle` (the D55 schema, the receipt's frames, the
/// source pins with `run_fork.rs` / `run_fork_wire.rs` once each, the
/// manifest last); the same base under its TEST-ONLY identity is REFUSED by
/// that writer. (The Python D55 replay gate has been run on test-only W16 /
/// W16R2 bundles only; a registered R13 bundle is its next input.)
#[test]
fn d60_the_capture_writer_writes_a_registered_fork_run_bundle_and_refuses_a_test_only_one() {
    use crate::private_block::run_capture::{self as cap, CaptureOpts};
    let capture = |fr: &ForkRun, blocks: &Vec<BlockPublic>, rc: &ForkReceipt| -> cap::Bundle {
        let guard = cap::Recorder::attach();
        cap::begin_fork_run_with(fr.capture_header().unwrap(), fr.binding().unwrap(), CaptureOpts { arrays: true, public_tables: true });
        let v = verify_run_with_forks(fr, blocks, rc, 3);
        let taken = cap::take();
        drop(guard);
        v.expect("the fork run verifies with a recorder attached");
        let mut b = taken.expect("the fork-run recorder took the capture");
        assert_eq!(b.stages.len(), 3, "the capture did not record every fork");
        cap::export_replay(&mut b, &mut |k| ForkBlocks::get(blocks, k).cloned()).expect("the export replay of the fork run's statement tables");
        b
    };
    let root = std::env::temp_dir().join(format!("d60-capture-writer-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    // the registered profile: written
    let mut r = rung(3, 180);
    let (rc, _) = prove_forks(&mut r, 3);
    let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
    let b = capture(&fr, &r.blocks, &rc);
    let frames: Vec<Vec<u8>> = rc.frames().cloned().collect();
    let dir = root.join("registered");
    cap::write_bundle(&dir, &b, &frames, "D60 test: a registered R13-rung D55 run (public synthetic fixture)", "run_fork_tests::d60_the_capture_writer_writes_a_registered_fork_run_bundle_and_refuses_a_test_only_one").unwrap_or_else(|e| panic!("the capture writer refused a REGISTERED D55 fork run: {e}"));
    let manifest = std::fs::read_to_string(dir.join("manifest.json")).expect("the manifest is written last");
    assert!(manifest.contains(cap::SCHEMA_D55) && manifest.contains(run::RUN_PROFILE_D55_R13_RUNG_H24), "{}", manifest.chars().take(300).collect::<String>());
    for pin in ["\"file\":\"src/private_block/run_fork.rs\"", "\"file\":\"src/private_block/run_fork_wire.rs\""] {
        assert_eq!(manifest.matches(pin).count(), 1, "{pin} is not pinned exactly once");
    }
    for f in ["run.json", "stage-00.json", "stage-02.json", cap::D55_TAIL_FILE, cap::ARRAYS_FILE, "receipt/head.bin", "receipt/fork-00.bin", "receipt/fork-02.bin", "receipt/tail.bin", "README.md"] {
        assert!(dir.join(f).is_file(), "the registered bundle has no {f}");
        assert!(manifest.contains(&format!("\"file\":\"{f}\"")), "the manifest does not list {f}");
    }
    let total: u64 = std::fs::read_dir(&dir).unwrap().filter_map(|e| e.ok()).filter_map(|e| e.metadata().ok()).filter(|m| m.is_file()).map(|m| m.len()).sum();
    // the same base under its TEST-ONLY identity: refused by the writer
    let mut t = rung(3, 181);
    let ft = ForkRun::new_test_identity(&t.st).unwrap();
    let (rt, _) = prove_run_with_forks(&ft, &t.blocks, &mut t.src, t.owners.take().unwrap(), 3).unwrap();
    let bt = capture(&ft, &t.blocks, &rt);
    let e = cap::write_bundle(&root.join("test-only"), &bt, &rt.frames().cloned().collect::<Vec<_>>(), "D60 test", "-").err().expect("THE CAPTURE WRITER WROTE A TEST-ONLY FORK IDENTITY'S BUNDLE");
    assert!(e.contains("not a registered D55 run profile"), "{e}");
    assert!(!root.join("test-only").exists(), "the refused bundle left a directory");
    std::fs::remove_dir_all(&root).unwrap();
    eprintln!("D60 CAPTURE | the registered R13-rung D55 run's bundle WRITTEN by run_capture::write_bundle ({} B outside receipt/, schema {}); the test-only identity's REFUSED: {}", total, cap::SCHEMA_D55, e.chars().take(120).collect::<String>());
}

/// the directory and its marker for the fresh-process receipts
fn receipt_dir() -> PathBuf {
    PathBuf::from(std::env::var("HL_D60_RECEIPT_DIR").expect("HL_D60_RECEIPT_DIR names the directory of the D60 test receipts"))
}

const TEST_RECEIPT_MARKER: &str = "TEST RECEIPTS, NOT FOR PUBLICATION: proved by run_fork_tests::d60_fresh_process_write_test_receipts on the public synthetic R13 loader fixture r13-h24-wide (layer 0 and its other-gate twin) and its public sequence; no real content. Ruling D60 requires the Python privacy gate on a D55 capture before any receipt for real content.\n";

/// **D60, PROCESS 1 of 2 (`#[ignore]`d; run alone, then
/// [`d60_fresh_process_verify_test_receipts`] in a NEW process): write a
/// three-block R13-rung D55 receipt (the registered profile) and a D12a
/// receipt of the same base into `HL_D60_RECEIPT_DIR`**, each run directory
/// with its endpoint policy beside it (`<run>.expected.bin`). Fixture data
/// only; the directory is marked as test receipts, not for publication.
#[test]
#[ignore = "D60 fresh-process receipts: run with HL_D60_RECEIPT_DIR, then the verify test in another process"]
fn d60_fresh_process_write_test_receipts() {
    let dir = receipt_dir();
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join("TEST_RECEIPTS_NOT_FOR_PUBLICATION.txt"), TEST_RECEIPT_MARKER).unwrap();
    let (d55, d12a) = (dir.join("d55-run"), dir.join("d12a-run"));
    for p in [&d55, &d12a] {
        assert!(!p.exists(), "{} exists; the receipts are written into new directories", p.display());
        std::fs::create_dir(p).unwrap();
    }
    let mut r = rung(3, 200);
    let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
    let (rc, stats) = prove_run_with_forks(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), 3).unwrap();
    let written = write_fork_receipt(&d55, &rc).unwrap();
    std::fs::write(dir.join("d55-run.expected.bin"), r.st.expected.to_bytes()).unwrap();
    let mut s = rung(3, 201);
    let mut sink = super::super::super::run_sink::DirSink::create(&d12a, 3).unwrap();
    run::prove_run(&s.st, &s.blocks, &mut s.src, s.owners.take().unwrap(), &mut |k, b| super::super::super::run_sink::SegmentSink::accept(&mut sink, k, b)).unwrap();
    std::fs::write(dir.join("d12a-run.expected.bin"), s.st.expected.to_bytes()).unwrap();
    let mut manifest = format!("profile {}\nbase {}\nworkers {} generators {} forks {:.3} s total {:.3} s\n", fr.profile(), r.st.rs().profile(), stats.workers, stats.generators, stats.forks_s, stats.total_s);
    for (name, (n, h)) in d55_file_names(3).iter().zip(&written) {
        manifest.push_str(&format!("d55-run/{name} {n} {h}\n"));
    }
    for (k, (n, h)) in sink.lengths().iter().zip(sink.digests()).enumerate() {
        manifest.push_str(&format!("d12a-run/{} {n} {h}\n", super::super::super::run_sink::segment_file_name(k)));
    }
    std::fs::write(dir.join("MANIFEST.txt"), &manifest).unwrap();
    eprintln!("D60 FRESH-PROCESS WRITE | {} | pid {}\n{manifest}", dir.display(), std::process::id());
}

/// **D60, PROCESS 2 of 2 (`#[ignore]`d): in a NEW process, rebuild both
/// statements from the fixture and the policy files alone and verify from
/// the directories**: the D55 receipt verifies under its registered profile;
/// the D12a verifier refuses the D55 directory and the D55 frames; the D55
/// verifier refuses the D12a directory and the D12a segments; the D12a
/// receipt verifies under D12a.
#[test]
#[ignore = "D60 fresh-process receipts: run after d60_fresh_process_write_test_receipts, in another process"]
fn d60_fresh_process_verify_test_receipts() {
    let dir = receipt_dir();
    assert_eq!(std::fs::read_to_string(dir.join("TEST_RECEIPTS_NOT_FOR_PUBLICATION.txt")).unwrap(), TEST_RECEIPT_MARKER);
    let public = |ctx: u8, policy: &str| -> (RunStatement, Vec<BlockPublic>) {
        let p = rung_public(3);
        let expected = crate::private_block::ExpectedIo::from_bytes_at(&p.seed, &std::fs::read(dir.join(policy)).unwrap()).unwrap();
        let st = RunStatement::new_bound(RunShape::accuracy(p.seed, 3).unwrap(), [ctx; 32], expected, &p.blocks, &[(0, 0); 3], &p.model).unwrap();
        (st, p.blocks)
    };
    let (st55, b55) = public(200, "d55-run.expected.bin");
    let fr = ForkRun::new(&st55, D55OptIn::registered_profile()).unwrap();
    let seen = verify_run_with_forks_from_dir(&fr, &b55, &dir.join("d55-run"), 3).unwrap_or_else(|e| panic!("the D55 test receipt does not verify in a fresh process: {e}"));
    eprintln!("D60 FRESH-PROCESS VERIFY | pid {} | the D55 receipt ({}) VERIFIES: {} frames, {} B", std::process::id(), fr.profile(), seen.len(), seen.iter().map(|(n, _)| n).sum::<u64>());
    let e1 = run::verify_run_from_dir(&st55, &b55, &dir.join("d55-run")).err().expect("THE D12a VERIFIER ACCEPTED THE D55 DIRECTORY");
    eprintln!("D60 FRESH-PROCESS VERIFY | the D12a verifier on the D55 directory | REFUSED: {e1}");
    let (rc, _) = read_fork_receipt(&fr, &dir.join("d55-run")).unwrap();
    let e2 = run::verify_run(&st55, &b55, &rc.forks).err().expect("THE D12a VERIFIER ACCEPTED THE D55 FORK FRAMES AS SEGMENTS");
    eprintln!("D60 FRESH-PROCESS VERIFY | the D12a verifier on the D55 fork frames as segments | REFUSED: {e2}");
    let (st12, b12) = public(201, "d12a-run.expected.bin");
    let fr12 = ForkRun::new(&st12, D55OptIn::registered_profile()).unwrap();
    let e3 = verify_run_with_forks_from_dir(&fr12, &b12, &dir.join("d12a-run"), 3).err().expect("THE D55 VERIFIER ACCEPTED THE D12a DIRECTORY");
    eprintln!("D60 FRESH-PROCESS VERIFY | the D55 verifier on the D12a directory | REFUSED: {e3}");
    let segs: Vec<Vec<u8>> = (0..3).map(|k| std::fs::read(dir.join("d12a-run").join(super::super::super::run_sink::segment_file_name(k))).unwrap()).collect();
    let e4 = verify_run_with_forks(&fr12, &b12, &ForkReceipt { head: rc.head.clone(), forks: segs.clone(), tail: rc.tail.clone() }, 3).err().expect("THE D55 VERIFIER ACCEPTED D12a SEGMENTS AS FORKS");
    eprintln!("D60 FRESH-PROCESS VERIFY | the D55 verifier on the D12a segments as forks | REFUSED: {e4}");
    run::verify_run_from_dir(&st12, &b12, &dir.join("d12a-run")).unwrap_or_else(|e| panic!("the D12a test receipt does not verify in a fresh process: {e}"));
    eprintln!("D60 FRESH-PROCESS VERIFY | the D12a receipt VERIFIES under D12a; all four cross-checks refused");
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
    // D59: a W16R2 (rate 1/2) base too; D60: and an R13 base, whose fork run
    // is under its REGISTERED D55 profile (the W16 / W16R2 ones under their
    // test-only identities)
    let spec = shape::ACCURACY_PROFILES.iter().chain(shape::W16_PROFILES.iter()).chain(shape::W16R2_PROFILES.iter()).find(|s| s.name == name).expect("an R13, W16 or W16R2 profile name");
    // D60: `HL_D55_ORDER` = `serial-first` (the default), `forks-first`, or
    // `both` (alternating per pass, serial first in even passes)
    let order: String = env_or("HL_D55_ORDER", "serial-first".to_string());
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
    let run_profile = run::accuracy_run_profile(sh.profile)
        .or_else(|| crate::private_block::w16_privacy_gate_tests::W16_TEST_RUN_PROFILES.iter().find(|(_, b)| *b == sh.profile).map(|(r, _)| *r))
        .expect("an R13 run profile or a W16 test-only run identity");
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
        Chain { witnesses: got.into_iter().map(|(_, w)| Some(w)).collect(), planes: planes.clone(), tamper: None }
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
    // D60: every wall with the order of its pass (`true`: the forks ran first)
    let mut by_order: Vec<(bool, usize, f64)> = Vec::new();
    for p in 0..passes {
        let forks_first = match order.as_str() {
            "forks-first" => true,
            "both" => p % 2 == 1,
            _ => false,
        };
        for phase in if forks_first { [1, 0] } else { [0, 1] } {
            if phase == 0 {
                let (wall, bytes) = serial(ctx, p == 0);
                ctx += 1;
                eprintln!("D55-AB {name} L{l} T{} serial pass {p} ({}): wall {wall:.3} s = {:.2} proved tok/s; receipt {bytes} B", sh.tokens, if forks_first { "forks first" } else { "serial first" }, tok(wall));
                table[0].1.push(wall);
                by_order.push((forks_first, 0, wall));
                continue;
            }
            for (i, &n) in workers.iter().enumerate() {
                let (wall, bytes, st) = forked(ctx, n, p == 0);
                ctx += 1;
                let mut core = st.fork_core_s.clone();
                core.sort_by(|a, b| a.partial_cmp(b).unwrap());
                eprintln!(
                    "D55-AB {name} L{l} T{} forks N{n} pass {p} ({}): wall {wall:.3} s = {:.2} proved tok/s; {} workers; preflight {:.3} s, commit {:.3} s, forks {:.3} s, join {:.3} s; fork prove_core min {:.3} median {:.3} max {:.3} s; receipt {bytes} B",
                    sh.tokens,
                    if forks_first { "forks first" } else { "serial first" },
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
                by_order.push((forks_first, i + 1, wall));
            }
        }
    }
    // D60: the same table split by order
    for ff in [false, true] {
        for (i, (arm, _)) in table.iter().enumerate() {
            let walls: Vec<f64> = by_order.iter().filter(|(f, a, _)| *f == ff && *a == i).map(|(_, _, w)| *w).collect();
            if walls.is_empty() {
                continue;
            }
            let best = walls.iter().cloned().fold(f64::INFINITY, f64::min);
            let mean = walls.iter().sum::<f64>() / walls.len() as f64;
            eprintln!("D55-AB ORDER {} | {arm:<14} | {} passes | best {best:.3} s = {:.2} tok/s | mean {mean:.3} s = {:.2} tok/s", if ff { "forks-first " } else { "serial-first" }, walls.len(), tok(best), tok(mean));
        }
    }
    eprintln!("D55-AB {name} L{l}: the fork run's profile {}", { let (st, _o) = statement(250); ForkRun::new(&st, D55OptIn::unreviewed_prototype()).map(|f| format!("{} (registered: {})", f.profile(), f.is_registered())).unwrap_or_else(|e| e) });
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

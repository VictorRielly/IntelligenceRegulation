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

/// **D64 / H124c: the witness ON the clock.** The fork prover's feeder pulls
/// block `k`'s witness just in time (`run_fork.rs`, phase 2). Builder threads
/// (`jit_builder`) fill `built` from the chain's block inputs, at most `ahead`
/// blocks beyond the last one taken, so building overlaps the forks' proving.
/// The sealing pass that fixes the block inputs and boundary planes is timed
/// separately.
struct JitState {
    built: Vec<Option<Result<Witness, String>>>,
    given: Vec<bool>,
    taken: usize,
    stop: bool,
}

struct Jit<'a> {
    state: &'a std::sync::Mutex<JitState>,
    cv: &'a std::sync::Condvar,
    planes: &'a [Vec<i16>],
}

impl RunWitnessSource for Jit<'_> {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        let mut g = self.state.lock().map_err(|_| "jit: the state lock is poisoned".to_string())?;
        if k >= g.built.len() || g.given[k] {
            return Err(format!("jit: witness {k} does not exist or was consumed"));
        }
        loop {
            if let Some(r) = g.built[k].take() {
                g.given[k] = true;
                g.taken = g.taken.max(k + 1);
                self.cv.notify_all();
                return r;
            }
            g = self.cv.wait(g).map_err(|_| "jit: the state lock is poisoned".to_string())?;
        }
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.planes.get(k).cloned().ok_or_else(|| format!("no boundary {k}"))
    }
}

/// one builder thread of [`Jit`]: takes the next block, waits until it is
/// within `ahead` of the feeder, builds it, stores it; stops when told or out
/// of blocks. The feeder's block `taken` is never made to wait (`ahead >= 1`).
fn jit_builder(state: &std::sync::Mutex<JitState>, cv: &std::sync::Condvar, next: &std::sync::atomic::AtomicUsize, ahead: usize, build: &(dyn Fn(usize) -> Result<Witness, String> + Sync)) {
    loop {
        let k = next.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        {
            let Ok(mut g) = state.lock() else { return };
            if k >= g.built.len() {
                return;
            }
            while !g.stop && k >= g.taken + ahead.max(1) {
                let Ok(n) = cv.wait(g) else { return };
                g = n;
            }
            if g.stop {
                return;
            }
        }
        let w = build(k);
        let Ok(mut g) = state.lock() else { return };
        g.built[k] = Some(w);
        cv.notify_all();
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
    for pin in ["\"file\":\"src/private_block/run_fork.rs\"", "\"file\":\"src/private_block/run_fork_wire.rs\"", "\"file\":\"src/gpu/metal.rs\"", "\"file\":\"src/gpu/metal_kernels.metal\""] {
        assert_eq!(manifest.matches(pin).count(), 1, "{pin} is not pinned exactly once");
    }
    // gate round 26 F-B1: the manifest records whether the run proved on the GPU
    assert_eq!(manifest.matches(&format!("\"proved_on_gpu\":{}", crate::gpu::enabled())).count(), 1, "the manifest does not record proved_on_gpu = gpu::enabled()");
    for f in ["run.json", "stage-00.json", "stage-02.json", cap::D55_TAIL_FILE, cap::ARRAYS_FILE, "receipt/head.bin", "receipt/fork-00.bin", "receipt/fork-02.bin", "receipt/tail.bin", "README.md"] {
        assert!(dir.join(f).is_file(), "the registered bundle has no {f}");
        assert!(manifest.contains(&format!("\"file\":\"{f}\"")), "the manifest does not list {f}");
    }
    let total: u64 = std::fs::read_dir(&dir).unwrap().filter_map(|e| e.ok()).filter_map(|e| e.metadata().ok()).filter(|m| m.is_file()).map(|m| m.len()).sum();
    // D60 review closure: the registered run's run.json describes it as
    // registered (descriptive text only), not as the prototype
    let run_json = std::fs::read_to_string(dir.join("run.json")).unwrap();
    assert!(run_json.contains("D55 REGISTERED OPT-IN RUN PROFILE (ruling D60") && run_json.contains("it ends /d55-commit-fork-join-registered-d60") && !run_json.contains("D55 PROTOTYPE") && !run_json.contains("prototype-unregistered"), "the registered bundle's run.json still describes the prototype");
    // D60 review F3: the Rust gate's capture checks (the production writer's
    // manifest, PG-7 the allow-list over the run file, every fork and the
    // tail, PG-8 per fork, and their controls) on the bundle AS WRITTEN
    let gate = crate::private_block::w16_privacy_gate_tests::d60_registered_bundle_checks(r.st.rs().sh(), &dir, None).unwrap_or_else(|e| panic!("the Rust gate checks on the registered bundle FAILED: {e}"));
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
    eprintln!("D60 CAPTURE | the Rust gate on the written bundle: {gate}");
}

// ------------------------------------------------------------------ D60: the Python privacy gate's inputs

/// one honest fork run's verifier view, recorded with arrays and public-table
/// values (each fork on its own verifier worker) and export-replayed: the
/// D60 capture-writer test's recipe
fn d60pg_capture(fr: &ForkRun, blocks: &dyn ForkBlocks, rc: &ForkReceipt, workers: usize) -> crate::private_block::run_capture::Bundle {
    use crate::private_block::run_capture::{self as cap, CaptureOpts};
    let guard = cap::Recorder::attach();
    cap::begin_fork_run_with(fr.capture_header().unwrap(), fr.binding().unwrap(), CaptureOpts { arrays: true, public_tables: true });
    let v = verify_run_with_forks(fr, blocks, rc, workers);
    let taken = cap::take();
    drop(guard);
    v.expect("the fork run verifies with a recorder attached");
    let mut b = taken.expect("the fork-run recorder took the capture");
    assert_eq!(b.stages.len(), blocks.count(), "the capture did not record every fork");
    cap::export_replay(&mut b, &mut |k| blocks.get(k).cloned()).expect("the export replay of the fork run's statement tables");
    b
}

/// the witnesses and boundary planes of an honest chain from `x0` through
/// `blocks` (stage `k` at `shapes[k]`), with the run's padded input and
/// output planes; an inadmissible stage is an `Err`
#[allow(clippy::type_complexity)]
fn d60pg_chain(seed: &crate::private_block::shape::Shape, shapes: &[crate::private_block::shape::Shape], blocks: &[BlockPublic], x0: &[i16]) -> Result<(Vec<Option<Witness>>, Vec<Vec<i16>>, Vec<i16>, Vec<i16>), String> {
    let ids = Ids::new(seed)?;
    let (mut witnesses, mut planes, mut input, mut output) = (Vec::new(), Vec::new(), Vec::new(), Vec::new());
    let mut x = x0.to_vec();
    for k in 0..blocks.len() {
        let w = witness::build_for_block(&shapes[k], &blocks[k], &x).map_err(|e| format!("stage {k}: {e}"))?;
        if k == 0 {
            input = w.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect();
        }
        let out = w.output()?;
        x = unpad(seed, &out);
        if k + 1 < blocks.len() {
            planes.push(out);
        } else {
            output = out;
        }
        witnesses.push(Some(w));
    }
    Ok((witnesses, planes, input, output))
}

/// **D60 privacy gate: an `l`-block R13-rung run on hidden input `hidden`.**
/// Input 0 is the fixture's public sequence ([`rung`]'s); input `s > 0` is
/// the first admissible deterministic variant of it: its token rows rotated
/// by `5 s` and every word nudged by -1, 0 or +1, else only rotated, else
/// only nudged, else the token order reversed. Returns the run and which
/// variant it is.
fn d60pg_rung(l: usize, context: u8, hidden: usize) -> (Rung, String) {
    let RungPublic { ex, seed, shapes, blocks, model } = rung_public(l);
    let (x, _) = ex.load_seq(&shapes[0], "public", 0).unwrap();
    let (t, w) = (seed.tokens, seed.width);
    let rot = |x: &[i16], r: usize| -> Vec<i16> { (0..t * w).map(|i| x[((i / w + r) % t) * w + i % w]).collect() };
    let nudge = |x: &[i16], s: usize| -> Vec<i16> { x.iter().enumerate().map(|(i, &v)| v.saturating_add(((i * 7 + s) % 3) as i16 - 1)).collect() };
    let rev: Vec<i16> = (0..t * w).map(|i| x[(t - 1 - i / w) * w + i % w]).collect();
    let candidates: Vec<(String, Vec<i16>)> = if hidden == 0 {
        vec![("the fixture's public sequence".into(), x.clone())]
    } else {
        let r = (5 * hidden) % t;
        vec![
            (format!("the fixture's public sequence, token rows rotated by {r}, every word nudged by ((i 7 + {hidden}) mod 3) - 1"), nudge(&rot(&x, r), hidden)),
            (format!("the fixture's public sequence, token rows rotated by {r}"), rot(&x, r)),
            (format!("the fixture's public sequence, every word nudged by ((i 7 + {hidden}) mod 3) - 1"), nudge(&x, hidden)),
            ("the fixture's public sequence, token order reversed".into(), rev),
        ]
    };
    let mut why = Vec::new();
    for (what, x0) in candidates {
        match d60pg_chain(&seed, &shapes, &blocks, &x0) {
            Ok((witnesses, planes, input, output)) => {
                let ctx = [context; 32];
                let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&seed, ctx, 0, 0).unwrap(), &input, &output).unwrap();
                let st = RunStatement::new_bound(RunShape::accuracy(seed, l).unwrap(), ctx, expected, &blocks, &vec![(0, 0); l], &model).unwrap();
                return (Rung { st, blocks, src: Chain { witnesses, planes, tamper: None }, owners: Some(owners) }, what);
            }
            Err(e) => why.push(format!("{what}: {e}")),
        }
    }
    panic!("no admissible hidden input {hidden} for the R13 rung chain: {why:?}");
}

/// **D60's privacy-gate inputs: REGISTERED D55 fork-run bundles over R13
/// bases, written by the PRODUCTION capture writer** (`run_capture::write_bundle`),
/// for the Python D55 gate's R13 port (`staging_v25/scripts/zk60_native_rg_d55.py`).
/// `HL_D60PG_CASES` (default `R13_RUNG_H24:0,R13_RUNG_H24:1`) names
/// `PROFILE:hidden` pairs, each one honest `HL_D60PG_L`-fork run (default 3)
/// under the base's REGISTERED D55 run profile, proved on `L` workers,
/// verified with the recorder attached (arrays and public-table values),
/// export-replayed and written into `HL_D60PG_CAPTURE_DIR/d55-<profile>-s<hidden>`:
/// * `R13_RUNG_H24`: the public synthetic loader fixture `r13-h24-wide`
///   (layer 0 and its other-gate twin, [`rung_public`]); hidden input 0 is the
///   fixture's public sequence, input `s > 0` a deterministic variant of it
///   ([`d60pg_rung`]);
/// * a TRAINED R13 base (`R13_8B_T128_H24`, `R13_SHIELD_T128_H24`,
///   `R13_TINY_T128_LOW`): the run profile registered for real content, at
///   its true geometry, with ONE public synthetic block at every layer (the
///   A/B's recipe: `range16_tests::case`, tame diagonal weights; no trained
///   weights are on this host) and M10's admissible input family
///   (`((i 37 + 11 + s) mod (41 + 20 (s mod 3))) - 20`, the first admissible
///   `s` from `7 hidden`).
/// * `PROFILE:hidden:own` (a trained base only; 2026-11-02, the TS / census /
///   bases lane): the same, with layer 1 proved at its OWN norm constant
///   (cn_a, cn_m or ceps, the first that passes the trained door; outside
///   the R13 accuracy base, so the block and its digest are unchanged), so
///   fork 1's stage line carries an own-calibration clause; written to
///   `d55-<profile>-own-s<hidden>` and checked as its own PG-10 pair.
///
/// Test-only synthetic bundles, not for publication; the Python gate reads
/// them and they are deleted once recorded.
#[test]
#[ignore = "writes registered D55 R13 fork-run capture bundles; set HL_D60PG_CAPTURE_DIR"]
fn d60_privacy_gate_write_registered_r13_fork_bundles() {
    use crate::private_block::run_capture as cap;
    use crate::private_block::shape;
    let root = PathBuf::from(std::env::var("HL_D60PG_CAPTURE_DIR").expect("HL_D60PG_CAPTURE_DIR is not set: this test writes a directory of evidence and will not choose one for you"));
    let l: usize = env_or("HL_D60PG_L", 3usize);
    let cases: String = env_or("HL_D60PG_CASES", "R13_RUNG_H24:0,R13_RUNG_H24:1".to_string());
    let command = "HL_D60PG_CAPTURE_DIR=<dir> [HL_D60PG_CASES=<PROFILE:hidden,...>] [HL_D60PG_L=<L>] HL_R13_LOADER_FIXTURES=<fixtures> <hashline lib test binary> --ignored --exact --nocapture private_block::run::fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles";
    let mut n = 0usize;
    // per profile name: the run's shape and every bundle written for it
    let mut written: Vec<(String, crate::private_block::shape::Shape, Vec<PathBuf>)> = Vec::new();
    for case in cases.split(',').map(str::trim).filter(|c| !c.is_empty()) {
        // [TS / CENSUS / bases lane, 2026-11-02] `PROFILE:hidden[:own]`: the
        // optional `own` variant (a trained base only) proves layer 1 at its
        // OWN norm constant, so its stage line carries an own-calibration
        // clause (the gate's per-layer path); without it nothing changes
        let mut parts = case.splitn(3, ':');
        let name = parts.next().unwrap_or(case);
        let hidden = parts.next().unwrap_or("0");
        let own_variant = match parts.next() {
            None => false,
            Some("own") => true,
            Some(v) => panic!("{case}: unknown variant {v:?} (only `own`)"),
        };
        let hidden: usize = hidden.parse().unwrap_or_else(|_| panic!("{case}: the hidden-input index is not a number"));
        assert!(!(own_variant && name == "R13_RUNG_H24"), "{case}: the own-constant variant is for a trained base");
        let t0 = Instant::now();
        let dir = root.join(format!("d55-{}{}-s{hidden}", name.to_ascii_lowercase(), if own_variant { "-own" } else { "" }));
        let context = 210u8.wrapping_add((n as u8).wrapping_mul(3));
        let (rc, b, what, profile, base, run_sh) = if name == "R13_RUNG_H24" {
            let (mut r, what) = d60pg_rung(l, context, hidden);
            let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
            assert!(fr.is_registered(), "{case}: not under a registered D55 profile");
            let (rc, stats) = prove_run_with_forks(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), l).unwrap_or_else(|e| panic!("{case}: the honest fork run did not prove: {e}"));
            honest_stats_hold(&r.st, &stats);
            let b = d60pg_capture(&fr, &r.blocks, &rc, l);
            (rc, b, format!("the public synthetic R13 loader fixture r13-h24-wide (layer 0 and its other-gate twin (-4, -13), alternating); hidden input {hidden}: {what}"), fr.profile().to_string(), r.st.rs().profile().to_string(), r.st.rs().sh().clone())
        } else {
            let spec = shape::ACCURACY_PROFILES.iter().find(|s| s.name == name).unwrap_or_else(|| panic!("{case}: not an R13 accuracy profile"));
            let original = crate::private_block::range16_tests::built(spec.profile);
            let (sh, data, public, ff) = crate::private_block::range16_tests::case(original, 3);
            let blk = BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
            // the own-constant variant: layer 1 (or the last) at its own norm
            // constant -- cn_a, cn_m or ceps, which are outside the R13
            // accuracy base, so the block's public data (and its digest) are
            // the same at every layer -- the first that passes the trained
            // door (`Shape::with_layer_calibration`); every other layer, and
            // every layer of a plain case, at the run's calibration
            let own_layer = if own_variant { 1usize.min(l - 1) } else { usize::MAX };
            let (own, own_what, own_shape) = if own_variant {
                use crate::private_block::trained_statement::{apply_own, cal_field, OWN_FIELDS};
                let base = sh.norm_calibration();
                let mut found = None;
                for (i, delta) in [(2usize, 1i64), (3, 1), (4, 1), (2, -1), (3, -1)] {
                    let mut own = [None; 11];
                    own[i] = Some(cal_field(&base, i) + delta);
                    if let Ok(s1) = apply_own(&base, &own).and_then(|c| sh.with_layer_calibration(&c)) {
                        found = Some((own, format!("layer {own_layer} at its OWN {} {} (the run's is {})", OWN_FIELDS[i].2, cal_field(&base, i) + delta, cal_field(&base, i)), s1));
                        break;
                    }
                }
                let (own, what, s1) = found.unwrap_or_else(|| panic!("{case}: no own norm constant passes the trained door"));
                (own, what, Some(s1))
            } else {
                ([None; 11], String::new(), None)
            };
            let shape_at = |k: usize| -> crate::private_block::shape::Shape { if k == own_layer { own_shape.clone().expect("the own layer's shape") } else { sh.clone() } };
            // the first admissible input of M10's family whose WHOLE chain
            // builds (wherever the previous rule did not panic, this is its
            // choice: it took the first input admissible at layer 0 and then
            // required every later layer to build)
            let ids = Ids::new(&sh).unwrap();
            let chain = |x0: Vec<i16>| -> Result<(Vec<Option<Witness>>, Vec<Vec<i16>>, Vec<i16>, Vec<i16>), String> {
                let (mut x, mut witnesses, mut planes, mut input, mut output) = (x0, Vec::new(), Vec::new(), Vec::new(), Vec::new());
                for k in 0..l {
                    let w = witness::build_accuracy(&shape_at(k), &public, &ff, &data, &x).map_err(|e| format!("layer {k}: {e}"))?;
                    if k == 0 {
                        input = w.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect::<Vec<i16>>();
                    }
                    let out = w.output().unwrap();
                    x = unpad(&sh, &out);
                    if k + 1 < l {
                        planes.push(out);
                    } else {
                        output = out;
                    }
                    witnesses.push(Some(w));
                }
                Ok((witnesses, planes, input, output))
            };
            let mut s = 7 * hidden;
            let (witnesses, planes, input, output) = loop {
                let x0: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + s) % (41 + 20 * (s % 3))) as i16 - 20).collect();
                match chain(x0) {
                    Ok(c) => break c,
                    Err(_) if s < 7 * hidden + 6 => s += 1,
                    Err(e) => panic!("{case}: no admissible synthetic input: {e}"),
                }
            };
            let run_profile = run::accuracy_run_profile(sh.profile).expect("an R13 base has a registered D12a run profile");
            let mut prov = Provenance::recipe("D60 privacy-gate fixture (public synthetic)", 1.0, [3; 32], [4; 32]);
            prov.rope_theta = shape::trained_rope_theta(sh.profile).expect("a trained profile's pinned RoPE base");
            prov.rope_scaling = shape::trained_rope_scaling(sh.profile).expect("a trained profile's pinned RoPE transform");
            let source = ModelSource { kind: SourceKind::PublicSyntheticRecipe, repo: "synthetic/d60-privacy-gate".into(), revision: "d60".into(), weights_sha256: [0; 32], config_sha256: [0; 32], checkpoint_parameters: 0, checkpoint_layers: l as u32 };
            let r0 = LayerRecord::of_block(0, &blk, vec![]);
            let records: Vec<LayerRecord> = (0..l)
                .map(|i| {
                    let mut r = r0.clone();
                    r.index = i as u32;
                    if i == own_layer {
                        r.own = own;
                    }
                    r
                })
                .collect();
            let model = TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(&sh, run_profile, source, IntegerCalibration::as_the_code_proves(&sh, &prov), records).unwrap_or_else(|e| panic!("{case}: the synthetic {l}-layer statement: {e}"));
            let c = [context; 32];
            let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&sh, c, 0, 0).unwrap(), &input, &output).unwrap();
            let st = RunStatement::new_bound_from_digests(RunShape::new(sh.clone(), l, run_profile).unwrap(), c, expected, vec![blk.digest(); l], &vec![(0, 0); l], &model).unwrap();
            let fr = ForkRun::new(&st, D55OptIn::registered_profile()).unwrap();
            assert!(fr.is_registered(), "{case}: not under a registered D55 profile");
            let rep = RepeatBlock::new(&blk, l);
            let mut src = Chain { witnesses, planes, tamper: None };
            let (rc, stats) = prove_run_with_forks(&fr, &rep, &mut src, owners, l).unwrap_or_else(|e| panic!("{case}: the honest fork run did not prove: {e}"));
            honest_stats_hold(&st, &stats);
            let b = d60pg_capture(&fr, &rep, &rc, l);
            let own_note = if own_variant { format!("; {own_what}, so its stage line carries the own-calibration clause") } else { String::new() };
            (rc, b, format!("the registered TRAINED base {run_profile} at its true geometry with ONE public synthetic block at every layer (range16_tests::case, tame diagonal weights, 3 activation groups; no trained weights){own_note}; hidden input {hidden}: M10's input family at s = {s}"), fr.profile().to_string(), run_profile.to_string(), st.rs().sh().clone())
        };
        let frames: Vec<Vec<u8>> = rc.frames().cloned().collect();
        let note = format!(
            "D60 privacy-gate fixture (2026-11-02): one honest {l}-fork D55 run under the REGISTERED D55 run profile `{profile}` (base `{base}`), {what}; proved and verified on this path: {}. TEST-ONLY SYNTHETIC BUNDLE, NOT FOR PUBLICATION: no real content; delete once recorded.",
            crate::gpu::label()
        );
        cap::write_bundle(&dir, &b, &frames, &note, command).unwrap_or_else(|e| panic!("{case}: the production capture writer refused the registered fork run: {e}"));
        eprintln!(
            "D60-PG-BUNDLE {case} -> {} | {profile} | {l} forks, {} stage bytes, tail {} B, frames {:?} B | {:.1} s | {what}",
            dir.display(),
            b.stages.iter().map(|s| s.len()).sum::<usize>(),
            b.fork_tail.as_ref().map(|t| t.len()).unwrap_or(0),
            frames.iter().map(|f| f.len()).collect::<Vec<_>>(),
            t0.elapsed().as_secs_f64()
        );
        // an own-constant variant is its own PG-10 pair
        let wkey = if own_variant { format!("{name}+own") } else { name.to_string() };
        match written.iter_mut().find(|(p, _, _)| *p == wkey) {
            Some((_, _, dirs)) => dirs.push(dir.clone()),
            None => written.push((wkey, run_sh, vec![dir.clone()])),
        }
        n += 1;
    }
    assert!(n > 0, "HL_D60PG_CASES names no case");
    // D60 review F3: the Rust gate's capture checks on every bundle exactly as
    // the production writer laid it on disk (the first two of a profile as
    // the PG-10 pair)
    let mut verdicts = Vec::new();
    for (name, sh, dirs) in &written {
        for (i, d) in dirs.iter().enumerate() {
            let other = if dirs.len() > 1 { Some(dirs[if i == 0 { 1 } else { 0 }].as_path()) } else { None };
            let v = crate::private_block::w16_privacy_gate_tests::d60_registered_bundle_checks(sh, d, other).unwrap_or_else(|e| panic!("{name}: the Rust gate checks on the written bundle FAILED: {e}"));
            eprintln!("D60-PG-RUST {v}");
            verdicts.push(v);
        }
    }
    eprintln!("D60-PG-RUST VERDICT {} bundles, every check PASS and every control fired", verdicts.len());
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

// ------------------------------------------------------------------ D60 review closure (2026-11-02)

/// a fresh scratch directory for one test (the trained tests' temp root)
fn scratch(tag: &str) -> PathBuf {
    crate::private_block::trained_block_tests::base_dir(&format!("d60-close-{tag}"))
}

/// **D60 REVIEW F1: THE FORK VERIFIER'S OWN PREFLIGHT HAS NEGATIVE CONTROLS.**
/// At the R13 rung with `L = 3` and an HONEST receipt, the verifier is handed
/// public blocks that are not the statement's, and each case is refused by
/// its ruling BEFORE any frame is decoded (no `D55 wire:` text) — through
/// `verify_run_with_forks` and through `verify_run_with_forks_from_dir`, the
/// latter on the honest directory AND on a directory that does not exist
/// (so the refusal comes before the directory is even listed):
/// * (a1) blocks 0 and 1 swapped: block 1 (the other-gate twin) at stage 0
///   meets stage 0's gate denominator (the R13 stage shape, CS-1's check);
/// * (a2) block 1 with one public weight changed — the SAME stage shape,
///   another digest: refused by CS-6 and by nothing else (the preflight with
///   its digest loop off accepts it, so the loop is what this case pins);
/// * (b) a list of two blocks: CS-6's count;
/// * (c1) block 0 at stage 1 (a block that fits another stage's shape);
/// * (c2) block 1 with a feed-forward word outside its support: ruling CS-1;
/// * (d) two fork frames (and, on disk, a directory missing fork 2).
///
/// The honest prover refuses (a1), (a2) and (c2) by the same rulings.
#[test]
fn d60_f1_the_fork_verifier_refuses_blocks_that_are_not_the_statements() {
    let mut r = rung(3, 190);
    let (rc, _) = prove_forks(&mut r, 3);
    let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
    verify_run_with_forks(&fr, &r.blocks, &rc, 3).expect("the honest L3 receipt verifies");
    let root = scratch("f1");
    let dir = root.join("run");
    std::fs::create_dir(&dir).unwrap();
    write_fork_receipt(&dir, &rc).unwrap();
    verify_run_with_forks_from_dir(&fr, &r.blocks, &dir, 3).expect("the honest L3 receipt verifies from its directory");
    let missing = root.join("no-such-run-directory");
    // the mutated block lists
    let changed_weight = |blocks: &[BlockPublic]| -> Vec<BlockPublic> {
        let mut v = blocks.to_vec();
        let w = &mut v[1].attention.wq;
        let i = w.iter().position(|&x| x != 0).expect("a nonzero wq word");
        w[i] = if w[i] > 0 { w[i] - 1 } else { w[i] + 1 };
        v
    };
    let ssh = r.st.stage_shape(1).unwrap();
    let off_support = |blocks: &[BlockPublic]| -> Vec<BlockPublic> {
        let mut v = blocks.to_vec();
        let at = if ssh.d_pad > ssh.width { ssh.width * ssh.f_pad } else { ssh.hidden };
        assert!(ssh.d_pad > ssh.width || ssh.f_pad > ssh.hidden, "the rung's feed-forward plane has no padding to write into");
        v[1].feed_forward.wg_t[at] = 1;
        v
    };
    let swapped = |blocks: &[BlockPublic]| -> Vec<BlockPublic> {
        let mut v = blocks.to_vec();
        v.swap(0, 1);
        v
    };
    let a2 = changed_weight(&r.blocks[..]);
    assert_ne!(a2[1].digest(), r.blocks[1].digest());
    assert!(a2[1].check_for_shape(&ssh).is_ok(), "the changed-weight block does not fit its stage shape, so (a2) would not isolate CS-6");
    let mut c1 = r.blocks.clone();
    c1[1] = r.blocks[0].clone();
    let cases: Vec<(&str, Vec<BlockPublic>, &str)> = vec![
        ("(a1) blocks 0 and 1 swapped", swapped(&r.blocks[..]), "gate denominator differs from the stage shape"),
        ("(a2) block 1 with one public weight changed", a2.clone(), "ruling CS-6 — block 1 handed to the run is not the block the run statement names"),
        ("(b) two blocks for a three-block statement", r.blocks[..2].to_vec(), "ruling CS-6 — the run statement names 3 blocks and 2 public statements were handed"),
        ("(c1) block 0 at stage 1", c1, "private run: block 1: R13 public folded gate denominator differs from the stage shape"),
        ("(c2) block 1 with a feed-forward word outside its support", off_support(&r.blocks[..]), "ruling CS-1"),
    ];
    for (what, blocks, want) in &cases {
        let e = verify_run_with_forks(&fr, blocks, &rc, 3).err().unwrap_or_else(|| panic!("{what}: THE FORK VERIFIER ACCEPTED BLOCKS THAT ARE NOT THE STATEMENT'S"));
        assert!(e.contains(*want) && !e.contains("D55 wire:"), "{what}: not refused by its ruling before any frame was decoded: {e}");
        for (d, which) in [(&dir, "the honest directory"), (&missing, "a directory that does not exist")] {
            let e2 = verify_run_with_forks_from_dir(&fr, blocks, d, 3).err().unwrap_or_else(|| panic!("{what}: THE FORK VERIFIER ACCEPTED IT FROM {which}"));
            assert_eq!(e2, e, "{what}: from {which}, the refusal is not the preflight's (before the directory is listed)");
        }
        eprintln!("D60 F1 | {what} | REFUSED by the preflight (in memory, from the directory and before a missing directory is listed): {e}");
    }
    // (a2) is refused by the digest loop ALONE: the preflight without it admits it
    preflight(&r.st, &a2, false).expect("the preflight without its digest loop refuses the changed-weight block: (a2) does not isolate CS-6");
    assert!(preflight(&r.st, &a2, true).unwrap_err().contains("ruling CS-6"));
    // (d) the frame count: two fork frames, and a directory missing fork 2
    let short = ForkReceipt { forks: rc.forks[..2].to_vec(), ..rc.clone() };
    let e = verify_run_with_forks(&fr, &r.blocks, &short, 3).err().expect("TWO FORK FRAMES VERIFIED FOR A THREE-BLOCK RUN");
    assert!(e.contains("2 fork frames were offered, this run has 3") && !e.contains("D55 wire:"), "{e}");
    eprintln!("D60 F1 | (d) two fork frames for a three-block run | REFUSED before any frame is decoded: {e}");
    let gone = root.join("run-missing-fork-2");
    std::fs::create_dir(&gone).unwrap();
    write_fork_receipt(&gone, &rc).unwrap();
    std::fs::remove_file(gone.join(d55_fork_file_name(2))).unwrap();
    let e = verify_run_with_forks_from_dir(&fr, &r.blocks, &gone, 3).err().expect("A DIRECTORY MISSING FORK 2 VERIFIED");
    assert!(e.contains("is missing d55-fork-002.bin") && !e.contains("D55 wire:"), "{e}");
    eprintln!("D60 F1 | (d) a directory missing fork 2 | REFUSED before any frame is read: {e}");
    // the honest prover refuses the same lists by the same rulings
    type Mutate<'m> = &'m dyn Fn(&[BlockPublic]) -> Vec<BlockPublic>;
    let prover_cases: [(&str, Mutate, &str); 3] = [
        ("(a1) blocks 0 and 1 swapped", &swapped, "gate denominator differs from the stage shape"),
        ("(a2) block 1 with one public weight changed", &changed_weight, "ruling CS-6"),
        ("(c2) a feed-forward word outside its support", &off_support, "ruling CS-1"),
    ];
    for (i, (what, mutate, want)) in prover_cases.into_iter().enumerate() {
        let mut p = rung(3, 191 + i as u8);
        let blocks = mutate(&p.blocks[..]);
        let fp = ForkRun::new(&p.st, D55OptIn::registered_profile()).unwrap();
        let e = prove_run_with_forks(&fp, &blocks, &mut p.src, p.owners.take().unwrap(), 3).err().unwrap_or_else(|| panic!("{what}: THE HONEST FORK PROVER PROVED A RUN OVER BLOCKS THAT ARE NOT THE STATEMENT'S"));
        assert!(e.contains(want), "{what}: the prover's refusal is not its ruling: {e}");
        eprintln!("D60 F1 | the honest prover on {what} | REFUSED: {e}");
    }
    std::fs::remove_dir_all(&root).unwrap();
}

/// **D60 REVIEW F3: THE CLI FAILS CLOSED FOR A D55 RUN UNTIL THE PRIVACY GATE
/// HAS PASSED.** The admission rule in both arms of the production constant,
/// then the CLI end to end on a copy of the public synthetic fixture (`L =
/// 1`): (1) `stack-prove --d55-workers 1` WITHOUT the acknowledgement is
/// refused and creates nothing; the acknowledgement without `--d55-workers`
/// is refused too; (2) WITH it the run proves, and its directory holds the
/// three frames and the marker and nothing else, while `segments.json` and
/// `statement.json` name no marker; (3) `stack-verify --d55-workers` verifies
/// and publishes the statement (its `d55-publication` event names the
/// marker); (4) a copy with the marker removed still verifies against the
/// SAME published statement and `segments.json` (so the marker is no
/// verified byte) and is reported ABSENT; (5) a marker of other content, a
/// link or a directory under the marker's name is refused by the reader; (6)
/// `--verify-in-process` reads the marked directory.
#[test]
fn d60_f3_the_cli_fails_closed_for_a_d55_run_until_the_privacy_gate_passes() {
    use crate::private_block::trained_block::{d55_prove_admission, trained_stack_prove_command, trained_stack_verify_command, D55_TEST_RECEIPT_FLAG};
    use crate::private_block::trained_block_tests::{copy_tree_for_tests, verifier_copy};
    // the production constant: false until the coordinator's commit
    assert!(!D55_REAL_CONTENT_PRIVACY_GATE_PASSED, "D55_REAL_CONTENT_PRIVACY_GATE_PASSED was flipped: update this test with the gate verdict recorded in D60");
    // the rule, both arms of the constant
    for gate in [false, true] {
        assert_eq!(d55_prove_admission(None, false, gate), Ok(false), "a D12a run is never affected");
        assert!(d55_prove_admission(None, true, gate).unwrap_err().contains("only with --d55-workers"));
        assert_eq!(d55_prove_admission(Some(3), true, gate), Ok(true), "the acknowledgement always marks a test receipt");
    }
    let e = d55_prove_admission(Some(3), false, false).unwrap_err();
    assert!(e.contains("D60 review F3") && e.contains(D55_TEST_RECEIPT_FLAG), "{e}");
    assert_eq!(d55_prove_admission(Some(3), false, true), Ok(false), "after the gate passes, a D55 run needs no acknowledgement");
    // the CLI on a copy of the fixture
    let root = scratch("f3");
    let ex = root.join("r13-h24-wide");
    copy_tree_for_tests(&fixtures().join("r13-h24-wide"), &ex);
    let vc = verifier_copy(&ex);
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    let (exd, vcd) = (ex.display().to_string(), vc.display().to_string());
    let out = root.join("run");
    let od = out.display().to_string();
    let unverified = root.join("run.unverified-statement");
    // (1) refused without the acknowledgement; nothing exists
    assert_eq!(trained_stack_prove_command(&s(&["--export", &exd, "--seq", "public", "--out", &od, "--d55-workers", "1"])), 1, "A D55 FORK RUN PROVED WITHOUT THE TEST-RECEIPT ACKNOWLEDGEMENT");
    assert!(!out.exists() && !unverified.exists(), "the refused prover created something");
    assert_eq!(trained_stack_prove_command(&s(&["--export", &exd, "--seq", "public", "--out", &od, D55_TEST_RECEIPT_FLAG])), 1, "the acknowledgement was accepted without --d55-workers");
    assert!(!out.exists() && !unverified.exists());
    eprintln!("D60 F3 | stack-prove --d55-workers 1 without {D55_TEST_RECEIPT_FLAG}: REFUSED, nothing created; the flag without --d55-workers: REFUSED");
    // (2) accepted with it; the marker beside the frames, nowhere else
    assert_eq!(trained_stack_prove_command(&s(&["--export", &exd, "--seq", "public", "--out", &od, "--d55-workers", "1", D55_TEST_RECEIPT_FLAG])), 0, "stack-prove --d55-workers with the acknowledgement failed");
    assert_eq!(std::fs::read(out.join(D55_TEST_RECEIPT_MARKER_FILE)).unwrap(), D55_TEST_RECEIPT_MARKER_TEXT);
    let mut names: Vec<String> = std::fs::read_dir(&out).unwrap().map(|e| e.unwrap().file_name().to_string_lossy().to_string()).collect();
    names.sort();
    let mut want: Vec<String> = d55_file_names(1).into_iter().chain(std::iter::once(D55_TEST_RECEIPT_MARKER_FILE.to_string())).collect();
    want.sort();
    assert_eq!(names, want, "the marked run directory");
    let segs = std::fs::read_to_string(unverified.join("segments.json")).unwrap();
    let stmt = std::fs::read_to_string(unverified.join("statement.json")).unwrap();
    assert!(!segs.contains("NOT_FOR_PUBLICATION") && !stmt.contains("NOT_FOR_PUBLICATION") && segs.matches("\"file\"").count() == 3, "the marker reached segments.json or statement.json");
    let id = stmt.split("\"trained_statement_identity\": \"").nth(1).unwrap().split('"').next().unwrap().to_string();
    assert!(run::fork::d55_test_receipt_marker(&out).unwrap());
    // (3) the fresh verifier verifies, publishes, and reports the marker
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id, "--d55-workers", "1"])), 0, "stack-verify --d55-workers refused the marked test receipt");
    assert!(out.join("statement").join("statement.json").exists() && !unverified.exists(), "the verified statement was not published");
    assert!(run::fork::d55_test_receipt_marker(&out).unwrap(), "the marker did not survive the verification");
    // (4) the marker is no verified byte: without it the same statement and
    // segments.json still check, and it is reported ABSENT
    let bare = root.join("run-without-marker");
    copy_tree_for_tests(&out, &bare);
    std::fs::remove_file(bare.join(D55_TEST_RECEIPT_MARKER_FILE)).unwrap();
    assert!(!run::fork::d55_test_receipt_marker(&bare).unwrap());
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &bare.display().to_string(), "--expect-statement", &id, "--d55-workers", "1"])), 0, "without its marker, the receipt no longer checks against its own published statement");
    // (5) anything else under the marker's name is refused by the reader
    let marker = out.join(D55_TEST_RECEIPT_MARKER_FILE);
    let mut other = D55_TEST_RECEIPT_MARKER_TEXT.to_vec();
    other[0] ^= 0x20;
    let elsewhere = root.join("elsewhere.txt");
    std::fs::write(&elsewhere, D55_TEST_RECEIPT_MARKER_TEXT).unwrap();
    for what in ["a marker of other content (its length)", "a symbolic link to a true marker", "a directory"] {
        std::fs::remove_file(&marker).unwrap();
        match what {
            "a directory" => std::fs::create_dir(&marker).unwrap(),
            "a symbolic link to a true marker" => std::os::unix::fs::symlink(&elsewhere, &marker).unwrap(),
            _ => std::fs::write(&marker, &other).unwrap(),
        }
        assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id, "--d55-workers", "1"])), 1, "{what} under the marker's name was accepted");
        let e = d55_test_receipt_marker(&out).unwrap_err();
        eprintln!("D60 F3 | {what} under the marker's name | REFUSED: {e}");
        if marker.is_dir() {
            std::fs::remove_dir(&marker).unwrap();
        } else {
            std::fs::remove_file(&marker).unwrap();
        }
        std::fs::write(&marker, D55_TEST_RECEIPT_MARKER_TEXT).unwrap();
    }
    assert_eq!(trained_stack_verify_command(&s(&["--export", &vcd, "--artifact", &od, "--expect-statement", &id, "--d55-workers", "1"])), 0, "the restored marked receipt no longer verifies");
    // (6) --verify-in-process reads the marked directory
    let o2 = root.join("run-in-process");
    assert_eq!(trained_stack_prove_command(&s(&["--export", &exd, "--seq", "public", "--out", &o2.display().to_string(), "--d55-workers", "1", D55_TEST_RECEIPT_FLAG, "--verify-in-process"])), 0, "stack-prove --verify-in-process on a marked run failed");
    assert!(o2.join("statement").join("statement.json").exists() && run::fork::d55_test_receipt_marker(&o2).unwrap());
    eprintln!("D60 F3 | with {D55_TEST_RECEIPT_FLAG}: proved, the directory marked {D55_TEST_RECEIPT_MARKER_FILE} (3 frames + the marker; segments.json and statement.json name no marker); stack-verify verifies and reports it; the receipt without its marker checks against the same statement; other content, a link or a directory under its name is refused; --verify-in-process reads the marked directory");
    std::fs::remove_dir_all(&root).unwrap();
}

/// **D60 REVIEW F4: A FIFO OR A SYMBOLIC LINK SWAPPED IN BETWEEN A BOUNDED
/// READER'S CHECK AND ITS OPEN IS REFUSED, WITHOUT HANGING**, on this target
/// (the macOS work box, where the open flags were x86-64-Linux-only). For the
/// D55 frame reader, D12a's segment reader and regular-file reader, and the
/// token-table reader: a regular file of the counted length passes the
/// `lstat` checks, then the test hook (`run::before_open_hook_for_tests`)
/// swaps in (i) a FIFO with no writer — without `O_NONBLOCK` the open would
/// block for ever; the reader runs on its own thread and the test fails at a
/// timeout instead of hanging — refused by the `fstat` re-check; (ii) a
/// symbolic link to a regular file of the SAME length — without
/// `O_NOFOLLOW` it would be followed and read — refused at the open
/// (`ELOOP`).
#[test]
fn d60_f4_a_fifo_or_symlink_swapped_in_after_the_check_is_refused_without_hanging() {
    use std::sync::atomic::AtomicBool;
    use std::sync::Arc;
    // (`HL_D60_F4_MUTANT=1` skips this precondition only, for the closure's
    // mutation check: a build without the macOS values must then FAIL below)
    if std::env::var("HL_D60_F4_MUTANT").is_err() {
        assert!(run::NOFOLLOW_NONBLOCK.is_some(), "this target has no O_NOFOLLOW | O_NONBLOCK values: the window between the check and the open is unprotected (D60 review F4)");
    }
    let root = scratch("f4");
    // the D12a segment reader's counted length, from a one-block rung statement
    let seg_want = {
        let r = rung(1, 195);
        super::super::super::wire::segment_len(&r.st.stage_layout(0).unwrap(), r.st.seg_geom(0).unwrap())
    };
    let table_want = 4096usize;
    // (`HL_D60_F4_SWAPS`, e.g. `symlink`, narrows the swaps for the mutation check)
    let swaps: Vec<String> = std::env::var("HL_D60_F4_SWAPS").map(|v| v.split(',').map(str::to_string).collect()).unwrap_or_else(|_| vec!["FIFO".into(), "symlink".into()]);
    for reader in ["D55 frame", "D12a segment", "D12a regular file", "token table"] {
        for swap in swaps.iter().map(String::as_str) {
            let tag = format!("{}-{}", reader.replace(' ', "-"), swap);
            let p = root.join(format!("{tag}.bin"));
            let decoy = root.join(format!("{tag}.decoy"));
            let want = if reader == "D12a segment" { seg_want } else { table_want };
            let bytes = vec![7u8; want];
            std::fs::write(&p, &bytes).unwrap();
            std::fs::write(&decoy, &bytes).unwrap();
            let sha = crate::private_block::trained_block::hex(&crate::private_block::trained_block::sha256(&bytes));
            let fired = Arc::new(AtomicBool::new(false));
            let (tx, rx) = std::sync::mpsc::channel();
            let (fired2, swap2, reader2) = (fired.clone(), swap.to_string(), reader.to_string());
            std::thread::spawn(move || {
                let st = (reader2 == "D12a segment").then(|| rung(1, 195).st);
                run::before_open_hook_for_tests(Box::new(move |path: &std::path::Path| {
                    std::fs::remove_file(path).unwrap();
                    if swap2 == "FIFO" {
                        assert!(std::process::Command::new("mkfifo").arg(path).status().map(|x| x.success()).unwrap_or(false), "mkfifo");
                    } else {
                        std::os::unix::fs::symlink(&decoy, path).unwrap();
                    }
                    fired2.store(true, Ordering::SeqCst);
                }));
                let r: Result<(), String> = match reader2.as_str() {
                    "D55 frame" => read_frame_bounded("fork frame 0", &p, want, usize::MAX).map(|_| ()),
                    "D12a segment" => run::read_segment_bounded(st.as_ref().unwrap(), 0, &p).map(|_| ()),
                    "D12a regular file" => run::read_regular_file_bounded(&p, want as u64, true).map(|_| ()),
                    _ => crate::private_block::token_io::load::read_exact_streamed(&p, want, &sha, |_| {}),
                };
                let _ = tx.send(r);
            });
            let r = rx.recv_timeout(std::time::Duration::from_secs(60)).unwrap_or_else(|_| panic!("{reader}, a {swap} swapped in after the check: THE READER HUNG (no O_NONBLOCK on this target?)"));
            assert!(fired.load(Ordering::SeqCst), "{reader}, {swap}: the swap hook never ran (the reader did not open through run::open_nofollow_nonblock)");
            let e = r.err().unwrap_or_else(|| panic!("{reader}: A {swap} SWAPPED IN AFTER THE CHECK WAS READ (no O_NOFOLLOW on this target?)"));
            let wanted = if swap == "FIFO" { "changed after its check" } else { "cannot be opened as a regular file" };
            assert!(e.contains(wanted), "{reader}, {swap}: refused, but not at the open / fstat re-check: {e}");
            eprintln!("D60 F4 | {reader} | a {swap} swapped in between the lstat and the open | REFUSED without hanging: {e}");
        }
    }
    std::fs::remove_dir_all(&root).unwrap();
}

/// **D60 REVIEW F7: the on-disk reader checks each frame's header against the
/// verifier's own values before it reads the next frame.** A run directory
/// whose frame `j` carries a wrong header is refused by THAT header, and a
/// FIFO standing in for a LATER frame is never reached (its refusal would
/// name it): the head's binding (the tail a FIFO), the head's S0 tag (fork 0
/// a FIFO), fork 0's binding (fork 1 a FIFO), fork 1's start tag (fork 2 a
/// FIFO), the tail's binding; the honest directory verifies.
#[test]
fn d60_f7_the_on_disk_reader_checks_each_header_before_it_reads_the_next_frame() {
    let mut r = rung(3, 196);
    let (rc, _) = prove_forks(&mut r, 3);
    let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
    let root = scratch("f7");
    let flip = |p: &std::path::Path, at: usize| {
        let mut b = std::fs::read(p).unwrap();
        b[at] ^= 1;
        std::fs::write(p, b).unwrap();
    };
    let head_len = super::super::super::wire::fork::head_len(3);
    let cases: [(&str, String, usize, Option<String>, &str); 5] = [
        ("the head's binding", D55_HEAD_FILE.to_string(), 8, Some(D55_TAIL_FILE.to_string()), "the head belongs to another run"),
        ("the head's S0 tag", D55_HEAD_FILE.to_string(), head_len - 1, Some(d55_fork_file_name(0)), "the head's S0 tag is not the verifier's own S0"),
        ("fork 0's binding", d55_fork_file_name(0), 8, Some(d55_fork_file_name(1)), "fork frame 0 belongs to another run"),
        ("fork 1's start tag", d55_fork_file_name(1), 60, Some(d55_fork_file_name(2)), "fork frame 1's start tag is not the verifier's own fork-1 position"),
        ("the tail's binding", D55_TAIL_FILE.to_string(), 8, None, "the tail belongs to another run"),
    ];
    for (i, (what, file, at, fifo, want)) in cases.iter().enumerate() {
        let d = root.join(format!("case-{i}"));
        std::fs::create_dir(&d).unwrap();
        write_fork_receipt(&d, &rc).unwrap();
        flip(&d.join(file), *at);
        if let Some(f) = fifo {
            std::fs::remove_file(d.join(f)).unwrap();
            assert!(std::process::Command::new("mkfifo").arg(d.join(f)).status().map(|x| x.success()).unwrap_or(false), "mkfifo");
        }
        let e = read_fork_receipt(&fr, &d).err().unwrap_or_else(|| panic!("{what}: THE READER ACCEPTED A WRONG HEADER"));
        assert!(e.contains(*want) && !e.contains("not a regular file"), "{what}: not refused by that header before the next frame was read: {e}");
        let e2 = verify_run_with_forks_from_dir(&fr, &r.blocks, &d, 3).err().expect("verified");
        assert_eq!(e2, e, "{what}: the directory verifier's refusal is not the reader's");
        eprintln!("D60 F7 | {what} wrong{} | REFUSED by the reader at that header: {e}", fifo.as_ref().map(|f| format!(" ({f} a FIFO, never reached)")).unwrap_or_default());
    }
    let d = root.join("honest");
    std::fs::create_dir(&d).unwrap();
    write_fork_receipt(&d, &rc).unwrap();
    verify_run_with_forks_from_dir(&fr, &r.blocks, &d, 3).expect("the honest directory verifies");
    std::fs::remove_dir_all(&root).unwrap();
}

/// **D60 REVIEW F8 (b): a prover whose EVERY fork worker panics FAILS, and
/// does not hang.** `L = 3` on two workers, so a third job waits on the
/// rendezvous queue after both workers have panicked on their first (before
/// the fix the feeder blocked there for ever, the receiver kept alive in its
/// `Mutex`). The prover runs on its own thread and the test fails at a
/// timeout instead of hanging.
#[test]
fn d60_f8_a_prover_whose_every_worker_panics_fails_and_does_not_hang() {
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let mut r = rung(3, 197);
        let fr = ForkRun::new(&r.st, D55OptIn::registered_profile()).unwrap();
        let _p = PanicInEveryFork::on();
        let res = prove_run_with_forks(&fr, &r.blocks, &mut r.src, r.owners.take().unwrap(), 2).map(|_| ());
        let _ = tx.send(res);
    });
    let res = rx.recv_timeout(std::time::Duration::from_secs(120)).expect("THE FORK PROVER HUNG after every worker panicked (D60 review F8 (b))");
    let e = res.err().expect("a prover whose every fork panicked returned a receipt");
    assert!(e.contains("its worker panicked") && e.contains("D60 F8 test switch"), "{e}");
    eprintln!("D60 F8 | every fork worker panics (L3, 2 workers) | the prover FAILS and returns: {e}");
}

/// **D60 REVIEW F2, tooling (`#[ignore]`d): write an `L`-layer R13 export
/// from the public synthetic fixture `r13-h24-wide`** into
/// `HL_D60_EXPORT_DIR` (a new directory, outside the repository), `L` =
/// `HL_D60_EXPORT_L` (default 3): every layer is the fixture's layer 0 (its
/// arrays copied, its manifest with `"layer": k`), the variant
/// `r13-h24-wide-x<L>-d60`, and the public sequence `seq_public` chained by
/// the native witness builder (`x_in` of layer `k + 1` is the builder's
/// output of layer `k`; `stack-prove`'s parity pass checks each against the
/// builder again). Public synthetic data only: no real content. With
/// `HL_D60_EXPORT_UP_TO=1`, `L` is a MAXIMUM: the export holds the longest
/// admissible prefix of the repeated-layer chain (the residual stream grows
/// layer by layer until the norm's range refuses).
#[test]
#[ignore = "D60 F2 tooling: HL_D60_EXPORT_DIR (new), HL_D60_EXPORT_L, HL_D60_EXPORT_UP_TO"]
fn d60_close_write_r13_multi_layer_test_export() {
    use crate::private_block::trained_block::{hex, sha256};
    let out = PathBuf::from(std::env::var("HL_D60_EXPORT_DIR").expect("HL_D60_EXPORT_DIR names the new export directory"));
    let max_l: usize = env_or("HL_D60_EXPORT_L", 3usize);
    let up_to = std::env::var("HL_D60_EXPORT_UP_TO").is_ok_and(|v| v == "1");
    assert!(!out.exists(), "{} exists; the export is written into a new directory", out.display());
    let src = fixtures().join("r13-h24-wide");
    let p0 = rung_public(1);
    let (x0, _) = p0.ex.load_seq(&p0.shapes[0], "public", 0).unwrap();
    // the chain first: the longest admissible prefix (or exactly `max_l`)
    let mut chain: Vec<(Vec<i16>, Vec<i16>)> = Vec::new();
    let mut x = x0;
    let lay = crate::private_block::layout::Layout::for_shape(&p0.shapes[0]).unwrap();
    for k in 0..max_l {
        // the sealing pass's two refusals: the builder's, and CS-3's lookup misses
        let built = witness::build_for_block(&p0.shapes[0], &p0.blocks[0], &x).and_then(|w| crate::private_block::protocol::check_lookup_misses(&p0.shapes[0], &lay, &p0.blocks[0], &w).map(|_| w));
        match built {
            Ok(w) => {
                let y = unpad(&p0.seed, &w.output().unwrap());
                chain.push((x, y.clone()));
                x = y;
            }
            Err(e) if up_to && k > 0 => {
                eprintln!("D60 F2 EXPORT | layer {k} of the repeated-layer chain is not admissible ({e}); the export holds layers 0..{k}");
                break;
            }
            Err(e) => panic!("layer {k} of the repeated-layer chain is not admissible: {e}"),
        }
    }
    let l = chain.len();
    let variant = format!("r13-h24-wide-x{l}-d60");
    let manifest0 = std::fs::read_to_string(src.join("layer_00/manifest.json")).unwrap();
    assert_eq!(manifest0.matches("\"layer\": 0\n}").count(), 1, "the fixture manifest's layer field");
    let seq = out.join("seq_public");
    std::fs::create_dir_all(&seq).unwrap();
    let (mut layer_entries, mut arrays) = (Vec::new(), Vec::new());
    let arr = |name: &str, b: &[u8]| format!("    \"{name}\": {{\n      \"dtype\": \"int16\",\n      \"file\": \"{name}.bin\",\n      \"sha256\": \"{}\",\n      \"shape\": [\n        {},\n        {}\n      ]\n    }}", hex(&sha256(b)), p0.seed.tokens, p0.seed.width);
    for k in 0..l {
        let ldir = out.join(format!("layer_{k:02}"));
        std::fs::create_dir_all(&ldir).unwrap();
        for e in std::fs::read_dir(src.join("layer_00")).unwrap() {
            let e = e.unwrap();
            if e.file_name() != "manifest.json" {
                std::fs::copy(e.path(), ldir.join(e.file_name())).unwrap();
            }
        }
        let m = manifest0.replace("\"layer\": 0\n}", &format!("\"layer\": {k}\n}}"));
        std::fs::write(ldir.join("manifest.json"), &m).unwrap();
        layer_entries.push(format!("    {{\n      \"dir\": \"layer_{k:02}\",\n      \"layer\": {k},\n      \"manifest_sha256\": \"{}\"\n    }}", hex(&sha256(m.as_bytes()))));
        let (xk, yk) = &chain[k];
        let (xi, xo): (Vec<u8>, Vec<u8>) = (xk.iter().flat_map(|v| v.to_le_bytes()).collect(), yk.iter().flat_map(|v| v.to_le_bytes()).collect());
        for (name, b) in [(format!("x_in_L{k:02}"), &xi), (format!("x_out_L{k:02}"), &xo)] {
            std::fs::write(seq.join(format!("{name}.bin")), b).unwrap();
            arrays.push(arr(&name, b));
        }
    }
    std::fs::write(seq.join("manifest.json"), format!("{{\n  \"arrays\": {{\n{}\n  }},\n  \"kind\": \"sequence\"\n}}\n", arrays.join(",\n"))).unwrap();
    let profile = std::fs::read_to_string(src.join("profile.json")).unwrap();
    let start = profile.find("\"layers\": [").expect("the fixture profile's layer list");
    let end = start + profile[start..].find("\n  ],").expect("the end of the layer list") + "\n  ],".len();
    let mut p = format!("{}\"layers\": [\n{}\n  ],{}", &profile[..start], layer_entries.join(",\n"), &profile[end..]);
    assert_eq!(p.matches("\"variant\": \"r13-h24-wide\"").count(), 1);
    p = p.replace("\"variant\": \"r13-h24-wide\"", &format!("\"variant\": \"{variant}\""));
    std::fs::write(out.join("profile.json"), &p).unwrap();
    let ex = TrainedExport::load(&out).unwrap_or_else(|e| panic!("the written {l}-layer export does not load: {e}"));
    assert_eq!(ex.layers.len(), l);
    let id = crate::private_block::trained_block::stack_identity_for_tests(&out).unwrap();
    eprintln!("D60 F2 EXPORT | {} | variant {variant} | {l} layers (each the fixture's layer 0) | seq_public chained by the native builder | trained statement identity {} | public synthetic data, not for publication", out.display(), hex(&id));
}

/// **D60 REVIEW F2, the cross-binary check (`#[ignore]`d): ONE production
/// CLI command run inside the TEST binary** (whose `cfg(test)` arms are
/// compiled in, where the release CLI compiles the production ones):
/// `HL_D60_CLI_ARGS` is the command and its flags, whitespace-separated
/// (`stack-prove …` or `stack-verify …`), `HL_D60_CLI_WANT` the expected
/// exit code (default 0). A receipt the release CLI proved is verified here,
/// and one proved here by the release CLI.
#[test]
#[ignore = "D60 F2 cross-binary: HL_D60_CLI_ARGS, HL_D60_CLI_WANT"]
fn d60_close_cli_in_the_test_binary() {
    use crate::private_block::trained_block::{trained_stack_prove_command, trained_stack_verify_command};
    let line = std::env::var("HL_D60_CLI_ARGS").expect("HL_D60_CLI_ARGS names the command");
    let want: i32 = env_or("HL_D60_CLI_WANT", 0i32);
    let args: Vec<String> = line.split_whitespace().map(str::to_string).collect();
    let (cmd, rest) = args.split_first().expect("a command");
    let got = match cmd.as_str() {
        "stack-prove" => trained_stack_prove_command(rest),
        "stack-verify" => trained_stack_verify_command(rest),
        other => panic!("{other} is not stack-prove or stack-verify"),
    };
    eprintln!("D60 F2 TEST-BINARY CLI | {line} | exit {got} (want {want})");
    assert_eq!(got, want, "the test binary's {cmd} exited {got}, not {want}");
}

/// **D60 REVIEW F5, the measurement's other half (`#[ignore]`d): the bytes
/// ONE public block holds resident**, at each `HL_D60_F5_PROFILES` profile
/// (default the R13 rung and Llama-3-8B T128), from the A/B's synthetic block
/// at the profile's true padded geometry (`range16_tests::case`): every
/// padded weight word (i8), the RoPE / exp tables (i64), the activation
/// table and the encoded R13 accuracy data. `load_fork_blocks` holds `L` of
/// them at once on every D55 CLI path; D12a's `BlockCache` holds one.
#[test]
#[ignore = "D60 F5: the resident bytes of one public block per profile"]
fn d60_close_f5_resident_bytes_of_one_public_block() {
    use crate::private_block::shape;
    let names: String = env_or("HL_D60_F5_PROFILES", "R13_RUNG_H24,R13_8B_T128_H24".to_string());
    for name in names.split(',') {
        let spec = shape::ACCURACY_PROFILES.iter().find(|s| s.name == name).unwrap_or_else(|| panic!("{name} is not an R13 profile"));
        let (sh, data, public, ff) = crate::private_block::range16_tests::case(crate::private_block::range16_tests::built(spec.profile), 3);
        let blk = BlockPublic::new(public, ff).with_accuracy(data);
        let a = &blk.attention;
        let f = &blk.feed_forward;
        let words = a.wq.len() + a.wk.len() + a.wv.len() + a.wo.len() + a.gamma_a.len() + f.gamma_m.len() + f.wg_t.len() + f.wu_t.len() + f.wd_t.len();
        let tables = 8 * (a.rope_cos.len() + a.rope_sin.len() + a.exp.len()) + 2 * f.act.len();
        let acc = blk.accuracy().map(|x| x.encode().len()).unwrap_or(0);
        let total = words + tables + acc;
        eprintln!(
            "D60 F5 BLOCK | {name} (T{}, width {}, hidden {}; d_pad {}, f_pad {}) | one public block: {words} B of padded weight words + {tables} B of tables + {acc} B of accuracy data = {total} B ({:.3} GiB); x32 = {:.2} GiB, x22 = {:.2} GiB, x26 = {:.2} GiB",
            sh.tokens,
            sh.width,
            sh.hidden,
            sh.d_pad,
            sh.f_pad,
            total as f64 / (1u64 << 30) as f64,
            32.0 * total as f64 / (1u64 << 30) as f64,
            22.0 * total as f64 / (1u64 << 30) as f64,
            26.0 * total as f64 / (1u64 << 30) as f64
        );
    }
}

/// **[A11] the fork pools' size rule.** By default each fork worker of a run on
/// `w > 1` workers gets its own pool of ceil(cores / w) threads, and a run on one
/// worker keeps the global pool; an explicit size wins, and 0 is the global pool.
#[test]
fn a11_the_fork_pool_size_rule() {
    let cores = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(1);
    set_fork_pool_auto_for_test();
    assert_eq!(fork_pool_threads(1), 0, "one worker keeps the global pool");
    for w in [2usize, 3, 6, 8] {
        assert_eq!(fork_pool_threads(w), cores.div_ceil(w), "the default at {w} workers");
    }
    set_fork_pool_for_test(Some(0));
    assert_eq!(fork_pool_threads(6), 0);
    set_fork_pool_for_test(Some(5));
    assert_eq!(fork_pool_threads(6), 5);
    assert_eq!(fork_pools(3).unwrap().iter().filter(|p| p.as_ref().is_some_and(|p| p.current_num_threads() == 5)).count(), 3);
    set_fork_pool_for_test(None);
}

// ------------------------------------------------------------------ the A/B

fn env_or<T: std::str::FromStr>(name: &str, default: T) -> T {
    std::env::var(name).ok().and_then(|v| v.parse().ok()).unwrap_or(default)
}

/// A7: this process's user + system CPU seconds so far (`getrusage(RUSAGE_SELF)`;
/// NaN if the call fails)
fn cpu_seconds() -> f64 {
    let u = usage_now();
    u.user + u.sys
}

/// A11: what `getrusage(RUSAGE_SELF)` says of this process so far: user and
/// system CPU seconds, minor and major page faults, voluntary and involuntary
/// context switches (NaN / 0 if the call fails)
#[derive(Clone, Copy, Debug, Default)]
struct Usage {
    user: f64,
    sys: f64,
    minflt: i64,
    majflt: i64,
    nvcsw: i64,
    nivcsw: i64,
}

impl Usage {
    fn since(self, before: Usage) -> Usage {
        Usage { user: self.user - before.user, sys: self.sys - before.sys, minflt: self.minflt - before.minflt, majflt: self.majflt - before.majflt, nvcsw: self.nvcsw - before.nvcsw, nivcsw: self.nivcsw - before.nivcsw }
    }
}

fn usage_now() -> Usage {
    // `tv_usec` is 32-bit on macOS (then 4 bytes of padding) and the low half of a
    // 64-bit word on little-endian Linux
    #[repr(C)]
    struct Timeval {
        sec: i64,
        usec: i32,
    }
    // `struct rusage` on 64-bit macOS and Linux: two timevals, then fourteen longs
    // (maxrss, ixrss, idrss, isrss, minflt, majflt, nswap, inblock, oublock,
    // msgsnd, msgrcv, nsignals, nvcsw, nivcsw)
    #[repr(C)]
    struct Rusage {
        utime: Timeval,
        stime: Timeval,
        rest: [i64; 14],
    }
    extern "C" {
        fn getrusage(who: i32, usage: *mut Rusage) -> i32;
    }
    let mut r = Rusage { utime: Timeval { sec: 0, usec: 0 }, stime: Timeval { sec: 0, usec: 0 }, rest: [0; 14] };
    // SAFETY: RUSAGE_SELF (0) fills the caller's struct, whose layout is the C one
    if unsafe { getrusage(0, &mut r) } != 0 {
        return Usage { user: f64::NAN, sys: f64::NAN, ..Usage::default() };
    }
    Usage {
        user: r.utime.sec as f64 + r.utime.usec as f64 * 1e-6,
        sys: r.stime.sec as f64 + r.stime.usec as f64 * 1e-6,
        minflt: r.rest[4],
        majflt: r.rest[5],
        nvcsw: r.rest[12],
        nivcsw: r.rest[13],
    }
}

/// A12: one fork call's table builds, per slot: the time a fork spent building
/// the slot's tables (summed over the forks, per block of the call's `l`), and
/// how many of those builds ran on the device. Read and reset by the call.
fn a12_report(name: &str, l: usize, n: usize, arm: &str) {
    let rows = crate::private_block::argument::a12_take_table_times();
    let blocks = l.max(1) as f64;
    let total: u64 = rows.iter().map(|r| r.1).sum();
    let parts: Vec<String> = rows.iter().filter(|r| r.1 as f64 / blocks >= 5e4).map(|(s, ns, b, d)| format!("s{s:02} {:.2} ms ({d}/{b} dev)", *ns as f64 * 1e-6 / blocks)).collect();
    #[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
    let dev = format!(" | device builds so far {:?}", crate::gpu::MetalTables::build_stats());
    #[cfg(not(all(feature = "gpu-metal", not(feature = "gpu-cuda"))))]
    let dev = String::new();
    eprintln!("D55-AB A12 TABLES {name} L{l} forks N{n} [{arm}]: table builds {:.2} ms per block (summed over the forks) | {}{dev}", total as f64 * 1e-6 / blocks, parts.join(", "));
}

/// A11: one fork call's diagnostic lines: the process's usage over the call,
/// the fork workers' own thread CPU against their `prove_core` walls, and,
/// when the phase clock was on, every phase summed over the forks
fn a11_report(name: &str, l: usize, n: usize, arm: &str, wall: f64, u: Usage, st: &ForkStats) {
    let core: f64 = st.fork_core_s.iter().sum();
    let tcpu: f64 = st.fork_thread_cpu_s.iter().sum();
    eprintln!(
        "D55-AB A11 USAGE {name} L{l} forks N{n} [{arm}]: wall {wall:.3} s, forks {:.3} s | process user {:.1} s + sys {:.1} s = {:.1} cores | minor faults {} ({:.0}/s), major {} | csw voluntary {}, involuntary {} | fork workers: prove_core {core:.2} s summed, their own thread CPU {tcpu:.2} s ({:.0}%)",
        st.forks_s,
        u.user,
        u.sys,
        (u.user + u.sys) / wall,
        u.minflt,
        u.minflt as f64 / wall,
        u.majflt,
        u.nvcsw,
        u.nivcsw,
        if core > 0.0 { 100.0 * tcpu / core } else { 0.0 }
    );
    if st.fork_phases.iter().all(|p| p.is_empty()) {
        return;
    }
    let mut order: Vec<String> = Vec::new();
    let mut sum: std::collections::HashMap<String, f64> = std::collections::HashMap::new();
    for rows in &st.fork_phases {
        for (label, s) in rows {
            if !sum.contains_key(label) {
                order.push(label.clone());
            }
            *sum.entry(label.clone()).or_insert(0.0) += s;
        }
    }
    let total: f64 = sum.values().sum();
    let blocks = st.fork_phases.len().max(1) as f64;
    for label in &order {
        let s = sum[label];
        eprintln!("D55-AB A11 PHASE N{n} [{arm}] | {label:<64} | {s:>8.3} s summed over {blocks} forks | {:>8.2} ms per block | {:>5.1}%", 1e3 * s / blocks, 100.0 * s / total.max(1e-12));
    }
    eprintln!("D55-AB A11 PHASE N{n} [{arm}] | {:<64} | {total:>8.3} s summed over {blocks} forks | {:>8.2} ms per block (prove_core {:.2} ms)", "ALL PHASES", 1e3 * total / blocks, 1e3 * core / blocks);
}

/// A7: one arm of the in-process GPU-policy A/B (`HL_D55_GPU_AB`), from `+`-joined
/// words: `shared` / `thread` (the queues), `spin` / `block` / `spin<us>` (the wait),
/// `hostfold` / `devfold` (the opening's row fold). Unnamed parts keep the defaults
/// (spin, host fold; the process's queue mode).
#[derive(Clone, Debug)]
struct GpuArm {
    label: String,
    per_thread: Option<bool>,
    wait: Option<u64>,
    devfold: bool,
    /// A11: `phases` turns the phase clock on in every fork (diagnostic; no byte changes)
    phases: bool,
    /// A11: `fp<t>`: each fork worker's own rayon pool of `t` threads; `fpauto`:
    /// the default rule (ceil(cores / workers)); `global`: the one global pool;
    /// unnamed: as the environment says
    fork_pool: Option<usize>,
    /// A12: `devtab`: a device slot's tables built on the device, ahead of its
    /// first round; `devtabsync`: on the device in a command buffer of their
    /// own; `hosttab`: on the host; unnamed: as the environment says
    device_tables: Option<u8>,
    /// A8: the openings' host store fold, `m11` (0, the forms before A8), `sparse`
    /// (1) or `small` (2); unnamed: as the environment says
    a8_form: Option<u8>,
    /// A14: the generator's XOF form, the transcript's absorb form and the lazy
    /// sums (see [`A14Arm`])
    a14: A14Arm,
    /// A15: where the sealing pass builds its witnesses (see [`A15Seal`]); unnamed:
    /// as the environment says
    seal: Option<A15Seal>,
    /// A17: the looked columns, the checked record, the kept matrices (see [`A17Arm`])
    a17: A17Arm,
    /// A16: the builder's forms (see [`a16_word`]); unnamed: as the environment says
    a16: Option<u32>,
    /// A16: `prod`: every witness through production's `build_for_block`
    prod: bool,
    /// A18: the table forms, the registry record, A13's window (see [`A18Arm`])
    a18: A18Arm,
}

// ---- [A14] the A/B words of efficiency plan A14 (the forks' remaining host work) ----

/// **[A14]** the three byte-preserving forms of A14, each `None` as the
/// environment says: `xofb3` / `xof8` (`fill_fp`'s blocks from blake3's XOF, or
/// eight NEON lanes), `trser` / `trpar` (a long transcript absorb serial, or
/// BLAKE3's tree on rayon), `lazy0` / `lazy1` (the host's `Fp2 x Fp` dot products
/// per term, or summed exactly and reduced once); `a14old` / `a14new` set all
/// three off / on (the tree before A14 / every A14 form), `a14def` the A14
/// default (`xofb3+trser+lazy1`: the parallel absorb did not pay and the lane
/// XOF moved no wall on top of the lazy sums; both are opt-in)
#[derive(Clone, Copy, Debug, Default)]
struct A14Arm {
    xof: Option<zkp_core::rng::XofForm>,
    absorb_par: Option<bool>,
    lazy: Option<bool>,
}

/// [A14] one `+`-joined word of an arm, if it is A14's
fn a14_word(a: &mut A14Arm, w: &str) -> bool {
    use zkp_core::rng::XofForm;
    match w {
        "xofb3" => a.xof = Some(XofForm::Blake3),
        "xof8" => a.xof = Some(XofForm::Lanes8),
        "trser" => a.absorb_par = Some(false),
        "trpar" => a.absorb_par = Some(true),
        "lazy0" => a.lazy = Some(false),
        "lazy1" => a.lazy = Some(true),
        "a14old" => *a = A14Arm { xof: Some(XofForm::Blake3), absorb_par: Some(false), lazy: Some(false) },
        "a14new" => *a = A14Arm { xof: Some(XofForm::Lanes8), absorb_par: Some(true), lazy: Some(true) },
        "a14def" => *a = A14Arm { xof: Some(XofForm::Blake3), absorb_par: Some(false), lazy: Some(true) },
        _ => return false,
    }
    true
}

/// [A14] put an arm's forms in force for the whole process (the fork workers
/// read them); `A14Arm::default()` restores the environment's
#[cfg_attr(not(all(feature = "gpu-metal", not(feature = "gpu-cuda"))), allow(dead_code))]
fn a14_apply(a: &A14Arm) {
    zkp_core::rng::set_xof_form(a.xof);
    crate::transcript::set_absorb_parallel(a.absorb_par);
    crate::private_block::argument::set_lazy_for_test(a.lazy);
}

// ---- end of [A14] ----

// ---- [A15] the sealing pass's pool (efficiency plan A15) ----

use crate::private_block::trained_block::SealPool;

/// **[A15]** where the harness's sealing pass builds its witnesses: `sp<t>` in
/// production's sealing pool of `t` threads ([`SealPool`]; `sp0` the global pool,
/// called from the harness thread: the harness before A15); `spauto` production's
/// default rule; `spg` the global pool entered on one of its own workers (as
/// `trained_block::seal_and_record`'s `rayon::join` ran each build before A15)
#[derive(Clone, Copy, Debug, PartialEq)]
enum A15Seal {
    Pool(usize),
    Auto,
    GlobalWarm,
}

/// [A15] one `+`-joined word of an arm, if it is A15's (`spin...` stays A7's)
fn a15_word(w: &str) -> Option<A15Seal> {
    match w {
        "spauto" => Some(A15Seal::Auto),
        "spg" => Some(A15Seal::GlobalWarm),
        _ => w.strip_prefix("sp").and_then(|t| t.parse::<usize>().ok()).map(A15Seal::Pool),
    }
}

/// [A15] `spg` in force (the sealing thread of a stream reads it too)
static A15_WARM: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// [A15] put an arm's sealing form in force for the whole process; `None` restores
/// the environment's
fn a15_apply(s: Option<A15Seal>) {
    use crate::private_block::trained_block::{set_seal_pool_auto_for_test, set_seal_pool_for_test};
    A15_WARM.store(s == Some(A15Seal::GlobalWarm), std::sync::atomic::Ordering::Relaxed);
    match s {
        None => set_seal_pool_for_test(None),
        Some(A15Seal::Pool(t)) => set_seal_pool_for_test(Some(t)),
        Some(A15Seal::Auto) => set_seal_pool_auto_for_test(),
        Some(A15Seal::GlobalWarm) => set_seal_pool_for_test(Some(0)),
    }
}

/// [A15] one sealing pass's builder: the pool in force, or (`spg`) the global pool
/// entered on one of its workers
struct A15Sealer {
    warm: bool,
    pool: SealPool,
}

impl A15Sealer {
    fn now() -> A15Sealer {
        A15Sealer { warm: A15_WARM.load(std::sync::atomic::Ordering::Relaxed), pool: SealPool::get().expect("the sealing pool") }
    }
    /// one witness build (the same words wherever it runs)
    fn run<R: Send>(&self, f: impl FnOnce() -> R + Send) -> R {
        if self.warm {
            rayon::join(f, || ()).0
        } else {
            self.pool.run(f)
        }
    }
    fn label(&self) -> String {
        match (self.warm, self.pool.threads()) {
            (true, _) => format!("the global pool of {}, entered on a worker", rayon::current_num_threads()),
            (false, 0) => format!("the global pool of {}, from the calling thread", rayon::current_num_threads()),
            (false, t) => format!("a sealing pool of {t}"),
        }
    }
}

/// [A15] one digest of every plane of every witness of a chain (each witness hashed
/// on its own rayon task, off the clock): its output plane index, then each plane's
/// length and words
fn a15_digest(ws: &[Witness]) -> String {
    use rayon::prelude::*;
    let parts: Vec<[u8; 32]> = ws
        .par_iter()
        .map(|w| {
            let mut h = blake3::Hasher::new();
            h.update(&(w.output_plane as u64).to_le_bytes());
            let mut buf: Vec<u8> = Vec::with_capacity(1 << 16);
            for p in &w.planes {
                h.update(&(p.len() as u64).to_le_bytes());
                for c in p.chunks(1 << 13) {
                    buf.clear();
                    for v in c {
                        buf.extend_from_slice(&v.to_le_bytes());
                    }
                    h.update(&buf);
                }
            }
            *h.finalize().as_bytes()
        })
        .collect();
    let mut h = blake3::Hasher::new();
    for d in &parts {
        h.update(d);
    }
    h.finalize().to_hex().to_string()
}

/// [A15] one request from its input: A13's SEALED line (for `a13/seal_pairs.py`; no
/// before-challenge parts here) and the sealing pass's own CPU
#[allow(clippy::too_many_arguments)]
fn a15_sealed_report(name: &str, l: usize, n: usize, arm: &str, wall: f64, seal: f64, u: Usage, st: &ForkStats, pool: &str) {
    let cpu = u.user + u.sys;
    eprintln!(
        "D55-AB A13 SEALED {name} L{l} N{n} [{arm}]: wall {wall:.3} s; sealing pass {seal:.3} s ({:.1} cores busy, {cpu:.1} CPU-s); prove call {:.3} s: preflight {:.3}, commit {:.3}, forks {:.3}, join {:.3} s; 0/{l} forks parked (A15: no before-challenge parts)",
        cpu / seal.max(1e-9),
        st.total_s,
        st.preflight_s,
        st.commit_s,
        st.forks_s,
        st.join_s
    );
    eprintln!(
        "D55-AB A15 SEALED {name} L{l} N{n} [{arm}]: sealing pass {seal:.3} s in {pool}: user {:.2} s + sys {:.2} s = {:.1} cores; csw voluntary {}, involuntary {}; minor faults {}",
        u.user,
        u.sys,
        cpu / seal.max(1e-9),
        u.nvcsw,
        u.nivcsw,
        u.minflt
    );
}

// ---- end of [A15] ----

// ---- [A17] the forks' host work (efficiency plan A17) ----

/// **[A17]** the two forms of `protocol.rs`'s `[A17]` block, each `None` as the
/// environment says: `looked0` / `looked1` (a W16 profile's one-term looked
/// columns copied out first, or read from their planes), `checked0` /
/// `checked1` (each fork re-checks its block's public data, or the preflight's
/// record of that very block stands in); `a17old` / `a17new` both off / on.
/// (Stage 3 also measured a third form, each fork worker's kept `A` and `H`, as
/// the word `reuse1` of the work-in-progress commit; it lost and was removed.)
type A17Arm = (Option<bool>, Option<bool>);

/// [A17] one `+`-joined word of an arm, if it is A17's
fn a17_word(a: &mut A17Arm, w: &str) -> bool {
    match w {
        "looked0" => a.0 = Some(false),
        "looked1" => a.0 = Some(true),
        "checked0" => a.1 = Some(false),
        "checked1" => a.1 = Some(true),
        "a17old" => *a = (Some(false), Some(false)),
        "a17new" => *a = (Some(true), Some(true)),
        _ => return false,
    }
    true
}

/// [A17] put an arm's forms in force for the whole process (the fork workers
/// read them); `(None, None)` restores the environment's
#[cfg_attr(not(all(feature = "gpu-metal", not(feature = "gpu-cuda"))), allow(dead_code))]
fn a17_apply(a: A17Arm) {
    crate::private_block::protocol::set_a17_for_test(a.0, a.1);
}

/// [A17] a fork run's blocks that are NOT the same twice: the first `get` of each
/// block (the preflight's) is the honest block, every later one (the fork's) is
/// `other`; the digests are the honest blocks' (so CS-6 passes)
struct A17Turncoat<'b> {
    honest: &'b [BlockPublic],
    other: &'b BlockPublic,
    asked: Vec<std::sync::atomic::AtomicUsize>,
}

impl ForkBlocks for A17Turncoat<'_> {
    fn count(&self) -> usize {
        self.honest.len()
    }
    fn get(&self, k: usize) -> Result<&BlockPublic, String> {
        let b = self.honest.get(k).ok_or_else(|| format!("private run: no public statement for block {k}"))?;
        Ok(if self.asked[k].fetch_add(1, std::sync::atomic::Ordering::SeqCst) == 0 { b } else { self.other })
    }
    fn digest_of(&self, k: usize) -> Result<Digest, String> {
        self.honest.get(k).map(|b| b.digest()).ok_or_else(|| format!("private run: no public statement for block {k}"))
    }
}

/// **[A17] the preflight's record never lets a fork prove a block it did not
/// check.** At the R13 rung (`L = 3`, two workers), with the record in force:
/// (1) the honest run proves (every fork's record covering its block) and
/// verifies; (2) a block source that hands each fork a DIFFERENT block than
/// the preflight checked (the honest block without its public accuracy data,
/// which CS-1 / CS-4 refuse) is refused at the fork by that check's own words,
/// so the run fails closed; (3) the same with the record switched off. A block
/// object cannot change while its record lives (the record borrows it), so "a
/// modified block" is always another object, which is case (2).
#[test]
fn a17_a_fork_refuses_a_block_its_preflight_did_not_check() {
    use crate::private_block::protocol::set_a17_for_test;
    let mut r = rung(3, 171);
    set_a17_for_test(None, Some(true));
    let (rc, _) = prove_forks(&mut r, 2);
    let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
    let ok = verify_run_with_forks(&fr, &r.blocks, &rc, 3);
    set_a17_for_test(None, None);
    ok.expect("the honest D55 fork run with the preflight's records verifies");
    let other = BlockPublic::new(r.blocks[1].attention().clone(), r.blocks[1].feed_forward().clone());
    let want = other.check_for_shape(&r.st.stage_shape(1).unwrap()).expect_err("the block without its accuracy data is refused by CS-1 / CS-4");
    for checked in [true, false] {
        let mut r = rung(3, 172 + checked as u8);
        let turncoat = A17Turncoat { honest: &r.blocks, other: &other, asked: (0..3).map(|_| std::sync::atomic::AtomicUsize::new(0)).collect() };
        let fr = ForkRun::new(&r.st, D55OptIn::unreviewed_prototype()).unwrap();
        set_a17_for_test(None, Some(checked));
        let got = prove_run_with_forks(&fr, &turncoat, &mut r.src, r.owners.take().unwrap(), 2);
        set_a17_for_test(None, None);
        let e = got.err().unwrap_or_else(|| panic!("A FORK PROVED A BLOCK ITS PREFLIGHT DID NOT CHECK (record {checked})"));
        assert!(e.contains(&want), "the refusal is not CS-1 / CS-4's own (record {checked}): {e}");
        assert!(turncoat.asked.iter().all(|n| n.load(std::sync::atomic::Ordering::SeqCst) >= 1), "the preflight did not ask for every block");
        eprintln!("A17 | turncoat blocks, record {checked}: refused at the fork: {}", e.chars().take(160).collect::<String>());
    }
}

// ---- end of [A17] ----

// ---- [A16] the builder's serial remainder (efficiency plan A16) ----

/// [A16] a form's word (`cache`, `quant`, `norm`, `loops`, `once`, `overlap`, `kernels`)
fn a16_form(w: &str) -> Option<u32> {
    use crate::private_block::witness::{A16_CACHE, A16_KERNELS, A16_LOOPS, A16_NORM, A16_ONCE, A16_OVERLAP, A16_QUANT};
    Some(match w {
        "cache" => A16_CACHE,
        "quant" => A16_QUANT,
        "norm" => A16_NORM,
        "loops" => A16_LOOPS,
        "once" => A16_ONCE,
        "overlap" => A16_OVERLAP,
        "kernels" => A16_KERNELS,
        _ => return None,
    })
}

/// **[A16]** one `+`-joined word of an arm, if it is A16's: `a16old` (no form: the
/// builder before A16), `a16all`, `a16def` (the default), `a16<form>` (adds the form to
/// the arm's set, which starts empty), `a16x<form>` (every form but this one; joined
/// words take more out), and `prod` (every witness through production's
/// `witness::build_for_block`, as `seal_and_record` builds it, instead of
/// `build_accuracy`: the same words; `once` acts on that path only)
fn a16_word(forms: &mut Option<u32>, prod: &mut bool, w: &str) -> bool {
    use crate::private_block::witness::{A16_ALL, A16_DEFAULT};
    match w {
        "prod" => *prod = true,
        "a16old" => *forms = Some(0),
        "a16all" => *forms = Some(A16_ALL),
        "a16def" => *forms = Some(A16_DEFAULT),
        _ => {
            if let Some(f) = w.strip_prefix("a16x").and_then(a16_form) {
                *forms = Some(forms.unwrap_or(A16_ALL) & !f);
            } else if let Some(f) = w.strip_prefix("a16").and_then(a16_form) {
                *forms = Some(forms.unwrap_or(0) | f);
            } else {
                return false;
            }
        }
    }
    true
}

/// [A16] `prod` in force (the harness's `build`, on every thread, reads it)
static A16_PROD: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// [A16] put an arm's forms and builder in force for the whole process; `(None, false)`
/// restores the environment's forms and `build_accuracy`
fn a16_apply(forms: Option<u32>, prod: bool) {
    crate::private_block::witness::set_a16_for_test(forms);
    A16_PROD.store(prod, std::sync::atomic::Ordering::Relaxed);
}

/// [A16] an arm of the sealing-alone A/B: A15's place and A16's forms and builder
fn a16_seal_arm(spec: &str) -> Option<(Option<A15Seal>, Option<u32>, bool)> {
    let (mut seal, mut forms, mut prod) = (None, None, false);
    for w in spec.split('+').map(str::trim).filter(|w| !w.is_empty()) {
        if let Some(sp) = a15_word(w) {
            seal = Some(sp);
        } else if !a16_word(&mut forms, &mut prod, w) {
            return None;
        }
    }
    Some((seal, forms, prod))
}

// ---- end of [A16] ----

fn gpu_arm(spec: &str) -> Option<GpuArm> {
    let mut a = GpuArm { label: spec.to_string(), per_thread: None, wait: None, devfold: false, phases: false, fork_pool: None, device_tables: None, a8_form: None, a14: A14Arm::default(), seal: None, a17: (None, None), a16: None, prod: false, a18: A18Arm::default() };
    for w in spec.split('+').map(str::trim) {
        if let Some(t) = w.strip_prefix("fp").and_then(|t| t.parse::<usize>().ok()) {
            a.fork_pool = Some(t);
            continue;
        }
        // [A14]
        if a14_word(&mut a.a14, w) {
            continue;
        }
        // [A17]
        if a17_word(&mut a.a17, w) {
            continue;
        }
        // [A15]
        if let Some(sp) = a15_word(w) {
            a.seal = Some(sp);
            continue;
        }
        // [A16]
        if a16_word(&mut a.a16, &mut a.prod, w) {
            continue;
        }
        // [A18]
        if a18_word(&mut a.a18, w) {
            continue;
        }
        match w {
            "global" => a.fork_pool = Some(0),
            "fpauto" => a.fork_pool = Some(usize::MAX),
            "shared" => a.per_thread = Some(false),
            "thread" => a.per_thread = Some(true),
            "spin" => a.wait = None,
            "block" => a.wait = Some(0),
            "hostfold" => a.devfold = false,
            "devfold" => a.devfold = true,
            "phases" => a.phases = true,
            #[cfg(feature = "gpu-metal")]
            "devtab" => a.device_tables = Some(crate::private_block::argument::DT_DEVICE),
            #[cfg(feature = "gpu-metal")]
            "devtabsync" => a.device_tables = Some(crate::private_block::argument::DT_SYNC),
            #[cfg(feature = "gpu-metal")]
            "hosttab" => a.device_tables = Some(crate::private_block::argument::DT_HOST),
            "m11" => a.a8_form = Some(0),
            "sparse" => a.a8_form = Some(1),
            "small" => a.a8_form = Some(2),
            _ => a.wait = Some(w.strip_prefix("spin")?.parse().ok()?),
        }
    }
    Some(a)
}

thread_local! {
    /// A11: the label of the A/B arm the harness thread is running (for the A11 lines)
    static A11_ARM: std::cell::RefCell<String> = const { std::cell::RefCell::new(String::new()) };
}

fn a11_arm_label() -> String {
    A11_ARM.with(|a| a.borrow().clone())
}

fn a11_set_arm(label: &str) {
    A11_ARM.with(|a| *a.borrow_mut() = label.to_string());
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
    // D64 / H124c: `HL_D55_JIT` = `builders:ahead` pairs (e.g. `4:6,8:8`), one
    // extra fork arm each with every witness built ON the clock ([`Jit`])
    let jit: Vec<(usize, usize)> = std::env::var("HL_D55_JIT")
        .unwrap_or_default()
        .split(',')
        .filter_map(|p| {
            let (b, a) = p.trim().split_once(':')?;
            Some((b.parse::<usize>().ok()?.max(1), a.parse::<usize>().ok()?.max(1)))
        })
        .collect();
    let t0 = Instant::now();
    let original = crate::private_block::range16_tests::built(spec.profile);
    let (sh, data, public, ff) = crate::private_block::range16_tests::case(original, 3);
    let blk = BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
    // [A16] `prod`: production's builder (`build_for_block`, as `seal_and_record`), the same words
    let build = |x: &[i16]| if A16_PROD.load(std::sync::atomic::Ordering::Relaxed) { witness::build_for_block(&sh, &blk, x) } else { witness::build_accuracy(&sh, &public, &ff, &data, x) };
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
    // the sealing pass: the forward chain, one full witness build per block, serial
    let t_seal = Instant::now();
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
    let seal_s = t_seal.elapsed().as_secs_f64();
    eprintln!("D55-AB {name} L{l} T{}: the sealing pass (the forward chain as {l} serial full witness builds) {seal_s:.3} s", sh.tokens);
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
    // A7: `HL_D55_TIMELINE=1` records every command buffer's GPU timestamps over
    // each timed call and prints what the GPU did (diagnostic; no byte changes)
    let timeline: bool = env_or("HL_D55_TIMELINE", 0usize) == 1;
    #[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
    let tl_start = || if timeline { Some(crate::gpu::gpu_timeline_start()) } else { None };
    #[cfg(not(all(feature = "gpu-metal", not(feature = "gpu-cuda"))))]
    let tl_start = || -> Option<f64> {
        let _ = timeline;
        None
    };
    // the timeline over `[h0, h0 + wall]` and, when given, the window `(from, len)` in it
    let tl_report = |arm: &str, h0: Option<f64>, wall: f64, window: Option<(f64, f64)>| {
        #[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
        if let Some(h0) = h0 {
            let spans = crate::gpu::gpu_timeline_take();
            eprintln!("D55-AB A7 TIMELINE {name} L{l} {arm} (queues {}): the whole call, {wall:.3} s\n{}", crate::gpu::metal_queues_for_test(), crate::gpu::gpu_timeline_report(&spans, h0, h0 + wall));
            if let Some((from, len)) = window {
                eprintln!("D55-AB A7 TIMELINE {name} L{l} {arm} (queues {}): the forks phase, {len:.3} s\n{}", crate::gpu::metal_queues_for_test(), crate::gpu::gpu_timeline_report(&spans, h0 + from, h0 + from + len));
            }
        }
        let _ = (arm, h0, wall, window);
    };
    // arm 0 = D12a serial, arm n = forks on n workers
    let serial = |ctx: u8, verify: bool| -> (f64, usize) {
        let mut src = witnesses();
        let (st, owners) = statement(ctx);
        let mut rep_d12a = RepeatBlock::new(&blk, l);
        let mut segs: Vec<Vec<u8>> = Vec::new();
        let mut bytes = 0usize;
        let h0 = tl_start();
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
        tl_report("serial (D12a)", h0, wall, None);
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
        let h0 = tl_start();
        let u0 = usage_now();
        let _ = crate::private_block::argument::a12_take_table_times();
        let t = Instant::now();
        let (rc, stats) = prove_run_with_forks(&fr, &rep, &mut src, owners, n).expect("the D55 fork run proves");
        let wall = t.elapsed().as_secs_f64();
        let u = usage_now().since(u0);
        let cpu = u.user + u.sys;
        eprintln!("D55-AB A7 CPU {name} L{l} forks N{n}: {cpu:.1} CPU-seconds (user + system, the whole process) over the {wall:.3} s call = {:.1} cores busy on average", cpu / wall);
        a11_report(&name, l, n, &a11_arm_label(), wall, u, &stats);
        a12_report(&name, l, n, &a11_arm_label());
        tl_report(&format!("forks N{n}"), h0, wall, Some((stats.preflight_s + stats.commit_s, stats.forks_s)));
        if verify {
            let tv = Instant::now();
            verify_run_with_forks(&fr, &rep, &rc, 6).expect("the D55 fork run verifies");
            eprintln!("D55-AB {name} L{l} forks N{n}: verified (D55 verifier, 6 threads) in {:.2} s", tv.elapsed().as_secs_f64());
        }
        (wall, rc.bytes(), stats)
    };
    // D64 / H124c: the fork arm with every witness built ON the clock by `b`
    // builder threads, at most `ahead` blocks beyond the feeder
    let forked_jit = |ctx: u8, n: usize, b: usize, ahead: usize, verify: bool| -> (f64, usize, ForkStats) {
        let (st, owners) = statement(ctx);
        let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).unwrap();
        let state = std::sync::Mutex::new(JitState { built: (0..l).map(|_| None).collect(), given: vec![false; l], taken: 0, stop: false });
        let cv = std::sync::Condvar::new();
        let next = std::sync::atomic::AtomicUsize::new(0);
        let bk = |k: usize| build(&xs[k]);
        let t = Instant::now();
        let proved = std::thread::scope(|sc| {
            for _ in 0..b.min(l) {
                let (state, cv, next, bk) = (&state, &cv, &next, &bk);
                sc.spawn(move || jit_builder(state, cv, next, ahead, bk));
            }
            let mut src = Jit { state: &state, cv: &cv, planes: &planes };
            let r = prove_run_with_forks(&fr, &rep, &mut src, owners, n);
            if let Ok(mut g) = state.lock() {
                g.stop = true;
            }
            cv.notify_all();
            r
        });
        let wall = t.elapsed().as_secs_f64();
        let (rc, stats) = proved.expect("the D55 fork run proves (witness on the clock)");
        if verify {
            let tv = Instant::now();
            verify_run_with_forks(&fr, &rep, &rc, 6).expect("the D55 fork run verifies (witness on the clock)");
            eprintln!("D55-AB {name} L{l} forks N{n} JIT {b}:{ahead}: verified (D55 verifier, 6 threads) in {:.2} s", tv.elapsed().as_secs_f64());
        }
        (wall, rc.bytes(), stats)
    };
    let mut jit_table: Vec<(String, Vec<f64>)> = jit.iter().flat_map(|&(b, a)| workers.iter().map(move |n| (format!("forks N={n} JIT {b}:{a}"), Vec::new()))).collect();
    // H124c: `HL_D55_SEALED=1` adds the arm a single request would really run: the sealing
    // pass ON the clock (the forward chain, one full build per block, from the run's input),
    // KEEPING its witnesses and boundary planes, then the fork run on them
    let sealed_on: bool = env_or("HL_D55_SEALED", 0usize) == 1;
    let forked_sealed = |ctx: u8, n: usize, verify: bool| -> (f64, f64, usize) {
        let (st, owners) = statement(ctx);
        let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).unwrap();
        // [A15] the sealing pass in the pool the arm (or the environment) names, and its CPU
        let sealer = A15Sealer::now();
        // [A18] A13's window: the sealing pass through `prove_run_with_forks_sealing`, each
        // witness handed over as it is built and the first W forks' before-challenge parts
        // made beside it (no byte changes)
        if ahead_window() > 0 {
            let mem = A18Mem::start();
            let (u0, h0) = (usage_now(), tl_start());
            let t = Instant::now();
            let (mut seal, mut us) = (0.0f64, None);
            let (rc, stats) = prove_run_with_forks_sealing(&fr, &rep, owners, n, |push| {
                let mut pls = Vec::with_capacity(l);
                let mut x = xs[0].clone();
                for k in 0..l {
                    let w = sealer.run(|| build(&x)).expect("the chain was admissible");
                    let out = w.output().unwrap();
                    x = unpad(&sh, &out);
                    if k + 1 < l {
                        pls.push(out);
                    }
                    push(k, w)?;
                }
                seal = t.elapsed().as_secs_f64();
                us = Some(usage_now().since(u0));
                Ok(Chain { witnesses: (0..l).map(|_| None).collect(), planes: pls, tamper: None })
            })
            .expect("the D55 fork run proves (sealing pass on the clock, before-challenge parts beside it)");
            let wall = t.elapsed().as_secs_f64();
            let mem = mem.stop();
            tl_report(&format!("A18 sealing pass with its parts N{n} [{}]", a11_arm_label()), h0, seal, None);
            a18_sealed_report(&name, l, n, &a11_arm_label(), wall, seal, us.expect("the sealing pass ran"), &stats, &sealer.label(), mem);
            if verify {
                verify_run_with_forks(&fr, &rep, &rc, 6).expect("the D55 fork run verifies (sealing pass on the clock, before-challenge parts beside it)");
                eprintln!("D55-AB {name} L{l} forks N{n} SEALED: verified (D55 verifier, 6 threads)");
            }
            return (wall, seal, rc.bytes());
        }
        let (u0, h0) = (usage_now(), tl_start());
        let t = Instant::now();
        let (mut ws, mut pls) = (Vec::with_capacity(l), Vec::with_capacity(l));
        let mut x = xs[0].clone();
        for k in 0..l {
            let w = sealer.run(|| build(&x)).expect("the chain was admissible");
            let out = w.output().unwrap();
            x = unpad(&sh, &out);
            if k + 1 < l {
                pls.push(out);
            }
            ws.push(Some(w));
        }
        let seal = t.elapsed().as_secs_f64();
        let us = usage_now().since(u0);
        tl_report(&format!("A15 sealing pass N{n} [{}]", a11_arm_label()), h0, seal, None);
        let mut src = Chain { witnesses: ws, planes: pls, tamper: None };
        let (rc, stats) = prove_run_with_forks(&fr, &rep, &mut src, owners, n).expect("the D55 fork run proves (sealing pass on the clock)");
        let wall = t.elapsed().as_secs_f64();
        a15_sealed_report(&name, l, n, &a11_arm_label(), wall, seal, us, &stats, &sealer.label());
        if verify {
            verify_run_with_forks(&fr, &rep, &rc, 6).expect("the D55 fork run verifies (sealing pass on the clock)");
            eprintln!("D55-AB {name} L{l} forks N{n} SEALED: verified (D55 verifier, 6 threads)");
        }
        (wall, seal, rc.bytes())
    };
    let mut sealed_table: Vec<(String, Vec<f64>)> = if sealed_on { workers.iter().map(|n| (format!("forks N={n} SEALED"), Vec::new())).collect() } else { Vec::new() };
    // D64 / H124d: `HL_D55_PIPE=R` streams R requests. A sealing thread runs request
    // r + 1's sealing pass (from its input, witnesses kept) while the prover runs request
    // r's fork run; at most one sealed request waits. Returns the total wall, each
    // request's completion time and its latency (from the start of its sealing pass),
    // and the receipts with their contexts, verified by the caller after the clock.
    let pipe: usize = env_or("HL_D55_PIPE", 0usize);
    let piped = |ctx0: u8, n: usize, r: usize| -> (f64, Vec<f64>, Vec<f64>, Vec<(RunStatement, ForkReceipt)>) {
        // [A18] `stsl` (or A13's window, which needs it): each request's statement made
        // on the sealing thread; with a window its sealing pass makes its forks'
        // before-challenge parts beside it (`seal_ahead`); and the stream's footprint
        let (stsl, window) = (a18_stsl(), ahead_window());
        let mem = if stsl { Some(A18Mem::start()) } else { None };
        let t = Instant::now();
        let (tx, rx) = std::sync::mpsc::sync_channel::<(usize, Option<(RunStatement, Endpoints)>, A18Sealed, f64)>(1);
        let (mut done, mut lat, mut rcs) = (Vec::new(), Vec::new(), Vec::new());
        std::thread::scope(|sc| {
            let (xs, build, sh, statement, rep_r) = (&xs, &build, &sh, &statement, &rep);
            // [A15] the arm's label for the sealing thread's lines
            let (name, arm) = (&name, a11_arm_label());
            sc.spawn(move || {
                for q in 0..r {
                    let t_in = t.elapsed().as_secs_f64();
                    // [A15] the sealing pass in the pool in force (beside the forks' own pools)
                    let sealer = A15Sealer::now();
                    // [A18] the statement is kept with its receipt (`statement` draws fresh
                    // endpoint commitments on every call, so a rebuilt one would be another run)
                    let made = if stsl { Some(statement(ctx0.wrapping_add(q as u8))) } else { None };
                    let seal_all = |push: &mut dyn FnMut(usize, Witness) -> Result<(), String>| -> Result<Vec<Vec<i16>>, String> {
                        let mut pls = Vec::with_capacity(l);
                        let mut x = xs[0].clone();
                        for k in 0..l {
                            let w = sealer.run(|| build(&x)).expect("the chain was admissible");
                            let out = w.output().unwrap();
                            x = unpad(sh, &out);
                            if k + 1 < l {
                                pls.push(out);
                            }
                            push(k, w)?;
                        }
                        Ok(pls)
                    };
                    let sealed = match &made {
                        Some((st, _)) if window > 0 => {
                            let fr = ForkRun::new(st, D55OptIn::unreviewed_prototype()).unwrap();
                            let (ahead, pls) = seal_ahead(&fr, rep_r, seal_all).expect("the stream's sealing pass with its before-challenge parts");
                            eprintln!("D55-AB A18 PIPE-SEAL {name} L{l} N{n} [{arm}] request {q}: sealing pass with its parts {:.3} s; {} parts parked, holding {:.2} GB on the host", t.elapsed().as_secs_f64() - t_in, ahead.parked, ahead.host_bytes as f64 / 1e9);
                            A18Sealed::Ahead(ahead, pls)
                        }
                        _ => {
                            let mut ws = Vec::with_capacity(l);
                            let pls = seal_all(&mut |_, w| {
                                ws.push(Some(w));
                                Ok(())
                            })
                            .expect("the stream's sealing pass");
                            A18Sealed::Whole(ws, pls)
                        }
                    };
                    eprintln!("D55-AB A15 PIPE-SEAL {name} L{l} N{n} [{arm}] request {q}: sealing pass {:.3} s in {}", t.elapsed().as_secs_f64() - t_in, sealer.label());
                    if tx.send((q, made, sealed, t_in)).is_err() {
                        break;
                    }
                }
            });
            for _ in 0..r {
                let (q, made, sealed, t_in) = rx.recv().expect("a sealed request");
                // the statement is kept with its receipt: `statement` draws fresh endpoint
                // commitments on every call, so a rebuilt one would be another run
                let (st, owners) = match made {
                    Some(m) => m,
                    None => statement(ctx0.wrapping_add(q as u8)),
                };
                let rc = {
                    let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).unwrap();
                    match sealed {
                        A18Sealed::Whole(ws, pls) => {
                            let mut src = Chain { witnesses: ws, planes: pls, tamper: None };
                            prove_run_with_forks(&fr, &rep, &mut src, owners, n)
                        }
                        A18Sealed::Ahead(ahead, pls) => {
                            let mut src = Chain { witnesses: (0..l).map(|_| None).collect(), planes: pls, tamper: None };
                            prove_run_with_forks_ahead(&fr, &rep, ahead, &mut src, owners, n)
                        }
                    }
                    .expect("the D55 fork run proves (stream)")
                    .0
                };
                let now = t.elapsed().as_secs_f64();
                done.push(now);
                lat.push(now - t_in);
                rcs.push((st, rc));
            }
        });
        let wall = t.elapsed().as_secs_f64();
        if let Some(mem) = mem {
            let (f0, peak, f1) = mem.stop();
            eprintln!("D55-AB A18 PIPE-MEM {name} L{l} N{n} [{}]: {r} requests in {wall:.3} s; footprint start {f0:.1} GiB, peak {peak:.1} GiB, end {f1:.1} GiB", a11_arm_label());
        }
        (wall, done, lat, rcs)
    };
    // [A15] `HL_A15_SEAL_AB=<arms>` (A15's words `sp<t>`, `spauto`, `spg`): the sealing pass
    // ALONE, `HL_A15_SEAL_PASSES` passes (default 3), each arm once per pass (reversed in
    // odd passes with `HL_D55_AB_ALTERNATE=1`): its wall and the process's usage over it.
    // In each arm's first pass, one digest of every plane of every witness of the chain
    // (off the clock), which must be the first arm's. Then `HL_A15_SAMPLE=K`: for each arm
    // of `HL_A15_SAMPLE_ARMS` (default `sp0,spauto`), K sealing passes between two
    // handshakes with an outside sampler (`A15-SAMPLE READY <arm> pid <pid>`, the files
    // `$HL_A15_SAMPLE_DIR/go.<arm>` and `next.<arm>`). `HL_A15_ONLY=1` ends the test there.
    let a15_alone = |check: bool| -> (f64, Usage, String, String) {
        let sealer = A15Sealer::now();
        let u0 = usage_now();
        let t = Instant::now();
        let mut ws: Vec<Witness> = Vec::with_capacity(l);
        let mut x = xs[0].clone();
        for _ in 0..l {
            let w = sealer.run(|| build(&x)).expect("the chain was admissible");
            x = unpad(&sh, &w.output().unwrap());
            ws.push(w);
        }
        let wall = t.elapsed().as_secs_f64();
        let u = usage_now().since(u0);
        assert_eq!(ws[l - 1].output().unwrap(), output, "A15: the chain's last output moved");
        let digest = if check { a15_digest(&ws) } else { String::new() };
        drop(ws);
        (wall, u, sealer.label(), digest)
    };
    let a15_arms: Vec<(String, A15Seal)> = std::env::var("HL_A15_SEAL_AB")
        .unwrap_or_default()
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| (s.to_string(), a15_word(s).unwrap_or_else(|| panic!("HL_A15_SEAL_AB: an unknown arm {s:?}"))))
        .collect();
    if !a15_arms.is_empty() {
        let a15_passes: usize = env_or("HL_A15_SEAL_PASSES", 3usize).max(1);
        let alternate: bool = env_or("HL_D55_AB_ALTERNATE", 0usize) == 1;
        let mut first: Option<(String, String)> = None;
        for p in 0..a15_passes {
            let order: Vec<usize> = if alternate && p % 2 == 1 { (0..a15_arms.len()).rev().collect() } else { (0..a15_arms.len()).collect() };
            for ai in order {
                let (label, s) = &a15_arms[ai];
                a15_apply(Some(*s));
                let (wall, u, pool, digest) = a15_alone(p == 0);
                a15_apply(None);
                let mut same = String::new();
                if p == 0 {
                    match &first {
                        None => first = Some((label.clone(), digest.clone())),
                        Some((l0, d0)) => assert_eq!(&digest, d0, "A15: a plane of the chain's witnesses differs between [{l0}] and [{label}]"),
                    }
                    same = format!("; every plane of every witness: digest {} (equal to the first arm's, [{}])", &digest[..16], first.as_ref().map(|(l0, _)| l0.as_str()).unwrap_or("-"));
                }
                eprintln!(
                    "D55-AB A15 SEALONLY {name} L{l} [{label}] pass {p}: wall {wall:.3} s in {pool}; user {:.2} s + sys {:.2} s = {:.1} cores; csw voluntary {}, involuntary {}; minor faults {}{same}",
                    u.user,
                    u.sys,
                    (u.user + u.sys) / wall,
                    u.nvcsw,
                    u.nivcsw,
                    u.minflt
                );
            }
        }
    }
    let a15_sample: usize = env_or("HL_A15_SAMPLE", 0usize);
    if a15_sample > 0 {
        let dir = PathBuf::from(std::env::var("HL_A15_SAMPLE_DIR").expect("HL_A15_SAMPLE_DIR names the handshake directory"));
        let wait_for = |f: &std::path::Path, secs: u64| {
            let t = Instant::now();
            while !f.exists() {
                assert!(t.elapsed().as_secs() < secs, "A15-SAMPLE: no {} after {secs} s", f.display());
                std::thread::sleep(std::time::Duration::from_millis(20));
            }
        };
        let arms: Vec<String> = std::env::var("HL_A15_SAMPLE_ARMS").unwrap_or_else(|_| "sp0,spauto".into()).split(',').map(|s| s.trim().to_string()).filter(|s| !s.is_empty()).collect();
        for label in &arms {
            a15_apply(Some(a15_word(label).unwrap_or_else(|| panic!("HL_A15_SAMPLE_ARMS: an unknown arm {label:?}"))));
            eprintln!("A15-SAMPLE READY {label} pid {}", std::process::id());
            wait_for(&dir.join(format!("go.{label}")), 600);
            let t = Instant::now();
            for i in 0..a15_sample {
                let (wall, u, pool, _) = a15_alone(false);
                eprintln!("A15-SAMPLE {label} pass {i}: wall {wall:.3} s in {pool}; user {:.2} s + sys {:.2} s; csw voluntary {}, involuntary {}; minor faults {}", u.user, u.sys, u.nvcsw, u.nivcsw, u.minflt);
            }
            eprintln!("A15-SAMPLE DONE {label} after {:.3} s", t.elapsed().as_secs_f64());
            wait_for(&dir.join(format!("next.{label}")), 600);
            a15_apply(None);
        }
    }
    // [A16] `HL_A16_SEAL_AB=<arms>`, each `+`-joined A15 words (`sp<t>`, `spauto`, `spg`) and
    // A16 words ([`a16_word`]: `a16old`, `a16all`, `a16def`, `a16<form>`, `a16x<form>`, `prod`):
    // the sealing pass ALONE, `HL_A16_SEAL_PASSES` passes (default 3), each arm once per pass
    // (reversed in odd passes with `HL_D55_AB_ALTERNATE=1`); in each arm's first pass one
    // digest of every plane of every witness of the chain, which must be the first arm's. Then
    // `HL_A16_SAMPLE=K` over `HL_A16_SAMPLE_ARMS` (A15's handshake, `A16-SAMPLE READY <arm> pid
    // <pid>`, `$HL_A16_SAMPLE_DIR/go.<arm>` and `next.<arm>`). `HL_A16_ONLY=1` ends the test there.
    {
        let arm_of = |s: &str| a16_seal_arm(s).unwrap_or_else(|| panic!("HL_A16_SEAL_AB / HL_A16_SAMPLE_ARMS: an unknown arm {s:?}"));
        let a16_put = |s: &str| {
            let (seal, forms, prod) = arm_of(s);
            a15_apply(seal);
            a16_apply(forms, prod);
            format!("forms {:#04x}, {}", crate::private_block::witness::a16_forms(), if prod { "build_for_block" } else { "build_accuracy" })
        };
        let a16_off = || {
            a15_apply(None);
            a16_apply(None, false);
        };
        let arms: Vec<String> = std::env::var("HL_A16_SEAL_AB").unwrap_or_default().split(',').map(str::trim).filter(|s| !s.is_empty()).map(str::to_string).collect();
        if !arms.is_empty() {
            let passes: usize = env_or("HL_A16_SEAL_PASSES", 3usize).max(1);
            let alternate: bool = env_or("HL_D55_AB_ALTERNATE", 0usize) == 1;
            let mut first: Option<(String, String)> = None;
            for p in 0..passes {
                let order: Vec<usize> = if alternate && p % 2 == 1 { (0..arms.len()).rev().collect() } else { (0..arms.len()).collect() };
                for ai in order {
                    let label = &arms[ai];
                    let what = a16_put(label);
                    let (wall, u, pool, digest) = a15_alone(p == 0);
                    a16_off();
                    let mut same = String::new();
                    if p == 0 {
                        match &first {
                            None => first = Some((label.clone(), digest.clone())),
                            Some((l0, d0)) => assert_eq!(&digest, d0, "A16: a plane of the chain's witnesses differs between [{l0}] and [{label}]"),
                        }
                        same = format!("; every plane of every witness: digest {} (equal to the first arm's, [{}])", &digest[..16], first.as_ref().map(|(l0, _)| l0.as_str()).unwrap_or("-"));
                    }
                    eprintln!(
                        "D55-AB A16 SEALONLY {name} L{l} [{label}] pass {p}: wall {wall:.3} s in {pool}; user {:.2} s + sys {:.2} s = {:.1} cores; csw voluntary {}, involuntary {}; minor faults {}; {what}{same}",
                        u.user,
                        u.sys,
                        (u.user + u.sys) / wall,
                        u.nvcsw,
                        u.nivcsw,
                        u.minflt
                    );
                }
            }
        }
        let k: usize = env_or("HL_A16_SAMPLE", 0usize);
        if k > 0 {
            let dir = PathBuf::from(std::env::var("HL_A16_SAMPLE_DIR").expect("HL_A16_SAMPLE_DIR names the handshake directory"));
            let wait_for = |f: &std::path::Path, secs: u64| {
                let t = Instant::now();
                while !f.exists() {
                    assert!(t.elapsed().as_secs() < secs, "A16-SAMPLE: no {} after {secs} s", f.display());
                    std::thread::sleep(std::time::Duration::from_millis(20));
                }
            };
            let sample_arms: Vec<String> = std::env::var("HL_A16_SAMPLE_ARMS").unwrap_or_else(|_| "spauto+a16old,spauto+a16def".into()).split(',').map(|s| s.trim().to_string()).filter(|s| !s.is_empty()).collect();
            for (si, label) in sample_arms.iter().enumerate() {
                let what = a16_put(label);
                eprintln!("A16-SAMPLE READY s{si} [{label}] pid {}", std::process::id());
                wait_for(&dir.join(format!("go.s{si}")), 600);
                let t = Instant::now();
                for i in 0..k {
                    let (wall, u, pool, _) = a15_alone(false);
                    eprintln!("A16-SAMPLE s{si} [{label}] pass {i}: wall {wall:.3} s in {pool}; {what}; user {:.2} s + sys {:.2} s; csw voluntary {}, involuntary {}; minor faults {}", u.user, u.sys, u.nvcsw, u.nivcsw, u.minflt);
                }
                eprintln!("A16-SAMPLE DONE s{si} [{label}] after {:.3} s", t.elapsed().as_secs_f64());
                wait_for(&dir.join(format!("next.s{si}")), 600);
                a16_off();
            }
        }
        if env_or("HL_A16_ONLY", 0usize) == 1 {
            eprintln!("D55-AB A16: HL_A16_ONLY=1, the test ends after the sealing passes");
            return;
        }
    }
    if env_or("HL_A15_ONLY", 0usize) == 1 {
        eprintln!("D55-AB A15: HL_A15_ONLY=1, the test ends after the sealing passes");
        return;
    }
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
            for (j, &(b, a)) in jit.iter().enumerate() {
                for (i, &n) in workers.iter().enumerate() {
                    let (wall, bytes, st) = forked_jit(ctx, n, b, a, p == 0);
                    ctx += 1;
                    eprintln!(
                        "D55-AB {name} L{l} T{} forks N{n} JIT {b}:{a} pass {p}: wall {wall:.3} s = {:.2} proved tok/s WITH every witness built on the clock; preflight {:.3} s, commit {:.3} s, forks {:.3} s, join {:.3} s; receipt {bytes} B",
                        sh.tokens,
                        tok(wall),
                        st.preflight_s,
                        st.commit_s,
                        st.forks_s,
                        st.join_s
                    );
                    jit_table[j * workers.len() + i].1.push(wall);
                }
            }
            if sealed_on {
                for (i, &n) in workers.iter().enumerate() {
                    let (wall, seal, bytes) = forked_sealed(ctx, n, p == 0);
                    ctx += 1;
                    eprintln!("D55-AB {name} L{l} T{} forks N{n} SEALED pass {p}: wall {wall:.3} s = {:.2} proved tok/s FROM THE RUN'S INPUT (sealing pass {seal:.3} s on the clock, its witnesses kept); receipt {bytes} B", sh.tokens, tok(wall));
                    sealed_table[i].1.push(wall);
                }
            }
        }
    }
    // A7: `HL_D55_GPU_AB=shared+spin,thread+spin,thread+block,...` (see [`GpuArm`]):
    // after the warm passes, the fork arm at every worker count once per GPU policy
    // per pass (`HL_D55_AB_PASSES`, default `HL_D55_PASSES`), interleaved, in this
    // process (the first pass verified); the process's own policy is restored after
    let gpu_ab: Vec<GpuArm> = std::env::var("HL_D55_GPU_AB").unwrap_or_default().split(',').filter(|s| !s.trim().is_empty()).map(|s| gpu_arm(s).unwrap_or_else(|| panic!("HL_D55_GPU_AB: an unknown arm {s:?}"))).collect();
    let ab_passes: usize = env_or("HL_D55_AB_PASSES", passes).max(1);
    // and per arm and pass, `HL_D55_AB_SEALED=1`: one request from its input; and
    // `HL_D55_AB_PIPE=R`: a stream of R requests, every receipt verified after its clock
    let ab_sealed: bool = env_or("HL_D55_AB_SEALED", 0usize) == 1;
    let ab_pipe: usize = env_or("HL_D55_AB_PIPE", 0usize);
    #[allow(unused_mut)]
    let mut queue_table: Vec<(String, Vec<f64>)> = Vec::new();
    #[allow(unused_mut)]
    let mut ab_sealed_table: Vec<(String, Vec<f64>)> = Vec::new();
    #[allow(unused_mut)]
    let mut ab_pipe_table: Vec<(String, Vec<(f64, f64)>)> = Vec::new();
    #[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
    if !gpu_ab.is_empty() {
        let own_q = crate::gpu::metal_set_queues_for_test(false);
        let own_w = crate::gpu::metal_set_wait_for_test(None);
        crate::gpu::metal_set_queues_for_test(own_q);
        crate::gpu::metal_set_wait_for_test(own_w);
        // A8: the process's store fold form, restored after
        let own_form = crate::gpu::metal_set_a8_fold_for_test(None);
        crate::gpu::metal_set_a8_fold_for_test(own_form);
        queue_table = gpu_ab.iter().flat_map(|a| workers.iter().map(move |n| (format!("forks N={n} {}", a.label), Vec::new()))).collect();
        ab_sealed_table = gpu_ab.iter().flat_map(|a| workers.iter().map(move |n| (format!("forks N={n} SEALED {}", a.label), Vec::new()))).collect();
        ab_pipe_table = gpu_ab.iter().flat_map(|a| workers.iter().map(move |n| (format!("PIPE {ab_pipe} N={n} {}", a.label), Vec::new()))).collect();
        // A11: `HL_D55_AB_ALTERNATE=1` runs the arms in reverse order in every odd
        // pass, so one process gives paired changes in both arm orders (the second
        // arm of a pass ran about 4.5% faster whichever it was, A7)
        let alternate: bool = env_or("HL_D55_AB_ALTERNATE", 0usize) == 1;
        for p in 0..ab_passes {
            let order: Vec<usize> = if alternate && p % 2 == 1 { (0..gpu_ab.len()).rev().collect() } else { (0..gpu_ab.len()).collect() };
            for ai in order {
                let a = &gpu_ab[ai];
                crate::gpu::metal_set_queues_for_test(a.per_thread.unwrap_or(own_q));
                crate::gpu::metal_set_wait_for_test(a.wait);
                crate::gpu::metal_set_device_fold_for_test(Some(a.devfold));
                crate::private_block::argument::set_device_tables_for_test(a.device_tables);
                crate::gpu::metal_set_a8_fold_for_test(match a.a8_form {
                    Some(0) => Some(crate::gpu::MetalA8Form::M11),
                    Some(1) => Some(crate::gpu::MetalA8Form::Sparse),
                    Some(_) => Some(crate::gpu::MetalA8Form::Small),
                    None => own_form,
                });
                a11_set_arm(&a.label);
                // [A14]
                a14_apply(&a.a14);
                // [A15]
                a15_apply(a.seal);
                // [A17]
                a17_apply(a.a17);
                // [A16]
                a16_apply(a.a16, a.prod);
                // [A18]
                a18_apply(&a.a18);
                if a.fork_pool == Some(usize::MAX) {
                    set_fork_pool_auto_for_test();
                } else {
                    set_fork_pool_for_test(a.fork_pool);
                }
                for (i, &n) in workers.iter().enumerate() {
                    // A11: the phase clock in every fork of this arm's proof-only call
                    // (the workers inherit this thread's switch, D55 review F5)
                    crate::private_block::timing::force(if a.phases { Some(true) } else { None });
                    let (wall, bytes, st) = forked(ctx, n, p == 0);
                    crate::private_block::timing::force(None);
                    ctx = ctx.wrapping_add(1);
                    eprintln!(
                        "D55-AB GPU-AB {name} L{l} T{} forks N{n} [{}] pass {p}: wall {wall:.3} s = {:.2} proved tok/s; preflight {:.3} s, commit {:.3} s, forks {:.3} s, join {:.3} s; receipt {bytes} B",
                        sh.tokens,
                        a.label,
                        tok(wall),
                        st.preflight_s,
                        st.commit_s,
                        st.forks_s,
                        st.join_s
                    );
                    queue_table[ai * workers.len() + i].1.push(wall);
                }
                if ab_sealed {
                    for (i, &n) in workers.iter().enumerate() {
                        let (wall, seal, bytes) = forked_sealed(ctx, n, p == 0);
                        ctx = ctx.wrapping_add(1);
                        eprintln!("D55-AB GPU-AB {name} L{l} T{} forks N{n} [{}] SEALED pass {p}: wall {wall:.3} s = {:.2} proved tok/s FROM THE RUN'S INPUT (sealing pass {seal:.3} s on the clock); receipt {bytes} B", sh.tokens, a.label, tok(wall));
                        ab_sealed_table[ai * workers.len() + i].1.push(wall);
                    }
                }
                if ab_pipe > 0 {
                    for (i, &n) in workers.iter().enumerate() {
                        let (wall, done, lat, rcs) = piped(ctx, n, ab_pipe);
                        ctx = ctx.wrapping_add(ab_pipe as u8);
                        let amortized = (ab_pipe * sh.tokens) as f64 / wall;
                        let steady = if ab_pipe > 1 { ((ab_pipe - 1) * sh.tokens) as f64 / (done[ab_pipe - 1] - done[0]) } else { f64::NAN };
                        for (st, rc) in &rcs {
                            let fr = ForkRun::new(st, D55OptIn::unreviewed_prototype()).unwrap();
                            verify_run_with_forks(&fr, &rep, rc, 6).expect("a streamed request's receipt verifies (GPU-policy A/B)");
                        }
                        eprintln!(
                            "D55-AB GPU-AB PIPE {name} L{l} T{} forks N{n} [{}] pass {p}: {ab_pipe} requests in {wall:.3} s; amortized {amortized:.2} proved tok/s; steady state {steady:.2} tok/s (completions {}); per-request latency {}; all {ab_pipe} receipts verified after the clock",
                            sh.tokens,
                            a.label,
                            done.iter().map(|d| format!("{d:.2}")).collect::<Vec<_>>().join(", "),
                            lat.iter().map(|d| format!("{d:.2}")).collect::<Vec<_>>().join(", ")
                        );
                        ab_pipe_table[ai * workers.len() + i].1.push((steady, amortized));
                    }
                }
            }
        }
        crate::gpu::metal_set_queues_for_test(own_q);
        crate::gpu::metal_set_wait_for_test(own_w);
        crate::gpu::metal_set_device_fold_for_test(None);
        crate::private_block::argument::set_device_tables_for_test(None);
        crate::gpu::metal_set_a8_fold_for_test(own_form);
        // [A14]
        a14_apply(&A14Arm::default());
        // [A15]
        a15_apply(None);
        // [A17]
        a17_apply((None, None));
        // [A16]
        a16_apply(None, false);
        // [A18]
        a18_apply(&A18Arm::default());
        a11_set_arm("");
        set_fork_pool_for_test(None);
    }
    #[cfg(not(all(feature = "gpu-metal", not(feature = "gpu-cuda"))))]
    let _ = (&gpu_ab, ab_passes, ab_sealed, ab_pipe);
    // A11: `HL_A11_SAMPLE=K`: at each worker count, K proof-only fork calls back to
    // back, on witness sets built before the first, between two handshakes with an
    // outside sampler (`/usr/bin/sample`): the harness prints `A11-SAMPLE READY
    // N<n> pid <pid>`, waits for the file `$HL_A11_SAMPLE_DIR/go.N<n>`, runs the K
    // calls, prints `A11-SAMPLE DONE N<n>` and waits for `next.N<n>`. These calls are
    // not verified (every other arm verifies its first pass); their receipts are
    // dropped after the window.
    let sample_k: usize = env_or("HL_A11_SAMPLE", 0usize);
    if sample_k > 0 {
        let dir = PathBuf::from(std::env::var("HL_A11_SAMPLE_DIR").expect("HL_A11_SAMPLE_DIR names the handshake directory"));
        let wait_for = |f: &std::path::Path, secs: u64| {
            let t = Instant::now();
            while !f.exists() {
                assert!(t.elapsed().as_secs() < secs, "A11-SAMPLE: no {} after {secs} s", f.display());
                std::thread::sleep(std::time::Duration::from_millis(20));
            }
        };
        for &n in &workers {
            let mut sets = Vec::with_capacity(sample_k);
            for _ in 0..sample_k {
                let src = witnesses();
                let (st, owners) = statement(ctx);
                ctx = ctx.wrapping_add(1);
                sets.push((src, st, owners));
            }
            eprintln!("A11-SAMPLE READY N{n} pid {}", std::process::id());
            wait_for(&dir.join(format!("go.N{n}")), 600);
            let t = Instant::now();
            let mut keep = Vec::with_capacity(sample_k);
            for (i, (mut src, st, owners)) in sets.into_iter().enumerate() {
                let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).unwrap();
                let u0 = usage_now();
                let t1 = Instant::now();
                let (rc, stats) = prove_run_with_forks(&fr, &rep, &mut src, owners, n).expect("the D55 fork run proves (A11 sampling window)");
                let wall = t1.elapsed().as_secs_f64();
                a11_report(&name, l, n, "sample", wall, usage_now().since(u0), &stats);
                eprintln!("A11-SAMPLE N{n} call {i}: started {:.3} s into the window, wall {wall:.3} s, forks {:.3} s", t.elapsed().as_secs_f64() - wall, stats.forks_s);
                keep.push(rc);
            }
            eprintln!("A11-SAMPLE DONE N{n} after {:.3} s", t.elapsed().as_secs_f64());
            wait_for(&dir.join(format!("next.N{n}")), 600);
            drop(keep);
        }
    }
    // D64 / H124d: the stream, once, after the warm passes
    if pipe > 0 {
        for &n in &workers {
            let (wall, done, lat, rcs) = piped(ctx, n, pipe);
            ctx = ctx.wrapping_add(pipe as u8);
            let amortized = (pipe * sh.tokens) as f64 / wall;
            let steady = if pipe > 1 { ((pipe - 1) * sh.tokens) as f64 / (done[pipe - 1] - done[0]) } else { f64::NAN };
            eprintln!(
                "D55-AB PIPE {name} L{l} T{} forks N{n}: {pipe} requests in {wall:.3} s; amortized {amortized:.2} proved tok/s (all witness work on the clock); steady state {steady:.2} tok/s (completions {}); per-request latency {}",
                sh.tokens,
                done.iter().map(|d| format!("{d:.2}")).collect::<Vec<_>>().join(", "),
                lat.iter().map(|d| format!("{d:.2}")).collect::<Vec<_>>().join(", ")
            );
            let tv = Instant::now();
            for (st, rc) in &rcs {
                let fr = ForkRun::new(st, D55OptIn::unreviewed_prototype()).unwrap();
                verify_run_with_forks(&fr, &rep, rc, 6).expect("a streamed request's receipt verifies");
            }
            eprintln!("D55-AB PIPE {name} L{l} forks N{n}: all {pipe} receipts verified after the clock in {:.1} s", tv.elapsed().as_secs_f64());
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
    for (arm, walls) in sealed_table.iter().filter(|(_, w)| !w.is_empty()) {
        let best = walls.iter().cloned().fold(f64::INFINITY, f64::min);
        let mean = walls.iter().sum::<f64>() / walls.len() as f64;
        eprintln!("D55-AB SUMMARY | {arm:<14} | one request end to end from its input, measured | best {best:.3} s = {:.2} tok/s | mean {mean:.3} s = {:.2} tok/s", tok(best), tok(mean));
    }
    for (arm, walls) in queue_table.iter().filter(|(_, w)| !w.is_empty()) {
        let best = walls.iter().cloned().fold(f64::INFINITY, f64::min);
        let mean = walls.iter().sum::<f64>() / walls.len() as f64;
        eprintln!("D55-AB SUMMARY | {arm:<14} | A7 GPU-policy A/B, interleaved, {} passes | best {best:.3} s = {:.2} tok/s | mean {mean:.3} s = {:.2} tok/s", walls.len(), tok(best), tok(mean));
    }
    for (arm, walls) in ab_sealed_table.iter().filter(|(_, w)| !w.is_empty()) {
        let best = walls.iter().cloned().fold(f64::INFINITY, f64::min);
        let mean = walls.iter().sum::<f64>() / walls.len() as f64;
        eprintln!("D55-AB SUMMARY | {arm:<14} | A7 GPU-policy A/B, one request from its input, interleaved, {} passes | best {best:.3} s = {:.2} tok/s | mean {mean:.3} s = {:.2} tok/s", walls.len(), tok(best), tok(mean));
    }
    for (arm, v) in ab_pipe_table.iter().filter(|(_, v)| !v.is_empty()) {
        let k = v.len() as f64;
        let (steady, amortized) = (v.iter().map(|x| x.0).sum::<f64>() / k, v.iter().map(|x| x.1).sum::<f64>() / k);
        let best = v.iter().map(|x| x.0).fold(0.0f64, f64::max);
        eprintln!("D55-AB SUMMARY | {arm:<14} | A7 GPU-policy A/B, stream, interleaved, {} passes | steady state mean {steady:.2} tok/s (best {best:.2}) | amortized mean {amortized:.2} tok/s", v.len());
    }
    for (arm, walls) in jit_table.iter().filter(|(_, w)| !w.is_empty()) {
        let best = walls.iter().cloned().fold(f64::INFINITY, f64::min);
        let mean = walls.iter().sum::<f64>() / walls.len() as f64;
        eprintln!(
            "D55-AB SUMMARY | {arm:<14} | witness on the clock | best {best:.3} s = {:.2} tok/s | mean {mean:.3} s = {:.2} tok/s | with the sealing pass ({seal_s:.3} s) one request end to end {:.3} s = {:.2} tok/s",
            tok(best),
            tok(mean),
            best + seal_s,
            tok(best + seal_s)
        );
    }
    #[cfg(feature = "gpu-metal")]
    {
        let (compile, rounds) = crate::gpu::metal_sumcheck_stats();
        eprintln!("D55-AB device evidence: HL_GPU={:?}, Metal kernel compile {compile:.3} s, device sumcheck rounds {rounds:.3} s", std::env::var("HL_GPU").ok());
    }
    // A4: how many witness weight products ran on the device, and where their time went
    #[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
    {
        let (n, in_place, s) = crate::gpu::witness_product_stats();
        let phases: Vec<String> = crate::gpu::WITNESS_PRODUCT_PHASES.iter().zip(s).map(|(p, s)| format!("{p} {s:.3} s")).collect();
        eprintln!(
            "D55-AB A4 witness products on the device: {n}, {in_place} written in place (HL_GPU_WITNESS={:?}, route {:?}); summed {}",
            std::env::var("HL_GPU_WITNESS").ok(),
            std::env::var("HL_GPU_WITNESS_ROUTE").ok(),
            phases.join(", ")
        );
    }
    eprintln!("D55-AB {name} L{l}: total {:.1} s", t0.elapsed().as_secs_f64());
}

// ---- [A18] the forks' host work, and A13's before-challenge parts on the new base (efficiency plan A18) ----
//
// The harness's arm words (joinable with every other word) and the byte tests of
// A13's port. `protocol.rs`'s two forms: `tabinv0` / `tabinv1` (the table helpers
// inverted again, or read from the inverse tables already made), `registry0` /
// `registry1` (`define` re-checks its block's registry per slot, or the
// preflight's record stands in), `pubtab0` / `pubtab1` (`define`'s public tables
// built in a loop, or in indexed parallel maps); `a18old` / `a18new` all three
// off / on. A13's window
// (`run_fork.rs`, `HL_D55_AHEAD`): `noahead` / `ahead<W>`, `aw<k>` side workers,
// `ap<t>` threads each, `qos<q>`; and `stsl`: a stream's statements made on its
// sealing thread (forced by any window; the harness before A18 made them on the
// prover thread), so a window can be compared at an equal statement placement.

/// **[A18]** one arm's A18 words (see the block comment above)
#[derive(Clone, Copy, Debug, Default)]
struct A18Arm {
    tabinv: Option<bool>,
    registry: Option<bool>,
    pubtab: Option<bool>,
    ahead: [Option<usize>; 4],
    stsl: bool,
}

/// [A18] one `+`-joined word of an arm, if it is A18's
fn a18_word(a: &mut A18Arm, w: &str) -> bool {
    match w {
        "tabinv0" => a.tabinv = Some(false),
        "tabinv1" => a.tabinv = Some(true),
        "registry0" => a.registry = Some(false),
        "registry1" => a.registry = Some(true),
        "pubtab0" => a.pubtab = Some(false),
        "pubtab1" => a.pubtab = Some(true),
        "a18old" => {
            a.tabinv = Some(false);
            a.registry = Some(false);
            a.pubtab = Some(false);
        }
        "a18new" => {
            a.tabinv = Some(true);
            a.registry = Some(true);
            a.pubtab = Some(true);
        }
        "noahead" => a.ahead[0] = Some(0),
        "stsl" => a.stsl = true,
        _ => {
            for (p, i) in [("ahead", 0usize), ("aw", 1), ("ap", 2), ("qos", 3)] {
                if let Some(v) = w.strip_prefix(p).and_then(|t| t.parse::<usize>().ok()) {
                    a.ahead[i] = Some(v);
                    return true;
                }
            }
            return false;
        }
    }
    true
}

/// [A18] `stsl` in force (the stream's sealing thread reads it)
static A18_STSL: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// [A18] put an arm's words in force for the whole process; `A18Arm::default()`
/// restores the environment's
#[cfg_attr(not(all(feature = "gpu-metal", not(feature = "gpu-cuda"))), allow(dead_code))]
fn a18_apply(a: &A18Arm) {
    crate::private_block::protocol::set_a18_for_test(a.tabinv, a.registry, a.pubtab);
    set_ahead_for_test(a.ahead[0], a.ahead[1], a.ahead[2]);
    set_ahead_qos_for_test(a.ahead[3]);
    A18_STSL.store(a.stsl, std::sync::atomic::Ordering::Relaxed);
}

/// [A18] whether a stream's statements are made on its sealing thread
fn a18_stsl() -> bool {
    A18_STSL.load(std::sync::atomic::Ordering::Relaxed) || ahead_window() > 0
}

/// [A18] (A13's) this process's physical footprint in GiB (macOS
/// `proc_pid_rusage`, `ri_phys_footprint`, which counts Metal's shared buffers;
/// NaN elsewhere)
fn a18_footprint_gib() -> f64 {
    #[cfg(target_os = "macos")]
    {
        extern "C" {
            fn proc_pid_rusage(pid: i32, flavor: i32, buffer: *mut u64) -> i32;
            fn getpid() -> i32;
        }
        // RUSAGE_INFO_V2: a 16-byte uuid, then u64 fields; ri_phys_footprint is the 8th
        let mut b = [0u64; 64];
        // SAFETY: fills at most sizeof(rusage_info_v2) = 152 bytes of the 512-byte buffer
        if unsafe { proc_pid_rusage(getpid(), 2, b.as_mut_ptr()) } == 0 {
            return b[9] as f64 / (1u64 << 30) as f64;
        }
    }
    f64::NAN
}

/// [A18] (A13's) the footprint at the start of a call, its peak (sampled every
/// 10 ms on a side thread) and at the end
struct A18Mem {
    f0: f64,
    stop: std::sync::Arc<std::sync::atomic::AtomicBool>,
    h: std::thread::JoinHandle<f64>,
}

impl A18Mem {
    fn start() -> A18Mem {
        let f0 = a18_footprint_gib();
        let stop = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        let s = stop.clone();
        let h = std::thread::spawn(move || {
            let mut peak = f0;
            while !s.load(std::sync::atomic::Ordering::Relaxed) {
                peak = peak.max(a18_footprint_gib());
                std::thread::sleep(std::time::Duration::from_millis(10));
            }
            peak
        });
        A18Mem { f0, stop, h }
    }
    fn stop(self) -> (f64, f64, f64) {
        self.stop.store(true, std::sync::atomic::Ordering::Relaxed);
        let f1 = a18_footprint_gib();
        let peak = self.h.join().unwrap_or(f64::NAN).max(f1);
        (self.f0, peak, f1)
    }
}

/// [A18] one request from its input with A13's window: A13's SEALED line (with
/// the forks parked, the parts taken back whole, the feeder's wait and the
/// footprint; `a13/seal_pairs.py`) and A15's (`a15/seal_pairs.py`)
#[allow(clippy::too_many_arguments)]
fn a18_sealed_report(name: &str, l: usize, n: usize, arm: &str, wall: f64, seal: f64, u: Usage, st: &ForkStats, pool: &str, mem: (f64, f64, f64)) {
    let cpu = u.user + u.sys;
    let mean = |v: &[f64]| if v.is_empty() { f64::NAN } else { v.iter().sum::<f64>() / v.len() as f64 };
    let parked: Vec<f64> = st.fork_before_s.iter().filter(|(_, p)| *p).map(|(s, _)| *s).collect();
    let inline: Vec<f64> = st.fork_before_s.iter().filter(|(_, p)| !*p).map(|(s, _)| *s).collect();
    eprintln!(
        "D55-AB A13 SEALED {name} L{l} N{n} [{arm}]: wall {wall:.3} s; sealing pass {seal:.3} s ({:.1} cores busy, {cpu:.1} CPU-s); prove call {:.3} s: preflight {:.3}, commit {:.3}, forks {:.3}, join {:.3} s; {}/{l} forks parked ({} queued parts taken back whole), feeder waited {:.3} s; before-challenge parts: parked mean {:.1} ms (sum {:.2} s), in a fork mean {:.1} ms (sum {:.2} s); footprint start {:.1} GiB, peak {:.1} GiB, end {:.1} GiB",
        cpu / seal.max(1e-9),
        st.total_s,
        st.preflight_s,
        st.commit_s,
        st.forks_s,
        st.join_s,
        st.ahead_parked,
        st.ahead_taken_back,
        st.ahead_wait_s,
        1e3 * mean(&parked),
        parked.iter().sum::<f64>(),
        1e3 * mean(&inline),
        inline.iter().sum::<f64>(),
        mem.0,
        mem.1,
        mem.2
    );
    eprintln!(
        "D55-AB A15 SEALED {name} L{l} N{n} [{arm}]: sealing pass {seal:.3} s in {pool}: user {:.2} s + sys {:.2} s = {:.1} cores; csw voluntary {}, involuntary {}; minor faults {}",
        u.user,
        u.sys,
        cpu / seal.max(1e-9),
        u.nvcsw,
        u.nivcsw,
        u.minflt
    );
}

/// [A18] a stream's sealed request: its witnesses whole, or its forks'
/// before-challenge parts made beside the sealing pass (`seal_ahead`)
enum A18Sealed {
    Whole(Vec<Option<Witness>>, Vec<Vec<i16>>),
    Ahead(ForkAhead, Vec<Vec<i16>>),
}

// ---- [A18] the byte tests of A13's port: a parked fork is the same fork, byte for byte ----
//
// A D55 receipt cannot be made twice: its generators are the operating system's
// and its endpoint owners are consumed (and have no `Clone`, by design). So the
// tests hold the randomness fixed with `run_fork.rs`'s test-only seeded
// generators ([`SeededForks`]: the commit phase's and every fork's replaced,
// right after construction, by [`a18_seeded`]) and compare what CAN be compared
// on one statement (A13's `run_fork_a13_tests.rs`, ported onto A14-A17):
// * **all forks, directly** ([`a18_check_direct`]): on one statement, one
//   commit phase and the preflight's records, every fork `k` proved whole
//   against the same fork with its before-challenge part made first on other
//   threads in rayon pools of 1, 2 and 6, PARKED, moved and finished in reverse
//   block order on yet other threads: the fork frame, the end state and the
//   joined claims, byte for byte;
// * **the real paths** ([`a18_check_paths`]): `prove_run_with_forks` (no
//   window), `prove_run_with_forks_sealing` and `seal_ahead` (on another thread,
//   as a stream's sealing thread runs it) then `prove_run_with_forks_ahead`, at
//   several windows, fork-worker counts, side-worker counts and side pools. Each
//   receipt verifies, its head is the replayed commit phase's, its forks parked
//   are the window's, and each interior fork equals that fork recomputed the
//   OTHER way.
// Both at the W16R2 rung, under the A17 and A18 forms in force (the defaults):
// on the CPU in the suite, and on the Metal device (ignored; run alone by name).

const A18_SEED: u64 = 20261105;

/// the seeded generator these tests install in place of generator `k`
/// (`usize::MAX`: the commit phase's)
fn a18_seeded(seed: u64, k: usize) -> ZkRng {
    let mut d = b"a13 byte test: the seeded generator of fork ".to_vec();
    d.extend_from_slice(&(k as u64).to_le_bytes());
    ZkRng::new(seed, &d)
}

/// the D55 harness's fixture at a W16R2 profile: ONE public synthetic block at
/// every layer and the honest chain from M10's admissible input
struct A18Fix {
    sh: crate::private_block::shape::Shape,
    blk: BlockPublic,
    xs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
    input: Vec<i16>,
    output: Vec<i16>,
    model: TrainedModelStatement,
    run_profile: &'static str,
    l: usize,
}

impl A18Fix {
    fn new(profile: &str, l: usize) -> A18Fix {
        use crate::private_block::shape;
        let original = crate::private_block::range16_tests::built(profile);
        let (sh, data, public, ff) = crate::private_block::range16_tests::case(original, 3);
        let blk = BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
        let build = |x: &[i16]| witness::build_accuracy(&sh, &public, &ff, &data, x);
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
        let (mut xs, mut planes, mut input, mut output) = (vec![x0], Vec::new(), Vec::new(), Vec::new());
        for k in 0..l {
            let w = build(&xs[k]).unwrap_or_else(|e| panic!("{}: layer {k} of the synthetic chain is not admissible: {e}", sh.name));
            if k == 0 {
                input = w.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect();
            }
            let out = w.output().unwrap();
            xs.push(unpad(&sh, &out));
            if k + 1 < l {
                planes.push(out);
            } else {
                output = out;
            }
        }
        let run_profile = crate::private_block::w16_privacy_gate_tests::W16_TEST_RUN_PROFILES.iter().find(|(_, b)| *b == sh.profile).map(|(r, _)| *r).expect("a W16R2 test-only run identity");
        let mut prov = Provenance::recipe("A18 byte test fixture (public synthetic)", 1.0, [3; 32], [4; 32]);
        prov.rope_theta = shape::trained_rope_theta(sh.profile).expect("the profile's pinned RoPE base");
        prov.rope_scaling = shape::trained_rope_scaling(sh.profile).expect("the profile's pinned RoPE transform");
        let source = ModelSource { kind: SourceKind::PublicSyntheticRecipe, repo: "synthetic/a18".into(), revision: "a18".into(), weights_sha256: [0; 32], config_sha256: [0; 32], checkpoint_parameters: 0, checkpoint_layers: l as u32 };
        let r0 = LayerRecord::of_block(0, &blk, vec![]);
        let records: Vec<LayerRecord> = (0..l)
            .map(|i| {
                let mut r = r0.clone();
                r.index = i as u32;
                r
            })
            .collect();
        let model = TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(&sh, run_profile, source, IntegerCalibration::as_the_code_proves(&sh, &prov), records).unwrap();
        A18Fix { sh, blk, xs, planes, input, output, model, run_profile, l }
    }

    fn witness(&self, k: usize) -> Witness {
        let data = self.blk.accuracy().expect("an accuracy block");
        witness::build_accuracy(&self.sh, self.blk.attention(), self.blk.feed_forward(), data, &self.xs[k]).expect("the chain was admissible")
    }

    /// a fresh statement (its endpoint commitments drawn anew) and its owners
    fn statement(&self, ctx: u8) -> (RunStatement, Endpoints) {
        let c = [ctx; 32];
        let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&self.sh, c, 0, 0).unwrap(), &self.input, &self.output).unwrap();
        let st = RunStatement::new_bound_from_digests(RunShape::new(self.sh.clone(), self.l, self.run_profile).unwrap(), c, expected, vec![self.blk.digest(); self.l], &vec![(0, 0); self.l], &self.model).unwrap();
        (st, owners)
    }

    /// every boundary plane only (every witness handed over)
    fn planes_only(&self) -> Chain {
        Chain { witnesses: (0..self.l).map(|_| None).collect(), planes: self.planes.clone(), tamper: None }
    }

    /// every witness and boundary plane, kept whole
    fn whole(&self) -> Chain {
        Chain { witnesses: (0..self.l).map(|k| Some(self.witness(k))).collect(), planes: self.planes.clone(), tamper: None }
    }
}

/// the commit phase replayed with the seeded commit generator: the boundary
/// owners, their roots, the binding and the head those make
fn a18_commit_phase(fr: &ForkRun, fix: &A18Fix, ntt: &NttTables) -> (Vec<PreparedBoundary>, Vec<Digest>, Digest, Vec<u8>) {
    let st = fr.st;
    let l = st.rs.l;
    let tag = st.rs.sh.hash_tag();
    let mut rng0 = seeded_generator(usize::MAX).expect("a SeededForks guard is live");
    let bounds: Vec<PreparedBoundary> = (0..l - 1).map(|k| boundary::prepare(&st.boundary_spec(k).unwrap(), &words(&fix.planes[k]), ntt, &mut rng0, &tag).unwrap()).collect();
    let roots: Vec<Digest> = bounds.iter().map(|p| p.root()).collect();
    let mut tr = fr.transcript().unwrap();
    let binding = tr.state();
    absorb_commit(&mut tr, st, &roots, None).unwrap();
    let head = fw::encode_head(&binding, l, &roots, &position_tag(&tr)).unwrap();
    (bounds, roots, binding, head)
}

fn a18_whole_out(d: Done) -> ForkOut {
    match d {
        Done::Out(o) => o,
        Done::Parked(_) => panic!("a fork parked after the commit phase"),
    }
}

fn a18_parked_of(d: Done) -> Box<Parked> {
    match d {
        Done::Parked(p) => p,
        Done::Out(_) => panic!("a fork finished before the commit phase"),
    }
}

fn a18_pool(t: usize) -> rayon::ThreadPool {
    rayon::ThreadPoolBuilder::new().num_threads(t).build().expect("a rayon pool")
}

/// the same fork, compared: its frame, its end state and its joined claims
fn a18_same(what: &str, a: &ForkOut, b: &ForkOut) {
    assert_eq!(a.k, b.k, "{what}: two forks compared");
    assert!(a.bytes == b.bytes, "{what}: fork {}'s frames differ ({} B against {} B)", a.k, a.bytes.len(), b.bytes.len());
    assert_eq!(a.end, b.end, "{what}: fork {}'s end states differ", a.k);
    assert_eq!([claim_bytes(&a.claims[0]), claim_bytes(&a.claims[1])], [claim_bytes(&b.claims[0]), claim_bytes(&b.claims[1])], "{what}: fork {}'s joined claims differ", a.k);
}

/// **All forks, directly**: on one statement, one commit phase and the
/// preflight's records, each fork whole against the same fork parked (its part
/// made on another thread in a pool of `parts` threads, all of them at once)
/// and finished in reverse block order on other threads in a pool of `finish`.
/// Returns a summary line.
fn a18_check_direct(fix: &A18Fix) -> String {
    let _seeded = SeededForks::on(A18_SEED, a18_seeded);
    let hooks = ForkHooks::capture();
    let (st, owners) = fix.statement(7);
    let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).unwrap();
    let l = st.rs.l;
    let [ein, eout] = protocol::check_endpoints(&st.rs.sh, &st.expected, owners).unwrap();
    let ntt = NttTables::new(st.rs.ntt_log());
    let (bounds, roots, binding, _) = a18_commit_phase(&fr, fix, &ntt);
    let in_data: Vec<&[Fp]> = (0..l).map(|k| if k == 0 { &ein.data[..] } else { bounds[k - 1].data() }).collect();
    let out_data: Vec<&[Fp]> = (0..l).map(|k| if k + 1 == l { &eout.data[..] } else { bounds[k].data() }).collect();
    let blocks = RepeatBlock::new(&fix.blk, l);
    let checked = preflight(&st, &blocks, true).expect("the preflight passes");
    let late = ForkCtx { fr: &fr, blocks: &blocks, ntt: &ntt, cheat: Cheat::default(), late: Some(ForkLate { checked: &checked, roots: &roots, in_data, out_data, binding }) };
    let early = ForkCtx { fr: &fr, blocks: &blocks, ntt: &ntt, cheat: Cheat::default(), late: None };
    let whole: Vec<ForkOut> = (0..l).map(|k| a18_whole_out(late.prove_one(k, fix.witness(k)).unwrap())).collect();
    let mut sizes = Vec::new();
    for (parts, finish) in [(1usize, 1usize), (2, 3), (6, 2)] {
        let (pp, pf) = (a18_pool(parts), a18_pool(finish));
        let parked: Vec<Box<Parked>> = std::thread::scope(|s| {
            let hs: Vec<_> = (0..l)
                .map(|k| {
                    let (early, pp) = (&early, &pp);
                    s.spawn(move || {
                        let _h = hooks.install();
                        pp.install(|| {
                            let _h = hooks.install();
                            early.prove_one(k, fix.witness(k))
                        })
                    })
                })
                .collect();
            hs.into_iter().map(|h| a18_parked_of(h.join().expect("a part's thread").expect("a fork's before-challenge part"))).collect()
        });
        assert!(parked.iter().enumerate().all(|(k, p)| p.k == k && p.sealing), "the parts are not each block's, parked");
        let mut outs: Vec<ForkOut> = std::thread::scope(|s| {
            let hs: Vec<_> = parked
                .into_iter()
                .rev()
                .map(|p| {
                    let (late, pf) = (&late, &pf);
                    s.spawn(move || {
                        let _h = hooks.install();
                        pf.install(|| {
                            let _h = hooks.install();
                            late.finish_one(*p)
                        })
                    })
                })
                .collect();
            hs.into_iter().map(|h| h.join().expect("a finishing thread").expect("a parked fork's rest")).collect()
        });
        outs.sort_by_key(|o| o.k);
        for (a, b) in whole.iter().zip(&outs) {
            a18_same(&format!("parts in a pool of {parts}, finished in a pool of {finish}"), a, b);
        }
        sizes.push(format!("{parts}/{finish}"));
    }
    format!("{} L{l}: all {l} forks parked (parts / finish pools {}) equal the whole forks byte for byte ({} B of fork frames)", fix.sh.name, sizes.join(", "), whole.iter().map(|o| o.bytes.len()).sum::<usize>())
}

/// the interior forks of `rc` (both IO commitments boundaries) recomputed the
/// other way on its own statement's replayed commit phase: whole if
/// `parked_in_rc`, else parked on another thread and finished here
fn a18_recompute_interior(fr: &ForkRun, fix: &A18Fix, rc: &ForkReceipt, parked_in_rc: bool, hooks: ForkHooks) {
    let l = fr.st.rs.l;
    let ntt = NttTables::new(fr.st.rs.ntt_log());
    let (bounds, roots, binding, head) = a18_commit_phase(fr, fix, &ntt);
    assert!(head == rc.head, "the replayed commit phase is not the receipt's head");
    let none: &[Fp] = &[];
    let in_data: Vec<&[Fp]> = (0..l).map(|k| if k == 0 { none } else { bounds[k - 1].data() }).collect();
    let out_data: Vec<&[Fp]> = (0..l).map(|k| if k + 1 == l { none } else { bounds[k].data() }).collect();
    let blocks = RepeatBlock::new(&fix.blk, l);
    let checked = preflight(fr.st, &blocks, true).expect("the preflight passes");
    let late = ForkCtx { fr, blocks: &blocks, ntt: &ntt, cheat: Cheat::default(), late: Some(ForkLate { checked: &checked, roots: &roots, in_data, out_data, binding }) };
    let early = ForkCtx { fr, blocks: &blocks, ntt: &ntt, cheat: Cheat::default(), late: None };
    let p3 = a18_pool(3);
    for k in 1..l - 1 {
        let o = if parked_in_rc {
            a18_whole_out(late.prove_one(k, fix.witness(k)).unwrap())
        } else {
            let p = std::thread::scope(|s| {
                let (early, p3) = (&early, &p3);
                s.spawn(move || {
                    let _h = hooks.install();
                    p3.install(|| {
                        let _h = hooks.install();
                        early.prove_one(k, fix.witness(k))
                    })
                })
                .join()
                .expect("a part's thread")
            });
            late.finish_one(*a18_parked_of(p.unwrap())).unwrap()
        };
        assert!(o.bytes == rc.forks[k], "fork {k} of a receipt made {} is not that fork made {}", if parked_in_rc { "with parts" } else { "whole" }, if parked_in_rc { "whole" } else { "parked" });
    }
}

/// **The real paths**, at `n` fork workers, each window and each
/// `(side workers, side pool threads)`. Returns the summary lines.
fn a18_check_paths(fix: &A18Fix, ns: &[usize], windows: &[usize], sides: &[(usize, usize)]) -> Vec<String> {
    let _seeded = SeededForks::on(A18_SEED, a18_seeded);
    let hooks = ForkHooks::capture();
    let l = fix.l;
    let blocks = RepeatBlock::new(&fix.blk, l);
    let mut ctx = 40u8;
    let mut lines = Vec::new();
    let mut prove = |path: &str, n: usize, window: usize, side: (usize, usize)| -> (usize, usize) {
        set_ahead_for_test(Some(window), Some(side.0), Some(side.1));
        ctx = ctx.wrapping_add(1);
        let (st, owners) = fix.statement(ctx);
        let fr = ForkRun::new(&st, D55OptIn::unreviewed_prototype()).unwrap();
        let (rc, stats) = match path {
            "whole" => prove_run_with_forks(&fr, &blocks, &mut fix.whole(), owners, n),
            "sealing" => prove_run_with_forks_sealing(&fr, &blocks, owners, n, |push| {
                for k in 0..l {
                    push(k, fix.witness(k))?;
                }
                Ok(fix.planes_only())
            }),
            _ => {
                // a stream's: the sealing pass and its parts on another thread
                let ahead = std::thread::scope(|s| {
                    let (fr, blocks) = (&fr, &blocks);
                    s.spawn(move || {
                        let _h = hooks.install();
                        seal_ahead(fr, blocks, |push| {
                            for k in 0..l {
                                push(k, fix.witness(k))?;
                            }
                            Ok(())
                        })
                    })
                    .join()
                    .expect("the sealing thread")
                })
                .expect("the sealing pass with its parts")
                .0;
                prove_run_with_forks_ahead(&fr, &blocks, ahead, &mut fix.planes_only(), owners, n)
            }
        }
        .unwrap_or_else(|e| panic!("{path} N{n} window {window}: the fork run proves: {e}"));
        set_ahead_for_test(None, None, None);
        verify_run_with_forks(&fr, &blocks, &rc, 2).unwrap_or_else(|e| panic!("{path} N{n} window {window}: the receipt verifies: {e}"));
        let want = if path == "whole" { 0 } else { window.min(l) };
        // one request's form hands a part not yet started when the forks run back
        // to its fork whole; a stream's (`seal_ahead`) makes every part first
        let handed = if path == "sealing" { stats.ahead_parked + stats.ahead_taken_back } else { stats.ahead_parked };
        assert_eq!(handed, want, "{path} N{n} window {window}: forks parked (and parts taken back whole)");
        assert!(path == "sealing" || stats.ahead_taken_back == 0, "{path}: a part was taken back");
        assert_eq!(stats.generators, l + 1, "{path}: L + 1 generators");
        assert!(stats.fork_hooks.iter().all(|h| h.seeded == Some(A18_SEED)), "{path}: a fork did not hold the seeded switch");
        a18_recompute_interior(&fr, fix, &rc, stats.ahead_parked > 0, hooks);
        (rc.bytes(), stats.ahead_parked)
    };
    for &n in ns {
        let (bytes, _) = prove("whole", n, 0, (1, 0));
        lines.push(format!("{} L{l} N{n} whole: {bytes} B, verified; its interior forks parked equal it", fix.sh.name));
        for &w in windows {
            for &side in sides {
                for path in ["sealing", "seal_ahead"] {
                    let (b, parked) = prove(path, n, w, side);
                    assert_eq!(b, bytes, "{path}: the receipt's size moved");
                    lines.push(format!("{} L{l} N{n} {path} window {w} side {side:?}: {parked} parked, {b} B, verified; its interior forks whole equal it", fix.sh.name));
                }
            }
        }
    }
    lines
}

/// **[A18] A13's parked forks equal whole forks, byte for byte, at the W16R2
/// rung, on the CPU** (in the suite): A13's byte test on the A14-A17 base, every
/// fork beside the preflight's record
#[test]
fn a18_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung() {
    let fix = A18Fix::new(crate::private_block::shape::W16R2_RUNG_H24, 4);
    eprintln!("A18-BYTES {}", a18_check_direct(&fix));
    for line in a18_check_paths(&fix, &[1, 3], &[1, 4, 9], &[(1, 0), (2, 3)]) {
        eprintln!("A18-BYTES {line}");
    }
}

/// **[A18] the same on the Metal device** (`A`'s commitment made by a side
/// worker on the device, finished by a fork worker), and under the A18 forms
/// off and on: toggles `HL_GPU` in-process, so it is ignored and run alone by
/// name
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
#[test]
#[ignore = "A18: toggles HL_GPU and the A18 forms in-process; run alone by name on a Mac"]
fn a18_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung_on_the_device() {
    let fix = A18Fix::new(crate::private_block::shape::W16R2_RUNG_H24, 4);
    std::env::set_var("HL_GPU", "1");
    let before = crate::gpu::metal_sumcheck_stats().1;
    let mut lines = Vec::new();
    for (label, on) in [("a18old", false), ("a18new", true)] {
        crate::private_block::protocol::set_a18_for_test(Some(on), Some(on), Some(on));
        lines.push(format!("[{label}] {}", a18_check_direct(&fix)));
        lines.extend(a18_check_paths(&fix, &[1, 3, 6], &[2, 4], &[(1, 0), (2, 3), (3, 6)]).into_iter().map(|s| format!("[{label}] {s}")));
    }
    crate::private_block::protocol::set_a18_for_test(None, None, None);
    let ran = crate::gpu::metal_sumcheck_stats().1 - before;
    std::env::remove_var("HL_GPU");
    for line in lines {
        eprintln!("A18-BYTES (Metal) {line}");
    }
    assert!(ran > 0.0, "no sumcheck round ran on the device");
}

// ---- end of [A18] ----

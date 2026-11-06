//! **D55 "COMMIT, FORK, JOIN" — one run's blocks proved at the same time.
//! A REGISTERED, OPT-IN run profile since D60 (2026-11-02).**
//!
//! Victor's ruling D55 (`docs/zkmatrix-poc/ZK60_DECISIONS.md`, 2026-11-01)
//! had the construction of `ZK60_D55_CONCURRENT_RUN_DESIGN.md` built as an
//! opt-in, unregistered prototype (test builds only). The independent review
//! (`results/zk60_d55_20261101/REVIEW_D55_20261101.md`) found it sound as
//! built, and its findings F1–F5 were closed. **D60** ("Go ahead and register
//! D55") amends D12a for this ONE opt-in profile: the prover and verifier are
//! production code, and each eligible base run profile has ONE registered D55
//! run profile of its own (`run::D55_RUN_PROFILES`: the twelve R13
//! blocks-only run profiles, each D55 string its own transcript-constructor
//! domain). **Registered D12a runs are unchanged**: no byte of
//! [`super::prove_run_with`] or its verifier moves, CS-7
//! (`registered_block_shape`) names no D55 string, and a D12a run never
//! reaches this file. The only door is [`ForkRun::new`] with an explicit
//! [`D55OptIn`]; a base with no registered D55 profile is refused by name.
//!
//! **What stays TEST-ONLY** (each `#[cfg(test)]`, absent from every production
//! build): the cheating prover the malicious controls play
//! ([`ForkTamper`], `prove_run_with_forks_tampered`), the F2 mutation
//! ([`DropForkIndex`]), the per-worker test switches ([`ForkHooks`]), every
//! run-capture hook, [`RepeatBlock`] (the A/B's synthetic stack) and the
//! TEST-ONLY fork identities over bases with no registered D55 profile (the
//! prototype's `d55-commit-fork-join-runs/opt-in-prototype-unregistered/…`
//! strings, byte for byte the prototype's transcript: the W16 / W16R2 A/B and
//! privacy-gate bases and the rung-G false-statement harness), admitted only
//! through `D55OptIn::unreviewed_prototype()`.
//!
//! **The construction** (the design's three phases, on a D12a run statement):
//!
//! 1. **Commit.** On the run transcript (its own header: the D55 profile
//!    string as the constructor domain, a fork parameter line and a fork
//!    schedule digest), commit every internal boundary `B_0 .. B_{L-2}` from
//!    the boundary planes the source already computed, absorb every root in
//!    boundary order, then the phase label `pb-fork-s0`. That state is `S0`;
//!    every boundary root is fixed before any block challenge exists.
//! 2. **Fork.** Block `k`'s transcript is `fork(S0, k)`: `S0` re-derived (the
//!    transcript type is neither `Clone` nor `Send`, so each worker rebuilds
//!    the same state from the public header and the roots) that absorbs
//!    `pb-run-fork` = `k` and `pb-run-fork-block` = block `k`'s digest before
//!    anything else. `protocol::prove_core` runs on it unchanged, on a pool of
//!    `N` workers sharing the process's one Metal context (as M10 does), each
//!    block with its OWN OS-seeded generator under a per-`k` domain.
//! 3. **Join.** On the run transcript (from `S0`), in block order: block `k`'s
//!    index, its fork's final state and squeeze counter, and every claim its
//!    slots 21 and 22 raised (points, coefficients, slices, values); then
//!    `pb-fork-s1`. That is `S1`. Only then is each `B_k` opened ONCE with
//!    block `k`'s slot-22 claims and block `k + 1`'s slot-21 claims (D12a's
//!    site order), then the external input endpoint with block 0's slot-21
//!    claims, then the external output endpoint with block `L - 1`'s slot-22
//!    claims — every opening challenge drawn after `S1`.
//!
//! The verifier mirrors it, verifying the forks on a pool of threads.
//!
//! **The review's findings, as closed here and kept by the production
//! version:** F3, the transcript is constructed under the D55 profile string
//! itself, and [`ForkRun::census`] holds that constructor against every
//! absorb of the path; F4, `L + 1` OS generators (one per prover thread,
//! which s25's W-8 census scans) and no seeded arm; F5, the calling thread's
//! test switches ([`ForkHooks`]) are installed in every prover and verifier
//! worker in test builds, and a fork-run recorder is seeded into a per-fork
//! recorder on each verifier worker; F2, the [`DropForkIndex`] mutation; F1,
//! the false-statement controls in the tests. **D60 also closes the Info
//! items:** F6, the registered profiles' schedule text gives counts, not
//! ranges, and says that the quoted D12a stage line's IO openings are made in
//! phase 3 (`ForkRun::schedule_lines`); F7, the foreign-frame splice, `L = 1`
//! and the another-base tests (`run_fork_tests.rs`).
//!
//! **What a fork receipt that verifies IS NOT**: a privacy statement. D60
//! requires the Python privacy gate on a D55 capture before any receipt for
//! real content — and since the D60 review (F3) that precondition is in code:
//! [`D55_REAL_CONTENT_PRIVACY_GATE_PASSED`].

use super::super::hash_domain;

/// **D60 REVIEW F3 (2026-11-02): RULING D60'S REAL-CONTENT PRECONDITION, IN
/// CODE.** D60 registers the D55 profiles, and requires the Python privacy
/// gate on a D55 capture before ANY receipt for real content. When D60 was
/// built no gate had read a capture under a REGISTERED D55 profile string (the
/// Rust gate and the Python D55 replay gate read W16 / W16R2 TEST-ONLY
/// identities, whose header bytes differ: the parameter-line clause, the
/// schedule literal and the counted schedule lines), and nothing refused a
/// real-content run (`results/zk60_d60_20261102/REVIEW_D60_20261102.md` F3).
///
/// **While this is `false`**, `zk60_trained_block stack-prove --d55-workers N`
/// REFUSES to run unless the operator passes the explicit test-receipt
/// acknowledgement `--d55-test-receipt-not-for-publication`, and every run
/// directory proved with it carries [`D55_TEST_RECEIPT_MARKER_FILE`], which
/// `stack-verify --d55-workers` reports on every verification (and reports
/// as ABSENT when a D55 directory lacks it). `stack-verify` itself stays usable.
///
/// **It waits for, and only a coordinator commit flips it on:** the Python
/// D55 replay gate (`zk60_native_rg_d55.py`, extended to the R13 layout and
/// the registered header) and the Rust gate's PG-7 allow-list and fork checks
/// PASSING on a bundle written by `run_capture::write_bundle` for a REGISTERED
/// R13 D55 profile (`run_fork_tests::d60_the_capture_writer_…`), with that
/// verdict recorded in the D60 entry of `docs/zkmatrix-poc/ZK60_DECISIONS.md`.
/// Flipping it moves no receipt or statement byte: it only lifts the CLI's
/// refusal.
pub(crate) const D55_REAL_CONTENT_PRIVACY_GATE_PASSED: bool = false;
#[cfg(test)]
use super::super::run_capture as capture;
use super::super::wire::fork::{self as fw, ForkFrame, TailFrame};
use super::*;
use std::path::Path;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{mpsc, Mutex};
use std::time::Instant;

/// **TEST BUILDS ONLY: the prefix of a TEST-ONLY fork identity** (the D55
/// prototype's profile string, byte for byte): `this ‖ the base run profile`,
/// for a base with no registered D55 profile (W16 / W16R2's test-only run
/// identities, the rung-G harness). Never handed to `RunShape::new`, no
/// registry names it, and [`ForkRun::new`] forms it only under
/// `D55OptIn::unreviewed_prototype()`. Its length (69 bytes) keeps every such
/// constructor input at least two bytes from every absorb input of a fork run
/// ([`ForkRun::census`], s25's W-2 / s33's J-7a scans).
#[cfg(test)]
pub(crate) const D55_PROFILE_PREFIX: &str = "d55-commit-fork-join-runs/opt-in-prototype-unregistered/test-only/v1/";
/// the D12a run parameter line's last clause, which a fork run replaces
const D12A_LINE_TAIL: &str = "/one-run-one-transcript";
/// D60: a REGISTERED D55 run's parameter-line clause (36 bytes: the fork
/// runs' `parameters` absorbs then fall between the 295- and 343-byte absorb
/// kinds of every eligible base, equal to neither; s25's W-2 census)
const D55_LINE_TAIL: &str = "/d55-commit-fork-join-registered-d60";
/// D60: a REGISTERED D55 run's schedule-digest domain literal
const D55_SCHEDULE_LITERAL: &[u8] = b"hashline/private-run-fork-schedule/d55-registered-d60/1";
/// a TEST-ONLY fork identity's clause and literal (the prototype's)
#[cfg(test)]
const D55_TEST_LINE_TAIL: &str = "/d55-commit-fork-join-prototype-unregistered";
#[cfg(test)]
const D55_TEST_SCHEDULE_LITERAL: &[u8] = b"hashline/private-run-fork-schedule/d55-prototype/1";

/// the TEST-ONLY D55 identity of a base run profile (the prototype's string)
#[cfg(test)]
pub(crate) fn d55_profile_of(base: &str) -> String {
    format!("{D55_PROFILE_PREFIX}{base}")
}

/// **The D55 profile string a fork run over `base` hashes under** (test
/// builds: the scans' reader): the registered one (D60) where the base has
/// one, else the test-only identity.
#[cfg(test)]
pub(crate) fn fork_profile_for(base: &str) -> String {
    d55_run_profile(base).map(str::to_string).unwrap_or_else(|| d55_profile_of(base))
}

/// **D55 review F3: every transcript label this module absorbs beyond the
/// D12a run header's six and the block's own** (`B`, `rows` and `log-cols` it
/// absorbs through `protocol::absorb_root`, as D12a does), with its data
/// length, or `None` for a claim list (`8 + Σ` of its claims' public words,
/// [`io_claim_list_len`] at a shape). The absorb-label scan
/// (`hash_domain_tests`) requires this table and the labels in this file's
/// source to be the same set; s25's W-2 census measures them.
pub(crate) const D55_LABELS: [(&str, Option<usize>); 9] = [
    ("pb-fork-commit-root", Some(8)),
    ("pb-fork-s0", Some(8)),
    ("pb-run-fork", Some(8)),
    ("pb-run-fork-block", Some(32)),
    ("pb-join-fork", Some(8)),
    ("pb-join-state", Some(40)),
    ("pb-join-in-claims", None),
    ("pb-join-out-claims", None),
    ("pb-fork-s1", Some(8)),
];

/// The length of ONE IO slot's claim list as [`claim_bytes`] encodes it, at
/// a shape: one claim (slot 21's on its input, slot 22's on its output), its
/// value and part count, then the data slice over the whole padded `Dom::D`
/// plane (`clog2(t_pad · d_pad)` coordinates) and the reserved pair's two
/// parts (`min(that, endpoint_log_n)` coordinates each), every part framed
/// by its offset, size, coefficient and point length (`argument.rs`'s
/// `build_claim`). Checked against the claims a real fork run joins
/// (`ForkStats::join_claim_bytes`).
pub(crate) fn io_claim_list_len(sh: &Shape) -> usize {
    let plane = sh.t_pad * sh.d_pad;
    let log = plane.next_power_of_two().trailing_zeros() as usize;
    let logm = log.min(sh.endpoint_log_n);
    let part = |coords: usize| 8 + 8 + 16 + 8 + 16 * coords;
    8 + 16 + 8 + part(log) + 2 * part(logm)
}

/// the commit phase's generator domain (the `L - 1` boundary commitments)
const SEED_USE_FORK_COMMIT: &[u8] = b"hashline-zk-rng/private-block/d55-fork-run-commit-phase/v1/";
/// one generator per fork, domain-separated by the block index
const SEED_USE_FORK_BLOCK: &[u8] = b"hashline-zk-rng/private-block/d55-fork-run-one-stream-per-fork/v1/";

// **D55 REVIEW F2 (2026-11-01), TEST BUILDS ONLY: the MUTATION a same-block
// fork swap must catch.** While a [`DropForkIndex`] guard lives on a thread,
// that thread's fork derivation leaves the index out (`fork(S0, k)` = S0,
// then only the block digest), on the prover's and the verifier's side
// alike. It exists so that
// `d55_control_a_same_block_fork_swap_is_caught_only_by_the_index` can show
// its control FAILS against a derivation without the index, i.e. that the
// swap of two forks carrying the same block is refused by the index and by
// nothing else. Carried into the fork workers with the protocol's own
// switches ([`ForkHooks`]).
#[cfg(test)]
thread_local! {
    static DROP_FORK_INDEX: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
    /// D60 review F8 (b), TEST BUILDS ONLY: while set (a [`PanicInEveryFork`]
    /// guard, carried into the workers by [`ForkHooks`]), every fork's proof
    /// PANICS before it starts
    static PANIC_IN_FORK: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
}

/// **D60 review F8 (b), TEST BUILDS ONLY:** while alive, every fork this
/// thread's prover hands out panics in its worker, so a test can show that a
/// prover whose every worker panics FAILS (returns the panics as errors) and
/// does not hang on its job queue.
#[cfg(test)]
pub(crate) struct PanicInEveryFork {
    was: bool,
}

#[cfg(test)]
impl PanicInEveryFork {
    pub(crate) fn on() -> PanicInEveryFork {
        PanicInEveryFork { was: PANIC_IN_FORK.with(|c| c.replace(true)) }
    }
}

#[cfg(test)]
impl Drop for PanicInEveryFork {
    fn drop(&mut self) {
        PANIC_IN_FORK.with(|c| c.set(self.was));
    }
}

/// While alive, this thread derives every fork WITHOUT its index (the F2
/// mutation; see `DROP_FORK_INDEX`). Test builds only.
#[cfg(test)]
pub(crate) struct DropForkIndex {
    was: bool,
}

#[cfg(test)]
impl DropForkIndex {
    pub(crate) fn on() -> DropForkIndex {
        DropForkIndex { was: DROP_FORK_INDEX.with(|c| c.replace(true)) }
    }
}

#[cfg(test)]
impl Drop for DropForkIndex {
    fn drop(&mut self) {
        DROP_FORK_INDEX.with(|c| c.set(self.was));
    }
}

/// **D55 REVIEW F5 (test builds only): the calling thread's test switches,
/// carried into every fork worker** — the protocol's
/// ([`protocol::ThreadHooks`]: the cheating prover, the injection hooks, the
/// lapse and tag switches) and this module's F2 mutation. Every worker of the
/// prover and of the verifier installs them before its first fork and
/// restores its own on exit, so a test's cheat reaches `prove_core` /
/// `verify_core` on whichever thread a fork lands. Each fork records what it
/// saw ([`ForkStats::fork_hooks`]), so a test can assert the hooks were live
/// in every fork before it trusts a rejection.
#[cfg(test)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub(crate) struct ForkHooks {
    pub block: protocol::ThreadHooks,
    pub drop_fork_index: bool,
    /// D60 review F8 (b): every fork's proof panics ([`PanicInEveryFork`])
    pub panic_in_fork: bool,
    /// [A13] the byte tests' seeded generators ([`SeededForks`])
    pub seeded: Option<u64>,
}

#[cfg(test)]
impl ForkHooks {
    pub(crate) fn capture() -> ForkHooks {
        ForkHooks { block: protocol::ThreadHooks::capture(), drop_fork_index: DROP_FORK_INDEX.with(|c| c.get()), panic_in_fork: PANIC_IN_FORK.with(|c| c.get()), seeded: SEEDED_FORKS.with(|c| c.get()) }
    }
    fn install(self) -> ForkHooksGuard {
        let block = self.block.install();
        let was = DROP_FORK_INDEX.with(|c| c.replace(self.drop_fork_index));
        let was_panic = PANIC_IN_FORK.with(|c| c.replace(self.panic_in_fork));
        let was_seeded = SEEDED_FORKS.with(|c| c.replace(self.seeded));
        ForkHooksGuard { _block: block, was, was_panic, was_seeded }
    }
}

#[cfg(test)]
struct ForkHooksGuard {
    _block: protocol::ThreadHooksGuard,
    was: bool,
    was_panic: bool,
    was_seeded: Option<u64>,
}

#[cfg(test)]
impl Drop for ForkHooksGuard {
    fn drop(&mut self) {
        DROP_FORK_INDEX.with(|c| c.set(self.was));
        PANIC_IN_FORK.with(|c| c.set(self.was_panic));
        SEEDED_FORKS.with(|c| c.set(self.was_seeded));
    }
}

// **[A13] TEST BUILDS ONLY: seeded generators for the byte tests.** A D55 fork
// run's generators are the operating system's, so two runs never share a byte.
// To compare a fork proved whole with the same fork parked after its
// before-challenge part, `run_fork_a13_tests.rs` installs (a [`SeededForks`]
// guard, carried into every worker by [`ForkHooks`]) a seed and a maker: then
// the commit phase's generator and fork `k`'s are REPLACED, right after their
// `from_os` construction, by `make(seed, usize::MAX)` and `make(seed, k)`. The
// maker is the test file's (this file constructs no seeded generator); nothing
// of this exists in a production build.
#[cfg(test)]
thread_local! {
    static SEEDED_FORKS: std::cell::Cell<Option<u64>> = const { std::cell::Cell::new(None) };
}

#[cfg(test)]
static SEEDED_MAKER: std::sync::OnceLock<fn(u64, usize) -> ZkRng> = std::sync::OnceLock::new();

/// [A13] while alive (test builds only), this thread's fork runs use the test
/// file's seeded generators (see `SEEDED_FORKS`)
#[cfg(test)]
pub(crate) struct SeededForks {
    was: Option<u64>,
}

#[cfg(test)]
impl SeededForks {
    pub(crate) fn on(seed: u64, make: fn(u64, usize) -> ZkRng) -> SeededForks {
        let _ = SEEDED_MAKER.set(make);
        SeededForks { was: SEEDED_FORKS.with(|c| c.replace(Some(seed))) }
    }
}

#[cfg(test)]
impl Drop for SeededForks {
    fn drop(&mut self) {
        SEEDED_FORKS.with(|c| c.set(self.was));
    }
}

/// [A13] (test builds only) the seeded generator that replaces generator `k`
/// (`usize::MAX`: the commit phase's), when a [`SeededForks`] guard is live
#[cfg(test)]
fn seeded_generator(k: usize) -> Option<ZkRng> {
    SEEDED_FORKS.with(|c| c.get()).and_then(|seed| SEEDED_MAKER.get().map(|make| make(seed, k)))
}

/// **THE OPT-IN FLAG.** A value of this type is the only way to make a
/// [`ForkRun`]: a D55 fork run is never the default, and a caller that holds
/// none cannot make one. Its production constructor admits the REGISTERED
/// D55 profile of the statement's base only (D60).
pub(crate) struct D55OptIn {
    /// test builds only: whether a base with no registered D55 profile may
    /// fall back to its TEST-ONLY identity
    #[cfg(test)]
    test_only: bool,
}

impl D55OptIn {
    /// **D60: the caller opts in to the registered D55 run profile of its run
    /// statement's base.** A base with none is refused by [`ForkRun::new`].
    pub(crate) fn registered_profile() -> D55OptIn {
        D55OptIn {
            #[cfg(test)]
            test_only: false,
        }
    }
    /// TEST BUILDS ONLY: as [`D55OptIn::registered_profile`] (a registered
    /// base still gets its registered string), and a base with NO registered
    /// D55 profile falls back to its test-only identity (the prototype's
    /// string; W16 / W16R2 / rung-G harnesses)
    #[cfg(test)]
    pub(crate) fn unreviewed_prototype() -> D55OptIn {
        D55OptIn { test_only: true }
    }
}

/// **A base with no registered D55 profile**: refused by name (D60), except
/// that a test build's `D55OptIn::unreviewed_prototype()` gives it its
/// TEST-ONLY identity. Returns the profile and whether it is test-only.
#[cfg(test)]
fn no_registered_profile(base: &str, opt_in: &D55OptIn) -> Result<(String, bool), String> {
    if !opt_in.test_only {
        return Err(format!("D60: the run profile {base} has no registered D55 profile; a D55 fork run is registered over the {} R13 blocks-only run profiles only", D55_RUN_PROFILES.len()));
    }
    if base.starts_with(D55_PROFILE_PREFIX) || base.contains(D55_REGISTERED_MARKER) {
        return Err(format!("D55: {base} is itself a fork-run identity"));
    }
    Ok((d55_profile_of(base), true))
}

#[cfg(not(test))]
fn no_registered_profile(base: &str, _opt_in: &D55OptIn) -> Result<(String, bool), String> {
    Err(format!("D60: the run profile {base} has no registered D55 profile; a D55 fork run is registered over the {} R13 blocks-only run profiles only", D55_RUN_PROFILES.len()))
}

/// A D12a run statement under its D55 profile: the same geometry, blocks,
/// boundaries, endpoint policy and calibration, a different transcript (its
/// own domain, parameter line and schedule) and a different receipt
/// (`run_fork_wire.rs`).
pub(crate) struct ForkRun<'a> {
    st: &'a RunStatement,
    profile: String,
    /// test builds only: whether `profile` is a TEST-ONLY identity (the
    /// prototype's string, line and schedule literal) rather than a
    /// registered D55 run profile
    #[cfg(test)]
    test_only: bool,
}

// **Where the provers' randomness comes from (D55 review F4, 2026-11-01).**
// `L + 1` generators per run, each `ZkRng::from_os` under its own domain and
// each built on the thread that uses it: ONE for the commit phase (the
// `L - 1` boundary commitments, on the calling thread, dropped before any
// fork starts) and ONE per fork (inside the worker that proves it, handed to
// `prove_core` by `&mut`). None is cloned (`ZkRng` is neither `Clone` nor
// `Copy`), shared or derived from another. There is no seeded arm: the dead
// `FixtureSeed(ZkRng::new)` the review found is gone, and s25's W-8 census
// scans this file and counts the two construction sites.

pub(crate) fn commit_seed_domain(profile: &str) -> Vec<u8> {
    let mut d = SEED_USE_FORK_COMMIT.to_vec();
    d.push(hash_domain::ROLE_RUN_PROVER);
    d.extend_from_slice(profile.as_bytes());
    d
}

pub(crate) fn fork_seed_domain(profile: &str, k: usize) -> Vec<u8> {
    let mut d = SEED_USE_FORK_BLOCK.to_vec();
    d.push(hash_domain::ROLE_RUN_PROVER);
    d.extend_from_slice(&(k as u64).to_le_bytes());
    d.extend_from_slice(profile.as_bytes());
    d
}

/// One D55 receipt: the head, `L` fork frames in block order, the tail.
#[derive(Clone)]
pub(crate) struct ForkReceipt {
    pub head: Vec<u8>,
    pub forks: Vec<Vec<u8>>,
    pub tail: Vec<u8>,
}

impl ForkReceipt {
    pub(crate) fn bytes(&self) -> usize {
        self.head.len() + self.forks.iter().map(Vec::len).sum::<usize>() + self.tail.len()
    }
    /// the `L + 2` frames in file order (head, forks, tail)
    fn frames(&self) -> impl Iterator<Item = &Vec<u8>> {
        std::iter::once(&self.head).chain(self.forks.iter()).chain(std::iter::once(&self.tail))
    }
}

/// wall seconds of each phase of one fork-run proof
#[derive(Clone, Debug, Default)]
pub(crate) struct ForkStats {
    pub workers: usize,
    /// the statement checks and the endpoint owners, before the header
    pub preflight_s: f64,
    /// phase 1: the `L - 1` boundary commitments and their absorbs
    pub commit_s: f64,
    /// phase 2: every fork, wall clock
    pub forks_s: f64,
    /// phase 3: the join and every opening
    pub join_s: f64,
    pub total_s: f64,
    /// `prove_core`'s own seconds on each fork, in block order
    pub fork_core_s: Vec<f64>,
    /// D55 review F5 (test builds only): the test switches each fork's worker
    /// held while it proved that fork, in block order (a test compares them
    /// with the calling thread's before it trusts a cheat)
    #[cfg(test)]
    pub fork_hooks: Vec<ForkHooks>,
    /// A11 (test builds only): each fork worker's thread CPU seconds on its
    /// `prove_core`, and its phase clock's rows when the clock is on, in block order
    #[cfg(test)]
    pub fork_thread_cpu_s: Vec<f64>,
    #[cfg(test)]
    pub fork_phases: Vec<Vec<(String, f64)>>,
    /// D55 review F4: how many generators this proof constructed (`L + 1`:
    /// the commit phase's and one per fork)
    pub generators: usize,
    /// D55 review F3: the byte lengths of every fork's two joined claim lists
    /// (`[slot 21, slot 22]`, block order), for the census's formula
    pub join_claim_bytes: Vec<[usize; 2]>,
    /// [A13] how many forks went on from a before-challenge part made during
    /// the sealing pass (0 with `HL_D55_AHEAD` off)
    pub ahead_parked: usize,
    /// [A13] the seconds the fork feeder waited for a before-challenge part
    /// still running when its fork was due
    pub ahead_wait_s: f64,
    /// [A13] how many parts queued in the window were not started when the
    /// forks ran, so their forks took them back whole
    pub ahead_taken_back: usize,
    /// [A13] each fork's before-challenge seconds, in block order, and
    /// whether that part ran during the sealing pass
    pub fork_before_s: Vec<(f64, bool)>,
}

/// **The malicious-receipt controls the D55 ruling names** (TEST BUILDS
/// ONLY), played by a cheating prover. Each makes a complete receipt;
/// `forge_tags` additionally writes, wherever the cheater can compute it, the
/// position tag an honest verifier expects, so that the rejection must come
/// from the Fiat-Shamir chain and not from the (localising, never adopted)
/// tag comparison.
#[cfg(test)]
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) enum ForkTamper {
    /// blocks `a` and `b` are each proved on the OTHER's fork (index and
    /// block digest), and emitted at their own positions
    ForkIndexSwap { a: usize, b: usize },
    /// at the join, block `block`'s fork state is its START state (a stale
    /// state that does not bind its messages), not its final one
    StaleForkState { block: usize },
    /// boundary `boundary`'s root is left out of `S0` and absorbed into the
    /// run transcript only after every fork, at the join
    RootAfterFork { boundary: usize },
    /// block `block`'s slot-22 claims are raised on its fork and opened in
    /// the tail, but not absorbed at the join
    ClaimNotJoined { block: usize },
    /// the same claims neither absorbed at the join NOR put into `B_block`'s
    /// opening (the cheater opens the boundary with its other site only)
    ClaimNotJoinedNorOpened { block: usize },
}

/// **What the prover deviates in.** In a production build this carries
/// nothing and every answer below is the honest prover's (the way D12a's
/// `prove_run_with` reads ruling CS-3's switch as `false` outside tests); in
/// a test build it carries the cheating prover's [`ForkTamper`] and whether
/// it forges the honest position tags.
#[derive(Clone, Copy, Default)]
struct Cheat {
    #[cfg(test)]
    t: Option<(ForkTamper, bool)>,
}

impl Cheat {
    /// whether any deviation is on (the S1 tag's forged variant)
    fn on(&self) -> bool {
        #[cfg(test)]
        return self.t.is_some();
        #[cfg(not(test))]
        false
    }
    /// whether the cheater forges the honest position tags where it can
    fn forge(&self) -> bool {
        #[cfg(test)]
        return self.t.is_some_and(|(_, f)| f);
        #[cfg(not(test))]
        false
    }
    /// the fork index block `k` is proved on
    fn fork_index(&self, k: usize) -> usize {
        #[cfg(test)]
        if let Some((ForkTamper::ForkIndexSwap { a, b }, _)) = self.t {
            return if k == a {
                b
            } else if k == b {
                a
            } else {
                k
            };
        }
        k
    }
    /// the boundary whose root is left out of `S0`
    fn skipped_root(&self) -> Option<usize> {
        #[cfg(test)]
        if let Some((ForkTamper::RootAfterFork { boundary }, _)) = self.t {
            return Some(boundary);
        }
        None
    }
    /// whether block `k`'s join absorbs its START state (test builds only;
    /// a production join absorbs every fork's end state)
    #[cfg(test)]
    fn stale_state(&self, k: usize) -> bool {
        matches!(self.t, Some((ForkTamper::StaleForkState { block }, _)) if block == k)
    }
    /// whether block `k`'s slot-22 claims are left out of the join
    fn claim_not_joined(&self, k: usize) -> bool {
        #[cfg(test)]
        if let Some((ForkTamper::ClaimNotJoined { block } | ForkTamper::ClaimNotJoinedNorOpened { block }, _)) = self.t {
            return block == k;
        }
        let _ = k;
        false
    }
    /// whether block `k`'s slot-22 claims are left out of `B_k`'s opening
    fn claim_not_opened(&self, k: usize) -> bool {
        #[cfg(test)]
        if let Some((ForkTamper::ClaimNotJoinedNorOpened { block }, _)) = self.t {
            return block == k;
        }
        let _ = k;
        false
    }
}

impl<'a> ForkRun<'a> {
    /// **The one door.** The base must be a blocks-only run statement of this
    /// build (no token-I/O, no classifier run) with a REGISTERED D55 run
    /// profile (D60, `run::D55_RUN_PROFILES`), and that profile must be one
    /// CS-7's registry does NOT admit as a D12a run profile. In a test build,
    /// `D55OptIn::unreviewed_prototype()` lets a base with no registered D55
    /// profile take its test-only identity instead.
    pub(crate) fn new(st: &'a RunStatement, opt_in: D55OptIn) -> Result<ForkRun<'a>, String> {
        let base = st.rs.profile;
        if TOKEN_IO_RUN_PROFILES.contains(&base) || is_classify_run_profile(base) {
            return Err(format!("D55: {base} is a token-I/O or classifier run profile; a D55 fork run forks blocks-only runs only"));
        }
        let (profile, test_only) = match d55_run_profile(base) {
            Some(p) => {
                // D60: a registered string is the marker and its base, and
                // nothing else (a registry entry that drifted is refused here)
                let tail = base.strip_prefix("hashline-zk-mr1/").ok_or_else(|| format!("D60: the base run profile {base} is not a hashline-zk-mr1 profile"))?;
                if p != format!("hashline-zk-mr1/{D55_REGISTERED_MARKER}{tail}") {
                    return Err(format!("D60: the registered D55 profile {p:?} is not the D55 marker and its base {base:?}"));
                }
                (p.to_string(), false)
            }
            None => no_registered_profile(base, &opt_in)?,
        };
        #[cfg(not(test))]
        let _ = test_only;
        // CS-7 never admits a D55 string as a D12a run profile: a D12a run
        // under a fork run's constructor domain would share its transcript
        if registered_block_shape(&profile, &st.rs.sh).is_some() {
            return Err(format!("D55: the fork profile {profile:?} is a registered D12a run profile; a fork run's domain must be its own"));
        }
        let fr = ForkRun {
            st,
            profile,
            #[cfg(test)]
            test_only,
        };
        fr.parameter_line()?;
        fr.census()?;
        Ok(fr)
    }

    pub(crate) fn profile(&self) -> &str {
        &self.profile
    }

    /// TEST BUILDS ONLY: the same statement under its TEST-ONLY identity even
    /// where the base has a registered D55 profile (D60's another-profile
    /// control: one statement, two constructor domains)
    #[cfg(test)]
    pub(crate) fn new_test_identity(st: &'a RunStatement) -> Result<ForkRun<'a>, String> {
        let fr = ForkRun { st, profile: d55_profile_of(st.rs.profile), test_only: true };
        fr.parameter_line()?;
        fr.census()?;
        Ok(fr)
    }

    /// whether this fork run hashes under a REGISTERED D55 run profile
    /// (always, in a production build)
    pub(crate) fn is_registered(&self) -> bool {
        #[cfg(test)]
        return !self.test_only;
        #[cfg(not(test))]
        true
    }

    fn line_tail(&self) -> &'static str {
        #[cfg(test)]
        if self.test_only {
            return D55_TEST_LINE_TAIL;
        }
        D55_LINE_TAIL
    }

    fn schedule_literal(&self) -> &'static [u8] {
        #[cfg(test)]
        if self.test_only {
            return D55_TEST_SCHEDULE_LITERAL;
        }
        D55_SCHEDULE_LITERAL
    }

    /// **The W-2 rule at the fork run's OWN constructor** (stage 25's census,
    /// in the small; D55 review F3). The transcript constructor's input is
    /// `hashline-v1/` and the D55 profile string, `12 + |D55 profile|` bytes
    /// — a length no base profile's census ever admitted — so it is held
    /// against EVERY absorb input of a fork run, not only the ones this module
    /// adds: it must be neither the length of, nor one byte from, the squeeze
    /// (47 bytes), any absorb of D55's own labels ([`D55_LABELS`], the claim
    /// lists at this shape's [`io_claim_list_len`] and empty), or any absorb
    /// the block path carries at this shape with the fork run's own parameter
    /// line (`hash_domain::path_labels`, which also lists D12a's
    /// `pb-run-stage` / `pb-run-block`; a fork run absorbs neither, and
    /// holding them too only makes the rule stricter). Each generator's
    /// seed-derivation input (22 + its domain) must be clear of the three
    /// forbidden lengths (64, 40, 47). Returns the table. The whole-path
    /// census with declared pairs is s25's W-2, which measures the fork run
    /// beside the registered profiles.
    pub(crate) fn census(&self) -> Result<String, String> {
        let ctor = 12 + self.profile.len();
        let absorb = |label: &str, data: usize| 32 + 8 + label.len() + 8 + data;
        let line = self.parameter_line()?;
        let sh = &self.st.rs.sh;
        let claims = io_claim_list_len(sh);
        let mut fixed: Vec<(String, usize)> = vec![("a transcript squeeze".to_string(), 47)];
        for (label, data) in D55_LABELS {
            match data {
                Some(d) => fixed.push((format!("`{label}`"), absorb(label, d))),
                None => {
                    fixed.push((format!("`{label}` (no claim)"), absorb(label, 8)));
                    fixed.push((format!("`{label}` (one IO claim)"), absorb(label, claims)));
                }
            }
        }
        for u in hash_domain::path_labels(sh, Some(&line)) {
            for d in &u.data {
                // a run absorbs its OWN parameter line, never the block's
                if u.label == "parameters" && *d != line.len() {
                    continue;
                }
                fixed.push((format!("`{}` with {d} bytes", u.label), absorb(u.label, *d)));
            }
        }
        for (what, len) in &fixed {
            if len.abs_diff(ctor) <= 1 {
                return Err(format!("D55: the {what} absorb is {len} bytes, at most one byte from the {ctor}-byte transcript constructor of {} (W-2)", self.profile));
            }
        }
        let seeds = [("commit-phase generator", 22 + commit_seed_domain(&self.profile).len()), ("per-fork generator", 22 + fork_seed_domain(&self.profile, 0).len())];
        for (what, len) in seeds {
            if [64usize, 40, 47].contains(&len) {
                return Err(format!("D55: the {what}'s seed-derivation input is {len} bytes, a forbidden length"));
            }
        }
        let nearest = fixed.iter().map(|(w, l)| (l.abs_diff(ctor), w.as_str(), *l)).min().expect("a non-empty table");
        let mut d55: Vec<String> = fixed.iter().filter(|(w, _)| D55_LABELS.iter().any(|(l, _)| w.starts_with(&format!("`{l}`")))).map(|(w, l)| format!("{w} {l}")).collect();
        d55.dedup();
        Ok(format!(
            "constructor {ctor} B (`hashline-v1/` + the {} B D55 profile over {}); {} absorb inputs held, the nearest {} B ({}, {} bytes away); D55's own: {}; seeds {} / {}",
            self.profile.len(),
            self.st.rs.profile,
            fixed.len(),
            nearest.2,
            nearest.1,
            nearest.0,
            d55.join(", "),
            seeds[0].1,
            seeds[1].1
        ))
    }

    /// the base D12a line with its one-transcript claim replaced by the D55
    /// run's, so a verifier reads the construction in the clear
    pub(crate) fn parameter_line(&self) -> Result<String, String> {
        let base = self.st.parameter_line()?;
        let stem = base.strip_suffix(D12A_LINE_TAIL).ok_or("D55: the base run's parameter line does not end in its one-transcript claim")?;
        Ok(format!("{stem}{}", self.line_tail()))
    }

    /// The fork schedule: the fork parameter line, the block layout, the three
    /// phases in words, and per block the D12a stage line (which carries the
    /// reserved pair rows of its two IO tabs and any per-layer calibration
    /// clause) under its fork's name.
    fn schedule_digest(&self) -> Result<Digest, String> {
        let (literal, lines) = self.schedule_lines()?;
        let mut h = blake3::Hasher::new();
        h.update(literal);
        for s in &lines {
            h.update(&(s.len() as u64).to_le_bytes());
            h.update(s.as_bytes());
        }
        Ok(*h.finalize().as_bytes())
    }

    /// the schedule digest's domain literal and its lines, in order (the
    /// digest frames each line by its little-endian `u64` length; s25's W-2
    /// census measures the input from these). D60 (review F6): a registered
    /// profile's lines give the forks and boundaries as COUNTS (the
    /// prototype's `0..{L-1}` read inclusively for forks and exclusively for
    /// boundaries), and each fork line says that the quoted D12a stage line's
    /// IO openings are not made in the fork but in phase 3. A test-only
    /// identity keeps the prototype's lines byte for byte.
    pub(crate) fn schedule_lines(&self) -> Result<(&'static [u8], Vec<String>), String> {
        let (st, l) = (self.st, self.st.rs.l);
        let mut lines = vec![self.parameter_line()?];
        lines.extend(Layout::for_shape(&st.rs.sh)?.describe());
        if self.is_registered() {
            let b = l.saturating_sub(1);
            lines.push(format!("phase 1 (commit): the {b} internal boundaries (boundary k after block k), committed in boundary order on the run transcript, each root absorbed (pb-fork-commit-root k, B, rows, log-cols); then pb-fork-s0 = {l}"));
            for k in 0..l {
                lines.push(format!("fork {k:02} of {l}: S0, then pb-run-fork {k} and pb-run-fork-block; the stage body and IO geometry of D12a's [{}]; its IO claims are opened in phase 3, not in the fork", st.stage_line(k)?));
            }
            lines.push(format!(
                "phase 3 (join): the {l} forks in block order (pb-join-fork, pb-join-state, pb-join-in-claims, pb-join-out-claims), then pb-fork-s1 = {l}; then each of the {b} internal boundaries opened once in boundary order (block k's slot 22, then block k+1's slot 21), then the external input endpoint (block 0's slot 21), then the external output endpoint (block {}'s slot 22)",
                l - 1
            ));
        } else {
            lines.push(format!("phase 1 (commit): boundaries 0..{} committed in order on the run transcript, each root absorbed (pb-fork-commit-root, B), then pb-fork-s0 = {l}", l.saturating_sub(1)));
            for k in 0..l {
                lines.push(format!("fork {k:02}: S0 then pb-run-fork {k} and pb-run-fork-block; the stage body and IO geometry of D12a's [{}]", st.stage_line(k)?));
            }
            lines.push(format!(
                "phase 3 (join): forks 0..{} in order (pb-join-fork, pb-join-state, pb-join-in-claims, pb-join-out-claims), then pb-fork-s1 = {l}; open boundaries 0..{} once each (block k slot 22, then block k+1 slot 21), then the external input endpoint, then the external output endpoint",
                l - 1,
                l.saturating_sub(1)
            ));
        }
        Ok((self.schedule_literal(), lines))
    }

    /// The fork run's header: its OWN transcript constructor, `hashline-v1/`
    /// ‖ the D55 profile string under the block shape's Fiat-Shamir key (D55
    /// review F3: a new construction is a new profile and its own transcript,
    /// T-1 / D17; the constructor alone separates every state and challenge
    /// of a fork run from D12a's, from a single block's and from a fork run
    /// on another base), then the D12a header's six absorbs with the fork
    /// run's own parameter line and schedule digest.
    fn transcript(&self) -> Result<Transcript, String> {
        let st = self.st;
        let sh = &st.rs.sh;
        let mut tr = protocol::tagged_transcript(sh, self.profile.as_bytes());
        let mut shape_bytes = Vec::with_capacity(7 * 8);
        for v in [st.rs.l, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim] {
            shape_bytes.extend_from_slice(&(v as u64).to_le_bytes());
        }
        tr.absorb(b"run-shape", &shape_bytes);
        tr.absorb(b"expected-IO", &st.expected.to_bytes());
        tr.absorb(b"public-statement", &st.public_statement());
        tr.absorb(b"parameters", self.parameter_line()?.as_bytes());
        tr.absorb(b"calibration", &st.calibration);
        tr.absorb(b"schedule", &self.schedule_digest()?);
        Ok(tr)
    }

    /// the run binding (the state after the header), which every frame of
    /// this receipt carries (test builds: a test compares it with D12a's)
    #[cfg(test)]
    pub(crate) fn binding(&self) -> Result<Digest, String> {
        Ok(self.transcript()?.state())
    }

    /// **D55 review F5 (test builds only): the fork run's public words for
    /// the run capture** — the base statement's header
    /// (`RunStatement::capture_header`) with the fork run's own constructor
    /// domain (the D55 profile string, F3), its parameter line and its
    /// schedule digest, so that the recorder rebuilds this header exactly as
    /// it rebuilds a block run's and compares the binding. The profile string
    /// is leaked to `'static` (test code; one short string per capture).
    #[cfg(test)]
    pub(crate) fn capture_header(&self) -> Result<super::super::run_capture::RunHeader, String> {
        let mut h = self.st.capture_header()?;
        h.profile = Box::leak(self.profile.clone().into_boxed_str());
        h.parameter_line = self.parameter_line()?;
        h.schedule_digest = self.schedule_digest()?;
        Ok(h)
    }

    /// `S0` from the public header and the roots (`skip`: a cheating prover
    /// that leaves one root out)
    fn s0(&self, roots: &[Digest], skip: Option<usize>) -> Result<Transcript, String> {
        let mut tr = self.transcript()?;
        absorb_commit(&mut tr, self.st, roots, skip)?;
        Ok(tr)
    }

    /// `fork(S0, idx)`
    fn fork(&self, roots: &[Digest], idx: usize, skip: Option<usize>) -> Result<Transcript, String> {
        let mut t = self.s0(roots, skip)?;
        absorb_fork_start(&mut t, self.st, idx)?;
        Ok(t)
    }
}

fn absorb_commit(tr: &mut Transcript, st: &RunStatement, roots: &[Digest], skip: Option<usize>) -> Result<(), String> {
    if roots.len() + 1 != st.rs.l {
        return Err(format!("D55: an {}-block run has {} boundary roots, not {}", st.rs.l, st.rs.l - 1, roots.len()));
    }
    for (k, root) in roots.iter().enumerate() {
        if Some(k) == skip {
            continue;
        }
        absorb_one_root(tr, st, k, root)?;
    }
    tr.absorb_u64(b"pb-fork-s0", st.rs.l as u64);
    Ok(())
}

fn absorb_one_root(tr: &mut Transcript, st: &RunStatement, k: usize, root: &Digest) -> Result<(), String> {
    let spec = st.boundary_spec(k)?;
    tr.absorb_u64(b"pb-fork-commit-root", k as u64);
    protocol::absorb_root(tr, b"B", root, spec.commitment_rows(), spec.log_n());
    Ok(())
}

fn absorb_fork_start(t: &mut Transcript, st: &RunStatement, idx: usize) -> Result<(), String> {
    let d = st.block_digests.get(idx).ok_or_else(|| format!("D55: no block {idx}"))?;
    // (the F2 mutation, a test switch: off unless a `DropForkIndex` guard
    // lives on this thread; a production build always absorbs the index)
    #[cfg(test)]
    let with_index = !DROP_FORK_INDEX.with(|c| c.get());
    #[cfg(not(test))]
    let with_index = true;
    if with_index {
        t.absorb_u64(b"pb-run-fork", idx as u64);
    }
    t.absorb(b"pb-run-fork-block", d);
    Ok(())
}

/// every public word of a claim list: count, then per claim its value, its
/// parts (slice offset and size, coefficient, point)
fn claim_bytes(claims: &[ZClaim]) -> Vec<u8> {
    let mut b = Vec::new();
    b.extend_from_slice(&(claims.len() as u64).to_le_bytes());
    for c in claims {
        b.extend_from_slice(&c.value.to_bytes());
        b.extend_from_slice(&(c.parts.len() as u64).to_le_bytes());
        for p in &c.parts {
            b.extend_from_slice(&(p.slice.offset as u64).to_le_bytes());
            b.extend_from_slice(&u64::from(p.slice.log_size).to_le_bytes());
            b.extend_from_slice(&p.coef.to_bytes());
            b.extend_from_slice(&(p.point.len() as u64).to_le_bytes());
            for x in &p.point {
                b.extend_from_slice(&x.to_bytes());
            }
        }
    }
    b
}

/// one fork's join absorbs: its index, its state and squeeze counter, its
/// incoming (slot 21) and outgoing (slot 22) claims
fn absorb_join(tr: &mut Transcript, k: usize, state: &[u8; 32], counter: u64, ic: &[ZClaim], oc: &[ZClaim]) {
    tr.absorb_u64(b"pb-join-fork", k as u64);
    let mut s = state.to_vec();
    s.extend_from_slice(&counter.to_le_bytes());
    tr.absorb(b"pb-join-state", &s);
    tr.absorb(b"pb-join-in-claims", &claim_bytes(ic));
    tr.absorb(b"pb-join-out-claims", &claim_bytes(oc));
}

fn close_join(tr: &mut Transcript, l: usize) {
    tr.absorb_u64(b"pb-fork-s1", l as u64);
}

/// **Where a fork run's public blocks come from**: shared by reference across
/// the worker threads. A slice holds one block per layer; the tests'
/// `RepeatBlock` holds ONE block for every layer (the measurement's
/// synthetic stack).
pub(crate) trait ForkBlocks: Sync {
    fn count(&self) -> usize;
    fn get(&self, k: usize) -> Result<&BlockPublic, String>;
    /// block `k`'s public digest
    fn digest_of(&self, k: usize) -> Result<Digest, String> {
        Ok(self.get(k)?.digest())
    }
}

impl ForkBlocks for Vec<BlockPublic> {
    fn count(&self) -> usize {
        self.len()
    }
    fn get(&self, k: usize) -> Result<&BlockPublic, String> {
        self.as_slice().get(k).ok_or_else(|| format!("private run: no public statement for block {k}"))
    }
}

/// ONE public block at every one of `l` layers, its digest computed once
/// (test builds only: the A/B's synthetic stack). It is also a D12a
/// [`BlockSource`], so the serial baseline and the fork run read the same
/// blocks the same way.
#[cfg(test)]
pub(crate) struct RepeatBlock<'b> {
    blk: &'b BlockPublic,
    l: usize,
    digest: Digest,
}

#[cfg(test)]
impl<'b> RepeatBlock<'b> {
    pub(crate) fn new(blk: &'b BlockPublic, l: usize) -> RepeatBlock<'b> {
        RepeatBlock { blk, l, digest: blk.digest() }
    }
}

#[cfg(test)]
impl ForkBlocks for RepeatBlock<'_> {
    fn count(&self) -> usize {
        self.l
    }
    fn get(&self, k: usize) -> Result<&BlockPublic, String> {
        if k < self.l {
            Ok(self.blk)
        } else {
            Err(format!("private run: no public statement for block {k}"))
        }
    }
    fn digest_of(&self, k: usize) -> Result<Digest, String> {
        self.get(k).map(|_| self.digest)
    }
}

#[cfg(test)]
impl BlockSource for RepeatBlock<'_> {
    fn block(&mut self, k: usize) -> Result<BlockRef<'_>, String> {
        ForkBlocks::get(self, k).map(BlockRef::Borrowed)
    }
    fn count(&self) -> usize {
        self.l
    }
    fn fit_the_shape(&mut self, sh: &Shape) -> Result<(), String> {
        for k in 0..self.l {
            self.blk.check_for_shape(sh).map_err(|e| format!("private run: block {k}: {e}"))?;
        }
        Ok(())
    }
    fn are_the_statements(&mut self, st: &RunStatement) -> Result<(), String> {
        as_many_blocks_as_the_statement(st, self.l)?;
        for (k, want) in st.block_digests.iter().enumerate() {
            digest_is_the_statements(k, &self.digest, want)?;
        }
        Ok(())
    }
}

/// RULINGS CS-1, CS-4 and CS-6 before anything is absorbed, as
/// [`super::prove_run_with`] and the D12a verifier's start make them.
/// [A17]: on success, each block's record of its passed CS-1 / CS-4 check
/// (`protocol::CheckedPublic`: that block object at that shape), in block order
fn preflight<'b>(st: &RunStatement, blocks: &'b dyn ForkBlocks, check_digests: bool) -> Result<Vec<protocol::CheckedPublic<'b>>, String> {
    use rayon::prelude::*;
    let sh = &st.rs.sh;
    as_many_blocks_as_the_statement(st, blocks.count())?;
    protocol::fits_the_ntt_tables(sh)?;
    // H122 (efficiency plan A2, byte-preserving): the per-block checks scan every block's
    // public weights, about 7 GB at 8B, and ran on one thread, 0.35-0.98 s per request.
    // They now run one block per rayon task. The refusal is the serial loop's: results are
    // read back in block order and the first error is returned.
    let per_block: Vec<Result<protocol::CheckedPublic<'b>, String>> = (0..st.rs.l)
        .into_par_iter()
        .map(|k| {
            let ssh = if sh.accuracy_stack() == super::super::accuracy_precision::Stack::Legacy { sh.clone() } else { st.stage_shape(k)? };
            protocol::CheckedPublic::check(blocks.get(k)?, &ssh).map_err(|e| format!("private run: block {k}: {e}"))
        })
        .collect();
    let mut checked = Vec::with_capacity(per_block.len());
    for r in per_block {
        checked.push(r?);
    }
    policy_fits_the_shape(&st.expected, sh)?;
    if check_digests {
        let digests: Vec<Result<(), String>> = (0..st.rs.l).into_par_iter().map(|k| digest_is_the_statements(k, &blocks.digest_of(k)?, &st.block_digests[k])).collect();
        for r in digests {
            r?;
        }
    }
    st.expected.spec.validate()?;
    Ok(checked)
}

// ---------------------------------------------- [A11] one rayon pool per fork worker
//
// (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A11;
// `results/zk60_effplan_20261105/a11/README.md`.) With the one global pool, a
// pool worker waiting in a join of fork A's parallel region steals and runs
// whatever is queued, often another fork's task, and A's region cannot end until
// that task does. Measured at N = 6 (W16R2 8B T128, macOS `sample`): 69% of the
// pool's running samples were such nested jobs, up to 28 deep (41% at N = 1),
// while the pool was about half asleep and each fork waited about 3.5x longer on
// its parallel regions than alone; the pool's sleeping and waking was most of the
// run's ~23 s of system CPU. Each fork worker gets its own pool; the fork's
// `prove_core` runs on that pool (`install`), so its parallel regions are worked
// by its own threads only.
//
// **Why no byte can move.** Which threads run a parallel region, and how many,
// changes no word: every parallel iterator on the proving path is indexed or an
// exact (field or integer) reduction, so its result does not depend on the pool
// (zkp-core's encode and sumcheck tests check this at several thread counts, and
// `w16r2_tests::a11_*` proves the seeded rung inside pools of 1 to 6 threads to
// the golden digest). The transcript, the randomness and the command buffers are
// each the fork's own, in the same order.
//
// **The default** ([`DEFAULT_FORK_POOL`]): ceil(cores / workers) threads per fork
// worker. In-process A/Bs at N = 6, both arm orders: the proof-only fork run
// -6.9% and -7.1% wall against the global pool (12 of 12 pairs faster), system
// CPU -80%, user CPU -21%; 6 threads was the best size measured (4, 5, 6, 8, 12,
// 24). `HL_D55_FORK_POOL=0` restores the global pool.

/// `HL_D55_FORK_POOL`: unset or `auto`, the default ([`DEFAULT_FORK_POOL`]);
/// `0`, the global pool (the pre-A11 path); `t`, each fork worker's own pool of
/// `t` threads. As a test override: `usize::MAX` none, `AUTO` the default.
static FORK_POOL_TEST: AtomicUsize = AtomicUsize::new(usize::MAX);
const AUTO: usize = usize::MAX - 1;

/// [A11] `HL_D55_FORK_POOL` unset: `true` gives each fork worker its own pool of
/// ceil(cores / workers) threads (6 at N = 6 on the 32-core M3 Ultra), a run on
/// one worker keeping the global pool; `false` keeps the global pool for all
const DEFAULT_FORK_POOL: bool = true;

/// the threads of each fork worker's own pool at `workers` workers (0: the global pool)
fn fork_pool_threads(workers: usize) -> usize {
    static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    let t = match FORK_POOL_TEST.load(Ordering::Relaxed) {
        usize::MAX => *ENV.get_or_init(|| match std::env::var("HL_D55_FORK_POOL").as_deref() {
            Err(_) | Ok("auto") | Ok("") => AUTO,
            Ok(v) => v.parse::<usize>().map(|t| t.min(1024)).unwrap_or(AUTO),
        }),
        t => t,
    };
    if t != AUTO {
        return t;
    }
    if !DEFAULT_FORK_POOL || workers <= 1 {
        return 0;
    }
    std::thread::available_parallelism().map(|n| n.get()).unwrap_or(1).div_ceil(workers)
}

/// tests: each fork worker's own pool of `t` threads (`Some(0)`: the global
/// pool; `None`: as the environment says). Changes no byte (see above).
#[cfg(test)]
pub(crate) fn set_fork_pool_for_test(threads: Option<usize>) {
    FORK_POOL_TEST.store(threads.map(|t| t.min(1024)).unwrap_or(usize::MAX), Ordering::Relaxed);
}

/// tests: the default rule (ceil(cores / workers) threads per fork worker)
#[cfg(test)]
pub(crate) fn set_fork_pool_auto_for_test() {
    FORK_POOL_TEST.store(AUTO, Ordering::Relaxed);
}

/// the fork workers' pools, made once per (worker index, thread count) and kept
/// for the process (an idle rayon thread sleeps)
fn fork_pools(workers: usize) -> Result<Vec<Option<std::sync::Arc<rayon::ThreadPool>>>, String> {
    let t = fork_pool_threads(workers);
    if t == 0 {
        return Ok(vec![None; workers]);
    }
    static POOLS: Mutex<Vec<(usize, usize, std::sync::Arc<rayon::ThreadPool>)>> = Mutex::new(Vec::new());
    let mut g = POOLS.lock().map_err(|_| "D55: the fork pools' lock is poisoned".to_string())?;
    (0..workers)
        .map(|w| {
            if let Some((_, _, p)) = g.iter().find(|(gw, gt, _)| *gw == w && *gt == t) {
                return Ok(Some(p.clone()));
            }
            let p = rayon::ThreadPoolBuilder::new().num_threads(t).thread_name(move |i| format!("hl-fork{w}-pool{i}")).build().map_err(|e| format!("D55: fork {w}'s pool of {t} threads: {e}"))?;
            let p = std::sync::Arc::new(p);
            g.push((w, t, p.clone()));
            Ok(Some(p))
        })
        .collect()
}

/// what one fork's worker hands back
struct ForkOut {
    k: usize,
    bytes: Vec<u8>,
    /// the fork's state and counter after `pb-run-fork-block` (what a stale
    /// join would absorb; the cheating prover's only)
    #[cfg(test)]
    start: ([u8; 32], u64),
    /// the fork's state and counter after `prove_core`
    end: ([u8; 32], u64),
    /// `[slot 21, slot 22]`
    claims: [Vec<ZClaim>; 2],
    core_s: f64,
    /// [A13] the before-challenge part's seconds (inside `core_s`), and
    /// whether that part ran during the sealing pass
    before_s: f64,
    parked: bool,
    /// the test switches this fork's worker held (F5)
    #[cfg(test)]
    hooks: ForkHooks,
    /// A11 (test builds only): the CPU seconds the worker's own thread used on
    /// this fork's `prove_core`, and its phase clock's rows (empty when off)
    #[cfg(test)]
    thread_cpu_s: f64,
    #[cfg(test)]
    phases: Vec<(String, f64)>,
}

/// A11 (test builds only): this thread's CPU seconds so far
/// (`CLOCK_THREAD_CPUTIME_ID`; NaN if the call fails). Spinning on a command
/// buffer counts; time blocked in a rayon join or a blocking wait does not.
#[cfg(test)]
pub(crate) fn thread_cpu_s() -> f64 {
    #[repr(C)]
    struct Timespec {
        sec: i64,
        nsec: i64,
    }
    extern "C" {
        fn clock_gettime(clk: i32, tp: *mut Timespec) -> i32;
    }
    #[cfg(target_os = "macos")]
    const CLOCK_THREAD_CPUTIME_ID: i32 = 16;
    #[cfg(not(target_os = "macos"))]
    const CLOCK_THREAD_CPUTIME_ID: i32 = 3;
    let mut t = Timespec { sec: 0, nsec: 0 };
    // SAFETY: fills the caller's struct, whose layout is the C `timespec` on 64-bit targets
    if unsafe { clock_gettime(CLOCK_THREAD_CPUTIME_ID, &mut t) } != 0 {
        return f64::NAN;
    }
    t.sec as f64 + t.nsec as f64 * 1e-9
}

/// the shared, read-only inputs of the fork workers (no generator: each fork
/// builds its own inside its worker)
struct ForkCtx<'c> {
    fr: &'c ForkRun<'c>,
    blocks: &'c dyn ForkBlocks,
    ntt: &'c NttTables,
    cheat: Cheat,
    /// what only exists after the preflight and the commit phase; `None` while
    /// the forks' before-challenge parts run during the sealing pass ([A13])
    late: Option<ForkLate<'c>>,
}

/// the fork workers' inputs made by the preflight and the commit phase
struct ForkLate<'c> {
    /// [A17] the preflight's record of each block's passed public checks
    checked: &'c [protocol::CheckedPublic<'c>],
    roots: &'c [Digest],
    in_data: Vec<&'c [Fp]>,
    out_data: Vec<&'c [Fp]>,
    binding: Digest,
}

/// a fork's transcript, opened from `S0` (never `Send`: it stays on the
/// thread that opened it)
struct Opened {
    f: Transcript,
    #[cfg(test)]
    start: ([u8; 32], u64),
    start_tag: [u8; 32],
}

/// **[A13] One fork after its before-challenge part.** It holds the fork's
/// ONE generator (built in [`ForkCtx::prove_one`], moved here by value: no
/// clone, no copy of its state, no second user), the state
/// `protocol::prove_core_before` returned, and the stage's shape and layout.
/// A fork that ran its part during the sealing pass is PARKED like this until
/// the commit phase has made `S0`; then any fork worker takes it, by value,
/// and finishes it ([`ForkCtx::finish_one`]). Not public: it holds the
/// witness, the commitments' openings and the generator.
struct Parked {
    k: usize,
    rng: ZkRng,
    ahead: protocol::CoreAhead,
    lay: Layout,
    ssh: Shape,
    ph: timing::Phases,
    before_s: f64,
    /// whether the before-challenge part ran during the sealing pass (then
    /// the after-part restarts the phase clock, so no row holds the wait)
    sealing: bool,
    #[cfg(test)]
    hooks: ForkHooks,
    #[cfg(test)]
    before_cpu_s: f64,
}

/// [A13] what [`ForkCtx::prove_one`] hands back: a finished fork, or (while
/// the commit phase has not run) a parked one
#[cfg_attr(not(test), allow(dead_code))]
enum Done {
    Out(ForkOut),
    Parked(Box<Parked>),
}

impl ForkCtx<'_> {
    fn late(&self) -> Result<&ForkLate<'_>, String> {
        self.late.as_ref().ok_or_else(|| "D55: a fork's transcript was asked for before the commit phase made S0".to_string())
    }

    /// block `k`'s fork transcript `fork(S0, k)` and its start tag
    fn open_fork(&self, late: &ForkLate<'_>, k: usize) -> Result<Opened, String> {
        let (idx, skip, forge) = (self.cheat.fork_index(k), self.cheat.skipped_root(), self.cheat.forge());
        let f = self.fr.fork(late.roots, idx, skip)?;
        #[cfg(test)]
        let start = (f.state(), f.counter());
        let start_tag = if forge && (idx != k || skip.is_some()) { position_tag(&self.fr.fork(late.roots, k, None)?) } else { position_tag(&f) };
        Ok(Opened {
            f,
            #[cfg(test)]
            start,
            start_tag,
        })
    }

    /// **One fork.** Its transcript first (when the commit phase has run), its
    /// ONE generator, the before-challenge part, then the rest on that
    /// transcript and generator. [A13] Run during the sealing pass (`late` is
    /// `None`), it stops after the before-challenge part and returns the fork
    /// PARKED, its generator inside.
    fn prove_one(&self, k: usize, wit: Witness) -> Result<Done, String> {
        // D60 review F8 (b), test builds only: the every-fork-panics switch
        #[cfg(test)]
        if PANIC_IN_FORK.with(|c| c.get()) {
            panic!("D60 F8 test switch: fork {k}'s worker panics");
        }
        let st = self.fr.st;
        let opened = match &self.late {
            Some(late) => Some(self.open_fork(late, k)?),
            None => None,
        };
        // this fork's ONE generator, built here in its worker (F4); [A13] a
        // parked fork carries it, by value, to the worker that finishes it
        let mut rng = ZkRng::from_os(&fork_seed_domain(&self.fr.profile, k)).map_err(|e| format!("D55 fork-run randomness: {e}"))?;
        // [A13] test builds only: the byte tests' seeded generator
        #[cfg(test)]
        if let Some(g) = seeded_generator(k) {
            rng = g;
        }
        #[cfg(test)]
        let hooks = ForkHooks::capture();
        let lay = st.stage_layout(k)?;
        let ssh = st.stage_shape(k)?;
        let blk = self.blocks.get(k)?;
        let mut ph = timing::Phases::start();
        let (mut phases, mut tick) = (Vec::new(), Instant::now());
        #[cfg(test)]
        let cpu0 = thread_cpu_s();
        // [A17] the preflight's record for block `k`, used only if it is for this
        // very block object at this shape. [A18] During the sealing pass there is
        // none yet (the preflight has not run): such a part checks its block itself.
        let hints = protocol::CoreHints { checked: self.late.as_ref().and_then(|late| late.checked.get(k)) };
        let t = Instant::now();
        let ahead = protocol::prove_core_before_with(&ssh, &lay, blk, wit, self.ntt, &mut rng, &mut ph, &mut phases, &mut tick, hints)?;
        let p = Parked {
            k,
            rng,
            ahead,
            lay,
            ssh,
            ph,
            before_s: t.elapsed().as_secs_f64(),
            sealing: opened.is_none(),
            #[cfg(test)]
            hooks,
            #[cfg(test)]
            before_cpu_s: thread_cpu_s() - cpu0,
        };
        match opened {
            Some(o) => self.finish(p, o, blk).map(Done::Out),
            None => Ok(Done::Parked(Box::new(p))),
        }
    }

    /// [A13] a parked fork, after the commit phase: its transcript, then the
    /// rest. [A18] The block is asked for again; `prove_core_after_with` refuses
    /// it unless it is the very object the before-challenge part was made from.
    fn finish_one(&self, p: Parked) -> Result<ForkOut, String> {
        let o = self.open_fork(self.late()?, p.k)?;
        let blk = self.blocks.get(p.k)?;
        self.finish(p, o, blk)
    }

    /// everything from the fork's first transcript use: `prove_core_after`,
    /// then the fork's frame
    fn finish(&self, p: Parked, o: Opened, blk: &BlockPublic) -> Result<ForkOut, String> {
        let late = self.late()?;
        let Parked { k, mut rng, ahead, lay, ssh, ph, before_s, sealing, .. } = p;
        let l = self.fr.st.rs.l;
        let mut f = o.f;
        // a fork parked during the sealing pass gets a fresh clock for its rest
        // (the rows of both are reported), so no row holds the wait
        let (mut ph_before, mut ph) = if sealing { (Some(ph), timing::Phases::start()) } else { (None, ph) };
        let (mut phases, mut tick) = (Vec::new(), Instant::now());
        // [A17] the preflight's record (read by the rest's registry form, [A18])
        let hints = protocol::CoreHints { checked: late.checked.get(k) };
        #[cfg(test)]
        let cpu0 = thread_cpu_s();
        let t = Instant::now();
        let core = protocol::prove_core_after_with(&ssh, &lay, blk, ahead, [late.in_data[k], late.out_data[k]], self.ntt, &mut rng, &mut f, &mut ph, &mut phases, &mut tick, hints)?;
        drop(rng);
        let core_s = before_s + t.elapsed().as_secs_f64();
        #[cfg(test)]
        let thread_cpu_s = p.before_cpu_s + (thread_cpu_s() - cpu0);
        let end = (f.state(), f.counter());
        let end_tag = position_tag(&f);
        let frame = ForkFrame { a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open };
        let bytes = fw::encode_fork(&frame, &lay, &late.binding, l, k, &o.start_tag, &end_tag)?;
        #[cfg(test)]
        let phases = ph_before.take().map(|b| b.rows_for_test()).unwrap_or_default().into_iter().chain(ph.rows_for_test()).collect();
        #[cfg(not(test))]
        let _ = ph_before.take();
        Ok(ForkOut {
            k,
            bytes,
            #[cfg(test)]
            start: o.start,
            end,
            claims: core.io_claims,
            core_s,
            before_s,
            parked: sealing,
            #[cfg(test)]
            hooks: p.hooks,
            #[cfg(test)]
            thread_cpu_s,
            #[cfg(test)]
            phases,
        })
    }
}

/// **THE D55 FORK-RUN PROVER** (D60: a registered, opt-in run profile):
/// phase 1 on the calling thread, phase 2 on `workers` threads (one shared
/// Metal context, as M10; [A11] each worker's forks on its own rayon pool by
/// default), phase 3 on the calling thread. The source is asked
/// for every boundary plane first, then for every witness in block order;
/// at most `workers + 1` witnesses are alive at once.
pub(crate) fn prove_run_with_forks(fr: &ForkRun, blocks: &dyn ForkBlocks, src: &mut dyn RunWitnessSource, externals: Endpoints, workers: usize) -> Result<(ForkReceipt, ForkStats), String> {
    prove_forks_inner(fr, blocks, src, externals, workers, Cheat::default(), None)
}

/// **A CHEATING FORK-RUN PROVER** for the D55 controls (`tamper`, and whether
/// it forges the honest position tags where it can). Test builds only.
#[cfg(test)]
pub(crate) fn prove_run_with_forks_tampered(fr: &ForkRun, blocks: &dyn ForkBlocks, src: &mut dyn RunWitnessSource, externals: Endpoints, workers: usize, tamper: ForkTamper, forge_tags: bool) -> Result<(ForkReceipt, ForkStats), String> {
    prove_forks_inner(fr, blocks, src, externals, workers, Cheat { t: Some((tamper, forge_tags)) }, None)
}

/// [A13] the work one fork worker is handed: a witness (the whole fork), a
/// fork parked after its before-challenge part, or that part's refusal
enum Job {
    Raw(Witness),
    Parked(Box<Parked>),
    Failed(String),
}

fn prove_forks_inner(fr: &ForkRun, blocks: &dyn ForkBlocks, src: &mut dyn RunWitnessSource, externals: Endpoints, workers: usize, cheat: Cheat, ahead: Option<&Slots>) -> Result<(ForkReceipt, ForkStats), String> {
    let t_all = Instant::now();
    let st = fr.st;
    let (sh, l) = (&st.rs.sh, st.rs.l);
    let workers = workers.clamp(1, l);
    let mut stats = ForkStats { workers, ..ForkStats::default() };
    // F5 (test builds): the calling thread's test switches, installed in
    // every worker below
    #[cfg(test)]
    let hooks = ForkHooks::capture();
    // RULINGS CS-1, CS-4, CS-6 (the cheating switch of a test build skips
    // CS-6, as D12a's; the verifier's check never consults it)
    #[cfg(test)]
    let honest_checks = !protocol::cheating_prover_is_on();
    #[cfg(not(test))]
    let honest_checks = true;
    // [A17] each block's record of its passed public checks, for its fork
    let checked = preflight(st, blocks, honest_checks)?;
    let [ein, eout] = protocol::check_endpoints(sh, &st.expected, externals)?;
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.rs.ntt_log());
    let mut tr = fr.transcript()?;
    let binding = tr.state();
    let (skip, forge) = (cheat.skipped_root(), cheat.forge());
    stats.preflight_s = t_all.elapsed().as_secs_f64();

    // ---------------- PHASE 1: commit every boundary, then S0
    let t1 = Instant::now();
    // the commit phase's ONE generator, on this thread (F4)
    let mut rng0 = ZkRng::from_os(&commit_seed_domain(&fr.profile)).map_err(|e| format!("D55 fork-run randomness: {e}"))?;
    // [A13] test builds only: the byte tests' seeded generator
    #[cfg(test)]
    if let Some(g) = seeded_generator(usize::MAX) {
        rng0 = g;
    }
    stats.generators = 1;
    let mut bounds: Vec<(BoundarySpec, PreparedBoundary)> = Vec::with_capacity(l - 1);
    for k in 0..l - 1 {
        let spec = st.boundary_spec(k)?;
        let plane = src.boundary_plane(k)?;
        if plane.len() != spec.len() {
            return Err(format!("private run: boundary {k}'s plane is {} words, the padded plane is {}", plane.len(), spec.len()));
        }
        let p = boundary::prepare(&spec, &words(&plane), &ntt, &mut rng0, &tag)?;
        bounds.push((spec, p));
    }
    drop(rng0);
    let roots: Vec<Digest> = bounds.iter().map(|(_, p)| p.root()).collect();
    absorb_commit(&mut tr, st, &roots, skip)?;
    let s0_tag = if forge && skip.is_some() { position_tag(&fr.s0(&roots, None)?) } else { position_tag(&tr) };
    let head = fw::encode_head(&binding, l, &roots, &s0_tag)?;
    stats.commit_s = t1.elapsed().as_secs_f64();

    // ---------------- PHASE 2: the forks, concurrently
    let t2 = Instant::now();
    let mut ahead_wait = 0.0f64;
    let mut outs: Vec<ForkOut> = {
        let in_data: Vec<&[Fp]> = (0..l).map(|k| if k == 0 { &ein.data[..] } else { bounds[k - 1].1.data() }).collect();
        let out_data: Vec<&[Fp]> = (0..l).map(|k| if k + 1 == l { &eout.data[..] } else { bounds[k].1.data() }).collect();
        let ctx = ForkCtx { fr, blocks, ntt: &ntt, cheat, late: Some(ForkLate { checked: &checked, roots: &roots, in_data, out_data, binding }) };
        let (tx, rx) = mpsc::sync_channel::<(usize, Job)>(0);
        let rx = Mutex::new(rx);
        // [A11] each worker's own rayon pool, or the global one (the default)
        let pools = fork_pools(workers)?;
        let results: Vec<Result<ForkOut, String>> = std::thread::scope(|s| {
            let hs: Vec<_> = (0..workers)
                .map(|w| {
                    let (ctx, rx, pool) = (&ctx, &rx, pools[w].clone());
                    s.spawn(move || {
                        #[cfg(test)]
                        let _hooks = hooks.install();
                        // [A13] a witness is the whole fork; a parked fork goes on
                        // from its before-challenge part; a refused part is the
                        // fork's error, as it would have been here
                        let run = |k: usize, job: Job| -> Result<ForkOut, String> {
                            match job {
                                Job::Raw(wit) => match ctx.prove_one(k, wit)? {
                                    Done::Out(o) => Ok(o),
                                    Done::Parked(_) => Err("D55: a fork parked after the commit phase".into()),
                                },
                                Job::Parked(p) if p.k == k => ctx.finish_one(*p),
                                Job::Parked(_) => Err("D55: a parked fork was handed out as another block's".into()),
                                Job::Failed(e) => Err(e),
                            }
                        };
                        // [A11] the fork's proof on this worker's pool, when it has
                        // one: `install` runs it on a pool thread (which then takes
                        // this worker's test switches too) and every parallel region
                        // inside it on that pool's threads only
                        let prove = |k: usize, job: Job| -> Result<ForkOut, String> {
                            match &pool {
                                Some(p) => p.install(|| {
                                    #[cfg(test)]
                                    let _hooks = hooks.install();
                                    run(k, job)
                                }),
                                None => run(k, job),
                            }
                        };
                        let mut mine = Vec::new();
                        loop {
                            let job = rx.lock().map_err(|_| "D55: the job queue's lock is poisoned".to_string()).and_then(|q| q.recv().map_err(|_| String::new()));
                            match job {
                                // D60 review F8 (b): a panic in one fork's
                                // proof is that fork's ERROR, and this worker
                                // goes on taking jobs, so the feeder never
                                // blocks on a rendezvous no live worker will
                                // take (it hung when every worker had
                                // panicked). A release build has `panic =
                                // "abort"`: there a panic ends the process
                                // (F8 (a)). Both fail closed.
                                Ok((k, job)) => mine.push(match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| prove(k, job))) {
                                    Ok(r) => r.map_err(|e| format!("D55: fork {k}: {e}")),
                                    Err(p) => Err(format!("D55: fork {k}: its worker panicked: {}", p.downcast_ref::<String>().map(String::as_str).or_else(|| p.downcast_ref::<&str>().copied()).unwrap_or("(no message)"))),
                                }),
                                Err(e) if e.is_empty() => break,
                                Err(e) => {
                                    mine.push(Err(e));
                                    break;
                                }
                            }
                        }
                        mine
                    })
                })
                .collect();
            let mut fed: Result<(), String> = Ok(());
            // [A13] the forks run: the side workers start no new part, and a
            // part not yet started is taken back whole
            if let Some(a) = ahead {
                a.set(|g| g.closing = true);
            }
            for k in 0..l {
                // [A13] a before-challenge part made during the sealing pass, if
                // one was (waiting while it still runs), else the source's witness
                let job = match ahead.map(|a| a.take(k)).transpose() {
                    Ok(Some((Some(j), waited))) => {
                        ahead_wait += waited;
                        Ok(j)
                    }
                    Ok(_) => src.witness(k).map(Job::Raw),
                    Err(e) => Err(e),
                };
                match job {
                    Ok(j) => {
                        if tx.send((k, j)).is_err() {
                            fed = Err("D55: every fork worker stopped".into());
                            break;
                        }
                    }
                    Err(e) => {
                        fed = Err(e);
                        break;
                    }
                }
            }
            drop(tx);
            let mut all: Vec<Result<ForkOut, String>> = hs.into_iter().flat_map(|h| h.join().unwrap_or_else(|_| vec![Err("D55: a fork worker panicked".to_string())])).collect();
            if let Err(e) = fed {
                all.push(Err(e));
            }
            all
        });
        let mut outs = Vec::with_capacity(l);
        let mut errs: Vec<String> = Vec::new();
        for r in results {
            match r {
                Ok(o) => outs.push(o),
                Err(e) => errs.push(e),
            }
        }
        if !errs.is_empty() {
            errs.sort();
            return Err(errs.remove(0));
        }
        outs
    };
    outs.sort_by_key(|o| o.k);
    if outs.len() != l || outs.iter().enumerate().any(|(i, o)| o.k != i) {
        return Err("D55: the forks did not return exactly one sub-proof per block".into());
    }
    stats.forks_s = t2.elapsed().as_secs_f64();
    stats.fork_core_s = outs.iter().map(|o| o.core_s).collect();
    stats.ahead_parked = outs.iter().filter(|o| o.parked).count();
    stats.ahead_wait_s = ahead_wait;
    stats.ahead_taken_back = ahead.and_then(|a| a.st.lock().ok().map(|g| g.taken_back)).unwrap_or(0);
    stats.fork_before_s = outs.iter().map(|o| (o.before_s, o.parked)).collect();
    #[cfg(test)]
    {
        stats.fork_hooks = outs.iter().map(|o| o.hooks).collect();
        stats.fork_thread_cpu_s = outs.iter().map(|o| o.thread_cpu_s).collect();
        stats.fork_phases = outs.iter_mut().map(|o| std::mem::take(&mut o.phases)).collect();
    }
    stats.generators += outs.len();
    stats.join_claim_bytes = outs.iter().map(|o| [claim_bytes(&o.claims[0]).len(), claim_bytes(&o.claims[1]).len()]).collect();

    // ---------------- PHASE 3: join, then every opening after S1
    let t3 = Instant::now();
    if let Some(j) = skip {
        // the cheater's late root: absorbed only after every fork
        absorb_one_root(&mut tr, st, j, &roots[j])?;
    }
    for o in &outs {
        #[cfg(test)]
        let (state, counter) = if cheat.stale_state(o.k) { o.start } else { o.end };
        #[cfg(not(test))]
        let (state, counter) = o.end;
        let out_claims: &[ZClaim] = if cheat.claim_not_joined(o.k) { &[] } else { &o.claims[1] };
        absorb_join(&mut tr, o.k, &state, counter, &o.claims[0], out_claims);
    }
    close_join(&mut tr, l);
    let s1_tag = if forge && cheat.on() {
        // the S1 an honest verifier computes from these very forks
        let mut h = fr.s0(&roots, None)?;
        for o in &outs {
            absorb_join(&mut h, o.k, &o.end.0, o.end.1, &o.claims[0], &o.claims[1]);
        }
        close_join(&mut h, l);
        position_tag(&h)
    } else {
        position_tag(&tr)
    };
    let mut boundary_opens = Vec::with_capacity(l - 1);
    for (k, (spec, owner)) in bounds.into_iter().enumerate() {
        let mut claims = if cheat.claim_not_opened(k) { Vec::new() } else { outs[k].claims[1].clone() };
        claims.extend(outs[k + 1].claims[0].iter().cloned());
        boundary_opens.push(owner.into_opening(&spec, &claims, &mut tr).map_err(|e| format!("D55: boundary {k}: {e}"))?);
    }
    let ic = &outs[0].claims[0];
    protocol::check_endpoint_opening(ic, sh, &tr)?;
    let in_open = pcs::open_zk(&ein, ic, &mut tr);
    drop(ein);
    let oc = &outs[l - 1].claims[1];
    protocol::check_endpoint_opening(oc, sh, &tr)?;
    let out_open = pcs::open_zk(&eout, oc, &mut tr);
    drop(eout);
    let end_tag = position_tag(&tr);
    let boundary_rows = if l > 1 { st.boundary_spec(0)?.commitment_rows() } else { 0 };
    let tail = fw::encode_tail(&TailFrame { boundary_opens, in_open, out_open }, sh, &binding, l, boundary_rows, BOUNDARY_SITES, &s1_tag, &end_tag)?;
    stats.join_s = t3.elapsed().as_secs_f64();
    stats.total_s = t_all.elapsed().as_secs_f64();
    let forks = outs.into_iter().map(|o| o.bytes).collect();
    Ok((ForkReceipt { head, forks, tail }, stats))
}

// ---------------------------------------------------------------- [A13] ahead
//
// **[A13] Each fork's before-challenge part during the sealing pass**
// (efficiency plan A13, 2026-11-05). A fork's transcript starts from `S0`, which
// needs every boundary root, so before A13 no fork started until the whole
// sealing pass had run. But `protocol::prove_core` uses no transcript until it
// absorbs `A`'s root: what comes before (`A`'s rows from the witness, the lookups
// and histograms, the CS-3 refusal, `A`'s mask rows, `A`'s commitment and `M`'s)
// needs only the block's own witness, shape, layout and public block, and the
// fork's generator. With a window `W > 0` the first `W` blocks' parts run on
// `HL_D55_AHEAD_WORKERS` side workers (each on its own rayon pool of
// `HL_D55_AHEAD_POOL` threads) as soon as the caller's sealing pass hands their
// witnesses over; each fork is then PARKED ([`Parked`]) until the commit phase
// has made `S0`, and the fork workers go on from it.
//
// **Why no byte can move.** Every fork is the same calls on the same inputs in
// the same order: `prove_core` is `prove_core_before` then `prove_core_after`
// (`A`'s root absorbed after `M`'s commitment, which reads no transcript, so the
// transcript sees the same absorbs), and each fork's ONE generator is built in
// `ForkCtx::prove_one` under its own per-`k` domain, drawn from in the same order
// (A's mask rows, A's pads and salts, M's masks, then everything after) and
// moved, by value, with its parked fork: never cloned, shared or copied, and
// nothing else draws from it. Which thread or pool runs a part changes no word
// (A11). The window and the worker counts decide only WHEN a part runs.
//
// **Memory.** A parked fork holds the witness, the lookup values, `A`'s
// commitment (on Metal its encoding and rows on the device too) and `M`'s, so a
// window of `W` keeps `W` of them alive at the end of the sealing pass
// (measured per window in `results/zk60_effplan_20261105/a13/`). `W` bounds it;
// on a 32 GB card a window must be chosen to fit.

/// `HL_D55_AHEAD`: the window (unset or 0: off, the default)
#[cfg_attr(not(test), allow(dead_code))]
const DEFAULT_AHEAD_WINDOW: usize = 0;
/// `HL_D55_AHEAD_WORKERS` unset: the side workers that make the parts
#[cfg_attr(not(test), allow(dead_code))]
const DEFAULT_AHEAD_WORKERS: usize = 2;
/// `HL_D55_AHEAD_POOL` unset: each side worker's pool of threads
#[cfg_attr(not(test), allow(dead_code))]
const DEFAULT_AHEAD_POOL: usize = 6;

/// tests: `[window, workers, pool threads, quality of service]`, `usize::MAX` = as the environment says
#[cfg_attr(not(test), allow(dead_code))]
static AHEAD_TEST: [AtomicUsize; 4] = [AtomicUsize::new(usize::MAX), AtomicUsize::new(usize::MAX), AtomicUsize::new(usize::MAX), AtomicUsize::new(usize::MAX)];

#[cfg_attr(not(test), allow(dead_code))]
fn ahead_knob(i: usize, var: &str, default: usize, cell: &'static std::sync::OnceLock<usize>) -> usize {
    match AHEAD_TEST[i].load(Ordering::Relaxed) {
        usize::MAX => *cell.get_or_init(|| std::env::var(var).ok().and_then(|v| v.trim().parse::<usize>().ok()).unwrap_or(default)),
        v => v,
    }
}

/// [A13] the window: how many of a fork run's first blocks have their
/// before-challenge part made during the sealing pass, by a caller that runs
/// its sealing pass through [`seal_ahead`] or [`prove_run_with_forks_sealing`]
/// (`HL_D55_AHEAD`; 0, the default, makes none)
#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn ahead_window() -> usize {
    static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    ahead_knob(0, "HL_D55_AHEAD", DEFAULT_AHEAD_WINDOW, &ENV)
}

#[cfg_attr(not(test), allow(dead_code))]
fn ahead_workers() -> usize {
    static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    ahead_knob(1, "HL_D55_AHEAD_WORKERS", DEFAULT_AHEAD_WORKERS, &ENV).clamp(1, 64)
}

#[cfg_attr(not(test), allow(dead_code))]
fn ahead_pool_threads() -> usize {
    static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    ahead_knob(2, "HL_D55_AHEAD_POOL", DEFAULT_AHEAD_POOL, &ENV).min(1024)
}

/// tests: the window, side workers and their pools' threads (`None`: as the
/// environment says). Changes no byte (see above).
#[cfg(test)]
pub(crate) fn set_ahead_for_test(window: Option<usize>, workers: Option<usize>, threads: Option<usize>) {
    for (i, v) in [window, workers, threads].into_iter().enumerate() {
        AHEAD_TEST[i].store(v.unwrap_or(usize::MAX), Ordering::Relaxed);
    }
}

/// `HL_D55_AHEAD_QOS`: the side workers' macOS quality of service, 0 none
/// (the default), 1 utility, 2 background (which keeps them on the efficiency
/// cores, below the sealing pass's threads). Changes no byte.
#[cfg_attr(not(test), allow(dead_code))]
fn ahead_qos() -> usize {
    static ENV: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    ahead_knob(3, "HL_D55_AHEAD_QOS", 0, &ENV).min(2)
}

/// tests: the side workers' quality of service (`None`: as the environment says)
#[cfg(test)]
pub(crate) fn set_ahead_qos_for_test(qos: Option<usize>) {
    AHEAD_TEST[3].store(qos.unwrap_or(usize::MAX), Ordering::Relaxed);
}

/// this thread's macOS quality-of-service class (0: leave it)
#[cfg_attr(not(test), allow(dead_code))]
fn set_thread_qos(qos: usize) {
    #[cfg(target_os = "macos")]
    {
        extern "C" {
            fn pthread_set_qos_class_self_np(qos_class: u32, relative_priority: i32) -> i32;
        }
        let class = match qos {
            1 => 0x11, // QOS_CLASS_UTILITY
            2 => 0x09, // QOS_CLASS_BACKGROUND
            _ => return,
        };
        // SAFETY: sets the calling thread's own scheduling class; no memory is passed
        let _ = unsafe { pthread_set_qos_class_self_np(class, 0) };
    }
    #[cfg(not(target_os = "macos"))]
    let _ = qos;
}

/// the side workers' pools (0 threads: the global pool), made once per
/// (worker index, thread count, quality of service) and kept for the process,
/// apart from the fork workers' (a stream's next request makes its parts while
/// this one's forks run)
#[cfg_attr(not(test), allow(dead_code))]
fn ahead_pools(workers: usize, t: usize, qos: usize) -> Result<Vec<Option<std::sync::Arc<rayon::ThreadPool>>>, String> {
    if t == 0 {
        return Ok(vec![None; workers]);
    }
    static POOLS: Mutex<Vec<(usize, usize, usize, std::sync::Arc<rayon::ThreadPool>)>> = Mutex::new(Vec::new());
    let mut g = POOLS.lock().map_err(|_| "D55: the side workers' pools' lock is poisoned".to_string())?;
    (0..workers)
        .map(|w| {
            if let Some((_, _, _, p)) = g.iter().find(|(gw, gt, gq, _)| *gw == w && *gt == t && *gq == qos) {
                return Ok(Some(p.clone()));
            }
            let p = rayon::ThreadPoolBuilder::new()
                .num_threads(t)
                .thread_name(move |i| format!("hl-ahead{w}-q{qos}-pool{i}"))
                .start_handler(move |_| set_thread_qos(qos))
                .build()
                .map_err(|e| format!("D55: side worker {w}'s pool of {t} threads: {e}"))?;
            let p = std::sync::Arc::new(p);
            g.push((w, t, qos, p.clone()));
            Ok(Some(p))
        })
        .collect()
}

/// one block's entry in [`Slots`]
#[cfg_attr(not(test), allow(dead_code))]
enum Slot {
    /// nothing handed over: the fork feeder asks the source
    Absent,
    /// handed over inside the window, its part not started: a side worker may
    /// start it, or the fork feeder takes it back whole once the forks run
    Queued(Witness),
    /// a side worker is making the block's part
    Pending,
    /// the witness, kept whole (outside the window)
    Raw(Witness),
    Parked(Box<Parked>),
    /// the part's refusal (or its worker's panic): the fork's error
    Failed(String),
    Taken,
}

/// what [`Slots`] guards
#[cfg_attr(not(test), allow(dead_code))]
struct SlotState {
    v: Vec<Slot>,
    /// side workers still running
    alive: usize,
    /// the sealing pass has handed over its last witness
    sealed: bool,
    /// the forks run: start no new part
    closing: bool,
    /// the run failed: start nothing
    stop: bool,
    /// parts taken back whole by the fork feeder
    taken_back: usize,
}

/// **[A13] a fork run's before-challenge parts, by block** (and the queue the
/// side workers take them from, lowest block first): written by the sealing
/// pass's hand-over and the side workers, taken once each by the fork feeder
/// in block order. A part not yet started when the forks run is taken back
/// whole, so a slow side worker never holds a fork up for a part it has not
/// begun.
#[cfg_attr(not(test), allow(dead_code))]
pub(crate) struct Slots {
    st: Mutex<SlotState>,
    cv: std::sync::Condvar,
}

#[cfg_attr(not(test), allow(dead_code))]
impl Slots {
    fn new(l: usize, workers: usize) -> Slots {
        Slots { st: Mutex::new(SlotState { v: (0..l).map(|_| Slot::Absent).collect(), alive: workers, sealed: false, closing: false, stop: false, taken_back: 0 }), cv: std::sync::Condvar::new() }
    }

    fn put(&self, k: usize, s: Slot) {
        if let Ok(mut g) = self.st.lock() {
            if let Some(e) = g.v.get_mut(k) {
                *e = s;
            }
        }
        self.cv.notify_all();
    }

    fn set(&self, f: impl FnOnce(&mut SlotState)) {
        if let Ok(mut g) = self.st.lock() {
            f(&mut g);
        }
        self.cv.notify_all();
    }

    /// a side worker's next part: the lowest queued block, waiting while none
    /// is queued and more may come; `None`: stop
    fn next_part(&self) -> Option<(usize, Witness)> {
        let mut g = self.st.lock().ok()?;
        loop {
            if g.stop || g.closing {
                return None;
            }
            if let Some(k) = g.v.iter().position(|e| matches!(e, Slot::Queued(_))) {
                if let Slot::Queued(w) = std::mem::replace(&mut g.v[k], Slot::Pending) {
                    return Some((k, w));
                }
            }
            if g.sealed {
                return None;
            }
            g = self.cv.wait(g).ok()?;
        }
    }

    /// a side worker has stopped; the last one to stop fails every part still
    /// pending, so the feeder can never wait on a part no worker will make
    fn worker_done(&self) {
        self.set(|g| {
            g.alive = g.alive.saturating_sub(1);
            if g.alive == 0 {
                for e in g.v.iter_mut().filter(|e| matches!(e, Slot::Pending)) {
                    *e = Slot::Failed("D55: the side workers stopped before this fork's before-challenge part was made".into());
                }
            }
        });
    }

    /// block `k`'s job (`None`: nothing was handed over), waiting while its
    /// part runs (a queued part not started is taken back whole); and the
    /// seconds waited
    fn take(&self, k: usize) -> Result<(Option<Job>, f64), String> {
        let t = Instant::now();
        let mut g = self.st.lock().map_err(|_| "D55: the before-challenge slots' lock is poisoned".to_string())?;
        while matches!(g.v.get(k), Some(Slot::Pending)) {
            g = self.cv.wait(g).map_err(|_| "D55: the before-challenge slots' lock is poisoned".to_string())?;
        }
        let s = std::mem::replace(g.v.get_mut(k).ok_or_else(|| format!("D55: no before-challenge slot for block {k}"))?, Slot::Taken);
        let job = match s {
            Slot::Absent => None,
            Slot::Queued(w) => {
                g.taken_back += 1;
                Some(Job::Raw(w))
            }
            Slot::Raw(w) => Some(Job::Raw(w)),
            Slot::Parked(p) => Some(Job::Parked(p)),
            Slot::Failed(e) => Some(Job::Failed(e)),
            Slot::Taken | Slot::Pending => return Err(format!("D55: block {k}'s before-challenge slot was taken twice")),
        };
        Ok((job, t.elapsed().as_secs_f64()))
    }

    /// how many parts are parked, and the host bytes they hold
    fn parked(&self) -> (usize, usize) {
        self.st.lock().map(|g| g.v.iter().filter_map(|e| if let Slot::Parked(p) = e { Some(p.ahead.host_bytes()) } else { None }).fold((0, 0), |(n, b), x| (n + 1, b + x))).unwrap_or((0, 0))
    }
}

/// **[A13] The before-challenge parts a sealing pass made** ([`seal_ahead`]),
/// for [`prove_run_with_forks_ahead`]: they continue only the fork run they
/// were made for (its header's binding) and with the same blocks object.
#[cfg_attr(not(test), allow(dead_code))]
pub(crate) struct ForkAhead {
    binding: Digest,
    blocks_at: usize,
    slots: Slots,
    /// how many parts were made, and the host bytes they hold
    pub parked: usize,
    pub host_bytes: usize,
}

#[cfg(test)]
type WorkerHooks = ForkHooks;
#[cfg(not(test))]
#[cfg_attr(not(test), allow(dead_code))]
type WorkerHooks = ();

#[cfg_attr(not(test), allow(dead_code))]
fn worker_hooks() -> WorkerHooks {
    #[cfg(test)]
    return ForkHooks::capture();
    #[cfg(not(test))]
    ()
}

#[cfg_attr(not(test), allow(dead_code))]
fn blocks_addr(blocks: &dyn ForkBlocks) -> usize {
    blocks as *const dyn ForkBlocks as *const () as usize
}

/// one side worker: takes the lowest queued block, makes its before-challenge
/// part (`prove_one` with no commit phase yet) on its pool and parks it in its
/// slot, until nothing is left to start
#[cfg_attr(not(test), allow(dead_code))]
fn ahead_worker(ctx: &ForkCtx<'_>, slots: &Slots, pool: Option<std::sync::Arc<rayon::ThreadPool>>, qos: usize, hooks: WorkerHooks) {
    #[cfg(test)]
    let _hooks = hooks.install();
    set_thread_qos(qos);
    while let Some((k, wit)) = slots.next_part() {
        let run = || match &pool {
            Some(p) => p.install(|| {
                #[cfg(test)]
                let _hooks = hooks.install();
                ctx.prove_one(k, wit)
            }),
            None => ctx.prove_one(k, wit),
        };
        let slot = match std::panic::catch_unwind(std::panic::AssertUnwindSafe(run)) {
            Ok(Ok(Done::Parked(p))) => Slot::Parked(p),
            Ok(Ok(Done::Out(_))) => Slot::Failed("D55: a fork finished before the commit phase".into()),
            Ok(Err(e)) => Slot::Failed(e),
            Err(p) => Slot::Failed(format!("its worker panicked: {}", p.downcast_ref::<String>().map(String::as_str).or_else(|| p.downcast_ref::<&str>().copied()).unwrap_or("(no message)"))),
        };
        slots.put(k, slot);
    }
    #[cfg(not(test))]
    let _ = hooks;
    slots.worker_done();
}

/// the hand-over the caller's sealing pass calls with each witness in block
/// order: inside the window, queued for the side workers; outside it, kept whole
#[cfg_attr(not(test), allow(dead_code))]
fn hand_over<'q>(l: usize, window: usize, slots: &'q Slots, next: &'q mut usize) -> impl FnMut(usize, Witness) -> Result<(), String> + 'q {
    move |k: usize, w: Witness| {
        if k != *next || k >= l {
            return Err(format!("D55: the sealing pass handed over block {k}, block {} was due (of {l})", *next));
        }
        *next += 1;
        slots.put(k, if k < window { Slot::Queued(w) } else { Slot::Raw(w) });
        Ok(())
    }
}

/// the side workers' setup, shared by [`seal_ahead`] and
/// [`prove_run_with_forks_sealing`]: the window, the workers and their pools
#[cfg_attr(not(test), allow(dead_code))]
fn ahead_setup(l: usize) -> Result<(usize, usize, Vec<Option<std::sync::Arc<rayon::ThreadPool>>>), String> {
    let window = ahead_window().min(l);
    let (aw, qos) = (if window == 0 { 0 } else { ahead_workers() }, ahead_qos());
    Ok((window, qos, ahead_pools(aw, ahead_pool_threads(), qos)?))
}

/// **[A13] THE SEALING PASS WITH EACH FORK'S BEFORE-CHALLENGE PART BESIDE IT**
/// (a stream's: every part in the window is made when it returns). `seal` is
/// the caller's sealing pass: it hands each witness to the hand-over in block
/// order as soon as it is built. Returns what [`prove_run_with_forks_ahead`]
/// continues from, with what `seal` returned. With [`ahead_window`] 0 every
/// witness is kept whole and no part is made.
#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn seal_ahead<T>(fr: &ForkRun, blocks: &dyn ForkBlocks, seal: impl FnOnce(&mut dyn FnMut(usize, Witness) -> Result<(), String>) -> Result<T, String>) -> Result<(ForkAhead, T), String> {
    let l = fr.st.rs.l;
    let (window, qos, pools) = ahead_setup(l)?;
    let ntt = NttTables::new(fr.st.rs.ntt_log());
    let ctx = ForkCtx { fr, blocks, ntt: &ntt, cheat: Cheat::default(), late: None };
    let slots = Slots::new(l, pools.len());
    let hooks = worker_hooks();
    let sealed = std::thread::scope(|s| {
        for pool in pools {
            let (ctx, slots) = (&ctx, &slots);
            s.spawn(move || ahead_worker(ctx, slots, pool, qos, hooks));
        }
        let mut next = 0usize;
        let r = {
            let mut push = hand_over(l, window, &slots, &mut next);
            seal(&mut push)
        };
        let failed = r.is_err();
        slots.set(|g| {
            g.sealed = true;
            g.stop = failed;
        });
        r
    })?;
    let (parked, host_bytes) = slots.parked();
    Ok((ForkAhead { binding: fr.transcript()?.state(), blocks_at: blocks_addr(blocks), slots, parked, host_bytes }, sealed))
}

/// **[A13] the D55 fork-run prover, continuing from [`seal_ahead`]'s parts**
/// (the fork run they were made for, the same blocks). A block with no part
/// takes its witness from `ahead` (kept whole) or, if none was handed over,
/// from `src`; boundary planes come from `src`.
#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn prove_run_with_forks_ahead(fr: &ForkRun, blocks: &dyn ForkBlocks, ahead: ForkAhead, src: &mut dyn RunWitnessSource, externals: Endpoints, workers: usize) -> Result<(ForkReceipt, ForkStats), String> {
    if ahead.binding != fr.transcript()?.state() || ahead.blocks_at != blocks_addr(blocks) {
        return Err("D55: the before-challenge parts were made for another fork run or another blocks object".into());
    }
    prove_forks_inner(fr, blocks, src, externals, workers, Cheat::default(), Some(&ahead.slots))
}

/// **[A13] ONE REQUEST: the sealing pass, each fork's before-challenge part
/// beside it, then the fork run**, in one scope, so the parts still being made
/// when the sealing pass ends overlap the statement checks and the commit
/// phase (the fork feeder waits for a part only when its fork is due, and
/// takes back whole any part not yet started when the forks run). `seal`
/// hands each witness over in block order and returns the source of the
/// boundary planes (and of any witness it did not hand over). With
/// [`ahead_window`] 0 this is the sealing pass, then [`prove_run_with_forks`].
#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn prove_run_with_forks_sealing<S: RunWitnessSource>(fr: &ForkRun, blocks: &dyn ForkBlocks, externals: Endpoints, workers: usize, seal: impl FnOnce(&mut dyn FnMut(usize, Witness) -> Result<(), String>) -> Result<S, String>) -> Result<(ForkReceipt, ForkStats), String> {
    let l = fr.st.rs.l;
    let (window, qos, pools) = ahead_setup(l)?;
    let ntt = NttTables::new(fr.st.rs.ntt_log());
    let ctx = ForkCtx { fr, blocks, ntt: &ntt, cheat: Cheat::default(), late: None };
    let slots = Slots::new(l, pools.len());
    let hooks = worker_hooks();
    std::thread::scope(|s| {
        for pool in pools {
            let (ctx, slots) = (&ctx, &slots);
            s.spawn(move || ahead_worker(ctx, slots, pool, qos, hooks));
        }
        let mut next = 0usize;
        let sealed = {
            let mut push = hand_over(l, window, &slots, &mut next);
            seal(&mut push)
        };
        let failed = sealed.is_err();
        slots.set(|g| {
            g.sealed = true;
            g.stop = failed;
        });
        let r = sealed.and_then(|mut src| prove_forks_inner(fr, blocks, &mut src, externals, workers, Cheat::default(), Some(&slots)));
        slots.set(|g| g.stop = true);
        r
    })
}

/// the refusal of a head whose S0 tag is not the verifier's own (the verifier
/// and, before any fork frame is read, `read_fork_receipt`)
const S0_TAG_REFUSAL: &str = "D55: the head's S0 tag is not the verifier's own S0 (every boundary root absorbed, in order, before any fork)";

/// what the verifier keeps of one verified fork
struct Seen {
    end: ([u8; 32], u64),
    claims: [Vec<ZClaim>; 2],
}

fn verify_one_fork(fr: &ForkRun, blocks: &dyn ForkBlocks, roots: &[Digest], ntt: &NttTables, binding: &Digest, k: usize, bytes: &[u8]) -> Result<Seen, String> {
    let st = fr.st;
    let sh = &st.rs.sh;
    let lay = st.stage_layout(k)?;
    let mut f = fr.fork(roots, k, None)?;
    let start_tag = position_tag(&f);
    let (frame, end_tag) = fw::decode_fork(bytes, &lay, binding, st.rs.l, k, &start_tag)?;
    // T-4 before a byte of the fork is hashed
    let bp = protocol::pcs_params_at(sh);
    hash_domain::paths_are_the_tree_depth("A", &bp, &frame.a_open)?;
    hash_domain::paths_are_the_tree_depth("H", &bp, &frame.h_open)?;
    hash_domain::mask_paths_are_the_tree_depth(&frame.mask_open)?;
    // F5: the fork's stage opens in this worker's per-fork recorder (test
    // builds; a no-op unless one is attached on this thread)
    #[cfg(test)]
    capture::fork_stage_begin(k, bytes, start_tag, frame.a_root, frame.h_root, frame.mask_root, &lay, &f);
    let view = CoreView { a_root: frame.a_root, h_root: frame.h_root, mask_root: frame.mask_root, slots: &frame.slots, mask_open: &frame.mask_open, a_open: &frame.a_open, h_open: &frame.h_open };
    let blk = blocks.get(k)?;
    let ssh = st.stage_shape(k)?;
    let mut ph = timing::Phases::start();
    let ([ic, oc], _) = protocol::verify_core(&ssh, &lay, blk, view, ntt, &mut f, &mut ph)?;
    if position_tag(&f) != end_tag {
        return Err(format!("fork {k}'s end tag is not the verifier's own fork-{k} position"));
    }
    #[cfg(test)]
    capture::stage_end(k, end_tag, &f);
    Ok(Seen { end: (f.state(), f.counter()), claims: [ic, oc] })
}

/// what one fork verifier worker hands back: the block, its verdict and (test
/// builds, with a fork-run recorder attached) its per-fork record
#[cfg(test)]
type ForkCap = Option<Result<capture::ForkStageCapture, String>>;
#[cfg(not(test))]
type ForkCap = ();

/// **THE D55 FORK-RUN VERIFIER**: the header and every root (`S0`), the `L`
/// forks on `workers` threads, the join (`S1`), then every opening. The
/// forks' order of completion does not matter: the join is in block order.
pub(crate) fn verify_run_with_forks(fr: &ForkRun, blocks: &dyn ForkBlocks, rc: &ForkReceipt, workers: usize) -> Result<(), String> {
    let st = fr.st;
    let (sh, l) = (&st.rs.sh, st.rs.l);
    preflight(st, blocks, true)?;
    if rc.forks.len() != l {
        return Err(format!("D55: {} fork frames were offered, this run has {l}", rc.forks.len()));
    }
    let ntt = NttTables::new(st.rs.ntt_log());
    let e_params = protocol::endpoint_pcs_params(sh);
    let e_zko = ZkOpts::standard(&e_params);
    let tag = sh.hash_tag();
    let mut tr = fr.transcript()?;
    let binding = tr.state();
    // ---- phase 1: every root, from the head, before any fork
    let (roots, s0_claimed) = fw::decode_head(&rc.head, &binding, l)?;
    absorb_commit(&mut tr, st, &roots, None)?;
    if position_tag(&tr) != s0_claimed {
        return Err(S0_TAG_REFUSAL.into());
    }
    // F5 (test builds): a fork-run recorder on this thread replays the
    // commit phase; its seed, if any, starts one per-fork recorder on
    // whichever worker verifies each fork (every capture hook is a no-op
    // without a recorder)
    #[cfg(test)]
    capture::fork_commit(&roots, &tr);
    #[cfg(test)]
    let seed = capture::fork_seed();
    // ---- phase 2: the forks
    let next = AtomicUsize::new(0);
    let workers = workers.clamp(1, l);
    // F5 (test builds): the calling thread's test switches, in every worker
    #[cfg(test)]
    let hooks = ForkHooks::capture();
    type Verified = (usize, Result<Seen, String>, ForkCap);
    let mut results: Vec<Verified> = std::thread::scope(|s| {
        let hs: Vec<_> = (0..workers)
            .map(|_| {
                let (next, roots, ntt, binding) = (&next, &roots, &ntt, &binding);
                #[cfg(test)]
                let seed = seed.as_ref();
                s.spawn(move || {
                    #[cfg(test)]
                    let _hooks = hooks.install();
                    let mut mine: Vec<Verified> = Vec::new();
                    loop {
                        let k = next.fetch_add(1, Ordering::SeqCst);
                        if k >= l {
                            break;
                        }
                        #[cfg(test)]
                        if let Some(sd) = seed {
                            capture::fork_stage_attach(sd, k);
                        }
                        let v = verify_one_fork(fr, blocks, roots, ntt, binding, k, &rc.forks[k]);
                        // always detaches this worker's per-fork recorder
                        #[cfg(test)]
                        let cap = seed.map(|_| capture::fork_stage_take(k));
                        #[cfg(not(test))]
                        let cap = ();
                        mine.push((k, v, cap));
                    }
                    mine
                })
            })
            .collect();
        hs.into_iter().flat_map(|h| h.join().unwrap_or_else(|_| vec![(usize::MAX, Err("a fork verifier panicked".to_string()), ForkCap::default())])).collect()
    });
    results.sort_by_key(|(k, _, _)| *k);
    let mut seen: Vec<Seen> = Vec::with_capacity(l);
    for (k, r, cap) in results {
        match r {
            Ok(s) if k == seen.len() => seen.push(s),
            Ok(_) => return Err("D55: the fork verifiers did not return one result per block".into()),
            Err(e) => return Err(format!("D55: fork {k}: {e}")),
        }
        // F5 (test builds): fork k's record, merged into the run's recorder
        // in block order
        #[cfg(test)]
        if let Some(cap) = cap {
            capture::fork_stage_merge(cap);
        }
        #[cfg(not(test))]
        let () = cap;
    }
    if seen.len() != l {
        return Err("D55: a fork was not verified".into());
    }
    // ---- phase 3: the join, then every opening after S1
    for (k, s) in seen.iter().enumerate() {
        absorb_join(&mut tr, k, &s.end.0, s.end.1, &s.claims[0], &s.claims[1]);
    }
    close_join(&mut tr, l);
    #[cfg(test)]
    if capture::active() {
        capture::fork_join(&seen.iter().map(|s| s.claims.clone()).collect::<Vec<_>>(), &tr);
    }
    let boundary_rows = if l > 1 { st.boundary_spec(0)?.commitment_rows() } else { 0 };
    let (tail, end_tag) = fw::decode_tail(&rc.tail, sh, &binding, l, boundary_rows, BOUNDARY_SITES, &position_tag(&tr))?;
    let ep = protocol::endpoint_pcs_params(sh);
    for (k, o) in tail.boundary_opens.iter().enumerate() {
        hash_domain::paths_are_the_tree_depth(&format!("boundary {k}"), &ep, o)?;
    }
    hash_domain::paths_are_the_tree_depth("run input endpoint", &ep, &tail.in_open)?;
    hash_domain::paths_are_the_tree_depth("run output endpoint", &ep, &tail.out_open)?;
    // F5 (test builds): the tail's openings, each recorded by a fork-run
    // recorder (the geometry is this verifier's own, from its statement)
    #[cfg(test)]
    let data_rows = st.rs.data_rows();
    #[cfg(test)]
    let endpoint_geom = |role: &'static str, root: Digest, sources: Vec<(usize, usize, usize)>| capture::Geom {
        role,
        commitment_kind: "external-endpoint",
        params: e_params,
        root,
        rows: sh.endpoint_rows,
        data_rows,
        site_rows: vec![data_rows, data_rows + 1],
        sum_rows: None,
        prox_row: data_rows + 2,
        boundary: None,
        claim_sources: sources,
    };
    for k in 0..l - 1 {
        let spec = st.boundary_spec(k)?;
        // the verifier's OWN claims, from both forks' slot terminals
        let mut claims = seen[k].claims[1].clone();
        claims.extend(seen[k + 1].claims[0].iter().cloned());
        boundary::check_opening(&spec, &claims, &tr).map_err(|e| format!("D55: boundary {k}: {e}"))?;
        let params = spec.params();
        let cm = protocol::commitment(roots[k], spec.commitment_rows(), spec.log_n());
        #[cfg(test)]
        let before = capture::checkpoint(&tr);
        pcs::verify_zk_tagged(&params, &ZkOpts::standard(&params), &cm, &claims, &tail.boundary_opens[k], &ntt, &mut tr, &tag).map_err(|e| format!("D55: boundary {k}: {e}"))?;
        #[cfg(test)]
        {
            let g = capture::Geom {
                role: "Input",
                commitment_kind: "internal-boundary",
                params,
                root: roots[k],
                rows: spec.commitment_rows(),
                data_rows: spec.data_rows(),
                site_rows: spec.site_rows(),
                sum_rows: None,
                prox_row: spec.prox_row(),
                boundary: Some(k),
                claim_sources: vec![(k, super::super::layout::SC_IO_OUT, seen[k].claims[1].len()), (k + 1, super::super::layout::SC_IO_IN, seen[k + 1].claims[0].len())],
            };
            capture::pcs(g, &claims, &tail.boundary_opens[k], &ntt, before, &tr);
        }
    }
    let ic = &seen[0].claims[0];
    protocol::check_endpoint_opening(ic, sh, &tr)?;
    let cm = protocol::commitment(st.expected.input, sh.endpoint_rows, sh.endpoint_log_n);
    #[cfg(test)]
    let before = capture::checkpoint(&tr);
    pcs::verify_zk_tagged(&e_params, &e_zko, &cm, ic, &tail.in_open, &ntt, &mut tr, &tag).map_err(|e| format!("D55: run input endpoint: {e}"))?;
    #[cfg(test)]
    capture::pcs(endpoint_geom("Input", st.expected.input, vec![(0, super::super::layout::SC_IO_IN, ic.len())]), ic, &tail.in_open, &ntt, before, &tr);
    let oc = &seen[l - 1].claims[1];
    protocol::check_endpoint_opening(oc, sh, &tr)?;
    let cm = protocol::commitment(st.expected.output, sh.endpoint_rows, sh.endpoint_log_n);
    #[cfg(test)]
    let before = capture::checkpoint(&tr);
    pcs::verify_zk_tagged(&e_params, &e_zko, &cm, oc, &tail.out_open, &ntt, &mut tr, &tag).map_err(|e| format!("D55: run output endpoint: {e}"))?;
    #[cfg(test)]
    capture::pcs(endpoint_geom("Output", st.expected.output, vec![(l - 1, super::super::layout::SC_IO_OUT, oc.len())]), oc, &tail.out_open, &ntt, before, &tr);
    if position_tag(&tr) != end_tag {
        return Err("D55: the tail's end tag is not the verifier's own transcript position".into());
    }
    #[cfg(test)]
    capture::fork_tail_end(end_tag, &tr);
    #[cfg(test)]
    capture::run_accepted();
    Ok(())
}

// ---------------------------------------------------------------- D60: a fork receipt on disk

/// **D60: the file names of a D55 receipt in a run directory** — the head,
/// one file per fork, the tail. None is a D12a segment's name
/// (`segment-NNN.bin`), so neither verifier reads the other's directory.
pub(crate) const D55_HEAD_FILE: &str = "d55-head.bin";
pub(crate) const D55_TAIL_FILE: &str = "d55-tail.bin";

/// `d55-fork-000.bin`, `d55-fork-001.bin`, …
pub(crate) fn d55_fork_file_name(k: usize) -> String {
    format!("d55-fork-{k:03}.bin")
}

/// the `L + 2` file names of an `l`-block fork run's receipt, in order
pub(crate) fn d55_file_names(l: usize) -> Vec<String> {
    std::iter::once(D55_HEAD_FILE.to_string()).chain((0..l).map(d55_fork_file_name)).chain(std::iter::once(D55_TAIL_FILE.to_string())).collect()
}

/// **D60 review F3: the not-for-publication marker of a D55 TEST receipt.**
/// While [`D55_REAL_CONTENT_PRIVACY_GATE_PASSED`] is `false`, `stack-prove
/// --d55-workers` runs only with `--d55-test-receipt-not-for-publication`, and
/// then writes this file into the run directory, beside the receipt's frames
/// and after them; `stack-verify --d55-workers` reports it on every
/// verification. It is a FILE IN THE RUN DIRECTORY and nothing else: not a
/// frame, not hashed into `segments.json`, not in `statement.json`, absorbed
/// nowhere — so it changes no verified receipt or statement byte, and a
/// marked receipt's frames are byte for byte what an unmarked one's would be.
/// [`read_fork_receipt`] admits it beside the `L + 2` frames only as a
/// regular file holding exactly [`D55_TEST_RECEIPT_MARKER_TEXT`].
pub(crate) const D55_TEST_RECEIPT_MARKER_FILE: &str = "D55_TEST_RECEIPT_NOT_FOR_PUBLICATION.txt";

/// the marker's one admitted content
pub(crate) const D55_TEST_RECEIPT_MARKER_TEXT: &[u8] = b"D55 TEST RECEIPT, NOT FOR PUBLICATION.\n\
This run directory was proved by `zk60_trained_block stack-prove --d55-workers N --d55-test-receipt-not-for-publication` \
in a build whose ruling-D60 real-content precondition was unmet (run_fork::D55_REAL_CONTENT_PRIVACY_GATE_PASSED = false: \
no privacy gate had yet passed on a capture under a registered D55 run profile; D60 review F3). It is a TEST receipt; \
prove public data only, and do not publish it or its statement. `stack-verify --d55-workers` reports this marker on every \
verification. The marker is not one of the receipt's frames: no verified receipt or statement byte carries it.\n";

/// **Whether `dir` holds the test-receipt marker** (D60 review F3): `false`
/// when no entry has its name; `true` when it is a regular file (never a
/// link, FIFO or directory, refused before it is opened) holding exactly
/// [`D55_TEST_RECEIPT_MARKER_TEXT`]; anything else under that name is
/// REFUSED by name.
pub(crate) fn d55_test_receipt_marker(dir: &Path) -> Result<bool, String> {
    let p = dir.join(D55_TEST_RECEIPT_MARKER_FILE);
    match std::fs::symlink_metadata(&p) {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(false),
        Err(e) => return Err(format!("D55: the test-receipt marker {}: {e}", p.display())),
        Ok(_) => {}
    }
    let found = super::read_regular_file_bounded(&p, D55_TEST_RECEIPT_MARKER_TEXT.len() as u64, true).map_err(|e| format!("D55: the test-receipt marker is not the marker this build writes: {e}"))?;
    if found != D55_TEST_RECEIPT_MARKER_TEXT {
        return Err(format!("D55: {} is not the test-receipt marker this build writes (other content of its length)", p.display()));
    }
    Ok(true)
}

/// **Write the test-receipt marker into a run directory** (D60 review F3),
/// atomically (a temporary name, flushed, renamed into place), never over an
/// existing entry.
pub(crate) fn write_d55_test_receipt_marker(dir: &Path) -> Result<std::path::PathBuf, String> {
    use std::io::Write;
    let p = dir.join(D55_TEST_RECEIPT_MARKER_FILE);
    if std::fs::symlink_metadata(&p).is_ok() {
        return Err(format!("D55: {} exists; the marker is never replaced", p.display()));
    }
    let tmp = dir.join(format!("{D55_TEST_RECEIPT_MARKER_FILE}.partial"));
    {
        let mut f = std::fs::OpenOptions::new().write(true).create_new(true).open(&tmp).map_err(|e| format!("D55: {} cannot be created: {e}", tmp.display()))?;
        f.write_all(D55_TEST_RECEIPT_MARKER_TEXT).map_err(|e| format!("D55: {} cannot be written: {e}", tmp.display()))?;
        f.sync_all().map_err(|e| format!("D55: {} cannot be flushed: {e}", tmp.display()))?;
    }
    std::fs::rename(&tmp, &p).map_err(|e| format!("D55: {} cannot be renamed to {}: {e}", tmp.display(), p.display()))?;
    Ok(p)
}

/// **Write a fork receipt into an EXISTING, EMPTY run directory**, each frame
/// ATOMICALLY (a temporary name, flushed to the device, renamed into place,
/// as `run_sink::DirSink` writes a segment), and return each frame's length
/// and SHA-256 in file order.
pub(crate) fn write_fork_receipt(dir: &Path, rc: &ForkReceipt) -> Result<Vec<(u64, String)>, String> {
    use std::io::Write;
    if !dir.is_dir() {
        return Err(format!("D55: the run directory {} does not exist; create it before the run", dir.display()));
    }
    let names = super::run_sink::dir_entry_names(dir)?;
    if !names.is_empty() {
        return Err(format!("D55: the run directory {} is not empty (it holds {} entries, the first being {})", dir.display(), names.len(), names[0]));
    }
    let mut out = Vec::with_capacity(rc.forks.len() + 2);
    for (name, bytes) in d55_file_names(rc.forks.len()).iter().zip(rc.frames()) {
        let final_path = dir.join(name);
        let tmp_path = dir.join(format!("{name}.partial"));
        {
            let mut f = std::fs::File::create(&tmp_path).map_err(|e| format!("D55: {} cannot be created: {e}", tmp_path.display()))?;
            f.write_all(bytes).map_err(|e| format!("D55: {} cannot be written: {e}", tmp_path.display()))?;
            f.sync_all().map_err(|e| format!("D55: {} cannot be flushed: {e}", tmp_path.display()))?;
        }
        std::fs::rename(&tmp_path, &final_path).map_err(|e| format!("D55: {} cannot be renamed to {}: {e}", tmp_path.display(), final_path.display()))?;
        out.push((bytes.len() as u64, super::run_sink::digest_hex(bytes)));
    }
    Ok(out)
}

/// One frame read through a BOUNDED reader (review r3_6's rule for a D12a
/// segment): a regular file (a link, FIFO, device or directory refused before
/// it is opened) whose length, from its metadata, is `want` — the verifier's
/// own counted length, never the file's — re-checked on the open handle and
/// read with at most `want + 1` bytes taken.
fn read_frame_bounded(what: &str, p: &Path, want: usize, ceiling: usize) -> Result<Vec<u8>, String> {
    use std::io::Read;
    if want > ceiling {
        return Err(format!("D55 wire: {what}'s counted length {want} B exceeds the wire ceiling {ceiling} B"));
    }
    let meta = std::fs::symlink_metadata(p).map_err(|e| format!("D55: {what} ({}) cannot be read: {e}", p.display()))?;
    if !meta.file_type().is_file() {
        return Err(format!("D55: {what} ({}) is not a regular file (a symbolic link, FIFO, device or directory is refused before it is opened)", p.display()));
    }
    if meta.len() != want as u64 {
        return Err(format!("D55 wire: {what} is {} B, the counted length is {want}; refused before it is read", meta.len()));
    }
    // D60 review F4: `O_NOFOLLOW | O_NONBLOCK` on every target that defines
    // them (macOS and aarch64 Linux too), so a link or FIFO swapped in after
    // the `lstat` is refused, never followed or blocked on
    let f = super::open_nofollow_nonblock(p).map_err(|e| format!("D55: {what} ({}) cannot be opened as a regular file: {e}", p.display()))?;
    let fm = f.metadata().map_err(|e| format!("D55: {what} ({}): {e}", p.display()))?;
    if !fm.file_type().is_file() || fm.len() != want as u64 {
        return Err(format!("D55 wire: {what} ({}) changed after its check; the counted length is {want}", p.display()));
    }
    let mut bytes = Vec::with_capacity(want);
    f.take(want as u64 + 1).read_to_end(&mut bytes).map_err(|e| format!("D55: {what} ({}) cannot be read: {e}", p.display()))?;
    if bytes.len() != want {
        return Err(format!("D55 wire: {what} read {} B, the counted length is {want}", bytes.len()));
    }
    Ok(bytes)
}

/// **Read a fork receipt from a run directory.** The directory must hold
/// exactly this run's `L + 2` frame files — `L` being the VERIFIER'S OWN —
/// and nothing else but the one `statement` DIRECTORY
/// (`run_sink::STATEMENT_DIR`) and (D60 review F3) the test-receipt marker
/// [`D55_TEST_RECEIPT_MARKER_FILE`], admitted only as the marker
/// ([`d55_test_receipt_marker`]); a missing frame is named, and any other
/// entry (a D12a segment, a leftover `.partial`, a foreign file) is refused
/// before a byte of any frame is read. Each frame is then read against its
/// counted length, and (D60 review F7) its HEADER is checked against the
/// verifier's own values before the next frame is read: the head's magic,
/// binding, `L` and S0 tag (every root absorbed), each fork frame's magic,
/// binding, `L`, `k` and start tag, the tail's magic, binding and `L` — so a
/// directory of correctly sized frames of another run costs one frame's read,
/// not the whole receipt's. (The verifier checks every one of them again;
/// nothing read here is adopted.) Returns the receipt and each frame's length
/// and SHA-256.
pub(crate) fn read_fork_receipt(fr: &ForkRun, dir: &Path) -> Result<(ForkReceipt, Vec<(u64, String)>), String> {
    let st = fr.st;
    let (sh, l) = (&st.rs.sh, st.rs.l);
    let want = d55_file_names(l);
    let names = super::run_sink::dir_entry_names(dir)?;
    for n in &names {
        if n == super::run_sink::STATEMENT_DIR {
            if dir.join(n).is_dir() {
                continue;
            }
            return Err(format!("D55: the run directory {} holds a FILE called {n}; the only entry allowed beside this run's {} frames is the {} DIRECTORY", dir.display(), l + 2, super::run_sink::STATEMENT_DIR));
        }
        // D60 review F3: the test-receipt marker, as the marker only
        if n == D55_TEST_RECEIPT_MARKER_FILE {
            d55_test_receipt_marker(dir)?;
            continue;
        }
        if !want.contains(n) {
            return Err(format!("D55: the run directory {} holds {n}, which is not one of this {l}-block fork run's {} frames", dir.display(), l + 2));
        }
    }
    for n in &want {
        if !names.contains(n) {
            return Err(format!("D55: the run directory {} is missing {n}", dir.display()));
        }
    }
    let ceiling = super::wire::wire_ceiling(sh);
    let boundary_rows = if l > 1 { st.boundary_spec(0)?.commitment_rows() } else { 0 };
    // D60 review F7: the verifier's own binding and S0, for the headers
    let mut tr = fr.transcript()?;
    let binding = tr.state();
    let head = read_frame_bounded("the head", &dir.join(D55_HEAD_FILE), fw::head_len(l), ceiling)?;
    let (roots, s0_claimed) = fw::decode_head(&head, &binding, l)?;
    absorb_commit(&mut tr, st, &roots, None)?;
    if position_tag(&tr) != s0_claimed {
        return Err(S0_TAG_REFUSAL.into());
    }
    drop(tr);
    let mut forks = Vec::with_capacity(l);
    for k in 0..l {
        let bytes = read_frame_bounded(&format!("fork frame {k}"), &dir.join(d55_fork_file_name(k)), fw::fork_len(&st.stage_layout(k)?), ceiling)?;
        fw::check_fork_header(&bytes, &binding, l, k, &position_tag(&fr.fork(&roots, k, None)?))?;
        forks.push(bytes);
    }
    let tail = read_frame_bounded("the tail", &dir.join(D55_TAIL_FILE), fw::tail_len(sh, l, boundary_rows, BOUNDARY_SITES), ceiling)?;
    fw::check_tail_header(&tail, &binding, l)?;
    let rc = ForkReceipt { head, forks, tail };
    let seen = rc.frames().map(|b| (b.len() as u64, super::run_sink::digest_hex(b))).collect();
    Ok((rc, seen))
}

/// **D60: verify a fork receipt from its run directory** (a fresh process's
/// path: `stack-verify --d55-workers`). Returns the lengths and SHA-256s of
/// EXACTLY the bytes verified, in file order.
pub(crate) fn verify_run_with_forks_from_dir(fr: &ForkRun, blocks: &dyn ForkBlocks, dir: &Path, workers: usize) -> Result<Vec<(u64, String)>, String> {
    // RULINGS CS-1 / CS-4 / CS-6 before the directory is listed
    preflight(fr.st, blocks, true)?;
    let (rc, seen) = read_fork_receipt(fr, dir)?;
    verify_run_with_forks(fr, blocks, &rc, workers)?;
    Ok(seen)
}

#[cfg(test)]
#[path = "run_fork_tests.rs"]
mod tests;

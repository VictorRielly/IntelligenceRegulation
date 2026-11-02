//! **D55 PROTOTYPE (2026-11-01): "commit, fork, join" — one run's blocks
//! proved at the same time.** TEST BUILDS ONLY, OPT-IN, UNREGISTERED.
//!
//! Victor's ruling D55 (`docs/zkmatrix-poc/ZK60_DECISIONS.md`, 2026-11-01):
//! build the construction of `ZK60_D55_CONCURRENT_RUN_DESIGN.md` as an opt-in,
//! unregistered prototype run profile. Registered runs stay D12a ("a run is
//! one transcript end to end", [`super::prove_run_with`]) and their bytes do
//! not move: nothing in this file is reachable from a production build (the
//! module is declared `#[cfg(test)]` in `run.rs`), no run profile is
//! registered for it ([`ForkRun::new`] refuses a base whose fork string CS-7
//! would admit), and the only door is [`ForkRun::new`] with an explicit
//! [`D55OptIn`]. It ships only after its soundness accounting
//! (`results/zk60_d55_20261101/SOUNDNESS_NOTE.md`), the malicious-receipt
//! controls, an independent D24-class review and a privacy re-check.
//!
//! **The construction** (the design's three phases, on a D12a run statement):
//!
//! 1. **Commit.** On the run transcript (its own header: the fork profile
//!    string, a fork parameter line and a fork schedule digest), commit every
//!    internal boundary `B_0 .. B_{L-2}` from the boundary planes the source
//!    already computed, absorb every root in boundary order, then the phase
//!    label `pb-fork-s0`. That state is `S0`; every boundary root is fixed
//!    before any block challenge exists.
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
//! **What a fork receipt that verifies IS NOT**: an accepted construction, a
//! privacy statement or a registered profile. See the soundness note.

use super::super::hash_domain;
use super::super::wire::fork::{self as fw, ForkFrame, TailFrame};
use super::*;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{mpsc, Mutex};
use std::time::Instant;

/// The fork profile string is this prefix and the base D12a run profile. It
/// is a transcript DOMAIN only; it is never handed to `RunShape::new` and no
/// registry names it.
pub(crate) const D55_PROFILE_PREFIX: &str = "d55-commit-fork-join-prototype-unregistered/";
/// the D12a run parameter line's last clause, which a fork run replaces
const D12A_LINE_TAIL: &str = "/one-run-one-transcript";
const D55_LINE_TAIL: &str = "/d55-commit-fork-join-prototype-unregistered";

/// the commit phase's generator domain (the `L - 1` boundary commitments)
const SEED_USE_FORK_COMMIT: &[u8] = b"hashline-zk-rng/private-block/d55-fork-run-commit-phase/v1/";
/// one generator per fork, domain-separated by the block index
const SEED_USE_FORK_BLOCK: &[u8] = b"hashline-zk-rng/private-block/d55-fork-run-one-stream-per-fork/v1/";

/// **THE OPT-IN FLAG.** A value of this type is the only way to make a
/// [`ForkRun`]; its one constructor says what the caller is accepting.
pub(crate) struct D55OptIn(());

impl D55OptIn {
    /// the caller opts in to an UNREVIEWED, UNREGISTERED prototype profile
    pub(crate) fn unreviewed_prototype() -> D55OptIn {
        D55OptIn(())
    }
}

/// A D12a run statement under the D55 prototype profile: the same geometry,
/// blocks, boundaries, endpoint policy and calibration, a different
/// transcript (its own domain, parameter line and schedule) and a different
/// receipt (`run_fork_wire.rs`).
pub(crate) struct ForkRun<'a> {
    st: &'a RunStatement,
    profile: String,
}

/// Where the provers' randomness comes from. `Os` is the construction: one
/// fresh OS-seeded generator for the commit phase and one per fork. A fixture
/// seed exists for nothing but a test's reproducibility (this whole module is
/// test-only) and is never used by the measurement.
#[derive(Clone, Copy, Debug)]
pub(crate) enum ForkRandomness {
    Os,
    #[allow(dead_code)]
    FixtureSeed(u64),
}

impl ForkRandomness {
    fn stream(&self, domain: &[u8]) -> Result<ZkRng, String> {
        match self {
            ForkRandomness::Os => ZkRng::from_os(domain).map_err(|e| format!("D55 fork-run randomness: {e}")),
            ForkRandomness::FixtureSeed(s) => Ok(ZkRng::new(*s, domain)),
        }
    }
}

fn commit_seed_domain(profile: &str) -> Vec<u8> {
    let mut d = SEED_USE_FORK_COMMIT.to_vec();
    d.push(hash_domain::ROLE_RUN_PROVER);
    d.extend_from_slice(profile.as_bytes());
    d
}

fn fork_seed_domain(profile: &str, k: usize) -> Vec<u8> {
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
}

/// **The four malicious-receipt controls the D55 ruling names**, played by a
/// cheating prover. Each makes a complete receipt; `forge_tags` additionally
/// writes, wherever the cheater can compute it, the position tag an honest
/// verifier expects, so that the rejection must come from the Fiat-Shamir
/// chain and not from the (localising, never adopted) tag comparison.
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

impl ForkTamper {
    fn fork_index(&self, k: usize) -> usize {
        match *self {
            ForkTamper::ForkIndexSwap { a, b } if k == a => b,
            ForkTamper::ForkIndexSwap { a, b } if k == b => a,
            _ => k,
        }
    }
    fn skipped_root(&self) -> Option<usize> {
        match *self {
            ForkTamper::RootAfterFork { boundary } => Some(boundary),
            _ => None,
        }
    }
}

impl<'a> ForkRun<'a> {
    /// **The one door.** The base must be a blocks-only run statement of this
    /// build (no token-I/O, no classifier run), and the fork profile string
    /// must be one CS-7's registry does NOT admit.
    pub(crate) fn new(st: &'a RunStatement, _opt_in: D55OptIn) -> Result<ForkRun<'a>, String> {
        if TOKEN_IO_RUN_PROFILES.contains(&st.rs.profile) || is_classify_run_profile(st.rs.profile) {
            return Err(format!("D55: {} is a token-I/O or classifier run profile; the prototype forks blocks-only runs only", st.rs.profile));
        }
        let profile = format!("{D55_PROFILE_PREFIX}{}", st.rs.profile);
        if registered_block_shape(&profile, &st.rs.sh).is_some() {
            return Err(format!("D55: the fork profile {profile:?} is a registered run profile; the prototype must stay unregistered"));
        }
        let fr = ForkRun { st, profile };
        fr.parameter_line()?;
        fr.census()?;
        Ok(fr)
    }

    pub(crate) fn profile(&self) -> &str {
        &self.profile
    }

    /// **The W-2 rule for what this module adds** (stage 25's census, in the
    /// small): the transcript constructor's input (`hashline-v1/` and the
    /// BASE run profile, `12 + |profile|` bytes, already admitted by the base
    /// profile's own census) must be neither the length of, nor one byte
    /// from, any fixed-length absorb the fork run adds (`32 + 8 + |label| + 8
    /// + |data|`); every non-empty claim-list absorb is longer than all of
    /// them; and each generator's seed-derivation input (22 + its domain) is
    /// clear of the three forbidden lengths (64, 40, 47). Returns the table.
    pub(crate) fn census(&self) -> Result<String, String> {
        let ctor = 12 + self.st.rs.profile.len();
        let absorb = |label: &str, data: usize| 32 + 8 + label.len() + 8 + data;
        let fixed: Vec<(&str, usize)> = vec![
            ("run-construction", absorb("run-construction", self.profile.len())),
            ("parameters (the fork line)", absorb("parameters", self.parameter_line()?.len())),
            ("pb-fork-commit-root", absorb("pb-fork-commit-root", 8)),
            ("pb-fork-s0", absorb("pb-fork-s0", 8)),
            ("pb-run-fork", absorb("pb-run-fork", 8)),
            ("pb-run-fork-block", absorb("pb-run-fork-block", 32)),
            ("pb-join-fork", absorb("pb-join-fork", 8)),
            ("pb-join-state", absorb("pb-join-state", 40)),
            ("pb-join-in-claims (no claim)", absorb("pb-join-in-claims", 8)),
            ("pb-join-out-claims (no claim)", absorb("pb-join-out-claims", 8)),
            ("pb-fork-s1", absorb("pb-fork-s1", 8)),
        ];
        for (what, len) in &fixed {
            if len.abs_diff(ctor) <= 1 {
                return Err(format!("D55: the {what} absorb is {len} bytes, at most one byte from the {ctor}-byte transcript constructor of {} (W-2)", self.st.rs.profile));
            }
        }
        // the shortest claim list with one claim of one part on a 0-variable point
        let nonempty_min = absorb("pb-join-in-claims", 8 + 16 + 8 + 8 + 8 + 16 + 8);
        if nonempty_min <= ctor + 1 {
            return Err(format!("D55: a one-claim absorb can be as short as {nonempty_min} bytes, within a byte of the {ctor}-byte constructor (W-2)"));
        }
        let seeds = [("commit-phase generator", 22 + commit_seed_domain(&self.profile).len()), ("per-fork generator", 22 + fork_seed_domain(&self.profile, 0).len())];
        for (what, len) in seeds {
            if [64usize, 40, 47].contains(&len) {
                return Err(format!("D55: the {what}'s seed-derivation input is {len} bytes, a forbidden length"));
            }
        }
        let mut t = format!("constructor {ctor} B ({}); ", self.st.rs.profile);
        t.push_str(&fixed.iter().map(|(w, l)| format!("{w} {l}")).collect::<Vec<_>>().join(", "));
        t.push_str(&format!("; one-claim lists >= {nonempty_min}; seeds {} / {}", seeds[0].1, seeds[1].1));
        Ok(t)
    }

    /// the base D12a line with its one-transcript claim replaced by the D55
    /// prototype's, so a verifier reads the construction in the clear
    pub(crate) fn parameter_line(&self) -> Result<String, String> {
        let base = self.st.parameter_line()?;
        let stem = base.strip_suffix(D12A_LINE_TAIL).ok_or("D55: the base run's parameter line does not end in its one-transcript claim")?;
        Ok(format!("{stem}{D55_LINE_TAIL}"))
    }

    /// The fork schedule: the fork parameter line, the block layout, the three
    /// phases in words, and per block the D12a stage line (which carries the
    /// reserved pair rows of its two IO tabs and any per-layer calibration
    /// clause) under its fork's name.
    fn schedule_digest(&self) -> Result<Digest, String> {
        let (st, l) = (self.st, self.st.rs.l);
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-run-fork-schedule/d55-prototype/1");
        let mut line = |s: &str| {
            h.update(&(s.len() as u64).to_le_bytes());
            h.update(s.as_bytes());
        };
        line(&self.parameter_line()?);
        for s in Layout::for_shape(&st.rs.sh)?.describe() {
            line(&s);
        }
        line(&format!("phase 1 (commit): boundaries 0..{} committed in order on the run transcript, each root absorbed (pb-fork-commit-root, B), then pb-fork-s0 = {l}", l.saturating_sub(1)));
        for k in 0..l {
            line(&format!("fork {k:02}: S0 then pb-run-fork {k} and pb-run-fork-block; the stage body and IO geometry of D12a's [{}]", st.stage_line(k)?));
        }
        line(&format!(
            "phase 3 (join): forks 0..{} in order (pb-join-fork, pb-join-state, pb-join-in-claims, pb-join-out-claims), then pb-fork-s1 = {l}; open boundaries 0..{} once each (block k slot 22, then block k+1 slot 21), then the external input endpoint, then the external output endpoint",
            l - 1,
            l.saturating_sub(1)
        ));
        Ok(*h.finalize().as_bytes())
    }

    /// The fork run's header: the BASE run profile's transcript constructor
    /// (so its input length is the one the base profile's W-2 census already
    /// admitted against every hash-input kind of the run), then FIRST the
    /// construction absorb `run-construction` = the fork profile string —
    /// which separates every later state and challenge from D12a's — then
    /// the D12a header's six absorbs with the fork run's own parameter line
    /// and schedule digest.
    fn transcript(&self) -> Result<Transcript, String> {
        let st = self.st;
        let sh = &st.rs.sh;
        let mut tr = protocol::tagged_transcript(sh, st.rs.profile.as_bytes());
        tr.absorb(b"run-construction", self.profile.as_bytes());
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
    /// this receipt carries; test-visible so a test can compare it with
    /// D12a's for the same statement
    pub(crate) fn binding(&self) -> Result<Digest, String> {
        Ok(self.transcript()?.state())
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
    t.absorb_u64(b"pb-run-fork", idx as u64);
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
/// the worker threads. A slice holds one block per layer; [`RepeatBlock`]
/// holds ONE block for every layer (the measurement's synthetic stack).
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

/// ONE public block at every one of `l` layers, its digest computed once.
/// It is also a D12a [`BlockSource`], so the serial baseline and the fork run
/// read the same blocks the same way.
pub(crate) struct RepeatBlock<'b> {
    blk: &'b BlockPublic,
    l: usize,
    digest: Digest,
}

impl<'b> RepeatBlock<'b> {
    pub(crate) fn new(blk: &'b BlockPublic, l: usize) -> RepeatBlock<'b> {
        RepeatBlock { blk, l, digest: blk.digest() }
    }
}

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
/// [`super::prove_run_with`] and the D12a verifier's start make them
fn preflight(st: &RunStatement, blocks: &dyn ForkBlocks, check_digests: bool) -> Result<(), String> {
    let sh = &st.rs.sh;
    as_many_blocks_as_the_statement(st, blocks.count())?;
    protocol::fits_the_ntt_tables(sh)?;
    for k in 0..st.rs.l {
        let ssh = if sh.accuracy_stack() == super::super::accuracy_precision::Stack::Legacy { sh.clone() } else { st.stage_shape(k)? };
        blocks.get(k)?.check_for_shape(&ssh).map_err(|e| format!("private run: block {k}: {e}"))?;
    }
    policy_fits_the_shape(&st.expected, sh)?;
    if check_digests {
        for k in 0..st.rs.l {
            digest_is_the_statements(k, &blocks.digest_of(k)?, &st.block_digests[k])?;
        }
    }
    st.expected.spec.validate()
}

/// what one fork's worker hands back
struct ForkOut {
    k: usize,
    bytes: Vec<u8>,
    /// the fork's state and counter after `pb-run-fork-block` (what a stale
    /// join would absorb)
    start: ([u8; 32], u64),
    /// the fork's state and counter after `prove_core`
    end: ([u8; 32], u64),
    /// `[slot 21, slot 22]`
    claims: [Vec<ZClaim>; 2],
    core_s: f64,
}

/// the shared, read-only inputs of the fork workers
struct ForkCtx<'c> {
    fr: &'c ForkRun<'c>,
    blocks: &'c dyn ForkBlocks,
    roots: &'c [Digest],
    in_data: Vec<&'c [Fp]>,
    out_data: Vec<&'c [Fp]>,
    ntt: &'c NttTables,
    binding: Digest,
    rnd: ForkRandomness,
    tamper: Option<(ForkTamper, bool)>,
}

impl ForkCtx<'_> {
    fn prove_one(&self, k: usize, wit: Witness) -> Result<ForkOut, String> {
        let st = self.fr.st;
        let l = st.rs.l;
        let (idx, skip, forge) = match self.tamper {
            Some((t, forge)) => (t.fork_index(k), t.skipped_root(), forge),
            None => (k, None, false),
        };
        let mut f = self.fr.fork(self.roots, idx, skip)?;
        let start = (f.state(), f.counter());
        let start_tag = if forge && (idx != k || skip.is_some()) { position_tag(&self.fr.fork(self.roots, k, None)?) } else { position_tag(&f) };
        let mut rng = self.rnd.stream(&fork_seed_domain(&self.fr.profile, k))?;
        let lay = st.stage_layout(k)?;
        let ssh = st.stage_shape(k)?;
        let blk = self.blocks.get(k)?;
        let mut ph = timing::Phases::start();
        let (mut phases, mut tick) = (Vec::new(), Instant::now());
        let t = Instant::now();
        let core = protocol::prove_core(&ssh, &lay, blk, wit, [self.in_data[k], self.out_data[k]], self.ntt, &mut rng, &mut f, &mut ph, &mut phases, &mut tick)?;
        let core_s = t.elapsed().as_secs_f64();
        let end = (f.state(), f.counter());
        let end_tag = position_tag(&f);
        let frame = ForkFrame { a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open };
        let bytes = fw::encode_fork(&frame, &lay, &self.binding, l, k, &start_tag, &end_tag)?;
        Ok(ForkOut { k, bytes, start, end, claims: core.io_claims, core_s })
    }
}

/// **THE D55 FORK-RUN PROVER** (opt-in, unregistered, test builds only):
/// phase 1 on the calling thread, phase 2 on `workers` threads (one shared
/// Metal context, as M10), phase 3 on the calling thread. The source is asked
/// for every boundary plane first, then for every witness in block order;
/// at most `workers + 1` witnesses are alive at once.
pub(crate) fn prove_run_with_forks(fr: &ForkRun, blocks: &dyn ForkBlocks, src: &mut dyn RunWitnessSource, externals: Endpoints, workers: usize, rnd: ForkRandomness) -> Result<(ForkReceipt, ForkStats), String> {
    prove_forks_inner(fr, blocks, src, externals, workers, rnd, None)
}

/// **A CHEATING FORK-RUN PROVER** for the D55 controls (`tamper`, and whether
/// it forges the honest position tags where it can)
pub(crate) fn prove_run_with_forks_tampered(fr: &ForkRun, blocks: &dyn ForkBlocks, src: &mut dyn RunWitnessSource, externals: Endpoints, workers: usize, tamper: ForkTamper, forge_tags: bool) -> Result<(ForkReceipt, ForkStats), String> {
    prove_forks_inner(fr, blocks, src, externals, workers, ForkRandomness::Os, Some((tamper, forge_tags)))
}

fn prove_forks_inner(fr: &ForkRun, blocks: &dyn ForkBlocks, src: &mut dyn RunWitnessSource, externals: Endpoints, workers: usize, rnd: ForkRandomness, tamper: Option<(ForkTamper, bool)>) -> Result<(ForkReceipt, ForkStats), String> {
    let t_all = Instant::now();
    let st = fr.st;
    let (sh, l) = (&st.rs.sh, st.rs.l);
    let workers = workers.clamp(1, l);
    let mut stats = ForkStats { workers, ..ForkStats::default() };
    // RULINGS CS-1, CS-4, CS-6 (the cheating switch skips CS-6, as D12a's)
    preflight(st, blocks, !protocol::cheating_prover_is_on())?;
    let [ein, eout] = protocol::check_endpoints(sh, &st.expected, externals)?;
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.rs.ntt_log());
    let mut tr = fr.transcript()?;
    let binding = tr.state();
    let (skip, forge) = match tamper {
        Some((t, forge)) => (t.skipped_root(), forge),
        None => (None, false),
    };
    stats.preflight_s = t_all.elapsed().as_secs_f64();

    // ---------------- PHASE 1: commit every boundary, then S0
    let t1 = Instant::now();
    let mut rng0 = rnd.stream(&commit_seed_domain(&fr.profile))?;
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
    let mut outs: Vec<ForkOut> = {
        let in_data: Vec<&[Fp]> = (0..l).map(|k| if k == 0 { &ein.data[..] } else { bounds[k - 1].1.data() }).collect();
        let out_data: Vec<&[Fp]> = (0..l).map(|k| if k + 1 == l { &eout.data[..] } else { bounds[k].1.data() }).collect();
        let ctx = ForkCtx { fr, blocks, roots: &roots, in_data, out_data, ntt: &ntt, binding, rnd, tamper };
        let (tx, rx) = mpsc::sync_channel::<(usize, Witness)>(0);
        let rx = Mutex::new(rx);
        let results: Vec<Result<ForkOut, String>> = std::thread::scope(|s| {
            let hs: Vec<_> = (0..workers)
                .map(|_| {
                    let (ctx, rx) = (&ctx, &rx);
                    s.spawn(move || {
                        let mut mine = Vec::new();
                        loop {
                            let job = rx.lock().map_err(|_| "D55: the job queue's lock is poisoned".to_string()).and_then(|q| q.recv().map_err(|_| String::new()));
                            match job {
                                Ok((k, wit)) => mine.push(ctx.prove_one(k, wit).map_err(|e| format!("D55: fork {k}: {e}"))),
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
            for k in 0..l {
                match src.witness(k) {
                    Ok(w) => {
                        if tx.send((k, w)).is_err() {
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

    // ---------------- PHASE 3: join, then every opening after S1
    let t3 = Instant::now();
    if let Some(j) = skip {
        // the cheater's late root: absorbed only after every fork
        absorb_one_root(&mut tr, st, j, &roots[j])?;
    }
    for o in &outs {
        let (state, counter) = match tamper {
            Some((ForkTamper::StaleForkState { block }, _)) if block == o.k => o.start,
            _ => o.end,
        };
        let out_claims: &[ZClaim] = match tamper {
            Some((ForkTamper::ClaimNotJoined { block } | ForkTamper::ClaimNotJoinedNorOpened { block }, _)) if block == o.k => &[],
            _ => &o.claims[1],
        };
        absorb_join(&mut tr, o.k, &state, counter, &o.claims[0], out_claims);
    }
    close_join(&mut tr, l);
    let s1_tag = if forge && tamper.is_some() {
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
        let mut claims = match tamper {
            Some((ForkTamper::ClaimNotJoinedNorOpened { block }, _)) if block == k => Vec::new(),
            _ => outs[k].claims[1].clone(),
        };
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
    let view = CoreView { a_root: frame.a_root, h_root: frame.h_root, mask_root: frame.mask_root, slots: &frame.slots, mask_open: &frame.mask_open, a_open: &frame.a_open, h_open: &frame.h_open };
    let blk = blocks.get(k)?;
    let ssh = st.stage_shape(k)?;
    let mut ph = timing::Phases::start();
    let ([ic, oc], _) = protocol::verify_core(&ssh, &lay, blk, view, ntt, &mut f, &mut ph)?;
    if position_tag(&f) != end_tag {
        return Err(format!("fork {k}'s end tag is not the verifier's own fork-{k} position"));
    }
    Ok(Seen { end: (f.state(), f.counter()), claims: [ic, oc] })
}

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
        return Err("D55: the head's S0 tag is not the verifier's own S0 (every boundary root absorbed, in order, before any fork)".into());
    }
    // ---- phase 2: the forks
    let next = AtomicUsize::new(0);
    let workers = workers.clamp(1, l);
    let mut results: Vec<(usize, Result<Seen, String>)> = std::thread::scope(|s| {
        let hs: Vec<_> = (0..workers)
            .map(|_| {
                let (next, roots, ntt, binding) = (&next, &roots, &ntt, &binding);
                s.spawn(move || {
                    let mut mine = Vec::new();
                    loop {
                        let k = next.fetch_add(1, Ordering::SeqCst);
                        if k >= l {
                            break;
                        }
                        mine.push((k, verify_one_fork(fr, blocks, roots, ntt, binding, k, &rc.forks[k])));
                    }
                    mine
                })
            })
            .collect();
        hs.into_iter().flat_map(|h| h.join().unwrap_or_else(|_| vec![(usize::MAX, Err("a fork verifier panicked".to_string()))])).collect()
    });
    results.sort_by_key(|(k, _)| *k);
    let mut seen: Vec<Seen> = Vec::with_capacity(l);
    for (k, r) in results {
        match r {
            Ok(s) if k == seen.len() => seen.push(s),
            Ok(_) => return Err("D55: the fork verifiers did not return one result per block".into()),
            Err(e) => return Err(format!("D55: fork {k}: {e}")),
        }
    }
    if seen.len() != l {
        return Err("D55: a fork was not verified".into());
    }
    // ---- phase 3: the join, then every opening after S1
    for (k, s) in seen.iter().enumerate() {
        absorb_join(&mut tr, k, &s.end.0, s.end.1, &s.claims[0], &s.claims[1]);
    }
    close_join(&mut tr, l);
    let boundary_rows = if l > 1 { st.boundary_spec(0)?.commitment_rows() } else { 0 };
    let (tail, end_tag) = fw::decode_tail(&rc.tail, sh, &binding, l, boundary_rows, BOUNDARY_SITES, &position_tag(&tr))?;
    let ep = protocol::endpoint_pcs_params(sh);
    for (k, o) in tail.boundary_opens.iter().enumerate() {
        hash_domain::paths_are_the_tree_depth(&format!("boundary {k}"), &ep, o)?;
    }
    hash_domain::paths_are_the_tree_depth("run input endpoint", &ep, &tail.in_open)?;
    hash_domain::paths_are_the_tree_depth("run output endpoint", &ep, &tail.out_open)?;
    for k in 0..l - 1 {
        let spec = st.boundary_spec(k)?;
        // the verifier's OWN claims, from both forks' slot terminals
        let mut claims = seen[k].claims[1].clone();
        claims.extend(seen[k + 1].claims[0].iter().cloned());
        boundary::check_opening(&spec, &claims, &tr).map_err(|e| format!("D55: boundary {k}: {e}"))?;
        let params = spec.params();
        let cm = protocol::commitment(roots[k], spec.commitment_rows(), spec.log_n());
        pcs::verify_zk_tagged(&params, &ZkOpts::standard(&params), &cm, &claims, &tail.boundary_opens[k], &ntt, &mut tr, &tag).map_err(|e| format!("D55: boundary {k}: {e}"))?;
    }
    let ic = &seen[0].claims[0];
    protocol::check_endpoint_opening(ic, sh, &tr)?;
    let cm = protocol::commitment(st.expected.input, sh.endpoint_rows, sh.endpoint_log_n);
    pcs::verify_zk_tagged(&e_params, &e_zko, &cm, ic, &tail.in_open, &ntt, &mut tr, &tag).map_err(|e| format!("D55: run input endpoint: {e}"))?;
    let oc = &seen[l - 1].claims[1];
    protocol::check_endpoint_opening(oc, sh, &tr)?;
    let cm = protocol::commitment(st.expected.output, sh.endpoint_rows, sh.endpoint_log_n);
    pcs::verify_zk_tagged(&e_params, &e_zko, &cm, oc, &tail.out_open, &ntt, &mut tr, &tag).map_err(|e| format!("D55: run output endpoint: {e}"))?;
    if position_tag(&tr) != end_tag {
        return Err("D55: the tail's end tag is not the verifier's own transcript position".into());
    }
    Ok(())
}

#[cfg(test)]
#[path = "run_fork_tests.rs"]
mod tests;

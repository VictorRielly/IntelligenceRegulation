//! **STAGE 12: the private RUN of several blocks under ONE transcript.**
//!
//! Block `k`'s hidden output is block `k+1`'s hidden input, and nothing about
//! either is published. This module holds the run's tests, smallest first:
//! section R1 pins the RULE the boundary commitment must satisfy — the claim
//! audit on a hand-built two-claim schedule — BEFORE any boundary module
//! exists, and the later sections drive the run itself at the development
//! rung.
//!
//! **WHAT A GREEN RUN HERE IS, AND IS NOT.** A run that verifies is a
//! CORRECTNESS milestone: the honest prover and the honest verifier agree that
//! `L` blocks were composed, each one's hidden output being the next one's
//! hidden input, under one Fiat-Shamir chain. It is NOT a privacy result. The
//! privacy obligations a run adds over one block (the boundary plane's joint
//! rank over all three commitments that hold it, blinding independence across
//! blocks, the run-wide joint law) have no tools yet and no gate has been run.
//! Nothing here is an acceptance of anything.

use super::protocol::audit_claims;
use crate::field::{Fp, Fp2};
use crate::pcs::{Slice, ZClaim, ZPart};

// ---------------------------------------------------------------- R1

/// The 125M boundary plane: `512 * 1024 = 2^19` words over rows of `2^14`, so
/// `2^19 / 2^14 = 32` data rows. Every R1 case is stated at this geometry
/// because it is the one the design counts, and because the rung's is the
/// same construction with four data rows instead of thirty-two.
const R1_LOG_LEN: usize = 19;
const R1_LOG_N: usize = 14;
const R1_DATA: usize = 1 << (R1_LOG_LEN - R1_LOG_N);

/// a deterministic, nonzero evaluation point (the audit reads only the SHAPE
/// of a claim, never a value, so any distinct points will do)
fn r1_point(seed: u64, len: usize) -> Vec<Fp2> {
    (0..len as u64).map(|i| Fp2::new(Fp::from_i64((1 + seed * 97 + i * 13) as i64), Fp::from_i64((3 + seed * 31 + i * 7) as i64))).collect()
}

/// One claim of exactly the shape `argument::build_claim` produces for an IO
/// tab: the data slice over the WHOLE padded plane, then the reserved pair at
/// `(mask_row, mask_row + 1)` with weights `(cm, cm * U)`.
fn r1_claim(mask_row: usize, seed: u64, cm: Fp2) -> ZClaim {
    let n = 1usize << R1_LOG_N;
    let pt = r1_point(seed, R1_LOG_LEN);
    let tail = pt[R1_LOG_LEN - R1_LOG_N..].to_vec();
    let mut parts = vec![ZPart { slice: Slice { offset: 0, log_size: R1_LOG_LEN as u32 }, coef: Fp2::ONE, point: pt.clone() }];
    for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
        parts.push(ZPart { slice: Slice { offset: (mask_row + k) * n, log_size: R1_LOG_N as u32 }, coef: cm.mul(u), point: tail.clone() });
    }
    ZClaim { parts, value: Fp2::ZERO }
}

/// `audit_claims` at the boundary's own geometry, with the arguments a
/// two-site commitment supplies: `rows = data + 2 * sites + 2`, the site rows
/// immediately above the data, the proximity PAIR last, and no zero-sum claim.
fn r1_audit(claims: &[ZClaim], sites: usize, rows: usize, prox: usize) -> Result<(), String> {
    let site_rows: Vec<usize> = (R1_DATA..R1_DATA + 2 * sites).collect();
    audit_claims(claims, 1usize << R1_LOG_N, rows, &site_rows, None, prox)
}

/// **R1, THE ACCEPTING CASE.** Two claims raised in two different blocks'
/// slot loops, on DISJOINT reserved pairs, with the proximity pair last: the
/// schedule audit that guards every opening of this module accepts it
/// unchanged, at `rows = 32 + 2*2 + 2 = 38`. This is the whole reason the
/// boundary can reuse the reviewed audit instead of a bespoke one.
#[test]
fn the_claim_audit_accepts_two_boundary_claims_on_disjoint_pairs() {
    let rows = R1_DATA + 6;
    let claims = [r1_claim(R1_DATA, 1, Fp2::ONE), r1_claim(R1_DATA + 2, 2, Fp2::U)];
    r1_audit(&claims, 2, rows, rows - 2).expect("the honest two-claim boundary schedule");
    // and the ORDER of the two claims is immaterial to the audit: the OUT
    // claim of block k is raised a stage before the IN claim of block k+1,
    // and a run that assembled them the other way round is still audited
    let swapped = [r1_claim(R1_DATA + 2, 2, Fp2::U), r1_claim(R1_DATA, 1, Fp2::ONE)];
    r1_audit(&swapped, 2, rows, rows - 2).expect("the two claims in the other order");
}

/// **R1, THE CASE THAT MATTERS: a shared pair is refused BY NAME.** Two
/// terminals sharing one reserved pair is the project's known
/// counterexample — both marginals stay uniform and the JOINT law moves with
/// the witness — and `uses[r] == 1` is the whole defence against it.
#[test]
fn the_claim_audit_refuses_two_boundary_claims_that_share_a_pair() {
    let rows = R1_DATA + 6;
    let claims = [r1_claim(R1_DATA, 1, Fp2::ONE), r1_claim(R1_DATA, 2, Fp2::U)];
    let e = r1_audit(&claims, 2, rows, rows - 2).expect_err("a shared reserved pair was accepted");
    assert!(e.contains("a reserved pair is unused or shared between claims"), "the shared-pair refusal changed: {e}");
}

/// **R1, the other refusals at this geometry**, each by name: a claim that
/// reaches the proximity pair, a zero pair coefficient, a pair that is not
/// aligned to the pair grid, and a second claim that leaves one pair unused.
#[test]
fn the_claim_audit_refusals_fire_at_the_boundary_geometry() {
    let rows = R1_DATA + 6;
    let prox = rows - 2;
    let cases: [(&str, Vec<ZClaim>, &str); 4] = [
        (
            "a claim reaching the proximity pair",
            vec![r1_claim(R1_DATA, 1, Fp2::ONE), r1_claim(prox, 2, Fp2::U)],
            "a claim reaches the proximity pair or leaves the commitment",
        ),
        (
            "a zero pair coefficient",
            vec![r1_claim(R1_DATA, 1, Fp2::ZERO), r1_claim(R1_DATA + 2, 2, Fp2::U)],
            "zero terminal mask coefficient; discard attempt",
        ),
        (
            "a pair straddling the pair grid",
            vec![r1_claim(R1_DATA + 1, 1, Fp2::ONE), r1_claim(R1_DATA + 3, 2, Fp2::U)],
            "a claim does not carry exactly its own reserved pair",
        ),
        ("only one of the two claim sites used", vec![r1_claim(R1_DATA, 1, Fp2::ONE)], "a reserved pair is unused or shared between claims"),
    ];
    for (what, claims, want) in cases {
        let e = r1_audit(&claims, 2, rows, prox).err().unwrap_or_else(|| panic!("{what} was accepted"));
        assert!(e.contains(want), "{what}: the refusal changed: {e}");
    }
}

/// **R1, BLOCKING ITEM B4 / RULING M-1, PINNED: the audit does NOT enforce the
/// hiding geometry.** The independent check's exact rank model found that a
/// boundary with a SINGLE proximity row — `rows = data + 2*sites + 1 = 37` —
/// has joint rank 5 of 6 on its reserved rows and discloses one real
/// dimension. What this test records is what `audit_claims` actually does with
/// that geometry, so that the boundary module's own derivation, and not the
/// audit, is what the hiding requirement rests on.
///
/// At `rows = 37` the audit must be handed `prox = 35` (it requires
/// `prox + 2 == rows`), and then the second reserved pair at rows `(34, 35)`
/// OVERLAPS the declared proximity position. So a two-site 37-row schedule is
/// refused here — but by the proximity-placement rule and not because the
/// geometry leaks, and a caller who declared `prox = 36` instead is refused
/// for a third, unrelated reason. NEITHER refusal is the hiding requirement:
/// both are geometry bookkeeping, and a module that let a caller choose `rows`
/// could still pick a leaking one that the audit happens to accept. That is
/// why `rows` is DERIVED in `boundary.rs` and every other value refused by
/// name (ruling M-1).
#[test]
fn the_claim_audit_is_not_what_enforces_the_hiding_geometry() {
    let claims = [r1_claim(R1_DATA, 1, Fp2::ONE), r1_claim(R1_DATA + 2, 2, Fp2::U)];
    // the 37-row geometry, presented the only two ways it can be presented
    let with_prox_35 = r1_audit(&claims, 2, R1_DATA + 5, R1_DATA + 3);
    let with_prox_36 = r1_audit(&claims, 2, R1_DATA + 5, R1_DATA + 4);
    let e35 = with_prox_35.expect_err("37 rows with prox 35 was accepted");
    let e36 = with_prox_36.expect_err("37 rows with prox 36 was accepted");
    assert!(e35.contains("a claim reaches the proximity pair or leaves the commitment"), "37/35: {e35}");
    assert!(e36.contains("proximity pair placement"), "37/36: {e36}");
    // **FINDING U-1, and it is the sharpest statement of B4 this lane has.**
    // The external endpoint's ONE-site `data + 5` budget has its proximity
    // PAIR at `(data + 2, data + 3)` — `check_opening_challenges` requires
    // `det(rho[data+2], rho[data+3]) != 0`, which is what makes `data + 3`
    // load-bearing and `data + 4` the only spare row. Hand `audit_claims` a
    // proximity position of `data + 3` instead, i.e. DECLARE the pair one row
    // too high, and it ACCEPTS: `prox + 2 == rows` holds, the claim's pair is
    // below it, and `uses` is 1 everywhere. Nothing about the real hiding
    // geometry was checked. (The endpoint does not in fact go through this
    // function — `check_endpoint_opening` checks its single claim's shape
    // directly — but a boundary module that took `rows` and `prox` from a
    // caller could pass exactly this kind of mis-declaration through.)
    let one = [r1_claim(R1_DATA, 1, Fp2::ONE)];
    r1_audit(&one, 1, R1_DATA + 5, R1_DATA + 3).expect("the audit accepts a mis-declared proximity position");
    // declared where the endpoint's pair really is, the same geometry is
    // refused — so the audit's verdict tracks the DECLARATION, not the truth
    let e = r1_audit(&one, 1, R1_DATA + 5, R1_DATA + 2).expect_err("prox = data + 2 at 37 rows was accepted");
    assert!(e.contains("proximity pair placement"), "the endpoint's true geometry: {e}");
}

// ---------------------------------------------------------------- R2

/// **RULING M-1, AS THE FIRST FAILING TEST OF R2.** The boundary commitment's
/// row count is DERIVED from the padded plane and the number of claim sites —
/// `rows = data + 2 * sites + 2`, two reserved pairs and then a proximity
/// PAIR — and a caller who declares any other row count is refused BY NAME.
/// The 37-row geometry is the one the independent check's rank model singled
/// out: one proximity row instead of two, joint rank 5 of 6 on the reserved
/// rows, one real dimension disclosed. `audit_claims` is not what stops it
/// (finding U-1 above); this is.
#[test]
fn the_boundary_derives_its_row_count_and_refuses_the_37_row_geometry_by_name() {
    let ctx = *blake3::hash(b"stage 12: the run's boundary, R2's first test").as_bytes();
    // the 125M boundary: a padded (512, 1024) plane over rows of 2^14
    let ok = super::boundary::BoundarySpec::new(ctx, 512, 1024, 0, 0, 2, 14, 4, 256, 38).expect("the 125M boundary statement is well formed");
    assert_eq!((ok.data_rows(), ok.commitment_rows(), ok.site_rows(), ok.prox_row()), (32, 38, vec![32, 33, 34, 35], 36), "the derived boundary geometry");
    let e = super::boundary::BoundarySpec::new(ctx, 512, 1024, 0, 0, 2, 14, 4, 256, 37).expect_err("the 37-row boundary geometry was accepted");
    assert!(e.contains("declares 37 rows") && e.contains("38"), "the derived-row refusal did not name the geometry: {e}");
}

// ---------------------------------------------------------------- R3 / R4: the run itself

use super::layout::*;
use super::run::{self, RunShape, RunStatement, RunStats, RunWitnessSource};
use super::shape::Shape;
use super::wire::{RUN_HEADER, RUN_TRAILER};
use super::witness::{self, Witness};
use super::{prepare_endpoints, AttentionPublic, BlockPublic, Endpoints, FeedForwardPublic, IoSpec};
use crate::merkle::Digest;

fn run_context() -> Digest {
    *blake3::hash(b"stage 12: the private run's own test context").as_bytes()
}

/// one committed plane of a witness, as the `int16` words an IO commitment
/// carries (the PADDED `Dom::D` cube, which is the slice slots 21 and 22
/// claim)
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

/// The TRUE `tokens x width` hidden state inside a padded `(t_pad, d_pad)`
/// plane: what the next block's witness builder takes. The padded positions
/// are forced to zero by ruling P-1's pad-zero term, so nothing is lost —
/// which is why `A_k`'s padded output plane and `A_{k+1}`'s padded input
/// plane are equal WORD FOR WORD, and why the boundary can claim the whole
/// padded cube.
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// The private side of a run, held as the caller's own data and handed to the
/// prover ONE STAGE AT A TIME. `inputs[k]` is block `k`'s true hidden input
/// and `planes[k]` the padded plane the run's `k`-th IO commitment carries,
/// so `planes` has `L + 1` entries: the external input, the `L - 1`
/// boundaries, the external output.
///
/// An HONEST chain has `inputs[k+1] = out(inputs[k])` and
/// `planes[k+1] = pad(out(inputs[k]))`. Every negative case below is one
/// deliberate disagreement between those two lists, which is exactly what a
/// cheating prover would have.
struct Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
    /// `(block, plane, position, delta)` applied to that block's witness
    /// AFTER it is built — a single-block tamper family, inside a run
    tamper: Option<(usize, usize, usize, i64)>,
}

impl Chain {
    /// the honest chain of `l` blocks from the shape's tame fixture
    fn honest(sh: &Shape, l: usize, zero: bool) -> Chain {
        let (public, ff, tame) = super::grow_tests::tame_case(sh);
        Chain::from_parts(sh, l, public, ff, if zero { vec![0i16; sh.tokens * sh.width] } else { tame })
    }
    /// **STAGE 19.** The same honest chain from ANY public weights and any
    /// first hidden input, so that the dense recipe drives a real run through
    /// this module's harness rather than a second one. `honest` is this at
    /// the tame fixture.
    fn from_parts(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> Chain {
        let ids = Ids::new(sh).expect("the shape has a plane map");
        let mut inputs = Vec::with_capacity(l);
        let mut planes = Vec::with_capacity(l + 1);
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness of the chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().expect("the block's hidden output"));
        }
        Chain { sh: sh.clone(), public, ff, inputs, planes, tamper: None }
    }
    /// **STAGE 21.** The same chain, censused BLOCK BY BLOCK as it is built,
    /// so that the non-triviality of every block is established without
    /// building a single witness twice and with only ONE witness resident —
    /// which is what makes this affordable at the 125M shape.
    fn from_parts_censused(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> (Chain, Vec<BlockCensus>) {
        let ids = Ids::new(sh).expect("the shape has a plane map");
        let mut inputs = Vec::with_capacity(l);
        let mut planes = Vec::with_capacity(l + 1);
        let mut census = Vec::with_capacity(l);
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness of the chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            census.push(BlockCensus::of(sh, &ids, &w));
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().expect("the block's hidden output"));
        }
        (Chain { sh: sh.clone(), public, ff, inputs, planes, tamper: None }, census)
    }
    /// rebuild `planes[k+1 ..]` from `inputs[k]`, so that everything DOWNSTREAM
    /// of a changed input is honest again and only the one disagreement the
    /// test means is left
    fn rechain_from(&mut self, k: usize) {
        let ids = Ids::new(&self.sh).expect("the shape has a plane map");
        let l = self.inputs.len();
        let mut x = self.inputs[k].clone();
        for j in k..l {
            let w = witness::build_shaped(&self.sh, &self.public, &self.ff, &x).expect("an honest witness of the chain");
            self.inputs[j] = x;
            self.planes[j + 1] = padded(&w, ids.at(A_X2));
            x = true_input(&self.sh, &w.output().expect("the block's hidden output"));
        }
    }
}

/// **STAGE 21: WHAT A BLOCK OF A RUN IS NUMERICALLY, as FRACTIONS and
/// COUNTS OF LIVE SLOTS ONLY.**
///
/// A run recipe is only worth proving if every block of it is non-trivial
/// where the diagonal fixture is empty, and the honest way to say so is to
/// MEASURE it rather than to argue from the weights. Nothing here is a
/// value, a position or a count of hidden words: the three fields are
/// fractions of a plane's true support and two counts of LIVE STRUCTURAL
/// SLOTS (how many of the shape's own head slots and key-value groups carry
/// anything at all), which are properties of the recipe, not of a witness.
/// The capture rule forbids more, and more is not needed.
#[derive(Clone, Copy, Debug)]
pub(super) struct BlockCensus {
    /// the fraction of `(t, j)` with `j` in `[d, f)` at which the GATE plane
    /// is nonzero — the half of the hidden axis the diagonal fixture leaves
    /// identically zero at every shape with `f > d`
    pub upper_hidden_gate: f64,
    /// the same for the ACTIVATION plane, which is the gate through SiLU
    pub upper_hidden_act: f64,
    /// how many of the shape's TRUE query head slots have a nonzero
    /// attention output
    pub live_head_slots: usize,
    /// how many of the shape's key-value groups have a nonzero rotated key
    /// AND a nonzero value
    pub live_kv_groups: usize,
    /// do any two key-value groups carry DIFFERENT rotated keys? — the
    /// regime finding S19-F1 rejected, and the only regime in which a
    /// grouped profile's bilinear slots are exercised at all
    pub kv_groups_differ: bool,
}

impl BlockCensus {
    fn of(sh: &Shape, ids: &Ids, w: &Witness) -> BlockCensus {
        let (d, f, fp, dh) = (sh.width, sh.hidden, sh.f_pad, sh.head_dim);
        let kvw = sh.kv_heads * dh;
        let upper = |plane: usize| -> f64 {
            let p = &w.planes[plane];
            let live = (0..sh.tokens).flat_map(|t| (d..f).map(move |j| t * fp + j)).filter(|i| p[*i] != 0).count();
            live as f64 / (sh.tokens * (f - d)) as f64
        };
        let o8 = &w.planes[ids.at(A_O8)];
        let live_head_slots = (0..sh.h_pad)
            .filter(|sl| sh.slot_is_true_head(*sl))
            .filter(|sl| (0..sh.tokens).flat_map(|t| (0..dh).map(move |c| t * sh.d_pad + sl * dh + c)).any(|i| o8[i] != 0))
            .count();
        let (kr, v8) = (&w.planes[ids.at(A_KR8)], &w.planes[ids.at(A_V8)]);
        let group_live = |p: &Vec<i64>, g: usize| (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| j * kvw + g * dh + c)).any(|i| p[i] != 0);
        let live_kv_groups = (0..sh.kv_heads).filter(|g| group_live(kr, *g) && group_live(v8, *g)).count();
        let kv_groups_differ = (1..sh.kv_heads).any(|g| (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| (j, c))).any(|(j, c)| kr[j * kvw + c] != kr[j * kvw + g * dh + c]));
        BlockCensus { upper_hidden_gate: upper(ids.at(A_G8)), upper_hidden_act: upper(ids.at(A_A16)), live_head_slots, live_kv_groups, kv_groups_differ }
    }
    /// the assertions every block of an admissible dense run must clear
    fn assert_non_trivial(&self, sh: &Shape, k: usize) {
        assert!(self.upper_hidden_gate > 0.5, "block {k}: the gate plane is nonzero at only {:.1}% of the upper hidden half", 100.0 * self.upper_hidden_gate);
        assert!(self.upper_hidden_act > 0.2, "block {k}: the activation plane is nonzero at only {:.1}% of the upper hidden half", 100.0 * self.upper_hidden_act);
        assert_eq!(self.live_head_slots, sh.q_heads, "block {k}: only {} of the {} true head slots carry a nonzero attention output", self.live_head_slots, sh.q_heads);
        assert_eq!(self.live_kv_groups, sh.kv_heads, "block {k}: only {} of the {} key-value groups carry nonzero keys and values", self.live_kv_groups, sh.kv_heads);
        assert!(self.kv_groups_differ || sh.kv_heads == 1, "block {k}: every key-value group carries the SAME rotated keys, so the run is not in the regime S19-F1 was about");
    }
}

/// Print EVERY block's census first and assert afterwards, so that one run
/// of a two-and-a-half-minute chain build reports all twelve lines even when
/// a floor is not met.
fn report_census(tag: &str, sh: &Shape, census: &[BlockCensus]) {
    for (k, b) in census.iter().enumerate() {
        // FRACTIONS AND LIVE-SLOT COUNTS ONLY (the capture rule): no witness
        // value, position or word count is printed or kept
        eprintln!(
            "{tag}: block {k:02} upper hidden half gate {:.1}% / activation {:.1}% nonzero, {}/{} head slots live, {}/{} key-value groups live, groups differ {}",
            100.0 * b.upper_hidden_gate,
            100.0 * b.upper_hidden_act,
            b.live_head_slots,
            sh.q_heads,
            b.live_kv_groups,
            sh.kv_heads,
            b.kv_groups_differ
        );
    }
    for (k, b) in census.iter().enumerate() {
        b.assert_non_trivial(sh, k);
    }
}

impl RunWitnessSource for Chain {
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

fn blocks_of(sh: &Shape, l: usize) -> Vec<BlockPublic> {
    (0..l)
        .map(|_| {
            let (public, ff, _) = super::grow_tests::tame_case(sh);
            BlockPublic::new(public, ff)
        })
        .collect()
}

/// **STAGE 19.** The run's `L` public blocks from ONE pair of statements —
/// what a run of the same layer repeated is — so that the dense recipe's
/// blocks are built without regenerating its weights `L` times.
fn blocks_from(public: &AttentionPublic, ff: &FeedForwardPublic, l: usize) -> Vec<BlockPublic> {
    (0..l).map(|_| BlockPublic::new(public.clone(), ff.clone())).collect()
}

/// the run profile of a shape: the rung-G development profile, or 125M's
fn run_shape_for(sh: &Shape, l: usize) -> RunShape {
    if sh.profile == Shape::m125().profile {
        RunShape::m125(l).expect("the 125M run shape")
    } else {
        RunShape::rung_g(l).expect("the rung-G run shape")
    }
}

/// the run statement and the two EXTERNAL endpoint owners of a chain
fn statement_of(c: &Chain, l: usize, blocks: &[BlockPublic]) -> (RunStatement, Endpoints) {
    let rs = run_shape_for(&c.sh, l);
    let spec = IoSpec::new_shaped(&c.sh, run_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &c.planes[0], &c.planes[l]).expect("the run's external endpoint owners");
    let st = RunStatement::new(rs, run_context(), expected, blocks, &vec![(0, 0); l]).expect("the run statement");
    (st, owners)
}

fn prove_to_vec(st: &RunStatement, blocks: &[BlockPublic], src: &mut dyn RunWitnessSource, owners: Endpoints) -> Result<(Vec<Vec<u8>>, RunStats), String> {
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let stats = run::prove_run(st, blocks, src, owners, &mut |k, b| {
        assert_eq!(k, segs.len(), "the sink was handed the segments out of order");
        segs.push(b);
        Ok(())
    })?;
    Ok((segs, stats))
}

/// **THE BYTE-EXACT COUNT, from the block's own counted receipt and nothing
/// else.** A run has three segment lengths: the first closes the external
/// input endpoint (one group), the interior ones close a two-group boundary,
/// and the last closes a boundary AND the external output endpoint.
pub(super) fn counted_segment_bytes(sh: &Shape, l: usize, boundary_rows: usize) -> Vec<usize> {
    let rb = sh.receipt_bytes();
    let e_n = 1usize << sh.endpoint_log_n;
    let e_vec = e_n + sh.opened_cols;
    let e_path = (e_n * sh.endpoint_inv_rate).next_power_of_two().trailing_zeros() as usize;
    let eopen = |groups: usize, rows: usize| (groups + 1) * e_vec * 16 + sh.opened_cols * (8 + rows * 8 + 32 + e_path * 32);
    let (e1, e2) = (eopen(1, sh.endpoint_rows), eopen(2, boundary_rows));
    // slots + mask opening + A + H: the block frame less its envelope and its
    // two endpoint openings
    let common = rb.total - rb.header_and_three_roots - rb.endpoint_openings;
    (0..l)
        .map(|k| {
            RUN_HEADER
                + 3 * 32
                + common
                + if k + 1 < l { 32 } else { 0 }
                + if k == 0 { e1 } else { e2 }
                + if k + 1 == l { e1 } else { 0 }
                + RUN_TRAILER
        })
        .collect()
}

/// **R3's ACCEPTANCE: an honest two-block run verifies FROM ITS SEGMENTS.**
/// Block 1's hidden output is block 2's hidden input and neither is
/// published; the chaining is carried by one boundary commitment with two
/// claim sites, opened once, in stage 2. The segment lengths are the counted
/// ones, byte for byte.
///
/// A CORRECTNESS milestone, not a privacy one: see the module header.
#[test]
fn an_honest_two_block_run_verifies_from_its_segments() {
    let sh = Shape::rung_g();
    let mut c = Chain::honest(&sh, 2, false);
    // the chaining the run is about, checked at the witness level first: the
    // plane block 1 writes IS the plane block 2 reads
    let ids = Ids::new(&sh).expect("plane map");
    let w1 = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[1]).expect("block 2's witness");
    assert_eq!(padded(&w1, ids.at(A_X)), c.planes[1], "block 2's input plane is not block 1's output plane");
    let blocks = blocks_of(&sh, 2);
    let (st, owners) = statement_of(&c, 2, &blocks);
    let rows = st.boundary_spec(0).expect("the run's one boundary").commitment_rows();
    let t0 = std::time::Instant::now();
    let (segs, stats) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the honest two-block run proves");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(stats.segment_bytes, counted_segment_bytes(&sh, 2, rows), "a segment is not the counted length");
    let t1 = std::time::Instant::now();
    run::verify_run(&st, &blocks, &segs).expect("the honest two-block run verifies from its segments");
    let verify_s = t1.elapsed().as_secs_f64();
    eprintln!(
        "RUN L=2 at the rung-G shape: prove {prove_s:.2} s ({:?}), verify from segments {verify_s:.2} s, segments {:?} B (total {} B), boundary {rows} rows, peak RSS {:.0} MiB (shared box, diagnostics only)",
        stats.prove_s.iter().map(|s| (s * 100.0).round() / 100.0).collect::<Vec<f64>>(),
        stats.segment_bytes,
        stats.segment_bytes.iter().sum::<usize>(),
        run::peak_rss_mib()
    );
}

/// **STAGE 19: AN HONEST THREE-BLOCK *DENSE FEED-FORWARD* RUN VERIFIES FROM
/// ITS SEGMENTS.** The same harness, the same tagged rule, the same counted
/// segment lengths — and feed-forward weights that are nonzero everywhere, so
/// that for the first time in this lane a RUN is composed of blocks whose
/// hidden units above `d` carry real values. Receipt lengths are a function
/// of the shape alone, so the counted segment bytes must not move by one
/// byte.
///
/// The attention words are the fixture's, not the dense recipe's: finding
/// S19-F1 rejects any honest proof whose key-value heads carry different
/// activations, so a fully dense run cannot be made until it is fixed.
///
/// A CORRECTNESS milestone, not a privacy one.
#[test]
fn an_honest_three_block_dense_run_verifies_from_its_segments() {
    let sh = Shape::rung_g();
    let (d, f, fp) = (sh.width, sh.hidden, sh.f_pad);
    let (public, ff, input) = super::dense_tests::dense_ff_case(&sh);
    let blocks = blocks_from(&public, &ff, 3);
    let mut c = Chain::from_parts(&sh, 3, public, ff, input);
    // the upper hidden half is live in EVERY block of the run, not only the
    // first: each block's input is the previous block's output, so this is
    // also the statement that the chaining does not collapse it
    let ids = Ids::new(&sh).expect("plane map");
    for k in 0..3 {
        let w = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[k]).expect("a dense witness of the chain");
        let live = (0..sh.tokens).flat_map(|t| (d..f).map(move |j| t * fp + j)).filter(|i| w.planes[ids.at(A_G8)][*i] != 0).count();
        assert!(live > 0, "block {k}: the gate plane is identically zero on the upper hidden half [{d}, {f})");
    }
    let (st, owners) = statement_of(&c, 3, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    let t0 = std::time::Instant::now();
    let (segs, stats) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the honest three-block dense run proves");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(stats.segment_bytes, counted_segment_bytes(&sh, 3, rows), "a dense segment is not the counted length");
    let t1 = std::time::Instant::now();
    run::verify_run(&st, &blocks, &segs).expect("the honest three-block dense run verifies from its segments");
    eprintln!(
        "DENSE RUN L=3 at the rung-G shape: prove {prove_s:.2} s, verify from segments {:.2} s, segments {:?} B (total {} B), boundary {rows} rows",
        t1.elapsed().as_secs_f64(),
        stats.segment_bytes,
        stats.segment_bytes.iter().sum::<usize>()
    );
}

/// **STAGE 20.** The first down-projection band at which a FULLY DENSE
/// chain of `l` blocks is admissible at this shape — searched, not assumed,
/// from the recipe's own `band_down` downwards. Every other band of the
/// recipe (attention, gate, up, the two gains, the hidden input) is the
/// recipe's own, so the ATTENTION words stay dense at every candidate, which
/// is the only thing finding S19-F1 was ever about. Returns the band and the
/// statement it produces; `None` if no band down to 1 makes the chain
/// admissible, which is itself a fact worth reporting.
///
/// Why a chain needs a smaller band than a block: block `k+1`'s hidden input
/// IS block `k`'s `xres2 = xres1 + z16`, so `z16`'s spread compounds along
/// the run and the residual leaves `int16`.
fn first_admissible_dense_run_band(sh: &Shape, l: usize) -> Option<(i64, AttentionPublic, FeedForwardPublic, Vec<i16>)> {
    use super::dense_tests::{band_down, dense_words_with, statement_of_words, BAND_ATTN, BAND_GATE, GAIN, INPUT_MAG};
    for down in (1..=band_down(sh)).rev() {
        let (w, input) = dense_words_with(sh, BAND_ATTN, BAND_GATE, down, GAIN, INPUT_MAG);
        let (public, ff) = statement_of_words(sh, &w);
        let mut x = input.clone();
        let mut ok = true;
        for _ in 0..l {
            match witness::build_shaped(sh, &public, &ff, &x) {
                Ok(wit) => x = true_input(sh, &padded(&wit, Ids::new(sh).expect("plane map").at(A_X2))),
                Err(m) => {
                    eprintln!("DENSE RUN band {down}: the witness builder refused a block of the chain: {m}");
                    ok = false;
                    break;
                }
            }
        }
        if ok {
            return Some((down, public, ff, input));
        }
    }
    None
}

/// **STAGE 20: AN HONEST THREE-BLOCK *FULLY DENSE* RUN VERIFIES FROM ITS
/// SEGMENTS.** Stage 19 could only run the DENSE FEED-FORWARD half, because
/// finding S19-F1 rejected any honest proof whose key-value heads carried
/// different activations and the dense attention words make them do exactly
/// that. With the repair the fully dense recipe runs: every one of the nine
/// public words is nonzero everywhere, in three chained blocks, and the
/// segment lengths are still the counted ones.
///
/// **The one thing the recipe has to give up to be a RUN and not a block** is
/// the down-projection band: block `k+1`'s hidden input IS block `k`'s
/// `xres2 = xres1 + z16`, so the fully dense `band_down` leaves `int16`
/// within a block or two (the witness builder refuses by name, `fixed oracle
/// range refusal: residual 2`). The test states which band the chain is
/// admissible at rather than assuming one: it walks the bands DOWN from the
/// recipe's own and takes the first at which the witness builder accepts all
/// three blocks, and it asserts that the attention words are the DENSE ones
/// throughout, which is what S19-F1 was about.
///
/// A CORRECTNESS milestone, not a privacy one.
#[test]
fn an_honest_three_block_fully_dense_run_verifies_from_its_segments() {
    let sh = Shape::rung_g();
    let (d, f, fp) = (sh.width, sh.hidden, sh.f_pad);
    let ids = Ids::new(&sh).expect("plane map");
    // the first down band at which a THREE-block chain is admissible, tried
    // from the recipe's own downwards; the attention words never change
    let (band, public, ff, input) = first_admissible_dense_run_band(&sh, 3).expect("no fully dense band makes a three-block chain admissible at the rung-G shape");
    // **STAGE 21.** The band `dense_tests::band_down_run` PINS for this shape
    // is the one this search finds — which is what makes the pinned recipe a
    // deterministic function of the shape and not a number someone chose.
    assert_eq!(band, super::dense_tests::band_down_run(&sh), "the pinned chain band is not the first admissible one");
    let blocks = blocks_from(&public, &ff, 3);
    let mut c = Chain::from_parts(&sh, 3, public, ff, input);
    for k in 0..3 {
        let w = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[k]).expect("a fully dense witness of the chain");
        let live = (0..sh.tokens).flat_map(|t| (d..f).map(move |j| t * fp + j)).filter(|i| w.planes[ids.at(A_G8)][*i] != 0).count();
        assert!(live > 0, "block {k}: the gate plane is identically zero on the upper hidden half [{d}, {f})");
        // and the two key-value groups carry DIFFERENT data in every block —
        // the regime S19-F1 rejected
        let (dh, kvw) = (sh.head_dim, sh.kv_heads * sh.head_dim);
        let differs = (0..sh.tokens).flat_map(|t| (0..dh).map(move |i| (t, i))).filter(|(t, i)| w.planes[ids.at(A_KR8)][t * kvw + i] != w.planes[ids.at(A_KR8)][t * kvw + dh + i]).count();
        assert!(differs > 0, "block {k}: the two key-value groups carry identical rotated keys, so the run is not in S19-F1's regime");
    }
    let (st, owners) = statement_of(&c, 3, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    let t0 = std::time::Instant::now();
    let (segs, stats) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the honest three-block fully dense run proves");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(stats.segment_bytes, counted_segment_bytes(&sh, 3, rows), "a fully dense segment is not the counted length");
    let t1 = std::time::Instant::now();
    run::verify_run(&st, &blocks, &segs).expect("the honest three-block fully dense run verifies from its segments");
    eprintln!(
        "FULLY DENSE RUN L=3 at the rung-G shape (down band {band}): prove {prove_s:.2} s, verify from segments {:.2} s, segments {:?} B (total {} B), boundary {rows} rows",
        t1.elapsed().as_secs_f64(),
        stats.segment_bytes,
        stats.segment_bytes.iter().sum::<usize>()
    );
}

/// **THE HEADLINE NEGATIVE TEST: block 2 rebuilt on a hidden input that is
/// NOT block 1's output is REJECTED BY THE VERIFIER.** Both variants, because
/// they fail at different slots:
///
/// (i) the boundary holds block 1's TRUE output and block 2 was run on
///     something else — block 2's slot 21 (`IO-in endpoint equality`) fails;
/// (ii) the boundary holds block 2's input and block 1's output differs —
///     block 1's slot 22 (`IO-out endpoint equality`) fails.
///
/// In both the PROVER succeeds: a cheating prover does not run the honest
/// prover's checks, so only a refusal by the VERIFIER is a soundness
/// statement (finding F-8's rule, applied to a run).
#[test]
fn the_headline_negative_test_a_second_block_on_another_input_is_rejected_by_the_verifier() {
    let sh = Shape::rung_g();
    for (variant, want) in [("(i) block 2 run on something other than block 1's output", "IO-in"), ("(ii) block 1's output is not what the boundary holds", "IO-out")] {
        let mut c = Chain::honest(&sh, 2, false);
        if variant.starts_with("(i)") {
            // block 2's input moves; the boundary keeps block 1's TRUE output
            let honest_boundary = c.planes[1].clone();
            c.inputs[1][0] += 1;
            c.rechain_from(1);
            c.planes[1] = honest_boundary;
        } else {
            // the BOUNDARY moves, at a true support position, so block 1's
            // honest output is no longer what it holds. Block 1's input, block
            // 2 and the external output endpoint are all honest for the plane
            // the boundary DOES hold, so only block 1's slot 22 can object.
            let ids = Ids::new(&sh).expect("plane map");
            c.planes[1][0] += 1;
            c.inputs[1] = true_input(&sh, &c.planes[1]);
            let w = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[1]).expect("block 2's witness on what the boundary holds");
            c.planes[2] = padded(&w, ids.at(A_X2));
        }
        let blocks = blocks_of(&sh, 2);
        let (st, owners) = statement_of(&c, 2, &blocks);
        let (segs, _) = match prove_to_vec(&st, &blocks, &mut c, owners) {
            Err(e) => panic!("{variant}: the PROVER refused, so this case says nothing about the verifier: {e}"),
            Ok(v) => v,
        };
        let e = run::verify_run(&st, &blocks, &segs).err().unwrap_or_else(|| panic!("{variant}: a run whose blocks are not chained VERIFIED"));
        assert!(e.contains(want), "{variant}: expected the {want} slot to fail, got: {e}");
        eprintln!("{variant}: rejected by the verifier: {e}");
    }
}

/// A dropped, reordered, duplicated or FOREIGN segment (spliced from a second
/// honest run of the same statement, with its own fresh commitments) is
/// rejected. The first three are caught before a field element is parsed; the
/// foreign one is caught by the header's transcript position, because two
/// runs diverge at their first commitment.
#[test]
fn a_dropped_reordered_duplicated_or_foreign_segment_is_rejected() {
    let sh = Shape::rung_g();
    let mut c = Chain::honest(&sh, 3, false);
    let blocks = blocks_of(&sh, 3);
    let (st, owners) = statement_of(&c, 3, &blocks);
    let (segs, _) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the honest three-block run proves");
    run::verify_run(&st, &blocks, &segs).expect("the honest three-block run verifies");
    // a SECOND honest run of the same statement: same blocks, same planes,
    // fresh randomness, so every commitment and every segment differs
    let (st2, owners2) = statement_of(&c, 3, &blocks);
    let (other, _) = prove_to_vec(&st2, &blocks, &mut c, owners2).expect("a second honest run");
    let cases: Vec<(&str, Vec<Vec<u8>>)> = vec![
        ("a dropped last segment", segs[..2].to_vec()),
        ("a dropped middle segment", vec![segs[0].clone(), segs[2].clone()]),
        ("two segments swapped", vec![segs[1].clone(), segs[0].clone(), segs[2].clone()]),
        ("a duplicated segment", vec![segs[0].clone(), segs[0].clone(), segs[2].clone()]),
        ("a foreign segment from another honest run", vec![segs[0].clone(), other[1].clone(), segs[2].clone()]),
        ("every segment foreign but the first", vec![segs[0].clone(), other[1].clone(), other[2].clone()]),
        ("only the third segment", vec![segs[2].clone()]),
    ];
    for (what, s) in cases {
        let e = run::verify_run(&st, &blocks, &s).err().unwrap_or_else(|| panic!("{what} was accepted"));
        eprintln!("{what}: rejected: {e}");
    }
    // a one-bit change anywhere in any segment, and a truncation
    for k in 0..3 {
        let mut bad = segs.clone();
        let at = bad[k].len() / 2;
        bad[k][at] ^= 1;
        assert!(run::verify_run(&st, &blocks, &bad).is_err(), "a one-bit change in segment {k} was accepted");
        let mut short = segs.clone();
        short[k].pop();
        assert!(run::verify_run(&st, &blocks, &short).is_err(), "a truncated segment {k} was accepted");
    }
}

/// **`L` IS THE VERIFIER'S OWN.** A verifier that expects a different number
/// of blocks is proving a different statement under a different transcript,
/// and it refuses: the run profile, the `"run-shape"` absorb, the parameter
/// line and the schedule digest all carry `L`, and the segment count is
/// checked against the verifier's own before anything is parsed.
#[test]
fn a_run_verified_with_the_wrong_l_is_rejected() {
    let sh = Shape::rung_g();
    let mut c = Chain::honest(&sh, 3, false);
    let blocks = blocks_of(&sh, 3);
    let (st, owners) = statement_of(&c, 3, &blocks);
    let (segs, _) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the honest three-block run proves");
    // the same segments, a statement that says two blocks
    let two = blocks_of(&sh, 2);
    let (st2, _o) = statement_of(&c, 2, &two);
    let e = run::verify_run(&st2, &two, &segs).err().expect("a three-segment run verified under L = 2");
    assert!(e.contains("segments were offered"), "{e}");
    // and a two-segment prefix under the same L = 2 statement: the run
    // binding differs, so segment 1 is not that run's
    let e = run::verify_run(&st2, &two, &segs[..2]).err().expect("a prefix of a three-block run verified as a two-block run");
    assert!(e.contains("another run"), "{e}");
}

// ====================================================================
// STAGE 21 / RULING R-5: the interior boundary scales
// ====================================================================

/// **THE BYTE-IDENTITY WITNESS FOR RULING R-5.** Everything the run header
/// absorbs, for the APPROVED scales, as literals.
///
/// R-5 adds a REFUSAL and nothing else: a run that used to construct with an
/// interior scale other than the approved calibration's now does not, and a
/// run at the approved scales is untouched. "Untouched" has to be MEASURED,
/// not argued, because the temptation R-5 declines is to bind the interior
/// scales by absorbing `BoundarySpec::digest()` — which would move every
/// proof byte. These literals were captured on the lane tip BEFORE the
/// refusal was added and must not move when it is.
///
/// The statement is built with SYNTHETIC, FIXED endpoint roots
/// (`ExpectedIo::from_roots`) because the real ones come from an
/// OS-seeded-RNG commitment and are not reproducible across processes. Every
/// other word of the header — the parameter line, the block digests, the
/// boundary digests, the schedule digest, the calibration — is a
/// deterministic function of the public statement, so the binding below is
/// too.
fn r5_fixed_statement(l: usize, scales: &[(i32, i32)]) -> Result<RunStatement, String> {
    let sh = Shape::rung_g();
    let spec = IoSpec::new_shaped(&sh, run_context(), 0, 0)?;
    let expected = super::ExpectedIo::from_roots(spec, [0x11; 32], [0x22; 32]);
    RunStatement::new(run_shape_for(&sh, l), run_context(), expected, &blocks_of(&sh, l), scales)
}

/// the rung-G `L = 3` run binding at the approved scales, captured before the
/// R-5 refusal existed (`u3-s21-r5-pin.log`). D65(1), finding F12: re-pinned
/// under the `/2` run profile (the binding is the run header's transcript
/// state, whose domain is the run profile string; the boundary digests below
/// did not move). It was `[161, 7, 121, 146, …]` under `/1`
/// (`results/zk60_f12_fix_20261104/REPIN.md`).
const R5_RUNG_G_L3_BINDING: [u8; 32] = [
    236, 113, 40, 11, 252, 209, 161, 91, 85, 24, 88, 2, 95, 96, 225, 198, 152, 14, 133, 168, 222, 13, 222, 69, 230, 38, 118, 216, 120, 195, 152, 174,
];
/// the two internal boundary digests of the same run, same capture
const R5_RUNG_G_L3_BOUNDARIES: [[u8; 32]; 2] = [
    [158, 51, 156, 18, 113, 248, 140, 198, 238, 67, 15, 141, 45, 5, 238, 153, 159, 113, 151, 213, 84, 175, 168, 86, 240, 93, 230, 219, 96, 11, 61, 209],
    [8, 8, 151, 49, 39, 84, 136, 12, 255, 240, 178, 115, 225, 107, 28, 12, 33, 14, 184, 48, 200, 168, 211, 70, 7, 85, 81, 47, 127, 155, 104, 81],
];

#[test]
fn the_run_header_the_approved_scales_bind_is_byte_identical_under_ruling_r5() {
    let st = r5_fixed_statement(3, &[(0, 0); 3]).expect("the approved statement constructs");
    let h = st.capture_header().expect("the capture header");
    eprintln!("R5-PIN binding {:?} boundaries {:?} {:?}", st.binding().expect("the binding"), h.boundaries[0].digest, h.boundaries[1].digest);
    assert_eq!(st.binding().expect("the binding"), R5_RUNG_G_L3_BINDING, "the run binding moved: R-5 must add NO absorb");
    assert_eq!([h.boundaries[0].digest, h.boundaries[1].digest], R5_RUNG_G_L3_BOUNDARIES, "a boundary digest moved");
    assert_eq!(h.boundary_scales, vec![0, 0], "the interior scales are the approved calibration's");
    assert_eq!(h.external_scales, super::ENDPOINT_SCALES, "the external scales are the approved calibration's");
    // and the thing R-5 deliberately does NOT do: the boundary digest is not
    // among the header's absorbs, so the interior scales stay unbound by the
    // transcript and bound instead by this construction-time refusal
    assert_eq!(
        h.parameter_line,
        "T24/d96/f192/H6/KV2/dh16/log_cols10/inv_rate4/Q256/P1/sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript/endpoint-log_n10-rate4-pad256-rows9/L3/boundary-log_n10-rate4-pad256-rows10-sites2/external-rows9/one-run-one-transcript",
        "the run parameter line moved"
    );
}

/// **RULING R-5, the refusal itself.** The security owner's reading: the
/// EXTERNAL scales are bound through the absorbed expected-IO bytes, the
/// INTERIOR ones by nothing at all — not the parameter line, not a stage
/// line, and `BoundarySpec::digest()` is never absorbed. They have no
/// arithmetic effect, so no equation is at risk; but a receipt does not
/// attest to them, and a scale chosen from the hidden input would publish a
/// hidden intermediate's dynamic range. The ruling is that a run REFUSES any
/// block scale pair other than the approved calibration's, exactly as
/// `IoSpec::new` already does for the endpoints.
///
/// Before this refusal, `RunStatement::new(.., &[(0,0),(0,1),(1,0)])`
/// CONSTRUCTED: the interior scale 1 agreed with itself across the boundary
/// and the external pair was `(0, 0)`, so both existing checks passed.
#[test]
fn an_interior_boundary_scale_other_than_the_approved_calibrations_is_refused() {
    // an interior scale of 1, consistent across the boundary and with the
    // approved external pair at both ends: the case that used to construct
    let e = r5_fixed_statement(3, &[(0, 1), (1, 1), (1, 0)]).err().expect("a run with an interior scale of 1 constructed");
    assert!(e.contains("block scales are pinned to the approved calibration (0, 0)"), "{e}");
    assert!(e.contains("block 0 declares (0, 1)"), "the refusal must name the block and the pair it refused: {e}");
    // one block in the middle out of calibration, likewise
    let e = r5_fixed_statement(3, &[(0, 0), (0, 3), (3, 0)]).err().expect("a run with an interior scale of 3 constructed");
    assert!(e.contains("block scales are pinned to the approved calibration (0, 0)"), "{e}");
    // a single block has no interior boundary at all, and is still pinned
    let e = r5_fixed_statement(1, &[(2, 2)]).err().expect("a one-block run out of calibration constructed");
    assert!(e.contains("not the endpoint policy's") || e.contains("pinned to the approved calibration"), "{e}");
    // and the approved pairs construct, at L = 1, 2, 3
    for l in 1..=3 {
        r5_fixed_statement(l, &vec![(0, 0); l]).unwrap_or_else(|e| panic!("the approved scales must construct at L = {l}: {e}"));
    }
}

/// **RULING M-4, both halves.** A run in which block `k+1` declares a
/// different input scale than block `k`'s output scale DOES NOT CONSTRUCT —
/// a boundary has one scale field and there is nowhere to put the second —
/// and a receipt made under one calibration identity is rejected under
/// another.
///
/// **STAGE 21.** M-4's check stays AHEAD of R-5's in `RunStatement::new`, so
/// this test still exercises M-4 and not the new refusal: a boundary whose
/// two sides disagree is refused as a boundary disagreement, and only a
/// self-consistent run that is out of calibration reaches R-5.
#[test]
fn a_boundary_scale_disagreement_does_not_construct_and_a_foreign_calibration_is_rejected() {
    let sh = Shape::rung_g();
    let mut c = Chain::honest(&sh, 2, false);
    let blocks = blocks_of(&sh, 2);
    // the scale disagreement, at construction
    let rs = RunShape::rung_g(2).expect("the rung-G run shape");
    let spec = IoSpec::new_shaped(&sh, run_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, _owners) = prepare_endpoints(spec, &c.planes[0], &c.planes[2]).expect("the external owners");
    let e = RunStatement::new(rs, run_context(), expected, &blocks, &[(0, 0), (1, 0)]).err().expect("a boundary with two scales was constructed");
    assert!(e.contains("a boundary has ONE scale"), "{e}");
    // the calibration, end to end
    let (st, owners) = statement_of(&c, 2, &blocks);
    let (segs, _) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the honest run proves");
    run::verify_run(&st, &blocks, &segs).expect("the honest run verifies under its own calibration");
    let other = st.with_calibration(*blake3::hash(b"another approved calibration").as_bytes());
    let e = run::verify_run(&other, &blocks, &segs).err().expect("a run verified under a foreign calibration");
    eprintln!("a foreign calibration: rejected: {e}");
}

/// The ALL-ZERO hidden input — the fixed input of the privacy case — is a
/// valid witness for a whole RUN, and its segments verify. A precondition of
/// the privacy argument, not a privacy result.
#[test]
fn the_all_zero_hidden_input_proves_and_verifies_as_a_run() {
    let sh = Shape::rung_g();
    let mut c = Chain::honest(&sh, 2, true);
    let ids = Ids::new(&sh).expect("plane map");
    assert!(c.planes[0].iter().all(|v| *v == 0), "the zero run's input plane is not zero");
    let w0 = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[0]).expect("block 1's witness");
    assert!(w0.planes[ids.at(A_X)].iter().all(|v| *v == 0), "the zero run's x_in plane is not zero");
    let blocks = blocks_of(&sh, 2);
    let (st, owners) = statement_of(&c, 2, &blocks);
    let rows = st.boundary_spec(0).expect("the boundary").commitment_rows();
    let (segs, stats) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the all-zero run proves");
    assert_eq!(stats.segment_bytes, counted_segment_bytes(&sh, 2, rows), "the segment lengths move with the hidden input");
    run::verify_run(&st, &blocks, &segs).expect("the all-zero run verifies from its segments");
}

/// **EVERY SINGLE-BLOCK TAMPER FAMILY, APPLIED TO BLOCK 2 OF A RUN.** One
/// representative of each of the twenty-seven families `rung_tests` decides
/// at one block, applied to the SECOND block of a two-block run on a true
/// support position. The prover must produce the segments and the VERIFIER
/// must refuse them.
#[test]
fn every_single_block_tamper_family_is_still_rejected_inside_a_run() {
    let sh = Shape::rung_g();
    let ids = Ids::new(&sh).expect("plane map");
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
    for (name, plane, delta) in cases {
        let mut c = Chain::honest(&sh, 2, false);
        c.tamper = Some((1, plane, 0, delta));
        let blocks = blocks_of(&sh, 2);
        let (st, owners) = statement_of(&c, 2, &blocks);
        // STAGE 40 (ported, native round 5), ruling CS-3: the honest prover
        // refuses a lookup miss by name; a cheating prover does not, so this
        // helper proves with the check off and the verifier has to speak
        let _cheating = super::protocol::CheatingProver::on();
        match prove_to_vec(&st, &blocks, &mut c, owners) {
            Err(e) => panic!("{name} in block 2: the PROVER refused, so this case says nothing about the verifier: {e}"),
            Ok((segs, _)) => {
                let e = run::verify_run(&st, &blocks, &segs).err().unwrap_or_else(|| panic!("{name} in block 2: a tampered run VERIFIED"));
                eprintln!("{name} in block 2 of a run: rejected by the verifier: {e}");
            }
        }
    }
}

/// **R5: the ladder.** `L = 3` is the smallest run with a block that has a
/// boundary on BOTH sides and with two consecutive boundaries; `L = 12` is
/// the 125M run's block count at a shape that costs seconds. Recorded for
/// each: prove and verify seconds, the total receipt against the counted
/// figure, and THE PROCESS HIGH-WATER MARK AFTER EACH BLOCK — a mark that
/// RISES across stages is the sign of allocator fragmentation, which is
/// reported and not repaired here (the check's OMITTED CONDITION 3).
#[test]
fn the_run_ladder_at_the_rung_three_blocks_then_twelve() {
    let sh = Shape::rung_g();
    for l in [3usize, 12] {
        let mut c = Chain::honest(&sh, l, false);
        let blocks = blocks_of(&sh, l);
        let (st, owners) = statement_of(&c, l, &blocks);
        let rows = st.boundary_spec(0).expect("the first boundary").commitment_rows();
        let t0 = std::time::Instant::now();
        let (segs, stats) = prove_to_vec(&st, &blocks, &mut c, owners).unwrap_or_else(|e| panic!("L = {l}: {e}"));
        let prove_s = t0.elapsed().as_secs_f64();
        let want = counted_segment_bytes(&sh, l, rows);
        assert_eq!(stats.segment_bytes, want, "L = {l}: a segment is not the counted length");
        let t1 = std::time::Instant::now();
        run::verify_run(&st, &blocks, &segs).unwrap_or_else(|e| panic!("L = {l}: the honest run did not verify: {e}"));
        let verify_s = t1.elapsed().as_secs_f64();
        let marks: Vec<i64> = stats.hwm_mib.iter().map(|m| m.round() as i64).collect();
        let rising = marks.windows(2).any(|w| w[1] > w[0]);
        eprintln!(
            "RUN L={l} at the rung-G shape: prove {prove_s:.2} s, verify from segments {verify_s:.2} s, receipt {} B in {l} segments (counted {}), high-water mark after each block {marks:?} MiB — {}; {}",
            stats.segment_bytes.iter().sum::<usize>(),
            want.iter().sum::<usize>(),
            if rising { "RISING (allocator fragmentation: reported, not repaired)" } else { "flat" },
            malloc_threshold_note()
        );
        hwm_report(&format!("RUN L={l} at rung-G"), &stats.hwm_mib);
        // the first segment closes the external input endpoint and the last
        // closes a boundary AND the external output endpoint, so the three
        // lengths are distinct in exactly the way the count says
        assert!(want[0] < want[1] && want[l - 1] > want[1], "L = {l}: the three segment lengths are not the counted three");
    }
}

/// **R6: ONE TWO-BLOCK RUN AT THE 125M SHAPE — PREPARED, NOT RUN.**
///
/// `#[ignore]`d, and this lane does NOT launch it: it is a heavy run and must
/// go out detached, under the heavy lock, inside a memory ceiling, on a
/// quiesced box. The exact command is in the lane ledger's stage 12 section,
/// in the style of stage 9's and stage 11's.
///
/// What it prints: the witness-build seconds of the chain, then per block the
/// proving seconds and the PROCESS HIGH-WATER MARK after that block, then the
/// two segment lengths against the counted figure and the verifying seconds.
/// Predictions, so that the run can fail (all [MODEL from MEASURED], the
/// single 125M block having measured prove 26.54 s, verify 1.04 s, receipt
/// 40,782,792 B, peak 10.42 GiB): prove about 2 x 31 s including the witness
/// builds, peak about 10.74 GiB (ruling M-3's flushed figure; predict under
/// 11.0), verify from segments about 2.1 s.
///
/// **The witness is built FOUR times, not twice**, and that is deliberate:
/// the chain builds block 1's witness to learn the boundary plane and block
/// 2's to learn the external output plane, drops both, and the prover then
/// builds each again just in time so that a run never holds two 125M
/// witnesses (711 MB each). About 4 x 4.7 s of the wall clock is that, and it
/// is not proving time.
///
/// The two segments are kept in memory here (about 81 MB against a 10.7 GiB
/// peak) so that the run can be VERIFIED; ruling M-3's flushing rule is about
/// the PROVER, which hands each segment to the sink and holds none, and a
/// twelve-block run must stream them to disk.
#[test]
#[ignore]
fn private_run_125m_two_blocks() {
    let sh = Shape::m125();
    eprintln!("125M RUN L=2: {}", malloc_threshold_note());
    let t0 = std::time::Instant::now();
    let mut c = Chain::honest(&sh, 2, false);
    eprintln!("125M RUN L=2: chain built (2 witnesses, dropped) in {:.2} s, peak RSS so far {:.2} GiB", t0.elapsed().as_secs_f64(), run::peak_rss_mib() / 1024.0);
    let blocks = blocks_of(&sh, 2);
    let (st, owners) = statement_of(&c, 2, &blocks);
    let rows = st.boundary_spec(0).expect("the run's one boundary").commitment_rows();
    assert_eq!(rows, 38, "the 125M boundary is not the counted 38 rows");
    let t1 = std::time::Instant::now();
    let (segs, stats) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the 125M two-block run proves");
    let prove_s = t1.elapsed().as_secs_f64();
    for (k, (s, m)) in stats.prove_s.iter().zip(stats.hwm_mib.iter()).enumerate() {
        eprintln!("125M RUN L=2: block {k}: prove {s:.2} s, high-water mark after it {:.2} GiB", m / 1024.0);
    }
    let want = counted_segment_bytes(&sh, 2, rows);
    eprintln!("125M RUN L=2: segments {:?} B, counted {want:?} B, total {} B", stats.segment_bytes, stats.segment_bytes.iter().sum::<usize>());
    assert_eq!(stats.segment_bytes, want, "a 125M segment is not the counted length");
    let t2 = std::time::Instant::now();
    run::verify_run(&st, &blocks, &segs).expect("the 125M two-block run verifies from its segments");
    let verify_s = t2.elapsed().as_secs_f64();
    hwm_report("125M RUN L=2", &stats.hwm_mib);
    eprintln!(
        "125M RUN L=2 RESULT: prove {prove_s:.2} s ({:?} per block), verify from segments {verify_s:.2} s, receipt {} B in 2 segments, peak RSS {:.2} GiB (shared box) — a CORRECTNESS result, not a privacy one",
        stats.prove_s.iter().map(|s| (s * 100.0).round() / 100.0).collect::<Vec<f64>>(),
        stats.segment_bytes.iter().sum::<usize>(),
        run::peak_rss_mib() / 1024.0
    );
}

// ------------------------------------------ STAGE 13: WHERE the segments go
//
// Not WHAT is in one. The wire format of a segment does not move: these tests
// are about a run whose segments are WRITTEN TO DISK as they are finished and
// READ BACK ONE AT A TIME by the verifier, which is what a twelve-block 125M
// run needs (484 MB of receipt against a 12 GiB ceiling).

use super::run_sink::{self, DirSink, MemorySink, SegmentSink};
use std::path::{Path, PathBuf};

/// **THE ALLOCATOR CONDITION, PRINTED BY EVERY LARGE RUN.** Multi-block runs
/// at large shapes are launched with `MALLOC_MMAP_THRESHOLD_=131072` in the
/// environment. With glibc's DYNAMIC threshold, freeing a large mapped buffer
/// raises the threshold, so later large buffers come from the heap and
/// fragment it; pinned, every large buffer is mapped and returned to the
/// system when it is freed. MEASURED on the same binary and the same
/// two-block 125M run, 2026-09-20 (`results/zk60_block125m_lane/m125-run-l2.log`
/// and `m125-run-l2-mmapthreshold.log`): high-water mark 10.67 then 10.82 GiB
/// without it, 10.04 then 10.05 GiB — flat — with it, at no measurable cost in
/// time. Nothing here calls `mallopt` and no library behaviour changes for any
/// other caller: the variable is read by the C allocator at start-up and this
/// is only a report of whether the launcher set it.
fn malloc_threshold_note() -> String {
    match std::env::var("MALLOC_MMAP_THRESHOLD_") {
        Ok(v) => format!("MALLOC_MMAP_THRESHOLD_={v} (pinned: every large buffer is mapped and returned to the system on free)"),
        Err(_) => "MALLOC_MMAP_THRESHOLD_ is NOT SET (glibc's dynamic threshold: expect the high-water mark to rise across blocks)".to_string(),
    }
}

/// The process high-water mark after every block, its change from the block
/// before, and `HWM-RISE` when that change is more than 1%. A whole-process
/// figure on a shared box: it BOUNDS a stage's cost from above and is not a
/// measurement of it.
fn hwm_report(tag: &str, marks: &[f64]) {
    for (k, m) in marks.iter().enumerate() {
        let (d, pct) = if k == 0 { (0.0, 0.0) } else { (m - marks[k - 1], 100.0 * (m - marks[k - 1]) / marks[k - 1]) };
        eprintln!("{tag}: block {k}: high-water mark {m:.1} MiB ({d:+.1} MiB, {pct:+.2}%){}", if pct > 1.0 { "  HWM-RISE" } else { "" });
    }
}

/// A directory of the machine's temporary space that is REMOVED when the test
/// leaves, so that no passing test leaves a file behind. Never inside the
/// repository.
struct TempRunDir(PathBuf);

impl TempRunDir {
    fn new(tag: &str) -> TempRunDir {
        let n = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0);
        let p = std::env::temp_dir().join(format!("hl-private-run-{tag}-{}-{n}", std::process::id()));
        std::fs::create_dir_all(&p).unwrap_or_else(|e| panic!("the test's temporary run directory {}: {e}", p.display()));
        TempRunDir(p)
    }
    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempRunDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

/// One run, its segments handed to BOTH sinks: the directory sink writes each
/// one out and keeps only its length and digest, the in-memory sink keeps the
/// bytes, so that a test can compare what landed on disk with what the prover
/// handed over FOR THIS RUN. Two separate runs cannot be compared byte for
/// byte: the prover takes its randomness from the OS (`ZkRng::from_os`) and
/// this lane adds no seeded path.
fn prove_to_dir_and_memory(st: &RunStatement, blocks: &[BlockPublic], src: &mut dyn RunWitnessSource, owners: Endpoints, dir: &Path) -> Result<(DirSink, MemorySink, RunStats), String> {
    let mut disk = DirSink::create(dir, st.rs().l())?;
    let mut mem = MemorySink::default();
    let stats = run::prove_run(st, blocks, src, owners, &mut |k, bytes| {
        mem.accept(k, bytes.clone())?;
        disk.accept(k, bytes)
    })?;
    Ok((disk, mem, stats))
}

/// **STAGE 13's ACCEPTANCE AT THE DEVELOPMENT RUNG: a TWELVE-block run whose
/// segments are written to a directory as they are finished, and verified by
/// reading them back ONE AT A TIME.** The prover holds nothing of a segment
/// once the sink has it (ruling M-3), the verifier holds at most one
/// segment's bytes, and `L` is the verifier's own.
#[test]
fn a_twelve_block_run_written_to_a_directory_verifies_by_streaming() {
    let sh = Shape::rung_g();
    let l = 12usize;
    let tmp = TempRunDir::new("l12");
    let mut c = Chain::honest(&sh, l, false);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    let rows = st.boundary_spec(0).expect("the first boundary").commitment_rows();
    let want = counted_segment_bytes(&sh, l, rows);
    let t0 = std::time::Instant::now();
    let (disk, mem, stats) = prove_to_dir_and_memory(&st, &blocks, &mut c, owners, tmp.path()).expect("the twelve-block run proves to a directory");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(stats.segment_bytes, want, "a segment the prover counted is not the counted length");
    assert_eq!(disk.lengths(), &want[..], "a segment FILE is not the counted length");
    // what is on disk IS what the prover handed over, byte for byte, and the
    // digest the sink recorded is the digest of the file
    for k in 0..l {
        let on_disk = std::fs::read(tmp.path().join(run_sink::segment_file_name(k))).expect("the segment file reads back");
        assert_eq!(on_disk.len(), want[k], "segment {k} on disk is not the counted length");
        assert_eq!(on_disk, mem.segments()[k], "segment {k} on disk is not the segment the in-memory sink was handed");
        assert_eq!(run_sink::digest_hex(&on_disk), disk.digests()[k], "segment {k}'s recorded digest is not the file's");
    }
    // exactly twelve files and nothing else: no temporary name is left behind
    let names = run_sink::dir_entry_names(tmp.path()).expect("the run directory lists");
    assert_eq!(names.len(), l, "the run directory holds {names:?}");
    assert_eq!(names[0], "segment-000.bin", "the first file is not the first segment");
    let t1 = std::time::Instant::now();
    run::verify_run_from_dir(&st, &blocks, tmp.path()).expect("the twelve-block run verifies by streaming from its directory");
    let verify_s = t1.elapsed().as_secs_f64();
    eprintln!(
        "RUN L=12 TO DISK at the rung-G shape: prove {prove_s:.2} s, verify by streaming {verify_s:.2} s, receipt {} B in {l} files (counted {}), {}",
        disk.total_bytes(),
        want.iter().sum::<usize>(),
        malloc_threshold_note()
    );
    hwm_report("RUN L=12 to disk at rung-G", &stats.hwm_mib);
}

/// **THE NEGATIVE BATTERY ON FILES.** Each mutation is made to a directory
/// that has just verified, is rejected, and is then undone — and the run
/// verifies again at the end, so every refusal is the mutation's and not a
/// residue of the one before.
#[test]
fn a_missing_truncated_swapped_duplicated_or_foreign_segment_file_is_rejected() {
    let sh = Shape::rung_g();
    let l = 3usize;
    let tmp = TempRunDir::new("neg");
    let other_tmp = TempRunDir::new("neg-other");
    let mut c = Chain::honest(&sh, l, false);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    let (_disk, mem, _stats) = prove_to_dir_and_memory(&st, &blocks, &mut c, owners, tmp.path()).expect("the honest three-block run proves to a directory");
    // a SECOND honest run of the same statement, in its own directory: same
    // blocks, same planes, fresh randomness, so every segment differs
    let (st2, owners2) = statement_of(&c, l, &blocks);
    let (_d2, mem2, _s2) = prove_to_dir_and_memory(&st2, &blocks, &mut c, owners2, other_tmp.path()).expect("a second honest run proves to its own directory");
    let path = |k: usize| tmp.path().join(run_sink::segment_file_name(k));
    let put = |k: usize, bytes: &[u8]| std::fs::write(path(k), bytes).expect("the test writes a segment file");
    let restore = |k: usize| put(k, &mem.segments()[k]);
    let refused = |what: &str| {
        let e = run::verify_run_from_dir(&st, &blocks, tmp.path()).err().unwrap_or_else(|| panic!("{what} was ACCEPTED"));
        eprintln!("{what}: rejected: {e}");
        e
    };
    run::verify_run_from_dir(&st, &blocks, tmp.path()).expect("the honest three-block run verifies by streaming");
    // (1) a MISSING segment file
    std::fs::remove_file(path(1)).expect("the test removes a segment file");
    assert!(refused("a missing segment file").contains("segment-001.bin"), "the refusal did not name the missing file");
    restore(1);
    // (2) a TRUNCATED segment file
    let short = &mem.segments()[1][..mem.segments()[1].len() - 1];
    put(1, short);
    assert!(refused("a truncated segment file").contains("counted length"), "the refusal did not name the counted length");
    restore(1);
    // (3) two segment files SWAPPED
    put(0, &mem.segments()[1]);
    put(1, &mem.segments()[0]);
    refused("two segment files swapped");
    restore(0);
    restore(1);
    // (4) a DUPLICATED segment: segment 0's bytes under segment 1's name
    put(1, &mem.segments()[0]);
    refused("a duplicated segment file");
    restore(1);
    // (5) an EXTRA segment file beyond L
    put(l, &mem.segments()[l - 1]);
    assert!(refused("an extra segment file beyond L").contains("segment-003.bin"), "the refusal did not name the extra file");
    std::fs::remove_file(path(l)).expect("the test removes the extra file");
    // (6) a FOREIGN segment file from a second honest run of the same statement
    put(1, &mem2.segments()[1]);
    assert!(refused("a foreign segment file from another honest run").contains("another run"), "the refusal was not the run binding");
    restore(1);
    // (7) a FOREIGN FILE in the run directory
    std::fs::write(tmp.path().join("notes.txt"), b"not a segment").expect("the test writes a foreign file");
    assert!(refused("a foreign file in the run directory").contains("notes.txt"), "the refusal did not name the foreign file");
    std::fs::remove_file(tmp.path().join("notes.txt")).expect("the test removes the foreign file");
    // and the honest run verifies again: every refusal above was its mutation
    run::verify_run_from_dir(&st, &blocks, tmp.path()).expect("the restored three-block run verifies by streaming");
}

/// **REVIEW r3 FINDING r3_6 (verifier DoS, not soundness; native round 5).**
/// A segment file is read only through the bounded reader: a symbolic link
/// to `/dev/zero`, a FIFO, a regular file one byte longer than the counted
/// length and a 512 MiB sparse file are each refused BY NAME from metadata,
/// before any byte of it is read. (An `open` of the FIFO would block for
/// ever and a read of `/dev/zero` would run into the memory cap: this test
/// returning is the evidence that neither was opened.) The honest run
/// verifies before and after.
#[test]
fn review_r3_6_a_symlink_fifo_or_overlong_segment_file_is_refused_before_it_is_read() {
    let sh = Shape::rung_g();
    let l = 2usize;
    let tmp = TempRunDir::new("r3-6");
    let mut c = Chain::honest(&sh, l, false);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    let (_disk, mem, _stats) = prove_to_dir_and_memory(&st, &blocks, &mut c, owners, tmp.path()).expect("the honest two-block run proves to a directory");
    run::verify_run_from_dir(&st, &blocks, tmp.path()).expect("the honest two-block run verifies by streaming");
    let path = tmp.path().join(run_sink::segment_file_name(0));
    let want = mem.segments()[0].len();
    let restore = || {
        let _ = std::fs::remove_file(&path);
        std::fs::write(&path, &mem.segments()[0]).expect("the test restores segment 0");
    };
    let refused = |what: &str| {
        let e = run::verify_run_from_dir(&st, &blocks, tmp.path()).err().unwrap_or_else(|| panic!("{what} was ACCEPTED"));
        eprintln!("review r3_6, {what}: refused: {e}");
        e
    };
    // (a) a symbolic link to /dev/zero
    std::fs::remove_file(&path).expect("the test removes segment 0");
    std::os::unix::fs::symlink("/dev/zero", &path).expect("the test links segment 0 to /dev/zero");
    assert!(refused("a symbolic link to /dev/zero").contains("not a regular file"));
    assert!(run::read_segment_bounded(&st, 0, &path).unwrap_err().contains("not a regular file"), "the bounded reader alone");
    restore();
    // (b) a FIFO
    std::fs::remove_file(&path).expect("the test removes segment 0");
    let made = std::process::Command::new("mkfifo").arg(&path).status().map(|s| s.success()).unwrap_or(false);
    assert!(made, "the test could not make a FIFO with mkfifo");
    assert!(refused("a FIFO").contains("not a regular file"));
    restore();
    // (c) a regular file ONE BYTE longer than the counted length
    std::fs::OpenOptions::new().write(true).open(&path).and_then(|f| f.set_len(want as u64 + 1)).expect("the test extends segment 0 by one byte");
    let e = refused("a segment file one byte too long");
    assert!(e.contains("counted length") && e.contains("before it is read"), "{e}");
    // (d) a 512 MiB SPARSE regular file (uses no disk blocks)
    std::fs::OpenOptions::new().write(true).open(&path).and_then(|f| f.set_len(512 << 20)).expect("the test makes segment 0 a sparse 512 MiB file");
    let e = refused("a 512 MiB sparse segment file");
    assert!(e.contains("536870912 B") && e.contains("before it is read"), "{e}");
    restore();
    // and the honest run verifies again: every refusal above was its mutation
    run::verify_run_from_dir(&st, &blocks, tmp.path()).expect("the restored two-block run verifies by streaming");
}

/// **REVIEW r4 FINDING r4_B (verifier DoS; native R5b).** The bounded reader
/// of a regular file (export profile, manifests, arrays, sequence files, an
/// artifact's policy): a FIFO, a symbolic link to `/dev/zero` (or to an
/// honest file) and a directory are refused by name before they are opened,
/// a file above the bound or (exact) of another length from metadata before
/// it is read; an honest file reads back. (An open of the FIFO would block
/// for ever: this test returning is the evidence it was not opened.)
#[test]
fn review_r4_b_the_bounded_file_reader_refuses_before_opening_or_reading() {
    let tmp = TempRunDir::new("r4-b");
    let honest = tmp.path().join("honest.bin");
    std::fs::write(&honest, vec![7u8; 4096]).unwrap();
    assert_eq!(run::read_regular_file_bounded(&honest, 4096, true).unwrap(), vec![7u8; 4096]);
    assert_eq!(run::read_regular_file_bounded(&honest, 8192, false).unwrap().len(), 4096);
    let e = run::read_regular_file_bounded(&honest, 4095, false).unwrap_err();
    assert!(e.contains("exceeds the bound") && e.contains("before it is read"), "{e}");
    let e = run::read_regular_file_bounded(&honest, 4097, true).unwrap_err();
    assert!(e.contains("expected length is 4097") && e.contains("before it is read"), "{e}");
    let zero = tmp.path().join("zero.bin");
    std::os::unix::fs::symlink("/dev/zero", &zero).unwrap();
    assert!(run::read_regular_file_bounded(&zero, 1 << 30, false).unwrap_err().contains("not a regular file"));
    let link = tmp.path().join("link.bin");
    std::os::unix::fs::symlink(&honest, &link).unwrap();
    assert!(run::read_regular_file_bounded(&link, 4096, false).unwrap_err().contains("not a regular file"));
    let fifo = tmp.path().join("fifo.bin");
    assert!(std::process::Command::new("mkfifo").arg(&fifo).status().map(|s| s.success()).unwrap_or(false), "mkfifo");
    assert!(run::read_regular_file_bounded(&fifo, 4096, false).unwrap_err().contains("not a regular file"));
    assert!(run::read_regular_file_bounded(tmp.path(), 4096, false).unwrap_err().contains("not a regular file"));
    let sparse = tmp.path().join("sparse.bin");
    std::fs::File::create(&sparse).and_then(|f| f.set_len(512 << 20)).unwrap();
    let e = run::read_regular_file_bounded(&sparse, 4096, false).unwrap_err();
    assert!(e.contains("536870912 bytes exceeds the bound 4096"), "{e}");
}

/// A run never writes into a directory that does not exist or already holds
/// something: a half-run's segments must not be mistakable for this run's.
#[test]
fn the_directory_sink_refuses_a_directory_that_is_missing_or_not_empty() {
    let tmp = TempRunDir::new("guard");
    let missing = tmp.path().join("no-such-directory");
    let e = DirSink::create(&missing, 2).err().expect("the sink accepted a directory that does not exist");
    assert!(e.contains("does not exist"), "{e}");
    std::fs::write(tmp.path().join("something.bin"), b"x").expect("the test writes a file");
    let e = DirSink::create(tmp.path(), 2).err().expect("the sink accepted a directory that is not empty");
    assert!(e.contains("not empty"), "{e}");
}

/// **THE TWELVE-BLOCK 125M RECEIPT, COUNTED — in a test that costs nothing.**
/// The figure the heavy run below is measured against, derived from the
/// block's own counted receipt and the run's framing constants and nothing
/// else (finding U-6). Stage 20 renamed it: the S19-F1 repair moves the
/// figure, so a name carrying the old literal would be a lie, and the number
/// is carried as the pre-repair one plus the counted per-block delta.
#[test]
fn the_twelve_block_125m_receipt_is_the_counted_figure() {
    let sh = Shape::m125();
    let spec = super::boundary::BoundarySpec::new(run_context(), sh.t_pad, sh.d_pad, 0, 1, run::BOUNDARY_SITES, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows + 1)
        .expect("the 125M internal boundary statement");
    assert_eq!(spec.commitment_rows(), 38, "the 125M boundary is not the derived 38 rows");
    let want = counted_segment_bytes(&sh, 12, spec.commitment_rows());
    // STAGE 20: every segment carries the whole block's slot vector, so the
    // S19-F1 repair adds its COUNTED bilinear delta to each of the twelve.
    let d = super::grow_tests::s20_bilinear_delta(&sh).1;
    assert_eq!((want[0], want[1], want[11]), (40_033_336 + d, 40_301_624 + d, 41_051_160 + d), "the three 125M segment lengths");
    assert_eq!(want.iter().sum::<usize>(), 484_100_736 + 12 * d, "the twelve-block 125M receipt is not the counted figure");
}

/// **STAGE 20, the 125M half of the fully dense RUN question — `#[ignore]`d
/// because it builds up to twelve 125M witnesses.** The rung-G answer is
/// measured by `an_honest_three_block_fully_dense_run_verifies_from_its_segments`
/// above; this is the same search at the 125M shape, which costs about
/// eleven seconds and 725 MiB PER BLOCK and so is not a gate. It PROVES
/// NOTHING: it only asks the witness builder whether a fully dense chain of
/// twelve blocks is admissible at some down-projection band, and prints the
/// first band that works or says that none does.
#[test]
#[ignore = "builds up to twelve 125M witnesses (about 11 s and 725 MiB each); it proves nothing and is not a gate"]
fn the_first_admissible_fully_dense_run_band_at_125m() {
    let sh = Shape::m125();
    match first_admissible_dense_run_band(&sh, 12) {
        Some((band, _, _, _)) => {
            eprintln!("125M FULLY DENSE RUN: admissible at down band {band} for twelve blocks");
            // STAGE 21: the pinned recipe band must be the measured one
            assert_eq!(band, super::dense_tests::band_down_run(&sh), "the pinned 125M chain band is not the first admissible one");
        }
        None => panic!("125M FULLY DENSE RUN: NO down band from the recipe's own down to 1 makes a twelve-block fully dense chain admissible"),
    }
}

/// **STAGE 21: THE FULLY DENSE TWELVE-BLOCK RECIPE AT 125M IS ADMISSIBLE AND
/// NON-TRIVIAL IN EVERY BLOCK — witness builder only, nothing is proved.**
///
/// This is the acceptance of the recipe `private_run_125m_twelve_blocks`
/// takes under `HL_PB_WEIGHTS=dense`, and it is separated from it so the
/// recipe can be established without a seven-minute proving run: it builds
/// the twelve witnesses of the chain, one at a time, censuses each as it is
/// built and drops it. About 11 s and 725 MiB per block, so it is
/// `#[ignore]`d and goes out detached under the heavy lock.
///
/// What it establishes, block by block for all twelve: the witness builder
/// ACCEPTS the block; the upper hidden half `[d, f)` — identically zero in
/// every proof this lane made before stage 19 — is live in the gate and in
/// the activation; every one of the twelve true query head slots has a
/// nonzero attention output; all four key-value groups carry nonzero keys
/// and values; and the groups carry DIFFERENT rotated keys, which is the
/// regime finding S19-F1 rejected and the only regime in which the two
/// repaired bilinear slots are exercised at all.
///
/// Only FRACTIONS and LIVE-SLOT COUNTS are printed, and nothing is retained.
#[test]
#[ignore = "builds twelve 125M witnesses (about 11 s and 725 MiB each); it proves nothing"]
fn the_fully_dense_twelve_block_recipe_is_admissible_and_non_trivial_at_125m() {
    let sh = Shape::m125();
    let t0 = std::time::Instant::now();
    let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
    let (_c, census) = Chain::from_parts_censused(&sh, 12, public, ff, x0);
    eprintln!(
        "125M DENSE L=12 RECIPE: twelve witnesses built and dropped in {:.2} s, peak RSS {:.2} GiB, down band {}",
        t0.elapsed().as_secs_f64(),
        run::peak_rss_mib() / 1024.0,
        super::dense_tests::band_down_run(&sh)
    );
    report_census("125M DENSE L=12 RECIPE", &sh, &census);
}

/// The directory a heavy run writes its segments to, from the environment.
/// The run REFUSES TO START unless the variable is set to an existing, EMPTY
/// directory outside the repository: 484 MB is not a thing to put somewhere
/// by default, and no measurement of this project writes into its own source
/// tree.
fn heavy_run_dir(var: &str) -> PathBuf {
    let v = std::env::var(var).unwrap_or_else(|_| panic!("{var} is not set: this run writes hundreds of MB of segments and will not choose a directory for you"));
    let p = PathBuf::from(&v);
    assert!(p.is_absolute(), "{var} = {v} is not an absolute path");
    let dir = p.canonicalize().unwrap_or_else(|e| panic!("{var} = {v} does not exist (the orchestrator creates it): {e}"));
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().expect("the crate has a parent directory").to_path_buf();
    assert!(!dir.starts_with(&repo), "{var} = {} is inside the repository {}: a run's segments never go there", dir.display(), repo.display());
    let n = run_sink::dir_entry_names(&dir).unwrap_or_else(|e| panic!("{e}"));
    assert!(n.is_empty(), "{var} = {} is not empty (it holds {n:?})", dir.display());
    dir
}

/// **STAGE 13: TWELVE BLOCKS AT THE 125M SHAPE — PREPARED, NOT RUN.**
///
/// `#[ignore]`d, and this lane does NOT launch it: it is a heavy run and goes
/// out detached, under the heavy lock, inside a memory ceiling, on a quiesced
/// box, with `MALLOC_MMAP_THRESHOLD_=131072` in its environment. The exact
/// command is in the lane ledger's stage 13 section.
///
/// **What is resident.** Twelve PUBLIC STATEMENTS — about 9.2 MB of padded
/// weights each, 110 MB in all, because `prove_run` and `verify_run` both take
/// the run's statements as one slice and a run's transcript absorbs every
/// block's digest in the header. That is about 1% of the modelled peak and it
/// is not worth an API that yields them one at a time. ONE witness (711 MB),
/// built just in time by the chain and dropped. ZERO segments: each is written
/// to `HL_PB_RUN_DIR` and dropped as it is finished (ruling M-3), and the
/// verifier reads them back one at a time.
///
/// Predictions, so that the run can fail [MODEL from the MEASURED two-block
/// run: prove 64.07 s, verify 2.38 s, peak 10.05 GiB with the threshold
/// pinned]: about 12 x 31.5 s = 6.3 minutes of proving after a chain build of
/// about 12 x 4.7 s, verify by streaming about 12 s, receipt 484,100,736 B,
/// peak about 10.15 GiB (the ten further public statements and eleven further
/// planes over the two-block run's 10.05).
///
/// It STOPS rather than running on if a segment length is not the counted one
/// or if the high-water mark passes 11.5 GiB.
///
/// **STAGE 21: `HL_PB_WEIGHTS` chooses the recipe.** `tame` (the DEFAULT,
/// and every figure ever measured for this test is at it) is the diagonal
/// fixture, whose upper hidden half is identically zero and whose key-value
/// groups all carry the same data. `dense` is the FULLY DENSE run recipe at
/// its measured chain band (`dense_tests::dense_run_case`): every entry of
/// all nine public words nonzero, a non-constant hidden input, and — this is
/// the point — the upper hidden half live and every head slot and key-value
/// group carrying different nonzero data in EVERY ONE of the twelve blocks,
/// asserted block by block as the chain is built. The log line and the
/// retained run statement both say which recipe ran.
#[test]
#[ignore]
fn private_run_125m_twelve_blocks() {
    let sh = Shape::m125();
    let l = 12usize;
    let which = std::env::var("HL_PB_WEIGHTS").unwrap_or_else(|_| "tame".into());
    let dir = heavy_run_dir("HL_PB_RUN_DIR");
    eprintln!("125M RUN L=12 [HL_PB_WEIGHTS={which}]: segments go to {}; {}", dir.display(), malloc_threshold_note());
    let t0 = std::time::Instant::now();
    let (mut c, blocks, recipe) = match which.as_str() {
        "tame" => (Chain::honest(&sh, l, false), blocks_of(&sh, l), super::run_statement_file::TAME_FIXTURE),
        "dense" => {
            let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
            let blocks = blocks_from(&public, &ff, l);
            let (c, census) = Chain::from_parts_censused(&sh, l, public, ff, x0);
            report_census("125M RUN L=12 [dense]", &sh, &census);
            (c, blocks, super::run_statement_file::DENSE_RUN_FIXTURE)
        }
        other => panic!("HL_PB_WEIGHTS={other:?} is not a recipe this test knows; it is `tame` (the default) or `dense`"),
    };
    eprintln!("125M RUN L=12 [{which}]: chain built ({l} witnesses, each dropped) in {:.2} s, high-water mark so far {:.2} GiB", t0.elapsed().as_secs_f64(), run::peak_rss_mib() / 1024.0);
    let (st, owners) = statement_of(&c, l, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    assert_eq!(rows, 38, "the 125M boundary is not the counted 38 rows");
    let want = counted_segment_bytes(&sh, l, rows);
    assert_eq!(want.iter().sum::<usize>(), 484_100_736 + 12 * super::grow_tests::s20_bilinear_delta(&sh).1, "the counted receipt moved");
    let mut disk = DirSink::create(&dir, l).unwrap_or_else(|e| panic!("125M RUN L=12: {e}"));
    let mut prev_hwm = run::peak_rss_mib();
    let mut tick = std::time::Instant::now();
    let t1 = std::time::Instant::now();
    let stats = run::prove_run(&st, &blocks, &mut c, owners, &mut |k, bytes: Vec<u8>| {
        let n = bytes.len();
        if n != want[k] {
            return Err(format!("STOP at block {k}: the segment is {n} B and the counted length is {} B", want[k]));
        }
        disk.accept(k, bytes)?;
        let (hwm, stage_s) = (run::peak_rss_mib(), tick.elapsed().as_secs_f64());
        let (d, pct) = (hwm - prev_hwm, 100.0 * (hwm - prev_hwm) / prev_hwm);
        eprintln!(
            "125M RUN L=12: block {k}: stage {stage_s:.2} s, segment {n} B (the counted length), high-water mark {:.2} GiB ({:+.3} GiB, {pct:+.2}%){}",
            hwm / 1024.0,
            d / 1024.0,
            if pct > 1.0 { "  HWM-RISE" } else { "" }
        );
        if hwm > 11.5 * 1024.0 {
            return Err(format!("STOP at block {k}: the high-water mark {:.2} GiB passed the 11.5 GiB ceiling", hwm / 1024.0));
        }
        (prev_hwm, tick) = (hwm, std::time::Instant::now());
        Ok(())
    })
    .unwrap_or_else(|e| panic!("125M RUN L=12: {e}"));
    let prove_s = t1.elapsed().as_secs_f64();
    // **STAGE 18.** The run is verified by streaming AND its PUBLIC statement
    // is retained beside the segments, in that order and only in that order
    // (ruling D21): `verify_then_write` verifies first and writes nothing if
    // the run does not verify, so the presence of
    // `<HL_PB_RUN_DIR>/statement/run-statement.json` afterwards is itself the
    // statement that this run verified in this process. The file carries only
    // public values — the geometry, the two external endpoint commitments and
    // their scales, the twelve block digests, the calibration identity, the
    // hash rule, the eleven boundaries' public statement digests and the
    // twelve segment files' lengths and SHA-256 — so a later process can
    // rebuild the verifier's statement and check the 484 MB of receipt this
    // run leaves behind.
    //
    // **STAGE 21.** The statement records the RECIPE, so a fresh verifier
    // regenerates the same public weights and checks them against the twelve
    // block digests the header absorbs.
    let w = super::run_statement_file::verify_then_write(&st, &blocks, &dir, &recipe)
        .unwrap_or_else(|e| panic!("125M RUN L=12: the run did not verify by streaming, or its public statement could not be retained: {e}"));
    let verify_s = w.verify_s;
    eprintln!("125M RUN L=12 [{which}]: the PUBLIC run statement is retained at {} — {} B, sha256 {}, recipe {:?}", w.path.display(), w.bytes, w.sha256, recipe.name);
    for (k, (len, dg)) in disk.lengths().iter().zip(disk.digests()).enumerate() {
        eprintln!("125M RUN L=12: {} {len} B sha256 {dg}", run_sink::segment_file_name(k));
    }
    hwm_report("125M RUN L=12", &stats.hwm_mib);
    eprintln!(
        "125M RUN L=12 [{which}] RESULT: prove {prove_s:.2} s ({:?} per block), verify by streaming {verify_s:.2} s, receipt {} B in {l} files (counted 484,100,736 pre-repair), peak RSS {:.2} GiB, {} — a CORRECTNESS result, not a privacy one",
        stats.prove_s.iter().map(|s| (s * 100.0).round() / 100.0).collect::<Vec<f64>>(),
        disk.total_bytes(),
        run::peak_rss_mib() / 1024.0,
        malloc_threshold_note()
    );
}

// ------------------------------------------------- STAGE 17: the run under the D19 tag

/// **A THREE-BLOCK TAGGED RUN PROVES AND VERIFIES** (ruling T-6 item 7). The
/// run profile is rung-G's, which is tagged, so every hash of every stage —
/// the run transcript, `A`, `H`, `M`, the two internal boundaries, both
/// external endpoints, and BOTH POSITION TAGS of every segment, which are
/// squeezed from a discarded transcript CLONE and would be drawn under the
/// unkeyed function if `clone_state` had dropped the key — is keyed. The
/// trailer comparison inside `RunVerifier::step` is what checks the clone:
/// it recomputes the end tag on its own transcript and refuses if it is not
/// the one the prover wrote.
#[test]
fn a_three_block_run_proves_and_verifies_under_the_tag() {
    let sh = Shape::rung_g();
    assert!(!sh.hashes_under_the_legacy_rule(), "the run's block shape must be tagged for this test to mean anything");
    let mut c = Chain::honest(&sh, 3, false);
    let blocks = blocks_of(&sh, 3);
    let (st, owners) = statement_of(&c, 3, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    let (segs, stats) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the honest tagged three-block run proves");
    // THE RECEIPT SIZES DO NOT MOVE: the wire format carries no tag.
    assert_eq!(stats.segment_bytes, counted_segment_bytes(&sh, 3, rows), "a tagged segment is not the counted length — the tag moved a receipt byte");
    run::verify_run(&st, &blocks, &segs).expect("the honest tagged three-block run verifies");
}

/// **A TAGGED RUN IS REFUSED BY A LEGACY-RULE RUN VERIFIER** (ruling T-6
/// item 7, the cross-rule half at the run). The refusal is whatever comes
/// first — the whole Fiat–Shamir chain diverges at the run header's very
/// first hash — and this test records it rather than demanding a particular
/// layer.
#[test]
fn a_tagged_run_is_refused_by_a_legacy_rule_run_verifier() {
    let sh = Shape::rung_g();
    let mut c = Chain::honest(&sh, 2, false);
    let blocks = blocks_of(&sh, 2);
    let (st, owners) = statement_of(&c, 2, &blocks);
    let (segs, _) = prove_to_vec(&st, &blocks, &mut c, owners).expect("the honest tagged run proves");
    run::verify_run(&st, &blocks, &segs).expect("the tagged run verifies under its own tag");
    let e = {
        let _g = super::hash_tag_tests::ForcedLegacy::on();
        run::verify_run(&st, &blocks, &segs).expect_err("a TAGGED run verified under a LEGACY-rule run verifier")
    };
    eprintln!("STAGE 17 cross-rule refusal at the run: tagged run, legacy verifier: {e}");
    assert!(!e.is_empty());
    // and the reverse: proved under the legacy rule, verified tagged
    let (st2, segs2, blocks2) = {
        let _g = super::hash_tag_tests::ForcedLegacy::on();
        let mut c2 = Chain::honest(&sh, 2, false);
        let blocks2 = blocks_of(&sh, 2);
        let (st2, owners2) = statement_of(&c2, 2, &blocks2);
        let (segs2, _) = prove_to_vec(&st2, &blocks2, &mut c2, owners2).expect("the legacy-rule run proves");
        run::verify_run(&st2, &blocks2, &segs2).expect("the legacy-rule run verifies under the legacy rule");
        (st2, segs2, blocks2)
    };
    let e2 = run::verify_run(&st2, &blocks2, &segs2).expect_err("a LEGACY-rule run verified under the TAG");
    eprintln!("STAGE 17 cross-rule refusal at the run: legacy run, tagged verifier: {e2}");
    assert!(!e2.is_empty());
}

// ---------------------- STAGE 18: the PUBLIC RUN STATEMENT beside the segments
//
// `run_statement_file.rs` retains the run's PUBLIC statement in
// `<run dir>/statement/run-statement.json` after the run has verified, so
// that a process that did not prove the run can rebuild the verifier's
// statement and check it. These tests are at the DEVELOPMENT RUNG, never at
// 125M: what they prove is that the file is SUFFICIENT and SELF-CHECKING, and
// three blocks show that exactly as well as twelve.

use super::run_statement_file::{self, TAME_FIXTURE};

/// Prove an honest tagged `l`-block rung-G run into a fresh directory and
/// retain its statement. Returns the temporary directory (which removes
/// itself), the statement's own size and the streaming verification's time.
fn a_run_with_its_statement(tag: &str, l: usize, zero: bool) -> (TempRunDir, run_statement_file::Written) {
    let sh = Shape::rung_g();
    let tmp = TempRunDir::new(tag);
    let mut c = Chain::honest(&sh, l, zero);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    prove_to_dir_and_memory(&st, &blocks, &mut c, owners, tmp.path()).expect("the honest run proves to a directory");
    let w = run_statement_file::verify_then_write(&st, &blocks, tmp.path(), &TAME_FIXTURE).expect("the run verifies and its statement is retained");
    (tmp, w)
}

/// **THE STATEMENT FILE IS SUFFICIENT.** A three-block tagged run is written
/// to a directory; then, from the FILES ON DISK plus this build's public
/// shape and weights recipe and nothing else, the verifier's statement is
/// rebuilt and the run is verified from its segments in a FRESH
/// `RunVerifier`. No value crosses over from the process that proved it —
/// `run_statement_file::read` opens one file, regenerates the public weights
/// from the named recipe, and recomputes every derived quantity.
///
/// This is the whole point of the file, and it is the test the integrator
/// asked for.
#[test]
fn a_run_is_rebuilt_from_its_statement_file_alone_and_verifies_in_a_fresh_verifier() {
    let (tmp, w) = a_run_with_its_statement("stmt", 3, false);
    // the file is beside the segments, not among them
    assert_eq!(w.path, tmp.path().join("statement").join("run-statement.json"), "the statement is not where it is documented to be");
    let names = run_sink::dir_entry_names(tmp.path()).expect("the run directory lists");
    assert_eq!(names, vec!["segment-000.bin".to_string(), "segment-001.bin".into(), "segment-002.bin".into(), "statement".into()], "the run directory holds {names:?}");
    // THE FRESH VERIFIER: the file and the recipe, and nothing else
    run_statement_file::verify_from_disk(tmp.path()).expect("the statement file alone does not rebuild a run that verifies");
    // and the rebuilt statement IS the one that proved: same binding
    let (st2, blocks2) = run_statement_file::read(tmp.path()).expect("the statement reads back");
    assert_eq!(blocks2.len(), 3, "the recipe gave {} blocks", blocks2.len());
    let h = st2.capture_header().expect("the rebuilt statement's header");
    assert_eq!(h.l, 3);
    eprintln!(
        "STAGE 18 RUN STATEMENT: {} B, sha256 {}, verify by streaming {:.2} s, run binding {}",
        w.bytes,
        w.sha256,
        w.verify_s,
        st2.binding().expect("the rebuilt binding").iter().map(|b| format!("{b:02x}")).collect::<String>()
    );
    assert!(w.bytes > 1500 && w.bytes < 200_000, "the statement file is {} B, which is not the size a run statement should be", w.bytes);
}

/// **ONE BYTE CHANGED IN AN ENDPOINT COMMITMENT IS REFUSED.** The file
/// recomputes everything it declares, so the altered root is caught by the
/// run binding it no longer matches — before a segment is opened, and by the
/// name of the quantity that moved. The same mutation in the run binding
/// itself, in a block digest and in a segment digest is refused too, each by
/// its own name.
#[test]
fn a_statement_file_with_one_byte_changed_is_refused() {
    let (tmp, _w) = a_run_with_its_statement("stmt-neg", 3, false);
    let path = run_statement_file::statement_path(tmp.path());
    let good = std::fs::read(&path).expect("the statement file reads");
    run_statement_file::verify_from_disk(tmp.path()).expect("the honest statement verifies");
    // flip the last hex digit of a named member's first hex string
    let flip = |what: &str, key: &str| -> String {
        let s = String::from_utf8(good.clone()).expect("the statement file is ASCII");
        let at = s.find(key).unwrap_or_else(|| panic!("{key} is not in the statement file"));
        let q = s[at..].find(':').expect("a key is followed by a colon") + at;
        let start = s[q..].find('"').expect("a hex value is quoted") + q + 1;
        let end = s[start..].find('"').expect("a hex value is quoted") + start;
        let mut b = good.clone();
        b[end - 1] = if b[end - 1] == b'0' { b'1' } else { b'0' };
        std::fs::write(&path, &b).expect("the test writes the statement file");
        let e = run_statement_file::verify_from_disk(tmp.path()).expect_err(&format!("{what} was ACCEPTED"));
        eprintln!("STAGE 18 statement refusal, {what}: {e}");
        std::fs::write(&path, &good).expect("the test restores the statement file");
        e
    };
    let e = flip("one byte of the external INPUT endpoint commitment", "\"input_root\"");
    assert!(e.contains("run binding"), "the refusal did not name the run binding: {e}");
    let e = flip("one byte of the external OUTPUT endpoint commitment", "\"output_root\"");
    assert!(e.contains("run binding"), "the refusal did not name the run binding: {e}");
    let e = flip("one byte of the declared run binding", "\"run_binding\"");
    assert!(e.contains("run binding"), "the refusal did not name the run binding: {e}");
    let e = flip("one byte of the declared endpoint policy bytes", "\"policy_bytes\"");
    assert!(e.contains("endpoint policy bytes"), "the refusal did not name the endpoint policy: {e}");
    let e = flip("one byte of a block's public digest", "\"block_digests\"");
    assert!(e.contains("block 0"), "the refusal did not name the block: {e}");
    let e = flip("one byte of the calibration identity", "\"calibration\"");
    assert!(e.contains("calibration"), "the refusal did not name the calibration: {e}");
    let e = flip("one byte of a boundary's statement digest", "\"statement_digest\"");
    assert!(e.contains("boundary 0"), "the refusal did not name the boundary: {e}");
    let e = flip("one byte of a segment's SHA-256", "\"sha256\"");
    assert!(e.contains("SHA-256"), "the refusal did not name the segment digest: {e}");
    // and the honest file still verifies: every refusal above was its mutation
    run_statement_file::verify_from_disk(tmp.path()).expect("the restored statement verifies");
}

/// **THE ALLOW LIST**, as a capture bundle has one. A retained file beside
/// the segments is PUBLISHING, so the writer may emit no key it has not
/// declared — and adding one to the list is the moment to ask whether the
/// quantity behind it is in the verifier's public statement.
#[test]
fn every_key_of_a_run_statement_is_on_the_allow_list() {
    let (tmp, _w) = a_run_with_its_statement("stmt-keys", 2, false);
    let bytes = std::fs::read(run_statement_file::statement_path(tmp.path())).expect("the statement file reads");
    let keys = super::run_capture::keys_of(&bytes);
    assert!(keys.len() > 40, "only {} keys were found; the scanner is not reading this file", keys.len());
    for k in &keys {
        assert!(run_statement_file::ALLOWED_KEYS.contains(&k.as_str()), "the statement file carries the key {k:?}, which is not on the allow list");
    }
    // and the allow list carries nothing the writer never emits, so the list
    // cannot drift into a wish list
    for a in run_statement_file::ALLOWED_KEYS {
        assert!(keys.iter().any(|k| k == a), "the allow list carries {a:?}, which this writer never emits");
    }
    // the file is valid JSON to a reader that is not this one: no key twice
    // in one object, no trailing byte (both are parser refusals)
    run_statement_file::json::parse(&bytes).expect("the statement file parses");
    eprintln!("STAGE 18 RUN STATEMENT: {} keys, all on the allow list of {}", keys.len(), run_statement_file::ALLOWED_KEYS.len());
}

/// **RULING D21: A FAILED RUN LEAVES NO STATEMENT FILE.** The only writer
/// verifies the whole run from its directory first and writes nothing if that
/// fails, so a corrupted segment leaves the directory exactly as it was —
/// no `statement/` directory at all.
#[test]
fn a_failed_run_leaves_no_statement_file() {
    let sh = Shape::rung_g();
    let l = 3usize;
    let tmp = TempRunDir::new("stmt-d21");
    let mut c = Chain::honest(&sh, l, false);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    let (_disk, mem, _stats) = prove_to_dir_and_memory(&st, &blocks, &mut c, owners, tmp.path()).expect("the honest run proves to a directory");
    // corrupt one byte in the middle of segment 1
    let mut bad = mem.segments()[1].clone();
    let at = bad.len() / 2;
    bad[at] ^= 1;
    std::fs::write(tmp.path().join(run_sink::segment_file_name(1)), &bad).expect("the test corrupts a segment file");
    let e = run_statement_file::verify_then_write(&st, &blocks, tmp.path(), &TAME_FIXTURE).expect_err("a statement was written for a run that did NOT verify");
    eprintln!("STAGE 18 D21: the corrupted run is refused and nothing is written: {e}");
    assert!(!tmp.path().join("statement").exists(), "a failed run left a statement directory");
    assert!(!run_statement_file::statement_path(tmp.path()).exists(), "a failed run left a statement file");
    let names = run_sink::dir_entry_names(tmp.path()).expect("the run directory lists");
    assert_eq!(names.len(), l, "the failed run left {names:?}");
    // and with the segment restored it verifies and the statement appears
    std::fs::write(tmp.path().join(run_sink::segment_file_name(1)), &mem.segments()[1]).expect("the test restores the segment file");
    run_statement_file::verify_then_write(&st, &blocks, tmp.path(), &TAME_FIXTURE).expect("the restored run verifies and its statement is retained");
    assert!(run_statement_file::statement_path(tmp.path()).exists(), "the restored run left no statement file");
}

/// **THE ONE ALLOWED ENTRY IS A NAME AND A KIND, AND NOTHING ELSE MOVED.**
/// `segment_paths` lets a run directory hold the `statement` DIRECTORY beside
/// its `L` segments; a FILE of that name, and every other foreign entry, is
/// still refused before a byte of any segment is read.
#[test]
fn the_run_directory_allows_the_statement_directory_and_nothing_else() {
    let (tmp, _w) = a_run_with_its_statement("stmt-dir", 2, false);
    let (st, blocks) = run_statement_file::read(tmp.path()).expect("the statement reads back");
    run::verify_run_from_dir(&st, &blocks, tmp.path()).expect("the run verifies with the statement directory present");
    // a foreign FILE is still refused, by name
    std::fs::write(tmp.path().join("notes.txt"), b"not a segment").expect("the test writes a foreign file");
    let e = run::verify_run_from_dir(&st, &blocks, tmp.path()).expect_err("a foreign file was accepted");
    assert!(e.contains("notes.txt"), "{e}");
    std::fs::remove_file(tmp.path().join("notes.txt")).expect("the test removes the foreign file");
    // and a FILE called `statement`, in a directory that has none, is refused
    let other = TempRunDir::new("stmt-file");
    std::fs::write(other.path().join("statement"), b"x").expect("the test writes a file called statement");
    let e = run_sink::segment_paths(other.path(), 2).expect_err("a FILE called statement was accepted");
    assert!(e.contains("a FILE called statement"), "{e}");
    run::verify_run_from_dir(&st, &blocks, tmp.path()).expect("the run still verifies");
}

/// **THE STATEMENT FILE'S OWN JSON READER IS STRICT.** It is a hundred lines
/// of hand-written parser in a crate with no JSON dependency, so what it
/// accepts and refuses is pinned here rather than assumed.
#[test]
fn the_statement_files_json_reader_is_strict() {
    use super::run_statement_file::json::{self, J};
    let ok = json::parse(br#"{"a":1,"b":[-2,3],"c":{"d":"x\ny"},"e":true,"f":false,"g":null}"#).expect("a well-formed value parses");
    assert_eq!(ok.get("a").expect("a").int().expect("an int"), 1);
    assert_eq!(ok.get("b").expect("b").ints().expect("ints"), vec![-2, 3]);
    assert_eq!(ok.get("c").expect("c").get("d").expect("d").str().expect("a string"), "x\ny");
    assert!(ok.get("e").expect("e").boolean().expect("a bool"));
    assert_eq!(*ok.get("g").expect("g"), J::Null);
    assert!(ok.get("h").is_err(), "a missing key must be an error");
    // whitespace between tokens is fine
    json::parse(b" { \"a\" : [ 1 , 2 ] } ").expect("whitespace parses");
    // and every one of these is refused
    for (what, src) in [
        ("a repeated key", &br#"{"a":1,"a":2}"#[..]),
        ("a trailing byte", &br#"{"a":1} x"#[..]),
        ("a trailing comma", &br#"{"a":1,}"#[..]),
        ("an unterminated object", &br#"{"a":1"#[..]),
        ("an unterminated string", &br#"{"a":"x"#[..]),
        ("a float", &br#"{"a":1.5}"#[..]),
        ("an exponent", &br#"{"a":1e3}"#[..]),
        // a `\u` escape, spelled with an escaped backslash so that the source
        // really does carry the two characters `\` and `u`
        ("a unicode escape", &b"{\"a\":\"\\u0041\"}"[..]),
        ("a bare word", &br#"{"a":yes}"#[..]),
        ("a single-quoted string", b"{'a':1}"),
        ("an empty input", b""),
    ] {
        assert!(json::parse(src).is_err(), "{what} was accepted");
    }
    // a digest is 64 lower-case hex characters and nothing else
    let d = json::parse(br#"{"x":"00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff","y":"00AA","z":3}"#).expect("parses");
    assert_eq!(d.get("x").expect("x").hex32().expect("a digest")[0], 0x00);
    assert_eq!(d.get("x").expect("x").hex32().expect("a digest")[31], 0xff);
    assert!(d.get("y").expect("y").hex32().is_err(), "a short/upper-case digest was accepted");
    assert!(d.get("z").expect("z").hex32().is_err(), "a number was read as a digest");
}

// ============================================================
// STAGE 22, item 1: a retained statement describes PUBLIC WEIGHTS ONLY
// ============================================================

/// Prove an honest tagged `l`-block rung-G run on the **FULLY DENSE run
/// recipe** into a fresh directory and retain its statement. The tame
/// harness above is `a_run_with_its_statement`; this is the same thing with
/// the recipe whose string is what stage 22 item 1 is about, and it is the
/// first time this lane writes a DENSE statement anywhere but the 125M
/// heavy run.
fn a_dense_run_with_its_statement(tag: &str, l: usize) -> (TempRunDir, run_statement_file::Written) {
    let sh = Shape::rung_g();
    let tmp = TempRunDir::new(tag);
    let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
    let blocks = blocks_from(&public, &ff, l);
    let mut c = Chain::from_parts(&sh, l, public, ff, x0);
    let (st, owners) = statement_of(&c, l, &blocks);
    prove_to_dir_and_memory(&st, &blocks, &mut c, owners, tmp.path()).expect("the honest fully dense run proves to a directory");
    let w = run_statement_file::verify_then_write(&st, &blocks, tmp.path(), &run_statement_file::DENSE_RUN_FIXTURE)
        .expect("the fully dense run verifies and its statement is retained");
    (tmp, w)
}

/// **STAGE 22 ITEM 1's ACCEPTANCE.** A retained run statement written on the
/// FULLY DENSE recipe
///
/// * names a recipe that passes the hidden-input deny-list, in both its
///   `recipe` and its `description`;
/// * carries the hidden input's seed NOWHERE in its bytes, in hex or in
///   decimal;
/// * still rebuilds the verifier's statement from the file alone,
///   regenerating the public weights from the recipe, and VERIFIES the run
///   in a fresh `RunVerifier` — which is the property the recipe field
///   exists for and the one a narrower string could have broken.
///
/// The tame statement is held to the same three, so the property is the
/// writer's and not one recipe's.
#[test]
fn a_retained_run_statement_regenerates_the_public_weights_and_names_no_hidden_input() {
    for (what, (tmp, w)) in [("FULLY DENSE", a_dense_run_with_its_statement("s22-dense-stmt", 3)), ("tame", a_run_with_its_statement("s22-tame-stmt", 3, false))] {
        let bytes = std::fs::read(&w.path).expect("the statement file reads");
        let text = String::from_utf8(bytes.clone()).expect("the statement file is ASCII");
        let j = run_statement_file::json::parse(&bytes).expect("the statement file parses");
        let pw = j.get("public_weights").expect("public_weights");
        let (recipe, description) = (pw.get("recipe").expect("recipe").str().expect("a string"), pw.get("description").expect("description").str().expect("a string"));
        for (field, s) in [("recipe", recipe), ("description", description)] {
            if let Some(t) = run_statement_file::hidden_input_token(s) {
                panic!("{what}: public_weights.{field} describes the hidden input (token {t:?}): {s:?}");
            }
        }
        // THE SEED ITSELF, in the whole file. The negative declaration
        // `not_in_this_file` legitimately contains the words "hidden
        // inputs", so the deny-list is applied to the recipe field and the
        // SEED is what is searched for over the whole text.
        for form in ["1dde4e17", "1DDE4E17", "2152243532620890113"] {
            assert!(!text.contains(form), "{what}: the statement file carries the hidden input's seed as {form:?}");
        }
        // and the file is still SUFFICIENT: the recipe regenerates the
        // public weights and a fresh verifier accepts the run
        run_statement_file::verify_from_disk(tmp.path()).expect("the statement file alone does not rebuild a run that verifies");
        let (_, blocks) = run_statement_file::read(tmp.path()).expect("the statement reads back");
        assert_eq!(blocks.len(), 3, "{what}: the recipe gave {} blocks", blocks.len());
        eprintln!("S22 STATEMENT [{what}]: {} B, sha256 {}, recipe passes the deny-list, fresh verifier OK", w.bytes, w.sha256);
    }
}

/// **THE PUBLIC WEIGHTS DID NOT MOVE — MEASURED AGAINST EVIDENCE WRITTEN
/// BEFORE STAGE 22.**
///
/// Splitting the stream could in principle have moved a weight. It did not,
/// and the proof is not this module's own arithmetic: the two run statements
/// this lane retained under `results/` — one on the tame fixture
/// (`m125-run-l12-tagged-run-statement.json`, stage 18) and one on the fully
/// dense recipe (`m125-run-l12-dense-run-statement.json`, the twelve-block
/// 125M run of 2026-09-20) — each carry twelve BLOCK DIGESTS absorbed by a
/// run header that was hashed before stage 22 existed. This build regenerates
/// the public weights from the recipe each file NAMES, at the 125M shape, and
/// the digests still match.
///
/// It is therefore also the test of the two LEGACY recipe names: those files
/// carry the stage-18 / stage-21 strings, and a build that could not read
/// them would have orphaned 484 MB of retained receipt.
#[test]
fn the_retained_125m_statements_still_regenerate_their_public_weights() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().expect("the crate has a parent").join("results").join("zk60_block125m_lane");
    let sh = Shape::m125();
    for (file, expect_legacy) in [("m125-run-l12-tagged-run-statement.json", super::run_statement_file::LEGACY_TAME_RECIPE_NAME), ("m125-run-l12-dense-run-statement.json", super::dense_tests::LEGACY_DENSE_RUN_RECIPE_NAME)] {
        let p = root.join(file);
        let bytes = std::fs::read(&p).unwrap_or_else(|e| panic!("{}: {e}", p.display()));
        let j = run_statement_file::json::parse(&bytes).expect("the retained statement parses");
        let recipe = j.get("public_weights").expect("public_weights").get("recipe").expect("recipe").str().expect("a string").to_string();
        assert_eq!(recipe, expect_legacy, "{file}: the retained statement's recipe string is not the pre-stage-22 one this test is about");
        // D65(1), finding F12: both files predate F12, so they name the RETIRED `/1` 125M profile (no run
        // under it verifies any more); what is checked here is only that their public weights regenerate
        let named = j.get("block_profile").expect("block_profile").str().expect("a string").to_string();
        assert_eq!(super::shape::pre_f12_successor(&named).as_deref(), Some(sh.profile), "{file}: not a (pre-F12) 125M statement: {named}");
        let blk = run_statement_file::recipe_block(&recipe, &sh).unwrap_or_else(|e| panic!("{file}: this build cannot read the retained recipe name: {e}"));
        let digests = j.get("block_digests").expect("block_digests").arr().expect("an array");
        assert_eq!(digests.len(), 12, "{file}: {} block digests", digests.len());
        for (k, d) in digests.iter().enumerate() {
            assert_eq!(
                d.hex32().expect("a digest"),
                blk.digest(),
                "{file}: block {k}'s public digest changed — the stage-22 stream split MOVED a public weight"
            );
        }
        eprintln!("S22 RETAINED STATEMENT {file}: all 12 block digests regenerate from the legacy recipe name, so the public weights are bit-identical");
    }
}

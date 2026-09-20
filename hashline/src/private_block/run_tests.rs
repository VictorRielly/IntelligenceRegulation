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
        let ids = Ids::new(sh).expect("the shape has a plane map");
        let mut inputs = Vec::with_capacity(l);
        let mut planes = Vec::with_capacity(l + 1);
        let mut x = if zero { vec![0i16; sh.tokens * sh.width] } else { tame };
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
fn counted_segment_bytes(sh: &Shape, l: usize, boundary_rows: usize) -> Vec<usize> {
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

/// **RULING M-4, both halves.** A run in which block `k+1` declares a
/// different input scale than block `k`'s output scale DOES NOT CONSTRUCT —
/// a boundary has one scale field and there is nowhere to put the second —
/// and a receipt made under one calibration identity is rejected under
/// another.
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
    let mut disk = DirSink::create(dir, st.rs.l)?;
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
/// else (finding U-6).
#[test]
fn the_twelve_block_125m_receipt_is_the_counted_484_100_736_bytes() {
    let sh = Shape::m125();
    let spec = super::boundary::BoundarySpec::new(run_context(), sh.t_pad, sh.d_pad, 0, 1, run::BOUNDARY_SITES, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows + 1)
        .expect("the 125M internal boundary statement");
    assert_eq!(spec.commitment_rows(), 38, "the 125M boundary is not the derived 38 rows");
    let want = counted_segment_bytes(&sh, 12, spec.commitment_rows());
    assert_eq!((want[0], want[1], want[11]), (40_033_336, 40_301_624, 41_051_160), "the three 125M segment lengths");
    assert_eq!(want.iter().sum::<usize>(), 484_100_736, "the twelve-block 125M receipt is not the counted figure");
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
#[test]
#[ignore]
fn private_run_125m_twelve_blocks() {
    let sh = Shape::m125();
    let l = 12usize;
    let dir = heavy_run_dir("HL_PB_RUN_DIR");
    eprintln!("125M RUN L=12: segments go to {}; {}", dir.display(), malloc_threshold_note());
    let t0 = std::time::Instant::now();
    let mut c = Chain::honest(&sh, l, false);
    eprintln!("125M RUN L=12: chain built ({l} witnesses, each dropped) in {:.2} s, high-water mark so far {:.2} GiB", t0.elapsed().as_secs_f64(), run::peak_rss_mib() / 1024.0);
    let blocks = blocks_of(&sh, l);
    let (st, owners) = statement_of(&c, l, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    assert_eq!(rows, 38, "the 125M boundary is not the counted 38 rows");
    let want = counted_segment_bytes(&sh, l, rows);
    assert_eq!(want.iter().sum::<usize>(), 484_100_736, "the counted receipt moved");
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
    let t2 = std::time::Instant::now();
    run::verify_run_from_dir(&st, &blocks, &dir).unwrap_or_else(|e| panic!("125M RUN L=12: the run did not verify by streaming: {e}"));
    let verify_s = t2.elapsed().as_secs_f64();
    for (k, (len, dg)) in disk.lengths().iter().zip(disk.digests()).enumerate() {
        eprintln!("125M RUN L=12: {} {len} B sha256 {dg}", run_sink::segment_file_name(k));
    }
    hwm_report("125M RUN L=12", &stats.hwm_mib);
    eprintln!(
        "125M RUN L=12 RESULT: prove {prove_s:.2} s ({:?} per block), verify by streaming {verify_s:.2} s, receipt {} B in {l} files (counted 484,100,736), peak RSS {:.2} GiB, {} — a CORRECTNESS result, not a privacy one",
        stats.prove_s.iter().map(|s| (s * 100.0).round() / 100.0).collect::<Vec<f64>>(),
        disk.total_bytes(),
        run::peak_rss_mib() / 1024.0,
        malloc_threshold_note()
    );
}

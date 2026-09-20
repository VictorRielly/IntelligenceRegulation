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

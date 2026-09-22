//! **THE D22 CONDITION-7 PRE-READ OF STAGE 36 — the reviewer's own tests.**
//!
//! This module exists ONLY on the review branch `zk60-private-block-125m-review`
//! and is no part of the lane's stage-36 delta. It was written by an
//! independent adversarial reviewer to test, by a different route from the
//! lane's own tests, the two claims the accepted toy privacy statement's
//! condition 7 turns on when the integrator merges that delta:
//!
//! 1. **the observer hook inside `protocol::check_opening_challenges` changes
//!    nothing that a caller can see** — not a returned challenge, not the
//!    verdict, not the number of draws, not the generator's end state — so
//!    that a test build and a production build agree on every value, and only
//!    on counting differ;
//! 2. **the endpoint replica's fidelity rests on `private_seam::prepare` as
//!    well as on `prepare_with_rng`**, which is the one source fact stage 36's
//!    own fidelity test does not assert (finding P36-3 of the pre-read).
//!
//! **THE CAPTURE RULE.** Nothing here prints a challenge, a seed, a stream
//! byte or a drawn value. The draw source is a PUBLIC fixture generator
//! (`ZkRng::new`, the legacy deterministic stream for public fixtures), its
//! values are compared in memory and never published, and what is printed is
//! counts and verdicts.

use super::draw_observer::{self, Verdict};
use super::protocol;
use crate::field::Fp2;
use crate::zk::ZkRng;

/// one drive of `check_opening_challenges` over a draw source we control
struct Run {
    /// every value the inner closure handed the function, in order (compared,
    /// never printed)
    values: Vec<(u64, u64)>,
    /// how many times the INNER closure was called — the ground truth the
    /// observer's own count is checked against
    calls: u64,
    res: Result<(), String>,
    /// the fixture generator's consumption at the end of the call
    consumed: u64,
}

/// Drive the production function with a deterministic public fixture stream,
/// optionally forcing the `zero_at`-th challenge to zero so that the refusal
/// exits are reached without touching production code.
fn one_run(groups: &[usize], rows: usize, prox: usize, zero_at: Option<usize>) -> Run {
    let mut rng = ZkRng::new(7, b"p36 pre-read: a public fixture stream");
    let mut values: Vec<(u64, u64)> = Vec::new();
    let mut calls = 0u64;
    let res = {
        let values = &mut values;
        let calls = &mut calls;
        let rng = &mut rng;
        protocol::check_opening_challenges(groups, rows, prox, || {
            let v = if Some(*calls as usize) == zero_at { Fp2::ZERO } else { rng.fp2() };
            *calls += 1;
            values.push((v.c0.0, v.c1.0));
            v
        })
    };
    let consumed = rng.consumed_bytes();
    Run { values, calls, res, consumed }
}

/// **THE HOOK IS INVISIBLE FROM OUTSIDE.** The same three calls, each made
/// twice — once with no observer session open and once with one open — and
/// compared on everything a caller can see: the sequence of challenges the
/// function consumed, the `Result` it returned (including the refusal string),
/// how many times the draw closure was called, and how many bytes the
/// generator had consumed when it returned.
///
/// The three cases are the function's three exits, so the comparison covers
/// every path the hook touches: an accepted call, a call refused inside the
/// group block (which short-circuits, so the draw count is itself a fact under
/// test), and a call refused on the proximity pair.
///
/// It also checks the observer's own numbers against the ground truth the test
/// holds independently: the closure's call count, and the split between group
/// and proximity draws that the geometry fixes.
#[test]
fn the_observer_changes_no_value_no_verdict_and_no_generator_state() {
    // (groups, rows, prox, zero_at, expected verdict, expected group draws)
    let cases: [(&[usize], usize, usize, Option<usize>, Verdict, u64); 3] = [
        (&[2, 3], 4, 1, None, Verdict::Accepted, 5),
        (&[2, 3], 4, 1, Some(3), Verdict::ZeroGroupMember, 4),
        (&[2], 2, 1, None, Verdict::DependentProximity, 2),
    ];
    for (groups, rows, prox, zero_at, want_verdict, want_group) in cases {
        let plain = one_run(groups, rows, prox, zero_at);
        let (watched, calls, total) = {
            let session = draw_observer::Session::open();
            let w = one_run(groups, rows, prox, zero_at);
            (w, session.calls(), session.total_draws())
        };

        assert_eq!(plain.values, watched.values, "{want_verdict:?}: the observer changed a challenge the function consumed");
        assert_eq!(plain.res, watched.res, "{want_verdict:?}: the observer changed the verdict or its message");
        assert_eq!(plain.calls, watched.calls, "{want_verdict:?}: the observer changed how many challenges the function drew");
        assert_eq!(plain.consumed, watched.consumed, "{want_verdict:?}: the observer changed the generator's end state");
        assert_eq!(plain.res.is_ok(), want_verdict == Verdict::Accepted, "{want_verdict:?}: the case did not reach the exit it was built for");

        // and the observer's numbers are the truth this test holds separately
        assert_eq!(calls.len(), 1, "{want_verdict:?}: one call was made and the observer recorded {} of them", calls.len());
        assert_eq!(total, watched.calls, "{want_verdict:?}: the observer counted {total} draws, the closure was called {} times", watched.calls);
        assert_eq!(calls[0].verdict, want_verdict, "{want_verdict:?}: the observer recorded a different exit");
        assert_eq!(calls[0].draws, watched.calls, "{want_verdict:?}: the recorded call's draw count is not the closure's call count");
        assert_eq!(calls[0].group_draws, want_group, "{want_verdict:?}: the group block's share of the draws moved");
        assert_eq!(calls[0].rho_draws(), watched.calls - want_group, "{want_verdict:?}: the proximity block's share does not complete the call");
        eprintln!("P36 hook: {want_verdict:?} — {} draws ({want_group} group + {} proximity), values and verdict identical with and without the observer", watched.calls, watched.calls - want_group);
    }
}

/// **A SESSION CARRIES NOTHING INTO THE NEXT ONE, AND AN UNWATCHED CALL
/// LEAVES NOTHING BEHIND.** Both are properties the lane's measurements rely
/// on without asserting: a stale record from an earlier call would be counted
/// into the next proof's 1,027 points.
#[test]
fn the_observer_leaks_no_record_across_sessions_or_out_of_an_unwatched_call() {
    {
        let session = draw_observer::Session::open();
        let _ = one_run(&[2, 3], 4, 1, None);
        assert_eq!(session.calls().len(), 1, "the watched call was not recorded");
    }
    // an UNWATCHED call between the two sessions
    let _ = one_run(&[2, 3], 4, 1, None);
    let session = draw_observer::Session::open();
    assert!(session.calls().is_empty(), "a new session inherited records from an earlier call");
    assert_eq!(session.total_draws(), 0, "a new session inherited a draw count");
    let _ = one_run(&[1], 2, 0, None);
    assert_eq!(session.calls().len(), 1, "the second session recorded the wrong number of calls");
    eprintln!("P36 session hygiene: records do not survive a session, and an unwatched call records nothing");
}

/// **THE GAP IN THE LANE'S REPLICA-FIDELITY TEST (finding P36-3), CLOSED
/// HERE.** Stage 36's `the_endpoint_replica_is_the_endpoint_preparers_own_
/// draw_sequence` pins `private_seam::prepare_with_rng` — the function that
/// DRAWS — and `endpoint_g::prepare`. It does not pin the frozen seam's
/// `prepare`, which is the function the production path actually calls and the
/// one that CONSTRUCTS the generator: a draw taken there, before the generator
/// is handed on, would add stream bytes to the real endpoint that the replica
/// would not see, and no test of the delta would notice.
///
/// Today it takes none. This test says so, so that the day it does, something
/// fails.
#[test]
fn the_frozen_seams_own_prepare_constructs_the_generator_and_draws_nothing_itself() {
    let body = fn_body(&source("src/private_seam.rs"), "pub fn prepare(");
    assert!(body.contains("ZkRng::from_os(DOMAIN)"), "the seam's `prepare` no longer makes its generator from OS entropy on the fixed domain");
    assert_eq!(body.matches("ZkRng::from_os").count(), 1, "the seam's `prepare` makes more than one generator");
    assert_eq!(body.matches("rng.").count(), 0, "the seam's `prepare` now DRAWS from the generator before handing it on; the endpoint replica no longer measures the endpoint");
    assert!(body.contains("prepare_with_rng(spec, side, values, ntt, &mut rng)"), "the seam's `prepare` no longer forwards its generator to `prepare_with_rng` unchanged");
    // and the same question of the generalised endpoint: its `prepare` both
    // makes the generator and draws, so the two uses stage 36 pins are the
    // whole of it only if there is no third
    let g = fn_body(&source("src/private_block/endpoint_g.rs"), "pub(crate) fn prepare(");
    assert_eq!(g.matches("ZkRng::from_os").count(), 1, "the generalised endpoint makes more than one generator");
    assert_eq!(g.matches("rng.").count(), 1, "the generalised endpoint uses its generator somewhere the replica does not");
    eprintln!("P36 replica fidelity, the half stage 36 does not assert: the frozen seam's `prepare` constructs the generator and draws nothing itself before forwarding it");
}

/// a source file of this crate, read at test time (the same route stage 25's
/// and stage 36's scans take)
fn source(rel: &str) -> String {
    let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(rel);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("cannot read {}: {e}", p.display()))
}

/// the body of a function, from its signature to the next item at column zero
fn fn_body(src: &str, signature: &str) -> String {
    let start = src.find(signature).unwrap_or_else(|| panic!("`{signature}` is gone"));
    let body = &src[start..];
    let end = body[1..].find("\n}\n").map(|i| i + 2).unwrap_or(body.len());
    body[..end].to_string()
}

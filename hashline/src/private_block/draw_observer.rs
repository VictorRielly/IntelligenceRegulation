//! **STAGE 36: the read-only TEST OBSERVER of the refusal replay**, the
//! third of the three the integrator authorised on 2026-09-22 at 07:25.
//!
//! **What was missing.** `protocol::check_opening_challenges` is where the
//! prover re-issues, off a discarded transcript clone, exactly the
//! challenges its own opening is about to draw, and tests it for the two
//! refusal conditions. Stage 23 pinned the ORDER of those evaluations by
//! driving the function from outside over a recorded partition, and said in
//! writing what it could not do: *"a session that wanted to observe the live
//! evaluation order would need a test-only observer inside
//! `protocol::check_opening_challenges` — a `#[cfg(test)] fn
//! observe(condition, draw_index)` beside the two refusals, called on every
//! evaluation and not only on a refusal. That is a PRODUCTION-FILE change
//! and ruling GS-2's instruction is not to add one."* The instruction has
//! been changed by the file's owner; this is that observer.
//!
//! **THE FOUR RULES IT IS BUILT UNDER.**
//!
//! 1. **No production call site.** Every line the hook adds to
//!    `protocol.rs` carries `#[cfg(test)]`, and so does this whole module
//!    (`private_block.rs` declares it under the same gate). A release build
//!    of the library compiles neither, so there is nothing to disable at
//!    run time and nothing to pay for.
//! 2. **Counts and verdicts, never values.** A record holds how many
//!    challenges the call drew, how many of them were group coefficients,
//!    and which of the three exits it took. No challenge, no coefficient,
//!    no determinant and no transcript state can be reached through it —
//!    the capture rule of this lane, applied to an observer that would
//!    otherwise be the easiest place in the code to leak one.
//! 3. **Off by default, and explicitly scoped.** The thread-local starts
//!    disabled; [`Session`] turns it on for the length of one measurement
//!    and off again on drop, even if the measurement panics. A test that
//!    never opens a session sees nothing and costs nothing, so the twenty-odd
//!    other tests that drive this function are unaffected.
//! 4. **Thread-local, deliberately.** The prover's openings happen on the
//!    thread that called it — the parallelism inside a commitment is below
//!    this level — so the records of one measurement are the records of one
//!    proof, and a second test running in parallel cannot mix its calls
//!    into them. The lane's filter runs `--test-threads=1` in any case.

use std::cell::RefCell;

/// How one call of `check_opening_challenges` ended. The three are its
/// three exits, and they are the whole vocabulary: no value of any kind
/// travels with them.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Verdict {
    /// a group member's coefficient was zero — the first refusal, taken
    /// before any proximity coefficient is drawn
    ZeroGroupMember,
    /// the proximity pair was degenerate (or the row geometry has no pair)
    /// — the second refusal
    DependentProximity,
    /// the whole partition was drawn and both conditions passed
    Accepted,
}

/// One call of `check_opening_challenges`, as counts.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) struct Call {
    /// challenges drawn while testing the group members' coefficients
    pub(super) group_draws: u64,
    /// challenges drawn by the call in total — the group block plus, when
    /// the group block passed, the `rows` proximity coefficients
    pub(super) draws: u64,
    pub(super) verdict: Verdict,
}

impl Call {
    /// the proximity coefficients this call drew (`rows` on an accepted
    /// call, zero on one refused in the group block)
    pub(super) fn rho_draws(&self) -> u64 {
        self.draws - self.group_draws
    }
}

#[derive(Default)]
struct State {
    on: bool,
    draws: u64,
    group_draws: u64,
    calls: Vec<Call>,
}

thread_local! {
    static OBS: RefCell<State> = RefCell::new(State::default());
}

/// A measurement window. While one is alive the observer records; when it
/// is dropped the observer is off again and its records are cleared, so a
/// panicking measurement cannot leave the next test observing.
pub(super) struct Session;

impl Session {
    /// Open a window. Records start empty.
    pub(super) fn open() -> Session {
        OBS.with(|o| {
            let mut s = o.borrow_mut();
            assert!(!s.on, "draw_observer: a session is already open on this thread");
            *s = State { on: true, ..State::default() };
        });
        Session
    }

    /// The calls recorded so far, in the order they were made.
    pub(super) fn calls(&self) -> Vec<Call> {
        OBS.with(|o| o.borrow().calls.clone())
    }

    /// Every recorded call's total draw count, summed — the number of
    /// challenge points the refusal replay re-issued inside this window.
    pub(super) fn total_draws(&self) -> u64 {
        OBS.with(|o| o.borrow().calls.iter().map(|c| c.draws).sum())
    }
}

impl Drop for Session {
    fn drop(&mut self) {
        OBS.with(|o| *o.borrow_mut() = State::default());
    }
}

/// Wrap a draw closure so that each challenge it produces is COUNTED. The
/// value passes through untouched and is never looked at.
///
/// This is the shape the hook takes in `protocol.rs`: one `#[cfg(test)]`
/// `let` that shadows the closure parameter. The body below it is not
/// restructured by a single character, which is what makes the
/// production-identity claim checkable by reading the diff.
///
/// It takes the closure by `&mut` rather than by value so that the hook's
/// one line USES the parameter's `mut` — a wrapper that moved it would
/// leave `mut draw` unused mutably and the test build would gain an
/// `unused_mut` warning the production build does not have.
pub(super) fn counting<'a, F: FnMut() -> crate::field::Fp2>(inner: &'a mut F) -> impl FnMut() -> crate::field::Fp2 + 'a {
    move || {
        OBS.with(|o| {
            let mut s = o.borrow_mut();
            if s.on {
                s.draws += 1;
            }
        });
        inner()
    }
}

/// The group block passed: every member's coefficient was tested and none
/// was zero. Recorded rather than inferred, so that the split between the
/// group block and the proximity block is the code's and not the test's.
pub(super) fn note_groups_passed() {
    OBS.with(|o| {
        let mut s = o.borrow_mut();
        if s.on {
            s.group_draws = s.draws;
        }
    });
}

/// One of the three exits was taken: close the call.
pub(super) fn note_verdict(verdict: Verdict) {
    OBS.with(|o| {
        let mut s = o.borrow_mut();
        if !s.on {
            return;
        }
        let group_draws = match verdict {
            // refused inside the group block: everything drawn was a group
            // coefficient and no proximity coefficient exists
            Verdict::ZeroGroupMember => s.draws,
            _ => s.group_draws,
        };
        let call = Call { group_draws, draws: s.draws, verdict };
        s.calls.push(call);
        s.draws = 0;
        s.group_draws = 0;
    });
}

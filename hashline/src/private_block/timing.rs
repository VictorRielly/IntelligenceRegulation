//! **STAGE 11: THE PHASE CLOCK — where the seconds of one block go.**
//!
//! One block at the 125M shape proves in 26.89 s (one run, shared box,
//! 2026-09-20). Nobody knew WHICH PART of the block those seconds belong to,
//! and the open design question P5 — whether a two-prover design that keeps
//! the feed-forward half on a GPU is worth building — was answered only by a
//! COUNT of committed rows (about 20% feed-forward, "10-17%" saved on paper).
//! This module replaces the count with a measurement.
//!
//! **WHAT IT MAY RECORD, AND WHAT IT MAY NOT.** Durations, byte counts, row
//! counts, cube sizes, the process's own `VmRSS` / `VmHWM`, and the slot names
//! that are already public constants of the schedule. NEVER a witness value, a
//! salt, a pad, a private plane, a challenge, a claimed sum or a terminal. The
//! sizes it prints are functions of the SHAPE alone, which is public and is in
//! the transcript's parameter line already.
//!
//! **IT CANNOT INFLUENCE A PROOF.** [`Phases`] is write-only from the
//! protocol's point of view: `mark` and `slot` push a row onto a private
//! vector and return `()`, and no branch of `protocol.rs`, `argument.rs` or
//! any other lane file reads the recorder back. Nothing in it touches the
//! transcript, the randomness stream or any committed buffer. With
//! `HL_PB_TIMING` unset every method returns on its first line, allocating
//! nothing (`Vec::new` does not allocate) and not even reading the clock, so
//! the proving path is the path it was before this module existed.
//!
//! **A TIMING RUN IS A DIAGNOSTIC, NOT A RECEIPT.** Wall clocks on a shared
//! box vary by a factor of two run to run (the project's own measured figure),
//! and a phase table is worth what one run is worth.
//!
//! Switched on with `HL_PB_TIMING=1`, in the house style of `HL_TIMING` in
//! `pcs.rs` and `zk.rs` (read fresh at every call and never memoised in a
//! `OnceLock`, so a test can turn it on for one proof and off for the next).

use super::layout::{N_SLOTS, SLOT_NAMES};
use std::time::Instant;

/// the switch
pub(crate) const ENV: &str = "HL_PB_TIMING";

// **TEST-ONLY.** Force the switch on or off for THIS THREAD. The stage 11
// parity gate has to prove with the clock ON and verify with it OFF inside
// one test, and `std::env::set_var` is not thread-safe: it would race every
// other test that reads the variable whenever the suite runs with more than
// one thread. Same shape and same discipline as
// `protocol::set_moved_multiplicity` — `None` restores the environment
// variable's own answer, and a test MUST clear it before it returns. The
// state, the setter and the branch that reads it all vanish from a release
// build.
#[cfg(test)]
thread_local! {
    static FORCE: std::cell::Cell<Option<bool>> = const { std::cell::Cell::new(None) };
}

/// set or clear the test-only thread-local override above
#[cfg(test)]
pub(crate) fn force(v: Option<bool>) {
    FORCE.with(|c| c.set(v));
}

/// Read FRESH every time: a `OnceLock` would make the on/off parity test of
/// stage 11 unwritable, and the cost is one environment lookup per proof.
pub(crate) fn enabled() -> bool {
    #[cfg(test)]
    {
        if let Some(v) = FORCE.with(|c| c.get()) {
            return v;
        }
    }
    std::env::var(ENV).map(|v| v == "1").unwrap_or(false)
}

/// **WHICH HALF OF THE BLOCK A PHASE BELONGS TO.** The six block halves are
/// read off the layout's own slot definitions (`argument::define`), and the
/// four remaining labels are the phases that are not a slot at all.
#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum Half {
    /// layout, plane maps, NTT tables, endpoint checks
    Setup,
    /// building and committing `A`, `M`, `H`
    Commit,
    /// the two RMS norms: their row sums, their squares, their limbs
    Norm,
    /// QKV, RoPE, scores, softmax, PV, the output projection
    Attn,
    /// the gate, up and down matmuls and the f-cube zero-check
    Ff,
    /// the `Dom::D` zero-check: both residual adds, the int16 classes, and the
    /// two matmul host terms that ride with them
    Residual,
    /// the three byte tables and the zero-sum row
    Lookup,
    /// the two external endpoint equality slots
    Endpoint,
    /// the `M`, `A`, `H` and endpoint openings (prover) or verifications
    Open,
    /// the wire frame: encode on the prover's side, decode on the verifier's
    Frame,
}

impl Half {
    pub(crate) fn label(self) -> &'static str {
        match self {
            Half::Setup => "setup",
            Half::Commit => "commit",
            Half::Norm => "norm",
            Half::Attn => "attention",
            Half::Ff => "feed-forward",
            Half::Residual => "residual",
            Half::Lookup => "lookup-table",
            Half::Endpoint => "endpoints",
            Half::Open => "openings",
            Half::Frame => "frame",
        }
    }
}

const HALVES: [Half; 10] = [Half::Setup, Half::Commit, Half::Norm, Half::Attn, Half::Ff, Half::Residual, Half::Lookup, Half::Endpoint, Half::Open, Half::Frame];

/// **THE SLOT-TO-HALF CLASSIFICATION, from the layout's own slot definitions.**
/// Indexed by the slot constants of `layout.rs` (`SC_SS` = 0 … `SC_IO_OUT` =
/// 22); the lane ledger's stage 11 carries the same table in words with the
/// reason for each line.
///
/// * `SC_SS`, `SC_SSM`, `SC_TZC`, `SC_LZC` — the two RMS norms (`norm_a`
///   before attention, `norm_m` before the feed-forward): their row sums,
///   their reciprocal squares and the byte limbs of both. NORM.
/// * `SC_RS`, `SC_QMM`, `SC_KMM`, `SC_VMM`, `SC_SCORE`, `SC_PV`, `SC_WO`,
///   `SC_QZC`, `SC_KVZC`, `SC_SZC` — the query / key / value projections and
///   their RoPE zero-checks, the score and PV bilinear matmuls, the softmax
///   row sums and its zero-check, and the output projection. ATTENTION.
/// * `SC_GMM`, `SC_UMM`, `SC_DMM`, `SC_FZC` — the gate, up and down matmuls
///   and the f-cube zero-check that hosts the first two. FEED-FORWARD.
/// * `SC_DZC` — the `Dom::D` zero-check. It is the one MIXED slot: it carries
///   both residual adds (`x1 = x + ao`, `x2 = x1 + z16`), the int16 classes of
///   all four width planes, BOTH norm relations, and it hosts one attention
///   matmul (`SC_WO`) and one feed-forward matmul (`SC_DMM`). It is counted as
///   RESIDUAL and never split, because no part of its single sumcheck can be
///   attributed to one half without re-deriving the slot.
/// * `SC_TAB`, `SC_ZS` — the three public byte tables' helper relations and
///   the zero-sum row. LOOKUP-TABLE.
/// * `SC_IO_IN`, `SC_IO_OUT` — the two external endpoint equalities. ENDPOINTS.
pub(crate) const SLOT_HALF: [Half; N_SLOTS] = [
    Half::Norm,     // 00 SC_SS    row sums, norm_a
    Half::Norm,     // 01 SC_SSM   row sums, norm_m
    Half::Norm,     // 02 SC_TZC   norm squares zero-check (hosts 00, 01)
    Half::Norm,     // 03 SC_LZC   norm limb zero-check
    Half::Attn,     // 04 SC_RS    masked softmax row sums + selector
    Half::Attn,     // 05 SC_QMM   query projection
    Half::Attn,     // 06 SC_KMM   key projection
    Half::Attn,     // 07 SC_VMM   value projection
    Half::Attn,     // 08 SC_SCORE score matmul (bilinear)
    Half::Attn,     // 09 SC_PV    PV matmul (bilinear)
    Half::Attn,     // 10 SC_WO    output projection
    Half::Ff,       // 11 SC_GMM   gate matmul
    Half::Ff,       // 12 SC_UMM   up matmul
    Half::Ff,       // 13 SC_DMM   down matmul
    Half::Residual, // 14 SC_DZC   D zero-check: residual 1 and 2, int16 classes, hosts 10 and 13
    Half::Attn,     // 15 SC_QZC   Q zero-check: RoPE (hosts 05, 09)
    Half::Attn,     // 16 SC_KVZC  KV zero-check: RoPE (hosts 06, 07)
    Half::Attn,     // 17 SC_SZC   softmax zero-check (hosts 04, 08)
    Half::Ff,       // 18 SC_FZC   F zero-check: activation pair (hosts 11, 12)
    Half::Lookup,   // 19 SC_TAB   the three byte tables' helper relations
    Half::Lookup,   // 20 SC_ZS    the zero-sum row
    Half::Endpoint, // 21 SC_IO_IN  input endpoint equality
    Half::Endpoint, // 22 SC_IO_OUT output endpoint equality
];

/// Process resident memory and its high-water mark, in MiB, from Linux
/// `/proc/self/status`. Whole-process figures: they BOUND a phase's cost from
/// above and are not a measurement of it. `NaN` where the file cannot be read
/// (the recorder never fails a proof over a missing `/proc`).
fn mem_mib() -> (f64, f64) {
    let Ok(s) = std::fs::read_to_string("/proc/self/status") else { return (f64::NAN, f64::NAN) };
    let field = |k: &str| -> f64 {
        s.lines()
            .find(|l| l.starts_with(k))
            .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<f64>().ok()))
            .map(|kb| kb / 1024.0)
            .unwrap_or(f64::NAN)
    };
    (field("VmRSS:"), field("VmHWM:"))
}

struct Row {
    label: &'static str,
    /// the slot index, for a row that is one slot of the argument
    slot: Option<usize>,
    half: Half,
    secs: f64,
    /// the counted figure this phase's seconds should be set against
    size: u64,
    unit: &'static str,
    rss: f64,
    hwm: f64,
}

/// The recorder. Inert unless `HL_PB_TIMING=1`.
pub(crate) struct Phases {
    on: bool,
    t0: Instant,
    tick: Instant,
    rows: Vec<Row>,
}

impl Phases {
    /// Start a recorder. Off: two clock reads and an empty `Vec`, which does
    /// not allocate.
    pub(crate) fn start() -> Phases {
        let now = Instant::now();
        Phases { on: enabled(), t0: now, tick: now, rows: Vec::new() }
    }

    // There is deliberately NO accessor for `on`: nothing outside this module
    // may ask whether timing is on, so no branch of the protocol can depend on
    // it. The compiler enforces it — an unused-method warning is what told the
    // author the first draft had one.

    /// Close the phase that ended here. `size` and `unit` are the counted
    /// figure the phase's seconds are to be read against (committed rows, a
    /// sumcheck cube, a word count); both are functions of the shape.
    pub(crate) fn mark(&mut self, half: Half, label: &'static str, size: u64, unit: &'static str) {
        if !self.on {
            return;
        }
        self.push(half, label, None, size, unit);
    }

    /// The same for one slot of the argument, labelled by the schedule's own
    /// public name and classified by [`SLOT_HALF`].
    pub(crate) fn slot(&mut self, s: usize, size: u64, unit: &'static str) {
        if !self.on || s >= N_SLOTS {
            return;
        }
        self.push(SLOT_HALF[s], SLOT_NAMES[s], Some(s), size, unit);
    }

    fn push(&mut self, half: Half, label: &'static str, slot: Option<usize>, size: u64, unit: &'static str) {
        let secs = self.tick.elapsed().as_secs_f64();
        let (rss, hwm) = mem_mib();
        self.rows.push(Row { label, slot, half, secs, size, unit, rss, hwm });
        // the clock restarts AFTER the `/proc` read, so the reading's own cost
        // lands in no phase
        self.tick = Instant::now();
    }

    /// The whole table: one line per phase, then the per-half totals, then the
    /// three-way split the P5 question asks for. `side` is `"prove"` or
    /// `"verify"`; `profile` is the shape's public name. Prints nothing when
    /// the switch is off.
    pub(crate) fn report(&self, side: &str, profile: &str) {
        if !self.on {
            return;
        }
        let wall = self.t0.elapsed().as_secs_f64();
        let sum: f64 = self.rows.iter().map(|r| r.secs).sum();
        let pct = |s: f64| if wall > 0.0 { 100.0 * s / wall } else { 0.0 };
        println!("PB-TIMING {side} [{profile}] {} phases, wall {wall:.3} s ({ENV}=1; diagnostics on a shared box, not a receipt)", self.rows.len());
        println!("PB-TIMING {side} | {:<44} | {:<12} | {:>8} | {:>6} | {:>14} | {:>9} | {:>9} |", "phase", "half", "seconds", "% wall", "size", "RSS MiB", "HWM MiB");
        for r in &self.rows {
            let name = match r.slot {
                Some(s) => format!("slot {s:02} {}", r.label),
                None => r.label.to_string(),
            };
            let size = format!("{} {}", r.size, r.unit);
            println!("PB-TIMING {side} | {:<44} | {:<12} | {:>8.3} | {:>5.1}% | {:>14} | {:>9.0} | {:>9.0} |", name, r.half.label(), r.secs, pct(r.secs), size, r.rss, r.hwm);
        }
        println!("PB-TIMING {side} | {:<44} | {:<12} | {:>8.3} | {:>5.1}% |", "SUM OF PHASES", "", sum, pct(sum));
        println!("PB-TIMING {side} | {:<44} | {:<12} | {:>8.3} | {:>5.1}% |", "WALL CLOCK OF THE CALL", "", wall, 100.0);
        println!("PB-TIMING {side} | {:<44} | {:<12} | {:>8.3} | {:>5.1}% |", "unaccounted (wall - sum)", "", wall - sum, pct(wall - sum));
        for h in HALVES {
            let (s, n) = self.rows.iter().filter(|r| r.half == h).fold((0.0f64, 0usize), |(s, n), r| (s + r.secs, n + 1));
            if n > 0 {
                println!("PB-TIMING {side} HALF {:<14} {s:>8.3} s  {:>5.1}%  ({n} phases)", h.label(), pct(s));
            }
        }
        let half_secs = |h: Half| -> f64 { self.rows.iter().filter(|r| r.half == h).map(|r| r.secs).sum() };
        let (a, f) = (half_secs(Half::Attn), half_secs(Half::Ff));
        let rest = sum - a - f;
        println!("PB-TIMING {side} SPLIT attention {a:.3} s ({:.1}%) | feed-forward {f:.3} s ({:.1}%) | the rest {rest:.3} s ({:.1}%) — of the {wall:.3} s wall", pct(a), pct(f), pct(rest));
        let mixed = self.rows.iter().filter(|r| r.slot == Some(14)).map(|r| r.secs).sum::<f64>();
        println!("PB-TIMING {side} NOTE slot 14 (D zero-check) is the one MIXED slot — {mixed:.3} s ({:.1}%) counted under 'residual', hosting one attention and one feed-forward matmul", pct(mixed));
    }
}

/// **STAGE 28 — attribution INSIDE one slot.** The 42-row table gives a slot
/// one line on purpose; this splits that line into the steps the prover
/// actually takes (building the slot's tables, the claimed sum, the masked
/// sumcheck body, the extension rounds), so a slot's seconds can be split
/// between the code this lane owns and the code it does not.
///
/// It prints and records nothing else: a label, a duration, and a PUBLIC
/// count (a cube, a table count) — the same rule as the rest of this module.
/// With the clock off it is `f()` and nothing else: no clock read, no print.
pub(crate) fn slot_step<T>(slot: usize, label: &str, size: u64, f: impl FnOnce() -> T) -> T {
    if !enabled() {
        return f();
    }
    let t = Instant::now();
    let out = f();
    let secs = t.elapsed().as_secs_f64();
    println!("PB-SLOTSTEP slot {slot:02} | {label:<34} | {secs:>8.3} s | {size:>12} |");
    out
}

/// Time one call that happens OUTSIDE a [`Phases`] recorder's scope — the wire
/// encode on the prover's side and the wire decode on the verifier's — and
/// print one line for it. Off: `f()` and nothing else.
pub(crate) fn timed<T>(side: &str, label: &str, size: u64, unit: &str, f: impl FnOnce() -> T) -> T {
    if !enabled() {
        return f();
    }
    let t = Instant::now();
    let out = f();
    let secs = t.elapsed().as_secs_f64();
    let (rss, hwm) = mem_mib();
    println!("PB-TIMING {side} | {label:<44} | {:<12} | {secs:>8.3} | {:>6} | {size:>8} {unit:<5} | {rss:>9.0} | {hwm:>9.0} |", Half::Frame.label(), "");
    out
}

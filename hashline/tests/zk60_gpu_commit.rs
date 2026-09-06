//! [ZK60-CL1] The chunked HIDING commitment against the CPU oracle.
//!
//! Run with `cargo test --release --features gpu-cuda --test zk60_gpu_commit`.
//!
//! [ZK60 round-7 review] This file no longer compiles to NOTHING without the
//! feature. `gpu_required_gate_refuses_a_build_without_the_feature` below is
//! compiled in every configuration, and under `HL_GPU_REQUIRED=1` it FAILS a
//! binary built without `gpu-cuda` — before, such a run compiled every device
//! test away and reported success. With the feature but no usable device
//! every test SKIPS loudly (and fails under `HL_GPU_REQUIRED=1`) rather than
//! passing vacuously — a green run on a box with no GPU must not be mistaken
//! for evidence.
//!
//! Each case compares BOTH halves against the CPU's own `encode_row_zk`, not
//! against the device's resident path, so a bug shared by the two device
//! paths could not hide:
//!   * the chunked commitment's column leaves, and
//!   * the chunked, pad/coset-aware OPENING columns —
//! the second being the half `columns_chunked` cannot serve, because it
//! re-encodes with neither the pads nor the coset scaling.

/// [ZK60 round-7 review] Compiled WITH and WITHOUT the feature. Asking for a
/// GPU-required run of a binary built without `gpu-cuda` is a FAILURE with a
/// visible reason, not a vacuous pass. Without the requirement it prints the
/// same machine-readable summary the device tests print, with zero cases, so
/// a gate script can see that nothing ran rather than infer it from silence.
#[test]
fn gpu_required_gate_refuses_a_build_without_the_feature() {
    let required = std::env::var("HL_GPU_REQUIRED").map(|v| v != "0").unwrap_or(false);
    if !cfg!(feature = "gpu-cuda") {
        println!(
            "ZK60_CL4_SUMMARY {{\"executed_cases\":0,\"gpu_enabled\":false,\"gpu_required\":{required},\"device\":\"built without --features gpu-cuda\"}}"
        );
        assert!(
            !required,
            "HL_GPU_REQUIRED=1 but this test binary was built WITHOUT --features gpu-cuda: every \
             device test was compiled away, so a green result would be vacuous. Build with \
             CARGO_TARGET_DIR=hashline/target-gpu and --features gpu-cuda."
        );
    }
}

#[cfg(feature = "gpu-cuda")]
mod device {

use hashline::gpu;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Mutex, MutexGuard, OnceLock};

/// The allocation cap and chunk-mode hooks are PROCESS-GLOBAL, and Rust runs
/// tests in parallel threads. Without this, a strict-mode test's injected cap
/// makes every concurrently-running test fail — which is exactly what happened
/// the first time this file was run. Every test takes the lock.

/// [ZK60-CL4] A GPU-required gate. Returning `true` from a skip is how a
/// suite reports a vacuous success: on a box with no device every test here
/// printed SKIP and PASSED, so "6 passed" meant nothing at all. Under
/// `HL_GPU_REQUIRED=1` a missing feature or device is a FAILURE.
///
/// `EXECUTED_CASES` then proves the run was not vacuous in the other
/// direction either: a device can be present while zero cases actually ran.
static EXECUTED_CASES: AtomicUsize = AtomicUsize::new(0);

fn gpu_required() -> bool {
    std::env::var("HL_GPU_REQUIRED").map(|v| v != "0").unwrap_or(false)
}

/// true = run the case. Panics instead of skipping when a GPU is required.
fn gpu_ready() -> bool {
    if gpu::enabled() {
        return true;
    }
    if gpu_required() {
        panic!(
            "HL_GPU_REQUIRED=1 but no usable device: {}. A skipped GPU case must FAIL this \
             gate, not report success.",
            gpu::label()
        );
    }
    eprintln!("SKIP (no device: {}) — set HL_GPU_REQUIRED=1 to make this a failure", gpu::label());
    false
}

fn note_case() {
    EXECUTED_CASES.fetch_add(1, Ordering::SeqCst);
}

/// Machine-readable summary for the gate script.
fn emit_summary() {
    println!(
        "ZK60_CL4_SUMMARY {{\"executed_cases\":{},\"gpu_enabled\":{},\"gpu_required\":{},\"device\":\"{}\"}}",
        EXECUTED_CASES.load(Ordering::SeqCst), gpu::enabled(), gpu_required(), gpu::label()
    );
}

fn serial() -> MutexGuard<'static, ()> {
    static L: OnceLock<Mutex<()>> = OnceLock::new();
    let m = L.get_or_init(|| Mutex::new(()));
    m.lock().unwrap_or_else(|e| e.into_inner())
}

/// `(0, 0)` or the test fails with the shape printed.
fn check(log_cols: u32, inv_rate: usize, rows: usize, q_pad: usize, chunk: usize) {
    if !gpu_ready() {
        return;
    }
    note_case();
    match gpu::dev_commit_zk_check_chunked(log_cols, inv_rate, rows, q_pad, chunk, false) {
        Ok((bad_leaves, bad_cols)) => assert_eq!(
            (bad_leaves, bad_cols),
            (0, 0),
            "chunked ZK commit mismatch at log_cols {log_cols}, inv_rate {inv_rate}, rows {rows}, q_pad {q_pad}, chunk {chunk}"
        ),
        Err(e) => panic!("chunked ZK commit failed at log_cols {log_cols}, inv_rate {inv_rate}, rows {rows}, q_pad {q_pad}, chunk {chunk}: {e}"),
    }
}

/// Every supported encoding rate, at a shape that really splits into chunks.
#[test]
fn zk_chunked_matches_cpu_at_every_rate() {
    let _g = serial();
    for &inv_rate in &[2usize, 4, 8] {
        check(10, inv_rate, 300, 16, 128);
    }
}

/// Row counts that are not multiples of the chunk step, so the LAST chunk is
/// short — the case that breaks a naive streaming hash.
#[test]
fn zk_chunked_matches_cpu_at_ragged_row_counts() {
    let _g = serial();
    for &rows in &[129usize, 255, 256, 257, 384, 400] {
        check(10, 4, rows, 16, 128);
    }
}

/// A single chunk must agree with the resident construction too: `rows <=
/// chunk` is the degenerate plan, and it is the one a small gate exercises.
#[test]
fn zk_chunked_matches_cpu_in_one_chunk() {
    let _g = serial();
    check(10, 4, 64, 16, 128);
    check(10, 4, 128, 16, 128);
}

/// Varied pad counts. `q_pad` sets how many hiding symbols ride each row, so
/// it moves the pad slice the chunk loop takes; `n + q <= nn` bounds it.
#[test]
fn zk_chunked_matches_cpu_at_varied_pad_counts() {
    let _g = serial();
    for &q_pad in &[1usize, 16, 64, 256] {
        check(10, 4, 300, q_pad, 128);
    }
}

/// Wider rows, where a chunk's encoded scratch is the thing being bounded.
#[test]
fn zk_chunked_matches_cpu_at_wider_shapes() {
    let _g = serial();
    check(12, 4, 300, 16, 128);
    check(14, 2, 200, 256, 128);
}

/// THE NEGATIVE CONTROL. Open the same hiding commitment with the non-ZK
/// `columns_chunked`, which re-encodes with neither the pads nor the coset
/// scaling. A correct build MUST disagree with the CPU almost everywhere; if
/// this ever passes as "0 bad", the positive tests above prove nothing,
/// because it would mean the oracle cannot tell the two apart.
#[test]
fn plain_reencode_of_a_hiding_commitment_is_detected_as_wrong() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    note_case();
    let (rows, q_pad) = (300usize, 16usize);
    let (bad_leaves, bad_cols) =
        gpu::dev_commit_zk_check_chunked(10, 4, rows, q_pad, 128, true).expect("negative control ran");
    // The COMMITMENT is still the chunked hiding one, so its leaves stay right;
    // only the opening is wrong. That split is itself the diagnosis.
    assert_eq!(bad_leaves, 0, "the chunked hiding leaves should be correct even in the negative control");
    assert!(
        bad_cols > rows,
        "the plain re-encode of a hiding commitment must disagree with the CPU in far more than {rows} entries, got {bad_cols} — the oracle is not discriminating"
    );
}

// ---------------------------------------------------------------------------
// [ZK60-CL2] The CL1 integration review's findings, turned into tests.
// Those findings were reached by SOURCE INSPECTION with no GPU reproduction,
// so each one gets a test that actually executes the path.
// ---------------------------------------------------------------------------

/// FINDING: `ensure_twiddles` replaced the tables whenever `max_log` DIFFERED,
/// so a smaller later commitment shrank them out from under an earlier
/// commitment's deferred opening. A resident commitment never cared (it opens
/// by gathering a retained `enc`); a chunked one re-encodes.
///
/// This proves the monotonic-cache invariant WITHOUT a device, against the
/// real layout function: the stage-major table for a larger `max_log` is a
/// strict prefix-extension of the one for a smaller `max_log`, entry for
/// entry. That is why keeping the largest tables is correct and not merely
/// convenient — a bigger table computes a smaller transform exactly.
#[test]
fn stage_major_twiddles_are_a_prefix_extension() {
    let _g = serial();
    for &(small, big) in &[(8u32, 10u32), (10, 12), (12, 16), (14, 16)] {
        let (fs, is) = gpu::stage_major_twiddles_for_test(small);
        let (fb, ib) = gpu::stage_major_twiddles_for_test(big);
        assert_eq!(fs.len(), (1usize << small) - 1, "forward length at max_log {small}");
        assert_eq!(fb.len(), (1usize << big) - 1, "forward length at max_log {big}");
        assert_eq!(
            fb[..fs.len()], fs[..],
            "forward stage-major table at max_log {big} is not a prefix-extension of {small}"
        );
        assert_eq!(
            ib[..is.len()], is[..],
            "inverse stage-major table at max_log {big} is not a prefix-extension of {small}"
        );
    }
}

/// FINDING: large commitment -> smaller-profile commitment -> open the
/// ORIGINAL. Before the monotonic fix the second commit shrank the tables and
/// the first commitment's opening could no longer run. Descending `log_cols`
/// is the ordering that triggers it; the openings all happen after every
/// commit, and each is repeated, per the review's "repeated openings".
#[test]
fn deferred_openings_survive_a_later_smaller_commitment() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    note_case();
    // descending width: the later, smaller tables must not strand the first
    let specs = [(14u32, 4usize, 200usize, 16usize), (10, 4, 300, 16), (8, 4, 200, 16)];
    let (bad_leaves, bad_cols) =
        gpu::dev_commit_zk_check_interleaved(&specs, 128, 2).expect("interleaved oracle ran");
    assert_eq!((bad_leaves, bad_cols), (0, 0), "descending-width interleaving mismatch");
}

/// The same, with ALTERNATING rates and widths and several live commitments,
/// so the tables grow and shrink repeatedly while openings are outstanding.
#[test]
fn deferred_openings_survive_alternating_rates_and_widths() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    note_case();
    let specs = [
        (12u32, 8usize, 200usize, 16usize),
        (10, 2, 300, 64),
        (14, 4, 150, 256),
        (10, 8, 260, 16),
        (12, 2, 200, 32),
    ];
    let (bad_leaves, bad_cols) =
        gpu::dev_commit_zk_check_interleaved(&specs, 128, 3).expect("interleaved oracle ran");
    assert_eq!((bad_leaves, bad_cols), (0, 0), "alternating-rate interleaving mismatch");
}

/// FINDING: `HL_ZK_CHUNK=off` was supposed to retain the reference path, but a
/// resident allocation failure sent it into the chunked path anyway — so the
/// reference arm of an A/B could silently become the test arm.
///
/// This drives the REAL entry point (`dev_commit_zk_from`), not the chunked
/// helper, so the mode/fallback branch is genuinely exercised. The failure is
/// injected with a deterministic allocation cap rather than by exhausting the
/// card, so it is reproducible and safe on any device.
#[test]
fn strict_off_reports_allocation_failure_instead_of_chunking() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    note_case();
    // Cap fresh allocations below the resident need but above the witness
    // upload, so the failure lands on the resident commit buffers.
    // Drain first: pool REUSE legitimately bypasses the cap (it needs no new
    // memory), so a same-shape buffer left by an earlier test would make this
    // injection a no-op and the assertion vacuous. That is exactly what
    // happened on the first run of this test.
    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(0); // 0 = off/strict
    let prev_cap = gpu::set_alloc_cap_for_test(1 << 19); // 524,288 elems = 4 MiB
    let r = gpu::dev_commit_zk_from_probe(10, 4, 300, 16);
    gpu::set_alloc_cap_for_test(prev_cap);
    gpu::set_zk_chunk_mode_for_test(prev_mode);

    match r {
        Ok(o) => panic!(
            "strict off must not silently succeed under an injected resident failure \
             (outcome = {o:?}); if chunked = true the reference mode is not strict at all"
        ),
        Err(e) => assert!(
            e.contains("strict reference mode"),
            "strict off must say WHY it refused rather than surfacing a bare allocation error: {e}"
        ),
    }
}

/// The complement: in AUTO the same injected failure must fall back to chunking
/// and succeed. Together these two pin the mode switch from both sides — strict
/// refuses, auto adapts — so neither can be satisfied by a path that ignores the
/// mode entirely.
#[test]
fn auto_falls_back_to_chunking_under_the_same_injected_failure() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    note_case();
    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(1); // 1 = auto
    let prev_cap = gpu::set_alloc_cap_for_test(1 << 19);
    let r = gpu::dev_commit_zk_from_probe(10, 4, 300, 16);
    gpu::set_alloc_cap_for_test(prev_cap);
    gpu::set_zk_chunk_mode_for_test(prev_mode);

    match r {
        Ok(o) => {
            assert!(o.chunked, "auto must CHUNK when the resident buffers cannot be allocated");
            // and the fallback must be CORRECT, not merely routed
            assert_eq!((o.bad_leaves, o.bad_cols), (0, 0), "the chunked fallback produced wrong output: {o:?}");
        }
        Err(e) => panic!("auto must not fail where it can chunk instead: {e}"),
    }
}

/// And the positive half of strict: with no cap, strict off still produces
/// correct results by the resident path, so the switch retains a WORKING
/// reference implementation rather than merely a failing one.
#[test]
fn strict_off_still_produces_correct_results_when_it_fits() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    note_case();
    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(0);
    let o = gpu::dev_commit_zk_from_probe(10, 4, 300, 16).expect("strict off ran");
    gpu::set_zk_chunk_mode_for_test(prev_mode);
    assert!(!o.chunked, "strict off must stay RESIDENT when it fits");
    assert_eq!((o.bad_leaves, o.bad_cols), (0, 0), "the resident reference path must be correct: {o:?}");
}

// ---------------------------------------------------------------------------
// [ZK60-CL3] Every resident allocation site, not just the first pair.
// ---------------------------------------------------------------------------

/// FINDING: the LAST resident take (`d_enc`) used a bare `?`, so a failure
/// there handed the whole commitment to the caller's CPU path instead of the
/// chunked one sitting right beside it. The first two takes got a chunked
/// retry; this one did not, purely because it happens later in the function.
///
/// A size cap cannot isolate this site — `d_coef2` and `d_enc` are the same
/// size — so the injection counts fresh allocations instead and fails only the
/// third one.
#[test]
fn the_last_resident_allocation_retries_chunking_rather_than_giving_up() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    note_case();
    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(1); // auto
    // fresh allocations in order: witness upload, d_coef, d_coef2, then d_enc.
    // Allowing 3 lets the pair succeed and fails exactly the d_enc take.
    let prev_fail = gpu::set_alloc_fail_after_for_test(3);
    let r = gpu::dev_commit_zk_from_probe(10, 4, 300, 16);
    gpu::set_alloc_fail_after_for_test(prev_fail);
    gpu::set_zk_chunk_mode_for_test(prev_mode);

    match r {
        Ok(o) => {
            assert!(o.chunked, "a refused encoded buffer must fall back to CHUNKING, not to the caller's CPU path");
            // the review's point: routing is not correctness
            assert_eq!((o.bad_leaves, o.bad_cols), (0, 0), "the d_enc retry produced wrong output: {o:?}");
        }
        Err(e) => panic!("the d_enc site must retry chunked instead of erroring out: {e}"),
    }
}

/// The same site under STRICT off must refuse, not quietly chunk.
#[test]
fn the_last_resident_allocation_is_also_strict_under_off() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    note_case();
    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(0); // off/strict
    let prev_fail = gpu::set_alloc_fail_after_for_test(3);
    let r = gpu::dev_commit_zk_from_probe(10, 4, 300, 16);
    gpu::set_alloc_fail_after_for_test(prev_fail);
    gpu::set_zk_chunk_mode_for_test(prev_mode);

    match r {
        Err(e) => assert!(
            e.contains("strict reference mode"),
            "strict off must name itself when it refuses the encoded buffer: {e}"
        ),
        Ok(o) => panic!("strict off must not chunk at the d_enc site (outcome = {o:?})"),
    }
}

/// ACCEPTANCE: "distinguish live ownership from pool reservation and allocated
/// capacity from requested scratch."
///
/// THE FIRST VERSION OF THIS TEST WAS VACUOUS and the round-6 review caught it:
/// it counted `pool_take` allocations, but the chunked path uses
/// `pool_take_min` for ALL its scratch, and take_min allocated straight from
/// the device outside the counter. The assertion could not fail. take_min is
/// now behind the same gate, and RAW (non-pool) allocations — pads, powers,
/// leaves, gather output — are counted separately, because they are real
/// device capacity that the old claim ignored entirely.
///
/// [ZK60 round-7 review] THE SECOND VERSION WAS STILL TOO WEAK: "at most 3
/// fresh pooled allocations" is satisfied by a fresh coef2/enc pair plus the
/// hash state, `raw_n > 0` says nothing about capacity, and its illustrative
/// `full_pair_elems` used 2^16 columns for a 2^12-column probe. This version
/// asserts BYTES — exactly what the chunked path was allowed to allocate
/// fresh, exactly what it reused and at what capacity, exactly which raw
/// allocations it made — and then DISABLES pool reuse and shows the same path
/// allocates the whole request fresh, so the reuse assertion is demonstrably
/// not vacuous.
#[test]
fn the_chunked_retry_reuses_pooled_capacity_rather_than_allocating_more() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    note_case();
    // The probe's shape: n = 2^10, nn = 2^12, chunk 128 -> rmax 128, 16 opened
    // columns. B3 state slots mirror cuda.rs (8 * 24 + 1), as the planner does.
    let (log_cols, inv_rate, rows, q_pad, q_open) = (10u32, 4usize, 300usize, 16usize, 16usize);
    let n = 1usize << log_cols;
    let nn = n * inv_rate;
    let rmax = 128usize;
    let state_elems = ((8 * 24 + 1) * nn + 1) / 2;
    let data_b = rows * n * 8;
    let coef_b = rmax * n * 8;
    let big_b = rmax * nn * 8;
    let state_b = state_elems * 8;
    // What the forced-chunk probe ASKS the pool for, in order: the probe's data
    // upload (exact take); the commit's coef / coef2 / enc / state (take_min);
    // the opening's coef / coef2 / enc (take_min; the commit returned its own).
    let requested = data_b + (coef_b + 2 * big_b + state_b) + (coef_b + 2 * big_b);
    // What the warm-up leaves in the pool: coef and coef2 released mid-commit,
    // then data and enc when the resident DevCommit drops. Deterministic after
    // a drain.
    let warm_pool_b = 2 * data_b + 2 * rows * nn * 8;

    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(1);
    let warm = gpu::dev_commit_zk_from_probe(log_cols, inv_rate, rows, q_pad).expect("warm-up ran");
    assert!(!warm.chunked, "warm-up should be resident");
    assert_eq!((warm.bad_leaves, warm.bad_cols), (0, 0), "warm-up must be correct: {warm:?}");

    // ---- reuse ON: forced chunking on the SAME shape
    gpu::reset_alloc_counters_for_test();
    let prev2 = gpu::set_zk_chunk_mode_for_test(2);
    let o = gpu::dev_commit_zk_from_probe(log_cols, inv_rate, rows, q_pad).expect("forced chunked ran");
    let on = gpu::pool_stats_for_test();
    gpu::set_zk_chunk_mode_for_test(prev2);
    assert!(o.chunked, "must have chunked");
    assert_eq!((o.bad_leaves, o.bad_cols), (0, 0), "the chunked path must be correct: {o:?}");
    eprintln!("[CL3] forced-chunk, reuse ON:  {on:?}");

    // The ONLY fresh pooled allocation a warm pool cannot serve is the blake3
    // column state: nothing of that size was ever pooled and the leftover
    // rows*n buffer is too small for it. EXACT, in bytes — not "<= 3 events".
    assert_eq!((on.fresh_count, on.fresh_bytes), (1, state_b),
        "reuse ON: the chunked path may allocate ONLY the blake3 state fresh ({state_b} B); saw {on:?}");
    // Every other take was served from the pool, by requested size ...
    assert_eq!(on.reuse_requested_bytes, requested - state_b,
        "reuse ON: every take but the state must be a reuse; saw {on:?}");
    // ... at the capacity of the RELEASED RESIDENT buffers (oversize reuse,
    // each buffer counted once): the data take is exact, the commit's three
    // scratch takes consume the other three warm buffers, and the opening's
    // three takes get the commit's scratch back. Capacity is what the card
    // holds; requested is what the kernels use.
    let capacity_expect = data_b + (data_b + 2 * rows * nn * 8) + (data_b + 2 * rows * nn * 8);
    assert_eq!(on.reuse_capacity_bytes, capacity_expect,
        "reuse ON: the capacity handed out must be the warm pool's ({warm_pool_b} B) plus the commit scratch re-served to the opening; saw {on:?}");
    assert!(on.reuse_capacity_bytes > on.reuse_requested_bytes, "oversize reuse must show capacity above request");
    // RAW allocations, one event each, EXACT: pads, coset powers, the chunked
    // leaf buffer, then the opening's index list and gather output.
    let raw_expect_b = rows * q_pad * 8 + nn * 8 + nn * 8 * 4 + q_open * 4 + rows * q_open * 8;
    assert_eq!((on.raw_count, on.raw_bytes), (5, raw_expect_b),
        "raw allocations on the commit+opening path must be counted one by one (scope: {}); saw {on:?}", gpu::RAW_ALLOC_SCOPE);

    // ---- NEGATIVE CONTROL: reuse OFF, same forced-chunk probe.
    // Every take is now fresh, so the fresh bytes must equal the whole request
    // and no reuse may be recorded. Had reuse been silently absent above, the
    // ON numbers would have looked like these.
    gpu::reset_alloc_counters_for_test();
    let prev_reuse = gpu::set_pool_reuse_for_test(false);
    let prev3 = gpu::set_zk_chunk_mode_for_test(2);
    let o2 = gpu::dev_commit_zk_from_probe(log_cols, inv_rate, rows, q_pad);
    let off = gpu::pool_stats_for_test();
    gpu::set_zk_chunk_mode_for_test(prev3);
    gpu::set_pool_reuse_for_test(prev_reuse);
    gpu::set_zk_chunk_mode_for_test(prev_mode);
    gpu::dev_pool_drain();
    let o2 = o2.expect("forced chunked with reuse disabled ran");
    assert!(o2.chunked, "reuse OFF must still chunk");
    assert_eq!((o2.bad_leaves, o2.bad_cols), (0, 0), "reuse OFF must still be correct: {o2:?}");
    eprintln!("[CL3] forced-chunk, reuse OFF: {off:?}");
    assert_eq!(off.reuse_count, 0, "reuse OFF: no take may be served from the pool; saw {off:?}");
    assert_eq!(off.fresh_bytes, requested,
        "reuse OFF: the whole request ({requested} B) must be allocated fresh; saw {off:?}");
    assert_eq!((off.raw_count, off.raw_bytes), (5, raw_expect_b), "raw allocations do not depend on pool reuse");
    // The exact identity the control establishes: every byte the ON run took
    // from the pool is a byte the OFF run had to allocate. (Measured on the
    // RTX 4070: ON fresh 3,162,112 B vs OFF fresh 24,494,080 B, 7.75x.)
    assert_eq!(off.fresh_bytes, on.fresh_bytes + on.reuse_requested_bytes,
        "reuse OFF must allocate fresh exactly what reuse ON served from the pool: ON {on:?} vs OFF {off:?}");
}

// ---------------------------------------------------------------------------
// [ZK60-CL6] Chunk-row choices are a MEMORY decision, not a proof decision.
// ---------------------------------------------------------------------------

/// Every chunk-row choice must reproduce the CPU's leaves AND opened columns:
/// the multiples of 128, a choice that is NOT a multiple of 128 (300 steps by
/// 256), and the `rows <= choice` corner where the device takes all rows as
/// ONE chunk (700 on 700, 1000 on 1024). 700 rows leaves a ragged tail at
/// 128/256/512; rate 8 with 64 pads widens the pad slice each chunk carries.
/// This is the oracle behind the CL6 sweep: if any choice moved a leaf or a
/// column, a chunk-row sweep would be comparing different proofs.
#[test]
fn every_chunk_row_choice_matches_the_cpu() {
    let _g = serial();
    for &chunk in &[128usize, 256, 300, 384, 512, 700] {
        check(10, 4, 700, 16, chunk);
        check(10, 8, 300, 64, chunk);
    }
    // rows <= choice at a wider shape: one chunk of all 1000 rows (131 MB of scratch)
    check(12, 4, 1000, 16, 1024);
}

// ---------------------------------------------------------------------------
// [ZK60-CL7] The fused, output-pruned hiding opening.
// ---------------------------------------------------------------------------

/// The hiding opening now takes the non-hiding opening's fused form: the
/// expand NTT's last stage group writes only the sampled columns, pruned to
/// the residues that can produce one. Against the CPU's `encode_row_zk`:
/// pruned AND dense at three shapes where fusion is eligible (log_nn 14, 15,
/// 15; ragged rows; rates 2/4/8; pads 16-256; chunk 128/256), REPEATED
/// indices (the distinct-slot expansion), a shape where fusion is NOT
/// eligible (log_nn = 10) and must fall through to the reference form, and
/// the reference form itself under `HL_ZK_FUSE_GATHER=0`. The negative
/// control above still uses the non-ZK opening and still fails loudly.
#[test]
fn fused_hiding_openings_match_the_cpu_in_every_form() {
    let _g = serial();
    if !gpu_ready() {
        return;
    }
    let prev_fuse = gpu::set_zk_fuse_gather_for_test(1);
    let prev_prune = gpu::set_prune_p2_for_test(1);
    for &(lc, rate, rows, q, chunk) in &[(12u32, 4usize, 300usize, 16usize, 128usize), (14, 2, 200, 256, 128), (12, 8, 260, 64, 256)] {
        for prune in [1usize, 0] {
            gpu::set_prune_p2_for_test(prune);
            note_case();
            let r = gpu::dev_commit_zk_check_chunked(lc, rate, rows, q, chunk, false).expect("fused oracle ran");
            assert_eq!(r, (0, 0), "fused opening (prune {prune}) mismatch at ({lc},{rate},{rows},{q},{chunk})");
        }
    }
    gpu::set_prune_p2_for_test(1);
    // repeated indices: the fused path keeps one slot per DISTINCT column and
    // expands duplicates on the host; every repeat must come back identical
    let idx = [5usize, 4099, 5, 16383, 4099, 0, 0, 8191, 5, 4095, 4096];
    note_case();
    let r = gpu::dev_commit_zk_check_chunked_with(12, 4, 300, 16, 128, false, Some(&idx)).expect("duplicate-index oracle ran");
    assert_eq!(r, (0, 0), "fused opening with repeated indices mismatch");
    assert!(gpu::dev_commit_zk_check_chunked_with(12, 4, 300, 16, 128, false, Some(&[1usize << 14])).is_err(),
            "an out-of-range index must be refused, not panic");
    // not eligible (log_nn = 10 <= NTT_LOG_BLK): the unfused form must serve it
    note_case();
    assert_eq!(gpu::dev_commit_zk_check_chunked(8, 4, 200, 16, 128, false).expect("ineligible shape ran"), (0, 0));
    // the reference form, retained
    gpu::set_zk_fuse_gather_for_test(0);
    note_case();
    assert_eq!(gpu::dev_commit_zk_check_chunked(12, 4, 300, 16, 128, false).expect("reference form ran"), (0, 0));
    gpu::set_prune_p2_for_test(prev_prune);
    gpu::set_zk_fuse_gather_for_test(prev_fuse);
}

/// [ZK60-CL4] The gate that proves the run was not vacuous, from BOTH sides:
/// a device must be present when required, AND real cases must have executed.
/// A green suite that skipped everything is the failure mode this closes.
#[test]
fn zzz_gpu_required_gate_proves_nonzero_executed_cases() {
    let _g = serial();
    emit_summary();
    if !gpu_required() {
        eprintln!("HL_GPU_REQUIRED not set: this gate is advisory in this run");
        return;
    }
    assert!(gpu::enabled(), "HL_GPU_REQUIRED=1 but no device: {}", gpu::label());
    // Execute a real case here so the gate never depends on test ORDER: even
    // if this runs first, it proves at least one genuine case ran.
    gpu::dev_pool_drain();
    let (bad_leaves, bad_cols) =
        gpu::dev_commit_zk_check_chunked(10, 4, 300, 16, 128, false).expect("required gate case ran");
    assert_eq!((bad_leaves, bad_cols), (0, 0));
    note_case();
    let n = EXECUTED_CASES.load(Ordering::SeqCst);
    assert!(n > 0, "GPU-required gate executed {n} cases; a zero-case run is not evidence");

    // and the negative control must have run too — a suite of positives only
    // cannot distinguish a correct build from an oracle that never fails
    let neg = gpu::dev_commit_zk_check_chunked(10, 4, 300, 16, 128, true)
        .expect("negative control ran under the required gate");
    assert!(neg.1 > 300, "the negative control must still detect the wrong re-encode, got {neg:?}");
    emit_summary();
}

} // mod device

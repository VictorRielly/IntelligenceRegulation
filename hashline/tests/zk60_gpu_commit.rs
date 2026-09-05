//! [ZK60-CL1] The chunked HIDING commitment against the CPU oracle.
//!
//! Run with `cargo test --release --features gpu-cuda --test zk60_gpu_commit`.
//! Without the feature the file compiles to nothing; with the feature but no
//! usable device every test SKIPS loudly rather than passing vacuously — a
//! green run on a box with no GPU must not be mistaken for evidence.
//!
//! Each case compares BOTH halves against the CPU's own `encode_row_zk`, not
//! against the device's resident path, so a bug shared by the two device
//! paths could not hide:
//!   * the chunked commitment's column leaves, and
//!   * the chunked, pad/coset-aware OPENING columns —
//! the second being the half `columns_chunked` cannot serve, because it
//! re-encodes with neither the pads nor the coset scaling.

#![cfg(feature = "gpu-cuda")]

use hashline::gpu;
use std::sync::{Mutex, MutexGuard, OnceLock};

/// The allocation cap and chunk-mode hooks are PROCESS-GLOBAL, and Rust runs
/// tests in parallel threads. Without this, a strict-mode test's injected cap
/// makes every concurrently-running test fail — which is exactly what happened
/// the first time this file was run. Every test takes the lock.
fn serial() -> MutexGuard<'static, ()> {
    static L: OnceLock<Mutex<()>> = OnceLock::new();
    let m = L.get_or_init(|| Mutex::new(()));
    m.lock().unwrap_or_else(|e| e.into_inner())
}

/// `(0, 0)` or the test fails with the shape printed.
fn check(log_cols: u32, inv_rate: usize, rows: usize, q_pad: usize, chunk: usize) {
    if !gpu::enabled() {
        eprintln!("SKIP zk60_gpu_commit: no device ({})", gpu::label());
        return;
    }
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
    if !gpu::enabled() {
        eprintln!("SKIP zk60_gpu_commit negative control: no device ({})", gpu::label());
        return;
    }
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
    if !gpu::enabled() {
        eprintln!("SKIP: no device ({})", gpu::label());
        return;
    }
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
    if !gpu::enabled() {
        eprintln!("SKIP: no device ({})", gpu::label());
        return;
    }
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
    if !gpu::enabled() {
        eprintln!("SKIP: no device ({})", gpu::label());
        return;
    }
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
        Ok(chunked) => panic!(
            "strict off must not silently succeed under an injected resident failure \
             (chunked = {chunked}); if chunked = true the reference mode is not strict at all"
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
    if !gpu::enabled() {
        eprintln!("SKIP: no device ({})", gpu::label());
        return;
    }
    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(1); // 1 = auto
    let prev_cap = gpu::set_alloc_cap_for_test(1 << 19);
    let r = gpu::dev_commit_zk_from_probe(10, 4, 300, 16);
    gpu::set_alloc_cap_for_test(prev_cap);
    gpu::set_zk_chunk_mode_for_test(prev_mode);

    match r {
        Ok(chunked) => assert!(chunked, "auto must CHUNK when the resident buffers cannot be allocated"),
        Err(e) => panic!("auto must not fail where it can chunk instead: {e}"),
    }
}

/// And the positive half of strict: with no cap, strict off still produces
/// correct results by the resident path, so the switch retains a WORKING
/// reference implementation rather than merely a failing one.
#[test]
fn strict_off_still_produces_correct_results_when_it_fits() {
    let _g = serial();
    if !gpu::enabled() {
        eprintln!("SKIP: no device ({})", gpu::label());
        return;
    }
    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(0);
    let chunked = gpu::dev_commit_zk_from_probe(10, 4, 300, 16);
    gpu::set_zk_chunk_mode_for_test(prev_mode);
    assert_eq!(chunked.expect("strict off ran"), false, "strict off must stay RESIDENT when it fits");
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
    if !gpu::enabled() {
        eprintln!("SKIP: no device ({})", gpu::label());
        return;
    }
    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(1); // auto
    // fresh allocations in order: witness upload, d_coef, d_coef2, then d_enc.
    // Allowing 3 lets the pair succeed and fails exactly the d_enc take.
    let prev_fail = gpu::set_alloc_fail_after_for_test(3);
    let r = gpu::dev_commit_zk_from_probe(10, 4, 300, 16);
    gpu::set_alloc_fail_after_for_test(prev_fail);
    gpu::set_zk_chunk_mode_for_test(prev_mode);

    match r {
        Ok(chunked) => assert!(
            chunked,
            "a refused encoded buffer must fall back to CHUNKING, not to the caller's CPU path"
        ),
        Err(e) => panic!("the d_enc site must retry chunked instead of erroring out: {e}"),
    }
}

/// The same site under STRICT off must refuse, not quietly chunk.
#[test]
fn the_last_resident_allocation_is_also_strict_under_off() {
    let _g = serial();
    if !gpu::enabled() {
        eprintln!("SKIP: no device ({})", gpu::label());
        return;
    }
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
        Ok(chunked) => panic!("strict off must not chunk at the d_enc site (chunked = {chunked})"),
    }
}

/// ACCEPTANCE: "distinguish live ownership from pool reservation and allocated
/// capacity from requested scratch."
///
/// After a fallback, the released resident buffers sit in the POOL, and
/// `take_min` reuses an oversized pooled buffer as chunk scratch. So the retry
/// should need essentially NO new device memory — the capacity was already
/// paid for. This asserts that directly by counting fresh allocations, which
/// also pins the difference between "allocated capacity" and "requested size".
#[test]
fn the_chunked_retry_reuses_pooled_capacity_rather_than_allocating_more() {
    let _g = serial();
    if !gpu::enabled() {
        eprintln!("SKIP: no device ({})", gpu::label());
        return;
    }
    gpu::dev_pool_drain();
    let prev_mode = gpu::set_zk_chunk_mode_for_test(1);
    // Warm the pool with a full resident commitment of this exact shape.
    let warm = gpu::dev_commit_zk_from_probe(10, 4, 300, 16);
    assert_eq!(warm.expect("warm-up ran"), false, "warm-up should be resident");

    // Now force the chunked path on the SAME shape. Its scratch is smaller than
    // the pooled buffers, so take_min should reuse them.
    gpu::set_alloc_fail_after_for_test(usize::MAX);
    let before = gpu::fresh_alloc_count_for_test();
    let prev2 = gpu::set_zk_chunk_mode_for_test(2); // force chunked
    let r = gpu::dev_commit_zk_from_probe(10, 4, 300, 16);
    let fresh = gpu::fresh_alloc_count_for_test() - before;
    gpu::set_zk_chunk_mode_for_test(prev2);
    gpu::set_zk_chunk_mode_for_test(prev_mode);

    assert_eq!(r.expect("forced chunked ran"), true, "must have chunked");
    // The blake3 column state and the leaves are genuinely new shapes; the big
    // encode scratch must NOT be. A handful of small allocations is expected;
    // a fresh full-size pair would mean pooled capacity was ignored.
    assert!(
        fresh <= 4,
        "the chunked path should reuse pooled capacity; it made {fresh} fresh allocations"
    );
}

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
    for &inv_rate in &[2usize, 4, 8] {
        check(10, inv_rate, 300, 16, 128);
    }
}

/// Row counts that are not multiples of the chunk step, so the LAST chunk is
/// short — the case that breaks a naive streaming hash.
#[test]
fn zk_chunked_matches_cpu_at_ragged_row_counts() {
    for &rows in &[129usize, 255, 256, 257, 384, 400] {
        check(10, 4, rows, 16, 128);
    }
}

/// A single chunk must agree with the resident construction too: `rows <=
/// chunk` is the degenerate plan, and it is the one a small gate exercises.
#[test]
fn zk_chunked_matches_cpu_in_one_chunk() {
    check(10, 4, 64, 16, 128);
    check(10, 4, 128, 16, 128);
}

/// Varied pad counts. `q_pad` sets how many hiding symbols ride each row, so
/// it moves the pad slice the chunk loop takes; `n + q <= nn` bounds it.
#[test]
fn zk_chunked_matches_cpu_at_varied_pad_counts() {
    for &q_pad in &[1usize, 16, 64, 256] {
        check(10, 4, 300, q_pad, 128);
    }
}

/// Wider rows, where a chunk's encoded scratch is the thing being bounded.
#[test]
fn zk_chunked_matches_cpu_at_wider_shapes() {
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

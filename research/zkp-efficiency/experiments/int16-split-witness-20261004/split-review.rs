//! Research-only, uncompiled review primitives. No native patch is applied.
//! This is for FFN-down AFTER the existing product int16-class check.
//! General i64 witness values must not be silently cast to i16.
//! Device GEMM must return exact int32 accumulators with alpha=1, beta=0;
//! no floating point epilogue, clamping or intermediate requantization.

pub fn split_i16(value: i16) -> (i8, i8) {
    let low = ((value & 255) - 128) as i8;
    let high = (value >> 8) as i8;
    (low, high)
}

/// Public padded K <= 16384: each byte dot <= 2^28 in magnitude, and the
/// complete int16 x int8 dot <= 2^36. For larger K, use proven bounded tiles
/// with i64 combination or the unchanged baseline; no new witness refusal.
pub fn reconstruct(low_dot: i32, high_dot: i32, column_sum: i32) -> i64 {
    i64::from(low_dot) + 256 * i64::from(high_dot) + 128 * i64::from(column_sum)
}

// Proposed interface, not implemented or compiled here:
// exact_down(h16: &[i64], true_t: usize, t_pad: usize, f_pad: usize,
//            d_pad: usize, wd_in_out: &[i8]) -> Vec<i64>
// Input and weight orientation/padding match witness.rs::matmul_in_out.
// Pack all K coordinates of true token rows. Skip padded token rows and
// leave their outputs zero, or encode zero as low=-128/high=0 consistently.
// Sum each weight column over the SAME padded K consumed by GEMM.
// Optional stacked input [low rows; high rows] has 2*true_t rows. Its two
// result groups must remain paired per token before i64 reconstruction.
// Cache sums only with the immutable weight identity and full shape/layout.
// P3 sums/weights/packed values remain private; no logs or receipt fields.
// Feed the original i64 accumulator into existing quantize(... SH_Z ...),
// retaining biased remainder, true output support and first-refusal order.

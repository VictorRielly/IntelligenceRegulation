// UNCOMPILED, UNAPPLIED research interface sketch, authored locally.
// The Python differential experiment validates the arithmetic/schedule,
// not this Rust source, CUDA execution, memory safety or native proof bytes.
// Owner integration seam: private_block/witness.rs FFN-down at line 685.
// Replace only matmul_in_out(...)+quantize(... SH_Z ...), retaining z16/RDL
// padded plane sizes, support, and all following residual/limb code.

pub struct DownTile<'a> {
    pub row0: usize,
    pub col0: usize,
    pub rows: usize,
    pub cols: usize,
    // Full-K stacked GEMM returns low then high, both exact signed i32.
    pub low: &'a [i32],
    pub high: &'a [i32],
    // Sums cover exactly the consumed padded K, bound to immutable weights.
    pub column_sums: &'a [i32],
}

// Private status; never printed/exported or absorbed into the transcript.
// Caller returns the existing static FFN-down refusal only after every tile
// finishes, and only then enters residual 2. No new proof-visible site.
pub fn finish_full_k_tile(
    tile: DownTile<'_>,
    output_stride: usize,
    z16: &mut [i64],
    rdl: &mut [i64],
    first_bad: &mut Option<usize>,
) {
    // Validated public plan must ensure nonoverlap and exact true support;
    // caller initializes every padded z16/RDL word to zero.
    assert_eq!(tile.low.len(), tile.rows * tile.cols);
    assert_eq!(tile.high.len(), tile.low.len());
    assert_eq!(tile.column_sums.len(), tile.cols);
    for r in 0..tile.rows {
        for j in 0..tile.cols {
            let ij = r * tile.cols + j;
            let acc = i64::from(tile.low[ij])
                + 256 * i64::from(tile.high[ij])
                + 128 * i64::from(tile.column_sums[j]);
            // SH_Z=6, nearest ties toward +infinity, never float/clamp.
            let q = (acc + 32) >> 6;
            let biased = acc - (q << 6) + 32;
            let dst = (tile.row0 + r) * output_stride + tile.col0 + j;
            if !(-32768..=32767).contains(&q) {
                *first_bad = Some(first_bad.map_or(dst, |old| old.min(dst)));
            }
            z16[dst] = q;
            rdl[dst] = biased;
        }
    }
}

// For split-K: widen and accumulate low+256high in a tile-sized i64 buffer
// after EACH partial, add 128*full_column_sum ONCE after the final K tile,
// then use the same finish/biased-remainder rule. No intermediate rounding
// or range checks. Existing wider-domain fallback stays available; never
// newly refuse a legacy supported shape to select this accelerator.
// Device concurrency requires race-free private status reduction and fixed
// public buffers/work schedule. Host mirror/transfer/workspace costs omitted.

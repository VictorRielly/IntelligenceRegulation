//! [UPERF3-XX] hashline's prover on the GPU (feature `gpu-cuda`, runtime
//! toggle `HL_GPU=1`), copied in discipline from zkmatrix-rs's
//! src/ring/gpu (cudarc driver API + NVRTC compilation of `kernels.cu` at
//! first use; no CUDA toolkit on the box, only the driver and the NVRTC
//! runtime library).
//!
//! DIFFERENTIAL DISCIPLINE: every device entry point computes the SAME
//! field values as the CPU code it replaces — canonical Goldilocks
//! representatives of the same mathematical quantity (an NTT is the
//! evaluation map, a sumcheck round sum is a field sum, a row-combination
//! is a linear map; none depends on operation order), and blake3 is a
//! function — so the transcript absorbs identical bytes and the proof is
//! byte-identical to the CPU path's. The CPU path stays the oracle: the
//! pass's proof sha256 with `HL_GPU=1` must equal the CPU-only binary's.
//!
//! Without the feature this module is the constant-false stub below and
//! nothing in the crate changes.

#[cfg(feature = "gpu-cuda")]
mod cuda;

// [ZK60-METAL] the Apple GPU backend: commitments only (zkp-core's Backend
// seam). Every other device entry point stays CUDA-only, so a gpu-metal build
// runs those phases on the CPU. CUDA wins if both features are requested.
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
mod metal;
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
pub use metal::{metal_commit, metal_commit_zk, probe_field as metal_probe_field, stats as metal_stats, MetalCommit};

/// **ROUND 2 (R2-5): GPU MODE FAILS CLOSED.** Every place a device entry
/// point declines and the prover would silently take the CPU body reports
/// here. The decline is counted and logged; and when the caller CLAIMED the
/// GPU (`HL_GPU_REQUIRED=1`) it is a hard failure: the process panics (an
/// abort in release builds), so no result is ever reported as GPU-made when
/// any part of it fell back to the CPU. The proof bytes would be identical
/// either way (the differential discipline above); what fails closed is the
/// CLAIM about how they were made.
pub fn required() -> bool {
    std::env::var("HL_GPU_REQUIRED").map(|v| v == "1").unwrap_or(false)
}

static DECLINES: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

/// the number of device declines in this process so far
pub fn declines() -> usize {
    DECLINES.load(std::sync::atomic::Ordering::Relaxed)
}

/// report one decline at `site` (never returns when the GPU is required)
pub fn declined(site: &str, err: &str) {
    DECLINES.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    eprintln!("[ZK60-GPU] {site} declined ({err}); CPU path");
    if required() {
        panic!("[ZK60-GPU] HL_GPU_REQUIRED=1 and {site} declined ({err}): refusing to fall back to the CPU (fail closed)");
    }
}

/// with `HL_GPU_REQUIRED=1`, refuse unless the device path is live
pub fn require_live() -> Result<(), String> {
    if required() && !enabled() {
        return Err(format!("HL_GPU_REQUIRED=1 but the GPU path is not live: {}", label()));
    }
    Ok(())
}

#[cfg(feature = "gpu-cuda")]
pub use cuda::{
    dev_columns, dev_commit, dev_commit_check, dev_commit_from, dev_eval_many, dev_fold_rows, dev_hash_check, dev_helpers, dev_stats,
    dev_stats_reset, dev_zerocheck, enabled, label, probe, DevCommit, GpuStats, HelperSpec, Pooled, ProbeReport, TabSpec,
};
// [UPERF3-ZA] the ZK commitment's device entries (new functions in cuda.rs)
#[cfg(feature = "gpu-cuda")]
pub use cuda::{dev_commit_zk, dev_commit_zk_keyed, dev_commit_zk_from, dev_upload_rows};
// [UPERF3-AC] the cached-W device entry (upload + encode, no hash) and the chunked-commit probe
#[cfg(feature = "gpu-cuda")]
pub use cuda::{dev_commit_check_chunked, dev_commit_zk_check_chunked, dev_encode_only};
// [FSP-HOST] item (a): the commitment whose upload reads the int8 planes directly
#[cfg(feature = "gpu-cuda")]
pub use cuda::dev_commit_planes;
// [ZK60-CL2] deferred-opening interleaving oracle, the strict/injection test
// hooks, and the stage-major twiddle layout used to assert the monotonic cache
#[cfg(feature = "gpu-cuda")]
pub use cuda::{dev_commit_zk_check_interleaved, dev_commit_zk_from_probe, fresh_alloc_count_for_test, raw_alloc_stats_for_test, reset_alloc_counters_for_test, set_alloc_cap_for_test, set_alloc_fail_after_for_test, set_zk_chunk_mode_for_test, stage_major_twiddles_for_test, ProbeOutcome};
// [ZK60 round-7 review] byte-level pool accounting, the reuse negative control, and the counter's stated scope
#[cfg(feature = "gpu-cuda")]
pub use cuda::{pool_stats_for_test, set_pool_reuse_for_test, PoolStats, RAW_ALLOC_SCOPE};
// [ZK60-CL7] the fused/pruned hiding opening's switches and the index-parameterised oracle
#[cfg(feature = "gpu-cuda")]
pub use cuda::{dev_commit_zk_check_chunked_with, set_prune_p2_for_test, set_zk_fuse_gather_for_test};
// [ZK60-CL18] the compact pad/scale switch (default OFF) and the pure width/refusal function the oracle pins
#[cfg(feature = "gpu-cuda")]
pub use cuda::{set_zk_compact_pad_for_test, zk_pad_width};
// [UPERF3-AH] the shape-general zero-check (any block count) and the up-front
// device-buffer reservation that keeps the "declined -> host path" discipline
// honest once the helper columns have already gone to the device.
#[cfg(feature = "gpu-cuda")]
pub use cuda::{dev_reserve, dev_tab_zerocheck, dev_zerocheck_blocks, TabSpecPad};
// [UPERF3-AI] the reservation that drains the buffer pool before it gives up (the ZK
// prover at Mistral width needs 1,168 MB for its zero-check F tables and the pool's
// retained chunk scratch is what stands in the way).
#[cfg(feature = "gpu-cuda")]
pub use cuda::{dev_mem_info, dev_pool_drain, dev_reserve_hard};
// [ZK60-CL15] the allocation-scoped opening probes (commit, snapshot the
// counters, open with the caller's indices, report the counters' movement
// across the OPEN alone) and the two kernel constants the pure plan below
// mirrors, so a test can pin the mirror to its owner.
#[cfg(feature = "gpu-cuda")]
pub use cuda::{dev_commit_open_probe, dev_commit_zk_open_probe, OpenProbe, NTT_LOG_BLK, P2SP_NC};

/// [ZK60-CL15] The chunked openings' HOST-SIDE index preprocessing, factored
/// out of `columns_chunked` and `columns_chunked_zk` (cuda.rs), which used to
/// build it twice inline, and compiled in EVERY configuration so the boundary
/// is testable without a device.
///
/// WHY: Codex's round-9 review found, by source inspection, that the hiding
/// fused/pruned opening reached `qs.last().unwrap()` with no guard for an
/// empty query list — after it had already taken three scratch buffers,
/// uploaded the index list and allocated the output. The decision here is
/// that an EMPTY query list opens ZERO columns (`OpenPlan::Empty`) and an
/// out-of-range index is an `Err`, both decided by this pure function BEFORE
/// any device work, so neither case allocates, uploads or launches anything.
///
/// The values are exactly what the device code built before (bit-identical,
/// so no proof byte can move): one output slot per DISTINCT index in
/// first-occurrence order (`uniq`), the per-column slot map the fused gather
/// kernels read (`sel`, `-1` = not sampled), the per-index slot (`slot`, how
/// duplicates are filled from the first occurrence on the host), the plain
/// `i32` index list the unfused gather kernel reads (`idx32`), and — on the
/// pruned route — the compact residue list `col mod blk`, sorted, deduped,
/// kept only when at most a quarter of the block (`nq * 4 <= blk`) and
/// padded to a multiple of `p2sp_nc` by repeating its last entry (those lanes
/// compute and are never stored). Fusion is declined when `log_nn <= log_blk`
/// (there is no second stage group to fuse) and pruning when
/// `log_nn - log_blk > 5` (the tile would not fit), exactly as before.
///
/// `blk` (= `1 << NTT_LOG_BLK`) and `p2sp_nc` (= `P2SP_NC`) are passed in:
/// cuda.rs stays the owner of the kernel constants.
pub mod open_plan {
    /// One nonempty opening's host-side plan. See the module doc for each field.
    #[derive(Debug, Clone, PartialEq, Eq)]
    pub struct OpenIndices {
        /// the fused form serves this opening: requested AND `log_nn > log_blk`
        pub fused: bool,
        /// per encoded column (`nn` entries): `-1`, or the output slot of that column
        pub sel: Vec<i32>,
        /// per opened index: its output slot
        pub slot: Vec<usize>,
        /// the distinct opened indices, first-occurrence order (one output slot each)
        pub uniq: Vec<usize>,
        /// the opened indices as `i32`, in the caller's order (the unfused gather list)
        pub idx32: Vec<i32>,
        /// the pruned last stage group's residue list, padded, with its distinct count
        pub residues: Option<(Vec<i32>, usize)>,
    }

    impl OpenIndices {
        /// The list the device gather reads: the slot map when fused, else the indices.
        pub fn device_index_list(&self) -> &[i32] {
            if self.fused { &self.sel } else { &self.idx32 }
        }
        /// Output columns the device writes: one per distinct index when fused, else one per index.
        pub fn cols_out(&self) -> usize {
            if self.fused { self.uniq.len() } else { self.idx32.len() }
        }
        /// The output column holding opened index number `c`.
        pub fn out_slot(&self, c: usize) -> usize {
            if self.fused { self.slot[c] } else { c }
        }
    }

    /// The decision for a query list.
    #[derive(Debug, Clone, PartialEq, Eq)]
    pub enum OpenPlan {
        /// no indices: open zero columns, touch nothing on the device
        Empty,
        Open(OpenIndices),
    }

    /// The compact residue list `j mod blk` of `idx`: sorted, deduplicated,
    /// then padded to a multiple of `p2sp_nc` by repeating its LAST entry.
    /// Returns `(list, distinct count)`; `None` for an empty `idx` — the
    /// site the round-9 review flagged unwrapped the last entry of an empty
    /// list. This does NOT apply the `nq * 4 <= blk` size rule (the bench
    /// wants the list regardless); `plan_open_indices` applies it.
    pub fn residue_list(idx: &[usize], blk: usize, p2sp_nc: usize) -> Option<(Vec<i32>, usize)> {
        let mut qs: Vec<i32> = idx.iter().map(|&j| (j & (blk - 1)) as i32).collect();
        qs.sort_unstable();
        qs.dedup();
        let nq = qs.len();
        let last = *qs.last()?;
        qs.resize(nq.div_ceil(p2sp_nc) * p2sp_nc, last);
        Some((qs, nq))
    }

    /// Plan one opening of `idx` over `nn` encoded columns. `fused` and
    /// `prune` are the caller's switch settings (`HL_GPU_FUSE_GATHER` /
    /// `HL_ZK_FUSE_GATHER`, `HL_GPU_PRUNE_P2`); eligibility by shape is
    /// decided here. Errors: a malformed shape, or any index `>= nn`.
    pub fn plan_open_indices(idx: &[usize], nn: usize, blk: usize, p2sp_nc: usize, fused: bool, prune: bool) -> Result<OpenPlan, String> {
        if !nn.is_power_of_two() || !blk.is_power_of_two() || p2sp_nc == 0 {
            return Err(format!("open plan: malformed shape (nn {nn}, blk {blk}, p2sp_nc {p2sp_nc})"));
        }
        if idx.is_empty() {
            return Ok(OpenPlan::Empty);
        }
        if let Some(&bad) = idx.iter().find(|&&j| j >= nn) {
            return Err(format!("opened index {bad} is out of range for {nn} encoded columns"));
        }
        let log_nn = nn.trailing_zeros();
        let log_blk = blk.trailing_zeros();
        let fused = fused && log_nn > log_blk;
        let mut uniq: Vec<usize> = Vec::with_capacity(idx.len());
        let mut slot: Vec<usize> = Vec::with_capacity(idx.len());
        let mut sel: Vec<i32> = vec![-1; nn];
        for &j in idx {
            if sel[j] < 0 {
                sel[j] = uniq.len() as i32;
                uniq.push(j);
            }
            slot.push(sel[j] as usize);
        }
        let idx32: Vec<i32> = idx.iter().map(|&j| j as i32).collect();
        let residues = if fused && prune && log_nn - log_blk <= 5 {
            residue_list(idx, blk, p2sp_nc).filter(|&(_, nq)| nq * 4 <= blk)
        } else {
            None
        };
        Ok(OpenPlan::Open(OpenIndices { fused, sel, slot, uniq, idx32, residues }))
    }
}

/// [FSP-HOST] ITEM (a) OF THE FIVE-SECOND PLAN'S STEP 4: the W
/// commitment's SOURCE, as the three int8 planes plus the block map,
/// instead of the converted `Vec<Fp>` copy of them.
///
/// WHY. `prove_layer_v3` builds `w_data: Vec<Fp>` — a block tiling of the
/// int8 weight planes, eight bytes per weight — and hands it to the
/// commitment, which uploads it in the NARROW form: `pack_narrow` reads
/// all eight bytes of every element and writes the one byte that
/// represents it (`gpu/cuda.rs`). At the 8B shape that is a 2.74 s fill
/// [MEASURED, `results/hashline_convert_r3.log`] followed by a pass that
/// reads 74.6 GB to write 9.3 GB. Reading the planes directly makes the
/// fill unnecessary and turns the packing pass into a 9.3 GB -> 9.3 GB
/// gather of contiguous `memcpy` runs.
///
/// WHY THE BYTES ARE IDENTICAL, not approximately. `pack_narrow` at
/// `w = 1` emits `v as u8` when `v < 128` and `v.wrapping_sub(P) as u8`
/// when `v >= P - 128`; `w_data[i] = Fp::from_i64(s as i64)` for an `i8`
/// `s` gives `v = s` for `s >= 0` and `v = P + s` for `s < 0`, so both
/// arms produce exactly the two's-complement byte `s as u8`. The map from
/// element index to plane element is the one `prove_layer_v3` writes with
/// and `zkp_core::ffn_v3::Layout` defines; it is transcribed once, here.
///
/// THE MAP (`Layout::new`): the W buffer is exactly `3 * nb_d * nb_f`
/// blocks of `wb = db * fb` elements, contiguous, `wg` first (block
/// `c * nb_f + b`), then `wu` (same index), then `wd` (block
/// `b * nb_d + c`). A `wg`/`wu` block holds `db` rows of `fb`, row `kp`
/// being `plane[(c*db+kp)*f + b*fb ..][..fb]`; a `wd` block holds `fb`
/// rows of `db`, row `jp` being `wd[(b*fb+jp)*d + c*db ..][..db]`. Every
/// row is CONTIGUOUS in its plane, which is what makes the byte fill a
/// gather of `memcpy`s. The commitment's row width is `n = wb`
/// (`params.pcs_for(lay.log_wb)`), so one commitment row is one block and
/// a chunked upload's row range is a block range — but this module makes
/// no such assumption: `fill_bytes` takes an arbitrary element range.
pub mod planes {
    use crate::field::Fp;
    use rayon::prelude::*;

    /// [FSP-HOST] Bytes of destination that make ONE parallel task. The
    /// first cut of this module used one task per block row and measured
    /// 2.3x slower than the `pack_narrow` pass it replaces (0.105 s against
    /// 0.046 s over the 12x512 fixture's 12 W commitments): the fixture's
    /// `wd` rows are 256 bytes, and rayon's per-task cost is not small
    /// against a 256-byte copy. 64 KB is ~8 tasks per block at that shape
    /// and ~128 at the 8B shape.
    const GRAIN: usize = 1 << 16;

    /// i8 as its two's-complement byte, for a whole run.
    #[inline]
    fn as_bytes(v: &[i8]) -> &[u8] {
        // SAFETY: i8 and u8 have identical size, alignment and validity
        // (the same pattern wcache.rs uses to digest a plane).
        unsafe { std::slice::from_raw_parts(v.as_ptr() as *const u8, v.len()) }
    }

    /// The three int8 planes of one v3 layer plus the block map, as a
    /// source the commitment reads instead of a converted `Vec<Fp>`.
    #[derive(Clone, Copy, Debug)]
    pub struct PlaneTiling<'a> {
        wg: &'a [i8],
        wu: &'a [i8],
        wd: &'a [i8],
        d: usize,
        f: usize,
        db: usize,
        fb: usize,
        nb_d: usize,
        nb_f: usize,
        len: usize,
        wb: usize,
        blocks: usize,
    }

    impl<'a> PlaneTiling<'a> {
        /// Build the source, checking the shape the caller claims: a wrong
        /// block count or a short plane is a decline, never a wrong byte.
        #[allow(clippy::too_many_arguments)]
        pub fn new(wg: &'a [i8], wu: &'a [i8], wd: &'a [i8], d: usize, f: usize, db: usize, fb: usize, nb_d: usize, nb_f: usize) -> Result<PlaneTiling<'a>, String> {
            if db == 0 || fb == 0 || nb_d == 0 || nb_f == 0 || nb_d.checked_mul(db) != Some(d) || nb_f.checked_mul(fb) != Some(f) {
                return Err(format!("plane tiling: blocks {nb_d}x{db} / {nb_f}x{fb} do not tile d {d} / f {f}"));
            }
            let plane_len = d.checked_mul(f).ok_or("plane tiling: plane length overflow")?;
            let len = plane_len.checked_mul(3).ok_or("plane tiling: total length overflow")?;
            // With nonzero block dimensions and exact tiling, these products
            // are bounded by the already checked total length.
            let wb = db.checked_mul(fb).ok_or("plane tiling: block length overflow")?;
            let blocks = nb_d.checked_mul(nb_f).and_then(|n| n.checked_mul(3)).ok_or("plane tiling: block count overflow")?;
            if wg.len() != plane_len || wu.len() != plane_len || wd.len() != plane_len {
                return Err(format!("plane tiling: planes {} / {} / {} are not d*f = {plane_len}", wg.len(), wu.len(), wd.len()));
            }
            Ok(PlaneTiling { wg, wu, wd, d, f, db, fb, nb_d, nb_f, len, wb, blocks })
        }

        /// Elements in the tiled buffer (`Layout::w_len`).
        pub fn len(&self) -> usize {
            self.len
        }
        pub fn is_empty(&self) -> bool {
            self.len() == 0
        }
        /// Elements per block (`Layout::wb`).
        pub fn wb(&self) -> usize {
            self.wb
        }
        /// Blocks in the buffer.
        pub fn blocks(&self) -> usize {
            self.blocks
        }
        /// Elements per row of block `blk` (`fb` for wg/wu, `db` for wd).
        fn row_len(&self, blk: usize) -> usize {
            if blk < 2 * self.nb_d * self.nb_f {
                self.fb
            } else {
                self.db
            }
        }
        /// The plane a block reads and the offset of its row `r` in it.
        fn row_src(&self, blk: usize, r: usize) -> (&'a [i8], usize) {
            let nb = self.nb_d * self.nb_f;
            if blk < 2 * nb {
                let (plane, k) = if blk < nb { (self.wg, blk) } else { (self.wu, blk - nb) };
                let (c, b) = (k / self.nb_f, k % self.nb_f);
                (plane, (c * self.db + r) * self.f + b * self.fb)
            } else {
                let k = blk - 2 * nb;
                let (b, c) = (k / self.nb_d, k % self.nb_d);
                (self.wd, (b * self.fb + r) * self.d + c * self.db)
            }
        }
        /// Row `r` of block `blk`, as the contiguous run of its plane.
        fn row(&self, blk: usize, r: usize) -> &'a [i8] {
            let (plane, base) = self.row_src(blk, r);
            &plane[base..base + self.row_len(blk)]
        }
        /// The distance in the plane between one row of `blk` and the next
        /// (`f` for a wg/wu block, `d` for a wd block). When it equals the
        /// row length the block's rows are ONE contiguous run of the plane
        /// — true of wg/wu whenever `nb_f == 1` and of wd whenever
        /// `nb_d == 1`, which covers the 12x512 fixture's wg/wu and the 8B
        /// shape's wd.
        fn row_stride(&self, blk: usize) -> usize {
            if blk < 2 * self.nb_d * self.nb_f {
                self.f
            } else {
                self.d
            }
        }

        /// The two's-complement BYTE image of elements
        /// `[off, off + dst.len())` — what `pack_narrow(dst, &w_data[off..],
        /// 1)` writes, without `w_data`.
        pub fn fill_bytes(&self, off: usize, dst: &mut [u8]) {
            self.fill_range(off, dst.len(), dst, |d, s| d.copy_from_slice(as_bytes(s)));
        }

        /// The 64-bit FIELD image of the same range — what `prove_layer_v3`
        /// writes into `w_data[off..]`. The reference the oracle compares
        /// against, and the CPU-side fallback's building block.
        pub fn fill_fp(&self, off: usize, dst: &mut [Fp]) {
            self.fill_range(off, dst.len(), dst, |d, s| {
                for (o, &v) in d.iter_mut().zip(s.iter()) {
                    *o = Fp::from_i64(v as i64);
                }
            });
        }

        /// Walk the element range block by block; inside a block, head row,
        /// whole rows in parallel, tail row. `put` writes one destination
        /// run from one contiguous source run.
        fn fill_range<T: Send + Sync>(&self, off: usize, len: usize, dst: &mut [T], put: impl Fn(&mut [T], &[i8]) + Sync) {
            assert_eq!(dst.len(), len);
            assert!(off <= self.len() && len <= self.len() - off,
                    "plane fill {off}+{len} past the buffer's {} elements", self.len());
            let wb = self.wb();
            let mut pos = 0usize;
            let mut e = off;
            while pos < len {
                let blk = e / wb;
                let s = e - blk * wb;
                let take = (wb - s).min(len - pos);
                self.fill_block(blk, s, &mut dst[pos..pos + take], &put);
                pos += take;
                e += take;
            }
        }

        fn fill_block<T: Send + Sync>(&self, blk: usize, s: usize, dst: &mut [T], put: &(impl Fn(&mut [T], &[i8]) + Sync)) {
            let rl = self.row_len(blk);
            let (mut r, c0) = (s / rl, s % rl);
            let mut pos = 0usize;
            if c0 != 0 {
                let take = (rl - c0).min(dst.len());
                put(&mut dst[..take], &self.row(blk, r)[c0..c0 + take]);
                pos = take;
                r += 1;
            }
            let rest = dst.len() - pos;
            let (full, tail) = (rest / rl, rest % rl);
            if full > 0 {
                let r_mid = r;
                let mid = &mut dst[pos..pos + full * rl];
                if self.row_stride(blk) == rl {
                    // the rows are one contiguous run of the plane: a single
                    // split copy, no per-row work at all
                    let (plane, base) = self.row_src(blk, r_mid);
                    let src = &plane[base..base + full * rl];
                    mid.par_chunks_mut(GRAIN).zip(src.par_chunks(GRAIN)).for_each(|(d, s)| put(d, s));
                } else {
                    // strided rows: one TASK per GRAIN bytes, not one per
                    // row. [FSP-HOST] a task per row was measured 2.3x
                    // SLOWER than the `pack_narrow` pass it replaces at the
                    // 12x512 fixture, whose wd rows are 256 bytes: rayon's
                    // per-task cost swamped a 256-byte copy.
                    let k = (GRAIN / rl).max(1);
                    mid.par_chunks_mut(k * rl).enumerate().for_each(|(t, part)| {
                        for (i, row) in part.chunks_mut(rl).enumerate() {
                            put(row, self.row(blk, r_mid + t * k + i));
                        }
                    });
                }
                pos += full * rl;
            }
            if tail > 0 {
                put(&mut dst[pos..], &self.row(blk, r + full)[..tail]);
            }
        }
    }

    /// [FSP-HOST] THE ORACLE for item (a), host side, compiled in every
    /// configuration. It pins two things:
    ///
    /// 1. `fill_fp` over the whole buffer == the buffer `prove_layer_v3`
    ///    writes. The reference is a literal transcription of that
    ///    function's three loops, driven by the REAL
    ///    `zkp_core::ffn_v3::Layout` offsets, so the map is checked against
    ///    its owner and not against itself. The fixture shape (12x512's
    ///    768/2048) is one of the cases, and `fill_fp`'s image at that
    ///    shape is what the four GPU byte gates prove end to end — so a
    ///    wrong transcription would have to be wrong in the same way as
    ///    the code the gates pin.
    /// 2. `fill_bytes(off, len)` == the two's-complement byte image of
    ///    `fill_fp` over the same range, at ranges that split blocks and
    ///    rows and in the CHUNKED form (successive pieces that reassemble
    ///    the buffer) — the form the 8B W commitment uses and the 12x512
    ///    fixture cannot reach.
    ///
    /// The comparison against the REAL `pack_narrow` (the function whose
    /// bytes must be reproduced) is the twin test in `gpu/cuda.rs`, which
    /// only exists under `--features gpu-cuda`.
    #[cfg(test)]
    mod tests {
        use super::*;
        use zkp_core::ffn_v3::Layout;

        /// A deterministic plane covering the whole i8 range, both ends
        /// included (-128 and 127 are the values `narrow_class` calls the
        /// two edges of the field).
        fn plane(n: usize, seed: u64) -> Vec<i8> {
            let mut x = seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1;
            (0..n)
                .map(|i| {
                    x ^= x << 13;
                    x ^= x >> 7;
                    x ^= x << 17;
                    match i % 37 {
                        0 => -128i8,
                        1 => 127,
                        2 => 0,
                        3 => -1,
                        _ => (x >> 24) as i8,
                    }
                })
                .collect()
        }

        /// `prove_layer_v3`'s W fill, transcribed (layer.rs, "W data + commit").
        fn reference(lay: &Layout, wg: &[i8], wu: &[i8], wd: &[i8]) -> Vec<Fp> {
            let (d, f, wb) = (lay.d, lay.f, lay.wb);
            let (db, fb) = (1usize << lay.log_db, 1usize << lay.log_fb);
            let mut w_data = vec![Fp::ZERO; lay.w_len];
            for c in 0..lay.nb_d {
                for b in 0..lay.nb_f {
                    for (offs, src) in [(&lay.wg, wg), (&lay.wu, wu)] {
                        let off = offs[c * lay.nb_f + b];
                        for kp in 0..db {
                            let k = c * db + kp;
                            for jp in 0..fb {
                                w_data[off + kp * fb + jp] = Fp::from_i64(src[k * f + b * fb + jp] as i64);
                            }
                        }
                    }
                    let off = lay.wd[b * lay.nb_d + c];
                    for jp in 0..fb {
                        let j = b * fb + jp;
                        for np in 0..db {
                            w_data[off + jp * db + np] = Fp::from_i64(wd[j * d + c * db + np] as i64);
                        }
                    }
                    assert_eq!(wb, db * fb);
                }
            }
            w_data
        }

        /// `pack_narrow`'s w = 1 arm, transcribed (gpu/cuda.rs).
        fn byte_image(v: &[Fp]) -> Vec<u8> {
            let p = crate::field::P;
            v.iter()
                .map(|x| {
                    let v = x.0;
                    if v < 128 {
                        v as u8
                    } else if v >= p - 128 {
                        v.wrapping_sub(p) as u8
                    } else {
                        panic!("value {v} is not an int8 in the field")
                    }
                })
                .collect()
        }

        /// (t_rows, d, f): the 12x512 fixture, a two-sided multi-block
        /// shape, the 8B block structure scaled down (nb_d 1, nb_f 7), and
        /// a single-block shape.
        const SHAPES: [(usize, usize, usize); 4] = [(512, 768, 2048), (16, 96, 192), (16, 256, 1792), (16, 64, 128)];

        #[test]
        fn fill_fp_is_the_layer_buffer() {
            for (t, d, f) in SHAPES {
                let lay = Layout::new(t, d, f);
                let (wg, wu, wd) = (plane(d * f, 1), plane(d * f, 2), plane(f * d, 3));
                let pt = PlaneTiling::new(&wg, &wu, &wd, d, f, 1 << lay.log_db, 1 << lay.log_fb, lay.nb_d, lay.nb_f).unwrap();
                assert_eq!(pt.len(), lay.w_len, "shape {d}x{f}");
                let want = reference(&lay, &wg, &wu, &wd);
                let mut got = vec![Fp::ZERO; lay.w_len];
                pt.fill_fp(0, &mut got);
                assert!(got == want, "fill_fp != the layer buffer at {d}x{f}");
            }
        }

        #[test]
        fn fill_bytes_is_the_packed_image_over_every_range() {
            for (t, d, f) in SHAPES {
                let lay = Layout::new(t, d, f);
                let (wg, wu, wd) = (plane(d * f, 4), plane(d * f, 5), plane(f * d, 6));
                let pt = PlaneTiling::new(&wg, &wu, &wd, d, f, 1 << lay.log_db, 1 << lay.log_fb, lay.nb_d, lay.nb_f).unwrap();
                let want = byte_image(&reference(&lay, &wg, &wu, &wd));
                let (wb, rl) = (lay.wb, 1usize << lay.log_fb);
                let n = lay.w_len;
                // whole buffer, block/row aligned pieces, and pieces that
                // start and end inside a row and inside a block
                let mut ranges: Vec<(usize, usize)> = vec![(0, n), (0, 1), (n - 1, 1), (0, wb), (wb, wb), (wb / 2, wb), (1, wb + 3), (rl - 1, 2 * rl + 1), (wb - 1, 2), (2 * wb - 3, 7)];
                if n > 3 * wb {
                    ranges.push((wb + rl / 2, 2 * wb + 5));
                }
                for (off, len) in ranges {
                    let len = len.min(n - off);
                    let mut got = vec![0u8; len];
                    pt.fill_bytes(off, &mut got);
                    assert!(got == want[off..off + len], "fill_bytes({off}, {len}) at {d}x{f}");
                }
                // the CHUNKED form: successive pieces reassemble the buffer
                for chunk in [wb, wb / 4 + 1, 3 * wb / 2, rl, 1000] {
                    let mut all: Vec<u8> = Vec::with_capacity(n);
                    let mut off = 0usize;
                    while off < n {
                        let m = chunk.min(n - off);
                        let mut piece = vec![0u8; m];
                        pt.fill_bytes(off, &mut piece);
                        all.extend_from_slice(&piece);
                        off += m;
                    }
                    assert!(all == want, "chunked fill (chunk {chunk}) at {d}x{f}");
                }
            }
        }

        #[test]
        fn a_shape_that_does_not_tile_is_declined() {
            let (d, f) = (96usize, 192usize);
            let (wg, wu, wd) = (plane(d * f, 7), plane(d * f, 8), plane(f * d, 9));
            assert!(PlaneTiling::new(&wg, &wu, &wd, d, f, 32, 64, 2, 3).is_err(), "wrong nb_d accepted");
            assert!(PlaneTiling::new(&wg, &wu, &wd, d, f, 0, 64, 3, 3).is_err(), "zero block accepted");
            assert!(PlaneTiling::new(&wg, &wu[..d * f - 1], &wd, d, f, 32, 64, 3, 3).is_err(), "short plane accepted");
        }

        #[test]
        fn overflowing_tiling_products_are_declined_without_large_allocations() {
            let hi = 1usize << (usize::BITS - 1);
            // These products previously wrapped to exactly the claimed
            // dimension/plane length in a release build.
            assert!(PlaneTiling::new(&[], &[], &[], 0, 1, hi, 1, 2, 1).is_err());
            assert!(PlaneTiling::new(&[1, 2], &[3, 4], &[5, 6], 2, 1, hi + 1, 1, 2, 1).is_err());
            assert!(PlaneTiling::new(&[], &[], &[], hi, 2, hi, 2, 1, 1).is_err());
            // Each plane's length fits, but the three-plane total does not.
            assert!(PlaneTiling::new(&[], &[], &[], hi, 1, hi, 1, 1, 1).is_err());
        }

        #[test]
        fn invalid_ranges_are_refused_before_writing_the_destination() {
            let plane = [1i8; 8];
            let pt = PlaneTiling::new(&plane, &plane, &plane, 2, 4, 2, 2, 1, 2).unwrap();
            pt.fill_bytes(pt.len(), &mut []); // the valid empty suffix
            for (off, len) in [(usize::MAX - 1, 2), (pt.len() - 1, 2), (pt.len() + 1, 0)] {
                let mut dst = vec![0xa5; len];
                let err = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| pt.fill_bytes(off, &mut dst)))
                    .expect_err("invalid plane range accepted");
                let msg = err.downcast_ref::<String>().map(String::as_str)
                    .or_else(|| err.downcast_ref::<&str>().copied()).unwrap_or("");
                assert!(msg.starts_with("plane fill "), "wrong refusal: {msg}");
                assert!(dst.iter().all(|&v| v == 0xa5));
            }
        }
    }
}

pub use planes::PlaneTiling;

/// [ZK60-CL20] The adapter side of `zkp_core::pcs`'s backend seam. The
/// core's commitment offers its encode-and-hash to a `Backend`; this is the
/// one hashline plugs in. With the feature, `CudaBackend` keeps the runtime
/// toggle (`enabled()`, i.e. `HL_GPU=1` plus a device that initialised) and
/// the exact decline messages the logs and `tests/test_hashline_cl_profile.py`
/// expect, and `DevCommit` is the core's `EncodedStore` through
/// `dev_fold_rows` / `dev_columns`. Without the feature the backend is the
/// core's `Cpu` and the store type is uninhabited, so no device arm exists.
#[cfg(feature = "gpu-cuda")]
mod seam {
    use super::cuda::{dev_columns, dev_commit, dev_commit_zk, dev_fold_rows, enabled, DevCommit};
    use crate::field::{Fp, Fp2};
    use crate::merkle::Digest;
    use crate::ntt::NttTables;
    use zkp_core::pcs::{Backend, EncodedStore, PcsParams};

    /// The store type hashline's commitments carry: the device-resident encoding.
    pub type DevStore = DevCommit;

    pub struct CudaBackend;

    /// The backend `pcs::commit` / `pcs::commit_zk` offer their work to.
    pub fn backend() -> CudaBackend {
        CudaBackend
    }

    impl EncodedStore for DevCommit {
        fn fold_rows(&self, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String> {
            dev_fold_rows(self, rhos)
        }
        fn columns(&self, idx: &[usize]) -> Result<Vec<Vec<Fp>>, String> {
            dev_columns(self, idx)
        }
    }

    impl Backend for CudaBackend {
        type Store = DevCommit;
        // [UPERF3-XX] the device path (HL_GPU=1): the same encoding and the same leaves; Err -> the CPU body.
        fn try_commit(&self, params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Option<(DevCommit, Vec<Digest>)> {
            if !enabled() {
                return None;
            }
            match dev_commit(params, data, ntt) {
                Ok(x) => Some(x),
                Err(e) => {
                    super::declined("[UPERF3-XX] gpu commit", &e);
                    None
                }
            }
        }
        fn try_commit_zk_keyed(&self, params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables, key: &[u8; 32]) -> Option<(DevCommit, Vec<Digest>)> {
            if !enabled() { return None; }
            match super::cuda::dev_commit_zk_keyed(params, data, pads, pows, ntt, key) {
                Ok(x) => {
                    if std::env::var("HL_GPU_REQUIRED").ok().as_deref() == Some("1") {
                        eprintln!("[ZK60] keyed gpu zk commit accepted");
                    }
                    Some(x)
                },
                Err(e) => { super::declined("[ZK60] keyed gpu zk commit", &e); None }
            }
        }
        // [UPERF3-ZA] the device path (rung 4): the same coset encoding on the device, leaves back, salted by the core.
        fn try_commit_zk(&self, params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Option<(DevCommit, Vec<Digest>)> {
            if !enabled() {
                return None;
            }
            match dev_commit_zk(params, data, pads, pows, ntt) {
                Ok(x) => Some(x),
                Err(e) => {
                    super::declined("[UPERF3-ZA] gpu zk commit", &e);
                    None
                }
            }
        }
    }
}

#[cfg(feature = "gpu-cuda")]
pub use seam::{backend, CudaBackend, DevStore};

/// [ZK60-METAL] The same seam on the Apple GPU: `MetalCommit` (the encoding in
/// unified memory) is the store; a decline runs the CPU body with the exact
/// messages' pattern the CUDA seam uses.
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
mod seam {
    use super::metal::{enabled, metal_commit, metal_commit_zk, MetalCommit};
    use crate::field::{Fp, Fp2};
    use crate::merkle::Digest;
    use crate::ntt::NttTables;
    use zkp_core::pcs::{Backend, EncodedStore, PcsParams};

    pub type DevStore = MetalCommit;

    pub struct MetalBackend;

    pub fn backend() -> MetalBackend {
        MetalBackend
    }

    impl EncodedStore for MetalCommit {
        fn fold_rows(&self, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String> {
            MetalCommit::fold_rows(self, rhos)
        }
        fn columns(&self, idx: &[usize]) -> Result<Vec<Vec<Fp>>, String> {
            MetalCommit::columns(self, idx)
        }
        fn fold_batch(&self) -> usize {
            usize::MAX // unified memory: one pass over the data for every vector
        }
    }

    impl Backend for MetalBackend {
        type Store = MetalCommit;
        fn try_commit(&self, params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Option<(MetalCommit, Vec<Digest>)> {
            if !enabled() {
                return None;
            }
            match metal_commit(params, data, ntt) {
                Ok(x) => Some(x),
                Err(e) => {
                    super::declined("[ZK60-METAL] metal commit", &e);
                    None
                }
            }
        }
        fn try_commit_zk_keyed(&self, params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables, key: &[u8; 32]) -> Option<(MetalCommit, Vec<Digest>)> {
            if !enabled() {
                return None;
            }
            match metal_commit_zk(params, data, pads, pows, ntt, Some(key)) {
                Ok(x) => Some(x),
                Err(e) => {
                    super::declined("[ZK60-METAL] keyed metal zk commit", &e);
                    None
                }
            }
        }
        fn try_commit_zk(&self, params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Option<(MetalCommit, Vec<Digest>)> {
            if !enabled() {
                return None;
            }
            match metal_commit_zk(params, data, pads, pows, ntt, None) {
                Ok(x) => Some(x),
                Err(e) => {
                    super::declined("[ZK60-METAL] metal zk commit", &e);
                    None
                }
            }
        }
    }
}

#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
pub use seam::{backend, DevStore, MetalBackend};

#[cfg(not(any(feature = "gpu-cuda", feature = "gpu-metal")))]
mod seam {
    /// Without the feature no external store exists (the type has no values).
    pub type DevStore = zkp_core::pcs::NoExternal;

    /// The core's CPU backend: never takes over.
    pub fn backend() -> zkp_core::pcs::Cpu {
        zkp_core::pcs::Cpu
    }
}

#[cfg(not(any(feature = "gpu-cuda", feature = "gpu-metal")))]
pub use seam::{backend, DevStore};

#[cfg(not(any(feature = "gpu-cuda", feature = "gpu-metal")))]
mod switch {
    /// The GPU path is never live without the `gpu-cuda` feature.
    #[inline(always)]
    pub fn enabled() -> bool {
        false
    }
    /// Human-readable state.
    pub fn label() -> String {
        "gpu: off (built without --features gpu-cuda)".to_string()
    }
}
#[cfg(not(any(feature = "gpu-cuda", feature = "gpu-metal")))]
pub use switch::{enabled, label};
#[cfg(all(feature = "gpu-metal", not(feature = "gpu-cuda")))]
pub use metal::{enabled, label};

#[cfg(not(feature = "gpu-cuda"))]
mod stub {
    #[derive(Clone, Debug, Default)]
    pub struct ProbeReport {
        pub device: String,
        pub n: usize,
        pub mismatches: usize,
        pub gmul_per_s: f64,
    }
    pub fn probe() -> Result<ProbeReport, String> {
        Err("built without --features gpu-cuda".to_string())
    }
    #[derive(Clone, Debug, Default)]
    pub struct GpuStats {
        pub secs_h2d: f64,
        pub secs_ntt: f64,
        pub secs_hash: f64,
        pub secs_d2h: f64,
        pub secs_sumcheck: f64,
        pub secs_fold: f64,
        pub secs_helpers: f64,
        pub bytes_h2d: u64,
        pub bytes_d2h: u64,
        pub vram_peak: u64,
        pub secs_reenc: f64,
        pub n_chunked: u64,
    }
    pub fn dev_stats() -> GpuStats {
        GpuStats::default()
    }
    pub fn dev_stats_reset() {}
}

#[cfg(not(feature = "gpu-cuda"))]
pub use stub::{dev_stats, dev_stats_reset, probe, GpuStats, ProbeReport};

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

#[cfg(feature = "gpu-cuda")]
pub use cuda::{
    dev_columns, dev_commit, dev_commit_check, dev_commit_from, dev_eval_many, dev_fold_rows, dev_hash_check, dev_helpers, dev_stats,
    dev_stats_reset, dev_zerocheck, enabled, label, probe, DevCommit, GpuStats, HelperSpec, Pooled, ProbeReport, TabSpec,
};
// [UPERF3-ZA] the ZK commitment's device entries (new functions in cuda.rs)
#[cfg(feature = "gpu-cuda")]
pub use cuda::{dev_commit_zk, dev_commit_zk_from, dev_upload_rows};
// [UPERF3-AC] the cached-W device entry (upload + encode, no hash) and the chunked-commit probe
#[cfg(feature = "gpu-cuda")]
pub use cuda::{dev_commit_check_chunked, dev_commit_zk_check_chunked, dev_encode_only};
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
                    eprintln!("[UPERF3-XX] gpu commit declined ({e}); CPU path");
                    None
                }
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
                    eprintln!("[UPERF3-ZA] gpu zk commit declined ({e}); CPU path");
                    None
                }
            }
        }
    }
}

#[cfg(feature = "gpu-cuda")]
pub use seam::{backend, CudaBackend, DevStore};

#[cfg(not(feature = "gpu-cuda"))]
mod seam {
    /// Without the feature no external store exists (the type has no values).
    pub type DevStore = zkp_core::pcs::NoExternal;

    /// The core's CPU backend: never takes over.
    pub fn backend() -> zkp_core::pcs::Cpu {
        zkp_core::pcs::Cpu
    }
}

#[cfg(not(feature = "gpu-cuda"))]
pub use seam::{backend, DevStore};

#[cfg(not(feature = "gpu-cuda"))]
mod stub {
    /// The GPU path is never live without the `gpu-cuda` feature.
    #[inline(always)]
    pub fn enabled() -> bool {
        false
    }
    /// Human-readable state.
    pub fn label() -> String {
        "gpu: off (built without --features gpu-cuda)".to_string()
    }
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
pub use stub::{dev_stats, dev_stats_reset, enabled, label, probe, GpuStats, ProbeReport};

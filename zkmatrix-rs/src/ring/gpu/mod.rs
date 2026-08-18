// [UPERF2-K] The GPU rung (CONTINUATION.md Section 4, Phase 3) — step 1.
//
// CUDA ports of the NTT-domain kernels, feature-gated (`gpu-cuda`, default
// OFF: the default build and the Mac build never see cudarc) and runtime-
// gated (`ZK_GPU=1` AND a device initializes). The kernels are CUDA C
// strings (`kernels.cu`, `include_str!`) compiled ONCE per process by
// NVRTC through cudarc's driver API — no CUDA toolkit on the box, only the
// driver (libcuda) and the NVRTC runtime library.
//
// DIFFERENTIAL DISCIPLINE (the PERF RULE): every GPU entry point computes
// the SAME exact-integer quantity as the CPU kernel it replaces —
// `ntt_gemm_modq_small`'s windows are exact integer partial sums recovered
// from Z_p under the single-prime capacity contract, so the GPU's output
// is bit-identical by construction as long as (a) its Goldilocks
// arithmetic yields canonical values (ported op-for-op from
// aux_ntt_core.rs), (b) the window boundaries are the CPU's
// (`ntt_window_terms(q, s_max)`, identical call), (c) the split-halves
// sums are the same integers (128-bit exact) and the flush applies the
// same `gl_reduce128(acc_lo + EPS*acc_hi)` -> inverse NTT -> center -> mod
// q -> add. The CPU kernel stays the oracle: `uperf-k battery` compares
// cell-by-cell at both moduli; `uperf-pc diff-battery` under `ZK_GPU=1`
// runs the O2/O3/E2E legs through the hook; the REAL rigs' digests are the
// gate.
//
// ONE hook per ported kernel: `eval_proof::ntt_gemm_modq_small_gen` asks
// `gpu::enabled()` at the top of its body and returns the GPU result when
// the port accepts the call (`Some`); `None` (feature off, ZK_GPU unset,
// no device, over capacity, below the minimum work, or a device error —
// reported once) means the CPU body runs as before.
//
// Knobs (all runtime; none changes a value): ZK_GPU=1 (on),
// ZK_GPU_MIN_MACS (decline smaller GEMMs; default 1<<22 D-domain MACs),
// ZK_GPU_BLOCK_MB (device budget for one u-block, default 256),
// ZK_GPU_STAGES (sub-blocks per call the pipeline aims for, default 4),
// ZK_GPU_VERBOSE=1 (per-call timing lines to stderr), ZK_GPU_PROFILE=1
// (synchronize after every kernel and attribute per kernel — analysis
// only), ZK_GPU_RFWD / ZK_GPU_TFWD / ZK_GPU_MAXRREG (NVRTC-time kernel
// shape experiments).

#[cfg(feature = "gpu-cuda")]
mod cuda;
// [UPERF2-L] The GPU rung, step 2: the K-field lane kernels (descent round,
// ixf round + fold, tree step) on the device — see k9.rs / kernels_k9.cu.
#[cfg(feature = "gpu-cuda")]
mod k9;

#[cfg(feature = "gpu-cuda")]
pub use cuda::{
    enabled, label, ntt_batch, ntt_gemm_modq_small, ntt_gemm_modq_small_force, probe, set_block_mb, set_bypass, stats,
    stats_reset, GpuStats, ProbeReport,
};
#[cfg(feature = "gpu-cuda")]
pub use k9::{k9_fused_round, k9_ixf_round, k9_label, k9_set_cold_ok, k9_set_eager, k9_set_min_pairs, k9_set_tree, k9_stats, k9_stats_reset, k9_tree_climb, kt_fold, K9Stats};

// ---------------------------------------------------------------------------
// The stub (default build): the hook compiles to a constant-false test.

#[cfg(not(feature = "gpu-cuda"))]
mod stub {
    use super::super::eval_proof::SmallRings;
    use super::super::{Poly, RingCtx};

    /// The GPU path is never live without the `gpu-cuda` feature.
    #[inline(always)]
    pub fn enabled() -> bool {
        false
    }
    /// Harness knob (no-op without the feature).
    pub fn set_bypass(_on: bool) {}
    /// Harness knob (no-op without the feature).
    pub fn set_block_mb(_mb: usize) {}
    /// Human-readable state.
    pub fn label() -> String {
        "gpu: off (built without --features gpu-cuda)".to_string()
    }
    /// Never called without the feature (the hook is gated by `enabled()`).
    pub fn ntt_gemm_modq_small<B: SmallRings + ?Sized>(_ctx: &RingCtx, _a: &[&[Poly]], _b: &[&B], _len: usize) -> Option<Vec<Poly>> {
        None
    }
    pub fn ntt_gemm_modq_small_force<B: SmallRings + ?Sized>(_ctx: &RingCtx, _a: &[&[Poly]], _b: &[&B], _len: usize) -> Option<Vec<Poly>> {
        None
    }
    /// Battery helper: transforms on the device (unavailable here).
    pub fn ntt_batch(_rings: &[[u64; super::super::D]], _inverse: bool) -> Result<Vec<[u64; super::super::D]>, String> {
        Err("built without --features gpu-cuda".to_string())
    }
    #[derive(Clone, Debug, Default)]
    pub struct ProbeReport {
        pub device: String,
        pub mismatches: usize,
        pub n: usize,
        pub gmul_per_s: f64,
    }
    pub fn probe() -> Result<ProbeReport, String> {
        Err("built without --features gpu-cuda".to_string())
    }
    /// Mirrors `cuda::GpuStats` (all zero without the feature).
    #[derive(Clone, Debug, Default)]
    pub struct GpuStats {
        pub calls: u64,
        pub declined: u64,
        pub macs: u128,
        pub bytes_h2d: u64,
        pub secs_smax: f64,
        pub secs_pack: f64,
        pub secs_wait: f64,
        pub secs_k_h2d: f64,
        pub secs_k_fwd: f64,
        pub secs_k_gemm: f64,
        pub secs_k_flush: f64,
        pub secs_d2h: f64,
        pub secs_total: f64,
    }
    pub fn stats() -> GpuStats {
        GpuStats::default()
    }
    pub fn stats_reset() {}

    // ---- [UPERF2-L] the K-field kernels' hooks (never live without the feature).
    use super::super::kfield::{BlkSrc, FusedPlan, KElem, KField, KKern, KTab, K_DEG};
    /// The fused descent round: `Err(tabs)` = the CPU body runs.
    #[allow(clippy::too_many_arguments)]
    pub fn k9_fused_round<'a>(
        _kern: &KKern,
        _plan: &FusedPlan,
        _n_pairs: usize,
        _eq_inplace: &mut [u32],
        _eq_src: &[u32],
        _eq_dst: &mut [u32],
        tabs: [&'a mut [u32]; 4],
        _nodes: &[u64],
        _node_consts: Option<&[[[u32; K_DEG]; 4]]>,
        _acc_lo: &mut [u64],
        _acc_hi: &mut [u64],
    ) -> Result<(), [&'a mut [u32]; 4]> {
        Err(tabs)
    }
    pub fn k9_ixf_round(_kern: &KKern, _kind: u8, _tabs: &[&[u32]], _nblk_pairs: usize, _deg: usize, _acc_lo: &mut [u64], _acc_hi: &mut [u64]) -> Option<()> {
        None
    }
    pub fn kt_fold(_kf: &KField, _t: &mut KTab, _scratch: &mut Vec<u32>, _r: &KElem) -> Option<()> {
        None
    }
    pub fn k9_tree_climb(_kern: &KKern, _src: &BlkSrc, _levels: usize, _np: &mut [u32], _nq: &mut [u32], _out_nblk: usize) -> Option<()> {
        None
    }
    pub fn k9_set_min_pairs(_p: usize) {}
    pub fn k9_set_eager(_on: bool) {}
    pub fn k9_set_cold_ok(_on: bool) {}
    pub fn k9_set_tree(_on: Option<bool>) {}
    pub fn k9_label() -> String {
        "k9: off (built without --features gpu-cuda)".to_string()
    }
    /// Mirrors `k9::K9Stats` (all zero without the feature).
    #[derive(Clone, Debug, Default)]
    pub struct K9Stats {
        pub rounds: u64,
        pub declined: u64,
        pub layer_uploads: u64,
        pub layer_hits: u64,
        pub bytes_h2d: u64,
        pub bytes_d2h: u64,
        pub secs_round: f64,
        pub secs_upload: f64,
        pub secs_encode: f64,
        pub secs_handover: f64,
        pub ixf_rounds: u64,
        pub ixf_folds: u64,
        pub ixf_hits: u64,
        pub secs_ixf: f64,
        pub climbs: u64,
        pub secs_climb: f64,
        pub secs_climb_d2h: f64,
        pub secs_kernel: f64,
        pub secs_up_memcpy: f64,
        pub secs_up_wait: f64,
    }
    pub fn k9_stats() -> K9Stats {
        K9Stats::default()
    }
    pub fn k9_stats_reset() {}
}

#[cfg(not(feature = "gpu-cuda"))]
pub use stub::*;

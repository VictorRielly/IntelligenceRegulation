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
// Knobs (all runtime): ZK_GPU=1 (on), ZK_GPU_MIN_MACS (decline smaller
// GEMMs; default 1<<22 D-domain MACs), ZK_GPU_BLOCK_MB (device budget for
// one transformed u-block, default 512), ZK_GPU_VERBOSE=1 (per-call
// timing lines to stderr).

#[cfg(feature = "gpu-cuda")]
mod cuda;

#[cfg(feature = "gpu-cuda")]
pub use cuda::{
    enabled, label, ntt_batch, ntt_gemm_modq_small, ntt_gemm_modq_small_force, probe, set_block_mb, set_bypass, stats,
    stats_reset, GpuStats, ProbeReport,
};

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
    #[derive(Clone, Debug, Default)]
    pub struct GpuStats {
        pub calls: u64,
        pub declined: u64,
        pub macs: u128,
        pub bytes_h2d: u64,
        pub secs_pack: f64,
        pub secs_h2d: f64,
        pub secs_gpu: f64,
        pub secs_total: f64,
    }
    pub fn stats() -> GpuStats {
        GpuStats::default()
    }
    pub fn stats_reset() {}
}

#[cfg(not(feature = "gpu-cuda"))]
pub use stub::*;

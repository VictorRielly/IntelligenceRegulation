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
pub use cuda::{dev_stats, dev_stats_reset, enabled, label, probe, GpuStats, ProbeReport};

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
    }
    pub fn dev_stats() -> GpuStats {
        GpuStats::default()
    }
    pub fn dev_stats_reset() {}
}

#[cfg(not(feature = "gpu-cuda"))]
pub use stub::{dev_stats, dev_stats_reset, enabled, label, probe, GpuStats, ProbeReport};

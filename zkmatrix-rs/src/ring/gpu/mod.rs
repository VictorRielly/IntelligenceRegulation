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
    enabled, imad_probe, label, ntt_batch, ntt_gemm_modq_small, ntt_gemm_modq_small_force, probe, set_block_mb, set_bypass, stats,
    stats_reset, GpuStats, ProbeReport,
};
#[cfg(feature = "gpu-cuda")]
pub use k9::{k9_fused_round, k9_ixf_round, k9_label, k9_set_cold_ok, k9_set_eager, k9_set_min_pairs, k9_set_tree, k9_stats, k9_stats_reset, k9_tree_climb, kt_fold, K9Stats};
// [UPERF2-N] The device tree store (k9.rs): the descent tree built and kept
// on the device, read in place by the fused rounds, materialized on demand
// for CPU readers.
#[cfg(feature = "gpu-cuda")]
pub use k9::{k9_set_tree_store, k9_tree_build, k9_tree_bytes, k9_tree_drop, k9_tree_fetch, k9_tree_release};
// [UPERF2-P] The GPU rung, step 4 (k9.rs): the eq b-part built on the device,
// one launch per fused round, the store's buffer pool + warm allocations,
// this lane's stats and knobs.
#[cfg(feature = "gpu-cuda")]
pub use k9::{k9_eq_build, k9_eq_drop, k9_eq_fetch, k9_kprobe, k9_set_eq_dev, k9_set_kvar, k9_set_multi, k9p_stats, k9p_stats_reset, K9PStats};
// [UPERF2-O] The GPU rung, step 3: the claim layer's zero-check tables built
// on the device + the device-resident ixf chain — see ixf.rs / kernels_ixf.cu.
#[cfg(feature = "gpu-cuda")]
mod ixf;
#[cfg(feature = "gpu-cuda")]
pub use ixf::{
    ixf_label, ixf_release, ixf_set_bypass, ixf_set_low_bits, ixf_set_min_pairs, ixf_stats, ixf_stats_reset, ixf_zc_abort, ixf_zc_fold, ixf_zc_handover, ixf_zc_open,
    ixf_zc_round, IxfDevChain, IxfStats,
};
// [UPERF2-Q] The level-h device session (cuda.rs): the level-0 h table
// accumulated on the device across the u-blocks (value-ring pool + limb
// radix expanded on the device, resident split-halves accumulator, one
// flush per exact-integer window) — the hook in
// `eval_proof::level_h_pairs_with_block`.
#[cfg(feature = "gpu-cuda")]
pub use cuda::{level_h_stream, level_h_stream_force, lh_stats, lh_stats_reset, set_lh_block, set_lh_session, LhStats};
// [UPERF2-Q] The combine session (cuda.rs): few fixed small rings x many
// streamed slices -> one inverse per output (the fold, the factored psi,
// the transport's limb-split combines, compute_psi).
#[cfg(feature = "gpu-cuda")]
pub use cuda::{cb_stats, cb_stats_reset, combine_accepts, combine_stream, set_cb_block, set_cb_session, CbStats, CombineOut, CombineResult, CombineSrc};
// [UPERF2-Q] The commit phase's chain GEMM (int8 x int8 -> i32, exact) on the device.
#[cfg(feature = "gpu-cuda")]
pub use cuda::{matmul_i8, mm_stats};

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
    /// [UPERF2-O] instruction-throughput probe (unavailable here).
    pub fn imad_probe(_mode: i32, _iters: i32, _blocks: u32) -> Result<f64, String> {
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
    use super::super::kfield::{BlkSrc, DevLayer, DevTreeBuilt, FusedPlan, KElem, KField, KKern, KTab, TreeLeaves, K_DEG};

    // ---- [UPERF2-N] the device tree store (never live without the feature).
    /// The device build: `None` = the CPU build runs.
    pub fn k9_tree_build(_kern: &KKern, _leaves: &TreeLeaves, _depth: usize) -> Option<DevTreeBuilt> {
        None
    }
    /// Never called without the feature (no device tree exists).
    pub fn k9_tree_fetch(_dev: DevLayer) -> Option<(KTab, KTab)> {
        None
    }
    pub fn k9_tree_release(_tree: u64, _k: usize) {}
    pub fn k9_tree_drop(_tree: u64) {}
    pub fn k9_tree_bytes(_tree: u64) -> usize {
        0
    }
    pub fn k9_set_tree_store(_on: Option<bool>) {}
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
        // [UPERF2-N]
        pub tree_builds: u64,
        pub tree_declined: u64,
        pub secs_tree_build: f64,
        pub bytes_tree_leaves: u64,
        pub layer_resident: u64,
        pub dev_climbs: u64,
        pub secs_dev_climb: f64,
        pub tree_fetches: u64,
        pub secs_tree_fetch: f64,
        pub tree_bytes_peak: u64,
        pub held_peak: u64,
    }
    pub fn k9_stats() -> K9Stats {
        K9Stats::default()
    }
    pub fn k9_stats_reset() {}

    // ---- [UPERF2-P] the device eq build / one-launch rounds / pool (never live without the feature).
    /// The device eq b-part build: `None` = the host build runs.
    pub fn k9_eq_build(_kf: &KField, _zeta: &[KElem]) -> Option<u64> {
        None
    }
    pub fn k9_eq_drop(_id: u64) {}
    pub fn k9_eq_fetch(_id: u64) -> Option<Vec<u32>> {
        None
    }
    pub fn k9_set_multi(_on: Option<bool>) {}
    pub fn k9_set_eq_dev(_on: Option<bool>) {}
    pub fn k9_set_kvar(_v: Option<u32>) {}
    pub fn k9_kprobe(_kern: &KKern, _chains: u32, _blocks_per_sm: u32, _tpb: u32, _iters: u32) -> Result<(f64, f64, u32), String> {
        Err("built without --features gpu-cuda".to_string())
    }
    /// Mirrors `k9::K9PStats` (all zero without the feature).
    #[derive(Clone, Debug, Default)]
    pub struct K9PStats {
        pub rounds_multi: u64,
        pub rounds_split: u64,
        pub launches: u64,
        pub eq_builds: u64,
        pub eq_binds: u64,
        pub eq_host: u64,
        pub secs_eq_build: f64,
        pub pool_hits: u64,
        pub pool_misses: u64,
        pub pool_trims: u64,
        pub secs_alloc: f64,
        pub secs_tb_upload: f64,
        pub secs_tb_alloc: f64,
        pub secs_tb_down: f64,
    }
    pub fn k9p_stats() -> K9PStats {
        K9PStats::default()
    }
    pub fn k9p_stats_reset() {}

    // ---- [UPERF2-O] the device-built zero-check tables + chain (never live without the feature).
    use super::super::fold::IxfZcSpec;
    /// The device chain handle (never constructed without the feature).
    pub struct IxfDevChain {
        pub n: usize,
        pub t: usize,
    }
    impl IxfDevChain {
        pub fn device_next(&self) -> bool {
            false
        }
    }
    pub fn ixf_zc_open(_kf: &KField, _spec: &IxfZcSpec) -> Option<IxfDevChain> {
        None
    }
    pub fn ixf_zc_round(_kf: &KField, _ch: &mut IxfDevChain, _deg: usize) -> Result<Vec<KElem>, String> {
        Err("built without --features gpu-cuda".to_string())
    }
    pub fn ixf_zc_fold(_kf: &KField, _ch: &mut IxfDevChain, _r: &KElem) -> Result<(), String> {
        Err("built without --features gpu-cuda".to_string())
    }
    pub fn ixf_zc_handover(_kf: &KField, _ch: IxfDevChain) -> Result<Vec<KTab>, String> {
        Err("built without --features gpu-cuda".to_string())
    }
    pub fn ixf_zc_abort(_ch: IxfDevChain) {}
    pub fn ixf_release() {}
    pub fn ixf_set_bypass(_on: bool) {}
    pub fn ixf_set_min_pairs(_p: usize) {}
    pub fn ixf_set_low_bits(_b: usize) {}
    pub fn ixf_label() -> String {
        "ixf: off (built without --features gpu-cuda)".to_string()
    }
    /// Mirrors `ixf::IxfStats` (all zero without the feature).
    #[derive(Clone, Debug, Default)]
    pub struct IxfStats {
        pub instances: u64,
        pub declined: u64,
        pub rounds: u64,
        pub folds: u64,
        pub bytes_h2d: u64,
        pub secs_open: f64,
        pub secs_upload: f64,
        pub secs_build: f64,
        pub secs_round: f64,
        pub secs_fold: f64,
        pub secs_handover: f64,
        pub secs_host_small: f64,
    }
    pub fn ixf_stats() -> IxfStats {
        IxfStats::default()
    }
    pub fn ixf_stats_reset() {}

    // ---- [UPERF2-Q] the level-h device session (never live without the feature).
    use super::super::eval_proof::Phi0Source;
    /// The session: `None` = the CPU body runs.
    pub fn level_h_stream<B: SmallRings + ?Sized>(_ctx: &RingCtx, _src: &Phi0Source, _w: &[&B], _chunk: usize, _block: usize) -> Option<Vec<Poly>> {
        None
    }
    pub fn level_h_stream_force<B: SmallRings + ?Sized>(_ctx: &RingCtx, _src: &Phi0Source, _w: &[&B], _chunk: usize, _block: usize) -> Option<Vec<Poly>> {
        None
    }
    /// Mirrors `cuda::LhStats` (all zero without the feature).
    #[derive(Clone, Debug, Default)]
    pub struct LhStats {
        pub sessions: u64,
        pub declined: u64,
        pub stages: u64,
        pub flushes: u64,
        pub bytes_h2d: u64,
        pub secs_smax: f64,
        pub secs_fill: f64,
        pub secs_wait: f64,
        pub secs_total: f64,
        pub secs_grow: f64,
        pub secs_enq: f64,
    }
    pub fn lh_stats() -> LhStats {
        LhStats::default()
    }
    pub fn lh_stats_reset() {}
    pub fn set_lh_block(_n: usize) {}
    pub fn set_lh_session(_on: bool) {}
    // ---- [UPERF2-Q] the combine session (never live without the feature).
    pub enum CombineSrc<'a, B: SmallRings + ?Sized> {
        Pool(&'a Phi0Source),
        Small(&'a [&'a B]),
        ModQ(&'a [&'a [Poly]]),
    }
    #[derive(Clone, Copy, PartialEq, Eq)]
    pub enum CombineOut {
        ModQ { two_l: Option<u64> },
        ExactI64,
    }
    pub enum CombineResult {
        ModQ(Vec<Poly>),
        I64(Vec<Vec<i64>>),
    }
    pub fn combine_accepts(_q: u64, _k: usize, _chunk: usize, _n_out: usize) -> bool {
        false
    }
    #[allow(clippy::too_many_arguments)]
    pub fn combine_stream<B: SmallRings + ?Sized>(
        _q: u64,
        _c: &[Vec<i64>],
        _src: CombineSrc<'_, B>,
        _k: usize,
        _chunk: usize,
        _n_out: usize,
        _out: CombineOut,
        _force: bool,
    ) -> Option<CombineResult> {
        None
    }
    /// Mirrors `cuda::CbStats` (all zero without the feature).
    #[derive(Clone, Debug, Default)]
    pub struct CbStats {
        pub sessions: u64,
        pub declined: u64,
        pub stages: u64,
        pub bytes_h2d: u64,
        pub secs_fill: f64,
        pub secs_wait: f64,
        pub secs_total: f64,
    }
    pub fn cb_stats() -> CbStats {
        CbStats::default()
    }
    pub fn cb_stats_reset() {}
    pub fn set_cb_session(_on: bool) {}
    pub fn set_cb_block(_n: usize) {}
    /// The chain GEMM: `None` = the CPU body runs.
    pub fn matmul_i8(_a: &[i64], _b_t: &[i64], _rows: usize, _inner: usize, _cols: usize) -> Option<Vec<i64>> {
        None
    }
    pub fn mm_stats() -> (u64, f64) {
        (0, 0.0)
    }
}

#[cfg(not(feature = "gpu-cuda"))]
pub use stub::*;

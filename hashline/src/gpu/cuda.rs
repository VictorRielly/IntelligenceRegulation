// [UPERF3-XX] The CUDA implementation of hashline's GPU port (feature
// `gpu-cuda`). See mod.rs for the discipline; kernels.cu for the device
// code. Bootstrap copied from zkmatrix-rs/src/ring/gpu/cuda.rs: one device
// singleton, NVRTC compile of the kernel source once per process, a
// runtime toggle (`HL_GPU=1`), a probe against the CPU field.

use crate::field::{Fp, Fp2, P};
use crate::sumcheck::{ProverOutput, SumcheckProof};
use crate::transcript::Transcript;
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::PcsParams;
use cudarc::driver::result as cu;
use cudarc::driver::{sys, CudaDevice, CudaSlice, CudaView, DevicePtr, DevicePtrMut, DeviceSlice, LaunchAsync, LaunchConfig};
use cudarc::nvrtc::{compile_ptx_with_opts, CompileOptions};
use rayon::prelude::*;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;
// [ZK60-CL15] the openings' pure index plan (mod.rs; compiled without the feature too)
use super::open_plan::{plan_open_indices, residue_list, OpenPlan};
use super::planes::PlaneTiling;

const KSRC: &str = include_str!("kernels.cu");
const MODULE: &str = "hlgpu";
const FUNCS: &[&str] = &[
    "k_probe", "k_ntt_p1", "k_ntt_p2", "k_gather_cols", "k_hash_cols",
    "k_sc_round_zc20", "k_sc_round_zc17", "k_reduce_f2", "k_sc_fold", "k_tab_from_fp", "k_tab_from_fp2", "k_eq_table",
    "k_fold_rows", "k_helper", "k_sum_fp", "k_eq_join", "k_dot_slices", "k_dif_pa", "k_dif_pb", "k_dit_p1_pad",
    "k_zk_pad_scale", // [UPERF3-ZA]
    "k_hash_cols_stream", "k_gather_cols_off", // [UPERF3-AC]
    "k_sc_round_zcf_gen", "k_sc_round_zcd_gen", "k_sc_round_tab_gen", // [UPERF3-AH]
    "k_ntt_p2_gather", "k_widen", // [UPERF3-AJ]
    // [UPERF3-AO] lever L9: the same transforms with the power-of-two tile
    // indexing strength-reduced, and the zero-padding stages of the forward
    // DIT's first pass dropped. Same values, byte for byte.
    "k_dif_pa_f", "k_ntt_p2_f", "k_ntt_p2_gather_f", "k_dit_p1_pad_s",
    "k_ntt_p2_gather_sp",
    // [FSP-L9] the same two contiguous-tile transforms on the permuted
    // shared-memory layout that removes the low stages' 2-way bank
    // conflicts (kernels.cu `shz`). Same values, byte for byte.
    "k_dit_p1_pad_sz", "k_dif_pb_z",
    // [FSP-L9] the opening's expand transform writing only the residues its
    // one consumer reads, and that consumer reading the compact block.
    "k_dit_p1_pad_c", "k_dit_p1_pad_cz", "k_ntt_p2_gather_spc",
];
const SC_THREADS: u32 = 256;
const SC_MAX_BLOCKS: u32 = 1024;
/// [UPERF3-AH] the block-looping round kernels' block size and the shared
/// parameter array they can hold (kernels.cu: SCG_THREADS / SCG_MAX_PRM).
const SCG_THREADS: u32 = 128;
pub const SCG_MAX_PRM: usize = 384;
/// [ZK60-CL15] `pub` so the test file can pin the mirror the no-feature
/// `open_plan` tests use (`1 << 12`) to this, its owner.
pub const NTT_LOG_BLK: u32 = 12;
fn ntt_threads() -> u32 {
    static V: OnceLock<u32> = OnceLock::new();
    // [UPERF3-AJ] 256 -> 512: the NTT kernels hold a 32 KB shared tile, so
    // sm_89 fits 3 blocks per SM; at 256 threads that is 768 of the SM's
    // 1,536 threads (50% occupancy) and at 512 it is exactly 1,536.
    // Measured with `HL_GPU_CHUNK_ROWS=128` at the Mistral shape: 3.03 ->
    // 2.50 s for one layer, byte-identical (results/hashline_hostwall_gpu.md).
    *V.get_or_init(|| std::env::var("HL_GPU_NTT_THREADS").ok().and_then(|v| v.parse().ok()).unwrap_or(512u32).clamp(32, 1024))
}

/// [UPERF3-AO] lever L9. `HL_GPU_NTT_FAST=0` restores the divide-indexed
/// strided-tile kernels (`k_dif_pa`, `k_ntt_p2`, `k_ntt_p2_gather`); the
/// default `_f` forms index with a shift and a mask instead of a runtime
/// 32-bit integer division, and are bit-for-bit the same transform.
fn ntt_fast() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_NTT_FAST").map(|v| v != "0").unwrap_or(true))
}
/// [UPERF3-AO] lever L9. `HL_GPU_PAD_SKIP=0` restores the full 12-stage
/// `k_dit_p1_pad`; the default `_s` form drops the first `rb` stages,
/// which on an R = 2^rb-fold zero-padded bit-reversed input are a
/// broadcast, not arithmetic (see kernels.cu). Same output buffer.
fn pad_skip() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_PAD_SKIP").map(|v| v != "0").unwrap_or(true))
}
/// [FSP-L9] lever L9, the bank-conflict item lane AO named and did not
/// take — BUILT, MEASURED, AND WITHDRAWN. `HL_GPU_SMEM_SWZ=1` selects
/// `k_dit_p1_pad_sz`, which is `k_dit_p1_pad_s` on a permuted
/// shared-memory layout (kernels.cu `shz`) that provably removes the
/// 2-way bank conflicts of the surviving low stages (3 and 4 at every
/// shape of the 8B pass). It is a relabelling of shared addresses only:
/// the same operand pairs, the same twiddles, the same order, the same
/// global loads and stores — byte-identical.
///
/// It is **slower**. ABBA over four processes at 1,024 / 3,584 / 10,752
/// rows: 0.897x-1.012x, eleven of twelve measurements below parity, mean
/// about 0.93x (`results/fsp2_ab_s2.log`). The four extra integer
/// operations per butterfly cost more than the conflicts save, which
/// prices the residual conflicts at only about 4% of this kernel — not
/// the gap to the memory roof. DEFAULT OFF; kept behind the switch so the
/// measurement is reproducible and a future lane does not re-derive it.
fn smem_swz() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_SMEM_SWZ").map(|v| v != "0").unwrap_or(false))
}
/// [FSP-L9] the same permutation for `k_dif_pb`, and the same verdict:
/// 0.814x-0.936x over the same twelve measurements. `k_dif_pb` already
/// runs at 168-197 GB/s (66-77% of the 256 GB/s roof) on a quiet box, so
/// there was little there to win. DEFAULT OFF; `HL_GPU_SMEM_SWZ_PB=1`
/// turns it on.
fn smem_swz_pb() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_SMEM_SWZ_PB").map(|v| v != "0").unwrap_or(false))
}
fn kn_dif_pa() -> &'static str { if ntt_fast() { "k_dif_pa_f" } else { "k_dif_pa" } }
fn kn_ntt_p2() -> &'static str { if ntt_fast() { "k_ntt_p2_f" } else { "k_ntt_p2" } }
fn kn_ntt_p2_gather() -> &'static str { if ntt_fast() { "k_ntt_p2_gather_f" } else { "k_ntt_p2_gather" } }
fn kn_dit_p1_pad() -> &'static str {
    match (pad_skip(), smem_swz()) {
        (true, true) => "k_dit_p1_pad_sz",
        (true, false) => "k_dit_p1_pad_s",
        (false, _) => "k_dit_p1_pad",
    }
}
fn kn_dif_pb() -> &'static str { if smem_swz_pb() { "k_dif_pb_z" } else { "k_dif_pb" } }

/// [FSP-L9] lever L9, the OTHER half of lane AO's item 1: the expand
/// transform's 537 MB of stores per chunk are read exactly once, by the
/// very next kernel, which in the PRUNED opening reads only the ~250
/// residues `col mod 4096` of the sampled columns. `k_dit_p1_pad_c`
/// stores only those, in the consumer's own order, and
/// `k_ntt_p2_gather_spc` reads that compact block instead of gathering
/// out of the full encoded row. Same stages, same twiddles, same operand
/// pairs, same global loads — the dead 94% of the stores disappear and
/// the consumer's scattered load becomes a contiguous one.
/// `HL_GPU_P1_COMPACT=0` restores the pair lane AO left
/// (`k_dit_p1_pad_s` + `k_ntt_p2_gather_sp`). Used only where the pruned
/// residue list exists, i.e. only on the NON-hiding chunked opening.
fn p1_compact() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_P1_COMPACT").map(|v| v != "0").unwrap_or(true))
}
fn kn_dit_p1_pad_c() -> &'static str { if smem_swz() { "k_dit_p1_pad_cz" } else { "k_dit_p1_pad_c" } }

/// [UPERF3-AO] lever L9 rung 3: the column count of one pruned tile
/// (kernels.cu `P2SP_NC`). The opening's compact residue list is padded to
/// a multiple of this. [ZK60-CL15] `pub` for the same pinning as `NTT_LOG_BLK`.
pub const P2SP_NC: usize = 64;
/// [UPERF3-AO] `HL_GPU_PRUNE_P2=0` restores the DENSE fused last stage
/// group. On the default the opening's last stage group runs only over the
/// distinct residues `col mod 2^NTT_LOG_BLK` of the sampled columns —
/// ~250 of 4,096 — which is the same arithmetic on the same operands with
/// the ~3,850 transforms nobody reads left undone.
fn prune_p2() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    let env = *V.get_or_init(|| std::env::var("HL_GPU_PRUNE_P2").map(|v| v != "0").unwrap_or(true));
    match PRUNE_P2_OVERRIDE.load(Ordering::SeqCst) { 255 => env, x => x != 0 }
}
/// [ZK60-CL7] Runtime override for `prune_p2` (0 = dense fused last stage,
/// 1 = pruned, 255 = follow the environment) so ONE test process can exercise
/// both forms of the fused opening against the CPU. Production reads the
/// environment exactly as before.
static PRUNE_P2_OVERRIDE: AtomicUsize = AtomicUsize::new(255);
pub fn set_prune_p2_for_test(mode: usize) -> usize {
    PRUNE_P2_OVERRIDE.swap(mode, Ordering::SeqCst)
}

/// [ZK60-CL7] `HL_ZK_FUSE_GATHER=0` restores the UNFUSED chunked HIDING
/// opening: the full expand NTT written back to the chunk buffer and then
/// read again by `k_gather_cols_off` (the CL1 form). On the default the
/// hiding opening takes the form the NON-hiding opening has had since
/// [UPERF3-AJ]/[UPERF3-AO]: the expand NTT's last stage group writes only the
/// sampled columns straight into the output, pruned to the ~250 residues
/// `col mod 2^NTT_LOG_BLK` that can produce one. Same operands, same
/// twiddles, same stage order — the opened columns are bit-identical; what
/// changes is that the encoded chunk (rmax x nn) is never stored and never
/// re-read. `fuse_gather()` (HL_GPU_FUSE_GATHER) still gates both openings.
static ZK_FUSE_OVERRIDE: AtomicUsize = AtomicUsize::new(255);
pub fn set_zk_fuse_gather_for_test(mode: usize) -> usize {
    ZK_FUSE_OVERRIDE.swap(mode, Ordering::SeqCst)
}
fn zk_fuse_gather() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    let env = *V.get_or_init(|| std::env::var("HL_ZK_FUSE_GATHER").map(|v| v != "0").unwrap_or(true));
    match ZK_FUSE_OVERRIDE.load(Ordering::SeqCst) { 255 => env, x => x != 0 }
}

/// [ZK60-CL18] `HL_ZK_COMPACT_PAD=1` — DEFAULT OFF — makes the CHUNKED hiding
/// routes (the chunked commit, the reference opening and the fused opening)
/// write the pad/scale output `rmax x (n + q)` instead of `rmax x nn`, and
/// launch the expand NTT's `k_ntt_p1` with `n_src = n + q`. Why it is
/// byte-preserving: `k_zk_pad_scale`'s last argument is only its OUTPUT ROW
/// STRIDE, and `k_ntt_p1`'s `n_src` is both its source row stride and its
/// zero-extension bound (`sh[q] = r < n_src ? s[r] : 0`), so the tail the
/// full form stores as `gl_mul(0, h^i) == 0ULL` is synthesized as the same
/// `0ULL` on the load — identical shared-memory tiles, identical stages,
/// identical leaves and columns (ZK60_CLAUDE_RESIDENCY.md §7). What changes
/// is traffic: the pad/scale write and the `k_ntt_p1` read each shrink from
/// `rmax*nn` to `rmax*(n+q)` per chunk, and the `d_coef2` scratch shrinks
/// the same way. Nothing else moves: the resident path (`HL_ZK_CHUNK=0`, the
/// reference) is untouched, `enc` stays `rmax x nn`, no kernel changed.
/// OFF is the reference form; ON is a diagnostic until measured.
static ZK_COMPACT_PAD_OVERRIDE: AtomicUsize = AtomicUsize::new(255);
/// 0 = full-width reference, 1 = compact, 255 = follow `HL_ZK_COMPACT_PAD`.
/// Returns the previous value so a test can restore it.
pub fn set_zk_compact_pad_for_test(mode: usize) -> usize {
    ZK_COMPACT_PAD_OVERRIDE.swap(mode, Ordering::SeqCst)
}
fn zk_compact_pad() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    let env = *V.get_or_init(|| matches!(std::env::var("HL_ZK_COMPACT_PAD").ok().as_deref(), Some("1") | Some("on")));
    match ZK_COMPACT_PAD_OVERRIDE.load(Ordering::SeqCst) { 255 => env, x => x != 0 }
}

/// [ZK60-CL18] The pad/scale output ROW STRIDE for one hiding encode: `nn`
/// on the reference form, `n + q` on the compact one. This is the single
/// place the compact width is decided, and it REFUSES — with the shape in
/// the message — rather than launching, when `n + q` does not meet
/// `k_ntt_p1`'s requirement (`n_src <= 2^log_nn`, `n_src` an `int`). Both
/// are already excluded upstream (`dev_commit_zk_from` asserts
/// `n + q <= nn`, as does the CPU `encode_row_zk`); re-checking here is what
/// makes "no unsupported `n + q` path is silently used" a property of the
/// route itself. Pure; exported so the test file can pin the boundary.
pub fn zk_pad_width(n: usize, q: usize, nn: usize, compact: bool) -> Result<usize, String> {
    if !compact {
        return Ok(nn);
    }
    let pw = n + q;
    if pw == 0 || pw > nn || pw > i32::MAX as usize {
        return Err(format!(
            "[ZK60-CL18] compact pad/scale refused: n + q = {n} + {q} = {pw} must satisfy 1 <= n + q <= nn = {nn} \
             (k_ntt_p1 zero-extends a source of n_src <= 2^log_nn entries; it cannot shorten a transform). \
             Unset HL_ZK_COMPACT_PAD for the full-width reference form."
        ));
    }
    Ok(pw)
}

pub(super) struct Gpu {
    pub(super) dev: Arc<CudaDevice>,
    pub(super) name: String,
    pub(super) cc: (i32, i32),
    pub(super) sms: i32,
    pub(super) vram_total: usize,
    /// The twiddle tables of the NttTables in use (keyed by max_log): forward, inverse.
    tw: Option<(u32, CudaSlice<u64>, CudaSlice<u64>)>,
    /// [UPERF3-AJ] the pinned double-buffered upload path (created on first use).
    up: Option<Uploader>,
}

// The driver handles are thread-agnostic (the context is bound per thread
// on every entry); the singleton lives behind a Mutex.
unsafe impl Send for Gpu {}

static GPU: OnceLock<Option<Mutex<Gpu>>> = OnceLock::new();
static INIT_ERR: Mutex<Option<String>> = Mutex::new(None);

// [rung 4d] The device buffer pool: a fresh cuMemAlloc'd buffer pays a
// first-touch cost on this box (~12 ms per 68 MB, measured: the second
// encode of the same buffers ran 5x faster), so buffers are reused by
// exact length across commitments and layers. Values are unaffected
// (every element a kernel reads is written first).
static POOL: Mutex<Vec<CudaSlice<u64>>> = Mutex::new(Vec::new());

/// [ZK60-CL2] Deterministic allocation-failure injection, so the exceptional
/// paths the CL1 review found by SOURCE INSPECTION can be exercised for real
/// instead of argued about. A fresh `cuMemAlloc` of more than this many
/// elements fails exactly as an out-of-memory device would; 0 = no cap.
/// Runtime-settable (not a `OnceLock`) so one test process can vary it, and
/// it deliberately does NOT gate pool REUSE — only new device allocations,
/// which is what a full card actually refuses.
static ALLOC_CAP_ELEMS: AtomicUsize = AtomicUsize::new(0);

/// Set the injected allocation cap in ELEMENTS (u64 slots), 0 to disable.
/// Returns the previous value so a test can restore it.
pub fn set_alloc_cap_for_test(elems: usize) -> usize {
    ALLOC_CAP_ELEMS.swap(elems, Ordering::SeqCst)
}

/// [ZK60-CL3] Fail the Nth and every later FRESH allocation (`usize::MAX`
/// disables it, the default).
///
/// A size cap alone cannot isolate a particular allocation SITE: in
/// `dev_commit_zk_from` the `d_coef2` and `d_enc` takes are the same size, so
/// any cap that refuses one refuses the other and the later site is never
/// reached. Counting fresh allocations targets each site exactly, which is
/// what "narrowly scoped deterministic failure injection" has to mean here.
static ALLOC_FAIL_AFTER: AtomicUsize = AtomicUsize::new(usize::MAX);
static ALLOC_FRESH_COUNT: AtomicUsize = AtomicUsize::new(0);

/// Fail EXACTLY the nth fresh allocation (0-based), then disarm.
///
/// [ZK60-CL4 review] This was "fail n and everything after", which made a
/// fallback impossible to test end to end: once armed, the chunked retry could
/// not allocate either. A transient refusal is also the more realistic model of
/// a momentarily full card. One-shot lets the failure land on one site and the
/// recovery path then run for real.
pub fn set_alloc_fail_after_for_test(n: usize) -> usize {
    ALLOC_FRESH_COUNT.store(0, Ordering::SeqCst);
    ALLOC_FAIL_AFTER.swap(n, Ordering::SeqCst)
}

/// [ZK60-CL4 review] Device allocations made OUTSIDE the pool
/// (`htod_sync_copy`, `alloc::<u32>`): pads, coset powers, leaves, gather
/// output. They are real device capacity and were invisible to the counter,
/// so any "made no fresh allocation" claim that ignored them was untestable.
///
/// [ZK60 round-7 review] Counted ONE ALLOCATION PER CALL, on the COMMITMENT
/// and OPENING paths. The first version noted pads+powers as a single event
/// and never noted the leaf buffers, so "2 events / 109,632 B" was neither a
/// count nor a capacity. Now every `note_raw_alloc` is exactly one device
/// allocation of exactly that many bytes: pads, coset powers, each leaf
/// buffer (`alloc::<u32>(nn*8)` in the resident hash, both chunked commits
/// and the pinned-upload commit), index/residue lists and gather output.
/// SCOPE IS STATED, not implied: the sumcheck, fold, helper and zero-check
/// paths keep their own scratch outside this counter (`RAW_ALLOC_SCOPE`).
static RAW_ALLOC_COUNT: AtomicUsize = AtomicUsize::new(0);
static RAW_ALLOC_BYTES: AtomicUsize = AtomicUsize::new(0);
pub const RAW_ALLOC_SCOPE: &str =
    "commitment + opening paths only: pads, coset powers, leaf buffers, index/residue lists, gather output";

/// [ZK60 round-7 review] Pool traffic in BYTES, not just events. "At most 3
/// fresh pooled allocations" bounded nothing: a full fresh scratch pair plus
/// the hash state is 3 allocations. These record the fresh bytes actually
/// allocated through the pool, and for every reuse both the CAPACITY handed
/// out and the length that was asked for — so a test can assert that the
/// chunked retry's scratch came out of the released resident buffers, by
/// size, and that the oversize was reuse rather than new memory.
static FRESH_ALLOC_BYTES: AtomicUsize = AtomicUsize::new(0);
static POOL_REUSE_COUNT: AtomicUsize = AtomicUsize::new(0);
static POOL_REUSE_CAPACITY_BYTES: AtomicUsize = AtomicUsize::new(0);
static POOL_REUSE_REQUESTED_BYTES: AtomicUsize = AtomicUsize::new(0);
/// NEGATIVE CONTROL for the reuse assertions: with reuse disabled every take
/// is a fresh allocation, so a test that claims "reused" can show the claim
/// would have failed had reuse not happened. Test-only; production never
/// touches it.
static POOL_REUSE_ENABLED: AtomicBool = AtomicBool::new(true);

/// Everything the allocation-accounting tests read, in one snapshot.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct PoolStats {
    /// fresh pool allocations ATTEMPTED (the injection counter; a one-shot
    /// failure is an attempt), and the bytes of those that SUCCEEDED
    pub fresh_count: usize,
    pub fresh_bytes: usize,
    /// reuses: events, capacity handed out, length requested
    pub reuse_count: usize,
    pub reuse_capacity_bytes: usize,
    pub reuse_requested_bytes: usize,
    /// raw (non-pool) device allocations on the commitment/opening paths
    pub raw_count: usize,
    pub raw_bytes: usize,
}

impl PoolStats {
    /// [ZK60-CL15] The counters' movement between two snapshots (every field
    /// only grows between resets, so this is exact). Lets a probe report what
    /// ONE step allocated — the opening alone, after its commit — without
    /// resetting the process-global counters under a test that may be
    /// tracking them.
    pub fn delta_since(&self, before: &PoolStats) -> PoolStats {
        PoolStats {
            fresh_count: self.fresh_count.saturating_sub(before.fresh_count),
            fresh_bytes: self.fresh_bytes.saturating_sub(before.fresh_bytes),
            reuse_count: self.reuse_count.saturating_sub(before.reuse_count),
            reuse_capacity_bytes: self.reuse_capacity_bytes.saturating_sub(before.reuse_capacity_bytes),
            reuse_requested_bytes: self.reuse_requested_bytes.saturating_sub(before.reuse_requested_bytes),
            raw_count: self.raw_count.saturating_sub(before.raw_count),
            raw_bytes: self.raw_bytes.saturating_sub(before.raw_bytes),
        }
    }
}

pub fn pool_stats_for_test() -> PoolStats {
    PoolStats {
        fresh_count: ALLOC_FRESH_COUNT.load(Ordering::SeqCst),
        fresh_bytes: FRESH_ALLOC_BYTES.load(Ordering::SeqCst),
        reuse_count: POOL_REUSE_COUNT.load(Ordering::SeqCst),
        reuse_capacity_bytes: POOL_REUSE_CAPACITY_BYTES.load(Ordering::SeqCst),
        reuse_requested_bytes: POOL_REUSE_REQUESTED_BYTES.load(Ordering::SeqCst),
        raw_count: RAW_ALLOC_COUNT.load(Ordering::SeqCst),
        raw_bytes: RAW_ALLOC_BYTES.load(Ordering::SeqCst),
    }
}
/// Returns the previous setting so a test can restore it.
pub fn set_pool_reuse_for_test(enabled: bool) -> bool {
    POOL_REUSE_ENABLED.swap(enabled, Ordering::SeqCst)
}
pub fn raw_alloc_stats_for_test() -> (usize, usize) {
    (RAW_ALLOC_COUNT.load(Ordering::SeqCst), RAW_ALLOC_BYTES.load(Ordering::SeqCst))
}
pub fn reset_alloc_counters_for_test() {
    ALLOC_FRESH_COUNT.store(0, Ordering::SeqCst);
    FRESH_ALLOC_BYTES.store(0, Ordering::SeqCst);
    POOL_REUSE_COUNT.store(0, Ordering::SeqCst);
    POOL_REUSE_CAPACITY_BYTES.store(0, Ordering::SeqCst);
    POOL_REUSE_REQUESTED_BYTES.store(0, Ordering::SeqCst);
    RAW_ALLOC_COUNT.store(0, Ordering::SeqCst);
    RAW_ALLOC_BYTES.store(0, Ordering::SeqCst);
}
/// ONE raw device allocation of `bytes`. Call once per allocation.
fn note_raw_alloc(bytes: usize) {
    RAW_ALLOC_COUNT.fetch_add(1, Ordering::SeqCst);
    RAW_ALLOC_BYTES.fetch_add(bytes, Ordering::SeqCst);
}
fn note_reuse(capacity_elems: usize, requested_elems: usize) {
    POOL_REUSE_COUNT.fetch_add(1, Ordering::SeqCst);
    POOL_REUSE_CAPACITY_BYTES.fetch_add(capacity_elems * 8, Ordering::SeqCst);
    POOL_REUSE_REQUESTED_BYTES.fetch_add(requested_elems * 8, Ordering::SeqCst);
}

/// The shared gate for a FRESH pool allocation: cap, one-shot injection and
/// the counter. `pool_take_min` used to allocate straight from the device,
/// outside all three — so the chunked path, which uses take_min exclusively,
/// was invisible to every assertion built on this counter.
fn fresh_alloc_gate(len: usize) -> Result<(), String> {
    let cap = ALLOC_CAP_ELEMS.load(Ordering::SeqCst);
    if cap != 0 && len > cap {
        return Err(format!(
            "cuMemAlloc({} B): injected allocation cap ({} B / {} elements)",
            len * 8, cap * 8, cap
        ));
    }
    let seen = ALLOC_FRESH_COUNT.fetch_add(1, Ordering::SeqCst);
    if seen == ALLOC_FAIL_AFTER.load(Ordering::SeqCst) {
        ALLOC_FAIL_AFTER.store(usize::MAX, Ordering::SeqCst); // one-shot
        return Err(format!(
            "cuMemAlloc({} B): injected one-shot failure at fresh allocation #{}",
            len * 8, seen
        ));
    }
    Ok(())
}

/// Fresh device allocations since the last arming. Lets a test assert that a
/// fallback REUSED pooled capacity instead of allocating more.
pub fn fresh_alloc_count_for_test() -> usize {
    ALLOC_FRESH_COUNT.load(Ordering::SeqCst)
}

fn pool_take(dev: &Arc<CudaDevice>, len: usize) -> Result<CudaSlice<u64>, String> {
    if POOL_REUSE_ENABLED.load(Ordering::SeqCst) {
        let mut pool = POOL.lock().unwrap();
        if let Some(i) = pool.iter().position(|b| b.len() == len) {
            note_reuse(len, len);
            return Ok(pool.swap_remove(i));
        }
    }
    fresh_alloc_gate(len)?;
    let b = unsafe { dev.alloc::<u64>(len) }.map_err(|e| format!("cuMemAlloc({} MB): {e}", len * 8 >> 20))?;
    FRESH_ALLOC_BYTES.fetch_add(len * 8, Ordering::SeqCst);
    Ok(b)
}

fn pool_put(buf: CudaSlice<u64>) {
    let mut pool = POOL.lock().unwrap();
    if pool.len() < 64 {
        pool.push(buf);
    }
}

/// [UPERF3-AC] A buffer of AT LEAST `len` (the smallest pooled one that
/// fits, else a fresh allocation of exactly `len`) — for chunk scratch
/// whose kernels take explicit row counts, so the extra tail is inert.
fn pool_take_min(dev: &Arc<CudaDevice>, len: usize) -> Result<CudaSlice<u64>, String> {
    if POOL_REUSE_ENABLED.load(Ordering::SeqCst) {
        let mut pool = POOL.lock().unwrap();
        let mut best: Option<usize> = None;
        for (i, b) in pool.iter().enumerate() {
            if b.len() >= len && best.map(|j| b.len() < pool[j].len()).unwrap_or(true) {
                best = Some(i);
            }
        }
        if let Some(i) = best {
            note_reuse(pool[i].len(), len);
            return Ok(pool.swap_remove(i));
        }
    }
    // [ZK60-CL4 review] this allocated straight from the device, outside the
    // cap, the injection and the counter. The chunked path uses take_min for
    // ALL its scratch, so it was invisible to every assertion built on them.
    fresh_alloc_gate(len)?;
    let b = unsafe { dev.alloc::<u64>(len) }.map_err(|e| format!("cuMemAlloc({} MB): {e}", len * 8 >> 20))?;
    FRESH_ALLOC_BYTES.fetch_add(len * 8, Ordering::SeqCst);
    Ok(b)
}

/// A pooled buffer: returned to the pool on drop.
pub struct Pooled(Option<CudaSlice<u64>>);
impl Pooled {
    fn take(dev: &Arc<CudaDevice>, len: usize) -> Result<Pooled, String> {
        Ok(Pooled(Some(pool_take(dev, len)?)))
    }
    /// [UPERF3-AC] at least `len` (see `pool_take_min`).
    fn take_min(dev: &Arc<CudaDevice>, len: usize) -> Result<Pooled, String> {
        Ok(Pooled(Some(pool_take_min(dev, len)?)))
    }
    #[inline]
    fn get(&self) -> &CudaSlice<u64> {
        self.0.as_ref().unwrap()
    }
    #[inline]
    fn get_mut(&mut self) -> &mut CudaSlice<u64> {
        self.0.as_mut().unwrap()
    }
}
impl Drop for Pooled {
    fn drop(&mut self) {
        if let Some(b) = self.0.take() {
            pool_put(b);
        }
    }
}

/// Per-process device-side accounting (seconds per phase, bytes moved).
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
    /// [UPERF3-AC] the opening's chunked re-encode (NTT time, counted apart from `secs_ntt`) and the chunked commit count
    pub secs_reenc: f64,
    pub n_chunked: u64,
}
static STATS: Mutex<GpuStats> = Mutex::new(GpuStats {
    secs_h2d: 0.0, secs_ntt: 0.0, secs_hash: 0.0, secs_d2h: 0.0, secs_sumcheck: 0.0, secs_fold: 0.0, secs_helpers: 0.0,
    bytes_h2d: 0, bytes_d2h: 0, vram_peak: 0, secs_reenc: 0.0, n_chunked: 0,
});
pub fn dev_stats() -> GpuStats {
    STATS.lock().unwrap().clone()
}
pub fn dev_stats_reset() {
    *STATS.lock().unwrap() = GpuStats::default();
}
pub(super) fn stats_with<F: FnOnce(&mut GpuStats)>(f: F) {
    f(&mut STATS.lock().unwrap());
}

pub(super) fn env_flag(name: &str) -> bool {
    std::env::var(name).map(|v| v == "1").unwrap_or(false)
}

/// `HL_GPU=1` requested (read once).
fn requested() -> bool {
    static ON: OnceLock<bool> = OnceLock::new();
    *ON.get_or_init(|| env_flag("HL_GPU"))
}

pub(super) fn verbose() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| env_flag("HL_GPU_VERBOSE"))
}

fn arch_str(cc: (i32, i32)) -> Option<&'static str> {
    Some(match cc {
        (7, 0) => "compute_70",
        (7, 5) => "compute_75",
        (8, 0) => "compute_80",
        (8, 6) => "compute_86",
        (8, 9) => "compute_89",
        (9, 0) => "compute_90",
        // [UPERF3-AJ] Blackwell. Untestable on this box (RTX 4070 Laptop is
        // sm_89, so these arms are never taken here); without them the NVRTC
        // compile falls through to the generic-PTX path, which JITs and runs
        // but gets no Blackwell codegen — a silent slowdown that would poison
        // a headline measurement on the 5090.
        (10, 0) => "compute_100", // datacenter Blackwell (B100/B200)
        (12, 0) => "compute_120", // consumer Blackwell (RTX 50-series)
        _ => return None,
    })
}

fn init_gpu() -> Result<Gpu, String> {
    let dev = CudaDevice::new(0).map_err(|e| format!("CudaDevice::new(0): {e}"))?;
    let name = dev.name().map_err(|e| format!("device name: {e}"))?;
    let major = dev
        .attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR)
        .map_err(|e| format!("cc major: {e}"))?;
    let minor = dev
        .attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR)
        .map_err(|e| format!("cc minor: {e}"))?;
    let sms = dev
        .attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT)
        .map_err(|e| format!("sm count: {e}"))?;
    let (_free, total) = cu::mem_get_info().map_err(|e| format!("cuMemGetInfo: {e}"))?;
    let t0 = Instant::now();
    let compile = |arch: Option<&'static str>| {
        let opts = CompileOptions { arch, ..Default::default() };
        compile_ptx_with_opts(KSRC, opts)
    };
    // [UPERF3-AJ] a generic-PTX fallback is a QUIET slowdown, so it is announced
    // on stderr whether or not HL_GPU_VERBOSE is set: either the compute
    // capability has no arm in `arch_str` (new hardware — add one) or the
    // toolkit's NVRTC is too old for that arch (bump the toolkit).
    let arch = arch_str((major, minor));
    if arch.is_none() {
        eprintln!("[UPERF3-AJ] WARNING: compute capability {major}.{minor} has no arch arm in arch_str; compiling GENERIC PTX (JIT, no {major}.{minor} codegen — timings taken here are NOT this card's)");
    }
    let ptx = match compile(arch) {
        Ok(p) => p,
        Err(e1) => {
            if arch.is_some() {
                eprintln!("[UPERF3-AJ] WARNING: NVRTC rejected arch compute_{major}{minor} ({e1}); compiling GENERIC PTX (JIT, no {major}.{minor} codegen — the toolkit at CUDA_ROOT is older than this card)");
            }
            match compile(None) {
                Ok(p) => p,
                Err(e2) => return Err(format!("NVRTC compile failed: {e1}; generic retry: {e2}")),
            }
        }
    };
    dev.load_ptx(ptx, MODULE, FUNCS).map_err(|e| format!("cuModuleLoadData: {e}"))?;
    let secs_compile = t0.elapsed().as_secs_f64();
    if verbose() {
        eprintln!(
            "[UPERF3-XX] gpu init: {name} (sm_{major}{minor}, {sms} SMs, {:.1} GB), NVRTC compile {secs_compile:.2}s",
            total as f64 / 1e9
        );
    }
    Ok(Gpu { dev, name, cc: (major, minor), sms, vram_total: total, tw: None, up: None })
}

fn note_vram(g: &Gpu) {
    if let Ok((free, total)) = cu::mem_get_info() {
        let _ = g;
        let held = (total - free) as u64;
        stats_with(|s| if held > s.vram_peak { s.vram_peak = held });
    }
}

#[inline]
fn as_u64s(v: &[Fp]) -> &[u64] {
    // SAFETY: Fp is #[repr(transparent)] over u64.
    unsafe { std::slice::from_raw_parts(v.as_ptr() as *const u64, v.len()) }
}
#[inline]
fn as_fps(v: Vec<u64>) -> Vec<Fp> {
    // Canonical values (< p) come back from the device; Fp(u64) is the same representation.
    v.into_iter().map(Fp).collect()
}

/// The device singleton (initialized on first use; None when it failed —
/// the reason is kept for `label()`).
pub(super) fn gpu() -> Option<&'static Mutex<Gpu>> {
    GPU.get_or_init(|| match init_gpu() {
        Ok(g) => Some(Mutex::new(g)),
        Err(e) => {
            *INIT_ERR.lock().unwrap() = Some(e);
            None
        }
    })
    .as_ref()
}

pub(super) fn init_err() -> String {
    INIT_ERR.lock().unwrap().clone().unwrap_or_else(|| "no device".to_string())
}

/// True when the GPU path is live: feature on (this file), `HL_GPU=1`,
/// and a device initialized.
#[inline]
pub fn enabled() -> bool {
    if !requested() {
        return false;
    }
    gpu().is_some()
}

/// Human-readable state (device / reason it is off).
pub fn label() -> String {
    if !requested() {
        return "gpu: off (HL_GPU unset; built with gpu-cuda)".to_string();
    }
    match gpu() {
        Some(g) => {
            let g = g.lock().unwrap();
            format!("gpu: ON — {} (sm_{}{}, {} SMs, {:.1} GB)", g.name, g.cc.0, g.cc.1, g.sms, g.vram_total as f64 / 1e9)
        }
        None => format!("gpu: off (HL_GPU=1 but init failed: {})", init_err()),
    }
}

#[derive(Clone, Debug, Default)]
pub struct ProbeReport {
    pub device: String,
    pub n: usize,
    pub mismatches: usize,
    pub gmul_per_s: f64,
}

/// Rung 0's probe: 2^20 random canonical pairs (plus the edge values) —
/// mul / add / sub on the device compared against field.rs.
pub fn probe() -> Result<ProbeReport, String> {
    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    let dev = &g.dev;
    let f = dev.get_func(MODULE, "k_probe").ok_or("k_probe missing")?;
    let n = 1usize << 20;
    let mut s = 0x9E37_79B9_7F4A_7C15u64;
    let mut rng = move || {
        s ^= s >> 12;
        s ^= s << 25;
        s ^= s >> 27;
        s.wrapping_mul(0x2545_F491_4F6C_DD1D)
    };
    let edges = [0u64, 1, P - 1, P - 2, 0xFFFF_FFFF, 0x1_0000_0000, 1u64 << 63, P - 0xFFFF_FFFF, 0xFFFF_FFFF_0000_0000];
    let mut a: Vec<u64> = Vec::with_capacity(n);
    let mut b: Vec<u64> = Vec::with_capacity(n);
    for &x in &edges {
        for &y in &edges {
            a.push(x);
            b.push(y);
        }
    }
    while a.len() < n {
        a.push(rng() % P);
        b.push(rng() % P);
    }
    let da = dev.htod_sync_copy(&a).map_err(|e| e.to_string())?;
    let db = dev.htod_sync_copy(&b).map_err(|e| e.to_string())?;
    let mut om = dev.alloc_zeros::<u64>(n).map_err(|e| e.to_string())?;
    let mut oa = dev.alloc_zeros::<u64>(n).map_err(|e| e.to_string())?;
    let mut os = dev.alloc_zeros::<u64>(n).map_err(|e| e.to_string())?;
    let cfg = LaunchConfig::for_num_elems(n as u32);
    dev.synchronize().map_err(|e| e.to_string())?;
    let t0 = Instant::now();
    let reps = 50;
    for _ in 0..reps {
        unsafe { f.clone().launch(cfg, (&da, &db, &mut om, &mut oa, &mut os, n as i32)) }.map_err(|e| e.to_string())?;
    }
    dev.synchronize().map_err(|e| e.to_string())?;
    let dt = t0.elapsed().as_secs_f64();
    let hm = dev.dtoh_sync_copy(&om).map_err(|e| e.to_string())?;
    let ha = dev.dtoh_sync_copy(&oa).map_err(|e| e.to_string())?;
    let hs = dev.dtoh_sync_copy(&os).map_err(|e| e.to_string())?;
    let mut bad = 0usize;
    for i in 0..n {
        let (x, y) = (Fp(a[i]), Fp(b[i]));
        if x.mul(y).0 != hm[i] || x.add(y).0 != ha[i] || x.sub(y).0 != hs[i] {
            bad += 1;
        }
    }
    if env_flag("HL_GPU_BENCH_H2D") {
        h2d_bench(&g);
    }
    // [UPERF3-AO] lever L9's attribution harness
    if env_flag("HL_GPU_BENCH_REENC") {
        reenc_bench(&mut g);
    }
    Ok(ProbeReport { device: g.name.clone(), n, mismatches: bad, gmul_per_s: reps as f64 * n as f64 / dt / 1e9 })
}

/// [UPERF3-AJ] A page-locked host staging buffer (`cuMemHostAlloc`), the
/// source a real DMA needs: a pageable `cuMemcpyHtoD` is staged by the
/// driver through its own small pinned buffer and blocks the host for the
/// whole transfer. Nothing about the BYTES changes — this is the same
/// little-endian u64 image reaching the same device addresses.
pub(super) struct PinBuf {
    ptr: *mut u64,
    len: usize,
}
unsafe impl Send for PinBuf {}
impl PinBuf {
    fn new(dev: &Arc<CudaDevice>, len: usize) -> Result<PinBuf, String> {
        dev.bind_to_thread().map_err(|e| e.to_string())?;
        // WRITECOMBINED: the host only ever WRITES this buffer and the DMA engine reads it.
        let flags = if env_flag("HL_GPU_PIN_NOWC") { 0 } else { sys::CU_MEMHOSTALLOC_WRITECOMBINED };
        let p = unsafe { cu::malloc_host(len * 8, flags) }.map_err(|e| format!("cuMemHostAlloc({} MB): {e}", len * 8 >> 20))?;
        Ok(PinBuf { ptr: p as *mut u64, len })
    }
    #[inline]
    fn as_mut_slice(&mut self) -> &mut [u64] {
        unsafe { std::slice::from_raw_parts_mut(self.ptr, self.len) }
    }
    #[inline]
    fn as_slice(&self) -> &[u64] {
        unsafe { std::slice::from_raw_parts(self.ptr, self.len) }
    }
}
impl Drop for PinBuf {
    fn drop(&mut self) {
        unsafe { let _ = cu::free_host(self.ptr as *mut std::ffi::c_void); }
    }
}

/// Fill a staging buffer from a host slice (8 threads; the copy is the
/// only host work the pinned path adds).
fn pin_fill(dst: &mut [u64], src: &[u64]) {
    dst.par_chunks_mut(1 << 18).zip(src.par_chunks(1 << 18)).for_each(|(a, b)| a.copy_from_slice(b));
}

/// [UPERF3-AJ] `HL_GPU_PIN_MB` — the size of ONE staging buffer (two are
/// held); 0 turns the pinned path off entirely and every upload falls back
/// to the built pageable `htod_sync_copy_into`.
fn pin_mb() -> usize {
    static V: OnceLock<usize> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_PIN_MB").ok().and_then(|v| v.parse().ok()).unwrap_or(64usize))
}
/// `HL_GPU_STREAM_COMMIT=0` keeps the chunked commit's upload in one block
/// before the encode (the pre-rung-1 shape, for the A/B).
fn stream_commit() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_STREAM_COMMIT").map(|v| v != "0").unwrap_or(true))
}

/// [UPERF3-AJ] The pinned, double-buffered upload engine: two page-locked
/// staging buffers, one copy stream, one event per buffer. `send` fills a
/// staging buffer and hands it to the DMA engine WITHOUT waiting, so the
/// caller's kernels (queued on the default stream) run while the bytes
/// move. `wait` is the only synchronization point.
struct Uploader {
    stream: sys::CUstream,
    pin: [PinBuf; 2],
    ev: [sys::CUevent; 2],
    armed: [bool; 2],
    cur: usize,
    /// host seconds actually spent blocked in this engine (the honest h2d cost)
    secs: f64,
    /// [FSP-HOST] of those seconds, the ones spent in `pack_narrow` — HOST
    /// arithmetic over the 64-bit staging vector, not bus time. Timing only:
    /// two `Instant`s per 64 MB staging piece, no value the transcript or the
    /// proof depends on is read or written here.
    pack_secs: f64,
    /// [FSP-HOST] elements packed, for the rate.
    pack_elems: u64,
}

impl Uploader {
    fn new(dev: &Arc<CudaDevice>, cap: usize) -> Result<Uploader, String> {
        dev.bind_to_thread().map_err(|e| e.to_string())?;
        let stream = dev.fork_default_stream().map_err(|e| format!("copy stream: {e}"))?;
        // the CudaStream wrapper would re-synchronize the default stream on drop; keep the raw handle
        let raw = stream.stream;
        std::mem::forget(stream);
        let pin = [PinBuf::new(dev, cap)?, PinBuf::new(dev, cap)?];
        let mk = || cu::event::create(sys::CUevent_flags::CU_EVENT_DISABLE_TIMING).map_err(|e| format!("cuEventCreate: {e}"));
        Ok(Uploader { stream: raw, pin, ev: [mk()?, mk()?], armed: [false, false], cur: 0, secs: 0.0, pack_secs: 0.0, pack_elems: 0 })
    }

    /// Stage and issue `src` into `dst[off..]`, asynchronously. The bytes
    /// are the caller's bytes: a host copy into page-locked memory and a
    /// DMA of the same little-endian u64 image.
    fn send(&mut self, dst: &mut CudaSlice<u64>, off: usize, src: &[u64]) -> Result<(), String> {
        let cap = self.pin[0].len;
        let t0 = Instant::now();
        let mut done = 0usize;
        while done < src.len() {
            let w = cap.min(src.len() - done);
            let b = self.cur;
            if self.armed[b] {
                unsafe { cu::event::synchronize(self.ev[b]) }.map_err(|e| format!("cuEventSynchronize: {e}"))?;
                self.armed[b] = false;
            }
            pin_fill(&mut self.pin[b].as_mut_slice()[..w], &src[done..done + w]);
            let mut view = dst.slice_mut(off + done..off + done + w);
            unsafe { cu::memcpy_htod_async(*view.device_ptr_mut(), &self.pin[b].as_slice()[..w], self.stream) }
                .map_err(|e| format!("cuMemcpyHtoDAsync: {e}"))?;
            unsafe { cu::event::record(self.ev[b], self.stream) }.map_err(|e| format!("cuEventRecord: {e}"))?;
            self.armed[b] = true;
            self.cur ^= 1;
            done += w;
        }
        self.secs += t0.elapsed().as_secs_f64();
        Ok(())
    }

    /// Block until every issued copy has landed.
    fn wait(&mut self) -> Result<(), String> {
        let t0 = Instant::now();
        unsafe { cu::stream::synchronize(self.stream) }.map_err(|e| format!("cuStreamSynchronize: {e}"))?;
        self.armed = [false, false];
        self.secs += t0.elapsed().as_secs_f64();
        Ok(())
    }
}

/// [FSP-HOST] `HL_FSP4_TIMING=1` prints the upload's host/bus split (what
/// the `secs_h2d` counter is made of). Default off; prints only, changes
/// no proof byte.
fn fsp4_timing() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| env_flag("HL_FSP4_TIMING"))
}

/// [UPERF3-AJ] `HL_GPU_NARROW=0` sends the 64-bit field image (the
/// pre-rung-3 shape, for the A/B).
fn narrow_on() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_NARROW").map(|v| v != "0").unwrap_or(true))
}

/// The signed byte width that represents a canonical Goldilocks value
/// exactly: 1, 2 or 4 for the int8 / int16 / int32 witness planes, 8 for
/// anything wider (`Fp::from_i64` maps x >= 0 to x and x < 0 to P + x, so
/// a plane's values are exactly the two ends of the field).
#[inline]
fn narrow_class(v: u64) -> usize {
    if v <= 0x7F || v >= P - 0x80 { 1 }
    else if v <= 0x7FFF || v >= P - 0x8000 { 2 }
    else if v <= 0x7FFF_FFFF || v >= P - 0x8000_0000 { 4 }
    else { 8 }
}

/// A strided sample: which width to TRY. `pack_narrow` verifies every
/// element, so a wrong guess costs a fallback, never a wrong byte.
fn narrow_probe(src: &[u64]) -> usize {
    let step = (src.len() / 4096).max(1);
    let mut w = 1usize;
    let mut i = 0;
    while i < src.len() {
        w = w.max(narrow_class(src[i]));
        if w == 8 { return 8; }
        i += step;
    }
    w.max(narrow_class(src[src.len() - 1]))
}

/// Pack `src` as w-byte two's-complement signed integers; false if any
/// value does not fit (the caller then falls back to the 64-bit upload).
fn pack_narrow(dst: &mut [u8], src: &[u64], w: usize) -> bool {
    use std::sync::atomic::{AtomicBool, Ordering};
    debug_assert_eq!(dst.len(), src.len() * w);
    let hi = 1u64 << (8 * w - 1);
    let ok = AtomicBool::new(true);
    // the width is fixed per call, so the inner loop is a straight store, not
    // a slice copy — this runs over ~176M elements per Mistral weight tensor
    dst.par_chunks_mut(w * 8192).zip(src.par_chunks(8192)).for_each(|(d, s)| {
        let mut good = true;
        match w {
            1 => {
                for (o, &v) in d.iter_mut().zip(s.iter()) {
                    *o = if v < hi { v as u8 } else if v >= P - hi { v.wrapping_sub(P) as u8 } else { good = false; 0 };
                }
            }
            2 => {
                for (o, &v) in d.chunks_exact_mut(2).zip(s.iter()) {
                    let x = if v < hi { v as u16 } else if v >= P - hi { v.wrapping_sub(P) as u16 } else { good = false; 0 };
                    o.copy_from_slice(&x.to_le_bytes());
                }
            }
            _ => {
                for (o, &v) in d.chunks_exact_mut(4).zip(s.iter()) {
                    let x = if v < hi { v as u32 } else if v >= P - hi { v.wrapping_sub(P) as u32 } else { good = false; 0 };
                    o.copy_from_slice(&x.to_le_bytes());
                }
            }
        }
        if !good {
            ok.store(false, Ordering::Relaxed);
        }
    });
    ok.load(Ordering::Relaxed)
}

/// [FSP-HOST] ITEM (a): WHERE a commitment's staged bytes come from.
///
/// `Words` is the inherited source — the converted 64-bit buffer, read in
/// full by `pack_narrow` to emit `w` bytes per element. `Planes` is the
/// three int8 weight planes plus the block map (`gpu/mod.rs`'s `planes`),
/// which produce the SAME bytes at `w = 1` by copying them: `pack_narrow`
/// at `w = 1` emits the two's-complement byte of an int8-valued field
/// element, which is the plane's own byte. Everything downstream —
/// `k_widen`, the encode, the hash, the leaves — sees identical bytes at
/// identical addresses, so no proof byte can move.
#[derive(Clone, Copy)]
enum UpSrc<'a> {
    Words(&'a [u64]),
    Planes(&'a PlaneTiling<'a>),
}

impl UpSrc<'_> {
    fn len(&self) -> usize {
        match self {
            UpSrc::Words(v) => v.len(),
            UpSrc::Planes(p) => p.len(),
        }
    }
    /// The byte width on the wire: the strided probe for a word source,
    /// always 1 for a plane source (an int8 plane IS one byte per element).
    fn width(&self) -> usize {
        match self {
            UpSrc::Words(v) => {
                if narrow_on() {
                    narrow_probe(v)
                } else {
                    8
                }
            }
            UpSrc::Planes(_) => 1,
        }
    }
    fn is_planes(&self) -> bool {
        matches!(self, UpSrc::Planes(_))
    }
}

impl Uploader {
    /// Stage elements `[start, start + cnt)` of `src` as `w` bytes each
    /// straight into the pinned buffer and hand them to the DMA — the
    /// witness planes cross the bus as bytes and the device widens them
    /// back to the identical 64-bit image (`k_widen`). `elem_off` is the
    /// destination's element offset.
    ///
    /// [FSP-HOST] this is the old `send_packed` with the source behind
    /// `UpSrc`: the `Words` arm is the inherited code, unchanged.
    fn send_src(&mut self, dst_base: sys::CUdeviceptr, elem_off: usize, src: &UpSrc, start: usize, cnt: usize, w: usize) -> Result<(), String> {
        if src.is_planes() && w != 1 {
            return Err(format!("plane source staged at {w} bytes per element"));
        }
        let per = (self.pin[0].len * 8) / w; // elements per staging piece
        let t0 = Instant::now();
        let mut done = 0usize;
        while done < cnt {
            let m = per.min(cnt - done);
            let b = self.cur;
            if self.armed[b] {
                unsafe { cu::event::synchronize(self.ev[b]) }.map_err(|e| format!("cuEventSynchronize: {e}"))?;
                self.armed[b] = false;
            }
            let bytes: &mut [u8] = unsafe { std::slice::from_raw_parts_mut(self.pin[b].ptr as *mut u8, m * w) };
            let tp = Instant::now(); // [FSP-HOST] timing only
            match src {
                UpSrc::Words(v) => {
                    if !pack_narrow(bytes, &v[start + done..start + done + m], w) {
                        return Err("narrow pack: value out of range".into());
                    }
                }
                UpSrc::Planes(p) => p.fill_bytes(start + done, bytes),
            }
            self.pack_secs += tp.elapsed().as_secs_f64();
            self.pack_elems += m as u64;
            let dp = dst_base + ((elem_off + done) * w) as sys::CUdeviceptr;
            unsafe { cu::memcpy_htod_async(dp, &bytes[..m * w], self.stream) }.map_err(|e| format!("cuMemcpyHtoDAsync: {e}"))?;
            unsafe { cu::event::record(self.ev[b], self.stream) }.map_err(|e| format!("cuEventRecord: {e}"))?;
            self.armed[b] = true;
            self.cur ^= 1;
            done += m;
        }
        self.secs += t0.elapsed().as_secs_f64();
        Ok(())
    }
}

impl Gpu {
    /// The upload engine, created on first use; `None` when pinned staging
    /// is off or unavailable (the caller then uses the pageable path).
    fn up(&mut self) -> Option<&mut Uploader> {
        if pin_mb() == 0 {
            return None;
        }
        if self.up.is_none() {
            let cap = (pin_mb() << 20) / 8;
            match Uploader::new(&self.dev.clone(), cap) {
                Ok(u) => self.up = Some(u),
                Err(e) => {
                    eprintln!("[UPERF3-AJ] pinned staging unavailable ({e}); pageable uploads");
                    return None;
                }
            }
        }
        self.up.as_mut()
    }

    /// [UPERF3-AJ] One whole upload in the NARROW form: pack w bytes per
    /// element, DMA the bytes, widen on the device. `dst` is untouched
    /// unless the whole thing succeeds, so a failure falls back cleanly.
    fn upload_narrow(&mut self, dst: &mut CudaSlice<u64>, src: UpSrc, w: usize) -> Result<(), String> {
        let dev = self.dev.clone();
        let f = dev.get_func(MODULE, "k_widen").ok_or("k_widen missing")?;
        let len = src.len();
        let mut d_pack = Pooled::take_min(&dev, (len * w + 7) / 8)?;
        let pack_base: sys::CUdeviceptr = *d_pack.get().device_ptr();
        let data_base: sys::CUdeviceptr = *dst.device_ptr();
        if self.up().is_none() {
            return Err("pinned staging unavailable".into());
        }
        let mut up = self.up.take().unwrap();
        let (secs0, pack0) = (up.secs, up.pack_secs); // [FSP-HOST] timing only
        let mut r = up.send_src(pack_base, 0, &src, 0, len, w).and_then(|_| up.wait());
        if r.is_err() {
            // a half-issued transfer must land before the scratch goes back to the pool
            let _ = up.wait();
            r = r.and(Err("narrow upload abandoned".to_string()));
        }
        let (secs_up, pack_up) = (up.secs - secs0, up.pack_secs - pack0);
        self.up = Some(up);
        r?;
        if fsp4_timing() {
            eprintln!("[FSP4] whole-buffer narrow upload {len} elem w {w} ({}): h2d counter {secs_up:.4} = host pack {pack_up:.4} + {:.4} rest",
                if src.is_planes() { "int8 planes" } else { "64-bit words" }, secs_up - pack_up);
        }
        let cfg = LaunchConfig::for_num_elems(len as u32);
        unsafe { f.launch(cfg, (pack_base, data_base, len as i64, w as i32)) }.map_err(|e| format!("k_widen: {e}"))?;
        dev.synchronize().map_err(|e| e.to_string())?;
        drop(d_pack.0.take().map(pool_put));
        Ok(())
    }

    /// [FSP-HOST] ITEM (a): the whole-buffer upload with the int8 planes as
    /// the source. There is no 64-bit image to fall back to inside this
    /// function, so an `Err` is a DECLINE: the caller builds the `Vec<Fp>`
    /// and takes the inherited path, which is why every arm below stays in
    /// the binary. The stats are charged exactly as `upload_sync` charges
    /// them for the narrow word path.
    fn upload_planes(&mut self, dst: &mut CudaSlice<u64>, pt: &PlaneTiling) -> Result<(), String> {
        if !narrow_on() {
            return Err("HL_GPU_NARROW=0: the plane source has no 64-bit form".into());
        }
        let t0 = Instant::now();
        self.upload_narrow(dst, UpSrc::Planes(pt), 1)?;
        stats_with(|s| {
            s.secs_h2d += t0.elapsed().as_secs_f64();
            s.bytes_h2d += pt.len() as u64;
        });
        Ok(())
    }

    /// One whole upload, host-synchronous — the drop-in for
    /// `htod_sync_copy_into` (identical bytes, identical destination).
    fn upload_sync(&mut self, dst: &mut CudaSlice<u64>, src: &[u64]) -> Result<(), String> {
        let dev = self.dev.clone();
        let t0 = Instant::now();
        if narrow_on() && src.len() >= (1 << 20) {
            let w = narrow_probe(src);
            if w < 8 {
                match self.upload_narrow(dst, UpSrc::Words(src), w) {
                    Ok(()) => {
                        stats_with(|s| { s.secs_h2d += t0.elapsed().as_secs_f64(); s.bytes_h2d += (src.len() * w) as u64; });
                        return Ok(());
                    }
                    Err(e) => eprintln!("[UPERF3-AJ] narrow upload declined ({e}); 64-bit upload"),
                }
            }
        }
        let ok = match self.up() {
            Some(u) => match u.send(dst, 0, src).and_then(|_| u.wait()) {
                Ok(()) => true,
                Err(e) => {
                    eprintln!("[UPERF3-AJ] pinned upload declined ({e}); pageable");
                    false
                }
            },
            None => false,
        };
        if !ok {
            dev.htod_sync_copy_into(src, dst).map_err(|e| format!("data upload: {e}"))?;
            dev.synchronize().map_err(|e| e.to_string())?;
        }
        stats_with(|s| { s.secs_h2d += t0.elapsed().as_secs_f64(); s.bytes_h2d += (src.len() * 8) as u64; });
        Ok(())
    }
}

/// [UPERF3-AJ] `HL_GPU_BENCH_H2D=1` on `gpu-probe`: the host-to-device
/// upload rate of the forms the commit path can use — the built pageable
/// `htod_sync_copy_into`, a pinned staging buffer filled then DMA'd, and
/// the same double-buffered on a copy stream (the form rung 1 puts under
/// the chunked commit). Diagnostic only; nothing here is on a proof path.
fn h2d_bench(g: &Gpu) {
    let dev = g.dev.clone();
    let n = 128usize << 20; // 1 GiB of u64
    let src: Vec<u64> = vec![0x0123_4567_89AB_CDEFu64; n];
    let mut d = match unsafe { dev.alloc::<u64>(n) } {
        Ok(b) => b,
        Err(e) => { eprintln!("[UPERF3-AJ] h2d bench: alloc failed ({e})"); return; }
    };
    let gb = (n * 8) as f64 / 1e9;
    let reps = 3;
    let t = Instant::now();
    for _ in 0..reps {
        dev.htod_sync_copy_into(&src, &mut d).unwrap();
    }
    let pageable = t.elapsed().as_secs_f64() / reps as f64;
    let chunk = 32usize << 20; // 256 MB staging buffers
    let (mut p0, mut p1) = match (PinBuf::new(&dev, chunk), PinBuf::new(&dev, chunk)) {
        (Ok(a), Ok(b)) => (a, b),
        _ => { eprintln!("[UPERF3-AJ] h2d bench: cuMemHostAlloc failed — pinned staging is not available on this box"); return; }
    };
    let t = Instant::now();
    for _ in 0..reps {
        for (k, off) in (0..n).step_by(chunk).enumerate() {
            let w = chunk.min(n - off);
            let b = if k & 1 == 0 { &mut p0 } else { &mut p1 };
            pin_fill(&mut b.as_mut_slice()[..w], &src[off..off + w]);
        }
    }
    let fill = t.elapsed().as_secs_f64() / reps as f64;
    let t = Instant::now();
    for _ in 0..reps {
        for (k, off) in (0..n).step_by(chunk).enumerate() {
            let w = chunk.min(n - off);
            let b = if k & 1 == 0 { &mut p0 } else { &mut p1 };
            pin_fill(&mut b.as_mut_slice()[..w], &src[off..off + w]);
            let mut view = d.slice_mut(off..off + w);
            unsafe { cu::memcpy_htod_async(*view.device_ptr_mut(), &b.as_slice()[..w], *dev.cu_stream()) }.unwrap();
            dev.synchronize().unwrap();
        }
    }
    let staged = t.elapsed().as_secs_f64() / reps as f64;
    // double-buffered on a copy stream: the fill of chunk k+1 rides the DMA of chunk k
    let stream = dev.fork_default_stream().unwrap();
    let t = Instant::now();
    for _ in 0..reps {
        let mut pending = false;
        for (k, off) in (0..n).step_by(chunk).enumerate() {
            let w = chunk.min(n - off);
            if k >= 2 || (pending && k >= 1) {
                // the buffer we are about to refill was handed to the DMA two chunks ago
            }
            let b = if k & 1 == 0 { &mut p0 } else { &mut p1 };
            if k >= 2 { unsafe { cu::stream::synchronize(stream.stream) }.unwrap(); }
            pin_fill(&mut b.as_mut_slice()[..w], &src[off..off + w]);
            let mut view = d.slice_mut(off..off + w);
            unsafe { cu::memcpy_htod_async(*view.device_ptr_mut(), &b.as_slice()[..w], stream.stream) }.unwrap();
            pending = true;
        }
        unsafe { cu::stream::synchronize(stream.stream) }.unwrap();
    }
    let piped = t.elapsed().as_secs_f64() / reps as f64;
    eprintln!(
        "[UPERF3-AJ] h2d {gb:.2} GB x{reps}: pageable {pageable:.4} s = {:.2} GB/s | pin fill {fill:.4} = {:.2} | staged serial {staged:.4} = {:.2} | double-buffered {piped:.4} = {:.2} GB/s",
        gb / pageable, gb / fill, gb / staged, gb / piped
    );
}

/// [UPERF3-AO] `HL_GPU_BENCH_REENC=1` on `gpu-probe`: LEVER L9's
/// attribution harness — the opening's chunked re-encode, kernel by
/// kernel, at the 8B pass's PCS shape (`log_cols` 14, `inv_rate` 4, 256
/// opened columns) but at a row count small enough to be safe on an 8 GB
/// card. Diagnostic only: nothing here runs on a proof path and no proof
/// byte depends on it. Knobs: `HL_BENCH_ROWS` (default 1024),
/// `HL_BENCH_LOGN` (14), `HL_BENCH_RATE` (4), `HL_BENCH_Q` (256),
/// `HL_BENCH_REPS` (5).
fn reenc_bench(g: &mut Gpu) {
    let envu = |k: &str, d: usize| std::env::var(k).ok().and_then(|v| v.parse().ok()).unwrap_or(d);
    let list: Vec<usize> = std::env::var("HL_BENCH_ROWS")
        .ok()
        .map(|v| v.split(',').filter_map(|x| x.trim().parse().ok()).collect())
        .filter(|v: &Vec<usize>| !v.is_empty())
        .unwrap_or_else(|| vec![1024]);
    for rows in list {
        reenc_bench_at(g, rows);
    }
}

fn reenc_bench_at(g: &mut Gpu, rows: usize) {
    let envu = |k: &str, d: usize| std::env::var(k).ok().and_then(|v| v.parse().ok()).unwrap_or(d);
    let log_n = envu("HL_BENCH_LOGN", 14) as u32;
    let inv_rate = envu("HL_BENCH_RATE", 4);
    let q = envu("HL_BENCH_Q", 256);
    let reps = envu("HL_BENCH_REPS", 5).max(1);
    let chunk = chunk_rows();
    let log_nn = log_n + inv_rate.trailing_zeros();
    let n = 1usize << log_n;
    let nn = 1usize << log_nn;
    // [ZK60-CL15] nothing to open: say so and stop, rather than reach the
    // residue list's last entry (the site the round-9 review flagged).
    if q == 0 {
        eprintln!("[UPERF3-AO] reenc bench: HL_BENCH_Q=0 opens no columns; nothing to time, skipping rows {rows}");
        return;
    }
    let ntt = NttTables::new(log_nn);
    if let Err(e) = g.ensure_twiddles(&ntt) {
        eprintln!("[UPERF3-AO] reenc bench: twiddles: {e}");
        return;
    }
    let dev = g.dev.clone();
    let mut s = 0x5EED_A0A0_0000_0001u64;
    let host: Vec<u64> = (0..rows * n)
        .map(|_| {
            s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            s % P
        })
        .collect();
    let mut d_data = match Pooled::take(&dev, rows * n) {
        Ok(b) => b,
        Err(e) => { eprintln!("[UPERF3-AO] reenc bench: data alloc: {e}"); return; }
    };
    if let Err(e) = dev.htod_sync_copy_into(&host, d_data.get_mut()) {
        eprintln!("[UPERF3-AO] reenc bench: upload: {e}");
        return;
    }
    drop(host);
    // indices in the shape `Transcript::challenge_indices` draws them
    let mut t = 0x1234_5678_9ABC_DEF0u64;
    let idx: Vec<usize> = (0..q)
        .map(|_| {
            t = t.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            ((t >> 33) as usize) % nn
        })
        .collect();
    let dc = DevCommit { rows, log_n, log_nn, data: d_data, enc: None, zk: None };

    // ---- the whole thing, as the opening calls it
    let mut full = f64::MAX;
    for _ in 0..reps.max(2) {
        let t0 = Instant::now();
        match g.columns_chunked(&dc, &idx, chunk) {
            Ok(_) => {}
            Err(e) => { eprintln!("[UPERF3-AO] reenc bench: columns_chunked: {e}"); return; }
        }
        full = full.min(t0.elapsed().as_secs_f64());
    }

    // ---- kernel by kernel over the same chunk plan
    let plan = chunk_plan(rows, chunk);
    let rmax = plan.iter().map(|&(_, rc)| rc).max().unwrap();
    let (mut d_coef, mut d_enc) = match (Pooled::take_min(&dev, rmax * n), Pooled::take_min(&dev, rmax * nn)) {
        (Ok(a), Ok(b)) => (a, b),
        _ => { eprintln!("[UPERF3-AO] reenc bench: scratch alloc failed"); return; }
    };
    // [ZK60-CL15] the slot map and index list from the SAME pure plan the
    // openings consume (fusion requested, no pruning: the bench uploads both
    // the dense-fused selector and the plain list and times each kernel).
    let p = match plan_open_indices(&idx, nn, 1usize << NTT_LOG_BLK, P2SP_NC, true, false) {
        Ok(OpenPlan::Open(p)) => p,
        Ok(OpenPlan::Empty) => { eprintln!("[UPERF3-AO] reenc bench: no indices to open, skipping"); return; }
        Err(e) => { eprintln!("[UPERF3-AO] reenc bench: index plan: {e}"); return; }
    };
    let uniq = p.uniq.len();
    let d_sel = dev.htod_sync_copy(&p.sel).unwrap();
    let d_idx = dev.htod_sync_copy(&p.idx32).unwrap();
    // [UPERF3-AO] rung 3's compact residue list, exactly as `columns_chunked`
    // builds it — [ZK60-CL15] through the shared `residue_list` (the bench
    // times the pruned kernel regardless of the `nq * 4 <= blk` rule, so it
    // asks for the list directly; `q > 0` was checked above, so it exists).
    let blk = 1usize << NTT_LOG_BLK;
    let (qs, nq) = match residue_list(&idx, blk, P2SP_NC) {
        Some(v) => v,
        None => { eprintln!("[UPERF3-AO] reenc bench: empty residue list, skipping"); return; }
    };
    let d_ql = dev.htod_sync_copy(&qs).unwrap();
    let mut d_out = unsafe { dev.alloc::<u64>(rows * q) }.unwrap();
    let threads = ntt_threads();
    let scale: u64 = Fp::new(1u64 << log_n).inv().0;
    let rb = log_nn - log_n;
    let (_, tf, ti) = g.tw.as_ref().unwrap();

    macro_rules! timed {
        ($body:block) => {{
            $body
            dev.synchronize().unwrap();
            let mut best = f64::MAX;
            for _ in 0..reps {
                let t0 = Instant::now();
                $body
                dev.synchronize().unwrap();
                best = best.min(t0.elapsed().as_secs_f64());
            }
            best
        }};
    }

    // [UPERF3-AO] BOTH arms of each kernel in one process: the divide-indexed
    // form the lane inherited and the strength-reduced `_f` form, and the
    // 12-stage `k_dit_p1_pad` against the `_s` form that drops the rb
    // broadcast stages. Same inputs, same launch shape, back to back.
    macro_rules! bench_pa {
        ($name:expr) => {{
            let f = dev.get_func(MODULE, $name).unwrap();
            timed!({
                for &(r0, rc) in &plan {
                    let view = dc.data.get().slice(r0 * n..(r0 + rc) * n);
                    let tiles = 1u32 << (log_n - NTT_LOG_BLK);
                    let cfg = LaunchConfig { grid_dim: (rc as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
                    unsafe { f.clone().launch(cfg, (&view, d_coef.get_mut(), ti, log_n as i32)) }.unwrap();
                }
            })
        }};
    }
    macro_rules! bench_p1 {
        ($name:expr) => {{
            let f = dev.get_func(MODULE, $name).unwrap();
            timed!({
                for &(_r0, rc) in &plan {
                    let lb = log_nn.min(NTT_LOG_BLK);
                    let bpr = 1u32 << (log_nn - lb);
                    let cfg = LaunchConfig { grid_dim: (rc as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
                    unsafe { f.clone().launch(cfg, (d_coef.get(), d_enc.get_mut(), tf, log_nn as i32, n as i32, rb as i32)) }.unwrap();
                }
            })
        }};
    }
    macro_rules! bench_p2 {
        ($name:expr) => {{
            let f = dev.get_func(MODULE, $name).unwrap();
            timed!({
                for &(_r0, rc) in &plan {
                    let tiles = 1u32 << (log_nn - NTT_LOG_BLK);
                    let cfg = LaunchConfig { grid_dim: (rc as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
                    unsafe { f.clone().launch(cfg, (d_enc.get_mut(), tf, log_nn as i32, 1u64)) }.unwrap();
                }
            })
        }};
    }
    macro_rules! bench_p2g {
        ($name:expr) => {{
            let f = dev.get_func(MODULE, $name).unwrap();
            timed!({
                for &(r0, rc) in &plan {
                    let tiles = 1u32 << (log_nn - NTT_LOG_BLK);
                    let cfg = LaunchConfig { grid_dim: (rc as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
                    unsafe { f.clone().launch(cfg, (d_enc.get(), tf, log_nn as i32, 1u64, &d_sel, &mut d_out, r0 as i32, rows as i32)) }.unwrap();
                }
            })
        }};
    }

    let (t_pa, t_pa_f) = if log_n > NTT_LOG_BLK { (bench_pa!("k_dif_pa"), bench_pa!("k_dif_pa_f")) } else { (0.0, 0.0) };

    // [FSP-L9] both arms of `k_dif_pb` too (plain and swizzled shared layout)
    macro_rules! bench_pb {
        ($name:expr) => {{
            let pb = dev.get_func(MODULE, $name).unwrap();
            timed!({
                for &(_r0, rc) in &plan {
                    let bpr = 1u32 << (log_n - log_n.min(NTT_LOG_BLK));
                    let cfg = LaunchConfig { grid_dim: (rc as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
                    let cptr: sys::CUdeviceptr = *d_coef.get().device_ptr();
                    unsafe { pb.clone().launch(cfg, (cptr, d_coef.get_mut(), ti, log_n as i32, scale)) }.unwrap();
                }
            })
        }};
    }
    let t_pb = bench_pb!("k_dif_pb");
    let t_pb_z = bench_pb!("k_dif_pb_z");

    let t_p1 = bench_p1!("k_dit_p1_pad");
    let t_p1_s = bench_p1!("k_dit_p1_pad_s");
    // [FSP-L9] the swizzled-shared-layout arm of the biggest kernel
    let t_p1_sz = bench_p1!("k_dit_p1_pad_sz");
    // [FSP-L9] the COMPACT producer/consumer pair
    let nqp = qs.len();
    let compact_ok = log_nn > NTT_LOG_BLK && log_nn - NTT_LOG_BLK <= 5;
    let t_p1_c = if compact_ok {
        let f = dev.get_func(MODULE, "k_dit_p1_pad_c").unwrap();
        timed!({
            for &(_r0, rc) in &plan {
                let bpr = 1u32 << (log_nn - log_nn.min(NTT_LOG_BLK));
                let cfg = LaunchConfig { grid_dim: (rc as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
                unsafe { f.clone().launch(cfg, (d_coef.get(), d_enc.get_mut(), tf, log_nn as i32, n as i32, rb as i32, &d_ql, nqp as i32)) }.unwrap();
            }
        })
    } else { 0.0 };
    let t_p2g_spc = if compact_ok {
        let f = dev.get_func(MODULE, "k_ntt_p2_gather_spc").unwrap();
        let gx = (nq.div_ceil(P2SP_NC)) as u32;
        timed!({
            for &(r0, rc) in &plan {
                let cfg = LaunchConfig { grid_dim: (gx, rc as u32, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
                unsafe { f.clone().launch(cfg, (d_enc.get(), tf, log_nn as i32, 1u64, &d_sel, &mut d_out, r0 as i32, rows as i32, &d_ql, nq as i32, nqp as i32)) }.unwrap();
            }
        })
    } else { 0.0 };

    let (t_p2, t_p2_f) = if log_nn > NTT_LOG_BLK { (bench_p2!("k_ntt_p2"), bench_p2!("k_ntt_p2_f")) } else { (0.0, 0.0) };
    let (t_p2g, t_p2g_f) = if log_nn > NTT_LOG_BLK { (bench_p2g!("k_ntt_p2_gather"), bench_p2g!("k_ntt_p2_gather_f")) } else { (0.0, 0.0) };
    let t_p2g_sp = if log_nn > NTT_LOG_BLK && log_nn - NTT_LOG_BLK <= 5 {
        let f = dev.get_func(MODULE, "k_ntt_p2_gather_sp").unwrap();
        let gx = (nq.div_ceil(P2SP_NC)) as u32;
        timed!({
            for &(r0, rc) in &plan {
                let cfg = LaunchConfig { grid_dim: (gx, rc as u32, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
                unsafe { f.clone().launch(cfg, (d_enc.get(), tf, log_nn as i32, 1u64, &d_sel, &mut d_out, r0 as i32, rows as i32, &d_ql, nq as i32)) }.unwrap();
            }
        })
    } else { 0.0 };

    let gc = dev.get_func(MODULE, "k_gather_cols_off").unwrap();
    let t_gc = timed!({
        for &(r0, rc) in &plan {
            let cfg = LaunchConfig::for_num_elems((rc * q) as u32);
            unsafe { gc.clone().launch(cfg, (d_enc.get(), &mut d_out, &d_idx, rc as i32, r0 as i32, rows as i32, nn as i32, q as i32)) }.unwrap();
        }
    });

    let t_d2h = {
        let t0 = Instant::now();
        let _ = dev.dtoh_sync_copy(&d_out).unwrap();
        t0.elapsed().as_secs_f64()
    };

    // butterflies per row, pass by pass
    let bf = |stages: u32, half: usize| stages as f64 * half as f64 * rows as f64;
    let bf_pa = bf(log_n.saturating_sub(NTT_LOG_BLK), n / 2);
    let bf_pb = bf(log_n.min(NTT_LOG_BLK), n / 2);
    let bf_p1 = bf(log_nn.min(NTT_LOG_BLK), nn / 2);
    let bf_p2 = bf(log_nn.saturating_sub(NTT_LOG_BLK), nn / 2);
    let bf_all = bf_pa + bf_pb + bf_p1 + bf_p2;
    // the `_s` arm does rb fewer stages of the forward DIT's first pass
    let bf_p1_s = bf(log_nn.min(NTT_LOG_BLK) - (log_nn - log_n).min(log_nn.min(NTT_LOG_BLK)), nn / 2);
    // global traffic per pass (bytes)
    let gb_pa = 2.0 * (rows * n * 8) as f64;
    let gb_pb = 2.0 * (rows * n * 8) as f64;
    let gb_p1 = (rows * (n + nn) * 8) as f64;
    let gb_p2 = 2.0 * (rows * nn * 8) as f64;
    let gb_p2g = (rows * nn * 8) as f64 + (rows * uniq * 8) as f64;
    let gb_gc = (rows * nn * 8) as f64 + (rows * q * 8) as f64;
    let kern = t_pa + t_pb + t_p1 + t_p2g;
    let kern_f = t_pa_f + t_pb + t_p1_s + t_p2g_f;
    let kern_sp = t_pa_f + t_pb + t_p1_s + t_p2g_sp;
    // [FSP-L9] the four kernels with this lane's two swizzled forms in
    let kern_z = t_pa_f + t_pb_z + t_p1_sz + t_p2g_sp;
    // [FSP-L9] the four kernels with the COMPACT producer/consumer pair in
    let kern_c = t_pa_f + t_pb + t_p1_c + t_p2g_spc;
    let line = |name: &str, t: f64, b: f64, gb: f64| {
        eprintln!(
            "[UPERF3-AO]   {name:<18} {t:.5} s  {:>6.2}% of the four  {:>8.2} e9 bf/s  {:>7.1} GB/s",
            if kern > 0.0 { 100.0 * t / kern } else { 0.0 },
            if t > 0.0 { b / t / 1e9 } else { 0.0 },
            if t > 0.0 { gb / t / 1e9 } else { 0.0 }
        );
    };
    let ab = |name: &str, base: f64, fast: f64| {
        eprintln!(
            "[UPERF3-AO]   A/B {name:<18} base {base:.5} -> {fast:.5} s   {:.3}x",
            if fast > 0.0 { base / fast } else { 0.0 }
        );
    };
    eprintln!(
        "[UPERF3-AO] L9 re-encode bench: rows {rows} log_n {log_n} -> log_nn {log_nn} (inv_rate {inv_rate}), q {q} ({uniq} distinct), chunk {chunk} rows x {} chunks, {threads} threads/block, best of {reps}",
        plan.len()
    );
    eprintln!(
        "[UPERF3-AO]   columns_chunked  {full:.5} s  (the opening's call; {:.2} e9 bf/s over {:.3} e9 butterflies)",
        bf_all / full / 1e9,
        bf_all / 1e9
    );
    line("k_dif_pa", t_pa, bf_pa, gb_pa);
    line("k_dif_pb", t_pb, bf_pb, gb_pb);
    line("k_dit_p1_pad", t_p1, bf_p1, gb_p1);
    line("k_ntt_p2_gather", t_p2g, bf_p2, gb_p2g);
    eprintln!("[UPERF3-AO]   --- not in the fused path, for reference ---");
    line("k_ntt_p2", t_p2, bf_p2, gb_p2);
    line("k_gather_cols_off", t_gc, 0.0, gb_gc);
    eprintln!("[UPERF3-AO]   --- lever L9 rung 2, both arms back to back ---");
    line("k_dif_pa_f", t_pa_f, bf_pa, gb_pa);
    line("k_dit_p1_pad_s", t_p1_s, bf_p1_s, gb_p1);
    line("k_ntt_p2_gather_f", t_p2g_f, bf_p2, gb_p2g);
    line("k_ntt_p2_f", t_p2_f, bf_p2, gb_p2);
    ab("k_dif_pa", t_pa, t_pa_f);
    ab("k_dit_p1_pad", t_p1, t_p1_s);
    ab("k_ntt_p2_gather", t_p2g, t_p2g_f);
    ab("k_ntt_p2", t_p2, t_p2_f);
    ab("four kernels", kern, kern_f);
    eprintln!("[UPERF3-AO]   --- lever L9 rung 3, the output-pruned last stage group ---");
    eprintln!(
        "[UPERF3-AO]   k_ntt_p2_gather_sp {t_p2g_sp:.5} s over {nq} distinct residues of {} ({:.1}% of the dense axis)",
        1usize << NTT_LOG_BLK,
        100.0 * nq as f64 / (1usize << NTT_LOG_BLK) as f64
    );
    ab("p2_gather_f -> sp", t_p2g_f, t_p2g_sp);
    ab("four kernels (sp)", kern, kern_sp);
    eprintln!("[FSP-L9]   --- the swizzled shared layout on the two contiguous-tile kernels ---");
    line("k_dit_p1_pad_sz", t_p1_sz, bf_p1_s, gb_p1);
    line("k_dif_pb_z", t_pb_z, bf_pb, gb_pb);
    ab("p1_pad_s -> _sz", t_p1_s, t_p1_sz);
    ab("dif_pb -> _z", t_pb, t_pb_z);
    ab("four kernels (sp+z)", kern_sp, kern_z);
    eprintln!("[FSP-L9]   --- the compact producer/consumer pair (the opening's expand transform writes only what its consumer reads) ---");
    let nt_c = 1usize << (log_nn.saturating_sub(NTT_LOG_BLK));
    let gb_p1_c = (rows * n * 8) as f64 + (rows * nt_c * nqp * 8) as f64;
    eprintln!("[FSP-L9]   its global traffic is {:.0} MB against {:.0} MB (reads unchanged, stores {:.1}x fewer)",
        gb_p1_c / 1e6, gb_p1 / 1e6, (rows * nn) as f64 / (rows * nt_c * nqp) as f64);
    line("k_dit_p1_pad_c", t_p1_c, bf_p1_s, gb_p1_c);
    eprintln!("[FSP-L9]   k_ntt_p2_gather_spc {t_p2g_spc:.5} s");
    ab("p1_pad_s -> _c", t_p1_s, t_p1_c);
    ab("p2g_sp -> _spc", t_p2g_sp, t_p2g_spc);
    ab("the pair sp -> c", t_p1_s + t_p2g_sp, t_p1_c + t_p2g_spc);
    ab("four kernels sp -> c", kern_sp, kern_c);
    eprintln!(
        "[UPERF3-AO]   four kernels {kern:.5} s | d2h {t_d2h:.5} s | columns_chunked {full:.5} s => launch/alloc/host residue {:.5} s ({:.1}%)",
        full - kern - t_d2h,
        100.0 * (full - kern - t_d2h) / full
    );
}

// ---------------------------------------------------------------------------
// [rung 1] The device-resident commitment: the systematic data (rows x n)
// and the RS-encoded matrix (rows x nn) stay on the device; the column
// hashes come back to the host (rung 1: the whole encoded matrix comes
// back and is hashed by the CPU code; rung 2 hashes on the device).

pub struct DevCommit {
    pub rows: usize,
    pub log_n: u32,
    pub log_nn: u32,
    pub(super) data: Pooled,
    /// [UPERF3-AC] `None` for a CHUNKED commitment: the encoding was never
    /// resident (hashed chunk by chunk) and the opening re-encodes it chunk
    /// by chunk from `data` (`dev_columns`).
    pub(super) enc: Option<Pooled>,
    /// [ZK60-CL1] Present only for a chunked HIDING commitment. A hiding
    /// encoding is `expand(pad_scale(ntt(data), pads, pows))`, so re-encoding
    /// it from `data` alone would drop the pads and the coset scaling and
    /// return the WRONG columns. Keeping the pads (`rows*q`) and powers
    /// (`nn`) resident costs ~21.5 MiB at the Mistral W shape against the
    /// 5,387 MiB the dropped `enc` frees, and lets `dev_columns` stay the
    /// single opening entry point.
    pub(super) zk: Option<ZkReenc>,
}

/// [ZK60-CL1] What a chunked hiding commitment needs to re-encode itself.
pub(super) struct ZkReenc {
    pads: CudaSlice<u64>,
    pows: CudaSlice<u64>,
    q: usize,
}

/// [rung 2] stage-major layout: stage s (half = 2^(s-1)) owns entries
/// [half - 1, 2 half - 1) = the CPU table's `t[k << (ml - s)]`, k < half.
///
/// [ZK60-CL2] Factored out of `ensure_twiddles` so the monotonic-cache
/// invariant can be asserted against THE REAL LAYOUT rather than a copy of it
/// in a test. Note the stored value, `t[k << (ml - s)]`, equals `w_{2^s}^k`
/// for every `ml >= s` — so this function's output for a larger `ml` extends
/// its output for a smaller one, entry for entry.
fn stage_major(t: &[Fp], ml: u32) -> Vec<u64> {
    let mut out = Vec::with_capacity((1usize << ml) - 1);
    for s in 1..=ml {
        let half = 1usize << (s - 1);
        for k in 0..half {
            out.push(t[k << (ml - s)].0);
        }
    }
    out
}

/// [ZK60-CL2] The stage-major forward/inverse tables a given `max_log` would
/// upload — exposed so the prefix invariant is testable without a device.
pub fn stage_major_twiddles_for_test(max_log: u32) -> (Vec<u64>, Vec<u64>) {
    let ntt = NttTables::new(max_log);
    let (f, i) = ntt.twiddle_tables();
    (stage_major(f, max_log), stage_major(i, max_log))
}

impl Gpu {
    /// [ZK60-CL2] MONOTONIC: keep the LARGEST tables seen, never shrink.
    ///
    /// This used to replace the tables on `*ml != ntt.max_log`, i.e. it also
    /// installed SMALLER ones. That was harmless while every opening read a
    /// retained `enc` (a pure gather, no NTT). CL1's deferred opening
    /// re-encodes, so a commitment outlives the tables it needs: commit big,
    /// commit small (tables shrink), open big -> `log_n <= max_log` fails.
    ///
    /// Growing only is CORRECT, not merely safe, and the invariant is exact.
    /// `twiddles[j] = w_{2^ml}^j`, and the stage-major layout stores stage `s`
    /// entry `k` at `t[k << (ml - s)] = w_{2^ml}^(k·2^(ml-s)) = w_{2^s}^k`,
    /// which does not mention `ml`. So a table built at a larger `max_log`
    /// holds bit-identical entries for every stage a smaller one covers, and
    /// is a strict prefix-extension of it. `zk60_gpu_commit.rs` asserts that
    /// prefix equality directly rather than trusting this comment.
    fn ensure_twiddles(&mut self, ntt: &NttTables) -> Result<(), String> {
        if let Some((ml, _, _)) = &self.tw {
            if *ml >= ntt.max_log {
                return Ok(());
            }
        }
        // [rung 2] stage-major layout: stage s (half = 2^(s-1)) owns entries
        // [half - 1, 2 half - 1) = the CPU table's tw[k << (max_log - s)], k < half.
        let (f, i) = ntt.twiddle_tables();
        let ml = ntt.max_log;
        let df = self.dev.htod_sync_copy(&stage_major(f, ml)).map_err(|e| format!("twiddle upload: {e}"))?;
        let di = self.dev.htod_sync_copy(&stage_major(i, ml)).map_err(|e| format!("twiddle upload: {e}"))?;
        self.tw = Some((ml, df, di));
        Ok(())
    }

    /// One transform of `rows` rows: src (rows x n_src, positions >= n_src
    /// read as zero) -> dst (rows x 2^log_n), forward or inverse (the
    /// inverse includes the 1/n scale), == ntt.rs on every row.
    fn ntt_rows(&self, src: &CudaSlice<u64>, dst: &mut CudaSlice<u64>, rows: usize, n_src: usize, log_n: u32, inverse: bool) -> Result<(), String> {
        let (max_log, tf, ti) = self.tw.as_ref().ok_or("twiddles not uploaded")?;
        let max_log = *max_log;
        assert!(log_n <= max_log, "device ntt size 2^{log_n} exceeds tables (2^{max_log})");
        assert!(log_n <= NTT_LOG_BLK + 12);
        let tw = if inverse { ti } else { tf };
        let scale: u64 = if inverse { Fp::new(1u64 << log_n).inv().0 } else { 1 };
        let p1 = self.dev.get_func(MODULE, "k_ntt_p1").ok_or("k_ntt_p1 missing")?;
        let lb = log_n.min(NTT_LOG_BLK);
        let blocks_per_row = 1u32 << (log_n - lb);
        let cfg1 = LaunchConfig { grid_dim: (rows as u32 * blocks_per_row, 1, 1), block_dim: (ntt_threads(), 1, 1), shared_mem_bytes: 0 };
        let vb = verbose();
        let ta = Instant::now();
        unsafe { p1.launch(cfg1, (src, &mut *dst, tw, log_n as i32, n_src as i32, scale)) }.map_err(|e| format!("k_ntt_p1: {e}"))?;
        if vb { self.dev.synchronize().map_err(|e| e.to_string())?; }
        let tb = Instant::now();
        if log_n > NTT_LOG_BLK {
            let p2 = self.dev.get_func(MODULE, kn_ntt_p2()).ok_or("k_ntt_p2 missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg2 = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (ntt_threads(), 1, 1), shared_mem_bytes: 0 };
            unsafe { p2.launch(cfg2, (&mut *dst, tw, log_n as i32, scale)) }.map_err(|e| format!("k_ntt_p2: {e}"))?;
        }
        if vb {
            self.dev.synchronize().map_err(|e| e.to_string())?;
            eprintln!("[UPERF3-XX]   ntt rows {rows} 2^{log_n} (n_src {n_src}, inverse {inverse}): p1 {:.4} | p2 {:.4} s", (tb - ta).as_secs_f64(), tb.elapsed().as_secs_f64());
        }
        Ok(())
    }

    /// [ZK60-CL1] `ntt_rows` over a VIEW of the source (a row chunk). Same
    /// kernels, same launch shapes, same twiddles, same scale — the only
    /// difference is where the rows are read from, so a chunked encode is
    /// bit-for-bit the resident encode.
    fn ntt_rows_view(&self, src: &CudaView<u64>, dst: &mut CudaSlice<u64>, rows: usize, n_src: usize, log_n: u32, inverse: bool) -> Result<(), String> {
        let (max_log, tf, ti) = self.tw.as_ref().ok_or("twiddles not uploaded")?;
        let max_log = *max_log;
        assert!(log_n <= max_log, "device ntt size 2^{log_n} exceeds tables (2^{max_log})");
        assert!(log_n <= NTT_LOG_BLK + 12);
        let tw = if inverse { ti } else { tf };
        let scale: u64 = if inverse { Fp::new(1u64 << log_n).inv().0 } else { 1 };
        let p1 = self.dev.get_func(MODULE, "k_ntt_p1").ok_or("k_ntt_p1 missing")?;
        let lb = log_n.min(NTT_LOG_BLK);
        let blocks_per_row = 1u32 << (log_n - lb);
        let cfg1 = LaunchConfig { grid_dim: (rows as u32 * blocks_per_row, 1, 1), block_dim: (ntt_threads(), 1, 1), shared_mem_bytes: 0 };
        unsafe { p1.launch(cfg1, (src, &mut *dst, tw, log_n as i32, n_src as i32, scale)) }.map_err(|e| format!("k_ntt_p1: {e}"))?;
        if log_n > NTT_LOG_BLK {
            let p2 = self.dev.get_func(MODULE, kn_ntt_p2()).ok_or("k_ntt_p2 missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg2 = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (ntt_threads(), 1, 1), shared_mem_bytes: 0 };
            unsafe { p2.launch(cfg2, (&mut *dst, tw, log_n as i32, scale)) }.map_err(|e| format!("k_ntt_p2: {e}"))?;
        }
        Ok(())
    }

    /// [ZK60-CL1] One row chunk of the HIDING encode: exactly the three steps
    /// `dev_commit_zk_from` runs resident — forward NTT to coefficients, then
    /// `k_zk_pad_scale` (append this chunk's `q` pads and scale by the coset
    /// powers), then the expand NTT. `pads` is sliced to the chunk because it
    /// is per ROW; `pows` is per COLUMN and shared by every chunk.
    ///
    /// [ZK60-CL18] `pw` is the pad/scale output's ROW STRIDE — `nn` (the
    /// reference form) or `n + q` (the compact form), decided by
    /// `zk_pad_width` at the caller that sized `coef2`. It is the width
    /// argument of `k_zk_pad_scale` AND the `n_src` of the expand NTT's
    /// `k_ntt_p1`, so the two can never disagree; `coef2` must hold
    /// `rows * pw`, asserted here so a stale stride cannot read past it.
    #[allow(clippy::too_many_arguments)]
    fn encode_rows_view_zk(&self, data: &CudaView<u64>, pads: &CudaView<u64>, pows: &CudaSlice<u64>,
                           coef: &mut CudaSlice<u64>, coef2: &mut CudaSlice<u64>, enc: &mut CudaSlice<u64>,
                           rows: usize, n: usize, q: usize, nn: usize, pw: usize, log_n: u32, log_nn: u32) -> Result<(), String> {
        assert!(pw == nn || pw == n + q, "[ZK60-CL18] pad/scale width {pw} is neither nn {nn} nor n + q {}", n + q);
        assert!(coef2.len() >= rows * pw && enc.len() >= rows * nn && pw <= nn);
        self.ntt_rows_view(data, coef, rows, n, log_n, true)?;
        let f = self.dev.get_func(MODULE, "k_zk_pad_scale").ok_or("k_zk_pad_scale missing")?;
        let cfg = LaunchConfig::for_num_elems((rows * pw) as u32);
        unsafe { f.launch(cfg, (&*coef, pads, pows, &mut *coef2, rows as i32, n as i32, q as i32, pw as i32)) }
            .map_err(|e| format!("k_zk_pad_scale: {e}"))?;
        self.ntt_rows(coef2, enc, rows, pw, log_nn, false)?;
        Ok(())
    }

    /// [ZK60-CL7] `encode_rows_view_zk` for the OPENING. The inverse NTT and
    /// `k_zk_pad_scale` are exactly `encode_rows_view_zk`'s. The expand NTT's
    /// first stage group is `k_ntt_p1` launched exactly as `ntt_rows` launches
    /// it (forward, scale 1, `n_src = nn`), so `k_ntt_p2_gather*` reads the
    /// layout `k_ntt_p2` would have read; its last stage group then writes
    /// only the `sel`-marked columns straight into `out` — pruned to the
    /// compact residue list when the caller supplied one, dense otherwise.
    /// Identical values: the same kernels, the same twiddles, the same order.
    /// The `k_ntt_p2` store and the `k_gather_cols_off` load of the encoded
    /// chunk are what disappear.
    ///
    /// [ZK60-CL18] `pw` as in `encode_rows_view_zk`: the pad/scale row stride
    /// and the `n_src` of the `k_ntt_p1` launch below, `nn` or `n + q`.
    #[allow(clippy::too_many_arguments)]
    fn encode_rows_view_zk_gather(&self, data: &CudaView<u64>, pads: &CudaView<u64>, pows: &CudaSlice<u64>,
                                  coef: &mut CudaSlice<u64>, coef2: &mut CudaSlice<u64>, enc: &mut CudaSlice<u64>,
                                  rows: usize, n: usize, q: usize, nn: usize, pw: usize, log_n: u32, log_nn: u32,
                                  d_sel: &CudaSlice<i32>, out: &mut CudaSlice<u64>, row0: usize, rows_total: usize,
                                  sp: Option<(&CudaSlice<i32>, usize)>) -> Result<(), String> {
        if log_nn <= NTT_LOG_BLK {
            return Err("gather fusion needs log_nn > NTT_LOG_BLK".into());
        }
        assert!(pw == nn || pw == n + q, "[ZK60-CL18] pad/scale width {pw} is neither nn {nn} nor n + q {}", n + q);
        assert!(coef2.len() >= rows * pw && enc.len() >= rows * nn && pw <= nn);
        self.ntt_rows_view(data, coef, rows, n, log_n, true)?;
        let f = self.dev.get_func(MODULE, "k_zk_pad_scale").ok_or("k_zk_pad_scale missing")?;
        let cfg = LaunchConfig::for_num_elems((rows * pw) as u32);
        unsafe { f.launch(cfg, (&*coef, pads, pows, &mut *coef2, rows as i32, n as i32, q as i32, pw as i32)) }
            .map_err(|e| format!("k_zk_pad_scale: {e}"))?;
        let (max_log, tf, _ti) = self.tw.as_ref().ok_or("twiddles not uploaded")?;
        assert!(log_nn <= *max_log, "device ntt size 2^{log_nn} exceeds tables (2^{max_log})");
        let threads = ntt_threads();
        let p1 = self.dev.get_func(MODULE, "k_ntt_p1").ok_or("k_ntt_p1 missing")?;
        let bpr = 1u32 << (log_nn - NTT_LOG_BLK);
        let cfg1 = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
        unsafe { p1.launch(cfg1, (&*coef2, &mut *enc, tf, log_nn as i32, pw as i32, 1u64)) }.map_err(|e| format!("k_ntt_p1: {e}"))?;
        if let Some((ql, nq)) = sp {
            let p2 = self.dev.get_func(MODULE, "k_ntt_p2_gather_sp").ok_or("k_ntt_p2_gather_sp missing")?;
            let gx = ((nq + P2SP_NC - 1) / P2SP_NC) as u32;
            let cfg2 = LaunchConfig { grid_dim: (gx, rows as u32, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { p2.launch(cfg2, (&*enc, tf, log_nn as i32, 1u64, d_sel, &mut *out, row0 as i32, rows_total as i32, ql, nq as i32)) }
                .map_err(|e| format!("k_ntt_p2_gather_sp: {e}"))?;
        } else {
            let p2 = self.dev.get_func(MODULE, kn_ntt_p2_gather()).ok_or("k_ntt_p2_gather missing")?;
            let tiles = 1u32 << (log_nn - NTT_LOG_BLK);
            let cfg2 = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { p2.launch(cfg2, (&*enc, tf, log_nn as i32, 1u64, d_sel, &mut *out, row0 as i32, rows_total as i32)) }
                .map_err(|e| format!("k_ntt_p2_gather: {e}"))?;
        }
        Ok(())
    }

    /// [ZK60-CL1] The chunked HIDING commitment. Mirrors `commit_chunked`:
    /// walk `chunk_plan`, encode each row chunk, fold it into the per-column
    /// blake3 state with `k_hash_cols_stream`, and take the leaves from the
    /// last chunk. Same kernels and same order as the resident path, so the
    /// leaves are bit-for-bit identical; only the peak memory differs.
    #[allow(clippy::too_many_arguments)]
    fn commit_zk_chunked(&self, d_data: &Pooled, d_pads: &CudaSlice<u64>, d_pows: &CudaSlice<u64>,
                         rows: usize, n: usize, q: usize, nn: usize, log_n: u32, log_nn: u32,
                         chunk: usize) -> Result<Vec<Digest>, String> {
        let dev = self.dev.clone();
        let plan = chunk_plan(rows, chunk);
        let rmax = plan.iter().map(|&(_, rc)| rc).max().unwrap();
        // [ZK60-CL18] the pad/scale output width — `nn`, or `n + q` under the
        // compact switch — decided (or refused) BEFORE any scratch is taken,
        // and the ONLY `take_min` it changes is `d_coef2`
        let pw = zk_pad_width(n, q, nn, zk_compact_pad())?;
        let t0 = Instant::now();
        let mut d_coef = Pooled::take_min(&dev, rmax * n)?;
        let mut d_coef2 = Pooled::take_min(&dev, rmax * pw)?;
        let mut d_enc = Pooled::take_min(&dev, rmax * nn)?;
        let state_words = B3_STATE_SLOTS * nn;
        let mut d_state = Pooled::take_min(&dev, (state_words + 1) / 2)?;
        dev.memset_zeros(d_state.get_mut()).map_err(|e| format!("state memset: {e}"))?;
        let mut d_leaves = unsafe { dev.alloc::<u32>(nn * 8) }.map_err(|e| format!("leaves alloc: {e}"))?;
        note_raw_alloc(nn * 8 * 4); // [round-7 review] the leaf buffer is a raw allocation too
        let f_hash = dev.get_func(MODULE, "k_hash_cols_stream").ok_or("k_hash_cols_stream missing")?;
        note_vram(self);
        for &(r0, rc) in &plan {
            let dview = d_data.get().slice(r0 * n..(r0 + rc) * n);
            let pview = d_pads.slice(r0 * q..(r0 + rc) * q);
            self.encode_rows_view_zk(&dview, &pview, d_pows, d_coef.get_mut(), d_coef2.get_mut(), d_enc.get_mut(),
                                     rc, n, q, nn, pw, log_n, log_nn)?;
            let cfg = LaunchConfig::for_num_elems(nn as u32);
            unsafe { f_hash.clone().launch(cfg, (d_enc.get(), d_state.get_mut(), rc as i32, r0 as i32, rows as i32, nn as i32, &mut d_leaves)) }
                .map_err(|e| format!("k_hash_cols_stream: {e}"))?;
        }
        let words = dev.dtoh_sync_copy(&d_leaves).map_err(|e| format!("leaves download: {e}"))?;
        let mut leaves = vec![[0u8; 32]; nn];
        for (j, leaf) in leaves.iter_mut().enumerate() {
            for w in 0..8 {
                leaf[4 * w..4 * w + 4].copy_from_slice(&words[j * 8 + w].to_le_bytes());
            }
        }
        let total = t0.elapsed().as_secs_f64();
        if verbose() {
            let how = if pw != nn { format!(", compact pad {pw} of {nn}") } else { String::new() };
            eprintln!("[ZK60-CL1]   chunked ZK commit rows {rows} 2^{log_n} -> 2^{log_nn} (q {q}) in {} chunks of <= {rmax}{how}: {total:.4} s", plan.len());
        }
        stats_with(|s| { s.secs_ntt += total; s.n_chunked += 1; s.bytes_d2h += (nn * 32) as u64; });
        Ok(leaves)
    }

    /// [ZK60-CL1] The opening for a chunked HIDING commitment: re-encode each
    /// row chunk THROUGH THE PAD/COSET STEP and gather the sampled columns.
    /// `columns_chunked` cannot serve this — it re-encodes with neither the
    /// pads nor the coset scaling, so it would return the wrong columns.
    fn columns_chunked_zk(&self, dc: &DevCommit, zk: &ZkReenc, idx: &[usize], chunk: usize) -> Result<Vec<Vec<Fp>>, String> {
        let dev = self.dev.clone();
        let (rows, log_n, log_nn) = (dc.rows, dc.log_n, dc.log_nn);
        let n = 1usize << log_n;
        let nn = 1usize << log_nn;
        let q_open = idx.len();
        // [ZK60-CL7] the fused form, built exactly as `columns_chunked` builds
        // it: one output slot per DISTINCT index (`challenge_indices` may
        // repeat one; duplicates are filled from the first occurrence on the
        // host), a per-column slot map for the gather kernel, and the compact
        // residue list for the pruned last stage group when it is materially
        // smaller than the dense axis. Declined below NTT_LOG_BLK, where there
        // is no second stage group to fuse.
        //
        // [ZK60-CL15] All of that is now the ONE pure plan in mod.rs, decided
        // FIRST: an empty query list opens zero columns and an out-of-range
        // index is an error, both before any scratch is taken, any list is
        // uploaded or any output is allocated. Same values as before, so the
        // proof bytes cannot move. `prune_p2()` is read here unconditionally;
        // it only reads a switch.
        let p = match plan_open_indices(idx, nn, 1usize << NTT_LOG_BLK, P2SP_NC, zk_fuse_gather() && fuse_gather(), prune_p2())? {
            OpenPlan::Empty => return Ok(Vec::new()),
            OpenPlan::Open(p) => p,
        };
        let fused = p.fused;
        let plan = chunk_plan(rows, chunk);
        let rmax = plan.iter().map(|&(_, rc)| rc).max().unwrap();
        // [ZK60-CL18] as in `commit_zk_chunked`: the pad/scale width decided
        // (or refused) before any scratch is taken; only `d_coef2` changes
        let pw = zk_pad_width(n, zk.q, nn, zk_compact_pad())?;
        let t0 = Instant::now();
        let mut d_coef = Pooled::take_min(&dev, rmax * n)?;
        let mut d_coef2 = Pooled::take_min(&dev, rmax * pw)?;
        let mut d_enc = Pooled::take_min(&dev, rmax * nn)?;
        let d_idx = dev.htod_sync_copy(p.device_index_list()).map_err(|e| e.to_string())?;
        note_raw_alloc(p.device_index_list().len() * 4);
        let blk = 1usize << NTT_LOG_BLK;
        let sp_list: Option<(CudaSlice<i32>, usize)> = match &p.residues {
            Some((qs, nq)) => {
                let b = dev.htod_sync_copy(qs).map_err(|e| e.to_string())?;
                note_raw_alloc(qs.len() * 4);
                Some((b, *nq))
            }
            None => None,
        };
        let cols_out = p.cols_out();
        let mut d_out = unsafe { dev.alloc::<u64>(rows * cols_out) }.map_err(|e| e.to_string())?;
        note_raw_alloc(rows * cols_out * 8);
        let f = dev.get_func(MODULE, "k_gather_cols_off").ok_or("k_gather_cols_off missing")?;
        for &(r0, rc) in &plan {
            let dview = dc.data.get().slice(r0 * n..(r0 + rc) * n);
            let pview = zk.pads.slice(r0 * zk.q..(r0 + rc) * zk.q);
            if fused {
                let sp = sp_list.as_ref().map(|(b, k)| (b, *k));
                self.encode_rows_view_zk_gather(&dview, &pview, &zk.pows, d_coef.get_mut(), d_coef2.get_mut(), d_enc.get_mut(),
                                                rc, n, zk.q, nn, pw, log_n, log_nn, &d_idx, &mut d_out, r0, rows, sp)?;
            } else {
                // the CL1 reference form, retained under HL_ZK_FUSE_GATHER=0
                self.encode_rows_view_zk(&dview, &pview, &zk.pows, d_coef.get_mut(), d_coef2.get_mut(), d_enc.get_mut(),
                                         rc, n, zk.q, nn, pw, log_n, log_nn)?;
                let cfg = LaunchConfig::for_num_elems((rc * q_open) as u32);
                unsafe { f.clone().launch(cfg, (d_enc.get(), &mut d_out, &d_idx, rc as i32, r0 as i32, rows as i32, nn as i32, q_open as i32)) }
                    .map_err(|e| format!("k_gather_cols_off: {e}"))?;
            }
        }
        let out = dev.dtoh_sync_copy(&d_out).map_err(|e| e.to_string())?;
        let dt = t0.elapsed().as_secs_f64();
        if verbose() {
            let mut how = match (&sp_list, fused) {
                (Some((_, nq)), _) => format!(", fused, pruned {nq}/{blk}"),
                (None, true) => ", fused".to_string(),
                _ => String::new(),
            };
            if pw != nn { how.push_str(&format!(", compact pad {pw} of {nn}")); } // [ZK60-CL18]
            eprintln!("[ZK60-CL1]   chunked ZK re-encode + gather rows {rows} ({} chunks{how}): {dt:.4} s", plan.len());
        }
        stats_with(|s| { s.secs_reenc += dt; s.bytes_d2h += (rows * cols_out * 8) as u64; });
        Ok((0..q_open)
            .map(|c| {
                let s0 = p.out_slot(c) * rows;
                out[s0..s0 + rows].iter().map(|&v| Fp(v)).collect()
            })
            .collect())
    }
}

/// Commit on the device: upload `data`, encode every row (inverse NTT of
/// size n, forward NTT of size nn = n * inv_rate with zero padding), and
/// return the device commitment plus the column leaves (rung 2: hashed on
/// the device; `HL_GPU_HOST_HASH=1` keeps rung 1's host hashing). `Err`
/// -> the caller runs the CPU body.
pub fn dev_commit(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    dev_commit_src(params, UpSrc::Words(as_u64s(data)), ntt)
}

/// [FSP-HOST] ITEM (a): the same commitment with the three int8 planes as
/// the upload's source — no converted `Vec<Fp>` is built, and the packing
/// pass reads one byte per element instead of eight. The staged bytes, the
/// device buffer after `k_widen`, the encoding, the leaves and the root are
/// the ones `dev_commit` produces from that `Vec<Fp>` (see `gpu/mod.rs`'s
/// `planes` module for why, and its oracle for the check). An `Err` is a
/// DECLINE: the caller builds the `Vec<Fp>` and calls `dev_commit`.
pub fn dev_commit_planes(params: &PcsParams, pt: &PlaneTiling, ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    // Check before choosing resident or streamed upload. The streamed
    // source has width 1 by construction and cannot honor this rollback
    // inside upload_planes(), which only the resident route calls.
    if !narrow_on() {
        return Err("HL_GPU_NARROW=0: direct plane upload disabled".into());
    }
    dev_commit_src(params, UpSrc::Planes(pt), ntt)
}

fn dev_commit_src(params: &PcsParams, src: UpSrc, ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    let n = params.cols();
    let len = src.len();
    assert!(len % n == 0 && len != 0);
    let rows = len / n;
    let nn = params.enc_cols();
    let dev = g.dev.clone();
    // [UPERF3-AJ] the chunked class with an INTERLEAVED pinned upload: the
    // bytes of the next chunk move while the current one encodes and hashes.
    // A decline here costs nothing — the block-upload body below runs.
    if stream_commit() && pin_mb() > 0 && rows * nn * 8 > chunk_bytes() && nn.is_power_of_two() {
        let log_nn = nn.trailing_zeros();
        if let Err(e) = g.ensure_twiddles(ntt) {
            eprintln!("[UPERF3-AJ] streamed commit declined ({e}); block upload");
        } else {
            let mut d_data = Pooled::take(&dev, len)?;
            match g.commit_chunked_upload(src, &mut d_data, rows, params.log_cols, log_nn, chunk_rows()) {
                Ok(leaves) => {
                    note_vram(&g);
                    return Ok((DevCommit { rows, log_n: params.log_cols, log_nn, data: d_data, enc: None, zk: None }, leaves));
                }
                Err(e) => eprintln!("[UPERF3-AJ] streamed commit declined ({e}); block upload"),
            }
        }
    }
    let mut d_data = Pooled::take(&dev, len)?;
    match src {
        UpSrc::Words(v) => g.upload_sync(d_data.get_mut(), v)?,
        UpSrc::Planes(p) => g.upload_planes(d_data.get_mut(), p)?,
    }
    drop(g);
    dev_commit_from(params, d_data, rows, ntt)
}

/// [UPERF3-AC] The cached-W form: upload `data` and build its encoding on
/// the device WITHOUT hashing (the Merkle tree comes from the cache); the
/// store then serves the opening exactly as a fresh commitment's would.
pub fn dev_encode_only(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Result<DevCommit, String> {
    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    g.ensure_twiddles(ntt)?;
    let n = params.cols();
    let nn = params.enc_cols();
    assert!(data.len() % n == 0 && !data.is_empty());
    let rows = data.len() / n;
    let log_n = params.log_cols;
    let log_nn = nn.trailing_zeros();
    assert_eq!(1usize << log_nn, nn, "inv_rate must be a power of two on the device path");
    let dev = g.dev.clone();
    let mut d_data = Pooled::take(&dev, data.len())?;
    g.upload_sync(d_data.get_mut(), as_u64s(data))?; // [UPERF3-AJ] pinned staging
    let t1 = Instant::now();
    if rows * nn * 8 > chunk_bytes() {
        // the chunked class: nothing to encode now — the opening re-encodes chunk by chunk
        return Ok(DevCommit { rows, log_n, log_nn, data: d_data, enc: None, zk: None });
    }
    let mut d_coef = Pooled::take(&dev, rows * n)?;
    let mut d_enc = match Pooled::take(&dev, rows * nn) {
        Ok(b) => b,
        Err(_) => return Ok(DevCommit { rows, log_n, log_nn, data: d_data, enc: None, zk: None }),
    };
    g.encode_rows(d_data.get(), d_coef.get_mut(), d_enc.get_mut(), rows, log_n, log_nn)?;
    dev.synchronize().map_err(|e| e.to_string())?;
    stats_with(|s| s.secs_ntt += t1.elapsed().as_secs_f64());
    note_vram(&g);
    drop(d_coef);
    Ok(DevCommit { rows, log_n, log_nn, data: d_data, enc: Some(d_enc), zk: None })
}

// ---------------------------------------------------------------------------
// [UPERF3-AC] THE CHUNKED COMMIT. A commitment whose encoding (rows x nn x
// 8 B) exceeds `HL_GPU_CHUNK_BYTES` (default 1 GiB; the 12x512 commitments
// are 151-272 MB and stay on the resident path above, byte for byte) — or
// whose resident buffer cannot be allocated — is encoded in ROW CHUNKS of
// `HL_GPU_CHUNK_ROWS` rows (default 1024; rounded down to a multiple of
// 128 so every chunk boundary is a blake3 chunk boundary of the column
// byte string): each chunk is RS-encoded into a reused scratch buffer and
// fed to `k_hash_cols_stream`, whose per-column CV stack persists in a
// device state buffer across chunks; the last chunk yields the leaves. The
// encoding is never resident; the OPENING re-encodes the same chunks and
// gathers the Q sampled columns (`dev_columns`). Values: the same row
// transforms (== the CPU encoder, row by row); the same column bytes in
// the same order (== blake3::hash of the column) — the proof bytes are
// the resident path's, which are the CPU path's.

fn chunk_bytes() -> usize {
    static V: OnceLock<usize> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_CHUNK_BYTES").ok().and_then(|v| v.parse().ok()).unwrap_or(1usize << 30))
}

/// [ZK60-CL1] The hiding commitment's chunking switch, and the REFERENCE
/// PATH RETAINER the acceptance criteria ask for.
///   unset / `auto` — chunk by size, and also whenever the resident buffers
///                    cannot be allocated (the non-ZK path's own rule)
///   `0` / `off`    — **STRICT**: never chunk, for any reason. The pre-CL1
///                    resident path byte-for-byte, and an allocation failure
///                    is REPORTED, not silently worked around. [ZK60-CL2]
///   `1` / `force`  — always chunk, so a small shape exercises the chunked
///                    code in the byte gates
#[derive(Clone, Copy, PartialEq, Debug)]
enum ZkChunk { Auto, Off, Force }

/// [ZK60-CL2] Runtime override (255 = follow the environment) so one test
/// process can exercise every mode. Production reads the env exactly as before.
static ZK_CHUNK_OVERRIDE: AtomicUsize = AtomicUsize::new(255);

/// 0 = off/strict, 1 = auto, 2 = force, 255 = follow `HL_ZK_CHUNK`.
/// Returns the previous value so a test can restore it.
pub fn set_zk_chunk_mode_for_test(mode: usize) -> usize {
    ZK_CHUNK_OVERRIDE.swap(mode, Ordering::SeqCst)
}

fn zk_chunk_mode() -> ZkChunk {
    static V: OnceLock<usize> = OnceLock::new();
    let env = *V.get_or_init(|| match std::env::var("HL_ZK_CHUNK").ok().as_deref() {
        Some("0") | Some("off") => 0,
        Some("1") | Some("force") => 2,
        _ => 1,
    });
    let v = match ZK_CHUNK_OVERRIDE.load(Ordering::SeqCst) { 255 => env, x => x };
    match v { 0 => ZkChunk::Off, 2 => ZkChunk::Force, _ => ZkChunk::Auto }
}
/// [UPERF3-AJ] `HL_GPU_FUSE_GATHER=0` restores the separate
/// `k_ntt_p2` + `k_gather_cols_off` pair (the pre-rung-2 shape, for the A/B).
fn fuse_gather() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("HL_GPU_FUSE_GATHER").map(|v| v != "0").unwrap_or(true))
}
fn chunk_rows() -> usize {
    static V: OnceLock<usize> = OnceLock::new();
    // [UPERF3-AJ] 1024 -> 128: a 1024-row chunk's encoded scratch is 537 MB at
    // the Mistral W shape, far past the 32 MB L2; a 128-row chunk is 67 MB (and
    // 128 rows is one blake3 chunk of a column, the smallest legal step).
    // Only chunked commitments are affected — nothing at the 125M shape.
    *V.get_or_init(|| std::env::var("HL_GPU_CHUNK_ROWS").ok().and_then(|v| v.parse().ok()).unwrap_or(128usize).max(128))
}

/// (row0, rc) per chunk: every chunk but the last a multiple of 128 rows.
fn chunk_plan(rows: usize, chunk: usize) -> Vec<(usize, usize)> {
    if rows <= chunk {
        return vec![(0, rows)];
    }
    let step = (chunk / 128).max(1) * 128;
    let mut out = Vec::new();
    let mut r0 = 0;
    while r0 < rows {
        let rc = step.min(rows - r0);
        out.push((r0, rc));
        r0 += rc;
    }
    out
}

const B3_STATE_SLOTS: usize = 8 * 24 + 1;

impl Gpu {
    /// `encode_rows` over a VIEW of the data (a row chunk); same kernels, same values.
    fn encode_rows_view(&self, data: &CudaView<u64>, coef: &mut CudaSlice<u64>, enc: &mut CudaSlice<u64>, rows: usize, log_n: u32, log_nn: u32) -> Result<(), String> {
        let (max_log, tf, ti) = self.tw.as_ref().ok_or("twiddles not uploaded")?;
        assert!(log_nn <= *max_log && log_n <= log_nn);
        assert!(coef.len() >= rows << log_n && enc.len() >= rows << log_nn);
        let scale: u64 = Fp::new(1u64 << log_n).inv().0;
        let threads = ntt_threads();
        if log_n > NTT_LOG_BLK {
            let pa = self.dev.get_func(MODULE, kn_dif_pa()).ok_or("k_dif_pa missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pa.launch(cfg, (data, &mut *coef, ti, log_n as i32)) }.map_err(|e| format!("k_dif_pa: {e}"))?;
            let pb = self.dev.get_func(MODULE, kn_dif_pb()).ok_or("k_dif_pb missing")?;
            let bpr = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            let cptr: sys::CUdeviceptr = *coef.device_ptr();
            unsafe { pb.launch(cfg, (cptr, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        } else {
            let pb = self.dev.get_func(MODULE, kn_dif_pb()).ok_or("k_dif_pb missing")?;
            let cfg = LaunchConfig { grid_dim: (rows as u32, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pb.launch(cfg, (data, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        }
        let rb = log_nn - log_n;
        let p1 = self.dev.get_func(MODULE, kn_dit_p1_pad()).ok_or("k_dit_p1_pad missing")?;
        let lb = log_nn.min(NTT_LOG_BLK);
        let bpr = 1u32 << (log_nn - lb);
        let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
        unsafe { p1.launch(cfg, (&*coef, &mut *enc, tf, log_nn as i32, (1usize << log_n) as i32, rb as i32)) }.map_err(|e| format!("k_dit_p1_pad: {e}"))?;
        if log_nn > NTT_LOG_BLK {
            let p2 = self.dev.get_func(MODULE, kn_ntt_p2()).ok_or("k_ntt_p2 missing")?;
            let tiles = 1u32 << (log_nn - NTT_LOG_BLK);
            let cfg2 = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { p2.launch(cfg2, (&mut *enc, tf, log_nn as i32, 1u64)) }.map_err(|e| format!("k_ntt_p2: {e}"))?;
        }
        Ok(())
    }

    /// [UPERF3-AJ] `encode_rows_view` for the OPENING: the last NTT stage
    /// group writes only the `sel`-marked columns straight into `out`, so
    /// the encoded chunk is never written back and never re-read (the
    /// `k_ntt_p2` store + the `k_gather_cols_off` load, 2/3 of the
    /// re-encode's traffic on the encoded matrix, are gone). Identical
    /// values: the same kernels, the same twiddles, the same order.
    ///
    /// [FSP-L9] `sp` is `(the padded residue list, its real length nq, its
    /// padded length nqp)`. With `HL_GPU_P1_COMPACT` on, the expand
    /// transform writes only those `nqp` residues per block into `enc` (a
    /// `rows x nt x nqp` block, 4 MB instead of 64 MB of stores per chunk
    /// at the 8B shape) and the pruned consumer reads them contiguously.
    /// `enc` is still the full-size scratch, so nothing about the
    /// allocation changes; what changes is how much of it is touched.
    #[allow(clippy::too_many_arguments)]
    fn encode_rows_view_gather(&self, data: &CudaView<u64>, coef: &mut CudaSlice<u64>, enc: &mut CudaSlice<u64>, rows: usize, log_n: u32, log_nn: u32,
                               d_sel: &CudaSlice<i32>, out: &mut CudaSlice<u64>, row0: usize, rows_total: usize,
                               sp: Option<(&CudaSlice<i32>, usize, usize)>) -> Result<(), String> {
        if log_nn <= NTT_LOG_BLK {
            return Err("gather fusion needs log_nn > NTT_LOG_BLK".into());
        }
        let (max_log, tf, ti) = self.tw.as_ref().ok_or("twiddles not uploaded")?;
        assert!(log_nn <= *max_log && log_n <= log_nn);
        assert!(coef.len() >= rows << log_n && enc.len() >= rows << log_nn);
        let scale: u64 = Fp::new(1u64 << log_n).inv().0;
        let threads = ntt_threads();
        if log_n > NTT_LOG_BLK {
            let pa = self.dev.get_func(MODULE, kn_dif_pa()).ok_or("k_dif_pa missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pa.launch(cfg, (data, &mut *coef, ti, log_n as i32)) }.map_err(|e| format!("k_dif_pa: {e}"))?;
            let pb = self.dev.get_func(MODULE, kn_dif_pb()).ok_or("k_dif_pb missing")?;
            let bpr = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            let cptr: sys::CUdeviceptr = *coef.device_ptr();
            unsafe { pb.launch(cfg, (cptr, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        } else {
            let pb = self.dev.get_func(MODULE, kn_dif_pb()).ok_or("k_dif_pb missing")?;
            let cfg = LaunchConfig { grid_dim: (rows as u32, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pb.launch(cfg, (data, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        }
        let rb = log_nn - log_n;
        let lb = log_nn.min(NTT_LOG_BLK);
        let bpr = 1u32 << (log_nn - lb);
        let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
        // [FSP-L9] the compact producer/consumer pair, when the caller
        // supplied the pruned residue list and the switch is on.
        let compact = sp.map(|(_, _, nqp)| nqp).filter(|_| p1_compact() && pad_skip());
        if let (Some(nqp), Some((ql, _, _))) = (compact, sp) {
            assert!(enc.len() >= rows * (1usize << (log_nn - NTT_LOG_BLK)) * nqp, "[FSP-L9] compact scratch too small");
            let p1 = self.dev.get_func(MODULE, kn_dit_p1_pad_c()).ok_or("k_dit_p1_pad_c missing")?;
            unsafe { p1.launch(cfg, (&*coef, &mut *enc, tf, log_nn as i32, (1usize << log_n) as i32, rb as i32, ql, nqp as i32)) }
                .map_err(|e| format!("k_dit_p1_pad_c: {e}"))?;
        } else {
            let p1 = self.dev.get_func(MODULE, kn_dit_p1_pad()).ok_or("k_dit_p1_pad missing")?;
            unsafe { p1.launch(cfg, (&*coef, &mut *enc, tf, log_nn as i32, (1usize << log_n) as i32, rb as i32)) }.map_err(|e| format!("k_dit_p1_pad: {e}"))?;
        }
        // [UPERF3-AO] rung 3: the pruned form when the caller supplied the
        // compact residue list; otherwise the dense fused kernel.
        if let Some((ql, nq, nqp)) = sp {
            let gx = ((nq + P2SP_NC - 1) / P2SP_NC) as u32;
            let cfg2 = LaunchConfig { grid_dim: (gx, rows as u32, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            if compact.is_some() {
                let p2 = self.dev.get_func(MODULE, "k_ntt_p2_gather_spc").ok_or("k_ntt_p2_gather_spc missing")?;
                unsafe { p2.launch(cfg2, (&*enc, tf, log_nn as i32, 1u64, d_sel, &mut *out, row0 as i32, rows_total as i32, ql, nq as i32, nqp as i32)) }
                    .map_err(|e| format!("k_ntt_p2_gather_spc: {e}"))?;
            } else {
                let p2 = self.dev.get_func(MODULE, "k_ntt_p2_gather_sp").ok_or("k_ntt_p2_gather_sp missing")?;
                unsafe { p2.launch(cfg2, (&*enc, tf, log_nn as i32, 1u64, d_sel, &mut *out, row0 as i32, rows_total as i32, ql, nq as i32)) }
                    .map_err(|e| format!("k_ntt_p2_gather_sp: {e}"))?;
            }
        } else {
            let p2 = self.dev.get_func(MODULE, kn_ntt_p2_gather()).ok_or("k_ntt_p2_gather missing")?;
            let tiles = 1u32 << (log_nn - NTT_LOG_BLK);
            let cfg2 = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { p2.launch(cfg2, (&*enc, tf, log_nn as i32, 1u64, d_sel, &mut *out, row0 as i32, rows_total as i32)) }
                .map_err(|e| format!("k_ntt_p2_gather: {e}"))?;
        }
        Ok(())
    }

    /// The chunked commit of a device-resident data buffer: leaves only.
    fn commit_chunked(&self, d_data: &Pooled, rows: usize, log_n: u32, log_nn: u32, chunk: usize) -> Result<Vec<Digest>, String> {
        let dev = self.dev.clone();
        let n = 1usize << log_n;
        let nn = 1usize << log_nn;
        let plan = chunk_plan(rows, chunk);
        let rmax = plan.iter().map(|&(_, rc)| rc).max().unwrap();
        let t0 = Instant::now();
        let mut d_coef = Pooled::take_min(&dev, rmax * n)?;
        let mut d_enc = Pooled::take_min(&dev, rmax * nn)?;
        // the per-column blake3 state (u32 slots, carried as a u64 pool buffer), zeroed
        let state_words = B3_STATE_SLOTS * nn;
        let mut d_state = Pooled::take_min(&dev, (state_words + 1) / 2)?;
        dev.memset_zeros(d_state.get_mut()).map_err(|e| format!("state memset: {e}"))?;
        let mut d_leaves = unsafe { dev.alloc::<u32>(nn * 8) }.map_err(|e| format!("leaves alloc: {e}"))?;
        note_raw_alloc(nn * 8 * 4);
        let f_hash = dev.get_func(MODULE, "k_hash_cols_stream").ok_or("k_hash_cols_stream missing")?;
        note_vram(self);
        let vb = verbose();
        let (mut t_ntt, mut t_hash) = (0.0f64, 0.0f64);
        for &(r0, rc) in &plan {
            let ta = Instant::now();
            let view = d_data.get().slice(r0 * n..(r0 + rc) * n);
            self.encode_rows_view(&view, d_coef.get_mut(), d_enc.get_mut(), rc, log_n, log_nn)?;
            if vb { dev.synchronize().map_err(|e| e.to_string())?; }
            let tb = Instant::now();
            let cfg = LaunchConfig::for_num_elems(nn as u32);
            unsafe { f_hash.clone().launch(cfg, (d_enc.get(), d_state.get_mut(), rc as i32, r0 as i32, rows as i32, nn as i32, &mut d_leaves)) }
                .map_err(|e| format!("k_hash_cols_stream: {e}"))?;
            if vb { dev.synchronize().map_err(|e| e.to_string())?; }
            t_ntt += (tb - ta).as_secs_f64();
            t_hash += tb.elapsed().as_secs_f64();
        }
        let words = dev.dtoh_sync_copy(&d_leaves).map_err(|e| format!("leaves download: {e}"))?;
        let mut leaves = vec![[0u8; 32]; nn];
        for (j, leaf) in leaves.iter_mut().enumerate() {
            for w in 0..8 {
                leaf[4 * w..4 * w + 4].copy_from_slice(&words[j * 8 + w].to_le_bytes());
            }
        }
        let total = t0.elapsed().as_secs_f64();
        if vb {
            eprintln!("[UPERF3-AC]   chunked commit rows {rows} 2^{log_n} -> 2^{log_nn} in {} chunks of <= {rmax}: ntt {t_ntt:.4} | hash {t_hash:.4} | total {total:.4} s", plan.len());
        }
        // when not verbose the ntt/hash split is not synchronized: charge the wall to ntt, the chunk count to the record
        stats_with(|s| { if vb { s.secs_ntt += t_ntt; s.secs_hash += total - t_ntt; } else { s.secs_ntt += total; } s.n_chunked += 1; s.bytes_d2h += (nn * 32) as u64; });
        Ok(leaves)
    }

    /// [UPERF3-AJ] The chunked commit with the UPLOAD INTERLEAVED: chunk
    /// k + 1's bytes ride the pinned copy stream while chunk k encodes and
    /// hashes on the default stream. Identical values: the same rows reach
    /// the same device addresses and the same kernels run on them, so the
    /// leaves — and the proof — are the block-upload path's.
    fn commit_chunked_upload(&mut self, host: UpSrc, d_data: &mut Pooled, rows: usize, log_n: u32, log_nn: u32, chunk: usize) -> Result<Vec<Digest>, String> {
        let dev = self.dev.clone();
        let n = 1usize << log_n;
        let nn = 1usize << log_nn;
        let plan = chunk_plan(rows, chunk);
        let rmax = plan.iter().map(|&(_, rc)| rc).max().unwrap();
        let t0 = Instant::now();
        let mut d_coef = Pooled::take_min(&dev, rmax * n)?;
        let mut d_enc = Pooled::take_min(&dev, rmax * nn)?;
        let state_words = B3_STATE_SLOTS * nn;
        let mut d_state = Pooled::take_min(&dev, (state_words + 1) / 2)?;
        dev.memset_zeros(d_state.get_mut()).map_err(|e| format!("state memset: {e}"))?;
        let mut d_leaves = unsafe { dev.alloc::<u32>(nn * 8) }.map_err(|e| format!("leaves alloc: {e}"))?;
        note_raw_alloc(nn * 8 * 4);
        let f_hash = dev.get_func(MODULE, "k_hash_cols_stream").ok_or("k_hash_cols_stream missing")?;
        note_vram(self);
        if self.up().is_none() {
            return Err("pinned staging unavailable".into());
        }
        // [UPERF3-AJ] the narrow class: the int8/int16/int32 witness planes
        // cross the bus as BYTES and `k_widen` restores the identical 64-bit
        // image on the device (8x less DMA for a weight tensor). The pinned
        // DMA on this box runs at ~5.5 GB/s whatever the staging (the
        // rung-1 probe), so the bytes on the wire are the lever.
        let w = host.width();
        let f_widen = self.dev.get_func(MODULE, "k_widen");
        let mut d_pack = if w < 8 && f_widen.is_some() {
            match Pooled::take_min(&dev, (host.len() * w + 7) / 8) {
                Ok(b) => Some(b),
                Err(_) => None,
            }
        } else {
            None
        };
        // [FSP-HOST] the plane source exists only in the narrow form: with no
        // `k_widen` or no packing scratch it DECLINES here, before anything is
        // staged, and the caller builds the `Vec<Fp>` and comes back.
        if host.is_planes() && d_pack.is_none() {
            return Err("plane source needs k_widen and the narrow packing scratch".into());
        }
        let w = if d_pack.is_some() { w } else { 8 };
        let pack_base: sys::CUdeviceptr = d_pack.as_ref().map(|b| *b.get().device_ptr()).unwrap_or(0);
        let data_base: sys::CUdeviceptr = *d_data.get().device_ptr();
        let mut up = self.up.take().unwrap();
        let secs0 = up.secs;
        let pack0 = up.pack_secs;
        let pel0 = up.pack_elems;
        let vb = verbose();
        let r = (|| -> Result<Vec<Digest>, String> {
            let (r0, rc) = plan[0];
            if w < 8 {
                up.send_src(pack_base, r0 * n, &host, r0 * n, rc * n, w)?;
            } else if let UpSrc::Words(hv) = host {
                up.send(d_data.get_mut(), r0 * n, &hv[r0 * n..(r0 + rc) * n])?;
            } else {
                return Err("plane source has no 64-bit upload form".into());
            }
            for (i, &(r0, rc)) in plan.iter().enumerate() {
                up.wait()?;
                if w < 8 {
                    let f = f_widen.clone().ok_or("k_widen missing")?;
                    let cfg = LaunchConfig::for_num_elems((rc * n) as u32);
                    let sp = pack_base + (r0 * n * w) as sys::CUdeviceptr;
                    let dp = data_base + (r0 * n * 8) as sys::CUdeviceptr;
                    unsafe { f.launch(cfg, (sp, dp, (rc * n) as i64, w as i32)) }.map_err(|e| format!("k_widen: {e}"))?;
                }
                {
                    let view = d_data.get().slice(r0 * n..(r0 + rc) * n);
                    self.encode_rows_view(&view, d_coef.get_mut(), d_enc.get_mut(), rc, log_n, log_nn)?;
                }
                let cfg = LaunchConfig::for_num_elems(nn as u32);
                unsafe { f_hash.clone().launch(cfg, (d_enc.get(), d_state.get_mut(), rc as i32, r0 as i32, rows as i32, nn as i32, &mut d_leaves)) }
                    .map_err(|e| format!("k_hash_cols_stream: {e}"))?;
                if i + 1 < plan.len() {
                    let (r1, rc1) = plan[i + 1];
                    if w < 8 {
                        up.send_src(pack_base, r1 * n, &host, r1 * n, rc1 * n, w)?;
                    } else if let UpSrc::Words(hv) = host {
                        up.send(d_data.get_mut(), r1 * n, &hv[r1 * n..(r1 + rc1) * n])?;
                    } else {
                        return Err("plane source has no 64-bit upload form".into());
                    }
                }
            }
            let words = dev.dtoh_sync_copy(&d_leaves).map_err(|e| format!("leaves download: {e}"))?;
            let mut leaves = vec![[0u8; 32]; nn];
            for (j, leaf) in leaves.iter_mut().enumerate() {
                for k in 0..8 {
                    leaf[4 * k..4 * k + 4].copy_from_slice(&words[j * 8 + k].to_le_bytes());
                }
            }
            Ok(leaves)
        })();
        if r.is_err() {
            // nothing may still be reading the packing scratch when it goes back to the pool
            let _ = up.wait();
            let _ = dev.synchronize();
        }
        let secs_up = up.secs - secs0;
        let pack_up = up.pack_secs - pack0;
        let pel = up.pack_elems - pel0;
        self.up = Some(up);
        let leaves = r?;
        drop(d_pack.take());
        let total = t0.elapsed().as_secs_f64();
        if vb {
            eprintln!("[UPERF3-AJ]   streamed commit rows {rows} 2^{log_n} -> 2^{log_nn} in {} chunks of <= {rmax} ({} B/elem on the wire): h2d visible {secs_up:.4} | total {total:.4} s", plan.len(), w);
        }
        // [FSP-HOST] what the `secs_h2d` counter is actually made of: the
        // host `pack_narrow` pass over the 64-bit staging vector, and the
        // rest (issue + the waits the engine really blocks on).
        if fsp4_timing() {
            eprintln!("[FSP4] streamed commit rows {rows} n 2^{log_n} w {w} ({}): h2d counter {secs_up:.4} = host pack {pack_up:.4} ({pel} elem, {:.2} GB read) + {:.4} rest | total {total:.4} s",
                if host.is_planes() { "int8 planes" } else { "64-bit words" },
                (pel * if host.is_planes() { 1 } else { 8 }) as f64 / 1e9, secs_up - pack_up);
        }
        stats_with(|s| {
            s.secs_h2d += secs_up;
            s.bytes_h2d += (host.len() * w) as u64;
            s.secs_ntt += total - secs_up;
            s.n_chunked += 1;
            s.bytes_d2h += (nn * 32) as u64;
        });
        Ok(leaves)
    }

    /// The opening's columns of a chunked commitment: re-encode chunk by chunk, gather.
    fn columns_chunked(&self, dc: &DevCommit, idx: &[usize], chunk: usize) -> Result<Vec<Vec<Fp>>, String> {
        let dev = self.dev.clone();
        let (rows, log_n, log_nn) = (dc.rows, dc.log_n, dc.log_nn);
        let n = 1usize << log_n;
        let nn = 1usize << log_nn;
        let q = idx.len();
        // [UPERF3-AJ] the fused form needs one output slot per DISTINCT index
        // (`challenge_indices` may repeat one; the duplicates are filled from
        // the first occurrence on the host, exactly as the gather kernel did).
        // [UPERF3-AO] rung 3: the distinct residues qq = col mod 2^NTT_LOG_BLK.
        // The last stage group is an independent nt-point transform per qq, so
        // only these can produce a sampled column; the list is padded to a
        // multiple of P2SP_NC by repeating its last entry (those lanes compute
        // and are never stored). Declined when it would not be materially
        // smaller than the dense axis, or when the tile would not fit.
        //
        // [ZK60-CL15] Both are the ONE pure plan in mod.rs, decided FIRST: an
        // empty query list opens zero columns and an out-of-range index is an
        // error, before any scratch, upload or output allocation. Same values.
        let p = match plan_open_indices(idx, nn, 1usize << NTT_LOG_BLK, P2SP_NC, fuse_gather(), prune_p2())? {
            OpenPlan::Empty => return Ok(Vec::new()),
            OpenPlan::Open(p) => p,
        };
        let fused = p.fused;
        let plan = chunk_plan(rows, chunk);
        let rmax = plan.iter().map(|&(_, rc)| rc).max().unwrap();
        let t0 = Instant::now();
        let mut d_coef = Pooled::take_min(&dev, rmax * n)?;
        let mut d_enc = Pooled::take_min(&dev, rmax * nn)?;
        let d_idx = dev.htod_sync_copy(p.device_index_list()).map_err(|e| e.to_string())?;
        note_raw_alloc(p.device_index_list().len() * 4);
        // [FSP-L9] the third element is the list's PADDED length, which is the
        // row stride of the compact intermediate.
        let sp_list: Option<(CudaSlice<i32>, usize, usize)> = match &p.residues {
            Some((qs, nq)) => {
                let b = dev.htod_sync_copy(qs).map_err(|e| e.to_string())?;
                note_raw_alloc(qs.len() * 4);
                Some((b, *nq, qs.len()))
            }
            None => None,
        };
        let cols_out = p.cols_out();
        let mut d_out = unsafe { dev.alloc::<u64>(rows * cols_out) }.map_err(|e| e.to_string())?;
        note_raw_alloc(rows * cols_out * 8);
        let f = dev.get_func(MODULE, "k_gather_cols_off").ok_or("k_gather_cols_off missing")?;
        for &(r0, rc) in &plan {
            let view = dc.data.get().slice(r0 * n..(r0 + rc) * n);
            if fused {
                let sp = sp_list.as_ref().map(|(b, k, kp)| (b, *k, *kp));
                self.encode_rows_view_gather(&view, d_coef.get_mut(), d_enc.get_mut(), rc, log_n, log_nn, &d_idx, &mut d_out, r0, rows, sp)?;
            } else {
                self.encode_rows_view(&view, d_coef.get_mut(), d_enc.get_mut(), rc, log_n, log_nn)?;
                let cfg = LaunchConfig::for_num_elems((rc * q) as u32);
                unsafe { f.clone().launch(cfg, (d_enc.get(), &mut d_out, &d_idx, rc as i32, r0 as i32, rows as i32, nn as i32, q as i32)) }
                    .map_err(|e| format!("k_gather_cols_off: {e}"))?;
            }
        }
        let out = dev.dtoh_sync_copy(&d_out).map_err(|e| e.to_string())?;
        let dt = t0.elapsed().as_secs_f64();
        if verbose() {
            eprintln!("[UPERF3-AC]   chunked re-encode + gather rows {rows} ({} chunks{}): {dt:.4} s", plan.len(), if fused { ", fused" } else { "" });
        }
        stats_with(|s| { s.secs_reenc += dt; s.bytes_d2h += (rows * cols_out * 8) as u64; });
        // [FSP-L9] lane AO's item 2, the host tail: this was a SERIAL loop
        // copying `q * rows` field elements (2.75 M at the 8B W shape, 22 MB)
        // into `q` vectors one element at a time. The `q` destinations are
        // disjoint and each is a straight copy of a contiguous run, so the
        // split is embarrassingly parallel and the values are unchanged --
        // `Fp` is `#[repr(transparent)]` over `u64`, so each column is a
        // memcpy of `out[s0 .. s0 + rows]`. Duplicated indices still take
        // their slot from `out_slot`, exactly as before.
        use rayon::prelude::*;
        let mut cols: Vec<Vec<Fp>> = (0..q).map(|_| Vec::new()).collect();
        cols.par_iter_mut().enumerate().for_each(|(c, dst)| {
            let s0 = p.out_slot(c) * rows;
            let src: &[u64] = &out[s0..s0 + rows];
            // SAFETY: Fp is #[repr(transparent)] over u64 (zkp-core field.rs),
            // so the two slices have identical layout; this is the same
            // element-for-element copy the map above performed.
            let src: &[Fp] = unsafe { std::slice::from_raw_parts(src.as_ptr() as *const Fp, rows) };
            dst.extend_from_slice(src);
        });
        Ok(cols)
    }
}

/// Rung 2's chunked check: the chunked commit's leaves == `hash_columns` of
/// the CPU encoding, and its re-encoded opening columns == the CPU
/// encoding at 16 indices, for `rows` rows in chunks of `chunk` rows.
/// Returns (bad leaves, bad column entries).
pub fn dev_commit_check_chunked(log_cols: u32, inv_rate: usize, rows: usize, chunk: usize) -> Result<(usize, usize), String> {
    let nn = PcsParams { log_cols, inv_rate, num_col_checks: 16 }.enc_cols();
    let idx: Vec<usize> = (0..16).map(|i| (i * 7919 + 13) % nn).collect();
    let p = dev_commit_open_probe(log_cols, inv_rate, rows, chunk, &idx)?;
    let (_, bad_cols) = p.open?;
    Ok((p.bad_leaves, bad_cols))
}

/// [ZK60-CL15] What an opening did, on its own. The oracle helpers commit
/// first, and the commit allocates, so a "the empty open allocated nothing"
/// claim needs the counters read around the OPEN alone: `alloc` is the
/// movement of every pool/raw counter across the open call and nothing else.
/// `open` is the opening's own outcome — `Ok((columns returned, bad column
/// entries against the CPU))` or the error it returned — kept as a value so
/// a test can assert that an out-of-range list is an `Err` AND allocated
/// nothing, from one call.
#[derive(Debug, Clone)]
pub struct OpenProbe {
    /// mismatching leaves of the chunked commitment (always computed)
    pub bad_leaves: usize,
    /// the OPEN's outcome
    pub open: Result<(usize, usize), String>,
    /// the allocation counters' movement across the OPEN alone
    pub alloc: PoolStats,
}

/// Open `dc` with `idx` through `open`, comparing every returned column against
/// `cpu` (row-major, `nn` wide), with the counters snapshotted around the call.
fn open_probe_run<F>(open: F, idx: &[usize], cpu: &[Fp], rows: usize, nn: usize) -> (Result<(usize, usize), String>, PoolStats)
where
    F: FnOnce() -> Result<Vec<Vec<Fp>>, String>,
{
    let before = pool_stats_for_test();
    let r = open();
    let alloc = pool_stats_for_test().delta_since(&before);
    let open = r.map(|cols| {
        let mut bad_cols = 0;
        for (c, &j) in idx.iter().enumerate() {
            for i in 0..rows {
                if cols[c][i] != cpu[i * nn + j] {
                    bad_cols += 1;
                }
            }
        }
        (cols.len(), bad_cols)
    });
    (open, alloc)
}

/// [ZK60-CL15] The NON-hiding chunked oracle with the opened indices supplied
/// by the caller (the body `dev_commit_check_chunked` always had, with the
/// index list a parameter): commit with `commit_chunked`, open with
/// `columns_chunked`, compare to the CPU encoding. The index list is NOT
/// pre-checked here — the point is to exercise the opening's own boundary
/// (empty, duplicate, out-of-range) and report what it allocated.
pub fn dev_commit_open_probe(log_cols: u32, inv_rate: usize, rows: usize, chunk: usize, idx: &[usize]) -> Result<OpenProbe, String> {
    let params = PcsParams { log_cols, inv_rate, num_col_checks: 16 };
    let ntt = NttTables::new(log_cols + inv_rate.trailing_zeros());
    let n = params.cols();
    let nn = params.enc_cols();
    let mut s = 0x5EED_0000u64 ^ (log_cols as u64) << 40 ^ (rows as u64) << 8 ^ chunk as u64;
    let data: Vec<Fp> = (0..rows * n)
        .map(|_| {
            s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            Fp::new(s % P)
        })
        .collect();
    let mut cpu = vec![Fp::ZERO; rows * nn];
    cpu.par_chunks_mut(nn).zip(data.par_chunks(n)).for_each(|(erow, drow)| {
        let mut coeffs = drow.to_vec();
        ntt.inverse(&mut coeffs);
        ntt.rs_encode(&coeffs, erow);
    });
    let cpu_leaves = crate::pcs::hash_columns(&cpu, rows, nn);
    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    g.ensure_twiddles(&ntt)?;
    let dev = g.dev.clone();
    let mut d_data = Pooled::take(&dev, data.len())?;
    dev.htod_sync_copy_into(as_u64s(&data), d_data.get_mut()).map_err(|e| format!("data upload: {e}"))?;
    let leaves = g.commit_chunked(&d_data, rows, params.log_cols, nn.trailing_zeros(), chunk)?;
    let bad_leaves = leaves.iter().zip(cpu_leaves.iter()).filter(|(a, b)| a != b).count();
    let dc = DevCommit { rows, log_n: params.log_cols, log_nn: nn.trailing_zeros(), data: d_data, enc: None, zk: None };
    let (open, alloc) = open_probe_run(|| g.columns_chunked(&dc, idx, chunk), idx, &cpu, rows, nn);
    Ok(OpenProbe { bad_leaves, open, alloc })
}

/// [ZK60-CL1] The chunked HIDING commitment's oracle. Checks BOTH halves that
/// the byte gates can only check together: the chunked leaves, and the
/// chunked pad/coset-aware opening columns, each against the CPU's own
/// `encode_row_zk` — not against the device's resident path, so a shared bug
/// could not hide. Returns (bad leaves, bad column entries); (0, 0) is a pass.
/// `plain_reencode` opens the SAME hiding commitment with the non-ZK
/// `columns_chunked` instead. That is the wrong function for a hiding
/// commitment — it drops the pads and the coset scaling — so a correct build
/// must report a LARGE `bad_cols` for it. It is the negative control that
/// proves this oracle discriminates at all, and it is the direct evidence for
/// rung 1's claim that `columns_chunked_zk` was mandatory rather than tidy.
pub fn dev_commit_zk_check_chunked(log_cols: u32, inv_rate: usize, rows: usize, q_pad: usize, chunk: usize, plain_reencode: bool) -> Result<(usize, usize), String> {
    dev_commit_zk_check_chunked_with(log_cols, inv_rate, rows, q_pad, chunk, plain_reencode, None)
}

/// [ZK60-CL7] The same oracle with the OPENED INDICES supplied by the caller
/// (`None` = the fixed 16 the tests have always used), so the fused opening's
/// distinct-slot expansion can be checked against REPEATED indices, which
/// `Transcript::challenge_indices` can produce. Out-of-range indices are an
/// error, not a panic.
pub fn dev_commit_zk_check_chunked_with(log_cols: u32, inv_rate: usize, rows: usize, q_pad: usize, chunk: usize, plain_reencode: bool, idx: Option<&[usize]>) -> Result<(usize, usize), String> {
    let nn = PcsParams { log_cols, inv_rate, num_col_checks: 16 }.enc_cols();
    let idx: Vec<usize> = match idx {
        Some(v) => {
            if let Some(&bad) = v.iter().find(|&&j| j >= nn) {
                return Err(format!("opened index {bad} is out of range for {nn} encoded columns"));
            }
            v.to_vec()
        }
        None => (0..16).map(|i| (i * 7919 + 13) % nn).collect(),
    };
    let p = dev_commit_zk_open_probe(log_cols, inv_rate, rows, q_pad, chunk, plain_reencode, &idx)?;
    let (_, bad_cols) = p.open?;
    Ok((p.bad_leaves, bad_cols))
}

/// [ZK60-CL15] The hiding oracle's body with the opening's own outcome and
/// allocation movement reported (`OpenProbe`), and the index list passed to
/// the opening UNCHECKED so its boundary is what gets exercised. `Err` from
/// this function is a failure of the fixture or the COMMIT; the open's error,
/// if any, is inside `open`.
pub fn dev_commit_zk_open_probe(log_cols: u32, inv_rate: usize, rows: usize, q_pad: usize, chunk: usize, plain_reencode: bool, idx: &[usize]) -> Result<OpenProbe, String> {
    let params = PcsParams { log_cols, inv_rate, num_col_checks: 16 };
    let ntt = NttTables::new(log_cols + inv_rate.trailing_zeros());
    let n = params.cols();
    let nn = params.enc_cols();
    let coset = Fp::new(7);
    let mut s = 0x21C0_FFEEu64 ^ ((log_cols as u64) << 40) ^ ((rows as u64) << 8) ^ chunk as u64 ^ ((q_pad as u64) << 24);
    let mut next = move || {
        s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        Fp::new(s % P)
    };
    let data: Vec<Fp> = (0..rows * n).map(|_| next()).collect();
    let pads: Vec<Fp> = (0..rows * q_pad).map(|_| next()).collect();
    let pows = crate::pcs::coset_powers(coset, nn);

    // CPU reference: the hiding encode, row by row, through the same function
    // the CPU prover uses.
    let mut cpu = vec![Fp::ZERO; rows * nn];
    for (i, erow) in cpu.chunks_mut(nn).enumerate() {
        crate::pcs::encode_row_zk(&ntt, &data[i * n..(i + 1) * n], &pads[i * q_pad..(i + 1) * q_pad], &pows, erow);
    }
    let cpu_leaves = crate::pcs::hash_columns(&cpu, rows, nn);

    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    g.ensure_twiddles(&ntt)?;
    let dev = g.dev.clone();
    let mut d_data = Pooled::take(&dev, data.len())?;
    dev.htod_sync_copy_into(as_u64s(&data), d_data.get_mut()).map_err(|e| format!("data upload: {e}"))?;
    let d_pads = dev.htod_sync_copy(as_u64s(&pads)).map_err(|e| format!("pads upload: {e}"))?;
    note_raw_alloc(pads.len() * 8);
    let d_pows = dev.htod_sync_copy(as_u64s(&pows)).map_err(|e| format!("pows upload: {e}"))?;
    note_raw_alloc(pows.len() * 8);
    let log_nn = nn.trailing_zeros();

    let leaves = g.commit_zk_chunked(&d_data, &d_pads, &d_pows, rows, n, q_pad, nn, log_cols, log_nn, chunk)?;
    let bad_leaves = leaves.iter().zip(cpu_leaves.iter()).filter(|(a, b)| a != b).count();

    let dc = DevCommit {
        rows, log_n: log_cols, log_nn, data: d_data, enc: None,
        zk: Some(ZkReenc { pads: d_pads, pows: d_pows, q: q_pad }),
    };
    let (open, alloc) = open_probe_run(
        || if plain_reencode {
            g.columns_chunked(&dc, idx, chunk)
        } else {
            g.columns_chunked_zk(&dc, dc.zk.as_ref().unwrap(), idx, chunk)
        },
        idx, &cpu, rows, nn,
    );
    Ok(OpenProbe { bad_leaves, open, alloc })
}

/// [ZK60-CL2] The INTERLEAVING oracle. Commits several hiding commitments
/// and keeps them all live, THEN opens each one `opens` times, comparing
/// leaves and columns against each commitment's own CPU reference.
///
/// This is the shape the CL1 review asked for, and it is the shape that
/// catches the twiddle hazard: give it specs with DECREASING `log_cols` and
/// the second commitment's `ensure_twiddles` used to shrink the tables out
/// from under the first commitment's deferred opening. A resident commitment
/// never cared — it opened by gathering a retained `enc`. A chunked one
/// re-encodes, so it depends on tables installed a commitment ago.
///
/// specs: `(log_cols, inv_rate, rows, q_pad)`. Returns (bad leaves, bad cols).
pub fn dev_commit_zk_check_interleaved(specs: &[(u32, usize, usize, usize)], chunk: usize, opens: usize) -> Result<(usize, usize), String> {
    struct Live { dc: DevCommit, cpu: Vec<Fp>, nn: usize, rows: usize }
    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    let dev = g.dev.clone();
    let mut live: Vec<Live> = Vec::with_capacity(specs.len());
    let mut bad_leaves = 0usize;

    for (si, &(log_cols, inv_rate, rows, q_pad)) in specs.iter().enumerate() {
        let params = PcsParams { log_cols, inv_rate, num_col_checks: 16 };
        let ntt = NttTables::new(log_cols + inv_rate.trailing_zeros());
        let n = params.cols();
        let nn = params.enc_cols();
        let coset = Fp::new(7);
        let mut s = 0xC12_0000u64 ^ ((si as u64) << 48) ^ ((log_cols as u64) << 40) ^ ((rows as u64) << 8) ^ q_pad as u64;
        let mut next = move || { s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407); Fp::new(s % P) };
        let data: Vec<Fp> = (0..rows * n).map(|_| next()).collect();
        let pads: Vec<Fp> = (0..rows * q_pad).map(|_| next()).collect();
        let pows = crate::pcs::coset_powers(coset, nn);
        let mut cpu = vec![Fp::ZERO; rows * nn];
        for (i, erow) in cpu.chunks_mut(nn).enumerate() {
            crate::pcs::encode_row_zk(&ntt, &data[i * n..(i + 1) * n], &pads[i * q_pad..(i + 1) * q_pad], &pows, erow);
        }
        let cpu_leaves = crate::pcs::hash_columns(&cpu, rows, nn);

        // each spec installs its own tables — the shrink point
        g.ensure_twiddles(&ntt)?;
        let mut d_data = Pooled::take(&dev, data.len())?;
        dev.htod_sync_copy_into(as_u64s(&data), d_data.get_mut()).map_err(|e| format!("data upload: {e}"))?;
        let d_pads = dev.htod_sync_copy(as_u64s(&pads)).map_err(|e| format!("pads upload: {e}"))?;
        note_raw_alloc(pads.len() * 8);
        let d_pows = dev.htod_sync_copy(as_u64s(&pows)).map_err(|e| format!("pows upload: {e}"))?;
        note_raw_alloc(pows.len() * 8);
        let log_nn = nn.trailing_zeros();
        let leaves = g.commit_zk_chunked(&d_data, &d_pads, &d_pows, rows, n, q_pad, nn, log_cols, log_nn, chunk)?;
        bad_leaves += leaves.iter().zip(cpu_leaves.iter()).filter(|(a, b)| a != b).count();
        let dc = DevCommit { rows, log_n: log_cols, log_nn, data: d_data, enc: None,
                             zk: Some(ZkReenc { pads: d_pads, pows: d_pows, q: q_pad }) };
        live.push(Live { dc, cpu, nn, rows });
    }

    // Everything committed; only NOW open. Repeated opens must be stable.
    let mut bad_cols = 0usize;
    for _ in 0..opens.max(1) {
        for l in &live {
            let idx: Vec<usize> = (0..16).map(|i| (i * 7919 + 13) % l.nn).collect();
            let cols = g.columns_chunked_zk(&l.dc, l.dc.zk.as_ref().unwrap(), &idx, chunk)?;
            for (c, &j) in idx.iter().enumerate() {
                for i in 0..l.rows {
                    if cols[c][i] != l.cpu[i * l.nn + j] {
                        bad_cols += 1;
                    }
                }
            }
        }
    }
    Ok((bad_leaves, bad_cols))
}

/// [ZK60-CL2] Drive the REAL entry point, `dev_commit_zk_from`, and report
/// which strategy it chose: `Ok(true)` = chunked (`enc` deferred), `Ok(false)`
/// = resident. The other oracles call `commit_zk_chunked` directly, which is
/// right for checking values but means they never touch the mode/fallback
/// decision — so a "strict mode" assertion built on them would be vacuous.
/// This one exercises the branch the CL1 review actually flagged.
pub fn dev_commit_zk_from_probe(log_cols: u32, inv_rate: usize, rows: usize, q_pad: usize) -> Result<ProbeOutcome, String> {
    let params = PcsParams { log_cols, inv_rate, num_col_checks: 16 };
    let ntt = NttTables::new(log_cols + inv_rate.trailing_zeros());
    let n = params.cols();
    let nn = params.enc_cols();
    let mut s = 0xF00D_5EEDu64 ^ ((log_cols as u64) << 40) ^ ((rows as u64) << 8) ^ q_pad as u64;
    let mut next = move || { s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407); Fp::new(s % P) };
    let data: Vec<Fp> = (0..rows * n).map(|_| next()).collect();
    let pads: Vec<Fp> = (0..rows * q_pad).map(|_| next()).collect();
    let pows = crate::pcs::coset_powers(Fp::new(7), nn);
    let d_data = {
        let g = gpu().ok_or_else(init_err)?;
        let mut g = g.lock().unwrap();
        g.ensure_twiddles(&ntt)?;
        let dev = g.dev.clone();
        let mut d = Pooled::take(&dev, data.len())?;
        dev.htod_sync_copy_into(as_u64s(&data), d.get_mut()).map_err(|e| format!("data upload: {e}"))?;
        d
    };
    // [ZK60-CL4 review] The first version returned only `dc.enc.is_none()` and
    // DISCARDED the leaves, so it proved which path was taken and nothing about
    // whether that path was correct. An injected-failure test built on it could
    // not have caught a fallback that routed correctly and computed garbage.
    // Now the leaves AND the opened columns from the ACTUAL path are checked
    // against the CPU encoding.
    let cpu = {
        let mut e = vec![Fp::ZERO; rows * nn];
        for (i, erow) in e.chunks_mut(nn).enumerate() {
            crate::pcs::encode_row_zk(&ntt, &data[i * n..(i + 1) * n], &pads[i * q_pad..(i + 1) * q_pad], &pows, erow);
        }
        e
    };
    let cpu_leaves = crate::pcs::hash_columns(&cpu, rows, nn);
    let (dc, leaves) = dev_commit_zk_from(&params, d_data, rows, &pads, &pows, &ntt)?;
    let bad_leaves = leaves.iter().zip(cpu_leaves.iter()).filter(|(a, b)| a != b).count();
    let idx: Vec<usize> = (0..16).map(|i| (i * 7919 + 13) % nn).collect();
    let cols = dev_columns(&dc, &idx)?;
    let mut bad_cols = 0usize;
    for (c, &j) in idx.iter().enumerate() {
        for i in 0..rows {
            if cols[c][i] != cpu[i * nn + j] { bad_cols += 1; }
        }
    }
    Ok(ProbeOutcome { chunked: dc.enc.is_none(), bad_leaves, bad_cols })
}

/// [ZK60-CL4 review] What path was taken AND whether it was right.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ProbeOutcome {
    pub chunked: bool,
    pub bad_leaves: usize,
    pub bad_cols: usize,
}

/// Commit a device-resident data buffer (rows x n u64, row-major) — the
/// encode + hash half of `dev_commit`, also used for the H data the helper
/// kernels write on the device.
pub fn dev_commit_from(params: &PcsParams, d_data: Pooled, rows: usize, ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    g.ensure_twiddles(ntt)?;
    let n = params.cols();
    let nn = params.enc_cols();
    assert_eq!(d_data.get().len(), rows * n);
    let log_n = params.log_cols;
    let log_nn = nn.trailing_zeros();
    assert_eq!(1usize << log_nn, nn, "inv_rate must be a power of two on the device path");
    let dev = g.dev.clone();
    let t1 = Instant::now();
    // [UPERF3-AC] the chunked class (by size, or when the resident buffers cannot be allocated)
    let chunked_now = rows * nn * 8 > chunk_bytes();
    let resident = if chunked_now { None } else {
        match (Pooled::take(&dev, rows * n), Pooled::take(&dev, rows * nn)) {
            (Ok(c), Ok(e)) => Some((c, e)),
            _ => None,
        }
    };
    let (mut d_coef, mut d_enc) = match resident {
        Some(x) => x,
        None => {
            if verbose() { eprintln!("[UPERF3-AC]   commit rows {rows} 2^{log_n} -> 2^{log_nn} ({:.0} MB): CHUNKED ({})", (rows * nn * 8) as f64 / 1e6, if chunked_now { "by size" } else { "resident alloc failed" }); }
            let leaves = g.commit_chunked(&d_data, rows, log_n, log_nn, chunk_rows())?;
            note_vram(&g);
            return Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: None, zk: None }, leaves));
        }
    };
    if gather_ntt() {
        // rung 1's form (HL_GPU_GATHER_NTT=1): DIT both ways with the bit-reversed gather on the load.
        g.ntt_rows(d_data.get(), d_coef.get_mut(), rows, n, log_n, true)?;
        g.ntt_rows(d_coef.get(), d_enc.get_mut(), rows, n, log_nn, false)?;
    } else {
        g.encode_rows(d_data.get(), d_coef.get_mut(), d_enc.get_mut(), rows, log_n, log_nn)?;
    }
    dev.synchronize().map_err(|e| e.to_string())?;
    let t2 = Instant::now();
    stats_with(|s| s.secs_ntt += (t2 - t1).as_secs_f64());
    note_vram(&g);
    drop(d_coef);
    let leaves = if host_hash() {
        // rung 1's form (HL_GPU_HOST_HASH=1): the encoded matrix back to the host, hashed by the CPU code.
        let enc_host = as_fps(dev.dtoh_sync_copy(d_enc.get()).map_err(|e| format!("enc download: {e}"))?);
        let t3 = Instant::now();
        stats_with(|s| { s.secs_d2h += (t3 - t2).as_secs_f64(); s.bytes_d2h += (rows * nn * 8) as u64; });
        let leaves = crate::pcs::hash_columns(&enc_host, rows, nn);
        stats_with(|s| s.secs_hash += t3.elapsed().as_secs_f64());
        leaves
    } else {
        // rung 2: blake3 per column on the device; only the leaves come back.
        let leaves = g.hash_cols(d_enc.get(), rows, nn)?;
        let t3 = Instant::now();
        stats_with(|s| { s.secs_hash += (t3 - t2).as_secs_f64(); s.bytes_d2h += (nn * 32) as u64; });
        leaves
    };
    Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: Some(d_enc), zk: None }, leaves))
}

/// `HL_GPU_GATHER_NTT=1`: rung 1's gather-based DIT NTT pair (for the A/B).
fn gather_ntt() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| env_flag("HL_GPU_GATHER_NTT"))
}

/// `HL_GPU_HOST_HASH=1`: keep the column hashing on the CPU (rung 1's form, for the A/B).
fn host_hash() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| env_flag("HL_GPU_HOST_HASH"))
}

impl Gpu {
    /// blake3 of every column of the encoded matrix (rows x nn) on the device.
    fn hash_cols(&self, enc: &CudaSlice<u64>, rows: usize, nn: usize) -> Result<Vec<Digest>, String> {
        let f = self.dev.get_func(MODULE, "k_hash_cols").ok_or("k_hash_cols missing")?;
        let mut d_leaves = unsafe { self.dev.alloc::<u32>(nn * 8) }.map_err(|e| format!("leaves alloc: {e}"))?;
        note_raw_alloc(nn * 8 * 4);
        let cfg = LaunchConfig::for_num_elems(nn as u32);
        unsafe { f.launch(cfg, (enc, &mut d_leaves, rows as i32, nn as i32)) }.map_err(|e| format!("k_hash_cols: {e}"))?;
        let words = self.dev.dtoh_sync_copy(&d_leaves).map_err(|e| format!("leaves download: {e}"))?;
        let mut leaves = vec![[0u8; 32]; nn];
        for (j, leaf) in leaves.iter_mut().enumerate() {
            for w in 0..8 {
                leaf[4 * w..4 * w + 4].copy_from_slice(&words[j * 8 + w].to_le_bytes());
            }
        }
        Ok(leaves)
    }
}

/// Rung 2's check: device column hashes == blake3::hash of the same
/// column bytes for `rows` rows over 64 columns of random values.
/// Returns the number of mismatching columns.
pub fn dev_hash_check(rows: usize) -> Result<usize, String> {
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let nn = 64usize;
    let mut s = 0xABCD_EF01u64 ^ (rows as u64) << 20;
    let enc: Vec<Fp> = (0..rows * nn)
        .map(|_| {
            s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            Fp::new(s % P)
        })
        .collect();
    let d_enc = g.dev.htod_sync_copy(as_u64s(&enc)).map_err(|e| e.to_string())?;
    let dev_leaves = g.hash_cols(&d_enc, rows, nn)?;
    let cpu_leaves = crate::pcs::hash_columns(&enc, rows, nn);
    Ok(dev_leaves.iter().zip(cpu_leaves.iter()).filter(|(a, b)| a != b).count())
}

/// The opened columns: for each index j, the column's `rows` entries of the encoded matrix.
pub fn dev_columns(dc: &DevCommit, idx: &[usize]) -> Result<Vec<Vec<Fp>>, String> {
    let q = idx.len();
    let rows = dc.rows;
    let nn = 1usize << dc.log_nn;
    // [ZK60-CL15] The public entry's boundary, decided before the device is
    // even locked, for all three arms: an EMPTY query list opens zero columns
    // (nothing to gather, nothing to allocate — a zero-length upload would in
    // fact be a driver error), and an out-of-range index is an error rather
    // than an out-of-bounds device read. `challenge_indices` never produces
    // either, so no caller's proof bytes move.
    if q == 0 {
        return Ok(Vec::new());
    }
    if let Some(&bad) = idx.iter().find(|&&j| j >= nn) {
        return Err(format!("opened index {bad} is out of range for {nn} encoded columns"));
    }
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    // [UPERF3-AC] a chunked commitment: re-encode chunk by chunk and gather
    let enc = match (&dc.enc, &dc.zk) {
        (Some(e), _) => e,
        // [ZK60-CL1] a chunked HIDING commitment re-encodes THROUGH the
        // pad/coset step. `columns_chunked` drops both and would return the
        // wrong columns — this arm is the reason `zk` is carried at all.
        (None, Some(zk)) => return g.columns_chunked_zk(dc, zk, idx, chunk_rows()),
        (None, None) => return g.columns_chunked(dc, idx, chunk_rows()),
    };
    let idx32: Vec<i32> = idx.iter().map(|&j| j as i32).collect();
    let d_idx = dev.htod_sync_copy(&idx32).map_err(|e| e.to_string())?;
    note_raw_alloc(idx32.len() * 4);
    let mut d_out = unsafe { dev.alloc::<u64>(rows * q) }.map_err(|e| e.to_string())?;
    note_raw_alloc(rows * q * 8);
    let f = dev.get_func(MODULE, "k_gather_cols").ok_or("k_gather_cols missing")?;
    let cfg = LaunchConfig::for_num_elems((rows * q) as u32);
    unsafe { f.launch(cfg, (enc.get(), &mut d_out, &d_idx, rows as i32, nn as i32, q as i32)) }.map_err(|e| format!("k_gather_cols: {e}"))?;
    let out = dev.dtoh_sync_copy(&d_out).map_err(|e| e.to_string())?;
    stats_with(|s| s.bytes_d2h += (rows * q * 8) as u64);
    Ok((0..q).map(|c| out[c * rows..(c + 1) * rows].iter().map(|&v| Fp(v)).collect()).collect())
}

/// Rung 1's check: the device encoding of random rows == the CPU encoding,
/// element for element, at (log_cols, inv_rate) shapes, and the gathered
/// columns == the host columns. Returns the number of mismatching elements.
pub fn dev_commit_check(log_cols: u32, inv_rate: usize, rows: usize) -> Result<(usize, f64, f64), String> {
    let params = PcsParams { log_cols, inv_rate, num_col_checks: 16 };
    let ntt = NttTables::new(log_cols + inv_rate.trailing_zeros());
    let n = params.cols();
    let nn = params.enc_cols();
    let mut s = 0x1234_5678u64 ^ (log_cols as u64) << 40 ^ rows as u64;
    let data: Vec<Fp> = (0..rows * n)
        .map(|_| {
            s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            Fp::new(s % P)
        })
        .collect();
    let t0 = Instant::now();
    let mut cpu = vec![Fp::ZERO; rows * nn];
    cpu.par_chunks_mut(nn).zip(data.par_chunks(n)).for_each(|(erow, drow)| {
        let mut coeffs = drow.to_vec();
        ntt.inverse(&mut coeffs);
        ntt.rs_encode(&coeffs, erow);
    });
    let t_cpu = t0.elapsed().as_secs_f64();
    let t1 = Instant::now();
    let (dc, _leaves) = dev_commit(&params, &data, &ntt)?;
    let t_gpu = t1.elapsed().as_secs_f64();
    let g = gpu().ok_or_else(init_err)?;
    let enc = {
        let g = g.lock().unwrap();
        as_fps(g.dev.dtoh_sync_copy(dc.enc.as_ref().ok_or("dev_commit_check: the probe shapes are resident")?.get()).map_err(|e| e.to_string())?)
    };
    let mut bad = enc.iter().zip(cpu.iter()).filter(|(a, b)| a != b).count();
    let idx: Vec<usize> = (0..16).map(|i| (i * 7919 + 13) % nn).collect();
    let cols = dev_columns(&dc, &idx)?;
    for (c, &j) in idx.iter().enumerate() {
        for i in 0..rows {
            if cols[c][i] != cpu[i * nn + j] {
                bad += 1;
            }
        }
    }
    Ok((bad, t_cpu, t_gpu))
}

// ---------------------------------------------------------------------------
// [rung 3] The zero-check sumchecks on the device. The tables are BUILT on
// the device from the resident commitment data (no upload): a base-field
// slice of a DevCommit's data, a (re, im) slice pair, or the eq table of a
// challenge point. The round loop stays on the host (the transcript):
// round kernel -> block partials -> one-block reduce -> 5 Fp2 back ->
// absorb -> challenge -> fold kernel.

/// One table of a device sumcheck.
pub enum TabSpec<'a> {
    /// (commitment, element offset, length): dst[i] = (data[off + i], 0)
    FromFp(&'a DevCommit, usize, usize),
    /// (commitment, re offset, im offset, length)
    FromFp2(&'a DevCommit, usize, usize, usize),
    /// eq(point, .) over 2^len(point) entries, MSB convention
    Eq(&'a [Fp2]),
}

fn as_u64s_f2(v: &[Fp2]) -> Vec<u64> {
    let mut out = Vec::with_capacity(v.len() * 2);
    for x in v {
        out.push(x.c0.0);
        out.push(x.c1.0);
    }
    out
}

/// Prove sum_x poly(tables(x)) == claim for the zc20 (kind 0) / zc17 (kind
/// 1) polynomial with parameters `prm` (the layout kernels.cu states),
/// exactly as sumcheck::prove would on the same tables. `Err` -> the
/// caller runs the CPU body (with the tables it builds itself).
pub fn dev_zerocheck(kind: i32, specs: &[TabSpec], prm: &[u64], tr: &mut Transcript) -> Result<ProverOutput, String> {
    zerocheck_impl(kind, None, specs, prm, tr)
}

/// [UPERF3-AH] The SHAPE-GENERAL form: the same sumcheck over `nb` blocks
/// (nb_f on the F side, nb_d on the D side) through the block-looping
/// round kernels, with the block-indexed parameter layout kernels.cu
/// states. `dev_zerocheck` above stays the templated 13 / 15-table path
/// (the 125M block shape) and is what the v2 prover and zk.rs still call.
pub fn dev_zerocheck_blocks(kind: i32, nb: usize, specs: &[TabSpec], prm: &[u64], tr: &mut Transcript) -> Result<ProverOutput, String> {
    zerocheck_impl(kind, Some(nb), specs, prm, tr)
}

/// [UPERF3-AH] Reserve device buffers of exactly these lengths through the
/// pool (which matches by exact length, so the reservation IS the later
/// allocation) and return them to it. `Err` iff the device cannot hold
/// them now — the caller then takes the host path BEFORE it commits to any
/// device work whose fallback no longer exists.
pub fn dev_reserve(lens: &[usize]) -> Result<(), String> {
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let mut held: Vec<Pooled> = Vec::with_capacity(lens.len());
    for &len in lens {
        held.push(Pooled::take(&dev, len)?);
    }
    note_vram(&g);
    Ok(())
}

/// [UPERF3-AI] (free, total) device memory in BYTES, plus how many buffers
/// the pool is holding — for the ZK prover's VRAM accounting at 8B width.
pub fn dev_mem_info() -> Option<(usize, usize, usize)> {
    let held = POOL.lock().unwrap().len();
    cu::mem_get_info().ok().map(|(free, total)| (free, total, held))
}

/// [UPERF3-AI] Free every buffer the pool is holding and report how many.
///
/// The pool matches by EXACT length, so buffers from a layer whose row
/// counts differ by even one row are dead weight that no later allocation
/// can reuse. The ZK prover's per-layer row counts DO differ (each layer's
/// signed shifts give different remainder-window sizes, hence different
/// table rows in A and H — measured: Mistral layer 0 commits H with 3033
/// rows, layer 1 with 3028), and at 8B width one layer's commitments
/// already fill an 8 GB part, so carrying the previous layer's pooled
/// buffers into the next one is what makes layer 1 fail. Draining is
/// value-neutral: a pooled buffer holds nothing live (every element a
/// kernel reads is written first); the only cost is the first-touch price
/// of the next allocation of each size.
pub fn dev_pool_drain() -> usize {
    let n = {
        let mut pool = POOL.lock().unwrap();
        let n = pool.len();
        pool.clear();
        n
    };
    // THE DRIVER FREES ASYNCHRONOUSLY on this box, and that is the whole trick: measured with
    // `dev_mem_info` at Mistral width, dropping 2.5 GB of pooled buffers left `cuMemGetInfo`
    // reporting the SAME 494 MiB free, and the memory only appeared several allocations later.
    // Without this synchronize the next big allocation (the H commit's rows x nn buffers) sees
    // a full card and either fails outright or is served by WSL's host-memory paging, which is
    // what made layer 1 of the 32-layer pass 2.7x slower than layer 0 (and, in another run,
    // panic). Syncing is value-neutral: it only waits for work already enqueued.
    if n > 0 {
        if let Some(g) = gpu() {
            let g = g.lock().unwrap();
            let _ = g.dev.synchronize();
        }
    }
    n
}

/// [UPERF3-AI] `dev_reserve` that, when the device cannot serve the request,
/// DRAINS the buffer pool and tries once more.
///
/// Why it is needed: the pool retains up to 64 freed buffers and matches by
/// EXACT length (that reuse is what makes the chunked commit fast across 32
/// layers), so after a wide layer's commitments the pool can be holding a
/// gigabyte or more of chunk scratch that no live object needs. At the
/// 125M block shape that never mattered; at Mistral width the zero-check F
/// table buffer is (3 + 10 x 7) x 2^20 x 2 u64 = 1,168 MB and it is exactly
/// what fails — measured on the RTX 4070 Laptop (8,188 MB), where the live
/// commitments at that moment are ~1.9 GB. Draining is value-neutral: a
/// pooled buffer holds no live data (every element a kernel reads is
/// written first), so the only cost of freeing it is the first-touch price
/// of the next allocation of that size.
pub fn dev_reserve_hard(lens: &[usize]) -> Result<(), String> {
    match dev_reserve(lens) {
        Ok(()) => Ok(()),
        Err(first) => {
            let freed = dev_pool_drain();
            if verbose() {
                eprintln!("[UPERF3-AI] reserve failed ({first}); drained {freed} pooled buffers and retrying");
            }
            dev_reserve(lens).map_err(|e| format!("{e}; {first} even after draining {freed} pooled buffers"))
        }
    }
}

fn zerocheck_impl(kind: i32, nblk: Option<usize>, specs: &[TabSpec], prm: &[u64], tr: &mut Transcript) -> Result<ProverOutput, String> {
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let t0 = Instant::now();
    let k = specs.len();
    let l = match &specs[0] {
        TabSpec::FromFp(_, _, n) | TabSpec::FromFp2(_, _, _, n) => *n,
        TabSpec::Eq(r) => 1usize << r.len(),
    };
    assert!(l.is_power_of_two() && (k <= 16 || nblk.is_some()));
    let nv = l.trailing_zeros() as usize;
    let mut tabs_p = Pooled::take(&dev, k * l * 2)?;
    let tabs = tabs_p.get_mut();
    let f_fp = dev.get_func(MODULE, "k_tab_from_fp").ok_or("k_tab_from_fp missing")?;
    let f_fp2 = dev.get_func(MODULE, "k_tab_from_fp2").ok_or("k_tab_from_fp2 missing")?;
    let mut eq_pts: Vec<CudaSlice<u64>> = Vec::new();
    for (t, sp) in specs.iter().enumerate() {
        let mut dst = tabs.slice_mut(t * l * 2..(t + 1) * l * 2);
        let cfg = LaunchConfig::for_num_elems(l as u32);
        match sp {
            TabSpec::FromFp(dc, off, n) => {
                assert_eq!(*n, l);
                let src = dc.data.get().slice(*off..*off + *n);
                unsafe { f_fp.clone().launch(cfg, (&src, &mut dst, *n as i32)) }.map_err(|e| format!("k_tab_from_fp: {e}"))?;
            }
            TabSpec::FromFp2(dc, ore, oim, n) => {
                assert_eq!(*n, l);
                let re = dc.data.get().slice(*ore..*ore + *n);
                let im = dc.data.get().slice(*oim..*oim + *n);
                unsafe { f_fp2.clone().launch(cfg, (&re, &im, &mut dst, *n as i32)) }.map_err(|e| format!("k_tab_from_fp2: {e}"))?;
            }
            TabSpec::Eq(r) => {
                assert_eq!(1usize << r.len(), l);
                let keep = g.eq_table_into(r, &mut dst)?;
                eq_pts.extend(keep);
            }
        }
    }
    let prm_len = prm.len();
    let (kname, threads) = match nblk {
        None => {
            assert!(prm_len <= 32);
            let (kname, want_k) = if kind == 0 { ("k_sc_round_zc20", 13) } else { ("k_sc_round_zc17", 15) };
            assert_eq!(k, want_k, "zero-check kind {kind} expects {want_k} tables");
            (kname, SC_THREADS)
        }
        // [UPERF3-AH] any block count: the tables are 3 eq + 10 nb (F) / 4 nb (D)
        // and the parameters are block-indexed (kernels.cu's layout).
        Some(nb) => {
            let (kname, want_k, want_prm) = if kind == 0 { ("k_sc_round_zcf_gen", 3 + 10 * nb, 17 + 14 * nb) } else { ("k_sc_round_zcd_gen", 3 + 4 * nb, 7 + 6 * nb) };
            assert_eq!(k, want_k, "zero-check kind {kind} with {nb} blocks expects {want_k} tables");
            assert_eq!(prm_len, want_prm, "zero-check kind {kind} with {nb} blocks expects {want_prm} parameters");
            if prm_len > SCG_MAX_PRM {
                return Err(format!("zero-check kind {kind}: {nb} blocks need {prm_len} parameters (kernel holds {SCG_MAX_PRM})"));
            }
            (kname, SCG_THREADS)
        }
    };
    let mut prm32 = prm.to_vec();
    prm32.resize(prm_len.max(32), 0);
    let d_prm = dev.htod_sync_copy(&prm32).map_err(|e| e.to_string())?;
    let mut d_part = unsafe { dev.alloc::<u64>(SC_MAX_BLOCKS as usize * 5 * 2) }.map_err(|e| e.to_string())?;
    let mut d_sums = unsafe { dev.alloc::<u64>(5 * 2) }.map_err(|e| e.to_string())?;
    let f_round = dev.get_func(MODULE, kname).ok_or("k_sc_round missing")?;
    let f_red = dev.get_func(MODULE, "k_reduce_f2").ok_or("k_reduce_f2 missing")?;
    let f_fold = dev.get_func(MODULE, "k_sc_fold").ok_or("k_sc_fold missing")?;
    note_vram(&g);
    let vb = verbose();
    let sync = |on: bool| -> Result<(), String> { if on { dev.synchronize().map_err(|e| e.to_string()) } else { Ok(()) } };
    sync(vb)?;
    let t_tab = t0.elapsed().as_secs_f64();
    let (mut t_round, mut t_fold, mut t_sync) = (0.0f64, 0.0f64, 0.0f64);
    let mut rounds = Vec::with_capacity(nv);
    let mut challenges = Vec::with_capacity(nv);
    let mut half = l / 2;
    for _round in 0..nv {
        let ta = Instant::now();
        let blocks = (((half as u32) + threads - 1) / threads).clamp(1, SC_MAX_BLOCKS);
        let cfg = LaunchConfig { grid_dim: (blocks, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
        match nblk {
            None => unsafe { f_round.clone().launch(cfg, (&*tabs, half as i32, l as i32, &d_prm, &mut d_part)) },
            Some(nb) => unsafe { f_round.clone().launch(cfg, (&*tabs, half as i32, l as i32, &d_prm, prm_len as i32, nb as i32, &mut d_part)) },
        }
        .map_err(|e| format!("k_sc_round: {e}"))?;
        let cfg_r = LaunchConfig { grid_dim: (1, 1, 1), block_dim: (1024, 1, 1), shared_mem_bytes: 0 };
        unsafe { f_red.clone().launch(cfg_r, (&d_part, blocks as i32, 5i32, &mut d_sums)) }.map_err(|e| format!("k_reduce_f2: {e}"))?;
        sync(vb)?;
        let tb = Instant::now();
        let h = dev.dtoh_sync_copy(&d_sums).map_err(|e| e.to_string())?;
        let sums: Vec<Fp2> = (0..5).map(|d| Fp2::new(Fp(h[2 * d]), Fp(h[2 * d + 1]))).collect();
        tr.absorb_fp2(b"sc-round", &sums);
        let r = tr.challenge_fp2();
        challenges.push(r);
        rounds.push(sums);
        let tc = Instant::now();
        let cfg_f = LaunchConfig::for_num_elems((k * half) as u32);
        unsafe { f_fold.clone().launch(cfg_f, (&mut *tabs, k as i32, half as i32, l as i32, r.c0.0, r.c1.0)) }.map_err(|e| format!("k_sc_fold: {e}"))?;
        sync(vb)?;
        let td = Instant::now();
        t_round += (tb - ta).as_secs_f64();
        t_sync += (tc - tb).as_secs_f64();
        t_fold += (td - tc).as_secs_f64();
        half /= 2;
    }
    let mut finals: Vec<Fp2> = Vec::with_capacity(k);
    for t in 0..k {
        let v = dev.dtoh_sync_copy(&tabs.slice(t * l * 2..t * l * 2 + 2)).map_err(|e| e.to_string())?;
        finals.push(Fp2::new(Fp(v[0]), Fp(v[1])));
    }
    if verbose() {
        eprintln!(
            "[UPERF3-XX] zero-check kind {kind} (2^{nv} x {k}): tables {:.4} s | rounds {:.4} s | folds {:.4} s | sync/absorb {:.4} s | total {:.4} s",
            t_tab, t_round, t_fold, t_sync, t0.elapsed().as_secs_f64()
        );
    }
    stats_with(|s| s.secs_sumcheck += t0.elapsed().as_secs_f64());
    Ok(ProverOutput { proof: SumcheckProof { rounds }, challenges, finals })
}

/// [UPERF3-AH] One table of the ZK TABLE zero-check: each is ZERO-EXTENDED
/// from its own length to the sumcheck's 2^log_S (the host does the same
/// with `resize(big, ZERO)`).
pub enum TabSpecPad<'a> {
    /// eq(point, .) over 2^len(point) entries, MSB convention (full length)
    Eq(&'a [Fp2]),
    /// (commitment, element offset, live length): dst[i] = (data[off + i], 0), then zeros
    FromFp(&'a DevCommit, usize, usize),
    /// (commitment, re offset, im offset, live length)
    FromFp2(&'a DevCommit, usize, usize, usize),
    /// a host vector (the PUBLIC table values), uploaded, then zeros
    Host(&'a [Fp2]),
}

/// [UPERF3-AH] (rung 3; lane AD's 20%-of-the-GPU-ZK-prove item) The ZK
/// table zero-check on the device: the same DEGREE-3 sumcheck over
/// log_S = max(log n, 16) variables that `masked_prove` runs on the host,
/// with the tables built on the device from the resident A / H data plus
/// the uploaded public table values. The transcript is the caller's (the
/// ZK masker is set on it), so the absorbed round polynomials — and the
/// proof bytes — are the host path's. `Err` -> the caller runs the host
/// body (the attempt is made on a cloned transcript state).
pub fn dev_tab_zerocheck(specs: &[TabSpecPad], prm: &[u64], tr: &mut Transcript) -> Result<ProverOutput, String> {
    const NV: usize = 4; // degree 3
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let t0 = Instant::now();
    let k = specs.len();
    assert!(k >= 4 && (k - 1) % 3 == 0, "table zero-check: 1 eq + 3 per slot, got {k}");
    let ns = (k - 1) / 3;
    let l = match &specs[0] {
        TabSpecPad::Eq(r) => 1usize << r.len(),
        _ => return Err("table zero-check: table 0 must be the eq table".to_string()),
    };
    assert!(l.is_power_of_two());
    let nv = l.trailing_zeros() as usize;
    let prm_len = prm.len();
    if prm_len != 2 + 2 * ns {
        return Err(format!("table zero-check: {ns} slots expect {} parameters, got {prm_len}", 2 + 2 * ns));
    }
    if prm_len > SCG_MAX_PRM {
        return Err(format!("table zero-check: {prm_len} parameters (kernel holds {SCG_MAX_PRM})"));
    }
    let mut tabs_p = Pooled::take(&dev, k * l * 2)?;
    // one zeroing pass: every table's tail beyond its live length is the host's ZERO padding
    dev.memset_zeros(tabs_p.get_mut()).map_err(|e| format!("tab zerocheck memset: {e}"))?;
    let tabs = tabs_p.get_mut();
    let f_fp = dev.get_func(MODULE, "k_tab_from_fp").ok_or("k_tab_from_fp missing")?;
    let f_fp2 = dev.get_func(MODULE, "k_tab_from_fp2").ok_or("k_tab_from_fp2 missing")?;
    let mut eq_pts: Vec<CudaSlice<u64>> = Vec::new();
    for (t, sp) in specs.iter().enumerate() {
        let mut dst = tabs.slice_mut(t * l * 2..(t + 1) * l * 2);
        match sp {
            TabSpecPad::Eq(r) => {
                assert_eq!(1usize << r.len(), l);
                let keep = g.eq_table_into(r, &mut dst)?;
                eq_pts.extend(keep);
            }
            TabSpecPad::FromFp(dc, off, n) => {
                assert!(*n <= l);
                let src = dc.data.get().slice(*off..*off + *n);
                let cfg = LaunchConfig::for_num_elems(*n as u32);
                unsafe { f_fp.clone().launch(cfg, (&src, &mut dst, *n as i32)) }.map_err(|e| format!("k_tab_from_fp: {e}"))?;
            }
            TabSpecPad::FromFp2(dc, ore, oim, n) => {
                assert!(*n <= l);
                let re = dc.data.get().slice(*ore..*ore + *n);
                let im = dc.data.get().slice(*oim..*oim + *n);
                let cfg = LaunchConfig::for_num_elems(*n as u32);
                unsafe { f_fp2.clone().launch(cfg, (&re, &im, &mut dst, *n as i32)) }.map_err(|e| format!("k_tab_from_fp2: {e}"))?;
            }
            TabSpecPad::Host(v) => {
                assert!(v.len() <= l);
                let flat = as_u64s_f2(v);
                let mut head = dst.slice_mut(0..flat.len());
                dev.htod_sync_copy_into(&flat, &mut head).map_err(|e| format!("tab values upload: {e}"))?;
            }
        }
    }
    let d_prm = dev.htod_sync_copy(&prm.to_vec()).map_err(|e| e.to_string())?;
    let mut d_part = unsafe { dev.alloc::<u64>(SC_MAX_BLOCKS as usize * NV * 2) }.map_err(|e| e.to_string())?;
    let mut d_sums = unsafe { dev.alloc::<u64>(NV * 2) }.map_err(|e| e.to_string())?;
    let f_round = dev.get_func(MODULE, "k_sc_round_tab_gen").ok_or("k_sc_round_tab_gen missing")?;
    let f_red = dev.get_func(MODULE, "k_reduce_f2").ok_or("k_reduce_f2 missing")?;
    let f_fold = dev.get_func(MODULE, "k_sc_fold").ok_or("k_sc_fold missing")?;
    note_vram(&g);
    let mut rounds = Vec::with_capacity(nv);
    let mut challenges = Vec::with_capacity(nv);
    let mut half = l / 2;
    for _round in 0..nv {
        let blocks = (((half as u32) + SCG_THREADS - 1) / SCG_THREADS).clamp(1, SC_MAX_BLOCKS);
        let cfg = LaunchConfig { grid_dim: (blocks, 1, 1), block_dim: (SCG_THREADS, 1, 1), shared_mem_bytes: 0 };
        unsafe { f_round.clone().launch(cfg, (&*tabs, half as i32, l as i32, &d_prm, prm_len as i32, ns as i32, &mut d_part)) }
            .map_err(|e| format!("k_sc_round_tab_gen: {e}"))?;
        let cfg_r = LaunchConfig { grid_dim: (1, 1, 1), block_dim: (1024, 1, 1), shared_mem_bytes: 0 };
        unsafe { f_red.clone().launch(cfg_r, (&d_part, blocks as i32, NV as i32, &mut d_sums)) }.map_err(|e| format!("k_reduce_f2: {e}"))?;
        let h = dev.dtoh_sync_copy(&d_sums).map_err(|e| e.to_string())?;
        let sums: Vec<Fp2> = (0..NV).map(|d| Fp2::new(Fp(h[2 * d]), Fp(h[2 * d + 1]))).collect();
        tr.absorb_fp2(b"sc-round", &sums);
        let r = tr.challenge_fp2();
        challenges.push(r);
        rounds.push(sums);
        let cfg_f = LaunchConfig::for_num_elems((k * half) as u32);
        unsafe { f_fold.clone().launch(cfg_f, (&mut *tabs, k as i32, half as i32, l as i32, r.c0.0, r.c1.0)) }.map_err(|e| format!("k_sc_fold: {e}"))?;
        half /= 2;
    }
    let mut finals: Vec<Fp2> = Vec::with_capacity(k);
    for t in 0..k {
        let v = dev.dtoh_sync_copy(&tabs.slice(t * l * 2..t * l * 2 + 2)).map_err(|e| e.to_string())?;
        finals.push(Fp2::new(Fp(v[0]), Fp(v[1])));
    }
    if verbose() {
        eprintln!("[UPERF3-AH] table zero-check (2^{nv} x {k}, {ns} slots): {:.4} s", t0.elapsed().as_secs_f64());
    }
    stats_with(|s| s.secs_sumcheck += t0.elapsed().as_secs_f64());
    Ok(ProverOutput { proof: SumcheckProof { rounds }, challenges, finals })
}

/// [rung 4] rho^T M for up to 4 row-weight vectors at once, on the
/// device-resident systematic data (== pcs::fold_rows_multi).
pub fn dev_fold_rows(dc: &DevCommit, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String> {
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let t0 = Instant::now();
    let k = rhos.len();
    let rows = dc.rows;
    let n = 1usize << dc.log_n;
    assert!(k >= 1 && k <= 4, "dev_fold_rows: {k} weight vectors (max 4)");
    let mut flat: Vec<u64> = Vec::with_capacity(k * rows * 2);
    for rho in rhos {
        assert_eq!(rho.len(), rows);
        flat.extend(as_u64s_f2(rho));
    }
    let d_rho = dev.htod_sync_copy(&flat).map_err(|e| e.to_string())?;
    let mut d_out = unsafe { dev.alloc::<u64>(k * n * 2) }.map_err(|e| e.to_string())?;
    let f = dev.get_func(MODULE, "k_fold_rows").ok_or("k_fold_rows missing")?;
    let cfg = LaunchConfig::for_num_elems(n as u32);
    unsafe { f.launch(cfg, (dc.data.get(), &d_rho, &mut d_out, rows as i32, n as i32, k as i32)) }.map_err(|e| format!("k_fold_rows: {e}"))?;
    let h = dev.dtoh_sync_copy(&d_out).map_err(|e| e.to_string())?;
    stats_with(|s| { s.secs_fold += t0.elapsed().as_secs_f64(); s.bytes_d2h += (k * n * 16) as u64; });
    Ok((0..k).map(|g| (0..n).map(|j| Fp2::new(Fp(h[(g * n + j) * 2]), Fp(h[(g * n + j) * 2 + 1]))).collect()).collect())
}

/// One helper column's specification (element offsets into the A data /
/// the H data): l1 = v1 + beta * w + c1 (w optional), l2 = v2 + c2.
pub struct HelperSpec {
    pub off_v1: usize,
    pub off_w: Option<usize>,
    pub off_v2: usize,
    pub len: usize,
    pub c1: Fp2,
    pub c2: Fp2,
    pub off_re: usize,
    pub off_im: usize,
}

/// [rung 4b] The LogUp helper columns computed on the device from the
/// resident A data into a fresh H data buffer (h_len u64), returned
/// together with each helper's (re, im) column sums (the helper-sum
/// functionals, order-free field sums).
pub fn dev_helpers(a_dc: &DevCommit, h_len: usize, specs: &[HelperSpec], alpha: Fp2, beta: Fp2) -> Result<(Pooled, Vec<Fp2>), String> {
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let t0 = Instant::now();
    let mut d_h = Pooled::take(&dev, h_len)?;
    let f = dev.get_func(MODULE, "k_helper").ok_or("k_helper missing")?;
    let f_sum = dev.get_func(MODULE, "k_sum_fp").ok_or("k_sum_fp missing")?;
    let mut sums = Vec::with_capacity(specs.len());
    let mut d_part = unsafe { dev.alloc::<u64>(1024) }.map_err(|e| e.to_string())?;
    for sp in specs {
        let prm = as_u64s_f2(&[alpha, beta, sp.c1, sp.c2]);
        let d_prm = dev.htod_sync_copy(&prm).map_err(|e| e.to_string())?;
        // HC = 8 elements per thread (den + prefix arrays live in registers); 128-thread blocks keep
        // the register file within the launch limit.
        let threads = (sp.len + 7) / 8;
        let cfg = LaunchConfig { grid_dim: (((threads + 127) / 128) as u32, 1, 1), block_dim: (128, 1, 1), shared_mem_bytes: 0 };
        let off_w: i32 = sp.off_w.map(|o| o as i32).unwrap_or(-1);
        unsafe {
            f.clone().launch(cfg, (a_dc.data.get(), sp.off_v1 as i32, off_w, sp.off_v2 as i32, sp.len as i32, &d_prm, d_h.get_mut(), sp.off_re as i32, sp.off_im as i32))
        }
        .map_err(|e| format!("k_helper: {e}"))?;
        let mut parts = [Fp::ZERO; 2];
        for (which, off) in [sp.off_re, sp.off_im].iter().enumerate() {
            let blocks = (((sp.len + 255) / 256) as u32).clamp(1, 1024);
            let cfg_s = LaunchConfig { grid_dim: (blocks, 1, 1), block_dim: (256, 1, 1), shared_mem_bytes: 0 };
            unsafe { f_sum.clone().launch(cfg_s, (d_h.get(), *off as i32, sp.len as i32, &mut d_part)) }.map_err(|e| format!("k_sum_fp: {e}"))?;
            let h = dev.dtoh_sync_copy(&d_part.slice(0..blocks as usize)).map_err(|e| e.to_string())?;
            parts[which] = h.iter().fold(Fp::ZERO, |a, &b| a.add(Fp(b)));
        }
        sums.push(Fp2::new(parts[0], parts[1]));
    }
    stats_with(|s| s.secs_helpers += t0.elapsed().as_secs_f64());
    Ok((d_h, sums))
}

impl Gpu {
    /// eq(r, .) over 2^len(r) entries into `dst` (MSB convention): the two
    /// half tables by the per-bit product, joined by one f2_mul per entry.
    /// Returns the buffers that must outlive the launches.
    fn eq_table_into(&self, r: &[Fp2], dst: &mut cudarc::driver::CudaViewMut<u64>) -> Result<Vec<CudaSlice<u64>>, String> {
        let nv = r.len();
        let n = 1usize << nv;
        let f_eq = self.dev.get_func(MODULE, "k_eq_table").ok_or("k_eq_table missing")?;
        if nv <= 10 {
            let d_r = self.dev.htod_sync_copy(&as_u64s_f2(r)).map_err(|e| e.to_string())?;
            let cfg = LaunchConfig::for_num_elems(n as u32);
            unsafe { f_eq.launch(cfg, (&d_r, &mut *dst, nv as i32)) }.map_err(|e| format!("k_eq_table: {e}"))?;
            return Ok(vec![d_r]);
        }
        let lo_bits = nv / 2;
        let hi_bits = nv - lo_bits;
        let d_hi_r = self.dev.htod_sync_copy(&as_u64s_f2(&r[..hi_bits])).map_err(|e| e.to_string())?;
        let d_lo_r = self.dev.htod_sync_copy(&as_u64s_f2(&r[hi_bits..])).map_err(|e| e.to_string())?;
        let mut d_hi = unsafe { self.dev.alloc::<u64>(2 << hi_bits) }.map_err(|e| e.to_string())?;
        let mut d_lo = unsafe { self.dev.alloc::<u64>(2 << lo_bits) }.map_err(|e| e.to_string())?;
        unsafe { f_eq.clone().launch(LaunchConfig::for_num_elems(1 << hi_bits), (&d_hi_r, &mut d_hi, hi_bits as i32)) }.map_err(|e| format!("k_eq_table: {e}"))?;
        unsafe { f_eq.launch(LaunchConfig::for_num_elems(1 << lo_bits), (&d_lo_r, &mut d_lo, lo_bits as i32)) }.map_err(|e| format!("k_eq_table: {e}"))?;
        let f_join = self.dev.get_func(MODULE, "k_eq_join").ok_or("k_eq_join missing")?;
        unsafe { f_join.launch(LaunchConfig::for_num_elems(n as u32), (&d_hi, &d_lo, &mut *dst, lo_bits as i32, n as i32)) }.map_err(|e| format!("k_eq_join: {e}"))?;
        Ok(vec![d_hi_r, d_lo_r, d_hi, d_lo])
    }
}

/// [rung 4c] The prover's `eval_many` on the device: the MLE of each
/// base-field slice (offset, len = 2^len(point)) of the resident data at
/// `point`, sharing one device eq table.
pub fn dev_eval_many(dc: &DevCommit, offs: &[usize], point: &[Fp2]) -> Result<Vec<Fp2>, String> {
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let t0 = Instant::now();
    let n = 1usize << point.len();
    let m = offs.len();
    let mut d_eq = unsafe { dev.alloc::<u64>(2 * n) }.map_err(|e| e.to_string())?;
    let _keep = g.eq_table_into(point, &mut d_eq.slice_mut(..))?;
    let offs32: Vec<i32> = offs.iter().map(|&o| o as i32).collect();
    let d_offs = dev.htod_sync_copy(&offs32).map_err(|e| e.to_string())?;
    let blocks = (((n + 255) / 256) as u32).clamp(1, 1024);
    let mut d_part = unsafe { dev.alloc::<u64>(blocks as usize * m * 2) }.map_err(|e| e.to_string())?;
    let f = dev.get_func(MODULE, "k_dot_slices").ok_or("k_dot_slices missing")?;
    let cfg = LaunchConfig { grid_dim: (blocks, 1, 1), block_dim: (256, 1, 1), shared_mem_bytes: 0 };
    unsafe { f.launch(cfg, (dc.data.get(), &d_offs, m as i32, &d_eq, n as i32, &mut d_part)) }.map_err(|e| format!("k_dot_slices: {e}"))?;
    let h = dev.dtoh_sync_copy(&d_part).map_err(|e| e.to_string())?;
    let mut out = vec![Fp2::ZERO; m];
    for b in 0..blocks as usize {
        for s in 0..m {
            out[s] = out[s].add(Fp2::new(Fp(h[(b * m + s) * 2]), Fp(h[(b * m + s) * 2 + 1])));
        }
    }
    stats_with(|s| s.secs_fold += t0.elapsed().as_secs_f64());
    Ok(out)
}

impl Gpu {
    /// [rung 4d] The systematic RS encoding of `rows` rows without any
    /// gather: DIF inverse (natural in, bit-reversed coefficients out) then
    /// DIT forward from the bit-reversed, zero-padded coefficients (natural
    /// evaluations out). `data` rows x n, `coef` rows x n scratch, `enc`
    /// rows x nn.
    fn encode_rows(&self, data: &CudaSlice<u64>, coef: &mut CudaSlice<u64>, enc: &mut CudaSlice<u64>, rows: usize, log_n: u32, log_nn: u32) -> Result<(), String> {
        let (max_log, tf, ti) = self.tw.as_ref().ok_or("twiddles not uploaded")?;
        assert!(log_nn <= *max_log && log_n <= log_nn);
        let vb = verbose();
        let ta = Instant::now();
        let scale: u64 = Fp::new(1u64 << log_n).inv().0;
        let threads = ntt_threads();
        // inverse: DIF pass A (strided stages) into coef, then pass B (contiguous) in place
        if log_n > NTT_LOG_BLK {
            let pa = self.dev.get_func(MODULE, kn_dif_pa()).ok_or("k_dif_pa missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pa.launch(cfg, (data, &mut *coef, ti, log_n as i32)) }.map_err(|e| format!("k_dif_pa: {e}"))?;
            let pb = self.dev.get_func(MODULE, kn_dif_pb()).ok_or("k_dif_pb missing")?;
            let bpr = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            // in place: the raw pointer as the source (each block reads its own range before writing it)
            let cptr: sys::CUdeviceptr = *coef.device_ptr();
            unsafe { pb.launch(cfg, (cptr, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        } else {
            let pb = self.dev.get_func(MODULE, kn_dif_pb()).ok_or("k_dif_pb missing")?;
            let cfg = LaunchConfig { grid_dim: (rows as u32, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pb.launch(cfg, (data, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        }
        if vb { self.dev.synchronize().map_err(|e| e.to_string())?; }
        let tb = Instant::now();
        // forward: DIT p1 with the contiguous padded load, then p2
        let rb = log_nn - log_n;
        let p1 = self.dev.get_func(MODULE, kn_dit_p1_pad()).ok_or("k_dit_p1_pad missing")?;
        let lb = log_nn.min(NTT_LOG_BLK);
        let bpr = 1u32 << (log_nn - lb);
        let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
        unsafe { p1.launch(cfg, (&*coef, &mut *enc, tf, log_nn as i32, (1usize << log_n) as i32, rb as i32)) }.map_err(|e| format!("k_dit_p1_pad: {e}"))?;
        if log_nn > NTT_LOG_BLK {
            let p2 = self.dev.get_func(MODULE, kn_ntt_p2()).ok_or("k_ntt_p2 missing")?;
            let tiles = 1u32 << (log_nn - NTT_LOG_BLK);
            let cfg2 = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { p2.launch(cfg2, (&mut *enc, tf, log_nn as i32, 1u64)) }.map_err(|e| format!("k_ntt_p2: {e}"))?;
        }
        if vb {
            self.dev.synchronize().map_err(|e| e.to_string())?;
            eprintln!("[UPERF3-XX]   encode rows {rows} 2^{log_n} -> 2^{log_nn}: dif inverse {:.4} | dit forward {:.4} s", (tb - ta).as_secs_f64(), tb.elapsed().as_secs_f64());
        }
        Ok(())
    }
}

// ===========================================================================
// [UPERF3-ZA] The ZK commitment on the device (new entries beside the
// existing ones; nothing above changes). The encoding of pcs::commit_zk:
// inverse NTT of every row (natural-order coefficients, rung 1's gather
// form), the pad + coset scaling kernel, the size-nn forward NTT, the
// column hashes (unsalted: the host salts the leaves as on the CPU path).
// ===========================================================================

/// Commit a device-resident data buffer (rows x n) in ZK mode: `pads` rows x q, `pows` h^i for i < nn.
pub fn dev_commit_zk_from(params: &PcsParams, d_data: Pooled, rows: usize, pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    g.ensure_twiddles(ntt)?;
    let n = params.cols();
    let nn = params.enc_cols();
    assert_eq!(d_data.get().len(), rows * n);
    assert_eq!(pads.len() % rows, 0);
    let q = pads.len() / rows;
    assert!(n + q <= nn && pows.len() == nn);
    let log_n = params.log_cols;
    let log_nn = nn.trailing_zeros();
    assert_eq!(1usize << log_nn, nn, "inv_rate must be a power of two on the device path");
    let dev = g.dev.clone();
    let t1 = Instant::now();

    // [ZK60-CL1] The hiding commitment's peak is
    //   [rows*(n + q + 2*nn) + nn] * 8 bytes
    // because BOTH `rows*nn` buffers are live across the expand NTT. At the
    // Mistral W shape that is 12,142 MiB, and the single `rows*nn` take is
    // 5,387 MiB — the allocation that died on 2026-09-04. The non-hiding twin
    // has chunked by size, and fallen back to chunked on allocation failure,
    // since [UPERF3-AC]; this path simply never learned to. Chunked, the same
    // shape peaks at ~1,563 MiB. See ZK60_CLAUDE_GPU.md.
    let want = (rows * nn * 8) as u64;
    let mode = zk_chunk_mode();
    let chunked_now = mode == ZkChunk::Force || (mode == ZkChunk::Auto && want as usize > chunk_bytes());

    // pads and powers are needed by BOTH paths, uploaded exactly as before; a
    // chunked commitment KEEPS them so `dev_columns` can re-encode through the
    // pad/coset step (~21.5 MiB at the Mistral W shape, against 5,387 freed).
    let t_up0 = Instant::now();
    let d_pads = dev.htod_sync_copy(as_u64s(pads)).map_err(|e| format!("pads upload: {e}"))?;
    note_raw_alloc(pads.len() * 8);
    let d_pows = dev.htod_sync_copy(as_u64s(pows)).map_err(|e| format!("pows upload: {e}"))?;
    note_raw_alloc(pows.len() * 8);
    // [ZK60-CL4 review] pads/powers are RAW device capacity, not pooled, and a
    // chunked commitment RETAINS them for its deferred opening. Counting them
    // is the difference between a capacity claim and an untestable one.
    // [round-7 review] one note per allocation, not one per pair.
    // [ZK60-CL4] the caller's own EXCLUSIVE interval: a TRANSFER, not an NTT.
    let t_upload = t_up0.elapsed().as_secs_f64();
    stats_with(|s| s.bytes_h2d += ((pads.len() + pows.len()) * 8) as u64);

    // Chunk by size, or because the resident pair will not fit. Never a silent
    // CPU fallback: the caller's CPU path is only reached on a real `Err`.
    //
    // [ZK60-CL2] EXCEPT under `HL_ZK_CHUNK=off`, which is STRICT. The first
    // version of this took the chunked branch on allocation failure even in
    // "off", so the reference-mode switch did not actually retain the
    // reference path — the one job it had. An allocation failure in strict
    // mode is now REPORTED, because a switch that silently changes strategy
    // under load is worse than no switch: it makes the reference arm of an
    // A/B secretly the same as the test arm.
    let resident = if chunked_now { None } else {
        match (Pooled::take(&dev, rows * n), Pooled::take(&dev, rows * nn)) {
            (Ok(c), Ok(c2)) => Some((c, c2)),
            (a, b) => {
                if mode == ZkChunk::Off {
                    let which = if a.is_err() { "coefficient (rows*n)" } else { "expanded (rows*nn)" };
                    let why = a.err().or(b.err()).unwrap_or_else(|| "unknown".to_string());
                    // `a`/`b` drop here: any buffer that DID allocate returns
                    // to the pool rather than leaking.
                    return Err(format!(
                        "HL_ZK_CHUNK=off (strict reference mode): the resident {which} buffer could not be allocated \
                         and strict mode forbids falling back to the chunked path — {why}. \
                         Unset HL_ZK_CHUNK (auto) to allow chunking."
                    ));
                }
                None
            }
        }
    };
    let (mut d_coef, mut d_coef2) = match resident {
        Some(x) => x,
        None => {
            if verbose() {
                eprintln!("[ZK60-CL1]   zk commit rows {rows} 2^{log_n} -> 2^{log_nn} (q {q}, {:.0} MB resident): CHUNKED ({})",
                          (rows * nn * 8) as f64 / 1e6,
                          if chunked_now { if mode == ZkChunk::Force { "forced" } else { "by size" } } else { "resident alloc failed" });
            }
            let leaves = g.commit_zk_chunked(&d_data, &d_pads, &d_pows, rows, n, q, nn, log_n, log_nn, chunk_rows())?;
            note_vram(&g);
            // [ZK60-CL4] NO secs_ntt charge here. commit_zk_chunked already
            // charged its own encode+hash wall, and t1.elapsed() SPANS that
            // call, so adding it again DOUBLE-CHARGED the chunked path. The
            // caller's exclusive work is the upload, and it is a transfer.
            stats_with(|s| s.secs_h2d += t_upload);
            let zk = ZkReenc { pads: d_pads, pows: d_pows, q };
            return Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: None, zk: Some(zk) }, leaves));
        }
    };

    g.ntt_rows(d_data.get(), d_coef.get_mut(), rows, n, log_n, true)?;
    let f = dev.get_func(MODULE, "k_zk_pad_scale").ok_or("k_zk_pad_scale missing")?;
    let cfg = LaunchConfig::for_num_elems((rows * nn) as u32);
    unsafe { f.launch(cfg, (d_coef.get(), &d_pads, &d_pows, d_coef2.get_mut(), rows as i32, n as i32, q as i32, nn as i32)) }.map_err(|e| format!("k_zk_pad_scale: {e}"))?;
    drop(d_coef);
    // [ZK60-CL3] The LAST resident allocation. It used to be a bare `?`, which
    // handed the whole commitment to the caller's CPU path — a much larger and
    // slower fallback than the chunked one that is right there. The first two
    // takes get a chunked retry; this one did not, purely because it happens
    // later in the function.
    //
    // Retrying is sound: chunking re-derives everything from `d_data`, which
    // is still live, so the work done so far is discarded rather than reused.
    // Dropping `d_coef2` first matters — it returns that buffer to the pool,
    // and `take_min` can then reuse it as chunk scratch (a chunk needs
    // `rmax*nn <= rows*nn`), so the retry usually needs NO new device memory.
    let mut d_enc = match Pooled::take(&dev, rows * nn) {
        Ok(e) => e,
        Err(why) => {
            if mode == ZkChunk::Off {
                return Err(format!(
                    "HL_ZK_CHUNK=off (strict reference mode): the resident encoded buffer \
                     could not be allocated and strict mode forbids the chunked retry — {why}. \
                     Unset HL_ZK_CHUNK (auto) to allow chunking."
                ));
            }
            drop(d_coef2);
            if verbose() {
                eprintln!("[ZK60-CL3]   zk commit rows {rows} 2^{log_n} -> 2^{log_nn}: the encoded buffer was refused ({why}); RETRYING CHUNKED");
            }
            // [ZK60-CL4] exclusive split for the fallback: everything spent so
            // far MINUS the upload is the resident attempt's discarded NTT and
            // pad/scale. It really ran, so it is charged; the callee then
            // charges the chunked encode. upload + discarded + chunked = wall,
            // with no interval counted twice.
            let t_discarded = (t1.elapsed().as_secs_f64() - t_upload).max(0.0);
            let leaves = g.commit_zk_chunked(&d_data, &d_pads, &d_pows, rows, n, q, nn, log_n, log_nn, chunk_rows())?;
            note_vram(&g);
            stats_with(|s| { s.secs_h2d += t_upload; s.secs_ntt += t_discarded; });
            let zk = ZkReenc { pads: d_pads, pows: d_pows, q };
            return Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: None, zk: Some(zk) }, leaves));
        }
    };
    g.ntt_rows(d_coef2.get(), d_enc.get_mut(), rows, nn, log_nn, false)?;
    dev.synchronize().map_err(|e| e.to_string())?;
    let t2 = Instant::now();
    stats_with(|s| s.secs_ntt += (t2 - t1).as_secs_f64());
    note_vram(&g);
    drop(d_coef2);
    let leaves = g.hash_cols(d_enc.get(), rows, nn)?;
    let t3 = Instant::now();
    stats_with(|s| { s.secs_hash += (t3 - t2).as_secs_f64(); s.bytes_d2h += (nn * 32) as u64; });
    Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: Some(d_enc), zk: None }, leaves))
}

/// Upload `data` and commit it in ZK mode (== pcs::commit_zk's encoding and leaves).
pub fn dev_commit_zk(params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    let n = params.cols();
    assert!(data.len() % n == 0 && !data.is_empty());
    let rows = data.len() / n;
    let dev = g.dev.clone();
    let t0 = Instant::now();
    let mut d_data = Pooled::take(&dev, data.len())?;
    g.upload_sync(d_data.get_mut(), as_u64s(data))?; // [UPERF3-AJ] pinned staging
    let _ = t0;
    drop(g);
    dev_commit_zk_from(params, d_data, rows, pads, pows, ntt)
}

/// Write `data` into a device buffer at element `offset` (the ZK H commit's host-generated tail rows).
pub fn dev_upload_rows(d: &mut Pooled, offset: usize, data: &[Fp]) -> Result<(), String> {
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    assert!(offset + data.len() <= d.get().len());
    let t0 = Instant::now();
    {
        let mut view = d.get_mut().slice_mut(offset..offset + data.len());
        dev.htod_sync_copy_into(as_u64s(data), &mut view).map_err(|e| format!("rows upload: {e}"))?;
    }
    dev.synchronize().map_err(|e| e.to_string())?;
    stats_with(|s| { s.secs_h2d += t0.elapsed().as_secs_f64(); s.bytes_h2d += (data.len() * 8) as u64; });
    Ok(())
}

// ---------------------------------------------------------------------------
// [FSP-HOST] ITEM (a)'s DEVICE-ARM ORACLE. `gpu/mod.rs`'s `planes` module
// carries the host oracle (the plane fill against `prove_layer_v3`'s own
// buffer, in every configuration). This one is the pair that only exists
// with `--features gpu-cuda`: the staged bytes the plane source hands the
// DMA are compared with the staged bytes `pack_narrow` — the real
// function, not a transcription — produces from the converted `Vec<Fp>`,
// at `w = 1`, over the same ranges, including a non-multiple-of-block
// range and the CHUNKED form (the successive pieces of a row-chunked
// upload). `hashline/src/bin/hashline.rs` is not this lane's file, so the
// rung could not be added to the `gpu-probe` command; it is run by
// `results/fsp4_oracles.sh` as `cargo test --features gpu-cuda --lib`.
// Neither test needs a device: both sides are host code.
#[cfg(test)]
mod fsp4_plane_oracle {
    use super::*;
    use zkp_core::ffn_v3::Layout;

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

    /// (t_rows, d, f): the 12x512 fixture (nb_d 3, nb_f 1 — the shape the
    /// four GPU byte gates prove end to end), a two-sided multi-block
    /// shape, and the 8B block structure scaled down (nb_d 1, nb_f 7 —
    /// the shape no fixture can reach).
    const SHAPES: [(usize, usize, usize); 3] = [(512, 768, 2048), (16, 96, 192), (16, 256, 1792)];

    #[test]
    fn narrow_off_declines_planes_before_either_device_strategy() {
        const CHILD: &str = "HL_TEST_PLANE_NARROW_OFF_CHILD";
        if std::env::var_os(CHILD).is_some() {
            let plane = vec![1i8; 64];
            let pt = PlaneTiling::new(&plane, &plane, &plane, 8, 8, 4, 4, 2, 2).unwrap();
            let params = PcsParams { log_cols: 4, inv_rate: 4, num_col_checks: 8 };
            let err = dev_commit_planes(&params, &pt, &NttTables::new(6)).err()
                .expect("plane upload ignored HL_GPU_NARROW=0");
            assert_eq!(err, "HL_GPU_NARROW=0: direct plane upload disabled");
            return;
        }
        // Fresh processes isolate the OnceLock-backed environment switches.
        // A disabled path must decline before GPU initialization/allocation,
        // so this test also runs on a feature-enabled host without a device.
        for stream in ["0", "1"] {
            let out = std::process::Command::new(std::env::current_exe().unwrap())
                .args(["--exact", "gpu::cuda::fsp4_plane_oracle::narrow_off_declines_planes_before_either_device_strategy", "--nocapture"])
                .env(CHILD, "1").env("HL_GPU", "1").env("HL_GPU_NARROW", "0")
                .env("HL_GPU_STREAM_COMMIT", stream).env("HL_GPU_CHUNK_BYTES", "1")
                .output().unwrap();
            assert!(out.status.success(), "{}", String::from_utf8_lossy(&out.stderr));
            assert!(String::from_utf8_lossy(&out.stdout).contains("1 passed; 0 failed; 0 ignored"));
        }
    }

    #[test]
    fn plane_fill_equals_pack_narrow_at_w1() {
        for (t, d, f) in SHAPES {
            let lay = Layout::new(t, d, f);
            let (wg, wu, wd) = (plane(d * f, 11), plane(d * f, 12), plane(f * d, 13));
            let pt = PlaneTiling::new(&wg, &wu, &wd, d, f, 1 << lay.log_db, 1 << lay.log_fb, lay.nb_d, lay.nb_f).unwrap();
            assert_eq!(pt.len(), lay.w_len);
            // the inherited source: the converted 64-bit buffer
            let mut w_data = vec![Fp::ZERO; lay.w_len];
            pt.fill_fp(0, &mut w_data);
            let words = as_u64s(&w_data);
            // the probe must agree that this buffer is an int8 plane
            assert_eq!(narrow_probe(words), 1, "narrow_probe at {d}x{f}");
            let (wb, rl) = (lay.wb, 1usize << lay.log_fb);
            let n = lay.w_len;
            let mut ranges: Vec<(usize, usize)> = vec![(0, n), (0, wb), (wb / 2, wb), (1, wb + 3), (rl - 1, 2 * rl + 1), (wb - 1, 2), (n - 1, 1)];
            if n > 3 * wb {
                ranges.push((wb + rl / 2, 2 * wb + 5));
            }
            for (off, len) in ranges {
                let len = len.min(n - off);
                let mut want = vec![0u8; len];
                assert!(pack_narrow(&mut want, &words[off..off + len], 1), "pack_narrow refused {off}+{len}");
                let mut got = vec![0u8; len];
                pt.fill_bytes(off, &mut got);
                assert!(got == want, "plane fill != pack_narrow at {off}+{len}, shape {d}x{f}");
            }
            // the chunked form: one row chunk at a time, as
            // `commit_chunked_upload` stages them
            for rows_per_chunk in [1usize, 2, 3, lay.w_len / wb] {
                let cnt = rows_per_chunk * wb;
                let mut off = 0usize;
                while off < n {
                    let m = cnt.min(n - off);
                    let mut want = vec![0u8; m];
                    assert!(pack_narrow(&mut want, &words[off..off + m], 1));
                    let mut got = vec![0u8; m];
                    pt.fill_bytes(off, &mut got);
                    assert!(got == want, "chunked plane fill != pack_narrow at {off}+{m}, shape {d}x{f}");
                    off += m;
                }
            }
        }
    }

    /// The staging engine slices a send into pieces of
    /// `pin_mb() MB / w` elements; the plane fill must reproduce
    /// `pack_narrow` at EVERY such piece boundary, which for a small
    /// staging buffer falls inside a block and inside a row.
    #[test]
    fn plane_fill_equals_pack_narrow_at_staging_piece_boundaries() {
        let (t, d, f) = (16usize, 256usize, 1792usize);
        let lay = Layout::new(t, d, f);
        let (wg, wu, wd) = (plane(d * f, 21), plane(d * f, 22), plane(f * d, 23));
        let pt = PlaneTiling::new(&wg, &wu, &wd, d, f, 1 << lay.log_db, 1 << lay.log_fb, lay.nb_d, lay.nb_f).unwrap();
        let mut w_data = vec![Fp::ZERO; lay.w_len];
        pt.fill_fp(0, &mut w_data);
        let words = as_u64s(&w_data);
        for per in [1usize, 7, 255, 4096, 65_537, lay.wb - 1, lay.wb + 1] {
            let mut all: Vec<u8> = Vec::with_capacity(lay.w_len);
            let mut off = 0usize;
            while off < lay.w_len {
                let m = per.min(lay.w_len - off);
                let mut piece = vec![0u8; m];
                pt.fill_bytes(off, &mut piece);
                all.extend_from_slice(&piece);
                off += m;
            }
            let mut want = vec![0u8; lay.w_len];
            assert!(pack_narrow(&mut want, words, 1));
            assert!(all == want, "staging pieces of {per} elements do not reassemble pack_narrow's image");
        }
    }
}

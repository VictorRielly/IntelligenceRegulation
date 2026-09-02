// [UPERF2-L] The GPU rung, step 2 — the K-field lane kernels of kfield.rs on
// the device (feature `gpu-cuda`): the fused masked-descent round (all
// three modes), the claim layer's ixf round + fold, the tree step. Device
// code: kernels_k9.cu (its header states the arithmetic and why the values
// are identical). This file: the host side — device-resident chains, the
// uploads, the handover protocol, the four hook entries.
//
// THE DESCENT CHAIN (k9_fused_round). masked_rounds_bulk (gkr_masked.rs)
// runs, per tree layer j, round 0 = FUSE_EXTRACT (reads the tree layer j+1
// and the b-part eq table; writes nothing), round 1 = FUSE_EXTRACT_FOLD
// (reads the same; writes the fresh state-1 tables), rounds t >= 2 =
// FUSE_FOLD (reads state t-1, writes state t IN PLACE on the CPU). Here:
//   * round 0 uploads the layer (the packed live blocks, or the compact
//     leaves re-encoded 8 B per leaf + exceptions and expanded on the
//     device) and the eq table, computes the node values, and KEEPS the
//     layer resident; round 1 reads it there (re-uploads on a tag miss —
//     the host layer is read-only and stays the source of truth), writes
//     the state-1 tables INTO DEVICE MEMORY (live ranges only, packed per
//     range), and keeps them; rounds >= 2 fold on the device out of place
//     (ping-pong), one launch per live range.
//   * The node sums come back every round (a handful of u64s).
//   * The HOST TABLES ARE NOT WRITTEN until the HANDOVER: the last round
//     the device runs — decided at the round itself from the plan: the
//     successor round's output would be below the minimum (`min_pairs`),
//     or the pad slices are about to be materialized (the live ranges'
//     width drops below one pair-block while pads exist). At the handover
//     the current state (the live ranges) is copied into the host buffers
//     exactly where the CPU path would have left it (the first 2 n_pairs
//     blocks of each buffer; the pads' slices untouched, as on the CPU).
//   * WHY THIS IS SAFE (the invariant this file relies on; gkr_masked.rs
//     `masked_rounds_bulk` at f821485): between two consecutive hooked
//     rounds of one layer nothing on the host reads or moves the five
//     buffers — after a fused round the caller only truncates the Vecs
//     (no reallocation), finalizes the planes, absorbs the transcript and
//     draws the challenge; and the successor of a round whose output has
//     >= 2 * min_pairs blocks per table and (no pads, or >= 2 pair-blocks
//     per instance still skipping) is ALWAYS a hooked FUSE_FOLD on the same
//     buffers: `bulk` holds (n_t >= 2 KL, t < n_bvars), `tabs` and
//     `pending` are set, `need_mat` is false, `fuse` is on (else no fused
//     call ever happens). Every hooked call checks the chain's expected
//     successor (mode, buffers, sizes, ranges) and PANICS on a mismatch —
//     the host would otherwise read stale tables; that is a protocol
//     violation, never a value change. Any decline (below the minimum, no
//     device, over the VRAM budget) happens BEFORE a chain is opened, or
//     writes the resident state back to the host first (`abort_to_host`).
//
// THE IXF CHAIN (k9_ixf_round + kt_fold, fold.rs ixf_sumcheck_prove_packed):
// round(t) uploads the tables once, the folds run on the device with an
// EAGER copy of every folded table back to the host (the host stays
// coherent — the ixf loop shrinks the buffers between rounds, so pointer
// identity is not guaranteed there), and the resident copy saves the next
// round's upload when the call sequence is the expected chain (fold(0..nt)
// then round(t+1) with halved sizes); otherwise it re-uploads. Values never
// depend on the cache.
//
// THE TREE STEP (k9_tree_climb): the source (a packed layer, or the compact
// leaves re-encoded) is uploaded, the step(s) run on the device, the
// output layer is copied to the host EAGERLY (its readers are not all
// hooked); the resident output is remembered so that the fused round 0
// that reads the same buffers skips its upload.
//
// Knobs (none changes a value): ZK_GPU=1 (on, with lane K's plumbing),
// ZK_GPU_K9=0 (the K-field kernels off — the one-binary A/B),
// ZK_GPU_K9_MIN_PAIRS (smallest round output in pair-blocks the device
// takes; default 32), ZK_GPU_K9_BUDGET_MB (device memory the K-field
// chains may hold; default = free VRAM at first use minus 512 MB),
// ZK_GPU_K9_EAGER=1 (write every round's state back to the host — the
// battery's cell-by-cell mode; slower), ZK_GPU_VERBOSE=1 (a line per call).
//
// [UPERF2-N] THE DEVICE TREE STORE (k9_tree_build / k9_tree_fetch /
// k9_tree_release / k9_tree_drop; gkr.rs `build_tree_from` + `FracTree::
// layer`): a packed descent tree whose BIG layers (> K9_SMALL_LAYER_N
// elements) live on the device — the leaves go up ONCE (the compact words
// as they are, or the packed leaf tables), the bottom-up steps run here
// (`k_tree_step[_cl]`), the checkpointed layers (stride max(ZK_K9_CHECKPOINT,
// 2)) stay RESIDENT, the gap layers are freed as soon as the layer above
// exists, and the smallest big layer is downloaded once so the host loop
// builds the small top layers as before. The descent's fused rounds 0/1
// then present `BlkSrc::Device` layers: a resident checkpoint or the compact
// leaves are read IN PLACE, a gap layer is CLIMBED here from the nearest
// resident layer below into the layer buffers (freed after round 1) — no
// per-layer upload, no host layer store. `release_layer(k)` frees the
// resident checkpoint (lane H's top-down discipline; the leaves are never
// released), `Drop` frees the tree. Any CPU reader of a device layer
// (fusion off, a declined hook, the ref/scalar paths, the harness) gets the
// layer materialized on demand (`k9_tree_fetch`: a download, or a climb +
// download) — the same integers, so the same tree on every path. The store's
// bytes count in the VRAM budget and are never released by `release_idle`.
// Knob: ZK_GPU_K9_TREE_STORE=0 (the A/B; the CPU build + L's uploads).

use super::super::eval_proof::{oracle_mode, threads};
use super::super::kfield::{
    BlkSrc, CompactLeaves, DevLayer, DevTreeBuilt, FusedPlan, KElem, KField, KKern, KTab, TreeLeaves, FUSE_EXTRACT, FUSE_EXTRACT_FOLD, FUSE_FOLD, KBLK,
    KL, K9_SMALL_LAYER_N, K_DEG,
};
use super::cuda::{device_handle, env_flag, env_usize, verbose, DevBuf, HostPinned, POOL};
use cudarc::driver::result as cu;
use cudarc::driver::{sys, CudaDevice, CudaFunction, CudaStream, LaunchAsync, LaunchConfig};
use cudarc::nvrtc::{compile_ptx_with_opts, CompileOptions};
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;

const KSRC: &str = include_str!("kernels_k9.cu");
const MODULE: &str = "zkgpu_k9";
const FUNCS: &[&str] = &[
    "k_fold_round",
    "k_extract_round",
    "k_extract_round_cl",
    "k_extract_fold",
    "k_extract_fold_cl",
    "k_fold_table",
    "k_tree_step",
    "k_tree_step_cl",
    "k_ixf_round",
    // [UPERF2-P] one launch per round over a device range table; the eq built on the device.
    "k_fold_round_m",
    "k_extract_round_m",
    "k_extract_round_cl_m",
    "k_extract_fold_m",
    "k_extract_fold_cl_m",
    "k_eq_outer",
    // [UPERF2-P] variant 1 of the fused rounds (the node loop distributed, NN unrolled).
    "k_fold_round_m1",
    "k_extract_round_m1",
    "k_extract_round_cl_m1",
    "k_extract_fold_m1",
    "k_extract_fold_cl_m1",
];

/// [UPERF2-P] The fused-round kernel variant (`ZK_GPU_K9_KVAR`: 0 = lane L's
/// bodies behind the one-launch wrapper — the default; 1 = the distributed
/// node loop with the node count unrolled — MEASURED slower: FOLD 6.9 vs 6.1
/// ms at 2^15 pair-blocks, EXTRACT 19.2 vs 13.7 ms, the extra K-mult per
/// node costs its share and the occupancy stays 8 warps/SM; kept for the
/// record). Every variant computes the same canonical node sums
/// (kernels_k9.cu, the variant's header); the battery compares them.
static KVAR_OVERRIDE: AtomicU64 = AtomicU64::new(u64::MAX);
fn kvar() -> u32 {
    let o = KVAR_OVERRIDE.load(Ordering::Relaxed);
    if o != u64::MAX {
        return o as u32;
    }
    static V: OnceLock<u32> = OnceLock::new();
    *V.get_or_init(|| env_usize("ZK_GPU_K9_KVAR", 0) as u32)
}
/// Harness knob: the kernel variant (None = the env / default).
pub fn k9_set_kvar(v: Option<u32>) {
    KVAR_OVERRIDE.store(v.map(|x| x as u64).unwrap_or(u64::MAX), Ordering::Relaxed);
}
/// The kernel name for a one-launch round: `base` = the variant-0 name
/// (".._m"); variant 1 exists for nn in {3, 5}.
fn kname(base: &'static str, nn: usize) -> &'static str {
    if kvar() == 1 && (nn == 3 || nn == 5) {
        match base {
            "k_fold_round_m" => "k_fold_round_m1",
            "k_extract_round_m" => "k_extract_round_m1",
            "k_extract_round_cl_m" => "k_extract_round_cl_m1",
            "k_extract_fold_m" => "k_extract_fold_m1",
            "k_extract_fold_cl_m" => "k_extract_fold_cl_m1",
            _ => base,
        }
    } else {
        base
    }
}

// [UPERF2-P] One live range's descriptor of a one-launch round (== struct K9R
// in kernels_k9.cu): the five input / output pointers (FOLD; EXTRACT_FOLD
// outputs), or the layer source (packed: in0 = p, in1 = q; compact: in0 =
// words, in1 = alpha, in2 = exceptions) + eq pointer of the extract modes,
// the thread prefix, the parameter slot, the flags.
#[repr(C)]
#[derive(Clone, Copy, Default)]
struct K9Range {
    ins: [u64; 5],
    outs: [u64; 5],
    eq: u64,
    t0: u32,
    n: u32,
    slot: u32,
    flags: u32,
    n_exc: u32,
    e_base: u32,
    pad0: u32,
    pad1: u32,
}
const K9R_HAS_EE: u32 = 1;
/// The range table's device/pinned slot after the parameter slots.
const K9R_BYTES: usize = std::mem::size_of::<K9Range>();

/// [UPERF2-P] Knobs (none changes a value): `ZK_GPU_K9_MULTI=0` -> one launch
/// per live range (lane L's kernels; the one-binary A/B of the one-launch
/// round), `ZK_GPU_K9_EQ_DEV=0` -> the eq b-part built on the host and
/// uploaded (lane L's path), `ZK_GPU_K9_POOL=0` -> no device buffer pool
/// (cuMemAlloc/cuMemFree per tree layer, lane N's path), `ZK_GPU_K9_WARM=1`
/// -> memset every freshly allocated device buffer once (MEASURED a net
/// loss on this box — the fill engine pays the cold pages slower than the
/// kernels' own first touch; default OFF, kept for the record).
fn multi_launch() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("ZK_GPU_K9_MULTI").map(|v| v != "0").unwrap_or(true))
}
fn eq_dev_enabled() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("ZK_GPU_K9_EQ_DEV").map(|v| v != "0").unwrap_or(true))
}
fn pool_enabled() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("ZK_GPU_K9_POOL").map(|v| v != "0").unwrap_or(true))
}
fn warm_enabled() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("ZK_GPU_K9_WARM").map(|v| v == "1").unwrap_or(false))
}
static MULTI_OVERRIDE: AtomicU64 = AtomicU64::new(0); // 0 = env, 1 = on, 2 = off
fn multi() -> bool {
    match MULTI_OVERRIDE.load(Ordering::Relaxed) {
        1 => true,
        2 => false,
        _ => multi_launch(),
    }
}
/// Harness knob: the one-launch round on/off (None = the env / default).
pub fn k9_set_multi(on: Option<bool>) {
    MULTI_OVERRIDE.store(match on { Some(true) => 1, Some(false) => 2, None => 0 }, Ordering::Relaxed);
}
static EQDEV_OVERRIDE: AtomicU64 = AtomicU64::new(0);
fn eq_dev() -> bool {
    match EQDEV_OVERRIDE.load(Ordering::Relaxed) {
        1 => true,
        2 => false,
        _ => eq_dev_enabled(),
    }
}
/// Harness knob: the device eq build on/off (None = the env / default).
pub fn k9_set_eq_dev(on: Option<bool>) {
    EQDEV_OVERRIDE.store(match on { Some(true) => 1, Some(false) => 2, None => 0 }, Ordering::Relaxed);
}

/// [UPERF2-P] Stats of this lane's changes (separate from `K9Stats`).
#[derive(Clone, Debug, Default)]
pub struct K9PStats {
    /// Rounds run as ONE launch over the range table / as one launch per range.
    pub rounds_multi: u64,
    pub rounds_split: u64,
    /// Kernel launches of the fused rounds.
    pub launches: u64,
    /// Device eq builds / binds of a device eq / host materializations of a device eq.
    pub eq_builds: u64,
    pub eq_binds: u64,
    pub eq_host: u64,
    pub secs_eq_build: f64,
    /// Device buffer pool: hits / misses (cuMemAlloc) / buffers trimmed (cuMemFree).
    pub pool_hits: u64,
    pub pool_misses: u64,
    pub pool_trims: u64,
    /// Seconds inside cuMemAlloc / the warming memsets (enqueue side).
    pub secs_alloc: f64,
    /// Inside the tree builds: leaf upload / steps (enqueue) / the top download.
    pub secs_tb_upload: f64,
    pub secs_tb_alloc: f64,
    pub secs_tb_down: f64,
}
static P_ROUNDS_MULTI: AtomicU64 = AtomicU64::new(0);
static P_ROUNDS_SPLIT: AtomicU64 = AtomicU64::new(0);
static P_LAUNCHES: AtomicU64 = AtomicU64::new(0);
static P_EQ_BUILDS: AtomicU64 = AtomicU64::new(0);
static P_EQ_BINDS: AtomicU64 = AtomicU64::new(0);
static P_EQ_HOST: AtomicU64 = AtomicU64::new(0);
static P_EQ_BUILD_US: AtomicU64 = AtomicU64::new(0);
static P_POOL_HITS: AtomicU64 = AtomicU64::new(0);
static P_POOL_MISSES: AtomicU64 = AtomicU64::new(0);
static P_POOL_TRIMS: AtomicU64 = AtomicU64::new(0);
static P_ALLOC_US: AtomicU64 = AtomicU64::new(0);
static P_TB_UPLOAD_US: AtomicU64 = AtomicU64::new(0);
static P_TB_ALLOC_US: AtomicU64 = AtomicU64::new(0);
static P_TB_DOWN_US: AtomicU64 = AtomicU64::new(0);

pub fn k9p_stats() -> K9PStats {
    let us = |s: &AtomicU64| s.load(Ordering::Relaxed) as f64 * 1e-6;
    K9PStats {
        rounds_multi: P_ROUNDS_MULTI.load(Ordering::Relaxed),
        rounds_split: P_ROUNDS_SPLIT.load(Ordering::Relaxed),
        launches: P_LAUNCHES.load(Ordering::Relaxed),
        eq_builds: P_EQ_BUILDS.load(Ordering::Relaxed),
        eq_binds: P_EQ_BINDS.load(Ordering::Relaxed),
        eq_host: P_EQ_HOST.load(Ordering::Relaxed),
        secs_eq_build: us(&P_EQ_BUILD_US),
        pool_hits: P_POOL_HITS.load(Ordering::Relaxed),
        pool_misses: P_POOL_MISSES.load(Ordering::Relaxed),
        pool_trims: P_POOL_TRIMS.load(Ordering::Relaxed),
        secs_alloc: us(&P_ALLOC_US),
        secs_tb_upload: us(&P_TB_UPLOAD_US),
        secs_tb_alloc: us(&P_TB_ALLOC_US),
        secs_tb_down: us(&P_TB_DOWN_US),
    }
}
pub fn k9p_stats_reset() {
    for s in [
        &P_ROUNDS_MULTI, &P_ROUNDS_SPLIT, &P_LAUNCHES, &P_EQ_BUILDS, &P_EQ_BINDS, &P_EQ_HOST, &P_EQ_BUILD_US, &P_POOL_HITS, &P_POOL_MISSES,
        &P_POOL_TRIMS, &P_ALLOC_US, &P_TB_UPLOAD_US, &P_TB_ALLOC_US, &P_TB_DOWN_US,
    ] {
        s.store(0, Ordering::Relaxed);
    }
}
/// Threads per block of the round kernels (== TK9 in kernels_k9.cu).
const TK9: u32 = 64;
/// Threads per block of the elementwise kernels.
const TEL: u32 = 128;
/// Pinned staging per buffer (bytes) for the pipelined uploads / downloads
/// (`ZK_GPU_K9_STG_MB`, default 32; two buffers ping-pong — measured 4..128
/// MB within the box's noise, the DMA runs at 5-9 GB/s either way).
fn stg_bytes() -> usize {
    static V: OnceLock<usize> = OnceLock::new();
    *V.get_or_init(|| env_usize("ZK_GPU_K9_STG_MB", 32).max(1) << 20)
}
/// Largest exception list the compact leaves may carry to the device per
/// instance (the device decode scans it per element).
const CL_MAX_EXC: usize = 1 << 14;

// ---------------------------------------------------------------------------
// Kernel parameters (== struct K9P in kernels_k9.cu): scalars + the device
// pointer of the round's constant vectors (== the PRM_* layout there).

#[repr(C)]
#[derive(Clone, Copy)]
struct K9Params {
    q: u32,
    s: u32,
    c31: u32,
    c32: u32,
    nn: u32,
    has_fc: u32,
    has_nc: u32,
    has_ee: u32,
    kind: u32,
    deg: u32,
    prm: u64,
}

const PRM_NODES: usize = 0;
const PRM_R: usize = 8;
const PRM_LAMBDA: usize = 24;
const PRM_EE: usize = 40;
const PRM_FC: usize = 56;
const PRM_NC: usize = 120;
const PRM_WORDS: usize = 440;
/// Per-range parameter slots per round (extract modes: E(e) differs per range).
const PRM_SLOTS: usize = 64;

impl K9Params {
    fn new(kern: &KKern) -> K9Params {
        K9Params {
            q: kern.q as u32,
            s: kern.s as u32,
            c31: kern.c31 as u32,
            c32: kern.c32 as u32,
            nn: 0,
            has_fc: 0,
            has_nc: 0,
            has_ee: 0,
            kind: 0,
            deg: 0,
            prm: 0,
        }
    }
}

/// The host image of one round's constant vectors.
#[derive(Clone)]
struct Prm([u32; PRM_WORDS]);

impl Prm {
    fn new() -> Prm {
        Prm([0u32; PRM_WORDS])
    }
    fn set_nodes(&mut self, nodes: &[u64]) {
        for (i, &x) in nodes.iter().enumerate() {
            self.0[PRM_NODES + i] = x as u32;
        }
    }
    fn set_vec(&mut self, at: usize, v: &[u32; K_DEG]) {
        self.0[at..at + K_DEG].copy_from_slice(v);
    }
    fn set_fc(&mut self, fc: &[[u32; K_DEG]; 4]) {
        for k in 0..4 {
            self.set_vec(PRM_FC + k * K_DEG, &fc[k]);
        }
    }
    fn set_nc(&mut self, nc: &[[[u32; K_DEG]; 4]]) {
        for (ni, c) in nc.iter().enumerate() {
            for k in 0..4 {
                self.set_vec(PRM_NC + (ni * 4 + k) * K_DEG, &c[k]);
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Knobs / stats

fn k9_requested() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("ZK_GPU_K9").map(|v| v != "0").unwrap_or(true))
}

static MIN_PAIRS_OVERRIDE: AtomicU64 = AtomicU64::new(0);
fn min_pairs() -> usize {
    let o = MIN_PAIRS_OVERRIDE.load(Ordering::Relaxed) as usize;
    if o > 0 {
        return o;
    }
    static V: OnceLock<usize> = OnceLock::new();
    *V.get_or_init(|| env_usize("ZK_GPU_K9_MIN_PAIRS", 32).max(1))
}
/// Harness knob: the minimum round output (pair-blocks) the device takes
/// (0 = the env / default).
pub fn k9_set_min_pairs(p: usize) {
    MIN_PAIRS_OVERRIDE.store(p as u64, Ordering::Relaxed);
}

static EAGER: AtomicBool = AtomicBool::new(false);
fn eager() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    EAGER.load(Ordering::Relaxed) || *V.get_or_init(|| env_flag("ZK_GPU_K9_EAGER"))
}
/// Harness knob: write every descent round's state back to the host (the
/// battery compares tables cell by cell after single calls).
pub fn k9_set_eager(on: bool) {
    EAGER.store(on, Ordering::Relaxed);
}

static WARNED: AtomicBool = AtomicBool::new(false);
static DISABLED: AtomicBool = AtomicBool::new(false);
static COLD_OK: AtomicBool = AtomicBool::new(false);
fn profile() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| env_flag("ZK_GPU_PROFILE"))
}
static TREE_OVERRIDE: AtomicU64 = AtomicU64::new(0); // 0 = env, 1 = on, 2 = off
/// The tree climb on the device: OFF by default (measured: the eager copy
/// of the output layer to the host over PCIe costs what the CPU step
/// costs — U_PERF2_GPU2_REPORT.md Section 4); `ZK_GPU_K9_TREE=1` enables it.
fn tree_enabled() -> bool {
    match TREE_OVERRIDE.load(Ordering::Relaxed) {
        1 => return true,
        2 => return false,
        _ => {}
    }
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| env_flag("ZK_GPU_K9_TREE"))
}
/// Harness knob: the tree climb on the device on/off (None = the env / default).
pub fn k9_set_tree(on: Option<bool>) {
    TREE_OVERRIDE.store(match on { Some(true) => 1, Some(false) => 2, None => 0 }, Ordering::Relaxed);
}
/// Harness knob: let a FUSE_FOLD round that starts without a resident chain
/// upload its input state (the battery drives single rounds; the production
/// path declines such rounds — an upload per round is PCIe-bound).
pub fn k9_set_cold_ok(on: bool) {
    COLD_OK.store(on, Ordering::Relaxed);
}

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
    /// Inside the uploads: host memcpy into pinned staging / waits for the DMA.
    pub secs_up_memcpy: f64,
    pub secs_up_wait: f64,
    // [UPERF2-N] the device tree store.
    /// Trees built on the device / declined (budget, shape).
    pub tree_builds: u64,
    pub tree_declined: u64,
    /// Seconds inside the device builds (leaf upload + steps + the top download).
    pub secs_tree_build: f64,
    /// Bytes of leaves uploaded by the builds.
    pub bytes_tree_leaves: u64,
    /// Fused-round layer bindings that read a resident layer / the compact
    /// leaves IN PLACE (no upload, no climb).
    pub layer_resident: u64,
    /// Gap layers climbed on the device inside the fused-round binding.
    pub dev_climbs: u64,
    pub secs_dev_climb: f64,
    /// Host materializations of device layers (CPU readers; a download or a
    /// climb + download) and their seconds.
    pub tree_fetches: u64,
    pub secs_tree_fetch: f64,
    /// Peak device bytes held by the store / by all K9 buffers.
    pub tree_bytes_peak: u64,
    pub held_peak: u64,
}
static S_ROUNDS: AtomicU64 = AtomicU64::new(0);
static S_DECLINED: AtomicU64 = AtomicU64::new(0);
static S_LAYER_UP: AtomicU64 = AtomicU64::new(0);
static S_LAYER_HIT: AtomicU64 = AtomicU64::new(0);
static S_H2D: AtomicU64 = AtomicU64::new(0);
static S_D2H: AtomicU64 = AtomicU64::new(0);
static S_ROUND_US: AtomicU64 = AtomicU64::new(0);
static S_UPLOAD_US: AtomicU64 = AtomicU64::new(0);
static S_ENCODE_US: AtomicU64 = AtomicU64::new(0);
static S_HANDOVER_US: AtomicU64 = AtomicU64::new(0);
static S_IXF_ROUNDS: AtomicU64 = AtomicU64::new(0);
static S_IXF_FOLDS: AtomicU64 = AtomicU64::new(0);
static S_IXF_HITS: AtomicU64 = AtomicU64::new(0);
static S_IXF_US: AtomicU64 = AtomicU64::new(0);
static S_CLIMBS: AtomicU64 = AtomicU64::new(0);
static S_CLIMB_US: AtomicU64 = AtomicU64::new(0);
static S_CLIMB_D2H_US: AtomicU64 = AtomicU64::new(0);
static S_KERNEL_US: AtomicU64 = AtomicU64::new(0);
static S_UPWAIT_US: AtomicU64 = AtomicU64::new(0);
static S_UPMEMCPY_US: AtomicU64 = AtomicU64::new(0);
// [UPERF2-N]
static S_TREE_BUILDS: AtomicU64 = AtomicU64::new(0);
static S_TREE_DECLINED: AtomicU64 = AtomicU64::new(0);
static S_TREE_BUILD_US: AtomicU64 = AtomicU64::new(0);
static S_TREE_LEAF_BYTES: AtomicU64 = AtomicU64::new(0);
static S_LAYER_RESIDENT: AtomicU64 = AtomicU64::new(0);
static S_DEV_CLIMBS: AtomicU64 = AtomicU64::new(0);
static S_DEV_CLIMB_US: AtomicU64 = AtomicU64::new(0);
static S_TREE_FETCHES: AtomicU64 = AtomicU64::new(0);
static S_TREE_FETCH_US: AtomicU64 = AtomicU64::new(0);
static S_TREE_BYTES_PEAK: AtomicU64 = AtomicU64::new(0);
static S_HELD_PEAK: AtomicU64 = AtomicU64::new(0);

fn add_us(s: &AtomicU64, secs: f64) {
    s.fetch_add((secs * 1e6) as u64, Ordering::Relaxed);
}

fn note_peak(s: &AtomicU64, v: usize) {
    s.fetch_max(v as u64, Ordering::Relaxed);
}

pub fn k9_stats() -> K9Stats {
    let us = |s: &AtomicU64| s.load(Ordering::Relaxed) as f64 * 1e-6;
    K9Stats {
        rounds: S_ROUNDS.load(Ordering::Relaxed),
        declined: S_DECLINED.load(Ordering::Relaxed),
        layer_uploads: S_LAYER_UP.load(Ordering::Relaxed),
        layer_hits: S_LAYER_HIT.load(Ordering::Relaxed),
        bytes_h2d: S_H2D.load(Ordering::Relaxed),
        bytes_d2h: S_D2H.load(Ordering::Relaxed),
        secs_round: us(&S_ROUND_US),
        secs_upload: us(&S_UPLOAD_US),
        secs_encode: us(&S_ENCODE_US),
        secs_handover: us(&S_HANDOVER_US),
        ixf_rounds: S_IXF_ROUNDS.load(Ordering::Relaxed),
        ixf_folds: S_IXF_FOLDS.load(Ordering::Relaxed),
        ixf_hits: S_IXF_HITS.load(Ordering::Relaxed),
        secs_ixf: us(&S_IXF_US),
        climbs: S_CLIMBS.load(Ordering::Relaxed),
        secs_climb: us(&S_CLIMB_US),
        secs_climb_d2h: us(&S_CLIMB_D2H_US),
        secs_kernel: us(&S_KERNEL_US),
        secs_up_memcpy: us(&S_UPMEMCPY_US),
        secs_up_wait: us(&S_UPWAIT_US),
        tree_builds: S_TREE_BUILDS.load(Ordering::Relaxed),
        tree_declined: S_TREE_DECLINED.load(Ordering::Relaxed),
        secs_tree_build: us(&S_TREE_BUILD_US),
        bytes_tree_leaves: S_TREE_LEAF_BYTES.load(Ordering::Relaxed),
        layer_resident: S_LAYER_RESIDENT.load(Ordering::Relaxed),
        dev_climbs: S_DEV_CLIMBS.load(Ordering::Relaxed),
        secs_dev_climb: us(&S_DEV_CLIMB_US),
        tree_fetches: S_TREE_FETCHES.load(Ordering::Relaxed),
        secs_tree_fetch: us(&S_TREE_FETCH_US),
        tree_bytes_peak: S_TREE_BYTES_PEAK.load(Ordering::Relaxed),
        held_peak: S_HELD_PEAK.load(Ordering::Relaxed),
    }
}

pub fn k9_stats_reset() {
    for s in [
        &S_ROUNDS, &S_DECLINED, &S_LAYER_UP, &S_LAYER_HIT, &S_H2D, &S_D2H, &S_ROUND_US, &S_UPLOAD_US, &S_ENCODE_US, &S_HANDOVER_US, &S_IXF_ROUNDS,
        &S_IXF_FOLDS, &S_IXF_HITS, &S_IXF_US, &S_CLIMBS, &S_CLIMB_US, &S_CLIMB_D2H_US, &S_KERNEL_US, &S_UPWAIT_US, &S_UPMEMCPY_US,
        &S_TREE_BUILDS, &S_TREE_DECLINED, &S_TREE_BUILD_US, &S_TREE_LEAF_BYTES, &S_LAYER_RESIDENT, &S_DEV_CLIMBS, &S_DEV_CLIMB_US, &S_TREE_FETCHES,
        &S_TREE_FETCH_US, &S_TREE_BYTES_PEAK, &S_HELD_PEAK,
    ] {
        s.store(0, Ordering::Relaxed);
    }
}

// [UPERF2-N] The device tree store knob: `ZK_GPU_K9_TREE_STORE=0` keeps the
// trees on the host (the CPU build + lane L's per-layer uploads — the A/B);
// `k9_set_tree_store` is the harness override.
static TREE_STORE_OVERRIDE: AtomicU64 = AtomicU64::new(0); // 0 = env, 1 = on, 2 = off
fn tree_store_enabled() -> bool {
    match TREE_STORE_OVERRIDE.load(Ordering::Relaxed) {
        1 => return true,
        2 => return false,
        _ => {}
    }
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("ZK_GPU_K9_TREE_STORE").map(|v| v != "0").unwrap_or(true))
}
/// Harness knob: the device tree store on/off (None = the env / default).
pub fn k9_set_tree_store(on: Option<bool>) {
    TREE_STORE_OVERRIDE.store(match on { Some(true) => 1, Some(false) => 2, None => 0 }, Ordering::Relaxed);
}

// ---------------------------------------------------------------------------
// State

// ---------------------------------------------------------------------------
// [UPERF2-P] THE DEVICE MEMORY: a buddy allocator over fixed-size slabs.
//
// Every K-field buffer of the descents and the tree store — a state table
// of one live range, a climbed layer of one tree, a store checkpoint, the
// compact leaves, the eq table, the climb scratch — is a power-of-two
// number of bytes (per-instance sizes are 2^k elements x 64 B). They are
// carved out of 256 MiB slabs (cuMemAlloc'd once, kept for the process,
// trimmed only when the budget needs it) by a buddy allocator, so that
// bytes change roles — a released checkpoint becomes a climbed layer,
// becomes a state chunk of the next layer, becomes a leaf layer of the
// next pair's trees — WITHOUT a new allocation: measured on this box
// (WSL2), cuMemAlloc of multi-GB buffers costs ~50-100 ms per GB and a
// kernel's first touch of fresh pages runs 2-10x slower (lane L's finding);
// with the slabs both are paid once per process. States are laid out per
// PIECE (a live range, split at 2^16 pair-blocks = 64 MiB per table): the
// one-launch round's range table carries the pieces' pointers, so nothing
// needs to be contiguous across ranges. `ZK_GPU_K9_SLAB_MB=0` = one
// cuMemAlloc per chunk (the A/B; lane N's allocation pattern).

const SLAB_MIN_BITS: u32 = 16; // 64 KiB granularity
/// Largest piece of a state (pair-blocks): 2^16 pair-blocks = 2^17 blocks x
/// 512 B = 64 MiB per table.
const MAX_PIECE_PAIRS: usize = 1 << 16;

fn slab_bits() -> u32 {
    static V: OnceLock<u32> = OnceLock::new();
    *V.get_or_init(|| {
        let mb = env_usize("ZK_GPU_K9_SLAB_MB", 256);
        if mb == 0 { 0 } else { (mb << 20).next_power_of_two().trailing_zeros().max(SLAB_MIN_BITS + 1) }
    })
}

/// A device allocation handed out by the buddy (or a dedicated buffer).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Chunk {
    ptr: u64,
    bytes: usize,
}
impl Chunk {
    const NONE: Chunk = Chunk { ptr: 0, bytes: 0 };
    fn is_none(&self) -> bool {
        self.bytes == 0
    }
}

struct Buddy {
    /// 0 = no slabs (every chunk a dedicated cuMemAlloc).
    slab_bits: u32,
    slabs: Vec<DevBuf>,
    /// Free blocks by level (level l = 2^(SLAB_MIN_BITS + l) bytes): their addresses.
    free: Vec<std::collections::BTreeSet<u64>>,
    /// Dedicated buffers (requests above a slab, or slab_bits == 0), by address.
    dedicated: std::collections::HashMap<u64, DevBuf>,
    /// Bytes handed out (chunks) / bytes allocated from the driver (slabs + dedicated).
    live: usize,
    total: usize,
}

impl Buddy {
    fn new(slab_bits: u32) -> Buddy {
        let levels = if slab_bits == 0 { 0 } else { (slab_bits - SLAB_MIN_BITS + 1) as usize };
        Buddy { slab_bits, slabs: Vec::new(), free: (0..levels).map(|_| std::collections::BTreeSet::new()).collect(), dedicated: std::collections::HashMap::new(), live: 0, total: 0 }
    }
    /// The level of a request (its size rounded up to a power of two >= 64 KiB).
    fn level_of(bytes: usize) -> u32 {
        let b = bytes.max(1usize << SLAB_MIN_BITS).next_power_of_two();
        b.trailing_zeros() - SLAB_MIN_BITS
    }
    fn size_of_level(l: u32) -> usize {
        1usize << (SLAB_MIN_BITS + l)
    }
    /// Does the request fit a slab?
    fn slab_fits(&self, bytes: usize) -> bool {
        self.slab_bits > 0 && Self::level_of(bytes) + SLAB_MIN_BITS <= self.slab_bits
    }
    /// The base of the slab containing `addr`.
    fn slab_base(&self, addr: u64) -> u64 {
        let sz = 1u64 << self.slab_bits;
        for s in &self.slabs {
            if addr >= s.ptr && addr < s.ptr + sz {
                return s.ptr;
            }
        }
        panic!("[UPERF2-P] k9 buddy: address {addr:#x} is in no slab");
    }
    /// A block from the free lists (splitting a bigger one), or None.
    fn try_alloc(&mut self, bytes: usize) -> Option<Chunk> {
        if !self.slab_fits(bytes) {
            return None;
        }
        let l = Self::level_of(bytes);
        let mut lv = l;
        while (lv as usize) < self.free.len() && self.free[lv as usize].is_empty() {
            lv += 1;
        }
        if lv as usize >= self.free.len() {
            return None;
        }
        let addr = *self.free[lv as usize].iter().next().unwrap();
        self.free[lv as usize].remove(&addr);
        // Split down to l: the upper halves go back as free blocks.
        while lv > l {
            lv -= 1;
            let half = Self::size_of_level(lv) as u64;
            self.free[lv as usize].insert(addr + half);
        }
        let bytes = Self::size_of_level(l);
        self.live += bytes;
        Some(Chunk { ptr: addr, bytes })
    }
    /// Give a chunk back (merging with its buddy while that is free).
    fn free(&mut self, c: Chunk) {
        if c.is_none() {
            return;
        }
        if let Some(mut b) = self.dedicated.remove(&c.ptr) {
            self.total -= b.bytes;
            self.live -= c.bytes;
            b.free();
            return;
        }
        let base = self.slab_base(c.ptr);
        let mut l = Self::level_of(c.bytes);
        let mut addr = c.ptr;
        let top = self.free.len() as u32 - 1;
        while l < top {
            let size = Self::size_of_level(l) as u64;
            let rel = addr - base;
            let buddy = base + (rel ^ size);
            if self.free[l as usize].remove(&buddy) {
                addr = addr.min(buddy);
                l += 1;
            } else {
                break;
            }
        }
        self.free[l as usize].insert(addr);
        self.live -= c.bytes;
    }
    /// A fresh slab (cuMemAlloc'd by the caller) joins the free list whole.
    fn add_slab(&mut self, b: DevBuf) {
        let top = self.free.len() - 1;
        self.free[top].insert(b.ptr);
        self.total += b.bytes;
        self.slabs.push(b);
    }
    /// A dedicated buffer (above the slab size, or without slabs).
    fn add_dedicated(&mut self, b: DevBuf) -> Chunk {
        let c = Chunk { ptr: b.ptr, bytes: b.bytes };
        self.total += b.bytes;
        self.live += b.bytes;
        self.dedicated.insert(b.ptr, b);
        c
    }
    /// Free the slabs that are entirely free; returns the bytes given back.
    fn trim_free_slabs(&mut self) -> usize {
        if self.slab_bits == 0 {
            return 0;
        }
        let top = self.free.len() - 1;
        let mut freed = 0usize;
        let mut i = 0;
        while i < self.slabs.len() {
            let ptr = self.slabs[i].ptr;
            if self.free[top].remove(&ptr) {
                let mut b = self.slabs.swap_remove(i);
                freed += b.bytes;
                self.total -= b.bytes;
                b.free();
            } else {
                i += 1;
            }
        }
        freed
    }
    fn slab_bytes(&self) -> usize {
        1usize << self.slab_bits
    }
}

/// One piece of a device-resident state: the pair-blocks [a, b) of the
/// state (within one live range), the five tables' chunks (2 (b - a) blocks
/// each), and the range it belongs to.
#[derive(Clone, Copy, Debug)]
struct Piece {
    a: usize,
    b: usize,
    ri: usize,
    ch: [Chunk; 5],
}

/// The descent chain: state t of one layer, device-resident.
struct Chain {
    /// The host buffers (eq, pl, p1, q0, q1) the state belongs to.
    ptrs: [usize; 5],
    /// State-t pair-blocks per table (== the successor's 2 x n_pairs).
    out_pairs: usize,
    /// The live pair-block ranges of state t.
    ranges: Vec<(usize, usize)>,
    /// The device layout: the pieces (in order, partitioning the ranges).
    pieces: Vec<Piece>,
}

/// Split the live ranges into pieces of at most MAX_PIECE_PAIRS pair-blocks
/// (chunks not yet allocated).
fn pieces_of(ranges: &[(usize, usize)]) -> Vec<Piece> {
    let mut v = Vec::new();
    for (ri, &(a, b)) in ranges.iter().enumerate() {
        let mut x = a;
        while x < b {
            let y = (x + MAX_PIECE_PAIRS).min(b);
            v.push(Piece { a: x, b: y, ri, ch: [Chunk::NONE; 5] });
            x = y;
        }
    }
    v
}

/// The device address of table k at pair-block `x` of a state (x within a piece).
fn piece_ptr(p: &Piece, k: usize, x: usize) -> u64 {
    debug_assert!(x >= p.a && x <= p.b);
    p.ch[k].ptr + (2 * (x - p.a) * KBLK * 4) as u64
}

/// One instance's layer on the device (round 0 -> round 1): absolute device
/// pointers of the instance's layer block 0 (an upload into the layer
/// buffers, a device climb into them, or — [UPERF2-N] — a resident layer /
/// the compact leaves of the tree store read in place).
enum LayerDev {
    Packed { p: u64, q: u64 },
    /// `meta` = alpha[16] then n_exc x (idx, p[16], q[16]).
    Compact { w: u64, meta: u64, n_exc: usize },
}

/// The identity of an instance's layer as the plan presents it.
#[derive(Clone, PartialEq, Eq, Debug)]
enum LayerId {
    Packed { p: usize, q: usize, p_len: usize, q_len: usize },
    Compact { c: usize, n: usize },
    /// [UPERF2-N] a device tree's layer.
    Device { tree: u64, k: usize },
}

/// [UPERF2-N] One tree of the device store.
struct DevTree {
    depth: usize,
    /// The bulk kernel context (the K9P scalars of its steps).
    kern: KKern,
    /// Resident packed layers (p, q) by index — the checkpoints among the
    /// big layers, and the packed leaves at `depth` when not compact.
    /// [UPERF2-P] chunks of the buddy.
    layers: Vec<Option<(Chunk, Chunk)>>,
    /// The compact leaves: (words: 2 per leaf, meta: alpha[16] + the
    /// exceptions x 33 words, n_exc).
    compact: Option<(Chunk, Chunk, usize)>,
    /// Device bytes held by this tree.
    bytes: usize,
}

struct LayerRes {
    /// The plan of the round that produced it (round 0), for the round-1 check.
    n_pairs: usize,
    ranges: Vec<(usize, usize)>,
    ids: Vec<(LayerId, usize)>, // (id, first_pair)
    devs: Vec<LayerDev>,
    /// The eq table (ptr, len).
    eq: (usize, usize),
    /// [UPERF2-P] The device address of the eq's element 0 (the resident
    /// device eq, or the uploaded host words).
    eq_up: u64,
    /// [UPERF2-P] The chunks this binding owns (uploaded packed layers,
    /// compact words + meta, climbed layers, the climb scratch): freed when
    /// the binding is dropped (after round 1, or on a re-bind).
    owned: Vec<Chunk>,
}

/// [UPERF2-P] The resident device eq b-part: its id, elements, chunk.
struct EqRes {
    id: u64,
    n: usize,
    ch: Chunk,
}

/// The ixf chain (fold.rs): the tables' host pointers at the last round,
/// the resident buffers, and the expected next call.
struct IxfChain {
    kind: u8,
    nt: usize,
    /// Host pointers of the tables as seen at the round (per table).
    ptrs: Vec<usize>,
    /// Elements per table at the round.
    n: usize,
    /// Which ping-pong buffer holds each table.
    buf: Vec<usize>,
    /// Folds seen since the round (in order); after nt folds the next
    /// round(t+1) is expected with n/2 elements.
    folded: usize,
    /// The scratch pointers the folds handed the tables (the expected
    /// pointers at round t+1; informational — the sequence decides).
    next_ptrs: Vec<usize>,
    /// True once a fold left its output device-only (the host copy is
    /// stale until the handover).
    lazy: bool,
}

struct K9 {
    dev: Arc<CudaDevice>,
    sk: CudaStream,
    sc: CudaStream,
    ev: [sys::CUevent; 2],
    f: std::collections::HashMap<&'static str, CudaFunction>,
    stg: [HostPinned; 2],
    // Descent. [UPERF2-P] the state / layer / eq buffers are chunks of `mem`
    // owned by the chain / the layer binding / the eq (below).
    partial: DevBuf,
    partial_h: HostPinned,
    prm_d: DevBuf,
    prm_h: HostPinned,
    chain: Option<Chain>,
    layer: Option<LayerRes>,
    // Ixf.
    ixf_t: Vec<[DevBuf; 2]>,
    ixf: Option<IxfChain>,
    // Tree (lane L's device climb, off by default).
    tree_src: [DevBuf; 2],
    tree_out: [DevBuf; 2],
    // [UPERF2-N] The device tree store.
    trees: std::collections::HashMap<u64, DevTree>,
    next_tree: u64,
    tree_bytes: usize,
    // Budget: `held` = the dedicated DevBufs above (partial, prm, ixf, tree
    // src/out); the slabs are `mem.total`; `used()` is their sum.
    budget: usize,
    held: usize,
    last_kernel_ms: f64,
    // [UPERF2-P] The buddy allocator (slabs), the resident device eq, the eq ids.
    mem: Buddy,
    eq: Option<EqRes>,
    next_eq: u64,
}

unsafe impl Send for K9 {}

static K9S: OnceLock<Option<Mutex<K9>>> = OnceLock::new();
static INIT_ERR: Mutex<Option<String>> = Mutex::new(None);

fn arch_str(cc: (i32, i32)) -> Option<&'static str> {
    Some(match cc {
        (7, 0) => "compute_70",
        (7, 5) => "compute_75",
        (8, 0) => "compute_80",
        (8, 6) => "compute_86",
        (8, 9) => "compute_89",
        (9, 0) => "compute_90",
        _ => return None,
    })
}

fn init_k9() -> Result<K9, String> {
    let dev = device_handle().ok_or_else(|| "no device".to_string())?;
    dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
    let major = dev.attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR).map_err(|e| e.to_string())?;
    let minor = dev.attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR).map_err(|e| e.to_string())?;
    let t0 = Instant::now();
    // The PTX is cached on disk keyed by (source, options, arch): the
    // NVRTC compile of these kernels takes seconds; the driver's own JIT
    // cache (~/.nv/ComputeCache) covers the PTX -> SASS step.
    let arch = arch_str((major, minor));
    let opts_str = format!("-DTK9={TK9}|{}", arch.unwrap_or("generic"));
    let cache_path = {
        use sha2::Digest;
        let mut h = sha2::Sha256::new();
        h.update(KSRC.as_bytes());
        h.update(opts_str.as_bytes());
        let d: [u8; 32] = h.finalize().into();
        let hex: String = d.iter().take(16).map(|b| format!("{b:02x}")).collect();
        let base = std::env::var("XDG_CACHE_HOME").ok().map(std::path::PathBuf::from).or_else(|| std::env::var("HOME").ok().map(|h| std::path::PathBuf::from(h).join(".cache")));
        base.map(|b| b.join("zkmatrix-gpu").join(format!("k9-{hex}.ptx")))
    };
    let cached: Option<String> = cache_path.as_ref().and_then(|p| std::fs::read_to_string(p).ok()).filter(|s| !s.is_empty());
    let ptx = match cached {
        Some(src) => cudarc::nvrtc::Ptx::from_src(src),
        None => {
            let compile = |arch: Option<&'static str>| {
                let opts = CompileOptions { arch, options: vec![format!("-DTK9={TK9}")], ..Default::default() };
                compile_ptx_with_opts(KSRC, opts)
            };
            let ptx = match compile(arch) {
                Ok(p) => p,
                Err(e1) => match compile(None) {
                    Ok(p) => p,
                    Err(e2) => return Err(format!("NVRTC compile (k9) failed: {e1}; generic retry: {e2}")),
                },
            };
            if let Some(p) = &cache_path {
                if let Some(dir) = p.parent() {
                    let _ = std::fs::create_dir_all(dir);
                }
                let _ = std::fs::write(p, ptx.to_src());
            }
            ptx
        }
    };
    let secs_ptx = t0.elapsed().as_secs_f64();
    let t1 = Instant::now();
    dev.load_ptx(ptx, MODULE, FUNCS).map_err(|e| format!("cuModuleLoadData (k9): {e}"))?;
    let secs_load = t1.elapsed().as_secs_f64();
    let mut f = std::collections::HashMap::new();
    for &name in FUNCS {
        f.insert(name, dev.get_func(MODULE, name).ok_or_else(|| format!("{name} missing"))?);
    }
    let sk = dev.fork_default_stream().map_err(|e| format!("k9 compute stream: {e}"))?;
    let sc = dev.fork_default_stream().map_err(|e| format!("k9 copy stream: {e}"))?;
    let mk_ev = || cu::event::create(sys::CUevent_flags::CU_EVENT_DISABLE_TIMING).map_err(|e| format!("cuEventCreate: {e}"));
    let ev = [mk_ev()?, mk_ev()?];
    let mut stg = [HostPinned::empty(), HostPinned::empty()];
    for s in stg.iter_mut() {
        s.grow(stg_bytes())?;
    }
    let mut partial = DevBuf::empty();
    partial.grow(5 * 16 * 8)?;
    let mut partial_h = HostPinned::empty();
    partial_h.grow(5 * 16 * 8)?;
    // [UPERF2-P] the parameter slots + the range table of a one-launch round
    // share one pinned/device pair (one copy per round).
    let mut prm_d = DevBuf::empty();
    prm_d.grow(PRM_SLOTS * PRM_WORDS * 4 + PRM_SLOTS * K9R_BYTES)?;
    let mut prm_h = HostPinned::empty();
    prm_h.grow(PRM_SLOTS * PRM_WORDS * 4 + PRM_SLOTS * K9R_BYTES)?;
    let (free, total) = cu::mem_get_info().map_err(|e| format!("cuMemGetInfo: {e}"))?;
    let budget = {
        let mb = env_usize("ZK_GPU_K9_BUDGET_MB", 0);
        if mb > 0 { mb << 20 } else { free.saturating_sub(256 << 20) }
    };
    if verbose() {
        eprintln!(
            "[UPERF2-L] k9 init: PTX (NVRTC or the disk cache) {secs_ptx:.2}s + module load (driver JIT or its cache) {secs_load:.2}s + setup {:.2}s; VRAM free {:.2} / {:.2} GB; K9 budget {:.2} GB; min_pairs {}",
            t0.elapsed().as_secs_f64() - secs_ptx - secs_load,
            free as f64 / 1e9,
            total as f64 / 1e9,
            budget as f64 / 1e9,
            min_pairs()
        );
        let occ: Vec<String> = FUNCS
            .iter()
            .map(|name| {
                let b = f.get(name).map(|fun| fun.occupancy_max_active_blocks_per_multiprocessor(TK9, 0, None).unwrap_or(0)).unwrap_or(0);
                format!("{name}: {b} blk/SM ({} warps)", b * TK9 / 32)
            })
            .collect();
        eprintln!("[UPERF2-L] k9 occupancy at {TK9} threads/block: {}", occ.join("; "));
    }
    Ok(K9 {
        dev,
        sk,
        sc,
        ev,
        f,
        stg,
        partial,
        partial_h,
        prm_d,
        prm_h,
        chain: None,
        layer: None,
        ixf_t: Vec::new(),
        ixf: None,
        tree_src: [DevBuf::empty(), DevBuf::empty()],
        tree_out: [DevBuf::empty(), DevBuf::empty()],
        trees: std::collections::HashMap::new(),
        next_tree: 1,
        tree_bytes: 0,
        budget,
        held: 0,
        last_kernel_ms: 0.0,
        mem: Buddy::new(slab_bits()),
        eq: None,
        next_eq: 1,
    })
}

fn k9s() -> Option<&'static Mutex<K9>> {
    K9S.get_or_init(|| match init_k9() {
        Ok(k) => Some(Mutex::new(k)),
        Err(e) => {
            *INIT_ERR.lock().unwrap() = Some(e);
            None
        }
    })
    .as_ref()
}

/// Live iff lane K's `enabled()` (feature, ZK_GPU=1, device) AND
/// ZK_GPU_K9 != 0 AND not permanently disabled by an earlier device error
/// AND not under `oracle_mode()`.
fn live() -> bool {
    super::cuda::enabled() && k9_requested() && !DISABLED.load(Ordering::Relaxed) && !oracle_mode()
}

/// The human-readable state for the harness.
pub fn k9_label() -> String {
    if !super::cuda::enabled() {
        return format!("k9: off ({})", super::cuda::label());
    }
    if !k9_requested() {
        return "k9: off (ZK_GPU_K9=0)".to_string();
    }
    match k9s() {
        Some(k) => {
            let k = k.lock().unwrap();
            format!(
                "k9: on — K-field kernels on the device (budget {:.2} GB, used {:.2} GB, min_pairs {}, eager {}; tree store {} — {} trees, {:.2} GB)",
                k.budget as f64 / 1e9,
                k.used() as f64 / 1e9,
                min_pairs(),
                eager(),
                if tree_store_enabled() { "on" } else { "off" },
                k.trees.len(),
                k.tree_bytes as f64 / 1e9
            )
        }
        None => format!("k9: FAILED to initialize ({})", INIT_ERR.lock().unwrap().clone().unwrap_or_default()),
    }
}

/// [UPERF3-WW] round 11, rung 1 (ADDITIVE) — give back this module's IDLE
/// device residency at a phase boundary the caller chooses: the idle
/// families (the ixf tables with no chain alive, the climb buffers) and
/// the wholly free slabs — exactly `make_room`'s own rule (a live chain,
/// the layer binding, the eq and the tree store are never taken). WHY:
/// the budget is fixed at init (free VRAM - 256 MB) and the slabs are
/// kept for the process, so after a descent phase this module can sit on
/// several GB of idle slabs that the modules budgeting against the LIVE
/// free VRAM (ixf, zc) then cannot see — MEASURED 2026-09-02 at 12x512:
/// 3.76 GB idle after the Stage-A leg's silu descents left the
/// in-process oracle leg's claim layer at "free 3.65 GB", the ixf module
/// declined its 4.06 GB tables and the CPU-built tables went through
/// this module's upload path (the crash above). The Stage-A driver calls
/// this after its aggregate phase. Returns the bytes given back; 0 when
/// the module is not live.
pub fn k9_trim_idle() -> usize {
    if !live() {
        return 0;
    }
    let Some(kk) = k9s() else { return 0 };
    let mut k = kk.lock().unwrap();
    if k.chain.is_some() {
        return 0;
    }
    let before = k.used();
    let _ = k.dev.bind_to_thread();
    let b = k.budget;
    k.make_room(b);
    before.saturating_sub(k.used())
}

/// [UPERF2-L] Protocol assertion for lane K's bypass switch: no descent
/// chain may hold device-resident host state when the hooks stop firing.
pub(super) fn assert_no_chain(what: &str) {
    if let Some(Some(k)) = K9S.get() {
        if let Ok(k) = k.try_lock() {
            assert!(k.chain.is_none(), "[UPERF2-L] {what} while a K-field descent chain is device-resident (protocol violation)");
        }
    }
}

// ---------------------------------------------------------------------------
// Device helpers

impl K9 {
    fn sync_all(&self) -> Result<(), String> {
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk: {e}"))?;
        unsafe { cu::stream::synchronize(self.sc.stream) }.map_err(|e| format!("sync sc: {e}"))?;
        Ok(())
    }

    /// The device bytes in use: the dedicated buffers + the slabs.
    fn used(&self) -> usize {
        self.held + self.mem.total
    }

    /// Grow one of the remaining dedicated buffers (lane L's ixf tables and
    /// device-climb buffers) within the budget (synchronizes first when it
    /// must reallocate); when the budget is short the idle families go back
    /// first.
    fn grow_dev(&mut self, which: DevSel, bytes: usize) -> Result<(), String> {
        let cur = self.sel(which).bytes;
        if bytes <= cur {
            return Ok(());
        }
        let need = bytes - cur;
        if self.used() + need > self.budget {
            self.make_room(need);
        }
        if self.used() + need > self.budget {
            return Err(format!(
                "K9 VRAM budget: need {:.2} GB more (used {:.2} GB, budget {:.2} GB)",
                need as f64 / 1e9,
                self.used() as f64 / 1e9,
                self.budget as f64 / 1e9
            ));
        }
        self.sync_all()?;
        let ta = Instant::now();
        let b = self.sel(which);
        let old = b.bytes;
        b.grow(bytes)?;
        let new = b.bytes;
        self.held = self.held + new - old;
        note_peak(&S_HELD_PEAK, self.used());
        add_us(&P_ALLOC_US, ta.elapsed().as_secs_f64());
        Ok(())
    }

    /// [UPERF2-P] A chunk of device memory (a power of two >= 64 KiB) from
    /// the buddy: a free block, else a fresh slab within the budget, else
    /// after the idle families are given back; `Err("K9 VRAM budget ..")`
    /// when nothing fits (the callers decline — never a value change).
    fn alloc(&mut self, bytes: usize) -> Result<Chunk, String> {
        if let Some(c) = self.mem.try_alloc(bytes) {
            P_POOL_HITS.fetch_add(1, Ordering::Relaxed);
            return Ok(c);
        }
        // A new slab (or a dedicated buffer when the request exceeds a slab
        // / no slabs are configured).
        let want = if self.mem.slab_fits(bytes) { self.mem.slab_bytes() } else { bytes.max(1usize << SLAB_MIN_BITS).next_power_of_two() };
        if self.used() + want > self.budget {
            self.make_room(want);
            // The idle families may have returned chunks: try again first.
            if let Some(c) = self.mem.try_alloc(bytes) {
                return Ok(c);
            }
        }
        if self.used() + want > self.budget {
            return Err(format!(
                "K9 VRAM budget: need {:.2} GB more (used {:.2} GB of which slabs {:.2}, live {:.2}; budget {:.2} GB)",
                want as f64 / 1e9,
                self.used() as f64 / 1e9,
                self.mem.total as f64 / 1e9,
                self.mem.live as f64 / 1e9,
                self.budget as f64 / 1e9
            ));
        }
        let ta = Instant::now();
        let mut b = DevBuf::empty();
        b.grow(want)?;
        P_POOL_MISSES.fetch_add(1, Ordering::Relaxed);
        let c = if self.mem.slab_fits(bytes) {
            self.mem.add_slab(b);
            self.mem.try_alloc(bytes).expect("a fresh slab satisfies the request")
        } else {
            self.mem.add_dedicated(b)
        };
        if warm_enabled() {
            self.warm(c.ptr, c.bytes)?;
        }
        add_us(&P_ALLOC_US, ta.elapsed().as_secs_f64());
        note_peak(&S_HELD_PEAK, self.used());
        Ok(c)
    }

    /// Give a chunk back to the buddy (the caller has synchronized the
    /// streams that could still touch it — every round ends with a sync).
    fn free(&mut self, c: Chunk) {
        if !c.is_none() {
            self.mem.free(c);
        }
    }

    /// Free the idle families' dedicated buffers and the free slabs so that
    /// `bytes` more may be allocated: lane L's ixf tables (no ixf chain
    /// alive), the device-climb buffers, then the wholly free slabs. The
    /// descent's chain / layer binding / eq and the tree store are never
    /// taken here.
    fn make_room(&mut self, bytes: usize) {
        let _ = self.sync_all();
        let mut freed = 0usize;
        if self.ixf.is_none() {
            for t in self.ixf_t.iter_mut() {
                freed += t[0].bytes + t[1].bytes;
                t[0].free();
                t[1].free();
            }
        }
        for b in self.tree_src.iter_mut().chain(self.tree_out.iter_mut()) {
            freed += b.bytes;
            b.free();
        }
        self.held -= freed;
        if self.used() + bytes > self.budget {
            let t = self.mem.trim_free_slabs();
            if t > 0 {
                P_POOL_TRIMS.fetch_add(1, Ordering::Relaxed);
            }
            freed += t;
        }
        if verbose() && freed > 0 {
            eprintln!("[UPERF2-P] k9: gave back {:.2} GB of idle device buffers / free slabs", freed as f64 / 1e9);
        }
    }

    /// [UPERF2-P] Touch a freshly allocated device buffer once (a memset on
    /// the compute stream, synchronous): MEASURED a net loss on this box —
    /// off by default (`ZK_GPU_K9_WARM=1`).
    fn warm(&self, ptr: sys::CUdeviceptr, bytes: usize) -> Result<(), String> {
        if bytes == 0 || ptr == 0 {
            return Ok(());
        }
        unsafe { cu::memset_d8_async(ptr, 0, bytes, self.sk.stream) }.map_err(|e| format!("memset (warm): {e}"))?;
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk (warm): {e}"))
    }

    /// The layer binding is consumed (round 1 ran, or a re-bind): its chunks
    /// go back to the buddy (after a sync — the kernels that read them are
    /// done at every round's end; the climb scratch too).
    fn release_layer_bufs(&mut self) {
        if let Some(l) = self.layer.take() {
            let _ = self.sync_all();
            for c in l.owned {
                self.free(c);
            }
        }
    }

    /// Drop the chain's state chunks (the chain ended or aborted).
    fn release_chain(&mut self) {
        if let Some(ch) = self.chain.take() {
            let _ = self.sync_all();
            for p in ch.pieces {
                for c in p.ch {
                    self.free(c);
                }
            }
        }
    }

    /// Drop the resident device eq (its handle is gone or superseded).
    fn release_eq(&mut self) {
        if let Some(e) = self.eq.take() {
            let _ = self.sync_all();
            self.free(e.ch);
        }
    }

    fn sel(&mut self, which: DevSel) -> &mut DevBuf {
        match which {
            DevSel::Ixf(k, i) => {
                while self.ixf_t.len() <= k {
                    self.ixf_t.push([DevBuf::empty(), DevBuf::empty()]);
                }
                &mut self.ixf_t[k][i]
            }
            DevSel::TreeSrc(i) => &mut self.tree_src[i],
            DevSel::TreeOut(i) => &mut self.tree_out[i],
        }
    }

    /// The device error path: every K-field chain buffer goes back and the
    /// chains are dropped. [UPERF2-N] the TREE STORE STAYS — its layers are
    /// the only copy of the big layers of the trees the host still holds,
    /// and `k9_tree_fetch` (a plain download) must keep answering.
    fn release_all(&mut self) {
        let _ = self.sync_all();
        self.release_chain();
        self.release_layer_bufs();
        self.release_eq();
        for t in self.ixf_t.iter_mut() {
            t[0].free();
            t[1].free();
        }
        for b in self.tree_src.iter_mut().chain(self.tree_out.iter_mut()) {
            b.free();
        }
        self.held = 0;
        self.ixf = None;
        let _ = self.mem.trim_free_slabs();
    }

    /// Upload `src` (host words) to device address `dst` through the pinned
    /// staging ring on the copy stream (parallel memcpy into pinned, async
    /// DMA; the two buffers ping-pong on events). Returns after the LAST
    /// chunk's DMA has been ENQUEUED (not completed): the caller records /
    /// waits on the copy stream before reading on the compute stream.
    fn upload_words(&mut self, dst: sys::CUdeviceptr, src: &[u32], pp: &mut usize) -> Result<(), String> {
        let per = stg_bytes() / 4;
        let mut off = 0usize;
        while off < src.len() {
            let n = per.min(src.len() - off);
            let i = *pp & 1;
            let tw = Instant::now();
            unsafe { cu::event::synchronize(self.ev[i]) }.map_err(|e| format!("event sync: {e}"))?;
            add_us(&S_UPWAIT_US, tw.elapsed().as_secs_f64());
            let tm = Instant::now();
            {
                let dstw = self.stg[i].slice_mut::<u32>(n);
                let s = &src[off..off + n];
                if threads() > 1 && n >= (1 << 20) && !in_rayon_worker() {
                    POOL.install(|| {
                        use rayon::prelude::*;
                        dstw.par_chunks_mut(1 << 18).zip(s.par_chunks(1 << 18)).for_each(|(d, s)| d.copy_from_slice(s));
                    });
                } else {
                    dstw.copy_from_slice(s);
                }
            }
            add_us(&S_UPMEMCPY_US, tm.elapsed().as_secs_f64());
            unsafe { cu::memcpy_htod_async(dst + (off * 4) as u64, self.stg[i].slice::<u32>(n), self.sc.stream) }
                .map_err(|e| format!("h2d: {e}"))?;
            unsafe { cu::event::record(self.ev[i], self.sc.stream) }.map_err(|e| format!("record: {e}"))?;
            S_H2D.fetch_add((n * 4) as u64, Ordering::Relaxed);
            off += n;
            *pp += 1;
        }
        Ok(())
    }

    /// Make the compute stream wait for everything enqueued on the copy stream.
    fn compute_after_copies(&mut self) -> Result<(), String> {
        let ev = self.ev[0];
        // Record a fresh marker on sc and wait on sk (ev[0] is reused; the
        // staging protocol only needs "the DMA that last read staging[i]").
        unsafe { cu::event::record(ev, self.sc.stream) }.map_err(|e| format!("record: {e}"))?;
        unsafe { cu::stream::wait_event(self.sk.stream, ev, sys::CUevent_wait_flags::CU_EVENT_WAIT_DEFAULT) }
            .map_err(|e| format!("wait: {e}"))?;
        Ok(())
    }

    /// Download `words` u32 from device address `src` into `dst` (host,
    /// pageable) synchronously through the pinned staging (parallel copy
    /// out of pinned).
    fn download_words(&mut self, src: sys::CUdeviceptr, dst: &mut [u32]) -> Result<(), String> {
        let per = stg_bytes() / 4;
        let mut off = 0usize;
        // Everything the compute stream produced must be complete.
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk: {e}"))?;
        let mut pp = 0usize;
        // Pipeline: DMA chunk i+1 while copying chunk i out of pinned.
        let n_chunks = dst.len().div_ceil(per);
        // Enqueue chunk 0.
        if n_chunks > 0 {
            let n0 = per.min(dst.len());
            unsafe { cu::event::synchronize(self.ev[0]) }.map_err(|e| format!("event sync: {e}"))?;
            unsafe { cu::event::synchronize(self.ev[1]) }.map_err(|e| format!("event sync: {e}"))?;
            unsafe { cu::memcpy_dtoh_async(self.stg[0].slice_mut::<u32>(n0), src, self.sc.stream) }.map_err(|e| format!("d2h: {e}"))?;
            unsafe { cu::event::record(self.ev[0], self.sc.stream) }.map_err(|e| format!("record: {e}"))?;
        }
        while off < dst.len() {
            let n = per.min(dst.len() - off);
            let i = pp & 1;
            // Enqueue the next chunk into the other buffer.
            let next_off = off + n;
            if next_off < dst.len() {
                let nn = per.min(dst.len() - next_off);
                let j = i ^ 1;
                unsafe { cu::memcpy_dtoh_async(self.stg[j].slice_mut::<u32>(nn), src + (next_off * 4) as u64, self.sc.stream) }
                    .map_err(|e| format!("d2h: {e}"))?;
                unsafe { cu::event::record(self.ev[j], self.sc.stream) }.map_err(|e| format!("record: {e}"))?;
            }
            unsafe { cu::event::synchronize(self.ev[i]) }.map_err(|e| format!("event sync: {e}"))?;
            {
                let s = self.stg[i].slice::<u32>(n);
                let d = &mut dst[off..off + n];
                if threads() > 1 && n >= (1 << 20) && !in_rayon_worker() {
                    POOL.install(|| {
                        use rayon::prelude::*;
                        d.par_chunks_mut(1 << 18).zip(s.par_chunks(1 << 18)).for_each(|(d, s)| d.copy_from_slice(s));
                    });
                } else {
                    d.copy_from_slice(s);
                }
            }
            S_D2H.fetch_add((n * 4) as u64, Ordering::Relaxed);
            off = next_off;
            pp += 1;
        }
        Ok(())
    }

    fn launch(&self, name: &str, grid: u32, block: u32, args: &mut [*mut c_void]) -> Result<(), String> {
        let f = self.f.get(name).ok_or_else(|| format!("{name} missing"))?.clone();
        let cfg = LaunchConfig { grid_dim: (grid.max(1), 1, 1), block_dim: (block, 1, 1), shared_mem_bytes: 0 };
        unsafe { f.launch_on_stream(&self.sk, cfg, args) }.map_err(|e| format!("launch {name}: {e}"))
    }

    /// Upload the round's parameter slots (stream-ordered on the compute
    /// stream, before the launches that read them); returns the device
    /// address of slot 0.
    fn upload_prm(&mut self, slots: &[Prm]) -> Result<u64, String> {
        self.upload_prm_ranges(slots, &[]).map(|(p, _)| p)
    }

    /// [UPERF2-P] The parameter slots + the range table of a one-launch
    /// round in ONE copy; returns (slot 0's device address, the range
    /// table's device address).
    fn upload_prm_ranges(&mut self, slots: &[Prm], ranges: &[K9Range]) -> Result<(u64, u64), String> {
        assert!(slots.len() <= PRM_SLOTS, "K9 gpu: too many parameter slots ({} ranges)", slots.len());
        assert!(ranges.len() <= PRM_SLOTS, "K9 gpu: too many ranges ({})", ranges.len());
        // The previous round's launches must be done with the staging.
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk: {e}"))?;
        // Layout: the used slots, then the range table right after them (one
        // contiguous copy per round).
        let prm_words = slots.len() * PRM_WORDS;
        let rw = K9R_BYTES / 4;
        let words = prm_words + ranges.len() * rw;
        let h = self.prm_h.slice_mut::<u32>(words);
        for (i, p) in slots.iter().enumerate() {
            h[i * PRM_WORDS..(i + 1) * PRM_WORDS].copy_from_slice(&p.0);
        }
        for (i, r) in ranges.iter().enumerate() {
            let src: &[u32] = unsafe { std::slice::from_raw_parts(r as *const K9Range as *const u32, rw) };
            h[prm_words + i * rw..prm_words + (i + 1) * rw].copy_from_slice(src);
        }
        unsafe { cu::memcpy_htod_async(self.prm_d.ptr, self.prm_h.slice::<u32>(words), self.sk.stream) }.map_err(|e| format!("h2d prm: {e}"))?;
        Ok((self.prm_d.ptr, self.prm_d.ptr + (prm_words * 4) as u64))
    }

    fn zero_partial(&self) -> Result<(), String> {
        unsafe { cu::memset_d8_async(self.partial.ptr, 0, 5 * 16 * 8, self.sk.stream) }.map_err(|e| format!("memset partial: {e}"))
    }

    /// Read the node partial sums back (sync) and deposit them mod q into
    /// acc_lo[ni*31*KL + t*KL] (acc_hi untouched = 0 contribution).
    fn deposit_partial(&mut self, q: u64, nn: usize, acc_lo: &mut [u64]) -> Result<(), String> {
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk: {e}"))?;
        let h = self.partial_h.slice_mut::<u64>(nn * 16);
        unsafe { cu::memcpy_dtoh_sync(h, self.partial.ptr) }.map_err(|e| format!("d2h partial: {e}"))?;
        for ni in 0..nn {
            for t in 0..16 {
                acc_lo[ni * 31 * KL + t * KL] += h[ni * 16 + t] % q;
            }
        }
        Ok(())
    }
}

/// The remaining dedicated buffers (lane L's ixf tables and device-climb
/// buffers); [UPERF2-P] everything else is a chunk of the buddy.
#[derive(Clone, Copy)]
enum DevSel {
    Ixf(usize, usize),
    TreeSrc(usize),
    TreeOut(usize),
}

/// [UPERF2-N] Is the current thread a rayon worker (of ANY pool)? A staging
/// memcpy must then stay serial: `POOL.install` from a worker of another
/// pool makes that worker steal and run its own pool's pending jobs while it
/// waits — a job that re-enters this module (a device-layer materialization
/// from `extract_children_par`'s jobs, say) would then dead-lock on the K9
/// mutex / the layer's once-cell it is itself initializing.
fn in_rayon_worker() -> bool {
    rayon::current_thread_index().is_some()
}

/// Grid size for a grid-stride kernel over `n` items with `block` threads.
fn grid_for(n: usize, block: u32) -> u32 {
    let per = block as usize;
    (n.div_ceil(per).min(4096)).max(1) as u32
}

// ---------------------------------------------------------------------------
// The compact leaves on the device. [UPERF2-N] the words go up AS THEY ARE
// (`CompactLeaves::words`: 2 per leaf — q0, q1 | MEMBER; a zero pair = the
// (0, 1) dummy), alpha's coordinates and the exception list (idx, p[16],
// q[16]) sorted — the device decode + the exception override (`cl_get`,
// kernels_k9.cu) is `CompactLeaves::expand_blocks` per element, so the
// same packed blocks reach the same kernels. (Lane L re-derived this
// encoding from `expand_blocks` at ~24 ms per 4M leaves; with the accessors
// it is a memcpy into the pinned staging.) Meta: alpha[16] then n_exc x 33.

struct ClEncoded<'a> {
    words: &'a [u32],
    alpha: [u32; K_DEG],
    exc: Vec<u32>, // n_exc x 33
    n_exc: usize,
}

fn cl_encode(c: &CompactLeaves) -> Option<ClEncoded<'_>> {
    let ex = c.exceptions();
    if ex.len() > CL_MAX_EXC {
        return None;
    }
    let mut exc: Vec<u32> = Vec::with_capacity(33 * ex.len());
    for (i, p, q) in ex {
        exc.push(*i as u32);
        exc.extend_from_slice(p);
        exc.extend_from_slice(q);
    }
    Some(ClEncoded { words: c.words(), alpha: *c.alpha_words(), exc, n_exc: ex.len() })
}

/// The meta words of the compact leaves (alpha then the exceptions).
fn cl_meta(e: &ClEncoded) -> Vec<u32> {
    let mut meta: Vec<u32> = Vec::with_capacity(K_DEG + e.exc.len());
    meta.extend_from_slice(&e.alpha);
    meta.extend_from_slice(&e.exc);
    meta
}

// ---------------------------------------------------------------------------
// The fused descent round (the hook of kfield::k9_fused_round_par).

fn layer_id(src: &BlkSrc) -> LayerId {
    match src {
        BlkSrc::Packed { p, q } => LayerId::Packed { p: p.as_ptr() as usize, q: q.as_ptr() as usize, p_len: p.len(), q_len: q.len() },
        BlkSrc::Compact(c) => LayerId::Compact { c: (*c) as *const CompactLeaves as usize, n: c.n },
        BlkSrc::Device { dev, .. } => LayerId::Device { tree: dev.tree, k: dev.k },
    }
}

/// `Ok(())` = computed on the device (acc_lo updated; the tables as the
/// protocol above states); `Err(tabs)` = declined, the CPU body runs.
#[allow(clippy::too_many_arguments)]
pub fn k9_fused_round<'a>(
    kern: &KKern,
    plan: &FusedPlan,
    n_pairs: usize,
    eq_inplace: &mut [u32],
    eq_src: &[u32],
    eq_dst: &mut [u32],
    tabs: [&'a mut [u32]; 4],
    nodes: &[u64],
    node_consts: Option<&[[[u32; K_DEG]; 4]]>,
    acc_lo: &mut [u64],
    _acc_hi: &mut [u64],
) -> Result<(), [&'a mut [u32]; 4]> {
    if !live() {
        return Err(tabs);
    }
    let Some(kk) = k9s() else { return Err(tabs) };
    let mut k = kk.lock().unwrap();
    let mut tabs = tabs;
    // A chain that is alive MUST be continued or handed over by this very
    // call (the host tables are stale otherwise) — decided inside before
    // any size decline.
    let t0 = Instant::now();
    let res = k.fused_round(kern, plan, n_pairs, &mut *eq_inplace, eq_src, &mut *eq_dst, &mut tabs, nodes, node_consts, acc_lo);
    match res {
        Ok(true) => {
            S_ROUNDS.fetch_add(1, Ordering::Relaxed);
            add_us(&S_ROUND_US, t0.elapsed().as_secs_f64());
            Ok(())
        }
        Ok(false) => {
            S_DECLINED.fetch_add(1, Ordering::Relaxed);
            Err(tabs)
        }
        Err(e) => {
            // A device error. If a chain holds device-resident state, write
            // it back to the host first (the CPU continues from a coherent
            // host); if even that fails, fail loudly — never silently.
            if !WARNED.swap(true, Ordering::Relaxed) {
                eprintln!("[UPERF2-L] gpu k9 fused round failed ({e}); this and later K-field calls fall back to the CPU bodies");
            }
            if k.chain.is_some() {
                let eq_ptr = k.chain.as_ref().unwrap().ptrs[0];
                let r = if eq_ptr == eq_dst.as_ptr() as usize {
                    k.abort_to_host(&mut *eq_dst, &mut tabs)
                } else {
                    k.abort_to_host(&mut *eq_inplace, &mut tabs)
                };
                if let Err(e2) = r {
                    panic!("[UPERF2-L] gpu k9 fused round failed ({e}) and the resident state could not be written back ({e2}); the host tables are stale");
                }
            }
            k.release_all();
            DISABLED.store(true, Ordering::Relaxed);
            Err(tabs)
        }
    }
}

impl K9 {
    #[allow(clippy::too_many_arguments)]
    fn fused_round(
        &mut self,
        kern: &KKern,
        plan: &FusedPlan,
        n_pairs: usize,
        eq_inplace: &mut [u32],
        eq_src: &[u32],
        eq_dst: &mut [u32],
        tabs: &mut [&mut [u32]; 4],
        nodes: &[u64],
        node_consts: Option<&[[[u32; K_DEG]; 4]]>,
        acc_lo: &mut [u64],
    ) -> Result<bool, String> {
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let nn = nodes.len();
        assert!(nn <= 5 && nn >= 1, "K9 gpu: node count");
        let acc_words = nn * 31 * KL;
        assert!(acc_lo.len() >= acc_words, "K9 gpu: accumulator layout");
        let ranges: Vec<(usize, usize)> = plan.ranges.to_vec();
        // The live ranges cover the whole state (no pads skipped) when their
        // union is [0, n_pairs) — as one range (FUSE_FOLD without pads) or
        // as adjacent per-instance ranges (the extract modes list every
        // instance).
        let covers_all = ranges_union_is(&ranges, n_pairs);
        let min_width = ranges.iter().map(|&(a, b)| b - a).min().unwrap_or(0);
        let mode = plan.mode;
        // ---- The chain check (FUSE_FOLD continues; anything else with a
        // chain alive is a protocol violation). The successor's ranges are
        // the chain's halved — or, when those cover everything, the CPU
        // presents the single range [0, n_pairs) (skipping ended without
        // pads: `ranges_blk` is the whole table).
        if let Some(ch) = &self.chain {
            let ptrs = [eq_inplace.as_ptr() as usize, tabs[0].as_ptr() as usize, tabs[1].as_ptr() as usize, tabs[2].as_ptr() as usize, tabs[3].as_ptr() as usize];
            let halved: Vec<(usize, usize)> = ch.ranges.iter().map(|&(a, b)| (a / 2, b / 2)).collect();
            let same_ranges = halved == ranges || (ranges_union_is(&halved, n_pairs) && ranges.len() == 1 && ranges[0] == (0, n_pairs));
            let ok = mode == FUSE_FOLD && ptrs == ch.ptrs && ch.out_pairs == 2 * n_pairs && same_ranges;
            if !ok {
                // Write the resident state back and fail loudly: the caller
                // deviated from the sequence this file relies on.
                let msg = format!(
                    "[UPERF2-L] K-field descent chain broken: expected FUSE_FOLD on the same buffers with n_pairs {} and ranges {:?}, got mode {} n_pairs {} ranges {:?} same_ptrs {}",
                    ch.out_pairs / 2,
                    ch.ranges.iter().map(|&(a, b)| (a / 2, b / 2)).collect::<Vec<_>>(),
                    mode,
                    n_pairs,
                    ranges,
                    ptrs == ch.ptrs
                );
                panic!("{msg}");
            }
        } else if mode == FUSE_FOLD {
            // No chain: a FUSE_FOLD round that starts cold (the layer's earlier
            // rounds ran on the CPU — e.g. below the minimum): decline (an
            // upload of the whole state per round would be PCIe-bound) —
            // unless the harness asks for it (`k9_set_cold_ok`).
            if !COLD_OK.load(Ordering::Relaxed) || n_pairs < min_pairs() {
                return Ok(false);
            }
            let prev: Vec<(usize, usize)> = ranges.iter().map(|&(a, b)| (2 * a, 2 * b)).collect();
            let pieces = match self.alloc_state(&prev) {
                Ok(p) => p,
                Err(e) => {
                    if verbose() {
                        eprintln!("[UPERF2-L] k9: cold fold declined ({e})");
                    }
                    return Ok(false);
                }
            };
            let mut pp = 0usize;
            for pc in &pieces {
                for k in 0..5 {
                    let src: &[u32] = if k == 0 { &eq_inplace[2 * pc.a * KBLK..2 * pc.b * KBLK] } else { &tabs[k - 1][2 * pc.a * KBLK..2 * pc.b * KBLK] };
                    self.upload_words(pc.ch[k].ptr, src, &mut pp)?;
                }
            }
            self.compute_after_copies()?;
            let ptrs = [eq_inplace.as_ptr() as usize, tabs[0].as_ptr() as usize, tabs[1].as_ptr() as usize, tabs[2].as_ptr() as usize, tabs[3].as_ptr() as usize];
            self.chain = Some(Chain { ptrs, out_pairs: 2 * n_pairs, ranges: prev, pieces });
        }
        // ---- Size gate (only when no chain is alive: a live chain is
        // continued down to its handover).
        if self.chain.is_none() && n_pairs < min_pairs() {
            return Ok(false);
        }
        // ---- Parameters (the scalars by value; the vectors in a device slot
        // per range).
        let mut p = K9Params::new(kern);
        p.nn = nn as u32;
        let mut prm0 = Prm::new();
        prm0.set_nodes(nodes);
        prm0.set_vec(PRM_R, &plan.r_prev);
        prm0.set_vec(PRM_LAMBDA, &plan.lambda);
        if let Some(fc) = plan.fold_consts.as_ref() {
            p.has_fc = 1;
            prm0.set_fc(fc);
        }
        if let Some(nc) = node_consts {
            assert_eq!(nc.len(), nn);
            p.has_nc = 1;
            prm0.set_nc(nc);
        }
        // ---- Handover decision (this round's output is the successor's
        // input): the successor is hooked and taken by us iff its output
        // (n_pairs / 2) >= min_pairs and (no pads or the skipping goes on).
        let succ_taken = n_pairs / 2 >= min_pairs() && (covers_all || min_width / 2 >= 1);
        let handover = mode != FUSE_EXTRACT && (!succ_taken || eager());
        let t0 = Instant::now();
        match mode {
            FUSE_EXTRACT | FUSE_EXTRACT_FOLD => {
                assert_eq!(plan.layers.len(), ranges.len(), "K9 gpu: one layer per live range");
                // (1) The layer + eq on the device: reuse round 0's when the tag matches.
                let ids: Vec<(LayerId, usize)> = plan.layers.iter().map(|l| (layer_id(&l.src), l.first_pair)).collect();
                // [UPERF2-P] the eq's identity: the resident device table's id,
                // else the host words (the caller's, or the handle's image).
                let eq_id = match plan.eq_tab.and_then(|t| t.dev().map(|id| (id, t.n()))) {
                    Some((id, n)) if self.eq.as_ref().map(|e| (e.id, e.n)) == Some((id, n)) => (usize::MAX - id as usize, n),
                    _ => {
                        let w: &[u32] = if !eq_src.is_empty() {
                            eq_src
                        } else if let Some(t) = plan.eq_tab {
                            &t.host().d
                        } else {
                            eq_src
                        };
                        (w.as_ptr() as usize, w.len())
                    }
                };
                let hit = match &self.layer {
                    Some(l) => {
                        mode == FUSE_EXTRACT_FOLD
                            && l.n_pairs == 2 * n_pairs
                            && l.ids.len() == ids.len()
                            && l.ids.iter().zip(ids.iter()).all(|((id0, fp0), (id1, fp1))| id0 == id1 && *fp0 == 2 * fp1)
                            && l.eq == eq_id
                            && l.ranges.len() == ranges.len()
                            && l.ranges.iter().zip(ranges.iter()).all(|(&(a2, b2), &(a, b))| a2 == 2 * a && b2 == 2 * b)
                    }
                    None => false,
                };
                if hit {
                    S_LAYER_HIT.fetch_add(1, Ordering::Relaxed);
                } else {
                    self.release_layer_bufs();
                    let tu = Instant::now();
                    if !self.upload_layer(plan, n_pairs, &ranges, eq_src, &ids)? {
                        return Ok(false);
                    }
                    add_us(&S_UPLOAD_US, tu.elapsed().as_secs_f64());
                    S_LAYER_UP.fetch_add(1, Ordering::Relaxed);
                }
                // (2) The state-1 output pieces (EXTRACT_FOLD).
                let f_blk = if mode == FUSE_EXTRACT { 4usize } else { 8 };
                let fe_blk = if mode == FUSE_EXTRACT { 2usize } else { 4 };
                let out_pieces: Vec<Piece> = if mode == FUSE_EXTRACT_FOLD {
                    match self.alloc_state(&ranges) {
                        Ok(p) => p,
                        Err(e) => {
                            if verbose() {
                                eprintln!("[UPERF2-L] k9: extract-fold declined ({e})");
                            }
                            self.release_layer_bufs();
                            return Ok(false);
                        }
                    }
                } else {
                    pieces_of(&ranges)
                };
                self.compute_after_copies()?;
                let slots: Vec<Prm> = plan
                    .layers
                    .iter()
                    .map(|l| {
                        let mut q = prm0.clone();
                        if let Some(ee) = l.ee {
                            q.set_vec(PRM_EE, &ee);
                        }
                        q
                    })
                    .collect();
                // The launch pieces: per output piece, the layer / eq pointers
                // at the piece's first pair-block (`la` = its offset in the
                // instance), the state-1 output pointers, the range's slot.
                let (all_packed, all_compact) = {
                    let layer = self.layer.as_ref().unwrap();
                    (
                        layer.devs.iter().all(|d| matches!(d, LayerDev::Packed { .. })),
                        layer.devs.iter().all(|d| matches!(d, LayerDev::Compact { .. })),
                    )
                };
                let eq_base = self.eq_ptr_for(plan, eq_src);
                let mut rtab: Vec<K9Range> = Vec::with_capacity(out_pieces.len());
                let mut t0c = 0u32;
                {
                    let layer = self.layer.as_ref().unwrap();
                    for pc in &out_pieces {
                        let ri = pc.ri;
                        let n = 8 * (pc.b - pc.a);
                        let la = pc.a - plan.layers[ri].first_pair;
                        let mut r = K9Range { t0: t0c, n: n as u32, slot: ri as u32, ..Default::default() };
                        if plan.layers[ri].ee.is_some() {
                            r.flags |= K9R_HAS_EE;
                        }
                        r.eq = eq_base + ((fe_blk * la) * KBLK * 4) as u64;
                        if mode == FUSE_EXTRACT_FOLD {
                            r.outs = std::array::from_fn(|k| pc.ch[k].ptr);
                        }
                        match &layer.devs[ri] {
                            LayerDev::Packed { p: p_ptr, q: q_ptr } => {
                                r.ins[0] = p_ptr + (f_blk * la * KBLK * 4) as u64;
                                r.ins[1] = q_ptr + (f_blk * la * KBLK * 4) as u64;
                            }
                            LayerDev::Compact { w: w_ptr, meta, n_exc } => {
                                r.ins[0] = *w_ptr;
                                r.ins[1] = *meta;
                                r.ins[2] = *meta + (K_DEG * 4) as u64;
                                r.n_exc = *n_exc as u32;
                                r.e_base = (f_blk * la * KL) as u32;
                            }
                        }
                        rtab.push(r);
                        t0c += n as u32;
                    }
                }
                let total = t0c;
                if multi() && (all_packed || all_compact) {
                    // [UPERF2-P] ONE launch over the range table.
                    let (prm_base, rptr) = self.upload_prm_ranges(&slots, &rtab)?;
                    self.zero_partial()?;
                    if profile() {
                        self.sync_all()?;
                    }
                    let tk = Instant::now();
                    let mut pr = p;
                    pr.prm = prm_base;
                    let nr = rtab.len() as u32;
                    let part = self.partial.ptr;
                    let name = kname(
                        match (mode == FUSE_EXTRACT, all_packed) {
                            (true, true) => "k_extract_round_m",
                            (true, false) => "k_extract_round_cl_m",
                            (false, true) => "k_extract_fold_m",
                            (false, false) => "k_extract_fold_cl_m",
                        },
                        nn,
                    );
                    let mut args: [*mut c_void; 5] = [
                        &pr as *const _ as *mut _,
                        &rptr as *const _ as *mut _,
                        &nr as *const _ as *mut _,
                        &total as *const _ as *mut _,
                        &part as *const _ as *mut _,
                    ];
                    self.launch(name, grid_for(total as usize, TK9), TK9, &mut args)?;
                    P_LAUNCHES.fetch_add(1, Ordering::Relaxed);
                    P_ROUNDS_MULTI.fetch_add(1, Ordering::Relaxed);
                    self.deposit_partial(kern.q, nn, acc_lo)?;
                    self.last_kernel_ms = tk.elapsed().as_secs_f64() * 1e3;
                    add_us(&S_KERNEL_US, tk.elapsed().as_secs_f64());
                } else {
                    // Lane L's kernels: one launch per piece.
                    let prm_base = self.upload_prm(&slots)?;
                    self.zero_partial()?;
                    if profile() {
                        self.sync_all()?;
                    }
                    let tk = Instant::now();
                    P_ROUNDS_SPLIT.fetch_add(1, Ordering::Relaxed);
                    P_LAUNCHES.fetch_add(rtab.len() as u64, Ordering::Relaxed);
                    let part = self.partial.ptr;
                    for r in &rtab {
                        let mut pr = p;
                        pr.prm = prm_base + (r.slot as usize * PRM_WORDS * 4) as u64;
                        if r.flags & K9R_HAS_EE != 0 {
                            pr.has_ee = 1;
                        }
                        let n_u = r.n;
                        let grid = grid_for(r.n as usize, TK9);
                        let compact = !all_packed;
                        if !compact {
                            let (pp, qq, eq_ptr) = (r.ins[0], r.ins[1], r.eq);
                            if mode == FUSE_EXTRACT {
                                let mut args: [*mut c_void; 6] = [
                                    &pr as *const _ as *mut _,
                                    &pp as *const _ as *mut _,
                                    &qq as *const _ as *mut _,
                                    &eq_ptr as *const _ as *mut _,
                                    &n_u as *const _ as *mut _,
                                    &part as *const _ as *mut _,
                                ];
                                self.launch("k_extract_round", grid, TK9, &mut args)?;
                            } else {
                                let outs = r.outs;
                                let mut args: [*mut c_void; 11] = [
                                    &pr as *const _ as *mut _,
                                    &pp as *const _ as *mut _,
                                    &qq as *const _ as *mut _,
                                    &eq_ptr as *const _ as *mut _,
                                    &outs[0] as *const _ as *mut _,
                                    &outs[1] as *const _ as *mut _,
                                    &outs[2] as *const _ as *mut _,
                                    &outs[3] as *const _ as *mut _,
                                    &outs[4] as *const _ as *mut _,
                                    &n_u as *const _ as *mut _,
                                    &part as *const _ as *mut _,
                                ];
                                self.launch("k_extract_fold", grid, TK9, &mut args)?;
                            }
                        } else {
                            let (w, alpha, exc, eq_ptr) = (r.ins[0], r.ins[1], r.ins[2], r.eq);
                            let n_exc_u = r.n_exc;
                            let e_base = r.e_base;
                            if mode == FUSE_EXTRACT {
                                let mut args: [*mut c_void; 9] = [
                                    &pr as *const _ as *mut _,
                                    &w as *const _ as *mut _,
                                    &alpha as *const _ as *mut _,
                                    &exc as *const _ as *mut _,
                                    &n_exc_u as *const _ as *mut _,
                                    &e_base as *const _ as *mut _,
                                    &eq_ptr as *const _ as *mut _,
                                    &n_u as *const _ as *mut _,
                                    &part as *const _ as *mut _,
                                ];
                                self.launch("k_extract_round_cl", grid, TK9, &mut args)?;
                            } else {
                                let outs = r.outs;
                                let mut args: [*mut c_void; 14] = [
                                    &pr as *const _ as *mut _,
                                    &w as *const _ as *mut _,
                                    &alpha as *const _ as *mut _,
                                    &exc as *const _ as *mut _,
                                    &n_exc_u as *const _ as *mut _,
                                    &e_base as *const _ as *mut _,
                                    &eq_ptr as *const _ as *mut _,
                                    &outs[0] as *const _ as *mut _,
                                    &outs[1] as *const _ as *mut _,
                                    &outs[2] as *const _ as *mut _,
                                    &outs[3] as *const _ as *mut _,
                                    &outs[4] as *const _ as *mut _,
                                    &n_u as *const _ as *mut _,
                                    &part as *const _ as *mut _,
                                ];
                                self.launch("k_extract_fold_cl", grid, TK9, &mut args)?;
                            }
                        }
                    }
                    self.deposit_partial(kern.q, nn, acc_lo)?;
                    self.last_kernel_ms = tk.elapsed().as_secs_f64() * 1e3;
                    add_us(&S_KERNEL_US, tk.elapsed().as_secs_f64());
                }
                if mode == FUSE_EXTRACT {
                    // Keep the layer for round 1; nothing written.
                    if let Some(l) = self.layer.as_mut() {
                        l.n_pairs = n_pairs;
                        l.ranges = ranges.clone();
                    }
                } else {
                    // The layer is consumed; the state-1 tables are resident.
                    // Its chunks go back to the buddy.
                    self.release_layer_bufs();
                    let ptrs = [eq_dst.as_ptr() as usize, tabs[0].as_ptr() as usize, tabs[1].as_ptr() as usize, tabs[2].as_ptr() as usize, tabs[3].as_ptr() as usize];
                    self.chain = Some(Chain { ptrs, out_pairs: n_pairs, ranges: ranges.clone(), pieces: out_pieces });
                    if handover {
                        let th = Instant::now();
                        self.handover_to_host(eq_dst, tabs)?;
                        add_us(&S_HANDOVER_US, th.elapsed().as_secs_f64());
                        if !succ_taken {
                            self.release_chain();
                        }
                    }
                }
            }
            _ => {
                // FUSE_FOLD on the resident state: state t-1 (the chain's
                // pieces) -> state t (fresh pieces); the input of an output
                // piece [a, b) is the previous state's pair-blocks [2a, 2b),
                // which may span several previous pieces (a launch piece per
                // intersection).
                let out_pieces = match self.alloc_state(&ranges) {
                    Ok(p) => p,
                    Err(e) => {
                        // Cannot continue on the device: write the current state
                        // back (the CPU takes over from a coherent host).
                        if verbose() {
                            eprintln!("[UPERF2-L] k9: fold round declined ({e}); handing the state to the host");
                        }
                        self.abort_to_host(eq_inplace, tabs)?;
                        return Ok(false);
                    }
                };
                let in_pieces = self.chain.as_ref().unwrap().pieces.clone();
                let mut rtab: Vec<K9Range> = Vec::new();
                let mut t0c = 0u32;
                for oc in &out_pieces {
                    let (ia, ib) = (2 * oc.a, 2 * oc.b);
                    let mut cur = ia;
                    for ic in &in_pieces {
                        if ic.b <= ia || ic.a >= ib {
                            continue;
                        }
                        let (xa, xb) = (ic.a.max(ia), ic.b.min(ib));
                        assert!(xa == cur, "K9 gpu: the input pair-blocks [{ia}, {ib}) are not covered contiguously by the previous pieces");
                        // Output pair-blocks of this intersection: [xa/2, xb/2).
                        let (oa, ob) = (xa / 2, xb / 2);
                        assert!(xa % 2 == 0 && xb % 2 == 0, "K9 gpu: piece boundaries at odd pair-blocks");
                        let ins: [u64; 5] = std::array::from_fn(|k| piece_ptr(ic, k, xa));
                        let outs: [u64; 5] = std::array::from_fn(|k| piece_ptr(oc, k, oa));
                        let n = 8 * (ob - oa);
                        rtab.push(K9Range { ins, outs, t0: t0c, n: n as u32, slot: 0, ..Default::default() });
                        t0c += n as u32;
                        cur = xb;
                    }
                    assert!(cur == ib, "K9 gpu: the input pair-blocks [{ia}, {ib}) exceed the previous pieces");
                }
                let total = t0c;
                if multi() {
                    // [UPERF2-P] ONE launch over the range table.
                    let (prm_base, rptr) = self.upload_prm_ranges(std::slice::from_ref(&prm0), &rtab)?;
                    p.prm = prm_base;
                    self.zero_partial()?;
                    if profile() {
                        self.sync_all()?;
                    }
                    let tk = Instant::now();
                    let nr = rtab.len() as u32;
                    let part = self.partial.ptr;
                    let mut args: [*mut c_void; 5] = [
                        &p as *const _ as *mut _,
                        &rptr as *const _ as *mut _,
                        &nr as *const _ as *mut _,
                        &total as *const _ as *mut _,
                        &part as *const _ as *mut _,
                    ];
                    self.launch(kname("k_fold_round_m", nn), grid_for(total as usize, TK9), TK9, &mut args)?;
                    P_LAUNCHES.fetch_add(1, Ordering::Relaxed);
                    P_ROUNDS_MULTI.fetch_add(1, Ordering::Relaxed);
                    self.deposit_partial(kern.q, nn, acc_lo)?;
                    self.last_kernel_ms = tk.elapsed().as_secs_f64() * 1e3;
                    add_us(&S_KERNEL_US, tk.elapsed().as_secs_f64());
                } else {
                    let prm_base = self.upload_prm(std::slice::from_ref(&prm0))?;
                    p.prm = prm_base;
                    self.zero_partial()?;
                    if profile() {
                        self.sync_all()?;
                    }
                    let tk = Instant::now();
                    P_ROUNDS_SPLIT.fetch_add(1, Ordering::Relaxed);
                    P_LAUNCHES.fetch_add(rtab.len() as u64, Ordering::Relaxed);
                    let part = self.partial.ptr;
                    for r in &rtab {
                        let n_u = r.n;
                        let grid = grid_for(r.n as usize, TK9);
                        let (ins, outs) = (r.ins, r.outs);
                        let mut args: [*mut c_void; 13] = [
                            &p as *const _ as *mut _,
                            &ins[0] as *const _ as *mut _,
                            &ins[1] as *const _ as *mut _,
                            &ins[2] as *const _ as *mut _,
                            &ins[3] as *const _ as *mut _,
                            &ins[4] as *const _ as *mut _,
                            &outs[0] as *const _ as *mut _,
                            &outs[1] as *const _ as *mut _,
                            &outs[2] as *const _ as *mut _,
                            &outs[3] as *const _ as *mut _,
                            &outs[4] as *const _ as *mut _,
                            &n_u as *const _ as *mut _,
                            &part as *const _ as *mut _,
                        ];
                        self.launch("k_fold_round", grid, TK9, &mut args)?;
                    }
                    self.deposit_partial(kern.q, nn, acc_lo)?;
                    self.last_kernel_ms = tk.elapsed().as_secs_f64() * 1e3;
                    add_us(&S_KERNEL_US, tk.elapsed().as_secs_f64());
                }
                // State t-1 is consumed (the round is complete: deposit synced).
                let ptrs = self.chain.as_ref().unwrap().ptrs;
                self.release_chain();
                self.chain = Some(Chain { ptrs, out_pairs: n_pairs, ranges: ranges.clone(), pieces: out_pieces });
                if handover {
                    let th = Instant::now();
                    self.handover_to_host(eq_inplace, tabs)?;
                    add_us(&S_HANDOVER_US, th.elapsed().as_secs_f64());
                    if !succ_taken {
                        self.release_chain();
                    }
                }
            }
        }
        if verbose() {
            eprintln!(
                "[UPERF2-L] k9 round mode {} n_pairs {} ranges {} nn {} handover {} : {:.2} ms (kernel+sync {:.2} ms)",
                mode,
                n_pairs,
                ranges.len(),
                nn,
                handover,
                t0.elapsed().as_secs_f64() * 1e3,
                self.last_kernel_ms
            );
        }
        Ok(true)
    }

    /// [UPERF2-P] Allocate the pieces of a state over `ranges` (5 chunks per
    /// piece); on a shortfall everything allocated so far goes back.
    fn alloc_state(&mut self, ranges: &[(usize, usize)]) -> Result<Vec<Piece>, String> {
        let mut pieces = pieces_of(ranges);
        for i in 0..pieces.len() {
            let bytes = 2 * (pieces[i].b - pieces[i].a) * KBLK * 4;
            for k in 0..5 {
                match self.alloc(bytes) {
                    Ok(c) => pieces[i].ch[k] = c,
                    Err(e) => {
                        for pc in &pieces {
                            for c in pc.ch {
                                self.free(c);
                            }
                        }
                        return Err(e);
                    }
                }
            }
        }
        Ok(pieces)
    }

    /// The device address of the eq b-part's element 0 as bound for this
    /// round (the resident device eq, or the uploaded host words).
    fn eq_ptr_for(&self, _plan: &FusedPlan, _eq_src: &[u32]) -> u64 {
        self.layer.as_ref().expect("a bound layer").eq_up
    }

    /// Bind the plan's layers on the device — upload the packed live blocks
    /// / the compact leaves' words, or [UPERF2-N] take a device tree's
    /// layer in place (a resident checkpoint, the compact leaves) or CLIMB
    /// its gap layer here into fresh chunks — and bind or upload the eq
    /// table; sets `self.layer`. `Ok(false)` = declined (budget / encoding
    /// limits; nothing stays allocated).
    fn upload_layer(&mut self, plan: &FusedPlan, n_pairs: usize, ranges: &[(usize, usize)], eq_src: &[u32], ids: &[(LayerId, usize)]) -> Result<bool, String> {
        let f_blk = if plan.mode == FUSE_EXTRACT { 4usize } else { 8 };
        // Per range: what to do.
        enum Bind<'e> {
            Upload { nb: usize },
            Compact(ClEncoded<'e>),
            InPlace(LayerDev),
            Climb { src_k: usize, nblk: usize },
        }
        let mut binds: Vec<Bind> = Vec::with_capacity(ranges.len());
        let te = Instant::now();
        for (ri, &(a, b)) in ranges.iter().enumerate() {
            let n = b - a;
            match &plan.layers[ri].src {
                BlkSrc::Packed { p, q } => {
                    let la = a - plan.layers[ri].first_pair;
                    assert!(p.len() >= f_blk * (la + n) * KBLK && q.len() >= f_blk * (la + n) * KBLK, "K9 gpu: layer slice");
                    binds.push(Bind::Upload { nb: f_blk * (la + n) });
                }
                BlkSrc::Compact(c) => {
                    let Some(e) = cl_encode(c) else {
                        return Ok(false);
                    };
                    binds.push(Bind::Compact(e));
                }
                BlkSrc::Device { dev, .. } => {
                    let Some(t) = self.trees.get(&dev.tree) else {
                        panic!("[UPERF2-N] device tree {} is gone while its layer {} is being read (protocol violation)", dev.tree, dev.k);
                    };
                    let k = dev.k;
                    if let Some((p, q)) = &t.layers[k] {
                        binds.push(Bind::InPlace(LayerDev::Packed { p: p.ptr, q: q.ptr }));
                    } else if k == t.depth {
                        let (w, m, n_exc) = t.compact.as_ref().expect("a device tree keeps its leaves");
                        binds.push(Bind::InPlace(LayerDev::Compact { w: w.ptr, meta: m.ptr, n_exc: *n_exc }));
                    } else {
                        let src_k = (k + 1..=t.depth).find(|&kk| t.layers[kk].is_some() || (kk == t.depth && t.compact.is_some())).expect("a device tree keeps its leaves");
                        let nblk = (1usize << k) / KL;
                        let la = a - plan.layers[ri].first_pair;
                        assert!(f_blk * (la + n) <= nblk, "K9 gpu: device layer range");
                        binds.push(Bind::Climb { src_k, nblk });
                    }
                }
            }
        }
        add_us(&S_ENCODE_US, te.elapsed().as_secs_f64());
        // [UPERF2-P] the eq: a device-built table (the plan's handle) is bound
        // IN PLACE when its id is the resident one; otherwise the host words
        // (the caller's, or the handle's image materialized once) go up.
        let eq_hit = match plan.eq_tab.and_then(|t| t.dev().map(|id| (id, t.n()))) {
            Some((id, n)) => self.eq.as_ref().map(|e| (e.id, e.n)) == Some((id, n)),
            None => false,
        };
        fn eq_host_words<'p>(plan: &FusedPlan<'p>, eq_src: &'p [u32]) -> &'p [u32] {
            if !eq_src.is_empty() {
                eq_src
            } else if let Some(t) = plan.eq_tab {
                if !t.host_built() {
                    P_EQ_HOST.fetch_add(1, Ordering::Relaxed);
                }
                &t.host().d
            } else {
                eq_src
            }
        }
        // Allocate: everything this binding owns (freed together on decline).
        let mut owned: Vec<Chunk> = Vec::new();
        let alloc_or_decline = |k: &mut K9, bytes: usize, owned: &mut Vec<Chunk>| -> Result<Option<Chunk>, String> {
            match k.alloc(bytes) {
                Ok(c) => {
                    owned.push(c);
                    Ok(Some(c))
                }
                Err(e) => {
                    if e.starts_with("K9 VRAM budget") {
                        if verbose() {
                            eprintln!("[UPERF2-L] k9: layer declined — {e}");
                        }
                        Ok(None)
                    } else {
                        Err(e)
                    }
                }
            }
        };
        macro_rules! take {
            ($e:expr) => {
                match $e {
                    Ok(Some(c)) => c,
                    Ok(None) => {
                        for c in owned {
                            self.free(c);
                        }
                        return Ok(false);
                    }
                    Err(e) => return Err(e),
                }
            };
        }
        let mut pp = 0usize;
        // The eq first (a device eq is bound; else the host words go up).
        let (eq_key, eq_up): ((usize, usize), u64) = if eq_hit {
            P_EQ_BINDS.fetch_add(1, Ordering::Relaxed);
            let e = self.eq.as_ref().unwrap();
            ((usize::MAX - e.id as usize, e.n), e.ch.ptr)
        } else {
            let w = eq_host_words(plan, eq_src);
            let c = take!(alloc_or_decline(self, w.len() * 4, &mut owned));
            self.upload_words(c.ptr, w, &mut pp)?;
            ((w.as_ptr() as usize, w.len()), c.ptr)
        };
        let mut devs: Vec<LayerDev> = Vec::with_capacity(ranges.len());
        let mut n_res = 0u64;
        let mut n_climb = 0u64;
        let tc = Instant::now();
        // The climb scratch (two chunks per intermediate level size; the
        // levels ping-pong), sized by the largest climb.
        let mut scr: [Chunk; 2] = [Chunk::NONE; 2];
        let mut scr_bytes = 0usize;
        for (ri, b) in binds.iter().enumerate() {
            if let Bind::Climb { src_k, .. } = b {
                if let BlkSrc::Device { dev, .. } = &plan.layers[ri].src {
                    if src_k - dev.k >= 2 {
                        scr_bytes = scr_bytes.max(2 * (1usize << (src_k - 1)) / KL * KBLK * 4);
                    }
                }
            }
        }
        if scr_bytes > 0 {
            scr[0] = take!(alloc_or_decline(self, scr_bytes, &mut owned));
            scr[1] = take!(alloc_or_decline(self, scr_bytes, &mut owned));
        }
        for (ri, &(a, b)) in ranges.iter().enumerate() {
            let n = b - a;
            match &binds[ri] {
                Bind::Upload { nb } => {
                    let (p, q) = match &plan.layers[ri].src {
                        BlkSrc::Packed { p, q } => (p, q),
                        _ => unreachable!(),
                    };
                    let bytes = nb * KBLK * 4;
                    let cp = take!(alloc_or_decline(self, bytes, &mut owned));
                    let cq = take!(alloc_or_decline(self, bytes, &mut owned));
                    self.upload_words(cp.ptr, &p[..nb * KBLK], &mut pp)?;
                    self.upload_words(cq.ptr, &q[..nb * KBLK], &mut pp)?;
                    devs.push(LayerDev::Packed { p: cp.ptr, q: cq.ptr });
                }
                Bind::Compact(e) => {
                    let meta = cl_meta(e);
                    let cw = take!(alloc_or_decline(self, e.words.len() * 4, &mut owned));
                    let cm = take!(alloc_or_decline(self, meta.len() * 4, &mut owned));
                    self.upload_words(cw.ptr, e.words, &mut pp)?;
                    self.upload_words(cm.ptr, &meta, &mut pp)?;
                    devs.push(LayerDev::Compact { w: cw.ptr, meta: cm.ptr, n_exc: e.n_exc });
                }
                Bind::InPlace(ld) => {
                    n_res += 1;
                    devs.push(match ld {
                        LayerDev::Packed { p, q } => LayerDev::Packed { p: *p, q: *q },
                        LayerDev::Compact { w, meta, n_exc } => LayerDev::Compact { w: *w, meta: *meta, n_exc: *n_exc },
                    });
                }
                Bind::Climb { src_k, nblk } => {
                    let dev = match &plan.layers[ri].src {
                        BlkSrc::Device { dev, .. } => *dev,
                        _ => unreachable!(),
                    };
                    let bytes = nblk * KBLK * 4;
                    let cp = take!(alloc_or_decline(self, bytes, &mut owned));
                    let cq = take!(alloc_or_decline(self, bytes, &mut owned));
                    self.climb_layer(dev.tree, dev.k, *src_k, cp.ptr, cq.ptr, &scr)?;
                    n_climb += 1;
                    devs.push(LayerDev::Packed { p: cp.ptr, q: cq.ptr });
                    let _ = n;
                }
            }
        }
        if n_climb > 0 {
            // The climbs' outputs are read by this round's kernels on the same
            // stream (ordered); the timing here is enqueue-side only.
            add_us(&S_DEV_CLIMB_US, tc.elapsed().as_secs_f64());
            S_DEV_CLIMBS.fetch_add(n_climb, Ordering::Relaxed);
        }
        S_LAYER_RESIDENT.fetch_add(n_res, Ordering::Relaxed);
        self.layer = Some(LayerRes { n_pairs, ranges: ranges.to_vec(), ids: ids.to_vec(), devs, eq: eq_key, eq_up, owned });
        Ok(true)
    }

    /// Copy the resident state's live pieces into the host buffers where
    /// the CPU path would have left them (blocks [2a, 2b) per piece).
    fn handover_to_host(&mut self, eq: &mut [u32], tabs: &mut [&mut [u32]; 4]) -> Result<(), String> {
        let pieces = self.chain.as_ref().unwrap().pieces.clone();
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk: {e}"))?;
        for pc in &pieces {
            for k in 0..5 {
                let words = 2 * (pc.b - pc.a) * KBLK;
                let dst_all: &mut [u32] = if k == 0 { &mut *eq } else { &mut *tabs[k - 1] };
                assert!(2 * pc.b * KBLK <= dst_all.len(), "K9 gpu: handover destination too small");
                let dst = &mut dst_all[2 * pc.a * KBLK..2 * pc.a * KBLK + words];
                self.download_words(pc.ch[k].ptr, dst)?;
            }
        }
        Ok(())
    }

    /// The device cannot continue: write the resident state back (the host
    /// becomes coherent) and drop the chain.
    fn abort_to_host(&mut self, eq: &mut [u32], tabs: &mut [&mut [u32]; 4]) -> Result<(), String> {
        if self.chain.is_some() {
            self.handover_to_host(eq, tabs)?;
            self.release_chain();
        }
        Ok(())
    }
}

/// Do the (sorted, disjoint) ranges cover exactly [0, n) with no gap?
fn ranges_union_is(ranges: &[(usize, usize)], n: usize) -> bool {
    let mut cur = 0usize;
    for &(a, b) in ranges {
        if a != cur || b < a {
            return false;
        }
        cur = b;
    }
    cur == n
}

// ---------------------------------------------------------------------------
// The ixf round + fold (the hooks of kfield::k9_ixf_round_par / KField::kt_fold_par).

pub fn k9_ixf_round(kern: &KKern, kind: u8, tabs: &[&[u32]], nblk_pairs: usize, deg: usize, acc_lo: &mut [u64], _acc_hi: &mut [u64]) -> Option<()> {
    if !live() {
        return None;
    }
    let kk = k9s()?;
    let mut k = kk.lock().unwrap();
    let t0 = Instant::now();
    match k.ixf_round(kern, kind, tabs, nblk_pairs, deg, acc_lo) {
        Ok(true) => {
            S_IXF_ROUNDS.fetch_add(1, Ordering::Relaxed);
            add_us(&S_IXF_US, t0.elapsed().as_secs_f64());
            if verbose() {
                eprintln!("[UPERF2-L] k9 ixf round kind {kind} nt {} n_pairs {nblk_pairs} deg {deg}: {:.2} ms (kernel+sync {:.2} ms)", tabs.len(), t0.elapsed().as_secs_f64() * 1e3, k.last_kernel_ms);
            }
            Some(())
        }
        Ok(false) => None,
        Err(e) => {
            if !WARNED.swap(true, Ordering::Relaxed) {
                eprintln!("[UPERF2-L] gpu k9 ixf round failed ({e}); this and later K-field calls fall back to the CPU bodies");
            }
            k.release_all();
            DISABLED.store(true, Ordering::Relaxed);
            None
        }
    }
}

pub fn kt_fold(kf: &KField, t: &mut KTab, scratch: &mut Vec<u32>, r: &KElem) -> Option<()> {
    if !live() {
        return None;
    }
    let kern = kf.kern.as_ref()?;
    let kk = k9s()?;
    let mut k = kk.lock().unwrap();
    let t0 = Instant::now();
    match k.fold_table(kern, t, scratch, r) {
        Ok(true) => {
            S_IXF_FOLDS.fetch_add(1, Ordering::Relaxed);
            add_us(&S_IXF_US, t0.elapsed().as_secs_f64());
            if verbose() {
                eprintln!("[UPERF2-L] k9 ixf fold n_out {}: {:.2} ms (t.d len {} cap {}, scratch len {} cap {})", t.n, t0.elapsed().as_secs_f64() * 1e3, t.d.len(), t.d.capacity(), scratch.len(), scratch.capacity());
            }
            Some(())
        }
        Ok(false) => None,
        Err(e) => {
            if !WARNED.swap(true, Ordering::Relaxed) {
                eprintln!("[UPERF2-L] gpu k9 fold failed ({e}); this and later K-field calls fall back to the CPU bodies");
            }
            k.release_all();
            DISABLED.store(true, Ordering::Relaxed);
            None
        }
    }
}

impl K9 {
    fn ixf_round(&mut self, kern: &KKern, kind: u8, tabs: &[&[u32]], nblk_pairs: usize, deg: usize, acc_lo: &mut [u64]) -> Result<bool, String> {
        let nt = tabs.len();
        assert!((3..=5).contains(&nt) && deg >= 2 && deg <= 4, "K9 gpu ixf: shape");
        if nblk_pairs < min_pairs() {
            self.ixf = None;
            return Ok(false);
        }
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let n = nblk_pairs * 2 * KL; // elements per table
        let words = nblk_pairs * 2 * KBLK;
        // Resident? The expected chain: the previous round's nt folds done,
        // this round's tables with n = prev/2 — the SEQUENCE identifies the
        // successor (fold.rs `ixf_sumcheck_prove_packed` is one sequential
        // loop on one transcript; nothing else calls these hooks in between).
        // Under the lazy protocol the host copies of a live chain are STALE,
        // so a chain that is alive but not the expected successor is a
        // protocol violation (fail loudly), never a re-upload.
        let ptrs: Vec<usize> = tabs.iter().map(|t| t.as_ptr() as usize).collect();
        let hit = match &self.ixf {
            Some(c) => {
                let seq_ok = c.kind == kind && c.nt == nt && c.folded == nt && c.n == 2 * n;
                if !seq_ok {
                    if c.lazy {
                        panic!(
                            "[UPERF2-L] K-field ixf chain broken: expected round(t+1) kind {} nt {} n {} after {} folds, got kind {kind} nt {nt} n {n} (folded {})",
                            c.kind, c.nt, c.n / 2, c.nt, c.folded
                        );
                    }
                    false
                } else {
                    if c.next_ptrs != ptrs && verbose() {
                        eprintln!("[UPERF2-L] k9 ixf: the folded tables moved on the host (shrink_to_fit) — the sequence identifies them; continuing on the device");
                    }
                    true
                }
            }
            None => false,
        };
        let bufs: Vec<usize> = if hit {
            S_IXF_HITS.fetch_add(1, Ordering::Relaxed);
            self.ixf.as_ref().unwrap().buf.clone()
        } else {
            self.ixf = None;
            // Budget: nt tables x 2 (ping-pong) x words.
            let per = words * 4;
            let mut more = 0usize;
            for k in 0..nt {
                let cur = if self.ixf_t.len() > k { self.ixf_t[k][0].bytes.min(self.ixf_t[k][1].bytes) } else { 0 };
                more += 2 * per.saturating_sub(cur);
            }
            if self.held + more > self.budget {
                return Ok(false);
            }
            // [UPERF3-WW] round 11, rung 1 (ADDITIVE, default-preserving):
            // make the room ONCE, before the grows. `make_room` frees the
            // whole idle ixf_t family (self.ixf is None here), so a
            // make_room fired by grow_dev in the MIDDLE of the loop below
            // freed the tables grown earlier in the same call and the
            // upload wrote to ptr 0 — CUDA_ERROR_INVALID_VALUE, after which
            // the module disables itself for the process (MEASURED
            // 2026-09-02 at 12x512 in the one-process Stage-A + oracle
            // pass: the descents of the oracle leg ran on the CPU, 55-59 s).
            // `more` over-counts (it is the pre-check's figure), so a pass
            // here guarantees no grow below crosses the budget; when the
            // room cannot be made, decline — the CPU round, no value moves.
            if self.used() + more > self.budget {
                self.make_room(more);
                if self.used() + more > self.budget {
                    return Ok(false);
                }
            }
            for k in 0..nt {
                self.grow_dev(DevSel::Ixf(k, 0), per)?;
                self.grow_dev(DevSel::Ixf(k, 1), per / 2)?;
            }
            let mut pp = 0usize;
            for k in 0..nt {
                let dst = self.ixf_t[k][0].ptr;
                self.upload_words(dst, &tabs[k][..words], &mut pp)?;
            }
            self.compute_after_copies()?;
            vec![0usize; nt]
        };
        let mut p = K9Params::new(kern);
        p.kind = kind as u32;
        p.deg = deg as u32;
        p.prm = self.upload_prm(std::slice::from_ref(&Prm::new()))?;
        self.zero_partial()?;
        let tk = Instant::now();
        let n_pairs = nblk_pairs * KL;
        let n_u = n_pairs as u32;
        let part = self.partial.ptr;
        let tp: [u64; 5] = std::array::from_fn(|k| if k < nt { self.ixf_t[k][bufs[k]].ptr } else { 0 });
        let name = "k_ixf_round";
        let mut args: [*mut c_void; 8] = [
            &p as *const _ as *mut _,
            &tp[0] as *const _ as *mut _,
            &tp[1] as *const _ as *mut _,
            &tp[2] as *const _ as *mut _,
            &tp[3] as *const _ as *mut _,
            &tp[4] as *const _ as *mut _,
            &n_u as *const _ as *mut _,
            &part as *const _ as *mut _,
        ];
        self.launch(name, grid_for(n_pairs, TK9), TK9, &mut args)?;
        self.deposit_partial(kern.q, deg + 1, acc_lo)?;
        self.last_kernel_ms = tk.elapsed().as_secs_f64() * 1e3;
        add_us(&S_KERNEL_US, tk.elapsed().as_secs_f64());
        self.ixf = Some(IxfChain { kind, nt, ptrs, n, buf: bufs, folded: 0, next_ptrs: vec![0; nt], lazy: false });
        Ok(true)
    }

    /// The fold of one table (kt_fold_par's contract: t halves; the
    /// out-of-place result lands in `scratch` which is swapped in; the old
    /// buffer becomes the scratch). Taken only when the table is resident
    /// (the ixf chain expects this fold); the folded table is written to
    /// the host EAGERLY.
    fn fold_table(&mut self, kern: &KKern, t: &mut KTab, scratch: &mut Vec<u32>, r: &KElem) -> Result<bool, String> {
        let n_out = t.n / 2;
        if n_out < KL {
            return Ok(false);
        }
        let nblk = n_out / KL;
        // Which resident table is this?
        let ptr = t.d.as_ptr() as usize;
        let idx = match &self.ixf {
            Some(c) if c.n == t.n && c.folded < c.nt => c.ptrs.iter().position(|&p| p == ptr),
            _ => None,
        };
        let Some(k) = idx else {
            // Not the expected fold: a cold fold is PCIe-bound — decline. A
            // LAZY chain alive here would mean the host copies are stale
            // while an unexpected caller folds a table: protocol violation.
            if let Some(c) = &self.ixf {
                assert!(!c.lazy, "[UPERF2-L] K-field ixf chain broken: an unexpected fold (table {:#x}, n {}) while the chain holds device-only state", ptr, t.n);
            }
            self.ixf = None;
            return Ok(false);
        };
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let c = self.ixf.as_ref().unwrap();
        let in_buf = c.buf[k];
        let out_buf = in_buf ^ 1;
        let out_bytes = nblk * KBLK * 4;
        self.grow_dev(DevSel::Ixf(k, out_buf), out_bytes)?;
        let mut p = K9Params::new(kern);
        let mut prm0 = Prm::new();
        prm0.set_vec(PRM_R, &super::super::kfield::kop(r));
        p.prm = self.upload_prm(std::slice::from_ref(&prm0))?;
        let src = self.ixf_t[k][in_buf].ptr;
        let dst = self.ixf_t[k][out_buf].ptr;
        let n_u = n_out as u32;
        let mut args: [*mut c_void; 4] = [&p as *const _ as *mut _, &src as *const _ as *mut _, &dst as *const _ as *mut _, &n_u as *const _ as *mut _];
        self.launch("k_fold_table", grid_for(n_out, TEL), TEL, &mut args)?;
        if profile() {
            self.sync_all()?;
        }
        // The folded table's host buffer is `scratch` (grown as kt_fold_par
        // does), swapped in. HANDOVER RULE: the output is copied to the host
        // when the successor round would not be taken by the device (its
        // n_pairs below the minimum — the CPU round / the scalar tail read
        // the host) or under the eager knob; otherwise it stays device-only
        // (the successor round is guaranteed by the loop: `while packed[0].n
        // >= 2 KL` re-checked right after these folds).
        let succ_taken = n_out / (2 * KL) >= min_pairs();
        if !succ_taken || eager() {
            // Handover / eager: the folded table lands in `scratch`, swapped
            // in exactly as kt_fold_par does.
            if scratch.len() < nblk * KBLK {
                if scratch.is_empty() {
                    // calloc: zero pages faulted in only where written (the
                    // CPU's `resize` would memset the whole buffer).
                    *scratch = vec![0u32; nblk * KBLK];
                } else {
                    scratch.resize(nblk * KBLK, 0);
                }
            }
            self.download_words(dst, &mut scratch[..nblk * KBLK])?;
            std::mem::swap(&mut t.d, scratch);
            t.n = n_out;
            t.d.truncate(nblk * KBLK);
        } else {
            // Lazy: the host buffer keeps its (now stale) full length — the
            // caller's truncate/shrink_to_fit of the scratch and the table
            // then cost nothing (the CPU path's shrink of a 256 MB table is
            // an mremap that frees pages: ~5 ms per table per round at the
            // rig, most of lane D's `d.cl-folds`); the next round reads the
            // device copy; the handover writes the right length.
            t.n = n_out;
        }
        let c = self.ixf.as_mut().unwrap();
        c.buf[k] = out_buf;
        c.next_ptrs[k] = t.d.as_ptr() as usize;
        c.folded += 1;
        if succ_taken && !eager() {
            c.lazy = true;
        }
        if !succ_taken && c.folded == c.nt {
            // Every table handed over: the chain ends here.
            self.ixf = None;
        }
        Ok(true)
    }
}

// ---------------------------------------------------------------------------
// The tree step (the hook of kfield::k9_tree_climb_par).

pub fn k9_tree_climb(kern: &KKern, src: &BlkSrc, levels: usize, np: &mut [u32], nq: &mut [u32], out_nblk: usize) -> Option<()> {
    if !live() || !tree_enabled() {
        return None;
    }
    let kk = k9s()?;
    let mut k = kk.lock().unwrap();
    let t0 = Instant::now();
    match k.tree_climb(kern, src, levels, np, nq, out_nblk) {
        Ok(true) => {
            S_CLIMBS.fetch_add(1, Ordering::Relaxed);
            add_us(&S_CLIMB_US, t0.elapsed().as_secs_f64());
            Some(())
        }
        Ok(false) => None,
        Err(e) => {
            if !WARNED.swap(true, Ordering::Relaxed) {
                eprintln!("[UPERF2-L] gpu k9 tree climb failed ({e}); this and later K-field calls fall back to the CPU bodies");
            }
            k.release_all();
            DISABLED.store(true, Ordering::Relaxed);
            None
        }
    }
}

impl K9 {
    fn tree_climb(&mut self, kern: &KKern, src: &BlkSrc, levels: usize, np: &mut [u32], nq: &mut [u32], out_nblk: usize) -> Result<bool, String> {
        // Only worth it at size (the D2H of the output is the cost).
        if out_nblk < 4 * min_pairs() {
            return Ok(false);
        }
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let src_nblk = out_nblk << levels;
        let out_words = out_nblk * KBLK;
        // Budget: the source (packed: 2 tables) + the outputs (2 tables) +
        // one intermediate pair when levels > 1.
        let src_bytes = match src {
            BlkSrc::Packed { .. } => 2 * src_nblk * KBLK * 4,
            BlkSrc::Compact(c) => 2 * c.n * 4 + (K_DEG + 33 * 64) * 4,
            // [UPERF2-N] a device layer never reaches this hook on the fast path
            // (the tree store answers it in place); the CPU climb materializes.
            BlkSrc::Device { .. } => return Ok(false),
        };
        let inter_bytes = if levels > 1 { 2 * (out_nblk << (levels - 1)) * KBLK * 4 } else { 0 };
        let need = src_bytes + 2 * out_words * 4 + inter_bytes;
        let have = self.tree_src[0].bytes + self.tree_src[1].bytes + self.tree_out[0].bytes + self.tree_out[1].bytes;
        if self.held + need.saturating_sub(have) > self.budget {
            return Ok(false);
        }
        let mut p = K9Params::new(kern);
        p.prm = self.upload_prm(std::slice::from_ref(&Prm::new()))?;
        let mut pp = 0usize;
        // Level 1: from the source.
        let (mut cur_p, mut cur_q, mut cur_buf): (u64, u64, usize);
        let mut m = out_nblk << (levels - 1); // output blocks of the first step
        // Output buffers: ping-pong between tree_out[0] and [1]; the final
        // level lands where we then download from.
        let out_bytes_first = 2 * m * KBLK * 4;
        self.grow_dev(DevSel::TreeOut(0), out_bytes_first)?;
        match src {
            BlkSrc::Packed { p: sp, q: sq } => {
                self.grow_dev(DevSel::TreeSrc(0), src_nblk * KBLK * 4)?;
                self.grow_dev(DevSel::TreeSrc(1), src_nblk * KBLK * 4)?;
                self.upload_words(self.tree_src[0].ptr, &sp[..src_nblk * KBLK], &mut pp)?;
                self.upload_words(self.tree_src[1].ptr, &sq[..src_nblk * KBLK], &mut pp)?;
                self.compute_after_copies()?;
                let cp = self.tree_src[0].ptr;
                let cq = self.tree_src[1].ptr;
                let dp = self.tree_out[0].ptr;
                let dq = dp + (m * KBLK * 4) as u64;
                let n_u = (m * KL) as u32;
                let mut args: [*mut c_void; 6] = [
                    &p as *const _ as *mut _,
                    &cp as *const _ as *mut _,
                    &cq as *const _ as *mut _,
                    &dp as *const _ as *mut _,
                    &dq as *const _ as *mut _,
                    &n_u as *const _ as *mut _,
                ];
                self.launch("k_tree_step", grid_for(m * KL, TEL), TEL, &mut args)?;
                cur_p = dp;
                cur_q = dq;
                cur_buf = 0;
            }
            BlkSrc::Compact(c) => {
                assert!(src_nblk * KL <= c.n, "K9 gpu: compact climb range");
                let te = Instant::now();
                let Some(e) = cl_encode(c) else {
                    return Ok(false);
                };
                add_us(&S_ENCODE_US, te.elapsed().as_secs_f64());
                let meta = cl_meta(&e);
                self.grow_dev(DevSel::TreeSrc(0), e.words.len() * 4)?;
                self.grow_dev(DevSel::TreeSrc(1), meta.len() * 4)?;
                self.upload_words(self.tree_src[0].ptr, e.words, &mut pp)?;
                self.upload_words(self.tree_src[1].ptr, &meta, &mut pp)?;
                self.compute_after_copies()?;
                let w = self.tree_src[0].ptr;
                let alpha = self.tree_src[1].ptr;
                let exc = alpha + (K_DEG * 4) as u64;
                let n_exc = e.n_exc as u32;
                let e_base = 0u32;
                let dp = self.tree_out[0].ptr;
                let dq = dp + (m * KBLK * 4) as u64;
                let n_u = (m * KL) as u32;
                let mut args: [*mut c_void; 9] = [
                    &p as *const _ as *mut _,
                    &w as *const _ as *mut _,
                    &alpha as *const _ as *mut _,
                    &exc as *const _ as *mut _,
                    &n_exc as *const _ as *mut _,
                    &e_base as *const _ as *mut _,
                    &dp as *const _ as *mut _,
                    &dq as *const _ as *mut _,
                    &n_u as *const _ as *mut _,
                ];
                self.launch("k_tree_step_cl", grid_for(m * KL, TEL), TEL, &mut args)?;
                cur_p = dp;
                cur_q = dq;
                cur_buf = 0;
            }
            BlkSrc::Device { .. } => unreachable!("declined above"),
        }
        // Further levels.
        for _lev in 2..=levels {
            let m2 = m / 2;
            let nb = cur_buf ^ 1;
            self.grow_dev(DevSel::TreeOut(nb), 2 * m2 * KBLK * 4)?;
            let dp = self.tree_out[nb].ptr;
            let dq = dp + (m2 * KBLK * 4) as u64;
            let n_u = (m2 * KL) as u32;
            let mut args: [*mut c_void; 6] = [
                &p as *const _ as *mut _,
                &cur_p as *const _ as *mut _,
                &cur_q as *const _ as *mut _,
                &dp as *const _ as *mut _,
                &dq as *const _ as *mut _,
                &n_u as *const _ as *mut _,
            ];
            self.launch("k_tree_step", grid_for(m2 * KL, TEL), TEL, &mut args)?;
            cur_p = dp;
            cur_q = dq;
            cur_buf = nb;
            m = m2;
        }
        debug_assert_eq!(m, out_nblk);
        // Eager D2H of the layer.
        let td = Instant::now();
        self.download_words(cur_p, &mut np[..out_words])?;
        self.download_words(cur_q, &mut nq[..out_words])?;
        add_us(&S_CLIMB_D2H_US, td.elapsed().as_secs_f64());
        let _ = cur_buf;
        Ok(true)
    }
}

// ---------------------------------------------------------------------------
// [UPERF2-N] THE DEVICE TREE STORE (the hooks of gkr.rs `build_tree_from`,
// `PackedTree::layer` / `release` / `Drop`, and `BlkSrc::host_tabs`).

/// The smallest BIG layer index: 2^top_k > K9_SMALL_LAYER_N (the small top
/// layers are the host's; the descent reads them element by element).
fn tree_top_k() -> usize {
    K9_SMALL_LAYER_N.trailing_zeros() as usize + 1
}

/// The device store's checkpoint stride: `ZK_K9_CHECKPOINT` when >= 2, else
/// 2 (a "keep every layer" request cannot be honored in VRAM at the rig's
/// depths; the values do not depend on the policy).
fn tree_stride() -> usize {
    super::super::kfield::k9_checkpoint_stride().max(2)
}

/// Build the tree on the device: `Some(built)` = the store holds it (its
/// big layers per the checkpoint policy, the leaves) and `built.top_*` is
/// the smallest big layer downloaded for the host's small top layers; `None`
/// = declined (feature/knob off, oracle, shape, VRAM) — the CPU build runs.
pub fn k9_tree_build(kern: &KKern, leaves: &TreeLeaves, depth: usize) -> Option<DevTreeBuilt> {
    if !live() || !tree_store_enabled() {
        return None;
    }
    let kk = k9s()?;
    let mut k = kk.lock().unwrap();
    let t0 = Instant::now();
    match k.tree_build(kern, leaves, depth) {
        Ok(Some(b)) => {
            S_TREE_BUILDS.fetch_add(1, Ordering::Relaxed);
            add_us(&S_TREE_BUILD_US, t0.elapsed().as_secs_f64());
            if verbose() {
                eprintln!(
                    "[UPERF2-N] k9 tree build: id {} depth {depth} in {:.2} ms; store {} trees {:.2} GB; held {:.2} GB",
                    b.id,
                    t0.elapsed().as_secs_f64() * 1e3,
                    k.trees.len(),
                    k.tree_bytes as f64 / 1e9,
                    k.held as f64 / 1e9
                );
            }
            Some(b)
        }
        Ok(None) => {
            S_TREE_DECLINED.fetch_add(1, Ordering::Relaxed);
            None
        }
        Err(e) => {
            // A device error: nothing of this tree is kept (the CPU builds it);
            // the K-field kernels fall back from here on.
            if !WARNED.swap(true, Ordering::Relaxed) {
                eprintln!("[UPERF2-N] gpu k9 tree build failed ({e}); this and later K-field calls fall back to the CPU bodies");
            }
            k.release_all();
            DISABLED.store(true, Ordering::Relaxed);
            None
        }
    }
}

/// Materialize layer k of a device tree on the host (a download of a
/// resident layer, or a device climb + download). Independent of `live()`:
/// the store is the only copy of the big layers, and every CPU reader —
/// fusion off, a declined hook, the oracle routing, the bypass, the harness
/// — must keep reading. `None` = no such tree.
pub fn k9_tree_fetch(dev: DevLayer) -> Option<(KTab, KTab)> {
    let kk = k9s()?;
    let mut k = kk.lock().unwrap();
    if !k.trees.contains_key(&dev.tree) {
        return None;
    }
    let t0 = Instant::now();
    match k.tree_fetch(dev.tree, dev.k) {
        Ok(r) => {
            S_TREE_FETCHES.fetch_add(1, Ordering::Relaxed);
            add_us(&S_TREE_FETCH_US, t0.elapsed().as_secs_f64());
            if verbose() {
                eprintln!("[UPERF2-N] k9 tree fetch: tree {} layer {} ({} elements) to the host in {:.2} ms", dev.tree, dev.k, dev.n, t0.elapsed().as_secs_f64() * 1e3);
            }
            Some(r)
        }
        Err(e) => panic!("[UPERF2-N] device tree {} layer {} could not be materialized ({e}); the host has no copy", dev.tree, dev.k),
    }
}

/// Release the resident copy of layer k (lane H's discipline: consumed
/// layers go back top-down; the leaves stay). No-op for gap layers.
pub fn k9_tree_release(tree: u64, k: usize) {
    let Some(kk) = k9s() else { return };
    let mut s = kk.lock().unwrap();
    s.tree_release(tree, k);
}

/// Drop a device tree (the FracTree is gone).
pub fn k9_tree_drop(tree: u64) {
    let Some(kk) = k9s() else { return };
    let mut s = kk.lock().unwrap();
    s.tree_drop(tree);
}

/// Device bytes held by a tree (0 if unknown).
pub fn k9_tree_bytes(tree: u64) -> usize {
    let Some(kk) = k9s() else { return 0 };
    let s = kk.lock().unwrap();
    s.trees.get(&tree).map(|t| t.bytes).unwrap_or(0)
}

impl K9 {
    /// Allocate a store buffer: [UPERF2-P] a chunk of the buddy (the layer
    /// sizes recur across the trees of a pass — warm bytes, no cuMemAlloc
    /// after the slabs exist). Counted in `tree_bytes`.
    fn tree_alloc(&mut self, bytes: usize) -> Result<Chunk, String> {
        let ta = Instant::now();
        let c = self.alloc(bytes).map_err(|e| e.replace("K9 VRAM budget", "K9 VRAM budget (tree store)"))?;
        self.tree_bytes += c.bytes;
        note_peak(&S_TREE_BYTES_PEAK, self.tree_bytes);
        add_us(&P_TB_ALLOC_US, ta.elapsed().as_secs_f64());
        Ok(c)
    }

    /// Free a store buffer (the caller has synchronized): back to the buddy.
    fn tree_free(&mut self, c: Chunk) {
        self.tree_bytes -= c.bytes;
        self.free(c);
    }

    /// One tree step on the device: parents [0, n) from the children of a
    /// resident packed layer (`src = Ok((cp, cq))`) or of the compact leaves
    /// (`src = Err((w, meta, n_exc))`), written to (dp, dq).
    #[allow(clippy::type_complexity)]
    fn dev_step(&mut self, p: &K9Params, src: Result<(u64, u64), (u64, u64, usize)>, dp: u64, dq: u64, n: usize) -> Result<(), String> {
        let n_u = n as u32;
        match src {
            Ok((cp, cq)) => {
                let mut args: [*mut c_void; 6] = [
                    p as *const _ as *mut _,
                    &cp as *const _ as *mut _,
                    &cq as *const _ as *mut _,
                    &dp as *const _ as *mut _,
                    &dq as *const _ as *mut _,
                    &n_u as *const _ as *mut _,
                ];
                self.launch("k_tree_step", grid_for(n, TEL), TEL, &mut args)
            }
            Err((w, meta, n_exc)) => {
                let alpha = meta;
                let exc = meta + (K_DEG * 4) as u64;
                let n_exc_u = n_exc as u32;
                let e_base = 0u32;
                let mut args: [*mut c_void; 9] = [
                    p as *const _ as *mut _,
                    &w as *const _ as *mut _,
                    &alpha as *const _ as *mut _,
                    &exc as *const _ as *mut _,
                    &n_exc_u as *const _ as *mut _,
                    &e_base as *const _ as *mut _,
                    &dp as *const _ as *mut _,
                    &dq as *const _ as *mut _,
                    &n_u as *const _ as *mut _,
                ];
                self.launch("k_tree_step_cl", grid_for(n, TEL), TEL, &mut args)
            }
        }
    }

    /// The source of a step above layer `kk` of a tree: its resident packed
    /// layer, or the compact leaves when `kk` is the leaf layer.
    #[allow(clippy::type_complexity)]
    fn tree_src_of(&self, tree: u64, kk: usize) -> Result<Result<(u64, u64), (u64, u64, usize)>, String> {
        let t = self.trees.get(&tree).ok_or_else(|| format!("device tree {tree} is gone"))?;
        if let Some((p, q)) = &t.layers[kk] {
            return Ok(Ok((p.ptr, q.ptr)));
        }
        if kk == t.depth {
            if let Some((w, m, n_exc)) = &t.compact {
                return Ok(Err((w.ptr, m.ptr, *n_exc)));
            }
        }
        Err(format!("device tree {tree}: layer {kk} is not resident"))
    }

    /// The device build (see `k9_tree_build`). The transient of the build
    /// is one layer pair beyond the resident set; the small top layers are
    /// the host's (`top_k` downloaded, the host loop continues).
    fn tree_build(&mut self, kern: &KKern, leaves: &TreeLeaves, depth: usize) -> Result<Option<DevTreeBuilt>, String> {
        let top_k = tree_top_k();
        if depth <= top_k {
            return Ok(None);
        }
        let n = 1usize << depth;
        let stride = tree_stride();
        let keep = |k: usize| -> bool { k == depth || (depth - k) % stride == 0 };
        // Budget estimate: the leaves + the kept layers + the transient pair.
        let leaf_bytes = match leaves {
            TreeLeaves::Packed { .. } => 2 * n / KL * KBLK * 4,
            TreeLeaves::Compact(c) => {
                if c.exceptions().len() > CL_MAX_EXC {
                    return Ok(None);
                }
                c.words().len() * 4 + (K_DEG + 33 * c.exceptions().len()) * 4
            }
        };
        let mut need = leaf_bytes;
        for k in top_k..depth {
            if keep(k) {
                need += 2 * (1usize << k) / KL * KBLK * 4;
            }
        }
        need += 2 * (1usize << (depth - 1)) / KL * KBLK * 4 + 2 * (1usize << (depth - 2)) / KL * KBLK * 4;
        // [UPERF2-P] the free bytes of the buddy count (a released
        // checkpoint of the previous pair, a dead state): the estimate is
        // against used - free + need.
        let free_now = self.mem.total - self.mem.live;
        if self.used() + need.saturating_sub(free_now) > self.budget {
            self.make_room(need.saturating_sub(free_now));
        }
        let free_now = self.mem.total - self.mem.live;
        if self.used() + need.saturating_sub(free_now) > self.budget {
            if verbose() {
                eprintln!(
                    "[UPERF2-N] k9: tree build declined — VRAM budget (need {:.2} GB, used {:.2} (free in slabs {:.2}), budget {:.2})",
                    need as f64 / 1e9,
                    self.used() as f64 / 1e9,
                    free_now as f64 / 1e9,
                    self.budget as f64 / 1e9
                );
            }
            return Ok(None);
        }
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        // A fresh tree entry; on any error below its buffers are freed.
        let id = self.next_tree;
        self.next_tree += 1;
        let mut t = DevTree { depth, kern: *kern, layers: (0..=depth).map(|_| None).collect(), compact: None, bytes: 0 };
        let r = self.tree_build_into(kern, leaves, depth, top_k, &keep, &mut t);
        match r {
            Ok(built) => {
                self.trees.insert(id, t);
                Ok(Some(DevTreeBuilt { id, top_k, top_p: built.0, top_q: built.1 }))
            }
            Err(e) => {
                let _ = self.sync_all();
                for l in t.layers.iter_mut() {
                    if let Some((p, q)) = l.take() {
                        self.tree_free(p);
                        self.tree_free(q);
                    }
                }
                if let Some((w, m, _)) = t.compact.take() {
                    self.tree_free(w);
                    self.tree_free(m);
                }
                // A budget shortfall mid-build is a decline, not a device error.
                if e.starts_with("K9 VRAM budget") {
                    if verbose() {
                        eprintln!("[UPERF2-N] k9: tree build declined mid-way ({e})");
                    }
                    Ok(None)
                } else {
                    Err(e)
                }
            }
        }
    }

    fn tree_build_into(&mut self, kern: &KKern, leaves: &TreeLeaves, depth: usize, top_k: usize, keep: &dyn Fn(usize) -> bool, t: &mut DevTree) -> Result<(KTab, KTab), String> {
        let n = 1usize << depth;
        let mut pp = 0usize;
        let tu = Instant::now();
        // The leaves go up.
        match leaves {
            TreeLeaves::Packed { p, q, n: np } => {
                assert_eq!(*np, n);
                let bytes = n / KL * KBLK * 4;
                let bp = self.tree_alloc(bytes)?;
                let bq = self.tree_alloc(bytes)?;
                self.upload_words(bp.ptr, &p[..n / KL * KBLK], &mut pp)?;
                self.upload_words(bq.ptr, &q[..n / KL * KBLK], &mut pp)?;
                S_TREE_LEAF_BYTES.fetch_add(2 * bytes as u64, Ordering::Relaxed);
                t.bytes += bp.bytes + bq.bytes;
                t.layers[depth] = Some((bp, bq));
            }
            TreeLeaves::Compact(c) => {
                assert_eq!(c.n, n);
                let e = cl_encode(c).ok_or_else(|| "compact leaves: too many exceptions".to_string())?;
                let meta = cl_meta(&e);
                let bw = self.tree_alloc(e.words.len() * 4)?;
                let bm = self.tree_alloc(meta.len() * 4)?;
                self.upload_words(bw.ptr, e.words, &mut pp)?;
                self.upload_words(bm.ptr, &meta, &mut pp)?;
                S_TREE_LEAF_BYTES.fetch_add(((e.words.len() + meta.len()) * 4) as u64, Ordering::Relaxed);
                t.bytes += bw.bytes + bm.bytes;
                t.compact = Some((bw, bm, e.n_exc));
            }
        }
        self.compute_after_copies()?;
        add_us(&P_TB_UPLOAD_US, tu.elapsed().as_secs_f64());
        let mut p = K9Params::new(kern);
        p.prm = self.upload_prm(std::slice::from_ref(&Prm::new()))?;
        // Bottom-up: layers depth-1 .. top_k on the device; the source of
        // layer k is layer k+1 (resident until layer k exists, then freed
        // unless kept).
        for k in (top_k..depth).rev() {
            let half = 1usize << k;
            let bytes = half / KL * KBLK * 4;
            let np = self.tree_alloc(bytes)?;
            let nq = self.tree_alloc(bytes)?;
            let src = self.tree_src_of_local(t, k + 1)?;
            self.dev_step(&p, src, np.ptr, nq.ptr, half)?;
            t.bytes += np.bytes + nq.bytes;
            t.layers[k] = Some((np, nq));
            if k + 1 < depth && !keep(k + 1) {
                self.sync_all()?;
                if let Some((op, oq)) = t.layers[k + 1].take() {
                    t.bytes -= op.bytes + oq.bytes;
                    self.tree_free(op);
                    self.tree_free(oq);
                }
            }
        }
        // The smallest big layer to the host (the host loop builds the top).
        let n_top = 1usize << top_k;
        let mut tp = KTab::recycled(n_top);
        let mut tq = KTab::recycled(n_top);
        {
            let td = Instant::now();
            let (bp, bq) = t.layers[top_k].as_ref().expect("top layer");
            let (pp_, qp_) = (bp.ptr, bq.ptr);
            let words = n_top / KL * KBLK;
            self.download_words(pp_, &mut tp.d[..words])?;
            self.download_words(qp_, &mut tq.d[..words])?;
            add_us(&P_TB_DOWN_US, td.elapsed().as_secs_f64());
        }
        if !keep(top_k) {
            self.sync_all()?;
            if let Some((op, oq)) = t.layers[top_k].take() {
                t.bytes -= op.bytes + oq.bytes;
                self.tree_free(op);
                self.tree_free(oq);
            }
        }
        Ok((tp, tq))
    }

    /// `tree_src_of` for a tree not yet registered (the build).
    #[allow(clippy::type_complexity)]
    fn tree_src_of_local(&self, t: &DevTree, kk: usize) -> Result<Result<(u64, u64), (u64, u64, usize)>, String> {
        if let Some((p, q)) = &t.layers[kk] {
            return Ok(Ok((p.ptr, q.ptr)));
        }
        if kk == t.depth {
            if let Some((w, m, n_exc)) = &t.compact {
                return Ok(Err((w.ptr, m.ptr, *n_exc)));
            }
        }
        Err(format!("device tree (building): layer {kk} is not resident"))
    }

    /// Climb layer `k` of `tree` from its resident layer `src_k` (> k; the
    /// compact leaves when src_k is the leaf layer) into (dp, dq) — the
    /// whole layer, 2^k elements — with the intermediate levels through the
    /// climb scratch (grown by the caller). Stream-ordered on the compute
    /// stream; nothing is synchronized here.
    fn climb_layer(&mut self, tree: u64, k: usize, src_k: usize, dp: u64, dq: u64, scr: &[Chunk; 2]) -> Result<(), String> {
        // The K9P scalars are the tree's kernel constants recorded at build
        // time (the tree steps read no parameter vector; prm is a valid,
        // unread pointer).
        let kern = self.trees.get(&tree).ok_or_else(|| format!("device tree {tree} is gone"))?.kern;
        let mut p = K9Params::new(&kern);
        p.prm = self.prm_d.ptr;
        let levels = src_k - k;
        assert!(levels >= 1);
        let mut src = self.tree_src_of(tree, src_k)?;
        // Levels src_k-1 .. k+1 into the scratch (ping-pong), the last into (dp, dq).
        let mut cur = 0usize;
        for lev in 1..=levels {
            let out_k = src_k - lev;
            let m = 1usize << out_k;
            let (op, oq) = if lev == levels {
                (dp, dq)
            } else {
                let bytes = m / KL * KBLK * 4;
                assert!(scr[cur].bytes >= 2 * bytes, "K9 gpu: climb scratch");
                let base = scr[cur].ptr;
                (base, base + bytes as u64)
            };
            self.dev_step(&p, src, op, oq, m)?;
            src = Ok((op, oq));
            cur ^= 1;
        }
        Ok(())
    }

    /// Materialize layer k of a tree on the host.
    fn tree_fetch(&mut self, tree: u64, k: usize) -> Result<(KTab, KTab), String> {
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let (depth, resident, compact) = {
            let t = self.trees.get(&tree).ok_or_else(|| format!("device tree {tree} is gone"))?;
            (t.depth, t.layers[k].as_ref().map(|(p, q)| (p.ptr, q.ptr)), t.compact.is_some())
        };
        let n = 1usize << k;
        let words = n / KL * KBLK;
        let mut tp = KTab::recycled(n);
        let mut tq = KTab::recycled(n);
        if let Some((pp_, qp_)) = resident {
            self.download_words(pp_, &mut tp.d[..words])?;
            self.download_words(qp_, &mut tq.d[..words])?;
            return Ok((tp, tq));
        }
        if k == depth {
            // The compact leaves: expanded on the host by the caller (never
            // fetched); a packed leaf layer is resident by construction.
            return Err(if compact { "the compact leaves are read on the host".to_string() } else { "the leaves are not resident".to_string() });
        }
        // A gap layer: climb into the layer buffers (the LayerRes that may
        // reference them is dropped — the next round re-binds), then download.
        let src_k = {
            let t = self.trees.get(&tree).unwrap();
            (k + 1..=depth).find(|&kk| t.layers[kk].is_some() || (kk == depth && t.compact.is_some())).ok_or_else(|| "no resident layer below".to_string())?
        };
        let bytes = words * 4;
        let scr_bytes = if src_k - k >= 2 { 2 * (1usize << (src_k - 1)) / KL * KBLK * 4 } else { 0 };
        // [UPERF2-P] fresh chunks for the target + the scratch, freed after
        // the download (the layer binding, if any, keeps its own chunks).
        let mut tmp: Vec<Chunk> = Vec::new();
        let r = (|| -> Result<(), String> {
            let cp = self.alloc(bytes)?;
            tmp.push(cp);
            let cq = self.alloc(bytes)?;
            tmp.push(cq);
            let mut scr = [Chunk::NONE; 2];
            if scr_bytes > 0 {
                scr[0] = self.alloc(scr_bytes)?;
                tmp.push(scr[0]);
                scr[1] = self.alloc(scr_bytes)?;
                tmp.push(scr[1]);
            }
            self.climb_layer(tree, k, src_k, cp.ptr, cq.ptr, &scr)?;
            S_DEV_CLIMBS.fetch_add(1, Ordering::Relaxed);
            self.download_words(cp.ptr, &mut tp.d[..words])?;
            self.download_words(cq.ptr, &mut tq.d[..words])?;
            Ok(())
        })();
        let _ = self.sync_all();
        for c in tmp {
            self.free(c);
        }
        r?;
        Ok((tp, tq))
    }

    fn tree_release(&mut self, tree: u64, k: usize) {
        let Some(t) = self.trees.get_mut(&tree) else { return };
        if k >= t.depth {
            return;
        }
        if t.layers[k].is_none() {
            return;
        }
        // Any thread may release / drop (a FracTree drop): bind the context.
        let _ = self.dev.bind_to_thread();
        // A LayerRes pointing into it must not survive.
        let drop_binding = self.layer.as_ref().is_some_and(|l| l.ids.iter().any(|(id, _)| matches!(id, LayerId::Device { tree: tt, k: kk } if *tt == tree && *kk == k)));
        if drop_binding {
            self.release_layer_bufs();
        }
        let _ = self.sync_all();
        let t = self.trees.get_mut(&tree).unwrap();
        if let Some((p, q)) = t.layers[k].take() {
            t.bytes -= p.bytes + q.bytes;
            self.tree_free(p);
            self.tree_free(q);
        }
    }

    fn tree_drop(&mut self, tree: u64) {
        let Some(mut t) = self.trees.remove(&tree) else { return };
        let _ = self.dev.bind_to_thread();
        let drop_binding = self.layer.as_ref().is_some_and(|l| l.ids.iter().any(|(id, _)| matches!(id, LayerId::Device { tree: tt, .. } if *tt == tree)));
        if drop_binding {
            self.release_layer_bufs();
        }
        let _ = self.sync_all();
        for l in t.layers.iter_mut() {
            if let Some((p, q)) = l.take() {
                self.tree_free(p);
                self.tree_free(q);
            }
        }
        if let Some((w, m, _)) = t.compact.take() {
            self.tree_free(w);
            self.tree_free(m);
        }
    }
}

// ---------------------------------------------------------------------------
// [UPERF2-P] THE EQ B-PART ON THE DEVICE (the hook of kfield::EqTab::new).
// eq over zeta[..j] (2^j entries) = lo[i mod 2^lb] x hi[i >> lb] with lo =
// the eq table over zeta[..lb] and hi = the eq table over zeta[lb..] (both
// tiny, built on the host by `kt_eq_table_par`, uploaded once), one product
// kernel — the same canonical field product as the doubling's (a product of
// the same factors; canonical representatives are unique), so the same bytes
// as the host table. The table is a chunk of the buddy (ONE resident eq at
// a time — the descent builds one per layer, the fused rounds 0/1 of that
// layer bind it in place, `EqTab`'s drop frees it); the host image is never
// downloaded — a CPU reader rebuilds it (`EqTab::host`).

/// Build the eq b-part on the device: `Some(id)` = resident (bound by the
/// fused rounds through the plan's `eq_tab`); `None` = declined (not live,
/// knob off, budget) — the host build runs.
pub fn k9_eq_build(kf: &KField, zeta: &[KElem]) -> Option<u64> {
    if !live() || !eq_dev() {
        return None;
    }
    let kern = kf.kern.as_ref()?;
    let kk = k9s()?;
    let mut k = kk.lock().unwrap();
    let t0 = Instant::now();
    match k.eq_build(kf, kern, zeta) {
        Ok(Some(id)) => {
            P_EQ_BUILDS.fetch_add(1, Ordering::Relaxed);
            add_us(&P_EQ_BUILD_US, t0.elapsed().as_secs_f64());
            if verbose() {
                eprintln!("[UPERF2-P] k9 eq build: id {id} 2^{} entries in {:.2} ms", zeta.len(), t0.elapsed().as_secs_f64() * 1e3);
            }
            Some(id)
        }
        Ok(None) => None,
        Err(e) => {
            if !WARNED.swap(true, Ordering::Relaxed) {
                eprintln!("[UPERF2-P] gpu k9 eq build failed ({e}); this and later K-field calls fall back to the CPU bodies");
            }
            k.release_all();
            DISABLED.store(true, Ordering::Relaxed);
            None
        }
    }
}

/// The eq table's handle is gone: its chunk goes back.
pub fn k9_eq_drop(id: u64) {
    let Some(kk) = k9s() else { return };
    let mut k = kk.lock().unwrap();
    if k.eq.as_ref().map(|e| e.id) == Some(id) {
        let _ = k.dev.bind_to_thread();
        k.release_eq();
    }
}

impl K9 {
    fn eq_build(&mut self, kf: &KField, kern: &KKern, zeta: &[KElem]) -> Result<Option<u64>, String> {
        let j = zeta.len();
        let n = 1usize << j;
        // The split: lo gets the low half of the variables (>= 3 bits so
        // that both halves are whole packed blocks).
        let lb = (j / 2).max(3);
        let hb = j - lb;
        if hb < 3 {
            return Ok(None);
        }
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        // A resident eq (an earlier layer's) is superseded.
        self.release_eq();
        let bytes = n / KL * KBLK * 4;
        let lo_words = (1usize << lb) / KL * KBLK;
        let hi_words = (1usize << hb) / KL * KBLK;
        // The table + the two halves (transient): declined on a shortfall
        // (the host build runs) — never a device error.
        let mut tmp: Vec<Chunk> = Vec::new();
        let (ct, cl, ch) = match (|| -> Result<(Chunk, Chunk, Chunk), String> {
            let ct = self.alloc(bytes)?;
            tmp.push(ct);
            let cl = self.alloc(lo_words * 4)?;
            tmp.push(cl);
            let ch = self.alloc(hi_words * 4)?;
            tmp.push(ch);
            Ok((ct, cl, ch))
        })() {
            Ok(v) => v,
            Err(e) => {
                for c in tmp {
                    self.free(c);
                }
                if e.starts_with("K9 VRAM budget") {
                    return Ok(None);
                }
                return Err(e);
            }
        };
        // The halves on the host (canonical products), then up.
        let lo = kf.kt_eq_table_par(&zeta[..lb]);
        let hi = kf.kt_eq_table_par(&zeta[lb..]);
        debug_assert_eq!(lo.d.len(), lo_words);
        debug_assert_eq!(hi.d.len(), hi_words);
        let mut pp = 0usize;
        self.upload_words(cl.ptr, &lo.d[..lo_words], &mut pp)?;
        self.upload_words(ch.ptr, &hi.d[..hi_words], &mut pp)?;
        self.compute_after_copies()?;
        let mut p = K9Params::new(kern);
        p.prm = self.upload_prm(std::slice::from_ref(&Prm::new()))?;
        let (lo_ptr, hi_ptr, out) = (cl.ptr, ch.ptr, ct.ptr);
        let n_u = n as u32;
        let lb_u = lb as u32;
        let mut args: [*mut c_void; 6] = [
            &p as *const _ as *mut _,
            &lo_ptr as *const _ as *mut _,
            &hi_ptr as *const _ as *mut _,
            &out as *const _ as *mut _,
            &n_u as *const _ as *mut _,
            &lb_u as *const _ as *mut _,
        ];
        self.launch("k_eq_outer", grid_for(n, TEL), TEL, &mut args)?;
        // The halves are consumed once the kernel is done (a sync; the
        // build is once per layer).
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk: {e}"))?;
        self.free(cl);
        self.free(ch);
        let id = self.next_eq;
        self.next_eq += 1;
        self.eq = Some(EqRes { id, n, ch: ct });
        Ok(Some(id))
    }
}

/// Harness accessor: the resident device eq table's words (a download), if
/// `id` is the resident one. Not used by the prover (the host image is
/// rebuilt, never downloaded).
pub fn k9_eq_fetch(id: u64) -> Option<Vec<u32>> {
    let kk = k9s()?;
    let mut k = kk.lock().unwrap();
    let (cur, n, ptr) = k.eq.as_ref().map(|e| (e.id, e.n, e.ch.ptr))?;
    if cur != id {
        return None;
    }
    let words = n / KL * KBLK;
    let mut out = vec![0u32; words];
    let _ = k.dev.bind_to_thread();
    k.download_words(ptr, &mut out).ok()?;
    Some(out)
}

// ---------------------------------------------------------------------------
// [UPERF2-P] THE K-MULT PROBE (analysis only, `uperf-p kprobe`): a separate
// tiny module (its own NVRTC compile — seconds, not the K9 module's minutes)
// measuring the register-only throughput of the K-field product as the
// round kernels compute it (the same kmac/kred chain, copied), at a chosen
// number of independent chains per thread (ILP) and blocks per SM
// (occupancy). It tells whether the round kernels sit at the arithmetic's
// own ceiling on this part or below it (memory / structure).
const KPROBE_SRC: &str = r#"
typedef unsigned long long u64;
typedef unsigned int u32;
#define KDEG 16
#define M32 0xFFFFFFFFULL
#define M31 0x7FFFFFFFULL
__device__ __forceinline__ u64 madw(u32 a, u32 b, u64 c) { u64 r; asm("mad.wide.u32 %0, %1, %2, %3;" : "=l"(r) : "r"(a), "r"(b), "l"(c)); return r; }
__device__ __forceinline__ u64 fold31(u64 v, u32 c31) { return madw(c31, (u32)(v >> 31), v & M31); }
__device__ __forceinline__ u32 canon1(u64 v, u32 q) { u32 r = (u32)v; u32 r2 = r - q; return (r < q) ? r : r2; }
__device__ __forceinline__ void kmac(const u32* a, const u32* b, u64* acc, u32 c32) {
#pragma unroll
    for (int t = 0; t < 31; t++) {
        const int i0 = (t < 15) ? 0 : (t - 15);
        const int i1 = (t < 15) ? t : 15;
        u64 s = 0; int cnt = 0;
#pragma unroll
        for (int i = i0; i <= i1; i++) {
            s = madw(a[i], b[t - i], s); cnt++;
            if (cnt == 4) { acc[t] += madw(c32, (u32)(s >> 32), s & M32); s = 0; cnt = 0; }
        }
        if (cnt) acc[t] += madw(c32, (u32)(s >> 32), s & M32);
    }
}
__device__ __forceinline__ void kred(const u64* acc, u32* out, u32 q, u32 s, u32 c31) {
    u32 h[15];
#pragma unroll
    for (int t = 0; t < 15; t++) h[t] = canon1(fold31(acc[t + 16], c31), q);
#pragma unroll
    for (int t = 0; t < 16; t++) { u64 v = (t < 15) ? madw(s, h[t], acc[t]) : acc[t]; v = fold31(v, c31); v = fold31(v, c31); out[t] = canon1(v, q); }
}
__device__ __forceinline__ void kmul(const u32* a, const u32* b, u32* out, u32 q, u32 s, u32 c31, u32 c32) {
    u64 acc[31];
#pragma unroll
    for (int t = 0; t < 31; t++) acc[t] = 0;
    kmac(a, b, acc, c32);
    kred(acc, out, q, s, c31);
}
// mode 0: one dependent chain per thread (a = a * b); mode 1: two chains;
// mode 2: four chains. `iters` products per chain. The result is folded into
// out[thread] so nothing is dead.
template <int CH>
__device__ __forceinline__ void probe_body(u32 q, u32 s, u32 c31, u32 c32, u32 iters, u32* out) {
    const u32 tid = blockIdx.x * blockDim.x + threadIdx.x;
    u32 a[CH][KDEG], b[KDEG];
#pragma unroll
    for (int j = 0; j < KDEG; j++) { b[j] = (tid * 2654435761u + j * 40503u) % q; }
#pragma unroll
    for (int c = 0; c < CH; c++)
#pragma unroll
        for (int j = 0; j < KDEG; j++) a[c][j] = (tid * 97u + c * 131u + j * 7u + 1u) % q;
    for (u32 it = 0; it < iters; it++) {
#pragma unroll
        for (int c = 0; c < CH; c++) {
            u32 o[KDEG];
            kmul(a[c], b, o, q, s, c31, c32);
#pragma unroll
            for (int j = 0; j < KDEG; j++) a[c][j] = o[j];
        }
    }
    u32 acc = 0;
#pragma unroll
    for (int c = 0; c < CH; c++)
#pragma unroll
        for (int j = 0; j < KDEG; j++) acc ^= a[c][j];
    out[tid] = acc;
}
extern "C" __global__ void k_probe1(u32 q, u32 s, u32 c31, u32 c32, u32 iters, u32* out) { probe_body<1>(q, s, c31, c32, iters, out); }
extern "C" __global__ void k_probe2(u32 q, u32 s, u32 c31, u32 c32, u32 iters, u32* out) { probe_body<2>(q, s, c31, c32, iters, out); }
extern "C" __global__ void k_probe4(u32 q, u32 s, u32 c31, u32 c32, u32 iters, u32* out) { probe_body<4>(q, s, c31, c32, iters, out); }
"#;

/// Run the probe: (chains, blocks_per_sm, threads_per_block, iters) ->
/// (kernel seconds, K-mults per second, occupancy blocks/SM the driver
/// reports for that block size).
pub fn k9_kprobe(kern: &KKern, chains: u32, blocks_per_sm: u32, tpb: u32, iters: u32) -> Result<(f64, f64, u32), String> {
    let dev = device_handle().ok_or_else(|| "no device".to_string())?;
    dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
    static LOADED: OnceLock<Result<(), String>> = OnceLock::new();
    let r = LOADED.get_or_init(|| {
        let major = dev.attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR).map_err(|e| e.to_string())?;
        let minor = dev.attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR).map_err(|e| e.to_string())?;
        let opts = CompileOptions { arch: arch_str((major, minor)), ..Default::default() };
        let ptx = compile_ptx_with_opts(KPROBE_SRC, opts).map_err(|e| format!("NVRTC (probe): {e}"))?;
        dev.load_ptx(ptx, "zkgpu_k9probe", &["k_probe1", "k_probe2", "k_probe4"]).map_err(|e| format!("load (probe): {e}"))
    });
    r.clone()?;
    let name = match chains {
        1 => "k_probe1",
        2 => "k_probe2",
        _ => "k_probe4",
    };
    let f = dev.get_func("zkgpu_k9probe", name).ok_or_else(|| "probe fn".to_string())?;
    let sms = dev.attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT).map_err(|e| e.to_string())? as u32;
    let occ = f.occupancy_max_active_blocks_per_multiprocessor(tpb, 0, None).unwrap_or(0);
    let grid = sms * blocks_per_sm;
    let mut out = DevBuf::empty();
    out.grow((grid * tpb) as usize * 4)?;
    let (q, s, c31, c32) = (kern.q as u32, kern.s as u32, kern.c31 as u32, kern.c32 as u32);
    let stream = dev.fork_default_stream().map_err(|e| e.to_string())?;
    let launch = |iters: u32| -> Result<f64, String> {
        let cfg = LaunchConfig { grid_dim: (grid, 1, 1), block_dim: (tpb, 1, 1), shared_mem_bytes: 0 };
        let optr = out.ptr;
        let mut args: [*mut c_void; 6] = [
            &q as *const _ as *mut _,
            &s as *const _ as *mut _,
            &c31 as *const _ as *mut _,
            &c32 as *const _ as *mut _,
            &iters as *const _ as *mut _,
            &optr as *const _ as *mut _,
        ];
        unsafe { cu::stream::synchronize(stream.stream) }.map_err(|e| e.to_string())?;
        let t0 = Instant::now();
        unsafe { f.clone().launch_on_stream(&stream, cfg, &mut args[..]) }.map_err(|e| format!("launch probe: {e}"))?;
        unsafe { cu::stream::synchronize(stream.stream) }.map_err(|e| e.to_string())?;
        Ok(t0.elapsed().as_secs_f64())
    };
    let _ = launch(1)?; // warm (JIT)
    let secs = launch(iters)?;
    let kmuls = (grid * tpb) as f64 * iters as f64 * chains as f64;
    Ok((secs, kmuls / secs, occ))
}

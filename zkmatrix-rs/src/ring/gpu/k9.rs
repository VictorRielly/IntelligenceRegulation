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
];
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

/// One live range's placement in the device layout of a state: `blk0` =
/// its first device block (per table), `n_blk` = its blocks.
#[derive(Clone, Copy, Debug)]
struct Region {
    blk0: usize,
    n_blk: usize,
}

/// The descent chain: state t of one layer, device-resident.
struct Chain {
    /// The host buffers (eq, pl, p1, q0, q1) the state belongs to.
    ptrs: [usize; 5],
    /// State-t pair-blocks per table (== the successor's 2 x n_pairs).
    out_pairs: usize,
    /// The live pair-block ranges of state t.
    ranges: Vec<(usize, usize)>,
    /// The device layout: region per range; per-table stride (blocks).
    regions: Vec<Region>,
    tab_blk: usize,
    /// Which ping-pong buffer holds state t.
    buf: usize,
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
    layers: Vec<Option<(DevBuf, DevBuf)>>,
    /// The compact leaves: (words: 2 per leaf, meta: alpha[16] + the
    /// exceptions x 33 words, n_exc).
    compact: Option<(DevBuf, DevBuf, usize)>,
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
    // Descent.
    st: [DevBuf; 2],
    lay_p: DevBuf,
    lay_q: DevBuf,
    cl_w: DevBuf,
    cl_meta: DevBuf,
    eqb: DevBuf,
    partial: DevBuf,
    partial_h: HostPinned,
    prm_d: DevBuf,
    prm_h: HostPinned,
    chain: Option<Chain>,
    layer: Option<LayerRes>,
    // Ixf.
    ixf_t: Vec<[DevBuf; 2]>,
    ixf: Option<IxfChain>,
    // Tree.
    tree_src: [DevBuf; 2],
    tree_out: [DevBuf; 2],
    // [UPERF2-N] The device tree store + the intermediate-level scratch of
    // the in-hook climbs (descent family: freed with the layer buffers).
    trees: std::collections::HashMap<u64, DevTree>,
    next_tree: u64,
    tree_bytes: usize,
    climb_scr: [DevBuf; 2],
    // Budget.
    budget: usize,
    held: usize,
    last_kernel_ms: f64,
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
    let mut prm_d = DevBuf::empty();
    prm_d.grow(PRM_SLOTS * PRM_WORDS * 4)?;
    let mut prm_h = HostPinned::empty();
    prm_h.grow(PRM_SLOTS * PRM_WORDS * 4)?;
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
        st: [DevBuf::empty(), DevBuf::empty()],
        lay_p: DevBuf::empty(),
        lay_q: DevBuf::empty(),
        cl_w: DevBuf::empty(),
        cl_meta: DevBuf::empty(),
        eqb: DevBuf::empty(),
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
        climb_scr: [DevBuf::empty(), DevBuf::empty()],
        budget,
        held: 0,
        last_kernel_ms: 0.0,
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
                "k9: on — K-field kernels on the device (budget {:.2} GB, held {:.2} GB, min_pairs {}, eager {}; tree store {} — {} trees, {:.2} GB)",
                k.budget as f64 / 1e9,
                k.held as f64 / 1e9,
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

    /// Grow a device buffer within the budget (synchronizes first when it
    /// must reallocate). When the budget is short, the buffers of the OTHER
    /// families (the descent's, the ixf's, the tree's — only one is active
    /// at a time; a family with a live chain is never released) are given
    /// back first.
    fn grow_dev(&mut self, which: DevSel, bytes: usize) -> Result<(), String> {
        let cur = self.sel(which).bytes;
        if bytes <= cur {
            return Ok(());
        }
        let need = bytes - cur;
        if self.held + need > self.budget {
            self.release_idle(which);
        }
        if self.held + need > self.budget {
            return Err(format!(
                "K9 VRAM budget: need {:.2} GB more (held {:.2} GB, budget {:.2} GB)",
                need as f64 / 1e9,
                self.held as f64 / 1e9,
                self.budget as f64 / 1e9
            ));
        }
        self.sync_all()?;
        let b = self.sel(which);
        let old = b.bytes;
        b.grow(bytes)?;
        let new = b.bytes;
        self.held = self.held + new - old;
        note_peak(&S_HELD_PEAK, self.held);
        Ok(())
    }

    /// Free the idle families' buffers (never a family whose chain is alive;
    /// `which` = the buffer about to grow — its own family is kept unless it
    /// is idle too, i.e. a descent's layer/state buffers between layers).
    fn release_idle(&mut self, which: DevSel) {
        let _ = self.sync_all();
        let fam = match which {
            DevSel::St(_) | DevSel::LayP | DevSel::LayQ | DevSel::ClW | DevSel::ClMeta | DevSel::Eqb | DevSel::ClimbScr(_) => 0,
            DevSel::Ixf(..) => 1,
            DevSel::TreeSrc(_) | DevSel::TreeOut(_) => 2,
        };
        let mut freed = 0usize;
        if (fam != 0 || matches!(which, DevSel::LayP | DevSel::LayQ | DevSel::ClW | DevSel::ClMeta | DevSel::Eqb | DevSel::ClimbScr(_))) && self.chain.is_none() {
            for b in self.st.iter_mut() {
                freed += b.bytes;
                b.free();
            }
            let [c0, c1] = &mut self.climb_scr;
            for b in [&mut self.lay_p, &mut self.lay_q, &mut self.cl_w, &mut self.cl_meta, &mut self.eqb, c0, c1] {
                freed += b.bytes;
                b.free();
            }
            self.layer = None;
        }
        if fam != 1 && self.ixf.is_none() {
            for t in self.ixf_t.iter_mut() {
                freed += t[0].bytes + t[1].bytes;
                t[0].free();
                t[1].free();
            }
        }
        if fam != 2 {
            for b in self.tree_src.iter_mut().chain(self.tree_out.iter_mut()) {
                freed += b.bytes;
                b.free();
            }
        }
        self.held -= freed;
        if verbose() && freed > 0 {
            eprintln!("[UPERF2-L] k9: released {:.2} GB of idle device buffers", freed as f64 / 1e9);
        }
    }

    /// Free the layer buffers (round 1 consumed them; the next layer grows
    /// them again — VRAM for the state tables of the big layers).
    /// [UPERF2-N] the climb scratch goes with them.
    fn release_layer_bufs(&mut self) {
        let _ = self.sync_all();
        let mut freed = 0usize;
        let [c0, c1] = &mut self.climb_scr;
        for b in [&mut self.lay_p, &mut self.lay_q, &mut self.cl_w, &mut self.cl_meta, c0, c1] {
            freed += b.bytes;
            b.free();
        }
        self.held -= freed;
        self.layer = None;
    }

    fn sel(&mut self, which: DevSel) -> &mut DevBuf {
        match which {
            DevSel::St(i) => &mut self.st[i],
            DevSel::LayP => &mut self.lay_p,
            DevSel::LayQ => &mut self.lay_q,
            DevSel::ClW => &mut self.cl_w,
            DevSel::ClMeta => &mut self.cl_meta,
            DevSel::Eqb => &mut self.eqb,
            DevSel::Ixf(k, i) => {
                while self.ixf_t.len() <= k {
                    self.ixf_t.push([DevBuf::empty(), DevBuf::empty()]);
                }
                &mut self.ixf_t[k][i]
            }
            DevSel::TreeSrc(i) => &mut self.tree_src[i],
            DevSel::TreeOut(i) => &mut self.tree_out[i],
            DevSel::ClimbScr(i) => &mut self.climb_scr[i],
        }
    }

    /// [UPERF2-N] Free every idle family (a tree build / a fetch needs the
    /// room): the descent's buffers when no chain is alive, the ixf tables
    /// when no ixf chain is alive, the climb scratch. The tree store itself
    /// is never released here.
    fn release_idle_all(&mut self) {
        let _ = self.sync_all();
        let mut freed = 0usize;
        if self.chain.is_none() {
            for b in self.st.iter_mut() {
                freed += b.bytes;
                b.free();
            }
            let [c0, c1] = &mut self.climb_scr;
            for b in [&mut self.lay_p, &mut self.lay_q, &mut self.cl_w, &mut self.cl_meta, &mut self.eqb, c0, c1] {
                freed += b.bytes;
                b.free();
            }
            self.layer = None;
        }
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
        if verbose() && freed > 0 {
            eprintln!("[UPERF2-N] k9: released {:.2} GB of idle device buffers for the tree store", freed as f64 / 1e9);
        }
    }

    /// The device error path: every K-field chain buffer goes back and the
    /// chains are dropped. [UPERF2-N] the TREE STORE STAYS — its layers are
    /// the only copy of the big layers of the trees the host still holds,
    /// and `k9_tree_fetch` (a plain download) must keep answering.
    fn release_all(&mut self) {
        let _ = self.sync_all();
        for b in self.st.iter_mut() {
            b.free();
        }
        self.lay_p.free();
        self.lay_q.free();
        self.cl_w.free();
        self.cl_meta.free();
        self.eqb.free();
        for t in self.ixf_t.iter_mut() {
            t[0].free();
            t[1].free();
        }
        for b in self.tree_src.iter_mut().chain(self.tree_out.iter_mut()).chain(self.climb_scr.iter_mut()) {
            b.free();
        }
        self.held = self.tree_bytes;
        self.chain = None;
        self.layer = None;
        self.ixf = None;
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
        assert!(slots.len() <= PRM_SLOTS, "K9 gpu: too many parameter slots ({} ranges)", slots.len());
        // The previous round's launches must be done with the staging.
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk: {e}"))?;
        let h = self.prm_h.slice_mut::<u32>(slots.len() * PRM_WORDS);
        for (i, p) in slots.iter().enumerate() {
            h[i * PRM_WORDS..(i + 1) * PRM_WORDS].copy_from_slice(&p.0);
        }
        unsafe { cu::memcpy_htod_async(self.prm_d.ptr, self.prm_h.slice::<u32>(slots.len() * PRM_WORDS), self.sk.stream) }
            .map_err(|e| format!("h2d prm: {e}"))?;
        Ok(self.prm_d.ptr)
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

#[derive(Clone, Copy)]
enum DevSel {
    St(usize),
    LayP,
    LayQ,
    ClW,
    ClMeta,
    Eqb,
    Ixf(usize, usize),
    TreeSrc(usize),
    TreeOut(usize),
    /// [UPERF2-N] the in-hook climb's intermediate-level scratch (descent family).
    ClimbScr(usize),
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
            let (regions, tab_blk) = layout(&prev);
            let bytes = 5 * tab_blk * KBLK * 4;
            if let Err(e) = self.grow_dev(DevSel::St(0), bytes) {
                if verbose() {
                    eprintln!("[UPERF2-L] k9: cold fold declined ({e})");
                }
                return Ok(false);
            }
            let mut pp = 0usize;
            for (ri, &(a, b)) in prev.iter().enumerate() {
                for k in 0..5 {
                    let src: &[u32] = if k == 0 { &eq_inplace[2 * a * KBLK..2 * b * KBLK] } else { &tabs[k - 1][2 * a * KBLK..2 * b * KBLK] };
                    let dst = self.st[0].ptr + (((k * tab_blk) + regions[ri].blk0) * KBLK * 4) as u64;
                    self.upload_words(dst, src, &mut pp)?;
                }
            }
            self.compute_after_copies()?;
            let ptrs = [eq_inplace.as_ptr() as usize, tabs[0].as_ptr() as usize, tabs[1].as_ptr() as usize, tabs[2].as_ptr() as usize, tabs[3].as_ptr() as usize];
            self.chain = Some(Chain { ptrs, out_pairs: 2 * n_pairs, ranges: prev, regions, tab_blk, buf: 0 });
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
                let eq_id = (eq_src.as_ptr() as usize, eq_src.len());
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
                    self.layer = None;
                    let tu = Instant::now();
                    if !self.upload_layer(plan, n_pairs, &ranges, eq_src, &ids)? {
                        return Ok(false);
                    }
                    add_us(&S_UPLOAD_US, tu.elapsed().as_secs_f64());
                    S_LAYER_UP.fetch_add(1, Ordering::Relaxed);
                }
                // (2) The state-1 output buffer (EXTRACT_FOLD).
                let f_blk = if mode == FUSE_EXTRACT { 4usize } else { 8 };
                let fe_blk = if mode == FUSE_EXTRACT { 2usize } else { 4 };
                let (regions, tab_blk) = layout(&ranges);
                let buf = 0usize;
                if mode == FUSE_EXTRACT_FOLD {
                    let bytes = 5 * tab_blk * KBLK * 4;
                    if let Err(e) = self.grow_dev(DevSel::St(buf), bytes) {
                        if verbose() {
                            eprintln!("[UPERF2-L] k9: extract-fold declined ({e})");
                        }
                        self.layer = None;
                        return Ok(false);
                    }
                }
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
                let prm_base = self.upload_prm(&slots)?;
                self.zero_partial()?;
                if profile() {
                    self.sync_all()?;
                }
                let tk = Instant::now();
                let layer = self.layer.as_ref().unwrap();
                for (ri, &(a, b)) in ranges.iter().enumerate() {
                    let n = 8 * (b - a);
                    let la = a - plan.layers[ri].first_pair;
                    let mut pr = p;
                    pr.prm = prm_base + (ri * PRM_WORDS * 4) as u64;
                    if plan.layers[ri].ee.is_some() {
                        pr.has_ee = 1;
                    }
                    let eq_ptr = self.eqb.ptr + ((fe_blk * la) * KBLK * 4) as u64;
                    let n_u = n as u32;
                    let part = self.partial.ptr;
                    let grid = grid_for(n, TK9);
                    let reg = regions[ri];
                    let outs: [u64; 5] = std::array::from_fn(|k| self.st[buf].ptr + (((k * tab_blk) + reg.blk0) * KBLK * 4) as u64);
                    match &layer.devs[ri] {
                        LayerDev::Packed { p: p_ptr, q: q_ptr } => {
                            let pp = p_ptr + (f_blk * la * KBLK * 4) as u64;
                            let qq = q_ptr + (f_blk * la * KBLK * 4) as u64;
                            if mode == FUSE_EXTRACT {
                                let name = "k_extract_round";
                                let mut args: [*mut c_void; 6] = [
                                    &pr as *const _ as *mut _,
                                    &pp as *const _ as *mut _,
                                    &qq as *const _ as *mut _,
                                    &eq_ptr as *const _ as *mut _,
                                    &n_u as *const _ as *mut _,
                                    &part as *const _ as *mut _,
                                ];
                                self.launch(name, grid, TK9, &mut args)?;
                            } else {
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
                        }
                        LayerDev::Compact { w: w_ptr, meta, n_exc } => {
                            let w = *w_ptr;
                            let alpha = *meta;
                            let exc = alpha + (K_DEG * 4) as u64;
                            let n_exc_u = *n_exc as u32;
                            let e_base = (f_blk * la * KL) as u32;
                            if mode == FUSE_EXTRACT {
                                let name = "k_extract_round_cl";
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
                                self.launch(name, grid, TK9, &mut args)?;
                            } else {
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
                }
                self.deposit_partial(kern.q, nn, acc_lo)?;
                self.last_kernel_ms = tk.elapsed().as_secs_f64() * 1e3;
                add_us(&S_KERNEL_US, tk.elapsed().as_secs_f64());
                if mode == FUSE_EXTRACT {
                    // Keep the layer for round 1; nothing written.
                    if let Some(l) = self.layer.as_mut() {
                        l.n_pairs = n_pairs;
                        l.ranges = ranges.clone();
                    }
                } else {
                    // The layer is consumed; the state-1 tables are resident.
                    // Its buffers go back (the big layers need the VRAM for
                    // the state tables' ping-pong).
                    self.release_layer_bufs();
                    let ptrs = [eq_dst.as_ptr() as usize, tabs[0].as_ptr() as usize, tabs[1].as_ptr() as usize, tabs[2].as_ptr() as usize, tabs[3].as_ptr() as usize];
                    self.chain = Some(Chain { ptrs, out_pairs: n_pairs, ranges: ranges.clone(), regions, tab_blk, buf });
                    if handover {
                        let th = Instant::now();
                        self.handover_to_host(eq_dst, tabs)?;
                        add_us(&S_HANDOVER_US, th.elapsed().as_secs_f64());
                        if !succ_taken {
                            self.chain = None;
                        }
                    }
                }
            }
            _ => {
                // FUSE_FOLD on the resident state.
                let (regions, tab_blk) = layout(&ranges);
                let ch = self.chain.as_ref().unwrap();
                let in_buf = ch.buf;
                let out_buf = in_buf ^ 1;
                let in_regions = ch.regions.clone();
                let in_tab_blk = ch.tab_blk;
                let bytes = 5 * tab_blk * KBLK * 4;
                if let Err(e) = self.grow_dev(DevSel::St(out_buf), bytes) {
                    // Cannot continue on the device: write the current state
                    // back (the CPU takes over from a coherent host).
                    if verbose() {
                        eprintln!("[UPERF2-L] k9: fold round declined ({e}); handing the state to the host");
                    }
                    self.abort_to_host(eq_inplace, tabs)?;
                    return Ok(false);
                }
                let prm_base = self.upload_prm(std::slice::from_ref(&prm0))?;
                p.prm = prm_base;
                self.zero_partial()?;
                if profile() {
                    self.sync_all()?;
                }
                let tk = Instant::now();
                let in_ranges = self.chain.as_ref().unwrap().ranges.clone();
                for (ri, &(a, b)) in ranges.iter().enumerate() {
                    let n = 8 * (b - a);
                    let n_u = n as u32;
                    let part = self.partial.ptr;
                    let grid = grid_for(n, TK9);
                    // The input blocks of the output pair-blocks [a, b): the
                    // previous state's pair-blocks [2a, 2b) — contiguous in the
                    // device layout when consecutive previous ranges cover them
                    // without a gap (asserted).
                    let in_blk0 = input_offset(&in_ranges, &in_regions, 2 * a, 2 * b);
                    let ins: [u64; 5] = std::array::from_fn(|k| self.st[in_buf].ptr + (((k * in_tab_blk) + in_blk0) * KBLK * 4) as u64);
                    let outs: [u64; 5] = std::array::from_fn(|k| self.st[out_buf].ptr + (((k * tab_blk) + regions[ri].blk0) * KBLK * 4) as u64);
                    let name = "k_fold_round";
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
                    self.launch(name, grid, TK9, &mut args)?;
                }
                self.deposit_partial(kern.q, nn, acc_lo)?;
                self.last_kernel_ms = tk.elapsed().as_secs_f64() * 1e3;
                add_us(&S_KERNEL_US, tk.elapsed().as_secs_f64());
                let ptrs = self.chain.as_ref().unwrap().ptrs;
                self.chain = Some(Chain { ptrs, out_pairs: n_pairs, ranges: ranges.clone(), regions, tab_blk, buf: out_buf });
                if handover {
                    let th = Instant::now();
                    self.handover_to_host(eq_inplace, tabs)?;
                    add_us(&S_HANDOVER_US, th.elapsed().as_secs_f64());
                    if !succ_taken {
                        self.chain = None;
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

    /// Bind the plan's layers on the device — upload the packed live blocks
    /// / the compact leaves' words, or [UPERF2-N] take a device tree's
    /// layer in place (a resident checkpoint, the compact leaves) or CLIMB
    /// its gap layer here into the layer buffers — and upload the eq table;
    /// sets `self.layer`. `Ok(false)` = declined (budget / encoding limits).
    fn upload_layer(&mut self, plan: &FusedPlan, n_pairs: usize, ranges: &[(usize, usize)], eq_src: &[u32], ids: &[(LayerId, usize)]) -> Result<bool, String> {
        let f_blk = if plan.mode == FUSE_EXTRACT { 4usize } else { 8 };
        // Sizes.
        let mut packed_blk = 0usize;
        let mut cl_words = 0usize;
        let mut cl_meta_w = 0usize;
        let mut scr_bytes = 0usize;
        let mut encoded: Vec<Option<ClEncoded>> = Vec::with_capacity(ranges.len());
        // [UPERF2-N] per range: the device tree binding (resident pointers,
        // or a climb plan: (nearest resident source layer, whole-layer blocks)).
        enum DevBind {
            None,
            InPlace(LayerDev),
            Climb { src_k: usize, nblk: usize },
        }
        let mut binds: Vec<DevBind> = Vec::with_capacity(ranges.len());
        let te = Instant::now();
        for (ri, &(a, b)) in ranges.iter().enumerate() {
            let n = b - a;
            match &plan.layers[ri].src {
                BlkSrc::Packed { p, q } => {
                    let la = a - plan.layers[ri].first_pair;
                    assert!(p.len() >= f_blk * (la + n) * KBLK && q.len() >= f_blk * (la + n) * KBLK, "K9 gpu: layer slice");
                    packed_blk += f_blk * (la + n);
                    encoded.push(None);
                    binds.push(DevBind::None);
                }
                BlkSrc::Compact(c) => {
                    let Some(e) = cl_encode(c) else {
                        return Ok(false);
                    };
                    cl_words += e.words.len();
                    cl_meta_w += K_DEG + e.exc.len();
                    encoded.push(Some(e));
                    binds.push(DevBind::None);
                }
                BlkSrc::Device { dev, .. } => {
                    encoded.push(None);
                    let Some(t) = self.trees.get(&dev.tree) else {
                        panic!("[UPERF2-N] device tree {} is gone while its layer {} is being read (protocol violation)", dev.tree, dev.k);
                    };
                    let k = dev.k;
                    if let Some((p, q)) = &t.layers[k] {
                        binds.push(DevBind::InPlace(LayerDev::Packed { p: p.ptr, q: q.ptr }));
                    } else if k == t.depth {
                        let (w, m, n_exc) = t.compact.as_ref().expect("a device tree keeps its leaves");
                        binds.push(DevBind::InPlace(LayerDev::Compact { w: w.ptr, meta: m.ptr, n_exc: *n_exc }));
                    } else {
                        let src_k = (k + 1..=t.depth).find(|&kk| t.layers[kk].is_some() || (kk == t.depth && t.compact.is_some())).expect("a device tree keeps its leaves");
                        let nblk = (1usize << k) / KL;
                        let la = a - plan.layers[ri].first_pair;
                        assert!(f_blk * (la + n) <= nblk, "K9 gpu: device layer range");
                        packed_blk += nblk;
                        // Intermediate levels (src_k - k >= 2): the largest is layer k+1.
                        if src_k - k >= 2 {
                            scr_bytes = scr_bytes.max(2 * (1usize << (k + 1)) / KL * KBLK * 4);
                        }
                        binds.push(DevBind::Climb { src_k, nblk });
                    }
                }
            }
        }
        add_us(&S_ENCODE_US, te.elapsed().as_secs_f64());
        let eq_bytes = eq_src.len() * 4;
        // Budget (the state-1 tables come on top: 5 x the LIVE state-1 blocks,
        // and their ping-pong half for state 2).
        let need = 2 * packed_blk * KBLK * 4 + cl_words * 4 + cl_meta_w * 4 + eq_bytes + 2 * scr_bytes;
        let live_pairs: usize = ranges.iter().map(|&(a, b)| b - a).sum();
        let st1_pairs = if plan.mode == FUSE_EXTRACT { live_pairs / 2 } else { live_pairs };
        let st1 = 5 * st1_pairs * 2 * KBLK * 4;
        let st2 = st1 / 2;
        let more = need.saturating_sub(self.lay_p.bytes + self.lay_q.bytes + self.cl_w.bytes + self.cl_meta.bytes + self.eqb.bytes + self.climb_scr[0].bytes + self.climb_scr[1].bytes);
        let want = more + st1.saturating_sub(self.st[0].bytes) + st2.saturating_sub(self.st[1].bytes);
        if self.held + want > self.budget {
            self.release_idle(DevSel::LayP);
        }
        if self.held + want > self.budget {
            if verbose() {
                eprintln!(
                    "[UPERF2-L] k9: layer declined — VRAM budget (need {:.2} GB layer + {:.2} GB state, held {:.2}, budget {:.2})",
                    need as f64 / 1e9,
                    st1 as f64 / 1e9,
                    self.held as f64 / 1e9,
                    self.budget as f64 / 1e9
                );
            }
            return Ok(false);
        }
        self.grow_dev(DevSel::LayP, packed_blk * KBLK * 4)?;
        self.grow_dev(DevSel::LayQ, packed_blk * KBLK * 4)?;
        self.grow_dev(DevSel::ClW, cl_words * 4)?;
        self.grow_dev(DevSel::ClMeta, cl_meta_w * 4)?;
        self.grow_dev(DevSel::Eqb, eq_bytes)?;
        if scr_bytes > 0 {
            // Each scratch buffer holds BOTH tables of one intermediate level
            // (the levels ping-pong between the two).
            self.grow_dev(DevSel::ClimbScr(0), scr_bytes)?;
            self.grow_dev(DevSel::ClimbScr(1), scr_bytes)?;
        }
        // Uploads (copy stream) and climbs (compute stream).
        let mut pp = 0usize;
        self.upload_words(self.eqb.ptr, eq_src, &mut pp)?;
        let mut devs: Vec<LayerDev> = Vec::with_capacity(ranges.len());
        let mut pblk = 0usize;
        let mut woff = 0usize;
        let mut moff = 0usize;
        let mut n_res = 0u64;
        let mut n_climb = 0u64;
        let tc = Instant::now();
        for (ri, &(a, b)) in ranges.iter().enumerate() {
            let n = b - a;
            match &plan.layers[ri].src {
                BlkSrc::Packed { p, q } => {
                    let la = a - plan.layers[ri].first_pair;
                    let nb = f_blk * (la + n);
                    let dp = self.lay_p.ptr + (pblk * KBLK * 4) as u64;
                    let dq = self.lay_q.ptr + (pblk * KBLK * 4) as u64;
                    self.upload_words(dp, &p[..nb * KBLK], &mut pp)?;
                    self.upload_words(dq, &q[..nb * KBLK], &mut pp)?;
                    devs.push(LayerDev::Packed { p: dp, q: dq });
                    pblk += nb;
                }
                BlkSrc::Compact(_) => {
                    let e = encoded[ri].as_ref().unwrap();
                    let w = self.cl_w.ptr + (woff * 4) as u64;
                    let m = self.cl_meta.ptr + (moff * 4) as u64;
                    self.upload_words(w, e.words, &mut pp)?;
                    let meta = cl_meta(e);
                    self.upload_words(m, &meta, &mut pp)?;
                    devs.push(LayerDev::Compact { w, meta: m, n_exc: e.n_exc });
                    woff += e.words.len();
                    moff += meta.len();
                }
                BlkSrc::Device { dev, .. } => match std::mem::replace(&mut binds[ri], DevBind::None) {
                    DevBind::InPlace(ld) => {
                        n_res += 1;
                        devs.push(ld);
                    }
                    DevBind::Climb { src_k, nblk } => {
                        let dp = self.lay_p.ptr + (pblk * KBLK * 4) as u64;
                        let dq = self.lay_q.ptr + (pblk * KBLK * 4) as u64;
                        self.climb_layer(dev.tree, dev.k, src_k, dp, dq)?;
                        n_climb += 1;
                        devs.push(LayerDev::Packed { p: dp, q: dq });
                        pblk += nblk;
                    }
                    DevBind::None => unreachable!(),
                },
            }
        }
        if n_climb > 0 {
            // The climbs' outputs are read by this round's kernels on the same
            // stream (ordered); the timing here is enqueue-side only.
            add_us(&S_DEV_CLIMB_US, tc.elapsed().as_secs_f64());
            S_DEV_CLIMBS.fetch_add(n_climb, Ordering::Relaxed);
        }
        S_LAYER_RESIDENT.fetch_add(n_res, Ordering::Relaxed);
        self.layer = Some(LayerRes { n_pairs, ranges: ranges.to_vec(), ids: ids.to_vec(), devs, eq: (eq_src.as_ptr() as usize, eq_src.len()) });
        Ok(true)
    }

    /// Copy the resident state's live regions into the host buffers where
    /// the CPU path would have left them (blocks [2a, 2b) per range).
    fn handover_to_host(&mut self, eq: &mut [u32], tabs: &mut [&mut [u32]; 4]) -> Result<(), String> {
        let ch = self.chain.as_ref().unwrap();
        let regions = ch.regions.clone();
        let ranges = ch.ranges.clone();
        let tab_blk = ch.tab_blk;
        let buf = ch.buf;
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk: {e}"))?;
        for (ri, &(a, b)) in ranges.iter().enumerate() {
            let reg = regions[ri];
            for k in 0..5 {
                let src = self.st[buf].ptr + (((k * tab_blk) + reg.blk0) * KBLK * 4) as u64;
                let words = reg.n_blk * KBLK;
                debug_assert_eq!(words, 2 * (b - a) * KBLK);
                let dst_all: &mut [u32] = if k == 0 { &mut *eq } else { &mut *tabs[k - 1] };
                assert!(2 * b * KBLK <= dst_all.len(), "K9 gpu: handover destination too small");
                let dst = &mut dst_all[2 * a * KBLK..2 * a * KBLK + words];
                self.download_words(src, dst)?;
            }
        }
        Ok(())
    }

    /// The device cannot continue: write the resident state back (the host
    /// becomes coherent) and drop the chain.
    fn abort_to_host(&mut self, eq: &mut [u32], tabs: &mut [&mut [u32]; 4]) -> Result<(), String> {
        if self.chain.is_some() {
            self.handover_to_host(eq, tabs)?;
            self.chain = None;
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

/// The device block offset (per table) of the previous state's pair-block
/// `a0`, and the assertion that [a0, b0) is covered by consecutive previous
/// ranges with no gap (their regions are adjacent in the layout).
fn input_offset(prev_ranges: &[(usize, usize)], prev_regions: &[Region], a0: usize, b0: usize) -> usize {
    let mut cur = a0;
    let mut off: Option<usize> = None;
    for (r, &(a, b)) in prev_ranges.iter().enumerate() {
        if b <= a0 || a >= b0 {
            continue;
        }
        if off.is_none() {
            assert!(a <= a0, "K9 gpu: the input pair-blocks [{a0}, {b0}) start before the previous ranges {prev_ranges:?}");
            off = Some(prev_regions[r].blk0 + 2 * (a0 - a));
        } else {
            assert!(a == cur, "K9 gpu: the input pair-blocks [{a0}, {b0}) are not covered contiguously by the previous ranges {prev_ranges:?}");
        }
        cur = b;
    }
    assert!(cur >= b0, "K9 gpu: the input pair-blocks [{a0}, {b0}) exceed the previous ranges {prev_ranges:?}");
    off.expect("K9 gpu: no previous range covers the input")
}

/// The device layout of a state: regions per range (contiguous, in order),
/// per-table stride in blocks.
fn layout(ranges: &[(usize, usize)]) -> (Vec<Region>, usize) {
    let mut regions = Vec::with_capacity(ranges.len());
    let mut off = 0usize;
    for &(a, b) in ranges {
        let n_blk = 2 * (b - a);
        regions.push(Region { blk0: off, n_blk });
        off += n_blk;
    }
    (regions, off)
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
    /// Allocate a store buffer within the budget (idle families released
    /// first). Counted in `held` and `tree_bytes`.
    fn tree_alloc(&mut self, bytes: usize) -> Result<DevBuf, String> {
        if self.held + bytes > self.budget {
            self.release_idle_all();
        }
        if self.held + bytes > self.budget {
            return Err(format!(
                "K9 VRAM budget (tree store): need {:.2} GB more (held {:.2} GB, budget {:.2} GB)",
                bytes as f64 / 1e9,
                self.held as f64 / 1e9,
                self.budget as f64 / 1e9
            ));
        }
        let mut b = DevBuf::empty();
        b.grow(bytes)?;
        self.held += b.bytes;
        self.tree_bytes += b.bytes;
        note_peak(&S_HELD_PEAK, self.held);
        note_peak(&S_TREE_BYTES_PEAK, self.tree_bytes);
        Ok(b)
    }

    /// Free a store buffer (the caller has synchronized).
    fn tree_free(&mut self, mut b: DevBuf) {
        self.held -= b.bytes;
        self.tree_bytes -= b.bytes;
        b.free();
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
        if self.held + need > self.budget {
            self.release_idle_all();
        }
        if self.held + need > self.budget {
            if verbose() {
                eprintln!(
                    "[UPERF2-N] k9: tree build declined — VRAM budget (need {:.2} GB, held {:.2}, budget {:.2})",
                    need as f64 / 1e9,
                    self.held as f64 / 1e9,
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
            let (bp, bq) = t.layers[top_k].as_ref().expect("top layer");
            let (pp_, qp_) = (bp.ptr, bq.ptr);
            let words = n_top / KL * KBLK;
            self.download_words(pp_, &mut tp.d[..words])?;
            self.download_words(qp_, &mut tq.d[..words])?;
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
    fn climb_layer(&mut self, tree: u64, k: usize, src_k: usize, dp: u64, dq: u64) -> Result<(), String> {
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
                assert!(self.climb_scr[cur].bytes >= 2 * bytes, "K9 gpu: climb scratch");
                let base = self.climb_scr[cur].ptr;
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
        let scr = if src_k - k >= 2 { 2 * (1usize << (k + 1)) / KL * KBLK * 4 } else { 0 };
        self.layer = None;
        self.grow_dev(DevSel::LayP, bytes)?;
        self.grow_dev(DevSel::LayQ, bytes)?;
        if scr > 0 {
            self.grow_dev(DevSel::ClimbScr(0), scr)?;
            self.grow_dev(DevSel::ClimbScr(1), scr)?;
        }
        let (dp, dq) = (self.lay_p.ptr, self.lay_q.ptr);
        self.climb_layer(tree, k, src_k, dp, dq)?;
        S_DEV_CLIMBS.fetch_add(1, Ordering::Relaxed);
        self.download_words(dp, &mut tp.d[..words])?;
        self.download_words(dq, &mut tq.d[..words])?;
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
        if let Some(l) = &self.layer {
            if l.ids.iter().any(|(id, _)| matches!(id, LayerId::Device { tree: tt, k: kk } if *tt == tree && *kk == k)) {
                let _ = self.sync_all();
                self.layer = None;
            }
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
        if let Some(l) = &self.layer {
            if l.ids.iter().any(|(id, _)| matches!(id, LayerId::Device { tree: tt, .. } if *tt == tree)) {
                self.layer = None;
            }
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

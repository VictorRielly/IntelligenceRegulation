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

use super::super::eval_proof::{oracle_mode, threads};
use super::super::kfield::{
    BlkSrc, CompactLeaves, FusedPlan, KElem, KField, KKern, KTab, FUSE_EXTRACT, FUSE_EXTRACT_FOLD, FUSE_FOLD, KBLK, KL, K_DEG,
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
/// Pinned staging per buffer (bytes) for the pipelined uploads / downloads.
const STG_BYTES: usize = 32 << 20;
/// Largest exception list the compact re-encoding accepts per instance.
const CL_MAX_EXC: usize = 1 << 14;
/// Blocks per re-encoding chunk (128 KB of scratch per table per thread).
const CL_CHUNK_BLK: usize = 256;

// ---------------------------------------------------------------------------
// Kernel parameters (== struct K9P in kernels_k9.cu).

#[repr(C)]
#[derive(Clone, Copy)]
struct K9Params {
    q: u32,
    s: u32,
    c31: u32,
    c32: u32,
    nn: u32,
    nodes: [u32; 5],
    has_fc: u32,
    has_nc: u32,
    has_ee: u32,
    mode: u32,
    kind: u32,
    deg: u32,
    pad0: u32,
    pad1: u32,
    r: [u32; K_DEG],
    lambda: [u32; K_DEG],
    ee: [u32; K_DEG],
    fc: [[u32; K_DEG]; 4],
    nc: [[[u32; K_DEG]; 4]; 5],
}

impl K9Params {
    fn new(kern: &KKern) -> K9Params {
        K9Params {
            q: kern.q as u32,
            s: kern.s as u32,
            c31: kern.c31 as u32,
            c32: kern.c32 as u32,
            nn: 0,
            nodes: [0; 5],
            has_fc: 0,
            has_nc: 0,
            has_ee: 0,
            mode: 0,
            kind: 0,
            deg: 0,
            pad0: 0,
            pad1: 0,
            r: [0; K_DEG],
            lambda: [0; K_DEG],
            ee: [0; K_DEG],
            fc: [[0; K_DEG]; 4],
            nc: [[[0; K_DEG]; 4]; 5],
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

fn add_us(s: &AtomicU64, secs: f64) {
    s.fetch_add((secs * 1e6) as u64, Ordering::Relaxed);
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
    }
}

pub fn k9_stats_reset() {
    for s in [
        &S_ROUNDS, &S_DECLINED, &S_LAYER_UP, &S_LAYER_HIT, &S_H2D, &S_D2H, &S_ROUND_US, &S_UPLOAD_US, &S_ENCODE_US, &S_HANDOVER_US, &S_IXF_ROUNDS,
        &S_IXF_FOLDS, &S_IXF_HITS, &S_IXF_US, &S_CLIMBS, &S_CLIMB_US, &S_CLIMB_D2H_US, &S_KERNEL_US,
    ] {
        s.store(0, Ordering::Relaxed);
    }
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

/// One instance's layer on the device (round 0 -> round 1).
enum LayerDev {
    Packed { p_blk0: usize, q_blk0: usize, n_blk: usize },
    Compact { w_off: usize, meta_off: usize, n_exc: usize, n_leaves: usize },
}

/// The identity of an instance's layer as the plan presents it.
#[derive(Clone, PartialEq, Eq, Debug)]
enum LayerId {
    Packed { p: usize, q: usize, p_len: usize, q_len: usize },
    Compact { c: usize, n: usize },
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
    /// pointers at round t+1; a mismatch = miss, re-upload).
    next_ptrs: Vec<usize>,
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
    chain: Option<Chain>,
    layer: Option<LayerRes>,
    // Ixf.
    ixf_t: Vec<[DevBuf; 2]>,
    ixf: Option<IxfChain>,
    // Tree.
    tree_src: [DevBuf; 2],
    tree_out: [DevBuf; 2],
    // Budget.
    budget: usize,
    held: usize,
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
    dev.load_ptx(ptx, MODULE, FUNCS).map_err(|e| format!("cuModuleLoadData (k9): {e}"))?;
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
        s.grow(STG_BYTES)?;
    }
    let mut partial = DevBuf::empty();
    partial.grow(5 * 16 * 8)?;
    let mut partial_h = HostPinned::empty();
    partial_h.grow(5 * 16 * 8)?;
    let (free, total) = cu::mem_get_info().map_err(|e| format!("cuMemGetInfo: {e}"))?;
    let budget = {
        let mb = env_usize("ZK_GPU_K9_BUDGET_MB", 0);
        if mb > 0 { mb << 20 } else { free.saturating_sub(512 << 20) }
    };
    if verbose() {
        eprintln!(
            "[UPERF2-L] k9 init: NVRTC compile {:.2}s; VRAM free {:.2} / {:.2} GB; K9 budget {:.2} GB; min_pairs {}",
            t0.elapsed().as_secs_f64(),
            free as f64 / 1e9,
            total as f64 / 1e9,
            budget as f64 / 1e9,
            min_pairs()
        );
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
        chain: None,
        layer: None,
        ixf_t: Vec::new(),
        ixf: None,
        tree_src: [DevBuf::empty(), DevBuf::empty()],
        tree_out: [DevBuf::empty(), DevBuf::empty()],
        budget,
        held: 0,
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
                "k9: on — K-field kernels on the device (budget {:.2} GB, held {:.2} GB, min_pairs {}, eager {})",
                k.budget as f64 / 1e9,
                k.held as f64 / 1e9,
                min_pairs(),
                eager()
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
    /// must reallocate).
    fn grow_dev(&mut self, which: DevSel, bytes: usize) -> Result<(), String> {
        let cur = self.sel(which).bytes;
        if bytes <= cur {
            return Ok(());
        }
        let need = bytes - cur;
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
        Ok(())
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
        }
    }

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
        for b in self.tree_src.iter_mut().chain(self.tree_out.iter_mut()) {
            b.free();
        }
        self.held = 0;
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
        let per = STG_BYTES / 4;
        let mut off = 0usize;
        while off < src.len() {
            let n = per.min(src.len() - off);
            let i = *pp & 1;
            unsafe { cu::event::synchronize(self.ev[i]) }.map_err(|e| format!("event sync: {e}"))?;
            {
                let dstw = self.stg[i].slice_mut::<u32>(n);
                let s = &src[off..off + n];
                if threads() > 1 && n >= (1 << 20) {
                    POOL.install(|| {
                        use rayon::prelude::*;
                        dstw.par_chunks_mut(1 << 18).zip(s.par_chunks(1 << 18)).for_each(|(d, s)| d.copy_from_slice(s));
                    });
                } else {
                    dstw.copy_from_slice(s);
                }
            }
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
        let per = STG_BYTES / 4;
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
                if threads() > 1 && n >= (1 << 20) {
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
}

/// Grid size for a grid-stride kernel over `n` items with `block` threads.
fn grid_for(n: usize, block: u32) -> u32 {
    let per = block as usize;
    (n.div_ceil(per).min(4096)).max(1) as u32
}

// ---------------------------------------------------------------------------
// The compact leaves: re-encoding from `expand_blocks` (the words are private
// to kfield.rs; the encoding is derived from the exact packed blocks the
// CPU kernels read, so the device expansion — the same decode + the
// exception override — yields the same blocks). Words: 2 per leaf (q0, q1 |
// MEMBER); meta: alpha[16] then n_exc x (idx, p[16], q[16]).

struct ClEncoded {
    words: Vec<u32>,
    alpha: [u32; K_DEG],
    exc: Vec<u32>, // n_exc x 33
    n_exc: usize,
}

fn cl_encode(c: &CompactLeaves) -> Option<ClEncoded> {
    let n = c.n;
    let nblk = n / KL;
    // Alpha: probe the first blocks for a member-looking leaf; take the most
    // frequent tail among the first 2 blocks (>= 16 leaves).
    let mut alpha = [0u32; K_DEG];
    let mut have_alpha = false;
    {
        let probe_blk = nblk.min(2);
        let mut sp = vec![0u32; probe_blk * KBLK];
        let mut sq = vec![0u32; probe_blk * KBLK];
        c.expand_blocks(0, probe_blk, &mut sp, &mut sq);
        let mut cands: Vec<([u32; K_DEG], usize)> = Vec::new();
        for b in 0..probe_blk {
            for l in 0..KL {
                let base = b * KBLK + l;
                let member = sp[base] == 1 && (1..K_DEG).all(|j| sp[base + j * KL] == 0);
                if member {
                    let mut tail = [0u32; K_DEG];
                    for j in 2..K_DEG {
                        tail[j] = sq[base + j * KL];
                    }
                    if let Some(e) = cands.iter_mut().find(|e| e.0 == tail) {
                        e.1 += 1;
                    } else {
                        cands.push((tail, 1));
                    }
                }
            }
        }
        if let Some(best) = cands.iter().max_by_key(|e| e.1) {
            alpha = best.0;
            have_alpha = true;
        }
    }
    let n_chunks = nblk.div_ceil(CL_CHUNK_BLK);
    let encode_chunk = |ci: usize| -> (Vec<u32>, Vec<u32>) {
        let b0 = ci * CL_CHUNK_BLK;
        let nb = CL_CHUNK_BLK.min(nblk - b0);
        let mut sp = vec![0u32; nb * KBLK];
        let mut sq = vec![0u32; nb * KBLK];
        c.expand_blocks(b0, nb, &mut sp, &mut sq);
        let mut words = vec![0u32; 2 * nb * KL];
        let mut exc: Vec<u32> = Vec::new();
        for b in 0..nb {
            for l in 0..KL {
                let base = b * KBLK + l;
                let i = b * KL + l;
                let p_is_one = sp[base] == 1 && (1..K_DEG).all(|j| sp[base + j * KL] == 0);
                let p_is_zero = (0..K_DEG).all(|j| sp[base + j * KL] == 0);
                let q_is_one = sq[base] == 1 && (1..K_DEG).all(|j| sq[base + j * KL] == 0);
                let q0 = sq[base];
                let q1 = sq[base + KL];
                if p_is_zero && q_is_one {
                    words[2 * i] = 0;
                    words[2 * i + 1] = 0;
                } else if have_alpha && p_is_one && q0 < (1 << 31) && q1 < (1 << 31) && (2..K_DEG).all(|j| sq[base + j * KL] == alpha[j]) {
                    words[2 * i] = q0;
                    words[2 * i + 1] = q1 | (1 << 31);
                } else {
                    // Exception: index (absolute), p, q. The words stay 0 (dummy);
                    // the device applies the exception after the decode.
                    exc.push(((b0 + b) * KL + l) as u32);
                    for j in 0..K_DEG {
                        exc.push(sp[base + j * KL]);
                    }
                    for j in 0..K_DEG {
                        exc.push(sq[base + j * KL]);
                    }
                }
            }
        }
        (words, exc)
    };
    let parts: Vec<(Vec<u32>, Vec<u32>)> = if threads() > 1 && n_chunks > 1 {
        POOL.install(|| {
            use rayon::prelude::*;
            (0..n_chunks).into_par_iter().map(encode_chunk).collect()
        })
    } else {
        (0..n_chunks).map(encode_chunk).collect()
    };
    let mut words = Vec::with_capacity(2 * n);
    let mut exc = Vec::new();
    for (w, e) in parts {
        words.extend_from_slice(&w);
        exc.extend_from_slice(&e);
    }
    let n_exc = exc.len() / 33;
    if n_exc > CL_MAX_EXC {
        return None;
    }
    Some(ClEncoded { words, alpha, exc, n_exc })
}

// ---------------------------------------------------------------------------
// The fused descent round (the hook of kfield::k9_fused_round_par).

fn layer_id(src: &BlkSrc) -> LayerId {
    match src {
        BlkSrc::Packed { p, q } => LayerId::Packed { p: p.as_ptr() as usize, q: q.as_ptr() as usize, p_len: p.len(), q_len: q.len() },
        BlkSrc::Compact(c) => LayerId::Compact { c: (*c) as *const CompactLeaves as usize, n: c.n },
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
        // ---- Parameters.
        let mut p = K9Params::new(kern);
        p.nn = nn as u32;
        for (i, &x) in nodes.iter().enumerate() {
            p.nodes[i] = x as u32;
        }
        p.mode = mode as u32;
        p.r = plan.r_prev;
        p.lambda = plan.lambda;
        if let Some(fc) = plan.fold_consts.as_ref() {
            p.has_fc = 1;
            p.fc = *fc;
        }
        if let Some(nc) = node_consts {
            assert_eq!(nc.len(), nn);
            p.has_nc = 1;
            for (i, c) in nc.iter().enumerate() {
                p.nc[i] = *c;
            }
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
                            && l.ids == ids
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
                self.zero_partial()?;
                let tk = Instant::now();
                let layer = self.layer.as_ref().unwrap();
                for (ri, &(a, b)) in ranges.iter().enumerate() {
                    let n = 8 * (b - a);
                    let la = a - plan.layers[ri].first_pair;
                    let mut pr = p;
                    if let Some(ee) = plan.layers[ri].ee {
                        pr.has_ee = 1;
                        pr.ee = ee;
                    }
                    let eq_ptr = self.eqb.ptr + ((fe_blk * la) * KBLK * 4) as u64;
                    let n_u = n as u32;
                    let part = self.partial.ptr;
                    let grid = grid_for(n, TK9);
                    let reg = regions[ri];
                    let outs: [u64; 5] = std::array::from_fn(|k| self.st[buf].ptr + (((k * tab_blk) + reg.blk0) * KBLK * 4) as u64);
                    match &layer.devs[ri] {
                        LayerDev::Packed { p_blk0, q_blk0, .. } => {
                            let pp = self.lay_p.ptr + ((p_blk0 + f_blk * la) * KBLK * 4) as u64;
                            let qq = self.lay_q.ptr + ((q_blk0 + f_blk * la) * KBLK * 4) as u64;
                            if mode == FUSE_EXTRACT {
                                let name = "k_extract_round";
                                pr.nn = nn as u32;
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
                        LayerDev::Compact { w_off, meta_off, n_exc, .. } => {
                            let w = self.cl_w.ptr + (w_off * 4) as u64;
                            let alpha = self.cl_meta.ptr + (meta_off * 4) as u64;
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
                add_us(&S_KERNEL_US, tk.elapsed().as_secs_f64());
                if mode == FUSE_EXTRACT {
                    // Keep the layer for round 1; nothing written.
                    if let Some(l) = self.layer.as_mut() {
                        l.n_pairs = n_pairs;
                        l.ranges = ranges.clone();
                    }
                } else {
                    // The layer is consumed; the state-1 tables are resident.
                    self.layer = None;
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
                self.zero_partial()?;
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
                "[UPERF2-L] k9 round mode {} n_pairs {} ranges {} nn {} handover {} : {:.2} ms",
                mode,
                n_pairs,
                ranges.len(),
                nn,
                handover,
                t0.elapsed().as_secs_f64() * 1e3
            );
        }
        Ok(true)
    }

    /// Upload the plan's layers (packed live blocks or the re-encoded
    /// compact leaves) and the eq table; sets `self.layer`. `Ok(false)` =
    /// declined (budget / encoding limits).
    fn upload_layer(&mut self, plan: &FusedPlan, n_pairs: usize, ranges: &[(usize, usize)], eq_src: &[u32], ids: &[(LayerId, usize)]) -> Result<bool, String> {
        let f_blk = if plan.mode == FUSE_EXTRACT { 4usize } else { 8 };
        // Sizes.
        let mut packed_blk = 0usize;
        let mut cl_words = 0usize;
        let mut cl_meta = 0usize;
        let mut encoded: Vec<Option<ClEncoded>> = Vec::with_capacity(ranges.len());
        let te = Instant::now();
        for (ri, &(a, b)) in ranges.iter().enumerate() {
            let n = b - a;
            match &plan.layers[ri].src {
                BlkSrc::Packed { p, q } => {
                    let la = a - plan.layers[ri].first_pair;
                    assert!(p.len() >= f_blk * (la + n) * KBLK && q.len() >= f_blk * (la + n) * KBLK, "K9 gpu: layer slice");
                    packed_blk += f_blk * (la + n);
                    encoded.push(None);
                }
                BlkSrc::Compact(c) => {
                    let Some(e) = cl_encode(c) else {
                        return Ok(false);
                    };
                    cl_words += e.words.len();
                    cl_meta += K_DEG + e.exc.len();
                    encoded.push(Some(e));
                }
            }
        }
        add_us(&S_ENCODE_US, te.elapsed().as_secs_f64());
        let eq_bytes = eq_src.len() * 4;
        // Budget (the state-1 tables come on top: 5 x 2 x n_pairs blocks).
        let need = 2 * packed_blk * KBLK * 4 + cl_words * 4 + cl_meta * 4 + eq_bytes;
        let st1 = if plan.mode == FUSE_EXTRACT { 5 * (n_pairs / 2) * 2 * KBLK * 4 } else { 5 * n_pairs * 2 * KBLK * 4 };
        let more = need.saturating_sub(self.lay_p.bytes + self.lay_q.bytes + self.cl_w.bytes + self.cl_meta.bytes + self.eqb.bytes);
        if self.held + more + st1.saturating_sub(self.st[0].bytes) > self.budget {
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
        self.grow_dev(DevSel::ClMeta, cl_meta * 4)?;
        self.grow_dev(DevSel::Eqb, eq_bytes)?;
        // Uploads.
        let mut pp = 0usize;
        self.upload_words(self.eqb.ptr, eq_src, &mut pp)?;
        let mut devs: Vec<LayerDev> = Vec::with_capacity(ranges.len());
        let mut pblk = 0usize;
        let mut woff = 0usize;
        let mut moff = 0usize;
        for (ri, &(a, b)) in ranges.iter().enumerate() {
            let n = b - a;
            match &plan.layers[ri].src {
                BlkSrc::Packed { p, q } => {
                    let la = a - plan.layers[ri].first_pair;
                    let nb = f_blk * (la + n);
                    self.upload_words(self.lay_p.ptr + (pblk * KBLK * 4) as u64, &p[..nb * KBLK], &mut pp)?;
                    self.upload_words(self.lay_q.ptr + (pblk * KBLK * 4) as u64, &q[..nb * KBLK], &mut pp)?;
                    devs.push(LayerDev::Packed { p_blk0: pblk, q_blk0: pblk, n_blk: nb });
                    pblk += nb;
                }
                BlkSrc::Compact(_) => {
                    let e = encoded[ri].as_ref().unwrap();
                    self.upload_words(self.cl_w.ptr + (woff * 4) as u64, &e.words, &mut pp)?;
                    let mut meta: Vec<u32> = Vec::with_capacity(K_DEG + e.exc.len());
                    meta.extend_from_slice(&e.alpha);
                    meta.extend_from_slice(&e.exc);
                    self.upload_words(self.cl_meta.ptr + (moff * 4) as u64, &meta, &mut pp)?;
                    devs.push(LayerDev::Compact { w_off: woff, meta_off: moff, n_exc: e.n_exc, n_leaves: e.words.len() / 2 });
                    woff += e.words.len();
                    moff += meta.len();
                }
            }
        }
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
        // this round's tables at the folds' output pointers with n = prev/2.
        let ptrs: Vec<usize> = tabs.iter().map(|t| t.as_ptr() as usize).collect();
        let hit = match &self.ixf {
            Some(c) => c.kind == kind && c.nt == nt && c.folded == nt && c.n == 2 * n && c.next_ptrs == ptrs,
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
        add_us(&S_KERNEL_US, tk.elapsed().as_secs_f64());
        self.ixf = Some(IxfChain { kind, nt, ptrs, n, buf: bufs, folded: 0, next_ptrs: vec![0; nt] });
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
            // Not the expected fold: the ixf chain (if any) is broken; a
            // cold fold is PCIe-bound — decline.
            self.ixf = None;
            return Ok(false);
        };
        if nblk / 2 < 1 {
            self.ixf = None;
            return Ok(false);
        }
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let c = self.ixf.as_ref().unwrap();
        let in_buf = c.buf[k];
        let out_buf = in_buf ^ 1;
        let out_bytes = nblk * KBLK * 4;
        self.grow_dev(DevSel::Ixf(k, out_buf), out_bytes)?;
        let mut p = K9Params::new(kern);
        p.r = super::super::kfield::kop(r);
        let src = self.ixf_t[k][in_buf].ptr;
        let dst = self.ixf_t[k][out_buf].ptr;
        let n_u = n_out as u32;
        let mut args: [*mut c_void; 4] = [&p as *const _ as *mut _, &src as *const _ as *mut _, &dst as *const _ as *mut _, &n_u as *const _ as *mut _];
        self.launch("k_fold_table", grid_for(n_out, TEL), TEL, &mut args)?;
        // Eager: the folded table into `scratch` (grown as kt_fold_par does), then swap.
        if scratch.len() < nblk * KBLK {
            scratch.resize(nblk * KBLK, 0);
        }
        self.download_words(dst, &mut scratch[..nblk * KBLK])?;
        std::mem::swap(&mut t.d, scratch);
        t.n = n_out;
        t.d.truncate(nblk * KBLK);
        let c = self.ixf.as_mut().unwrap();
        c.buf[k] = out_buf;
        c.next_ptrs[k] = t.d.as_ptr() as usize;
        c.folded += 1;
        Ok(true)
    }
}

// ---------------------------------------------------------------------------
// The tree step (the hook of kfield::k9_tree_climb_par).

pub fn k9_tree_climb(kern: &KKern, src: &BlkSrc, levels: usize, np: &mut [u32], nq: &mut [u32], out_nblk: usize) -> Option<()> {
    if !live() {
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
        };
        let inter_bytes = if levels > 1 { 2 * (out_nblk << (levels - 1)) * KBLK * 4 } else { 0 };
        let need = src_bytes + 2 * out_words * 4 + inter_bytes;
        let have = self.tree_src[0].bytes + self.tree_src[1].bytes + self.tree_out[0].bytes + self.tree_out[1].bytes;
        if self.held + need.saturating_sub(have) > self.budget {
            return Ok(false);
        }
        let mut p = K9Params::new(kern);
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
                let mut meta: Vec<u32> = Vec::with_capacity(K_DEG + e.exc.len());
                meta.extend_from_slice(&e.alpha);
                meta.extend_from_slice(&e.exc);
                self.grow_dev(DevSel::TreeSrc(0), e.words.len() * 4)?;
                self.grow_dev(DevSel::TreeSrc(1), meta.len() * 4)?;
                self.upload_words(self.tree_src[0].ptr, &e.words, &mut pp)?;
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
        let _ = (p, cur_buf);
        Ok(true)
    }
}

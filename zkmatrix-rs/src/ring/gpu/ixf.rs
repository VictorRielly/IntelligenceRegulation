// [UPERF2-O] The GPU rung, step 3 (host side): the claim layer's stacked
// zero-check instances with their factor tables BUILT ON THE DEVICE from the
// compact operands, the ixf round + fold on device-resident tables, and a
// handover of the small tail to the host loop. Own NVRTC module
// (`zkgpu_ixf`, kernels_ixf.cu); lane K's device / stream discipline
// (cuda.rs: `device_handle`, `DevBuf`, `HostPinned`); independent of lane
// L's k9.rs (which keeps handling the joint-matmul instances and any tail
// its `ZK_GPU_K9_MIN_PAIRS` admits).
//
// Protocol (driven by fold.rs `ixf_sumcheck_prove_zc`, one sequential loop on
// one transcript): `ixf_zc_open(kf, spec)` uploads the layers' i64 tensors
// (pinned staging), builds the three stacked tables on the device, and keeps
// the eq factor as two small host/device tables (eqL over the low variables,
// eqH over the high ones — the eq-fold identity: folding a low variable
// folds only eqL; when the low group is exhausted the remaining eq is one
// small table G) and the requant shift table as the 16-slot layer table
// (a per-slot broadcast while position variables remain); `round(deg)`
// launches the round kernel and returns the node values (canonical sums
// reduced mod q — the same field elements the CPU planes finalize to);
// `fold(r)` folds the three device tables out of place (a rotating scratch:
// four buffers for three tables) and the small host tables; `handover()`
// materializes every factor table of the current (small) size on the host
// for the CPU loop. A device error is returned to the caller, which
// rebuilds the instance's tables on the host from the same operands and
// re-folds them with the challenges already drawn (deterministic) — the
// device is then disabled for the process (reported once). Nothing here
// changes a value: the batteries compare proof bytes.
//
// Knobs (none changes a value): `ZK_GPU=1` (lane K's master switch),
// `ZK_GPU_IXF=0` (this module off — the one-binary A/B), `ZK_GPU_IXF_MIN_PAIRS`
// (the smallest round the device runs, in pair-blocks; default 32 = lane L's),
// `ZK_GPU_IXF_LOWBITS` (the eq low group size, default 12), `ZK_GPU_VERBOSE=1`.

use super::super::eval_proof::{oracle_mode, threads};
use super::super::fold::IxfZcSpec;
use super::super::kfield::{kop, KElem, KField, KTab, KBLK, KL, K_DEG};
use super::cuda::{device_handle, env_usize, verbose, DevBuf, HostPinned, POOL};
use cudarc::driver::result as cu;
use cudarc::driver::{sys, CudaDevice, CudaFunction, CudaStream, LaunchAsync, LaunchConfig};
use cudarc::nvrtc::{compile_ptx_with_opts, CompileOptions};
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;

const KSRC: &str = include_str!("kernels_ixf.cu");
const MODULE: &str = "zkgpu_ixf";
const FUNCS: &[&str] = &["k_oixf_build", "k_oixf_fold", "k_oixf_round"];
/// Threads per block of the round kernel (== TOX in kernels_ixf.cu).
const TOX: u32 = 64;
/// Threads per block of the build / fold kernels.
const TEL: u32 = 128;
/// Grid cap (grid-stride loops above it).
const GRID_CAP: u32 = 1 << 15;
/// Pinned staging chunk for the source uploads.
fn stg_bytes() -> usize {
    env_usize("ZK_GPU_IXF_STG_MB", 32) << 20
}
/// The eq low group (variables) — eqL has 2^lowbits elements at most.
static LOW_BITS_OVERRIDE: AtomicU64 = AtomicU64::new(0);
fn low_bits() -> usize {
    let o = LOW_BITS_OVERRIDE.load(Ordering::Relaxed) as usize;
    if o > 0 {
        return o;
    }
    static V: OnceLock<usize> = OnceLock::new();
    *V.get_or_init(|| env_usize("ZK_GPU_IXF_LOWBITS", 12).clamp(1, 16))
}
/// Harness knob: the eq low group size in variables (0 = env/default).
pub fn ixf_set_low_bits(b: usize) {
    LOW_BITS_OVERRIDE.store(b as u64, Ordering::Relaxed);
}
static MIN_PAIRS_OVERRIDE: AtomicU64 = AtomicU64::new(0);
fn min_pairs() -> usize {
    let o = MIN_PAIRS_OVERRIDE.load(Ordering::Relaxed) as usize;
    if o > 0 {
        return o;
    }
    static V: OnceLock<usize> = OnceLock::new();
    *V.get_or_init(|| env_usize("ZK_GPU_IXF_MIN_PAIRS", 32).max(1))
}
/// Harness knob: the smallest device round in pair-blocks (0 = env/default).
pub fn ixf_set_min_pairs(p: usize) {
    MIN_PAIRS_OVERRIDE.store(p as u64, Ordering::Relaxed);
}
static BYPASS: AtomicBool = AtomicBool::new(false);
/// Harness knob: route every zero-check instance to the host path (the
/// in-process A/B); asserts no chain is open.
pub fn ixf_set_bypass(on: bool) {
    if on {
        if let Some(Some(m)) = IXFS.get() {
            if let Ok(s) = m.try_lock() {
                assert!(s.chain.is_none(), "[UPERF2-O] ixf_set_bypass(true) while a device chain is open");
            }
        }
    }
    BYPASS.store(on, Ordering::Relaxed);
}
static WARNED: AtomicBool = AtomicBool::new(false);
static DISABLED: AtomicBool = AtomicBool::new(false);

fn requested() -> bool {
    static ON: OnceLock<bool> = OnceLock::new();
    *ON.get_or_init(|| std::env::var("ZK_GPU_IXF").map(|v| v != "0").unwrap_or(true))
}

// ---------------------------------------------------------------------------
// Stats (observation only)

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
static S_INST: AtomicU64 = AtomicU64::new(0);
static S_DECL: AtomicU64 = AtomicU64::new(0);
static S_ROUNDS: AtomicU64 = AtomicU64::new(0);
static S_FOLDS: AtomicU64 = AtomicU64::new(0);
static S_H2D: AtomicU64 = AtomicU64::new(0);
static S_OPEN_US: AtomicU64 = AtomicU64::new(0);
static S_UP_US: AtomicU64 = AtomicU64::new(0);
static S_BUILD_US: AtomicU64 = AtomicU64::new(0);
static S_ROUND_US: AtomicU64 = AtomicU64::new(0);
static S_FOLD_US: AtomicU64 = AtomicU64::new(0);
static S_HAND_US: AtomicU64 = AtomicU64::new(0);
static S_SMALL_US: AtomicU64 = AtomicU64::new(0);
fn add_us(s: &AtomicU64, secs: f64) {
    s.fetch_add((secs * 1e6) as u64, Ordering::Relaxed);
}
pub fn ixf_stats() -> IxfStats {
    let us = |s: &AtomicU64| s.load(Ordering::Relaxed) as f64 * 1e-6;
    IxfStats {
        instances: S_INST.load(Ordering::Relaxed),
        declined: S_DECL.load(Ordering::Relaxed),
        rounds: S_ROUNDS.load(Ordering::Relaxed),
        folds: S_FOLDS.load(Ordering::Relaxed),
        bytes_h2d: S_H2D.load(Ordering::Relaxed),
        secs_open: us(&S_OPEN_US),
        secs_upload: us(&S_UP_US),
        secs_build: us(&S_BUILD_US),
        secs_round: us(&S_ROUND_US),
        secs_fold: us(&S_FOLD_US),
        secs_handover: us(&S_HAND_US),
        secs_host_small: us(&S_SMALL_US),
    }
}
pub fn ixf_stats_reset() {
    for s in [&S_INST, &S_DECL, &S_ROUNDS, &S_FOLDS, &S_H2D, &S_OPEN_US, &S_UP_US, &S_BUILD_US, &S_ROUND_US, &S_FOLD_US, &S_HAND_US, &S_SMALL_US] {
        s.store(0, Ordering::Relaxed);
    }
}

// ---------------------------------------------------------------------------
// Device state

/// Kernel parameters (== kernels_ixf.cu `struct OP`).
#[repr(C)]
#[derive(Clone, Copy)]
struct OP {
    q: u32,
    s: u32,
    c31: u32,
    c32: u32,
    kind: u32,
    deg: u32,
    eq_mode: u32,
    lo_bits: u32,
    sh_mode: u32,
    sh_shift: u32,
    n_pairs: u32,
    pad0: u32,
}

/// The per-instance chain state (the small tables live on the host as
/// packed KTabs and are re-uploaded per round; the three stacked tables
/// live only on the device).
struct Chain {
    kind: u8,
    /// Total variables / current elements per table / rounds done.
    n_vars: usize,
    n: usize,
    t: usize,
    n_pos: usize,
    /// Which of the four big buffers holds table k (0..3); the fourth is
    /// the scratch.
    tab: [usize; 3],
    scratch: usize,
    /// The eq factor: h = the low group's variables; eq_lo (2^(h-t)
    /// elements, folded per round while t < h); eq_hi (2^(n_vars-h), fixed,
    /// device-resident + a host copy for the handover / the switch to G);
    /// g = the remaining eq table once t >= h (2^(n_vars-t) elements).
    h: usize,
    eq_lo: KTab,
    eq_hi: KTab,
    g: Option<KTab>,
    /// The requant shift: the per-slot layer table (slots elements; a
    /// broadcast while t < n_pos), then l (folded from t = n_pos on).
    sh_slots: Option<KTab>,
    l: Option<KTab>,
    /// Sequence check for the round/fold alternation.
    expect_fold: bool,
}

struct Ixf {
    dev: Arc<CudaDevice>,
    sk: CudaStream,
    f: std::collections::HashMap<&'static str, CudaFunction>,
    /// The four big buffers (three tables + the rotating scratch).
    big: [DevBuf; 4],
    /// The layers' i64 sources (all three tables of an instance).
    src: DevBuf,
    /// Small device tables: eqA (per-round upload), eqB (once), sh/l, r, lay meta.
    eq_a: DevBuf,
    eq_b: DevBuf,
    sh: DevBuf,
    r_d: DevBuf,
    lay_d: DevBuf,
    partial: DevBuf,
    /// Pinned staging: two chunks for the source upload; one for the small
    /// tables + params; one for the partial readback.
    stg: [HostPinned; 2],
    ev: [sys::CUevent; 2],
    small_h: HostPinned,
    partial_h: HostPinned,
    held: usize,
    chain: Option<Chain>,
    last_kernel_ms: f64,
}

unsafe impl Send for Ixf {}

static IXFS: OnceLock<Option<Mutex<Ixf>>> = OnceLock::new();
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

fn init_ixf() -> Result<Ixf, String> {
    let dev = device_handle().ok_or_else(|| "no device".to_string())?;
    dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
    let major = dev.attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR).map_err(|e| e.to_string())?;
    let minor = dev.attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR).map_err(|e| e.to_string())?;
    let t0 = Instant::now();
    let arch = arch_str((major, minor));
    // PTX cached on disk keyed by (source, options, arch) — as k9.rs.
    let opts_str = format!("-DTOX={TOX}|{}", arch.unwrap_or("generic"));
    let cache_path = {
        use sha2::Digest;
        let mut h = sha2::Sha256::new();
        h.update(KSRC.as_bytes());
        h.update(opts_str.as_bytes());
        let d: [u8; 32] = h.finalize().into();
        let hex: String = d.iter().take(16).map(|b| format!("{b:02x}")).collect();
        let base = std::env::var("XDG_CACHE_HOME").ok().map(std::path::PathBuf::from).or_else(|| std::env::var("HOME").ok().map(|h| std::path::PathBuf::from(h).join(".cache")));
        base.map(|b| b.join("zkmatrix-gpu").join(format!("ixf-{hex}.ptx")))
    };
    let cached: Option<String> = cache_path.as_ref().and_then(|p| std::fs::read_to_string(p).ok()).filter(|s| !s.is_empty());
    let ptx = match cached {
        Some(src) => cudarc::nvrtc::Ptx::from_src(src),
        None => {
            let compile = |arch: Option<&'static str>| {
                let opts = CompileOptions { arch, options: vec![format!("-DTOX={TOX}")], ..Default::default() };
                compile_ptx_with_opts(KSRC, opts)
            };
            let ptx = match compile(arch) {
                Ok(p) => p,
                Err(e1) => match compile(None) {
                    Ok(p) => p,
                    Err(e2) => return Err(format!("NVRTC compile (ixf) failed: {e1}; generic retry: {e2}")),
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
    dev.load_ptx(ptx, MODULE, FUNCS).map_err(|e| format!("cuModuleLoadData (ixf): {e}"))?;
    let secs_load = t1.elapsed().as_secs_f64();
    let mut f = std::collections::HashMap::new();
    for &name in FUNCS {
        f.insert(name, dev.get_func(MODULE, name).ok_or_else(|| format!("{name} missing"))?);
    }
    let sk = dev.fork_default_stream().map_err(|e| format!("ixf stream: {e}"))?;
    let mk_ev = || cu::event::create(sys::CUevent_flags::CU_EVENT_DISABLE_TIMING).map_err(|e| format!("cuEventCreate: {e}"));
    let ev = [mk_ev()?, mk_ev()?];
    let mut stg = [HostPinned::empty(), HostPinned::empty()];
    for s in stg.iter_mut() {
        s.grow(stg_bytes())?;
    }
    let mut small_h = HostPinned::empty();
    small_h.grow(1 << 20)?;
    let mut partial_h = HostPinned::empty();
    partial_h.grow(4 * 16 * 8)?;
    let mut partial = DevBuf::empty();
    partial.grow(4 * 16 * 8)?;
    let mut r_d = DevBuf::empty();
    r_d.grow(64)?;
    let mut lay_d = DevBuf::empty();
    lay_d.grow(32 * 8)?;
    if verbose() {
        let occ: Vec<String> = FUNCS
            .iter()
            .map(|name| {
                let thr = if *name == "k_oixf_round" { TOX } else { TEL };
                let b = f.get(name).map(|fun| fun.occupancy_max_active_blocks_per_multiprocessor(thr, 0, None).unwrap_or(0)).unwrap_or(0);
                format!("{name}: {b} blk/SM ({} warps)", b * thr / 32)
            })
            .collect();
        eprintln!(
            "[UPERF2-O] ixf init: PTX {secs_ptx:.2}s + module load {secs_load:.2}s; min_pairs {}, low bits {}; occupancy: {}",
            min_pairs(),
            low_bits(),
            occ.join("; ")
        );
    }
    Ok(Ixf {
        dev,
        sk,
        f,
        big: [DevBuf::empty(), DevBuf::empty(), DevBuf::empty(), DevBuf::empty()],
        src: DevBuf::empty(),
        eq_a: DevBuf::empty(),
        eq_b: DevBuf::empty(),
        sh: DevBuf::empty(),
        r_d,
        lay_d,
        partial,
        stg,
        ev,
        small_h,
        partial_h,
        held: 0,
        chain: None,
        last_kernel_ms: 0.0,
    })
}

fn ixfs() -> Option<&'static Mutex<Ixf>> {
    IXFS.get_or_init(|| match init_ixf() {
        Ok(k) => Some(Mutex::new(k)),
        Err(e) => {
            *INIT_ERR.lock().unwrap() = Some(e);
            None
        }
    })
    .as_ref()
}

/// Live iff lane K's `enabled()` AND ZK_GPU_IXF != 0 AND not bypassed AND
/// not disabled by an earlier device error AND not under `oracle_mode()`.
fn live() -> bool {
    super::cuda::enabled() && requested() && !BYPASS.load(Ordering::Relaxed) && !DISABLED.load(Ordering::Relaxed) && !oracle_mode()
}

pub fn ixf_label() -> String {
    if !super::cuda::enabled() {
        return format!("ixf: off ({})", super::cuda::label());
    }
    if !requested() {
        return "ixf: off (ZK_GPU_IXF=0)".to_string();
    }
    if BYPASS.load(Ordering::Relaxed) {
        return "ixf: bypassed (harness)".to_string();
    }
    match ixfs() {
        Some(k) => {
            let k = k.lock().unwrap();
            format!("ixf: on — device-built zero-check tables + device chain (held {:.2} GB, min_pairs {}, low bits {})", k.held as f64 / 1e9, min_pairs(), low_bits())
        }
        None => format!("ixf: FAILED to initialize ({})", INIT_ERR.lock().unwrap().clone().unwrap_or_default()),
    }
}

/// Free the big device buffers (the end of the claim layer: the descents'
/// K9 chains want the VRAM). No chain may be open.
pub fn ixf_release() {
    if let Some(Some(m)) = IXFS.get() {
        let mut s = m.lock().unwrap();
        assert!(s.chain.is_none(), "[UPERF2-O] ixf_release while a device chain is open");
        s.release_big();
    }
}

// ---------------------------------------------------------------------------
// The chain handle (fold.rs drives it; the state lives in the singleton).

pub struct IxfDevChain {
    /// Elements per table now.
    pub n: usize,
    /// Rounds done.
    pub t: usize,
}

impl IxfDevChain {
    /// True while the device should run the next round (>= min_pairs
    /// pair-blocks per table).
    pub fn device_next(&self) -> bool {
        self.n / (2 * KL) >= min_pairs()
    }
}

/// Open a device chain for one stacked zero-check instance: `None` = declined
/// (module off, budget, shape) — the caller builds on the host.
pub fn ixf_zc_open(kf: &KField, spec: &IxfZcSpec) -> Option<IxfDevChain> {
    if !live() {
        return None;
    }
    let kern = kf.kern.as_ref()?;
    let n_vars = spec.n_pos + spec.lambda;
    if n_vars < 6 || spec.n_pos < 1 || (1usize << n_vars) / (2 * KL) < min_pairs() {
        S_DECL.fetch_add(1, Ordering::Relaxed);
        return None;
    }
    let m = ixfs()?;
    let mut s = m.lock().unwrap();
    assert!(s.chain.is_none(), "[UPERF2-O] ixf_zc_open while a device chain is open (protocol violation)");
    let t0 = Instant::now();
    match s.open(kf, kern, spec) {
        Ok(true) => {
            S_INST.fetch_add(1, Ordering::Relaxed);
            add_us(&S_OPEN_US, t0.elapsed().as_secs_f64());
            let c = s.chain.as_ref().unwrap();
            if verbose() {
                eprintln!(
                    "[UPERF2-O] ixf open kind {} n 2^{} (n_pos {}, lambda {}): {:.1} ms (held {:.2} GB)",
                    spec.kind_id(),
                    n_vars,
                    spec.n_pos,
                    spec.lambda,
                    t0.elapsed().as_secs_f64() * 1e3,
                    s.held as f64 / 1e9
                );
            }
            Some(IxfDevChain { n: c.n, t: 0 })
        }
        Ok(false) => {
            S_DECL.fetch_add(1, Ordering::Relaxed);
            None
        }
        Err(e) => {
            s.fail(&e);
            None
        }
    }
}

/// One round: the node values (deg + 1 canonical K-elements) of the current
/// tables. `Err` = the device failed (the chain is closed and the module
/// disabled; the caller rebuilds on the host).
pub fn ixf_zc_round(kf: &KField, ch: &mut IxfDevChain, deg: usize) -> Result<Vec<KElem>, String> {
    let m = ixfs().ok_or("ixf: no device")?;
    let mut s = m.lock().unwrap();
    let t0 = Instant::now();
    let r = s.round(kf, deg);
    match r {
        Ok(v) => {
            S_ROUNDS.fetch_add(1, Ordering::Relaxed);
            add_us(&S_ROUND_US, t0.elapsed().as_secs_f64());
            if verbose() {
                eprintln!("[UPERF2-O] ixf round t {} n {} deg {deg}: {:.2} ms (kernel+sync {:.2} ms)", ch.t, ch.n, t0.elapsed().as_secs_f64() * 1e3, s.last_kernel_ms);
            }
            Ok(v)
        }
        Err(e) => {
            s.fail(&e);
            Err(e)
        }
    }
}

/// The fold by r of every table (device + the small host tables).
pub fn ixf_zc_fold(kf: &KField, ch: &mut IxfDevChain, r: &KElem) -> Result<(), String> {
    let m = ixfs().ok_or("ixf: no device")?;
    let mut s = m.lock().unwrap();
    let t0 = Instant::now();
    match s.fold(kf, r) {
        Ok(()) => {
            S_FOLDS.fetch_add(1, Ordering::Relaxed);
            add_us(&S_FOLD_US, t0.elapsed().as_secs_f64());
            let c = s.chain.as_ref().unwrap();
            ch.n = c.n;
            ch.t = c.t;
            Ok(())
        }
        Err(e) => {
            s.fail(&e);
            Err(e)
        }
    }
}

/// Close the chain: every factor table of the current size materialized on
/// the host in the packed layout — [eq, t1, t2, t3, (sh)] — for the CPU
/// loop. The big device buffers stay allocated for the next instance.
pub fn ixf_zc_handover(kf: &KField, ch: IxfDevChain) -> Result<Vec<KTab>, String> {
    let m = ixfs().ok_or("ixf: no device")?;
    let mut s = m.lock().unwrap();
    let t0 = Instant::now();
    let _ = ch;
    match s.handover(kf) {
        Ok(v) => {
            add_us(&S_HAND_US, t0.elapsed().as_secs_f64());
            Ok(v)
        }
        Err(e) => {
            s.fail(&e);
            Err(e)
        }
    }
}

/// Abandon the chain (after a host-side failure); the module stays live.
pub fn ixf_zc_abort(ch: IxfDevChain) {
    let _ = ch;
    if let Some(Some(m)) = IXFS.get() {
        let mut s = m.lock().unwrap();
        s.chain = None;
    }
}

// ---------------------------------------------------------------------------
// The device work

impl Ixf {
    fn fail(&mut self, e: &str) {
        if !WARNED.swap(true, Ordering::Relaxed) {
            eprintln!("[UPERF2-O] gpu ixf failed ({e}); this instance is rebuilt on the host and later zero-check instances run on the CPU");
        }
        self.chain = None;
        self.release_big();
        DISABLED.store(true, Ordering::Relaxed);
    }

    fn sync(&self) -> Result<(), String> {
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync: {e}"))
    }

    fn release_big(&mut self) {
        let _ = self.sync();
        let mut freed = 0usize;
        for b in self.big.iter_mut() {
            freed += b.bytes;
            b.free();
        }
        freed += self.src.bytes;
        self.src.free();
        self.held = self.held.saturating_sub(freed);
        if verbose() && freed > 0 {
            eprintln!("[UPERF2-O] ixf: released {:.2} GB of device buffers", freed as f64 / 1e9);
        }
    }

    fn launch(&self, name: &str, grid: u32, block: u32, args: &mut [*mut c_void]) -> Result<(), String> {
        let f = self.f.get(name).ok_or_else(|| format!("{name} missing"))?.clone();
        let cfg = LaunchConfig { grid_dim: (grid.max(1), 1, 1), block_dim: (block, 1, 1), shared_mem_bytes: 0 };
        unsafe { f.launch_on_stream(&self.sk, cfg, args) }.map_err(|e| format!("launch {name}: {e}"))
    }

    /// Upload host words (any Copy type as bytes) to `dst` through the pinned
    /// staging (memcpy into pinned on the pool, async DMA on the compute
    /// stream, two buffers ping-pong on events).
    fn upload_bytes(&mut self, dst: sys::CUdeviceptr, src: &[u8], pp: &mut usize) -> Result<(), String> {
        let per = stg_bytes();
        let mut off = 0usize;
        while off < src.len() {
            let n = per.min(src.len() - off);
            let i = *pp & 1;
            unsafe { cu::event::synchronize(self.ev[i]) }.map_err(|e| format!("event sync: {e}"))?;
            {
                let d = self.stg[i].slice_mut::<u8>(n);
                let s = &src[off..off + n];
                if threads() > 1 && n >= (1 << 20) {
                    POOL.install(|| {
                        use rayon::prelude::*;
                        d.par_chunks_mut(1 << 20).zip(s.par_chunks(1 << 20)).for_each(|(d, s)| d.copy_from_slice(s));
                    });
                } else {
                    d.copy_from_slice(s);
                }
            }
            unsafe { cu::memcpy_htod_async(dst + off as u64, self.stg[i].slice::<u8>(n), self.sk.stream) }.map_err(|e| format!("h2d: {e}"))?;
            unsafe { cu::event::record(self.ev[i], self.sk.stream) }.map_err(|e| format!("record: {e}"))?;
            S_H2D.fetch_add(n as u64, Ordering::Relaxed);
            off += n;
            *pp += 1;
        }
        Ok(())
    }

    /// Small synchronous-ordered upload through the small pinned buffer
    /// (stream-ordered on sk; waits for the previous users of the buffer).
    fn upload_small(&mut self, dst: sys::CUdeviceptr, words: &[u32]) -> Result<(), String> {
        let bytes = words.len() * 4;
        if bytes > self.small_h.bytes {
            self.sync()?;
            self.small_h.grow(bytes.next_power_of_two())?;
        }
        // The previous launches reading small_h's earlier contents must be done.
        self.sync()?;
        self.small_h.slice_mut::<u32>(words.len()).copy_from_slice(words);
        unsafe { cu::memcpy_htod_async(dst, self.small_h.slice::<u32>(words.len()), self.sk.stream) }.map_err(|e| format!("h2d small: {e}"))?;
        S_H2D.fetch_add(bytes as u64, Ordering::Relaxed);
        Ok(())
    }

    fn grow(b: &mut DevBuf, bytes: usize, held: &mut usize) -> Result<(), String> {
        let old = b.bytes;
        if bytes > old {
            b.grow(bytes)?;
            *held += b.bytes - old;
        }
        Ok(())
    }

    fn open(&mut self, kf: &KField, kern: &super::super::kfield::KKern, spec: &IxfZcSpec) -> Result<bool, String> {
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let n_vars = spec.n_pos + spec.lambda;
        let n = 1usize << n_vars;
        let words = (n / KL) * KBLK;
        let tab_bytes = words * 4;
        // Sources: the three tables' layers concatenated (i64).
        let mut src_len = 0usize; // elements
        let mut lay_meta: [[u64; 32]; 3] = [[0u64; 32]; 3];
        for k in 0..3 {
            for (li, sl) in spec.layers[k].iter().enumerate() {
                assert!(li < 16, "ixf: at most 16 layers");
                lay_meta[k][li] = src_len as u64;
                lay_meta[k][16 + li] = (sl.len() / spec.cols_real) as u64;
                src_len += sl.len();
            }
        }
        let src_bytes = src_len * 8;
        // Budget: 3 tables + half a scratch + the sources, against the free VRAM (256 MB margin).
        let need_big = [tab_bytes, tab_bytes, tab_bytes, tab_bytes / 2];
        let mut more = 0usize;
        for (b, need) in self.big.iter().zip(need_big.iter()) {
            more += need.saturating_sub(b.bytes);
        }
        more += src_bytes.saturating_sub(self.src.bytes);
        let (free, _total) = cu::mem_get_info().map_err(|e| format!("cuMemGetInfo: {e}"))?;
        if more + (256usize << 20) > free {
            if verbose() {
                eprintln!("[UPERF2-O] ixf: declined n 2^{n_vars} (need {:.2} GB more, free {:.2} GB)", more as f64 / 1e9, free as f64 / 1e9);
            }
            return Ok(false);
        }
        self.sync()?;
        for (i, need) in need_big.iter().enumerate() {
            let mut held = self.held;
            Self::grow(&mut self.big[i], *need, &mut held)?;
            self.held = held;
        }
        {
            let mut held = self.held;
            Self::grow(&mut self.src, src_bytes.max(8), &mut held)?;
            self.held = held;
        }
        let small_words = ((1usize << low_bits()).max(1 << (n_vars.saturating_sub(low_bits()))) / KL).max(1) * KBLK;
        let mut held = self.held;
        Self::grow(&mut self.eq_a, small_words * 4, &mut held)?;
        Self::grow(&mut self.eq_b, small_words * 4, &mut held)?;
        Self::grow(&mut self.sh, ((spec.slots.max(KL) / KL) * KBLK * 4).max(KBLK * 4), &mut held)?;
        self.held = held;
        // ---- upload the sources (pinned staging), then build the three tables.
        let tu = Instant::now();
        let mut pp = 0usize;
        let mut off = 0usize;
        for k in 0..3 {
            for sl in spec.layers[k].iter() {
                let bytes: &[u8] = unsafe { std::slice::from_raw_parts(sl.as_ptr() as *const u8, sl.len() * 8) };
                self.upload_bytes(self.src.ptr + (off * 8) as u64, bytes, &mut pp)?;
                off += sl.len();
            }
        }
        add_us(&S_UP_US, tu.elapsed().as_secs_f64());
        let tb = Instant::now();
        let q = kern.q;
        let lcp = spec.cols_pad.trailing_zeros();
        assert_eq!(1usize << lcp, spec.cols_pad, "ixf: cols_pad is a power of two");
        for k in 0..3 {
            // per-table layer meta (u64[32]) — stream-ordered before the launch.
            let meta_words: Vec<u32> = lay_meta[k].iter().flat_map(|v| [(*v & 0xffff_ffff) as u32, (*v >> 32) as u32]).collect();
            self.upload_small(self.lay_d.ptr, &meta_words)?;
            let n_layers = spec.layers[k].len() as u32;
            let n_pos = spec.n_pos as u32;
            let cols_real = spec.cols_real as u32;
            let n_u = n as u32;
            let src_p = self.src.ptr;
            let lay_p = self.lay_d.ptr;
            let dst_p = self.big[k].ptr;
            let mut args: [*mut c_void; 9] = [
                &src_p as *const _ as *mut _,
                &lay_p as *const _ as *mut _,
                &n_layers as *const _ as *mut _,
                &n_pos as *const _ as *mut _,
                &lcp as *const _ as *mut _,
                &cols_real as *const _ as *mut _,
                &q as *const _ as *mut _,
                &dst_p as *const _ as *mut _,
                &n_u as *const _ as *mut _,
            ];
            let grid = ((n as u32).div_ceil(TEL)).min(GRID_CAP);
            self.launch("k_oixf_build", grid, TEL, &mut args)?;
        }
        // ---- the small tables: eq low / high, the shift slots.
        let h = low_bits().min(n_vars);
        let eq_lo = kf.kt_eq_table_par(&spec.point[..h]);
        let eq_hi = kf.kt_eq_table_par(&spec.point[h..]);
        self.upload_small(self.eq_b.ptr, &eq_hi.d)?;
        let sh_slots = if spec.kind_id() == 2 {
            let mut t = KTab::zeroed(spec.slots.max(KL));
            for (i, e) in spec.sh_layer.iter().enumerate() {
                t.set(i, e);
            }
            self.upload_small(self.sh.ptr, &t.d)?;
            Some(t)
        } else {
            None
        };
        if super::cuda::enabled() && verbose() {
            self.sync()?;
        }
        add_us(&S_BUILD_US, tb.elapsed().as_secs_f64());
        self.chain = Some(Chain {
            kind: spec.kind_id(),
            n_vars,
            n,
            t: 0,
            n_pos: spec.n_pos,
            tab: [0, 1, 2],
            scratch: 3,
            h,
            eq_lo,
            eq_hi,
            g: None,
            sh_slots,
            l: None,
            expect_fold: false,
        });
        Ok(true)
    }

    fn params(&self, kern: &super::super::kfield::KKern, c: &Chain, deg: usize) -> OP {
        let n_pairs = c.n / 2;
        let (eq_mode, lo_bits) = if c.t < c.h { (0u32, (c.h - c.t - 1) as u32) } else { (1u32, 0u32) };
        let (sh_mode, sh_shift) = if c.kind == 2 {
            if c.t < c.n_pos { (1u32, (c.n_pos - c.t - 1) as u32) } else { (2u32, 0u32) }
        } else {
            (0u32, 0u32)
        };
        OP {
            q: kern.q as u32,
            s: kern.s as u32,
            c31: kern.c31 as u32,
            c32: kern.c32 as u32,
            kind: c.kind as u32,
            deg: deg as u32,
            eq_mode,
            lo_bits,
            sh_mode,
            sh_shift,
            n_pairs: n_pairs as u32,
            pad0: 0,
        }
    }

    fn round(&mut self, kf: &KField, deg: usize) -> Result<Vec<KElem>, String> {
        let kern = *kf.kern.as_ref().ok_or("ixf: no kernel")?;
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let c = self.chain.take().ok_or("ixf: round without a chain")?;
        assert!(!c.expect_fold, "[UPERF2-O] ixf: round while a fold is expected (protocol violation)");
        assert!(deg >= 2 && deg <= 3, "ixf: degree {deg} (2 or 3)");
        let n_pairs = c.n / 2;
        let p = self.params(&kern, &c, deg);
        // eqA: eq_lo (mode 0) or g (mode 1); shift: sh_slots (broadcast) or l (pair).
        let res = (|| -> Result<Vec<KElem>, String> {
            let ts = Instant::now();
            if c.t < c.h {
                self.upload_small(self.eq_a.ptr, &c.eq_lo.d)?;
            } else {
                self.upload_small(self.eq_a.ptr, &c.g.as_ref().ok_or("ixf: g missing")?.d)?;
            }
            if c.kind == 2 && c.t >= c.n_pos {
                self.upload_small(self.sh.ptr, &c.l.as_ref().ok_or("ixf: l missing")?.d)?;
            }
            add_us(&S_SMALL_US, ts.elapsed().as_secs_f64());
            unsafe { cu::memset_d8_async(self.partial.ptr, 0, 4 * 16 * 8, self.sk.stream) }.map_err(|e| format!("memset partial: {e}"))?;
            let tk = Instant::now();
            let t1 = self.big[c.tab[0]].ptr;
            let t2 = self.big[c.tab[1]].ptr;
            let t3 = self.big[c.tab[2]].ptr;
            let ea = self.eq_a.ptr;
            let eb = self.eq_b.ptr;
            let shp = self.sh.ptr;
            let part = self.partial.ptr;
            let mut args: [*mut c_void; 8] = [
                &p as *const _ as *mut _,
                &t1 as *const _ as *mut _,
                &t2 as *const _ as *mut _,
                &t3 as *const _ as *mut _,
                &ea as *const _ as *mut _,
                &eb as *const _ as *mut _,
                &shp as *const _ as *mut _,
                &part as *const _ as *mut _,
            ];
            let grid = ((n_pairs as u32).div_ceil(TOX)).min(GRID_CAP);
            self.launch("k_oixf_round", grid, TOX, &mut args)?;
            self.sync()?;
            let nn = deg + 1;
            let h = self.partial_h.slice_mut::<u64>(nn * 16);
            unsafe { cu::memcpy_dtoh_sync(h, self.partial.ptr) }.map_err(|e| format!("d2h partial: {e}"))?;
            self.last_kernel_ms = tk.elapsed().as_secs_f64() * 1e3;
            let q = kern.q;
            let out: Vec<KElem> = (0..nn).map(|ni| (0..K_DEG).map(|t| h[ni * 16 + t] % q).collect()).collect();
            Ok(out)
        })();
        let mut c = c;
        c.expect_fold = res.is_ok();
        self.chain = Some(c);
        res
    }

    fn fold(&mut self, kf: &KField, r: &KElem) -> Result<(), String> {
        let kern = *kf.kern.as_ref().ok_or("ixf: no kernel")?;
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let mut c = self.chain.take().ok_or("ixf: fold without a chain")?;
        assert!(c.expect_fold, "[UPERF2-O] ixf: fold while a round is expected (protocol violation)");
        let n_out = c.n / 2;
        assert!(n_out >= KL, "ixf: device fold below one block");
        let res = (|| -> Result<(), String> {
            let rk = kop(r);
            self.upload_small(self.r_d.ptr, &rk)?;
            let p = self.params(&kern, &c, 2);
            let n_u = n_out as u32;
            let grid = ((n_out as u32).div_ceil(TEL)).min(GRID_CAP);
            for k in 0..3 {
                let src = self.big[c.tab[k]].ptr;
                let dst = self.big[c.scratch].ptr;
                let rp = self.r_d.ptr;
                let mut args: [*mut c_void; 5] = [&p as *const _ as *mut _, &rp as *const _ as *mut _, &src as *const _ as *mut _, &dst as *const _ as *mut _, &n_u as *const _ as *mut _];
                self.launch("k_oixf_fold", grid, TEL, &mut args)?;
                let old = c.tab[k];
                c.tab[k] = c.scratch;
                c.scratch = old;
            }
            // The small host tables.
            let ts = Instant::now();
            if c.t < c.h {
                kf.kt_fold_inplace(&mut c.eq_lo, r);
                if c.t + 1 == c.h {
                    // the low group is exhausted: the remaining eq is C x eq_hi
                    let cst = c.eq_lo.get(0);
                    let mut g = KTab::zeroed(c.eq_hi.n);
                    for i in 0..c.eq_hi.n {
                        g.set(i, &kf.mul(&cst, &c.eq_hi.get(i)));
                    }
                    c.g = Some(g);
                }
            } else {
                let g = c.g.as_mut().ok_or("ixf: g missing at fold")?;
                kf.kt_fold_inplace(g, r);
            }
            if c.kind == 2 {
                if c.t < c.n_pos {
                    if c.t + 1 == c.n_pos {
                        // position variables exhausted: the layer table (slots
                        // elements = 2^lambda) is the table from now on
                        let sh = c.sh_slots.as_ref().ok_or("ixf: sh missing")?;
                        let slots = 1usize << (c.n_vars - c.n_pos);
                        let mut l = KTab::zeroed(slots);
                        for i in 0..slots {
                            l.set(i, &sh.get(i));
                        }
                        c.l = Some(l);
                    }
                } else {
                    let l = c.l.as_mut().ok_or("ixf: l missing at fold")?;
                    kf.kt_fold_inplace(l, r);
                }
            }
            add_us(&S_SMALL_US, ts.elapsed().as_secs_f64());
            Ok(())
        })();
        if res.is_ok() {
            c.t += 1;
            c.n = n_out;
            c.expect_fold = false;
        }
        self.chain = Some(c);
        res
    }

    fn handover(&mut self, kf: &KField) -> Result<Vec<KTab>, String> {
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let c = self.chain.take().ok_or("ixf: handover without a chain")?;
        assert!(!c.expect_fold, "[UPERF2-O] ixf: handover while a fold is expected");
        let n = c.n;
        let mut out: Vec<KTab> = Vec::with_capacity(5);
        // eq
        let mut eq = KTab::zeroed(n);
        if c.t < c.h {
            let a = c.h - c.t;
            let mask = (1usize << a) - 1;
            for i in 0..n {
                eq.set(i, &kf.mul(&c.eq_lo.get(i & mask), &c.eq_hi.get(i >> a)));
            }
        } else {
            let g = c.g.as_ref().ok_or("ixf: g missing at handover")?;
            assert_eq!(g.n, n);
            for i in 0..n {
                eq.set(i, &g.get(i));
            }
        }
        out.push(eq);
        // the three stacked tables (device -> host)
        self.sync()?;
        let words = n.div_ceil(KL) * KBLK;
        for k in 0..3 {
            let mut t = KTab::zeroed(n);
            let src = self.big[c.tab[k]].ptr;
            unsafe { cu::memcpy_dtoh_sync(&mut t.d[..words], src) }.map_err(|e| format!("d2h table: {e}"))?;
            out.push(t);
        }
        // the shift table
        if c.kind == 2 {
            let mut sh = KTab::zeroed(n);
            if c.t < c.n_pos {
                let sl = c.sh_slots.as_ref().ok_or("ixf: sh missing at handover")?;
                let a = c.n_pos - c.t;
                for i in 0..n {
                    sh.set(i, &sl.get(i >> a));
                }
            } else {
                let l = c.l.as_ref().ok_or("ixf: l missing at handover")?;
                assert_eq!(l.n, n);
                for i in 0..n {
                    sh.set(i, &l.get(i));
                }
            }
            out.push(sh);
        }
        Ok(out)
    }
}

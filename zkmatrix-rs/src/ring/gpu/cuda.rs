// [UPERF2-K] The CUDA implementation of the GPU rung (feature `gpu-cuda`).
// See mod.rs for the discipline; kernels.cu for the device code.
//
// Execution model of the ported GEMM (`Gpu::gemm`): the call's positions
// [0, len) are cut into the CPU's exact-integer windows (`ntt_window_terms`),
// each window into u-blocks of `ublk` positions (sized to a device budget
// and to >= PIPE_STAGES sub-blocks per call so the stages overlap); per
// u-block the host PACKS the operands into pinned staging (u32 mod-q / i8
// digits when they fit, else u64 / i64; the lifts happen on the device),
// the copy stream UPLOADS them, the compute stream TRANSFORMS them
// (t-major store) and runs the split-K GEMM into the window accumulator;
// two staging/source buffers ping-pong with events so pack(i+1), h2d(i+1)
// and gpu(i) overlap; a window ends with the flush kernels; the mod-q
// output is copied back once per call.

use super::super::aux::{self, D};
use super::super::eval_proof::{ntt_window_terms, threads, SmallRings};
use super::super::{Poly, RingCtx};
use cudarc::driver::result as cu;
use cudarc::driver::{sys, CudaDevice, CudaStream, LaunchAsync, LaunchConfig};
use cudarc::nvrtc::{compile_ptx_with_opts, CompileOptions};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, LazyLock, Mutex, OnceLock};
use std::time::Instant;

const KSRC: &str = include_str!("kernels.cu");
const MODULE: &str = "zkgpu";
const FUNCS: &[&str] = &[
    "k_mulmod_probe",
    "k_ntt_fwd",
    "k_gemm_split",
    "k_gemm_split_m16",
    "k_flush_reduce",
    "k_ntt_inv",
    "k_imad_probe",
    "k_ntt_fwd_pool", // [UPERF2-Q]
];
/// Rings per block of the transform kernels (default; `ZK_GPU_RFWD` overrides,
/// passed to NVRTC as -DR_FWD) and threads per transform block (`ZK_GPU_TFWD`).
const R_FWD: usize = 32;
const T_FWD: usize = 256;
fn r_fwd() -> usize {
    static V: OnceLock<usize> = OnceLock::new();
    *V.get_or_init(|| env_usize("ZK_GPU_RFWD", R_FWD).max(1))
}
fn t_fwd() -> u32 {
    static V: OnceLock<usize> = OnceLock::new();
    *V.get_or_init(|| env_usize("ZK_GPU_TFWD", T_FWD).max(32)) as u32
}
/// GEMM tile (== TM_G / TN_G / KB_G in kernels.cu).
const TM_G: usize = 64;
const TN_G: usize = 64;
const KB_G: usize = 32;
/// Sub-blocks per call the pipeline aims for (pack / h2d / gpu overlap).
const PIPE_STAGES: usize = 4;
/// Smallest u-block worth a device round trip when splitting for the pipeline.
const MIN_UBLK: usize = 64;

// ---------------------------------------------------------------------------
// Raw buffers

/// A device allocation (cuMemAlloc), grown on demand; freed on drop.
/// [UPERF2-L] shared with k9.rs (pub(super)).
pub(super) struct DevBuf {
    pub(super) ptr: sys::CUdeviceptr,
    pub(super) bytes: usize,
}

impl DevBuf {
    pub(super) fn empty() -> Self {
        DevBuf { ptr: 0, bytes: 0 }
    }
    pub(super) fn needs(&self, bytes: usize) -> bool {
        bytes > self.bytes
    }
    /// Grow to at least `bytes` (the caller has synchronized every stream
    /// that could still touch the old allocation).
    pub(super) fn grow(&mut self, bytes: usize) -> Result<(), String> {
        if !self.needs(bytes) {
            return Ok(());
        }
        self.free();
        let want = bytes.max(256);
        let p = unsafe { cu::malloc_sync(want) }.map_err(|e| format!("cuMemAlloc({want} B): {e}"))?;
        self.ptr = p;
        self.bytes = want;
        Ok(())
    }
    pub(super) fn free(&mut self) {
        if self.ptr != 0 {
            let _ = unsafe { cu::free_sync(self.ptr) };
            self.ptr = 0;
            self.bytes = 0;
        }
    }
}

impl Drop for DevBuf {
    fn drop(&mut self) {
        self.free();
    }
}

/// Page-locked host staging (cuMemHostAlloc), grown on demand.
/// [UPERF2-L] shared with k9.rs (pub(super)).
pub(super) struct HostPinned {
    pub(super) ptr: *mut u8,
    pub(super) bytes: usize,
}

impl HostPinned {
    pub(super) fn empty() -> Self {
        HostPinned { ptr: std::ptr::null_mut(), bytes: 0 }
    }
    pub(super) fn needs(&self, bytes: usize) -> bool {
        bytes > self.bytes
    }
    pub(super) fn grow(&mut self, bytes: usize) -> Result<(), String> {
        if !self.needs(bytes) {
            return Ok(());
        }
        self.free();
        let want = bytes.max(256);
        let p = unsafe { cu::malloc_host(want, 0) }.map_err(|e| format!("cuMemHostAlloc({want} B): {e}"))?;
        self.ptr = p as *mut u8;
        self.bytes = want;
        Ok(())
    }
    pub(super) fn free(&mut self) {
        if !self.ptr.is_null() {
            let _ = unsafe { cu::free_host(self.ptr as *mut _) };
            self.ptr = std::ptr::null_mut();
            self.bytes = 0;
        }
    }
    /// The first `n` elements as a typed slice (n * size_of::<T>() <= bytes).
    pub(super) fn slice_mut<T>(&mut self, n: usize) -> &mut [T] {
        assert!(n * std::mem::size_of::<T>() <= self.bytes);
        unsafe { std::slice::from_raw_parts_mut(self.ptr as *mut T, n) }
    }
    pub(super) fn slice<T>(&self, n: usize) -> &[T] {
        assert!(n * std::mem::size_of::<T>() <= self.bytes);
        unsafe { std::slice::from_raw_parts(self.ptr as *const T, n) }
    }
}

impl Drop for HostPinned {
    fn drop(&mut self) {
        self.free();
    }
}

// Plain page-locked memory: a byte buffer like any other for the host
// threads that pack it (the pool writes disjoint chunks).
unsafe impl Send for HostPinned {}
unsafe impl Sync for HostPinned {}

// ---------------------------------------------------------------------------
// State

struct Gpu {
    dev: Arc<CudaDevice>,
    name: String,
    cc: (i32, i32),
    sms: i32,
    vram_total: usize,
    /// Compute stream / copy stream (both non-blocking; explicit events).
    sk: CudaStream,
    sc: CudaStream,
    /// Per ping-pong buffer: "h2d done" (staging reusable, transforms may
    /// start) and "transforms done" (device source reusable).
    ev_h2d: [sys::CUevent; 2],
    ev_fwd: [sys::CUevent; 2],
    psi: DevBuf,
    ipsi: DevBuf,
    n_inv: u64,
    // Device scratch (resident between calls).
    src_a: [DevBuf; 2],
    src_b: [DevBuf; 2],
    a_t: DevBuf,
    b_t: DevBuf,
    acc: DevBuf,
    v: DevBuf,
    out: DevBuf,
    // Pinned host staging (resident between calls).
    st_a: [HostPinned; 2],
    st_b: [HostPinned; 2],
    st_out: HostPinned,
    // [UPERF2-Q] the level-h session's per-ring descriptors (pool index,
    // radix) — device + pinned, ping-pong like src_a / st_a (which the
    // session uses for the value-ring pool).
    desc: [DevBuf; 2],
    st_desc: [HostPinned; 2],
}

// The driver handles are thread-agnostic (the context is bound per thread
// on every entry); the singleton lives behind a Mutex.
unsafe impl Send for Gpu {}

static GPU: OnceLock<Option<Mutex<Gpu>>> = OnceLock::new();
static BYPASS: AtomicBool = AtomicBool::new(false);
static WARNED: AtomicBool = AtomicBool::new(false);
static INIT_ERR: Mutex<Option<String>> = Mutex::new(None);
/// Harness override of the u-block budget (MB); 0 = `ZK_GPU_BLOCK_MB` / default.
static BLOCK_MB: AtomicU64 = AtomicU64::new(0);

/// Harness knob: the device budget for one transformed u-block in MB (the
/// battery forces tiny blocks so windows span many u-blocks); 0 restores
/// `ZK_GPU_BLOCK_MB` / the default.
pub fn set_block_mb(mb: usize) {
    BLOCK_MB.store(mb as u64, Ordering::Relaxed);
}

fn block_budget_bytes() -> usize {
    let o = BLOCK_MB.load(Ordering::Relaxed) as usize;
    (if o > 0 { o } else { env_usize("ZK_GPU_BLOCK_MB", 256) }) << 20
}

/// The kernel-pool of this module (the same `ZK_THREADS` size as
/// eval_proof's; only host-side packing rides it — values are unaffected).
/// [UPERF2-L] shared with k9.rs.
pub(super) static POOL: LazyLock<rayon::ThreadPool> = LazyLock::new(|| {
    rayon::ThreadPoolBuilder::new().num_threads(threads()).build().expect("ZK_THREADS pool (gpu)")
});

pub(super) fn env_flag(name: &str) -> bool {
    std::env::var(name).map(|v| v == "1").unwrap_or(false)
}

pub(super) fn env_usize(name: &str, default: usize) -> usize {
    std::env::var(name).ok().and_then(|v| v.parse::<usize>().ok()).unwrap_or(default)
}

/// `ZK_GPU=1` requested (read once).
fn requested() -> bool {
    static ON: OnceLock<bool> = OnceLock::new();
    *ON.get_or_init(|| env_flag("ZK_GPU"))
}

pub(super) fn verbose() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| env_flag("ZK_GPU_VERBOSE"))
}

/// [UPERF2-L] The device handle for the K-field kernels (k9.rs): the same
/// context as the GEMM's; None when the device failed to initialize.
pub(super) fn device_handle() -> Option<Arc<CudaDevice>> {
    gpu().map(|g| g.lock().unwrap().dev.clone())
}

/// `ZK_GPU_PROFILE=1`: synchronize after every kernel and attribute per
/// kernel (destroys the overlap; analysis only).
fn profile() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| env_flag("ZK_GPU_PROFILE"))
}

/// Minimum D-domain MACs (D * na * nb * len) for a GEMM to go to the device.
fn min_macs() -> u128 {
    static M: OnceLock<usize> = OnceLock::new();
    *M.get_or_init(|| env_usize("ZK_GPU_MIN_MACS", 1 << 22)) as u128
}

fn pipe_stages() -> usize {
    static S: OnceLock<usize> = OnceLock::new();
    *S.get_or_init(|| env_usize("ZK_GPU_STAGES", PIPE_STAGES).max(1))
}

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
    // NVRTC compile once (arch-targeted PTX when the cc is known; the
    // generic default otherwise / on failure).
    let t0 = Instant::now();
    let maxrreg = env_usize("ZK_GPU_MAXRREG", 0);
    let r_fwd = env_usize("ZK_GPU_RFWD", R_FWD);
    let t_fwd = env_usize("ZK_GPU_TFWD", T_FWD);
    let compile = |arch: Option<&'static str>| {
        let opts = CompileOptions {
            arch,
            maxrregcount: if maxrreg > 0 { Some(maxrreg) } else { None },
            options: vec![format!("-DR_FWD={r_fwd}"), format!("-DT_FWD={t_fwd}")],
            ..Default::default()
        };
        compile_ptx_with_opts(KSRC, opts)
    };
    let ptx = match compile(arch_str((major, minor))) {
        Ok(p) => p,
        Err(e1) => match compile(None) {
            Ok(p) => p,
            Err(e2) => return Err(format!("NVRTC compile failed: {e1}; generic retry: {e2}")),
        },
    };
    dev.load_ptx(ptx, MODULE, FUNCS).map_err(|e| format!("cuModuleLoadData: {e}"))?;
    let secs_compile = t0.elapsed().as_secs_f64();
    // Streams + events.
    let sk = dev.fork_default_stream().map_err(|e| format!("compute stream: {e}"))?;
    let sc = dev.fork_default_stream().map_err(|e| format!("copy stream: {e}"))?;
    let mk_ev = || cu::event::create(sys::CUevent_flags::CU_EVENT_DISABLE_TIMING).map_err(|e| format!("cuEventCreate: {e}"));
    let ev_h2d = [mk_ev()?, mk_ev()?];
    let ev_fwd = [mk_ev()?, mk_ev()?];
    // Twiddle tables (the CPU tables, copied — same values).
    let t = aux::build_tables();
    let psi_h: Vec<u64> = (0..D).map(|i| t.psi_brv(i)).collect();
    let ipsi_h: Vec<u64> = (0..D).map(|i| t.ipsi_brv(i)).collect();
    let mut psi = DevBuf::empty();
    let mut ipsi = DevBuf::empty();
    psi.grow(D * 8)?;
    ipsi.grow(D * 8)?;
    unsafe { cu::memcpy_htod_sync(psi.ptr, &psi_h) }.map_err(|e| format!("psi upload: {e}"))?;
    unsafe { cu::memcpy_htod_sync(ipsi.ptr, &ipsi_h) }.map_err(|e| format!("ipsi upload: {e}"))?;
    if verbose() {
        eprintln!(
            "[UPERF2-K] gpu init: {name} (sm_{major}{minor}, {sms} SMs, {:.1} GB), NVRTC compile {secs_compile:.2}s",
            total as f64 / 1e9
        );
    }
    Ok(Gpu {
        dev,
        name,
        cc: (major, minor),
        sms,
        vram_total: total,
        sk,
        sc,
        ev_h2d,
        ev_fwd,
        psi,
        ipsi,
        n_inv: t.n_inv(),
        src_a: [DevBuf::empty(), DevBuf::empty()],
        src_b: [DevBuf::empty(), DevBuf::empty()],
        a_t: DevBuf::empty(),
        b_t: DevBuf::empty(),
        acc: DevBuf::empty(),
        v: DevBuf::empty(),
        out: DevBuf::empty(),
        st_a: [HostPinned::empty(), HostPinned::empty()],
        st_b: [HostPinned::empty(), HostPinned::empty()],
        st_out: HostPinned::empty(),
        desc: [DevBuf::empty(), DevBuf::empty()],
        st_desc: [HostPinned::empty(), HostPinned::empty()],
    })
}

/// The device singleton (initialized on first use; None when it failed —
/// the reason is kept for `label()`).
fn gpu() -> Option<&'static Mutex<Gpu>> {
    GPU.get_or_init(|| match init_gpu() {
        Ok(g) => Some(Mutex::new(g)),
        Err(e) => {
            *INIT_ERR.lock().unwrap() = Some(e);
            None
        }
    })
    .as_ref()
}

/// True when the GPU path is live: feature on (this file), `ZK_GPU=1`, a
/// device initialized, and not bypassed by the harness.
#[inline]
pub fn enabled() -> bool {
    if BYPASS.load(Ordering::Relaxed) || !requested() {
        return false;
    }
    gpu().is_some()
}

/// Harness knob: force the CPU path regardless of `ZK_GPU` (the battery's
/// A/B inside one process). [UPERF2-L] Turning the bypass ON while a
/// K-field descent chain holds device-resident state (k9.rs) is a protocol
/// violation (the host tables would be read stale): asserted.
pub fn set_bypass(on: bool) {
    if on {
        super::k9::assert_no_chain("set_bypass(true)");
    }
    BYPASS.store(on, Ordering::Relaxed);
}

/// Human-readable state (device / reason it is off).
pub fn label() -> String {
    if !requested() {
        // Still try to name the device for the report, without enabling.
        return match gpu() {
            Some(g) => {
                let g = g.lock().unwrap();
                format!("gpu: off (ZK_GPU unset); device present: {} (sm_{}{}, {} SMs, {:.1} GB)", g.name, g.cc.0, g.cc.1, g.sms, g.vram_total as f64 / 1e9)
            }
            None => format!("gpu: off (ZK_GPU unset); no device: {}", INIT_ERR.lock().unwrap().clone().unwrap_or_default()),
        };
    }
    match gpu() {
        Some(g) => {
            let g = g.lock().unwrap();
            format!(
                "gpu-cuda: {} (sm_{}{}, {} SMs, {:.1} GB VRAM), ZK_GPU=1, min_macs {}, block budget {} MB, stages {}, bypass {}",
                g.name,
                g.cc.0,
                g.cc.1,
                g.sms,
                g.vram_total as f64 / 1e9,
                min_macs(),
                block_budget_bytes() >> 20,
                pipe_stages(),
                BYPASS.load(Ordering::Relaxed)
            )
        }
        None => format!("gpu: FAILED to initialize ({}); CPU path", INIT_ERR.lock().unwrap().clone().unwrap_or_default()),
    }
}

// ---------------------------------------------------------------------------
// Stats (observation only)

#[derive(Clone, Debug, Default)]
pub struct GpuStats {
    pub calls: u64,
    pub declined: u64,
    pub macs: u128,
    pub bytes_h2d: u64,
    /// Host time computing s_max (the operand bound; the CPU pays it too).
    pub secs_smax: f64,
    /// Host time packing the staging buffers (overlaps the device).
    pub secs_pack: f64,
    /// Host time blocked on events (staging reuse) and the final drain.
    pub secs_wait: f64,
    /// Device time attributed per kernel class under ZK_GPU_PROFILE=1.
    pub secs_k_h2d: f64,
    pub secs_k_fwd: f64,
    pub secs_k_gemm: f64,
    pub secs_k_flush: f64,
    pub secs_d2h: f64,
    pub secs_total: f64,
}

static S_CALLS: AtomicU64 = AtomicU64::new(0);
static S_DECLINED: AtomicU64 = AtomicU64::new(0);
static S_MACS: AtomicU64 = AtomicU64::new(0); // in units of 2^10 MACs
static S_BYTES: AtomicU64 = AtomicU64::new(0);
static S_SMAX_US: AtomicU64 = AtomicU64::new(0);
static S_PACK_US: AtomicU64 = AtomicU64::new(0);
static S_WAIT_US: AtomicU64 = AtomicU64::new(0);
static S_KH2D_US: AtomicU64 = AtomicU64::new(0);
static S_KFWD_US: AtomicU64 = AtomicU64::new(0);
static S_KGEMM_US: AtomicU64 = AtomicU64::new(0);
static S_KFLUSH_US: AtomicU64 = AtomicU64::new(0);
static S_D2H_US: AtomicU64 = AtomicU64::new(0);
static S_TOTAL_US: AtomicU64 = AtomicU64::new(0);

pub fn stats() -> GpuStats {
    let us = |s: &AtomicU64| s.load(Ordering::Relaxed) as f64 * 1e-6;
    GpuStats {
        calls: S_CALLS.load(Ordering::Relaxed),
        declined: S_DECLINED.load(Ordering::Relaxed),
        macs: (S_MACS.load(Ordering::Relaxed) as u128) << 10,
        bytes_h2d: S_BYTES.load(Ordering::Relaxed),
        secs_smax: us(&S_SMAX_US),
        secs_pack: us(&S_PACK_US),
        secs_wait: us(&S_WAIT_US),
        secs_k_h2d: us(&S_KH2D_US),
        secs_k_fwd: us(&S_KFWD_US),
        secs_k_gemm: us(&S_KGEMM_US),
        secs_k_flush: us(&S_KFLUSH_US),
        secs_d2h: us(&S_D2H_US),
        secs_total: us(&S_TOTAL_US),
    }
}

pub fn stats_reset() {
    for s in [
        &S_CALLS, &S_DECLINED, &S_MACS, &S_BYTES, &S_SMAX_US, &S_PACK_US, &S_WAIT_US, &S_KH2D_US, &S_KFWD_US, &S_KGEMM_US, &S_KFLUSH_US, &S_D2H_US,
        &S_TOTAL_US,
    ] {
        s.store(0, Ordering::Relaxed);
    }
}

fn add_us(s: &AtomicU64, secs: f64) {
    s.fetch_add((secs * 1e6) as u64, Ordering::Relaxed);
}

// ---------------------------------------------------------------------------
// The mulmod probe

#[derive(Clone, Debug, Default)]
pub struct ProbeReport {
    pub device: String,
    pub mismatches: usize,
    pub n: usize,
    pub gmul_per_s: f64,
}

/// The orchestrator's feasibility kernel: 2^20 Goldilocks products x 100
/// launches, compared against the CPU `mul_p`.
pub fn probe() -> Result<ProbeReport, String> {
    let g = gpu().ok_or_else(|| INIT_ERR.lock().unwrap().clone().unwrap_or_else(|| "no device".to_string()))?;
    let g = g.lock().unwrap();
    let dev = &g.dev;
    let f = dev.get_func(MODULE, "k_mulmod_probe").ok_or("k_mulmod_probe missing")?;
    let n = 1usize << 20;
    let a: Vec<u64> = (0..n as u64).map(|i| i.wrapping_mul(0x9E3779B97F4A7C15) % aux::P).collect();
    let b: Vec<u64> = (0..n as u64).map(|i| (i.wrapping_mul(0xC2B2AE3D27D4EB4F) ^ 0xFFFF) % aux::P).collect();
    let da = dev.htod_sync_copy(&a).map_err(|e| e.to_string())?;
    let db = dev.htod_sync_copy(&b).map_err(|e| e.to_string())?;
    let mut dout = dev.alloc_zeros::<u64>(n).map_err(|e| e.to_string())?;
    let cfg = LaunchConfig::for_num_elems(n as u32);
    dev.synchronize().map_err(|e| e.to_string())?;
    let t0 = Instant::now();
    for _ in 0..100 {
        unsafe { f.clone().launch(cfg, (&da, &db, &mut dout, n as i32)) }.map_err(|e| e.to_string())?;
    }
    dev.synchronize().map_err(|e| e.to_string())?;
    let dt = t0.elapsed().as_secs_f64();
    let out = dev.dtoh_sync_copy(&dout).map_err(|e| e.to_string())?;
    let mut bad = 0usize;
    for i in 0..n {
        if aux::mul_p(a[i], b[i]) != out[i] {
            bad += 1;
        }
    }
    Ok(ProbeReport { device: g.name.clone(), mismatches: bad, n, gmul_per_s: 100.0 * n as f64 / dt / 1e9 })
}

// ---------------------------------------------------------------------------
// [UPERF2-O] The instruction-throughput probe (analysis only): G MAC-class
// operations per second per mode (see kernels.cu k_imad_probe): 0 IMAD32,
// 1 mad.wide.u32, 2 lane K's 64x64->128 + ACC128 pair, 3 the 3-limb 9 x
// mad.wide MAC. `iters` steps per thread over `blocks` x 256 threads.

pub fn imad_probe(mode: i32, iters: i32, blocks: u32) -> Result<f64, String> {
    let g = gpu().ok_or_else(|| INIT_ERR.lock().unwrap().clone().unwrap_or_else(|| "no device".to_string()))?;
    let g = g.lock().unwrap();
    let dev = &g.dev;
    let f = dev.get_func(MODULE, "k_imad_probe").ok_or("k_imad_probe missing")?;
    let n = blocks as usize * 256;
    let mut dout = dev.alloc_zeros::<u64>(n).map_err(|e| e.to_string())?;
    let cfg = LaunchConfig { grid_dim: (blocks, 1, 1), block_dim: (256, 1, 1), shared_mem_bytes: 0 };
    // warm (clock ramp + JIT)
    unsafe { f.clone().launch(cfg, (&mut dout, iters, mode)) }.map_err(|e| e.to_string())?;
    dev.synchronize().map_err(|e| e.to_string())?;
    let reps = 5;
    let t0 = Instant::now();
    for _ in 0..reps {
        unsafe { f.clone().launch(cfg, (&mut dout, iters, mode)) }.map_err(|e| e.to_string())?;
    }
    dev.synchronize().map_err(|e| e.to_string())?;
    let dt = t0.elapsed().as_secs_f64();
    // MAC-class operations per step: mode 0/1: 8, mode 2: 4 (64x64 products), mode 3: 4 (3-limb products)
    let per_step = match mode {
        0 | 1 => 8.0,
        _ => 4.0,
    };
    Ok(reps as f64 * n as f64 * iters as f64 * per_step / dt / 1e9)
}

// ---------------------------------------------------------------------------
// Battery helper: the transforms alone

/// Forward (`inverse == false`; standard-order input, bit-reversed output)
/// or inverse transform of raw Z_p rings on the device — the battery
/// compares against `ntt_fwd_best` / `ntt_inv_best`.
pub fn ntt_batch(rings: &[[u64; D]], inverse: bool) -> Result<Vec<[u64; D]>, String> {
    let g = gpu().ok_or_else(|| INIT_ERR.lock().unwrap().clone().unwrap_or_else(|| "no device".to_string()))?;
    let g = g.lock().unwrap();
    let n = rings.len();
    if n == 0 {
        return Ok(Vec::new());
    }
    let flat: Vec<u64> = rings.iter().flat_map(|r| r.iter().copied()).collect();
    let dev = g.dev.clone();
    let mut src = dev.htod_sync_copy(&flat).map_err(|e| e.to_string())?;
    let mut dst = dev.alloc_zeros::<u64>(n * D).map_err(|e| e.to_string())?;
    let blocks = n.div_ceil(r_fwd()) as u32;
    let cfg = LaunchConfig { grid_dim: (blocks, 1, 1), block_dim: (t_fwd(), 1, 1), shared_mem_bytes: 0 };
    let mut out = vec![[0u64; D]; n];
    if !inverse {
        let f = dev.get_func(MODULE, "k_ntt_fwd").ok_or("k_ntt_fwd missing")?;
        unsafe { f.launch(cfg, (&src, 4i32, 0u64, n as i32, &mut dst, g.psi.ptr)) }.map_err(|e| e.to_string())?;
        let flat_t = dev.dtoh_sync_copy(&dst).map_err(|e| e.to_string())?; // [t][slot]
        for slot in 0..n {
            for t in 0..D {
                out[slot][t] = flat_t[t * n + slot];
            }
        }
    } else {
        let f = dev.get_func(MODULE, "k_ntt_inv").ok_or("k_ntt_inv missing")?;
        let n_inv = g.n_inv;
        unsafe { f.launch(cfg, (&mut src, n as i32, g.ipsi.ptr, n_inv, 0i32, 0u64, &mut dst)) }.map_err(|e| e.to_string())?;
        let flat_o = dev.dtoh_sync_copy(&dst).map_err(|e| e.to_string())?;
        for slot in 0..n {
            out[slot].copy_from_slice(&flat_o[slot * D..(slot + 1) * D]);
        }
    }
    Ok(out)
}

// ---------------------------------------------------------------------------
// The ported kernel: ntt_gemm_modq_small

/// The hook's entry: `Some(out)` = computed on the device (bit-identical to
/// the CPU body), `None` = declined (see mod.rs). Honors the minimum-work
/// threshold.
pub fn ntt_gemm_modq_small<B: SmallRings + ?Sized>(ctx: &RingCtx, a: &[&[Poly]], b: &[&B], len: usize) -> Option<Vec<Poly>> {
    ntt_gemm_impl(ctx, a, b, len, false)
}

/// The battery's entry: ignores the minimum-work threshold (still declines
/// over-capacity shapes, which the CPU also routes to its oracle).
pub fn ntt_gemm_modq_small_force<B: SmallRings + ?Sized>(ctx: &RingCtx, a: &[&[Poly]], b: &[&B], len: usize) -> Option<Vec<Poly>> {
    ntt_gemm_impl(ctx, a, b, len, true)
}

fn ntt_gemm_impl<B: SmallRings + ?Sized>(ctx: &RingCtx, a: &[&[Poly]], b: &[&B], len: usize, force: bool) -> Option<Vec<Poly>> {
    let g = gpu()?;
    let (na, nb) = (a.len(), b.len());
    if na == 0 || nb == 0 || len == 0 {
        return None;
    }
    let macs = (D as u128) * (na as u128) * (nb as u128) * (len as u128);
    if !force && macs < min_macs() {
        S_DECLINED.fetch_add(1, Ordering::Relaxed);
        return None;
    }
    let t0 = Instant::now();
    let q = ctx.zq.q;
    // The operand bound (exact, from the data — the same value the CPU
    // body's `max_abs` scan yields; here per ring over (slice, ring-range)
    // tasks so the pool shares it evenly).
    let s_max: u128 = {
        const RING_TASK: usize = 512;
        let tasks_per_slice = len.div_ceil(RING_TASK);
        let scan = |task: usize| -> u64 {
            let (ib, t) = (task / tasks_per_slice, task % tasks_per_slice);
            let (u_lo, u_hi) = (t * RING_TASK, ((t + 1) * RING_TASK).min(len));
            let mut buf = [0i64; D];
            let mut m = 0u64;
            for u in u_lo..u_hi {
                let ring = b[ib].ring(u, &mut buf);
                let mr = ring.iter().map(|x| x.unsigned_abs()).max().unwrap_or(0);
                if mr > m {
                    m = mr;
                }
            }
            m
        };
        let n_tasks = nb * tasks_per_slice;
        let m = if threads() > 1 && n_tasks > 1 {
            POOL.install(|| {
                use rayon::prelude::*;
                (0..n_tasks).into_par_iter().map(scan).max().unwrap_or(0)
            })
        } else {
            (0..n_tasks).map(scan).max().unwrap_or(0)
        };
        m as u128
    };
    add_us(&S_SMAX_US, t0.elapsed().as_secs_f64());
    let window = ntt_window_terms(q, s_max);
    if window == 0 {
        return None; // over capacity: the CPU body runs its exact oracle
    }
    let mut st = g.lock().unwrap();
    match st.gemm(ctx, a, b, len, window, s_max) {
        Ok(out) => {
            S_CALLS.fetch_add(1, Ordering::Relaxed);
            S_MACS.fetch_add((macs >> 10) as u64, Ordering::Relaxed);
            add_us(&S_TOTAL_US, t0.elapsed().as_secs_f64());
            Some(out)
        }
        Err(e) => {
            if !WARNED.swap(true, Ordering::Relaxed) {
                eprintln!("[UPERF2-K] gpu ntt_gemm failed ({e}); this and later calls fall back to the CPU body");
            }
            // Release device scratch (an OOM leaves it best dropped) and
            // route every later call to the CPU. [UPERF2-L] a K-field chain
            // cannot be alive here (no GEMM runs inside a descent layer);
            // asserted rather than assumed.
            st.release_all();
            super::k9::assert_no_chain("gemm failure bypass");
            BYPASS.store(true, Ordering::Relaxed);
            None
        }
    }
}

impl Gpu {
    fn sync_all(&self) -> Result<(), String> {
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync sk: {e}"))?;
        unsafe { cu::stream::synchronize(self.sc.stream) }.map_err(|e| format!("sync sc: {e}"))?;
        Ok(())
    }

    fn release_all(&mut self) {
        let _ = self.sync_all();
        for b in self.src_a.iter_mut().chain(self.src_b.iter_mut()) {
            b.free();
        }
        self.a_t.free();
        self.b_t.free();
        self.acc.free();
        self.v.free();
        self.out.free();
        for h in self.st_a.iter_mut().chain(self.st_b.iter_mut()) {
            h.free();
        }
        self.st_out.free();
        for d in self.desc.iter_mut() {
            d.free(); // [UPERF2-Q]
        }
        for h in self.st_desc.iter_mut() {
            h.free();
        }
    }

    fn gemm<B: SmallRings + ?Sized>(
        &mut self,
        ctx: &RingCtx,
        a: &[&[Poly]],
        b: &[&B],
        len: usize,
        window: usize,
        s_max: u128,
    ) -> Result<Vec<Poly>, String> {
        let dev = self.dev.clone();
        dev.bind_to_thread().map_err(|e| format!("bind_to_thread: {e}"))?;
        let q = ctx.zq.q;
        let (na, nb) = (a.len(), b.len());
        let a_fmt: i32 = if q < (1u64 << 32) { 0 } else { 1 };
        let b_fmt: i32 = if s_max <= 127 { 2 } else { 3 };
        let a_elt = if a_fmt == 0 { 4 } else { 8 };
        let b_elt = if b_fmt == 2 { 1 } else { 8 };
        // u-block: positions per device round trip — within the budget, and
        // >= pipe_stages sub-blocks per call when the call is large enough.
        let budget = block_budget_bytes();
        let per_pos = (na + nb) * D * 8 + 2 * (na * D * a_elt + nb * D * b_elt);
        let mut ublk = (budget / per_pos.max(1)).clamp(1, len.min(window));
        let staged = len.div_ceil(pipe_stages()).max(MIN_UBLK);
        if ublk > staged {
            ublk = staged;
        }
        // Split-K count: enough blocks to fill the device (target 512), the
        // accumulator capped at 256 MB.
        // The 16-row GEMM tile for skinny shapes (na <= 16), the 64-row tile otherwise.
        let tm = if na <= 16 { 16 } else { TM_G };
        let tiles_m = na.div_ceil(tm);
        let tiles_n = nb.div_ceil(TN_G);
        let base_blocks = D * tiles_m * tiles_n;
        let acc_cell_bytes = D * na * nb * 32;
        let ks_cap = ((256usize << 20) / acc_cell_bytes.max(1)).max(1);
        let ks = (512usize.div_ceil(base_blocks)).clamp(1, ublk.div_ceil(KB_G)).min(ks_cap);
        // Buffer sizes (bytes).
        let sz_src_a = na * ublk * D * a_elt;
        let sz_src_b = nb * ublk * D * b_elt;
        let sz_t_a = na * ublk * D * 8;
        let sz_t_b = nb * ublk * D * 8;
        let sz_acc = ks * D * na * nb * 32;
        let sz_v = na * nb * D * 8;
        let sz_out = na * nb * D * 8;
        let grow = self.src_a.iter().any(|d| d.needs(sz_src_a))
            || self.src_b.iter().any(|d| d.needs(sz_src_b))
            || self.a_t.needs(sz_t_a)
            || self.b_t.needs(sz_t_b)
            || self.acc.needs(sz_acc)
            || self.v.needs(sz_v)
            || self.out.needs(sz_out)
            || self.st_a.iter().any(|h| h.needs(sz_src_a))
            || self.st_b.iter().any(|h| h.needs(sz_src_b))
            || self.st_out.needs(sz_out);
        if grow {
            self.sync_all()?;
            for d in self.src_a.iter_mut() {
                d.grow(sz_src_a)?;
            }
            for d in self.src_b.iter_mut() {
                d.grow(sz_src_b)?;
            }
            self.a_t.grow(sz_t_a)?;
            self.b_t.grow(sz_t_b)?;
            self.acc.grow(sz_acc)?;
            self.v.grow(sz_v)?;
            self.out.grow(sz_out)?;
            for h in self.st_a.iter_mut() {
                h.grow(sz_src_a)?;
            }
            for h in self.st_b.iter_mut() {
                h.grow(sz_src_b)?;
            }
            self.st_out.grow(sz_out)?;
        }
        let f_fwd = dev.get_func(MODULE, "k_ntt_fwd").ok_or("k_ntt_fwd missing")?;
        let f_gemm = if tm == 16 {
            dev.get_func(MODULE, "k_gemm_split_m16").ok_or("k_gemm_split_m16 missing")?
        } else {
            dev.get_func(MODULE, "k_gemm_split").ok_or("k_gemm_split missing")?
        };
        let f_flush = dev.get_func(MODULE, "k_flush_reduce").ok_or("k_flush_reduce missing")?;
        let f_inv = dev.get_func(MODULE, "k_ntt_inv").ok_or("k_ntt_inv missing")?;
        let sk = self.sk.stream;
        let sc = self.sc.stream;
        let prof = profile();
        let (mut secs_pack, mut secs_wait, mut secs_kh2d, mut secs_kfwd, mut secs_kgemm, mut secs_kflush) = (0.0f64, 0.0f64, 0.0f64, 0.0f64, 0.0f64, 0.0f64);
        let mut bytes_h2d = 0u64;
        let sync_sk = || unsafe { cu::stream::synchronize(sk) }.map_err(|e| format!("sync sk: {e}"));
        // Zero the output.
        unsafe { cu::memset_d8_async(self.out.ptr, 0, sz_out, sk) }.map_err(|e| format!("memset out: {e}"))?;
        let mut blk = 0usize; // ping-pong index across the whole call
        let mut u0 = 0usize;
        while u0 < len {
            let u1 = (u0 + window).min(len);
            unsafe { cu::memset_d8_async(self.acc.ptr, 0, sz_acc, sk) }.map_err(|e| format!("memset acc: {e}"))?;
            let mut ub0 = u0;
            while ub0 < u1 {
                let n = ublk.min(u1 - ub0);
                let pp = blk % 2;
                let n_as = n * na * D;
                let n_bs = n * nb * D;
                // ---- staging[pp] must be free: the h2d that last read it is done.
                let tw = Instant::now();
                unsafe { cu::event::synchronize(self.ev_h2d[pp]) }.map_err(|e| format!("event sync h2d: {e}"))?;
                secs_wait += tw.elapsed().as_secs_f64();
                // ---- pack (host, pooled): slot = ub * na + ia / ub * nb + ib.
                let tp = Instant::now();
                {
                    let per_a = na * D;
                    let per_b = nb * D;
                    let (st_a, st_b) = (&mut self.st_a[pp], &mut self.st_b[pp]);
                    let do_a32 = |ub: usize, chunk: &mut [u32]| {
                        for ia in 0..na {
                            let ring = &a[ia][ub0 + ub];
                            let dst = &mut chunk[ia * D..(ia + 1) * D];
                            for c in 0..D {
                                dst[c] = ring[c] as u32;
                            }
                        }
                    };
                    let do_a64 = |ub: usize, chunk: &mut [u64]| {
                        for ia in 0..na {
                            chunk[ia * D..(ia + 1) * D].copy_from_slice(&a[ia][ub0 + ub]);
                        }
                    };
                    let do_b8 = |ub: usize, chunk: &mut [i8]| {
                        let mut buf = [0i64; D];
                        for ib in 0..nb {
                            let ring = b[ib].ring(ub0 + ub, &mut buf);
                            let dst = &mut chunk[ib * D..(ib + 1) * D];
                            for c in 0..D {
                                dst[c] = ring[c] as i8;
                            }
                        }
                    };
                    let do_b64 = |ub: usize, chunk: &mut [i64]| {
                        let mut buf = [0i64; D];
                        for ib in 0..nb {
                            let ring = b[ib].ring(ub0 + ub, &mut buf);
                            chunk[ib * D..(ib + 1) * D].copy_from_slice(ring);
                        }
                    };
                    if threads() > 1 {
                        POOL.install(|| {
                            use rayon::prelude::*;
                            if a_fmt == 0 {
                                st_a.slice_mut::<u32>(n_as).par_chunks_mut(per_a).enumerate().for_each(|(ub, c)| do_a32(ub, c));
                            } else {
                                st_a.slice_mut::<u64>(n_as).par_chunks_mut(per_a).enumerate().for_each(|(ub, c)| do_a64(ub, c));
                            }
                            if b_fmt == 2 {
                                st_b.slice_mut::<i8>(n_bs).par_chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b8(ub, c));
                            } else {
                                st_b.slice_mut::<i64>(n_bs).par_chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b64(ub, c));
                            }
                        });
                    } else {
                        if a_fmt == 0 {
                            st_a.slice_mut::<u32>(n_as).chunks_mut(per_a).enumerate().for_each(|(ub, c)| do_a32(ub, c));
                        } else {
                            st_a.slice_mut::<u64>(n_as).chunks_mut(per_a).enumerate().for_each(|(ub, c)| do_a64(ub, c));
                        }
                        if b_fmt == 2 {
                            st_b.slice_mut::<i8>(n_bs).chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b8(ub, c));
                        } else {
                            st_b.slice_mut::<i64>(n_bs).chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b64(ub, c));
                        }
                    }
                }
                secs_pack += tp.elapsed().as_secs_f64();
                // ---- upload on the copy stream (after the transforms that
                // last read src[pp]); record "h2d done".
                unsafe { cu::stream::wait_event(sc, self.ev_fwd[pp], sys::CUevent_wait_flags::CU_EVENT_WAIT_DEFAULT) }
                    .map_err(|e| format!("wait fwd: {e}"))?;
                unsafe { cu::memcpy_htod_async(self.src_a[pp].ptr, self.st_a[pp].slice::<u8>(n_as * a_elt), sc) }
                    .map_err(|e| format!("h2d a: {e}"))?;
                unsafe { cu::memcpy_htod_async(self.src_b[pp].ptr, self.st_b[pp].slice::<u8>(n_bs * b_elt), sc) }
                    .map_err(|e| format!("h2d b: {e}"))?;
                unsafe { cu::event::record(self.ev_h2d[pp], sc) }.map_err(|e| format!("record h2d: {e}"))?;
                bytes_h2d += (n_as * a_elt + n_bs * b_elt) as u64;
                // ---- transforms on the compute stream (after the upload).
                unsafe { cu::stream::wait_event(sk, self.ev_h2d[pp], sys::CUevent_wait_flags::CU_EVENT_WAIT_DEFAULT) }
                    .map_err(|e| format!("wait h2d: {e}"))?;
                if prof {
                    // Attribute the upload separately (the transforms wait for it).
                    let th = Instant::now();
                    unsafe { cu::event::synchronize(self.ev_h2d[pp]) }.map_err(|e| format!("event sync h2d (prof): {e}"))?;
                    secs_kh2d += th.elapsed().as_secs_f64();
                }
                let tk = Instant::now();
                let n_slots_a = n * na;
                let n_slots_b = n * nb;
                let cfg_a = LaunchConfig { grid_dim: (n_slots_a.div_ceil(r_fwd()) as u32, 1, 1), block_dim: (t_fwd(), 1, 1), shared_mem_bytes: 0 };
                let cfg_b = LaunchConfig { grid_dim: (n_slots_b.div_ceil(r_fwd()) as u32, 1, 1), block_dim: (t_fwd(), 1, 1), shared_mem_bytes: 0 };
                unsafe { f_fwd.clone().launch_on_stream(&self.sk, cfg_a, (self.src_a[pp].ptr, a_fmt, q, n_slots_a as i32, self.a_t.ptr, self.psi.ptr)) }
                    .map_err(|e| format!("fwd a: {e}"))?;
                unsafe { f_fwd.clone().launch_on_stream(&self.sk, cfg_b, (self.src_b[pp].ptr, b_fmt, q, n_slots_b as i32, self.b_t.ptr, self.psi.ptr)) }
                    .map_err(|e| format!("fwd b: {e}"))?;
                unsafe { cu::event::record(self.ev_fwd[pp], sk) }.map_err(|e| format!("record fwd: {e}"))?;
                if prof {
                    sync_sk()?;
                    secs_kfwd += tk.elapsed().as_secs_f64();
                }
                // ---- the GEMM (split-K over this u-block).
                let tk = Instant::now();
                let ks_n = ks.min(n.div_ceil(KB_G)).max(1);
                let k_per_split = n.div_ceil(ks_n);
                let cfg_g = LaunchConfig {
                    grid_dim: (tiles_n as u32, tiles_m as u32, (D * ks_n) as u32),
                    block_dim: (16, 16, 1),
                    shared_mem_bytes: 0,
                };
                unsafe {
                    f_gemm.clone().launch_on_stream(
                        &self.sk,
                        cfg_g,
                        (self.a_t.ptr, self.b_t.ptr, self.acc.ptr, na as i32, nb as i32, n as i32, ks_n as i32, k_per_split as i32),
                    )
                }
                .map_err(|e| format!("gemm: {e}"))?;
                if prof {
                    sync_sk()?;
                    secs_kgemm += tk.elapsed().as_secs_f64();
                }
                ub0 += n;
                blk += 1;
            }
            // ---- window flush: reduce -> inverse NTT -> center/mod q/add.
            let tk = Instant::now();
            let cells = na * nb;
            let cfg_f = LaunchConfig { grid_dim: (cells as u32, 1, 1), block_dim: (D as u32, 1, 1), shared_mem_bytes: 0 };
            unsafe { f_flush.clone().launch_on_stream(&self.sk, cfg_f, (self.acc.ptr, ks as i32, na as i32, nb as i32, self.v.ptr)) }
                .map_err(|e| format!("flush: {e}"))?;
            let cfg_i = LaunchConfig { grid_dim: (cells.div_ceil(r_fwd()) as u32, 1, 1), block_dim: (t_fwd(), 1, 1), shared_mem_bytes: 0 };
            let n_inv = self.n_inv;
            unsafe { f_inv.clone().launch_on_stream(&self.sk, cfg_i, (self.v.ptr, cells as i32, self.ipsi.ptr, n_inv, 1i32, q, self.out.ptr)) }
                .map_err(|e| format!("inv: {e}"))?;
            if prof {
                sync_sk()?;
                secs_kflush += tk.elapsed().as_secs_f64();
            }
            u0 = u1;
        }
        // ---- drain + results.
        let tw = Instant::now();
        sync_sk()?;
        secs_wait += tw.elapsed().as_secs_f64();
        let td = Instant::now();
        let flat: &mut [u64] = self.st_out.slice_mut::<u64>(na * nb * D);
        unsafe { cu::memcpy_dtoh_sync(flat, self.out.ptr) }.map_err(|e| format!("d2h out: {e}"))?;
        let out: Vec<Poly> = (0..na * nb).map(|c| flat[c * D..(c + 1) * D].to_vec()).collect();
        let secs_d2h = td.elapsed().as_secs_f64();
        S_BYTES.fetch_add(bytes_h2d, Ordering::Relaxed);
        add_us(&S_PACK_US, secs_pack);
        add_us(&S_WAIT_US, secs_wait);
        add_us(&S_KH2D_US, secs_kh2d);
        add_us(&S_KFWD_US, secs_kfwd);
        add_us(&S_KGEMM_US, secs_kgemm);
        add_us(&S_KFLUSH_US, secs_kflush);
        add_us(&S_D2H_US, secs_d2h);
        if verbose() {
            eprintln!(
                "[UPERF2-K] gemm na {na} nb {nb} len {len} (window {window}, ublk {ublk}, ks {ks}, a_fmt {a_fmt}, b_fmt {b_fmt}): pack {:.1} ms, wait {:.1} ms, h2d {:.0} MB, d2h {:.1} ms{}",
                secs_pack * 1e3,
                secs_wait * 1e3,
                bytes_h2d as f64 / 1e6,
                secs_d2h * 1e3,
                if prof {
                    format!(" | h2d {:.1} ms; kernels: fwd {:.1} ms, gemm {:.1} ms, flush {:.1} ms", secs_kh2d * 1e3, secs_kfwd * 1e3, secs_kgemm * 1e3, secs_kflush * 1e3)
                } else {
                    String::new()
                }
            );
        }
        Ok(out)
    }
}

// ---------------------------------------------------------------------------
// [UPERF2-Q] THE LEVEL-H DEVICE SESSION.
//
// `level_h_pairs_with_block` (eval_proof.rs) computes the r x r table
// g[j][k] = <phi_j, w_k> of one level with the level-0 functional supplied
// per u-block by a `Phi0Source`; per block it called K's GEMM once (host
// fill of r x block u64 rings -> s_max scan -> u32 pack -> upload ->
// transforms -> GEMM -> flush -> d2h -> host mod-q add). The session keeps
// the whole level on the device instead:
//   * the a-operand of a stage is a POOL of the value rings the stage's
//     windows touch (`Phi0Source::fill_pool_u32`, u32 mod-q, one per VALUE
//     ring — l0 digit rings share it) plus a per-ring (pool index, radix)
//     descriptor; `k_ntt_fwd_pool` applies the limb radix (`(pool * radix)
//     % q`, the same canonical residue `poly_scale` yields) and lifts —
//     the host never scales, and the upload is ~l0 x smaller;
//   * the w slices are packed i8 straight from the flat store
//     (`SmallRings::as_i8`), i64 for the boxed store when |w| > 127;
//   * the split-halves accumulator (K's `acc`) stays resident across the
//     stages; the flush (reduce -> inverse -> center -> mod q -> add into
//     `out`) runs once per exact-integer window (at the rig's level 0 the
//     whole level is one window), the table comes back once;
//   * s_max: for the flat i8 store the bound 127 (no scan) when the whole
//     level fits its window; the level's exact scan otherwise;
//   * ping-pong staging + events as K's pipeline, so the host fill/pack of
//     stage i+1 overlaps the device work of stage i.
// Bit-identity: every accumulated quantity is the same exact 128-bit
// split-halves integer of the same products (pool ring x radix mod q is
// the ring `fill` writes; the lifts and transforms are K's), the flush is
// K's flush on the same u128, and mod-q addition of exact partial sums is
// partition-independent — the CPU body relies on the same fact across its
// u-blocks and windows. `uperf-q battery` compares session vs the CPU body
// (bypassed) cell by cell; the oracle is the unchanged loop.

use super::super::ct_engine::prof;
use super::super::eval_proof::Phi0Source;

/// `ZK_GPU_LH_BLOCK`: positions per session stage (0 = the caller's block);
/// the harness override (`set_lh_block`) wins.
static LH_BLOCK: AtomicU64 = AtomicU64::new(0);

/// Harness knob: positions per session stage (0 = `ZK_GPU_LH_BLOCK` / the
/// caller's block) — the battery drives ragged stages and window crossings.
pub fn set_lh_block(n: usize) {
    LH_BLOCK.store(n as u64, Ordering::Relaxed);
}

fn lh_block(default: usize) -> usize {
    let o = LH_BLOCK.load(Ordering::Relaxed) as usize;
    if o > 0 {
        return o;
    }
    static V: OnceLock<usize> = OnceLock::new();
    let v = *V.get_or_init(|| env_usize("ZK_GPU_LH_BLOCK", 0));
    if v > 0 { v } else { default }
}

/// `ZK_GPU_LH=0` turns the session off (the hook declines; K's per-block
/// GEMM path runs — the one-binary A/B of the session); the harness knob
/// `set_lh_session` overrides at runtime.
static LH_OFF: AtomicBool = AtomicBool::new(false);
static LH_OFF_SET: AtomicBool = AtomicBool::new(false);

pub fn set_lh_session(on: bool) {
    LH_OFF.store(!on, Ordering::Relaxed);
    LH_OFF_SET.store(true, Ordering::Relaxed);
}

fn lh_session_on() -> bool {
    if LH_OFF_SET.load(Ordering::Relaxed) {
        return !LH_OFF.load(Ordering::Relaxed);
    }
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| std::env::var("ZK_GPU_LH").map(|v| v != "0").unwrap_or(true))
}

/// [UPERF2-Q] Session stats (observation only).
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
    /// Buffer growth (allocations; the first session / a bigger shape).
    pub secs_grow: f64,
    /// Host time enqueueing the uploads + launches (should be ~0).
    pub secs_enq: f64,
}

static LH_SESSIONS: AtomicU64 = AtomicU64::new(0);
static LH_DECLINED: AtomicU64 = AtomicU64::new(0);
static LH_STAGES: AtomicU64 = AtomicU64::new(0);
static LH_FLUSHES: AtomicU64 = AtomicU64::new(0);
static LH_BYTES: AtomicU64 = AtomicU64::new(0);
static LH_SMAX_US: AtomicU64 = AtomicU64::new(0);
static LH_FILL_US: AtomicU64 = AtomicU64::new(0);
static LH_WAIT_US: AtomicU64 = AtomicU64::new(0);
static LH_TOTAL_US: AtomicU64 = AtomicU64::new(0);
static LH_GROW_US: AtomicU64 = AtomicU64::new(0);
static LH_ENQ_US: AtomicU64 = AtomicU64::new(0);

pub fn lh_stats() -> LhStats {
    let us = |s: &AtomicU64| s.load(Ordering::Relaxed) as f64 * 1e-6;
    LhStats {
        sessions: LH_SESSIONS.load(Ordering::Relaxed),
        declined: LH_DECLINED.load(Ordering::Relaxed),
        stages: LH_STAGES.load(Ordering::Relaxed),
        flushes: LH_FLUSHES.load(Ordering::Relaxed),
        bytes_h2d: LH_BYTES.load(Ordering::Relaxed),
        secs_smax: us(&LH_SMAX_US),
        secs_fill: us(&LH_FILL_US),
        secs_wait: us(&LH_WAIT_US),
        secs_total: us(&LH_TOTAL_US),
        secs_grow: us(&LH_GROW_US),
        secs_enq: us(&LH_ENQ_US),
    }
}

pub fn lh_stats_reset() {
    for s in [&LH_SESSIONS, &LH_DECLINED, &LH_STAGES, &LH_FLUSHES, &LH_BYTES, &LH_SMAX_US, &LH_FILL_US, &LH_WAIT_US, &LH_TOTAL_US, &LH_GROW_US, &LH_ENQ_US] {
        s.store(0, Ordering::Relaxed);
    }
}

/// The hook's entry (honors the minimum-work threshold): `Some(g)` = the
/// r x r table g[j*r + k] = <phi_j, w_k> computed on the device; `None` =
/// declined (the CPU body runs).
pub fn level_h_stream<B: SmallRings + ?Sized>(ctx: &RingCtx, src: &Phi0Source, w: &[&B], chunk: usize, block: usize) -> Option<Vec<Poly>> {
    level_h_impl(ctx, src, w, chunk, block, false)
}

/// The battery's entry (ignores the minimum-work threshold).
pub fn level_h_stream_force<B: SmallRings + ?Sized>(ctx: &RingCtx, src: &Phi0Source, w: &[&B], chunk: usize, block: usize) -> Option<Vec<Poly>> {
    level_h_impl(ctx, src, w, chunk, block, true)
}

fn level_h_impl<B: SmallRings + ?Sized>(ctx: &RingCtx, src: &Phi0Source, w: &[&B], chunk: usize, block: usize, force: bool) -> Option<Vec<Poly>> {
    let g = gpu()?;
    let r = w.len();
    if r == 0 || chunk == 0 || block == 0 {
        return None;
    }
    let q = ctx.zq.q;
    if q >= (1u64 << 32) {
        LH_DECLINED.fetch_add(1, Ordering::Relaxed);
        return None; // the u32 pool needs q < 2^32; the CPU body runs
    }
    let macs = (D as u128) * (r as u128) * (r as u128) * (chunk as u128);
    if !force && (macs < min_macs() || !lh_session_on()) {
        LH_DECLINED.fetch_add(1, Ordering::Relaxed);
        return None;
    }
    let _tq = prof::timer(prof::Q_LH_STREAM);
    let t0 = Instant::now();
    // The operand bound: the flat i8 store is |w| <= 127 by construction —
    // when the whole level fits that window no scan is needed (any bound
    // >= the true max gives a window at least as strict; the flush
    // partition does not move a value). Otherwise the level's exact max
    // (each slice's `max_abs`, parallel inside).
    let s_max: u128 = {
        let _ts = prof::timer(prof::Q_LH_SMAX);
        let all_i8 = w.iter().all(|s| s.as_i8().is_some());
        if all_i8 && ntt_window_terms(q, 127) >= chunk {
            127
        } else {
            w.iter().map(|s| s.max_abs()).max().unwrap_or(0)
        }
    };
    add_us(&LH_SMAX_US, t0.elapsed().as_secs_f64());
    let window = ntt_window_terms(q, s_max);
    if window == 0 {
        LH_DECLINED.fetch_add(1, Ordering::Relaxed);
        return None; // over capacity: the CPU body runs its exact oracle
    }
    let mut st = g.lock().unwrap();
    match st.level_h(ctx, src, w, chunk, block, window, s_max) {
        Ok(out) => {
            LH_SESSIONS.fetch_add(1, Ordering::Relaxed);
            add_us(&LH_TOTAL_US, t0.elapsed().as_secs_f64());
            Some(out)
        }
        Err(e) => {
            if !WARNED.swap(true, Ordering::Relaxed) {
                eprintln!("[UPERF2-Q] gpu level-h session failed ({e}); this and later calls fall back to the CPU body");
            }
            st.release_all();
            super::k9::assert_no_chain("level-h session failure bypass");
            BYPASS.store(true, Ordering::Relaxed);
            None
        }
    }
}

impl Gpu {
    /// The session body (see the section note). `window` = the exact-integer
    /// window for `s_max` (>= 1); the accumulator is flushed every `window`
    /// positions and at the end.
    #[allow(clippy::too_many_arguments)]
    fn level_h<B: SmallRings + ?Sized>(
        &mut self,
        ctx: &RingCtx,
        src: &Phi0Source,
        w: &[&B],
        chunk: usize,
        block: usize,
        window: usize,
        s_max: u128,
    ) -> Result<Vec<Poly>, String> {
        let dev = self.dev.clone();
        dev.bind_to_thread().map_err(|e| format!("bind_to_thread: {e}"))?;
        let zq = &ctx.zq;
        let q = zq.q;
        let r = w.len();
        let (na, nb) = (r, r);
        let b_fmt: i32 = if s_max <= 127 { 2 } else { 3 };
        let b_elt = if b_fmt == 2 { 1 } else { 8 };
        let n_blk = lh_block(block).clamp(1, chunk.min(window));
        let tm = if na <= 16 { 16 } else { TM_G };
        let tiles_m = na.div_ceil(tm);
        let tiles_n = nb.div_ceil(TN_G);
        let base_blocks = D * tiles_m * tiles_n;
        let acc_cell_bytes = D * na * nb * 32;
        let ks_cap = ((256usize << 20) / acc_cell_bytes.max(1)).max(1);
        let ks = (512usize.div_ceil(base_blocks)).clamp(1, n_blk.div_ceil(KB_G)).min(ks_cap);
        // Buffer sizes (bytes): the pool holds at most one ring per digit
        // ring of the stage plus the zero slot; the descriptors 8 B per ring.
        let sz_pool = (1 + na * n_blk) * D * 4;
        let sz_desc = na * n_blk * 8;
        let sz_src_b = nb * n_blk * D * b_elt;
        let sz_t_a = na * n_blk * D * 8;
        let sz_t_b = nb * n_blk * D * 8;
        let sz_acc = ks * D * na * nb * 32;
        let sz_v = na * nb * D * 8;
        let sz_out = na * nb * D * 8;
        let grow = self.src_a.iter().any(|d| d.needs(sz_pool))
            || self.desc.iter().any(|d| d.needs(sz_desc))
            || self.src_b.iter().any(|d| d.needs(sz_src_b))
            || self.a_t.needs(sz_t_a)
            || self.b_t.needs(sz_t_b)
            || self.acc.needs(sz_acc)
            || self.v.needs(sz_v)
            || self.out.needs(sz_out)
            || self.st_a.iter().any(|h| h.needs(sz_pool))
            || self.st_desc.iter().any(|h| h.needs(sz_desc))
            || self.st_b.iter().any(|h| h.needs(sz_src_b))
            || self.st_out.needs(sz_out);
        let tg = Instant::now();
        if grow {
            self.sync_all()?;
            for d in self.src_a.iter_mut() {
                d.grow(sz_pool)?;
            }
            for d in self.desc.iter_mut() {
                d.grow(sz_desc)?;
            }
            for d in self.src_b.iter_mut() {
                d.grow(sz_src_b)?;
            }
            self.a_t.grow(sz_t_a)?;
            self.b_t.grow(sz_t_b)?;
            self.acc.grow(sz_acc)?;
            self.v.grow(sz_v)?;
            self.out.grow(sz_out)?;
            for h in self.st_a.iter_mut() {
                h.grow(sz_pool)?;
            }
            for h in self.st_desc.iter_mut() {
                h.grow(sz_desc)?;
            }
            for h in self.st_b.iter_mut() {
                h.grow(sz_src_b)?;
            }
            self.st_out.grow(sz_out)?;
        }
        let secs_grow = tg.elapsed().as_secs_f64();
        let mut secs_enq = 0.0f64;
        let f_pool = dev.get_func(MODULE, "k_ntt_fwd_pool").ok_or("k_ntt_fwd_pool missing")?;
        let f_fwd = dev.get_func(MODULE, "k_ntt_fwd").ok_or("k_ntt_fwd missing")?;
        let f_gemm = if tm == 16 {
            dev.get_func(MODULE, "k_gemm_split_m16").ok_or("k_gemm_split_m16 missing")?
        } else {
            dev.get_func(MODULE, "k_gemm_split").ok_or("k_gemm_split missing")?
        };
        let f_flush = dev.get_func(MODULE, "k_flush_reduce").ok_or("k_flush_reduce missing")?;
        let f_inv = dev.get_func(MODULE, "k_ntt_inv").ok_or("k_ntt_inv missing")?;
        let sk = self.sk.stream;
        let sc = self.sc.stream;
        let sync_sk = || unsafe { cu::stream::synchronize(sk) }.map_err(|e| format!("sync sk: {e}"));
        let (mut secs_fill, mut secs_wait) = (0.0f64, 0.0f64);
        let mut bytes_h2d = 0u64;
        let mut stages = 0u64;
        let mut flushes = 0u64;
        unsafe { cu::memset_d8_async(self.out.ptr, 0, sz_out, sk) }.map_err(|e| format!("memset out: {e}"))?;
        unsafe { cu::memset_d8_async(self.acc.ptr, 0, sz_acc, sk) }.map_err(|e| format!("memset acc: {e}"))?;
        let mut blk = 0usize;
        let mut u0 = 0usize;
        let mut in_win = 0usize;
        while u0 < chunk {
            let n = n_blk.min(chunk - u0).min(window - in_win);
            let pp = blk % 2;
            // ---- staging[pp] must be free (its last h2d done).
            let tw = Instant::now();
            unsafe { cu::event::synchronize(self.ev_h2d[pp]) }.map_err(|e| format!("event sync h2d: {e}"))?;
            secs_wait += tw.elapsed().as_secs_f64();
            // ---- host: the value-ring pool + descriptors (per slice, on the
            // pool) and the w pack.
            let tf = Instant::now();
            let _tq = prof::timer(prof::Q_LH_FILL);
            let counts: Vec<usize> = (0..na).map(|j| src.pool_count(j * chunk + u0, n)).collect();
            let mut bases: Vec<usize> = Vec::with_capacity(na);
            let mut tot = 1usize; // slot 0 = the zero ring
            for c in &counts {
                bases.push(tot);
                tot += c;
            }
            let pool_bytes = tot * D * 4;
            let desc_bytes = na * n * 8;
            let n_bs = n * nb * D;
            {
                let pool_all: &mut [u32] = self.st_a[pp].slice_mut::<u32>(tot * D);
                let (zero_seg, mut rest) = pool_all.split_at_mut(D);
                zero_seg.fill(0);
                let mut segs: Vec<&mut [u32]> = Vec::with_capacity(na);
                for c in &counts {
                    let (s, r2) = rest.split_at_mut(c * D);
                    segs.push(s);
                    rest = r2;
                }
                let desc_all: &mut [[u32; 2]] = self.st_desc[pp].slice_mut::<[u32; 2]>(na * n);
                let bases_r = &bases;
                let counts_r = &counts;
                let fill_j = |j: usize, seg: &mut [u32], dj: &mut [[u32; 2]]| {
                    let k = src.fill_pool_u32(zq, j * chunk + u0, n, bases_r[j] as u32, 0, seg, dj);
                    debug_assert_eq!(k, counts_r[j], "pool count mismatch");
                    let _ = k;
                };
                let per_b = nb * D;
                let st_b = &mut self.st_b[pp];
                let do_b8 = |ub: usize, c8: &mut [i8]| {
                    let mut buf = [0i64; D];
                    for ib in 0..nb {
                        let dst = &mut c8[ib * D..(ib + 1) * D];
                        if let Some(raw) = w[ib].as_i8() {
                            dst.copy_from_slice(&raw[(u0 + ub) * D..(u0 + ub + 1) * D]);
                        } else {
                            let ring = w[ib].ring(u0 + ub, &mut buf);
                            for c in 0..D {
                                dst[c] = ring[c] as i8;
                            }
                        }
                    }
                };
                let do_b64 = |ub: usize, c64: &mut [i64]| {
                    let mut buf = [0i64; D];
                    for ib in 0..nb {
                        let ring = w[ib].ring(u0 + ub, &mut buf);
                        c64[ib * D..(ib + 1) * D].copy_from_slice(ring);
                    }
                };
                if threads() > 1 {
                    POOL.install(|| {
                        use rayon::prelude::*;
                        segs.into_par_iter().zip(desc_all.par_chunks_mut(n)).enumerate().for_each(|(j, (seg, dj))| fill_j(j, seg, dj));
                        if b_fmt == 2 {
                            st_b.slice_mut::<i8>(n_bs).par_chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b8(ub, c));
                        } else {
                            st_b.slice_mut::<i64>(n_bs).par_chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b64(ub, c));
                        }
                    });
                } else {
                    for (j, (seg, dj)) in segs.into_iter().zip(desc_all.chunks_mut(n)).enumerate() {
                        fill_j(j, seg, dj);
                    }
                    if b_fmt == 2 {
                        st_b.slice_mut::<i8>(n_bs).chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b8(ub, c));
                    } else {
                        st_b.slice_mut::<i64>(n_bs).chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b64(ub, c));
                    }
                }
            }
            drop(_tq);
            secs_fill += tf.elapsed().as_secs_f64();
            let te = Instant::now();
            // ---- upload on the copy stream (after the transforms that last
            // read src[pp]); record "h2d done".
            unsafe { cu::stream::wait_event(sc, self.ev_fwd[pp], sys::CUevent_wait_flags::CU_EVENT_WAIT_DEFAULT) }
                .map_err(|e| format!("wait fwd: {e}"))?;
            unsafe { cu::memcpy_htod_async(self.src_a[pp].ptr, self.st_a[pp].slice::<u8>(pool_bytes), sc) }.map_err(|e| format!("h2d pool: {e}"))?;
            unsafe { cu::memcpy_htod_async(self.desc[pp].ptr, self.st_desc[pp].slice::<u8>(desc_bytes), sc) }.map_err(|e| format!("h2d desc: {e}"))?;
            unsafe { cu::memcpy_htod_async(self.src_b[pp].ptr, self.st_b[pp].slice::<u8>(n_bs * b_elt), sc) }.map_err(|e| format!("h2d b: {e}"))?;
            unsafe { cu::event::record(self.ev_h2d[pp], sc) }.map_err(|e| format!("record h2d: {e}"))?;
            bytes_h2d += (pool_bytes + desc_bytes + n_bs * b_elt) as u64;
            // ---- transforms on the compute stream (after the upload).
            unsafe { cu::stream::wait_event(sk, self.ev_h2d[pp], sys::CUevent_wait_flags::CU_EVENT_WAIT_DEFAULT) }
                .map_err(|e| format!("wait h2d: {e}"))?;
            let n_slots_a = n * na;
            let n_slots_b = n * nb;
            let cfg_a = LaunchConfig { grid_dim: (n_slots_a.div_ceil(r_fwd()) as u32, 1, 1), block_dim: (t_fwd(), 1, 1), shared_mem_bytes: 0 };
            let cfg_b = LaunchConfig { grid_dim: (n_slots_b.div_ceil(r_fwd()) as u32, 1, 1), block_dim: (t_fwd(), 1, 1), shared_mem_bytes: 0 };
            unsafe { f_pool.clone().launch_on_stream(&self.sk, cfg_a, (self.src_a[pp].ptr, self.desc[pp].ptr, n as i32, na as i32, q, self.a_t.ptr, self.psi.ptr)) }
                .map_err(|e| format!("fwd pool: {e}"))?;
            unsafe { f_fwd.clone().launch_on_stream(&self.sk, cfg_b, (self.src_b[pp].ptr, b_fmt, q, n_slots_b as i32, self.b_t.ptr, self.psi.ptr)) }
                .map_err(|e| format!("fwd b: {e}"))?;
            unsafe { cu::event::record(self.ev_fwd[pp], sk) }.map_err(|e| format!("record fwd: {e}"))?;
            // ---- the GEMM (split-K over this stage) into the resident accumulator.
            let ks_n = ks.min(n.div_ceil(KB_G)).max(1);
            let k_per_split = n.div_ceil(ks_n);
            let cfg_g = LaunchConfig { grid_dim: (tiles_n as u32, tiles_m as u32, (D * ks_n) as u32), block_dim: (16, 16, 1), shared_mem_bytes: 0 };
            unsafe {
                f_gemm.clone().launch_on_stream(
                    &self.sk,
                    cfg_g,
                    (self.a_t.ptr, self.b_t.ptr, self.acc.ptr, na as i32, nb as i32, n as i32, ks_n as i32, k_per_split as i32),
                )
            }
            .map_err(|e| format!("gemm: {e}"))?;
            secs_enq += te.elapsed().as_secs_f64();
            in_win += n;
            u0 += n;
            blk += 1;
            stages += 1;
            // ---- window end (or the level's end): flush into `out`.
            if in_win == window || u0 == chunk {
                let cells = na * nb;
                let cfg_f = LaunchConfig { grid_dim: (cells as u32, 1, 1), block_dim: (D as u32, 1, 1), shared_mem_bytes: 0 };
                unsafe { f_flush.clone().launch_on_stream(&self.sk, cfg_f, (self.acc.ptr, ks as i32, na as i32, nb as i32, self.v.ptr)) }
                    .map_err(|e| format!("flush: {e}"))?;
                let cfg_i = LaunchConfig { grid_dim: (cells.div_ceil(r_fwd()) as u32, 1, 1), block_dim: (t_fwd(), 1, 1), shared_mem_bytes: 0 };
                let n_inv = self.n_inv;
                unsafe { f_inv.clone().launch_on_stream(&self.sk, cfg_i, (self.v.ptr, cells as i32, self.ipsi.ptr, n_inv, 1i32, q, self.out.ptr)) }
                    .map_err(|e| format!("inv: {e}"))?;
                if u0 < chunk {
                    unsafe { cu::memset_d8_async(self.acc.ptr, 0, sz_acc, sk) }.map_err(|e| format!("memset acc: {e}"))?;
                }
                in_win = 0;
                flushes += 1;
            }
        }
        // ---- drain + the table.
        let tw = Instant::now();
        {
            let _tq = prof::timer(prof::Q_LH_WAIT);
            sync_sk()?;
        }
        secs_wait += tw.elapsed().as_secs_f64();
        let flat: &mut [u64] = self.st_out.slice_mut::<u64>(na * nb * D);
        unsafe { cu::memcpy_dtoh_sync(flat, self.out.ptr) }.map_err(|e| format!("d2h out: {e}"))?;
        let out: Vec<Poly> = (0..na * nb).map(|c| flat[c * D..(c + 1) * D].to_vec()).collect();
        LH_STAGES.fetch_add(stages, Ordering::Relaxed);
        LH_FLUSHES.fetch_add(flushes, Ordering::Relaxed);
        LH_BYTES.fetch_add(bytes_h2d, Ordering::Relaxed);
        add_us(&LH_FILL_US, secs_fill);
        add_us(&LH_WAIT_US, secs_wait);
        add_us(&LH_GROW_US, secs_grow);
        add_us(&LH_ENQ_US, secs_enq);
        if verbose() {
            eprintln!(
                "[UPERF2-Q] level-h session r {r} chunk {chunk} (window {window}, stage {n_blk}, ks {ks}, b_fmt {b_fmt}): {stages} stages, {flushes} flushes, grow {:.1} ms, fill {:.1} ms, enqueue {:.1} ms, wait {:.1} ms, h2d {:.0} MB",
                secs_grow * 1e3,
                secs_fill * 1e3,
                secs_enq * 1e3,
                secs_wait * 1e3,
                bytes_h2d as f64 / 1e6
            );
        }
        Ok(out)
    }
}

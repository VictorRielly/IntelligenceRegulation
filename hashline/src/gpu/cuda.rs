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
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;

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
];
const SC_THREADS: u32 = 256;
const SC_MAX_BLOCKS: u32 = 1024;
/// [UPERF3-AH] the block-looping round kernels' block size and the shared
/// parameter array they can hold (kernels.cu: SCG_THREADS / SCG_MAX_PRM).
const SCG_THREADS: u32 = 128;
pub const SCG_MAX_PRM: usize = 384;
const NTT_LOG_BLK: u32 = 12;
fn ntt_threads() -> u32 {
    static V: OnceLock<u32> = OnceLock::new();
    // [UPERF3-AJ] 256 -> 512: the NTT kernels hold a 32 KB shared tile, so
    // sm_89 fits 3 blocks per SM; at 256 threads that is 768 of the SM's
    // 1,536 threads (50% occupancy) and at 512 it is exactly 1,536.
    // Measured with `HL_GPU_CHUNK_ROWS=128` at the Mistral shape: 3.03 ->
    // 2.50 s for one layer, byte-identical (results/hashline_hostwall_gpu.md).
    *V.get_or_init(|| std::env::var("HL_GPU_NTT_THREADS").ok().and_then(|v| v.parse().ok()).unwrap_or(512u32).clamp(32, 1024))
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

fn pool_take(dev: &Arc<CudaDevice>, len: usize) -> Result<CudaSlice<u64>, String> {
    let mut pool = POOL.lock().unwrap();
    if let Some(i) = pool.iter().position(|b| b.len() == len) {
        return Ok(pool.swap_remove(i));
    }
    drop(pool);
    unsafe { dev.alloc::<u64>(len) }.map_err(|e| format!("cuMemAlloc({} MB): {e}", len * 8 >> 20))
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
    let mut pool = POOL.lock().unwrap();
    let mut best: Option<usize> = None;
    for (i, b) in pool.iter().enumerate() {
        if b.len() >= len && best.map(|j| b.len() < pool[j].len()).unwrap_or(true) {
            best = Some(i);
        }
    }
    if let Some(i) = best {
        return Ok(pool.swap_remove(i));
    }
    drop(pool);
    unsafe { dev.alloc::<u64>(len) }.map_err(|e| format!("cuMemAlloc({} MB): {e}", len * 8 >> 20))
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
    let g = g.lock().unwrap();
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
        Ok(Uploader { stream: raw, pin, ev: [mk()?, mk()?], armed: [false, false], cur: 0, secs: 0.0 })
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

impl Uploader {
    /// Pack `src` w bytes per element straight into the staging buffer and
    /// hand it to the DMA — the int8 planes cross the bus as bytes, and the
    /// device widens them back to the identical 64-bit image (`k_widen`).
    fn send_packed(&mut self, dst_base: sys::CUdeviceptr, elem_off: usize, src: &[u64], w: usize) -> Result<(), String> {
        let per = (self.pin[0].len * 8) / w; // elements per staging piece
        let t0 = Instant::now();
        let mut done = 0usize;
        while done < src.len() {
            let m = per.min(src.len() - done);
            let b = self.cur;
            if self.armed[b] {
                unsafe { cu::event::synchronize(self.ev[b]) }.map_err(|e| format!("cuEventSynchronize: {e}"))?;
                self.armed[b] = false;
            }
            let bytes: &mut [u8] = unsafe { std::slice::from_raw_parts_mut(self.pin[b].ptr as *mut u8, m * w) };
            if !pack_narrow(bytes, &src[done..done + m], w) {
                return Err("narrow pack: value out of range".into());
            }
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
    fn upload_narrow(&mut self, dst: &mut CudaSlice<u64>, src: &[u64], w: usize) -> Result<(), String> {
        let dev = self.dev.clone();
        let f = dev.get_func(MODULE, "k_widen").ok_or("k_widen missing")?;
        let mut d_pack = Pooled::take_min(&dev, (src.len() * w + 7) / 8)?;
        let pack_base: sys::CUdeviceptr = *d_pack.get().device_ptr();
        let data_base: sys::CUdeviceptr = *dst.device_ptr();
        if self.up().is_none() {
            return Err("pinned staging unavailable".into());
        }
        let mut up = self.up.take().unwrap();
        let r = up.send_packed(pack_base, 0, src, w).and_then(|_| up.wait());
        self.up = Some(up);
        r?;
        let cfg = LaunchConfig::for_num_elems(src.len() as u32);
        unsafe { f.launch(cfg, (pack_base, data_base, src.len() as i64, w as i32)) }.map_err(|e| format!("k_widen: {e}"))?;
        dev.synchronize().map_err(|e| e.to_string())?;
        drop(d_pack.0.take().map(pool_put));
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
                match self.upload_narrow(dst, src, w) {
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
}

impl Gpu {
    fn ensure_twiddles(&mut self, ntt: &NttTables) -> Result<(), String> {
        if let Some((ml, _, _)) = &self.tw {
            if *ml == ntt.max_log {
                return Ok(());
            }
        }
        // [rung 2] stage-major layout: stage s (half = 2^(s-1)) owns entries
        // [half - 1, 2 half - 1) = the CPU table's tw[k << (max_log - s)], k < half.
        let (f, i) = ntt.twiddle_tables();
        let ml = ntt.max_log;
        let stage_major = |t: &[Fp]| -> Vec<u64> {
            let mut out = Vec::with_capacity((1usize << ml) - 1);
            for s in 1..=ml {
                let half = 1usize << (s - 1);
                for k in 0..half {
                    out.push(t[k << (ml - s)].0);
                }
            }
            out
        };
        let df = self.dev.htod_sync_copy(&stage_major(f)).map_err(|e| format!("twiddle upload: {e}"))?;
        let di = self.dev.htod_sync_copy(&stage_major(i)).map_err(|e| format!("twiddle upload: {e}"))?;
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
            let p2 = self.dev.get_func(MODULE, "k_ntt_p2").ok_or("k_ntt_p2 missing")?;
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
}

/// Commit on the device: upload `data`, encode every row (inverse NTT of
/// size n, forward NTT of size nn = n * inv_rate with zero padding), and
/// return the device commitment plus the column leaves (rung 2: hashed on
/// the device; `HL_GPU_HOST_HASH=1` keeps rung 1's host hashing). `Err`
/// -> the caller runs the CPU body.
pub fn dev_commit(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
    let g = gpu().ok_or_else(init_err)?;
    let mut g = g.lock().unwrap();
    let n = params.cols();
    assert!(data.len() % n == 0 && !data.is_empty());
    let rows = data.len() / n;
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
            let mut d_data = Pooled::take(&dev, data.len())?;
            match g.commit_chunked_upload(as_u64s(data), &mut d_data, rows, params.log_cols, log_nn, chunk_rows()) {
                Ok(leaves) => {
                    note_vram(&g);
                    return Ok((DevCommit { rows, log_n: params.log_cols, log_nn, data: d_data, enc: None }, leaves));
                }
                Err(e) => eprintln!("[UPERF3-AJ] streamed commit declined ({e}); block upload"),
            }
        }
    }
    let mut d_data = Pooled::take(&dev, data.len())?;
    g.upload_sync(d_data.get_mut(), as_u64s(data))?;
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
        return Ok(DevCommit { rows, log_n, log_nn, data: d_data, enc: None });
    }
    let mut d_coef = Pooled::take(&dev, rows * n)?;
    let mut d_enc = match Pooled::take(&dev, rows * nn) {
        Ok(b) => b,
        Err(_) => return Ok(DevCommit { rows, log_n, log_nn, data: d_data, enc: None }),
    };
    g.encode_rows(d_data.get(), d_coef.get_mut(), d_enc.get_mut(), rows, log_n, log_nn)?;
    dev.synchronize().map_err(|e| e.to_string())?;
    stats_with(|s| s.secs_ntt += t1.elapsed().as_secs_f64());
    note_vram(&g);
    drop(d_coef);
    Ok(DevCommit { rows, log_n, log_nn, data: d_data, enc: Some(d_enc) })
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
            let pa = self.dev.get_func(MODULE, "k_dif_pa").ok_or("k_dif_pa missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pa.launch(cfg, (data, &mut *coef, ti, log_n as i32)) }.map_err(|e| format!("k_dif_pa: {e}"))?;
            let pb = self.dev.get_func(MODULE, "k_dif_pb").ok_or("k_dif_pb missing")?;
            let bpr = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            let cptr: sys::CUdeviceptr = *coef.device_ptr();
            unsafe { pb.launch(cfg, (cptr, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        } else {
            let pb = self.dev.get_func(MODULE, "k_dif_pb").ok_or("k_dif_pb missing")?;
            let cfg = LaunchConfig { grid_dim: (rows as u32, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pb.launch(cfg, (data, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        }
        let rb = log_nn - log_n;
        let p1 = self.dev.get_func(MODULE, "k_dit_p1_pad").ok_or("k_dit_p1_pad missing")?;
        let lb = log_nn.min(NTT_LOG_BLK);
        let bpr = 1u32 << (log_nn - lb);
        let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
        unsafe { p1.launch(cfg, (&*coef, &mut *enc, tf, log_nn as i32, (1usize << log_n) as i32, rb as i32)) }.map_err(|e| format!("k_dit_p1_pad: {e}"))?;
        if log_nn > NTT_LOG_BLK {
            let p2 = self.dev.get_func(MODULE, "k_ntt_p2").ok_or("k_ntt_p2 missing")?;
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
    fn encode_rows_view_gather(&self, data: &CudaView<u64>, coef: &mut CudaSlice<u64>, enc: &mut CudaSlice<u64>, rows: usize, log_n: u32, log_nn: u32,
                               d_sel: &CudaSlice<i32>, out: &mut CudaSlice<u64>, row0: usize, rows_total: usize) -> Result<(), String> {
        if log_nn <= NTT_LOG_BLK {
            return Err("gather fusion needs log_nn > NTT_LOG_BLK".into());
        }
        let (max_log, tf, ti) = self.tw.as_ref().ok_or("twiddles not uploaded")?;
        assert!(log_nn <= *max_log && log_n <= log_nn);
        assert!(coef.len() >= rows << log_n && enc.len() >= rows << log_nn);
        let scale: u64 = Fp::new(1u64 << log_n).inv().0;
        let threads = ntt_threads();
        if log_n > NTT_LOG_BLK {
            let pa = self.dev.get_func(MODULE, "k_dif_pa").ok_or("k_dif_pa missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pa.launch(cfg, (data, &mut *coef, ti, log_n as i32)) }.map_err(|e| format!("k_dif_pa: {e}"))?;
            let pb = self.dev.get_func(MODULE, "k_dif_pb").ok_or("k_dif_pb missing")?;
            let bpr = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            let cptr: sys::CUdeviceptr = *coef.device_ptr();
            unsafe { pb.launch(cfg, (cptr, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        } else {
            let pb = self.dev.get_func(MODULE, "k_dif_pb").ok_or("k_dif_pb missing")?;
            let cfg = LaunchConfig { grid_dim: (rows as u32, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pb.launch(cfg, (data, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        }
        let rb = log_nn - log_n;
        let p1 = self.dev.get_func(MODULE, "k_dit_p1_pad").ok_or("k_dit_p1_pad missing")?;
        let lb = log_nn.min(NTT_LOG_BLK);
        let bpr = 1u32 << (log_nn - lb);
        let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
        unsafe { p1.launch(cfg, (&*coef, &mut *enc, tf, log_nn as i32, (1usize << log_n) as i32, rb as i32)) }.map_err(|e| format!("k_dit_p1_pad: {e}"))?;
        let p2 = self.dev.get_func(MODULE, "k_ntt_p2_gather").ok_or("k_ntt_p2_gather missing")?;
        let tiles = 1u32 << (log_nn - NTT_LOG_BLK);
        let cfg2 = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
        unsafe { p2.launch(cfg2, (&*enc, tf, log_nn as i32, 1u64, d_sel, &mut *out, row0 as i32, rows_total as i32)) }
            .map_err(|e| format!("k_ntt_p2_gather: {e}"))?;
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
    fn commit_chunked_upload(&mut self, host: &[u64], d_data: &mut Pooled, rows: usize, log_n: u32, log_nn: u32, chunk: usize) -> Result<Vec<Digest>, String> {
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
        let w = if narrow_on() { narrow_probe(host) } else { 8 };
        let f_widen = self.dev.get_func(MODULE, "k_widen");
        let mut d_pack = if w < 8 && f_widen.is_some() {
            match Pooled::take_min(&dev, (host.len() * w + 7) / 8) {
                Ok(b) => Some(b),
                Err(_) => None,
            }
        } else {
            None
        };
        let w = if d_pack.is_some() { w } else { 8 };
        let pack_base: sys::CUdeviceptr = d_pack.as_ref().map(|b| *b.get().device_ptr()).unwrap_or(0);
        let data_base: sys::CUdeviceptr = *d_data.get().device_ptr();
        let mut up = self.up.take().unwrap();
        let secs0 = up.secs;
        let vb = verbose();
        let r = (|| -> Result<Vec<Digest>, String> {
            let (r0, rc) = plan[0];
            if w < 8 {
                up.send_packed(pack_base, r0 * n, &host[r0 * n..(r0 + rc) * n], w)?;
            } else {
                up.send(d_data.get_mut(), r0 * n, &host[r0 * n..(r0 + rc) * n])?;
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
                        up.send_packed(pack_base, r1 * n, &host[r1 * n..(r1 + rc1) * n], w)?;
                    } else {
                        up.send(d_data.get_mut(), r1 * n, &host[r1 * n..(r1 + rc1) * n])?;
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
        self.up = Some(up);
        let leaves = r?;
        drop(d_pack.take());
        let total = t0.elapsed().as_secs_f64();
        if vb {
            eprintln!("[UPERF3-AJ]   streamed commit rows {rows} 2^{log_n} -> 2^{log_nn} in {} chunks of <= {rmax} ({} B/elem on the wire): h2d visible {secs_up:.4} | total {total:.4} s", plan.len(), w);
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
        let plan = chunk_plan(rows, chunk);
        let rmax = plan.iter().map(|&(_, rc)| rc).max().unwrap();
        let t0 = Instant::now();
        let mut d_coef = Pooled::take_min(&dev, rmax * n)?;
        let mut d_enc = Pooled::take_min(&dev, rmax * nn)?;
        // [UPERF3-AJ] the fused form needs one output slot per DISTINCT index
        // (`challenge_indices` may repeat one; the duplicates are filled from
        // the first occurrence on the host, exactly as the gather kernel did).
        let fused = fuse_gather() && log_nn > NTT_LOG_BLK;
        let mut uniq: Vec<usize> = Vec::with_capacity(q);
        let mut slot: Vec<usize> = Vec::with_capacity(q);
        let mut sel: Vec<i32> = vec![-1; nn];
        for &j in idx {
            if sel[j] < 0 {
                sel[j] = uniq.len() as i32;
                uniq.push(j);
            }
            slot.push(sel[j] as usize);
        }
        let nu = uniq.len();
        let idx32: Vec<i32> = idx.iter().map(|&j| j as i32).collect();
        let d_idx = dev.htod_sync_copy(if fused { &sel } else { &idx32 }).map_err(|e| e.to_string())?;
        let cols_out = if fused { nu } else { q };
        let mut d_out = unsafe { dev.alloc::<u64>(rows * cols_out) }.map_err(|e| e.to_string())?;
        let f = dev.get_func(MODULE, "k_gather_cols_off").ok_or("k_gather_cols_off missing")?;
        for &(r0, rc) in &plan {
            let view = dc.data.get().slice(r0 * n..(r0 + rc) * n);
            if fused {
                self.encode_rows_view_gather(&view, d_coef.get_mut(), d_enc.get_mut(), rc, log_n, log_nn, &d_idx, &mut d_out, r0, rows)?;
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
        Ok((0..q)
            .map(|c| {
                let s0 = if fused { slot[c] } else { c } * rows;
                out[s0..s0 + rows].iter().map(|&v| Fp(v)).collect()
            })
            .collect())
    }
}

/// Rung 2's chunked check: the chunked commit's leaves == `hash_columns` of
/// the CPU encoding, and its re-encoded opening columns == the CPU
/// encoding at 16 indices, for `rows` rows in chunks of `chunk` rows.
/// Returns (bad leaves, bad column entries).
pub fn dev_commit_check_chunked(log_cols: u32, inv_rate: usize, rows: usize, chunk: usize) -> Result<(usize, usize), String> {
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
    let dc = DevCommit { rows, log_n: params.log_cols, log_nn: nn.trailing_zeros(), data: d_data, enc: None };
    let idx: Vec<usize> = (0..16).map(|i| (i * 7919 + 13) % nn).collect();
    let cols = g.columns_chunked(&dc, &idx, chunk)?;
    let mut bad_cols = 0;
    for (c, &j) in idx.iter().enumerate() {
        for i in 0..rows {
            if cols[c][i] != cpu[i * nn + j] {
                bad_cols += 1;
            }
        }
    }
    Ok((bad_leaves, bad_cols))
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
            return Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: None }, leaves));
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
    Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: Some(d_enc) }, leaves))
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
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let q = idx.len();
    let rows = dc.rows;
    let nn = 1usize << dc.log_nn;
    // [UPERF3-AC] a chunked commitment: re-encode chunk by chunk and gather
    let enc = match &dc.enc {
        Some(e) => e,
        None => return g.columns_chunked(dc, idx, chunk_rows()),
    };
    let idx32: Vec<i32> = idx.iter().map(|&j| j as i32).collect();
    let d_idx = dev.htod_sync_copy(&idx32).map_err(|e| e.to_string())?;
    let mut d_out = unsafe { dev.alloc::<u64>(rows * q) }.map_err(|e| e.to_string())?;
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
            let freed = {
                let mut pool = POOL.lock().unwrap();
                let n = pool.len();
                pool.clear();
                n
            };
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
            let pa = self.dev.get_func(MODULE, "k_dif_pa").ok_or("k_dif_pa missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pa.launch(cfg, (data, &mut *coef, ti, log_n as i32)) }.map_err(|e| format!("k_dif_pa: {e}"))?;
            let pb = self.dev.get_func(MODULE, "k_dif_pb").ok_or("k_dif_pb missing")?;
            let bpr = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            // in place: the raw pointer as the source (each block reads its own range before writing it)
            let cptr: sys::CUdeviceptr = *coef.device_ptr();
            unsafe { pb.launch(cfg, (cptr, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        } else {
            let pb = self.dev.get_func(MODULE, "k_dif_pb").ok_or("k_dif_pb missing")?;
            let cfg = LaunchConfig { grid_dim: (rows as u32, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
            unsafe { pb.launch(cfg, (data, &mut *coef, ti, log_n as i32, scale)) }.map_err(|e| format!("k_dif_pb: {e}"))?;
        }
        if vb { self.dev.synchronize().map_err(|e| e.to_string())?; }
        let tb = Instant::now();
        // forward: DIT p1 with the contiguous padded load, then p2
        let rb = log_nn - log_n;
        let p1 = self.dev.get_func(MODULE, "k_dit_p1_pad").ok_or("k_dit_p1_pad missing")?;
        let lb = log_nn.min(NTT_LOG_BLK);
        let bpr = 1u32 << (log_nn - lb);
        let cfg = LaunchConfig { grid_dim: (rows as u32 * bpr, 1, 1), block_dim: (threads, 1, 1), shared_mem_bytes: 0 };
        unsafe { p1.launch(cfg, (&*coef, &mut *enc, tf, log_nn as i32, (1usize << log_n) as i32, rb as i32)) }.map_err(|e| format!("k_dit_p1_pad: {e}"))?;
        if log_nn > NTT_LOG_BLK {
            let p2 = self.dev.get_func(MODULE, "k_ntt_p2").ok_or("k_ntt_p2 missing")?;
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
    let mut d_coef = Pooled::take(&dev, rows * n)?;
    g.ntt_rows(d_data.get(), d_coef.get_mut(), rows, n, log_n, true)?;
    let d_pads = dev.htod_sync_copy(as_u64s(pads)).map_err(|e| format!("pads upload: {e}"))?;
    let d_pows = dev.htod_sync_copy(as_u64s(pows)).map_err(|e| format!("pows upload: {e}"))?;
    stats_with(|s| s.bytes_h2d += ((pads.len() + pows.len()) * 8) as u64);
    let mut d_coef2 = Pooled::take(&dev, rows * nn)?;
    let f = dev.get_func(MODULE, "k_zk_pad_scale").ok_or("k_zk_pad_scale missing")?;
    let cfg = LaunchConfig::for_num_elems((rows * nn) as u32);
    unsafe { f.launch(cfg, (d_coef.get(), &d_pads, &d_pows, d_coef2.get_mut(), rows as i32, n as i32, q as i32, nn as i32)) }.map_err(|e| format!("k_zk_pad_scale: {e}"))?;
    drop(d_coef);
    let mut d_enc = Pooled::take(&dev, rows * nn)?;
    g.ntt_rows(d_coef2.get(), d_enc.get_mut(), rows, nn, log_nn, false)?;
    dev.synchronize().map_err(|e| e.to_string())?;
    let t2 = Instant::now();
    stats_with(|s| s.secs_ntt += (t2 - t1).as_secs_f64());
    note_vram(&g);
    drop(d_coef2);
    let leaves = g.hash_cols(d_enc.get(), rows, nn)?;
    let t3 = Instant::now();
    stats_with(|s| { s.secs_hash += (t3 - t2).as_secs_f64(); s.bytes_d2h += (nn * 32) as u64; });
    Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: Some(d_enc) }, leaves))
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

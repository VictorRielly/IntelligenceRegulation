// [UPERF2-K] The CUDA implementation of the GPU rung (feature `gpu-cuda`).
// See mod.rs for the discipline; kernels.cu for the device code.

use super::super::aux::{self, D};
use super::super::eval_proof::{ntt_window_terms, threads, SmallRings};
use super::super::{Poly, RingCtx};
use cudarc::driver::{sys, CudaDevice, CudaFunction, CudaSlice, DeviceRepr, LaunchAsync, LaunchConfig, ValidAsZeroBits};
use cudarc::nvrtc::{compile_ptx_with_opts, CompileOptions};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, LazyLock, Mutex, OnceLock};
use std::time::Instant;

const KSRC: &str = include_str!("kernels.cu");
const MODULE: &str = "zkgpu";
const FUNCS: &[&str] = &["k_mulmod_probe", "k_ntt_fwd", "k_gemm_split", "k_flush_reduce", "k_ntt_inv"];
/// Rings per block of the transform kernels (== R_FWD in kernels.cu).
const R_FWD: usize = 32;
/// GEMM tile (== TM_G / TN_G / KB_G in kernels.cu).
const TM_G: usize = 64;
const TN_G: usize = 64;
const KB_G: usize = 16;

// ---------------------------------------------------------------------------
// State

struct Gpu {
    dev: Arc<CudaDevice>,
    name: String,
    cc: (i32, i32),
    sms: i32,
    vram_total: usize,
    psi: CudaSlice<u64>,
    ipsi: CudaSlice<u64>,
    n_inv: u64,
    // Reusable device scratch, grown on demand (kept resident between calls).
    a_src32: Scratch<u32>,
    a_src64: Scratch<u64>,
    b_src8: Scratch<i8>,
    b_src64: Scratch<i64>,
    a_t: Scratch<u64>,
    b_t: Scratch<u64>,
    acc: Scratch<u64>,
    v: Scratch<u64>,
    out: Scratch<u64>,
}

struct Scratch<T> {
    buf: Option<CudaSlice<T>>,
    cap: usize,
}

impl<T: DeviceRepr + ValidAsZeroBits> Scratch<T> {
    fn new() -> Self {
        Scratch { buf: None, cap: 0 }
    }
    /// A buffer of at least `n` elements (contents unspecified).
    fn get(&mut self, dev: &Arc<CudaDevice>, n: usize) -> Result<&mut CudaSlice<T>, String> {
        if self.buf.is_none() || self.cap < n {
            self.buf = None; // free before the larger allocation
            let cap = n.max(1);
            let b = unsafe { dev.alloc::<T>(cap) }.map_err(|e| format!("cuMemAlloc({} x {} B): {e}", cap, std::mem::size_of::<T>()))?;
            self.buf = Some(b);
            self.cap = cap;
        }
        Ok(self.buf.as_mut().unwrap())
    }
    fn release(&mut self) {
        self.buf = None;
        self.cap = 0;
    }
}

static GPU: OnceLock<Option<Mutex<Gpu>>> = OnceLock::new();
static BYPASS: AtomicBool = AtomicBool::new(false);
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
    (if o > 0 { o } else { env_usize("ZK_GPU_BLOCK_MB", 512) }) << 20
}
static WARNED: AtomicBool = AtomicBool::new(false);
static INIT_ERR: Mutex<Option<String>> = Mutex::new(None);

/// The kernel-pool of this module (the same `ZK_THREADS` size as
/// eval_proof's; only host-side packing rides it — values are unaffected).
static POOL: LazyLock<rayon::ThreadPool> = LazyLock::new(|| {
    rayon::ThreadPoolBuilder::new().num_threads(threads()).build().expect("ZK_THREADS pool (gpu)")
});

fn env_flag(name: &str) -> bool {
    std::env::var(name).map(|v| v == "1").unwrap_or(false)
}

fn env_usize(name: &str, default: usize) -> usize {
    std::env::var(name).ok().and_then(|v| v.parse::<usize>().ok()).unwrap_or(default)
}

/// `ZK_GPU=1` requested (read once).
fn requested() -> bool {
    static ON: OnceLock<bool> = OnceLock::new();
    *ON.get_or_init(|| env_flag("ZK_GPU"))
}

fn verbose() -> bool {
    static V: OnceLock<bool> = OnceLock::new();
    *V.get_or_init(|| env_flag("ZK_GPU_VERBOSE"))
}

/// Minimum D-domain MACs (D * na * nb * len) for a GEMM to go to the device.
fn min_macs() -> u128 {
    static M: OnceLock<usize> = OnceLock::new();
    *M.get_or_init(|| env_usize("ZK_GPU_MIN_MACS", 1 << 22)) as u128
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
    let (_free, total) = cudarc::driver::result::mem_get_info().map_err(|e| format!("cuMemGetInfo: {e}"))?;
    // NVRTC compile once (arch-targeted PTX when the cc is known; the
    // generic default otherwise / on failure).
    let t0 = Instant::now();
    let compile = |arch: Option<&'static str>| {
        let opts = CompileOptions { arch, ..Default::default() };
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
    // Twiddle tables (the CPU tables, copied — same values).
    let t = aux::build_tables();
    let psi_h: Vec<u64> = (0..D).map(|i| t.psi_brv(i)).collect();
    let ipsi_h: Vec<u64> = (0..D).map(|i| t.ipsi_brv(i)).collect();
    let psi = dev.htod_sync_copy(&psi_h).map_err(|e| format!("psi upload: {e}"))?;
    let ipsi = dev.htod_sync_copy(&ipsi_h).map_err(|e| format!("ipsi upload: {e}"))?;
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
        psi,
        ipsi,
        n_inv: t.n_inv(),
        a_src32: Scratch::new(),
        a_src64: Scratch::new(),
        b_src8: Scratch::new(),
        b_src64: Scratch::new(),
        a_t: Scratch::new(),
        b_t: Scratch::new(),
        acc: Scratch::new(),
        v: Scratch::new(),
        out: Scratch::new(),
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
/// A/B inside one process).
pub fn set_bypass(on: bool) {
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
                "gpu-cuda: {} (sm_{}{}, {} SMs, {:.1} GB VRAM), ZK_GPU=1, min_macs {}, bypass {}",
                g.name,
                g.cc.0,
                g.cc.1,
                g.sms,
                g.vram_total as f64 / 1e9,
                min_macs(),
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
    pub secs_pack: f64,
    pub secs_h2d: f64,
    pub secs_gpu: f64,
    pub secs_total: f64,
}

static S_CALLS: AtomicU64 = AtomicU64::new(0);
static S_DECLINED: AtomicU64 = AtomicU64::new(0);
static S_MACS: AtomicU64 = AtomicU64::new(0); // in units of 2^10 MACs
static S_BYTES: AtomicU64 = AtomicU64::new(0);
static S_PACK_US: AtomicU64 = AtomicU64::new(0);
static S_H2D_US: AtomicU64 = AtomicU64::new(0);
static S_GPU_US: AtomicU64 = AtomicU64::new(0);
static S_TOTAL_US: AtomicU64 = AtomicU64::new(0);

pub fn stats() -> GpuStats {
    GpuStats {
        calls: S_CALLS.load(Ordering::Relaxed),
        declined: S_DECLINED.load(Ordering::Relaxed),
        macs: (S_MACS.load(Ordering::Relaxed) as u128) << 10,
        bytes_h2d: S_BYTES.load(Ordering::Relaxed),
        secs_pack: S_PACK_US.load(Ordering::Relaxed) as f64 * 1e-6,
        secs_h2d: S_H2D_US.load(Ordering::Relaxed) as f64 * 1e-6,
        secs_gpu: S_GPU_US.load(Ordering::Relaxed) as f64 * 1e-6,
        secs_total: S_TOTAL_US.load(Ordering::Relaxed) as f64 * 1e-6,
    }
}

pub fn stats_reset() {
    for s in [&S_CALLS, &S_DECLINED, &S_MACS, &S_BYTES, &S_PACK_US, &S_H2D_US, &S_GPU_US, &S_TOTAL_US] {
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
// Battery helper: the transforms alone

/// Forward (`inverse == false`; standard-order input, bit-reversed output)
/// or inverse transform of raw Z_p rings on the device — the battery
/// compares against `ntt_fwd_best` / `ntt_inv_best`.
pub fn ntt_batch(rings: &[[u64; D]], inverse: bool) -> Result<Vec<[u64; D]>, String> {
    let g = gpu().ok_or_else(|| INIT_ERR.lock().unwrap().clone().unwrap_or_else(|| "no device".to_string()))?;
    let mut g = g.lock().unwrap();
    let n = rings.len();
    if n == 0 {
        return Ok(Vec::new());
    }
    let flat: Vec<u64> = rings.iter().flat_map(|r| r.iter().copied()).collect();
    let dev = g.dev.clone();
    let src = dev.htod_sync_copy(&flat).map_err(|e| e.to_string())?;
    let mut dst = dev.alloc_zeros::<u64>(n * D).map_err(|e| e.to_string())?;
    let blocks = n.div_ceil(R_FWD) as u32;
    let cfg = LaunchConfig { grid_dim: (blocks, 1, 1), block_dim: (256, 1, 1), shared_mem_bytes: 0 };
    let mut out = vec![[0u64; D]; n];
    if !inverse {
        let f = dev.get_func(MODULE, "k_ntt_fwd").ok_or("k_ntt_fwd missing")?;
        unsafe { f.launch(cfg, (&src, 4i32, 0u64, n as i32, &mut dst, &g.psi)) }.map_err(|e| e.to_string())?;
        let flat_t = dev.dtoh_sync_copy(&dst).map_err(|e| e.to_string())?; // [t][slot]
        for slot in 0..n {
            for t in 0..D {
                out[slot][t] = flat_t[t * n + slot];
            }
        }
    } else {
        let f = dev.get_func(MODULE, "k_ntt_inv").ok_or("k_ntt_inv missing")?;
        let mut v = src;
        let n_inv = g.n_inv;
        unsafe { f.launch(cfg, (&mut v, n as i32, &g.ipsi, n_inv, 0i32, 0u64, &mut dst)) }.map_err(|e| e.to_string())?;
        let flat_o = dev.dtoh_sync_copy(&dst).map_err(|e| e.to_string())?;
        for slot in 0..n {
            out[slot].copy_from_slice(&flat_o[slot * D..(slot + 1) * D]);
        }
    }
    let _ = &mut g; // keep the lock for the duration
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
    let q = ctx.zq.q;
    let s_max: u128 = b.iter().map(|s| s.max_abs()).max().unwrap_or(0);
    let window = ntt_window_terms(q, s_max);
    if window == 0 {
        return None; // over capacity: the CPU body runs its exact oracle
    }
    let macs = (D as u128) * (na as u128) * (nb as u128) * (len as u128);
    if !force && macs < min_macs() {
        S_DECLINED.fetch_add(1, Ordering::Relaxed);
        return None;
    }
    let t0 = Instant::now();
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
            // route every later call to the CPU.
            st.release_all();
            BYPASS.store(true, Ordering::Relaxed);
            None
        }
    }
}

impl Gpu {
    fn release_all(&mut self) {
        self.a_src32.release();
        self.a_src64.release();
        self.b_src8.release();
        self.b_src64.release();
        self.a_t.release();
        self.b_t.release();
        self.acc.release();
        self.v.release();
        self.out.release();
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
        let q = ctx.zq.q;
        let (na, nb) = (a.len(), b.len());
        let a_fmt: i32 = if q < (1u64 << 32) { 0 } else { 1 };
        let b_fmt: i32 = if s_max <= 127 { 2 } else { 3 };
        let a_elt = if a_fmt == 0 { 4 } else { 8 };
        let b_elt = if b_fmt == 2 { 1 } else { 8 };
        // u-block: positions per device round trip, sized to the budget.
        let budget = block_budget_bytes();
        let per_pos = (na + nb) * D * 8 + na * D * a_elt + nb * D * b_elt;
        let ublk = (budget / per_pos.max(1)).clamp(1, len.min(window));
        // Split-K count: enough blocks to fill the device (target 512), the
        // accumulator capped at 256 MB.
        let tiles_m = na.div_ceil(TM_G);
        let tiles_n = nb.div_ceil(TN_G);
        let base_blocks = D * tiles_m * tiles_n;
        let acc_cell_bytes = D * na * nb * 32;
        let ks_cap = ((256usize << 20) / acc_cell_bytes.max(1)).max(1);
        let ks = (512usize.div_ceil(base_blocks)).clamp(1, ublk.div_ceil(KB_G)).min(ks_cap);
        // Device buffers.
        let n_a_src = na * ublk * D;
        let n_b_src = nb * ublk * D;
        let mut out_dev = self.out.get(&dev, na * nb * D)?.slice_mut(0..na * nb * D);
        dev.memset_zeros(&mut out_dev).map_err(|e| format!("memset out: {e}"))?;
        drop(out_dev);
        // Host staging.
        let mut a_st32: Vec<u32> = if a_fmt == 0 { vec![0u32; n_a_src] } else { Vec::new() };
        let mut a_st64: Vec<u64> = if a_fmt == 1 { vec![0u64; n_a_src] } else { Vec::new() };
        let mut b_st8: Vec<i8> = if b_fmt == 2 { vec![0i8; n_b_src] } else { Vec::new() };
        let mut b_st64: Vec<i64> = if b_fmt == 3 { vec![0i64; n_b_src] } else { Vec::new() };
        let f_fwd = dev.get_func(MODULE, "k_ntt_fwd").ok_or("k_ntt_fwd missing")?;
        let f_gemm = dev.get_func(MODULE, "k_gemm_split").ok_or("k_gemm_split missing")?;
        let f_flush = dev.get_func(MODULE, "k_flush_reduce").ok_or("k_flush_reduce missing")?;
        let f_inv = dev.get_func(MODULE, "k_ntt_inv").ok_or("k_ntt_inv missing")?;
        let (mut secs_pack, mut secs_h2d, mut secs_gpu) = (0.0f64, 0.0f64, 0.0f64);
        let mut bytes_h2d = 0u64;
        let mut u0 = 0usize;
        while u0 < len {
            let u1 = (u0 + window).min(len);
            // Zero the window accumulator.
            {
                let mut acc = self.acc.get(&dev, ks * D * na * nb * 4)?.slice_mut(0..ks * D * na * nb * 4);
                dev.memset_zeros(&mut acc).map_err(|e| format!("memset acc: {e}"))?;
            }
            let mut ub0 = u0;
            while ub0 < u1 {
                let n = ublk.min(u1 - ub0);
                // ---- pack the u-block (host, pooled): slot = ub * na + ia / ub * nb + ib.
                let tp = Instant::now();
                let pack = |a_st32: &mut [u32], a_st64: &mut [u64], b_st8: &mut [i8], b_st64: &mut [i64]| {
                    use rayon::prelude::*;
                    let per_a = na * D;
                    let per_b = nb * D;
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
                            if a_fmt == 0 {
                                a_st32[..n * per_a].par_chunks_mut(per_a).enumerate().for_each(|(ub, c)| do_a32(ub, c));
                            } else {
                                a_st64[..n * per_a].par_chunks_mut(per_a).enumerate().for_each(|(ub, c)| do_a64(ub, c));
                            }
                            if b_fmt == 2 {
                                b_st8[..n * per_b].par_chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b8(ub, c));
                            } else {
                                b_st64[..n * per_b].par_chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b64(ub, c));
                            }
                        });
                    } else {
                        if a_fmt == 0 {
                            a_st32[..n * per_a].chunks_mut(per_a).enumerate().for_each(|(ub, c)| do_a32(ub, c));
                        } else {
                            a_st64[..n * per_a].chunks_mut(per_a).enumerate().for_each(|(ub, c)| do_a64(ub, c));
                        }
                        if b_fmt == 2 {
                            b_st8[..n * per_b].chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b8(ub, c));
                        } else {
                            b_st64[..n * per_b].chunks_mut(per_b).enumerate().for_each(|(ub, c)| do_b64(ub, c));
                        }
                    }
                };
                pack(&mut a_st32, &mut a_st64, &mut b_st8, &mut b_st64);
                secs_pack += tp.elapsed().as_secs_f64();
                // ---- upload.
                let th = Instant::now();
                let n_as = n * na * D;
                let n_bs = n * nb * D;
                if a_fmt == 0 {
                    let mut d = self.a_src32.get(&dev, n_as)?.slice_mut(0..n_as);
                    dev.htod_sync_copy_into(&a_st32[..n_as], &mut d).map_err(|e| format!("h2d a32: {e}"))?;
                } else {
                    let mut d = self.a_src64.get(&dev, n_as)?.slice_mut(0..n_as);
                    dev.htod_sync_copy_into(&a_st64[..n_as], &mut d).map_err(|e| format!("h2d a64: {e}"))?;
                }
                if b_fmt == 2 {
                    let mut d = self.b_src8.get(&dev, n_bs)?.slice_mut(0..n_bs);
                    dev.htod_sync_copy_into(&b_st8[..n_bs], &mut d).map_err(|e| format!("h2d b8: {e}"))?;
                } else {
                    let mut d = self.b_src64.get(&dev, n_bs)?.slice_mut(0..n_bs);
                    dev.htod_sync_copy_into(&b_st64[..n_bs], &mut d).map_err(|e| format!("h2d b64: {e}"))?;
                }
                bytes_h2d += (n_as * a_elt + n_bs * b_elt) as u64;
                secs_h2d += th.elapsed().as_secs_f64();
                // ---- transforms + GEMM on the device.
                let tg = Instant::now();
                let n_slots_a = n * na;
                let n_slots_b = n * nb;
                self.a_t.get(&dev, D * n_slots_a)?;
                self.b_t.get(&dev, D * n_slots_b)?;
                let cfg_a = LaunchConfig { grid_dim: (n_slots_a.div_ceil(R_FWD) as u32, 1, 1), block_dim: (256, 1, 1), shared_mem_bytes: 0 };
                let cfg_b = LaunchConfig { grid_dim: (n_slots_b.div_ceil(R_FWD) as u32, 1, 1), block_dim: (256, 1, 1), shared_mem_bytes: 0 };
                {
                    let a_t = self.a_t.buf.as_mut().unwrap();
                    if a_fmt == 0 {
                        let src = self.a_src32.buf.as_ref().unwrap();
                        unsafe { f_fwd.clone().launch(cfg_a, (src, a_fmt, q, n_slots_a as i32, a_t, &self.psi)) }
                            .map_err(|e| format!("fwd a: {e}"))?;
                    } else {
                        let src = self.a_src64.buf.as_ref().unwrap();
                        unsafe { f_fwd.clone().launch(cfg_a, (src, a_fmt, q, n_slots_a as i32, a_t, &self.psi)) }
                            .map_err(|e| format!("fwd a: {e}"))?;
                    }
                }
                {
                    let b_t = self.b_t.buf.as_mut().unwrap();
                    if b_fmt == 2 {
                        let src = self.b_src8.buf.as_ref().unwrap();
                        unsafe { f_fwd.clone().launch(cfg_b, (src, b_fmt, q, n_slots_b as i32, b_t, &self.psi)) }
                            .map_err(|e| format!("fwd b: {e}"))?;
                    } else {
                        let src = self.b_src64.buf.as_ref().unwrap();
                        unsafe { f_fwd.clone().launch(cfg_b, (src, b_fmt, q, n_slots_b as i32, b_t, &self.psi)) }
                            .map_err(|e| format!("fwd b: {e}"))?;
                    }
                }
                let ks_n = ks.min(n.div_ceil(KB_G)).max(1);
                let k_per_split = n.div_ceil(ks_n);
                let cfg_g = LaunchConfig {
                    grid_dim: (tiles_n as u32, tiles_m as u32, (D * ks_n) as u32),
                    block_dim: (16, 16, 1),
                    shared_mem_bytes: 0,
                };
                {
                    let a_t = self.a_t.buf.as_ref().unwrap();
                    let b_t = self.b_t.buf.as_ref().unwrap();
                    let acc = self.acc.buf.as_mut().unwrap();
                    unsafe {
                        f_gemm.clone().launch(cfg_g, (a_t, b_t, acc, na as i32, nb as i32, n as i32, ks_n as i32, k_per_split as i32))
                    }
                    .map_err(|e| format!("gemm: {e}"))?;
                }
                dev.synchronize().map_err(|e| format!("sync (block): {e}"))?;
                secs_gpu += tg.elapsed().as_secs_f64();
                ub0 += n;
            }
            // ---- window flush: reduce -> inverse NTT -> center/mod q/add.
            let tg = Instant::now();
            let cells = na * nb;
            self.v.get(&dev, cells * D)?;
            {
                let acc = self.acc.buf.as_ref().unwrap();
                let v = self.v.buf.as_mut().unwrap();
                let cfg_f = LaunchConfig { grid_dim: (cells as u32, 1, 1), block_dim: (D as u32, 1, 1), shared_mem_bytes: 0 };
                unsafe { f_flush.clone().launch(cfg_f, (acc, ks as i32, na as i32, nb as i32, v)) }.map_err(|e| format!("flush: {e}"))?;
            }
            {
                let v = self.v.buf.as_mut().unwrap();
                let out = self.out.buf.as_mut().unwrap();
                let cfg_i = LaunchConfig { grid_dim: (cells.div_ceil(R_FWD) as u32, 1, 1), block_dim: (256, 1, 1), shared_mem_bytes: 0 };
                let n_inv = self.n_inv;
                unsafe { f_inv.clone().launch(cfg_i, (v, cells as i32, &self.ipsi, n_inv, 1i32, q, out)) }.map_err(|e| format!("inv: {e}"))?;
            }
            dev.synchronize().map_err(|e| format!("sync (window): {e}"))?;
            secs_gpu += tg.elapsed().as_secs_f64();
            u0 = u1;
        }
        // ---- results.
        let mut flat = vec![0u64; na * nb * D];
        {
            let out = self.out.buf.as_ref().unwrap().slice(0..na * nb * D);
            dev.dtoh_sync_copy_into(&out, &mut flat).map_err(|e| format!("d2h out: {e}"))?;
        }
        let out: Vec<Poly> = (0..na * nb).map(|c| flat[c * D..(c + 1) * D].to_vec()).collect();
        S_BYTES.fetch_add(bytes_h2d, Ordering::Relaxed);
        add_us(&S_PACK_US, secs_pack);
        add_us(&S_H2D_US, secs_h2d);
        add_us(&S_GPU_US, secs_gpu);
        if verbose() {
            eprintln!(
                "[UPERF2-K] gemm na {na} nb {nb} len {len} (window {window}, ublk {ublk}, ks {ks}, a_fmt {a_fmt}, b_fmt {b_fmt}): pack {:.1} ms, h2d {:.1} ms ({:.0} MB), gpu {:.1} ms",
                secs_pack * 1e3,
                secs_h2d * 1e3,
                bytes_h2d as f64 / 1e6,
                secs_gpu * 1e3
            );
        }
        Ok(out)
    }
}

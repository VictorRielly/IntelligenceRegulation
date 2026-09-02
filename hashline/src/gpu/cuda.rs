// [UPERF3-XX] The CUDA implementation of hashline's GPU port (feature
// `gpu-cuda`). See mod.rs for the discipline; kernels.cu for the device
// code. Bootstrap copied from zkmatrix-rs/src/ring/gpu/cuda.rs: one device
// singleton, NVRTC compile of the kernel source once per process, a
// runtime toggle (`HL_GPU=1`), a probe against the CPU field.

use crate::field::{Fp, P};
use cudarc::driver::result as cu;
use cudarc::driver::{sys, CudaDevice, LaunchAsync, LaunchConfig};
use cudarc::nvrtc::{compile_ptx_with_opts, CompileOptions};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;

const KSRC: &str = include_str!("kernels.cu");
const MODULE: &str = "hlgpu";
const FUNCS: &[&str] = &["k_probe"];

pub(super) struct Gpu {
    pub(super) dev: Arc<CudaDevice>,
    pub(super) name: String,
    pub(super) cc: (i32, i32),
    pub(super) sms: i32,
    pub(super) vram_total: usize,
}

// The driver handles are thread-agnostic (the context is bound per thread
// on every entry); the singleton lives behind a Mutex.
unsafe impl Send for Gpu {}

static GPU: OnceLock<Option<Mutex<Gpu>>> = OnceLock::new();
static INIT_ERR: Mutex<Option<String>> = Mutex::new(None);

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
}
static STATS: Mutex<GpuStats> = Mutex::new(GpuStats {
    secs_h2d: 0.0, secs_ntt: 0.0, secs_hash: 0.0, secs_d2h: 0.0, secs_sumcheck: 0.0, secs_fold: 0.0, secs_helpers: 0.0,
    bytes_h2d: 0, bytes_d2h: 0, vram_peak: 0,
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
    let ptx = match compile(arch_str((major, minor))) {
        Ok(p) => p,
        Err(e1) => match compile(None) {
            Ok(p) => p,
            Err(e2) => return Err(format!("NVRTC compile failed: {e1}; generic retry: {e2}")),
        },
    };
    dev.load_ptx(ptx, MODULE, FUNCS).map_err(|e| format!("cuModuleLoadData: {e}"))?;
    let secs_compile = t0.elapsed().as_secs_f64();
    if verbose() {
        eprintln!(
            "[UPERF3-XX] gpu init: {name} (sm_{major}{minor}, {sms} SMs, {:.1} GB), NVRTC compile {secs_compile:.2}s",
            total as f64 / 1e9
        );
    }
    Ok(Gpu { dev, name, cc: (major, minor), sms, vram_total: total })
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
    Ok(ProbeReport { device: g.name.clone(), n, mismatches: bad, gmul_per_s: reps as f64 * n as f64 / dt / 1e9 })
}

// [UPERF3-XX] The CUDA implementation of hashline's GPU port (feature
// `gpu-cuda`). See mod.rs for the discipline; kernels.cu for the device
// code. Bootstrap copied from zkmatrix-rs/src/ring/gpu/cuda.rs: one device
// singleton, NVRTC compile of the kernel source once per process, a
// runtime toggle (`HL_GPU=1`), a probe against the CPU field.

use crate::field::{Fp, P};
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::PcsParams;
use cudarc::driver::result as cu;
use cudarc::driver::{sys, CudaDevice, CudaSlice, LaunchAsync, LaunchConfig};
use cudarc::nvrtc::{compile_ptx_with_opts, CompileOptions};
use rayon::prelude::*;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;

const KSRC: &str = include_str!("kernels.cu");
const MODULE: &str = "hlgpu";
const FUNCS: &[&str] = &["k_probe", "k_ntt_p1", "k_ntt_p2", "k_gather_cols"];
const NTT_LOG_BLK: u32 = 12;
const NTT_THREADS: u32 = 256;

pub(super) struct Gpu {
    pub(super) dev: Arc<CudaDevice>,
    pub(super) name: String,
    pub(super) cc: (i32, i32),
    pub(super) sms: i32,
    pub(super) vram_total: usize,
    /// The twiddle tables of the NttTables in use (keyed by max_log): forward, inverse.
    tw: Option<(u32, CudaSlice<u64>, CudaSlice<u64>)>,
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
    Ok(Gpu { dev, name, cc: (major, minor), sms, vram_total: total, tw: None })
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
    Ok(ProbeReport { device: g.name.clone(), n, mismatches: bad, gmul_per_s: reps as f64 * n as f64 / dt / 1e9 })
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
    pub(super) data: CudaSlice<u64>,
    pub(super) enc: CudaSlice<u64>,
    /// rung 1: the host copy of the systematic data for the CPU row-combination (rung 4 removes it).
    pub data_host: Vec<Fp>,
}

impl Gpu {
    fn ensure_twiddles(&mut self, ntt: &NttTables) -> Result<(), String> {
        if let Some((ml, _, _)) = &self.tw {
            if *ml == ntt.max_log {
                return Ok(());
            }
        }
        let (f, i) = ntt.twiddle_tables();
        let df = self.dev.htod_sync_copy(as_u64s(f)).map_err(|e| format!("twiddle upload: {e}"))?;
        let di = self.dev.htod_sync_copy(as_u64s(i)).map_err(|e| format!("twiddle upload: {e}"))?;
        self.tw = Some((ntt.max_log, df, di));
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
        let cfg1 = LaunchConfig { grid_dim: (rows as u32 * blocks_per_row, 1, 1), block_dim: (NTT_THREADS, 1, 1), shared_mem_bytes: 0 };
        unsafe { p1.launch(cfg1, (src, &mut *dst, tw, log_n as i32, n_src as i32, max_log as i32, scale)) }.map_err(|e| format!("k_ntt_p1: {e}"))?;
        if log_n > NTT_LOG_BLK {
            let p2 = self.dev.get_func(MODULE, "k_ntt_p2").ok_or("k_ntt_p2 missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg2 = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (NTT_THREADS, 1, 1), shared_mem_bytes: 0 };
            unsafe { p2.launch(cfg2, (&mut *dst, tw, log_n as i32, max_log as i32, scale)) }.map_err(|e| format!("k_ntt_p2: {e}"))?;
        }
        Ok(())
    }
}

/// Commit on the device: upload `data`, encode every row (inverse NTT of
/// size n, forward NTT of size nn = n * inv_rate with zero padding), and
/// return the device commitment plus the column leaves (rung 1: hashed
/// on the host from the encoded matrix copied back). `Err` -> the caller
/// runs the CPU body.
pub fn dev_commit(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Result<(DevCommit, Vec<Digest>), String> {
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
    let t0 = Instant::now();
    let d_data = dev.htod_sync_copy(as_u64s(data)).map_err(|e| format!("data upload: {e}"))?;
    dev.synchronize().map_err(|e| e.to_string())?;
    let t1 = Instant::now();
    stats_with(|s| { s.secs_h2d += (t1 - t0).as_secs_f64(); s.bytes_h2d += (data.len() * 8) as u64; });
    let mut d_coef = unsafe { dev.alloc::<u64>(rows * n) }.map_err(|e| format!("coef alloc: {e}"))?;
    let mut d_enc = unsafe { dev.alloc::<u64>(rows * nn) }.map_err(|e| format!("enc alloc: {e}"))?;
    g.ntt_rows(&d_data, &mut d_coef, rows, n, log_n, true)?;
    g.ntt_rows(&d_coef, &mut d_enc, rows, n, log_nn, false)?;
    dev.synchronize().map_err(|e| e.to_string())?;
    let t2 = Instant::now();
    stats_with(|s| s.secs_ntt += (t2 - t1).as_secs_f64());
    note_vram(&g);
    drop(d_coef);
    // rung 1: the encoded matrix back to the host, hashed by the CPU code.
    let enc_host = as_fps(dev.dtoh_sync_copy(&d_enc).map_err(|e| format!("enc download: {e}"))?);
    let t3 = Instant::now();
    stats_with(|s| { s.secs_d2h += (t3 - t2).as_secs_f64(); s.bytes_d2h += (rows * nn * 8) as u64; });
    let leaves = crate::pcs::hash_columns(&enc_host, rows, nn);
    let t4 = Instant::now();
    stats_with(|s| s.secs_hash += (t4 - t3).as_secs_f64());
    Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: d_enc, data_host: data.to_vec() }, leaves))
}

/// The opened columns: for each index j, the column's `rows` entries of the encoded matrix.
pub fn dev_columns(dc: &DevCommit, idx: &[usize]) -> Result<Vec<Vec<Fp>>, String> {
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let q = idx.len();
    let rows = dc.rows;
    let nn = 1usize << dc.log_nn;
    let idx32: Vec<i32> = idx.iter().map(|&j| j as i32).collect();
    let d_idx = dev.htod_sync_copy(&idx32).map_err(|e| e.to_string())?;
    let mut d_out = unsafe { dev.alloc::<u64>(rows * q) }.map_err(|e| e.to_string())?;
    let f = dev.get_func(MODULE, "k_gather_cols").ok_or("k_gather_cols missing")?;
    let cfg = LaunchConfig::for_num_elems((rows * q) as u32);
    unsafe { f.launch(cfg, (&dc.enc, &mut d_out, &d_idx, rows as i32, nn as i32, q as i32)) }.map_err(|e| format!("k_gather_cols: {e}"))?;
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
        as_fps(g.dev.dtoh_sync_copy(&dc.enc).map_err(|e| e.to_string())?)
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

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
use cudarc::driver::{sys, CudaDevice, CudaSlice, LaunchAsync, LaunchConfig};
use cudarc::nvrtc::{compile_ptx_with_opts, CompileOptions};
use rayon::prelude::*;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;

const KSRC: &str = include_str!("kernels.cu");
const MODULE: &str = "hlgpu";
const FUNCS: &[&str] = &[
    "k_probe", "k_ntt_p1", "k_ntt_p2", "k_gather_cols", "k_hash_cols",
    "k_sc_round_zc20", "k_sc_round_zc17", "k_reduce_f2", "k_sc_fold", "k_tab_from_fp", "k_tab_from_fp2", "k_eq_table",
    "k_fold_rows",
];
const SC_THREADS: u32 = 256;
const SC_MAX_BLOCKS: u32 = 1024;
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
        let cfg1 = LaunchConfig { grid_dim: (rows as u32 * blocks_per_row, 1, 1), block_dim: (NTT_THREADS, 1, 1), shared_mem_bytes: 0 };
        unsafe { p1.launch(cfg1, (src, &mut *dst, tw, log_n as i32, n_src as i32, scale)) }.map_err(|e| format!("k_ntt_p1: {e}"))?;
        if log_n > NTT_LOG_BLK {
            let p2 = self.dev.get_func(MODULE, "k_ntt_p2").ok_or("k_ntt_p2 missing")?;
            let tiles = 1u32 << (log_n - NTT_LOG_BLK);
            let cfg2 = LaunchConfig { grid_dim: (rows as u32 * tiles, 1, 1), block_dim: (NTT_THREADS, 1, 1), shared_mem_bytes: 0 };
            unsafe { p2.launch(cfg2, (&mut *dst, tw, log_n as i32, scale)) }.map_err(|e| format!("k_ntt_p2: {e}"))?;
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
    let leaves = if host_hash() {
        // rung 1's form (HL_GPU_HOST_HASH=1): the encoded matrix back to the host, hashed by the CPU code.
        let enc_host = as_fps(dev.dtoh_sync_copy(&d_enc).map_err(|e| format!("enc download: {e}"))?);
        let t3 = Instant::now();
        stats_with(|s| { s.secs_d2h += (t3 - t2).as_secs_f64(); s.bytes_d2h += (rows * nn * 8) as u64; });
        let leaves = crate::pcs::hash_columns(&enc_host, rows, nn);
        stats_with(|s| s.secs_hash += t3.elapsed().as_secs_f64());
        leaves
    } else {
        // rung 2: blake3 per column on the device; only the leaves come back.
        let leaves = g.hash_cols(&d_enc, rows, nn)?;
        let t3 = Instant::now();
        stats_with(|s| { s.secs_hash += (t3 - t2).as_secs_f64(); s.bytes_d2h += (nn * 32) as u64; });
        leaves
    };
    Ok((DevCommit { rows, log_n, log_nn, data: d_data, enc: d_enc }, leaves))
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
    let g = gpu().ok_or_else(init_err)?;
    let g = g.lock().unwrap();
    let dev = g.dev.clone();
    let t0 = Instant::now();
    let k = specs.len();
    let l = match &specs[0] {
        TabSpec::FromFp(_, _, n) | TabSpec::FromFp2(_, _, _, n) => *n,
        TabSpec::Eq(r) => 1usize << r.len(),
    };
    assert!(l.is_power_of_two() && k <= 16);
    let nv = l.trailing_zeros() as usize;
    let mut tabs = unsafe { dev.alloc::<u64>(k * l * 2) }.map_err(|e| format!("sc tables alloc ({} MB): {e}", k * l * 16 >> 20))?;
    let f_fp = dev.get_func(MODULE, "k_tab_from_fp").ok_or("k_tab_from_fp missing")?;
    let f_fp2 = dev.get_func(MODULE, "k_tab_from_fp2").ok_or("k_tab_from_fp2 missing")?;
    let f_eq = dev.get_func(MODULE, "k_eq_table").ok_or("k_eq_table missing")?;
    let mut eq_pts: Vec<CudaSlice<u64>> = Vec::new();
    for (t, sp) in specs.iter().enumerate() {
        let mut dst = tabs.slice_mut(t * l * 2..(t + 1) * l * 2);
        let cfg = LaunchConfig::for_num_elems(l as u32);
        match sp {
            TabSpec::FromFp(dc, off, n) => {
                assert_eq!(*n, l);
                let src = dc.data.slice(*off..*off + *n);
                unsafe { f_fp.clone().launch(cfg, (&src, &mut dst, *n as i32)) }.map_err(|e| format!("k_tab_from_fp: {e}"))?;
            }
            TabSpec::FromFp2(dc, ore, oim, n) => {
                assert_eq!(*n, l);
                let re = dc.data.slice(*ore..*ore + *n);
                let im = dc.data.slice(*oim..*oim + *n);
                unsafe { f_fp2.clone().launch(cfg, (&re, &im, &mut dst, *n as i32)) }.map_err(|e| format!("k_tab_from_fp2: {e}"))?;
            }
            TabSpec::Eq(r) => {
                assert_eq!(1usize << r.len(), l);
                let d_r = dev.htod_sync_copy(&as_u64s_f2(r)).map_err(|e| e.to_string())?;
                unsafe { f_eq.clone().launch(cfg, (&d_r, &mut dst, r.len() as i32)) }.map_err(|e| format!("k_eq_table: {e}"))?;
                eq_pts.push(d_r);
            }
        }
    }
    assert!(prm.len() <= 32);
    let mut prm32 = prm.to_vec();
    prm32.resize(32, 0);
    let d_prm = dev.htod_sync_copy(&prm32).map_err(|e| e.to_string())?;
    let mut d_part = unsafe { dev.alloc::<u64>(SC_MAX_BLOCKS as usize * 5 * 2) }.map_err(|e| e.to_string())?;
    let mut d_sums = unsafe { dev.alloc::<u64>(5 * 2) }.map_err(|e| e.to_string())?;
    let (kname, want_k) = if kind == 0 { ("k_sc_round_zc20", 13) } else { ("k_sc_round_zc17", 15) };
    assert_eq!(k, want_k, "zero-check kind {kind} expects {want_k} tables");
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
        let blocks = (((half as u32) + SC_THREADS - 1) / SC_THREADS).clamp(1, SC_MAX_BLOCKS);
        let cfg = LaunchConfig { grid_dim: (blocks, 1, 1), block_dim: (SC_THREADS, 1, 1), shared_mem_bytes: 0 };
        unsafe { f_round.clone().launch(cfg, (&tabs, half as i32, l as i32, &d_prm, &mut d_part)) }.map_err(|e| format!("k_sc_round: {e}"))?;
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
        unsafe { f_fold.clone().launch(cfg_f, (&mut tabs, k as i32, half as i32, l as i32, r.c0.0, r.c1.0)) }.map_err(|e| format!("k_sc_fold: {e}"))?;
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
    unsafe { f.launch(cfg, (&dc.data, &d_rho, &mut d_out, rows as i32, n as i32, k as i32)) }.map_err(|e| format!("k_fold_rows: {e}"))?;
    let h = dev.dtoh_sync_copy(&d_out).map_err(|e| e.to_string())?;
    stats_with(|s| { s.secs_fold += t0.elapsed().as_secs_f64(); s.bytes_d2h += (k * n * 16) as u64; });
    Ok((0..k).map(|g| (0..n).map(|j| Fp2::new(Fp(h[(g * n + j) * 2]), Fp(h[(g * n + j) * 2 + 1]))).collect()).collect())
}

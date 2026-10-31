//! [ZK60-METAL M0/M1, 2026-10-31] The commitment encode-and-hash on the Apple
//! GPU (feature `gpu-metal`, runtime toggle `HL_GPU=1`), for the M3 Ultra Mac
//! Studio. Plan: `docs/zkmatrix-poc/ZK60_METAL_PORT_PLAN.md`.
//!
//! Scope of this rung: zkp-core's `Backend` seam only (`try_commit`,
//! `try_commit_zk`, `try_commit_zk_keyed`). The kernels in
//! `metal_kernels.metal` are compiled from source at first use
//! (`newLibraryWithSource`, so the build needs no Xcode Metal toolchain). Every
//! other device entry point of the CUDA module stays CUDA-only and the prover
//! keeps its CPU bodies for them.
//!
//! DIFFERENTIAL DISCIPLINE: the encoding and the column leaves are exactly the
//! CPU's (canonical Goldilocks values, the same evaluation order, BLAKE3); the
//! store's `fold_rows` / `columns` run the core's own arithmetic on the CPU over
//! the encoding in unified (shared) memory. `tests/zk60_metal_commit.rs`
//! compares every output with the CPU oracle; a decline (`Err`) runs the CPU.

use crate::field::{Fp, Fp2};
use crate::merkle::Digest;
use crate::ntt::NttTables;
use metal::{
    Buffer, CommandQueue, CompileOptions, ComputePipelineState, Device, MTLCommandBufferStatus, MTLResourceOptions, MTLSize,
};
use rayon::prelude::*;
use std::collections::HashMap;
use std::ffi::c_void;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use zkp_core::pcs::PcsParams;

const SRC: &str = include_str!("metal_kernels.metal");
const KERNELS: [&str; 13] = [
    "k_gather_cols",
    "k_fold_partial",
    "k_fold_reduce",
    "k_gl_probe",
    "k_bitrev_copy",
    "k_ntt_stage",
    "k_scale",
    "k_init_plain_bitrev",
    "k_init_zk_bitrev",
    "k_hash_cols",
    "k_ntt_head",
    "k_ntt_tail",
    "k_fold_rows",
];
/// threadgroup tile of the fused NTT (TILE_LOG in the MSL source)
const TILE_LOG: u32 = 11;

struct Ctx {
    device: Device,
    queue: CommandQueue,
    pipes: HashMap<&'static str, ComputePipelineState>,
    /// (forward, inverse) twiddle buffers per NttTables::max_log
    twiddles: Mutex<HashMap<u32, (Buffer, Buffer)>>,
}

static CTX: OnceLock<Result<Ctx, String>> = OnceLock::new();

fn ctx() -> Result<&'static Ctx, String> {
    CTX.get_or_init(|| {
        objc::rc::autoreleasepool(|| {
            let device = Device::system_default().ok_or("no Metal device")?;
            let opts = CompileOptions::new();
            let lib = device.new_library_with_source(SRC, &opts).map_err(|e| format!("metal compile: {e}"))?;
            let mut pipes = HashMap::new();
            for k in KERNELS {
                let f = lib.get_function(k, None).map_err(|e| format!("metal function {k}: {e}"))?;
                let p = device.new_compute_pipeline_state_with_function(&f).map_err(|e| format!("metal pipeline {k}: {e}"))?;
                pipes.insert(k, p);
            }
            let queue = device.new_command_queue();
            Ok(Ctx { device, queue, pipes, twiddles: Mutex::new(HashMap::new()) })
        })
    })
    .as_ref()
    .map_err(|e| e.clone())
}

/// `HL_GPU=1` and a Metal device whose kernels compiled.
pub fn enabled() -> bool {
    std::env::var("HL_GPU").map(|v| v == "1").unwrap_or(false) && ctx().is_ok()
}

/// Human-readable state (printed by the CLIs and recorded in run logs).
pub fn label() -> String {
    if !std::env::var("HL_GPU").map(|v| v == "1").unwrap_or(false) {
        return "gpu: off (built with gpu-metal; HL_GPU unset)".to_string();
    }
    match ctx() {
        Ok(c) => format!(
            "gpu: ON (Metal, {}, unified memory, max buffer {} GiB; commitments on the device)",
            c.device.name(),
            c.device.max_buffer_length() >> 30
        ),
        Err(e) => format!("gpu: off (Metal unavailable: {e})"),
    }
}

// --------------------------------------------------------------- statistics

static SECS_COMMIT_NS: AtomicU64 = AtomicU64::new(0);
static N_COMMITS: AtomicU64 = AtomicU64::new(0);
static BYTES_ENCODED: AtomicU64 = AtomicU64::new(0);

/// (commitments made on the device, their summed wall seconds, encoded bytes)
pub fn stats() -> (u64, f64, u64) {
    (
        N_COMMITS.load(Ordering::Relaxed),
        SECS_COMMIT_NS.load(Ordering::Relaxed) as f64 * 1e-9,
        BYTES_ENCODED.load(Ordering::Relaxed),
    )
}

// ---------------------------------------------------------------- arguments
// #[repr(C)] mirrors of the MSL structs (same field order, natural alignment).

#[repr(C)]
struct ProbeArgs {
    count: u64,
}
#[repr(C)]
struct CopyRevArgs {
    rows: u64,
    log_n: u32,
    pad0: u32,
}
#[repr(C)]
struct StageArgs {
    rows: u64,
    log_n: u32,
    log_len: u32,
    stride: u64,
}
#[repr(C)]
struct ScaleArgs {
    rows: u64,
    log_n: u32,
    pad0: u32,
    s: u64,
}
#[repr(C)]
struct InitArgs {
    rows: u64,
    log_n: u32,
    log_nn: u32,
    q: u64,
}
#[repr(C)]
struct HeadArgs {
    rows: u64,
    log_n: u32,
    log_src: u32,
    mode: u32,
    max_log: u32,
    q: u64,
    scale: u64,
    apply_scale: u32,
    pad0: u32,
}
#[repr(C)]
struct TailArgs {
    rows: u64,
    log_n: u32,
    max_log: u32,
    scale: u64,
    apply_scale: u32,
    pad0: u32,
}

/// Head input modes (k_ntt_head): a natural-order copy, the plain RS row, the hiding row.
const MODE_COPY: u32 = 0;
const MODE_PLAIN: u32 = 1;
const MODE_ZK: u32 = 2;

/// The fused two-pass transform: HEAD (gather + stages 1..min(log_n, 11)) and,
/// for log_n > 11, TAIL (the remaining stages). `scale` multiplies the final
/// outputs (the inverse's 1/n). `src`, `pads`, `pows` are read by HEAD only.
#[allow(clippy::too_many_arguments)]
fn encode_fused(
    c: &Ctx, enc: &metal::ComputeCommandEncoderRef, src: &Buffer, pads: Option<&Buffer>, pows: Option<&Buffer>, dst: &Buffer,
    tw: &Buffer, rows: u64, log_n: u32, log_src: u32, mode: u32, q: u64, max_log: u32, scale: Option<u64>,
) {
    let l = log_n.min(TILE_LOG);
    let tile = 1u64 << l;
    let head = &c.pipes["k_ntt_head"];
    enc.set_compute_pipeline_state(head);
    enc.set_buffer(0, Some(src), 0);
    enc.set_buffer(1, Some(pads.unwrap_or(src)), 0);
    enc.set_buffer(2, Some(pows.unwrap_or(src)), 0);
    enc.set_buffer(3, Some(dst), 0);
    enc.set_buffer(4, Some(tw), 0);
    let head_scales = scale.is_some() && log_n <= TILE_LOG;
    set_args(
        enc,
        5,
        &HeadArgs { rows, log_n, log_src, mode, max_log, q, scale: scale.unwrap_or(1), apply_scale: head_scales as u32, pad0: 0 },
    );
    let th = (tile / 2).max(1).min(head.max_total_threads_per_threadgroup());
    enc.dispatch_thread_groups(MTLSize::new((1u64 << log_n) / tile, rows, 1), MTLSize::new(th, 1, 1));
    if log_n > TILE_LOG {
        let tail = &c.pipes["k_ntt_tail"];
        enc.set_compute_pipeline_state(tail);
        enc.set_buffer(0, Some(dst), 0);
        enc.set_buffer(1, Some(tw), 0);
        set_args(enc, 2, &TailArgs { rows, log_n, max_log, scale: scale.unwrap_or(1), apply_scale: scale.is_some() as u32, pad0: 0 });
        let th = (1u64 << (TILE_LOG - 1)).min(tail.max_total_threads_per_threadgroup());
        enc.dispatch_thread_groups(MTLSize::new(1u64 << (log_n - TILE_LOG), rows, 1), MTLSize::new(th, 1, 1));
    }
}

#[repr(C)]
struct HashArgs {
    rows: u64,
    nn: u64,
    keyed: u32,
    pad0: u32,
    key: [u32; 8],
}

fn shared_buffer(c: &Ctx, bytes: u64) -> Result<Buffer, String> {
    if bytes == 0 {
        return Err("metal: zero-length buffer".into());
    }
    if bytes > c.device.max_buffer_length() {
        return Err(format!("metal: buffer of {bytes} B exceeds the device maximum {} B", c.device.max_buffer_length()));
    }
    Ok(c.device.new_buffer(bytes, MTLResourceOptions::StorageModeShared))
}

fn upload(c: &Ctx, vals: &[Fp]) -> Result<Buffer, String> {
    let buf = shared_buffer(c, (vals.len() * 8) as u64)?;
    // SAFETY: the buffer is at least vals.len() * 8 bytes of shared, CPU-visible
    // memory and Fp is repr(transparent) over u64.
    unsafe { std::ptr::copy_nonoverlapping(vals.as_ptr() as *const u64, buf.contents() as *mut u64, vals.len()) };
    Ok(buf)
}

fn as_u64s(buf: &Buffer, len: usize) -> &[u64] {
    // SAFETY: callers pass len <= buffer length / 8; the buffer lives as long as
    // the borrow and the GPU no longer writes it (its command buffer completed).
    unsafe { std::slice::from_raw_parts(buf.contents() as *const u64, len) }
}

fn twiddle_buffers(c: &Ctx, ntt: &NttTables) -> Result<(Buffer, Buffer), String> {
    let mut map = c.twiddles.lock().map_err(|_| "metal: twiddle cache poisoned")?;
    if let Some((f, i)) = map.get(&ntt.max_log) {
        return Ok((f.clone(), i.clone()));
    }
    let (fw, inv) = ntt.twiddle_tables();
    let f = upload(c, fw)?;
    let i = upload(c, inv)?;
    map.insert(ntt.max_log, (f.clone(), i.clone()));
    Ok((f, i))
}

/// One command buffer, one serial compute encoder (each dispatch sees the
/// previous one's writes); `encode` records the dispatches.
fn run(c: &Ctx, encode: impl FnOnce(&metal::ComputeCommandEncoderRef) -> Result<(), String>) -> Result<(), String> {
    let cb = c.queue.new_command_buffer();
    let enc = cb.new_compute_command_encoder();
    let r = encode(enc);
    enc.end_encoding();
    r?;
    cb.commit();
    cb.wait_until_completed();
    match cb.status() {
        MTLCommandBufferStatus::Completed => Ok(()),
        s => Err(format!("metal: command buffer ended {s:?}")),
    }
}

fn set_args<T>(enc: &metal::ComputeCommandEncoderRef, index: u64, args: &T) {
    enc.set_bytes(index, std::mem::size_of::<T>() as u64, args as *const T as *const c_void);
}

fn dispatch_2d(c: &Ctx, enc: &metal::ComputeCommandEncoderRef, kernel: &str, w: u64, h: u64) {
    let p = &c.pipes[kernel];
    enc.set_compute_pipeline_state(p);
    let tg = p.max_total_threads_per_threadgroup().min(256).min(w.max(1));
    enc.dispatch_threads(MTLSize::new(w, h, 1), MTLSize::new(tg, 1, 1));
}

/// The NTT stages of `ntt.rs::transform` on `a` (rows rows of 2^log_n),
/// whose rows are ALREADY in bit-reversed order.
fn encode_stages(c: &Ctx, enc: &metal::ComputeCommandEncoderRef, a: &Buffer, tw: &Buffer, rows: u64, log_n: u32, max_log: u32) {
    for log_len in 1..=log_n {
        enc.set_buffer(0, Some(a), 0);
        enc.set_buffer(1, Some(tw), 0);
        let stride = 1u64 << (max_log - log_len);
        set_args(enc, 2, &StageArgs { rows, log_n, log_len, stride });
        dispatch_2d(c, enc, "k_ntt_stage", 1u64 << (log_n - 1), rows);
    }
}

// ------------------------------------------------------------------- probe

/// M0: (a+b, a-b, a*b) for each pair, on the device.
pub fn probe_field(a: &[Fp], b: &[Fp]) -> Result<Vec<(Fp, Fp, Fp)>, String> {
    assert_eq!(a.len(), b.len());
    let c = ctx()?;
    objc::rc::autoreleasepool(|| {
        let ab = upload(c, a)?;
        let bb = upload(c, b)?;
        let out = shared_buffer(c, (a.len() * 24) as u64)?;
        run(c, |enc| {
            enc.set_buffer(0, Some(&ab), 0);
            enc.set_buffer(1, Some(&bb), 0);
            enc.set_buffer(2, Some(&out), 0);
            set_args(enc, 3, &ProbeArgs { count: a.len() as u64 });
            dispatch_2d(c, enc, "k_gl_probe", a.len() as u64, 1);
            Ok(())
        })?;
        let v = as_u64s(&out, a.len() * 3);
        Ok((0..a.len()).map(|i| (Fp(v[3 * i]), Fp(v[3 * i + 1]), Fp(v[3 * i + 2]))).collect())
    })
}

// ------------------------------------------------------------------- store

/// The device-made encoding (rows x nn, row-major) in shared memory, plus, for
/// the hiding form, the message rows the opening folds (`fold_rows_multi_zk`
/// folds the DATA, not the coset encoding).
pub struct MetalCommit {
    rows: usize,
    n: usize,
    nn: usize,
    ir: usize,
    enc: Buffer,
    /// Some(rows x n data) for the hiding form; None for the plain form, whose
    /// fold reads the systematic positions of the encoding.
    data: Option<Buffer>,
}

impl MetalCommit {
    /// `rho^T M` over the systematic data, the same arithmetic as zkp-core's
    /// `fold_rows_host` (only the summation's chunking is the same too, so the
    /// values are identical; field addition is exact either way).
    pub fn fold_rows(&self, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String> {
        for r in rhos {
            if r.len() < self.rows {
                return Err(format!("metal fold: rho of {} entries for {} rows", r.len(), self.rows));
            }
        }
        let (buf, nn, ir) = match &self.data {
            Some(d) => (d, self.n, 1usize),
            None => (&self.enc, self.nn, self.ir),
        };
        // The host fold over the shared buffer is the default: measured on the
        // 8B T128 block it beats the device fold, whose per-call overhead the
        // core's chunks of four rho vectors multiply. HL_METAL_DEVICE_FOLD=1
        // selects the device kernels (equal values; kept for larger shapes).
        if std::env::var("HL_METAL_DEVICE_FOLD").map(|v| v == "1").unwrap_or(false) {
            return fold_rows_device(buf, self.rows, self.n, nn, ir, rhos);
        }
        let t = std::time::Instant::now();
        let src = as_u64s(buf, self.rows * nn);
        let out = fold_rows_host(src, self.rows, self.n, nn, ir, rhos);
        if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
            eprintln!("[ZK60-METAL] store fold: {} rho x {} rows x {} cols ({}) in {:.4} s", rhos.len(), self.rows, self.n, if self.data.is_some() { "zk data" } else { "systematic" }, t.elapsed().as_secs_f64());
        }
        Ok(out)
    }

    /// The encoded columns at `idx` (each `rows` entries), in the order of `idx`.
    pub fn columns(&self, idx: &[usize]) -> Result<Vec<Vec<Fp>>, String> {
        let enc = as_u64s(&self.enc, self.rows * self.nn);
        if let Some(&j) = idx.iter().find(|&&j| j >= self.nn) {
            return Err(format!("metal columns: index {j} >= {}", self.nn));
        }
        let t = std::time::Instant::now();
        let out: Vec<Vec<Fp>> = if std::env::var("HL_METAL_HOST_GATHER").map(|v| v == "1").unwrap_or(false) {
            // the host gather (strided reads across the whole encoding)
            idx.par_iter().map(|&j| (0..self.rows).map(|i| Fp(enc[i * self.nn + j])).collect()).collect()
        } else {
            gather_columns_device(&self.enc, self.rows, self.nn, idx)?
        };
        if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
            eprintln!("[ZK60-METAL] store columns: {} x {} rows in {:.4} s", idx.len(), self.rows, t.elapsed().as_secs_f64());
        }
        Ok(out)
    }
}

#[repr(C)]
struct FoldArgs {
    rows: u64,
    n: u64,
    nn: u64,
    ir: u64,
    k: u32,
    pad0: u32,
}

#[repr(C)]
struct FoldPartArgs {
    rows: u64,
    n: u64,
    nn: u64,
    ir: u64,
    rows_per_block: u64,
    k: u32,
    blocks: u32,
}

/// `fold_rows_host` on the device (k_fold_partial over row blocks, then
/// k_fold_reduce), eight rho vectors per dispatch.
fn fold_rows_device(src: &Buffer, rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String> {
    let c = ctx()?;
    let mut out_all = Vec::with_capacity(rhos.len());
    objc::rc::autoreleasepool(|| {
        for chunk in rhos.chunks(8) {
            let k = chunk.len();
            let mut flat = Vec::with_capacity(k * rows * 2);
            for r in chunk {
                for v in &r[..rows] {
                    flat.push(Fp(v.c0.0));
                    flat.push(Fp(v.c1.0));
                }
            }
            let rb = upload(c, &flat)?;
            let ob = shared_buffer(c, (k * n * 16) as u64)?;
            // enough row blocks for ~2M threads, at least 16 rows each
            let blocks = ((2usize << 20) / n.max(1)).clamp(1, rows.div_ceil(16).max(1)).min(rows.max(1));
            let rpb = rows.div_ceil(blocks);
            let blocks = rows.div_ceil(rpb);
            let pa = FoldPartArgs { rows: rows as u64, n: n as u64, nn: nn as u64, ir: ir as u64, rows_per_block: rpb as u64, k: k as u32, blocks: blocks as u32 };
            let part = shared_buffer(c, (blocks * k * n * 16) as u64)?;
            let _ = FoldArgs { rows: 0, n: 0, nn: 0, ir: 0, k: 0, pad0: 0 }; // the single-pass k_fold_rows stays compiled as a reference
            run(c, |enc| {
                enc.set_buffer(0, Some(src), 0);
                enc.set_buffer(1, Some(&rb), 0);
                enc.set_buffer(2, Some(&part), 0);
                set_args(enc, 3, &pa);
                dispatch_2d(c, enc, "k_fold_partial", n as u64, blocks as u64);
                enc.set_buffer(0, Some(&part), 0);
                enc.set_buffer(1, Some(&ob), 0);
                set_args(enc, 2, &pa);
                dispatch_2d(c, enc, "k_fold_reduce", n as u64, k as u64);
                Ok(())
            })?;
            let o = as_u64s(&ob, k * n * 2);
            for g in 0..k {
                out_all.push((0..n).map(|j| Fp2::new(Fp(o[(g * n + j) * 2]), Fp(o[(g * n + j) * 2 + 1]))).collect());
            }
        }
        Ok(out_all)
    })
}

#[repr(C)]
struct GatherArgs {
    rows: u64,
    nn: u64,
    nidx: u64,
}

/// The opened columns on the device (k_gather_cols): a scattered read is cheap
/// on the GPU, while the host's strided walk over a multi-GB encoding pays a TLB
/// miss per element.
fn gather_columns_device(enc: &Buffer, rows: usize, nn: usize, idx: &[usize]) -> Result<Vec<Vec<Fp>>, String> {
    if idx.is_empty() {
        return Ok(Vec::new());
    }
    let c = ctx()?;
    objc::rc::autoreleasepool(|| {
        let ib: Vec<Fp> = idx.iter().map(|&j| Fp(j as u64)).collect();
        let ibuf = upload(c, &ib)?;
        let ob = shared_buffer(c, (idx.len() * rows * 8) as u64)?;
        run(c, |e| {
            e.set_buffer(0, Some(enc), 0);
            e.set_buffer(1, Some(&ibuf), 0);
            e.set_buffer(2, Some(&ob), 0);
            set_args(e, 3, &GatherArgs { rows: rows as u64, nn: nn as u64, nidx: idx.len() as u64 });
            dispatch_2d(c, e, "k_gather_cols", idx.len() as u64, rows as u64);
            Ok(())
        })?;
        let o = as_u64s(&ob, idx.len() * rows);
        Ok(o.chunks_exact(rows).map(|col| col.iter().map(|&v| Fp(v)).collect()).collect())
    })
}

/// zkp-core `pcs::fold_rows_host`, over raw canonical u64 values.
fn fold_rows_host(src: &[u64], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    let k = rhos.len();
    let chunk = 512usize.min(n);
    let n_chunks = (n + chunk - 1) / chunk;
    let parts: Vec<Vec<Vec<Fp2>>> = (0..n_chunks)
        .into_par_iter()
        .map(|ci| {
            let c0 = ci * chunk;
            let w = chunk.min(n - c0);
            let mut out = vec![vec![Fp2::ZERO; w]; k];
            for i in 0..rows {
                let row = &src[i * nn..(i + 1) * nn];
                for (g, rho) in rhos.iter().enumerate() {
                    let r = rho[i];
                    if r.is_zero() {
                        continue;
                    }
                    let o = &mut out[g];
                    for j in 0..w {
                        let v = Fp(row[(c0 + j) * ir]);
                        if v.is_zero() {
                            continue;
                        }
                        o[j] = o[j].add(r.mul_base(v));
                    }
                }
            }
            out
        })
        .collect();
    let mut out = vec![vec![Fp2::ZERO; n]; k];
    for (ci, p) in parts.into_iter().enumerate() {
        let c0 = ci * chunk;
        for g in 0..k {
            for (j, v) in p[g].iter().enumerate() {
                out[g][c0 + j] = *v;
            }
        }
    }
    out
}

// ---------------------------------------------------------------- commits

enum Init<'a> {
    Plain,
    Zk { pads: &'a [Fp], pows: &'a [Fp], q: usize },
}

fn check_shape(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Result<(usize, usize, usize), String> {
    let n = params.cols();
    let nn = params.enc_cols();
    if data.is_empty() || data.len() % n != 0 {
        return Err(format!("metal: data length {} not a multiple of n = {n}", data.len()));
    }
    if !nn.is_power_of_two() || nn % n != 0 {
        return Err(format!("metal: encoded width {nn} is not a power-of-two multiple of {n}"));
    }
    let log_nn = nn.trailing_zeros();
    if log_nn > ntt.max_log || log_nn > 31 {
        return Err(format!("metal: encoded width 2^{log_nn} exceeds the NTT tables (2^{})", ntt.max_log));
    }
    Ok((n, nn, data.len() / n))
}

fn commit_impl(
    params: &PcsParams, data: &[Fp], ntt: &NttTables, init: Init, key: Option<&[u8; 32]>,
) -> Result<(MetalCommit, Vec<Digest>), String> {
    let t0 = std::time::Instant::now();
    let c = ctx()?;
    let (n, nn, rows) = check_shape(params, data, ntt)?;
    let (log_n, log_nn) = (n.trailing_zeros(), nn.trailing_zeros());
    let rows64 = rows as u64;
    let timing = std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false);
    objc::rc::autoreleasepool(|| {
        let (tw_f, tw_i) = twiddle_buffers(c, ntt)?;
        let d = upload(c, data)?;
        let t = shared_buffer(c, (rows * n * 8) as u64)?;
        let e = shared_buffer(c, (rows * nn * 8) as u64)?;
        let leaves_buf = shared_buffer(c, (nn * 32) as u64)?;
        let t_setup = t0.elapsed().as_secs_f64();
        let zk_bufs = match &init {
            Init::Plain => None,
            Init::Zk { pads, pows, q } => {
                if pads.len() != rows * q || pows.len() != nn || n + q > nn {
                    return Err(format!("metal zk: pads {} / pows {} / q {q} do not fit rows {rows} n {n} nn {nn}", pads.len(), pows.len()));
                }
                Some((upload(c, pads)?, upload(c, pows)?, *q))
            }
        };
        let ninv = Fp::new(n as u64).inv();
        let mut kw = [0u32; 8];
        if let Some(k) = key {
            for (i, w) in kw.iter_mut().enumerate() {
                *w = u32::from_le_bytes([k[4 * i], k[4 * i + 1], k[4 * i + 2], k[4 * i + 3]]);
            }
        }
        let staged = std::env::var("HL_METAL_STAGED").map(|v| v == "1").unwrap_or(false);
        run(c, |enc| {
            if !staged {
                // M2: two fused passes per transform (see metal_kernels.metal)
                encode_fused(c, enc, &d, None, None, &t, &tw_i, rows64, log_n, log_n, MODE_COPY, 0, ntt.max_log, Some(ninv.0));
                match &zk_bufs {
                    None => encode_fused(c, enc, &t, None, None, &e, &tw_f, rows64, log_nn, log_n, MODE_PLAIN, 0, ntt.max_log, None),
                    Some((pb, wb, q)) => {
                        encode_fused(c, enc, &t, Some(pb), Some(wb), &e, &tw_f, rows64, log_nn, log_n, MODE_ZK, *q as u64, ntt.max_log, None)
                    }
                }
                enc.set_buffer(0, Some(&e), 0);
                enc.set_buffer(1, Some(&leaves_buf), 0);
                set_args(enc, 2, &HashArgs { rows: rows64, nn: nn as u64, keyed: key.is_some() as u32, pad0: 0, key: kw });
                dispatch_2d(c, enc, "k_hash_cols", nn as u64, 1);
                return Ok(());
            }
            // M1 reference path (HL_METAL_STAGED=1): one dispatch per stage
            // inverse transform of every row: bit-reverse D into T, stages, x 1/n
            enc.set_buffer(0, Some(&d), 0);
            enc.set_buffer(1, Some(&t), 0);
            set_args(enc, 2, &CopyRevArgs { rows: rows64, log_n, pad0: 0 });
            dispatch_2d(c, enc, "k_bitrev_copy", n as u64, rows64);
            encode_stages(c, enc, &t, &tw_i, rows64, log_n, ntt.max_log);
            enc.set_buffer(0, Some(&t), 0);
            set_args(enc, 1, &ScaleArgs { rows: rows64, log_n, pad0: 0, s: ninv.0 });
            dispatch_2d(c, enc, "k_scale", n as u64, rows64);
            // the forward transform's input, written bit-reversed into E
            match &zk_bufs {
                None => {
                    enc.set_buffer(0, Some(&t), 0);
                    enc.set_buffer(1, Some(&e), 0);
                    set_args(enc, 2, &InitArgs { rows: rows64, log_n, log_nn, q: 0 });
                    dispatch_2d(c, enc, "k_init_plain_bitrev", nn as u64, rows64);
                }
                Some((pb, wb, q)) => {
                    enc.set_buffer(0, Some(&t), 0);
                    enc.set_buffer(1, Some(pb), 0);
                    enc.set_buffer(2, Some(wb), 0);
                    enc.set_buffer(3, Some(&e), 0);
                    set_args(enc, 4, &InitArgs { rows: rows64, log_n, log_nn, q: *q as u64 });
                    dispatch_2d(c, enc, "k_init_zk_bitrev", nn as u64, rows64);
                }
            }
            encode_stages(c, enc, &e, &tw_f, rows64, log_nn, ntt.max_log);
            // the column leaves
            enc.set_buffer(0, Some(&e), 0);
            enc.set_buffer(1, Some(&leaves_buf), 0);
            set_args(enc, 2, &HashArgs { rows: rows64, nn: nn as u64, keyed: key.is_some() as u32, pad0: 0, key: kw });
            dispatch_2d(c, enc, "k_hash_cols", nn as u64, 1);
            Ok(())
        })?;
        let t_gpu = t0.elapsed().as_secs_f64();
        if timing {
            // DIAGNOSTIC ONLY: the same GPU parts re-run one by one on SCRATCH
            // buffers (never on `e` or `leaves_buf`, which the result reads)
            let t2 = shared_buffer(c, (rows * n * 8) as u64)?;
            let e2 = shared_buffer(c, (rows * nn * 8) as u64)?;
            let l2 = shared_buffer(c, (nn * 32) as u64)?;
            let part = |f: &dyn Fn(&metal::ComputeCommandEncoderRef)| -> Result<f64, String> {
                let s = std::time::Instant::now();
                run(c, |enc| {
                    f(enc);
                    Ok(())
                })?;
                Ok(s.elapsed().as_secs_f64())
            };
            let inv = part(&|enc| {
                encode_fused(c, enc, &d, None, None, &t2, &tw_i, rows64, log_n, log_n, MODE_COPY, 0, ntt.max_log, Some(ninv.0));
            })?;
            let init = 0.0f64; // fused into the forward head on the default path
            let fwd = part(&|enc| {
                encode_fused(c, enc, &t2, None, None, &e2, &tw_f, rows64, log_nn, log_n, MODE_PLAIN, 0, ntt.max_log, None);
            })?;
            let hash = part(&|enc| {
                enc.set_buffer(0, Some(&e2), 0);
                enc.set_buffer(1, Some(&l2), 0);
                set_args(enc, 2, &HashArgs { rows: rows64, nn: nn as u64, keyed: key.is_some() as u32, pad0: 0, key: kw });
                dispatch_2d(c, enc, "k_hash_cols", nn as u64, 1);
            })?;
            eprintln!(
                "[ZK60-METAL] commit {rows} x 2^{log_n} -> 2^{log_nn}: setup {t_setup:.3} s, gpu total {:.3} s (inverse {inv:.3}, init {init:.3}, forward {fwd:.3}, hash {hash:.3})",
                t_gpu - t_setup
            );
        }
        // SAFETY: nn * 32 bytes, completed command buffer
        let raw = unsafe { std::slice::from_raw_parts(leaves_buf.contents() as *const u8, nn * 32) };
        let leaves: Vec<Digest> = raw.chunks_exact(32).map(|ch| ch.try_into().expect("32-byte leaf")).collect();
        let store = MetalCommit {
            rows,
            n,
            nn,
            ir: params.inv_rate,
            enc: e,
            data: if zk_bufs.is_some() { Some(d) } else { None },
        };
        N_COMMITS.fetch_add(1, Ordering::Relaxed);
        SECS_COMMIT_NS.fetch_add(t0.elapsed().as_nanos() as u64, Ordering::Relaxed);
        BYTES_ENCODED.fetch_add((rows * nn * 8) as u64, Ordering::Relaxed);
        Ok((store, leaves))
    })
}

/// `pcs::commit`'s encode-and-hash on the device.
pub fn metal_commit(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Result<(MetalCommit, Vec<Digest>), String> {
    commit_impl(params, data, ntt, Init::Plain, None)
}

/// `pcs::commit_zk*`'s coset encode-and-hash on the device (UNSALTED leaves;
/// the core salts them), unkeyed (`key = None`) or under a column key.
pub fn metal_commit_zk(
    params: &PcsParams, data: &[Fp], pads: &[Fp], pows: &[Fp], ntt: &NttTables, key: Option<&[u8; 32]>,
) -> Result<(MetalCommit, Vec<Digest>), String> {
    let q = if data.is_empty() { 0 } else { pads.len() / (data.len() / params.cols()).max(1) };
    if q == 0 {
        return Err("metal zk: no pad symbols".into());
    }
    commit_impl(params, data, ntt, Init::Zk { pads, pows, q }, key)
}

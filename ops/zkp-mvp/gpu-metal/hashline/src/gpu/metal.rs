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
const KERNELS: [&str; 14] = [
    "k_fold_tables",
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
    /// [M3] compiled sumcheck round kernels, one per generated slot polynomial
    sc_pipes: Mutex<HashMap<String, ComputePipelineState>>,
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
            Ok(Ctx { device, queue, pipes, twiddles: Mutex::new(HashMap::new()), sc_pipes: Mutex::new(HashMap::new()) })
        })
    })
    .as_ref()
    .map_err(|e| e.clone())
}

/// `HL_GPU=1` and a Metal device whose kernels compiled.
///
/// FAILS CLOSED under `HL_GPU_REQUIRED=1`: a requested device that does not
/// initialise (no device, a kernel-library compile error) panics here instead
/// of silently routing every call to the CPU. Found 2026-10-31: a compile
/// error left a whole "metal" golden arm on the CPU with REQUIRED set.
pub fn enabled() -> bool {
    if !std::env::var("HL_GPU").map(|v| v == "1").unwrap_or(false) {
        return false;
    }
    match ctx() {
        Ok(_) => true,
        Err(e) => {
            if super::required() {
                panic!("[ZK60-METAL] HL_GPU=1 and HL_GPU_REQUIRED=1 but the Metal device is unavailable: {e}");
            }
            false
        }
    }
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

/// [M4f] A shared buffer that goes back to a process-wide pool when dropped.
///
/// **Why.** The first touch of a FRESH shared Metal buffer is slow on this Mac:
/// 74-78 ms to write 973 MB the first time, 5 ms the second (2.4 GB: 0.17-0.20
/// s against 0.011 s; `results/zk60_metal_20261031/README.md`, M4f). A block
/// allocates gigabytes of them (the commitments' data, row and encoded
/// matrices, the zero-checks' tables), and the next block asks for the same
/// sizes again, so reusing them skips that cost.
///
/// **Why it cannot change a byte.** A pooled buffer comes back with its last
/// contents, so every user must write all it later reads: the upload copies
/// every word, the NTT head writes every element of its rows (the padding as
/// explicit zeros), the hash, gather and fold kernels write every output, the
/// sumcheck tables are written whole, and each round's kernel writes the
/// partial of every thread the host then reads. Nothing reads a buffer it has
/// not written; the seeded byte gates and the golden gate hold this.
/// `HL_METAL_POOL=0` turns the pool off; `HL_METAL_POOL_GIB` caps what it keeps
/// (default 48 GiB of the 256).
pub struct PBuf(Option<Buffer>);

impl std::ops::Deref for PBuf {
    type Target = Buffer;
    fn deref(&self) -> &Buffer {
        self.0.as_ref().expect("metal: pooled buffer taken")
    }
}

impl PBuf {
    /// keep the buffer outside the pool (a cache that lives for the process)
    fn keep(mut self) -> Buffer {
        self.0.take().expect("metal: pooled buffer taken")
    }
}

impl Drop for PBuf {
    fn drop(&mut self) {
        if let Some(b) = self.0.take() {
            pool_put(b);
        }
    }
}

/// free buffers and the bytes they hold
static POOL: Mutex<(Vec<Buffer>, u64)> = Mutex::new((Vec::new(), 0));
static POOL_HITS: AtomicU64 = AtomicU64::new(0);
static POOL_MISSES: AtomicU64 = AtomicU64::new(0);

fn pool_on() -> bool {
    static ON: OnceLock<bool> = OnceLock::new();
    *ON.get_or_init(|| std::env::var("HL_METAL_POOL").map(|v| v != "0").unwrap_or(true))
}

fn pool_cap() -> u64 {
    static CAP: OnceLock<u64> = OnceLock::new();
    *CAP.get_or_init(|| std::env::var("HL_METAL_POOL_GIB").ok().and_then(|v| v.parse::<u64>().ok()).unwrap_or(48) << 30)
}

/// the smallest free buffer of at least `bytes` and at most 1.25x that
fn pool_take(bytes: u64) -> Option<Buffer> {
    if !pool_on() {
        return None;
    }
    let mut g = POOL.lock().ok()?;
    let best = g.0.iter().enumerate().filter(|(_, b)| b.length() >= bytes && b.length() <= bytes + bytes / 4).min_by_key(|(_, b)| b.length()).map(|(i, _)| i)?;
    let b = g.0.swap_remove(best);
    g.1 -= b.length();
    Some(b)
}

fn pool_put(b: Buffer) {
    if !pool_on() {
        return;
    }
    let Ok(mut g) = POOL.lock() else { return };
    if g.1 + b.length() <= pool_cap() {
        g.1 += b.length();
        g.0.push(b);
    }
}

/// (pool hits, misses) since the process started (diagnostics)
pub fn pool_stats() -> (u64, u64) {
    (POOL_HITS.load(Ordering::Relaxed), POOL_MISSES.load(Ordering::Relaxed))
}

fn shared_buffer(c: &Ctx, bytes: u64) -> Result<PBuf, String> {
    if bytes == 0 {
        return Err("metal: zero-length buffer".into());
    }
    if bytes > c.device.max_buffer_length() {
        return Err(format!("metal: buffer of {bytes} B exceeds the device maximum {} B", c.device.max_buffer_length()));
    }
    if let Some(b) = pool_take(bytes) {
        POOL_HITS.fetch_add(1, Ordering::Relaxed);
        return Ok(PBuf(Some(b)));
    }
    POOL_MISSES.fetch_add(1, Ordering::Relaxed);
    Ok(PBuf(Some(c.device.new_buffer(bytes, MTLResourceOptions::StorageModeShared))))
}

fn upload(c: &Ctx, vals: &[Fp]) -> Result<PBuf, String> {
    let buf = shared_buffer(c, (vals.len() * 8) as u64)?;
    // SAFETY: the buffer is at least vals.len() * 8 bytes of shared, CPU-visible
    // memory, not yet used by the GPU, and Fp is repr(transparent) over u64.
    let dst = unsafe { std::slice::from_raw_parts_mut(buf.contents() as *mut u64, vals.len()) };
    // [M4d] large uploads in parallel: the copy of a block's A matrix (600 MB at
    // the Shieldstral shape) also takes the fresh buffer's first-touch faults
    const UPLOAD_PAR_MIN: usize = 1 << 20;
    const UPLOAD_CHUNK: usize = 1 << 17;
    let src: &[u64] = unsafe { std::slice::from_raw_parts(vals.as_ptr() as *const u64, vals.len()) };
    if vals.len() < UPLOAD_PAR_MIN {
        dst.copy_from_slice(src);
    } else {
        dst.par_chunks_mut(UPLOAD_CHUNK).zip(src.par_chunks(UPLOAD_CHUNK)).for_each(|(d, s)| d.copy_from_slice(s));
    }
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
    let f = upload(c, fw)?.keep();
    let i = upload(c, inv)?.keep();
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
    wait_done(cb);
    match cb.status() {
        MTLCommandBufferStatus::Completed => Ok(()),
        s => Err(format!("metal: command buffer ended {s:?}")),
    }
}

/// **[M5d] Wait for a committed command buffer by spinning on its status**
/// instead of `waitUntilCompleted`, whose thread sleep and wake-up cost
/// hundreds of microseconds per call. A block makes about 190 device sumcheck
/// rounds, each ending in one such wait (researcher H113). Only the waiting
/// changes: the same command buffer, the same results. `HL_METAL_SPIN=0`
/// restores the blocking wait.
fn wait_done(cb: &metal::CommandBufferRef) {
    static SPIN: OnceLock<bool> = OnceLock::new();
    if !*SPIN.get_or_init(|| std::env::var("HL_METAL_SPIN").map(|v| v != "0").unwrap_or(true)) {
        cb.wait_until_completed();
        return;
    }
    loop {
        match cb.status() {
            MTLCommandBufferStatus::Completed | MTLCommandBufferStatus::Error => return,
            _ => std::hint::spin_loop(),
        }
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
    enc: PBuf,
    /// Some(rows x n data) for the hiding form; None for the plain form, whose
    /// fold reads the systematic positions of the encoding.
    data: Option<PBuf>,
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

// ------------------------------------------------------- M3: sumcheck rounds

/// The Goldilocks section of `metal_kernels.metal` (everything before the
/// field probe): the SAME field code the commitment kernels use and M0 checks.
fn gl_header() -> &'static str {
    let end = SRC.find("// ------------------------------------------------------------- field probe").expect("metal source layout");
    &SRC[..end]
}

const SC_PRELUDE: &str = r#"
inline ulong gl_neg_sc(ulong a) { return a == 0UL ? 0UL : GL_P - a; }
struct fp2 { ulong c0; ulong c1; };
inline fp2 f2(ulong a, ulong b) { fp2 r; r.c0 = a; r.c1 = b; return r; }
inline fp2 f2_add(fp2 a, fp2 b) { return f2(gl_add(a.c0, b.c0), gl_add(a.c1, b.c1)); }
inline fp2 f2_sub(fp2 a, fp2 b) { return f2(gl_sub(a.c0, b.c0), gl_sub(a.c1, b.c1)); }
inline fp2 f2_neg(fp2 a) { return f2(gl_neg_sc(a.c0), gl_neg_sc(a.c1)); }
// Fp2::mul: (a0 + a1 u)(b0 + b1 u), u^2 = 7. [M4e] Karatsuba: three base
// products, the cross term as (a0 + a1)(b0 + b1) - ac - bd, and 7 bd as
// 8 bd - bd by doublings: the same field elements as Fp2::mul (exact
// arithmetic, every operation returns the canonical word), two products fewer.
inline ulong gl_mul7(ulong x) { ulong x2 = gl_add(x, x); ulong x4 = gl_add(x2, x2); return gl_sub(gl_add(x4, x4), x); }
inline fp2 f2_mul(fp2 a, fp2 b) {
    ulong ac = gl_mul(a.c0, b.c0), bd = gl_mul(a.c1, b.c1);
    ulong cross = gl_mul(gl_add(a.c0, a.c1), gl_add(b.c0, b.c1));
    return f2(gl_add(ac, gl_mul7(bd)), gl_sub(gl_sub(cross, ac), bd));
}
inline fp2 CF(constant ulong *cf, uint i) { return f2(cf[2 * i], cf[2 * i + 1]); }
// [M3b] mixed operands: an extension value times / plus a base-field word
inline fp2 f2_mulb(fp2 a, ulong b) { return f2(gl_mul(a.c0, b), gl_mul(a.c1, b)); }
inline fp2 f2_addb(fp2 a, ulong b) { return f2(gl_add(a.c0, b), a.c1); }
// [M4e] a table's value at point d of the pair's line (lo at 0, hi at 1,
// lo + d (hi - lo) beyond: what the CPU reaches by adding the step d times)
inline ulong ln_base(device const ulong *tabs, ulong lo, ulong hi, uint d, ulong dd) {
    ulong l = tabs[lo];
    if (d == 0u) { return l; }
    ulong h = tabs[hi];
    if (d == 1u) { return h; }
    return gl_add(l, gl_mul(gl_sub(h, l), dd));
}
inline fp2 ln_ext(device const ulong *tabs, ulong lo, ulong hi, uint d, ulong dd) {
    fp2 l = f2(tabs[lo], tabs[lo + 1]);
    if (d == 0u) { return l; }
    fp2 h = f2(tabs[hi], tabs[hi + 1]);
    if (d == 1u) { return h; }
    return f2_add(l, f2_mulb(f2_sub(h, l), dd));
}
"#;

#[allow(dead_code)] // the M3 untyped kernel contract, kept as documentation; since
// [M4e] the generated kernels run one thread per (stride, point) instead (metal_slot.rs)
const SC_ROUND: &str = r#"
struct RoundArgs { ulong nhalf; ulong cap; uint eval_one; uint nthreads; };
// One thread per stride of cube pairs: the round's evaluations at 0..=D along
// each pair's line, exactly as ClosureRounds::round (cur, then cur += dif).
kernel void k_sc_round(device const ulong *tabs [[buffer(0)]],
                       device ulong *part [[buffer(1)]],
                       constant ulong *cf [[buffer(2)]],
                       constant RoundArgs &a [[buffer(3)]],
                       uint gid [[thread_position_in_grid]]) {
    if (gid >= a.nthreads) { return; }
    fp2 acc[SC_D + 1];
    for (uint d = 0; d <= SC_D; d++) { acc[d] = f2(0UL, 0UL); }
    fp2 T[SC_K];
    fp2 dif[SC_K];
    for (ulong i = ulong(gid); i < a.nhalf; i += ulong(a.nthreads)) {
        for (uint t = 0; t < SC_K; t++) {
            ulong lo = (ulong(t) * a.cap + i) * 2UL;
            ulong hi = (ulong(t) * a.cap + i + a.nhalf) * 2UL;
            T[t] = f2(tabs[lo], tabs[lo + 1]);
            dif[t] = f2_sub(f2(tabs[hi], tabs[hi + 1]), T[t]);
        }
        acc[0] = f2_add(acc[0], slot_poly(T, cf));
        for (uint d = 1; d <= SC_D; d++) {
            for (uint t = 0; t < SC_K; t++) { T[t] = f2_add(T[t], dif[t]); }
            if (d != 1u || a.eval_one != 0u) { acc[d] = f2_add(acc[d], slot_poly(T, cf)); }
        }
    }
    for (uint d = 0; d <= SC_D; d++) {
        ulong o = (ulong(gid) * (SC_D + 1) + ulong(d)) * 2UL;
        part[o] = acc[d].c0;
        part[o + 1] = acc[d].c1;
    }
}
"#;

#[repr(C)]
struct RoundArgs {
    half: u64,
    cap: u64,
    eval_one: u32,
    nthreads: u32,
}
#[repr(C)]
struct FoldTabArgs {
    half: u64,
    cap: u64,
    k: u64,
    r0: u64,
    r1: u64,
}

static SC_COMPILE_NS: AtomicU64 = AtomicU64::new(0);
static SC_ROUND_NS: AtomicU64 = AtomicU64::new(0);

/// (seconds compiling generated slot kernels, seconds in device rounds+folds)
pub fn sumcheck_stats() -> (f64, f64) {
    (SC_COMPILE_NS.load(Ordering::Relaxed) as f64 * 1e-9, SC_ROUND_NS.load(Ordering::Relaxed) as f64 * 1e-9)
}

fn sc_pipelines(c: &Ctx, kernel_src: &str, k: usize, degree: usize) -> Result<(ComputePipelineState, ComputePipelineState), String> {
    // [M4] ONE library compile for both kernels: the round-0 and the later
    // round kernel live in the same generated source, and compiling it once
    // per kernel doubled the (dominant, cold) compile time of a large slot
    let src = format!("{}{SC_PRELUDE}\n#define SC_K {k}\n#define SC_D {degree}\n{kernel_src}", gl_header());
    let names = ["k_sc_round0", "k_sc_round"];
    let keys = names.map(|n| format!("{n}\n{src}"));
    let mut cache = c.sc_pipes.lock().map_err(|_| "metal: sumcheck kernel cache poisoned")?;
    if let (Some(p0), Some(p1)) = (cache.get(&keys[0]), cache.get(&keys[1])) {
        return Ok((p0.clone(), p1.clone()));
    }
    // [M4e] DIAGNOSTIC: HL_METAL_DUMP=<dir> writes each compiled slot library
    if let Ok(dir) = std::env::var("HL_METAL_DUMP") {
        let _ = std::fs::write(format!("{dir}/slot_k{k}_d{degree}_{:016x}.metal", src.len() as u64 ^ (kernel_src.len() as u64) << 20), &src);
    }
    let t = std::time::Instant::now();
    let (p0, p1) = objc::rc::autoreleasepool(|| -> Result<(ComputePipelineState, ComputePipelineState), String> {
        let lib = c.device.new_library_with_source(&src, &CompileOptions::new()).map_err(|e| format!("metal sumcheck compile: {e}"))?;
        let mk = |name: &str| -> Result<ComputePipelineState, String> {
            let f = lib.get_function(name, None).map_err(|e| format!("metal sumcheck function {name}: {e}"))?;
            c.device.new_compute_pipeline_state_with_function(&f).map_err(|e| format!("metal sumcheck pipeline: {e}"))
        };
        Ok((mk(names[0])?, mk(names[1])?))
    })?;
    SC_COMPILE_NS.fetch_add(t.elapsed().as_nanos() as u64, Ordering::Relaxed);
    if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
        eprintln!("[ZK60-METAL] compiled a slot library ({k} tables, degree {degree}, {} B of source, 2 kernels) in {:.3} s", src.len(), t.elapsed().as_secs_f64());
    }
    cache.insert(keys[0].clone(), p0.clone());
    cache.insert(keys[1].clone(), p1.clone());
    Ok((p0, p1))
}

/// A sumcheck whose tables live on the Apple GPU and whose round polynomial is
/// the generated MSL function `slot_poly(T, cf)` (`poly_fn`), with `coefs` as
/// `cf`. The same contract as `ClosureRounds` (zkp-core sumcheck/rounds.rs):
/// unmasked evaluations at 0..=degree, folding in most-significant-variable
/// order, and the same s(1) recovery when `recover_one` is set.
pub struct MetalRounds {
    k: usize,
    n_vars: usize,
    degree: usize,
    cap: usize,
    len: usize,
    tabs: PBuf,
    coefs: PBuf,
    /// round 0: typed by field (base tables as one word); rounds 1..: every
    /// table extension-valued (the first fold makes them so)
    pipe0: ComputePipelineState,
    pipe: ComputePipelineState,
    next: usize,
    pending: Option<Vec<Fp2>>,
    recover_one: bool,
    unmasked_claim: Option<Fp2>,
    /// nanoseconds spent in this sumcheck's rounds and folds (diagnostics)
    busy_ns: std::cell::Cell<u64>,
    /// [M4d] the same split (diagnostics): round 0, later rounds, folds
    split_ns: std::cell::Cell<[u64; 3]>,
    /// [M4e] threads per round: log2 cap, pairs per thread and the
    /// threadgroup width (read once)
    cap_log: u32,
    per: usize,
    tg: u64,
    /// [M4e] the partials buffer, sized for round 0 and reused every round
    part: PBuf,
    /// [M4e] a fold not yet run: (its half, its challenge). It is encoded in
    /// the next round's command buffer, ahead of that round; the last fold
    /// runs at once, since the final tables are read after it.
    fold_r: Option<(usize, Fp2)>,
}

/// threads of a round over `half` pairs (the per-thread pair count and the cap)
fn sc_threads(half: usize, per: usize, cap_log: u32) -> usize {
    (half / per).clamp(1, 1 << cap_log)
}

/// `Ok(None)`: a table the kernel keeps as a base-field word has a nonzero
/// imaginary part, so the typed kernel does not apply; the caller keeps the CPU.
pub fn metal_rounds(kernel_src: &str, tables: &[Vec<Fp2>], degree: usize, coefs: &[Fp2], base: &[bool]) -> Result<Option<MetalRounds>, String> {
    let c = ctx()?;
    if tables.is_empty() || degree == 0 {
        return Err("metal sumcheck: no tables or degree 0".into());
    }
    let cap = tables[0].len();
    if !cap.is_power_of_two() || cap < 2 || tables.iter().any(|t| t.len() != cap) {
        return Err("metal sumcheck: table lengths".into());
    }
    let k = tables.len();
    if base.len() != k {
        return Err("metal sumcheck: base flags".into());
    }
    let (pipe0, pipe) = sc_pipelines(c, kernel_src, k, degree)?;
    let t_setup = std::time::Instant::now();
    objc::rc::autoreleasepool(|| {
        // the tables straight into shared memory, one table per rayon task
        let tabs = shared_buffer(c, (k * cap * 16) as u64)?;
        {
            // SAFETY: k * cap * 2 u64 of shared, CPU-visible memory, written
            // once here before any GPU use; tasks write disjoint table ranges.
            let dst = unsafe { std::slice::from_raw_parts_mut(tabs.contents() as *mut u64, k * cap * 2) };
            let typed_ok: bool = dst
                .par_chunks_mut(cap * 2)
                .zip(tables.par_iter())
                .zip(base.par_iter())
                .map(|((d, t), &b)| {
                    let mut ok = true;
                    for (pair, v) in d.chunks_exact_mut(2).zip(t.iter()) {
                        pair[0] = v.c0.0;
                        pair[1] = v.c1.0;
                        ok &= !b || v.c1.0 == 0;
                    }
                    ok
                })
                .reduce(|| true, |a, b| a && b);
            if !typed_ok {
                return Ok(None);
            }
        }
        if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
            eprintln!("[ZK60-METAL] sumcheck setup: {k} tables x 2^{} in {:.4} s", cap.trailing_zeros(), t_setup.elapsed().as_secs_f64());
        }
        let parts = rounds_parts(c, cap, degree, coefs)?;
        Ok(Some(assemble_rounds(tabs, k, cap, degree, pipe0, pipe, parts)))
    })
}

/// the coefficient buffer, the thread settings and the partials buffer of a
/// device sumcheck (everything but its tables)
struct RoundsParts {
    coefs: PBuf,
    cap_log: u32,
    per: usize,
    tg: u64,
    part: PBuf,
}

fn rounds_parts(c: &Ctx, cap: usize, degree: usize, coefs: &[Fp2]) -> Result<RoundsParts, String> {
    let mut cf: Vec<Fp> = coefs.iter().flat_map(|v| [v.c0, v.c1]).collect();
    if cf.is_empty() {
        cf.push(Fp::ZERO);
    }
    let coefs = upload(c, &cf)?;
    // [M4e] one pair per thread up to 2^17 strides, groups of 64 (measured
    // on slot 14's later rounds; HL_METAL_SC_THREADS / _PER / _TG override)
    let cap_log: u32 = std::env::var("HL_METAL_SC_THREADS").ok().and_then(|v| v.parse().ok()).unwrap_or(17).clamp(8, 22);
    let per: usize = std::env::var("HL_METAL_SC_PER").ok().and_then(|v| v.parse().ok()).unwrap_or(1).max(1);
    let tg: u64 = std::env::var("HL_METAL_SC_TG").ok().and_then(|v| v.parse().ok()).unwrap_or(64).clamp(32, 1024);
    let t0n = sc_threads(cap / 2, per, cap_log);
    let part = shared_buffer(c, (t0n * (degree + 1) * 16) as u64)?;
    Ok(RoundsParts { coefs, cap_log, per, tg, part })
}

fn assemble_rounds(tabs: PBuf, k: usize, cap: usize, degree: usize, pipe0: ComputePipelineState, pipe: ComputePipelineState, p: RoundsParts) -> MetalRounds {
    MetalRounds {
        k,
        n_vars: cap.trailing_zeros() as usize,
        degree,
        cap,
        len: cap,
        tabs,
        coefs: p.coefs,
        pipe0,
        pipe,
        next: 0,
        pending: None,
        recover_one: false,
        unmasked_claim: None,
        busy_ns: std::cell::Cell::new(0),
        split_ns: std::cell::Cell::new([0; 3]),
        cap_log: p.cap_log,
        per: p.per,
        tg: p.tg,
        part: p.part,
        fold_r: None,
    }
}

/// **[ZK60-METAL M4i]** A slot's `k` tables of `cap` extension elements in ONE
/// pooled shared buffer, written IN PLACE by the slot's table builder and then
/// handed to [`metal_rounds_owned`]: no host vector per table (whose fresh,
/// recycled pages macOS zeroes first) and no copy into device memory. The
/// buffer is viewed as `[Fp2]`, so the constructor checks that `Fp2` is the two
/// words `c0, c1` and refuses otherwise (the caller then builds host vectors as
/// before). A pooled buffer holds stale words, so the builder writes every
/// element of every table.
pub struct MetalTables {
    buf: PBuf,
    k: usize,
    cap: usize,
}

impl MetalTables {
    pub fn new(k: usize, cap: usize) -> Result<MetalTables, String> {
        if std::mem::size_of::<Fp2>() != 16 || std::mem::offset_of!(Fp2, c0) != 0 || std::mem::offset_of!(Fp2, c1) != 8 || std::mem::align_of::<Fp2>() > 8 {
            return Err("metal tables: Fp2 is not the two words c0, c1".into());
        }
        if k == 0 || cap < 2 || !cap.is_power_of_two() {
            return Err("metal tables: table count or length".into());
        }
        let c = ctx()?;
        let buf = objc::rc::autoreleasepool(|| shared_buffer(c, (k * cap * 16) as u64))?;
        Ok(MetalTables { buf, k, cap })
    }

    /// the `k` tables as disjoint mutable slices of `cap` elements each
    pub fn tables_mut(&mut self) -> Vec<&mut [Fp2]> {
        // SAFETY: `k * cap * 16` bytes of shared, CPU-visible memory owned by
        // `self` (page-aligned, so aligned for `Fp2`; the layout was checked in
        // `new`) and not in use by the GPU; any two words are an `Fp2` value,
        // and the builder overwrites every element before anything reads it.
        let all = unsafe { std::slice::from_raw_parts_mut(self.buf.contents() as *mut Fp2, self.k * self.cap) };
        all.chunks_mut(self.cap).collect()
    }

    /// host copies of the tables (the CPU path when the device declines)
    pub fn to_vecs(&self) -> Vec<Vec<Fp2>> {
        // SAFETY: as in `tables_mut`, read-only, after the builder wrote them
        let all = unsafe { std::slice::from_raw_parts(self.buf.contents() as *const Fp2, self.k * self.cap) };
        all.chunks(self.cap).map(|t| t.to_vec()).collect()
    }
}

/// [`metal_rounds`] over tables already in device memory ([`MetalTables`]).
/// `Err((tables, None))`: a table the kernel keeps as a base-field word has a
/// nonzero imaginary part (the typed kernel does not apply; the CPU runs);
/// `Err((tables, Some(e)))`: a device error. Either way the tables come back.
pub fn metal_rounds_owned(kernel_src: &str, t: MetalTables, degree: usize, coefs: &[Fp2], base: &[bool]) -> Result<MetalRounds, (MetalTables, Option<String>)> {
    let c = match ctx() {
        Ok(c) => c,
        Err(e) => return Err((t, Some(e))),
    };
    if degree == 0 || base.len() != t.k {
        return Err((t, Some("metal sumcheck: degree 0 or base flags".into())));
    }
    let (pipe0, pipe) = match sc_pipelines(c, kernel_src, t.k, degree) {
        Ok(p) => p,
        Err(e) => return Err((t, Some(e))),
    };
    let t_setup = std::time::Instant::now();
    let (k, cap) = (t.k, t.cap);
    // the base-typing check the copy made, on the tables in place
    let typed_ok = {
        // SAFETY: as in `MetalTables::to_vecs`
        let all = unsafe { std::slice::from_raw_parts(t.buf.contents() as *const Fp2, k * cap) };
        all.par_chunks(cap).zip(base.par_iter()).all(|(tab, &b)| !b || tab.iter().all(|v| v.c1.0 == 0))
    };
    if !typed_ok {
        return Err((t, None));
    }
    if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
        eprintln!("[ZK60-METAL] sumcheck setup (tables in place): {k} tables x 2^{} in {:.4} s", cap.trailing_zeros(), t_setup.elapsed().as_secs_f64());
    }
    let parts = match objc::rc::autoreleasepool(|| rounds_parts(c, cap, degree, coefs)) {
        Ok(p) => p,
        Err(e) => return Err((t, Some(e))),
    };
    Ok(assemble_rounds(t.buf, k, cap, degree, pipe0, pipe, parts))
}

impl MetalRounds {
    /// `ClosureRounds::recover_one`, the same semantics.
    pub fn recover_one(mut self, initial_unmasked_claim: Option<Fp2>) -> Self {
        assert!(self.degree >= 1, "claim recovery requires degree >= 1");
        self.recover_one = true;
        self.unmasked_claim = initial_unmasked_claim;
        self
    }

    /// the folded tables after the last round (each of length 1), as the CPU
    /// evaluator leaves its `tables`
    pub fn final_tables(&self) -> Vec<Vec<Fp2>> {
        self.finals_inner().into_iter().map(|v| vec![v]).collect()
    }

    fn finals_inner(&self) -> Vec<Fp2> {
        assert!(self.fold_r.is_none(), "metal sumcheck: a fold is still deferred");
        let raw = as_u64s(&self.tabs, self.k * self.cap * 2);
        (0..self.k).map(|t| Fp2::new(Fp(raw[t * self.cap * 2]), Fp(raw[t * self.cap * 2 + 1]))).collect()
    }
}

impl zkp_core::sumcheck::SumcheckRounds for MetalRounds {
    fn n_vars(&self) -> usize {
        self.n_vars
    }
    fn degree(&self) -> usize {
        self.degree
    }

    fn round(&mut self, j: usize) -> Vec<Fp2> {
        assert_eq!(j, self.next, "sumcheck evaluator round order");
        assert!(j < self.n_vars && self.pending.is_none(), "round needs the preceding fold");
        let t0 = std::time::Instant::now();
        let c = ctx().expect("metal context");
        let half = self.len / 2;
        let claim = if self.recover_one { self.unmasked_claim } else { None };
        let eval_one = claim.is_none();
        // threads per round: HL_METAL_SC_THREADS (log2, default 15) caps it
        let nthreads = sc_threads(half, self.per, self.cap_log);
        let d1 = self.degree + 1;
        let fold = self.fold_r.take();
        let sums = objc::rc::autoreleasepool(|| {
            let pipe = if j == 0 { &self.pipe0 } else { &self.pipe };
            run(c, |enc| {
                // [M4e] the previous round's fold, in this command buffer: the
                // encoder runs its dispatches in order (as the NTT stages do)
                if let Some((fh, r)) = fold {
                    enc.set_buffer(0, Some(&self.tabs), 0);
                    set_args(enc, 1, &FoldTabArgs { half: fh as u64, cap: self.cap as u64, k: self.k as u64, r0: r.c0.0, r1: r.c1.0 });
                    dispatch_2d(c, enc, "k_fold_tables", fh as u64, self.k as u64);
                }
                enc.set_compute_pipeline_state(pipe);
                enc.set_buffer(0, Some(&self.tabs), 0);
                enc.set_buffer(1, Some(&self.part), 0);
                enc.set_buffer(2, Some(&self.coefs), 0);
                set_args(enc, 3, &RoundArgs { half: half as u64, cap: self.cap as u64, eval_one: eval_one as u32, nthreads: nthreads as u32 });
                // [M4e] one thread per (stride, evaluation point); [M4g] 32
                // lanes per point, point 1 not launched when the claim gives s(1)
                let np = if eval_one { d1 } else { d1 - 1 };
                let grid = (nthreads.div_ceil(32) * 32 * np) as u64;
                let tg = pipe.max_total_threads_per_threadgroup().min(self.tg).min(grid);
                enc.dispatch_threads(MTLSize::new(grid, 1, 1), MTLSize::new(tg, 1, 1));
                Ok(())
            })
            .expect("metal sumcheck round");
            // [M4e] small rounds on this thread (a rayon region costs about
            // half a millisecond here), large ones in parallel; field addition
            // is exact, so the grouping does not change the sums. [M4g] Point
            // 1 was not evaluated when the claim gives s(1): its partials are
            // not read (the sum stays zero until the claim sets it below).
            let p = as_u64s(&self.part, nthreads * d1 * 2);
            let sum = |blk: &[u64]| -> Vec<Fp2> {
                let mut acc = vec![Fp2::ZERO; d1];
                for th in blk.chunks_exact(d1 * 2) {
                    for (d, s) in acc.iter_mut().enumerate() {
                        if d != 1 || eval_one {
                            *s = s.add(Fp2::new(Fp(th[2 * d]), Fp(th[2 * d + 1])));
                        }
                    }
                }
                acc
            };
            if nthreads <= 1 << 14 {
                sum(p)
            } else {
                p.par_chunks(4096 * d1 * 2).map(sum).reduce(|| vec![Fp2::ZERO; d1], |mut a, b| {
                    for (x, y) in a.iter_mut().zip(b.iter()) {
                        *x = x.add(*y);
                    }
                    a
                })
            }
        });
        let mut sums = sums;
        if let Some(claim) = claim {
            sums[1] = claim.sub(sums[0]);
        }
        self.pending = Some(sums.clone());
        let ns = t0.elapsed().as_nanos() as u64;
        SC_ROUND_NS.fetch_add(ns, Ordering::Relaxed);
        self.busy_ns.set(self.busy_ns.get() + ns);
        let mut sp = self.split_ns.get();
        sp[if j == 0 { 0 } else { 1 }] += ns;
        self.split_ns.set(sp);
        sums
    }

    fn fold(&mut self, r: Fp2) {
        let t0 = std::time::Instant::now();
        let sums = self.pending.take().expect("fold needs a round");
        if self.recover_one {
            self.unmasked_claim = Some(zkp_core::mle::interpolate_eval(&sums, r));
        }
        let half = self.len / 2;
        if self.next + 1 < self.n_vars {
            // [M4e] encoded ahead of the next round, in its command buffer
            self.fold_r = Some((half, r));
        } else {
            // the last fold: the final tables are read right after it
            let c = ctx().expect("metal context");
            objc::rc::autoreleasepool(|| {
                run(c, |enc| {
                    enc.set_buffer(0, Some(&self.tabs), 0);
                    set_args(enc, 1, &FoldTabArgs { half: half as u64, cap: self.cap as u64, k: self.k as u64, r0: r.c0.0, r1: r.c1.0 });
                    dispatch_2d(c, enc, "k_fold_tables", half as u64, self.k as u64);
                    Ok(())
                })
                .expect("metal sumcheck fold");
            });
        }
        self.len = half;
        self.next += 1;
        let ns = t0.elapsed().as_nanos() as u64;
        SC_ROUND_NS.fetch_add(ns, Ordering::Relaxed);
        self.busy_ns.set(self.busy_ns.get() + ns);
        let mut sp = self.split_ns.get();
        sp[2] += ns;
        self.split_ns.set(sp);
    }

    fn finals(&self) -> Vec<Fp2> {
        assert_eq!(self.next, self.n_vars, "finals need all folds");
        assert!(self.pending.is_none() && self.fold_r.is_none());
        if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
            let sp = self.split_ns.get();
            eprintln!(
                "[ZK60-METAL] sumcheck rounds: {} tables, {} rounds, degree {} in {:.4} s (round 0 {:.4}, rounds 1.. {:.4}, folds {:.4}; max threads/group {} / {})",
                self.k,
                self.n_vars,
                self.degree,
                self.busy_ns.get() as f64 * 1e-9,
                sp[0] as f64 * 1e-9,
                sp[1] as f64 * 1e-9,
                sp[2] as f64 * 1e-9,
                self.pipe0.max_total_threads_per_threadgroup(),
                self.pipe.max_total_threads_per_threadgroup()
            );
        }
        self.finals_inner()
    }
}

// ------------------------------------------- M4k: the late rounds on the host

/// [ZK60-METAL M4k] the host round a device round must beat: a device round
/// costs about 0.35-0.4 ms here whatever its size (command buffer, wait,
/// partial sum; `logs/m4g_split.log`, 18 rounds of 3 tables in 6.8 ms)
const TAIL_ROUND_BUDGET_S: f64 = 2.5e-4;

impl MetalRounds {
    /// **[ZK60-METAL M4k]** this sumcheck, finished on the HOST from the first
    /// round whose host cost (pairs x points evaluated x one evaluation of
    /// `poly`, timed here on eight points) is under a device round's latency.
    /// `poly` is the slot's own polynomial (the closure the IR was checked
    /// against before this kernel was allowed to run), so a host round is the
    /// `ClosureRounds` round over the same tables: the same unmasked values, the
    /// same s(1) recovery, the same folds. Where the switch lands changes no
    /// value. `HL_METAL_HOST_TAIL=0` keeps every round on the device.
    pub fn with_host_tail(self, poly: &(dyn Fn(&[Fp2]) -> Fp2 + Sync)) -> TailedRounds<'_> {
        let k = self.k;
        let pts: Vec<Vec<Fp2>> = (0..8u64).map(|s| (0..k as u64).map(|t| Fp2::new(Fp::new(s * 7919 + t * 104_729 + 1), Fp::new(t + 3 * s + 1))).collect()).collect();
        let t = std::time::Instant::now();
        let mut sink = Fp2::ZERO;
        for p in &pts {
            sink = sink.add(poly(p));
        }
        std::hint::black_box(sink);
        let per_eval = t.elapsed().as_secs_f64() / 8.0;
        let on = std::env::var("HL_METAL_HOST_TAIL").map(|v| v != "0").unwrap_or(true);
        let (degree, n_vars) = (self.degree, self.n_vars);
        TailedRounds { dev: Some(self), host: Vec::new(), poly, per_eval, on, degree, n_vars, next: 0, pending: None, recover_one: false, unmasked_claim: None, host_rounds: 0 }
    }

    fn run_fold_now(&self, half: usize, r: Fp2) {
        let c = ctx().expect("metal context");
        objc::rc::autoreleasepool(|| {
            run(c, |enc| {
                enc.set_buffer(0, Some(&self.tabs), 0);
                set_args(enc, 1, &FoldTabArgs { half: half as u64, cap: self.cap as u64, k: self.k as u64, r0: r.c0.0, r1: r.c1.0 });
                dispatch_2d(c, enc, "k_fold_tables", half as u64, self.k as u64);
                Ok(())
            })
            .expect("metal sumcheck fold");
        });
    }

    /// [M4k] the current tables (`len` entries each) as host vectors, any
    /// deferred fold run first, and the claim-recovery state
    fn into_host(mut self) -> (Vec<Vec<Fp2>>, bool, Option<Fp2>) {
        if let Some((fh, r)) = self.fold_r.take() {
            self.run_fold_now(fh, r);
        }
        let raw = as_u64s(&self.tabs, self.k * self.cap * 2);
        let tables = (0..self.k).map(|t| (0..self.len).map(|i| Fp2::new(Fp(raw[(t * self.cap + i) * 2]), Fp(raw[(t * self.cap + i) * 2 + 1]))).collect()).collect();
        (tables, self.recover_one, self.unmasked_claim)
    }
}

/// [`MetalRounds`] with its late rounds on the host ([`MetalRounds::with_host_tail`]).
pub struct TailedRounds<'p> {
    dev: Option<MetalRounds>,
    host: Vec<Vec<Fp2>>,
    poly: &'p (dyn Fn(&[Fp2]) -> Fp2 + Sync),
    per_eval: f64,
    on: bool,
    degree: usize,
    n_vars: usize,
    next: usize,
    pending: Option<Vec<Fp2>>,
    recover_one: bool,
    unmasked_claim: Option<Fp2>,
    host_rounds: usize,
}

impl TailedRounds<'_> {
    /// the folded tables after the last round, as [`MetalRounds::final_tables`]
    pub fn final_tables(&self) -> Vec<Vec<Fp2>> {
        match &self.dev {
            Some(d) => d.final_tables(),
            None => self.host.iter().map(|t| vec![t[0]]).collect(),
        }
    }

    /// how many rounds ran on the host (diagnostics)
    pub fn host_rounds(&self) -> usize {
        self.host_rounds
    }

    /// `ClosureRounds::round` (zkp-core sumcheck/rounds.rs), one thread: the
    /// small tables of the last rounds
    fn host_round(&mut self) -> Vec<Fp2> {
        let k = self.host.len();
        let half = self.host[0].len() / 2;
        let claim = if self.recover_one { self.unmasked_claim } else { None };
        let eval_one = claim.is_none();
        let mut acc = vec![Fp2::ZERO; self.degree + 1];
        let (mut cur, mut dif) = (vec![Fp2::ZERO; k], vec![Fp2::ZERO; k]);
        for i in 0..half {
            for (t, tb) in self.host.iter().enumerate() {
                cur[t] = tb[i];
                dif[t] = tb[i + half].sub(tb[i]);
            }
            acc[0] = acc[0].add((self.poly)(&cur));
            for d in 1..=self.degree {
                for t in 0..k {
                    cur[t] = cur[t].add(dif[t]);
                }
                if d != 1 || eval_one {
                    acc[d] = acc[d].add((self.poly)(&cur));
                }
            }
        }
        if let Some(claim) = claim {
            acc[1] = claim.sub(acc[0]);
        }
        self.pending = Some(acc.clone());
        self.host_rounds += 1;
        acc
    }
}

impl zkp_core::sumcheck::SumcheckRounds for TailedRounds<'_> {
    fn n_vars(&self) -> usize {
        self.n_vars
    }
    fn degree(&self) -> usize {
        self.degree
    }

    fn round(&mut self, j: usize) -> Vec<Fp2> {
        assert_eq!(j, self.next, "sumcheck evaluator round order");
        if let Some(d) = self.dev.as_mut() {
            let half = d.len / 2;
            let points = if d.recover_one && d.unmasked_claim.is_some() { self.degree } else { self.degree + 1 };
            if !self.on || (half * points) as f64 * self.per_eval > TAIL_ROUND_BUDGET_S {
                return d.round(j);
            }
            let (tables, recover_one, unmasked_claim) = self.dev.take().expect("the device evaluator").into_host();
            self.host = tables;
            self.recover_one = recover_one;
            self.unmasked_claim = unmasked_claim;
        }
        assert!(self.pending.is_none(), "round needs the preceding fold");
        self.host_round()
    }

    fn fold(&mut self, r: Fp2) {
        match self.dev.as_mut() {
            Some(d) => d.fold(r),
            None => {
                let sums = self.pending.take().expect("fold needs a round");
                if self.recover_one {
                    self.unmasked_claim = Some(zkp_core::mle::interpolate_eval(&sums, r));
                }
                let half = self.host[0].len() / 2;
                for tb in self.host.iter_mut() {
                    let (lo, hi) = tb.split_at_mut(half);
                    for (a, b) in lo.iter_mut().zip(hi.iter()) {
                        *a = a.add(r.mul(b.sub(*a)));
                    }
                    tb.truncate(half);
                }
            }
        }
        self.next += 1;
    }

    fn finals(&self) -> Vec<Fp2> {
        assert_eq!(self.next, self.n_vars, "finals need all folds");
        match &self.dev {
            Some(d) => d.finals(),
            None => {
                assert!(self.pending.is_none());
                self.host.iter().map(|t| t[0]).collect()
            }
        }
    }
}

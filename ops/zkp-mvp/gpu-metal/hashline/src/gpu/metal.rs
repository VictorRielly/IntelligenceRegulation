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
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Mutex, OnceLock};
use zkp_core::pcs::PcsParams;

const SRC: &str = include_str!("metal_kernels.metal");
const KERNELS: [&str; 18] = [
    "k_fs_test",
    "k_sc_fs_step",
    "k_sc_part_reduce",
    "k_fold_tables_dev",
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
    /// the process-wide queue (the default, `HL_METAL_QUEUES=shared`; [A7] the
    /// opt-in `thread` gives each thread its own, `OWN_QUEUE`)
    queue: CommandQueue,
    pipes: HashMap<&'static str, ComputePipelineState>,
    /// (forward, inverse) twiddle buffers per NttTables::max_log
    twiddles: Mutex<HashMap<u32, (Buffer, Buffer)>>,
    /// [M12] the compact head twiddles (forward, inverse) per max_log: the
    /// 1024 powers of the 2048th root the head's 11 stages use, contiguous
    head_tw: Mutex<HashMap<u32, (Buffer, Buffer)>>,
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
            Ok(Ctx { device, queue, pipes, twiddles: Mutex::new(HashMap::new()), head_tw: Mutex::new(HashMap::new()), sc_pipes: Mutex::new(HashMap::new()) })
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
    /// [M12] 1: the head reads the compact twiddles (buffer 6)
    use_hw: u32,
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
    tw: &Buffer, hw: Option<&Buffer>, rows: u64, log_n: u32, log_src: u32, mode: u32, q: u64, max_log: u32, scale: Option<u64>,
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
    enc.set_buffer(6, Some(hw.unwrap_or(tw)), 0);
    let head_scales = scale.is_some() && log_n <= TILE_LOG;
    set_args(
        enc,
        5,
        &HeadArgs { rows, log_n, log_src, mode, max_log, q, scale: scale.unwrap_or(1), apply_scale: head_scales as u32, use_hw: hw.is_some() as u32 },
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

/// **[ZK60-METAL M12]** the head stages' twiddles, compact: `hw[m] =
/// tw[m << (max_log - 11)]` (= omega_2048^m) for m < 1024. Stage s <= 11 of
/// the head reads `tw[k << (max_log - s)]` = `hw[k << (11 - s)]`, the same
/// word, from 8 KB of consecutive words instead of a gather whose stride is
/// 2^(max_log - s) words. `None` when the tables are smaller than a tile or
/// `HL_METAL_HEAD_TW=0`.
fn head_twiddle_buffers(c: &Ctx, ntt: &NttTables) -> Result<Option<(Buffer, Buffer)>, String> {
    static ON: OnceLock<bool> = OnceLock::new();
    if !*ON.get_or_init(|| std::env::var("HL_METAL_HEAD_TW").map(|v| v != "0").unwrap_or(true)) || ntt.max_log < TILE_LOG {
        return Ok(None);
    }
    let mut map = c.head_tw.lock().map_err(|_| "metal: head twiddle cache poisoned")?;
    if let Some((f, i)) = map.get(&ntt.max_log) {
        return Ok(Some((f.clone(), i.clone())));
    }
    let (fw, inv) = ntt.twiddle_tables();
    let sh = ntt.max_log - TILE_LOG;
    let pick = |t: &[Fp]| -> Vec<Fp> { (0..1usize << (TILE_LOG - 1)).map(|m| t[m << sh]).collect() };
    let f = upload(c, &pick(fw))?.keep();
    let i = upload(c, &pick(inv))?.keep();
    map.insert(ntt.max_log, (f.clone(), i.clone()));
    Ok(Some((f, i)))
}

/// **[M6, tests] one device Fiat-Shamir round step** (`k_fs_test`), from a
/// transcript `state` and squeeze `counter`: `absorb_fp2(b"sc-round", vals)`
/// then `challenge_fp2()`. Returns the new state and the challenge.
#[cfg(test)]
pub fn fs_round_for_test(state: [u8; 32], key: Option<[u8; 32]>, counter: u64, vals: &[Fp2]) -> Result<([u8; 32], Fp2), String> {
    #[repr(C)]
    struct FsTestArgs {
        n: u32,
        keyed: u32,
        counter: u64,
    }
    if vals.is_empty() || vals.len() > 8 {
        return Err("metal fs test: 1..=8 round values".into());
    }
    let c = ctx()?;
    let words = |b: &[u8; 32]| -> Vec<u32> { (0..8).map(|i| u32::from_le_bytes([b[4 * i], b[4 * i + 1], b[4 * i + 2], b[4 * i + 3]])).collect() };
    let put_u32 = |v: &[u32]| -> Result<PBuf, String> {
        let buf = shared_buffer(c, (v.len() * 4) as u64)?;
        // SAFETY: v.len() * 4 bytes of shared memory owned here
        unsafe { std::slice::from_raw_parts_mut(buf.contents() as *mut u32, v.len()) }.copy_from_slice(v);
        Ok(buf)
    };
    let st = put_u32(&words(&state))?;
    let kb = put_u32(&words(&key.unwrap_or([0u8; 32])))?;
    let flat: Vec<Fp> = vals.iter().flat_map(|x| [x.c0, x.c1]).collect();
    let vb = upload(c, &flat)?;
    let out = shared_buffer(c, 10 * 8)?;
    run(c, |enc| {
        enc.set_buffer(0, Some(&st), 0);
        enc.set_buffer(1, Some(&kb), 0);
        enc.set_buffer(2, Some(&vb), 0);
        enc.set_buffer(3, Some(&out), 0);
        set_args(enc, 4, &FsTestArgs { n: vals.len() as u32, keyed: key.is_some() as u32, counter });
        dispatch_2d(c, enc, "k_fs_test", 1, 1);
        Ok(())
    })?;
    // SAFETY: 10 words, completed command buffer
    let o = unsafe { std::slice::from_raw_parts(out.contents() as *const u64, 10) };
    let mut st_out = [0u8; 32];
    for i in 0..8 {
        st_out[4 * i..4 * i + 4].copy_from_slice(&(o[i] as u32).to_le_bytes());
    }
    Ok((st_out, Fp2::new(Fp::new(o[8]), Fp::new(o[9]))))
}

/// **[M6, probe] what a device round's fixed cost is made of.** `n` rounds of
/// a one-thread `k_fs_test` dispatch, optionally followed by a fold of
/// `fold_half` pairs over 3 tables: [0] each round in its own command buffer,
/// waited (today's shape); [1] all rounds in one command buffer. [2]/[3] the
/// same with the fold. Seconds; diagnostics only, values are not checked.
#[cfg(test)]
pub fn dispatch_overhead_probe(n: usize, fold_half: usize) -> Result<[f64; 4], String> {
    #[repr(C)]
    struct FsTestArgs {
        n: u32,
        keyed: u32,
        counter: u64,
    }
    let c = ctx()?;
    let st = shared_buffer(c, 32)?;
    let kb = shared_buffer(c, 32)?;
    let vb = shared_buffer(c, 16 * 8)?;
    let out = shared_buffer(c, 10 * 8)?;
    let cap = (2 * fold_half).max(2);
    let tabs = shared_buffer(c, (3 * cap * 16) as u64)?;
    let one = |enc: &metal::ComputeCommandEncoderRef, i: usize, fold: bool| {
        enc.set_buffer(0, Some(&st), 0);
        enc.set_buffer(1, Some(&kb), 0);
        enc.set_buffer(2, Some(&vb), 0);
        enc.set_buffer(3, Some(&out), 0);
        set_args(enc, 4, &FsTestArgs { n: 4, keyed: 1, counter: i as u64 });
        dispatch_2d(c, enc, "k_fs_test", 1, 1);
        if fold {
            enc.set_buffer(0, Some(&tabs), 0);
            set_args(enc, 1, &FoldTabArgs { half: fold_half as u64, cap: cap as u64, k: 3, r0: 3, r1: 5 });
            dispatch_2d(c, enc, "k_fold_tables", fold_half as u64, 3);
        }
    };
    let mut t = [0f64; 4];
    for (slot, fold) in [(0usize, false), (2, true)] {
        // warm the pipelines once
        objc::rc::autoreleasepool(|| run(c, |enc| { one(enc, 0, fold); Ok(()) }))?;
        let t0 = std::time::Instant::now();
        for i in 0..n {
            objc::rc::autoreleasepool(|| run(c, |enc| { one(enc, i, fold); Ok(()) }))?;
        }
        t[slot] = t0.elapsed().as_secs_f64();
        let t0 = std::time::Instant::now();
        objc::rc::autoreleasepool(|| {
            run(c, |enc| {
                for i in 0..n {
                    one(enc, i, fold);
                }
                Ok(())
            })
        })?;
        t[slot + 1] = t0.elapsed().as_secs_f64();
    }
    Ok(t)
}

/// **[M11, bench] Goldilocks multiply throughput on the device.** Compiles
/// `gl_header()` + `variant` (which must define `inline ulong vmul(ulong a,
/// ulong b)`), runs `threads` threads of an `iters`-long chain `x = vmul(x, y)
/// + x` (a dependent chain, as a butterfly's), and returns (seconds, outputs).
/// Two variants that compute the same field product return equal outputs.
#[cfg(test)]
pub fn mul_bench_for_test(variant: &str, threads: usize, iters: u32) -> Result<(f64, Vec<u64>), String> {
    let c = ctx()?;
    let src = format!(
        "{}\n{variant}\nkernel void k_mul_bench(device ulong *buf [[buffer(0)]], constant uint &iters [[buffer(1)]], uint tid [[thread_position_in_grid]]) {{\n    ulong x = buf[2 * tid], y = buf[2 * tid + 1];\n    for (uint i = 0; i < iters; i++) {{ x = gl_add(vmul(x, y), x); y = gl_add(y, 1UL); }}\n    buf[2 * tid] = x;\n}}\n",
        gl_header()
    );
    let lib = c.device.new_library_with_source(&src, &CompileOptions::new()).map_err(|e| format!("bench compile: {e}"))?;
    let f = lib.get_function("k_mul_bench", None).map_err(|e| format!("bench function: {e}"))?;
    let pipe = c.device.new_compute_pipeline_state_with_function(&f).map_err(|e| format!("bench pipeline: {e}"))?;
    let vals: Vec<Fp> = (0..2 * threads as u64).map(|i| Fp::new(i.wrapping_mul(0x9E37_79B9_7F4A_7C15) ^ (i << 7))).collect();
    let buf = upload(c, &vals)?;
    let tg = pipe.max_total_threads_per_threadgroup().min(256);
    let t = std::time::Instant::now();
    run(c, |enc| {
        enc.set_compute_pipeline_state(&pipe);
        enc.set_buffer(0, Some(&buf), 0);
        enc.set_bytes(1, 4, &iters as *const u32 as *const c_void);
        enc.dispatch_threads(MTLSize::new(threads as u64, 1, 1), MTLSize::new(tg, 1, 1));
        Ok(())
    })?;
    let secs = t.elapsed().as_secs_f64();
    let o = as_u64s(&buf, 2 * threads);
    Ok((secs, (0..threads).map(|i| o[2 * i]).collect()))
}

/// **[M18, bench] any arithmetic chain on the device.** Compiles `gl_header()`
/// + `SC_PRELUDE` + `src`, which must define `kernel void k_bench(device ulong
/// *buf [[buffer(0)]], constant uint &iters [[buffer(1)]], uint tid
/// [[thread_position_in_grid]])` using `buf[4 tid .. 4 tid + 4)`; returns
/// (seconds, the buffer after the run). `init` fills the buffer (4 words per
/// thread).
#[cfg(test)]
pub fn src_bench_for_test(src: &str, threads: usize, iters: u32, init: &[u64]) -> Result<(f64, Vec<u64>), String> {
    let c = ctx()?;
    if init.len() != 4 * threads {
        return Err("bench: 4 words per thread".into());
    }
    let full = format!("{}{SC_PRELUDE}\n{src}\n", gl_header());
    let lib = c.device.new_library_with_source(&full, &CompileOptions::new()).map_err(|e| format!("bench compile: {e}"))?;
    let f = lib.get_function("k_bench", None).map_err(|e| format!("bench function: {e}"))?;
    let pipe = c.device.new_compute_pipeline_state_with_function(&f).map_err(|e| format!("bench pipeline: {e}"))?;
    let buf = upload(c, &init.iter().map(|&w| Fp(w)).collect::<Vec<Fp>>())?;
    let tg = pipe.max_total_threads_per_threadgroup().min(256);
    let t = std::time::Instant::now();
    run(c, |enc| {
        enc.set_compute_pipeline_state(&pipe);
        enc.set_buffer(0, Some(&buf), 0);
        enc.set_bytes(1, 4, &iters as *const u32 as *const c_void);
        enc.dispatch_threads(MTLSize::new(threads as u64, 1, 1), MTLSize::new(tg, 1, 1));
        Ok(())
    })?;
    let secs = t.elapsed().as_secs_f64();
    Ok((secs, as_u64s(&buf, 4 * threads).to_vec()))
}

/// One command buffer, one serial compute encoder (each dispatch sees the
/// previous one's writes); `encode` records the dispatches.
fn run(c: &Ctx, encode: impl FnOnce(&metal::ComputeCommandEncoderRef) -> Result<(), String>) -> Result<(), String> {
    run_tagged(c, "other", encode)
}

/// [`run`], with a call-site tag for the [A7] timeline. The command buffer goes
/// to this thread's queue ([`Ctx::with_queue`]) and is waited for before
/// the call returns, as before: every later command buffer, on any queue, is
/// committed after this one completed, so the queue it ran on cannot reorder
/// any read against any write.
fn run_tagged(c: &Ctx, tag: &'static str, encode: impl FnOnce(&metal::ComputeCommandEncoderRef) -> Result<(), String>) -> Result<(), String> {
    let tl = TL_ON.load(Ordering::Relaxed);
    let begin = if tl { host_time_s() } else { 0.0 };
    c.with_queue(|queue, qi| {
        let cb = queue.new_command_buffer();
        let enc = cb.new_compute_command_encoder();
        let r = encode(enc);
        enc.end_encoding();
        r?;
        let committed = if tl { host_time_s() } else { 0.0 };
        cb.commit();
        wait_done(cb);
        let status = cb.status();
        if tl {
            tl_record(cb, tag, qi, begin, committed);
        }
        match status {
            MTLCommandBufferStatus::Completed => Ok(()),
            s => Err(format!("metal: command buffer ended {s:?}")),
        }
    })
}

// ------------------------------------------- [A7] queues and GPU timestamps
//
// (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A7; H121;
// `results/zk60_effplan_20261105/a7/README.md`.)
//
// QUEUES. `HL_METAL_QUEUES=shared` (the default) keeps the one process-wide queue
// every proof thread shares; `thread` (opt-in, [`DEFAULT_QUEUES`] says why) gives
// every thread its own queue, made at its first command buffer and released when the thread ends (a
// fork run's workers are fresh threads, so each fork worker has a queue of its
// own; the witness products keep their own queue, A4). No byte can
// move: every command buffer is still waited for by the thread that made it
// before that thread goes on (`run_tagged`), so nothing ever runs ahead of a
// write it reads, whichever queue carries it; the queue only decides which
// waiting command buffers the GPU may run side by side.
//
// TIMESTAMPS. Diagnostic only: while the timeline is on (tests:
// `gpu_timeline_start` .. `gpu_timeline_take`), each completed command buffer's
// `GPUStartTime` / `GPUEndTime` (host time, seconds) is kept with its thread,
// queue, call-site tag and the host times it was begun, committed and seen
// complete. Reading them after completion changes nothing the GPU computed; off,
// the cost is one relaxed load per command buffer. No value is read or kept.

/// [A7] queue modes: one shared queue, or one queue per thread
const Q_SHARED: usize = 1;
const Q_THREAD: usize = 2;
/// [A7] the mode when `HL_METAL_QUEUES` is unset: the one shared queue, as before
/// A7. Per-thread queues change the GPU's picture (W16R2 8B T128, 32 blocks, N = 6:
/// up to six command buffers at once instead of three, a finished one seen complete
/// 0.2 ms late instead of 1.7) but not the D55 wall. Interleaved in one process with
/// the arm order run both ways (the second arm of a pass ran about 4.5% faster
/// either way): the proof-only fork run about +1.4%, the 4-request stream's steady
/// state about -2.7% (`results/zk60_effplan_20261105/a7/README.md`). So they stay
/// an opt-in (`HL_METAL_QUEUES=thread`).
const DEFAULT_QUEUES: usize = Q_SHARED;
/// 0 until read from the environment (or set by a test)
static QUEUES: AtomicUsize = AtomicUsize::new(0);

/// [A7] `HL_METAL_QUEUES`: `shared` (or `1`) or `thread`; anything else, the default
fn queue_mode() -> usize {
    match QUEUES.load(Ordering::Relaxed) {
        0 => {
            let m = match std::env::var("HL_METAL_QUEUES").as_deref() {
                Ok("shared") | Ok("1") => Q_SHARED,
                Ok("thread") => Q_THREAD,
                _ => DEFAULT_QUEUES,
            };
            QUEUES.store(m, Ordering::Relaxed);
            m
        }
        m => m,
    }
}

/// tests: from now on every thread gets its own queue (`per_thread`) or all share
/// one; returns whether they had their own before. Changes no byte (see above).
#[cfg(test)]
pub fn set_queues_for_test(per_thread: bool) -> bool {
    let before = queue_mode() == Q_THREAD;
    QUEUES.store(if per_thread { Q_THREAD } else { Q_SHARED }, Ordering::Relaxed);
    before
}

/// tests: the queue mode in force, `shared` or `thread`
#[cfg(test)]
pub fn queues_for_test() -> &'static str {
    if queue_mode() == Q_THREAD {
        "thread"
    } else {
        "shared"
    }
}

/// this thread's serial number, from 0 in the order threads first ask
fn thread_serial() -> u32 {
    static NEXT: AtomicU32 = AtomicU32::new(0);
    thread_local! {
        static ME: u32 = NEXT.fetch_add(1, Ordering::Relaxed);
    }
    ME.with(|m| *m)
}

thread_local! {
    /// [A7] this thread's own queue (`HL_METAL_QUEUES=thread`), made at its first
    /// command buffer, released when the thread ends; `None` if Metal gave none
    /// (the thread then uses the shared queue)
    static OWN_QUEUE: std::cell::OnceCell<Option<CommandQueue>> = const { std::cell::OnceCell::new() };
}

impl Ctx {
    /// run `f` on the queue this thread's command buffers go to, with its number
    /// for the timeline (0: the shared queue; 1 + the thread's serial: its own)
    fn with_queue<R>(&self, f: impl FnOnce(&CommandQueue, u32) -> R) -> R {
        if queue_mode() != Q_THREAD {
            return f(&self.queue, 0);
        }
        OWN_QUEUE.with(|q| {
            let own = q.get_or_init(|| {
                use metal::foreign_types::ForeignType;
                let made = objc::rc::autoreleasepool(|| self.device.new_command_queue());
                (!made.as_ptr().is_null()).then_some(made)
            });
            match own {
                Some(own) => f(own, thread_serial() + 1),
                None => f(&self.queue, 0),
            }
        })
    }
}

/// [A7] the mach host clock in seconds, the clock of a command buffer's
/// `GPUStartTime` / `GPUEndTime` (`CACurrentMediaTime`'s)
pub fn host_time_s() -> f64 {
    #[repr(C)]
    struct Timebase {
        numer: u32,
        denom: u32,
    }
    extern "C" {
        fn mach_absolute_time() -> u64;
        fn mach_timebase_info(info: *mut Timebase) -> i32;
    }
    static SCALE: OnceLock<f64> = OnceLock::new();
    let s = *SCALE.get_or_init(|| {
        let mut tb = Timebase { numer: 0, denom: 0 };
        // SAFETY: writes the two fields of `tb`
        if unsafe { mach_timebase_info(&mut tb) } == 0 && tb.denom != 0 {
            tb.numer as f64 / tb.denom as f64 * 1e-9
        } else {
            1e-9
        }
    });
    // SAFETY: no preconditions
    let ticks = unsafe { mach_absolute_time() };
    ticks as f64 * s
}

/// a completed command buffer's (GPUStartTime, GPUEndTime), host seconds; a
/// failed message reads as zero
fn gpu_times(cb: &metal::CommandBufferRef) -> (f64, f64) {
    use objc::Message;
    // SAFETY: two CFTimeInterval (f64) getters of a completed command buffer
    unsafe {
        let t0: f64 = cb.send_message(objc::runtime::Sel::register("GPUStartTime"), ()).unwrap_or(0.0);
        let t1: f64 = cb.send_message(objc::runtime::Sel::register("GPUEndTime"), ()).unwrap_or(0.0);
        (t0, t1)
    }
}

/// [A7] one completed command buffer on the timeline (host seconds throughout)
#[derive(Clone, Copy, Debug)]
pub struct CbSpan {
    /// the call site (`commit`, `batch`, `round`, `fold`, `gather`, `wprod`, ...)
    pub tag: &'static str,
    /// [`thread_serial`] of the thread that made and waited for it
    pub thread: u32,
    /// 0: the shared queue; 1..: a per-thread queue; 99: the witness queue
    pub queue: u32,
    /// the host began encoding it
    pub begin: f64,
    /// the host committed it
    pub committed: f64,
    pub gpu_start: f64,
    pub gpu_end: f64,
    /// the waiting thread saw it complete
    pub done: f64,
}

static TL_ON: AtomicBool = AtomicBool::new(false);
static TL: Mutex<Vec<CbSpan>> = Mutex::new(Vec::new());

fn tl_record(cb: &metal::CommandBufferRef, tag: &'static str, queue: u32, begin: f64, committed: f64) {
    let done = host_time_s();
    let (gpu_start, gpu_end) = gpu_times(cb);
    if let Ok(mut g) = TL.lock() {
        g.push(CbSpan { tag, thread: thread_serial(), queue, begin, committed, gpu_start, gpu_end, done });
    }
}

/// tests: clear the timeline and start recording; returns the host time now
#[cfg(test)]
pub fn gpu_timeline_start() -> f64 {
    if let Ok(mut g) = TL.lock() {
        g.clear();
    }
    TL_ON.store(true, Ordering::SeqCst);
    host_time_s()
}

/// tests: stop recording and take what was recorded
#[cfg(test)]
pub fn gpu_timeline_take() -> Vec<CbSpan> {
    TL_ON.store(false, Ordering::SeqCst);
    TL.lock().map(|mut g| std::mem::take(&mut *g)).unwrap_or_default()
}

/// **[A7] what the GPU did over the host-time window `[a, b]`**: the time at
/// least one command buffer was executing (busy) against the window, the idle
/// gaps between, how many ran at once, and per call site, thread and queue the
/// command buffers' GPU time, their wait from commit to the GPU's start, and the
/// host's time between them. Every interval is clipped to the window.
#[cfg(test)]
pub fn gpu_timeline_report(spans: &[CbSpan], a: f64, b: f64) -> String {
    use std::fmt::Write;
    let wall = (b - a).max(0.0);
    let inw: Vec<&CbSpan> = spans.iter().filter(|s| s.gpu_end > a && s.gpu_start < b && s.gpu_end >= s.gpu_start && s.gpu_start > 0.0).collect();
    let clip = |s: &CbSpan| (s.gpu_start.max(a), s.gpu_end.min(b));
    // sweep: busy (>= 1 executing), time at >= 2, and the idle gaps
    let mut ev: Vec<(f64, i32)> = inw
        .iter()
        .flat_map(|s| {
            let (x, y) = clip(*s);
            [(x, 1), (y, -1)]
        })
        .collect();
    ev.sort_by(|p, q| p.0.partial_cmp(&q.0).unwrap().then(q.1.cmp(&p.1)));
    let (mut busy, mut multi, mut depth, mut last) = (0.0f64, 0.0f64, 0i32, a);
    let mut gaps: Vec<f64> = Vec::new();
    let mut depth_time = [0.0f64; 8];
    for &(t, d) in &ev {
        let dt = t - last;
        if depth == 0 {
            if dt > 0.0 {
                gaps.push(dt);
            }
        } else {
            busy += dt;
            if depth >= 2 {
                multi += dt;
            }
        }
        depth_time[(depth.max(0) as usize).min(7)] += dt;
        depth += d;
        last = t;
    }
    if b > last {
        gaps.push(b - last);
        depth_time[0] += b - last;
    }
    let sum_gpu: f64 = inw
        .iter()
        .map(|s| {
            let (x, y) = clip(*s);
            y - x
        })
        .sum();
    let mut o = String::new();
    let _ = writeln!(o, "  window {wall:.4} s: {} command buffers; GPU busy (>= 1 executing) {busy:.4} s = {:.1}%, idle {:.4} s = {:.1}%; summed command-buffer GPU time {sum_gpu:.4} s (mean {:.2} at once while busy); >= 2 at once {multi:.4} s = {:.1}% of busy", inw.len(), 100.0 * busy / wall.max(1e-12), wall - busy, 100.0 * (wall - busy) / wall.max(1e-12), sum_gpu / busy.max(1e-12), 100.0 * multi / busy.max(1e-12));
    let _ = writeln!(o, "  time at k executing: {}", (0..8).map(|k| format!("{k}{}: {:.4} s", if k == 7 { "+" } else { "" }, depth_time[k])).collect::<Vec<_>>().join(", "));
    let edges = [0.0, 20e-6, 50e-6, 200e-6, 1e-3, 5e-3, f64::INFINITY];
    let names = ["< 20 us", "20-50 us", "50-200 us", "0.2-1 ms", "1-5 ms", ">= 5 ms"];
    let hist: Vec<String> = (0..6)
        .map(|i| {
            let g: Vec<f64> = gaps.iter().cloned().filter(|&x| x >= edges[i] && x < edges[i + 1]).collect();
            format!("{} {} ({:.4} s)", names[i], g.len(), g.iter().fold(0.0f64, |s, x| s + x))
        })
        .collect();
    let longest = gaps.iter().cloned().fold(0.0f64, f64::max);
    let _ = writeln!(o, "  idle gaps: {} totalling {:.4} s, longest {:.2} ms; {}", gaps.len(), gaps.iter().sum::<f64>(), longest * 1e3, hist.join(", "));
    // per call site
    let mut tags: Vec<&str> = inw.iter().map(|s| s.tag).collect();
    tags.sort();
    tags.dedup();
    for t in tags {
        let v: Vec<&&CbSpan> = inw.iter().filter(|s| s.tag == t).collect();
        let g: f64 = v.iter().map(|s| s.gpu_end - s.gpu_start).sum();
        let qd: f64 = v.iter().map(|s| (s.gpu_start - s.committed).max(0.0)).sum();
        let cd: f64 = v.iter().map(|s| (s.done - s.gpu_end).max(0.0)).sum();
        let en: f64 = v.iter().map(|s| (s.committed - s.begin).max(0.0)).sum();
        let _ = writeln!(o, "  tag {t:<7} {:>5} cbs: GPU {g:.4} s (mean {:.3} ms); commit -> GPU start {qd:.4} s (mean {:.3} ms); GPU end -> seen {cd:.4} s; encode {en:.4} s", v.len(), 1e3 * g / v.len() as f64, 1e3 * qd / v.len() as f64);
    }
    // per thread: time inside run (begin .. done) and the host time between
    let mut ths: Vec<u32> = inw.iter().map(|s| s.thread).collect();
    ths.sort();
    ths.dedup();
    let mut lines = Vec::new();
    for th in ths {
        let mut v: Vec<&CbSpan> = spans.iter().filter(|s| s.thread == th && s.done > a && s.begin < b).collect();
        v.sort_by(|p, q| p.begin.partial_cmp(&q.begin).unwrap());
        let inside: f64 = v.iter().map(|s| s.done.min(b) - s.begin.max(a)).sum();
        let gpu: f64 = v.iter().map(|s| (s.gpu_end.min(b) - s.gpu_start.max(a)).max(0.0)).sum();
        let qd: f64 = v.iter().map(|s| (s.gpu_start - s.committed).max(0.0)).sum();
        let first = v.first().map(|s| s.begin.max(a)).unwrap_or(a);
        let lastd = v.last().map(|s| s.done.min(b)).unwrap_or(a);
        let qs: Vec<u32> = {
            let mut q: Vec<u32> = v.iter().map(|s| s.queue).collect();
            q.sort();
            q.dedup();
            q
        };
        lines.push(format!("t{th} q{qs:?} {} cbs, active {:.3} s: in run {inside:.3} s (GPU {gpu:.3}, commit -> start {qd:.3}), host between {:.3} s", v.len(), lastd - first, (lastd - first - inside).max(0.0)));
    }
    let _ = writeln!(o, "  per thread: {}", lines.join("; "));
    // per queue: did command buffers of one queue ever execute side by side?
    let mut qs: Vec<u32> = inw.iter().map(|s| s.queue).collect();
    qs.sort();
    qs.dedup();
    for q in qs {
        let mut v: Vec<&&CbSpan> = inw.iter().filter(|s| s.queue == q).collect();
        v.sort_by(|x, y| x.gpu_start.partial_cmp(&y.gpu_start).unwrap());
        let (mut overlap, mut end) = (0usize, f64::NEG_INFINITY);
        for s in &v {
            if s.gpu_start < end {
                overlap += 1;
            }
            end = end.max(s.gpu_end);
        }
        let _ = writeln!(o, "  queue {q}: {} cbs, {overlap} started before the queue's earlier ones had all ended", v.len());
    }
    o
}

/// [A7] the wait policy: [`WAIT_SPIN`] spins on the status for as long as it
/// takes (M5d), 0 blocks in `waitUntilCompleted`, `n` spins `n` microseconds
/// and then blocks; [`WAIT_UNREAD`] until read from the environment
const WAIT_UNREAD: u64 = u64::MAX;
const WAIT_SPIN: u64 = u64::MAX - 1;
static WAIT: AtomicU64 = AtomicU64::new(WAIT_UNREAD);

/// `HL_METAL_SPIN=0`: block; `HL_METAL_SPIN_US=n`: spin `n` us, then block;
/// otherwise spin (M5d's default)
fn wait_mode() -> u64 {
    match WAIT.load(Ordering::Relaxed) {
        WAIT_UNREAD => {
            let m = if std::env::var("HL_METAL_SPIN").map(|v| v == "0").unwrap_or(false) {
                0
            } else {
                std::env::var("HL_METAL_SPIN_US").ok().and_then(|v| v.parse::<u64>().ok()).filter(|&us| us < WAIT_SPIN).unwrap_or(WAIT_SPIN)
            };
            WAIT.store(m, Ordering::Relaxed);
            m
        }
        m => m,
    }
}

/// tests: the wait policy from now on (`None`: spin until done; `Some(0)`: block;
/// `Some(n)`: spin `n` us, then block); returns the previous one. Only how the
/// host waits changes: the same command buffer, the same results.
#[cfg(test)]
pub fn set_wait_for_test(spin_us: Option<u64>) -> Option<u64> {
    let before = match wait_mode() {
        WAIT_SPIN => None,
        m => Some(m),
    };
    WAIT.store(spin_us.map(|us| us.min(WAIT_SPIN - 1)).unwrap_or(WAIT_SPIN), Ordering::Relaxed);
    before
}

/// **[M5d] Wait for a committed command buffer by spinning on its status**
/// instead of `waitUntilCompleted`, whose thread sleep and wake-up cost
/// hundreds of microseconds per call. A block makes about 190 device sumcheck
/// rounds, each ending in one such wait (researcher H113). Only the waiting
/// changes: the same command buffer, the same results. `HL_METAL_SPIN=0`
/// restores the blocking wait; [A7] `HL_METAL_SPIN_US=n` spins `n` us and then
/// blocks (a spinning thread holds a core the fork run's host work could use).
fn wait_done(cb: &metal::CommandBufferRef) {
    let m = wait_mode();
    if m == 0 {
        cb.wait_until_completed();
        return;
    }
    let t0 = if m == WAIT_SPIN { None } else { Some(std::time::Instant::now()) };
    loop {
        match cb.status() {
            MTLCommandBufferStatus::Completed | MTLCommandBufferStatus::Error => return,
            _ => {
                if let Some(t0) = t0 {
                    if t0.elapsed().as_micros() as u64 >= m {
                        cb.wait_until_completed();
                        return;
                    }
                }
                std::hint::spin_loop()
            }
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
        if device_fold_on() {
            return fold_rows_device(buf, self.rows, self.n, nn, ir, rhos);
        }
        let t = std::time::Instant::now();
        let src = as_u64s(buf, self.rows * nn);
        #[cfg(test)]
        if let Some(c) = FOLD_CAPTURE.lock().expect("the fold capture").as_mut() {
            c.push(FoldCapture { rows: self.rows, n: self.n, nn, ir, src: src.to_vec(), rhos: rhos.to_vec(), pads: None });
        }
        let out = fold_rows_host_by_form(src, self.rows, self.n, nn, ir, rhos);
        if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
            eprintln!("[ZK60-METAL] store fold: {} rho x {} rows x {} cols ({}) in {:.4} s", rhos.len(), self.rows, self.n, if self.data.is_some() { "zk data" } else { "systematic" }, t.elapsed().as_secs_f64());
        }
        Ok(out)
    }

    /// **[A8]** the hiding opening's vectors `rho^T [M | pads]` in ONE parallel
    /// pass ([`fold_segments_a8`]: the data rows' chunks and the pad rows'
    /// chunks together, written straight into vectors of their final length).
    /// Before A8 the core folded the pads afterwards on ONE thread (`q = 280`
    /// columns are a single chunk of its host fold) and grew every vector to
    /// append them. The same values (see `EncodedStore::fold_rows_with_pads`).
    /// `None` (the core's path, as before) under the M11 forms, the device
    /// fold or the plain (systematic) form.
    pub fn fold_rows_with_pads(&self, rhos: &[Vec<Fp2>], pads: &[Fp], q: usize) -> Option<Result<Vec<Vec<Fp2>>, String>> {
        let small = match a8_fold_form() {
            A8Form::M11 => return None,
            A8Form::Sparse => false,
            A8Form::Small => true,
        };
        let data = match &self.data {
            Some(d) if !device_fold_on() => d,
            _ => return None,
        };
        if let Some(r) = rhos.iter().find(|r| r.len() < self.rows) {
            return Some(Err(format!("metal fold: rho of {} entries for {} rows", r.len(), self.rows)));
        }
        if pads.len() != self.rows * q {
            return Some(Err(format!("metal fold: {} pad words for {} rows x q = {q}", pads.len(), self.rows)));
        }
        let t = std::time::Instant::now();
        let src = as_u64s(data, self.rows * self.n);
        // SAFETY: Fp is repr(transparent) over u64
        let pw: &[u64] = unsafe { std::slice::from_raw_parts(pads.as_ptr() as *const u64, pads.len()) };
        #[cfg(test)]
        if let Some(c) = FOLD_CAPTURE.lock().expect("the fold capture").as_mut() {
            c.push(FoldCapture { rows: self.rows, n: self.n, nn: self.n, ir: 1, src: src.to_vec(), rhos: rhos.to_vec(), pads: Some((pw.to_vec(), q)) });
        }
        let segs = [A8Seg { src, n: self.n, nn: self.n, ir: 1 }, A8Seg { src: pw, n: q, nn: q, ir: 1 }];
        let out = fold_segments_a8_opts(&segs, self.rows, rhos, a8_opts(self.n, small));
        if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
            eprintln!("[ZK60-METAL] store fold with pads ({:?}): {} rho x {} rows x ({} + {q}) cols (zk data) in {:.4} s", a8_fold_form(), rhos.len(), self.rows, self.n, t.elapsed().as_secs_f64());
        }
        Some(Ok(out))
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
            run_tagged(c, "devfold", |enc| {
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
        run_tagged(c, "gather", |e| {
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

/// [A7] tests: 0 lets `HL_METAL_DEVICE_FOLD=1` decide (read at each fold, as
/// before), 1 keeps the host fold, 2 takes the device fold
static DEVICE_FOLD_TEST: AtomicUsize = AtomicUsize::new(0);

/// whether the opening's row fold runs on the device (equal values either way)
fn device_fold_on() -> bool {
    match DEVICE_FOLD_TEST.load(Ordering::Relaxed) {
        1 => false,
        2 => true,
        _ => std::env::var("HL_METAL_DEVICE_FOLD").map(|v| v == "1").unwrap_or(false),
    }
}

/// tests: the opening's row fold on the device (`Some(true)`), on the host
/// (`Some(false)`), or as the environment says (`None`)
#[cfg(test)]
pub fn set_device_fold_for_test(on: Option<bool>) {
    DEVICE_FOLD_TEST.store(
        match on {
            None => 0,
            Some(false) => 1,
            Some(true) => 2,
        },
        Ordering::Relaxed,
    );
}

/// [M11] the most rho vectors the opening fold takes the lazy form for
const LAZY_FOLD_MAX_RHOS: usize = 16;

/// [M11] `HL_METAL_LAZY_FOLD=0` keeps the per-term field arithmetic of the
/// opening's row fold, for a same-binary A/B
fn lazy_fold_on() -> bool {
    static ON: OnceLock<bool> = OnceLock::new();
    *ON.get_or_init(|| std::env::var("HL_METAL_LAZY_FOLD").map(|v| v != "0").unwrap_or(true))
}

/// **[ZK60-METAL M11]** [`fold_rows_host`] with ONE reduction per output
/// entry. Each component's sum `sum_i rho_g[i].c * src[i][j]` is formed as an
/// exact integer: every product of two canonical words fits a u128, and the
/// u128 overflows are counted in a u64 `H`, so the integer is `L + 2^128 H`.
/// Its value mod p is `(L mod p) + H (2^128 mod p)`, which is the field sum
/// the per-term form computes. The same chunking of the columns.
pub fn fold_rows_host_lazy(src: &[u64], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    let k = rhos.len();
    let chunk = 256usize.min(n);
    let n_chunks = n.div_ceil(chunk);
    let t64 = Fp::from_u128(1u128 << 64);
    let c128 = t64.mul(t64);
    let red = |l: u128, h: u64| Fp::from_u128(l).add(Fp::new(h).mul(c128));
    let parts: Vec<Vec<Vec<Fp2>>> = (0..n_chunks)
        .into_par_iter()
        .map(|ci| {
            let c0 = ci * chunk;
            let w = chunk.min(n - c0);
            let mut lo = vec![0u128; k * w * 2];
            let mut hi = vec![0u64; k * w * 2];
            for i in 0..rows {
                let row = &src[i * nn..(i + 1) * nn];
                for (g, rho) in rhos.iter().enumerate() {
                    let r = rho[i];
                    if r.is_zero() {
                        continue;
                    }
                    let (r0, r1) = (r.c0.0 as u128, r.c1.0 as u128);
                    let (lo_g, hi_g) = (&mut lo[g * w * 2..(g + 1) * w * 2], &mut hi[g * w * 2..(g + 1) * w * 2]);
                    for j in 0..w {
                        let v = row[(c0 + j) * ir] as u128;
                        let (s0, o0) = lo_g[2 * j].overflowing_add(r0 * v);
                        lo_g[2 * j] = s0;
                        hi_g[2 * j] += o0 as u64;
                        let (s1, o1) = lo_g[2 * j + 1].overflowing_add(r1 * v);
                        lo_g[2 * j + 1] = s1;
                        hi_g[2 * j + 1] += o1 as u64;
                    }
                }
            }
            (0..k).map(|g| (0..w).map(|j| Fp2::new(red(lo[g * w * 2 + 2 * j], hi[g * w * 2 + 2 * j]), red(lo[g * w * 2 + 2 * j + 1], hi[g * w * 2 + 2 * j + 1]))).collect()).collect()
        })
        .collect();
    let mut out = vec![vec![Fp2::ZERO; n]; k];
    for (ci, p) in parts.into_iter().enumerate() {
        let c0 = ci * chunk;
        for g in 0..k {
            out[g][c0..c0 + p[g].len()].copy_from_slice(&p[g]);
        }
    }
    out
}

/// [M11, tests] the per-term host fold, for the equality test
#[cfg(test)]
pub fn fold_rows_host_for_test(src: &[u64], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    fold_rows_host(src, rows, n, nn, ir, rhos)
}

/// [M11] the forms before A8: the lazy form for a few rho vectors (10 x 2606
/// rows 13.4 -> 8.7 ms); at 37 vectors it was no faster (8.3 -> 8.7 ms;
/// narrower chunks 15 ms), so many vectors kept the per-term form
/// (`logs/m11/fold_*.log`)
fn fold_rows_host_m11(src: &[u64], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    if lazy_fold_on() && rhos.len() <= LAZY_FOLD_MAX_RHOS {
        fold_rows_host_lazy(src, rows, n, nn, ir, rhos)
    } else {
        fold_rows_host(src, rows, n, nn, ir, rhos)
    }
}

/// [M11, tests] the forms before A8, as the opening chose them
#[cfg(test)]
pub fn fold_rows_host_m11_for_test(src: &[u64], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    fold_rows_host_m11(src, rows, n, nn, ir, rhos)
}

/// the opening's host fold, in the form the A8 switch selects (equal values)
fn fold_rows_host_by_form(src: &[u64], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    match a8_fold_form() {
        A8Form::M11 => fold_rows_host_m11(src, rows, n, nn, ir, rhos),
        A8Form::Sparse => fold_rows_host_a8(src, rows, n, nn, ir, rhos, a8_opts(n, false)),
        A8Form::Small => fold_rows_host_a8(src, rows, n, nn, ir, rhos, a8_opts(n, true)),
    }
}

/// [A8] the opening fold's host form. Every form returns the same canonical
/// words (each output entry is the field sum `sum_i rho_g[i] * src[i][j]`,
/// formed exactly; only how it is formed differs)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum A8Form {
    /// the M11 forms (lazy for at most 16 vectors, per-term above)
    M11,
    /// the row-sparse lazy form ([`fold_rows_host_a8`] without the small-word path)
    Sparse,
    /// the row-sparse lazy form with the 16-bit small-word path
    Small,
}

/// [A8, tests] 0 lets `HL_METAL_A8_FOLD` decide; 1 + the form's index otherwise
static A8_FORM_TEST: AtomicUsize = AtomicUsize::new(0);

/// [A8] `HL_METAL_A8_FOLD=m11|sparse|small` (read once); the default is the
/// small-word form (the in-process A/B at N = 6, both arm orders:
/// `results/zk60_effplan_20261105/a8/`); `m11` restores the forms before A8
fn a8_fold_form() -> A8Form {
    match A8_FORM_TEST.load(Ordering::Relaxed) {
        1 => A8Form::M11,
        2 => A8Form::Sparse,
        3 => A8Form::Small,
        _ => {
            static F: OnceLock<A8Form> = OnceLock::new();
            *F.get_or_init(|| match std::env::var("HL_METAL_A8_FOLD").as_deref() {
                Ok("m11") => A8Form::M11,
                Ok("sparse") => A8Form::Sparse,
                _ => A8Form::Small,
            })
        }
    }
}

/// [A8, tests] the opening fold's host form for this process (`None`: as the
/// environment says); returns the previous setting
#[cfg(test)]
pub fn set_a8_fold_for_test(form: Option<A8Form>) -> Option<A8Form> {
    let v = match form {
        None => 0,
        Some(A8Form::M11) => 1,
        Some(A8Form::Sparse) => 2,
        Some(A8Form::Small) => 3,
    };
    match A8_FORM_TEST.swap(v, Ordering::Relaxed) {
        1 => Some(A8Form::M11),
        2 => Some(A8Form::Sparse),
        3 => Some(A8Form::Small),
        _ => None,
    }
}

/// [A8, tests] the inputs of one host store fold (the census and the bench)
#[cfg(test)]
pub struct FoldCapture {
    pub rows: usize,
    pub n: usize,
    pub nn: usize,
    pub ir: usize,
    pub src: Vec<u64>,
    pub rhos: Vec<Vec<Fp2>>,
    /// the hiding opening's pads (rows x q, row-major) and q, when the fold
    /// took them too (`fold_rows_with_pads`)
    pub pads: Option<(Vec<u64>, usize)>,
}

#[cfg(test)]
static FOLD_CAPTURE: Mutex<Option<Vec<FoldCapture>>> = Mutex::new(None);

/// [A8, tests] start (`true`) or stop capturing the host store folds' inputs;
/// returns what was captured since the last call
#[cfg(test)]
pub fn fold_capture_for_test(on: bool) -> Vec<FoldCapture> {
    let mut g = FOLD_CAPTURE.lock().expect("the fold capture");
    let got = g.take().unwrap_or_default();
    if on {
        *g = Some(Vec::new());
    }
    got
}

/// **[A8] the opening fold's options**, as measured on the W16R2 8B T128
/// block's two store folds (`results/zk60_effplan_20261105/a8/`, stages 1 and
/// 1b): chunks of 256 columns, the next row's slice prefetched, the small-word
/// lanes in NEON. The fold is bound by the memory latency at each row's start
/// (every row's slice of a chunk is a page away from the last one's), not by
/// its accumulators: narrow chunks that keep the accumulators in L1 were up to
/// 2x slower, and one row of prefetch took a 6-thread pool's A fold from 21.7
/// to 14.1 ms (row-sparse) and to 9.9 ms with the small-word path.
pub fn a8_opts(n: usize, small: bool) -> A8Opts {
    A8Opts { w: 256usize.min(n.max(1)), small, pf: 1, neon: true }
}

/// the half-width of the small-word path: a word is small if it is a signed
/// integer `x` with `-2^15 <= x < 2^15` (that is `v < 2^15` or `v >= p - 2^15`)
const A8_SMALL_HALF: u64 = 1 << 15;

/// a canonical word `v` as `(x + 2^15) mod p` for its signed representative
/// `x`: below `2^16` exactly when the word is small (`v + 2^15` cannot wrap a
/// u64, as `v < p`)
#[inline(always)]
fn a8_shifted(v: u64) -> u64 {
    let t = v + A8_SMALL_HALF;
    if t >= crate::field::P {
        t - crate::field::P
    } else {
        t
    }
}

/// one rayon split's scratch for [`fold_rows_host_a8`] (reused across its chunks)
#[derive(Default)]
struct A8Scratch {
    lo: Vec<u128>,
    hi: Vec<u64>,
    sm: Vec<u64>,
    csum: Vec<u128>,
    vs: Vec<u32>,
    row: Vec<u64>,
}

/// **[A8] the opening's row fold, row-sparse and exact.** The same canonical
/// words as [`fold_rows_host`]: every output entry is the field sum
/// `sum_i rho_g[i] * src[i][j]` (per component), formed here as an exact
/// integer and reduced once. Only how the sum is formed differs:
/// - each row's nonzero coefficients are listed once (`terms`), so a row is
///   read once per column chunk and each of its vectors touches it without a
///   zero test per vector and row (the u128 form of [`fold_rows_host_lazy`]
///   for every vector count; the M11 per-term form above 16 vectors is gone);
/// - the slice of the row `pf` rows ahead is prefetched ([`A8Opts`],
///   [`a8_opts`]: the fold waits on each row's first lines otherwise);
/// - the outputs are written in place (no per-chunk vectors to copy);
/// - `small`: a row chunk whose words are all small signed integers
///   (`-2^15 <= x < 2^15`) is summed as `x + 2^15 < 2^16` against the
///   coefficient's two 32-bit halves in u64 lanes (products below 2^48, fewer
///   than 2^16 rows, so no lane overflows), and `2^15 * sum_i rho_g[i]` over
///   those rows is subtracted once per vector and chunk. That is the same
///   integer sum, so the same field value. Every other row chunk takes the
///   u128 form of [`fold_rows_host_lazy`].
#[allow(clippy::too_many_arguments)]
pub fn fold_rows_host_a8(src: &[u64], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>], opts: A8Opts) -> Vec<Vec<Fp2>> {
    fold_segments_a8_opts(&[A8Seg { src, n, nn, ir }], rows, rhos, opts)
}

/// [A8] one column segment of a fold: `n` columns whose entry `j` of row `i`
/// is `src[i * nn + j * ir]`
#[derive(Clone, Copy)]
pub struct A8Seg<'a> {
    pub src: &'a [u64],
    pub n: usize,
    pub nn: usize,
    pub ir: usize,
}

/// [A8] how [`fold_segments_a8_opts`] forms the same sums (equal values every way)
#[derive(Clone, Copy, Debug)]
pub struct A8Opts {
    /// the chunk width (columns per task)
    pub w: usize,
    /// the 16-bit small-word path
    pub small: bool,
    /// prefetch the slice of the row this many rows ahead (0: none)
    pub pf: usize,
    /// the small-word lanes in explicit NEON (aarch64) instead of the scalar loop
    pub neon: bool,
}

/// [A8, tests] [`fold_segments_a8_opts`] at chunk width `w`, without the
/// prefetch and with the scalar small-word lanes
#[cfg(test)]
pub fn fold_segments_a8(segs: &[A8Seg<'_>], rows: usize, rhos: &[Vec<Fp2>], w: usize, small: bool) -> Vec<Vec<Fp2>> {
    fold_segments_a8_opts(segs, rows, rhos, A8Opts { w, small, pf: 0, neon: false })
}

/// [A8] a prefetch hint for the cache line holding `p` (`prfm`: no
/// architectural effect, never faults)
#[inline(always)]
fn a8_prefetch(p: &u64) {
    #[cfg(target_arch = "aarch64")]
    // SAFETY: `prfm` only hints the cache; it reads and writes nothing
    // architecturally and cannot fault (and `p` is a live reference)
    unsafe {
        std::arch::asm!("prfm pldl1keep, [{0}]", in(reg) p as *const u64, options(nostack, preserves_flags, readonly));
    }
    #[cfg(not(target_arch = "aarch64"))]
    let _ = p;
}

/// [A8] the small-word lanes: `a[j] += l0 * v[j]`, `b[j] += h0 * v[j]`,
/// `c[j] += l1 * v[j]`, `e[j] += h1 * v[j]` (u32 x u32 -> u64), in NEON's
/// widening multiply-accumulate on aarch64; the same integers as the scalar loop
#[inline(always)]
#[allow(clippy::too_many_arguments)]
fn a8_small_lanes(a: &mut [u64], b: &mut [u64], c: &mut [u64], e: &mut [u64], vs: &[u32], l0: u32, h0: u32, l1: u32, h1: u32, neon: bool) {
    let n = vs.len();
    assert!(a.len() >= n && b.len() >= n && c.len() >= n && e.len() >= n);
    let mut j = 0usize;
    #[cfg(target_arch = "aarch64")]
    if neon {
        use std::arch::aarch64::*;
        let n4 = n & !3;
        // SAFETY: NEON is part of the aarch64 base ISA; every pointer below
        // addresses entries j..j + 4 <= n4 <= n of a slice holding at least n
        unsafe {
            while j < n4 {
                let v = vld1q_u32(vs.as_ptr().add(j));
                let vl = vget_low_u32(v);
                let pa = a.as_mut_ptr().add(j);
                vst1q_u64(pa, vmlal_n_u32(vld1q_u64(pa), vl, l0));
                vst1q_u64(pa.add(2), vmlal_high_n_u32(vld1q_u64(pa.add(2)), v, l0));
                let pb = b.as_mut_ptr().add(j);
                vst1q_u64(pb, vmlal_n_u32(vld1q_u64(pb), vl, h0));
                vst1q_u64(pb.add(2), vmlal_high_n_u32(vld1q_u64(pb.add(2)), v, h0));
                let pc = c.as_mut_ptr().add(j);
                vst1q_u64(pc, vmlal_n_u32(vld1q_u64(pc), vl, l1));
                vst1q_u64(pc.add(2), vmlal_high_n_u32(vld1q_u64(pc.add(2)), v, l1));
                let pe = e.as_mut_ptr().add(j);
                vst1q_u64(pe, vmlal_n_u32(vld1q_u64(pe), vl, h1));
                vst1q_u64(pe.add(2), vmlal_high_n_u32(vld1q_u64(pe.add(2)), v, h1));
                j += 4;
            }
        }
    }
    #[cfg(not(target_arch = "aarch64"))]
    let _ = neon;
    for ((((x, y), z), t), &v) in a[j..n].iter_mut().zip(b[j..n].iter_mut()).zip(c[j..n].iter_mut()).zip(e[j..n].iter_mut()).zip(vs[j..n].iter()) {
        *x += (l0 as u64) * (v as u64);
        *y += (h0 as u64) * (v as u64);
        *z += (l1 as u64) * (v as u64);
        *t += (h1 as u64) * (v as u64);
    }
}

/// [A8] [`fold_rows_host_a8`] over several column segments at once (the
/// hiding opening's message rows, then its pad rows): each output vector is
/// the segments' folds one after another, `sum_s n_s` entries, formed in ONE
/// parallel pass over every segment's chunks, as [`A8Opts`] says (the same
/// values every way)
pub fn fold_segments_a8_opts(segs: &[A8Seg<'_>], rows: usize, rhos: &[Vec<Fp2>], opts: A8Opts) -> Vec<Vec<Fp2>> {
    let A8Opts { w, small, pf, neon } = opts;
    let k = rhos.len();
    let total: usize = segs.iter().map(|s| s.n).sum();
    let mut out: Vec<Vec<Fp2>> = (0..k).into_par_iter().map(|_| vec![Fp2::ZERO; total]).collect();
    if k == 0 || total == 0 || rows == 0 {
        return out;
    }
    for s in segs {
        assert!(s.n == 0 || (s.ir >= 1 && s.src.len() >= (rows - 1) * s.nn + (s.n - 1) * s.ir + 1), "a8 fold: a segment's source is too short");
    }
    // u64 small-word lanes hold fewer than 2^16 rows of products below 2^48
    let small = small && rows < (1 << 16);
    // row i's nonzero coefficients, in vector order: terms[starts[i]..starts[i + 1]]
    let mut starts = Vec::with_capacity(rows + 1);
    let mut terms: Vec<(u64, u64, u32)> = Vec::new();
    starts.push(0usize);
    for i in 0..rows {
        for (g, rho) in rhos.iter().enumerate() {
            let r = rho[i];
            if !r.is_zero() {
                terms.push((r.c0.0, r.c1.0, g as u32));
            }
        }
        starts.push(terms.len());
    }
    let w = w.max(1);
    let t64 = Fp::from_u128(1u128 << 64);
    let c128 = t64.mul(t64);
    let red = |l: u128, h: u64| Fp::from_u128(l).add(Fp::new(h).mul(c128));
    let half = Fp::new(A8_SMALL_HALF);
    // the chunks: (segment, first column) for every w columns of each segment
    let chunks: Vec<(usize, usize)> = segs.iter().enumerate().flat_map(|(si, s)| (0..s.n.div_ceil(w)).map(move |c| (si, c * w))).collect();
    // each chunk's k output slices, so every chunk writes its own columns
    let mut dst: Vec<Vec<&mut [Fp2]>> = (0..chunks.len()).map(|_| Vec::with_capacity(k)).collect();
    for o in out.iter_mut() {
        let mut rest: &mut [Fp2] = o.as_mut_slice();
        let mut ci = 0usize;
        for s in segs {
            let (seg, tail) = std::mem::take(&mut rest).split_at_mut(s.n);
            rest = tail;
            for piece in seg.chunks_mut(w) {
                dst[ci].push(piece);
                ci += 1;
            }
        }
    }
    dst.into_par_iter().zip(chunks.into_par_iter()).for_each_init(A8Scratch::default, |sc, (mut d, (si, c0))| {
        let A8Seg { src, nn, ir, .. } = segs[si];
        let wc = d[0].len();
        // the u128 sums and their overflow counts, per vector: [2 * wc] each;
        // the small-word sums, per vector: four [wc] lanes (the low and high
        // coefficient halves of each component), and the coefficients' sums
        sc.lo.clear();
        sc.lo.resize(k * 2 * wc, 0);
        sc.hi.clear();
        sc.hi.resize(k * 2 * wc, 0);
        if small {
            sc.sm.clear();
            sc.sm.resize(k * 4 * wc, 0);
            sc.csum.clear();
            sc.csum.resize(k * 2, 0);
            sc.vs.resize(wc, 0);
        }
        if ir != 1 {
            sc.row.resize(wc, 0);
        }
        let A8Scratch { lo, hi, sm, csum, vs, row } = sc;
        for i in 0..rows {
            // the slice of the row `pf` rows ahead, one hint per 128-byte line:
            // each row's slice starts a page away from the last one's, which the
            // hardware prefetcher does not follow
            if pf > 0 && ir == 1 && i + pf < rows {
                let nb = (i + pf) * nn + c0;
                let mut o = 0;
                while o < wc {
                    a8_prefetch(&src[nb + o]);
                    o += 16;
                }
            }
            let ts = &terms[starts[i]..starts[i + 1]];
            if ts.is_empty() {
                continue;
            }
            let base = i * nn + c0 * ir;
            let r: &[u64] = if ir == 1 {
                &src[base..base + wc]
            } else {
                for (j, v) in row[..wc].iter_mut().enumerate() {
                    *v = src[base + j * ir];
                }
                &row[..wc]
            };
            // the row chunk's words as x + 2^15, and whether all are small (a
            // chunk whose first word is not small is not looked at further:
            // rows of full-width words, such as all of H's, cost one test)
            let is_small = small && a8_shifted(r[0]) >> 16 == 0 && {
                let mut any_big = 0u64;
                for (o, &v) in vs[..wc].iter_mut().zip(r.iter()) {
                    let t = a8_shifted(v);
                    any_big |= t >> 16;
                    *o = t as u32;
                }
                any_big == 0
            };
            if is_small {
                for &(r0, r1, g) in ts {
                    let g = g as usize;
                    let (l0, h0, l1, h1) = (r0 as u32, (r0 >> 32) as u32, r1 as u32, (r1 >> 32) as u32);
                    let s = &mut sm[g * 4 * wc..(g + 1) * 4 * wc];
                    let (s_l0, s) = s.split_at_mut(wc);
                    let (s_h0, s) = s.split_at_mut(wc);
                    let (s_l1, s_h1) = s.split_at_mut(wc);
                    a8_small_lanes(s_l0, s_h0, s_l1, s_h1, &vs[..wc], l0, h0, l1, h1, neon);
                    csum[2 * g] += r0 as u128;
                    csum[2 * g + 1] += r1 as u128;
                }
            } else {
                for &(r0, r1, g) in ts {
                    let g = g as usize;
                    let (r0, r1) = (r0 as u128, r1 as u128);
                    let lo_g = &mut lo[g * 2 * wc..(g + 1) * 2 * wc];
                    let hi_g = &mut hi[g * 2 * wc..(g + 1) * 2 * wc];
                    for ((l, h), &v) in lo_g.chunks_exact_mut(2).zip(hi_g.chunks_exact_mut(2)).zip(r.iter()) {
                        let v = v as u128;
                        let (s0, o0) = l[0].overflowing_add(r0 * v);
                        l[0] = s0;
                        h[0] += o0 as u64;
                        let (s1, o1) = l[1].overflowing_add(r1 * v);
                        l[1] = s1;
                        h[1] += o1 as u64;
                    }
                }
            }
        }
        for (g, o) in d.iter_mut().enumerate() {
            let (lo_g, hi_g) = (&lo[g * 2 * wc..(g + 1) * 2 * wc], &hi[g * 2 * wc..(g + 1) * 2 * wc]);
            for (j, e) in o.iter_mut().enumerate() {
                *e = Fp2::new(red(lo_g[2 * j], hi_g[2 * j]), red(lo_g[2 * j + 1], hi_g[2 * j + 1]));
            }
            if small {
                // sum_i r_i (x_i + 2^15) = (low lanes) + 2^32 (high lanes), each
                // lane below 2^64; minus 2^15 sum_i r_i over the same rows
                let c = Fp2::new(Fp::from_u128(csum[2 * g]).mul(half), Fp::from_u128(csum[2 * g + 1]).mul(half));
                let s = &sm[g * 4 * wc..(g + 1) * 4 * wc];
                let (s_l0, s_h0, s_l1, s_h1) = (&s[..wc], &s[wc..2 * wc], &s[2 * wc..3 * wc], &s[3 * wc..]);
                for (j, e) in o.iter_mut().enumerate() {
                    let x0 = Fp::from_u128(s_l0[j] as u128 + ((s_h0[j] as u128) << 32));
                    let x1 = Fp::from_u128(s_l1[j] as u128 + ((s_h1[j] as u128) << 32));
                    *e = e.add(Fp2::new(x0, x1)).sub(c);
                }
            }
        }
    });
    out
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
        let hw = head_twiddle_buffers(c, ntt)?;
        let (hw_f, hw_i) = (hw.as_ref().map(|h| &h.0), hw.as_ref().map(|h| &h.1));
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
        run_tagged(c, "commit", |enc| {
            if !staged {
                // M2: two fused passes per transform (see metal_kernels.metal)
                encode_fused(c, enc, &d, None, None, &t, &tw_i, hw_i, rows64, log_n, log_n, MODE_COPY, 0, ntt.max_log, Some(ninv.0));
                match &zk_bufs {
                    None => encode_fused(c, enc, &t, None, None, &e, &tw_f, hw_f, rows64, log_nn, log_n, MODE_PLAIN, 0, ntt.max_log, None),
                    Some((pb, wb, q)) => {
                        encode_fused(c, enc, &t, Some(pb), Some(wb), &e, &tw_f, hw_f, rows64, log_nn, log_n, MODE_ZK, *q as u64, ntt.max_log, None)
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
                run_tagged(c, "diag", |enc| {
                    f(enc);
                    Ok(())
                })?;
                Ok(s.elapsed().as_secs_f64())
            };
            let inv = part(&|enc| {
                encode_fused(c, enc, &d, None, None, &t2, &tw_i, hw_i, rows64, log_n, log_n, MODE_COPY, 0, ntt.max_log, Some(ninv.0));
            })?;
            let init = 0.0f64; // fused into the forward head on the default path
            let fwd = part(&|enc| {
                encode_fused(c, enc, &t2, None, None, &e2, &tw_f, hw_f, rows64, log_nn, log_n, MODE_PLAIN, 0, ntt.max_log, None);
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
    /// [A12] the slot's tables' device build, not yet run: encoded ahead of
    /// the first command buffer that reads the tables (round 0's, the batch's)
    /// or run alone before the host reads them ([`MetalRounds::into_host`])
    prelude: Option<TabBuild>,
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
        prelude: None,
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
    /// [A12] `Some(ok)` once a device build ([`MetalTables::build_planned`])
    /// has checked every table round 0 keeps as a base-field word (`ok`: all
    /// their words have `c1 = 0`); `None`: [`metal_rounds_owned`] checks on
    /// the host, as before
    typed: Option<bool>,
    /// [A12] the tables the device is to build, by table index
    plan: Vec<TabJob>,
    /// [A12] a device build planned and prepared but not yet run: it runs
    /// ahead of the slot's first round ([`metal_rounds_owned`] hands it to the
    /// rounds) or alone ([`MetalTables::flush`]) before anything reads a table
    pending: Option<TabBuild>,
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
        Ok(MetalTables { buf, k, cap, typed: None, plan: Vec::new(), pending: None })
    }

    /// the `k` tables as disjoint mutable slices of `cap` elements each ([A12]
    /// a host write of every table: any device build's plan, pending build and
    /// base check are dropped)
    pub fn tables_mut(&mut self) -> Vec<&mut [Fp2]> {
        self.typed = None;
        self.plan.clear();
        self.pending = None;
        // SAFETY: `k * cap * 16` bytes of shared, CPU-visible memory owned by
        // `self` (page-aligned, so aligned for `Fp2`; the layout was checked in
        // `new`) and not in use by the GPU; any two words are an `Fp2` value,
        // and the builder overwrites every element before anything reads it.
        let all = unsafe { std::slice::from_raw_parts_mut(self.buf.contents() as *mut Fp2, self.k * self.cap) };
        all.chunks_mut(self.cap).collect()
    }

    /// host copies of the tables (the CPU path when the device declines)
    pub fn to_vecs(&self) -> Vec<Vec<Fp2>> {
        assert!(self.pending.is_none(), "[ZK60-METAL A12] the tables were read before their deferred device build ran");
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
    // [A12] a decline hands the tables to the host: a deferred device build
    // runs first (a failure there leaves no tables to hand: the attempt is refused)
    let fail = |mut t: MetalTables, why: Option<String>| -> Result<MetalRounds, (MetalTables, Option<String>)> {
        if let Err(e) = t.flush() {
            panic!("[ZK60-METAL A12] a deferred table build failed before a decline ({e}): the attempt is refused");
        }
        Err((t, why))
    };
    let c = match ctx() {
        Ok(c) => c,
        Err(e) => return fail(t, Some(e)),
    };
    if degree == 0 || base.len() != t.k {
        return fail(t, Some("metal sumcheck: degree 0 or base flags".into()));
    }
    let (pipe0, pipe) = match sc_pipelines(c, kernel_src, t.k, degree) {
        Ok(p) => p,
        Err(e) => return fail(t, Some(e)),
    };
    let t_setup = std::time::Instant::now();
    let (k, cap) = (t.k, t.cap);
    // the base-typing check the copy made, on the tables in place ([A12] or
    // its answer from the device build, which checked the same words)
    let typed_ok = match t.typed {
        Some(ok) => ok,
        None => {
            // SAFETY: as in `MetalTables::to_vecs`
            let all = unsafe { std::slice::from_raw_parts(t.buf.contents() as *const Fp2, k * cap) };
            all.par_chunks(cap).zip(base.par_iter()).all(|(tab, &b)| !b || tab.iter().all(|v| v.c1.0 == 0))
        }
    };
    if !typed_ok {
        return fail(t, None);
    }
    if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
        eprintln!("[ZK60-METAL] sumcheck setup (tables in place): {k} tables x 2^{} in {:.4} s", cap.trailing_zeros(), t_setup.elapsed().as_secs_f64());
    }
    let parts = match objc::rc::autoreleasepool(|| rounds_parts(c, cap, degree, coefs)) {
        Ok(p) => p,
        Err(e) => return fail(t, Some(e)),
    };
    let MetalTables { buf, pending, .. } = t;
    let mut r = assemble_rounds(buf, k, cap, degree, pipe0, pipe, parts);
    // [A12] the deferred build runs ahead of the first round
    r.prelude = pending;
    Ok(r)
}

// ------------------------------------ [A12] the device slots' tables, built on the device
//
// (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A12;
// `results/zk60_effplan_20261105/a12/README.md`.)
//
// WHAT. A device slot's tables (`private_block/argument.rs`, `build_tables_device`)
// written by two kernels instead of the host builder (`build_tables_into`):
// * an eq cube as the product of its point's two half tables, entry `x` being
//   `hi[y >> p_lo] * lo[y & (2^p_lo - 1)]` with `y = (x >> shift) & (2^p - 1)`
//   (the host's `eq_cube_split_into`, with the host's own half tables);
// * a committed plane's table, gathered from the committed rows through the
//   inverse bit map the host builder precomputes, `out[x] = sum_z eqf[z] *
//   v(inv(x & used) | zbits[z])` with `v(idx) = sum_s coef_s * data[off_s + idx]`
//   (the host's `priv_table_fill`; a plain store, `v(inv(x & used))`, when no
//   coordinate is fixed).
// The rows are read where they already are: `A`'s and `H`'s from their
// commitments' own device copies (`MetalCommit::resident_rows`, registered by
// `prove_core` for its slots), anything else through a no-copy view of the host
// slice's pages (or a pooled copy if Metal refuses the view). Mapping a fresh
// view of a 330 MB matrix for every slot cost about 2.2 ms of residency each
// (`results/zk60_effplan_20261105/a12/README.md`). Public tables, and any table
// the plan leaves out, are written by the host first (disjoint words; the
// device reads none of them). The build is then encoded AHEAD OF THE SLOT'S
// FIRST ROUND, in its own encoder of that round's (or batch's) command buffer
// (`MetalRounds::prelude`), so it costs no command buffer and no queue wait of
// its own; or, `HL_METAL_DEVICE_TABLES=sync`, in a command buffer of its own.
//
// WHY NO BYTE CAN MOVE. Every word is the canonical Goldilocks representative
// of the same field element the host builder writes: the same formula over the
// same inputs (the half tables, the bit maps, the eq weights and the slice
// coefficients are the host builder's own, made on the host), the same exact
// field operations (`gl_header` and `SC_PRELUDE`, the commit and round kernels'
// own), only the order of exact additions may differ. The resident copy is the
// copy the commitment encoded and its openings fold, of the same slice, and
// the slice cannot change while it is registered (it is borrowed). The base
// check `metal_rounds_owned` makes on the host is made by construction for the
// device's tables (a deferred build) or by the device (its own command
// buffer), and by the host for the host's; a deferred table the device then
// flags refuses the attempt. Nothing reads a table before the command buffer
// that built it completed. The tests compare every word of every table of every
// slot with the host builders (W16R2 8B, the W16R2 rung), in both forms, and
// prove the rung golden in every mode.

const TAB_SRC: &str = r#"
// [A12] the device slots' tables (gpu/metal.rs, TAB_SRC)
struct TabEqArgs {
    ulong out_off;   // the table's first word in `tabs`
    ulong cap;       // its length, elements
    ulong mask;      // 2^p - 1
    uint shift;      // n - start - p
    uint p_lo;       // the bottom half of the point
    uint hi_off;     // the top half's eq table in `aux64`, words
    uint lo_off;     // the bottom half's, words
    uint check;      // a table round 0 keeps as a base-field word
    uint pad0;
};
kernel void k_tab_eq(device ulong *tabs [[buffer(0)]],
                     device const ulong *aux64 [[buffer(1)]],
                     device atomic_uint *flag [[buffer(2)]],
                     constant TabEqArgs &a [[buffer(3)]],
                     uint gid [[thread_position_in_grid]]) {
    ulong x = ulong(gid);
    if (x >= a.cap) { return; }
    ulong y = (x >> a.shift) & a.mask;
    ulong h = ulong(a.hi_off) + 2UL * (y >> a.p_lo);
    ulong l = ulong(a.lo_off) + 2UL * (y & ((1UL << a.p_lo) - 1UL));
    fp2 v = f2_mul(f2(aux64[h], aux64[h + 1UL]), f2(aux64[l], aux64[l + 1UL]));
    ulong o = a.out_off + 2UL * x;
    tabs[o] = v.c0;
    tabs[o + 1UL] = v.c1;
    if (a.check != 0u && v.c1 != 0UL) { atomic_fetch_or_explicit(flag, 1u, memory_order_relaxed); }
}

struct TabPlaneArgs {
    ulong out_off;   // the table's first word in `tabs`
    ulong cap;       // its length, elements
    ulong used;      // the cube variables the plane reads
    ulong base;      // the committed data's first word in its view
    uint xlo;        // the low half of a cube index, bits
    uint nz;         // 2^(fixed coordinates); 0: a plain store, no eq weight
    uint ns;         // slices
    uint one;        // one slice, coefficient 1
    uint inv_lo;     // the inverse bit map's low half in `aux32`
    uint inv_hi;     // its high half
    uint zb;         // the fixed coordinates' index bits in `aux32`
    uint sl;         // the slices in `aux64`: (offset, c0, c1) each
    uint eqf;        // the fixed coordinates' eq table in `aux64`, words
    uint check;      // a table round 0 keeps as a base-field word
};
// sum over the slices of coef * data[off + idx], from zero (`priv_table_fill`'s fold)
inline fp2 tab_val(device const ulong *data, device const ulong *aux64, constant TabPlaneArgs &a, ulong idx) {
    if (a.one != 0u) { return f2(data[a.base + aux64[a.sl] + idx], 0UL); }
    fp2 v = f2(0UL, 0UL);
    for (uint s = 0u; s < a.ns; s++) {
        ulong w = ulong(a.sl) + 3UL * ulong(s);
        v = f2_add(v, f2_mulb(f2(aux64[w + 1UL], aux64[w + 2UL]), data[a.base + aux64[w] + idx]));
    }
    return v;
}
kernel void k_tab_plane(device ulong *tabs [[buffer(0)]],
                        device const ulong *data [[buffer(1)]],
                        device const uint *aux32 [[buffer(2)]],
                        device const ulong *aux64 [[buffer(3)]],
                        device atomic_uint *flag [[buffer(4)]],
                        constant TabPlaneArgs &a [[buffer(5)]],
                        uint gid [[thread_position_in_grid]]) {
    ulong x = ulong(gid);
    if (x >= a.cap) { return; }
    ulong xu = x & a.used;
    ulong im = ulong(aux32[a.inv_hi + uint(xu >> a.xlo)]) | ulong(aux32[a.inv_lo + uint(xu & ((1UL << a.xlo) - 1UL))]);
    fp2 v;
    if (a.nz == 0u) {
        v = tab_val(data, aux64, a, im);
    } else {
        v = f2(0UL, 0UL);
        for (uint z = 0u; z < a.nz; z++) {
            ulong e = ulong(a.eqf) + 2UL * ulong(z);
            v = f2_add(v, f2_mul(f2(aux64[e], aux64[e + 1UL]), tab_val(data, aux64, a, im | ulong(aux32[a.zb + z]))));
        }
    }
    ulong o = a.out_off + 2UL * x;
    tabs[o] = v.c0;
    tabs[o + 1UL] = v.c1;
    if (a.check != 0u && v.c1 != 0UL) { atomic_fetch_or_explicit(flag, 1u, memory_order_relaxed); }
}
"#;

#[repr(C)]
struct TabEqArgs {
    out_off: u64,
    cap: u64,
    mask: u64,
    shift: u32,
    p_lo: u32,
    hi_off: u32,
    lo_off: u32,
    check: u32,
    pad0: u32,
}

#[repr(C)]
struct TabPlaneArgs {
    out_off: u64,
    cap: u64,
    used: u64,
    base: u64,
    xlo: u32,
    nz: u32,
    ns: u32,
    one: u32,
    inv_lo: u32,
    inv_hi: u32,
    zb: u32,
    sl: u32,
    eqf: u32,
    check: u32,
}

/// [A12] one table of a slot the device builds ([`MetalTables::plan_eq`],
/// [`MetalTables::plan_plane`])
enum TabJob {
    Eq { t: usize, hi: Vec<Fp2>, lo: Vec<Fp2>, shift: u32, p: u32 },
    Plane { t: usize, src: usize, log: u32, slices: Vec<(usize, Fp2)>, used: u64, xlo: u32, inv_lo: Vec<u32>, inv_hi: Vec<u32>, zbits: Vec<u32>, eqf: Vec<Fp2> },
}

impl TabJob {
    fn table(&self) -> usize {
        match self {
            TabJob::Eq { t, .. } | TabJob::Plane { t, .. } => *t,
        }
    }
}

struct TabPipes {
    eq: ComputePipelineState,
    plane: ComputePipelineState,
}

static TAB_PIPES: OnceLock<Result<TabPipes, String>> = OnceLock::new();

/// [A12] the two table kernels, compiled once (the field code of the commit
/// and round kernels: `gl_header`, `SC_PRELUDE`)
fn tab_pipes(c: &Ctx) -> Result<&'static TabPipes, String> {
    TAB_PIPES
        .get_or_init(|| {
            objc::rc::autoreleasepool(|| {
                let src = format!("{}{SC_PRELUDE}\n{TAB_SRC}", gl_header());
                let lib = c.device.new_library_with_source(&src, &CompileOptions::new()).map_err(|e| format!("metal table kernels compile: {e}"))?;
                let mk = |name: &str| -> Result<ComputePipelineState, String> {
                    let f = lib.get_function(name, None).map_err(|e| format!("metal table function {name}: {e}"))?;
                    c.device.new_compute_pipeline_state_with_function(&f).map_err(|e| format!("metal table pipeline {name}: {e}"))
                };
                Ok(TabPipes { eq: mk("k_tab_eq")?, plane: mk("k_tab_plane")? })
            })
        })
        .as_ref()
        .map_err(|e| e.clone())
}

/// [A12] a pooled shared buffer holding `words` (a small auxiliary table)
fn upload_words<T: Copy>(c: &Ctx, words: &[T]) -> Result<PBuf, String> {
    let bytes = std::mem::size_of_val(words).max(16);
    let buf = shared_buffer(c, bytes as u64)?;
    // SAFETY: at least `size_of_val(words)` bytes of shared memory owned here,
    // not in use by the GPU; `T` is a plain integer type
    unsafe { std::ptr::copy_nonoverlapping(words.as_ptr() as *const u8, buf.contents() as *mut u8, std::mem::size_of_val(words)) };
    Ok(buf)
}

thread_local! {
    /// [A12] the committed rows this thread's block proof has registered as
    /// resident on the device ([`MetalCommit::resident_rows`]): (an id, the
    /// host slice's first word, its length in words, the commitment's own
    /// device copy of exactly those words)
    static RESIDENT: std::cell::RefCell<Vec<(u64, usize, usize, Buffer)>> = const { std::cell::RefCell::new(Vec::new()) };
}

/// [A12] the registration of [`MetalCommit::resident_rows`]: its entries leave
/// this thread's list when it drops. It borrows the host rows and their
/// commitments, so it cannot outlive them, and the rows cannot change while it
/// lives.
struct ResidentRows<'a> {
    ids: Vec<u64>,
    _rows: std::marker::PhantomData<&'a [Fp]>,
    /// not `Send`: the entries are this thread's and leave with its drop
    _here: std::marker::PhantomData<*const ()>,
}

impl Drop for ResidentRows<'_> {
    fn drop(&mut self) {
        let _ = RESIDENT.try_with(|r| r.borrow_mut().retain(|e| !self.ids.contains(&e.0)));
    }
}

impl MetalCommit {
    /// **[A12] While the returned value lives, the table kernels read each
    /// `rows` slice from its commitment's own device copy** (the hiding
    /// form's message rows, uploaded once for the commit and read by its
    /// openings) instead of mapping the host pages anew for every slot. A
    /// pair is registered only when the commitment holds that copy and it is
    /// exactly the slice's length; the kernels find it by the slice's address
    /// and length, on this thread only. The caller pairs each slice with the
    /// commitment made of it (`CommittedZk::data` and its store); the borrow
    /// keeps both alive and the rows unchanged for as long as it is held.
    pub fn resident_rows<'a>(pairs: &[(&'a [Fp], &'a MetalCommit)]) -> impl Sized + 'a {
        static NEXT: AtomicU64 = AtomicU64::new(1);
        let mut ids = Vec::new();
        RESIDENT.with(|r| {
            let mut r = r.borrow_mut();
            for (rows, mc) in pairs {
                if let Some(d) = &mc.data {
                    if !rows.is_empty() && mc.rows * mc.n == rows.len() && d.length() >= std::mem::size_of_val(*rows) as u64 {
                        let id = NEXT.fetch_add(1, Ordering::Relaxed);
                        r.push((id, rows.as_ptr() as usize, rows.len(), (**d).clone()));
                        ids.push(id);
                    }
                }
            }
        });
        ResidentRows { ids, _rows: std::marker::PhantomData, _here: std::marker::PhantomData }
    }
}

/// [A12] the commitment's resident copy of exactly `d`, if this thread registered one
fn resident(d: &[Fp]) -> Option<Buffer> {
    RESIDENT.with(|r| r.borrow().iter().find(|e| e.1 == d.as_ptr() as usize && e.2 == d.len()).map(|e| e.3.clone()))
}

/// **[A12] the largest committed slice the table kernels map anew** (words):
/// above it a slice is read only from a resident copy, and a build that would
/// need a larger view is left to the host. A fresh view of a block's 330 MB
/// matrix cost about 2.2 ms of residency per slot, more than the host build
/// (`results/zk60_effplan_20261105/a12/README.md`); the endpoints' 5 MB are cheap.
const TAB_VIEW_MAX_WORDS: usize = 1 << 22;

/// [A12] the committed data as the table kernel reads it, and `d`'s first
/// word in it: the commitment's resident copy when this thread registered one
/// for exactly `d` (word 0), else a read-only no-copy view of the whole pages
/// holding `d`, else a pooled copy (word 0). The caller keeps it until its
/// command buffer completed, while `d` is still borrowed.
fn data_buffer(c: &Ctx, d: &[Fp]) -> Result<(WeightBuf, u64), String> {
    if let Some(b) = resident(d) {
        TAB_BUILDS[5].fetch_add(1, Ordering::Relaxed);
        return Ok((WeightBuf::View(b), 0));
    }
    // SAFETY: `d`'s own bytes, read only
    let bytes = unsafe { std::slice::from_raw_parts(d.as_ptr() as *const i8, std::mem::size_of_val(d)) };
    if let Some((b, off)) = page_view(c, bytes) {
        if off % 8 == 0 {
            TAB_BUILDS[3].fetch_add(1, Ordering::Relaxed);
            return Ok((WeightBuf::View(b), off / 8));
        }
    }
    TAB_BUILDS[4].fetch_add(1, Ordering::Relaxed);
    Ok((WeightBuf::Copy(upload(c, d)?), 0))
}

/// [A12] how a slot's tables were built, for the A/B and the tests
/// (diagnostics): device builds, tables built on the device, tables the host
/// wrote beside them, no-copy data views, data copies, resident data, builds
/// deferred into the slot's first round command buffer, builds left to the
/// host (a large slice not resident)
static TAB_BUILDS: [AtomicU64; 8] = [const { AtomicU64::new(0) }; 8];

/// [A12] one table kernel's dispatch
enum TabArg {
    Eq(TabEqArgs),
    /// (the data source, the args with its base word filled in)
    Plane(usize, TabPlaneArgs),
}

/// **[A12] A device table build, ready to encode**: the dispatches, their
/// auxiliary tables, the committed data they read (kept alive until the
/// command buffer that ran them completed) and the base-check flag. Encoded in
/// a command buffer of its own ([`MetalTables::build_planned`] with
/// `defer = false`) or ahead of the slot's first round
/// ([`MetalRounds`]' `prelude`), in an encoder of its own: its dispatches run
/// concurrently (each writes only its own table), and the rounds' encoder after
/// it sees its writes (the buffers are hazard-tracked).
struct TabBuild {
    args: Vec<TabArg>,
    a32: PBuf,
    a64: PBuf,
    flag: PBuf,
    data: [Option<(WeightBuf, u64)>; 4],
    cap: u64,
}

impl TabBuild {
    fn encode(&self, c: &Ctx, cb: &metal::CommandBufferRef, tabs: &metal::BufferRef) -> Result<(), String> {
        let pipes = tab_pipes(c)?;
        let enc = cb.compute_command_encoder_with_dispatch_type(metal::MTLDispatchType::Concurrent);
        for a in &self.args {
            match a {
                TabArg::Eq(ea) => {
                    enc.set_compute_pipeline_state(&pipes.eq);
                    enc.set_buffer(0, Some(tabs), 0);
                    enc.set_buffer(1, Some(&self.a64), 0);
                    enc.set_buffer(2, Some(&self.flag), 0);
                    set_args(enc, 3, ea);
                    let tg = pipes.eq.max_total_threads_per_threadgroup().min(256).min(self.cap);
                    enc.dispatch_threads(MTLSize::new(self.cap, 1, 1), MTLSize::new(tg, 1, 1));
                }
                TabArg::Plane(src, pa) => {
                    let Some((vb, _)) = self.data[*src].as_ref() else {
                        enc.end_encoding();
                        return Err("metal tables: a plane without its data".into());
                    };
                    enc.set_compute_pipeline_state(&pipes.plane);
                    enc.set_buffer(0, Some(tabs), 0);
                    enc.set_buffer(1, Some(vb.buffer()), 0);
                    enc.set_buffer(2, Some(&self.a32), 0);
                    enc.set_buffer(3, Some(&self.a64), 0);
                    enc.set_buffer(4, Some(&self.flag), 0);
                    set_args(enc, 5, pa);
                    let tg = pipes.plane.max_total_threads_per_threadgroup().min(256).min(self.cap);
                    enc.dispatch_threads(MTLSize::new(self.cap, 1, 1), MTLSize::new(tg, 1, 1));
                }
            }
        }
        enc.end_encoding();
        Ok(())
    }

    /// whether a device table flagged base-field had a nonzero `c1` (read only
    /// after the command buffer that ran this build completed)
    fn flagged(&self) -> bool {
        // SAFETY: four bytes of shared memory the completed command buffer may have written
        unsafe { *(self.flag.contents() as *const u32) != 0 }
    }
}

/// **[A12] [`run_tagged`] with a table build encoded first**, in its own
/// encoder of the same command buffer (`pre`; none: exactly `run_tagged`).
fn run_tagged_pre(c: &Ctx, tag: &'static str, pre: Option<(&TabBuild, &metal::BufferRef)>, encode: impl FnOnce(&metal::ComputeCommandEncoderRef) -> Result<(), String>) -> Result<(), String> {
    let Some((tb, tabs)) = pre else { return run_tagged(c, tag, encode) };
    let tl = TL_ON.load(Ordering::Relaxed);
    let begin = if tl { host_time_s() } else { 0.0 };
    c.with_queue(|queue, qi| {
        let cb = queue.new_command_buffer();
        tb.encode(c, cb, tabs)?;
        let enc = cb.new_compute_command_encoder();
        let r = encode(enc);
        enc.end_encoding();
        r?;
        let committed = if tl { host_time_s() } else { 0.0 };
        cb.commit();
        wait_done(cb);
        let status = cb.status();
        if tl {
            tl_record(cb, tag, qi, begin, committed);
        }
        match status {
            MTLCommandBufferStatus::Completed => Ok(()),
            s => Err(format!("metal: command buffer ended {s:?}")),
        }
    })
}

impl MetalTables {
    /// [A12] (device builds, device tables, host tables beside them, no-copy
    /// data views, data copies, resident data, deferred builds, builds left to
    /// the host) since the process started (diagnostics)
    pub fn build_stats() -> [u64; 8] {
        std::array::from_fn(|i| TAB_BUILDS[i].load(Ordering::Relaxed))
    }

    /// **[A12]** plan table `t` as the eq cube of a point split in two
    /// halves: `hi` the eq table of its first `p - p / 2` coordinates, `lo` of
    /// its last `p / 2`, `shift = n - start - p`
    pub fn plan_eq(&mut self, t: usize, hi: Vec<Fp2>, lo: Vec<Fp2>, shift: usize, p: usize) {
        self.plan.push(TabJob::Eq { t, hi, lo, shift: shift as u32, p: p as u32 });
    }

    /// **[A12]** plan table `t` as a committed plane's table over data source
    /// `src` (`ProverData::data`'s index): `log` the plane's index bits,
    /// `slices` its (offset, coefficient) parts, `used` the cube variables it
    /// reads, `inv_lo` / `inv_hi` the inverse bit map's halves (split at
    /// `xlo` bits), `zbits` the fixed coordinates' index bits and `eqf` their
    /// eq table (empty for a plain store, `zbits` then `[0]`)
    #[allow(clippy::too_many_arguments)]
    pub fn plan_plane(&mut self, t: usize, src: usize, log: usize, slices: Vec<(usize, Fp2)>, used: usize, xlo: usize, inv_lo: Vec<u32>, inv_hi: Vec<u32>, zbits: Vec<u32>, eqf: Vec<Fp2>) {
        self.plan.push(TabJob::Plane { t, src, log: log as u32, slices, used: used as u64, xlo: xlo as u32, inv_lo, inv_hi, zbits, eqf });
    }

    /// the number of tables planned so far
    pub fn planned(&self) -> usize {
        self.plan.len()
    }

    /// [A12] the device build's base check (`None`: no device build since the
    /// last host write)
    pub fn base_checked(&self) -> Option<bool> {
        self.typed
    }

    /// [A12] whether a device build is still to run (deferred into the slot's
    /// first round command buffer)
    pub fn deferred(&self) -> bool {
        self.pending.is_some()
    }

    /// **[A12] Run a deferred device build now**, in a command buffer of its
    /// own (a slot that leaves the device after its tables were planned: the
    /// host then reads them). `Err`: the command buffer failed or the device
    /// found a base-flagged word with `c1 != 0`; the tables are then not the
    /// planned ones.
    pub fn flush(&mut self) -> Result<(), String> {
        let Some(tb) = self.pending.take() else { return Ok(()) };
        let c = ctx()?;
        let tabs: &metal::BufferRef = &self.buf;
        objc::rc::autoreleasepool(|| run_tagged_pre(c, "tables", Some((&tb, tabs)), |_| Ok(())))?;
        if tb.flagged() {
            return Err("metal tables: a base-field table has an extension word".into());
        }
        Ok(())
    }

    /// **[A12] Build the planned tables on the device**, and every other table
    /// with `host` (given `(table index, its elements)`, on this thread, before
    /// the device runs). `data` is the slot's committed data (`ProverData`'s
    /// four), `base` the round-0 kernel's base-field flags. Every planned table
    /// is checked against its data's bounds first.
    ///
    /// The base check (kept for [`metal_rounds_owned`]): the host checks the
    /// host's tables; a device table flagged base must be base-field BY
    /// CONSTRUCTION (an eq cube whose half tables are base-field; a plane whose
    /// slice coefficients and fixed-point weights are), and the device checks
    /// its words as well. With `defer` and every flagged device table base by
    /// construction, the build is not run here but encoded ahead of the slot's
    /// first round ([`MetalRounds`]; [`MetalTables::flush`] if the tables are
    /// read first), and a word the device then flags refuses the attempt
    /// (it cannot happen: the construction makes those words base-field).
    /// Otherwise it runs now, in a command buffer of its own, and the device's
    /// flag is part of the answer.
    ///
    /// `Ok(false)`: the device does not take this build, and nothing was
    /// written: a slice above [`TAB_VIEW_MAX_WORDS`] words is not resident on
    /// this thread and `views` does not allow mapping it (the caller builds on
    /// the host, as without A12). `Err`: nothing usable was built; the caller
    /// rebuilds every table on the host. The plan is consumed either way.
    pub fn build_planned(&mut self, data: [&[Fp]; 4], base: &[bool], defer: bool, views: bool, host: impl FnOnce(Vec<(usize, &mut [Fp2])>)) -> Result<bool, String> {
        let plan = std::mem::take(&mut self.plan);
        self.typed = None;
        self.pending = None;
        let (k, cap) = (self.k, self.cap);
        let n = cap.trailing_zeros();
        if base.len() != k {
            return Err("metal tables: base flags".into());
        }
        if !views {
            for j in &plan {
                if let TabJob::Plane { src, .. } = j {
                    let d = data.get(*src).copied().unwrap_or(&[]);
                    if d.len() > TAB_VIEW_MAX_WORDS && resident(d).is_none() {
                        TAB_BUILDS[7].fetch_add(1, Ordering::Relaxed);
                        return Ok(false);
                    }
                }
            }
        }
        let mut planned = vec![false; k];
        // whether every device table flagged base is base-field by construction
        let mut base_by_construction = true;
        let is_base = |v: &[Fp2]| v.iter().all(|e| e.c1.0 == 0);
        for j in &plan {
            let t = j.table();
            if t >= k || planned[t] {
                return Err(format!("metal tables: table {t} planned twice or out of range"));
            }
            planned[t] = true;
            let ok = match j {
                TabJob::Eq { hi, lo, shift, p, .. } => {
                    let p_lo = p / 2;
                    if base[t] && !(is_base(hi) && is_base(lo)) {
                        base_by_construction = false;
                    }
                    *p < 32 && hi.len() == 1usize << (p - p_lo) && lo.len() == 1usize << p_lo && shift + p <= n
                }
                TabJob::Plane { src, log, slices, used, xlo, inv_lo, inv_hi, zbits, eqf, .. } => {
                    if base[t] && !(slices.iter().all(|(_, cf)| cf.c1.0 == 0) && is_base(eqf)) {
                        base_by_construction = false;
                    }
                    let lim = if *log < 32 { 1u64 << log } else { 0 };
                    let fits = |v: &u32| u64::from(*v) < lim;
                    *src < 4
                        && *log < 32
                        && !slices.is_empty()
                        && *xlo <= n
                        && used >> n == 0
                        && inv_lo.len() == 1usize << xlo
                        && inv_hi.len() == 1usize << (n - xlo)
                        && (if eqf.is_empty() { zbits.len() == 1 } else { zbits.len() == eqf.len() })
                        && inv_lo.iter().chain(inv_hi.iter()).chain(zbits.iter()).all(fits)
                        && slices.iter().all(|(off, _)| off.checked_add(1usize << log).is_some_and(|e| e <= data[*src].len()))
                }
            };
            if !ok {
                return Err(format!("metal tables: table {t}'s plan does not fit its slot or its data"));
            }
        }
        let c = ctx()?;
        tab_pipes(c)?;
        objc::rc::autoreleasepool(|| {
            // the small tables, packed: u32 index maps, u64 field words
            let (mut aux32, mut aux64): (Vec<u32>, Vec<u64>) = (Vec::new(), Vec::new());
            let off32 = |aux32: &mut Vec<u32>, v: &[u32]| -> u32 {
                let o = aux32.len() as u32;
                aux32.extend_from_slice(v);
                o
            };
            let off64 = |aux64: &mut Vec<u64>, v: &[Fp2]| -> u32 {
                let o = aux64.len() as u32;
                aux64.extend(v.iter().flat_map(|e| [e.c0.0, e.c1.0]));
                o
            };
            // the committed data, in place (resident, or a view, or a copy)
            let mut views: [Option<(WeightBuf, u64)>; 4] = [None, None, None, None];
            for j in &plan {
                if let TabJob::Plane { src, .. } = j {
                    if views[*src].is_none() {
                        views[*src] = Some(data_buffer(c, data[*src])?);
                    }
                }
            }
            let mut args: Vec<TabArg> = Vec::with_capacity(plan.len());
            for j in &plan {
                let out_off = (j.table() * cap * 2) as u64;
                let check = u32::from(base[j.table()]);
                match j {
                    TabJob::Eq { hi, lo, shift, p, .. } => {
                        let (hi_off, lo_off) = (off64(&mut aux64, hi), off64(&mut aux64, lo));
                        let mask = if *p == 0 { 0 } else { (1u64 << p) - 1 };
                        args.push(TabArg::Eq(TabEqArgs { out_off, cap: cap as u64, mask, shift: *shift, p_lo: p / 2, hi_off, lo_off, check, pad0: 0 }));
                    }
                    TabJob::Plane { src, slices, used, xlo, inv_lo, inv_hi, zbits, eqf, .. } => {
                        let (il, ih, zb) = (off32(&mut aux32, inv_lo), off32(&mut aux32, inv_hi), off32(&mut aux32, zbits));
                        let sl = aux64.len() as u32;
                        for (o, cf) in slices {
                            aux64.extend_from_slice(&[*o as u64, cf.c0.0, cf.c1.0]);
                        }
                        let ef = off64(&mut aux64, eqf);
                        let one = u32::from(slices.len() == 1 && slices[0].1 == Fp2::ONE);
                        let base_word = views[*src].as_ref().map(|v| v.1).unwrap_or(0);
                        let a = TabPlaneArgs { out_off, cap: cap as u64, used: *used, base: base_word, xlo: *xlo, nz: eqf.len() as u32, ns: slices.len() as u32, one, inv_lo: il, inv_hi: ih, zb, sl, eqf: ef, check };
                        args.push(TabArg::Plane(*src, a));
                    }
                }
            }
            if aux32.len() > u32::MAX as usize / 2 || aux64.len() > u32::MAX as usize / 2 {
                return Err("metal tables: auxiliary tables too large".into());
            }
            let tb = TabBuild { args, a32: upload_words(c, &aux32)?, a64: upload_words(c, &aux64)?, flag: upload_words(c, &[0u32; 4])?, data: views, cap: cap as u64 };
            // the host's tables (the ones the plan leaves out), before any
            // device work: slices of those tables only, never of a planned one
            let at = self.buf.contents() as usize;
            let host_tables: Vec<usize> = (0..k).filter(|&t| !planned[t]).collect();
            // SAFETY: table `t` is the `cap` elements at `t * cap` of the
            // `k * cap` elements of shared memory `self` owns (the layout was
            // checked in `new`), not in use by the GPU; each slice is its own table's
            let tabs: Vec<(usize, &mut [Fp2])> = host_tables.iter().map(|&t| (t, unsafe { std::slice::from_raw_parts_mut((at as *mut Fp2).add(t * cap), cap) })).collect();
            host(tabs);
            let host_ok = host_tables.par_iter().filter(|&&t| base[t]).all(|&t| {
                // SAFETY: as above, read after `host` wrote it
                let tab = unsafe { std::slice::from_raw_parts((at as *const Fp2).add(t * cap), cap) };
                tab.iter().all(|v| v.c1.0 == 0)
            });
            TAB_BUILDS[0].fetch_add(1, Ordering::Relaxed);
            TAB_BUILDS[1].fetch_add(plan.len() as u64, Ordering::Relaxed);
            TAB_BUILDS[2].fetch_add(host_tables.len() as u64, Ordering::Relaxed);
            if defer && base_by_construction {
                TAB_BUILDS[6].fetch_add(1, Ordering::Relaxed);
                self.typed = Some(host_ok);
                self.pending = Some(tb);
                return Ok(true);
            }
            let tabs: &metal::BufferRef = &self.buf;
            run_tagged_pre(c, "tables", Some((&tb, tabs)), |_| Ok(()))?;
            self.typed = Some(host_ok && !tb.flagged());
            Ok(true)
        })
    }
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
        assert!(self.prelude.is_none(), "[ZK60-METAL A12] the tables were read before their deferred device build ran");
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
        // [A12] the tables' deferred device build, ahead of the first round
        let pre = self.prelude.take();
        let sums = objc::rc::autoreleasepool(|| {
            let pipe = if j == 0 { &self.pipe0 } else { &self.pipe };
            let tabs: &metal::BufferRef = &self.tabs;
            run_tagged_pre(c, "round", pre.as_ref().map(|p| (p, tabs)), |enc| {
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
            // [A12] the deferred build's base-field tables were base by
            // construction; a word the device flags is a device fault
            assert!(!pre.as_ref().is_some_and(|p| p.flagged()), "[ZK60-METAL A12] a base-field table built on the device has an extension word: the attempt is refused");
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
                run_tagged(c, "fold", |enc| {
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

/// [M5e] the host-tail budget, overridable for an A/B (`HL_METAL_TAIL_BUDGET_US`,
/// microseconds). Which side computes a round changes no byte (M4k).
fn tail_round_budget_s() -> f64 {
    static B: OnceLock<f64> = OnceLock::new();
    *B.get_or_init(|| std::env::var("HL_METAL_TAIL_BUDGET_US").ok().and_then(|v| v.parse::<f64>().ok()).filter(|v| v.is_finite() && *v >= 0.0).map(|us| us * 1e-6).unwrap_or(TAIL_ROUND_BUDGET_S))
}

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
            run_tagged(c, "fold", |enc| {
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
        // [A12] a deferred table build not yet run (the host takes the first round)
        if let Some(pre) = self.prelude.take() {
            let c = ctx().expect("metal context");
            let tabs: &metal::BufferRef = &self.tabs;
            objc::rc::autoreleasepool(|| run_tagged_pre(c, "tables", Some((&pre, tabs)), |_| Ok(()))).expect("[ZK60-METAL A12] the deferred table build");
            assert!(!pre.flagged(), "[ZK60-METAL A12] a base-field table built on the device has an extension word: the attempt is refused");
        }
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
            if !self.on || (half * points) as f64 * self.per_eval > tail_round_budget_s() {
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

// ------------------------------------- M6: a sumcheck's device rounds in one submission

/// **[ZK60-METAL M6]** the host-tail budget when the device rounds are
/// batched. A batched device round costs about 0.025 ms of fixed time against
/// about 0.21 ms in a command buffer of its own (`logs/m6_probe`, 190 and
/// 1000 rounds), so the host takes only the rounds cheaper than that.
/// `HL_METAL_BATCH_TAIL_US` overrides it (microseconds; 0 keeps every round
/// on the device). Which side computes a round changes no byte (M4k).
const BATCH_TAIL_BUDGET_S: f64 = 2.5e-5;

fn batch_tail_budget_s() -> f64 {
    static B: OnceLock<f64> = OnceLock::new();
    *B.get_or_init(|| std::env::var("HL_METAL_BATCH_TAIL_US").ok().and_then(|v| v.parse::<f64>().ok()).filter(|v| v.is_finite() && *v >= 0.0).map(|us| us * 1e-6).unwrap_or(BATCH_TAIL_BUDGET_S))
}

/// `HL_METAL_BATCH=0` restores one command buffer per device round (M4).
fn batch_on() -> bool {
    static B: OnceLock<bool> = OnceLock::new();
    *B.get_or_init(|| std::env::var("HL_METAL_BATCH").map(|v| v != "0").unwrap_or(true))
}

/// the widest round message the device transcript step absorbs (`fs_absorb_round`)
const FS_MAX_POINTS: usize = 8;

/// [M6] a round with more partials than this per point is first reduced
/// across the whole GPU to `PART_RED_WIDTH` per point (`k_sc_part_reduce`):
/// one threadgroup reading 2^17 x (D + 1) partials cost about 0.3 ms a round
/// (`logs/m6diag`, the 2^19-table slots at 0.36 ms per batched round)
const PART_RED_MIN: usize = 4096;
const PART_RED_WIDTH: usize = 4096;

#[repr(C)]
struct PartRedArgs {
    nthreads: u32,
    d1: u32,
    width: u32,
    eval_one: u32,
}

#[repr(C)]
struct FsStepArgs {
    nthreads: u32,
    d1: u32,
    j: u32,
    eval_one: u32,
    tgw: u32,
    pad0: u32,
}
#[repr(C)]
struct FoldDevArgs {
    half: u64,
    cap: u64,
    k: u64,
    roff: u64,
}

static SC_BATCH_ROUNDS: AtomicU64 = AtomicU64::new(0);
static SC_BATCHES: AtomicU64 = AtomicU64::new(0);

/// (device sumchecks batched, their rounds) (diagnostics)
pub fn batch_stats() -> (u64, u64) {
    (SC_BATCHES.load(Ordering::Relaxed), SC_BATCH_ROUNDS.load(Ordering::Relaxed))
}

fn words_le(b: &[u8; 32]) -> [u64; 8] {
    std::array::from_fn(|i| u32::from_le_bytes([b[4 * i], b[4 * i + 1], b[4 * i + 2], b[4 * i + 3]]) as u64)
}

impl MetalRounds {
    /// **[M6]** rounds `0..nd` of this sumcheck in ONE command buffer: per
    /// round the round kernel, the transcript step (`k_sc_fs_step`: reduce,
    /// recover s(1), CFS-mask, absorb `sc-round`, squeeze) and the fold by the
    /// device's challenge. Returns the device's unmasked rounds and
    /// challenges, UNCHECKED: the caller replays them through `tr`. `tr` is
    /// only read (its state, counter and key) and must not have a masker.
    fn batched_rounds(&mut self, nd: usize, mask: &zkp_core::sumcheck::CfsMask, c: Fp2, tr: &crate::transcript::Transcript) -> Result<(Vec<Vec<Fp2>>, Vec<Fp2>), String> {
        let cx = ctx()?;
        let (d, d1) = (self.degree, self.degree + 1);
        if self.next != 0 || self.pending.is_some() || self.fold_r.is_some() || nd == 0 || nd > self.n_vars || d1 > FS_MAX_POINTS || mask.degree != d || mask.n_vars < self.n_vars {
            return Err("metal batched rounds: state, round count or mask shape".into());
        }
        let n = mask.n_vars;
        // the mask's per-round terms that do not depend on the challenges
        let a = |i: usize, e: usize| mask.coeffs[2 + i * d + (e - 1)];
        let u = |i: usize, x: Fp2| {
            let (mut acc, mut xp) = (Fp2::ZERO, Fp2::ONE);
            for e in 1..=d {
                xp = xp.mul(x);
                acc = acc.add(a(i, e).mul(xp));
            }
            acc
        };
        let half_inv = Fp::new(2).inv();
        let mut suffix = vec![Fp2::ZERO; n + 1];
        for i in (0..n).rev() {
            suffix[i] = suffix[i + 1].add(u(i, Fp2::ONE).mul_base(half_inv));
        }
        let mut mk: Vec<u64> = Vec::with_capacity(4 + d1 + nd * 2 * (2 + d1 + d));
        let push = |mk: &mut Vec<u64>, v: Fp2| {
            mk.push(v.c0.0);
            mk.push(v.c1.0);
        };
        push(&mut mk, c);
        push(&mut mk, mask.coeffs[1]);
        for i in 0..d1 {
            // zkp-core `mle::interpolate_eval`'s weights 1 / prod_{m != i} (i - m)
            let mut den = Fp::ONE;
            for m in 0..d1 {
                if m != i {
                    den = den.mul(Fp::from_i64(i as i64 - m as i64));
                }
            }
            mk.push(den.inv().0);
        }
        for j in 0..nd {
            push(&mut mk, Fp2::from_u64(1u64 << (n - 1 - j)));
            push(&mut mk, mask.coeffs[0].add(suffix[j + 1]));
            for x in 0..d1 {
                push(&mut mk, u(j, Fp2::from_u64(x as u64)));
            }
            for e in 1..=d {
                push(&mut mk, a(j, e));
            }
        }
        let mut fs = [0u64; 32];
        fs[..8].copy_from_slice(&words_le(&tr.state()));
        let key = tr.fs_key();
        fs[8..16].copy_from_slice(&words_le(&key.unwrap_or([0u8; 32])));
        fs[16] = tr.counter();
        fs[17] = key.is_some() as u64;
        fs[18] = self.recover_one as u64;
        if let Some(cl) = self.unmasked_claim.filter(|_| self.recover_one) {
            fs[19] = cl.c0.0;
            fs[20] = cl.c1.0;
        }
        fs[23] = 1; // the empty product of the challenges
        let rec = 2 * (2 * d1 + 1);
        let fs_pipe = &cx.pipes["k_sc_fs_step"];
        let tg_max = fs_pipe.max_total_threads_per_threadgroup().min(256);
        let tgw = 1u64 << (63 - tg_max.leading_zeros());
        let t0 = std::time::Instant::now();
        // [A12] the tables' deferred device build, ahead of the batch's rounds
        let pre = self.prelude.take();
        let (sums, rs) = objc::rc::autoreleasepool(|| -> Result<(Vec<Vec<Fp2>>, Vec<Fp2>), String> {
            let mkb = upload(cx, &mk.iter().map(|&w| Fp(w)).collect::<Vec<Fp>>())?;
            let fsb = upload(cx, &fs.iter().map(|&w| Fp(w)).collect::<Vec<Fp>>())?;
            let out = shared_buffer(cx, (nd * rec * 8) as u64)?;
            let part2 = shared_buffer(cx, (PART_RED_WIDTH * d1 * 16) as u64)?;
            let mut claim_known = self.recover_one && self.unmasked_claim.is_some();
            let tabs: &metal::BufferRef = &self.tabs;
            run_tagged_pre(cx, "batch", pre.as_ref().map(|p| (p, tabs)), |enc| {
                for j in 0..=nd {
                    if j > 0 {
                        // the fold of round j - 1 by the device's challenge
                        let hprev = (self.len >> (j - 1)) / 2;
                        enc.set_buffer(0, Some(&self.tabs), 0);
                        set_args(enc, 1, &FoldDevArgs { half: hprev as u64, cap: self.cap as u64, k: self.k as u64, roff: ((j - 1) * rec + 4 * d1) as u64 });
                        enc.set_buffer(2, Some(&out), 0);
                        dispatch_2d(cx, enc, "k_fold_tables_dev", hprev as u64, self.k as u64);
                    }
                    if j == nd {
                        break;
                    }
                    let half = (self.len >> j) / 2;
                    let eval_one = !claim_known;
                    let nthreads = sc_threads(half, self.per, self.cap_log);
                    let pipe = if j == 0 { &self.pipe0 } else { &self.pipe };
                    enc.set_compute_pipeline_state(pipe);
                    enc.set_buffer(0, Some(&self.tabs), 0);
                    enc.set_buffer(1, Some(&self.part), 0);
                    enc.set_buffer(2, Some(&self.coefs), 0);
                    set_args(enc, 3, &RoundArgs { half: half as u64, cap: self.cap as u64, eval_one: eval_one as u32, nthreads: nthreads as u32 });
                    let np = if eval_one { d1 } else { d1 - 1 };
                    let grid = (nthreads.div_ceil(32) * 32 * np) as u64;
                    let tg = pipe.max_total_threads_per_threadgroup().min(self.tg).min(grid);
                    enc.dispatch_threads(MTLSize::new(grid, 1, 1), MTLSize::new(tg, 1, 1));
                    // a large round's partials: first reduced across the GPU
                    let (src, count) = if nthreads > PART_RED_MIN {
                        enc.set_buffer(0, Some(&self.part), 0);
                        enc.set_buffer(1, Some(&part2), 0);
                        set_args(enc, 2, &PartRedArgs { nthreads: nthreads as u32, d1: d1 as u32, width: PART_RED_WIDTH as u32, eval_one: eval_one as u32 });
                        dispatch_2d(cx, enc, "k_sc_part_reduce", PART_RED_WIDTH as u64, 1);
                        (&part2, PART_RED_WIDTH)
                    } else {
                        (&self.part, nthreads)
                    };
                    enc.set_compute_pipeline_state(fs_pipe);
                    enc.set_buffer(0, Some(src), 0);
                    enc.set_buffer(1, Some(&fsb), 0);
                    enc.set_buffer(2, Some(&mkb), 0);
                    enc.set_buffer(3, Some(&out), 0);
                    set_args(enc, 4, &FsStepArgs { nthreads: count as u32, d1: d1 as u32, j: j as u32, eval_one: eval_one as u32, tgw: tgw as u32, pad0: 0 });
                    enc.dispatch_thread_groups(MTLSize::new(1, 1, 1), MTLSize::new(tgw, 1, 1));
                    claim_known = self.recover_one;
                }
                Ok(())
            })?;
            // [A12] the deferred build's base-field tables were base by
            // construction; a word the device flags is a device fault
            assert!(!pre.as_ref().is_some_and(|p| p.flagged()), "[ZK60-METAL A12] a base-field table built on the device has an extension word: the attempt is refused");
            let o = as_u64s(&out, nd * rec);
            let at = |w: usize| Fp2::new(Fp(o[w]), Fp(o[w + 1]));
            let sums = (0..nd).map(|j| (0..d1).map(|x| at(j * rec + 2 * x)).collect()).collect();
            let rs = (0..nd).map(|j| at(j * rec + 4 * d1)).collect();
            Ok((sums, rs))
        })?;
        self.len >>= nd;
        self.next = nd;
        let ns = t0.elapsed().as_nanos() as u64;
        SC_ROUND_NS.fetch_add(ns, Ordering::Relaxed);
        self.busy_ns.set(self.busy_ns.get() + ns);
        SC_BATCHES.fetch_add(1, Ordering::Relaxed);
        SC_BATCH_ROUNDS.fetch_add(nd as u64, Ordering::Relaxed);
        Ok((sums, rs))
    }
}

impl TailedRounds<'_> {
    /// [M6] how many leading rounds run batched on the device: those the host
    /// tail would not take at the batched budget (all of them when the tail
    /// is off), 0 when batching does not apply
    fn batched_round_count(&self) -> usize {
        let Some(d) = self.dev.as_ref() else { return 0 };
        if !batch_on() || d.next != 0 || d.pending.is_some() || d.fold_r.is_some() || self.degree + 1 > FS_MAX_POINTS {
            return 0;
        }
        let budget = batch_tail_budget_s();
        let mut claim_known = d.recover_one && d.unmasked_claim.is_some();
        let mut nd = 0;
        for j in 0..self.n_vars {
            let half = d.len >> (j + 1);
            let points = if claim_known { self.degree } else { self.degree + 1 };
            if self.on && (half * points) as f64 * self.per_eval <= budget {
                break;
            }
            nd += 1;
            claim_known = d.recover_one;
        }
        nd
    }

    /// **[ZK60-METAL M6]** `crate::zk::masked_prove_rounds` for this
    /// evaluator, with its device rounds in ONE command buffer
    /// ([`MetalRounds::batched_rounds`]). The host then REPLAYS each device
    /// round through `tr` with the real `CfsMasker`: s(1) recomputed from its
    /// own claim, the masked message absorbed, the challenge drawn, and the
    /// device's challenge required to equal it (the device folded by it). A
    /// difference panics before any later round, so a device fault refuses
    /// the attempt and never changes a byte. The remaining rounds run as
    /// before (`round`/`fold`, the host tail). Returns (masked rounds,
    /// challenges, finals), the transcript left exactly as the CPU leaves it.
    pub fn masked_prove(&mut self, mask: &zkp_core::sumcheck::CfsMask, c: Fp2, tr: &mut crate::transcript::Transcript) -> (Vec<Vec<Fp2>>, Vec<Fp2>, Vec<Fp2>) {
        let nd = self.batched_round_count();
        if nd < 2 {
            return crate::zk::masked_prove_rounds(self, mask, c, tr);
        }
        assert!(!c.is_zero(), "zero mask challenge: abandon proof attempt");
        assert_eq!(self.degree, mask.degree, "masked evaluator degree mismatch");
        assert!(self.n_vars <= mask.n_vars, "masked evaluator variable count");
        let t0 = std::time::Instant::now();
        let dev = self.dev.as_mut().expect("the device evaluator");
        let (dev_sums, dev_r) = dev.batched_rounds(nd, mask, c, tr).expect("metal batched sumcheck rounds");
        tr.set_masker(Box::new(zkp_core::sumcheck::CfsMasker { mask: mask.clone(), c, challenges: Vec::new() }));
        let recover = dev.recover_one;
        let mut claim = if recover { dev.unmasked_claim } else { None };
        let mut challenges = Vec::with_capacity(self.n_vars);
        for j in 0..nd {
            let mut sums = dev_sums[j].clone();
            if let Some(cl) = claim {
                sums[1] = cl.sub(sums[0]);
            }
            assert!(sums == dev_sums[j], "[ZK60-METAL M6] the device's s(1) differs from the host's claim at round {j} of {}: the attempt is refused", self.n_vars);
            tr.absorb_fp2(b"sc-round", &sums);
            let r = tr.challenge_fp2();
            assert!(r == dev_r[j], "[ZK60-METAL M6] the device transcript differs from the host's at round {j} of {}: the attempt is refused", self.n_vars);
            if recover {
                claim = Some(zkp_core::mle::interpolate_eval(&sums, r));
            }
            challenges.push(r);
        }
        if recover {
            dev.unmasked_claim = claim;
        }
        self.next = nd;
        let replay_s = t0.elapsed().as_secs_f64();
        use zkp_core::sumcheck::SumcheckRounds;
        for j in nd..self.n_vars {
            let sums = self.round(j);
            assert_eq!(sums.len(), self.degree + 1, "sumcheck evaluator round length");
            tr.absorb_fp2(b"sc-round", &sums);
            let r = tr.challenge_fp2();
            self.fold(r);
            challenges.push(r);
        }
        if std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false) {
            eprintln!("[ZK60-METAL M6] {} of {} rounds batched (degree {}), batch + replay {:.4} s, then {} host rounds", nd, self.n_vars, self.degree, replay_s, self.host_rounds);
        }
        let finals = self.finals();
        let (_, masked) = tr.take_masker();
        (masked, challenges, finals)
    }
}

// ============================================================================
// [A4, 2026-11-05] THE WITNESS WEIGHT PRODUCTS ON THE DEVICE, EXACTLY
// (`docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A4;
// `results/zk60_effplan_20261105/a4/README.md`).
//
// WHAT. `out[t, j] = sum_i x[t, i] w(i, j)` for the private block's seven weight
// products (`private_block/witness.rs`: `matmul`, `matmul_in_out`), with int16
// activations `x` and int8 weights `w` stored (output, input) or (input, output).
// The CPU path (`tiled16` there) stays the reference and the default: the builder
// calls here only under `gpu::enabled()`, for a product large enough to pay,
// and the activations must fit i16 (otherwise `Ok(None)`: the CPU path, silently).
// Every output is an exact integer, so the device must return the same words.
//
// PRIVACY. `x` and `out` are private witness values. They stay on this machine
// (unified memory, the local GPU); nothing here prints, hashes or keeps them: the
// packed activations go back to the buffer pool (stale contents are never read,
// see `PBuf`), the result plane is the caller's own `Vec`, and an error names a
// shape or a device state, never a value.
//
// TWO EXACT ROUTES (`HL_GPU_WITNESS_ROUTE`; (b) at the 2 x 4 layout is the
// default, the fastest measured on the GPU's clock, see the README):
//
// (b) `simd4x2` / `simd2x4`, `k_wprod_sg<FM, FN>` (two simdgroup layouts of the
// same arithmetic): FlashProve's byte decomposition (`products.cuh`,
// pinned in `results/zk60_astra_20261026/flashprove_comparison_20261104/`) on
// the float matrix units (`simdgroup_float8x8`), which Metal has instead of INT8
// tensor cores. THE BOUND, proved:
// * x in [-32768, 32767] splits as x = 256 hi + lo, lo = x & 255 in [0, 255] and
//   hi = (x - lo) / 256 in [-128, 127] (an exact division). w is in [-128, 127].
//   Every operand is an integer of magnitude <= 255, a binary32 value.
// * |lo w| <= 255 * 128 = 32,640 and |hi w| <= 128 * 128 = 16,384.
// * A SLAB is 512 consecutive terms (16 tiles of 32, `WP_SLAB_TILES`). Whatever
//   order or fusion the matrix hardware uses, each value it forms inside a slab is
//   a sum of a subset of the slab's products, so its magnitude is at most
//   512 * 32,640 = 16,711,680 < 2^24 = 16,777,216. Every integer of magnitude
//   <= 2^24 is a binary32 value, and a multiply or add whose exact result is
//   representable returns it unchanged (correct or faithful rounding alike).
//   So every slab sum is the exact integer.
// * Each slab sum converts to int32 exactly and is added to an int32 total:
//   |sum lo w| <= K * 32,640 < 2^31 for K <= 65,536 terms (`WP_MAX_K`, checked
//   before any device work); the same for hi. The output is then
//   256 * hi_total + lo_total in int64 = sum x w, exactly.
// * The library is compiled with fast math OFF, and a start-up self-check runs
//   every route at these bounds against the host's i64 sums; any difference turns
//   the device path off for the process (every call declines).
//
// (a) `int`, `k_wprod_int`: plain int32 multiply-adds in a tiled kernel.
// |x w| <= 32,768 * 128 = 2^22, so an int32 partial over 256 terms
// (`WP_INT_TILES` tiles of 32) is at most 2^30 < 2^31; partials are widened to
// int64 between them. Exact by construction.
//
// Every kernel tiles 64 tokens x 64 outputs x 32 terms on 256 threads. The
// activations are packed into a pooled int16 buffer. With `HL_GPU_WITNESS_VIEW`
// unset (the default) the weights reach the device as a read-only no-copy view of
// the pages that hold them, and the kernel writes the int64 result plane in place
// through a view of that `Vec`'s own pages when its allocation is page-aligned;
// otherwise (or with `HL_GPU_WITNESS_VIEW=0`) the weights are copied into a pooled
// buffer and the outputs written compactly there, then scattered at the caller's
// row stride. The products run on their own command queue, so a sealing pass never
// waits behind a fork prover's command buffers in the shared queue.
// ============================================================================

const WPROD_SRC: &str = r##"
#include <metal_stdlib>
#include <metal_simdgroup_matrix>
using namespace metal;

// [A4] the witness weight products, exactly (see metal.rs for the bounds)
struct WProdArgs {
    uint t;       // output rows (true tokens)
    uint k;       // terms per output (the inner width)
    uint n;       // output columns (the outer width)
    uint kp;      // row stride of the packed activations, a multiple of WP_BK
    uint in_out;  // 1: w[i * n + j]; 0: w[j * k + i]
    uint os;      // row stride of the output
    ulong w_off;  // byte offset of w in its buffer
};

#define WP_BM 64
#define WP_BN 64
#define WP_BK 32
// (b): 16 tiles of 32 = 512 terms per exact float slab
#define WP_SLAB_TILES 16
// (a): 8 tiles of 32 = 256 terms per int32 partial
#define WP_INT_TILES 8

// one tile of 32 terms x 64 outputs of the weights into threadgroup memory as
// [term][output], converted exactly (int8 -> T), zero outside the matrix
template <typename T>
inline void wp_weights(threadgroup T *b, device const char *w, constant WProdArgs &a, uint k0, uint n0, uint tid) {
    if (a.in_out != 0) {
        const uint r = tid >> 3, c = (tid & 7) * 8, i = k0 + r;
        for (uint e = 0; e < 8; e++) {
            const uint j = n0 + c + e;
            b[r * WP_BN + c + e] = (i < a.k && j < a.n) ? T(w[(ulong)i * a.n + j]) : T(0);
        }
    } else {
        const uint c = tid >> 2, r = (tid & 3) * 8, j = n0 + c;
        for (uint e = 0; e < 8; e++) {
            const uint i = k0 + r + e;
            b[(r + e) * WP_BN + c] = (i < a.k && j < a.n) ? T(w[(ulong)j * a.k + i]) : T(0);
        }
    }
}

// (b) byte-split activations on simdgroup_float8x8. 8 simdgroups tile the 64 x 64
// output tile, each FM x FN fragments of 8 x 8 (FM * FN = 8), with a low-byte and
// a high-byte accumulator per fragment, flushed to int32 every slab.
template <uint FM, uint FN>
kernel void k_wprod_sg(device const short *x [[buffer(0)]],
                       device const char *wbuf [[buffer(1)]],
                       device long *out [[buffer(2)]],
                       constant WProdArgs &a [[buffer(3)]],
                       uint2 tg [[threadgroup_position_in_grid]],
                       uint tid [[thread_index_in_threadgroup]],
                       uint sg [[simdgroup_index_in_threadgroup]],
                       uint lane [[thread_index_in_simdgroup]]) {
    threadgroup float xlo[WP_BM * WP_BK];
    threadgroup float xhi[WP_BM * WP_BK];
    threadgroup float wt[WP_BK * WP_BN];
    threadgroup float scr[8 * 64];
    device const char *w = wbuf + a.w_off;
    const uint m0 = tg.y * WP_BM, n0 = tg.x * WP_BN;
    // simdgroups along the outputs, and this one's place: rows r0.., columns c0..
    const uint sgn = WP_BN / (8 * FN);
    const uint r0 = (sg / sgn) * 8 * FM, c0 = (sg % sgn) * 8 * FN;
    simdgroup_float8x8 clo[FM][FN], chi[FM][FN];
    int2 ilo[FM][FN], ihi[FM][FN];
    for (uint i = 0; i < FM; i++) {
        for (uint j = 0; j < FN; j++) {
            clo[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            chi[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
            ilo[i][j] = int2(0);
            ihi[i][j] = int2(0);
        }
    }
    threadgroup float *sc = scr + sg * 64;
    const uint nkt = (a.k + WP_BK - 1) / WP_BK;
    for (uint kt = 0; kt < nkt; kt++) {
        const uint k0 = kt * WP_BK;
        {
            // 64 rows x 32 terms of the packed (zero-padded) activations, 8 per thread
            const uint r = tid >> 2, c = (tid & 3) * 8;
            device const short *src = x + (ulong)(m0 + r) * a.kp + k0 + c;
            for (uint e = 0; e < 8; e++) {
                const int v = int(src[e]);
                const int lo = v & 255;
                xlo[r * WP_BK + c + e] = float(lo);
                xhi[r * WP_BK + c + e] = float((v - lo) / 256);
            }
        }
        wp_weights(wt, w, a, k0, n0, tid);
        threadgroup_barrier(mem_flags::mem_threadgroup);
        for (uint kk = 0; kk < WP_BK; kk += 8) {
            simdgroup_float8x8 b[FN];
            for (uint j = 0; j < FN; j++) {
                simdgroup_load(b[j], wt + kk * WP_BN + c0 + j * 8, WP_BN);
            }
            for (uint i = 0; i < FM; i++) {
                simdgroup_float8x8 al, ah;
                simdgroup_load(al, xlo + (r0 + i * 8) * WP_BK + kk, WP_BK);
                simdgroup_load(ah, xhi + (r0 + i * 8) * WP_BK + kk, WP_BK);
                for (uint j = 0; j < FN; j++) {
                    simdgroup_multiply_accumulate(clo[i][j], al, b[j], clo[i][j]);
                    simdgroup_multiply_accumulate(chi[i][j], ah, b[j], chi[i][j]);
                }
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if ((kt + 1) % WP_SLAB_TILES == 0 || kt + 1 == nkt) {
            // the slab is complete: its sums are exact integers below 2^24; move
            // them into the int32 totals through this simdgroup's own scratch
            // (lane l reads positions 2l and 2l + 1 of the row-major 8 x 8)
            for (uint i = 0; i < FM; i++) {
                for (uint j = 0; j < FN; j++) {
                    simdgroup_store(clo[i][j], sc, 8);
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                    ilo[i][j] += int2(int(sc[2 * lane]), int(sc[2 * lane + 1]));
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                    simdgroup_store(chi[i][j], sc, 8);
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                    ihi[i][j] += int2(int(sc[2 * lane]), int(sc[2 * lane + 1]));
                    simdgroup_barrier(mem_flags::mem_threadgroup);
                    clo[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
                    chi[i][j] = make_filled_simdgroup_matrix<float, 8, 8>(0.0f);
                }
            }
        }
    }
    for (uint i = 0; i < FM; i++) {
        for (uint j = 0; j < FN; j++) {
            const uint row = m0 + r0 + i * 8 + (lane >> 2);
            const uint col = n0 + c0 + j * 8 + 2 * (lane & 3);
            if (row < a.t) {
                device long *o = out + (ulong)row * a.os;
                if (col < a.n) {
                    o[col] = long(ihi[i][j].x) * 256 + long(ilo[i][j].x);
                }
                if (col + 1 < a.n) {
                    o[col + 1] = long(ihi[i][j].y) * 256 + long(ilo[i][j].y);
                }
            }
        }
    }
}

#define WP_SG_INSTANCE(NAME, FM, FN) \
template [[host_name(NAME)]] [[kernel]] void k_wprod_sg<FM, FN>( \
    device const short *x [[buffer(0)]], device const char *wbuf [[buffer(1)]], device long *out [[buffer(2)]], \
    constant WProdArgs &a [[buffer(3)]], uint2 tg [[threadgroup_position_in_grid]], uint tid [[thread_index_in_threadgroup]], \
    uint sg [[simdgroup_index_in_threadgroup]], uint lane [[thread_index_in_simdgroup]]);
// 32 tokens x 16 outputs per simdgroup, and 16 tokens x 32 outputs
WP_SG_INSTANCE("k_wprod_sg_4x2", 4, 2)
WP_SG_INSTANCE("k_wprod_sg_2x4", 2, 4)

// (a) int32 multiply-adds: 16 x 16 threads, 4 tokens x 4 outputs each
kernel void k_wprod_int(device const short *x [[buffer(0)]],
                        device const char *wbuf [[buffer(1)]],
                        device long *out [[buffer(2)]],
                        constant WProdArgs &a [[buffer(3)]],
                        uint2 tg [[threadgroup_position_in_grid]],
                        uint tid [[thread_index_in_threadgroup]]) {
    threadgroup int4 xt4[WP_BK * WP_BM / 4];
    threadgroup int4 wt4[WP_BK * WP_BN / 4];
    threadgroup int *xt = (threadgroup int *)xt4;
    threadgroup int *wt = (threadgroup int *)wt4;
    device const char *w = wbuf + a.w_off;
    const uint m0 = tg.y * WP_BM, n0 = tg.x * WP_BN;
    const uint tr = tid >> 4, tc = tid & 15;
    int4 acc[4];
    long tot[4][4];
    for (uint i = 0; i < 4; i++) {
        acc[i] = int4(0);
        for (uint j = 0; j < 4; j++) {
            tot[i][j] = 0;
        }
    }
    const uint nkt = (a.k + WP_BK - 1) / WP_BK;
    for (uint kt = 0; kt < nkt; kt++) {
        const uint k0 = kt * WP_BK;
        {
            // [term][token]
            const uint r = tid >> 2, c = (tid & 3) * 8;
            device const short *src = x + (ulong)(m0 + r) * a.kp + k0 + c;
            for (uint e = 0; e < 8; e++) {
                xt[(c + e) * WP_BM + r] = int(src[e]);
            }
        }
        wp_weights(wt, w, a, k0, n0, tid);
        threadgroup_barrier(mem_flags::mem_threadgroup);
        for (uint kk = 0; kk < WP_BK; kk++) {
            const int4 av = xt4[kk * (WP_BM / 4) + tr];
            const int4 bv = wt4[kk * (WP_BN / 4) + tc];
            acc[0] += av.x * bv;
            acc[1] += av.y * bv;
            acc[2] += av.z * bv;
            acc[3] += av.w * bv;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if ((kt + 1) % WP_INT_TILES == 0 || kt + 1 == nkt) {
            for (uint i = 0; i < 4; i++) {
                tot[i][0] += long(acc[i].x);
                tot[i][1] += long(acc[i].y);
                tot[i][2] += long(acc[i].z);
                tot[i][3] += long(acc[i].w);
                acc[i] = int4(0);
            }
        }
    }
    for (uint i = 0; i < 4; i++) {
        const uint row = m0 + tr * 4 + i;
        if (row < a.t) {
            for (uint j = 0; j < 4; j++) {
                const uint col = n0 + tc * 4 + j;
                if (col < a.n) {
                    out[(ulong)row * a.os + col] = tot[i][j];
                }
            }
        }
    }
}
"##;

/// `#[repr(C)]` mirror of the MSL `WProdArgs`
#[repr(C)]
struct WProdArgs {
    t: u32,
    k: u32,
    n: u32,
    kp: u32,
    in_out: u32,
    os: u32,
    w_off: u64,
}

/// the tile both kernels use (tokens, outputs, terms) and its thread count
const WP_BM: usize = 64;
const WP_BN: usize = 64;
const WP_BK: usize = 32;
const WP_THREADS: u64 = 256;
/// the most terms per output the float route's int32 totals hold: K * 32,640 < 2^31
const WP_MAX_K: usize = 1 << 16;

/// [A4] which exact route computes the witness products (see the section comment)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WProdRoute {
    /// (b) byte-split activations on the float matrix units, exact slabs of 512
    /// terms; each simdgroup 32 tokens x 16 outputs
    Simd4x2,
    /// (b), each simdgroup 16 tokens x 32 outputs
    Simd2x4,
    /// (a) int32 multiply-adds, partials of 256 terms widened to int64
    Int,
}

/// every route, for the self-check and the tests
pub const WP_ROUTES: [WProdRoute; 3] = [WProdRoute::Simd4x2, WProdRoute::Simd2x4, WProdRoute::Int];
/// the route a product takes unless `HL_GPU_WITNESS_ROUTE` names another
/// (the fastest measured, `results/zk60_effplan_20261105/a4/README.md`)
const WP_DEFAULT_ROUTE: WProdRoute = WProdRoute::Simd2x4;

#[cfg(test)]
thread_local! {
    /// tests: this thread's (route, weight view) instead of the environment's
    static WP_TEST_OPTS: std::cell::Cell<Option<(WProdRoute, bool)>> = const { std::cell::Cell::new(None) };
}

/// tests: run `f` with this thread's device products on `route`, the weights as a
/// page view (`view`) or a copy
#[cfg(test)]
pub fn with_witness_options<R>(route: WProdRoute, view: bool, f: impl FnOnce() -> R) -> R {
    let before = WP_TEST_OPTS.with(|o| o.replace(Some((route, view))));
    let r = f();
    WP_TEST_OPTS.with(|o| o.set(before));
    r
}

/// the route and the transfers: `HL_GPU_WITNESS_ROUTE` = `int` (a), `simd2x4` or
/// `simd4x2` (b), unset [`WP_DEFAULT_ROUTE`]; `HL_GPU_WITNESS_VIEW=0` copies the
/// weights in and the outputs out, anything else maps their pages
fn witness_options() -> (WProdRoute, bool) {
    #[cfg(test)]
    if let Some(o) = WP_TEST_OPTS.with(|o| o.get()) {
        return o;
    }
    let route = match std::env::var("HL_GPU_WITNESS_ROUTE").as_deref() {
        Ok("int") => WProdRoute::Int,
        Ok("simd2x4") => WProdRoute::Simd2x4,
        Ok("simd4x2") => WProdRoute::Simd4x2,
        _ => WP_DEFAULT_ROUTE,
    };
    let view = std::env::var("HL_GPU_WITNESS_VIEW").map(|v| v != "0").unwrap_or(true);
    (route, view)
}

/// the compiled witness-product kernels and their own command queue
struct WCtx {
    sg42: ComputePipelineState,
    sg24: ComputePipelineState,
    int: ComputePipelineState,
    queue: CommandQueue,
}

impl WCtx {
    fn pipe(&self, route: WProdRoute) -> &ComputePipelineState {
        match route {
            WProdRoute::Simd4x2 => &self.sg42,
            WProdRoute::Simd2x4 => &self.sg24,
            WProdRoute::Int => &self.int,
        }
    }
}

static WCTX: OnceLock<Result<WCtx, String>> = OnceLock::new();

/// the device context and the witness kernels, compiled (fast math off) and
/// self-checked once per process; a failure is kept and every call declines
fn wctx() -> Result<(&'static Ctx, &'static WCtx), String> {
    let c = ctx()?;
    let w = WCTX
        .get_or_init(|| {
            let w = objc::rc::autoreleasepool(|| -> Result<WCtx, String> {
                let opts = CompileOptions::new();
                opts.set_fast_math_enabled(false);
                let lib = c.device.new_library_with_source(WPROD_SRC, &opts).map_err(|e| format!("metal witness-product compile: {e}"))?;
                let pipe = |name: &str| -> Result<ComputePipelineState, String> {
                    let f = lib.get_function(name, None).map_err(|e| format!("metal function {name}: {e}"))?;
                    let p = c.device.new_compute_pipeline_state_with_function(&f).map_err(|e| format!("metal pipeline {name}: {e}"))?;
                    if p.max_total_threads_per_threadgroup() < WP_THREADS || p.thread_execution_width() != 32 {
                        return Err(format!("metal pipeline {name}: {} threads per threadgroup, SIMD width {} (needs {WP_THREADS} and 32)", p.max_total_threads_per_threadgroup(), p.thread_execution_width()));
                    }
                    Ok(p)
                };
                Ok(WCtx { sg42: pipe("k_wprod_sg_4x2")?, sg24: pipe("k_wprod_sg_2x4")?, int: pipe("k_wprod_int")?, queue: c.device.new_command_queue() })
            })?;
            wprod_self_check(c, &w)?;
            Ok(w)
        })
        .as_ref()
        .map_err(|e| e.clone())?;
    Ok((c, w))
}

/// **The exactness self-check.** Every route and both weight layouts, at 65 tokens
/// x 1,100 terms x 70 outputs (three slabs, the last partial; partial tiles in every
/// dimension), on two public patterns: every product at the float route's slab
/// bound (x = 32,767, whose low byte is 255 and high byte 127, times w = -128), and
/// mixed extremes. Each must equal the host's i64 sums.
fn wprod_self_check(c: &Ctx, w: &WCtx) -> Result<(), String> {
    let (t, k, n) = (65usize, 1100usize, 70usize);
    const XS: [i64; 8] = [-32768, 32767, -1, 255, 0, -256, 12345, -129];
    const WS: [i8; 6] = [-128, 127, -127, 1, 0, -1];
    for pattern in 0..2 {
        let x: Vec<i64> = (0..t * k).map(|i| if pattern == 0 { 32767 } else { XS[(i * 5 + i / 7) % 8] }).collect();
        let wt: Vec<i8> = (0..k * n).map(|i| if pattern == 0 { -128 } else { WS[(i * 7 + i / 11) % 6] }).collect();
        for in_out in [false, true] {
            let want: Vec<i64> = (0..t * n)
                .map(|o| {
                    let (r, j) = (o / n, o % n);
                    (0..k).map(|i| x[r * k + i] * i64::from(if in_out { wt[i * n + j] } else { wt[j * k + i] })).sum()
                })
                .collect();
            for route in WP_ROUTES {
                for view in [false, true] {
                    let got = objc::rc::autoreleasepool(|| wprod_run(c, w, route, view, t, &x, k, &wt, k, n, n, t * n, in_out))?;
                    if got.as_deref() != Some(&want[..]) {
                        return Err(format!("the {route:?} route's exactness self-check failed (pattern {pattern}, in_out {in_out}, view {view}): the device path is off"));
                    }
                }
            }
        }
    }
    Ok(())
}

static WP_CALLS: AtomicU64 = AtomicU64::new(0);
/// of which wrote their result plane in place
static WP_IN_PLACE: AtomicU64 = AtomicU64::new(0);
/// summed nanoseconds per phase, see [`WP_PHASES`]
static WP_NS: [AtomicU64; 7] = [const { AtomicU64::new(0) }; 7];
/// the phases of one device product, in order
#[cfg(test)]
pub const WP_PHASES: [&str; 7] = ["activation buffer", "pack", "weights", "output plane + encode", "command buffer", "of which on the GPU", "scatter"];

/// tests: (device products made, how many wrote their result in place, and their
/// summed seconds per phase of [`WP_PHASES`])
#[cfg(test)]
pub fn witness_product_stats() -> (u64, u64, [f64; 7]) {
    (WP_CALLS.load(Ordering::Relaxed), WP_IN_PLACE.load(Ordering::Relaxed), std::array::from_fn(|i| WP_NS[i].load(Ordering::Relaxed) as f64 * 1e-9))
}

/// **[A4] One witness weight product on the device**: `out[t * os + j] =
/// sum_i x[t * xs + i] * w(i, j)` for `t < t_rows`, `j < outer` (`w[j * inner + i]`,
/// or `w[i * outer + j]` when `in_out`), every other word of the `out_len` plane
/// zero: exactly `witness::matmul_reference`. `Ok(None)` when the CPU must take it
/// (an activation outside i16, or a shape outside the kernels' bounds; the CPU
/// path then runs exactly as before); `Err` on a device failure (the caller
/// declines).
#[allow(clippy::too_many_arguments)]
pub fn witness_product(t_rows: usize, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize, in_out: bool) -> Result<Option<Vec<i64>>, String> {
    let (route, view) = witness_options();
    witness_product_with(route, view, t_rows, x, xs, w, inner, outer, os, out_len, in_out)
}

/// [`witness_product`] on a given route and weight transfer
#[allow(clippy::too_many_arguments)]
pub fn witness_product_with(route: WProdRoute, view: bool, t_rows: usize, x: &[i64], xs: usize, w: &[i8], inner: usize, outer: usize, os: usize, out_len: usize, in_out: bool) -> Result<Option<Vec<i64>>, String> {
    let rows_end = |stride: usize, width: usize| t_rows.checked_sub(1).and_then(|r| r.checked_mul(stride)).and_then(|v| v.checked_add(width));
    let fits = t_rows >= 1
        && inner >= 1
        && outer >= 1
        && inner <= WP_MAX_K
        && t_rows < 1 << 30
        && outer < 1 << 30
        && xs >= inner
        && os >= outer
        && os <= u32::MAX as usize
        && rows_end(xs, inner).is_some_and(|e| e <= x.len())
        && rows_end(os, outer).is_some_and(|e| e <= out_len)
        && inner.checked_mul(outer).is_some_and(|e| e <= w.len());
    if !fits {
        return Ok(None);
    }
    let (c, wc) = wctx()?;
    objc::rc::autoreleasepool(|| wprod_run(c, wc, route, view, t_rows, x, xs, w, inner, outer, os, out_len, in_out))
}

/// the weights as the kernels read them: a no-copy view of their pages, or a copy
enum WeightBuf {
    View(Buffer),
    Copy(PBuf),
}

impl WeightBuf {
    fn buffer(&self) -> &metal::BufferRef {
        match self {
            WeightBuf::View(b) => b,
            WeightBuf::Copy(b) => b,
        }
    }
}

extern "C" {
    fn getpagesize() -> std::os::raw::c_int;
}

/// the VM page size (a power of two), or `None`
fn page_size() -> Option<usize> {
    // SAFETY: getpagesize has no preconditions
    usize::try_from(unsafe { getpagesize() }).ok().filter(|p| p.is_power_of_two())
}

/// **A no-copy device buffer over the whole pages `[base, base + len)`.** The caller
/// guarantees `base` is page-aligned, `len` a positive multiple of the page size,
/// every page mapped, and that the memory outlives the buffer (it drops the buffer
/// once its command buffer completes, while it still owns or borrows the memory);
/// a nil deallocator leaves the memory to its owner. `None` if Metal refuses.
unsafe fn pages_view(c: &Ctx, base: usize, len: usize) -> Option<Buffer> {
    use metal::foreign_types::ForeignType;
    use objc::Message;
    if len == 0 || len as u64 > c.device.max_buffer_length() {
        return None;
    }
    let device: &metal::DeviceRef = &c.device;
    let sel = objc::runtime::Sel::register("newBufferWithBytesNoCopy:length:options:deallocator:");
    let args = (base as *mut c_void, len as u64, MTLResourceOptions::StorageModeShared, std::ptr::null_mut::<c_void>());
    let raw: *mut objc::runtime::Object = device.send_message(sel, args).ok()?;
    if raw.is_null() {
        return None;
    }
    // SAFETY: a non-nil MTLBuffer from a `new` method (+1), now owned by the Buffer
    Some(Buffer::from_ptr(raw as *mut metal::MTLBuffer))
}

/// **A read-only device view of the whole pages holding `w`**, and `w`'s offset in
/// it. Those pages are mapped and readable (each holds at least one byte of `w`);
/// the kernels only read, and only inside `w` (`w_off`, `k * n` bytes).
fn page_view(c: &Ctx, w: &[i8]) -> Option<(Buffer, u64)> {
    let page = page_size()?;
    let p = w.as_ptr() as usize;
    let base = p & !(page - 1);
    let end = p.checked_add(w.len())?.checked_add(page - 1)? & !(page - 1);
    // SAFETY: whole mapped pages (above); the caller drops the view while `w` is borrowed
    let b = unsafe { pages_view(c, base, end - base) }?;
    Some((b, (p - base) as u64))
}

/// the weights for one product: a page view (when `view` and Metal accepts it) or a pooled copy
fn weight_buffer(c: &Ctx, w: &[i8], view: bool) -> Result<(WeightBuf, u64), String> {
    if view {
        if let Some((b, off)) = page_view(c, w) {
            return Ok((WeightBuf::View(b), off));
        }
    }
    let b = shared_buffer(c, w.len() as u64)?;
    // SAFETY: w.len() bytes of shared memory owned here, not in use by the GPU
    let d = unsafe { std::slice::from_raw_parts_mut(b.contents() as *mut i8, w.len()) };
    const CHUNK: usize = 1 << 20;
    if w.len() <= CHUNK {
        d.copy_from_slice(w);
    } else {
        d.par_chunks_mut(CHUNK).zip(w.par_chunks(CHUNK)).for_each(|(d, s)| d.copy_from_slice(s));
    }
    Ok((WeightBuf::Copy(b), 0))
}

/// **The result plane, written in place when it can be**: a zeroed `Vec` of
/// `out_len` words whose allocation starts on a page and spans whole pages of its
/// own (its capacity is rounded up to a page), with a writable device view of
/// exactly those pages. The kernels write only `row * os + col` for `row < t`,
/// `col < n`, inside the first `out_len` words. `None` for the view when the
/// allocator gave an unaligned block or Metal refuses: the caller then writes a
/// pooled buffer and scatters it.
fn result_plane(c: &Ctx, out_len: usize, view: bool) -> (Vec<i64>, Option<Buffer>) {
    let page = match page_size() {
        Some(p) if view && p % 8 == 0 => p,
        _ => return (vec![0i64; out_len], None),
    };
    let cap = (out_len * 8).div_ceil(page) * page / 8;
    let mut v = vec![0i64; cap];
    let base = v.as_mut_ptr() as usize;
    // SAFETY: [base, base + cap * 8) is whole pages of `v`'s own allocation (aligned
    // start, a page multiple long), all of it `v`'s zeroed words; `v` outlives the
    // view (the caller drops the view after the command buffer completes)
    let b = if base % page == 0 { unsafe { pages_view(c, base, cap * 8) } } else { None };
    v.truncate(out_len);
    (v, b)
}

/// pack, present, run, write back (shapes already checked)
#[allow(clippy::too_many_arguments)]
fn wprod_run(c: &Ctx, wc: &WCtx, route: WProdRoute, view: bool, t: usize, x: &[i64], xs: usize, w: &[i8], k: usize, n: usize, os: usize, out_len: usize, in_out: bool) -> Result<Option<Vec<i64>>, String> {
    let now = std::time::Instant::now;
    let mut at = [now(); 7];
    let (tp, kp) = (t.div_ceil(WP_BM) * WP_BM, k.div_ceil(WP_BK) * WP_BK);
    let xb = shared_buffer(c, (tp * kp * 2) as u64)?;
    at[1] = now();
    // SAFETY: tp * kp i16 of shared memory owned here, not in use by the GPU
    let xd = unsafe { std::slice::from_raw_parts_mut(xb.contents() as *mut i16, tp * kp) };
    // every word is written (the pad as zeros): a pooled buffer's old contents are
    // never read. Eight rows per task.
    const ROWS: usize = 8;
    let fits = xd
        .par_chunks_mut(kp * ROWS)
        .enumerate()
        .map(|(b, rows)| {
            let mut ok = true;
            for (dr, row) in rows.chunks_mut(kp).enumerate() {
                let r = b * ROWS + dr;
                if r >= t {
                    row.fill(0);
                    continue;
                }
                for (d, &v) in row[..k].iter_mut().zip(&x[r * xs..r * xs + k]) {
                    *d = v as i16;
                    ok &= i64::from(*d) == v;
                }
                row[k..].fill(0);
            }
            ok
        })
        .reduce(|| true, |a, b| a && b);
    if !fits {
        return Ok(None);
    }
    at[2] = now();
    let (wb, w_off) = weight_buffer(c, &w[..k * n], view)?;
    at[3] = now();
    // the output: in place at the caller's stride, or compact in a pooled buffer
    let (mut out, in_place) = result_plane(c, out_len, view);
    let pooled = match in_place {
        Some(_) => None,
        None => Some(shared_buffer(c, (t * n * 8) as u64)?),
    };
    let ob: &metal::BufferRef = match (&in_place, &pooled) {
        (Some(b), _) => b,
        (None, Some(b)) => b,
        (None, None) => unreachable!("one output buffer"),
    };
    let ostride = if in_place.is_some() { os } else { n };
    let wrote_in_place = in_place.is_some();
    let args = WProdArgs { t: t as u32, k: k as u32, n: n as u32, kp: kp as u32, in_out: in_out as u32, os: ostride as u32, w_off };
    // one command buffer on the witness queue (`run`'s shape, with the GPU's own clock)
    let tl = TL_ON.load(Ordering::Relaxed);
    let begin = if tl { host_time_s() } else { 0.0 };
    let cb = wc.queue.new_command_buffer();
    let enc = cb.new_compute_command_encoder();
    enc.set_compute_pipeline_state(wc.pipe(route));
    enc.set_buffer(0, Some(&xb), 0);
    enc.set_buffer(1, Some(wb.buffer()), 0);
    enc.set_buffer(2, Some(ob), 0);
    set_args(enc, 3, &args);
    enc.dispatch_thread_groups(MTLSize::new(n.div_ceil(WP_BN) as u64, (tp / WP_BM) as u64, 1), MTLSize::new(WP_THREADS, 1, 1));
    enc.end_encoding();
    at[4] = now();
    let committed = if tl { host_time_s() } else { 0.0 };
    cb.commit();
    wait_done(cb);
    if !matches!(cb.status(), MTLCommandBufferStatus::Completed) {
        return Err(format!("metal witness product: command buffer ended {:?}", cb.status()));
    }
    if tl {
        tl_record(cb, "wprod", 99, begin, committed);
    }
    // GPUStartTime / GPUEndTime of the completed command buffer (a failed message counts as zero)
    let gpu_s = {
        let (t0, t1) = gpu_times(cb);
        (t1 - t0).max(0.0)
    };
    drop(wb);
    drop(in_place);
    at[5] = now();
    if let Some(pb) = &pooled {
        // SAFETY: t * n words, every one written by the completed command buffer (the
        // grid covers every row below tp >= t and every column below a multiple of 64 >= n)
        let dev = unsafe { std::slice::from_raw_parts(pb.contents() as *const i64, t * n) };
        out.par_chunks_mut(os).zip(dev.par_chunks(n)).for_each(|(o, d)| o[..n].copy_from_slice(d));
    }
    at[6] = now();
    WP_CALLS.fetch_add(1, Ordering::Relaxed);
    if wrote_in_place {
        WP_IN_PLACE.fetch_add(1, Ordering::Relaxed);
    }
    let ns = |a: std::time::Instant, b: std::time::Instant| (b - a).as_nanos() as u64;
    for i in 0..5 {
        WP_NS[i].fetch_add(ns(at[i], at[i + 1]), Ordering::Relaxed);
    }
    WP_NS[5].fetch_add((gpu_s * 1e9) as u64, Ordering::Relaxed);
    WP_NS[6].fetch_add(ns(at[5], at[6]), Ordering::Relaxed);
    Ok(Some(out))
}

// [UPERF3-RR] U-PERF3 round 10, lane RR (host side): Stage A's aggregate
// zero-check — `zc_range::zc_agg_prove_masked`'s round loop — on the device.
// Own NVRTC module (`zkgpu_zc`, kernels_zc.cu); lane K's device / stream
// discipline (cuda.rs: `device_handle`, `DevBuf`, `HostPinned`); independent
// of the k9 / ixf modules (which keep the descents and the claim layer).
//
// Protocol (driven by zc_range.rs, one sequential loop on one transcript):
// `zc_agg_open(ext, planes, rem, rho, stop_n)` uploads the stacked BASE
// tables (w planes + rem, u32 residues) into the table buffers and builds
// the pair-granularity eq table on the device from the two half tables
// (build_eq_full's A / B, computed on the host — tiny); `zc_agg_round`
// launches the node-sum kernel (base round / E round) and returns the per-
// constraint node values (canonical sums reduced mod q on the host — the
// same field elements the CPU's split planes finalize to); `zc_agg_fold(r)`
// folds every table out of place (a rotating scratch: w + 2 buffers for w +
// 1 tables) and compacts the eq table; `zc_agg_handover` materializes the
// tables (as ETab) + the eq table on the host once the device is done (the
// tail rounds and the claim stacking read host tables). A device error is
// returned to the caller, which rebuilds the tables on the host from the
// same stacked instance and re-folds them with the challenges already drawn
// (deterministic) — the device is then disabled for the process (reported
// once). Nothing here changes a value: the batteries / the pass digests
// compare proof bytes.
//
// Memory: every table buffer holds n/2 E elements (c u32 each) — the base
// table (n u32) fits in the same bytes (c >= 2), so round 0 reads the base
// table in place and fold 0 writes E elements to the scratch. Held bytes =
// (w + 2 + 2) x (n/2) x c x 4; the open declines (-> CPU) when the free
// VRAM minus a 256 MB margin cannot hold it.
//
// Knobs (none changes a value): `ZK_GPU=1` (lane K's master switch),
// `ZK_GPU_ZC=0` (this module off — the one-binary A/B), `ZK_GPU_ZC_MIN_PAIRS`
// (the smallest round the device runs, in pairs; default 4096),
// `ZK_GPU_VERBOSE=1`.

use super::super::eval_proof::oracle_mode;
use super::super::kfield::KL;
use super::super::zc_range::{EElem, ETab, SubExt};
use super::cuda::{device_handle, env_usize, verbose, DevBuf, HostPinned};
use cudarc::driver::result as cu;
use cudarc::driver::{sys, CudaDevice, CudaFunction, CudaStream, LaunchAsync, LaunchConfig};
use cudarc::nvrtc::{compile_ptx_with_opts, CompileOptions};
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Instant;

const KSRC: &str = include_str!("kernels_zc.cu");
const MODULE: &str = "zkgpu_zc";
const FUNCS: &[&str] = &["k_zc_round_base", "k_zc_round_ext", "k_zc_fold_base", "k_zc_fold_ext", "k_zc_eq_build", "k_zc_eq_compact"];
/// The sub-extension degree the kernels are compiled for (== ZC_C).
const ZC_C: usize = 4;
/// Tables held in registers per thread (== WMAX in kernels_zc.cu).
const WMAX: usize = 12;
/// Threads per block of the round kernels (== TZC).
const TZC: u32 = 128;
/// Threads per block of the fold / eq kernels.
const TEL: u32 = 128;
/// Grid cap (grid-stride loops above it).
const GRID_CAP: u32 = 1 << 14;
/// Pinned staging chunk for the uploads.
const STG_BYTES: usize = 64 << 20;

/// Kernel parameters (by value; == kernels_zc.cu ZP).
#[repr(C)]
#[derive(Clone, Copy)]
struct ZcParams {
    q: u32,
    s: u32,
    c31: u32,
    c32: u32,
    w: u32,
    nalpha: u32,
    nn: u32,
    n_pairs: u32,
    nodes: [u32; 4],
    alpha: [u32; 4],
    pow2: [u32; WMAX],
}

static MIN_PAIRS_OVERRIDE: AtomicU64 = AtomicU64::new(0);
fn min_pairs() -> usize {
    let o = MIN_PAIRS_OVERRIDE.load(Ordering::Relaxed) as usize;
    if o > 0 {
        return o;
    }
    static V: OnceLock<usize> = OnceLock::new();
    *V.get_or_init(|| env_usize("ZK_GPU_ZC_MIN_PAIRS", 4096).max(1))
}
/// Harness knob: the smallest device round in pairs (0 = env/default).
pub fn zc_set_min_pairs(p: usize) {
    MIN_PAIRS_OVERRIDE.store(p as u64, Ordering::Relaxed);
}
static BYPASS: AtomicBool = AtomicBool::new(false);
/// Harness knob: route every aggregate to the host path (the in-process A/B).
pub fn zc_set_bypass(on: bool) {
    BYPASS.store(on, Ordering::Relaxed);
}
static WARNED: AtomicBool = AtomicBool::new(false);
static DISABLED: AtomicBool = AtomicBool::new(false);

fn requested() -> bool {
    static ON: OnceLock<bool> = OnceLock::new();
    *ON.get_or_init(|| std::env::var("ZK_GPU_ZC").map(|v| v != "0").unwrap_or(true))
}

// ---------------------------------------------------------------------------
// Stats (observation only)

#[derive(Clone, Debug, Default)]
pub struct ZcStats {
    pub instances: u64,
    pub declined: u64,
    pub rounds: u64,
    pub folds: u64,
    pub bytes_h2d: u64,
    pub secs_open: f64,
    pub secs_round: f64,
    pub secs_fold: f64,
    pub secs_handover: f64,
    pub held_peak: u64,
}
static S_INST: AtomicU64 = AtomicU64::new(0);
static S_DECL: AtomicU64 = AtomicU64::new(0);
static S_ROUNDS: AtomicU64 = AtomicU64::new(0);
static S_FOLDS: AtomicU64 = AtomicU64::new(0);
static S_H2D: AtomicU64 = AtomicU64::new(0);
static S_OPEN_US: AtomicU64 = AtomicU64::new(0);
static S_ROUND_US: AtomicU64 = AtomicU64::new(0);
static S_FOLD_US: AtomicU64 = AtomicU64::new(0);
static S_HAND_US: AtomicU64 = AtomicU64::new(0);
static S_HELD_PEAK: AtomicU64 = AtomicU64::new(0);
fn add_us(s: &AtomicU64, secs: f64) {
    s.fetch_add((secs * 1e6) as u64, Ordering::Relaxed);
}
pub fn zc_stats() -> ZcStats {
    ZcStats {
        instances: S_INST.load(Ordering::Relaxed),
        declined: S_DECL.load(Ordering::Relaxed),
        rounds: S_ROUNDS.load(Ordering::Relaxed),
        folds: S_FOLDS.load(Ordering::Relaxed),
        bytes_h2d: S_H2D.load(Ordering::Relaxed),
        secs_open: S_OPEN_US.load(Ordering::Relaxed) as f64 / 1e6,
        secs_round: S_ROUND_US.load(Ordering::Relaxed) as f64 / 1e6,
        secs_fold: S_FOLD_US.load(Ordering::Relaxed) as f64 / 1e6,
        secs_handover: S_HAND_US.load(Ordering::Relaxed) as f64 / 1e6,
        held_peak: S_HELD_PEAK.load(Ordering::Relaxed),
    }
}
pub fn zc_stats_reset() {
    for s in [&S_INST, &S_DECL, &S_ROUNDS, &S_FOLDS, &S_H2D, &S_OPEN_US, &S_ROUND_US, &S_FOLD_US, &S_HAND_US, &S_HELD_PEAK] {
        s.store(0, Ordering::Relaxed);
    }
}

// ---------------------------------------------------------------------------
// The singleton

/// The per-aggregate chain state.
struct Chain {
    /// Elements per table now / rounds done / planes.
    n: usize,
    t: usize,
    w: usize,
    /// True until the first fold: the table buffers hold BASE tables.
    base: bool,
    /// Which buffer holds table k; the spare is the scratch.
    tab: Vec<usize>,
    scratch: usize,
    /// Which of the two eq buffers is current.
    eq_cur: usize,
    /// The host takes over at n <= stop_n (the claim-stacking point).
    stop_n: usize,
    expect_fold: bool,
}

struct Zc {
    dev: Arc<CudaDevice>,
    sk: CudaStream,
    f: std::collections::HashMap<&'static str, CudaFunction>,
    /// The table buffers (w + 1) + the scratch, grown per open.
    bufs: Vec<DevBuf>,
    eq: [DevBuf; 2],
    /// The eq half tables (A then B), plain c words per element.
    ab: DevBuf,
    /// r (c words) at 0; the table pointer list (u64 x WMAX) at 64.
    small: DevBuf,
    partial: DevBuf,
    partial_h: HostPinned,
    /// Pinned staging for every host -> device copy (stream-ordered on sk:
    /// a pageable cuMemcpyHtoD may return before the DMA lands, and sk is
    /// not the null stream — the race the ixf module avoids the same way).
    stg: HostPinned,
    held: usize,
    chain: Option<Chain>,
    last_kernel_ms: f64,
}

unsafe impl Send for Zc {}

static ZCS: OnceLock<Option<Mutex<Zc>>> = OnceLock::new();
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

fn init_zc() -> Result<Zc, String> {
    let dev = device_handle().ok_or_else(|| "no device".to_string())?;
    dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
    let major = dev.attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR).map_err(|e| e.to_string())?;
    let minor = dev.attribute(sys::CUdevice_attribute::CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR).map_err(|e| e.to_string())?;
    let t0 = Instant::now();
    let arch = arch_str((major, minor));
    // PTX cached on disk keyed by (source, options, arch) — as k9.rs / ixf.rs.
    let opts: Vec<String> = vec![format!("-DZC_C={ZC_C}"), format!("-DTZC={TZC}")];
    let opts_str = format!("{}|{}", opts.join(" "), arch.unwrap_or("generic"));
    let cache_path = {
        use sha2::Digest;
        let mut h = sha2::Sha256::new();
        h.update(KSRC.as_bytes());
        h.update(opts_str.as_bytes());
        let d: [u8; 32] = h.finalize().into();
        let hex: String = d.iter().take(16).map(|b| format!("{b:02x}")).collect();
        let base = std::env::var("XDG_CACHE_HOME").ok().map(std::path::PathBuf::from).or_else(|| std::env::var("HOME").ok().map(|h| std::path::PathBuf::from(h).join(".cache")));
        base.map(|b| b.join("zkmatrix-gpu").join(format!("zc-{hex}.ptx")))
    };
    let cached: Option<String> = cache_path.as_ref().and_then(|p| std::fs::read_to_string(p).ok()).filter(|s| !s.is_empty());
    let ptx = match cached {
        Some(src) => cudarc::nvrtc::Ptx::from_src(src),
        None => {
            let compile = |arch: Option<&'static str>| {
                let o = CompileOptions { arch, options: opts.clone(), ..Default::default() };
                compile_ptx_with_opts(KSRC, o)
            };
            let ptx = match compile(arch) {
                Ok(p) => p,
                Err(e1) => match compile(None) {
                    Ok(p) => p,
                    Err(e2) => return Err(format!("NVRTC compile (zc) failed: {e1}; generic retry: {e2}")),
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
    dev.load_ptx(ptx, MODULE, FUNCS).map_err(|e| format!("cuModuleLoadData (zc): {e}"))?;
    let secs_load = t1.elapsed().as_secs_f64();
    let mut f = std::collections::HashMap::new();
    for &name in FUNCS {
        f.insert(name, dev.get_func(MODULE, name).ok_or_else(|| format!("{name} missing"))?);
    }
    let sk = dev.fork_default_stream().map_err(|e| format!("zc stream: {e}"))?;
    let mut partial = DevBuf::empty();
    partial.grow(4 * WMAX * ZC_C * 8)?;
    let mut partial_h = HostPinned::empty();
    partial_h.grow(4 * WMAX * ZC_C * 8)?;
    let mut small = DevBuf::empty();
    small.grow(64 + WMAX * 8)?;
    if verbose() {
        eprintln!("[UPERF3-RR] zc init: PTX (NVRTC or the disk cache) {secs_ptx:.2}s + module load {secs_load:.2}s; c {ZC_C}, WMAX {WMAX}, TZC {TZC}, min_pairs {}", min_pairs());
    }
    Ok(Zc {
        dev,
        sk,
        f,
        bufs: Vec::new(),
        eq: [DevBuf::empty(), DevBuf::empty()],
        ab: DevBuf::empty(),
        small,
        partial,
        partial_h,
        stg: HostPinned::empty(),
        held: 0,
        chain: None,
        last_kernel_ms: 0.0,
    })
}

fn zcs() -> Option<&'static Mutex<Zc>> {
    ZCS.get_or_init(|| match init_zc() {
        Ok(k) => Some(Mutex::new(k)),
        Err(e) => {
            *INIT_ERR.lock().unwrap() = Some(e);
            None
        }
    })
    .as_ref()
}

/// Live iff lane K's `enabled()` AND ZK_GPU_ZC != 0 AND not bypassed AND not
/// disabled by an earlier device error AND not under `oracle_mode()`.
fn live() -> bool {
    super::cuda::enabled() && requested() && !BYPASS.load(Ordering::Relaxed) && !DISABLED.load(Ordering::Relaxed) && !oracle_mode()
}

pub fn zc_label() -> String {
    if !super::cuda::enabled() {
        return format!("zc: off ({})", super::cuda::label());
    }
    if !requested() {
        return "zc: off (ZK_GPU_ZC=0)".to_string();
    }
    if BYPASS.load(Ordering::Relaxed) {
        return "zc: bypassed (harness)".to_string();
    }
    if DISABLED.load(Ordering::Relaxed) {
        return "zc: DISABLED after a device error".to_string();
    }
    match zcs() {
        Some(k) => {
            let k = k.lock().unwrap();
            let st = zc_stats();
            format!(
                "zc: on — device zc aggregate (c {ZC_C}; held {:.2} GB, peak {:.2} GB; {} aggregates, {} declined, {} rounds / {} folds; open {:.2}s round {:.2}s fold {:.2}s handover {:.2}s; min_pairs {})",
                k.held as f64 / 1e9,
                st.held_peak as f64 / 1e9,
                st.instances,
                st.declined,
                st.rounds,
                st.folds,
                st.secs_open,
                st.secs_round,
                st.secs_fold,
                st.secs_handover,
                min_pairs()
            )
        }
        None => format!("zc: FAILED to initialize ({})", INIT_ERR.lock().unwrap().clone().unwrap_or_default()),
    }
}

// ---------------------------------------------------------------------------
// The chain handle (zc_range.rs drives it; the state lives in the singleton).

pub struct ZcDevChain {
    /// Elements per table now.
    pub n: usize,
    /// Rounds done.
    pub t: usize,
    /// The host takes over at n <= stop_n.
    pub stop_n: usize,
}

impl ZcDevChain {
    /// True while the device should run the next round.
    pub fn device_next(&self) -> bool {
        self.n > self.stop_n && self.n / 2 >= min_pairs()
    }
}

/// Open a device chain for one stacked aggregate: `None` = declined (module
/// off, shape, budget) — the caller runs the host body.
pub fn zc_agg_open(ext: &SubExt, planes: &[&[u32]], rem: &[u32], rho: &[EElem], stop_n: usize) -> Option<ZcDevChain> {
    if !live() {
        return None;
    }
    let n = rem.len();
    let w = planes.len();
    if ext.c != ZC_C || w + 1 > WMAX || n < 2 * KL || !n.is_power_of_two() || (1usize << rho.len()) != n || planes.iter().any(|p| p.len() != n) {
        S_DECL.fetch_add(1, Ordering::Relaxed);
        return None;
    }
    let probe = ZcDevChain { n, t: 0, stop_n };
    if !probe.device_next() {
        S_DECL.fetch_add(1, Ordering::Relaxed);
        return None;
    }
    let m = zcs()?;
    let mut s = m.lock().unwrap();
    assert!(s.chain.is_none(), "[UPERF3-RR] zc_agg_open while a device chain is open (protocol violation)");
    let t0 = Instant::now();
    match s.open(ext, planes, rem, rho, stop_n) {
        Ok(true) => {
            S_INST.fetch_add(1, Ordering::Relaxed);
            add_us(&S_OPEN_US, t0.elapsed().as_secs_f64());
            if verbose() {
                eprintln!(
                    "[UPERF3-RR] zc open: n 2^{} x {} tables (w {w}), stop_n {stop_n}: {:.1} ms (held {:.2} GB)",
                    n.trailing_zeros(),
                    w + 1,
                    t0.elapsed().as_secs_f64() * 1e3,
                    s.held as f64 / 1e9
                );
            }
            Some(probe)
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

/// One round: per constraint k (w planes then the recomposition) the node
/// values at `nodes` — `sums[k][ni]`, canonical E elements. `Err` = the
/// device failed (the chain is closed and the module disabled; the caller
/// rebuilds on the host).
pub fn zc_agg_round(ext: &SubExt, ch: &mut ZcDevChain, nodes: &[u64], alphabet: &[u32], e0: u32) -> Result<Vec<Vec<EElem>>, String> {
    let m = zcs().ok_or("zc: no device")?;
    let mut s = m.lock().unwrap();
    let t0 = Instant::now();
    let r = s.round(ext, nodes, alphabet, e0);
    match r {
        Ok(v) => {
            S_ROUNDS.fetch_add(1, Ordering::Relaxed);
            add_us(&S_ROUND_US, t0.elapsed().as_secs_f64());
            if verbose() {
                eprintln!("[UPERF3-RR] zc round t {} n {}: {:.2} ms (kernel+sync {:.2} ms)", ch.t, ch.n, t0.elapsed().as_secs_f64() * 1e3, s.last_kernel_ms);
            }
            Ok(v)
        }
        Err(e) => {
            s.fail(&e);
            Err(e)
        }
    }
}

/// The fold by r of every table + the eq compaction.
pub fn zc_agg_fold(ext: &SubExt, ch: &mut ZcDevChain, r: &EElem) -> Result<(), String> {
    let m = zcs().ok_or("zc: no device")?;
    let mut s = m.lock().unwrap();
    let t0 = Instant::now();
    match s.fold(ext, r) {
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

/// Close the chain: the w + 1 tables (E, `n` elements each) and the eq
/// table (`n / 2` elements) materialized on the host for the CPU loop. The
/// device buffers stay allocated for the next aggregate.
pub fn zc_agg_handover(ext: &SubExt, ch: ZcDevChain) -> Result<(Vec<ETab>, ETab), String> {
    let m = zcs().ok_or("zc: no device")?;
    let mut s = m.lock().unwrap();
    let t0 = Instant::now();
    let _ = ch;
    match s.handover(ext) {
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
pub fn zc_agg_abort(ch: ZcDevChain) {
    let _ = ch;
    if let Some(Some(m)) = ZCS.get() {
        let mut s = m.lock().unwrap();
        s.chain = None;
    }
}

// ---------------------------------------------------------------------------
// The device work

impl Zc {
    fn fail(&mut self, e: &str) {
        if !WARNED.swap(true, Ordering::Relaxed) {
            eprintln!("[UPERF3-RR] gpu zc failed ({e}); this aggregate is rebuilt on the host and later aggregates run on the CPU");
        }
        self.chain = None;
        self.release();
        DISABLED.store(true, Ordering::Relaxed);
    }

    fn sync(&self) -> Result<(), String> {
        unsafe { cu::stream::synchronize(self.sk.stream) }.map_err(|e| format!("sync: {e}"))
    }

    fn release(&mut self) {
        let _ = self.sync();
        let mut freed = 0usize;
        for b in self.bufs.iter_mut() {
            freed += b.bytes;
            b.free();
        }
        for b in self.eq.iter_mut() {
            freed += b.bytes;
            b.free();
        }
        freed += self.ab.bytes;
        self.ab.free();
        self.held = self.held.saturating_sub(freed);
    }

    fn launch(&self, name: &str, grid: (u32, u32), block: u32, args: &mut [*mut c_void]) -> Result<(), String> {
        let f = self.f.get(name).ok_or_else(|| format!("{name} missing"))?.clone();
        let cfg = LaunchConfig { grid_dim: (grid.0.max(1), grid.1.max(1), 1), block_dim: (block, 1, 1), shared_mem_bytes: 0 };
        unsafe { f.launch_on_stream(&self.sk, cfg, args) }.map_err(|e| format!("launch {name}: {e}"))
    }

    fn grow(b: &mut DevBuf, bytes: usize, held: &mut usize) -> Result<(), String> {
        let old = b.bytes;
        if bytes > old {
            b.grow(bytes)?;
            *held += b.bytes - old;
        }
        Ok(())
    }

    /// Host -> device through the pinned staging, chunked, stream-ordered
    /// on sk (each chunk waits for the previous chunk's DMA before the
    /// staging is overwritten; the copy precedes every later launch on sk).
    fn upload<T: Copy>(&mut self, dst: sys::CUdeviceptr, src: &[T]) -> Result<(), String> {
        let bytes: &[u8] = unsafe { std::slice::from_raw_parts(src.as_ptr() as *const u8, std::mem::size_of_val(src)) };
        if bytes.is_empty() {
            return Ok(());
        }
        let per = STG_BYTES.min(bytes.len()).max(256);
        if self.stg.needs(per) {
            self.sync()?;
            self.stg.grow(per)?;
        }
        let mut off = 0usize;
        while off < bytes.len() {
            let n = per.min(bytes.len() - off);
            self.sync()?;
            self.stg.slice_mut::<u8>(n).copy_from_slice(&bytes[off..off + n]);
            unsafe { cu::memcpy_htod_async(dst + off as u64, self.stg.slice::<u8>(n), self.sk.stream) }.map_err(|e| format!("h2d: {e}"))?;
            S_H2D.fetch_add(n as u64, Ordering::Relaxed);
            off += n;
        }
        Ok(())
    }

    fn params(&self, ext: &SubExt, c: &Chain, nodes: &[u64], alphabet: &[u32], e0: u32) -> Result<ZcParams, String> {
        if nodes.len() > 4 || alphabet.len() > 4 || alphabet.is_empty() {
            return Err(format!("zc: unsupported shape (nodes {}, alphabet {})", nodes.len(), alphabet.len()));
        }
        let q = ext.q;
        let c31 = (1u64 << 31) % q;
        let mut p = ZcParams {
            q: q as u32,
            s: ext.s as u32,
            c31: c31 as u32,
            c32: (2 * c31) as u32,
            w: c.w as u32,
            nalpha: alphabet.len() as u32,
            nn: nodes.len() as u32,
            n_pairs: (c.n / 2) as u32,
            nodes: [0; 4],
            alpha: [0; 4],
            pow2: [0; WMAX],
        };
        for (i, &x) in nodes.iter().enumerate() {
            p.nodes[i] = (x % q) as u32;
        }
        for (i, &a) in alphabet.iter().enumerate() {
            p.alpha[i] = a;
        }
        for k in 0..c.w {
            p.pow2[k] = ((1u128 << (e0 as usize * k)) % q as u128) as u32;
        }
        Ok(p)
    }

    fn open(&mut self, ext: &SubExt, planes: &[&[u32]], rem: &[u32], rho: &[EElem], stop_n: usize) -> Result<bool, String> {
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let n = rem.len();
        let w = planes.len();
        let ntab = w + 1;
        let c = ext.c;
        let e_bytes = (n / 2) * c * 4; // one table buffer: n/2 E elements (>= n base words)
        // Budget against the free VRAM (256 MB margin).
        let mut more = 0usize;
        for i in 0..ntab + 1 {
            let have = self.bufs.get(i).map_or(0, |b| b.bytes);
            more += e_bytes.saturating_sub(have);
        }
        for b in self.eq.iter() {
            more += e_bytes.saturating_sub(b.bytes);
        }
        let hl = rho.len() / 2;
        let ab_bytes = ((1usize << hl) + (1usize << (rho.len() - hl))) * c * 4;
        more += ab_bytes.saturating_sub(self.ab.bytes);
        let (free, _total) = cu::mem_get_info().map_err(|e| format!("cuMemGetInfo: {e}"))?;
        if more + (256usize << 20) > free {
            if verbose() {
                eprintln!("[UPERF3-RR] zc: declined n 2^{} x {ntab} (need {:.2} GB more, free {:.2} GB)", n.trailing_zeros(), more as f64 / 1e9, free as f64 / 1e9);
            }
            return Ok(false);
        }
        self.sync()?;
        while self.bufs.len() < ntab + 1 {
            self.bufs.push(DevBuf::empty());
        }
        let mut held = self.held;
        for i in 0..ntab + 1 {
            Self::grow(&mut self.bufs[i], e_bytes, &mut held)?;
        }
        for b in self.eq.iter_mut() {
            Self::grow(b, e_bytes, &mut held)?;
        }
        Self::grow(&mut self.ab, ab_bytes.max(256), &mut held)?;
        self.held = held;
        S_HELD_PEAK.fetch_max(self.held as u64, Ordering::Relaxed);
        // ---- the base tables into their buffers (round 0 reads them in place).
        for (k, p) in planes.iter().enumerate() {
            let dst = self.bufs[k].ptr;
            self.upload(dst, p)?;
        }
        let dst_rem = self.bufs[w].ptr;
        self.upload(dst_rem, rem)?;
        // ---- the eq half tables (build_eq_full's A / B) -> the pair eq on the device.
        let build = |z: &[EElem]| -> Vec<EElem> {
            let mut t = vec![ext.one()];
            for zv in z {
                let zbar = ext.sub(&ext.one(), zv);
                let mut nt = Vec::with_capacity(t.len() * 2);
                for e in &t {
                    nt.push(ext.mul(e, &zbar));
                }
                for e in &t {
                    nt.push(ext.mul(e, zv));
                }
                t = nt;
            }
            t
        };
        let a = build(&rho[..hl]);
        let b = build(&rho[hl..]);
        let mut ab: Vec<u32> = Vec::with_capacity((a.len() + b.len()) * c);
        for e in a.iter().chain(b.iter()) {
            ab.extend_from_slice(e);
        }
        let dst_ab = self.ab.ptr;
        self.upload(dst_ab, &ab)?;
        let chain = Chain { n, t: 0, w, base: true, tab: (0..ntab).collect(), scratch: ntab, eq_cur: 0, stop_n, expect_fold: false };
        let p = self.params(ext, &chain, &[0], &[0], 1)?;
        let a_p = self.ab.ptr;
        let b_p = self.ab.ptr + (a.len() * c * 4) as u64;
        let hl_u = hl as u32;
        let out_p = self.eq[0].ptr;
        let n_pairs = (n / 2) as u32;
        let mut args: [*mut c_void; 6] = [
            &p as *const _ as *mut _,
            &a_p as *const _ as *mut _,
            &b_p as *const _ as *mut _,
            &hl_u as *const _ as *mut _,
            &out_p as *const _ as *mut _,
            &n_pairs as *const _ as *mut _,
        ];
        let grid = (n_pairs.div_ceil(TEL)).min(GRID_CAP);
        self.launch("k_zc_eq_build", (grid, 1), TEL, &mut args)?;
        if verbose() {
            self.sync()?;
        }
        self.chain = Some(chain);
        Ok(true)
    }

    fn round(&mut self, ext: &SubExt, nodes: &[u64], alphabet: &[u32], e0: u32) -> Result<Vec<Vec<EElem>>, String> {
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let c = self.chain.take().ok_or("zc: round without a chain")?;
        assert!(!c.expect_fold, "[UPERF3-RR] zc: round while a fold is expected (protocol violation)");
        let res = (|| -> Result<Vec<Vec<EElem>>, String> {
            let p = self.params(ext, &c, nodes, alphabet, e0)?;
            let ntab = c.w + 1;
            let nn = nodes.len();
            // the table pointer list
            let ptrs: Vec<u64> = (0..ntab).map(|k| self.bufs[c.tab[k]].ptr).collect();
            let ptr_dst = self.small.ptr + 64;
            self.upload(ptr_dst, &ptrs)?;
            let part_bytes = nn * ntab * ZC_C * 8;
            unsafe { cu::memset_d8_async(self.partial.ptr, 0, part_bytes, self.sk.stream) }.map_err(|e| format!("memset partial: {e}"))?;
            let tk = Instant::now();
            let eq_p = self.eq[c.eq_cur].ptr;
            let part = self.partial.ptr;
            let mut args: [*mut c_void; 4] = [&p as *const _ as *mut _, &ptr_dst as *const _ as *mut _, &eq_p as *const _ as *mut _, &part as *const _ as *mut _];
            let grid = ((p.n_pairs).div_ceil(TZC)).min(GRID_CAP);
            self.launch(if c.base { "k_zc_round_base" } else { "k_zc_round_ext" }, (grid, nn as u32), TZC, &mut args)?;
            self.sync()?;
            let h = self.partial_h.slice_mut::<u64>(nn * ntab * ZC_C);
            unsafe { cu::memcpy_dtoh_sync(h, self.partial.ptr) }.map_err(|e| format!("d2h partial: {e}"))?;
            self.last_kernel_ms = tk.elapsed().as_secs_f64() * 1e3;
            let q = ext.q;
            let out: Vec<Vec<EElem>> =
                (0..ntab).map(|k| (0..nn).map(|ni| (0..ZC_C).map(|j| (h[(ni * ntab + k) * ZC_C + j] % q) as u32).collect()).collect()).collect();
            Ok(out)
        })();
        let mut c = c;
        c.expect_fold = res.is_ok();
        self.chain = Some(c);
        res
    }

    fn fold(&mut self, ext: &SubExt, r: &EElem) -> Result<(), String> {
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let mut c = self.chain.take().ok_or("zc: fold without a chain")?;
        assert!(c.expect_fold, "[UPERF3-RR] zc: fold while a round is expected (protocol violation)");
        let n_out = c.n / 2;
        let res = (|| -> Result<(), String> {
            let rk: Vec<u32> = r.clone();
            let dst_r = self.small.ptr;
            self.upload(dst_r, &rk)?;
            let p = self.params(ext, &c, &[0], &[0], 1)?;
            let ntab = c.w + 1;
            let n_u = n_out as u32;
            let grid = ((n_out as u32).div_ceil(TEL)).min(GRID_CAP);
            let rp = self.small.ptr;
            for k in 0..ntab {
                let src = self.bufs[c.tab[k]].ptr;
                let dst = self.bufs[c.scratch].ptr;
                let mut args: [*mut c_void; 5] = [&p as *const _ as *mut _, &rp as *const _ as *mut _, &src as *const _ as *mut _, &dst as *const _ as *mut _, &n_u as *const _ as *mut _];
                self.launch(if c.base { "k_zc_fold_base" } else { "k_zc_fold_ext" }, (grid, 1), TEL, &mut args)?;
                let old = c.tab[k];
                c.tab[k] = c.scratch;
                c.scratch = old;
            }
            // the eq compaction: n_out / 2 pairs remain
            let eq_n = (n_out / 2) as u32;
            let src = self.eq[c.eq_cur].ptr;
            let dst = self.eq[1 - c.eq_cur].ptr;
            let mut args: [*mut c_void; 3] = [&src as *const _ as *mut _, &dst as *const _ as *mut _, &eq_n as *const _ as *mut _];
            let grid_e = (eq_n.div_ceil(TEL)).min(GRID_CAP);
            self.launch("k_zc_eq_compact", (grid_e, 1), TEL, &mut args)?;
            c.eq_cur = 1 - c.eq_cur;
            Ok(())
        })();
        if res.is_ok() {
            c.t += 1;
            c.n = n_out;
            c.base = false;
            c.expect_fold = false;
        }
        self.chain = Some(c);
        res
    }

    fn handover(&mut self, ext: &SubExt) -> Result<(Vec<ETab>, ETab), String> {
        self.dev.bind_to_thread().map_err(|e| format!("bind: {e}"))?;
        let c = self.chain.take().ok_or("zc: handover without a chain")?;
        assert!(!c.expect_fold, "[UPERF3-RR] zc: handover while a fold is expected");
        assert!(!c.base, "[UPERF3-RR] zc: handover before the first fold");
        let n = c.n;
        let cc = ext.c;
        self.sync()?;
        // The copies are whole 8-lane blocks; the lanes past the table's
        // length hold stale data from the earlier (larger) rounds on the
        // device, where the CPU's ETab pads are exact zeros (the kernels map
        // zeros to zeros; a stale eq lane would weigh a pad pair) — zero
        // them here.
        let zero = vec![0u32; cc];
        let mut tabs: Vec<ETab> = Vec::with_capacity(c.w + 1);
        let words = n.div_ceil(KL) * cc * KL;
        for k in 0..c.w + 1 {
            let mut t = ETab::zeroed(n, cc);
            let src = self.bufs[c.tab[k]].ptr;
            unsafe { cu::memcpy_dtoh_sync(&mut t.d[..words], src) }.map_err(|e| format!("d2h table: {e}"))?;
            for i in n..n.div_ceil(KL) * KL {
                t.set(i, &zero);
            }
            tabs.push(t);
        }
        let n_eq = n / 2;
        let mut eq = ETab::zeroed(n_eq, cc);
        let words_eq = n_eq.div_ceil(KL) * cc * KL;
        if words_eq > 0 {
            unsafe { cu::memcpy_dtoh_sync(&mut eq.d[..words_eq], self.eq[c.eq_cur].ptr) }.map_err(|e| format!("d2h eq: {e}"))?;
            for i in n_eq..n_eq.div_ceil(KL) * KL {
                eq.set(i, &zero);
            }
        }
        Ok((tabs, eq))
    }
}

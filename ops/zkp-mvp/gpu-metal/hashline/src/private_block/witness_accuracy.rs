//! R13 integer execution, before its values are assigned to proof planes.
//!
//! This is not a proof entry point. Registered legacy profiles continue to
//! use the legacy builder until every R13 relation and range check is active.
use super::*;
use crate::private_block::accuracy_precision::BaseShifts;
use crate::private_block::accuracy_public::{AccuracyPublic, Geometry};

// **H124c (2026-11-04): the builder's serial remainder, parallelized byte-identically.**
// A sampling profile of one W16R2 8B T128 block showed about 174 ms of its 253 ms outside
// the weight products, all on one thread: `quantized`, the score and softmax/PV loops,
// `assign`'s repeated supports. Each is element-wise or independent per head, so it now runs
// on rayon. The rules that keep it byte-identical:
// - integer sums keep their own order, and nothing is reassociated;
// - an error is the one the sequential loop would return first (chunks checked in order;
//   heads checked in logical order, each head's own first error);
// - the sequential code stays as the reference, chosen by `with_sequential` (tests) or when
//   the geometry does not split into whole per-slot chunks.
thread_local! {
    static SEQUENTIAL: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
}

fn sequential() -> bool {
    SEQUENTIAL.with(|s| s.get())
}

/// run `f` with this thread's builder on its sequential reference paths
#[cfg(test)]
pub(crate) fn with_sequential<R>(f: impl FnOnce() -> R) -> R {
    SEQUENTIAL.with(|s| s.set(true));
    let r = f();
    SEQUENTIAL.with(|s| s.set(false));
    r
}

/// below this many positions a parallel split costs more than it saves
const PAR_MIN: usize = 1 << 14;
const PAR_CHUNK: usize = 1 << 13;

/// A domain's support split by whole chunks of its plane: `groups[c]` holds the support
/// positions in `[c * stride, (c + 1) * stride)`. The chunks are token rows (D, Q, Kv, F),
/// head slots (S) or plain blocks (Dd).
struct ChunkPlan {
    stride: usize,
    groups: Vec<Vec<usize>>,
    /// [A16] the support's length (every position is in exactly one group)
    count: usize,
}

fn chunk_plan(g: &Geom, dom: Dom, support: &[usize]) -> Option<ChunkPlan> {
    let stride = match dom {
        Dom::D => g.d_pad,
        Dom::Q => g.q_pad,
        Dom::Kv => g.kvw,
        Dom::F => g.f_pad,
        Dom::S => g.t_pad * g.t_pad,
        Dom::Dd => 1 << 12,
        _ => return None,
    };
    let len = g.len(dom);
    if stride == 0 || len % stride != 0 || support.len() < PAR_MIN {
        return None;
    }
    let mut groups = vec![Vec::new(); len / stride];
    for &i in support {
        groups.get_mut(i / stride)?.push(i);
    }
    Some(ChunkPlan { stride, groups, count: support.len() })
}

// ---- [A16] the builder's serial remainder (see `witness.rs`, the [A16] block) ----

/// [A16] which of the block's public checks the caller has already run on the same data
/// at the same shape (`witness::build_accuracy_with`)
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub(super) enum Checked {
    /// none: `build` runs every check (its own tests)
    #[cfg_attr(not(test), allow(dead_code))]
    Nothing,
    /// `build_accuracy`'s three (`check_constructed`, `check_for_registry`, the gate shift)
    Registry,
    /// the whole `BlockPublic::check_accuracy_for_shape` (`build_for_block` under A16_ONCE)
    Block,
}

static PLANS: ShareCache<Option<ChunkPlan>> = ShareCache::new();

/// [A16] `chunk_plan(g, dom, support(dom))`, kept for the process
fn shared_plan(g: &Geom, dom: Dom) -> std::sync::Arc<Option<ChunkPlan>> {
    PLANS.get_or(g.cache_key(dom), || chunk_plan(g, dom, &g.support_shared(dom)))
}

/// [A16] a domain's support: kept for the process (A16_CACHE) or built
fn support_of(g: &Geom, dom: Dom, cache: bool) -> std::sync::Arc<Vec<usize>> {
    if cache {
        g.support_shared(dom)
    } else {
        std::sync::Arc::new(g.support(dom))
    }
}

/// [A16] a plan usable over a plane of `n` words whose support has `count` positions
fn plan_for(p: &Option<std::sync::Arc<Option<ChunkPlan>>>, n: usize, count: usize) -> Option<&ChunkPlan> {
    let pl = p.as_ref()?.as_ref().as_ref()?;
    (pl.stride > 0 && pl.groups.len() * pl.stride == n && pl.count == count).then_some(pl)
}

/// **[A16] `quantized` over whole chunks** (A16_QUANT): each chunk of the two output
/// planes is written by one task at its own support positions, with `quantized`'s
/// per-position function; no serial read-back. If any position refuses, `quantized`
/// itself runs and returns its (the sequential loop's) first refusal. Without a plan
/// for this plane, `quantized`.
#[allow(clippy::too_many_arguments)]
fn quantized_with(
    acc: Vec<i64>,
    support: &[usize],
    plan: Option<&ChunkPlan>,
    shift: u32,
    mult: &[u64],
    stride: usize,
    lo: i64,
    hi: i64,
    site: &'static str,
) -> Result<Quantized, String> {
    use rayon::prelude::*;
    let Some(pl) = plan.filter(|p| !sequential() && p.groups.len() * p.stride == acc.len() && p.count == support.len()) else {
        return quantized(acc, support, shift, mult, stride, lo, hi, site);
    };
    let st = pl.stride;
    let (mut words, mut rho) = (zeros(acc.len()), zeros(acc.len()));
    let ok = {
        // `quantized`'s `one`, with `mult[i % stride]` read without the division where the
        // multiplier's stride is the chunk's (`i - base == i % st` inside chunk `c`)
        let one = |i: usize, base: usize| -> Option<(i64, i64)> {
            let m = if stride == 1 { mult[0] } else if stride == st { mult[i - base] } else { mult[i % stride] };
            let r = crate::private_block::accuracy::requant(acc[i] as i128, m, shift).ok()?;
            if !(lo..=hi).contains(&r.word) {
                return None;
            }
            Some((r.word, i64::try_from(r.remainder).ok()?))
        };
        words.par_chunks_mut(st).zip(rho.par_chunks_mut(st)).zip(pl.groups.par_iter()).enumerate().all(|(c, ((w, r), pos))| {
            let base = c * st;
            for &i in pos {
                let Some((a, b)) = one(i, base) else { return false };
                w[i - base] = a;
                r[i - base] = b;
            }
            true
        })
    };
    if !ok {
        return quantized(acc, support, shift, mult, stride, lo, hi, site);
    }
    Ok(Quantized { words, rho })
}

/// [A16] one row of `normalized` (its loop body at row `t`, verbatim but for the i64
/// form): `(d, a1, a2)`, the row's words, remainders and complements written into
/// `w`, `r`, `s` (the row's slices of the three `Dom::D` planes)
#[allow(clippy::too_many_arguments)]
fn norm_row(g: &Geom, row: &[i64], gamma: &[i8], gmax: u128, tn: u32, cn: i64, w: &mut [i64], r: &mut [i64], s: &mut [i64]) -> Result<(i64, i64, i64), String> {
    let ss = g.s.norm_ceps + row.iter().map(|v| v * v).sum::<i64>();
    let d = isqrt(u64::try_from(ss).map_err(|_| range("norm denominator"))?) as i64;
    let (a1, a2) = (ss - d * d, 2 * d - (ss - d * d));
    if d == 0
        || [d, a1, a2]
            .iter()
            .any(|v| !(0..1i64 << (8 * LIMBS_ISQRT)).contains(v))
    {
        return Err(range("norm denominator"));
    }
    let dv = (d as i128) << tn;
    let denominator = 2 * dv;
    // every intermediate of `2 * x * gamma * cn + dv` is at most `bound` in magnitude; the
    // bound takes at least int16's maximum for `x` and the isqrt window's for `d` (checked
    // above), so for an int16 row the form chosen is a function of public constants only
    let rmax = row.iter().map(|v| v.unsigned_abs() as u128).max().unwrap_or(0).max(1 << 15);
    let dv_max = if tn < 64 { (1u128 << (8 * LIMBS_ISQRT)) << tn } else { u128::MAX };
    let bound = 2u128.saturating_mul(rmax).saturating_mul(gmax.max(1)).saturating_mul((cn.unsigned_abs() as u128).max(1)).saturating_add(dv_max);
    if bound < 1 << 62 && dv_max < 1 << 61 && denominator.unsigned_abs() < 1 << 62 {
        // the same Euclidean quotient and remainder as the i128 form: every value fits
        let (dv, denominator) = (dv as i64, denominator as i64);
        for i in 0..g.d {
            let numerator = 2 * row[i] * gamma[i] as i64 * cn + dv;
            let q = numerator.div_euclid(denominator);
            let rr = numerator.rem_euclid(denominator);
            let sg = denominator - 1 - rr;
            if !(-32768..=32767).contains(&q) || rr >= 1 << 24 || sg >= 1 << 24 {
                return Err(range("norm quotient/remainder"));
            }
            w[i] = q;
            r[i] = rr;
            s[i] = sg;
        }
    } else {
        for i in 0..g.d {
            let numerator = 2 * row[i] as i128 * gamma[i] as i128 * cn as i128 + dv;
            let q = numerator.div_euclid(denominator);
            let rr = numerator.rem_euclid(denominator);
            let sg = denominator - 1 - rr;
            if !(-32768..=32767).contains(&q) || rr >= 1 << 24 || sg >= 1 << 24 {
                return Err(range("norm quotient/remainder"));
            }
            w[i] = q as i64;
            r[i] = rr as i64;
            s[i] = sg as i64;
        }
    }
    Ok((d, a1, a2))
}

/// **[A16] `normalized`, its rows in parallel** (A16_NORM): each row is the sequential
/// loop's body ([`norm_row`]); the first refusal in row order is returned, which is the
/// sequential loop's (a row's refusal depends on that row alone). Outside the shapes it
/// covers, `normalized`.
fn normalized_par(g: &Geom, x: &[i64], gamma: &[i8], tn: u32, cn: i64) -> Result<Norm, String> {
    use rayon::prelude::*;
    let (dl, tl, dp) = (g.len(Dom::D), g.len(Dom::T), g.d_pad);
    if sequential() || dp == 0 || g.d > dp || dl % dp != 0 || dl / dp < g.t || tl < g.t || x.len() < g.t * dp || gamma.len() < g.d {
        return normalized(g, x, gamma, tn, cn);
    }
    let gmax = gamma[..g.d].iter().map(|v| v.unsigned_abs() as u128).max().unwrap_or(0);
    let (mut words, mut rho, mut sigma) = (zeros(dl), zeros(dl), zeros(dl));
    let rows: Vec<Result<(i64, i64, i64), String>> = words
        .par_chunks_mut(dp)
        .zip(rho.par_chunks_mut(dp))
        .zip(sigma.par_chunks_mut(dp))
        .take(g.t)
        .enumerate()
        .map(|(t, ((w, r), s))| norm_row(g, &x[t * dp..t * dp + g.d], gamma, gmax, tn, cn, w, r, s))
        .collect();
    let mut out = Norm { words, d: vec![0; tl], dsq: vec![0; tl], a1: vec![0; tl], a2: vec![0; tl], rho, sigma };
    for (t, row) in rows.into_iter().enumerate() {
        let (d, a1, a2) = row?;
        out.d[t] = d;
        out.dsq[t] = d * d;
        out.a1[t] = a1;
        out.a2[t] = a2;
    }
    Ok(out)
}

/// **[A16] `residual` over whole chunks** (A16_LOOPS): the same sum and class check at
/// every support position; on any refusal `residual` itself runs and returns its first
fn residual_with(g: &Geom, x: &[i64], y: &[i64], site: &'static str, plan: Option<&ChunkPlan>) -> Result<Vec<i64>, String> {
    use rayon::prelude::*;
    let n = g.len(Dom::D);
    if let Some(pl) = plan.filter(|p| !sequential() && p.groups.len() * p.stride == n && x.len() >= n && y.len() >= n) {
        let st = pl.stride;
        let mut out = zeros(n);
        let ok = out.par_chunks_mut(st).zip(pl.groups.par_iter()).enumerate().all(|(c, (ch, pos))| {
            let base = c * st;
            for &i in pos {
                match x[i].checked_add(y[i]).filter(|v| (-32768..=32767).contains(v)) {
                    Some(v) => ch[i - base] = v,
                    None => return false,
                }
            }
            true
        });
        if ok {
            return Ok(out);
        }
    }
    residual(g, x, y, site)
}

/// [A16] the words as int16 when every one is in int16's whole class (`-32768..=32767`),
/// converted on the pool; `None` otherwise
fn narrow16_par(x: &[i64]) -> Option<Vec<i16>> {
    use rayon::prelude::*;
    if !x.par_chunks(PAR_CHUNK).all(|c| c.iter().all(|&v| i16::try_from(v).is_ok())) {
        return None;
    }
    Some(x.par_iter().map(|&v| v as i16).collect())
}

/// [A16] `sum_i a[i] * b[i]` of int16 words: every product (at most 2^30) is exact in
/// i32 and the sum is accumulated in i64 in index order: the integer the i64 form gives
#[inline]
fn dot16_16(a: &[i16], b: &[i16]) -> i64 {
    a.iter().zip(b).map(|(&x, &y)| i64::from(i32::from(x) * i32::from(y))).sum()
}

// ---- end of [A16] helpers ----

/// H124c: fill the planes `targets[k]` at every support position, each plane over its
/// chunks in parallel; `cell(i, k)` checks position `i` and gives the plane-`k` word.
/// Every refusal `cell` can return is one fixed string per role, so the error is the
/// sequential loop's. A plane whose length does not match the plan is refused to the
/// caller, which then takes the sequential path.
fn fill_planes(planes: &mut [Vec<i64>], targets: &[usize], plan: &ChunkPlan, cell: &(dyn Fn(usize, usize) -> Result<i64, String> + Sync)) -> Option<Result<(), String>> {
    use rayon::prelude::*;
    if targets.iter().any(|&p| planes[p].len() != plan.groups.len() * plan.stride) {
        return None;
    }
    for (k, &p) in targets.iter().enumerate() {
        let mut plane = std::mem::take(&mut planes[p]);
        let r = plane.par_chunks_mut(plan.stride).zip(plan.groups.par_iter()).enumerate().try_for_each(|(c, (ch, pos))| -> Result<(), String> {
            for &i in pos {
                ch[i - c * plan.stride] = cell(i, k)?;
            }
            Ok(())
        });
        planes[p] = plane;
        if r.is_err() {
            return Some(r);
        }
    }
    Some(Ok(()))
}

/// the logical head of every padded head slot (`None` for a padding slot), or `None` when
/// the slots do not fit `nslots`
fn slot_heads(g: &Geom, nslots: usize) -> Option<Vec<Option<usize>>> {
    let mut inv = vec![None; nslots];
    for h in 0..g.hq {
        let s = g.slot(h);
        if s >= nslots || inv[s].is_some() {
            return None;
        }
        inv[s] = Some(h);
    }
    Some(inv)
}

#[derive(Debug)]
pub(super) struct Quantized {
    pub words: Vec<i64>,
    /// Biased Euclidean remainder: acc*m + half - word*2^shift.
    pub rho: Vec<i64>,
}

pub(super) struct Norm {
    pub words: Vec<i64>,
    pub d: Vec<i64>,
    pub dsq: Vec<i64>,
    pub a1: Vec<i64>,
    pub a2: Vec<i64>,
    pub rho: Vec<i64>,
    pub sigma: Vec<i64>,
}

pub(super) struct Trace {
    pub x: Vec<i64>,
    pub na: Norm,
    pub q: Quantized,
    pub k: Quantized,
    pub v: Quantized,
    pub qr: Quantized,
    pub kr: Quantized,
    pub s: Quantized,
    pub mx: Vec<i64>,
    pub sum: Vec<i64>,
    pub zsel: Vec<i64>,
    pub e: Vec<i64>,
    pub p: Vec<i64>,
    pub sr: Vec<i64>,
    pub sg: Vec<i64>,
    pub o: Quantized,
    pub ao: Quantized,
    pub x1: Vec<i64>,
    pub nm: Norm,
    pub gate: Quantized,
    pub a_scaled: Vec<i64>,
    pub up: Quantized,
    pub h: Quantized,
    pub z: Quantized,
    pub x2: Vec<i64>,
}

fn quantized(
    acc: Vec<i64>,
    support: &[usize],
    shift: u32,
    mult: &[u64],
    stride: usize,
    lo: i64,
    hi: i64,
    site: &'static str,
) -> Result<Quantized, String> {
    // one position, its checks in the sequential order
    let one = |i: usize| -> Result<(i64, i64), String> {
        let r = crate::private_block::accuracy::requant(acc[i] as i128, mult[i % stride], shift)?;
        if !(lo..=hi).contains(&r.word) {
            return Err(range(site));
        }
        Ok((r.word, i64::try_from(r.remainder).map_err(|_| range(site))?))
    };
    let mut words = vec![0; acc.len()];
    let mut rho = vec![0; acc.len()];
    if sequential() || support.len() < PAR_MIN {
        for &i in support {
            let (w, r) = one(i)?;
            words[i] = w;
            rho[i] = r;
        }
    } else {
        use rayon::prelude::*;
        // H124c: chunks in parallel; each stops at its own first error, and the chunks are
        // read back in order, so the error returned is the sequential loop's first
        let parts: Vec<Result<Vec<(i64, i64)>, String>> = support.par_chunks(PAR_CHUNK).map(|ch| ch.iter().map(|&i| one(i)).collect()).collect();
        for (ch, part) in support.chunks(PAR_CHUNK).zip(parts) {
            for (&i, (w, r)) in ch.iter().zip(part?) {
                words[i] = w;
                rho[i] = r;
            }
        }
    }
    Ok(Quantized { words, rho })
}

fn normalized(g: &Geom, x: &[i64], gamma: &[i8], tn: u32, cn: i64) -> Result<Norm, String> {
    let mut out = Norm {
        words: vec![0; g.len(Dom::D)],
        d: vec![0; g.len(Dom::T)],
        dsq: vec![0; g.len(Dom::T)],
        a1: vec![0; g.len(Dom::T)],
        a2: vec![0; g.len(Dom::T)],
        rho: vec![0; g.len(Dom::D)],
        sigma: vec![0; g.len(Dom::D)],
    };
    for t in 0..g.t {
        let row = &x[t * g.d_pad..t * g.d_pad + g.d];
        let ss = g.s.norm_ceps + row.iter().map(|v| v * v).sum::<i64>();
        let d = isqrt(u64::try_from(ss).map_err(|_| range("norm denominator"))?) as i64;
        let (a1, a2) = (ss - d * d, 2 * d - (ss - d * d));
        if d == 0
            || [d, a1, a2]
                .iter()
                .any(|v| !(0..1i64 << (8 * LIMBS_ISQRT)).contains(v))
        {
            return Err(range("norm denominator"));
        }
        out.d[t] = d;
        out.dsq[t] = d * d;
        out.a1[t] = a1;
        out.a2[t] = a2;
        let dv = (d as i128) << tn;
        let denominator = 2 * dv;
        for i in 0..g.d {
            let numerator = 2 * row[i] as i128 * gamma[i] as i128 * cn as i128 + dv;
            let q = numerator.div_euclid(denominator);
            let r = numerator.rem_euclid(denominator);
            let s = denominator - 1 - r;
            if !(-32768..=32767).contains(&q) || r >= 1 << 24 || s >= 1 << 24 {
                return Err(range("norm quotient/remainder"));
            }
            let index = g.dix(t, i);
            out.words[index] = q as i64;
            out.rho[index] = r as i64;
            out.sigma[index] = s as i64;
        }
    }
    Ok(out)
}

fn residual(g: &Geom, x: &[i64], y: &[i64], site: &'static str) -> Result<Vec<i64>, String> {
    let mut out = vec![0; g.len(Dom::D)];
    for i in g.support(Dom::D) {
        out[i] = x[i]
            .checked_add(y[i])
            .filter(|v| (-32768..=32767).contains(v))
            .ok_or_else(|| range(site))?;
    }
    Ok(out)
}

/// the whole trace, every public check run here (`build_with`, [`Checked::Nothing`])
#[cfg(test)]
pub(super) fn build(
    sh: &Shape,
    public: &AttentionPublic,
    ff: &FeedForwardPublic,
    accuracy: &AccuracyPublic,
    input: &[i16],
) -> Result<Trace, String> {
    build_with(sh, public, ff, accuracy, input, a16_forms(), Checked::Nothing)
}

/// the whole trace in the [A16] forms `forms`, after the public checks `checked`
pub(super) fn build_with(
    sh: &Shape,
    public: &AttentionPublic,
    ff: &FeedForwardPublic,
    accuracy: &AccuracyPublic,
    input: &[i16],
    forms: u32,
    checked: Checked,
) -> Result<Trace, String> {
    // [A16] the reference paths take no form
    let forms = if sequential() { 0 } else { forms };
    let once = forms & A16_ONCE != 0;
    // [A16] A16_ONCE: steps 3, 4 and 8 of `check_accuracy_for_shape`, which the caller ran
    if !(once && checked == Checked::Block) {
    public.check_for_shape(sh)?;
    ff.check_for_shape(sh)?;
    if [
        &public.wq,
        &public.wk,
        &public.wv,
        &public.wo,
        &public.gamma_a,
        &ff.wg_t,
        &ff.wu_t,
        &ff.wd_t,
        &ff.gamma_m,
    ]
    .into_iter()
    .any(|words| {
        // H124c: about 243 MB of weights per 8B block, scanned in parallel chunks
        use rayon::prelude::*;
        words.par_chunks(1 << 20).any(|c| c.contains(&i8::MIN))
    })
    {
        return Err("R13 public weights/gains must be symmetric int8".into());
    }
    }
    let geometry = Geometry {
        width: sh.width,
        query_width: sh.q_width(),
        kv_width: sh.kv_heads * sh.head_dim,
        hidden: sh.hidden,
    };
    let base = BaseShifts {
        norm_tn: sh.norm_tn,
        qkv: sh.sh_qkv,
        score: sh.sh_s,
        pv: sh.sh_o,
        ao: sh.sh_ao,
        gate: sh.sh_g,
        up: 0,
        product: sh.sh_h,
        down: sh.sh_z,
    };
    let registry=sh.accuracy_registry();
    // [A16] A16_ONCE: step 6, which `build_accuracy` (or `check_accuracy_for_shape`) ran
    // with the same registry, geometry and `sh.accuracy_base()` (this `base`, field for
    // field), passing only if `accuracy.stack() == sh.accuracy_stack()`
    if !(once && checked != Checked::Nothing) {
        accuracy.check_for_registry(registry, geometry, base, accuracy.stack())?;
    }
    let (p, m, folds) = (
        accuracy.precision(),
        accuracy.multipliers(),
        accuracy.folds(),
    );
    let g = Geom::new(sh);
    if input.len() != g.t * g.d {
        return Err("R13 witness: input shape".into());
    }
    // [A16] the forms of this build
    let (cache, quant, norm, loops, kernels) = (forms & A16_CACHE != 0, forms & A16_QUANT != 0, forms & A16_NORM != 0, forms & A16_LOOPS != 0, forms & A16_KERNELS != 0);
    // (tests: not while this thread pins its products with `with_device_products`, whose
    // thread-local switch and counter a product made on another thread would not see)
    let overlap = forms & A16_OVERLAP != 0 && !products_pinned();
    let (sd, sq, sk, ss, sf) = (
        support_of(&g, Dom::D, cache),
        support_of(&g, Dom::Q, cache),
        support_of(&g, Dom::Kv, cache),
        support_of(&g, Dom::S, cache),
        support_of(&g, Dom::F, cache),
    );
    // [A16] the chunk plans of the parallel forms (kept for the process)
    let plan_of = |dom: Dom| if quant || loops { Some(shared_plan(&g, dom)) } else { None };
    let (pd, pq, pk, ps, pf) = (plan_of(Dom::D), plan_of(Dom::Q), plan_of(Dom::Kv), plan_of(Dom::S), plan_of(Dom::F));
    fn qplan(quant: bool, p: &Option<std::sync::Arc<Option<ChunkPlan>>>, n: usize, count: usize) -> Option<&ChunkPlan> {
        if quant { plan_for(p, n, count) } else { None }
    }
    let (lq, lkv, ls, lf, ld) = (g.len(Dom::Q), g.len(Dom::Kv), g.len(Dom::S), g.len(Dom::F), g.len(Dom::D));
    let zero = |n: usize| if loops { zeros(n) } else { vec![0; n] };
    let mut x = zero(g.len(Dom::D));
    if loops && x.len() >= g.t * g.d_pad && g.d <= g.d_pad {
        // [A16] `sd` is `(t, i) -> t * d_pad + i` in (t, i) order, zipped with `input[t * d + i]`
        use rayon::prelude::*;
        x.par_chunks_mut(g.d_pad).take(g.t).enumerate().for_each(|(t, row)| {
            for i in 0..g.d {
                row[i] = input[t * g.d + i] as i64;
            }
        });
    } else {
        for (&i, &word) in sd.iter().zip(input) {
            x[i] = word as i64;
        }
    }
    let norm_of = |x: &[i64], gamma: &[i8], cn: i64| if norm { normalized_par(&g, x, gamma, p.norm_tn, cn) } else { normalized(&g, x, gamma, p.norm_tn, cn) };
    let na = norm_of(&x, &public.gamma_a, sh.norm_cn_a)?;
    let pad = |words: &[u16], width: usize| {
        let mut out = vec![1; width];
        for (dst, &word) in out.iter_mut().zip(words) {
            *dst = word as u64;
        }
        out
    };
    let mut mq = vec![1; g.q_pad];
    for h in 0..g.hq {
        for i in 0..g.dh {
            mq[g.slot(h) * g.dh + i] = m.q[h * g.dh + i] as u64;
        }
    }
    // the five requantized products of the attention input, each as before (A16_QUANT:
    // over whole chunks)
    let q_of = || {
        quantized_with(
            matmul(&g, &na.words, g.d_pad, &public.wq, g.d_pad, g.q_pad, g.q_pad, lq),
            &sq,
            qplan(quant, &pq, lq, sq.len()),
            p.q,
            &mq,
            g.q_pad,
            -32768,
            32767,
            "Q",
        )
    };
    let k_of = || {
        quantized_with(
            matmul(&g, &na.words, g.d_pad, &public.wk, g.d_pad, g.kvw, g.kvw, lkv),
            &sk,
            qplan(quant, &pk, lkv, sk.len()),
            p.k,
            &pad(&m.k, g.kvw),
            g.kvw,
            -32768,
            32767,
            "K",
        )
    };
    let v_of = || {
        quantized_with(
            matmul(&g, &na.words, g.d_pad, &public.wv, g.d_pad, g.kvw, g.kvw, lkv),
            &sk,
            qplan(quant, &pk, lkv, sk.len()),
            p.v,
            &pad(&m.v, g.kvw),
            g.kvw,
            -32768,
            32767,
            "V",
        )
    };
    let qr_of = |q: &Quantized| {
        quantized_with(
            rotate(&g, &q.words, g.h_pad, g.q_pad, lq, &public.rope_cos, &public.rope_sin),
            &sq,
            qplan(quant, &pq, lq, sq.len()),
            SH_ROPE,
            &[1],
            1,
            -32768,
            32767,
            "QR",
        )
    };
    let kr_of = |k: &Quantized| {
        quantized_with(
            rotate(&g, &k.words, g.hkv, g.kvw, lkv, &public.rope_cos, &public.rope_sin),
            &sk,
            qplan(quant, &pk, lkv, sk.len()),
            SH_ROPE,
            &[1],
            1,
            -32768,
            32767,
            "KR",
        )
    };
    let (q, k, v, qr, kr) = if overlap {
        // [A16] A16_OVERLAP: Q and its rotation, K and its rotation, and V side by side;
        // the refusals in the sequential order Q, K, V, QR, KR (nothing else is skipped)
        let ((q, qr), ((k, kr), v)) = rayon::join(
            || {
                let q = q_of();
                let qr = q.as_ref().ok().map(qr_of);
                (q, qr)
            },
            || {
                rayon::join(
                    || {
                        let k = k_of();
                        let kr = k.as_ref().ok().map(kr_of);
                        (k, kr)
                    },
                    v_of,
                )
            },
        );
        let (q, k, v) = (q?, k?, v?);
        (q, k, v, qr.expect("Q was made")?, kr.expect("K was made")?)
    } else {
        let q = q_of()?;
        let k = k_of()?;
        let v = v_of()?;
        let qr = qr_of(&q)?;
        let kr = kr_of(&k)?;
        (q, k, v, qr, kr)
    };
    let mut sacc = zero(ls);
    // H124c: `six` is contiguous per head slot, so each slot's scores are one task
    let tt = g.t_pad * g.t_pad;
    let heads_of_slots = if sacc.len() % tt == 0 { slot_heads(&g, sacc.len() / tt) } else { None };
    // [A16] A16_KERNELS: the rotated Q and K words as int16 (they were range-checked to
    // int16 by their requantization, so for an admissible trace this never declines)
    let qk16 = if kernels { narrow16_par(&qr.words).zip(narrow16_par(&kr.words)) } else { None };
    match heads_of_slots {
        Some(inv) if !sequential() => {
            use rayon::prelude::*;
            let (qw, kw) = (&qr.words, &kr.words);
            match &qk16 {
                Some((q16, k16)) => {
                    // [A16] each score is the same exact integer sum over the head dimension, of
                    // contiguous int16 rows (`qix(t, hs, i)` and `kvix(j, kv, i)` are `+ i`), in
                    // the same order
                    sacc.par_chunks_mut(tt).enumerate().for_each(|(hs, ch)| {
                        let Some(h) = inv[hs] else { return };
                        let kv = h / g.group;
                        for t in 0..g.t {
                            let qb = g.qix(t, hs, 0);
                            let qs = &q16[qb..qb + g.dh];
                            for j in 0..g.t {
                                let kb = g.kvix(j, kv, 0);
                                ch[t * g.t_pad + j] = dot16_16(qs, &k16[kb..kb + g.dh]);
                            }
                        }
                    });
                }
                None => {
            sacc.par_chunks_mut(tt).enumerate().for_each(|(hs, ch)| {
                let Some(h) = inv[hs] else { return };
                for t in 0..g.t {
                    for j in 0..g.t {
                        ch[t * g.t_pad + j] = (0..g.dh).map(|i| qw[g.qix(t, hs, i)] * kw[g.kvix(j, h / g.group, i)]).sum();
                    }
                }
            });
                }
            }
        }
        _ => {
            for h in 0..g.hq {
                for t in 0..g.t {
                    for j in 0..g.t {
                        sacc[g.six(g.slot(h), t, j)] = (0..g.dh)
                            .map(|i| qr.words[g.qix(t, g.slot(h), i)] * kr.words[g.kvix(j, h / g.group, i)])
                            .sum();
                    }
                }
            }
        }
    }
    // This includes masked future scores. Their range is still checked.
    let s = quantized_with(sacc, &ss, qplan(quant, &ps, ls, ss.len()), p.score, &[1], 1, -127, 127, "score")?;
    let mut mx = vec![0; g.len(Dom::Ht)];
    let mut sum = mx.clone();
    let mut zsel = zero(ls);
    // [A16] A16_LOOPS: four more zero planes zeroed on the pool, not cloned on this thread
    let (mut e, mut probability, mut sr, mut sg) = if loops { (zeros(ls), zeros(ls), zeros(ls), zeros(ls)) } else { (zsel.clone(), zsel.clone(), zsel.clone(), zsel.clone()) };
    let mut oacc = zero(lq);
    // H124c: per head slot in parallel when the S and Ht planes split into the same
    // number of whole slot chunks; otherwise the sequential loop below
    let nslots = zsel.len() / tt;
    let par_heads = if !sequential() && zsel.len() == nslots * tt && mx.len() == nslots * g.t_pad { slot_heads(&g, nslots) } else { None };
    // [A16] A16_KERNELS: the value words as int16 (range-checked by their requantization)
    let v16_own = if kernels && par_heads.is_some() { narrow16_par(&v.words) } else { None };
    let v16 = v16_own.as_deref();
    if let Some(inv) = par_heads {
        use rayon::prelude::*;
        let (sw, vw, exp, wrho_s, f_p) = (&s.words, &v.words, &public.exp, sh.wrho_s, p.f_p);
        let outs: Vec<Result<Vec<i64>, String>> = zsel
            .par_chunks_mut(tt)
            .zip(e.par_chunks_mut(tt))
            .zip(probability.par_chunks_mut(tt))
            .zip(sr.par_chunks_mut(tt))
            .zip(sg.par_chunks_mut(tt))
            .zip(mx.par_chunks_mut(g.t_pad))
            .zip(sum.par_chunks_mut(g.t_pad))
            .enumerate()
            .map(|(hs, ((((((zsel, e), probability), sr), sg), mx), sum))| -> Result<Vec<i64>, String> {
                let Some(h) = inv[hs] else { return Ok(Vec::new()) };
                // a slot's own coordinates: six(hs, t, j) - hs * tt and htix(hs, t) - hs * t_pad
                let at = |t: usize, j: usize| t * g.t_pad + j;
                let mut o = vec![0i64; g.t * g.dh];
                for t in 0..g.t {
                    let best = (0..=t).map(|j| sw[g.six(hs, t, j)]).max().unwrap();
                    let arg = (0..=t).find(|&j| sw[g.six(hs, t, j)] == best).unwrap();
                    mx[t] = best;
                    zsel[at(t, arg)] = 1;
                    let total: i64 = (0..=t).map(|j| exp[(best - sw[g.six(hs, t, j)]) as usize]).sum();
                    if total <= 0 {
                        return Err(range("softmax"));
                    }
                    sum[t] = total;
                    for j in 0..g.t {
                        let index = at(t, j);
                        let masked = if j <= t { sw[g.six(hs, t, j)] } else { MASK_SCORE };
                        let delta = best - masked;
                        if !(0..256).contains(&delta) {
                            return Err(range("exp difference"));
                        }
                        e[index] = exp[delta as usize];
                        let numerator = if j <= t { e[index] << f_p } else { 0 };
                        probability[index] = numerator / total;
                        sr[index] = numerator % total;
                        sg[index] = total - 1 - sr[index];
                        if sg[index] >= 1 << wrho_s {
                            return Err(range("softmax"));
                        }
                    }
                    // [A16] A16_KERNELS: the same sums, accumulated j by j over contiguous int16
                    // value rows (`kvix(j, kv, i)` is `+ i`): for each `i` the terms are added in
                    // the order j = 0..=t onto 0, as the old sum adds them; a row whose weights
                    // are not all int16 (never, for an admissible trace) keeps the old form
                    let prow = &probability[at(t, 0)..at(t, 0) + t + 1];
                    match v16 {
                        Some(v16) if prow.iter().all(|&p| i16::try_from(p).is_ok()) => {
                            let kv = h / g.group;
                            let orow = &mut o[t * g.dh..(t + 1) * g.dh];
                            for (j, &pj) in prow.iter().enumerate() {
                                let vb = g.kvix(j, kv, 0);
                                let pj = pj as i32;
                                for (acc, &vv) in orow.iter_mut().zip(&v16[vb..vb + g.dh]) {
                                    *acc += i64::from(pj * i32::from(vv));
                                }
                            }
                        }
                        _ => {
                    for i in 0..g.dh {
                        o[t * g.dh + i] = (0..=t).map(|j| probability[at(t, j)] * vw[g.kvix(j, h / g.group, i)]).sum();
                    }
                        }
                    }
                }
                Ok(o)
            })
            .collect();
        // the sequential loop's error: heads in logical order, each head's own first error
        for h in 0..g.hq {
            if let Err(err) = &outs[g.slot(h)] {
                return Err(err.clone());
            }
        }
        if loops && oacc.len() >= g.t * g.q_pad && g.hq <= g.h_pad {
            // [A16] A16_LOOPS: the same scatter by rows of `Dom::Q` (`qix(t, hs, i)` is
            // `t * q_pad + hs * dh + i`; each (t, hs, i) is written once)
            use rayon::prelude::*;
            let outs = &outs;
            oacc.par_chunks_mut(g.q_pad).take(g.t).enumerate().for_each(|(t, row)| {
                for h in 0..g.hq {
                    let hs = g.slot(h);
                    if let Ok(o) = &outs[hs] {
                        row[hs * g.dh..(hs + 1) * g.dh].copy_from_slice(&o[t * g.dh..(t + 1) * g.dh]);
                    }
                }
            });
        } else {
        for h in 0..g.hq {
            let hs = g.slot(h);
            if let Ok(o) = &outs[hs] {
                for t in 0..g.t {
                    for i in 0..g.dh {
                        oacc[g.qix(t, hs, i)] = o[t * g.dh + i];
                    }
                }
            }
        }
        }
    } else {
    for h in 0..g.hq {
        for t in 0..g.t {
            let hs = g.slot(h);
            let best = (0..=t).map(|j| s.words[g.six(hs, t, j)]).max().unwrap();
            let arg = (0..=t).find(|&j| s.words[g.six(hs, t, j)] == best).unwrap();
            mx[g.htix(hs, t)] = best;
            zsel[g.six(hs, t, arg)] = 1;
            let total: i64 = (0..=t)
                .map(|j| public.exp[(best - s.words[g.six(hs, t, j)]) as usize])
                .sum();
            if total <= 0 {
                return Err(range("softmax"));
            }
            sum[g.htix(hs, t)] = total;
            for j in 0..g.t {
                let index = g.six(hs, t, j);
                let masked = if j <= t { s.words[index] } else { MASK_SCORE };
                let delta = best - masked;
                if !(0..256).contains(&delta) {
                    return Err(range("exp difference"));
                }
                e[index] = public.exp[delta as usize];
                let numerator = if j <= t { e[index] << p.f_p } else { 0 };
                probability[index] = numerator / total;
                sr[index] = numerator % total;
                sg[index] = total - 1 - sr[index];
                if sg[index] >= 1 << sh.wrho_s {
                    return Err(range("softmax"));
                }
            }
            for i in 0..g.dh {
                oacc[g.qix(t, hs, i)] = (0..=t)
                    .map(|j| probability[g.six(hs, t, j)] * v.words[g.kvix(j, h / g.group, i)])
                    .sum();
            }
        }
    }
    }
    // The ungated exp lookup also covers padded score coordinates.
    let ungated = |e: &mut [i64]| -> Result<(), String> {
        for index in 0..e.len() {
            let (ht, j) = (index / g.t_pad, index % g.t_pad);
            let masked = if j <= ht % g.t_pad {
                s.words[index]
            } else {
                MASK_SCORE
            };
            let delta = mx[ht] - masked;
            if !(0..256).contains(&delta) {
                return Err(range("exp difference"));
            }
            e[index] = public.exp[delta as usize];
        }
        Ok(())
    };
    if loops && g.t_pad > 0 && e.len() % g.t_pad == 0 && e.len() / g.t_pad <= mx.len() && s.words.len() >= e.len() {
        // [A16] A16_LOOPS: by rows of `t_pad` (row `ht` holds the indices `ht * t_pad + j`);
        // on any refusal the loop above runs and names its first
        use rayon::prelude::*;
        let (tp, sw, mxr, exp) = (g.t_pad, &s.words, &mx, &public.exp);
        let ok = e.par_chunks_mut(tp).enumerate().all(|(ht, row)| {
            let (base, top) = (ht * tp, ht % tp);
            for (j, slot) in row.iter_mut().enumerate() {
                let masked = if j <= top { sw[base + j] } else { MASK_SCORE };
                let delta = mxr[ht] - masked;
                if !(0..256).contains(&delta) {
                    return false;
                }
                *slot = exp[delta as usize];
            }
            true
        });
        if !ok {
            ungated(&mut e)?;
        }
    } else {
        ungated(&mut e)?;
    }
    let o = quantized_with(oacc, &sq, qplan(quant, &pq, lq, sq.len()), p.pv, &[1], 1, -32768, 32767, "O")?;
    let ao = quantized_with(
        matmul(
            &g,
            &o.words,
            g.q_pad,
            &public.wo,
            g.q_pad,
            g.d_pad,
            g.d_pad,
            ld,
        ),
        &sd,
        qplan(quant, &pd, ld, sd.len()),
        p.ao,
        &pad(&m.o, g.d_pad),
        g.d_pad,
        -32768,
        32767,
        "AO",
    )?;
    // [A16] A16_LOOPS: the residuals over whole chunks
    let res = |x: &[i64], y: &[i64], site: &'static str| if loops { residual_with(&g, x, y, site, plan_for(&pd, ld, sd.len())) } else { residual(&g, x, y, site) };
    let x1 = res(&x, &ao.words, "residual 1")?;
    let nm = norm_of(&x1, &ff.gamma_m, sh.norm_cn_m)?;
    let mut mg = vec![1; g.f_pad];
    mg[..g.f].copy_from_slice(&folds.gate.multipliers);
    let gate_of = || {
        quantized_with(
            matmul_in_out(&g, &nm.words, g.d_pad, &ff.wg_t, g.d_pad, g.f_pad, g.f_pad, lf),
            &sf,
            qplan(quant, &pf, lf, sf.len()),
            folds.gate.shift,
            &mg,
            g.f_pad,
            -2048,
            2047,
            "FFN gate",
        )
    };
    let up_of = || {
        quantized_with(
            matmul_in_out(&g, &nm.words, g.d_pad, &ff.wu_t, g.d_pad, g.f_pad, g.f_pad, lf),
            &sf,
            qplan(quant, &pf, lf, sf.len()),
            p.up,
            &pad(&m.u, g.f_pad),
            g.f_pad,
            -32768,
            32767,
            "FFN up",
        )
    };
    let (gate, up) = if overlap {
        // [A16] A16_OVERLAP: gate beside up; gate's refusal first
        let (gate, up) = rayon::join(gate_of, up_of);
        (gate?, up?)
    } else {
        let gate = gate_of()?;
        (gate, up_of()?)
    };
    let a_scaled_seq = || {
        let mut a_scaled = vec![0; lf];
        for &i in sf.iter() {
            a_scaled[i] = accuracy.scaled_tables()[accuracy.group_ids()[i % g.f_pad]]
                [(gate.words[i] + 2048) as usize];
        }
        a_scaled
    };
    let a_scaled = match plan_for(&pf, lf, sf.len()).filter(|pl| loops && pl.stride == g.f_pad && gate.words.len() >= lf) {
        Some(pl) => {
            // [A16] A16_LOOPS: over whole rows of `Dom::F` (`i % f_pad == i - base` in row
            // `c`); a lookup the sequential loop would not make in bounds sends it there
            use rayon::prelude::*;
            let (tables, ids) = (accuracy.scaled_tables(), accuracy.group_ids());
            let mut a = zeros(lf);
            let ok = a.par_chunks_mut(pl.stride).zip(pl.groups.par_iter()).enumerate().all(|(c, (ch, pos))| {
                let base = c * pl.stride;
                for &i in pos {
                    let word = ids
                        .get(i - base)
                        .and_then(|&k| tables.get(k))
                        .and_then(|t| usize::try_from(gate.words[i] + 2048).ok().and_then(|ix| t.get(ix)));
                    match word {
                        Some(w) => ch[i - base] = *w,
                        None => return false,
                    }
                }
                true
            });
            if ok { a } else { a_scaled_seq() }
        }
        None => a_scaled_seq(),
    };
    let hacc: Vec<i64> = if loops {
        // [A16] A16_LOOPS: the same element-wise products, collected in order on the pool
        use rayon::prelude::*;
        a_scaled.par_iter().zip(up.words.par_iter()).map(|(a, u)| a * u).collect()
    } else {
        a_scaled.iter().zip(&up.words).map(|(a, u)| a * u).collect()
    };
    let bias = 1i64 << (p.product_bits - 1);
    let h = quantized_with(
        hacc,
        &sf,
        qplan(quant, &pf, lf, sf.len()),
        folds.product.shift,
        &[1],
        1,
        -bias,
        bias - 1,
        "FFN product",
    )?;
    let z = quantized_with(
        matmul_in_out(
            &g,
            &h.words,
            g.f_pad,
            &ff.wd_t,
            g.f_pad,
            g.d_pad,
            g.d_pad,
            ld,
        ),
        &sd,
        qplan(quant, &pd, ld, sd.len()),
        p.down,
        &pad(&m.d, g.d_pad),
        g.d_pad,
        -32768,
        32767,
        "FFN down",
    )?;
    let x2 = res(&x1, &z.words, "residual 2")?;
    Ok(Trace {
        x,
        na,
        q,
        k,
        v,
        qr,
        kr,
        s,
        mx,
        sum,
        zsel,
        e,
        p: probability,
        sr,
        sg,
        o,
        ao,
        x1,
        nm,
        gate,
        a_scaled,
        up,
        h,
        z,
        x2,
    })
}

// Assign the independently tested integer trace to R13's explicit roles.
// This helper does not activate a proof profile or assert that host relations
// are integrated. Histogram planes remain empty for the protocol to derive.
#[cfg(test)]
pub(super) fn assign(
    sh: &Shape, public: &AttentionPublic, data: &AccuracyPublic, trace: Trace,
) -> Result<Witness,String> {
    assign_with(sh,public,data,trace,a16_forms())
}

/// `assign` in the [A16] forms `forms` (A16_CACHE: the supports and chunk plans kept for
/// the process, not rebuilt per block; the same vectors)
pub(super) fn assign_with(
    sh: &Shape, public: &AttentionPublic, data: &AccuracyPublic, trace: Trace, forms: u32,
) -> Result<Witness,String> {
    use crate::private_block::accuracy_layout::{AccuracyIds,Limbs as L};
    let cache=!sequential() && forms&A16_CACHE!=0;
    let g=Geom::new(sh);
    // W16 (D54): the 16-bit allocation; every other profile keeps R13's
    let w16=sh.range16();
    let ids=if w16 {AccuracyIds::new_w16(data.stack(),sh.dd_cap>0,&data.precision(),sh.accuracy_gate_shift,sh.wrho_s,sh.log_cols)?}
        else {AccuracyIds::new(data.stack(),sh.dd_cap>0,sh.limbs_sigma_s())?};
    let mut planes:Vec<Vec<i64>>=ids.doms.iter().map(|&d| if d==Dom::Tab {Vec::new()} else {vec![0;g.len(d)]}).collect();
    let write=|planes:&mut Vec<Vec<i64>>,old:usize,words:Vec<i64>| -> Result<(),String> {
        let at=ids.map[old];
        if at==usize::MAX || words.len()!=g.len(ids.doms[at]) {return Err("R13 witness: word plane shape mismatch".into());}
        planes[at]=words; Ok(())
    };
    // W16: a role of `count` 16-bit limbs. A role with no plane is a word
    // looked up directly (range-checked here all the same); the product
    // word's single plane at LowH24 is its TOP limb (`range16::word24`)
    let role_dom=|role:L| -> Dom {
        match role {
            L::X|L::Y|L::Nr|L::Ns|L::Ao|L::Rao|L::X1|L::Ym|L::Mr|L::Ms|L::Z|L::Rd|L::X2=>Dom::D,
            L::Q|L::Rq|L::Qr|L::Rqr|L::O|L::Ro=>Dom::Q,
            L::K|L::Rk|L::V|L::Rv|L::Kr|L::Rkr=>Dom::Kv,
            L::Rs=>Dom::S,
            L::P|L::Sr|L::Sg=>if sh.dd_cap>0 {Dom::Dd} else {Dom::S},
            L::Rg|L::Up|L::Ru|L::H|L::Rh=>Dom::F,
        }
    };
    // H124c: each domain's support is built once, not once per role (about 15 ms per 8B block)
    // [A16] A16_CACHE: once per geometry for the process instead (the same vectors)
    let supports:std::cell::RefCell<Vec<(Dom,std::sync::Arc<Vec<usize>>)>>=std::cell::RefCell::new(Vec::new());
    let support=|dom:Dom| -> std::sync::Arc<Vec<usize>> {
        if cache {return g.support_shared(dom);}
        if let Some((_,v))=supports.borrow().iter().find(|(d,_)| *d==dom) {return v.clone();}
        let v=std::sync::Arc::new(g.support(dom)); supports.borrow_mut().push((dom,v.clone())); v
    };
    // H124c: and each domain's chunk plan once, for the parallel limb fills
    let plans:std::cell::RefCell<Vec<(Dom,std::sync::Arc<Option<ChunkPlan>>)>>=std::cell::RefCell::new(Vec::new());
    let plan=|dom:Dom| -> std::sync::Arc<Option<ChunkPlan>> {
        if cache {return shared_plan(&g,dom);}
        if let Some((_,v))=plans.borrow().iter().find(|(d,_)| *d==dom) {return v.clone();}
        let v=std::sync::Arc::new(if sequential() {None} else {chunk_plan(&g,dom,&support(dom))}); plans.borrow_mut().push((dom,v.clone())); v
    };
    let decompose16=|planes:&mut Vec<Vec<i64>>,role:L,values:&[i64],bias:i64| -> Result<(),String> {
        let (count,dom)=(ids.count(role),role_dom(role));
        if values.len()!=g.len(dom) {return Err("W16 witness: limb source shape mismatch".into());}
        let top_only=role==L::H && count==1;
        // a word or one-limb remainder is 16 bits; a two-limb remainder and
        // the product word are 24 (the lookups then pin each limb's width)
        let width=if top_only || count==2 {24} else {16};
        if let Some(pl)=plan(dom).as_ref() {
            let targets:Vec<usize>=if top_only {vec![ids.limb(role,0)]} else {(0..count).map(|k| ids.limb(role,k)).collect()};
            let cell=|i:usize,k:usize| -> Result<i64,String> {
                let value=values[i].checked_add(bias).filter(|&v| v>=0 && v<(1i64<<width))
                    .ok_or_else(||range("W16 limb decomposition"))?;
                Ok(if top_only {crate::private_block::range16::word24_top(values[i],bias)} else {(value>>(16*k))&0xffff})
            };
            if let Some(r)=fill_planes(planes,&targets,pl,&cell) {return r;}
        }
        for &i in support(dom).iter() {
            let value=values[i].checked_add(bias).filter(|&v| v>=0 && v<(1i64<<width))
                .ok_or_else(||range("W16 limb decomposition"))?;
            if top_only {planes[ids.limb(role,0)][i]=crate::private_block::range16::word24_top(values[i],bias); continue;}
            for k in 0..count {planes[ids.limb(role,k)][i]=(value>>(16*k))&0xffff;}
        }
        Ok(())
    };
    let decompose=|planes:&mut Vec<Vec<i64>>,role:L,values:&[i64],bias:i64| -> Result<(),String> {
        if w16 {return decompose16(planes,role,values,bias);}
        let count=ids.count(role); let dom=ids.doms[ids.limb(role,0)];
        if values.len()!=g.len(dom) {return Err("R13 witness: limb source shape mismatch".into());}
        if let Some(pl)=plan(dom).as_ref() {
            let targets:Vec<usize>=(0..count).map(|k| ids.limb(role,k)).collect();
            let cell=|i:usize,k:usize| -> Result<i64,String> {
                let value=values[i].checked_add(bias).filter(|&v| v>=0 && v<(1i64<<(8*count)))
                    .ok_or_else(||range("R13 limb decomposition"))?;
                Ok((value>>(8*k))&255)
            };
            if let Some(r)=fill_planes(planes,&targets,pl,&cell) {return r;}
        }
        for &i in support(dom).iter() {
            let value=values[i].checked_add(bias).filter(|&v| v>=0 && v<(1i64<<(8*count)))
                .ok_or_else(||range("R13 limb decomposition"))?;
            for k in 0..count {planes[ids.limb(role,k)][i]=(value>>(8*k))&255;}
        }
        Ok(())
    };
    let norm=|planes:&mut Vec<Vec<i64>>,n:&Norm,d:usize,dsq:usize,l:usize,nr:L,ns:L,y:L| -> Result<(),String> {
        write(planes,d,n.d.clone())?; write(planes,dsq,n.dsq.clone())?;
        let mut packed=vec![0;g.len(Dom::L)];
        for (component,values) in [&n.d,&n.a1,&n.a2].into_iter().enumerate() {
            for t in 0..g.t {
                if !(0..1<<24).contains(&values[t]) {return Err(range("R13 isqrt limbs"));}
                for k in 0..LIMBS_ISQRT {packed[g.lix(component*LIMBS_ISQRT+k,t)]=(values[t]>>(8*k))&255;}
            }
        }
        write(planes,l,packed)?; decompose(planes,nr,&n.rho,0)?; decompose(planes,ns,&n.sigma,0)?;
        decompose(planes,y,&n.words,32768)
    };
    norm(&mut planes,&trace.na,A_D,A_DSQ,A_LIMB,L::Nr,L::Ns,L::Y)?;
    norm(&mut planes,&trace.nm,A_DM,A_DSQM,A_LIMBM,L::Mr,L::Ms,L::Ym)?;
    for (role,values,bias) in [(L::X,&trace.x,32768),(L::Ao,&trace.ao.words,32768),
        (L::Rao,&trace.ao.rho,0),(L::X1,&trace.x1,32768),(L::Z,&trace.z.words,32768),
        (L::Rd,&trace.z.rho,0),(L::X2,&trace.x2,32768),
        (L::Q,&trace.q.words,32768),(L::Rq,&trace.q.rho,0),(L::Qr,&trace.qr.words,32768),(L::Rqr,&trace.qr.rho,0),
        (L::O,&trace.o.words,32768),(L::Ro,&trace.o.rho,0),(L::K,&trace.k.words,32768),(L::Rk,&trace.k.rho,0),
        (L::V,&trace.v.words,32768),(L::Rv,&trace.v.rho,0),(L::Kr,&trace.kr.words,32768),(L::Rkr,&trace.kr.rho,0),
        (L::Rs,&trace.s.rho,0),(L::Rg,&trace.gate.rho,0),(L::Up,&trace.up.words,32768),
        (L::Ru,&trace.up.rho,0),(L::H,&trace.h.words,1i64<<(data.precision().product_bits-1)),(L::Rh,&trace.h.rho,0)] {
        decompose(&mut planes,role,values,bias)?;
    }
    if sh.dd_cap==0 {
        decompose(&mut planes,L::P,&trace.p,0)?;
        decompose(&mut planes,L::Sr,&trace.sr,0)?;
        decompose(&mut planes,L::Sg,&trace.sg,0)?;
    } else {
        sh.check_dd_geometry()?;
        let column=public.dd_e_column(sh.dd_cap)?;
        let mut q=vec![0;g.len(Dom::Dd)]; let mut rho=q.clone();let mut sigma=q.clone();let mut counts=q.clone();
        for h in 0..g.hq {for t in 0..g.t {
            let hs=g.slot(h);let total=trace.sum[g.htix(hs,t)];let base=(hs*g.t_pad+t)*sh.dd_cap;
            if total<=0 {return Err(range("R13 dictionary denominator"));}
            for (k,&e) in column.iter().enumerate() {
                let numerator=e.checked_shl(data.precision().f_p).ok_or_else(||range("R13 dictionary numerator"))?;
                q[base+k]=numerator/total;rho[base+k]=numerator%total;sigma[base+k]=total-1-rho[base+k];
                if !(0..=1<<data.precision().f_p).contains(&q[base+k])
                    || !(0..1i64<<sh.wrho_s).contains(&sigma[base+k]) {return Err(range("R13 dictionary quotient/remainder"));}
            }
            for j in 0..g.t_pad {
                let e=if j<=t {trace.e[g.six(hs,t,j)]} else {0};
                let k=column.iter().position(|&word|word==e).ok_or_else(||range("R13 dictionary column"))?;
                counts[base+k]+=1;
            }
        }}
        decompose(&mut planes,L::P,&q,0)?;decompose(&mut planes,L::Sr,&rho,0)?;decompose(&mut planes,L::Sg,&sigma,0)?;
        planes[ids.pdict]=q;planes[ids.mdd]=counts;
    }
    for (old,values) in [(A_X,trace.x),(A_Y,trace.na.words),(A_YM,trace.nm.words),
        (A_Q8,trace.q.words),(A_K8,trace.k.words),(A_V8,trace.v.words),(A_QR8,trace.qr.words),(A_KR8,trace.kr.words),
        (A_S8,trace.s.words),(A_MX,trace.mx),(A_SUM,trace.sum),(A_ZSEL,trace.zsel),(A_E,trace.e),(A_P,trace.p),
        (A_O8,trace.o.words),(A_AO,trace.ao.words),(A_X1,trace.x1),(A_G8,trace.gate.words),
        (A_A16,trace.a_scaled),(A_U16,trace.up.words),(A_H16,trace.h.words),(A_Z16,trace.z.words),(A_X2,trace.x2)] {
        write(&mut planes,old,values)?;
    }
    Ok(Witness {planes,output_plane:ids.map[A_X2]})
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::accuracy_groups::Group;
    use crate::private_block::accuracy_precision::Stack;
    use crate::private_block::accuracy_public::Multipliers;
    use std::collections::BTreeMap;

    fn parse(text: &str) -> BTreeMap<&str, Vec<i64>> {
        text.lines()
            .map(|line| {
                let mut cells = line.split('\t');
                (
                    cells.next().unwrap(),
                    cells.map(|s| s.parse().unwrap()).collect(),
                )
            })
            .collect()
    }

    fn fixture(
        stack: Stack,
    ) -> (
        Shape,
        AttentionPublic,
        FeedForwardPublic,
        AccuracyPublic,
        Vec<i16>,
    ) {
        let f = parse(include_str!("r13_vectors/block_fixture_t32.tsv"));
        let mut sh = Shape::new(
            "R13 trace fixture",
            "r13-trace-fixture",
            32,
            16,
            32,
            4,
            4,
            2,
            8,
            8,
            9,
            7,
            None,
            None,
            None,
            None,
        )
        .unwrap();
        // This test exercises execution only, not a registered proof profile.
        sh.norm_tn = 10;
        sh.norm_cn_a = 200;
        sh.norm_cn_m = 180;
        sh.norm_ceps = 123;
        sh.sh_qkv = 8;
        sh.sh_s = 6;
        sh.sh_o = 9;
        sh.sh_ao = 7;
        sh.sh_g = 8;
        sh.sh_h = 14;
        sh.sh_z = 6;
        let i8s = |key: &str| {
            f[key]
                .iter()
                .map(|&v| i8::try_from(v).unwrap())
                .collect::<Vec<_>>()
        };
        let transpose = |key: &str, rows: usize, cols: usize| {
            let w = &f[key];
            (0..cols)
                .flat_map(|j| (0..rows).map(move |i| i8::try_from(w[i * cols + j]).unwrap()))
                .collect::<Vec<_>>()
        };
        let public = AttentionPublic::new_shaped(
            &sh,
            &transpose("w_q", 16, 16),
            &transpose("w_k", 16, 8),
            &transpose("w_v", 16, 8),
            &transpose("w_o", 16, 16),
            &i8s("gamma"),
            &f["cos"],
            &f["sin"],
            &f["exp"],
        )
        .unwrap();
        let ff = FeedForwardPublic::new_shaped(
            &sh,
            &i8s("gamma"),
            &i8s("w_g"),
            &i8s("w_u"),
            &i8s("w_d"),
            &[0; 256],
        )
        .unwrap();
        let ms = |key: &str| {
            f[key]
                .iter()
                .map(|&v| u16::try_from(v).unwrap())
                .collect::<Vec<_>>()
        };
        let groups: Vec<Group> = f["members"]
            .chunks_exact(2)
            .map(|v| Group {
                e_in: v[0] as i32,
                e_out: v[1] as i32,
            })
            .collect();
        let tables = groups
            .iter()
            .map(|g| {
                crate::private_block::accuracy_tables::silu_table(g.e_in, g.e_out, 12).unwrap()
            })
            .collect();
        let accuracy = AccuracyPublic::new(
            stack,
            Geometry {
                width: 16,
                query_width: 16,
                kv_width: 8,
                hidden: 32,
            },
            BaseShifts {
                norm_tn: 10,
                qkv: 8,
                score: 6,
                pv: 9,
                ao: 7,
                gate: 8,
                up: 0,
                product: 14,
                down: 6,
            },
            (-3, -11),
            Multipliers {
                q: ms("m_q"),
                k: ms("m_k"),
                v: ms("m_v"),
                o: ms("m_o"),
                g: ms("m_g"),
                u: ms("m_u"),
                d: ms("m_d"),
            },
            groups,
            f["groups"].iter().map(|&v| v as usize).collect(),
            tables,
        )
        .unwrap();
        let input = f["input"]
            .iter()
            .map(|&v| i16::try_from(v).unwrap())
            .collect();
        (sh, public, ff, accuracy, input)
    }

    #[test]
    fn both_export_stacks_match_the_independent_full_block_oracle() {
        for (stack, expected) in [
            (
                Stack::Low,
                include_str!("r13_vectors/block_trace_low_t32.tsv"),
            ),
            (
                Stack::LowH24,
                include_str!("r13_vectors/block_trace_low_h24_t32.tsv"),
            ),
        ] {
            let (sh, public, ff, accuracy, input) = fixture(stack);
            let trace = build(&sh, &public, &ff, &accuracy, &input).unwrap();
            let expected = parse(expected);
            let g = Geom::new(&sh);
            let sites: [(&str, Dom, &[i64]); 18] = [
                ("y", Dom::D, &trace.na.words),
                ("q", Dom::Q, &trace.q.words),
                ("k", Dom::Kv, &trace.k.words),
                ("v", Dom::Kv, &trace.v.words),
                ("qr", Dom::Q, &trace.qr.words),
                ("kr", Dom::Kv, &trace.kr.words),
                ("s", Dom::S, &trace.s.words),
                ("p", Dom::S, &trace.p),
                ("o8", Dom::Q, &trace.o.words),
                ("ao", Dom::D, &trace.ao.words),
                ("x1", Dom::D, &trace.x1),
                ("nm", Dom::D, &trace.nm.words),
                ("gate", Dom::F, &trace.gate.words),
                ("a_scaled", Dom::F, &trace.a_scaled),
                ("u16", Dom::F, &trace.up.words),
                ("h16", Dom::F, &trace.h.words),
                ("z16", Dom::D, &trace.z.words),
                ("x2", Dom::D, &trace.x2),
            ];
            for (name, domain, actual) in sites {
                let dense: Vec<_> = g.support(domain).into_iter().map(|i| actual[i]).collect();
                assert_eq!(dense, expected[name], "{stack:?}: {name}");
            }
            assert!(trace
                .na
                .rho
                .iter()
                .chain(&trace.na.sigma)
                .chain(&trace.nm.rho)
                .chain(&trace.nm.sigma)
                .all(|&r| (0..1 << 24).contains(&r)));
            // This oracle fixture has Q in [-70,88]. Its widened norm and
            // up words exercise values outside int8; Q/QR endpoints have
            // their own signed16 boundary/rotation controls below.
            assert!(trace.na.words.iter().any(|v| v.abs() > 127));
            assert!(trace.up.words.iter().any(|v| v.abs() > 127));
            assert!(trace.up.rho.iter().any(|&r| r != 0));
        }
    }

    #[test]
    fn future_scores_are_range_checked_before_the_causal_mask() {
        let (sh, public, ff, accuracy, input) = fixture(Stack::LowH24);
        // This out-of-range score is a future position of the first row.
        // It must enter the quantizer before the causal mask is applied.
        let mut acc = vec![0; sh.size(Dom::S)];
        acc[Geom::new(&sh).six(0, 0, 31)] = 128 << accuracy.precision().score;
        assert!(quantized(
            acc,
            &Geom::new(&sh).support(Dom::S),
            accuracy.precision().score,
            &[1],
            1,
            -127,
            127,
            "score"
        )
        .unwrap_err()
        .contains("score"));
        // The honest fixture remains accepted by the complete executor.
        build(&sh, &public, &ff, &accuracy, &input).unwrap();
    }

    #[test]
    fn amended_int16_endpoints_and_rope_accumulators_do_not_wrap() {
        let q = quantized(vec![-65536, 65534], &[0, 1], 1, &[1], 1, -32768, 32767, "Q").unwrap();
        assert_eq!(q.words, vec![-32768, 32767]);
        for bad in [-65538, 65536] {
            assert!(quantized(vec![bad], &[0], 1, &[1], 1, -32768, 32767, "Q").is_err());
        }
        let (mut sh, mut public, _, _, _) = fixture(Stack::LowH24);
        sh.norm_ceps = 1;
        let g = Geom::new(&sh);
        let mut x = vec![0; g.len(Dom::D)];
        x[0] = -1;
        let n = normalized(&g, &x, &vec![1; g.d_pad], 2, 1 << 17).unwrap();
        assert_eq!(n.words[0], -32768);
        let mut q = vec![0; g.len(Dom::Q)];
        q[g.qix(1, 0, 0)] = -32768;
        public.rope_cos[g.half] = 128;
        public.rope_sin[g.half] = 0;
        let rotated = rotate(
            &g,
            &q,
            g.h_pad,
            g.q_pad,
            g.len(Dom::Q),
            &public.rope_cos,
            &public.rope_sin,
        );
        let accepted = quantized(
            rotated,
            &g.support(Dom::Q),
            SH_ROPE,
            &[1],
            1,
            -32768,
            32767,
            "QR",
        )
        .unwrap();
        assert_eq!(accepted.words[g.qix(1, 0, 0)], -32768);
        public.rope_cos[g.half] = -128;
        let rotated = rotate(
            &g,
            &q,
            g.h_pad,
            g.q_pad,
            g.len(Dom::Q),
            &public.rope_cos,
            &public.rope_sin,
        );
        assert!(quantized(
            rotated,
            &g.support(Dom::Q),
            SH_ROPE,
            &[1],
            1,
            -32768,
            32767,
            "QR"
        )
        .is_err());
    }

    #[test]
    fn new_execution_rejects_public_negative_128_weights() {
        let (sh, mut public, ff, accuracy, input) = fixture(Stack::LowH24);
        public.wq[0] = -128;
        assert!(build(&sh, &public, &ff, &accuracy, &input)
            .err()
            .unwrap()
            .contains("symmetric int8"));
    }
    #[test]
    fn both_accuracy_stacks_assign_all_words_to_distinct_native_planes_and_recover_the_output() {
        use crate::private_block::accuracy_layout::{AccuracyIds,Limbs as L};
        for stack in [Stack::Low,Stack::LowH24] {
            let (sh,public,ff,data,input)=fixture(stack);
            let trace=build(&sh,&public,&ff,&data,&input).unwrap();
            let expected=trace.x2.clone();
            let mut witness=assign(&sh,&public,&data,trace).unwrap();
            let ids=AccuracyIds::new(stack,false,sh.limbs_sigma_s()).unwrap();
            let g=Geom::new(&sh);
            for (old,role,bias) in [(A_X,L::X,32768),(A_Y,L::Y,32768),(A_YM,L::Ym,32768),(A_Q8,L::Q,32768),
                (A_K8,L::K,32768),(A_V8,L::V,32768),(A_QR8,L::Qr,32768),(A_KR8,L::Kr,32768),
                (A_O8,L::O,32768),(A_AO,L::Ao,32768),(A_X1,L::X1,32768),(A_U16,L::Up,32768),
                (A_H16,L::H,1i64<<(data.precision().product_bits-1)),(A_Z16,L::Z,32768),(A_X2,L::X2,32768)] {
                for i in g.support(ids.doms[ids.map[old]]) {
                    let reconstructed:i64=(0..ids.count(role)).map(|k|witness.planes[ids.limb(role,k)][i]<<(8*k)).sum();
                    assert_eq!(witness.planes[ids.map[old]][i]+bias,reconstructed,"{role:?}[{i}]");
                }
            }
            for dom in [Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F] {
                let lookups=ids.lookups(dom,data.precision(),data.folds().gate.shift,sh.wrho_s).unwrap();
                for lk in lookups {for i in 0..g.len(dom) {
                    let value=lk.terms.iter().fold(lk.cst,|s,&(p,c)|s+c*witness.planes[p][i]);
                    assert!((0..256).contains(&value),"{dom:?} position {i}");
                }}
            }
            for &old in &[A_MU8,A_MEXP,A_MACT] {assert!(witness.planes[ids.map[old]].is_empty());}
            assert_eq!(witness.output().unwrap(),expected.iter().map(|&v|v as i16).collect::<Vec<_>>());
            assert_ne!(ids.map[A_X2],A_X2);
            witness.planes[A_X2].fill(12345);
            assert_eq!(witness.output().unwrap(),expected.iter().map(|&v|v as i16).collect::<Vec<_>>());
        }
    }

    #[test]
    fn dictionary_assignment_uses_fp12_on_every_slot_including_repeated_padding_zeros() {
        use crate::private_block::accuracy_layout::{AccuracyIds,Limbs as L};
        for stack in [Stack::Low,Stack::LowH24] {
            let (mut sh,mut public,ff,data,input)=fixture(stack);
            sh.dd_cap=32;
            public.exp=vec![512;256];
            let trace=build(&sh,&public,&ff,&data,&input).unwrap();
            let expected=trace.p.clone();let totals=trace.sum.clone();
            let witness=assign(&sh,&public,&data,trace).unwrap();
            let ids=AccuracyIds::new(stack,true,sh.limbs_sigma_s()).unwrap();
            let column=public.dd_e_column(sh.dd_cap).unwrap();let g=Geom::new(&sh);
            assert!(column.iter().filter(|&&v|v==0).count()>1);
            for h in 0..g.hq {for t in 0..g.t {
                let hs=g.slot(h);let base=(hs*g.t_pad+t)*sh.dd_cap;let total=totals[g.htix(hs,t)];
                assert_eq!(witness.planes[ids.mdd][base..base+sh.dd_cap].iter().sum::<i64>(),g.t_pad as i64);
                for (k,&e) in column.iter().enumerate() {
                    let q=witness.planes[ids.pdict][base+k];
                    let read=|role| (0..ids.count(role)).map(|j|witness.planes[ids.limb(role,j)][base+k]<<(8*j)).sum::<i64>();
                    let (rho,sigma)=(read(L::Sr),read(L::Sg));
                    assert_eq!(q,read(L::P));assert_eq!(q*total+rho,e<<12);assert_eq!(rho+sigma+1,total);
                    if e==0 && k>0 {assert_eq!(witness.planes[ids.mdd][base+k],0);}
                }
                for j in 0..g.t {assert_eq!(witness.planes[ids.map[A_P]][g.six(hs,t,j)],expected[g.six(hs,t,j)]);}
            }}
        }
    }

    // ---- [A16] the chunked and per-row forms refuse exactly as the loops they replace ----

    /// [A16] `quantized_with` over a hand-made plan whose chunks are visited out of support
    /// order: equal words, and on refusals of two different kinds in two chunks, the one
    /// first in SUPPORT order (`quantized`'s), whichever chunk comes first
    #[test]
    fn a16_quantized_over_chunks_refuses_with_the_first_refusal_in_support_order() {
        // 4 chunks of 4; the support visits chunk 3 first, then 0, then 1 and 2
        let support: Vec<usize> = vec![12, 13, 14, 0, 1, 3, 5, 6, 9, 10];
        let mut groups = vec![Vec::new(); 4];
        for &i in &support {
            groups[i / 4].push(i);
        }
        let plan = ChunkPlan { stride: 4, groups, count: support.len() };
        let mult: Vec<u64> = vec![3, 5, 7, 11];
        let acc: Vec<i64> = (0..16).map(|i| (i as i64 - 8) * 100).collect();
        let a = quantized(acc.clone(), &support, 1, &mult, 4, -32768, 32767, "T").unwrap();
        let b = quantized_with(acc.clone(), &support, Some(&plan), 1, &mult, 4, -32768, 32767, "T").unwrap();
        assert_eq!((a.words, a.rho), (b.words, b.rho));
        // the multiplier stride 1 and the chunk-stride form of `mult[i % stride]`
        let a = quantized(acc.clone(), &support, 1, &[3], 1, -32768, 32767, "T").unwrap();
        let b = quantized_with(acc.clone(), &support, Some(&plan), 1, &[3], 1, -32768, 32767, "T").unwrap();
        assert_eq!((a.words, a.rho), (b.words, b.rho));
        let m2: Vec<u64> = vec![3, 5];
        let a = quantized(acc.clone(), &support, 1, &m2, 2, -32768, 32767, "T").unwrap();
        let b = quantized_with(acc.clone(), &support, Some(&plan), 1, &m2, 2, -32768, 32767, "T").unwrap();
        assert_eq!((a.words, a.rho), (b.words, b.rho));
        // a class refusal at 13 (chunk 3) and an int64 refusal at 1 (chunk 0): 13 is first
        // in this support, 1 is first in chunk order
        let mut bad = acc.clone();
        bad[13] = 1 << 40;
        bad[1] = i64::MAX;
        let want = quantized(bad.clone(), &support, 1, &mult, 4, -32768, 32767, "T").unwrap_err();
        assert!(want.contains("refusal: T"), "{want}");
        assert_eq!(quantized_with(bad.clone(), &support, Some(&plan), 1, &mult, 4, -32768, 32767, "T").unwrap_err(), want);
        // the other support order: the int64 refusal first
        let support2: Vec<usize> = vec![0, 1, 3, 5, 6, 9, 10, 12, 13, 14];
        let mut groups = vec![Vec::new(); 4];
        for &i in &support2 {
            groups[i / 4].push(i);
        }
        let plan2 = ChunkPlan { stride: 4, groups, count: support2.len() };
        let want = quantized(bad.clone(), &support2, 1, &mult, 4, -32768, 32767, "T").unwrap_err();
        assert!(want.contains("int64"), "{want}");
        assert_eq!(quantized_with(bad, &support2, Some(&plan2), 1, &mult, 4, -32768, 32767, "T").unwrap_err(), want);
    }

    /// [A16] `normalized_par` against `normalized`: equal planes on the fixture (both the
    /// i64 and, with a huge multiplier, the i128 form), and with two bad rows of different
    /// kinds, the first row's refusal in either order
    #[test]
    fn a16_normalized_by_rows_equals_normalized_and_refuses_with_the_first_rows_refusal() {
        let (sh, public, _, _, input) = fixture(Stack::LowH24);
        let g = Geom::new(&sh);
        let mut x = vec![0; g.len(Dom::D)];
        for (&i, &w) in g.support(Dom::D).iter().zip(&input) {
            x[i] = w as i64;
        }
        let same = |x: &[i64], gamma: &[i8], tn: u32, cn: i64, what: &str| {
            match (normalized(&g, x, gamma, tn, cn), normalized_par(&g, x, gamma, tn, cn)) {
                (Ok(a), Ok(b)) => assert!(a.words == b.words && a.d == b.d && a.dsq == b.dsq && a.a1 == b.a1 && a.a2 == b.a2 && a.rho == b.rho && a.sigma == b.sigma, "{what}: a plane differs"),
                (Err(a), Err(b)) => assert_eq!(a, b, "{what}: the refusals differ"),
                (a, b) => panic!("{what}: {:?} against {:?}", a.err(), b.err()),
            }
        };
        same(&x, &public.gamma_a, 10, 200, "the fixture");
        same(&x, &public.gamma_a, 10, 1 << 55, "a multiplier that needs i128");
        // row 1: a denominator past the isqrt window; row 3: a quotient past int16
        let gamma = vec![1i8; g.d_pad];
        let row = |x: &mut Vec<i64>, t: usize, v: &[i64]| {
            for (i, &w) in v.iter().enumerate() {
                x[t * g.d_pad + i] = w;
            }
        };
        let mut a = vec![1; g.len(Dom::D)];
        row(&mut a, 1, &vec![1 << 23; g.d]);
        row(&mut a, 3, &[1000]);
        for i in 1..g.d {
            a[3 * g.d_pad + i] = 0;
        }
        let r = normalized(&g, &a, &gamma, 2, 1 << 17).err().expect("row 1 refuses");
        assert!(r.contains("norm denominator"), "{r}");
        same(&a, &gamma, 2, 1 << 17, "denominator first");
        let mut b = vec![1; g.len(Dom::D)];
        row(&mut b, 3, &vec![1 << 23; g.d]);
        row(&mut b, 1, &[1000]);
        for i in 1..g.d {
            b[g.d_pad + i] = 0;
        }
        let r = normalized(&g, &b, &gamma, 2, 1 << 17).err().expect("row 1 refuses");
        assert!(r.contains("norm quotient/remainder"), "{r}");
        same(&b, &gamma, 2, 1 << 17, "quotient first");
    }

    /// [A16] `residual_with` over a plan equals `residual`, refusal included
    #[test]
    fn a16_residual_over_chunks_equals_residual() {
        let (sh, ..) = fixture(Stack::LowH24);
        let g = Geom::new(&sh);
        let support = g.support(Dom::D);
        let mut groups = vec![Vec::new(); g.len(Dom::D) / g.d_pad];
        for &i in &support {
            groups[i / g.d_pad].push(i);
        }
        let plan = ChunkPlan { stride: g.d_pad, groups, count: support.len() };
        let x: Vec<i64> = (0..g.len(Dom::D)).map(|i| (i as i64 * 97) % 30000 - 15000).collect();
        let y: Vec<i64> = (0..g.len(Dom::D)).map(|i| (i as i64 * 31) % 20000 - 10000).collect();
        assert_eq!(residual(&g, &x, &y, "r").unwrap(), residual_with(&g, &x, &y, "r", Some(&plan)).unwrap());
        let mut y2 = y.clone();
        y2[support[support.len() - 1]] = 40000;
        assert_eq!(residual(&g, &x, &y2, "r").unwrap_err(), residual_with(&g, &x, &y2, "r", Some(&plan)).unwrap_err());
    }

    /// [A16] `HL_A16`'s words
    #[test]
    fn a16_the_switch_parses_its_words() {
        use super::super::{a16_parse, A16_ALL, A16_CACHE, A16_DEFAULT, A16_KERNELS, A16_NORM, A16_ONCE};
        assert_eq!(a16_parse(Some("kernels")), A16_KERNELS);
        assert_eq!(a16_parse(None), A16_DEFAULT);
        assert_eq!(a16_parse(Some("")), A16_DEFAULT);
        assert_eq!(a16_parse(Some("auto")), A16_DEFAULT);
        assert_eq!(a16_parse(Some("0")), 0);
        assert_eq!(a16_parse(Some("old")), 0);
        assert_eq!(a16_parse(Some("all")), A16_ALL);
        assert_eq!(a16_parse(Some("cache,norm")), A16_CACHE | A16_NORM);
        assert_eq!(a16_parse(Some("once+cache")), A16_ONCE | A16_CACHE);
        assert_eq!(a16_parse(Some("cache,bogus")), A16_DEFAULT);
    }

}

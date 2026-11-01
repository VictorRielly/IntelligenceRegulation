//! Research prototype (2026-11-01): a streamed LogUp-GKR fractional-sumcheck
//! prover and verifier for W16-style tagged range lookups, over zkp-core's
//! Goldilocks / Fp2 field, measured against the committed-helper path on the
//! same leaves. NOT a production prover and NOT zero-knowledge: no masks,
//! no commitment to the leaves (the verifier's leaf check is an oracle that
//! stands in for the claim on the committed A planes). See README.md.
//!
//! Tree. One fractional tree of 2^n leaves (p, q). Leaf x is
//!   * a query (1, c_w - v) with c_w = alpha - gamma*w, v in [0, 2^w), unless
//!   * x lies in the last S leaves of its half (the "special" region), which
//!     hold the table (-m, c_w - t) for every used width w and t in [0, 2^w),
//!     pads (0, c_0 - 0) (P-3: repeat an entry with multiplicity 0) and ONE
//!     blinding leaf per half: (s*r1, r1) and (-s*r2, r2), which cancel.
//! Layer k has 2^k nodes; node i combines children 2i, 2i+1:
//!   p = p0*q1 + p1*q0, q = q0*q1.  The root must be (0, nonzero).
//!
//! Streaming. Leaves stay as u32 values (the A planes' stand-in). Layer n-1
//! is never stored: it is recomputed from leaves. Layers 1..=n-2 are stored
//! bottom-up (16 B/leaf in total) and each is freed when the top-down pass has
//! used it. The leaf-layer sumcheck keeps p == 1 implicit outside the special
//! region and uses the base-field structure of the leaves in its first two
//! rounds.
//!
//! MLE convention: index bit b <-> coordinate b (LSB first). Child bit = bit 0.

use rayon::prelude::*;
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicUsize, Ordering::Relaxed};
use std::time::Instant;
use zkp_core::field::{batch_inverse2, batch_inverse2_checked, Fp, Fp2, P};
use zkp_core::ntt::NttTables;
use zkp_core::pcs::{commit_zk_owned, PcsParams, ZkOpts};
use zkp_core::rng::ZkRng;
use zkp_core::transcript::Transcript;

// ===================== heap accounting =====================================
struct Counting;
static CUR: AtomicUsize = AtomicUsize::new(0);
static PEAK: AtomicUsize = AtomicUsize::new(0);
fn bump(s: usize) {
    let c = CUR.fetch_add(s, Relaxed) + s;
    PEAK.fetch_max(c, Relaxed);
}
unsafe impl GlobalAlloc for Counting {
    unsafe fn alloc(&self, l: Layout) -> *mut u8 {
        let p = System.alloc(l);
        if !p.is_null() {
            bump(l.size());
        }
        p
    }
    unsafe fn alloc_zeroed(&self, l: Layout) -> *mut u8 {
        let p = System.alloc_zeroed(l);
        if !p.is_null() {
            bump(l.size());
        }
        p
    }
    unsafe fn dealloc(&self, p: *mut u8, l: Layout) {
        System.dealloc(p, l);
        CUR.fetch_sub(l.size(), Relaxed);
    }
    unsafe fn realloc(&self, p: *mut u8, l: Layout, n: usize) -> *mut u8 {
        let q = System.realloc(p, l, n);
        if !q.is_null() {
            if n >= l.size() {
                bump(n - l.size());
            } else {
                CUR.fetch_sub(l.size() - n, Relaxed);
            }
        }
        q
    }
}
#[global_allocator]
static GA: Counting = Counting;
fn heap_now() -> usize {
    CUR.load(Relaxed)
}
fn peak_reset() -> usize {
    let c = CUR.load(Relaxed);
    PEAK.store(c, Relaxed);
    c
}
fn heap_peak() -> usize {
    PEAK.load(Relaxed)
}

/// A zero-initialised vector of plain field data through `alloc_zeroed`
/// (all-zero bytes are `Fp::ZERO`), so large tables get lazily zeroed pages
/// instead of an explicit zeroing pass.
fn zvec<T: Copy>(n: usize) -> Vec<T> {
    if n == 0 {
        return Vec::new();
    }
    let layout = Layout::array::<T>(n).expect("layout");
    unsafe {
        let ptr = std::alloc::alloc_zeroed(layout) as *mut T;
        assert!(!ptr.is_null(), "allocation failed");
        Vec::from_raw_parts(ptr, n, n)
    }
}

// ===================== field helpers =======================================
const ONE: Fp2 = Fp2::ONE;
const ZERO: Fp2 = Fp2::ZERO;
const DOMAIN: &[u8] = b"research/zkp-efficiency/logup-gkr-20261101/w16-proto/v1";
type E4 = [Fp2; 4]; // [P0, P1, Q0, Q1]
type E2 = [Fp2; 2];

/// a signed integer with |v| < p, canonically (no division)
#[inline(always)]
fn fpi(v: i64) -> Fp {
    if v >= 0 {
        Fp::new(v as u64)
    } else {
        Fp(P - v.unsigned_abs())
    }
}
/// eq(z, r) for one coordinate: (1-z)(1-r) + z r
#[inline(always)]
fn eq1(z: Fp2, r: Fp2) -> Fp2 {
    ONE.sub(z).sub(r).add(z.mul(r).double())
}
fn eq_pt(z: &[Fp2], r: &[Fp2]) -> Fp2 {
    assert_eq!(z.len(), r.len());
    z.iter().zip(r).fold(ONE, |a, (&x, &y)| a.mul(eq1(x, y)))
}
/// eq(z, i) for every i in {0,1}^len, index bit b <-> z[b]; one product per entry
fn eq_tab(z: &[Fp2]) -> Vec<Fp2> {
    let mut out = vec![ZERO; 1usize << z.len()];
    out[0] = ONE;
    let mut len = 1usize;
    for &zi in z {
        for i in 0..len {
            let e = out[i];
            let hi = e.mul(zi);
            out[i + len] = hi;
            out[i] = e.sub(hi);
        }
        len <<= 1;
    }
    out
}
#[inline(always)]
fn combine(a: E2, b: E2) -> E2 {
    [a[0].mul(b[1]).add(b[0].mul(a[1])), a[1].mul(b[1])]
}
#[inline(always)]
fn fold(a: Fp2, b: Fp2, r: Fp2) -> Fp2 {
    a.add(r.mul(b.sub(a)))
}
#[inline(always)]
fn fold4(a: &E4, b: &E4, r: Fp2) -> E4 {
    [fold(a[0], b[0], r), fold(a[1], b[1], r), fold(a[2], b[2], r), fold(a[3], b[3], r)]
}
/// g = P0 Q1 + P1 Q0 + lam Q0 Q1 at a pair (x at X=0, y at X=1): (g(0), [X^2] g)
#[inline(always)]
fn gpoly(x: &E4, y: &E4, lam: Fp2) -> (Fp2, Fp2) {
    let g0 = x[0].mul(x[3]).add(x[2].mul(x[1].add(lam.mul(x[3]))));
    let (d0, d1, d2, d3) = (y[0].sub(x[0]), y[1].sub(x[1]), y[2].sub(x[2]), y[3].sub(x[3]));
    let g2 = d0.mul(d3).add(d2.mul(d1.add(lam.mul(d3))));
    (g0, g2)
}
#[inline(always)]
fn gval(e: &E4, lam: Fp2) -> Fp2 {
    e[0].mul(e[3]).add(e[1].mul(e[2])).add(lam.mul(e[2]).mul(e[3]))
}

// ===================== configuration and counters ==========================
#[derive(Clone, Copy)]
struct Cfg {
    /// low bits of the split eq table (block = 2^lo_max pairs)
    lo_max: usize,
    /// pairs from which a pass runs on rayon
    par_min: usize,
    /// use the base-field / p==1 fast paths
    fast: bool,
}
impl Default for Cfg {
    fn default() -> Cfg {
        Cfg { lo_max: 10, par_min: 1 << 13, fast: true }
    }
}

/// Counted work: Fp2 x Fp2 products (5 base products each in zkp-core), extra
/// base-field products (Fp2 x Fp counts 2), and main-memory bytes of the big
/// arrays (sources, stored layers, sumcheck tables; the split eq tables are
/// cache-resident and not counted as traffic).
#[derive(Default, Clone, Copy, Debug)]
struct Cost {
    fp2: u64,
    base: u64,
    rd: u64,
    wr: u64,
}
impl Cost {
    fn add(&mut self, fp2: u64, base: u64, rd: u64, wr: u64) {
        self.fp2 += fp2;
        self.base += base;
        self.rd += rd;
        self.wr += wr;
    }
    fn fp2_equiv(&self) -> f64 {
        self.fp2 as f64 + self.base as f64 / 5.0
    }
}

// ===================== witness =============================================
#[derive(Clone, Copy, Debug)]
enum Sp {
    Tab { tag: u8, t: u32, m: u64 },
    Blind { x: Fp2, y: Fp2 },
}

#[derive(Clone)]
struct Witness {
    n: usize,
    s_log: usize,
    seg_log: usize,
    widths: Vec<u32>,
    vals: Vec<u32>,
    seg_tag: Vec<u8>,
    sp: Vec<Sp>,
    n_table: usize,
}

struct Xs(u64);
impl Xs {
    fn next(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        x.wrapping_mul(0x2545F4914F6CDD1D)
    }
}

impl Witness {
    fn half(&self) -> usize {
        1usize << (self.n - 1)
    }
    fn s(&self) -> usize {
        1usize << self.s_log
    }
    fn special(&self, x: usize) -> bool {
        (x & (self.half() - 1)) >= self.half() - self.s()
    }
    fn sidx(&self, x: usize) -> usize {
        (x >> (self.n - 1)) * self.s() + (x & (self.half() - 1)) - (self.half() - self.s())
    }
    fn tag(&self, x: usize) -> usize {
        self.seg_tag[x >> self.seg_log] as usize
    }
    fn queries(&self) -> usize {
        (1usize << self.n) - 2 * self.s()
    }
    /// recompute every table multiplicity from the current query values
    fn recount(&mut self) {
        let mut counts: Vec<Vec<u64>> = self.widths.iter().map(|&w| vec![0u64; 1usize << w]).collect();
        for x in 0..(1usize << self.n) {
            if !self.special(x) {
                let t = self.tag(x);
                let v = self.vals[x] as usize;
                if v < counts[t].len() {
                    counts[t][v] += 1;
                }
            }
        }
        for e in self.sp.iter_mut() {
            if let Sp::Tab { tag, t, m } = e {
                *m = if *m == 0 && *tag == 0 && *t == 0 { 0 } else { counts[*tag as usize][*t as usize] };
            }
        }
        // the first entry of (tag 0, value 0) carries the count; its pads stay at 0
        let mut seen = false;
        for e in self.sp.iter_mut() {
            if let Sp::Tab { tag: 0, t: 0, m } = e {
                if !seen {
                    *m = counts[0][0];
                    seen = true;
                } else {
                    *m = 0;
                }
            }
        }
    }
}

/// W16-like synthetic witness: query segments of 2^seg_log leaves with a
/// width tag drawn by weight, values uniform in [0, 2^w); the table and two
/// blinding leaves in the special regions.
fn gen_witness(n: usize, s_log: usize, seg_log: usize, widths: &[u32], weights: &[u32], seed: u64) -> Witness {
    assert!(n >= 4 && widths.len() == weights.len() && widths.len() <= 255);
    assert!(widths.iter().all(|&w| (1..=30).contains(&w)), "values must stay below 2^31");
    let nn = 1usize << n;
    let half = nn / 2;
    let s = 1usize << s_log;
    assert!(s >= 2 && s <= half / 2, "special region must be at most a quarter of the tree");
    assert!(seg_log <= n - 1);
    let table_len: usize = widths.iter().map(|&w| 1usize << w).sum();
    assert!(table_len <= 2 * (s - 1), "table ({table_len}) does not fit the special regions ({})", 2 * (s - 1));
    let mut rng = Xs(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1);
    let wsum: u32 = weights.iter().sum();
    let nseg = nn >> seg_log;
    let seg_tag: Vec<u8> = (0..nseg)
        .map(|_| {
            let mut u = (rng.next() % wsum as u64) as u32;
            let mut t = 0usize;
            while u >= weights[t] {
                u -= weights[t];
                t += 1;
            }
            t as u8
        })
        .collect();
    let mut w = Witness { n, s_log, seg_log, widths: widths.to_vec(), vals: vec![0u32; nn], seg_tag, sp: Vec::new(), n_table: table_len };
    for x in 0..nn {
        if !w.special(x) {
            let wd = widths[w.tag(x)];
            w.vals[x] = (rng.next() & ((1u64 << wd) - 1)) as u32;
        }
    }
    // table list, then pads repeating (tag 0, value 0) with multiplicity 0
    let mut list: Vec<Sp> = Vec::with_capacity(2 * s);
    for (tag, &wd) in widths.iter().enumerate() {
        for t in 0..(1u32 << wd) {
            list.push(Sp::Tab { tag: tag as u8, t, m: 1 }); // m filled by recount
        }
    }
    let mut zr = ZkRng::new(seed, b"logup-gkr-proto/blinding");
    let sbl = zr.fp2();
    let nz = |zr: &mut ZkRng| loop {
        let r = zr.fp2();
        if !r.is_zero() {
            return r;
        }
    };
    let (r1, r2) = (nz(&mut zr), nz(&mut zr));
    let mut sp = Vec::with_capacity(2 * s);
    let mut it = list.into_iter();
    for h in 0..2 {
        for _ in 0..s - 1 {
            sp.push(it.next().unwrap_or(Sp::Tab { tag: 0, t: 0, m: 0 }));
        }
        sp.push(if h == 0 { Sp::Blind { x: sbl.mul(r1), y: r1 } } else { Sp::Blind { x: sbl.neg().mul(r2), y: r2 } });
    }
    w.sp = sp;
    w.recount();
    w
}

// ===================== the challenge-dependent leaf view ====================
struct Ctx<'a> {
    w: &'a Witness,
    n: usize,
    hmask: usize,
    sp_start: usize,
    s: usize,
    seg_log: usize,
    c: Vec<Fp2>,
    c2: Vec<Fp2>,
    two_c: Vec<Fp2>,
    sp_pq: Vec<E2>,
}
impl<'a> Ctx<'a> {
    fn new(w: &'a Witness, alpha: Fp2, gamma: Fp2) -> Ctx<'a> {
        let c: Vec<Fp2> = w.widths.iter().map(|&wd| alpha.sub(gamma.mul_base(Fp::new(wd as u64)))).collect();
        let c2 = c.iter().map(|x| x.mul(*x)).collect();
        let two_c = c.iter().map(|x| x.double()).collect();
        let sp_pq = w
            .sp
            .iter()
            .map(|e| match *e {
                Sp::Tab { tag, t, m } => [Fp2::from_base(Fp::new(m)).neg(), c[tag as usize].sub_base(Fp::new(t as u64))],
                Sp::Blind { x, y } => [x, y],
            })
            .collect();
        Ctx { w, n: w.n, hmask: w.half() - 1, sp_start: w.half() - w.s(), s: w.s(), seg_log: w.seg_log, c, c2, two_c, sp_pq }
    }
    #[inline(always)]
    fn special(&self, x: usize) -> bool {
        (x & self.hmask) >= self.sp_start
    }
    #[inline(always)]
    fn sidx(&self, x: usize) -> usize {
        (x >> (self.n - 1)) * self.s + (x & self.hmask) - self.sp_start
    }
    #[inline(always)]
    fn tag(&self, x: usize) -> usize {
        self.w.seg_tag[x >> self.seg_log] as usize
    }
    #[inline(always)]
    fn leaf(&self, x: usize) -> E2 {
        if self.special(x) {
            self.sp_pq[self.sidx(x)]
        } else {
            [ONE, self.c[self.tag(x)].sub_base(Fp::new(self.w.vals[x] as u64))]
        }
    }
    /// layer n-1 node i (children leaves 2i, 2i+1), never stored
    #[inline(always)]
    fn node1(&self, i: usize) -> E2 {
        let x = 2 * i;
        if !self.special(x) {
            let t = self.tag(x);
            let (a, b) = (self.w.vals[x] as u64, self.w.vals[x + 1] as u64);
            let s = Fp::new(a + b);
            [self.two_c[t].sub_base(s), self.c2[t].sub(self.c[t].mul_base(s)).add_base(Fp::new(a * b))]
        } else {
            combine(self.leaf(x), self.leaf(x + 1))
        }
    }
    /// entry i of the leaf-layer sumcheck tables: leaves 2i, 2i+1
    #[inline(always)]
    fn leaf_entry(&self, i: usize) -> E4 {
        let (a, b) = (self.leaf(2 * i), self.leaf(2 * i + 1));
        [a[0], b[0], a[1], b[1]]
    }
    /// entry i of the layer-(n-2) sumcheck tables: layer n-1 nodes 2i, 2i+1
    #[inline(always)]
    fn virt_entry(&self, i: usize) -> E4 {
        let (a, b) = (self.node1(2 * i), self.node1(2 * i + 1));
        [a[0], b[0], a[1], b[1]]
    }
    /// leaves [x0, x0+len) (aligned power of two): one query segment and no special leaf?
    fn pure(&self, x0: usize, len: usize) -> Option<usize> {
        if len > (1usize << self.seg_log) || len > self.hmask + 1 || self.special(x0 + len - 1) {
            None
        } else {
            Some(self.tag(x0))
        }
    }
}

// ===================== proof objects and the transcript =====================
#[derive(Clone, PartialEq, Debug)]
struct LayerProof {
    rounds: Vec<E4>, // cubic coefficients c0..c3 of each round polynomial
    finals: E4,      // P0, P1, Q0, Q1 at the layer's random point
}
#[derive(Clone, PartialEq, Debug)]
struct Proof {
    layer1: E4, // p1[0], p1[1], q1[0], q1[1]
    layers: Vec<LayerProof>,
}
impl Proof {
    fn bytes(&self) -> usize {
        16 * (4 + self.layers.iter().map(|l| 4 * l.rounds.len() + 4).sum::<usize>())
    }
}

fn transcript_start(w: &Witness) -> Transcript {
    let mut tr = Transcript::new(DOMAIN);
    tr.absorb_u64(b"log-leaves", w.n as u64);
    tr.absorb_u64(b"log-special", w.s_log as u64);
    tr.absorb_u64(b"log-segment", w.seg_log as u64);
    for &wd in &w.widths {
        tr.absorb_u64(b"width", wd as u64);
    }
    // PROTOTYPE GAP: the real protocol absorbs the commitment of A (values,
    // histograms, blinding leaves) here; this prototype commits to nothing.
    tr
}

/// scaled round state: claim = eb * cs
struct RoundState {
    eb: Fp2,
    cs: Fp2,
}
/// From h(0) and [X^2]h of h(X) = sum_j E(j) g(T_j(X)) and the claim, the
/// round's cubic s(X) = eb * eq(z_t, X) * h(X); absorb it, draw r.
fn emit_round(st: &mut RoundState, h0: Fp2, h2: Fp2, zt: Fp2, tr: &mut Transcript) -> (E4, Fp2) {
    let e0 = ONE.sub(zt);
    let e1 = zt.double().sub(ONE);
    let h1 = st.cs.sub(e0.mul(h0)).mul(zt.inv());
    let h1c = h1.sub(h0).sub(h2);
    let c = [
        st.eb.mul(e0.mul(h0)),
        st.eb.mul(e0.mul(h1c).add(e1.mul(h0))),
        st.eb.mul(e0.mul(h2).add(e1.mul(h1c))),
        st.eb.mul(e1.mul(h2)),
    ];
    tr.absorb_fp2(b"gkr-round", &c);
    let r = tr.challenge_fp2();
    st.cs = h0.add(r.mul(h1c.add(r.mul(h2))));
    st.eb = st.eb.mul(eq1(zt, r));
    (c, r)
}

// ===================== kernels ==============================================
struct Split {
    elo: Vec<Fp2>,
    ehi: Vec<Fp2>,
}
fn split(zr: &[Fp2], cfg: &Cfg, cost: &mut Cost) -> Split {
    let lo = zr.len().min(cfg.lo_max);
    let s = Split { elo: eq_tab(&zr[..lo]), ehi: eq_tab(&zr[lo..]) };
    cost.add((s.elo.len() + s.ehi.len()) as u64, 0, 0, 0);
    s
}
fn sum2(v: &[(Fp2, Fp2)]) -> (Fp2, Fp2) {
    v.iter().fold((ZERO, ZERO), |a, b| (a.0.add(b.0), a.1.add(b.1)))
}

/// pass 0 of a layer: the round-0 polynomial from an entry accessor
fn round0<F: Fn(usize) -> E4 + Sync>(zr: &[Fp2], lam: Fp2, cfg: &Cfg, cost: &mut Cost, f: F) -> (Fp2, Fp2, usize) {
    let sp = split(zr, cfg, cost);
    let (bs, nb) = (sp.elo.len(), sp.ehi.len());
    let work = |b: usize| -> (Fp2, Fp2) {
        let (mut a0, mut a2) = (ZERO, ZERO);
        for l in 0..bs {
            let j = b * bs + l;
            let (x, y) = (f(2 * j), f(2 * j + 1));
            let (g0, g2) = gpoly(&x, &y, lam);
            a0 = a0.add(sp.elo[l].mul(g0));
            a2 = a2.add(sp.elo[l].mul(g2));
        }
        (sp.ehi[b].mul(a0), sp.ehi[b].mul(a2))
    };
    let parts: Vec<(Fp2, Fp2)> = if nb > 1 && nb * bs >= cfg.par_min { (0..nb).into_par_iter().map(work).collect() } else { (0..nb).map(work).collect() };
    let (h0, h2) = sum2(&parts);
    cost.add(8 * (nb * bs) as u64 + 2 * nb as u64, 0, 0, 0);
    (h0, h2, nb * bs)
}

/// pass t >= 1 of a dense layer: fold the previous tables with r and compute
/// the round polynomial of the folded tables, writing them (AoS) once
fn fold_round<F: Fn(usize) -> E4 + Sync>(new_len: usize, r: Fp2, zr: &[Fp2], lam: Fp2, cfg: &Cfg, cost: &mut Cost, f: F) -> (Vec<E4>, Fp2, Fp2, usize) {
    assert_eq!(1usize << (zr.len() + 1), new_len);
    let sp = split(zr, cfg, cost);
    let (bs, nb) = (sp.elo.len(), sp.ehi.len());
    let mut out: Vec<E4> = zvec(new_len);
    let work = |b: usize, ch: &mut [E4]| -> (Fp2, Fp2) {
        let (mut a0, mut a2) = (ZERO, ZERO);
        for l in 0..bs {
            let j = b * bs + l;
            let x = fold4(&f(4 * j), &f(4 * j + 1), r);
            let y = fold4(&f(4 * j + 2), &f(4 * j + 3), r);
            ch[2 * l] = x;
            ch[2 * l + 1] = y;
            let (g0, g2) = gpoly(&x, &y, lam);
            a0 = a0.add(sp.elo[l].mul(g0));
            a2 = a2.add(sp.elo[l].mul(g2));
        }
        (sp.ehi[b].mul(a0), sp.ehi[b].mul(a2))
    };
    let parts: Vec<(Fp2, Fp2)> = if nb > 1 && nb * bs >= cfg.par_min {
        out.par_chunks_mut(2 * bs).enumerate().map(|(b, ch)| work(b, ch)).collect()
    } else {
        out.chunks_mut(2 * bs).enumerate().map(|(b, ch)| work(b, ch)).collect()
    };
    let (h0, h2) = sum2(&parts);
    cost.add(16 * (nb * bs) as u64 + 2 * nb as u64, 0, 0, 0);
    (out, h0, h2, nb * bs)
}

/// The leaf layer's tables after a fold: (Q0, Q1) dense, (P0, P1) == 1 except
/// on the last `sp` entries of each half
struct Sparse {
    q: Vec<E2>,
    sp: usize,
    ps: Vec<E2>,
}
#[inline(always)]
fn is_sp(i: usize, len: usize, sp: usize) -> bool {
    let h = len / 2;
    (i & (h - 1)) >= h - sp
}
#[inline(always)]
fn sidx(i: usize, len: usize, sp: usize) -> usize {
    let h = len / 2;
    (i / h) * sp + (i & (h - 1)) - (h - sp)
}
impl Sparse {
    #[inline(always)]
    fn entry(&self, i: usize) -> E4 {
        let n = self.q.len();
        let q = self.q[i];
        if is_sp(i, n, self.sp) {
            let s = self.ps[sidx(i, n, self.sp)];
            [s[0], s[1], q[0], q[1]]
        } else {
            [ONE, ONE, q[0], q[1]]
        }
    }
}

struct LeafPart {
    h0: Fp2,
    h2: Fp2,
    sa: Fp2,
    spd: Fp2,
    sd: Fp2,
    pure: bool,
    rec: Vec<(usize, E2)>,
}
impl LeafPart {
    fn slow(h0: Fp2, h2: Fp2, rec: Vec<(usize, E2)>) -> LeafPart {
        LeafPart { h0, h2, sa: ZERO, spd: ZERO, sd: ZERO, pure: false, rec }
    }
}
/// combine block parts: h0 = sum h0 + sum sa + lam sum spd, h2 = sum h2 + lam sum sd
fn leaf_sum(parts: &[LeafPart], lam: Fp2) -> (Fp2, Fp2, usize) {
    let (mut h0, mut h2, mut sa, mut spd, mut sd, mut pure) = (ZERO, ZERO, ZERO, ZERO, ZERO, 0usize);
    for p in parts {
        h0 = h0.add(p.h0);
        h2 = h2.add(p.h2);
        sa = sa.add(p.sa);
        spd = spd.add(p.spd);
        sd = sd.add(p.sd);
        pure += p.pure as usize;
    }
    (h0.add(sa).add(lam.mul(spd)), h2.add(lam.mul(sd)), pure)
}
fn collect_specials(parts: Vec<LeafPart>, sp: usize) -> Vec<E2> {
    let mut ps: Vec<E2> = vec![[ZERO, ZERO]; 2 * sp];
    let mut seen = vec![false; 2 * sp];
    for p in parts {
        for (k, v) in p.rec {
            assert!(!seen[k], "special entry {k} written twice");
            seen[k] = true;
            ps[k] = v;
        }
    }
    assert!(seen.iter().all(|&s| s), "a special entry was not written");
    ps
}
/// a slow-path entry of a new sparse table: record its p values if special,
/// else they must be exactly one
#[inline(always)]
fn note_entry(rec: &mut Vec<(usize, E2)>, e: usize, ent: &E4, len: usize, sp: usize) {
    if is_sp(e, len, sp) {
        rec.push((sidx(e, len, sp), [ent[0], ent[1]]));
    } else {
        assert!(ent[0] == ONE && ent[1] == ONE, "a non-special leaf-layer entry lost p == 1");
    }
}

/// leaf layer, pass 0: round-0 polynomial straight from the u32 leaves
fn leaf_round0(ctx: &Ctx, zr: &[Fp2], lam: Fp2, cfg: &Cfg, cost: &mut Cost) -> (Fp2, Fp2) {
    let sp = split(zr, cfg, cost);
    let (bs, nb) = (sp.elo.len(), sp.ehi.len());
    let k0: Vec<Fp2> = (0..ctx.c.len()).map(|t| ctx.two_c[t].add(lam.mul(ctx.c2[t]))).collect();
    let k1: Vec<Fp2> = (0..ctx.c.len()).map(|t| ONE.add(lam.mul(ctx.c[t]))).collect();
    let work = |b: usize| -> LeafPart {
        let x0 = 4 * b * bs;
        if cfg.fast {
            if let Some(t) = ctx.pure(x0, 4 * bs) {
                let v = &ctx.w.vals[x0..x0 + 4 * bs];
                let (mut se, mut s1, mut s2, mut s3) = (ZERO, ZERO, ZERO, ZERO);
                for l in 0..bs {
                    let e = sp.elo[l];
                    let (a, bb, a2, b2) = (v[4 * l] as u64, v[4 * l + 1] as u64, v[4 * l + 2] as i64, v[4 * l + 3] as i64);
                    se = se.add(e);
                    s1 = s1.add(e.mul_base(Fp::new(a + bb)));
                    s2 = s2.add(e.mul_base(Fp::new(a * bb)));
                    s3 = s3.add(e.mul_base(fpi((a2 - a as i64) * (b2 - bb as i64))));
                }
                let h0 = k0[t].mul(se).sub(k1[t].mul(s1)).add(lam.mul(s2));
                let h2 = lam.mul(s3);
                return LeafPart { h0: sp.ehi[b].mul(h0), h2: sp.ehi[b].mul(h2), sa: ZERO, spd: ZERO, sd: ZERO, pure: true, rec: Vec::new() };
            }
        }
        let (mut a0, mut a2) = (ZERO, ZERO);
        for l in 0..bs {
            let j = b * bs + l;
            let (x, y) = (ctx.leaf_entry(2 * j), ctx.leaf_entry(2 * j + 1));
            let (g0, g2) = gpoly(&x, &y, lam);
            a0 = a0.add(sp.elo[l].mul(g0));
            a2 = a2.add(sp.elo[l].mul(g2));
        }
        LeafPart::slow(sp.ehi[b].mul(a0), sp.ehi[b].mul(a2), Vec::new())
    };
    let parts: Vec<LeafPart> = if nb > 1 && nb * bs >= cfg.par_min { (0..nb).into_par_iter().map(work).collect() } else { (0..nb).map(work).collect() };
    let (h0, h2, pure) = leaf_sum(&parts, lam);
    let (pp, ip) = ((pure * bs) as u64, ((nb - pure) * bs) as u64);
    cost.add(8 * ip + 6 * nb as u64, 6 * pp, 16 * pp + 128 * ip, 0);
    (h0, h2)
}

/// leaf layer, pass 1: fold the leaves with r0 into (Q0, Q1) of 2^(n-2)
/// entries and compute the round-1 polynomial
fn leaf_fold_round1(ctx: &Ctx, r0: Fp2, zr: &[Fp2], lam: Fp2, cfg: &Cfg, cost: &mut Cost) -> (Sparse, Fp2, Fp2) {
    let new_len = 1usize << (ctx.n - 2);
    assert_eq!(1usize << (zr.len() + 1), new_len);
    let sp_new = (ctx.s / 4).max(1).min(new_len / 2);
    let sp = split(zr, cfg, cost);
    let (bs, nb) = (sp.elo.len(), sp.ehi.len());
    let mut q: Vec<E2> = zvec(new_len);
    let work = |b: usize, ch: &mut [E2]| -> LeafPart {
        let x0 = 8 * b * bs;
        if cfg.fast {
            if let Some(t) = ctx.pure(x0, 8 * bs) {
                let v = &ctx.w.vals[x0..x0 + 8 * bs];
                let c = ctx.c[t];
                let (mut sa, mut spd, mut sd) = (ZERO, ZERO, ZERO);
                for l in 0..bs {
                    let e = sp.elo[l];
                    let mut qq = [[ZERO; 2]; 2];
                    for (h, qe) in qq.iter_mut().enumerate() {
                        let o = 8 * l + 4 * h;
                        let (a, bb, a2, b2) = (v[o] as i64, v[o + 1] as i64, v[o + 2] as i64, v[o + 3] as i64);
                        qe[0] = c.sub_base(Fp::new(a as u64)).sub(r0.mul_base(fpi(a2 - a)));
                        qe[1] = c.sub_base(Fp::new(bb as u64)).sub(r0.mul_base(fpi(b2 - bb)));
                    }
                    ch[2 * l] = qq[0];
                    ch[2 * l + 1] = qq[1];
                    let (xa, xb) = (qq[0], qq[1]);
                    sa = sa.add(e.mul(xa[0].add(xa[1])));
                    spd = spd.add(e.mul(xa[0].mul(xa[1])));
                    sd = sd.add(e.mul(xb[0].sub(xa[0]).mul(xb[1].sub(xa[1]))));
                }
                let eh = sp.ehi[b];
                return LeafPart { h0: ZERO, h2: ZERO, sa: eh.mul(sa), spd: eh.mul(spd), sd: eh.mul(sd), pure: true, rec: Vec::new() };
            }
        }
        let (mut a0, mut a2) = (ZERO, ZERO);
        let mut rec = Vec::new();
        for l in 0..bs {
            let j = b * bs + l;
            let x = fold4(&ctx.leaf_entry(4 * j), &ctx.leaf_entry(4 * j + 1), r0);
            let y = fold4(&ctx.leaf_entry(4 * j + 2), &ctx.leaf_entry(4 * j + 3), r0);
            ch[2 * l] = [x[2], x[3]];
            ch[2 * l + 1] = [y[2], y[3]];
            note_entry(&mut rec, 2 * j, &x, new_len, sp_new);
            note_entry(&mut rec, 2 * j + 1, &y, new_len, sp_new);
            let (g0, g2) = gpoly(&x, &y, lam);
            a0 = a0.add(sp.elo[l].mul(g0));
            a2 = a2.add(sp.elo[l].mul(g2));
        }
        LeafPart::slow(sp.ehi[b].mul(a0), sp.ehi[b].mul(a2), rec)
    };
    let parts: Vec<LeafPart> = if nb > 1 && nb * bs >= cfg.par_min {
        q.par_chunks_mut(2 * bs).enumerate().map(|(b, ch)| work(b, ch)).collect()
    } else {
        q.chunks_mut(2 * bs).enumerate().map(|(b, ch)| work(b, ch)).collect()
    };
    let (h0, h2, pure) = leaf_sum(&parts, lam);
    let (pp, ip) = ((pure * bs) as u64, ((nb - pure) * bs) as u64);
    cost.add(5 * pp + 16 * ip + 4 * nb as u64, 8 * pp, 32 * pp + 256 * ip, 64 * (pp + ip));
    let ps = collect_specials(parts, sp_new);
    (Sparse { q, sp: sp_new, ps }, h0, h2)
}

/// leaf layer, pass t >= 2: fold a sparse table and compute the round polynomial
fn sparse_fold_round(prev: &Sparse, r: Fp2, zr: &[Fp2], lam: Fp2, cfg: &Cfg, cost: &mut Cost) -> (Sparse, Fp2, Fp2) {
    let plen = prev.q.len();
    let new_len = plen / 2;
    assert_eq!(1usize << (zr.len() + 1), new_len);
    let sp_new = (prev.sp / 2).max(1).min(new_len / 2);
    let sp = split(zr, cfg, cost);
    let (bs, nb) = (sp.elo.len(), sp.ehi.len());
    let mut q: Vec<E2> = zvec(new_len);
    let work = |b: usize, ch: &mut [E2]| -> LeafPart {
        let i0 = 4 * b * bs;
        let pure = 4 * bs <= plen / 2 && !is_sp(i0 + 4 * bs - 1, plen, prev.sp);
        if cfg.fast && pure {
            let pq = &prev.q[i0..i0 + 4 * bs];
            let (mut sa, mut spd, mut sd) = (ZERO, ZERO, ZERO);
            for l in 0..bs {
                let e = sp.elo[l];
                let xa = [fold(pq[4 * l][0], pq[4 * l + 1][0], r), fold(pq[4 * l][1], pq[4 * l + 1][1], r)];
                let xb = [fold(pq[4 * l + 2][0], pq[4 * l + 3][0], r), fold(pq[4 * l + 2][1], pq[4 * l + 3][1], r)];
                ch[2 * l] = xa;
                ch[2 * l + 1] = xb;
                sa = sa.add(e.mul(xa[0].add(xa[1])));
                spd = spd.add(e.mul(xa[0].mul(xa[1])));
                sd = sd.add(e.mul(xb[0].sub(xa[0]).mul(xb[1].sub(xa[1]))));
            }
            let eh = sp.ehi[b];
            return LeafPart { h0: ZERO, h2: ZERO, sa: eh.mul(sa), spd: eh.mul(spd), sd: eh.mul(sd), pure: true, rec: Vec::new() };
        }
        let (mut a0, mut a2) = (ZERO, ZERO);
        let mut rec = Vec::new();
        for l in 0..bs {
            let j = b * bs + l;
            let x = fold4(&prev.entry(4 * j), &prev.entry(4 * j + 1), r);
            let y = fold4(&prev.entry(4 * j + 2), &prev.entry(4 * j + 3), r);
            ch[2 * l] = [x[2], x[3]];
            ch[2 * l + 1] = [y[2], y[3]];
            note_entry(&mut rec, 2 * j, &x, new_len, sp_new);
            note_entry(&mut rec, 2 * j + 1, &y, new_len, sp_new);
            let (g0, g2) = gpoly(&x, &y, lam);
            a0 = a0.add(sp.elo[l].mul(g0));
            a2 = a2.add(sp.elo[l].mul(g2));
        }
        LeafPart::slow(sp.ehi[b].mul(a0), sp.ehi[b].mul(a2), rec)
    };
    let parts: Vec<LeafPart> = if nb > 1 && nb * bs >= cfg.par_min {
        q.par_chunks_mut(2 * bs).enumerate().map(|(b, ch)| work(b, ch)).collect()
    } else {
        q.chunks_mut(2 * bs).enumerate().map(|(b, ch)| work(b, ch)).collect()
    };
    let (h0, h2, pure) = leaf_sum(&parts, lam);
    let (pp, ip) = ((pure * bs) as u64, ((nb - pure) * bs) as u64);
    cost.add(9 * pp + 16 * ip + 4 * nb as u64, 0, 128 * pp + 256 * ip, 64 * (pp + ip));
    let ps = collect_specials(parts, sp_new);
    (Sparse { q, sp: sp_new, ps }, h0, h2)
}

// ===================== the prover ==========================================
/// bottom-up: layers 1..=n-2 (index k), each [p, q] per node; layer n-1 virtual
fn build_layers(ctx: &Ctx, cfg: &Cfg, cost: &mut Cost) -> Vec<Option<Vec<E2>>> {
    let n = ctx.n;
    let mut layers: Vec<Option<Vec<E2>>> = (0..n - 1).map(|_| None).collect();
    let len = 1usize << (n - 2);
    let mut top: Vec<E2> = zvec(len);
    let ch = 1usize << 12;
    let fill = |ci: usize, c: &mut [E2]| {
        for (o, e) in c.iter_mut().enumerate() {
            let i = ci * ch + o;
            *e = combine(ctx.node1(2 * i), ctx.node1(2 * i + 1));
        }
    };
    if len >= cfg.par_min {
        top.par_chunks_mut(ch).enumerate().for_each(|(ci, c)| fill(ci, c));
    } else {
        top.chunks_mut(ch).enumerate().for_each(|(ci, c)| fill(ci, c));
    }
    cost.add(3 * len as u64, 4 * len as u64, 16 * len as u64, 32 * len as u64);
    layers[n - 2] = Some(top);
    for k in (1..n - 2).rev() {
        let below = layers[k + 1].as_ref().unwrap();
        let len = 1usize << k;
        let mut cur: Vec<E2> = zvec(len);
        let fill = |ci: usize, c: &mut [E2]| {
            for (o, e) in c.iter_mut().enumerate() {
                let i = ci * ch + o;
                *e = combine(below[2 * i], below[2 * i + 1]);
            }
        };
        if len >= cfg.par_min {
            cur.par_chunks_mut(ch).enumerate().for_each(|(ci, c)| fill(ci, c));
        } else {
            cur.chunks_mut(ch).enumerate().for_each(|(ci, c)| fill(ci, c));
        }
        cost.add(3 * len as u64, 0, 64 * len as u64, 32 * len as u64);
        layers[k] = Some(cur);
    }
    layers
}

#[derive(Clone, Copy)]
enum Src<'a> {
    Stored(&'a [E2]),
    Virtual,
    Leaves,
}
enum Tab {
    D(Vec<E4>),
    S(Sparse),
}

#[derive(Default, Clone, Debug)]
struct LayerStat {
    k: usize,
    secs: f64,
    rounds: usize,
    par_rounds: usize,
}

/// one layer's reduction: claims on layer k at z -> sumcheck over layer k+1
fn reduce_layer(ctx: &Ctx, cfg: &Cfg, cost: &mut Cost, k: usize, z: &[Fp2], claim: Fp2, lam: Fp2, src: Src, tr: &mut Transcript, stat: &mut LayerStat) -> (LayerProof, Vec<Fp2>) {
    assert_eq!(z.len(), k);
    let mut st = RoundState { eb: ONE, cs: claim };
    let mut rounds = Vec::with_capacity(k);
    let mut rho = Vec::with_capacity(k);
    let par = |pairs: usize| pairs >= cfg.par_min;
    // pass 0
    let pairs0 = 1usize << (k - 1);
    let (h0, h2) = match src {
        Src::Stored(l) => {
            let (h0, h2, p) = round0(&z[1..], lam, cfg, cost, |i| [l[2 * i][0], l[2 * i + 1][0], l[2 * i][1], l[2 * i + 1][1]]);
            cost.add(0, 0, 128 * p as u64, 0);
            (h0, h2)
        }
        Src::Virtual => {
            let (h0, h2, p) = round0(&z[1..], lam, cfg, cost, |i| ctx.virt_entry(i));
            cost.add(0, 8 * p as u64, 32 * p as u64, 0);
            (h0, h2)
        }
        Src::Leaves => leaf_round0(ctx, &z[1..], lam, cfg, cost),
    };
    stat.par_rounds += par(pairs0) as usize;
    let (c, mut r) = emit_round(&mut st, h0, h2, z[0], tr);
    rounds.push(c);
    rho.push(r);
    let finals: E4 = if k == 1 {
        let ent = |i: usize| -> E4 {
            match src {
                Src::Stored(l) => [l[2 * i][0], l[2 * i + 1][0], l[2 * i][1], l[2 * i + 1][1]],
                Src::Virtual => ctx.virt_entry(i),
                Src::Leaves => ctx.leaf_entry(i),
            }
        };
        fold4(&ent(0), &ent(1), r)
    } else {
        // pass 1: fold the source with r0
        let new_len = 1usize << (k - 1);
        let (mut tab, h0, h2) = match src {
            Src::Stored(l) => {
                let (t, h0, h2, p) = fold_round(new_len, r, &z[2..], lam, cfg, cost, |i| [l[2 * i][0], l[2 * i + 1][0], l[2 * i][1], l[2 * i + 1][1]]);
                cost.add(0, 0, 256 * p as u64, 128 * p as u64);
                (Tab::D(t), h0, h2)
            }
            Src::Virtual => {
                let (t, h0, h2, p) = fold_round(new_len, r, &z[2..], lam, cfg, cost, |i| ctx.virt_entry(i));
                cost.add(0, 16 * p as u64, 64 * p as u64, 128 * p as u64);
                (Tab::D(t), h0, h2)
            }
            Src::Leaves => {
                let (t, h0, h2) = leaf_fold_round1(ctx, r, &z[2..], lam, cfg, cost);
                (Tab::S(t), h0, h2)
            }
        };
        stat.par_rounds += par(new_len / 2) as usize;
        let (c, r1) = emit_round(&mut st, h0, h2, z[1], tr);
        rounds.push(c);
        rho.push(r1);
        r = r1;
        for t in 2..k {
            let (nt, h0, h2) = match tab {
                Tab::D(d) => {
                    let nl = d.len() / 2;
                    let (t2, h0, h2, p) = fold_round(nl, r, &z[t + 1..], lam, cfg, cost, |i| d[i]);
                    cost.add(0, 0, 256 * p as u64, 128 * p as u64);
                    (Tab::D(t2), h0, h2)
                }
                Tab::S(s) => {
                    let (t2, h0, h2) = sparse_fold_round(&s, r, &z[t + 1..], lam, cfg, cost);
                    (Tab::S(t2), h0, h2)
                }
            };
            tab = nt;
            let len = match &tab {
                Tab::D(d) => d.len(),
                Tab::S(s) => s.q.len(),
            };
            stat.par_rounds += par(len / 2) as usize;
            let (c, rt) = emit_round(&mut st, h0, h2, z[t], tr);
            rounds.push(c);
            rho.push(rt);
            r = rt;
        }
        match &tab {
            Tab::D(d) => fold4(&d[0], &d[1], r),
            Tab::S(s) => fold4(&s.entry(0), &s.entry(1), r),
        }
    };
    cost.add(20 * k as u64, 100 * k as u64, 0, 0); // per-round scalar work, one inversion each
    tr.absorb_fp2(b"gkr-finals", &finals);
    stat.rounds = k;
    (LayerProof { rounds, finals }, rho)
}

#[derive(Default, Clone, Debug)]
struct ProveStats {
    build: f64,
    topdown: f64,
    layers: Vec<LayerStat>,
    cost_build: Cost,
    cost_top: Cost,
    leaf_claim: E2,
    leaf_point: Vec<Fp2>,
    root: E2,
}

fn prove(ctx: &Ctx, cfg: &Cfg, tr: &mut Transcript, forge_root: bool) -> (Proof, ProveStats) {
    let n = ctx.n;
    let mut ps = ProveStats::default();
    let t0 = Instant::now();
    let mut cb = Cost::default();
    let mut layers = build_layers(ctx, cfg, &mut cb);
    ps.build = t0.elapsed().as_secs_f64();
    ps.cost_build = cb;
    let t1 = Instant::now();
    let mut ct = Cost::default();
    let l1 = layers[1].take().unwrap();
    ps.root = combine(l1[0], l1[1]);
    let mut layer1 = [l1[0][0], l1[1][0], l1[0][1], l1[1][1]];
    if forge_root {
        // a cheating prover: make the root numerator zero by changing p1[1]
        layer1[1] = layer1[0].mul(layer1[3]).mul(layer1[2].inv()).neg();
    }
    drop(l1);
    tr.absorb_fp2(b"gkr-layer1", &layer1);
    let mu = tr.challenge_fp2();
    let mut z = vec![mu];
    let (mut pc, mut qc) = (fold(layer1[0], layer1[1], mu), fold(layer1[2], layer1[3], mu));
    let mut out = Vec::with_capacity(n - 1);
    for k in 1..n {
        let tk = Instant::now();
        let lam = tr.challenge_fp2();
        let claim = pc.add(lam.mul(qc));
        let mut stat = LayerStat { k, ..Default::default() };
        let (lp, rho) = if k + 1 <= n - 2 {
            let l = layers[k + 1].take().unwrap();
            reduce_layer(ctx, cfg, &mut ct, k, &z, claim, lam, Src::Stored(&l), tr, &mut stat)
        } else if k + 1 == n - 1 {
            reduce_layer(ctx, cfg, &mut ct, k, &z, claim, lam, Src::Virtual, tr, &mut stat)
        } else {
            reduce_layer(ctx, cfg, &mut ct, k, &z, claim, lam, Src::Leaves, tr, &mut stat)
        };
        let f = lp.finals;
        let mu = tr.challenge_fp2();
        pc = fold(f[0], f[1], mu);
        qc = fold(f[2], f[3], mu);
        z = std::iter::once(mu).chain(rho).collect();
        out.push(lp);
        stat.secs = tk.elapsed().as_secs_f64();
        ps.layers.push(stat);
    }
    ps.topdown = t1.elapsed().as_secs_f64();
    ps.cost_top = ct;
    ps.leaf_claim = [pc, qc];
    ps.leaf_point = z;
    (Proof { layer1, layers: out }, ps)
}

// ===================== the verifier =========================================
/// Sum_x eq(z, x) (p(x), q(x)) over the verifier's own leaves: the ORACLE that
/// stands in for the leaf claim on the committed A planes (prototype only)
fn leaf_mle(ctx: &Ctx, z: &[Fp2]) -> E2 {
    let n = ctx.n;
    let lo = n / 2;
    let (elo, ehi) = (eq_tab(&z[..lo]), eq_tab(&z[lo..]));
    let bs = elo.len();
    let parts: Vec<E2> = (0..ehi.len())
        .into_par_iter()
        .map(|h| {
            let (mut ap, mut aq) = (ZERO, ZERO);
            for l in 0..bs {
                let v = ctx.leaf(h * bs + l);
                ap = ap.add(elo[l].mul(v[0]));
                aq = aq.add(elo[l].mul(v[1]));
            }
            [ehi[h].mul(ap), ehi[h].mul(aq)]
        })
        .collect();
    parts.iter().fold([ZERO, ZERO], |a, b| [a[0].add(b[0]), a[1].add(b[1])])
}

#[derive(Default, Clone, Debug)]
struct VerifyStats {
    rounds_secs: f64,
    oracle_secs: f64,
}

fn verify(wv: &Witness, proof: &Proof) -> (Result<(), String>, VerifyStats) {
    let mut vs = VerifyStats::default();
    let t0 = Instant::now();
    let n = wv.n;
    let mut tr = transcript_start(wv);
    let alpha = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let l = proof.layer1;
    tr.absorb_fp2(b"gkr-layer1", &l);
    if !l[0].mul(l[3]).add(l[1].mul(l[2])).is_zero() {
        return (Err("root numerator is nonzero: the lookup identity fails".into()), vs);
    }
    if l[2].mul(l[3]).is_zero() {
        return (Err("root denominator is zero: a zero LogUp denominator".into()), vs);
    }
    let mu = tr.challenge_fp2();
    let mut z = vec![mu];
    let (mut pc, mut qc) = (fold(l[0], l[1], mu), fold(l[2], l[3], mu));
    if proof.layers.len() != n - 1 {
        return (Err("wrong number of layers".into()), vs);
    }
    for k in 1..n {
        let lp = &proof.layers[k - 1];
        if lp.rounds.len() != k {
            return (Err(format!("layer {k}: wrong round count")), vs);
        }
        let lam = tr.challenge_fp2();
        let mut claim = pc.add(lam.mul(qc));
        let mut rho = Vec::with_capacity(k);
        for (t, c) in lp.rounds.iter().enumerate() {
            let s01 = c[0].add(c[0].add(c[1]).add(c[2]).add(c[3]));
            if s01 != claim {
                return (Err(format!("layer {k} round {t}: s(0)+s(1) != claim")), vs);
            }
            tr.absorb_fp2(b"gkr-round", c);
            let r = tr.challenge_fp2();
            claim = c[0].add(r.mul(c[1].add(r.mul(c[2].add(r.mul(c[3]))))));
            rho.push(r);
        }
        let f = lp.finals;
        tr.absorb_fp2(b"gkr-finals", &f);
        if claim != eq_pt(&z, &rho).mul(gval(&f, lam)) {
            return (Err(format!("layer {k}: final evaluation check fails")), vs);
        }
        let mu = tr.challenge_fp2();
        pc = fold(f[0], f[1], mu);
        qc = fold(f[2], f[3], mu);
        z = std::iter::once(mu).chain(rho).collect();
    }
    vs.rounds_secs = t0.elapsed().as_secs_f64();
    let t1 = Instant::now();
    let ctx = Ctx::new(wv, alpha, gamma);
    let want = leaf_mle(&ctx, &z);
    vs.oracle_secs = t1.elapsed().as_secs_f64();
    if want != [pc, qc] {
        return (Err("leaf claim does not match the (committed) leaves".into()), vs);
    }
    (Ok(()), vs)
}

// ===================== independent reference prover =========================
fn interp_cubic(y: [Fp2; 4]) -> E4 {
    let inv2 = Fp2::from_u64(2).inv();
    let inv3 = Fp2::from_u64(3).inv();
    let inv6 = Fp2::from_u64(6).inv();
    let d1 = y[1].sub(y[0]);
    let d2 = y[2].sub(y[1].double()).add(y[0]);
    let d3 = y[3].sub(y[2].mul_base(Fp(3))).add(y[1].mul_base(Fp(3))).sub(y[0]);
    [y[0], d1.sub(d2.mul(inv2)).add(d3.mul(inv3)), d2.sub(d3).mul(inv2), d3.mul(inv6)]
}
/// textbook full-tree prover from explicit leaves: brute-force evaluation of
/// each round polynomial at X = 0..3, no fusion, no split eq, no fast paths
fn prove_ref(leaves: Vec<E2>, tr: &mut Transcript) -> Proof {
    let n = leaves.len().trailing_zeros() as usize;
    let mut full: Vec<Vec<E2>> = vec![Vec::new(); n + 1];
    full[n] = leaves;
    for k in (0..n).rev() {
        full[k] = (0..1usize << k).map(|i| combine(full[k + 1][2 * i], full[k + 1][2 * i + 1])).collect();
    }
    let l1 = &full[1];
    let layer1 = [l1[0][0], l1[1][0], l1[0][1], l1[1][1]];
    tr.absorb_fp2(b"gkr-layer1", &layer1);
    let mu = tr.challenge_fp2();
    let mut z = vec![mu];
    let mut out = Vec::new();
    for k in 1..n {
        let lam = tr.challenge_fp2();
        let lk = &full[k + 1];
        let mut t: Vec<E4> = (0..1usize << k).map(|i| [lk[2 * i][0], lk[2 * i + 1][0], lk[2 * i][1], lk[2 * i + 1][1]]).collect();
        let mut eb = ONE;
        let mut rho = Vec::new();
        let mut rounds = Vec::new();
        for tt in 0..k {
            let er = eq_tab(&z[tt + 1..k]);
            let mut ys = [ZERO; 4];
            for (xv, y) in ys.iter_mut().enumerate() {
                let xf = Fp2::from_u64(xv as u64);
                let w = eb.mul(ONE.sub(z[tt]).add(z[tt].double().sub(ONE).mul(xf)));
                let mut acc = ZERO;
                for j in 0..t.len() / 2 {
                    let a = t[2 * j];
                    let b = t[2 * j + 1];
                    let e = [a[0].add(xf.mul(b[0].sub(a[0]))), a[1].add(xf.mul(b[1].sub(a[1]))), a[2].add(xf.mul(b[2].sub(a[2]))), a[3].add(xf.mul(b[3].sub(a[3])))];
                    acc = acc.add(er[j].mul(gval(&e, lam)));
                }
                *y = w.mul(acc);
            }
            let c = interp_cubic(ys);
            tr.absorb_fp2(b"gkr-round", &c);
            let r = tr.challenge_fp2();
            eb = eb.mul(eq1(z[tt], r));
            rho.push(r);
            rounds.push(c);
            t = (0..t.len() / 2).map(|j| fold4(&t[2 * j], &t[2 * j + 1], r)).collect();
        }
        let finals = t[0];
        tr.absorb_fp2(b"gkr-finals", &finals);
        let mu = tr.challenge_fp2();
        z = std::iter::once(mu).chain(rho).collect();
        out.push(LayerProof { rounds, finals });
    }
    Proof { layer1, layers: out }
}
fn explicit_leaves(ctx: &Ctx) -> Vec<E2> {
    (0..1usize << ctx.n).map(|x| ctx.leaf(x)).collect()
}

/// direct fractional sum sum_x p/q and product prod_x q (batch inversion)
fn direct_sum(ctx: &Ctx) -> Result<(Fp2, Fp2), String> {
    let nn = 1usize << ctx.n;
    let ch = 1usize << 14.min(ctx.n);
    let parts: Vec<Result<(Fp2, Fp2), String>> = (0..nn / ch)
        .into_par_iter()
        .map(|c| {
            let lv: Vec<E2> = (0..ch).map(|o| ctx.leaf(c * ch + o)).collect();
            let mut d: Vec<Fp2> = lv.iter().map(|e| e[1]).collect();
            let prod = d.iter().fold(ONE, |a, b| a.mul(*b));
            batch_inverse2_checked(&mut d).map_err(|e| e.to_string())?;
            let s = lv.iter().zip(&d).fold(ZERO, |a, (e, inv)| a.add(e[0].mul(*inv)));
            Ok((s, prod))
        })
        .collect();
    let mut s = ZERO;
    let mut p = ONE;
    for r in parts {
        let (a, b) = r?;
        s = s.add(a);
        p = p.mul(b);
    }
    Ok((s, p))
}

// ===================== the committed-helper baseline ========================
/// per-width inverse tables 1/(c_w - t), t in [0, 2^w): the native W16 `tabs`
fn helper_tables(ctx: &Ctx) -> Vec<Vec<Fp2>> {
    ctx.w
        .widths
        .iter()
        .enumerate()
        .map(|(t, &wd)| {
            let mut d: Vec<Fp2> = (0..1u64 << wd).map(|v| ctx.c[t].sub_base(Fp::new(v))).collect();
            if d.len() >= 1 << 15 {
                d.par_chunks_mut(1 << 14).for_each(batch_inverse2);
            } else {
                batch_inverse2(&mut d);
            }
            d
        })
        .collect()
}
/// helper i (one Fp2 per two lookups, leaves 2i, 2i+1) by table gathers,
/// written to separate real / imaginary rows (`write_helpers_w16`'s form)
fn helper_write(ctx: &Ctx, tbl: &[Vec<Fp2>], re: &mut [Fp], im: &mut [Fp]) {
    let ch = 1usize << 13;
    re.par_chunks_mut(ch).zip(im.par_chunks_mut(ch)).enumerate().for_each(|(ci, (rc, ic))| {
        for o in 0..rc.len() {
            let i = ci * ch + o;
            let x = 2 * i;
            let h = if !ctx.special(x) {
                let t = ctx.tag(x);
                tbl[t][ctx.w.vals[x] as usize].add(tbl[t][ctx.w.vals[x + 1] as usize])
            } else {
                let one = |y: usize| -> Fp2 {
                    match ctx.w.sp[ctx.sidx(y)] {
                        Sp::Tab { tag, t, m } => tbl[tag as usize][t as usize].mul_base(Fp::new(m)).neg(),
                        Sp::Blind { x, y } => x.mul(y.inv()),
                    }
                };
                one(x).add(one(x + 1))
            };
            rc[o] = h.c0;
            ic[o] = h.c1;
        }
    });
}
/// the pre-stage-28 form: batch-invert every denominator, then pair and write
fn helper_batchinv(ctx: &Ctx, re: &mut [Fp], im: &mut [Fp]) {
    let ch = 1usize << 13; // helpers per chunk = 2^14 denominators
    re.par_chunks_mut(ch).zip(im.par_chunks_mut(ch)).enumerate().for_each(|(ci, (rc, ic))| {
        let x0 = 2 * ci * ch;
        let lv: Vec<E2> = (0..2 * rc.len()).map(|o| ctx.leaf(x0 + o)).collect();
        let mut d: Vec<Fp2> = lv.iter().map(|e| e[1]).collect();
        batch_inverse2(&mut d);
        for o in 0..rc.len() {
            let (a, b) = (&lv[2 * o], &lv[2 * o + 1]);
            let h = if a[0] == ONE && b[0] == ONE { d[2 * o].add(d[2 * o + 1]) } else { a[0].mul(d[2 * o]).add(b[0].mul(d[2 * o + 1])) };
            rc[o] = h.c0;
            ic[o] = h.c1;
        }
    });
}

// ===================== tests and controls ===================================
struct Report {
    pass: usize,
    fail: usize,
}
impl Report {
    fn check(&mut self, name: &str, ok: bool, detail: &str) {
        if ok {
            self.pass += 1;
            println!("PASS {name} {detail}");
        } else {
            self.fail += 1;
            println!("FAIL {name} {detail}");
        }
    }
}

fn run_prove(w: &Witness, cfg: &Cfg, forge: bool) -> (Proof, ProveStats) {
    let mut tr = transcript_start(w);
    let alpha = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let ctx = Ctx::new(w, alpha, gamma);
    prove(&ctx, cfg, &mut tr, forge)
}
fn run_ref(w: &Witness, tamper: &dyn Fn(&mut Vec<E2>, &Witness)) -> Proof {
    let mut tr = transcript_start(w);
    let alpha = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let ctx = Ctx::new(w, alpha, gamma);
    let mut lv = explicit_leaves(&ctx);
    tamper(&mut lv, w);
    prove_ref(lv, &mut tr)
}
fn ctx_of(w: &Witness) -> (Fp2, Fp2) {
    let mut tr = transcript_start(w);
    (tr.challenge_fp2(), tr.challenge_fp2())
}
fn first_query_of_width(w: &Witness, width: u32) -> usize {
    (0..1usize << w.n).find(|&x| !w.special(x) && w.widths[w.tag(x)] == width).expect("a query of that width")
}

fn controls(name: &str, w: &Witness, cfg: &Cfg, rep: &mut Report) {
    let maxw = *w.widths.iter().max().unwrap();
    // honest
    let (pf, st) = run_prove(w, cfg, false);
    let (ok, _) = verify(w, &pf);
    rep.check(&format!("{name}/honest-verifies"), ok.is_ok(), &format!("{ok:?}"));
    let (a, g) = ctx_of(w);
    let ctx = Ctx::new(w, a, g);
    let ds = direct_sum(&ctx);
    let ok_ds = matches!(ds, Ok((s, p)) if s.is_zero() && p == st.root[1] && st.root[0].is_zero());
    rep.check(&format!("{name}/honest-direct-sum-zero-and-root-matches"), ok_ds, "");
    // C1 out-of-table value (multiplicities unchanged)
    let mut bad = w.clone();
    let x0 = first_query_of_width(w, maxw);
    bad.vals[x0] = (1u32 << maxw) + 7;
    let (pf1, st1) = run_prove(&bad, cfg, false);
    let (r1, _) = verify(&bad, &pf1);
    let (a, g) = ctx_of(&bad);
    let dsb = direct_sum(&Ctx::new(&bad, a, g));
    rep.check(&format!("{name}/C1-out-of-table-breaks-identity"), !st1.root[0].is_zero() && matches!(dsb, Ok((s, _)) if !s.is_zero()) && r1.is_err(), &format!("{r1:?}"));
    // C2 same bad witness, forged root
    let (pf2, _) = run_prove(&bad, cfg, true);
    let (r2, _) = verify(&bad, &pf2);
    rep.check(&format!("{name}/C2-forged-root-refused"), r2.is_err(), &format!("{r2:?}"));
    // C3 wrong multiplicity
    let mut badm = w.clone();
    let k = badm.sp.iter().position(|e| matches!(e, Sp::Tab { m, .. } if *m > 0)).unwrap();
    if let Sp::Tab { m, .. } = &mut badm.sp[k] {
        *m += 1;
    }
    let (pf3, _) = run_prove(&badm, cfg, false);
    let (r3, _) = verify(&badm, &pf3);
    rep.check(&format!("{name}/C3-wrong-multiplicity-refused"), r3.is_err(), &format!("{r3:?}"));
    // C4 tampered round coefficient
    let mut pf4 = pf.clone();
    let kk = pf4.layers.len() / 2;
    pf4.layers[kk].rounds[0][1] = pf4.layers[kk].rounds[0][1].add(ONE);
    let (r4, _) = verify(w, &pf4);
    rep.check(&format!("{name}/C4-tampered-round-refused"), r4.is_err(), &format!("{r4:?}"));
    // C5 tampered finals
    let mut pf5 = pf.clone();
    let last = pf5.layers.len() - 1;
    pf5.layers[last].finals[2] = pf5.layers[last].finals[2].add(ONE);
    let (r5, _) = verify(w, &pf5);
    rep.check(&format!("{name}/C5-tampered-finals-refused"), r5.is_err(), &format!("{r5:?}"));
    // C6 zero denominator in a blinding leaf
    let mut bz = w.clone();
    let bi = bz.sp.iter().position(|e| matches!(e, Sp::Blind { .. })).unwrap();
    if let Sp::Blind { y, .. } = &mut bz.sp[bi] {
        *y = ZERO;
    }
    let (pf6, _) = run_prove(&bz, cfg, false);
    let (r6, _) = verify(&bz, &pf6);
    let (a, g) = ctx_of(&bz);
    let dz = direct_sum(&Ctx::new(&bz, a, g));
    rep.check(&format!("{name}/C6-zero-denominator-refused"), r6.is_err() && dz.is_err(), &format!("{r6:?}"));
    // C9 a (0, 0) leaf: the root becomes (0, 0), which passes a numerator-only
    // check; the root-denominator check must refuse it
    let mut b00 = w.clone();
    if let Sp::Blind { x, y } = &mut b00.sp[bi] {
        *x = ZERO;
        *y = ZERO;
    }
    let (pf9, st9) = run_prove(&b00, cfg, false);
    let (r9, _) = verify(&b00, &pf9);
    rep.check(&format!("{name}/C9-zero-zero-leaf-refused-by-denominator-check"), st9.root[0].is_zero() && st9.root[1].is_zero() && matches!(&r9, Err(e) if e.contains("denominator")), &format!("{r9:?}"));
    // C7 leaves differ from the committed ones (prover consistent with its own)
    let mut alt = w.clone();
    let x1 = first_query_of_width(w, maxw);
    alt.vals[x1] = (alt.vals[x1] + 1) % (1u32 << maxw);
    alt.recount();
    let (pf7, _) = run_prove(&alt, cfg, false);
    let (r7a, _) = verify(&alt, &pf7);
    let (r7, _) = verify(w, &pf7);
    rep.check(&format!("{name}/C7-other-leaves-refused-by-leaf-claim"), r7a.is_ok() && r7.is_err(), &format!("{r7:?}"));
    // C8 cancel a matched (query, table) pair: query p := 0, its table m -= 1
    let pf8 = run_ref(w, &|lv, ww| {
        let x = first_query_of_width(ww, maxw);
        lv[x][0] = ZERO;
        let (t, v) = (ww.tag(x), ww.vals[x]);
        for y in 0..lv.len() {
            if ww.special(y) {
                if let Sp::Tab { tag, t: tv, m } = ww.sp[ww.sidx(y)] {
                    if tag as usize == t && tv == v && m > 0 {
                        lv[y][0] = lv[y][0].add(ONE); // -m -> -(m-1)
                        break;
                    }
                }
            }
        }
    });
    let (r8, _) = verify(w, &pf8);
    rep.check(&format!("{name}/C8-cancelled-pair-refused-by-leaf-claim"), r8.is_err() && pf8.layer1[0].mul(pf8.layer1[3]).add(pf8.layer1[1].mul(pf8.layer1[2])).is_zero(), &format!("{r8:?}"));
}

fn tests() -> bool {
    let mut rep = Report { pass: 0, fail: 0 };
    // unit: the fast layer-(n-1) node equals the generic combine
    {
        let w = gen_witness(8, 2, 2, &[2, 1], &[1, 1], 3);
        let (a, g) = ctx_of(&w);
        let ctx = Ctx::new(&w, a, g);
        let ok = (0..1usize << 7).all(|i| ctx.node1(i) == combine(ctx.leaf(2 * i), ctx.leaf(2 * i + 1)));
        rep.check("unit/node1-fast-equals-combine", ok, "");
    }
    // tiny and medium configurations: optimized == reference, fast == slow
    let tiny_lo = [Cfg { lo_max: 2, par_min: 1 << 30, fast: true }, Cfg { lo_max: 10, par_min: 1 << 30, fast: true }, Cfg { lo_max: 3, par_min: 4, fast: true }];
    for n in 4..=11 {
        let w = gen_witness(n, 2, 2, &[2, 1], &[3, 1], 100 + n as u64);
        let rf = run_ref(&w, &|_, _| {});
        for (ci, cfg) in tiny_lo.iter().enumerate() {
            let (pf, _) = run_prove(&w, cfg, false);
            rep.check(&format!("tiny/n{n}/cfg{ci}/optimized-equals-reference"), pf == rf, "");
            let slow = Cfg { fast: false, ..*cfg };
            let (ps, _) = run_prove(&w, &slow, false);
            rep.check(&format!("tiny/n{n}/cfg{ci}/fast-equals-slow"), ps == pf, "");
        }
        let (ok, _) = verify(&w, &rf);
        rep.check(&format!("tiny/n{n}/reference-verifies"), ok.is_ok(), &format!("{ok:?}"));
    }
    for n in [12usize, 13, 14] {
        let w = gen_witness(n, 9, 10, &[8, 7, 4], &[5, 2, 1], 200 + n as u64);
        let rf = run_ref(&w, &|_, _| {});
        for cfg in [Cfg { lo_max: 4, par_min: 64, fast: true }, Cfg { lo_max: 6, par_min: 1 << 30, fast: true }, Cfg::default()] {
            let (pf, _) = run_prove(&w, &cfg, false);
            rep.check(&format!("medium/n{n}/lo{}/optimized-equals-reference", cfg.lo_max), pf == rf, "");
            let (ps, _) = run_prove(&w, &Cfg { fast: false, ..cfg }, false);
            rep.check(&format!("medium/n{n}/lo{}/fast-equals-slow", cfg.lo_max), ps == pf, "");
        }
        let (ok, _) = verify(&w, &rf);
        rep.check(&format!("medium/n{n}/verifies"), ok.is_ok(), &format!("{ok:?}"));
    }
    // controls: tiny, medium and the W16 widths
    controls("tiny-n9", &gen_witness(9, 2, 2, &[2, 1], &[3, 1], 7), &Cfg { lo_max: 2, par_min: 8, fast: true }, &mut rep);
    controls("medium-n14", &gen_witness(14, 9, 10, &[8, 7, 4], &[5, 2, 1], 8), &Cfg { lo_max: 4, par_min: 64, fast: true }, &mut rep);
    let w16 = gen_witness(18, 16, 14, &W16_WIDTHS, &W16_WEIGHTS, 9);
    {
        let (pf, _) = run_prove(&w16, &Cfg::default(), false);
        let (ps, _) = run_prove(&w16, &Cfg { fast: false, ..Cfg::default() }, false);
        rep.check("w16-n18/fast-equals-slow", pf == ps, "");
    }
    controls("w16-n18", &w16, &Cfg::default(), &mut rep);
    println!("TESTS pass={} fail={}", rep.pass, rep.fail);
    rep.fail == 0
}

// ===================== benchmark ============================================
/// W16 range families (widths of the tagged sub-tables) and a rough query mix
const W16_WIDTHS: [u32; 9] = [16, 15, 13, 12, 8, 7, 5, 4, 2];
const W16_WEIGHTS: [u32; 9] = [70, 5, 3, 5, 8, 3, 2, 2, 2];

fn fmt_fp2(v: Fp2) -> String {
    format!("\"{:016x}{:016x}\"", v.c1.0, v.c0.0)
}

fn bench(n: usize, reps: usize, threads: usize, do_helper: bool, do_commit: bool, cfg: Cfg) {
    println!("CONFIG {{\"lo_max\":{},\"par_min\":{},\"fast\":{}}}", cfg.lo_max, cfg.par_min, cfg.fast);
    let t = Instant::now();
    let w = gen_witness(n, 16, 14, &W16_WIDTHS, &W16_WEIGHTS, 2026_1101 + n as u64);
    let gen_s = t.elapsed().as_secs_f64();
    let nn = 1usize << n;
    let base_heap = heap_now();
    println!(
        "WITNESS {{\"log_leaves\":{n},\"leaves\":{nn},\"queries\":{},\"table_entries\":{},\"special_per_half\":{},\"threads\":{threads},\"gen_secs\":{gen_s:.3},\"witness_heap_bytes\":{base_heap}}}",
        w.queries(),
        w.n_table,
        w.s()
    );
    for rep in 0..reps {
        let base = peak_reset();
        let t0 = Instant::now();
        let mut tr = transcript_start(&w);
        let alpha = tr.challenge_fp2();
        let gamma = tr.challenge_fp2();
        let ctx = Ctx::new(&w, alpha, gamma);
        let mat = t0.elapsed().as_secs_f64();
        let (pf, ps) = prove(&ctx, &cfg, &mut tr, false);
        let total = t0.elapsed().as_secs_f64();
        let peak = heap_peak() - base;
        let (vr, vs) = verify(&w, &pf);
        assert!(vr.is_ok(), "verification failed: {vr:?}");
        let mut ds_ok = String::from("null");
        if rep == 0 {
            let td = Instant::now();
            let ds = direct_sum(&ctx).expect("no zero denominator");
            ds_ok = format!("{{\"sum_is_zero\":{},\"root_q_equals_product\":{},\"secs\":{:.4}}}", ds.0.is_zero(), ds.1 == ps.root[1], td.elapsed().as_secs_f64());
        }
        let c = {
            let mut c = ps.cost_build;
            c.add(ps.cost_top.fp2, ps.cost_top.base, ps.cost_top.rd, ps.cost_top.wr);
            c
        };
        let per = |v: f64| v / nn as f64;
        let big: Vec<String> = ps.layers.iter().filter(|l| l.k + 6 >= n).map(|l| format!("[{},{:.5},{}]", l.k, l.secs, l.par_rounds)).collect();
        let par_rounds: usize = ps.layers.iter().map(|l| l.par_rounds).sum();
        let rounds: usize = ps.layers.iter().map(|l| l.rounds).sum();
        println!(
            "RESULT gkr {{\"log_leaves\":{n},\"rep\":{rep},\"threads\":{threads},\"materialize_s\":{mat:.6},\"build_s\":{:.6},\"topdown_s\":{:.6},\"prove_s\":{total:.6},\"ns_per_leaf\":{:.3},\"ns_per_query\":{:.3},\"verify_rounds_s\":{:.6},\"verify_oracle_s\":{:.6},\"peak_heap_bytes\":{peak},\"peak_heap_b_per_leaf\":{:.2},\"proof_bytes\":{},\"rounds\":{rounds},\"parallel_rounds\":{par_rounds},\"fp2_mul\":{},\"base_mul\":{},\"fp2_equiv_per_leaf\":{:.3},\"bytes_rd_per_leaf\":{:.2},\"bytes_wr_per_leaf\":{:.2},\"build_fp2_equiv_per_leaf\":{:.3},\"top_fp2_equiv_per_leaf\":{:.3},\"direct\":{ds_ok},\"root_q\":{},\"last_layers_k_secs_parrounds\":[{}]}}",
            ps.build,
            ps.topdown,
            per(total * 1e9),
            total * 1e9 / w.queries() as f64,
            vs.rounds_secs,
            vs.oracle_secs,
            per(peak as f64),
            pf.bytes(),
            c.fp2,
            c.base,
            per(c.fp2_equiv()),
            per(c.rd as f64),
            per(c.wr as f64),
            per(ps.cost_build.fp2_equiv()),
            per(ps.cost_top.fp2_equiv()),
            fmt_fp2(ps.root[1]),
            big.join(",")
        );
    }
    if do_helper {
        let mut tr = transcript_start(&w);
        let alpha = tr.challenge_fp2();
        let gamma = tr.challenge_fp2();
        let ctx = Ctx::new(&w, alpha, gamma);
        for rep in 0..reps {
            let base = peak_reset();
            let t0 = Instant::now();
            let tbl = helper_tables(&ctx);
            let t_tab = t0.elapsed().as_secs_f64();
            let mut re: Vec<Fp> = zvec(nn / 2);
            let mut im: Vec<Fp> = zvec(nn / 2);
            let t1 = Instant::now();
            helper_write(&ctx, &tbl, &mut re, &mut im);
            let t_wr = t1.elapsed().as_secs_f64();
            let peak_w = heap_peak() - base;
            let mut re2: Vec<Fp> = zvec(nn / 2);
            let mut im2: Vec<Fp> = zvec(nn / 2);
            let t2 = Instant::now();
            helper_batchinv(&ctx, &mut re2, &mut im2);
            let t_bi = t2.elapsed().as_secs_f64();
            let same = re == re2 && im == im2;
            drop(re2);
            drop(im2);
            let mut commit_s = -1.0;
            let mut peak_c = 0usize;
            if do_commit {
                let mut data = re;
                data.extend_from_slice(&im);
                drop(im);
                let params = PcsParams { log_cols: 14, inv_rate: 4, num_col_checks: 256 };
                let ntt = NttTables::new(16);
                let zk = ZkOpts::standard(&params);
                let mut rng = ZkRng::new(rep as u64 + 1, b"logup-gkr-proto/helper-commit");
                let bc = peak_reset();
                let t3 = Instant::now();
                let cm = commit_zk_owned(&params, data, &ntt, &zk, &mut rng);
                commit_s = t3.elapsed().as_secs_f64();
                peak_c = heap_peak() - bc;
                std::hint::black_box(cm.cm.tree.root());
                drop(cm);
            }
            let per = |v: f64| v * 1e9 / nn as f64;
            println!(
                "RESULT helper {{\"log_leaves\":{n},\"rep\":{rep},\"threads\":{threads},\"inverse_tables_s\":{t_tab:.6},\"gather_write_s\":{t_wr:.6},\"batchinv_write_s\":{t_bi:.6},\"commit_s\":{commit_s:.6},\"ns_per_leaf_tables\":{:.3},\"ns_per_leaf_gather\":{:.3},\"ns_per_leaf_batchinv\":{:.3},\"ns_per_leaf_commit\":{:.3},\"gather_equals_batchinv\":{same},\"helper_words\":{nn},\"peak_heap_write_bytes\":{peak_w},\"peak_heap_commit_bytes\":{peak_c}}}",
                per(t_tab),
                per(t_wr),
                per(t_bi),
                per(commit_s.max(0.0))
            );
        }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let get = |k: &str, d: usize| -> usize { args.iter().position(|a| a == k).and_then(|i| args.get(i + 1)).map(|v| v.parse().expect("integer")).unwrap_or(d) };
    let threads = get("--threads", 0);
    if threads > 0 {
        rayon::ThreadPoolBuilder::new().num_threads(threads).build_global().expect("pool");
    }
    let threads = rayon::current_num_threads();
    match args.get(1).map(|s| s.as_str()) {
        Some("test") => {
            let ok = tests();
            std::process::exit(if ok { 0 } else { 1 });
        }
        Some("bench") => {
            let reps = get("--reps", 3);
            let helper = !args.iter().any(|a| a == "--no-helper");
            let commit = !args.iter().any(|a| a == "--no-commit");
            let d = Cfg::default();
            let cfg = Cfg { lo_max: get("--lo-max", d.lo_max), par_min: 1usize << get("--log-par-min", d.par_min.trailing_zeros() as usize), fast: !args.iter().any(|a| a == "--slow") };
            for n in args.iter().position(|a| a == "--log-n").map(|i| args[i + 1].split(',').map(|v| v.parse().unwrap()).collect::<Vec<usize>>()).unwrap_or(vec![20]) {
                bench(n, reps, threads, helper, commit, cfg);
            }
        }
        _ => {
            eprintln!("usage: logup-gkr-w16-proto test | bench --log-n 20,22,24 [--reps 3] [--threads T] [--no-helper] [--no-commit]");
            std::process::exit(2);
        }
    }
}

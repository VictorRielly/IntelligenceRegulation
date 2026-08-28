// [UPERF3-S] U-PERF3 round 1, lane S — the SPIKE for the Stage-A protocol
// change of U_PERF3_OPENING_LAYER_DESIGN.md (S1 range facts as base-field
// booleanity + recomposition zero-checks; S2 the SiLU LogUp as ONE
// sumcheck with a committed helper h). SYNTHETIC, NO ENGINE CHANGE: nothing
// here is called by any shipped path; the frozen masked descent
// (gkr_masked.rs, the BK pair builder in the bin) is the ORACLE the bin's
// `uperf-s` arms compare against. Everything below is additive.
//
// S1 (b): the zero-check
//     sum_x eq(rho, x) * [ sum_k beta_k * f(d_k(x)) + beta_rec * (r(x) - sum_k 2^(e0 k) d_k(x)) ] = 0
// over the 2^n hypercube of one committed column, where d_k are the
// committed digit planes of the remainder r (e0 = 1: bit planes b in {0,1},
// f(v) = v(1-v); e0 = 2: the house balanced base-4 digits {-2..1},
// f(v) = (v+2)(v+1)v(v-1)) and the recomposition term ties the planes to
// the value the descent proves in range. Field: the prover TABLES are
// base-field residues (u32) until the first fold; every challenge (rho,
// beta, the round r_t) is drawn in the sub-extension E_c = GF(q^c) c K,
// c in {4, 8, 16} (design memo Section 2.6: c >= 4 for ~2^-120 per round;
// c = 16 is K itself), realized INSIDE K as the elements whose Y-coordinates
// vanish off the multiples of 16/c: E_c = Z_q[Z]/(Z^c - s0), Z = Y^(16/c)
// (Y^16 - s0 irreducible => Z^c - s0 irreducible => a field of size q^c).
// So every E_c value is a K-value the verifier / transcript can absorb with
// the house encoding, c = 16 IS the frozen K arithmetic (the differential
// leg against fold.rs `ixf_sumcheck_prove` is byte-identical), and the
// prover's arithmetic per element is c^2 base MACs (E x E) / c (E x base)
// instead of the descent's 256 (K x K).
//
// Prover shape (mirrors the K9 kernel discipline so the wall comparison
// is kernel-vs-kernel, not kernel-vs-boxed): lane-blocked SoA tables (8
// lanes per block, coordinate-major), 32x32->64 MACs into split lo/hi u64
// planes, one special-form reduction per output coordinate (q = 2^31 - 399:
// two fold31 + canon), persistent lazy node planes summed per chunk in index
// order (deterministic ZK_THREADS). The eq factor is never folded: with
// eq(rho, x) = prod_t eq(rho_t, x_t) the current variable's factor
// eq(rho_t, X) is a per-node SCALAR pulled out of the sum, and the table
// over the unbound variables is the even-lane compaction of the previous
// round's table (no arithmetic), so the round polynomial is
//     g_t(X) = K_t * eq(rho_t, X) * H_t(X),   H_t(X) = sum_i eq_pairs[i] * G(r_<t, X, i),
// with K_t = prod_{s<t} eq(rho_s, r_s) / prod_{s<=t} (1 - rho_s). H_t has
// degree deg_f, evaluated at nodes {0, 2, .., deg_f}; H_t(1) comes from the
// round identity g(0) + g(1) = C (the descent kernel's own trick), the
// last node by exact extrapolation; the shipped g_t has deg_f + 2 nodes.
//
// S2 (b): the LogUp well-formedness sum_x eq(rho, x) [h(x)(alpha - key(x)) - 1]
// = 0 is the frozen claim layer's Had shape (v0 (v1 v2 - v3)) with tables
// [eq, h, alpha - key, 1] — it runs on fold.rs's packed prover verbatim
// (`ixf_sumcheck_prove_packed`, IxfCombine::Had); h_i = 1/(alpha - key_i)
// is built by the honest prover from the 256 table-row inverses.
//
// Structural counters for the frozen masked descent (S1/S2 (a)) are at the
// end: 3 K-mults per pair-term per evaluated node in the fused round kernel
// (round_g5_pair: PL*Q1, P1*Q0, eq*wire), 5 folds per pair-term per round,
// the extract / eq builds, the tree build with the c=2 recompute.

use super::XofReader;
use super::gkr::eq_eval;
use super::kfield::{K_DEG, KElem, KField, KL, KTab, k9_pooled_pub, k9_threads};
use super::sumcheck::{LkpTranscript, SumcheckProof};

// ---------------------------------------------------------------------------
// E_c = GF(q^c) inside K.

/// One E_c element: c canonical coordinates in Z = Y^(16/c), little-endian.
pub type EElem = Vec<u32>;

/// The sub-extension context (see the module header). Requires the K9
/// modulus gate (2^30 < q < 2^31, 2^31 mod q < 1024) — the frozen q31 point.
#[derive(Clone, Copy)]
pub struct SubExt {
    pub c: usize,
    pub stride: usize,
    pub q: u64,
    pub s: u64,
    c31: u64,
    c32: u64,
    q32: u32,
}

const M32: u64 = 0xFFFF_FFFF;

#[inline(always)]
fn fold31(v: u64, c31: u64) -> u64 {
    (v & 0x7FFF_FFFF) + c31 * (v >> 31)
}

#[inline(always)]
fn canon32(v: u64, q32: u32) -> u32 {
    let r = v as u32;
    let r = r.min(r.wrapping_sub(q32));
    r.min(r.wrapping_sub(q32))
}

#[inline(always)]
fn addm32(a: u32, b: u32, q32: u32) -> u32 {
    let s = a + b;
    s.min(s.wrapping_sub(q32))
}

#[inline(always)]
fn subm32(a: u32, b: u32, q32: u32) -> u32 {
    let d = a.wrapping_sub(b);
    d.min(d.wrapping_add(q32))
}

/// lo + 2^32 hi (lo, hi < 2^38) reduced to < 2^49 (K9's recomb).
#[inline(always)]
fn recomb(lo: u64, hi: u64, c32: u64) -> u64 {
    lo + c32 * (hi & M32) + ((c32 * (hi >> 32)) << 32)
}

/// One base-field product a*b (both canonical) reduced to canonical.
#[inline(always)]
fn mulm(a: u32, b: u32, c31: u64, q32: u32) -> u32 {
    let p = a as u64 * b as u64; // < 2^62
    canon32(fold31(fold31(p, c31), c31), q32)
}

impl SubExt {
    pub fn new(kf: &KField, c: usize) -> SubExt {
        assert!(c >= 1 && K_DEG % c == 0, "E_c needs c | 16");
        let q = kf.zq.q;
        assert!(q > (1u64 << 30) && q < (1u64 << 31), "E_c kernels need the q31 gate");
        let c31 = (1u64 << 31) % q;
        assert!(c31 < 1024, "E_c kernels need 2^31 mod q < 1024 (the K9 gate)");
        SubExt { c, stride: K_DEG / c, q, s: kf.s, c31, c32: 2 * c31, q32: q as u32 }
    }

    pub fn zero(&self) -> EElem {
        vec![0u32; self.c]
    }

    pub fn one(&self) -> EElem {
        self.embed(1)
    }

    pub fn embed(&self, x: u64) -> EElem {
        let mut e = self.zero();
        e[0] = (x % self.q) as u32;
        e
    }

    pub fn is_zero(&self, a: &EElem) -> bool {
        a.iter().all(|&x| x == 0)
    }

    /// The K-element (coordinates at stride 16/c) — the transcript / oracle
    /// encoding.
    pub fn to_k(&self, a: &EElem) -> KElem {
        let mut k = vec![0u64; K_DEG];
        for (i, &x) in a.iter().enumerate() {
            k[i * self.stride] = x as u64;
        }
        k
    }

    /// The E_c element of a K-element that lies in the subfield (None if any
    /// off-stride coordinate is nonzero).
    pub fn from_k(&self, k: &KElem) -> Option<EElem> {
        let mut e = self.zero();
        for (j, &x) in k.iter().enumerate() {
            if j % self.stride == 0 {
                e[j / self.stride] = x as u32;
            } else if x != 0 {
                return None;
            }
        }
        Some(e)
    }

    pub fn add(&self, a: &EElem, b: &EElem) -> EElem {
        a.iter().zip(b.iter()).map(|(&x, &y)| addm32(x, y, self.q32)).collect()
    }

    pub fn sub(&self, a: &EElem, b: &EElem) -> EElem {
        a.iter().zip(b.iter()).map(|(&x, &y)| subm32(x, y, self.q32)).collect()
    }

    pub fn neg(&self, a: &EElem) -> EElem {
        a.iter().map(|&x| if x == 0 { 0 } else { self.q32 - x }).collect()
    }

    /// Scale by a base-field canonical scalar.
    pub fn scale(&self, s: u32, a: &EElem) -> EElem {
        a.iter().map(|&x| mulm(x, s, self.c31, self.q32)).collect()
    }

    /// E x E: schoolbook c^2 products in split planes, one reduction per
    /// coordinate with the Z^c = s0 fold (the K9 red_block discipline).
    pub fn mul(&self, a: &EElem, b: &EElem) -> EElem {
        let c = self.c;
        let mut lo = vec![0u64; 2 * c - 1];
        let mut hi = vec![0u64; 2 * c - 1];
        for i in 0..c {
            for j in 0..c {
                let p = a[i] as u64 * b[j] as u64;
                lo[i + j] += p & M32;
                hi[i + j] += p >> 32;
            }
        }
        let mut out = vec![0u32; c];
        self.red_planes_scalar(&lo, &hi, &mut out);
        out
    }

    /// Reduce 2c-1 split planes (<= 2 products per term class: lo, hi < 2^38)
    /// to c canonical coordinates: out_t = w_t + s0 * red(w_{t+c}).
    #[inline(always)]
    fn red_planes_scalar(&self, lo: &[u64], hi: &[u64], out: &mut [u32]) {
        let c = self.c;
        for t in 0..c {
            let h = if t + c < 2 * c - 1 {
                let w = recomb(lo[t + c], hi[t + c], self.c32);
                canon32(fold31(fold31(w, self.c31), self.c31), self.q32) as u64
            } else {
                0
            };
            let w = recomb(lo[t], hi[t], self.c32);
            let v = w + self.s * h; // < 2^49 + 2^62
            out[t] = canon32(fold31(fold31(v, self.c31), self.c31), self.q32);
        }
    }

    /// Fermat inversion through K (the inverse of a subfield element lies in
    /// the subfield).
    pub fn inv(&self, kf: &KField, a: &EElem) -> EElem {
        let k = kf.inv(&self.to_k(a));
        self.from_k(&k).expect("inverse of a subfield element is in the subfield")
    }

    /// Uniform E_c element: c rejection-free base draws (for c = 16 exactly
    /// KField::uniform's 16 draws in order).
    pub fn uniform(&self, reader: &mut XofReader) -> EElem {
        (0..self.c).map(|_| reader.next_field(self.q) as u32).collect()
    }

    /// Wire bytes of one E_c element (4 B per canonical coordinate).
    pub fn wire_bytes(&self) -> usize {
        4 * self.c
    }

    /// Draw a challenge from the transcript: the same XOF position and the
    /// same absorb bytes as `LkpTranscript::challenge_k` (so at c = 16 the
    /// transcript is byte-identical to the K path).
    pub fn challenge(&self, kf: &KField, tr: &mut LkpTranscript) -> EElem {
        let mut reader = XofReader::new("lkp-chal", &[&tr.state()]);
        let e = self.uniform(&mut reader);
        tr.absorb("chal", &kf.bytes(&self.to_k(&e)));
        e
    }

    /// Absorb E_c elements with the house K encoding under `label`.
    pub fn absorb(&self, kf: &KField, tr: &mut LkpTranscript, label: &str, elems: &[EElem]) {
        let ks: Vec<KElem> = elems.iter().map(|e| self.to_k(e)).collect();
        tr.absorb_k(kf, label, &ks);
    }

    /// Lagrange evaluation of a round polynomial (evals at nodes 0..d) at r
    /// (integer node denominators inverted in the base field, as
    /// sumcheck::lagrange_eval).
    pub fn lagrange_eval(&self, kf: &KField, evals: &[EElem], r: &EElem) -> EElem {
        let d = evals.len() - 1;
        let zq = &kf.zq;
        let mut acc = self.zero();
        for i in 0..=d {
            let mut den: i64 = 1;
            for j in 0..=d {
                if j != i {
                    den *= i as i64 - j as i64;
                }
            }
            let mut num = self.one();
            for j in 0..=d {
                if j != i {
                    num = self.mul(&num, &self.sub(r, &self.embed(j as u64)));
                }
            }
            let coeff = zq.inv(zq.to_mod(den)) as u32;
            acc = self.add(&acc, &self.mul(&self.scale(coeff, &num), &evals[i]));
        }
        acc
    }

    /// eq(rho_t, X) = (1 - rho_t) + X (2 rho_t - 1) for an integer node X.
    fn eq_node(&self, rho_t: &EElem, x: u64) -> EElem {
        let one = self.one();
        let a = self.sub(&one, rho_t);
        let b = self.sub(rho_t, &a); // 2 rho - 1
        self.add(&a, &self.scale((x % self.q) as u32, &b))
    }

    /// eq(a, b) over E_c points.
    pub fn eq_point(&self, a: &[EElem], b: &[EElem]) -> EElem {
        assert_eq!(a.len(), b.len());
        let one = self.one();
        let mut acc = one.clone();
        for (x, y) in a.iter().zip(b.iter()) {
            let both1 = self.mul(x, y);
            let both0 = self.mul(&self.sub(&one, x), &self.sub(&one, y));
            acc = self.mul(&acc, &self.add(&both1, &both0));
        }
        acc
    }
}

// ---------------------------------------------------------------------------
// Lane-blocked E_c tables (8 lanes per block, coordinate-major inside the
// block: coordinate j of lane l at blk*c*KL + j*KL + l).

pub struct ETab {
    pub n: usize,
    pub c: usize,
    pub d: Vec<u32>,
}

impl ETab {
    fn blk_words(c: usize) -> usize {
        c * KL
    }

    /// n elements, zero-filled, capacity padded to whole PAIR-blocks (16
    /// elements) so the block kernels never see a partial block (the pad
    /// lanes are exact zeros; every kernel below maps zeros to zeros).
    pub fn zeroed(n: usize, c: usize) -> ETab {
        let nblk = n.div_ceil(2 * KL) * 2;
        ETab { n, c, d: vec![0u32; nblk * ETab::blk_words(c)] }
    }

    #[inline(always)]
    pub fn get(&self, i: usize) -> EElem {
        let bw = ETab::blk_words(self.c);
        let base = (i / KL) * bw + (i % KL);
        (0..self.c).map(|j| self.d[base + j * KL]).collect()
    }

    #[inline(always)]
    pub fn set(&mut self, i: usize, e: &EElem) {
        let bw = ETab::blk_words(self.c);
        let base = (i / KL) * bw + (i % KL);
        for j in 0..self.c {
            self.d[base + j * KL] = e[j];
        }
    }
}

/// Deinterleave the element pairs (2i, 2i+1) of pair-block m of an E-table
/// (source blocks 2m, 2m+1) into even / odd lane-blocks (lane l = pair l).
#[inline(always)]
fn e_deint_pair(c: usize, src: &[u32], m: usize, t0: &mut [u32], t1: &mut [u32]) {
    let bw = c * KL;
    let b0 = &src[(2 * m) * bw..(2 * m) * bw + bw];
    let b1 = &src[(2 * m + 1) * bw..(2 * m + 1) * bw + bw];
    for j in 0..c {
        for l in 0..4 {
            t0[j * KL + l] = b0[j * KL + 2 * l];
            t1[j * KL + l] = b0[j * KL + 2 * l + 1];
            t0[j * KL + 4 + l] = b1[j * KL + 2 * l];
            t1[j * KL + 4 + l] = b1[j * KL + 2 * l + 1];
        }
    }
}

/// The base-table analogue: 16 consecutive u32 -> even / odd lanes.
#[inline(always)]
fn b_deint_pair(src: &[u32], m: usize, t0: &mut [u32; KL], t1: &mut [u32; KL]) {
    let s = &src[16 * m..16 * m + 16];
    for l in 0..KL {
        t0[l] = s[2 * l];
        t1[l] = s[2 * l + 1];
    }
}

/// E x E lane MAC into split planes ((2c-1) x KL each): planes[t] +=
/// sum_{i+j=t} a_i b_j per lane.
#[inline(always)]
pub(crate) fn e_mac(c: usize, a: &[u32], b: &[u32], lo: &mut [u64], hi: &mut [u64]) {
    for i in 0..c {
        for j in 0..c {
            let t = i + j;
            for l in 0..KL {
                let p = a[i * KL + l] as u64 * b[j * KL + l] as u64;
                lo[t * KL + l] += p & M32;
                hi[t * KL + l] += p >> 32;
            }
        }
    }
}

/// E x base lane MAC into split planes: planes[j] += a_j * f per lane.
#[inline(always)]
pub(crate) fn e_mac_base(c: usize, a: &[u32], f: &[u32; KL], lo: &mut [u64], hi: &mut [u64]) {
    for j in 0..c {
        for l in 0..KL {
            let p = a[j * KL + l] as u64 * f[l] as u64;
            lo[j * KL + l] += p & M32;
            hi[j * KL + l] += p >> 32;
        }
    }
}

/// E x broadcast-E lane MAC (the fold's fixed operand r).
#[inline(always)]
pub(crate) fn e_mac_fixed(c: usize, a: &[u32], r: &[u32], lo: &mut [u64], hi: &mut [u64]) {
    for i in 0..c {
        for j in 0..c {
            let t = i + j;
            let rj = r[j] as u64;
            for l in 0..KL {
                let p = a[i * KL + l] as u64 * rj;
                lo[t * KL + l] += p & M32;
                hi[t * KL + l] += p >> 32;
            }
        }
    }
}

/// base x broadcast-E lane MAC (the first fold of a base table).
#[inline(always)]
pub(crate) fn e_mac_base_fixed(c: usize, a: &[u32; KL], r: &[u32], lo: &mut [u64], hi: &mut [u64]) {
    for j in 0..c {
        let rj = r[j] as u64;
        for l in 0..KL {
            let p = a[l] as u64 * rj;
            lo[j * KL + l] += p & M32;
            hi[j * KL + l] += p >> 32;
        }
    }
}

/// Reduce (2c-1) x KL split planes (<= 2 products per term class) to a
/// canonical E lane-block, folding Z^c = s0.
#[inline(always)]
fn e_red_block(ext: &SubExt, lo: &[u64], hi: &[u64], out: &mut [u32]) {
    let c = ext.c;
    let (c31, c32, s, q32) = (ext.c31, ext.c32, ext.s, ext.q32);
    let mut h = [0u32; 16 * KL];
    for t in 0..c - 1 {
        for l in 0..KL {
            let idx = (t + c) * KL + l;
            let w = recomb(lo[idx], hi[idx], c32);
            h[t * KL + l] = canon32(fold31(fold31(w, c31), c31), q32);
        }
    }
    for t in 0..c {
        for l in 0..KL {
            let idx = t * KL + l;
            let w = recomb(lo[idx], hi[idx], c32);
            let v = if t < c - 1 { w + s * h[t * KL + l] as u64 } else { w };
            out[t * KL + l] = canon32(fold31(fold31(v, c31), c31), q32);
        }
    }
}

/// Finalize a persistent lazy node accumulator ((2c-1) x KL split planes,
/// lanes summed, u128 exact) to one canonical E element.
fn e_finalize(ext: &SubExt, lo: &[u64], hi: &[u64]) -> EElem {
    let c = ext.c;
    let q = ext.q as u128;
    let s = ext.s as u128;
    let wide: Vec<u128> = (0..2 * c - 1)
        .map(|t| {
            let mut v: u128 = 0;
            for l in 0..KL {
                v += lo[t * KL + l] as u128 + ((hi[t * KL + l] as u128) << 32);
            }
            v
        })
        .collect();
    (0..c)
        .map(|t| {
            let h = if t + c < 2 * c - 1 { wide[t + c] % q } else { 0 };
            ((wide[t] + s * h) % q) as u32
        })
        .collect()
}

// ---------------------------------------------------------------------------
// S1 (b): the booleanity / digit-alphabet + recomposition zero-check.

/// One column's committed data as the prover reads it (canonical residues).
pub struct ZcRangeInstance<'a> {
    pub n_log2: usize,
    /// Digit base bits: 1 (bit planes {0,1}) or 2 (balanced base-4 {-2..1}).
    pub e0: u32,
    /// The digit planes (w of them), each 2^n canonical residues.
    pub planes: &'a [Vec<u32>],
    /// The remainder values, 2^n canonical residues.
    pub rem: &'a [u32],
}

impl ZcRangeInstance<'_> {
    pub fn w(&self) -> usize {
        self.planes.len()
    }
    /// The digit alphabet as canonical residues.
    pub fn alphabet(&self, q: u64) -> Vec<u32> {
        let (lo, hi) = super::digits::alphabet(self.e0);
        (lo..=hi).map(|a| (if a < 0 { (a + q as i64) as u64 } else { a as u64 }) as u32).collect()
    }
    /// deg_f = alphabet size (the per-plane constraint prod_a (d - a)).
    pub fn deg_f(&self) -> usize {
        super::digits::alphabet_rows(self.e0)
    }
}

pub struct ZcRangeProof {
    pub c: usize,
    /// Per round the shipped nodes g_t(0..=deg_f + 1).
    pub rounds: Vec<Vec<EElem>>,
    /// The final table values (planes then rem) at the point — the MLE
    /// claims an eval proof would open.
    pub finals: Vec<EElem>,
}

#[derive(Default, Clone, Debug)]
pub struct ZcRangeStats {
    pub rounds: usize,
    pub nodes_computed: usize,
    pub macs_round: u64,
    pub macs_fold: u64,
    pub macs_eq: u64,
    pub secs_eq: f64,
    pub secs_round: f64,
    pub secs_fold: f64,
    pub secs_total: f64,
    pub wire_bytes: usize,
}

impl ZcRangeStats {
    pub fn macs_total(&self) -> u64 {
        self.macs_round + self.macs_fold + self.macs_eq
    }
}

/// A prover table: base residues until the first fold, E_c after.
enum ZTab {
    Base(Vec<u32>),
    Ext(ETab),
}

/// The eq table over rho at ELEMENT granularity: eq[x] = A[x_low] * B[x_high]
/// (two half tables; N E-mults, threaded, positional).
fn build_eq_full(ext: &SubExt, rho: &[EElem]) -> ETab {
    let n = rho.len();
    let hl = n / 2;
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
    let size = 1usize << n;
    let mut t = ETab::zeroed(size, ext.c);
    let c = ext.c;
    let bw = c * KL;
    let nblk = size / KL;
    let mask = (1usize << hl) - 1;
    let ext_c = *ext;
    let fill = |m0: usize, dst: &mut [u32]| {
        let mut ab = vec![0u32; bw];
        let mut bb = vec![0u32; bw];
        let mut lo = vec![0u64; (2 * c - 1) * KL];
        let mut hi = vec![0u64; (2 * c - 1) * KL];
        for (mi, blk) in dst.chunks_mut(bw).enumerate() {
            let m = m0 + mi;
            for l in 0..KL {
                let x = m * KL + l;
                let ea = &a[x & mask];
                let eb = &b[x >> hl];
                for j in 0..c {
                    ab[j * KL + l] = ea[j];
                    bb[j * KL + l] = eb[j];
                }
            }
            for v in lo.iter_mut() {
                *v = 0;
            }
            for v in hi.iter_mut() {
                *v = 0;
            }
            super::ec_kernel::mac_auto(c, &ab, &bb, &mut lo, &mut hi);
            e_red_block(&ext_c, &lo, &hi, blk);
        }
    };
    if size >= KL {
        let d = &mut t.d[..nblk * bw];
        let chunk = 256usize;
        if k9_threads() > 1 && nblk > chunk {
            k9_pooled_pub(|| {
                use rayon::prelude::*;
                d.par_chunks_mut(chunk * bw).enumerate().for_each(|(ci, dc)| fill(ci * chunk, dc));
            });
        } else {
            fill(0, d);
        }
    } else {
        for x in 0..size {
            let v = ext.mul(&a[x & mask], &b[x >> hl]);
            t.set(x, &v);
        }
    }
    t
}

/// Even-lane compaction: out[i] = t[2i] (the eq table over the unbound
/// variables after a round — no arithmetic).
fn compact_even(c: usize, t: &ETab) -> ETab {
    let n_out = t.n / 2;
    let mut out = ETab::zeroed(n_out, c);
    let bw = c * KL;
    let nblk_out = n_out.div_ceil(KL);
    let mut a = vec![0u32; bw];
    let mut b = vec![0u32; bw];
    for m in 0..nblk_out {
        e_deint_pair(c, &t.d, m, &mut a, &mut b);
        out.d[m * bw..(m + 1) * bw].copy_from_slice(&a);
    }
    out
}

/// Fold an E table with r: out[i] = t[2i] + r (t[2i+1] - t[2i]) (threaded,
/// positional; c^2 MACs per output element).
fn fold_ext(ext: &SubExt, t: &ETab, r: &EElem) -> ETab {
    let c = ext.c;
    let n_out = t.n / 2;
    let mut out = ETab::zeroed(n_out, c);
    let bw = c * KL;
    let nblk_out = n_out.div_ceil(KL);
    let ext_c = *ext;
    let q32 = ext.q32;
    let body = |m0: usize, dst: &mut [u32]| {
        let mut a = vec![0u32; bw];
        let mut b = vec![0u32; bw];
        let mut lo = vec![0u64; (2 * c - 1) * KL];
        let mut hi = vec![0u64; (2 * c - 1) * KL];
        for (mi, blk) in dst.chunks_mut(bw).enumerate() {
            let m = m0 + mi;
            e_deint_pair(c, &t.d, m, &mut a, &mut b);
            for x in 0..bw {
                b[x] = subm32(b[x], a[x], q32);
            }
            for v in lo.iter_mut() {
                *v = 0;
            }
            for v in hi.iter_mut() {
                *v = 0;
            }
            // planes = a (as a degree-0 term) + r * d
            for x in 0..bw {
                lo[x] += a[x] as u64;
            }
            super::ec_kernel::mac_fixed_auto(c, &b, r, &mut lo, &mut hi);
            e_red_block(&ext_c, &lo, &hi, blk);
        }
    };
    let d = &mut out.d[..nblk_out * bw];
    let chunk = 256usize;
    if k9_threads() > 1 && nblk_out > chunk {
        k9_pooled_pub(|| {
            use rayon::prelude::*;
            d.par_chunks_mut(chunk * bw).enumerate().for_each(|(ci, dc)| body(ci * chunk, dc));
        });
    } else {
        body(0, d);
    }
    out
}

/// Fold a BASE table with r in E: out[i] = t[2i] + r (t[2i+1] - t[2i]) — c
/// MACs per output element; the output is an E table.
fn fold_base(ext: &SubExt, t: &[u32], r: &EElem) -> ETab {
    let c = ext.c;
    let n_out = t.len() / 2;
    let mut out = ETab::zeroed(n_out, c);
    let bw = c * KL;
    let nblk_out = n_out.div_ceil(KL);
    let ext_c = *ext;
    let q32 = ext.q32;
    // Source padded to whole pair-blocks (zeros).
    let mut src = t.to_vec();
    src.resize(nblk_out * 2 * KL, 0);
    let body = |m0: usize, dst: &mut [u32]| {
        let mut a = [0u32; KL];
        let mut b = [0u32; KL];
        let mut lo = vec![0u64; (2 * c - 1) * KL];
        let mut hi = vec![0u64; (2 * c - 1) * KL];
        for (mi, blk) in dst.chunks_mut(bw).enumerate() {
            let m = m0 + mi;
            b_deint_pair(&src, m, &mut a, &mut b);
            for l in 0..KL {
                b[l] = subm32(b[l], a[l], q32);
            }
            for v in lo.iter_mut() {
                *v = 0;
            }
            for v in hi.iter_mut() {
                *v = 0;
            }
            for l in 0..KL {
                lo[l] += a[l] as u64;
            }
            super::ec_kernel::mac_base_fixed_auto(c, &b, r, &mut lo, &mut hi);
            e_red_block(&ext_c, &lo, &hi, blk);
        }
    };
    let d = &mut out.d[..nblk_out * bw];
    let chunk = 256usize;
    if k9_threads() > 1 && nblk_out > chunk {
        k9_pooled_pub(|| {
            use rayon::prelude::*;
            d.par_chunks_mut(chunk * bw).enumerate().for_each(|(ci, dc)| body(ci * chunk, dc));
        });
    } else {
        body(0, d);
    }
    out
}

/// The per-round node sums H_t(X) = sum_i eq_pairs[i] * (per-constraint
/// value at X), for X in `nodes`, returned per constraint (w planes then the
/// recomposition) so the betas apply once per round. Threaded over pair-block
/// chunks with per-chunk lazy planes summed in index order.
#[allow(clippy::too_many_arguments)]
fn round_sums(
    ext: &SubExt,
    tabs: &[ZTab],
    eq_pairs: &ETab,
    npairs: usize,
    nodes: &[u64],
    alphabet: &[u32],
    e0: u32,
    stats: &mut ZcRangeStats,
) -> Vec<Vec<EElem>> {
    let c = ext.c;
    let w = tabs.len() - 1;
    let nn = nodes.len();
    let ncons = w + 1;
    let planes = (2 * c - 1) * KL;
    let acc_words = ncons * nn * planes;
    let nblk_pairs = npairs.div_ceil(KL);
    let deg_f = alphabet.len();
    // MAC accounting (per pair-block: 8 pairs).
    let base_round = matches!(tabs[0], ZTab::Base(_));
    let per_pair_node: u64 = if base_round {
        // per plane: 1 (node extrapolation) + (deg_f - 1) (f chain) + c
        // (eq x f, e_mac_base) + 1 (2^(e0 k) scaling into rec); rec row:
        // 1 (extrapolation) + c (eq x rec)
        (w as u64) * (deg_f as u64 + 1 + c as u64) + 1 + c as u64
    } else {
        // per table: c (node extrapolation, scalar x E); per plane: deg_f
        // E x E (c^2 each: f chain + eq x f) + c (2^(e0 k) scaling); rec
        // row: c^2 (eq x rec)
        (w as u64 + 1) * c as u64
            + (w as u64) * (deg_f as u64 * (c * c) as u64 + c as u64)
            + (c * c) as u64
    };
    stats.macs_round += per_pair_node * (nblk_pairs * KL) as u64 * nn as u64;
    stats.nodes_computed += nn;
    let ext_c = *ext;
    let alpha_v: Vec<u32> = alphabet.to_vec();
    let body = |m0: usize, m1: usize, lo: &mut [u64], hi: &mut [u64]| {
        let bw = c * KL;
        let q32 = ext_c.q32;
        let c31 = ext_c.c31;
        // staging
        let mut eqb = vec![0u32; bw];
        let mut ea = vec![0u32; bw]; // E table even lanes
        let mut eb = vec![0u32; bw]; // E table odd lanes
        let mut ev = vec![0u32; bw]; // extrapolated value at X
        let mut ef = vec![0u32; bw]; // f(v) (E)
        let mut et = vec![0u32; bw]; // temp
        let mut erec = vec![0u32; bw]; // recomposition accumulator (E)
        let mut plo = vec![0u64; planes];
        let mut phi = vec![0u64; planes];
        let mut ba = [0u32; KL];
        let mut bb = [0u32; KL];
        let mut bv = [0u32; KL];
        let mut bf = [0u32; KL];
        let mut brec = [0u32; KL];
        // 2^(e0 k) as canonical residues
        let pow2: Vec<u32> = (0..w).map(|k| ((1u128 << (e0 as usize * k)) % ext_c.q as u128) as u32).collect();
        // [UPERF3-DD rung 4] the fused base-round fast path: one
        // attributed AVX2 call per (block, node) — deinterleave,
        // extrapolation, f chain, eq x f MAC and recomposition
        // register-resident. Values identical to the loop below (the
        // battery digest is the gate); ZK_EC_SCALAR=1 forces the loop.
        #[cfg(target_arch = "x86_64")]
        if base_round && super::ec_kernel::avx2_active() {
            let bp: Vec<&[u32]> = tabs
                .iter()
                .map(|t| {
                    let ZTab::Base(v) = t else { unreachable!() };
                    v.as_slice()
                })
                .collect();
            for m in m0..m1 {
                let eq_blk = &eq_pairs.d[m * bw..(m + 1) * bw];
                for (ni, &x) in nodes.iter().enumerate() {
                    let xr = (x % ext_c.q) as u32;
                    super::ec_kernel::base_node_fused(
                        &bp, m, xr, &alpha_v, &pow2, eq_blk, c, nn, ni, planes, c31, q32, lo, hi,
                    );
                }
            }
            return;
        }
        for m in m0..m1 {
            let eq_blk = &eq_pairs.d[m * bw..(m + 1) * bw];
            eqb.copy_from_slice(eq_blk);
            for (ni, &x) in nodes.iter().enumerate() {
                let xr = (x % ext_c.q) as u32;
                if base_round {
                    // recomposition at X: rem(X) - sum 2^(e0 k) d_k(X)
                    for l in 0..KL {
                        brec[l] = 0;
                    }
                    for (k, tab) in tabs.iter().enumerate() {
                        let ZTab::Base(t) = tab else { unreachable!() };
                        b_deint_pair(t, m, &mut ba, &mut bb);
                        super::ec_kernel::extrap_lanes(&ba, &bb, xr, c31, q32, &mut bv);
                        if k < w {
                            // f = prod_a (v - a)
                            super::ec_kernel::f_chain_lanes(&bv, &alpha_v, c31, q32, &mut bf);
                            let sl = (k * nn + ni) * planes;
                            super::ec_kernel::mac_base_auto(c, &eqb, &bf, &mut lo[sl..sl + planes], &mut hi[sl..sl + planes]);
                            super::ec_kernel::rec_sub_scaled(&mut brec, pow2[k], &bv, c31, q32);
                        } else {
                            super::ec_kernel::rec_add(&mut brec, &bv, q32);
                            let sl = (w * nn + ni) * planes;
                            super::ec_kernel::mac_base_auto(c, &eqb, &brec, &mut lo[sl..sl + planes], &mut hi[sl..sl + planes]);
                        }
                    }
                } else {
                    for v in erec.iter_mut() {
                        *v = 0;
                    }
                    for (k, tab) in tabs.iter().enumerate() {
                        let ZTab::Ext(t) = tab else { unreachable!() };
                        e_deint_pair(c, &t.d, m, &mut ea, &mut eb);
                        super::ec_kernel::extrap_lanes(&ea, &eb, xr, c31, q32, &mut ev);
                        if k < w {
                            // f = prod_a (v - a): (deg_f - 1) E x E products
                            for i in 0..bw {
                                ef[i] = ev[i];
                            }
                            for l in 0..KL {
                                ef[l] = subm32(ef[l], alpha_v[0], q32);
                            }
                            for &a in &alpha_v[1..] {
                                for i in 0..bw {
                                    et[i] = ev[i];
                                }
                                for l in 0..KL {
                                    et[l] = subm32(et[l], a, q32);
                                }
                                for v in plo.iter_mut() {
                                    *v = 0;
                                }
                                for v in phi.iter_mut() {
                                    *v = 0;
                                }
                                super::ec_kernel::mac_auto(c, &ef, &et, &mut plo, &mut phi);
                                e_red_block(&ext_c, &plo, &phi, &mut ef);
                            }
                            let sl = (k * nn + ni) * planes;
                            super::ec_kernel::mac_auto(c, &eqb, &ef, &mut lo[sl..sl + planes], &mut hi[sl..sl + planes]);
                            super::ec_kernel::rec_sub_scaled(&mut erec, pow2[k], &ev, c31, q32);
                        } else {
                            super::ec_kernel::rec_add(&mut erec, &ev, q32);
                            let sl = (w * nn + ni) * planes;
                            super::ec_kernel::mac_auto(c, &eqb, &erec, &mut lo[sl..sl + planes], &mut hi[sl..sl + planes]);
                        }
                    }
                }
            }
        }
    };
    let t = k9_threads();
    let chunk_blk = 64usize;
    let n_chunks = if t <= 1 || nblk_pairs < 2 * chunk_blk { 1 } else { (t * 8).min(nblk_pairs.div_ceil(chunk_blk)).max(1) };
    let mut acc_lo = vec![0u64; acc_words];
    let mut acc_hi = vec![0u64; acc_words];
    if n_chunks <= 1 {
        body(0, nblk_pairs, &mut acc_lo, &mut acc_hi);
    } else {
        let per = nblk_pairs.div_ceil(n_chunks);
        let partials: Vec<(Vec<u64>, Vec<u64>)> = k9_pooled_pub(|| {
            use rayon::prelude::*;
            (0..n_chunks)
                .into_par_iter()
                .map(|ci| {
                    let m0 = (ci * per).min(nblk_pairs);
                    let m1 = ((ci + 1) * per).min(nblk_pairs);
                    let mut lo = vec![0u64; acc_words];
                    let mut hi = vec![0u64; acc_words];
                    if m1 > m0 {
                        body(m0, m1, &mut lo, &mut hi);
                    }
                    (lo, hi)
                })
                .collect()
        });
        for (lo, hi) in &partials {
            for i in 0..acc_words {
                acc_lo[i] += lo[i];
                acc_hi[i] += hi[i];
            }
        }
    }
    (0..ncons)
        .map(|k| {
            (0..nn)
                .map(|ni| {
                    let sl = (k * nn + ni) * planes;
                    e_finalize(ext, &acc_lo[sl..sl + planes], &acc_hi[sl..sl + planes])
                })
                .collect()
        })
        .collect()
}

/// Exact extrapolation of a degree-d polynomial from its values at nodes
/// 0..=d to node d+1: H(d+1) = sum_i (-1)^(d-i) C(d+1, i) H(i).
fn extrapolate_next(ext: &SubExt, h: &[EElem]) -> EElem {
    let d = h.len() - 1;
    let mut acc = ext.zero();
    let mut binom: i128 = 1; // C(d+1, 0)
    for (i, hv) in h.iter().enumerate() {
        let sign_neg = (d - i) % 2 == 1;
        let coeff = ((binom % ext.q as i128) + ext.q as i128) as u128 % ext.q as u128;
        let term = ext.scale(coeff as u32, hv);
        acc = if sign_neg { ext.sub(&acc, &term) } else { ext.add(&acc, &term) };
        binom = binom * (d as i128 + 1 - i as i128) / (i as i128 + 1);
    }
    acc
}

/// PROVE: the zero-check of `inst` under (rho, betas) with challenges in
/// E_c. `betas` = w + 1 RLC coefficients (planes, then the recomposition).
/// Returns (proof, the final point, the counters).
pub fn zc_range_prove(
    kf: &KField,
    ext: &SubExt,
    inst: &ZcRangeInstance,
    rho: &[EElem],
    betas: &[EElem],
    tr: &mut LkpTranscript,
) -> (ZcRangeProof, Vec<EElem>, ZcRangeStats) {
    let t_all = std::time::Instant::now();
    let n = inst.n_log2;
    assert!(n >= 4, "zc_range_prove needs n >= 4 (one full pair-block)");
    assert_eq!(rho.len(), n);
    let w = inst.w();
    assert_eq!(betas.len(), w + 1);
    let size = 1usize << n;
    assert!(inst.planes.iter().all(|p| p.len() == size) && inst.rem.len() == size);
    let alphabet = inst.alphabet(ext.q);
    let deg_f = alphabet.len();
    let nodes: Vec<u64> = (0..=deg_f as u64).filter(|&x| x != 1).collect();
    let mut stats = ZcRangeStats::default();
    let c = ext.c;
    // eq at pair granularity: eq_full compacted once (eq_full[2i]).
    let t0 = std::time::Instant::now();
    let eq_full = build_eq_full(ext, rho);
    stats.macs_eq += (size as u64) * (c * c) as u64;
    let mut eq_pairs = compact_even(c, &eq_full);
    drop(eq_full);
    stats.secs_eq += t0.elapsed().as_secs_f64();
    // tables: planes then rem, base until the first fold
    let mut tabs: Vec<ZTab> = inst.planes.iter().map(|p| ZTab::Base(p.clone())).collect();
    tabs.push(ZTab::Base(inst.rem.to_vec()));
    let mut rounds: Vec<Vec<EElem>> = Vec::with_capacity(n);
    let mut point: Vec<EElem> = Vec::with_capacity(n);
    let one = ext.one();
    let mut c_run = ext.zero(); // the claimed sum: 0
    let mut p_t = one.clone(); // prod_{s<t} eq(rho_s, r_s)
    let mut d_t = one.clone(); // prod_{s<=t} (1 - rho_s)
    let mut cur = size;
    for t in 0..n {
        let npairs = cur / 2;
        d_t = ext.mul(&d_t, &ext.sub(&one, &rho[t]));
        assert!(!ext.is_zero(&d_t) && !ext.is_zero(&rho[t]), "degenerate rho (restart guard)");
        let k_t = ext.mul(&p_t, &ext.inv(kf, &d_t));
        let tr0 = std::time::Instant::now();
        let sums = round_sums(ext, &tabs, &eq_pairs, npairs, &nodes, &alphabet, inst.e0, &mut stats);
        // H_t(X) = sum_k beta_k * sums[k][X]
        let mut h: Vec<EElem> = vec![ext.zero(); nodes.len()];
        for (k, bk) in betas.iter().enumerate() {
            for (ni, hv) in h.iter_mut().enumerate() {
                *hv = ext.add(hv, &ext.mul(bk, &sums[k][ni]));
            }
        }
        // g(X) = K_t eq(rho_t, X) H(X) at the computed nodes; g(1) = C - g(0);
        // H(1) = g(1) / (K_t rho_t); H(deg_f + 1) by extrapolation.
        let deg = deg_f + 1;
        let mut g = vec![ext.zero(); deg + 1];
        let mut hfull = vec![ext.zero(); deg_f + 1];
        for (ni, &x) in nodes.iter().enumerate() {
            hfull[x as usize] = h[ni].clone();
            g[x as usize] = ext.mul(&ext.mul(&k_t, &ext.eq_node(&rho[t], x)), &h[ni]);
        }
        g[1] = ext.sub(&c_run, &g[0]);
        let k_rho = ext.mul(&k_t, &rho[t]);
        hfull[1] = ext.mul(&g[1], &ext.inv(kf, &k_rho));
        let h_last = extrapolate_next(ext, &hfull);
        g[deg] = ext.mul(&ext.mul(&k_t, &ext.eq_node(&rho[t], deg as u64)), &h_last);
        stats.secs_round += tr0.elapsed().as_secs_f64();
        stats.rounds += 1;
        stats.wire_bytes += (deg + 1) * ext.wire_bytes();
        ext.absorb(kf, tr, "ixf-round-poly", &g);
        let r = ext.challenge(kf, tr);
        c_run = ext.lagrange_eval(kf, &g, &r);
        // fold
        let tf0 = std::time::Instant::now();
        let mut ntabs = Vec::with_capacity(tabs.len());
        for tab in tabs.iter() {
            let nt = match tab {
                ZTab::Base(b) => {
                    stats.macs_fold += (npairs.div_ceil(KL) * KL) as u64 * c as u64;
                    fold_base(ext, b, &r)
                }
                ZTab::Ext(e) => {
                    stats.macs_fold += (npairs.div_ceil(KL) * KL) as u64 * (c * c) as u64;
                    fold_ext(ext, e, &r)
                }
            };
            ntabs.push(ZTab::Ext(nt));
        }
        tabs = ntabs;
        eq_pairs = compact_even(c, &eq_pairs);
        stats.secs_fold += tf0.elapsed().as_secs_f64();
        p_t = ext.mul(&p_t, &ext.eq_point(std::slice::from_ref(&rho[t]), std::slice::from_ref(&r)));
        rounds.push(g);
        point.push(r);
        cur /= 2;
    }
    let finals: Vec<EElem> = tabs
        .iter()
        .map(|tab| match tab {
            ZTab::Ext(e) => e.get(0),
            ZTab::Base(_) => unreachable!(),
        })
        .collect();
    stats.wire_bytes += finals.len() * ext.wire_bytes();
    stats.secs_total = t_all.elapsed().as_secs_f64();
    (ZcRangeProof { c, rounds, finals }, point, stats)
}

/// The zero-check's constraint value G at opened finals (planes then rem).
pub fn zc_range_g_of(ext: &SubExt, e0: u32, alphabet: &[u32], betas: &[EElem], finals: &[EElem]) -> EElem {
    let w = finals.len() - 1;
    let mut acc = ext.zero();
    let mut rec = finals[w].clone();
    for k in 0..w {
        let v = &finals[k];
        let mut f = ext.sub(v, &ext.embed(alphabet[0] as u64));
        for &a in &alphabet[1..] {
            f = ext.mul(&f, &ext.sub(v, &ext.embed(a as u64)));
        }
        acc = ext.add(&acc, &ext.mul(&betas[k], &f));
        let p2 = ((1u128 << (e0 as usize * k)) % ext.q as u128) as u32;
        rec = ext.sub(&rec, &ext.scale(p2, v));
    }
    ext.add(&acc, &ext.mul(&betas[w], &rec))
}

/// VERIFY the round chain and the final identity C == eq(rho, x*) *
/// G(finals). The finals are the MLE claims (in the protocol: opened by the
/// eval proof; in the spike: `zc_range_open_check`). Returns the point.
#[allow(clippy::too_many_arguments)]
pub fn zc_range_verify(
    kf: &KField,
    ext: &SubExt,
    n_log2: usize,
    e0: u32,
    w: usize,
    rho: &[EElem],
    betas: &[EElem],
    proof: &ZcRangeProof,
    tr: &mut LkpTranscript,
) -> Option<Vec<EElem>> {
    if proof.rounds.len() != n_log2 || proof.finals.len() != w + 1 || proof.c != ext.c {
        return None;
    }
    let deg_f = super::digits::alphabet_rows(e0);
    let deg = deg_f + 1;
    let mut c_run = ext.zero();
    let mut point = Vec::with_capacity(n_log2);
    for g in &proof.rounds {
        if g.len() != deg + 1 {
            return None;
        }
        if ext.add(&g[0], &g[1]) != c_run {
            return None;
        }
        ext.absorb(kf, tr, "ixf-round-poly", g);
        let r = ext.challenge(kf, tr);
        c_run = ext.lagrange_eval(kf, g, &r);
        point.push(r);
    }
    let (lo, hi) = super::digits::alphabet(e0);
    let alphabet: Vec<u32> =
        (lo..=hi).map(|a| (if a < 0 { (a + ext.q as i64) as u64 } else { a as u64 }) as u32).collect();
    let gval = zc_range_g_of(ext, e0, &alphabet, betas, &proof.finals);
    let expect = ext.mul(&ext.eq_point(rho, &point), &gval);
    if expect != c_run {
        return None;
    }
    Some(point)
}

/// MLE of a base table at an E point (fold order = variable 0 first).
pub fn base_mle_eval(ext: &SubExt, table: &[u32], point: &[EElem]) -> EElem {
    assert_eq!(table.len(), 1 << point.len());
    let mut cur = fold_base(ext, table, &point[0]);
    for r in &point[1..] {
        cur = fold_ext(ext, &cur, r);
    }
    cur.get(0)
}

/// The spike's stand-in for the eval proof: every final equals the MLE of
/// its table at the point.
pub fn zc_range_open_check(ext: &SubExt, inst: &ZcRangeInstance, point: &[EElem], finals: &[EElem]) -> bool {
    let w = inst.w();
    if finals.len() != w + 1 {
        return false;
    }
    for k in 0..w {
        if base_mle_eval(ext, &inst.planes[k], point) != finals[k] {
            return false;
        }
    }
    base_mle_eval(ext, inst.rem, point) == finals[w]
}

/// The K-field boxed ORACLE of the same zero-check (fold.rs
/// `ixf_sumcheck_prove` on boxed K tables with the RLC combine): for c = 16
/// its rounds / finals / transcript must be byte-identical to
/// `zc_range_prove`. Small sizes only (boxed tables).
pub fn zc_range_prove_oracle_k(
    kf: &KField,
    inst: &ZcRangeInstance,
    rho: &[KElem],
    betas: &[KElem],
    tr: &mut LkpTranscript,
) -> (SumcheckProof, Vec<KElem>) {
    let n = inst.n_log2;
    let size = 1usize << n;
    let w = inst.w();
    let (lo, hi) = super::digits::alphabet(inst.e0);
    let alphabet: Vec<KElem> = (lo..=hi).map(|a| kf.embed(kf.zq.to_mod(a))).collect();
    let mut tables: Vec<Vec<KElem>> = Vec::with_capacity(w + 2);
    tables.push(super::gkr::eq_table(kf, rho));
    for p in inst.planes {
        tables.push(p.iter().map(|&v| kf.embed(v as u64)).collect());
    }
    tables.push(inst.rem.iter().map(|&v| kf.embed(v as u64)).collect());
    assert!(tables.iter().all(|t| t.len() == size));
    let e0 = inst.e0;
    let deg = alphabet.len() + 1;
    let combine = |kf: &KField, v: &[KElem]| -> KElem {
        // v[0] = eq, v[1..=w] = planes, v[w+1] = rem
        let mut acc = kf.zero();
        let mut rec = v[w + 1].clone();
        for k in 0..w {
            let d = &v[1 + k];
            let mut f = kf.sub(d, &alphabet[0]);
            for a in &alphabet[1..] {
                f = kf.mul(&f, &kf.sub(d, a));
            }
            acc = kf.add(&acc, &kf.mul(&betas[k], &f));
            let p2 = ((1u128 << (e0 as usize * k)) % kf.zq.q as u128) as u64;
            rec = kf.sub(&rec, &kf.scale(p2, d));
        }
        acc = kf.add(&acc, &kf.mul(&betas[w], &rec));
        kf.mul(&v[0], &acc)
    };
    let degrees = vec![deg; n];
    super::fold::ixf_sumcheck_prove(kf, tables, &degrees, &combine, tr)
}

// ---------------------------------------------------------------------------
// S2 (b): the SiLU LogUp as ONE sumcheck with the committed helper h.

pub struct LogupSumcheckOut {
    pub proof: SumcheckProof,
    pub point: Vec<KElem>,
    /// sum_x h(x) — the witness-side fractional sum.
    pub h_sum: KElem,
    /// sum_j m_j / (alpha - t_j) — the table side (256 rows).
    pub table_sum: KElem,
    /// h(x*) and key(x*) recomputed from the (kept) tables — the claims an
    /// eval proof would open (spike stand-in).
    pub h_at_point: KElem,
    pub key_at_point: KElem,
    pub secs_h: f64,
    pub secs_tables: f64,
    pub secs_sumcheck: f64,
    pub secs_open: f64,
    pub kmuls_counted: u64,
    pub wire_bytes: usize,
    pub h_values: usize,
    pub h_raw_bytes: usize,
}

/// PROVE (honest prover): keys = fused (x, y) residue pairs, `table` = the
/// fused 256 rows, `mult` = the multiplicities per row; alpha, rho already
/// drawn. h_i = 1/(alpha - key_i) from the 256 row inverses (an off-table
/// key gets its own inverse — the tamper legs); the sumcheck runs on the
/// frozen packed Had prover with tables [eq, h, alpha - key, 1].
pub fn logup_sumcheck_prove(
    kf: &KField,
    keys: &[KElem],
    row_of: &[Option<usize>],
    table: &[KElem],
    mult: &[u64],
    alpha: &KElem,
    rho: &[KElem],
    tr: &mut LkpTranscript,
) -> LogupSumcheckOut {
    use super::fold::{IxfCombine, ixf_sumcheck_prove_packed};
    let n = rho.len();
    let size = 1usize << n;
    assert_eq!(keys.len(), size);
    assert!(kf.kern.is_some(), "the packed Had prover needs the bulk kernel");
    let t0 = std::time::Instant::now();
    let inv_rows: Vec<KElem> = table.iter().map(|t| kf.inv(&kf.sub(alpha, t))).collect();
    let mut h: Vec<KElem> = Vec::with_capacity(size);
    let mut h_sum = kf.zero();
    for (i, key) in keys.iter().enumerate() {
        let hi = match row_of[i] {
            Some(j) => inv_rows[j].clone(),
            None => kf.inv(&kf.sub(alpha, key)),
        };
        h_sum = kf.add(&h_sum, &hi);
        h.push(hi);
    }
    let mut table_sum = kf.zero();
    for (j, inv) in inv_rows.iter().enumerate() {
        table_sum = kf.add(&table_sum, &kf.scale(mult[j] % kf.zq.q, inv));
    }
    let secs_h = t0.elapsed().as_secs_f64();
    let t1 = std::time::Instant::now();
    let eq = kf.kt_eq_table_par(rho);
    let mut ht = KTab::zeroed(size);
    let mut at = KTab::zeroed(size);
    for i in 0..size {
        ht.set(i, &h[i]);
        at.set(i, &kf.sub(alpha, &keys[i]));
    }
    let ones = KTab::filled(size, &kf.one());
    let secs_tables = t1.elapsed().as_secs_f64();
    let degrees = vec![3usize; n];
    let t2 = std::time::Instant::now();
    let (proof, point) = ixf_sumcheck_prove_packed(kf, vec![eq, ht, at, ones], &degrees, IxfCombine::Had, tr);
    let secs_sumcheck = t2.elapsed().as_secs_f64();
    let t3 = std::time::Instant::now();
    let h_at_point = super::sumcheck::mle_eval(kf, &h, &point);
    let key_at_point = super::sumcheck::mle_eval(kf, keys, &point);
    let secs_open = t3.elapsed().as_secs_f64();
    // Counted K-mults: Had kernel = 2 per pair-term per node (4 nodes) + 4
    // folds per pair-term; sum of pair-terms over rounds = size; eq build
    // 2 * size; row inverses ~750 K-mults each.
    let kmuls_counted = (size as u64) * (4 * 2 + 4) + 2 * size as u64 + 750 * table.len() as u64;
    let wire_bytes = proof.rounds.iter().map(|r| r.len()).sum::<usize>() * 64 + proof.final_evals.len() * 64 + 2 * 64;
    LogupSumcheckOut {
        proof,
        point,
        h_sum,
        table_sum,
        h_at_point,
        key_at_point,
        secs_h,
        secs_tables,
        secs_sumcheck,
        secs_open,
        kmuls_counted,
        wire_bytes,
        h_values: size * K_DEG,
        h_raw_bytes: size * K_DEG * 4,
    }
}

/// VERIFY: the round chain against the claimed sum 0 (Had combine), the eq
/// and constant finals recomputed, h(x*) / key(x*) taken as the opened
/// claims, and the sum equality h_sum == table_sum (the LogUp identity —
/// the descent's root cross-check in sum form).
#[allow(clippy::too_many_arguments)]
pub fn logup_sumcheck_verify(
    kf: &KField,
    n: usize,
    alpha: &KElem,
    rho: &[KElem],
    out: &LogupSumcheckOut,
    tr: &mut LkpTranscript,
) -> (bool, bool) {
    use super::fold::{IxfCombine, ixf_sumcheck_verify};
    let degrees = vec![3usize; n];
    let combine = |kf: &KField, v: &[KElem]| IxfCombine::Had.eval(kf, v);
    let zero = kf.zero();
    let chain_ok = match ixf_sumcheck_verify(kf, &degrees, &zero, &out.proof, &combine, tr) {
        Some((point, _c)) => {
            let f = &out.proof.final_evals;
            point == out.point
                && f.len() == 4
                && f[0] == eq_eval(kf, rho, &point)
                && f[1] == out.h_at_point
                && f[2] == kf.sub(alpha, &out.key_at_point)
                && f[3] == kf.one()
        }
        None => false,
    };
    let sum_ok = out.h_sum == out.table_sum;
    (chain_ok, sum_ok)
}

// ---------------------------------------------------------------------------
// Structural counters for the frozen masked descent (S1/S2 (a)).

/// K-mults of ONE masked descent over `n_real` real trees (pads skipped
/// analytically) of the given depth with e_bits instance variables, on the
/// fused fast path as built (gkr_masked::masked_rounds_bulk +
/// kfield::round_g5_pair / fused_round_body): per layer j — the b-part eq
/// doubling (2 * 2^j) [+ n_real * 2^j E(e) scalings when e_bits > 0]; round 0
/// PL = p0 + lambda q0 over S = n_real 2^j elements; every evaluated node
/// (deg, skipping node 1) costs 3 K-mults per pair-term (PL*Q1, P1*Q0,
/// eq*wire); round 1's fused extract+fold 6 per state-1 element (4 folds +
/// PL_1 + eq); rounds >= 2 fold 5 tables. Returns (rounds kmuls, tree-build
/// kmuls incl. the c=2 checkpoint recompute at +2/3 of a build).
pub fn masked_descent_kmuls(depth: usize, e_bits: usize, n_real: usize) -> (u64, u64) {
    let mut total: u64 = 0;
    for j in 1..depth {
        let n_bvars = j + e_bits;
        let child_masked = j <= depth - 2;
        let degs = super::gkr_masked::sc_degrees(n_bvars, child_masked);
        let s = (n_real as u64) << j; // state-0 elements
        total += 2 * (1u64 << j);
        if e_bits > 0 {
            total += s;
        }
        for t in 0..n_bvars {
            let pairs = s >> (t + 1);
            let nodes = degs[t] as u64; // nodes {0, 2, .., deg}
            total += pairs * nodes * 3;
            match t {
                0 => total += s,          // PL formation
                1 => total += 6 * (s / 2), // fused extract + fold into state 1
                _ => total += 5 * (s >> t), // fold of 5 tables into state t
            }
        }
    }
    let leaves = (n_real as u64) << depth;
    let tree = 3 * (leaves - n_real as u64);
    let tree_with_recompute = tree + tree * 2 / 3;
    (total, tree_with_recompute)
}

/// Both sides of one pair (witness depth `depth`, table depth `dt`, the
/// same n_real / e_bits): (rounds kmuls, tree kmuls).
pub fn masked_pair_kmuls(depth: usize, dt: usize, e_bits: usize, n_real: usize) -> (u64, u64) {
    let (a, b) = masked_descent_kmuls(depth, e_bits, n_real);
    let (c, d) = masked_descent_kmuls(dt, e_bits, n_real);
    (a + c, b + d)
}

/// Base MACs per K-mult (the 16x16 lane MAC of kfield.rs) — the exchange
/// rate every K-mult-equivalent figure in the spike report uses.
pub const MACS_PER_KMUL: u64 = 256;

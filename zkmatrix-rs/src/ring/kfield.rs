// U-K1 (M4_LOOKUP_DESIGN.md Section 8): scalar arithmetic for the
// lookup's challenge/soundness field K = GF(q^16), realized as the
// residue field of CRT slot 0 of the k = 8 split:
//
//     K := Z_q[Y] / (Y^16 - s0),   s0 = slot_roots[0],
//
// |K| = q^16 ~ 2^496 at q31 — the field every LogUp/GKR challenge,
// round polynomial and MLE value lives in. Elements are length-16
// coefficient vectors (little-endian in Y); multiplication is the
// existing slot kernel (`slot_mul_g`), inversion is Fermat
// (a^(q^16 - 2), test/verifier-grade — the GKR prover never inverts,
// which is the point of the projective accumulation).
//
// LANE NOTE (the 8-lane cost model, Section 2.2 of the design): a full
// ring multiplication executes 8 INDEPENDENT slot-field multiplications
// — one per CRT slot — which is what prices a K-mult at ~1/8th of a
// ring mult. The lanes are NOT interchangeable as K-instances: slot j
// computes in Z_q[Y]/(Y^16 - s_j), and s_j/s0 is not a 16th power in
// Z_q (the slot roots are distinct primitive-root powers), so
// transporting a canonical-K value into lane j requires the field
// isomorphism phi_j : Y -> c_j Y with c_j a 16th root of s_j/s0 — which
// lives only in the extension. Bulk kernels must therefore either keep
// each value in one lane for its whole life (the U-K3 layout) or apply
// an explicit 16x16 change-of-basis per transport; `lane_split`/
// `lane_merge` below expose the per-lane view and the U-K1 battery pins
// the per-lane consistency (ring mult == 8 slot-field mults, each in
// its own field). Scalar K arithmetic (this module) is the semantic
// reference; lane routing is a U-K3 throughput decision.

use sha2::{Digest, Sha256};

use super::{D, Poly, RingCtx, XofReader, Zq, crt_merge, crt_split, slot_mul_g};

/// Extension degree of the slot field at the frozen point (D / k).
pub const K_DEG: usize = 16;

/// One K-element: K_DEG base-field coefficients, little-endian in Y.
pub type KElem = Vec<u64>;

/// The canonical slot field: slot 0's binomial.
pub struct KField {
    pub zq: Zq,
    /// The binomial root: Y^K_DEG = s in K.
    pub s: u64,
    /// Little-endian u64 limbs of q^K_DEG - 2 (the Fermat inversion
    /// exponent), precomputed once.
    inv_exp: Vec<u64>,
    /// U-K9: the bulk-kernel context — present iff the modulus passes the
    /// vector-reduction gate (KKern::try_new) AND this instance is not the
    /// scalar differential oracle (harness_scalar). Every bulk path in
    /// gkr/sumcheck/gkr_masked dispatches on this; None means the original
    /// scalar code runs everywhere, bit-identically.
    pub(crate) kern: Option<KKern>,
}

/// Little-endian limbs of q^K_DEG - delta (delta in {1, 2}).
fn q_pow_minus(q: u64, delta: u64) -> Vec<u64> {
    let mut limbs: Vec<u64> = vec![1];
    for _ in 0..K_DEG {
        let mut carry: u128 = 0;
        for l in limbs.iter_mut() {
            let wide = *l as u128 * q as u128 + carry;
            *l = wide as u64;
            carry = wide >> 64;
        }
        if carry != 0 {
            limbs.push(carry as u64);
        }
    }
    // Subtract delta (q^K_DEG ends in ...001? no — just do the borrow).
    let mut borrow = delta;
    for l in limbs.iter_mut() {
        let (v, under) = l.overflowing_sub(borrow);
        *l = v;
        borrow = u64::from(under);
        if borrow == 0 {
            break;
        }
    }
    assert_eq!(borrow, 0);
    limbs
}

impl KField {
    /// The canonical instance for a ring context: slot 0 of the CRT
    /// split. Asserts the frozen slot degree.
    pub fn new(ctx: &RingCtx) -> KField {
        assert_eq!(ctx.slot_deg, K_DEG, "slot field expects the frozen k = 8 split");
        let q = ctx.zq.q;
        let s = ctx.slot_roots[0];
        KField { zq: Zq::new(q), s, inv_exp: q_pow_minus(q, 2), kern: KKern::try_new(q, s) }
    }

    /// U-K9 differential oracle: the same field with every bulk kernel
    /// DISABLED — all arithmetic runs the original scalar path. The [U-K9]
    /// battery proves the bulk path bit-identical against this instance.
    /// Battery/harness use only; never a protocol decision.
    pub fn harness_scalar(ctx: &RingCtx) -> KField {
        let mut kf = KField::new(ctx);
        kf.kern = None;
        kf
    }

    pub fn zero(&self) -> KElem {
        vec![0; K_DEG]
    }

    pub fn one(&self) -> KElem {
        self.embed(1)
    }

    /// The field generator Y (the design's fixed fusion element kappa).
    pub fn gen_y(&self) -> KElem {
        let mut e = self.zero();
        e[1] = 1;
        e
    }

    /// Z_q -> K subfield embedding (constant coefficient).
    pub fn embed(&self, x: u64) -> KElem {
        let mut e = self.zero();
        e[0] = x % self.zq.q;
        e
    }

    /// Coordinate c of a K-element (a PUBLIC Z_q-linear functional —
    /// the E4 landing reads K-values coordinate-wise).
    pub fn coord(&self, a: &KElem, c: usize) -> u64 {
        a[c]
    }

    pub fn is_zero(&self, a: &KElem) -> bool {
        a.iter().all(|&x| x == 0)
    }

    pub fn add(&self, a: &KElem, b: &KElem) -> KElem {
        a.iter().zip(b.iter()).map(|(&x, &y)| self.zq.add(x, y)).collect()
    }

    pub fn sub(&self, a: &KElem, b: &KElem) -> KElem {
        a.iter().zip(b.iter()).map(|(&x, &y)| self.zq.sub(x, y)).collect()
    }

    pub fn neg(&self, a: &KElem) -> KElem {
        a.iter().map(|&x| self.zq.neg(x)).collect()
    }

    /// Scale by a base-field scalar.
    pub fn scale(&self, c: u64, a: &KElem) -> KElem {
        a.iter().map(|&x| self.zq.mul(c, x)).collect()
    }

    pub fn mul(&self, a: &KElem, b: &KElem) -> KElem {
        slot_mul_g(&self.zq, a, b, self.s, K_DEG)
    }

    pub fn sq(&self, a: &KElem) -> KElem {
        self.mul(a, a)
    }

    /// b^e for little-endian u64 limbs e (MSB-first square-and-multiply).
    pub fn pow_limbs(&self, b: &KElem, e_limbs: &[u64]) -> KElem {
        let mut acc = self.one();
        let mut started = false;
        for limb in e_limbs.iter().rev() {
            for bit in (0..64).rev() {
                if started {
                    acc = self.sq(&acc);
                }
                if (limb >> bit) & 1 == 1 {
                    if started {
                        acc = self.mul(&acc, b);
                    } else {
                        acc = b.clone();
                        started = true;
                    }
                }
            }
        }
        acc
    }

    pub fn pow(&self, b: &KElem, e: u64) -> KElem {
        self.pow_limbs(b, &[e])
    }

    /// Fermat inversion: a^(q^16 - 2). Verifier/test-grade cost
    /// (~750 slot mults); the GKR prover never calls it.
    pub fn inv(&self, a: &KElem) -> KElem {
        assert!(!self.is_zero(a), "K inversion of zero");
        self.pow_limbs(a, &self.inv_exp)
    }

    /// Uniform K-element from an XOF stream (16 rejection-free
    /// next_field draws — the challenge sampler for alpha/rho/r/mu).
    pub fn uniform(&self, reader: &mut XofReader) -> KElem {
        (0..K_DEG).map(|_| reader.next_field(self.zq.q)).collect()
    }

    /// Canonical transcript bytes (little-endian u64 per coefficient) —
    /// every K-element that enters a hash uses exactly this encoding.
    pub fn bytes(&self, a: &KElem) -> Vec<u8> {
        let mut out = Vec::with_capacity(K_DEG * 8);
        for &c in a {
            out.extend_from_slice(&c.to_le_bytes());
        }
        out
    }
}

// ---------------------------------------------------------------------------
// The per-lane view of a ring element (the 8-lane cost-model anchor).

/// Split a ring element into its 8 slot-field residues: lane j is a
/// K_DEG-coefficient element of Z_q[Y]/(Y^16 - slot_roots[j]) — lane
/// j's OWN field, see the module header's lane note.
pub fn lane_split(ctx: &RingCtx, a: &Poly) -> Vec<KElem> {
    let buf = crt_split(ctx, a);
    (0..ctx.k).map(|j| buf[j * ctx.slot_deg..(j + 1) * ctx.slot_deg].to_vec()).collect()
}

/// Inverse of lane_split.
pub fn lane_merge(ctx: &RingCtx, lanes: &[KElem]) -> Poly {
    assert_eq!(lanes.len(), ctx.k);
    let mut buf = vec![0u64; D];
    for (j, lane) in lanes.iter().enumerate() {
        assert_eq!(lane.len(), ctx.slot_deg);
        buf[j * ctx.slot_deg..(j + 1) * ctx.slot_deg].copy_from_slice(lane);
    }
    crt_merge(ctx, &mut buf);
    buf
}

// ---------------------------------------------------------------------------
// U-K9 (B-D1/B-D2): the kernel-grade bulk layer — lane-packed slot
// arithmetic with lazy (wide-accumulate, reduce-once) discipline, the A1
// kernel class (aux_ntt_core.rs) transplanted to K = GF(q^16):
//
//   * Tables are LANE-BLOCKED SoA: KL = 8 K-elements per block, canonical
//     u32 coefficients, coefficient-major within the block (coefficient j
//     of lane l at block*KBLK + j*KL + l). Canonical values fit u32 because
//     the gate requires q < 2^31; a 512 B block is 8 cache lines, streamed
//     sequentially — this is also the H-03 memory representation (64 B per
//     element vs ~170 B for a boxed Vec<u64> KElem).
//   * A 16x16 slot product is 256 widening 32x32->64 MACs accumulated in
//     SPLIT u64 PLANES (lo/hi 32-bit halves, the A1 acc_lo/acc_hi trick),
//     which autovectorizes to vpmuludq/vpaddq under AVX2 (8x lane
//     occupancy: 8 elements per kernel call, 4 u64 lanes per vector op).
//   * Reduction is DEFERRED: one division-free special-form reduction per
//     output coefficient (never per multiplication), using 2^31 == c31 and
//     2^32 == c32 (mod q) with tiny c31 (399 at the frozen q31 point):
//     two fold steps + two conditional subtractions land exact canonical
//     values — bit-identical to the scalar `%` path by construction.
//   * Sum-shaped relations (p' = pL qR + pR qL; the round-poly node sum
//     over the hypercube) accumulate MANY products in the planes and
//     reduce once per output — the "lazy reduction inside round_poly/
//     build_tree" the M4 Section 7' fix priced.
//
// GATE: 2^30 < q < 2^31 and 2^31 mod q < 1024 (KKern::try_new). Q8 =
// 2^31 - 399 qualifies (c31 = 399, c32 = 798). Any other modulus (q46
// class) — and every KField::harness_scalar instance — runs the original
// scalar path everywhere: same values, no packed layer. The scalar path
// is the shipped differential oracle ([U-K9] battery).
//
// Plane-bound bookkeeping (all exact-integer, asserted in debug):
//   operands < q < 2^31, product p < 2^62; p_lo < 2^32, p_hi < 2^30.
//   A single product-sum of up to 3 x 16 terms keeps lo < 2^37, hi < 2^35;
//   the recombine w = lo + c32*(hi & m32) + (c32*(hi >> 32)) << 32 stays
//   < 2^47 (exact in u64), fold31 twice + canon32 lands [0, q).
//   The persistent round-poly accumulator adds <= 16 products per pair
//   term; at <= 2^28 pair terms lo, hi < 2^64 (in-engine cap 2^25 leaves).
//   Its finalization runs in u128 with an exact `%` — a handful of values
//   per round, not a hot path.

/// Lanes per block (8 independent K-values per kernel call — the design's
/// 8x lane-occupancy anchor).
pub(crate) const KL: usize = 8;
/// u32 words per block: KL lanes x K_DEG coefficients.
pub(crate) const KBLK: usize = KL * K_DEG;
/// Audited CPU-reference ceiling for any one packed table. This bounds the
/// persistent lazy accumulator and prevents unchecked allocation arithmetic.
/// A GPU backend may raise it only with a new integer-bound proof and tests.
pub const K9_MAX_LEAVES: usize = 1 << 25;
const K9_MAX_PAIR_TERMS: usize = K9_MAX_LEAVES / 2;

pub fn k9_capacity_ok(leaves: usize) -> bool {
    leaves.is_power_of_two() && leaves <= K9_MAX_LEAVES
}

/// The bulk-kernel modulus context (see the gate above).
#[derive(Clone, Copy)]
pub(crate) struct KKern {
    pub q: u64,
    pub s: u64,
    /// 2^31 mod q — tiny under the gate.
    pub c31: u64,
    /// 2^32 mod q = 2*c31 (q > 2^30 makes 2*c31 < q).
    pub c32: u64,
}

impl KKern {
    pub(crate) fn try_new(q: u64, s: u64) -> Option<KKern> {
        if q <= (1u64 << 30) || q >= (1u64 << 31) {
            return None;
        }
        let c31 = (1u64 << 31) % q;
        if c31 >= 1024 {
            return None;
        }
        Some(KKern { q, s, c31, c32: 2 * c31 })
    }
}

/// A lane-blocked packed table of n canonical K-elements (layout in the
/// module header). Trailing lanes of the last block are zero padding.
pub(crate) struct KTab {
    pub n: usize,
    pub d: Vec<u32>,
}

impl KTab {
    pub(crate) fn zeroed(n: usize) -> KTab {
        assert!(n <= K9_MAX_LEAVES, "K9 packed-table cap exceeded");
        let words = n
            .div_ceil(KL)
            .checked_mul(KBLK)
            .expect("K9 packed-table allocation overflow");
        KTab { n, d: vec![0u32; words] }
    }

    pub(crate) fn from_kelems(v: &[KElem]) -> KTab {
        let mut t = KTab::zeroed(v.len());
        for (i, e) in v.iter().enumerate() {
            t.set(i, e);
        }
        t
    }

    /// [UPERF2-A] A table of n copies of one element (the neutral / dummy
    /// leaf fill), written blockwise; trailing lanes of a partial last
    /// block stay zero. Same contents as from_kelems(&vec![e; n]).
    pub(crate) fn filled(n: usize, e: &KElem) -> KTab {
        let mut t = KTab::zeroed(n);
        if n == 0 {
            return t;
        }
        let nblk = n / KL;
        if nblk > 0 {
            let mut blk = [0u32; KBLK];
            for j in 0..K_DEG {
                debug_assert!(e[j] < (1 << 31), "packed KTab expects canonical q31-class values");
                for l in 0..KL {
                    blk[j * KL + l] = e[j] as u32;
                }
            }
            for m in 0..nblk {
                t.d[m * KBLK..(m + 1) * KBLK].copy_from_slice(&blk);
            }
        }
        for i in nblk * KL..n {
            t.set(i, e);
        }
        t
    }

    #[inline]
    pub(crate) fn get(&self, i: usize) -> KElem {
        debug_assert!(i < self.n);
        let base = (i / KL) * KBLK + (i % KL);
        (0..K_DEG).map(|j| self.d[base + j * KL] as u64).collect()
    }

    #[inline]
    pub(crate) fn set(&mut self, i: usize, e: &KElem) {
        debug_assert!(i < self.n);
        let base = (i / KL) * KBLK + (i % KL);
        for j in 0..K_DEG {
            debug_assert!(e[j] < (1 << 31), "packed KTab expects canonical q31-class values");
            self.d[base + j * KL] = e[j] as u32;
        }
    }

    pub(crate) fn to_kelems(&self) -> Vec<KElem> {
        (0..self.n).map(|i| self.get(i)).collect()
    }

    /// Copy element si of src into slot di (no KElem allocation).
    #[inline]
    pub(crate) fn copy_elem(&mut self, di: usize, src: &KTab, si: usize) {
        debug_assert!(di < self.n && si < src.n);
        let db = (di / KL) * KBLK + (di % KL);
        let sb = (si / KL) * KBLK + (si % KL);
        for j in 0..K_DEG {
            self.d[db + j * KL] = src.d[sb + j * KL];
        }
    }
}

/// Canonical [u32; K_DEG] view of a scalar K-element (kernel operand form).
#[inline]
pub(crate) fn kop(e: &KElem) -> [u32; K_DEG] {
    std::array::from_fn(|j| {
        debug_assert!(e[j] < (1 << 31));
        e[j] as u32
    })
}

// --- lane-scalar primitives (inlined into every kernel body) ---

/// One fold of v at the 2^31 boundary: v == (v & m31) + c31*(v >> 31).
#[inline(always)]
fn fold31(v: u64, c31: u64) -> u64 {
    (v & 0x7FFF_FFFF) + c31 * (v >> 31)
}

/// v < 2q + 2^22 (and < 2^32): two conditional subtractions via the
/// unsigned-min trick (r - q wraps huge when r < q).
#[inline(always)]
fn canon32(v: u64, q32: u32) -> u32 {
    let r = v as u32;
    let r = r.min(r.wrapping_sub(q32));
    r.min(r.wrapping_sub(q32))
}

/// Lane modular add/sub on canonical u32 values.
#[inline(always)]
fn addm32(a: u32, b: u32, q32: u32) -> u32 {
    let s = a + b; // < 2^32: both < q < 2^31
    s.min(s.wrapping_sub(q32))
}
#[inline(always)]
fn subm32(a: u32, b: u32, q32: u32) -> u32 {
    let d = a.wrapping_sub(b);
    d.min(d.wrapping_add(q32))
}

/// Recombine split planes: value == lo + 2^32*hi with lo, hi < 2^38
/// (exact in u64: result < 2^49).
#[inline(always)]
fn recomb(lo: u64, hi: u64, c32: u64) -> u64 {
    lo + c32 * (hi & 0xFFFF_FFFF) + ((c32 * (hi >> 32)) << 32)
}

/// 16x16 MAC of two lane-blocks into split planes (31 output coefficients
/// x KL lanes): planes[t] += sum_{i+j=t} a_i b_j, per lane.
#[inline(always)]
fn mac_block(a: &[u32; KBLK], b: &[u32; KBLK], lo: &mut [u64; 31 * KL], hi: &mut [u64; 31 * KL]) {
    for i in 0..K_DEG {
        for j in 0..K_DEG {
            let t = i + j;
            for l in 0..KL {
                let p = a[i * KL + l] as u64 * b[j * KL + l] as u64;
                lo[t * KL + l] += p & 0xFFFF_FFFF;
                hi[t * KL + l] += p >> 32;
            }
        }
    }
}

/// mac_block with a broadcast (fixed) second operand.
#[inline(always)]
fn mac_block_fixed(
    a: &[u32; KBLK],
    r: &[u32; K_DEG],
    lo: &mut [u64; 31 * KL],
    hi: &mut [u64; 31 * KL],
) {
    for i in 0..K_DEG {
        for j in 0..K_DEG {
            let t = i + j;
            let rj = r[j] as u64;
            for l in 0..KL {
                let p = a[i * KL + l] as u64 * rj;
                lo[t * KL + l] += p & 0xFFFF_FFFF;
                hi[t * KL + l] += p >> 32;
            }
        }
    }
}

/// Reduce split planes (single product-sum class: lo, hi < 2^38) to a
/// canonical output block, folding Y^16 = s: out_t = w_t + s * red(w_{t+16}).
#[inline(always)]
fn red_block(kern: &KKern, lo: &[u64; 31 * KL], hi: &[u64; 31 * KL], out: &mut [u32; KBLK]) {
    let (c31, c32, s, q32) = (kern.c31, kern.c32, kern.s, kern.q as u32);
    let mut h = [0u32; KBLK];
    for t in 0..K_DEG - 1 {
        for l in 0..KL {
            let idx = (t + K_DEG) * KL + l;
            let w = recomb(lo[idx], hi[idx], c32); // < 2^49
            h[t * KL + l] = canon32(fold31(fold31(w, c31), c31), q32);
        }
    }
    for t in 0..K_DEG {
        for l in 0..KL {
            let idx = t * KL + l;
            let w = recomb(lo[idx], hi[idx], c32);
            let v = w + s * h[t * KL + l] as u64; // < 2^49 + 2^62 < 2^63
            out[t * KL + l] = canon32(fold31(fold31(v, c31), c31), q32);
        }
    }
}

/// Deinterleave the (2i, 2i+1) element pairs feeding output block m: the
/// inputs are src blocks 2m and 2m+1; t0 gets the even elements, t1 the
/// odd, as aligned lane-blocks (output lane l = pair l).
#[inline(always)]
fn deint_pair(src: &[u32], m: usize, t0: &mut [u32; KBLK], t1: &mut [u32; KBLK]) {
    let b0 = &src[(2 * m) * KBLK..(2 * m) * KBLK + KBLK];
    let b1 = &src[(2 * m + 1) * KBLK..(2 * m + 1) * KBLK + KBLK];
    for j in 0..K_DEG {
        for l in 0..4 {
            t0[j * KL + l] = b0[j * KL + 2 * l];
            t1[j * KL + l] = b0[j * KL + 2 * l + 1];
            t0[j * KL + 4 + l] = b1[j * KL + 2 * l];
            t1[j * KL + 4 + l] = b1[j * KL + 2 * l + 1];
        }
    }
}

// --- kernel bodies (shared by the AVX2 and portable instantiations) ---

/// One projective-tree layer step over full blocks: parents m*KL..(m+1)*KL
/// from child pairs; np = pL qR + pR qL (2 MACs, ONE reduction), nq = qL qR.
#[inline(always)]
fn tree_step_body(kern: &KKern, cp: &[u32], cq: &[u32], np: &mut [u32], nq: &mut [u32], nblk: usize) {
    let src_words = nblk.checked_mul(2 * KBLK).expect("K9 tree input size overflow");
    let dst_words = nblk.checked_mul(KBLK).expect("K9 tree output size overflow");
    assert!(cp.len() >= src_words && cq.len() >= src_words, "K9 tree input layout");
    assert!(np.len() >= dst_words && nq.len() >= dst_words, "K9 tree output layout");
    let mut pl = [0u32; KBLK];
    let mut pr = [0u32; KBLK];
    let mut ql = [0u32; KBLK];
    let mut qr = [0u32; KBLK];
    let mut out = [0u32; KBLK];
    for m in 0..nblk {
        deint_pair(cp, m, &mut pl, &mut pr);
        deint_pair(cq, m, &mut ql, &mut qr);
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block(&pl, &qr, &mut lo, &mut hi);
        mac_block(&pr, &ql, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        np[m * KBLK..(m + 1) * KBLK].copy_from_slice(&out);
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block(&ql, &qr, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        nq[m * KBLK..(m + 1) * KBLK].copy_from_slice(&out);
    }
}

/// Fold full blocks IN PLACE: T'[m] = T[2m] + r (T[2m+1] - T[2m]) at
/// block granularity — output block m is written after its source blocks
/// (2m, 2m+1) are staged on the stack, and m <= 2m keeps every unread
/// source block ahead of the write cursor (forward-safe). [U-PERF-PA]
/// residue rebase (uk9-residue-2026-07-12): the out-of-place original
/// allocated + memset a fresh table per fold — one per table per
/// sumcheck round in the descent hot loops.
#[inline(always)]
fn fold_body(kern: &KKern, d_io: &mut [u32], r: &[u32; K_DEG], nblk: usize) {
    let src_words = nblk.checked_mul(2 * KBLK).expect("K9 fold input size overflow");
    assert!(d_io.len() >= src_words, "K9 fold layout");
    let q32 = kern.q as u32;
    let mut t0 = [0u32; KBLK];
    let mut t1 = [0u32; KBLK];
    let mut d = [0u32; KBLK];
    let mut out = [0u32; KBLK];
    for m in 0..nblk {
        deint_pair(d_io, m, &mut t0, &mut t1);
        for x in 0..KBLK {
            d[x] = subm32(t1[x], t0[x], q32);
        }
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block_fixed(&d, r, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        for x in 0..KBLK {
            out[x] = addm32(t0[x], out[x], q32);
        }
        d_io[m * KBLK..(m + 1) * KBLK].copy_from_slice(&out);
    }
}

/// One eq-table doubling step IN PLACE over full blocks: for each block
/// m of the current half, block m becomes a * zbar and block m + half
/// becomes a * z, with the operand block a staged on the stack before
/// either store. [U-PERF-PA] residue rebase: the out-of-place original
/// allocated a fresh double-size table per variable (~2x the final size
/// in cumulative churn per eq build).
#[inline(always)]
fn eq_double_body(
    kern: &KKern,
    d_io: &mut [u32],
    half_nblk: usize,
    zbar: &[u32; K_DEG],
    z: &[u32; K_DEG],
) {
    let words = half_nblk.checked_mul(2 * KBLK).expect("K9 eq-double size overflow");
    assert!(d_io.len() >= words, "K9 eq-double layout");
    let mut a = [0u32; KBLK];
    let mut out = [0u32; KBLK];
    for m in 0..half_nblk {
        a.copy_from_slice(&d_io[m * KBLK..(m + 1) * KBLK]);
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block_fixed(&a, zbar, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        d_io[m * KBLK..(m + 1) * KBLK].copy_from_slice(&out);
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block_fixed(&a, z, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        d_io[(m + half_nblk) * KBLK..(m + half_nblk + 1) * KBLK].copy_from_slice(&out);
    }
}

/// Elementwise fixed-operand product over full blocks: dst[i] = src[i] * r.
#[inline(always)]
fn mul_fixed_body(kern: &KKern, src: &[u32], r: &[u32; K_DEG], dst: &mut [u32], nblk: usize) {
    let words = nblk.checked_mul(KBLK).expect("K9 fixed-mul size overflow");
    assert!(src.len() >= words && dst.len() >= words, "K9 fixed-mul layout");
    let mut out = [0u32; KBLK];
    for m in 0..nblk {
        let a: &[u32; KBLK] = src[m * KBLK..(m + 1) * KBLK].try_into().unwrap();
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block_fixed(a, r, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        dst[m * KBLK..(m + 1) * KBLK].copy_from_slice(&out);
    }
}

/// Elementwise product of two tables over full blocks: dst[i] = a[i] * b[i].
#[inline(always)]
fn mul_elem_body(kern: &KKern, a: &[u32], b: &[u32], dst: &mut [u32], nblk: usize) {
    let words = nblk.checked_mul(KBLK).expect("K9 element-mul size overflow");
    assert!(a.len() >= words && b.len() >= words && dst.len() >= words, "K9 element-mul layout");
    let mut out = [0u32; KBLK];
    for m in 0..nblk {
        let ab: &[u32; KBLK] = a[m * KBLK..(m + 1) * KBLK].try_into().unwrap();
        let bb: &[u32; KBLK] = b[m * KBLK..(m + 1) * KBLK].try_into().unwrap();
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block(ab, bb, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        dst[m * KBLK..(m + 1) * KBLK].copy_from_slice(&out);
    }
}

/// Broadcast modular add over full blocks: t[i] += c.
#[inline(always)]
fn addc_body(kern: &KKern, t: &mut [u32], c: &[u32; K_DEG], nblk: usize) {
    let words = nblk.checked_mul(KBLK).expect("K9 add size overflow");
    assert!(t.len() >= words, "K9 add layout");
    let q32 = kern.q as u32;
    for m in 0..nblk {
        for j in 0..K_DEG {
            for l in 0..KL {
                let idx = m * KBLK + j * KL + l;
                t[idx] = addm32(t[idx], c[j], q32);
            }
        }
    }
}

/// The GKR/masked-GKR round-polynomial table part over full blocks.
///
/// Tables (each `n` elements, pairs = n/2): eq, p0, p1, q0, q1, ql where
/// ql = lambda*q0 is maintained by the caller so the wire is 3 products:
///     wire(x, i) = P0 Q1 + P1 Q0 + QL Q1   (all extrapolated at x)
///     g(x) = sum_i EQ(x, i) * wire(x, i)  [+ caller's analytic terms].
/// Node x = 1 is NEVER evaluated (g(1) = c_run - g(0), the caller's
/// identity); nodes are {0, 2, .., deg}. Extrapolation is by successive
/// modular addition of the pair difference — operands stay canonical u32,
/// so the whole node loop is one MAC/reduce pipeline.
/// `consts`: per node index (0-based over the evaluated nodes) optional
/// broadcast add-constants for [p0, p1, q0, q1, ql] — the masked t == 0
/// child-mask terms zz(x)*SP(c); zeros elsewhere.
/// Output: per evaluated node, the 31 coefficient sums as u128 (lo +
/// 2^32*hi), for the caller to reduce exactly (a handful of values).
#[inline(always)]
#[allow(clippy::too_many_arguments)]
fn round_g_body(
    kern: &KKern,
    eq: &[u32],
    p0: &[u32],
    p1: &[u32],
    q0: &[u32],
    q1: &[u32],
    ql: &[u32],
    nblk_pairs: usize,
    nodes: &[u64],
    consts: Option<&[[[u32; K_DEG]; 5]]>,
    acc_lo: &mut [u64],
    acc_hi: &mut [u64],
) {
    let pair_terms = nblk_pairs.checked_mul(KL).expect("K9 round term-count overflow");
    assert!(pair_terms <= K9_MAX_PAIR_TERMS, "K9 lazy-accumulator cap exceeded");
    let src_words = nblk_pairs
        .checked_mul(2 * KBLK)
        .expect("K9 round input size overflow");
    assert!(
        [eq, p0, p1, q0, q1, ql].iter().all(|table| table.len() >= src_words),
        "K9 round input layout"
    );
    let acc_words = nodes
        .len()
        .checked_mul(31 * KL)
        .expect("K9 round accumulator size overflow");
    assert!(acc_lo.len() >= acc_words && acc_hi.len() >= acc_words, "K9 round accumulator layout");
    if let Some(cs) = consts {
        assert_eq!(cs.len(), nodes.len(), "K9 round constant layout");
    }
    let q32 = kern.q as u32;
    // per-table even/odd lane-blocks + running extrapolation state
    let mut e0 = [[0u32; KBLK]; 6];
    let mut e1 = [[0u32; KBLK]; 6];
    let mut dd = [[0u32; KBLK]; 6];
    let mut cur = [[0u32; KBLK]; 6];
    let mut op = [[0u32; KBLK]; 5];
    let mut tred = [0u32; KBLK];
    for m in 0..nblk_pairs {
        let srcs = [eq, p0, p1, q0, q1, ql];
        for (k, s) in srcs.iter().enumerate() {
            let (a, b) = (&mut e0[k], &mut e1[k]);
            deint_pair(s, m, a, b);
            for x in 0..KBLK {
                dd[k][x] = subm32(e1[k][x], e0[k][x], q32);
            }
            cur[k] = e1[k];
        }
        let mut prev_x = 1u64;
        for (ni, &x) in nodes.iter().enumerate() {
            // advance the running values to node x (from T1 for x >= 2)
            let tabs: [&[u32; KBLK]; 6] = if x == 0 {
                [&e0[0], &e0[1], &e0[2], &e0[3], &e0[4], &e0[5]]
            } else {
                while prev_x < x {
                    for k in 0..6 {
                        for xx in 0..KBLK {
                            cur[k][xx] = addm32(cur[k][xx], dd[k][xx], q32);
                        }
                    }
                    prev_x += 1;
                }
                [&cur[0], &cur[1], &cur[2], &cur[3], &cur[4], &cur[5]]
            };
            // masked child-mask constants on the five non-eq operands
            let use_ops = if let Some(cs) = consts {
                let c = &cs[ni];
                for k in 0..5 {
                    for j in 0..K_DEG {
                        for l in 0..KL {
                            op[k][j * KL + l] = addm32(tabs[k + 1][j * KL + l], c[k][j], q32);
                        }
                    }
                }
                true
            } else {
                false
            };
            let (vp0, vp1, vq0, vq1, vql) = if use_ops {
                (&op[0], &op[1], &op[2], &op[3], &op[4])
            } else {
                (tabs[1], tabs[2], tabs[3], tabs[4], tabs[5])
            };
            // wire = P0 Q1 + P1 Q0 + QL Q1: 3 MACs, one reduction
            let mut lo = [0u64; 31 * KL];
            let mut hi = [0u64; 31 * KL];
            mac_block(vp0, vq1, &mut lo, &mut hi);
            mac_block(vp1, vq0, &mut lo, &mut hi);
            mac_block(vql, vq1, &mut lo, &mut hi);
            red_block(kern, &lo, &hi, &mut tred);
            // eq * wire into the persistent node accumulator (NO reduction)
            let alo: &mut [u64; 31 * KL] =
                (&mut acc_lo[ni * 31 * KL..(ni + 1) * 31 * KL]).try_into().unwrap();
            let ahi: &mut [u64; 31 * KL] =
                (&mut acc_hi[ni * 31 * KL..(ni + 1) * 31 * KL]).try_into().unwrap();
            mac_block(tabs[0], &tred, alo, ahi);
        }
    }
}

// --- [UPERF2-A] additional kernel bodies (the fast masked-descent path) ---

/// Out-of-place fold over full blocks: dst[m] = src[2m] + r (src[2m+1] -
/// src[2m]) at block granularity — the same arithmetic as `fold_body`
/// on separate source/destination buffers, so block ranges can be split
/// across threads (the in-place fold's forward-safe aliasing forbids a
/// naive range split: a later chunk's writes land on an earlier chunk's
/// unread sources). Values are identical to `fold_body`.
#[inline(always)]
fn fold_oop_body(kern: &KKern, src: &[u32], dst: &mut [u32], r: &[u32; K_DEG], nblk: usize) {
    let src_words = nblk.checked_mul(2 * KBLK).expect("K9 fold input size overflow");
    let dst_words = nblk.checked_mul(KBLK).expect("K9 fold output size overflow");
    assert!(src.len() >= src_words && dst.len() >= dst_words, "K9 oop-fold layout");
    let q32 = kern.q as u32;
    let mut t0 = [0u32; KBLK];
    let mut t1 = [0u32; KBLK];
    let mut d = [0u32; KBLK];
    let mut out = [0u32; KBLK];
    for m in 0..nblk {
        deint_pair(src, m, &mut t0, &mut t1);
        for x in 0..KBLK {
            d[x] = subm32(t1[x], t0[x], q32);
        }
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block_fixed(&d, r, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        for x in 0..KBLK {
            out[x] = addm32(t0[x], out[x], q32);
        }
        dst[m * KBLK..(m + 1) * KBLK].copy_from_slice(&out);
    }
}

/// In-place fixed-operand multiply-add over full blocks: a[i] += b[i] * r
/// (the PL := p0 + lambda*q0 table of the fast round kernel, built on top
/// of the extracted p0 blocks).
#[inline(always)]
fn mul_fixed_add_body(kern: &KKern, a_io: &mut [u32], b: &[u32], r: &[u32; K_DEG], nblk: usize) {
    let words = nblk.checked_mul(KBLK).expect("K9 fixed-mul-add size overflow");
    assert!(a_io.len() >= words && b.len() >= words, "K9 fixed-mul-add layout");
    let q32 = kern.q as u32;
    let mut out = [0u32; KBLK];
    for m in 0..nblk {
        let bb: &[u32; KBLK] = b[m * KBLK..(m + 1) * KBLK].try_into().unwrap();
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block_fixed(bb, r, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        let ab = &mut a_io[m * KBLK..(m + 1) * KBLK];
        for x in 0..KBLK {
            ab[x] = addm32(ab[x], out[x], q32);
        }
    }
}

/// The eq-table doubling step on SPLIT halves: for each block m of the
/// current half, lo[m] (= a) becomes a * zbar and up[m] becomes a * z.
/// Identical values to `eq_double_body`; the split lets the two output
/// regions be chunked in lock-step across threads.
#[inline(always)]
fn eq_double_split_body(
    kern: &KKern,
    lo_io: &mut [u32],
    up: &mut [u32],
    nblk: usize,
    zbar: &[u32; K_DEG],
    z: &[u32; K_DEG],
) {
    let words = nblk.checked_mul(KBLK).expect("K9 eq-double size overflow");
    assert!(lo_io.len() >= words && up.len() >= words, "K9 eq-double split layout");
    let mut a = [0u32; KBLK];
    let mut out = [0u32; KBLK];
    for m in 0..nblk {
        a.copy_from_slice(&lo_io[m * KBLK..(m + 1) * KBLK]);
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block_fixed(&a, zbar, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        lo_io[m * KBLK..(m + 1) * KBLK].copy_from_slice(&out);
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block_fixed(&a, z, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut out);
        up[m * KBLK..(m + 1) * KBLK].copy_from_slice(&out);
    }
}

/// The FIVE-table round-polynomial kernel: the same node sums as
/// `round_g_body` with the p0 and ql = lambda*q0 tables REPLACED by one
/// table PL := p0 + lambda*q0, so the wire is TWO products
///     wire(x, i) = PL Q1 + P1 Q0   (== P0 Q1 + P1 Q0 + lambda Q0 Q1)
/// before the eq MAC (three MACs and one reduction per node instead of
/// four and one). Everything else — extrapolation by successive modular
/// adds, the deferred reduction, the persistent lazy node accumulators —
/// is `round_g_body`'s. Field values are identical because PL(x) =
/// P0(x) + lambda Q0(x) holds at every extrapolated x (linearity), so
/// each node's canonical sum is the same field element. `consts` (masked
/// t == 0): per node add-constants for [pl, p1, q0, q1].
#[inline(always)]
#[allow(clippy::too_many_arguments)]
fn round_g5_body(
    kern: &KKern,
    eq: &[u32],
    pl: &[u32],
    p1: &[u32],
    q0: &[u32],
    q1: &[u32],
    nblk_pairs: usize,
    nodes: &[u64],
    consts: Option<&[[[u32; K_DEG]; 4]]>,
    acc_lo: &mut [u64],
    acc_hi: &mut [u64],
) {
    let pair_terms = nblk_pairs.checked_mul(KL).expect("K9 round term-count overflow");
    assert!(pair_terms <= K9_MAX_PAIR_TERMS, "K9 lazy-accumulator cap exceeded");
    let src_words = nblk_pairs
        .checked_mul(2 * KBLK)
        .expect("K9 round input size overflow");
    assert!(
        [eq, pl, p1, q0, q1].iter().all(|table| table.len() >= src_words),
        "K9 round5 input layout"
    );
    let acc_words = nodes
        .len()
        .checked_mul(31 * KL)
        .expect("K9 round accumulator size overflow");
    assert!(acc_lo.len() >= acc_words && acc_hi.len() >= acc_words, "K9 round accumulator layout");
    if let Some(cs) = consts {
        assert_eq!(cs.len(), nodes.len(), "K9 round5 constant layout");
    }
    let q32 = kern.q as u32;
    let mut e0 = [[0u32; KBLK]; 5];
    let mut e1 = [[0u32; KBLK]; 5];
    let mut dd = [[0u32; KBLK]; 5];
    let mut cur = [[0u32; KBLK]; 5];
    let mut op = [[0u32; KBLK]; 4];
    let mut tred = [0u32; KBLK];
    for m in 0..nblk_pairs {
        let srcs = [eq, pl, p1, q0, q1];
        for (k, s) in srcs.iter().enumerate() {
            let (a, b) = (&mut e0[k], &mut e1[k]);
            deint_pair(s, m, a, b);
            for x in 0..KBLK {
                dd[k][x] = subm32(e1[k][x], e0[k][x], q32);
            }
            cur[k] = e1[k];
        }
        let mut prev_x = 1u64;
        for (ni, &x) in nodes.iter().enumerate() {
            let tabs: [&[u32; KBLK]; 5] = if x == 0 {
                [&e0[0], &e0[1], &e0[2], &e0[3], &e0[4]]
            } else {
                while prev_x < x {
                    for k in 0..5 {
                        for xx in 0..KBLK {
                            cur[k][xx] = addm32(cur[k][xx], dd[k][xx], q32);
                        }
                    }
                    prev_x += 1;
                }
                [&cur[0], &cur[1], &cur[2], &cur[3], &cur[4]]
            };
            let use_ops = if let Some(cs) = consts {
                let c = &cs[ni];
                for k in 0..4 {
                    for j in 0..K_DEG {
                        for l in 0..KL {
                            op[k][j * KL + l] = addm32(tabs[k + 1][j * KL + l], c[k][j], q32);
                        }
                    }
                }
                true
            } else {
                false
            };
            let (vpl, vp1, vq0, vq1) = if use_ops {
                (&op[0], &op[1], &op[2], &op[3])
            } else {
                (tabs[1], tabs[2], tabs[3], tabs[4])
            };
            // wire = PL Q1 + P1 Q0: 2 MACs, one reduction
            let mut lo = [0u64; 31 * KL];
            let mut hi = [0u64; 31 * KL];
            mac_block(vpl, vq1, &mut lo, &mut hi);
            mac_block(vp1, vq0, &mut lo, &mut hi);
            red_block(kern, &lo, &hi, &mut tred);
            let alo: &mut [u64; 31 * KL] =
                (&mut acc_lo[ni * 31 * KL..(ni + 1) * 31 * KL]).try_into().unwrap();
            let ahi: &mut [u64; 31 * KL] =
                (&mut acc_hi[ni * 31 * KL..(ni + 1) * 31 * KL]).try_into().unwrap();
            mac_block(tabs[0], &tred, alo, ahi);
        }
    }
}

// --- dispatch: AVX2 instantiation when available, portable otherwise ---

macro_rules! k9_kernel {
    ($pub_name:ident, $avx_name:ident, $body:ident, ($($arg:ident : $ty:ty),*)) => {
        #[cfg(target_arch = "x86_64")]
        #[target_feature(enable = "avx2")]
        unsafe fn $avx_name($($arg: $ty),*) {
            $body($($arg),*)
        }
        pub(crate) fn $pub_name($($arg: $ty),*) {
            #[cfg(target_arch = "x86_64")]
            if std::arch::is_x86_feature_detected!("avx2") {
                return unsafe { $avx_name($($arg),*) };
            }
            #[allow(unreachable_code)]
            $body($($arg),*)
        }
    };
}

k9_kernel!(k9_tree_step, k9_tree_step_avx2, tree_step_body,
    (kern: &KKern, cp: &[u32], cq: &[u32], np: &mut [u32], nq: &mut [u32], nblk: usize));
k9_kernel!(k9_fold_blocks, k9_fold_blocks_avx2, fold_body,
    (kern: &KKern, d_io: &mut [u32], r: &[u32; K_DEG], nblk: usize));
k9_kernel!(k9_eq_double_blocks, k9_eq_double_blocks_avx2, eq_double_body,
    (kern: &KKern, d_io: &mut [u32], half_nblk: usize, zbar: &[u32; K_DEG], z: &[u32; K_DEG]));
k9_kernel!(k9_mul_fixed_blocks, k9_mul_fixed_blocks_avx2, mul_fixed_body,
    (kern: &KKern, src: &[u32], r: &[u32; K_DEG], dst: &mut [u32], nblk: usize));
k9_kernel!(k9_mul_elem_blocks, k9_mul_elem_blocks_avx2, mul_elem_body,
    (kern: &KKern, a: &[u32], b: &[u32], dst: &mut [u32], nblk: usize));
k9_kernel!(k9_addc_blocks, k9_addc_blocks_avx2, addc_body,
    (kern: &KKern, t: &mut [u32], c: &[u32; K_DEG], nblk: usize));
k9_kernel!(k9_round_g_blocks, k9_round_g_blocks_avx2, round_g_body,
    (kern: &KKern, eq: &[u32], p0: &[u32], p1: &[u32], q0: &[u32], q1: &[u32], ql: &[u32],
     nblk_pairs: usize, nodes: &[u64], consts: Option<&[[[u32; K_DEG]; 5]]>,
     acc_lo: &mut [u64], acc_hi: &mut [u64]));
// [UPERF2-A] fast-path bodies
k9_kernel!(k9_fold_oop_blocks, k9_fold_oop_blocks_avx2, fold_oop_body,
    (kern: &KKern, src: &[u32], dst: &mut [u32], r: &[u32; K_DEG], nblk: usize));
k9_kernel!(k9_mul_fixed_add_blocks, k9_mul_fixed_add_blocks_avx2, mul_fixed_add_body,
    (kern: &KKern, a_io: &mut [u32], b: &[u32], r: &[u32; K_DEG], nblk: usize));
k9_kernel!(k9_eq_double_split_blocks, k9_eq_double_split_blocks_avx2, eq_double_split_body,
    (kern: &KKern, lo_io: &mut [u32], up: &mut [u32], nblk: usize, zbar: &[u32; K_DEG], z: &[u32; K_DEG]));
k9_kernel!(k9_round_g5_blocks, k9_round_g5_blocks_avx2, round_g5_body,
    (kern: &KKern, eq: &[u32], pl: &[u32], p1: &[u32], q0: &[u32], q1: &[u32],
     nblk_pairs: usize, nodes: &[u64], consts: Option<&[[[u32; K_DEG]; 4]]>,
     acc_lo: &mut [u64], acc_hi: &mut [u64]));

// ---------------------------------------------------------------------------
// [UPERF2-A] Deterministic ZK_THREADS parallelism over the packed kernels.
//
// Every split below is over INDEPENDENT block ranges of exact-integer
// work: elementwise kernels (fold, fixed-operand MAC, eq doubling, tree
// steps, broadcast add) write disjoint output blocks — no reduction at
// all — and the round-polynomial kernel accumulates per-chunk lazy planes
// that are summed in index order at the end. Those planes are exact
// non-negative integer sums bounded by the serial total (which the
// K9_MAX_PAIR_TERMS cap keeps < 2^64), so partial sums cannot overflow and
// integer addition is associative: the result is BIT-IDENTICAL for any
// ZK_THREADS and any chunking. Threads come from
// `eval_proof::threads()` (ZK_THREADS, default 1); at 1 the bodies run
// inline with no pool involvement.

static K9_POOL: std::sync::LazyLock<rayon::ThreadPool> = std::sync::LazyLock::new(|| {
    rayon::ThreadPoolBuilder::new()
        .num_threads(super::eval_proof::threads())
        .build()
        .expect("ZK_THREADS K9 pool")
});

#[inline(always)]
pub(crate) fn k9_threads() -> usize {
    super::eval_proof::threads()
}

fn k9_pooled<R: Send>(f: impl FnOnce() -> R + Send) -> R {
    if k9_threads() > 1 { K9_POOL.install(f) } else { f() }
}

/// The pool wrapper for the sibling modules' own splits (gkr.rs's
/// extract; same pool, same threads()).
pub(crate) fn k9_pooled_pub<R: Send>(f: impl FnOnce() -> R + Send) -> R {
    k9_pooled(f)
}

pub(crate) fn k9_extract_chunk_blk() -> usize {
    K9_CHUNK_BLK
}

/// Deinterleave n consecutive block pairs of `src` starting at pair index
/// m0 into t0_out (even elements) / t1_out (odd elements), block i of the
/// outputs from source blocks 2(m0+i), 2(m0+i)+1 — the extract_children
/// copy at block granularity (no per-element get/set).
pub(crate) fn k9_deint_blocks(src: &[u32], m0: usize, n: usize, t0_out: &mut [u32], t1_out: &mut [u32]) {
    assert!(t0_out.len() >= n * KBLK && t1_out.len() >= n * KBLK, "K9 deint output layout");
    assert!(src.len() >= 2 * (m0 + n) * KBLK, "K9 deint input layout");
    let mut a = [0u32; KBLK];
    let mut b = [0u32; KBLK];
    for i in 0..n {
        deint_pair(src, m0 + i, &mut a, &mut b);
        t0_out[i * KBLK..(i + 1) * KBLK].copy_from_slice(&a);
        t1_out[i * KBLK..(i + 1) * KBLK].copy_from_slice(&b);
    }
}

/// Blocks per parallel chunk for elementwise kernels (positional output;
/// any value is identical): 256 blocks = 128 KiB of u32 words per table
/// operand — a few cache-resident lane blocks per work item.
const K9_CHUNK_BLK: usize = 256;

/// Number of pair-block chunks for the round kernel: enough for load
/// balance, few enough that the per-chunk accumulators stay small.
fn k9_round_chunks(nblk_pairs: usize) -> usize {
    let t = k9_threads();
    if t <= 1 || nblk_pairs < 2 * K9_CHUNK_BLK {
        return 1;
    }
    (t * 8).min(nblk_pairs.div_ceil(K9_CHUNK_BLK)).max(1)
}

/// Threaded out-of-place fold: dst[m] over the block range, chunked.
pub(crate) fn k9_fold_oop_par(kern: &KKern, src: &[u32], dst: &mut [u32], r: &[u32; K_DEG], nblk: usize) {
    if k9_threads() <= 1 || nblk <= K9_CHUNK_BLK {
        return k9_fold_oop_blocks(kern, src, dst, r, nblk);
    }
    let kern = *kern;
    let r = *r;
    let dst = &mut dst[..nblk * KBLK];
    let src = &src[..2 * nblk * KBLK];
    k9_pooled(|| {
        use rayon::prelude::*;
        dst.par_chunks_mut(K9_CHUNK_BLK * KBLK).enumerate().for_each(|(c, dchunk)| {
            let m0 = c * K9_CHUNK_BLK;
            let n = dchunk.len() / KBLK;
            k9_fold_oop_blocks(&kern, &src[2 * m0 * KBLK..2 * (m0 + n) * KBLK], dchunk, &r, n);
        });
    });
}

/// Threaded in-place a[i] += b[i]*r over full blocks.
pub(crate) fn k9_mul_fixed_add_par(kern: &KKern, a_io: &mut [u32], b: &[u32], r: &[u32; K_DEG], nblk: usize) {
    if k9_threads() <= 1 || nblk <= K9_CHUNK_BLK {
        return k9_mul_fixed_add_blocks(kern, a_io, b, r, nblk);
    }
    let kern = *kern;
    let r = *r;
    let a_io = &mut a_io[..nblk * KBLK];
    let b = &b[..nblk * KBLK];
    k9_pooled(|| {
        use rayon::prelude::*;
        a_io.par_chunks_mut(K9_CHUNK_BLK * KBLK)
            .zip(b.par_chunks(K9_CHUNK_BLK * KBLK))
            .for_each(|(ac, bc)| k9_mul_fixed_add_blocks(&kern, ac, bc, &r, ac.len() / KBLK));
    });
}

/// Threaded broadcast add over full blocks (in place).
pub(crate) fn k9_addc_par(kern: &KKern, t: &mut [u32], c: &[u32; K_DEG], nblk: usize) {
    if k9_threads() <= 1 || nblk <= K9_CHUNK_BLK {
        return k9_addc_blocks(kern, t, c, nblk);
    }
    let kern = *kern;
    let c = *c;
    let t = &mut t[..nblk * KBLK];
    k9_pooled(|| {
        use rayon::prelude::*;
        t.par_chunks_mut(K9_CHUNK_BLK * KBLK).for_each(|tc| k9_addc_blocks(&kern, tc, &c, tc.len() / KBLK));
    });
}

/// Threaded eq doubling in place: the table's current half (half_nblk
/// full blocks) is split from its mirror and both are chunked in
/// lock-step.
pub(crate) fn k9_eq_double_par(kern: &KKern, d_io: &mut [u32], half_nblk: usize, zbar: &[u32; K_DEG], z: &[u32; K_DEG]) {
    if k9_threads() <= 1 || half_nblk <= K9_CHUNK_BLK {
        return k9_eq_double_blocks(kern, d_io, half_nblk, zbar, z);
    }
    let kern = *kern;
    let (zbar, z) = (*zbar, *z);
    let (lo, up) = d_io[..2 * half_nblk * KBLK].split_at_mut(half_nblk * KBLK);
    k9_pooled(|| {
        use rayon::prelude::*;
        lo.par_chunks_mut(K9_CHUNK_BLK * KBLK)
            .zip(up.par_chunks_mut(K9_CHUNK_BLK * KBLK))
            .for_each(|(lc, uc)| k9_eq_double_split_blocks(&kern, lc, uc, lc.len() / KBLK, &zbar, &z));
    });
}

/// Threaded projective-tree layer step: output blocks are independent.
pub(crate) fn k9_tree_step_par(kern: &KKern, cp: &[u32], cq: &[u32], np: &mut [u32], nq: &mut [u32], nblk: usize) {
    if k9_threads() <= 1 || nblk <= K9_CHUNK_BLK {
        return k9_tree_step(kern, cp, cq, np, nq, nblk);
    }
    let kern = *kern;
    let (cp, cq) = (&cp[..2 * nblk * KBLK], &cq[..2 * nblk * KBLK]);
    let (np, nq) = (&mut np[..nblk * KBLK], &mut nq[..nblk * KBLK]);
    k9_pooled(|| {
        use rayon::prelude::*;
        np.par_chunks_mut(K9_CHUNK_BLK * KBLK)
            .zip(nq.par_chunks_mut(K9_CHUNK_BLK * KBLK))
            .enumerate()
            .for_each(|(c, (npc, nqc))| {
                let m0 = c * K9_CHUNK_BLK;
                let n = npc.len() / KBLK;
                k9_tree_step(&kern, &cp[2 * m0 * KBLK..2 * (m0 + n) * KBLK], &cq[2 * m0 * KBLK..2 * (m0 + n) * KBLK], npc, nqc, n);
            });
    });
}

/// Threaded five-table round kernel: per-chunk lazy planes summed in
/// index order into acc_lo/acc_hi (exact integer sums — identical for any
/// chunking, see the section note).
#[allow(clippy::too_many_arguments)]
pub(crate) fn k9_round_g5_par(
    kern: &KKern,
    eq: &[u32],
    pl: &[u32],
    p1: &[u32],
    q0: &[u32],
    q1: &[u32],
    nblk_pairs: usize,
    nodes: &[u64],
    consts: Option<&[[[u32; K_DEG]; 4]]>,
    acc_lo: &mut [u64],
    acc_hi: &mut [u64],
) {
    let n_chunks = k9_round_chunks(nblk_pairs);
    if n_chunks <= 1 {
        return k9_round_g5_blocks(kern, eq, pl, p1, q0, q1, nblk_pairs, nodes, consts, acc_lo, acc_hi);
    }
    let per = nblk_pairs.div_ceil(n_chunks);
    let acc_words = nodes.len() * 31 * KL;
    let kern = *kern;
    let partials: Vec<(Vec<u64>, Vec<u64>)> = k9_pooled(|| {
        use rayon::prelude::*;
        (0..n_chunks)
            .into_par_iter()
            .map(|c| {
                let m0 = (c * per).min(nblk_pairs);
                let m1 = ((c + 1) * per).min(nblk_pairs);
                let mut lo = vec![0u64; acc_words];
                let mut hi = vec![0u64; acc_words];
                if m1 > m0 {
                    let (w0, w1) = (2 * m0 * KBLK, 2 * m1 * KBLK);
                    k9_round_g5_blocks(
                        &kern, &eq[w0..w1], &pl[w0..w1], &p1[w0..w1], &q0[w0..w1], &q1[w0..w1], m1 - m0, nodes,
                        consts, &mut lo, &mut hi,
                    );
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

/// Threaded pack of boxed K-elements into a fresh table (positional).
pub(crate) fn k9_pack_par(v: &[KElem]) -> KTab {
    let mut t = KTab::zeroed(v.len());
    let nblk = v.len() / KL;
    if k9_threads() <= 1 || nblk <= K9_CHUNK_BLK {
        for (i, e) in v.iter().enumerate() {
            t.set(i, e);
        }
        return t;
    }
    let full = nblk * KBLK;
    {
        let d = &mut t.d[..full];
        k9_pooled(|| {
            use rayon::prelude::*;
            d.par_chunks_mut(K9_CHUNK_BLK * KBLK).enumerate().for_each(|(c, dc)| {
                let i0 = c * K9_CHUNK_BLK * KL;
                let n = dc.len() / KBLK * KL;
                for i in 0..n {
                    let e = &v[i0 + i];
                    let base = (i / KL) * KBLK + (i % KL);
                    for j in 0..K_DEG {
                        debug_assert!(e[j] < (1 << 31));
                        dc[base + j * KL] = e[j] as u32;
                    }
                }
            });
        });
    }
    for i in nblk * KL..v.len() {
        t.set(i, &v[i]);
    }
    t
}

impl KField {
    /// [UPERF2-A] Fold a packed table via an out-of-place threaded fold
    /// into `scratch` (grown once, then swapped in — no allocation after
    /// the first round of a layer). Identical values to `kt_fold_inplace`.
    /// Sizes below a full output block take the scalar staging path.
    pub(crate) fn kt_fold_par(&self, t: &mut KTab, scratch: &mut Vec<u32>, r: &KElem) {
        let kern = self.kern.as_ref().expect("kt_fold_par requires the bulk kernel");
        let n_out = t.n / 2;
        if n_out >= KL {
            debug_assert_eq!(n_out % KL, 0, "power-of-two tables only");
            let nblk = n_out / KL;
            if scratch.len() < nblk * KBLK {
                scratch.resize(nblk * KBLK, 0);
            }
            k9_fold_oop_par(kern, &t.d, scratch, &kop(r), nblk);
            std::mem::swap(&mut t.d, scratch);
            t.n = n_out;
            t.d.truncate(nblk * KBLK);
        } else {
            let mut out = KTab::zeroed(n_out);
            for i in 0..n_out {
                let (a, b) = (t.get(2 * i), t.get(2 * i + 1));
                out.set(i, &self.add(&a, &self.mul(r, &self.sub(&b, &a))));
            }
            *t = out;
        }
    }

    /// [UPERF2-A] The threaded eq-table build (same in-place doubling,
    /// the doubling step chunked across threads); `kt_eq_table_ref` is
    /// the pre-change body. Identical values.
    pub(crate) fn kt_eq_table_par(&self, z: &[KElem]) -> KTab {
        let kern = self.kern.as_ref().expect("kt_eq_table requires the bulk kernel");
        assert!(z.len() <= K9_MAX_LEAVES.trailing_zeros() as usize, "K9 eq table cap exceeded");
        let mut t = KTab::zeroed(1usize << z.len());
        t.set(0, &self.one());
        let mut half = 1usize;
        for zv in z {
            let zbar = self.sub(&self.one(), zv);
            if half >= KL {
                k9_eq_double_par(kern, &mut t.d, half / KL, &kop(&zbar), &kop(zv));
            } else {
                for i in 0..half {
                    let a = t.get(i);
                    t.set(i + half, &self.mul(&a, zv));
                    t.set(i, &self.mul(&a, &zbar));
                }
            }
            half *= 2;
        }
        t
    }

    /// [UPERF2-A] In-place a[i] += b[i]*r over two same-size packed tables
    /// (threaded; scalar tail below a full block).
    pub(crate) fn kt_mul_fixed_add_inplace(&self, a: &mut KTab, b: &KTab, r: &KElem) {
        let kern = self.kern.as_ref().expect("kt_mul_fixed_add_inplace requires the bulk kernel");
        assert_eq!(a.n, b.n);
        let nblk = a.n / KL;
        if nblk > 0 {
            k9_mul_fixed_add_par(kern, &mut a.d, &b.d, &kop(r), nblk);
        }
        for i in nblk * KL..a.n {
            let v = self.add(&a.get(i), &self.mul(&b.get(i), r));
            a.set(i, &v);
        }
    }

    /// [UPERF2-A] Broadcast add t[i] += c over a packed table (threaded
    /// full blocks; scalar tail).
    pub(crate) fn kt_addc(&self, t: &mut KTab, c: &KElem) {
        let kern = self.kern.as_ref().expect("kt_addc requires the bulk kernel");
        let nblk = t.n / KL;
        if nblk > 0 {
            k9_addc_par(kern, &mut t.d, &kop(c), nblk);
        }
        for i in nblk * KL..t.n {
            let v = self.add(&t.get(i), c);
            t.set(i, &v);
        }
    }
}

// --- table-level operations (bulk when full blocks exist, scalar tails) ---

impl KField {
    /// Fold a packed table IN PLACE: T'[i] = T[2i] + r (T[2i+1] - T[2i]).
    /// Halves t (capacity retained — no allocation, no memset on the hot
    /// path). Requires kern; sizes below a full block fall back to scalar
    /// ops staged through a fresh small table (cold path; preserves the
    /// trailing-lane zero-padding invariant). [U-PERF-PA] residue rebase.
    pub(crate) fn kt_fold_inplace(&self, t: &mut KTab, r: &KElem) {
        let kern = self.kern.as_ref().expect("kt_fold_inplace requires the bulk kernel");
        let n_out = t.n / 2;
        if n_out >= KL {
            debug_assert_eq!(n_out % KL, 0, "power-of-two tables only");
            k9_fold_blocks(kern, &mut t.d, &kop(r), n_out / KL);
            t.n = n_out;
            t.d.truncate(n_out.div_ceil(KL) * KBLK);
        } else {
            let mut out = KTab::zeroed(n_out);
            for i in 0..n_out {
                let (a, b) = (t.get(2 * i), t.get(2 * i + 1));
                out.set(i, &self.add(&a, &self.mul(r, &self.sub(&b, &a))));
            }
            *t = out;
        }
    }

    /// Elementwise fixed-operand product: out[i] = t[i] * r.
    pub(crate) fn kt_mul_fixed(&self, t: &KTab, r: &KElem) -> KTab {
        let kern = self.kern.as_ref().expect("kt_mul_fixed requires the bulk kernel");
        let mut out = KTab::zeroed(t.n);
        if t.n >= KL {
            let nblk = t.n / KL;
            k9_mul_fixed_blocks(kern, &t.d[..nblk * KBLK], &kop(r), &mut out.d[..nblk * KBLK], nblk);
            for i in nblk * KL..t.n {
                out.set(i, &self.mul(&t.get(i), r));
            }
        } else {
            for i in 0..t.n {
                out.set(i, &self.mul(&t.get(i), r));
            }
        }
        out
    }

    /// The packed eq table over a point (little-endian, same convention as
    /// gkr::eq_table), built IN PLACE: ONE final-size allocation, then a
    /// doubling step per variable inside it (scalar staging below a full
    /// block, the eq-double kernel above). [U-PERF-PA] residue rebase: the
    /// out-of-place original allocated a fresh double-size table per
    /// variable (~2x the final size in cumulative churn per eq build —
    /// once per descent LAYER in the hot loops).
    pub(crate) fn kt_eq_table(&self, z: &[KElem]) -> KTab {
        let kern = self.kern.as_ref().expect("kt_eq_table requires the bulk kernel");
        assert!(z.len() <= K9_MAX_LEAVES.trailing_zeros() as usize, "K9 eq table cap exceeded");
        let mut t = KTab::zeroed(1usize << z.len());
        t.set(0, &self.one());
        let mut half = 1usize;
        for zv in z {
            let zbar = self.sub(&self.one(), zv);
            if half >= KL {
                k9_eq_double_blocks(kern, &mut t.d, half / KL, &kop(&zbar), &kop(zv));
            } else {
                for i in 0..half {
                    let a = t.get(i);
                    t.set(i + half, &self.mul(&a, zv));
                    t.set(i, &self.mul(&a, &zbar));
                }
            }
            half *= 2;
        }
        t
    }

    /// Bulk MLE evaluation of a packed table at a point (fold order =
    /// variable 0 first, exactly sumcheck::mle_eval). Folds in place —
    /// the pack is the only allocation.
    pub(crate) fn kt_mle_eval(&self, mut t: KTab, point: &[KElem]) -> KElem {
        assert_eq!(t.n, 1 << point.len());
        for r in point {
            self.kt_fold_inplace(&mut t, r);
        }
        t.get(0)
    }

    /// Finalize one node of the round-poly accumulator: 31 exact u128
    /// coefficient sums (lanes added) -> canonical K-element with the
    /// Y^16 = s fold. Cold path: a few per round.
    pub(crate) fn kt_round_g_finalize(&self, acc_lo: &[u64], acc_hi: &[u64]) -> KElem {
        assert_eq!(acc_lo.len(), 31 * KL, "K9 finalize lo layout");
        assert_eq!(acc_hi.len(), 31 * KL, "K9 finalize hi layout");
        let q = self.zq.q as u128;
        let s = self.s as u128;
        let wide: Vec<u128> = (0..31)
            .map(|t| {
                let mut v: u128 = 0;
                for l in 0..KL {
                    v += acc_lo[t * KL + l] as u128 + ((acc_hi[t * KL + l] as u128) << 32);
                }
                v
            })
            .collect();
        (0..K_DEG)
            .map(|t| {
                let hi = if t + K_DEG < 31 { wide[t + K_DEG] % q } else { 0 };
                ((wide[t] + s * hi) % q) as u64
            })
            .collect()
    }
}

/// U-K9 hook for lookup.rs's weight stream: elementwise fixed-operand
/// product over KElems, bulk when the kernel is live (bit-identical to the
/// scalar map).
pub fn bulk_mul_fixed_kelems(kf: &KField, v: &[KElem], r: &KElem) -> Vec<KElem> {
    if kf.kern.is_some() && v.len() >= KL {
        let t = KTab::from_kelems(v);
        kf.kt_mul_fixed(&t, r).to_kelems()
    } else {
        v.iter().map(|e| kf.mul(e, r)).collect()
    }
}

/// Battery-only forced-portable packed path. This exercises the exact SoA
/// layout and reduction body without AVX2 dispatch, unlike the boxed scalar
/// oracle which intentionally uses different code.
pub fn harness_bulk_mul_fixed_portable(
    kf: &KField,
    v: &[KElem],
    r: &KElem,
) -> Vec<KElem> {
    let kern = kf.kern.as_ref().expect("portable packed harness needs K9 kernel");
    let t = KTab::from_kelems(v);
    let mut out = KTab::zeroed(v.len());
    let nblk = v.len() / KL;
    if nblk > 0 {
        mul_fixed_body(
            kern,
            &t.d[..nblk * KBLK],
            &kop(r),
            &mut out.d[..nblk * KBLK],
            nblk,
        );
    }
    for i in nblk * KL..v.len() {
        out.set(i, &kf.mul(&t.get(i), r));
    }
    out.to_kelems()
}

/// Battery-only forced-portable packed fold, including its deinterleave
/// boundary and (post-residue) the IN-PLACE aliasing discipline: the
/// full blocks are folded inside the staged source buffer exactly as the
/// protocol path does. Input length must be even, as in the protocol
/// fold.
pub fn harness_fold_portable(kf: &KField, v: &[KElem], r: &KElem) -> Vec<KElem> {
    assert!(!v.is_empty() && v.len() % 2 == 0, "portable fold input");
    let kern = kf.kern.as_ref().expect("portable packed harness needs K9 kernel");
    let mut t = KTab::from_kelems(v);
    let n_out = v.len() / 2;
    let nblk = n_out / KL;
    if nblk > 0 {
        fold_body(kern, &mut t.d, &kop(r), nblk);
    }
    let mut out = KTab::zeroed(n_out);
    out.d[..nblk * KBLK].copy_from_slice(&t.d[..nblk * KBLK]);
    // The scalar tail reads its source pairs at element indices >=
    // 2*nblk*KL — beyond the region the in-place fold wrote, so they are
    // still the original values.
    for i in nblk * KL..n_out {
        let (a, b) = (t.get(2 * i), t.get(2 * i + 1));
        out.set(i, &kf.add(&a, &kf.mul(r, &kf.sub(&b, &a))));
    }
    out.to_kelems()
}

/// Battery-only forced-portable packed eq-table build (the in-place
/// doubling path without AVX2 dispatch), for the [U-K9] boundary legs.
pub fn harness_eq_table_portable(kf: &KField, z: &[KElem]) -> Vec<KElem> {
    let kern = kf.kern.as_ref().expect("portable packed harness needs K9 kernel");
    assert!(z.len() <= K9_MAX_LEAVES.trailing_zeros() as usize);
    let mut t = KTab::zeroed(1usize << z.len());
    t.set(0, &kf.one());
    let mut half = 1usize;
    for zv in z {
        let zbar = kf.sub(&kf.one(), zv);
        if half >= KL {
            eq_double_body(kern, &mut t.d, half / KL, &kop(&zbar), &kop(zv));
        } else {
            for i in 0..half {
                let a = t.get(i);
                t.set(i + half, &kf.mul(&a, zv));
                t.set(i, &kf.mul(&a, &zbar));
            }
        }
        half *= 2;
    }
    t.to_kelems()
}

// ---------------------------------------------------------------------------
// [U-PERF-PA] B-D3 attribution harnesses (battery/bench-only, no protocol
// use): the same elementwise product on the same SoA layout with the
// arithmetic DISCIPLINE selectable, so the kernel speedup can be split
// into its two claimed sources (M4 Section 7' priced "reduction
// discipline" and "8x lane occupancy" separately):
//
//   scalar oracle      — boxed slot_mul_g per element: u128 wide
//                        accumulation, TWO u128 `%` per output
//                        coefficient, a fresh Vec per product.
//   packed "eager"     — slot_mul_g's EXACT discipline (u128 wide, `%`
//                        per output) transplanted onto the lane-blocked
//                        SoA layout with no allocation: isolates the
//                        LAYOUT/LANE-OCCUPANCY share.
//   packed lazy (ship) — split u64 planes + ONE division-free
//                        special-form reduction per output coefficient:
//                        the additional factor isolates the
//                        REDUCTION/ARITHMETIC-DISCIPLINE share.
//
// All three produce bit-identical values (asserted in the battery).

/// slot_mul_g's discipline on the packed layout (see above). Not a
/// protocol kernel — attribution harness only.
fn mul_elem_eager_body(kern: &KKern, a: &[u32], b: &[u32], dst: &mut [u32], nblk: usize) {
    let words = nblk.checked_mul(KBLK).expect("K9 eager-mul size overflow");
    assert!(a.len() >= words && b.len() >= words && dst.len() >= words, "K9 eager-mul layout");
    let q = kern.q as u128;
    let s = kern.s;
    let zq_mul = |x: u64, y: u64| -> u64 { (x as u128 * y as u128 % q) as u64 };
    let zq_add = |x: u64, y: u64| -> u64 {
        let v = x + y;
        if v >= kern.q { v - kern.q } else { v }
    };
    let mut wide = [0u128; 31 * KL];
    for m in 0..nblk {
        let ab = &a[m * KBLK..(m + 1) * KBLK];
        let bb = &b[m * KBLK..(m + 1) * KBLK];
        wide.fill(0);
        for i in 0..K_DEG {
            for j in 0..K_DEG {
                let t = i + j;
                for l in 0..KL {
                    wide[t * KL + l] += ab[i * KL + l] as u128 * bb[j * KL + l] as u128;
                }
            }
        }
        for t in 0..K_DEG {
            for l in 0..KL {
                let lo = (wide[t * KL + l] % q) as u64;
                let hi = if t + K_DEG < 31 { (wide[(t + K_DEG) * KL + l] % q) as u64 } else { 0 };
                dst[m * KBLK + t * KL + l] = zq_add(lo, zq_mul(s, hi)) as u32;
            }
        }
    }
}

/// Apply the packed elementwise product `reps` times (out feeds the next
/// rep) with the discipline selectable; packs once so the per-rep cost
/// is the kernel body alone. Values are discipline-independent.
pub fn harness_mul_elem_reps(
    kf: &KField,
    a: &[KElem],
    b: &[KElem],
    reps: usize,
    eager: bool,
) -> Vec<KElem> {
    assert!(reps >= 1 && a.len() == b.len() && a.len() % KL == 0, "attribution harness shape");
    let kern = kf.kern.as_ref().expect("packed harness needs K9 kernel");
    let nblk = a.len() / KL;
    let mut cur = KTab::from_kelems(a);
    let tb = KTab::from_kelems(b);
    let mut out = KTab::zeroed(a.len());
    for _ in 0..reps {
        if eager {
            mul_elem_eager_body(kern, &cur.d, &tb.d, &mut out.d, nblk);
        } else {
            k9_mul_elem_blocks(kern, &cur.d, &tb.d, &mut out.d, nblk);
        }
        std::mem::swap(&mut cur, &mut out);
    }
    cur.to_kelems()
}

/// LKP-5: the digest freezing the slot-field constants — q, k,
/// slot_deg and every slot root. Any parameter move that changes the
/// field the lookup transcript lives in must trip this row.
pub fn slot_field_digest(ctx: &RingCtx) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"lkp5-slot-field-v1");
    hasher.update(ctx.zq.q.to_le_bytes());
    hasher.update((ctx.k as u64).to_le_bytes());
    hasher.update((ctx.slot_deg as u64).to_le_bytes());
    for &r in &ctx.slot_roots {
        hasher.update(r.to_le_bytes());
    }
    hasher.finalize().into()
}

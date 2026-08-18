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
/// [UPERF2-G] Large buffers are recycled through the table arena
/// (`k9_arena_*`): `zeroed` hands back an all-zero table either way (a
/// recycled buffer is memset), `recycled` may hand back a DIRTY buffer
/// (callers that overwrite every element they will ever read); `Drop`
/// returns the buffer to the arena.
pub(crate) struct KTab {
    pub n: usize,
    pub d: Vec<u32>,
}

impl Drop for KTab {
    fn drop(&mut self) {
        k9_arena_give(std::mem::take(&mut self.d));
    }
}

impl KTab {
    fn words_for(n: usize) -> usize {
        assert!(n <= K9_MAX_LEAVES, "K9 packed-table cap exceeded");
        n.div_ceil(KL).checked_mul(KBLK).expect("K9 packed-table allocation overflow")
    }

    pub(crate) fn zeroed(n: usize) -> KTab {
        let words = KTab::words_for(n);
        KTab { n, d: k9_arena_take(words, true) }
    }

    /// [UPERF2-G] A table whose contents are UNSPECIFIED (possibly a
    /// recycled buffer's old values): for callers that write every element
    /// they will read (fold outputs, eq tables, tree layers, the fused
    /// descent's state-1 tables). Trailing-lane zero padding is NOT
    /// guaranteed — full-block sizes only on the packed paths.
    pub(crate) fn recycled(n: usize) -> KTab {
        let words = KTab::words_for(n);
        KTab { n, d: k9_arena_take(words, false) }
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
    let mut e0 = [[0u32; KBLK]; 5];
    let mut e1 = [[0u32; KBLK]; 5];
    let mut st = RoundG5State::new();
    for m in 0..nblk_pairs {
        let srcs = [eq, pl, p1, q0, q1];
        for (k, s) in srcs.iter().enumerate() {
            let (a, b) = (&mut e0[k], &mut e1[k]);
            deint_pair(s, m, a, b);
        }
        round_g5_pair(kern, &e0, &e1, nodes, consts, acc_lo, acc_hi, &mut st);
    }
}

/// [UPERF2-G] The per-pair-block staging state of the five-table node loop
/// (the running extrapolation, the masked operand copies, the reduced
/// wire) — hoisted out of `round_g5_body` so the fused kernels below share
/// its node loop verbatim.
struct RoundG5State {
    dd: [[u32; KBLK]; 5],
    cur: [[u32; KBLK]; 5],
    op: [[u32; KBLK]; 4],
    tred: [u32; KBLK],
}

impl RoundG5State {
    #[inline(always)]
    fn new() -> RoundG5State {
        RoundG5State { dd: [[0u32; KBLK]; 5], cur: [[0u32; KBLK]; 5], op: [[0u32; KBLK]; 4], tred: [0u32; KBLK] }
    }
}

/// [UPERF2-G] The node loop of `round_g5_body` for ONE pair-block whose
/// (even, odd) lane-blocks of the five tables (eq, pl, p1, q0, q1) are
/// staged in e0/e1: successive-add extrapolation to every node x != 1, the
/// masked add-constants, wire = PL Q1 + P1 Q0 with one deferred reduction,
/// eq * wire into the persistent lazy node planes. Byte-for-byte the loop
/// body `round_g5_body` had inline (a code motion — the values it
/// produces are the same integers).
#[inline(always)]
fn round_g5_pair(
    kern: &KKern,
    e0: &[[u32; KBLK]; 5],
    e1: &[[u32; KBLK]; 5],
    nodes: &[u64],
    consts: Option<&[[[u32; K_DEG]; 4]]>,
    acc_lo: &mut [u64],
    acc_hi: &mut [u64],
    st: &mut RoundG5State,
) {
    let q32 = kern.q as u32;
    for k in 0..5 {
        for x in 0..KBLK {
            st.dd[k][x] = subm32(e1[k][x], e0[k][x], q32);
        }
        st.cur[k] = e1[k];
    }
    let mut prev_x = 1u64;
    for (ni, &x) in nodes.iter().enumerate() {
        let tabs: [&[u32; KBLK]; 5] = if x == 0 {
            [&e0[0], &e0[1], &e0[2], &e0[3], &e0[4]]
        } else {
            while prev_x < x {
                for k in 0..5 {
                    for xx in 0..KBLK {
                        st.cur[k][xx] = addm32(st.cur[k][xx], st.dd[k][xx], q32);
                    }
                }
                prev_x += 1;
            }
            [&st.cur[0], &st.cur[1], &st.cur[2], &st.cur[3], &st.cur[4]]
        };
        let use_ops = if let Some(cs) = consts {
            let c = &cs[ni];
            for k in 0..4 {
                for j in 0..K_DEG {
                    for l in 0..KL {
                        st.op[k][j * KL + l] = addm32(tabs[k + 1][j * KL + l], c[k][j], q32);
                    }
                }
            }
            true
        } else {
            false
        };
        let (vpl, vp1, vq0, vq1) = if use_ops {
            (&st.op[0], &st.op[1], &st.op[2], &st.op[3])
        } else {
            (tabs[1], tabs[2], tabs[3], tabs[4])
        };
        // wire = PL Q1 + P1 Q0: 2 MACs, one reduction
        let mut lo = [0u64; 31 * KL];
        let mut hi = [0u64; 31 * KL];
        mac_block(vpl, vq1, &mut lo, &mut hi);
        mac_block(vp1, vq0, &mut lo, &mut hi);
        red_block(kern, &lo, &hi, &mut st.tred);
        let alo: &mut [u64; 31 * KL] =
            (&mut acc_lo[ni * 31 * KL..(ni + 1) * 31 * KL]).try_into().unwrap();
        let ahi: &mut [u64; 31 * KL] =
            (&mut acc_hi[ni * 31 * KL..(ni + 1) * 31 * KL]).try_into().unwrap();
        mac_block(tabs[0], &st.tred, alo, ahi);
    }
}

// --- [UPERF2-G] fused descent kernels ---
//
// The fast masked-descent rounds loop (gkr_masked::masked_rounds_bulk)
// streams, per b-round, its five work tables (eq, PL, p1, q0, q1) through
// the round kernel and then again through the folds: 2.5 x table bytes per
// round. The fused kernel folds the PREVIOUS round's challenge on the fly:
// round t's kernel reads the state-(t-1) tables (4 blocks per output
// pair-block), computes the two state-t blocks of each table by
// `fold_oop_body`'s arithmetic (+ the masked add-constants), writes them
// back IN PLACE, and runs the node loop on them — 1.5 x table bytes per
// round, no fold scratch. Rounds 0 and 1 go one step further and read the
// tree's layer j+1 directly (the extract deinterleave + PL = p0 + lambda
// q0 formed on the fly): the first materialized work tables are state 1
// (half the size). Every stored value is the canonical result of the same
// field expression the eager path stores (fold, then add-constant, then
// PL; each op exact modular on canonical u32 operands; PL(fold(p0) +
// c_p0, fold(q0) + c_q0) == fold(PL0) + c_pl as field elements, hence as
// bytes), and the node planes are exact integer sums of the same
// (eq, wire) terms — so the round polynomials, boundaries and openings are
// bit-identical, whatever the chunking (`uperf-g descent-battery`, four
// ways).
//
// IN-PLACE HAZARD (the fold-fused write): output pair-block m' writes
// state-t blocks [2m', 2m'+2) and reads state-(t-1) blocks [4m', 4m'+4) of
// the SAME buffer. A pair-block range [A, 2A) therefore writes [2A, 4A) —
// exactly what the range [A/2, A) reads — and reads [4A, 8A) — what the
// range [2A, 4A) writes. Hence the RUNG schedule of `k9_fused_round_par`:
// the prefix [0, A0) is folded through a small scratch (its reads [0, 4A0)
// overlap its own writes), then the rungs [A0, 2A0), [2A0, 4A0), .. run in
// that order, each fully parallel over its live pair-blocks (a rung's
// reads never meet its own writes: 4A > 2·2A). Positional writes, no
// reduction: any thread count is identical.

/// Fused kernel modes.
pub(crate) const FUSE_FOLD: u8 = 0; // sources: the five state-(t-1) tables; writes state t in place
pub(crate) const FUSE_EXTRACT: u8 = 1; // round 0: eq (state 0) + the tree layer; no writes
pub(crate) const FUSE_EXTRACT_FOLD: u8 = 2; // round 1: eq (state 0) + the tree layer; writes state 1 (eq in place, four fresh tables)

/// The sources of one fused job (a contiguous run of `n` output pair-blocks).
pub(crate) struct FusedSrc<'a> {
    pub mode: u8,
    /// eq: 4n blocks (FOLD / EXTRACT_FOLD: state t-1) or 2n blocks (EXTRACT:
    /// state t). For the extract modes this is the instance-local slice of
    /// the b-part eq table (eq(zeta_b, b)); `eq_scale` = E(e) multiplies
    /// each block on the fly (None: the slice is the eq itself) — the same
    /// mul_fixed arithmetic the eager path used to materialize the joint
    /// table, so the same canonical values.
    pub eq: &'a [u32],
    pub eq_scale: Option<[u32; K_DEG]>,
    /// FOLD: pl, p1, q0, q1 at state t-1 (4n blocks each). EXTRACT*: t[0] =
    /// the instance's p layer, t[1] = its q layer (4n / 8n blocks); t[2],
    /// t[3] unused (empty).
    pub t: [&'a [u32]; 4],
    /// The pending fold challenge (FOLD, EXTRACT_FOLD).
    pub r_prev: [u32; K_DEG],
    /// PL = p0 + lambda q0 (EXTRACT*).
    pub lambda: [u32; K_DEG],
    /// Add-constants after the fold (the masked t == 0 child-mask terms):
    /// FOLD: [c_pl, c_p1, c_q0, c_q1] on the four non-eq tables;
    /// EXTRACT_FOLD: [c_p0, c_p1, c_q0, c_q1] on the folded p0/p1/q0/q1
    /// (PL is formed from the shifted p0, q0). None = no shift.
    pub fold_consts: Option<[[u32; K_DEG]; 4]>,
}

/// The destinations of one fused job: 2n blocks each (empty when the mode
/// writes nothing).
pub(crate) struct FusedDst<'a> {
    pub eq: &'a mut [u32],
    pub t: [&'a mut [u32]; 4],
}

/// Deinterleave two explicit lane blocks (a = block 2m, b = block 2m+1 of a
/// table): t0 the even elements, t1 the odd — `deint_pair` on operands.
#[inline(always)]
fn deint_blocks(a: &[u32; KBLK], b: &[u32; KBLK], t0: &mut [u32; KBLK], t1: &mut [u32; KBLK]) {
    for j in 0..K_DEG {
        for l in 0..4 {
            t0[j * KL + l] = a[j * KL + 2 * l];
            t1[j * KL + l] = a[j * KL + 2 * l + 1];
            t0[j * KL + 4 + l] = b[j * KL + 2 * l];
            t1[j * KL + 4 + l] = b[j * KL + 2 * l + 1];
        }
    }
}

/// One folded block from the source pair (a, b) = (2m, 2m+1): out = t0 +
/// r (t1 - t0) [+ c] with (t0, t1) = deint(a, b) — `fold_oop_body`'s
/// per-block arithmetic followed by `addc_body`'s broadcast add.
#[inline(always)]
fn fold_pair_blocks(
    kern: &KKern,
    a: &[u32; KBLK],
    b: &[u32; KBLK],
    r: &[u32; K_DEG],
    c: Option<&[u32; K_DEG]>,
    out: &mut [u32; KBLK],
) {
    let q32 = kern.q as u32;
    let mut t0 = [0u32; KBLK];
    let mut t1 = [0u32; KBLK];
    let mut d = [0u32; KBLK];
    deint_blocks(a, b, &mut t0, &mut t1);
    for x in 0..KBLK {
        d[x] = subm32(t1[x], t0[x], q32);
    }
    let mut lo = [0u64; 31 * KL];
    let mut hi = [0u64; 31 * KL];
    mac_block_fixed(&d, r, &mut lo, &mut hi);
    red_block(kern, &lo, &hi, out);
    for x in 0..KBLK {
        out[x] = addm32(t0[x], out[x], q32);
    }
    if let Some(c) = c {
        for j in 0..K_DEG {
            for l in 0..KL {
                out[j * KL + l] = addm32(out[j * KL + l], c[j], q32);
            }
        }
    }
}

/// out = a * r on one lane block — `mul_fixed_body`'s per-block arithmetic.
#[inline(always)]
fn mul_fixed_block(kern: &KKern, a: &[u32; KBLK], r: &[u32; K_DEG], out: &mut [u32; KBLK]) {
    let mut lo = [0u64; 31 * KL];
    let mut hi = [0u64; 31 * KL];
    mac_block_fixed(a, r, &mut lo, &mut hi);
    red_block(kern, &lo, &hi, out);
}

/// PL block = p0 + lambda * q0 on lane blocks — `mul_fixed_add_body`'s
/// per-block arithmetic.
#[inline(always)]
fn pl_block(kern: &KKern, p0: &[u32; KBLK], q0: &[u32; KBLK], lambda: &[u32; K_DEG], out: &mut [u32; KBLK]) {
    let q32 = kern.q as u32;
    let mut lo = [0u64; 31 * KL];
    let mut hi = [0u64; 31 * KL];
    mac_block_fixed(q0, lambda, &mut lo, &mut hi);
    red_block(kern, &lo, &hi, out);
    for x in 0..KBLK {
        out[x] = addm32(p0[x], out[x], q32);
    }
}

#[inline(always)]
fn blk(s: &[u32], i: usize) -> &[u32; KBLK] {
    s[i * KBLK..(i + 1) * KBLK].try_into().unwrap()
}

#[inline(always)]
fn put_blk(d: &mut [u32], i: usize, b: &[u32; KBLK]) {
    d[i * KBLK..(i + 1) * KBLK].copy_from_slice(b);
}

/// The fused round kernel over `n` output pair-blocks (see the section
/// note): per pair-block the mode's fetch (fold / extract / extract+fold,
/// with the writes), then `round_g5_pair` on the staged (even, odd) blocks.
#[inline(always)]
fn fused_round_body(
    kern: &KKern,
    s: &FusedSrc,
    d: &mut FusedDst,
    n: usize,
    nodes: &[u64],
    node_consts: Option<&[[[u32; K_DEG]; 4]]>,
    acc_lo: &mut [u64],
    acc_hi: &mut [u64],
) {
    let pair_terms = n.checked_mul(KL).expect("K9 fused round term-count overflow");
    assert!(pair_terms <= K9_MAX_PAIR_TERMS, "K9 lazy-accumulator cap exceeded");
    let acc_words = nodes.len().checked_mul(31 * KL).expect("K9 round accumulator size overflow");
    assert!(acc_lo.len() >= acc_words && acc_hi.len() >= acc_words, "K9 fused accumulator layout");
    if let Some(cs) = node_consts {
        assert_eq!(cs.len(), nodes.len(), "K9 fused round constant layout");
    }
    let (w2, w4, w8) = (2 * n * KBLK, 4 * n * KBLK, 8 * n * KBLK);
    match s.mode {
        FUSE_FOLD => {
            assert!(s.eq.len() >= w4 && s.t.iter().all(|t| t.len() >= w4), "K9 fused fold source layout");
            assert!(d.eq.len() >= w2 && d.t.iter().all(|t| t.len() >= w2), "K9 fused fold dest layout");
        }
        FUSE_EXTRACT => {
            assert!(s.eq.len() >= w2 && s.t[0].len() >= w4 && s.t[1].len() >= w4, "K9 fused extract source layout");
        }
        FUSE_EXTRACT_FOLD => {
            assert!(s.eq.len() >= w4 && s.t[0].len() >= w8 && s.t[1].len() >= w8, "K9 fused extract-fold source layout");
            assert!(d.eq.len() >= w2 && d.t.iter().all(|t| t.len() >= w2), "K9 fused extract-fold dest layout");
        }
        _ => panic!("K9 fused round: unknown mode"),
    }
    let mut e0 = [[0u32; KBLK]; 5];
    let mut e1 = [[0u32; KBLK]; 5];
    let mut st = RoundG5State::new();
    let mut ba = [0u32; KBLK];
    let mut bb = [0u32; KBLK];
    // extract staging: state-0 blocks of p0/p1/q0/q1 (up to 4 each)
    let mut x0 = [[0u32; KBLK]; 4];
    let mut x1 = [[0u32; KBLK]; 4];
    let mut y0 = [[0u32; KBLK]; 4];
    let mut y1 = [[0u32; KBLK]; 4];
    let mut fa = [[0u32; KBLK]; 4];
    let mut fb = [[0u32; KBLK]; 4];
    for m in 0..n {
        match s.mode {
            FUSE_FOLD => {
                for k in 0..5 {
                    let src = if k == 0 { s.eq } else { s.t[k - 1] };
                    let c = if k == 0 { None } else { s.fold_consts.as_ref().map(|fc| &fc[k - 1]) };
                    fold_pair_blocks(kern, blk(src, 4 * m), blk(src, 4 * m + 1), &s.r_prev, c, &mut ba);
                    fold_pair_blocks(kern, blk(src, 4 * m + 2), blk(src, 4 * m + 3), &s.r_prev, c, &mut bb);
                    let dst: &mut [u32] = if k == 0 { &mut *d.eq } else { &mut *d.t[k - 1] };
                    put_blk(dst, 2 * m, &ba);
                    put_blk(dst, 2 * m + 1, &bb);
                    deint_blocks(&ba, &bb, &mut e0[k], &mut e1[k]);
                }
            }
            FUSE_EXTRACT => {
                match s.eq_scale.as_ref() {
                    None => deint_pair(s.eq, m, &mut e0[0], &mut e1[0]),
                    Some(sc) => {
                        mul_fixed_block(kern, blk(s.eq, 2 * m), sc, &mut ba);
                        mul_fixed_block(kern, blk(s.eq, 2 * m + 1), sc, &mut bb);
                        deint_blocks(&ba, &bb, &mut e0[0], &mut e1[0]);
                    }
                }
                // tree layer blocks 4m..4m+4: (p0, p1) state-0 blocks 2m, 2m+1
                deint_pair(s.t[0], 2 * m, &mut x0[0], &mut x1[0]);
                deint_pair(s.t[0], 2 * m + 1, &mut x0[1], &mut x1[1]);
                deint_pair(s.t[1], 2 * m, &mut y0[0], &mut y1[0]);
                deint_pair(s.t[1], 2 * m + 1, &mut y0[1], &mut y1[1]);
                pl_block(kern, &x0[0], &y0[0], &s.lambda, &mut ba);
                pl_block(kern, &x0[1], &y0[1], &s.lambda, &mut bb);
                deint_blocks(&ba, &bb, &mut e0[1], &mut e1[1]);
                deint_blocks(&x1[0], &x1[1], &mut e0[2], &mut e1[2]);
                deint_blocks(&y0[0], &y0[1], &mut e0[3], &mut e1[3]);
                deint_blocks(&y1[0], &y1[1], &mut e0[4], &mut e1[4]);
            }
            _ => {
                // eq: state-0 blocks 4m..4m+4 (b-part x E(e) on the fly) -> state-1 blocks 2m, 2m+1
                match s.eq_scale.as_ref() {
                    None => {
                        fold_pair_blocks(kern, blk(s.eq, 4 * m), blk(s.eq, 4 * m + 1), &s.r_prev, None, &mut ba);
                        fold_pair_blocks(kern, blk(s.eq, 4 * m + 2), blk(s.eq, 4 * m + 3), &s.r_prev, None, &mut bb);
                    }
                    Some(sc) => {
                        for i in 0..4 {
                            mul_fixed_block(kern, blk(s.eq, 4 * m + i), sc, &mut fa[i]);
                        }
                        fold_pair_blocks(kern, &fa[0], &fa[1], &s.r_prev, None, &mut ba);
                        fold_pair_blocks(kern, &fa[2], &fa[3], &s.r_prev, None, &mut bb);
                    }
                }
                put_blk(d.eq, 2 * m, &ba);
                put_blk(d.eq, 2 * m + 1, &bb);
                deint_blocks(&ba, &bb, &mut e0[0], &mut e1[0]);
                // tree layer blocks 8m..8m+8 -> state-0 blocks 4m..4m+4 of p0/p1 (x0/x1) and q0/q1 (y0/y1)
                for i in 0..4 {
                    deint_pair(s.t[0], 4 * m + i, &mut x0[i], &mut x1[i]);
                    deint_pair(s.t[1], 4 * m + i, &mut y0[i], &mut y1[i]);
                }
                let (cp0, cp1, cq0, cq1) = match s.fold_consts.as_ref() {
                    Some(fc) => (Some(&fc[0]), Some(&fc[1]), Some(&fc[2]), Some(&fc[3])),
                    None => (None, None, None, None),
                };
                // state-1 blocks (a = 2m, b = 2m+1) of p0, p1, q0, q1 (shifted)
                fold_pair_blocks(kern, &x0[0], &x0[1], &s.r_prev, cp0, &mut fa[0]);
                fold_pair_blocks(kern, &x0[2], &x0[3], &s.r_prev, cp0, &mut fb[0]);
                fold_pair_blocks(kern, &x1[0], &x1[1], &s.r_prev, cp1, &mut fa[1]);
                fold_pair_blocks(kern, &x1[2], &x1[3], &s.r_prev, cp1, &mut fb[1]);
                fold_pair_blocks(kern, &y0[0], &y0[1], &s.r_prev, cq0, &mut fa[2]);
                fold_pair_blocks(kern, &y0[2], &y0[3], &s.r_prev, cq0, &mut fb[2]);
                fold_pair_blocks(kern, &y1[0], &y1[1], &s.r_prev, cq1, &mut fa[3]);
                fold_pair_blocks(kern, &y1[2], &y1[3], &s.r_prev, cq1, &mut fb[3]);
                // PL = p0 + lambda q0 at state 1
                pl_block(kern, &fa[0], &fa[2], &s.lambda, &mut ba);
                pl_block(kern, &fb[0], &fb[2], &s.lambda, &mut bb);
                put_blk(d.t[0], 2 * m, &ba);
                put_blk(d.t[0], 2 * m + 1, &bb);
                deint_blocks(&ba, &bb, &mut e0[1], &mut e1[1]);
                for k in 1..4 {
                    put_blk(d.t[k], 2 * m, &fa[k]);
                    put_blk(d.t[k], 2 * m + 1, &fb[k]);
                    deint_blocks(&fa[k], &fb[k], &mut e0[k + 1], &mut e1[k + 1]);
                }
            }
        }
        round_g5_pair(kern, &e0, &e1, nodes, node_consts, acc_lo, acc_hi, &mut st);
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
// [UPERF2-G] fused descent round bodies
k9_kernel!(k9_fused_round_blocks, k9_fused_round_blocks_avx2, fused_round_body,
    (kern: &KKern, s: &FusedSrc, d: &mut FusedDst, n: usize, nodes: &[u64],
     node_consts: Option<&[[[u32; K_DEG]; 4]]>, acc_lo: &mut [u64], acc_hi: &mut [u64]));

// ---------------------------------------------------------------------------
// [UPERF2-G] The fused-round driver: rung schedule + jobs + planes.

/// One instance's tree layer j+1 for the extract modes, and its eq factor.
/// [UPERF2-H] the layer is a `BlkSrc`: a packed layer's slices, or the
/// compact leaves (expanded per job sub-chunk into scratch — the same
/// bytes, so the same values).
pub(crate) struct FusedLayer<'a> {
    pub src: BlkSrc<'a>,
    /// The instance's first state-t output pair-block (global index).
    pub first_pair: usize,
    /// E(e): the eq blocks of this instance are the b-part table's blocks
    /// times E(e) (None: times one — the b-part table IS the eq).
    pub ee: Option<[u32; K_DEG]>,
}

/// The plan of one fused round.
pub(crate) struct FusedPlan<'a> {
    pub mode: u8,
    /// The LIVE (real) output pair-block ranges [a, b) of state t, sorted
    /// and disjoint; for the extract modes each range lies within one
    /// instance and `layers[i]` is that instance's layer.
    pub ranges: &'a [(usize, usize)],
    pub layers: &'a [FusedLayer<'a>],
    pub r_prev: [u32; K_DEG],
    pub lambda: [u32; K_DEG],
    pub fold_consts: Option<[[u32; K_DEG]; 4]>,
}

/// The prefix [0, A0) of the in-place rung schedule goes through the
/// scratch (its reads [0, 4 A0) overlap its own writes [0, 2 A0)).
const K9_FUSE_PREFIX_PAIRS: usize = 64;
/// Smallest parallel job (pair-blocks).
const K9_FUSE_MIN_JOB_PAIRS: usize = 8;
/// u64 words of padding between consecutive jobs' plane slots (128 B: two
/// cache lines, enough for any 16 B-aligned base).
const K9_PLANE_PAD: usize = 16;

/// Jobs per thread per rung (`ZK_K9_JOBS_PER_THREAD`, default 8): more,
/// smaller jobs shorten the barrier tail on a hybrid box (an E-core's job
/// takes ~2x a P-core's); fewer, larger jobs cost less setup. Any value is
/// bit-identical (exact-integer planes).
fn k9_fuse_jobs_per_thread() -> usize {
    static V: std::sync::LazyLock<usize> = std::sync::LazyLock::new(|| {
        std::env::var("ZK_K9_JOBS_PER_THREAD").ok().and_then(|v| v.parse::<usize>().ok()).filter(|&n| n >= 1).unwrap_or(8)
    });
    *V
}

/// Carve `buf` (whose first block is table block `base_blk`) into the
/// sorted, disjoint block ranges `pieces` — disjoint &mut views for the
/// parallel jobs.
fn k9_carve<'a>(buf: &'a mut [u32], base_blk: usize, pieces: &[(usize, usize)]) -> Vec<&'a mut [u32]> {
    let mut out = Vec::with_capacity(pieces.len());
    let mut rest = buf;
    let mut cur = base_blk;
    for &(lo, hi) in pieces {
        assert!(lo >= cur && hi >= lo, "K9 carve: pieces must be sorted and disjoint");
        let (_, r) = std::mem::take(&mut rest).split_at_mut((lo - cur) * KBLK);
        let (piece, r) = r.split_at_mut((hi - lo) * KBLK);
        out.push(piece);
        rest = r;
        cur = hi;
    }
    out
}

/// One fused job (a run of `n` output pair-blocks) with its planes.
struct FusedJob<'a> {
    src: FusedSrc<'a>,
    dst: FusedDst<'a>,
    n: usize,
    lo: &'a mut [u64],
    hi: &'a mut [u64],
    /// [UPERF2-H] extract modes over compact leaves: (the leaves, the
    /// leaf block of this job's first pair-block, layer blocks per
    /// pair-block f, eq blocks per pair-block fe); `src.t` is then empty
    /// and the run expands sub-chunks of pair-blocks into scratch.
    compact: Option<(&'a CompactLeaves, usize, usize, usize)>,
}

/// Pair-blocks per expansion sub-chunk of a compact-leaves job (f = 8
/// layer blocks each at round 1: 128 KB of scratch per table — cache
/// resident). Any value is bit-identical (per-pair-block state only).
const K9_COMPACT_SUB_PAIRS: usize = 32;

/// The fused round over the whole table (state-t pair-blocks 0..n_pairs;
/// the plan's live ranges only): deterministic per-job planes summed into
/// acc_lo/acc_hi (exact integers — identical for any thread count / job
/// partition). Buffers (whole tables):
///   FUSE_FOLD: `eq_inplace` + `tabs` = the five state-(t-1) tables, folded
///     IN PLACE to state t (the rung schedule + scratch prefix);
///   FUSE_EXTRACT: `eq_src` = the b-part eq table (per-instance E(e) in the
///     plan's layers), no writes;
///   FUSE_EXTRACT_FOLD: `eq_src` as above, `eq_dst` + `tabs` = the FRESH
///     state-1 tables (written, no aliasing: one parallel pass).
#[allow(clippy::too_many_arguments)]
pub(crate) fn k9_fused_round_par(
    kern: &KKern,
    plan: &FusedPlan,
    n_pairs: usize,
    eq_inplace: &mut [u32],
    eq_src: &[u32],
    eq_dst: &mut [u32],
    tabs: [&mut [u32]; 4],
    nodes: &[u64],
    node_consts: Option<&[[[u32; K_DEG]; 4]]>,
    acc_lo: &mut [u64],
    acc_hi: &mut [u64],
    scratch: &mut Vec<u32>,
) {
    let acc_words = nodes.len() * 31 * KL;
    assert!(acc_lo.len() >= acc_words && acc_hi.len() >= acc_words, "K9 fused accumulator layout");
    let inplace = plan.mode == FUSE_FOLD;
    let writes = plan.mode != FUSE_EXTRACT;
    if !inplace {
        assert_eq!(plan.layers.len(), plan.ranges.len(), "K9 fused extract: one layer per live range");
    }
    // Rungs (a, b, via_scratch) over the output pair-blocks [0, n_pairs):
    // the in-place fold needs the schedule; the fresh-table modes are one
    // parallel pass.
    let mut rungs: Vec<(usize, usize, bool)> = Vec::new();
    if !inplace {
        rungs.push((0, n_pairs, false));
    } else {
        let a0 = K9_FUSE_PREFIX_PAIRS.min(n_pairs);
        rungs.push((0, a0, true));
        let mut a = a0;
        while a < n_pairs {
            rungs.push((a, 2 * a, false));
            a *= 2;
        }
        let need = 5 * 2 * a0 * KBLK;
        if scratch.len() < need {
            scratch.resize(need, 0);
        }
    }
    let threads = k9_threads();
    let mut tabs = tabs;
    for &(ra, rb, via_scratch) in &rungs {
        // Live sub-ranges of this rung and the job partition.
        let live: Vec<(usize, usize, usize)> = plan
            .ranges
            .iter()
            .enumerate()
            .filter_map(|(ri, &(lo, hi))| {
                let (a, b) = (lo.max(ra), hi.min(rb));
                if a < b { Some((a, b, ri)) } else { None }
            })
            .collect();
        if live.is_empty() {
            continue;
        }
        let total: usize = live.iter().map(|&(a, b, _)| b - a).sum();
        let jobs_target = if threads <= 1 { 1 } else { (threads * k9_fuse_jobs_per_thread()).min(total / K9_FUSE_MIN_JOB_PAIRS).max(1) };
        let w = total.div_ceil(jobs_target).max(1);
        let mut jobs: Vec<(usize, usize, usize)> = Vec::new();
        for &(a, b, ri) in &live {
            let mut x = a;
            while x < b {
                let y = (x + w).min(b);
                jobs.push((x, y, ri));
                x = y;
            }
        }
        let nj = jobs.len();
        let write_pieces: Vec<(usize, usize)> = jobs.iter().map(|&(a, b, _)| (2 * a, 2 * b)).collect();
        // Per-job plane slots padded by 128 B so no two jobs' persistent
        // accumulators share a cache line (the planes are written on every
        // pair-block; a shared boundary line would ping-pong between cores).
        let slot = 2 * acc_words + K9_PLANE_PAD;
        let mut planes = vec![0u64; nj * slot];
        // In-place mode: writes land in [.., 2 rb) blocks, reads come from
        // [4 ra, ..) = [2 rb, ..) blocks (rungs) or the whole buffer
        // read-only (the scratch prefix).
        let read_base = 4 * ra;
        let (eq_w, eq_r): (&mut [u32], &[u32]) = if inplace && !via_scratch {
            let (w_, r_) = eq_inplace.split_at_mut(2 * rb * KBLK);
            (w_, &r_[..])
        } else if inplace {
            (Default::default(), &eq_inplace[..])
        } else {
            (Default::default(), Default::default())
        };
        let mut tab_w: Vec<&mut [u32]> = Vec::with_capacity(4);
        let mut tab_r: Vec<&[u32]> = Vec::with_capacity(4);
        if inplace {
            for t in tabs.iter_mut() {
                if via_scratch {
                    tab_w.push(Default::default());
                    tab_r.push(&t[..]);
                } else {
                    let (w_, r_) = t.split_at_mut(2 * rb * KBLK);
                    tab_w.push(w_);
                    tab_r.push(&r_[..]);
                }
            }
        } else if writes {
            for t in tabs.iter_mut() {
                tab_w.push(&mut t[..]);
                tab_r.push(Default::default());
            }
        } else {
            for _ in 0..4 {
                tab_w.push(Default::default());
                tab_r.push(Default::default());
            }
        }
        // Destination pieces per job: the scratch (prefix), the write
        // regions (in-place rungs), or the fresh tables (extract-fold).
        let a0_blk = if via_scratch { 2 * rb } else { 0 };
        let (mut eq_pieces, mut tab_pieces): (Vec<&mut [u32]>, Vec<Vec<&mut [u32]>>) = if !writes {
            ((0..nj).map(|_| Default::default()).collect(), (0..4).map(|_| (0..nj).map(|_| Default::default()).collect()).collect())
        } else if via_scratch {
            let mut regions: Vec<&mut [u32]> = scratch[..5 * a0_blk * KBLK].chunks_mut(a0_blk * KBLK).collect();
            let eqp = k9_carve(regions.remove(0), 0, &write_pieces);
            let tp: Vec<Vec<&mut [u32]>> = regions.into_iter().map(|r| k9_carve(r, 0, &write_pieces)).collect();
            (eqp, tp)
        } else if inplace {
            let eqp = k9_carve(eq_w, 0, &write_pieces);
            let tp: Vec<Vec<&mut [u32]>> = tab_w.into_iter().map(|w_| k9_carve(w_, 0, &write_pieces)).collect();
            (eqp, tp)
        } else {
            let eqp = k9_carve(&mut eq_dst[..], 0, &write_pieces);
            let tp: Vec<Vec<&mut [u32]>> = tab_w.into_iter().map(|w_| k9_carve(w_, 0, &write_pieces)).collect();
            (eqp, tp)
        };
        let mut plane_chunks: Vec<&mut [u64]> = planes.chunks_mut(slot).map(|c| &mut c[..2 * acc_words]).collect();
        // Assemble the jobs (in order; the &mut pieces are moved in).
        let mut job_list: Vec<FusedJob> = Vec::with_capacity(nj);
        let mut tab_iters: Vec<std::vec::IntoIter<&mut [u32]>> =
            tab_pieces.drain(..).map(|v| v.into_iter()).collect();
        for (ji, &(a, b, ri)) in jobs.iter().enumerate() {
            let n = b - a;
            let (src_eq, eq_scale, src_t, compact): (&[u32], Option<[u32; K_DEG]>, [&[u32]; 4], Option<(&CompactLeaves, usize, usize, usize)>) = if inplace {
                (
                    &eq_r[(4 * a - read_base) * KBLK..(4 * b - read_base) * KBLK],
                    None,
                    std::array::from_fn(|k| &tab_r[k][(4 * a - read_base) * KBLK..(4 * b - read_base) * KBLK]),
                    None,
                )
            } else {
                let lay = &plan.layers[ri];
                let la = a - lay.first_pair;
                let (f, fe) = if plan.mode == FUSE_EXTRACT { (4, 2) } else { (8, 4) };
                match &lay.src {
                    BlkSrc::Packed { p, q } => (
                        &eq_src[fe * la * KBLK..fe * (la + n) * KBLK],
                        lay.ee,
                        [&p[f * la * KBLK..f * (la + n) * KBLK], &q[f * la * KBLK..f * (la + n) * KBLK], Default::default(), Default::default()],
                        None,
                    ),
                    BlkSrc::Compact(c) => (
                        &eq_src[fe * la * KBLK..fe * (la + n) * KBLK],
                        lay.ee,
                        [Default::default(), Default::default(), Default::default(), Default::default()],
                        Some((*c, f * la, f, fe)),
                    ),
                }
            };
            let dst_eq = std::mem::take(&mut eq_pieces[ji]);
            let dst_t: [&mut [u32]; 4] = std::array::from_fn(|k| tab_iters[k].next().unwrap());
            let (lo, hi) = std::mem::take(&mut plane_chunks[ji]).split_at_mut(acc_words);
            job_list.push(FusedJob {
                src: FusedSrc {
                    mode: plan.mode,
                    eq: src_eq,
                    eq_scale,
                    t: src_t,
                    r_prev: plan.r_prev,
                    lambda: plan.lambda,
                    fold_consts: plan.fold_consts,
                },
                dst: FusedDst { eq: dst_eq, t: dst_t },
                n,
                lo,
                hi,
                compact,
            });
        }
        let kern_c = *kern;
        let run = |job: &mut FusedJob| {
            match job.compact {
                None => k9_fused_round_blocks(&kern_c, &job.src, &mut job.dst, job.n, nodes, node_consts, job.lo, job.hi),
                Some((c, blk0, f, fe)) => {
                    // [UPERF2-H] compact leaves: expand sub-chunks of pair-blocks
                    // into scratch and run the same kernel per sub-chunk (the
                    // planes accumulate exact integers; the state is per
                    // pair-block — any sub-chunking is bit-identical).
                    let sub = K9_COMPACT_SUB_PAIRS;
                    let mut sp = vec![0u32; f * sub * KBLK];
                    let mut sq = vec![0u32; f * sub * KBLK];
                    let writes = !job.dst.eq.is_empty();
                    let [d0, d1, d2, d3] = &mut job.dst.t;
                    let mut s = 0usize;
                    while s < job.n {
                        let m = sub.min(job.n - s);
                        c.expand_blocks(blk0 + f * s, f * m, &mut sp, &mut sq);
                        let src = FusedSrc {
                            mode: job.src.mode,
                            eq: &job.src.eq[fe * s * KBLK..fe * (s + m) * KBLK],
                            eq_scale: job.src.eq_scale,
                            t: [&sp[..f * m * KBLK], &sq[..f * m * KBLK], Default::default(), Default::default()],
                            r_prev: job.src.r_prev,
                            lambda: job.src.lambda,
                            fold_consts: job.src.fold_consts,
                        };
                        let (w0, w1) = (2 * s * KBLK, 2 * (s + m) * KBLK);
                        let mut dst = if writes {
                            FusedDst {
                                eq: &mut job.dst.eq[w0..w1],
                                t: [&mut d0[w0..w1], &mut d1[w0..w1], &mut d2[w0..w1], &mut d3[w0..w1]],
                            }
                        } else {
                            FusedDst { eq: Default::default(), t: [Default::default(), Default::default(), Default::default(), Default::default()] }
                        };
                        k9_fused_round_blocks(&kern_c, &src, &mut dst, m, nodes, node_consts, job.lo, job.hi);
                        s += m;
                    }
                }
            }
        };
        if threads <= 1 || nj <= 1 {
            for job in job_list.iter_mut() {
                run(job);
            }
        } else {
            k9_pooled(|| {
                use rayon::prelude::*;
                job_list.par_iter_mut().for_each(|job| run(job));
            });
        }
        drop(job_list);
        // Sum the planes (exact integers; any order).
        for c in planes.chunks(slot) {
            for i in 0..acc_words {
                acc_lo[i] += c[i];
                acc_hi[i] += c[acc_words + i];
            }
        }
        // Prefix: copy the folded pieces from the scratch into the tables.
        if via_scratch {
            for &(lo, hi) in &write_pieces {
                eq_inplace[lo * KBLK..hi * KBLK].copy_from_slice(&scratch[lo * KBLK..hi * KBLK]);
                for k in 0..4 {
                    tabs[k][lo * KBLK..hi * KBLK].copy_from_slice(&scratch[((k + 1) * a0_blk + lo) * KBLK..((k + 1) * a0_blk + hi) * KBLK]);
                }
            }
        }
    }
}

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

/// Threaded fixed-operand product dst[i] = src[i] * r over full blocks.
pub(crate) fn k9_mul_fixed_par(kern: &KKern, src: &[u32], r: &[u32; K_DEG], dst: &mut [u32], nblk: usize) {
    if k9_threads() <= 1 || nblk <= K9_CHUNK_BLK {
        return k9_mul_fixed_blocks(kern, src, r, dst, nblk);
    }
    let kern = *kern;
    let r = *r;
    let src = &src[..nblk * KBLK];
    let dst = &mut dst[..nblk * KBLK];
    k9_pooled(|| {
        use rayon::prelude::*;
        dst.par_chunks_mut(K9_CHUNK_BLK * KBLK)
            .zip(src.par_chunks(K9_CHUNK_BLK * KBLK))
            .for_each(|(dc, sc)| k9_mul_fixed_blocks(&kern, sc, &r, dc, dc.len() / KBLK));
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

// ---------------------------------------------------------------------------
// [UPERF2-D] The claim layer's ixf sumcheck round kernel on packed tables.
//
// The claim layer's folded instances (fold.rs `ixf_sumcheck_prove`) sum,
// over the unbound hypercube, ONE of three fixed combine shapes of the
// linearly extrapolated factor tables:
//     Prod3: v0 * v1 * v2                    (joint matmul: eq * A * B)
//     Had:   v0 * (v1 * v2 - v3)             (Hadamard zero-check)
//     Rq:    v0 * ((v1 - v4 * v2) - v3)      (requant zero-check)
// where v0 is always the eq factor. Per pair-block and node x the kernel
// forms the inner product (one MAC + one deferred reduction), the modular
// differences, then MACs eq * inner into a persistent per-node lazy plane
// accumulator (NO reduction) — exactly `round_g5_body`'s discipline. All
// deg + 1 nodes 0..=deg are evaluated (the ixf wire ships every node;
// no g(1) identity). Extrapolation to node x >= 2 is by successive
// modular adds of the pair difference from the x = 1 operand, so every
// operand stays canonical u32. Values are the same field elements the
// scalar `round_poly` + closure computes (exact K arithmetic; the
// battery pins it), and the per-chunk planes are exact non-negative
// integer sums bounded by the serial total (< 2^57 under the
// K9_MAX_PAIR_TERMS cap), so any thread chunking is bit-identical.

/// The three combine shapes (kernel ids). fold.rs's `IxfCombine` maps to these.
pub(crate) const IXF_KIND_PROD3: u8 = 0;
pub(crate) const IXF_KIND_HAD: u8 = 1;
pub(crate) const IXF_KIND_RQ: u8 = 2;

/// Factor-table count of a kind.
pub(crate) fn ixf_kind_tables(kind: u8) -> usize {
    match kind {
        IXF_KIND_PROD3 => 3,
        IXF_KIND_HAD => 4,
        IXF_KIND_RQ => 5,
        _ => panic!("unknown ixf kind"),
    }
}

/// The round kernel body over full pair-blocks: tabs[k] are the packed
/// factor tables (>= 2 * nblk_pairs blocks each), nodes 0..=deg, acc_lo /
/// acc_hi are (deg + 1) x 31 x KL persistent planes.
#[inline(always)]
fn ixf_round_body(
    kern: &KKern,
    kind: u8,
    tabs: &[&[u32]],
    nblk_pairs: usize,
    deg: usize,
    acc_lo: &mut [u64],
    acc_hi: &mut [u64],
) {
    let nt = ixf_kind_tables(kind);
    assert_eq!(tabs.len(), nt, "ixf round: table count vs kind");
    let pair_terms = nblk_pairs.checked_mul(KL).expect("ixf round term-count overflow");
    assert!(pair_terms <= K9_MAX_PAIR_TERMS, "K9 lazy-accumulator cap exceeded");
    let src_words = nblk_pairs.checked_mul(2 * KBLK).expect("ixf round input size overflow");
    assert!(tabs.iter().all(|t| t.len() >= src_words), "ixf round input layout");
    let acc_words = (deg + 1).checked_mul(31 * KL).expect("ixf round accumulator size overflow");
    assert!(acc_lo.len() >= acc_words && acc_hi.len() >= acc_words, "ixf round accumulator layout");
    let q32 = kern.q as u32;
    let mut e0 = [[0u32; KBLK]; 5];
    let mut e1 = [[0u32; KBLK]; 5];
    let mut dd = [[0u32; KBLK]; 5];
    let mut cur = [[0u32; KBLK]; 5];
    let mut inner = [0u32; KBLK];
    for m in 0..nblk_pairs {
        for k in 0..nt {
            let (a, b) = (&mut e0[k], &mut e1[k]);
            deint_pair(tabs[k], m, a, b);
            for x in 0..KBLK {
                dd[k][x] = subm32(e1[k][x], e0[k][x], q32);
            }
            cur[k] = e1[k];
        }
        let mut prev_x = 1usize;
        for x in 0..=deg {
            let v: [&[u32; KBLK]; 5] = if x == 0 {
                [&e0[0], &e0[1], &e0[2], &e0[3], &e0[4]]
            } else if x == 1 {
                [&e1[0], &e1[1], &e1[2], &e1[3], &e1[4]]
            } else {
                while prev_x < x {
                    for k in 0..nt {
                        for xx in 0..KBLK {
                            cur[k][xx] = addm32(cur[k][xx], dd[k][xx], q32);
                        }
                    }
                    prev_x += 1;
                }
                [&cur[0], &cur[1], &cur[2], &cur[3], &cur[4]]
            };
            // the inner factor: one MAC + one reduction, then modular adds
            let mut lo = [0u64; 31 * KL];
            let mut hi = [0u64; 31 * KL];
            match kind {
                IXF_KIND_PROD3 => {
                    mac_block(v[1], v[2], &mut lo, &mut hi);
                    red_block(kern, &lo, &hi, &mut inner);
                }
                IXF_KIND_HAD => {
                    mac_block(v[1], v[2], &mut lo, &mut hi);
                    red_block(kern, &lo, &hi, &mut inner);
                    for i in 0..KBLK {
                        inner[i] = subm32(inner[i], v[3][i], q32);
                    }
                }
                _ => {
                    mac_block(v[4], v[2], &mut lo, &mut hi);
                    red_block(kern, &lo, &hi, &mut inner);
                    for i in 0..KBLK {
                        inner[i] = subm32(subm32(v[1][i], inner[i], q32), v[3][i], q32);
                    }
                }
            }
            // eq * inner into the persistent node accumulator (NO reduction)
            let alo: &mut [u64; 31 * KL] = (&mut acc_lo[x * 31 * KL..(x + 1) * 31 * KL]).try_into().unwrap();
            let ahi: &mut [u64; 31 * KL] = (&mut acc_hi[x * 31 * KL..(x + 1) * 31 * KL]).try_into().unwrap();
            mac_block(v[0], &inner, alo, ahi);
        }
    }
}

k9_kernel!(k9_ixf_round_blocks, k9_ixf_round_blocks_avx2, ixf_round_body,
    (kern: &KKern, kind: u8, tabs: &[&[u32]], nblk_pairs: usize, deg: usize,
     acc_lo: &mut [u64], acc_hi: &mut [u64]));

/// Threaded ixf round kernel: per-chunk lazy planes summed in index order
/// into acc_lo/acc_hi (exact integer sums — identical for any chunking).
pub(crate) fn k9_ixf_round_par(
    kern: &KKern,
    kind: u8,
    tabs: &[&[u32]],
    nblk_pairs: usize,
    deg: usize,
    acc_lo: &mut [u64],
    acc_hi: &mut [u64],
) {
    let n_chunks = k9_round_chunks(nblk_pairs);
    if n_chunks <= 1 {
        return k9_ixf_round_blocks(kern, kind, tabs, nblk_pairs, deg, acc_lo, acc_hi);
    }
    let per = nblk_pairs.div_ceil(n_chunks);
    let acc_words = (deg + 1) * 31 * KL;
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
                    let sub: Vec<&[u32]> = tabs.iter().map(|t| &t[w0..w1]).collect();
                    k9_ixf_round_blocks(&kern, kind, &sub, m1 - m0, deg, &mut lo, &mut hi);
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

impl KField {
    /// [UPERF2-D] One ixf sumcheck round polynomial (evaluations at nodes
    /// 0..=deg) over packed factor tables of `kind`'s shape, all of the
    /// same power-of-two size >= 2 * KL (full pair-blocks only — the
    /// caller finishes smaller tables on the scalar path). Threaded via
    /// `k9_ixf_round_par`; each node finalized exactly (u128).
    pub(crate) fn kt_ixf_round_poly(&self, tabs: &[&KTab], deg: usize, kind: u8) -> Vec<KElem> {
        let kern = self.kern.as_ref().expect("kt_ixf_round_poly requires the bulk kernel");
        let n = tabs[0].n;
        assert!(n >= 2 * KL && n % (2 * KL) == 0, "ixf round: full pair-blocks only");
        assert!(tabs.iter().all(|t| t.n == n), "ixf round: table sizes");
        let nblk_pairs = n / (2 * KL);
        let acc_words = (deg + 1) * 31 * KL;
        let mut acc_lo = vec![0u64; acc_words];
        let mut acc_hi = vec![0u64; acc_words];
        let views: Vec<&[u32]> = tabs.iter().map(|t| t.d.as_slice()).collect();
        k9_ixf_round_par(kern, kind, &views, nblk_pairs, deg, &mut acc_lo, &mut acc_hi);
        (0..=deg)
            .map(|x| self.kt_round_g_finalize(&acc_lo[x * 31 * KL..(x + 1) * 31 * KL], &acc_hi[x * 31 * KL..(x + 1) * 31 * KL]))
            .collect()
    }

    /// [UPERF2-D] Threaded pack of boxed K-elements (positional).
    pub(crate) fn kt_pack(&self, v: &[KElem]) -> KTab {
        k9_pack_par(v)
    }
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

    /// [UPERF2-A] Ranged variant of kt_fold_par: only the SOURCE block
    /// ranges in `ranges_blk` (each [lo, hi) with lo, hi even, block
    /// units of the current table) are folded — output blocks [lo/2,
    /// hi/2) of the halved table; every other output block is left as it
    /// was in the scratch (never read by the caller: the pad-skipping
    /// descent). Requires t.n/2 >= KL and every range within the table.
    pub(crate) fn kt_fold_par_ranges(&self, t: &mut KTab, scratch: &mut Vec<u32>, r: &KElem, ranges_blk: &[(usize, usize)]) {
        let kern = self.kern.as_ref().expect("kt_fold_par_ranges requires the bulk kernel");
        let n_out = t.n / 2;
        assert!(n_out >= KL && n_out % KL == 0, "ranged fold needs full output blocks");
        let nblk_out = n_out / KL;
        if scratch.len() < nblk_out * KBLK {
            scratch.resize(nblk_out * KBLK, 0);
        }
        let rk = kop(r);
        for &(lo, hi) in ranges_blk {
            debug_assert!(lo % 2 == 0 && hi % 2 == 0 && lo < hi && hi <= 2 * nblk_out);
            let n = (hi - lo) / 2;
            k9_fold_oop_par(kern, &t.d[lo * KBLK..hi * KBLK], &mut scratch[(lo / 2) * KBLK..(hi / 2) * KBLK], &rk, n);
        }
        std::mem::swap(&mut t.d, scratch);
        t.n = n_out;
        t.d.truncate(nblk_out * KBLK);
    }

    /// [UPERF2-A] The threaded eq-table build (same in-place doubling,
    /// the doubling step chunked across threads); `kt_eq_table_ref` is
    /// the pre-change body. Identical values.
    pub(crate) fn kt_eq_table_par(&self, z: &[KElem]) -> KTab {
        let kern = self.kern.as_ref().expect("kt_eq_table requires the bulk kernel");
        assert!(z.len() <= K9_MAX_LEAVES.trailing_zeros() as usize, "K9 eq table cap exceeded");
        // [UPERF2-G] every entry is written by the doubling (recycled buffer).
        let mut t = KTab::recycled(1usize << z.len());
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
        // [UPERF2-G] every entry is written by the doubling (recycled buffer).
        let mut t = KTab::recycled(1usize << z.len());
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

// ---------------------------------------------------------------------------
// [UPERF2-G] The packed-table ARENA (OPT-IN, `ZK_K9_ARENA_MB=<cap>`;
// default 0 = off): recycled u32 buffers for the large KTabs (tree
// leaf/layer tables, the descent's work tables, eq tables), so a table
// does not pay the page faults of a fresh calloc on first touch. Policy:
// LIFO free list of buffers >= 256 KB, capped at the given MiB of held
// capacity (oldest evicted); a take is served by the smallest pooled buffer
// within 2x of the request (a bigger one would keep its extra pages
// resident under a small table; no realloc growth — glibc copies heap
// chunks), else fresh. `zero = true` memsets a recycled buffer. Allocation
// plumbing only — no value changes. MEASURED ON THIS BOX (report item 2):
// after lane E's calloc-p / parallel-q fill the faults are ~5% of the 8T
// bench's CPU and the pool did not pay for itself (size classes double per
// layer, so within a side nothing fits; across sides the held set costs
// RSS: +0.5 GB peak, prove +10%) — left as an experiment for a box with
// memory to spare plus a `k9_arena_clear()` call from the pass driver
// after the descent phase (the held buffers are resident RSS until then).

struct K9Arena {
    bufs: Vec<Vec<u32>>,
    held: usize,
}

static K9_ARENA: std::sync::Mutex<K9Arena> = std::sync::Mutex::new(K9Arena { bufs: Vec::new(), held: 0 });
static K9_ARENA_CAP: std::sync::LazyLock<usize> = std::sync::LazyLock::new(|| {
    let mb = std::env::var("ZK_K9_ARENA_MB").ok().and_then(|v| v.parse::<usize>().ok()).unwrap_or(0);
    mb << 18 // words: 1 MiB = 2^18 u32
});
/// Buffers below this are never pooled (256 KB).
const K9_ARENA_MIN_WORDS: usize = 1 << 16;
static K9_ARENA_HITS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static K9_ARENA_GROWS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static K9_ARENA_MISSES: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

/// A buffer of exactly `words` u32 (all zero when `zero`), recycled when
/// the arena has one.
pub(crate) fn k9_arena_take(words: usize, zero: bool) -> Vec<u32> {
    use std::sync::atomic::Ordering::Relaxed;
    if words < K9_ARENA_MIN_WORDS || *K9_ARENA_CAP == 0 {
        return k9_fresh_words(words);
    }
    let taken: Option<Vec<u32>> = {
        let mut a = K9_ARENA.lock().expect("K9 arena lock");
        // Best fit within 2x of the request (a bigger buffer would keep its
        // extra pages resident under a small table); no growth (a realloc
        // of a heap chunk copies).
        let mut best: Option<usize> = None;
        for (i, b) in a.bufs.iter().enumerate() {
            if b.capacity() >= words && b.capacity() <= 2 * words && best.is_none_or(|j| b.capacity() < a.bufs[j].capacity()) {
                best = Some(i);
            }
        }
        if best.is_some_and(|i| a.bufs[i].capacity() > words) {
            K9_ARENA_GROWS.fetch_add(1, Relaxed); // (counted: served by a larger buffer)
        }
        best.map(|i| {
            let b = a.bufs.remove(i);
            a.held -= b.capacity();
            b
        })
    };
    match taken {
        Some(mut b) => {
            K9_ARENA_HITS.fetch_add(1, Relaxed);
            if zero {
                b.clear();
                if b.capacity() < words {
                    b.reserve_exact(words);
                }
                b.resize(words, 0);
            } else if b.len() >= words {
                b.truncate(words);
            } else {
                if b.capacity() < words {
                    b.reserve_exact(words - b.len());
                }
                b.resize(words, 0);
            }
            b
        }
        None => {
            K9_ARENA_MISSES.fetch_add(1, Relaxed);
            k9_fresh_words(words)
        }
    }
}

/// A fresh zeroed buffer (calloc: zero pages, faulted in on first touch).
/// Probed and NOT adopted: MADV_HUGEPAGE on the 2 MiB-aligned interior cut
/// the bench's minor faults 9x (1.32M -> 142K) with no measurable wall
/// change at 8T or 1T on this box (the report, item 2) — the FFI was
/// removed again.
fn k9_fresh_words(words: usize) -> Vec<u32> {
    vec![0u32; words]
}

/// Return a buffer to the arena (dropped when small, or when the arena is
/// disabled; the oldest pooled buffers are evicted past the cap).
pub(crate) fn k9_arena_give(v: Vec<u32>) {
    if v.capacity() < K9_ARENA_MIN_WORDS || *K9_ARENA_CAP == 0 {
        return;
    }
    let mut evicted: Vec<Vec<u32>> = Vec::new();
    {
        let mut a = K9_ARENA.lock().expect("K9 arena lock");
        a.held += v.capacity();
        a.bufs.push(v);
        while a.held > *K9_ARENA_CAP && !a.bufs.is_empty() {
            let b = a.bufs.remove(0);
            a.held -= b.capacity();
            evicted.push(b);
        }
    }
    drop(evicted); // munmap outside the lock
}

/// Release every pooled buffer (RSS drops to the live set).
pub fn k9_arena_clear() {
    let bufs = {
        let mut a = K9_ARENA.lock().expect("K9 arena lock");
        a.held = 0;
        std::mem::take(&mut a.bufs)
    };
    drop(bufs);
}

/// (pooled buffers, held MiB, takes served from the pool, of which by a
/// larger-than-requested buffer, fresh allocations) — observation only.
pub fn k9_arena_stats() -> (usize, usize, u64, u64, u64) {
    use std::sync::atomic::Ordering::Relaxed;
    let a = K9_ARENA.lock().expect("K9 arena lock");
    (a.bufs.len(), a.held >> 18, K9_ARENA_HITS.load(Relaxed), K9_ARENA_GROWS.load(Relaxed), K9_ARENA_MISSES.load(Relaxed))
}

// ---------------------------------------------------------------------------
// [UPERF2-H] Descent tree memory: the knobs, the COMPACT LEAVES of the
// aligned witness trees, block sources, and the multi-level tree climb.
//
// The masked descent reads every tree layer ONCE, top-down (round j reads
// layer j+1 through the fused rounds 0/1 or the eager extract; nothing
// reads it again), so a packed tree does not have to keep its layers
// resident for the whole descent: (1) a layer is RELEASED by the descent
// once its round has its state-1 tables (gkr.rs `FracTree::release_layer`
// — the store is per-layer `RwLock<Option<..>>`, the descent holds only
// `&[FracTree]`); (2) the build keeps the leaves, every c-th layer above
// them and the small top layers, and a gap layer is RECOMPUTED from the
// nearest stored layer below when its round asks for it
// (`k9_tree_climb_par`: chunked, positional, the block-local `tree_step_body`
// arithmetic level by level through per-chunk scratch — the same integers
// the build stored); (3) the aligned witness tree's leaves are (0, 1)
// dummies, (1, alpha - v) members with v on K-coordinates 0..1 only
// (`lookup::fuse_pair` / `KField::embed`), and four blinders — stored as
// two u32 per leaf (`CompactLeaves`, 8 B instead of 128 B for p + q) and
// EXPANDED chunkwise into cache-resident scratch, exactly the packed blocks
// `KTab::set` would have written, wherever a kernel reads the leaf layer
// (the tree step, the fused extract rounds, the eager extract). Values are
// bit-identical by construction on every path; the batteries assert it.

/// Layers of at most this many elements are always stored (never a
/// checkpoint gap, never released): the roots, the layer-1 quadruples and
/// the scalar-tail layers read element by element.
pub(crate) const K9_SMALL_LAYER_N: usize = 1 << 12;

static K9_CKPT_OVERRIDE: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(usize::MAX);
static K9_CKPT_ENV: std::sync::LazyLock<usize> = std::sync::LazyLock::new(|| {
    std::env::var("ZK_K9_CHECKPOINT").ok().and_then(|v| v.parse::<usize>().ok()).unwrap_or(2)
});

/// The checkpoint stride c of the packed tree build (`ZK_K9_CHECKPOINT`,
/// default 2): layers depth, depth-c, depth-2c, .. and the small top layers
/// are stored, the others recomputed on demand; 0 (or 1) = every layer
/// stored (the pre-change layout). Always 0 under `oracle_mode()`.
pub fn k9_checkpoint_stride() -> usize {
    if super::eval_proof::oracle_mode() {
        return 0;
    }
    let o = K9_CKPT_OVERRIDE.load(std::sync::atomic::Ordering::Relaxed);
    let c = if o == usize::MAX { *K9_CKPT_ENV } else { o };
    if c <= 1 { 0 } else { c }
}

/// Battery/bench: override the checkpoint stride in process (None = back
/// to the env / default).
pub fn k9_set_checkpoint_stride(c: Option<usize>) {
    K9_CKPT_OVERRIDE.store(c.unwrap_or(usize::MAX), std::sync::atomic::Ordering::Relaxed);
}

/// Tri-state in-process override over an env default (0 = env, 1 = off,
/// 2 = on).
fn k9_knob(over: &std::sync::atomic::AtomicU8, env: &std::sync::LazyLock<bool>) -> bool {
    match over.load(std::sync::atomic::Ordering::Relaxed) {
        1 => false,
        2 => true,
        _ => **env,
    }
}

fn k9_set_knob(over: &std::sync::atomic::AtomicU8, v: Option<bool>) {
    over.store(match v { None => 0, Some(false) => 1, Some(true) => 2 }, std::sync::atomic::Ordering::Relaxed);
}

static K9_RELEASE_OVERRIDE: std::sync::atomic::AtomicU8 = std::sync::atomic::AtomicU8::new(0);
static K9_RELEASE_ENV: std::sync::LazyLock<bool> =
    std::sync::LazyLock::new(|| std::env::var("ZK_K9_TREE_RELEASE").map(|v| v != "0").unwrap_or(true));

/// Does the fast masked descent release each tree layer once its round has
/// consumed it (`ZK_K9_TREE_RELEASE`, default on; off under `oracle_mode()`)?
pub fn k9_tree_release_enabled() -> bool {
    !super::eval_proof::oracle_mode() && k9_knob(&K9_RELEASE_OVERRIDE, &K9_RELEASE_ENV)
}

pub fn k9_set_tree_release(v: Option<bool>) {
    k9_set_knob(&K9_RELEASE_OVERRIDE, v);
}

static K9_COMPACT_OVERRIDE: std::sync::atomic::AtomicU8 = std::sync::atomic::AtomicU8::new(0);
static K9_COMPACT_ENV: std::sync::LazyLock<bool> =
    std::sync::LazyLock::new(|| std::env::var("ZK_K9_COMPACT_LEAVES").map(|v| v != "0").unwrap_or(true));

/// Are the aligned witness trees' leaves stored compact
/// (`ZK_K9_COMPACT_LEAVES`, default on; off under `oracle_mode()`)?
pub fn k9_compact_leaves_enabled() -> bool {
    !super::eval_proof::oracle_mode() && k9_knob(&K9_COMPACT_OVERRIDE, &K9_COMPACT_ENV)
}

pub fn k9_set_compact_leaves(v: Option<bool>) {
    k9_set_knob(&K9_COMPACT_OVERRIDE, v);
}

/// The member flag bit of a compact leaf's second word (canonical values
/// are < 2^31, so bit 31 is free).
const K9_CL_MEMBER: u32 = 1 << 31;

/// The compact leaf layer of an aligned witness tree: leaf i is the dummy
/// (0, 1) when its word pair is zero, the member (1, alpha - v) with the
/// pair (q0, q1 | MEMBER) = the canonical K-coordinates 0 and 1 of q and
/// q's coordinates 2.. equal to alpha's, or an exception (index, p, q) —
/// the blinders (and anything else the builder cannot express). `n` is a
/// multiple of KL. `expand_blocks` writes the exact packed blocks
/// (`KTab::set`'s layout) of any block range.
pub(crate) struct CompactLeaves {
    pub n: usize,
    w: Vec<u32>,
    alpha: [u32; K_DEG],
    exc: Vec<(usize, [u32; K_DEG], [u32; K_DEG])>,
}

impl CompactLeaves {
    pub(crate) fn new(n: usize, alpha: &KElem) -> CompactLeaves {
        assert!(n % KL == 0 && n > 0, "compact leaves need whole lane blocks");
        CompactLeaves { n, w: vec![0u32; 2 * n], alpha: kop(alpha), exc: Vec::new() }
    }

    /// The word pairs (2 per leaf) for the builder's parallel fill.
    pub(crate) fn words_mut(&mut self) -> &mut [u32] {
        &mut self.w
    }

    /// Write member leaf i's pair (q0, q1) into a words slice whose first
    /// word is leaf `base`'s.
    #[inline(always)]
    pub(crate) fn put_member(words: &mut [u32], base: usize, i: usize, q0: u32, q1: u32) {
        debug_assert!(q0 < K9_CL_MEMBER && q1 < K9_CL_MEMBER);
        words[2 * (i - base)] = q0;
        words[2 * (i - base) + 1] = q1 | K9_CL_MEMBER;
    }

    /// An exception (index, p, q): overrides whatever the pair encodes.
    pub(crate) fn add_exception(&mut self, i: usize, p: &KElem, q: &KElem) {
        assert!(i < self.n);
        let (pp, qq) = (kop(p), kop(q));
        match self.exc.binary_search_by_key(&i, |e| e.0) {
            Ok(k) => self.exc[k] = (i, pp, qq),
            Err(k) => self.exc.insert(k, (i, pp, qq)),
        }
    }

    pub(crate) fn n_exceptions(&self) -> usize {
        self.exc.len()
    }

    /// Bytes held (the word pairs + the exceptions).
    pub(crate) fn bytes(&self) -> usize {
        self.w.len() * 4 + self.exc.len() * (8 + 8 * K_DEG)
    }

    #[inline(always)]
    fn decode(&self, i: usize) -> ([u32; K_DEG], [u32; K_DEG]) {
        let (w0, w1) = (self.w[2 * i], self.w[2 * i + 1]);
        let mut p = [0u32; K_DEG];
        let mut q = [0u32; K_DEG];
        if w1 & K9_CL_MEMBER != 0 {
            p[0] = 1;
            q = self.alpha;
            q[0] = w0;
            q[1] = w1 & !K9_CL_MEMBER;
        } else {
            q[0] = 1;
        }
        (p, q)
    }

    fn get_pair(&self, i: usize) -> ([u32; K_DEG], [u32; K_DEG]) {
        debug_assert!(i < self.n);
        if let Ok(k) = self.exc.binary_search_by_key(&i, |e| e.0) {
            return (self.exc[k].1, self.exc[k].2);
        }
        self.decode(i)
    }

    pub(crate) fn get_p(&self, i: usize) -> KElem {
        self.get_pair(i).0.iter().map(|&x| x as u64).collect()
    }

    pub(crate) fn get_q(&self, i: usize) -> KElem {
        self.get_pair(i).1.iter().map(|&x| x as u64).collect()
    }

    /// Expand leaf blocks [blk0, blk0 + nblk) into p_out / q_out (nblk * KBLK
    /// words each): the bytes `KTab::set` writes for the same elements.
    pub(crate) fn expand_blocks(&self, blk0: usize, nblk: usize, p_out: &mut [u32], q_out: &mut [u32]) {
        assert!((blk0 + nblk) * KL <= self.n, "compact leaves: block range");
        assert!(p_out.len() >= nblk * KBLK && q_out.len() >= nblk * KBLK, "compact leaves: output layout");
        for b in 0..nblk {
            let pb = &mut p_out[b * KBLK..(b + 1) * KBLK];
            let qb = &mut q_out[b * KBLK..(b + 1) * KBLK];
            let i0 = (blk0 + b) * KL;
            let ws = &self.w[2 * i0..2 * (i0 + KL)];
            for l in 0..KL {
                let (w0, w1) = (ws[2 * l], ws[2 * l + 1]);
                let m = w1 & K9_CL_MEMBER != 0;
                pb[l] = m as u32;
                for j in 1..K_DEG {
                    pb[j * KL + l] = 0;
                }
                if m {
                    qb[l] = w0;
                    qb[KL + l] = w1 & !K9_CL_MEMBER;
                    for j in 2..K_DEG {
                        qb[j * KL + l] = self.alpha[j];
                    }
                } else {
                    qb[l] = 1;
                    for j in 1..K_DEG {
                        qb[j * KL + l] = 0;
                    }
                }
            }
        }
        // Exceptions inside the range override.
        if !self.exc.is_empty() {
            let (i_lo, i_hi) = (blk0 * KL, (blk0 + nblk) * KL);
            let k0 = self.exc.partition_point(|e| e.0 < i_lo);
            for e in &self.exc[k0..] {
                if e.0 >= i_hi {
                    break;
                }
                let li = e.0 - i_lo;
                let base = (li / KL) * KBLK + (li % KL);
                for j in 0..K_DEG {
                    p_out[base + j * KL] = e.1[j];
                    q_out[base + j * KL] = e.2[j];
                }
            }
        }
    }
}

/// A read source of packed (p, q) blocks: a stored/owned packed layer, or
/// the compact leaves expanded on demand.
pub(crate) enum BlkSrc<'a> {
    Packed { p: &'a [u32], q: &'a [u32] },
    Compact(&'a CompactLeaves),
}

/// Expansion scratch of `BlkSrc::blocks` (grown as needed, reused).
#[derive(Default)]
pub(crate) struct ExpandScratch {
    p: Vec<u32>,
    q: Vec<u32>,
}

#[inline(always)]
fn packed_get(d: &[u32], i: usize) -> KElem {
    let base = (i / KL) * KBLK + (i % KL);
    (0..K_DEG).map(|j| d[base + j * KL] as u64).collect()
}

impl<'a> BlkSrc<'a> {
    pub(crate) fn get_p(&self, i: usize) -> KElem {
        match self {
            BlkSrc::Packed { p, .. } => packed_get(p, i),
            BlkSrc::Compact(c) => c.get_p(i),
        }
    }

    pub(crate) fn get_q(&self, i: usize) -> KElem {
        match self {
            BlkSrc::Packed { q, .. } => packed_get(q, i),
            BlkSrc::Compact(c) => c.get_q(i),
        }
    }

    /// The blocks [blk0, blk0 + nblk) of p and q: sub-slices of a packed
    /// source, or the compact leaves expanded into `scratch`.
    pub(crate) fn blocks<'s>(&'s self, blk0: usize, nblk: usize, scratch: &'s mut ExpandScratch) -> (&'s [u32], &'s [u32]) {
        match self {
            BlkSrc::Packed { p, q } => (&p[blk0 * KBLK..(blk0 + nblk) * KBLK], &q[blk0 * KBLK..(blk0 + nblk) * KBLK]),
            BlkSrc::Compact(c) => {
                let words = nblk * KBLK;
                if scratch.p.len() < words {
                    scratch.p.resize(words, 0);
                    scratch.q.resize(words, 0);
                }
                c.expand_blocks(blk0, nblk, &mut scratch.p, &mut scratch.q);
                (&scratch.p[..words], &scratch.q[..words])
            }
        }
    }
}

/// Output blocks per parallel chunk of the climb (the source of a chunk is
/// this << levels blocks per table; positional, any value identical).
const K9_CLIMB_CHUNK_BLK: usize = 64;

/// The tree layer `levels` above `src`: output blocks [0, out_nblk) from
/// source blocks [0, out_nblk << levels), the intermediate levels computed
/// per chunk through scratch (never materialized whole). Every output block
/// is `tree_step_body`'s block-local arithmetic applied level by level to
/// the same source blocks the layered build reads — the same integers.
/// levels == 1 over a packed source is the build's own threaded step.
pub(crate) fn k9_tree_climb_par(kern: &KKern, src: &BlkSrc, levels: usize, np: &mut [u32], nq: &mut [u32], out_nblk: usize) {
    assert!(levels >= 1, "tree climb: at least one level");
    if levels == 1 {
        if let BlkSrc::Packed { p, q } = src {
            return k9_tree_step_par(kern, p, q, np, nq, out_nblk);
        }
    }
    let (np, nq) = (&mut np[..out_nblk * KBLK], &mut nq[..out_nblk * KBLK]);
    let kern = *kern;
    let job = |c0: usize, npc: &mut [u32], nqc: &mut [u32]| {
        let n = npc.len() / KBLK;
        let mut scratch = ExpandScratch::default();
        let (sp, sq) = src.blocks(c0 << levels, n << levels, &mut scratch);
        if levels == 1 {
            k9_tree_step(&kern, sp, sq, npc, nqc, n);
            return;
        }
        // Ping-pong scratch for the intermediate levels.
        let top = (n << (levels - 1)) * KBLK;
        let mut bufs = [(vec![0u32; top], vec![0u32; top]), (vec![0u32; top], vec![0u32; top])];
        let mut cur = 0usize;
        {
            let m = n << (levels - 1);
            let (a_p, a_q) = &mut bufs[cur];
            k9_tree_step(&kern, sp, sq, &mut a_p[..m * KBLK], &mut a_q[..m * KBLK], m);
        }
        for lev in 2..levels {
            let m = n << (levels - lev);
            let (lo, hi) = bufs.split_at_mut(1);
            let (from, to) = if cur == 0 { (&lo[0], &mut hi[0]) } else { (&hi[0], &mut lo[0]) };
            k9_tree_step(&kern, &from.0[..2 * m * KBLK], &from.1[..2 * m * KBLK], &mut to.0[..m * KBLK], &mut to.1[..m * KBLK], m);
            cur ^= 1;
        }
        let (fp, fq) = &bufs[cur];
        k9_tree_step(&kern, &fp[..2 * n * KBLK], &fq[..2 * n * KBLK], npc, nqc, n);
    };
    let ch = K9_CLIMB_CHUNK_BLK;
    if k9_threads() <= 1 || out_nblk <= ch {
        for c0 in (0..out_nblk).step_by(ch) {
            let n = ch.min(out_nblk - c0);
            job(c0, &mut np[c0 * KBLK..(c0 + n) * KBLK], &mut nq[c0 * KBLK..(c0 + n) * KBLK]);
        }
        return;
    }
    k9_pooled(|| {
        use rayon::prelude::*;
        np.par_chunks_mut(ch * KBLK).zip(nq.par_chunks_mut(ch * KBLK)).enumerate().for_each(|(c, (npc, nqc))| {
            job(c * ch, npc, nqc);
        });
    });
}

// ---------------------------------------------------------------------------
// [UPERF2-G] Fusion knob: the fused descent kernels (fold-into-next-round +
// extract-into-round-0) are ON by default; `ZK_UPERF_G_NOFUSE=1` (or the
// in-process `k9_set_fuse_off(true)`) runs the same rounds loop with every
// fold applied eagerly — lane A's HEAD kernel loop — for the one-binary
// A/B. `oracle_mode()` still routes to the pre-change `_ref` bodies.

static K9_FUSE_OFF: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
static K9_FUSE_ENV_OFF: std::sync::LazyLock<bool> =
    std::sync::LazyLock::new(|| std::env::var("ZK_UPERF_G_NOFUSE").map(|v| v == "1").unwrap_or(false));

/// Are the fused descent kernels enabled?
pub fn k9_fuse_enabled() -> bool {
    !*K9_FUSE_ENV_OFF && !K9_FUSE_OFF.load(std::sync::atomic::Ordering::Relaxed)
}

/// Battery/bench: disable (true) / re-enable (false) the fused kernels in
/// process; the env override wins when set.
pub fn k9_set_fuse_off(off: bool) {
    K9_FUSE_OFF.store(off, std::sync::atomic::Ordering::Relaxed);
}

static K9_XFUSE_ENV_OFF: std::sync::LazyLock<bool> =
    std::sync::LazyLock::new(|| std::env::var("ZK_UPERF_G_NOXFUSE").map(|v| v == "1").unwrap_or(false));

/// Is the extract fusion (rounds 0/1 read the tree layer directly)
/// enabled? `ZK_UPERF_G_NOXFUSE=1` keeps the fold fusion but extracts the
/// state-0 tables eagerly (the attribution knob).
pub fn k9_fuse_extract_enabled() -> bool {
    !*K9_XFUSE_ENV_OFF
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

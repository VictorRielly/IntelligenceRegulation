// Route R shared ring-arithmetic module (U1 of the protocol build; see
// docs/zkmatrix-poc/ROUTE_R_DESIGN.md Section 6, "Suggested module layout").
//
// R_q = Z_q[X]/(X^D + 1), D = 128, parametric in the modulus q. The
// recommended operating point (Q2/Q3 + A1 tranches, RING_MULT_BOTTLENECK.md
// Section 6.5) is exported as Q8/ETA8: k = 8 split at q8_31 = 2^31 - 399
// (q = 17 mod 32, primitive 16th root eta), quinary challenges
// (|C| = 5^128 = 2^297.2), LS18 invertibility margin 1.30x — tight;
// re-verify via `ls18_ok` on any parameter change.
//
// Multiplication strategies, all bit-identical mod q (differential battery
// in bin/ring_matmul.rs self-test):
//   - poly_mul_g:            negacyclic schoolbook, ground truth at any q
//   - ring_mul_split:        k-way CRT split, schoolbook slots
//   - ring_mul_split_kara_fast: fixed-buffer Karatsuba slots (A2 kernels)
//   - commit_kernel_split_kara_fast: amortized-split GEMM (pre-split keys)
//   - aux::* (A1):           Goldilocks helper-prime NTT evaluation —
//     regime-dispatched (single-prime / limb-split x3); p has no protocol
//     role, outputs are exact mod q under the capacity contract.
//
// Everything here is EVALUATION machinery; soundness objects (challenge
// sets, norms, statements) live in params.rs / sigma.rs / ct_engine.rs.

use sha2::{Digest, Sha256};
use std::io::{BufReader, Read};

// A1 auxiliary-modulus NTT kernels (shared with ring_lattice.rs and
// aux_ntt.rs). Path is relative to src/ring/.
#[path = "../aux_ntt_core.rs"]
pub mod aux;

pub mod commit;
pub mod ct_engine;
pub mod digits;
pub mod eval_proof; // [UAGB1-BD] the batched-opening / eval-proof layer
pub mod fold; // [UAGB1-BE] the IXF fold layer
pub mod gpu; // [UPERF2-K] the GPU rung: CUDA/NVRTC ports of the NTT-domain kernels (feature `gpu-cuda`; a stub otherwise)
pub mod gkr;
pub mod pass_agg; // [UAGB1-BG] the pass-level composition (fold -> batch -> eval proofs)
pub mod descent_fold; // [UAGB1-BK] folded masked descent for table-membership facts
pub mod gkr_masked;
pub mod kfield;
pub mod link;
pub mod lookup;
pub mod sumcheck;
pub mod params;
pub mod sigma;
pub mod t_blind; // [UAGB1-BL] T_blind: masking the weight-touching round polynomials (P2)
pub mod ec_kernel; // [UPERF3-DD] Stage A round 4: the production E_c MAC kernels (bench + AVX2); not called by any shipped path
pub mod zc_range; // [UPERF3-S] SPIKE (S1/S2): base-field/E_c zero-check + LogUp-as-sumcheck; not called by any shipped path
pub mod two_tier; // [UPERF3-FF] SPIKE (S4): the sqrt two-tier opening front end; not called by any shipped path
pub mod stage_a; // [UPERF3-GG] Stage A round 5: the descent replacement in the real pass (selector-gated); not called by any shipped path
pub mod attn_softmax; // [UPERF3-JJ] SPIKE X-S1: the integer softmax chain value side (lane-local exp member + oracle-exact derivation); not called by any shipped path

pub use aux::D;
pub const LOG2_DELTA0: f64 = 0.005326; // log2(1.0037), same C3 model as Route Z

/// The recommended protocol modulus: largest prime < 2^31 with q = 17 mod 32
/// (v2(q-1) = 4), so X^128 + 1 splits into exactly 8 irreducible degree-16
/// binomials X^16 - eta^(2t+1).
pub const Q8: u64 = 2_147_483_249; // 2^31 - 399
/// Primitive 16th root of unity mod Q8 (eta^8 = -1; asserted by ring_ctx).
pub const ETA8: u64 = 2_056_890_868;

/// The 46-bit sibling (k = 8 class), the design's conservative/fallback
/// modulus: q8_46 = 2^46 - 1103 (RING_MULT_BOTTLENECK.md Section 6.1).
/// Carried for regimes whose side-condition budgets do not close at q31
/// (see ct_engine.rs ARP notes).
pub const Q8_46: u64 = 70_368_744_176_561;
pub const ETA8_46: u64 = 49_533_544_627_797;

/// Ring elements: dense coefficient vectors, length D, values in [0, q).
pub type Poly = Vec<u64>;

// ---------------------------------------------------------------------------
// Scalar arithmetic at a runtime modulus.

#[derive(Clone, Copy)]
pub struct Zq {
    pub q: u64,
}

impl Zq {
    pub fn new(q: u64) -> Self {
        assert!(q % 2 == 1 && q < (1u64 << 60), "odd q below 2^60 expected");
        Zq { q }
    }
    #[inline(always)]
    pub fn add(&self, a: u64, b: u64) -> u64 {
        let s = a + b;
        if s >= self.q { s - self.q } else { s }
    }
    #[inline(always)]
    pub fn sub(&self, a: u64, b: u64) -> u64 {
        if a >= b { a - b } else { a + self.q - b }
    }
    #[inline(always)]
    pub fn mul(&self, a: u64, b: u64) -> u64 {
        ((a as u128 * b as u128) % self.q as u128) as u64
    }
    #[inline(always)]
    pub fn neg(&self, a: u64) -> u64 {
        if a == 0 { 0 } else { self.q - a }
    }
    /// Centered representative in (-q/2, q/2].
    #[inline(always)]
    pub fn center(&self, a: u64) -> i64 {
        if a > self.q / 2 { a as i64 - self.q as i64 } else { a as i64 }
    }
    #[inline(always)]
    pub fn to_mod(&self, a: i64) -> u64 {
        let r = a % self.q as i64;
        if r < 0 { (r + self.q as i64) as u64 } else { r as u64 }
    }
    pub fn pow(&self, mut b: u64, mut e: u64) -> u64 {
        let mut acc = 1u64;
        while e > 0 {
            if e & 1 == 1 {
                acc = self.mul(acc, b);
            }
            b = self.mul(b, b);
            e >>= 1;
        }
        acc
    }
    pub fn inv(&self, a: u64) -> u64 {
        self.pow(a, self.q - 2)
    }
}

// ---------------------------------------------------------------------------
// Dense polynomial helpers.

pub fn poly_zero() -> Poly {
    vec![0u64; D]
}

pub fn poly_add(zq: &Zq, a: &[u64], b: &[u64]) -> Poly {
    (0..D).map(|i| zq.add(a[i], b[i])).collect()
}

pub fn poly_sub(zq: &Zq, a: &[u64], b: &[u64]) -> Poly {
    (0..D).map(|i| zq.sub(a[i], b[i])).collect()
}

pub fn poly_neg(zq: &Zq, a: &[u64]) -> Poly {
    a.iter().map(|&x| zq.neg(x)).collect()
}

pub fn poly_scale(zq: &Zq, s: u64, a: &[u64]) -> Poly {
    a.iter().map(|&x| zq.mul(s, x)).collect()
}

pub fn poly_from_small(zq: &Zq, v: &[i64]) -> Poly {
    v.iter().map(|&x| zq.to_mod(x)).collect()
}

pub fn poly_to_small(zq: &Zq, a: &[u64]) -> Vec<i64> {
    a.iter().map(|&x| zq.center(x)).collect()
}

pub fn poly_linf(zq: &Zq, a: &[u64]) -> u64 {
    a.iter().map(|&x| zq.center(x).unsigned_abs()).max().unwrap()
}

/// The constant coefficient viewed centered: ct(a) in (-q/2, q/2].
pub fn ct_coeff(zq: &Zq, a: &[u64]) -> i64 {
    zq.center(a[0])
}

/// sigma_{-1}: X -> X^{-1} = -X^{D-1}, the conjugation automorphism of
/// R_q. ct(sigma_{-1}(a) * b) = <a, b> for coefficient vectors — the
/// ct-engine's inner-product transport (design Section 4, step 3).
pub fn poly_conj(zq: &Zq, a: &[u64]) -> Poly {
    let mut out = poly_zero();
    out[0] = a[0];
    for i in 1..D {
        out[D - i] = zq.neg(a[i]);
    }
    out
}

/// Negacyclic schoolbook at any q < 2^60: ground truth. The pos/neg u128
/// accumulators hold D products < q^2 <= 2^120 — exact.
pub fn poly_mul_g(zq: &Zq, a: &[u64], b: &[u64]) -> Poly {
    let mut pos = [0u128; 128];
    let mut neg = [0u128; 128];
    for i in 0..D {
        if a[i] == 0 {
            continue;
        }
        let ai = a[i] as u128;
        for j in 0..D {
            let p = ai * b[j] as u128;
            let k = i + j;
            if k < D {
                pos[k] += p;
            } else {
                neg[k - D] += p;
            }
        }
    }
    (0..D)
        .map(|k| zq.sub((pos[k] % zq.q as u128) as u64, (neg[k] % zq.q as u128) as u64))
        .collect()
}

/// Small x small negacyclic product over Z (no mod): exact rejection-sample
/// centers, challenge x witness products. |out|_inf <= D * |a|_inf * |b|_inf.
pub fn poly_mul_small(a: &[i64], b: &[i64]) -> Vec<i64> {
    let mut out = vec![0i64; D];
    for i in 0..D {
        if a[i] == 0 {
            continue;
        }
        for j in 0..D {
            let k = i + j;
            let p = a[i] * b[j];
            if k < D {
                out[k] += p;
            } else {
                out[k - D] -= p;
            }
        }
    }
    out
}

// Norms over the centered coefficient embedding.

pub fn vec_norm_sq_i64(v: &[i64]) -> u128 {
    // Saturating (audit 2026-07-14 C-04: total resource budget). A hostile
    // proof can supply arbitrary i64 responses; a wrapping sum could fold a
    // huge l2^2 back to a small value and slip past a norm bound. Saturating
    // to u128::MAX makes an oversized bundle ALWAYS exceed any real bound.
    v.iter().fold(0u128, |acc, &x| {
        let sq = (x as i128 * x as i128) as u128;
        acc.saturating_add(sq)
    })
}

/// floor(sqrt(x)): per-coordinate contract bound implied by an l2^2 bound.
pub fn isqrt_u128(x: u128) -> u128 {
    let mut r = (x as f64).sqrt() as u128;
    while r > 0 && r * r > x {
        r -= 1;
    }
    while (r + 1) * (r + 1) <= x {
        r += 1;
    }
    r
}

// ---------------------------------------------------------------------------
// k-way CRT split. X^D + 1 = prod_i (X^(D/k) - slot_roots[i]) mod q,
// realized as log2(k) butterfly levels from a primitive 2k-th root zeta
// (zeta^k = -1): a node X^(2m) - zeta^e splits into X^m -+ zeta^(e/2);
// exponents stay even until the leaves, whose roots are the odd powers.

pub struct RingCtx {
    pub zq: Zq,
    pub k: usize,
    pub slot_deg: usize,
    pub levels: usize,
    split_roots: Vec<Vec<u64>>, // [level][node]: the s of that butterfly
    merge_inv2: u64,
    merge_inv2s: Vec<Vec<u64>>, // [level][node]: (2 s)^-1
    pub slot_roots: Vec<u64>,   // leaf roots, length k
}

pub fn ring_ctx(q: u64, zeta: u64, k: usize) -> RingCtx {
    assert!(k.is_power_of_two() && k >= 2 && D % k == 0);
    let zq = Zq::new(q);
    assert!(zq.pow(zeta, k as u64) == q - 1, "zeta^k != -1 mod q");
    let levels = k.trailing_zeros() as usize;
    let mut exps: Vec<usize> = vec![k]; // root of X^D + 1 is zeta^k = -1
    let mut split_roots = Vec::with_capacity(levels);
    for _ in 0..levels {
        let mut next = Vec::with_capacity(2 * exps.len());
        let mut srs = Vec::with_capacity(exps.len());
        for &e in &exps {
            assert!(e % 2 == 0);
            let h = e / 2;
            srs.push(zq.pow(zeta, h as u64));
            next.push(h);
            next.push(h + k);
        }
        split_roots.push(srs);
        exps = next;
    }
    let slot_roots: Vec<u64> = exps.iter().map(|&e| zq.pow(zeta, e as u64)).collect();
    let merge_inv2 = zq.inv(2);
    let merge_inv2s: Vec<Vec<u64>> = split_roots
        .iter()
        .map(|lvl| lvl.iter().map(|&s| zq.inv(zq.mul(2, s))).collect())
        .collect();
    RingCtx { zq, k, slot_deg: D / k, levels, split_roots, merge_inv2, merge_inv2s, slot_roots }
}

/// The recommended-point context: k = 8 at q8_31.
pub fn ring_ctx_q8() -> RingCtx {
    ring_ctx(Q8, ETA8, 8)
}

/// Forward split: coefficient vector -> k slot images (leaf order),
/// contiguous in one length-D buffer.
pub fn crt_split(ctx: &RingCtx, a: &[u64]) -> Vec<u64> {
    let zq = &ctx.zq;
    let mut buf = a.to_vec();
    let mut m = D / 2;
    for level in 0..ctx.levels {
        let node_len = D >> level;
        for node in 0..(1usize << level) {
            let s = ctx.split_roots[level][node];
            let base = node * node_len;
            for i in 0..m {
                let lo = buf[base + i];
                let t = zq.mul(s, buf[base + i + m]);
                buf[base + i] = zq.add(lo, t);
                buf[base + i + m] = zq.sub(lo, t);
            }
        }
        m /= 2;
    }
    buf
}

/// Inverse of crt_split (in place).
pub fn crt_merge(ctx: &RingCtx, buf: &mut [u64]) {
    let zq = &ctx.zq;
    let mut m = ctx.slot_deg;
    for level in (0..ctx.levels).rev() {
        let node_len = D >> level;
        for node in 0..(1usize << level) {
            let inv2s = ctx.merge_inv2s[level][node];
            let base = node * node_len;
            for i in 0..m {
                let p = buf[base + i];
                let mi = buf[base + i + m];
                buf[base + i] = zq.mul(ctx.merge_inv2, zq.add(p, mi));
                buf[base + i + m] = zq.mul(inv2s, zq.sub(p, mi));
            }
        }
        m *= 2;
    }
}

/// Schoolbook multiplication in F_q[X]/(X^m - s): m^2 MACs + m fold mults.
pub fn slot_mul_g(zq: &Zq, a: &[u64], b: &[u64], s: u64, m: usize) -> Vec<u64> {
    let mut wide = vec![0u128; 2 * m];
    for i in 0..m {
        if a[i] == 0 {
            continue;
        }
        let ai = a[i] as u128;
        for j in 0..m {
            wide[i + j] += ai * b[j] as u128;
        }
    }
    (0..m)
        .map(|t| {
            let lo = (wide[t] % zq.q as u128) as u64;
            let hi = (wide[t + m] % zq.q as u128) as u64;
            zq.add(lo, zq.mul(s, hi))
        })
        .collect()
}

/// Full k-way split multiplication: split both operands, slot-multiply,
/// merge. (In GEMM-shaped kernels the splits amortize.)
pub fn ring_mul_split(ctx: &RingCtx, a: &[u64], b: &[u64]) -> Poly {
    let sa = crt_split(ctx, a);
    let sb = crt_split(ctx, b);
    let mut out = vec![0u64; D];
    let m = ctx.slot_deg;
    for i in 0..ctx.k {
        let prod =
            slot_mul_g(&ctx.zq, &sa[i * m..(i + 1) * m], &sb[i * m..(i + 1) * m], ctx.slot_roots[i], m);
        out[i * m..(i + 1) * m].copy_from_slice(&prod);
    }
    crt_merge(ctx, &mut out);
    out
}

/// Extended Euclid in F_q[X] mod (X^m - s) (irreducible). None for a = 0.
pub fn slot_inv_g(zq: &Zq, a: &[u64], s: u64, m: usize) -> Option<Vec<u64>> {
    let trim = |v: &mut Vec<u64>| {
        while v.len() > 1 && *v.last().unwrap() == 0 {
            v.pop();
        }
    };
    let is_zero = |v: &[u64]| v.iter().all(|&x| x == 0);
    if is_zero(a) {
        return None;
    }
    let mut r0: Vec<u64> = {
        let mut md = vec![0u64; m + 1];
        md[m] = 1;
        md[0] = zq.neg(s);
        md
    };
    let mut r1: Vec<u64> = a.to_vec();
    trim(&mut r1);
    let mut t0: Vec<u64> = vec![0];
    let mut t1: Vec<u64> = vec![1];
    while !is_zero(&r1) {
        let mut rem = r0.clone();
        let mut qt = vec![0u64; rem.len().saturating_sub(r1.len()) + 1];
        let lead_inv = zq.inv(*r1.last().unwrap());
        while rem.len() >= r1.len() && !is_zero(&rem) {
            let shift = rem.len() - r1.len();
            let coef = zq.mul(*rem.last().unwrap(), lead_inv);
            qt[shift] = zq.add(qt[shift], coef);
            for i in 0..r1.len() {
                rem[shift + i] = zq.sub(rem[shift + i], zq.mul(coef, r1[i]));
            }
            trim(&mut rem);
            if rem.len() == 1 && rem[0] == 0 {
                break;
            }
        }
        let mut prod = vec![0u64; qt.len() + t1.len() - 1];
        for i in 0..qt.len() {
            if qt[i] == 0 {
                continue;
            }
            for j in 0..t1.len() {
                prod[i + j] = zq.add(prod[i + j], zq.mul(qt[i], t1[j]));
            }
        }
        let mut t2 = vec![0u64; t0.len().max(prod.len())];
        for (i, t2i) in t2.iter_mut().enumerate() {
            let a0 = if i < t0.len() { t0[i] } else { 0 };
            let b0 = if i < prod.len() { prod[i] } else { 0 };
            *t2i = zq.sub(a0, b0);
        }
        trim(&mut t2);
        r0 = r1;
        r1 = rem;
        trim(&mut r1);
        if r1.len() == 1 && r1[0] == 0 {
            r1 = vec![0];
        }
        t0 = t1;
        t1 = t2;
    }
    let g_inv = zq.inv(r0[0]);
    let mut out = vec![0u64; m];
    for (i, &c) in t0.iter().enumerate() {
        if i < m {
            out[i] = zq.mul(c, g_inv);
        }
    }
    Some(out)
}

/// Ring inverse via the k-way CRT (exists iff every slot image is nonzero).
pub fn poly_inv_g(ctx: &RingCtx, a: &[u64]) -> Option<Poly> {
    let buf = crt_split(ctx, a);
    let m = ctx.slot_deg;
    let mut out = vec![0u64; D];
    for i in 0..ctx.k {
        let inv = slot_inv_g(&ctx.zq, &buf[i * m..(i + 1) * m], ctx.slot_roots[i], m)?;
        out[i * m..(i + 1) * m].copy_from_slice(&inv);
    }
    crt_merge(ctx, &mut out);
    Some(out)
}

/// LS18 coverage check for k-split invertibility of quinary challenge
/// differences: q^(1/k)/sqrt(k) must exceed ||c - c'||_inf <= 4. Returns
/// the margin (bound / 4); callers assert > 1 at derive time.
pub fn ls18_margin(q: u64, k: usize) -> f64 {
    (q as f64).powf(1.0 / k as f64) / (k as f64).sqrt() / 4.0
}

// ---------------------------------------------------------------------------
// Fixed-buffer Karatsuba slot kernels (A2): stack arrays, i128 lazy
// combination, one reduction per output. Depth 1 for the k = 8 degree-16
// slots, depth 2 for k = 2 degree-64 slots. Bounds: operands < q < 2^60,
// level sums < 4q, base products accumulate <= 16 terms -> < 2^8 q^2 < 2^128.

#[inline]
fn school_acc<const N: usize, const W: usize>(a: &[u64], b: &[u64], out: &mut [u128; W]) {
    for i in 0..N {
        if a[i] == 0 {
            continue;
        }
        let ai = a[i] as u128;
        for j in 0..N {
            out[i + j] += ai * b[j] as u128;
        }
    }
}

/// 16 x 16 Karatsuba (depth 1) into a 31-length i128 accumulator (+=).
fn kara16_acc(a: &[u64], b: &[u64], out: &mut [i128]) {
    let mut p0 = [0u128; 15];
    let mut p2 = [0u128; 15];
    let mut p1 = [0u128; 15];
    let mut sa = [0u64; 8];
    let mut sb = [0u64; 8];
    for i in 0..8 {
        sa[i] = a[i] + a[i + 8];
        sb[i] = b[i] + b[i + 8];
    }
    school_acc::<8, 15>(&a[0..8], &b[0..8], &mut p0);
    school_acc::<8, 15>(&a[8..16], &b[8..16], &mut p2);
    school_acc::<8, 15>(&sa, &sb, &mut p1);
    for i in 0..15 {
        out[i] += p0[i] as i128;
        out[i + 16] += p2[i] as i128;
        out[i + 8] += p1[i] as i128 - p0[i] as i128 - p2[i] as i128;
    }
}

/// 32 x 32 Karatsuba into a 63-length i128 accumulator (+=).
fn kara32_acc(a: &[u64], b: &[u64], out: &mut [i128]) {
    let mut p0 = [0u128; 31];
    let mut p2 = [0u128; 31];
    let mut p1 = [0u128; 31];
    let mut sa = [0u64; 16];
    let mut sb = [0u64; 16];
    for i in 0..16 {
        sa[i] = a[i] + a[i + 16];
        sb[i] = b[i] + b[i + 16];
    }
    school_acc::<16, 31>(&a[0..16], &b[0..16], &mut p0);
    school_acc::<16, 31>(&a[16..32], &b[16..32], &mut p2);
    school_acc::<16, 31>(&sa, &sb, &mut p1);
    for i in 0..31 {
        out[i] += p0[i] as i128;
        out[i + 32] += p2[i] as i128;
        out[i + 16] += p1[i] as i128 - p0[i] as i128 - p2[i] as i128;
    }
}

/// 64 x 64 Karatsuba (depth 2) into a 127-length i128 accumulator (+=).
fn kara64_acc(a: &[u64], b: &[u64], out: &mut [i128]) {
    let mut p0 = [0i128; 63];
    let mut p2 = [0i128; 63];
    let mut p1 = [0i128; 63];
    let mut sa = [0u64; 32];
    let mut sb = [0u64; 32];
    for i in 0..32 {
        sa[i] = a[i] + a[i + 32];
        sb[i] = b[i] + b[i + 32];
    }
    kara32_acc(&a[0..32], &b[0..32], &mut p0);
    kara32_acc(&a[32..64], &b[32..64], &mut p2);
    kara32_acc(&sa, &sb, &mut p1);
    for i in 0..63 {
        out[i] += p0[i];
        out[i + 64] += p2[i];
        out[i + 32] += p1[i] - p0[i] - p2[i];
    }
}

/// Karatsuba plain product for slot degrees 16/32/64 (+= into `out`, which
/// must hold 2m - 1 entries; entries may go negative transiently).
pub fn kara_acc(a: &[u64], b: &[u64], m: usize, out: &mut [i128]) {
    match m {
        64 => kara64_acc(a, b, out),
        32 => kara32_acc(a, b, out),
        16 => kara16_acc(a, b, out),
        _ => panic!("unsupported slot degree {m}"),
    }
}

pub fn reduce_i128(zq: &Zq, x: i128) -> u64 {
    let r = (x % zq.q as i128) as i64;
    zq.to_mod(r)
}

/// Slot product via fixed-buffer Karatsuba: F_q[X]/(X^m - s).
pub fn slot_mul_kara_fast(zq: &Zq, a: &[u64], b: &[u64], s: u64, m: usize) -> Vec<u64> {
    let mut wide = vec![0i128; 2 * m - 1];
    kara_acc(a, b, m, &mut wide);
    (0..m)
        .map(|t| {
            let lo = reduce_i128(zq, wide[t]);
            let hi = if t + m < 2 * m - 1 { reduce_i128(zq, wide[t + m]) } else { 0 };
            zq.add(lo, zq.mul(s, hi))
        })
        .collect()
}

/// k-way split multiplication with fixed-buffer Karatsuba slot kernels.
pub fn ring_mul_split_kara_fast(ctx: &RingCtx, a: &[u64], b: &[u64]) -> Poly {
    let sa = crt_split(ctx, a);
    let sb = crt_split(ctx, b);
    let mut out = vec![0u64; D];
    let m = ctx.slot_deg;
    for i in 0..ctx.k {
        let prod = slot_mul_kara_fast(
            &ctx.zq,
            &sa[i * m..(i + 1) * m],
            &sb[i * m..(i + 1) * m],
            ctx.slot_roots[i],
            m,
        );
        out[i * m..(i + 1) * m].copy_from_slice(&prod);
    }
    crt_merge(ctx, &mut out);
    out
}

/// Amortized-split GEMM commit kernel with fixed-buffer Karatsuba MACs:
/// `a_split` holds pre-split key rows (split once per CRS), each column is
/// split once, i128 slot accumulators absorb whole columns before the single
/// reduction (cols * 2^8 q^2 must stay below 2^127 — fine to ~2^40 cols at
/// q31). The A2 fallback for shapes/regimes off the A1 path.
pub fn commit_kernel_split_kara_fast(
    ctx: &RingCtx,
    a_split: &[Vec<u64>],
    rows: usize,
    cols: usize,
    rho_mod: &[Poly],
) -> Vec<Poly> {
    let zq = &ctx.zq;
    let m = ctx.slot_deg;
    let rho_split: Vec<Vec<u64>> = rho_mod.iter().map(|r| crt_split(ctx, r)).collect();
    (0..rows)
        .map(|r| {
            let mut wide = vec![0i128; 2 * D];
            for c in 0..cols {
                let a = &a_split[r * cols + c];
                let x = &rho_split[c];
                for slot in 0..ctx.k {
                    let base = slot * m;
                    kara_acc(
                        &a[base..base + m],
                        &x[base..base + m],
                        m,
                        &mut wide[2 * base..2 * base + 2 * m - 1],
                    );
                }
            }
            let mut out = vec![0u64; D];
            for slot in 0..ctx.k {
                let s = ctx.slot_roots[slot];
                let base = slot * m;
                for t in 0..m {
                    let lo = reduce_i128(zq, wide[2 * base + t]);
                    let hi = if t < m - 1 { reduce_i128(zq, wide[2 * base + t + m]) } else { 0 };
                    out[base + t] = zq.add(lo, zq.mul(s, hi));
                }
            }
            crt_merge(ctx, &mut out);
            out
        })
        .collect()
}

/// rows x cols ring matrix (row-major) times a small-integer ring vector,
/// mod q: exact i128 lazy accumulation. The schoolbook differential oracle
/// for every GEMM path.
pub fn ring_matvec_small_g(zq: &Zq, m: &[Poly], rows: usize, cols: usize, v: &[Vec<i64>]) -> Vec<Poly> {
    (0..rows)
        .map(|r| {
            let mut accp = [0i128; 128];
            for c in 0..cols {
                let a = &m[r * cols + c];
                let x = &v[c];
                for i in 0..D {
                    let xi = x[i];
                    if xi == 0 {
                        continue;
                    }
                    for j in 0..D {
                        let k = i + j;
                        let p = a[j] as i128 * xi as i128;
                        if k < D {
                            accp[k] += p;
                        } else {
                            accp[k - D] -= p;
                        }
                    }
                }
            }
            accp.iter()
                .map(|&x| {
                    let r = (x % zq.q as i128) as i64;
                    zq.to_mod(r)
                })
                .collect::<Poly>()
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Balanced base-2^e digit decomposition (Q2).

/// x = sum_j 2^(ej) d_j with d_j in [-2^(e-1), 2^(e-1) - 1]. Panics if L
/// digits cannot carry x.
pub fn digit_decompose(x: i64, e: u32, l: usize) -> Vec<i64> {
    let base = 1i64 << e;
    let half = base >> 1;
    let mut digs = Vec::with_capacity(l);
    let mut rem = x;
    for _ in 0..l {
        let mut d = rem % base;
        if d >= half {
            d -= base;
        }
        if d < -half {
            d += base;
        }
        digs.push(d);
        rem = (rem - d) / base;
    }
    assert!(rem == 0, "digit range exhausted for {x}");
    digs
}

/// Split a witness (columns of D-length i64 vectors) into L digit witnesses.
pub fn digit_split_witness(u: &[Vec<i64>], e: u32, l: usize) -> Vec<Vec<Vec<i64>>> {
    let mut out = vec![vec![vec![0i64; D]; u.len()]; l];
    for (n, col) in u.iter().enumerate() {
        for (i, &x) in col.iter().enumerate() {
            for (j, d) in digit_decompose(x, e, l).into_iter().enumerate() {
                out[j][n][i] = d;
            }
        }
    }
    out
}

// ---------------------------------------------------------------------------
// RNG and the SHA-256 counter-mode XOF for CRS expansion and Fiat-Shamir
// challenges.

/// Minimal randomness interface used by prover sampling. Production proof
/// paths must use [`ProverRng`]. The `u64` implementation is retained only
/// for deterministic legacy batteries and benchmark data generation.
pub trait RngSource {
    fn next_u64(&mut self) -> u64;
}

/// OS-seeded cryptographic prover RNG. This is deliberately a distinct type
/// from Fiat-Shamir transcripts: prover masks, commitment randomness and
/// rejection-sampling coins must never be derived from public statement data.
enum ProverRngInner {
    /// Linux GPU deployments use the kernel CSPRNG directly. A modest
    /// buffer keeps sampling hot paths from issuing one syscall per field
    /// limb. FORK-SAFE (audit 2026-07-14 H-01): the PID that filled the
    /// buffer is recorded; a draw from a different PID (i.e. after fork)
    /// reopens `/dev/urandom` and discards the inherited userspace buffer
    /// before returning any bytes, so parent and child never share a
    /// buffered stream.
    Os { reader: BufReader<std::fs::File>, pid: u32 },
    /// Deterministic SHA-256 counter stream for batteries only.
    Test(XofReader),
}

pub struct ProverRng {
    inner: ProverRngInner,
    /// Internal diagnostic session tag (audit 2026-07-14 H-01: downgraded
    /// from a security claim to bookkeeping). Drawn from OS entropy at the
    /// head of every `from_os` session, it labels a generator for logs and
    /// for the freshness batteries that assert two independent sessions
    /// differ. It is PRIVATE prover state: it is neither committed nor
    /// absorbed into any transcript, so no verifier or session registry
    /// can read it to detect reuse. It is therefore NOT an enforceable
    /// freshness invariant — the real no-reuse property is structural
    /// (masks are consumed by value; `ProverRng` is non-`Clone`; the OS
    /// stream is fork-reseeded). Do not treat this handle as auditable
    /// freshness.
    session_nonce: [u8; 32],
}

impl ProverRng {
    /// Seed a fresh prover session from the operating system CSPRNG. The
    /// leading 32 bytes of the session stream are consumed as the diagnostic
    /// session tag (see [`ProverRng::session_nonce`]) before any secret is
    /// drawn.
    pub fn from_os() -> std::io::Result<Self> {
        let source = std::fs::File::open("/dev/urandom")?;
        let mut reader = BufReader::with_capacity(1 << 16, source);
        let mut session_nonce = [0u8; 32];
        reader.read_exact(&mut session_nonce)?;
        Ok(ProverRng {
            inner: ProverRngInner::Os { reader, pid: std::process::id() },
            session_nonce,
        })
    }

    /// Deterministic CSPRNG for batteries only. The name and documentation
    /// are intentionally explicit so production call sites cannot mistake a
    /// public transcript hash for prover entropy. Gated behind `cfg(test)`
    /// or the `harness` feature (audit 2026-07-14 H-01): a production build
    /// with `--no-default-features` cannot construct a deterministic prover
    /// generator at all.
    #[cfg(any(test, feature = "harness"))]
    pub fn from_test_seed(domain: &str, seed: &[u8]) -> Self {
        let mut hasher = Sha256::new();
        hasher.update(b"zkmatrix-test-prover-rng-v1");
        hasher.update((domain.len() as u64).to_le_bytes());
        hasher.update(domain.as_bytes());
        hasher.update((seed.len() as u64).to_le_bytes());
        hasher.update(seed);
        let seed: [u8; 32] = hasher.finalize().into();
        // Reproducible session nonce for the batteries (a stable tag; the
        // adversarial "same-seed" arm relies on this being deterministic).
        let mut nh = Sha256::new();
        nh.update(b"zkmatrix-test-prover-rng-session-nonce-v1");
        nh.update(seed);
        let session_nonce: [u8; 32] = nh.finalize().into();
        ProverRng {
            inner: ProverRngInner::Test(XofReader::new("test-prover-rng", &[&seed])),
            session_nonce,
        }
    }

    /// The diagnostic session tag for this generator (see the field doc:
    /// internal bookkeeping, not an enforceable freshness invariant). Two
    /// independent `from_os` sessions return distinct tags with
    /// overwhelming probability.
    pub fn session_nonce(&self) -> [u8; 32] {
        self.session_nonce
    }
}

impl RngSource for ProverRng {
    #[inline(always)]
    fn next_u64(&mut self) -> u64 {
        match &mut self.inner {
            ProverRngInner::Os { reader, pid } => {
                // Fork guard (H-01): if this process is not the one that
                // filled the buffer, the inherited buffered bytes are
                // shared with the other side of the fork. Reopen a fresh
                // /dev/urandom handle (discarding the stale buffer) before
                // returning anything.
                let cur = std::process::id();
                if cur != *pid {
                    let source = std::fs::File::open("/dev/urandom")
                        .expect("operating-system CSPRNG unavailable after fork");
                    *reader = BufReader::with_capacity(1 << 16, source);
                    *pid = cur;
                }
                let mut bytes = [0u8; 8];
                reader
                    .read_exact(&mut bytes)
                    .expect("operating-system CSPRNG failed during proof generation");
                u64::from_le_bytes(bytes)
            }
            ProverRngInner::Test(reader) => reader.next_u64(),
        }
    }
}

pub fn splitmix64(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9e37_79b9_7f4a_7c15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
    z ^ (z >> 31)
}

impl RngSource for u64 {
    #[inline(always)]
    fn next_u64(&mut self) -> u64 {
        splitmix64(self)
    }
}

/// Uniform draw below an arbitrary bound (rejection on the top bits).
pub fn rng_below(rng: &mut dyn RngSource, bound: u64) -> u64 {
    assert!(bound > 0, "rng_below requires a nonzero bound");
    let shift = bound.leading_zeros();
    loop {
        let v = rng.next_u64() >> shift;
        if v < bound {
            return v;
        }
    }
}

pub fn rng_ternary_poly(rng: &mut dyn RngSource) -> Vec<i64> {
    let mut out = Vec::with_capacity(D);
    while out.len() < D {
        let mut w = rng.next_u64();
        // 12 unbiased base-3 digits per word via rejection on 5-bit chunks.
        for _ in 0..12 {
            let c = (w & 31) as i64;
            w >>= 5;
            if c < 30 {
                out.push(c % 3 - 1);
                if out.len() == D {
                    break;
                }
            }
        }
    }
    out
}

pub struct XofReader {
    key: [u8; 32],
    counter: u64,
    buf: Vec<u8>,
    pos: usize,
}

impl XofReader {
    pub fn new(domain: &str, items: &[&[u8]]) -> Self {
        let mut hasher = Sha256::new();
        hasher.update(b"route-r-v1");
        hasher.update(domain.as_bytes());
        for item in items {
            hasher.update((item.len() as u64).to_le_bytes());
            hasher.update(item);
        }
        XofReader { key: hasher.finalize().into(), counter: 0, buf: Vec::new(), pos: 0 }
    }

    pub fn next_bytes(&mut self, n: usize) -> Vec<u8> {
        let mut out = Vec::with_capacity(n);
        while out.len() < n {
            if self.pos == self.buf.len() {
                let mut hasher = Sha256::new();
                hasher.update(self.key);
                hasher.update(self.counter.to_le_bytes());
                self.buf = hasher.finalize().to_vec();
                self.pos = 0;
                self.counter += 1;
            }
            out.push(self.buf[self.pos]);
            self.pos += 1;
        }
        out
    }

    pub fn next_u64(&mut self) -> u64 {
        let b = self.next_bytes(8);
        u64::from_le_bytes(b.try_into().unwrap())
    }

    /// Uniform field element below q (rejection on the minimal bit width).
    pub fn next_field(&mut self, q: u64) -> u64 {
        let shift = q.leading_zeros();
        loop {
            let v = self.next_u64() >> shift;
            if v < q {
                return v;
            }
        }
    }

    /// Unbiased quinary challenge coefficient in {-2,...,2}: rejection on
    /// bytes (250 = 50 * 5 accepted values).
    pub fn next_quinary(&mut self) -> i64 {
        loop {
            let b = self.next_bytes(1)[0];
            if b < 250 {
                return (b % 5) as i64 - 2;
            }
        }
    }

    /// One quinary ring challenge (|C| = 5^128 = 2^297.2).
    pub fn next_challenge(&mut self) -> Vec<i64> {
        (0..D).map(|_| self.next_quinary()).collect()
    }
}

// ---------------------------------------------------------------------------
// Gaussian sampling and rejection sampling (alpha = 12, M = 2.76 discipline
// as lattice_matmul.rs; f64 exp is a prototype-carryover shortcut — the
// report requires fixed-point for production, noted in the design doc).

pub fn gaussian_ivec(rng: &mut dyn RngSource, len: usize, sigma: u64) -> Vec<i64> {
    let window = 12i64 * sigma as i64;
    let span = (2 * window + 1) as u64;
    let two_sigma_sq = 2.0 * sigma as f64 * sigma as f64;
    let mut out = Vec::with_capacity(len);
    while out.len() < len {
        let y = (rng.next_u64() % span) as i64 - window;
        let p = (-(y as f64) * (y as f64) / two_sigma_sq).exp();
        let u = (rng.next_u64() >> 11) as f64 / (1u64 << 53) as f64;
        if u < p {
            out.push(y);
        }
    }
    out
}

/// log M for the classical sigma = 12 ||center|| masking regime
/// (t = alpha = 12: log M = t/alpha + 1/(2 alpha^2) = 1 + 1/288).
pub const REJ_LOG_M_ALPHA12: f64 = 1.0 + 1.0 / 288.0;

/// `log_m` MUST match the caller's sigma = alpha ||center|| convention:
/// log M = t/alpha + 1/(2 alpha^2). Passing a log M sized for a smaller
/// alpha than the sigma actually used is sound and ZK-safe but collapses
/// the acceptance rate (the U-K8 chain paid e^-1.0 per unit instead of
/// its designed e^-0.47 while this constant was hard-coded at alpha = 12).
pub fn rejection_accept(
    rng: &mut dyn RngSource,
    response: &[i64],
    center_v: &[i64],
    sigma: u64,
    log_m: f64,
) -> bool {
    let mut norm_c: i128 = 0;
    let mut dot: i128 = 0;
    for (&z, &c) in response.iter().zip(center_v.iter()) {
        norm_c += c as i128 * c as i128;
        dot += z as i128 * c as i128;
    }
    let exponent = (norm_c - 2 * dot) as f64 / (2.0 * sigma as f64 * sigma as f64);
    let threshold = (exponent - log_m).exp();
    if threshold >= 1.0 {
        return true;
    }
    let u = (rng.next_u64() >> 11) as f64 / (1u64 << 53) as f64;
    u < threshold
}

/// Joint log M for k bundles in the 12-sigma regime (t = alpha = 12):
/// log M_joint = t sqrt(k)/alpha + k/(2 alpha^2). k = 1 gives
/// `REJ_LOG_M_ALPHA12`.
pub fn joint_log_m_alpha12(k: usize) -> f64 {
    (k as f64).sqrt() + k as f64 / 288.0
}

/// Joint-scaled rejection over k bundles with DIFFERENT sigmas
/// (Q4_LEMMAS.md Lemma Q4.2b, PROVEN): one test on the summed exponent
/// S = sum_i (||v_i||^2 - 2 <z_i, v_i>) / (2 sigma_i^2), accepted iff
/// u < exp(S - log M_joint) with M_joint = exp(t sqrt(k)/alpha +
/// k/(2 alpha^2)). Neither the sigmas nor the accepted output
/// distribution change vs the per-bundle product scheme — only the
/// restart rate improves (21.1 -> 5.7 expected attempts at k = 3 in the
/// 12-sigma regime). k = 1 reduces exactly to `rejection_accept`.
/// `log_m` MUST match the sigma = alpha ||center|| convention shared by
/// the parts (see `rejection_accept`).
pub fn joint_rejection_accept(
    rng: &mut dyn RngSource,
    parts: &[(&[i64], &[i64], u64)],
    log_m: f64,
) -> bool {
    let k = parts.len();
    if k == 0 {
        return true;
    }
    let mut s_exp = 0.0f64;
    for (z, v, sigma) in parts {
        let mut norm_c: i128 = 0;
        let mut dot: i128 = 0;
        for (&zi, &vi) in z.iter().zip(v.iter()) {
            norm_c += vi as i128 * vi as i128;
            dot += zi as i128 * vi as i128;
        }
        s_exp += (norm_c - 2 * dot) as f64 / (2.0 * *sigma as f64 * *sigma as f64);
    }
    let threshold = (s_exp - log_m).exp();
    if threshold >= 1.0 {
        return true;
    }
    let u = (rng.next_u64() >> 11) as f64 / (1u64 << 53) as f64;
    u < threshold
}

// ---------------------------------------------------------------------------
// Serialization helper shared by statement hashing everywhere.

pub fn polys_bytes(polys: &[Poly]) -> Vec<u8> {
    let mut out = Vec::with_capacity(polys.len() * D * 8);
    for p in polys {
        for &c in p.iter() {
            out.extend_from_slice(&c.to_le_bytes());
        }
    }
    out
}

//! A1 auxiliary-modulus NTT kernels, shared by the Route R backends.
//!
//! Origin: the A1 prototype bin (`bin/aux_ntt.rs`, workstream A1 of
//! `docs/zkmatrix-poc/RING_MULT_BOTTLENECK.md` Section 4; report:
//! `docs/zkmatrix-poc/A1_AUX_NTT_REPORT.md`). This module is the reusable
//! arithmetic promoted out of that bin per the report's Section 5
//! integration plan: Goldilocks primitives, the psi-twisted negacyclic
//! length-128 NTT, protocol-domain lifts, the capacity contract, the
//! limb-split fallback, and the GEMM-shaped commit kernels. It is shared by
//! `#[path]` inclusion from each binary (the `manifest.rs` precedent — the
//! crate is a collection of stand-alone bins, so a library target is
//! deliberately avoided; the module has no dependencies).
//!
//! Soundness note (unchanged from the report): the helper prime p carries no
//! protocol role. A ring product over R_q = Z_q[X]/(X^128 + 1) is an exact
//! integer polynomial with bounded coefficients; any modulus large enough to
//! determine that integer can host the computation. Every kernel here
//! produces mod-q outputs BIT-IDENTICAL to schoolbook — an evaluation
//! strategy, not a protocol change. The exact-integer contract
//! (`capacity`) is a static property of the operand-norm regime, asserted at
//! kernel construction, never assumed from data.
//!
//! All value-path arithmetic is exact integer (u64/u128/i128).

#![allow(dead_code)]

// ---------------------------------------------------------------------------
// Ring degree (matches ring_lattice.rs / ROUTE_R_DESIGN.md).

pub const D: usize = 128;
pub const LOG2_D: u32 = 7;

// ---------------------------------------------------------------------------
// Goldilocks arithmetic: p = 2^64 - 2^32 + 1.
//
// Facts used (verified in the aux_ntt bin's self-test): p is prime;
// p - 1 = 2^32 * (2^32 - 1) = 2^32 * 3 * 5 * 17 * 257 * 65537, so
// v2(p-1) = 32 and 256th roots of unity exist; 7 generates Z_p^*.

pub const P: u64 = 0xFFFF_FFFF_0000_0001;
pub const EPS: u64 = 0xFFFF_FFFF; // 2^32 - 1 = 2^64 mod p
pub const GEN: u64 = 7;

/// Branchless canonicalization to [0, p): subtract p if possible. Compiles
/// to a cmov — data-dependent branches cost ~3x NTT throughput here.
#[inline(always)]
pub fn canon_p(r: u64) -> u64 {
    let (d, borrow) = r.overflowing_sub(P);
    if borrow { r } else { d }
}

#[inline(always)]
pub fn add_p(a: u64, b: u64) -> u64 {
    // a, b < p. a + b < 2p < 2^65: on carry, a+b-2^64 + (2^32-1) = a+b-p,
    // and the EPS adjustment cannot re-carry (a+b-2^64 < 2^64 - 2^33 + 2).
    let (s, carry) = a.overflowing_add(b);
    canon_p(s.wrapping_add((carry as u64) * EPS))
}

#[inline(always)]
pub fn sub_p(a: u64, b: u64) -> u64 {
    // a, b < p. On borrow: a-b+2^64 - (2^32-1) = a-b+p (no re-borrow:
    // a-b+2^64 >= 2^64-p+1 = 2^32 > EPS).
    let (d, borrow) = a.overflowing_sub(b);
    d.wrapping_sub((borrow as u64) * EPS)
}

/// Reduce a full u128 mod p, branchless. With x = lo + 2^64*hi_lo +
/// 2^96*hi_hi and 2^64 = 2^32 - 1, 2^96 = -1 (mod p):
/// x = lo + (2^32-1)*hi_lo - hi_hi. Neither adjustment can double-wrap
/// (borrow case: t >= 2^64 - 2^32 + 1 > EPS; carry case:
/// t + t1 - 2^64 <= 2^64 - 2^33, + EPS < 2^64). Cross-checked against the
/// slow `% p` path over random and structured edge values in the aux_ntt
/// bin's self-test.
#[inline(always)]
pub fn reduce128(x: u128) -> u64 {
    let lo = x as u64;
    let hi = (x >> 64) as u64;
    let hi_lo = hi & EPS;
    let hi_hi = hi >> 32;
    let (t, borrow) = lo.overflowing_sub(hi_hi);
    let t = t.wrapping_sub((borrow as u64) * EPS);
    let t1 = (hi_lo << 32).wrapping_sub(hi_lo); // hi_lo * (2^32 - 1), exact
    let (r, carry) = t.overflowing_add(t1);
    canon_p(r.wrapping_add((carry as u64) * EPS))
}

#[inline(always)]
pub fn mul_p(a: u64, b: u64) -> u64 {
    reduce128(a as u128 * b as u128)
}

pub fn pow_p(mut base: u64, mut e: u64) -> u64 {
    let mut acc = 1u64;
    while e > 0 {
        if e & 1 == 1 {
            acc = mul_p(acc, base);
        }
        base = mul_p(base, base);
        e >>= 1;
    }
    acc
}

pub fn inv_p(a: u64) -> u64 {
    pow_p(a, P - 2)
}

// ---------------------------------------------------------------------------
// Negacyclic NTT over Z_p, length 128, via the merged psi-twist
// (Longa-Naehrig 2016, the SEAL/NFLlib convention): forward = Cooley-Tukey
// DIT with psi powers in bit-reversed order (standard-order input,
// bit-reversed output), inverse = Gentleman-Sande DIF with inverse psi
// powers (bit-reversed input, standard-order output, final scale by 1/n).
// Multiplication in Z_p[X]/(X^128 + 1) is then: fwd(a), fwd(b), pointwise,
// inv — no zero-padding, no separate twist pass.

pub struct NttTables {
    psi_brv: [u64; D],  // psi^bitrev7(i)
    ipsi_brv: [u64; D], // psi^{-bitrev7(i)}
    n_inv: u64,
}

pub fn bitrev7(mut i: u32) -> u32 {
    let mut r = 0u32;
    for _ in 0..LOG2_D {
        r = (r << 1) | (i & 1);
        i >>= 1;
    }
    r
}

pub fn build_tables() -> NttTables {
    // psi: primitive 256th root of unity (psi^128 = -1).
    let psi = pow_p(GEN, (P - 1) / (2 * D as u64));
    let psi_inv = inv_p(psi);
    let mut psi_brv = [0u64; D];
    let mut ipsi_brv = [0u64; D];
    // Powers by repeated multiplication (exact; D = 128 steps).
    let mut fwd = [0u64; D];
    let mut bwd = [0u64; D];
    let mut f = 1u64;
    let mut b = 1u64;
    for i in 0..D {
        fwd[i] = f;
        bwd[i] = b;
        f = mul_p(f, psi);
        b = mul_p(b, psi_inv);
    }
    for i in 0..D {
        psi_brv[i] = fwd[bitrev7(i as u32) as usize];
        ipsi_brv[i] = bwd[bitrev7(i as u32) as usize];
    }
    NttTables { psi_brv, ipsi_brv, n_inv: inv_p(D as u64) }
}

/// Forward negacyclic NTT, in place. Input standard order, output
/// bit-reversed order (consistent order is all pointwise mult needs).
pub fn ntt_fwd(a: &mut [u64; D], t: &NttTables) {
    let mut len = D;
    let mut m = 1;
    while m < D {
        len >>= 1;
        for i in 0..m {
            let s = t.psi_brv[m + i];
            let j1 = 2 * i * len;
            for j in j1..j1 + len {
                let u = a[j];
                let v = mul_p(a[j + len], s);
                a[j] = add_p(u, v);
                a[j + len] = sub_p(u, v);
            }
        }
        m <<= 1;
    }
}

/// Inverse negacyclic NTT, in place. Bit-reversed input, standard output.
pub fn ntt_inv(a: &mut [u64; D], t: &NttTables) {
    let mut len = 1;
    let mut m = D;
    while m > 1 {
        let h = m >> 1;
        let mut j1 = 0;
        for i in 0..h {
            let s = t.ipsi_brv[h + i];
            for j in j1..j1 + len {
                let u = a[j];
                let v = a[j + len];
                a[j] = add_p(u, v);
                a[j + len] = mul_p(sub_p(u, v), s);
            }
            j1 += 2 * len;
        }
        len <<= 1;
        m = h;
    }
    for x in a.iter_mut() {
        *x = mul_p(*x, t.n_inv);
    }
}

/// Negacyclic product over Z_p via NTT (the A1 primitive).
pub fn negacyclic_mul_p(a: &[u64; D], b: &[u64; D], t: &NttTables) -> [u64; D] {
    let mut fa = *a;
    let mut fb = *b;
    ntt_fwd(&mut fa, t);
    ntt_fwd(&mut fb, t);
    let mut fc = [0u64; D];
    for i in 0..D {
        fc[i] = mul_p(fa[i], fb[i]);
    }
    ntt_inv(&mut fc, t);
    fc
}

/// Reference: negacyclic schoolbook over Z_p (per-product reduction, then
/// u128 accumulation of reduced values — exact for any inputs < p).
pub fn negacyclic_schoolbook_p(a: &[u64; D], b: &[u64; D]) -> [u64; D] {
    let mut pos = [0u128; D];
    let mut neg = [0u128; D];
    for i in 0..D {
        if a[i] == 0 {
            continue;
        }
        for j in 0..D {
            let prod = mul_p(a[i], b[j]) as u128;
            let k = i + j;
            if k < D {
                pos[k] += prod;
            } else {
                neg[k - D] += prod;
            }
        }
    }
    let mut out = [0u64; D];
    for k in 0..D {
        out[k] = sub_p(reduce128(pos[k]), reduce128(neg[k]));
    }
    out
}

// ---------------------------------------------------------------------------
// Lifts between the protocol domain (balanced representatives mod q) and the
// helper domain Z_p, plus exact recovery.
//
// The exact-integer contract: if every coefficient of the true integer
// product/accumulation satisfies |c| <= (p-1)/2, then its value mod p
// determines it uniquely, and `center_from_p` recovers it. Whether the
// contract holds is a static property of the operand-norm regime — the
// capacity analysis below — never of the data.

/// Balanced representative of v mod q, |result| <= (q-1)/2.
#[inline(always)]
pub fn balanced_mod_q(v: u64, q: u64) -> i64 {
    if v > q / 2 { v as i64 - q as i64 } else { v as i64 }
}

/// Lift a balanced integer (|v| < p/2) into Z_p.
#[inline(always)]
pub fn lift_to_p(v: i64) -> u64 {
    if v >= 0 { v as u64 } else { P.wrapping_sub(v.unsigned_abs()) }
}

/// Centered representative of u in Z_p, in (-(p-1)/2, (p-1)/2].
#[inline(always)]
pub fn center_from_p(u: u64) -> i128 {
    if u > P / 2 { u as i128 - P as i128 } else { u as i128 }
}

/// Reduce an exact integer to [0, q).
#[inline(always)]
pub fn mod_q_i128(x: i128, q: u64) -> u64 {
    let r = x % q as i128;
    if r < 0 { (r + q as i128) as u64 } else { r as u64 }
}

/// Reduce a centered value |x| < 2^63 to [0, q) with a single u64 division
/// (the i128 remainder is a slow libcall; every recovered Z_p value is
/// centered below 2^63 by the capacity contract).
#[inline(always)]
pub fn mod_q_centered(x: i128, q: u64) -> u64 {
    debug_assert!(x.unsigned_abs() < 1 << 63);
    let r = (x.unsigned_abs() as u64) % q;
    if x < 0 && r != 0 { q - r } else { r }
}

// ---------------------------------------------------------------------------
// Capacity analysis. Exact u128 checks of the single-prime contract
//     n_acc * d * A * B <= (p-1)/2
// where A, B are the operand magnitude bounds (balanced representatives) and
// n_acc is how many ring products are accumulated before leaving the NTT
// domain (the module dimension N_r for the commit kernel).

/// Returns (fits_single_prime, bit_length_of_bound). Exact integer math.
pub fn capacity(n_acc: u128, a_max: u128, b_max: u128) -> (bool, u32) {
    // Largest case used: 2^11 * 2^7 * 2^45 * 2^45 = 2^108 — no u128 overflow.
    let bound = n_acc
        .checked_mul(D as u128)
        .and_then(|x| x.checked_mul(a_max))
        .and_then(|x| x.checked_mul(b_max))
        .expect("capacity bound overflows u128 — regime out of scope");
    (bound <= (P as u128 - 1) / 2, 128 - bound.leading_zeros())
}

/// Largest n_acc that keeps the single-prime contract for (A, B).
pub fn max_n_acc(a_max: u128, b_max: u128) -> u128 {
    (P as u128 - 1) / 2 / (D as u128) / a_max / b_max
}

// ---------------------------------------------------------------------------
// Mod-q scalar helpers (used by the limb recompose and the k = 2 baselines).

pub fn mul_q(a: u64, b: u64, q: u64) -> u64 {
    ((a as u128 * b as u128) % q as u128) as u64
}

pub fn pow_q(mut base: u64, mut e: u64, q: u64) -> u64 {
    let mut acc = 1u64;
    while e > 0 {
        if e & 1 == 1 {
            acc = mul_q(acc, base, q);
        }
        base = mul_q(base, base, q);
        e >>= 1;
    }
    acc
}

/// sqrt(-1) mod q for q = 5 mod 8: 2^((q-1)/4) works because 2 is a
/// quadratic nonresidue there; asserted on construction.
pub fn sqrt_m1(q: u64) -> u64 {
    let r = pow_q(2, (q - 1) / 4, q);
    assert_eq!(mul_q(r, r, q), q - 1, "sqrt(-1) construction failed");
    r
}

// ---------------------------------------------------------------------------
// The general-regime fallback: balanced limb-splitting with 3 Karatsuba
// sub-products over the SAME Goldilocks prime (chosen over two-prime CRT:
// op counts are a wash — 3 Goldilocks pointwise muls vs 1 Goldilocks + 1
// Montgomery mul + Garner reconstruction — and limb-split reuses the one
// NTT/reduction path; estimate documented in A1_AUX_NTT_REPORT.md).
//
// a = a1*2^L + a0 with |a0| <= 2^(L-1), |a1| <= q/2^(L+1) + 1; likewise b.
//   a*b = P0 + 2^L*(PM - P0 - P2) + 2^2L*P2,  P0 = a0 b0, P2 = a1 b1,
//   PM = (a0+a1)(b0+b1).
// The mid transform comes from NTT linearity (NTT(a0)+NTT(a1)) — only 2
// forward transforms per operand. Recombination MUST happen on exact
// integers (3 inverse transforms, centered recovery), then mod q: scaling
// by 2^L / 2^2L inside Z_p would overflow the capacity contract.

/// Limb size: half the bit length of (q-1)/2, rounded up.
pub fn limb_bits(q: u64) -> u32 {
    let bits = 64 - ((q - 1) / 2).leading_zeros();
    bits.div_ceil(2)
}

/// Split a balanced value into balanced limbs (v = hi*2^L + lo).
#[inline(always)]
pub fn split_limbs(v: i64, l: u32) -> (i64, i64) {
    let half = 1i64 << (l - 1);
    let full = 1i64 << l;
    let lo = (v % full + full + half) % full - half; // balanced remainder
    let hi = (v - lo) >> l;
    (lo, hi)
}

/// General mod-q x mod-q negacyclic ring product via the limb-split path.
/// Inputs/outputs in [0, q). Exact for any q with limb sub-products inside
/// the capacity contract (checked once by the caller/self-test).
pub fn ring_mul_q_limbsplit(a: &[u64], b: &[u64], q: u64, t: &NttTables) -> Vec<u64> {
    let l = limb_bits(q);
    let mut a0 = [0u64; D];
    let mut a1 = [0u64; D];
    let mut b0 = [0u64; D];
    let mut b1 = [0u64; D];
    for i in 0..D {
        let (lo, hi) = split_limbs(balanced_mod_q(a[i], q), l);
        a0[i] = lift_to_p(lo);
        a1[i] = lift_to_p(hi);
        let (lo, hi) = split_limbs(balanced_mod_q(b[i], q), l);
        b0[i] = lift_to_p(lo);
        b1[i] = lift_to_p(hi);
    }
    ntt_fwd(&mut a0, t);
    ntt_fwd(&mut a1, t);
    ntt_fwd(&mut b0, t);
    ntt_fwd(&mut b1, t);
    let mut p0 = [0u64; D];
    let mut p2 = [0u64; D];
    let mut pm = [0u64; D];
    for i in 0..D {
        p0[i] = mul_p(a0[i], b0[i]);
        p2[i] = mul_p(a1[i], b1[i]);
        pm[i] = mul_p(add_p(a0[i], a1[i]), add_p(b0[i], b1[i]));
    }
    ntt_inv(&mut p0, t);
    ntt_inv(&mut p2, t);
    ntt_inv(&mut pm, t);
    // Recompose mod q: each recovered sub-product is exact (|v| <= d*2^2L
    // <= 2^53 at q46), so reduce each mod q and combine with 2^L, 2^2L mod q.
    let two_l = (1u64 << l) % q;
    let two_2l = mul_q(two_l, two_l, q);
    let mut out = vec![0u64; D];
    for k in 0..D {
        let v0 = mod_q_centered(center_from_p(p0[k]), q);
        let v2 = mod_q_centered(center_from_p(p2[k]), q);
        let vm = mod_q_centered(center_from_p(pm[k]), q);
        // mid = vm - v0 - v2 (mod q); all sums stay far below 2^63.
        let mid = (vm + 2 * q - v0 - v2) % q;
        out[k] = (v0 + mul_q(two_l, mid, q) + mul_q(two_2l, v2, q)) % q;
    }
    out
}

/// Short-operand (regime a/b') single-prime ring product: a general mod q,
/// b balanced small (|b| <= b_max with d*q/2*b_max within capacity).
pub fn ring_mul_q_single(a: &[u64], b_small: &[i64], q: u64, t: &NttTables) -> Vec<u64> {
    let mut fa = [0u64; D];
    let mut fb = [0u64; D];
    for i in 0..D {
        fa[i] = lift_to_p(balanced_mod_q(a[i], q));
        fb[i] = lift_to_p(b_small[i]);
    }
    ntt_fwd(&mut fa, t);
    ntt_fwd(&mut fb, t);
    let mut fc = [0u64; D];
    for i in 0..D {
        fc[i] = mul_p(fa[i], fb[i]);
    }
    ntt_inv(&mut fc, t);
    fc.iter().map(|&u| mod_q_centered(center_from_p(u), q)).collect()
}

/// Ternary-specialized schoolbook single ring mult (regime (a) operands,
/// the Tier-1 add/sub lever): skip zeros, add/sub key coefficients in i128.
pub fn ring_mul_q_ternary_schoolbook(a: &[u64], b: &[i64], q: u64) -> Vec<u64> {
    let mut acc = [0i128; D];
    for i in 0..D {
        let xi = b[i];
        if xi == 0 {
            continue;
        }
        if xi == 1 {
            for j in 0..D {
                let k = i + j;
                if k < D {
                    acc[k] += a[j] as i128;
                } else {
                    acc[k - D] -= a[j] as i128;
                }
            }
        } else {
            for j in 0..D {
                let k = i + j;
                if k < D {
                    acc[k] -= a[j] as i128;
                } else {
                    acc[k - D] += a[j] as i128;
                }
            }
        }
    }
    acc.iter().map(|&v| mod_q_centered(v, q)).collect()
}

/// Reference: negacyclic schoolbook mod q, inputs in [0, q). u128 lazy
/// accumulation is exact: 128 * (q46-1)^2 < 2^99.
pub fn ring_mul_q_schoolbook(a: &[u64], b: &[u64], q: u64) -> Vec<u64> {
    let mut pos = [0u128; D];
    let mut neg = [0u128; D];
    for i in 0..D {
        if a[i] == 0 {
            continue;
        }
        for j in 0..D {
            let prod = a[i] as u128 * b[j] as u128;
            let k = i + j;
            if k < D {
                pos[k] += prod;
            } else {
                neg[k - D] += prod;
            }
        }
    }
    (0..D)
        .map(|k| {
            let p = (pos[k] % q as u128) as u64;
            let n = (neg[k] % q as u128) as u64;
            if p >= n { p - n } else { p + q - n }
        })
        .collect()
}

// ---------------------------------------------------------------------------
// The GEMM-shaped commitment kernel. C = G * R over R_q, where
// G ((kappa + msg_r) x N_r) is the FIXED commitment key and R packs many
// bounded columns (N_r ring elements each): ternary randomness (regime a,
// the dominant LLM-scale cost), Gaussian masks (regime b), digit witnesses.
//
// A1 evaluation: transform G once (cached), transform each column of R once,
// multiply-accumulate POINTWISE in the NTT domain, one inverse transform per
// output element, centered recovery, reduce mod q.
//
// Accumulator discipline: NTT-domain values are < 2^64, so a raw pointwise
// product fills a u128 and two of them cannot be added there. Split-halves
// lazy accumulation: accumulate the LOW and HIGH 64-bit halves of each raw
// product in separate u128s (no per-product reduction — one widening mul and
// two adds per term). Since 2^64 = EPS (mod p), the sum is recovered as
// reduce128(acc_lo + EPS * acc_hi), exact while acc_hi < 2^96 — i.e. for up
// to ~2^31 accumulated terms, and N_r <= 72 here. The EXACT-INTEGER contract
// (coefficients of the true integer result < p/2) is asserted from the
// regime bound at construction, never assumed from data; the worst-case
// self-tests drive the accumulator to the exact bound.

pub struct A1CommitKernel {
    pub rows: usize,
    pub inner: usize,
    pub q: u64,
    pub b_max: u128, // column-operand contract bound (|column coeff| <= b_max)
    g_hat: Vec<[u64; D]>, // rows * inner cached forward transforms
}

impl A1CommitKernel {
    /// g: rows*inner ring elements (row-major, coefficients in [0, q)).
    /// b_max is the CONTRACT bound on the column operands this kernel will
    /// ever see (1 for ternary/binary randomness, 12*sigma for Gaussian
    /// masks, ...). The single-prime capacity contract
    /// inner * d * (q-1)/2 * b_max <= (p-1)/2 is asserted here — a static
    /// regime property.
    pub fn new(g: &[Vec<u64>], rows: usize, inner: usize, q: u64, b_max: u128, t: &NttTables) -> Self {
        let (fits, bits) = capacity(inner as u128, ((q - 1) / 2) as u128, b_max);
        assert!(
            fits,
            "A1 commit kernel outside single-prime capacity ({bits} bits; n_acc={inner}, b_max={b_max}) — use A1GemmKernel for automatic limb-split fallback"
        );
        let g_hat = g
            .iter()
            .map(|poly| {
                let mut f = [0u64; D];
                for i in 0..D {
                    f[i] = lift_to_p(balanced_mod_q(poly[i], q));
                }
                ntt_fwd(&mut f, t);
                f
            })
            .collect();
        A1CommitKernel { rows, inner, q, b_max, g_hat }
    }

    /// Bytes held by the cached NTT-domain key rows.
    pub fn cached_bytes(&self) -> usize {
        self.g_hat.len() * D * 8
    }

    /// One column of R (inner bounded ring elements, |coeff| <= b_max) ->
    /// rows output elements.
    pub fn commit_column(&self, r_col: &[Vec<i64>], t: &NttTables) -> Vec<Vec<u64>> {
        debug_assert_eq!(r_col.len(), self.inner);
        // Forward transforms of the column (once per column, shared by rows).
        let r_hat: Vec<[u64; D]> = r_col
            .iter()
            .map(|poly| {
                let mut f = [0u64; D];
                for i in 0..D {
                    debug_assert!(poly[i].unsigned_abs() as u128 <= self.b_max);
                    f[i] = lift_to_p(poly[i]);
                }
                ntt_fwd(&mut f, t);
                f
            })
            .collect();
        (0..self.rows)
            .map(|row| {
                let mut acc_lo = [0u128; D];
                let mut acc_hi = [0u128; D];
                for c in 0..self.inner {
                    let gh = &self.g_hat[row * self.inner + c];
                    let rh = &r_hat[c];
                    for k in 0..D {
                        let prod = gh[k] as u128 * rh[k] as u128;
                        acc_lo[k] += prod as u64 as u128;
                        acc_hi[k] += (prod >> 64) as u128;
                    }
                }
                let mut v = [0u64; D];
                for k in 0..D {
                    // sum = acc_lo + 2^64*acc_hi = acc_lo + EPS*acc_hi (mod p);
                    // < 2^71 + 2^103 at N_r = 72 — fits u128 with margin.
                    v[k] = reduce128(acc_lo[k] + EPS as u128 * acc_hi[k]);
                }
                ntt_inv(&mut v, t);
                v.iter().map(|&u| mod_q_centered(center_from_p(u), self.q)).collect()
            })
            .collect()
    }
}

/// A1 commit kernel for the GENERAL/bounded regime (regime (b)/(c) columns —
/// e.g. Gaussian mask commitments at q46, where key x mask exceeds one
/// prime): both operands limb-split, 3 Karatsuba sub-products, all three
/// accumulated in the NTT domain (the sub-product bounds leave ~10+ bits of
/// headroom, so the full module dimension accumulates in-domain), 3 inverse
/// transforms per output element, exact recompose mod q.
///
/// Cached per key element: 3 transforms (lo, hi, lo+hi). Per column element:
/// 2 forward transforms + one NTT-domain add (linearity gives the mid
/// transform). Pointwise: 3 muls per coefficient per term.
pub struct A1LimbCommitKernel {
    pub rows: usize,
    pub inner: usize,
    pub q: u64,
    pub b_max: u128,
    l: u32,                    // COMMON limb base (Karatsuba needs one base)
    g_hat: Vec<[[u64; D]; 3]>, // per key element: [lo, hi, lo+hi] transforms
}

impl A1LimbCommitKernel {
    pub fn new(g: &[Vec<u64>], rows: usize, inner: usize, q: u64, b_max: u128, t: &NttTables) -> Self {
        // One base for BOTH operands: with a = a1*2^l + a0, b = b1*2^l + b0,
        // PM - P0 - P2 = a0 b1 + a1 b0 carries the single scale 2^l only if
        // both splits use the same l. l halves the key (the wider operand).
        let l = limb_bits(q);
        // PM dominates capacity: operand bounds are sums of the limb bounds.
        let a_pm = (1u128 << (l - 1)) + (((q as u128 - 1) / 2 + (1u128 << (l - 1))) >> l) + 1;
        let b_pm = (1u128 << (l - 1)) + ((b_max + (1u128 << (l - 1))) >> l) + 1;
        let (fits, bits) = capacity(inner as u128, a_pm, b_pm);
        assert!(
            fits,
            "limb commit kernel outside capacity ({bits} bits; n_acc={inner}, b_max={b_max}) — parameter regime fits NOTHING; the derive-time chain must reject it"
        );
        let g_hat = g
            .iter()
            .map(|poly| {
                let mut lo = [0u64; D];
                let mut hi = [0u64; D];
                let mut mid = [0u64; D];
                for i in 0..D {
                    let (lv, hv) = split_limbs(balanced_mod_q(poly[i], q), l);
                    lo[i] = lift_to_p(lv);
                    hi[i] = lift_to_p(hv);
                }
                ntt_fwd(&mut lo, t);
                ntt_fwd(&mut hi, t);
                for i in 0..D {
                    mid[i] = add_p(lo[i], hi[i]);
                }
                [lo, hi, mid]
            })
            .collect();
        A1LimbCommitKernel { rows, inner, q, b_max, l, g_hat }
    }

    pub fn cached_bytes(&self) -> usize {
        self.g_hat.len() * 3 * D * 8
    }

    /// One column of bounded integer ring elements (|v| <= b_max).
    pub fn commit_column(&self, col: &[Vec<i64>], t: &NttTables) -> Vec<Vec<u64>> {
        debug_assert_eq!(col.len(), self.inner);
        let col_hat: Vec<[[u64; D]; 3]> = col
            .iter()
            .map(|poly| {
                let mut lo = [0u64; D];
                let mut hi = [0u64; D];
                let mut mid = [0u64; D];
                for i in 0..D {
                    debug_assert!(poly[i].unsigned_abs() as u128 <= self.b_max);
                    let (lv, hv) = split_limbs(poly[i], self.l);
                    lo[i] = lift_to_p(lv);
                    hi[i] = lift_to_p(hv);
                }
                ntt_fwd(&mut lo, t);
                ntt_fwd(&mut hi, t);
                for i in 0..D {
                    mid[i] = add_p(lo[i], hi[i]);
                }
                [lo, hi, mid]
            })
            .collect();
        let q = self.q;
        let two_l = (1u64 << self.l) % q;
        let two_2l = mul_q(two_l, two_l, q);
        (0..self.rows)
            .map(|row| {
                let mut acc = [[[0u128; D]; 2]; 3]; // [P0|P2|PM][lo|hi][k]
                for c in 0..self.inner {
                    let gh = &self.g_hat[row * self.inner + c];
                    let rh = &col_hat[c];
                    for s in 0..3 {
                        for k in 0..D {
                            let prod = gh[s][k] as u128 * rh[s][k] as u128;
                            acc[s][0][k] += prod as u64 as u128;
                            acc[s][1][k] += (prod >> 64) as u128;
                        }
                    }
                }
                let mut parts = [[0u64; D]; 3];
                for s in 0..3 {
                    let mut v = [0u64; D];
                    for k in 0..D {
                        v[k] = reduce128(acc[s][0][k] + EPS as u128 * acc[s][1][k]);
                    }
                    ntt_inv(&mut v, t);
                    parts[s] = v;
                }
                (0..D)
                    .map(|k| {
                        let v0 = mod_q_centered(center_from_p(parts[0][k]), q);
                        let v2 = mod_q_centered(center_from_p(parts[1][k]), q);
                        let vm = mod_q_centered(center_from_p(parts[2][k]), q);
                        let mid = (vm + 2 * q - v0 - v2) % q;
                        (v0 + mul_q(two_l, mid, q) + mul_q(two_2l, v2, q)) % q
                    })
                    .collect()
            })
            .collect()
    }
}

// ---------------------------------------------------------------------------
// Regime-dispatching kernel: the integration entry point. Chooses the
// single-prime path when the (n_acc, q, b_max) regime fits the capacity
// contract and falls back to the limb-split path AUTOMATICALLY otherwise —
// over-capacity regimes are an expected configuration (e.g. Gaussian masks
// at q46, verifier response bounds at q31), never a panic. Construction
// panics only if the regime fits NOTHING (even limb sub-products overflow),
// which the derive-time parameter chain must have rejected already.

pub enum A1GemmKernel {
    Single(A1CommitKernel),
    Limb(A1LimbCommitKernel),
}

impl A1GemmKernel {
    pub fn new(g: &[Vec<u64>], rows: usize, inner: usize, q: u64, b_max: u128, t: &NttTables) -> Self {
        let (fits_single, _) = capacity(inner as u128, ((q - 1) / 2) as u128, b_max);
        if fits_single {
            A1GemmKernel::Single(A1CommitKernel::new(g, rows, inner, q, b_max, t))
        } else {
            A1GemmKernel::Limb(A1LimbCommitKernel::new(g, rows, inner, q, b_max, t))
        }
    }

    pub fn commit_column(&self, col: &[Vec<i64>], t: &NttTables) -> Vec<Vec<u64>> {
        match self {
            A1GemmKernel::Single(k) => k.commit_column(col, t),
            A1GemmKernel::Limb(k) => k.commit_column(col, t),
        }
    }

    pub fn path(&self) -> &'static str {
        match self {
            A1GemmKernel::Single(_) => "single-prime",
            A1GemmKernel::Limb(_) => "limb-split x3",
        }
    }

    pub fn cached_bytes(&self) -> usize {
        match self {
            A1GemmKernel::Single(k) => k.cached_bytes(),
            A1GemmKernel::Limb(k) => k.cached_bytes(),
        }
    }
}

/// The path `A1GemmKernel::new` would choose for a regime, without building
/// anything: `Some("single-prime" | "limb-split x3")`, or `None` if the
/// regime fits nothing (derive-time chains use this to fail loudly).
pub fn a1_regime_path(n_acc: usize, q: u64, b_max: u128) -> Option<&'static str> {
    if capacity(n_acc as u128, ((q - 1) / 2) as u128, b_max).0 {
        return Some("single-prime");
    }
    let l = limb_bits(q);
    let a_pm = (1u128 << (l - 1)) + (((q as u128 - 1) / 2 + (1u128 << (l - 1))) >> l) + 1;
    let b_pm = (1u128 << (l - 1)) + ((b_max + (1u128 << (l - 1))) >> l) + 1;
    if capacity(n_acc as u128, a_pm, b_pm).0 { Some("limb-split x3") } else { None }
}

// ---------------------------------------------------------------------------
// Regime (b'): challenge-combination sums. sum_i s_i * a_i over R_q with
// small s_i (|s| <= s_max, e.g. quinary challenges) and general mod-q a_i.
// Single-prime NTT-domain accumulation, AUTOMATICALLY chunked at the
// capacity-derived term limit (1023 terms at q46; ~2^25 at q31) with exact
// recovery + partial mod-q reduction between chunks. Panics only if even a
// single term exceeds capacity — a derive-time parameter failure, not a
// data condition (quinary s_max = 2 fits any q below ~2^54).

pub fn a1_combination_sum(a: &[Vec<u64>], s: &[Vec<i64>], s_max: u128, q: u64, t: &NttTables) -> Vec<u64> {
    assert_eq!(a.len(), s.len());
    let n_max = max_n_acc(((q - 1) / 2) as u128, s_max).min(1 << 31);
    assert!(
        n_max >= 1,
        "combination-sum single term exceeds single-prime capacity (s_max={s_max}) — the derive-time chain must reject this regime"
    );
    let n_max = n_max as usize;
    let mut out = vec![0u64; D];
    let mut idx = 0;
    while idx < a.len() {
        let end = (idx + n_max).min(a.len());
        let mut acc_lo = [0u128; D];
        let mut acc_hi = [0u128; D];
        for i in idx..end {
            let mut fa = [0u64; D];
            let mut fs = [0u64; D];
            for k in 0..D {
                fa[k] = lift_to_p(balanced_mod_q(a[i][k], q));
                debug_assert!(s[i][k].unsigned_abs() as u128 <= s_max);
                fs[k] = lift_to_p(s[i][k]);
            }
            ntt_fwd(&mut fa, t);
            ntt_fwd(&mut fs, t);
            for k in 0..D {
                let prod = fa[k] as u128 * fs[k] as u128;
                acc_lo[k] += prod as u64 as u128;
                acc_hi[k] += (prod >> 64) as u128;
            }
        }
        let mut v = [0u64; D];
        for k in 0..D {
            v[k] = reduce128(acc_lo[k] + EPS as u128 * acc_hi[k]);
        }
        ntt_inv(&mut v, t);
        for k in 0..D {
            let c = mod_q_centered(center_from_p(v[k]), q);
            let sum = out[k] + c;
            out[k] = if sum >= q { sum - q } else { sum };
        }
        idx = end;
    }
    out
}

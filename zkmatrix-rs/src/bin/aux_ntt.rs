// A1 prototype: auxiliary-modulus NTT evaluation of Route R ring products
// (docs/zkmatrix-poc/RING_MULT_BOTTLENECK.md Section 4, workstream A1;
// report: docs/zkmatrix-poc/A1_AUX_NTT_REPORT.md).
//
// The protocol ring is R_q = Z_q[X]/(X^128 + 1) with q = 5 mod 8 chosen for
// the Lyubashevsky-Seiler invertibility margin — which means R_q itself has
// no useful NTT (v2(q-1) = 2). But a ring product is an exact integer
// polynomial with bounded coefficients (|c_k| <= d * max|a| * max|b| over
// balanced representatives), so it can be computed over ANY modulus large
// enough to determine it, in particular over the NTT-friendly Goldilocks
// prime p = 2^64 - 2^32 + 1 (v2(p-1) = 32: 256th roots of unity exist, so
// the psi-twisted NEGACYCLIC length-128 transform works directly, no
// zero-padding). Reduce mod q at the end. Zero soundness interaction: q, the
// ring, the challenges and every protocol equation are untouched; this is
// purely a faster way to compute the same numbers (standard practice in RNS
// FHE implementations).
//
// Everything on the value path is exact integer arithmetic (u64/u128/i128);
// floating point appears only in timing/diagnostic printout.
//
// Run:  cargo run --release --bin aux_ntt            (self-tests + capacity table)
//       cargo run --release --bin aux_ntt bench      (adds the benchmark suite)

// ---------------------------------------------------------------------------
// Ring degree (matches ring_lattice.rs / ROUTE_R_DESIGN.md).

const D: usize = 128;
const LOG2_D: u32 = 7;

// Protocol moduli (no protocol role is played by p; q46 is the protocol
// recommendation of ROUTE_R_DESIGN.md Section 1, q31 the prototype modulus).
const Q46: u64 = 70_368_744_177_029; // 2^46 - 635, prime, q = 5 mod 8
const Q31: u64 = 2_147_483_629; // 2^31 - 19, prime, q = 5 mod 8

// ---------------------------------------------------------------------------
// Goldilocks arithmetic: p = 2^64 - 2^32 + 1.
//
// Facts used (verified in self-test): p is prime; p - 1 = 2^32 * (2^32 - 1)
// = 2^32 * 3 * 5 * 17 * 257 * 65537, so v2(p-1) = 32 and 256th roots of
// unity exist; 7 generates Z_p^*.

const P: u64 = 0xFFFF_FFFF_0000_0001;
const EPS: u64 = 0xFFFF_FFFF; // 2^32 - 1 = 2^64 mod p
const GEN: u64 = 7;

/// Branchless canonicalization to [0, p): subtract p if possible. Compiles
/// to a cmov — data-dependent branches cost ~3x NTT throughput here.
#[inline(always)]
fn canon_p(r: u64) -> u64 {
    let (d, borrow) = r.overflowing_sub(P);
    if borrow { r } else { d }
}

#[inline(always)]
fn add_p(a: u64, b: u64) -> u64 {
    // a, b < p. a + b < 2p < 2^65: on carry, a+b-2^64 + (2^32-1) = a+b-p,
    // and the EPS adjustment cannot re-carry (a+b-2^64 < 2^64 - 2^33 + 2).
    let (s, carry) = a.overflowing_add(b);
    canon_p(s.wrapping_add((carry as u64) * EPS))
}

#[inline(always)]
fn sub_p(a: u64, b: u64) -> u64 {
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
/// slow `% p` path over random and structured edge values in self-test.
#[inline(always)]
fn reduce128(x: u128) -> u64 {
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
fn mul_p(a: u64, b: u64) -> u64 {
    reduce128(a as u128 * b as u128)
}

fn pow_p(mut base: u64, mut e: u64) -> u64 {
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

fn inv_p(a: u64) -> u64 {
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

struct NttTables {
    psi_brv: [u64; D],  // psi^bitrev7(i)
    ipsi_brv: [u64; D], // psi^{-bitrev7(i)}
    n_inv: u64,
}

fn bitrev7(mut i: u32) -> u32 {
    let mut r = 0u32;
    for _ in 0..LOG2_D {
        r = (r << 1) | (i & 1);
        i >>= 1;
    }
    r
}

fn build_tables() -> NttTables {
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
fn ntt_fwd(a: &mut [u64; D], t: &NttTables) {
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
fn ntt_inv(a: &mut [u64; D], t: &NttTables) {
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
fn negacyclic_mul_p(a: &[u64; D], b: &[u64; D], t: &NttTables) -> [u64; D] {
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
fn negacyclic_schoolbook_p(a: &[u64; D], b: &[u64; D]) -> [u64; D] {
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
fn balanced_mod_q(v: u64, q: u64) -> i64 {
    if v > q / 2 { v as i64 - q as i64 } else { v as i64 }
}

/// Lift a balanced integer (|v| < p/2) into Z_p.
#[inline(always)]
fn lift_to_p(v: i64) -> u64 {
    if v >= 0 { v as u64 } else { P.wrapping_sub(v.unsigned_abs()) }
}

/// Centered representative of u in Z_p, in (-(p-1)/2, (p-1)/2].
#[inline(always)]
fn center_from_p(u: u64) -> i128 {
    if u > P / 2 { u as i128 - P as i128 } else { u as i128 }
}

/// Reduce an exact integer to [0, q).
#[inline(always)]
fn mod_q_i128(x: i128, q: u64) -> u64 {
    let r = x % q as i128;
    if r < 0 { (r + q as i128) as u64 } else { r as u64 }
}

/// Reduce a centered value |x| < 2^63 to [0, q) with a single u64 division
/// (the i128 remainder is a slow libcall; every recovered Z_p value is
/// centered below 2^63 by the capacity contract).
#[inline(always)]
fn mod_q_centered(x: i128, q: u64) -> u64 {
    debug_assert!(x.unsigned_abs() < 1 << 63);
    let r = (x.unsigned_abs() as u64) % q;
    if x < 0 && r != 0 { q - r } else { r }
}

// ---------------------------------------------------------------------------
// U2: capacity analysis. Exact u128 checks of the single-prime contract
//     n_acc * d * A * B <= (p-1)/2
// where A, B are the operand magnitude bounds (balanced representatives) and
// n_acc is how many ring products are accumulated before leaving the NTT
// domain (the module dimension N_r for the commit kernel).

/// Returns (fits_single_prime, bit_length_of_bound). Exact integer math.
fn capacity(n_acc: u128, a_max: u128, b_max: u128) -> (bool, u32) {
    // Largest case used: 2^11 * 2^7 * 2^45 * 2^45 = 2^108 — no u128 overflow.
    let bound = n_acc
        .checked_mul(D as u128)
        .and_then(|x| x.checked_mul(a_max))
        .and_then(|x| x.checked_mul(b_max))
        .expect("capacity bound overflows u128 — regime out of scope");
    (bound <= (P as u128 - 1) / 2, 128 - bound.leading_zeros())
}

/// Largest n_acc that keeps the single-prime contract for (A, B).
fn max_n_acc(a_max: u128, b_max: u128) -> u128 {
    (P as u128 - 1) / 2 / (D as u128) / a_max / b_max
}

fn print_capacity_table() {
    println!("[U2] capacity regimes (single Goldilocks prime: bound <= (p-1)/2, i.e. 63 bits)");
    println!(
        "  {:<44} {:>8} {:>8} {:>6} {:>10} {:>6}  {}",
        "operands (balanced magnitudes)", "log2 A", "log2 B", "n_acc", "bound bits", "fits", "prime config"
    );
    let bits = |x: u128| 128 - x.leading_zeros();
    let mut row = |label: &str, a: u128, b: u128, n_acc: u128| {
        let (fits, bnd_bits) = capacity(n_acc, a, b);
        let config = if fits { "single-prime NTT" } else { "limb-split x3 Karatsuba" };
        println!(
            "  {:<44} {:>8} {:>8} {:>6} {:>10} {:>6}  {}",
            label,
            bits(a).saturating_sub(1),
            bits(b).saturating_sub(1),
            n_acc,
            bnd_bits,
            if fits { "YES" } else { "no" },
            config
        );
    };
    let half = |q: u64| ((q - 1) / 2) as u128;

    // (a) THE GOLDEN CASE: key (mod q) x ternary randomness — the commit
    // kernel, the dominant LLM-scale cost. Fits ONE prime even at q46 with
    // the full module-dimension accumulated in the NTT domain.
    row("(a) key x ternary, q46, FFN N_r=72", half(Q46), 1, 72);
    row("(a) key x ternary, q46, n2048 N_r=54", half(Q46), 1, 54);
    row("(a) key x ternary, q31, proto N_r=26", half(Q31), 1, 26);
    println!(
        "      golden case headroom: ternary columns at q46 accumulate up to n_acc = {} in-domain",
        max_n_acc(half(Q46), 1)
    );

    // (b) key x small-Gaussian masks (12*sigma tail cut, alpha = 12 window
    // rejection as in the prototypes). sigma values: ROUTE_R_DESIGN Section 3
    // (log2 sigma = 28.6 / 30.0 rounded up to the next power of two — the
    // verdict is bits-scale either way); prototype sigma exact (ring_lattice
    // derive_sigma_params: 177,186).
    row("(b) key x mask 12s, q31 proto s=177186", half(Q31), 12 * 177_186, 26);
    row("(b) key x mask 12s, q46 n2048 s~2^28.6", half(Q46), 12 * (1u128 << 29), 54);
    row("(b) key x mask 12s, q46 FFN s~2^30", half(Q46), 12 * (1u128 << 30), 72);
    println!(
        "      single-prime capacity at q46 ends at B <= {} (12*sigma), i.e. sigma <~ {} — all protocol sigmas exceed it",
        max_n_acc(half(Q46), 1),
        max_n_acc(half(Q46), 1) / 12
    );

    // (b') quinary challenge x general mod-q: protocol combination sums.
    row("(b') quinary chal x mod-q, q46, 1023 terms", 2, half(Q46), 1023);
    println!(
        "      combination sums c*t / sum s_i a_i stay single-prime up to n_acc = {} terms at q46 (chunk or partial-reduce beyond)",
        max_n_acc(2, half(Q46))
    );

    // (c) general mod-q x mod-q (response x response, gate garbage terms).
    row("(c) general x general, q46", half(Q46), half(Q46), 1);
    row("(c) general x general, q31", half(Q31), half(Q31), 1);
    // Limb-split sub-product capacity (the fallback's own contract).
    let l46 = limb_bits(Q46);
    let l31 = limb_bits(Q31);
    row("(c) limb sub-products (lo+hi), q46", 1u128 << l46, 1u128 << l46, 1);
    row("(c) limb sub-products (lo+hi), q31", 1u128 << l31, 1u128 << l31, 1);
    println!(
        "      limb-split sub-products keep >= 10 bits of headroom: even general GEMMs may accumulate n_acc <= {} at q46",
        max_n_acc(1u128 << l46, 1u128 << l46)
    );
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
fn limb_bits(q: u64) -> u32 {
    let bits = 64 - ((q - 1) / 2).leading_zeros();
    bits.div_ceil(2)
}

/// Split a balanced value into balanced limbs (v = hi*2^L + lo).
#[inline(always)]
fn split_limbs(v: i64, l: u32) -> (i64, i64) {
    let half = 1i64 << (l - 1);
    let full = 1i64 << l;
    let lo = (v % full + full + half) % full - half; // balanced remainder
    let hi = (v - lo) >> l;
    (lo, hi)
}

/// General mod-q x mod-q negacyclic ring product via the limb-split path.
/// Inputs/outputs in [0, q). Exact for any q with limb sub-products inside
/// the capacity contract (checked once by the caller/self-test).
fn ring_mul_q_limbsplit(a: &[u64], b: &[u64], q: u64, t: &NttTables) -> Vec<u64> {
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
fn ring_mul_q_single(a: &[u64], b_small: &[i64], q: u64, t: &NttTables) -> Vec<u64> {
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
fn ring_mul_q_ternary_schoolbook(a: &[u64], b: &[i64], q: u64) -> Vec<u64> {
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
fn ring_mul_q_schoolbook(a: &[u64], b: &[u64], q: u64) -> Vec<u64> {
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

fn selftest_capacity_and_fallback() {
    println!("[U2] lifts, single-prime short-operand path, limb-split fallback");
    let t = build_tables();
    let mut rng = 0xa1a1_0002u64;

    for &q in &[Q46, Q31] {
        let qb = 64 - q.leading_zeros();
        // regime (a): key x ternary, random.
        let mut ok = true;
        for _ in 0..50 {
            let a: Vec<u64> = (0..D).map(|_| rng_below(&mut rng, q)).collect();
            let b_small: Vec<i64> =
                (0..D).map(|_| (rng_below(&mut rng, 3) as i64) - 1).collect();
            let b_mod: Vec<u64> = b_small.iter().map(|&v| mod_q_i128(v as i128, q)).collect();
            if ring_mul_q_single(&a, &b_small, q, &t) != ring_mul_q_schoolbook(&a, &b_mod, q) {
                ok = false;
                break;
            }
        }
        assert_true(&format!("single-prime key x ternary = schoolbook mod q ({qb}-bit q, 50 inputs)"), ok);

        // regime (a) worst case: hits the bound n=1, d * (q-1)/2 exactly.
        // a_0 = +M, a_i = -M (i >= 1), b = all ones: c_0 = d * M.
        let m = (q - 1) / 2;
        let mut a = vec![q - m; D]; // -M mod q
        a[0] = m;
        let b_small = vec![1i64; D];
        let b_mod = vec![1u64; D];
        let got = ring_mul_q_single(&a, &b_small, q, &t);
        let want = ring_mul_q_schoolbook(&a, &b_mod, q);
        let exact_c0 = (D as u128) * (m as u128);
        assert_true(
            &format!(
                "worst-case magnitude (c_0 = d*(q-1)/2, {} bits) exact ({qb}-bit q)",
                128 - exact_c0.leading_zeros()
            ),
            got == want && got[0] == (exact_c0 % q as u128) as u64,
        );

        // regime (b') quinary x general.
        let mut ok = true;
        for _ in 0..50 {
            let a: Vec<u64> = (0..D).map(|_| rng_below(&mut rng, q)).collect();
            let c_small: Vec<i64> =
                (0..D).map(|_| (rng_below(&mut rng, 5) as i64) - 2).collect();
            let c_mod: Vec<u64> = c_small.iter().map(|&v| mod_q_i128(v as i128, q)).collect();
            if ring_mul_q_single(&a, &c_small, q, &t) != ring_mul_q_schoolbook(&a, &c_mod, q) {
                ok = false;
                break;
            }
        }
        assert_true(&format!("single-prime quinary x mod-q = schoolbook ({qb}-bit q, 50 inputs)"), ok);

        // regime (c): general x general via limb split, random + worst case.
        let l = limb_bits(q);
        let (fits, _) = capacity(1, 1u128 << l, 1u128 << l);
        assert_true(&format!("limb sub-product contract holds (L = {l}, {qb}-bit q)"), fits);
        let mut ok = true;
        for trial in 0..50 {
            let mut a: Vec<u64> = (0..D).map(|_| rng_below(&mut rng, q)).collect();
            let mut b: Vec<u64> = (0..D).map(|_| rng_below(&mut rng, q)).collect();
            if trial == 0 {
                // worst case: max-magnitude balanced values everywhere.
                a = vec![(q - 1) / 2; D];
                b = vec![q - (q - 1) / 2; D];
            }
            if ring_mul_q_limbsplit(&a, &b, q, &t) != ring_mul_q_schoolbook(&a, &b, q) {
                ok = false;
                break;
            }
        }
        assert_true(
            &format!("limb-split general x general = schoolbook mod q ({qb}-bit q, 50 inputs incl. worst case)"),
            ok,
        );
    }
}

// ---------------------------------------------------------------------------
// RNG (splitmix64, same discipline as the sibling prototypes).

fn splitmix64(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9e37_79b9_7f4a_7c15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
    z ^ (z >> 31)
}

fn rng_below(rng: &mut u64, bound: u64) -> u64 {
    // Rejection on the top bits; bound < 2^63 everywhere we use it... except
    // bound = P where the masked draw is fine too (mask = next power of two).
    let mask = bound.next_power_of_two().wrapping_sub(1);
    let mask = if mask == 0 { u64::MAX } else { mask };
    loop {
        let v = splitmix64(rng) & mask;
        if v < bound {
            return v;
        }
    }
}

// ---------------------------------------------------------------------------
// U3: the GEMM-shaped commitment kernel. C = G * R over R_q, where
// G ((kappa + msg_r) x N_r) is the FIXED commitment key and R packs many
// ternary randomness columns (N_r ring elements each) — regime (a), the
// dominant LLM-scale cost.
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
// self-test drives the accumulator to the exact bound.

struct A1CommitKernel {
    rows: usize,
    inner: usize,
    q: u64,
    g_hat: Vec<[u64; D]>, // rows * inner cached forward transforms
}

impl A1CommitKernel {
    /// g: rows*inner ring elements (row-major, coefficients in [0, q)).
    fn new(g: &[Vec<u64>], rows: usize, inner: usize, q: u64, t: &NttTables) -> Self {
        // Regime (a) contract: n_acc = inner, A = (q-1)/2, B = 1 (ternary).
        let (fits, bits) = capacity(inner as u128, ((q - 1) / 2) as u128, 1);
        assert!(fits, "A1 commit kernel outside single-prime capacity ({bits} bits)");
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
        A1CommitKernel { rows, inner, q, g_hat }
    }

    /// One column of R (inner ternary ring elements) -> rows output elements.
    fn commit_column(&self, r_col: &[Vec<i64>], t: &NttTables) -> Vec<Vec<u64>> {
        debug_assert_eq!(r_col.len(), self.inner);
        // Forward transforms of the column (once per column, shared by rows).
        let r_hat: Vec<[u64; D]> = r_col
            .iter()
            .map(|poly| {
                let mut f = [0u64; D];
                for i in 0..D {
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
struct A1LimbCommitKernel {
    rows: usize,
    inner: usize,
    q: u64,
    l: u32,                    // COMMON limb base (Karatsuba needs one base)
    g_hat: Vec<[[u64; D]; 3]>, // per key element: [lo, hi, lo+hi] transforms
}

impl A1LimbCommitKernel {
    fn new(g: &[Vec<u64>], rows: usize, inner: usize, q: u64, b_max: u128, t: &NttTables) -> Self {
        // One base for BOTH operands: with a = a1*2^l + a0, b = b1*2^l + b0,
        // PM - P0 - P2 = a0 b1 + a1 b0 carries the single scale 2^l only if
        // both splits use the same l. l halves the key (the wider operand).
        let l = limb_bits(q);
        // PM dominates capacity: operand bounds are sums of the limb bounds.
        let a_pm = (1u128 << (l - 1)) + (((q as u128 - 1) / 2 + (1u128 << (l - 1))) >> l) + 1;
        let b_pm = (1u128 << (l - 1)) + ((b_max + (1u128 << (l - 1))) >> l) + 1;
        let (fits, bits) = capacity(inner as u128, a_pm, b_pm);
        assert!(fits, "limb commit kernel outside capacity ({bits} bits)");
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
        A1LimbCommitKernel { rows, inner, q, l, g_hat }
    }

    /// One column of bounded integer ring elements (|v| <= b_max).
    fn commit_column(&self, col: &[Vec<i64>], t: &NttTables) -> Vec<Vec<u64>> {
        debug_assert_eq!(col.len(), self.inner);
        let col_hat: Vec<[[u64; D]; 3]> = col
            .iter()
            .map(|poly| {
                let mut lo = [0u64; D];
                let mut hi = [0u64; D];
                let mut mid = [0u64; D];
                for i in 0..D {
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

// --- in-file baselines (same statement, no NTT) ----------------------------

/// Naive negacyclic schoolbook commit: per output element, 16384 u64 MACs
/// per ring-mult, u128 pos/neg lazy accumulation across the whole inner
/// dimension (exact: < 2^105 at q46), one reduction per output coefficient.
fn commit_column_schoolbook(
    g: &[Vec<u64>],
    rows: usize,
    inner: usize,
    r_col_mod: &[Vec<u64>],
    q: u64,
) -> Vec<Vec<u64>> {
    (0..rows)
        .map(|row| {
            let mut pos = [0u128; D];
            let mut neg = [0u128; D];
            for c in 0..inner {
                let a = &g[row * inner + c];
                let b = &r_col_mod[c];
                for i in 0..D {
                    let ai = a[i] as u128;
                    if ai == 0 {
                        continue;
                    }
                    for j in 0..D {
                        let prod = ai * b[j] as u128;
                        let k = i + j;
                        if k < D {
                            pos[k] += prod;
                        } else {
                            neg[k - D] += prod;
                        }
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
        })
        .collect()
}

/// Ternary-specialized schoolbook commit (the Tier-1 add/sub lever, same
/// shape as ring_lattice's ring_matvec_small): skips zero coefficients,
/// adds/subtracts key coefficients in i128.
fn commit_column_ternary_schoolbook(
    g: &[Vec<u64>],
    rows: usize,
    inner: usize,
    r_col: &[Vec<i64>],
    q: u64,
) -> Vec<Vec<u64>> {
    (0..rows)
        .map(|row| {
            let mut acc = [0i128; D];
            for c in 0..inner {
                let a = &g[row * inner + c];
                let x = &r_col[c];
                for i in 0..D {
                    let xi = x[i];
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
            }
            acc.iter().map(|&v| mod_q_i128(v, q)).collect()
        })
        .collect()
}

// --- k = 2 CRT-split baseline (the current Route R design point) -----------
//
// X^128 + 1 = (X^64 - r)(X^64 + r) mod q with r^2 = -1 (q = 5 mod 8). The
// split AMORTIZES like A1 does: key slots cached, column slots computed once,
// slot-wise 64x64 schoolbook MAC accumulation (8192 MACs per ring-mult),
// recombination once per output element.

fn mul_q(a: u64, b: u64, q: u64) -> u64 {
    ((a as u128 * b as u128) % q as u128) as u64
}

fn pow_q(mut base: u64, mut e: u64, q: u64) -> u64 {
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
/// quadratic nonresidue there; verified by the caller.
fn sqrt_m1(q: u64) -> u64 {
    let r = pow_q(2, (q - 1) / 4, q);
    assert_eq!(mul_q(r, r, q), q - 1, "sqrt(-1) construction failed");
    r
}

const HALF: usize = D / 2;

/// a(X) mod (X^64 - s): coefficient i picks up s * coefficient (i + 64).
fn to_slot_q(a: &[u64], s: u64, q: u64) -> Vec<u64> {
    (0..HALF)
        .map(|i| {
            let t = mul_q(s, a[i + HALF], q);
            let v = a[i] + t;
            if v >= q { v - q } else { v }
        })
        .collect()
}

struct K2CommitKernel {
    rows: usize,
    inner: usize,
    q: u64,
    r_pos: u64, // sqrt(-1)
    inv2: u64,
    inv2r: u64,
    g_pos: Vec<Vec<u64>>, // cached key slots, rows * inner each
    g_neg: Vec<Vec<u64>>,
}

impl K2CommitKernel {
    fn new(g: &[Vec<u64>], rows: usize, inner: usize, q: u64) -> Self {
        let r_pos = sqrt_m1(q);
        let r_neg = q - r_pos;
        let inv2 = pow_q(2, q - 2, q);
        let inv2r = mul_q(inv2, pow_q(r_pos, q - 2, q), q);
        let g_pos = g.iter().map(|p| to_slot_q(p, r_pos, q)).collect();
        let g_neg = g.iter().map(|p| to_slot_q(p, r_neg, q)).collect();
        K2CommitKernel { rows, inner, q, r_pos, inv2, inv2r, g_pos, g_neg }
    }

    fn commit_column(&self, r_col_mod: &[Vec<u64>]) -> Vec<Vec<u64>> {
        let q = self.q;
        let r_neg = q - self.r_pos;
        let c_pos: Vec<Vec<u64>> =
            r_col_mod.iter().map(|p| to_slot_q(p, self.r_pos, q)).collect();
        let c_neg: Vec<Vec<u64>> =
            r_col_mod.iter().map(|p| to_slot_q(p, r_neg, q)).collect();
        (0..self.rows)
            .map(|row| {
                // Slot-wise negacyclic-64 schoolbook (X^64 = s in the slot),
                // u128 lazy accumulation across inner (exact: < 2^105).
                let mut out = vec![0u64; D];
                for (slot_idx, (gs, cs, s)) in [
                    (&self.g_pos, &c_pos, self.r_pos),
                    (&self.g_neg, &c_neg, r_neg),
                ]
                .iter()
                .enumerate()
                {
                    let mut wide = vec![0u128; 2 * HALF];
                    for c in 0..self.inner {
                        let a = &gs[row * self.inner + c];
                        let b = &cs[c];
                        for i in 0..HALF {
                            let ai = a[i] as u128;
                            if ai == 0 {
                                continue;
                            }
                            for j in 0..HALF {
                                wide[i + j] += ai * b[j] as u128;
                            }
                        }
                    }
                    let slot: Vec<u64> = (0..HALF)
                        .map(|k| {
                            let lo = (wide[k] % q as u128) as u64;
                            let hi = (wide[k + HALF] % q as u128) as u64;
                            let t = mul_q(*s, hi, q);
                            let v = lo + t;
                            if v >= q { v - q } else { v }
                        })
                        .collect();
                    // stash: reuse `out` halves before recombination
                    if slot_idx == 0 {
                        out[..HALF].copy_from_slice(&slot);
                    } else {
                        out[HALF..].copy_from_slice(&slot);
                    }
                }
                // Recombine: lo = (p + m)/2, hi = (p - m)/(2r).
                let mut res = vec![0u64; D];
                for i in 0..HALF {
                    let p = out[i];
                    let m = out[i + HALF];
                    let sum = if p + m >= q { p + m - q } else { p + m };
                    let dif = if p >= m { p - m } else { p + q - m };
                    res[i] = mul_q(self.inv2, sum, q);
                    res[i + HALF] = mul_q(self.inv2r, dif, q);
                }
                res
            })
            .collect()
    }
}

// --- U3 self-test -----------------------------------------------------------

fn selftest_commit_kernel() {
    println!("[U3] GEMM-shaped commit kernel (A1 cached-transform vs baselines)");
    let t = build_tables();
    let mut rng = 0xa1a1_0003u64;

    for &q in &[Q46, Q31] {
        let qb = 64 - q.leading_zeros();
        // Small shape + one realistic shape.
        for &(rows, inner, label) in
            &[(4usize, 6usize, "small 4x6"), (14, 36, "demo 14x36")]
        {
            let g: Vec<Vec<u64>> = (0..rows * inner)
                .map(|_| (0..D).map(|_| rng_below(&mut rng, q)).collect())
                .collect();
            let a1 = A1CommitKernel::new(&g, rows, inner, q, &t);
            let k2 = K2CommitKernel::new(&g, rows, inner, q);
            let mut all_ok = true;
            for _ in 0..8 {
                let r_col: Vec<Vec<i64>> = (0..inner)
                    .map(|_| (0..D).map(|_| (rng_below(&mut rng, 3) as i64) - 1).collect())
                    .collect();
                let r_mod: Vec<Vec<u64>> = r_col
                    .iter()
                    .map(|p| p.iter().map(|&v| mod_q_i128(v as i128, q)).collect())
                    .collect();
                let want = commit_column_schoolbook(&g, rows, inner, &r_mod, q);
                if a1.commit_column(&r_col, &t) != want
                    || commit_column_ternary_schoolbook(&g, rows, inner, &r_col, q) != want
                    || k2.commit_column(&r_mod) != want
                {
                    all_ok = false;
                    break;
                }
            }
            assert_true(
                &format!("A1 = ternary-schoolbook = k2 = schoolbook, {label}, {qb}-bit q"),
                all_ok,
            );
        }

        // Worst-case accumulator test: every key element the +-M pattern
        // (a_0 = +M, a_i = -M), every column element all-ones ternary. The
        // exact integer coefficient 0 of each output = inner * d * M — the
        // regime-(a) bound hit EXACTLY; checked against the closed form.
        let rows = 2;
        let inner = if q == Q46 { 72 } else { 26 }; // largest table shapes
        let m = (q - 1) / 2;
        let mut pattern = vec![q - m; D];
        pattern[0] = m;
        let g: Vec<Vec<u64>> = (0..rows * inner).map(|_| pattern.clone()).collect();
        let r_col: Vec<Vec<i64>> = (0..inner).map(|_| vec![1i64; D]).collect();
        let r_mod: Vec<Vec<u64>> = (0..inner).map(|_| vec![1u64; D]).collect();
        let a1 = A1CommitKernel::new(&g, rows, inner, q, &t);
        let got = a1.commit_column(&r_col, &t);
        let want = commit_column_schoolbook(&g, rows, inner, &r_mod, q);
        let exact = inner as u128 * D as u128 * m as u128;
        let (fits, bits) = capacity(inner as u128, m as u128, 1);
        assert!(fits);
        assert_true(
            &format!(
                "worst-case accumulator (exact c_0 = N_r*d*(q-1)/2, {bits} bits < 63) exact, N_r={inner}, {qb}-bit q"
            ),
            got == want && got[0][0] == (exact % q as u128) as u64,
        );
    }

    // Limb-split GEMM kernel (regime (b) mask columns at q46): random and
    // max-magnitude columns at full FFN accumulation depth.
    let q = Q46;
    let (rows, inner) = (3usize, 72usize);
    let b_mask: i64 = 12 << 30; // 12 * 2^30 ~ FFN-scale 12*sigma
    let g: Vec<Vec<u64>> = (0..rows * inner)
        .map(|_| (0..D).map(|_| rng_below(&mut rng, q)).collect())
        .collect();
    let limb = A1LimbCommitKernel::new(&g, rows, inner, q, b_mask as u128, &t);
    let mut ok = true;
    for trial in 0..6 {
        let col: Vec<Vec<i64>> = (0..inner)
            .map(|_| {
                (0..D)
                    .map(|_| {
                        if trial == 0 {
                            b_mask // max magnitude everywhere
                        } else {
                            rng_below(&mut rng, 2 * b_mask as u64 + 1) as i64 - b_mask
                        }
                    })
                    .collect()
            })
            .collect();
        let col_mod: Vec<Vec<u64>> = col
            .iter()
            .map(|p| p.iter().map(|&v| mod_q_i128(v as i128, q)).collect())
            .collect();
        if limb.commit_column(&col, &t) != commit_column_schoolbook(&g, rows, inner, &col_mod, q) {
            ok = false;
            break;
        }
    }
    assert_true(
        "limb-split GEMM kernel = schoolbook on 12*2^30-bounded mask columns (N_r=72, q46, incl. max-magnitude)",
        ok,
    );
}

// ---------------------------------------------------------------------------
// U4: benchmarks. Single-threaded on purpose (the machine is shared with a
// sibling agent's benchmarks; medians over pinned repetition counts are the
// defensible statistic). Effective MACs/s = ring-mults/s x d^2 (the
// schoolbook-equivalent MAC count of one ring multiplication) — the unit the
// LLM-scale commit-bill estimates are written in.

use std::time::Instant;

const BENCH_REPS: usize = 9; // pinned; median reported
const MULT_ITERS: usize = 1000; // ring-mults per timed repetition

fn median(mut v: Vec<f64>) -> f64 {
    v.sort_by(|a, b| a.partial_cmp(b).unwrap());
    v[v.len() / 2]
}

/// Standalone k = 2 ring mult (split both operands, two 64x64 slot
/// schoolbooks, recombine) — the per-mult form of the K2CommitKernel path.
fn ring_mul_q_k2(a: &[u64], b: &[u64], q: u64, r_pos: u64, inv2: u64, inv2r: u64) -> Vec<u64> {
    let r_neg = q - r_pos;
    let mut out = vec![0u64; D];
    for (idx, s) in [r_pos, r_neg].iter().enumerate() {
        let sa = to_slot_q(a, *s, q);
        let sb = to_slot_q(b, *s, q);
        let mut wide = vec![0u128; 2 * HALF];
        for i in 0..HALF {
            let ai = sa[i] as u128;
            if ai == 0 {
                continue;
            }
            for j in 0..HALF {
                wide[i + j] += ai * sb[j] as u128;
            }
        }
        for k in 0..HALF {
            let lo = (wide[k] % q as u128) as u64;
            let hi = (wide[k + HALF] % q as u128) as u64;
            let t = mul_q(*s, hi, q);
            let v = lo + t;
            out[idx * HALF + k] = if v >= q { v - q } else { v };
        }
    }
    let mut res = vec![0u64; D];
    for i in 0..HALF {
        let p = out[i];
        let m = out[i + HALF];
        let sum = if p + m >= q { p + m - q } else { p + m };
        let dif = if p >= m { p - m } else { p + q - m };
        res[i] = mul_q(inv2, sum, q);
        res[i + HALF] = mul_q(inv2r, dif, q);
    }
    res
}

fn bench_single_mults(t: &NttTables) {
    println!("[U4a] single ring-mult, d = 128 (median of {BENCH_REPS} reps x {MULT_ITERS} mults, 1 thread)");
    println!(
        "  {:<44} {:>10} {:>14} {:>12}",
        "method (operand regime)", "us/mult", "ring-mults/s", "eff MMAC/s"
    );
    let mut rng = 0xa1a1_0004u64;
    const POOL: usize = 32;
    for &q in &[Q46, Q31] {
        let qb = 64 - q.leading_zeros();
        let r_pos = sqrt_m1(q);
        let inv2 = pow_q(2, q - 2, q);
        let inv2r = mul_q(inv2, pow_q(r_pos, q - 2, q), q);
        let gen_pool: Vec<Vec<u64>> = (0..POOL)
            .map(|_| (0..D).map(|_| rng_below(&mut rng, q)).collect())
            .collect();
        let gen_pool2: Vec<Vec<u64>> = (0..POOL)
            .map(|_| (0..D).map(|_| rng_below(&mut rng, q)).collect())
            .collect();
        let ter_pool: Vec<Vec<i64>> = (0..POOL)
            .map(|_| (0..D).map(|_| (rng_below(&mut rng, 3) as i64) - 1).collect())
            .collect();

        let mut run = |label: &str, f: &mut dyn FnMut(usize) -> u64| {
            let mut times = Vec::with_capacity(BENCH_REPS);
            let mut sink = 0u64;
            for _ in 0..BENCH_REPS {
                let start = Instant::now();
                for i in 0..MULT_ITERS {
                    sink ^= f(i % POOL);
                }
                times.push(start.elapsed().as_secs_f64());
            }
            std::hint::black_box(sink);
            let per = median(times) / MULT_ITERS as f64;
            println!(
                "  {:<44} {:>10.3} {:>14.0} {:>12.1}",
                format!("{label}, q{qb}"),
                per * 1e6,
                1.0 / per,
                (D * D) as f64 / per / 1e6
            );
        };

        run("schoolbook (general x general)", &mut |i| {
            ring_mul_q_schoolbook(&gen_pool[i], &gen_pool2[i], q)[0]
        });
        run("schoolbook ternary-spec (key x ternary)", &mut |i| {
            ring_mul_q_ternary_schoolbook(&gen_pool[i], &ter_pool[i], q)[0]
        });
        run("k2 split (general x general)", &mut |i| {
            ring_mul_q_k2(&gen_pool[i], &gen_pool2[i], q, r_pos, inv2, inv2r)[0]
        });
        run("A1 single-prime (key x ternary)", &mut |i| {
            ring_mul_q_single(&gen_pool[i], &ter_pool[i], q, t)[0]
        });
        run("A1 limb-split (general x general)", &mut |i| {
            ring_mul_q_limbsplit(&gen_pool[i], &gen_pool2[i], q, t)[0]
        });
    }

    // Transform primitives (feeds the report's cost model).
    let mut a = [0u64; D];
    for x in a.iter_mut() {
        *x = rng_below(&mut rng, P);
    }
    let mut times_f = Vec::new();
    let mut times_i = Vec::new();
    for _ in 0..BENCH_REPS {
        let start = Instant::now();
        for _ in 0..MULT_ITERS {
            ntt_fwd(&mut a, t);
        }
        times_f.push(start.elapsed().as_secs_f64());
        let start = Instant::now();
        for _ in 0..MULT_ITERS {
            ntt_inv(&mut a, t);
        }
        times_i.push(start.elapsed().as_secs_f64());
    }
    std::hint::black_box(&a);
    println!(
        "  primitive: ntt_fwd {:.0} ns, ntt_inv {:.0} ns (448 butterflies each)",
        median(times_f) / MULT_ITERS as f64 * 1e9,
        median(times_i) / MULT_ITERS as f64 * 1e9
    );
}

/// Median per-column seconds over BENCH_REPS pinned repetitions of `f`
/// applied to each of `cols` inputs.
fn time_per_col<T>(cols: &[T], f: &mut dyn FnMut(&T)) -> f64 {
    let mut times = Vec::with_capacity(BENCH_REPS);
    for _ in 0..BENCH_REPS {
        let start = Instant::now();
        for col in cols {
            f(col);
        }
        times.push(start.elapsed().as_secs_f64() / cols.len() as f64);
    }
    median(times)
}

fn bench_commit_kernel(t: &NttTables) {
    let q = Q46;
    let mut rng = 0xa1a1_0005u64;
    // (label, rows = kappa + msg_r, inner = N_r) — ROUTE_R_DESIGN Section 3.
    let shapes: [(&str, usize, usize); 3] =
        [("demo 14 x 36", 14, 36), ("n2048 Pi2 31 x 54", 31, 54), ("FFN 47 x 72", 47, 72)];
    // Pinned column counts per timed rep (slow methods get fewer).
    let cols_fast = 16;
    let cols_slow = 2;
    let b_mask: i64 = 12 << 30; // FFN-scale mask magnitude, 12 * sigma at sigma = 2^30

    println!("[U4b] commit kernel C = G x R, q46 (median of {BENCH_REPS} reps, 1 thread)");
    println!(
        "  {:<26} {:<30} {:>12} {:>14} {:>12} {:>8} {:>8}",
        "shape (rows x N_r)", "method (column regime)", "ms/column", "ring-mults/s", "eff MMAC/s", "vs schb", "vs k2"
    );
    for (label, rows, inner) in shapes {
        let g: Vec<Vec<u64>> = (0..rows * inner)
            .map(|_| (0..D).map(|_| rng_below(&mut rng, q)).collect())
            .collect();
        let a1 = A1CommitKernel::new(&g, rows, inner, q, t);
        let a1_limb = A1LimbCommitKernel::new(&g, rows, inner, q, b_mask as u128, t);
        let k2 = K2CommitKernel::new(&g, rows, inner, q);
        // Fixed column sets, generated outside all timing.
        let ter_cols: Vec<Vec<Vec<i64>>> = (0..cols_fast)
            .map(|_| {
                (0..inner)
                    .map(|_| (0..D).map(|_| (rng_below(&mut rng, 3) as i64) - 1).collect())
                    .collect()
            })
            .collect();
        let ter_mod: Vec<Vec<Vec<u64>>> = ter_cols
            .iter()
            .map(|col| {
                col.iter()
                    .map(|p| p.iter().map(|&v| mod_q_i128(v as i128, q)).collect())
                    .collect()
            })
            .collect();
        let mask_cols: Vec<Vec<Vec<i64>>> = (0..cols_fast)
            .map(|_| {
                (0..inner)
                    .map(|_| {
                        (0..D)
                            .map(|_| rng_below(&mut rng, 2 * b_mask as u64 + 1) as i64 - b_mask)
                            .collect()
                    })
                    .collect()
            })
            .collect();
        let mask_mod: Vec<Vec<Vec<u64>>> = mask_cols
            .iter()
            .map(|col| {
                col.iter()
                    .map(|p| p.iter().map(|&v| mod_q_i128(v as i128, q)).collect())
                    .collect()
            })
            .collect();
        let ring_mults = (rows * inner) as f64;

        let mut results: Vec<(&str, f64)> = Vec::new();
        results.push((
            "schoolbook (any)",
            time_per_col(&ter_mod[..cols_slow], &mut |col| {
                std::hint::black_box(commit_column_schoolbook(&g, rows, inner, col, q));
            }),
        ));
        results.push((
            "ternary-schoolbook (ternary)",
            time_per_col(&ter_cols, &mut |col| {
                std::hint::black_box(commit_column_ternary_schoolbook(&g, rows, inner, col, q));
            }),
        ));
        results.push((
            "k2 split cached (any)",
            time_per_col(&ter_mod[..cols_slow], &mut |col| {
                std::hint::black_box(k2.commit_column(col));
            }),
        ));
        results.push((
            "A1 single-prime (ternary)",
            time_per_col(&ter_cols, &mut |col| {
                std::hint::black_box(a1.commit_column(col, t));
            }),
        ));
        results.push((
            "A1 limb-split (mask 12s~2^33.6)",
            time_per_col(&mask_cols, &mut |col| {
                std::hint::black_box(a1_limb.commit_column(col, t));
            }),
        ));
        // Baseline check: schoolbook cost is operand-independent (same u64
        // MACs); measure once on mask columns to confirm, folded into notes.
        let schb_mask = time_per_col(&mask_mod[..cols_slow], &mut |col| {
            std::hint::black_box(commit_column_schoolbook(&g, rows, inner, col, q));
        });
        let schb = results[0].1;
        let k2_t = results[2].1;
        for (name, per_col) in &results {
            println!(
                "  {:<26} {:<30} {:>12.3} {:>14.0} {:>12.1} {:>8.1} {:>8.1}",
                label,
                name,
                per_col * 1e3,
                ring_mults / per_col,
                ring_mults * (D * D) as f64 / per_col / 1e6,
                schb / per_col,
                k2_t / per_col
            );
        }
        println!(
            "  {:<26} (schoolbook on mask columns: {:.3} ms/col — operand-independent as expected)",
            "", schb_mask * 1e3
        );
    }

    // Scaled-up FFN-representative run: many columns through the cached A1
    // kernel (amortization stability + a wall-clock anchor).
    let (rows, inner, cols) = (47usize, 72usize, 256usize);
    let g: Vec<Vec<u64>> = (0..rows * inner)
        .map(|_| (0..D).map(|_| rng_below(&mut rng, q)).collect())
        .collect();
    let a1 = A1CommitKernel::new(&g, rows, inner, q, t);
    let columns: Vec<Vec<Vec<i64>>> = (0..cols)
        .map(|_| {
            (0..inner)
                .map(|_| (0..D).map(|_| (rng_below(&mut rng, 3) as i64) - 1).collect())
                .collect()
        })
        .collect();
    let mut times = Vec::new();
    for _ in 0..3 {
        let start = Instant::now();
        for col in &columns {
            std::hint::black_box(a1.commit_column(col, t));
        }
        times.push(start.elapsed().as_secs_f64());
    }
    let total = median(times);
    let ring_mults = (rows * inner * cols) as f64;
    println!(
        "  scaled FFN 47 x 72 x {cols} cols, A1: {:.3} s total, {:.0} ring-mults/s, {:.1} eff MMAC/s (median of 3)",
        total,
        ring_mults / total,
        ring_mults * (D * D) as f64 / total / 1e6
    );
    println!("  caveat: shared machine (sibling agent benchmarks run concurrently); medians over pinned reps.");
}

// ---------------------------------------------------------------------------
// Self-test helpers.

fn assert_true(label: &str, cond: bool) {
    if cond {
        println!("  ok   {label}");
    } else {
        println!("  FAIL {label}");
        std::process::exit(1);
    }
}

fn selftest_goldilocks() {
    println!("[U1] Goldilocks arithmetic + negacyclic NTT");
    // p - 1 = 2^32 * 3 * 5 * 17 * 257 * 65537 (Fermat-prime factorization).
    let factors: [u64; 6] = [2, 3, 5, 17, 257, 65537];
    let mut prod: u128 = 1 << 32;
    for &f in &factors[1..] {
        prod *= f as u128;
    }
    assert_true("p - 1 factors as 2^32 * 3 * 5 * 17 * 257 * 65537", prod == (P - 1) as u128);
    let mut gen_ok = true;
    for &f in &factors {
        if pow_p(GEN, (P - 1) / f) == 1 {
            gen_ok = false;
        }
    }
    assert_true("7 generates Z_p^* (order checked at every prime factor)", gen_ok);

    // reduce128 vs the slow path, structured edges + randoms.
    let edges: [u128; 12] = [
        0,
        1,
        (P - 1) as u128,
        P as u128,
        (P + 1) as u128,
        u64::MAX as u128,
        1u128 << 64,
        (1u128 << 64) + 1,
        (P as u128 - 1) * (P as u128 - 1),
        u128::MAX,
        (u64::MAX as u128) << 64,
        ((P - 1) as u128) << 64,
    ];
    let mut red_ok = true;
    for &x in &edges {
        if reduce128(x) as u128 != x % P as u128 {
            red_ok = false;
        }
    }
    let mut rng = 0xa1a1_0001u64;
    for _ in 0..1_000_000 {
        let x = (splitmix64(&mut rng) as u128) << 64 | splitmix64(&mut rng) as u128;
        if reduce128(x) as u128 != x % P as u128 {
            red_ok = false;
            break;
        }
    }
    assert_true("reduce128 matches slow reduction (12 edges + 10^6 random u128)", red_ok);

    // psi really is a primitive 256th root.
    let psi = pow_p(GEN, (P - 1) / 256);
    assert_true("psi^128 = -1, psi^256 = 1", pow_p(psi, 128) == P - 1 && pow_p(psi, 256) == 1);

    let t = build_tables();
    // Roundtrip on random and on structured inputs.
    let mut rt_ok = true;
    for trial in 0..200 {
        let mut a = [0u64; D];
        for x in a.iter_mut() {
            *x = rng_below(&mut rng, P);
        }
        if trial == 0 {
            a = [0u64; D]; // all zero
        }
        if trial == 1 {
            a = [P - 1; D]; // worst-case magnitude
        }
        let orig = a;
        ntt_fwd(&mut a, &t);
        ntt_inv(&mut a, &t);
        if a != orig {
            rt_ok = false;
            break;
        }
    }
    assert_true("NTT roundtrip (inv o fwd = id; 200 inputs incl. 0 and p-1)", rt_ok);

    // Negacyclic product vs schoolbook over Z_p.
    let mut mul_ok = true;
    for trial in 0..100 {
        let mut a = [0u64; D];
        let mut b = [0u64; D];
        for x in a.iter_mut() {
            *x = rng_below(&mut rng, P);
        }
        for x in b.iter_mut() {
            *x = rng_below(&mut rng, P);
        }
        if trial == 0 {
            // Worst-case magnitude both sides.
            a = [P - 1; D];
            b = [P - 1; D];
        }
        if trial == 1 {
            // X^127 * X: exercises the wraparound sign, X^128 = -1.
            a = [0u64; D];
            b = [0u64; D];
            a[127] = 1;
            b[1] = 1;
        }
        if negacyclic_mul_p(&a, &b, &t) != negacyclic_schoolbook_p(&a, &b) {
            mul_ok = false;
            break;
        }
    }
    assert_true("NTT negacyclic product = schoolbook mod p (100 inputs incl. worst-case)", mul_ok);
    // The X^127 * X^1 = -X^0 identity, explicitly.
    let mut a = [0u64; D];
    let mut b = [0u64; D];
    a[127] = 1;
    b[1] = 1;
    let c = negacyclic_mul_p(&a, &b, &t);
    let mut expect = [0u64; D];
    expect[0] = P - 1;
    assert_true("X^127 * X = -1 (negacyclic wraparound)", c == expect);
}

// ---------------------------------------------------------------------------
// main dispatch.

fn main() {
    let mode = std::env::args().nth(1).unwrap_or_else(|| "self-test".to_string());
    println!("aux_ntt: A1 auxiliary-modulus NTT prototype");
    println!(
        "  protocol ring Z_q[X]/(X^{D} + 1), q46 = {Q46} (mod 8 = {}), q31 = {Q31} (mod 8 = {})",
        Q46 % 8,
        Q31 % 8
    );
    println!("  helper prime p = {P} = 2^64 - 2^32 + 1 (no protocol role)");

    selftest_goldilocks();
    selftest_capacity_and_fallback();
    selftest_commit_kernel();
    print_capacity_table();

    if mode == "bench" {
        let t = build_tables();
        bench_single_mults(&t);
        bench_commit_kernel(&t);
    }
    println!("aux_ntt self-test ok");
}

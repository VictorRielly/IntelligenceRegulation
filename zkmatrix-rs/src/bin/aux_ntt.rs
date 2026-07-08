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

#[inline(always)]
fn add_p(a: u64, b: u64) -> u64 {
    // a, b < p. a + b < 2p < 2^65: on carry, a+b-2^64 + (2^32-1) = a+b-p.
    let (s, carry) = a.overflowing_add(b);
    let mut r = if carry { s.wrapping_add(EPS) } else { s };
    if r >= P {
        r -= P;
    }
    r
}

#[inline(always)]
fn sub_p(a: u64, b: u64) -> u64 {
    // a, b < p. On borrow: a-b+2^64 - (2^32-1) = a-b+p.
    let (d, borrow) = a.overflowing_sub(b);
    if borrow { d.wrapping_sub(EPS) } else { d }
}

/// Reduce a full u128 mod p. With x = lo + 2^64*hi_lo + 2^96*hi_hi and
/// 2^64 = 2^32 - 1, 2^96 = -1 (mod p): x = lo + (2^32-1)*hi_lo - hi_hi.
/// Branch analysis (all cases stay canonical, < p, with ONE final
/// conditional subtraction): see A1_AUX_NTT_REPORT.md; cross-checked against
/// the slow `% p` path over random and structured edge values in self-test.
#[inline(always)]
fn reduce128(x: u128) -> u64 {
    let lo = x as u64;
    let hi = (x >> 64) as u64;
    let hi_lo = hi & EPS;
    let hi_hi = hi >> 32;
    let (t, borrow) = lo.overflowing_sub(hi_hi);
    let t = if borrow { t.wrapping_sub(EPS) } else { t };
    let t1 = (hi_lo << 32).wrapping_sub(hi_lo); // hi_lo * (2^32 - 1), exact
    let (r, carry) = t.overflowing_add(t1);
    let mut r = if carry { r.wrapping_add(EPS) } else { r };
    if r >= P {
        r -= P;
    }
    r
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
    let mut out = vec![0u64; D];
    for k in 0..D {
        let v0 = center_from_p(p0[k]);
        let v2 = center_from_p(p2[k]);
        let vm = center_from_p(pm[k]);
        // exact: |v| <= d * 2^(2L) <= 2^53 at q46; scaled by 2^2L fits i128.
        let c = v0 + ((vm - v0 - v2) << l) + (v2 << (2 * l));
        out[k] = mod_q_i128(c, q);
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
    fc.iter().map(|&u| mod_q_i128(center_from_p(u), q)).collect()
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
// Accumulator discipline: NTT-domain values are < 2^64; a u128 cannot hold
// even two raw 64x64 products, so each pointwise product is REDUCED to u64
// (reduce128, < p) and the reduced values are accumulated in u128 — exact
// for up to 2^64 terms, and N_r <= 72 here. One reduce128 at the end of the
// accumulation returns to Z_p. The EXACT-INTEGER contract (coefficients of
// the true integer result < p/2) is asserted from the regime bound at
// construction, never assumed from data.

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
                let mut acc = [0u128; D];
                for c in 0..self.inner {
                    let gh = &self.g_hat[row * self.inner + c];
                    let rh = &r_hat[c];
                    for k in 0..D {
                        acc[k] += mul_p(gh[k], rh[k]) as u128;
                    }
                }
                let mut v = [0u64; D];
                for k in 0..D {
                    v[k] = reduce128(acc[k]);
                }
                ntt_inv(&mut v, t);
                v.iter().map(|&u| mod_q_i128(center_from_p(u), self.q)).collect()
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
        println!("[bench] not yet implemented");
    }
    println!("aux_ntt self-test ok");
}

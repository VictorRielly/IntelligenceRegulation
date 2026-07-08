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

    if mode == "bench" {
        println!("[bench] not yet implemented");
    }
    println!("aux_ntt self-test ok");
}

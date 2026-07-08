// Route R design-spike prototype: arithmetic core for the cyclotomic ring
// lift of the lattice track (see docs/zkmatrix-poc/ROUTE_R_DESIGN.md).
//
// R_q = Z_q[X]/(X^d + 1), d = 128, q = 2^31 - 19 (prime, q = 5 mod 8), so
// X^d + 1 = (X^64 - r)(X^64 + r) with r^2 = -1 mod q: two irreducible
// halves, hence the Lyubashevsky-Seiler (LS18) bound: every nonzero y with
// ||y||_inf < q^(1/2)/sqrt(2) ~ 32768 is invertible. Challenge set:
// quinary-coefficient ring elements (|C| = 5^128 = 2^297.2); differences
// have ||.||_inf <= 4, so they are invertible unconditionally.
//
// Contents: ring arithmetic (naive negacyclic mul; NTT/CRT-split kernels are
// a follow-up, the two-way CRT here is used for slot semantics + inversion),
// coefficient norms, ternary/quinary/Gaussian sampling, a toy module
// commitment com(x; rho) = (A1 rho, A2 rho + x), and ONE complete
// Sigma-protocol round at ring level: the well-formedness opening proof
// (report Alg. 1 / Section 5.5 shape, the strictly-simpler special case of
// Pi1's Sigma step) with a quinary ring challenge, rejection sampling over
// coefficient norms, verification, and a valid/tampered/norm-overflow +
// extraction self-test. This is an arithmetic-core proof, NOT the full
// protocol.
//
// Run: cargo run --release --bin ring_lattice

use sha2::{Digest, Sha256};
use std::time::Instant;

// ---------------------------------------------------------------------------
// Modulus and ring constants.

const D: usize = 128; // ring degree, X^D + 1
const HALF: usize = D / 2;
const Q: u64 = 2_147_483_629; // 2^31 - 19, prime, q = 5 mod 8
const LOG2_Q: f64 = 31.0;
const LOG2_DELTA0: f64 = 0.005326; // log2(1.0037), same C3 model as Route Z
const SQRT_M1: u64 = 629_208_553; // r with r^2 = -1 mod q (verified in test)

// Derived prototype parameters (C0-C4 ring analogues; derivation mirrors
// derive_params_gadget in lattice_matmul.rs and is re-checked in the
// self-test): message = MSG_R ring elements (256 slots), randomness
// N_R ring elements, binding KAPPA ring rows.
const MSG_R: usize = 2;
const N_R: usize = 26;
const KAPPA: usize = 8;
const N_Z: usize = N_R * D; // 3328 integer coefficients of randomness

fn addm(a: u64, b: u64) -> u64 {
    let s = a + b;
    if s >= Q { s - Q } else { s }
}

fn subm(a: u64, b: u64) -> u64 {
    if a >= b { a - b } else { a + Q - b }
}

fn mulm(a: u64, b: u64) -> u64 {
    ((a as u128 * b as u128) % Q as u128) as u64
}

fn negm(a: u64) -> u64 {
    if a == 0 { 0 } else { Q - a }
}

/// Centered representative in (-q/2, q/2].
fn center(a: u64) -> i64 {
    if a > Q / 2 { a as i64 - Q as i64 } else { a as i64 }
}

fn to_mod(a: i64) -> u64 {
    let r = a % Q as i64;
    if r < 0 { (r + Q as i64) as u64 } else { r as u64 }
}

// ---------------------------------------------------------------------------
// Ring elements: dense coefficient vectors, length D, values in [0, q).

type Poly = Vec<u64>; // length D

fn poly_zero() -> Poly {
    vec![0u64; D]
}

fn poly_add(a: &[u64], b: &[u64]) -> Poly {
    (0..D).map(|i| addm(a[i], b[i])).collect()
}

fn poly_sub(a: &[u64], b: &[u64]) -> Poly {
    (0..D).map(|i| subm(a[i], b[i])).collect()
}

/// Naive negacyclic multiplication (16384 MACs). Lazy accumulation: products
/// are < 2^62, and D of them fit in u128 without intermediate reduction.
/// NTT over the two-way split is the production follow-up; timings below are
/// for THIS naive kernel and are labelled as such.
fn poly_mul(a: &[u64], b: &[u64]) -> Poly {
    let mut pos = [0u128; D];
    let mut neg = [0u128; D];
    for i in 0..D {
        let ai = a[i] as u128;
        if ai == 0 {
            continue;
        }
        for j in 0..D {
            let p = ai * b[j] as u128;
            let k = i + j;
            if k < D {
                pos[k] += p;
            } else {
                neg[k - D] += p; // X^D = -1
            }
        }
    }
    (0..D)
        .map(|k| subm((pos[k] % Q as u128) as u64, (neg[k] % Q as u128) as u64))
        .collect()
}

/// Multiplication of a small-integer polynomial (challenge, |coeff| <= 4) by
/// a small-integer polynomial (e.g. ternary randomness), over Z (no mod):
/// used for exact rejection-sampling centers. |result|_inf <= 4 * 1 * D.
fn poly_mul_small(a: &[i64], b: &[i64]) -> Vec<i64> {
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

fn poly_from_small(v: &[i64]) -> Poly {
    v.iter().map(|&x| to_mod(x)).collect()
}

// Norms over the centered coefficient embedding.
fn poly_linf(a: &[u64]) -> u64 {
    a.iter().map(|&x| center(x).unsigned_abs()).max().unwrap()
}

fn vec_norm_sq_i64(v: &[i64]) -> u128 {
    v.iter().map(|&x| (x as i128 * x as i128) as u128).sum()
}

// ---------------------------------------------------------------------------
// RNG (splitmix64, same discipline as lattice_matmul.rs) and a SHA-256
// counter-mode XOF for Fiat-Shamir expansion.

fn splitmix64(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9e37_79b9_7f4a_7c15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
    z ^ (z >> 31)
}

fn rng_field(rng: &mut u64) -> u64 {
    loop {
        let v = splitmix64(rng) >> 32; // 32-bit candidate, q < 2^31
        if v < Q {
            return v;
        }
    }
}

fn rng_ternary_poly(rng: &mut u64) -> Vec<i64> {
    let mut out = Vec::with_capacity(D);
    while out.len() < D {
        let mut w = splitmix64(rng);
        // 21 unbiased base-3 digits per word via rejection on 5-bit chunks.
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

struct XofReader {
    key: [u8; 32],
    counter: u64,
    buf: Vec<u8>,
    pos: usize,
}

impl XofReader {
    fn new(domain: &str, items: &[&[u8]]) -> Self {
        let mut hasher = Sha256::new();
        hasher.update(b"ring-lattice-v1");
        hasher.update(domain.as_bytes());
        for item in items {
            hasher.update((item.len() as u64).to_le_bytes());
            hasher.update(item);
        }
        XofReader { key: hasher.finalize().into(), counter: 0, buf: Vec::new(), pos: 0 }
    }

    fn next_bytes(&mut self, n: usize) -> Vec<u8> {
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

    fn next_u64(&mut self) -> u64 {
        let b = self.next_bytes(8);
        u64::from_le_bytes(b.try_into().unwrap())
    }

    fn next_field(&mut self) -> u64 {
        loop {
            let v = self.next_u64() >> 32;
            if v < Q {
                return v;
            }
        }
    }

    /// Unbiased quinary challenge coefficient in {-2,...,2}: rejection on
    /// bytes (250 = 50 * 5 accepted values).
    fn next_quinary(&mut self) -> i64 {
        loop {
            let b = self.next_bytes(1)[0];
            if b < 250 {
                return (b % 5) as i64 - 2;
            }
        }
    }

    fn next_challenge(&mut self) -> Vec<i64> {
        (0..D).map(|_| self.next_quinary()).collect()
    }
}

// ---------------------------------------------------------------------------
// Two-way CRT: R_q = F_q[X]/(X^64 - r) x F_q[X]/(X^64 + r), each factor a
// field F_{q^64}. Used for slot semantics, invertibility checks (LS18 in
// practice) and explicit inversion via extended Euclid.

type Slot = Vec<u64>; // length HALF, element of F_q[X]/(X^64 -+ r)

/// c(X) mod (X^64 - s): coefficient i picks up s * coefficient (i + 64).
fn to_slot(a: &[u64], s: u64) -> Slot {
    (0..HALF).map(|i| addm(a[i], mulm(s, a[i + HALF]))).collect()
}

fn to_crt(a: &[u64]) -> (Slot, Slot) {
    (to_slot(a, SQRT_M1), to_slot(a, negm(SQRT_M1)))
}

fn from_crt(p: &Slot, m: &Slot) -> Poly {
    // lo = (p + m)/2, hi = (p - m)/(2r)
    let inv2 = (Q + 1) / 2;
    let inv2r = mulm(inv2, modinv_scalar(SQRT_M1));
    let mut out = poly_zero();
    for i in 0..HALF {
        out[i] = mulm(inv2, addm(p[i], m[i]));
        out[i + HALF] = mulm(inv2r, subm(p[i], m[i]));
    }
    out
}

fn modinv_scalar(a: u64) -> u64 {
    // Fermat: a^(q-2) mod q.
    let mut result = 1u64;
    let mut base = a;
    let mut e = Q - 2;
    while e > 0 {
        if e & 1 == 1 {
            result = mulm(result, base);
        }
        base = mulm(base, base);
        e >>= 1;
    }
    result
}

/// Schoolbook multiplication in F_q[X]/(X^64 - s).
fn slot_mul(a: &[u64], b: &[u64], s: u64) -> Slot {
    let mut wide = vec![0u128; 2 * HALF];
    for i in 0..HALF {
        if a[i] == 0 {
            continue;
        }
        for j in 0..HALF {
            wide[i + j] += a[i] as u128 * b[j] as u128;
        }
    }
    (0..HALF)
        .map(|k| {
            let lo = (wide[k] % Q as u128) as u64;
            let hi = (wide[k + HALF] % Q as u128) as u64;
            addm(lo, mulm(s, hi))
        })
        .collect()
}

/// Extended Euclid in F_q[X]: inverse of a mod (X^64 - s), where the modulus
/// is irreducible, so every nonzero a is invertible. Returns None for a = 0.
fn slot_inv(a: &[u64], s: u64) -> Option<Slot> {
    // Work with plain coefficient vectors; deg tracked explicitly.
    let trim = |v: &mut Vec<u64>| {
        while v.len() > 1 && *v.last().unwrap() == 0 {
            v.pop();
        }
    };
    let is_zero = |v: &[u64]| v.iter().all(|&x| x == 0);
    if is_zero(a) {
        return None;
    }
    // modulus X^64 - s
    let mut r0: Vec<u64> = {
        let mut m = vec![0u64; HALF + 1];
        m[HALF] = 1;
        m[0] = negm(s);
        m
    };
    let mut r1: Vec<u64> = a.to_vec();
    trim(&mut r1);
    let mut t0: Vec<u64> = vec![0];
    let mut t1: Vec<u64> = vec![1];
    while !is_zero(&r1) {
        // divide r0 by r1: quotient qt, remainder rem
        let mut rem = r0.clone();
        let mut qt = vec![0u64; rem.len().saturating_sub(r1.len()) + 1];
        let lead_inv = modinv_scalar(*r1.last().unwrap());
        while rem.len() >= r1.len() && !is_zero(&rem) {
            let shift = rem.len() - r1.len();
            let coef = mulm(*rem.last().unwrap(), lead_inv);
            qt[shift] = addm(qt[shift], coef);
            for i in 0..r1.len() {
                rem[shift + i] = subm(rem[shift + i], mulm(coef, r1[i]));
            }
            trim(&mut rem);
            if rem.len() == 1 && rem[0] == 0 {
                break;
            }
        }
        // t2 = t0 - qt * t1
        let mut prod = vec![0u64; qt.len() + t1.len() - 1];
        for i in 0..qt.len() {
            if qt[i] == 0 {
                continue;
            }
            for j in 0..t1.len() {
                prod[i + j] = addm(prod[i + j], mulm(qt[i], t1[j]));
            }
        }
        let mut t2 = vec![0u64; t0.len().max(prod.len())];
        for i in 0..t2.len() {
            let a0 = if i < t0.len() { t0[i] } else { 0 };
            let b0 = if i < prod.len() { prod[i] } else { 0 };
            t2[i] = subm(a0, b0);
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
    // r0 is the gcd (a nonzero constant since the modulus is irreducible).
    let g_inv = modinv_scalar(r0[0]);
    let mut out = vec![0u64; HALF];
    for (i, &c) in t0.iter().enumerate() {
        if i < HALF {
            out[i] = mulm(c, g_inv);
        }
    }
    Some(out)
}

/// Ring inverse via CRT (exists iff both slots are nonzero).
fn poly_inv(a: &[u64]) -> Option<Poly> {
    let (p, m) = to_crt(a);
    let ip = slot_inv(&p, SQRT_M1)?;
    let im = slot_inv(&m, negm(SQRT_M1))?;
    Some(from_crt(&ip, &im))
}

// ---------------------------------------------------------------------------
// Gaussian sampling and rejection sampling (same window-rejection shape and
// alpha = 12 discipline as lattice_matmul.rs; f64 exp is a prototype
// shortcut, the report requires fixed-point for production).

fn gaussian_ivec(rng: &mut u64, len: usize, sigma: u64) -> Vec<i64> {
    let window = 12i64 * sigma as i64;
    let span = (2 * window + 1) as u64;
    let two_sigma_sq = 2.0 * sigma as f64 * sigma as f64;
    let mut out = Vec::with_capacity(len);
    while out.len() < len {
        let y = (splitmix64(rng) % span) as i64 - window;
        let p = (-(y as f64) * (y as f64) / two_sigma_sq).exp();
        let u = (splitmix64(rng) >> 11) as f64 / (1u64 << 53) as f64;
        if u < p {
            out.push(y);
        }
    }
    out
}

fn rejection_accept(rng: &mut u64, response: &[i64], center_v: &[i64], sigma: u64) -> bool {
    let mut norm_c: i128 = 0;
    let mut dot: i128 = 0;
    for (&z, &c) in response.iter().zip(center_v.iter()) {
        norm_c += c as i128 * c as i128;
        dot += z as i128 * c as i128;
    }
    let exponent = (norm_c - 2 * dot) as f64 / (2.0 * sigma as f64 * sigma as f64);
    let log_m = 1.0 + 1.0 / 288.0; // alpha = 12
    let threshold = (exponent - log_m).exp();
    if threshold >= 1.0 {
        return true;
    }
    let u = (splitmix64(rng) >> 11) as f64 / (1u64 << 53) as f64;
    u < threshold
}

// ---------------------------------------------------------------------------
// Toy module commitment over R_q: com(x; rho) = (A1 rho, A2 rho + x),
// A1 in R^{KAPPA x N_R}, A2 in R^{MSG_R x N_R}, rho ternary in R^{N_R}.

struct Crs {
    a1: Vec<Poly>, // KAPPA * N_R, row-major
    a2: Vec<Poly>, // MSG_R * N_R
    crs_hash: [u8; 32],
}

fn expand_crs(seed: u64) -> Crs {
    let mut reader = XofReader::new("A1A2", &[&seed.to_le_bytes()]);
    let mut a1 = Vec::with_capacity(KAPPA * N_R);
    for _ in 0..KAPPA * N_R {
        a1.push((0..D).map(|_| reader.next_field()).collect::<Poly>());
    }
    let mut a2 = Vec::with_capacity(MSG_R * N_R);
    for _ in 0..MSG_R * N_R {
        a2.push((0..D).map(|_| reader.next_field()).collect::<Poly>());
    }
    let mut hasher = Sha256::new();
    hasher.update(b"ring-crs");
    hasher.update(seed.to_le_bytes());
    hasher.update((KAPPA as u64).to_le_bytes());
    hasher.update((N_R as u64).to_le_bytes());
    hasher.update((MSG_R as u64).to_le_bytes());
    hasher.update(Q.to_le_bytes());
    Crs { a1, a2, crs_hash: hasher.finalize().into() }
}

/// rows x N_R ring matrix times a small-integer ring vector (entries |.| <=
/// bound_small so i128 lazy accumulation is exact).
fn ring_matvec_small(m: &[Poly], rows: usize, v: &[Vec<i64>]) -> Vec<Poly> {
    (0..rows)
        .map(|r| {
            let mut accp = [0i128; D];
            for c in 0..N_R {
                let a = &m[r * N_R + c];
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
                    let r = (x % Q as i128) as i64;
                    to_mod(r)
                })
                .collect::<Poly>()
        })
        .collect()
}

fn commit(crs: &Crs, x: &[Poly], rho: &[Vec<i64>]) -> (Vec<Poly>, Vec<Poly>) {
    let t1 = ring_matvec_small(&crs.a1, KAPPA, rho);
    let mut t2 = ring_matvec_small(&crs.a2, MSG_R, rho);
    for (t, xi) in t2.iter_mut().zip(x.iter()) {
        *t = poly_add(t, xi);
    }
    (t1, t2)
}

// ---------------------------------------------------------------------------
// The Sigma round: well-formedness opening proof (report Alg. 1 / Section
// 5.5 option 1). Statement: t1 = A1 rho for ternary rho (the message slot is
// then determined). One quinary ring challenge, r = 1.
//
// Prover:  y <- D_sigma^{N_Z};  w = A1 y;  c = H(stmt, w);  z = y + c rho
//          (over Z), rejection-sample on (z, center = c rho).
// Verifier: recompute c;  check A1 z = w + c t1 over R_q and ||z||_2 <= B.
//
// Norm chain (worst-case T1 discipline, mirrored from the report): the
// center is c rho with ||c rho||_2 <= ||c||_1 max * ||rho||_2 <= 2D sqrt(N_Z)
// (quinary l1 <= 2D); sigma = 12 T1; B = 1.2 sigma sqrt(N_Z); extraction
// beta = 2B + ||c - c'||_1 * B0 folded into C3.

struct SigmaParams {
    sigma: u64,
    bound_sq: u128,
    beta: u128,
}

fn derive_sigma_params() -> SigmaParams {
    let b0 = (N_Z as f64).sqrt();
    let t1 = 2.0 * D as f64 * b0; // ||c||_1 <= 2D, worst case
    let sigma = (12.0 * t1).ceil() as u64;
    let bound = 1.2 * sigma as f64 * (N_Z as f64).sqrt();
    let bound_sq = (bound * bound).ceil() as u128;
    let beta = (2.0 * bound + 4.0 * D as f64 * b0).ceil() as u128;
    // C0/C2 analogue: q > 8 beta with headroom; C3: binding rows.
    assert!((Q as u128) > 8 * beta, "C2: q too small for beta");
    let log2_beta = (beta as f64).log2();
    let k_z = ((log2_beta / 2.0) * (log2_beta / 2.0) / (LOG2_Q * LOG2_DELTA0)).ceil() as usize;
    assert!(KAPPA * D >= k_z, "C3: KAPPA too small: need k_Z >= {k_z}");
    // C4 analogue (knapsack MLWE hiding): N_Z - (KAPPA + MSG_R) D >= d_LWE.
    let d_lwe = (768.0 * LOG2_Q / 11.7).ceil() as usize;
    assert!(N_Z >= (KAPPA + MSG_R) * D + d_lwe, "C4: N too small");
    SigmaParams { sigma, bound_sq, beta }
}

struct OpeningProof {
    w: Vec<Poly>,
    z: Vec<Vec<i64>>, // integer responses (norm-checked, so not reduced)
}

fn statement_hash(crs: &Crs, t1: &[Poly], ctx: &[u8]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"ring-open-stmt-v1");
    hasher.update(crs.crs_hash);
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    for p in t1 {
        for &c in p.iter() {
            hasher.update(c.to_le_bytes());
        }
    }
    hasher.finalize().into()
}

fn commits_bytes(polys: &[Poly]) -> Vec<u8> {
    let mut out = Vec::with_capacity(polys.len() * D * 8);
    for p in polys {
        for &c in p.iter() {
            out.extend_from_slice(&c.to_le_bytes());
        }
    }
    out
}

fn challenge_from(h0: &[u8; 32], w: &[Poly]) -> Vec<i64> {
    XofReader::new("chal", &[h0, &commits_bytes(w)]).next_challenge()
}

fn prove_opening(
    sp: &SigmaParams,
    crs: &Crs,
    t1: &[Poly],
    rho: &[Vec<i64>],
    ctx: &[u8],
    rng: &mut u64,
) -> (OpeningProof, usize) {
    let h0 = statement_hash(crs, t1, ctx);
    let mut attempts = 0usize;
    loop {
        attempts += 1;
        let y: Vec<Vec<i64>> =
            (0..N_R).map(|_| gaussian_ivec(rng, D, sp.sigma)).collect();
        let w = ring_matvec_small(&crs.a1, KAPPA, &y);
        let c = challenge_from(&h0, &w);
        // center v = c * rho, response z = y + v, both exact over Z.
        let v: Vec<Vec<i64>> = rho.iter().map(|r| poly_mul_small(&c, r)).collect();
        let z: Vec<Vec<i64>> = y
            .iter()
            .zip(v.iter())
            .map(|(yi, vi)| yi.iter().zip(vi.iter()).map(|(&a, &b)| a + b).collect())
            .collect();
        let flat_z: Vec<i64> = z.iter().flatten().copied().collect();
        let flat_v: Vec<i64> = v.iter().flatten().copied().collect();
        if rejection_accept(rng, &flat_z, &flat_v, sp.sigma) {
            return (OpeningProof { w, z }, attempts);
        }
    }
}

fn verify_opening(
    sp: &SigmaParams,
    crs: &Crs,
    t1: &[Poly],
    ctx: &[u8],
    proof: &OpeningProof,
) -> bool {
    if proof.w.len() != KAPPA || proof.z.len() != N_R {
        return false;
    }
    // Norm check first: exact integers (the +q overflow test below shows the
    // mod-q checks alone cannot catch a shifted response).
    let flat: Vec<i64> = proof.z.iter().flatten().copied().collect();
    if vec_norm_sq_i64(&flat) > sp.bound_sq {
        return false;
    }
    let h0 = statement_hash(crs, t1, ctx);
    let c = challenge_from(&h0, &proof.w);
    let lhs = ring_matvec_small(&crs.a1, KAPPA, &proof.z);
    let c_mod = poly_from_small(&c);
    for i in 0..KAPPA {
        let rhs = poly_add(&proof.w[i], &poly_mul(&c_mod, &t1[i]));
        if lhs[i] != rhs {
            return false;
        }
    }
    true
}

// ===========================================================================
// Q3: generic-modulus layer and the k-way CRT split (k = 8 lives in a
// different residue class, q = 17 mod 32, than the k = 2 mandate's
// q = 5 mod 8 -- necessarily a different prime, so everything below is
// parametric in q). See scripts/route_r_params.py (k_split_study) for the
// residue-condition derivation, prime selection and verification.

/// q8 at 31 bits: largest prime < 2^31 with q = 17 mod 32 (v2(q-1) = 4), so
/// X^128 + 1 splits into exactly 8 irreducible degree-16 factors
/// X^16 - eta^(2t+1), eta a primitive 16th root of unity. LS18 at k = 8:
/// nonzero y with ||y||_inf < q^(1/8)/sqrt(8) = 5.19 invertible -- covers
/// quinary challenge differences (<= 4) with margin 1.30x.
const Q8: u64 = 2_147_483_249; // 2^31 - 399
const ETA8: u64 = 2_056_890_868; // primitive 16th root of unity mod Q8

#[derive(Clone, Copy)]
struct Zq {
    q: u64,
}

impl Zq {
    fn new(q: u64) -> Self {
        assert!(q % 2 == 1 && q < (1u64 << 60), "odd q below 2^60 expected");
        Zq { q }
    }
    fn add(&self, a: u64, b: u64) -> u64 {
        let s = a + b;
        if s >= self.q { s - self.q } else { s }
    }
    fn sub(&self, a: u64, b: u64) -> u64 {
        if a >= b { a - b } else { a + self.q - b }
    }
    fn mul(&self, a: u64, b: u64) -> u64 {
        ((a as u128 * b as u128) % self.q as u128) as u64
    }
    fn neg(&self, a: u64) -> u64 {
        if a == 0 { 0 } else { self.q - a }
    }
    fn center(&self, a: u64) -> i64 {
        if a > self.q / 2 { a as i64 - self.q as i64 } else { a as i64 }
    }
    fn to_mod(&self, a: i64) -> u64 {
        let r = a % self.q as i64;
        if r < 0 { (r + self.q as i64) as u64 } else { r as u64 }
    }
    fn pow(&self, mut b: u64, mut e: u64) -> u64 {
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
    fn inv(&self, a: u64) -> u64 {
        self.pow(a, self.q - 2)
    }
}

/// k-way CRT context: X^D + 1 = prod_i (X^(D/k) - slot_roots[i]) mod q,
/// realized as log2(k) levels of split butterflies. Built from zeta, a
/// primitive 2k-th root of unity (zeta^k = -1): node with modulus
/// X^(2m) - zeta^e splits into X^m -+ zeta^(e/2); exponents stay even until
/// the leaves, whose roots are the odd powers of zeta.
struct RingCtx {
    zq: Zq,
    k: usize,
    slot_deg: usize,
    levels: usize,
    split_roots: Vec<Vec<u64>>, // [level][node]: the s of that butterfly
    merge_inv2: u64,
    merge_inv2s: Vec<Vec<u64>>, // [level][node]: (2 s)^-1
    slot_roots: Vec<u64>,       // leaf roots, length k
}

fn ring_ctx(q: u64, zeta: u64, k: usize) -> RingCtx {
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

/// Forward split: coefficient vector -> k slot images (leaf order),
/// contiguous in one length-D buffer. log2(k) butterfly levels, D/2 mults
/// per level.
fn crt_split(ctx: &RingCtx, a: &[u64]) -> Vec<u64> {
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
fn crt_merge(ctx: &RingCtx, buf: &mut [u64]) {
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
fn slot_mul_g(zq: &Zq, a: &[u64], b: &[u64], s: u64, m: usize) -> Vec<u64> {
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
/// merge. (In GEMM-shaped kernels the splits amortize; see the benchmark
/// section.)
fn ring_mul_split(ctx: &RingCtx, a: &[u64], b: &[u64]) -> Poly {
    let sa = crt_split(ctx, a);
    let sb = crt_split(ctx, b);
    let mut out = vec![0u64; D];
    let m = ctx.slot_deg;
    for i in 0..ctx.k {
        let prod = slot_mul_g(&ctx.zq, &sa[i * m..(i + 1) * m], &sb[i * m..(i + 1) * m], ctx.slot_roots[i], m);
        out[i * m..(i + 1) * m].copy_from_slice(&prod);
    }
    crt_merge(ctx, &mut out);
    out
}

/// Generic negacyclic schoolbook (ground truth at any q < 2^60): the
/// pos/neg u128 accumulators hold D products < q^2 <= 2^120 -- exact.
fn poly_mul_g(zq: &Zq, a: &[u64], b: &[u64]) -> Poly {
    let mut pos = [0u128; D];
    let mut neg = [0u128; D];
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

/// Extended Euclid in F_q[X] mod (X^m - s) (irreducible): generic port of
/// slot_inv. Returns None for a = 0.
fn slot_inv_g(zq: &Zq, a: &[u64], s: u64, m: usize) -> Option<Vec<u64>> {
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
fn poly_inv_g(ctx: &RingCtx, a: &[u64]) -> Option<Poly> {
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

fn poly_linf_g(zq: &Zq, a: &[u64]) -> u64 {
    a.iter().map(|&x| zq.center(x).unsigned_abs()).max().unwrap()
}

fn poly_from_small_g(zq: &Zq, v: &[i64]) -> Poly {
    v.iter().map(|&x| zq.to_mod(x)).collect()
}

// ---------------------------------------------------------------------------
// Q3: the Sigma opening round at generic q (run at q8, k = 8 in the
// self-test). Same shapes and norm chain as the k = 2 path; the verifier's
// ring multiplication c * t1 goes through the k-way split kernel.

fn rng_field_g(rng: &mut u64, q: u64) -> u64 {
    loop {
        let v = splitmix64(rng) >> 33; // 31-bit candidate; q8 < 2^31
        if v < q {
            return v;
        }
    }
}

fn expand_crs_g(seed: u64, q: u64) -> Crs {
    let mut reader = XofReader::new("A1A2-g", &[&seed.to_le_bytes(), &q.to_le_bytes()]);
    let next_field = |reader: &mut XofReader| loop {
        let v = reader.next_u64() >> 33;
        if v < q {
            return v;
        }
    };
    let mut a1 = Vec::with_capacity(KAPPA * N_R);
    for _ in 0..KAPPA * N_R {
        a1.push((0..D).map(|_| next_field(&mut reader)).collect::<Poly>());
    }
    let mut a2 = Vec::with_capacity(MSG_R * N_R);
    for _ in 0..MSG_R * N_R {
        a2.push((0..D).map(|_| next_field(&mut reader)).collect::<Poly>());
    }
    let mut hasher = Sha256::new();
    hasher.update(b"ring-crs-g");
    hasher.update(seed.to_le_bytes());
    hasher.update((KAPPA as u64).to_le_bytes());
    hasher.update((N_R as u64).to_le_bytes());
    hasher.update((MSG_R as u64).to_le_bytes());
    hasher.update(q.to_le_bytes());
    Crs { a1, a2, crs_hash: hasher.finalize().into() }
}

/// rows x cols ring matrix (row-major) times small-integer ring vector,
/// mod q: exact i128 lazy accumulation as in ring_matvec_small.
fn ring_matvec_small_g(zq: &Zq, m: &[Poly], rows: usize, cols: usize, v: &[Vec<i64>]) -> Vec<Poly> {
    (0..rows)
        .map(|r| {
            let mut accp = [0i128; D];
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

fn derive_sigma_params_g(q: u64) -> SigmaParams {
    let log2_q = (q as f64).log2();
    let b0 = (N_Z as f64).sqrt();
    let t1 = 2.0 * D as f64 * b0;
    let sigma = (12.0 * t1).ceil() as u64;
    let bound = 1.2 * sigma as f64 * (N_Z as f64).sqrt();
    let bound_sq = (bound * bound).ceil() as u128;
    let beta = (2.0 * bound + 4.0 * D as f64 * b0).ceil() as u128;
    assert!((q as u128) > 8 * beta, "C2: q too small for beta");
    let log2_beta = (beta as f64).log2();
    let k_z = ((log2_beta / 2.0) * (log2_beta / 2.0) / (log2_q * LOG2_DELTA0)).ceil() as usize;
    assert!(KAPPA * D >= k_z, "C3: KAPPA too small: need k_Z >= {k_z}");
    let d_lwe = (768.0 * log2_q / 11.7).ceil() as usize;
    assert!(N_Z >= (KAPPA + MSG_R) * D + d_lwe, "C4: N too small");
    SigmaParams { sigma, bound_sq, beta }
}

fn statement_hash_g(q: u64, crs: &Crs, t1: &[Poly], ctx: &[u8]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"ring-open-stmt-g-v1");
    hasher.update(q.to_le_bytes());
    hasher.update(crs.crs_hash);
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    for p in t1 {
        for &c in p.iter() {
            hasher.update(c.to_le_bytes());
        }
    }
    hasher.finalize().into()
}

fn prove_opening_g(
    ctx_ring: &RingCtx,
    sp: &SigmaParams,
    crs: &Crs,
    t1: &[Poly],
    rho: &[Vec<i64>],
    ctx: &[u8],
    rng: &mut u64,
) -> (OpeningProof, usize) {
    let h0 = statement_hash_g(ctx_ring.zq.q, crs, t1, ctx);
    let mut attempts = 0usize;
    loop {
        attempts += 1;
        let y: Vec<Vec<i64>> = (0..N_R).map(|_| gaussian_ivec(rng, D, sp.sigma)).collect();
        let w = ring_matvec_small_g(&ctx_ring.zq, &crs.a1, KAPPA, N_R, &y);
        let c = challenge_from(&h0, &w);
        let v: Vec<Vec<i64>> = rho.iter().map(|r| poly_mul_small(&c, r)).collect();
        let z: Vec<Vec<i64>> = y
            .iter()
            .zip(v.iter())
            .map(|(yi, vi)| yi.iter().zip(vi.iter()).map(|(&a, &b)| a + b).collect())
            .collect();
        let flat_z: Vec<i64> = z.iter().flatten().copied().collect();
        let flat_v: Vec<i64> = v.iter().flatten().copied().collect();
        if rejection_accept(rng, &flat_z, &flat_v, sp.sigma) {
            return (OpeningProof { w, z }, attempts);
        }
    }
}

fn verify_opening_g(
    ctx_ring: &RingCtx,
    sp: &SigmaParams,
    crs: &Crs,
    t1: &[Poly],
    ctx: &[u8],
    proof: &OpeningProof,
) -> bool {
    if proof.w.len() != KAPPA || proof.z.len() != N_R {
        return false;
    }
    let flat: Vec<i64> = proof.z.iter().flatten().copied().collect();
    if vec_norm_sq_i64(&flat) > sp.bound_sq {
        return false;
    }
    let h0 = statement_hash_g(ctx_ring.zq.q, crs, t1, ctx);
    let c = challenge_from(&h0, &proof.w);
    let lhs = ring_matvec_small_g(&ctx_ring.zq, &crs.a1, KAPPA, N_R, &proof.z);
    let c_mod = poly_from_small_g(&ctx_ring.zq, &c);
    for i in 0..KAPPA {
        // The verifier's ring multiplication runs on the k-way split kernel.
        let rhs = poly_add_g(&ctx_ring.zq, &proof.w[i], &ring_mul_split(ctx_ring, &c_mod, &t1[i]));
        if lhs[i] != rhs {
            return false;
        }
    }
    true
}

fn poly_add_g(zq: &Zq, a: &[u64], b: &[u64]) -> Poly {
    (0..D).map(|i| zq.add(a[i], b[i])).collect()
}

// ===========================================================================
// Q2: the digit-decomposed opening round (see route_r_params.py, derive_q2,
// for the design rationale). A combination-magnitude witness u
// (||u||_inf <= WIT_W, standing in for sum_i s_i rho_i at t ~ 2048 combined
// commitments) cannot run the plain opening round at a 31-bit q: its norm
// chain needs q > 8 beta ~ 2^34. Decomposed into balanced base-2^e digit
// vectors with per-digit statements t_j = A1 u_j, the public recombination
// sum_j 2^(ej) t_j = t, and per-digit Sigma rounds sharing one challenge
// (jointly rejection-sampled), the chain shrinks to the digit scale and
// fits q8 with headroom. In the full protocol the digit ranges are exact
// ct-claims from the M2 gadget family; the prototype stand-in is the
// bundle norm check (flagged in the doc).

const DIGIT_E: u32 = 4; // digit base 2^e
const DIGIT_L: usize = 3; // digits: covers |coeff| <= W with L*e >= log2(W)+1
const WIT_W: i64 = 1 << 10; // combination-magnitude witness, ||u||_inf <= 2^10

struct DigitParams {
    sigma: u64,
    bound_sq: u128,  // bundle l2^2 response bound (over all L digits)
    center_sq: u128, // concentration restart rule on the center bundle
    beta: u128,
    beta_undecomposed: u128, // what the plain round would have needed
}

fn derive_digit_params(q: u64) -> DigitParams {
    let n_z = N_Z as f64;
    let log2_q = (q as f64).log2();
    let op_c = 1.3 * (2.0 * D as f64).sqrt(); // concentration operator norm
    let half = (1u64 << (DIGIT_E - 1)) as f64; // ||digit||_inf <= 2^(e-1)
    let bundle_dim = (DIGIT_L as f64) * n_z;
    let t_bundle = op_c * half * bundle_dim.sqrt();
    let sigma = (12.0 * t_bundle).ceil() as u64;
    let bound = 1.2 * sigma as f64 * bundle_dim.sqrt();
    let bound_sq = (bound * bound).ceil() as u128;
    let center_sq = (t_bundle * t_bundle).ceil() as u128;
    let beta_dig = 2.0 * bound + op_c * half * n_z.sqrt();
    // Recombined range-proved witness after one challenge clearing: honest
    // magnitude W, not the Gaussian-response magnitude.
    let beta_rec = op_c * WIT_W as f64 * n_z.sqrt();
    let beta = beta_dig.max(beta_rec).ceil() as u128;
    assert!((q as u128) > 8 * beta, "C2 (digit chain): q too small");
    let log2_beta = (beta as f64).log2();
    let k_z = ((log2_beta / 2.0) * (log2_beta / 2.0) / (log2_q * LOG2_DELTA0)).ceil() as usize;
    assert!(KAPPA * D >= k_z, "C3 (digit chain): KAPPA too small");
    // The undecomposed chain for the same witness, for the payoff print:
    let t_u = op_c * WIT_W as f64 * n_z.sqrt();
    let b_u = 1.2 * 12.0 * t_u * n_z.sqrt();
    let beta_u = (2.0 * b_u + op_c * WIT_W as f64 * n_z.sqrt()).ceil() as u128;
    DigitParams { sigma, bound_sq, center_sq, beta, beta_undecomposed: beta_u }
}

/// Balanced base-2^e digits: x = sum_j 2^(ej) d_j with d_j in
/// [-2^(e-1), 2^(e-1) - 1] (so ||d||_inf <= 2^(e-1)). Panics if L digits
/// cannot carry x.
fn digit_decompose(x: i64, e: u32, l: usize) -> Vec<i64> {
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

fn digit_split_witness(u: &[Vec<i64>], e: u32, l: usize) -> Vec<Vec<Vec<i64>>> {
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

struct DigitOpeningProof {
    t_digits: Vec<Vec<Poly>>, // [L][KAPPA] digit statements
    w: Vec<Vec<Poly>>,        // [L][KAPPA] first messages
    z: Vec<Vec<Vec<i64>>>,    // [L][N_R] integer responses
}

fn digit_statement_hash(q: u64, crs: &Crs, t: &[Poly], t_digits: &[Vec<Poly>], ctx: &[u8]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"ring-open-digit-stmt-v1");
    hasher.update(q.to_le_bytes());
    hasher.update(crs.crs_hash);
    hasher.update((DIGIT_E as u64).to_le_bytes());
    hasher.update((DIGIT_L as u64).to_le_bytes());
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    for p in t {
        for &c in p.iter() {
            hasher.update(c.to_le_bytes());
        }
    }
    for td in t_digits {
        for p in td {
            for &c in p.iter() {
                hasher.update(c.to_le_bytes());
            }
        }
    }
    hasher.finalize().into()
}

fn digit_challenge(h0: &[u8; 32], w: &[Vec<Poly>]) -> Vec<i64> {
    let mut bytes = Vec::new();
    for wj in w {
        bytes.extend_from_slice(&commits_bytes(wj));
    }
    XofReader::new("chal-dig", &[h0, &bytes]).next_challenge()
}

/// Prover for the digit-decomposed opening round. Note: takes the *claimed*
/// statement t and the witness u independently (a malicious caller may pass
/// mismatched ones; the verifier's recombination check is what catches it).
/// Returns (proof, rejection attempts, concentration restarts).
fn prove_opening_digits(
    ctx_ring: &RingCtx,
    dp: &DigitParams,
    crs: &Crs,
    t: &[Poly],
    u: &[Vec<i64>],
    ctx: &[u8],
    rng: &mut u64,
) -> (DigitOpeningProof, usize, usize) {
    let zq = &ctx_ring.zq;
    let u_dig = digit_split_witness(u, DIGIT_E, DIGIT_L);
    let t_digits: Vec<Vec<Poly>> =
        u_dig.iter().map(|uj| ring_matvec_small_g(zq, &crs.a1, KAPPA, N_R, uj)).collect();
    let h0 = digit_statement_hash(zq.q, crs, t, &t_digits, ctx);
    let mut attempts = 0usize;
    let mut restarts = 0usize;
    loop {
        attempts += 1;
        let y: Vec<Vec<Vec<i64>>> = (0..DIGIT_L)
            .map(|_| (0..N_R).map(|_| gaussian_ivec(rng, D, dp.sigma)).collect())
            .collect();
        let w: Vec<Vec<Poly>> =
            y.iter().map(|yj| ring_matvec_small_g(zq, &crs.a1, KAPPA, N_R, yj)).collect();
        let c = digit_challenge(&h0, &w);
        let v: Vec<Vec<Vec<i64>>> = u_dig
            .iter()
            .map(|uj| uj.iter().map(|un| poly_mul_small(&c, un)).collect())
            .collect();
        let flat_v: Vec<i64> = v.iter().flatten().flatten().copied().collect();
        // Concentration restart rule: the center bundle must sit inside the
        // concentration bound the parameters were sized with.
        if vec_norm_sq_i64(&flat_v) > dp.center_sq {
            restarts += 1;
            continue;
        }
        let z: Vec<Vec<Vec<i64>>> = y
            .iter()
            .zip(v.iter())
            .map(|(yj, vj)| {
                yj.iter()
                    .zip(vj.iter())
                    .map(|(yn, vn)| yn.iter().zip(vn.iter()).map(|(&a, &b)| a + b).collect())
                    .collect()
            })
            .collect();
        let flat_z: Vec<i64> = z.iter().flatten().flatten().copied().collect();
        if rejection_accept(rng, &flat_z, &flat_v, dp.sigma) {
            return (DigitOpeningProof { t_digits, w, z }, attempts, restarts);
        }
    }
}

fn verify_opening_digits(
    ctx_ring: &RingCtx,
    dp: &DigitParams,
    crs: &Crs,
    t: &[Poly],
    ctx: &[u8],
    proof: &DigitOpeningProof,
) -> bool {
    let zq = &ctx_ring.zq;
    if proof.t_digits.len() != DIGIT_L || proof.w.len() != DIGIT_L || proof.z.len() != DIGIT_L {
        return false;
    }
    for j in 0..DIGIT_L {
        if proof.t_digits[j].len() != KAPPA || proof.w[j].len() != KAPPA || proof.z[j].len() != N_R
        {
            return false;
        }
    }
    // 1. Recombination: sum_j 2^(ej) t_j = t mod q (public, exact).
    for r in 0..KAPPA {
        let mut acc = poly_zero();
        for j in 0..DIGIT_L {
            let scale = zq.to_mod(1i64 << (DIGIT_E as usize * j));
            for i in 0..D {
                acc[i] = zq.add(acc[i], zq.mul(scale, proof.t_digits[j][r][i]));
            }
        }
        if acc != t[r] {
            return false;
        }
    }
    // 2. Bundle norm (exact integers; the prototype stand-in for the exact
    //    per-digit ct-range claims of the full protocol).
    let flat: Vec<i64> = proof.z.iter().flatten().flatten().copied().collect();
    if vec_norm_sq_i64(&flat) > dp.bound_sq {
        return false;
    }
    // 3. Per-digit Sigma equations, ring mults on the split kernel.
    let h0 = digit_statement_hash(zq.q, crs, t, &proof.t_digits, ctx);
    let c = digit_challenge(&h0, &proof.w);
    let c_mod = poly_from_small_g(zq, &c);
    for j in 0..DIGIT_L {
        let lhs = ring_matvec_small_g(zq, &crs.a1, KAPPA, N_R, &proof.z[j]);
        for r in 0..KAPPA {
            let rhs = poly_add_g(zq, &proof.w[j][r], &ring_mul_split(ctx_ring, &c_mod, &proof.t_digits[j][r]));
            if lhs[r] != rhs {
                return false;
            }
        }
    }
    true
}

// ---------------------------------------------------------------------------
// Self-test.

fn assert_true(label: &str, cond: bool) {
    if cond {
        println!("  ok   {label}");
    } else {
        println!("  FAIL {label}");
        std::process::exit(1);
    }
}

fn main() {
    println!("ring_lattice: Route R arithmetic-core prototype");
    println!(
        "  R_q = Z_q[X]/(X^{D} + 1), q = {Q} = 2^31 - 19 (q mod 8 = {}), r = {SQRT_M1}",
        Q % 8
    );
    let mut rng = 0x5eed_0001u64;

    // --- 1. modulus / CRT structure -------------------------------------
    assert_true("q = 5 mod 8", Q % 8 == 5);
    assert_true("r^2 = -1 mod q", mulm(SQRT_M1, SQRT_M1) == Q - 1);
    let ls18_bound = (Q as f64).sqrt() / 2f64.sqrt();
    println!("  LS18 invertibility bound: ||y||_inf < {ls18_bound:.1} (challenge diffs <= 4)");
    assert_true("LS18 bound covers quinary differences", 4.0 < ls18_bound);

    // --- 2. ring arithmetic vs CRT --------------------------------------
    let a: Poly = (0..D).map(|_| rng_field(&mut rng)).collect();
    let b: Poly = (0..D).map(|_| rng_field(&mut rng)).collect();
    let ab = poly_mul(&a, &b);
    let (ap, am) = to_crt(&a);
    let (bp, bm) = to_crt(&b);
    let crt_prod = from_crt(&slot_mul(&ap, &bp, SQRT_M1), &slot_mul(&am, &bm, negm(SQRT_M1)));
    assert_true("negacyclic mul matches CRT-split mul", ab == crt_prod);
    let (p1, m1) = to_crt(&a);
    assert_true("CRT roundtrip", from_crt(&p1, &m1) == a);
    let ba = poly_mul(&b, &a);
    assert_true("mul commutes", ab == ba);
    let c0: Poly = (0..D).map(|_| rng_field(&mut rng)).collect();
    let left = poly_mul(&poly_add(&a, &b), &c0);
    let right = poly_add(&poly_mul(&a, &c0), &poly_mul(&b, &c0));
    assert_true("mul distributes over add", left == right);
    let left_s = poly_mul(&poly_sub(&a, &b), &c0);
    let right_s = poly_sub(&poly_mul(&a, &c0), &poly_mul(&b, &c0));
    assert_true("mul distributes over sub", left_s == right_s);

    // --- 3. challenge-difference invertibility (LS18 in practice) -------
    let mut all_invertible = true;
    let mut worst_linf = 0u64;
    for trial in 0..200 {
        let mut xr = XofReader::new("trial", &[&(trial as u64).to_le_bytes()]);
        let c1 = xr.next_challenge();
        let c2 = xr.next_challenge();
        if c1 == c2 {
            continue;
        }
        let diff: Vec<i64> = c1.iter().zip(c2.iter()).map(|(&x, &y)| x - y).collect();
        let diff_mod = poly_from_small(&diff);
        worst_linf = worst_linf.max(poly_linf(&diff_mod));
        match poly_inv(&diff_mod) {
            Some(inv) => {
                let one = poly_mul(&inv, &diff_mod);
                let mut expected = poly_zero();
                expected[0] = 1;
                if one != expected {
                    all_invertible = false;
                }
            }
            None => all_invertible = false,
        }
    }
    assert_true(
        &format!("200 challenge differences invertible (worst ||diff||_inf = {worst_linf})"),
        all_invertible && worst_linf <= 4,
    );
    // Negative control: an element that is zero in one CRT slot is a zero
    // divisor -- the structure LS18's bound protects short elements from.
    let (xp, _) = to_crt(&a);
    let zero_slot = from_crt(&xp, &vec![0u64; HALF]);
    assert_true("zero-in-one-slot element is NOT invertible", poly_inv(&zero_slot).is_none());
    assert_true(
        "  ... and its l_inf is above the LS18 bound",
        poly_linf(&zero_slot) as f64 >= ls18_bound,
    );

    // --- 4. CRT-slot elementwise products (2 slots at k = 2) ------------
    let const_slot = |v: u64| -> Slot {
        let mut s = vec![0u64; HALF];
        s[0] = v;
        s
    };
    let x_slot = from_crt(&const_slot(17), &const_slot(400_000));
    let y_slot = from_crt(&const_slot(923), &const_slot(5));
    let prod = poly_mul(&x_slot, &y_slot);
    let (pp, pm) = to_crt(&prod);
    assert_true(
        "slot-packed constants multiply slot-wise",
        pp[0] == mulm(17, 923)
            && pm[0] == mulm(400_000, 5)
            && pp[1..].iter().all(|&v| v == 0)
            && pm[1..].iter().all(|&v| v == 0),
    );

    // --- 5. parameters ----------------------------------------------------
    let sp = derive_sigma_params();
    println!(
        "  params: kappa={KAPPA} N_R={N_R} (N_Z={N_Z}) msg_r={MSG_R} sigma=2^{:.1} B^2=2^{:.1} beta=2^{:.1}",
        (sp.sigma as f64).log2(),
        (sp.bound_sq as f64).log2(),
        (sp.beta as f64).log2()
    );
    println!(
        "  soundness: |C| = 5^{D} = 2^{:.1}; knowledge error <= 2/|C| + 2*5^-{D} = 2^{:.1}; FS budget (Q+1)^2 * eps = 2^{:.1} <= 2^-128",
        128.0 * 5f64.log2(),
        1.0 - 128.0 * 5f64.log2(),
        128.0 + 1.0 - 128.0 * 5f64.log2(),
    );

    // --- 6. commitment + one full Sigma round ---------------------------
    let t_crs = Instant::now();
    let crs = expand_crs(42);
    let crs_ms = t_crs.elapsed().as_secs_f64() * 1e3;
    let x: Vec<Poly> = (0..MSG_R).map(|_| (0..D).map(|_| rng_field(&mut rng)).collect()).collect();
    let rho: Vec<Vec<i64>> = (0..N_R).map(|_| rng_ternary_poly(&mut rng)).collect();
    let t_com = Instant::now();
    let (t1, _t2) = commit(&crs, &x, &rho);
    let com_ms = t_com.elapsed().as_secs_f64() * 1e3;

    let ctx = b"route-r-prototype-manifest-digest";
    let t_prove = Instant::now();
    let (proof, attempts) = prove_opening(&sp, &crs, &t1, &rho, ctx, &mut rng);
    let prove_ms = t_prove.elapsed().as_secs_f64() * 1e3;
    let t_verify = Instant::now();
    let ok = verify_opening(&sp, &crs, &t1, ctx, &proof);
    let verify_ms = t_verify.elapsed().as_secs_f64() * 1e3;
    assert_true(&format!("valid opening proof verifies (attempts = {attempts})"), ok);

    // --- 7. negative battery --------------------------------------------
    let mut bad = OpeningProof { w: proof.w.clone(), z: proof.z.clone() };
    bad.z[0][0] += 1;
    assert_true("tampered response coordinate fails", !verify_opening(&sp, &crs, &t1, ctx, &bad));
    let mut bad_w = OpeningProof { w: proof.w.clone(), z: proof.z.clone() };
    bad_w.w[0][0] = addm(bad_w.w[0][0], 1);
    assert_true("tampered first message fails", !verify_opening(&sp, &crs, &t1, ctx, &bad_w));
    assert_true(
        "wrong context (manifest digest) fails",
        !verify_opening(&sp, &crs, &t1, b"other-ctx", &proof),
    );
    let mut t1_bad = t1.clone();
    t1_bad[0][0] = addm(t1_bad[0][0], 1);
    assert_true("wrong statement fails", !verify_opening(&sp, &crs, &t1_bad, ctx, &proof));
    // Norm overflow: add q to one integer coordinate. Every mod-q check is
    // unchanged; only the exact-integer norm check can catch it.
    let mut overflow = OpeningProof { w: proof.w.clone(), z: proof.z.clone() };
    overflow.z[0][0] += Q as i64;
    assert_true(
        "+q norm-overflow response fails (norm check only)",
        !verify_opening(&sp, &crs, &t1, ctx, &overflow),
    );

    // --- 8. extraction: 2 transcripts -> relaxed opening via LS18 -------
    // Rewind simulation: same mask y, two different challenges (the proof
    // device of 2-special soundness; rejection sampling bypassed on purpose).
    let y: Vec<Vec<i64>> = (0..N_R).map(|_| gaussian_ivec(&mut rng, D, sp.sigma)).collect();
    let mut xr = XofReader::new("rewind", &[b"c"]);
    let c1 = xr.next_challenge();
    let c2 = xr.next_challenge();
    assert!(c1 != c2);
    let z1: Vec<Vec<i64>> = y.iter().zip(rho.iter()).map(|(yi, ri)| {
        let v = poly_mul_small(&c1, ri);
        yi.iter().zip(v.iter()).map(|(&a, &b)| a + b).collect()
    }).collect();
    let z2: Vec<Vec<i64>> = y.iter().zip(rho.iter()).map(|(yi, ri)| {
        let v = poly_mul_small(&c2, ri);
        yi.iter().zip(v.iter()).map(|(&a, &b)| a + b).collect()
    }).collect();
    // A1 (z1 - z2) = (c1 - c2) t1; invert the difference and recover an
    // exact (relaxed slack cleared) opening rho* with A1 rho* = t1.
    let dz: Vec<Vec<i64>> = z1.iter().zip(z2.iter())
        .map(|(a1v, b1v)| a1v.iter().zip(b1v.iter()).map(|(&p, &m)| p - m).collect())
        .collect();
    let dc: Vec<i64> = c1.iter().zip(c2.iter()).map(|(&p, &m)| p - m).collect();
    let dc_mod = poly_from_small(&dc);
    let dc_inv = poly_inv(&dc_mod).expect("challenge difference invertible (LS18)");
    let rho_star: Vec<Poly> = dz.iter()
        .map(|zi| poly_mul(&dc_inv, &poly_from_small(zi)))
        .collect();
    let t1_star = {
        // A1 rho* with full mod-q polys: reuse small matvec by centering.
        let rho_star_small: Vec<Vec<i64>> = rho_star.iter()
            .map(|p| p.iter().map(|&c| center(c)).collect())
            .collect();
        ring_matvec_small(&crs.a1, KAPPA, &rho_star_small)
    };
    assert_true("extracted opening satisfies A1 rho* = t1", t1_star == t1);
    // From two HONEST transcripts the masks cancel (dz = (c1 - c2) rho), so
    // the LS18 inversion recovers the exact ternary rho. For adversarial
    // transcripts rho* need not be short -- extraction only yields the
    // relaxed opening (dz, dc) with ||dz|| <= 2B, and binding runs through
    // the SIS bound beta; the exact-recovery check below is the honest-case
    // sanity that the inversion algebra is right.
    let rho_mod: Vec<Poly> = rho.iter().map(|r| poly_from_small(r)).collect();
    assert_true("honest-case extraction recovers rho exactly", rho_star == rho_mod);
    println!(
        "  note: adversarial extraction yields only the relaxed opening (slack dc); binding runs through the SIS bound beta = 2^{:.1}",
        (sp.beta as f64).log2()
    );

    // --- 9. timings (approximate; machine shared with another agent) ----
    let t_mul = Instant::now();
    let reps = 2000;
    let mut acc = a.clone();
    for _ in 0..reps {
        acc = poly_mul(&acc, &b);
    }
    let mul_us = t_mul.elapsed().as_secs_f64() * 1e6 / reps as f64;
    std::hint::black_box(&acc);
    let t_smul = Instant::now();
    let mut sacc = ap.clone();
    for _ in 0..reps {
        sacc = slot_mul(&sacc, &bp, SQRT_M1);
    }
    let smul_us = t_smul.elapsed().as_secs_f64() * 1e6 / reps as f64;
    std::hint::black_box(&sacc);
    println!("  timings (approx, single-thread, naive kernels):");
    println!("    ring mul (negacyclic {D}, schoolbook)  {mul_us:8.1} us");
    println!("    slot mul (degree {HALF}, schoolbook)     {smul_us:8.1} us  (x2 per ring mul via CRT)");
    println!("    expand CRS ({KAPPA}+{MSG_R})x{N_R} ring elems      {crs_ms:8.1} ms");
    println!("    commit (x: {MSG_R} ring elems = {} slots)  {com_ms:8.1} ms", MSG_R * D);
    println!("    prove opening (r = 1, {attempts} attempt(s)) {prove_ms:8.1} ms");
    println!("    verify opening                        {verify_ms:8.1} ms");

    // =====================================================================
    // --- 10. Q3: the k = 8 split at q8 = 17 mod 32 -----------------------
    println!("\nQ3: k = 8 split, q8 = {Q8} = 2^31 - 399 (q8 mod 32 = {})", Q8 % 32);
    let zq8 = Zq::new(Q8);
    assert_true("q8 = 17 mod 32 (v2(q8-1) = 4)", Q8 % 32 == 17);
    assert_true("eta^8 = -1 mod q8 (primitive 16th root)", zq8.pow(ETA8, 8) == Q8 - 1);
    let ctx8 = ring_ctx(Q8, ETA8, 8);
    assert_true(
        "8 slot roots are the odd powers of eta (X^128 + 1 = prod X^16 - eta^odd)",
        ctx8.slot_roots.len() == 8
            && ctx8.slot_roots.iter().all(|&s| zq8.pow(s, 8) == Q8 - 1),
    );
    let ls18_8 = (Q8 as f64).powf(1.0 / 8.0) / 8f64.sqrt();
    println!(
        "  LS18 bound at k = 8: q^(1/8)/sqrt(8) = {ls18_8:.2}; quinary-diff margin {:.2}x",
        ls18_8 / 4.0
    );
    assert_true("LS18 bound covers quinary differences at k = 8", 4.0 < ls18_8);

    // k = 2 generic ctx at the legacy modulus reproduces the legacy kernel.
    let ctx2 = ring_ctx(Q, SQRT_M1, 2);
    let g_ab = ring_mul_split(&ctx2, &a, &b);
    assert_true("generic k = 2 split (at q31) matches legacy negacyclic mul", g_ab == ab);

    // Split/merge round-trip and split-mul vs schoolbook at q8.
    let mut rnd8 = 0x8888_0001u64;
    let mut all_ok = true;
    let mut roundtrip_ok = true;
    for _ in 0..25 {
        let x8: Poly = (0..D).map(|_| rng_field_g(&mut rnd8, Q8)).collect();
        let y8: Poly = (0..D).map(|_| rng_field_g(&mut rnd8, Q8)).collect();
        let mut rt = crt_split(&ctx8, &x8);
        crt_merge(&ctx8, &mut rt);
        if rt != x8 {
            roundtrip_ok = false;
        }
        if ring_mul_split(&ctx8, &x8, &y8) != poly_mul_g(&zq8, &x8, &y8) {
            all_ok = false;
        }
    }
    assert_true("8-way CRT split/merge round-trip (25 random elements)", roundtrip_ok);
    assert_true("k = 8 split mul matches negacyclic schoolbook (25 random pairs)", all_ok);

    // LS18 in practice at k = 8: challenge differences inverted through all
    // 8 degree-16 slots (ext-gcd per slot), inv * diff = 1 in R_q8.
    let mut all_inv8 = true;
    let mut worst_linf8 = 0u64;
    for trial in 0..100u64 {
        let mut xr = XofReader::new("trial8", &[&trial.to_le_bytes()]);
        let c1 = xr.next_challenge();
        let c2 = xr.next_challenge();
        if c1 == c2 {
            continue;
        }
        let diff: Vec<i64> = c1.iter().zip(c2.iter()).map(|(&x, &y)| x - y).collect();
        let diff_mod = poly_from_small_g(&zq8, &diff);
        worst_linf8 = worst_linf8.max(poly_linf_g(&zq8, &diff_mod));
        match poly_inv_g(&ctx8, &diff_mod) {
            Some(inv) => {
                let one = ring_mul_split(&ctx8, &inv, &diff_mod);
                let mut expected = poly_zero();
                expected[0] = 1;
                if one != expected {
                    all_inv8 = false;
                }
            }
            None => all_inv8 = false,
        }
    }
    assert_true(
        &format!("100 challenge differences invertible at k = 8 (worst ||diff||_inf = {worst_linf8})"),
        all_inv8 && (worst_linf8 as f64) < ls18_8,
    );
    // Negative control: zero in one of the 8 slots -> genuine zero divisor.
    let x8: Poly = (0..D).map(|_| rng_field_g(&mut rnd8, Q8)).collect();
    let mut buf8 = crt_split(&ctx8, &x8);
    for v in buf8[0..ctx8.slot_deg].iter_mut() {
        *v = 0;
    }
    let mut zero_slot8 = buf8.clone();
    crt_merge(&ctx8, &mut zero_slot8);
    assert_true(
        "zero-in-one-of-8-slots element is NOT invertible",
        poly_inv_g(&ctx8, &zero_slot8).is_none(),
    );
    assert_true(
        "  ... and its l_inf is above the k = 8 LS18 bound",
        poly_linf_g(&zq8, &zero_slot8) as f64 >= ls18_8,
    );
    // 8-slot elementwise products (the H3 Hadamard density point).
    let mk8 = |vals: [u64; 8]| -> Poly {
        let mut buf = vec![0u64; D];
        for (i, &v) in vals.iter().enumerate() {
            buf[i * ctx8.slot_deg] = v;
        }
        crt_merge(&ctx8, &mut buf);
        buf
    };
    let xs = mk8([3, 1, 4, 1, 5, 9, 2, 6]);
    let ys = mk8([2, 7, 1, 8, 2, 8, 1, 8]);
    let prod8 = ring_mul_split(&ctx8, &xs, &ys);
    let sp8 = crt_split(&ctx8, &prod8);
    let expect8: [u64; 8] = [6, 7, 4, 8, 10, 72, 2, 48];
    assert_true(
        "slot-packed constants multiply slot-wise across 8 slots",
        (0..8).all(|i| {
            sp8[i * ctx8.slot_deg] == expect8[i]
                && sp8[i * ctx8.slot_deg + 1..(i + 1) * ctx8.slot_deg].iter().all(|&v| v == 0)
        }),
    );

    // --- 11. Q3: opening-proof Sigma round end-to-end at k = 8 -----------
    let sp_8 = derive_sigma_params_g(Q8);
    println!(
        "  k = 8 Sigma round at q8: kappa={KAPPA} N_R={N_R} msg_r={MSG_R} sigma=2^{:.1} beta=2^{:.1} (C2 headroom {:.1} bits)",
        (sp_8.sigma as f64).log2(),
        (sp_8.beta as f64).log2(),
        (Q8 as f64).log2() - (8.0 * sp_8.beta as f64).log2(),
    );
    let crs8 = expand_crs_g(43, Q8);
    let rho8: Vec<Vec<i64>> = (0..N_R).map(|_| rng_ternary_poly(&mut rng)).collect();
    let t1_8 = ring_matvec_small_g(&zq8, &crs8.a1, KAPPA, N_R, &rho8);
    let ctx_bytes8 = b"route-r-k8-manifest-digest";
    let t_prove8 = Instant::now();
    let (proof8, attempts8) = prove_opening_g(&ctx8, &sp_8, &crs8, &t1_8, &rho8, ctx_bytes8, &mut rng);
    let prove8_ms = t_prove8.elapsed().as_secs_f64() * 1e3;
    let t_verify8 = Instant::now();
    let ok8 = verify_opening_g(&ctx8, &sp_8, &crs8, &t1_8, ctx_bytes8, &proof8);
    let verify8_ms = t_verify8.elapsed().as_secs_f64() * 1e3;
    assert_true(&format!("k = 8 valid opening proof verifies (attempts = {attempts8})"), ok8);
    let mut bad8 = OpeningProof { w: proof8.w.clone(), z: proof8.z.clone() };
    bad8.z[0][0] += 1;
    assert_true(
        "k = 8 tampered response coordinate fails",
        !verify_opening_g(&ctx8, &sp_8, &crs8, &t1_8, ctx_bytes8, &bad8),
    );
    let mut bad8w = OpeningProof { w: proof8.w.clone(), z: proof8.z.clone() };
    bad8w.w[0][0] = zq8.add(bad8w.w[0][0], 1);
    assert_true(
        "k = 8 tampered first message fails",
        !verify_opening_g(&ctx8, &sp_8, &crs8, &t1_8, ctx_bytes8, &bad8w),
    );
    assert_true(
        "k = 8 wrong context fails",
        !verify_opening_g(&ctx8, &sp_8, &crs8, &t1_8, b"other-ctx", &proof8),
    );
    let mut t1_8bad = t1_8.clone();
    t1_8bad[0][0] = zq8.add(t1_8bad[0][0], 1);
    assert_true(
        "k = 8 wrong statement fails",
        !verify_opening_g(&ctx8, &sp_8, &crs8, &t1_8bad, ctx_bytes8, &proof8),
    );
    let mut overflow8 = OpeningProof { w: proof8.w.clone(), z: proof8.z.clone() };
    overflow8.z[0][0] += Q8 as i64;
    assert_true(
        "k = 8 +q norm-overflow response fails (norm check only)",
        !verify_opening_g(&ctx8, &sp_8, &crs8, &t1_8, ctx_bytes8, &overflow8),
    );
    println!("  k = 8 prove {prove8_ms:.1} ms, verify {verify8_ms:.1} ms");

    // =====================================================================
    // --- 12. Q2: digit-decomposed opening round at (k = 8, q8) -----------
    println!(
        "\nQ2: digit-decomposed opening round at (k = 8, q8), e = {DIGIT_E}, L = {DIGIT_L}, ||u||_inf <= {WIT_W}"
    );
    let dp = derive_digit_params(Q8);
    println!(
        "  digit chain: sigma=2^{:.1} beta=2^{:.1}; C2 8*beta=2^{:.1} < q8=2^31.0 (headroom {:.1} bits)",
        (dp.sigma as f64).log2(),
        (dp.beta as f64).log2(),
        (8.0 * dp.beta as f64).log2(),
        31.0 - (8.0 * dp.beta as f64).log2(),
    );
    println!(
        "  undecomposed chain for the same witness: beta=2^{:.1}, needs q > 2^{:.1} -- does NOT fit q31",
        (dp.beta_undecomposed as f64).log2(),
        (8.0 * dp.beta_undecomposed as f64).log2(),
    );
    assert_true(
        "undecomposed combination witness violates C2 at q8 (the Q2 premise)",
        (Q8 as u128) <= 8 * dp.beta_undecomposed,
    );
    // Digit split/recombine sanity across the full witness range.
    let mut digit_ok = true;
    for x in (-WIT_W..=WIT_W).step_by(7) {
        let digs = digit_decompose(x, DIGIT_E, DIGIT_L);
        let rec: i64 = digs.iter().enumerate().map(|(j, &d)| d << (DIGIT_E as usize * j)).sum();
        if rec != x || digs.iter().any(|&d| d.abs() > 1 << (DIGIT_E - 1)) {
            digit_ok = false;
        }
    }
    assert_true("balanced digit decompose/recombine round-trip on [-W, W]", digit_ok);

    // Combination-magnitude witness and its statement.
    let u_wide: Vec<Vec<i64>> = (0..N_R)
        .map(|_| (0..D).map(|_| (splitmix64(&mut rng) % (2 * WIT_W as u64 + 1)) as i64 - WIT_W).collect())
        .collect();
    let t_wide = ring_matvec_small_g(&zq8, &crs8.a1, KAPPA, N_R, &u_wide);
    let ctx_bytes_d = b"route-r-q2-digit-manifest";
    let t_dprove = Instant::now();
    let (dproof, dattempts, drestarts) =
        prove_opening_digits(&ctx8, &dp, &crs8, &t_wide, &u_wide, ctx_bytes_d, &mut rng);
    let dprove_ms = t_dprove.elapsed().as_secs_f64() * 1e3;
    let t_dverify = Instant::now();
    let dok = verify_opening_digits(&ctx8, &dp, &crs8, &t_wide, ctx_bytes_d, &dproof);
    let dverify_ms = t_dverify.elapsed().as_secs_f64() * 1e3;
    assert_true(
        &format!("digit opening proof verifies (attempts = {dattempts}, restarts = {drestarts})"),
        dok,
    );

    // Tamper battery.
    // (a) wrong digit: one coordinate of one digit response.
    let mut bad_d = DigitOpeningProof {
        t_digits: dproof.t_digits.clone(),
        w: dproof.w.clone(),
        z: dproof.z.clone(),
    };
    bad_d.z[1][0][0] += 1;
    assert_true(
        "wrong digit (tampered digit response) fails",
        !verify_opening_digits(&ctx8, &dp, &crs8, &t_wide, ctx_bytes_d, &bad_d),
    );
    // (b) digit out of range: a malicious decomposition that still
    // recombines to u (digit 0 shifted by 2^17, digit 1 compensating by
    // -2^13) but whose digits violate ||.||_inf <= 2^(e-1). Sigma equations
    // and recombination both hold; only the norm/range layer can catch it.
    // (Deterministic for this seed; the full protocol replaces the norm
    // stand-in with exact ct-range claims.)
    {
        let shift = 1i64 << 17;
        let mut u_dig = digit_split_witness(&u_wide, DIGIT_E, DIGIT_L);
        for n in 0..N_R {
            for i in 0..D {
                u_dig[0][n][i] += shift;
                u_dig[1][n][i] -= shift >> DIGIT_E;
            }
        }
        let t_digits: Vec<Vec<Poly>> = u_dig
            .iter()
            .map(|uj| ring_matvec_small_g(&zq8, &crs8.a1, KAPPA, N_R, uj))
            .collect();
        let h0 = digit_statement_hash(Q8, &crs8, &t_wide, &t_digits, ctx_bytes_d);
        let y: Vec<Vec<Vec<i64>>> = (0..DIGIT_L)
            .map(|_| (0..N_R).map(|_| gaussian_ivec(&mut rng, D, dp.sigma)).collect())
            .collect();
        let w: Vec<Vec<Poly>> = y
            .iter()
            .map(|yj| ring_matvec_small_g(&zq8, &crs8.a1, KAPPA, N_R, yj))
            .collect();
        let c = digit_challenge(&h0, &w);
        let z: Vec<Vec<Vec<i64>>> = y
            .iter()
            .zip(u_dig.iter())
            .map(|(yj, uj)| {
                yj.iter()
                    .zip(uj.iter())
                    .map(|(yn, un)| {
                        let v = poly_mul_small(&c, un);
                        yn.iter().zip(v.iter()).map(|(&a, &b)| a + b).collect()
                    })
                    .collect()
            })
            .collect();
        let cheat = DigitOpeningProof { t_digits, w, z };
        assert_true(
            "digit out of range (recombining but oversized digits) fails",
            !verify_opening_digits(&ctx8, &dp, &crs8, &t_wide, ctx_bytes_d, &cheat),
        );
    }
    // (c) recombination mismatch: honest digit rounds on a DIFFERENT
    // witness, claimed against t_wide. Every Sigma equation and the norm
    // check pass; only the recombination check catches it.
    {
        let u_other: Vec<Vec<i64>> = (0..N_R)
            .map(|_| {
                (0..D).map(|_| (splitmix64(&mut rng) % (2 * WIT_W as u64 + 1)) as i64 - WIT_W).collect()
            })
            .collect();
        let (cheat, _, _) =
            prove_opening_digits(&ctx8, &dp, &crs8, &t_wide, &u_other, ctx_bytes_d, &mut rng);
        assert_true(
            "recombination mismatch (digits of a different witness) fails",
            !verify_opening_digits(&ctx8, &dp, &crs8, &t_wide, ctx_bytes_d, &cheat),
        );
    }
    // (d) context binding and (e) +q overflow, as in the other rounds.
    assert_true(
        "digit round wrong context fails",
        !verify_opening_digits(&ctx8, &dp, &crs8, &t_wide, b"other-ctx", &dproof),
    );
    let mut over_d = DigitOpeningProof {
        t_digits: dproof.t_digits.clone(),
        w: dproof.w.clone(),
        z: dproof.z.clone(),
    };
    over_d.z[0][0][0] += Q8 as i64;
    assert_true(
        "digit round +q norm-overflow fails (norm check only)",
        !verify_opening_digits(&ctx8, &dp, &crs8, &t_wide, ctx_bytes_d, &over_d),
    );
    let dig_kb = (DIGIT_L * KAPPA * D * 2 * 31) as f64 / 8.0 / 1024.0
        + (DIGIT_L * N_Z) as f64 * ((dp.sigma as f64).log2() + 4.0) / 8.0 / 1024.0;
    println!(
        "  digit prove {dprove_ms:.1} ms, verify {dverify_ms:.1} ms, proof ~{dig_kb:.1} KB (L = {DIGIT_L} digit statements + responses)"
    );

    println!("ring_lattice self-test ok");
}

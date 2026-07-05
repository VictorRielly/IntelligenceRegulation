//! Native benchmark backend for the lattice matrix-multiplication proofs.
//!
//! Route-Z transcription of protocols Pi1 (public A, hidden B/C) and Pi2
//! (all matrices hidden) from the companion lattice report, sized for a
//! 128-bit security target by the report's constraint system (C1-C4):
//!
//!   Pi1: b = 8,  r = 37  (r (b-1) >= 256)
//!   Pi2: b = 6,  r = 64  (r (b-2) >= 256)
//!   q   = 2^61 - 1 (Mersenne prime; single-limb arithmetic, satisfies
//!         q > 8 beta and q > 2^{3b} for the sizes benchmarked here)
//!   k   from C3 (core-SVP binding proxy, delta0 = 1.0037)
//!   N   from C4 (knapsack-LWE hiding, Kyber-normalized first cut)
//!
//! Fiat-Shamir uses SHA-256 in counter mode as the XOF, with transcript
//! compression (the verifier recomputes first messages and checks the
//! challenge hash). Benchmark-only shortcuts, called out inline: the
//! Gaussian window sampler and the rejection accept decision use f64
//! (production needs >= 128-bit fixed point per report Section 12), and
//! prover secrets come from a seeded splitmix64 stream for reproducible
//! timing (production needs an OS entropy source).

use rayon::prelude::*;
use sha2::{Digest, Sha256};
use std::env;
use std::time::Instant;

const Q: u64 = (1 << 61) - 1; // Mersenne prime 2^61 - 1
const LOG2_Q: f64 = 61.0;
const LOG2_DELTA0: f64 = 0.005326; // log2(1.0037)
const HIDING_DIM: usize = 4005; // ceil(768 * 61 / 11.7), constraint C4

#[inline]
fn addm(a: u64, b: u64) -> u64 {
    let c = a + b;
    if c >= Q { c - Q } else { c }
}

#[inline]
fn subm(a: u64, b: u64) -> u64 {
    if a >= b { a - b } else { Q - (b - a) }
}

#[inline]
fn reduce122(x: u128) -> u64 {
    // x < 2^122: fold high bits for the Mersenne modulus.
    let lo = (x & Q as u128) as u64;
    let hi = (x >> 61) as u64;
    let mut s = lo + hi;
    if s >= Q {
        s -= Q;
    }
    if s >= Q {
        s -= Q;
    }
    s
}

#[inline]
fn mulm(a: u64, b: u64) -> u64 {
    reduce122(a as u128 * b as u128)
}

#[inline]
fn reduce_i128(x: i128) -> u64 {
    let m = (x % Q as i128) as i64;
    if m < 0 { (m + Q as i64) as u64 } else { m as u64 }
}

fn splitmix64(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9e37_79b9_7f4a_7c15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
    z ^ (z >> 31)
}

fn rng_field(rng: &mut u64) -> u64 {
    loop {
        let candidate = splitmix64(rng) & Q;
        if candidate < Q {
            return candidate;
        }
    }
}

fn rng_small(rng: &mut u64, max_entry: u64) -> u64 {
    splitmix64(rng) % max_entry
}

fn rng_ternary(rng: &mut u64, len: usize) -> Vec<i8> {
    let mut out = Vec::with_capacity(len);
    while out.len() < len {
        let word = splitmix64(rng);
        for shift in (0..64).step_by(2) {
            let trit = ((word >> shift) & 3) as i8;
            if trit != 3 {
                out.push(trit - 1);
                if out.len() == len {
                    break;
                }
            }
        }
    }
    out
}

// ---------------------------------------------------------------------------
// SHA-256 counter-mode XOF for CRS expansion and Fiat-Shamir challenges.

struct XofReader {
    prefix: Vec<u8>,
    counter: u64,
    buffer: [u8; 32],
    pos: usize,
}

impl XofReader {
    fn new(domain: &str, items: &[&[u8]]) -> Self {
        let mut hasher = Sha256::new();
        hasher.update(b"lattice-matmul-v1");
        hasher.update((domain.len() as u64).to_le_bytes());
        hasher.update(domain.as_bytes());
        for item in items {
            hasher.update((item.len() as u64).to_le_bytes());
            hasher.update(item);
        }
        let prefix = hasher.finalize().to_vec();
        let mut reader = XofReader {
            prefix,
            counter: 0,
            buffer: [0u8; 32],
            pos: 32,
        };
        reader.refill();
        reader
    }

    fn refill(&mut self) {
        let mut hasher = Sha256::new();
        hasher.update(&self.prefix);
        hasher.update(self.counter.to_le_bytes());
        self.buffer.copy_from_slice(&hasher.finalize());
        self.counter += 1;
        self.pos = 0;
    }

    fn next_u64(&mut self) -> u64 {
        if self.pos + 8 > 32 {
            self.refill();
        }
        let word = u64::from_le_bytes(
            self.buffer[self.pos..self.pos + 8].try_into().unwrap(),
        );
        self.pos += 8;
        word
    }

    fn next_field(&mut self) -> u64 {
        loop {
            let candidate = self.next_u64() & Q;
            if candidate < Q {
                return candidate;
            }
        }
    }

    fn next_sb(&mut self, b: u32) -> u64 {
        self.next_u64() & ((1u64 << b) - 1)
    }
}

fn hash_words(domain: &str, items: &[&[u8]]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"lattice-matmul-v1");
    hasher.update((domain.len() as u64).to_le_bytes());
    hasher.update(domain.as_bytes());
    for item in items {
        hasher.update((item.len() as u64).to_le_bytes());
        hasher.update(item);
    }
    hasher.finalize().into()
}

fn words_bytes(words: &[u64]) -> Vec<u8> {
    let mut out = Vec::with_capacity(words.len() * 8);
    for w in words {
        out.extend_from_slice(&w.to_le_bytes());
    }
    out
}

// ---------------------------------------------------------------------------
// Parameters (report Part II, Section 11).

#[derive(Clone, Copy, Debug)]
enum Protocol {
    Pi1,
    Pi2,
}

#[derive(Clone, Debug)]
struct Params {
    proto: Protocol,
    n: usize,
    m: usize,
    b: u32,
    r: usize,
    k: usize,
    big_n: usize,
    sigma: u64,
    bound_sq: u128,
    beta: u128,
}

fn isqrt_ceil(v: u128) -> u128 {
    if v == 0 {
        return 0;
    }
    let mut x = (v as f64).sqrt() as u128;
    while x * x > v {
        x -= 1;
    }
    while (x + 1) * (x + 1) <= v {
        x += 1;
    }
    if x * x == v { x } else { x + 1 }
}

fn derive_params(proto: Protocol, n: usize, m: usize) -> Params {
    let (b, r) = match proto {
        Protocol::Pi1 => (8u32, 37usize), // r (b-1) = 259 >= 256
        Protocol::Pi2 => (6u32, 64usize), // r (b-2) = 256
    };
    let two_b = 1u128 << b;
    let mut k = 1536usize; // seed guess, refined by C3 below
    let mut big_n = ((k + n + HIDING_DIM + 63) / 64) * 64;
    let mut sigma = 0u64;
    let mut bound_sq = 0u128;
    let mut beta = 0u128;
    for _ in 0..4 {
        let b0 = isqrt_ceil(big_n as u128);
        let (t_sq, dim) = match proto {
            Protocol::Pi1 => {
                let b_rho = m as u128 * two_b * b0;
                (2 * (two_b * b_rho) * (two_b * b_rho), 2 * big_n)
            }
            Protocol::Pi2 => {
                let b_rho_s = n as u128 * two_b * b0;
                let b_rho_v = m as u128 * two_b * b0;
                let last = two_b * b0 + two_b * two_b * b_rho_v;
                (
                    two_b * two_b * (b_rho_s * b_rho_s + b_rho_v * b_rho_v)
                        + last * last,
                    3 * big_n,
                )
            }
        };
        sigma = (12 * isqrt_ceil(t_sq)) as u64;
        bound_sq = 36 * (sigma as u128) * (sigma as u128) * dim as u128 / 25;
        let bound = isqrt_ceil(bound_sq);
        beta = match proto {
            Protocol::Pi1 => {
                let b_rho = m as u128 * two_b * isqrt_ceil(big_n as u128);
                2 * bound + two_b * b_rho
            }
            Protocol::Pi2 => {
                let b0 = isqrt_ceil(big_n as u128);
                let b_rho_s = n as u128 * two_b * b0;
                let b_rho_v = m as u128 * two_b * b0;
                std::cmp::max(
                    2 * bound + two_b * b_rho_s,
                    3 * two_b * bound + two_b * two_b * two_b * b_rho_v,
                )
            }
        };
        // C3: 2 sqrt(k log2 q log2 delta0) >= log2 beta.
        let log2_beta = (beta as f64).log2();
        k = ((log2_beta / 2.0) * (log2_beta / 2.0) / (LOG2_Q * LOG2_DELTA0))
            .ceil() as usize;
        // C4: N - (k + n) >= hiding dimension.
        big_n = ((k + n + HIDING_DIM + 63) / 64) * 64;
    }
    // C0/C2 sanity for the modulus shared by both protocols.
    assert!(Q as u128 > 8 * beta, "q too small for beta at this shape");
    assert!(Q as u128 > 1u128 << (3 * b), "q too small for 2^(3b)");
    Params {
        proto,
        n,
        m,
        b,
        r,
        k,
        big_n,
        sigma,
        bound_sq,
        beta,
    }
}

fn proof_bytes(params: &Params) -> usize {
    let sigma_bits = 64 - params.sigma.leading_zeros() as usize + 4;
    let bits_per_rep = match params.proto {
        Protocol::Pi1 => {
            params.b as usize
                + params.n * 61
                + 2 * params.big_n * sigma_bits
        }
        Protocol::Pi2 => {
            params.b as usize
                + (params.k + 1 + 2 * params.n) * 61
                + 3 * params.big_n * sigma_bits
        }
    };
    params.r * bits_per_rep / 8
}

// ---------------------------------------------------------------------------
// CRS and commitments.

struct Crs {
    g1: Vec<u64>, // k x N row-major
    g2: Vec<u64>, // n x N row-major
    crs_hash: [u8; 32],
}

fn expand_crs(params: &Params, seed: u64) -> Crs {
    let expand = |tag: &str, rows: usize| -> Vec<u64> {
        let mut out = vec![0u64; rows * params.big_n];
        out.par_chunks_mut(params.big_n)
            .enumerate()
            .for_each(|(row, chunk)| {
                let mut reader = XofReader::new(
                    "crs-row",
                    &[
                        &seed.to_le_bytes(),
                        tag.as_bytes(),
                        &(row as u64).to_le_bytes(),
                    ],
                );
                for value in chunk.iter_mut() {
                    *value = reader.next_field();
                }
            });
        out
    };
    let g1 = expand("G1", params.k);
    let g2 = expand("G2", params.n);
    let crs_hash = hash_words(
        "crs",
        &[
            &seed.to_le_bytes(),
            &Q.to_le_bytes(),
            &(params.n as u64).to_le_bytes(),
            &(params.m as u64).to_le_bytes(),
            &(params.k as u64).to_le_bytes(),
            &(params.big_n as u64).to_le_bytes(),
            &(params.b as u64).to_le_bytes(),
            &(params.r as u64).to_le_bytes(),
        ],
    );
    Crs { g1, g2, crs_hash }
}

/// Blocked multi-vector version of `matvec_signed`: G times a set of
/// signed vectors, streaming G from memory once per MATMAT_BLOCK vectors
/// instead of once per vector. The kernels are memory-bandwidth bound, so
/// reusing each row of G against an L2-resident block of vectors is the
/// main throughput lever (report Section 13's GEMM shape).
const MATMAT_BLOCK: usize = 8;

fn matmat_signed(g: &[u64], rows: usize, width: usize, vs: &[Vec<i64>]) -> Vec<Vec<u64>> {
    let mut out: Vec<Vec<u64>> = vec![Vec::new(); vs.len()];
    for (block_index, block) in vs.chunks(MATMAT_BLOCK).enumerate() {
        let per_row: Vec<Vec<u64>> = (0..rows)
            .into_par_iter()
            .map(|row| {
                let grow = &g[row * width..(row + 1) * width];
                block
                    .iter()
                    .map(|v| {
                        let mut acc: i128 = 0;
                        for t in 0..width {
                            acc += grow[t] as i128 * v[t] as i128;
                        }
                        reduce_i128(acc)
                    })
                    .collect()
            })
            .collect();
        for (j, slot) in out[block_index * MATMAT_BLOCK..]
            .iter_mut()
            .take(block.len())
            .enumerate()
        {
            *slot = (0..rows).map(|row| per_row[row][j]).collect();
        }
    }
    out
}

/// Commit every column of a matrix in blocked multi-vector passes.
fn commit_columns_fast(
    params: &Params,
    crs: &Crs,
    messages: &[Vec<u64>],
    rhos: &[Vec<i8>],
) -> Vec<Vec<u64>> {
    const WIDEN_CHUNK: usize = 64;
    let mut out = Vec::with_capacity(messages.len());
    for (msg_chunk, rho_chunk) in messages
        .chunks(WIDEN_CHUNK)
        .zip(rhos.chunks(WIDEN_CHUNK))
    {
        let widened: Vec<Vec<i64>> = rho_chunk
            .iter()
            .map(|rho| rho.iter().map(|&x| x as i64).collect())
            .collect();
        let t1s = matmat_signed(&crs.g1, params.k, params.big_n, &widened);
        let t2s = matmat_signed(&crs.g2, params.n, params.big_n, &widened);
        for ((msg, mut t1), t2) in msg_chunk.iter().zip(t1s).zip(t2s) {
            t1.extend(t2.iter().zip(msg.iter()).map(|(&g, &x)| addm(g, x)));
            out.push(t1);
        }
    }
    out
}

/// Serial mod-q matvec, for use inside repetition-parallel contexts.
fn matvec_mod_serial(a: &[u64], rows: usize, width: usize, v: &[u64]) -> Vec<u64> {
    (0..rows)
        .map(|row| {
            let base = row * width;
            let mut acc: u128 = 0;
            for t in 0..width {
                acc += mulm(a[base + t], v[t]) as u128;
            }
            (acc % Q as u128) as u64
        })
        .collect()
}

/// Deterministic per-repetition rng stream so waves can sample in parallel.
fn mix_seed(seed: u64, ell: u64) -> u64 {
    let mut s = seed ^ 0x9e37_79b9_7f4a_7c15u64.wrapping_mul(ell + 1);
    splitmix64(&mut s)
}

// ---------------------------------------------------------------------------
// Gaussian and rejection sampling. f64 is a benchmark-only shortcut; the
// report requires >= 128-bit fixed point for the exp evaluations.

fn gaussian_vec(rng: &mut u64, len: usize, sigma: u64) -> Vec<i64> {
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

fn rejection_accept(rng: &mut u64, response: &[i64], center: &[i64], sigma: u64) -> bool {
    let mut norm_c: i128 = 0;
    let mut dot: i128 = 0;
    for (&z, &c) in response.iter().zip(center.iter()) {
        norm_c += c as i128 * c as i128;
        dot += z as i128 * c as i128;
    }
    let exponent = (norm_c - 2 * dot) as f64
        / (2.0 * sigma as f64 * sigma as f64);
    let log_m = 1.0 + 1.0 / 288.0; // alpha = 12
    let threshold = (exponent - log_m).exp();
    if threshold >= 1.0 {
        return true;
    }
    let u = (splitmix64(rng) >> 11) as f64 / (1u64 << 53) as f64;
    u < threshold
}

fn norm_sq(values: &[i64]) -> u128 {
    values
        .iter()
        .map(|&v| (v as i128 * v as i128) as u128)
        .sum()
}

// ---------------------------------------------------------------------------
// Shared helpers for both protocols.

/// b_vec = sum_j coeff_j * columns[j] mod q.
fn combine_columns(columns: &[Vec<u64>], coeffs: &[u64]) -> Vec<u64> {
    let n = columns[0].len();
    let mut out = vec![0u64; n];
    for (col, &coeff) in columns.iter().zip(coeffs.iter()) {
        for i in 0..n {
            out[i] = addm(out[i], mulm(coeff, col[i]));
        }
    }
    out
}

/// rho_v = sum_j coeff_j * rho_j over Z (ternary randomness, small coeffs).
fn combine_ternary(rhos: &[Vec<i8>], coeffs: &[u64]) -> Vec<i64> {
    let len = rhos[0].len();
    let mut out = vec![0i64; len];
    for (rho, &coeff) in rhos.iter().zip(coeffs.iter()) {
        let c = coeff as i64;
        for i in 0..len {
            out[i] += c * rho[i] as i64;
        }
    }
    out
}

fn combine_commit(commits: &[Vec<u64>], coeffs: &[u64]) -> Vec<u64> {
    let len = commits[0].len();
    let mut out = vec![0u64; len];
    for (commit, &coeff) in commits.iter().zip(coeffs.iter()) {
        for i in 0..len {
            out[i] = addm(out[i], mulm(coeff, commit[i]));
        }
    }
    out
}

fn axpy_mod(dst: &mut [u64], src: &[u64], scalar: u64) {
    for (d, &s) in dst.iter_mut().zip(src.iter()) {
        *d = addm(*d, mulm(scalar, s));
    }
}

fn statement_hash(crs: &Crs, tag: &str, groups: &[&[Vec<u64>]]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"lattice-matmul-v1");
    hasher.update(tag.as_bytes());
    hasher.update(crs.crs_hash);
    for group in groups {
        for commitment in group.iter() {
            hasher.update(words_bytes(commitment));
        }
    }
    hasher.finalize().into()
}

// ---------------------------------------------------------------------------
// Pi1: public A, hidden B and C.

struct Pi1Rep {
    gamma: u64,
    z: Vec<u64>,
    zeta: Vec<i64>,
    xi: Vec<i64>,
}

#[allow(clippy::too_many_arguments)]
fn prove_pi1(
    params: &Params,
    crs: &Crs,
    a: &[u64], // n x n row-major, public
    b_cols: &[Vec<u64>],
    rho_b: &[Vec<i8>],
    tau_c: &[Vec<i8>],
    tb: &[Vec<u64>],
    tc: &[Vec<u64>],
    rng: &mut u64,
) -> Vec<Pi1Rep> {
    let n = params.n;
    let big_n = params.big_n;
    let h0 = statement_hash(crs, "stmt-pi1", &[tb, tc]);
    let base_rng = splitmix64(rng);
    // Per-repetition state, built in parallel; each repetition owns a
    // deterministic rng stream so wave sampling can also run in parallel.
    struct RepState {
        b_vec: Vec<u64>,
        rho_v: Vec<i64>,
        tau_v: Vec<i64>,
        rng: u64,
    }
    let mut states: Vec<RepState> = (0..params.r)
        .into_par_iter()
        .map(|ell| {
            let mut reader = XofReader::new("v", &[&h0, &(ell as u64).to_le_bytes()]);
            let v: Vec<u64> = (0..params.m).map(|_| reader.next_sb(params.b)).collect();
            RepState {
                b_vec: combine_columns(b_cols, &v),
                rho_v: combine_ternary(rho_b, &v),
                tau_v: combine_ternary(tau_c, &v),
                rng: mix_seed(base_rng, ell as u64),
            }
        })
        .collect();
    let mut done: Vec<Option<Pi1Rep>> = (0..params.r).map(|_| None).collect();
    let mut pending: Vec<usize> = (0..params.r).collect();
    // Wave scheduling: every pending repetition's mask commitments are
    // computed in one blocked pass over G1/G2 per wave; rejected
    // repetitions carry into the next wave with entirely fresh masks.
    while !pending.is_empty() {
        let sampled: Vec<(Vec<u64>, Vec<i64>, Vec<i64>, u64)> = pending
            .par_iter()
            .map(|&i| {
                let mut r = states[i].rng;
                let eps: Vec<u64> = (0..n).map(|_| rng_field(&mut r)).collect();
                let noise = gaussian_vec(&mut r, 2 * big_n, params.sigma);
                let eta = noise[..big_n].to_vec();
                let mu = noise[big_n..].to_vec();
                (eps, eta, mu, r)
            })
            .collect();
        let mut eps_all = Vec::with_capacity(pending.len());
        let mut noise_all = Vec::with_capacity(2 * pending.len());
        for (idx, (eps, eta, mu, new_rng)) in sampled.into_iter().enumerate() {
            states[pending[idx]].rng = new_rng;
            eps_all.push(eps);
            noise_all.push(eta);
            noise_all.push(mu);
        }
        let g1_res = matmat_signed(&crs.g1, params.k, big_n, &noise_all);
        let g2_res = matmat_signed(&crs.g2, n, big_n, &noise_all);
        let a_eps_all: Vec<Vec<u64>> = eps_all
            .par_iter()
            .map(|eps| matvec_mod_serial(a, n, n, eps))
            .collect();
        let mut next_pending = Vec::new();
        for (idx, &i) in pending.iter().enumerate() {
            let ell = i;
            let eta = &noise_all[2 * idx];
            let mu = &noise_all[2 * idx + 1];
            let eps = &eps_all[idx];
            let mut w = g1_res[2 * idx].clone();
            w.extend(
                g2_res[2 * idx]
                    .iter()
                    .zip(eps.iter())
                    .map(|(&g, &x)| addm(g, x)),
            );
            let mut u = g1_res[2 * idx + 1].clone();
            u.extend(
                g2_res[2 * idx + 1]
                    .iter()
                    .zip(a_eps_all[idx].iter())
                    .map(|(&g, &x)| addm(g, x)),
            );
            let mut gr = XofReader::new(
                "gamma",
                &[
                    &h0,
                    &(ell as u64).to_le_bytes(),
                    &words_bytes(&w),
                    &words_bytes(&u),
                ],
            );
            let gamma = gr.next_sb(params.b);
            let st = &mut states[i];
            let g = gamma as i64;
            let z: Vec<u64> = (0..n)
                .map(|j| addm(eps[j], mulm(gamma, st.b_vec[j])))
                .collect();
            let zeta: Vec<i64> = (0..big_n).map(|j| eta[j] + g * st.rho_v[j]).collect();
            let xi: Vec<i64> = (0..big_n).map(|j| mu[j] + g * st.tau_v[j]).collect();
            let mut response = zeta.clone();
            response.extend_from_slice(&xi);
            let mut center: Vec<i64> = st.rho_v.iter().map(|&x| g * x).collect();
            center.extend(st.tau_v.iter().map(|&x| g * x));
            if rejection_accept(&mut st.rng, &response, &center, params.sigma) {
                done[i] = Some(Pi1Rep { gamma, z, zeta, xi });
            } else {
                next_pending.push(i);
            }
        }
        pending = next_pending;
    }
    done.into_iter().map(Option::unwrap).collect()
}

fn verify_pi1(
    params: &Params,
    crs: &Crs,
    a: &[u64],
    tb: &[Vec<u64>],
    tc: &[Vec<u64>],
    proof: &[Pi1Rep],
) -> bool {
    if proof.len() != params.r {
        return false;
    }
    let n = params.n;
    let big_n = params.big_n;
    let h0 = statement_hash(crs, "stmt-pi1", &[tb, tc]);
    for rep in proof {
        if rep.gamma >= (1 << params.b) {
            return false;
        }
        if rep.z.len() != n || rep.z.iter().any(|&z| z >= Q) {
            return false;
        }
        if rep.zeta.len() != big_n || rep.xi.len() != big_n {
            return false;
        }
        // Sum of squares separates across the concatenation.
        if norm_sq(&rep.zeta) + norm_sq(&rep.xi) > params.bound_sq {
            return false;
        }
    }
    // All repetitions' response matvecs in one blocked pass per G matrix.
    let vecs: Vec<Vec<i64>> = proof
        .iter()
        .flat_map(|rep| [rep.zeta.clone(), rep.xi.clone()])
        .collect();
    let g1_res = matmat_signed(&crs.g1, params.k, big_n, &vecs);
    let g2_res = matmat_signed(&crs.g2, n, big_n, &vecs);
    proof.par_iter().enumerate().all(|(ell, rep)| {
        let mut reader = XofReader::new("v", &[&h0, &(ell as u64).to_le_bytes()]);
        let v: Vec<u64> = (0..params.m).map(|_| reader.next_sb(params.b)).collect();
        let t_b = combine_commit(tb, &v);
        let t_c = combine_commit(tc, &v);
        // w = (G1 zeta, G2 zeta + z) - gamma T_b
        let mut w = g1_res[2 * ell].clone();
        w.extend(
            g2_res[2 * ell]
                .iter()
                .zip(rep.z.iter())
                .map(|(&g, &z)| addm(g, z)),
        );
        for i in 0..w.len() {
            w[i] = subm(w[i], mulm(rep.gamma, t_b[i]));
        }
        // u = (G1 xi, G2 xi + A z) - gamma T_c
        let az = matvec_mod_serial(a, n, n, &rep.z);
        let mut u = g1_res[2 * ell + 1].clone();
        u.extend(
            g2_res[2 * ell + 1]
                .iter()
                .zip(az.iter())
                .map(|(&g, &z)| addm(g, z)),
        );
        for i in 0..u.len() {
            u[i] = subm(u[i], mulm(rep.gamma, t_c[i]));
        }
        let mut gr = XofReader::new(
            "gamma",
            &[
                &h0,
                &(ell as u64).to_le_bytes(),
                &words_bytes(&w),
                &words_bytes(&u),
            ],
        );
        rep.gamma == gr.next_sb(params.b)
    })
}

// ---------------------------------------------------------------------------
// Pi2: all three matrices hidden (A committed by rows).

struct Pi2Rep {
    gamma: u64,
    t1: Vec<u64>, // k + 1 words (scalar-key commitment to g1)
    z_a: Vec<u64>,
    z_b: Vec<u64>,
    zeta_a: Vec<i64>,
    zeta_b: Vec<i64>,
    zeta_q: Vec<i64>,
}

fn scalar_key(params: &Params, crs: &Crs, s: &[u64]) -> Vec<u64> {
    // g_s^T = s^T G2 (length N). Serial: callers run it inside
    // repetition-parallel maps.
    let mut out = vec![0u128; params.big_n];
    for i in 0..params.n {
        let si = s[i];
        let row = &crs.g2[i * params.big_n..(i + 1) * params.big_n];
        for (o, &g) in out.iter_mut().zip(row.iter()) {
            *o += mulm(si, g) as u128;
        }
    }
    out.into_iter().map(|acc| (acc % Q as u128) as u64).collect()
}

fn dot_mod(a: &[u64], b: &[u64]) -> u64 {
    let mut acc: u128 = 0;
    for (&x, &y) in a.iter().zip(b.iter()) {
        acc += mulm(x, y) as u128;
    }
    (acc % Q as u128) as u64
}

fn dot_signed(a: &[u64], b: &[i64]) -> u64 {
    let mut acc: i128 = 0;
    for (&x, &y) in a.iter().zip(b.iter()) {
        acc += x as i128 * y as i128;
    }
    reduce_i128(acc)
}

#[allow(clippy::too_many_arguments)]
fn prove_pi2(
    params: &Params,
    crs: &Crs,
    a_rows: &[Vec<u64>],
    rho_a: &[Vec<i8>],
    b_cols: &[Vec<u64>],
    rho_b: &[Vec<i8>],
    tau_c: &[Vec<i8>],
    ta: &[Vec<u64>],
    tb: &[Vec<u64>],
    tc: &[Vec<u64>],
    rng: &mut u64,
) -> Vec<Pi2Rep> {
    let n = params.n;
    let big_n = params.big_n;
    let h0 = statement_hash(crs, "stmt-pi2", &[ta, tb, tc]);
    let base_rng = splitmix64(rng);
    struct RepState {
        a_vec: Vec<u64>,
        b_vec: Vec<u64>,
        rho_s: Vec<i64>,
        rho_v: Vec<i64>,
        tau_v: Vec<i64>,
        g_s: Vec<u64>,
        rng: u64,
    }
    let mut states: Vec<RepState> = (0..params.r)
        .into_par_iter()
        .map(|ell| {
            let mut reader = XofReader::new("sv", &[&h0, &(ell as u64).to_le_bytes()]);
            let s: Vec<u64> = (0..n).map(|_| reader.next_sb(params.b)).collect();
            let v: Vec<u64> = (0..params.m).map(|_| reader.next_sb(params.b)).collect();
            let mut a_vec = vec![0u64; n];
            for (row, &coeff) in a_rows.iter().zip(s.iter()) {
                axpy_mod(&mut a_vec, row, coeff);
            }
            let g_s = scalar_key(params, crs, &s);
            RepState {
                a_vec,
                b_vec: combine_columns(b_cols, &v),
                rho_s: combine_ternary(rho_a, &s),
                rho_v: combine_ternary(rho_b, &v),
                tau_v: combine_ternary(tau_c, &v),
                g_s,
                rng: mix_seed(base_rng, ell as u64),
            }
        })
        .collect();
    let mut done: Vec<Option<Pi2Rep>> = (0..params.r).map(|_| None).collect();
    let mut pending: Vec<usize> = (0..params.r).collect();
    while !pending.is_empty() {
        // Per attempt: G1 acts on [eta_a, eta_b, eta_0, eta_1] and G2 on
        // [eta_a, eta_b]; all pending repetitions share one blocked pass.
        let sampled: Vec<(Vec<u64>, Vec<u64>, Vec<i64>, Vec<i64>, Vec<i64>, Vec<i64>, u64)> =
            pending
                .par_iter()
                .map(|&i| {
                    let mut r = states[i].rng;
                    let eps_a: Vec<u64> = (0..n).map(|_| rng_field(&mut r)).collect();
                    let eps_b: Vec<u64> = (0..n).map(|_| rng_field(&mut r)).collect();
                    let eta1: Vec<i64> =
                        rng_ternary(&mut r, big_n).iter().map(|&x| x as i64).collect();
                    let noise = gaussian_vec(&mut r, 3 * big_n, params.sigma);
                    let eta_a = noise[..big_n].to_vec();
                    let eta_b = noise[big_n..2 * big_n].to_vec();
                    let eta0 = noise[2 * big_n..].to_vec();
                    (eps_a, eps_b, eta_a, eta_b, eta0, eta1, r)
                })
                .collect();
        let mut eps_all = Vec::with_capacity(pending.len());
        let mut g1_vecs = Vec::with_capacity(4 * pending.len());
        let mut g2_vecs = Vec::with_capacity(2 * pending.len());
        for (idx, (eps_a, eps_b, eta_a, eta_b, eta0, eta1, new_rng)) in
            sampled.into_iter().enumerate()
        {
            states[pending[idx]].rng = new_rng;
            g2_vecs.push(eta_a.clone());
            g2_vecs.push(eta_b.clone());
            g1_vecs.push(eta_a);
            g1_vecs.push(eta_b);
            g1_vecs.push(eta0);
            g1_vecs.push(eta1);
            eps_all.push((eps_a, eps_b));
        }
        let g1_res = matmat_signed(&crs.g1, params.k, big_n, &g1_vecs);
        let g2_res = matmat_signed(&crs.g2, n, big_n, &g2_vecs);
        let mut next_pending = Vec::new();
        for (idx, &i) in pending.iter().enumerate() {
            let ell = i;
            let (eps_a, eps_b) = &eps_all[idx];
            let eta_a = &g1_vecs[4 * idx];
            let eta_b = &g1_vecs[4 * idx + 1];
            let eta0 = &g1_vecs[4 * idx + 2];
            let eta1 = &g1_vecs[4 * idx + 3];
            let st_ro = &states[i];
            let g0 = dot_mod(eps_a, eps_b);
            let g1_scalar = addm(dot_mod(eps_a, &st_ro.b_vec), dot_mod(&st_ro.a_vec, eps_b));
            let mut w_a = g1_res[4 * idx].clone();
            w_a.extend(
                g2_res[2 * idx]
                    .iter()
                    .zip(eps_a.iter())
                    .map(|(&g, &x)| addm(g, x)),
            );
            let mut w_b = g1_res[4 * idx + 1].clone();
            w_b.extend(
                g2_res[2 * idx + 1]
                    .iter()
                    .zip(eps_b.iter())
                    .map(|(&g, &x)| addm(g, x)),
            );
            let mut t0 = g1_res[4 * idx + 2].clone();
            t0.push(addm(dot_signed(&st_ro.g_s, eta0), g0));
            let mut t1 = g1_res[4 * idx + 3].clone();
            t1.push(addm(dot_signed(&st_ro.g_s, eta1), g1_scalar));
            let mut gr = XofReader::new(
                "gamma2",
                &[
                    &h0,
                    &(ell as u64).to_le_bytes(),
                    &words_bytes(&w_a),
                    &words_bytes(&w_b),
                    &words_bytes(&t0),
                    &words_bytes(&t1),
                ],
            );
            let gamma = gr.next_sb(params.b);
            let g = gamma as i64;
            let g_sq = g * g;
            let st = &mut states[i];
            let z_a: Vec<u64> = (0..n)
                .map(|j| addm(eps_a[j], mulm(gamma, st.a_vec[j])))
                .collect();
            let z_b: Vec<u64> = (0..n)
                .map(|j| addm(eps_b[j], mulm(gamma, st.b_vec[j])))
                .collect();
            let zeta_a: Vec<i64> = (0..big_n).map(|j| eta_a[j] + g * st.rho_s[j]).collect();
            let zeta_b: Vec<i64> = (0..big_n).map(|j| eta_b[j] + g * st.rho_v[j]).collect();
            let zeta_q: Vec<i64> = (0..big_n)
                .map(|j| eta0[j] + g * eta1[j] + g_sq * st.tau_v[j])
                .collect();
            let mut response = zeta_a.clone();
            response.extend_from_slice(&zeta_b);
            response.extend_from_slice(&zeta_q);
            let mut center: Vec<i64> = st.rho_s.iter().map(|&x| g * x).collect();
            center.extend(st.rho_v.iter().map(|&x| g * x));
            center.extend((0..big_n).map(|j| g * eta1[j] + g_sq * st.tau_v[j]));
            if rejection_accept(&mut st.rng, &response, &center, params.sigma) {
                done[i] = Some(Pi2Rep {
                    gamma,
                    t1,
                    z_a,
                    z_b,
                    zeta_a,
                    zeta_b,
                    zeta_q,
                });
            } else {
                next_pending.push(i);
            }
        }
        pending = next_pending;
    }
    done.into_iter().map(Option::unwrap).collect()
}

fn verify_pi2(
    params: &Params,
    crs: &Crs,
    ta: &[Vec<u64>],
    tb: &[Vec<u64>],
    tc: &[Vec<u64>],
    proof: &[Pi2Rep],
) -> bool {
    if proof.len() != params.r {
        return false;
    }
    let n = params.n;
    let big_n = params.big_n;
    let h0 = statement_hash(crs, "stmt-pi2", &[ta, tb, tc]);
    for rep in proof {
        if rep.gamma >= (1 << params.b) {
            return false;
        }
        if rep.t1.len() != params.k + 1 || rep.t1.iter().any(|&x| x >= Q) {
            return false;
        }
        for z in [&rep.z_a, &rep.z_b] {
            if z.len() != n || z.iter().any(|&x| x >= Q) {
                return false;
            }
        }
        if rep.zeta_a.len() != big_n || rep.zeta_b.len() != big_n || rep.zeta_q.len() != big_n {
            return false;
        }
        if norm_sq(&rep.zeta_a) + norm_sq(&rep.zeta_b) + norm_sq(&rep.zeta_q) > params.bound_sq
        {
            return false;
        }
    }
    // All repetitions' response matvecs in one blocked pass per G matrix:
    // G1 acts on [zeta_a, zeta_b, zeta_q] and G2 on [zeta_a, zeta_b].
    let g1_vecs: Vec<Vec<i64>> = proof
        .iter()
        .flat_map(|rep| [rep.zeta_a.clone(), rep.zeta_b.clone(), rep.zeta_q.clone()])
        .collect();
    let g2_vecs: Vec<Vec<i64>> = proof
        .iter()
        .flat_map(|rep| [rep.zeta_a.clone(), rep.zeta_b.clone()])
        .collect();
    let g1_res = matmat_signed(&crs.g1, params.k, big_n, &g1_vecs);
    let g2_res = matmat_signed(&crs.g2, n, big_n, &g2_vecs);
    proof.par_iter().enumerate().all(|(ell, rep)| {
        let mut reader = XofReader::new("sv", &[&h0, &(ell as u64).to_le_bytes()]);
        let s: Vec<u64> = (0..n).map(|_| reader.next_sb(params.b)).collect();
        let v: Vec<u64> = (0..params.m).map(|_| reader.next_sb(params.b)).collect();
        let t_a = combine_commit(ta, &s);
        let t_b = combine_commit(tb, &v);
        let t_c = combine_commit(tc, &v);
        let g_s = scalar_key(params, crs, &s);
        // T_t = (T_c first slot, s^T (T_c second slot)).
        let t_t_scalar = dot_mod(&s, &t_c[params.k..]);
        let gamma = rep.gamma;
        let gamma_sq = mulm(gamma, gamma);
        let assemble_w = |g1_part: &[u64], g2_part: &[u64], z: &[u64], t: &[u64]| -> Vec<u64> {
            let mut w = g1_part.to_vec();
            w.extend(g2_part.iter().zip(z.iter()).map(|(&g, &x)| addm(g, x)));
            for i in 0..w.len() {
                w[i] = subm(w[i], mulm(gamma, t[i]));
            }
            w
        };
        let w_a = assemble_w(&g1_res[3 * ell], &g2_res[2 * ell], &rep.z_a, &t_a);
        let w_b = assemble_w(&g1_res[3 * ell + 1], &g2_res[2 * ell + 1], &rep.z_b, &t_b);
        // t0 = (G1 zeta_q, <g_s, zeta_q> + <z_a, z_b>) - gamma t1 - gamma^2 T_t
        let mut t0 = g1_res[3 * ell + 2].clone();
        for i in 0..params.k {
            t0[i] = subm(subm(t0[i], mulm(gamma, rep.t1[i])), mulm(gamma_sq, t_c[i]));
        }
        let scalar_slot = subm(
            subm(
                addm(dot_signed(&g_s, &rep.zeta_q), dot_mod(&rep.z_a, &rep.z_b)),
                mulm(gamma, rep.t1[params.k]),
            ),
            mulm(gamma_sq, t_t_scalar),
        );
        t0.push(scalar_slot);
        let mut gr = XofReader::new(
            "gamma2",
            &[
                &h0,
                &(ell as u64).to_le_bytes(),
                &words_bytes(&w_a),
                &words_bytes(&w_b),
                &words_bytes(&t0),
                &words_bytes(&rep.t1),
            ],
        );
        gamma == gr.next_sb(params.b)
    })
}

// ---------------------------------------------------------------------------
// Instance generation, self-test, benchmarks.

fn matmul_mod_gemm(a: &[u64], b_cols: &[Vec<u64>], n: usize) -> Vec<Vec<u64>> {
    b_cols
        .par_iter()
        .map(|col| {
            (0..n)
                .map(|i| {
                    let mut acc: u128 = 0;
                    let base = i * n;
                    for t in 0..n {
                        acc += mulm(a[base + t], col[t]) as u128;
                    }
                    (acc % Q as u128) as u64
                })
                .collect()
        })
        .collect()
}

struct Instance {
    a_flat: Vec<u64>,        // n x n row-major
    a_rows: Vec<Vec<u64>>,   // for Pi2 row commitments
    b_cols: Vec<Vec<u64>>,
    rho_a: Vec<Vec<i8>>,
    rho_b: Vec<Vec<i8>>,
    tau_c: Vec<Vec<i8>>,
    ta: Vec<Vec<u64>>,
    tb: Vec<Vec<u64>>,
    tc: Vec<Vec<u64>>,
    matmul_s: f64,
    commit_s: f64,
}

fn make_instance(params: &Params, crs: &Crs, seed: u64, valid: bool, with_a_commit: bool) -> Instance {
    let n = params.n;
    let mut rng = seed;
    let a_flat: Vec<u64> = (0..n * n).map(|_| rng_small(&mut rng, 64)).collect();
    let b_cols: Vec<Vec<u64>> = (0..params.m)
        .map(|_| (0..n).map(|_| rng_small(&mut rng, 64)).collect())
        .collect();
    let start = Instant::now();
    let mut c_cols = matmul_mod_gemm(&a_flat, &b_cols, n);
    let matmul_s = start.elapsed().as_secs_f64();
    if !valid {
        c_cols[0][0] = addm(c_cols[0][0], 1);
    }
    let a_rows: Vec<Vec<u64>> =
        (0..n).map(|i| a_flat[i * n..(i + 1) * n].to_vec()).collect();
    let rho_a: Vec<Vec<i8>> =
        (0..n).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let rho_b: Vec<Vec<i8>> = (0..params.m)
        .map(|_| rng_ternary(&mut rng, params.big_n))
        .collect();
    let tau_c: Vec<Vec<i8>> = (0..params.m)
        .map(|_| rng_ternary(&mut rng, params.big_n))
        .collect();
    let start = Instant::now();
    let ta: Vec<Vec<u64>> = if with_a_commit {
        commit_columns_fast(params, crs, &a_rows, &rho_a)
    } else {
        Vec::new()
    };
    let tb = commit_columns_fast(params, crs, &b_cols, &rho_b);
    let tc = commit_columns_fast(params, crs, &c_cols, &tau_c);
    let commit_s = start.elapsed().as_secs_f64();
    Instance {
        a_flat,
        a_rows,
        b_cols,
        rho_a,
        rho_b,
        tau_c,
        ta,
        tb,
        tc,
        matmul_s,
        commit_s,
    }
}

fn run_case(proto: Protocol, n: usize, seed: u64, valid: bool) -> bool {
    let params = derive_params(proto, n, n);
    let crs = expand_crs(&params, 0xC0FFEE);
    let with_a = matches!(proto, Protocol::Pi2);
    let inst = make_instance(&params, &crs, seed, valid, with_a);
    let mut rng = seed ^ 0x5151_5151;
    match proto {
        Protocol::Pi1 => {
            let proof = prove_pi1(
                &params, &crs, &inst.a_flat, &inst.b_cols, &inst.rho_b,
                &inst.tau_c, &inst.tb, &inst.tc, &mut rng,
            );
            verify_pi1(&params, &crs, &inst.a_flat, &inst.tb, &inst.tc, &proof)
        }
        Protocol::Pi2 => {
            let proof = prove_pi2(
                &params, &crs, &inst.a_rows, &inst.rho_a, &inst.b_cols,
                &inst.rho_b, &inst.tau_c, &inst.ta, &inst.tb, &inst.tc,
                &mut rng,
            );
            verify_pi2(&params, &crs, &inst.ta, &inst.tb, &inst.tc, &proof)
        }
    }
}

fn self_test() {
    for (proto, name) in [(Protocol::Pi1, "pi1"), (Protocol::Pi2, "pi2")] {
        for n in [16usize, 32] {
            assert!(run_case(proto, n, 1000 + n as u64, true), "{name} n={n} valid");
            assert!(!run_case(proto, n, 2000 + n as u64, false), "{name} n={n} invalid");
        }
    }
    println!("lattice-matmul self-test ok");
}

fn bench(proto: Protocol, name: &str, n: usize) {
    let params = derive_params(proto, n, n);
    let start = Instant::now();
    let crs = expand_crs(&params, 0xC0FFEE);
    let crs_s = start.elapsed().as_secs_f64();
    let with_a = matches!(proto, Protocol::Pi2);
    let inst = make_instance(&params, &crs, 0xBEEF + n as u64, true, with_a);
    let mut rng = 0xABCD ^ n as u64;
    let (prove_s, verify_s, verified) = match proto {
        Protocol::Pi1 => {
            let start = Instant::now();
            let proof = prove_pi1(
                &params, &crs, &inst.a_flat, &inst.b_cols, &inst.rho_b,
                &inst.tau_c, &inst.tb, &inst.tc, &mut rng,
            );
            let prove_s = start.elapsed().as_secs_f64();
            let start = Instant::now();
            let ok = verify_pi1(&params, &crs, &inst.a_flat, &inst.tb, &inst.tc, &proof);
            (prove_s, start.elapsed().as_secs_f64(), ok)
        }
        Protocol::Pi2 => {
            let start = Instant::now();
            let proof = prove_pi2(
                &params, &crs, &inst.a_rows, &inst.rho_a, &inst.b_cols,
                &inst.rho_b, &inst.tau_c, &inst.ta, &inst.tb, &inst.tc,
                &mut rng,
            );
            let prove_s = start.elapsed().as_secs_f64();
            let start = Instant::now();
            let ok = verify_pi2(&params, &crs, &inst.ta, &inst.tb, &inst.tc, &proof);
            (prove_s, start.elapsed().as_secs_f64(), ok)
        }
    };
    println!(
        "{name},{n},{},{},{},{},{:.6},{:.6},{:.6},{:.6},{:.6},{},{verified}",
        params.b,
        params.r,
        params.k,
        params.big_n,
        crs_s,
        inst.matmul_s,
        inst.commit_s,
        prove_s,
        verify_s,
        proof_bytes(&params),
    );
}

fn bench_batch(proto: Protocol, name: &str, n: usize, batches: &[usize]) {
    let params = derive_params(proto, n, n);
    let start = Instant::now();
    let crs = expand_crs(&params, 0xC0FFEE);
    let crs_s = start.elapsed().as_secs_f64();
    let with_a = matches!(proto, Protocol::Pi2);
    let max_batch = *batches.iter().max().unwrap();
    let instances: Vec<Instance> = (0..max_batch)
        .map(|i| make_instance(&params, &crs, 0xCAFE + 31 * i as u64, true, with_a))
        .collect();
    for &t in batches {
        let start = Instant::now();
        let mut all_ok = true;
        let mut proofs1 = Vec::new();
        let mut proofs2 = Vec::new();
        for inst in &instances[..t] {
            let mut rng = 0xABCD ^ t as u64;
            match proto {
                Protocol::Pi1 => proofs1.push(prove_pi1(
                    &params, &crs, &inst.a_flat, &inst.b_cols, &inst.rho_b,
                    &inst.tau_c, &inst.tb, &inst.tc, &mut rng,
                )),
                Protocol::Pi2 => proofs2.push(prove_pi2(
                    &params, &crs, &inst.a_rows, &inst.rho_a, &inst.b_cols,
                    &inst.rho_b, &inst.tau_c, &inst.ta, &inst.tb, &inst.tc,
                    &mut rng,
                )),
            }
        }
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        for (i, inst) in instances[..t].iter().enumerate() {
            let ok = match proto {
                Protocol::Pi1 => verify_pi1(
                    &params, &crs, &inst.a_flat, &inst.tb, &inst.tc, &proofs1[i],
                ),
                Protocol::Pi2 => verify_pi2(
                    &params, &crs, &inst.ta, &inst.tb, &inst.tc, &proofs2[i],
                ),
            };
            all_ok &= ok;
        }
        let verify_s = start.elapsed().as_secs_f64();
        let commit_s: f64 = instances[..t].iter().map(|i| i.commit_s).sum();
        println!(
            "{name},{n},{t},{crs_s:.6},{commit_s:.6},{prove_s:.6},{:.6},{verify_s:.6},{:.6},{all_ok}",
            prove_s / t as f64,
            verify_s / t as f64,
        );
    }
}

fn usage() {
    eprintln!("usage:");
    eprintln!("  lattice_matmul self-test");
    eprintln!("  lattice_matmul bench <pi1|pi2> <n> [n...]");
    eprintln!("  lattice_matmul bench-batch <pi1|pi2> <n> <t...>");
    eprintln!("  lattice_matmul params <pi1|pi2> <n> [n...]");
}

fn parse_proto(arg: &str) -> Option<(Protocol, &str)> {
    match arg {
        "pi1" => Some((Protocol::Pi1, "pi1")),
        "pi2" => Some((Protocol::Pi2, "pi2")),
        _ => None,
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        usage();
        std::process::exit(1);
    }
    match args[1].as_str() {
        "self-test" => self_test(),
        "params" => {
            let Some((proto, name)) = parse_proto(args.get(2).map(String::as_str).unwrap_or(""))
            else {
                usage();
                std::process::exit(1);
            };
            println!("proto,n,b,r,k,N,log2_sigma,log2_beta,proof_mb");
            for arg in &args[3..] {
                let n: usize = arg.parse().unwrap();
                let params = derive_params(proto, n, n);
                println!(
                    "{name},{n},{},{},{},{},{:.1},{:.1},{:.2}",
                    params.b,
                    params.r,
                    params.k,
                    params.big_n,
                    (params.sigma as f64).log2(),
                    (params.beta as f64).log2(),
                    proof_bytes(&params) as f64 / 1e6,
                );
            }
        }
        "bench" => {
            let Some((proto, name)) = parse_proto(args.get(2).map(String::as_str).unwrap_or(""))
            else {
                usage();
                std::process::exit(1);
            };
            println!(
                "proto,n,b,r,k,N,crs_s,matmul_s,commit_s,prove_s,verify_s,proof_bytes,verified"
            );
            for arg in &args[3..] {
                let n: usize = arg.parse().unwrap();
                bench(proto, name, n);
            }
        }
        "bench-batch" => {
            if args.len() < 5 {
                usage();
                std::process::exit(1);
            }
            let Some((proto, name)) = parse_proto(args[2].as_str()) else {
                usage();
                std::process::exit(1);
            };
            let n: usize = args[3].parse().unwrap();
            let batches: Vec<usize> =
                args[4..].iter().map(|a| a.parse().unwrap()).collect();
            println!(
                "proto,n,batch,crs_s,commit_s,batch_prove_s,prove_per_claim_s,batch_verify_s,verify_per_claim_s,verified"
            );
            bench_batch(proto, name, n, &batches);
        }
        _ => {
            usage();
            std::process::exit(1);
        }
    }
}

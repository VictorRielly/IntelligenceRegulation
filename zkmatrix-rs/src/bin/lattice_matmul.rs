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
//! Rectangular support (M0): claims are `C = A B` with `A: rows x inner`,
//! `B: inner x cols`, `C: rows x cols`. The commitment message dimension
//! `msg` (rows of `G2`) covers the longest committed column over every shape
//! sharing the key; shorter columns/rows are zero-padded into the shared
//! message space, so each commitment is an ordinary commitment to the padded
//! vector. Every relation only ever *reads* the declared coordinate range
//! (`A z` reads `z[..inner]`, the Pi2 product inner products are truncated to
//! `inner`, the derived scalar projections read the declared row range), so
//! padding-region junk in an adversarial commitment can never influence a
//! verified statement.
//!
//! Layer chaining (M1): activations that appear as an output (committed by
//! columns) and as the next claim's left operand (committed by rows) are
//! linked by the transpose-consistency gadget: per repetition, random
//! `s, v`; `com(Y v)` is derived homomorphically from the column commitments
//! and `com(Y^T s)` from the row commitments; a Sigma-protocol of the
//! derived-key form (as for `T_t` in Pi2) proves the scalar projections
//! `s^T (Y v) = v^T (Y^T s)` agree. The gadget's Gaussian parameters account
//! for the norm growth of the homomorphically combined randomness
//! (`B_rho = count * 2^b * sqrt(N)` per orientation).
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

#[path = "../manifest.rs"]
mod manifest;
use manifest::{ClaimManifest, Operation, Orientation};

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
        hasher.update(b"lattice-matmul-v2");
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
    hasher.update(b"lattice-matmul-v2");
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
// Parameters (report Part II, Section 11), generalized to rectangular shapes.

#[derive(Clone, Copy, Debug)]
enum Protocol {
    Pi1,
    Pi2,
}

/// One matmul claim shape: `A: rows x inner`, `B: inner x cols`,
/// `C: rows x cols`.
#[derive(Clone, Copy, Debug)]
struct Shape {
    rows: usize,
    inner: usize,
    cols: usize,
}

#[derive(Clone, Debug)]
struct Params {
    proto: Protocol,
    /// Message dimension: rows of G2; every committed column/row is
    /// zero-padded to this length. Covers every shape sharing this key.
    msg: usize,
    b: u32,
    r: usize,
    k: usize,
    big_n: usize,
    sigma: u64,
    bound_sq: u128,
    beta: u128,
    /// Transpose-consistency gadget Gaussian parameters (chain mode; zero
    /// when the parameter set was derived without a link).
    sigma_t: u64,
    bound_t_sq: u128,
    /// Elementwise (Hadamard/binary) gadget Gaussian parameters (M2):
    /// per-triple centers over single ternary vectors, dimension 3N.
    sigma_h: u64,
    bound_h_sq: u128,
}

/// Largest rescale shift the conservatively folded gadget beta covers.
const GADGET_MAX_SHIFT: u32 = 12;

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

/// Derive one parameter set covering every shape in `shapes` (they share one
/// CRS), plus optionally the transpose gadget for a `link` matrix of the
/// given (rows, cols). Norm bounds use the worst-case combination counts
/// over all shapes; the message dimension covers the longest committed
/// column or row. For a single square shape this reproduces the original
/// square derivation exactly.
fn derive_params_multi(
    proto: Protocol,
    shapes: &[Shape],
    link: Option<(usize, usize)>,
) -> Params {
    derive_params_gadget(proto, shapes, link, 0)
}

/// Full derivation: `min_msg` raises the message dimension for packed
/// gadget columns (range-proof bit packing needs width * column-length
/// message slots).
fn derive_params_gadget(
    proto: Protocol,
    shapes: &[Shape],
    link: Option<(usize, usize)>,
    min_msg: usize,
) -> Params {
    assert!(!shapes.is_empty());
    let (b, r) = match proto {
        Protocol::Pi1 => (8u32, 37usize), // r (b-1) = 259 >= 256
        Protocol::Pi2 => (6u32, 64usize), // r (b-2) = 256
    };
    let two_b = 1u128 << b;
    // Message dimension: longest committed column (B/C columns have length
    // inner and rows) or row (Pi2's A rows have length inner). The link
    // matrix is an output of one claim and a left input of another, so its
    // dimensions are already covered, but include them for safety.
    let mut msg = shapes
        .iter()
        .map(|s| s.rows.max(s.inner))
        .max()
        .unwrap();
    if let Some((link_rows, link_cols)) = link {
        msg = msg.max(link_rows).max(link_cols);
    }
    msg = msg.max(min_msg);
    // Worst-case combination counts: s combines `rows` commitments, v
    // combines `cols` commitments.
    let max_rows = shapes.iter().map(|s| s.rows).max().unwrap();
    let max_cols = shapes.iter().map(|s| s.cols).max().unwrap();
    let mut k = 1536usize; // seed guess, refined by C3 below
    let mut big_n = ((k + msg + HIDING_DIM + 63) / 64) * 64;
    let mut sigma = 0u64;
    let mut bound_sq = 0u128;
    let mut beta = 0u128;
    let mut sigma_t = 0u64;
    let mut bound_t_sq = 0u128;
    let mut sigma_h = 0u64;
    let mut bound_h_sq = 0u128;
    for _ in 0..4 {
        let b0 = isqrt_ceil(big_n as u128);
        let (t_sq, dim) = match proto {
            Protocol::Pi1 => {
                let b_rho = max_cols as u128 * two_b * b0;
                (2 * (two_b * b_rho) * (two_b * b_rho), 2 * big_n)
            }
            Protocol::Pi2 => {
                let b_rho_s = max_rows as u128 * two_b * b0;
                let b_rho_v = max_cols as u128 * two_b * b0;
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
                let b_rho = max_cols as u128 * two_b * b0;
                2 * bound + two_b * b_rho
            }
            Protocol::Pi2 => {
                let b_rho_s = max_rows as u128 * two_b * b0;
                let b_rho_v = max_cols as u128 * two_b * b0;
                std::cmp::max(
                    2 * bound + two_b * b_rho_s,
                    3 * two_b * bound + two_b * two_b * two_b * b_rho_v,
                )
            }
        };
        // Transpose gadget: rejection center (gamma rho_v, gamma rho_s)
        // where rho_v combines `link_cols` ternary vectors and rho_s
        // combines `link_rows`, each with b-bit coefficients; dimension 2N.
        // The extracted SIS relation has norm <= 2 * bound_t + 2^b * B_rho,
        // which is folded into the shared beta so C3's k covers it.
        if let Some((link_rows, link_cols)) = link {
            let b_rho_s_t = link_rows as u128 * two_b * b0;
            let b_rho_v_t = link_cols as u128 * two_b * b0;
            let t_sq_t =
                two_b * two_b * (b_rho_s_t * b_rho_s_t + b_rho_v_t * b_rho_v_t);
            sigma_t = (12 * isqrt_ceil(t_sq_t)) as u64;
            bound_t_sq = 36
                * (sigma_t as u128)
                * (sigma_t as u128)
                * (2 * big_n) as u128
                / 25;
            let bound_t = isqrt_ceil(bound_t_sq);
            let beta_t =
                2 * bound_t + two_b * std::cmp::max(b_rho_s_t, b_rho_v_t);
            beta = std::cmp::max(beta, beta_t);
        }
        // M2 elementwise gadget (always derived): per-triple rejection
        // centers (gamma rho_x, gamma rho_y, gamma eta1 + gamma^2 rho_z)
        // over single ternary vectors -- no m-fold combination -- with
        // dimension 3N. The extracted SIS norms (2-transcript pair and the
        // 3-transcript Vandermonde-cleared T_t opening) fold into beta.
        {
            let last_h = two_b * b0 + two_b * two_b * b0;
            let t_sq_h = 2 * (two_b * b0) * (two_b * b0) + last_h * last_h;
            sigma_h = (12 * isqrt_ceil(t_sq_h)) as u64;
            bound_h_sq = 36
                * (sigma_h as u128)
                * (sigma_h as u128)
                * (3 * big_n) as u128
                / 25;
            let bound_h = isqrt_ceil(bound_h_sq);
            let beta_h = std::cmp::max(
                2 * bound_h + two_b * b0,
                3 * two_b * bound_h + two_b * two_b * two_b * b0,
            );
            beta = std::cmp::max(beta, beta_h);
            // Conservative folding for the rescale/recomposition opening
            // gadgets at the largest supported composition (max_cols
            // columns combined with b-bit weights, shift <=
            // GADGET_MAX_SHIFT): center norm of the masked opening.
            let center_link = two_b
                * two_b
                * max_cols as u128
                * (2 + (1u128 << GADGET_MAX_SHIFT))
                * b0;
            let sigma_link = 12 * isqrt_ceil(center_link * center_link);
            let bound_link_sq =
                36 * sigma_link * sigma_link * big_n as u128 / 25;
            let beta_link = 2 * isqrt_ceil(bound_link_sq) + center_link;
            beta = std::cmp::max(beta, beta_link);
        }
        // C3: 2 sqrt(k log2 q log2 delta0) >= log2 beta.
        let log2_beta = (beta as f64).log2();
        k = ((log2_beta / 2.0) * (log2_beta / 2.0) / (LOG2_Q * LOG2_DELTA0))
            .ceil() as usize;
        // C4: N - (k + msg) >= hiding dimension.
        big_n = ((k + msg + HIDING_DIM + 63) / 64) * 64;
    }
    // C0/C2 sanity for the modulus shared by both protocols.
    assert!(Q as u128 > 8 * beta, "q too small for beta at this shape");
    assert!(Q as u128 > 1u128 << (3 * b), "q too small for 2^(3b)");
    Params {
        proto,
        msg,
        b,
        r,
        k,
        big_n,
        sigma,
        bound_sq,
        beta,
        sigma_t,
        bound_t_sq,
        sigma_h,
        bound_h_sq,
    }
}

fn derive_params(proto: Protocol, n: usize, m: usize) -> Params {
    derive_params_multi(
        proto,
        &[Shape {
            rows: n,
            inner: n,
            cols: m,
        }],
        None,
    )
}

fn proof_bytes(params: &Params) -> usize {
    let sigma_bits = 64 - params.sigma.leading_zeros() as usize + 4;
    let bits_per_rep = match params.proto {
        Protocol::Pi1 => {
            params.b as usize
                + params.msg * 61
                + 2 * params.big_n * sigma_bits
        }
        Protocol::Pi2 => {
            params.b as usize
                + (params.k + 1 + 2 * params.msg) * 61
                + 3 * params.big_n * sigma_bits
        }
    };
    params.r * bits_per_rep / 8
}

// ---------------------------------------------------------------------------
// CRS and commitments.

struct Crs {
    g1: Vec<u64>, // k x N row-major
    g2: Vec<u64>, // msg x N row-major
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
    let g2 = expand("G2", params.msg);
    let crs_hash = hash_words(
        "crs",
        &[
            &seed.to_le_bytes(),
            &Q.to_le_bytes(),
            &(params.msg as u64).to_le_bytes(),
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

/// Serial signed matvec, for use inside repetition-parallel contexts.
fn matvec_signed_serial(g: &[u64], rows: usize, width: usize, v: &[i64]) -> Vec<u64> {
    (0..rows)
        .map(|row| {
            let grow = &g[row * width..(row + 1) * width];
            let mut acc: i128 = 0;
            for t in 0..width {
                acc += grow[t] as i128 * v[t] as i128;
            }
            reduce_i128(acc)
        })
        .collect()
}

/// Commit every column of a matrix in blocked multi-vector passes. Messages
/// shorter than the shared message dimension are zero-padded: the result is
/// an ordinary commitment to the padded vector (`G2 rho + pad(x)`).
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
        let t2s = matmat_signed(&crs.g2, params.msg, params.big_n, &widened);
        for ((msg, mut t1), t2) in msg_chunk.iter().zip(t1s).zip(t2s) {
            assert!(msg.len() <= params.msg, "message longer than key");
            t1.extend(t2.iter().enumerate().map(|(i, &g)| {
                if i < msg.len() { addm(g, msg[i]) } else { g }
            }));
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

fn pad_to(mut v: Vec<u64>, len: usize) -> Vec<u64> {
    assert!(v.len() <= len);
    v.resize(len, 0);
    v
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

/// Statement hash: binds the CRS, the claim shape, an optional chain
/// context (claim-manifest digest; empty for stand-alone claims) and every
/// commitment group. Every Fiat-Shamir challenge derives from this hash, so
/// chained claims bind the whole DAG before any challenge is drawn.
fn statement_hash(
    crs: &Crs,
    tag: &str,
    shape: &Shape,
    ctx: &[u8],
    groups: &[&[Vec<u64>]],
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"lattice-matmul-v2");
    hasher.update(tag.as_bytes());
    hasher.update(crs.crs_hash);
    hasher.update((shape.rows as u64).to_le_bytes());
    hasher.update((shape.inner as u64).to_le_bytes());
    hasher.update((shape.cols as u64).to_le_bytes());
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    for group in groups {
        for commitment in group.iter() {
            hasher.update(words_bytes(commitment));
        }
    }
    hasher.finalize().into()
}

fn commitment_group_digest(group: &[Vec<u64>]) -> Vec<u8> {
    let mut hasher = Sha256::new();
    hasher.update(b"lattice-commit-group");
    hasher.update((group.len() as u64).to_le_bytes());
    for commitment in group {
        hasher.update(words_bytes(commitment));
    }
    hasher.finalize().to_vec()
}

// ---------------------------------------------------------------------------
// Pi1: public A (rows x inner), hidden B (inner x cols) and C (rows x cols).

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
    shape: &Shape,
    ctx: &[u8],
    a: &[u64], // rows x inner row-major, public
    b_cols: &[Vec<u64>],
    rho_b: &[Vec<i8>],
    tau_c: &[Vec<i8>],
    tb: &[Vec<u64>],
    tc: &[Vec<u64>],
    rng: &mut u64,
) -> Vec<Pi1Rep> {
    let msg = params.msg;
    let inner = shape.inner;
    let big_n = params.big_n;
    let h0 = statement_hash(crs, "stmt-pi1", shape, ctx, &[tb, tc]);
    let base_rng = splitmix64(rng);
    // Per-repetition state, built in parallel; each repetition owns a
    // deterministic rng stream so wave sampling can also run in parallel.
    struct RepState {
        b_vec: Vec<u64>, // padded to msg
        rho_v: Vec<i64>,
        tau_v: Vec<i64>,
        rng: u64,
    }
    let mut states: Vec<RepState> = (0..params.r)
        .into_par_iter()
        .map(|ell| {
            let mut reader = XofReader::new("v", &[&h0, &(ell as u64).to_le_bytes()]);
            let v: Vec<u64> = (0..shape.cols).map(|_| reader.next_sb(params.b)).collect();
            RepState {
                b_vec: pad_to(combine_columns(b_cols, &v), msg),
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
                let eps: Vec<u64> = (0..msg).map(|_| rng_field(&mut r)).collect();
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
        let g2_res = matmat_signed(&crs.g2, msg, big_n, &noise_all);
        // A acts on the declared coordinate range of eps only; the result
        // (length rows) is padded back into the shared message space.
        let a_eps_all: Vec<Vec<u64>> = eps_all
            .par_iter()
            .map(|eps| {
                pad_to(
                    matvec_mod_serial(a, shape.rows, inner, &eps[..inner]),
                    msg,
                )
            })
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
            let z: Vec<u64> = (0..msg)
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
    shape: &Shape,
    ctx: &[u8],
    a: &[u64],
    tb: &[Vec<u64>],
    tc: &[Vec<u64>],
    proof: &[Pi1Rep],
) -> bool {
    if proof.len() != params.r {
        return false;
    }
    if tb.len() != shape.cols || tc.len() != shape.cols {
        return false;
    }
    let msg = params.msg;
    let inner = shape.inner;
    let big_n = params.big_n;
    let h0 = statement_hash(crs, "stmt-pi1", shape, ctx, &[tb, tc]);
    for rep in proof {
        if rep.gamma >= (1 << params.b) {
            return false;
        }
        if rep.z.len() != msg || rep.z.iter().any(|&z| z >= Q) {
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
    let g2_res = matmat_signed(&crs.g2, msg, big_n, &vecs);
    proof.par_iter().enumerate().all(|(ell, rep)| {
        let mut reader = XofReader::new("v", &[&h0, &(ell as u64).to_le_bytes()]);
        let v: Vec<u64> = (0..shape.cols).map(|_| reader.next_sb(params.b)).collect();
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
        // u = (G1 xi, G2 xi + pad(A z[..inner])) - gamma T_c
        let az = pad_to(
            matvec_mod_serial(a, shape.rows, inner, &rep.z[..inner]),
            msg,
        );
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

/// g_s^T = s^T G2 over the first `s.len()` rows of G2 (length N). Serial:
/// callers run it inside repetition-parallel maps.
fn scalar_key(params: &Params, crs: &Crs, s: &[u64]) -> Vec<u64> {
    let mut out = vec![0u128; params.big_n];
    for (i, &si) in s.iter().enumerate() {
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
    shape: &Shape,
    ctx: &[u8],
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
    let msg = params.msg;
    let inner = shape.inner;
    let big_n = params.big_n;
    let h0 = statement_hash(crs, "stmt-pi2", shape, ctx, &[ta, tb, tc]);
    let base_rng = splitmix64(rng);
    struct RepState {
        a_vec: Vec<u64>, // padded to msg
        b_vec: Vec<u64>, // padded to msg
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
            let s: Vec<u64> = (0..shape.rows).map(|_| reader.next_sb(params.b)).collect();
            let v: Vec<u64> = (0..shape.cols).map(|_| reader.next_sb(params.b)).collect();
            let mut a_vec = vec![0u64; inner];
            for (row, &coeff) in a_rows.iter().zip(s.iter()) {
                axpy_mod(&mut a_vec, row, coeff);
            }
            let g_s = scalar_key(params, crs, &s);
            RepState {
                a_vec: pad_to(a_vec, msg),
                b_vec: pad_to(combine_columns(b_cols, &v), msg),
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
                    let eps_a: Vec<u64> = (0..msg).map(|_| rng_field(&mut r)).collect();
                    let eps_b: Vec<u64> = (0..msg).map(|_| rng_field(&mut r)).collect();
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
        let g2_res = matmat_signed(&crs.g2, msg, big_n, &g2_vecs);
        let mut next_pending = Vec::new();
        for (idx, &i) in pending.iter().enumerate() {
            let ell = i;
            let (eps_a, eps_b) = &eps_all[idx];
            let eta_a = &g1_vecs[4 * idx];
            let eta_b = &g1_vecs[4 * idx + 1];
            let eta0 = &g1_vecs[4 * idx + 2];
            let eta1 = &g1_vecs[4 * idx + 3];
            let st_ro = &states[i];
            // Inner products are truncated to the declared inner dimension
            // so the padding region can never influence the scalar claim.
            let g0 = dot_mod(&eps_a[..inner], &eps_b[..inner]);
            let g1_scalar = addm(
                dot_mod(&eps_a[..inner], &st_ro.b_vec[..inner]),
                dot_mod(&st_ro.a_vec[..inner], &eps_b[..inner]),
            );
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
            let z_a: Vec<u64> = (0..msg)
                .map(|j| addm(eps_a[j], mulm(gamma, st.a_vec[j])))
                .collect();
            let z_b: Vec<u64> = (0..msg)
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
    shape: &Shape,
    ctx: &[u8],
    ta: &[Vec<u64>],
    tb: &[Vec<u64>],
    tc: &[Vec<u64>],
    proof: &[Pi2Rep],
) -> bool {
    if proof.len() != params.r {
        return false;
    }
    if ta.len() != shape.rows || tb.len() != shape.cols || tc.len() != shape.cols {
        return false;
    }
    let msg = params.msg;
    let inner = shape.inner;
    let big_n = params.big_n;
    let h0 = statement_hash(crs, "stmt-pi2", shape, ctx, &[ta, tb, tc]);
    for rep in proof {
        if rep.gamma >= (1 << params.b) {
            return false;
        }
        if rep.t1.len() != params.k + 1 || rep.t1.iter().any(|&x| x >= Q) {
            return false;
        }
        for z in [&rep.z_a, &rep.z_b] {
            if z.len() != msg || z.iter().any(|&x| x >= Q) {
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
    let g2_res = matmat_signed(&crs.g2, msg, big_n, &g2_vecs);
    proof.par_iter().enumerate().all(|(ell, rep)| {
        let mut reader = XofReader::new("sv", &[&h0, &(ell as u64).to_le_bytes()]);
        let s: Vec<u64> = (0..shape.rows).map(|_| reader.next_sb(params.b)).collect();
        let v: Vec<u64> = (0..shape.cols).map(|_| reader.next_sb(params.b)).collect();
        let t_a = combine_commit(ta, &s);
        let t_b = combine_commit(tb, &v);
        let t_c = combine_commit(tc, &v);
        let g_s = scalar_key(params, crs, &s);
        // T_t = (T_c first slot, s^T (T_c second slot restricted to the
        // declared row range)).
        let t_t_scalar = dot_mod(&s, &t_c[params.k..params.k + shape.rows]);
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
        // t0 = (G1 zeta_q, <g_s, zeta_q> + <z_a, z_b>_inner)
        //      - gamma t1 - gamma^2 T_t
        let mut t0 = g1_res[3 * ell + 2].clone();
        for i in 0..params.k {
            t0[i] = subm(subm(t0[i], mulm(gamma, rep.t1[i])), mulm(gamma_sq, t_c[i]));
        }
        let inner_z = dot_mod(&rep.z_a[..inner], &rep.z_b[..inner]);
        let scalar_slot = subm(
            subm(
                addm(dot_signed(&g_s, &rep.zeta_q), inner_z),
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
// Transpose-consistency gadget (M1 layer chaining).
//
// Statement: the by-columns commitments `col_commits` (n_c commitments to
// columns of Y, length n_r) and the by-rows commitments `row_commits`
// (n_r commitments to rows of Y, length n_c) open to the same matrix Y.
//
// Per repetition: challenges s (length n_r) and v (length n_c) with b-bit
// entries; the verifier derives
//
//   T_v = sum_j v_j Tcol_j  = com(pad(Y v); rho_v),   rho_v = sum_j v_j tau_j
//   T_s = sum_i s_i Trow_i  = com(pad(Y^T s); rho_s), rho_s = sum_i s_i rho_i
//   c_v = <s, msg-slot(T_v)[..n_r]> = <g_s, rho_v> + s^T Y v
//   c_s = <v, msg-slot(T_s)[..n_c]> = <g_v, rho_s> + v^T Y^T s
//
// where g_s = s^T G2, g_v = v^T G2 are derived scalar keys (as for T_t in
// Pi2). If both orientations hold the same Y the message parts cancel in
// c_v - c_s, so the prover shows knowledge of short (rho_v, rho_s) with
//
//   G1 rho_v = T_v[..k],  G1 rho_s = T_s[..k],
//   <g_s, rho_v> - <g_v, rho_s> = c_v - c_s
//
// via a Gaussian-masked Sigma-protocol with rejection sampling (parameters
// sigma_t / bound_t_sq sized for the homomorphically combined randomness).
// If the matrices differ, s^T (Y_col - Y_row^T) v != 0 except with
// probability ~2^{1-b} per repetition, and the verification equation fails.

struct TransposeRep {
    gamma: u64,
    zeta_v: Vec<i64>,
    zeta_s: Vec<i64>,
}

fn transpose_statement_hash(
    crs: &Crs,
    ctx: &[u8],
    n_r: usize,
    n_c: usize,
    row_commits: &[Vec<u64>],
    col_commits: &[Vec<u64>],
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"lattice-matmul-v2");
    hasher.update(b"stmt-transpose");
    hasher.update(crs.crs_hash);
    hasher.update((n_r as u64).to_le_bytes());
    hasher.update((n_c as u64).to_le_bytes());
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    for group in [row_commits, col_commits] {
        for commitment in group {
            hasher.update(words_bytes(commitment));
        }
    }
    hasher.finalize().into()
}

#[allow(clippy::too_many_arguments)]
fn prove_transpose(
    params: &Params,
    crs: &Crs,
    n_r: usize,
    n_c: usize,
    ctx: &[u8],
    row_commits: &[Vec<u64>],
    col_commits: &[Vec<u64>],
    rho_rows: &[Vec<i8>],
    tau_cols: &[Vec<i8>],
    rng: &mut u64,
) -> Vec<TransposeRep> {
    assert!(params.sigma_t > 0, "params derived without a link shape");
    let big_n = params.big_n;
    let h0 = transpose_statement_hash(crs, ctx, n_r, n_c, row_commits, col_commits);
    let base_rng = splitmix64(rng);
    (0..params.r)
        .into_par_iter()
        .map(|ell| {
            let mut reader =
                XofReader::new("sv-t", &[&h0, &(ell as u64).to_le_bytes()]);
            let s: Vec<u64> = (0..n_r).map(|_| reader.next_sb(params.b)).collect();
            let v: Vec<u64> = (0..n_c).map(|_| reader.next_sb(params.b)).collect();
            let rho_v = combine_ternary(tau_cols, &v);
            let rho_s = combine_ternary(rho_rows, &s);
            let g_s = scalar_key(params, crs, &s);
            let g_v = scalar_key(params, crs, &v);
            let mut r = mix_seed(base_rng, ell as u64);
            loop {
                let noise = gaussian_vec(&mut r, 2 * big_n, params.sigma_t);
                let eta_v = &noise[..big_n];
                let eta_s = &noise[big_n..];
                let w1 = matvec_signed_serial(&crs.g1, params.k, big_n, eta_v);
                let w2 = matvec_signed_serial(&crs.g1, params.k, big_n, eta_s);
                let w3 = subm(dot_signed(&g_s, eta_v), dot_signed(&g_v, eta_s));
                let mut gr = XofReader::new(
                    "gamma-t",
                    &[
                        &h0,
                        &(ell as u64).to_le_bytes(),
                        &words_bytes(&w1),
                        &words_bytes(&w2),
                        &w3.to_le_bytes(),
                    ],
                );
                let gamma = gr.next_sb(params.b);
                let g = gamma as i64;
                let zeta_v: Vec<i64> =
                    (0..big_n).map(|j| eta_v[j] + g * rho_v[j]).collect();
                let zeta_s: Vec<i64> =
                    (0..big_n).map(|j| eta_s[j] + g * rho_s[j]).collect();
                let mut response = zeta_v.clone();
                response.extend_from_slice(&zeta_s);
                let mut center: Vec<i64> = rho_v.iter().map(|&x| g * x).collect();
                center.extend(rho_s.iter().map(|&x| g * x));
                if rejection_accept(&mut r, &response, &center, params.sigma_t) {
                    return TransposeRep {
                        gamma,
                        zeta_v,
                        zeta_s,
                    };
                }
            }
        })
        .collect()
}

fn verify_transpose(
    params: &Params,
    crs: &Crs,
    n_r: usize,
    n_c: usize,
    ctx: &[u8],
    row_commits: &[Vec<u64>],
    col_commits: &[Vec<u64>],
    proof: &[TransposeRep],
) -> bool {
    if params.sigma_t == 0 || proof.len() != params.r {
        return false;
    }
    if row_commits.len() != n_r || col_commits.len() != n_c {
        return false;
    }
    if n_r > params.msg || n_c > params.msg {
        return false;
    }
    let big_n = params.big_n;
    // Norm and length checks first: the mod-q linear checks below must
    // never run on unbounded responses.
    for rep in proof {
        if rep.gamma >= (1 << params.b) {
            return false;
        }
        if rep.zeta_v.len() != big_n || rep.zeta_s.len() != big_n {
            return false;
        }
        if norm_sq(&rep.zeta_v) + norm_sq(&rep.zeta_s) > params.bound_t_sq {
            return false;
        }
    }
    let h0 = transpose_statement_hash(crs, ctx, n_r, n_c, row_commits, col_commits);
    proof.par_iter().enumerate().all(|(ell, rep)| {
        let mut reader = XofReader::new("sv-t", &[&h0, &(ell as u64).to_le_bytes()]);
        let s: Vec<u64> = (0..n_r).map(|_| reader.next_sb(params.b)).collect();
        let v: Vec<u64> = (0..n_c).map(|_| reader.next_sb(params.b)).collect();
        let t_v = combine_commit(col_commits, &v);
        let t_s = combine_commit(row_commits, &s);
        let c_v = dot_mod(&s, &t_v[params.k..params.k + n_r]);
        let c_s = dot_mod(&v, &t_s[params.k..params.k + n_c]);
        let g_s = scalar_key(params, crs, &s);
        let g_v = scalar_key(params, crs, &v);
        let gamma = rep.gamma;
        // w1 = G1 zeta_v - gamma T_v[..k], w2 = G1 zeta_s - gamma T_s[..k]
        let mut w1 = matvec_signed_serial(&crs.g1, params.k, big_n, &rep.zeta_v);
        let mut w2 = matvec_signed_serial(&crs.g1, params.k, big_n, &rep.zeta_s);
        for i in 0..params.k {
            w1[i] = subm(w1[i], mulm(gamma, t_v[i]));
            w2[i] = subm(w2[i], mulm(gamma, t_s[i]));
        }
        // w3 = (<g_s, zeta_v> - <g_v, zeta_s>) - gamma (c_v - c_s)
        let w3 = subm(
            subm(dot_signed(&g_s, &rep.zeta_v), dot_signed(&g_v, &rep.zeta_s)),
            mulm(gamma, subm(c_v, c_s)),
        );
        let mut gr = XofReader::new(
            "gamma-t",
            &[
                &h0,
                &(ell as u64).to_le_bytes(),
                &words_bytes(&w1),
                &words_bytes(&w2),
                &w3.to_le_bytes(),
            ],
        );
        gamma == gr.next_sb(params.b)
    })
}

// ---------------------------------------------------------------------------
// M2 elementwise gadget family (Class 3 of the transformer proof plan).
//
// Hadamard gadget: prove z = x o y per committed column with the derived-key
// garbage-term Sigma-protocol. Per repetition draw s from S_b^L; the claim
// <s o x, y> = s^T z is one inner product where (a) s o x's commitment
// derives from T_x by scaling the message rows of the second slot by s (key
// (G1, D_s G2): the first slot is unchanged, so Lemma 5.5 binding applies
// verbatim, exactly as with Pi2's scalar key), (b) y sits under the standard
// key, and (c) the scalar s^T z sits under the scalar key g_s = s^T G2 as
// Pi2's T_t does. 3-special soundness mirrors Theorem 8.3 per triple; a
// defect d = x o y - z != 0 survives <s, d> = 0 with probability <= 2^-b
// per repetition. Binary constraints are the special case x = y = z = b.
//
// Range proofs pack the W bit-vectors of one column into a single committed
// "packed" column (slot i*L + t holds bit i of element t), so the binary
// family runs once per column instead of once per bit vector. The
// recomposition <s, value_j> = <w, packed_j> with w[i*L + t] = 2^i s_t is
// linear and batches across all columns with fresh weights u_j into one
// two-sided scalar-link Sigma-proof per repetition (the transpose-gadget
// shape, with keys g_s and g_w). Rescale-with-rounding x = 2^shift y + r is
// a zero-opening proof on the u-combined difference commitment plus range
// proofs on r (width = shift) and y (declared width); the ranges make the
// mod-q linear relation an integer relation (no wraparound), which is what
// turns "x = 2^shift y + r mod q" into floor division.

struct HadamardStatement<'a> {
    len: usize,
    tx: &'a [u64],
    ty: &'a [u64],
    tz: &'a [u64],
}

struct HadamardWitness<'a> {
    x: &'a [u64],
    y: &'a [u64],
    rho_x: &'a [i8],
    rho_y: &'a [i8],
    rho_z: &'a [i8],
}

struct HadamardRep {
    gamma: u64,
    t1: Vec<u64>,
    z_a: Vec<u64>,
    z_b: Vec<u64>,
    zeta_a: Vec<i64>,
    zeta_b: Vec<i64>,
    zeta_q: Vec<i64>,
}

fn hadamard_statement_hash(
    crs: &Crs,
    ctx: &[u8],
    stmts: &[HadamardStatement],
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"lattice-matmul-v2");
    hasher.update(b"stmt-hadamard");
    hasher.update(crs.crs_hash);
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    hasher.update((stmts.len() as u64).to_le_bytes());
    for st in stmts {
        hasher.update((st.len as u64).to_le_bytes());
        hasher.update(words_bytes(st.tx));
        hasher.update(words_bytes(st.ty));
        hasher.update(words_bytes(st.tz));
    }
    hasher.finalize().into()
}

/// Scalar key over an s of arbitrary length <= msg: g_s^T = s^T G2[..len].
fn scalar_key_prefix(params: &Params, crs: &Crs, s: &[u64]) -> Vec<u64> {
    let mut out = vec![0u128; params.big_n];
    for (i, &si) in s.iter().enumerate() {
        let row = &crs.g2[i * params.big_n..(i + 1) * params.big_n];
        for (o, &g) in out.iter_mut().zip(row.iter()) {
            *o += mulm(si, g) as u128;
        }
    }
    out.into_iter().map(|acc| (acc % Q as u128) as u64).collect()
}

fn prove_hadamard(
    params: &Params,
    crs: &Crs,
    ctx: &[u8],
    stmts: &[HadamardStatement],
    wits: &[HadamardWitness],
    rng: &mut u64,
) -> Vec<Vec<HadamardRep>> {
    assert_eq!(stmts.len(), wits.len());
    assert!(params.sigma_h > 0);
    let big_n = params.big_n;
    let h0 = hadamard_statement_hash(crs, ctx, stmts);
    let base = splitmix64(rng);
    let grid: Vec<(usize, usize)> = (0..stmts.len())
        .flat_map(|ti| (0..params.r).map(move |ell| (ti, ell)))
        .collect();
    let flat: Vec<HadamardRep> = grid
        .par_iter()
        .map(|&(ti, ell)| {
            let st = &stmts[ti];
            let wit = &wits[ti];
            let l = st.len;
            // s is shared per repetition across triples (prefix per length).
            let mut reader =
                XofReader::new("s-h", &[&h0, &(ell as u64).to_le_bytes()]);
            let s: Vec<u64> = (0..l).map(|_| reader.next_sb(params.b)).collect();
            let g_s = scalar_key_prefix(params, crs, &s);
            let a: Vec<u64> = (0..l).map(|i| mulm(s[i], wit.x[i])).collect();
            let mut r = mix_seed(base, (ti * params.r + ell) as u64);
            loop {
                let eps_a: Vec<u64> = (0..l).map(|_| rng_field(&mut r)).collect();
                let eps_b: Vec<u64> = (0..l).map(|_| rng_field(&mut r)).collect();
                let eta1 = rng_ternary(&mut r, big_n);
                let noise = gaussian_vec(&mut r, 3 * big_n, params.sigma_h);
                let eta_a = &noise[..big_n];
                let eta_b = &noise[big_n..2 * big_n];
                let eta0 = &noise[2 * big_n..];
                let g0 = dot_mod(&eps_a, &eps_b);
                let g1v = addm(dot_mod(&eps_a, &wit.y[..l]), dot_mod(&a, &eps_b));
                // w_a = (G1 eta_a, s o (G2[..l] eta_a) + eps_a)
                let mut w_a = matvec_signed_serial(&crs.g1, params.k, big_n, eta_a);
                let g2ea = matvec_signed_serial(&crs.g2, l, big_n, eta_a);
                w_a.extend((0..l).map(|i| addm(mulm(s[i], g2ea[i]), eps_a[i])));
                // w_b = (G1 eta_b, G2[..l] eta_b + eps_b)
                let mut w_b = matvec_signed_serial(&crs.g1, params.k, big_n, eta_b);
                let g2eb = matvec_signed_serial(&crs.g2, l, big_n, eta_b);
                w_b.extend((0..l).map(|i| addm(g2eb[i], eps_b[i])));
                let mut t0 = matvec_signed_serial(&crs.g1, params.k, big_n, eta0);
                t0.push(addm(dot_signed(&g_s, eta0), g0));
                let eta1w: Vec<i64> = eta1.iter().map(|&x| x as i64).collect();
                let mut t1 = matvec_signed_serial(&crs.g1, params.k, big_n, &eta1w);
                t1.push(addm(dot_signed(&g_s, &eta1w), g1v));
                let mut gr = XofReader::new(
                    "gamma-h",
                    &[
                        &h0,
                        &(ti as u64).to_le_bytes(),
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
                let z_a: Vec<u64> =
                    (0..l).map(|i| addm(eps_a[i], mulm(gamma, a[i]))).collect();
                let z_b: Vec<u64> = (0..l)
                    .map(|i| addm(eps_b[i], mulm(gamma, wit.y[i])))
                    .collect();
                let zeta_a: Vec<i64> = (0..big_n)
                    .map(|j| eta_a[j] + g * wit.rho_x[j] as i64)
                    .collect();
                let zeta_b: Vec<i64> = (0..big_n)
                    .map(|j| eta_b[j] + g * wit.rho_y[j] as i64)
                    .collect();
                let zeta_q: Vec<i64> = (0..big_n)
                    .map(|j| eta0[j] + g * eta1[j] as i64 + g_sq * wit.rho_z[j] as i64)
                    .collect();
                let mut response = zeta_a.clone();
                response.extend_from_slice(&zeta_b);
                response.extend_from_slice(&zeta_q);
                let mut center: Vec<i64> =
                    wit.rho_x.iter().map(|&x| g * x as i64).collect();
                center.extend(wit.rho_y.iter().map(|&x| g * x as i64));
                center.extend(
                    (0..big_n).map(|j| g * eta1[j] as i64 + g_sq * wit.rho_z[j] as i64),
                );
                if rejection_accept(&mut r, &response, &center, params.sigma_h) {
                    return HadamardRep {
                        gamma,
                        t1,
                        z_a,
                        z_b,
                        zeta_a,
                        zeta_b,
                        zeta_q,
                    };
                }
            }
        })
        .collect();
    flat.chunks(params.r).map(|c| c.iter().map(clone_hrep).collect()).collect()
}

fn clone_hrep(rep: &HadamardRep) -> HadamardRep {
    HadamardRep {
        gamma: rep.gamma,
        t1: rep.t1.clone(),
        z_a: rep.z_a.clone(),
        z_b: rep.z_b.clone(),
        zeta_a: rep.zeta_a.clone(),
        zeta_b: rep.zeta_b.clone(),
        zeta_q: rep.zeta_q.clone(),
    }
}

fn verify_hadamard(
    params: &Params,
    crs: &Crs,
    ctx: &[u8],
    stmts: &[HadamardStatement],
    proof: &[Vec<HadamardRep>],
) -> bool {
    if params.sigma_h == 0 || proof.len() != stmts.len() {
        return false;
    }
    let big_n = params.big_n;
    for (st, reps) in stmts.iter().zip(proof.iter()) {
        if st.len > params.msg || reps.len() != params.r {
            return false;
        }
        for rep in reps {
            if rep.gamma >= (1 << params.b)
                || rep.t1.len() != params.k + 1
                || rep.t1.iter().any(|&x| x >= Q)
                || rep.z_a.len() != st.len
                || rep.z_b.len() != st.len
                || rep.z_a.iter().chain(rep.z_b.iter()).any(|&x| x >= Q)
                || rep.zeta_a.len() != big_n
                || rep.zeta_b.len() != big_n
                || rep.zeta_q.len() != big_n
            {
                return false;
            }
            if norm_sq(&rep.zeta_a) + norm_sq(&rep.zeta_b) + norm_sq(&rep.zeta_q)
                > params.bound_h_sq
            {
                return false;
            }
        }
    }
    let h0 = hadamard_statement_hash(crs, ctx, stmts);
    let grid: Vec<(usize, usize)> = (0..stmts.len())
        .flat_map(|ti| (0..params.r).map(move |ell| (ti, ell)))
        .collect();
    grid.par_iter().all(|&(ti, ell)| {
        let st = &stmts[ti];
        let rep = &proof[ti][ell];
        let l = st.len;
        let mut reader = XofReader::new("s-h", &[&h0, &(ell as u64).to_le_bytes()]);
        let s: Vec<u64> = (0..l).map(|_| reader.next_sb(params.b)).collect();
        let g_s = scalar_key_prefix(params, crs, &s);
        let gamma = rep.gamma;
        let gamma_sq = mulm(gamma, gamma);
        // (i): w_a = (G1 zeta_a - gamma tx1, s o (G2 zeta_a) + z_a - gamma s o tx2)
        let mut w_a = matvec_signed_serial(&crs.g1, params.k, big_n, &rep.zeta_a);
        for i in 0..params.k {
            w_a[i] = subm(w_a[i], mulm(gamma, st.tx[i]));
        }
        let g2za = matvec_signed_serial(&crs.g2, l, big_n, &rep.zeta_a);
        w_a.extend((0..l).map(|i| {
            subm(
                addm(mulm(s[i], g2za[i]), rep.z_a[i]),
                mulm(gamma, mulm(s[i], st.tx[params.k + i])),
            )
        }));
        // (ii): w_b = (G1 zeta_b - gamma ty1, G2 zeta_b + z_b - gamma ty2)
        let mut w_b = matvec_signed_serial(&crs.g1, params.k, big_n, &rep.zeta_b);
        for i in 0..params.k {
            w_b[i] = subm(w_b[i], mulm(gamma, st.ty[i]));
        }
        let g2zb = matvec_signed_serial(&crs.g2, l, big_n, &rep.zeta_b);
        w_b.extend((0..l).map(|i| {
            subm(
                addm(g2zb[i], rep.z_b[i]),
                mulm(gamma, st.ty[params.k + i]),
            )
        }));
        // (iii): t0 = (G1 zeta_q - gamma t1[..k] - gamma^2 tz1,
        //              <g_s, zeta_q> + <z_a, z_b> - gamma t1[k] - gamma^2 s^T tz2)
        let mut t0 = matvec_signed_serial(&crs.g1, params.k, big_n, &rep.zeta_q);
        for i in 0..params.k {
            t0[i] = subm(
                subm(t0[i], mulm(gamma, rep.t1[i])),
                mulm(gamma_sq, st.tz[i]),
            );
        }
        let t_scalar = dot_mod(&s, &st.tz[params.k..params.k + l]);
        t0.push(subm(
            subm(
                addm(dot_signed(&g_s, &rep.zeta_q), dot_mod(&rep.z_a, &rep.z_b)),
                mulm(gamma, rep.t1[params.k]),
            ),
            mulm(gamma_sq, t_scalar),
        ));
        let mut gr = XofReader::new(
            "gamma-h",
            &[
                &h0,
                &(ti as u64).to_le_bytes(),
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

// --------------------------- range / rescale plumbing ----------------------

/// Pack the width-W bit decomposition of a column (values in [0, 2^W)) into
/// one packed column: slot i*len + t holds bit i of element t.
fn pack_bits(column: &[u64], width: u32) -> Vec<u64> {
    let l = column.len();
    let mut packed = vec![0u64; width as usize * l];
    for (t, &v) in column.iter().enumerate() {
        debug_assert!(v < 1u64 << width);
        for i in 0..width as usize {
            packed[i * l + t] = (v >> i) & 1;
        }
    }
    packed
}

struct ScalarLinkRep {
    gamma: u64,
    zeta_l: Vec<i64>,
    zeta_r: Vec<i64>,
}

/// Gaussian parameters for a masked-opening gadget with the given squared
/// center-norm bound and dimension multiple of N.
fn opening_gadget_params(params: &Params, center_sq: u128, dim_mult: usize) -> (u64, u128) {
    let sigma = (12 * isqrt_ceil(center_sq)) as u64;
    let bound_sq = 36
        * (sigma as u128)
        * (sigma as u128)
        * (dim_mult * params.big_n) as u128
        / 25;
    (sigma, bound_sq)
}

fn recomposition_statement_hash(
    crs: &Crs,
    ctx: &[u8],
    len: usize,
    width: u32,
    signed: bool,
    value_commits: &[Vec<u64>],
    packed_commits: &[Vec<u64>],
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"lattice-matmul-v2");
    hasher.update(b"stmt-recomposition");
    hasher.update(crs.crs_hash);
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    hasher.update((len as u64).to_le_bytes());
    hasher.update(width.to_le_bytes());
    hasher.update([signed as u8]);
    for group in [value_commits, packed_commits] {
        hasher.update((group.len() as u64).to_le_bytes());
        for c in group.iter() {
            hasher.update(words_bytes(c));
        }
    }
    hasher.finalize().into()
}

/// Recomposition link: for every column j, <s, value_j> = <w, packed_j>
/// (- the signed offset), batched over columns with fresh weights u_j into
/// one two-key Sigma-proof per repetition. Center norms: gamma * (sum_j u_j
/// rho_j) on both sides.
#[allow(clippy::too_many_arguments)]
fn prove_recomposition(
    params: &Params,
    crs: &Crs,
    ctx: &[u8],
    len: usize,
    width: u32,
    signed: bool,
    value_commits: &[Vec<u64>],
    packed_commits: &[Vec<u64>],
    rho_values: &[Vec<i8>],
    rho_packed: &[Vec<i8>],
    rng: &mut u64,
) -> Vec<ScalarLinkRep> {
    let big_n = params.big_n;
    let m = value_commits.len();
    // Center norm per side: gamma * sum_j u_j rho_j with ternary rho and
    // b-bit u, gamma: per-coordinate <= m 2^{2b}. The 2^i recomposition
    // coefficients live in the public key g_w, not in the randomness.
    let center = (1u128 << (2 * params.b)) * m as u128 * isqrt_ceil(big_n as u128);
    let (sigma_o, _bound_sq_o) =
        opening_gadget_params(params, 2 * center * center, 2);
    let h0 = recomposition_statement_hash(
        crs, ctx, len, width, signed, value_commits, packed_commits,
    );
    let base = splitmix64(rng);
    (0..params.r)
        .into_par_iter()
        .map(|ell| {
            let mut reader =
                XofReader::new("su-rec", &[&h0, &(ell as u64).to_le_bytes()]);
            let s: Vec<u64> = (0..len).map(|_| reader.next_sb(params.b)).collect();
            let u: Vec<u64> = (0..m).map(|_| reader.next_sb(params.b)).collect();
            let g_s = scalar_key_prefix(params, crs, &s);
            let wv: Vec<u64> = (0..width as usize * len)
                .map(|idx| mulm(1u64 << (idx / len), s[idx % len]))
                .collect();
            let g_w = scalar_key_prefix(params, crs, &wv);
            let rho_l = combine_ternary(rho_values, &u);
            let rho_r = combine_ternary(rho_packed, &u);
            let mut r = mix_seed(base, ell as u64);
            loop {
                let noise = gaussian_vec(&mut r, 2 * big_n, sigma_o);
                let eta_l = &noise[..big_n];
                let eta_r = &noise[big_n..];
                let w1 = matvec_signed_serial(&crs.g1, params.k, big_n, eta_l);
                let w2 = matvec_signed_serial(&crs.g1, params.k, big_n, eta_r);
                let w3 = subm(dot_signed(&g_s, eta_l), dot_signed(&g_w, eta_r));
                let mut gr = XofReader::new(
                    "gamma-rec",
                    &[
                        &h0,
                        &(ell as u64).to_le_bytes(),
                        &words_bytes(&w1),
                        &words_bytes(&w2),
                        &w3.to_le_bytes(),
                    ],
                );
                let gamma = gr.next_sb(params.b);
                let g = gamma as i64;
                let zeta_l: Vec<i64> =
                    (0..big_n).map(|j| eta_l[j] + g * rho_l[j]).collect();
                let zeta_r: Vec<i64> =
                    (0..big_n).map(|j| eta_r[j] + g * rho_r[j]).collect();
                let mut response = zeta_l.clone();
                response.extend_from_slice(&zeta_r);
                let mut center_v: Vec<i64> = rho_l.iter().map(|&x| g * x).collect();
                center_v.extend(rho_r.iter().map(|&x| g * x));
                if rejection_accept(&mut r, &response, &center_v, sigma_o) {
                    return ScalarLinkRep {
                        gamma,
                        zeta_l,
                        zeta_r,
                    };
                }
            }
        })
        .collect()
}

#[allow(clippy::too_many_arguments)]
fn verify_recomposition(
    params: &Params,
    crs: &Crs,
    ctx: &[u8],
    len: usize,
    width: u32,
    signed: bool,
    value_commits: &[Vec<u64>],
    packed_commits: &[Vec<u64>],
    proof: &[ScalarLinkRep],
) -> bool {
    let big_n = params.big_n;
    let m = value_commits.len();
    if proof.len() != params.r
        || packed_commits.len() != m
        || width as usize * len > params.msg
        || width == 0
        || width > 48
    {
        return false;
    }
    let center = (1u128 << (2 * params.b)) * m as u128 * isqrt_ceil(big_n as u128);
    let (_sigma_o, bound_sq_o) = opening_gadget_params(params, 2 * center * center, 2);
    for rep in proof {
        if rep.gamma >= (1 << params.b)
            || rep.zeta_l.len() != big_n
            || rep.zeta_r.len() != big_n
        {
            return false;
        }
        if norm_sq(&rep.zeta_l) + norm_sq(&rep.zeta_r) > bound_sq_o {
            return false;
        }
    }
    let h0 = recomposition_statement_hash(
        crs, ctx, len, width, signed, value_commits, packed_commits,
    );
    proof.par_iter().enumerate().all(|(ell, rep)| {
        let mut reader = XofReader::new("su-rec", &[&h0, &(ell as u64).to_le_bytes()]);
        let s: Vec<u64> = (0..len).map(|_| reader.next_sb(params.b)).collect();
        let u: Vec<u64> = (0..m).map(|_| reader.next_sb(params.b)).collect();
        let g_s = scalar_key_prefix(params, crs, &s);
        let wv: Vec<u64> = (0..width as usize * len)
            .map(|idx| mulm(1u64 << (idx / len), s[idx % len]))
            .collect();
        let g_w = scalar_key_prefix(params, crs, &wv);
        let t_l = combine_commit(value_commits, &u);
        let t_r = combine_commit(packed_commits, &u);
        let c_l = dot_mod(&s, &t_l[params.k..params.k + len]);
        let mut c_r = dot_mod(&wv, &t_r[params.k..params.k + width as usize * len]);
        if signed {
            // value = sum 2^i b_i - 2^{width-1}: subtract the public offset
            // 2^{width-1} (sum_t s_t)(sum_j u_j) from the packed side.
            let s_sum = s.iter().fold(0u64, |acc, &x| addm(acc, x));
            let u_sum = u.iter().fold(0u64, |acc, &x| addm(acc, x));
            let offset = mulm(1u64 << (width - 1), mulm(s_sum, u_sum));
            c_r = subm(c_r, offset);
        }
        let gamma = rep.gamma;
        let mut w1 = matvec_signed_serial(&crs.g1, params.k, big_n, &rep.zeta_l);
        let mut w2 = matvec_signed_serial(&crs.g1, params.k, big_n, &rep.zeta_r);
        for i in 0..params.k {
            w1[i] = subm(w1[i], mulm(gamma, t_l[i]));
            w2[i] = subm(w2[i], mulm(gamma, t_r[i]));
        }
        let w3 = subm(
            subm(
                dot_signed(&g_s, &rep.zeta_l),
                dot_signed(&g_w, &rep.zeta_r),
            ),
            mulm(gamma, subm(c_l, c_r)),
        );
        let mut gr = XofReader::new(
            "gamma-rec",
            &[
                &h0,
                &(ell as u64).to_le_bytes(),
                &words_bytes(&w1),
                &words_bytes(&w2),
                &w3.to_le_bytes(),
            ],
        );
        gamma == gr.next_sb(params.b)
    })
}

struct ZeroOpenRep {
    gamma: u64,
    zeta: Vec<i64>,
}

fn zero_open_statement_hash(
    crs: &Crs,
    ctx: &[u8],
    len: usize,
    shift: u32,
    tx: &[Vec<u64>],
    ty: &[Vec<u64>],
    tr: &[Vec<u64>],
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"lattice-matmul-v2");
    hasher.update(b"stmt-rescale-link");
    hasher.update(crs.crs_hash);
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    hasher.update((len as u64).to_le_bytes());
    hasher.update(shift.to_le_bytes());
    for group in [tx, ty, tr] {
        hasher.update((group.len() as u64).to_le_bytes());
        for c in group.iter() {
            hasher.update(words_bytes(c));
        }
    }
    hasher.finalize().into()
}

/// Rescale link: prove the u-combined difference sum_j u_j (T_xj - 2^shift
/// T_yj - T_rj) opens to the zero message with short combined randomness,
/// per repetition with fresh u. With the ranges on r and y this makes
/// x = 2^shift y + r hold over the integers (floor division).
#[allow(clippy::too_many_arguments)]
fn prove_rescale_link(
    params: &Params,
    crs: &Crs,
    ctx: &[u8],
    len: usize,
    shift: u32,
    tx: &[Vec<u64>],
    ty: &[Vec<u64>],
    tr: &[Vec<u64>],
    rho_x: &[Vec<i8>],
    rho_y: &[Vec<i8>],
    rho_r: &[Vec<i8>],
    rng: &mut u64,
) -> Vec<ZeroOpenRep> {
    assert!(shift <= GADGET_MAX_SHIFT);
    let big_n = params.big_n;
    let m = tx.len();
    let center = (1u128 << (2 * params.b))
        * m as u128
        * (2 + (1u128 << shift))
        * isqrt_ceil(big_n as u128);
    let (sigma_o, _bound) = opening_gadget_params(params, center * center, 1);
    let h0 = zero_open_statement_hash(crs, ctx, len, shift, tx, ty, tr);
    let base = splitmix64(rng);
    (0..params.r)
        .into_par_iter()
        .map(|ell| {
            let mut reader =
                XofReader::new("u-link", &[&h0, &(ell as u64).to_le_bytes()]);
            let u: Vec<u64> = (0..m).map(|_| reader.next_sb(params.b)).collect();
            // rho_D = sum_j u_j (rho_xj - 2^shift rho_yj - rho_rj) over Z.
            let mut rho_d = vec![0i64; big_n];
            for j in 0..m {
                let uj = u[j] as i64;
                for t in 0..big_n {
                    rho_d[t] += uj
                        * (rho_x[j][t] as i64
                            - (1i64 << shift) * rho_y[j][t] as i64
                            - rho_r[j][t] as i64);
                }
            }
            let mut r = mix_seed(base, ell as u64);
            loop {
                let eta = gaussian_vec(&mut r, big_n, sigma_o);
                let mut w = matvec_signed_serial(&crs.g1, params.k, big_n, &eta);
                let g2eta = matvec_signed_serial(&crs.g2, len, big_n, &eta);
                w.extend_from_slice(&g2eta);
                let mut gr = XofReader::new(
                    "gamma-link",
                    &[&h0, &(ell as u64).to_le_bytes(), &words_bytes(&w)],
                );
                let gamma = gr.next_sb(params.b);
                let g = gamma as i64;
                let zeta: Vec<i64> = (0..big_n).map(|j| eta[j] + g * rho_d[j]).collect();
                let center_v: Vec<i64> = rho_d.iter().map(|&x| g * x).collect();
                if rejection_accept(&mut r, &zeta, &center_v, sigma_o) {
                    return ZeroOpenRep { gamma, zeta };
                }
            }
        })
        .collect()
}

#[allow(clippy::too_many_arguments)]
fn verify_rescale_link(
    params: &Params,
    crs: &Crs,
    ctx: &[u8],
    len: usize,
    shift: u32,
    tx: &[Vec<u64>],
    ty: &[Vec<u64>],
    tr: &[Vec<u64>],
    proof: &[ZeroOpenRep],
) -> bool {
    let big_n = params.big_n;
    let m = tx.len();
    if proof.len() != params.r
        || ty.len() != m
        || tr.len() != m
        || shift > GADGET_MAX_SHIFT
        || len > params.msg
    {
        return false;
    }
    let center = (1u128 << (2 * params.b))
        * m as u128
        * (2 + (1u128 << shift))
        * isqrt_ceil(big_n as u128);
    let (_sigma_o, bound_sq_o) = opening_gadget_params(params, center * center, 1);
    for rep in proof {
        if rep.gamma >= (1 << params.b) || rep.zeta.len() != big_n {
            return false;
        }
        if norm_sq(&rep.zeta) > bound_sq_o {
            return false;
        }
    }
    let h0 = zero_open_statement_hash(crs, ctx, len, shift, tx, ty, tr);
    proof.par_iter().enumerate().all(|(ell, rep)| {
        let mut reader = XofReader::new("u-link", &[&h0, &(ell as u64).to_le_bytes()]);
        let u: Vec<u64> = (0..m).map(|_| reader.next_sb(params.b)).collect();
        // D = sum_j u_j (T_xj - 2^shift T_yj - T_rj), rows [0, k + len).
        let rows = params.k + len;
        let mut d = vec![0u64; rows];
        let two_s = 1u64 << shift;
        for j in 0..m {
            let uj = u[j];
            for t in 0..rows {
                let term = subm(subm(tx[j][t], mulm(two_s, ty[j][t])), tr[j][t]);
                d[t] = addm(d[t], mulm(uj, term));
            }
        }
        let gamma = rep.gamma;
        let mut w = matvec_signed_serial(&crs.g1, params.k, big_n, &rep.zeta);
        let g2z = matvec_signed_serial(&crs.g2, len, big_n, &rep.zeta);
        w.extend_from_slice(&g2z);
        for t in 0..rows {
            w[t] = subm(w[t], mulm(gamma, d[t]));
        }
        let mut gr = XofReader::new(
            "gamma-link",
            &[&h0, &(ell as u64).to_le_bytes(), &words_bytes(&w)],
        );
        gamma == gr.next_sb(params.b)
    })
}

// ---------------------------------------------------------------------------
// Instance generation, self-test, benchmarks.

/// C = A B for A rows x inner (flat row-major) and B given as columns of
/// length inner; C returned as columns of length rows.
fn matmul_mod_gemm(a: &[u64], b_cols: &[Vec<u64>], rows: usize, inner: usize) -> Vec<Vec<u64>> {
    b_cols
        .par_iter()
        .map(|col| {
            (0..rows)
                .map(|i| {
                    let mut acc: u128 = 0;
                    let base = i * inner;
                    for t in 0..inner {
                        acc += mulm(a[base + t], col[t]) as u128;
                    }
                    (acc % Q as u128) as u64
                })
                .collect()
        })
        .collect()
}

struct Instance {
    a_flat: Vec<u64>,      // rows x inner row-major
    a_rows: Vec<Vec<u64>>, // for Pi2 row commitments
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

fn make_instance(
    params: &Params,
    crs: &Crs,
    shape: &Shape,
    seed: u64,
    valid: bool,
    with_a_commit: bool,
) -> Instance {
    let mut rng = seed;
    let a_flat: Vec<u64> = (0..shape.rows * shape.inner)
        .map(|_| rng_small(&mut rng, 64))
        .collect();
    let b_cols: Vec<Vec<u64>> = (0..shape.cols)
        .map(|_| (0..shape.inner).map(|_| rng_small(&mut rng, 64)).collect())
        .collect();
    let start = Instant::now();
    let mut c_cols = matmul_mod_gemm(&a_flat, &b_cols, shape.rows, shape.inner);
    let matmul_s = start.elapsed().as_secs_f64();
    if !valid {
        c_cols[0][0] = addm(c_cols[0][0], 1);
    }
    let a_rows: Vec<Vec<u64>> = (0..shape.rows)
        .map(|i| a_flat[i * shape.inner..(i + 1) * shape.inner].to_vec())
        .collect();
    let rho_a: Vec<Vec<i8>> = (0..shape.rows)
        .map(|_| rng_ternary(&mut rng, params.big_n))
        .collect();
    let rho_b: Vec<Vec<i8>> = (0..shape.cols)
        .map(|_| rng_ternary(&mut rng, params.big_n))
        .collect();
    let tau_c: Vec<Vec<i8>> = (0..shape.cols)
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

fn run_case(proto: Protocol, shape: Shape, seed: u64, valid: bool) -> bool {
    let params = derive_params_multi(proto, &[shape], None);
    let crs = expand_crs(&params, 0xC0FFEE);
    let with_a = matches!(proto, Protocol::Pi2);
    let inst = make_instance(&params, &crs, &shape, seed, valid, with_a);
    let mut rng = seed ^ 0x5151_5151;
    match proto {
        Protocol::Pi1 => {
            let proof = prove_pi1(
                &params, &crs, &shape, b"", &inst.a_flat, &inst.b_cols, &inst.rho_b,
                &inst.tau_c, &inst.tb, &inst.tc, &mut rng,
            );
            verify_pi1(&params, &crs, &shape, b"", &inst.a_flat, &inst.tb, &inst.tc, &proof)
        }
        Protocol::Pi2 => {
            let proof = prove_pi2(
                &params, &crs, &shape, b"", &inst.a_rows, &inst.rho_a, &inst.b_cols,
                &inst.rho_b, &inst.tau_c, &inst.ta, &inst.tb, &inst.tc, &mut rng,
            );
            verify_pi2(&params, &crs, &shape, b"", &inst.ta, &inst.tb, &inst.tc, &proof)
        }
    }
}

fn square(n: usize) -> Shape {
    Shape {
        rows: n,
        inner: n,
        cols: n,
    }
}

fn self_test() {
    let shapes = [
        square(16), // square regression shape
        Shape {
            rows: 16,
            inner: 32,
            cols: 8,
        },
        Shape {
            rows: 8,
            inner: 16,
            cols: 64,
        },
    ];
    for (proto, name) in [(Protocol::Pi1, "pi1"), (Protocol::Pi2, "pi2")] {
        for shape in shapes {
            let tag = 1000 + shape.rows as u64 + 3 * shape.inner as u64 + 7 * shape.cols as u64;
            assert!(
                run_case(proto, shape, tag, true),
                "{name} {shape:?} valid"
            );
            assert!(
                !run_case(proto, shape, 1000 + tag, false),
                "{name} {shape:?} invalid"
            );
        }
    }
    transpose_self_test();
    gadget_self_test();
    println!("lattice-matmul self-test ok");
}

/// M2 gadget checks: Hadamard/binary valid + tampered, packed range
/// recomposition valid + non-binary bit + out-of-range remainder, rescale
/// link valid + wrong shift + wrong quotient, norm overflows, swapped
/// commitments (adversarial reordering after the statement is fixed).
fn gadget_self_test() {
    let l = 8usize; // column length
    let m = 4usize; // columns
    let width = 4u32;
    let shift = 4u32;
    let shape = Shape { rows: l, inner: l, cols: m };
    let params = derive_params_gadget(
        Protocol::Pi2,
        &[shape],
        None,
        (width.max(shift) as usize) * l,
    );
    assert!(width as usize * l <= params.msg, "packed columns must fit msg");
    let crs = expand_crs(&params, 0xC0FFEE);
    let mut rng = 0x6AD6E7_u64;
    let mut commit_cols = |cols: &[Vec<u64>], rng: &mut u64| {
        let rhos: Vec<Vec<i8>> = (0..cols.len())
            .map(|_| rng_ternary(rng, params.big_n))
            .collect();
        let commits = commit_columns_fast(&params, &crs, cols, &rhos);
        (commits, rhos)
    };

    // --- Hadamard: z = x o y over m columns.
    let x_cols: Vec<Vec<u64>> = (0..m)
        .map(|_| (0..l).map(|_| rng_small(&mut rng, 1 << 8)).collect())
        .collect();
    let y_cols: Vec<Vec<u64>> = (0..m)
        .map(|_| (0..l).map(|_| rng_small(&mut rng, 1 << 8)).collect())
        .collect();
    let z_cols: Vec<Vec<u64>> = (0..m)
        .map(|j| (0..l).map(|t| mulm(x_cols[j][t], y_cols[j][t])).collect())
        .collect();
    let (tx, rho_x) = commit_cols(&x_cols, &mut rng);
    let (ty, rho_y) = commit_cols(&y_cols, &mut rng);
    let (tz, rho_z) = commit_cols(&z_cols, &mut rng);
    let stmts: Vec<HadamardStatement> = (0..m)
        .map(|j| HadamardStatement {
            len: l,
            tx: &tx[j],
            ty: &ty[j],
            tz: &tz[j],
        })
        .collect();
    let wits: Vec<HadamardWitness> = (0..m)
        .map(|j| HadamardWitness {
            x: &x_cols[j],
            y: &y_cols[j],
            rho_x: &rho_x[j],
            rho_y: &rho_y[j],
            rho_z: &rho_z[j],
        })
        .collect();
    let mut prng = 0x4AD_u64;
    let proof = prove_hadamard(&params, &crs, b"st", &stmts, &wits, &mut prng);
    assert!(
        verify_hadamard(&params, &crs, b"st", &stmts, &proof),
        "hadamard valid"
    );
    // Wrong product at one position: honest prover, false statement.
    let mut z_bad = z_cols.clone();
    z_bad[1][2] = addm(z_bad[1][2], 1);
    let (tz_bad, rho_z_bad) = commit_cols(&z_bad, &mut rng);
    let stmts_bad: Vec<HadamardStatement> = (0..m)
        .map(|j| HadamardStatement {
            len: l,
            tx: &tx[j],
            ty: &ty[j],
            tz: &tz_bad[j],
        })
        .collect();
    let wits_bad: Vec<HadamardWitness> = (0..m)
        .map(|j| HadamardWitness {
            x: &x_cols[j],
            y: &y_cols[j],
            rho_x: &rho_x[j],
            rho_y: &rho_y[j],
            rho_z: &rho_z_bad[j],
        })
        .collect();
    let mut prng2 = 0xBAD1_u64;
    let bad_proof = prove_hadamard(&params, &crs, b"st", &stmts_bad, &wits_bad, &mut prng2);
    assert!(
        !verify_hadamard(&params, &crs, b"st", &stmts_bad, &bad_proof),
        "hadamard wrong product must fail"
    );
    // Tampered response and +q norm overflow.
    let mut tampered: Vec<Vec<HadamardRep>> = proof
        .iter()
        .map(|reps| reps.iter().map(clone_hrep).collect())
        .collect();
    tampered[0][0].zeta_q[0] += 1;
    assert!(
        !verify_hadamard(&params, &crs, b"st", &stmts, &tampered),
        "hadamard tampered zeta must fail"
    );
    let mut oversized: Vec<Vec<HadamardRep>> = proof
        .iter()
        .map(|reps| reps.iter().map(clone_hrep).collect())
        .collect();
    oversized[0][0].zeta_a[0] += Q as i64;
    assert!(
        !verify_hadamard(&params, &crs, b"st", &stmts, &oversized),
        "hadamard norm overflow must fail"
    );
    // Context separation: same proof under a different manifest digest.
    assert!(
        !verify_hadamard(&params, &crs, b"other", &stmts, &proof),
        "hadamard context swap must fail"
    );

    // --- Rescale + range family: x = 2^shift y + r, both r and y ranged.
    let xr_cols: Vec<Vec<u64>> = (0..m)
        .map(|_| (0..l).map(|_| rng_small(&mut rng, 1 << (width + shift))).collect())
        .collect();
    let yq_cols: Vec<Vec<u64>> = xr_cols
        .iter()
        .map(|col| col.iter().map(|&v| v >> shift).collect())
        .collect();
    let rr_cols: Vec<Vec<u64>> = xr_cols
        .iter()
        .map(|col| col.iter().map(|&v| v & ((1 << shift) - 1)).collect())
        .collect();
    let p_r: Vec<Vec<u64>> = rr_cols.iter().map(|c| pack_bits(c, shift)).collect();
    let p_y: Vec<Vec<u64>> = yq_cols.iter().map(|c| pack_bits(c, width)).collect();
    let (txr, rho_xr) = commit_cols(&xr_cols, &mut rng);
    let (tyq, rho_yq) = commit_cols(&yq_cols, &mut rng);
    let (trr, rho_rr) = commit_cols(&rr_cols, &mut rng);
    let (tpr, rho_pr) = commit_cols(&p_r, &mut rng);
    let (tpy, rho_py) = commit_cols(&p_y, &mut rng);
    // Binary constraints on both packed matrices (x = y = z = packed).
    let bin_stmts: Vec<HadamardStatement> = tpr
        .iter()
        .map(|t| HadamardStatement {
            len: shift as usize * l,
            tx: t,
            ty: t,
            tz: t,
        })
        .chain(tpy.iter().map(|t| HadamardStatement {
            len: width as usize * l,
            tx: t,
            ty: t,
            tz: t,
        }))
        .collect();
    let bin_wits: Vec<HadamardWitness> = (0..m)
        .map(|j| HadamardWitness {
            x: &p_r[j],
            y: &p_r[j],
            rho_x: &rho_pr[j],
            rho_y: &rho_pr[j],
            rho_z: &rho_pr[j],
        })
        .chain((0..m).map(|j| HadamardWitness {
            x: &p_y[j],
            y: &p_y[j],
            rho_x: &rho_py[j],
            rho_y: &rho_py[j],
            rho_z: &rho_py[j],
        }))
        .collect();
    let mut prng3 = 0xB19A_u64;
    let bin_proof = prove_hadamard(&params, &crs, b"bin", &bin_stmts, &bin_wits, &mut prng3);
    assert!(
        verify_hadamard(&params, &crs, b"bin", &bin_stmts, &bin_proof),
        "binary valid"
    );
    // Non-binary bit: a 2 in one packed slot (recommit honestly).
    let mut p_bad = p_r.clone();
    p_bad[0][0] = 2;
    let (tp_bad, rho_p_bad) = commit_cols(&p_bad, &mut rng);
    let bad_stmt = [HadamardStatement {
        len: shift as usize * l,
        tx: &tp_bad[0],
        ty: &tp_bad[0],
        tz: &tp_bad[0],
    }];
    let bad_wit = [HadamardWitness {
        x: &p_bad[0],
        y: &p_bad[0],
        rho_x: &rho_p_bad[0],
        rho_y: &rho_p_bad[0],
        rho_z: &rho_p_bad[0],
    }];
    let mut prng4 = 0xB19B_u64;
    let nb = prove_hadamard(&params, &crs, b"bin", &bad_stmt, &bad_wit, &mut prng4);
    assert!(
        !verify_hadamard(&params, &crs, b"bin", &bad_stmt, &nb),
        "non-binary bit must fail"
    );
    // Recomposition links, r side then y side.
    let mut prng5 = 0x2EC0_u64;
    let rec_r = prove_recomposition(
        &params, &crs, b"rec-r", l, shift, false, &trr, &tpr, &rho_rr, &rho_pr,
        &mut prng5,
    );
    assert!(
        verify_recomposition(&params, &crs, b"rec-r", l, shift, false, &trr, &tpr, &rec_r),
        "recomposition r valid"
    );
    let rec_y = prove_recomposition(
        &params, &crs, b"rec-y", l, width, false, &tyq, &tpy, &rho_yq, &rho_py,
        &mut prng5,
    );
    assert!(
        verify_recomposition(&params, &crs, b"rec-y", l, width, false, &tyq, &tpy, &rec_y),
        "recomposition y valid"
    );
    // Out-of-range remainder: r' = r + 2^shift at one slot, y' = y - 1
    // keeps the linear relation but r' cannot recompose from shift bits.
    let mut r_oob = rr_cols.clone();
    r_oob[0][0] += 1 << shift;
    let (tr_oob, rho_r_oob) = commit_cols(&r_oob, &mut rng);
    let mut prng6 = 0x2EC1_u64;
    let rec_oob = prove_recomposition(
        &params, &crs, b"rec-r", l, shift, false, &tr_oob, &tpr, &rho_r_oob, &rho_pr,
        &mut prng6,
    );
    assert!(
        !verify_recomposition(
            &params, &crs, b"rec-r", l, shift, false, &tr_oob, &tpr, &rec_oob
        ),
        "out-of-range remainder must fail recomposition"
    );
    // Rescale link: valid, then wrong shift, then wrong quotient.
    let mut prng7 = 0x11FF_u64;
    let link = prove_rescale_link(
        &params, &crs, b"lnk", l, shift, &txr, &tyq, &trr, &rho_xr, &rho_yq, &rho_rr,
        &mut prng7,
    );
    assert!(
        verify_rescale_link(&params, &crs, b"lnk", l, shift, &txr, &tyq, &trr, &link),
        "rescale link valid"
    );
    assert!(
        !verify_rescale_link(&params, &crs, b"lnk", l, shift - 1, &txr, &tyq, &trr, &link),
        "wrong shift must fail"
    );
    let mut y_bad = yq_cols.clone();
    y_bad[0][0] = addm(y_bad[0][0], 1);
    let (ty_bad, rho_y_bad) = commit_cols(&y_bad, &mut rng);
    let mut prng8 = 0x11FE_u64;
    let bad_link = prove_rescale_link(
        &params, &crs, b"lnk", l, shift, &txr, &ty_bad, &trr, &rho_xr, &rho_y_bad,
        &rho_rr, &mut prng8,
    );
    assert!(
        !verify_rescale_link(&params, &crs, b"lnk", l, shift, &txr, &ty_bad, &trr, &bad_link),
        "wrong quotient must fail rescale link"
    );
    // Swapped commitments after the statement was fixed.
    let mut swapped = trr.clone();
    swapped.swap(0, 1);
    assert!(
        !verify_recomposition(&params, &crs, b"rec-r", l, shift, false, &swapped, &tpr, &rec_r),
        "swapped commitments must fail"
    );
}

/// Stand-alone transpose gadget check: valid case, mismatched matrix,
/// tampered response, out-of-range norm.
fn transpose_self_test() {
    let n_r = 8usize;
    let n_c = 16usize;
    let shape = Shape {
        rows: n_r,
        inner: 16,
        cols: n_c,
    };
    let params = derive_params_multi(Protocol::Pi2, &[shape], Some((n_r, n_c)));
    let crs = expand_crs(&params, 0xC0FFEE);
    let mut rng = 0xF00D_u64;
    // Y as rows and columns.
    let y_rows: Vec<Vec<u64>> = (0..n_r)
        .map(|_| (0..n_c).map(|_| rng_small(&mut rng, 64)).collect())
        .collect();
    let y_cols: Vec<Vec<u64>> = (0..n_c)
        .map(|j| (0..n_r).map(|i| y_rows[i][j]).collect())
        .collect();
    let rho_rows: Vec<Vec<i8>> = (0..n_r).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let tau_cols: Vec<Vec<i8>> = (0..n_c).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let trow = commit_columns_fast(&params, &crs, &y_rows, &rho_rows);
    let tcol = commit_columns_fast(&params, &crs, &y_cols, &tau_cols);
    let mut prng = 0xB0BA_u64;
    let proof = prove_transpose(
        &params, &crs, n_r, n_c, b"", &trow, &tcol, &rho_rows, &tau_cols, &mut prng,
    );
    assert!(
        verify_transpose(&params, &crs, n_r, n_c, b"", &trow, &tcol, &proof),
        "transpose valid"
    );
    // Mismatched matrix: rows of Y' != Y.
    let mut y2_rows = y_rows.clone();
    y2_rows[0][0] = addm(y2_rows[0][0], 1);
    let trow2 = commit_columns_fast(&params, &crs, &y2_rows, &rho_rows);
    let mut prng2 = 0xB0BB_u64;
    let bad = prove_transpose(
        &params, &crs, n_r, n_c, b"", &trow2, &tcol, &rho_rows, &tau_cols, &mut prng2,
    );
    assert!(
        !verify_transpose(&params, &crs, n_r, n_c, b"", &trow2, &tcol, &bad),
        "transpose mismatch must fail"
    );
    // Tampered response.
    let mut tampered: Vec<TransposeRep> = proof
        .iter()
        .map(|rep| TransposeRep {
            gamma: rep.gamma,
            zeta_v: rep.zeta_v.clone(),
            zeta_s: rep.zeta_s.clone(),
        })
        .collect();
    tampered[0].zeta_v[0] += 1;
    assert!(
        !verify_transpose(&params, &crs, n_r, n_c, b"", &trow, &tcol, &tampered),
        "transpose tampered response must fail"
    );
    // Out-of-range norm: adding q leaves every mod-q check unchanged, so
    // only the norm check can catch it.
    let mut oversized: Vec<TransposeRep> = proof
        .iter()
        .map(|rep| TransposeRep {
            gamma: rep.gamma,
            zeta_v: rep.zeta_v.clone(),
            zeta_s: rep.zeta_s.clone(),
        })
        .collect();
    oversized[0].zeta_v[0] += Q as i64;
    assert!(
        !verify_transpose(&params, &crs, n_r, n_c, b"", &trow, &tcol, &oversized),
        "transpose norm overflow must fail"
    );
    // Swapped column commitments (adversarial reordering after the
    // statement was fixed) must fail.
    let mut swapped_cols = tcol.clone();
    swapped_cols.swap(0, 1);
    assert!(
        !verify_transpose(&params, &crs, n_r, n_c, b"", &trow, &swapped_cols, &proof),
        "transpose commitment swap must fail"
    );
}

// ---------------------------------------------------------------------------
// Chained-inference demo (M1): Z = (X W1) W2 with Y = X W1 shared between
// the two claims through dual-orientation commitments plus the
// transpose-consistency gadget. All Fiat-Shamir challenges bind the claim
// manifest digest, which covers every commitment in the DAG.

#[allow(clippy::too_many_arguments)]
fn chain_demo(n0: usize, n1: usize, n2: usize, n3: usize) {
    println!(
        "lattice chain-demo: X {n0}x{n1}, W1 {n1}x{n2}, W2 {n2}x{n3} (Pi2 track)"
    );
    let s1 = Shape {
        rows: n0,
        inner: n1,
        cols: n2,
    };
    let s2 = Shape {
        rows: n0,
        inner: n2,
        cols: n3,
    };
    let start = Instant::now();
    let params = derive_params_multi(Protocol::Pi2, &[s1, s2], Some((n0, n2)));
    let crs = expand_crs(&params, 0xC0FFEE);
    println!(
        "  params: msg={} k={} N={} sigma_t=2^{:.1}, crs {:.3}s",
        params.msg,
        params.k,
        params.big_n,
        (params.sigma_t as f64).log2(),
        start.elapsed().as_secs_f64()
    );

    // Witnesses.
    let mut rng = 0xC4A1_u64;
    let x_rows: Vec<Vec<u64>> = (0..n0)
        .map(|_| (0..n1).map(|_| rng_small(&mut rng, 64)).collect())
        .collect();
    let w1_cols: Vec<Vec<u64>> = (0..n2)
        .map(|_| (0..n1).map(|_| rng_small(&mut rng, 64)).collect())
        .collect();
    let w2_cols: Vec<Vec<u64>> = (0..n3)
        .map(|_| (0..n2).map(|_| rng_small(&mut rng, 64)).collect())
        .collect();
    // Y = X W1 in both orientations; Z = Y W2 by columns.
    let y_cols: Vec<Vec<u64>> = w1_cols
        .iter()
        .map(|col| {
            (0..n0)
                .map(|i| dot_mod(&x_rows[i], col))
                .collect()
        })
        .collect();
    let y_rows: Vec<Vec<u64>> = (0..n0)
        .map(|i| (0..n2).map(|j| y_cols[j][i]).collect())
        .collect();
    let z_cols: Vec<Vec<u64>> = w2_cols
        .iter()
        .map(|col| (0..n0).map(|i| dot_mod(&y_rows[i], col)).collect())
        .collect();

    // Commitments (X by rows, weights and outputs by columns, Y in both
    // orientations).
    let start = Instant::now();
    let rho_x: Vec<Vec<i8>> = (0..n0).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let rho_w1: Vec<Vec<i8>> = (0..n2).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let tau_yc: Vec<Vec<i8>> = (0..n2).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let rho_yr: Vec<Vec<i8>> = (0..n0).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let rho_w2: Vec<Vec<i8>> = (0..n3).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let tau_z: Vec<Vec<i8>> = (0..n3).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let tx = commit_columns_fast(&params, &crs, &x_rows, &rho_x);
    let tw1 = commit_columns_fast(&params, &crs, &w1_cols, &rho_w1);
    let tyc = commit_columns_fast(&params, &crs, &y_cols, &tau_yc);
    let tyr = commit_columns_fast(&params, &crs, &y_rows, &rho_yr);
    let tw2 = commit_columns_fast(&params, &crs, &w2_cols, &rho_w2);
    let tz = commit_columns_fast(&params, &crs, &z_cols, &tau_z);
    println!("  commit: {:.3}s", start.elapsed().as_secs_f64());

    // Claim manifest: every commitment enters the statement hash before any
    // challenge is derived.
    let build_manifest = |tyr_group: &[Vec<u64>], tz_group: &[Vec<u64>]| -> ClaimManifest {
        let mut m = ClaimManifest::new("lattice-route-z-pi2", &crs.crs_hash);
        let id_x = m.add_commitment(
            "X",
            n0,
            n1,
            Orientation::ByRows,
            (params.msg as u64).to_le_bytes().to_vec(),
            commitment_group_digest(&tx),
        );
        let id_w1 = m.add_commitment(
            "W1",
            n1,
            n2,
            Orientation::ByColumns,
            (params.msg as u64).to_le_bytes().to_vec(),
            commitment_group_digest(&tw1),
        );
        let id_yc = m.add_commitment(
            "Y",
            n0,
            n2,
            Orientation::ByColumns,
            (params.msg as u64).to_le_bytes().to_vec(),
            commitment_group_digest(&tyc),
        );
        let id_yr = m.add_commitment(
            "Y",
            n0,
            n2,
            Orientation::ByRows,
            (params.msg as u64).to_le_bytes().to_vec(),
            commitment_group_digest(tyr_group),
        );
        let id_w2 = m.add_commitment(
            "W2",
            n2,
            n3,
            Orientation::ByColumns,
            (params.msg as u64).to_le_bytes().to_vec(),
            commitment_group_digest(&tw2),
        );
        let id_z = m.add_commitment(
            "Z",
            n0,
            n3,
            Orientation::ByColumns,
            (params.msg as u64).to_le_bytes().to_vec(),
            commitment_group_digest(tz_group),
        );
        m.add_operation(Operation::Matmul {
            a: id_x,
            b: id_w1,
            c: id_yc,
        });
        m.add_operation(Operation::LinkTranspose {
            by_rows: id_yr,
            by_cols: id_yc,
        });
        m.add_operation(Operation::Matmul {
            a: id_yr,
            b: id_w2,
            c: id_z,
        });
        m
    };
    let manifest = build_manifest(&tyr, &tz);
    let ctx = manifest.digest();

    // Prove the chain.
    let start = Instant::now();
    let mut prng = 0xB01D_u64;
    let proof1 = prove_pi2(
        &params, &crs, &s1, &ctx, &x_rows, &rho_x, &w1_cols, &rho_w1, &tau_yc,
        &tx, &tw1, &tyc, &mut prng,
    );
    let proof2 = prove_pi2(
        &params, &crs, &s2, &ctx, &y_rows, &rho_yr, &w2_cols, &rho_w2, &tau_z,
        &tyr, &tw2, &tz, &mut prng,
    );
    let link = prove_transpose(
        &params, &crs, n0, n2, &ctx, &tyr, &tyc, &rho_yr, &tau_yc, &mut prng,
    );
    println!("  prove (2 claims + link): {:.3}s", start.elapsed().as_secs_f64());

    // Verify the chain: the verifier re-derives the manifest digest from
    // the commitments it was given and never re-commits any matrix.
    let start = Instant::now();
    let ok1 = verify_pi2(&params, &crs, &s1, &ctx, &tx, &tw1, &tyc, &proof1);
    let ok2 = verify_pi2(&params, &crs, &s2, &ctx, &tyr, &tw2, &tz, &proof2);
    let okl = verify_transpose(&params, &crs, n0, n2, &ctx, &tyr, &tyc, &link);
    println!(
        "  verify: {:.3}s (claim1={ok1} claim2={ok2} link={okl})",
        start.elapsed().as_secs_f64()
    );
    assert!(ok1 && ok2 && okl, "honest chain must verify");

    // Negative case 1: substitute a different Y in the second claim. Both
    // matmul claims verify against their own commitments; the transpose
    // link must reject the chain.
    let mut y2_rows = y_rows.clone();
    y2_rows[0][0] = addm(y2_rows[0][0], 1);
    let z2_cols: Vec<Vec<u64>> = w2_cols
        .iter()
        .map(|col| (0..n0).map(|i| dot_mod(&y2_rows[i], col)).collect())
        .collect();
    let tyr2 = commit_columns_fast(&params, &crs, &y2_rows, &rho_yr);
    let tz2 = commit_columns_fast(&params, &crs, &z2_cols, &tau_z);
    let manifest2 = build_manifest(&tyr2, &tz2);
    let ctx2 = manifest2.digest();
    let proof1b = prove_pi2(
        &params, &crs, &s1, &ctx2, &x_rows, &rho_x, &w1_cols, &rho_w1, &tau_yc,
        &tx, &tw1, &tyc, &mut prng,
    );
    let proof2b = prove_pi2(
        &params, &crs, &s2, &ctx2, &y2_rows, &rho_yr, &w2_cols, &rho_w2, &tau_z,
        &tyr2, &tw2, &tz2, &mut prng,
    );
    let link_bad = prove_transpose(
        &params, &crs, n0, n2, &ctx2, &tyr2, &tyc, &rho_yr, &tau_yc, &mut prng,
    );
    let ok1b = verify_pi2(&params, &crs, &s1, &ctx2, &tx, &tw1, &tyc, &proof1b);
    let ok2b = verify_pi2(&params, &crs, &s2, &ctx2, &tyr2, &tw2, &tz2, &proof2b);
    let oklb = verify_transpose(&params, &crs, n0, n2, &ctx2, &tyr2, &tyc, &link_bad);
    assert!(ok1b, "substituted-Y chain: claim 1 verifies standalone");
    assert!(ok2b, "substituted-Y chain: claim 2 verifies standalone");
    assert!(!oklb, "substituted-Y chain: transpose link must fail");
    println!("  negative wrong-Y: claims pass standalone, link fails as required");

    // Negative case 2: tampered link response.
    let mut tampered: Vec<TransposeRep> = link
        .iter()
        .map(|rep| TransposeRep {
            gamma: rep.gamma,
            zeta_v: rep.zeta_v.clone(),
            zeta_s: rep.zeta_s.clone(),
        })
        .collect();
    tampered[0].zeta_s[0] += 1;
    assert!(
        !verify_transpose(&params, &crs, n0, n2, &ctx, &tyr, &tyc, &tampered),
        "tampered link response must fail"
    );

    // Negative case 3: swapped commitments handed to the link verifier.
    assert!(
        !verify_transpose(&params, &crs, n0, n2, &ctx, &tyr, &tx, &link),
        "wrong commitment group in link must fail"
    );

    // Negative case 4: out-of-range norm (mod-q checks unchanged).
    let mut oversized: Vec<TransposeRep> = link
        .iter()
        .map(|rep| TransposeRep {
            gamma: rep.gamma,
            zeta_v: rep.zeta_v.clone(),
            zeta_s: rep.zeta_s.clone(),
        })
        .collect();
    oversized[0].zeta_v[0] += Q as i64;
    assert!(
        !verify_transpose(&params, &crs, n0, n2, &ctx, &tyr, &tyc, &oversized),
        "oversized link response must fail"
    );

    // Negative case 5: manifest reordering. A manifest with the same
    // commitments in a different order yields a different context digest,
    // so proofs made for the honest ordering must fail against it.
    let mut reordered = manifest.clone();
    reordered.commitments.swap(0, 1);
    let ctx_reordered = reordered.digest();
    assert_ne!(ctx, ctx_reordered, "reordered manifest digest must differ");
    assert!(
        !verify_pi2(
            &params,
            &crs,
            &s1,
            &ctx_reordered,
            &tx,
            &tw1,
            &tyc,
            &proof1
        ),
        "claim proof must not verify under a reordered manifest"
    );
    println!("lattice chain-demo ok");
}

fn bench(proto: Protocol, name: &str, n: usize) {
    bench_shape(proto, name, square(n), &n.to_string());
}

fn bench_shape(proto: Protocol, name: &str, shape: Shape, dim_label: &str) {
    let params = derive_params_multi(proto, &[shape], None);
    let n = dim_label;
    let seed_dim = shape.rows as u64 + 3 * shape.inner as u64 + 7 * shape.cols as u64;
    let start = Instant::now();
    let crs = expand_crs(&params, 0xC0FFEE);
    let crs_s = start.elapsed().as_secs_f64();
    let with_a = matches!(proto, Protocol::Pi2);
    let inst = make_instance(&params, &crs, &shape, 0xBEEF + seed_dim, true, with_a);
    let mut rng = 0xABCD ^ seed_dim;
    let (prove_s, verify_s, verified) = match proto {
        Protocol::Pi1 => {
            let start = Instant::now();
            let proof = prove_pi1(
                &params, &crs, &shape, b"", &inst.a_flat, &inst.b_cols, &inst.rho_b,
                &inst.tau_c, &inst.tb, &inst.tc, &mut rng,
            );
            let prove_s = start.elapsed().as_secs_f64();
            let start = Instant::now();
            let ok = verify_pi1(
                &params, &crs, &shape, b"", &inst.a_flat, &inst.tb, &inst.tc, &proof,
            );
            (prove_s, start.elapsed().as_secs_f64(), ok)
        }
        Protocol::Pi2 => {
            let start = Instant::now();
            let proof = prove_pi2(
                &params, &crs, &shape, b"", &inst.a_rows, &inst.rho_a, &inst.b_cols,
                &inst.rho_b, &inst.tau_c, &inst.ta, &inst.tb, &inst.tc, &mut rng,
            );
            let prove_s = start.elapsed().as_secs_f64();
            let start = Instant::now();
            let ok = verify_pi2(
                &params, &crs, &shape, b"", &inst.ta, &inst.tb, &inst.tc, &proof,
            );
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
    let shape = square(n);
    let start = Instant::now();
    let crs = expand_crs(&params, 0xC0FFEE);
    let crs_s = start.elapsed().as_secs_f64();
    let with_a = matches!(proto, Protocol::Pi2);
    let max_batch = *batches.iter().max().unwrap();
    let instances: Vec<Instance> = (0..max_batch)
        .map(|i| make_instance(&params, &crs, &shape, 0xCAFE + 31 * i as u64, true, with_a))
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
                    &params, &crs, &shape, b"", &inst.a_flat, &inst.b_cols, &inst.rho_b,
                    &inst.tau_c, &inst.tb, &inst.tc, &mut rng,
                )),
                Protocol::Pi2 => proofs2.push(prove_pi2(
                    &params, &crs, &shape, b"", &inst.a_rows, &inst.rho_a, &inst.b_cols,
                    &inst.rho_b, &inst.tau_c, &inst.ta, &inst.tb, &inst.tc, &mut rng,
                )),
            }
        }
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        for (i, inst) in instances[..t].iter().enumerate() {
            let ok = match proto {
                Protocol::Pi1 => verify_pi1(
                    &params, &crs, &shape, b"", &inst.a_flat, &inst.tb, &inst.tc,
                    &proofs1[i],
                ),
                Protocol::Pi2 => verify_pi2(
                    &params, &crs, &shape, b"", &inst.ta, &inst.tb, &inst.tc, &proofs2[i],
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

/// M2 exit-criterion demo: prove Y = X W (Pi2), then rescale Y by 2^shift
/// with remainder and range-prove both r (width = shift) and y' (declared
/// width), measuring the rescale+range family's prover cost against the
/// matmul claim it post-processes.
fn gadget_demo(rows: usize, inner: usize, cols: usize, shift: u32, width: u32) {
    println!(
        "lattice gadget-demo: X {rows}x{inner}, W {inner}x{cols}, rescale shift={shift}, quotient width={width}"
    );
    let shape = Shape { rows, inner, cols };
    let min_msg = (width.max(shift) as usize) * rows;
    let params = derive_params_gadget(Protocol::Pi2, &[shape], None, min_msg);
    let start = Instant::now();
    let crs = expand_crs(&params, 0xC0FFEE);
    println!(
        "  params: msg={} k={} N={} sigma_h=2^{:.1}, crs {:.3}s",
        params.msg,
        params.k,
        params.big_n,
        (params.sigma_h as f64).log2(),
        start.elapsed().as_secs_f64()
    );
    let inst = make_instance(&params, &crs, &shape, 0xDE110, true, true);
    // Manifest over every commitment before any challenge.
    let mut mf = manifest::ClaimManifest::new("lattice-route-z", &crs.crs_hash);
    let digest_of = |group: &[Vec<u64>]| -> Vec<u8> {
        let mut hasher = Sha256::new();
        for c in group {
            hasher.update(words_bytes(c));
        }
        hasher.finalize().to_vec()
    };
    // Y = X W columns, then the rescale witnesses.
    let y_cols = matmul_mod_gemm(&inst.a_flat, &inst.b_cols, rows, inner);
    let yq_cols: Vec<Vec<u64>> = y_cols
        .iter()
        .map(|c| c.iter().map(|&v| v >> shift).collect())
        .collect();
    let rr_cols: Vec<Vec<u64>> = y_cols
        .iter()
        .map(|c| c.iter().map(|&v| v & ((1u64 << shift) - 1)).collect())
        .collect();
    // Demo guard: quotients must fit the declared width (they do for the
    // 6-bit inputs of make_instance as long as width is large enough).
    assert!(yq_cols.iter().flatten().all(|&v| v < 1u64 << width));
    let p_r: Vec<Vec<u64>> = rr_cols.iter().map(|c| pack_bits(c, shift)).collect();
    let p_y: Vec<Vec<u64>> = yq_cols.iter().map(|c| pack_bits(c, width)).collect();
    let mut rng = 0xDE111_u64;
    let start = Instant::now();
    let mut commit_group = |cols: &[Vec<u64>], rng: &mut u64| {
        let rhos: Vec<Vec<i8>> = (0..cols.len())
            .map(|_| rng_ternary(rng, params.big_n))
            .collect();
        let commits = commit_columns_fast(&params, &crs, cols, &rhos);
        (commits, rhos)
    };
    let (tyq, rho_yq) = commit_group(&yq_cols, &mut rng);
    let (trr, rho_rr) = commit_group(&rr_cols, &mut rng);
    let (tpr, rho_pr) = commit_group(&p_r, &mut rng);
    let (tpy, rho_py) = commit_group(&p_y, &mut rng);
    let gadget_commit_s = start.elapsed().as_secs_f64();
    let ida = mf.add_commitment("X", rows, inner, manifest::Orientation::ByRows, vec![], digest_of(&inst.ta));
    let idb = mf.add_commitment("W", inner, cols, manifest::Orientation::ByColumns, vec![], digest_of(&inst.tb));
    let idy = mf.add_commitment("Y", rows, cols, manifest::Orientation::ByColumns, vec![], digest_of(&inst.tc));
    let idyq = mf.add_commitment("Yq", rows, cols, manifest::Orientation::ByColumns, vec![], digest_of(&tyq));
    let idr = mf.add_commitment("R", rows, cols, manifest::Orientation::ByColumns, vec![], digest_of(&trr));
    let idpr = mf.add_commitment("R-bits", shift as usize * rows, cols, manifest::Orientation::ByColumns, vec![], digest_of(&tpr));
    let idpy = mf.add_commitment("Yq-bits", width as usize * rows, cols, manifest::Orientation::ByColumns, vec![], digest_of(&tpy));
    mf.add_operation(manifest::Operation::Matmul { a: ida, b: idb, c: idy });
    mf.add_operation(manifest::Operation::Rescale { x: idy, y: idyq, r: idr, shift });
    mf.add_operation(manifest::Operation::Range { value: idr, bits: idpr, width: shift, signed: false });
    mf.add_operation(manifest::Operation::Range { value: idyq, bits: idpy, width, signed: false });
    mf.add_operation(manifest::Operation::Binary { bits: idpr });
    mf.add_operation(manifest::Operation::Binary { bits: idpy });
    let ctx = mf.digest();

    // Matmul claim (the baseline for the exit criterion).
    let mut prng = 0xDE112_u64;
    let start = Instant::now();
    let mm_proof = prove_pi2(
        &params, &crs, &shape, &ctx, &inst.a_rows, &inst.rho_a, &inst.b_cols,
        &inst.rho_b, &inst.tau_c, &inst.ta, &inst.tb, &inst.tc, &mut prng,
    );
    let matmul_prove_s = start.elapsed().as_secs_f64();

    // Rescale + range family.
    let start = Instant::now();
    let bin_stmts: Vec<HadamardStatement> = tpr
        .iter()
        .map(|t| HadamardStatement { len: shift as usize * rows, tx: t, ty: t, tz: t })
        .chain(tpy.iter().map(|t| HadamardStatement {
            len: width as usize * rows,
            tx: t,
            ty: t,
            tz: t,
        }))
        .collect();
    let bin_wits: Vec<HadamardWitness> = (0..cols)
        .map(|j| HadamardWitness {
            x: &p_r[j], y: &p_r[j], rho_x: &rho_pr[j], rho_y: &rho_pr[j], rho_z: &rho_pr[j],
        })
        .chain((0..cols).map(|j| HadamardWitness {
            x: &p_y[j], y: &p_y[j], rho_x: &rho_py[j], rho_y: &rho_py[j], rho_z: &rho_py[j],
        }))
        .collect();
    let bin_proof = prove_hadamard(&params, &crs, &ctx, &bin_stmts, &bin_wits, &mut prng);
    let rec_r = prove_recomposition(
        &params, &crs, &ctx, rows, shift, false, &trr, &tpr, &rho_rr, &rho_pr, &mut prng,
    );
    let rec_y = prove_recomposition(
        &params, &crs, &ctx, rows, width, false, &tyq, &tpy, &rho_yq, &rho_py, &mut prng,
    );
    let link = prove_rescale_link(
        &params, &crs, &ctx, rows, shift, &inst.tc, &tyq, &trr, &inst.tau_c, &rho_yq,
        &rho_rr, &mut prng,
    );
    let family_prove_s = start.elapsed().as_secs_f64();

    let start = Instant::now();
    let mm_ok = verify_pi2(&params, &crs, &shape, &ctx, &inst.ta, &inst.tb, &inst.tc, &mm_proof);
    let bin_ok = verify_hadamard(&params, &crs, &ctx, &bin_stmts, &bin_proof);
    let rr_ok = verify_recomposition(&params, &crs, &ctx, rows, shift, false, &trr, &tpr, &rec_r);
    let ry_ok = verify_recomposition(&params, &crs, &ctx, rows, width, false, &tyq, &tpy, &rec_y);
    let lk_ok = verify_rescale_link(&params, &crs, &ctx, rows, shift, &inst.tc, &tyq, &trr, &link);
    let verify_s = start.elapsed().as_secs_f64();
    let elements = rows * cols;
    println!("  gadget commits (Yq, R, bits): {gadget_commit_s:.3}s");
    println!("  matmul claim prove: {matmul_prove_s:.3}s");
    println!(
        "  rescale+range family prove: {family_prove_s:.3}s  ({:.1}% of matmul claim; {:.1} ms/element)",
        100.0 * family_prove_s / matmul_prove_s,
        1000.0 * family_prove_s / elements as f64,
    );
    println!(
        "  verify all: {verify_s:.3}s (matmul={mm_ok} binary={bin_ok} rec_r={rr_ok} rec_y={ry_ok} link={lk_ok})"
    );
    assert!(mm_ok && bin_ok && rr_ok && ry_ok && lk_ok);
    // Negative: wrong quotient at one element must break the link.
    let mut y_bad = yq_cols.clone();
    y_bad[0][0] = addm(y_bad[0][0], 1);
    let rho_bad: Vec<Vec<i8>> = (0..cols).map(|_| rng_ternary(&mut rng, params.big_n)).collect();
    let ty_bad = commit_columns_fast(&params, &crs, &y_bad, &rho_bad);
    let mut prng_bad = 0xDE113_u64;
    let bad_link = prove_rescale_link(
        &params, &crs, &ctx, rows, shift, &inst.tc, &ty_bad, &trr, &inst.tau_c,
        &rho_bad, &rho_rr, &mut prng_bad,
    );
    let bad_ok = verify_rescale_link(&params, &crs, &ctx, rows, shift, &inst.tc, &ty_bad, &trr, &bad_link);
    println!("  negative wrong-quotient link: {}", if bad_ok { "ACCEPTED (BUG)" } else { "fails as required" });
    assert!(!bad_ok);
    println!("lattice gadget-demo ok");
}

fn usage() {
    eprintln!("usage:");
    eprintln!("  lattice_matmul self-test");
    eprintln!("  lattice_matmul bench <pi1|pi2> <n> [n...]");
    eprintln!("  lattice_matmul bench-rect <pi1|pi2> <rows> <inner> <cols>");
    eprintln!("  lattice_matmul bench-batch <pi1|pi2> <n> <t...>");
    eprintln!("  lattice_matmul params <pi1|pi2> <n> [n...]");
    eprintln!("  lattice_matmul chain-demo [n0 n1 n2 n3]   (default 16 32 64 8)");
    eprintln!("  lattice_matmul gadget-demo [rows inner cols shift width]   (default 16 32 64 6 12)");
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
        "gadget-demo" => {
            let dims: Vec<usize> = args[2..].iter().map(|a| a.parse().unwrap()).collect();
            match dims.len() {
                0 => gadget_demo(16, 32, 64, 6, 12),
                5 => gadget_demo(dims[0], dims[1], dims[2], dims[3] as u32, dims[4] as u32),
                _ => {
                    usage();
                    std::process::exit(1);
                }
            }
        }
        "chain-demo" => {
            let dims: Vec<usize> = args[2..].iter().map(|a| a.parse().unwrap()).collect();
            match dims.len() {
                0 => chain_demo(16, 32, 64, 8),
                4 => chain_demo(dims[0], dims[1], dims[2], dims[3]),
                _ => {
                    usage();
                    std::process::exit(1);
                }
            }
        }
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
        "bench-rect" => {
            if args.len() != 6 {
                usage();
                std::process::exit(1);
            }
            let Some((proto, name)) = parse_proto(args[2].as_str()) else {
                usage();
                std::process::exit(1);
            };
            let rows: usize = args[3].parse().unwrap();
            let inner: usize = args[4].parse().unwrap();
            let cols: usize = args[5].parse().unwrap();
            println!(
                "proto,shape,b,r,k,N,crs_s,matmul_s,commit_s,prove_s,verify_s,proof_bytes,verified"
            );
            bench_shape(
                proto,
                name,
                Shape { rows, inner, cols },
                &format!("{rows}x{inner}x{cols}"),
            );
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

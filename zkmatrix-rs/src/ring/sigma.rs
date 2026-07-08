// Route R Sigma layer (U2): masked opening rounds at r = 1 — the plain
// well-formedness opening (report Alg. 1 / Section 5.5 shape) and the Q2
// digit-decomposed opening for combination-magnitude witnesses. Both are
// the prototype rounds of ring_lattice.rs made parametric in the commit
// shape; the full-protocol rounds (Pi1/Pi2, U4/U5) compose these shapes.
//
// Discipline carried from Route Z:
//   - statement hash first: every challenge derives from
//     H(crs, shape, ctx, statement commitments); ctx = manifest digest for
//     chained claims;
//   - exact-integer norm checks at verification, BEFORE the response
//     matvec (this also establishes the A1 verify kernel's contract bound
//     for adversarial responses);
//   - rejection sampling with alpha = 12, M = 2.76 over the coefficient
//     embedding (prototype-validated at ring level);
//   - digit rounds share ONE challenge and are jointly rejection-sampled,
//     with the concentration restart rule on the center bundle.

use sha2::{Digest, Sha256};

use super::commit::{KernelPath, MatvecKind, RingCrs, a1_matvec};
use super::{
    D, Poly, RingCtx, XofReader, digit_split_witness, gaussian_ivec, poly_add, poly_from_small,
    poly_mul_small, poly_zero, polys_bytes, rejection_accept, ring_mul_split_kara_fast,
    vec_norm_sq_i64,
};
use super::aux::ring_mul_q_single;

// ---------------------------------------------------------------------------
// Parameter shapes for the two opening rounds (worst-case chain for the
// plain round, concentration chain for the digit round — matching the
// prototype and the params.rs discipline).

pub struct OpeningParams {
    pub sigma: u64,
    pub bound_sq: u128,
    pub beta: u128,
}

/// Plain opening round (ternary witness): worst-case T discipline.
pub fn derive_opening_params(q: u64, kappa: usize, n_r: usize, msg_r: usize) -> OpeningParams {
    let n_z = (n_r * D) as f64;
    let log2_q = (q as f64).log2();
    let b0 = n_z.sqrt();
    let t1 = 2.0 * D as f64 * b0; // ||c||_1 <= 2D, worst case
    let sigma = (12.0 * t1).ceil() as u64;
    let bound = 1.2 * sigma as f64 * n_z.sqrt();
    let bound_sq = (bound * bound).ceil() as u128;
    let beta = (2.0 * bound + 4.0 * D as f64 * b0).ceil() as u128;
    assert!((q as u128) > 8 * beta, "C2: q too small for beta");
    let log2_beta = (beta as f64).log2();
    let k_z = ((log2_beta / 2.0) * (log2_beta / 2.0) / (log2_q * super::LOG2_DELTA0)).ceil() as usize;
    assert!(kappa * D >= k_z, "C3: kappa too small: need k_Z >= {k_z}");
    let d_lwe = (768.0 * log2_q / 11.7).ceil() as usize;
    assert!(n_r * D >= (kappa + msg_r) * D + d_lwe, "C4: N too small");
    OpeningParams { sigma, bound_sq, beta }
}

pub struct DigitParams {
    pub e: u32,
    pub l: usize,
    /// Honest witness magnitude the round is sized for (||u||_inf <= w_inf).
    pub w_inf: i64,
    pub sigma: u64,
    pub bound_sq: u128,  // bundle l2^2 response bound (over all L digits)
    pub center_sq: u128, // concentration restart rule on the center bundle
    pub beta: u128,
    pub beta_undecomposed: u128, // what the plain round would have needed
}

/// Digit-decomposed opening round (combination-magnitude witness),
/// concentration discipline.
pub fn derive_digit_params(q: u64, kappa: usize, n_r: usize, e: u32, l: usize, w_inf: i64) -> DigitParams {
    let n_z = (n_r * D) as f64;
    let log2_q = (q as f64).log2();
    let op_c = 1.3 * (2.0 * D as f64).sqrt(); // concentration operator norm
    let half = (1u64 << (e - 1)) as f64; // ||digit||_inf <= 2^(e-1)
    let bundle_dim = (l as f64) * n_z;
    let t_bundle = op_c * half * bundle_dim.sqrt();
    let sigma = (12.0 * t_bundle).ceil() as u64;
    let bound = 1.2 * sigma as f64 * bundle_dim.sqrt();
    let bound_sq = (bound * bound).ceil() as u128;
    let center_sq = (t_bundle * t_bundle).ceil() as u128;
    let beta_dig = 2.0 * bound + op_c * half * n_z.sqrt();
    let beta_rec = op_c * w_inf as f64 * n_z.sqrt();
    let beta = beta_dig.max(beta_rec).ceil() as u128;
    assert!((q as u128) > 8 * beta, "C2 (digit chain): q too small");
    let log2_beta = (beta as f64).log2();
    let k_z = ((log2_beta / 2.0) * (log2_beta / 2.0) / (log2_q * super::LOG2_DELTA0)).ceil() as usize;
    assert!(kappa * D >= k_z, "C3 (digit chain): kappa too small");
    let t_u = op_c * w_inf as f64 * n_z.sqrt();
    let b_u = 1.2 * 12.0 * t_u * n_z.sqrt();
    let beta_u = (2.0 * b_u + op_c * w_inf as f64 * n_z.sqrt()).ceil() as u128;
    DigitParams { e, l, w_inf, sigma, bound_sq, center_sq, beta, beta_undecomposed: beta_u }
}

// ---------------------------------------------------------------------------
// Plain opening round: t1 = A1 rho for ternary rho.

pub struct OpeningProof {
    pub w: Vec<Poly>,
    pub z: Vec<Vec<i64>>, // integer responses (norm-checked, so not reduced)
}

pub fn statement_hash(crs: &RingCrs, t1: &[Poly], ctx: &[u8]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"route-r-open-stmt-v1");
    hasher.update(crs.q.to_le_bytes());
    hasher.update(crs.crs_hash);
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    hasher.update(&polys_bytes(t1));
    hasher.finalize().into()
}

pub fn challenge_from(h0: &[u8; 32], w: &[Poly]) -> Vec<i64> {
    XofReader::new("chal", &[h0, &polys_bytes(w)]).next_challenge()
}

pub fn prove_opening(
    path: &KernelPath,
    sp: &OpeningParams,
    crs: &RingCrs,
    t1: &[Poly],
    rho: &[Vec<i64>],
    ctx: &[u8],
    rng: &mut u64,
) -> (OpeningProof, usize) {
    let h0 = statement_hash(crs, t1, ctx);
    let n_r = crs.shape.n_r;
    let mut attempts = 0usize;
    loop {
        attempts += 1;
        let y: Vec<Vec<i64>> = (0..n_r).map(|_| gaussian_ivec(rng, D, sp.sigma)).collect();
        // Mask commitment (regime b): |y| <= 12 sigma by the sampler window.
        let w = a1_matvec(path, crs, MatvecKind::Mask, &y);
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

pub fn verify_opening(
    path: &KernelPath,
    ring: &RingCtx,
    sp: &OpeningParams,
    crs: &RingCrs,
    t1: &[Poly],
    ctx: &[u8],
    proof: &OpeningProof,
) -> bool {
    let (kappa, n_r) = (crs.shape.kappa, crs.shape.n_r);
    if proof.w.len() != kappa || proof.z.len() != n_r {
        return false;
    }
    // Norm check first: exact integers (mod-q checks alone cannot catch a
    // +q-shifted response), and it establishes the A1 verify kernel's
    // per-coordinate contract for adversarial z.
    let flat: Vec<i64> = proof.z.iter().flatten().copied().collect();
    if vec_norm_sq_i64(&flat) > sp.bound_sq {
        return false;
    }
    let h0 = statement_hash(crs, t1, ctx);
    let c = challenge_from(&h0, &proof.w);
    let lhs = a1_matvec(path, crs, MatvecKind::Verify, &proof.z);
    let zq = &ring.zq;
    let c_mod = poly_from_small(zq, &c);
    for i in 0..kappa {
        // c * t1: split kernel on the oracle path, quinary x mod-q
        // single-prime on A1.
        let ct = match path {
            KernelPath::School => ring_mul_split_kara_fast(ring, &c_mod, &t1[i]),
            KernelPath::A1(p) => ring_mul_q_single(&t1[i], &c, zq.q, &p.nt),
        };
        let rhs = poly_add(zq, &proof.w[i], &ct);
        if lhs[i] != rhs {
            return false;
        }
    }
    true
}

/// Interactive 2-transcript extraction (self-test/audit use): from two
/// accepting transcripts sharing a first message, recover the witness as
/// (c1 - c2)^{-1} (z1 - z2) — LS18 guarantees the inverse exists for
/// distinct quinary challenges. Returns None if the difference is not
/// invertible (impossible under C0').
pub fn extract_two_transcripts(
    ring: &RingCtx,
    c1: &[i64],
    z1: &[Vec<i64>],
    c2: &[i64],
    z2: &[Vec<i64>],
) -> Option<Vec<Poly>> {
    let zq = &ring.zq;
    let diff: Vec<i64> = c1.iter().zip(c2.iter()).map(|(&a, &b)| a - b).collect();
    let inv = super::poly_inv_g(ring, &poly_from_small(zq, &diff))?;
    Some(
        z1.iter()
            .zip(z2.iter())
            .map(|(a, b)| {
                let d: Vec<i64> = a.iter().zip(b.iter()).map(|(&x, &y)| x - y).collect();
                ring_mul_split_kara_fast(ring, &inv, &poly_from_small(zq, &d))
            })
            .collect(),
    )
}

// ---------------------------------------------------------------------------
// Digit-decomposed opening round: t = A1 u for a combination-magnitude
// witness u (||u||_inf <= w_inf), decomposed into L balanced base-2^e digit
// vectors with published digit statements t_j = A1 u_j and the public
// recombination sum_j 2^(ej) t_j = t. In the full protocol the digit
// ranges are exact ct-claims (U6); until those are wired in, the bundle
// norm check is the documented stand-in.

pub struct DigitOpeningProof {
    pub t_digits: Vec<Vec<Poly>>, // [L][kappa] digit statements
    pub w: Vec<Vec<Poly>>,        // [L][kappa] first messages
    pub z: Vec<Vec<Vec<i64>>>,    // [L][n_r] integer responses
}

pub fn digit_statement_hash(
    crs: &RingCrs,
    dp: &DigitParams,
    t: &[Poly],
    t_digits: &[Vec<Poly>],
    ctx: &[u8],
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"route-r-open-digit-stmt-v1");
    hasher.update(crs.q.to_le_bytes());
    hasher.update(crs.crs_hash);
    hasher.update((dp.e as u64).to_le_bytes());
    hasher.update((dp.l as u64).to_le_bytes());
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    hasher.update(&polys_bytes(t));
    for td in t_digits {
        hasher.update(&polys_bytes(td));
    }
    hasher.finalize().into()
}

pub fn digit_challenge(h0: &[u8; 32], w: &[Vec<Poly>]) -> Vec<i64> {
    let mut bytes = Vec::new();
    for wj in w {
        bytes.extend_from_slice(&polys_bytes(wj));
    }
    XofReader::new("chal-dig", &[h0, &bytes]).next_challenge()
}

/// Prover for the digit-decomposed opening round. Takes the *claimed*
/// statement t and the witness u independently (a malicious caller may
/// pass mismatched ones; the verifier's recombination check catches it).
/// Returns (proof, rejection attempts, concentration restarts).
pub fn prove_opening_digits(
    path: &KernelPath,
    dp: &DigitParams,
    crs: &RingCrs,
    t: &[Poly],
    u: &[Vec<i64>],
    ctx: &[u8],
    rng: &mut u64,
) -> (DigitOpeningProof, usize, usize) {
    let n_r = crs.shape.n_r;
    let u_dig = digit_split_witness(u, dp.e, dp.l);
    // Digit-witness commitments: |u_j| <= 2^(e-1) << 12 sigma, so the mask
    // kernel's contract covers them.
    let t_digits: Vec<Vec<Poly>> =
        u_dig.iter().map(|uj| a1_matvec(path, crs, MatvecKind::Mask, uj)).collect();
    let h0 = digit_statement_hash(crs, dp, t, &t_digits, ctx);
    let mut attempts = 0usize;
    let mut restarts = 0usize;
    loop {
        attempts += 1;
        let y: Vec<Vec<Vec<i64>>> = (0..dp.l)
            .map(|_| (0..n_r).map(|_| gaussian_ivec(rng, D, dp.sigma)).collect())
            .collect();
        let w: Vec<Vec<Poly>> = y.iter().map(|yj| a1_matvec(path, crs, MatvecKind::Mask, yj)).collect();
        let c = digit_challenge(&h0, &w);
        let v: Vec<Vec<Vec<i64>>> = u_dig
            .iter()
            .map(|uj| uj.iter().map(|un| poly_mul_small(&c, un)).collect())
            .collect();
        let flat_v: Vec<i64> = v.iter().flatten().flatten().copied().collect();
        // Concentration restart rule: the center bundle must sit inside
        // the bound the parameters were sized with.
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

pub fn verify_opening_digits(
    path: &KernelPath,
    ring: &RingCtx,
    dp: &DigitParams,
    crs: &RingCrs,
    t: &[Poly],
    ctx: &[u8],
    proof: &DigitOpeningProof,
) -> bool {
    let (kappa, n_r) = (crs.shape.kappa, crs.shape.n_r);
    let zq = &ring.zq;
    if proof.t_digits.len() != dp.l || proof.w.len() != dp.l || proof.z.len() != dp.l {
        return false;
    }
    for j in 0..dp.l {
        if proof.t_digits[j].len() != kappa || proof.w[j].len() != kappa || proof.z[j].len() != n_r {
            return false;
        }
    }
    // 1. Recombination: sum_j 2^(ej) t_j = t mod q (public, exact).
    for r in 0..kappa {
        let mut acc = poly_zero();
        for j in 0..dp.l {
            let scale = zq.to_mod(1i64 << (dp.e as usize * j));
            for i in 0..D {
                acc[i] = zq.add(acc[i], zq.mul(scale, proof.t_digits[j][r][i]));
            }
        }
        if acc != t[r] {
            return false;
        }
    }
    // 2. Bundle norm (exact integers; stand-in for the exact per-digit
    //    ct-range claims until U6 wires them in).
    let flat: Vec<i64> = proof.z.iter().flatten().flatten().copied().collect();
    if vec_norm_sq_i64(&flat) > dp.bound_sq {
        return false;
    }
    // 3. Per-digit Sigma equations (one shared challenge). The norm check
    //    above runs first, establishing the A1 verify kernel's contract.
    let h0 = digit_statement_hash(crs, dp, t, &proof.t_digits, ctx);
    let c = digit_challenge(&h0, &proof.w);
    let c_mod = poly_from_small(zq, &c);
    for j in 0..dp.l {
        let lhs = a1_matvec(path, crs, MatvecKind::Verify, &proof.z[j]);
        for r in 0..kappa {
            let ct = match path {
                KernelPath::School => ring_mul_split_kara_fast(ring, &c_mod, &proof.t_digits[j][r]),
                KernelPath::A1(p) => ring_mul_q_single(&proof.t_digits[j][r], &c, zq.q, &p.nt),
            };
            let rhs = poly_add(zq, &proof.w[j][r], &ct);
            if lhs[r] != rhs {
                return false;
            }
        }
    }
    true
}

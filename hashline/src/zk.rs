//! [UPERF3-ZA] The zero-knowledge form of the hashline proof for the
//! ACTIVATIONS (mode P1 of TARGET_CONTRACT Amendment A1: inputs and
//! activations private, weights public), behind `--zk`. The non-`--zk`
//! path is untouched (the 50cf7bdf.. byte-identity gate).
//!
//! THE PLAN (rung 0; the constructions of U_PERF3_ROUTE_B_THROUGHPUT.md
//! section 4.2, with the two places where that memo's sketch does not
//! close and what is built instead):
//!
//! (a) Ligero-ZK for the A and H commitments (`pcs.rs`, additive):
//!   (i) PAD ROWS: every row's message polynomial f_data (degree < n, the
//!       systematic interpolant on the size-n subgroup) becomes
//!       f = f_data + Z_n * g_pad with Z_n(x) = x^n - 1 and g_pad a fresh
//!       uniformly random polynomial of degree < Q (Q = num_col_checks).
//!       f agrees with the data on the subgroup; on any Q evaluation
//!       points OUTSIDE the subgroup the map g_pad -> (f(eta_1..eta_Q))
//!       is a bijection (Z_n(eta) != 0 and a Vandermonde in eta), so any
//!       Q opened positions are jointly uniform. The evaluation domain
//!       moves to the COSET h * G_{4n} (h = 7, a generator: h^(4n) != 1),
//!       which is disjoint from G_n, so NO opened position is systematic
//!       and the sampling stays uniform over all 4n columns. The code is
//!       RS(n + Q, 4n) on the coset: rate 0.254, distance 0.7455,
//!       (1 - delta/3)^Q = 2^-105.6 at Q = 256 (the memo's number); the
//!       NTT sizes are unchanged (n + Q coefficients zero-padded to 4n;
//!       the coset is a coefficient scaling by h^i).
//!  (ii) MASK ROWS: one uniformly random row (n symbols + pads) per
//!       (private table, opening point) pair, committed WITH the data.
//!       The memo's "v' = rho^T M + u with u's inner product read off"
//!       does not close: the verifier cannot know <u, c> for a
//!       challenge-dependent column weight c without u, and letting the
//!       prover send it is unsound. What is built instead ties the mask
//!       row to the sumcheck (see (b)(ii)): the opened claim is the
//!       COMBINED value (1 - rho_ext) * T~(rho) + rho_ext * <R_T, eq(rho_col)>
//!       for the table T and its mask row R_T — one Claim with two parts
//!       sharing the column key, whose clear vector and whose value are
//!       both uniform; the verifier never sees T~(rho). The proximity
//!       vector is masked automatically (its random rho touches the mask
//!       rows). The all-ones (sum) group of H is masked by a zero-sum
//!       random row u whose zero sum is PROVEN by a masked 14-variable
//!       sumcheck (a sum claim's mask must have a challenge-independent
//!       constraint — Ligero's own device).
//! (b) Zero-knowledge sumcheck (Chiesa-Forbes-Spooner masking as in
//!     Libra) for every sumcheck touching A, H or the helpers (gu, d,
//!     zc20, zc17, and the new table-side and zero-sum sumchecks):
//!   (i) a committed random masking polynomial g(x) = a_0 + a' * prod_j x_j
//!       + sum_j sum_{e=1..d} a_{j,e} x_j^e (n*d + 2 coefficients: the
//!       extra a' is needed so that BOTH the mask's total G and its
//!       terminal g(rho) are uniform given the round messages), a
//!       verifier challenge c, and the sumcheck run on f + c g; g's round
//!       contributions are closed-form. The claimed sums of the matmul
//!       sumchecks are sent MASKED (S'' = S + c G) and the zero-checks'
//!       claimed sums are computed by the verifier from S'' and a sent
//!       correction Gamma = c20 G20 - nu c_gu G_gu (a linear functional
//!       of the mask coefficients, proven from the mask commitment).
//!  (ii) THE LAST-ROUND EXTENSION for the terminal values: every private
//!       table T of the sumcheck is extended by one trailing variable,
//!       T_ext(x, y) = (1 - y) T(x) + y R_T(x) with R_T the mask row
//!       replicated over the rows, and the eq/selector factor carries
//!       (1 - y). Rounds 0..k-1 are IDENTICAL to the unmasked sumcheck
//!       (the y = 1 half sums to zero over booleans); round k costs O(1)
//!       and the verifier's terminal check runs on the MASKED values
//!       m_T = (1 - rho_k) T~(rho) + rho_k R_T~(rho), which are uniform.
//!       This is Libra's input-layer mask in multilinear form; it costs
//!       no sumcheck work and reuses the device zero-check kernels
//!       unchanged (the mask is applied to the round messages through
//!       the transcript hook and to the finals on the host).
//! (c) The mask polynomials are committed in a small per-layer
//!     Ligero-form commitment (`MaskCommit`: one row per sumcheck, with
//!     Q pads; a zero-sum blinding row; a proximity mask row) and opened
//!     with Ligero's PRODUCT-FORM linear test (the clear object is
//!     q' = sum_rows p_a * p_w + p_b, checked by its sum over the message
//!     domain and at Q sampled columns), the only hash-based ZK opening
//!     of a linear functional whose mask constraint is challenge-
//!     independent. All functionals of one layer (the g(rho)'s and the
//!     Gammas) are folded into one test by a verifier challenge theta.
//! (d) Committed multiplicities: the histogram tables move into A (before
//!     alpha); their LogUp table side becomes a committed helper column
//!     h_t = m_t / (alpha - t) in H with a masked zero-check
//!     h_t (alpha - t(x)) - m(x) = 0 over the public table values, and
//!     the LogUp identity becomes ONE sum claim on H with value 0
//!     (witness helpers minus table helpers plus the zero-sum mask row).
//!     No helper sum and no histogram is ever sent.
//! (e) Salted leaves: leaf = blake3(blake3(column) || salt_j), salt_j
//!     32 fresh random bytes per column (the device hash kernel is
//!     unchanged; the salting is one extra host hash per leaf).
//!
//! Randomness: every pad, mask, salt and mask polynomial is derived from
//! `--seed` through a blake3 stream (`ZkRng`), so the CPU and GPU provers
//! produce byte-identical `--zk` proofs under the same seed (the parity
//! gate of rung 4). A deployment draws the seed from OS entropy.
//!
//! What remains in the clear under P1 (stated, not hidden): the weights
//! and everything of the W commitment (public by the mode); the shapes,
//! shifts and the table digest; the multiplicity TOTALS (implied by the
//! shape); the masked values above (uniform). The composition of layers
//! and the chained transcript are owed a written simulator (the same
//! caveat class as the lattice line's lemmas Q4.7-Q4.9).

use crate::field::{Fp, Fp2};

/// The ZK configuration of a pass (rung 0: the flag and the seed).
#[derive(Clone, Copy, Debug, Default)]
pub struct ZkConfig {
    pub enabled: bool,
    pub seed: u64,
}

/// A deterministic blake3 stream: the source of every pad, mask, salt
/// and masking polynomial under `--zk` (the CPU/GPU parity gate needs
/// the prover's randomness to be a function of the seed).
pub struct ZkRng {
    key: [u8; 32],
    counter: u64,
    buf: [u8; 64],
    pos: usize,
}

impl ZkRng {
    pub fn new(seed: u64, domain: &[u8]) -> ZkRng {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline-zk-rng/");
        h.update(domain);
        h.update(&seed.to_le_bytes());
        ZkRng { key: *h.finalize().as_bytes(), counter: 0, buf: [0u8; 64], pos: 64 }
    }

    fn refill(&mut self) {
        let mut h = blake3::Hasher::new();
        h.update(&self.key);
        h.update(&self.counter.to_le_bytes());
        self.counter += 1;
        let mut out = h.finalize_xof();
        out.fill(&mut self.buf);
        self.pos = 0;
    }

    pub fn next_u64(&mut self) -> u64 {
        if self.pos + 8 > self.buf.len() {
            self.refill();
        }
        let v = u64::from_le_bytes(self.buf[self.pos..self.pos + 8].try_into().unwrap());
        self.pos += 8;
        v
    }

    /// A uniform base-field element (a 128-bit draw reduced mod p: bias 2^-64).
    pub fn fp(&mut self) -> Fp {
        let lo = self.next_u64();
        let hi = self.next_u64();
        Fp::from_u128(((hi as u128) << 64) | lo as u128)
    }

    pub fn fp2(&mut self) -> Fp2 {
        let a = self.fp();
        let b = self.fp();
        Fp2::new(a, b)
    }

    pub fn fp_vec(&mut self, n: usize) -> Vec<Fp> {
        (0..n).map(|_| self.fp()).collect()
    }

    pub fn fp2_vec(&mut self, n: usize) -> Vec<Fp2> {
        (0..n).map(|_| self.fp2()).collect()
    }

    pub fn bytes32(&mut self) -> [u8; 32] {
        let mut out = [0u8; 32];
        for c in out.chunks_mut(8) {
            c.copy_from_slice(&self.next_u64().to_le_bytes());
        }
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rng_is_deterministic_and_domain_separated() {
        let mut a = ZkRng::new(7, b"x");
        let mut b = ZkRng::new(7, b"x");
        let va: Vec<u64> = (0..100).map(|_| a.next_u64()).collect();
        let vb: Vec<u64> = (0..100).map(|_| b.next_u64()).collect();
        assert_eq!(va, vb);
        let mut c = ZkRng::new(8, b"x");
        assert_ne!(va[0], c.next_u64());
        let mut d = ZkRng::new(7, b"y");
        assert_ne!(va[0], d.next_u64());
        let f = a.fp();
        assert!(f.0 < crate::field::P);
    }
}

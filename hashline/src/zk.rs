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
    buf: Vec<u8>,
    pos: usize,
}

const RNG_BLOCK: usize = 8192;

impl ZkRng {
    pub fn new(seed: u64, domain: &[u8]) -> ZkRng {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline-zk-rng/");
        h.update(domain);
        h.update(&seed.to_le_bytes());
        ZkRng { key: *h.finalize().as_bytes(), counter: 0, buf: vec![0u8; RNG_BLOCK], pos: RNG_BLOCK }
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


// ===========================================================================
// The mask commitment (construction (c)): the CFS masking polynomials of
// a layer, committed in a small Ligero-form matrix and opened with the
// PRODUCT-FORM linear test. Base rows: for each sumcheck s, a_s,re and
// a_s,im (its Fp2 coefficients; message = coefficients || 256 pads ||
// zeros on G_512); b_re, b_im (the blinding polynomial, degree < 1024,
// zero sum over G_512: b_512 = -b_0); u_re, u_im (the proximity mask).
// Every base row is evaluated on the coset 7 * G_4096 (RS(1024, 4096),
// distance 3/4), the columns are salted and Merkle-committed, and 256
// columns are opened. A linear functional F = sum_i theta^i <a_{s_i}, w_i>
// with claimed value V is proven by the clear polynomial
//   q'(x) = sum_s p_{a_s}(x) p_{W_s}(x) + p_b(x)   (degree < 1024)
// whose sum over G_512 is V (512 (q'_0 + q'_512) = V; the blinding sums
// to zero there) and which agrees with the opened columns at the 256
// sampled points. q' is uniform given V; the a-rows' columns are uniform
// by their pads; b and u are determined by (q', prox, the a columns).
// ===========================================================================

use crate::merkle::{Digest, MerkleTree};
use crate::mle::eq_point;
use crate::ntt::NttTables;
use crate::pcs::{self, coset_powers, salt_leaf, Claim, Commitment, Opening, OpeningZk, PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use crate::sumcheck::{self, extension_round, masked_terminal, CfsMask, CfsMasker, SumcheckProof};
use crate::transcript::Transcript;
use rayon::prelude::*;

pub const MASK_LOG_MSG: u32 = 9; // 512 message positions per a-row
pub const MASK_LOG_DOM: u32 = 12; // 4096 evaluation positions
pub const MASK_Q: usize = 256; // opened columns (== pads per a-row)

pub struct MaskCommit {
    /// (n_vars, degree) per sumcheck
    pub specs: Vec<(usize, usize)>,
    pub masks: Vec<CfsMask>,
    /// the a-rows' committed messages (512 each; 2 per mask: re, im), as coefficients of their G_512 interpolants
    pub a_coefs: Vec<Vec<Fp>>,
    /// base rows x 4096, row-major (2 per mask, then b_re, b_im, u_re, u_im)
    pub encoded: Vec<Fp>,
    /// b and u as 1024 coefficients each (re, im)
    pub b: (Vec<Fp>, Vec<Fp>),
    pub u: (Vec<Fp>, Vec<Fp>),
    pub salts: Vec<[u8; 32]>,
    pub tree: MerkleTree,
}

/// One functional over the mask coefficients: sum over terms (row s, weights over
/// the L_s coefficients of mask s) = value. A Gamma spans two rows.
#[derive(Clone, Debug)]
pub struct MaskFunctional {
    pub terms: Vec<(usize, Vec<Fp2>)>,
    pub value: Fp2,
}

#[derive(Clone, Debug, Default)]
pub struct MaskOpening {
    pub q: Vec<Fp2>,
    pub prox: Vec<Fp2>,
    pub columns: Vec<(usize, Vec<Fp>, [u8; 32], Vec<Digest>)>,
}

impl MaskOpening {
    pub fn size_bytes(&self) -> usize {
        self.q.len() * 16 + self.prox.len() * 16 + self.columns.iter().map(|(_, c, _, p)| 8 + c.len() * 8 + 32 + p.len() * 32).sum::<usize>()
    }
    pub fn write_bytes(&self, out: &mut Vec<u8>) {
        for x in &self.q { out.extend_from_slice(&x.to_bytes()); }
        for x in &self.prox { out.extend_from_slice(&x.to_bytes()); }
        for (j, col, salt, path) in &self.columns {
            out.extend_from_slice(&(*j as u64).to_le_bytes());
            for x in col { out.extend_from_slice(&x.to_bytes()); }
            out.extend_from_slice(salt);
            for d in path { out.extend_from_slice(d); }
        }
    }
}

/// coefficients (any length <= 2^log_dom) -> evaluations on the coset 7 G_4096.
fn encode_coeffs_coset(ntt: &NttTables, coeffs: &[Fp], pows: &[Fp], out: &mut [Fp]) {
    for v in out.iter_mut() { *v = Fp::ZERO; }
    for (i, c) in coeffs.iter().enumerate() { out[i] = c.mul(pows[i]); }
    ntt.forward(out);
}

pub fn mask_commit(specs: &[(usize, usize)], ntt: &NttTables, rng: &mut ZkRng) -> MaskCommit {
    let m = 1usize << MASK_LOG_MSG;
    let dom = 1usize << MASK_LOG_DOM;
    let pows = coset_powers(Fp::new(7), dom);
    let masks: Vec<CfsMask> = specs.iter().map(|&(n, d)| CfsMask::random(rng, n, d)).collect();
    let n_base = 2 * masks.len() + 4;
    let mut encoded = vec![Fp::ZERO; n_base * dom];
    let mut a_coefs = Vec::with_capacity(2 * masks.len());
    for (s, mk) in masks.iter().enumerate() {
        let re: Vec<Fp> = mk.coeffs.iter().map(|c| c.c0).collect();
        let im: Vec<Fp> = mk.coeffs.iter().map(|c| c.c1).collect();
        for (k, part) in [re, im].iter().enumerate() {
            assert!(part.len() + MASK_Q <= m, "mask row: {} coefficients + {MASK_Q} pads > {m}", part.len());
            let mut msg = vec![Fp::ZERO; m];
            msg[..part.len()].copy_from_slice(part);
            let pads = rng.fp_vec(MASK_Q);
            msg[part.len()..part.len() + MASK_Q].copy_from_slice(&pads);
            ntt.inverse(&mut msg);
            encode_coeffs_coset(ntt, &msg, &pows, &mut encoded[(2 * s + k) * dom..(2 * s + k + 1) * dom]);
            a_coefs.push(msg);
        }
    }
    let mut b_re = rng.fp_vec(2 * m);
    let mut b_im = rng.fp_vec(2 * m);
    b_re[m] = b_re[0].neg();
    b_im[m] = b_im[0].neg();
    let u_re = rng.fp_vec(2 * m);
    let u_im = rng.fp_vec(2 * m);
    let base0 = 2 * masks.len();
    for (k, c) in [&b_re, &b_im, &u_re, &u_im].iter().enumerate() {
        encode_coeffs_coset(ntt, c, &pows, &mut encoded[(base0 + k) * dom..(base0 + k + 1) * dom]);
    }
    let salts: Vec<[u8; 32]> = (0..dom).map(|_| rng.bytes32()).collect();
    let leaves = pcs::hash_columns(&encoded, n_base, dom);
    let salted: Vec<Digest> = leaves.par_iter().zip(salts.par_iter()).map(|(l, s)| salt_leaf(l, s)).collect();
    let tree = MerkleTree::build(salted);
    MaskCommit { specs: specs.to_vec(), masks, a_coefs, encoded, b: (b_re, b_im), u: (u_re, u_im), salts, tree }
}

/// The combined weight vector of mask row s under theta (over the 512 message positions) and the combined value.
fn combined_weights(specs: &[(usize, usize)], functionals: &[MaskFunctional], theta: Fp2) -> (Vec<Vec<Fp2>>, Fp2) {
    let m = 1usize << MASK_LOG_MSG;
    let mut ws: Vec<Vec<Fp2>> = specs.iter().map(|_| vec![Fp2::ZERO; m]).collect();
    let mut v = Fp2::ZERO;
    let mut th = Fp2::ONE;
    for f in functionals {
        for (row, w) in &f.terms {
            let l = CfsMask::len(specs[*row].0, specs[*row].1);
            assert_eq!(w.len(), l, "mask functional: {} weights for a mask of {l} coefficients", w.len());
            for (j, x) in w.iter().enumerate() {
                ws[*row][j] = ws[*row][j].add(th.mul(*x));
            }
        }
        v = v.add(th.mul(f.value));
        th = th.mul(theta);
    }
    (ws, v)
}

/// p_W (the interpolant of W on G_512) as coefficients (re, im).
fn weight_polys(w: &[Fp2], ntt: &NttTables) -> (Vec<Fp>, Vec<Fp>) {
    let mut re: Vec<Fp> = w.iter().map(|x| x.c0).collect();
    let mut im: Vec<Fp> = w.iter().map(|x| x.c1).collect();
    ntt.inverse(&mut re);
    ntt.inverse(&mut im);
    (re, im)
}

/// The product of two polynomials given by coefficients (each < 512): 1024 coefficients.
fn poly_mul_512(a: &[Fp], b: &[Fp], ntt: &NttTables) -> Vec<Fp> {
    let m2 = 2usize << MASK_LOG_MSG;
    let mut ea = vec![Fp::ZERO; m2];
    let mut eb = vec![Fp::ZERO; m2];
    ea[..a.len()].copy_from_slice(a);
    eb[..b.len()].copy_from_slice(b);
    ntt.forward(&mut ea);
    ntt.forward(&mut eb);
    for (x, y) in ea.iter_mut().zip(eb.iter()) { *x = x.mul(*y); }
    ntt.inverse(&mut ea);
    ea
}

pub fn mask_open(mc: &MaskCommit, functionals: &[MaskFunctional], ntt: &NttTables, tr: &mut Transcript) -> MaskOpening {
    let m = 1usize << MASK_LOG_MSG;
    let dom = 1usize << MASK_LOG_DOM;
    let theta = tr.challenge_fp2();
    let (ws, _v) = combined_weights(&mc.specs, functionals, theta);
    // q' = sum_s p_{a_s} p_{W_s} + p_b as 1024 Fp2 coefficients, a_s = a_re + U a_im, W = W_re + U W_im (U^2 = 7)
    let mut q_re = mc.b.0.clone();
    let mut q_im = mc.b.1.clone();
    for s in 0..mc.masks.len() {
        let (w_re, w_im) = weight_polys(&ws[s], ntt);
        let (a_re, a_im) = (&mc.a_coefs[2 * s], &mc.a_coefs[2 * s + 1]);
        let rr = poly_mul_512(a_re, &w_re, ntt);
        let ii = poly_mul_512(a_im, &w_im, ntt);
        let ri = poly_mul_512(a_re, &w_im, ntt);
        let ir = poly_mul_512(a_im, &w_re, ntt);
        for i in 0..2 * m {
            q_re[i] = q_re[i].add(rr[i]).add(ii[i].mul(Fp::new(7)));
            q_im[i] = q_im[i].add(ri[i]).add(ir[i]);
        }
    }
    let q: Vec<Fp2> = q_re.iter().zip(q_im.iter()).map(|(a, b)| Fp2::new(*a, *b)).collect();
    tr.absorb_fp2(b"mask-q", &q);
    // the proximity combination: sum_rows r_row p_row + u (Fp2), 1024 coefficients
    let n_rows = 2 * mc.masks.len() + 2;
    let rs = tr.challenge_fp2_vec(n_rows);
    let mut prox: Vec<Fp2> = (0..2 * m).map(|i| Fp2::new(mc.u.0[i], mc.u.1[i])).collect();
    for (row, r) in rs.iter().enumerate() {
        let coeffs: &[Fp] = if row < 2 * mc.masks.len() { &mc.a_coefs[row] } else if row == 2 * mc.masks.len() { &mc.b.0 } else { &mc.b.1 };
        for (i, c) in coeffs.iter().enumerate() { prox[i] = prox[i].add(r.mul_base(*c)); }
    }
    tr.absorb_fp2(b"mask-prox", &prox);
    let idx = tr.challenge_indices(MASK_Q, dom);
    let n_base = 2 * mc.masks.len() + 4;
    let columns = idx.iter().map(|&j| {
        let col: Vec<Fp> = (0..n_base).map(|r| mc.encoded[r * dom + j]).collect();
        (j, col, mc.salts[j], mc.tree.path(j))
    }).collect();
    MaskOpening { q, prox, columns }
}

pub fn mask_verify(root: &Digest, specs: &[(usize, usize)], functionals: &[MaskFunctional], op: &MaskOpening, ntt: &NttTables, tr: &mut Transcript) -> Result<(), String> {
    let m = 1usize << MASK_LOG_MSG;
    let dom = 1usize << MASK_LOG_DOM;
    let n_base = 2 * specs.len() + 4;
    let theta = tr.challenge_fp2();
    let (ws, v) = combined_weights(specs, functionals, theta);
    if op.q.len() != 2 * m { return Err("mask: q length".into()); }
    // sum over G_512 of q' = 512 (q_0 + q_512)
    let got = op.q[0].add(op.q[m]).mul_base(Fp::new(m as u64));
    if got != v { return Err("mask: the product polynomial's sum != the combined functional".into()); }
    tr.absorb_fp2(b"mask-q", &op.q);
    let rs = tr.challenge_fp2_vec(2 * specs.len() + 2);
    if op.prox.len() != 2 * m { return Err("mask: prox length".into()); }
    tr.absorb_fp2(b"mask-prox", &op.prox);
    let idx = tr.challenge_indices(MASK_Q, dom);
    if op.columns.len() != idx.len() { return Err("mask: column count".into()); }
    let pows = coset_powers(Fp::new(7), dom);
    let enc = |c: &[Fp]| -> Vec<Fp> { let mut o = vec![Fp::ZERO; dom]; encode_coeffs_coset(ntt, c, &pows, &mut o); o };
    let w_enc: Vec<(Vec<Fp>, Vec<Fp>)> = ws.iter().map(|w| { let (re, im) = weight_polys(w, ntt); (enc(&re), enc(&im)) }).collect();
    let q_enc = { let re: Vec<Fp> = op.q.iter().map(|x| x.c0).collect(); let im: Vec<Fp> = op.q.iter().map(|x| x.c1).collect(); (enc(&re), enc(&im)) };
    let p_enc = { let re: Vec<Fp> = op.prox.iter().map(|x| x.c0).collect(); let im: Vec<Fp> = op.prox.iter().map(|x| x.c1).collect(); (enc(&re), enc(&im)) };
    for ((j, col, salt, path), &want_j) in op.columns.iter().zip(idx.iter()) {
        if *j != want_j { return Err("mask: column index".into()); }
        if col.len() != n_base { return Err("mask: column length".into()); }
        let leaf = salt_leaf(&pcs_hash_column(col), salt);
        if !MerkleTree::verify_path(root, *j, &leaf, path) { return Err(format!("mask: Merkle path for column {j} fails")); }
        let mut acc = Fp2::new(col[2 * specs.len()], col[2 * specs.len() + 1]);
        for s in 0..specs.len() {
            let w = Fp2::new(w_enc[s].0[*j], w_enc[s].1[*j]);
            let a = Fp2::new(col[2 * s], col[2 * s + 1]);
            acc = acc.add(a.mul(w));
        }
        if acc != Fp2::new(q_enc.0[*j], q_enc.1[*j]) { return Err(format!("mask: column {j} disagrees with the product polynomial")); }
        let mut pacc = Fp2::new(col[n_base - 2], col[n_base - 1]);
        for (row, r) in rs.iter().enumerate() { pacc = pacc.add(r.mul_base(col[row])); }
        if pacc != Fp2::new(p_enc.0[*j], p_enc.1[*j]) { return Err(format!("mask: column {j} disagrees with the proximity vector")); }
    }
    Ok(())
}

fn pcs_hash_column(col: &[Fp]) -> Digest {
    let bytes: Vec<u8> = col.iter().flat_map(|v| v.to_bytes()).collect();
    *blake3::hash(&bytes).as_bytes()
}

// ===========================================================================
// The ZK layer: prove_layer_zk / verify_layer_zk (mode P1). The statement,
// the W commitment and its opening, the matmul structure and the two
// zero-checks are those of layer.rs; A and H are committed in ZK mode with
// their mask rows, every sumcheck is CFS-masked with the last-round
// extension, and the H sum group is masked by a proven zero-sum row.
// ===========================================================================

use crate::chain::LayerWitness;
use crate::export::{D, F};
use crate::field::batch_inverse2;
use crate::layer::{tag_range, LayerParams, Layout, Statement, TAG_INT8, TAG_SILU, LOG_WBLOCK};
use crate::mle::{eq_table_msb, eval_mle_ext, fold_cols_base, fold_cols_i8, fold_rows_i32, fold_rows_i8};

/// One multiplicity table's rows: its committed histogram m in A (one row,
/// zero-padded), its mask row, its table-side helper h_t = m / (alpha - t)
/// in H (re, im) with an Fp2 mask (re, im).
#[derive(Clone, Debug)]
pub struct TabRows {
    pub tag: u64,
    pub size: usize,
    pub a_row: usize,
    pub a_mask: usize,
    pub h_re: usize,
    pub h_im: usize,
    pub h_mre: usize,
    pub h_mim: usize,
}

/// Which mask row (index into the A or H commitment's rows) masks which (table, point).
pub struct ZkLayout {
    pub lay: Layout,
    pub a_n: usize,
    pub h_n: usize,
    /// A mask rows (row indices): zc20 [7], zc17 [9], gu X_b [3], d h8 [1], prox [1]
    pub a_m20: [usize; 7],
    pub a_m17: [usize; 9],
    pub a_mgu: [usize; 3],
    pub a_md: usize,
    pub a_prox: usize,
    pub a_len: usize,
    /// H mask rows: zc20 [3] (re, im), zc17 [3] (re, im), u (re, im), u' (re, im), prox
    pub h_m20: [(usize, usize); 3],
    pub h_m17: [(usize, usize); 3],
    pub h_u: (usize, usize),
    pub h_up: (usize, usize),
    pub h_prox: usize,
    pub h_len: usize,
    /// the multiplicity tables (silu, int8, range(s) for each distinct shift ascending)
    pub tabs: Vec<TabRows>,
}

/// The number of multiplicity-table slots of every layer: silu, int8, and
/// one per distinct shift of the 4-tuple (at most 4); the unused slots are
/// dummies (tag 0, size 0: m = h_t = 0) so that every layer's A and H have
/// the SAME row counts — the device buffer pool then reuses its buffers
/// across layers instead of caching one layout per table count.
pub const N_TABLE_SLOTS: usize = 6;

/// The multiplicity tables' (tag, size) in proof order for a shift tuple, padded to N_TABLE_SLOTS.
pub fn table_specs(shifts: (u32, u32, u32, u32)) -> Vec<(u64, usize)> {
    let mut out = vec![(TAG_SILU, 256usize), (TAG_INT8, 256usize)];
    let mut sh: Vec<u32> = vec![shifts.0, shifts.1, shifts.2, shifts.3];
    sh.sort();
    sh.dedup();
    for s in sh { out.push((tag_range(s), 1usize << s)); }
    while out.len() < N_TABLE_SLOTS { out.push((0, 0)); }
    out
}

impl ZkLayout {
    pub fn new(t_rows: usize, params: &LayerParams, shifts: (u32, u32, u32, u32)) -> ZkLayout {
        let lay = Layout::new(t_rows);
        let a_n = 1usize << params.log_cols.min(lay.log_tb);
        let h_n = a_n;
        let tspecs = table_specs(shifts);
        for (_, size) in &tspecs { assert!(*size <= a_n, "zk: a multiplicity table ({size}) larger than a row ({a_n})"); }
        let mut r = lay.a_len / a_n;
        let mut next = || { let v = r; r += 1; v };
        let a_m20 = [next(), next(), next(), next(), next(), next(), next()];
        let a_m17 = [next(), next(), next(), next(), next(), next(), next(), next(), next()];
        let a_mgu = [next(), next(), next()];
        let a_md = next();
        let a_prox = next();
        let mut tabs: Vec<TabRows> = tspecs.iter().map(|&(tag, size)| TabRows { tag, size, a_row: next(), a_mask: next(), h_re: 0, h_im: 0, h_mre: 0, h_mim: 0 }).collect();
        let a_len = r * a_n;
        let mut r = lay.h_len / h_n;
        let mut next = || { let v = r; r += 1; v };
        let h_m20 = [(next(), next()), (next(), next()), (next(), next())];
        let h_m17 = [(next(), next()), (next(), next()), (next(), next())];
        let h_u = (next(), next());
        let h_up = (next(), next());
        let h_prox = next();
        for t in tabs.iter_mut() { t.h_re = next(); t.h_im = next(); t.h_mre = next(); t.h_mim = next(); }
        let h_len = r * h_n;
        ZkLayout { lay, a_n, h_n, a_m20, a_m17, a_mgu, a_md, a_prox, a_len, h_m20, h_m17, h_u, h_up, h_prox, h_len, tabs }
    }
    fn a_mask_rows(&self) -> Vec<usize> {
        let mut v: Vec<usize> = self.a_m20.to_vec();
        v.extend(self.a_m17);
        v.extend(self.a_mgu);
        v.push(self.a_md);
        v.extend(self.tabs.iter().map(|t| t.a_mask));
        v
    }
    fn h_mask_rows(&self) -> Vec<usize> {
        let mut v = Vec::new();
        for (a, b) in self.h_m20.iter().chain(self.h_m17.iter()) { v.push(*a); v.push(*b); }
        v.extend([self.h_u.0, self.h_u.1, self.h_up.0, self.h_up.1]);
        for t in &self.tabs { v.push(t.h_mre); v.push(t.h_mim); }
        v
    }
}

/// The sumchecks of a layer in mask-commitment order: gu, d, zc20, zc17, zsum.
pub const SC_GU: usize = 0;
pub const SC_D: usize = 1;
pub const SC_ZC20: usize = 2;
pub const SC_ZC17: usize = 3;
pub const SC_ZSUM: usize = 4;
pub const SC_TAB: usize = 5;

pub fn mask_specs(lay: &Layout, a_log_cols: u32) -> Vec<(usize, usize)> {
    vec![(8 + 1, 2), (11 + 1, 2), (lay.log_tf as usize + 1, 4), (lay.log_tb as usize + 1, 4), (a_log_cols as usize + 1, 2), (a_log_cols as usize + 1, 3)]
}

/// The public compressed table values of table `tag` (size entries, zero beyond), as an n-entry Fp2 row.
fn tval_row(tag: u64, size: usize, n: usize, table: &[i8; 256], beta: Fp2, gamma: Fp2) -> Vec<Fp2> {
    let mut out = vec![Fp2::ZERO; n];
    for (i, o) in out.iter_mut().enumerate().take(size) {
        *o = if tag == TAG_SILU {
            Fp2::from_i64(i as i64 - 128).add(beta.mul_base(Fp::from_i64(table[i] as i64))).add(gamma.mul_base(Fp::new(TAG_SILU)))
        } else if tag == TAG_INT8 {
            Fp2::from_i64(i as i64 - 128).add(gamma.mul_base(Fp::new(TAG_INT8)))
        } else {
            Fp2::from_u64(i as u64).add(gamma.mul_base(Fp::new(tag)))
        };
    }
    out
}

#[derive(Clone, Debug, Default)]
pub struct LayerProofZk {
    pub w_com: Option<Commitment>,
    pub a_com: Option<Commitment>,
    pub mask_root: Digest,
    pub h_com: Option<Commitment>,
    pub gu_claim: Fp2,
    pub gu_sc: SumcheckProof,
    pub gu_term: Vec<Fp2>,
    pub d_claim: Fp2,
    pub d_sc: SumcheckProof,
    pub d_term: Vec<Fp2>,
    pub gamma20: Fp2,
    pub zc20_sc: SumcheckProof,
    pub zc20_term: Vec<Fp2>,
    pub gamma17: Fp2,
    pub zc17_sc: SumcheckProof,
    pub zc17_term: Vec<Fp2>,
    pub gamma_zs: Fp2,
    pub zs_sc: SumcheckProof,
    pub zs_term: Fp2,
    pub gamma_tab: Fp2,
    pub tab_sc: SumcheckProof,
    /// per table: the masked m~ then the masked h_t~
    pub tab_term: Vec<Fp2>,
    pub mask_open: MaskOpening,
    pub w_open: Opening,
    pub a_open: OpeningZk,
    pub h_open: OpeningZk,
}

impl LayerProofZk {
    pub fn size_bytes(&self) -> usize {
        let coms = 3 * (32 + 8 + 4) + 32;
        let f2 = |v: &Vec<Fp2>| v.len() * 16;
        coms + 16 + self.gu_sc.size_bytes() + f2(&self.gu_term) + 16 + self.d_sc.size_bytes() + f2(&self.d_term)
            + 16 + self.zc20_sc.size_bytes() + f2(&self.zc20_term) + 16 + self.zc17_sc.size_bytes() + f2(&self.zc17_term)
            + 16 + self.zs_sc.size_bytes() + 16 + 16 + self.tab_sc.size_bytes() + f2(&self.tab_term)
            + self.mask_open.size_bytes() + self.w_open.size_bytes() + self.a_open.size_bytes() + self.h_open.size_bytes()
    }
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(self.size_bytes());
        let com = |out: &mut Vec<u8>, c: &Option<Commitment>| {
            let c = c.as_ref().expect("commitment");
            out.extend_from_slice(&c.root);
            out.extend_from_slice(&(c.rows as u64).to_le_bytes());
            out.extend_from_slice(&c.log_cols.to_le_bytes());
        };
        com(&mut out, &self.w_com);
        com(&mut out, &self.a_com);
        out.extend_from_slice(&self.mask_root);
        com(&mut out, &self.h_com);
        let f2 = |out: &mut Vec<u8>, v: &[Fp2]| { for x in v { out.extend_from_slice(&x.to_bytes()); } };
        f2(&mut out, &[self.gu_claim]); self.gu_sc.write_bytes(&mut out); f2(&mut out, &self.gu_term);
        f2(&mut out, &[self.d_claim]); self.d_sc.write_bytes(&mut out); f2(&mut out, &self.d_term);
        f2(&mut out, &[self.gamma20]); self.zc20_sc.write_bytes(&mut out); f2(&mut out, &self.zc20_term);
        f2(&mut out, &[self.gamma17]); self.zc17_sc.write_bytes(&mut out); f2(&mut out, &self.zc17_term);
        f2(&mut out, &[self.gamma_zs]); self.zs_sc.write_bytes(&mut out); f2(&mut out, &[self.zs_term]);
        f2(&mut out, &[self.gamma_tab]); self.tab_sc.write_bytes(&mut out); f2(&mut out, &self.tab_term);
        self.mask_open.write_bytes(&mut out);
        self.w_open.write_bytes(&mut out);
        self.a_open.write_bytes(&mut out);
        self.h_open.write_bytes(&mut out);
        debug_assert_eq!(out.len(), self.size_bytes());
        out
    }
}

/// The host-side Fp2 tables of the zero-checks (the CPU path only).
struct HostTabsZk {
    g8f: Vec<Fp2>, rgf: Vec<Fp2>, a8f: Vec<Fp2>, u8f: Vec<Fp2>, ruf: Vec<Fp2>, h8f: Vec<Fp2>, rhf: Vec<Fp2>,
    hg: Vec<Fp2>, hu: Vec<Fp2>, hh: Vec<Fp2>,
    zf: Vec<Vec<Fp2>>, rdf: Vec<Vec<Fp2>>, hz: Vec<Vec<Fp2>>,
}

pub struct ProveOutputZk {
    pub proof: LayerProofZk,
    pub timings: Vec<(String, f64)>,
    /// the enumerated opening sites (from the mask-site assertions), for the record
    pub sites: Vec<String>,
}

fn absorb_statement(tr: &mut Transcript, st: &Statement) {
    tr.absorb_u64(b"layer", st.l as u64);
    tr.absorb_u64(b"t_rows", st.t_rows as u64);
    tr.absorb(b"shifts", &[st.shifts.0 as u8, st.shifts.1 as u8, st.shifts.2 as u8, st.shifts.3 as u8]);
    tr.absorb(b"table", st.table_digest.as_bytes());
    tr.absorb(b"zk", b"P1");
}

fn absorb_com(tr: &mut Transcript, label: &[u8], c: &Commitment) {
    tr.absorb(label, &c.root);
    tr.absorb_u64(label, c.rows as u64);
}

fn pow2(sh: u32) -> Fp { Fp::new(1u64 << sh) }

fn to_fp2_i32(v: &[i32]) -> Vec<Fp2> { v.par_iter().map(|&x| Fp2::from_i64(x as i64)).collect() }

fn multiplicities(w: &LayerWitness, lay: &Layout) -> Vec<(u64, Vec<u32>)> {
    let tf = lay.tf;
    let tb = lay.tb;
    let mut silu = vec![0u32; 256];
    for &g in &w.g8[..tf] { if (-128..=127).contains(&g) { silu[(g + 128) as usize] += 1; } else { silu[0] += 1; } }
    let mut int8 = vec![0u32; 256];
    for col in [&w.u8v[..tf], &w.h8[..tf]] { for &v in col { if (-128..=127).contains(&v) { int8[(v + 128) as usize] += 1; } else { int8[0] += 1; } } }
    for &v in &w.z[..tb * 3] { if (-128..=127).contains(&v) { int8[(v + 128) as usize] += 1; } else { int8[0] += 1; } }
    let (sg, su, sh, sz) = w.shifts;
    let mut out = vec![(TAG_SILU, silu), (TAG_INT8, int8)];
    let mut shifts: Vec<u32> = vec![sg, su, sh, sz];
    shifts.sort();
    shifts.dedup();
    for s in shifts {
        let mut m = vec![0u32; 1usize << s];
        let cols: Vec<&[i32]> = [(sg, &w.rg[..tf]), (su, &w.ru[..tf]), (sh, &w.rh[..tf]), (sz, &w.rd[..tb * 3])].into_iter().filter(|(c, _)| *c == s).map(|(_, v)| v).collect();
        for col in cols { for &r in col { if r >= 0 && (r as usize) < m.len() { m[r as usize] += 1; } else { m[0] += 1; } } }
        out.push((tag_range(s), m));
    }
    out
}

fn helper_column(l1: &[Fp2], l2: &[Fp2], alpha: Fp2) -> Vec<Fp2> {
    let n = l1.len();
    let mut den: Vec<Fp2> = Vec::with_capacity(2 * n);
    den.extend(l1.iter().map(|v| alpha.sub(*v)));
    den.extend(l2.iter().map(|v| alpha.sub(*v)));
    den.par_chunks_mut(4096).for_each(|c| batch_inverse2(c));
    (0..n).into_par_iter().map(|i| den[i].add(den[n + i])).collect()
}

#[inline(always)]
fn helper_constraint(h: Fp2, l1: Fp2, l2: Fp2, alpha: Fp2) -> Fp2 {
    let d1 = alpha.sub(l1);
    let d2 = alpha.sub(l2);
    h.mul(d1).mul(d2).sub(d1.add(d2))
}

/// The eq table of an opening point's column tail, built once and dotted with every mask row.
struct MaskPoint {
    eq: Vec<Fp2>,
}

impl MaskPoint {
    fn new(tail: &[Fp2], n: usize) -> MaskPoint {
        assert_eq!(1usize << tail.len(), n);
        MaskPoint { eq: eq_table_msb(tail) }
    }
    /// <row, eq(point)> for a full mask row — the mask's MLE at the opening point.
    fn eval(&self, data: &[Fp], row: usize) -> Fp2 {
        let n = self.eq.len();
        data[row * n..(row + 1) * n].iter().zip(self.eq.iter()).fold(Fp2::ZERO, |a, (x, e)| a.add(e.mul_base(*x)))
    }
    fn eval2(&self, data: &[Fp], rows: (usize, usize)) -> Fp2 {
        self.eval(data, rows.0).add(Fp2::U.mul(self.eval(data, rows.1)))
    }
}

/// Evaluate base-field slices of `data` at one point (one eq table).
fn eval_many(data: &[Fp], slices: &[(usize, usize)], point: &[Fp2]) -> Vec<Fp2> {
    let eq = eq_table_msb(point);
    slices.iter().map(|&(off, len)| {
        assert_eq!(len, eq.len());
        data[off..off + len].par_iter().zip(eq.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b))
    }).collect()
}

#[cfg(feature = "gpu-cuda")]
fn dev_of(cm: &pcs::Committed) -> Option<&crate::gpu::DevCommit> {
    match &cm.store { pcs::Store::Device(dc) => Some(dc), _ => None }
}

fn eval_many_dev(cmz: &pcs::CommittedZk, slices: &[(usize, usize)], point: &[Fp2]) -> Vec<Fp2> {
    #[cfg(feature = "gpu-cuda")]
    if let (true, Some(dc)) = (crate::gpu::enabled(), dev_of(&cmz.cm)) {
        let offs: Vec<usize> = slices.iter().map(|&(o, len)| { assert_eq!(len, 1usize << point.len()); o }).collect();
        match crate::gpu::dev_eval_many(dc, &offs, point) {
            Ok(v) => return v,
            Err(e) => eprintln!("[UPERF3-ZA] gpu eval_many declined ({e}); CPU path"),
        }
    }
    eval_many(&cmz.data, slices, point)
}

/// Run one masked sumcheck body (CPU) under the masker: returns (masked rounds, challenges, finals).
fn masked_prove<F>(tables: &mut Vec<Vec<Fp2>>, degree: usize, poly: F, mask: &CfsMask, c: Fp2, tr: &mut Transcript) -> (Vec<Vec<Fp2>>, Vec<Fp2>, Vec<Fp2>)
where
    F: Fn(&[Fp2]) -> Fp2 + Sync,
{
    tr.set_masker(Box::new(CfsMasker { mask: mask.clone(), c, challenges: Vec::new() }));
    let out = sumcheck::prove(tables, degree, poly, tr);
    let (_, masked) = tr.take_masker();
    (masked, out.challenges, out.finals)
}

/// The extension round on the host: absorbs s_k + c g_k, draws rho_k; returns (rho_k, the masked terminals of the private tables).
fn extension<F>(finals: &[Fp2], exts: &[Fp2], degree: usize, poly: F, mask: &CfsMask, c: Fp2, prev: &[Fp2], rounds: &mut Vec<Vec<Fp2>>, tr: &mut Transcript) -> Fp2
where
    F: Fn(&[Fp2]) -> Fp2,
{
    let mut sk = extension_round(finals, exts, degree, poly);
    let gk = mask.round(prev.len(), prev);
    for (x, g) in sk.iter_mut().zip(gk.iter()) { *x = x.add(c.mul(*g)); }
    tr.absorb_fp2(b"sc-round", &sk);
    rounds.push(sk);
    tr.challenge_fp2()
}

/// The claims on A and H shared by the prover and the verifier.
#[allow(clippy::too_many_arguments)]
fn build_claims_zk(zl: &ZkLayout, proof: &LayerProofZk, p2: &[Fp2], p5: &[Fp2], rho20: &[Fp2], rho17: &[Fp2], rho_zs: &[Fp2], rho_tab: &[Fp2], e_gu: Fp2, e_d: Fp2, e20: Fp2, e17: Fp2, e_zs: Fp2, e_tab: Fp2, w_p3: &[Fp2], w_p6: &[Fp2]) -> (Vec<Claim>, Vec<ZClaim>, Vec<ZClaim>) {
    let lay = &zl.lay;
    let one = Fp2::ONE;
    let u = Fp2::U;
    let n = zl.a_n;
    let log_n = n.trailing_zeros();
    let s_w = |off: usize| Slice { offset: off, log_size: LOG_WBLOCK };
    let s_tf = |off: usize| Slice { offset: off, log_size: lay.log_tf };
    let s_tb = |off: usize| Slice { offset: off, log_size: lay.log_tb };
    let s_row = |row: usize| Slice { offset: row * n, log_size: log_n };
    let tail = |p: &[Fp2]| p[p.len() - log_n as usize..].to_vec();
    // W as built
    let mut wc = Vec::new();
    for b in 0..3 { wc.push(Claim { parts: vec![(s_w(lay.wg[b]), one)], point: w_p3.to_vec(), sum: false, value: proof.gu_term[3 + b] }); }
    for b in 0..3 { wc.push(Claim { parts: vec![(s_w(lay.wu[b]), one)], point: w_p3.to_vec(), sum: false, value: proof.gu_term[6 + b] }); }
    for b in 0..3 { wc.push(Claim { parts: vec![(s_w(lay.wd[b]), one)], point: w_p6.to_vec(), sum: false, value: proof.d_term[1 + b] }); }
    // A: masked claims (1 - e) T~(p) + e R~(tail p)
    let masked = |sl: Slice, mask_row: usize, p: &[Fp2], e: Fp2, value: Fp2| ZClaim {
        parts: vec![ZPart { slice: sl, coef: one.sub(e), point: p.to_vec() }, ZPart { slice: s_row(mask_row), coef: e, point: tail(p) }],
        value,
    };
    let mut ac = Vec::new();
    let a_cols = [lay.g8, lay.rg, lay.a8, lay.u8v, lay.ru, lay.h8, lay.rh];
    for (i, off) in a_cols.iter().enumerate() { ac.push(masked(s_tf(*off), zl.a_m20[i], rho20, e20, proof.zc20_term[i])); }
    for b in 0..3 { ac.push(masked(s_tb(lay.x[b]), zl.a_m17[b], rho17, e17, proof.zc17_term[b])); }
    for b in 0..3 { ac.push(masked(s_tb(lay.z[b]), zl.a_m17[3 + b], rho17, e17, proof.zc17_term[3 + b])); }
    for b in 0..3 { ac.push(masked(s_tb(lay.rd[b]), zl.a_m17[6 + b], rho17, e17, proof.zc17_term[6 + b])); }
    for b in 0..3 { ac.push(masked(s_tb(lay.x[b]), zl.a_mgu[b], p2, e_gu, proof.gu_term[b])); }
    ac.push(masked(s_tf(lay.h8), zl.a_md, p5, e_d, proof.d_term[0]));
    // the multiplicity rows at rho_tab (single-row points: the point is the whole tail)
    for (i, t) in zl.tabs.iter().enumerate() {
        ac.push(ZClaim {
            parts: vec![ZPart { slice: s_row(t.a_row), coef: one.sub(e_tab), point: rho_tab.to_vec() }, ZPart { slice: s_row(t.a_mask), coef: e_tab, point: rho_tab.to_vec() }],
            value: proof.tab_term[2 * i],
        });
    }
    // H: Fp2 tables as (re, im) pairs with Fp2 masks
    let masked2 = |re: Slice, im: Slice, mask: (usize, usize), p: &[Fp2], e: Fp2, value: Fp2| ZClaim {
        parts: vec![
            ZPart { slice: re, coef: one.sub(e), point: p.to_vec() },
            ZPart { slice: im, coef: one.sub(e).mul(u), point: p.to_vec() },
            ZPart { slice: s_row(mask.0), coef: e, point: tail(p) },
            ZPart { slice: s_row(mask.1), coef: e.mul(u), point: tail(p) },
        ],
        value,
    };
    let mut hc = Vec::new();
    for (i, (re, im)) in [lay.hg, lay.hu, lay.hh].iter().enumerate() { hc.push(masked2(s_tf(*re), s_tf(*im), zl.h_m20[i], rho20, e20, proof.zc20_term[7 + i])); }
    for b in 0..3 { let (re, im) = lay.hz[b]; hc.push(masked2(s_tb(re), s_tb(im), zl.h_m17[b], rho17, e17, proof.zc17_term[9 + b])); }
    // the zero-sum row u at rho_zs (a single-row point), masked by u'
    hc.push(ZClaim {
        parts: vec![
            ZPart { slice: s_row(zl.h_u.0), coef: one.sub(e_zs), point: rho_zs.to_vec() },
            ZPart { slice: s_row(zl.h_u.1), coef: one.sub(e_zs).mul(u), point: rho_zs.to_vec() },
            ZPart { slice: s_row(zl.h_up.0), coef: e_zs, point: rho_zs.to_vec() },
            ZPart { slice: s_row(zl.h_up.1), coef: e_zs.mul(u), point: rho_zs.to_vec() },
        ],
        value: proof.zs_term,
    });
    // the table-side helpers at rho_tab
    for (i, t) in zl.tabs.iter().enumerate() {
        hc.push(ZClaim {
            parts: vec![
                ZPart { slice: s_row(t.h_re), coef: one.sub(e_tab), point: rho_tab.to_vec() },
                ZPart { slice: s_row(t.h_im), coef: one.sub(e_tab).mul(u), point: rho_tab.to_vec() },
                ZPart { slice: s_row(t.h_mre), coef: e_tab, point: rho_tab.to_vec() },
                ZPart { slice: s_row(t.h_mim), coef: e_tab.mul(u), point: rho_tab.to_vec() },
            ],
            value: proof.tab_term[2 * i + 1],
        });
    }
    // THE LOGUP IDENTITY as one value-0 sum claim: witness helpers - table helpers + the zero-sum row u
    let mut parts = Vec::new();
    for (re, im) in [lay.hg, lay.hu, lay.hh] {
        parts.push(ZPart { slice: s_tf(re), coef: one, point: vec![] });
        parts.push(ZPart { slice: s_tf(im), coef: u, point: vec![] });
    }
    for b in 0..3 {
        let (re, im) = lay.hz[b];
        parts.push(ZPart { slice: s_tb(re), coef: one, point: vec![] });
        parts.push(ZPart { slice: s_tb(im), coef: u, point: vec![] });
    }
    for t in &zl.tabs {
        parts.push(ZPart { slice: s_row(t.h_re), coef: one.neg(), point: vec![] });
        parts.push(ZPart { slice: s_row(t.h_im), coef: u.neg(), point: vec![] });
    }
    parts.push(ZPart { slice: s_row(zl.h_u.0), coef: one, point: vec![] });
    parts.push(ZPart { slice: s_row(zl.h_u.1), coef: u, point: vec![] });
    hc.push(ZClaim { parts, value: Fp2::ZERO });
    (wc, ac, hc)
}

/// The mask functionals of a layer (shared by prover and verifier): the
/// five g_s(rho_s) (values derived from the terminal checks) and the three
/// Gammas (values sent): Gamma20 = c20 G20 - nu0 c_gu G_gu over rows
/// (zc20, gu); Gamma17 = c17 G17 - nu_z c_d G_d over (zc17, d); Gamma_zs = c_zs G_zs.
#[allow(clippy::too_many_arguments)]
fn mask_functionals(specs: &[(usize, usize)], rhos: [&[Fp2]; 6], g_vals: [Fp2; 6], cs: [Fp2; 6], nu0: Fp2, nu_z: Fp2, gammas: [Fp2; 4]) -> Vec<MaskFunctional> {
    let mut fs = Vec::new();
    for s in 0..6 {
        fs.push(MaskFunctional { terms: vec![(s, CfsMask::eval_weights(rhos[s], specs[s].1))], value: g_vals[s] });
    }
    let sw = |s: usize, scale: Fp2| -> Vec<Fp2> { CfsMask::sum_weights(specs[s].0, specs[s].1).iter().map(|w| w.mul(scale)).collect() };
    fs.push(MaskFunctional { terms: vec![(SC_ZC20, sw(SC_ZC20, cs[SC_ZC20])), (SC_GU, sw(SC_GU, nu0.mul(cs[SC_GU]).neg()))], value: gammas[0] });
    fs.push(MaskFunctional { terms: vec![(SC_ZC17, sw(SC_ZC17, cs[SC_ZC17])), (SC_D, sw(SC_D, nu_z.mul(cs[SC_D]).neg()))], value: gammas[1] });
    fs.push(MaskFunctional { terms: vec![(SC_ZSUM, sw(SC_ZSUM, cs[SC_ZSUM]))], value: gammas[2] });
    fs.push(MaskFunctional { terms: vec![(SC_TAB, sw(SC_TAB, cs[SC_TAB]))], value: gammas[3] });
    fs
}


fn pcs_params(params: &LayerParams, min_log: u32) -> PcsParams {
    PcsParams { log_cols: params.log_cols.min(min_log), inv_rate: params.inv_rate, num_col_checks: params.num_col_checks }
}

fn tail_of(p: &[Fp2], log_n: usize) -> Vec<Fp2> {
    p[p.len() - log_n..].to_vec()
}

fn layer_rng(cfg: &ZkConfig, l: usize) -> ZkRng {
    ZkRng::new(cfg.seed, format!("layer-{l}").as_bytes())
}

/// Prove one layer in ZK mode (P1) over the first `t_rows` rows of the witness.
pub fn prove_layer_zk(w: &LayerWitness, t_rows: usize, params: &LayerParams, ntt: &NttTables, cfg: &ZkConfig, tr: &mut Transcript) -> ProveOutputZk {
    use std::time::Instant;
    let mut timings = Vec::new();
    let mut tick = Instant::now();
    let lap = |name: &str, timings: &mut Vec<(String, f64)>, tick: &mut Instant| {
        timings.push((name.to_string(), tick.elapsed().as_secs_f64()));
        *tick = Instant::now();
    };
    let zl = ZkLayout::new(t_rows, params, w.shifts);
    let lay = zl.lay.clone();
    let tf = lay.tf;
    let tb = lay.tb;
    let n = zl.a_n;
    let log_n = n.trailing_zeros() as usize;
    let (sh_g, sh_u, sh_h, sh_z) = w.shifts;
    let st = Statement { l: w.l, t_rows, shifts: w.shifts, table: w.table, table_digest: w.table_digest.clone() };
    absorb_statement(tr, &st);
    let mut rng = layer_rng(cfg, w.l);
    let mut proof = LayerProofZk::default();
    let mut sites: Vec<String> = Vec::new();

    // ---- W data + commit (as built: public weights) ----
    let mut w_data = vec![Fp::ZERO; lay.w_len];
    w_data[lay.wg[0]..lay.wg[0] + D * F].par_iter_mut().zip(w.wg_t.par_iter()).for_each(|(o, &v)| *o = Fp::from_i64(v as i64));
    w_data[lay.wu[0]..lay.wu[0] + D * F].par_iter_mut().zip(w.wu_t.par_iter()).for_each(|(o, &v)| *o = Fp::from_i64(v as i64));
    for b in 0..3 {
        let off = lay.wd[b];
        w_data[off..off + F * 256].par_chunks_mut(256).enumerate().for_each(|(k, row)| {
            for j in 0..256 { row[j] = Fp::from_i64(w.wd_t[k * D + b * 256 + j] as i64); }
        });
    }
    let w_pcs = pcs_params(params, LOG_WBLOCK);
    let w_cm = pcs::commit(&w_pcs, &w_data, ntt);
    proof.w_com = Some(w_cm.commitment());
    absorb_com(tr, b"W", proof.w_com.as_ref().unwrap());
    lap("commit W", &mut timings, &mut tick);

    // ---- A data + mask rows + ZK commit ----
    let mut a_data = vec![Fp::ZERO; zl.a_len];
    for (off, col) in [(lay.g8, &w.g8), (lay.rg, &w.rg), (lay.a8, &w.a8), (lay.u8v, &w.u8v), (lay.ru, &w.ru), (lay.h8, &w.h8), (lay.rh, &w.rh)] {
        a_data[off..off + tf].par_iter_mut().zip(col[..tf].par_iter()).for_each(|(o, &v)| *o = Fp::from_i64(v as i64));
    }
    for b in 0..3 {
        let (xo, zo, ro) = (lay.x[b], lay.z[b], lay.rd[b]);
        a_data[xo..xo + tb].par_chunks_mut(256).enumerate().for_each(|(t, row)| { for k in 0..256 { row[k] = Fp::from_i64(w.x[t * D + b * 256 + k] as i64); } });
        a_data[zo..zo + tb].par_chunks_mut(256).enumerate().for_each(|(t, row)| { for k in 0..256 { row[k] = Fp::from_i64(w.z[t * D + b * 256 + k] as i64); } });
        a_data[ro..ro + tb].par_chunks_mut(256).enumerate().for_each(|(t, row)| { for k in 0..256 { row[k] = Fp::from_i64(w.rd[t * D + b * 256 + k] as i64); } });
    }
    // the multiplicity tables as rows of A (committed before alpha)
    let mut mults = multiplicities(w, &lay);
    while mults.len() < zl.tabs.len() { mults.push((0, Vec::new())); }
    assert_eq!(mults.len(), zl.tabs.len());
    for (t, (tag, m)) in zl.tabs.iter().zip(mults.iter()) {
        assert_eq!(*tag, t.tag);
        assert_eq!(m.len(), t.size);
        for (j, &c) in m.iter().enumerate() { a_data[t.a_row * n + j] = Fp::new(c as u64); }
    }
    for r in zl.a_mask_rows().into_iter().chain(std::iter::once(zl.a_prox)) {
        let v = rng.fp_vec(n);
        a_data[r * n..(r + 1) * n].copy_from_slice(&v);
    }
    let a_pcs = pcs_params(params, lay.log_tb);
    let a_zk = ZkOpts::standard(&a_pcs);
    let mut a_cmz = pcs::commit_zk_owned(&a_pcs, a_data, ntt, &a_zk, &mut rng);
    a_cmz.mask_rows = zl.a_mask_rows();
    let a_data: &[Fp] = &a_cmz.data;
    a_cmz.prox_mask_row = Some(zl.a_prox);
    proof.a_com = Some(a_cmz.commitment());
    absorb_com(tr, b"A", proof.a_com.as_ref().unwrap());
    lap("commit A (zk)", &mut timings, &mut tick);

    // ---- the mask commitment (the CFS masking polynomials of the five sumchecks) ----
    let specs = mask_specs(&lay, a_pcs.log_cols);
    let mc = mask_commit(&specs, ntt, &mut rng);
    proof.mask_root = mc.tree.root();
    tr.absorb(b"M", &proof.mask_root);
    lap("mask commit", &mut timings, &mut tick);

    // ---- challenges, helpers + the table-side helpers + mask rows, ZK commit H ----
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_silu = gamma.mul_base(Fp::new(TAG_SILU));
    let g_int8 = gamma.mul_base(Fp::new(TAG_INT8));
    let g_rg = gamma.mul_base(Fp::new(tag_range(sh_g)));
    let g_ru = gamma.mul_base(Fp::new(tag_range(sh_u)));
    let g_rh = gamma.mul_base(Fp::new(tag_range(sh_h)));
    let g_rd = gamma.mul_base(Fp::new(tag_range(sh_z)));
    let h_pcs = pcs_params(params, lay.log_tb);
    let h_zk = ZkOpts::standard(&h_pcs);
    // [UPERF3-ZA] the device path (HL_GPU=1): the helper columns on the device (XX's kernels) into a
    // buffer of the ZK length; the host-generated tail rows are uploaded; the zero-check tables are
    // built on the device, so no host helper columns exist on this path.
    #[cfg(feature = "gpu-cuda")]
    let use_dev_h = crate::gpu::enabled() && dev_of(&a_cmz.cm).is_some();
    #[cfg(not(feature = "gpu-cuda"))]
    let use_dev_h = false;
    let mut host_tabs: Option<HostTabsZk> = None;
    let mut h_data = vec![Fp::ZERO; zl.h_len];
    if !use_dev_h {
        let g8f = to_fp2_i32(&w.g8[..tf]);
        let a8f = to_fp2_i32(&w.a8[..tf]);
        let rgf = to_fp2_i32(&w.rg[..tf]);
        let u8f = to_fp2_i32(&w.u8v[..tf]);
        let ruf = to_fp2_i32(&w.ru[..tf]);
        let h8f = to_fp2_i32(&w.h8[..tf]);
        let rhf = to_fp2_i32(&w.rh[..tf]);
        let hg = {
            let lg: Vec<Fp2> = g8f.par_iter().zip(a8f.par_iter()).map(|(g, a)| g.add(beta.mul(*a)).add(g_silu)).collect();
            let lrg: Vec<Fp2> = rgf.par_iter().map(|r| r.add(g_rg)).collect();
            helper_column(&lg, &lrg, alpha)
        };
        let hu = {
            let lu: Vec<Fp2> = u8f.par_iter().map(|v| v.add(g_int8)).collect();
            let lru: Vec<Fp2> = ruf.par_iter().map(|r| r.add(g_ru)).collect();
            helper_column(&lu, &lru, alpha)
        };
        let hh = {
            let lh: Vec<Fp2> = h8f.par_iter().map(|v| v.add(g_int8)).collect();
            let lrh: Vec<Fp2> = rhf.par_iter().map(|r| r.add(g_rh)).collect();
            helper_column(&lh, &lrh, alpha)
        };
        let mut zf: Vec<Vec<Fp2>> = Vec::new();
        let mut rdf: Vec<Vec<Fp2>> = Vec::new();
        let mut hz: Vec<Vec<Fp2>> = Vec::new();
        for b in 0..3 {
            let z_b: Vec<Fp2> = a_data[lay.z[b]..lay.z[b] + tb].par_iter().map(|v| Fp2::from_base(*v)).collect();
            let rd_b: Vec<Fp2> = a_data[lay.rd[b]..lay.rd[b] + tb].par_iter().map(|v| Fp2::from_base(*v)).collect();
            let lz: Vec<Fp2> = z_b.par_iter().map(|v| v.add(g_int8)).collect();
            let lrd: Vec<Fp2> = rd_b.par_iter().map(|r| r.add(g_rd)).collect();
            hz.push(helper_column(&lz, &lrd, alpha));
            zf.push(z_b);
            rdf.push(rd_b);
        }
        for (col, (ore, oim)) in [(&hg, lay.hg), (&hu, lay.hu), (&hh, lay.hh)] {
            h_data[ore..ore + tf].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c0);
            h_data[oim..oim + tf].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c1);
        }
        for b in 0..3 {
            let (ore, oim) = lay.hz[b];
            h_data[ore..ore + tb].par_iter_mut().zip(hz[b].par_iter()).for_each(|(o, v)| *o = v.c0);
            h_data[oim..oim + tb].par_iter_mut().zip(hz[b].par_iter()).for_each(|(o, v)| *o = v.c1);
        }
        host_tabs = Some(HostTabsZk { g8f, rgf, a8f, u8f, ruf, h8f, rhf, hg, hu, hh, zf, rdf, hz });
    }
    // the table-side helpers h_t = m / (alpha - tval) (zero beyond each table)
    let tvals: Vec<Vec<Fp2>> = zl.tabs.iter().map(|t| tval_row(t.tag, t.size, n, &w.table, beta, gamma)).collect();
    for (t, (tv, (_, m))) in zl.tabs.iter().zip(tvals.iter().zip(mults.iter())) {
        let mut den: Vec<Fp2> = tv[..t.size].iter().map(|v| alpha.sub(*v)).collect();
        batch_inverse2(&mut den);
        for j in 0..t.size {
            let h = den[j].mul_base(Fp::new(m[j] as u64));
            h_data[t.h_re * n + j] = h.c0;
            h_data[t.h_im * n + j] = h.c1;
        }
    }
    // mask rows: the 12 Fp2 masks (24 rows), u' (2), the prox row, the table masks; then the zero-sum u (2)
    let mut plain_rows: Vec<usize> = Vec::new();
    for (a, b) in zl.h_m20.iter().chain(zl.h_m17.iter()) { plain_rows.push(*a); plain_rows.push(*b); }
    plain_rows.extend([zl.h_up.0, zl.h_up.1, zl.h_prox]);
    for t in &zl.tabs { plain_rows.push(t.h_mre); plain_rows.push(t.h_mim); }
    for r in plain_rows {
        let v = rng.fp_vec(n);
        h_data[r * n..(r + 1) * n].copy_from_slice(&v);
    }
    for r in [zl.h_u.0, zl.h_u.1] {
        let mut sum = Fp::ZERO;
        for j in 0..n - 1 { let v = rng.fp(); h_data[r * n + j] = v; sum = sum.add(v); }
        h_data[r * n + n - 1] = sum.neg();
    }
    #[cfg(feature = "gpu-cuda")]
    let h_cmz_dev: Option<pcs::CommittedZk> = if use_dev_h {
        use crate::gpu::HelperSpec;
        let a_dc = dev_of(&a_cmz.cm).unwrap();
        let mut specs = vec![
            HelperSpec { off_v1: lay.g8, off_w: Some(lay.a8), off_v2: lay.rg, len: tf, c1: g_silu, c2: g_rg, off_re: lay.hg.0, off_im: lay.hg.1 },
            HelperSpec { off_v1: lay.u8v, off_w: None, off_v2: lay.ru, len: tf, c1: g_int8, c2: g_ru, off_re: lay.hu.0, off_im: lay.hu.1 },
            HelperSpec { off_v1: lay.h8, off_w: None, off_v2: lay.rh, len: tf, c1: g_int8, c2: g_rh, off_re: lay.hh.0, off_im: lay.hh.1 },
        ];
        for b in 0..3 {
            specs.push(HelperSpec { off_v1: lay.z[b], off_w: None, off_v2: lay.rd[b], len: tb, c1: g_int8, c2: g_rd, off_re: lay.hz[b].0, off_im: lay.hz[b].1 });
        }
        let rows = zl.h_len / n;
        let (mut d_h, _sums) = crate::gpu::dev_helpers(a_dc, zl.h_len, &specs, alpha, beta).expect("gpu helpers (zk)");
        crate::gpu::dev_upload_rows(&mut d_h, lay.h_len, &h_data[lay.h_len..zl.h_len]).expect("gpu upload of the H tail rows");
        Some(pcs::commit_zk_device(&h_pcs, d_h, rows, std::mem::take(&mut h_data), ntt, &h_zk, &mut rng).expect("gpu zk commit H"))
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let h_cmz_dev: Option<pcs::CommittedZk> = None;
    let mut h_cmz = match h_cmz_dev {
        Some(c) => c,
        None => pcs::commit_zk_owned(&h_pcs, std::mem::take(&mut h_data), ntt, &h_zk, &mut rng),
    };
    h_cmz.mask_rows = zl.h_mask_rows();
    let h_data: &[Fp] = &h_cmz.data;
    h_cmz.prox_mask_row = Some(zl.h_prox);
    proof.h_com = Some(h_cmz.commitment());
    absorb_com(tr, b"H", proof.h_com.as_ref().unwrap());
    lap("helpers + commit H (zk)", &mut timings, &mut tick);

    // ---- g/u matmul sumcheck (masked; the claimed sum sent masked; the X terminals masked) ----
    let r_i = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_j = tr.challenge_fp2_vec(11);
    let lam_gu = tr.challenge_fp2();
    let mut p1 = r_i.clone();
    p1.extend_from_slice(&r_j);
    let ev = eval_many_dev(&a_cmz, &[(lay.g8, tf), (lay.rg, tf), (lay.u8v, tf), (lay.ru, tf)], &p1);
    let s_gu = ev[0].mul_base(pow2(sh_g)).add(ev[1]).add(lam_gu.mul(ev[2].mul_base(pow2(sh_u)).add(ev[3])));
    let c_gu = tr.challenge_fp2();
    let g_gu_total = mc.masks[SC_GU].total();
    proof.gu_claim = s_gu.add(c_gu.mul(g_gu_total));
    tr.absorb_fp2(b"gu-claim", &[proof.gu_claim]);
    let eq_ri = eq_table_msb(&r_i);
    let eq_rj = eq_table_msb(&r_j);
    let xk = fold_rows_i8(&w.x[..t_rows * D], t_rows, D, &eq_ri);
    let wgk = fold_cols_i8(&w.wg_t, D, F, &eq_rj);
    let wuk = fold_cols_i8(&w.wu_t, D, F, &eq_rj);
    let mut tables: Vec<Vec<Fp2>> = Vec::new();
    for b in 0..3 { tables.push(xk[b * 256..(b + 1) * 256].to_vec()); }
    for b in 0..3 { tables.push(wgk[b * 256..(b + 1) * 256].iter().zip(wuk[b * 256..(b + 1) * 256].iter()).map(|(g, u)| g.add(lam_gu.mul(*u))).collect()); }
    let gu_poly = |v: &[Fp2]| v[0].mul(v[3]).add(v[1].mul(v[4])).add(v[2].mul(v[5]));
    let (mut gu_rounds, r_kp, gu_fin) = masked_prove(&mut tables, 2, gu_poly, &mc.masks[SC_GU], c_gu, tr);
    let mut p2 = r_i.clone();
    p2.extend_from_slice(&r_kp);
    let p2_tail = tail_of(&p2, log_n);
    let mp = MaskPoint::new(&p2_tail, n);
    let mut exts = vec![Fp2::ZERO; 6];
    for b in 0..3 { exts[b] = mp.eval(&a_data, zl.a_mgu[b]); }
    let e_gu = extension(&gu_fin, &exts, 2, gu_poly, &mc.masks[SC_GU], c_gu, &r_kp, &mut gu_rounds, tr);
    proof.gu_sc = SumcheckProof { rounds: gu_rounds };
    let mut term = Vec::with_capacity(9);
    for b in 0..3 { term.push(masked_terminal(gu_fin[b], exts[b], e_gu)); }
    for b in 0..3 { term.push(eval_mle_ext(&wgk[b * 256..(b + 1) * 256], &r_kp)); }
    for b in 0..3 { term.push(eval_mle_ext(&wuk[b * 256..(b + 1) * 256], &r_kp)); }
    proof.gu_term = term;
    tr.absorb_fp2(b"gu-term", &proof.gu_term);
    let mut rho_gu = r_kp.clone();
    rho_gu.push(e_gu);
    let mut p3 = r_kp.clone();
    p3.extend_from_slice(&r_j);
    lap("matmul g/u (zk)", &mut timings, &mut tick);

    // ---- d matmul sumcheck (masked) ----
    let r_ip = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_jp = tr.challenge_fp2_vec(8);
    let lam_d = tr.challenge_fp2_vec(3);
    let mut p4 = r_ip.clone();
    p4.extend_from_slice(&r_jp);
    let ev = eval_many_dev(&a_cmz, &[(lay.z[0], tb), (lay.rd[0], tb), (lay.z[1], tb), (lay.rd[1], tb), (lay.z[2], tb), (lay.rd[2], tb)], &p4);
    let s_d = (0..3).fold(Fp2::ZERO, |a, b| a.add(lam_d[b].mul(ev[2 * b].mul_base(pow2(sh_z)).add(ev[2 * b + 1]))));
    let c_d = tr.challenge_fp2();
    let g_d_total = mc.masks[SC_D].total();
    proof.d_claim = s_d.add(c_d.mul(g_d_total));
    tr.absorb_fp2(b"d-claim", &[proof.d_claim]);
    let eq_rip = eq_table_msb(&r_ip);
    let eq_rjp = eq_table_msb(&r_jp);
    let hk = fold_rows_i32(&w.h8[..tf], t_rows, F, &eq_rip);
    let mut cw = vec![Fp2::ZERO; D];
    for b in 0..3 { for j in 0..256 { cw[b * 256 + j] = lam_d[b].mul(eq_rjp[j]); } }
    let wdk = fold_cols_i8(&w.wd_t, F, D, &cw);
    let mut tables = vec![hk, wdk];
    let d_poly = |v: &[Fp2]| v[0].mul(v[1]);
    let (mut d_rounds, r_k, d_fin) = masked_prove(&mut tables, 2, d_poly, &mc.masks[SC_D], c_d, tr);
    let mut p5 = r_ip.clone();
    p5.extend_from_slice(&r_k);
    let p5_tail = tail_of(&p5, log_n);
    let exts = vec![MaskPoint::new(&p5_tail, n).eval(&a_data, zl.a_md), Fp2::ZERO];
    let e_d = extension(&d_fin, &exts, 2, d_poly, &mc.masks[SC_D], c_d, &r_k, &mut d_rounds, tr);
    proof.d_sc = SumcheckProof { rounds: d_rounds };
    let mut term = vec![masked_terminal(d_fin[0], exts[0], e_d)];
    for b in 0..3 {
        let wdb = fold_cols_base(&w_data[lay.wd[b]..lay.wd[b] + F * 256], F, 256, &eq_rjp);
        term.push(eval_mle_ext(&wdb, &r_k));
    }
    proof.d_term = term;
    tr.absorb_fp2(b"d-term", &proof.d_term);
    let mut rho_d = r_k.clone();
    rho_d.push(e_d);
    let mut p6 = r_k.clone();
    p6.extend_from_slice(&r_jp);
    lap("matmul d (zk)", &mut timings, &mut tick);

    // ---- zero-check 20 (masked; claim nu0 S''_gu + Gamma20) ----
    let tau = tr.challenge_fp2_vec(lay.log_tf as usize);
    let mu = tr.challenge_fp2_vec(4);
    let nu0 = tr.challenge_fp2();
    let nu = [nu0, nu0.mul(lam_gu), Fp2::ZERO];
    let c20 = tr.challenge_fp2();
    proof.gamma20 = c20.mul(mc.masks[SC_ZC20].total()).sub(nu0.mul(c_gu).mul(g_gu_total));
    tr.absorb_fp2(b"gamma20", &[proof.gamma20]);
    let (p_g, p_u, p_h) = (pow2(sh_g), pow2(sh_u), pow2(sh_h));
    let mu_c = mu.clone();
    let zc20_poly = move |v: &[Fp2]| -> Fp2 {
        let (eqt, eq1, eq5) = (v[0], v[1], v[2]);
        let (g8, rg, a8, u8, ru, h8, rh, hg, hu, hh) = (v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12]);
        let c_had = a8.mul(u8).sub(h8.mul_base(p_h)).sub(rh);
        let c_hg = helper_constraint(hg, g8.add(beta.mul(a8)).add(g_silu), rg.add(g_rg), alpha);
        let c_hu = helper_constraint(hu, u8.add(g_int8), ru.add(g_ru), alpha);
        let c_hh = helper_constraint(hh, h8.add(g_int8), rh.add(g_rh), alpha);
        let zc = mu_c[0].mul(c_had).add(mu_c[1].mul(c_hg)).add(mu_c[2].mul(c_hu)).add(mu_c[3].mul(c_hh));
        let fold1 = nu[0].mul(g8.mul_base(p_g).add(rg)).add(nu[1].mul(u8.mul_base(p_u).add(ru)));
        eqt.mul(zc).add(eq1.mul(fold1)).add(eq5.mul(nu[2].mul(h8)))
    };
    #[cfg(feature = "gpu-cuda")]
    let dev20 = if let (true, Some(a_dc), Some(h_dc)) = (crate::gpu::enabled(), dev_of(&a_cmz.cm), dev_of(&h_cmz.cm)) {
        use crate::gpu::TabSpec;
        let specs = vec![
            TabSpec::Eq(&tau), TabSpec::Eq(&p1), TabSpec::Eq(&p5),
            TabSpec::FromFp(a_dc, lay.g8, tf), TabSpec::FromFp(a_dc, lay.rg, tf), TabSpec::FromFp(a_dc, lay.a8, tf),
            TabSpec::FromFp(a_dc, lay.u8v, tf), TabSpec::FromFp(a_dc, lay.ru, tf), TabSpec::FromFp(a_dc, lay.h8, tf), TabSpec::FromFp(a_dc, lay.rh, tf),
            TabSpec::FromFp2(h_dc, lay.hg.0, lay.hg.1, tf), TabSpec::FromFp2(h_dc, lay.hu.0, lay.hu.1, tf), TabSpec::FromFp2(h_dc, lay.hh.0, lay.hh.1, tf),
        ];
        let mut prm: Vec<u64> = Vec::new();
        for v in [alpha, beta, g_silu, g_rg, g_ru, g_rh, g_int8, mu[0], mu[1], mu[2], mu[3], nu[0], nu[1], nu[2]] {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        prm.extend([p_g.0, p_u.0, p_h.0]);
        tr.set_masker(Box::new(CfsMasker { mask: mc.masks[SC_ZC20].clone(), c: c20, challenges: Vec::new() }));
        let out = crate::gpu::dev_zerocheck(0, &specs, &prm, tr).expect("gpu zero-check 20 (zk)");
        let (_, masked) = tr.take_masker();
        Some((masked, out.challenges, out.finals))
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let dev20: Option<(Vec<Vec<Fp2>>, Vec<Fp2>, Vec<Fp2>)> = None;
    let (mut rounds20, rho20, fin20) = match dev20 {
        Some(x) => x,
        None => {
            let ht = host_tabs.as_mut().expect("zero-check 20 (zk): no host tables on the device path");
            let mut tables: Vec<Vec<Fp2>> = vec![
                eq_table_msb(&tau), eq_table_msb(&p1), eq_table_msb(&p5),
                std::mem::take(&mut ht.g8f), std::mem::take(&mut ht.rgf), std::mem::take(&mut ht.a8f), std::mem::take(&mut ht.u8f),
                std::mem::take(&mut ht.ruf), std::mem::take(&mut ht.h8f), std::mem::take(&mut ht.rhf),
                std::mem::take(&mut ht.hg), std::mem::take(&mut ht.hu), std::mem::take(&mut ht.hh),
            ];
            masked_prove(&mut tables, 4, &zc20_poly, &mc.masks[SC_ZC20], c20, tr)
        }
    };
    let t20 = tail_of(&rho20, log_n);
    let mp = MaskPoint::new(&t20, n);
    let mut exts = vec![Fp2::ZERO; 13];
    for i in 0..7 { exts[3 + i] = mp.eval(&a_data, zl.a_m20[i]); }
    for i in 0..3 { exts[10 + i] = mp.eval2(&h_data, zl.h_m20[i]); }
    let e20 = extension(&fin20, &exts, 4, &zc20_poly, &mc.masks[SC_ZC20], c20, &rho20, &mut rounds20, tr);
    proof.zc20_sc = SumcheckProof { rounds: rounds20 };
    proof.zc20_term = (3..13).map(|i| masked_terminal(fin20[i], exts[i], e20)).collect();
    tr.absorb_fp2(b"zc20-term", &proof.zc20_term);
    let mut rho20e = rho20.clone();
    rho20e.push(e20);
    lap("zero-check 20 (zk)", &mut timings, &mut tick);

    // ---- zero-check 17 (masked; claim nu_z S''_d + Gamma17) ----
    let tau2 = tr.challenge_fp2_vec(lay.log_tb as usize);
    let mu2 = tr.challenge_fp2_vec(3);
    let nu_z = tr.challenge_fp2();
    let nu_zb = [nu_z.mul(lam_d[0]), nu_z.mul(lam_d[1]), nu_z.mul(lam_d[2])];
    let c17 = tr.challenge_fp2();
    proof.gamma17 = c17.mul(mc.masks[SC_ZC17].total()).sub(nu_z.mul(c_d).mul(g_d_total));
    tr.absorb_fp2(b"gamma17", &[proof.gamma17]);
    let p_z = pow2(sh_z);
    let mu2_c = mu2.clone();
    let zc17_poly = move |v: &[Fp2]| -> Fp2 {
        let (eqt, _eq2, eq4) = (v[0], v[1], v[2]);
        let mut zc = Fp2::ZERO;
        let mut fz = Fp2::ZERO;
        for b in 0..3 {
            let (z, rd, h) = (v[6 + b], v[9 + b], v[12 + b]);
            zc = zc.add(mu2_c[b].mul(helper_constraint(h, z.add(g_int8), rd.add(g_rd), alpha)));
            fz = fz.add(nu_zb[b].mul(z.mul_base(p_z).add(rd)));
        }
        eqt.mul(zc).add(eq4.mul(fz))
    };
    #[cfg(feature = "gpu-cuda")]
    let dev17 = if let (true, Some(a_dc), Some(h_dc)) = (crate::gpu::enabled(), dev_of(&a_cmz.cm), dev_of(&h_cmz.cm)) {
        use crate::gpu::TabSpec;
        let mut specs = vec![TabSpec::Eq(&tau2), TabSpec::Eq(&p2), TabSpec::Eq(&p4)];
        for b in 0..3 { specs.push(TabSpec::FromFp(a_dc, lay.x[b], tb)); }
        for b in 0..3 { specs.push(TabSpec::FromFp(a_dc, lay.z[b], tb)); }
        for b in 0..3 { specs.push(TabSpec::FromFp(a_dc, lay.rd[b], tb)); }
        for b in 0..3 { specs.push(TabSpec::FromFp2(h_dc, lay.hz[b].0, lay.hz[b].1, tb)); }
        let mut prm: Vec<u64> = Vec::new();
        for v in [alpha, g_int8, g_rd, mu2[0], mu2[1], mu2[2], Fp2::ZERO, Fp2::ZERO, Fp2::ZERO, nu_zb[0], nu_zb[1], nu_zb[2]] {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        prm.push(p_z.0);
        tr.set_masker(Box::new(CfsMasker { mask: mc.masks[SC_ZC17].clone(), c: c17, challenges: Vec::new() }));
        let out = crate::gpu::dev_zerocheck(1, &specs, &prm, tr).expect("gpu zero-check 17 (zk)");
        let (_, masked) = tr.take_masker();
        Some((masked, out.challenges, out.finals))
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let dev17: Option<(Vec<Vec<Fp2>>, Vec<Fp2>, Vec<Fp2>)> = None;
    let (mut rounds17, rho17, fin17) = match dev17 {
        Some(x) => x,
        None => {
            let ht = host_tabs.as_mut().expect("zero-check 17 (zk): no host tables on the device path");
            let mut tables: Vec<Vec<Fp2>> = vec![eq_table_msb(&tau2), eq_table_msb(&p2), eq_table_msb(&p4)];
            for b in 0..3 { tables.push(a_data[lay.x[b]..lay.x[b] + tb].par_iter().map(|v| Fp2::from_base(*v)).collect()); }
            for b in 0..3 { tables.push(std::mem::take(&mut ht.zf[b])); }
            for b in 0..3 { tables.push(std::mem::take(&mut ht.rdf[b])); }
            for b in 0..3 { tables.push(std::mem::take(&mut ht.hz[b])); }
            masked_prove(&mut tables, 4, &zc17_poly, &mc.masks[SC_ZC17], c17, tr)
        }
    };
    drop(host_tabs);
    let t17 = tail_of(&rho17, log_n);
    let mp = MaskPoint::new(&t17, n);
    let mut exts = vec![Fp2::ZERO; 15];
    for i in 0..9 { exts[3 + i] = mp.eval(&a_data, zl.a_m17[i]); }
    for b in 0..3 { exts[12 + b] = mp.eval2(&h_data, zl.h_m17[b]); }
    let e17 = extension(&fin17, &exts, 4, &zc17_poly, &mc.masks[SC_ZC17], c17, &rho17, &mut rounds17, tr);
    proof.zc17_sc = SumcheckProof { rounds: rounds17 };
    proof.zc17_term = (3..15).map(|i| masked_terminal(fin17[i], exts[i], e17)).collect();
    tr.absorb_fp2(b"zc17-term", &proof.zc17_term);
    let mut rho17e = rho17.clone();
    rho17e.push(e17);
    lap("zero-check 17 (zk)", &mut timings, &mut tick);

    // ---- the table-side zero-check (masked): eq(tau3) sum_i mu3_i (h_t,i (alpha - tval_i) - m_i) = 0 ----
    let tau3 = tr.challenge_fp2_vec(log_n);
    let mu3 = tr.challenge_fp2_vec(zl.tabs.len());
    let c_tab = tr.challenge_fp2();
    proof.gamma_tab = c_tab.mul(mc.masks[SC_TAB].total());
    tr.absorb_fp2(b"gamma-tab", &[proof.gamma_tab]);
    let n_tabs = zl.tabs.len();
    let mu3c = mu3.clone();
    let tab_poly = move |v: &[Fp2]| -> Fp2 {
        let mut acc = Fp2::ZERO;
        for i in 0..n_tabs {
            let (m, h, tv) = (v[1 + 3 * i], v[2 + 3 * i], v[3 + 3 * i]);
            acc = acc.add(mu3c[i].mul(h.mul(alpha.sub(tv)).sub(m)));
        }
        v[0].mul(acc)
    };
    let mut tables: Vec<Vec<Fp2>> = vec![eq_table_msb(&tau3)];
    for (t, tv) in zl.tabs.iter().zip(tvals.iter()) {
        tables.push((0..n).map(|j| Fp2::from_base(a_data[t.a_row * n + j])).collect());
        tables.push((0..n).map(|j| Fp2::new(h_data[t.h_re * n + j], h_data[t.h_im * n + j])).collect());
        tables.push(tv.clone());
    }
    let (mut rounds_tab, rho_tab, fin_tab) = masked_prove(&mut tables, 3, &tab_poly, &mc.masks[SC_TAB], c_tab, tr);
    drop(tables);
    let mp = MaskPoint::new(&rho_tab, n);
    let mut exts = vec![Fp2::ZERO; 1 + 3 * n_tabs];
    for (i, t) in zl.tabs.iter().enumerate() {
        exts[1 + 3 * i] = mp.eval(&a_data, t.a_mask);
        exts[2 + 3 * i] = mp.eval2(&h_data, (t.h_mre, t.h_mim));
    }
    let e_tab = extension(&fin_tab, &exts, 3, &tab_poly, &mc.masks[SC_TAB], c_tab, &rho_tab, &mut rounds_tab, tr);
    proof.tab_sc = SumcheckProof { rounds: rounds_tab };
    proof.tab_term = (0..n_tabs).flat_map(|i| [masked_terminal(fin_tab[1 + 3 * i], exts[1 + 3 * i], e_tab), masked_terminal(fin_tab[2 + 3 * i], exts[2 + 3 * i], e_tab)]).collect();
    tr.absorb_fp2(b"tab-term", &proof.tab_term);
    let mut rho_tabe = rho_tab.clone();
    rho_tabe.push(e_tab);
    lap("table zero-check (zk)", &mut timings, &mut tick);

    // ---- the zero-sum sumcheck over u (masked; claim Gamma_zs = c_zs G_zs) ----
    let c_zs = tr.challenge_fp2();
    proof.gamma_zs = c_zs.mul(mc.masks[SC_ZSUM].total());
    tr.absorb_fp2(b"gamma-zs", &[proof.gamma_zs]);
    let zs_poly = |v: &[Fp2]| v[0].mul(v[1]);
    let u_tab: Vec<Fp2> = (0..n).map(|j| Fp2::new(h_data[zl.h_u.0 * n + j], h_data[zl.h_u.1 * n + j])).collect();
    let mut tables = vec![vec![Fp2::ONE; n], u_tab];
    let (mut rounds_zs, rho_zs, fin_zs) = masked_prove(&mut tables, 2, zs_poly, &mc.masks[SC_ZSUM], c_zs, tr);
    let exts = vec![Fp2::ZERO, MaskPoint::new(&rho_zs, n).eval2(&h_data, zl.h_up)];
    let e_zs = extension(&fin_zs, &exts, 2, zs_poly, &mc.masks[SC_ZSUM], c_zs, &rho_zs, &mut rounds_zs, tr);
    proof.zs_sc = SumcheckProof { rounds: rounds_zs };
    proof.zs_term = masked_terminal(fin_zs[1], exts[1], e_zs);
    tr.absorb_fp2(b"zs-term", &[proof.zs_term]);
    let mut rho_zse = rho_zs.clone();
    rho_zse.push(e_zs);

    // ---- the mask opening: the six g(rho)'s and the four Gammas in one product-form test ----
    let g_vals = [mc.masks[SC_GU].eval(&rho_gu), mc.masks[SC_D].eval(&rho_d), mc.masks[SC_ZC20].eval(&rho20e), mc.masks[SC_ZC17].eval(&rho17e), mc.masks[SC_ZSUM].eval(&rho_zse), mc.masks[SC_TAB].eval(&rho_tabe)];
    let fs = mask_functionals(&specs, [&rho_gu, &rho_d, &rho20e, &rho17e, &rho_zse, &rho_tabe], g_vals, [c_gu, c_d, c20, c17, c_zs, c_tab], nu0, nu_z, [proof.gamma20, proof.gamma17, proof.gamma_zs, proof.gamma_tab]);
    proof.mask_open = mask_open(&mc, &fs, ntt, tr);
    lap("zsum + mask open", &mut timings, &mut tick);

    // ---- PCS openings ----
    let (wc, ac, hc) = build_claims_zk(&zl, &proof, &p2, &p5, &rho20, &rho17, &rho_zs, &rho_tab, e_gu, e_d, e20, e17, e_zs, e_tab, &p3, &p6);
    proof.w_open = pcs::open(&w_cm, &wc, tr);
    drop(w_cm);
    {
        let groups_a = pcs::zk_groups_for_record(&a_cmz, &ac);
        sites.push(format!("A: {} claims in {} groups", ac.len(), groups_a));
    }
    proof.a_open = pcs::open_zk(&a_cmz, &ac, tr);
    sites.extend(pcs::last_mask_sites().into_iter().map(|s| format!("A {s}")));
    drop(a_cmz);
    proof.h_open = pcs::open_zk(&h_cmz, &hc, tr);
    sites.extend(pcs::last_mask_sites().into_iter().map(|s| format!("H {s}")));
    drop(h_cmz);
    lap("pcs openings (zk)", &mut timings, &mut tick);
    ProveOutputZk { proof, timings, sites }
}

/// Verify one ZK layer proof against the public statement.
pub fn verify_layer_zk(st: &Statement, proof: &LayerProofZk, params: &LayerParams, ntt: &NttTables, tr: &mut Transcript) -> Result<(), String> {
    let vb = std::env::var("HL_TIMING").map(|v| v == "1").unwrap_or(false);
    let t_v0 = std::time::Instant::now();
    let mut t_last = 0.0f64;
    let mut lapv = |name: &str| {
        if vb {
            let t = t_v0.elapsed().as_secs_f64();
            eprintln!("[verify_layer_zk] {name:<22} {:.4} s", t - t_last);
            t_last = t;
        }
    };
    let zl = ZkLayout::new(st.t_rows, params, st.shifts);
    let lay = zl.lay.clone();
    let n = zl.a_n;
    let log_n = n.trailing_zeros() as usize;
    let (sh_g, sh_u, sh_h, sh_z) = st.shifts;
    absorb_statement(tr, st);
    let w_com = proof.w_com.as_ref().ok_or("missing W commitment")?;
    let a_com = proof.a_com.as_ref().ok_or("missing A commitment")?;
    let h_com = proof.h_com.as_ref().ok_or("missing H commitment")?;
    let w_pcs = pcs_params(params, LOG_WBLOCK);
    let a_pcs = pcs_params(params, lay.log_tb);
    let h_pcs = pcs_params(params, lay.log_tb);
    if w_com.rows != lay.w_len / w_pcs.cols() { return Err("W commitment rows".into()); }
    if a_com.rows != zl.a_len / a_pcs.cols() { return Err("A commitment rows".into()); }
    if h_com.rows != zl.h_len / h_pcs.cols() { return Err("H commitment rows".into()); }
    absorb_com(tr, b"W", w_com);
    absorb_com(tr, b"A", a_com);
    let specs = mask_specs(&lay, a_pcs.log_cols);
    tr.absorb(b"M", &proof.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    absorb_com(tr, b"H", h_com);
    let g_silu = gamma.mul_base(Fp::new(TAG_SILU));
    let g_int8 = gamma.mul_base(Fp::new(TAG_INT8));
    let g_rg = gamma.mul_base(Fp::new(tag_range(sh_g)));
    let g_ru = gamma.mul_base(Fp::new(tag_range(sh_u)));
    let g_rh = gamma.mul_base(Fp::new(tag_range(sh_h)));
    let g_rd = gamma.mul_base(Fp::new(tag_range(sh_z)));
    let div = |num: Fp2, c: Fp2| -> Result<Fp2, String> { if c.is_zero() { Err("zero mask challenge".into()) } else { Ok(num.mul(c.inv())) } };

    // ---- g/u ----
    let r_i = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_j = tr.challenge_fp2_vec(11);
    let lam_gu = tr.challenge_fp2();
    let mut p1 = r_i.clone();
    p1.extend_from_slice(&r_j);
    let c_gu = tr.challenge_fp2();
    tr.absorb_fp2(b"gu-claim", &[proof.gu_claim]);
    let (fin, rho_gu) = sumcheck::verify(proof.gu_claim, 2, 9, &proof.gu_sc, tr)?;
    let r_kp = rho_gu[..8].to_vec();
    let e_gu = rho_gu[8];
    if proof.gu_term.len() != 9 { return Err("gu terminal".into()); }
    let sel = Fp2::ONE.sub(e_gu);
    let mut want = Fp2::ZERO;
    for b in 0..3 { want = want.add(proof.gu_term[b].mul(sel.mul(proof.gu_term[3 + b].add(lam_gu.mul(proof.gu_term[6 + b]))))); }
    let g_gu_val = div(fin.sub(want), c_gu)?;
    tr.absorb_fp2(b"gu-term", &proof.gu_term);
    let mut p2 = r_i.clone();
    p2.extend_from_slice(&r_kp);
    let mut p3 = r_kp.clone();
    p3.extend_from_slice(&r_j);

    // ---- d ----
    let r_ip = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_jp = tr.challenge_fp2_vec(8);
    let lam_d = tr.challenge_fp2_vec(3);
    let mut p4 = r_ip.clone();
    p4.extend_from_slice(&r_jp);
    let c_d = tr.challenge_fp2();
    tr.absorb_fp2(b"d-claim", &[proof.d_claim]);
    let (fin, rho_d) = sumcheck::verify(proof.d_claim, 2, 12, &proof.d_sc, tr)?;
    let r_k = rho_d[..11].to_vec();
    let e_d = rho_d[11];
    if proof.d_term.len() != 4 { return Err("d terminal".into()); }
    let wd_comb = (0..3).fold(Fp2::ZERO, |a, b| a.add(lam_d[b].mul(proof.d_term[1 + b])));
    let want = proof.d_term[0].mul(Fp2::ONE.sub(e_d).mul(wd_comb));
    let g_d_val = div(fin.sub(want), c_d)?;
    tr.absorb_fp2(b"d-term", &proof.d_term);
    let mut p5 = r_ip.clone();
    p5.extend_from_slice(&r_k);
    let mut p6 = r_k.clone();
    p6.extend_from_slice(&r_jp);

    // ---- zero-check 20 ----
    let tau = tr.challenge_fp2_vec(lay.log_tf as usize);
    let mu = tr.challenge_fp2_vec(4);
    let nu0 = tr.challenge_fp2();
    let nu = [nu0, nu0.mul(lam_gu), Fp2::ZERO];
    let c20 = tr.challenge_fp2();
    tr.absorb_fp2(b"gamma20", &[proof.gamma20]);
    let claimed = nu0.mul(proof.gu_claim).add(proof.gamma20);
    let (fin, rho20e) = sumcheck::verify(claimed, 4, lay.log_tf as usize + 1, &proof.zc20_sc, tr)?;
    let rho20 = rho20e[..lay.log_tf as usize].to_vec();
    let e20 = rho20e[lay.log_tf as usize];
    if proof.zc20_term.len() != 10 { return Err("zc20 terminal".into()); }
    let g20_val = {
        let v = &proof.zc20_term;
        let (g8, rg, a8, u8, ru, h8, rh, hg, hu, hh) = (v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9]);
        let c_had = a8.mul(u8).sub(h8.mul_base(pow2(sh_h))).sub(rh);
        let c_hg = helper_constraint(hg, g8.add(beta.mul(a8)).add(g_silu), rg.add(g_rg), alpha);
        let c_hu = helper_constraint(hu, u8.add(g_int8), ru.add(g_ru), alpha);
        let c_hh = helper_constraint(hh, h8.add(g_int8), rh.add(g_rh), alpha);
        let zc = mu[0].mul(c_had).add(mu[1].mul(c_hg)).add(mu[2].mul(c_hu)).add(mu[3].mul(c_hh));
        let fold1 = nu[0].mul(g8.mul_base(pow2(sh_g)).add(rg)).add(nu[1].mul(u8.mul_base(pow2(sh_u)).add(ru)));
        let sel = Fp2::ONE.sub(e20);
        let want = sel.mul(eq_point(&tau, &rho20).mul(zc).add(eq_point(&p1, &rho20).mul(fold1)).add(eq_point(&p5, &rho20).mul(nu[2].mul(h8))));
        div(fin.sub(want), c20)?
    };
    tr.absorb_fp2(b"zc20-term", &proof.zc20_term);

    // ---- zero-check 17 ----
    let tau2 = tr.challenge_fp2_vec(lay.log_tb as usize);
    let mu2 = tr.challenge_fp2_vec(3);
    let nu_z = tr.challenge_fp2();
    let c17 = tr.challenge_fp2();
    tr.absorb_fp2(b"gamma17", &[proof.gamma17]);
    let claimed = nu_z.mul(proof.d_claim).add(proof.gamma17);
    let (fin, rho17e) = sumcheck::verify(claimed, 4, lay.log_tb as usize + 1, &proof.zc17_sc, tr)?;
    let rho17 = rho17e[..lay.log_tb as usize].to_vec();
    let e17 = rho17e[lay.log_tb as usize];
    if proof.zc17_term.len() != 12 { return Err("zc17 terminal".into()); }
    let g17_val = {
        let v = &proof.zc17_term;
        let mut zc = Fp2::ZERO;
        let mut fz = Fp2::ZERO;
        for b in 0..3 {
            let (z, rd, h) = (v[3 + b], v[6 + b], v[9 + b]);
            zc = zc.add(mu2[b].mul(helper_constraint(h, z.add(g_int8), rd.add(g_rd), alpha)));
            fz = fz.add(nu_z.mul(lam_d[b]).mul(z.mul_base(pow2(sh_z)).add(rd)));
        }
        let sel = Fp2::ONE.sub(e17);
        let want = sel.mul(eq_point(&tau2, &rho17).mul(zc).add(eq_point(&p4, &rho17).mul(fz)));
        div(fin.sub(want), c17)?
    };
    tr.absorb_fp2(b"zc17-term", &proof.zc17_term);

    // ---- the table-side zero-check ----
    let tau3 = tr.challenge_fp2_vec(log_n);
    let mu3 = tr.challenge_fp2_vec(zl.tabs.len());
    let c_tab = tr.challenge_fp2();
    tr.absorb_fp2(b"gamma-tab", &[proof.gamma_tab]);
    let (fin, rho_tabe) = sumcheck::verify(proof.gamma_tab, 3, log_n + 1, &proof.tab_sc, tr)?;
    let rho_tab = rho_tabe[..log_n].to_vec();
    let e_tab = rho_tabe[log_n];
    if proof.tab_term.len() != 2 * zl.tabs.len() { return Err("tab terminal".into()); }
    let g_tab_val = {
        let eq = eq_table_msb(&rho_tab);
        let sel = Fp2::ONE.sub(e_tab);
        let mut acc = Fp2::ZERO;
        for (i, t) in zl.tabs.iter().enumerate() {
            let tv = tval_row(t.tag, t.size, n, &st.table, beta, gamma);
            let tv_at = tv.iter().zip(eq.iter()).fold(Fp2::ZERO, |a, (x, e)| a.add(x.mul(*e)));
            let (m, h) = (proof.tab_term[2 * i], proof.tab_term[2 * i + 1]);
            acc = acc.add(mu3[i].mul(h.mul(alpha.sub(sel.mul(tv_at))).sub(m)));
        }
        let want = sel.mul(eq_point(&tau3, &rho_tab)).mul(acc);
        div(fin.sub(want), c_tab)?
    };
    tr.absorb_fp2(b"tab-term", &proof.tab_term);

    // ---- the zero-sum sumcheck ----
    let c_zs = tr.challenge_fp2();
    tr.absorb_fp2(b"gamma-zs", &[proof.gamma_zs]);
    let (fin, rho_zse) = sumcheck::verify(proof.gamma_zs, 2, log_n + 1, &proof.zs_sc, tr)?;
    let rho_zs = rho_zse[..log_n].to_vec();
    let e_zs = rho_zse[log_n];
    let g_zs_val = div(fin.sub(Fp2::ONE.sub(e_zs).mul(proof.zs_term)), c_zs)?;
    tr.absorb_fp2(b"zs-term", &[proof.zs_term]);

    lapv("sumchecks");
    // ---- the mask opening ----
    let fs = mask_functionals(&specs, [&rho_gu, &rho_d, &rho20e, &rho17e, &rho_zse, &rho_tabe], [g_gu_val, g_d_val, g20_val, g17_val, g_zs_val, g_tab_val], [c_gu, c_d, c20, c17, c_zs, c_tab], nu0, nu_z, [proof.gamma20, proof.gamma17, proof.gamma_zs, proof.gamma_tab]);
    mask_verify(&proof.mask_root, &specs, &fs, &proof.mask_open, ntt, tr).map_err(|e| format!("M: {e}"))?;
    lapv("mask opening");

    // ---- PCS openings ----
    let (wc, ac, hc) = build_claims_zk(&zl, proof, &p2, &p5, &rho20, &rho17, &rho_zs, &rho_tab, e_gu, e_d, e20, e17, e_zs, e_tab, &p3, &p6);
    pcs::verify(&w_pcs, w_com, &wc, &proof.w_open, ntt, tr).map_err(|e| format!("W: {e}"))?;
    lapv("W opening");
    pcs::verify_zk(&a_pcs, &ZkOpts::standard(&a_pcs), a_com, &ac, &proof.a_open, ntt, tr).map_err(|e| format!("A: {e}"))?;
    lapv("A opening (zk)");
    pcs::verify_zk(&h_pcs, &ZkOpts::standard(&h_pcs), h_com, &hc, &proof.h_open, ntt, tr).map_err(|e| format!("H: {e}"))?;
    lapv("H opening (zk)");
    Ok(())
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

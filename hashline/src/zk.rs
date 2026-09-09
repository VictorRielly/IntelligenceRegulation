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
//! Randomness: each prover invocation draws 32 secret bytes from the OS
//! for its blake3 stream. Reusing or cloning a default `ZkConfig` does
//! not reuse pads, masks or salts. Explicit `--seed N` selects the old
//! deterministic stream ONLY for test fixtures and CPU/GPU byte gates;
//! it provides no privacy. No production seed is stored in the config
//! or printed. Entropy failure aborts proving; there is no fallback.
//!
//! What remains in the clear under P1 (stated, not hidden): the weights
//! and everything of the W commitment (public by the mode); the shapes,
//! shifts and the table digest; the multiplicity TOTALS (implied by the
//! shape); the masked values above (uniform). The composition of layers
//! and the chained transcript are owed a written simulator (the same
//! caveat class as the lattice line's lemmas Q4.7-Q4.9).

use crate::field::{Fp, Fp2};

// ===========================================================================
// [UPERF3-AM] THE STATEMENT HEADER: WHICH PRIVACY CLAIM, AND WHAT IS CLAIMED
// ABOUT THE OUTPUT.
//
// One binary ships two products (the 2026-09-05 ruling) and, in time, two
// proof FUNCTIONS (docs/zkmatrix-poc/PROOF_FUNCTIONS.md). A verifier has to
// know which claim it is checking, and no proof may be presentable as a
// stronger claim than it delivers. Both facts therefore live in the
// TRANSCRIPT, absorbed immediately after the statement fields and before any
// challenge, so every challenge in the proof depends on them: a verifier that
// checks with the wrong header diverges at the first challenge and REJECTS.
//
// The header has three named parts:
//   priv=  the private set, named exactly (P1 = inputs + activations + the
//          output; P3 = those AND the weights);
//   out=   what is claimed about the OUTPUT -- `commit` (function 1, attested
//          inference: the output is committed and nothing more is claimed) or
//          `commit+pred:<id>` (function 2, validated classification: committed
//          AND a named predicate holds). Function 2's gadget is NOT BUILT in
//          this lane; the SLOT is, so adding it is a variant and not a header
//          redesign;
//   model= the model identity digest, in the same header and under the same
//          transcript as the predicate id, so "acceptable under predicate P
//          against filter model M" cannot be re-presented under another P or M.
//
// ONE FROZEN EXCEPTION: the tuple (P1, commit, no declared model id) keeps the
// legacy tag `P1-v3` (`P1` for the v2 statement) byte for byte, because the
// round-13/14 byte gates and the 8B row 930ce9a0.. freeze it. That tuple IS
// the tuple the legacy tag has always meant; `describe()` prints it in full so
// the declaration is never implicit.
// ===========================================================================

/// The private set a proof claims. Named, not numbered, in the header.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum ZkPrivacy {
    /// FAST TIER: private inputs, every activation (the output plane included)
    /// private; the weights PUBLIC (their commitment is per-model cacheable).
    #[default]
    P1,
    /// FULL TIER: as P1, and the weights private too -- committed hidingly and
    /// RE-COMMITTED with fresh randomness on every proof (a cached hash-based
    /// weight commitment reveals 256 encoded columns per proof and is
    /// recoverable by linear algebra after ~65 of them: lane ZZ,
    /// U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md section 1).
    P3,
}

impl ZkPrivacy {
    pub fn private_set(&self) -> &'static str {
        match self {
            ZkPrivacy::P1 => "in+act+out",
            ZkPrivacy::P3 => "in+act+out+weights",
        }
    }
    pub fn public_set(&self) -> &'static str {
        match self {
            ZkPrivacy::P1 => "weights+shapes+shifts+table-digest",
            ZkPrivacy::P3 => "shapes+shifts+table-digest",
        }
    }
    pub fn long(&self) -> &'static str {
        match self {
            ZkPrivacy::P1 => "private = {the input X, EVERY activation plane including the output z16, the remainders, the multiplicities}; public = {the weights W, the shapes, the signed shifts, the activation-table digest}",
            ZkPrivacy::P3 => "private = {the input X, EVERY activation plane including the output z16, the remainders, the multiplicities, AND the weights W}; public = {the shapes, the signed shifts, the activation-table digest}",
        }
    }
}

/// What the proof claims about the OUTPUT (PROOF_FUNCTIONS.md sections 1-2).
/// THE OUTPUT IS COMMITTED IN EVERY VARIANT -- it is an activation and the ZK
/// path commits every activation, so "uncommitted" would be extra work, not
/// less. What varies is whether anything FURTHER is asserted about it. This is
/// a plain enumerated field, not a predicate framework: a future predicate is a
/// new variant and a new tag, and nothing else here moves.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum OutputClaim {
    /// Function 1, ATTESTED INFERENCE: the output is bound as a commitment and
    /// nothing further is asserted about it.
    #[default]
    Committed,
    /// Function 2, VALIDATED CLASSIFICATION, first (binary) form: committed AND
    /// the single non-negativity fact y[accept] - y[reject] >= 0 is proven
    /// against the deployment's frozen acceptable class. NOT BUILT in this lane
    /// -- the driver refuses it; the variant reserves the transcript slot so the
    /// gadget is added as a variant and not as a header redesign.
    BinaryAcceptable,
}

impl OutputClaim {
    pub fn tag(&self) -> &'static str {
        match self {
            OutputClaim::Committed => "commit",
            OutputClaim::BinaryAcceptable => "commit+pred:binary-acceptable",
        }
    }
}

/// [UPERF3-AN] FUNCTION 2's PREDICATE, in the ONE form PROOF_FUNCTIONS.md section 5
/// rules: a single committed output score against a PUBLIC threshold,
/// `z16[row][col] - tau >= 0`. The acceptable set is FROZEN PER DEPLOYMENT and it
/// IS this triple -- there is no set commitment, no per-proof set and no
/// membership lookup (section 6's generalisations are documented, NOT built).
/// The triple is part of the STATEMENT IDENTITY: it is printed into the header
/// body next to the model identity digest and absorbed under the same
/// transcript, so a proof of "acceptable under this predicate against this
/// model" cannot be re-presented under another predicate or another model.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PredicateSpec {
    /// the row of the committed output plane z16 the score is read from
    pub row: usize,
    /// the output column: the deployment's frozen ACCEPTABLE class
    pub col: usize,
    /// the public threshold; the proof asserts z16[row][col] - tau >= 0
    pub tau: i64,
}

impl PredicateSpec {
    pub fn tag(&self) -> String {
        format!("binary-acceptable(row={},col={},tau={})", self.row, self.col, self.tau)
    }
}

/// The statement header: the privacy mode, the output claim and the model
/// identity, bound together in the transcript.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ZkStatementMode {
    pub privacy: ZkPrivacy,
    pub output: OutputClaim,
    /// The declared model identity digest. `None` means "the W commitment root
    /// in this proof IS the identity", which is true under P1 (the weights are
    /// public and the root is stable per model) and NOT true under P3, where
    /// the root is re-randomised every proof -- see the honesty note in the AM
    /// status section.
    pub model_id: Option<String>,
    /// [UPERF3-AN] the predicate's parameters, present exactly when the output
    /// claim is `BinaryAcceptable`.
    pub pred: Option<PredicateSpec>,
}

impl ZkStatementMode {
    pub fn p1() -> ZkStatementMode {
        ZkStatementMode::default()
    }
    /// [UPERF3-AN] The predicate this statement claims, or `None` for function 1.
    /// The output-claim slot and the parameters must agree: a declared function-2
    /// claim with no parameters names no predicate, and parameters under a
    /// function-1 claim would be proven and not claimed.
    pub fn predicate(&self) -> Result<Option<&PredicateSpec>, String> {
        match (self.output, &self.pred) {
            (OutputClaim::Committed, None) => Ok(None),
            (OutputClaim::BinaryAcceptable, Some(p)) => Ok(Some(p)),
            (OutputClaim::Committed, Some(_)) => {
                Err("a predicate was given under output claim `commit`: function 1 asserts nothing about the output".into())
            }
            (OutputClaim::BinaryAcceptable, None) => {
                Err("output claim `commit+pred:binary-acceptable` with NO predicate parameters (row, col, tau): the statement names no predicate".into())
            }
        }
    }
    /// The `out=` field of the header body: the output claim, with the
    /// predicate's parameters when there is one.
    fn out_tag(&self) -> String {
        match (self.output, &self.pred) {
            (OutputClaim::BinaryAcceptable, Some(p)) => format!("commit+pred:{}", p.tag()),
            (o, _) => o.tag().to_string(),
        }
    }
    fn legacy(&self) -> bool {
        self.privacy == ZkPrivacy::P1 && self.output == OutputClaim::Committed && self.model_id.is_none() && self.pred.is_none()
    }
    fn body(&self, profile: &str) -> Vec<u8> {
        format!(
            "HL-ZK/1|profile={profile}|priv={}|pub={}|out={}|model={}",
            self.privacy.private_set(),
            self.privacy.public_set(),
            self.out_tag(),
            self.model_id.as_deref().unwrap_or("w-root")
        )
        .into_bytes()
    }
    /// The bytes absorbed after the v3 statement fields.
    pub fn header_v3(&self) -> Vec<u8> {
        if self.legacy() { b"P1-v3".to_vec() } else { self.body("v3") }
    }
    /// The bytes absorbed after the v2 statement fields.
    pub fn header_v2(&self) -> Vec<u8> {
        if self.legacy() { b"P1".to_vec() } else { self.body("v2") }
    }
    /// The one-line declaration prover and verifier both print.
    pub fn describe(&self, profile: &str) -> String {
        format!(
            "MODE {} [{profile}] header {:?}: {}; output claim: {}; model identity: {}",
            match self.privacy { ZkPrivacy::P1 => "P1 (fast tier)", ZkPrivacy::P3 => "P3 (full tier)" },
            String::from_utf8_lossy(&if profile == "v3" { self.header_v3() } else { self.header_v2() }),
            self.privacy.long(),
            match (&self.output, &self.pred) {
                (OutputClaim::Committed, _) => "function 1 (attested inference) — the output is committed, nothing more is claimed".to_string(),
                (OutputClaim::BinaryAcceptable, Some(p)) => format!(
                    "function 2 (validated classification, binary form) — the output is committed AND z16[row {}][col {}] - {} >= 0 is PROVEN; the acceptable set is frozen per deployment and is exactly this triple; posture: NO VALID PROOF => REJECT (PROOF_FUNCTIONS.md section 3)",
                    p.row, p.col, p.tau
                ),
                (OutputClaim::BinaryAcceptable, None) => "function 2 DECLARED WITH NO PARAMETERS — this statement names no predicate and will be refused".to_string(),
            },
            match (&self.model_id, self.privacy) {
                (Some(id), _) => format!("declared: {id}"),
                (None, ZkPrivacy::P1) => "the W commitment root (public weights: stable per model)".to_string(),
                (None, ZkPrivacy::P3) => "NONE — the W root is re-randomised every proof; this proof does not name a model".to_string(),
            }
        )
    }
}

/// The ZK configuration. `None` draws fresh OS entropy for EACH proof.
/// `Some(seed)` is a public deterministic test fixture, not a privacy mode.
#[derive(Clone, Debug, Default)]
pub struct ZkConfig {
    pub enabled: bool,
    pub seed: Option<u64>,
    /// [UPERF3-AM] the statement header (privacy mode, output claim, model id).
    pub mode: ZkStatementMode,
}

impl ZkConfig {
    pub fn p3(&self) -> bool {
        self.mode.privacy == ZkPrivacy::P3
    }

    pub fn randomness_label(&self) -> &'static str {
        if self.seed.is_some() { "deterministic-test" } else { "os" }
    }

    fn rng(&self, domain: &[u8]) -> ZkRng {
        match self.seed {
            Some(seed) => ZkRng::new(seed, domain),
            None => ZkRng::from_os(domain)
                .unwrap_or_else(|e| panic!("cannot obtain secret proof randomness: {e}")),
        }
    }
}

// Canonical randomness implementation; legacy API remains available here.
pub use zkp_core::rng::ZkRng;


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
/// [UPERF3-AN] FUNCTION 2's predicate sumcheck (v3 only, and only when a predicate is declared).
pub const SC_PRED: usize = 6;

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
    /// [UPERF3-AM] MODE P3 ONLY: W's HIDING opening. Empty under P1, and an
    /// empty `OpeningZk` writes zero bytes — so the P1 serialization, and every
    /// frozen P1 digest, is untouched by this field.
    pub w_open_zk: OpeningZk,
    pub a_open: OpeningZk,
    pub h_open: OpeningZk,
    /// [UPERF3-AN] FUNCTION 2 ONLY: the predicate gadget. `None` under function 1,
    /// and `None` writes ZERO bytes -- so the function-1 serialization, and every
    /// frozen function-1 digest, is untouched by this field.
    pub pred: Option<PredProofV3>,
}

#[path = "zk_proof_size.rs"]
mod proof_size;
pub use proof_size::{ArgumentBytes, ColumnBytes, MaskOpeningBytes, OpeningBytes, ProofSizeBreakdown};

/// [UPERF3-AN] FUNCTION 2's predicate gadget: ONE masked sumcheck over the
/// d-block cube that binds the committed output to its 16 bit-planes, and its
/// two masked terminals (the output block, then the bit row).
#[derive(Clone, Debug, Default)]
pub struct PredProofV3 {
    pub gamma: Fp2,
    pub sc: SumcheckProof,
    pub term: Vec<Fp2>,
}

impl PredProofV3 {
    pub fn size_bytes(&self) -> usize {
        16 + self.sc.size_bytes() + 16 * self.term.len()
    }
    pub fn write_bytes(&self, out: &mut Vec<u8>) {
        out.extend_from_slice(&self.gamma.to_bytes());
        self.sc.write_bytes(out);
        for x in &self.term { out.extend_from_slice(&x.to_bytes()); }
    }
}

impl LayerProofZk {
    pub fn size_bytes(&self) -> usize {
        let coms = 3 * (32 + 8 + 4) + 32;
        let f2 = |v: &Vec<Fp2>| v.len() * 16;
        coms + 16 + self.gu_sc.size_bytes() + f2(&self.gu_term) + 16 + self.d_sc.size_bytes() + f2(&self.d_term)
            + 16 + self.zc20_sc.size_bytes() + f2(&self.zc20_term) + 16 + self.zc17_sc.size_bytes() + f2(&self.zc17_term)
            + 16 + self.zs_sc.size_bytes() + 16 + 16 + self.tab_sc.size_bytes() + f2(&self.tab_term)
            + self.mask_open.size_bytes() + self.w_open.size_bytes() + self.w_open_zk.size_bytes() + self.a_open.size_bytes() + self.h_open.size_bytes()
            + self.pred.as_ref().map(|p| p.size_bytes()).unwrap_or(0) // [UPERF3-AN]
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
        self.w_open_zk.write_bytes(&mut out);
        self.a_open.write_bytes(&mut out);
        self.h_open.write_bytes(&mut out);
        if let Some(p) = &self.pred { p.write_bytes(&mut out); } // [UPERF3-AN]
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

// A zero multiplier would expose the unmasked claim and rounds. Refuse this
// attempt before absorbing the claim; never redraw on the same transcript.
fn mask_challenge(mut draw: impl FnMut() -> Fp2) -> Fp2 {
    let c = draw();
    assert!(!c.is_zero(), "zero mask challenge: abandon proof attempt");
    c
}

#[cfg(test)]
#[path = "zk_cfs_safety_tests.rs"]
mod cfs_safety_tests;

/// Run one masked sumcheck body (CPU) under the masker: returns (masked rounds, challenges, finals).
pub(crate) fn masked_prove<F>(tables: &mut Vec<Vec<Fp2>>, degree: usize, poly: F, mask: &CfsMask, c: Fp2, tr: &mut Transcript) -> (Vec<Vec<Fp2>>, Vec<Fp2>, Vec<Fp2>)
where
    F: Fn(&[Fp2]) -> Fp2 + Sync,
{
    assert!(!c.is_zero(), "zero mask challenge: abandon proof attempt");
    tr.set_masker(Box::new(CfsMasker { mask: mask.clone(), c, challenges: Vec::new() }));
    let out = sumcheck::prove(tables, degree, poly, tr);
    let (_, masked) = tr.take_masker();
    (masked, out.challenges, out.finals)
}

/// The extension round on the host: absorbs s_k + c g_k, draws rho_k; returns (rho_k, the masked terminals of the private tables).
pub(crate) fn extension<F>(finals: &[Fp2], exts: &[Fp2], degree: usize, poly: F, mask: &CfsMask, c: Fp2, prev: &[Fp2], rounds: &mut Vec<Vec<Fp2>>, tr: &mut Transcript) -> Fp2
where
    F: Fn(&[Fp2]) -> Fp2,
{
    assert!(!c.is_zero(), "zero mask challenge: abandon proof attempt");
    assert_eq!(degree, mask.degree, "masked extension: round degree mismatch");
    let mut sk = extension_round(finals, exts, degree, poly);
    let gk = mask.round(prev.len(), prev);
    assert_eq!(sk.len(), gk.len(), "masked extension: round length mismatch");
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

/// [UPERF3-AN] FUNCTION 2's two extra mask functionals, appended in the same
/// order by prover and verifier: g_pred(rho) recovered from the terminal check,
/// and Gamma_pred = c_pred * G_pred as sent.
fn push_pred_functionals(fs: &mut Vec<MaskFunctional>, specs: &[(usize, usize)], rho_pe: &[Fp2], g_val: Fp2, c_pred: Fp2, gamma: Fp2) {
    let (nv, deg) = specs[SC_PRED];
    fs.push(MaskFunctional { terms: vec![(SC_PRED, CfsMask::eval_weights(rho_pe, deg))], value: g_val });
    let sw: Vec<Fp2> = CfsMask::sum_weights(nv, deg).iter().map(|w| w.mul(c_pred)).collect();
    fs.push(MaskFunctional { terms: vec![(SC_PRED, sw)], value: gamma });
}


fn pcs_params(params: &LayerParams, min_log: u32) -> PcsParams {
    PcsParams { log_cols: params.log_cols.min(min_log), inv_rate: params.inv_rate, num_col_checks: params.num_col_checks }
}

fn tail_of(p: &[Fp2], log_n: usize) -> Vec<Fp2> {
    p[p.len() - log_n..].to_vec()
}

fn layer_rng(cfg: &ZkConfig, l: usize) -> ZkRng {
    cfg.rng(format!("layer-{l}").as_bytes())
}

/// Prove one layer in ZK mode (P1) over the first `t_rows` rows of the witness.
pub fn prove_layer_zk(w: &LayerWitness, t_rows: usize, params: &LayerParams, ntt: &NttTables, cfg: &ZkConfig, tr: &mut Transcript) -> ProveOutputZk {
    assert!(cfg.mode.legacy() && cfg.mode.pred.is_none(),
        "v2 ZK supports only legacy P1; use v3 for private weights, predicates or model declarations");
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
    let c_gu = mask_challenge(|| tr.challenge_fp2());
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
    let c_d = mask_challenge(|| tr.challenge_fp2());
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
    let c20 = mask_challenge(|| tr.challenge_fp2());
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
    let c17 = mask_challenge(|| tr.challenge_fp2());
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
    let c_tab = mask_challenge(|| tr.challenge_fp2());
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
    let c_zs = mask_challenge(|| tr.challenge_fp2());
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
    fn explicit_zero_seed_keeps_legacy_stream_across_refills() {
        let cfg = ZkConfig { seed: Some(0), ..Default::default() };
        let mut legacy = ZkRng::new(0, b"layer-v3-0");
        let mut fixture = cfg.rng(b"layer-v3-0");
        for _ in 0..(8192 / 8 + 16) { assert_eq!(legacy.next_u64(), fixture.next_u64()); }
        assert_eq!(cfg.randomness_label(), "deterministic-test");
    }

    #[test]
    #[cfg(unix)]
    fn cloned_default_configs_never_reuse_a_mask_stream() {
        let cfg = ZkConfig::default();
        assert_eq!(cfg.seed, None);
        assert_eq!(cfg.randomness_label(), "os");
        let mut a = cfg.rng(b"layer-v3-0");
        let mut b = cfg.clone().rng(b"layer-v3-0");
        assert_ne!(a.bytes32(), b.bytes32());
    }


}


// ===========================================================================
// [UPERF3-AD] THE ZK FORM OF THE WIDENED-STACK (v3) STATEMENT — mode P1
// composed with lane ZB's semantics, behind `--zk --profile v3` (round 12).
//
// THE PLAN (rung 0). Every construction of lane ZA above is kept AS BUILT
// — (a) the Ligero-ZK commitments of A and H (Q pad symbols per row on
// the coset 7 G_4n, salted leaves, one uniformly random mask row per
// (private table, opening point)), (b) the CFS-masked sumchecks with the
// last-round extension, (c) the per-layer mask commitment with the
// product-form linear test, (d) committed multiplicities, (e) the seeded
// randomness — and applied to lane ZB's objects:
//   - the BLOCK-STRUCTURED planes (LayoutV3: nb_f f-blocks of g8 / rg /
//     a16 / u16 / ru / h16 / rh, nb_d d-blocks of X / z16 / rd): one mask
//     row per plane per opening point — 7 nb_f at rho_F (zero-check F),
//     3 nb_d at rho_D (zero-check D), nb_d X-blocks at p2 (the g/u matmul
//     terminals), nb_f h16-blocks at p5 (the d matmul terminals), and the
//     proximity row; in H one Fp2 mask (re, im) per helper plane per
//     point (3 nb_f at rho_F, nb_d at rho_D), the zero-sum row u and its
//     extension mask u', a prox row;
//   - the INT16-OUTPUT ACTIVATION TABLE (ACT16: 256 rows, int16 outputs),
//     the INT16 CLASS (2^16 rows, [-32768, 32767]) and the four
//     BALANCED-REMAINDER WINDOWS (one per signed shift, NO dedup, so every
//     layer has exactly 6 table slots) as COMMITTED multiplicity tables:
//     rows of A committed before alpha, each with a mask of its own shape,
//     their table side h_t = m / (alpha - tval) as committed helper rows of
//     H (re, im) with Fp2 masks, the LogUp identity ONE value-0 sum claim.
//     A table larger than a commitment row (the INT16 class is 2^16 rows
//     against n = 2^14 at 12x512; a window of 2^15 rows at sh = 15; every
//     table at the 3x16 shape's n = 2^12) occupies 2^log_size / n
//     CONSECUTIVE rows (log_size = max(log2 size, log n)); its helper and
//     both masks have the same shape. Nothing of a histogram is sent.
//   - the TABLE ZERO-CHECK runs over log_S = max(log n, 16) variables with
//     every slot's m, h_t and public tval zero-extended to 2^log_S; a slot
//     of 2^log_size entries then contributes prod_{j<k}(1 - rho_j) * T~
//     (rho[k..]) with k = log_S - log_size, so its opened claim is the
//     two-part masked claim at the point rho[k..] with that public
//     coefficient; every slot's column tail is the last log n coordinates
//     of rho_tab — one column-weight group for all six slots (as ZA's);
//   - the ROUND-NEAREST REQUANT identities acc = 2^sh y + r (the balanced
//     remainder; the field inverse of 2^-sh as the public coefficient at
//     sh <= 0 with the remainder committed all-zero over the window {0})
//     fold LINEARLY into the masked matmul claims and the two zero-checks
//     exactly as in ZB's form: zero-check F folds the g/u claim (its
//     claimed sum nu0 (S_gu + c_gu G_gu) + Gamma_F with Gamma_F = c_F G_F -
//     nu0 c_gu G_gu proven from the mask commitment), zero-check D folds
//     the d claim likewise; the h16 (at p5) and X (at p2) terminals are
//     opened as masked claims of their own (ZA's open item stands).
// The device path (HL_GPU=1) is ZA's: the ZK commits on the device, the
// helper columns on the device with the host-generated tail rows
// uploaded, the two zero-checks through XX's kernels under the transcript
// masker at the 125M block shape (nb_f 1, nb_d 3) and on the host at any
// other shape (the 7B layer: nb_f 7, nb_d 1). The seeded RNG domain is
// "layer-v3-{l}", so a v3 ZK proof never shares randomness with a v2 one.
// Soundness parameters unchanged and stated: Goldilocks + F_{p^2}
// challenges, RS(n + Q, 4n) on the coset (distance 0.7455), Q = 256
// column checks, (1 - delta/3)^Q = 2^-105.6; the mask commitment RS(1024,
// 4096) with 256 checks. The v2 ZK path (`--zk` alone) and the non-zk
// paths are untouched (the three byte gates re-run at rung 0).
// ===========================================================================

use crate::export_v3::V3Witness;
use crate::layer::{absorb_statement_v3, pow2_signed, rem_index, rem_rows, rem_value, tag_rem_v3, LayoutV3, StatementV3, TAG_ACT16, TAG_INT16};

/// One multiplicity-table slot of the v3 form: its committed histogram m
/// (`rows` consecutive rows of A), its mask (the same shape), its
/// table-side helper h_t = m / (alpha - tval) in H (re, im; `rows` rows
/// each) and the helper's Fp2 mask (re, im).
#[derive(Clone, Debug)]
pub struct TabRowsV3 {
    pub tag: u64,
    pub size: usize,
    /// max(log2 size, log n): the slot's slice size in the commitment
    pub log_size: u32,
    /// 2^log_size / n
    pub rows: usize,
    pub a_row: usize,
    pub a_mask: usize,
    pub h_re: usize,
    pub h_im: usize,
    pub h_mre: usize,
    pub h_mim: usize,
}

/// The table slots of every v3 layer: ACT16, INT16, and one balanced
/// remainder window per signed shift (g, u, h, z) — no dedup, so the
/// count is fixed at 6 (a layout that only depends on the shifts' sizes).
pub const N_TABLE_SLOTS_V3: usize = 6;

pub fn table_specs_v3(shifts: (i32, i32, i32, i32)) -> Vec<(u64, usize)> {
    let (sg, su, sh, sz) = shifts;
    vec![(TAG_ACT16, 256usize), (TAG_INT16, 1usize << 16), (tag_rem_v3(sg), rem_rows(sg)), (tag_rem_v3(su), rem_rows(su)), (tag_rem_v3(sh), rem_rows(sh)), (tag_rem_v3(sz), rem_rows(sz))]
}

/// Which mask row (index into the A or H commitment's rows) masks which (plane, point) of the v3 layer.
pub struct ZkLayoutV3 {
    // Separate experimental schedule; the public legacy constructor always sets false.
    mr1: bool,
    pub lay: LayoutV3,
    pub a_n: usize,
    pub log_n: usize,
    /// the table zero-check's variable count: max(log n, 16)
    pub log_s: usize,
    /// A mask rows: the 7 nb_f f-planes at rho_F, the 3 nb_d d-planes (X, z16, rd) at rho_D,
    /// the nb_d X-blocks at p2, the nb_f h16-blocks at p5, the prox row
    pub a_mf: Vec<usize>,
    pub a_md: Vec<usize>,
    pub a_mgu: Vec<usize>,
    pub a_mdd: Vec<usize>,
    pub a_prox: usize,
    pub a_len: usize,
    /// H mask rows (re, im): the 3 nb_f helper planes at rho_F, the nb_d hz planes at rho_D, u, u', prox
    pub h_mf: Vec<(usize, usize)>,
    pub h_md: Vec<(usize, usize)>,
    pub h_u: (usize, usize),
    pub h_up: (usize, usize),
    pub h_prox: usize,
    pub h_len: usize,
    pub tabs: Vec<TabRowsV3>,
    /// [UPERF3-AM] MODE P3 ONLY (unused under P1, where W is committed plainly).
    /// W's own commitment width and mask rows: ONE mask row per W BLOCK
    /// terminal — a single shared row would leave the DIFFERENCES of two
    /// blocks' evaluations in the clear — plus the reserved proximity row.
    pub w_n: usize,
    pub log_wn: usize,
    /// 2 * nb_d * nb_f rows: the Wg then the Wu blocks, at the g/u point p3
    pub w_mgu: Vec<usize>,
    /// nb_f * nb_d rows: the Wd blocks, at the d point p6
    pub w_mdd: Vec<usize>,
    pub w_prox: usize,
    /// the W commitment's length under P3 (lay.w_len + the mask rows)
    pub w_len_p3: usize,
    /// [UPERF3-AN] FUNCTION 2 ONLY (nothing is allocated under function 1): the
    /// A row holding the 16 bit-planes of the predicate slack in its first 16
    /// columns, and the two mask rows its two opening claims need (one for the
    /// output block, one for the bit row). They are appended AFTER every
    /// existing row, so no offset in the function-1 layout moves.
    pub pred: bool,
    pub a_pb: usize,
    pub a_pmb: usize,
    pub a_pmz: usize,
    // Fresh IO profile only: independent input/output terminal mask pairs.
    a_io: Option<[usize; 2]>,
}

impl ZkLayoutV3 {
    pub fn new(t_rows: usize, d: usize, f: usize, params: &LayerParams, shifts: (i32, i32, i32, i32), pred: bool) -> ZkLayoutV3 {
        Self::with_masks(t_rows, d, f, params, shifts, pred, false)
    }

    fn with_masks(t_rows: usize, d: usize, f: usize, params: &LayerParams, shifts: (i32, i32, i32, i32), pred: bool, mr1: bool) -> Self {
        let width = if mr1 { 2 } else { 1 };
        let lay = LayoutV3::new(t_rows, d, f);
        let log_n = params.log_cols.min(lay.log_a_min) as usize;
        assert!(log_n <= 16, "zk v3: log_cols > 16 is not supported (a table slot would be narrower than a row)");
        let a_n = 1usize << log_n;
        let log_s = log_n.max(16);
        let (nb_d, nb_f) = (lay.nb_d, lay.nb_f);
        let tspecs = table_specs_v3(shifts);
        assert_eq!(tspecs.len(), N_TABLE_SLOTS_V3);
        let mut r = lay.a_len / a_n;
        let mut next = |k: usize| { let v = r; r += k; v };
        let a_mf: Vec<usize> = (0..7 * nb_f).map(|_| next(width)).collect();
        let a_md: Vec<usize> = (0..3 * nb_d).map(|_| next(width)).collect();
        let a_mgu: Vec<usize> = (0..nb_d).map(|_| next(width)).collect();
        let a_mdd: Vec<usize> = (0..nb_f).map(|_| next(width)).collect();
        let a_prox = next(width);
        let mut tabs: Vec<TabRowsV3> = Vec::with_capacity(tspecs.len());
        for &(tag, size) in &tspecs {
            assert!(size.is_power_of_two());
            let log_size = (size.trailing_zeros() as usize).max(log_n) as u32;
            let rows = (1usize << log_size) / a_n;
            let a_row = next(rows);
            let a_mask = next(if mr1 && rows == 1 { 2 } else { rows });
            tabs.push(TabRowsV3 { tag, size, log_size, rows, a_row, a_mask, h_re: 0, h_im: 0, h_mre: 0, h_mim: 0 });
        }
        // [UPERF3-AN] appended LAST, and only for function 2
        let (a_pb, a_pmb, a_pmz) = if pred { (next(1), next(width), next(width)) } else { (0, 0, 0) };
        let a_len = r * a_n;
        let mut r = lay.h_len / a_n;
        let mut next = |k: usize| { let v = r; r += k; v };
        let h_mf: Vec<(usize, usize)> = (0..3 * nb_f).map(|_| (next(1), next(1))).collect();
        let h_md: Vec<(usize, usize)> = (0..nb_d).map(|_| (next(1), next(1))).collect();
        let h_u = (next(1), next(1));
        let h_up = (next(1), next(1));
        let h_prox = next(width);
        for t in tabs.iter_mut() {
            t.h_re = next(t.rows);
            t.h_im = next(t.rows);
            t.h_mre = next(t.rows);
            t.h_mim = next(t.rows);
        }
        let h_len = r * a_n;
        // [UPERF3-AM] the P3 W layout (indices only; nothing is allocated under P1)
        let log_wn = params.log_cols.min(lay.log_wb) as usize;
        let w_n = 1usize << log_wn;
        let mut r = lay.w_len / w_n;
        let mut next = |k: usize| { let v = r; r += k; v };
        let w_mgu: Vec<usize> = (0..2 * nb_d * nb_f).map(|_| next(width)).collect();
        let w_mdd: Vec<usize> = (0..nb_f * nb_d).map(|_| next(width)).collect();
        let w_prox = next(width);
        let w_len_p3 = r * w_n;
        ZkLayoutV3 { mr1, lay, a_n, log_n, log_s, a_mf, a_md, a_mgu, a_mdd, a_prox, a_len, h_mf, h_md, h_u, h_up, h_prox, h_len, tabs, w_n, log_wn, w_mgu, w_mdd, w_prox, w_len_p3, pred, a_pb, a_pmb, a_pmz, a_io: None }
    }

    fn with_io(st: &StatementV3, params: &LayerParams) -> Self {
        let mut zl = Self::with_masks(st.t_rows, st.d, st.f, params, st.shifts, false, true);
        let first = zl.a_len / zl.a_n;
        zl.a_io = Some([first, first + 2]);
        zl.a_len += 4 * zl.a_n;
        zl
    }

    fn mask_range(&self, row: usize) -> std::ops::Range<usize> { row..row + if self.mr1 { 2 } else { 1 } }
    fn eval_mask(&self, mp: &MaskPoint, data: &[Fp], row: usize) -> Fp2 {
        if self.mr1 { mp.eval2(data, (row, row + 1)) } else { mp.eval(data, row) }
    }
    fn pair_claim(&self, mut claim: ZClaim) -> ZClaim {
        if self.mr1 {
            let mut im = claim.parts.last().unwrap().clone();
            im.slice.offset += 1usize << im.slice.log_size;
            im.coef = im.coef.mul(Fp2::U);
            claim.parts.push(im);
        }
        claim
    }

    /// The W mask rows (mode P3 only), in the order `assert_mask_sites` reports.
    pub fn w_mask_rows(&self) -> Vec<usize> {
        let mut v: Vec<usize> = Vec::new();
        for &r in self.w_mgu.iter().chain(&self.w_mdd) { v.extend(self.mask_range(r)); }
        v
    }
    fn a_mask_rows(&self) -> Vec<usize> {
        let mut v: Vec<usize> = Vec::new();
        for &r in self.a_mf.iter().chain(&self.a_md).chain(&self.a_mgu).chain(&self.a_mdd) { v.extend(self.mask_range(r)); }
        for t in &self.tabs { v.extend(t.a_mask..t.a_mask + if self.mr1 && t.rows == 1 { 2 } else { t.rows }); }
        if self.pred { v.extend(self.mask_range(self.a_pmb)); v.extend(self.mask_range(self.a_pmz)); } // [UPERF3-AN]
        if let Some(pairs) = self.a_io { for row in pairs { v.extend(self.mask_range(row)); } }
        v
    }
    fn h_mask_rows(&self) -> Vec<usize> {
        let mut v = Vec::new();
        for (a, b) in self.h_mf.iter().chain(self.h_md.iter()) { v.push(*a); v.push(*b); }
        v.extend([self.h_u.0, self.h_u.1, self.h_up.0, self.h_up.1]);
        for t in &self.tabs { v.extend(t.h_mre..t.h_mre + t.rows); v.extend(t.h_mim..t.h_mim + t.rows); }
        v
    }
    /// [UPERF3-AM] The W mask sites, reported only when the layer is proven in mode P3.
    pub fn describe_w_p3(&self) -> String {
        format!(
            "W masks (P3): commitment {} rows of 2^{} = {} data + {} block masks + 1 prox row; Wg/Wu blocks at p3 -> rows {:?}; Wd blocks at p6 -> rows {:?}; prox row {}",
            self.w_len_p3 / self.w_n, self.log_wn, self.lay.w_len / self.w_n, self.w_mgu.len() + self.w_mdd.len(), self.w_mgu, self.w_mdd, self.w_prox
        )
    }

    /// The enumerated mask sites of the layout (which mask row masks which plane at which point).
    pub fn describe(&self) -> Vec<String> {
        if self.mr1 {
            let mut out = vec![
                format!("ffn-v3-mr1-fresh-poc/1: n={} wn={} pred={}", self.a_n, self.w_n, self.pred),
                format!("A rows={} masks={:?} prox pair={:?}", self.a_len / self.a_n, self.a_mask_rows(), self.mask_range(self.a_prox)),
                format!("H rows={} masks={:?} prox pair={:?} zero-sum pair={:?}", self.h_len / self.a_n, self.h_mask_rows(), self.mask_range(self.h_prox), self.h_u),
                format!("fresh P3 W rows={} masks={:?} prox pair={:?}", self.w_len_p3 / self.w_n, self.w_mask_rows(), self.mask_range(self.w_prox)),
            ];
            for t in &self.tabs { out.push(format!("table tag={} size={} rows={} data={} mask={} kind={}", t.tag, t.size, t.rows, t.a_row, t.a_mask, if t.rows == 1 { "pair" } else { "block" })); }
            return out;
        }
        let lay = &self.lay;
        let mut v = Vec::new();
        v.push(format!(
            "layout: n = 2^{} columns; table zero-check over 2^{} (the INT16 class spans {} rows); A {} rows = {} data + {} masks + {} table/mask rows; H {} rows = {} data + {} masks + {} helper/mask rows",
            self.log_n, self.log_s, self.tabs[1].rows, self.a_len / self.a_n, lay.a_len / self.a_n,
            self.a_mf.len() + self.a_md.len() + self.a_mgu.len() + self.a_mdd.len() + 1, self.tabs.iter().map(|t| 2 * t.rows).sum::<usize>(),
            self.h_len / self.a_n, lay.h_len / self.a_n, 2 * (self.h_mf.len() + self.h_md.len()) + 5, self.tabs.iter().map(|t| 4 * t.rows).sum::<usize>()
        ));
        v.push(format!(
            "A masks: {} f-planes (g8,rg,a16,u16,ru,h16,rh x {} f-blocks) at rho_F -> rows {:?}; {} d-planes (X,z16,rd x {} d-blocks) at rho_D -> rows {:?}; X-blocks at p2 -> {:?}; h16-blocks at p5 -> {:?}; prox row {}",
            self.a_mf.len(), lay.nb_f, self.a_mf, self.a_md.len(), lay.nb_d, self.a_md, self.a_mgu, self.a_mdd, self.a_prox
        ));
        for t in &self.tabs {
            v.push(format!(
                "table slot tag {} ({} entries, 2^{} slice, {} row(s)): m at A rows {}.., mask at A rows {}..; helper h_t at H rows re {}.. im {}.., its mask re {}.. im {}..",
                t.tag, t.size, t.log_size, t.rows, t.a_row, t.a_mask, t.h_re, t.h_im, t.h_mre, t.h_mim
            ));
        }
        v.push(format!(
            "H masks: {} helper planes (hg,hu,hh x {} f-blocks) at rho_F -> rows {:?}; {} hz planes at rho_D -> rows {:?}; zero-sum u rows {:?} (its extension mask u' {:?}) for the value-0 LogUp sum group; prox row {}",
            self.h_mf.len(), lay.nb_f, self.h_mf, self.h_md.len(), self.h_md, self.h_u, self.h_up, self.h_prox
        ));
        v
    }
}

/// The sumchecks of a v3 layer in mask-commitment order (ZA's SC_* slots):
/// gu (log_db vars, degree 2), d (log_fb, 2), zero-check F (log_t + log_fb, 4),
/// zero-check D (log_t + log_db, 4), zsum (log n, 2), table (log_S, 3); +1 each for the extension.
pub fn mask_specs_v3(zl: &ZkLayoutV3, is_p3: bool) -> Vec<(usize, usize)> {
    let lay = &zl.lay;
    // [UPERF3-AM] MODE P3 gives the two MATMUL sumchecks a SECOND extension variable.
    // The extension round is only an identity when poly(exts) = 0, and the matmul poly is
    // BILINEAR (activation x weight): masking both factors in one round leaves the product
    // of the two masks behind and the round stops summing to its claim. Two rounds, each
    // with one side's extension zero, keep poly(exts) = 0 in both — the activation side is
    // masked in round k, the weight side in round k + 1. Cost: one round of a degree-2
    // sumcheck per matmul, i.e. three field elements.
    let x = usize::from(is_p3);
    let mut v = vec![
        (lay.log_db as usize + 1 + x, 2),
        (lay.log_fb as usize + 1 + x, 2),
        ((lay.log_t + lay.log_fb) as usize + 1, 4),
        ((lay.log_t + lay.log_db) as usize + 1, 4),
        (zl.log_n + 1, 2),
        (zl.log_s + 1, 3),
    ];
    // [UPERF3-AN] FUNCTION 2's predicate sumcheck: the d-block cube, degree 3
    // (eq * B * B), + 1 for its extension round. Absent under function 1, so the
    // function-1 mask commitment is the same commitment it has always been.
    if zl.pred { v.push(((lay.log_t + lay.log_db) as usize + 1, 3)); }
    // IO reserves both seam slots before M is committed; no late mask commitment.
    if zl.a_io.is_some() { v.extend([((lay.log_t + lay.log_db) as usize + 1, 2); 2]); }
    v
}

/// The six multiplicity tables of the (possibly tampered) witness, in slot
/// order; values outside a table count into entry 0 (only the LogUp
/// identity can catch them — what the tamper legs test).
fn multiplicities_zk_v3(w: &V3Witness, lay: &LayoutV3) -> Vec<Vec<u32>> {
    let tf = lay.t_rows * lay.f;
    let td = lay.t_rows * lay.d;
    let mut act = vec![0u32; 256];
    for &g in &w.g8[..tf] {
        if (-128..=127).contains(&g) { act[(g + 128) as usize] += 1; } else { act[0] += 1; }
    }
    let mut i16t = vec![0u32; 1 << 16];
    for col in [&w.u16v[..tf], &w.h16[..tf], &w.z16[..td]] {
        for &v in col {
            if (-32768..=32767).contains(&v) { i16t[(v + 32768) as usize] += 1; } else { i16t[0] += 1; }
        }
    }
    let (sg, su, sh, sz) = w.shifts;
    let mut out = vec![act, i16t];
    let cols: [(i32, &[i32]); 4] = [(sg, &w.rg[..tf]), (su, &w.ru[..tf]), (sh, &w.rh[..tf]), (sz, &w.rd[..td])];
    for (s, col) in cols {
        let mut m = vec![0u32; rem_rows(s)];
        for &r in col {
            match rem_index(s, r) { Some(i) => m[i] += 1, None => m[0] += 1 }
        }
        out.push(m);
    }
    out
}

/// The public compressed table values of slot `tag` (size entries).
fn tval_v3(tag: u64, size: usize, table: &[i16; 256], beta: Fp2, gamma: Fp2) -> Vec<Fp2> {
    let gt = gamma.mul_base(Fp::new(tag));
    (0..size)
        .map(|i| {
            if tag == TAG_ACT16 {
                Fp2::from_i64(i as i64 - 128).add(beta.mul_base(Fp::from_i64(table[i] as i64))).add(gt)
            } else if tag == TAG_INT16 {
                Fp2::from_i64(i as i64 - 32768).add(gt)
            } else {
                let sh = tag as i32 - 72; // tag_rem_v3(sh) = 72 + sh
                Fp2::from_i64(rem_value(sh, i)).add(gt)
            }
        })
        .collect()
}

/// prod_{j<k} (1 - rho_j): the coefficient a 2^(|rho| - k)-entry table zero-extended to 2^|rho| carries at rho.
fn ext_coef(rho: &[Fp2], k: usize) -> Fp2 {
    rho[..k].iter().fold(Fp2::ONE, |a, r| a.mul(Fp2::ONE.sub(*r)))
}

/// MLE of the base-field slice data[off .. off + 2^|point|] at `point`.
fn eval_slice(data: &[Fp], off: usize, point: &[Fp2]) -> Fp2 {
    eval_many(data, &[(off, 1usize << point.len())], point)[0]
}

#[cfg(test)]
thread_local! {
    /// [UPERF3-AN] TEST ONLY (it does not exist in the shipped binary): replace the
    /// honest bit row with a chosen sparse one, so the two facts the predicate gadget
    /// rests on -- the planes are BOOLEAN, and only the 16 weighted columns count --
    /// can be attacked directly rather than argued.
    static PRED_BIT_TAMPER: std::cell::RefCell<Option<Vec<(usize, i64)>>> = const { std::cell::RefCell::new(None) };
}

/// [UPERF3-AN] FUNCTION 2. The number of bit planes the predicate slack needs:
/// both the score and the threshold are int16, so `y - tau` lies in
/// [-65535, 65535] and "non-negative" is exactly "16 bits recompose it".
pub const PRED_BITS: usize = 16;

/// The Boolean point of index `idx` over `nv` variables, r[0] the MOST
/// significant bit (the `eq_table_msb` convention the whole engine uses).
fn bool_point(idx: usize, nv: usize) -> Vec<Fp2> {
    (0..nv).map(|j| Fp2::from_u64(((idx >> (nv - 1 - j)) & 1) as u64)).collect()
}

/// The MLE, at `rho`, of the PUBLIC weight table of the predicate sumcheck:
/// 2^i on index i < 16 and ZERO everywhere else. Zero outside the 16 bit
/// columns is what makes a bit planted anywhere else worth nothing, so no
/// separate "the tail is zero" constraint is needed.
fn pred_weight_at(rho: &[Fp2]) -> Fp2 {
    let nv = rho.len();
    assert!(nv >= 4);
    let mut acc = ext_coef(rho, nv - 4);
    for j in 0..4 {
        let r = rho[nv - 4 + j];
        // MSB-first: rho[nv - 4 + j] carries index weight 2^(3 - j), so the
        // value weight it multiplies in is 2^(2^(3 - j)).
        let base = Fp2::from_u64(1u64 << (1usize << (3 - j)));
        acc = acc.mul(Fp2::ONE.sub(r).add(r.mul(base)));
    }
    acc
}

/// The host-side Fp2 tables of the v3 zero-checks (the CPU path, and the GPU path at a non-kernel shape).
struct HostTabsZkV3 {
    /// per f-block: g8, rg, a16, u16, ru, h16, rh, hg, hu, hh
    fb: Vec<Vec<Vec<Fp2>>>,
    /// per d-block: z, rd, hz
    db: Vec<Vec<Vec<Fp2>>>,
}

/// Prove one v3 layer in ZK mode (P1) over the first `t_rows` rows of the witness.
pub fn prove_layer_zk_v3(w: &V3Witness, t_rows: usize, params: &LayerParams, ntt: &NttTables, cfg: &ZkConfig, tr: &mut Transcript) -> ProveOutputZk {
    prove_layer_zk_v3_inner(w, t_rows, params, ntt, cfg, tr, false, cfg.rng(format!("layer-v3-{}", w.l).as_bytes())).expect("legacy FFN proof")
}

fn prove_layer_zk_v3_inner(w: &V3Witness, t_rows: usize, params: &LayerParams, ntt: &NttTables, cfg: &ZkConfig, tr: &mut Transcript, mr1: bool, rng: ZkRng) -> Result<ProveOutputZk, String> {
    prepare_layer_zk_v3_inner(w, t_rows, params, ntt, cfg, tr, mr1, false, rng)?.finish(ntt, tr)
}

// Private owners and claims are retained only until their ONE final opening.
enum PendingWeightV3 {
    Public(pcs::Committed, Vec<Claim>),
    Private(pcs::CommittedZk, Vec<ZClaim>),
}
struct PendingV3 {
    proof: LayerProofZk,
    zl: ZkLayoutV3,
    mc: MaskCommit,
    fs: Vec<MaskFunctional>,
    w: PendingWeightV3,
    a: pcs::CommittedZk,
    h: pcs::CommittedZk,
    ac: Vec<ZClaim>,
    hc: Vec<ZClaim>,
    timings: Vec<(String, f64)>,
    sites: Vec<String>,
    tick: std::time::Instant,
}
impl PendingV3 {
    fn finish(mut self, ntt: &NttTables, tr: &mut Transcript) -> Result<ProveOutputZk, String> {
        let zl = &self.zl;
        self.proof.mask_open = mask_open(&self.mc, &self.fs, ntt, tr);
        drop(self.mc);
        self.timings.push(("zsum + mask open".into(), self.tick.elapsed().as_secs_f64()));
        self.tick = std::time::Instant::now();
        match self.w {
            PendingWeightV3::Public(cm, claims) => { self.proof.w_open = pcs::open(&cm, &claims, tr); }
            PendingWeightV3::Private(cm, claims) => {
                self.sites.push(format!("W: {} claims in {} groups", claims.len(), pcs::zk_groups_for_record(&cm, &claims)));
                if zl.mr1 { fresh_poc::check_masks(&claims, cm.cm.rows, zl.log_wn, &zl.w_mask_rows(), zl.w_prox, tr)?; }
                self.proof.w_open_zk = pcs::open_zk(&cm, &claims, tr);
                self.sites.extend(pcs::last_mask_sites().into_iter().map(|s| format!("W {s}")));
            }
        }
        self.sites.push(format!("A: {} claims in {} groups", self.ac.len(), pcs::zk_groups_for_record(&self.a, &self.ac)));
        if zl.mr1 { fresh_poc::check_masks(&self.ac, self.a.cm.rows, zl.log_n, &zl.a_mask_rows(), zl.a_prox, tr)?; }
        self.proof.a_open = pcs::open_zk(&self.a, &self.ac, tr);
        self.sites.extend(pcs::last_mask_sites().into_iter().map(|s| format!("A {s}")));
        drop(self.a);
        self.sites.push(format!("H: {} claims in {} groups", self.hc.len(), pcs::zk_groups_for_record(&self.h, &self.hc)));
        if zl.mr1 { fresh_poc::check_masks(&self.hc, self.h.cm.rows, zl.log_n, &zl.h_mask_rows(), zl.h_prox, tr)?; }
        self.proof.h_open = pcs::open_zk(&self.h, &self.hc, tr);
        self.sites.extend(pcs::last_mask_sites().into_iter().map(|s| format!("H {s}")));
        drop(self.h);
        self.timings.push(("pcs openings (zk)".into(), self.tick.elapsed().as_secs_f64()));
        Ok(ProveOutputZk { proof: self.proof, timings: self.timings, sites: self.sites })
    }
}

fn prepare_layer_zk_v3_inner(w: &V3Witness, t_rows: usize, params: &LayerParams, ntt: &NttTables, cfg: &ZkConfig, tr: &mut Transcript, mr1: bool, io: bool, mut rng: ZkRng) -> Result<PendingV3, String> {
    use std::time::Instant;
    let mut timings = Vec::new();
    let mut tick = Instant::now();
    let lap = |name: &str, timings: &mut Vec<(String, f64)>, tick: &mut Instant| {
        timings.push((name.to_string(), tick.elapsed().as_secs_f64()));
        *tick = Instant::now();
    };
    assert!(t_rows <= w.t_rows, "witness derived over {} rows < {t_rows}", w.t_rows);
    // [UPERF3-AN] FUNCTION 2: the declared predicate (None = function 1).
    let pred: Option<PredicateSpec> = cfg.mode.predicate().expect("zk v3: statement mode").cloned();
    if let Some(p) = &pred {
        assert!(p.row < t_rows, "function 2: predicate row {} outside the {t_rows} proven rows", p.row);
        assert!(p.col < w.dims.d, "function 2: predicate col {} outside the output plane (d = {})", p.col, w.dims.d);
    }
    let zl = if io {
        if !mr1 || pred.is_some() { return Err("IO requires the fresh function-1 schedule".into()); }
        ZkLayoutV3::with_io(&fresh_poc::statement(w), params)
    } else { ZkLayoutV3::with_masks(t_rows, w.dims.d, w.dims.f, params, w.shifts, pred.is_some(), mr1) };
    let lay = zl.lay.clone();
    let (d, f) = (lay.d, lay.f);
    let (nb_d, nb_f, db, fb, tfb, tdb, wb) = (lay.nb_d, lay.nb_f, 1usize << lay.log_db, 1usize << lay.log_fb, lay.tfb, lay.tdb, lay.wb);
    let n = zl.a_n;
    let log_n = zl.log_n;
    let log_s = zl.log_s;
    let (sh_g, sh_u, sh_h, sh_z) = w.shifts;
    let st = StatementV3 { l: w.l, t_rows, d, f, shifts: w.shifts, act: w.act, table: w.table, table_digest: w.table_digest.clone() };
    absorb_statement_v3(tr, &st);
    // [UPERF3-AM] the statement header: the privacy mode, the output claim and the model
    // identity, in the Fiat-Shamir domain before any challenge (see ZkStatementMode).
    let is_p3 = cfg.p3();
    tr.absorb(b"zk", &cfg.mode.header_v3());
    let mut proof = LayerProofZk::default();
    let mut sites: Vec<String> = zl.describe();
    if is_p3 { sites.insert(0, zl.describe_w_p3()); }

    // [UPERF3-AI] VRAM accounting under HL_GPU_VERBOSE=1 (the ZK path at 8B width runs at the
    // edge of an 8 GB part, so "what is held where" is the whole story of this rung).
    #[cfg(feature = "gpu-cuda")]
    let vnote = |tag: &str| {
        if std::env::var("HL_GPU_VERBOSE").map(|v| v == "1").unwrap_or(false) {
            if let Some((free, total, held)) = crate::gpu::dev_mem_info() {
                eprintln!("[UPERF3-AI] vram {tag}: free {} MiB / {} MiB, pool {held}", free >> 20, total >> 20);
            }
        }
    };
    #[cfg(not(feature = "gpu-cuda"))]
    let vnote = |_tag: &str| {};

    // [UPERF3-AI] START THIS LAYER WITH A CLEAN CARD. The device buffer pool matches by exact
    // length, and the ZK prover's A and H row counts differ from layer to layer (each layer's
    // signed shifts give different remainder-window sizes, so different table rows — measured
    // at Mistral: H is 3033 rows at layer 0 and 3028 at layer 1). At 8B width ONE layer's
    // commitments already fill an 8 GB part, so the previous layer's pooled buffers are dead
    // weight that makes the next layer's H commit fail (it did: `gpu zk commit H (v3):
    // cuMemAlloc(1514 MB) OUT_OF_MEMORY` at layer 1 of the first 32-layer attempt). Draining
    // is value-neutral — a pooled buffer holds nothing live — and costs only the first touch
    // of the next allocation of each size.
    //
    // ALL OF THE ABOVE IS A HYPOTHESIS THE DEAD AGENT LEFT IN A COMMENT (its logs died with the
    // box); `HL_ZK_DRAIN=0` turns BOTH drains off so the A/B can be run in ONE binary, which is
    // how rung 3 re-establishes it. Default = on.
    #[cfg(feature = "gpu-cuda")]
    let drain_on = std::env::var("HL_ZK_DRAIN").map(|v| v != "0").unwrap_or(true);
    #[cfg(feature = "gpu-cuda")]
    let drain = |tag: &str| {
        if crate::gpu::enabled() && drain_on {
            let n = crate::gpu::dev_pool_drain();
            if std::env::var("HL_GPU_VERBOSE").map(|v| v == "1").unwrap_or(false) {
                eprintln!("[UPERF3-AI] drain {tag}: freed {n} pooled buffers");
            }
        }
    };
    #[cfg(not(feature = "gpu-cuda"))]
    let drain = |_tag: &str| {};
    drain("layer top");

    // ---- W data + commit (P1: public weights, ZB's block layout; P3: the same
    // matrix with one mask row per block terminal and the HIDING commitment) ----
    let mut w_data = vec![Fp::ZERO; if is_p3 { zl.w_len_p3 } else { lay.w_len }];
    for c in 0..nb_d {
        for b in 0..nb_f {
            for (offs, src) in [(&lay.wg, &w.wg_t), (&lay.wu, &w.wu_t)] {
                let off = offs[c * nb_f + b];
                w_data[off..off + wb].par_chunks_mut(fb).enumerate().for_each(|(kp, row)| {
                    let k = c * db + kp;
                    for jp in 0..fb { row[jp] = Fp::from_i64(src[k * f + b * fb + jp] as i64); }
                });
            }
            let off = lay.wd[b * nb_d + c];
            w_data[off..off + wb].par_chunks_mut(db).enumerate().for_each(|(jp, row)| {
                let j = b * fb + jp;
                for np in 0..db { row[np] = Fp::from_i64(w.wd_t[j * d + c * db + np] as i64); }
            });
        }
    }
    let w_pcs = pcs_params(params, lay.log_wb);
    // [UPERF3-AM] MODE P3: the mask rows, drawn BEFORE the commitment (a mask chosen after
    // the challenges would not hide). One per block terminal, plus the proximity row.
    if is_p3 {
        for r in zl.w_mask_rows().into_iter().chain(zl.mask_range(zl.w_prox)) {
            let v = rng.fp_vec(zl.w_n);
            w_data[r * zl.w_n..(r + 1) * zl.w_n].copy_from_slice(&v);
        }
    }
    #[cfg(test)]
    if mr1 && is_p3 { fresh_poc::check_generated_rows(&w_data, zl.w_n, &zl.w_mask_rows().into_iter().chain(zl.mask_range(zl.w_prox)).collect::<Vec<_>>()); }
    // [UPERF3-AI] the per-model weight cache (lane AC's `--wcache DIR`) also serves the ZK
    // prover: under mode P1 the weights are PUBLIC, so W's commitment is per-model work here
    // exactly as it is in layer.rs's v3 FFN prover. Same `w_data`, same `PcsParams`, same
    // `WKey::new("v3", l, d, f, ..)` key -> the same Ligero matrix, the same leaves, the same
    // root; the ZK and non-zk passes share entries. `wcache::commit_w` falls back to
    // `pcs::commit` (the previous line, byte for byte) when no `--wcache` dir is configured.
    // [UPERF3-AM] ... and under P3 the cache is FORBIDDEN, which is a soundness fact and not a
    // preference: a cached hash-based weight commitment opens 256 of its encoded columns per
    // proof, so after ~(n + Q)/Q proofs (65 at the measured 125M n = 2^14) the weight rows are
    // recoverable by linear algebra (lane ZZ, U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md section 1).
    // The driver refuses the flag combination; this is the belt-and-braces stop.
    let (w_cm, w_cmz) = if is_p3 {
        assert!(
            crate::wcache::dir().is_none(),
            "mode P3: --wcache is REFUSED — a cached weight commitment reveals 256 encoded columns per proof and the weights are recoverable after ~65 proofs (U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md section 1). The weights must be re-committed with fresh randomness on EVERY proof."
        );
        let w_zk = ZkOpts::standard(&w_pcs);
        let mut cmz = pcs::commit_zk_owned(&w_pcs, std::mem::take(&mut w_data), ntt, &w_zk, &mut rng);
        cmz.mask_rows = zl.w_mask_rows();
        cmz.prox_mask_row = Some(zl.w_prox);
        (None, Some(cmz))
    } else {
        (Some(crate::wcache::commit_w(&w_pcs, &w_data, ntt, &crate::wcache::WKey::new("v3", w.l, d, f, &w.wg_t, &w.wu_t, &w.wd_t))), None)
    };
    proof.w_com = Some(match (&w_cm, &w_cmz) { (Some(c), _) => c.commitment(), (_, Some(c)) => c.commitment(), _ => unreachable!() });
    // the block terminals below read the systematic W matrix; under P3 it lives in the commitment
    let w_data_ref: &[Fp] = match &w_cmz { Some(c) => &c.data, None => &w_data };
    absorb_com(tr, b"W", proof.w_com.as_ref().unwrap());
    lap("commit W", &mut timings, &mut tick);
    vnote("after commit W");

    // ---- A data + the committed multiplicities + mask rows + ZK commit ----
    let mut a_data = vec![Fp::ZERO; zl.a_len];
    for b in 0..nb_f {
        for (offs, col) in [(&lay.g8, &w.g8), (&lay.rg, &w.rg), (&lay.a16, &w.a16), (&lay.u16, &w.u16v), (&lay.ru, &w.ru), (&lay.h16, &w.h16), (&lay.rh, &w.rh)] {
            let off = offs[b];
            a_data[off..off + tfb].par_chunks_mut(fb).enumerate().for_each(|(t, row)| {
                for jp in 0..fb { row[jp] = Fp::from_i64(col[t * f + b * fb + jp] as i64); }
            });
        }
    }
    for c in 0..nb_d {
        a_data[lay.x[c]..lay.x[c] + tdb].par_chunks_mut(db).enumerate().for_each(|(t, row)| {
            for kp in 0..db { row[kp] = Fp::from_i64(w.x[t * d + c * db + kp] as i64); }
        });
        for (offs, col) in [(&lay.z, &w.z16), (&lay.rd, &w.rd)] {
            let off = offs[c];
            a_data[off..off + tdb].par_chunks_mut(db).enumerate().for_each(|(t, row)| {
                for kp in 0..db { row[kp] = Fp::from_i64(col[t * d + c * db + kp] as i64); }
            });
        }
    }
    let mults = multiplicities_zk_v3(w, &lay);
    assert_eq!(mults.len(), zl.tabs.len());
    for (t, m) in zl.tabs.iter().zip(mults.iter()) {
        assert_eq!(m.len(), t.size);
        for (j, &c) in m.iter().enumerate() { a_data[t.a_row * n + j] = Fp::new(c as u64); }
    }
    // [UPERF3-AN] FUNCTION 2: the predicate slack's 16 bit planes, in the first 16
    // columns of one appended A row. The slack is y - tau for the frozen
    // (row, col, tau); it is non-negative exactly when 16 bits recompose it.
    // If it is NOT non-negative the prover says so and still emits the proof --
    // which then does not verify. That IS the deployment semantics
    // (PROOF_FUNCTIONS.md section 3: no valid proof => reject), and it is what
    // lets a test drive the refusal leg.
    if let Some(p) = &pred {
        let y = w.z16[p.row * d + p.col] as i64;
        let slack = y - p.tau;
        if !(0..(1i64 << PRED_BITS)).contains(&slack) {
            eprintln!(
                "[UPERF3-AN] FUNCTION 2: THE PREDICATE DOES NOT HOLD at layer {} — z16[{}][{}] = {y}, tau = {}, y - tau = {slack} is outside [0, 65535]. A proof is still emitted and WILL NOT VERIFY (no valid proof => reject).",
                w.l, p.row, p.col, p.tau
            );
        }
        for i in 0..PRED_BITS { a_data[zl.a_pb * n + i] = Fp::new(((slack >> i) & 1) as u64); }
        #[cfg(test)]
        PRED_BIT_TAMPER.with(|t| {
            if let Some(cells) = t.borrow().as_ref() {
                for i in 0..n { a_data[zl.a_pb * n + i] = Fp::ZERO; }
                for (i, v) in cells { a_data[zl.a_pb * n + i] = Fp::from_i64(*v); }
            }
        });
    }
    let mut a_random_rows: Vec<_> = zl.a_mask_rows().into_iter().chain(zl.mask_range(zl.a_prox)).collect();
    if mr1 { a_random_rows.sort_unstable(); }
    for r in a_random_rows {
        let v = rng.fp_vec(n);
        a_data[r * n..(r + 1) * n].copy_from_slice(&v);
    }
    #[cfg(test)]
    if mr1 { fresh_poc::check_generated_rows(&a_data, n, &zl.a_mask_rows().into_iter().chain(zl.mask_range(zl.a_prox)).collect::<Vec<_>>()); }
    let a_pcs = pcs_params(params, lay.log_a_min);
    let a_zk = ZkOpts::standard(&a_pcs);
    let mut a_cmz = pcs::commit_zk_owned(&a_pcs, a_data, ntt, &a_zk, &mut rng);
    a_cmz.mask_rows = zl.a_mask_rows();
    a_cmz.prox_mask_row = Some(zl.a_prox);
    let a_data: &[Fp] = &a_cmz.data;
    proof.a_com = Some(a_cmz.commitment());
    absorb_com(tr, b"A", proof.a_com.as_ref().unwrap());
    lap("commit A (zk)", &mut timings, &mut tick);
    vnote("after commit A");

    // ---- the mask commitment (the CFS masking polynomials of the six sumchecks) ----
    let specs = mask_specs_v3(&zl, is_p3);
    let mc = mask_commit(&specs, ntt, &mut rng);
    proof.mask_root = mc.tree.root();
    tr.absorb(b"M", &proof.mask_root);
    lap("mask commit", &mut timings, &mut tick);

    // ---- challenges, helpers + the table-side helpers + mask rows, ZK commit H ----
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_act = gamma.mul_base(Fp::new(TAG_ACT16));
    let g_i16 = gamma.mul_base(Fp::new(TAG_INT16));
    let g_rg = gamma.mul_base(Fp::new(tag_rem_v3(sh_g)));
    let g_ru = gamma.mul_base(Fp::new(tag_rem_v3(sh_u)));
    let g_rh = gamma.mul_base(Fp::new(tag_rem_v3(sh_h)));
    let g_rd = gamma.mul_base(Fp::new(tag_rem_v3(sh_z)));
    let h_pcs = pcs_params(params, lay.log_a_min);
    let h_zk = ZkOpts::standard(&h_pcs);
    // [UPERF3-AI] was `nb_f == 1 && nb_d == 3` — the XX zero-check kernels this prover called
    // were fixed at 13 / 15 tables (the 125M block shape), which declined Mistral's (7, 1) =
    // 73 / 7 and left the LogUp helpers AND both zero-checks on the host even after lane AH
    // made the kernels shape-general for the non-zk prover. The block-looping kernels take any
    // block count; the bound is their shared parameter array (gpu::SCG_MAX_PRM = 384).
    let dev_shape = nb_f >= 1 && nb_d >= 1 && 17 + 14 * nb_f <= 384 && 7 + 6 * nb_d <= 384;
    // [UPERF3-AI] A THIRD DRAIN HERE WAS TRIED AND IS MEASURED HARMFUL ON THIS BOX — do not
    // re-add it without re-running the A/B (results/hashline_zk_8b_drain_pre_ab.log).
    // The reasoning that suggested it: at Mistral width layer 0 proves in 4.36 s and layers
    // 1..31 in 8.34 s, and the only difference in the HL_GPU_VERBOSE trace is that at layer 0
    // the reservation below FAILS, `dev_reserve_hard` drains and retries; at later layers it
    // SUCCEEDS with 494 MiB free, which on WSL means cuMemAlloc was served by HOST memory, so
    // the helpers/H/zero-check phase then runs against paged memory. Draining here to force
    // the tables into real VRAM does exactly that — and then the H commit's 1,516 MB NTT
    // scratch has nowhere to go: `gpu zk commit H (v3): cuMemAlloc(1516 MB) OUT_OF_MEMORY`
    // at LAYER 0, on the first run of the experiment. On an 8,188 MiB part the resident A
    // commitment + 1,392 MB of zero-check tables + a 1.5 GB H commit do not fit, and WSL's
    // paging is what makes the layer possible at all. The 2x is the price of a card that is
    // too small for this statement, not a bug in the pool discipline; a board with 16 GB+
    // should show layer-0 speed at every layer with no code change.
    // [UPERF3-AI] (AH's safety rung, moved to where THIS prover needs it) the two zero-check
    // table buffers are reserved through the pool BEFORE the decision, because in the ZK
    // prover the host tables are built in the `!use_dev_h` branch BELOW: once the helpers go
    // to the device there are no host tables and a later decline is a panic by design. The
    // pool matches by exact length, so the reservation IS the later allocation. At Mistral
    // width the zcF buffer alone is (3 + 10 x 7) x 2^20 x 2 u64 = 1.22 GB on top of the
    // resident A / H commitments, on an 8,188 MB part — a live decline, not a formality.
    #[cfg(feature = "gpu-cuda")]
    let use_dev_h = crate::gpu::enabled()
        && dev_shape
        && dev_of(&a_cmz.cm).is_some()
        && match crate::gpu::dev_reserve_hard(&[(3 + 10 * nb_f) * tfb * 2, (3 + 4 * nb_d) * tdb * 2]) {
            Ok(()) => true,
            Err(e) => {
                eprintln!("[UPERF3-AI] gpu zero-check tables unaffordable ({e}); the whole layer takes the CPU path");
                false
            }
        };
    #[cfg(not(feature = "gpu-cuda"))]
    let use_dev_h = false;
    #[cfg(not(feature = "gpu-cuda"))]
    let _ = dev_shape;
    let mut host_tabs: Option<HostTabsZkV3> = None;
    let mut h_data = vec![Fp::ZERO; zl.h_len];
    if !use_dev_h {
        let to2 = |off: usize, len: usize| -> Vec<Fp2> { a_data[off..off + len].par_iter().map(|v| Fp2::from_base(*v)).collect() };
        let mut fbt: Vec<Vec<Vec<Fp2>>> = Vec::with_capacity(nb_f);
        for b in 0..nb_f {
            let g8f = to2(lay.g8[b], tfb); let rgf = to2(lay.rg[b], tfb); let a16f = to2(lay.a16[b], tfb);
            let u16f = to2(lay.u16[b], tfb); let ruf = to2(lay.ru[b], tfb); let h16f = to2(lay.h16[b], tfb); let rhf = to2(lay.rh[b], tfb);
            let hg = {
                let lg: Vec<Fp2> = g8f.par_iter().zip(a16f.par_iter()).map(|(g, a)| g.add(beta.mul(*a)).add(g_act)).collect();
                let lrg: Vec<Fp2> = rgf.par_iter().map(|r| r.add(g_rg)).collect();
                helper_column(&lg, &lrg, alpha)
            };
            let hu = {
                let lu: Vec<Fp2> = u16f.par_iter().map(|v| v.add(g_i16)).collect();
                let lru: Vec<Fp2> = ruf.par_iter().map(|r| r.add(g_ru)).collect();
                helper_column(&lu, &lru, alpha)
            };
            let hh = {
                let lh: Vec<Fp2> = h16f.par_iter().map(|v| v.add(g_i16)).collect();
                let lrh: Vec<Fp2> = rhf.par_iter().map(|r| r.add(g_rh)).collect();
                helper_column(&lh, &lrh, alpha)
            };
            for (col, (ore, oim)) in [(&hg, lay.hg[b]), (&hu, lay.hu[b]), (&hh, lay.hh[b])] {
                h_data[ore..ore + tfb].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c0);
                h_data[oim..oim + tfb].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c1);
            }
            fbt.push(vec![g8f, rgf, a16f, u16f, ruf, h16f, rhf, hg, hu, hh]);
        }
        let mut dbt: Vec<Vec<Vec<Fp2>>> = Vec::with_capacity(nb_d);
        for c in 0..nb_d {
            let zf = to2(lay.z[c], tdb);
            let rdf = to2(lay.rd[c], tdb);
            let lz: Vec<Fp2> = zf.par_iter().map(|v| v.add(g_i16)).collect();
            let lrd: Vec<Fp2> = rdf.par_iter().map(|r| r.add(g_rd)).collect();
            let hz = helper_column(&lz, &lrd, alpha);
            let (ore, oim) = lay.hz[c];
            h_data[ore..ore + tdb].par_iter_mut().zip(hz.par_iter()).for_each(|(o, v)| *o = v.c0);
            h_data[oim..oim + tdb].par_iter_mut().zip(hz.par_iter()).for_each(|(o, v)| *o = v.c1);
            dbt.push(vec![zf, rdf, hz]);
        }
        host_tabs = Some(HostTabsZkV3 { fb: fbt, db: dbt });
    }
    // the table-side helpers h_t = m / (alpha - tval) (zero beyond each table)
    let tvals: Vec<Vec<Fp2>> = zl.tabs.iter().map(|t| tval_v3(t.tag, t.size, &w.table, beta, gamma)).collect();
    for (t, (tv, m)) in zl.tabs.iter().zip(tvals.iter().zip(mults.iter())) {
        let mut den: Vec<Fp2> = tv.iter().map(|v| alpha.sub(*v)).collect();
        den.par_chunks_mut(4096).for_each(|c| batch_inverse2(c));
        for j in 0..t.size {
            let h = den[j].mul_base(Fp::new(m[j] as u64));
            h_data[t.h_re * n + j] = h.c0;
            h_data[t.h_im * n + j] = h.c1;
        }
    }
    // mask rows: the Fp2 masks of the helper planes, u', the prox row, the table helpers' masks; then the zero-sum u
    let mut plain_rows: Vec<usize> = Vec::new();
    for (a, b) in zl.h_mf.iter().chain(zl.h_md.iter()) { plain_rows.push(*a); plain_rows.push(*b); }
    plain_rows.extend([zl.h_up.0, zl.h_up.1]);
    plain_rows.extend(zl.mask_range(zl.h_prox));
    for t in &zl.tabs { plain_rows.extend(t.h_mre..t.h_mre + t.rows); plain_rows.extend(t.h_mim..t.h_mim + t.rows); }
    for r in plain_rows {
        let v = rng.fp_vec(n);
        h_data[r * n..(r + 1) * n].copy_from_slice(&v);
    }
    for r in [zl.h_u.0, zl.h_u.1] {
        let mut sum = Fp::ZERO;
        for j in 0..n - 1 { let v = rng.fp(); h_data[r * n + j] = v; sum = sum.add(v); }
        h_data[r * n + n - 1] = sum.neg();
    }
    #[cfg(test)]
    if mr1 { fresh_poc::check_generated_rows(&h_data, n, &zl.h_mask_rows().into_iter().chain(zl.mask_range(zl.h_prox)).collect::<Vec<_>>()); }
    #[cfg(feature = "gpu-cuda")]
    let h_cmz_dev: Option<pcs::CommittedZk> = if use_dev_h {
        use crate::gpu::HelperSpec;
        let a_dc = dev_of(&a_cmz.cm).unwrap();
        // [UPERF3-AI] every f-block, not only block 0 (`k_helper` is length-general).
        let mut hspecs = Vec::with_capacity(3 * nb_f + nb_d);
        for b in 0..nb_f {
            hspecs.push(HelperSpec { off_v1: lay.g8[b], off_w: Some(lay.a16[b]), off_v2: lay.rg[b], len: tfb, c1: g_act, c2: g_rg, off_re: lay.hg[b].0, off_im: lay.hg[b].1 });
            hspecs.push(HelperSpec { off_v1: lay.u16[b], off_w: None, off_v2: lay.ru[b], len: tfb, c1: g_i16, c2: g_ru, off_re: lay.hu[b].0, off_im: lay.hu[b].1 });
            hspecs.push(HelperSpec { off_v1: lay.h16[b], off_w: None, off_v2: lay.rh[b], len: tfb, c1: g_i16, c2: g_rh, off_re: lay.hh[b].0, off_im: lay.hh[b].1 });
        }
        for c in 0..nb_d {
            hspecs.push(HelperSpec { off_v1: lay.z[c], off_w: None, off_v2: lay.rd[c], len: tdb, c1: g_i16, c2: g_rd, off_re: lay.hz[c].0, off_im: lay.hz[c].1 });
        }
        let rows = zl.h_len / n;
        let (mut d_h, _sums) = crate::gpu::dev_helpers(a_dc, zl.h_len, &hspecs, alpha, beta).expect("gpu helpers (zk v3)");
        vnote("after dev_helpers");
        crate::gpu::dev_upload_rows(&mut d_h, lay.h_len, &h_data[lay.h_len..zl.h_len]).expect("gpu upload of the H tail rows (zk v3)");
        Some(pcs::commit_zk_device(&h_pcs, d_h, rows, std::mem::take(&mut h_data), ntt, &h_zk, &mut rng).expect("gpu zk commit H (v3)"))
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let h_cmz_dev: Option<pcs::CommittedZk> = None;
    let mut h_cmz = match h_cmz_dev {
        Some(c) => c,
        None => pcs::commit_zk_owned(&h_pcs, std::mem::take(&mut h_data), ntt, &h_zk, &mut rng),
    };
    h_cmz.mask_rows = zl.h_mask_rows();
    h_cmz.prox_mask_row = Some(zl.h_prox);
    let h_data: &[Fp] = &h_cmz.data;
    proof.h_com = Some(h_cmz.commitment());
    absorb_com(tr, b"H", proof.h_com.as_ref().unwrap());
    // [UPERF3-AI] the H commit's NTT scratch (rows x n + rows x nn = 1,895 MiB at Mistral
    // width) is in the pool and nothing later in this layer has those lengths; free it, so the
    // zero-check tables (1,168 + 224 MiB) are allocated against a card holding only the three
    // commitments. Without this the zero-check's table allocation is served by WSL's paging
    // and its "tables" phase went from 0.003 s to 4.5 s (measured at Mistral, layer 1) — again
    // the dead agent's testimony, re-established (or not) by the HL_ZK_DRAIN=0 A/B in rung 3.
    drain("after H");
    lap("helpers + commit H (zk)", &mut timings, &mut tick);
    vnote("after helpers+H");

    // ---- g/u matmul sumcheck (masked; the claimed sum sent masked; the X-block terminals masked) ----
    let r_i = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_j = tr.challenge_fp2_vec(lay.log_fb as usize);
    let lam_gu = tr.challenge_fp2();
    let lam_f = tr.challenge_fp2_vec(nb_f);
    let mut p1 = r_i.clone();
    p1.extend_from_slice(&r_j);
    let mut sl: Vec<(usize, usize)> = Vec::with_capacity(4 * nb_f);
    for b in 0..nb_f { sl.extend([(lay.g8[b], tfb), (lay.rg[b], tfb), (lay.u16[b], tfb), (lay.ru[b], tfb)]); }
    let ev = eval_many_dev(&a_cmz, &sl, &p1);
    let (p_g, p_u, p_h, p_z) = (pow2_signed(sh_g), pow2_signed(sh_u), pow2_signed(sh_h), pow2_signed(sh_z));
    let mut s_gu = Fp2::ZERO;
    for b in 0..nb_f {
        let gb = ev[4 * b].mul_base(p_g).add(ev[4 * b + 1]);
        let ub = ev[4 * b + 2].mul_base(p_u).add(ev[4 * b + 3]);
        s_gu = s_gu.add(lam_f[b].mul(gb.add(lam_gu.mul(ub))));
    }
    let c_gu = fresh_poc::draw_mask_challenge(|| tr.challenge_fp2(), mr1)?;
    let g_gu_total = mc.masks[SC_GU].total();
    proof.gu_claim = s_gu.add(c_gu.mul(g_gu_total));
    tr.absorb_fp2(b"gu-claim", &[proof.gu_claim]);
    let eq_ri = eq_table_msb(&r_i);
    let eq_rj = eq_table_msb(&r_j);
    let xk = fold_rows_i8(&w.x[..t_rows * d], t_rows, d, &eq_ri);
    let cw_gu: Vec<Fp2> = (0..f).into_par_iter().map(|j| lam_f[j / fb].mul(eq_rj[j % fb])).collect();
    let wgk = fold_cols_i8(&w.wg_t, d, f, &cw_gu);
    let wuk = fold_cols_i8(&w.wu_t, d, f, &cw_gu);
    let mut tables: Vec<Vec<Fp2>> = Vec::with_capacity(2 * nb_d);
    for c in 0..nb_d { tables.push(xk[c * db..(c + 1) * db].to_vec()); }
    for c in 0..nb_d {
        tables.push(wgk[c * db..(c + 1) * db].iter().zip(wuk[c * db..(c + 1) * db].iter()).map(|(g, u)| g.add(lam_gu.mul(*u))).collect());
    }
    let nbd = nb_d;
    let gu_poly = move |v: &[Fp2]| -> Fp2 { let mut s = Fp2::ZERO; for c in 0..nbd { s = s.add(v[c].mul(v[nbd + c])); } s };
    let (mut gu_rounds, r_kp, gu_fin) = masked_prove(&mut tables, 2, gu_poly, &mc.masks[SC_GU], c_gu, tr);
    let mut p2 = r_i.clone();
    p2.extend_from_slice(&r_kp);
    let mut p3 = r_kp.clone();
    p3.extend_from_slice(&r_j);
    let mp = MaskPoint::new(&tail_of(&p2, log_n), n);
    let mut exts = vec![Fp2::ZERO; 2 * nb_d];
    for c in 0..nb_d { exts[c] = zl.eval_mask(&mp, a_data, zl.a_mgu[c]); }
    // [UPERF3-AM] MODE P3: the W block terminals are masked exactly as A's are, with ONE
    // mask row per block (a shared row would leave block DIFFERENCES in the clear). The
    // sumcheck's extension round carries the selector: setting the W tables' extension to
    // the SAME lam_f / lam_gu combination of the block masks makes the extended W table
    // value equal the combination the verifier forms from the masked block terminals, so
    // the verifier's check closes with no extra term.
    let w_mev: Vec<Fp2> = if is_p3 {
        let mpw = MaskPoint::new(&tail_of(&p3, zl.log_wn), zl.w_n);
        zl.w_mgu.iter().map(|&r| zl.eval_mask(&mpw, w_data_ref, r)).collect()
    } else { Vec::new() };
    // round k: the ACTIVATION side's extension (the weight side's is zero, so poly(exts) = 0)
    let e_gu = extension(&gu_fin, &exts, 2, gu_poly, &mc.masks[SC_GU], c_gu, &r_kp, &mut gu_rounds, tr);
    let mut rho_gu = r_kp.clone();
    rho_gu.push(e_gu);
    // round k+1 (P3 only): the WEIGHT side's extension, over the values round k left
    let (e_gu2, fin_gu2) = if is_p3 {
        let fin1: Vec<Fp2> = gu_fin.iter().zip(exts.iter()).map(|(f, e)| masked_terminal(*f, *e, e_gu)).collect();
        let mut exts2 = vec![Fp2::ZERO; 2 * nb_d];
        for c in 0..nb_d {
            let mut s = Fp2::ZERO;
            for b in 0..nb_f {
                let g = w_mev[c * nb_f + b];
                let u = w_mev[nb_d * nb_f + c * nb_f + b];
                s = s.add(lam_f[b].mul(g.add(lam_gu.mul(u))));
            }
            exts2[nb_d + c] = s;
        }
        let e2 = extension(&fin1, &exts2, 2, gu_poly, &mc.masks[SC_GU], c_gu, &rho_gu, &mut gu_rounds, tr);
        rho_gu.push(e2);
        (e2, fin1)
    } else { (Fp2::ZERO, Vec::new()) };
    proof.gu_sc = SumcheckProof { rounds: gu_rounds };
    // the two claim coefficients each opening site carries: (data, mask)
    let sel2 = Fp2::ONE.sub(e_gu2);
    let (cd_gu, cm_gu) = if is_p3 { (sel2.mul(Fp2::ONE.sub(e_gu)), sel2.mul(e_gu)) } else { (Fp2::ONE.sub(e_gu), e_gu) };
    let cd_w_gu = if is_p3 { sel2.mul(Fp2::ONE.sub(e_gu)) } else { Fp2::ONE };
    let mut term = Vec::with_capacity(nb_d + 2 * nb_d * nb_f);
    for c in 0..nb_d {
        term.push(if is_p3 { sel2.mul(fin_gu2[c]) } else { masked_terminal(gu_fin[c], exts[c], e_gu) });
    }
    for (ri, offs) in [(0usize, &lay.wg), (1, &lay.wu)] {
        for c in 0..nb_d {
            for b in 0..nb_f {
                let blk = &w_data_ref[offs[c * nb_f + b]..offs[c * nb_f + b] + wb];
                let folded = fold_cols_base(blk, db, fb, &eq_rj);
                let v = eval_mle_ext(&folded, &r_kp);
                term.push(if is_p3 { cd_w_gu.mul(v).add(e_gu2.mul(w_mev[ri * nb_d * nb_f + c * nb_f + b])) } else { v });
            }
        }
    }
    proof.gu_term = term;
    tr.absorb_fp2(b"gu-term", &proof.gu_term);
    lap("matmul g/u (zk)", &mut timings, &mut tick);

    // ---- d matmul sumcheck (masked; the h16-block terminals masked) ----
    let r_ip = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_jp = tr.challenge_fp2_vec(lay.log_db as usize);
    let lam_d = tr.challenge_fp2_vec(nb_d);
    let mut p4 = r_ip.clone();
    p4.extend_from_slice(&r_jp);
    let mut sl: Vec<(usize, usize)> = Vec::with_capacity(2 * nb_d);
    for c in 0..nb_d { sl.extend([(lay.z[c], tdb), (lay.rd[c], tdb)]); }
    let ev = eval_many_dev(&a_cmz, &sl, &p4);
    let s_d = (0..nb_d).fold(Fp2::ZERO, |a, c| a.add(lam_d[c].mul(ev[2 * c].mul_base(p_z).add(ev[2 * c + 1]))));
    let c_d = fresh_poc::draw_mask_challenge(|| tr.challenge_fp2(), mr1)?;
    let g_d_total = mc.masks[SC_D].total();
    proof.d_claim = s_d.add(c_d.mul(g_d_total));
    tr.absorb_fp2(b"d-claim", &[proof.d_claim]);
    let eq_rip = eq_table_msb(&r_ip);
    let eq_rjp = eq_table_msb(&r_jp);
    let hk = fold_rows_i32(&w.h16[..t_rows * f], t_rows, f, &eq_rip);
    let cw_d: Vec<Fp2> = (0..d).into_par_iter().map(|k| lam_d[k / db].mul(eq_rjp[k % db])).collect();
    let wdk = fold_cols_i8(&w.wd_t, f, d, &cw_d);
    let mut tables: Vec<Vec<Fp2>> = Vec::with_capacity(2 * nb_f);
    for b in 0..nb_f { tables.push(hk[b * fb..(b + 1) * fb].to_vec()); }
    for b in 0..nb_f { tables.push(wdk[b * fb..(b + 1) * fb].to_vec()); }
    let nbf = nb_f;
    let d_poly = move |v: &[Fp2]| -> Fp2 { let mut s = Fp2::ZERO; for b in 0..nbf { s = s.add(v[b].mul(v[nbf + b])); } s };
    let (mut d_rounds, r_k, d_fin) = masked_prove(&mut tables, 2, d_poly, &mc.masks[SC_D], c_d, tr);
    let mut p5 = r_ip.clone();
    p5.extend_from_slice(&r_k);
    let mut p6 = r_k.clone();
    p6.extend_from_slice(&r_jp);
    let mp = MaskPoint::new(&tail_of(&p5, log_n), n);
    let mut exts = vec![Fp2::ZERO; 2 * nb_f];
    for b in 0..nb_f { exts[b] = zl.eval_mask(&mp, a_data, zl.a_mdd[b]); }
    // [UPERF3-AM] MODE P3: the Wd block terminals, masked as the g/u ones are.
    let wd_mev: Vec<Fp2> = if is_p3 {
        let mpw = MaskPoint::new(&tail_of(&p6, zl.log_wn), zl.w_n);
        zl.w_mdd.iter().map(|&r| zl.eval_mask(&mpw, w_data_ref, r)).collect()
    } else { Vec::new() };
    let e_d = extension(&d_fin, &exts, 2, d_poly, &mc.masks[SC_D], c_d, &r_k, &mut d_rounds, tr);
    let mut rho_dm = r_k.clone();
    rho_dm.push(e_d);
    let (e_d2, fin_d2) = if is_p3 {
        let fin1: Vec<Fp2> = d_fin.iter().zip(exts.iter()).map(|(f, e)| masked_terminal(*f, *e, e_d)).collect();
        let mut exts2 = vec![Fp2::ZERO; 2 * nb_f];
        for b in 0..nb_f {
            let mut s = Fp2::ZERO;
            for c in 0..nb_d { s = s.add(lam_d[c].mul(wd_mev[b * nb_d + c])); }
            exts2[nb_f + b] = s;
        }
        let e2 = extension(&fin1, &exts2, 2, d_poly, &mc.masks[SC_D], c_d, &rho_dm, &mut d_rounds, tr);
        rho_dm.push(e2);
        (e2, fin1)
    } else { (Fp2::ZERO, Vec::new()) };
    proof.d_sc = SumcheckProof { rounds: d_rounds };
    let sel2d = Fp2::ONE.sub(e_d2);
    let (cd_d, cm_d) = if is_p3 { (sel2d.mul(Fp2::ONE.sub(e_d)), sel2d.mul(e_d)) } else { (Fp2::ONE.sub(e_d), e_d) };
    let cd_w_d = if is_p3 { sel2d.mul(Fp2::ONE.sub(e_d)) } else { Fp2::ONE };
    let mut term = Vec::with_capacity(nb_f + nb_f * nb_d);
    for b in 0..nb_f {
        term.push(if is_p3 { sel2d.mul(fin_d2[b]) } else { masked_terminal(d_fin[b], exts[b], e_d) });
    }
    for b in 0..nb_f {
        for c in 0..nb_d {
            let blk = &w_data_ref[lay.wd[b * nb_d + c]..lay.wd[b * nb_d + c] + wb];
            let folded = fold_cols_base(blk, fb, db, &eq_rjp);
            let v = eval_mle_ext(&folded, &r_k);
            term.push(if is_p3 { cd_w_d.mul(v).add(e_d2.mul(wd_mev[b * nb_d + c])) } else { v });
        }
    }
    proof.d_term = term;
    tr.absorb_fp2(b"d-term", &proof.d_term);
    // the systematic W data is dead from here (its encoding lives in w_cm): 1.4 GB at the 7B
    // shape. Under P3 it is not: the ZK commitment owns it (`pcs::CommittedZk::data`) and the
    // host fold at the opening reads it, so the P3 row carries it to the end of the layer.
    drop(w_data);
    lap("matmul d (zk)", &mut timings, &mut tick);

    // ---- zero-check F (masked; claim nu0 S''_gu + Gamma_F) ----
    let tau = tr.challenge_fp2_vec((lay.log_t + lay.log_fb) as usize);
    let mu = tr.challenge_fp2_vec(4 * nb_f);
    let nu0 = tr.challenge_fp2();
    let mut nu: Vec<Fp2> = Vec::with_capacity(3 * nb_f);
    for b in 0..nb_f { nu.push(nu0.mul(lam_f[b])); nu.push(nu0.mul(lam_f[b]).mul(lam_gu)); nu.push(Fp2::ZERO); }
    let c_f = fresh_poc::draw_mask_challenge(|| tr.challenge_fp2(), mr1)?;
    proof.gamma20 = c_f.mul(mc.masks[SC_ZC20].total()).sub(nu0.mul(c_gu).mul(g_gu_total));
    tr.absorb_fp2(b"gammaF", &[proof.gamma20]);
    let (mu_c, nu_c) = (mu.clone(), nu.clone());
    let zcf_poly = move |v: &[Fp2]| -> Fp2 {
        let (eqt, eq1, eq5) = (v[0], v[1], v[2]);
        let mut zc = Fp2::ZERO;
        let mut f1 = Fp2::ZERO;
        let mut f5 = Fp2::ZERO;
        for b in 0..nbf {
            let o = 3 + 10 * b;
            let (g8, rg, a16, u16, ru, h16, rh, hg, hu, hh) = (v[o], v[o + 1], v[o + 2], v[o + 3], v[o + 4], v[o + 5], v[o + 6], v[o + 7], v[o + 8], v[o + 9]);
            let c_had = a16.mul(u16).sub(h16.mul_base(p_h)).sub(rh);
            let c_hg = helper_constraint(hg, g8.add(beta.mul(a16)).add(g_act), rg.add(g_rg), alpha);
            let c_hu = helper_constraint(hu, u16.add(g_i16), ru.add(g_ru), alpha);
            let c_hh = helper_constraint(hh, h16.add(g_i16), rh.add(g_rh), alpha);
            zc = zc.add(mu_c[4 * b].mul(c_had)).add(mu_c[4 * b + 1].mul(c_hg)).add(mu_c[4 * b + 2].mul(c_hu)).add(mu_c[4 * b + 3].mul(c_hh));
            f1 = f1.add(nu_c[3 * b].mul(g8.mul_base(p_g).add(rg))).add(nu_c[3 * b + 1].mul(u16.mul_base(p_u).add(ru)));
            f5 = f5.add(nu_c[3 * b + 2].mul(h16));
        }
        eqt.mul(zc).add(eq1.mul(f1)).add(eq5.mul(f5))
    };
    #[cfg(feature = "gpu-cuda")]
    let dev_f = if let (true, true, Some(a_dc), Some(h_dc)) = (crate::gpu::enabled(), dev_shape, dev_of(&a_cmz.cm), dev_of(&h_cmz.cm)) {
        use crate::gpu::TabSpec;
        // [UPERF3-AI] every f-block, in the CPU's table order (3 eq, then block-major
        // g8 rg a16 u16 ru h16 rh hg hu hh) — the order `host_tabs.fb[b]` is built in.
        let mut specs_t = Vec::with_capacity(3 + 10 * nb_f);
        specs_t.extend([TabSpec::Eq(&tau), TabSpec::Eq(&p1), TabSpec::Eq(&p5)]);
        for b in 0..nb_f {
            specs_t.extend([
                TabSpec::FromFp(a_dc, lay.g8[b], tfb), TabSpec::FromFp(a_dc, lay.rg[b], tfb), TabSpec::FromFp(a_dc, lay.a16[b], tfb),
                TabSpec::FromFp(a_dc, lay.u16[b], tfb), TabSpec::FromFp(a_dc, lay.ru[b], tfb), TabSpec::FromFp(a_dc, lay.h16[b], tfb), TabSpec::FromFp(a_dc, lay.rh[b], tfb),
                TabSpec::FromFp2(h_dc, lay.hg[b].0, lay.hg[b].1, tfb), TabSpec::FromFp2(h_dc, lay.hu[b].0, lay.hu[b].1, tfb), TabSpec::FromFp2(h_dc, lay.hh[b].0, lay.hh[b].1, tfb),
            ]);
        }
        // [UPERF3-AI] the BLOCK-INDEXED parameter layout of `k_sc_round_zcf_gen` (kernels.cu):
        // the seven Fp2 constants, then p_g / p_u / p_h at index 14 (the templated kernel put
        // them LAST), then mu (4 per block) and nu (3 per block), both block-major.
        let mut prm: Vec<u64> = Vec::with_capacity(17 + 14 * nb_f);
        for v in [alpha, beta, g_act, g_rg, g_ru, g_rh, g_i16] {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        prm.extend([p_g.0, p_u.0, p_h.0]);
        for v in mu.iter().chain(nu.iter()) {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        // the attempt rides a CLONED transcript state (AH's `dev_tab` pattern): a decline
        // falls through to the host body with nothing absorbed.
        let mut tr_try = Transcript::clone_state(tr);
        tr_try.set_masker(Box::new(CfsMasker { mask: mc.masks[SC_ZC20].clone(), c: c_f, challenges: Vec::new() }));
        match crate::gpu::dev_zerocheck_blocks(0, nb_f, &specs_t, &prm, &mut tr_try) {
            Ok(out) => {
                let (_, masked) = tr_try.take_masker();
                *tr = tr_try;
                Some((masked, out.challenges, out.finals))
            }
            Err(e) => {
                let _ = tr_try.take_masker();
                eprintln!("[UPERF3-AI] gpu zero-check F (zk v3) declined ({e}); CPU path");
                None
            }
        }
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let dev_f: Option<(Vec<Vec<Fp2>>, Vec<Fp2>, Vec<Fp2>)> = None;
    let (mut rounds_f, rho_f, fin_f) = match dev_f {
        Some(x) => x,
        None => {
            let ht = host_tabs.as_mut().expect("zero-check F (zk v3): no host tables on the device path");
            let mut tables: Vec<Vec<Fp2>> = vec![eq_table_msb(&tau), eq_table_msb(&p1), eq_table_msb(&p5)];
            for b in 0..nb_f { for t in std::mem::take(&mut ht.fb[b]) { tables.push(t); } }
            masked_prove(&mut tables, 4, &zcf_poly, &mc.masks[SC_ZC20], c_f, tr)
        }
    };
    let mp = MaskPoint::new(&tail_of(&rho_f, log_n), n);
    let mut exts = vec![Fp2::ZERO; 3 + 10 * nb_f];
    for b in 0..nb_f {
        for i in 0..7 { exts[3 + 10 * b + i] = zl.eval_mask(&mp, a_data, zl.a_mf[7 * b + i]); }
        for i in 0..3 { exts[3 + 10 * b + 7 + i] = mp.eval2(h_data, zl.h_mf[3 * b + i]); }
    }
    let e_f = extension(&fin_f, &exts, 4, &zcf_poly, &mc.masks[SC_ZC20], c_f, &rho_f, &mut rounds_f, tr);
    proof.zc20_sc = SumcheckProof { rounds: rounds_f };
    proof.zc20_term = (3..3 + 10 * nb_f).map(|i| masked_terminal(fin_f[i], exts[i], e_f)).collect();
    tr.absorb_fp2(b"zcF-term", &proof.zc20_term);
    let mut rho_fe = rho_f.clone();
    rho_fe.push(e_f);
    lap("zero-check F (zk)", &mut timings, &mut tick);
    vnote("after zcF");

    // ---- zero-check D (masked; claim nu_z S''_d + Gamma_D; the X evaluation folded no more: opened at p2) ----
    let tau2 = tr.challenge_fp2_vec((lay.log_t + lay.log_db) as usize);
    let mu2 = tr.challenge_fp2_vec(nb_d);
    let nu_z = tr.challenge_fp2();
    let nu_zb: Vec<Fp2> = (0..nb_d).map(|c| nu_z.mul(lam_d[c])).collect();
    let c_dz = fresh_poc::draw_mask_challenge(|| tr.challenge_fp2(), mr1)?;
    proof.gamma17 = c_dz.mul(mc.masks[SC_ZC17].total()).sub(nu_z.mul(c_d).mul(g_d_total));
    tr.absorb_fp2(b"gammaD", &[proof.gamma17]);
    let (mu2_c, nu_zc) = (mu2.clone(), nu_zb.clone());
    let zcd_poly = move |v: &[Fp2]| -> Fp2 {
        let (eqt, _eq2, eq4) = (v[0], v[1], v[2]);
        let mut zc = Fp2::ZERO;
        let mut fz = Fp2::ZERO;
        for c in 0..nbd {
            let (z, rd, h) = (v[3 + nbd + c], v[3 + 2 * nbd + c], v[3 + 3 * nbd + c]);
            zc = zc.add(mu2_c[c].mul(helper_constraint(h, z.add(g_i16), rd.add(g_rd), alpha)));
            fz = fz.add(nu_zc[c].mul(z.mul_base(p_z).add(rd)));
        }
        eqt.mul(zc).add(eq4.mul(fz))
    };
    #[cfg(feature = "gpu-cuda")]
    let dev_d = if let (true, true, Some(a_dc), Some(h_dc)) = (crate::gpu::enabled(), dev_shape, dev_of(&a_cmz.cm), dev_of(&h_cmz.cm)) {
        use crate::gpu::TabSpec;
        let mut specs_t = vec![TabSpec::Eq(&tau2), TabSpec::Eq(&p2), TabSpec::Eq(&p4)];
        for c in 0..nb_d { specs_t.push(TabSpec::FromFp(a_dc, lay.x[c], tdb)); }
        for c in 0..nb_d { specs_t.push(TabSpec::FromFp(a_dc, lay.z[c], tdb)); }
        for c in 0..nb_d { specs_t.push(TabSpec::FromFp(a_dc, lay.rd[c], tdb)); }
        for c in 0..nb_d { specs_t.push(TabSpec::FromFp2(h_dc, lay.hz[c].0, lay.hz[c].1, tdb)); }
        // [UPERF3-AI] the BLOCK-INDEXED parameter layout of `k_sc_round_zcd_gen` (kernels.cu):
        // alpha, g_i16, g_rd, then p_z at index 6, then mu2 / nu_x / nu_z, nb_d each. The ZK
        // D-side polynomial has NO x term (X is opened at p2 instead of folded here), so nu_x
        // is nb_d ZEROs — with them the kernel computes exactly `zcd_poly` above.
        let mut prm: Vec<u64> = Vec::with_capacity(7 + 6 * nb_d);
        for v in [alpha, g_i16, g_rd] {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        prm.push(p_z.0);
        for v in mu2.iter().chain(std::iter::repeat(&Fp2::ZERO).take(nb_d)).chain(nu_zb.iter()) {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        let mut tr_try = Transcript::clone_state(tr);
        tr_try.set_masker(Box::new(CfsMasker { mask: mc.masks[SC_ZC17].clone(), c: c_dz, challenges: Vec::new() }));
        match crate::gpu::dev_zerocheck_blocks(1, nb_d, &specs_t, &prm, &mut tr_try) {
            Ok(out) => {
                let (_, masked) = tr_try.take_masker();
                *tr = tr_try;
                Some((masked, out.challenges, out.finals))
            }
            Err(e) => {
                let _ = tr_try.take_masker();
                eprintln!("[UPERF3-AI] gpu zero-check D (zk v3) declined ({e}); CPU path");
                None
            }
        }
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let dev_d: Option<(Vec<Vec<Fp2>>, Vec<Fp2>, Vec<Fp2>)> = None;
    let (mut rounds_d, rho_d, fin_d) = match dev_d {
        Some(x) => x,
        None => {
            let ht = host_tabs.as_mut().expect("zero-check D (zk v3): no host tables on the device path");
            let mut tables: Vec<Vec<Fp2>> = vec![eq_table_msb(&tau2), eq_table_msb(&p2), eq_table_msb(&p4)];
            for c in 0..nb_d { tables.push(a_data[lay.x[c]..lay.x[c] + tdb].par_iter().map(|v| Fp2::from_base(*v)).collect()); }
            let mut dbt: Vec<Vec<Vec<Fp2>>> = (0..nb_d).map(|c| std::mem::take(&mut ht.db[c])).collect();
            for role in 0..3 { for c in 0..nb_d { tables.push(std::mem::take(&mut dbt[c][role])); } }
            masked_prove(&mut tables, 4, &zcd_poly, &mc.masks[SC_ZC17], c_dz, tr)
        }
    };
    drop(host_tabs);
    let mp = MaskPoint::new(&tail_of(&rho_d, log_n), n);
    let mut exts = vec![Fp2::ZERO; 3 + 4 * nb_d];
    for c in 0..nb_d {
        exts[3 + c] = zl.eval_mask(&mp, a_data, zl.a_md[3 * c]);
        exts[3 + nb_d + c] = zl.eval_mask(&mp, a_data, zl.a_md[3 * c + 1]);
        exts[3 + 2 * nb_d + c] = zl.eval_mask(&mp, a_data, zl.a_md[3 * c + 2]);
        exts[3 + 3 * nb_d + c] = mp.eval2(h_data, zl.h_md[c]);
    }
    let e_dz = extension(&fin_d, &exts, 4, &zcd_poly, &mc.masks[SC_ZC17], c_dz, &rho_d, &mut rounds_d, tr);
    proof.zc17_sc = SumcheckProof { rounds: rounds_d };
    proof.zc17_term = (3..3 + 4 * nb_d).map(|i| masked_terminal(fin_d[i], exts[i], e_dz)).collect();
    tr.absorb_fp2(b"zcD-term", &proof.zc17_term);
    let mut rho_de = rho_d.clone();
    rho_de.push(e_dz);
    lap("zero-check D (zk)", &mut timings, &mut tick);

    // ---- the table-side zero-check over log_S variables (masked): eq(tau3) sum_t mu3_t (h_t (alpha - tval_t) - m_t) = 0 ----
    let tau3 = tr.challenge_fp2_vec(log_s);
    let mu3 = tr.challenge_fp2_vec(zl.tabs.len());
    let c_tab = fresh_poc::draw_mask_challenge(|| tr.challenge_fp2(), mr1)?;
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
    let big = 1usize << log_s;
    // [UPERF3-AH] (rung 3) THE TABLE ZERO-CHECK ON THE DEVICE — lane AD's item: at v3 this
    // sumcheck runs over 2^16 variables and was the last host sumcheck of the ZK prover
    // (AD: 1.14 s = 20% of the GPU ZK prove). The tables are built on the device from the
    // resident A / H data plus the uploaded PUBLIC table values, each zero-extended to 2^log_S
    // exactly as the host's `resize(big, ZERO)`; the ZK masker rides the transcript as in the
    // other two device zero-checks. Attempted on a CLONED transcript state, so a decline
    // (allocation, an unexpected shape) falls through to the host body with nothing absorbed.
    #[cfg(feature = "gpu-cuda")]
    let dev_tab = if let (true, Some(a_dc), Some(h_dc)) = (crate::gpu::enabled(), dev_of(&a_cmz.cm), dev_of(&h_cmz.cm)) {
        use crate::gpu::TabSpecPad;
        let mut specs: Vec<TabSpecPad> = Vec::with_capacity(1 + 3 * n_tabs);
        specs.push(TabSpecPad::Eq(&tau3));
        for (t, tv) in zl.tabs.iter().zip(tvals.iter()) {
            let len = 1usize << t.log_size;
            specs.push(TabSpecPad::FromFp(a_dc, t.a_row * n, len));
            specs.push(TabSpecPad::FromFp2(h_dc, t.h_re * n, t.h_im * n, len));
            specs.push(TabSpecPad::Host(tv));
        }
        let mut prm: Vec<u64> = Vec::with_capacity(2 + 2 * n_tabs);
        prm.push(alpha.c0.0);
        prm.push(alpha.c1.0);
        for v in mu3.iter() { prm.push(v.c0.0); prm.push(v.c1.0); }
        let mut tr_try = Transcript::clone_state(tr);
        tr_try.set_masker(Box::new(CfsMasker { mask: mc.masks[SC_TAB].clone(), c: c_tab, challenges: Vec::new() }));
        match crate::gpu::dev_tab_zerocheck(&specs, &prm, &mut tr_try) {
            Ok(out) => {
                let (_, masked) = tr_try.take_masker();
                *tr = tr_try;
                Some((masked, out.challenges, out.finals))
            }
            Err(e) => {
                let _ = tr_try.take_masker();
                eprintln!("[UPERF3-AH] gpu table zero-check declined ({e}); CPU path");
                None
            }
        }
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let dev_tab: Option<(Vec<Vec<Fp2>>, Vec<Fp2>, Vec<Fp2>)> = None;
    let (mut rounds_tab, rho_tab, fin_tab) = match dev_tab {
        Some(x) => x,
        None => {
            let mut tables: Vec<Vec<Fp2>> = vec![eq_table_msb(&tau3)];
            for (t, tv) in zl.tabs.iter().zip(tvals.iter()) {
                let len = 1usize << t.log_size;
                let mut m: Vec<Fp2> = (0..len).into_par_iter().map(|j| Fp2::from_base(a_data[t.a_row * n + j])).collect();
                m.resize(big, Fp2::ZERO);
                let mut h: Vec<Fp2> = (0..len).into_par_iter().map(|j| Fp2::new(h_data[t.h_re * n + j], h_data[t.h_im * n + j])).collect();
                h.resize(big, Fp2::ZERO);
                let mut tvx = tv.clone();
                tvx.resize(big, Fp2::ZERO);
                tables.push(m);
                tables.push(h);
                tables.push(tvx);
            }
            let out = masked_prove(&mut tables, 3, &tab_poly, &mc.masks[SC_TAB], c_tab, tr);
            drop(tables);
            out
        }
    };
    if mr1 { fresh_poc::check_table_point(&zl, &rho_tab)?; }
    let mut exts = vec![Fp2::ZERO; 1 + 3 * n_tabs];
    for (i, t) in zl.tabs.iter().enumerate() {
        let k = log_s - t.log_size as usize;
        let coef = ext_coef(&rho_tab, k);
        let pt = &rho_tab[k..];
        exts[1 + 3 * i] = coef.mul(eval_slice(a_data, t.a_mask * n, pt));
        if mr1 && t.rows == 1 { exts[1 + 3 * i] = exts[1 + 3 * i].add(coef.mul(Fp2::U).mul(eval_slice(a_data, (t.a_mask + 1) * n, pt))); }
        exts[2 + 3 * i] = coef.mul(eval_slice(h_data, t.h_mre * n, pt).add(Fp2::U.mul(eval_slice(h_data, t.h_mim * n, pt))));
    }
    let e_tab = extension(&fin_tab, &exts, 3, &tab_poly, &mc.masks[SC_TAB], c_tab, &rho_tab, &mut rounds_tab, tr);
    proof.tab_sc = SumcheckProof { rounds: rounds_tab };
    proof.tab_term = (0..n_tabs).flat_map(|i| [masked_terminal(fin_tab[1 + 3 * i], exts[1 + 3 * i], e_tab), masked_terminal(fin_tab[2 + 3 * i], exts[2 + 3 * i], e_tab)]).collect();
    tr.absorb_fp2(b"tab-term", &proof.tab_term);
    let mut rho_tabe = rho_tab.clone();
    rho_tabe.push(e_tab);
    lap("table zero-check (zk)", &mut timings, &mut tick);

    // ---- the zero-sum sumcheck over u (masked; claim Gamma_zs = c_zs G_zs) ----
    let c_zs = fresh_poc::draw_mask_challenge(|| tr.challenge_fp2(), mr1)?;
    proof.gamma_zs = c_zs.mul(mc.masks[SC_ZSUM].total());
    tr.absorb_fp2(b"gamma-zs", &[proof.gamma_zs]);
    let zs_poly = |v: &[Fp2]| v[0].mul(v[1]);
    let u_tab: Vec<Fp2> = (0..n).map(|j| Fp2::new(h_data[zl.h_u.0 * n + j], h_data[zl.h_u.1 * n + j])).collect();
    let mut tables = vec![vec![Fp2::ONE; n], u_tab];
    let (mut rounds_zs, rho_zs, fin_zs) = masked_prove(&mut tables, 2, zs_poly, &mc.masks[SC_ZSUM], c_zs, tr);
    let exts = vec![Fp2::ZERO, MaskPoint::new(&rho_zs, n).eval2(h_data, zl.h_up)];
    let e_zs = extension(&fin_zs, &exts, 2, zs_poly, &mc.masks[SC_ZSUM], c_zs, &rho_zs, &mut rounds_zs, tr);
    proof.zs_sc = SumcheckProof { rounds: rounds_zs };
    proof.zs_term = masked_terminal(fin_zs[1], exts[1], e_zs);
    tr.absorb_fp2(b"zs-term", &[proof.zs_term]);
    let mut rho_zse = rho_zs.clone();
    rho_zse.push(e_zs);

    // ---- [UPERF3-AN] FUNCTION 2: THE PREDICATE SUMCHECK ----------------------
    // ONE masked sumcheck over the d-block cube proves both halves of the
    // content filter at once:
    //
    //   sum_y [ eq(y, pt) z_c(y) - w(y) B(y) + nu eqr(y) (B(y)^2 - B(y)) ] = tau
    //
    //   * eq(y, pt) picks the frozen output entry OUT OF THE COMMITMENT, so the
    //     score the predicate is about is the committed one and not a side
    //     value the prover chose;
    //   * w is the PUBLIC weight table (2^i on i < 16, ZERO elsewhere), so
    //     sum_y w(y) B(y) is the recomposition of the 16 bit planes and a bit
    //     planted outside the 16 columns is worth nothing;
    //   * the eqr term sums to zero exactly when those 16 entries are BOOLEAN.
    //
    // Together: y - (a 16-bit integer) = tau, i.e. y - tau in [0, 65535], i.e.
    // y - tau >= 0, since y and tau are both int16 (y by the TAG_INT16 lookup
    // the layer already proves, so no NEW lookup and no new table).
    // THE CLAIMED SUM IS THE PUBLIC CONSTANT tau: the sumcheck reveals no
    // witness quantity, and it is sent masked in the same CFS form as the other
    // six. Cost: one degree-3 sumcheck over ONE d-block.
    let mut pred_ctx: Option<(Vec<Fp2>, Fp2, Fp2)> = None;
    if let Some(p) = &pred {
        let nv = (lay.log_t + lay.log_db) as usize;
        let c_blk = p.col / db;
        let pt_pred = bool_point(p.row * db + (p.col % db), nv);
        let tau_p = tr.challenge_fp2_vec(nv);
        let nu_p = tr.challenge_fp2();
        let c_pred = fresh_poc::draw_mask_challenge(|| tr.challenge_fp2(), mr1)?;
        let gamma_pred = c_pred.mul(mc.masks[SC_PRED].total());
        tr.absorb_fp2(b"gamma-pred", &[gamma_pred]);
        let pred_poly = move |v: &[Fp2]| -> Fp2 {
            v[0].mul(v[1]).sub(v[3].mul(v[2])).add(nu_p.mul(v[4]).mul(v[2].mul(v[2]).sub(v[2])))
        };
        let big = 1usize << nv;
        let mut tables: Vec<Vec<Fp2>> = vec![
            eq_table_msb(&pt_pred),
            a_data[lay.z[c_blk]..lay.z[c_blk] + tdb].par_iter().map(|v| Fp2::from_base(*v)).collect(),
            {
                let mut b: Vec<Fp2> = (0..n).map(|j| Fp2::from_base(a_data[zl.a_pb * n + j])).collect();
                b.resize(big, Fp2::ZERO);
                b
            },
            {
                let mut wt = vec![Fp2::ZERO; big];
                for (i, s) in wt.iter_mut().enumerate().take(PRED_BITS) { *s = Fp2::from_u64(1u64 << i); }
                wt
            },
            eq_table_msb(&tau_p),
        ];
        let (mut rounds_p, rho_p, fin_p) = masked_prove(&mut tables, 3, &pred_poly, &mc.masks[SC_PRED], c_pred, tr);
        drop(tables);
        let mp = MaskPoint::new(&tail_of(&rho_p, log_n), n);
        let coef_b = ext_coef(&rho_p, nv - log_n);
        let mut exts = vec![Fp2::ZERO; 5];
        exts[1] = zl.eval_mask(&mp, a_data, zl.a_pmz);
        exts[2] = coef_b.mul(zl.eval_mask(&mp, a_data, zl.a_pmb));
        let e_p = extension(&fin_p, &exts, 3, &pred_poly, &mc.masks[SC_PRED], c_pred, &rho_p, &mut rounds_p, tr);
        let term = vec![masked_terminal(fin_p[1], exts[1], e_p), masked_terminal(fin_p[2], exts[2], e_p)];
        tr.absorb_fp2(b"pred-term", &term);
        proof.pred = Some(PredProofV3 { gamma: gamma_pred, sc: SumcheckProof { rounds: rounds_p }, term });
        sites.push(format!(
            "predicate (function 2): {} -> bit row {} (cols 0..{PRED_BITS}), mask rows {} (bits) / {} (output block); sumcheck {nv} vars degree 3, claimed sum = the PUBLIC tau",
            p.tag(), zl.a_pb, zl.a_pmb, zl.a_pmz
        ));
        pred_ctx = Some((rho_p, e_p, c_pred));
    }

    // ---- the mask opening: the six g(rho)'s and the four Gammas in one product-form test ----
    let g_vals = [mc.masks[SC_GU].eval(&rho_gu), mc.masks[SC_D].eval(&rho_dm), mc.masks[SC_ZC20].eval(&rho_fe), mc.masks[SC_ZC17].eval(&rho_de), mc.masks[SC_ZSUM].eval(&rho_zse), mc.masks[SC_TAB].eval(&rho_tabe)];
    let mut fs = mask_functionals(&specs, [&rho_gu, &rho_dm, &rho_fe, &rho_de, &rho_zse, &rho_tabe], g_vals, [c_gu, c_d, c_f, c_dz, c_zs, c_tab], nu0, nu_z, [proof.gamma20, proof.gamma17, proof.gamma_zs, proof.gamma_tab]);
    if let Some((rho_p, e_p, c_pred)) = &pred_ctx {
        // [UPERF3-AN] the 7th slot: g_pred(rho) and Gamma_pred, in the same product-form test
        let mut rho_pe = rho_p.clone();
        rho_pe.push(*e_p);
        push_pred_functionals(&mut fs, &specs, &rho_pe, mc.masks[SC_PRED].eval(&rho_pe), *c_pred, proof.pred.as_ref().unwrap().gamma);
    }
    // Retain M/W/A/H until every fixed-profile claim has been assembled.
    let pred_claims = pred.as_ref().zip(pred_ctx.as_ref()).map(|(p, (rho_p, e_p, _))| (p, rho_p.as_slice(), *e_p));
    let (wc, ac, hc) = build_claims_zk_v3(&zl, &proof, &p2, &p5, &rho_f, &rho_d, &rho_zs, &rho_tab, (cd_gu, cm_gu), (cd_d, cm_d), e_f, e_dz, e_zs, e_tab, &p3, &p6, pred_claims);
    let w = match (w_cm, w_cmz) {
        (Some(cm), None) => PendingWeightV3::Public(cm, wc),
        (None, Some(cm)) => PendingWeightV3::Private(cm,
            build_w_zclaims_v3(&zl, &proof, &p3, &p6, (cd_w_gu, e_gu2), (cd_w_d, e_d2))),
        _ => unreachable!(),
    };
    Ok(PendingV3 { proof, zl, mc, fs, w, a: a_cmz, h: h_cmz, ac, hc, timings, sites, tick })
}

/// [UPERF3-AM] MODE P3: the HIDING claims on W, shared by the prover and the
/// verifier. Each block claim is the two-part masked claim
/// `(1 - e) W_blk~(p) + e R_blk~(tail p)` against the block's own mask row —
/// the same form lane ZA gave every A and H opening site, with one mask row per
/// block so that no difference of two blocks' evaluations is in the clear. The
/// two points (p3 for the g/u blocks, p6 for the d blocks) give exactly two
/// column-weight groups, each of which therefore touches a mask row.
fn build_w_zclaims_v3(zl: &ZkLayoutV3, proof: &LayerProofZk, w_p3: &[Fp2], w_p6: &[Fp2], k_gu: (Fp2, Fp2), k_d: (Fp2, Fp2)) -> Vec<ZClaim> {
    let lay = &zl.lay;
    let (nb_d, nb_f) = (lay.nb_d, lay.nb_f);
    let wn = zl.w_n;
    let log_wn = zl.log_wn;
    let s_w = |off: usize| Slice { offset: off, log_size: lay.log_wb };
    let s_row = |row: usize| Slice { offset: row * wn, log_size: log_wn as u32 };
    let tail = |p: &[Fp2]| p[p.len() - log_wn..].to_vec();
    let masked = |sl: Slice, mask_row: usize, p: &[Fp2], k: (Fp2, Fp2), value: Fp2| zl.pair_claim(ZClaim {
        parts: vec![ZPart { slice: sl, coef: k.0, point: p.to_vec() }, ZPart { slice: s_row(mask_row), coef: k.1, point: tail(p) }],
        value,
    });
    let mut wc = Vec::with_capacity(3 * nb_d * nb_f);
    for (ri, offs) in [(0usize, &lay.wg), (1, &lay.wu)] {
        for c in 0..nb_d {
            for b in 0..nb_f {
                let k = ri * nb_d * nb_f + c * nb_f + b;
                wc.push(masked(s_w(offs[c * nb_f + b]), zl.w_mgu[k], w_p3, k_gu, proof.gu_term[nb_d + k]));
            }
        }
    }
    for b in 0..nb_f {
        for c in 0..nb_d {
            wc.push(masked(s_w(lay.wd[b * nb_d + c]), zl.w_mdd[b * nb_d + c], w_p6, k_d, proof.d_term[nb_f + b * nb_d + c]));
        }
    }
    wc
}

/// The claims on W (plain), A and H (ZK) of a v3 layer proof, shared by the prover and the verifier.
#[allow(clippy::too_many_arguments)]
fn build_claims_zk_v3(zl: &ZkLayoutV3, proof: &LayerProofZk, p2: &[Fp2], p5: &[Fp2], rho_f: &[Fp2], rho_d: &[Fp2], rho_zs: &[Fp2], rho_tab: &[Fp2], k_gu: (Fp2, Fp2), k_d: (Fp2, Fp2), e_f: Fp2, e_dz: Fp2, e_zs: Fp2, e_tab: Fp2, w_p3: &[Fp2], w_p6: &[Fp2], pred: Option<(&PredicateSpec, &[Fp2], Fp2)>) -> (Vec<Claim>, Vec<ZClaim>, Vec<ZClaim>) {
    let lay = &zl.lay;
    let (nb_d, nb_f) = (lay.nb_d, lay.nb_f);
    let one = Fp2::ONE;
    let u = Fp2::U;
    let n = zl.a_n;
    let log_n = zl.log_n;
    let s_w = |off: usize| Slice { offset: off, log_size: lay.log_wb };
    let s_f = |off: usize| Slice { offset: off, log_size: lay.log_t + lay.log_fb };
    let s_d = |off: usize| Slice { offset: off, log_size: lay.log_t + lay.log_db };
    let s_row = |row: usize| Slice { offset: row * n, log_size: log_n as u32 };
    let tail = |p: &[Fp2]| p[p.len() - log_n..].to_vec();
    // W as built (ZB's claims)
    let mut wc = Vec::new();
    for (ri, offs) in [(0usize, &lay.wg), (1, &lay.wu)] {
        for c in 0..nb_d {
            for b in 0..nb_f {
                wc.push(Claim { parts: vec![(s_w(offs[c * nb_f + b]), one)], point: w_p3.to_vec(), sum: false, value: proof.gu_term[nb_d + ri * nb_d * nb_f + c * nb_f + b] });
            }
        }
    }
    for b in 0..nb_f {
        for c in 0..nb_d {
            wc.push(Claim { parts: vec![(s_w(lay.wd[b * nb_d + c]), one)], point: w_p6.to_vec(), sum: false, value: proof.d_term[nb_f + b * nb_d + c] });
        }
    }
    // A: masked claims (1 - e) T~(p) + e R~(tail p)
    let masked = |sl: Slice, mask_row: usize, p: &[Fp2], e: Fp2, value: Fp2| zl.pair_claim(ZClaim {
        parts: vec![ZPart { slice: sl, coef: one.sub(e), point: p.to_vec() }, ZPart { slice: s_row(mask_row), coef: e, point: tail(p) }],
        value,
    });
    let mut ac = Vec::new();
    for b in 0..nb_f {
        let cols = [lay.g8[b], lay.rg[b], lay.a16[b], lay.u16[b], lay.ru[b], lay.h16[b], lay.rh[b]];
        for (i, off) in cols.iter().enumerate() { ac.push(masked(s_f(*off), zl.a_mf[7 * b + i], rho_f, e_f, proof.zc20_term[10 * b + i])); }
    }
    for c in 0..nb_d {
        ac.push(masked(s_d(lay.x[c]), zl.a_md[3 * c], rho_d, e_dz, proof.zc17_term[c]));
        ac.push(masked(s_d(lay.z[c]), zl.a_md[3 * c + 1], rho_d, e_dz, proof.zc17_term[nb_d + c]));
        ac.push(masked(s_d(lay.rd[c]), zl.a_md[3 * c + 2], rho_d, e_dz, proof.zc17_term[2 * nb_d + c]));
    }
    // [UPERF3-AM] the two matmul-opened planes carry the coefficient PAIR, because under P3
    // their sumcheck has a second extension round (see mask_specs_v3).
    let masked2 = |sl: Slice, mask_row: usize, p: &[Fp2], k: (Fp2, Fp2), value: Fp2| zl.pair_claim(ZClaim {
        parts: vec![ZPart { slice: sl, coef: k.0, point: p.to_vec() }, ZPart { slice: s_row(mask_row), coef: k.1, point: tail(p) }],
        value,
    });
    for c in 0..nb_d { ac.push(masked2(s_d(lay.x[c]), zl.a_mgu[c], p2, k_gu, proof.gu_term[c])); }
    for b in 0..nb_f { ac.push(masked2(s_f(lay.h16[b]), zl.a_mdd[b], p5, k_d, proof.d_term[b])); }
    // the multiplicity slots at rho_tab[k..] with the zero-extension coefficient prod_{j<k}(1 - rho_j)
    for (i, t) in zl.tabs.iter().enumerate() {
        let k = zl.log_s - t.log_size as usize;
        let coef = ext_coef(rho_tab, k);
        let pt = rho_tab[k..].to_vec();
        let s = |row: usize| Slice { offset: row * n, log_size: t.log_size };
        let claim = ZClaim {
            parts: vec![ZPart { slice: s(t.a_row), coef: one.sub(e_tab).mul(coef), point: pt.clone() }, ZPart { slice: s(t.a_mask), coef: e_tab.mul(coef), point: pt }],
            value: proof.tab_term[2 * i],
        };
        ac.push(if t.rows == 1 { zl.pair_claim(claim) } else { claim });
    }
    // [UPERF3-AN] FUNCTION 2: the predicate sumcheck's two private terminals. Both
    // sit in ONE column-weight group (the tail of rho_p on the whole row), so the
    // group is masked by a_pmz / a_pmb and neither the committed output entry nor
    // any bit plane is ever opened in the clear.
    if let Some((p, rho_p, e_p)) = pred {
        let nv = (lay.log_t + lay.log_db) as usize;
        let dbk = 1usize << lay.log_db;
        let pp = proof.pred.as_ref().expect("function 2: no predicate gadget");
        ac.push(masked(s_d(lay.z[p.col / dbk]), zl.a_pmz, rho_p, e_p, pp.term[0]));
        let coef_b = ext_coef(rho_p, nv - log_n);
        let pt_b = rho_p[nv - log_n..].to_vec();
        ac.push(zl.pair_claim(ZClaim {
            parts: vec![
                ZPart { slice: s_row(zl.a_pb), coef: one.sub(e_p).mul(coef_b), point: pt_b.clone() },
                ZPart { slice: s_row(zl.a_pmb), coef: e_p.mul(coef_b), point: pt_b },
            ],
            value: pp.term[1],
        }));
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
    for b in 0..nb_f {
        for (i, (re, im)) in [lay.hg[b], lay.hu[b], lay.hh[b]].iter().enumerate() {
            hc.push(masked2(s_f(*re), s_f(*im), zl.h_mf[3 * b + i], rho_f, e_f, proof.zc20_term[10 * b + 7 + i]));
        }
    }
    for c in 0..nb_d {
        let (re, im) = lay.hz[c];
        hc.push(masked2(s_d(re), s_d(im), zl.h_md[c], rho_d, e_dz, proof.zc17_term[3 * nb_d + c]));
    }
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
    // the table-side helpers at rho_tab[k..]
    for (i, t) in zl.tabs.iter().enumerate() {
        let k = zl.log_s - t.log_size as usize;
        let coef = ext_coef(rho_tab, k);
        let pt = rho_tab[k..].to_vec();
        let s = |row: usize| Slice { offset: row * n, log_size: t.log_size };
        hc.push(ZClaim {
            parts: vec![
                ZPart { slice: s(t.h_re), coef: one.sub(e_tab).mul(coef), point: pt.clone() },
                ZPart { slice: s(t.h_im), coef: one.sub(e_tab).mul(coef).mul(u), point: pt.clone() },
                ZPart { slice: s(t.h_mre), coef: e_tab.mul(coef), point: pt.clone() },
                ZPart { slice: s(t.h_mim), coef: e_tab.mul(coef).mul(u), point: pt },
            ],
            value: proof.tab_term[2 * i + 1],
        });
    }
    // THE LOGUP IDENTITY as one value-0 sum claim: witness helpers - table helpers + the zero-sum row u
    let mut parts = Vec::new();
    for b in 0..nb_f {
        for (re, im) in [lay.hg[b], lay.hu[b], lay.hh[b]] {
            parts.push(ZPart { slice: s_f(re), coef: one, point: vec![] });
            parts.push(ZPart { slice: s_f(im), coef: u, point: vec![] });
        }
    }
    for c in 0..nb_d {
        let (re, im) = lay.hz[c];
        parts.push(ZPart { slice: s_d(re), coef: one, point: vec![] });
        parts.push(ZPart { slice: s_d(im), coef: u, point: vec![] });
    }
    for t in &zl.tabs {
        parts.push(ZPart { slice: Slice { offset: t.h_re * n, log_size: t.log_size }, coef: one.neg(), point: vec![] });
        parts.push(ZPart { slice: Slice { offset: t.h_im * n, log_size: t.log_size }, coef: u.neg(), point: vec![] });
    }
    parts.push(ZPart { slice: s_row(zl.h_u.0), coef: one, point: vec![] });
    parts.push(ZPart { slice: s_row(zl.h_u.1), coef: u, point: vec![] });
    hc.push(ZClaim { parts, value: Fp2::ZERO });
    (wc, ac, hc)
}

/// Verify one v3 ZK layer proof against the public statement.
pub fn verify_layer_zk_v3(st: &StatementV3, proof: &LayerProofZk, params: &LayerParams, ntt: &NttTables, tr: &mut Transcript, mode: &ZkStatementMode) -> Result<(), String> {
    verify_layer_zk_v3_inner(st, proof, params, ntt, tr, mode, false)
}

fn verify_layer_zk_v3_inner(st: &StatementV3, proof: &LayerProofZk, params: &LayerParams, ntt: &NttTables, tr: &mut Transcript, mode: &ZkStatementMode, mr1: bool) -> Result<(), String> {
    verify_layer_zk_v3_with_seams(st, proof, params, ntt, tr, mode, mr1, false, |_, _, _, _| Ok(()))
}

fn verify_layer_zk_v3_with_seams(st: &StatementV3, proof: &LayerProofZk, params: &LayerParams, ntt: &NttTables, tr: &mut Transcript, mode: &ZkStatementMode, mr1: bool, io: bool,
    before_openings: impl FnOnce(&ZkLayoutV3, &mut Vec<ZClaim>, &mut Vec<MaskFunctional>, &mut Transcript) -> Result<(), String>) -> Result<(), String> {
    // [UPERF3-AN] FUNCTION 2: the declared predicate (None = function 1). A statement
    // whose output-claim slot and predicate parameters disagree names no predicate
    // and is refused before any challenge is drawn.
    let pred = mode.predicate()?;
    if let Some(p) = pred {
        if p.row >= st.t_rows || p.col >= st.d {
            return Err(format!("function 2: the predicate's (row {}, col {}) is outside the {}x{} output plane", p.row, p.col, st.t_rows, st.d));
        }
    }
    // A function-1 proof carries no predicate gadget and a function-2 proof does, so
    // neither can be presented as the other even before the header diverges.
    if proof.pred.is_some() != pred.is_some() {
        return Err(format!(
            "output claim mismatch: the statement declares {} and the proof carries {}",
            if pred.is_some() { "function 2 (a predicate)" } else { "function 1 (commit only)" },
            if proof.pred.is_some() { "a predicate gadget" } else { "none" }
        ));
    }
    let zl = if io {
        if !mr1 || pred.is_some() { return Err("IO requires the fresh function-1 schedule".into()); }
        ZkLayoutV3::with_io(st, params)
    } else { ZkLayoutV3::with_masks(st.t_rows, st.d, st.f, params, st.shifts, pred.is_some(), mr1) };
    let lay = zl.lay.clone();
    let (nb_d, nb_f) = (lay.nb_d, lay.nb_f);
    let n = zl.a_n;
    let log_n = zl.log_n;
    let log_s = zl.log_s;
    let (sh_g, sh_u, sh_h, sh_z) = st.shifts;
    absorb_statement_v3(tr, st);
    // [UPERF3-AM] the verifier is TOLD which privacy claim and which output claim it is
    // checking; the header is in the Fiat-Shamir domain, so a proof made under one header
    // diverges at the first challenge under any other. A P1 proof cannot be presented as P3,
    // and a function-1 proof cannot be presented as function-2.
    let is_p3 = mode.privacy == ZkPrivacy::P3;
    tr.absorb(b"zk", &mode.header_v3());
    let w_com = proof.w_com.as_ref().ok_or("missing W commitment")?;
    let a_com = proof.a_com.as_ref().ok_or("missing A commitment")?;
    let h_com = proof.h_com.as_ref().ok_or("missing H commitment")?;
    let w_pcs = pcs_params(params, lay.log_wb);
    let a_pcs = pcs_params(params, lay.log_a_min);
    let h_pcs = pcs_params(params, lay.log_a_min);
    let w_rows_want = if is_p3 { zl.w_len_p3 } else { lay.w_len } / w_pcs.cols();
    if w_com.rows != w_rows_want { return Err("W commitment rows".into()); }
    if a_com.rows != zl.a_len / n { return Err("A commitment rows".into()); }
    if h_com.rows != zl.h_len / n { return Err("H commitment rows".into()); }
    absorb_com(tr, b"W", w_com);
    absorb_com(tr, b"A", a_com);
    let specs = mask_specs_v3(&zl, is_p3);
    tr.absorb(b"M", &proof.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    absorb_com(tr, b"H", h_com);
    let g_act = gamma.mul_base(Fp::new(TAG_ACT16));
    let g_i16 = gamma.mul_base(Fp::new(TAG_INT16));
    let g_rg = gamma.mul_base(Fp::new(tag_rem_v3(sh_g)));
    let g_ru = gamma.mul_base(Fp::new(tag_rem_v3(sh_u)));
    let g_rh = gamma.mul_base(Fp::new(tag_rem_v3(sh_h)));
    let g_rd = gamma.mul_base(Fp::new(tag_rem_v3(sh_z)));
    let (p_g, p_u, p_h, p_z) = (pow2_signed(sh_g), pow2_signed(sh_u), pow2_signed(sh_h), pow2_signed(sh_z));
    let div = |num: Fp2, c: Fp2| -> Result<Fp2, String> { if c.is_zero() { Err("zero mask challenge".into()) } else { Ok(num.mul(c.inv())) } };

    // ---- g/u ----
    let r_i = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_j = tr.challenge_fp2_vec(lay.log_fb as usize);
    let lam_gu = tr.challenge_fp2();
    let lam_f = tr.challenge_fp2_vec(nb_f);
    let mut p1 = r_i.clone();
    p1.extend_from_slice(&r_j);
    let c_gu = tr.challenge_fp2();
    tr.absorb_fp2(b"gu-claim", &[proof.gu_claim]);
    let ext_rounds = 1 + usize::from(is_p3);
    let (fin, rho_gu) = sumcheck::verify(proof.gu_claim, 2, lay.log_db as usize + ext_rounds, &proof.gu_sc, tr)?;
    let r_kp = rho_gu[..lay.log_db as usize].to_vec();
    let e_gu = rho_gu[lay.log_db as usize];
    let e_gu2 = if is_p3 { rho_gu[lay.log_db as usize + 1] } else { Fp2::ZERO };
    let sel2 = Fp2::ONE.sub(e_gu2);
    let (cd_gu, cm_gu) = if is_p3 { (sel2.mul(Fp2::ONE.sub(e_gu)), sel2.mul(e_gu)) } else { (Fp2::ONE.sub(e_gu), e_gu) };
    let cd_w_gu = if is_p3 { sel2.mul(Fp2::ONE.sub(e_gu)) } else { Fp2::ONE };
    if proof.gu_term.len() != nb_d + 2 * nb_d * nb_f { return Err("gu terminal".into()); }
    // [UPERF3-AM] under P1 the W block terminals are in the clear and the extension round's
    // (1 - e) selector is applied here; under P3 they are the MASKED terminals, whose
    // combination already IS the extended W table value (the prover set the W tables'
    // extension to the same combination of the block masks), so the selector is not applied.
    let sel = if is_p3 { Fp2::ONE } else { Fp2::ONE.sub(e_gu) };
    let mut want = Fp2::ZERO;
    for c in 0..nb_d {
        let mut wsum = Fp2::ZERO;
        for b in 0..nb_f {
            let wg = proof.gu_term[nb_d + c * nb_f + b];
            let wu = proof.gu_term[nb_d + nb_d * nb_f + c * nb_f + b];
            wsum = wsum.add(lam_f[b].mul(wg.add(lam_gu.mul(wu))));
        }
        want = want.add(proof.gu_term[c].mul(sel.mul(wsum)));
    }
    let g_gu_val = div(fin.sub(want), c_gu)?;
    tr.absorb_fp2(b"gu-term", &proof.gu_term);
    let mut p2 = r_i.clone();
    p2.extend_from_slice(&r_kp);
    let mut p3 = r_kp.clone();
    p3.extend_from_slice(&r_j);

    // ---- d ----
    let r_ip = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_jp = tr.challenge_fp2_vec(lay.log_db as usize);
    let lam_d = tr.challenge_fp2_vec(nb_d);
    let mut p4 = r_ip.clone();
    p4.extend_from_slice(&r_jp);
    let c_d = tr.challenge_fp2();
    tr.absorb_fp2(b"d-claim", &[proof.d_claim]);
    let (fin, rho_dm) = sumcheck::verify(proof.d_claim, 2, lay.log_fb as usize + ext_rounds, &proof.d_sc, tr)?;
    let r_k = rho_dm[..lay.log_fb as usize].to_vec();
    let e_d = rho_dm[lay.log_fb as usize];
    let e_d2 = if is_p3 { rho_dm[lay.log_fb as usize + 1] } else { Fp2::ZERO };
    let sel2d = Fp2::ONE.sub(e_d2);
    let (cd_d, cm_d) = if is_p3 { (sel2d.mul(Fp2::ONE.sub(e_d)), sel2d.mul(e_d)) } else { (Fp2::ONE.sub(e_d), e_d) };
    let cd_w_d = if is_p3 { sel2d.mul(Fp2::ONE.sub(e_d)) } else { Fp2::ONE };
    if proof.d_term.len() != nb_f + nb_f * nb_d { return Err("d terminal".into()); }
    let sel = if is_p3 { Fp2::ONE } else { Fp2::ONE.sub(e_d) };
    let mut want = Fp2::ZERO;
    for b in 0..nb_f {
        let wd_comb = (0..nb_d).fold(Fp2::ZERO, |a, c| a.add(lam_d[c].mul(proof.d_term[nb_f + b * nb_d + c])));
        want = want.add(proof.d_term[b].mul(sel.mul(wd_comb)));
    }
    let g_d_val = div(fin.sub(want), c_d)?;
    tr.absorb_fp2(b"d-term", &proof.d_term);
    let mut p5 = r_ip.clone();
    p5.extend_from_slice(&r_k);
    let mut p6 = r_k.clone();
    p6.extend_from_slice(&r_jp);

    // ---- zero-check F ----
    let tau = tr.challenge_fp2_vec((lay.log_t + lay.log_fb) as usize);
    let mu = tr.challenge_fp2_vec(4 * nb_f);
    let nu0 = tr.challenge_fp2();
    let c_f = tr.challenge_fp2();
    tr.absorb_fp2(b"gammaF", &[proof.gamma20]);
    let claimed = nu0.mul(proof.gu_claim).add(proof.gamma20);
    let nvf = (lay.log_t + lay.log_fb) as usize;
    let (fin, rho_fe) = sumcheck::verify(claimed, 4, nvf + 1, &proof.zc20_sc, tr)?;
    let rho_f = rho_fe[..nvf].to_vec();
    let e_f = rho_fe[nvf];
    if proof.zc20_term.len() != 10 * nb_f { return Err("zcF terminal".into()); }
    let g_f_val = {
        let v = &proof.zc20_term;
        let mut zc = Fp2::ZERO;
        let mut f1 = Fp2::ZERO;
        for b in 0..nb_f {
            let o = 10 * b;
            let (g8, rg, a16, u16, ru, h16, rh, hg, hu, hh) = (v[o], v[o + 1], v[o + 2], v[o + 3], v[o + 4], v[o + 5], v[o + 6], v[o + 7], v[o + 8], v[o + 9]);
            let c_had = a16.mul(u16).sub(h16.mul_base(p_h)).sub(rh);
            let c_hg = helper_constraint(hg, g8.add(beta.mul(a16)).add(g_act), rg.add(g_rg), alpha);
            let c_hu = helper_constraint(hu, u16.add(g_i16), ru.add(g_ru), alpha);
            let c_hh = helper_constraint(hh, h16.add(g_i16), rh.add(g_rh), alpha);
            zc = zc.add(mu[4 * b].mul(c_had)).add(mu[4 * b + 1].mul(c_hg)).add(mu[4 * b + 2].mul(c_hu)).add(mu[4 * b + 3].mul(c_hh));
            let nu_b = nu0.mul(lam_f[b]);
            f1 = f1.add(nu_b.mul(g8.mul_base(p_g).add(rg))).add(nu_b.mul(lam_gu).mul(u16.mul_base(p_u).add(ru)));
        }
        let sel = Fp2::ONE.sub(e_f);
        let want = sel.mul(eq_point(&tau, &rho_f).mul(zc).add(eq_point(&p1, &rho_f).mul(f1)));
        div(fin.sub(want), c_f)?
    };
    tr.absorb_fp2(b"zcF-term", &proof.zc20_term);

    // ---- zero-check D ----
    let tau2 = tr.challenge_fp2_vec((lay.log_t + lay.log_db) as usize);
    let mu2 = tr.challenge_fp2_vec(nb_d);
    let nu_z = tr.challenge_fp2();
    let c_dz = tr.challenge_fp2();
    tr.absorb_fp2(b"gammaD", &[proof.gamma17]);
    let claimed = nu_z.mul(proof.d_claim).add(proof.gamma17);
    let nvd = (lay.log_t + lay.log_db) as usize;
    let (fin, rho_de) = sumcheck::verify(claimed, 4, nvd + 1, &proof.zc17_sc, tr)?;
    let rho_d = rho_de[..nvd].to_vec();
    let e_dz = rho_de[nvd];
    if proof.zc17_term.len() != 4 * nb_d { return Err("zcD terminal".into()); }
    let g_dz_val = {
        let v = &proof.zc17_term;
        let mut zc = Fp2::ZERO;
        let mut fz = Fp2::ZERO;
        for c in 0..nb_d {
            let (z, rd, h) = (v[nb_d + c], v[2 * nb_d + c], v[3 * nb_d + c]);
            zc = zc.add(mu2[c].mul(helper_constraint(h, z.add(g_i16), rd.add(g_rd), alpha)));
            fz = fz.add(nu_z.mul(lam_d[c]).mul(z.mul_base(p_z).add(rd)));
        }
        let sel = Fp2::ONE.sub(e_dz);
        let want = sel.mul(eq_point(&tau2, &rho_d).mul(zc).add(eq_point(&p4, &rho_d).mul(fz)));
        div(fin.sub(want), c_dz)?
    };
    tr.absorb_fp2(b"zcD-term", &proof.zc17_term);

    // ---- the table-side zero-check ----
    let tau3 = tr.challenge_fp2_vec(log_s);
    let mu3 = tr.challenge_fp2_vec(zl.tabs.len());
    let c_tab = tr.challenge_fp2();
    tr.absorb_fp2(b"gamma-tab", &[proof.gamma_tab]);
    let (fin, rho_tabe) = sumcheck::verify(proof.gamma_tab, 3, log_s + 1, &proof.tab_sc, tr)?;
    let rho_tab = rho_tabe[..log_s].to_vec();
    if mr1 { fresh_poc::check_table_point(&zl, &rho_tab)?; }
    let e_tab = rho_tabe[log_s];
    if proof.tab_term.len() != 2 * zl.tabs.len() { return Err("tab terminal".into()); }
    let g_tab_val = {
        let eq = eq_table_msb(&rho_tab);
        let sel = Fp2::ONE.sub(e_tab);
        let mut acc = Fp2::ZERO;
        for (i, t) in zl.tabs.iter().enumerate() {
            let tv = tval_v3(t.tag, t.size, &st.table, beta, gamma);
            let tv_at = tv.par_iter().zip(eq[..t.size].par_iter()).map(|(x, e)| x.mul(*e)).reduce(|| Fp2::ZERO, |a, b| a.add(b));
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

    // ---- [UPERF3-AN] FUNCTION 2: the predicate sumcheck ----
    // The claimed sum is the PUBLIC threshold tau; the three public tables
    // (the entry selector, the 2^i weights, the booleanity eq) are evaluated at
    // rho by the verifier and carry the extension round's (1 - e) selector, and
    // the two private terminals arrive masked.
    let mut pred_ctx: Option<(Vec<Fp2>, Fp2, Fp2, Fp2)> = None;
    if let Some(p) = pred {
        let pp = proof.pred.as_ref().ok_or("function 2: no predicate gadget in the proof")?;
        if pp.term.len() != 2 { return Err("pred terminal".into()); }
        let nv = (lay.log_t + lay.log_db) as usize;
        let db = 1usize << lay.log_db;
        let pt_pred = bool_point(p.row * db + (p.col % db), nv);
        let tau_p = tr.challenge_fp2_vec(nv);
        let nu_p = tr.challenge_fp2();
        let c_pred = tr.challenge_fp2();
        tr.absorb_fp2(b"gamma-pred", &[pp.gamma]);
        let claim = Fp2::from_i64(p.tau).add(pp.gamma);
        let (fin, rho_pe) = sumcheck::verify(claim, 3, nv + 1, &pp.sc, tr)?;
        let rho_p = rho_pe[..nv].to_vec();
        let e_p = rho_pe[nv];
        let sel = Fp2::ONE.sub(e_p);
        let (zt, bt) = (pp.term[0], pp.term[1]);
        let want = sel.mul(eq_point(&pt_pred, &rho_p)).mul(zt)
            .sub(sel.mul(pred_weight_at(&rho_p)).mul(bt))
            .add(nu_p.mul(sel.mul(eq_point(&tau_p, &rho_p))).mul(bt.mul(bt).sub(bt)));
        let g_pred_val = div(fin.sub(want), c_pred)?;
        tr.absorb_fp2(b"pred-term", &pp.term);
        pred_ctx = Some((rho_p, e_p, c_pred, g_pred_val));
    }

    // ---- the mask opening ----
    let mut fs = mask_functionals(&specs, [&rho_gu, &rho_dm, &rho_fe, &rho_de, &rho_zse, &rho_tabe], [g_gu_val, g_d_val, g_f_val, g_dz_val, g_zs_val, g_tab_val], [c_gu, c_d, c_f, c_dz, c_zs, c_tab], nu0, nu_z, [proof.gamma20, proof.gamma17, proof.gamma_zs, proof.gamma_tab]);
    if let Some((rho_p, e_p, c_pred, g_pred_val)) = &pred_ctx {
        let mut rho_pe = rho_p.clone();
        rho_pe.push(*e_p);
        push_pred_functionals(&mut fs, &specs, &rho_pe, *g_pred_val, *c_pred, proof.pred.as_ref().unwrap().gamma);
    }

    // ---- PCS openings ----
    let pred_claims = pred.zip(pred_ctx.as_ref()).map(|(p, (rho_p, e_p, _, _))| (p, rho_p.as_slice(), *e_p));
    let (wc, mut ac, hc) = build_claims_zk_v3(&zl, proof, &p2, &p5, &rho_f, &rho_d, &rho_zs, &rho_tab, (cd_gu, cm_gu), (cd_d, cm_d), e_f, e_dz, e_zs, e_tab, &p3, &p6, pred_claims);
    before_openings(&zl, &mut ac, &mut fs, tr)?;
    #[cfg(test)]
    if io { mask_diagnostic::io::mask_before(&proof.mask_root, &specs, &fs, &proof.mask_open, tr); }
    mask_verify(&proof.mask_root, &specs, &fs, &proof.mask_open, ntt, tr).map_err(|e| format!("M: {e}"))?;
    #[cfg(test)]
    if io { mask_diagnostic::io::mask_after(tr); }
    #[cfg(test)]
    let mut diagnostic_w = None;
    if is_p3 {
        let wcz = build_w_zclaims_v3(&zl, proof, &p3, &p6, (cd_w_gu, e_gu2), (cd_w_d, e_d2));
        #[cfg(test)]
        { diagnostic_w = if io { mask_diagnostic::io::capture(mask_diagnostic::Role::W, &w_pcs, w_com, &wcz, &proof.w_open_zk, tr) }
            else { mask_diagnostic::capture(mask_diagnostic::Role::W, &w_pcs, w_com, &wcz, &proof.w_open_zk, tr) }; }
        if mr1 { fresh_poc::check_masks(&wcz, w_com.rows, zl.log_wn, &zl.w_mask_rows(), zl.w_prox, tr)?; }
        pcs::verify_zk(&w_pcs, &ZkOpts::standard(&w_pcs), w_com, &wcz, &proof.w_open_zk, ntt, tr).map_err(|e| format!("W: {e}"))?;
        #[cfg(test)]
        mask_diagnostic::finish(&mut diagnostic_w, tr);
    } else {
        #[cfg(test)]
        let before = Transcript::clone_state(tr);
        pcs::verify(&w_pcs, w_com, &wc, &proof.w_open, ntt, tr).map_err(|e| format!("W: {e}"))?;
        #[cfg(test)]
        if io { mask_diagnostic::io::public_w(&w_pcs, w_com, &wc, &proof.w_open, &before, tr); }
    }
    // IO has a separate capture contract; do not publish it as legacy/fresh function 1.
    // Test-only public observation: publish only after the complete FFN accepts.
    #[cfg(test)]
    let mut diagnostic_a = if io { mask_diagnostic::io::capture(mask_diagnostic::Role::A, &a_pcs, a_com, &ac, &proof.a_open, tr) }
        else { mask_diagnostic::capture(mask_diagnostic::Role::A, &a_pcs, a_com, &ac, &proof.a_open, tr) };
    if mr1 { fresh_poc::check_masks(&ac, a_com.rows, log_n, &zl.a_mask_rows(), zl.a_prox, tr)?; }
    pcs::verify_zk(&a_pcs, &ZkOpts::standard(&a_pcs), a_com, &ac, &proof.a_open, ntt, tr).map_err(|e| format!("A: {e}"))?;
    #[cfg(test)]
    mask_diagnostic::finish(&mut diagnostic_a, tr);
    #[cfg(test)]
    let mut diagnostic_h = if io { mask_diagnostic::io::capture(mask_diagnostic::Role::H, &h_pcs, h_com, &hc, &proof.h_open, tr) }
        else { mask_diagnostic::capture(mask_diagnostic::Role::H, &h_pcs, h_com, &hc, &proof.h_open, tr) };
    if mr1 { fresh_poc::check_masks(&hc, h_com.rows, log_n, &zl.h_mask_rows(), zl.h_prox, tr)?; }
    pcs::verify_zk(&h_pcs, &ZkOpts::standard(&h_pcs), h_com, &hc, &proof.h_open, ntt, tr).map_err(|e| format!("H: {e}"))?;
    #[cfg(test)]
    mask_diagnostic::finish(&mut diagnostic_h, tr);
    #[cfg(test)]
    if io {
        // Held privately by the test observer until both endpoint openings accept.
        mask_diagnostic::io::record("W", diagnostic_w);
        mask_diagnostic::io::record("A", diagnostic_a);
        mask_diagnostic::io::record("H", diagnostic_h);
    } else { mask_diagnostic::publish(diagnostic_w, diagnostic_a, diagnostic_h); }
    Ok(())
}

#[cfg(test)]
#[path = "zk_ffn_mask_diagnostic.rs"]
mod mask_diagnostic;

#[cfg(test)]
mod tests_v3 {
    use super::*;
    use crate::export_v3::{clone_witness_v3, derive_v3, V3Dims, V3Exps, V3LayerExport};
    use crate::layer::{apply_tamper_v3, TamperV3};
    use crate::tables_v3::{int16out_member, Act16Fn};

    /// A synthetic v3 layer (T 2, d 16, f 16; int8 X, small int8 weights; the frozen member (-3, -11);
    /// shifts (7, 0, 14, 6)) derived through the exact widened chain — every range fact holds.
    fn synth(seed: u64) -> V3Witness {
        let (t, d, f) = (2usize, 16usize, 16usize);
        let mut s = seed;
        let mut nx = |m: i64| -> i8 {
            s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            (((s >> 33) as i64) % (2 * m + 1) - m) as i8
        };
        let x: Vec<i8> = (0..t * d).map(|_| nx(127)).collect();
        let wg_t: Vec<i8> = (0..d * f).map(|_| nx(4)).collect();
        let wu_t: Vec<i8> = (0..d * f).map(|_| nx(4)).collect();
        let wd_t: Vec<i8> = (0..f * d).map(|_| nx(4)).collect();
        let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
        let exps = V3Exps { e_x: 0, e_g: -3, e_a16: -11, e_u16: 0, e_h16: 0, e_z16: 0, e_wg: 0, e_wu: 0, e_wd: 0 };
        let ex = V3LayerExport {
            l: 0, dims: V3Dims { t, d, f, layers: 1 }, x, wg_t, wu_t, wd_t, a16: vec![], u16: vec![], h16: vec![], z16: vec![],
            exps, shifts: (7, 0, 14, 6), act: Act16Fn::Silu, table, table_digest, digest_checks: vec![],
        };
        let w = derive_v3(&ex, t);
        assert!(w.range_ok, "the synthetic witness fails a range fact");
        w
    }

    fn stmt(w: &V3Witness) -> StatementV3 {
        StatementV3 { l: w.l, t_rows: w.t_rows, d: w.dims.d, f: w.dims.f, shifts: w.shifts, act: w.act, table: w.table, table_digest: w.table_digest.clone() }
    }

    #[test]
    #[cfg(unix)]
    fn fresh_os_proofs_verify_for_both_privacy_modes_with_reused_config() {
        let params = LayerParams { log_cols: 5, inv_rate: 4, num_col_checks: 12 };
        let ntt = NttTables::new(16);
        let w = synth(1);
        let st = stmt(&w);
        for privacy in [ZkPrivacy::P1, ZkPrivacy::P3] {
            let cfg = ZkConfig { enabled: true, mode: ZkStatementMode { privacy, ..Default::default() }, ..Default::default() };
            let mut proofs = Vec::new();
            for _ in 0..2 {
                let out = prove_layer_zk_v3(&w, 2, &params, &ntt, &cfg.clone(), &mut Transcript::new(b"fresh-os-test"));
                verify_layer_zk_v3(&st, &out.proof, &params, &ntt, &mut Transcript::new(b"fresh-os-test"), &cfg.mode).unwrap();
                let sizes = out.proof.size_breakdown().unwrap();
                assert_eq!(sizes.total_bytes(), out.proof.to_bytes().len());
                if privacy == ZkPrivacy::P1 {
                    assert!(sizes.w_plain.total_bytes() > 0);
                    assert_eq!(sizes.w_plain.columns.salts, 0);
                    assert_eq!(sizes.w_hiding.total_bytes(), 0);
                } else {
                    assert_eq!(sizes.w_plain.total_bytes(), 0);
                    assert!(sizes.w_hiding.columns.salts > 0);
                }
                proofs.push(out.proof);
            }
            assert_ne!(proofs[0].to_bytes(), proofs[1].to_bytes());
            assert_eq!(proofs[0].size_breakdown(), proofs[1].size_breakdown(), "fresh values changed size-only telemetry");
            assert_ne!(proofs[0].a_com.as_ref().unwrap().root, proofs[1].a_com.as_ref().unwrap().root);
            if privacy == ZkPrivacy::P3 {
                assert_ne!(proofs[0].w_com.as_ref().unwrap().root, proofs[1].w_com.as_ref().unwrap().root);
            }
        }
    }

    fn chi2_top_byte(vals: &[u64]) -> f64 {
        let mut bins = [0f64; 256];
        for v in vals { bins[(v >> 56) as usize] += 1.0; }
        let e = vals.len() as f64 / 256.0;
        bins.iter().map(|b| (b - e) * (b - e) / e).sum()
    }

    /// The v3 ZK layer end to end at a tiny shape: honest accept; five tamper legs reject; and THE
    /// UNIFORMITY TEST over the v3 opening sites — every opened column entry of A and H (the planes,
    /// the multi-row INT16 class and window slots, the helpers, the masks) and every clear-vector entry
    /// is a fresh field element: distinct across two witnesses and several seeds, none in the witness
    /// range, chi-square of the top byte against uniform at 256 bins; the mask-site assertion ran at
    /// every group (enumerated). The contrast (ZB's non-zk v3 opening reveals raw int16 values at its
    /// systematic columns) is the non-zk path itself.
    /// [UPERF3-AM] MODE P3 (the FULL tier): the weight commitment is hiding and per-proof.
    /// Three things are asserted: (1) it round-trips and every tamper leg still rejects;
    /// (2) NO opened value of W lies in the witness range and no two openings repeat — the
    /// int8 weights are gone from the proof, which under P1 they are not; (3) THE HEADER
    /// BINDS THE CLAIM: a P1 proof checked as P3, or a P3 proof checked as P1, is rejected,
    /// so no proof can be presented as claiming more privacy than it delivers.
    #[test]
    fn zk_v3_p3_hides_the_weights_and_the_header_binds_the_claim() {
        let params = LayerParams { log_cols: 5, inv_rate: 4, num_col_checks: 12 };
        let ntt = NttTables::new(16);
        let w = synth(1);
        let st = stmt(&w);
        let p1 = ZkConfig { enabled: true, seed: Some(1), ..Default::default() };
        let p3 = ZkConfig { enabled: true, seed: Some(1), mode: ZkStatementMode { privacy: ZkPrivacy::P3, ..Default::default() } };
        let mut tr = Transcript::new(b"t");
        let out = prove_layer_zk_v3(&w, 2, &params, &ntt, &p3, &mut tr);
        let mut tv = Transcript::new(b"t");
        verify_layer_zk_v3(&st, &out.proof, &params, &ntt, &mut tv, &p3.mode).unwrap();
        assert!(out.sites.iter().any(|s| s.starts_with("W masks (P3)")), "no W mask site reported");
        assert!(out.sites.iter().any(|s| s.starts_with("W group vector")), "no W opening group reported");

        // (2) nothing of W in the clear: every opened W column entry and clear-vector entry is
        // a fresh field element far from the witness range, across seeds and witnesses.
        let w2 = synth(2);
        let mut all: Vec<u64> = Vec::new();
        for seed in 0..3u64 {
            for (wi, wit) in [&w, &w2].iter().enumerate() {
                let cfg = ZkConfig { enabled: true, seed: Some(200 + seed + 100 * wi as u64), mode: p3.mode.clone() };
                let mut tr = Transcript::new(b"t");
                let o = prove_layer_zk_v3(wit, 2, &params, &ntt, &cfg, &mut tr);
                let op = &o.proof.w_open_zk;
                assert!(o.proof.w_open.group_vecs.is_empty() && o.proof.w_open.columns.is_empty(), "P3 wrote a plain W opening");
                let mut seen = std::collections::HashSet::new();
                for (j, col, _, _) in &op.columns { if seen.insert(*j) { all.extend(col.iter().map(|x| x.0)); } }
                for v in op.group_vecs.iter().chain(std::iter::once(&op.prox_vec)) { all.extend(v.iter().flat_map(|x| [x.c0.0, x.c1.0])); }
            }
        }
        let total = all.len();
        assert!(total > 1000, "only {total} opened W values");
        all.sort_unstable();
        all.dedup();
        assert_eq!(all.len(), total, "a repeated opened W value");
        assert!(all.iter().all(|&v| v > 1u64 << 40 && v < crate::field::P - (1u64 << 40)), "an opened W value in the witness range");

        // (3) the header binds the claim, in both directions
        let mut tv = Transcript::new(b"t");
        assert!(verify_layer_zk_v3(&st, &out.proof, &params, &ntt, &mut tv, &p1.mode).is_err(), "a P3 proof verified as P1");
        let mut tr = Transcript::new(b"t");
        let out1 = prove_layer_zk_v3(&w, 2, &params, &ntt, &p1, &mut tr);
        let mut tv = Transcript::new(b"t");
        assert!(verify_layer_zk_v3(&st, &out1.proof, &params, &ntt, &mut tv, &p3.mode).is_err(), "a P1 proof verified as P3");
        // ... and so does the OUTPUT-CLAIM slot: a function-1 proof is not a function-2 proof
        let f2 = ZkStatementMode { output: OutputClaim::BinaryAcceptable, ..Default::default() };
        assert_ne!(p1.mode.header_v3(), f2.header_v3());
        let mut tv = Transcript::new(b"t");
        assert!(verify_layer_zk_v3(&st, &out1.proof, &params, &ntt, &mut tv, &f2).is_err(), "a function-1 proof verified as function-2");
        assert_eq!(p1.mode.header_v3(), b"P1-v3".to_vec(), "the frozen P1 tag moved");

        // (1) the tamper legs, under P3
        for tm in [TamperV3::FlipX(3), TamperV3::FlipW(5), TamperV3::RemainderOutOfRange(9), TamperV3::WrongTableEntry(5), TamperV3::WrongRequant(7), TamperV3::WrongZ(4), TamperV3::OutOfRangeInt16(2)] {
            let mut wt = clone_witness_v3(&w);
            apply_tamper_v3(&mut wt, tm);
            let mut tr = Transcript::new(b"t");
            let o = prove_layer_zk_v3(&wt, 2, &params, &ntt, &p3, &mut tr);
            let mut tv = Transcript::new(b"t");
            assert!(verify_layer_zk_v3(&st, &o.proof, &params, &ntt, &mut tv, &p3.mode).is_err(), "P3 accepted {tm:?}");
        }
    }

    /// [UPERF3-AN] FUNCTION 2, THE ZK CONTENT FILTER (PROOF_FUNCTIONS.md section 5's
    /// simplest form: binary output, ONE non-negativity fact, the acceptable set
    /// frozen per deployment, the output committed because it already is).
    ///
    /// Seven things are asserted:
    ///  (1) an ACCEPTABLE classification proves and verifies;
    ///  (2) an UNACCEPTABLE one does NOT — the filter is enforced by the soundness
    ///      of the proof system, not by a policy layer (section 1's "enforcement");
    ///  (3) THE TWO FUNCTIONS ARE NOT INTERCHANGEABLE, in BOTH directions: a
    ///      function-1 proof does not verify as function 2, and a function-2 proof
    ///      does not verify as function 1;
    ///  (4) THE PREDICATE IS PART OF THE STATEMENT'S IDENTITY: the same proof under
    ///      a different threshold, a different column or a different row is
    ///      rejected, and the predicate id sits in the same header, under the same
    ///      transcript, as the model identity digest — changing EITHER rejects;
    ///  (5) the range fact is real: every tamper leg still rejects with the
    ///      predicate on;
    ///  (6) nothing of the output or of the bit planes is in the clear — the two
    ///      terminals are masked (fresh across seeds for one and the same
    ///      statement, and never equal to the score, the threshold or the slack);
    ///  (7) BYTE-PRESERVING: a function-1 proof of the same witness is byte for
    ///      byte the proof it was before this lane existed (the layout, the mask
    ///      spec list and the serialization all grow only under function 2).
    #[test]
    fn zk_v3_function2_binary_predicate_is_a_separate_statement() {
        let params = LayerParams { log_cols: 5, inv_rate: 4, num_col_checks: 12 };
        let ntt = NttTables::new(16);
        let w = synth(1);
        let st = stmt(&w);
        let d = w.dims.d;
        let (prow, pcol) = (1usize, 3usize);
        let score = w.z16[prow * d + pcol] as i64;
        let f2mode = |row: usize, col: usize, tau: i64| ZkStatementMode {
            output: OutputClaim::BinaryAcceptable,
            pred: Some(PredicateSpec { row, col, tau }),
            ..Default::default()
        };
        let acc = f2mode(prow, pcol, score - 7); // slack 7 >= 0: ACCEPTABLE
        let cfg2 = ZkConfig { enabled: true, seed: Some(1), mode: acc.clone() };
        let p1 = ZkConfig { enabled: true, seed: Some(1), ..Default::default() };

        // (1) an acceptable classification proves and verifies
        let mut tr = Transcript::new(b"t");
        let out2 = prove_layer_zk_v3(&w, 2, &params, &ntt, &cfg2, &mut tr);
        let mut tv = Transcript::new(b"t");
        verify_layer_zk_v3(&st, &out2.proof, &params, &ntt, &mut tv, &acc).expect("function 2 did not verify");
        assert!(out2.proof.pred.is_some(), "no predicate gadget in the function-2 proof");
        assert!(out2.sites.iter().any(|s| s.starts_with("predicate (function 2)")), "no predicate site reported");

        // (2) an UNACCEPTABLE classification cannot be given a passing proof
        let rej = f2mode(prow, pcol, score + 1); // slack -1
        let cfgr = ZkConfig { enabled: true, seed: Some(1), mode: rej.clone() };
        let mut tr = Transcript::new(b"t");
        let outr = prove_layer_zk_v3(&w, 2, &params, &ntt, &cfgr, &mut tr);
        let mut tv = Transcript::new(b"t");
        assert!(verify_layer_zk_v3(&st, &outr.proof, &params, &ntt, &mut tv, &rej).is_err(), "an UNACCEPTABLE classification produced a verifying function-2 proof");

        // (3) the two functions are not interchangeable, in BOTH directions
        let mut tr = Transcript::new(b"t");
        let out1 = prove_layer_zk_v3(&w, 2, &params, &ntt, &p1, &mut tr);
        let mut tv = Transcript::new(b"t");
        assert!(verify_layer_zk_v3(&st, &out1.proof, &params, &ntt, &mut tv, &acc).is_err(), "a function-1 proof verified as function-2");
        let mut tv = Transcript::new(b"t");
        assert!(verify_layer_zk_v3(&st, &out2.proof, &params, &ntt, &mut tv, &p1.mode).is_err(), "a function-2 proof verified as function-1");

        // (4) the predicate, and the model identity beside it, are the statement's identity
        for other in [f2mode(prow, pcol, score - 6), f2mode(prow, pcol, score - 8), f2mode(prow, (pcol + 1) % d, score - 7), f2mode(1 - prow, pcol, score - 7)] {
            assert_ne!(acc.header_v3(), other.header_v3(), "two different predicates share a header");
            let mut tv = Transcript::new(b"t");
            assert!(verify_layer_zk_v3(&st, &out2.proof, &params, &ntt, &mut tv, &other).is_err(), "a function-2 proof verified under a DIFFERENT predicate {:?}", other.pred);
        }
        let named = ZkStatementMode { model_id: Some("filter-model-abc".into()), ..acc.clone() };
        assert_ne!(acc.header_v3(), named.header_v3(), "the model identity left the predicate's header");
        let mut tv = Transcript::new(b"t");
        assert!(verify_layer_zk_v3(&st, &out2.proof, &params, &ntt, &mut tv, &named).is_err(), "a function-2 proof verified under a different model identity");
        // ... and a function-2 claim with no parameters names no predicate at all
        let bare = ZkStatementMode { output: OutputClaim::BinaryAcceptable, ..Default::default() };
        assert!(bare.predicate().is_err(), "a bare function-2 claim was accepted");
        let mut tv = Transcript::new(b"t");
        assert!(verify_layer_zk_v3(&st, &out2.proof, &params, &ntt, &mut tv, &bare).is_err(), "a bare function-2 claim verified");

        // (5) the layer's own facts still hold with the predicate on
        for tm in [TamperV3::FlipX(3), TamperV3::FlipW(5), TamperV3::RemainderOutOfRange(9), TamperV3::WrongTableEntry(5), TamperV3::WrongRequant(7), TamperV3::WrongZ(4), TamperV3::OutOfRangeInt16(2)] {
            let mut wt = clone_witness_v3(&w);
            apply_tamper_v3(&mut wt, tm);
            let mut tr = Transcript::new(b"t");
            let o = prove_layer_zk_v3(&wt, 2, &params, &ntt, &cfg2, &mut tr);
            let mut tv = Transcript::new(b"t");
            assert!(verify_layer_zk_v3(&st, &o.proof, &params, &ntt, &mut tv, &acc).is_err(), "function 2 accepted {tm:?}");
        }

        // (5b) THE TWO FACTS THE GADGET RESTS ON, ATTACKED DIRECTLY. The honest bit
        // row is replaced with a cheating one and the proof must still fail:
        //   - NON-BOOLEAN: put the whole slack in column 0 (whose public weight is
        //     2^0 = 1), so the recomposition is right and only booleanity is wrong;
        //   - OUT OF THE WINDOW: put the honest bits in columns 16.., whose public
        //     weight is ZERO, so booleanity is right and only the recomposition is
        //     wrong. This is what makes a negative slack unprovable.
        let slack = score - acc.pred.as_ref().unwrap().tau;
        for (what, cells) in [
            ("a NON-BOOLEAN bit plane", vec![(0usize, slack)]),
            ("bits outside the 16 weighted columns", (0..PRED_BITS).map(|i| (PRED_BITS + i, (slack >> i) & 1)).collect::<Vec<_>>()),
            ("every plane set, recomposing to nothing", (0..PRED_BITS).map(|i| (i, 1i64)).collect::<Vec<_>>()),
        ] {
            PRED_BIT_TAMPER.with(|t| *t.borrow_mut() = Some(cells));
            let mut tr = Transcript::new(b"t");
            let o = prove_layer_zk_v3(&w, 2, &params, &ntt, &cfg2, &mut tr);
            PRED_BIT_TAMPER.with(|t| *t.borrow_mut() = None);
            let mut tv = Transcript::new(b"t");
            assert!(verify_layer_zk_v3(&st, &o.proof, &params, &ntt, &mut tv, &acc).is_err(), "function 2 accepted {what}");
        }

        // (6) the score, the threshold and the slack are nowhere in the clear
        let leaks = [score, acc.pred.as_ref().unwrap().tau, 7i64];
        let mut terms: Vec<[u64; 4]> = Vec::new();
        for seed in 1..5u64 {
            let cfg = ZkConfig { enabled: true, seed: Some(seed), mode: acc.clone() };
            let mut tr = Transcript::new(b"t");
            let o = prove_layer_zk_v3(&w, 2, &params, &ntt, &cfg, &mut tr);
            let t = o.proof.pred.as_ref().unwrap().term.clone();
            for v in &t {
                for l in leaks {
                    assert_ne!(*v, Fp2::from_i64(l), "a predicate terminal IS a witness value");
                }
                assert!(v.c0.0 > 1u64 << 40 && v.c0.0 < crate::field::P - (1u64 << 40), "a predicate terminal is in the witness range");
            }
            terms.push([t[0].c0.0, t[0].c1.0, t[1].c0.0, t[1].c1.0]);
        }
        let mut flat: Vec<u64> = terms.iter().flatten().copied().collect();
        let total = flat.len();
        flat.sort_unstable();
        flat.dedup();
        assert_eq!(flat.len(), total, "a predicate terminal repeated across seeds: it is not masked");

        // (7) byte-preserving: the function-1 proof of the same witness is untouched
        let mut tr = Transcript::new(b"t");
        let out1b = prove_layer_zk_v3(&w, 2, &params, &ntt, &p1, &mut tr);
        assert_eq!(out1.proof.to_bytes(), out1b.proof.to_bytes(), "function 1 is no longer deterministic");
        assert!(out1.proof.pred.is_none(), "a function-1 proof carries a predicate gadget");
        assert_eq!(out1.proof.to_bytes().len(), out1.proof.size_bytes(), "function-1 size accounting moved");
        assert!(out2.proof.size_bytes() > out1.proof.size_bytes(), "the predicate costs no bytes at all?");
        let sizes = out2.proof.size_breakdown().unwrap();
        let mut predicate_bytes = Vec::new();
        out2.proof.pred.as_ref().unwrap().write_bytes(&mut predicate_bytes);
        assert_eq!(sizes.predicate.unwrap().total_bytes(), predicate_bytes.len());
        assert_eq!(sizes.total_bytes(), out2.proof.to_bytes().len());
        println!(
            "[UPERF3-AN] function 1 {} B; function 2 {} B (+{} B, +{:.4}%); predicate sumcheck {} rounds",
            out1.proof.size_bytes(),
            out2.proof.size_bytes(),
            out2.proof.size_bytes() - out1.proof.size_bytes(),
            100.0 * (out2.proof.size_bytes() as f64 / out1.proof.size_bytes() as f64 - 1.0),
            out2.proof.pred.as_ref().unwrap().sc.rounds.len()
        );
    }

    #[test]
    fn zk_v3_layer_roundtrip_tampers_and_uniform_openings() {
        let params = LayerParams { log_cols: 5, inv_rate: 4, num_col_checks: 12 };
        let ntt = NttTables::new(16);
        let w = synth(1);
        let st = stmt(&w);
        let cfg = ZkConfig { enabled: true, seed: Some(1), ..Default::default() };
        let mut tr = Transcript::new(b"t");
        let out = prove_layer_zk_v3(&w, 2, &params, &ntt, &cfg, &mut tr);
        let mut tv = Transcript::new(b"t");
        verify_layer_zk_v3(&st, &out.proof, &params, &ntt, &mut tv, &cfg.mode).unwrap();
        println!("v3 zk sites:");
        for s in &out.sites { if s.len() > 160 { println!("  {}... ({} chars)", &s[..160], s.len()); } else { println!("  {s}"); } }
        let a_groups = out.sites.iter().filter(|s| s.starts_with("A group vector")).count();
        let h_groups = out.sites.iter().filter(|s| s.starts_with("H group vector")).count();
        assert!(a_groups >= 5 && h_groups >= 4, "sites: A {a_groups} H {h_groups}");
        // a second seed proves the same statement with different bytes
        let mut tr = Transcript::new(b"t");
        let out_b = prove_layer_zk_v3(&w, 2, &params, &ntt, &ZkConfig { enabled: true, seed: Some(2), ..Default::default() }, &mut tr);
        assert_ne!(out.proof.to_bytes(), out_b.proof.to_bytes());
        let mut tv = Transcript::new(b"t");
        verify_layer_zk_v3(&st, &out_b.proof, &params, &ntt, &mut tv, &cfg.mode).unwrap();
        // tamper legs (the wrong-rounding leg needs a round-up element; the driver's 3x16 run covers it)
        for tm in [TamperV3::FlipX(3), TamperV3::FlipW(5), TamperV3::RemainderOutOfRange(9), TamperV3::WrongTableEntry(5), TamperV3::WrongRequant(7), TamperV3::WrongZ(4), TamperV3::OutOfRangeInt16(2)] {
            let mut w2 = clone_witness_v3(&w);
            apply_tamper_v3(&mut w2, tm);
            let mut tr = Transcript::new(b"t");
            let out2 = prove_layer_zk_v3(&w2, 2, &params, &ntt, &cfg, &mut tr);
            let mut tv = Transcript::new(b"t");
            let r = verify_layer_zk_v3(&st, &out2.proof, &params, &ntt, &mut tv, &cfg.mode);
            assert!(r.is_err(), "{tm:?} was accepted");
            println!("  tamper {tm:?}: REJECT ({})", r.err().unwrap());
        }
        // the uniformity statistic over the v3 sites
        let w2 = synth(2);
        let mut cols_a: Vec<u64> = Vec::new();
        let mut cols_b: Vec<u64> = Vec::new();
        let mut vecs: Vec<u64> = Vec::new();
        for seed in 0..4u64 {
            for (wi, wit) in [&w, &w2].iter().enumerate() {
                let mut tr = Transcript::new(b"t");
                // disjoint seeds per witness: under ONE seed the mask rows, pads and salts are the same for both
                // witnesses and every row equal between them (masks, zero rows) would open to equal values
                let o = prove_layer_zk_v3(wit, 2, &params, &ntt, &ZkConfig { enabled: true, seed: Some(100 + seed + 100 * wi as u64), ..Default::default() }, &mut tr);
                let cols = if wi == 0 { &mut cols_a } else { &mut cols_b };
                for op in [&o.proof.a_open, &o.proof.h_open] {
                    let mut seen = std::collections::HashSet::new();
                    for (j, col, _, _) in &op.columns { if seen.insert(*j) { cols.extend(col.iter().map(|x| x.0)); } }
                    for v in op.group_vecs.iter().chain(std::iter::once(&op.prox_vec)) { vecs.extend(v.iter().flat_map(|x| [x.c0.0, x.c1.0])); }
                }
                let mut seen = std::collections::HashSet::new();
                for (j, col, _, _) in &o.proof.mask_open.columns { if seen.insert(*j) { cols.extend(col.iter().map(|x| x.0)); } }
            }
        }
        let mut all: Vec<u64> = cols_a.iter().chain(cols_b.iter()).chain(vecs.iter()).copied().collect();
        let total = all.len();
        all.sort_unstable();
        all.dedup();
        assert_eq!(all.len(), total, "repeated opened values");
        assert!(all.iter().all(|&v| v > 1u64 << 40 && v < crate::field::P - (1u64 << 40)), "an opened value in the witness range");
        for (name, v) in [("columns A", &cols_a), ("columns B", &cols_b), ("clear vectors", &vecs)] {
            let c = chi2_top_byte(v);
            println!("chi2 {name}: {c:.1} over {} values (df 255; 310.5 at p = 0.01)", v.len());
            assert!(c < 310.5, "{name}: chi2 {c} vs uniform");
        }
        let mut bins_a = [0f64; 256];
        let mut bins_b = [0f64; 256];
        for v in &cols_a { bins_a[(v >> 56) as usize] += 1.0; }
        for v in &cols_b { bins_b[(v >> 56) as usize] += 1.0; }
        let (na, nb) = (cols_a.len() as f64, cols_b.len() as f64);
        let mut c2 = 0.0;
        for i in 0..256 {
            let e = (bins_a[i] + bins_b[i]) / (na + nb);
            let (ea, eb) = (e * na, e * nb);
            if ea > 0.0 { c2 += (bins_a[i] - ea).powi(2) / ea + (bins_b[i] - eb).powi(2) / eb; }
        }
        println!("two-sample chi2 columns A vs B: {c2:.1} (df 255)");
        assert!(c2 < 310.5);
    }
}

/// Experimental fresh-commitment FFN mask repair, CPU proof of concept.
#[path = "zk_ffn_fresh_poc.rs"]
pub mod fresh_poc;

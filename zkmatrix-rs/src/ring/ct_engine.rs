// Route R ct-engine (U3): scalar claims over committed witnesses, proven
// without any small-coefficient scalar compression (design Section 2's
// finding 2 and Section 4 step 3; the LNP22 Pi_ct shape, ALS20 Section 4
// specialized to products).
//
// A scalar claim  <w, unpack(x)> = s  for public w over committed packed x
// is transported to the ring:  <w, x-coeffs> = ct( sum_u sigma_{-1}(w~_u)
// x_u )  where w~ is w packed chunk-wise and ct() is the centered constant
// coefficient. The engine proves a batch of such claims:
//
//   1. Prover commits masking elements g_l (ct(g_l) = 0, uniform
//      elsewhere) BEFORE the claim weights theta are drawn — enforced by
//      the hash order: theta = XOF(h0) where h0 binds every commitment
//      including com(g). ct(g) = 0 is a completeness property; soundness
//      needs only that g is FIXED before theta: for a nonzero defect,
//      <theta_l, defect> is uniform in Z_q, so a committed g matches it
//      with probability q^-1 per row, q^-l over l rows (l = ceil(256 /
//      log2 q) = 9 rows at q31 -> 2^-279).
//   2. Prover reveals h_l = g_l + f_l(witness), f_l the R-linear
//      ct-expression of claim l. Verifier checks ct(h_l) = s_l DIRECTLY
//      (deterministic — no scalar Schwartz-Zippel anywhere).
//   3. The ring-valued identity "h_l = g_l + f_l(witness)" rides one
//      masked Sigma round shared by every commitment in the batch:
//      per-commitment A1-side opening checks plus, per claim, a
//      message-side check against ONE prover-sent combined mask image W_l.
//      Extraction (two accepting transcripts, LS18-invertible challenge
//      difference) yields the identity EXACTLY over R_q — message-side
//      relations are mod-q algebra, no norm conditions. Per-slot soundness
//      2^-296-class per the design's Section 2 accounting.
//
// Message-side check, derived once (the code follows this exactly):
// for standard commitments com_i = (t1_i, t2_i) = (A1 rho_i, A2 rho_i +
// x_i), Ajtai commitments t_a = A1 rho_a + B_a s_a (s short, see below),
// challenge c, masks y_i / (yr_a, ys_a), responses z_i = y_i + c rho_i,
// zs_a = ys_a + c s_a:
//
//   c x_{ij}  = c t2_{ij} - (A2 z_i)_j + (A2 y_i)_j
//   c s_{au}  = zs_{au} - ys_{au}
//
// so with  f_l = sum a_{lij} x_{ij} + sum phi_{lau} s_{au}  and the mask
// element g_l sitting in message slot sl(l) of the g-commitment:
//
//   c h_l = c C_l - ZA_l + YA_l + ZS_l - YS_l,
//   C_l  := t2_{G,sl(l)} + sum a_{lij} t2_{ij}          (public combo)
//   ZA_l := (A2 z_G)_{sl(l)} + sum a_{lij} (A2 z_i)_j    (verifier)
//   ZS_l := sum phi_{lau} zs_{au}                        (verifier)
//   YA_l, YS_l: same over masks                          (prover)
//
// The prover sends W_l := YA_l - YS_l (one ring element per claim); the
// verifier checks  c h_l - c C_l + ZA_l - ZS_l = W_l.  Subtracting two
// accepting transcripts and dividing by the invertible challenge
// difference pins h_l = g_l + f_l(x*, s*) for the extracted openings.
//
// The Ajtai slot (ABDLOP-style, LNP22): witnesses that must be
// NORM-GROUNDED by the proof itself (the ARP masking vector below) are
// committed as t = A1 rho + B s with short s; the opening's response
// norm check bounds the extracted (relaxed) s. Plain BDLOP messages are
// mod-q values with no norm claim — that split is exactly LNP22's reason
// for ABDLOP, imported here for the approximate-range machinery only.
//
// Approximate range proof (ARP, JL projection): to ground "||b|| is small"
// side conditions (the binary gadget's non-wrap condition), reveal
// y = R b + m for an FS-derived sparse R in {0,+-1}^{rows x n} and a
// committed Gaussian mask m (Ajtai slot), rejection-sampled; range-check
// y; tie y to (b, m) with `rows` linear ct-claims. HONESTY NOTE (Q4): the
// extraction constant composing the JL lower bound with the relaxed-
// opening challenge slack is carried as an explicit parameter
// (`SLACK_OP`, conservative worst-case ||c-bar||_1 = 4D) pending the Q4
// lemma write-up; `arp_budget_ok` runs the derive-time budget check with
// these conservative constants and REJECTS shapes that do not close —
// callers fall back to exact per-chunk range strategies (the swappable
// range-strategy hook, design Section 5).

use sha2::{Digest, Sha256};

use super::aux::ring_mul_q_single;
use super::commit::{CommitShape, KernelPath, MatvecKind, RingCrs, a1_matvec, a2_matvec};
use super::{
    D, Poly, RingCtx, XofReader, ct_coeff, gaussian_ivec, poly_add, poly_conj, poly_from_small,
    poly_mul_small, poly_sub, poly_zero, polys_bytes, rejection_accept, ring_matvec_small_g,
    ring_mul_split_kara_fast, vec_norm_sq_i64,
};

// ---------------------------------------------------------------------------
// Claims and witnesses.

/// One linear ct-claim: ct( sum_(i,j) a_(i,j) x_(i,j) + sum_(a,u)
/// phi_(a,u) s_(a,u) + g_l ) = scalar, coefficients public ring elements.
pub struct CtClaim {
    /// (standard-commitment index, message slot, coefficient poly).
    pub msg_coeffs: Vec<(usize, usize, Poly)>,
    /// (Ajtai-commitment index, s slot, coefficient poly).
    pub ajtai_coeffs: Vec<(usize, usize, Poly)>,
    /// Claimed centered ct value.
    pub scalar: i64,
}

/// One RING-VALUED linear claim: sum_(i,j) a_(i,j) x_(i,j) = 0 over R_q
/// (all D coefficients — no ct projection, no g-mask, no reveal; W_rl is
/// simulatable from the verification equation, so nothing leaks). This is
/// the natural claim form for R-linear public maps (design Section 4
/// option (a): negacyclic-block A, shift/gadget matrices, convolutions,
/// block-selection). Per-slot soundness 2^-296 via the same two-transcript
/// extraction as the ct-claims.
pub struct RingClaim {
    pub msg_coeffs: Vec<(usize, usize, Poly)>,
}

// ---------------------------------------------------------------------------
// Quadratic claims (the ALS20/LNP22 product layer, U5/U6). Virtual
// openings V_i = c x_i split into the verifier-computable part
// P_i = c t2_i - (A2 z_i) = c x_i - Y_i and the prover's mask image
// Y_i = A2 y_i. Expanding products of P's isolates the claim at the top
// challenge monomial with prover-sent PRE-CHALLENGE garbage terms:
//
//   sigma-twisted (ct-quadratic, e.g. the binary gadget's
//   sum conj(x_u) x_u):
//     E := sum gamma sigma(P_a) P_b  (verifier)
//        = sigma(c) c Q - sigma(c) Ga - c Gb + G0,
//     Ga = sum gamma sigma(x_a) Y_b, Gb = sum gamma x_b sigma(Y_a),
//     G0 = sum gamma sigma(Y_a) Y_b;
//   check: sigma(c) c h = E + sigma(c) Ga + c Gb - G0
//                       + sigma(c) (c C_L - ZA_L + W_L)
//   with h = Q + L + g revealed, ct(h) = scalar checked directly.
//
//   untwisted (ring-valued quadratic, e.g. slot-packed Hadamard
//   x*y - z = 0):
//     E2 := sum gamma P_a P_b = c^2 Q - c G1 + G0;
//   check: E2 + c G1 - G0 + c (c C_L - ZA_L + W_L) = 0.
//
// Extraction is 3-special-sound (distinct challenges; Vandermonde-type
// clearing by products of LS18-invertible differences — the design's
// soundness item 1). ZK NOTE (Q4-class): the garbage terms are sent in
// clear and simulated as near-uniform (they are masked by the Gaussian
// mask images Y; the formal leftover-entropy lemma is part of the Q4
// write-up, same status as the concentration-bound lemma).

/// ct-projected quadratic claim with the sigma_{-1} twist on the left
/// factor: ct( sum_p gamma_p sigma(x_(ap)) x_(bp) + sum a x + g ) = scalar.
pub struct QuadCtClaim {
    /// (commit_a, slot_a, commit_b, slot_b, gamma).
    pub quad: Vec<(usize, usize, usize, usize, Poly)>,
    pub msg_coeffs: Vec<(usize, usize, Poly)>,
    pub scalar: i64,
}

/// Ring-valued quadratic claim (untwisted):
/// sum_p gamma_p x_(ap) x_(bp) + sum a x = 0 over R_q.
pub struct QuadRingClaim {
    pub quad: Vec<(usize, usize, usize, usize, Poly)>,
    pub msg_coeffs: Vec<(usize, usize, Poly)>,
}

/// Prover-side view of one standard commitment in the batch.
pub struct StdOpening<'a> {
    pub t1: &'a [Poly],
    pub t2: &'a [Poly],
    pub x: &'a [Poly],
    pub rho: &'a [Vec<i64>],
}

/// A COMBINED commitment (a challenge combination of column commitments —
/// Pi1/Pi2's transcription lift): its randomness rho_wide = sum_j v_j
/// rho_j has combination magnitude, so its opening inside the ct-round is
/// digit-decomposed (Q2): published digit statements T1_j with the public
/// recombination sum_j 2^(ej) T1_j = T1, per-digit Sigma equations sharing
/// the round's challenge, and 2^(ej)-weighted response sums on the
/// message side:
///   c x = c T2 - sum_j 2^(ej) (A2 z_j) + sum_j 2^(ej) (A2 y_j).
/// The verifier computes T1/T2 itself (combination sums of the public
/// column groups), so the digit statements bind to the statement.
pub struct DigitOpening<'a> {
    pub t1: &'a [Poly],
    pub t2: &'a [Poly],
    pub x: &'a [Poly],
    pub rho_wide: &'a [Vec<i64>],
}

/// Ajtai commitment t = A1 rho + B s (B: kappa x s_r, expanded from the
/// CRS hash; s short integer ring vectors).
pub struct AjtaiCommit {
    pub b_mat: Vec<Poly>, // kappa x s_r, row-major
    pub t: Vec<Poly>,     // kappa
}

pub struct AjtaiOpening<'a> {
    pub com: &'a AjtaiCommit,
    pub s: &'a [Vec<i64>],
    pub rho: &'a [Vec<i64>],
}

/// Expand the B matrix for an Ajtai slot from the CRS hash (public,
/// per-label).
pub fn expand_b_mat(crs: &RingCrs, label: &str, s_r: usize) -> Vec<Poly> {
    let mut reader = XofReader::new("ajtai-B", &[&crs.crs_hash, label.as_bytes()]);
    (0..crs.shape.kappa * s_r).map(|_| (0..D).map(|_| reader.next_field(crs.q)).collect()).collect()
}

pub fn ajtai_commit(crs: &RingCrs, b_mat: &[Poly], s: &[Vec<i64>], rho: &[Vec<i64>]) -> AjtaiCommit {
    let zq = super::Zq::new(crs.q);
    let s_r = s.len();
    let t1 = ring_matvec_small_g(&zq, &crs.a1, crs.shape.kappa, crs.shape.n_r, rho);
    let bs = ring_matvec_small_g(&zq, b_mat, crs.shape.kappa, s_r, s);
    let t = t1.iter().zip(bs.iter()).map(|(a, b)| poly_add(&zq, a, b)).collect();
    AjtaiCommit { b_mat: b_mat.to_vec(), t }
}

// ---------------------------------------------------------------------------
// Round parameters. The standard-commitment mask bundle follows the joint
// opening discipline (worst-case ||c||_1 = 2D operator norm over the
// (T + G) N_Z bundle); the Ajtai s-bundle gets its own sigma sized to its
// witness scale.

pub struct CtRoundParams {
    pub sigma: u64,       // std randomness masks
    pub bound_sq: u128,   // std response bundle l2^2
    /// Concentration restart rule on the std center bundle (0 = worst-case
    /// chain, no restart check).
    pub center_sq: u128,
    pub sigma_s: u64,     // Ajtai s masks
    pub bound_s_sq: u128, // Ajtai s response bundle l2^2
}

/// n_commits counts standard commitments INCLUDING the g-commitments and
/// Ajtai rho parts; s_z is the total Ajtai s coefficient count; s_inf the
/// honest |s|_inf scale. conc = true sizes the std bundle with the
/// concentration operator norm (1.3 sqrt(2D)) and a restart-if-exceeded
/// rule — required for batches beyond ~10 commitments at q31.
pub fn derive_ct_round_params(
    q: u64,
    shape: CommitShape,
    n_commits: usize,
    s_z: usize,
    s_inf: u64,
    conc: bool,
) -> CtRoundParams {
    let n_z = (shape.n_r * D) as f64;
    let bundle = n_commits as f64 * n_z;
    let op = if conc { 1.3 * (2.0 * D as f64).sqrt() } else { 2.0 * D as f64 };
    let t_bundle = op * bundle.sqrt();
    let sigma = (12.0 * t_bundle).ceil() as u64;
    let bound = 1.2 * sigma as f64 * bundle.sqrt();
    let bound_sq = (bound * bound).ceil() as u128;
    let center_sq = if conc { (t_bundle * t_bundle).ceil() as u128 } else { 0 };
    let beta = (2.0 * bound + op * bundle.sqrt()).ceil() as u128;
    assert!((q as u128) > 8 * beta, "C2 (ct round): q too small for the std bundle");
    let (sigma_s, bound_s_sq) = if s_z == 0 {
        (0, 0)
    } else {
        let t_s = op * s_inf as f64 * (s_z as f64).sqrt();
        let sigma_s = (12.0 * t_s).ceil() as u64;
        let bound_s = 1.2 * sigma_s as f64 * (s_z as f64).sqrt();
        let beta_s = (2.0 * bound_s).ceil() as u128;
        assert!((q as u128) > 8 * beta_s, "C2 (ct round): q too small for the s bundle");
        (sigma_s, (bound_s * bound_s).ceil() as u128)
    };
    CtRoundParams { sigma, bound_sq, center_sq, sigma_s, bound_s_sq }
}

/// The round's statement hash h0: binds crs, ctx, every standard
/// commitment (INCLUDING the g-commitments) and every Ajtai commitment.
/// theta / JL rows derive from this hash — the commit-before-challenge
/// ordering rule in one place.
pub fn ct_h0(
    crs: &RingCrs,
    ctx: &[u8],
    t1s: &[Vec<Poly>],
    t2s: &[Vec<Poly>],
    ajtai: &[&AjtaiCommit],
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"route-r-ct-stmt-v1");
    hasher.update(crs.q.to_le_bytes());
    hasher.update(crs.crs_hash);
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    for (t1, t2) in t1s.iter().zip(t2s.iter()) {
        hasher.update(polys_bytes(t1));
        hasher.update(polys_bytes(t2));
    }
    for a in ajtai {
        hasher.update(polys_bytes(&a.t));
    }
    hasher.finalize().into()
}

// ---------------------------------------------------------------------------
// Theta batching and functional packing.

/// l = ceil(256 / log2 q) uniform rows (the design's output-compression
/// discipline; q^-l <= 2^-256 scalar soundness).
pub fn theta_rows(q: u64) -> usize {
    (256.0 / (q as f64).log2()).ceil() as usize
}

/// Draw theta: l x n uniform scalars from the statement hash. MUST be
/// called with an h0 that already binds every commitment of the round
/// (the g-before-theta ordering rule).
pub fn derive_theta(h0: &[u8; 32], l: usize, n: usize, q: u64) -> Vec<Vec<u64>> {
    let mut reader = XofReader::new("theta", &[h0]);
    (0..l).map(|_| (0..n).map(|_| reader.next_field(q)).collect()).collect()
}

/// Pack a scalar functional w (length <= slots * D, padded with zeros)
/// into conjugated ring coefficients: <w, coeffs(x)> = ct( sum_u
/// conj(w~_u) x_u ).
pub fn pack_functional(zq: &super::Zq, w: &[u64], slots: usize) -> Vec<Poly> {
    let mut out = Vec::with_capacity(slots);
    for u in 0..slots {
        let mut chunk = poly_zero();
        for i in 0..D {
            let idx = u * D + i;
            if idx < w.len() {
                chunk[i] = w[idx];
            }
        }
        out.push(poly_conj(zq, &chunk));
    }
    out
}

// ---------------------------------------------------------------------------
// The round.

pub struct CtRoundProof {
    pub h: Vec<Poly>,             // one reveal per claim
    pub w1: Vec<Vec<Poly>>,       // per plain commitment: A1-side mask image
    pub w1_ajtai: Vec<Vec<Poly>>, // per Ajtai commitment: A1 rho-mask + B s-mask image
    pub w_claim: Vec<Poly>,       // per ct-claim: combined message-side mask image
    pub w_ring: Vec<Poly>,        // per ring-claim: combined message-side mask image
    // Quadratic layer (empty when the round has no quadratic claims).
    pub h_quad: Vec<Poly>,        // per quad ct-claim: reveal (ct checked)
    pub gq: Vec<[Poly; 3]>,       // per quad ct-claim: (Ga, Gb, G0)
    pub w_quad: Vec<Poly>,        // per quad ct-claim: linear-part mask image
    pub gr: Vec<[Poly; 2]>,       // per quad ring-claim: (G1, G0)
    pub w_qring: Vec<Poly>,       // per quad ring-claim: linear-part mask image
    pub z: Vec<Vec<Vec<i64>>>,    // per plain commitment: response
    pub z_rho_ajtai: Vec<Vec<Vec<i64>>>, // per Ajtai commitment: rho response
    pub z_s_ajtai: Vec<Vec<Vec<i64>>>,   // per Ajtai commitment: s response
    // Digit-opened combined commitments (empty when the round has none).
    pub t1_digits: Vec<Vec<Vec<Poly>>>,   // per digit commitment: [L][kappa]
    pub w1_digits: Vec<Vec<Vec<Poly>>>,   // per digit commitment: [L][kappa]
    pub z_digits: Vec<Vec<Vec<Vec<i64>>>>, // per digit commitment: [L][n_r]
}

/// Challenge hash: h0 (binds crs/ctx/commitments) + reveals + digit
/// statements + all first messages. The reveals h_l are theta-dependent,
/// so they enter here, not h0.
fn ct_challenge(h0: &[u8; 32], proof_head: &CtRoundProof) -> Vec<i64> {
    let mut hasher = Sha256::new();
    hasher.update(h0);
    hasher.update(polys_bytes(&proof_head.h));
    for td in &proof_head.t1_digits {
        for t in td {
            hasher.update(polys_bytes(t));
        }
    }
    for w in &proof_head.w1 {
        hasher.update(polys_bytes(w));
    }
    for w in &proof_head.w1_ajtai {
        hasher.update(polys_bytes(w));
    }
    for wd in &proof_head.w1_digits {
        for w in wd {
            hasher.update(polys_bytes(w));
        }
    }
    hasher.update(polys_bytes(&proof_head.w_claim));
    hasher.update(polys_bytes(&proof_head.w_ring));
    hasher.update(polys_bytes(&proof_head.h_quad));
    for g in &proof_head.gq {
        hasher.update(polys_bytes(g.as_slice()));
    }
    hasher.update(polys_bytes(&proof_head.w_quad));
    for g in &proof_head.gr {
        hasher.update(polys_bytes(g.as_slice()));
    }
    hasher.update(polys_bytes(&proof_head.w_qring));
    let digest: [u8; 32] = hasher.finalize().into();
    XofReader::new("chal-ct", &[&digest]).next_challenge()
}

/// Generic combo over (index, slot, coeff) lists against any per-commitment
/// group table.
fn coeff_combo(ring: &RingCtx, coeffs: &[(usize, usize, Poly)], groups: &[Vec<Poly>]) -> Poly {
    let zq = &ring.zq;
    let mut acc = poly_zero();
    for (i, j, coeff) in coeffs {
        let prod = ring_mul_split_kara_fast(ring, coeff, &groups[*i][*j]);
        acc = poly_add(zq, &acc, &prod);
    }
    acc
}

/// sum gamma * f(left_a) * right_b over the quad monomial list, where left
/// is drawn from table `ta` (optionally conjugated) and right from `tb`.
fn quad_combo(
    ring: &RingCtx,
    quad: &[(usize, usize, usize, usize, Poly)],
    ta: &[Vec<Poly>],
    conj_left: bool,
    tb: &[Vec<Poly>],
) -> Poly {
    let zq = &ring.zq;
    let mut acc = poly_zero();
    for (ia, ja, ib, jb, gamma) in quad {
        let left = if conj_left { poly_conj(zq, &ta[*ia][*ja]) } else { ta[*ia][*ja].clone() };
        let prod = ring_mul_split_kara_fast(ring, &left, &tb[*ib][*jb]);
        let term = ring_mul_split_kara_fast(ring, gamma, &prod);
        acc = poly_add(zq, &acc, &term);
    }
    acc
}

/// Message-side combination WITHOUT the g-slot term (ring claims have no
/// mask element).
fn ring_claim_combo(ring: &RingCtx, claim: &RingClaim, groups: &[Vec<Poly>]) -> Poly {
    let zq = &ring.zq;
    let mut acc = poly_zero();
    for (i, j, coeff) in &claim.msg_coeffs {
        let prod = ring_mul_split_kara_fast(ring, coeff, &groups[*i][*j]);
        acc = poly_add(zq, &acc, &prod);
    }
    acc
}

/// The claim's message-side combination over any per-commitment group
/// indexed like t2 (the public C_l over t2s, the ZA_l over A2 z's).
fn claim_combo(
    ring: &RingCtx,
    claim: &CtClaim,
    g_slot: (usize, usize), // (g-commitment index, slot) for this claim
    groups: &[Vec<Poly>],   // per std commitment, msg_r elements each
) -> Poly {
    let zq = &ring.zq;
    let mut acc = groups[g_slot.0][g_slot.1].clone();
    for (i, j, coeff) in &claim.msg_coeffs {
        let prod = ring_mul_split_kara_fast(ring, coeff, &groups[*i][*j]);
        acc = poly_add(zq, &acc, &prod);
    }
    acc
}

/// sum phi_(a,u) v_(a,u) for per-Ajtai-commitment integer vectors v
/// (responses or masks), reduced mod q.
fn ajtai_combo(ring: &RingCtx, claim: &CtClaim, vs: &[&[Vec<i64>]]) -> Poly {
    let zq = &ring.zq;
    let mut acc = poly_zero();
    for (a, u, coeff) in &claim.ajtai_coeffs {
        let v_mod = poly_from_small(zq, &vs[*a][*u]);
        let prod = ring_mul_split_kara_fast(ring, coeff, &v_mod);
        acc = poly_add(zq, &acc, &prod);
    }
    acc
}

/// Sample the masking elements g_l (ct = 0, uniform elsewhere) for a batch
/// of n_claims claims; returns them packed into ceil(n_claims / msg_r)
/// message groups ready for commit(). Slot of claim l: group l / msg_r,
/// slot l % msg_r.
pub fn sample_ct_masks(rng: &mut u64, q: u64, msg_r: usize, n_claims: usize) -> Vec<Vec<Poly>> {
    let n_groups = n_claims.div_ceil(msg_r);
    (0..n_groups)
        .map(|g| {
            (0..msg_r)
                .map(|s| {
                    let l = g * msg_r + s;
                    let mut p: Poly = (0..D).map(|_| super::rng_below(rng, q)).collect();
                    if l < n_claims {
                        p[0] = 0; // ct(g_l) = 0 (completeness)
                    }
                    p
                })
                .collect()
        })
        .collect()
}

pub fn g_slot_of(l: usize, msg_r: usize, g_base: usize) -> (usize, usize) {
    (g_base + l / msg_r, l % msg_r)
}

/// Prove a batch of linear ct-claims. Commitment index space for claims:
/// plain commitments first (0..plain.len(), g-commitments appended last
/// inside that range, `g_base` = index of the first), then digit-opened
/// combined commitments (plain.len()..). h0 must bind crs, ctx and every
/// commitment — the claims' coefficients (theta-derived by the caller)
/// must be derived from that same h0. `dp` is required when digits is
/// non-empty (one shared digit chain for all combined commitments).
#[allow(clippy::too_many_arguments)]
pub fn prove_ct_round(
    path: &KernelPath,
    ring: &RingCtx,
    rp: &CtRoundParams,
    dp: Option<&super::sigma::DigitParams>,
    crs: &RingCrs,
    h0: &[u8; 32],
    claims: &[CtClaim],
    ring_claims: &[RingClaim],
    quad_claims: &[QuadCtClaim],
    quad_ring: &[QuadRingClaim],
    plain: &[StdOpening],
    digits: &[DigitOpening],
    ajtai: &[AjtaiOpening],
    g_base: usize,
    rng: &mut u64,
) -> (CtRoundProof, usize) {
    let zq = &ring.zq;
    let shape = crs.shape;
    let msg_r = shape.msg_r;
    assert!(digits.is_empty() || dp.is_some(), "digit openings need DigitParams");
    // All messages in index order (plain then digits) for reveals/W.
    let all_x: Vec<Vec<Poly>> =
        plain.iter().map(|o| o.x.to_vec()).chain(digits.iter().map(|o| o.x.to_vec())).collect();
    // Reveals: h_l = g_l + f_l(witness).
    let h: Vec<Poly> = claims
        .iter()
        .enumerate()
        .map(|(l, claim)| {
            let (gi, gs) = g_slot_of(l, msg_r, g_base);
            let mut acc = all_x[gi][gs].clone();
            for (i, j, coeff) in &claim.msg_coeffs {
                let prod = ring_mul_split_kara_fast(ring, coeff, &all_x[*i][*j]);
                acc = poly_add(zq, &acc, &prod);
            }
            let s_vecs: Vec<&[Vec<i64>]> = ajtai.iter().map(|a| a.s).collect();
            let sc = ajtai_combo(ring, claim, &s_vecs);
            poly_add(zq, &acc, &sc)
        })
        .collect();
    // Quadratic ct-claim reveals: h_q = Q(x) + L(x) + g (g slots start
    // after the linear ct-claims').
    let h_quad: Vec<Poly> = quad_claims
        .iter()
        .enumerate()
        .map(|(l, qc)| {
            let (gi, gs) = g_slot_of(claims.len() + l, msg_r, g_base);
            let q = quad_combo(ring, &qc.quad, &all_x, true, &all_x);
            let lin = coeff_combo(ring, &qc.msg_coeffs, &all_x);
            poly_add(zq, &poly_add(zq, &q, &lin), &all_x[gi][gs])
        })
        .collect();

    // Digit decomposition of the wide randomness + digit statements
    // (witness data — computed once, outside the rejection loop).
    let (dig_e, dig_l) = dp.map(|d| (d.e, d.l)).unwrap_or((1, 0));
    let u_digs: Vec<Vec<Vec<Vec<i64>>>> = digits
        .iter()
        .map(|o| super::digit_split_witness(o.rho_wide, dig_e, dig_l))
        .collect();
    let t1_digits: Vec<Vec<Vec<Poly>>> = u_digs
        .iter()
        .map(|ud| ud.iter().map(|uj| a1_matvec(path, crs, MatvecKind::Mask, uj)).collect())
        .collect();

    let mut attempts = 0usize;
    loop {
        attempts += 1;
        // Masks.
        let ys: Vec<Vec<Vec<i64>>> = (0..plain.len())
            .map(|_| (0..shape.n_r).map(|_| gaussian_ivec(rng, D, rp.sigma)).collect())
            .collect();
        let y_rho_a: Vec<Vec<Vec<i64>>> = (0..ajtai.len())
            .map(|_| (0..shape.n_r).map(|_| gaussian_ivec(rng, D, rp.sigma)).collect())
            .collect();
        let y_s_a: Vec<Vec<Vec<i64>>> = ajtai
            .iter()
            .map(|a| (0..a.s.len()).map(|_| gaussian_ivec(rng, D, rp.sigma_s)).collect())
            .collect();
        let y_digs: Vec<Vec<Vec<Vec<i64>>>> = digits
            .iter()
            .map(|_| {
                (0..dig_l)
                    .map(|_| {
                        (0..shape.n_r)
                            .map(|_| gaussian_ivec(rng, D, dp.unwrap().sigma))
                            .collect()
                    })
                    .collect()
            })
            .collect();
        // First messages: A1-side images.
        let w1: Vec<Vec<Poly>> = ys.iter().map(|y| a1_matvec(path, crs, MatvecKind::Mask, y)).collect();
        let w1_ajtai: Vec<Vec<Poly>> = ajtai
            .iter()
            .zip(y_rho_a.iter().zip(y_s_a.iter()))
            .map(|(a, (yr, ysv))| {
                let base = a1_matvec(path, crs, MatvecKind::Mask, yr);
                let bs = ring_matvec_small_g(zq, &a.com.b_mat, shape.kappa, a.s.len(), ysv);
                base.iter().zip(bs.iter()).map(|(x, y)| poly_add(zq, x, y)).collect()
            })
            .collect();
        let w1_digits: Vec<Vec<Vec<Poly>>> = y_digs
            .iter()
            .map(|yd| yd.iter().map(|yj| a1_matvec(path, crs, MatvecKind::Mask, yj)).collect())
            .collect();
        // Message-side mask images: per plain commitment A2 y; per digit
        // commitment the 2^(ej)-weighted digit-mask sum.
        let a2y_plain: Vec<Vec<Poly>> =
            ys.iter().map(|y| a2_matvec(path, crs, MatvecKind::Mask, y)).collect();
        let a2y_dig: Vec<Vec<Poly>> = y_digs
            .iter()
            .map(|yd| {
                let per_dig: Vec<Vec<Poly>> =
                    yd.iter().map(|yj| a2_matvec(path, crs, MatvecKind::Mask, yj)).collect();
                weighted_digit_sum(zq, &per_dig, dig_e)
            })
            .collect();
        let a2y: Vec<Vec<Poly>> = a2y_plain.into_iter().chain(a2y_dig).collect();
        let w_claim: Vec<Poly> = claims
            .iter()
            .enumerate()
            .map(|(l, claim)| {
                let g_slot = g_slot_of(l, msg_r, g_base);
                let ya = claim_combo(ring, claim, g_slot, &a2y);
                let y_vecs: Vec<&[Vec<i64>]> = y_s_a.iter().map(|y| y.as_slice()).collect();
                let ysum = ajtai_combo(ring, claim, &y_vecs);
                poly_sub(zq, &ya, &ysum)
            })
            .collect();
        let w_ring: Vec<Poly> =
            ring_claims.iter().map(|rc| ring_claim_combo(ring, rc, &a2y)).collect();
        // Quadratic garbage terms (pre-challenge; masks fresh per attempt).
        let gq: Vec<[Poly; 3]> = quad_claims
            .iter()
            .map(|qc| {
                let ga = quad_combo(ring, &qc.quad, &all_x, true, &a2y);
                let gb = quad_combo(ring, &qc.quad, &a2y, true, &all_x);
                let g0 = quad_combo(ring, &qc.quad, &a2y, true, &a2y);
                [ga, gb, g0]
            })
            .collect();
        let w_quad: Vec<Poly> = quad_claims
            .iter()
            .enumerate()
            .map(|(l, qc)| {
                let (gi, gs) = g_slot_of(claims.len() + l, msg_r, g_base);
                poly_add(zq, &coeff_combo(ring, &qc.msg_coeffs, &a2y), &a2y[gi][gs])
            })
            .collect();
        let gr: Vec<[Poly; 2]> = quad_ring
            .iter()
            .map(|qr| {
                let g1a = quad_combo(ring, &qr.quad, &all_x, false, &a2y);
                let g1b = quad_combo(ring, &qr.quad, &a2y, false, &all_x);
                let g1 = poly_add(zq, &g1a, &g1b);
                let g0 = quad_combo(ring, &qr.quad, &a2y, false, &a2y);
                [g1, g0]
            })
            .collect();
        let w_qring: Vec<Poly> =
            quad_ring.iter().map(|qr| coeff_combo(ring, &qr.msg_coeffs, &a2y)).collect();

        let head = CtRoundProof {
            h: h.clone(),
            w1,
            w1_ajtai,
            w_claim,
            w_ring,
            h_quad: h_quad.clone(),
            gq,
            w_quad,
            gr,
            w_qring,
            z: Vec::new(),
            z_rho_ajtai: Vec::new(),
            z_s_ajtai: Vec::new(),
            t1_digits: t1_digits.clone(),
            w1_digits,
            z_digits: Vec::new(),
        };
        let c = ct_challenge(h0, &head);

        // Responses + rejection: three bundles (plain rho + Ajtai rho;
        // Ajtai s; digit) accepted independently — the repetition rate is
        // the product of the M's (the joint-scaling rework is the Q4
        // lemma's scope).
        let add = |y: &[Vec<i64>], v: &[Vec<i64>]| -> Vec<Vec<i64>> {
            y.iter()
                .zip(v.iter())
                .map(|(yn, vn)| yn.iter().zip(vn.iter()).map(|(&a, &b)| a + b).collect())
                .collect()
        };
        let centers_std: Vec<Vec<Vec<i64>>> = plain
            .iter()
            .map(|o| o.rho.iter().map(|r| poly_mul_small(&c, r)).collect())
            .collect();
        let centers_rho_a: Vec<Vec<Vec<i64>>> = ajtai
            .iter()
            .map(|a| a.rho.iter().map(|r| poly_mul_small(&c, r)).collect())
            .collect();
        let centers_s_a: Vec<Vec<Vec<i64>>> = ajtai
            .iter()
            .map(|a| a.s.iter().map(|sv| poly_mul_small(&c, sv)).collect())
            .collect();
        let centers_dig: Vec<Vec<Vec<Vec<i64>>>> = u_digs
            .iter()
            .map(|ud| {
                ud.iter()
                    .map(|uj| uj.iter().map(|un| poly_mul_small(&c, un)).collect())
                    .collect()
            })
            .collect();
        let z: Vec<Vec<Vec<i64>>> =
            ys.iter().zip(centers_std.iter()).map(|(y, v)| add(y, v)).collect();
        let z_rho_ajtai: Vec<Vec<Vec<i64>>> =
            y_rho_a.iter().zip(centers_rho_a.iter()).map(|(y, v)| add(y, v)).collect();
        let z_s_ajtai: Vec<Vec<Vec<i64>>> =
            y_s_a.iter().zip(centers_s_a.iter()).map(|(y, v)| add(y, v)).collect();
        let z_digits: Vec<Vec<Vec<Vec<i64>>>> = y_digs
            .iter()
            .zip(centers_dig.iter())
            .map(|(yd, vd)| yd.iter().zip(vd.iter()).map(|(yj, vj)| add(yj, vj)).collect())
            .collect();

        let flat2 = |vs: &[Vec<Vec<i64>>], extra: &[Vec<Vec<i64>>]| -> Vec<i64> {
            vs.iter().chain(extra.iter()).flatten().flatten().copied().collect()
        };
        let flat_z = flat2(&z, &z_rho_ajtai);
        let flat_v = flat2(&centers_std, &centers_rho_a);
        // Concentration restart rule (when the params were conc-sized).
        if rp.center_sq > 0 && vec_norm_sq_i64(&flat_v) > rp.center_sq {
            continue;
        }
        if let Some(d) = dp {
            let fv: Vec<i64> = centers_dig.iter().flatten().flatten().flatten().copied().collect();
            if !centers_dig.is_empty() && vec_norm_sq_i64(&fv) > d.center_sq * digits.len() as u128 {
                continue;
            }
        }
        let ok_std = flat_z.is_empty() || rejection_accept(rng, &flat_z, &flat_v, rp.sigma);
        let ok_s = if rp.sigma_s == 0 {
            true
        } else {
            let fz: Vec<i64> = z_s_ajtai.iter().flatten().flatten().copied().collect();
            let fv: Vec<i64> = centers_s_a.iter().flatten().flatten().copied().collect();
            rejection_accept(rng, &fz, &fv, rp.sigma_s)
        };
        let ok_dig = if digits.is_empty() {
            true
        } else {
            let fz: Vec<i64> = z_digits.iter().flatten().flatten().flatten().copied().collect();
            let fv: Vec<i64> = centers_dig.iter().flatten().flatten().flatten().copied().collect();
            rejection_accept(rng, &fz, &fv, dp.unwrap().sigma)
        };
        if ok_std && ok_s && ok_dig {
            return (
                CtRoundProof {
                    h: head.h,
                    w1: head.w1,
                    w1_ajtai: head.w1_ajtai,
                    w_claim: head.w_claim,
                    w_ring: head.w_ring,
                    h_quad: head.h_quad,
                    gq: head.gq,
                    w_quad: head.w_quad,
                    gr: head.gr,
                    w_qring: head.w_qring,
                    z,
                    z_rho_ajtai,
                    z_s_ajtai,
                    t1_digits: head.t1_digits,
                    w1_digits: head.w1_digits,
                    z_digits,
                },
                attempts,
            );
        }
    }
}

/// sum_j 2^(ej) group_j, element-wise over msg_r-length groups.
fn weighted_digit_sum(zq: &super::Zq, per_dig: &[Vec<Poly>], e: u32) -> Vec<Poly> {
    let msg_r = per_dig[0].len();
    (0..msg_r)
        .map(|slot| {
            let mut acc = poly_zero();
            for (j, grp) in per_dig.iter().enumerate() {
                let scale = zq.to_mod(1i64 << (e as usize * j));
                for k in 0..D {
                    acc[k] = zq.add(acc[k], zq.mul(scale, grp[slot][k]));
                }
            }
            acc
        })
        .collect()
}

/// Verify a ct-round: shapes, exact-integer norms (FIRST — the A1 verify
/// kernel contract), ct(h_l) = scalar_l, digit recombinations against the
/// verifier-computed combined T1s, per-commitment A1-side opening checks,
/// per-claim message-side checks against W_l. t1s/t2s: plain commitments
/// (incl. g-commitments); t1s_dig/t2s_dig: the COMBINED commitments,
/// computed by the verifier from the public column groups.
#[allow(clippy::too_many_arguments)]
pub fn verify_ct_round(
    path: &KernelPath,
    ring: &RingCtx,
    rp: &CtRoundParams,
    dp: Option<&super::sigma::DigitParams>,
    crs: &RingCrs,
    h0: &[u8; 32],
    claims: &[CtClaim],
    ring_claims: &[RingClaim],
    quad_claims: &[QuadCtClaim],
    quad_ring: &[QuadRingClaim],
    t1s: &[Vec<Poly>],
    t2s: &[Vec<Poly>],
    t1s_dig: &[Vec<Poly>],
    t2s_dig: &[Vec<Poly>],
    ajtai_coms: &[&AjtaiCommit],
    g_base: usize,
    proof: &CtRoundProof,
) -> bool {
    let zq = &ring.zq;
    let shape = crs.shape;
    let n_plain = t1s.len();
    let n_dig = t1s_dig.len();
    if proof.h.len() != claims.len()
        || proof.w1.len() != n_plain
        || proof.z.len() != n_plain
        || proof.w1_ajtai.len() != ajtai_coms.len()
        || proof.z_rho_ajtai.len() != ajtai_coms.len()
        || proof.z_s_ajtai.len() != ajtai_coms.len()
        || proof.w_claim.len() != claims.len()
        || proof.w_ring.len() != ring_claims.len()
        || proof.h_quad.len() != quad_claims.len()
        || proof.gq.len() != quad_claims.len()
        || proof.w_quad.len() != quad_claims.len()
        || proof.gr.len() != quad_ring.len()
        || proof.w_qring.len() != quad_ring.len()
        || proof.t1_digits.len() != n_dig
        || proof.w1_digits.len() != n_dig
        || proof.z_digits.len() != n_dig
    {
        return false;
    }
    if n_dig > 0 && dp.is_none() {
        return false;
    }
    for zi in proof.z.iter().chain(proof.z_rho_ajtai.iter()) {
        if zi.len() != shape.n_r {
            return false;
        }
    }
    let (dig_e, dig_l) = dp.map(|d| (d.e, d.l)).unwrap_or((1, 0));
    for i in 0..n_dig {
        if proof.t1_digits[i].len() != dig_l
            || proof.w1_digits[i].len() != dig_l
            || proof.z_digits[i].len() != dig_l
        {
            return false;
        }
        for j in 0..dig_l {
            if proof.t1_digits[i][j].len() != shape.kappa
                || proof.w1_digits[i][j].len() != shape.kappa
                || proof.z_digits[i][j].len() != shape.n_r
            {
                return false;
            }
        }
    }
    // Norm checks first (std bundle incl. Ajtai rho parts, s bundle, digit
    // bundles per commitment).
    let flat_std: Vec<i64> = proof
        .z
        .iter()
        .chain(proof.z_rho_ajtai.iter())
        .flatten()
        .flatten()
        .copied()
        .collect();
    if vec_norm_sq_i64(&flat_std) > rp.bound_sq {
        return false;
    }
    if rp.sigma_s > 0 {
        let flat_s: Vec<i64> = proof.z_s_ajtai.iter().flatten().flatten().copied().collect();
        if vec_norm_sq_i64(&flat_s) > rp.bound_s_sq {
            return false;
        }
    }
    if let Some(d) = dp {
        for zd in &proof.z_digits {
            let flat: Vec<i64> = zd.iter().flatten().flatten().copied().collect();
            if vec_norm_sq_i64(&flat) > d.bound_sq {
                return false;
            }
        }
    }
    // Deterministic scalar checks.
    for (claim, h) in claims.iter().zip(proof.h.iter()) {
        if ct_coeff(zq, h) != claim.scalar {
            return false;
        }
    }
    for (qc, h) in quad_claims.iter().zip(proof.h_quad.iter()) {
        if ct_coeff(zq, h) != qc.scalar {
            return false;
        }
    }
    // Digit recombination against the verifier-computed combined T1s.
    for i in 0..n_dig {
        for r in 0..shape.kappa {
            let mut acc = poly_zero();
            for j in 0..dig_l {
                let scale = zq.to_mod(1i64 << (dig_e as usize * j));
                for k in 0..D {
                    acc[k] = zq.add(acc[k], zq.mul(scale, proof.t1_digits[i][j][r][k]));
                }
            }
            if acc != t1s_dig[i][r] {
                return false;
            }
        }
    }
    let c = ct_challenge(h0, proof);
    let c_mod = poly_from_small(zq, &c);
    let mul_ct1 = |t: &Poly| -> Poly {
        match path {
            KernelPath::School => ring_mul_split_kara_fast(ring, &c_mod, t),
            KernelPath::A1(p) => ring_mul_q_single(t, &c, zq.q, &p.nt),
        }
    };
    // Per-commitment A1-side opening checks.
    for i in 0..n_plain {
        let lhs = a1_matvec(path, crs, MatvecKind::Verify, &proof.z[i]);
        for r in 0..shape.kappa {
            if lhs[r] != poly_add(zq, &proof.w1[i][r], &mul_ct1(&t1s[i][r])) {
                return false;
            }
        }
    }
    for (a, com) in ajtai_coms.iter().enumerate() {
        let s_r = proof.z_s_ajtai[a].len();
        if com.b_mat.len() != shape.kappa * s_r || com.t.len() != shape.kappa {
            return false;
        }
        let base = a1_matvec(path, crs, MatvecKind::Verify, &proof.z_rho_ajtai[a]);
        let bs = ring_matvec_small_g(zq, &com.b_mat, shape.kappa, s_r, &proof.z_s_ajtai[a]);
        for r in 0..shape.kappa {
            let lhs = poly_add(zq, &base[r], &bs[r]);
            if lhs != poly_add(zq, &proof.w1_ajtai[a][r], &mul_ct1(&com.t[r])) {
                return false;
            }
        }
    }
    // Per-digit Sigma equations (shared challenge).
    for i in 0..n_dig {
        for j in 0..dig_l {
            let lhs = a1_matvec(path, crs, MatvecKind::Verify, &proof.z_digits[i][j]);
            for r in 0..shape.kappa {
                if lhs[r] != poly_add(zq, &proof.w1_digits[i][j][r], &mul_ct1(&proof.t1_digits[i][j][r])) {
                    return false;
                }
            }
        }
    }
    // Per-claim message-side checks: c h_l - c C_l + ZA_l - ZS_l = W_l.
    // Digit commitments contribute 2^(ej)-weighted response sums.
    let a2z_plain: Vec<Vec<Poly>> =
        (0..n_plain).map(|i| a2_matvec(path, crs, MatvecKind::Verify, &proof.z[i])).collect();
    let a2z_dig: Vec<Vec<Poly>> = (0..n_dig)
        .map(|i| {
            let per_dig: Vec<Vec<Poly>> = (0..dig_l)
                .map(|j| a2_matvec(path, crs, MatvecKind::Verify, &proof.z_digits[i][j]))
                .collect();
            weighted_digit_sum(zq, &per_dig, dig_e)
        })
        .collect();
    let a2z: Vec<Vec<Poly>> = a2z_plain.into_iter().chain(a2z_dig).collect();
    let t2_all: Vec<Vec<Poly>> = t2s.iter().cloned().chain(t2s_dig.iter().cloned()).collect();
    for (l, claim) in claims.iter().enumerate() {
        let g_slot = g_slot_of(l, shape.msg_r, g_base);
        let c_l = claim_combo(ring, claim, g_slot, &t2_all);
        let za_l = claim_combo(ring, claim, g_slot, &a2z);
        let zs_vecs: Vec<&[Vec<i64>]> = proof.z_s_ajtai.iter().map(|v| v.as_slice()).collect();
        let zs_l = ajtai_combo(ring, claim, &zs_vecs);
        let ch = ring_mul_split_kara_fast(ring, &c_mod, &proof.h[l]);
        let cc = ring_mul_split_kara_fast(ring, &c_mod, &c_l);
        let lhs = poly_sub(zq, &poly_add(zq, &poly_sub(zq, &ch, &cc), &za_l), &zs_l);
        if lhs != proof.w_claim[l] {
            return false;
        }
    }
    // Ring-valued claims: W_rl = ZA_rl - c C_rl (the claim value is the
    // zero ring element; extraction divides by the invertible challenge
    // difference and pins sum coeff * x = 0 exactly).
    for (l, rc) in ring_claims.iter().enumerate() {
        let c_rl = ring_claim_combo(ring, rc, &t2_all);
        let za_rl = ring_claim_combo(ring, rc, &a2z);
        let cc = ring_mul_split_kara_fast(ring, &c_mod, &c_rl);
        if poly_sub(zq, &za_rl, &cc) != proof.w_ring[l] {
            return false;
        }
    }
    // Quadratic layer. P table: P_i = c t2_i - (A2 z_i) = c x_i - Y_i.
    if !quad_claims.is_empty() || !quad_ring.is_empty() {
        let p_table: Vec<Vec<Poly>> = t2_all
            .iter()
            .zip(a2z.iter())
            .map(|(t2, az)| {
                t2.iter()
                    .zip(az.iter())
                    .map(|(t, a)| {
                        let ct2 = ring_mul_split_kara_fast(ring, &c_mod, t);
                        poly_sub(zq, &ct2, a)
                    })
                    .collect()
            })
            .collect();
        let sig_c = poly_conj(zq, &c_mod);
        let sc_c = ring_mul_split_kara_fast(ring, &sig_c, &c_mod);
        // sigma-twisted ct-quadratics:
        //   sigma(c) c h = E + sigma(c) Ga + c Gb - G0
        //               + sigma(c) (c C_L - ZA_L + W_L).
        for (l, qc) in quad_claims.iter().enumerate() {
            let g_slot = g_slot_of(claims.len() + l, shape.msg_r, g_base);
            let e = quad_combo(ring, &qc.quad, &p_table, true, &p_table);
            let c_l = poly_add(zq, &coeff_combo(ring, &qc.msg_coeffs, &t2_all), &t2_all[g_slot.0][g_slot.1]);
            let za_l = poly_add(zq, &coeff_combo(ring, &qc.msg_coeffs, &a2z), &a2z[g_slot.0][g_slot.1]);
            let lin = {
                let ccl = ring_mul_split_kara_fast(ring, &c_mod, &c_l);
                let inner = poly_add(zq, &poly_sub(zq, &ccl, &za_l), &proof.w_quad[l]);
                ring_mul_split_kara_fast(ring, &sig_c, &inner)
            };
            let lhs = ring_mul_split_kara_fast(ring, &sc_c, &proof.h_quad[l]);
            let mut rhs = poly_add(zq, &e, &ring_mul_split_kara_fast(ring, &sig_c, &proof.gq[l][0]));
            rhs = poly_add(zq, &rhs, &ring_mul_split_kara_fast(ring, &c_mod, &proof.gq[l][1]));
            rhs = poly_sub(zq, &rhs, &proof.gq[l][2]);
            rhs = poly_add(zq, &rhs, &lin);
            if lhs != rhs {
                return false;
            }
        }
        // Untwisted ring-valued quadratics:
        //   E2 + c G1 - G0 + c (c C_L - ZA_L + W_L) = 0.
        for (l, qr) in quad_ring.iter().enumerate() {
            let e2 = quad_combo(ring, &qr.quad, &p_table, false, &p_table);
            let c_l = coeff_combo(ring, &qr.msg_coeffs, &t2_all);
            let za_l = coeff_combo(ring, &qr.msg_coeffs, &a2z);
            let lin = {
                let ccl = ring_mul_split_kara_fast(ring, &c_mod, &c_l);
                let inner = poly_add(zq, &poly_sub(zq, &ccl, &za_l), &proof.w_qring[l]);
                ring_mul_split_kara_fast(ring, &c_mod, &inner)
            };
            let mut lhs = poly_add(zq, &e2, &ring_mul_split_kara_fast(ring, &c_mod, &proof.gr[l][0]));
            lhs = poly_sub(zq, &lhs, &proof.gr[l][1]);
            lhs = poly_add(zq, &lhs, &lin);
            if lhs.iter().any(|&x| x != 0) {
                return false;
            }
        }
    }
    true
}

// ---------------------------------------------------------------------------
// ARP: approximate range proof by JL projection (mechanism per LNP22; the
// extraction constant is parameterized — see the module header's Q4 note).

/// Conservative relaxed-opening slack: worst-case l1 of a challenge
/// difference (||c - c'||_1 <= 4D). The Q4 lemma is expected to tighten
/// this; every budget that must close TODAY closes with this value or the
/// shape is rejected at derive time.
pub const SLACK_OP: f64 = 4.0 * D as f64;
/// JL lower-bound constant for rows x n sign projections (LNP22 Lemma
/// 2.8-class): ||R b||_2^2 >= rows/13 * ||b||_2^2 except w.p. ~2^-128.
pub const JL_C: f64 = 13.0;

pub struct ArpParams {
    pub rows: usize,
    pub n: usize,       // projected coefficient count
    pub sigma_arp: u64, // masking-vector Gaussian parameter
    pub y_bound_sq: u128,
    /// Extracted (relaxed) l2 bound on the projected witness implied by an
    /// accepting ARP, with the conservative constants above.
    pub extract_bound: f64,
}

/// Size the ARP for an honest witness with per-coefficient bound w_inf
/// over n coefficients. alpha follows the report's rejection discipline
/// but is a free knob here (smaller alpha = tighter extraction, more
/// restarts); alpha = 3 keeps M ~ e^(1/2 + 1/18) ~ 1.75.
pub fn derive_arp_params(n: usize, rows: usize, w_inf: u64, alpha: f64) -> ArpParams {
    // Honest center per row: concentration 1.3 sqrt(n E[R^2] E[b^2]) with
    // E[R^2] = 1/2 (rows are {0,+-1} w.p. 1/2,1/4,1/4).
    let center_row = 1.3 * (n as f64 * 0.5).sqrt() * w_inf as f64;
    let center_bundle = center_row * (rows as f64).sqrt();
    let sigma_arp = (alpha * center_bundle).ceil() as u64;
    let y_bound = 1.2 * sigma_arp as f64 * (rows as f64).sqrt();
    let y_bound_sq = (y_bound * y_bound).ceil() as u128;
    // ||c-bar (y - m')||_2 <= slack * 2 * y_bound-class; JL lower bound
    // with constant JL_C. Conservative composition (Q4 note).
    let extract_bound = SLACK_OP * 2.0 * y_bound / (rows as f64 / JL_C).sqrt();
    ArpParams { rows, n, sigma_arp, y_bound_sq, extract_bound }
}

/// Derive-time budget check for a non-wrap side condition |defect| <
/// budget given the ARP's extracted bound B: the quadratic defect is
/// bounded by B^2 + B sqrt(n). Returns false (caller must fall back to an
/// exact range strategy) when the conservative constants do not close.
pub fn arp_budget_ok(ap: &ArpParams, budget: f64) -> bool {
    let b = ap.extract_bound;
    b * b + b * (ap.n as f64).sqrt() < budget
}

/// FS-derived JL rows: entries in {0, +1, -1} with probabilities
/// (1/2, 1/4, 1/4), rows x n, from the round's h0 (which must already
/// bind the witness commitments and the ARP mask commitment).
pub fn derive_jl_rows(h0: &[u8; 32], rows: usize, n: usize) -> Vec<Vec<i64>> {
    let mut reader = XofReader::new("arp-jl", &[h0]);
    (0..rows)
        .map(|_| {
            (0..n)
                .map(|_| {
                    let b = reader.next_bytes(1)[0];
                    match b & 3 {
                        0 => 1i64,
                        1 => -1i64,
                        _ => 0i64,
                    }
                })
                .collect()
        })
        .collect()
}

/// Sample the ARP masking vector (Gaussian, sigma_arp). MUST be sampled
/// and COMMITTED (Ajtai slot) before the JL rows are derived — the
/// FS-with-aborts loop therefore wraps the whole sequence: sample m ->
/// commit m -> h0 -> derive R -> arp_attempt; on None, restart with a
/// FRESH m (and hence a fresh h0 and fresh R).
pub fn sample_arp_mask(ap: &ArpParams, rng: &mut u64) -> Vec<i64> {
    gaussian_ivec(rng, ap.rows, ap.sigma_arp)
}

/// Pack the flat mask into ceil(rows / D) ring elements for the Ajtai slot.
pub fn pack_arp_mask(ap: &ArpParams, m_flat: &[i64]) -> Vec<Vec<i64>> {
    let s_r = ap.rows.div_ceil(D);
    (0..s_r)
        .map(|u| (0..D).map(|i| m_flat.get(u * D + i).copied().unwrap_or(0)).collect())
        .collect()
}

/// One reveal attempt: y = R b + m, rejection-sampled against center R b
/// plus the range gate. None = the caller restarts the round with a fresh
/// mask commitment. b_coeffs are the centered coefficients of the
/// committed witness being ranged (concatenated packing order).
pub fn arp_attempt(
    ap: &ArpParams,
    jl: &[Vec<i64>],
    b_coeffs: &[i64],
    m_flat: &[i64],
    rng: &mut u64,
) -> Option<Vec<i64>> {
    assert_eq!(jl.len(), ap.rows);
    let centers: Vec<i64> = jl
        .iter()
        .map(|row| row.iter().zip(b_coeffs.iter()).map(|(&r, &b)| r * b).sum())
        .collect();
    let y: Vec<i64> = m_flat.iter().zip(centers.iter()).map(|(&m, &c)| m + c).collect();
    if !rejection_accept(rng, &y, &centers, ap.sigma_arp) {
        return None;
    }
    if vec_norm_sq_i64(&y) > ap.y_bound_sq {
        return None;
    }
    Some(y)
}

/// The ARP's ct-claims: for each row i, ct-claim
///   sum_u conj(R~_iu) x_u + conj(X^(i mod D)) m_(i/D)  has ct = y_i.
/// msg_slots maps flat witness chunks u to (commitment, slot) pairs.
pub fn arp_claims(
    zq: &super::Zq,
    ap: &ArpParams,
    jl: &[Vec<i64>],
    msg_slots: &[(usize, usize)],
    ajtai_idx: usize,
    y: &[i64],
) -> Vec<CtClaim> {
    (0..ap.rows)
        .map(|i| {
            let w: Vec<u64> = jl[i].iter().map(|&v| zq.to_mod(v)).collect();
            let packed = pack_functional(zq, &w, msg_slots.len());
            let msg_coeffs: Vec<(usize, usize, Poly)> = packed
                .into_iter()
                .enumerate()
                .map(|(u, coeff)| {
                    let (ci, sj) = msg_slots[u];
                    (ci, sj, coeff)
                })
                .collect();
            // conj(X^(i mod D)): coefficient extraction of slot i of m.
            let mut xi = poly_zero();
            xi[i % D] = 1;
            let phi = poly_conj(zq, &xi);
            CtClaim { msg_coeffs, ajtai_coeffs: vec![(ajtai_idx, i / D, phi)], scalar: y[i] }
        })
        .collect()
}

/// Verifier-side ARP checks that sit OUTSIDE the ct-round: the reveal's
/// range. (The tie y_i = <R_i, b> + m_i is the ct-round's job.)
pub fn arp_check_reveal(ap: &ArpParams, y: &[i64]) -> bool {
    y.len() == ap.rows && vec_norm_sq_i64(y) <= ap.y_bound_sq
}

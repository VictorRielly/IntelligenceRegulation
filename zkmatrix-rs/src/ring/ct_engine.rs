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
//
// *** ARP IS LEGACY, NOT ZK-GRADE (audit 2026-07-14 C-01). *** At the
// frozen operating point (ARP_REJ_T = 1.5) the rejection test clips the
// masked reveal at Phi(-1.5) ~ 2^-4.75 per unit — a non-negligible
// statistical defect, so ARP-arm transcripts are NOT statistical zero
// knowledge (see the ARP_REJ_T doc for the parameter economics that
// close the demotion argument). ARP therefore stays only as the LEGACY
// range arm of the q46 block chain (ffn-chain); the target path for
// range facts is the exact [0,256) range-lookup table (U-R2), and the
// per-layer rig is ARP-free (U-R ledger D-5). The LKP-8/9 freeze rows
// pin these constants for REPRODUCIBILITY, not as a security claim.

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

/// One RING-VALUED linear claim: sum_(i,j) a_(i,j) x_(i,j) = constant
/// over R_q (all D coefficients — no ct projection, no g-mask, no
/// reveal; W_rl is simulatable from the verification equation, so
/// nothing leaks). This is the natural claim form for R-linear public
/// maps (design Section 4 option (a): negacyclic-block A, shift/gadget
/// matrices, convolutions, block-selection) and, with a nonzero public
/// constant, for the committed-executions tie claims (Appendix B.1:
/// masked-reveal pivots F with the claim value being a public
/// tau-combination of the reveals). Per-slot soundness 2^-296 via the
/// same two-transcript extraction as the ct-claims: subtracting two
/// accepting transcripts clears the constant and pins
/// sum a x - constant = 0 exactly. The constant is STATEMENT data — the
/// caller must bind it (or the reveals it derives from) into h0.
pub struct RingClaim {
    pub msg_coeffs: Vec<(usize, usize, Poly)>,
    /// Public claim value K: sum a x = K. Zero for homogeneous claims.
    pub constant: Poly,
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
// soundness item 1).
//
// R1 MASKING (Q4_LEMMAS.md Section R1 — the Q4.3d/e fix). The garbage
// terms sent in the clear are NOT hidden by the Gaussian mask images Y
// (Y is pinned by the revealed response z: Y_i = c x_i - P_i with P
// verifier-computable), so the unmasked layer leaks the witness-images
// Q and L exactly (Q4.3d-1/2; for the committed-executions gate the
// leaked L recovers the product matrix C — Q4.3e). Every quadratic
// claim therefore carries committed one-time pads riding the round's
// g-slot space, AFTER the ct-masked reveal slots:
//
//   quad ct-claim l    -> 3 pads at pb + 3l                  (conj(ma), mb, conj(mw))
//   quad ring-claim l  -> 2 pads at pb + 3 n_qct + 2l                    (m1, mw)
//   twisted quad l     -> 3 pads at pb + 3 n_qct + 2 n_qr + 3l (conj(ma), mb, conj(mw))
//
// with pb = n_lin + n_qct (the ct-masked slots). Pads are UNIFORM ring
// elements (no ct constraint); the sigma(c)-side pads (ma, mw of the
// twisted families) are committed PRE-CONJUGATED so a standard virtual
// opening supplies the twisted monomial: conj(P_slot) = sigma(c) m -
// conj(Y_slot). The prover sends the MASKED images (same element count):
//   Ga~ = Ga + ma, Gb~ = Gb + mb, W~ = W + mw,
//   G0~ = G0 + conj(Y_MA) + Y_MB + conj(Y_MW)   (twisted; untwisted:
//   G1~ = G1 + m1, W~ = W + mw, G0~ = G0 + Y_M1 + Y_MW)
// and the verifier subtracts the pad openings from the check. Pads ride
// the g-commitments (shared rho/z, no new response bundle or rejection
// test) and are bound by h0 BEFORE the round challenge — the R1.2
// ordering rule; the R1 order-regression battery pins both directions.
// Soundness is unchanged (pads are pre-challenge images entering only
// lower challenge monomials — the Vandermonde clearing annihilates
// them); the masked variant is HVZK under the round's MLWE assumption
// alone (machine-checked completeness: scripts/zk_lemma_check.py
// OK-3a/3b; the leak identities OK-1/2a and the C recovery OK-4).

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

/// Sigma-twisted RING-VALUED quadratic claim (no ct projection, no
/// reveal, no g-mask — the committed-executions gate's claim form,
/// AUTOMORPHISM_GATE_DESIGN.md Appendix B):
///     sum_p gamma_p sigma(x_ap) x_bp + sum a x = 0   over the FULL ring.
/// Check (the QuadCtClaim equation with h = 0 and no g slot):
///     E + sigma(c) Ga + c Gb - G0
///       + sigma(c) (c C_L - ZA_L + W_L)  =  0,
/// with E = sum gamma sigma(P_a) P_b over the virtual-opening table and
/// (Ga, Gb, G0, W_L) the prover's pre-challenge garbage/mask images.
/// Extraction over three transcripts pins the identity exactly
/// (sigma(dc) dc invertible by LS18); nothing is revealed, so the only
/// ZK surface is the garbage terms (Q4.3's R1 masking applies here too).
pub struct TwistedQuadRingClaim {
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
    let _t = prof::timer(prof::CT_H0); // [UPERF-PC] observation only
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
    pub gtq: Vec<[Poly; 3]>,      // per twisted quad ring-claim: (Ga, Gb, G0)
    pub w_tq: Vec<Poly>,          // per twisted quad ring-claim: linear mask image
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
    for g in &proof_head.gtq {
        hasher.update(polys_bytes(g.as_slice()));
    }
    hasher.update(polys_bytes(&proof_head.w_tq));
    let digest: [u8; 32] = hasher.finalize().into();
    XofReader::new("chal-ct", &[&digest]).next_challenge()
}

/// Recompute a transcript's round challenge from public data. Exposed for
/// the R1 regression battery (which crafts a pad commitment AFTER the
/// challenge and shows the h0-bound chain rejects it) and for
/// leak-arithmetic checks that evaluate verifier-computable combinations
/// of a transcript (Q4.3d).
pub fn ct_round_challenge(h0: &[u8; 32], proof: &CtRoundProof) -> Vec<i64> {
    ct_challenge(h0, proof)
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

/// R1 pad-slot count for a round's quadratic claims (Q4_LEMMAS.md R1.4):
/// 3 per quad ct-claim, 2 per untwisted quad ring-claim, 3 per twisted
/// quad ring-claim. Callers size the g-groups with sample_g_masks
/// (n_pads = this) and commit them BEFORE h0 — the R1.2 ordering rule.
pub fn r1_pad_count(n_qct: usize, n_qr: usize, n_tq: usize) -> usize {
    3 * n_qct + 2 * n_qr + 3 * n_tq
}

/// Flat g-slot index of the first R1 pad of each quadratic family, given
/// the round's claim counts (layout in the quadratic-layer header).
fn r1_pad_base(n_lin: usize, n_qct: usize, n_qr: usize) -> (usize, usize, usize) {
    let qct = n_lin + n_qct;
    let qr = qct + 3 * n_qct;
    let tq = qr + 2 * n_qr;
    (qct, qr, tq)
}

/// Sample the round's g-groups: n_ct ct-masked reveal masks (ct(g_l) = 0,
/// uniform elsewhere — the theta-batch discipline) followed by n_pads R1
/// one-time pads (FULLY uniform, no ct constraint — R1.1). Returns
/// ceil((n_ct + n_pads) / msg_r) message groups ready for commit().
/// Flat slot l: group l / msg_r, slot l % msg_r (g_slot_of).
pub fn sample_g_masks(
    rng: &mut dyn super::RngSource,
    q: u64,
    msg_r: usize,
    n_ct: usize,
    n_pads: usize,
) -> Vec<Vec<Poly>> {
    let n_groups = (n_ct + n_pads).div_ceil(msg_r);
    (0..n_groups)
        .map(|g| {
            (0..msg_r)
                .map(|s| {
                    let l = g * msg_r + s;
                    let mut p: Poly = (0..D).map(|_| super::rng_below(rng, q)).collect();
                    if l < n_ct {
                        p[0] = 0; // ct(g_l) = 0 (completeness)
                    }
                    p
                })
                .collect()
        })
        .collect()
}

/// Sample the masking elements g_l (ct = 0, uniform elsewhere) for a batch
/// of n_claims LINEAR ct-claims (rounds with quadratic claims must use
/// sample_g_masks with the r1_pad_count pad tail).
pub fn sample_ct_masks(
    rng: &mut dyn super::RngSource,
    q: u64,
    msg_r: usize,
    n_claims: usize,
) -> Vec<Vec<Poly>> {
    sample_g_masks(rng, q, msg_r, n_claims, 0)
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
    rng: &mut dyn super::RngSource,
) -> (CtRoundProof, usize) {
    prove_ct_round_tq(
        path, ring, rp, dp, crs, h0, claims, ring_claims, quad_claims, quad_ring, &[], plain,
        digits, ajtai, g_base, rng,
    )
}

/// prove_ct_round with sigma-twisted ring-valued quadratic claims (the
/// committed-executions gate). The plain wrapper above delegates here.
#[allow(clippy::too_many_arguments)]
pub fn prove_ct_round_tq(
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
    tq_claims: &[TwistedQuadRingClaim],
    plain: &[StdOpening],
    digits: &[DigitOpening],
    ajtai: &[AjtaiOpening],
    g_base: usize,
    rng: &mut dyn super::RngSource,
) -> (CtRoundProof, usize) {
    let _t_total = prof::timer(prof::CT_TOTAL); // [UPERF-PC] observation only
    let t_setup = prof::timer(prof::CT_SETUP);
    let zq = &ring.zq;
    let shape = crs.shape;
    let msg_r = shape.msg_r;
    assert!(digits.is_empty() || dp.is_some(), "digit openings need DigitParams");
    // All messages in index order (plain then digits) for reveals/W.
    let all_x: Vec<Vec<Poly>> =
        plain.iter().map(|o| o.x.to_vec()).chain(digits.iter().map(|o| o.x.to_vec())).collect();
    // R1 pad layout: the g-slot space must cover the quad-claim pads
    // (callers size the g-groups with sample_g_masks + r1_pad_count).
    let (pb_qct, pb_qr, pb_tq) = r1_pad_base(claims.len(), quad_claims.len(), quad_ring.len());
    let n_gslots = pb_tq + 3 * tq_claims.len();
    if n_gslots > 0 {
        let (gi, _) = g_slot_of(n_gslots - 1, msg_r, g_base);
        assert!(gi < all_x.len(), "g-groups must cover the R1 pad slots (sample_g_masks)");
    }
    drop(t_setup);
    let t_reveal = prof::timer(prof::CT_REVEAL);
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
    drop(t_reveal);

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
        prof::bump(prof::CT_ATTEMPTS);
        // Masks.
        let t_gauss = prof::timer(prof::CT_GAUSS);
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
        drop(t_gauss);
        // First messages: A1-side images.
        let t_w1 = prof::timer(prof::CT_W1);
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
        drop(t_w1);
        // Message-side mask images: per plain commitment A2 y; per digit
        // commitment the 2^(ej)-weighted digit-mask sum.
        let t_a2y = prof::timer(prof::CT_A2Y);
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
        drop(t_a2y);
        let t_wclaim = prof::timer(prof::CT_WCLAIM);
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
        // Quadratic garbage terms (pre-challenge; masks fresh per attempt),
        // R1-MASKED: heads carry Ga~/Gb~/G1~/W~/G0~ (the committed pads
        // added; twisted-side pads read pre-conjugated from their slots).
        let pad_slot = |k: usize| g_slot_of(k, msg_r, g_base);
        let mut gq = Vec::with_capacity(quad_claims.len());
        let mut w_quad = Vec::with_capacity(quad_claims.len());
        for (l, qc) in quad_claims.iter().enumerate() {
            let ga = quad_combo(ring, &qc.quad, &all_x, true, &a2y);
            let gb = quad_combo(ring, &qc.quad, &a2y, true, &all_x);
            let g0 = quad_combo(ring, &qc.quad, &a2y, true, &a2y);
            let (gi, gs) = g_slot_of(claims.len() + l, msg_r, g_base);
            let w = poly_add(zq, &coeff_combo(ring, &qc.msg_coeffs, &a2y), &a2y[gi][gs]);
            let (ai, av) = pad_slot(pb_qct + 3 * l);
            let (bi, bv) = pad_slot(pb_qct + 3 * l + 1);
            let (wi, wv) = pad_slot(pb_qct + 3 * l + 2);
            let g0m = poly_add(
                zq,
                &poly_add(zq, &g0, &poly_conj(zq, &a2y[ai][av])),
                &poly_add(zq, &a2y[bi][bv], &poly_conj(zq, &a2y[wi][wv])),
            );
            gq.push([
                poly_add(zq, &ga, &poly_conj(zq, &all_x[ai][av])),
                poly_add(zq, &gb, &all_x[bi][bv]),
                g0m,
            ]);
            w_quad.push(poly_add(zq, &w, &poly_conj(zq, &all_x[wi][wv])));
        }
        let mut gr = Vec::with_capacity(quad_ring.len());
        let mut w_qring = Vec::with_capacity(quad_ring.len());
        for (l, qr) in quad_ring.iter().enumerate() {
            let g1a = quad_combo(ring, &qr.quad, &all_x, false, &a2y);
            let g1b = quad_combo(ring, &qr.quad, &a2y, false, &all_x);
            let g1 = poly_add(zq, &g1a, &g1b);
            let g0 = quad_combo(ring, &qr.quad, &a2y, false, &a2y);
            let (i1, v1) = pad_slot(pb_qr + 2 * l);
            let (iw, vw) = pad_slot(pb_qr + 2 * l + 1);
            let g0m = poly_add(zq, &g0, &poly_add(zq, &a2y[i1][v1], &a2y[iw][vw]));
            gr.push([poly_add(zq, &g1, &all_x[i1][v1]), g0m]);
            w_qring.push(poly_add(zq, &coeff_combo(ring, &qr.msg_coeffs, &a2y), &all_x[iw][vw]));
        }
        let mut gtq = Vec::with_capacity(tq_claims.len());
        let mut w_tq = Vec::with_capacity(tq_claims.len());
        for (l, qc) in tq_claims.iter().enumerate() {
            let ga = quad_combo(ring, &qc.quad, &all_x, true, &a2y);
            let gb = quad_combo(ring, &qc.quad, &a2y, true, &all_x);
            let g0 = quad_combo(ring, &qc.quad, &a2y, true, &a2y);
            let (ai, av) = pad_slot(pb_tq + 3 * l);
            let (bi, bv) = pad_slot(pb_tq + 3 * l + 1);
            let (wi, wv) = pad_slot(pb_tq + 3 * l + 2);
            let g0m = poly_add(
                zq,
                &poly_add(zq, &g0, &poly_conj(zq, &a2y[ai][av])),
                &poly_add(zq, &a2y[bi][bv], &poly_conj(zq, &a2y[wi][wv])),
            );
            gtq.push([
                poly_add(zq, &ga, &poly_conj(zq, &all_x[ai][av])),
                poly_add(zq, &gb, &all_x[bi][bv]),
                g0m,
            ]);
            w_tq.push(poly_add(
                zq,
                &coeff_combo(ring, &qc.msg_coeffs, &a2y),
                &poly_conj(zq, &all_x[wi][wv]),
            ));
        }
        drop(t_wclaim);

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
            gtq,
            w_tq,
            z: Vec::new(),
            z_rho_ajtai: Vec::new(),
            z_s_ajtai: Vec::new(),
            t1_digits: t1_digits.clone(),
            w1_digits,
            z_digits: Vec::new(),
        };
        let c = {
            let _t = prof::timer(prof::CT_CHAL);
            ct_challenge(h0, &head)
        };

        let t_resp = prof::timer(prof::CT_RESP);
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
        // Joint-scaled rejection across the active bundles (Q4.2b, proven):
        // ONE test on the summed exponent replaces the per-bundle product —
        // same sigmas, same accepted distribution, ~3.7x fewer restarts at
        // three active bundles.
        let fz_s: Vec<i64> = z_s_ajtai.iter().flatten().flatten().copied().collect();
        let fv_s: Vec<i64> = centers_s_a.iter().flatten().flatten().copied().collect();
        let fz_d: Vec<i64> = z_digits.iter().flatten().flatten().flatten().copied().collect();
        let fv_d: Vec<i64> = centers_dig.iter().flatten().flatten().flatten().copied().collect();
        let mut parts: Vec<(&[i64], &[i64], u64)> = Vec::new();
        if !flat_z.is_empty() {
            parts.push((&flat_z, &flat_v, rp.sigma));
        }
        if rp.sigma_s > 0 && !fz_s.is_empty() {
            parts.push((&fz_s, &fv_s, rp.sigma_s));
        }
        if !digits.is_empty() {
            parts.push((&fz_d, &fv_d, dp.unwrap().sigma));
        }
        let accepted =
            super::joint_rejection_accept(rng, &parts, super::joint_log_m_alpha12(parts.len()));
        drop(parts);
        drop(t_resp);
        if accepted {
            let proof = CtRoundProof {
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
                gtq: head.gtq,
                w_tq: head.w_tq,
                z,
                z_rho_ajtai,
                z_s_ajtai,
                t1_digits: head.t1_digits,
                w1_digits: head.w1_digits,
                z_digits,
            };
            prof_digest_ct_proof(&proof); // [UPERF-PC] differential digest hook
            return (proof, attempts);
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
    verify_ct_round_tq(
        path, ring, rp, dp, crs, h0, claims, ring_claims, quad_claims, quad_ring, &[], t1s, t2s,
        t1s_dig, t2s_dig, ajtai_coms, g_base, proof,
    )
}

/// verify_ct_round with sigma-twisted ring-valued quadratic claims.
#[allow(clippy::too_many_arguments)]
pub fn verify_ct_round_tq(
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
    tq_claims: &[TwistedQuadRingClaim],
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
        || proof.gtq.len() != tq_claims.len()
        || proof.w_tq.len() != tq_claims.len()
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
    // Ring-valued claims: W_rl = ZA_rl - c C_rl + c K (claim value K,
    // zero for homogeneous claims; extraction divides by the invertible
    // challenge difference and pins sum coeff * x = K exactly).
    for (l, rc) in ring_claims.iter().enumerate() {
        let c_rl = ring_claim_combo(ring, rc, &t2_all);
        let za_rl = ring_claim_combo(ring, rc, &a2z);
        let cc = ring_mul_split_kara_fast(ring, &c_mod, &c_rl);
        let ck = ring_mul_split_kara_fast(ring, &c_mod, &rc.constant);
        if poly_add(zq, &poly_sub(zq, &za_rl, &cc), &ck) != proof.w_ring[l] {
            return false;
        }
    }
    // Quadratic layer. P table: P_i = c t2_i - (A2 z_i) = c x_i - Y_i.
    // R1: each quad check subtracts its committed-pad openings; the pads
    // MUST be covered by the g-slot space bound in h0 (R1.2).
    if !quad_claims.is_empty() || !quad_ring.is_empty() || !tq_claims.is_empty() {
        let (pb_qct, pb_qr, pb_tq) =
            r1_pad_base(claims.len(), quad_claims.len(), quad_ring.len());
        let n_gslots = pb_tq + 3 * tq_claims.len();
        {
            let (gi, _) = g_slot_of(n_gslots - 1, shape.msg_r, g_base);
            if gi >= t2s.len() {
                return false;
            }
        }
        let pad_slot = |k: usize| g_slot_of(k, shape.msg_r, g_base);
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
        // sigma-twisted ct-quadratics (R1-masked heads; the pad openings
        // conj(P_MA), P_MB, conj(P_MW) subtracted — zk_lemma_check OK-3a):
        //   sigma(c) c h = E + sigma(c) Ga~ + c Gb~ - G0~
        //               + sigma(c) (c C_L - ZA_L + W~)
        //               - conj(P_MA) - P_MB - conj(P_MW).
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
            let (ai, av) = pad_slot(pb_qct + 3 * l);
            let (bi, bv) = pad_slot(pb_qct + 3 * l + 1);
            let (wi, wv) = pad_slot(pb_qct + 3 * l + 2);
            rhs = poly_sub(zq, &rhs, &poly_conj(zq, &p_table[ai][av]));
            rhs = poly_sub(zq, &rhs, &p_table[bi][bv]);
            rhs = poly_sub(zq, &rhs, &poly_conj(zq, &p_table[wi][wv]));
            if lhs != rhs {
                return false;
            }
        }
        // Untwisted ring-valued quadratics (R1-masked; pads plain —
        // zk_lemma_check OK-3b):
        //   E2 + c G1~ - G0~ + c (c C_L - ZA_L + W~) - P_M1 - P_MW = 0.
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
            let (i1, v1) = pad_slot(pb_qr + 2 * l);
            let (iw, vw) = pad_slot(pb_qr + 2 * l + 1);
            lhs = poly_sub(zq, &lhs, &p_table[i1][v1]);
            lhs = poly_sub(zq, &lhs, &p_table[iw][vw]);
            if lhs.iter().any(|&x| x != 0) {
                return false;
            }
        }
        // Sigma-twisted ring-valued quadratics (no reveal; R1-masked):
        //   E + sigma(c) Ga~ + c Gb~ - G0~ + sigma(c)(c C_L - ZA_L + W~)
        //     - conj(P_MA) - P_MB - conj(P_MW) = 0.
        for (l, qc) in tq_claims.iter().enumerate() {
            let e = quad_combo(ring, &qc.quad, &p_table, true, &p_table);
            let c_l = coeff_combo(ring, &qc.msg_coeffs, &t2_all);
            let za_l = coeff_combo(ring, &qc.msg_coeffs, &a2z);
            let lin = {
                let ccl = ring_mul_split_kara_fast(ring, &c_mod, &c_l);
                let inner = poly_add(zq, &poly_sub(zq, &ccl, &za_l), &proof.w_tq[l]);
                ring_mul_split_kara_fast(ring, &sig_c, &inner)
            };
            let mut lhs = poly_add(zq, &e, &ring_mul_split_kara_fast(ring, &sig_c, &proof.gtq[l][0]));
            lhs = poly_add(zq, &lhs, &ring_mul_split_kara_fast(ring, &c_mod, &proof.gtq[l][1]));
            lhs = poly_sub(zq, &lhs, &proof.gtq[l][2]);
            lhs = poly_add(zq, &lhs, &lin);
            let (ai, av) = pad_slot(pb_tq + 3 * l);
            let (bi, bv) = pad_slot(pb_tq + 3 * l + 1);
            let (wi, wv) = pad_slot(pb_tq + 3 * l + 2);
            lhs = poly_sub(zq, &lhs, &poly_conj(zq, &p_table[ai][av]));
            lhs = poly_sub(zq, &lhs, &p_table[bi][bv]);
            lhs = poly_sub(zq, &lhs, &poly_conj(zq, &p_table[wi][wv]));
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
    /// The masking ratio sigma_arp = alpha * center_bundle; the rejection
    /// constants derive from it via `log_m_joint`.
    pub alpha: f64,
    /// Runtime center-norm gate (audit 2026-07-14 C-01, precondition gap):
    /// sigma_arp is derived from the CONCENTRATION-scale center bound
    /// (1.3 sqrt(n/2) w_inf per row), not from a checked bound on the
    /// actual ||R b||. arp_attempt / arp_attempt_joint reject any attempt
    /// whose actual projected-center bundle exceeds this l2^2 bound, so
    /// the density-ratio lemma's sigma = alpha * ||center|| regime is
    /// EXECUTABLE rather than assumed. A rejected attempt restarts with a
    /// fresh mask commitment, hence a fresh h0 and fresh JL rows.
    pub center_bound_sq: u128,
}

/// Rejection-lemma tail parameter for the ARP masking regime.
///
/// *** LEGACY, NOT ZK-GRADE (audit 2026-07-14 C-01). *** The rejection
/// test discards the region where the reveal's exponent exceeds the
/// t-tail; at the frozen t = 1.5 that clips Phi(-1.5) ~ 6.68e-2 ~
/// 2^-4.75 of the mass per unit (the repository's own Q4.2b lemma bounds
/// the defect only by 2 exp(-t^2/2) ~ 0.649 — neither is negligible).
/// The accepted distribution is therefore NOT within negligible
/// statistical distance of the center-independent Gaussian, and ARP-arm
/// transcripts are NOT statistical ZK. t = 1.5 is a REPRODUCIBILITY pin
/// (LKP-8/9 freeze the restart economics), not a security claim.
///
/// The demotion argument (why we do NOT retune t): a 128-bit statistical
/// target needs t >= 13.4 (2 exp(-t^2/2) <= 2^-128). At alpha = 3.5 that
/// drives log M_joint(4) = t*2/alpha + 4/(2 alpha^2) ~ 7.82, i.e. ~2.5e3
/// expected attempts per 4-unit q46 round versus ~2.8 today — a ~900x
/// prover blowup on every grounding round. Recovering the restart rate
/// by raising alpha instead is closed off by the extraction budget:
/// arp_budget_ok already FAILS the 512-bit unit at alpha = 5 (LKP-8
/// wall 2). No (t, alpha) point simultaneously gives negligible
/// clipping, a closing extraction budget and viable economics at q46 —
/// which is exactly why ARP is demoted to the legacy chain arm and the
/// exact range lookup (U-R2) is the target path.
const ARP_REJ_T: f64 = 1.5;

impl ArpParams {
    /// log M for a joint (Q4.2b) rejection test over k coupled units at
    /// this regime's alpha: t sqrt(k)/alpha + k/(2 alpha^2), t = ARP_REJ_T.
    /// k = 1 is the single-unit `rejection_accept` constant.
    pub fn log_m_joint(&self, k: usize) -> f64 {
        ARP_REJ_T * (k as f64).sqrt() / self.alpha
            + k as f64 / (2.0 * self.alpha * self.alpha)
    }
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
    // The executable form of the sigma-derivation assumption (C-01): the
    // actual ||R b|| over the bundle must stay within the concentration
    // bound sigma_arp was sized from.
    let center_bound_sq = (center_bundle * center_bundle).ceil() as u128;
    ArpParams { rows, n, sigma_arp, y_bound_sq, extract_bound, alpha, center_bound_sq }
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
pub fn sample_arp_mask(ap: &ArpParams, rng: &mut dyn super::RngSource) -> Vec<i64> {
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
    rng: &mut dyn super::RngSource,
) -> Option<Vec<i64>> {
    assert_eq!(jl.len(), ap.rows);
    let centers: Vec<i64> = jl
        .iter()
        .map(|row| row.iter().zip(b_coeffs.iter()).map(|(&r, &b)| r * b).sum())
        .collect();
    // Runtime center-norm gate (audit 2026-07-14 C-01): the density-ratio
    // formula below is only justified for centers within the bound
    // sigma_arp was derived from — enforce it on the ACTUAL ||R b||
    // instead of assuming concentration. Restarting draws a fresh mask
    // commitment -> fresh h0 -> fresh R, so honest witnesses pass with
    // overwhelming probability.
    if vec_norm_sq_i64(&centers) > ap.center_bound_sq {
        return None;
    }
    let y: Vec<i64> = m_flat.iter().zip(centers.iter()).map(|(&m, &c)| m + c).collect();
    if !rejection_accept(rng, &y, &centers, ap.sigma_arp, ap.log_m_joint(1)) {
        return None;
    }
    if vec_norm_sq_i64(&y) > ap.y_bound_sq {
        return None;
    }
    Some(y)
}

/// One joint reveal attempt over k restart-coupled units (Q4.2b): each
/// unit's y_u = R b_u + m_u, then ONE summed-exponent rejection test
/// replaces the per-unit product — same sigmas, same accepted output
/// distribution, restart rate e^-(t sqrt(k)/alpha + k/(2 alpha^2))
/// instead of the product's e^-k(t/alpha + 1/(2 alpha^2)). The per-unit
/// range gate (`y_bound_sq`, what the verifier re-checks via
/// `arp_check_reveal`) is unchanged. units = (b_coeffs, m_flat) pairs.
pub fn arp_attempt_joint(
    ap: &ArpParams,
    jl: &[Vec<i64>],
    units: &[(&[i64], &[i64])],
    rng: &mut dyn super::RngSource,
) -> Option<Vec<Vec<i64>>> {
    assert_eq!(jl.len(), ap.rows);
    let mut ys: Vec<Vec<i64>> = Vec::with_capacity(units.len());
    let mut centers_all: Vec<Vec<i64>> = Vec::with_capacity(units.len());
    for (b_coeffs, m_flat) in units {
        let centers: Vec<i64> = jl
            .iter()
            .map(|row| row.iter().zip(b_coeffs.iter()).map(|(&r, &b)| r * b).sum())
            .collect();
        // Per-unit runtime center-norm gate (audit 2026-07-14 C-01) —
        // same executable precondition as arp_attempt; the whole coupled
        // round restarts (fresh mask commitments -> fresh R).
        if vec_norm_sq_i64(&centers) > ap.center_bound_sq {
            return None;
        }
        let y: Vec<i64> = m_flat.iter().zip(centers.iter()).map(|(&m, &c)| m + c).collect();
        ys.push(y);
        centers_all.push(centers);
    }
    let parts: Vec<(&[i64], &[i64], u64)> = ys
        .iter()
        .zip(centers_all.iter())
        .map(|(y, c)| (y.as_slice(), c.as_slice(), ap.sigma_arp))
        .collect();
    if !super::joint_rejection_accept(rng, &parts, ap.log_m_joint(units.len())) {
        return None;
    }
    if ys.iter().any(|y| vec_norm_sq_i64(y) > ap.y_bound_sq) {
        return None;
    }
    Some(ys)
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

// ---------------------------------------------------------------------------
// U-R1 S0 (RANGE_AGGREGATION_DESIGN Section 2b): multi-wave partition of a
// commitment list and claim splitting across C2-capped ct-round waves. The
// binding requirement is upstream (every commitment enters the statement
// hash before any wave's challenges derive — the D-4 pattern); these
// helpers only partition and re-index.
//
// VERIFIER-SAFE (audit 2026-07-14 M-01): every helper below returns a
// typed `WaveError` on malformed input — out-of-range commitment
// indices/slots, inconsistent plans, oversized or overlapping
// co-location groups, straddling quads — instead of panicking. The
// splitter REJECTS Ajtai-bearing claims outright: partial scalars are
// computed from msg_coeffs only, so a split claim carrying Ajtai terms
// would silently drop that opening's contribution (Ajtai material is
// per-round, never multi-wave; the layer's claim families carry none).

/// Typed rejection from the wave-partition helpers (audit 2026-07-14
/// M-01): malformed external input surfaces as an error a verifier can
/// report — never a panic.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum WaveError {
    /// The wave cap is zero.
    ZeroCap,
    /// A co-location group is larger than the wave cap.
    GroupExceedsCap { group: usize, len: usize, cap: usize },
    /// A commitment index (group member or claim reference) is out of
    /// range for the plan.
    CommitIndexOutOfRange { index: usize, n_commits: usize },
    /// A commitment appears in two co-location groups.
    OverlappingGroups { index: usize },
    /// A message slot index is out of range for its commitment group.
    SlotOutOfRange { commit: usize, slot: usize },
    /// The plan's slot table is internally inconsistent (hand-built or
    /// stale plan; plan_waves never produces this).
    PlanInconsistent { index: usize },
    /// The splitter REJECTS claims carrying Ajtai coefficients (M-01):
    /// the share scalar is a msg_coeffs functional only, so an
    /// Ajtai-bearing claim cannot be split without silently dropping the
    /// Ajtai opening's contribution.
    AjtaiClaimUnsupported,
    /// A quadratic claim references no commitment at all.
    EmptyQuadClaim,
    /// A quadratic claim's commitments straddle waves (quads are never
    /// split — co-locate via plan_waves groups).
    QuadStraddlesWaves,
    /// The prover's reveal list does not match the derived share
    /// structure (count or wave labels).
    RevealShapeMismatch,
    /// A revealed partial is a non-centered representative or the
    /// partials do not sum to the claim total (the sum gate).
    PartialSumGate,
    /// Z1: the pad layout does not match the round's inputs — claim
    /// count vs layout, pad-table shape vs layout, a Padded call with
    /// no layout/pads, or an unbuildable layout (n_claims exceeds one
    /// commitment's coefficient space, pad waves not strictly
    /// ascending / out of plan range).
    PadLayoutMismatch,
    /// Z1: a padded claim has support in a wave outside the layout's
    /// pad-wave set (the plan-derived set must COVER every padded
    /// claim's touched waves — design Section 2.5's circularity rule).
    PadCoverage { wave: usize },
}

impl std::fmt::Display for WaveError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            WaveError::ZeroCap => write!(f, "wave cap must be positive"),
            WaveError::GroupExceedsCap { group, len, cap } => {
                write!(f, "co-location group {group} has {len} members, cap {cap}")
            }
            WaveError::CommitIndexOutOfRange { index, n_commits } => {
                write!(f, "commitment index {index} out of range ({n_commits} commitments)")
            }
            WaveError::OverlappingGroups { index } => {
                write!(f, "commitment {index} appears in two co-location groups")
            }
            WaveError::SlotOutOfRange { commit, slot } => {
                write!(f, "slot {slot} out of range for commitment {commit}")
            }
            WaveError::PlanInconsistent { index } => {
                write!(f, "wave plan slot table inconsistent at commitment {index}")
            }
            WaveError::AjtaiClaimUnsupported => {
                write!(f, "Ajtai-bearing claims are rejected by the multi-wave splitter")
            }
            WaveError::EmptyQuadClaim => write!(f, "quadratic claim references no commitment"),
            WaveError::QuadStraddlesWaves => {
                write!(f, "quadratic claim straddles waves (co-locate via plan_waves groups)")
            }
            WaveError::RevealShapeMismatch => {
                write!(f, "partial reveals do not match the derived share structure")
            }
            WaveError::PartialSumGate => {
                write!(f, "partial scalar fails the centered-representative/sum gate")
            }
            WaveError::PadLayoutMismatch => {
                write!(f, "wave-share pad layout inconsistent with the round's inputs")
            }
            WaveError::PadCoverage { wave } => {
                write!(f, "padded claim touches wave {wave} outside the pad-wave set")
            }
        }
    }
}

/// Reduce mod q and center into (-q/2, q/2].
fn center_i128(zq: &super::Zq, v: i128) -> i64 {
    let q = zq.q as i128;
    let mut r = v.rem_euclid(q);
    if r > q / 2 {
        r -= q;
    }
    r as i64
}

/// Centered ct (constant term) of a * b in Z_q[X]/(X^D + 1):
/// ct = a_0 b_0 - sum_{k>0} a_k b_{D-k}.
pub fn ct_mul_centered(zq: &super::Zq, a: &Poly, b: &Poly) -> i64 {
    let q = zq.q as i128;
    let mut acc: i128 = (a[0] as i128 * b[0] as i128) % q;
    for k in 1..D {
        acc -= (a[k] as i128 * b[D - k] as i128) % q;
    }
    center_i128(zq, acc)
}

/// Deterministic wave partition (U-R1 D-2): co-location groups (e.g. a
/// quadratic claim's operand + output commitments) are placed as whole
/// units, first-fit in index order. A pure function of its arguments, so
/// prover and verifier derive the same plan independently — nothing
/// prover-chosen enters the partition.
pub struct WavePlan {
    /// wave -> global commitment indices, in wave-local order.
    pub waves: Vec<Vec<usize>>,
    /// global commitment index -> (wave, wave-local index).
    pub slot_of: Vec<(usize, usize)>,
}

pub fn plan_waves(
    n_commits: usize,
    groups: &[Vec<usize>],
    cap: usize,
) -> Result<WavePlan, WaveError> {
    if cap == 0 {
        return Err(WaveError::ZeroCap);
    }
    let mut group_of = vec![usize::MAX; n_commits];
    for (g, members) in groups.iter().enumerate() {
        if members.len() > cap {
            return Err(WaveError::GroupExceedsCap { group: g, len: members.len(), cap });
        }
        for &i in members {
            if i >= n_commits {
                return Err(WaveError::CommitIndexOutOfRange { index: i, n_commits });
            }
            if group_of[i] != usize::MAX {
                return Err(WaveError::OverlappingGroups { index: i });
            }
            group_of[i] = g;
        }
    }
    let mut waves: Vec<Vec<usize>> = Vec::new();
    let mut placed = vec![false; n_commits];
    for i in 0..n_commits {
        if placed[i] {
            continue;
        }
        let unit: Vec<usize> =
            if group_of[i] != usize::MAX { groups[group_of[i]].clone() } else { vec![i] };
        let w = (0..waves.len())
            .find(|&w| waves[w].len() + unit.len() <= cap)
            .unwrap_or_else(|| {
                waves.push(Vec::new());
                waves.len() - 1
            });
        for &m in &unit {
            waves[w].push(m);
            placed[m] = true;
        }
    }
    let mut slot_of = vec![(usize::MAX, usize::MAX); n_commits];
    for (w, ws) in waves.iter().enumerate() {
        for (l, &g) in ws.iter().enumerate() {
            slot_of[g] = (w, l);
        }
    }
    Ok(WavePlan { waves, slot_of })
}

/// Bounds-checked plan lookup: commitment index in range AND its slot
/// entry consistent with the plan's wave table.
fn plan_slot(plan: &WavePlan, ci: usize) -> Result<(usize, usize), WaveError> {
    let n_commits = plan.slot_of.len();
    if ci >= n_commits {
        return Err(WaveError::CommitIndexOutOfRange { index: ci, n_commits });
    }
    let (w, l) = plan.slot_of[ci];
    if w >= plan.waves.len() || l >= plan.waves[w].len() || plan.waves[w][l] != ci {
        return Err(WaveError::PlanInconsistent { index: ci });
    }
    Ok((w, l))
}

/// The PUBLIC per-wave shares of a linear claim: msg_coeffs partitioned
/// by the plan, commitment indices re-based wave-locally, scalars left 0
/// for the caller to fill. Ajtai-bearing claims are REJECTED (audit
/// 2026-07-14 M-01): the share scalar is computed from msg_coeffs only,
/// so splitting a claim with Ajtai coefficients would silently drop that
/// opening's contribution. Ajtai material is per-round and never enters
/// the multi-wave splitter (the chain's q31 claim families carry none).
pub fn split_claim_shares(
    plan: &WavePlan,
    claim: &CtClaim,
) -> Result<Vec<(usize, CtClaim)>, WaveError> {
    if !claim.ajtai_coeffs.is_empty() {
        return Err(WaveError::AjtaiClaimUnsupported);
    }
    let mut by_wave: std::collections::BTreeMap<usize, CtClaim> = std::collections::BTreeMap::new();
    for (ci, s, p) in &claim.msg_coeffs {
        let (w, l) = plan_slot(plan, *ci)?;
        by_wave
            .entry(w)
            .or_insert_with(|| CtClaim { msg_coeffs: vec![], ajtai_coeffs: vec![], scalar: 0 })
            .msg_coeffs
            .push((l, *s, p.clone()));
    }
    Ok(by_wave.into_iter().collect())
}

/// Prover-side split (U-R1 D-1): per-wave claim lists plus, per original
/// claim, the (wave, partial ct) reveals. Partial scalars are computed
/// from the message openings (msgs[i] = commitment i's message polys);
/// their sum equals the claim's total by construction — the verifier
/// re-derives the shares from public weights and gates the sum.
pub fn split_claims_prover(
    zq: &super::Zq,
    plan: &WavePlan,
    claims: &[CtClaim],
    msgs: &[&[Poly]],
) -> Result<(Vec<Vec<CtClaim>>, Vec<Vec<(usize, i64)>>), WaveError> {
    let mut per_wave: Vec<Vec<CtClaim>> = (0..plan.waves.len()).map(|_| Vec::new()).collect();
    let mut reveals: Vec<Vec<(usize, i64)>> = Vec::with_capacity(claims.len());
    for claim in claims {
        let mut touched: Vec<(usize, i64)> = Vec::new();
        for (w, mut share) in split_claim_shares(plan, claim)? {
            let mut acc: i128 = 0;
            for (l, s, p) in &share.msg_coeffs {
                let gi = plan.waves[w][*l];
                let msg = msgs
                    .get(gi)
                    .ok_or(WaveError::CommitIndexOutOfRange { index: gi, n_commits: msgs.len() })?
                    .get(*s)
                    .ok_or(WaveError::SlotOutOfRange { commit: gi, slot: *s })?;
                acc += ct_mul_centered(zq, p, msg) as i128;
            }
            share.scalar = center_i128(zq, acc);
            touched.push((w, share.scalar));
            per_wave[w].push(share);
        }
        reveals.push(touched);
    }
    Ok((per_wave, reveals))
}

/// Verifier-side split: rebuilds the per-wave claims from the PUBLIC
/// weights and the prover's partial reveals, gating (a) share structure,
/// (b) centered representatives, and (c) sum(partials) == claim total
/// mod q. A typed error on any violation; per-wave ct-round verification
/// then holds each partial to its wave's committed material.
pub fn split_claims_verifier(
    zq: &super::Zq,
    plan: &WavePlan,
    claims: &[CtClaim],
    reveals: &[Vec<(usize, i64)>],
) -> Result<Vec<Vec<CtClaim>>, WaveError> {
    if reveals.len() != claims.len() {
        return Err(WaveError::RevealShapeMismatch);
    }
    let mut per_wave: Vec<Vec<CtClaim>> = (0..plan.waves.len()).map(|_| Vec::new()).collect();
    for (claim, rv) in claims.iter().zip(reveals.iter()) {
        let shares = split_claim_shares(plan, claim)?;
        if shares.len() != rv.len() {
            return Err(WaveError::RevealShapeMismatch);
        }
        let mut sum: i128 = 0;
        for ((w, mut share), &(rw, part)) in shares.into_iter().zip(rv.iter()) {
            if w != rw {
                return Err(WaveError::RevealShapeMismatch);
            }
            if part.unsigned_abs() > zq.q / 2 {
                return Err(WaveError::PartialSumGate);
            }
            share.scalar = part;
            sum += part as i128;
            per_wave[w].push(share);
        }
        if center_i128(zq, sum) != claim.scalar {
            return Err(WaveError::PartialSumGate);
        }
    }
    Ok(per_wave)
}

/// The single wave a quadratic ring claim lives in;
/// Err(QuadStraddlesWaves) if its operand/output commitments straddle
/// waves — quads are never split (U-R1 D-1); the caller co-locates them
/// via `plan_waves` groups. Every commitment index is bounds-checked.
pub fn quad_ring_wave(plan: &WavePlan, qc: &QuadRingClaim) -> Result<usize, WaveError> {
    let mut idxs: Vec<usize> = Vec::new();
    for (i, _, k, _, _) in &qc.quad {
        idxs.push(*i);
        idxs.push(*k);
    }
    for (i, _, _) in &qc.msg_coeffs {
        idxs.push(*i);
    }
    if idxs.is_empty() {
        return Err(WaveError::EmptyQuadClaim);
    }
    let (w0, _) = plan_slot(plan, idxs[0])?;
    for &i in &idxs[1..] {
        if plan_slot(plan, i)?.0 != w0 {
            return Err(WaveError::QuadStraddlesWaves);
        }
    }
    Ok(w0)
}

/// Wave-local re-indexing of a co-located quadratic claim.
pub fn quad_ring_localized(
    plan: &WavePlan,
    qc: &QuadRingClaim,
) -> Result<(usize, QuadRingClaim), WaveError> {
    let w = quad_ring_wave(plan, qc)?;
    let l = |ci: usize| plan.slot_of[ci].1;
    Ok((
        w,
        QuadRingClaim {
            quad: qc.quad.iter().map(|(i, j, k, m, p)| (l(*i), *j, l(*k), *m, p.clone())).collect(),
            msg_coeffs: qc.msg_coeffs.iter().map(|(i, s, p)| (l(*i), *s, p.clone())).collect(),
        },
    ))
}

// ---------------------------------------------------------------------------
// U-Z1 (WAVE_SHARE_MASKING_DESIGN.md, audit 2026-07-14 C-02): coset one-time
// pads on the per-wave shares. The unmasked splitter above reveals, per
// (claim, wave), the TRUE partial ct scalar — a public-coefficient linear
// measurement of that wave's private committed coefficients (design eq. 1,
// 9(W-1) fresh equations per proof beyond the totals, accumulating across
// proofs). The fix: per padded claim j and pad-bearing wave w, a uniform
// committed pad e_{j,w} with sum_w e_{j,w} = 0 (last pad SOLVED — the M4
// solved-pad pattern; a uniform masked share always has a centered
// representative, so there are NO degenerate draws and NO restart guards);
// the wave's rebuilt share claim gains ONE weight-1 read of the pad
// coefficient and its scalar becomes the masked reveal
//     functional_w(msgs) + e_{j,w} = sigma~_{j,w}          (design eq. 3)
// making the reveal vector EXACTLY uniform on the coset {sum = total}
// (design Section 3.1 — a finite one-time-pad statement). The zero-sum
// sum_w e_{j,w} = 0 is forced by the closing round (design eq. 4, Z1-impl-b).
//
// Layout discipline (design 2.2/2.5 + the psi-circularity rule): the pad
// LAYOUT is a pure function of the PUBLIC plan — pads exist for every
// (claim row j, pad wave w) position over the plan-derived pad-wave set,
// wave-major, n_claims per wave, whole pad-waves per commitment. Pad
// VALUES are drawn from the per-proof ProverRng stream and committed
// (bound in the statement hash) BEFORE any challenge; which positions are
// READ is derived symmetrically by prover and verifier from the claims.
// A claim touching <= 1 wave takes NO pad — its single share IS the
// public total (zero free exposures, Z1-i).
//
// Sharpening recorded against design Section 2.3 (found at implementation
// time): the closing round's zero-sum read set must EQUAL the set of pad
// positions the wave rounds read (all pad waves, per claim row). A closing
// read over a strict superset would leave the extra positions unbound by
// any wave relation, and a delta parked there forges a shifted total. The
// splitter therefore gives every multi-wave padded claim a share in EVERY
// pad wave (empty functional + pad read where the claim has no support),
// so wave reads == closing reads == the full pad-wave set, per row.

/// Splitter policy per claim family (design Section 2.4). The default for
/// value-carrying share families (the pins) is `Padded`; identically-zero
/// families (zeta slot-constancy) take `ForcedZero`; `Revealed` is the
/// as-built C-02 leak, retained ONLY for the permanent [Z1-a] baseline
/// exhibit and compiled away outside harness/test builds.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum SplitPolicy {
    /// Coset one-time pads: masked reveals sigma~ = functional + pad.
    Padded,
    /// Per-wave shares forced to the public constant 0; NOTHING is sent
    /// (the zeta deletion, design 2.4). Strictly stronger than the
    /// layer-wide sum gate it replaces.
    ForcedZero,
    /// LEGACY (C-02): true partial scalars in the clear. Kept
    /// compile-away for the [Z1-a] unmasked-leak regression only.
    #[cfg(any(test, feature = "harness"))]
    Revealed,
}

/// The public pad layout (design 2.2): wave-major, `n_claims` pads per
/// pad wave, `waves_per_cm = msg_r * D / n_claims` whole pad-waves per
/// pad commitment. Pure function of (claim-row count, plan-derived
/// pad-wave set, commitment shape) — prover and verifier derive it
/// independently and must agree byte-for-byte (`layout_bytes`, Z1-i).
///
/// Round-list convention: wave w's ct-round commitment list is
/// [wave's data commitments | the wave's pad commitment | g-groups],
/// so the pad commitment's wave-local index is the wave's data count
/// and `g_base` shifts by one. The verifier builds the same list from
/// the plan (D-2 — nothing prover-chosen enters the layout).
pub struct WavePadLayout {
    /// Padded claim rows (the pin batch: UR1_PIN_COPIES = 9).
    pub n_claims: usize,
    /// Ascending wave indices that carry pads (the plan-derived
    /// pin-bearing set; at the layer rig's lookup arms: every wave).
    pub pad_waves: Vec<usize>,
    /// Whole pad-waves packed per pad commitment (113 at 9/1024).
    pub waves_per_cm: usize,
    /// ceil(|pad_waves| / waves_per_cm); 0 when |pad_waves| <= 1 or
    /// n_claims == 0 (no pads — single-wave shares are public totals).
    pub n_pad_cms: usize,
}

impl WavePadLayout {
    /// Derive the layout. `pad_waves` must be strictly ascending and
    /// within the plan's wave range; `n_claims` must fit one
    /// commitment's coefficient space.
    pub fn derive(
        n_claims: usize,
        pad_waves: Vec<usize>,
        n_waves: usize,
        msg_r: usize,
    ) -> Result<Self, WaveError> {
        if n_claims > msg_r * D {
            return Err(WaveError::PadLayoutMismatch);
        }
        for (i, &w) in pad_waves.iter().enumerate() {
            if w >= n_waves || (i > 0 && pad_waves[i - 1] >= w) {
                return Err(WaveError::PadLayoutMismatch);
            }
        }
        let waves_per_cm = if n_claims == 0 { 0 } else { (msg_r * D) / n_claims };
        let n_pad_cms = if n_claims == 0 || pad_waves.len() <= 1 {
            0
        } else {
            pad_waves.len().div_ceil(waves_per_cm)
        };
        Ok(WavePadLayout { n_claims, pad_waves, waves_per_cm, n_pad_cms })
    }

    /// Whether the construction carries pads at all.
    pub fn has_pads(&self) -> bool {
        self.n_pad_cms > 0
    }

    /// (pad-commitment ordinal, message slot, coefficient index) of the
    /// pad for claim row j's share in pad-wave ordinal wi.
    pub fn slot(&self, j: usize, wi: usize) -> (usize, usize, usize) {
        debug_assert!(j < self.n_claims && wi < self.pad_waves.len());
        let cm = wi / self.waves_per_cm;
        let flat = (wi % self.waves_per_cm) * self.n_claims + j;
        (cm, flat / D, flat % D)
    }

    /// Canonical byte serialization of the COMPLETE layout — counts,
    /// pad-wave set, and every (claim, wave) -> (cm, slot, coeff)
    /// position. The Z1-i determinism leg compares prover- and
    /// verifier-derived layouts byte-for-byte.
    pub fn layout_bytes(&self) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend(b"z1-pad-layout-v1");
        for v in [self.n_claims, self.waves_per_cm, self.n_pad_cms, self.pad_waves.len()] {
            out.extend((v as u64).to_le_bytes());
        }
        for &w in &self.pad_waves {
            out.extend((w as u64).to_le_bytes());
        }
        if self.has_pads() {
            for j in 0..self.n_claims {
                for wi in 0..self.pad_waves.len() {
                    let (cm, s, c) = self.slot(j, wi);
                    out.extend((cm as u64).to_le_bytes());
                    out.extend((s as u64).to_le_bytes());
                    out.extend((c as u64).to_le_bytes());
                }
            }
        }
        out
    }
}

/// One proof's pad table — PRIVATE prover state until committed.
/// ONE-TIME by construction (design 2.5's freshness rule, battery Z1-h):
/// not `Clone`, drawn only from the per-proof RNG stream, and CONSUMED
/// by value by `split_claims_prover_masked` (the last honest reader), so
/// a second proof cannot reuse a pad table without deliberately
/// reconstructing it through the harness-only escape hatch.
pub struct WavePads {
    /// values[j][wi]: the mod-q pad of claim row j in pad-wave ordinal
    /// wi. Per row: uniform draws with the LAST entry solved so the row
    /// sums to 0 mod q.
    values: Vec<Vec<u64>>,
}

impl WavePads {
    /// Battery-only raw access ([Z1-b]/[Z1-g] rank harnesses).
    #[cfg(any(test, feature = "harness"))]
    pub fn harness_values(&self) -> &[Vec<u64>] {
        &self.values
    }

    /// Battery-only reconstruction — the [Z1-h] pad-REUSE attack arm.
    /// Production code cannot reach this: pads are drawn fresh per
    /// proof and moved into the splitter.
    #[cfg(any(test, feature = "harness"))]
    pub fn harness_from_values(values: Vec<Vec<u64>>) -> Self {
        WavePads { values }
    }
}

/// Draw one proof's pad table from the per-proof ProverRng stream
/// (design 2.1): per claim row, |pad_waves| - 1 uniform Z_q draws with
/// the last pad SOLVED (row sum = 0 mod q). NO restart guards — a
/// uniform masked share always has a centered representative. Layouts
/// without pads yield an empty table.
pub fn draw_wave_pads(
    rng: &mut dyn super::RngSource,
    q: u64,
    layout: &WavePadLayout,
) -> WavePads {
    if !layout.has_pads() {
        return WavePads { values: vec![Vec::new(); layout.n_claims] };
    }
    let k = layout.pad_waves.len();
    let values = (0..layout.n_claims)
        .map(|_| {
            let mut row: Vec<u64> = (0..k - 1).map(|_| super::rng_below(rng, q)).collect();
            let sum = row.iter().fold(0u64, |a, &v| {
                let s = a as u128 + v as u128;
                (s % q as u128) as u64
            });
            row.push((q - sum) % q); // the solved last pad
            row
        })
        .collect();
    WavePads { values }
}

/// Pack the pad table into pad-commitment message groups (the wave-major
/// layout). Coefficients not addressed by the layout are FRESH UNIFORM
/// draws — they are never read by any claim and carry no structure.
pub fn pack_wave_pads(
    rng: &mut dyn super::RngSource,
    q: u64,
    msg_r: usize,
    layout: &WavePadLayout,
    pads: &WavePads,
) -> Result<Vec<Vec<Poly>>, WaveError> {
    if pads.values.len() != layout.n_claims {
        return Err(WaveError::PadLayoutMismatch);
    }
    let mut cms: Vec<Vec<Poly>> = (0..layout.n_pad_cms)
        .map(|_| {
            (0..msg_r)
                .map(|_| (0..D).map(|_| super::rng_below(rng, q)).collect())
                .collect()
        })
        .collect();
    if layout.has_pads() {
        for (j, row) in pads.values.iter().enumerate() {
            if row.len() != layout.pad_waves.len() {
                return Err(WaveError::PadLayoutMismatch);
            }
            for (wi, &v) in row.iter().enumerate() {
                let (cm, s, c) = layout.slot(j, wi);
                cms[cm][s][c] = v;
            }
        }
    }
    Ok(cms)
}

/// The weight-1 pad read term of claim row j's share in pad-wave ordinal
/// wi: (wave-local pad-commitment index, slot, conj(X^coeff)) — the
/// coefficient-extraction functional (ct(conj(X^i) * m) = m_i). The
/// wave-local index follows the round-list convention (the wave's data
/// count — see WavePadLayout).
fn pad_read_term(
    zq: &super::Zq,
    plan: &WavePlan,
    layout: &WavePadLayout,
    j: usize,
    wi: usize,
) -> (usize, usize, Poly) {
    let w = layout.pad_waves[wi];
    let (_, s, c) = layout.slot(j, wi);
    let mut xi = poly_zero();
    xi[c] = 1;
    (plan.waves[w].len(), s, poly_conj(zq, &xi))
}

/// Shared prover/verifier share-structure walk for the Padded policy:
/// per claim, the plan-split support shares keyed by wave, the touched
/// count, and the coverage check (support must sit inside the pad-wave
/// set). Returns (touched wave count, support map).
fn padded_support(
    plan: &WavePlan,
    layout: &WavePadLayout,
    claim: &CtClaim,
) -> Result<(usize, std::collections::BTreeMap<usize, CtClaim>), WaveError> {
    let shares = split_claim_shares(plan, claim)?;
    let touched = shares.len();
    if touched >= 2 {
        // FAIL-CLOSED: a multi-wave claim under the Padded policy MUST
        // be coverable by pads — a layout without pads (or one missing
        // a touched wave) errors rather than silently reverting to the
        // C-02 revealed partials.
        for (w, _) in &shares {
            if !layout.has_pads() || !layout.pad_waves.contains(w) {
                return Err(WaveError::PadCoverage { wave: *w });
            }
        }
    }
    Ok((touched, shares.into_iter().collect()))
}

/// Prover-side MASKED split (design 2.1/2.3): per claim row j with >= 2
/// touched waves, one share in EVERY pad wave — the wave's support
/// functional (possibly empty) plus the weight-1 pad read — revealing
/// sigma~ = center(functional + pad). Claims touching <= 1 wave take the
/// unpadded single-share path (share == public total, NO reveal entry).
/// CONSUMES the pad table (one-time freshness, Z1-h).
pub fn split_claims_prover_masked(
    zq: &super::Zq,
    plan: &WavePlan,
    claims: &[CtClaim],
    msgs: &[&[Poly]],
    layout: &WavePadLayout,
    pads: WavePads,
) -> Result<(Vec<Vec<CtClaim>>, Vec<Vec<(usize, i64)>>), WaveError> {
    let _t = prof::timer(prof::CT_SPLIT); // [UPERF-PC] observation only
    if claims.len() != layout.n_claims || pads.values.len() != layout.n_claims {
        return Err(WaveError::PadLayoutMismatch);
    }
    let share_scalar = |share: &CtClaim, w: usize| -> Result<i128, WaveError> {
        let mut acc: i128 = 0;
        for (l, s, p) in &share.msg_coeffs {
            let gi = plan.waves[w][*l];
            let msg = msgs
                .get(gi)
                .ok_or(WaveError::CommitIndexOutOfRange { index: gi, n_commits: msgs.len() })?
                .get(*s)
                .ok_or(WaveError::SlotOutOfRange { commit: gi, slot: *s })?;
            acc += ct_mul_centered(zq, p, msg) as i128;
        }
        Ok(acc)
    };
    let mut per_wave: Vec<Vec<CtClaim>> = (0..plan.waves.len()).map(|_| Vec::new()).collect();
    let mut reveals: Vec<Vec<(usize, i64)>> = Vec::with_capacity(claims.len());
    for (j, claim) in claims.iter().enumerate() {
        let (touched, mut support) = padded_support(plan, layout, claim)?;
        if touched <= 1 || !layout.has_pads() {
            // Zero free exposures: the single share IS the public total
            // (Z1-i) — no pad spent, nothing revealed beyond the claim.
            let mut rv = Vec::new();
            for (w, mut share) in support {
                share.scalar = center_i128(zq, share_scalar(&share, w)?);
                rv.push((w, share.scalar));
                per_wave[w].push(share);
            }
            reveals.push(rv);
            continue;
        }
        let mut rv = Vec::with_capacity(layout.pad_waves.len());
        for wi in 0..layout.pad_waves.len() {
            let w = layout.pad_waves[wi];
            let mut share = support.remove(&w).unwrap_or(CtClaim {
                msg_coeffs: vec![],
                ajtai_coeffs: vec![],
                scalar: 0,
            });
            let sigma = share_scalar(&share, w)?;
            share.msg_coeffs.push(pad_read_term(zq, plan, layout, j, wi));
            share.scalar = center_i128(zq, sigma + pads.values[j][wi] as i128);
            rv.push((w, share.scalar));
            per_wave[w].push(share);
        }
        reveals.push(rv);
    }
    if prof::digest_on() {
        // [UPERF-PC] differential digest: the masked reveal wires.
        let flat: Vec<i64> = reveals
            .iter()
            .flat_map(|rv| rv.iter().flat_map(|&(w, s)| [w as i64, s]))
            .collect();
        prof::digest_i64s("split-reveals", &flat);
    }
    Ok((per_wave, reveals))
}

/// Verifier-side MASKED split: rebuilds every share claim — support
/// functionals from public weights PLUS the plan-derived pad read — from
/// the prover's masked reveals, gating (a) reveal structure against the
/// derived layout, (b) centered representatives, (c) the mod-q sum gate
/// sum(sigma~) == total (pads cancel by the closing round's zero-sum).
/// Per-wave ct-round verification then holds each masked share to the
/// wave's committed data + pad material.
pub fn split_claims_verifier_masked(
    zq: &super::Zq,
    plan: &WavePlan,
    claims: &[CtClaim],
    reveals: &[Vec<(usize, i64)>],
    layout: &WavePadLayout,
) -> Result<Vec<Vec<CtClaim>>, WaveError> {
    if claims.len() != layout.n_claims || reveals.len() != claims.len() {
        return Err(WaveError::RevealShapeMismatch);
    }
    let mut per_wave: Vec<Vec<CtClaim>> = (0..plan.waves.len()).map(|_| Vec::new()).collect();
    for (j, (claim, rv)) in claims.iter().zip(reveals.iter()).enumerate() {
        let (touched, mut support) = padded_support(plan, layout, claim)?;
        if touched <= 1 || !layout.has_pads() {
            // Unpadded single-share path: the reveal must restate the
            // share the verifier derives itself (the share is public).
            if rv.len() != touched {
                return Err(WaveError::RevealShapeMismatch);
            }
            let mut sum: i128 = 0;
            for ((w, mut share), &(rw, part)) in support.into_iter().zip(rv.iter()) {
                if w != rw {
                    return Err(WaveError::RevealShapeMismatch);
                }
                if part.unsigned_abs() > zq.q / 2 {
                    return Err(WaveError::PartialSumGate);
                }
                share.scalar = part;
                sum += part as i128;
                per_wave[w].push(share);
            }
            if center_i128(zq, sum) != claim.scalar {
                return Err(WaveError::PartialSumGate);
            }
            continue;
        }
        if rv.len() != layout.pad_waves.len() {
            return Err(WaveError::RevealShapeMismatch);
        }
        let mut sum: i128 = 0;
        for (wi, &(rw, part)) in rv.iter().enumerate() {
            let w = layout.pad_waves[wi];
            if w != rw {
                return Err(WaveError::RevealShapeMismatch);
            }
            if part.unsigned_abs() > zq.q / 2 {
                return Err(WaveError::PartialSumGate);
            }
            let mut share = support.remove(&w).unwrap_or(CtClaim {
                msg_coeffs: vec![],
                ajtai_coeffs: vec![],
                scalar: 0,
            });
            share.msg_coeffs.push(pad_read_term(zq, plan, layout, j, wi));
            share.scalar = part;
            sum += part as i128;
            per_wave[w].push(share);
        }
        if center_i128(zq, sum) != claim.scalar {
            return Err(WaveError::PartialSumGate);
        }
    }
    Ok(per_wave)
}

/// The ForcedZero split (the zeta deletion, design 2.4): per-wave share
/// claims with the public scalar 0 and NO reveal wire — identical on
/// both sides. Claims must carry a zero total (identity 2: every honest
/// share of the slot-constancy family is identically zero); a nonzero
/// total is a caller error, surfaced as the sum gate.
pub fn split_claims_forced_zero(
    plan: &WavePlan,
    claims: &[CtClaim],
) -> Result<Vec<Vec<CtClaim>>, WaveError> {
    let mut per_wave: Vec<Vec<CtClaim>> = (0..plan.waves.len()).map(|_| Vec::new()).collect();
    for claim in claims {
        if claim.scalar != 0 {
            return Err(WaveError::PartialSumGate);
        }
        for (w, mut share) in split_claim_shares(plan, claim)? {
            share.scalar = 0;
            per_wave[w].push(share);
        }
    }
    Ok(per_wave)
}

/// Policy dispatch, prover side (the Z1 splitter entry point). `Padded`
/// requires the layout and consumes the pad table; `ForcedZero` reveals
/// nothing; `Revealed` (harness/test builds only) is the legacy C-02
/// path for the permanent [Z1-a] baseline exhibit.
pub fn split_claims_prover_policy(
    zq: &super::Zq,
    plan: &WavePlan,
    claims: &[CtClaim],
    msgs: &[&[Poly]],
    policy: SplitPolicy,
    layout: Option<&WavePadLayout>,
    pads: Option<WavePads>,
) -> Result<(Vec<Vec<CtClaim>>, Vec<Vec<(usize, i64)>>), WaveError> {
    match policy {
        SplitPolicy::Padded => {
            let layout = layout.ok_or(WaveError::PadLayoutMismatch)?;
            let pads = pads.ok_or(WaveError::PadLayoutMismatch)?;
            split_claims_prover_masked(zq, plan, claims, msgs, layout, pads)
        }
        SplitPolicy::ForcedZero => {
            Ok((split_claims_forced_zero(plan, claims)?, vec![Vec::new(); claims.len()]))
        }
        #[cfg(any(test, feature = "harness"))]
        SplitPolicy::Revealed => split_claims_prover(zq, plan, claims, msgs),
    }
}

/// The closing round's exact zero-sum claims (design eq. 4, Z1-impl-b):
/// for each padded claim row j, ONE linear ct-claim reading — with
/// weight 1 — EXACTLY the pad positions the wave rounds read (row j
/// across ALL pad waves) with the public zero scalar. No psi
/// compression: these are exact single claims, so no new 2^-31-per-copy
/// edge opens; each consumes one g-slot of the closing round.
///
/// Read-set discipline (the Section 2.3 sharpening recorded in the
/// module header above): the zero-sum read set EQUALS the wave rounds'
/// pad-read set per row. Commitment index convention for the closing
/// round's list: pad commitment k at local index k (0..n_pad_cms),
/// g-groups from n_pad_cms.
pub fn closing_round_claims(zq: &super::Zq, layout: &WavePadLayout) -> Vec<CtClaim> {
    if !layout.has_pads() {
        return Vec::new();
    }
    (0..layout.n_claims)
        .map(|j| {
            // Indicator chunks per (cm, slot), conjugated once per chunk:
            // ct(conj(sum_i X^i) * m) = sum_i m_i over the read set.
            let mut chunks: std::collections::BTreeMap<(usize, usize), Poly> =
                std::collections::BTreeMap::new();
            for wi in 0..layout.pad_waves.len() {
                let (cm, s, c) = layout.slot(j, wi);
                chunks.entry((cm, s)).or_insert_with(poly_zero)[c] = 1;
            }
            let msg_coeffs = chunks
                .into_iter()
                .map(|((cm, s), ind)| (cm, s, poly_conj(zq, &ind)))
                .collect();
            CtClaim { msg_coeffs, ajtai_coeffs: vec![], scalar: 0 }
        })
        .collect()
}

// ---------------------------------------------------------------------------
// [UPERF-PC] Phase profiling + differential-digest instrumentation (U-PERF
// lane PC). Counters are process-global atomics, OFF by default; when off,
// the only cost on any hot path is one relaxed bool load. NOTHING here
// touches a transcript, an rng stream, or a hash: timers observe, the
// digest accumulator hashes bytes the protocol already produced (enabled
// only by the uperf-pc harness for the differential gate). Consumers:
// the [UPERF-PC] bench arm in ring_matmul.rs.

pub mod prof {
    use sha2::{Digest, Sha256};
    use std::sync::Mutex;
    use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
    use std::time::Instant;

    pub const CT_SETUP: usize = 0; // prove_ct_round entry: all_x clone + digit decomp
    pub const CT_REVEAL: usize = 1; // reveals h / h_quad
    pub const CT_GAUSS: usize = 2; // per-attempt Gaussian mask sampling
    pub const CT_W1: usize = 3; // per-attempt A1-side mask images
    pub const CT_A2Y: usize = 4; // per-attempt A2-side mask images
    pub const CT_WCLAIM: usize = 5; // per-attempt claim/ring/quad mask combos
    pub const CT_CHAL: usize = 6; // per-attempt challenge hash
    pub const CT_RESP: usize = 7; // per-attempt centers + z + norms + rejection
    pub const CT_TOTAL: usize = 8; // prove_ct_round total
    pub const CT_H0: usize = 9; // ct_h0 statement hashing
    pub const CT_SPLIT: usize = 10; // masked splitter (prover side)
    pub const EP_CRS: usize = 11; // expand_level_matrix (XOF expansion, cache miss)
    pub const EP_MATVEC: usize = 12; // matvec_modq_small
    pub const EP_IP: usize = 13; // ring_ip_modq_small
    pub const EP_PSI: usize = 14; // compute_psi
    pub const EP_TRANSPORT: usize = 15; // transport_level_from_psi
    pub const EP_PSI0F: usize = 16; // psi_level0_factored[_multi]
    pub const CT_ATTEMPTS: usize = 17; // rejection-loop attempts (count only)
    pub const EP_LEVELH: usize = 18; // level_h_pairs (h cross-garbage)
    pub const EP_CRS_HIT: usize = 19; // expand_level_matrix cache hits (count only)
    pub const BG_KROWS: usize = 20; // bg_kernel_pass rows pass (claim rows b_rows)
    pub const BG_KPHI: usize = 21; // bg_kernel_pass phi pass (aggregated functional)
    pub const BG_FOLD: usize = 22; // bg_fold / agg_fold (quinary fold + digit split)
    pub const BG_MATVEC_CHUNKS: usize = 23; // bg_matvec_chunks (A x w_j for all j + digit split)
    pub const BG_LEVELH: usize = 24; // bg_level_h / agg_level_h wall (incl. digit split of h)
    pub const BG_PROVE_GROUP: usize = 25; // bg_prove_group total (per group)
    pub const BG_VERIFY_GROUP: usize = 26; // bg_verify_group total (per group)
    pub const BG_COMMIT: usize = 27; // bg/bk pass: the commit phase (chains, digits, u_0s, statement)
    pub const BG_CLAIM_LAYER: usize = 28; // bg/bk pass: prover claim layer (ixf sumchecks + assemblies)
    pub const BK_TREES: usize = 29; // bk descent phase: witness/table tree builds
    pub const BK_GKR: usize = 30; // bk descent phase: masked_gkr_prove calls
    // [UPERF2-A] descent internals (observation only; gkr/gkr_masked/kfield)
    pub const A_TREE_PACK: usize = 31; // build_tree: boxed leaves -> packed leaf tables
    pub const A_TREE_STEP: usize = 32; // build_tree_packed: the layer steps
    pub const A_EQ_TABLE: usize = 33; // kt_eq_table per descent layer
    pub const A_EXTRACT: usize = 34; // extract_children + the lambda*q0 (or PL) table
    pub const A_ROUND_G: usize = 35; // the bulk round-poly kernel (all rounds)
    pub const A_FOLD: usize = 36; // the per-round table folds (all tables)
    pub const A_SCALAR_TAIL: usize = 37; // sub-block scalar rounds + w-round
    pub const A_GKR_PROVE: usize = 38; // masked_gkr_prove total
    pub const A_GKR_VERIFY: usize = 39; // masked_gkr_verify total
    // [UPERF2-E] descent callers / descent verify / small-cols aux (observation only)
    pub const E_TREE_SLOTS: usize = 40; // bk_tree_slots: member column materialization (prover)
    pub const E_TREE_WIT: usize = 41; // aligned_witness_tree + neutral pads (prover)
    pub const E_TREE_TAB: usize = 42; // table trees: m_k + blinded_table_tree + pads (prover)
    pub const E_VERIFY_SHELLS: usize = 43; // verifier: zero_masks shells per pair
    pub const E_VERIFY_CROSS: usize = 44; // verifier: root cross-checks per pair
    pub const E_CLAIMS_MASK: usize = 45; // bk_pair_claims: mask-opening claims (both sides)
    pub const E_CLAIMS_WIT: usize = 46; // bk_pair_claims: witness-side publics (eq tables, prefixes, blinder rows)
    pub const E_CLAIMS_TAB: usize = 47; // bk_pair_claims: table-side publics
    pub const E_KPASS_SMALL: usize = 48; // kernel_pass_factored: misaligned (small-cols) tensors, both passes
    pub const E_PSI0_SMALL: usize = 49; // psi_level0_factored_multi: misaligned (small-cols) tensors
    pub const N_PHASES: usize = 50;

    pub const NAMES: [&str; N_PHASES] = [
        "ct.setup(clone+digits)",
        "ct.reveals",
        "ct.mask-sampling",
        "ct.a1-matvec(w1)",
        "ct.a2-matvec(a2y)",
        "ct.claim-combos",
        "ct.challenge-hash",
        "ct.centers+z+reject",
        "ct.prove-total",
        "ct.h0-hash",
        "ct.masked-splitter",
        "ep.crs-expand",
        "ep.matvec",
        "ep.ring-ip",
        "ep.compute-psi",
        "ep.transport",
        "ep.psi0-factored",
        "ct.attempts",
        "ep.level-h-pairs",
        "ep.crs-cache-hit",
        "bg.kernel-rows",
        "bg.kernel-phi",
        "bg.fold",
        "bg.matvec-chunks",
        "bg.level-h",
        "bg.prove-group",
        "bg.verify-group",
        "bg.commit-phase",
        "bg.claim-layer",
        "bk.descent-trees",
        "bk.descent-gkr",
        "a.tree-pack",
        "a.tree-step",
        "a.eq-table",
        "a.extract",
        "a.round-g",
        "a.fold",
        "a.scalar-tail",
        "a.gkr-prove",
        "a.gkr-verify",
        "e.tree-slots",
        "e.tree-witness",
        "e.tree-table",
        "e.verify-shells",
        "e.verify-cross",
        "e.claims-mask",
        "e.claims-witness",
        "e.claims-table",
        "e.kpass-smallcols",
        "e.psi0-smallcols",
    ];

    static ENABLED: AtomicBool = AtomicBool::new(false);
    static DIGEST_ON: AtomicBool = AtomicBool::new(false);
    static NS: [AtomicU64; N_PHASES] = [const { AtomicU64::new(0) }; N_PHASES];
    static CALLS: [AtomicU64; N_PHASES] = [const { AtomicU64::new(0) }; N_PHASES];
    static DIGEST: Mutex<Option<Sha256>> = Mutex::new(None);

    /// Turn phase timing / the differential digest on or off.
    pub fn enable(profile: bool, digest: bool) {
        ENABLED.store(profile, Ordering::Relaxed);
        DIGEST_ON.store(digest, Ordering::Relaxed);
        if digest {
            *DIGEST.lock().unwrap() = Some(Sha256::new_with_prefix(b"uperf-pc-diff-v1"));
        }
    }

    #[inline(always)]
    pub fn on() -> bool {
        ENABLED.load(Ordering::Relaxed)
    }

    /// Scope guard: times its lifetime into `phase` (and bumps the call
    /// count) when profiling is on; a no-op otherwise.
    pub struct Timer {
        phase: usize,
        start: Option<Instant>,
    }

    #[inline(always)]
    pub fn timer(phase: usize) -> Timer {
        if on() {
            CALLS[phase].fetch_add(1, Ordering::Relaxed);
            Timer { phase, start: Some(Instant::now()) }
        } else {
            Timer { phase, start: None }
        }
    }

    impl Drop for Timer {
        fn drop(&mut self) {
            if let Some(t0) = self.start {
                NS[self.phase].fetch_add(t0.elapsed().as_nanos() as u64, Ordering::Relaxed);
            }
        }
    }

    /// Count-only bump (attempts, cache hits).
    #[inline(always)]
    pub fn bump(phase: usize) {
        if on() {
            CALLS[phase].fetch_add(1, Ordering::Relaxed);
        }
    }

    pub fn reset() {
        for i in 0..N_PHASES {
            NS[i].store(0, Ordering::Relaxed);
            CALLS[i].store(0, Ordering::Relaxed);
        }
    }

    /// (name, seconds, calls) per phase, in phase order.
    pub fn report() -> Vec<(&'static str, f64, u64)> {
        (0..N_PHASES)
            .map(|i| {
                (
                    NAMES[i],
                    NS[i].load(Ordering::Relaxed) as f64 / 1e9,
                    CALLS[i].load(Ordering::Relaxed),
                )
            })
            .collect()
    }

    #[inline(always)]
    pub fn digest_on() -> bool {
        DIGEST_ON.load(Ordering::Relaxed)
    }

    /// Absorb labeled bytes into the differential digest (when enabled).
    pub fn digest_absorb(label: &str, bytes: &[u8]) {
        if !digest_on() {
            return;
        }
        let mut g = DIGEST.lock().unwrap();
        if let Some(h) = g.as_mut() {
            h.update((label.len() as u64).to_le_bytes());
            h.update(label.as_bytes());
            h.update((bytes.len() as u64).to_le_bytes());
            h.update(bytes);
        }
    }

    /// Absorb an i64 slice (le bytes) into the differential digest.
    pub fn digest_i64s(label: &str, v: &[i64]) {
        if !digest_on() {
            return;
        }
        let mut out = Vec::with_capacity(v.len() * 8);
        for &x in v {
            out.extend_from_slice(&x.to_le_bytes());
        }
        digest_absorb(label, &out);
    }

    /// Take the accumulated differential digest (resets the accumulator).
    pub fn digest_take() -> Option<[u8; 32]> {
        let mut g = DIGEST.lock().unwrap();
        g.take().map(|h| h.finalize().into())
    }
}

/// [UPERF-PC] Absorb a full CtRoundProof into the differential digest —
/// every wire field in declaration order (attempts are not wire and are
/// pinned indirectly: z depends on the accepted attempt's masks).
pub fn prof_digest_ct_proof(proof: &CtRoundProof) {
    if !prof::digest_on() {
        return;
    }
    let pb = |label: &str, polys: &[Poly]| prof::digest_absorb(label, &polys_bytes(polys));
    pb("h", &proof.h);
    for w in &proof.w1 {
        pb("w1", w);
    }
    for w in &proof.w1_ajtai {
        pb("w1a", w);
    }
    pb("w_claim", &proof.w_claim);
    pb("w_ring", &proof.w_ring);
    pb("h_quad", &proof.h_quad);
    for g in &proof.gq {
        pb("gq", g.as_slice());
    }
    pb("w_quad", &proof.w_quad);
    for g in &proof.gr {
        pb("gr", g.as_slice());
    }
    pb("w_qring", &proof.w_qring);
    for g in &proof.gtq {
        pb("gtq", g.as_slice());
    }
    pb("w_tq", &proof.w_tq);
    for zi in &proof.z {
        for zn in zi {
            prof::digest_i64s("z", zn);
        }
    }
    for zi in &proof.z_rho_ajtai {
        for zn in zi {
            prof::digest_i64s("zra", zn);
        }
    }
    for zi in &proof.z_s_ajtai {
        for zn in zi {
            prof::digest_i64s("zsa", zn);
        }
    }
    for td in &proof.t1_digits {
        for t in td {
            pb("t1d", t);
        }
    }
    for wd in &proof.w1_digits {
        for w in wd {
            pb("w1d", w);
        }
    }
    for zd in &proof.z_digits {
        for zj in zd {
            for zn in zj {
                prof::digest_i64s("zd", zn);
            }
        }
    }
}

/// Policy dispatch, verifier side.
pub fn split_claims_verifier_policy(
    zq: &super::Zq,
    plan: &WavePlan,
    claims: &[CtClaim],
    reveals: &[Vec<(usize, i64)>],
    policy: SplitPolicy,
    layout: Option<&WavePadLayout>,
) -> Result<Vec<Vec<CtClaim>>, WaveError> {
    match policy {
        SplitPolicy::Padded => {
            let layout = layout.ok_or(WaveError::PadLayoutMismatch)?;
            split_claims_verifier_masked(zq, plan, claims, reveals, layout)
        }
        SplitPolicy::ForcedZero => {
            if reveals.iter().any(|rv| !rv.is_empty()) {
                return Err(WaveError::RevealShapeMismatch);
            }
            split_claims_forced_zero(plan, claims)
        }
        #[cfg(any(test, feature = "harness"))]
        SplitPolicy::Revealed => split_claims_verifier(zq, plan, claims, reveals),
    }
}

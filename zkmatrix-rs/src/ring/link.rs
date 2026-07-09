// Route R modulus link (U-L1): the F3 resolution, option (a) of
// docs/zkmatrix-poc/GADGET_MODULUS_DECISION.md Section 3 — bit tensors
// committed at a dedicated q8_46 gadget layer, value tensors at q8_31,
// tied by l FS-derived structured-weight rows whose revealed integer
// scalars y_l are asserted by one linear ct-claim on EACH side:
//
//   q46 side (grounding): weight on bit (i, t) is xi_(l,t) * 2^i — the
//     structured 2^i weights ARE the recomposition; no recomposition
//     claim runs at q31 at all.
//   q31 side (target):    weight on value t is xi_(l,t).
//
// Soundness shape (Section 3.2; mechanics machine-checked standalone in
// bin/gadget_link_spike.rs): the q46 side is integer-exact under the
// w_max rule n * 2^(w-1) * (2^W - 1) < q46/2 plus the range gate
// |y_l| < q46/2 (the GROUNDING side's q/2 ONLY — Section 3.3: a
// symmetric q31/2 gate is a completeness break at the frozen w, not a
// hardening); the q31 side then forces V31 = V46 (mod q31) unless a row
// catches the nonzero difference: per-row miss <= 2^-w for signed
// uniform w-bit weights over prime q31, l = ceil(256 / w) independent
// rows. Frozen operating point (full-tensor granularity): w = 11,
// l = 24 -> 2^-264.
//
// Hash ordering: the xi rows derive from h0_link, which binds BOTH CRS
// hashes and BOTH sides' commitment groups (values, bit planes, and the
// g-mask commitments of both sides) — the engine's g-before-challenge
// rule applied across moduli. Each side's ct-round then uses
// ct_h0(crs_side, h0_link, ...) so the round hash binds h0_link plus
// that side's commitments (including the ARP mask commitment on the
// q46 side, whose JL rows derive from the round hash as usual).
//
// The shared LINK interface with the trace gate's Q-A4 is Section 3.5:
// this module is the gnd = binary-proof instantiation (map = 2^i
// recomposition); the weight/row/gate helpers are generic in (q_gnd,
// q_tgt, w, l).
//
// What this module does NOT rely on (Q4_LEMMAS.md Q4.4): the link's own
// soundness is mod-q ct-algebra plus the per-row point-mass bound — it
// does not touch SLACK_OP/JL_C. The q46 BINARY grounding it composes
// with does (the ARP side condition), and that budget is a derive-time
// gate, not a proven lemma; see the granularity note at
// `arp_binary_unit_ok` below.

use sha2::{Digest, Sha256};

use super::commit::{CommitShape, RingCrs};
use super::ct_engine::{CtClaim, pack_functional};
use super::{D, LOG2_DELTA0, Poly, XofReader, Zq, polys_bytes};
use super::params::{E_C2, TAIL};

// ---------------------------------------------------------------------------
// The q46-class gadget commitment layer, re-derived through the C2/C3/C4
// chain (mirror of scripts/gadget_modulus_study.py::derive_gadget_layer;
// concentration discipline, wave bundles of n_commits commitments).
// Callers assert the frozen points against the study's table — see
// ring_matmul.rs::freeze_check_link.

pub struct GadgetLayer {
    pub shape: CommitShape,
    pub sigma_f: f64,
    pub beta_f: f64,
    pub c2_headroom_bits: f64,
    /// Ring-MACs per committed element at this shape.
    pub macs_el: f64,
    /// Commitment bytes per column, KB.
    pub col_kb: f64,
}

/// C2/C3/C4 iteration for a gadget-wave ct-round at modulus q with
/// msg_r-slot columns and wave bundles of n_commits commitments. None
/// when C2 fails (< 1 bit of headroom) — the study's q31 wave-capacity
/// finding.
pub fn derive_gadget_layer(q: u64, msg_r: usize, n_commits: usize) -> Option<GadgetLayer> {
    let log2_q = (q as f64).log2();
    let msg_z = msg_r * D;
    let d_lwe = (768.0 * log2_q / 11.7).ceil() as usize;
    let op = TAIL * (E_C2 * D as f64).sqrt(); // concentration op norm
    let mut k_z = 12 * D;
    let (mut kappa, mut n_r, mut sigma, mut beta) = (0usize, 0usize, 0.0f64, 0.0f64);
    for _ in 0..8 {
        let n_z = ((k_z + msg_z + d_lwe).div_ceil(D) * D) as f64;
        let bundle = n_commits as f64 * n_z;
        let t_bundle = op * bundle.sqrt();
        sigma = 12.0 * t_bundle;
        let bound = 1.2 * sigma * bundle.sqrt();
        beta = 2.0 * bound + op * bundle.sqrt();
        k_z = (((beta.log2() / 2.0) * (beta.log2() / 2.0)) / (log2_q * LOG2_DELTA0)).ceil() as usize;
        kappa = k_z.div_ceil(D);
        n_r = n_z as usize / D;
    }
    if (q as f64) <= 8.0 * beta * 2.0 {
        return None; // C2 fails at >= 1 bit of headroom
    }
    Some(GadgetLayer {
        shape: CommitShape { kappa, n_r, msg_r },
        sigma_f: sigma,
        beta_f: beta,
        c2_headroom_bits: log2_q - (8.0 * beta).log2(),
        macs_el: (1.0 + kappa as f64 / msg_r as f64) * n_r as f64 / D as f64,
        col_kb: (kappa + msg_r) as f64 * D as f64 * log2_q / 8.0 / 1024.0,
    })
}

/// The ARP-grounded binary side condition at modulus q closes only for
/// binary-claim units of at most ~896 coefficients under the coded
/// conservative constants (derive_arp_params/arp_budget_ok at rows =
/// 256, alpha = 3): a REAL granularity finding of this build — the
/// study's Section 1 budget table is the n = 512 shape, and a full
/// msg_r = 32 gadget column (4096 coefficients x W planes) does NOT
/// close even at q46. Binary claims + their ARPs must stay partitioned
/// at F3-shape units until Q4.4' lands. This helper is the derive-time
/// gate for that unit size (thin wrapper so freeze rows and demos share
/// one definition).
pub fn arp_binary_unit_ok(n_bits: usize, q: u64) -> bool {
    let ap = super::ct_engine::derive_arp_params(n_bits, 256, 1, 3.0);
    super::ct_engine::arp_budget_ok(&ap, (q / 2) as f64)
}

// ---------------------------------------------------------------------------
// Link parameters (Section 3.3): the w_max non-overflow rule, rows for
// 2^-256, the honest-|y| model, and the grounding-side range gate.

#[derive(Clone, Copy, Debug)]
pub struct LinkParams {
    /// Weight width: signed uniform w-bit rows, per-row miss 2^-w.
    pub w: u32,
    /// Rows: l = ceil(256 / w); soundness 2^-(w l) <= 2^-256.
    pub l: usize,
    /// Linked value coordinates (the granularity unit).
    pub n: usize,
    /// Bit planes W of the linked values (values in [0, 2^W)).
    pub w_bits: u32,
    /// Grounding modulus (carries the integer bound; q8_46 here).
    pub q_gnd: u64,
    /// Target modulus (the value chain; q8_31 here).
    pub q_tgt: u64,
}

/// Largest w with n * 2^(w-1) * (2^W - 1) < q_gnd/2 — the grounding
/// side's integer-exactness cap (worst-case |<xi_l, V_gnd>|).
pub fn link_w_max(n: usize, w_bits: u32, q_gnd: u64) -> u32 {
    let cap = (q_gnd / 2) as f64 / (n as f64 * ((1u64 << w_bits) - 1) as f64);
    (cap.log2().floor() as u32).max(0) + 1
}

/// l = ceil(256 / w) independent rows for 2^-256 aggregate soundness.
pub fn link_rows(w: u32) -> usize {
    256usize.div_ceil(w as usize)
}

/// 1.3-tail model of the honest |y_l| (Section 3.3, spike-corrected:
/// xi is centered but the values are NOT — Var(xi v) = E[xi^2] E[v^2]
/// with E[v^2] = 2^(2W)/3).
pub fn link_honest_y(lp: &LinkParams) -> f64 {
    let var = lp.n as f64 * 2.0f64.powi(2 * lp.w as i32) / 12.0
        * 2.0f64.powi(2 * lp.w_bits as i32) / 3.0;
    TAIL * var.sqrt()
}

/// Derive-time construction: asserts the w_max rule, the row budget and
/// the honest-completeness fit under the grounding gate.
pub fn derive_link_params(n: usize, w_bits: u32, q_gnd: u64, q_tgt: u64, w: u32) -> LinkParams {
    assert!(w >= 1 && w <= link_w_max(n, w_bits, q_gnd), "link w_max rule violated");
    let l = link_rows(w);
    assert!(w as usize * l >= 256, "link row budget below 2^-256");
    assert!(q_gnd > q_tgt, "grounding modulus must dominate the target");
    let lp = LinkParams { w, l, n, w_bits, q_gnd, q_tgt };
    // Completeness: the honest tail must fit under the grounding gate.
    assert!(link_honest_y(&lp) < (q_gnd / 2) as f64, "honest |y| busts the grounding gate");
    lp
}

/// The load-bearing range gate: |y_l| < q_gnd/2 for EVERY row — the
/// GROUNDING side's q/2 only (Section 3.3/3.4: it pins the integer y
/// from its residue on the side that carries the integer bound; a
/// symmetric q_tgt/2 gate is unsatisfiable by the honest prover at the
/// frozen w and would be a completeness break, not a hardening).
pub fn link_gate_ok(lp: &LinkParams, y: &[i64]) -> bool {
    y.len() == lp.l && y.iter().all(|&v| v.unsigned_abs() < lp.q_gnd / 2)
}

// ---------------------------------------------------------------------------
// The cross-modulus statement hash and the FS weight rows.

/// h0_link: binds BOTH CRS hashes and BOTH sides' commitment groups
/// (values, bit planes, AND the g-mask commitments of each side — pass
/// each side's full t1/t2 lists exactly as they enter that side's
/// ct-round). The xi rows derive from this hash; deriving them before
/// any commitment in these lists is the F5 failure mode.
pub fn link_h0(
    ctx: &[u8],
    gnd_crs: &RingCrs,
    tgt_crs: &RingCrs,
    gnd_t1s: &[Vec<Poly>],
    gnd_t2s: &[Vec<Poly>],
    tgt_t1s: &[Vec<Poly>],
    tgt_t2s: &[Vec<Poly>],
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"route-r-link-stmt-v1");
    hasher.update((ctx.len() as u64).to_le_bytes());
    hasher.update(ctx);
    for (crs, t1s, t2s) in [(gnd_crs, gnd_t1s, gnd_t2s), (tgt_crs, tgt_t1s, tgt_t2s)] {
        hasher.update(crs.q.to_le_bytes());
        hasher.update(crs.crs_hash);
        hasher.update((t1s.len() as u64).to_le_bytes());
        for (t1, t2) in t1s.iter().zip(t2s.iter()) {
            hasher.update(polys_bytes(t1));
            hasher.update(polys_bytes(t2));
        }
    }
    hasher.finalize().into()
}

/// l rows of signed uniform w-bit weights xi_(l,t) in
/// [-2^(w-1), 2^(w-1) - 1] (2^w values — max point mass of xi * delta
/// mod prime q_tgt is exactly 2^-w for delta != 0), one XOF per row.
pub fn derive_link_xi(h0: &[u8; 32], lp: &LinkParams) -> Vec<Vec<i64>> {
    let half = 1i64 << (lp.w - 1);
    (0..lp.l)
        .map(|row| {
            let mut reader = XofReader::new("link-xi", &[h0, &(row as u64).to_le_bytes()]);
            (0..lp.n)
                .map(|_| (reader.next_u64() & ((1u64 << lp.w) - 1)) as i64 - half)
                .collect()
        })
        .collect()
}

/// The revealed integers y_l = <xi_l, v> over Z (values in [0, 2^W)).
pub fn link_reveal_y(lp: &LinkParams, xi: &[Vec<i64>], values: &[u64]) -> Vec<i64> {
    assert_eq!(values.len(), lp.n);
    xi.iter()
        .map(|row| {
            let acc: i128 = row
                .iter()
                .zip(values.iter())
                .map(|(&a, &v)| a as i128 * v as i128)
                .sum();
            i64::try_from(acc).expect("y_l exceeds i64 — w_max rule violated upstream")
        })
        .collect()
}

// ---------------------------------------------------------------------------
// The two claim families. Both sides are ordinary linear ct-claims and
// ride their side's ct-round unchanged (g-masks, reveals, combined mask
// images — nothing new in the engine). The VERIFIER rebuilds both
// families from (h0_link, the revealed y) — the y values are bound
// through the reveals h_l (ct(h_l) = scalar is the round's
// deterministic check).

/// Grounding-side claims (q_gnd, over the bit commitments): row l puts
/// weight xi_(l,t) * 2^i on bit (i, t) — the structured weights subsume
/// recomposition. `plane_slots[i]` lists plane i's (commitment, slot)
/// pairs in coordinate order, ceil(n / D) pairs per plane. Scalar:
/// y_l itself (|y_l| < q_gnd/2, so the centered residue IS the
/// integer).
pub fn link_claims_gnd(
    zq: &Zq,
    lp: &LinkParams,
    xi: &[Vec<i64>],
    y: &[i64],
    plane_slots: &[Vec<(usize, usize)>],
) -> Vec<CtClaim> {
    assert_eq!(zq.q, lp.q_gnd);
    assert_eq!(plane_slots.len(), lp.w_bits as usize);
    let chunks = lp.n.div_ceil(D);
    (0..lp.l)
        .map(|row| {
            let mut msg_coeffs: Vec<(usize, usize, Poly)> = Vec::new();
            for (i, slots) in plane_slots.iter().enumerate() {
                assert_eq!(slots.len(), chunks);
                // Weight on plane i, coordinate t: xi_(l,t) << i (fits
                // i64: |xi| < 2^(w-1), i < W, w-1 + W < 63 asserted by
                // the w_max rule at any sane q_gnd).
                let w_flat: Vec<u64> =
                    xi[row].iter().map(|&x| zq.to_mod(x << i)).collect();
                let packed = pack_functional(zq, &w_flat, chunks);
                for (u, coeff) in packed.into_iter().enumerate() {
                    let (ci, sj) = slots[u];
                    msg_coeffs.push((ci, sj, coeff));
                }
            }
            CtClaim { msg_coeffs, ajtai_coeffs: vec![], scalar: y[row] }
        })
        .collect()
}

/// Target-side claims (q_tgt, over the value commitments): row l puts
/// weight xi_(l,t) on value t. Scalar: the centered residue of y_l mod
/// q_tgt — computed FROM the revealed integer (|y_l| may legitimately
/// exceed q_tgt/2; only the grounding side pins the integer).
pub fn link_claims_tgt(
    zq: &Zq,
    lp: &LinkParams,
    xi: &[Vec<i64>],
    y: &[i64],
    value_slots: &[(usize, usize)],
) -> Vec<CtClaim> {
    assert_eq!(zq.q, lp.q_tgt);
    let chunks = lp.n.div_ceil(D);
    assert_eq!(value_slots.len(), chunks);
    (0..lp.l)
        .map(|row| {
            let w_flat: Vec<u64> = xi[row].iter().map(|&x| zq.to_mod(x)).collect();
            let packed = pack_functional(zq, &w_flat, chunks);
            let msg_coeffs: Vec<(usize, usize, Poly)> = packed
                .into_iter()
                .enumerate()
                .map(|(u, coeff)| {
                    let (ci, sj) = value_slots[u];
                    (ci, sj, coeff)
                })
                .collect();
            CtClaim { msg_coeffs, ajtai_coeffs: vec![], scalar: zq.center(zq.to_mod(y[row])) }
        })
        .collect()
}

// U-K4 (M4_LOOKUP_DESIGN.md Sections 1/3.2/8): the lookup's STATEMENT
// data — the exact int8 SiLU pair table (silu-int8-table-v1) and the
// deterministic kappa := Y fusion.
//
// The fusion is the design's spike-found sharpening: witnesses and
// table entries are BASE-field residues, and {1, Y} are Z_q-linearly
// independent in K = Z_q[Y]/(Y^16 - s0), so
//
//     x + Y y  ==  v + Y S[v]   iff   x == v  AND  y == S[v]
//
// — the pair binding is EXACT, costs no soundness term, needs no
// challenge and has no hash-ordering edge. A base-field fusion scalar
// (the tempting shortcut) admits the exact collision
// y' = S[v'] + (v' - x) kappa^{-1}; the [U-K4] battery keeps that
// attack live in both directions (E3-N2), so nobody ever "optimizes"
// kappa into the base field.
//
// The table is STATEMENT data: its canonical spec digest (LKP-1) must
// be bound into the lookup's h0 (ctx) before alpha is drawn, exactly
// like the manifest digest of every other claim family.

use sha2::{Digest, Sha256};

use super::kfield::{KElem, KField};

/// silu-int8-table-v1: rows (v, S[v]) for v = -128..=127 at 4
/// fractional bits on both sides — the real value is v/16, and
/// S[v] = round_half_up(silu(v/16) * 16) with silu(x) = x*sigmoid(x).
/// The output range lands inside int8 without clamping (min silu is
/// ~-0.278 -> -4; max input 7.9375 -> 127). f64 evaluation is
/// deterministic per platform; the LKP-1 digest freeze row makes any
/// platform drift loud.
/// Frozen integer outputs for `silu-int8-table-v1`, indexed by x + 128.
/// Protocol semantics must not depend on a platform's libm implementation;
/// these bytes, not a runtime floating-point evaluation, define the table.
pub const SILU_INT8_OUTPUTS: [i8; 256] = [
     0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
     0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -3, -3, -3, -3, -3, -3, -3, -3, -3, -3, -4, -4, -4,
    -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4,
    -4, -4, -4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -1, -1,
     0,  0,  1,  1,  2,  2,  3,  4,  4,  5,  6,  7,  7,  8,  9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
    27, 28, 29, 30, 31, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 44,
    45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 58, 59, 60, 61,
    62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77,
    78, 79, 80, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94,
    95, 96, 97, 98, 99,100,101,102,103,104,105,106,107,108,109,110,
   111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,
   127,
];

pub const SILU_INT8_TABLE_DIGEST: [u8; 32] = [
    0x76, 0x8b, 0x83, 0xd7, 0xc0, 0x1d, 0x9b, 0xee,
    0xcc, 0x64, 0x5d, 0x26, 0x46, 0xf1, 0x07, 0xdf,
    0x7f, 0xc3, 0x70, 0xdc, 0x80, 0x2f, 0xee, 0x15,
    0x4c, 0x03, 0x18, 0x68, 0x5c, 0x40, 0xd2, 0x97,
];

pub fn silu_int8_table() -> Vec<(i64, i64)> {
    SILU_INT8_OUTPUTS
        .iter()
        .enumerate()
        .map(|(index, &y)| (index as i64 - 128, y as i64))
        .collect()
}

/// The canonical spec-header digest (LKP-1) — the design Section 1.1
/// JSON, byte-exact.
pub fn table_spec_digest(rows: &[(i64, i64)]) -> [u8; 32] {
    let mut json = String::from(
        "{\"function\":\"silu-int8-table-v1\",\
         \"input\":{\"width\":8,\"frac_bits\":4,\"signed\":true},\
         \"output\":{\"width\":8,\"frac_bits\":4,\"signed\":true},\
         \"rounding\":\"y = round_half_up(x * sigmoid(x)) on the fixed-point grid\",\
         \"table\":[",
    );
    for (i, (v, s)) in rows.iter().enumerate() {
        if i > 0 {
            json.push(',');
        }
        json.push_str(&format!("[{v},{s}]"));
    }
    json.push_str("]}");
    let mut h = Sha256::new();
    h.update(json.as_bytes());
    h.finalize().into()
}

/// kappa := Y fusion of a residue pair: x + Y y is literally the
/// K-element with coefficients [x, y, 0, ..] — no multiplication.
pub fn fuse_pair(kf: &KField, x: u64, y: u64) -> KElem {
    let mut e = kf.zero();
    e[0] = x % kf.zq.q;
    e[1] = y % kf.zq.q;
    e
}

/// The fused table: centered residues of the signed spec rows, one
/// K-element per row (256 = 2^8 rows — no padding needed).
pub fn fused_silu_table(kf: &KField, rows: &[(i64, i64)]) -> Vec<KElem> {
    rows.iter().map(|&(v, s)| fuse_pair(kf, kf.zq.to_mod(v), kf.zq.to_mod(s))).collect()
}

/// Honest multiplicities of a fused witness column against a fused
/// table (the prover-side histogram; committed per instance).
pub fn multiplicities(kf: &KField, witness: &[KElem], table: &[KElem]) -> Vec<KElem> {
    table
        .iter()
        .map(|t| kf.embed(witness.iter().filter(|w| *w == t).count() as u64))
        .collect()
}

// ---------------------------------------------------------------------------
// E4 (U-K6): the MLE-evaluation landing. The descents end in claims
// v = MLE(column)(z*) — one K-element per column. Coordinate c of v is
// a BASE-FIELD public-weight linear functional of the committed
// coefficients (weights = coordinate c of the tensor weight vector
// L_z*), so the 3 x 16 coordinate rows land as ORDINARY linear
// ct-claims (pack_functional — the link-row machinery), batched by 9
// base-field psi randomizer copies (the theta convention, 2^-279).
// psi MUST be drawn from the transcript state AFTER the claimed
// coordinates are absorbed — the E4-N1 edge.

use super::D;
use super::ct_engine::{CtClaim, pack_functional};
use super::kfield::K_DEG;

/// One block of the MLE tensor weight vector L_z (L[i] =
/// prod_t (z_t if bit_t(i) else 1 - z_t)), streamed: block `block` of
/// length 2^lb costs O(2^lb + |z|) — the full table (11.5 GB at FFN
/// scale) is never materialized.
pub fn mle_weights_block(kf: &KField, z: &[KElem], block: usize, lb: usize) -> Vec<KElem> {
    assert!(lb <= z.len());
    let (low, high) = z.split_at(lb);
    let inner = super::gkr::eq_table(kf, low);
    let mut pre = kf.one();
    for (t, zt) in high.iter().enumerate() {
        let f = if (block >> t) & 1 == 1 { zt.clone() } else { kf.sub(&kf.one(), zt) };
        pre = kf.mul(&pre, &f);
    }
    // U-K9: the block product rides the bulk kernel (bit-identical).
    super::kfield::bulk_mul_fixed_kelems(kf, &inner, &pre)
}

/// The 9 psi-batched E4 claims. weights_w / weights_t are the tensor
/// weight vectors at the witness / table descent endpoints;
/// x/y/m_slots map value chunks (D values each, dense-packed) to
/// (commitment, slot) pairs; v_coords are the 3 * K_DEG claimed
/// coordinate values (v^X, then v^Y, then v^M) as mod-q residues —
/// ABSORBED into the transcript before psi was drawn; psi is the
/// copies x 48 randomizer table.
pub fn e4_claims(
    kf: &KField,
    weights_w: &[KElem],
    weights_t: &[KElem],
    x_slots: &[(usize, usize)],
    y_slots: &[(usize, usize)],
    m_slots: &[(usize, usize)],
    v_coords: &[u64],
    psi: &[Vec<u64>],
) -> Vec<CtClaim> {
    let zq = &kf.zq;
    assert_eq!(v_coords.len(), 3 * K_DEG);
    psi.iter()
        .map(|p| {
            assert_eq!(p.len(), 3 * K_DEG);
            let build = |weights: &[KElem], off: usize| -> Vec<u64> {
                (0..weights.len())
                    .map(|i| {
                        let mut acc = 0u64;
                        for c in 0..K_DEG {
                            acc = zq.add(acc, zq.mul(p[off + c], weights[i][c]));
                        }
                        acc
                    })
                    .collect()
            };
            let mut msg_coeffs: Vec<(usize, usize, super::Poly)> = Vec::new();
            for (wf, slots) in [
                (build(weights_w, 0), x_slots),
                (build(weights_w, K_DEG), y_slots),
                (build(weights_t, 2 * K_DEG), m_slots),
            ] {
                assert!(wf.len() <= slots.len() * D);
                let packed = pack_functional(zq, &wf, slots.len());
                for (u, coeff) in packed.into_iter().enumerate() {
                    let (ci, sj) = slots[u];
                    msg_coeffs.push((ci, sj, coeff));
                }
            }
            let scalar_mod = (0..3 * K_DEG)
                .fold(0u64, |a, r| zq.add(a, zq.mul(p[r], v_coords[r])));
            CtClaim { msg_coeffs, ajtai_coeffs: vec![], scalar: zq.center(scalar_mod) }
        })
        .collect()
}

/// psi: the E4 randomizer copies (9 at the frozen point — LKP-4),
/// drawn from the transcript state that already binds the claimed
/// coordinates (the E4-N1 edge).
pub fn derive_e4_psi(state: &[u8; 32], copies: usize, q: u64) -> Vec<Vec<u64>> {
    let mut reader = super::XofReader::new("e4-psi", &[state]);
    (0..copies).map(|_| (0..3 * K_DEG).map(|_| reader.next_field(q)).collect()).collect()
}

/// Multiply by the generator Y in coordinates (for reconstructing
/// v_w = v^X + Y v^Y from claimed coordinates): shift up with the
/// binomial wrap Y^K_DEG = s.
pub fn mul_y(kf: &KField, a: &KElem) -> KElem {
    let mut out = kf.zero();
    out[0] = kf.zq.mul(kf.s, a[K_DEG - 1]);
    out[1..K_DEG].copy_from_slice(&a[0..K_DEG - 1]);
    out
}

/// The multiplication-by-kappa matrix in coordinates: row c, column j
/// = (kappa * Y^j)[c]. A pinned value sum_e kappa_e * x_e over
/// COMMITTED K-elements x_e (16 base coefficients each) has coordinate
/// rows coord_c = sum_e sum_j M(kappa_e)[c][j] * x_e[j] — the E4
/// public-weight shape over the elements' base coefficients (U-K5c's
/// mask-opening and blinder-column pins use exactly this).
pub fn k_weight_coords(kf: &KField, kappa: &KElem) -> Vec<Vec<u64>> {
    let mut cols = Vec::with_capacity(K_DEG);
    let mut cur = kappa.clone();
    for _ in 0..K_DEG {
        cols.push(cur.clone());
        cur = mul_y(kf, &cur);
    }
    // rows[c][j] = cols[j][c]
    (0..K_DEG).map(|c| (0..K_DEG).map(|j| cols[j][c]).collect()).collect()
}

// ---------------------------------------------------------------------------
// U-K5c: the pin layer — every masked-descent claim (G_j hypersums,
// mask openings, the aggregate-only leaf P/Q pins) is a PINNED VALUE:
// a public-weight K-linear functional of committed data equal to a
// transcript-derived K value. Its K_DEG coordinate rows are ordinary
// base-field linear ct-claim rows; ONE psi batch over every row of
// every pin lands them as the same 9 CtClaims as E4 (LKP-4 budget,
// psi drawn AFTER all pinned values are bound — the E4-N1 edge, whose
// scope now includes the mask openings).

/// One linear term of a pinned value's functional.
pub enum PinTerm {
    /// Committed base-field SCALARS x_i at consecutive message
    /// coefficients coeff0.. of commitment `commit`, with a K weight
    /// per scalar: contributes sum_i weights[i] * x_i.
    Scalar { commit: usize, coeff0: usize, weights: Vec<KElem> },
    /// Committed K-ELEMENTS (K_DEG consecutive base coefficients each)
    /// starting at coeff0, with a K weight per element: contributes
    /// sum_e weights[e] * elem_e (coordinate rows via k_weight_coords).
    Kelems { commit: usize, coeff0: usize, weights: Vec<KElem> },
}

/// A pinned value: functional(committed data) = value, both sides
/// K-valued; K_DEG base-coordinate rows in the psi batch.
pub struct PinnedValue {
    pub terms: Vec<PinTerm>,
    pub value: KElem,
}

/// U-K8 (the slot-packed E4 variant, M4_LOOKUP_DESIGN Section 3.4):
/// E1-composed pin weights for a SLOT-PACKED (H3) tensor. The pin's
/// functional wants sum_t w_t * value_t where value_t is the CONSTANT
/// coordinate of CRT slot t%k of packed element t/k — itself a public
/// base-field row over the element's D coefficients (crt_coord_rows
/// row (t%k)*slot_deg). Folding the per-VALUE K weights through those
/// rows gives per-COEFFICIENT K weights, i.e. the same PinTerm::Scalar
/// claim family as a dense tensor with a different public weight
/// computation — exactly the design's "no new claim family" promise.
/// `const_rows[s]` is slot s's constant-coordinate projection row (D
/// base scalars); `weights[t]` the K weight on value t; output length
/// chunks * D (one K weight per committed coefficient, in element
/// order). Cost: k * D KElem-scales per packed element.
pub fn slot_pin_weights(
    kf: &KField,
    const_rows: &[Vec<u64>],
    weights: &[KElem],
    chunks: usize,
) -> Vec<KElem> {
    let k = const_rows.len();
    let mut out = vec![kf.zero(); chunks * D];
    for u in 0..chunks {
        for (s, row) in const_rows.iter().enumerate() {
            let t = u * k + s;
            if t >= weights.len() {
                break;
            }
            let w = &weights[t];
            if kf.is_zero(w) {
                continue;
            }
            assert_eq!(row.len(), D);
            for (i, &m) in row.iter().enumerate() {
                if m != 0 {
                    let o = &mut out[u * D + i];
                    *o = kf.add(o, &kf.scale(m, w));
                }
            }
        }
    }
    out
}

/// psi for the pin batch: `copies` x (pins * K_DEG) randomizer rows,
/// drawn from transcript state that already binds every pinned value.
pub fn derive_pin_psi(state: &[u8; 32], copies: usize, rows: usize, q: u64) -> Vec<Vec<u64>> {
    let mut reader = super::XofReader::new("e4-pin-psi", &[state]);
    (0..copies).map(|_| (0..rows).map(|_| reader.next_field(q)).collect()).collect()
}

/// The psi-batched pin claims: one CtClaim per psi copy over all pins'
/// coordinate rows (pin p, coordinate c = row p * K_DEG + c). The
/// verifier rebuilds the same claims from public weights and the
/// transcript's pinned values; the ct-round grounds them against the
/// commitments.
pub fn pin_claims(
    kf: &KField,
    pins: &[PinnedValue],
    n_commits: usize,
    msg_r: usize,
    psi: &[Vec<u64>],
) -> Vec<CtClaim> {
    let zq = &kf.zq;
    let rows_total = pins.len() * K_DEG;
    psi.iter()
        .map(|p| {
            assert_eq!(p.len(), rows_total);
            // Combined weight per committed message coefficient.
            let mut acc: Vec<Vec<u64>> = vec![vec![0u64; msg_r * D]; n_commits];
            let mut scalar_mod = 0u64;
            for (pi, pin) in pins.iter().enumerate() {
                let off = pi * K_DEG;
                for c in 0..K_DEG {
                    scalar_mod = zq.add(scalar_mod, zq.mul(p[off + c], pin.value[c]));
                }
                for term in &pin.terms {
                    match term {
                        PinTerm::Scalar { commit, coeff0, weights } => {
                            for (i, w) in weights.iter().enumerate() {
                                let mut s = 0u64;
                                for c in 0..K_DEG {
                                    s = zq.add(s, zq.mul(p[off + c], w[c]));
                                }
                                let a = &mut acc[*commit][coeff0 + i];
                                *a = zq.add(*a, s);
                            }
                        }
                        PinTerm::Kelems { commit, coeff0, weights } => {
                            for (e, w) in weights.iter().enumerate() {
                                let m = k_weight_coords(kf, w);
                                for j in 0..K_DEG {
                                    let mut s = 0u64;
                                    for c in 0..K_DEG {
                                        s = zq.add(s, zq.mul(p[off + c], m[c][j]));
                                    }
                                    let a = &mut acc[*commit][coeff0 + e * K_DEG + j];
                                    *a = zq.add(*a, s);
                                }
                            }
                        }
                    }
                }
            }
            let mut msg_coeffs: Vec<(usize, usize, super::Poly)> = Vec::new();
            for (ci, wf) in acc.iter().enumerate() {
                if wf.iter().all(|&x| x == 0) {
                    continue;
                }
                let packed = pack_functional(zq, wf, msg_r);
                for (sj, coeff) in packed.into_iter().enumerate() {
                    if coeff.iter().all(|&x| x == 0) {
                        continue;
                    }
                    msg_coeffs.push((ci, sj, coeff));
                }
            }
            CtClaim { msg_coeffs, ajtai_coeffs: vec![], scalar: zq.center(scalar_mod) }
        })
        .collect()
}

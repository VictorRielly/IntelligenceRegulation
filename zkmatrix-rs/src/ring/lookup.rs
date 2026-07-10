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
pub fn silu_int8_table() -> Vec<(i64, i64)> {
    (-128i64..=127)
        .map(|v| {
            let x = v as f64 / 16.0;
            let s = x / (1.0 + (-x).exp());
            let y = (s * 16.0 + 0.5).floor() as i64;
            debug_assert!((-128..=127).contains(&y));
            (v, y)
        })
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

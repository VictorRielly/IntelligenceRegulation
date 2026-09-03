//! [UPERF3-AE] The public table members of the attention statement:
//!
//!  * `exp-neg-table-v1` (design memo section 1.3; ATTENTION_INTEGER_SPEC
//!    section 2.5; the Python generator of record
//!    scripts/attention_spec_spike.py `exp_table_generate` /
//!    `exp_table_digest`): a 256-row member keyed (eS, d_h, fE) with
//!    E[d] = round_half_up(2^fE * exp(-d * 2^eS / sqrt(d_h))), d in
//!    [0, 255], E in [0, 2^fE], E[0] = 2^fE exactly, monotone
//!    nonincreasing. The KEY CONVENTION of this crate (recorded in the
//!    ledger, Agent AE rung 0): eS is the exponent of the committed s8
//!    plane, which is the requant of the RAW integer score accumulator
//!    q . k (the 1 / sqrt(d_h) of the attention lives in the table's
//!    decay constant, never in a shift). The 125M gate
//!    (results/m125_attn_at_o1.json) measured the SCALED score
//!    exponent -2; at d_h = 64 the raw exponent is exactly +3 more
//!    (sqrt(64) = 8), so the statement's member is (eS_raw = +1, 64, 9),
//!    whose function exp(-d * 2^1 / 8) = exp(-d / 4) is the gate's own
//!    exp(-d * 2^-2). The spec digest is the canonical JSON header the
//!    spike pins (byte-identical bytes, checked by a unit test against
//!    the spike's frozen example digests).
//!
//!  * `rope-cs-table-v1` (spec section 2.3; AM-4): the PUBLIC integer
//!    cos/sin tables of the rotate-half RoPE at fRo fractional bits,
//!    keyed (T_max, d_h, base, fRo): c[t][i] = round_half_up(cos(t *
//!    base^(-2i/d_h)) * 2^fRo), s likewise, i in [0, d_h/2); |c|, |s|
//!    <= 2^fRo. These are statement constants (never committed).
//!
//!  * the LogUp table TAGS of the attention statement (disjoint from the
//!    FFN's: TAG_SILU 1, TAG_INT8 2, TAG_ACT16 3, TAG_INT16 4, the v2
//!    range tags 16 + sh, the v3 window tags 64 + sh + 8 in 64..=88).
//!
//! Rung 0 (2026-09-03): the generators, digests and tags. The members
//! are generated at proof time from the key and checked against the
//! digest the statement absorbs (the silu-v2 discipline: a platform
//! libm drift is a hard stop, never a silent different table).

use sha2::{Digest, Sha256};

/// Fixed-point resolutions of the softmax chain (spec section 2.5).
pub const F_E: u32 = 9;
pub const F_P: u32 = 9;
/// RoPE cos/sin fractional bits (spec section 2.3).
pub const F_RO: u32 = 7;

// ---- LogUp table tags of the attention statement (>= 128) ----------------
/// unsigned 16-bit limb class [0, 2^16)
pub const TAG_U16: u64 = 128;
/// the fused (d, E) exp lookup: rows d + beta * E[d]
pub const TAG_EXP: u64 = 129;
/// the softmax weight class [0, 2^fP] (2^fP + 1 rows)
pub const TAG_PROB: u64 = 130;
/// the softmax remainder class [0, 2^wrho), wrho = fE + log2(T): 160 + wrho
pub fn tag_srem(wrho: u32) -> u64 {
    160 + wrho as u64
}
/// the balanced round-requant window of a signed shift sh in 0..=24: 192 + sh
pub fn tag_win(sh: i32) -> u64 {
    assert!((0..=24).contains(&sh), "window tag: shift {sh} out of 0..=24");
    192 + sh as u64
}

/// round_half_up(x) = floor(x + 1/2), the spike's rounding.
#[inline]
pub fn round_half_up(x: f64) -> i64 {
    (x + 0.5).floor() as i64
}

/// exp-neg-table-v1 member (eS, d_h, fE): the 256 outputs.
pub fn exp_table_generate(e_s: i32, head_dim: usize, f_e: u32) -> [i64; 256] {
    let lam = (e_s as f64).exp2() / (head_dim as f64).sqrt();
    let scale = (f_e as f64).exp2();
    let mut out = [0i64; 256];
    for (d, slot) in out.iter_mut().enumerate() {
        *slot = round_half_up(scale * (-(d as f64) * lam).exp());
    }
    out
}

/// The canonical spec-header digest of an exp member (sha256 hex of the
/// spike's JSON layout, byte for byte).
pub fn exp_table_digest(e_s: i32, head_dim: usize, f_e: u32, table: &[i64; 256]) -> String {
    let mut js = format!(
        "{{\"function\":\"exp-neg-table-v1\",\
         \"input\":{{\"width\":8,\"signed\":false}},\
         \"output\":{{\"width\":{},\"signed\":false,\"frac_bits\":{f_e}}},\
         \"decay\":{{\"score_scale_exp\":{e_s},\"head_dim\":{head_dim}}},\
         \"rounding\":\"E = round_half_up(2^frac_bits * exp(-d * 2^score_scale_exp / sqrt(head_dim)))\",\
         \"table\":[",
        f_e + 1
    );
    for (d, e) in table.iter().enumerate() {
        if d > 0 {
            js.push(',');
        }
        js.push_str(&format!("[{d},{e}]"));
    }
    js.push_str("]}");
    let mut h = Sha256::new();
    h.update(js.as_bytes());
    crate::silu::hex(&h.finalize())
}

/// The member for a key: (table, digest); structural checks asserted
/// (E[0] = 2^fE, outputs in [0, 2^fE], monotone nonincreasing).
pub fn exp_member(e_s: i32, head_dim: usize, f_e: u32) -> ([i64; 256], String) {
    let t = exp_table_generate(e_s, head_dim, f_e);
    assert_eq!(t[0], 1i64 << f_e, "exp member: E[0] != 2^fE");
    assert!(t.iter().all(|&e| (0..=(1i64 << f_e)).contains(&e)), "exp member: output range");
    assert!(t.windows(2).all(|w| w[0] >= w[1]), "exp member: not monotone");
    let d = exp_table_digest(e_s, head_dim, f_e, &t);
    (t, d)
}

/// rope-cs-table-v1 (T_max x d_h/2 each, row-major): (cos, sin).
pub fn rope_tables_generate(t_max: usize, head_dim: usize, base: f64, f_ro: u32) -> (Vec<i64>, Vec<i64>) {
    let half = head_dim / 2;
    let scale = (f_ro as f64).exp2();
    let mut c = vec![0i64; t_max * half];
    let mut s = vec![0i64; t_max * half];
    for i in 0..half {
        let theta = base.powf(-2.0 * i as f64 / head_dim as f64);
        for t in 0..t_max {
            let a = t as f64 * theta;
            c[t * half + i] = round_half_up(a.cos() * scale);
            s[t * half + i] = round_half_up(a.sin() * scale);
        }
    }
    (c, s)
}

/// The rope table digest: sha256 over the spike's JSON header followed
/// by the little-endian int64 bytes of c then s.
pub fn rope_digest(t_max: usize, head_dim: usize, base: f64, f_ro: u32, c: &[i64], s: &[i64]) -> String {
    let head = format!(
        "{{\"function\":\"rope-cs-table-v1\",\"rope_base\":{},\"head_dim\":{head_dim},\"t_max\":{t_max},\"frac_bits\":{f_ro},\
         \"rounding\":\"c=round_half_up(cos(t*base^(-2i/head_dim))*2^frac_bits); s likewise\"}}",
        py_float(base)
    );
    let mut h = Sha256::new();
    h.update(head.as_bytes());
    for v in c {
        h.update(v.to_le_bytes());
    }
    for v in s {
        h.update(v.to_le_bytes());
    }
    crate::silu::hex(&h.finalize())
}

/// Python's repr of a float for the header (10000.0 -> "10000.0").
fn py_float(x: f64) -> String {
    if x == x.floor() && x.abs() < 1e16 {
        format!("{:.1}", x)
    } else {
        format!("{}", x)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The spike's own frozen example digests (scripts/attention_spec_spike.py
    /// `check_tables`: 5 eS members at d_h 64 distinct; d_h 64 != 128) and
    /// the JJ-pinned members (ledger Agent JJ: eS -1 15903694.., eS -2 b4f01aca..).
    #[test]
    fn exp_members_match_the_python_generator() {
        let (_, d1) = exp_member(-1, 64, F_E);
        assert!(d1.starts_with("15903694"), "eS -1 d_h 64: {d1}");
        let (_, d2) = exp_member(-2, 64, F_E);
        assert!(d2.starts_with("b4f01aca"), "eS -2 d_h 64: {d2}");
        let (t, d3) = exp_member(1, 64, F_E);
        assert_eq!(t[0], 512);
        assert_eq!(t[4], round_half_up(512.0 * (-1.0f64).exp()));
        assert_ne!(d3, d2);
        let (_, d4) = exp_member(-2, 128, F_E);
        assert_ne!(d4, d2);
    }

    /// NN's pinned rope members: t16 355be440fcc13985.., t32 e0de1cf45aa38f10.. (d_h 64, base 1e4, fRo 7).
    #[test]
    fn rope_members_match_the_python_pins() {
        let (c, s) = rope_tables_generate(16, 64, 10000.0, F_RO);
        assert_eq!(c[0], 128);
        assert!(c.iter().chain(s.iter()).all(|v| v.abs() <= 128));
        let d = rope_digest(16, 64, 10000.0, F_RO, &c, &s);
        assert!(d.starts_with("355be440fcc13985"), "t16: {d}");
        let (c, s) = rope_tables_generate(32, 64, 10000.0, F_RO);
        let d = rope_digest(32, 64, 10000.0, F_RO, &c, &s);
        assert!(d.starts_with("e0de1cf45aa38f10"), "t32: {d}");
    }
}

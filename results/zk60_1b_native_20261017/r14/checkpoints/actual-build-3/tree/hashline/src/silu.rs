//! The frozen `silu-int8-table-v2` family, re-derived from the frozen
//! generation formula (zkmatrix-rs/src/ring/lookup.rs `silu_v2_generate`
//! and scripts/m125_export_ffn.py `silu_v2_generate`) and pinned by the
//! v2 spec digests (`table_spec_digest_v2`), which are the same digests
//! the export manifest carries under "tables". zkmatrix-rs has no
//! library target, so the bytes are regenerated here and CHECKED against
//! the frozen pins before use — a digest mismatch is a hard stop.

use sha2::{Digest, Sha256};

pub const SILU_V2_M3_DIGEST_HEX: &str = "bdf8bc7129dc6ec8b002af51fd4dbef3d7c1240f65c4da01ce2db2a7c9bb6c50";
pub const SILU_V2_M4_DIGEST_HEX: &str = "063993481a8fc0087014b25357a22b95d88bda649cc6997e2fe27c5bacd17ada";

/// S[g] = clamp(round_half_up(silu(g * 2^e_gate) / 2^e_act), -127, 127), g = -128..=127.
pub fn silu_v2_generate(e_gate: i32, e_act: i32) -> [i8; 256] {
    let mut out = [0i8; 256];
    for (i, slot) in out.iter_mut().enumerate() {
        let g = i as i32 - 128;
        let x = g as f64 * (e_gate as f64).exp2();
        let y = x / (1.0 + (-x).exp());
        let v = (y / (e_act as f64).exp2() + 0.5).floor();
        *slot = v.clamp(-127.0, 127.0) as i8;
    }
    out
}

pub fn table_spec_digest_v2(e_gate: i32, e_act: i32, table: &[i8; 256]) -> String {
    let mut json = format!(
        "{{\"function\":\"silu-int8-table-v2\",\
         \"input\":{{\"width\":8,\"scale_exp\":{e_gate},\"signed\":true}},\
         \"output\":{{\"width\":8,\"scale_exp\":{e_act},\"signed\":true}},\
         \"rounding\":\"y = clamp(round_half_up(silu(x*2^in_exp)/2^out_exp), -127, 127)\",\
         \"table\":["
    );
    for (i, s) in table.iter().enumerate() {
        if i > 0 { json.push(','); }
        json.push_str(&format!("[{},{}]", i as i32 - 128, *s as i32));
    }
    json.push_str("]}");
    let mut h = Sha256::new();
    h.update(json.as_bytes());
    hex(&h.finalize())
}

// [ZK60-CL20] canonical in zkp-core (moved with the v3 table registry).
pub use zkp_core::tables::hex;

/// The frozen member for (e_gate, e_act): regenerated and digest-checked.
/// Returns (bytes, digest hex). Panics on a pair outside the frozen
/// family or on a digest mismatch (platform libm drift would be loud).
pub fn silu_v2_member(e_gate: i32, e_act: i32) -> ([i8; 256], String) {
    let pin = match (e_gate, e_act) {
        (-3, -3) => SILU_V2_M3_DIGEST_HEX,
        (-4, -4) => SILU_V2_M4_DIGEST_HEX,
        _ => panic!("silu-int8-table-v2: ({e_gate},{e_act}) is not a frozen member"),
    };
    let t = silu_v2_generate(e_gate, e_act);
    let d = table_spec_digest_v2(e_gate, e_act, &t);
    assert_eq!(d, pin, "silu-int8-table-v2 ({e_gate},{e_act}): regenerated digest != frozen pin");
    (t, d)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frozen_members_regenerate_to_their_pins() {
        let (m3, d3) = silu_v2_member(-3, -3);
        assert_eq!(d3, SILU_V2_M3_DIGEST_HEX);
        assert_eq!(m3[255], 127);
        assert_eq!(m3.iter().copied().min().unwrap(), -2);
        let (m4, d4) = silu_v2_member(-4, -4);
        assert_eq!(d4, SILU_V2_M4_DIGEST_HEX);
        assert_eq!(m4.iter().copied().min().unwrap(), -4);
        assert_eq!(m4[255], 127);
    }
}

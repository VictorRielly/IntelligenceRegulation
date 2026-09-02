//! [UPERF3-ZB] The frozen int16-out activation-table families of the
//! WIDENED STACK (TARGET_CONTRACT section 2 v3, adopted 2026-08-26):
//! `silu-int16out-table-v3` (9 members) and `gelu-tanh-int16out-table-v3`
//! (6 members). Each member is a 256-row table over the int8 gate domain
//! g = -128..=127 with an int16 output:
//!
//!   S[g] = clamp(round_half_up(f(g * 2^e_in) / 2^e_out), -32767, 32767),
//!   round_half_up(x) = floor(x + 1/2), f = silu | gelu_tanh in f64.
//!
//! The bytes are regenerated here from that frozen formula (the engine's
//! zkmatrix-rs/src/ring/lookup.rs `int16out_generate`; the Python of
//! record scripts/m8b_margins.py `i16out_generate`) and CHECKED against
//! the frozen v3 spec digests below before use (`table_spec_digest_int16out`
//! — the v2 spec-header JSON with the v3 function names and the 16-bit
//! output width; the same digests the v3 exports' `NN table` rows carry
//! and `ring_matmul uperf-v3 tables` prints). zkmatrix-rs has no library
//! target, so the engine's frozen consts cannot be linked; the digest pin
//! is the freeze: a platform libm drift is a hard stop, never a silent
//! different table. Cross-checked 2026-09-02 three ways (the Python
//! generator, the frozen consts parsed from lookup.rs, the engine
//! binary's `uperf-v3 tables`): 15/15 members byte- and digest-identical.

use sha2::{Digest, Sha256};

/// The two frozen int16-out families.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Act16Fn {
    Silu,
    GeluTanh,
}

impl Act16Fn {
    pub fn spec_name(self) -> &'static str {
        match self {
            Act16Fn::Silu => "silu-int16out-table-v3",
            Act16Fn::GeluTanh => "gelu-tanh-int16out-table-v3",
        }
    }
    fn rounding_fn(self) -> &'static str {
        match self {
            Act16Fn::Silu => "silu",
            Act16Fn::GeluTanh => "gelu_tanh",
        }
    }
    pub fn from_spec_name(s: &str) -> Option<Act16Fn> {
        match s {
            "silu-int16out-table-v3" => Some(Act16Fn::Silu),
            "gelu-tanh-int16out-table-v3" => Some(Act16Fn::GeluTanh),
            _ => None,
        }
    }
    /// The f64 activation exactly as the frozen generators evaluate it.
    pub fn eval(self, x: f64) -> f64 {
        match self {
            Act16Fn::Silu => x / (1.0 + (-x).exp()),
            Act16Fn::GeluTanh => {
                0.5 * x * (1.0 + ((2.0f64 / std::f64::consts::PI).sqrt() * (x + 0.044715 * x * x * x)).tanh())
            }
        }
    }
    pub fn members(self) -> (&'static [(i32, i32)], &'static [&'static str]) {
        match self {
            Act16Fn::Silu => (&SILU16_V3_MEMBERS, &SILU16_V3_DIGESTS_HEX),
            Act16Fn::GeluTanh => (&GELU16_V3_MEMBERS, &GELU16_V3_DIGESTS_HEX),
        }
    }
}

/// (e_in = the margin-adjusted eGate, e_out = eA - 8) of every frozen member.
pub const SILU16_V3_MEMBERS: [(i32, i32); 9] =
    [(-5, -13), (-4, -13), (-4, -12), (-3, -12), (-3, -11), (-2, -11), (-1, -11), (-1, -10), (-1, -9)];
pub const SILU16_V3_DIGESTS_HEX: [&str; 9] = [
    "bf3eb04eeeeec844a313be913480606b4b792cdf6f26902bbb7fea4e571b92bc",
    "0c74b0e6fb57dd67a49c61bef5dae093f6ce154d6f331bd65d0d548faf0eca60",
    "afed7dc5c289cbdb18fbf5d794285ba5901ebe43e9e561aad6ec32987fa66d54",
    "859344ba5ed57bd3f831c9082e5991fe7012a0c5696cfa705320ffdb6cb17a25",
    "1001c138ce0d00f09390b36178044d72712fbdca1071467ea274dc980bd9a3f7",
    "eda5f34a1c0dd94ce7398d6762202ed85e3f6f2c4984a5b07aca57b00b30ba56",
    "493202f2d89b0ffe7981decfb818aafaacea4cccb117d758b9e6b416463d9a4b",
    "5323ca1bd1091ec18bf5036ca7ea4e007224ebc3a26ad56759a4b9da0c419a79",
    "d835998909adcd25dcc7eba10239e82ea0323437b5ba419d9fa5c28e6fa6c689",
];
pub const GELU16_V3_MEMBERS: [(i32, i32); 6] = [(-4, -12), (-3, -12), (-3, -11), (-2, -11), (-2, -10), (-1, -9)];
pub const GELU16_V3_DIGESTS_HEX: [&str; 6] = [
    "13ecf11e5608d6032ae9e3e119974e0f22a68fee70624d2295871b7e6f5ec1df",
    "37558a0d99cb5a226f4f8ef48f504e097249dffda54a9c563de2de4e6638ea6b",
    "4c811e7d93de21a9bd2cd925ed7b4abb87afda229ee49add8c22abec4b32fb1a",
    "f9eefef1e2e9e66d11a821d3fec7f4567e2e936b5817f2d157725301d33b0a15",
    "775e023b20b441268b9037c0f826d4378044991790e32274e1d613c3b4de5e09",
    "046effd433a6ca204131a25ed3e06343236b5eb77e2a0e6d562d8af73cc29eab",
];

/// Deterministic generation of an int16-out member (the frozen formula).
pub fn int16out_generate(f: Act16Fn, e_in: i32, e_out: i32) -> [i16; 256] {
    let mut out = [0i16; 256];
    for (i, slot) in out.iter_mut().enumerate() {
        let g = i as i32 - 128;
        let x = g as f64 * (e_in as f64).exp2();
        let y = f.eval(x);
        let v = (y / (e_out as f64).exp2() + 0.5).floor();
        *slot = v.clamp(-32767.0, 32767.0) as i16;
    }
    out
}

/// The canonical int16-out spec-header digest (hex): the v2 JSON layout
/// with the v3 function names and the 16-bit output width.
pub fn table_spec_digest_int16out(f: Act16Fn, e_in: i32, e_out: i32, table: &[i16; 256]) -> String {
    let mut json = format!(
        "{{\"function\":\"{}\",\
         \"input\":{{\"width\":8,\"scale_exp\":{e_in},\"signed\":true}},\
         \"output\":{{\"width\":16,\"scale_exp\":{e_out},\"signed\":true}},\
         \"rounding\":\"y = clamp(round_half_up({}(x*2^in_exp)/2^out_exp), -32767, 32767)\",\
         \"table\":[",
        f.spec_name(),
        f.rounding_fn()
    );
    for (i, s) in table.iter().enumerate() {
        if i > 0 {
            json.push(',');
        }
        json.push_str(&format!("[{},{}]", i as i32 - 128, *s as i32));
    }
    json.push_str("]}");
    let mut h = Sha256::new();
    h.update(json.as_bytes());
    crate::silu::hex(&h.finalize())
}

/// The frozen member for (function, e_in, e_out): regenerated and
/// digest-checked against the pin. None outside the frozen registry (a
/// statement must not reference a table that was never frozen); a
/// regenerated digest that differs from its pin is a hard stop.
pub fn int16out_member(f: Act16Fn, e_in: i32, e_out: i32) -> Option<([i16; 256], String)> {
    let (members, digests) = f.members();
    let i = members.iter().position(|&m| m == (e_in, e_out))?;
    let t = int16out_generate(f, e_in, e_out);
    let d = table_spec_digest_int16out(f, e_in, e_out, &t);
    assert_eq!(d, digests[i], "{} ({e_in},{e_out}): regenerated digest != frozen pin (platform drift)", f.spec_name());
    Some((t, d))
}

/// Every frozen member regenerated and checked; returns
/// (spec name, e_in, e_out, digest, min, max, rows clamped at +-32767).
pub fn registry_report() -> Vec<(&'static str, i32, i32, String, i16, i16, usize)> {
    let mut out = Vec::new();
    for f in [Act16Fn::Silu, Act16Fn::GeluTanh] {
        let (members, _) = f.members();
        for &(ei, eo) in members {
            let (t, d) = int16out_member(f, ei, eo).unwrap();
            let sat = t.iter().filter(|&&v| v == 32767 || v == -32767).count();
            out.push((f.spec_name(), ei, eo, d, *t.iter().min().unwrap(), *t.iter().max().unwrap(), sat));
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_frozen_members_regenerate_to_their_pins() {
        let rep = registry_report();
        assert_eq!(rep.len(), 15);
        // the 125M v3 export's two members and Mistral's saturating one
        let (t, d) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
        assert_eq!(d, "1001c138ce0d00f09390b36178044d72712fbdca1071467ea274dc980bd9a3f7");
        assert_eq!(*t.iter().min().unwrap(), -570);
        assert_eq!(*t.iter().max().unwrap(), 32512);
        let (t, _) = int16out_member(Act16Fn::Silu, -4, -13).unwrap();
        assert_eq!(t.iter().filter(|&&v| v == 32767).count(), 62);
        assert!(int16out_member(Act16Fn::Silu, -7, -20).is_none());
        assert_eq!(Act16Fn::from_spec_name("gelu-tanh-int16out-table-v3"), Some(Act16Fn::GeluTanh));
    }
}

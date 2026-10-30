//! **NATIVE R12 (F1, D38): RoPE frequency transforms — YaRN and llama3 —
//! as a change to the PUBLIC cos/sin tables only.**
//!
//! The rotation relation (`SC_QZC` / `SC_KVZC`: `cos x + sin x' - 2^7 r - rem
//! + 2^6`) reads two public tables and nothing else about the positional
//! encoding, so a scaled RoPE changes the TABLES and no relation, plane,
//! lookup or slot. This module computes the inverse frequencies by the
//! reference formulas of Hugging Face transformers (`modeling_rope_utils.py`,
//! `_compute_yarn_parameters` and `_compute_llama3_parameters`, main branch
//! of 2026-10-21; a copy is kept at `results/zk60_1b_native_20261017/r12/
//! reference/transformers_main_modeling_rope_utils.py`), in IEEE-754
//! binary64, and rounds `cos` / `sin` at `2^f_ro` exactly as the frozen
//! generator does. The unscaled case IS the frozen generator
//! (`tables_attn::rope_tables_generate`), byte for byte.
//!
//! The YaRN "attention factor" multiplies cos and sin in transformers. The
//! rotation relation assumes `|cos|, |sin| <= 1` (the table class
//! `[-2^7, 2^7]`, position 0 = `(2^7, 0)`), so a profile whose attention
//! factor is not exactly 1 is REFUSED by name; Shieldstral's (mscale =
//! mscale_all_dim = 1) is exactly 1. Shieldstral's Llama-4 query scale
//! (`llama_4_scaling_beta`) is `1 + beta ln(1 + floor(pos / 16384))`, exactly
//! 1 at every position below 16384, so at the registered T128 / T256 it is
//! not a factor at all.

use crate::tables_attn::round_half_up;

/// A RoPE frequency transform, with the parameters its reference formula reads.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) enum RopeScaling {
    /// the plain RoPE of every profile before R12
    None,
    /// Llama 3.1 / 3.2 (`rope_type: "llama3"`)
    Llama3 { factor: f64, low_freq_factor: f64, high_freq_factor: f64, original_max: u64 },
    /// YaRN (`rope_type: "yarn"`)
    Yarn { factor: f64, original_max: u64, beta_fast: f64, beta_slow: f64, mscale: f64, mscale_all_dim: f64, truncate: bool },
}

impl RopeScaling {
    /// Shieldstral-1.0-3B's (`config.json` at revision
    /// 003ec7e2b0bab5f0e6307edbaf186fa5822b76f5, `text_config.rope_parameters`:
    /// factor 16, original 16384, beta_fast 32, beta_slow 1, mscale 1,
    /// mscale_all_dim 1; no `truncate` key, so true)
    pub(crate) const fn shieldstral() -> RopeScaling {
        RopeScaling::Yarn { factor: 16.0, original_max: 16384, beta_fast: 32.0, beta_slow: 1.0, mscale: 1.0, mscale_all_dim: 1.0, truncate: true }
    }

    /// Llama 3.1's (factor 8, low 1, high 4, original 8192) — the Llama
    /// Guard 3 family's; registered by no profile yet, tested against the
    /// reference
    pub(crate) const fn llama3_1() -> RopeScaling {
        RopeScaling::Llama3 { factor: 8.0, low_freq_factor: 1.0, high_freq_factor: 4.0, original_max: 8192 }
    }

    /// the post-processing factor transformers multiplies cos and sin by
    pub(crate) fn attention_factor(&self) -> f64 {
        match *self {
            RopeScaling::None | RopeScaling::Llama3 { .. } => 1.0,
            RopeScaling::Yarn { factor, mscale, mscale_all_dim, .. } => {
                let get = |scale: f64, m: f64| if scale <= 1.0 { 1.0 } else { 0.1 * m * scale.ln() + 1.0 };
                if mscale != 0.0 && mscale_all_dim != 0.0 {
                    get(factor, mscale) / get(factor, mscale_all_dim)
                } else {
                    get(factor, 1.0)
                }
            }
        }
    }

    /// every parameter finite and in its range, and an attention factor of
    /// exactly 1 (the table class cannot carry another)
    pub(crate) fn check(&self) -> Result<(), String> {
        match *self {
            RopeScaling::None => {}
            RopeScaling::Llama3 { factor, low_freq_factor, high_freq_factor, original_max } => {
                if ![factor, low_freq_factor, high_freq_factor].iter().all(|v| v.is_finite() && *v > 0.0) || factor < 1.0 || high_freq_factor <= low_freq_factor || original_max == 0 {
                    return Err("rope scaling: a llama3 parameter is out of range".into());
                }
            }
            RopeScaling::Yarn { factor, original_max, beta_fast, beta_slow, mscale, mscale_all_dim, .. } => {
                if ![factor, beta_fast, beta_slow, mscale, mscale_all_dim].iter().all(|v| v.is_finite()) || factor < 1.0 || beta_fast <= 0.0 || beta_slow <= 0.0 || original_max == 0 {
                    return Err("rope scaling: a YaRN parameter is out of range".into());
                }
            }
        }
        if self.attention_factor() != 1.0 {
            return Err(format!(
                "rope scaling: the YaRN attention factor is {} — the RoPE tables are bounded by 2^F_RO (position 0 is (2^F_RO, 0)), so a profile whose attention factor is not exactly 1 is refused by name",
                self.attention_factor()
            ));
        }
        Ok(())
    }

    /// the canonical bytes a statement binds (`kind || every parameter`, f64
    /// as IEEE-754 bits, little-endian)
    pub(crate) fn encode(&self) -> Vec<u8> {
        let mut v = Vec::new();
        let f = |v: &mut Vec<u8>, x: f64| v.extend_from_slice(&x.to_bits().to_le_bytes());
        match *self {
            RopeScaling::None => v.extend_from_slice(b"none"),
            RopeScaling::Llama3 { factor, low_freq_factor, high_freq_factor, original_max } => {
                v.extend_from_slice(b"llama3");
                f(&mut v, factor);
                f(&mut v, low_freq_factor);
                f(&mut v, high_freq_factor);
                v.extend_from_slice(&original_max.to_le_bytes());
            }
            RopeScaling::Yarn { factor, original_max, beta_fast, beta_slow, mscale, mscale_all_dim, truncate } => {
                v.extend_from_slice(b"yarn");
                f(&mut v, factor);
                v.extend_from_slice(&original_max.to_le_bytes());
                f(&mut v, beta_fast);
                f(&mut v, beta_slow);
                f(&mut v, mscale);
                f(&mut v, mscale_all_dim);
                v.push(u8::from(truncate));
            }
        }
        v
    }

    /// the inverse of [`RopeScaling::encode`] (a statement record's bytes)
    pub(crate) fn decode(b: &[u8]) -> Result<RopeScaling, String> {
        let bad = || "rope scaling: an unreadable encoding".to_string();
        let f = |b: &[u8], at: usize| -> Result<f64, String> { Ok(f64::from_bits(u64::from_le_bytes(b.get(at..at + 8).ok_or_else(bad)?.try_into().map_err(|_| bad())?))) };
        let u = |b: &[u8], at: usize| -> Result<u64, String> { Ok(u64::from_le_bytes(b.get(at..at + 8).ok_or_else(bad)?.try_into().map_err(|_| bad())?)) };
        let out = if b == b"none" {
            RopeScaling::None
        } else if let Some(r) = b.strip_prefix(b"llama3") {
            if r.len() != 32 {
                return Err(bad());
            }
            RopeScaling::Llama3 { factor: f(r, 0)?, low_freq_factor: f(r, 8)?, high_freq_factor: f(r, 16)?, original_max: u(r, 24)? }
        } else if let Some(r) = b.strip_prefix(b"yarn") {
            if r.len() != 49 || r[48] > 1 {
                return Err(bad());
            }
            RopeScaling::Yarn { factor: f(r, 0)?, original_max: u(r, 8)?, beta_fast: f(r, 16)?, beta_slow: f(r, 24)?, mscale: f(r, 32)?, mscale_all_dim: f(r, 40)?, truncate: r[48] == 1 }
        } else {
            return Err(bad());
        };
        if out.encode() != b {
            return Err(bad());
        }
        Ok(out)
    }

    /// plain words for a statement or a log line
    pub(crate) fn describe(&self) -> String {
        match *self {
            RopeScaling::None => "none".into(),
            RopeScaling::Llama3 { factor, low_freq_factor, high_freq_factor, original_max } => format!("llama3 (factor {factor}, low {low_freq_factor}, high {high_freq_factor}, original {original_max})"),
            RopeScaling::Yarn { factor, original_max, beta_fast, beta_slow, mscale, mscale_all_dim, truncate } => {
                format!("yarn (factor {factor}, original {original_max}, beta {beta_fast}/{beta_slow}, mscale {mscale}/{mscale_all_dim}, truncate {truncate})")
            }
        }
    }
}

/// The inverse frequencies `inv_freq[i]`, `i < head_dim / 2`, at base
/// `theta`, by the reference formula of the transform (binary64).
pub(crate) fn inv_freq(head_dim: usize, theta: f64, s: &RopeScaling) -> Vec<f64> {
    let dim = head_dim;
    let half = dim / 2;
    // transformers: `base ** (arange(0, dim, 2) / dim)`, then `1 / that`
    let pos_freq: Vec<f64> = (0..half).map(|i| theta.powf((2 * i) as f64 / dim as f64)).collect();
    match *s {
        RopeScaling::None => (0..half).map(|i| theta.powf(-2.0 * i as f64 / dim as f64)).collect(),
        RopeScaling::Llama3 { factor, low_freq_factor, high_freq_factor, original_max } => {
            let old = original_max as f64;
            let (low_wl, high_wl) = (old / low_freq_factor, old / high_freq_factor);
            pos_freq
                .iter()
                .map(|p| {
                    let inv = 1.0 / p;
                    let wavelen = 2.0 * std::f64::consts::PI / inv;
                    let inv_llama = if wavelen > low_wl { inv / factor } else { inv };
                    let medium = !(wavelen < high_wl) && !(wavelen > low_wl);
                    if medium {
                        let smooth = (old / wavelen - low_freq_factor) / (high_freq_factor - low_freq_factor);
                        (1.0 - smooth) * inv_llama / factor + smooth * inv_llama
                    } else {
                        inv_llama
                    }
                })
                .collect()
        }
        RopeScaling::Yarn { factor, original_max, beta_fast, beta_slow, truncate, .. } => {
            let omax = original_max as f64;
            let corr = |rot: f64| (dim as f64 * (omax / (rot * 2.0 * std::f64::consts::PI)).ln()) / (2.0 * theta.ln());
            let (mut low, mut high) = (corr(beta_fast), corr(beta_slow));
            if truncate {
                low = low.floor();
                high = high.ceil();
            }
            let low = low.max(0.0);
            let mut high = high.min((dim - 1) as f64);
            if low == high {
                high += 0.001;
            }
            pos_freq
                .iter()
                .enumerate()
                .map(|(i, p)| {
                    let ramp = ((i as f64 - low) / (high - low)).clamp(0.0, 1.0);
                    let extra = 1.0 - ramp;
                    let (inv_extra, inv_inter) = (1.0 / p, 1.0 / (factor * p));
                    inv_inter * (1.0 - extra) + inv_extra * extra
                })
                .collect()
        }
    }
}

/// **The RoPE tables of a profile**: `cos` / `sin` at `t * inv_freq[i]`,
/// rounded half up at `2^f_ro`, row-major `(t, i)`. The unscaled case is the
/// frozen generator itself, so no existing table moves by one entry.
pub(crate) fn rope_tables(t_max: usize, head_dim: usize, theta: f64, s: &RopeScaling, f_ro: u32) -> Result<(Vec<i64>, Vec<i64>), String> {
    if *s == RopeScaling::None {
        return Ok(crate::tables_attn::rope_tables_generate(t_max, head_dim, theta, f_ro));
    }
    s.check()?;
    if !theta.is_finite() || theta <= 1.0 || head_dim < 2 || head_dim % 2 != 0 {
        return Err("rope scaling: the base or the head dimension is out of range".into());
    }
    let half = head_dim / 2;
    let scale = (f_ro as f64).exp2();
    let inv = inv_freq(head_dim, theta, s);
    let mut c = vec![0i64; t_max * half];
    let mut sn = vec![0i64; t_max * half];
    for (i, w) in inv.iter().enumerate() {
        for t in 0..t_max {
            let a = t as f64 * w;
            c[t * half + i] = round_half_up(a.cos() * scale);
            sn[t * half + i] = round_half_up(a.sin() * scale);
        }
    }
    Ok((c, sn))
}

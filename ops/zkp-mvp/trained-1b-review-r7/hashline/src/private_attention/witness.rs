//! The exact-integer attention-half witness (norm_a, QKV, RoPE, causal
//! softmax, PV, O, residual 1), recomputed from the private input with the
//! semantics of `private-block-kernel` / `causal_oracle::FixedCausalOracle`:
//! no clamping, a value outside its class is a refusal naming a static site.
//!
//! The returned planes are SECRET. Nothing here prints, hashes or serializes
//! them; a refusal carries a site name only (the refusal itself still depends
//! on the input, exactly as the kernel's does).

use super::layout::*;
use super::AttentionPublic;

pub(crate) struct Witness {
    /// one vector per witness plane, `N_WITNESS` of them, indexed by the `A_*` ids
    pub planes: Vec<Vec<i64>>,
}

impl Witness {
    /// the committed output plane xres1 (secret)
    pub(crate) fn output(&self) -> Result<Vec<i16>, String> {
        self.planes[A_X1].iter().map(|v| i16::try_from(*v).map_err(|_| "fixed oracle range refusal: residual 1".to_string())).collect()
    }
}

/// floor integer square root (integer only)
pub(crate) fn isqrt(v: u64) -> u64 {
    let mut rem = v;
    let mut res = 0u64;
    let mut bit = 1u64 << 62;
    while bit > v {
        bit >>= 2;
    }
    while bit != 0 {
        if rem >= res + bit {
            rem -= res + bit;
            res = (res >> 1) + bit;
        } else {
            res >>= 1;
        }
        bit >>= 2;
    }
    res
}

/// round to nearest, ties toward +inf: (y, remainder in [-2^(s-1), 2^(s-1)))
fn requant(acc: i64, sh: u32) -> (i64, i64) {
    let y = (acc + (1i64 << (sh - 1))) >> sh;
    (y, acc - (y << sh))
}

fn range(site: &'static str) -> String {
    format!("fixed oracle range refusal: {site}")
}

/// Requantize into the attention int8 subset; returns (values, biased remainder limb r + 2^(s-1)).
fn quantize(acc: &[i64], sh: u32, lo: i64, hi: i64, site: &'static str) -> Result<(Vec<i64>, Vec<i64>), String> {
    let mut y = Vec::with_capacity(acc.len());
    let mut r = Vec::with_capacity(acc.len());
    for &a in acc {
        let (q, rem) = requant(a, sh);
        if !(lo..=hi).contains(&q) {
            return Err(range(site));
        }
        y.push(q);
        r.push(rem + (1i64 << (sh - 1)));
    }
    Ok((y, r))
}

/// `out[t, j] = sum_i x[t, i] * w[j, i]`, `w` stored (output, input)
fn matmul(x: &[i64], w: &[i8], inner: usize, outer: usize) -> Vec<i64> {
    let mut out = vec![0i64; T * outer];
    for t in 0..T {
        for j in 0..outer {
            out[t * outer + j] = (0..inner).map(|i| x[t * inner + i] * i64::from(w[j * inner + i])).sum();
        }
    }
    out
}

/// half-split RoPE over `heads` heads per row
fn rotate(x: &[i64], heads: usize, cos: &[i64], sin: &[i64]) -> Vec<i64> {
    let width = heads * DH;
    let mut out = vec![0i64; T * width];
    for t in 0..T {
        for h in 0..heads {
            let base = t * width + h * DH;
            for i in 0..HALF {
                let (c, s) = (cos[t * HALF + i], sin[t * HALF + i]);
                let (a, b) = (x[base + i], x[base + HALF + i]);
                out[base + i] = c * a - s * b;
                out[base + HALF + i] = s * a + c * b;
            }
        }
    }
    out
}

fn limbs(v: i64, count: usize) -> Vec<i64> {
    (0..count).map(|k| if k + 1 == count { v >> (8 * k) } else { (v >> (8 * k)) & 255 }).collect()
}

pub(crate) fn build(public: &AttentionPublic, input: &[i16]) -> Result<Witness, String> {
    if input.len() != T * D {
        return Err("private attention: input shape".into());
    }
    let mut pl: Vec<Vec<i64>> = (0..N_WITNESS).map(|p| vec![0i64; a_dom(p).len()]).collect();
    let x: Vec<i64> = input.iter().map(|v| i64::from(*v)).collect();

    // ---- norm_a (round mode): D = isqrt(sum x^2 + Ceps), y = floor((2 x g Cn + D 2^tn) / (D 2^(tn+1))) ----
    let wrho = 1i64 << NORM_WRHO;
    for t in 0..T {
        let row = &x[t * D..(t + 1) * D];
        let ss: i64 = NORM_CEPS + row.iter().map(|v| v * v).sum::<i64>();
        let d = isqrt(ss as u64) as i64;
        let a1 = ss - d * d;
        let a2 = 2 * d - a1;
        if d >= 1 << 24 || !(0..1i64 << 24).contains(&a1) || !(0..1i64 << 24).contains(&a2) {
            return Err(range("norm denominator"));
        }
        pl[A_D][t] = d;
        pl[A_DSQ][t] = d * d;
        for (base, v) in [(0usize, d), (3, a1), (6, a2)] {
            for (k, l) in limbs(v, 3).into_iter().enumerate() {
                pl[A_LIMB][(base + k) * T + t] = l;
            }
        }
        let dv = d << NORM_TN;
        let den = 2 * dv;
        if den <= 0 {
            return Err(range("norm denominator"));
        }
        for i in 0..D {
            let num = 2 * row[i] * i64::from(public.gamma_a[i]) * NORM_CN + dv;
            let q = num.div_euclid(den);
            let rho = num.rem_euclid(den);
            let sigma = den - 1 - rho;
            if !(-127..=127).contains(&q) || rho >= wrho || sigma >= wrho {
                return Err(range("norm quotient/remainder"));
            }
            let idx = t * D + i;
            pl[A_Y][idx] = q;
            for (k, l) in limbs(rho, 4).into_iter().enumerate() {
                pl[A_NR0 + k][idx] = l;
            }
            for (k, l) in limbs(sigma, 4).into_iter().enumerate() {
                pl[A_NS0 + k][idx] = l;
            }
        }
    }
    for (idx, v) in x.iter().enumerate() {
        pl[A_X][idx] = *v;
        let l = limbs(v + 32768, 2);
        pl[A_XL0][idx] = l[0];
        pl[A_XL1][idx] = l[1];
    }

    // ---- QKV, RoPE ----
    let y = pl[A_Y].clone();
    let (q8, rql) = quantize(&matmul(&y, &public.wq, D, D), SH_QKV, -127, 127, "Q")?;
    let (k8, rkl) = quantize(&matmul(&y, &public.wk, D, KV), SH_QKV, -127, 127, "K")?;
    let (v8, rvl) = quantize(&matmul(&y, &public.wv, D, KV), SH_QKV, -127, 127, "V")?;
    let (qr8, rqrl) = quantize(&rotate(&q8, H, &public.rope_cos, &public.rope_sin), SH_ROPE, -127, 127, "QR")?;
    let (kr8, rkrl) = quantize(&rotate(&k8, 1, &public.rope_cos, &public.rope_sin), SH_ROPE, -127, 127, "KR")?;

    // ---- scores over ALL (h, t, j): an out-of-range masked score still refuses ----
    let mut sacc = vec![0i64; H * T * T];
    for h in 0..H {
        for t in 0..T {
            for j in 0..T {
                sacc[(h * T + t) * T + j] = (0..DH).map(|i| qr8[t * D + h * DH + i] * kr8[j * KV + i]).sum();
            }
        }
    }
    let (s8, rsl) = quantize(&sacc, SH_S, -127, 127, "score")?;

    // ---- causal softmax, PV ----
    let mut oacc = vec![0i64; T * D];
    for h in 0..H {
        for t in 0..T {
            let base = (h * T + t) * T;
            let masked = |j: usize| if j <= t { s8[base + j] } else { MASK_SCORE };
            let mut best = i64::MIN;
            let mut arg = 0usize;
            for j in 0..T {
                if masked(j) > best {
                    best = masked(j);
                    arg = j;
                }
            }
            if arg > t {
                return Err("fixed oracle relation failure: causal maximum attainment".into());
            }
            pl[A_MX][h * T + t] = best;
            pl[A_ZSEL][base + arg] = 1;
            let mut total = 0i64;
            for j in 0..T {
                let delta = best - masked(j);
                if !(0..256).contains(&delta) {
                    return Err(range("exp difference"));
                }
                pl[A_E][base + j] = public.exp[delta as usize];
                if j <= t {
                    total += pl[A_E][base + j];
                }
            }
            if !((1i64 << F_E)..=((T as i64) << F_E)).contains(&total) {
                return Err("fixed oracle relation failure: softmax denominator".into());
            }
            pl[A_SUM][h * T + t] = total;
            for j in 0..T {
                let (q, rho) = if j <= t {
                    let num = pl[A_E][base + j] << F_P;
                    (num / total, num % total)
                } else {
                    (0, 0)
                };
                let sigma = total - 1 - rho;
                if !(0..1i64 << WRHO_S).contains(&sigma) || !(0..=1i64 << F_P).contains(&q) {
                    return Err(range("softmax quotient/remainder"));
                }
                pl[A_P][base + j] = q;
                let (lp, lr, ls) = (limbs(q, 2), limbs(rho, 2), limbs(sigma, 2));
                pl[A_PL0][base + j] = lp[0];
                pl[A_PL1][base + j] = lp[1];
                pl[A_SR0][base + j] = lr[0];
                pl[A_SR1][base + j] = lr[1];
                pl[A_SG0][base + j] = ls[0];
                pl[A_SG1][base + j] = ls[1];
            }
            for i in 0..DH {
                // (t, h, i') order, the Q-domain layout of o8
                oacc[t * D + h * DH + i] = (0..=t).map(|j| pl[A_P][base + j] * v8[j * KV + i]).sum();
            }
        }
    }
    let (o8, ro) = quantize(&oacc, SH_O, -127, 127, "O")?;
    let (ao, ral) = quantize(&matmul(&o8, &public.wo, D, D), SH_AO, -32768, 32767, "AO")?;

    // ---- residual 1 (all three shifts are 0: xres1 = x + ao exactly) ----
    for idx in 0..T * D {
        let x1 = x[idx] + ao[idx];
        if !(-32768..=32767).contains(&x1) {
            return Err(range("residual 1"));
        }
        pl[A_X1][idx] = x1;
        let l = limbs(x1 + 32768, 2);
        pl[A_X1L0][idx] = l[0];
        pl[A_X1L1][idx] = l[1];
        let l = limbs(ao[idx] + 32768, 2);
        pl[A_AL0][idx] = l[0];
        pl[A_AL1][idx] = l[1];
        let l = limbs(ro[idx], 2);
        pl[A_RO0][idx] = l[0];
        pl[A_RO1][idx] = l[1];
    }
    pl[A_AO] = ao;
    pl[A_RAL] = ral;
    pl[A_Q8] = q8;
    pl[A_RQL] = rql;
    pl[A_QR8] = qr8;
    pl[A_RQRL] = rqrl;
    pl[A_O8] = o8;
    pl[A_K8] = k8;
    pl[A_RKL] = rkl;
    pl[A_V8] = v8;
    pl[A_RVL] = rvl;
    pl[A_KR8] = kr8;
    pl[A_RKRL] = rkrl;
    pl[A_S8] = s8;
    pl[A_RSL] = rsl;
    Ok(Witness { planes: pl })
}

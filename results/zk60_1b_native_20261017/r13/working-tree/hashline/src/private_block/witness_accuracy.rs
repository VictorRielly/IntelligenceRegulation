//! R13 integer execution, before its values are assigned to proof planes.
//!
//! This is not a proof entry point. Registered legacy profiles continue to
//! use the legacy builder until every R13 relation and range check is active.
use super::*;
use crate::private_block::accuracy_precision::BaseShifts;
use crate::private_block::accuracy_public::{AccuracyPublic, Geometry};

#[derive(Debug)]
pub(super) struct Quantized {
    pub words: Vec<i64>,
    /// Biased Euclidean remainder: acc*m + half - word*2^shift.
    pub rho: Vec<i64>,
}

pub(super) struct Norm {
    pub words: Vec<i64>,
    pub d: Vec<i64>,
    pub dsq: Vec<i64>,
    pub a1: Vec<i64>,
    pub a2: Vec<i64>,
    pub rho: Vec<i64>,
    pub sigma: Vec<i64>,
}

pub(super) struct Trace {
    pub x: Vec<i64>,
    pub na: Norm,
    pub q: Quantized,
    pub k: Quantized,
    pub v: Quantized,
    pub qr: Quantized,
    pub kr: Quantized,
    pub s: Quantized,
    pub mx: Vec<i64>,
    pub sum: Vec<i64>,
    pub zsel: Vec<i64>,
    pub e: Vec<i64>,
    pub p: Vec<i64>,
    pub sr: Vec<i64>,
    pub sg: Vec<i64>,
    pub o: Quantized,
    pub ao: Quantized,
    pub x1: Vec<i64>,
    pub nm: Norm,
    pub gate: Quantized,
    pub a_scaled: Vec<i64>,
    pub up: Quantized,
    pub h: Quantized,
    pub z: Quantized,
    pub x2: Vec<i64>,
}

fn quantized(
    acc: Vec<i64>,
    support: &[usize],
    shift: u32,
    mult: &[u64],
    stride: usize,
    lo: i64,
    hi: i64,
    site: &'static str,
) -> Result<Quantized, String> {
    let mut words = vec![0; acc.len()];
    let mut rho = vec![0; acc.len()];
    for &i in support {
        let r = crate::private_block::accuracy::requant(acc[i] as i128, mult[i % stride], shift)?;
        if !(lo..=hi).contains(&r.word) {
            return Err(range(site));
        }
        words[i] = r.word;
        rho[i] = i64::try_from(r.remainder).map_err(|_| range(site))?;
    }
    Ok(Quantized { words, rho })
}

fn normalized(g: &Geom, x: &[i64], gamma: &[i8], tn: u32, cn: i64) -> Result<Norm, String> {
    let mut out = Norm {
        words: vec![0; g.len(Dom::D)],
        d: vec![0; g.len(Dom::T)],
        dsq: vec![0; g.len(Dom::T)],
        a1: vec![0; g.len(Dom::T)],
        a2: vec![0; g.len(Dom::T)],
        rho: vec![0; g.len(Dom::D)],
        sigma: vec![0; g.len(Dom::D)],
    };
    for t in 0..g.t {
        let row = &x[t * g.d_pad..t * g.d_pad + g.d];
        let ss = g.s.norm_ceps + row.iter().map(|v| v * v).sum::<i64>();
        let d = isqrt(u64::try_from(ss).map_err(|_| range("norm denominator"))?) as i64;
        let (a1, a2) = (ss - d * d, 2 * d - (ss - d * d));
        if d == 0
            || [d, a1, a2]
                .iter()
                .any(|v| !(0..1i64 << (8 * LIMBS_ISQRT)).contains(v))
        {
            return Err(range("norm denominator"));
        }
        out.d[t] = d;
        out.dsq[t] = d * d;
        out.a1[t] = a1;
        out.a2[t] = a2;
        let dv = (d as i128) << tn;
        let denominator = 2 * dv;
        for i in 0..g.d {
            let numerator = 2 * row[i] as i128 * gamma[i] as i128 * cn as i128 + dv;
            let q = numerator.div_euclid(denominator);
            let r = numerator.rem_euclid(denominator);
            let s = denominator - 1 - r;
            if !(-32768..=32767).contains(&q) || r >= 1 << 24 || s >= 1 << 24 {
                return Err(range("norm quotient/remainder"));
            }
            let index = g.dix(t, i);
            out.words[index] = q as i64;
            out.rho[index] = r as i64;
            out.sigma[index] = s as i64;
        }
    }
    Ok(out)
}

fn residual(g: &Geom, x: &[i64], y: &[i64], site: &'static str) -> Result<Vec<i64>, String> {
    let mut out = vec![0; g.len(Dom::D)];
    for i in g.support(Dom::D) {
        out[i] = x[i]
            .checked_add(y[i])
            .filter(|v| (-32768..=32767).contains(v))
            .ok_or_else(|| range(site))?;
    }
    Ok(out)
}

pub(super) fn build(
    sh: &Shape,
    public: &AttentionPublic,
    ff: &FeedForwardPublic,
    accuracy: &AccuracyPublic,
    input: &[i16],
) -> Result<Trace, String> {
    public.check_for_shape(sh)?;
    ff.check_for_shape(sh)?;
    if [
        &public.wq,
        &public.wk,
        &public.wv,
        &public.wo,
        &public.gamma_a,
        &ff.wg_t,
        &ff.wu_t,
        &ff.wd_t,
        &ff.gamma_m,
    ]
    .into_iter()
    .any(|words| words.contains(&i8::MIN))
    {
        return Err("R13 public weights/gains must be symmetric int8".into());
    }
    let geometry = Geometry {
        width: sh.width,
        query_width: sh.q_width(),
        kv_width: sh.kv_heads * sh.head_dim,
        hidden: sh.hidden,
    };
    let base = BaseShifts {
        norm_tn: sh.norm_tn,
        qkv: sh.sh_qkv,
        score: sh.sh_s,
        pv: sh.sh_o,
        ao: sh.sh_ao,
        gate: sh.sh_g,
        up: 0,
        product: sh.sh_h,
        down: sh.sh_z,
    };
    accuracy.check_for(geometry, base, accuracy.stack())?;
    let (p, m, folds) = (
        accuracy.precision(),
        accuracy.multipliers(),
        accuracy.folds(),
    );
    let g = Geom::new(sh);
    if input.len() != g.t * g.d {
        return Err("R13 witness: input shape".into());
    }
    let (sd, sq, sk, ss, sf) = (
        g.support(Dom::D),
        g.support(Dom::Q),
        g.support(Dom::Kv),
        g.support(Dom::S),
        g.support(Dom::F),
    );
    let mut x = vec![0; g.len(Dom::D)];
    for (&i, &word) in sd.iter().zip(input) {
        x[i] = word as i64;
    }
    let na = normalized(&g, &x, &public.gamma_a, p.norm_tn, sh.norm_cn_a)?;
    let pad = |words: &[u16], width: usize| {
        let mut out = vec![1; width];
        for (dst, &word) in out.iter_mut().zip(words) {
            *dst = word as u64;
        }
        out
    };
    let mut mq = vec![1; g.q_pad];
    for h in 0..g.hq {
        for i in 0..g.dh {
            mq[g.slot(h) * g.dh + i] = m.q[h * g.dh + i] as u64;
        }
    }
    let q = quantized(
        matmul(
            &g,
            &na.words,
            g.d_pad,
            &public.wq,
            g.d_pad,
            g.q_pad,
            g.q_pad,
            g.len(Dom::Q),
        ),
        &sq,
        p.q,
        &mq,
        g.q_pad,
        -32768,
        32767,
        "Q",
    )?;
    let k = quantized(
        matmul(
            &g,
            &na.words,
            g.d_pad,
            &public.wk,
            g.d_pad,
            g.kvw,
            g.kvw,
            g.len(Dom::Kv),
        ),
        &sk,
        p.k,
        &pad(&m.k, g.kvw),
        g.kvw,
        -32768,
        32767,
        "K",
    )?;
    let v = quantized(
        matmul(
            &g,
            &na.words,
            g.d_pad,
            &public.wv,
            g.d_pad,
            g.kvw,
            g.kvw,
            g.len(Dom::Kv),
        ),
        &sk,
        p.v,
        &pad(&m.v, g.kvw),
        g.kvw,
        -32768,
        32767,
        "V",
    )?;
    let qr = quantized(
        rotate(
            &g,
            &q.words,
            g.h_pad,
            g.q_pad,
            g.len(Dom::Q),
            &public.rope_cos,
            &public.rope_sin,
        ),
        &sq,
        SH_ROPE,
        &[1],
        1,
        -32768,
        32767,
        "QR",
    )?;
    let kr = quantized(
        rotate(
            &g,
            &k.words,
            g.hkv,
            g.kvw,
            g.len(Dom::Kv),
            &public.rope_cos,
            &public.rope_sin,
        ),
        &sk,
        SH_ROPE,
        &[1],
        1,
        -32768,
        32767,
        "KR",
    )?;
    let mut sacc = vec![0; g.len(Dom::S)];
    for h in 0..g.hq {
        for t in 0..g.t {
            for j in 0..g.t {
                sacc[g.six(g.slot(h), t, j)] = (0..g.dh)
                    .map(|i| qr.words[g.qix(t, g.slot(h), i)] * kr.words[g.kvix(j, h / g.group, i)])
                    .sum();
            }
        }
    }
    // This includes masked future scores. Their range is still checked.
    let s = quantized(sacc, &ss, p.score, &[1], 1, -127, 127, "score")?;
    let mut mx = vec![0; g.len(Dom::Ht)];
    let mut sum = mx.clone();
    let mut zsel = vec![0; g.len(Dom::S)];
    let mut e = zsel.clone();
    let mut probability = zsel.clone();
    let mut sr = zsel.clone();
    let mut sg = zsel.clone();
    let mut oacc = vec![0; g.len(Dom::Q)];
    for h in 0..g.hq {
        for t in 0..g.t {
            let hs = g.slot(h);
            let best = (0..=t).map(|j| s.words[g.six(hs, t, j)]).max().unwrap();
            let arg = (0..=t).find(|&j| s.words[g.six(hs, t, j)] == best).unwrap();
            mx[g.htix(hs, t)] = best;
            zsel[g.six(hs, t, arg)] = 1;
            let total: i64 = (0..=t)
                .map(|j| public.exp[(best - s.words[g.six(hs, t, j)]) as usize])
                .sum();
            if total <= 0 {
                return Err(range("softmax"));
            }
            sum[g.htix(hs, t)] = total;
            for j in 0..g.t {
                let index = g.six(hs, t, j);
                let masked = if j <= t { s.words[index] } else { MASK_SCORE };
                let delta = best - masked;
                if !(0..256).contains(&delta) {
                    return Err(range("exp difference"));
                }
                e[index] = public.exp[delta as usize];
                let numerator = if j <= t { e[index] << p.f_p } else { 0 };
                probability[index] = numerator / total;
                sr[index] = numerator % total;
                sg[index] = total - 1 - sr[index];
                if sg[index] >= 1 << sh.wrho_s {
                    return Err(range("softmax"));
                }
            }
            for i in 0..g.dh {
                oacc[g.qix(t, hs, i)] = (0..=t)
                    .map(|j| probability[g.six(hs, t, j)] * v.words[g.kvix(j, h / g.group, i)])
                    .sum();
            }
        }
    }
    // The ungated exp lookup also covers padded score coordinates.
    for index in 0..e.len() {
        let (ht, j) = (index / g.t_pad, index % g.t_pad);
        let masked = if j <= ht % g.t_pad {
            s.words[index]
        } else {
            MASK_SCORE
        };
        let delta = mx[ht] - masked;
        if !(0..256).contains(&delta) {
            return Err(range("exp difference"));
        }
        e[index] = public.exp[delta as usize];
    }
    let o = quantized(oacc, &sq, p.pv, &[1], 1, -32768, 32767, "O")?;
    let ao = quantized(
        matmul(
            &g,
            &o.words,
            g.q_pad,
            &public.wo,
            g.q_pad,
            g.d_pad,
            g.d_pad,
            g.len(Dom::D),
        ),
        &sd,
        p.ao,
        &pad(&m.o, g.d_pad),
        g.d_pad,
        -32768,
        32767,
        "AO",
    )?;
    let x1 = residual(&g, &x, &ao.words, "residual 1")?;
    let nm = normalized(&g, &x1, &ff.gamma_m, p.norm_tn, sh.norm_cn_m)?;
    let mut mg = vec![1; g.f_pad];
    mg[..g.f].copy_from_slice(&folds.gate.multipliers);
    let gate = quantized(
        matmul_in_out(
            &g,
            &nm.words,
            g.d_pad,
            &ff.wg_t,
            g.d_pad,
            g.f_pad,
            g.f_pad,
            g.len(Dom::F),
        ),
        &sf,
        folds.gate.shift,
        &mg,
        g.f_pad,
        -2048,
        2047,
        "FFN gate",
    )?;
    let up = quantized(
        matmul_in_out(
            &g,
            &nm.words,
            g.d_pad,
            &ff.wu_t,
            g.d_pad,
            g.f_pad,
            g.f_pad,
            g.len(Dom::F),
        ),
        &sf,
        p.up,
        &pad(&m.u, g.f_pad),
        g.f_pad,
        -32768,
        32767,
        "FFN up",
    )?;
    let mut a_scaled = vec![0; g.len(Dom::F)];
    for &i in &sf {
        a_scaled[i] = accuracy.scaled_tables()[accuracy.group_ids()[i % g.f_pad]]
            [(gate.words[i] + 2048) as usize];
    }
    let hacc = a_scaled.iter().zip(&up.words).map(|(a, u)| a * u).collect();
    let bias = 1i64 << (p.product_bits - 1);
    let h = quantized(
        hacc,
        &sf,
        folds.product.shift,
        &[1],
        1,
        -bias,
        bias - 1,
        "FFN product",
    )?;
    let z = quantized(
        matmul_in_out(
            &g,
            &h.words,
            g.f_pad,
            &ff.wd_t,
            g.f_pad,
            g.d_pad,
            g.d_pad,
            g.len(Dom::D),
        ),
        &sd,
        p.down,
        &pad(&m.d, g.d_pad),
        g.d_pad,
        -32768,
        32767,
        "FFN down",
    )?;
    let x2 = residual(&g, &x1, &z.words, "residual 2")?;
    Ok(Trace {
        x,
        na,
        q,
        k,
        v,
        qr,
        kr,
        s,
        mx,
        sum,
        zsel,
        e,
        p: probability,
        sr,
        sg,
        o,
        ao,
        x1,
        nm,
        gate,
        a_scaled,
        up,
        h,
        z,
        x2,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::accuracy_groups::Group;
    use crate::private_block::accuracy_precision::Stack;
    use crate::private_block::accuracy_public::Multipliers;
    use std::collections::BTreeMap;

    fn parse(text: &str) -> BTreeMap<&str, Vec<i64>> {
        text.lines()
            .map(|line| {
                let mut cells = line.split('\t');
                (
                    cells.next().unwrap(),
                    cells.map(|s| s.parse().unwrap()).collect(),
                )
            })
            .collect()
    }

    fn fixture(
        stack: Stack,
    ) -> (
        Shape,
        AttentionPublic,
        FeedForwardPublic,
        AccuracyPublic,
        Vec<i16>,
    ) {
        let f = parse(include_str!("r13_vectors/block_fixture_t32.tsv"));
        let mut sh = Shape::new(
            "R13 trace fixture",
            "r13-trace-fixture",
            32,
            16,
            32,
            4,
            4,
            2,
            8,
            8,
            9,
            7,
            None,
            None,
            None,
            None,
        )
        .unwrap();
        // This test exercises execution only, not a registered proof profile.
        sh.norm_tn = 10;
        sh.norm_cn_a = 200;
        sh.norm_cn_m = 180;
        sh.norm_ceps = 123;
        sh.sh_qkv = 8;
        sh.sh_s = 6;
        sh.sh_o = 9;
        sh.sh_ao = 7;
        sh.sh_g = 8;
        sh.sh_h = 14;
        sh.sh_z = 6;
        let i8s = |key: &str| {
            f[key]
                .iter()
                .map(|&v| i8::try_from(v).unwrap())
                .collect::<Vec<_>>()
        };
        let transpose = |key: &str, rows: usize, cols: usize| {
            let w = &f[key];
            (0..cols)
                .flat_map(|j| (0..rows).map(move |i| i8::try_from(w[i * cols + j]).unwrap()))
                .collect::<Vec<_>>()
        };
        let public = AttentionPublic::new_shaped(
            &sh,
            &transpose("w_q", 16, 16),
            &transpose("w_k", 16, 8),
            &transpose("w_v", 16, 8),
            &transpose("w_o", 16, 16),
            &i8s("gamma"),
            &f["cos"],
            &f["sin"],
            &f["exp"],
        )
        .unwrap();
        let ff = FeedForwardPublic::new_shaped(
            &sh,
            &i8s("gamma"),
            &i8s("w_g"),
            &i8s("w_u"),
            &i8s("w_d"),
            &[0; 256],
        )
        .unwrap();
        let ms = |key: &str| {
            f[key]
                .iter()
                .map(|&v| u16::try_from(v).unwrap())
                .collect::<Vec<_>>()
        };
        let groups: Vec<Group> = f["members"]
            .chunks_exact(2)
            .map(|v| Group {
                e_in: v[0] as i32,
                e_out: v[1] as i32,
            })
            .collect();
        let tables = groups
            .iter()
            .map(|g| {
                crate::private_block::accuracy_tables::silu_table(g.e_in, g.e_out, 12).unwrap()
            })
            .collect();
        let accuracy = AccuracyPublic::new(
            stack,
            Geometry {
                width: 16,
                query_width: 16,
                kv_width: 8,
                hidden: 32,
            },
            BaseShifts {
                norm_tn: 10,
                qkv: 8,
                score: 6,
                pv: 9,
                ao: 7,
                gate: 8,
                up: 0,
                product: 14,
                down: 6,
            },
            (-3, -11),
            Multipliers {
                q: ms("m_q"),
                k: ms("m_k"),
                v: ms("m_v"),
                o: ms("m_o"),
                g: ms("m_g"),
                u: ms("m_u"),
                d: ms("m_d"),
            },
            groups,
            f["groups"].iter().map(|&v| v as usize).collect(),
            tables,
        )
        .unwrap();
        let input = f["input"]
            .iter()
            .map(|&v| i16::try_from(v).unwrap())
            .collect();
        (sh, public, ff, accuracy, input)
    }

    #[test]
    fn both_export_stacks_match_the_independent_full_block_oracle() {
        for (stack, expected) in [
            (
                Stack::Low,
                include_str!("r13_vectors/block_trace_low_t32.tsv"),
            ),
            (
                Stack::LowH24,
                include_str!("r13_vectors/block_trace_low_h24_t32.tsv"),
            ),
        ] {
            let (sh, public, ff, accuracy, input) = fixture(stack);
            let trace = build(&sh, &public, &ff, &accuracy, &input).unwrap();
            let expected = parse(expected);
            let g = Geom::new(&sh);
            let sites: [(&str, Dom, &[i64]); 18] = [
                ("y", Dom::D, &trace.na.words),
                ("q", Dom::Q, &trace.q.words),
                ("k", Dom::Kv, &trace.k.words),
                ("v", Dom::Kv, &trace.v.words),
                ("qr", Dom::Q, &trace.qr.words),
                ("kr", Dom::Kv, &trace.kr.words),
                ("s", Dom::S, &trace.s.words),
                ("p", Dom::S, &trace.p),
                ("o8", Dom::Q, &trace.o.words),
                ("ao", Dom::D, &trace.ao.words),
                ("x1", Dom::D, &trace.x1),
                ("nm", Dom::D, &trace.nm.words),
                ("gate", Dom::F, &trace.gate.words),
                ("a_scaled", Dom::F, &trace.a_scaled),
                ("u16", Dom::F, &trace.up.words),
                ("h16", Dom::F, &trace.h.words),
                ("z16", Dom::D, &trace.z.words),
                ("x2", Dom::D, &trace.x2),
            ];
            for (name, domain, actual) in sites {
                let dense: Vec<_> = g.support(domain).into_iter().map(|i| actual[i]).collect();
                assert_eq!(dense, expected[name], "{stack:?}: {name}");
            }
            assert!(trace
                .na
                .rho
                .iter()
                .chain(&trace.na.sigma)
                .chain(&trace.nm.rho)
                .chain(&trace.nm.sigma)
                .all(|&r| (0..1 << 24).contains(&r)));
            assert!(trace.q.words.iter().any(|v| v.abs() > 127));
            assert!(trace.up.rho.iter().any(|&r| r != 0));
        }
    }

    #[test]
    fn future_scores_are_range_checked_before_the_causal_mask() {
        let (sh, public, ff, accuracy, input) = fixture(Stack::LowH24);
        // This out-of-range score is a future position of the first row.
        // It must enter the quantizer before the causal mask is applied.
        let mut acc = vec![0; sh.size(Dom::S)];
        acc[Geom::new(&sh).six(0, 0, 31)] = 128 << accuracy.precision().score;
        assert!(quantized(
            acc,
            &Geom::new(&sh).support(Dom::S),
            accuracy.precision().score,
            &[1],
            1,
            -127,
            127,
            "score"
        )
        .unwrap_err()
        .contains("score"));
        // The honest fixture remains accepted by the complete executor.
        build(&sh, &public, &ff, &accuracy, &input).unwrap();
    }

    #[test]
    fn amended_int16_endpoints_and_rope_accumulators_do_not_wrap() {
        let q = quantized(vec![-65536, 65534], &[0, 1], 1, &[1], 1, -32768, 32767, "Q").unwrap();
        assert_eq!(q.words, vec![-32768, 32767]);
        for bad in [-65538, 65536] {
            assert!(quantized(vec![bad], &[0], 1, &[1], 1, -32768, 32767, "Q").is_err());
        }
        let (mut sh, mut public, _, _, _) = fixture(Stack::LowH24);
        sh.norm_ceps = 1;
        let g = Geom::new(&sh);
        let mut x = vec![0; g.len(Dom::D)];
        x[0] = -1;
        let n = normalized(&g, &x, &vec![1; g.d_pad], 2, 1 << 17).unwrap();
        assert_eq!(n.words[0], -32768);
        let mut q = vec![0; g.len(Dom::Q)];
        q[g.qix(1, 0, 0)] = -32768;
        public.rope_cos[g.half] = 128;
        public.rope_sin[g.half] = 0;
        let rotated = rotate(
            &g,
            &q,
            g.h_pad,
            g.q_pad,
            g.len(Dom::Q),
            &public.rope_cos,
            &public.rope_sin,
        );
        let accepted = quantized(
            rotated,
            &g.support(Dom::Q),
            SH_ROPE,
            &[1],
            1,
            -32768,
            32767,
            "QR",
        )
        .unwrap();
        assert_eq!(accepted.words[g.qix(1, 0, 0)], -32768);
        public.rope_cos[g.half] = -128;
        let rotated = rotate(
            &g,
            &q,
            g.h_pad,
            g.q_pad,
            g.len(Dom::Q),
            &public.rope_cos,
            &public.rope_sin,
        );
        assert!(quantized(
            rotated,
            &g.support(Dom::Q),
            SH_ROPE,
            &[1],
            1,
            -32768,
            32767,
            "QR"
        )
        .is_err());
    }

    #[test]
    fn new_execution_rejects_public_negative_128_weights() {
        let (sh, mut public, ff, accuracy, input) = fixture(Stack::LowH24);
        public.wq[0] = -128;
        assert!(build(&sh, &public, &ff, &accuracy, &input)
            .err()
            .unwrap()
            .contains("symmetric int8"));
    }
}

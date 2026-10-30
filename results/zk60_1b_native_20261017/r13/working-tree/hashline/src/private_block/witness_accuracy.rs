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
    let registry=sh.accuracy_registry();
    accuracy.check_for_registry(registry, geometry, base, accuracy.stack())?;
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

// Assign the independently tested integer trace to R13's explicit roles.
// This helper does not activate a proof profile or assert that host relations
// are integrated. Histogram planes remain empty for the protocol to derive.
pub(super) fn assign(
    sh: &Shape, public: &AttentionPublic, data: &AccuracyPublic, trace: Trace,
) -> Result<Witness,String> {
    use crate::private_block::accuracy_layout::{AccuracyIds,Limbs as L};
    let g=Geom::new(sh);
    let ids=AccuracyIds::new(data.stack(),sh.dd_cap>0,sh.limbs_sigma_s())?;
    let mut planes:Vec<Vec<i64>>=ids.doms.iter().map(|&d| if d==Dom::Tab {Vec::new()} else {vec![0;g.len(d)]}).collect();
    let write=|planes:&mut Vec<Vec<i64>>,old:usize,words:Vec<i64>| -> Result<(),String> {
        let at=ids.map[old];
        if at==usize::MAX || words.len()!=g.len(ids.doms[at]) {return Err("R13 witness: word plane shape mismatch".into());}
        planes[at]=words; Ok(())
    };
    let decompose=|planes:&mut Vec<Vec<i64>>,role:L,values:&[i64],bias:i64| -> Result<(),String> {
        let count=ids.count(role); let dom=ids.doms[ids.limb(role,0)];
        if values.len()!=g.len(dom) {return Err("R13 witness: limb source shape mismatch".into());}
        for i in g.support(dom) {
            let value=values[i].checked_add(bias).filter(|&v| v>=0 && v<(1i64<<(8*count)))
                .ok_or_else(||range("R13 limb decomposition"))?;
            for k in 0..count {planes[ids.limb(role,k)][i]=(value>>(8*k))&255;}
        }
        Ok(())
    };
    let norm=|planes:&mut Vec<Vec<i64>>,n:&Norm,d:usize,dsq:usize,l:usize,nr:L,ns:L,y:L| -> Result<(),String> {
        write(planes,d,n.d.clone())?; write(planes,dsq,n.dsq.clone())?;
        let mut packed=vec![0;g.len(Dom::L)];
        for (component,values) in [&n.d,&n.a1,&n.a2].into_iter().enumerate() {
            for t in 0..g.t {
                if !(0..1<<24).contains(&values[t]) {return Err(range("R13 isqrt limbs"));}
                for k in 0..LIMBS_ISQRT {packed[g.lix(component*LIMBS_ISQRT+k,t)]=(values[t]>>(8*k))&255;}
            }
        }
        write(planes,l,packed)?; decompose(planes,nr,&n.rho,0)?; decompose(planes,ns,&n.sigma,0)?;
        decompose(planes,y,&n.words,32768)
    };
    norm(&mut planes,&trace.na,A_D,A_DSQ,A_LIMB,L::Nr,L::Ns,L::Y)?;
    norm(&mut planes,&trace.nm,A_DM,A_DSQM,A_LIMBM,L::Mr,L::Ms,L::Ym)?;
    for (role,values,bias) in [(L::X,&trace.x,32768),(L::Ao,&trace.ao.words,32768),
        (L::Rao,&trace.ao.rho,0),(L::X1,&trace.x1,32768),(L::Z,&trace.z.words,32768),
        (L::Rd,&trace.z.rho,0),(L::X2,&trace.x2,32768),
        (L::Q,&trace.q.words,32768),(L::Rq,&trace.q.rho,0),(L::Qr,&trace.qr.words,32768),(L::Rqr,&trace.qr.rho,0),
        (L::O,&trace.o.words,32768),(L::Ro,&trace.o.rho,0),(L::K,&trace.k.words,32768),(L::Rk,&trace.k.rho,0),
        (L::V,&trace.v.words,32768),(L::Rv,&trace.v.rho,0),(L::Kr,&trace.kr.words,32768),(L::Rkr,&trace.kr.rho,0),
        (L::Rs,&trace.s.rho,0),(L::Rg,&trace.gate.rho,0),(L::Up,&trace.up.words,32768),
        (L::Ru,&trace.up.rho,0),(L::H,&trace.h.words,1i64<<(data.precision().product_bits-1)),(L::Rh,&trace.h.rho,0)] {
        decompose(&mut planes,role,values,bias)?;
    }
    if sh.dd_cap==0 {
        decompose(&mut planes,L::P,&trace.p,0)?;
        decompose(&mut planes,L::Sr,&trace.sr,0)?;
        decompose(&mut planes,L::Sg,&trace.sg,0)?;
    } else {
        sh.check_dd_geometry()?;
        let column=public.dd_e_column(sh.dd_cap)?;
        let mut q=vec![0;g.len(Dom::Dd)]; let mut rho=q.clone();let mut sigma=q.clone();let mut counts=q.clone();
        for h in 0..g.hq {for t in 0..g.t {
            let hs=g.slot(h);let total=trace.sum[g.htix(hs,t)];let base=(hs*g.t_pad+t)*sh.dd_cap;
            if total<=0 {return Err(range("R13 dictionary denominator"));}
            for (k,&e) in column.iter().enumerate() {
                let numerator=e.checked_shl(data.precision().f_p).ok_or_else(||range("R13 dictionary numerator"))?;
                q[base+k]=numerator/total;rho[base+k]=numerator%total;sigma[base+k]=total-1-rho[base+k];
                if !(0..=1<<data.precision().f_p).contains(&q[base+k])
                    || !(0..1i64<<sh.wrho_s).contains(&sigma[base+k]) {return Err(range("R13 dictionary quotient/remainder"));}
            }
            for j in 0..g.t_pad {
                let e=if j<=t {trace.e[g.six(hs,t,j)]} else {0};
                let k=column.iter().position(|&word|word==e).ok_or_else(||range("R13 dictionary column"))?;
                counts[base+k]+=1;
            }
        }}
        decompose(&mut planes,L::P,&q,0)?;decompose(&mut planes,L::Sr,&rho,0)?;decompose(&mut planes,L::Sg,&sigma,0)?;
        planes[ids.pdict]=q;planes[ids.mdd]=counts;
    }
    for (old,values) in [(A_X,trace.x),(A_Y,trace.na.words),(A_YM,trace.nm.words),
        (A_Q8,trace.q.words),(A_K8,trace.k.words),(A_V8,trace.v.words),(A_QR8,trace.qr.words),(A_KR8,trace.kr.words),
        (A_S8,trace.s.words),(A_MX,trace.mx),(A_SUM,trace.sum),(A_ZSEL,trace.zsel),(A_E,trace.e),(A_P,trace.p),
        (A_O8,trace.o.words),(A_AO,trace.ao.words),(A_X1,trace.x1),(A_G8,trace.gate.words),
        (A_A16,trace.a_scaled),(A_U16,trace.up.words),(A_H16,trace.h.words),(A_Z16,trace.z.words),(A_X2,trace.x2)] {
        write(&mut planes,old,values)?;
    }
    Ok(Witness {planes,output_plane:ids.map[A_X2]})
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
            // This oracle fixture has Q in [-70,88]. Its widened norm and
            // up words exercise values outside int8; Q/QR endpoints have
            // their own signed16 boundary/rotation controls below.
            assert!(trace.na.words.iter().any(|v| v.abs() > 127));
            assert!(trace.up.words.iter().any(|v| v.abs() > 127));
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
    #[test]
    fn both_accuracy_stacks_assign_all_words_to_distinct_native_planes_and_recover_the_output() {
        use crate::private_block::accuracy_layout::{AccuracyIds,Limbs as L};
        for stack in [Stack::Low,Stack::LowH24] {
            let (sh,public,ff,data,input)=fixture(stack);
            let trace=build(&sh,&public,&ff,&data,&input).unwrap();
            let expected=trace.x2.clone();
            let mut witness=assign(&sh,&public,&data,trace).unwrap();
            let ids=AccuracyIds::new(stack,false,sh.limbs_sigma_s()).unwrap();
            let g=Geom::new(&sh);
            for (old,role,bias) in [(A_X,L::X,32768),(A_Y,L::Y,32768),(A_YM,L::Ym,32768),(A_Q8,L::Q,32768),
                (A_K8,L::K,32768),(A_V8,L::V,32768),(A_QR8,L::Qr,32768),(A_KR8,L::Kr,32768),
                (A_O8,L::O,32768),(A_AO,L::Ao,32768),(A_X1,L::X1,32768),(A_U16,L::Up,32768),
                (A_H16,L::H,1i64<<(data.precision().product_bits-1)),(A_Z16,L::Z,32768),(A_X2,L::X2,32768)] {
                for i in g.support(ids.doms[ids.map[old]]) {
                    let reconstructed:i64=(0..ids.count(role)).map(|k|witness.planes[ids.limb(role,k)][i]<<(8*k)).sum();
                    assert_eq!(witness.planes[ids.map[old]][i]+bias,reconstructed,"{role:?}[{i}]");
                }
            }
            for dom in [Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F] {
                let lookups=ids.lookups(dom,data.precision(),data.folds().gate.shift,sh.wrho_s).unwrap();
                for lk in lookups {for i in 0..g.len(dom) {
                    let value=lk.terms.iter().fold(lk.cst,|s,&(p,c)|s+c*witness.planes[p][i]);
                    assert!((0..256).contains(&value),"{dom:?} position {i}");
                }}
            }
            for &old in &[A_MU8,A_MEXP,A_MACT] {assert!(witness.planes[ids.map[old]].is_empty());}
            assert_eq!(witness.output().unwrap(),expected.iter().map(|&v|v as i16).collect::<Vec<_>>());
            assert_ne!(ids.map[A_X2],A_X2);
            witness.planes[A_X2].fill(12345);
            assert_eq!(witness.output().unwrap(),expected.iter().map(|&v|v as i16).collect::<Vec<_>>());
        }
    }

    #[test]
    fn dictionary_assignment_uses_fp12_on_every_slot_including_repeated_padding_zeros() {
        use crate::private_block::accuracy_layout::{AccuracyIds,Limbs as L};
        for stack in [Stack::Low,Stack::LowH24] {
            let (mut sh,mut public,ff,data,input)=fixture(stack);
            sh.dd_cap=32;
            public.exp=vec![512;256];
            let trace=build(&sh,&public,&ff,&data,&input).unwrap();
            let expected=trace.p.clone();let totals=trace.sum.clone();
            let witness=assign(&sh,&public,&data,trace).unwrap();
            let ids=AccuracyIds::new(stack,true,sh.limbs_sigma_s()).unwrap();
            let column=public.dd_e_column(sh.dd_cap).unwrap();let g=Geom::new(&sh);
            assert!(column.iter().filter(|&&v|v==0).count()>1);
            for h in 0..g.hq {for t in 0..g.t {
                let hs=g.slot(h);let base=(hs*g.t_pad+t)*sh.dd_cap;let total=totals[g.htix(hs,t)];
                assert_eq!(witness.planes[ids.mdd][base..base+sh.dd_cap].iter().sum::<i64>(),g.t_pad as i64);
                for (k,&e) in column.iter().enumerate() {
                    let q=witness.planes[ids.pdict][base+k];
                    let read=|role| (0..ids.count(role)).map(|j|witness.planes[ids.limb(role,j)][base+k]<<(8*j)).sum::<i64>();
                    let (rho,sigma)=(read(L::Sr),read(L::Sg));
                    assert_eq!(q,read(L::P));assert_eq!(q*total+rho,e<<12);assert_eq!(rho+sigma+1,total);
                    if e==0 && k>0 {assert_eq!(witness.planes[ids.mdd][base+k],0);}
                }
                for j in 0..g.t {assert_eq!(witness.planes[ids.map[A_P]][g.six(hs,t,j)],expected[g.six(hs,t,j)]);}
            }}
        }
    }

}

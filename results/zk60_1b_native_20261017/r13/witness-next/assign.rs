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

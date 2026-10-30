//! R13 host relations, staged behind the shared proof-activation refusal.
use super::*;
use crate::private_block::accuracy_layout::{AccuracyIds,Limbs as L};

fn role(b:&B<'_>,ids:&AccuracyIds,group:L)->Result<Vec<usize>,String> {
    let ix:Vec<_>=(0..ids.count(group)).map(|k|b.tab(ids.limb(group,k))).collect();
    if ix.contains(&usize::MAX) {return Err("R13 relation references a limb outside its claimed domain".into());}
    Ok(ix)
}

pub(super) fn define_changed(slot:usize,ctx:&Ctx<'_>,pts:&mut Points,tr:&mut Transcript)->Result<Option<SlotDef>,String> {
    let sh=ctx.lay.shape();
    let data=ctx.accuracy.ok_or("R13 relation requires bound accuracy public data")?;
    let geometry=crate::private_block::accuracy_public::Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    data.check_for_registry(sh.accuracy_registry(),geometry,sh.accuracy_base(),sh.accuracy_stack())?;
    if data.folds().gate.shift!=sh.accuracy_gate_shift {return Err("R13 relation common gate shift differs from the public data".into());}
    match slot {
        SC_DZC=>dzc(ctx,pts,tr).map(Some),
        SC_FZC=>fzc(ctx,pts,tr).map(Some),
        SC_QZC|SC_KVZC=>qzc(slot,ctx,pts,tr).map(Some),
        // Remaining R13 changed slots are added before activation. The
        // shared BlockPublic refusal prevents a partial proof entry point.
        _=>Ok(None),
    }
}

fn dzc(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());let low=ids.accuracy()?;
    let precision=sh.accuracy_precision()?;let cube=sh.size(Dom::D);let mut b=B::new(lay,SC_DZC);
    let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::D).is_empty();
    let n_help=sh.helpers(Dom::D);let mu=tr.challenge_fp2_vec(13+n_help+usize::from(pad_on));
    let nu=nonzero(tr.challenge_fp2_vec(2))?;let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};
    b.eq(&tr.challenge_fp2_vec(sh.log(Dom::D)),0);b.eq(&pts.p_a,0);b.eq(&pts.p_z,0);
    let ig=b.public((0..cube).map(|i|k(ctx.public.gamma_a[i%sh.d_pad] as i64)).collect());
    let igm=b.public((0..cube).map(|i|k(ctx.ff.gamma_m[i%sh.d_pad] as i64)).collect());
    let range=ids.domain_range(Dom::D)?;let idx=b.a_range(range.start,range.end-1)?;
    let (nr,ns,mr,ms)=(role(&b,low,L::Nr)?,role(&b,low,L::Ns)?,role(&b,low,L::Mr)?,role(&b,low,L::Ms)?);
    let(xl,yl,al,ral,x1l,yml,zl,rdl,x2l)=(role(&b,low,L::X)?,role(&b,low,L::Y)?,role(&b,low,L::Ao)?,role(&b,low,L::Rao)?,
        role(&b,low,L::X1)?,role(&b,low,L::Ym)?,role(&b,low,L::Z)?,role(&b,low,L::Rd)?,role(&b,low,L::X2)?);
    let lt=lg(sh.t_pad);
    let id=b.a_slice(lay.a_off[ids.at(A_D)],lt,rho(0..lt),0)?;
    let idm=b.a_slice(lay.a_off[ids.at(A_DM)],lt,rho(0..lt),0)?;
    let h0=b.h(hids.first_helper(Dom::D))?;for j in 1..n_help {b.h(hids.helper(Dom::D,j))?;}
    let lks=lk_tables(lay,Dom::D,&b.shaped,ctx.g_u8);
    let gd=Gate(b.supp(Dom::D,cube)?);let mut pz=PadTerm::none();
    if pad_on {
        let planes:Vec<_>=crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::D).iter().map(|&p|b.tab(p)).collect();
        pz.mu=mu[13+n_help];pz.add(gd.0,&planes,zeta);
    }
    let (num,num_m,dv,den)=(k(2*sh.norm_cn_a),k(2*sh.norm_cn_m),k(1i64<<precision.norm_tn),k(1i64<<(precision.norm_tn+1)));
    let alpha=ctx.alpha;let hosted=vec![(SC_WO,nu[0]),(SC_DMM,nu[1])];
    let poly=move |v:&[Fp2]| {
        let at=|old|v[idx[old]];let lb=|ix:&[usize]|limbs(v,ix);
        let(x,y,ao,x1,ym,z,x2)=(at(A_X),at(A_Y),at(A_AO),at(A_X1),at(A_YM),at(A_Z16),at(A_X2));
        let (d,dm)=(v[id],v[idm]);let(kd,kdm)=(den.mul(d),den.mul(dm));
        let(nr,ns,mr,ms)=(lb(&nr),lb(&ns),lb(&mr),lb(&ms));
        let clauses=[v[ig].mul(x).mul(num).add(d.mul(dv)).sub(kd.mul(y)).sub(nr),
            nr.add(ns).add(Fp2::ONE).sub(kd),x.add(k(32768)).sub(lb(&xl)),y.add(k(32768)).sub(lb(&yl)),
            ao.add(k(32768)).sub(lb(&al)),x1.add(k(32768)).sub(lb(&x1l)),x1.sub(x).sub(ao),
            v[igm].mul(x1).mul(num_m).add(dm.mul(dv)).sub(kdm.mul(ym)).sub(mr),
            mr.add(ms).add(Fp2::ONE).sub(kdm),ym.add(k(32768)).sub(lb(&yml)),
            z.add(k(32768)).sub(lb(&zl)),x2.add(k(32768)).sub(lb(&x2l)),x2.sub(x1).sub(z)];
        let batch=mu.iter().zip(clauses).fold(Fp2::ZERO,|a,(m,c)|a.add(m.mul(c)));
        let zc=helper_sum(v,&lks,h0,alpha,&mu[13..13+n_help]).add(pz.eval(v)).add(gd.at(v).mul(batch));
        let host_o=k(1i64<<precision.ao).mul(ao).add(lb(&ral)).sub(k(1i64<<(precision.ao-1)));
        let host_d=k(1i64<<precision.down).mul(z).add(lb(&rdl)).sub(k(1i64<<(precision.down-1)));
        v[0].mul(zc).add(nu[0].mul(v[1]).mul(gd.at(v)).mul(host_o)).add(nu[1].mul(v[2]).mul(gd.at(v)).mul(host_d))
    };
    b.finish(Box::new(poly),hosted)
}

fn fzc(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());let low=ids.accuracy()?;
    let data=ctx.accuracy.ok_or("R13 FFN requires public accuracy data")?;let precision=sh.accuracy_precision()?;
    let cube=sh.size(Dom::F);let mut b=B::new(lay,SC_FZC);let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::F).is_empty();
    let n_help=sh.helpers(Dom::F);let mu=tr.challenge_fp2_vec(4+n_help+usize::from(pad_on));let nu=nonzero(tr.challenge_fp2_vec(2))?;
    let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};
    b.eq(&tr.challenge_fp2_vec(sh.log(Dom::F)),0);b.eq(&pts.p_g,0);b.eq(&pts.p_u,0);
    let range=ids.domain_range(Dom::F)?;let idx=b.a_range(range.start,range.end-1)?;
    let(rg,ul,ru,hl,rh)=(role(&b,low,L::Rg)?,role(&b,low,L::Up)?,role(&b,low,L::Ru)?,role(&b,low,L::H)?,role(&b,low,L::Rh)?);
    let h0=b.h(hids.first_helper(Dom::F))?;for j in 1..n_help {b.h(hids.helper(Dom::F,j))?;}
    let fact=b.h(hids.fact())?;let lks=lk_tables(lay,Dom::F,&b.shaped,ctx.g_u8);
    let group=b.public(crate::private_block::accuracy_act::group_column(sh,data)?);
    let gf=Gate(b.supp(Dom::F,cube)?);let mut pz=PadTerm::none();
    if pad_on {
        let planes:Vec<_>=crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::F).iter().map(|&p|b.tab(p)).collect();
        pz.mu=mu[4+n_help];pz.add(gf.0,&planes,zeta);
    }
    let (r,gate)=(data.folds().product.shift,sh.accuracy_gate_shift);
    let(alpha,beta,tag)=(ctx.alpha,ctx.beta,ctx.g_act);let beta2=beta.mul(beta);
    let hosted=vec![(SC_GMM,nu[0]),(SC_UMM,nu[1])];
    let poly=move |v:&[Fp2]| {
        let at=|old|v[idx[old]];let lb=|ix:&[usize]|limbs(v,ix);
        let(g,a,u,h)=(at(A_G8),at(A_A16),at(A_U16),at(A_H16));
        let f0=a.mul(u).sub(k(1i64<<r).mul(h)).sub(lb(&rh)).add(k(1i64<<(r-1)));
        let f1=u.add(k(32768)).sub(lb(&ul));let f2=h.add(k(1i64<<(precision.product_bits-1))).sub(lb(&hl));
        let query=g.add(k(2048)).add(beta.mul(a)).add(beta2.mul(v[group])).add(tag);
        let fa=v[fact].mul(alpha.sub(query)).sub(Fp2::ONE);
        let arithmetic=mu[0].mul(f0).add(mu[1].mul(f1)).add(mu[2].mul(f2));
        let zc=helper_sum(v,&lks,h0,alpha,&mu[4..4+n_help]).add(mu[3].mul(fa)).add(pz.eval(v)).add(gf.at(v).mul(arithmetic));
        let host_g=k(1i64<<gate).mul(g).add(lb(&rg)).sub(k(1i64<<(gate-1)));
        let host_u=k(1i64<<precision.up).mul(u).add(lb(&ru)).sub(k(1i64<<(precision.up-1)));
        v[0].mul(zc).add(nu[0].mul(v[1]).mul(gf.at(v)).mul(host_g)).add(nu[1].mul(v[2]).mul(gf.at(v)).mul(host_u))
    };
    b.finish(Box::new(poly),hosted)
}

fn qzc(slot:usize,ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());let low=ids.accuracy()?;let precision=sh.accuracy_precision()?;
    let q=slot==SC_QZC;let dom=if q {Dom::Q} else {Dom::Kv};let cube=sh.size(dom);let log=sh.log(dom);let mut b=B::new(lay,slot);
    let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,dom).is_empty();let n_help=sh.helpers(dom);
    let mu=tr.challenge_fp2_vec(4+n_help+usize::from(pad_on));let nu=nonzero(tr.challenge_fp2_vec(2))?;
    let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};
    b.eq(&tr.challenge_fp2_vec(log),0);b.eq(if q {&pts.pq} else {&pts.pk},0);b.eq(if q {&pts.p_o} else {&pts.pv},0);
    let(ct,st)=rope_tables_at(sh,ctx.public,dom);let ic=b.public(ct);let is=b.public(st);
    let range=ids.domain_range(dom)?;let idx=b.a_range(range.start,range.end-1)?;
    let(source,rotated,rr,lword,lrword,other,lother,rsource,rother,s1,s2)=if q {
        (A_Q8,A_QR8,L::Rqr,L::Q,L::Qr,A_O8,L::O,L::Rq,L::Ro,precision.q,precision.pv)
    } else {(A_K8,A_KR8,L::Rkr,L::K,L::Kr,A_V8,L::V,L::Rk,L::Rv,precision.k,precision.v)};
    let (wl,rwl,ol,r1,r2,rotrem)=(role(&b,low,lword)?,role(&b,low,lrword)?,role(&b,low,lother)?,role(&b,low,rsource)?,role(&b,low,rother)?,role(&b,low,rr)?);
    let mut cf=rho(0..log);cf[log-lg(sh.head_dim)]=Coord::Flip(log-lg(sh.head_dim));
    let flip=b.a_at(ids.at(source),cf,0)?;
    let h0=b.h(hids.first_helper(dom))?;for j in 1..n_help {b.h(hids.helper(dom,j))?;}
    let lks=lk_tables(lay,dom,&b.shaped,ctx.g_u8);let gate=Gate(b.supp(dom,cube)?);let mut pz=PadTerm::none();
    if pad_on {let planes:Vec<_>=crate::private_block::pad::zero_rule_a_planes(sh,ids,dom).iter().map(|&p|b.tab(p)).collect();
        pz.mu=mu[4+n_help];pz.add(gate.0,&planes,zeta);}
    let alpha=ctx.alpha;
    let hosted=if q {vec![(SC_QMM,nu[0]),(SC_PV,nu[1])]} else {vec![(SC_KMM,nu[0]),(SC_VMM,nu[1])]};
    let poly=move |v:&[Fp2]| {
        let at=|old|v[idx[old]];let lb=|ix:&[usize]|limbs(v,ix);
        let rope=v[ic].mul(at(source)).add(v[is].mul(v[flip])).sub(k(1<<SH_ROPE).mul(at(rotated)))
            .sub(lb(&rotrem)).add(k(1<<(SH_ROPE-1)));
        let clauses=[rope,at(source).add(k(32768)).sub(lb(&wl)),at(rotated).add(k(32768)).sub(lb(&rwl)),at(other).add(k(32768)).sub(lb(&ol))];
        let arithmetic=mu.iter().zip(clauses).fold(Fp2::ZERO,|a,(m,c)|a.add(m.mul(c)));
        let zc=helper_sum(v,&lks,h0,alpha,&mu[4..4+n_help]).add(pz.eval(v)).add(gate.at(v).mul(arithmetic));
        let host1=k(1i64<<s1).mul(at(source)).add(lb(&r1)).sub(k(1i64<<(s1-1)));
        let host2=k(1i64<<s2).mul(at(other)).add(lb(&r2)).sub(k(1i64<<(s2-1)));
        v[0].mul(zc).add(nu[0].mul(v[1]).mul(gate.at(v)).mul(host1)).add(nu[1].mul(v[2]).mul(gate.at(v)).mul(host2))
    };
    b.finish(Box::new(poly),hosted)
}

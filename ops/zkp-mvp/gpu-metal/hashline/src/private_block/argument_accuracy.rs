//! Native R13 host relations for the registered LOW and LOW+h24 profiles.
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
    // W16 (D54): the same relations at 16-bit limbs; no R13 slot changes
    if sh.range16() {
        return match slot {
            SC_DZC=>dzc_w16(ctx,pts,tr).map(Some),
            SC_FZC=>fzc_w16(ctx,pts,tr).map(Some),
            SC_QZC|SC_KVZC=>qzc_w16(slot,ctx,pts,tr).map(Some),
            SC_SZC if sh.dd_cap>0=>szc_dd_w16(ctx,pts,tr).map(Some),
            SC_SZC=>szc_w16(ctx,pts,tr).map(Some),
            SC_DD=>dd_w16(ctx,tr).map(Some),
            SC_TAB=>tab_w16(ctx,tr).map(Some),
            _=>Ok(None),
        };
    }
    match slot {
        SC_DZC=>dzc(ctx,pts,tr).map(Some),
        SC_FZC=>fzc(ctx,pts,tr).map(Some),
        SC_QZC|SC_KVZC=>qzc(slot,ctx,pts,tr).map(Some),
        SC_SZC if sh.dd_cap>0=>szc_dd(ctx,pts,tr).map(Some),
        SC_SZC=>szc(ctx,pts,tr).map(Some),
        SC_DD=>dd(ctx,tr).map(Some),
        SC_TAB=>tab(ctx,tr).map(Some),
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

fn szc_dd(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let low=ids.accuracy()?;let precision=sh.accuracy_precision()?;
    let(alpha,beta,g_u8,g_exp)=(ctx.alpha,ctx.beta,ctx.g_u8,ctx.g_exp);
    let(ls,lp)=(sh.limbs_sigma_s(),sh.limbs_p());
    let mut b=B::new(lay,SC_SZC);
    let pad_on=ALL_DOMS.into_iter().any(|d|crate::private_block::pad::pad_zero_host(d)==SC_SZC && !crate::private_block::pad::zero_rule_a_planes(sh,ids,d).is_empty());
    let n_pad=usize::from(pad_on);let cube=1usize<<sh.slots()[SC_SZC].0;

            if pad_on {
                return Err("private block: a DD profile's softmax zero-check would host a pad term; D30 here needs an unpadded score domain".into());
            }
            let tau = tr.challenge_fp2_vec(sh.log(Dom::S));
            let n_help = sh.helpers(Dom::S);
            let mu = tr.challenge_fp2_vec(2 + n_help + 2);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            let lam = pts.lam_z;
            b.eq(&tau, 0);
            b.eq(&pts.p_ht, 0);
            b.eq(&pts.p_s, 0);
            let im = b.public(causal_mask_at(sh));
            let idx = b.a_range(ids.at(A_S8), ids.at(A_P))?;
            let lht = sh.log(Dom::Ht);
            let imx = b.a_slice(lay.a_off[ids.at(A_MX)], lht, rho(0..lht), 0)?;
            let isum = b.a_slice(lay.a_off[ids.at(A_SUM)], lht, rho(0..lht), 0)?;
            let h0 = b.h(hids.first_helper(Dom::S))?;
            for j in 1..n_help {
                b.h(hids.helper(Dom::S, j))?;
            }
            let ihx = b.h(hids.sexp())?;
            let iht = b.h(hids.stuple())?;
            let lks = lk_tables(lay, Dom::S, &b.shaped, g_u8);
            let rsl_ix=role(&b,low,L::Rs)?;
            let b_shs = k(1i64 << precision.score).c0;
            let k_s_half = k(crate::private_block::witness::half(precision.score));
            let per_row = (sh.size(Dom::S) / sh.size(Dom::Ht)) as i64;
            let hosted = vec![(SC_RS, nu[0].mul(k(per_row))), (SC_SCORE, nu[1])];
            let ght = Gate(b.supp(Dom::Ht, cube)?);
            let gs = Gate(b.supp(Dom::S, cube)?);
            let (g_dd, beta2) = (ctx.g_dd, beta.mul(beta));
            let keyed = !dd_lapse(DD_LAPSE_DROP_KEY);
            let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let host_rs = nu[0].mul(ght.at(v)).mul(v[isum].add(lam));
                let host_s = nu[1].mul(gs.at(v)).mul(at(A_S8).mul_base(b_shs).add(limbs(v,&rsl_ix)).sub(k_s_half));
                let (mask, s8, zsel, e, p, sum) = (v[im], at(A_S8), at(A_ZSEL), at(A_E), at(A_P), v[isum]);
                let delta = v[imx].sub(mask.mul(s8.add(k(-MASK_SCORE)))).add(k(-MASK_SCORE));
                let c0 = zsel.mul(zsel).sub(zsel);
                let c1 = zsel.mul(delta);
                let cx = v[ihx].mul(alpha.sub(delta.add(beta.mul(e)).add(g_exp))).sub(Fp2::ONE);
                // the tuple lookup into this row's dictionary (D30)
                let key = if keyed { sum } else { Fp2::ZERO };
                let ct = v[iht].mul(alpha.sub(g_dd.add(key).add(beta.mul(mask.mul(e))).add(beta2.mul(p)))).sub(Fp2::ONE);
                let clauses = mu[0].mul(c0).add(mu[1].mul(c1));
                let zc = helper_sum(v, &lks, h0, alpha, &mu[2..2 + n_help]).add(mu[2 + n_help].mul(cx)).add(mu[3 + n_help].mul(ct)).add(gs.at(v).mul(clauses));
                v[0].mul(zc).add(v[1].mul(host_rs)).add(v[2].mul(host_s))
            };
            b.finish(Box::new(poly), hosted)
}

fn szc(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let low=ids.accuracy()?;let precision=sh.accuracy_precision()?;
    let(alpha,beta,g_u8,g_exp)=(ctx.alpha,ctx.beta,ctx.g_u8,ctx.g_exp);
    let(ls,lp)=(sh.limbs_sigma_s(),sh.limbs_p());
    let mut b=B::new(lay,SC_SZC);
    let pad_on=ALL_DOMS.into_iter().any(|d|crate::private_block::pad::pad_zero_host(d)==SC_SZC && !crate::private_block::pad::zero_rule_a_planes(sh,ids,d).is_empty());
    let n_pad=usize::from(pad_on);let cube=1usize<<sh.slots()[SC_SZC].0;

            let tau = tr.challenge_fp2_vec(sh.log(Dom::S));
            let n_help = sh.helpers(Dom::S);
            let mu = tr.challenge_fp2_vec(5 + n_help + 1 + n_pad);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
            let lam = pts.lam_z;
            b.eq(&tau, 0);
            b.eq(&pts.p_ht, 0);
            b.eq(&pts.p_s, 0);
            let im = b.public(causal_mask_at(sh));
            // the `Dom::S` block runs to the LAST `sigma_s` limb, which the toy
            // has no name for when `limbs_sigma_s` is three (S8)
            let idx = b.a_range(ids.at(A_S8), ids.sg(ls - 1))?;
            let i_pl: Vec<usize> = (0..lp).map(|kk| b.tab(ids.pl(kk))).collect();
            let i_sr: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sr(kk))).collect();
            let i_sg: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sg(kk))).collect();
            let lht = sh.log(Dom::Ht);
            let imx = b.a_slice(lay.a_off[ids.at(A_MX)], lht, rho(0..lht), 0)?;
            let isum = b.a_slice(lay.a_off[ids.at(A_SUM)], lht, rho(0..lht), 0)?;
            let h0 = b.h(hids.first_helper(Dom::S))?;
            for j in 1..n_help {
                b.h(hids.helper(Dom::S, j))?;
            }
            let ihx = b.h(hids.sexp())?;
            let lks = lk_tables(lay, Dom::S, &b.shaped, g_u8);
            let rsl_ix=role(&b,low,L::Rs)?;
            // **STAGE 35, LEVER (b)(iii)** — see the note in `SC_DZC` above:
            // a constant with no imaginary part makes `x.mul(c)` exactly
            // `x.mul_base(c.c0)`, two base multiplications instead of five,
            // and `lw` is `limbs`'s own `pow256(kk)` weight vector.
            // ROUND 2: the score shift is the SHAPE's (the frozen SH_S at every
            // registered shape)
            let (b_fp, b_shs) = (k(1 << sh.f_p()).c0, k(1i64 << precision.score).c0);
            let k_s_half = k(crate::private_block::witness::half(precision.score));
            let lw = |ix: &[usize]| -> Vec<(usize, Fp)> { ix.iter().enumerate().map(|(kk, i)| (*i, pow256(kk).c0)).collect() };
            let (w_sr, w_sg, w_pl) = (lw(&i_sr), lw(&i_sg), lw(&i_pl));
            // the row-sum host term is constant in j: it sums to (the number of
            // j positions of the S cube per Ht position) * (Sum(p_ht) + lam_z)
            let per_row = (sh.size(Dom::S) / sh.size(Dom::Ht)) as i64;
            let hosted = vec![(SC_RS, nu[0].mul(k(per_row))), (SC_SCORE, nu[1])];
            // **S9 part 4 on `Dom::S` AND `Dom::Ht` (finding S9-F7).** This
            // slot is the only host of two domains: `Dom::Ht` has no
            // zero-check of its own and its two planes (`A_MX`, `A_SUM`) are
            // read here on the LEADING coordinates, so its indicator is
            // lifted over the trailing `j` axis and carries its own group.
            // `supp_S` would be WRONG for them: it is 0 wherever `j` pads,
            // which would force a TRUE row's maximum to zero. `host_rs` takes
            // the LIFTED `supp_Ht` and not `supp_S`, because it is constant
            // in `j` and `per_row` must stay the full `t_pad`.
            let ght = Gate(b.supp(Dom::Ht, cube)?);
            let gs = Gate(b.supp(Dom::S, cube)?);
            let mut pz = PadTerm::none();
            if pad_on {
                pz.mu = mu[5 + n_help + 1];
                if crate::private_block::pad::zero_rule_a_planes(sh, ids, Dom::Ht) != vec![ids.at(A_MX), ids.at(A_SUM)] {
                    return Err("private block: a Dom::Ht plane is outside SC_SZC's pad-zero group".into());
                }
                pz.add(ght.0, &[imx, isum], zeta);
                let planes: Vec<usize> = crate::private_block::pad::zero_rule_a_planes(sh, ids, Dom::S).iter().map(|p| b.tab(*p)).collect();
                pz.add(gs.0, &planes, zeta);
            }
            // **STAGE 35, the differential gate.** See the same block in
            // `SC_DZC` above: `cfg(test)` only, and it hands this arm's
            // captures to the verbatim `89e393f` body in `s35_tests`.
            let groups = vec![
                sumcheck::EqualityGroup { point: tau, start: 0, bracket_degree: if pad_on { 4 } else { 3 } },
                sumcheck::EqualityGroup { point: pts.p_ht.clone(), start: 0, bracket_degree: if pad_on { 2 } else { 1 } },
                sumcheck::EqualityGroup { point: pts.p_s.clone(), start: 0, bracket_degree: if pad_on { 2 } else { 1 } },
            ];
            let bracket: GroupPoly = std::sync::Arc::new(move |group: usize, v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                if group == 1 {
                    return nu[0].mul(ght.at(v)).mul(v[isum].add(lam));
                }
                if group == 2 {
                    let host_s = at(A_S8).mul_base(b_shs).add(limbs(v,&rsl_ix)).sub(k_s_half);
                    return nu[1].mul(gs.at(v)).mul(host_s);
                }
                assert_eq!(group, 0);
                // `limbs` with base weights and the `256^0` multiply by one
                // dropped — the same `lb` as in `SC_DZC`
                let lb = |w: &[(usize, Fp)]| match w.split_first() {
                    None => Fp2::ZERO,
                    Some(((i0, _), rest)) => rest.iter().fold(v[*i0], |a, (i, c)| a.add(v[*i].mul_base(*c))),
                };
                let (mask, s8, zsel, e, p, sum) = (v[im], at(A_S8), at(A_ZSEL), at(A_E), at(A_P), v[isum]);
                let sr = lb(&w_sr);
                // delta = max - masked score, the masked score being mask * (s8 + 127) - 127
                let delta = v[imx].sub(mask.mul(s8.add(k(-MASK_SCORE)))).add(k(-MASK_SCORE));
                let c0 = zsel.mul(zsel).sub(zsel);
                let c1 = zsel.mul(delta);
                let c2 = mask.mul(e).mul_base(b_fp).sub(p.mul(sum)).sub(sr);
                let c3 = lb(&w_sg).add(sr).add(Fp2::ONE).sub(sum);
                let c4 = p.sub(lb(&w_pl));
                let cx = v[ihx].mul(alpha.sub(delta.add(beta.mul(e)).add(g_exp))).sub(Fp2::ONE);
                let g = gs.at(v);
                // **STAGE 35, LEVER (b)(i)** — the same rewrite as in
                // `SC_DZC` above, and the same argument: FIVE multiplications
                // by the support gate become ONE. `ght` gates the row-sum
                // host term and `gs` the rest; only `gs` is hoisted, because
                // the two are different tables (finding S9-F7).
                let mut clauses = Fp2::ZERO;
                for (m, c) in mu.iter().zip([c0, c1, c2, c3, c4]) {
                    clauses = clauses.add(m.mul(c));
                }
                let zc = helper_sum(v, &lks, h0, alpha, &mu[5..5 + n_help]).add(mu[5 + n_help].mul(cx)).add(pz.eval(v)).add(g.mul(clauses));
                zc
            });
            let poly_bracket = bracket.clone();
            let poly = move |v: &[Fp2]| (0..3).fold(Fp2::ZERO,
                |a, group| a.add(v[group].mul(poly_bracket(group, v))));
            let mut def = b.finish(Box::new(poly), hosted)?;
            def.groups = Some((groups, bracket));
            Ok(def)
}

fn dd(ctx:&Ctx<'_>,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let low=ids.accuracy()?;let precision=sh.accuracy_precision()?;
    let(alpha,beta,g_u8,g_exp)=(ctx.alpha,ctx.beta,ctx.g_u8,ctx.g_exp);
    let(ls,lp)=(sh.limbs_sigma_s(),sh.limbs_p());
    let mut b=B::new(lay,SC_DD);
    let pad_on=ALL_DOMS.into_iter().any(|d|crate::private_block::pad::pad_zero_host(d)==SC_DD && !crate::private_block::pad::zero_rule_a_planes(sh,ids,d).is_empty());
    let n_pad=usize::from(pad_on);let cube=1usize<<sh.slots()[SC_DD].0;

            if sh.dd_cap == 0 {
                return Err("private block: the dictionary slot at a profile without a dictionary".into());
            }
            if pad_on {
                return Err("private block: a DD profile's dictionary would host a pad term; D30 here needs an unpadded dictionary".into());
            }
            let ldd = sh.log(Dom::Dd);
            let tau = tr.challenge_fp2_vec(ldd);
            let n_help = sh.helpers(Dom::Dd);
            let mu = tr.challenge_fp2_vec(3 + n_help + 1);
            b.eq(&tau, 0);
            let _ = b.a_range(ids.pdict(), ids.mdd())?;
            let (ipd, imd) = (b.tab(ids.pdict()), b.tab(ids.mdd()));
            let i_pl: Vec<usize> = (0..lp).map(|kk| b.tab(ids.pl(kk))).collect();
            let i_sr: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sr(kk))).collect();
            let i_sg: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sg(kk))).collect();
            let lht = sh.log(Dom::Ht);
            let isum = b.a_slice(lay.a_off[ids.at(A_SUM)], lht, rho(0..lht), 0)?;
            // the public e column, constant in (h, t): slot k's value
            let ecol = ctx.public.dd_e_column(sh.dd_cap)?;
            let cap = sh.dd_cap;
            let ie = b.public((0..(1usize << ldd)).map(|x| k(ecol[x % cap])).collect());
            let h0 = b.h(hids.first_helper(Dom::Dd))?;
            for j in 1..n_help {
                b.h(hids.helper(Dom::Dd, j))?;
            }
            let ig = b.h(hids.gdd())?;
            let lks = lk_tables(lay, Dom::Dd, &b.shaped, g_u8);
            let b_fp = k(1 << sh.f_p()).c0;
            let lw = |ix: &[usize]| -> Vec<(usize, Fp)> { ix.iter().enumerate().map(|(kk, i)| (*i, pow256(kk).c0)).collect() };
            let (w_sr, w_sg, w_pl) = (lw(&i_sr), lw(&i_sg), lw(&i_pl));
            let (g_dd, beta2) = (ctx.g_dd, beta.mul(beta));
            let keyed = !dd_lapse(DD_LAPSE_DROP_KEY);
            // the D-3 lapse's public "used slot" gate: 0 on every row's last
            // slot (test builds, lapsed only)
            let gate = if dd_lapse(DD_LAPSE_GATE_LAST_SLOT) { Some(b.public((0..(1usize << ldd)).map(|x| if x % cap == cap - 1 { Fp2::ZERO } else { Fp2::ONE }).collect())) } else { None };
            let poly = move |v: &[Fp2]| {
                let lb = |w: &[(usize, Fp)]| match w.split_first() {
                    None => Fp2::ZERO,
                    Some(((i0, _), rest)) => rest.iter().fold(v[*i0], |a, (i, c)| a.add(v[*i].mul_base(*c))),
                };
                let (pd, md, sum, e) = (v[ipd], v[imd], v[isum], v[ie]);
                let sr = lb(&w_sr);
                let c2 = e.mul_base(b_fp).sub(pd.mul(sum)).sub(sr);
                let c3 = lb(&w_sg).add(sr).add(Fp2::ONE).sub(sum);
                let c4 = pd.sub(lb(&w_pl));
                let key = if keyed { sum } else { Fp2::ZERO };
                let ctab = v[ig].mul(alpha.sub(g_dd.add(key).add(beta.mul(e)).add(beta2.mul(pd)))).sub(md);
                let division = mu[0].mul(c2).add(mu[1].mul(c3)).add(mu[2].mul(c4));
                let division = match gate {
                    Some(gi) => v[gi].mul(division),
                    None => division,
                };
                v[0].mul(division.add(helper_sum(v, &lks, h0, alpha, &mu[3..3 + n_help])).add(mu[3 + n_help].mul(ctab)))
            };
            b.finish(Box::new(poly), vec![])
}

fn tab(ctx:&Ctx<'_>,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let data=ctx.accuracy.ok_or("R13 table relation requires bound accuracy data")?;
    let(alpha,beta,g_u8,g_exp,g_act)=(ctx.alpha,ctx.beta,ctx.g_u8,ctx.g_exp,ctx.g_act);
    let len=sh.size(Dom::Tab);let mut b=B::new(lay,SC_TAB);
    let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::Tab).is_empty();
    let tau=tr.challenge_fp2_vec(sh.log(Dom::Tab));let mu=tr.challenge_fp2_vec(3+usize::from(pad_on));
    let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};let th=hids.table_helpers();
    let act=crate::private_block::accuracy_act::table(data,len,beta,g_act)?;
    b.eq(&tau,0);
    b.a(ids.at(A_MU8))?;b.h(th[0])?;b.public(table_values_u8_at(len,g_u8));
    b.a(ids.at(A_MEXP))?;b.h(th[1])?;b.public(table_values_exp_at(len,ctx.public,beta,g_exp));
    b.a(ids.at(A_MACT))?;b.h(th[2])?;b.public(act.compressed);
    let mut pz=PadTerm::none();
    if pad_on {
        tab_group_is_declared(sh,ids,&[ids.at(A_MU8),ids.at(A_MEXP),ids.at(A_MACT)],&th)?;
        let bytes=b.supp(Dom::Tab,len)?;let activation=Some(b.public(act.support));
        pz.mu=mu[3];
        // PadTerm::add continues independent zeta powers across all groups.
        pz.add(bytes,&[1,4],zeta);pz.add(bytes,&[2,5],zeta);
        pz.add(activation,&[7],zeta);pz.add(activation,&[8],zeta);
    }
    b.finish(Box::new(move |v:&[Fp2]| {
        let r0=v[2].mul(alpha.sub(v[3])).sub(v[1]);
        let r1=v[5].mul(alpha.sub(v[6])).sub(v[4]);
        let r2=v[8].mul(alpha.sub(v[9])).sub(v[7]);
        v[0].mul(mu[0].mul(r0).add(mu[1].mul(r1)).add(mu[2].mul(r2)).add(pz.eval(v)))
    }),vec![])
}

// ---------------------------------------------------------------- W16 (D54)
//
// The R13 relations above at 16-bit limbs (`results/zk60_limb16_20261031/
// DESIGN.md`). What changes, slot by slot:
//  * a 16-bit word's decomposition clause `word + 32768 - sum limbs` is GONE:
//    the word itself is the lookup (`range16::word16`), so the clause and its
//    batching challenge are dropped, never kept as a trivial identity;
//  * a remainder's limb sum weighs `2^16` per limb (`limbs16`);
//  * the 24-bit product word keeps no decomposition clause: its low limb IS
//    the lookup expression `h + 2^23 - 2^16 top` (`range16::word24`);
//  * the softmax quotient `P` is looked up directly, so `p - sum PL` is gone;
//  * `SC_TAB` carries one more (multiplicity, helper, table) triple per range
//    sub-plane, and a narrow family's padded copies are held to zero under
//    its own support indicator.

fn dzc_w16(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());let low=ids.accuracy()?;
    let precision=sh.accuracy_precision()?;let cube=sh.size(Dom::D);let mut b=B::new(lay,SC_DZC);
    let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::D).is_empty();
    let n_help=sh.helpers(Dom::D);let mu=tr.challenge_fp2_vec(6+n_help+usize::from(pad_on));
    let nu=nonzero(tr.challenge_fp2_vec(2))?;let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};
    b.eq(&tr.challenge_fp2_vec(sh.log(Dom::D)),0);b.eq(&pts.p_a,0);b.eq(&pts.p_z,0);
    let ig=b.public((0..cube).map(|i|k(ctx.public.gamma_a[i%sh.d_pad] as i64)).collect());
    let igm=b.public((0..cube).map(|i|k(ctx.ff.gamma_m[i%sh.d_pad] as i64)).collect());
    let range=ids.domain_range(Dom::D)?;let idx=b.a_range(range.start,range.end-1)?;
    let (nr,ns,mr,ms)=(role(&b,low,L::Nr)?,role(&b,low,L::Ns)?,role(&b,low,L::Mr)?,role(&b,low,L::Ms)?);
    let (ral,rdl)=(role(&b,low,L::Rao)?,role(&b,low,L::Rd)?);
    let lt=lg(sh.t_pad);
    let id=b.a_slice(lay.a_off[ids.at(A_D)],lt,rho(0..lt),0)?;
    let idm=b.a_slice(lay.a_off[ids.at(A_DM)],lt,rho(0..lt),0)?;
    let h0=b.h(hids.first_helper(Dom::D))?;for j in 1..n_help {b.h(hids.helper(Dom::D,j))?;}
    let lks=lk_tables(lay,Dom::D,&b.shaped,ctx.g_u8);
    let gd=Gate(b.supp(Dom::D,cube)?);let mut pz=PadTerm::none();
    if pad_on {
        let planes:Vec<_>=crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::D).iter().map(|&p|b.tab(p)).collect();
        pz.mu=mu[6+n_help];pz.add(gd.0,&planes,zeta);
    }
    let (num,num_m,dv,den)=(k(2*sh.norm_cn_a),k(2*sh.norm_cn_m),k(1i64<<precision.norm_tn),k(1i64<<(precision.norm_tn+1)));
    let alpha=ctx.alpha;let hosted=vec![(SC_WO,nu[0]),(SC_DMM,nu[1])];
    let poly=move |v:&[Fp2]| {
        let at=|old|v[idx[old]];let lb=|ix:&[usize]|limbs16(v,ix);
        let(x,y,ao,x1,ym,z,x2)=(at(A_X),at(A_Y),at(A_AO),at(A_X1),at(A_YM),at(A_Z16),at(A_X2));
        let (d,dm)=(v[id],v[idm]);let(kd,kdm)=(den.mul(d),den.mul(dm));
        let(nr,ns,mr,ms)=(lb(&nr),lb(&ns),lb(&mr),lb(&ms));
        let clauses=[v[ig].mul(x).mul(num).add(d.mul(dv)).sub(kd.mul(y)).sub(nr),
            nr.add(ns).add(Fp2::ONE).sub(kd),x1.sub(x).sub(ao),
            v[igm].mul(x1).mul(num_m).add(dm.mul(dv)).sub(kdm.mul(ym)).sub(mr),
            mr.add(ms).add(Fp2::ONE).sub(kdm),x2.sub(x1).sub(z)];
        let batch=mu.iter().zip(clauses).fold(Fp2::ZERO,|a,(m,c)|a.add(m.mul(c)));
        let zc=helper_sum(v,&lks,h0,alpha,&mu[6..6+n_help]).add(pz.eval(v)).add(gd.at(v).mul(batch));
        let host_o=k(1i64<<precision.ao).mul(ao).add(lb(&ral)).sub(k(1i64<<(precision.ao-1)));
        let host_d=k(1i64<<precision.down).mul(z).add(lb(&rdl)).sub(k(1i64<<(precision.down-1)));
        v[0].mul(zc).add(nu[0].mul(v[1]).mul(gd.at(v)).mul(host_o)).add(nu[1].mul(v[2]).mul(gd.at(v)).mul(host_d))
    };
    b.finish(Box::new(poly),hosted)
}

fn fzc_w16(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());let low=ids.accuracy()?;
    let data=ctx.accuracy.ok_or("W16 FFN requires public accuracy data")?;let precision=sh.accuracy_precision()?;
    let cube=sh.size(Dom::F);let mut b=B::new(lay,SC_FZC);let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::F).is_empty();
    let n_help=sh.helpers(Dom::F);let mu=tr.challenge_fp2_vec(2+n_help+usize::from(pad_on));let nu=nonzero(tr.challenge_fp2_vec(2))?;
    let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};
    b.eq(&tr.challenge_fp2_vec(sh.log(Dom::F)),0);b.eq(&pts.p_g,0);b.eq(&pts.p_u,0);
    let range=ids.domain_range(Dom::F)?;let idx=b.a_range(range.start,range.end-1)?;
    let(rg,ru,rh)=(role(&b,low,L::Rg)?,role(&b,low,L::Ru)?,role(&b,low,L::Rh)?);
    let h0=b.h(hids.first_helper(Dom::F))?;for j in 1..n_help {b.h(hids.helper(Dom::F,j))?;}
    let fact=b.h(hids.fact())?;let lks=lk_tables(lay,Dom::F,&b.shaped,ctx.g_u8);
    let group=b.public(crate::private_block::accuracy_act::group_column(sh,data)?);
    let gf=Gate(b.supp(Dom::F,cube)?);let mut pz=PadTerm::none();
    if pad_on {
        let planes:Vec<_>=crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::F).iter().map(|&p|b.tab(p)).collect();
        pz.mu=mu[2+n_help];pz.add(gf.0,&planes,zeta);
    }
    let (r,gate)=(data.folds().product.shift,sh.accuracy_gate_shift);
    let(alpha,beta,tag)=(ctx.alpha,ctx.beta,ctx.g_act);let beta2=beta.mul(beta);
    let hosted=vec![(SC_GMM,nu[0]),(SC_UMM,nu[1])];
    let poly=move |v:&[Fp2]| {
        let at=|old|v[idx[old]];let lb=|ix:&[usize]|limbs16(v,ix);
        let(g,a,u,h)=(at(A_G8),at(A_A16),at(A_U16),at(A_H16));
        let f0=a.mul(u).sub(k(1i64<<r).mul(h)).sub(lb(&rh)).add(k(1i64<<(r-1)));
        let query=g.add(k(2048)).add(beta.mul(a)).add(beta2.mul(v[group])).add(tag);
        let fa=v[fact].mul(alpha.sub(query)).sub(Fp2::ONE);
        let zc=helper_sum(v,&lks,h0,alpha,&mu[2..2+n_help]).add(mu[1].mul(fa)).add(pz.eval(v)).add(gf.at(v).mul(mu[0].mul(f0)));
        let host_g=k(1i64<<gate).mul(g).add(lb(&rg)).sub(k(1i64<<(gate-1)));
        let host_u=k(1i64<<precision.up).mul(u).add(lb(&ru)).sub(k(1i64<<(precision.up-1)));
        v[0].mul(zc).add(nu[0].mul(v[1]).mul(gf.at(v)).mul(host_g)).add(nu[1].mul(v[2]).mul(gf.at(v)).mul(host_u))
    };
    b.finish(Box::new(poly),hosted)
}

fn qzc_w16(slot:usize,ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());let low=ids.accuracy()?;let precision=sh.accuracy_precision()?;
    let q=slot==SC_QZC;let dom=if q {Dom::Q} else {Dom::Kv};let cube=sh.size(dom);let log=sh.log(dom);let mut b=B::new(lay,slot);
    let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,dom).is_empty();let n_help=sh.helpers(dom);
    let mu=tr.challenge_fp2_vec(1+n_help+usize::from(pad_on));let nu=nonzero(tr.challenge_fp2_vec(2))?;
    let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};
    b.eq(&tr.challenge_fp2_vec(log),0);b.eq(if q {&pts.pq} else {&pts.pk},0);b.eq(if q {&pts.p_o} else {&pts.pv},0);
    let(ct,st)=rope_tables_at(sh,ctx.public,dom);let ic=b.public(ct);let is=b.public(st);
    let range=ids.domain_range(dom)?;let idx=b.a_range(range.start,range.end-1)?;
    let(source,rotated,rr,other,rsource,rother,s1,s2)=if q {
        (A_Q8,A_QR8,L::Rqr,A_O8,L::Rq,L::Ro,precision.q,precision.pv)
    } else {(A_K8,A_KR8,L::Rkr,A_V8,L::Rk,L::Rv,precision.k,precision.v)};
    let (r1,r2,rotrem)=(role(&b,low,rsource)?,role(&b,low,rother)?,role(&b,low,rr)?);
    let mut cf=rho(0..log);cf[log-lg(sh.head_dim)]=Coord::Flip(log-lg(sh.head_dim));
    let flip=b.a_at(ids.at(source),cf,0)?;
    let h0=b.h(hids.first_helper(dom))?;for j in 1..n_help {b.h(hids.helper(dom,j))?;}
    let lks=lk_tables(lay,dom,&b.shaped,ctx.g_u8);let gate=Gate(b.supp(dom,cube)?);let mut pz=PadTerm::none();
    if pad_on {let planes:Vec<_>=crate::private_block::pad::zero_rule_a_planes(sh,ids,dom).iter().map(|&p|b.tab(p)).collect();
        pz.mu=mu[1+n_help];pz.add(gate.0,&planes,zeta);}
    let alpha=ctx.alpha;
    let hosted=if q {vec![(SC_QMM,nu[0]),(SC_PV,nu[1])]} else {vec![(SC_KMM,nu[0]),(SC_VMM,nu[1])]};
    let poly=move |v:&[Fp2]| {
        let at=|old|v[idx[old]];let lb=|ix:&[usize]|limbs16(v,ix);
        let rope=v[ic].mul(at(source)).add(v[is].mul(v[flip])).sub(k(1<<SH_ROPE).mul(at(rotated)))
            .sub(lb(&rotrem)).add(k(1<<(SH_ROPE-1)));
        let zc=helper_sum(v,&lks,h0,alpha,&mu[1..1+n_help]).add(pz.eval(v)).add(gate.at(v).mul(mu[0].mul(rope)));
        let host1=k(1i64<<s1).mul(at(source)).add(lb(&r1)).sub(k(1i64<<(s1-1)));
        let host2=k(1i64<<s2).mul(at(other)).add(lb(&r2)).sub(k(1i64<<(s2-1)));
        v[0].mul(zc).add(nu[0].mul(v[1]).mul(gate.at(v)).mul(host1)).add(nu[1].mul(v[2]).mul(gate.at(v)).mul(host2))
    };
    b.finish(Box::new(poly),hosted)
}

fn szc_w16(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let low=ids.accuracy()?;let precision=sh.accuracy_precision()?;
    let(alpha,beta,g_exp)=(ctx.alpha,ctx.beta,ctx.g_exp);
    let mut b=B::new(lay,SC_SZC);
    let pad_on=ALL_DOMS.into_iter().any(|d|crate::private_block::pad::pad_zero_host(d)==SC_SZC && !crate::private_block::pad::zero_rule_a_planes(sh,ids,d).is_empty());
    let n_pad=usize::from(pad_on);
    let tau=tr.challenge_fp2_vec(sh.log(Dom::S));
    let n_help=sh.helpers(Dom::S);
    let mu=tr.challenge_fp2_vec(4+n_help+1+n_pad);
    let nu=nonzero(tr.challenge_fp2_vec(2))?;
    let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};
    let lam=pts.lam_z;
    b.eq(&tau,0);b.eq(&pts.p_ht,0);b.eq(&pts.p_s,0);
    let im=b.public(causal_mask_at(sh));
    let range=ids.domain_range(Dom::S)?;let idx=b.a_range(range.start,range.end-1)?;
    let(i_sr,i_sg,rsl_ix)=(role(&b,low,L::Sr)?,role(&b,low,L::Sg)?,role(&b,low,L::Rs)?);
    let lht=sh.log(Dom::Ht);
    let imx=b.a_slice(lay.a_off[ids.at(A_MX)],lht,rho(0..lht),0)?;
    let isum=b.a_slice(lay.a_off[ids.at(A_SUM)],lht,rho(0..lht),0)?;
    let h0=b.h(hids.first_helper(Dom::S))?;
    for j in 1..n_help {b.h(hids.helper(Dom::S,j))?;}
    let ihx=b.h(hids.sexp())?;
    let lks=lk_tables(lay,Dom::S,&b.shaped,ctx.g_u8);
    let (b_fp,b_shs)=(k(1<<sh.f_p()).c0,k(1i64<<precision.score).c0);
    let k_s_half=k(crate::private_block::witness::half(precision.score));
    let per_row=(sh.size(Dom::S)/sh.size(Dom::Ht)) as i64;
    let hosted=vec![(SC_RS,nu[0].mul(k(per_row))),(SC_SCORE,nu[1])];
    let cube=1usize<<sh.slots()[SC_SZC].0;
    let ght=Gate(b.supp(Dom::Ht,cube)?);
    let gs=Gate(b.supp(Dom::S,cube)?);
    let mut pz=PadTerm::none();
    if pad_on {
        pz.mu=mu[4+n_help+1];
        if crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::Ht)!=vec![ids.at(A_MX),ids.at(A_SUM)] {
            return Err("private block: a Dom::Ht plane is outside SC_SZC's pad-zero group".into());
        }
        pz.add(ght.0,&[imx,isum],zeta);
        let planes:Vec<usize>=crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::S).iter().map(|p|b.tab(*p)).collect();
        pz.add(gs.0,&planes,zeta);
    }
    let groups=vec![
        sumcheck::EqualityGroup{point:tau,start:0,bracket_degree:if pad_on {4} else {3}},
        sumcheck::EqualityGroup{point:pts.p_ht.clone(),start:0,bracket_degree:if pad_on {2} else {1}},
        sumcheck::EqualityGroup{point:pts.p_s.clone(),start:0,bracket_degree:if pad_on {2} else {1}},
    ];
    let bracket:GroupPoly=std::sync::Arc::new(move |group:usize,v:&[Fp2]| {
        let at=|p:usize|v[idx[p]];
        if group==1 {return nu[0].mul(ght.at(v)).mul(v[isum].add(lam));}
        if group==2 {
            let host_s=at(A_S8).mul_base(b_shs).add(limbs16(v,&rsl_ix)).sub(k_s_half);
            return nu[1].mul(gs.at(v)).mul(host_s);
        }
        assert_eq!(group,0);
        let (mask,s8,zsel,e,p,sum)=(v[im],at(A_S8),at(A_ZSEL),at(A_E),at(A_P),v[isum]);
        let sr=limbs16(v,&i_sr);
        let delta=v[imx].sub(mask.mul(s8.add(k(-MASK_SCORE)))).add(k(-MASK_SCORE));
        let c0=zsel.mul(zsel).sub(zsel);
        let c1=zsel.mul(delta);
        let c2=mask.mul(e).mul_base(b_fp).sub(p.mul(sum)).sub(sr);
        let c3=limbs16(v,&i_sg).add(sr).add(Fp2::ONE).sub(sum);
        let cx=v[ihx].mul(alpha.sub(delta.add(beta.mul(e)).add(g_exp))).sub(Fp2::ONE);
        let mut clauses=Fp2::ZERO;
        for (m,c) in mu.iter().zip([c0,c1,c2,c3]) {clauses=clauses.add(m.mul(c));}
        helper_sum(v,&lks,h0,alpha,&mu[4..4+n_help]).add(mu[4+n_help].mul(cx)).add(pz.eval(v)).add(gs.at(v).mul(clauses))
    });
    let poly_bracket=bracket.clone();
    let poly=move |v:&[Fp2]| (0..3).fold(Fp2::ZERO,|a,group|a.add(v[group].mul(poly_bracket(group,v))));
    let mut def=b.finish(Box::new(poly),hosted)?;
    def.groups=Some((groups,bracket));
    Ok(def)
}

fn szc_dd_w16(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let low=ids.accuracy()?;let precision=sh.accuracy_precision()?;
    let(alpha,beta,g_exp)=(ctx.alpha,ctx.beta,ctx.g_exp);
    let mut b=B::new(lay,SC_SZC);
    let pad_on=ALL_DOMS.into_iter().any(|d|crate::private_block::pad::pad_zero_host(d)==SC_SZC && !crate::private_block::pad::zero_rule_a_planes(sh,ids,d).is_empty());
    if pad_on {
        return Err("private block: a DD profile's softmax zero-check would host a pad term; D30 here needs an unpadded score domain".into());
    }
    let cube=1usize<<sh.slots()[SC_SZC].0;
    let tau=tr.challenge_fp2_vec(sh.log(Dom::S));
    let n_help=sh.helpers(Dom::S);
    let mu=tr.challenge_fp2_vec(2+n_help+2);
    let nu=nonzero(tr.challenge_fp2_vec(2))?;
    let lam=pts.lam_z;
    b.eq(&tau,0);b.eq(&pts.p_ht,0);b.eq(&pts.p_s,0);
    let im=b.public(causal_mask_at(sh));
    let idx=b.a_range(ids.at(A_S8),ids.at(A_P))?;
    let lht=sh.log(Dom::Ht);
    let imx=b.a_slice(lay.a_off[ids.at(A_MX)],lht,rho(0..lht),0)?;
    let isum=b.a_slice(lay.a_off[ids.at(A_SUM)],lht,rho(0..lht),0)?;
    let h0=b.h(hids.first_helper(Dom::S))?;
    for j in 1..n_help {b.h(hids.helper(Dom::S,j))?;}
    let ihx=b.h(hids.sexp())?;
    let iht=b.h(hids.stuple())?;
    let lks=lk_tables(lay,Dom::S,&b.shaped,ctx.g_u8);
    let rsl_ix=role(&b,low,L::Rs)?;
    let b_shs=k(1i64<<precision.score).c0;
    let k_s_half=k(crate::private_block::witness::half(precision.score));
    let per_row=(sh.size(Dom::S)/sh.size(Dom::Ht)) as i64;
    let hosted=vec![(SC_RS,nu[0].mul(k(per_row))),(SC_SCORE,nu[1])];
    let ght=Gate(b.supp(Dom::Ht,cube)?);
    let gs=Gate(b.supp(Dom::S,cube)?);
    let (g_dd,beta2)=(ctx.g_dd,beta.mul(beta));
    let keyed=!dd_lapse(DD_LAPSE_DROP_KEY);
    let poly=move |v:&[Fp2]| {
        let at=|p:usize|v[idx[p]];
        let host_rs=nu[0].mul(ght.at(v)).mul(v[isum].add(lam));
        let host_s=nu[1].mul(gs.at(v)).mul(at(A_S8).mul_base(b_shs).add(limbs16(v,&rsl_ix)).sub(k_s_half));
        let (mask,s8,zsel,e,p,sum)=(v[im],at(A_S8),at(A_ZSEL),at(A_E),at(A_P),v[isum]);
        let delta=v[imx].sub(mask.mul(s8.add(k(-MASK_SCORE)))).add(k(-MASK_SCORE));
        let c0=zsel.mul(zsel).sub(zsel);
        let c1=zsel.mul(delta);
        let cx=v[ihx].mul(alpha.sub(delta.add(beta.mul(e)).add(g_exp))).sub(Fp2::ONE);
        let key=if keyed {sum} else {Fp2::ZERO};
        let ct=v[iht].mul(alpha.sub(g_dd.add(key).add(beta.mul(mask.mul(e))).add(beta2.mul(p)))).sub(Fp2::ONE);
        let clauses=mu[0].mul(c0).add(mu[1].mul(c1));
        let zc=helper_sum(v,&lks,h0,alpha,&mu[2..2+n_help]).add(mu[2+n_help].mul(cx)).add(mu[3+n_help].mul(ct)).add(gs.at(v).mul(clauses));
        v[0].mul(zc).add(v[1].mul(host_rs)).add(v[2].mul(host_s))
    };
    b.finish(Box::new(poly),hosted)
}

fn dd_w16(ctx:&Ctx<'_>,tr:&mut Transcript)->Result<SlotDef,String> {
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let low=ids.accuracy()?;let(alpha,beta)=(ctx.alpha,ctx.beta);
    let mut b=B::new(lay,SC_DD);
    let pad_on=ALL_DOMS.into_iter().any(|d|crate::private_block::pad::pad_zero_host(d)==SC_DD && !crate::private_block::pad::zero_rule_a_planes(sh,ids,d).is_empty());
    if sh.dd_cap==0 {return Err("private block: the dictionary slot at a profile without a dictionary".into());}
    if pad_on {return Err("private block: a DD profile's dictionary would host a pad term; D30 here needs an unpadded dictionary".into());}
    let ldd=sh.log(Dom::Dd);
    let tau=tr.challenge_fp2_vec(ldd);
    let n_help=sh.helpers(Dom::Dd);
    let mu=tr.challenge_fp2_vec(2+n_help+1);
    b.eq(&tau,0);
    let _=b.a_range(ids.pdict(),ids.mdd())?;
    let (ipd,imd)=(b.tab(ids.pdict()),b.tab(ids.mdd()));
    let(i_sr,i_sg)=(role(&b,low,L::Sr)?,role(&b,low,L::Sg)?);
    let lht=sh.log(Dom::Ht);
    let isum=b.a_slice(lay.a_off[ids.at(A_SUM)],lht,rho(0..lht),0)?;
    let ecol=ctx.public.dd_e_column(sh.dd_cap)?;
    let cap=sh.dd_cap;
    let ie=b.public((0..(1usize<<ldd)).map(|x|k(ecol[x%cap])).collect());
    let h0=b.h(hids.first_helper(Dom::Dd))?;
    for j in 1..n_help {b.h(hids.helper(Dom::Dd,j))?;}
    let ig=b.h(hids.gdd())?;
    let lks=lk_tables(lay,Dom::Dd,&b.shaped,ctx.g_u8);
    let b_fp=k(1<<sh.f_p()).c0;
    let (g_dd,beta2)=(ctx.g_dd,beta.mul(beta));
    let keyed=!dd_lapse(DD_LAPSE_DROP_KEY);
    let gate=if dd_lapse(DD_LAPSE_GATE_LAST_SLOT) {Some(b.public((0..(1usize<<ldd)).map(|x|if x%cap==cap-1 {Fp2::ZERO} else {Fp2::ONE}).collect()))} else {None};
    let poly=move |v:&[Fp2]| {
        let (pd,md,sum,e)=(v[ipd],v[imd],v[isum],v[ie]);
        let sr=limbs16(v,&i_sr);
        let c2=e.mul_base(b_fp).sub(pd.mul(sum)).sub(sr);
        let c3=limbs16(v,&i_sg).add(sr).add(Fp2::ONE).sub(sum);
        let key=if keyed {sum} else {Fp2::ZERO};
        let ctab=v[ig].mul(alpha.sub(g_dd.add(key).add(beta.mul(e)).add(beta2.mul(pd)))).sub(md);
        let division=mu[0].mul(c2).add(mu[1].mul(c3));
        let division=match gate {Some(gi)=>v[gi].mul(division),None=>division};
        v[0].mul(division.add(helper_sum(v,&lks,h0,alpha,&mu[2..2+n_help])).add(mu[2+n_help].mul(ctab)))
    };
    b.finish(Box::new(poly),vec![])
}

fn tab_w16(ctx:&Ctx<'_>,tr:&mut Transcript)->Result<SlotDef,String> {
    use crate::private_block::range16;
    let lay=ctx.lay;let(sh,ids,hids)=(lay.shape(),lay.ids(),lay.hids());
    let data=ctx.accuracy.ok_or("W16 table relation requires bound accuracy data")?;
    let(alpha,beta,g_u8,g_exp,g_act)=(ctx.alpha,ctx.beta,ctx.g_u8,ctx.g_exp,ctx.g_act);
    let len=sh.size(Dom::Tab);let mut b=B::new(lay,SC_TAB);
    let rp=ids.accuracy()?.range_planes();let rh:Vec<usize>=hids.range_helpers().collect();
    if rp.len()!=rh.len() {return Err("W16: the range sub-planes and their table helpers differ in number".into());}
    let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::Tab).is_empty();
    let tau=tr.challenge_fp2_vec(sh.log(Dom::Tab));let mu=tr.challenge_fp2_vec(3+rp.len()+usize::from(pad_on));
    let zeta=if pad_on {nonzero(tr.challenge_fp2_vec(1))?[0]} else {Fp2::ZERO};let th=hids.table_helpers();
    let act=crate::private_block::accuracy_act::table(data,len,beta,g_act)?;
    b.eq(&tau,0);
    // (multiplicity, helper, public table) triples: the three, then one per
    // range sub-plane, every table index taken from the builder
    let mut triples=Vec::with_capacity(3+rp.len());
    triples.push((b.a(ids.at(A_MU8))?,b.h(th[0])?,b.public(table_values_u8_at(len,g_u8))));
    triples.push((b.a(ids.at(A_MEXP))?,b.h(th[1])?,b.public(table_values_exp_at(len,ctx.public,beta,g_exp))));
    triples.push((b.a(ids.at(A_MACT))?,b.h(th[2])?,b.public(act.compressed)));
    for (j,(f,s,plane)) in rp.iter().enumerate() {
        triples.push((b.a(*plane)?,b.h(rh[j])?,b.public(range16::table_column(*f,*s,sh.log_cols,range16::g_range(g_u8,f.width)))));
    }
    let mut pz=PadTerm::none();
    if pad_on {
        // the declared zero group: the three histograms and helpers, and the
        // narrow range families' (a full family has no padded copy)
        let narrow:Vec<usize>=(0..rp.len()).filter(|&j| !range16::full(rp[j].0,sh.log_cols)).collect();
        let a_decl:Vec<usize>=[ids.at(A_MU8),ids.at(A_MEXP),ids.at(A_MACT)].into_iter().chain(narrow.iter().map(|&j| rp[j].2)).collect();
        let h_decl:Vec<usize>=th.into_iter().chain(narrow.iter().map(|&j| rh[j])).collect();
        tab_group_is_declared(sh,ids,&a_decl,&h_decl)?;
        let bytes=b.supp(Dom::Tab,len)?;let activation=Some(b.public(act.support));
        pz.mu=mu[3+rp.len()];
        pz.add(bytes,&[triples[0].0,triples[1].0],zeta);pz.add(bytes,&[triples[0].1,triples[1].1],zeta);
        pz.add(activation,&[triples[2].0],zeta);pz.add(activation,&[triples[2].1],zeta);
        for &j in &narrow {
            let support=Some(b.public(range16::support_column(rp[j].0,sh.log_cols)));
            let (m,h,_)=triples[3+j];
            pz.add(support,&[m],zeta);pz.add(support,&[h],zeta);
        }
    }
    b.finish(Box::new(move |v:&[Fp2]| {
        let rel=triples.iter().zip(mu.iter()).fold(Fp2::ZERO,|a,(&(m,h,t),c)| a.add(c.mul(v[h].mul(alpha.sub(v[t])).sub(v[m]))));
        v[0].mul(rel.add(pz.eval(v)))
    }),vec![])
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::accuracy_groups::Group;
    use crate::private_block::accuracy_public::{AccuracyPublic,Geometry,Multipliers};
    use crate::private_block::accuracy_tables::silu_table;
    use crate::private_block::shape::Shape;

    fn case(mut sh:Shape,ng:usize)->(Shape,AccuracyPublic,crate::private_block::AttentionPublic,crate::private_block::FeedForwardPublic) {
        let geometry=Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
        let sequence=|n,max| (0..n).map(|i|1+(i%max) as u16).collect();
        let m=Multipliers{q:sequence(geometry.query_width,32),k:sequence(geometry.kv_width,32),
            v:sequence(geometry.kv_width,64),o:sequence(geometry.width,256),
            g:sequence(geometry.hidden,64),u:sequence(geometry.hidden,16),d:sequence(geometry.width,64)};
        let groups=vec![Group{e_in:-4,e_out:-13},Group{e_in:-3,e_out:-12},Group{e_in:-2,e_out:-11},Group{e_in:-1,e_out:-9}][..ng].to_vec();
        let tables=groups.iter().map(|g|silu_table(g.e_in,g.e_out,12).unwrap()).collect();
        let data=AccuracyPublic::new(sh.accuracy_stack(),geometry,sh.accuracy_base(),(-3,-11),m,groups,
            (0..geometry.hidden).map(|i|i%ng).collect(),tables).unwrap();
        sh=sh.with_accuracy_gate_shift(data.folds().gate.shift).unwrap();
        let (mut public,ff,_)=crate::private_block::grow_tests::tame_case(&sh);
        if sh.dd_cap>0 {
            public.exp=crate::tables_attn::exp_member(4,sh.head_dim,sh.f_e).0.to_vec();
            public.dd_e_column(sh.dd_cap).expect("the DD fixture retains the fixed dictionary cap");
        }
        (sh,data,public,ff)
    }

    fn visit(sh:&Shape,data:&AccuracyPublic,public:&crate::private_block::AttentionPublic,ff:&crate::private_block::FeedForwardPublic,mut f:impl FnMut(SlotDef)) {
        let lay=crate::private_block::layout::Layout::for_shape(sh).unwrap();
        let ctx=Ctx{accuracy:Some(data),lay:&lay,public,ff,alpha:k(7).add(Fp2::U),beta:k(11),g_u8:k(13),g_exp:k(17),g_act:k(19),g_dd:k(23)};
        let mut pts=Points::default();let mut tr=Transcript::new(sh.profile.as_bytes());
        for slot in 0..sh.n_slots() {
            f(define(slot,&ctx,&mut pts,&mut tr).unwrap_or_else(|e|panic!("{} slot{slot}: {e}",sh.name)));
        }
    }

    fn development_shapes()->Vec<Shape> {
        crate::private_block::accuracy_profile_tests::registered_shapes().into_iter().filter(|s|s.tokens==32).collect()
    }

    #[test]
    fn accuracy_native_definitions_match_claim_schedules_for_both_stacks_dd_and_all_group_counts() {
        let mut definitions=0;
        for sh in development_shapes() {for ng in 1..=4 {
            let(sh,data,public,ff)=case(sh.clone(),ng);let(a,h)=sh.claim_sites();
            visit(&sh,&data,&public,&ff,|def| {
                let n=sh.slots()[def.slot].0;let mut counts=[0;4];let mut masks=std::collections::HashSet::new();
                for tab in &def.tabs {match tab {
                    Tab::Eq{point,start}=>assert!(start+point.len()<=n),
                    Tab::Pub(values)=>assert_eq!(values.len(),1usize<<n,"{} slot{} public support",sh.name,def.slot),
                    Tab::Priv(p)=>{
                        counts[p.cm as usize]+=1;
                        assert_eq!(p.coords.len(),p.log);
                        assert!(masks.insert((p.cm as usize,p.mask_row)),"a private claim reuses a mask pair");
                        for c in &p.coords {if let Coord::Rho(i)|Coord::Flip(i)=c {assert!(*i<n);}}
                    },
                }}
                assert_eq!((counts[0],counts[1]),(a[def.slot],h[def.slot]));
                assert_eq!(def.hosted.iter().map(|(s,_)|*s).collect::<Vec<_>>(),
                    HOSTS.iter().find(|(s,_)|*s==def.slot).map(|(_,slots)|slots.to_vec()).unwrap_or_default());
                definitions+=1;
            });
        }}
        assert_eq!(definitions,8*(23+24));
    }

    #[test]
    fn accuracy_native_polynomials_obey_declared_degree_and_extension_zero_property() {
        for sh in development_shapes() {
            let(sh,data,public,ff)=case(sh,4);
            visit(&sh,&data,&public,&ff,|def| {
                let(_,extensions,degree)=sh.slots()[def.slot];
                for seed in [3i64,17,71] {
                    for round in 0..extensions {
                        let values:Vec<_>=def.tabs.iter().enumerate().map(|(i,t)|match t {
                            Tab::Priv(p) if p.ext_round==round=>k(seed+13*i as i64).add(Fp2::U.mul(k(i as i64+1))),
                            _=>Fp2::ZERO,
                        }).collect();
                        assert_eq!((def.poly)(&values),Fp2::ZERO,"{} slot{} extension{round}",sh.name,def.slot);
                    }
                    let mut line:Vec<_>=(0..degree+2).map(|t| {
                        let values:Vec<_>=(0..def.tabs.len()).map(|i|k(seed+7*i as i64).add(k(t as i64).mul(k(11+3*i as i64).add(Fp2::U)))).collect();
                        (def.poly)(&values)
                    }).collect();
                    for _ in 0..=degree {line=line.windows(2).map(|w|w[1].sub(w[0])).collect();}
                    assert_eq!(line,vec![Fp2::ZERO],"{} slot{} exceeds declared degree{degree}",sh.name,def.slot);
                }
            });
        }
    }

    fn inverse_values(mut values:Vec<Fp2>)->Vec<Fp2> {
        crate::field::batch_inverse2_checked(&mut values).unwrap();values
    }

    fn helper_write(dst:&mut[Fp],off:(usize,usize),values:&[Fp2]) {
        for (i,v) in values.iter().enumerate() {dst[off.0+i]=v.c0;dst[off.1+i]=v.c1;}
    }

    /// Independent unmasked A/H frame for relation checks. Multiplicities
    /// and inverses are derived from the integer planes; no PCS or proof
    /// entry point is called while R13 remains disabled.
    fn honest_frame(sh:&Shape,data:&AccuracyPublic,public:&crate::private_block::AttentionPublic,wit:&crate::private_block::witness::Witness,
        alpha:Fp2,beta:Fp2,tags:[Fp2;4])->(Vec<Fp>,Vec<Fp>) {
        use crate::private_block::{accuracy_act,protocol};
        let lay=Layout::for_shape(sh).unwrap();let(ids,hids,n)=(lay.ids(),lay.hids(),lay.n());
        let(mut a,mut h)=(vec![Fp::ZERO;lay.a_rows*n],vec![Fp::ZERO;lay.h_rows*n]);
        for p in lay.a_planes().into_iter().filter(|p|!ids.is_multiplicity(*p)) {
            for (i,&v) in wit.planes[p].iter().enumerate() {a[lay.a_off[p]+i]=Fp::from_i64(v);}
        }
        let inv8=inverse_values((0..256).map(|i|alpha.sub(k(i).add(tags[0]))).collect());
        let mut m8=vec![0u64;256];
        for dom in lay.lookup_doms() {
            let queries=protocol::lookup_values(&lay,wit,dom);
            for column in &queries {for &v in column {assert!((0..256).contains(&v));m8[v as usize]+=1;}}
            let(first,count)=lay.helpers(dom);
            for j in 0..count {
                let values=(0..sh.size(dom)).map(|i|queries[2*j..queries.len().min(2*j+2)].iter()
                    .fold(Fp2::ZERO,|sum,col|sum.add(inv8[col[i] as usize]))).collect::<Vec<_>>();
                helper_write(&mut h,lay.h_off[first+j],&values);
            }
        }
        let deltas=protocol::exp_deltas(&lay,wit);let mut me=vec![0u64;256];
        let exp_queries=deltas.iter().zip(&wit.planes[ids.at(A_E)]).map(|(&d,&e)| {
            assert_eq!(public.exp[d as usize],e);me[d as usize]+=1;k(d).add(beta.mul(k(e))).add(tags[1])
        }).collect::<Vec<_>>();
        helper_write(&mut h,lay.h_off[hids.sexp()],&inverse_values(exp_queries.iter().map(|q|alpha.sub(*q)).collect()));
        let ma=accuracy_act::histogram(sh,data,&wit.planes[ids.at(A_G8)],&wit.planes[ids.at(A_A16)]).unwrap();assert_eq!(ma.1,0);
        let queries=accuracy_act::query_values(sh,data,&wit.planes[ids.at(A_G8)],&wit.planes[ids.at(A_A16)],beta,tags[2]).unwrap();
        helper_write(&mut h,lay.h_off[hids.fact()],&inverse_values(queries.iter().map(|q|alpha.sub(*q)).collect()));
        let activation=accuracy_act::table(data,sh.size(Dom::Tab),beta,tags[2]).unwrap();
        let tables=[(ids.at(A_MU8),hids.table_helpers()[0],table_values_u8(tags[0]),m8),
            (ids.at(A_MEXP),hids.table_helpers()[1],table_values_exp(public,beta,tags[1]),me),
            (ids.at(A_MACT),hids.table_helpers()[2],activation.compressed[..activation.entries].to_vec(),ma.0)];
        for (plane,helper,values,m) in tables {
            assert_eq!(values.len(),m.len());
            for (i,&count) in m.iter().enumerate() {a[lay.a_off[plane]+i]=Fp::new(count);}
            let inverses=inverse_values(values.iter().map(|q|alpha.sub(*q)).collect());
            helper_write(&mut h,lay.h_off[helper],&inverses.iter().zip(&m).map(|(v,&count)|v.mul_base(Fp::new(count))).collect::<Vec<_>>());
        }
        if sh.dd_cap>0 {
            let(q,t)=protocol::dd_tuples(&lay,wit,&public.dd_e_column(sh.dd_cap).unwrap(),beta,tags[3]);
            helper_write(&mut h,lay.h_off[hids.stuple()],&inverse_values(q.iter().map(|v|alpha.sub(*v)).collect()));
            let values=inverse_values(t.iter().map(|v|alpha.sub(*v)).collect());
            helper_write(&mut h,lay.h_off[hids.gdd()],&values.iter().zip(&wit.planes[ids.mdd()]).map(|(v,&m)|v.mul_base(Fp::from_i64(m))).collect::<Vec<_>>());
        }
        (a,h)
    }

    #[test]
    fn accuracy_honest_full_word_witness_satisfies_native_host_relations_and_new_limb_mutation_fails() {
        for original in development_shapes() {
            let cal=crate::private_block::shape::NormCalibration{cn_a:4000,cn_m:4000,..original.norm_calibration()};
            let original=Shape::accuracy_trained(original.profile,&cal,original.f_e,20).unwrap();
            let(sh,data,public,ff)=case(original,3);
            let input:Vec<_>=(0..sh.tokens*sh.width).map(|i|((i*37+11)%201) as i16-100).collect();
            let wit=crate::private_block::witness::build_accuracy(&sh,&public,&ff,&data,&input).unwrap();
            let lay=Layout::for_shape(&sh).unwrap();let ids=lay.ids();
            assert!(wit.planes[ids.at(A_Y)].iter().any(|v|v.abs()>127));
            assert!(wit.planes[ids.at(A_Q8)].iter().any(|v|v.abs()>127));
            let(alpha,beta,tags)=(k(7).add(Fp2::U),k(11),[k(13),k(17),k(19),k(23)]);
            let(a,h)=honest_frame(&sh,&data,&public,&wit,alpha,beta,tags);
            let mut checked=0;let mut detected=false;
            visit(&sh,&data,&public,&ff,|mut def| {
                if ![SC_DZC,SC_QZC,SC_KVZC,SC_SZC,SC_FZC,SC_DD,SC_TAB].contains(&def.slot) {return;}
                let pd=ProverData{data:[&a,&h,&[],&[]],masks:&[]};
                let tables=build_tables_at(&mut def.tabs,sh.slots()[def.slot].0,&pd,usize::MAX);
                let mut row=vec![Fp2::ZERO;tables.len()];
                for i in 0..tables[0].len() {
                    for (v,table) in row.iter_mut().zip(&tables) {*v=table[i];}
                    // Suppress the hosted matmul sums, retaining the entire
                    // native zero-check, all lookup helpers and pad terms.
                    if !def.hosted.is_empty() {row[1]=Fp2::ZERO;row[2]=Fp2::ZERO;}
                    assert_eq!((def.poly)(&row),Fp2::ZERO,"{} slot{} row{i}",sh.name,def.slot);
                    if def.slot==SC_DZC && i==0 {
                        let plane=ids.accuracy().unwrap().limb(L::Y,1);
                        let claim=def.tabs.iter().position(|t|matches!(t,Tab::Priv(p) if p.cm==Cm::A && p.slices==vec![(lay.a_off[plane],Fp2::ONE)])).unwrap();
                        let mut forged=row.clone();forged[claim]=forged[claim].add(Fp2::ONE);
                        detected=!(def.poly)(&forged).is_zero();
                    }
                }
                checked+=1;
            });
            assert_eq!(checked,if sh.dd_cap>0 {7} else {6});
            assert!(detected,"the new norm output high byte did not reach the native relation");
        }
    }

    #[test]
    fn accuracy_public_context_checks_stack_denominator_presence_and_symmetric_words() {
        use crate::private_block::{BlockPublic,trained_statement::LayerRecord};
        for original in development_shapes() {
            let(sh,data,public,ff)=case(original,3);
            let missing=BlockPublic::new(public.clone(),ff.clone());
            assert!(missing.check_accuracy_for_shape(&sh).unwrap_err().contains("missing"));
            let blk=missing.with_accuracy(data.clone());
            blk.check_accuracy_for_shape(&sh).unwrap();
            blk.check_for_shape(&sh).unwrap();
            let wrong=sh.clone().with_accuracy_gate_shift(if sh.accuracy_gate_shift==17 {18} else {17}).unwrap();
            assert!(blk.check_accuracy_for_shape(&wrong).unwrap_err().contains("denominator"));
            assert!(blk.check_accuracy_for_shape(&Shape::toy()).is_err());
            let mut bad_public=public.clone();bad_public.wq[0]=i8::MIN;
            assert!(BlockPublic::new(bad_public,ff.clone()).with_accuracy(data.clone())
                .check_accuracy_for_shape(&sh).unwrap_err().contains("symmetric"));
            let rec=LayerRecord::of_block(0,&blk,vec![]);
            assert_eq!(rec.accuracy_gate_shift,Some(data.folds().gate.shift));
            let raw:Vec<u8>=data.raw_tables().iter().flatten().flat_map(|w|w.to_le_bytes()).collect();
            assert_eq!(rec.table_sha256[2],crate::private_block::trained_block::sha256(&raw));
            let legacy:Vec<u8>=ff.act.iter().flat_map(|w|w.to_le_bytes()).collect();
            assert_ne!(rec.table_sha256[2],crate::private_block::trained_block::sha256(&legacy));
        }
    }
}

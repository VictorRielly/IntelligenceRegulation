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

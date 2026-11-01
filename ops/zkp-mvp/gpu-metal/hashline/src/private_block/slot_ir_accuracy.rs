//! [ZK60-METAL M4, 2026-10-31] The R13 accuracy stack's redefined zero-checks
//! (`argument_accuracy.rs`: `dzc`, `fzc`, `qzc`, `szc`) as slot expression IR,
//! so the real classifier's heavy sumchecks can run on the Apple GPU.
//!
//! Each builder below mirrors ONE function of `argument_accuracy.rs`: the same
//! challenge draws in the same order and counts (on the caller's TWIN
//! transcript), the same table pushes in the same order (so a table id here is
//! the closure's `v[..]` index), and the same polynomial written as nodes and
//! terms. Nothing here is trusted on its own: before a slot may run on the
//! device, `argument.rs` evaluates this IR against the very closure being proved
//! at eight pseudo-random points of the whole space (`metal_slot::
//! ir_matches_closure`), and a slot that differs stays on the CPU. Field kinds
//! come from table provenance as in `slot_ir.rs`, and the device re-checks every
//! base-typed table on upload.
//!
//! Not transcribed (they stay on the CPU, and say so with an `Err`, so no legacy
//! arm runs for them): the DD variant of the softmax zero-check (`szc_dd`), the
//! dictionary slot (`dd`) and the table-helper slot (`tab`).

use super::*;
use crate::private_block::accuracy_layout::{AccuracyIds, Limbs as L};
use crate::private_block::accuracy_precision::Stack;

/// The accuracy arm of [`build_slot_ir`]: `Ok(None)` for a slot the accuracy
/// stack does not redefine (the legacy arm applies), `Ok(Some(terms))` for a
/// transcribed one (with its own pad flag), `Err` for a redefined slot without an IR.
pub(super) fn build(slot: usize, ctx: &Ctx, pts: &IrPoints, tr: &mut Transcript, b: &mut IrB) -> Result<Option<(Vec<SlotTerm>, bool)>, String> {
    let sh = ctx.lay.shape();
    if sh.accuracy_stack() == Stack::Legacy {
        return Ok(None);
    }
    // `define_changed`'s preconditions draw nothing; the accuracy data must exist
    let data = ctx.accuracy.ok_or("R13 IR requires bound accuracy public data")?;
    // W16 (D54): `argument_accuracy`'s `*_w16` relations; the DD softmax, the
    // dictionary and the table slot stay on the CPU as they do on R13
    if sh.range16() {
        return match slot {
            SC_DZC => dzc_w16(b, ctx, pts, tr).map(Some),
            SC_FZC => fzc_w16(b, ctx, data, pts, tr).map(Some),
            SC_QZC | SC_KVZC => qzc_w16(slot, b, ctx, pts, tr).map(Some),
            SC_SZC if sh.dd_cap > 0 => Err("W16 IR: the DD softmax zero-check is not transcribed".into()),
            SC_SZC => szc_w16(b, ctx, pts, tr).map(Some),
            SC_DD => Err("W16 IR: the dictionary slot is not transcribed".into()),
            SC_TAB => tab_w16(b, ctx, tr).map(Some),
            _ => Ok(None),
        };
    }
    match slot {
        SC_DZC => dzc(b, ctx, pts, tr).map(Some),
        SC_FZC => fzc(b, ctx, data, pts, tr).map(Some),
        SC_QZC | SC_KVZC => qzc(slot, b, ctx, pts, tr).map(Some),
        SC_SZC if sh.dd_cap > 0 => Err("R13 IR: the DD softmax zero-check is not transcribed".into()),
        SC_SZC => szc(b, ctx, pts, tr).map(Some),
        SC_DD => Err("R13 IR: the dictionary slot is not transcribed".into()),
        SC_TAB => Err("R13 IR: the R13 table-helper slot is not transcribed".into()),
        _ => Ok(None),
    }
}

fn nonzero(v: Vec<Fp2>) -> Result<Vec<Fp2>, String> {
    if v.iter().any(|x| x.is_zero()) {
        return Err("zero batching challenge".into());
    }
    Ok(v)
}

/// `argument_accuracy::role`: the table indices of a limb group, by shaped id
fn role(b: &IrB, low: &AccuracyIds, group: L) -> Result<Vec<usize>, String> {
    let ix: Vec<usize> = (0..low.count(group)).map(|k| b.tab(low.limb(group, k))).collect();
    if ix.contains(&usize::MAX) {
        return Err("R13 IR: a limb outside its claimed domain".into());
    }
    Ok(ix)
}

/// a toy plane id -> table id, refusing a plane outside the range
fn at(idx: &[usize], p: usize) -> Result<TableId, String> {
    match idx.get(p) {
        Some(&t) if t != usize::MAX => Ok(t as TableId),
        _ => Err(format!("R13 IR: plane {p} outside the slot's range")),
    }
}

fn base(v: i64) -> Coef {
    Coef::base(v, "an R13 public integer")
}

/// `x + 32768 - limbs(ix)`: an int16 clause
fn int16(b: &mut IrB, label: &str, x: TableId, ix: &[usize]) -> NodeId {
    let l = limbs_node(b, &format!("limbs of {label}"), ix);
    b.sum(label.to_string(), vec![st(Coef::one(), vec![ft(x)]), st(base(32768), vec![]), st(Coef::neg_one(), vec![fnd(l)])])
}

/// `2^s * x + limbs(r) - 2^(s-1)`: a host term's requantization
fn requant(b: &mut IrB, label: &str, s: u32, x: TableId, r: &[usize]) -> NodeId {
    let l = limbs_node(b, &format!("limbs of {label}"), r);
    b.sum(label.to_string(), vec![st(base(1i64 << s), vec![ft(x)]), st(Coef::one(), vec![fnd(l)]), st(base(-(1i64 << (s - 1))), vec![])])
}

/// the three top-level terms every accuracy zero-check shares:
/// `eq0 * zc + nu0 * eq1 * gate * host1 + nu1 * eq2 * gate * host2`
fn three_terms(eq: [TableId; 3], gate: Option<TableId>, zc: NodeId, nu: &[Fp2], host1: NodeId, host2: NodeId) -> Vec<SlotTerm> {
    let g: Vec<TableId> = gate.into_iter().collect();
    vec![
        SlotTerm { coef: Coef::one(), wrapper: vec![eq[0]], inner: vec![fnd(zc)], note: "eq(tau) * zc".to_string() },
        SlotTerm { coef: Coef::nu(0, nu[0]), wrapper: [vec![eq[1]], g.clone()].concat(), inner: vec![fnd(host1)], note: "host 1".to_string() },
        SlotTerm { coef: Coef::nu(1, nu[1]), wrapper: [vec![eq[2]], g].concat(), inner: vec![fnd(host2)], note: "host 2".to_string() },
    ]
}

/// `sum_k mu_k * clause_k`
fn batch(b: &mut IrB, label: &str, mu: &[Fp2], clauses: &[NodeId]) -> NodeId {
    b.sum(label.to_string(), clauses.iter().enumerate().map(|(k, c)| st(Coef::mu(k, mu[k]), vec![fnd(*c)])).collect())
}

/// `gate * node` as one subterm (the constant ONE where the profile has no gate)
fn gated(gate: Option<TableId>, n: NodeId) -> SubTerm {
    let mut f: Vec<Factor> = gate.into_iter().map(ft).collect();
    f.push(fnd(n));
    st(Coef::one(), f)
}

// ------------------------------------------------------------------- SC_DZC

fn dzc(b: &mut IrB, ctx: &Ctx, pts: &IrPoints, tr: &mut Transcript) -> Result<(Vec<SlotTerm>, bool), String> {
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let low = ids.accuracy()?;
    let precision = sh.accuracy_precision()?;
    let pad_on = !super::super::pad::zero_rule_a_planes(sh, ids, Dom::D).is_empty();
    let n_help = sh.helpers(Dom::D);
    let mu = tr.challenge_fp2_vec(13 + n_help + usize::from(pad_on));
    let nu = nonzero(tr.challenge_fp2_vec(2))?;
    let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
    let tau_len = tr.challenge_fp2_vec(sh.log(Dom::D)).len();
    let i_tau = b.eq(tau_len, 0, "tau");
    let i_pa = b.eq(pts.p_a, 0, "p_a");
    let i_pz = b.eq(pts.p_z, 0, "p_z");
    let ig = b.public_shape("gamma_a on the padded width");
    let igm = b.public_shape("gamma_m on the padded width");
    let range = ids.domain_range(Dom::D)?;
    let idx = b.a_range(range.start, range.end - 1);
    let (nr, ns, mr, ms) = (role(b, low, L::Nr)?, role(b, low, L::Ns)?, role(b, low, L::Mr)?, role(b, low, L::Ms)?);
    let (xl, yl, al, ral, x1l, yml, zl, rdl, x2l) = (
        role(b, low, L::X)?,
        role(b, low, L::Y)?,
        role(b, low, L::Ao)?,
        role(b, low, L::Rao)?,
        role(b, low, L::X1)?,
        role(b, low, L::Ym)?,
        role(b, low, L::Z)?,
        role(b, low, L::Rd)?,
        role(b, low, L::X2)?,
    );
    let id = b.a_slice("A_D read on the row axis");
    let idm = b.a_slice("A_DM read on the row axis");
    let h0 = b.h(hids.first_helper(Dom::D));
    for j in 1..n_help {
        b.h(hids.helper(Dom::D, j));
    }
    let shaped = b.shaped.clone();
    let gd = b.supp(Dom::D);
    let mut pz = if pad_on { IrPad::new(Coef::mu(13 + n_help, mu[13 + n_help]), zeta) } else { IrPad::none() };
    if pad_on {
        let planes: Vec<usize> = super::super::pad::zero_rule_a_planes(sh, ids, Dom::D).iter().map(|p| b.tab(*p)).collect();
        pz.add(gd, &planes);
    }
    let (num, num_m) = (2 * sh.norm_cn_a as i64, 2 * sh.norm_cn_m as i64);
    let (dv, den) = (1i64 << precision.norm_tn, 1i64 << (precision.norm_tn + 1));
    let (x, y, ao, x1, ym, z, x2) = (at(&idx, A_X)?, at(&idx, A_Y)?, at(&idx, A_AO)?, at(&idx, A_X1)?, at(&idx, A_YM)?, at(&idx, A_Z16)?, at(&idx, A_X2)?);
    let (n_nr, n_ns, n_mr, n_ms) = (limbs_node(b, "nr", &nr), limbs_node(b, "ns", &ns), limbs_node(b, "mr", &mr), limbs_node(b, "ms", &ms));
    let one = Coef::one;
    let neg = Coef::neg_one;
    let c0 = b.sum("c0".into(), vec![st(base(num), vec![ft(ig), ft(x)]), st(base(dv), vec![ft(id)]), st(base(-den), vec![ft(y), ft(id)]), st(neg(), vec![fnd(n_nr)])]);
    let c1 = b.sum("c1".into(), vec![st(one(), vec![fnd(n_nr)]), st(one(), vec![fnd(n_ns)]), st(one(), vec![]), st(base(-den), vec![ft(id)])]);
    let c2 = int16(b, "c2: x", x, &xl);
    let c3 = int16(b, "c3: y", y, &yl);
    let c4 = int16(b, "c4: ao", ao, &al);
    let c5 = int16(b, "c5: x1", x1, &x1l);
    let c6 = b.sum("c6: x1 - x - ao".into(), vec![st(one(), vec![ft(x1)]), st(neg(), vec![ft(x)]), st(neg(), vec![ft(ao)])]);
    let c7 = b.sum("c7".into(), vec![st(base(num_m), vec![ft(igm), ft(x1)]), st(base(dv), vec![ft(idm)]), st(base(-den), vec![ft(ym), ft(idm)]), st(neg(), vec![fnd(n_mr)])]);
    let c8 = b.sum("c8".into(), vec![st(one(), vec![fnd(n_mr)]), st(one(), vec![fnd(n_ms)]), st(one(), vec![]), st(base(-den), vec![ft(idm)])]);
    let c9 = int16(b, "c9: ym", ym, &yml);
    let c10 = int16(b, "c10: z", z, &zl);
    let c11 = int16(b, "c11: x2", x2, &x2l);
    let c12 = b.sum("c12: x2 - x1 - z".into(), vec![st(one(), vec![ft(x2)]), st(neg(), vec![ft(x1)]), st(neg(), vec![ft(z)])]);
    let cl = batch(b, "the thirteen R13 norm/residual clauses", &mu, &[c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12]);
    let mut zt = logup_subterms(b, Dom::D, h0, ctx.alpha, ctx.g_u8, &|k| Coef::mu(13 + k, mu[13 + k]), &shaped, "D");
    zt.extend(pz.subterms(b));
    zt.push(gated(gd, cl));
    let zc = b.sum("zc".into(), zt);
    let host_o = requant(b, "host SC_WO", precision.ao, ao, &ral);
    let host_d = requant(b, "host SC_DMM", precision.down, z, &rdl);
    Ok((three_terms([i_tau, i_pa, i_pz], gd, zc, &nu, host_o, host_d), pad_on))
}

// ------------------------------------------------------------------- SC_FZC

fn fzc(b: &mut IrB, ctx: &Ctx, data: &crate::private_block::accuracy_public::AccuracyPublic, pts: &IrPoints, tr: &mut Transcript) -> Result<(Vec<SlotTerm>, bool), String> {
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let low = ids.accuracy()?;
    let precision = sh.accuracy_precision()?;
    let pad_on = !super::super::pad::zero_rule_a_planes(sh, ids, Dom::F).is_empty();
    let n_help = sh.helpers(Dom::F);
    let mu = tr.challenge_fp2_vec(4 + n_help + usize::from(pad_on));
    let nu = nonzero(tr.challenge_fp2_vec(2))?;
    let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
    let tau_len = tr.challenge_fp2_vec(sh.log(Dom::F)).len();
    let i_tau = b.eq(tau_len, 0, "tau");
    let i_pg = b.eq(pts.p_g, 0, "p_g");
    let i_pu = b.eq(pts.p_u, 0, "p_u");
    let range = ids.domain_range(Dom::F)?;
    let idx = b.a_range(range.start, range.end - 1);
    let (rg, ul, ru, hl, rh) = (role(b, low, L::Rg)?, role(b, low, L::Up)?, role(b, low, L::Ru)?, role(b, low, L::H)?, role(b, low, L::Rh)?);
    let h0 = b.h(hids.first_helper(Dom::F));
    for j in 1..n_help {
        b.h(hids.helper(Dom::F, j));
    }
    let fact = b.h(hids.fact());
    let shaped = b.shaped.clone();
    let group = b.public_shape("the activation group column (public accuracy data)");
    let gf = b.supp(Dom::F);
    let mut pz = if pad_on { IrPad::new(Coef::mu(4 + n_help, mu[4 + n_help]), zeta) } else { IrPad::none() };
    if pad_on {
        let planes: Vec<usize> = super::super::pad::zero_rule_a_planes(sh, ids, Dom::F).iter().map(|p| b.tab(*p)).collect();
        pz.add(gf, &planes);
    }
    let (r, gate) = (data.folds().product.shift, sh.accuracy_gate_shift);
    let (alpha, beta, tag) = (ctx.alpha, ctx.beta, ctx.g_act);
    let beta2 = beta.mul(beta);
    let (g, a, u, h) = (at(&idx, A_G8)?, at(&idx, A_A16)?, at(&idx, A_U16)?, at(&idx, A_H16)?);
    let n_rh = limbs_node(b, "rh", &rh);
    let n_hl = limbs_node(b, "hl", &hl);
    let f0 = b.sum(
        "f0: a u - 2^r h - rh + 2^(r-1)".into(),
        vec![st(Coef::one(), vec![ft(a), ft(u)]), st(base(-(1i64 << r)), vec![ft(h)]), st(Coef::neg_one(), vec![fnd(n_rh)]), st(base(1i64 << (r - 1)), vec![])],
    );
    let f1 = int16(b, "f1: u", u, &ul);
    let f2 = b.sum(
        "f2: h + 2^(pb-1) - hl".into(),
        vec![st(Coef::one(), vec![ft(h)]), st(base(1i64 << (precision.product_bits - 1)), vec![]), st(Coef::neg_one(), vec![fnd(n_hl)])],
    );
    // alpha - query, query = g + 2048 + beta a + beta^2 group + tag
    let amq = b.affine(
        "alpha - query".into(),
        Coef::chal(alpha.sub(Fp2::from_i64(2048)).sub(tag), "alpha - 2048 - g_act"),
        vec![(Coef::neg_one(), g), (Coef::chal(beta.neg(), "-beta"), a), (Coef::chal(beta2.neg(), "-beta^2"), group)],
    );
    let fa = b.sum("fa: fact (alpha - query) - 1".into(), vec![st(Coef::one(), vec![ft(fact), fnd(amq)]), st(Coef::neg_one(), vec![])]);
    let ar = batch(b, "the three R13 product clauses", &mu, &[f0, f1, f2]);
    let mut zt = logup_subterms(b, Dom::F, h0, alpha, ctx.g_u8, &|k| Coef::mu(4 + k, mu[4 + k]), &shaped, "F");
    zt.push(st(Coef::mu(3, mu[3]), vec![fnd(fa)]));
    zt.extend(pz.subterms(b));
    zt.push(gated(gf, ar));
    let zc = b.sum("zc".into(), zt);
    let host_g = requant(b, "host SC_GMM", gate, g, &rg);
    let host_u = requant(b, "host SC_UMM", precision.up, u, &ru);
    Ok((three_terms([i_tau, i_pg, i_pu], gf, zc, &nu, host_g, host_u), pad_on))
}

// --------------------------------------------------------- SC_QZC / SC_KVZC

fn qzc(slot: usize, b: &mut IrB, ctx: &Ctx, pts: &IrPoints, tr: &mut Transcript) -> Result<(Vec<SlotTerm>, bool), String> {
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let low = ids.accuracy()?;
    let precision = sh.accuracy_precision()?;
    let q = slot == SC_QZC;
    let dom = if q { Dom::Q } else { Dom::Kv };
    let log = sh.log(dom);
    let pad_on = !super::super::pad::zero_rule_a_planes(sh, ids, dom).is_empty();
    let n_help = sh.helpers(dom);
    let mu = tr.challenge_fp2_vec(4 + n_help + usize::from(pad_on));
    let nu = nonzero(tr.challenge_fp2_vec(2))?;
    let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
    let tau_len = tr.challenge_fp2_vec(log).len();
    let i_tau = b.eq(tau_len, 0, "tau");
    let i_p1 = b.eq(if q { pts.pq } else { pts.pk }, 0, if q { "pq" } else { "pk" });
    let i_p2 = b.eq(if q { pts.p_o } else { pts.pv }, 0, if q { "p_o" } else { "pv" });
    let ic = b.public_shape("the RoPE cos table");
    let is = b.public_shape("the RoPE sin table");
    let range = ids.domain_range(dom)?;
    let idx = b.a_range(range.start, range.end - 1);
    let (source, rotated, rr, lword, lrword, other, lother, rsource, rother, s1, s2) = if q {
        (A_Q8, A_QR8, L::Rqr, L::Q, L::Qr, A_O8, L::O, L::Rq, L::Ro, precision.q, precision.pv)
    } else {
        (A_K8, A_KR8, L::Rkr, L::K, L::Kr, A_V8, L::V, L::Rk, L::Rv, precision.k, precision.v)
    };
    let (wl, rwl, ol, r1, r2, rotrem) =
        (role(b, low, lword)?, role(b, low, lrword)?, role(b, low, lother)?, role(b, low, rsource)?, role(b, low, rother)?, role(b, low, rr)?);
    // `b.a_at(source, coords with the head coordinate flipped, 0)`: one plane
    // read with a public coordinate permutation (no challenge: base-field)
    let flip = b.a_fixed(ids.at(source), 0, "the RoPE partner half (Coord::Flip at log - log2(head_dim))");
    let h0 = b.h(hids.first_helper(dom));
    for j in 1..n_help {
        b.h(hids.helper(dom, j));
    }
    let shaped = b.shaped.clone();
    let gate = b.supp(dom);
    let mut pz = if pad_on { IrPad::new(Coef::mu(4 + n_help, mu[4 + n_help]), zeta) } else { IrPad::none() };
    if pad_on {
        let planes: Vec<usize> = super::super::pad::zero_rule_a_planes(sh, ids, dom).iter().map(|p| b.tab(*p)).collect();
        pz.add(gate, &planes);
    }
    let (src, rot, oth) = (at(&idx, source)?, at(&idx, rotated)?, at(&idx, other)?);
    let n_rr = limbs_node(b, "the rotation remainder", &rotrem);
    let rope = b.sum(
        "rope: cos src + sin flip - 2^SH_ROPE rot - rem + 2^(SH_ROPE-1)".into(),
        vec![
            st(Coef::one(), vec![ft(ic), ft(src)]),
            st(Coef::one(), vec![ft(is), ft(flip)]),
            st(base(-(1i64 << SH_ROPE)), vec![ft(rot)]),
            st(Coef::neg_one(), vec![fnd(n_rr)]),
            st(base(1i64 << (SH_ROPE - 1)), vec![]),
        ],
    );
    let c1 = int16(b, "source", src, &wl);
    let c2 = int16(b, "rotated", rot, &rwl);
    let c3 = int16(b, "other", oth, &ol);
    let ar = batch(b, "the four R13 rope/range clauses", &mu, &[rope, c1, c2, c3]);
    let mut zt = logup_subterms(b, dom, h0, ctx.alpha, ctx.g_u8, &|k| Coef::mu(4 + k, mu[4 + k]), &shaped, "QKV");
    zt.extend(pz.subterms(b));
    zt.push(gated(gate, ar));
    let zc = b.sum("zc".into(), zt);
    let host1 = requant(b, "host 1", s1, src, &r1);
    let host2 = requant(b, "host 2", s2, oth, &r2);
    Ok((three_terms([i_tau, i_p1, i_p2], gate, zc, &nu, host1, host2), pad_on))
}

// ------------------------------------------------------------- SC_SZC, non-DD

fn szc(b: &mut IrB, ctx: &Ctx, pts: &IrPoints, tr: &mut Transcript) -> Result<(Vec<SlotTerm>, bool), String> {
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let low = ids.accuracy()?;
    let precision = sh.accuracy_precision()?;
    let (alpha, beta, g_exp) = (ctx.alpha, ctx.beta, ctx.g_exp);
    let (ls, lp) = (sh.limbs_sigma_s(), sh.limbs_p());
    let pad_on = ALL_DOMS
        .into_iter()
        .any(|d| super::super::pad::pad_zero_host(d) == SC_SZC && !super::super::pad::zero_rule_a_planes(sh, ids, d).is_empty());
    let n_pad = usize::from(pad_on);
    let tau_len = tr.challenge_fp2_vec(sh.log(Dom::S)).len();
    let n_help = sh.helpers(Dom::S);
    let mu = tr.challenge_fp2_vec(5 + n_help + 1 + n_pad);
    let nu = nonzero(tr.challenge_fp2_vec(2))?;
    let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
    let lam = pts.lam_z;
    let i_tau = b.eq(tau_len, 0, "tau");
    let i_pht = b.eq(pts.p_ht, 0, "p_ht");
    let i_ps = b.eq(pts.p_s, 0, "p_s");
    let im = b.public_shape("the causal mask");
    let idx = b.a_range(ids.at(A_S8), ids.sg(ls - 1));
    let i_pl: Vec<usize> = (0..lp).map(|kk| b.tab(ids.pl(kk))).collect();
    let i_sr: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sr(kk))).collect();
    let i_sg: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sg(kk))).collect();
    let imx = b.a_slice("A_MX on Dom::Ht");
    let isum = b.a_slice("A_SUM on Dom::Ht");
    let h0 = b.h(hids.first_helper(Dom::S));
    for j in 1..n_help {
        b.h(hids.helper(Dom::S, j));
    }
    let ihx = b.h(hids.sexp());
    let shaped = b.shaped.clone();
    let rsl = role(b, low, L::Rs)?;
    let b_fp = 1i64 << sh.f_p();
    let b_shs = 1i64 << precision.score;
    let s_half = super::super::witness::half(precision.score);
    let ght = b.supp(Dom::Ht);
    let gs = b.supp(Dom::S);
    let mut pz = if pad_on { IrPad::new(Coef::mu(5 + n_help + 1, mu[5 + n_help + 1]), zeta) } else { IrPad::none() };
    if pad_on {
        if super::super::pad::zero_rule_a_planes(sh, ids, Dom::Ht) != vec![ids.at(A_MX), ids.at(A_SUM)] {
            return Err("R13 IR: a Dom::Ht plane is outside SC_SZC's pad-zero group".into());
        }
        pz.add(ght, &[usize::from(imx), usize::from(isum)]);
        let planes: Vec<usize> = super::super::pad::zero_rule_a_planes(sh, ids, Dom::S).iter().map(|p| b.tab(*p)).collect();
        pz.add(gs, &planes);
    }
    let (s8, zsel, e, p) = (at(&idx, A_S8)?, at(&idx, A_ZSEL)?, at(&idx, A_E)?, at(&idx, A_P)?);
    let ms = -MASK_SCORE; // 127
    // delta = mx - mask (s8 + 127) + 127
    let delta = b.sum(
        "delta".into(),
        vec![st(Coef::one(), vec![ft(imx)]), st(Coef::neg_one(), vec![ft(im), ft(s8)]), st(base(-ms), vec![ft(im)]), st(base(ms), vec![])],
    );
    let n_sr = limbs_node(b, "sr", &i_sr);
    let n_sg = limbs_node(b, "sg", &i_sg);
    let n_pl = limbs_node(b, "pl", &i_pl);
    let c0 = b.sum("c0: zsel^2 - zsel".into(), vec![st(Coef::one(), vec![ft(zsel), ft(zsel)]), st(Coef::neg_one(), vec![ft(zsel)])]);
    let c1 = b.sum("c1: zsel delta".into(), vec![st(Coef::one(), vec![ft(zsel), fnd(delta)])]);
    let c2 = b.sum(
        "c2: 2^f_p mask e - p sum - sr".into(),
        vec![st(base(b_fp), vec![ft(im), ft(e)]), st(Coef::neg_one(), vec![ft(p), ft(isum)]), st(Coef::neg_one(), vec![fnd(n_sr)])],
    );
    let c3 = b.sum(
        "c3: sg + sr + 1 - sum".into(),
        vec![st(Coef::one(), vec![fnd(n_sg)]), st(Coef::one(), vec![fnd(n_sr)]), st(Coef::one(), vec![]), st(Coef::neg_one(), vec![ft(isum)])],
    );
    let c4 = b.sum("c4: p - pl".into(), vec![st(Coef::one(), vec![ft(p)]), st(Coef::neg_one(), vec![fnd(n_pl)])]);
    // cx = ihx (alpha - (delta + beta e + g_exp)) - 1
    let amd = b.sum(
        "alpha - delta - beta e - g_exp".into(),
        vec![st(Coef::chal(alpha.sub(g_exp), "alpha - g_exp"), vec![]), st(Coef::neg_one(), vec![fnd(delta)]), st(Coef::chal(beta.neg(), "-beta"), vec![ft(e)])],
    );
    let cx = b.sum("cx".into(), vec![st(Coef::one(), vec![ft(ihx), fnd(amd)]), st(Coef::neg_one(), vec![])]);
    let cl = batch(b, "the five R13 softmax clauses", &mu, &[c0, c1, c2, c3, c4]);
    let mut zt = logup_subterms(b, Dom::S, h0, alpha, ctx.g_u8, &|k| Coef::mu(5 + k, mu[5 + k]), &shaped, "S");
    zt.push(st(Coef::mu(5 + n_help, mu[5 + n_help]), vec![fnd(cx)]));
    zt.extend(pz.subterms(b));
    zt.push(gated(gs, cl));
    let zc = b.sum("zc".into(), zt);
    // the two hosted groups of the grouped evaluator: nu0 ght (sum + lam), nu1 gs host_s
    let rs = b.sum("sum + lam_z".into(), vec![st(Coef::one(), vec![ft(isum)]), st(Coef::chal(lam, "lam_z"), vec![])]);
    let n_rsl = limbs_node(b, "rsl", &rsl);
    let host_s = b.sum(
        "host SC_SCORE: 2^score s8 + rsl - half".into(),
        vec![st(base(b_shs), vec![ft(s8)]), st(Coef::one(), vec![fnd(n_rsl)]), st(base(-s_half), vec![])],
    );
    let gh: Vec<TableId> = ght.into_iter().collect();
    let gsv: Vec<TableId> = gs.into_iter().collect();
    let terms = vec![
        SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "eq(tau) * zc".to_string() },
        SlotTerm { coef: Coef::nu(0, nu[0]), wrapper: [vec![i_pht], gh].concat(), inner: vec![fnd(rs)], note: "host SC_RS".to_string() },
        SlotTerm { coef: Coef::nu(1, nu[1]), wrapper: [vec![i_ps], gsv].concat(), inner: vec![fnd(host_s)], note: "host SC_SCORE".to_string() },
    ];
    Ok((terms, pad_on))
}

// ---------------------------------------------------------------- W16 (D54)
//
// `argument_accuracy`'s `*_w16` relations as IR: the R13 builders above with
// the 16-bit words' decomposition clauses dropped (and their challenges), the
// remainders' limbs at weight 2^16, and each lookup folding its own family tag
// (`logup_subterms`). Table pushes are in the relations' order, as above.

/// `2^s * x + limbs16(r) - 2^(s-1)`
fn requant16(b: &mut IrB, label: &str, s: u32, x: TableId, r: &[usize]) -> NodeId {
    let l = limbs16_node(b, &format!("16-bit limbs of {label}"), r);
    b.sum(label.to_string(), vec![st(base(1i64 << s), vec![ft(x)]), st(Coef::one(), vec![fnd(l)]), st(base(-(1i64 << (s - 1))), vec![])])
}

fn dzc_w16(b: &mut IrB, ctx: &Ctx, pts: &IrPoints, tr: &mut Transcript) -> Result<(Vec<SlotTerm>, bool), String> {
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let low = ids.accuracy()?;
    let precision = sh.accuracy_precision()?;
    let pad_on = !super::super::pad::zero_rule_a_planes(sh, ids, Dom::D).is_empty();
    let n_help = sh.helpers(Dom::D);
    let mu = tr.challenge_fp2_vec(6 + n_help + usize::from(pad_on));
    let nu = nonzero(tr.challenge_fp2_vec(2))?;
    let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
    let tau_len = tr.challenge_fp2_vec(sh.log(Dom::D)).len();
    let i_tau = b.eq(tau_len, 0, "tau");
    let i_pa = b.eq(pts.p_a, 0, "p_a");
    let i_pz = b.eq(pts.p_z, 0, "p_z");
    let ig = b.public_shape("gamma_a on the padded width");
    let igm = b.public_shape("gamma_m on the padded width");
    let range = ids.domain_range(Dom::D)?;
    let idx = b.a_range(range.start, range.end - 1);
    let (nr, ns, mr, ms) = (role(b, low, L::Nr)?, role(b, low, L::Ns)?, role(b, low, L::Mr)?, role(b, low, L::Ms)?);
    let (ral, rdl) = (role(b, low, L::Rao)?, role(b, low, L::Rd)?);
    let id = b.a_slice("A_D read on the row axis");
    let idm = b.a_slice("A_DM read on the row axis");
    let h0 = b.h(hids.first_helper(Dom::D));
    for j in 1..n_help {
        b.h(hids.helper(Dom::D, j));
    }
    let shaped = b.shaped.clone();
    let gd = b.supp(Dom::D);
    let mut pz = if pad_on { IrPad::new(Coef::mu(6 + n_help, mu[6 + n_help]), zeta) } else { IrPad::none() };
    if pad_on {
        let planes: Vec<usize> = super::super::pad::zero_rule_a_planes(sh, ids, Dom::D).iter().map(|p| b.tab(*p)).collect();
        pz.add(gd, &planes);
    }
    let (num, num_m) = (2 * sh.norm_cn_a as i64, 2 * sh.norm_cn_m as i64);
    let (dv, den) = (1i64 << precision.norm_tn, 1i64 << (precision.norm_tn + 1));
    let (x, y, ao, x1, ym, z, x2) = (at(&idx, A_X)?, at(&idx, A_Y)?, at(&idx, A_AO)?, at(&idx, A_X1)?, at(&idx, A_YM)?, at(&idx, A_Z16)?, at(&idx, A_X2)?);
    let (n_nr, n_ns, n_mr, n_ms) = (limbs16_node(b, "nr", &nr), limbs16_node(b, "ns", &ns), limbs16_node(b, "mr", &mr), limbs16_node(b, "ms", &ms));
    let one = Coef::one;
    let neg = Coef::neg_one;
    let c0 = b.sum("c0".into(), vec![st(base(num), vec![ft(ig), ft(x)]), st(base(dv), vec![ft(id)]), st(base(-den), vec![ft(y), ft(id)]), st(neg(), vec![fnd(n_nr)])]);
    let c1 = b.sum("c1".into(), vec![st(one(), vec![fnd(n_nr)]), st(one(), vec![fnd(n_ns)]), st(one(), vec![]), st(base(-den), vec![ft(id)])]);
    let c2 = b.sum("c2: x1 - x - ao".into(), vec![st(one(), vec![ft(x1)]), st(neg(), vec![ft(x)]), st(neg(), vec![ft(ao)])]);
    let c3 = b.sum("c3".into(), vec![st(base(num_m), vec![ft(igm), ft(x1)]), st(base(dv), vec![ft(idm)]), st(base(-den), vec![ft(ym), ft(idm)]), st(neg(), vec![fnd(n_mr)])]);
    let c4 = b.sum("c4".into(), vec![st(one(), vec![fnd(n_mr)]), st(one(), vec![fnd(n_ms)]), st(one(), vec![]), st(base(-den), vec![ft(idm)])]);
    let c5 = b.sum("c5: x2 - x1 - z".into(), vec![st(one(), vec![ft(x2)]), st(neg(), vec![ft(x1)]), st(neg(), vec![ft(z)])]);
    let cl = batch(b, "the six W16 norm/residual clauses", &mu, &[c0, c1, c2, c3, c4, c5]);
    let mut zt = logup_subterms(b, Dom::D, h0, ctx.alpha, ctx.g_u8, &|k| Coef::mu(6 + k, mu[6 + k]), &shaped, "D");
    zt.extend(pz.subterms(b));
    zt.push(gated(gd, cl));
    let zc = b.sum("zc".into(), zt);
    let host_o = requant16(b, "host SC_WO", precision.ao, ao, &ral);
    let host_d = requant16(b, "host SC_DMM", precision.down, z, &rdl);
    Ok((three_terms([i_tau, i_pa, i_pz], gd, zc, &nu, host_o, host_d), pad_on))
}

fn fzc_w16(b: &mut IrB, ctx: &Ctx, data: &crate::private_block::accuracy_public::AccuracyPublic, pts: &IrPoints, tr: &mut Transcript) -> Result<(Vec<SlotTerm>, bool), String> {
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let low = ids.accuracy()?;
    let precision = sh.accuracy_precision()?;
    let pad_on = !super::super::pad::zero_rule_a_planes(sh, ids, Dom::F).is_empty();
    let n_help = sh.helpers(Dom::F);
    let mu = tr.challenge_fp2_vec(2 + n_help + usize::from(pad_on));
    let nu = nonzero(tr.challenge_fp2_vec(2))?;
    let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
    let tau_len = tr.challenge_fp2_vec(sh.log(Dom::F)).len();
    let i_tau = b.eq(tau_len, 0, "tau");
    let i_pg = b.eq(pts.p_g, 0, "p_g");
    let i_pu = b.eq(pts.p_u, 0, "p_u");
    let range = ids.domain_range(Dom::F)?;
    let idx = b.a_range(range.start, range.end - 1);
    let (rg, ru, rh) = (role(b, low, L::Rg)?, role(b, low, L::Ru)?, role(b, low, L::Rh)?);
    let h0 = b.h(hids.first_helper(Dom::F));
    for j in 1..n_help {
        b.h(hids.helper(Dom::F, j));
    }
    let fact = b.h(hids.fact());
    let shaped = b.shaped.clone();
    let group = b.public_shape("the activation group column (public accuracy data)");
    let gf = b.supp(Dom::F);
    let mut pz = if pad_on { IrPad::new(Coef::mu(2 + n_help, mu[2 + n_help]), zeta) } else { IrPad::none() };
    if pad_on {
        let planes: Vec<usize> = super::super::pad::zero_rule_a_planes(sh, ids, Dom::F).iter().map(|p| b.tab(*p)).collect();
        pz.add(gf, &planes);
    }
    let (r, gate) = (data.folds().product.shift, sh.accuracy_gate_shift);
    let (alpha, beta, tag) = (ctx.alpha, ctx.beta, ctx.g_act);
    let beta2 = beta.mul(beta);
    let (g, a, u, h) = (at(&idx, A_G8)?, at(&idx, A_A16)?, at(&idx, A_U16)?, at(&idx, A_H16)?);
    let n_rh = limbs16_node(b, "rh", &rh);
    let f0 = b.sum(
        "f0: a u - 2^r h - rh + 2^(r-1)".into(),
        vec![st(Coef::one(), vec![ft(a), ft(u)]), st(base(-(1i64 << r)), vec![ft(h)]), st(Coef::neg_one(), vec![fnd(n_rh)]), st(base(1i64 << (r - 1)), vec![])],
    );
    let amq = b.affine(
        "alpha - query".into(),
        Coef::chal(alpha.sub(Fp2::from_i64(2048)).sub(tag), "alpha - 2048 - g_act"),
        vec![(Coef::neg_one(), g), (Coef::chal(beta.neg(), "-beta"), a), (Coef::chal(beta2.neg(), "-beta^2"), group)],
    );
    let fa = b.sum("fa: fact (alpha - query) - 1".into(), vec![st(Coef::one(), vec![ft(fact), fnd(amq)]), st(Coef::neg_one(), vec![])]);
    let ar = batch(b, "the W16 product clause", &mu, &[f0]);
    let mut zt = logup_subterms(b, Dom::F, h0, alpha, ctx.g_u8, &|k| Coef::mu(2 + k, mu[2 + k]), &shaped, "F");
    zt.push(st(Coef::mu(1, mu[1]), vec![fnd(fa)]));
    zt.extend(pz.subterms(b));
    zt.push(gated(gf, ar));
    let zc = b.sum("zc".into(), zt);
    let host_g = requant16(b, "host SC_GMM", gate, g, &rg);
    let host_u = requant16(b, "host SC_UMM", precision.up, u, &ru);
    Ok((three_terms([i_tau, i_pg, i_pu], gf, zc, &nu, host_g, host_u), pad_on))
}

fn qzc_w16(slot: usize, b: &mut IrB, ctx: &Ctx, pts: &IrPoints, tr: &mut Transcript) -> Result<(Vec<SlotTerm>, bool), String> {
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let low = ids.accuracy()?;
    let precision = sh.accuracy_precision()?;
    let q = slot == SC_QZC;
    let dom = if q { Dom::Q } else { Dom::Kv };
    let log = sh.log(dom);
    let pad_on = !super::super::pad::zero_rule_a_planes(sh, ids, dom).is_empty();
    let n_help = sh.helpers(dom);
    let mu = tr.challenge_fp2_vec(1 + n_help + usize::from(pad_on));
    let nu = nonzero(tr.challenge_fp2_vec(2))?;
    let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
    let tau_len = tr.challenge_fp2_vec(log).len();
    let i_tau = b.eq(tau_len, 0, "tau");
    let i_p1 = b.eq(if q { pts.pq } else { pts.pk }, 0, if q { "pq" } else { "pk" });
    let i_p2 = b.eq(if q { pts.p_o } else { pts.pv }, 0, if q { "p_o" } else { "pv" });
    let ic = b.public_shape("the RoPE cos table");
    let is = b.public_shape("the RoPE sin table");
    let range = ids.domain_range(dom)?;
    let idx = b.a_range(range.start, range.end - 1);
    let (source, rotated, rr, other, rsource, rother, s1, s2) = if q {
        (A_Q8, A_QR8, L::Rqr, A_O8, L::Rq, L::Ro, precision.q, precision.pv)
    } else {
        (A_K8, A_KR8, L::Rkr, A_V8, L::Rk, L::Rv, precision.k, precision.v)
    };
    let (r1, r2, rotrem) = (role(b, low, rsource)?, role(b, low, rother)?, role(b, low, rr)?);
    let flip = b.a_fixed(ids.at(source), 0, "the RoPE partner half (Coord::Flip at log - log2(head_dim))");
    let h0 = b.h(hids.first_helper(dom));
    for j in 1..n_help {
        b.h(hids.helper(dom, j));
    }
    let shaped = b.shaped.clone();
    let gate = b.supp(dom);
    let mut pz = if pad_on { IrPad::new(Coef::mu(1 + n_help, mu[1 + n_help]), zeta) } else { IrPad::none() };
    if pad_on {
        let planes: Vec<usize> = super::super::pad::zero_rule_a_planes(sh, ids, dom).iter().map(|p| b.tab(*p)).collect();
        pz.add(gate, &planes);
    }
    let (src, rot, oth) = (at(&idx, source)?, at(&idx, rotated)?, at(&idx, other)?);
    let n_rr = limbs16_node(b, "the rotation remainder", &rotrem);
    let rope = b.sum(
        "rope: cos src + sin flip - 2^SH_ROPE rot - rem + 2^(SH_ROPE-1)".into(),
        vec![
            st(Coef::one(), vec![ft(ic), ft(src)]),
            st(Coef::one(), vec![ft(is), ft(flip)]),
            st(base(-(1i64 << SH_ROPE)), vec![ft(rot)]),
            st(Coef::neg_one(), vec![fnd(n_rr)]),
            st(base(1i64 << (SH_ROPE - 1)), vec![]),
        ],
    );
    let ar = batch(b, "the W16 rope clause", &mu, &[rope]);
    let mut zt = logup_subterms(b, dom, h0, ctx.alpha, ctx.g_u8, &|k| Coef::mu(1 + k, mu[1 + k]), &shaped, "QKV");
    zt.extend(pz.subterms(b));
    zt.push(gated(gate, ar));
    let zc = b.sum("zc".into(), zt);
    let host1 = requant16(b, "host 1", s1, src, &r1);
    let host2 = requant16(b, "host 2", s2, oth, &r2);
    Ok((three_terms([i_tau, i_p1, i_p2], gate, zc, &nu, host1, host2), pad_on))
}

fn szc_w16(b: &mut IrB, ctx: &Ctx, pts: &IrPoints, tr: &mut Transcript) -> Result<(Vec<SlotTerm>, bool), String> {
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let low = ids.accuracy()?;
    let precision = sh.accuracy_precision()?;
    let (alpha, beta, g_exp) = (ctx.alpha, ctx.beta, ctx.g_exp);
    let pad_on = ALL_DOMS
        .into_iter()
        .any(|d| super::super::pad::pad_zero_host(d) == SC_SZC && !super::super::pad::zero_rule_a_planes(sh, ids, d).is_empty());
    let n_pad = usize::from(pad_on);
    let tau_len = tr.challenge_fp2_vec(sh.log(Dom::S)).len();
    let n_help = sh.helpers(Dom::S);
    let mu = tr.challenge_fp2_vec(4 + n_help + 1 + n_pad);
    let nu = nonzero(tr.challenge_fp2_vec(2))?;
    let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
    let lam = pts.lam_z;
    let i_tau = b.eq(tau_len, 0, "tau");
    let i_pht = b.eq(pts.p_ht, 0, "p_ht");
    let i_ps = b.eq(pts.p_s, 0, "p_s");
    let im = b.public_shape("the causal mask");
    let range = ids.domain_range(Dom::S)?;
    let idx = b.a_range(range.start, range.end - 1);
    let (i_sr, i_sg) = (role(b, low, L::Sr)?, role(b, low, L::Sg)?);
    let imx = b.a_slice("A_MX on Dom::Ht");
    let isum = b.a_slice("A_SUM on Dom::Ht");
    let h0 = b.h(hids.first_helper(Dom::S));
    for j in 1..n_help {
        b.h(hids.helper(Dom::S, j));
    }
    let ihx = b.h(hids.sexp());
    let shaped = b.shaped.clone();
    let rsl = role(b, low, L::Rs)?;
    let b_fp = 1i64 << sh.f_p();
    let b_shs = 1i64 << precision.score;
    let s_half = super::super::witness::half(precision.score);
    let ght = b.supp(Dom::Ht);
    let gs = b.supp(Dom::S);
    let mut pz = if pad_on { IrPad::new(Coef::mu(4 + n_help + 1, mu[4 + n_help + 1]), zeta) } else { IrPad::none() };
    if pad_on {
        if super::super::pad::zero_rule_a_planes(sh, ids, Dom::Ht) != vec![ids.at(A_MX), ids.at(A_SUM)] {
            return Err("W16 IR: a Dom::Ht plane is outside SC_SZC's pad-zero group".into());
        }
        pz.add(ght, &[usize::from(imx), usize::from(isum)]);
        let planes: Vec<usize> = super::super::pad::zero_rule_a_planes(sh, ids, Dom::S).iter().map(|p| b.tab(*p)).collect();
        pz.add(gs, &planes);
    }
    let (s8, zsel, e, p) = (at(&idx, A_S8)?, at(&idx, A_ZSEL)?, at(&idx, A_E)?, at(&idx, A_P)?);
    let ms = -MASK_SCORE;
    let delta = b.sum(
        "delta".into(),
        vec![st(Coef::one(), vec![ft(imx)]), st(Coef::neg_one(), vec![ft(im), ft(s8)]), st(base(-ms), vec![ft(im)]), st(base(ms), vec![])],
    );
    let n_sr = limbs16_node(b, "sr", &i_sr);
    let n_sg = limbs16_node(b, "sg", &i_sg);
    let c0 = b.sum("c0: zsel^2 - zsel".into(), vec![st(Coef::one(), vec![ft(zsel), ft(zsel)]), st(Coef::neg_one(), vec![ft(zsel)])]);
    let c1 = b.sum("c1: zsel delta".into(), vec![st(Coef::one(), vec![ft(zsel), fnd(delta)])]);
    let c2 = b.sum(
        "c2: 2^f_p mask e - p sum - sr".into(),
        vec![st(base(b_fp), vec![ft(im), ft(e)]), st(Coef::neg_one(), vec![ft(p), ft(isum)]), st(Coef::neg_one(), vec![fnd(n_sr)])],
    );
    let c3 = b.sum(
        "c3: sg + sr + 1 - sum".into(),
        vec![st(Coef::one(), vec![fnd(n_sg)]), st(Coef::one(), vec![fnd(n_sr)]), st(Coef::one(), vec![]), st(Coef::neg_one(), vec![ft(isum)])],
    );
    let amd = b.sum(
        "alpha - delta - beta e - g_exp".into(),
        vec![st(Coef::chal(alpha.sub(g_exp), "alpha - g_exp"), vec![]), st(Coef::neg_one(), vec![fnd(delta)]), st(Coef::chal(beta.neg(), "-beta"), vec![ft(e)])],
    );
    let cx = b.sum("cx".into(), vec![st(Coef::one(), vec![ft(ihx), fnd(amd)]), st(Coef::neg_one(), vec![])]);
    let cl = batch(b, "the four W16 softmax clauses", &mu, &[c0, c1, c2, c3]);
    let mut zt = logup_subterms(b, Dom::S, h0, alpha, ctx.g_u8, &|k| Coef::mu(4 + k, mu[4 + k]), &shaped, "S");
    zt.push(st(Coef::mu(4 + n_help, mu[4 + n_help]), vec![fnd(cx)]));
    zt.extend(pz.subterms(b));
    zt.push(gated(gs, cl));
    let zc = b.sum("zc".into(), zt);
    let rs = b.sum("sum + lam_z".into(), vec![st(Coef::one(), vec![ft(isum)]), st(Coef::chal(lam, "lam_z"), vec![])]);
    let n_rsl = limbs16_node(b, "rsl", &rsl);
    let host_s = b.sum(
        "host SC_SCORE: 2^score s8 + rsl - half".into(),
        vec![st(base(b_shs), vec![ft(s8)]), st(Coef::one(), vec![fnd(n_rsl)]), st(base(-s_half), vec![])],
    );
    let gh: Vec<TableId> = ght.into_iter().collect();
    let gsv: Vec<TableId> = gs.into_iter().collect();
    let terms = vec![
        SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "eq(tau) * zc".to_string() },
        SlotTerm { coef: Coef::nu(0, nu[0]), wrapper: [vec![i_pht], gh].concat(), inner: vec![fnd(rs)], note: "host SC_RS".to_string() },
        SlotTerm { coef: Coef::nu(1, nu[1]), wrapper: [vec![i_ps], gsv].concat(), inner: vec![fnd(host_s)], note: "host SC_SCORE".to_string() },
    ];
    Ok((terms, pad_on))
}

/// `argument_accuracy::tab_w16`: the three tables' and every range
/// sub-plane's `h (alpha - t) - m`, and the pad groups (bytes, activation,
/// then each narrow range family) in the relation's own order. W16's table
/// slot carries five times R13's tables (0.18 s of a 0.76 s block on the CPU),
/// which is why it has a device path where R13's has none.
fn tab_w16(b: &mut IrB, ctx: &Ctx, tr: &mut Transcript) -> Result<(Vec<SlotTerm>, bool), String> {
    use crate::private_block::range16;
    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let rp = ids.accuracy()?.range_planes();
    let rh: Vec<usize> = hids.range_helpers().collect();
    if rp.len() != rh.len() {
        return Err("W16 IR: the range sub-planes and their table helpers differ in number".into());
    }
    let pad_on = !super::super::pad::zero_rule_a_planes(sh, ids, Dom::Tab).is_empty();
    let tau_len = tr.challenge_fp2_vec(sh.log(Dom::Tab)).len();
    let mu = tr.challenge_fp2_vec(3 + rp.len() + usize::from(pad_on));
    let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
    let th = hids.table_helpers();
    let i_tau = b.eq(tau_len, 0, "tau");
    let mut triples: Vec<(TableId, TableId, TableId)> = Vec::with_capacity(3 + rp.len());
    triples.push((b.a(ids.at(A_MU8)), b.h(th[0]), b.public_chal("the U8 tag g_u8", "the U8 table's value column")));
    triples.push((b.a(ids.at(A_MEXP)), b.h(th[1]), b.public_chal("beta and the exp tag g_exp", "the exp table's value column")));
    triples.push((b.a(ids.at(A_MACT)), b.h(th[2]), b.public_chal("beta and the activation tag g_act", "the activation table's value column")));
    for (j, (_, _, plane)) in rp.iter().enumerate() {
        triples.push((b.a(*plane), b.h(rh[j]), b.public_chal("a W16 range family's tag", "a W16 range sub-plane's value column")));
    }
    let mut pz = if pad_on { IrPad::new(Coef::mu(3 + rp.len(), mu[3 + rp.len()]), zeta) } else { IrPad::none() };
    if pad_on {
        let narrow: Vec<usize> = (0..rp.len()).filter(|&j| !range16::full(rp[j].0, sh.log_cols)).collect();
        let a_decl: Vec<usize> = [ids.at(A_MU8), ids.at(A_MEXP), ids.at(A_MACT)].into_iter().chain(narrow.iter().map(|&j| rp[j].2)).collect();
        let h_decl: Vec<usize> = th.into_iter().chain(narrow.iter().map(|&j| rh[j])).collect();
        super::super::argument::tab_group_is_declared(sh, ids, &a_decl, &h_decl)?;
        let bytes = b.supp(Dom::Tab);
        let activation = Some(b.public_shape("the activation table's support column"));
        let t = |k: usize| -> [usize; 2] { [usize::from(triples[k].0), usize::from(triples[k].1)] };
        pz.add(bytes, &[t(0)[0], t(1)[0]]);
        pz.add(bytes, &[t(0)[1], t(1)[1]]);
        pz.add(activation, &[t(2)[0]]);
        pz.add(activation, &[t(2)[1]]);
        for &j in &narrow {
            let support = Some(b.public_shape("a narrow W16 range family's support column"));
            pz.add(support, &[t(3 + j)[0]]);
            pz.add(support, &[t(3 + j)[1]]);
        }
    }
    let mut zc_terms: Vec<SubTerm> = Vec::new();
    for (k, &(m, h, tv)) in triples.iter().enumerate() {
        let den = b.affine(format!("alpha - values[{k}]"), Coef::chal(ctx.alpha, "alpha"), vec![(Coef::neg_one(), tv)]);
        let rel = b.sum(format!("r{k}: h (alpha - values) - m"), vec![st(Coef::one(), vec![ft(h), fnd(den)]), st(Coef::neg_one(), vec![ft(m)])]);
        zc_terms.push(st(Coef::mu(k, mu[k]), vec![fnd(rel)]));
    }
    zc_terms.extend(pz.subterms(b));
    let zc = b.sum("zc".into(), zc_terms);
    Ok((vec![SlotTerm { coef: Coef::one(), wrapper: vec![i_tau], inner: vec![fnd(zc)], note: "the W16 table helpers' relations".to_string() }], pad_on))
}

#[cfg(test)]
mod tests {
    //! THE ACCURACY-STACK ORACLE. The runtime guard checks one profile's IR
    //! against its closure at eight points before the device may run it; this
    //! test checks every development accuracy shape (both stacks, DD and not),
    //! every activation-group count and every slot, offline, so a drift in the
    //! transcription is a test failure and not only a silent CPU fallback.
    use super::super::{build_slot_ir, IrPoints};
    use crate::field::{Fp, Fp2};
    use crate::private_block::accuracy_groups::Group;
    use crate::private_block::accuracy_public::{AccuracyPublic, Geometry, Multipliers};
    use crate::private_block::accuracy_tables::silu_table;
    use crate::private_block::argument::{define, Ctx, Points};
    use crate::private_block::layout::*;
    use crate::private_block::shape::Shape;
    use crate::private_block::{AttentionPublic, FeedForwardPublic};
    use crate::transcript::Transcript;

    fn k(v: i64) -> Fp2 {
        Fp2::from_i64(v)
    }

    /// `argument_accuracy::tests::case`, verbatim in substance
    fn case(mut sh: Shape, ng: usize) -> (Shape, AccuracyPublic, AttentionPublic, FeedForwardPublic) {
        let geometry = Geometry { width: sh.width, query_width: sh.q_width(), kv_width: sh.kv_heads * sh.head_dim, hidden: sh.hidden };
        let sequence = |n, max| (0..n).map(|i| 1 + (i % max) as u16).collect();
        let m = Multipliers {
            q: sequence(geometry.query_width, 32),
            k: sequence(geometry.kv_width, 32),
            v: sequence(geometry.kv_width, 64),
            o: sequence(geometry.width, 256),
            g: sequence(geometry.hidden, 64),
            u: sequence(geometry.hidden, 16),
            d: sequence(geometry.width, 64),
        };
        let groups = vec![Group { e_in: -4, e_out: -13 }, Group { e_in: -3, e_out: -12 }, Group { e_in: -2, e_out: -11 }, Group { e_in: -1, e_out: -9 }][..ng].to_vec();
        let tables = groups.iter().map(|g| silu_table(g.e_in, g.e_out, 12).unwrap()).collect();
        // the profile's own table registry (Shieldstral pins its geometry and members)
        let data = AccuracyPublic::new_with_registry(sh.accuracy_registry(), sh.accuracy_stack(), geometry, sh.accuracy_base(), (-3, -11), m, groups, (0..geometry.hidden).map(|i| i % ng).collect(), tables).unwrap();
        sh = sh.with_accuracy_gate_shift(data.folds().gate.shift).unwrap();
        let (mut public, ff, _) = crate::private_block::grow_tests::tame_case(&sh);
        if sh.dd_cap > 0 {
            public.exp = crate::tables_attn::exp_member(4, sh.head_dim, sh.f_e).0.to_vec();
            public.dd_e_column(sh.dd_cap).expect("the DD fixture retains the fixed dictionary cap");
        }
        (sh, data, public, ff)
    }

    #[test]
    fn the_accuracy_ir_evaluates_to_the_r13_closure_at_every_development_shape_group_count_and_slot() {
        let shapes: Vec<Shape> = crate::private_block::accuracy_profile_tests::registered_shapes().into_iter().filter(|s| s.tokens == 32).collect();
        assert!(!shapes.is_empty());
        let mut z = 0x2545_F491_4F6C_DD1Du64;
        let mut next = move || {
            z ^= z << 13;
            z ^= z >> 7;
            z ^= z << 17;
            Fp::new(z)
        };
        let (mut transcribed, mut dd_szc, mut legacy_matched) = (0usize, 0usize, 0usize);
        for sh0 in shapes {
            for ng in 1..=4 {
                let (sh, data, public, ff) = case(sh0.clone(), ng);
                let lay = Layout::for_shape(&sh).unwrap();
                let ctx = Ctx { accuracy: Some(&data), lay: &lay, public: &public, ff: &ff, alpha: k(7).add(Fp2::U), beta: k(11), g_u8: k(13), g_exp: k(17), g_act: k(19), g_dd: k(23) };
                let (mut pts, mut ipts) = (Points::default(), IrPoints::default());
                let mut tr = Transcript::new(sh.profile.as_bytes());
                for slot in 0..sh.n_slots() {
                    let mut twin = Transcript::clone_state(&tr);
                    let ir = build_slot_ir(slot, &ctx, &mut ipts, &mut twin);
                    let def = define(slot, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{} ng{ng} slot{slot}: {e}", sh.name));
                    let redefined = [SC_DZC, SC_FZC, SC_QZC, SC_KVZC, SC_SZC].contains(&slot) && !(slot == SC_SZC && sh.dd_cap > 0);
                    match ir {
                        Ok(ir) => {
                            let at = format!("{} ng{ng} slot{slot}", sh.name);
                            assert_eq!(ir.tables.len(), def.tabs.len(), "{at}: table count");
                            for _ in 0..12 {
                                let v: Vec<Fp2> = (0..ir.tables.len()).map(|_| Fp2::new(next(), next())).collect();
                                assert_eq!(ir.eval(&v), (def.poly)(&v), "{at}: the IR differs from the closure");
                            }
                            assert!(ir.max_term_degree() <= sh.slots()[slot].2, "{at}: the IR exceeds the declared degree");
                            // a transcribed arm draws exactly what `define` drew (some
                            // legacy matmul arms stop after the challenges their
                            // polynomial uses, which the equality above covers)
                            if redefined {
                                let mut real = Transcript::clone_state(&tr);
                                assert_eq!(twin.challenge_fp2(), real.challenge_fp2(), "{at}: the IR drew a different challenge count");
                            }
                            if redefined {
                                transcribed += 1;
                            } else {
                                legacy_matched += 1;
                            }
                        }
                        Err(e) => {
                            assert!(!redefined, "{} ng{ng} slot{slot}: a transcribed slot has no IR: {e}", sh.name);
                            if slot == SC_SZC {
                                dd_szc += 1;
                            }
                        }
                    }
                }
            }
        }
        assert!(transcribed > 0 && legacy_matched > 0);
        eprintln!("accuracy IR oracle: {transcribed} transcribed slot IRs and {legacy_matched} legacy slot IRs match; {dd_szc} DD softmax slots stay on the CPU");
    }

    /// [M4c] the direct parallel helper write stores exactly the words the
    /// reference pair / single helper plus `write_h` stored, in both row
    /// orders, below and above the parallel threshold, and refuses a zero
    /// denominator with the same string
    #[test]
    fn m4c_direct_helper_write_equals_the_reference_columns() {
        use crate::private_block::protocol::{helper_inverses_u8, helper_pair_inverses_u8, u8_denominator_inverses, write_helper_u8, HELPER_PAR_MIN};
        let (alpha, g_u8) = (k(1_000_003).add(Fp2::U.mul(k(17))), k(29));
        let tbl = u8_denominator_inverses(alpha, g_u8);
        for len in [5usize, HELPER_PAR_MIN - 1, HELPER_PAR_MIN + 77] {
            let a: Vec<i64> = (0..len).map(|i| ((i * 131 + 7) % 300) as i64 - 20).collect();
            let b: Vec<i64> = (0..len).map(|i| ((i * 37 + 3) % 256) as i64).collect();
            for (o0, o1) in [(3usize, 3 + len + 11), (5 + len, 2)] {
                for pair in [true, false] {
                    let want = if pair { helper_pair_inverses_u8(&a, &b, alpha, g_u8, &tbl).unwrap() } else { helper_inverses_u8(&a, alpha, g_u8, &tbl).unwrap() };
                    let mut h_want = vec![Fp::new(9); 2 * len + 40];
                    for (i, v) in want.iter().enumerate() {
                        h_want[o0 + i] = v.c0;
                        h_want[o1 + i] = v.c1;
                    }
                    let mut h_got = vec![Fp::new(9); 2 * len + 40];
                    write_helper_u8(&mut h_got, (o0, o1), &a, pair.then_some(b.as_slice()), alpha, g_u8, &tbl).unwrap();
                    assert_eq!(h_got, h_want, "len {len} offsets ({o0}, {o1}) pair {pair}");
                }
            }
        }
        // a zero denominator: alpha chosen so value 300 hits it (outside the byte table)
        let alpha0 = k(300).add(g_u8);
        let tbl0 = u8_denominator_inverses(alpha0, g_u8);
        let bad: Vec<i64> = (0..HELPER_PAR_MIN + 5).map(|i| if i == 4321 { 300 } else { (i % 256) as i64 }).collect();
        let mut h = vec![Fp::ZERO; 2 * bad.len() + 8];
        let got = write_helper_u8(&mut h, (0, bad.len() + 1), &bad, None, alpha0, g_u8, &tbl0);
        assert_eq!(got, helper_inverses_u8(&bad, alpha0, g_u8, &tbl0).map(|_| ()));
        assert!(got.is_err());
    }

    /// [M4d] the one-region writer equals the job-by-job loop: the same `H`
    /// words (over a background that catches a stray write) and the same
    /// result, on the fast path (unaligned disjoint offsets, columns of one to
    /// several chunks, pairs and singles), at a zero denominator, and on the
    /// fallback (a malformed job behind a zero denominator; overlapping jobs).
    /// After a refusal only the refusal is compared: `H` is discarded then.
    #[test]
    fn m4d_batched_helper_write_equals_the_job_by_job_loop() {
        use crate::private_block::protocol::{u8_denominator_inverses, write_helper_u8, write_helpers_u8, HelperJob};
        let (alpha, g_u8) = (k(1_000_003).add(Fp2::U.mul(k(17))), k(29));
        let col = |len: usize, m: usize, c: usize| -> Vec<i64> { (0..len).map(|i| ((i * m + c) % 290) as i64 - 17).collect() };
        let lens = [5usize, 16_384, 40_000, 70_001, 3];
        let cols: Vec<(Vec<i64>, Vec<i64>)> = lens.iter().enumerate().map(|(i, &l)| (col(l, 131 + 2 * i, 7 + i), col(l, 37 + 2 * i, 3 + i))).collect();
        // disjoint, unaligned: job i's real row, a gap, its imaginary row, a gap
        let mut offs = Vec::new();
        let mut at = 11usize;
        for &l in &lens {
            offs.push((at + l + 5, at));
            at += 2 * l + 13;
        }
        let size = at + 9;
        let run = |jobs: &[HelperJob<'_>], al: Fp2, batched: bool| -> (Result<(), String>, Vec<Fp>) {
            let tbl = u8_denominator_inverses(al, g_u8);
            let mut h = vec![Fp::new(9); size];
            let r = if batched {
                write_helpers_u8(&mut h, jobs, al, g_u8, &tbl)
            } else {
                jobs.iter().try_for_each(|j| write_helper_u8(&mut h, j.off, j.a, j.b, al, g_u8, &tbl))
            };
            (r, h)
        };
        let jobs: Vec<HelperJob<'_>> = cols.iter().zip(&offs).enumerate().map(|(i, ((a, b), &off))| HelperJob { off, a, b: (i % 2 == 0).then_some(b.as_slice()) }).collect();
        let (want, got) = (run(&jobs, alpha, false), run(&jobs, alpha, true));
        assert!(want.0.is_ok() && got == want, "the fast path");
        // a zero denominator in job 3 (value 300 is outside the byte table)
        let alpha0 = k(300).add(g_u8);
        let mut hit = cols[3].0.clone();
        hit[50_000] = 300;
        let mut jobs0: Vec<HelperJob<'_>> = cols.iter().zip(&offs).map(|((a, b), &off)| HelperJob { off, a, b: Some(b) }).collect();
        jobs0[3].a = &hit;
        let (w0, g0) = (run(&jobs0, alpha0, false), run(&jobs0, alpha0, true));
        assert!(w0.0.is_err() && g0.0 == w0.0, "a zero denominator");
        // a malformed job 4 behind job 3's zero denominator: the loop's refusal
        let short = cols[4].1[..2].to_vec();
        jobs0[4].b = Some(&short);
        let (w1, g1) = (run(&jobs0, alpha0, false), run(&jobs0, alpha0, true));
        // (after a refusal `H` is discarded, and the parallel loop stops at no
        // fixed word, so only the refusal itself is compared)
        assert!(w1.0.is_err() && g1.0 == w1.0, "the fallback's first refusal");
        // jobs 1 and 2 overlap: the loop, word for word
        let mut jobs2: Vec<HelperJob<'_>> = cols.iter().zip(&offs).map(|((a, b), &off)| HelperJob { off, a, b: Some(b) }).collect();
        jobs2[2].off.1 = offs[1].1 + 7;
        jobs2[2].off.0 = offs[1].1 + 7 + lens[2] + 1;
        let (w2, g2) = (run(&jobs2, alpha, false), run(&jobs2, alpha, true));
        assert!(w2.0.is_ok() && g2 == w2, "overlapping jobs");
    }

    /// [ZK60-METAL M4h] the chunked parallel batch inversion returns the
    /// single-region inverses word for word, refuses a zero with the same
    /// string, and the parallel `write_h` writes what the loop writes, with the
    /// real row before or after the imaginary one
    #[test]
    fn m4h_parallel_inverses_and_h_writes_equal_the_sequential_forms() {
        use crate::private_block::protocol::{inverses, write_h, INV_CHUNK, WRITE_H_PAR_MIN};
        // long enough for both parallel forms (two inversion chunks, and the
        // write_h column below)
        let len = WRITE_H_PAR_MIN + INV_CHUNK + 5;
        let den: Vec<Fp2> = (0..len).map(|i| k(i as i64 * 7919 + 3).add(Fp2::U.mul(k((i % 977) as i64 + 1)))).collect();
        let mut want = den.clone();
        crate::field::batch_inverse2_checked(&mut want).unwrap();
        let got = inverses(den.clone()).unwrap();
        assert_eq!(got, want, "the inverses");
        assert!(got.iter().zip(&den).all(|(x, d)| x.mul(*d) == Fp2::ONE));
        let mut zero = den.clone();
        zero[2 * INV_CHUNK + 11] = Fp2::ZERO;
        assert_eq!(inverses(zero).unwrap_err(), "zero LogUp denominator; discard attempt");
        // short columns keep the single region (and its string)
        let mut short = den[..100].to_vec();
        short[40] = Fp2::ZERO;
        assert_eq!(inverses(short).unwrap_err(), "zero LogUp denominator; discard attempt");
        let col = &want[..WRITE_H_PAR_MIN + 77];
        let n = col.len();
        for off in [(13usize, 13 + n + 4), (2 * n + 9, 5)] {
            let size = off.0.max(off.1) + n + 3;
            let mut a = vec![Fp::new(5); size];
            write_h(&mut a, off, col);
            let mut b = vec![Fp::new(5); size];
            for (i, v) in col.iter().enumerate() {
                b[off.0 + i] = v.c0;
                b[off.1 + i] = v.c1;
            }
            assert_eq!(a, b, "write_h at {off:?}");
        }
    }

    /// [M4i/M4j] an extension element of the table fixtures
    fn m4_f(i: u64) -> Fp2 {
        Fp2::new(Fp::new(i * 1_000_003 + 7), Fp::new(i * 31 + 1))
    }

    /// [M4i/M4j] base data and private-table descriptors at `2^n_vars`: plain
    /// store, flipped, fixed (accumulating), short with broadcast, duplicated
    /// index (accumulating) and two slices; and a shuffled-order plain one
    fn m4_priv_cases(n_vars: usize) -> (Vec<Fp>, Vec<(&'static str, crate::private_block::argument::Priv)>) {
        use crate::private_block::argument::{Cm, Coord, Priv};
        let f = m4_f;
        let data: Vec<Fp> = (0..(4usize << n_vars)).map(|i| Fp::new((i as u64).wrapping_mul(0x9E37_79B9) % 1_000_000_007)).collect();
        let rho = |c: Vec<usize>| -> Vec<Coord> { c.into_iter().map(Coord::Rho).collect() };
        let mk = |slices: Vec<(usize, Fp2)>, log: usize, coords: Vec<Coord>| Priv { cm: Cm::A, slices, log, coords, mask_row: 0, ext_round: 0 };
        let mut cases: Vec<(&'static str, Priv)> = Vec::new();
        cases.push(("plain", mk(vec![(3, Fp2::ONE)], n_vars, rho((0..n_vars).rev().collect()))));
        let mut fl = rho((0..n_vars).collect());
        fl[1] = Coord::Flip(1);
        cases.push(("flipped", mk(vec![(1, f(2))], n_vars, fl)));
        let mut fx = rho((1..n_vars).collect());
        fx.insert(2, Coord::Fixed(f(3)));
        cases.push(("fixed", mk(vec![(2, Fp2::ONE)], n_vars, fx)));
        cases.push(("short, broadcast", mk(vec![(5, Fp2::ONE)], n_vars - 2, rho((0..n_vars - 2).collect()))));
        let mut dup = rho((0..n_vars).collect());
        dup[n_vars - 1] = Coord::Rho(0);
        cases.push(("duplicated index", mk(vec![(2, Fp2::ONE)], n_vars, dup)));
        cases.push(("two slices", mk(vec![(1, f(4)), (9, Fp2::U)], n_vars, rho((0..n_vars).collect()))));
        // a plain-store table whose coordinates are interleaved and partly flipped, short by one
        let mut mixed: Vec<Coord> = (0..n_vars - 1).map(|j| if j % 2 == 0 { Coord::Rho((j * 7 + 3) % (n_vars - 1) + 1) } else { Coord::Flip((j * 7 + 3) % (n_vars - 1) + 1) }).collect();
        mixed.reverse();
        cases.push(("interleaved, flipped, short", mk(vec![(7, Fp2::ONE)], n_vars - 1, mixed)));
        // [M9] accumulating tables that read EVERY cube variable once (the
        // parallel accumulating form): a fixed coordinate high in the index,
        // and one at the bottom with a flip and two slices
        let mut fa = rho((0..n_vars).rev().collect());
        fa.insert(1, Coord::Fixed(f(5)));
        cases.push(("fixed, every variable", mk(vec![(4, f(6))], n_vars + 1, fa)));
        let mut fb = rho((0..n_vars).collect());
        fb[n_vars / 2] = Coord::Flip(n_vars / 2);
        fb.push(Coord::Fixed(f(7)));
        cases.push(("fixed low, flipped, two slices, every variable", mk(vec![(1, f(2)), (6, Fp2::U)], n_vars + 1, fb)));
        (data, cases)
    }

    /// **[M6] the device Fiat-Shamir round step is the transcript's, byte for
    /// byte**: `absorb_fp2(b"sc-round", ..)` then `challenge_fp2()`, plain and
    /// keyed (a tagged profile), round degrees 1 to 7, squeeze counters 0 to 9.
    #[cfg(feature = "gpu-metal")]
    #[test]
    fn m6_device_fiat_shamir_step_equals_the_transcript() {
        use crate::transcript::Transcript;
        let key = *blake3::hash(b"zk60 m6 key").as_bytes();
        for keyed in [false, true] {
            for (deg, before) in [(1usize, 0usize), (2, 3), (3, 0), (3, 5), (4, 1), (7, 9)] {
                let mut tr = if keyed { Transcript::new_tagged(b"m6 fs", key) } else { Transcript::new(b"m6 fs") };
                tr.absorb(b"seed", &[deg as u8, before as u8, keyed as u8]);
                for _ in 0..before {
                    tr.challenge_fp2();
                }
                let state = tr.state();
                let vals: Vec<Fp2> = (0..=deg).map(|i| m4_f(97 * i as u64 + 13 * deg as u64 + before as u64 + 1)).collect();
                let (st, r) = crate::gpu::metal_fs_round_for_test(state, keyed.then_some(key), before as u64, &vals).expect("a Metal device");
                tr.absorb_fp2(b"sc-round", &vals);
                let want = tr.challenge_fp2();
                assert_eq!(r, want, "keyed {keyed} degree {deg} counter {before}: the device challenge");
                assert_eq!(st, tr.state(), "keyed {keyed} degree {deg} counter {before}: the device state");
            }
        }
    }

    /// **[M6, probe, ignored]** the fixed cost of a device round: one command
    /// buffer per round against one for all of them, with and without a fold.
    /// Prints only; run with `--ignored --nocapture`.
    #[cfg(feature = "gpu-metal")]
    #[test]
    #[ignore]
    fn m6_probe_dispatch_overhead() {
        for (n, fh) in [(190usize, 1usize << 10), (190, 1 << 14), (1000, 1 << 10)] {
            for rep in 0..3 {
                let t = crate::gpu::metal_dispatch_overhead_probe(n, fh).expect("a Metal device");
                eprintln!(
                    "[M6 probe] n {n} fold_half 2^{} rep {rep}: fs only {:.3} ms/round separate, {:.3} ms/round one buffer; fs+fold {:.3} separate, {:.3} one buffer",
                    fh.trailing_zeros(),
                    t[0] * 1e3 / n as f64,
                    t[1] * 1e3 / n as f64,
                    t[2] * 1e3 / n as f64,
                    t[3] * 1e3 / n as f64
                );
            }
        }
    }

    /// **[M5c] the split eq cube is the full table's broadcast, word for
    /// word**: every point length (odd and even splits), offset and cube size,
    /// including a point that covers the whole cube and broadcast ones.
    #[test]
    fn m5c_split_eq_cube_equals_the_full_table_broadcast() {
        use crate::mle::eq_table_msb;
        use crate::private_block::argument::{eq_cube_into, eq_cube_split_into};
        for n_vars in [16usize, 17] {
            for p in [2usize, 3, 7, 11, n_vars - 1, n_vars] {
                for start in [0usize, 1, n_vars - p] {
                    if start + p > n_vars {
                        continue;
                    }
                    let point: Vec<Fp2> = (0..p).map(|i| m4_f(31 * i as u64 + 7 * p as u64 + start as u64 + 1)).collect();
                    let mut want = vec![Fp2::ZERO; 1 << n_vars];
                    eq_cube_into(&eq_table_msb(&point), n_vars, start, &mut want);
                    let mut got = vec![Fp2::ONE; 1 << n_vars];
                    eq_cube_split_into(&point, n_vars, start, &mut got);
                    assert!(got == want, "n_vars {n_vars} p {p} start {start}: the split eq cube differs");
                }
            }
        }
    }

    /// [ZK60-METAL M4j] the parallel table builders (over the OUTPUT) are the
    /// sequential ones word for word: every descriptor of `m4_priv_cases`, the
    /// vector and the in-place forms, every eq cube shape, at widths on both
    /// sides of the production threshold (forced either way by the argument)
    #[test]
    fn m4j_parallel_table_builders_equal_the_sequential_ones() {
        use crate::private_block::argument::{eq_cube_at, eq_cube_into_at, priv_table_at, priv_table_into_at};
        let junk = Fp2::new(Fp::new(55), Fp::new(66));
        for n_vars in [3usize, 8, 13, 17] {
            let (data, cases) = m4_priv_cases(n_vars);
            for (name, p) in &cases {
                let seq = priv_table_at(p, &data, n_vars, usize::MAX);
                assert_eq!(priv_table_at(p, &data, n_vars, 0), seq, "{name} at 2^{n_vars}: vector");
                let mut got = vec![junk; 1usize << n_vars];
                priv_table_into_at(p, &data, n_vars, &mut got, 0);
                assert_eq!(got, seq, "{name} at 2^{n_vars}: in place");
                assert!(seq.iter().any(|v| !v.is_zero()), "{name}: an all-zero fixture");
            }
            for plen in 0..=n_vars.min(5) {
                for start in [0, (n_vars - plen) / 2, n_vars - plen] {
                    let e = crate::mle::eq_table_msb(&(0..plen).map(|i| m4_f(i as u64 + 5)).collect::<Vec<_>>());
                    let seq = eq_cube_at(&e, n_vars, start, usize::MAX);
                    assert_eq!(eq_cube_at(&e, n_vars, start, 0), seq, "eq 2^{n_vars} start {start} |point| {plen}");
                    let mut got = vec![junk; 1usize << n_vars];
                    eq_cube_into_at(&e, n_vars, start, &mut got, 0);
                    assert_eq!(got, seq, "eq in place 2^{n_vars} start {start} |point| {plen}");
                }
            }
        }
    }

    /// [ZK60-METAL M4i] the in-place table builders write, into a buffer full
    /// of stale words, exactly the vectors the host builders return (plain
    /// store, flipped, fixed, short-with-broadcast, duplicated-index and
    /// two-slice private tables; every eq cube shape), and the parallel plane
    /// write is the loop's, with the loop kept for overlapping or short jobs
    #[test]
    fn m4i_in_place_tables_and_plane_writes_equal_the_host_forms() {
        use crate::private_block::argument::{eq_cube, eq_cube_into, priv_table, priv_table_into};
        use crate::private_block::protocol::{write_planes, PLANES_PAR_MIN};
        let junk = Fp2::new(Fp::new(123_456_789), Fp::new(987_654_321));
        let f = m4_f;
        for n_vars in [5usize, 9, 12] {
            let (data, cases) = m4_priv_cases(n_vars);
            for (name, p) in &cases {
                let want = priv_table(p, &data, n_vars);
                let mut got = vec![junk; 1usize << n_vars];
                priv_table_into(p, &data, n_vars, &mut got);
                assert_eq!(got, want, "{name} at 2^{n_vars}");
                assert!(want.iter().any(|v| !v.is_zero()), "{name}: an all-zero fixture");
            }
            for plen in 0..=n_vars.min(6) {
                for start in 0..=(n_vars - plen) {
                    let point: Vec<Fp2> = (0..plen).map(|i| f(i as u64 + 11)).collect();
                    let e = crate::mle::eq_table_msb(&point);
                    let mut got = vec![junk; 1usize << n_vars];
                    eq_cube_into(&e, n_vars, start, &mut got);
                    assert_eq!(got, eq_cube(&e, n_vars, start), "eq cube 2^{n_vars} start {start} |point| {plen}");
                }
            }
        }
        // the plane write: disjoint unaligned jobs in shuffled order, then overlapping and short ones
        let plane = |len: usize, m: i64| -> Vec<i64> { (0..len as i64).map(|i| (i * m) % 70_001 - 35_000).collect() };
        let planes = [plane(PLANES_PAR_MIN + 3, 7), plane(40_000, 13), plane(5, 3), plane(PLANES_PAR_MIN / 2, 11)];
        let offs = [200_000usize, 17, 150_007, 60_011];
        let size = 300_000usize;
        let looped = |jobs: &[(usize, &[i64])]| -> Vec<Fp> {
            let mut d = vec![Fp::new(5); size];
            for (off, p) in jobs {
                for (i, v) in p.iter().enumerate() {
                    d[off + i] = Fp::from_i64(*v);
                }
            }
            d
        };
        let jobs: Vec<(usize, &[i64])> = offs.iter().zip(planes.iter()).map(|(o, p)| (*o, p.as_slice())).collect();
        let mut got = vec![Fp::new(5); size];
        write_planes(&mut got, &jobs);
        assert_eq!(got, looped(&jobs), "disjoint jobs");
        let mut over = jobs.clone();
        over[3].0 = 20; // overlaps job 1: the loop's order decides
        let mut got = vec![Fp::new(5); size];
        write_planes(&mut got, &over);
        assert_eq!(got, looped(&over), "overlapping jobs");
        let short: Vec<(usize, &[i64])> = vec![(3, &planes[2][..]), (11, &planes[2][..])];
        let mut got = vec![Fp::new(5); size];
        write_planes(&mut got, &short);
        assert_eq!(got, looped(&short), "short jobs");
    }

    /// [M4i] nanoseconds of the last `prove_core` call `seeded_accuracy_digest` made
    #[cfg(feature = "gpu-metal")]
    static LAST_CORE_NS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

    /// one seeded accuracy-stack block proof's digest (the recipe of
    /// `r12_golden_tests::digest_of_seeded_block`: roots, slot proofs,
    /// openings, IO claims, absorb order, lookups, final transcript state)
    #[cfg(feature = "gpu-metal")]
    /// [M10] the seeded core proof of `seeded_accuracy_digest`, returning
    /// only the final transcript state (it binds every absorbed message of
    /// the proof) and the proof call's seconds: no digest text, so N threads
    /// can prove at once without a formatting pass each
    fn seeded_core_state(sh: &Shape, blk: &crate::private_block::BlockPublic, w: crate::private_block::witness::Witness) -> ([u8; 32], f64) {
        let lay = Layout::for_shape(sh).unwrap();
        let (rows, n) = (sh.endpoint_rows, 1usize << sh.endpoint_log_n);
        let ids = Ids::new(sh).unwrap();
        let io = |p: usize| -> Vec<Fp> {
            let mut d = vec![Fp::ZERO; rows * n];
            for (i, v) in w.planes[p].iter().enumerate().take(d.len()) {
                d[i] = Fp::from_i64(*v);
            }
            d
        };
        let (ein, eout) = (io(ids.at(A_X)), io(ids.at(A_X2)));
        let ntt = crate::ntt::NttTables::new(crate::private_block::protocol::ntt_log_at(sh));
        let mut rng = crate::zk::ZkRng::new(20261031, b"zk60 metal m4 accuracy");
        let mut tr = Transcript::new(b"zk60 metal m4 accuracy");
        tr.absorb(b"profile", sh.profile.as_bytes());
        tr.absorb(b"schedule", &lay.schedule_digest());
        let mut ph = crate::private_block::timing::Phases::start();
        let (mut phases, mut tick) = (Vec::new(), std::time::Instant::now());
        let t_core = std::time::Instant::now();
        crate::private_block::protocol::prove_core(sh, &lay, blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the seeded accuracy core proof");
        (tr.state(), t_core.elapsed().as_secs_f64())
    }

    /// **[ZK60-METAL M10, ignored] throughput of INDEPENDENT block proofs at
    /// once**: one process, one shared warm-up (the slot kernels compile once),
    /// then N threads each proving the same seeded block K times. Each proof's
    /// final transcript state must equal the solo proof's. Prints the wall
    /// clock and blocks/s per N. `HL_M10_PROFILE` (default W16_8B_T128_H24),
    /// `HL_M10_THREADS` (default 1,2,3,4,6), `HL_M10_PER_THREAD` (default 4).
    #[cfg(feature = "gpu-metal")]
    #[test]
    #[ignore]
    fn m10_concurrent_block_proofs_throughput() {
        let name = std::env::var("HL_M10_PROFILE").unwrap_or_else(|_| "W16_8B_T128_H24".to_string());
        let spec = crate::private_block::shape::W16_PROFILES.iter().find(|s| s.name == name).expect("a W16 profile name");
        let cal = crate::private_block::shape::NormCalibration { tn: if spec.width >= 3072 { 9 } else { 10 }, cn_a: 100, cn_m: 100, ceps: 1, sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6 };
        let original = Shape::accuracy_trained(spec.profile, &cal, if spec.tokens == 32 { 12 } else { 9 }, 20).unwrap();
        let (sh, data, public, ff) = case(original, 3);
        let blk = crate::private_block::BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
        let mut seed = 0usize;
        let w0 = loop {
            let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + seed) % (41 + 20 * (seed % 3))) as i16 - 20).collect();
            match crate::private_block::witness::build_accuracy(&sh, &public, &ff, &data, &input) {
                Ok(w) => break w,
                Err(_) if seed < 6 => seed += 1,
                Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
            }
        };
        std::env::set_var("HL_GPU", "1");
        let (want, cold) = seeded_core_state(&sh, &blk, w0.clone());
        let (_, warm) = seeded_core_state(&sh, &blk, w0.clone());
        eprintln!("M10 {name}: solo cold {cold:.3} s, warm {warm:.3} s");
        let threads: Vec<usize> = std::env::var("HL_M10_THREADS").unwrap_or_else(|_| "1,2,3,4,6".into()).split(',').filter_map(|v| v.trim().parse().ok()).collect();
        let k: usize = std::env::var("HL_M10_PER_THREAD").ok().and_then(|v| v.parse().ok()).unwrap_or(4).max(1);
        for &n in &threads {
            let t = std::time::Instant::now();
            let cores: Vec<f64> = std::thread::scope(|s| {
                let hs: Vec<_> = (0..n)
                    .map(|_| {
                        let (sh, blk, w0) = (&sh, &blk, &w0);
                        s.spawn(move || {
                            (0..k)
                                .map(|_| {
                                    let (st, secs) = seeded_core_state(sh, blk, w0.clone());
                                    assert_eq!(st, want, "a concurrent proof's transcript differs from the solo proof's");
                                    secs
                                })
                                .collect::<Vec<f64>>()
                        })
                    })
                    .collect();
                hs.into_iter().flat_map(|h| h.join().expect("a prover thread")).collect()
            });
            let wall = t.elapsed().as_secs_f64();
            let mut c = cores.clone();
            c.sort_by(|a, b| a.partial_cmp(b).unwrap());
            let blocks = (n * k) as f64;
            eprintln!(
                "M10 {name} threads {n} x {k}: wall {wall:.3} s, {:.2} blocks/s ({:.1} proved tok/s for 32 layers of T{}), per-proof core min {:.3} median {:.3} max {:.3} s",
                blocks / wall,
                blocks / wall * sh.tokens as f64 / 32.0,
                sh.tokens,
                c[0],
                c[c.len() / 2],
                c[c.len() - 1]
            );
        }
        std::env::remove_var("HL_GPU");
    }

    fn seeded_accuracy_digest(sh: &Shape, blk: &crate::private_block::BlockPublic, w: crate::private_block::witness::Witness) -> String {
        let lay = Layout::for_shape(sh).unwrap();
        let (rows, n) = (sh.endpoint_rows, 1usize << sh.endpoint_log_n);
        let ids = Ids::new(sh).unwrap();
        let io = |p: usize| -> Vec<Fp> {
            let mut d = vec![Fp::ZERO; rows * n];
            for (i, v) in w.planes[p].iter().enumerate().take(d.len()) {
                d[i] = Fp::from_i64(*v);
            }
            d
        };
        let (ein, eout) = (io(ids.at(A_X)), io(ids.at(A_X2)));
        let ntt = crate::ntt::NttTables::new(crate::private_block::protocol::ntt_log_at(sh));
        let mut rng = crate::zk::ZkRng::new(20261031, b"zk60 metal m4 accuracy");
        let mut tr = Transcript::new(b"zk60 metal m4 accuracy");
        tr.absorb(b"profile", sh.profile.as_bytes());
        tr.absorb(b"schedule", &lay.schedule_digest());
        let mut ph = crate::private_block::timing::Phases::start();
        let (mut phases, mut tick) = (Vec::new(), std::time::Instant::now());
        let t_core = std::time::Instant::now();
        let core = crate::private_block::protocol::prove_core(sh, &lay, blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the seeded accuracy core proof");
        // [M4i] the proof call alone: the test's own clock also holds the
        // NTT tables, the endpoint rows and the digest's text below
        LAST_CORE_NS.store(t_core.elapsed().as_nanos() as u64, std::sync::atomic::Ordering::Relaxed);
        // DIAGNOSTIC ONLY (HL_TABLE_KIND_TIMING=1): this proof's direct table builds by kind
        crate::private_block::argument::table_kind_report(sh.name);
        if std::env::var("HL_M4_PHASES").map(|v| v == "1").unwrap_or(false) {
            let row: Vec<String> = phases.iter().map(|(n, t)| format!("{n} {t:.3}")).collect();
            eprintln!("M4-PHASES {} gpu={} | {}", sh.name, std::env::var("HL_GPU").unwrap_or_default(), row.join(" | "));
            ph.report(if std::env::var("HL_GPU").is_ok() { "prove-metal" } else { "prove-cpu" }, sh.profile);
        }
        let text = format!(
            "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}",
            core.a_root, core.h_root, core.mask_root, core.slots, core.mask_open, core.a_open, core.h_open, core.io_claims, core.order, core.lookups, tr.state()
        );
        blake3::hash(text.as_bytes()).to_hex().to_string()
    }

    /// **THE M4 BYTE-IDENTITY GATE.** Each development accuracy shape's seeded
    /// block proof, once on the CPU and once with the Metal device enabled,
    /// must digest to the same bytes, and the device must actually have run
    /// sumcheck rounds. It toggles `HL_GPU` in-process, so it is `#[ignore]`d
    /// and run alone by name (`--exact --test-threads=1`).
    #[cfg(feature = "gpu-metal")]
    #[test]
    #[ignore = "toggles HL_GPU in-process; run alone by name on a Mac"]
    fn m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal() {
        use crate::private_block::shape::NormCalibration;
        let shapes: Vec<Shape> = crate::private_block::accuracy_profile_tests::registered_shapes().into_iter().filter(|s| s.tokens == 32).collect();
        assert!(!shapes.is_empty());
        for original in shapes {
            let cal = NormCalibration { cn_a: 4000, cn_m: 4000, ..original.norm_calibration() };
            let original = Shape::accuracy_trained(original.profile, &cal, original.f_e, 20).unwrap();
            let (sh, data, public, ff) = case(original, 3);
            let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11) % 201) as i16 - 100).collect();
            let blk = crate::private_block::BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
            let wit = || crate::private_block::witness::build_accuracy(&sh, &public, &ff, &data, &input).unwrap();
            std::env::remove_var("HL_GPU");
            let cpu = seeded_accuracy_digest(&sh, &blk, wit());
            let before = crate::gpu::metal_sumcheck_stats().1;
            std::env::set_var("HL_GPU", "1");
            let metal = seeded_accuracy_digest(&sh, &blk, wit());
            std::env::remove_var("HL_GPU");
            let ran = crate::gpu::metal_sumcheck_stats().1 - before;
            eprintln!("M4-ACCURACY-DIGEST {} cpu {cpu} metal {metal} (device sumcheck rounds {ran:.4} s)", sh.name);
            assert_eq!(cpu, metal, "{}: the Metal accuracy proof's bytes differ from the CPU's", sh.name);
            assert!(ran > 0.0, "{}: no sumcheck round ran on the device", sh.name);
        }
    }

    /// **M4 AT A TRAINED GEOMETRY.** One seeded accuracy-stack block at each
    /// trained T128 shape named in `HL_M4_PROFILES` (default: the Shieldstral
    /// classifier's `R13_SHIELD_T128_H24`), synthetic public weights
    /// (`grow_tests::tame_case`) and a deterministic input: CPU then Metal,
    /// wall time of `prove_core` each, digests asserted equal. Timing is n = 1
    /// on whatever else the box runs; the digest equality is the result.
    #[cfg(feature = "gpu-metal")]
    #[test]
    #[ignore = "heavy, toggles HL_GPU in-process; run alone by name on a Mac"]
    fn m4_trained_accuracy_block_cpu_and_metal_digests_and_times() {
        let want = std::env::var("HL_M4_PROFILES").unwrap_or_else(|_| "R13_SHIELD_T128_H24".to_string());
        let want: Vec<&str> = want.split(',').collect();
        let mut shapes: Vec<Shape> = crate::private_block::accuracy_profile_tests::registered_shapes().into_iter().filter(|s| want.contains(&s.name)).collect();
        // W16 (D54): its profiles by name too, at `registered_shapes`' own
        // calibration rule (`accuracy_profile_tests::calibration`) and f_e
        for spec in crate::private_block::shape::W16_PROFILES.iter().filter(|s| want.contains(&s.name)) {
            let cal = crate::private_block::shape::NormCalibration { tn: if spec.width >= 3072 { 9 } else { 10 }, cn_a: 100, cn_m: 100, ceps: 1, sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6 };
            shapes.push(Shape::accuracy_trained(spec.profile, &cal, if spec.tokens == 32 { 12 } else { 9 }, 20).unwrap());
        }
        assert_eq!(shapes.len(), want.len(), "HL_M4_PROFILES names an unregistered accuracy profile");
        for original in shapes {
            let t0 = std::time::Instant::now();
            let (sh, data, public, ff) = case(original, 3);
            let blk = crate::private_block::BlockPublic::new(public.clone(), ff.clone()).with_accuracy(data.clone());
            let mut seed = 0usize;
            let input = loop {
                let input: Vec<i16> = (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + seed) % (41 + 20 * (seed % 3))) as i16 - 20).collect();
                match crate::private_block::witness::build_accuracy(&sh, &public, &ff, &data, &input) {
                    Ok(_) => break input,
                    Err(e) if seed < 6 => {
                        eprintln!("M4-TRAINED {} input {seed} not admissible: {e}", sh.name);
                        seed += 1;
                    }
                    Err(e) => panic!("{}: no admissible synthetic input: {e}", sh.name),
                }
            };
            let wit = || crate::private_block::witness::build_accuracy(&sh, &public, &ff, &data, &input).unwrap();
            eprintln!("M4-TRAINED {} setup {:.2} s", sh.name, t0.elapsed().as_secs_f64());
            std::env::remove_var("HL_GPU");
            let w = wit();
            let t = std::time::Instant::now();
            let cpu = seeded_accuracy_digest(&sh, &blk, w);
            let cpu_s = t.elapsed().as_secs_f64();
            let cpu_core = LAST_CORE_NS.load(std::sync::atomic::Ordering::Relaxed) as f64 * 1e-9;
            // twice on the device: COLD (this process compiles the shape's slot
            // kernels) and WARM (the in-process pipeline cache holds them, as for
            // every later layer of a multi-layer run). [M4i] HL_M4_WARM_PASSES=n
            // runs n warm passes (default 1): more samples per process, and a
            // steady window for a profiler
            let warm: usize = std::env::var("HL_M4_WARM_PASSES").ok().and_then(|v| v.parse().ok()).unwrap_or(1).max(1);
            let passes: Vec<&str> = std::iter::once("cold").chain(std::iter::repeat("warm").take(warm)).collect();
            for pass in passes {
                let (before, compile0, cpu_slots0) = (crate::gpu::metal_sumcheck_stats().1, crate::gpu::metal_sumcheck_stats().0, crate::private_block::metal_slot::cpu_slots());
                let pool0 = crate::gpu::metal_pool_stats();
                std::env::set_var("HL_GPU", "1");
                let w = wit();
                let t = std::time::Instant::now();
                let metal = seeded_accuracy_digest(&sh, &blk, w);
                let metal_s = t.elapsed().as_secs_f64();
                let metal_core = LAST_CORE_NS.load(std::sync::atomic::Ordering::Relaxed) as f64 * 1e-9;
                std::env::remove_var("HL_GPU");
                let (ran, compile) = (crate::gpu::metal_sumcheck_stats().1 - before, crate::gpu::metal_sumcheck_stats().0 - compile0);
                let cpu_slots = crate::private_block::metal_slot::cpu_slots() - cpu_slots0;
                let pool = crate::gpu::metal_pool_stats();
                let (hits, misses) = (pool.0 - pool0.0, pool.1 - pool0.1);
                eprintln!(
                    "M4-TRAINED {} cpu {cpu_s:.3} s metal-{pass} {metal_s:.3} s (prove core cpu {cpu_core:.3} s metal {metal_core:.3} s; kernel compile {compile:.3} s, device sumcheck rounds {ran:.3} s; {cpu_slots} slots without a matching IR; buffer pool {hits} reused / {misses} new) digest cpu {cpu} metal {metal}",
                    sh.name
                );
                assert_eq!(cpu, metal, "{}: the Metal accuracy proof's bytes differ from the CPU's", sh.name);
                assert!(ran > 0.0, "{}: no sumcheck round ran on the device", sh.name);
            }
        }
    }
}

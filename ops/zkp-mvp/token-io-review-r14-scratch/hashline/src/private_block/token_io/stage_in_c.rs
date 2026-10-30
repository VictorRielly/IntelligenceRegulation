//! **STAGE IN-C** (DESIGN_CLASSIFIER v2 §3.1, §3.6): stage IN
//! (`super::stage_in`, DESIGN v3 2.3) with two additions, and nothing else:
//!
//! * **the template clause** — every template position (the public prefix
//!   and suffix around the content; round 14, DESIGN v2.4 §15: and every
//!   position after a short item's suffix, up to `T`, holding the policy's
//!   public pad id) is pinned to its public id, by a clause
//!   with its OWN fresh coefficient in the query zero-check (a shared one
//!   would let it cancel against the LogUp clause: CHECK2 N-1, R-C0);
//! * **the control-id column (B-2)** — the lookup tuple gains a third, public
//!   column: table `tau(v) = v + beta E~(v, r_emb) + beta^2 ctl(v) + g_emb`,
//!   query `q_t = tok_t + beta x~(t, r_emb) + beta^2 c(t) + g_emb` with the
//!   public `c(t) = ctl(kappa(t))` at template positions and 0 at content
//!   positions: a content position holding a control id matches no table
//!   entry. Honest queries are still table values (D34's reading unchanged).
//!
//! Commitments, order and openings are stage IN's. A fork in its own file:
//! the frozen next-token stage (D36's pin) is untouched.

use super::classify::{ClassifierProfile, ClassifierTables};
use super::stage_in::StageInWitness;
use super::*;
use crate::pcs::{self, CommittedZk, ZkOpts};
use super::super::boundary::{self, BoundarySpec, PreparedBoundary};
use super::super::protocol;

pub(crate) const A_TOK: usize = 0;
pub(crate) const A_MULT: usize = 1;
pub(crate) const H_Q: usize = 0;
pub(crate) const H_TAB: usize = 1;
pub(crate) const H_U: usize = 2;

pub(crate) const SIC_IO: usize = 0;
pub(crate) const SIC_QZC: usize = 1;
pub(crate) const SIC_TZC: usize = 2;
pub(crate) const SIC_ZS: usize = 3;

/// the declared opening groups (stage IN's: the new columns are public)
pub(crate) const A_GROUPS: usize = 3;
pub(crate) const H_GROUPS: usize = 4;

pub(crate) fn layout(sh: &Shape, cp: &ClassifierProfile) -> StageLayout {
    let lt = cp.tier.stage_log_n;
    let (lti, lvoc) = (cp.ti_log(), cp.voc_log());
    let sched = StageSched {
        label: "stage IN-C",
        slots: vec![
            SlotSpec { name: "INC-00 IO-in: token endpoint = supp_T tok (whole padded plane: template and content)", main: clog2(cp.in_ep_words()), ext: 1, degree: 3, kind: SlotKind::Standalone, a_sites: 1, h_sites: 0, io_sites: 1 },
            SlotSpec { name: "INC-01 query zero-check: LogUp over (id, row, ctl) + BOS + TEMPLATE (prefix, suffix, trailing pad ids) + pad, fresh mu each", main: lti, ext: 1, degree: 4, kind: SlotKind::Standalone, a_sites: 1, h_sites: 1, io_sites: 1 },
            SlotSpec { name: "INC-02 table zero-check: h_tab (alpha - tau(v, ctl)) = m + pad, fresh mu each", main: lvoc, ext: 1, degree: 4, kind: SlotKind::Standalone, a_sites: 1, h_sites: 1, io_sites: 0 },
            SlotSpec { name: "INC-03 ZS zero-sum row", main: lt, ext: 1, degree: 2, kind: SlotKind::Standalone, a_sites: 0, h_sites: 1, io_sites: 0 },
        ],
        hosts: vec![],
        row_log: [lt, lt, cp.tier.ep_log_n, sh.endpoint_log_n],
    };
    StageLayout::new(cp.tier.stage_params(), vec![lti, lvoc], vec![lti, lvoc, lt], vec![1, -1, 1], H_U, sched)
}

/// `(queries, distinct table rows)` for the whole-run figure (stage IN's)
pub(crate) fn logup_size(lay: &StageLayout, cp: &ClassifierProfile) -> (u128, u128) {
    (1u128 << lay.h_log[H_Q], cp.v as u128)
}

/// the honest stage-IN-C inputs from an item's tokens (template + content):
/// `A_in`'s planes, the padded `B_in` plane and the input endpoint's words.
/// Refuses, before any commitment (D20 / H-1, naming no position or value):
/// a wrong length, an id outside V, a template position that is not its
/// public id, a content position holding a control id. A cheating prover
/// (test builds only) skips the refusals.
pub(crate) fn honest_inputs(cp: &ClassifierProfile, tables: &ClassifierTables, tokens: &[u64]) -> Result<(StageInWitness, Vec<i16>, Vec<Fp>), String> {
    #[cfg(test)]
    let cheating = protocol::cheating_prover_is_on();
    #[cfg(not(test))]
    let cheating = false;
    if tokens.len() != cp.tokens {
        return Err(format!("classifier stage IN-C: an item is exactly T = {} ids (template and content)", cp.tokens));
    }
    if !cheating {
        if tokens.iter().any(|t| *t >= cp.v as u64) {
            return Err("classifier stage IN-C: an id outside the vocabulary (refused before any commitment)".into());
        }
        if (0..cp.tokens).any(|t| cp.is_template(t) && tokens[t] != cp.kappa(t)) {
            return Err("classifier stage IN-C: a template position is not the policy's public id (refused before any commitment)".into());
        }
        if (0..cp.tokens).any(|t| !cp.is_template(t) && cp.ctl(tokens[t])) {
            return Err("classifier stage IN-C: a content position holds a control id (refused before any commitment; B-2)".into());
        }
    }
    let (ti_n, voc_n) = (1usize << cp.ti_log(), 1usize << cp.voc_log());
    let mut tok = vec![Fp::ZERO; ti_n];
    let mut mult = vec![Fp::ZERO; voc_n];
    let mut plane = vec![0i16; cp.t_pad * cp.d_pad];
    for (t, id) in tokens.iter().enumerate() {
        tok[t] = Fp::new(*id);
        let v = *id as usize;
        if v < voc_n {
            mult[v] = mult[v].add(Fp::ONE);
        }
        if v < cp.v {
            plane[t * cp.d_pad..t * cp.d_pad + cp.d].copy_from_slice(tables.emb_row(v));
        }
    }
    Ok((StageInWitness { tok, mult, hq_zero: vec![] }, plane, super::classify::input_plane(cp, tokens)))
}

/// **the sealing pass's stage-IN-C check** (ruling H-1, before any header):
/// stage IN's lookup checks plus the template ids and the control-id rule
pub(crate) fn lookup_misses(cp: &ClassifierProfile, tables: &ClassifierTables, wit: &StageInWitness, b_plane: &[i16]) -> Result<(), String> {
    let (ti_n, voc_n) = (1usize << cp.ti_log(), 1usize << cp.voc_log());
    if wit.tok.len() != ti_n || wit.mult.len() != voc_n || b_plane.len() != cp.t_pad * cp.d_pad || cp.tokens > ti_n {
        return Err("classifier stage IN-C: witness shape".into());
    }
    let miss = || Err("classifier stage IN-C: the witness's lookup misses (the class of the miss only)".to_string());
    let mut hist = vec![0u64; voc_n];
    for t in 0..ti_n {
        let id = wit.tok[t].0;
        if t >= cp.tokens {
            if id != 0 {
                return miss();
            }
            continue;
        }
        if id >= cp.v as u64 || (cp.is_template(t) && id != cp.kappa(t)) || (!cp.is_template(t) && cp.ctl(id)) {
            return miss();
        }
        hist[id as usize] += 1;
        let row = &b_plane[t * cp.d_pad..(t + 1) * cp.d_pad];
        if row[..cp.d] != *tables.emb_row(id as usize) || row[cp.d..].iter().any(|x| *x != 0) {
            return miss();
        }
    }
    if b_plane[cp.tokens * cp.d_pad..].iter().any(|x| *x != 0) {
        return miss();
    }
    if wit.mult.iter().zip(hist.iter()).any(|(m, h)| m.0 != *h) {
        return miss();
    }
    Ok(())
}

pub(crate) struct InCCtx<'a> {
    pub lay: &'a StageLayout,
    pub cp: &'a ClassifierProfile,
    pub alpha: Fp2,
    pub beta: Fp2,
    pub g_emb: Fp2,
    pub r_emb: Vec<Fp2>,
    pub tau_tab: Vec<Fp2>,
    pub b_in_row: usize,
    pub b_in_log: usize,
    pub ep_mask_row: usize,
}

fn supp(len: usize, size: usize) -> Vec<Fp2> {
    (0..size).map(|z| if z < len { Fp2::ONE } else { Fp2::ZERO }).collect()
}

/// `tau(v)` over the lifted vocabulary cube: true rows `v + beta E~(v, r) +
/// beta^2 ctl(v) + g`; padded rows repeat row 0's whole tuple
pub(crate) fn tau_table(cp: &ClassifierProfile, ef: &[Fp2], beta: Fp2, g_emb: Fp2) -> Vec<Fp2> {
    let b2 = beta.mul(beta);
    let row = |v: usize| k(v as i64).add(beta.mul(ef[v])).add(if cp.ctl(v as u64) { b2 } else { Fp2::ZERO }).add(g_emb);
    (0..1usize << cp.voc_log()).map(|v| if v < cp.v { row(v) } else { row(0) }).collect()
}

pub(crate) fn define(slot: usize, cx: &InCCtx, tr: &mut Transcript) -> Result<StageSlotDef, String> {
    let (lay, cp) = (cx.lay, cx.cp);
    let mut b = SB::new(lay, slot);
    let (alpha, beta, g_emb) = (cx.alpha, cx.beta, cx.g_emb);
    let (tl, sn) = (cp.ti_log(), 1usize << cp.ti_log());
    let (lv, vn) = (cp.voc_log(), 1usize << cp.voc_log());
    let t_bits = clog2(cp.t_pad);
    match slot {
        SIC_IO => {
            let words = cp.in_ep_words();
            let lw = clog2(words);
            let tau = tr.challenge_fp2_vec(lw);
            let i_eq = b.eq(&tau, 0);
            let i_supp = b.public(supp(cp.tokens, words));
            let mut ct = fixed(&vec![Fp2::ZERO; tl - lw]);
            ct.extend(rho(0..lw));
            let i_tok = b.a_at(A_TOK, ct)?;
            let i_end = b.io(Cm::In, lw, rho(0..lw), cx.ep_mask_row);
            b.finish(Box::new(move |v: &[Fp2]| v[i_eq].mul(v[i_end].sub(v[i_supp].mul(v[i_tok])))), vec![])
        }
        // the LogUp clause (three columns), the BOS clause, the TEMPLATE
        // clause and the pad clause, EACH with its own fresh coefficient
        SIC_QZC => {
            let tau = tr.challenge_fp2_vec(tl);
            let mu = nonzero(tr.challenge_fp2_vec(4))?;
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_supp = b.public(supp(cp.tokens, sn));
            let i_u0 = b.public(supp(1, sn));
            let rv_pad = super::rv14_mut("pad");
            let i_pi = b.public((0..sn).map(|t| if cp.is_template(t) && !(rv_pad && t >= cp.item_len()) { Fp2::ONE } else { Fp2::ZERO }).collect());
            let i_kappa = b.public((0..sn).map(|t| k(cp.kappa(t) as i64)).collect());
            let b2 = beta.mul(beta);
            let i_cq = b.public((0..sn).map(|t| if cp.ctl_q(t) { b2 } else { Fp2::ZERO }).collect());
            let i_tok = b.a(A_TOK)?;
            let i_hq = b.h(H_Q)?;
            let mut cb = rho(tl - t_bits..tl);
            cb.extend(fixed(&cx.r_emb));
            let i_b = b.io(Cm::Out, cx.b_in_log, cb, cx.b_in_row);
            let bos = k(cp.bos as i64);
            let poly = move |v: &[Fp2]| {
                let q = v[i_tok].add(beta.mul(v[i_b])).add(v[i_cq]).add(g_emb);
                let logup = v[i_hq].mul(alpha.sub(q)).sub(v[i_supp]);
                let bos_c = v[i_u0].mul(v[i_tok].sub(bos));
                let tmpl = v[i_pi].mul(v[i_tok].sub(v[i_kappa]));
                let pad = Fp2::ONE.sub(v[i_supp]).mul(v[i_tok].add(zeta.mul(v[i_hq])));
                v[i_eq].mul(mu[0].mul(logup).add(mu[1].mul(bos_c)).add(mu[2].mul(tmpl)).add(mu[3].mul(pad)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SIC_TZC => {
            let tau = tr.challenge_fp2_vec(lv);
            let mu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_supp = b.public(supp(cp.v, vn));
            let i_tau = b.public(cx.tau_tab.clone());
            let i_m = b.a(A_MULT)?;
            let i_h = b.h(H_TAB)?;
            let poly = move |v: &[Fp2]| {
                let rel = v[i_h].mul(alpha.sub(v[i_tau])).sub(v[i_m]);
                let pad = Fp2::ONE.sub(v[i_supp]).mul(v[i_m].add(zeta.mul(v[i_h])));
                v[i_eq].mul(mu[0].mul(rel).add(mu[1].mul(pad)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SIC_ZS => {
            let i1 = b.public(vec![Fp2::ONE; 1usize << lay.h_log[H_U]]);
            let iu = b.h(H_U)?;
            b.finish(Box::new(move |v: &[Fp2]| v[i1].mul(v[iu])), vec![])
        }
        _ => Err("classifier stage IN-C: unknown slot".into()),
    }
}

fn run_slots(side: &mut Side, cx: &InCCtx, tr: &mut Transcript) -> Result<Acc, String> {
    let mut acc = Acc::default();
    for slot in 0..cx.lay.sched.slots.len() {
        // ROUND 12 (gate round 16 capture request 2.2): the run capture's
        // definition checkpoint, as stage IN takes it (verify side only; a
        // no-op unless a recorder is attached; test builds only)
        #[cfg(test)]
        super::super::run_capture::start_slot(side, tr);
        let def = define(slot, cx, tr)?;
        run_stage_slot(side, &mut acc, def, &cx.lay.sched, tr)?;
    }
    finish_functionals(acc, cx.lay)
}

fn challenges(tr: &mut Transcript, cp: &ClassifierProfile, tables: &ClassifierTables) -> (Fp2, Fp2, Fp2, Vec<Fp2>, Vec<Fp2>) {
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let r_emb = tr.challenge_fp2_vec(clog2(cp.d_pad));
    let g_emb = gamma.mul_base(Fp::new(TAG_EMB));
    let ef = tables.emb_fold(&r_emb);
    (beta, alpha, g_emb, r_emb, ef)
}

fn inv_or_refuse(d: Fp2) -> Result<Fp2, String> {
    if d.is_zero() {
        return Err("zero LogUp denominator; discard attempt".into());
    }
    Ok(d.inv())
}

pub(crate) struct InCProved {
    pub seg: StageSegment,
    pub pending_b: Vec<ZClaim>,
    pub b_owner: PreparedBoundary,
    pub decommitment: Decommitment,
}

/// **THE STAGE IN-C PROVER** (stage IN's order: the stage words, `B_in`,
/// `A_in`, `M_in`, the challenges, `H_in`, the four slots, the openings, the
/// input endpoint consumed)
#[allow(clippy::too_many_arguments)]
pub(crate) fn prove(
    lay: &StageLayout,
    cp: &ClassifierProfile,
    tables: &ClassifierTables,
    wit: StageInWitness,
    b_spec: &BoundarySpec,
    b_plane: &[i16],
    ep: CommittedZk,
    ntt: &crate::ntt::NttTables,
    rng: &mut crate::zk::ZkRng,
    tr: &mut Transcript,
    tag: &zkp_core::hashtag::HashTag,
) -> Result<InCProved, String> {
    let n = lay.n;
    let (ti_n, voc_n) = (1usize << cp.ti_log(), 1usize << cp.voc_log());
    if wit.tok.len() != ti_n || wit.mult.len() != voc_n || lay.a_log != [cp.ti_log(), cp.voc_log()] {
        return Err("classifier stage IN-C: witness shape".into());
    }
    if b_plane.len() != b_spec.len() || b_plane.len() != cp.t_pad * cp.d_pad {
        return Err("classifier stage IN-C: the B_in plane is not the padded block plane".into());
    }
    tr.absorb_u64(b"pb-run-stage", 0);
    tr.absorb(b"pb-run-block", &cp.emb_digest);
    let b_words: Vec<Fp> = b_plane.iter().map(|x| Fp::from_i64(i64::from(*x))).collect();
    let b_owner = boundary::prepare(b_spec, &b_words, ntt, rng, tag)?;
    protocol::absorb_root(tr, b"B", &b_owner.root(), b_spec.commitment_rows(), b_spec.log_n());
    let params = lay.params;
    let zko = ZkOpts::standard(&params);
    let mut a_data = vec![Fp::ZERO; lay.a_rows * n];
    a_data[lay.a_off[A_TOK]..lay.a_off[A_TOK] + ti_n].copy_from_slice(&wit.tok);
    a_data[lay.a_off[A_MULT]..lay.a_off[A_MULT] + voc_n].copy_from_slice(&wit.mult);
    for x in &mut a_data[lay.a_mask_base * n..] {
        *x = rng.fp();
    }
    let mut a = pcs::commit_zk_owned_tagged(&params, a_data, ntt, &zko, rng, tag);
    a.mask_rows = lay.a_site_rows();
    a.prox_mask_row = Some(lay.a_prox);
    let a_root = a.commitment().root;
    protocol::absorb_root(tr, b"A", &a_root, lay.a_rows, lay.log_n);
    let mc = crate::zk::mask_commit_tagged(&lay.mask_specs(), ntt, rng, tag);
    let mask_root = mc.tree.root();
    tr.absorb(b"M", &mask_root);
    let (beta, alpha, g_emb, r_emb, ef) = challenges(tr, cp, tables);
    let tau_tab = tau_table(cp, &ef, beta, g_emb);
    let b2 = beta.mul(beta);
    let e_r = eq_table_msb(&r_emb);
    let mut h_q = vec![Fp2::ZERO; ti_n];
    for t in 0..cp.tokens {
        if wit.hq_zero.contains(&t) {
            continue;
        }
        let row = &b_plane[t * cp.d_pad..(t + 1) * cp.d_pad];
        let xr = row.iter().zip(e_r.iter()).fold(Fp2::ZERO, |acc_, (x, e)| if *x == 0 { acc_ } else { acc_.add(e.mul_base(Fp::from_i64(i64::from(*x)))) });
        let cq = if cp.ctl_q(t) { b2 } else { Fp2::ZERO };
        let q = Fp2::from_base(wit.tok[t]).add(beta.mul(xr)).add(cq).add(g_emb);
        h_q[t] = inv_or_refuse(alpha.sub(q))?;
    }
    let mut h_tab = vec![Fp2::ZERO; voc_n];
    for v in 0..voc_n {
        if !wit.mult[v].is_zero() {
            h_tab[v] = inv_or_refuse(alpha.sub(tau_tab[v]))?.mul_base(wit.mult[v]);
        }
    }
    let mut h_data = vec![Fp::ZERO; lay.h_rows * n];
    super::stage_in::write_h(&mut h_data, lay.h_off[H_Q], &h_q);
    super::stage_in::write_h(&mut h_data, lay.h_off[H_TAB], &h_tab);
    for x in &mut h_data[lay.h_mask_base * n..] {
        *x = rng.fp();
    }
    for r in lay.h_u_rows() {
        let mut sum = Fp::ZERO;
        for j in 0..n - 1 {
            let v = rng.fp();
            h_data[r * n + j] = v;
            sum = sum.add(v);
        }
        h_data[r * n + n - 1] = sum.neg();
    }
    let mut h = pcs::commit_zk_owned_tagged(&params, h_data, ntt, &zko, rng, tag);
    h.mask_rows = lay.h_site_rows().into_iter().chain(lay.h_u_rows()).collect();
    h.prox_mask_row = Some(lay.h_prox);
    let h_root = h.commitment().root;
    protocol::absorb_root(tr, b"H", &h_root, lay.h_rows, lay.log_n);
    let ep_data_rows = ep.cm.rows - super::super::endpoint_g::MASK_ROWS;
    let cx = InCCtx { lay, cp, alpha, beta, g_emb, r_emb, tau_tab, b_in_row: b_spec.mask_row(0)?, b_in_log: (cp.t_pad * cp.d_pad).trailing_zeros() as usize, ep_mask_row: ep_data_rows };
    let pd = super::super::argument::ProverData { data: [a.data.as_slice(), h.data.as_slice(), ep.data.as_slice(), b_owner.data()], masks: &mc.masks };
    let mut side = Side::Prove { pd, out: Vec::new() };
    let acc = run_slots(&mut side, &cx, tr)?;
    let slots = match side {
        Side::Prove { out, .. } => out,
        Side::Verify { .. } => unreachable!(),
    };
    let mask_open = crate::zk::mask_open(&mc, &acc.fs, ntt, tr);
    drop(mc);
    let [ac, mut hc, ic, oc] = acc.claims;
    hc.push(lay.logup_sum_claim());
    protocol::check_opening(&ac, lay.log_n, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, A_GROUPS, tr)?;
    let a_open = pcs::open_zk(&a, &ac, tr);
    drop(a);
    protocol::check_opening(&hc, lay.log_n, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, H_GROUPS, tr)?;
    let h_open = pcs::open_zk(&h, &hc, tr);
    drop(h);
    check_token_endpoint_opening(&ic, ep_data_rows, cp.tier.ep_n(), tr)?;
    let ep_open = pcs::open_zk(&ep, &ic, tr);
    let decommitment = Decommitment { data: ep.data.clone(), pads: ep.pads.clone(), salts: ep.salts.clone() };
    drop(ep);
    Ok(InCProved { seg: StageSegment { b_root: Some(b_owner.root()), a_root, h_root, mask_root, slots, mask_open, a_open, h_open, closes: vec![ep_open] }, pending_b: oc, b_owner, decommitment })
}

/// **THE STAGE IN-C VERIFIER**
#[allow(clippy::too_many_arguments)]
pub(crate) fn verify(
    lay: &StageLayout,
    cp: &ClassifierProfile,
    tables: &ClassifierTables,
    seg: &StageSegment,
    b_spec: &BoundarySpec,
    ep_spec: &super::super::endpoint_g::EndpointSpecG,
    ep_root: &Digest,
    ntt: &crate::ntt::NttTables,
    tr: &mut Transcript,
    tag: &zkp_core::hashtag::HashTag,
) -> Result<(Vec<ZClaim>, Digest), String> {
    let params = lay.params;
    let zko = ZkOpts::standard(&params);
    if seg.closes.len() != 1 {
        return Err("classifier: stage IN-C's segment parts are not the run schedule's".into());
    }
    super::super::hash_domain::paths_are_the_tree_depth("stage IN-C A", &params, &seg.a_open)?;
    super::super::hash_domain::paths_are_the_tree_depth("stage IN-C H", &params, &seg.h_open)?;
    super::super::hash_domain::mask_paths_are_the_tree_depth(&seg.mask_open)?;
    let ep_params = ep_spec.params();
    super::super::hash_domain::paths_are_the_tree_depth("input token endpoint", &ep_params, &seg.closes[0])?;
    let b_root = seg.b_root.ok_or("classifier: stage IN-C's segment carries no B_in root")?;
    tr.absorb_u64(b"pb-run-stage", 0);
    tr.absorb(b"pb-run-block", &cp.emb_digest);
    protocol::absorb_root(tr, b"B", &b_root, b_spec.commitment_rows(), b_spec.log_n());
    protocol::absorb_root(tr, b"A", &seg.a_root, lay.a_rows, lay.log_n);
    tr.absorb(b"M", &seg.mask_root);
    let (beta, alpha, g_emb, r_emb, ef) = challenges(tr, cp, tables);
    let tau_tab = tau_table(cp, &ef, beta, g_emb);
    protocol::absorb_root(tr, b"H", &seg.h_root, lay.h_rows, lay.log_n);
    let ep_data_rows = ep_spec.data_rows();
    let cx = InCCtx { lay, cp, alpha, beta, g_emb, r_emb, tau_tab, b_in_row: b_spec.mask_row(0)?, b_in_log: (cp.t_pad * cp.d_pad).trailing_zeros() as usize, ep_mask_row: ep_data_rows };
    let mut side = Side::Verify { slots: &seg.slots };
    let acc = run_slots(&mut side, &cx, tr)?;
    // ROUND 12 (gate round 16 capture request 2.2): every opening of the
    // stage wrapped as stage IN wraps its own (checkpoint after the schedule
    // check, the hook after the verification; no-ops unless a recorder is
    // attached; test builds only)
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    crate::zk::mask_verify_tagged(&seg.mask_root, &lay.mask_specs(), &acc.fs, &seg.mask_open, ntt, tr, tag).map_err(|e| format!("stage IN-C M: {e}"))?;
    #[cfg(test)]
    super::super::run_capture::mask(&lay.mask_specs(), &seg.mask_root, &acc.fs, &seg.mask_open, ntt, rc_before, tr);
    let [ac, mut hc, ic, oc] = acc.claims;
    hc.push(lay.logup_sum_claim());
    protocol::check_opening(&ac, lay.log_n, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, A_GROUPS, tr)?;
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.a_root, lay.a_rows, lay.log_n), &ac, &seg.a_open, ntt, tr, tag).map_err(|e| format!("stage IN-C A: {e}"))?;
    #[cfg(test)]
    super::super::run_capture::pcs(capture_a_geom("A-in", "stage-in-c", lay, seg.a_root), &ac, &seg.a_open, ntt, rc_before, tr);
    protocol::check_opening(&hc, lay.log_n, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, H_GROUPS, tr)?;
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.h_root, lay.h_rows, lay.log_n), &hc, &seg.h_open, ntt, tr, tag).map_err(|e| format!("stage IN-C H (the LogUp sum claim is part of this opening): {e}"))?;
    #[cfg(test)]
    super::super::run_capture::pcs(capture_h_geom("H-in", "stage-in-c", lay, seg.h_root), &hc, &seg.h_open, ntt, rc_before, tr);
    check_token_endpoint_opening(&ic, ep_data_rows, cp.tier.ep_n(), tr)?;
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&ep_params, &ZkOpts::standard(&ep_params), &protocol::commitment(*ep_root, ep_spec.commitment_rows(), cp.tier.ep_log_n), &ic, &seg.closes[0], ntt, tr, tag).map_err(|e| format!("input token endpoint: {e}"))?;
    #[cfg(test)]
    super::super::run_capture::pcs(capture_ep_geom("E-token-in", ep_spec, *ep_root, vec![(0, SIC_IO, ic.len())]), &ic, &seg.closes[0], ntt, rc_before, tr);
    Ok((oc, b_root))
}

/// ROUND 12 (gate round 16 capture request 2.1(b)): stage IN-C's plane table
/// for the run capture (the plane names are this module's, in plane order)
#[cfg(test)]
pub(crate) fn capture_planes(lay: &StageLayout) -> super::super::run_capture::StagePlanes<'_> {
    super::super::run_capture::StagePlanes::Stage {
        lay,
        a_names: vec!["A_TOK".into(), "A_MULT".into()],
        h_names: vec!["H_Q".into(), "H_TAB".into(), "H_U".into()],
        // [A, H, In = the input token endpoint, Out = B_in]
        roles: ["A-in", "H-in", "E-token-in", "B-in"],
    }
}

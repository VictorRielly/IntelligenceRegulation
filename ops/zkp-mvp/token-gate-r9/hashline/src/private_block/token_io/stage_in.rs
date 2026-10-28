//! **STAGE IN** (DESIGN v3 2.3, option (b)): hidden token ids -> hidden
//! `x_in = B_in` through the public int16 embedding table, by ONE indexed
//! LogUp lookup per position of the compressed row `(tok_t, x~(t, r_emb))` in
//! the `V`-row table `(v, E~(v, r_emb))`, with BOS forced at position 0.
//!
//! Commitments: `A_in` = `tok` (on `h_q`'s lifted domain) and the histogram
//! `m`; `H_in` = `h_q`, `h_tab` and the zero-sum pair `u`; `M_in` (4 slots).
//! Order (DESIGN 2.3): absorb the stage tag and the embedding digest, commit
//! `B_in`, commit `A_in`, commit `M_in`, draw beta, gamma, alpha, r_emb,
//! commit `H_in`, the four slots, open `M_in`, `A_in`, `H_in`, then the input
//! token endpoint (one site). `B_in` is opened in block 0's stage. Every
//! soundness lever (row widths, rates, Q) is the profile's tier (D27).

use super::*;
use crate::pcs::{self, CommittedZk, ZkOpts};
use super::super::boundary::{self, BoundarySpec, PreparedBoundary};
use super::super::protocol;

pub(crate) const A_TOK: usize = 0;
pub(crate) const A_MULT: usize = 1;
pub(crate) const H_Q: usize = 0;
pub(crate) const H_TAB: usize = 1;
pub(crate) const H_U: usize = 2;

pub(crate) const SI_IO: usize = 0;
pub(crate) const SI_QZC: usize = 1;
pub(crate) const SI_TZC: usize = 2;
pub(crate) const SI_ZS: usize = 3;

/// the declared opening groups (distinct column keys): A = IO-in's `tok`,
/// the query zero-check's `tok`, the table zero-check's `m`; H = `h_q`,
/// `h_tab`, `u`, and the pairless LogUp sum claim
pub(crate) const A_GROUPS: usize = 3;
pub(crate) const H_GROUPS: usize = 4;

/// the stage's schedule and layout (DESIGN 2.3 tables; the counter's
/// `input_b`): every domain at the stage row width (the P-3 lift)
pub(crate) fn layout(sh: &Shape, tp: &TokenProfile) -> StageLayout {
    let lt = tp.tier.stage_log_n;
    let (lti, lvoc) = (tp.ti_log(), tp.voc_log());
    let sched = StageSched {
        label: "stage IN",
        slots: vec![
            SlotSpec { name: "IN-00 IO-in: token endpoint = supp_T tok (whole padded plane)", main: clog2(tp.in_ep_words()), ext: 1, degree: 3, kind: SlotKind::Standalone, a_sites: 1, h_sites: 0, io_sites: 1 },
            SlotSpec { name: "IN-01 query zero-check: LogUp + BOS (own mu_bos) + pad, fresh mu each", main: lti, ext: 1, degree: 4, kind: SlotKind::Standalone, a_sites: 1, h_sites: 1, io_sites: 1 },
            SlotSpec { name: "IN-02 table zero-check: h_tab (alpha - tau) = m + pad, fresh mu each", main: lvoc, ext: 1, degree: 4, kind: SlotKind::Standalone, a_sites: 1, h_sites: 1, io_sites: 0 },
            SlotSpec { name: "IN-03 ZS zero-sum row", main: lt, ext: 1, degree: 2, kind: SlotKind::Standalone, a_sites: 0, h_sites: 1, io_sites: 0 },
        ],
        hosts: vec![],
        // [A, H, In = the input token endpoint, Out = B_in]
        row_log: [lt, lt, tp.tier.ep_log_n, sh.endpoint_log_n],
    };
    // A = [tok on Ti, m on Voc]; H = [h_q on Ti, h_tab on Voc, the zero-sum pair u (one row)]
    StageLayout::new(tp.tier.stage_params(), vec![lti, lvoc], vec![lti, lvoc, lt], vec![1, -1, 1], H_U, sched)
}

/// The stage's LogUp size for the derived whole-run figure (D27; MEMO_G02):
/// `(queries, distinct table rows)` = one query per position of `h_q`'s
/// (lifted) domain, and the `V` distinct compressed rows (padded table rows
/// repeat row 0).
pub(crate) fn logup_size(lay: &StageLayout, tp: &TokenProfile) -> (u128, u128) {
    (1u128 << lay.h_log[H_Q], tp.v as u128)
}

/// What the stage IN prover commits on `A_in` (and, for the tamper controls,
/// the positions where a CHEATING prover zeroes `h_q`).
#[derive(Clone, Debug)]
pub(crate) struct StageInWitness {
    pub tok: Vec<Fp>,
    pub mult: Vec<Fp>,
    pub hq_zero: Vec<usize>,
}

/// The honest stage-IN inputs from a prompt: `A_in`'s planes, the padded
/// `B_in` plane `E[tok]` (`t_pad x d_pad`, int16) and the input token
/// endpoint's words. Refuses (D20, naming no position or value) an
/// out-of-vocabulary id and a missing BOS BEFORE any commitment exists; a
/// cheating prover (test builds only) skips both refusals.
pub(crate) fn honest_inputs(tp: &TokenProfile, tables: &TokenTables, tokens: &[u64]) -> Result<(StageInWitness, Vec<i16>, Vec<Fp>), String> {
    #[cfg(test)]
    let cheating = protocol::cheating_prover_is_on();
    #[cfg(not(test))]
    let cheating = false;
    if tokens.len() != tp.tokens {
        return Err(format!("token I/O stage IN: the public-row variant needs exactly T = {} prompt tokens", tp.tokens));
    }
    if !cheating {
        if tokens.iter().any(|t| *t >= tp.v as u64) {
            return Err("token I/O stage IN: a token id outside the vocabulary (refused before any commitment)".into());
        }
        if tokens[0] != tp.bos {
            return Err("token I/O stage IN: position 0 is not the profile's BOS (refused before any commitment)".into());
        }
    }
    let (ti_n, voc_n) = (1usize << tp.ti_log(), 1usize << tp.voc_log());
    let mut tok = vec![Fp::ZERO; ti_n];
    let mut mult = vec![Fp::ZERO; voc_n];
    let mut plane = vec![0i16; tp.t_pad * tp.d_pad];
    for (t, id) in tokens.iter().enumerate() {
        tok[t] = Fp::new(*id);
        let v = *id as usize;
        if v < voc_n {
            mult[v] = mult[v].add(Fp::ONE);
        }
        if v < tp.v {
            plane[t * tp.d_pad..t * tp.d_pad + tp.d].copy_from_slice(tables.emb_row(v));
        }
    }
    Ok((StageInWitness { tok, mult, hq_zero: vec![] }, plane, endpoint_plane(tp, tokens)))
}

/// **ROUND 9 (F-T1): stage IN's indexed lookup, checked in the run's
/// SEALING PASS, before any header** (ruling H-1). Challenge-free: every
/// prompt position's id lies in the vocabulary (BOS at position 0), its
/// `B_in` row is that id's embedding row with zero pad words, every pad
/// position's id and `B_in` row are zero, and the multiplicities are the
/// prompt's histogram — exactly what the IN-01 / IN-02 LogUp needs to close.
/// Names the class of the miss only, never a position or value.
pub(crate) fn lookup_misses(tp: &TokenProfile, tables: &TokenTables, wit: &StageInWitness, b_plane: &[i16]) -> Result<(), String> {
    let (ti_n, voc_n) = (1usize << tp.ti_log(), 1usize << tp.voc_log());
    if wit.tok.len() != ti_n || wit.mult.len() != voc_n || b_plane.len() != tp.t_pad * tp.d_pad || tp.tokens > ti_n {
        return Err("token I/O stage IN: witness shape".into());
    }
    let miss = || Err("token I/O stage IN: the witness's embedding lookup misses (the class of the miss only)".to_string());
    let mut hist = vec![0u64; voc_n];
    for t in 0..ti_n {
        let id = wit.tok[t].0;
        if t >= tp.tokens {
            if id != 0 {
                return miss();
            }
            continue;
        }
        if id >= tp.v as u64 || (t == 0 && id != tp.bos) {
            return miss();
        }
        hist[id as usize] += 1;
        let row = &b_plane[t * tp.d_pad..(t + 1) * tp.d_pad];
        if row[..tp.d] != *tables.emb_row(id as usize) || row[tp.d..].iter().any(|x| *x != 0) {
            return miss();
        }
    }
    if b_plane[tp.tokens * tp.d_pad..].iter().any(|x| *x != 0) {
        return miss();
    }
    if wit.mult.iter().zip(hist.iter()).any(|(m, h)| m.0 != *h) {
        return miss();
    }
    Ok(())
}

/// the input token endpoint's plane from a prompt (public-row variant: `tok`
/// alone over `max(row width, T_pad)` words, pad words zero)
pub(crate) fn endpoint_plane(tp: &TokenProfile, tokens: &[u64]) -> Vec<Fp> {
    let mut ep = vec![Fp::ZERO; tp.in_ep_words()];
    for (t, id) in tokens.iter().enumerate() {
        ep[t] = Fp::new(*id);
    }
    ep
}

/// The slot context, identical on both sides.
pub(crate) struct InCtx<'a> {
    pub lay: &'a StageLayout,
    pub tp: &'a TokenProfile,
    pub alpha: Fp2,
    pub beta: Fp2,
    pub g_emb: Fp2,
    pub r_emb: Vec<Fp2>,
    /// `tau(v) = v' + beta E~(v', r_emb) + g_emb` over the lifted Voc cube
    pub tau_tab: Vec<Fp2>,
    /// the reserved pair of `B_in`'s site 0 (this stage's claim)
    pub b_in_row: usize,
    pub b_in_log: usize,
    pub ep_mask_row: usize,
}

/// the support of the first `len` entries over a cube of `size`
fn supp(len: usize, size: usize) -> Vec<Fp2> {
    (0..size).map(|z| if z < len { Fp2::ONE } else { Fp2::ZERO }).collect()
}

/// `tau(v)` for every position of the lifted vocabulary cube: true rows
/// `v + beta E~(v, r) + g`, padded rows repeat row 0 (DESIGN 2.3: `v' = 0`)
pub(crate) fn tau_table(tp: &TokenProfile, ef: &[Fp2], beta: Fp2, g_emb: Fp2) -> Vec<Fp2> {
    (0..1usize << tp.voc_log()).map(|v| if v < tp.v { k(v as i64).add(beta.mul(ef[v])).add(g_emb) } else { beta.mul(ef[0]).add(g_emb) }).collect()
}

pub(crate) fn define(slot: usize, cx: &InCtx, tr: &mut Transcript) -> Result<StageSlotDef, String> {
    let (lay, tp) = (cx.lay, cx.tp);
    let mut b = SB::new(lay, slot);
    let (alpha, beta, g_emb) = (cx.alpha, cx.beta, cx.g_emb);
    // the position domain Ti (IO-in, QZC), the vocabulary domain Voc (TZC)
    let (tl, sn) = (tp.ti_log(), 1usize << tp.ti_log());
    let (lv, vn) = (tp.voc_log(), 1usize << tp.voc_log());
    let t_bits = clog2(tp.t_pad);
    match slot {
        // D17 rule 1: over the endpoint's WHOLE padded plane, with the public
        // support factor binding the pad words to zero (DESIGN C-3)
        SI_IO => {
            let words = tp.in_ep_words();
            let lw = clog2(words);
            let tau = tr.challenge_fp2_vec(lw);
            let i_eq = b.eq(&tau, 0);
            let i_supp = b.public(supp(tp.tokens, words));
            let mut ct = fixed(&vec![Fp2::ZERO; tl - lw]);
            ct.extend(rho(0..lw));
            let i_tok = b.a_at(A_TOK, ct)?;
            let i_end = b.io(Cm::In, lw, rho(0..lw), cx.ep_mask_row);
            b.finish(Box::new(move |v: &[Fp2]| v[i_eq].mul(v[i_end].sub(v[i_supp].mul(v[i_tok])))), vec![])
        }
        // the LogUp clause, the BOS clause and the pad clause, EACH with its
        // own fresh coefficient drawn after A_in, M_in and H_in (v3, N-1/N-3)
        SI_QZC => {
            let tau = tr.challenge_fp2_vec(tl);
            let mu = nonzero(tr.challenge_fp2_vec(3))?;
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_supp = b.public(supp(tp.tokens, sn));
            let i_u0 = b.public(supp(1, sn));
            let i_tok = b.a(A_TOK)?;
            let i_hq = b.h(H_Q)?;
            // B_in at (rho_t, r_emb): its row bits on the trailing variables,
            // broadcast over the lift bits (where h_q = 0)
            let mut cb = rho(tl - t_bits..tl);
            cb.extend(fixed(&cx.r_emb));
            let i_b = b.io(Cm::Out, cx.b_in_log, cb, cx.b_in_row);
            let bos = k(tp.bos as i64);
            let poly = move |v: &[Fp2]| {
                let q = v[i_tok].add(beta.mul(v[i_b])).add(g_emb);
                let logup = v[i_hq].mul(alpha.sub(q)).sub(v[i_supp]);
                let bos_c = v[i_u0].mul(v[i_tok].sub(bos));
                let pad = Fp2::ONE.sub(v[i_supp]).mul(v[i_tok].add(zeta.mul(v[i_hq])));
                v[i_eq].mul(mu[0].mul(logup).add(mu[1].mul(bos_c)).add(mu[2].mul(pad)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SI_TZC => {
            let tau = tr.challenge_fp2_vec(lv);
            let mu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_supp = b.public(supp(tp.v, vn));
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
        SI_ZS => {
            let i1 = b.public(vec![Fp2::ONE; 1usize << lay.h_log[H_U]]);
            let iu = b.h(H_U)?;
            b.finish(Box::new(move |v: &[Fp2]| v[i1].mul(v[iu])), vec![])
        }
        _ => Err("token I/O stage IN: unknown slot".into()),
    }
}

fn run_slots(side: &mut Side, cx: &InCtx, tr: &mut Transcript) -> Result<Acc, String> {
    let mut acc = Acc::default();
    for slot in 0..cx.lay.sched.slots.len() {
        // TOKEN I/O (round 7): the run capture's definition checkpoint, as
        // `argument::argument` takes it (verify side only; a no-op unless a
        // recorder is attached)
        #[cfg(test)]
        super::super::run_capture::start_slot(side, tr);
        let def = define(slot, cx, tr)?;
        run_stage_slot(side, &mut acc, def, &cx.lay.sched, tr)?;
    }
    finish_functionals(acc, cx.lay)
}

/// the LogUp challenges (in F_p^2, the tier's lookup field) and the embedding
/// fold, identical on both sides
fn challenges(tr: &mut Transcript, tp: &TokenProfile, tables: &TokenTables) -> (Fp2, Fp2, Fp2, Vec<Fp2>, Vec<Fp2>) {
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let r_emb = tr.challenge_fp2_vec(clog2(tp.d_pad));
    let g_emb = gamma.mul_base(Fp::new(TAG_EMB));
    let ef = tables.emb_fold(&r_emb);
    (beta, alpha, g_emb, r_emb, ef)
}

pub(crate) fn write_h(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
    for (i, v) in col.iter().enumerate() {
        h[off.0 + i] = v.c0;
        h[off.1 + i] = v.c1;
    }
}

fn inv_or_refuse(d: Fp2) -> Result<Fp2, String> {
    if d.is_zero() {
        return Err("zero LogUp denominator; discard attempt".into());
    }
    Ok(d.inv())
}

/// What stage IN hands the run: its segment, the claim it raised on `B_in`
/// (site 0, completed in block 0's stage), the `B_in` owner, and the input
/// endpoint's decommitment for its owner (private, D21).
pub(crate) struct InProved {
    pub seg: StageSegment,
    pub pending_b: Vec<ZClaim>,
    pub b_owner: PreparedBoundary,
    pub decommitment: Decommitment,
}

/// **THE STAGE IN PROVER.** The caller has absorbed the run header; this
/// absorbs the stage tag, commits `B_in` (from `b_plane`), `A_in`, `M_in`,
/// `H_in`, runs the four slots, opens `M_in`, `A_in`, `H_in` and the input
/// token endpoint (consumed).
#[allow(clippy::too_many_arguments)]
pub(crate) fn prove(
    lay: &StageLayout,
    tp: &TokenProfile,
    tables: &TokenTables,
    wit: StageInWitness,
    b_spec: &BoundarySpec,
    b_plane: &[i16],
    ep: CommittedZk,
    ntt: &crate::ntt::NttTables,
    rng: &mut crate::zk::ZkRng,
    tr: &mut Transcript,
    tag: &zkp_core::hashtag::HashTag,
) -> Result<InProved, String> {
    let n = lay.n;
    let (ti_n, voc_n) = (1usize << tp.ti_log(), 1usize << tp.voc_log());
    if wit.tok.len() != ti_n || wit.mult.len() != voc_n || lay.a_log != [tp.ti_log(), tp.voc_log()] {
        return Err("token I/O stage IN: witness shape".into());
    }
    if b_plane.len() != b_spec.len() || b_plane.len() != tp.t_pad * tp.d_pad {
        return Err("token I/O stage IN: the B_in plane is not the padded block plane".into());
    }
    // the run's stage locality words (the block run's own two labels):
    // stage 0, whose public words are the embedding table
    tr.absorb_u64(b"pb-run-stage", 0);
    tr.absorb(b"pb-run-block", &tp.emb_digest);
    // B_in: the block's internal-boundary geometry (two sites), committed
    // before any challenge of either claim (D12a)
    let b_words: Vec<Fp> = b_plane.iter().map(|x| Fp::from_i64(i64::from(*x))).collect();
    let b_owner = boundary::prepare(b_spec, &b_words, ntt, rng, tag)?;
    protocol::absorb_root(tr, b"B", &b_owner.root(), b_spec.commitment_rows(), b_spec.log_n());
    // A_in
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
    // M_in
    let mc = crate::zk::mask_commit_tagged(&lay.mask_specs(), ntt, rng, tag);
    let mask_root = mc.tree.root();
    tr.absorb(b"M", &mask_root);
    // beta, gamma, alpha, r_emb -- after B_in, A_in, M_in (DESIGN 2.3 (iii))
    let (beta, alpha, g_emb, r_emb, ef) = challenges(tr, tp, tables);
    let tau_tab = tau_table(tp, &ef, beta, g_emb);
    // H_in
    let e_r = eq_table_msb(&r_emb);
    let mut h_q = vec![Fp2::ZERO; ti_n];
    for t in 0..tp.tokens {
        if wit.hq_zero.contains(&t) {
            continue;
        }
        let row = &b_plane[t * tp.d_pad..(t + 1) * tp.d_pad];
        let xr = row.iter().zip(e_r.iter()).fold(Fp2::ZERO, |acc_, (x, e)| if *x == 0 { acc_ } else { acc_.add(e.mul_base(Fp::from_i64(i64::from(*x)))) });
        let q = Fp2::from_base(wit.tok[t]).add(beta.mul(xr)).add(g_emb);
        h_q[t] = inv_or_refuse(alpha.sub(q))?;
    }
    let mut h_tab = vec![Fp2::ZERO; voc_n];
    for v in 0..voc_n {
        if !wit.mult[v].is_zero() {
            h_tab[v] = inv_or_refuse(alpha.sub(tau_tab[v]))?.mul_base(wit.mult[v]);
        }
    }
    let mut h_data = vec![Fp::ZERO; lay.h_rows * n];
    write_h(&mut h_data, lay.h_off[H_Q], &h_q);
    write_h(&mut h_data, lay.h_off[H_TAB], &h_tab);
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
    // the four slots
    let ep_data_rows = ep.cm.rows - super::super::endpoint_g::MASK_ROWS;
    let cx = InCtx { lay, tp, alpha, beta, g_emb, r_emb, tau_tab, b_in_row: b_spec.mask_row(0)?, b_in_log: (tp.t_pad * tp.d_pad).trailing_zeros() as usize, ep_mask_row: ep_data_rows };
    let pd = super::super::argument::ProverData { data: [a.data.as_slice(), h.data.as_slice(), ep.data.as_slice(), b_owner.data()], masks: &mc.masks };
    let mut side = Side::Prove { pd, out: Vec::new() };
    let acc = run_slots(&mut side, &cx, tr)?;
    let slots = match side {
        Side::Prove { out, .. } => out,
        Side::Verify { .. } => unreachable!(),
    };
    // ONE M opening, then ONE opening per commitment
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
    check_token_endpoint_opening(&ic, ep_data_rows, tp.tier.ep_n(), tr)?;
    let ep_open = pcs::open_zk(&ep, &ic, tr);
    let decommitment = Decommitment { data: ep.data.clone(), pads: ep.pads.clone(), salts: ep.salts.clone() };
    drop(ep);
    Ok(InProved {
        seg: StageSegment { b_root: Some(b_owner.root()), a_root, h_root, mask_root, slots, mask_open, a_open, h_open, closes: vec![ep_open] },
        pending_b: oc,
        b_owner,
        decommitment,
    })
}

/// **THE STAGE IN VERIFIER.** Every geometry from its own statement; the
/// claim on `B_in` is COMPUTED here from the terminals and carried to block
/// 0's stage, never read from a frame.
#[allow(clippy::too_many_arguments)]
pub(crate) fn verify(
    lay: &StageLayout,
    tp: &TokenProfile,
    tables: &TokenTables,
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
        return Err("token I/O: stage IN's segment parts are not the run schedule's".into());
    }
    super::super::hash_domain::paths_are_the_tree_depth("stage IN A", &params, &seg.a_open)?;
    super::super::hash_domain::paths_are_the_tree_depth("stage IN H", &params, &seg.h_open)?;
    super::super::hash_domain::mask_paths_are_the_tree_depth(&seg.mask_open)?;
    let ep_params = ep_spec.params();
    super::super::hash_domain::paths_are_the_tree_depth("input token endpoint", &ep_params, &seg.closes[0])?;
    let b_root = seg.b_root.ok_or("token I/O: stage IN's segment carries no B_in root")?;
    // the run's stage locality words (the block run's own two labels):
    // stage 0, whose public words are the embedding table
    tr.absorb_u64(b"pb-run-stage", 0);
    tr.absorb(b"pb-run-block", &tp.emb_digest);
    protocol::absorb_root(tr, b"B", &b_root, b_spec.commitment_rows(), b_spec.log_n());
    protocol::absorb_root(tr, b"A", &seg.a_root, lay.a_rows, lay.log_n);
    tr.absorb(b"M", &seg.mask_root);
    let (beta, alpha, g_emb, r_emb, ef) = challenges(tr, tp, tables);
    let tau_tab = tau_table(tp, &ef, beta, g_emb);
    protocol::absorb_root(tr, b"H", &seg.h_root, lay.h_rows, lay.log_n);
    let ep_data_rows = ep_spec.data_rows();
    let cx = InCtx { lay, tp, alpha, beta, g_emb, r_emb, tau_tab, b_in_row: b_spec.mask_row(0)?, b_in_log: (tp.t_pad * tp.d_pad).trailing_zeros() as usize, ep_mask_row: ep_data_rows };
    let mut side = Side::Verify { slots: &seg.slots };
    let acc = run_slots(&mut side, &cx, tr)?;
    // TOKEN I/O (round 7; capture request 2.2): every opening of the stage
    // wrapped as `protocol::verify_core` wraps a block's (checkpoint after
    // the schedule check, the hook after the verification; no-ops unless a
    // recorder is attached)
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    crate::zk::mask_verify_tagged(&seg.mask_root, &lay.mask_specs(), &acc.fs, &seg.mask_open, ntt, tr, tag).map_err(|e| format!("stage IN M: {e}"))?;
    #[cfg(test)]
    super::super::run_capture::mask(&lay.mask_specs(), &seg.mask_root, &acc.fs, &seg.mask_open, ntt, rc_before, tr);
    let [ac, mut hc, ic, oc] = acc.claims;
    hc.push(lay.logup_sum_claim());
    protocol::check_opening(&ac, lay.log_n, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, A_GROUPS, tr)?;
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.a_root, lay.a_rows, lay.log_n), &ac, &seg.a_open, ntt, tr, tag).map_err(|e| format!("stage IN A: {e}"))?;
    #[cfg(test)]
    super::super::run_capture::pcs(capture_a_geom("A-in", "stage-in", lay, seg.a_root), &ac, &seg.a_open, ntt, rc_before, tr);
    protocol::check_opening(&hc, lay.log_n, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, H_GROUPS, tr)?;
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.h_root, lay.h_rows, lay.log_n), &hc, &seg.h_open, ntt, tr, tag).map_err(|e| format!("stage IN H (the LogUp sum claim is part of this opening): {e}"))?;
    #[cfg(test)]
    super::super::run_capture::pcs(capture_h_geom("H-in", "stage-in", lay, seg.h_root), &hc, &seg.h_open, ntt, rc_before, tr);
    check_token_endpoint_opening(&ic, ep_data_rows, tp.tier.ep_n(), tr)?;
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&ep_params, &ZkOpts::standard(&ep_params), &protocol::commitment(*ep_root, ep_spec.commitment_rows(), tp.tier.ep_log_n), &ic, &seg.closes[0], ntt, tr, tag).map_err(|e| format!("input token endpoint: {e}"))?;
    #[cfg(test)]
    super::super::run_capture::pcs(capture_ep_geom("E-token-in", ep_spec, *ep_root, vec![(0, SI_IO, ic.len())]), &ic, &seg.closes[0], ntt, rc_before, tr);
    Ok((oc, b_root))
}

/// TOKEN I/O (round 7): stage IN's plane table for the run capture (the
/// plane names are this module's constants, in plane order)
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

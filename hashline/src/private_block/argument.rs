//! The eighteen masked sumchecks of the private block profile, written
//! ONCE and driven from both sides (`Side::Prove` / `Side::Verify`): the slot
//! order, every challenge, every table, every polynomial, every PCS claim and
//! every M functional come from the same code, so the two sides cannot build
//! different claim lists.
//!
//! One slot, both sides:
//!   absorb slot index -> draw c (zero: refuse) -> absorb the ONE published
//!   scalar (`s + c G` for a private sum, `c G` for a public-zero slot, the
//!   batched `Gamma_host` for a host) -> masked rounds -> one extension round
//!   per private factor family (two for the bilinear score / PV slots) ->
//!   absorb the masked terminals.
//! The verifier never sees a plane evaluation, a claimed scalar sum, a helper
//! sum or a histogram: terminals are `(1 - e) T(p) + e (R_re + u R_im)(tail p)`
//! with a pair reserved for that one site, and the mask evaluation g(rho) it
//! derives is closed by the single M opening.
//!
//! CONSTRUCTION PREMISE (not re-derived here): every slot polynomial has a
//! public factor (an eq, a public table, or the other side's zero extension)
//! in every monomial, so `poly(extensions) = 0` and the extension round is
//! consistent. `define` is written to keep that true; a new term without a
//! public factor would make honest proofs fail, not leak.

use super::layout::*;
use super::AttentionPublic;
use crate::field::{Fp, Fp2};
use crate::mle::{eq_point, eq_table_msb, eval_mle_ext, fold_rows_i8};
use crate::pcs::{Slice, ZClaim, ZPart};
use crate::sumcheck::{self, masked_terminal, CfsMask, SumcheckProof};
use crate::transcript::Transcript;
use crate::zk::{extension, masked_prove, MaskFunctional};

/// which hiding commitment a private table lives in
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Cm {
    A = 0,
    H = 1,
    In = 2,
    Out = 3,
}

/// one coordinate of a plane's claim point, as a function of the slot's challenges
#[derive(Clone, Debug)]
pub(crate) enum Coord {
    Rho(usize),
    /// `1 - rho_k` (the RoPE partner half)
    Flip(usize),
    Fixed(Fp2),
}

pub(crate) struct Priv {
    pub cm: Cm,
    /// (element offset, coefficient): one slice for A, (re, 1) and (im, u) for H
    pub slices: Vec<(usize, Fp2)>,
    pub log: usize,
    pub coords: Vec<Coord>,
    /// the site's reserved pair is rows (mask_row, mask_row + 1)
    pub mask_row: usize,
    /// the extension round that masks this table (the bilinear slots have two)
    pub ext_round: usize,
}

pub(crate) enum Tab {
    /// eq(point, x[start .. start + |point|]), constant in the other variables
    Eq { point: Vec<Fp2>, start: usize },
    Pub(Vec<Fp2>),
    Priv(Priv),
}

pub(crate) type Poly = Box<dyn Fn(&[Fp2]) -> Fp2 + Send + Sync>;

pub(crate) struct SlotDef {
    pub slot: usize,
    pub tabs: Vec<Tab>,
    pub poly: Poly,
    /// (hosted private slot, nu * kappa)
    pub hosted: Vec<(usize, Fp2)>,
}

#[derive(Clone, Debug, Default)]
pub(crate) struct SlotProof {
    /// the ONE published scalar of the slot (always mask-bearing)
    pub scalar: Fp2,
    pub sc: SumcheckProof,
    /// the masked terminals of the private tables, in table order
    pub terms: Vec<Fp2>,
}

pub(crate) struct ProverData<'a> {
    /// committed data of A, H, the input endpoint, the output endpoint
    pub data: [&'a [Fp]; 4],
    pub masks: &'a [CfsMask],
}

pub(crate) enum Side<'a> {
    Prove { pd: ProverData<'a>, out: Vec<SlotProof> },
    Verify { slots: &'a [SlotProof] },
}

#[derive(Default)]
pub(crate) struct Acc {
    pub cs: Vec<Fp2>,
    pub scalars: Vec<Fp2>,
    /// claims per commitment, indexed by `Cm`
    pub claims: [Vec<ZClaim>; 4],
    pub fs: Vec<MaskFunctional>,
    pub host_fs: Vec<MaskFunctional>,
    /// the absorb sequence, label by label (prover and verifier must agree)
    pub order: Vec<String>,
}

pub(crate) struct Ctx<'a> {
    pub lay: &'a Layout,
    pub public: &'a AttentionPublic,
    pub alpha: Fp2,
    pub beta: Fp2,
    pub g_u8: Fp2,
    pub g_exp: Fp2,
}

#[derive(Default)]
pub(crate) struct Points {
    r_t: Vec<Fp2>,
    p_ht: Vec<Fp2>,
    lam_z: Fp2,
    r_q: Vec<Fp2>,
    pq: Vec<Fp2>,
    pk: Vec<Fp2>,
    pv: Vec<Fp2>,
    p_s: Vec<Fp2>,
    p_o: Vec<Fp2>,
    p_a: Vec<Fp2>,
}

// ---------------------------------------------------------------- tables

fn claim_point(p: &Priv, rho: &[Fp2]) -> Vec<Fp2> {
    p.coords
        .iter()
        .map(|c| match c {
            Coord::Rho(k) => rho[*k],
            Coord::Flip(k) => Fp2::ONE.sub(rho[*k]),
            Coord::Fixed(f) => *f,
        })
        .collect()
}

/// T(x) = plane~(point(x)) over the slot's boolean domain: multilinear in x
/// because every challenge index occurs at most once among the coordinates.
fn priv_table(p: &Priv, data: &[Fp], n_vars: usize) -> Vec<Fp2> {
    let fixed: Vec<Fp2> = p.coords.iter().filter_map(|c| if let Coord::Fixed(f) = c { Some(*f) } else { None }).collect();
    let eqf = eq_table_msb(&fixed);
    let mut used = 0usize;
    for c in &p.coords {
        if let Coord::Rho(k) | Coord::Flip(k) = c {
            used |= 1usize << (n_vars - 1 - *k);
        }
    }
    let mut out = vec![Fp2::ZERO; 1usize << n_vars];
    for idx in 0..1usize << p.log {
        let (mut x, mut z) = (0usize, 0usize);
        for (j, c) in p.coords.iter().enumerate() {
            let b = (idx >> (p.log - 1 - j)) & 1;
            match c {
                Coord::Rho(k) => x |= b << (n_vars - 1 - *k),
                Coord::Flip(k) => x |= (1 - b) << (n_vars - 1 - *k),
                Coord::Fixed(_) => z = (z << 1) | b,
            }
        }
        let mut v = Fp2::ZERO;
        for (off, coef) in &p.slices {
            v = v.add(coef.mul_base(data[*off + idx]));
        }
        out[x] = out[x].add(eqf[z].mul(v));
    }
    // broadcast over the variables the plane does not depend on
    for x in 0..out.len() {
        if x & !used != 0 {
            out[x] = out[x & used];
        }
    }
    out
}

fn table_of(tab: &Tab, n_vars: usize, pd: &ProverData) -> Vec<Fp2> {
    match tab {
        Tab::Eq { point, start } => {
            let e = eq_table_msb(point);
            let shift = n_vars - *start - point.len();
            (0..1usize << n_vars).map(|x| e[(x >> shift) & (e.len() - 1)]).collect()
        }
        Tab::Pub(v) => v.clone(),
        Tab::Priv(p) => priv_table(p, pd.data[p.cm as usize], n_vars),
    }
}

/// the mask pair's value at the claim's column tail
fn mask_eval(p: &Priv, data: &[Fp], point: &[Fp2]) -> Fp2 {
    let logm = p.log.min(LOG_N);
    let c0 = if p.log < LOG_N { p.slices[0].0 % N } else { 0 };
    let eq = eq_table_msb(&point[p.log - logm..]);
    let row = |r: usize| {
        data[r * N + c0..r * N + c0 + eq.len()].iter().zip(eq.iter()).fold(Fp2::ZERO, |a, (x, e)| a.add(e.mul_base(*x)))
    };
    row(p.mask_row).add(Fp2::U.mul(row(p.mask_row + 1)))
}

/// `cd * plane~(point) + cm * (R_re + u R_im)(tail point)`: data parts then the reserved pair
fn build_claim(p: &Priv, point: &[Fp2], cd: Fp2, cm: Fp2, value: Fp2) -> ZClaim {
    let logm = p.log.min(LOG_N);
    let c0 = if p.log < LOG_N { p.slices[0].0 % N } else { 0 };
    let tail = point[p.log - logm..].to_vec();
    let mut parts: Vec<ZPart> = p
        .slices
        .iter()
        .map(|(off, coef)| ZPart { slice: Slice { offset: *off, log_size: p.log as u32 }, coef: coef.mul(cd), point: point.to_vec() })
        .collect();
    for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
        parts.push(ZPart { slice: Slice { offset: (p.mask_row + k) * N + c0, log_size: logm as u32 }, coef: cm.mul(u), point: tail.clone() });
    }
    ZClaim { parts, value }
}

fn total(tables: &[Vec<Fp2>], poly: &Poly) -> Fp2 {
    let mut row = vec![Fp2::ZERO; tables.len()];
    let mut acc = Fp2::ZERO;
    for x in 0..tables[0].len() {
        for (r, t) in row.iter_mut().zip(tables.iter()) {
            *r = t[x];
        }
        acc = acc.add(poly(&row));
    }
    acc
}

fn sum_weights(slot: usize) -> Vec<Fp2> {
    let (n, e, d) = SLOTS[slot];
    CfsMask::sum_weights(n + e, d)
}

// ---------------------------------------------------------------- one slot

pub(crate) fn run_slot(side: &mut Side, acc: &mut Acc, def: SlotDef, tr: &mut Transcript) -> Result<(), String> {
    let s = def.slot;
    let (n, ext, degree) = SLOTS[s];
    let kind = SLOT_KINDS[s];
    let n_priv = def.tabs.iter().filter(|t| matches!(t, Tab::Priv(_))).count();
    if s != acc.cs.len() || n_priv != slot_terms(s) || (kind == SlotKind::Host) == def.hosted.is_empty() {
        return Err(format!("private block: slot {s} differs from the declared schedule"));
    }
    if def.tabs.iter().any(|t| matches!(t, Tab::Priv(p) if p.ext_round >= ext || p.coords.len() != p.log)) {
        return Err(format!("private block: slot {s} table shape"));
    }
    tr.absorb_u64(b"pb-slot", s as u64);
    acc.order.push(format!("slot {s:02} begin"));
    // A zero multiplier would publish the unmasked scalar and rounds. Refusals are
    // functions of challenges only and are never resampled on the same transcript.
    let c = tr.challenge_fp2();
    if c.is_zero() {
        return Err("zero CFS mask challenge; discard attempt".into());
    }
    let (scalar, rho, es, terms, g_val) = match side {
        Side::Prove { pd, out } => {
            let mut tables: Vec<Vec<Fp2>> = def.tabs.iter().map(|t| table_of(t, n, pd)).collect();
            if tables.iter().any(|t| t.len() != 1usize << n) {
                return Err(format!("private block: slot {s} table length"));
            }
            let mask = &pd.masks[s];
            let scalar = match kind {
                SlotKind::Private => total(&tables, &def.poly).add(c.mul(mask.total())),
                SlotKind::Standalone => c.mul(mask.total()),
                SlotKind::Host => def.hosted.iter().fold(c.mul(mask.total()), |g, (hs, coef)| g.sub(coef.mul(acc.cs[*hs]).mul(pd.masks[*hs].total()))),
            };
            tr.absorb_fp2(b"pb-scalar", &[scalar]);
            let poly = |v: &[Fp2]| (def.poly)(v);
            let (mut rounds, rho, finals) = masked_prove(&mut tables, degree, &poly, mask, c, tr);
            let mut cur = finals;
            let mut prev = rho.clone();
            for m in 0..ext {
                let exts: Vec<Fp2> = def
                    .tabs
                    .iter()
                    .map(|t| match t {
                        Tab::Priv(p) if p.ext_round == m => mask_eval(p, pd.data[p.cm as usize], &claim_point(p, &rho)),
                        _ => Fp2::ZERO,
                    })
                    .collect();
                let e = extension(&cur, &exts, degree, &poly, mask, c, &prev, &mut rounds, tr);
                for (v, x) in cur.iter_mut().zip(exts.iter()) {
                    *v = masked_terminal(*v, *x, e);
                }
                prev.push(e);
            }
            let terms: Vec<Fp2> = def.tabs.iter().zip(cur.iter()).filter(|(t, _)| matches!(t, Tab::Priv(_))).map(|(_, v)| *v).collect();
            let g_val = mask.eval(&prev);
            let es = prev[n..].to_vec();
            out.push(SlotProof { scalar, sc: SumcheckProof { rounds }, terms: terms.clone() });
            (scalar, rho, es, terms, g_val)
        }
        Side::Verify { slots } => {
            let sp = slots.get(s).ok_or("private block: missing slot")?;
            if sp.terms.len() != n_priv {
                return Err(format!("private block: slot {s} terminal count"));
            }
            tr.absorb_fp2(b"pb-scalar", &[sp.scalar]);
            let claimed = def.hosted.iter().fold(sp.scalar, |a, (hs, coef)| a.add(coef.mul(acc.scalars[*hs])));
            let (fin, rho_full) = sumcheck::verify(claimed, degree, n + ext, &sp.sc, tr).map_err(|e| format!("slot {s} [{}]: {e}", SLOT_NAMES[s]))?;
            let rho = rho_full[..n].to_vec();
            let es = rho_full[n..].to_vec();
            let sel = es.iter().fold(Fp2::ONE, |a, e| a.mul(Fp2::ONE.sub(*e)));
            let mut k = 0usize;
            let vals: Vec<Fp2> = def
                .tabs
                .iter()
                .map(|t| match t {
                    Tab::Eq { point, start } => sel.mul(eq_point(point, &rho[*start..*start + point.len()])),
                    Tab::Pub(v) => sel.mul(eval_mle_ext(v, &rho)),
                    Tab::Priv(_) => {
                        k += 1;
                        sp.terms[k - 1]
                    }
                })
                .collect();
            let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());
            (sp.scalar, rho, es, sp.terms.clone(), g_val)
        }
    };
    acc.order.push(format!("slot {s:02} scalar+rounds"));
    // A zero terminal challenge would open an unmasked evaluation; (1 - e) = 0 would
    // detach the claim from the data. Both are refused, never redrawn.
    if es.iter().any(|e| e.is_zero() || *e == Fp2::ONE) {
        return Err("degenerate terminal mask challenge; discard attempt".into());
    }
    tr.absorb_fp2(b"pb-term", &terms);
    acc.order.push(format!("slot {s:02} terminals"));
    let cd = es.iter().fold(Fp2::ONE, |a, e| a.mul(Fp2::ONE.sub(*e)));
    let mut k = 0usize;
    for t in &def.tabs {
        if let Tab::Priv(p) = t {
            let cm = es[p.ext_round + 1..].iter().fold(es[p.ext_round], |a, e| a.mul(Fp2::ONE.sub(*e)));
            acc.claims[p.cm as usize].push(build_claim(p, &claim_point(p, &rho), cd, cm, terms[k]));
            k += 1;
        }
    }
    // M functionals, in the declared order: [Gamma_s if standalone] eval_s; host Gammas last
    let mut rho_full = rho;
    rho_full.extend_from_slice(&es);
    match kind {
        SlotKind::Standalone => acc.fs.push(MaskFunctional { terms: vec![(s, sum_weights(s).iter().map(|w| w.mul(c)).collect())], value: scalar }),
        SlotKind::Host => {
            let mut terms = vec![(s, sum_weights(s).iter().map(|w| w.mul(c)).collect::<Vec<Fp2>>())];
            for (hs, coef) in &def.hosted {
                let k = coef.mul(acc.cs[*hs]).neg();
                terms.push((*hs, sum_weights(*hs).iter().map(|w| w.mul(k)).collect()));
            }
            acc.host_fs.push(MaskFunctional { terms, value: scalar });
        }
        SlotKind::Private => {}
    }
    acc.fs.push(MaskFunctional { terms: vec![(s, CfsMask::eval_weights(&rho_full, degree))], value: g_val });
    acc.cs.push(c);
    acc.scalars.push(scalar);
    Ok(())
}

// ---------------------------------------------------------------- slot definitions

struct B<'a> {
    lay: &'a Layout,
    slot: usize,
    tabs: Vec<Tab>,
    ak: usize,
    hk: usize,
}

fn rho(r: std::ops::Range<usize>) -> Vec<Coord> {
    r.map(Coord::Rho).collect()
}
fn fixed(p: &[Fp2]) -> Vec<Coord> {
    p.iter().map(|f| Coord::Fixed(*f)).collect()
}
fn cat(parts: &[&Vec<Fp2>]) -> Vec<Fp2> {
    parts.iter().flat_map(|p| p.iter().copied()).collect()
}

impl<'a> B<'a> {
    fn new(lay: &'a Layout, slot: usize) -> Self {
        B { lay, slot, tabs: Vec::new(), ak: 0, hk: 0 }
    }
    fn push(&mut self, t: Tab) -> usize {
        self.tabs.push(t);
        self.tabs.len() - 1
    }
    fn eq(&mut self, point: &[Fp2], start: usize) -> usize {
        self.push(Tab::Eq { point: point.to_vec(), start })
    }
    fn public(&mut self, v: Vec<Fp2>) -> usize {
        self.push(Tab::Pub(v))
    }
    fn a_slice(&mut self, off: usize, log: usize, coords: Vec<Coord>, ext_round: usize) -> Result<usize, String> {
        let mask_row = self.lay.a_site(self.slot, self.ak)?;
        self.ak += 1;
        Ok(self.push(Tab::Priv(Priv { cm: Cm::A, slices: vec![(off, Fp2::ONE)], log, coords, mask_row, ext_round })))
    }
    fn a_at(&mut self, plane: usize, coords: Vec<Coord>, ext_round: usize) -> Result<usize, String> {
        self.a_slice(self.lay.a_off[plane], a_dom(plane).log(), coords, ext_round)
    }
    /// an A plane on its own domain (the slot's domain)
    fn a(&mut self, plane: usize) -> Result<usize, String> {
        self.a_at(plane, rho(0..a_dom(plane).log()), 0)
    }
    /// the planes `first ..= last`, returning plane -> table index
    fn a_range(&mut self, first: usize, last: usize) -> Result<Vec<usize>, String> {
        let mut idx = vec![usize::MAX; N_A];
        for p in first..=last {
            idx[p] = self.a(p)?;
        }
        Ok(idx)
    }
    fn h(&mut self, plane: usize) -> Result<usize, String> {
        let mask_row = self.lay.h_site(self.slot, self.hk)?;
        self.hk += 1;
        let (re, im) = self.lay.h_off[plane];
        let log = h_dom(plane).log();
        Ok(self.push(Tab::Priv(Priv { cm: Cm::H, slices: vec![(re, Fp2::ONE), (im, Fp2::U)], log, coords: rho(0..log), mask_row, ext_round: 0 })))
    }
    /// a caller-fixed endpoint plane (private_seam geometry: data rows 0..2, pair rows 2..4)
    fn endpoint(&mut self, cm: Cm) -> usize {
        self.push(Tab::Priv(Priv { cm, slices: vec![(0, Fp2::ONE)], log: 9, coords: rho(0..9), mask_row: 2, ext_round: 0 }))
    }
    fn finish(self, poly: Poly, hosted: Vec<(usize, Fp2)>) -> Result<SlotDef, String> {
        if self.ak != A_SITES[self.slot] || self.hk != H_SITES[self.slot] {
            return Err(format!("private block: slot {} uses {} A / {} H sites, schedule declares {} / {}", self.slot, self.ak, self.hk, A_SITES[self.slot], H_SITES[self.slot]));
        }
        Ok(SlotDef { slot: self.slot, tabs: self.tabs, poly, hosted })
    }
}

/// a U8 lookup in table-index space: value = cst + sum coef * v[idx] (the tag folded into cst)
#[derive(Clone)]
struct LkT {
    terms: Vec<(usize, Fp)>,
    cst: Fp2,
}

fn lk_tables(dom: Dom, idx: &[usize], g_u8: Fp2) -> Vec<LkT> {
    lookups(dom)
        .into_iter()
        .map(|l| LkT { terms: l.terms.iter().map(|(p, c)| (idx[*p], Fp::from_i64(*c))).collect(), cst: Fp2::from_i64(l.cst).add(g_u8) })
        .collect()
}

/// sum_k mu_k * (the LogUp helper relation of helper k), helpers at tables h0, h0 + 1, ...
fn helper_sum(v: &[Fp2], lks: &[LkT], h0: usize, alpha: Fp2, mu: &[Fp2]) -> Fp2 {
    let den = |l: &LkT| alpha.sub(l.terms.iter().fold(l.cst, |a, (i, c)| a.add(v[*i].mul_base(*c))));
    let mut acc = Fp2::ZERO;
    for k in 0..lks.len().div_ceil(2) {
        let h = v[h0 + k];
        let d1 = den(&lks[2 * k]);
        let rel = match lks.get(2 * k + 1) {
            Some(l2) => {
                let d2 = den(l2);
                h.mul(d1).mul(d2).sub(d1.add(d2))
            }
            None => h.mul(d1).sub(Fp2::ONE),
        };
        acc = acc.add(mu[k].mul(rel));
    }
    acc
}

fn nonzero(v: Vec<Fp2>) -> Result<Vec<Fp2>, String> {
    if v.iter().any(|x| x.is_zero()) {
        return Err("zero batching challenge; discard attempt".into());
    }
    Ok(v)
}

fn k(v: i64) -> Fp2 {
    Fp2::from_i64(v)
}

/// the causal support: 1 on j <= t, (h, t, j) order
pub(crate) fn causal_mask() -> Vec<Fp2> {
    (0..H * T * T).map(|x| if x % T <= (x / T) % T { Fp2::ONE } else { Fp2::ZERO }).collect()
}

/// (C, S') with out = C * x + S' * x_partner, over `heads` heads per row
fn rope_tables(public: &AttentionPublic, heads: usize) -> (Vec<Fp2>, Vec<Fp2>) {
    let width = heads * DH;
    let mut c = Vec::with_capacity(T * width);
    let mut s = Vec::with_capacity(T * width);
    for x in 0..T * width {
        let (t, i) = (x / width, x % DH);
        let at = t * HALF + i % HALF;
        c.push(k(public.rope_cos[at]));
        s.push(k(if i < HALF { -public.rope_sin[at] } else { public.rope_sin[at] }));
    }
    (c, s)
}

pub(crate) fn table_values_u8(g_u8: Fp2) -> Vec<Fp2> {
    (0..N as i64).map(|i| k(i).add(g_u8)).collect()
}
pub(crate) fn table_values_exp(public: &AttentionPublic, beta: Fp2, g_exp: Fp2) -> Vec<Fp2> {
    (0..N).map(|i| k(i as i64).add(beta.mul(k(public.exp[i]))).add(g_exp)).collect()
}

/// Draw the slot's challenges and build its tables and polynomial. Identical on both sides.
pub(crate) fn define(slot: usize, ctx: &Ctx, pts: &mut Points, tr: &mut Transcript) -> Result<SlotDef, String> {
    let lay = ctx.lay;
    let (alpha, beta, g_u8, g_exp) = (ctx.alpha, ctx.beta, ctx.g_u8, ctx.g_exp);
    let mut b = B::new(lay, slot);
    let (p1, p2, p3) = (pow256(1), pow256(2), pow256(3));
    match slot {
        SC_SS => {
            pts.r_t = tr.challenge_fp2_vec(5);
            b.eq(&pts.r_t, 0);
            b.a(A_X)?;
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1]).mul(v[1])), vec![])
        }
        SC_TZC => {
            let tau = tr.challenge_fp2_vec(5);
            let mu = tr.challenge_fp2_vec(3);
            let nu = nonzero(tr.challenge_fp2_vec(1))?[0];
            b.eq(&tau, 0);
            b.eq(&pts.r_t, 0);
            b.a(A_D)?;
            b.a(A_DSQ)?;
            for kk in 0..N_LIMBS {
                b.a_slice(lay.limb_off(kk), 5, rho(0..5), 0)?;
            }
            let poly = move |v: &[Fp2]| {
                let l3 = |o: usize| v[o].add(v[o + 1].mul(p1)).add(v[o + 2].mul(p2));
                let (d, dsq, dl, a1, a2) = (v[2], v[3], l3(4), l3(7), l3(10));
                let zc = mu[0].mul(dsq.sub(d.mul(d))).add(mu[1].mul(d.sub(dl))).add(mu[2].mul(d.double().sub(a1).sub(a2)));
                v[0].mul(zc).add(nu.mul(v[1]).mul(dsq.add(a1).sub(k(NORM_CEPS))))
            };
            b.finish(Box::new(poly), vec![(SC_SS, nu)])
        }
        SC_LZC => {
            let tau = tr.challenge_fp2_vec(9);
            b.eq(&tau, 0);
            let idx = b.a_range(A_LIMB, A_LIMB)?;
            let h0 = b.h(H_L)?;
            let lks = lk_tables(Dom::L, &idx, g_u8);
            b.finish(Box::new(move |v: &[Fp2]| v[0].mul(helper_sum(v, &lks, h0, alpha, &[Fp2::ONE]))), vec![])
        }
        SC_RS => {
            pts.p_ht = tr.challenge_fp2_vec(6);
            pts.lam_z = tr.challenge_fp2();
            let lam = pts.lam_z;
            b.eq(&pts.p_ht, 0);
            b.public(causal_mask());
            b.a(A_E)?;
            b.a(A_ZSEL)?;
            b.finish(Box::new(move |v: &[Fp2]| v[0].mul(v[1].mul(v[2]).add(lam.mul(v[3])))), vec![])
        }
        SC_QMM | SC_KMM | SC_VMM | SC_WO => {
            if slot == SC_QMM || slot == SC_WO {
                pts.r_q = tr.challenge_fp2_vec(5);
            }
            let (plane, w, outer): (usize, &[i8], usize) = match slot {
                SC_QMM => (A_Y, ctx.public.wq.as_slice(), D),
                SC_KMM => (A_Y, ctx.public.wk.as_slice(), KV),
                SC_VMM => (A_Y, ctx.public.wv.as_slice(), KV),
                _ => (A_O8, ctx.public.wo.as_slice(), D),
            };
            let r_j = tr.challenge_fp2_vec(outer.trailing_zeros() as usize);
            let point = cat(&[&pts.r_q, &r_j]);
            let mut coords = fixed(&pts.r_q);
            coords.extend(rho(0..4));
            b.a_at(plane, coords, 0)?;
            // w is (output j, input i): sum_j eq(r_j, j) w[j, i]
            b.public(fold_rows_i8(w, outer, D, &eq_table_msb(&r_j)));
            match slot {
                SC_QMM => pts.pq = point,
                SC_KMM => pts.pk = point,
                SC_VMM => pts.pv = point,
                _ => pts.p_a = point,
            }
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1])), vec![])
        }
        SC_SCORE => {
            let r_h = tr.challenge_fp2_vec(1);
            let r_t = tr.challenge_fp2_vec(5);
            let r_j = tr.challenge_fp2_vec(5);
            pts.p_s = cat(&[&r_h, &r_t, &r_j]);
            // two private factors: qr is masked in extension round 0, kr in round 1
            let mut cq = fixed(&cat(&[&r_t, &r_h]));
            cq.extend(rho(0..3));
            b.a_at(A_QR8, cq, 0)?;
            let mut ck = fixed(&r_j);
            ck.extend(rho(0..3));
            b.a_at(A_KR8, ck, 1)?;
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1])), vec![])
        }
        SC_PV => {
            let r_h = tr.challenge_fp2_vec(1);
            let r_t = tr.challenge_fp2_vec(5);
            let r_i = tr.challenge_fp2_vec(3);
            pts.p_o = cat(&[&r_t, &r_h, &r_i]);
            let mut cp = fixed(&cat(&[&r_h, &r_t]));
            cp.extend(rho(0..5));
            b.a_at(A_P, cp, 0)?;
            let mut cv = rho(0..5);
            cv.extend(fixed(&r_i));
            b.a_at(A_V8, cv, 1)?;
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1])), vec![])
        }
        SC_DZC => {
            let tau = tr.challenge_fp2_vec(9);
            let mu = tr.challenge_fp2_vec(6 + helpers(Dom::D).1);
            let nu = nonzero(tr.challenge_fp2_vec(1))?[0];
            b.eq(&tau, 0);
            b.eq(&pts.p_a, 0);
            let ig = b.public((0..T * D).map(|x| k(i64::from(ctx.public.gamma_a[x % D]))).collect());
            let idx = b.a_range(A_X, A_X1L1)?;
            let id = b.a_slice(lay.a_off[A_D], 5, rho(0..5), 0)?;
            let h0 = b.h(H_D0)?;
            for j in 1..helpers(Dom::D).1 {
                b.h(H_D0 + j)?;
            }
            let lks = lk_tables(Dom::D, &idx, g_u8);
            let (k_num, k_dv, k_den) = (k(2 * NORM_CN), k(1 << NORM_TN), k(1 << (NORM_TN + 1)));
            let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let l4 = |o: usize| at(o).add(at(o + 1).mul(p1)).add(at(o + 2).mul(p2)).add(at(o + 3).mul(p3));
                let l2 = |o: usize| at(o).add(at(o + 1).mul(p1));
                let (x, y, ao, x1, d) = (at(A_X), at(A_Y), at(A_AO), at(A_X1), v[id]);
                let (nr, ns) = (l4(A_NR0), l4(A_NS0));
                let c0 = k_num.mul(v[ig]).mul(x).add(k_dv.mul(d)).sub(k_den.mul(y).mul(d)).sub(nr);
                let c1 = ns.add(nr).add(Fp2::ONE).sub(k_den.mul(d));
                let c2 = x.add(k(32768)).sub(l2(A_XL0));
                let c3 = ao.add(k(32768)).sub(l2(A_AL0));
                let c4 = x1.add(k(32768)).sub(l2(A_X1L0));
                let c5 = x1.sub(x).sub(ao);
                let mut zc = helper_sum(v, &lks, h0, alpha, &mu[6..]);
                for (m, c) in mu.iter().zip([c0, c1, c2, c3, c4, c5]) {
                    zc = zc.add(m.mul(c));
                }
                let host = k(1 << SH_AO).mul(ao).add(at(A_RAL)).sub(k(1 << (SH_AO - 1)));
                v[0].mul(zc).add(nu.mul(v[1]).mul(host))
            };
            b.finish(Box::new(poly), vec![(SC_WO, nu)])
        }
        SC_QZC | SC_KVZC => {
            let q = slot == SC_QZC;
            let (dom, first, last, src, h_first) = if q { (Dom::Q, A_Q8, A_RO1, A_Q8, H_Q0) } else { (Dom::Kv, A_K8, A_RKRL, A_K8, H_KV0) };
            let log = dom.log();
            let tau = tr.challenge_fp2_vec(log);
            let mu = tr.challenge_fp2_vec(1 + helpers(dom).1);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            b.eq(&tau, 0);
            b.eq(if q { &pts.pq } else { &pts.pk }, 0);
            b.eq(if q { &pts.p_o } else { &pts.pv }, 0);
            let (ct, st) = rope_tables(ctx.public, if q { H } else { 1 });
            let ic = b.public(ct);
            let is = b.public(st);
            let idx = b.a_range(first, last)?;
            // the partner half: the most significant bit of i' flipped (its own site, its own pair)
            let mut cf = rho(0..log);
            cf[log - 3] = Coord::Flip(log - 3);
            let iflip = b.a_at(src, cf, 0)?;
            let h0 = b.h(h_first)?;
            for j in 1..helpers(dom).1 {
                b.h(h_first + j)?;
            }
            let lks = lk_tables(dom, &idx, g_u8);
            let half = k(1 << (SH_QKV - 1));
            let hosted = if q { vec![(SC_QMM, nu[0]), (SC_PV, nu[1])] } else { vec![(SC_KMM, nu[0]), (SC_VMM, nu[1])] };
            let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let (rot, rot_rem) = if q { (at(A_QR8), at(A_RQRL)) } else { (at(A_KR8), at(A_RKRL)) };
                let rope = v[ic].mul(at(src)).add(v[is].mul(v[iflip])).sub(k(1 << SH_ROPE).mul(rot)).sub(rot_rem).add(k(1 << (SH_ROPE - 1)));
                let zc = mu[0].mul(rope).add(helper_sum(v, &lks, h0, alpha, &mu[1..]));
                let (host1, host2) = if q {
                    (
                        k(1 << SH_QKV).mul(at(A_Q8)).add(at(A_RQL)).sub(half),
                        k(1 << SH_O).mul(at(A_O8)).add(at(A_RO0)).add(at(A_RO1).mul(p1)).sub(k(1 << (SH_O - 1))),
                    )
                } else {
                    (k(1 << SH_QKV).mul(at(A_K8)).add(at(A_RKL)).sub(half), k(1 << SH_QKV).mul(at(A_V8)).add(at(A_RVL)).sub(half))
                };
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(host1)).add(nu[1].mul(v[2]).mul(host2))
            };
            b.finish(Box::new(poly), hosted)
        }
        SC_SZC => {
            let tau = tr.challenge_fp2_vec(11);
            let n_help = helpers(Dom::S).1;
            let mu = tr.challenge_fp2_vec(5 + n_help + 1);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            let lam = pts.lam_z;
            b.eq(&tau, 0);
            b.eq(&pts.p_ht, 0);
            b.eq(&pts.p_s, 0);
            let im = b.public(causal_mask());
            let idx = b.a_range(A_S8, A_SG1)?;
            let imx = b.a_slice(lay.a_off[A_MX], 6, rho(0..6), 0)?;
            let isum = b.a_slice(lay.a_off[A_SUM], 6, rho(0..6), 0)?;
            let h0 = b.h(H_S0)?;
            for j in 1..n_help {
                b.h(H_S0 + j)?;
            }
            let ihx = b.h(H_SEXP)?;
            let lks = lk_tables(Dom::S, &idx, g_u8);
            // the row-sum host term is constant in j: it sums to T * (Sum(p_ht) + lam_z)
            let hosted = vec![(SC_RS, nu[0].mul(k(T as i64))), (SC_SCORE, nu[1])];
            let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let (mask, s8, zsel, e, p, sum) = (v[im], at(A_S8), at(A_ZSEL), at(A_E), at(A_P), v[isum]);
                let sr = at(A_SR0).add(at(A_SR1).mul(p1));
                // delta = max - masked score, the masked score being mask * (s8 + 127) - 127
                let delta = v[imx].sub(mask.mul(s8.add(k(-MASK_SCORE)))).add(k(-MASK_SCORE));
                let c0 = zsel.mul(zsel).sub(zsel);
                let c1 = zsel.mul(delta);
                let c2 = k(1 << F_P).mul(mask).mul(e).sub(p.mul(sum)).sub(sr);
                let c3 = at(A_SG0).add(at(A_SG1).mul(p1)).add(sr).add(Fp2::ONE).sub(sum);
                let c4 = p.sub(at(A_PL0)).sub(at(A_PL1).mul(p1));
                let cx = v[ihx].mul(alpha.sub(delta.add(beta.mul(e)).add(g_exp))).sub(Fp2::ONE);
                let mut zc = helper_sum(v, &lks, h0, alpha, &mu[5..5 + n_help]).add(mu[5 + n_help].mul(cx));
                for (m, c) in mu.iter().zip([c0, c1, c2, c3, c4]) {
                    zc = zc.add(m.mul(c));
                }
                let host_rs = sum.add(lam);
                let host_s = k(1 << SH_S).mul(s8).add(at(A_RSL)).sub(k(1 << (SH_S - 1)));
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(host_rs)).add(nu[1].mul(v[2]).mul(host_s))
            };
            b.finish(Box::new(poly), hosted)
        }
        SC_TAB => {
            let tau = tr.challenge_fp2_vec(8);
            let mu = tr.challenge_fp2_vec(2);
            b.eq(&tau, 0);
            b.a(A_MU8)?;
            b.h(H_GU8)?;
            b.public(table_values_u8(g_u8));
            b.a(A_MEXP)?;
            b.h(H_GEXP)?;
            b.public(table_values_exp(ctx.public, beta, g_exp));
            let poly = move |v: &[Fp2]| {
                let r0 = v[2].mul(alpha.sub(v[3])).sub(v[1]);
                let r1 = v[5].mul(alpha.sub(v[6])).sub(v[4]);
                v[0].mul(mu[0].mul(r0).add(mu[1].mul(r1)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SC_ZS => {
            b.public(vec![Fp2::ONE; N]);
            b.h(H_U)?;
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1])), vec![])
        }
        SC_IO_IN | SC_IO_OUT => {
            let tau = tr.challenge_fp2_vec(9);
            b.eq(&tau, 0);
            b.a(if slot == SC_IO_IN { A_X } else { A_X1 })?;
            b.endpoint(if slot == SC_IO_IN { Cm::In } else { Cm::Out });
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1].sub(v[2]))), vec![])
        }
        _ => Err("private block: unknown slot".into()),
    }
}

/// All eighteen slots in the declared order, then the functional list in the declared order.
pub(crate) fn argument(side: &mut Side, ctx: &Ctx, tr: &mut Transcript) -> Result<Acc, String> {
    let mut acc = Acc::default();
    let mut pts = Points::default();
    for slot in 0..N_SLOTS {
        let def = define(slot, ctx, &mut pts, tr)?;
        run_slot(side, &mut acc, def, tr)?;
    }
    let hosts = std::mem::take(&mut acc.host_fs);
    acc.fs.extend(hosts);
    if acc.fs.len() != N_FUNCTIONALS {
        return Err("private block: functional count differs from the declared schedule".into());
    }
    Ok(acc)
}

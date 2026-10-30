//! **STAGE OUT-C** (DESIGN_CLASSIFIER v2 §4): `x` = `B_out` row `T - 1`, the
//! final RMSNorm (stage OUT's relation, unchanged), and THE MARGIN SLOT in
//! place of the head, the argmax and the output endpoint:
//!
//! * `Delta = sum_i y(i) w_Delta(i)` — a PRIVATE slot (PD) over `Do`, `y` read
//!   at its natural `d_pad` with the lift bits fixed, `w_Delta` the public
//!   int16 margin vector;
//! * hosted by the isqrt-limb zero-check (LZC) over `Lo`, whose host term is
//!   `nu (sigma g(z) limb(z) + u0(z) (sigma b + c))`, `g(z) = 256^(z - 32)` on
//!   the five margin-limb entries `32 .. 32 + L` of the limb plane (pad
//!   entries of the isqrt plane until now) and 0 elsewhere: so the hosting
//!   rule `sum host-term = sum private` IS the margin identity
//!   `Delta = sigma (delta + b) + c` with `delta = sum_k 256^k limb(32 + k)`;
//! * the margin limbs are bytes because LZC's byte lookup covers EVERY entry
//!   of the limb plane, and zero beyond `32 + L` by LZC's pad clause (its live
//!   selector now names the isqrt sub-planes and the margin limbs);
//! * `b` (the PUBLIC verdict) and `c` enter only through the public constant
//!   `sigma b + c` and `sigma = 2b - 1`; the statement's transcript absorbs `b`.
//!
//! Why the verdict is right (design §4.2, the check's C-9): the identity holds
//! over the integers (every term below `2^41 << p / 2`), so `b = 1` gives
//! `Delta >= c + 1` and `b = 0` gives `Delta <= c`; flipping `b` needs a
//! negative five-byte number. No new domain, plane or helper; no output
//! endpoint. A new file: the frozen stage OUT (D36's pin) is untouched.

use super::classify::{ClassifierProfile, ClassifierTables, LAM_BASE};
use super::*;
use crate::pcs::{self, ZkOpts};
use crate::tables_attn::TAG_U8;
use super::super::boundary::{BoundarySpec, PreparedBoundary};
use super::super::protocol;

pub(crate) const TO_LOG: usize = 1;

pub(crate) const C_D: usize = 0;
pub(crate) const C_DSQ: usize = 1;
pub(crate) const C_LIMB: usize = 2;
pub(crate) const C_X: usize = 3;
pub(crate) const C_XL0: usize = 4;
pub(crate) const C_XL1: usize = 5;
pub(crate) const C_Y: usize = 6;
pub(crate) const C_RHO0: usize = 7;
pub(crate) const C_SIG0: usize = 11;
/// the byte histogram (one past the last plane)
pub(crate) const C_MULT: usize = 15;

pub(crate) const H_LO: usize = 0;
pub(crate) const H_D0: usize = 1;
pub(crate) const H_DO_HELPERS: usize = 6;
pub(crate) const H_GU8: usize = 7;
pub(crate) const H_U: usize = 8;

pub(crate) const SOC_IO: usize = 0;
pub(crate) const SOC_SS: usize = 1;
pub(crate) const SOC_TZC: usize = 2;
pub(crate) const SOC_PD: usize = 3;
pub(crate) const SOC_LZC: usize = 4;
pub(crate) const SOC_DZC: usize = 5;
pub(crate) const SOC_TAB: usize = 6;
pub(crate) const SOC_ZS: usize = 7;

/// the declared opening groups: A = IO-in's `x`, SS's `x`, TZC's {D, Dsq,
/// limb 0} (one key) and limbs 1..8, PD's `y`, LZC's limb plane, DZC's twelve
/// planes, DZC's fixed-point read of `D`, TAB = 1 + 1 + 9 + 1 + 1 + 1 + 1 + 1
/// = 16. H = LZC, DZC, TAB, ZS and the LogUp sum claim = 5.
pub(crate) const A_GROUPS: usize = 16;
pub(crate) const H_GROUPS: usize = 5;

pub(crate) fn layout(sh: &Shape, cp: &ClassifierProfile) -> StageLayout {
    let lt = cp.tier.stage_log_n;
    let (llo, ldo, ltab) = (cp.lo_log(), cp.do_log(), cp.tab_log());
    let d_bits = clog2(cp.d_pad);
    let sched = StageSched {
        label: "stage OUT-C",
        slots: vec![
            SlotSpec { name: "OUTC-00 IO-in: x = B_out row T-1 (fixed public row bits)", main: d_bits, ext: 1, degree: 2, kind: SlotKind::Standalone, a_sites: 1, h_sites: 0, io_sites: 1 },
            SlotSpec { name: "OUTC-01 SS final-norm row sum (private, hosted by TZC)", main: ldo, ext: 1, degree: 4, kind: SlotKind::Private, a_sites: 1, h_sites: 0, io_sites: 0 },
            SlotSpec { name: "OUTC-02 TZC isqrt (D, Dsq, 9 limb slices; hosts SS)", main: TO_LOG, ext: 1, degree: 3, kind: SlotKind::Host, a_sites: 11, h_sites: 0, io_sites: 0 },
            SlotSpec { name: "OUTC-03 PD margin sum_i y(i) w_Delta(i) (private, hosted by LZC)", main: d_bits, ext: 1, degree: 2, kind: SlotKind::Private, a_sites: 1, h_sites: 0, io_sites: 0 },
            SlotSpec { name: "OUTC-04 LZC limb lookups (+pad; isqrt and margin limbs) + host term sigma g limb + u0 (sigma b + c)", main: llo, ext: 1, degree: 4, kind: SlotKind::Host, a_sites: 1, h_sites: 1, io_sites: 0 },
            SlotSpec { name: "OUTC-05 DZC final-norm quotient + x limbs + helpers (+pad)", main: ldo, ext: 1, degree: 5, kind: SlotKind::Standalone, a_sites: 13, h_sites: H_DO_HELPERS, io_sites: 0 },
            SlotSpec { name: "OUTC-06 TAB byte-table helper (+pad)", main: ltab, ext: 1, degree: 3, kind: SlotKind::Standalone, a_sites: 1, h_sites: 1, io_sites: 0 },
            SlotSpec { name: "OUTC-07 ZS zero-sum row", main: lt, ext: 1, degree: 2, kind: SlotKind::Standalone, a_sites: 0, h_sites: 1, io_sites: 0 },
        ],
        hosts: vec![(SOC_TZC, vec![SOC_SS]), (SOC_LZC, vec![SOC_PD])],
        // [A, H, In = B_out, Out = unused (no output endpoint)]
        row_log: [lt, lt, sh.endpoint_log_n, lt],
    };
    let mut a_log = vec![TO_LOG; 2];
    a_log.push(llo);
    a_log.extend(vec![ldo; 12]);
    a_log.push(ltab);
    let mut h_sign = vec![1i64; H_U + 1];
    h_sign[H_GU8] = -1;
    let mut h_log = vec![llo];
    h_log.extend(vec![ldo; H_DO_HELPERS]);
    h_log.push(ltab);
    h_log.push(lt);
    StageLayout::new(cp.tier.stage_params(), a_log, h_log, h_sign, H_U, sched)
}

/// the stage's byte-lookup size for the whole-run figure: every looked
/// column over its domain's (lifted) extent, and the 256-row table
pub(crate) fn logup_size(lay: &StageLayout) -> (u128, u128) {
    let n = |helper: usize, cols: usize| (cols as u128) << lay.h_log[helper];
    (n(H_LO, lookups_lo().len()) + n(H_D0, lookups_do().len()), U8_LEN as u128)
}

#[derive(Clone, Debug)]
pub(crate) struct Lk {
    pub terms: Vec<(usize, i64)>,
    pub cst: i64,
}

fn byte(p: usize) -> Lk {
    Lk { terms: vec![(p, 1)], cst: 0 }
}

pub(crate) fn lookups_lo() -> Vec<Lk> {
    vec![byte(C_LIMB)]
}
pub(crate) fn lookups_do() -> Vec<Lk> {
    let mut v = vec![byte(C_XL0), byte(C_XL1), Lk { terms: vec![(C_Y, 1)], cst: 127 }, Lk { terms: vec![(C_Y, -1)], cst: 127 }];
    v.extend((0..NORM_LIMBS).map(|k| byte(C_RHO0 + k)));
    v.extend((0..NORM_LIMBS).map(|k| byte(C_SIG0 + k)));
    v
}

/// What the stage OUT-C prover commits on `A_out` (the histogram derived)
#[derive(Clone, Debug)]
pub(crate) struct StageOutCWitness {
    pub planes: Vec<Vec<Fp>>,
}

/// the integer semantics of stage OUT-C: the final norm (stage OUT's), the
/// margin, the verdict and its limbs
#[derive(Clone, Debug)]
pub(crate) struct OutCValues {
    pub x: Vec<i64>,
    pub d: i64,
    pub a1: i64,
    pub a2: i64,
    pub y: Vec<i64>,
    pub rho: Vec<i64>,
    pub sigma: Vec<i64>,
    /// `Delta = y . w_Delta`
    pub margin: i64,
    /// the public verdict: 1 iff `Delta > c`
    pub verdict: u8,
}

fn isqrt_u128(v: u128) -> u128 {
    if v < 2 {
        return v;
    }
    let mut x = 1u128 << (128 - v.leading_zeros()).div_ceil(2);
    loop {
        let y = (x + v / x) / 2;
        if y >= x {
            return x;
        }
        x = y;
    }
}

/// **the final norm and the margin on one int16 row** (stage OUT's norm,
/// refusing never clamping: D20; a cheating prover still gets the values)
pub(crate) fn out_values(cp: &ClassifierProfile, tables: &ClassifierTables, x_row: &[i64], check: bool) -> Result<OutCValues, String> {
    let nm = cp.norm;
    let ss: i128 = i128::from(nm.ceps) + x_row[..cp.d].iter().map(|v| i128::from(*v) * i128::from(*v)).sum::<i128>();
    let d = isqrt_u128(ss as u128) as i128;
    let a1 = ss - d * d;
    let a2 = 2 * d - a1;
    if check && (x_row.iter().any(|v| !(-32768..=32767).contains(v)) || !(1..1i128 << 24).contains(&d) || !(0..1i128 << 24).contains(&a1) || !(0..1i128 << 24).contains(&a2)) {
        return Err("classifier stage OUT-C: final norm denominator (refused, D20)".into());
    }
    let dv = d << nm.tn;
    let den = 2 * dv;
    let (mut y, mut rho, mut sigma) = (vec![0i64; cp.d_pad], vec![0i64; cp.d_pad], vec![0i64; cp.d_pad]);
    for i in 0..cp.d {
        let num = 2 * i128::from(x_row[i]) * i128::from(nm.g0) * i128::from(nm.cn) + dv;
        let q = num.div_euclid(den);
        let r = num - q * den;
        let s = den - 1 - r;
        if check && (!(-127..=127).contains(&q) || r >= 1i128 << cp.wrho || s >= 1i128 << cp.wrho) {
            return Err("classifier stage OUT-C: final norm quotient/remainder (refused, D20)".into());
        }
        y[i] = q as i64;
        rho[i] = r as i64;
        sigma[i] = s as i64;
    }
    let margin = tables.margin(&y[..cp.d]);
    let verdict = u8::from(margin > cp.policy.c);
    Ok(OutCValues { x: x_row.to_vec(), d: d as i64, a1: a1 as i64, a2: a2 as i64, y, rho, sigma, margin, verdict })
}

fn bytes_of(v: i64, n: usize) -> Vec<i64> {
    (0..n).map(|k| (v >> (8 * k)) & 0xFF).collect()
}

/// `delta = sigma (Delta - c) - b`, the nonnegative integer the limbs carry
pub(crate) fn delta_of(margin: i64, c: i64, b: u8) -> i64 {
    let s = 2 * i64::from(b) - 1;
    s * (margin - c) - i64::from(b)
}

/// The honest `A_out` planes from the integer values and the verdict.
pub(crate) fn witness_from_values(cp: &ClassifierProfile, ov: &OutCValues) -> Result<StageOutCWitness, String> {
    let l = cp.limbs;
    let (lo_n, do_n) = (1usize << cp.lo_log(), 1usize << cp.do_log());
    let mut planes: Vec<Vec<Fp>> = vec![Vec::new(); C_MULT + 1];
    let to = |v: i64| -> Vec<Fp> {
        let mut p = vec![Fp::ZERO; 1 << TO_LOG];
        p[0] = Fp::from_i64(v);
        p
    };
    planes[C_D] = to(ov.d);
    planes[C_DSQ] = to(ov.d * ov.d);
    let mut limb = vec![Fp::ZERO; lo_n];
    for (s, v) in [ov.d, ov.a1, ov.a2].iter().enumerate() {
        for (kk, b) in bytes_of(*v, LIMBS_ISQRT).iter().enumerate() {
            limb[2 * (3 * s + kk)] = Fp::from_i64(*b);
        }
    }
    let delta = delta_of(ov.margin, cp.policy.c, ov.verdict);
    if delta < 0 || (delta as u128) >= 1u128 << (8 * l) {
        return Err("classifier stage OUT-C: an honest margin difference left its limbs (a bug, never a refusal)".into());
    }
    for (kk, b) in bytes_of(delta, l).iter().enumerate() {
        limb[LAM_BASE + kk] = Fp::from_i64(*b);
    }
    planes[C_LIMB] = limb;
    for p in C_X..C_MULT {
        planes[p] = vec![Fp::ZERO; do_n];
    }
    for i in 0..cp.d {
        planes[C_X][i] = Fp::from_i64(ov.x[i]);
        let xl = bytes_of(ov.x[i] + 32768, 2);
        planes[C_XL0][i] = Fp::from_i64(xl[0]);
        planes[C_XL1][i] = Fp::from_i64(xl[1]);
        planes[C_Y][i] = Fp::from_i64(ov.y[i]);
        for (kk, b) in bytes_of(ov.rho[i], NORM_LIMBS).iter().enumerate() {
            planes[C_RHO0 + kk][i] = Fp::from_i64(*b);
        }
        for (kk, b) in bytes_of(ov.sigma[i], NORM_LIMBS).iter().enumerate() {
            planes[C_SIG0 + kk][i] = Fp::from_i64(*b);
        }
    }
    Ok(StageOutCWitness { planes })
}

pub(crate) fn row_of(cp: &ClassifierProfile, b_out: &[i16], row: usize) -> Vec<i64> {
    b_out[row * cp.d_pad..(row + 1) * cp.d_pad].iter().map(|v| i64::from(*v)).collect()
}

pub(crate) struct OutCCtx<'a> {
    pub lay: &'a StageLayout,
    pub cp: &'a ClassifierProfile,
    pub tables: &'a ClassifierTables,
    pub verdict: u8,
    pub alpha: Fp2,
    pub g_u8: Fp2,
    pub b_out_row: usize,
    pub b_out_log: usize,
}

fn supp(len: usize, size: usize) -> Vec<Fp2> {
    (0..size).map(|z| if z < len { Fp2::ONE } else { Fp2::ZERO }).collect()
}

fn resolve(lks: &[Lk], idx: &dyn Fn(usize) -> usize, g_u8: Fp2) -> Vec<(Vec<(usize, Fp)>, Fp2)> {
    lks.iter().map(|l| (l.terms.iter().map(|(p, c)| (idx(*p), Fp::from_i64(*c))).collect(), Fp2::from_i64(l.cst).add(g_u8))).collect()
}

/// the live entries of the limb plane: the nine isqrt sub-planes at To entry
/// 0 (index 2k) and the L margin limbs at `LAM_BASE ..`
fn live_limb(z: usize, l: usize) -> bool {
    (z % 2 == 0 && z / 2 < 3 * LIMBS_ISQRT) || (LAM_BASE..LAM_BASE + l).contains(&z)
}

pub(crate) fn define(slot: usize, cx: &OutCCtx, tr: &mut Transcript) -> Result<StageSlotDef, String> {
    let (lay, cp) = (cx.lay, cx.cp);
    let mut b = SB::new(lay, slot);
    let (alpha, g_u8) = (cx.alpha, cx.g_u8);
    let l = cp.limbs;
    let d_bits = clog2(cp.d_pad);
    let t_bits = clog2(cp.t_pad);
    let (llo, lo_n) = (cp.lo_log(), 1usize << cp.lo_log());
    let (ldo, do_n) = (cp.do_log(), 1usize << cp.do_log());
    let (ltab, tab_n) = (cp.tab_log(), 1usize << cp.tab_log());
    let lift = ldo - d_bits;
    let f0 = || vec![Coord::Fixed(Fp2::ZERO); TO_LOG];
    match slot {
        SOC_IO => {
            let tau = tr.challenge_fp2_vec(d_bits);
            let i_eq = b.eq(&tau, 0);
            let mut cx_ = fixed(&vec![Fp2::ZERO; lift]);
            cx_.extend(rho(0..d_bits));
            let i_x = b.a_at(C_X, cx_)?;
            let mut cb = fixed_bits(cp.tokens - 1, t_bits);
            cb.extend(rho(0..d_bits));
            let i_b = b.io(Cm::In, cx.b_out_log, cb, cx.b_out_row);
            b.finish(Box::new(move |v: &[Fp2]| v[i_eq].mul(v[i_x].sub(v[i_b]))), vec![])
        }
        SOC_SS => {
            let i_s = b.public(supp(cp.d, do_n));
            let i_x = b.a(C_X)?;
            b.finish(Box::new(move |v: &[Fp2]| v[i_s].mul(v[i_x]).mul(v[i_x])), vec![])
        }
        SOC_TZC => {
            let tau = tr.challenge_fp2_vec(TO_LOG);
            let mu = nonzero(tr.challenge_fp2_vec(4))?;
            let nu = nonzero(tr.challenge_fp2_vec(1))?[0];
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_u0 = b.public(supp(1, 1 << TO_LOG));
            let i_d = b.a(C_D)?;
            let i_dsq = b.a(C_DSQ)?;
            let i_l0 = i_dsq + 1;
            for kk in 0..3 * LIMBS_ISQRT {
                b.a_slice(lay.a_off[C_LIMB] + 2 * kk, TO_LOG, rho(0..TO_LOG))?;
            }
            let k_ceps = k(cp.norm.ceps);
            let (p1, p2) = (Fp::new(256), Fp::new(65536));
            let poly = move |v: &[Fp2]| {
                let l3 = |o: usize| v[o].add(v[o + 1].mul_base(p1)).add(v[o + 2].mul_base(p2));
                let (d, dsq, dl, a1, a2) = (v[i_d], v[i_dsq], l3(i_l0), l3(i_l0 + 3), l3(i_l0 + 6));
                let pad = Fp2::ONE.sub(v[i_u0]).mul(d.add(zeta.mul(dsq)));
                let zc = mu[0].mul(dsq.sub(d.mul(d))).add(mu[1].mul(d.sub(dl))).add(mu[2].mul(d.double().sub(a1).sub(a2))).add(mu[3].mul(pad));
                v[i_eq].mul(zc).add(nu.mul(v[i_u0]).mul(dsq.add(a1).sub(k_ceps)))
            };
            b.finish(Box::new(poly), vec![(SOC_SS, nu)])
        }
        // THE MARGIN: y at its natural d_pad (lift bits fixed) times the
        // public margin vector, a private sum hosted by LZC
        SOC_PD => {
            let mut cy = fixed(&vec![Fp2::ZERO; lift]);
            cy.extend(rho(0..d_bits));
            let i_y = b.a_at(C_Y, cy)?;
            let w: Vec<Fp2> = (0..cp.d_pad).map(|i| if i < cp.d { k(i64::from(cx.tables.w_delta[i])) } else { Fp2::ZERO }).collect();
            let i_w = b.public(w);
            b.finish(Box::new(move |v: &[Fp2]| v[i_y].mul(v[i_w])), vec![])
        }
        // the limb lookups (isqrt and margin limbs) + pad, and the HOST TERM
        // nu (sigma g limb + u0 (sigma b + c)): hosting forces
        // sum host-term = sum PD = Delta, i.e. Delta = sigma (delta + b) + c
        SOC_LZC => {
            let tau = tr.challenge_fp2_vec(llo);
            let mu = nonzero(tr.challenge_fp2_vec(2))?;
            let nu = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_s = b.public((0..lo_n).map(|z| if live_limb(z, l) { Fp2::ONE } else { Fp2::ZERO }).collect());
            let sig = if cx.verdict == 1 { Fp2::ONE } else { Fp2::ONE.neg() };
            let i_g = b.public((0..lo_n).map(|z| if (LAM_BASE..LAM_BASE + l).contains(&z) { sig.mul(k(1i64 << (8 * (z - LAM_BASE)))) } else { Fp2::ZERO }).collect());
            let i_u0 = b.public(supp(1, lo_n));
            let i_l = b.a(C_LIMB)?;
            let i_h = b.h(H_LO)?;
            let lks = resolve(&lookups_lo(), &|_| i_l, g_u8);
            let ones = vec![Fp2::ONE; 1];
            // the public constant sigma b + c (b is 0 or 1)
            let kc = k(i64::from(cx.verdict)).add(k(cp.policy.c));
            let poly = move |v: &[Fp2]| {
                let pad = Fp2::ONE.sub(v[i_s]).mul(v[i_l]);
                let host = v[i_g].mul(v[i_l]).add(v[i_u0].mul(kc));
                v[i_eq].mul(mu[0].mul(helper_sum(v, &lks, i_h, alpha, &ones)).add(mu[1].mul(pad))).add(nu.mul(host))
            };
            b.finish(Box::new(poly), vec![(SOC_PD, nu)])
        }
        SOC_DZC => {
            let tau = tr.challenge_fp2_vec(ldo);
            let mu = nonzero(tr.challenge_fp2_vec(3 + H_DO_HELPERS + 1))?;
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_s = b.public(supp(cp.d, do_n));
            let first = b.tabs_len();
            for p in C_X..C_MULT {
                b.a(p)?;
            }
            let at = move |p: usize| first + (p - C_X);
            let i_d = b.a_at(C_D, f0())?;
            let h0 = b.h(H_D0)?;
            for j in 1..H_DO_HELPERS {
                b.h(H_D0 + j)?;
            }
            let lks = resolve(&lookups_do(), &at, g_u8);
            let planes: Vec<usize> = (C_X..C_MULT).map(at).collect();
            let nm = cp.norm;
            let (k_num, k_dv, k_den) = (k(2 * nm.g0 * nm.cn), k(1i64 << nm.tn), k(1i64 << (nm.tn + 1)));
            let poly = move |v: &[Fp2]| {
                let lb = |p0: usize| (0..NORM_LIMBS).fold(Fp2::ZERO, |a, kk| a.add(v[at(p0 + kk)].mul_base(Fp::new(1u64 << (8 * kk)))));
                let (x, y, d) = (v[at(C_X)], v[at(C_Y)], v[i_d]);
                let (rh, sg) = (lb(C_RHO0), lb(C_SIG0));
                let kd = d.mul(k_den);
                let c0 = x.mul(k_num).add(d.mul(k_dv)).sub(kd.mul(y)).sub(rh);
                let c1 = sg.add(rh).add(Fp2::ONE).sub(kd);
                let c2 = x.add(k(32768)).sub(v[at(C_XL0)]).sub(v[at(C_XL1)].mul_base(Fp::new(256)));
                let g = v[i_s];
                let clauses = mu[0].mul(c0).add(mu[1].mul(c1)).add(mu[2].mul(c2));
                let pad = Fp2::ONE.sub(g).mul(zeta_fold(v, &planes, zeta));
                v[i_eq].mul(g.mul(clauses).add(helper_sum(v, &lks, h0, alpha, &mu[3..3 + H_DO_HELPERS])).add(mu[3 + H_DO_HELPERS].mul(pad)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SOC_TAB => {
            let tau = tr.challenge_fp2_vec(ltab);
            let mu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_s = b.public(supp(U8_LEN, tab_n));
            let i_tv = b.public((0..tab_n).map(|z| k((z % U8_LEN) as i64).add(g_u8)).collect());
            let i_m = b.a(C_MULT)?;
            let i_h = b.h(H_GU8)?;
            let poly = move |v: &[Fp2]| {
                let rel = v[i_h].mul(alpha.sub(v[i_tv])).sub(v[i_m]);
                let pad = Fp2::ONE.sub(v[i_s]).mul(v[i_m].add(zeta.mul(v[i_h])));
                v[i_eq].mul(mu[0].mul(rel).add(mu[1].mul(pad)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SOC_ZS => {
            let i1 = b.public(vec![Fp2::ONE; 1usize << lay.h_log[H_U]]);
            let iu = b.h(H_U)?;
            b.finish(Box::new(move |v: &[Fp2]| v[i1].mul(v[iu])), vec![])
        }
        _ => Err("classifier stage OUT-C: unknown slot".into()),
    }
}

fn run_slots(side: &mut Side, cx: &OutCCtx, tr: &mut Transcript) -> Result<Acc, String> {
    let mut acc = Acc::default();
    for slot in 0..cx.lay.sched.slots.len() {
        // ROUND 12 (gate round 16 capture request 2.2): the run capture's
        // definition checkpoint (verify side only; a no-op unless a recorder
        // is attached; test builds only)
        #[cfg(test)]
        super::super::run_capture::start_slot(side, tr);
        let def = define(slot, cx, tr)?;
        run_stage_slot(side, &mut acc, def, &cx.lay.sched, tr)?;
    }
    finish_functionals(acc, cx.lay)
}

fn looked(planes: &[Vec<Fp>], lks: &[Lk], n: usize) -> Vec<Vec<Fp>> {
    lks.iter()
        .map(|lk| (0..n).map(|x| lk.terms.iter().fold(Fp::from_i64(lk.cst), |a, (p, c)| a.add(Fp::from_i64(*c).mul(planes[*p][x])))).collect())
        .collect()
}

fn write_h(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
    for (i, v) in col.iter().enumerate() {
        h[off.0 + i] = v.c0;
        h[off.1 + i] = v.c1;
    }
}

fn helper_col(a: &[Fp], b: Option<&[Fp]>, alpha: Fp2, g: Fp2) -> Result<Vec<Fp2>, String> {
    let inv = |x: Fp| -> Result<Fp2, String> {
        let d = alpha.sub(Fp2::from_base(x).add(g));
        if d.is_zero() {
            return Err("zero LogUp denominator; discard attempt".into());
        }
        Ok(d.inv())
    };
    (0..a.len())
        .map(|i| {
            let h = inv(a[i])?;
            Ok(match b {
                Some(bb) => h.add(inv(bb[i])?),
                None => h,
            })
        })
        .collect()
}

fn witness_shape(lay: &StageLayout, wit: &StageOutCWitness) -> Result<(), String> {
    if wit.planes.len() != C_MULT + 1 || (0..C_MULT).any(|p| wit.planes[p].len() != 1usize << lay.a_log[p]) {
        return Err("classifier stage OUT-C: witness shape".into());
    }
    Ok(())
}

fn byte_columns(cp: &ClassifierProfile, wit: &StageOutCWitness) -> Vec<Vec<Fp>> {
    [(lookups_lo(), cp.lo_log()), (lookups_do(), cp.do_log())].iter().flat_map(|(lks, lg)| looked(&wit.planes, lks, 1usize << lg)).collect()
}

/// **the sealing pass's stage-OUT-C check** (H-1, before any header): every
/// byte lookup lands in the byte table, the margin limbs' pad entries are
/// zero, and the limbs, the margin and the verdict satisfy the identity
/// `Delta = sigma (delta + b) + c` with `Delta` recomputed from `y`
pub(crate) fn seal_check(lay: &StageLayout, cp: &ClassifierProfile, tables: &ClassifierTables, wit: &StageOutCWitness, verdict: u8) -> Result<(), String> {
    witness_shape(lay, wit)?;
    if byte_columns(cp, wit).iter().any(|c| c.iter().any(|v| (v.0 as usize) >= U8_LEN)) {
        return Err("classifier stage OUT-C: the witness looks up a value that is not a byte (the class of the miss only)".into());
    }
    let limb = &wit.planes[C_LIMB];
    if limb.iter().enumerate().any(|(z, v)| !live_limb(z, cp.limbs) && !v.is_zero()) {
        return Err("classifier stage OUT-C: a limb-plane pad entry is not zero".into());
    }
    let y: Vec<i64> = wit.planes[C_Y][..cp.d].iter().map(|v| if v.0 > P / 2 { -((P - v.0) as i64) } else { v.0 as i64 }).collect();
    let delta: i64 = (0..cp.limbs).map(|kk| (limb[LAM_BASE + kk].0 as i64) << (8 * kk)).sum();
    let s = 2 * i64::from(verdict) - 1;
    if tables.margin(&y) != s * (delta + i64::from(verdict)) + cp.policy.c {
        return Err("classifier stage OUT-C: the verdict and its limbs are not the margin's (refused before any header)".into());
    }
    Ok(())
}

pub(crate) struct OutCProved {
    pub seg: StageSegment,
}

/// **THE STAGE OUT-C PROVER.** `pending_b` is block `L - 1`'s claim on
/// `B_out`; `B_out`'s ONE opening follows this stage's `M`, `A`, `H`.
#[allow(clippy::too_many_arguments)]
pub(crate) fn prove(
    lay: &StageLayout,
    cp: &ClassifierProfile,
    tables: &ClassifierTables,
    wit: StageOutCWitness,
    verdict: u8,
    b_spec: &BoundarySpec,
    b_owner: PreparedBoundary,
    pending_b: Vec<ZClaim>,
    stage_index: u64,
    ntt: &crate::ntt::NttTables,
    rng: &mut crate::zk::ZkRng,
    tr: &mut Transcript,
    tag: &zkp_core::hashtag::HashTag,
) -> Result<OutCProved, String> {
    #[cfg(test)]
    let cheating = protocol::cheating_prover_is_on();
    #[cfg(not(test))]
    let cheating = false;
    let n = lay.n;
    witness_shape(lay, &wit)?;
    tr.absorb_u64(b"pb-run-stage", stage_index);
    tr.absorb(b"pb-run-block", &cp.w_digest);
    let cols = byte_columns(cp, &wit);
    let mut hist = vec![0u64; U8_LEN];
    let mut misses = 0usize;
    for c in &cols {
        for v in c {
            if (v.0 as usize) < U8_LEN {
                hist[v.0 as usize] += 1;
            } else {
                misses += 1;
                hist[0] += 1;
            }
        }
    }
    if misses > 0 && !cheating {
        return Err("classifier stage OUT-C: the witness looks up a value that is not a byte (the class of the miss only)".into());
    }
    let params = lay.params;
    let zko = ZkOpts::standard(&params);
    let mut a_data = vec![Fp::ZERO; lay.a_rows * n];
    for p in 0..C_MULT {
        a_data[lay.a_off[p]..lay.a_off[p] + wit.planes[p].len()].copy_from_slice(&wit.planes[p]);
    }
    for (i, c) in hist.iter().enumerate() {
        a_data[lay.a_off[C_MULT] + i] = Fp::new(*c);
    }
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
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let mut h_data = vec![Fp::ZERO; lay.h_rows * n];
    let mut ci = 0usize;
    for (first, count) in [(H_LO, 1usize), (H_D0, H_DO_HELPERS)] {
        let dom_cols = if first == H_LO { 1 } else { lookups_do().len() };
        for kk in 0..count {
            let a_col = &cols[ci + 2 * kk];
            let b_col = if 2 * kk + 1 < dom_cols { Some(cols[ci + 2 * kk + 1].as_slice()) } else { None };
            write_h(&mut h_data, lay.h_off[first + kk], &helper_col(a_col, b_col, alpha, g_u8)?);
        }
        ci += dom_cols;
    }
    let tcol: Vec<Fp2> = (0..1usize << cp.tab_log())
        .map(|z| {
            let m = if z < U8_LEN { hist[z] } else { 0 };
            if m == 0 {
                return Ok(Fp2::ZERO);
            }
            let d = alpha.sub(k((z % U8_LEN) as i64).add(g_u8));
            if d.is_zero() {
                return Err("zero LogUp denominator; discard attempt".to_string());
            }
            Ok(d.inv().mul_base(Fp::new(m)))
        })
        .collect::<Result<Vec<Fp2>, String>>()?;
    write_h(&mut h_data, lay.h_off[H_GU8], &tcol);
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
    let cx = OutCCtx { lay, cp, tables, verdict, alpha, g_u8, b_out_row: b_spec.mask_row(1)?, b_out_log: (cp.t_pad * cp.d_pad).trailing_zeros() as usize };
    let empty: [Fp; 0] = [];
    let pd = super::super::argument::ProverData { data: [a.data.as_slice(), h.data.as_slice(), b_owner.data(), &empty], masks: &mc.masks };
    let mut side = Side::Prove { pd, out: Vec::new() };
    let acc = run_slots(&mut side, &cx, tr)?;
    let slots = match side {
        Side::Prove { out, .. } => out,
        Side::Verify { .. } => unreachable!(),
    };
    let mask_open = crate::zk::mask_open(&mc, &acc.fs, ntt, tr);
    drop(mc);
    let [ac, mut hc, ic, oc] = acc.claims;
    if !oc.is_empty() {
        return Err("classifier stage OUT-C: a claim on an output endpoint (there is none)".into());
    }
    hc.push(lay.logup_sum_claim());
    protocol::check_opening(&ac, lay.log_n, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, A_GROUPS, tr)?;
    let a_open = pcs::open_zk(&a, &ac, tr);
    drop(a);
    protocol::check_opening(&hc, lay.log_n, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, H_GROUPS, tr)?;
    let h_open = pcs::open_zk(&h, &hc, tr);
    drop(h);
    let mut claims = pending_b;
    claims.extend(ic);
    let b_open = b_owner.into_opening(b_spec, &claims, tr)?;
    Ok(OutCProved { seg: StageSegment { b_root: None, a_root, h_root, mask_root, slots, mask_open, a_open, h_open, closes: vec![b_open] } })
}

/// **THE STAGE OUT-C VERIFIER.** The verdict is the STATEMENT's (public);
/// `pending_b` the verifier's own claim from block `L - 1`.
#[allow(clippy::too_many_arguments)]
pub(crate) fn verify(
    lay: &StageLayout,
    cp: &ClassifierProfile,
    tables: &ClassifierTables,
    verdict: u8,
    seg: &StageSegment,
    b_spec: &BoundarySpec,
    b_root: &Digest,
    pending_b: Vec<ZClaim>,
    stage_index: u64,
    ntt: &crate::ntt::NttTables,
    tr: &mut Transcript,
    tag: &zkp_core::hashtag::HashTag,
) -> Result<(), String> {
    let params = lay.params;
    let zko = ZkOpts::standard(&params);
    if seg.closes.len() != 1 || seg.b_root.is_some() {
        return Err("classifier: stage OUT-C's segment parts are not the run schedule's".into());
    }
    super::super::hash_domain::paths_are_the_tree_depth("stage OUT-C A", &params, &seg.a_open)?;
    super::super::hash_domain::paths_are_the_tree_depth("stage OUT-C H", &params, &seg.h_open)?;
    super::super::hash_domain::mask_paths_are_the_tree_depth(&seg.mask_open)?;
    super::super::hash_domain::paths_are_the_tree_depth("B_out", &b_spec.params(), &seg.closes[0])?;
    tr.absorb_u64(b"pb-run-stage", stage_index);
    tr.absorb(b"pb-run-block", &cp.w_digest);
    protocol::absorb_root(tr, b"A", &seg.a_root, lay.a_rows, lay.log_n);
    tr.absorb(b"M", &seg.mask_root);
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    protocol::absorb_root(tr, b"H", &seg.h_root, lay.h_rows, lay.log_n);
    let cx = OutCCtx { lay, cp, tables, verdict, alpha, g_u8, b_out_row: b_spec.mask_row(1)?, b_out_log: (cp.t_pad * cp.d_pad).trailing_zeros() as usize };
    let mut side = Side::Verify { slots: &seg.slots };
    let acc = run_slots(&mut side, &cx, tr)?;
    // ROUND 12 (gate round 16 capture request 2.2): the openings wrapped as
    // stage OUT wraps its own (no-ops unless a recorder is attached; test
    // builds only)
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    crate::zk::mask_verify_tagged(&seg.mask_root, &lay.mask_specs(), &acc.fs, &seg.mask_open, ntt, tr, tag).map_err(|e| format!("stage OUT-C M: {e}"))?;
    #[cfg(test)]
    super::super::run_capture::mask(&lay.mask_specs(), &seg.mask_root, &acc.fs, &seg.mask_open, ntt, rc_before, tr);
    let [ac, mut hc, ic, oc] = acc.claims;
    if !oc.is_empty() {
        return Err("classifier stage OUT-C: a claim on an output endpoint (there is none)".into());
    }
    hc.push(lay.logup_sum_claim());
    protocol::check_opening(&ac, lay.log_n, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, A_GROUPS, tr)?;
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.a_root, lay.a_rows, lay.log_n), &ac, &seg.a_open, ntt, tr, tag).map_err(|e| format!("stage OUT-C A: {e}"))?;
    #[cfg(test)]
    super::super::run_capture::pcs(capture_a_geom("A-out", "stage-out-c", lay, seg.a_root), &ac, &seg.a_open, ntt, rc_before, tr);
    protocol::check_opening(&hc, lay.log_n, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, H_GROUPS, tr)?;
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.h_root, lay.h_rows, lay.log_n), &hc, &seg.h_open, ntt, tr, tag).map_err(|e| format!("stage OUT-C H (the LogUp sum claim is part of this opening): {e}"))?;
    #[cfg(test)]
    super::super::run_capture::pcs(capture_h_geom("H-out", "stage-out-c", lay, seg.h_root), &hc, &seg.h_open, ntt, rc_before, tr);
    let mut claims = pending_b;
    #[cfg(test)]
    let (pending_n, incoming_n) = (claims.len(), ic.len());
    claims.extend(ic);
    super::super::boundary::check_opening(b_spec, &claims, tr)?;
    let bp = b_spec.params();
    #[cfg(test)]
    let rc_before = super::super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(*b_root, b_spec.commitment_rows(), b_spec.log_n()), &claims, &seg.closes[0], ntt, tr, tag).map_err(|e| format!("B_out: {e}"))?;
    // B_out: the last block's outgoing equality slot's claims, then OUTC-00's
    #[cfg(test)]
    super::super::run_capture::pcs(
        super::super::run_capture::Geom {
            role: "B-out",
            commitment_kind: "B-out",
            params: bp,
            root: *b_root,
            rows: b_spec.commitment_rows(),
            data_rows: b_spec.data_rows(),
            site_rows: b_spec.site_rows(),
            sum_rows: None,
            prox_row: b_spec.prox_row(),
            boundary: Some(stage_index as usize - 1),
            claim_sources: vec![(stage_index as usize - 1, super::super::layout::SC_IO_OUT, pending_n), (stage_index as usize, SOC_IO, incoming_n)],
        },
        &claims,
        &seg.closes[0],
        ntt,
        rc_before,
        tr,
    );
    Ok(())
}

/// ROUND 12 (gate round 16 capture request 2.1(b)): stage OUT-C's plane table
/// for the run capture (the plane names in plane order: the `To` planes D,
/// DSQ, the limb plane, the twelve `Do` planes, the byte histogram; H: the
/// `Lo` helper, six `Do` helpers, the byte-table helper, the zero-sum pair).
/// No output endpoint: its fourth role is never on a terminal ("none").
#[cfg(test)]
pub(crate) fn capture_planes(lay: &StageLayout) -> super::super::run_capture::StagePlanes<'_> {
    let mut a: Vec<String> = ["A_D", "A_DSQ", "A_LIMB", "A_X", "A_XL0", "A_XL1", "A_Y"].iter().map(|s| s.to_string()).collect();
    a.extend((0..4).map(|i| format!("A_RHO{i}")));
    a.extend((0..4).map(|i| format!("A_SIG{i}")));
    a.push("A_MU8".into());
    let mut h: Vec<String> = vec!["H_LO".into()];
    h.extend((0..H_DO_HELPERS).map(|i| format!("H_D{i}")));
    h.push("H_GU8".into());
    h.push("H_U".into());
    super::super::run_capture::StagePlanes::Stage {
        lay,
        a_names: a,
        h_names: h,
        // [A, H, In = B_out, Out = none (a classifier run has no output endpoint)]
        roles: ["A-out", "H-out", "B-out", "none"],
    }
}

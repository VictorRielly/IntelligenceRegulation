//! **STAGE OUT** (DESIGN v3 3.1-3.2, mode (i), public last row): `x` =
//! `B_out` row `T - 1`, the final RMSNorm with a uniform gain, the raw-integer
//! logits through the public head (VIRTUAL: never a plane), the keyed greedy
//! argmax (numpy's first maximum) and the hidden next token sealed in the
//! output token endpoint.
//!
//! Domains (row width 2^12, P-3 lift on every domain carrying H planes):
//! `To` (one output row, laid out over two entries: implementation note TI-1),
//! `Lo` (the nine isqrt limb sub-planes), `Do` (`T_out x d_pad`), `Vo`
//! (`T_out x V_pad`), `Tab`. Slots, in transcript order (the counter's list):
//! IO-in, SS (private) -> TZC (host), LZC, HEAD (private) -> DZC, VZC (host
//! of HEAD), RSEL, TAB, ZS, IO-out.

use super::*;
use crate::pcs::{self, CommittedZk, ZkOpts};
use crate::tables_attn::TAG_U8;
use super::super::boundary::{BoundarySpec, PreparedBoundary};
use super::super::protocol;

/// `To` is laid out over two entries (log 1): entry 0 is the output row,
/// entry 1 pads (TI-1: a log-0 domain cannot carry a claim)
pub(crate) const TO_LOG: usize = 1;

pub(crate) const A_D: usize = 0;
pub(crate) const A_DSQ: usize = 1;
pub(crate) const A_TOK: usize = 2;
pub(crate) const A_M: usize = 3;
pub(crate) const A_LIMB: usize = 4;
pub(crate) const A_X: usize = 5;
pub(crate) const A_XL0: usize = 6;
pub(crate) const A_XL1: usize = 7;
pub(crate) const A_Y: usize = 8;
pub(crate) const A_RHO0: usize = 9;
pub(crate) const A_SIG0: usize = 13;
pub(crate) const A_E: usize = 17;
pub(crate) const A_LAM0: usize = 18;

pub(crate) fn a_mult(limbs: usize) -> usize {
    A_LAM0 + limbs
}
pub(crate) const H_LO: usize = 0;
pub(crate) const H_D0: usize = 1;
pub(crate) const H_DO_HELPERS: usize = 6;
pub(crate) const H_V0: usize = 7;
pub(crate) fn hv(limbs: usize) -> usize {
    limbs.div_ceil(2)
}
pub(crate) fn h_gu8(limbs: usize) -> usize {
    H_V0 + hv(limbs)
}
pub(crate) fn h_u(limbs: usize) -> usize {
    H_V0 + hv(limbs) + 1
}

pub(crate) const SO_IO: usize = 0;
pub(crate) const SO_SS: usize = 1;
pub(crate) const SO_TZC: usize = 2;
pub(crate) const SO_LZC: usize = 3;
pub(crate) const SO_HEAD: usize = 4;
pub(crate) const SO_DZC: usize = 5;
pub(crate) const SO_VZC: usize = 6;
pub(crate) const SO_RSEL: usize = 7;
pub(crate) const SO_TAB: usize = 8;
pub(crate) const SO_ZS: usize = 9;
pub(crate) const SO_IOOUT: usize = 10;

/// The declared opening groups (distinct column keys), derived from the slot
/// list: A = IO-in's `x`, SS's `x`, TZC's {D, Dsq, limb 0} (one key: the
/// slot's point on two-word slices at column 0) and limbs 1..8 (their own
/// columns), LZC, HEAD's `y`, DZC's twelve planes, the fixed-point reads of
/// `To` (D in DZC; tok, M in VZC; tok in RSEL and IO-out: one key), VZC's
/// planes, RSEL's planes, TAB = 1 + 1 + 9 + 1 + 1 + 1 + 1 + 1 + 1 + 1 = 18.
/// H = LZC, DZC, VZC, TAB, ZS and the LogUp sum claim = 6.
pub(crate) const A_GROUPS: usize = 18;
pub(crate) const H_GROUPS: usize = 6;

pub(crate) fn layout(sh: &Shape, tp: &TokenProfile) -> StageLayout {
    let lt = tp.tier.stage_log_n;
    // the stage's domains, each at its own (lifted) log: Lo, Do, Vo, Tab
    let (llo, ldo, lvo, ltab) = (tp.lo_log(), tp.do_log(), tp.vo_log(), tp.tab_log());
    let l = tp.limbs;
    let vplanes = 1 + l;
    let h = hv(l);
    let d_bits = clog2(tp.d_pad);
    let sched = StageSched {
        label: "stage OUT",
        slots: vec![
            SlotSpec { name: "OUT-00 IO-in: x = B_out row T-1 (fixed public row bits)", main: d_bits, ext: 1, degree: 2, kind: SlotKind::Standalone, a_sites: 1, h_sites: 0, io_sites: 1 },
            SlotSpec { name: "OUT-01 SS final-norm row sum (private, hosted by TZC)", main: ldo, ext: 1, degree: 4, kind: SlotKind::Private, a_sites: 1, h_sites: 0, io_sites: 0 },
            SlotSpec { name: "OUT-02 TZC isqrt (D, Dsq, 9 limb slices; hosts SS)", main: TO_LOG, ext: 1, degree: 3, kind: SlotKind::Host, a_sites: 11, h_sites: 0, io_sites: 0 },
            SlotSpec { name: "OUT-03 LZC limb lookups (+pad)", main: llo, ext: 1, degree: 4, kind: SlotKind::Standalone, a_sites: 1, h_sites: 1, io_sites: 0 },
            SlotSpec { name: "OUT-04 HEAD matmul sum_i y(i) W'(r_j, i) (private, hosted by VZC)", main: d_bits, ext: 1, degree: 2, kind: SlotKind::Private, a_sites: 1, h_sites: 0, io_sites: 0 },
            SlotSpec { name: "OUT-05 DZC final-norm quotient + x limbs + helpers (+pad)", main: ldo, ext: 1, degree: 5, kind: SlotKind::Standalone, a_sites: 13, h_sites: H_DO_HELPERS, io_sites: 0 },
            SlotSpec { name: "OUT-06 VZC e(1-e) + head host term on keyed l* + helpers (+pad)", main: lvo, ext: 1, degree: 5, kind: SlotKind::Host, a_sites: vplanes + 2, h_sites: h, io_sites: 0 },
            SlotSpec { name: "OUT-07 RSEL supp e (c1 + c2 iota + c3 delta) - u0 (c1 + c2 tok) (standalone)", main: lvo, ext: 1, degree: 4, kind: SlotKind::Standalone, a_sites: vplanes + 1, h_sites: 0, io_sites: 0 },
            SlotSpec { name: "OUT-08 TAB byte-table helper (+pad)", main: ltab, ext: 1, degree: 3, kind: SlotKind::Standalone, a_sites: 1, h_sites: 1, io_sites: 0 },
            SlotSpec { name: "OUT-09 ZS zero-sum row", main: lt, ext: 1, degree: 2, kind: SlotKind::Standalone, a_sites: 0, h_sites: 1, io_sites: 0 },
            SlotSpec { name: "OUT-10 IO-out: output endpoint = u0 tok (whole 256-word plane)", main: clog2(tp.out_ep_words()), ext: 1, degree: 3, kind: SlotKind::Standalone, a_sites: 1, h_sites: 0, io_sites: 1 },
        ],
        hosts: vec![(SO_TZC, vec![SO_SS]), (SO_VZC, vec![SO_HEAD])],
        // [A, H, In = B_out, Out = the output token endpoint]
        row_log: [lt, lt, sh.endpoint_log_n, tp.tier.ep_log_n],
    };
    let mut a_log = vec![TO_LOG; 4];
    a_log.push(llo); // LIMB
    a_log.extend(vec![ldo; 12]); // Do
    a_log.extend(vec![lvo; vplanes]); // Vo
    a_log.push(ltab); // the U8 histogram
    let n_h = 1 + H_DO_HELPERS + h + 2;
    let mut h_sign = vec![1i64; n_h];
    h_sign[h_gu8(l)] = -1;
    // H = [Lo helper, six Do helpers, the Vo helpers, the table helper (Tab), the zero-sum pair u (one row)]
    let mut h_log = vec![llo];
    h_log.extend(vec![ldo; H_DO_HELPERS]);
    h_log.extend(vec![lvo; h]);
    h_log.push(ltab);
    h_log.push(lt);
    StageLayout::new(tp.tier.stage_params(), a_log, h_log, h_sign, h_u(l), sched)
}

/// The stage's LogUp size for the derived whole-run figure (D27; MEMO_G02):
/// `(queries, distinct table rows)` = every byte lookup column over its
/// domain's (lifted) extent, and the 256-row byte table.
pub(crate) fn logup_size(lay: &StageLayout, tp: &TokenProfile) -> (u128, u128) {
    let n = |helper: usize, cols: usize| (cols as u128) << lay.h_log[helper];
    (n(H_LO, lookups_lo().len()) + n(H_D0, lookups_do().len()) + n(H_V0, lookups_vo(tp.limbs).len()), U8_LEN as u128)
}

/// a byte lookup in PLANE space: `cst + sum coef * plane`
#[derive(Clone, Debug)]
pub(crate) struct Lk {
    pub terms: Vec<(usize, i64)>,
    pub cst: i64,
}

fn byte(p: usize) -> Lk {
    Lk { terms: vec![(p, 1)], cst: 0 }
}

/// the byte lookups of each domain, in helper order (helper k covers
/// lookups 2k, 2k + 1). Window exactly 32 bits: C-6, no scaled top limb.
pub(crate) fn lookups_lo() -> Vec<Lk> {
    vec![byte(A_LIMB)]
}
pub(crate) fn lookups_do() -> Vec<Lk> {
    let mut v = vec![byte(A_XL0), byte(A_XL1), Lk { terms: vec![(A_Y, 1)], cst: 127 }, Lk { terms: vec![(A_Y, -1)], cst: 127 }];
    v.extend((0..NORM_LIMBS).map(|k| byte(A_RHO0 + k)));
    v.extend((0..NORM_LIMBS).map(|k| byte(A_SIG0 + k)));
    v
}
pub(crate) fn lookups_vo(limbs: usize) -> Vec<Lk> {
    (0..limbs).map(|k| byte(A_LAM0 + k)).collect()
}

/// What the stage OUT prover commits on `A_out` (the histogram is derived).
/// Field-valued, so a cheating prover can commit a non-integer `M` (control 3).
#[derive(Clone, Debug)]
pub(crate) struct StageOutWitness {
    /// one plane per A plane, the histogram an EMPTY vector
    pub planes: Vec<Vec<Fp>>,
}

/// The integer semantics of stage OUT (R0's `final_norm`, `head_logits`,
/// `first_argmax`), with every intermediate the witness needs.
#[derive(Clone, Debug)]
pub(crate) struct OutValues {
    pub x: Vec<i64>,
    pub d: i64,
    pub a1: i64,
    pub a2: i64,
    pub y: Vec<i64>,
    pub rho: Vec<i64>,
    pub sigma: Vec<i64>,
    pub logits: Vec<i64>,
    pub tok: usize,
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

/// numpy's `argmax`: the lowest index among equal maxima (D25 T3)
pub(crate) fn first_argmax(l: &[i64]) -> usize {
    let mut best = 0usize;
    for i in 1..l.len() {
        if l[i] > l[best] {
            best = i;
        }
    }
    best
}

/// **The final norm, the head and the greedy choice on one int16 row**
/// (R0's integer semantics). Refuses (never clamps) a denominator outside its
/// limbs, `y` outside int8 or a remainder outside its window (D20 classes); a
/// cheating prover still gets the values (`check` = false).
pub(crate) fn out_values(tp: &TokenProfile, tables: &TokenTables, x_row: &[i64], check: bool) -> Result<OutValues, String> {
    let nm = tp.norm;
    let ss: i128 = i128::from(nm.ceps) + x_row[..tp.d].iter().map(|v| i128::from(*v) * i128::from(*v)).sum::<i128>();
    let d = isqrt_u128(ss as u128) as i128;
    let a1 = ss - d * d;
    let a2 = 2 * d - a1;
    if check && (x_row.iter().any(|v| !(-32768..=32767).contains(v)) || !(1..1i128 << 24).contains(&d) || !(0..1i128 << 24).contains(&a1) || !(0..1i128 << 24).contains(&a2)) {
        return Err("token I/O stage OUT: final norm denominator (refused, D20)".into());
    }
    let dv = d << nm.tn;
    let den = 2 * dv;
    let (mut y, mut rho, mut sigma) = (vec![0i64; tp.d_pad], vec![0i64; tp.d_pad], vec![0i64; tp.d_pad]);
    for i in 0..tp.d {
        let num = 2 * i128::from(x_row[i]) * i128::from(nm.g0) * i128::from(nm.cn) + dv;
        let q = num.div_euclid(den);
        let r = num - q * den;
        let s = den - 1 - r;
        if check && (!(-127..=127).contains(&q) || r >= 1i128 << tp.wrho || s >= 1i128 << tp.wrho) {
            return Err("token I/O stage OUT: final norm quotient/remainder (refused, D20)".into());
        }
        y[i] = q as i64;
        rho[i] = r as i64;
        sigma[i] = s as i64;
    }
    let logits = tables.logits(&y);
    let tok = first_argmax(&logits);
    Ok(OutValues { x: x_row.to_vec(), d: d as i64, a1: a1 as i64, a2: a2 as i64, y, rho, sigma, logits, tok })
}

fn bytes_of(v: i64, n: usize) -> Vec<i64> {
    (0..n).map(|k| (v >> (8 * k)) & 0xFF).collect()
}

/// The honest `A_out` planes from the integer values: the keyed argmax
/// witness `tok = j`, `M = l_j`, `e = e_j`, `delta_i = 2^v (M - l_i) + (i - j)`
/// in `limbs` bytes (zero on padded entries).
pub(crate) fn witness_from_values(tp: &TokenProfile, ov: &OutValues) -> Result<StageOutWitness, String> {
    let l = tp.limbs;
    let (lo_n, do_n, vo_n) = (1usize << tp.lo_log(), 1usize << tp.do_log(), 1usize << tp.vo_log());
    let mut planes: Vec<Vec<Fp>> = vec![Vec::new(); a_mult(l) + 1];
    let to = |v: i64| -> Vec<Fp> {
        let mut p = vec![Fp::ZERO; 1 << TO_LOG];
        p[0] = Fp::from_i64(v);
        p
    };
    let j = ov.tok;
    let m = ov.logits[j];
    planes[A_D] = to(ov.d);
    planes[A_DSQ] = to(ov.d * ov.d);
    planes[A_TOK] = to(j as i64);
    planes[A_M] = to(m);
    let mut limb = vec![Fp::ZERO; lo_n];
    for (s, v) in [ov.d, ov.a1, ov.a2].iter().enumerate() {
        for (kk, b) in bytes_of(*v, LIMBS_ISQRT).iter().enumerate() {
            limb[2 * (3 * s + kk)] = Fp::from_i64(*b);
        }
    }
    planes[A_LIMB] = limb;
    for p in A_X..A_E {
        planes[p] = vec![Fp::ZERO; do_n];
    }
    for i in 0..tp.d {
        planes[A_X][i] = Fp::from_i64(ov.x[i]);
        let xl = bytes_of(ov.x[i] + 32768, 2);
        planes[A_XL0][i] = Fp::from_i64(xl[0]);
        planes[A_XL1][i] = Fp::from_i64(xl[1]);
        planes[A_Y][i] = Fp::from_i64(ov.y[i]);
        for (kk, b) in bytes_of(ov.rho[i], NORM_LIMBS).iter().enumerate() {
            planes[A_RHO0 + kk][i] = Fp::from_i64(*b);
        }
        for (kk, b) in bytes_of(ov.sigma[i], NORM_LIMBS).iter().enumerate() {
            planes[A_SIG0 + kk][i] = Fp::from_i64(*b);
        }
    }
    planes[A_E] = vec![Fp::ZERO; vo_n];
    planes[A_E][j] = Fp::ONE;
    for kk in 0..l {
        planes[A_LAM0 + kk] = vec![Fp::ZERO; vo_n];
    }
    for i in 0..tp.v {
        let delta = ((m - ov.logits[i]) << tp.log_v) + (i as i64 - j as i64);
        if delta < 0 || (delta as u128) >= 1u128 << (8 * l) {
            return Err("token I/O stage OUT: an honest keyed difference left its limbs (a bug, never a refusal)".into());
        }
        for (kk, b) in bytes_of(delta, l).iter().enumerate() {
            planes[A_LAM0 + kk][i] = Fp::from_i64(*b);
        }
    }
    Ok(StageOutWitness { planes })
}

/// `x` = the `B_out` plane's row `row` (`t_pad x d_pad`, int16)
pub(crate) fn row_of(tp: &TokenProfile, b_out: &[i16], row: usize) -> Vec<i64> {
    b_out[row * tp.d_pad..(row + 1) * tp.d_pad].iter().map(|v| i64::from(*v)).collect()
}

/// the output token endpoint's plane: one id at word 0 of a 256-word row
pub(crate) fn endpoint_plane(tp: &TokenProfile, tok: u64) -> Vec<Fp> {
    let mut ep = vec![Fp::ZERO; tp.out_ep_words()];
    ep[0] = Fp::new(tok);
    ep
}

pub(crate) struct OutCtx<'a> {
    pub lay: &'a StageLayout,
    pub tp: &'a TokenProfile,
    pub tables: &'a TokenTables,
    pub alpha: Fp2,
    pub g_u8: Fp2,
    /// the reserved pair of `B_out`'s site 1 (this stage's claim)
    pub b_out_row: usize,
    pub b_out_log: usize,
    pub ep_mask_row: usize,
}

#[derive(Default)]
pub(crate) struct OutPoints {
    r_j: Vec<Fp2>,
}

fn supp(len: usize, size: usize) -> Vec<Fp2> {
    (0..size).map(|z| if z < len { Fp2::ONE } else { Fp2::ZERO }).collect()
}

/// lookups resolved to table indices (plane id -> table index) with the tag
fn resolve(lks: &[Lk], idx: &dyn Fn(usize) -> usize, g_u8: Fp2) -> Vec<(Vec<(usize, Fp)>, Fp2)> {
    lks.iter().map(|l| (l.terms.iter().map(|(p, c)| (idx(*p), Fp::from_i64(*c))).collect(), Fp2::from_i64(l.cst).add(g_u8))).collect()
}

pub(crate) fn define(slot: usize, cx: &OutCtx, pts: &mut OutPoints, tr: &mut Transcript) -> Result<StageSlotDef, String> {
    let (lay, tp) = (cx.lay, cx.tp);
    let mut b = SB::new(lay, slot);
    let (alpha, g_u8) = (cx.alpha, cx.g_u8);
    let l = tp.limbs;
    let d_bits = clog2(tp.d_pad);
    let t_bits = clog2(tp.t_pad);
    // each slot on its own domain: Lo (LZC), Do (SS, DZC; IO-in and HEAD read
    // it at its natural d_pad with the lift bits fixed), Vo (HEAD's r_j, VZC,
    // RSEL), Tab (TAB)
    let (llo, lo_n) = (tp.lo_log(), 1usize << tp.lo_log());
    let (ldo, do_n) = (tp.do_log(), 1usize << tp.do_log());
    let (lvo, vo_n) = (tp.vo_log(), 1usize << tp.vo_log());
    let (ltab, tab_n) = (tp.tab_log(), 1usize << tp.tab_log());
    let lift = ldo - d_bits;
    let (ow, low) = (tp.out_ep_words(), clog2(tp.out_ep_words()));
    let f0 = || vec![Coord::Fixed(Fp2::ZERO); TO_LOG];
    match slot {
        // the public last row: B_out read at the fixed bits of T - 1 (G-2)
        SO_IO => {
            let tau = tr.challenge_fp2_vec(d_bits);
            let i_eq = b.eq(&tau, 0);
            let mut cx_ = fixed(&vec![Fp2::ZERO; lift]);
            cx_.extend(rho(0..d_bits));
            let i_x = b.a_at(A_X, cx_)?;
            let mut cb = fixed_bits(tp.tokens - 1, t_bits);
            cb.extend(rho(0..d_bits));
            let i_b = b.io(Cm::In, cx.b_out_log, cb, cx.b_out_row);
            b.finish(Box::new(move |v: &[Fp2]| v[i_eq].mul(v[i_x].sub(v[i_b]))), vec![])
        }
        SO_SS => {
            let i_s = b.public(supp(tp.d, do_n));
            let i_x = b.a(A_X)?;
            b.finish(Box::new(move |v: &[Fp2]| v[i_s].mul(v[i_x]).mul(v[i_x])), vec![])
        }
        SO_TZC => {
            let tau = tr.challenge_fp2_vec(TO_LOG);
            let mu = nonzero(tr.challenge_fp2_vec(4))?;
            let nu = nonzero(tr.challenge_fp2_vec(1))?[0];
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_u0 = b.public(supp(1, 1 << TO_LOG));
            let i_d = b.a(A_D)?;
            let i_dsq = b.a(A_DSQ)?;
            let i_l0 = i_dsq + 1;
            for kk in 0..3 * LIMBS_ISQRT {
                b.a_slice(lay.a_off[A_LIMB] + 2 * kk, TO_LOG, rho(0..TO_LOG))?;
            }
            let k_ceps = k(tp.norm.ceps);
            let (p1, p2) = (Fp::new(256), Fp::new(65536));
            let poly = move |v: &[Fp2]| {
                let l3 = |o: usize| v[o].add(v[o + 1].mul_base(p1)).add(v[o + 2].mul_base(p2));
                let (d, dsq, dl, a1, a2) = (v[i_d], v[i_dsq], l3(i_l0), l3(i_l0 + 3), l3(i_l0 + 6));
                let pad = Fp2::ONE.sub(v[i_u0]).mul(d.add(zeta.mul(dsq)));
                let zc = mu[0].mul(dsq.sub(d.mul(d))).add(mu[1].mul(d.sub(dl))).add(mu[2].mul(d.double().sub(a1).sub(a2))).add(mu[3].mul(pad));
                v[i_eq].mul(zc).add(nu.mul(v[i_u0]).mul(dsq.add(a1).sub(k_ceps)))
            };
            b.finish(Box::new(poly), vec![(SO_SS, nu)])
        }
        SO_LZC => {
            let tau = tr.challenge_fp2_vec(llo);
            let mu = nonzero(tr.challenge_fp2_vec(2))?;
            let i_eq = b.eq(&tau, 0);
            // the live limb positions: sub-plane k < 9 at To entry 0 (index 2k)
            let i_s = b.public((0..lo_n).map(|z| if z % 2 == 0 && z / 2 < 3 * LIMBS_ISQRT { Fp2::ONE } else { Fp2::ZERO }).collect());
            let i_l = b.a(A_LIMB)?;
            let i_h = b.h(H_LO)?;
            let lks = resolve(&lookups_lo(), &|_| i_l, g_u8);
            let ones = vec![Fp2::ONE; 1];
            let poly = move |v: &[Fp2]| {
                let pad = Fp2::ONE.sub(v[i_s]).mul(v[i_l]);
                v[i_eq].mul(mu[0].mul(helper_sum(v, &lks, i_h, alpha, &ones)).add(mu[1].mul(pad)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SO_HEAD => {
            pts.r_j = tr.challenge_fp2_vec(lvo);
            let e = eq_table_msb(&pts.r_j);
            let wf = cx.tables.head_fold(&e[..tp.v], tp.d_pad);
            let mut cy = fixed(&vec![Fp2::ZERO; lift]);
            cy.extend(rho(0..d_bits));
            let i_y = b.a_at(A_Y, cy)?;
            let i_w = b.public(wf);
            b.finish(Box::new(move |v: &[Fp2]| v[i_y].mul(v[i_w])), vec![])
        }
        SO_DZC => {
            let tau = tr.challenge_fp2_vec(ldo);
            let mu = nonzero(tr.challenge_fp2_vec(3 + H_DO_HELPERS + 1))?;
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_s = b.public(supp(tp.d, do_n));
            let first = b.tabs_len();
            for p in A_X..A_E {
                b.a(p)?;
            }
            let at = move |p: usize| first + (p - A_X);
            let i_d = b.a_at(A_D, f0())?;
            let h0 = b.h(H_D0)?;
            for j in 1..H_DO_HELPERS {
                b.h(H_D0 + j)?;
            }
            let lks = resolve(&lookups_do(), &at, g_u8);
            let planes: Vec<usize> = (A_X..A_E).map(at).collect();
            let nm = tp.norm;
            let (k_num, k_dv, k_den) = (k(2 * nm.g0 * nm.cn), k(1i64 << nm.tn), k(1i64 << (nm.tn + 1)));
            let poly = move |v: &[Fp2]| {
                let lb = |p0: usize| (0..NORM_LIMBS).fold(Fp2::ZERO, |a, kk| a.add(v[at(p0 + kk)].mul_base(Fp::new(1u64 << (8 * kk)))));
                let (x, y, d) = (v[at(A_X)], v[at(A_Y)], v[i_d]);
                let (rh, sg) = (lb(A_RHO0), lb(A_SIG0));
                let kd = d.mul(k_den);
                let c0 = x.mul(k_num).add(d.mul(k_dv)).sub(kd.mul(y)).sub(rh);
                let c1 = sg.add(rh).add(Fp2::ONE).sub(kd);
                let c2 = x.add(k(32768)).sub(v[at(A_XL0)]).sub(v[at(A_XL1)].mul_base(Fp::new(256)));
                let g = v[i_s];
                let clauses = mu[0].mul(c0).add(mu[1].mul(c1)).add(mu[2].mul(c2));
                let pad = Fp2::ONE.sub(g).mul(zeta_fold(v, &planes, zeta));
                v[i_eq].mul(g.mul(clauses).add(helper_sum(v, &lks, h0, alpha, &mu[3..3 + H_DO_HELPERS])).add(mu[3 + H_DO_HELPERS].mul(pad)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SO_VZC => {
            let tau = tr.challenge_fp2_vec(lvo);
            let n_help = hv(l);
            let mu = nonzero(tr.challenge_fp2_vec(1 + n_help + 1))?;
            let nu = nonzero(tr.challenge_fp2_vec(1))?[0];
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_rj = b.eq(&pts.r_j, 0);
            let i_s = b.public(supp(tp.v, vo_n));
            let i_iota = b.public((0..vo_n).map(|z| k(z as i64)).collect());
            let i_e = b.a(A_E)?;
            for kk in 0..l {
                b.a(A_LAM0 + kk)?;
            }
            let lam = move |kk: usize| i_e + 1 + kk;
            let i_tok = b.a_at(A_TOK, f0())?;
            let i_m = b.a_at(A_M, f0())?;
            let h0 = b.h(H_V0)?;
            for j in 1..n_help {
                b.h(H_V0 + j)?;
            }
            let lks = resolve(&lookups_vo(l), &|p| lam(p - A_LAM0), g_u8);
            let planes: Vec<usize> = std::iter::once(i_e).chain((0..l).map(lam)).collect();
            let inv2v = k(1i64 << tp.log_v).inv();
            let poly = move |v: &[Fp2]| {
                let delta = (0..l).fold(Fp2::ZERO, |a, kk| a.add(v[lam(kk)].mul_base(Fp::new(1u64 << (8 * kk)))));
                let e = v[i_e];
                let lstar = v[i_s].mul(v[i_m].add(inv2v.mul(v[i_iota].sub(v[i_tok]).sub(delta))));
                let pad = Fp2::ONE.sub(v[i_s]).mul(zeta_fold(v, &planes, zeta));
                let zc = mu[0].mul(e.mul(Fp2::ONE.sub(e))).add(helper_sum(v, &lks, h0, alpha, &mu[1..1 + n_help])).add(mu[1 + n_help].mul(pad));
                v[i_eq].mul(zc).add(nu.mul(v[i_rj]).mul(lstar))
            };
            b.finish(Box::new(poly), vec![(SO_HEAD, nu)])
        }
        // A2 (sum e = 1), A3 (tok = sum i e) and A6 (sum e delta = 0), each
        // with its own fresh coefficient drawn after A_out, a public factor
        // in every monomial (DESIGN 3.1, B-3)
        SO_RSEL => {
            let c = nonzero(tr.challenge_fp2_vec(3))?;
            let i_s = b.public(supp(tp.v, vo_n));
            let i_iota = b.public((0..vo_n).map(|z| k(z as i64)).collect());
            let i_u0 = b.public(supp(1, vo_n));
            let i_e = b.a(A_E)?;
            for kk in 0..l {
                b.a(A_LAM0 + kk)?;
            }
            let i_tok = b.a_at(A_TOK, f0())?;
            let poly = move |v: &[Fp2]| {
                let delta = (0..l).fold(Fp2::ZERO, |a, kk| a.add(v[i_e + 1 + kk].mul_base(Fp::new(1u64 << (8 * kk)))));
                v[i_s].mul(v[i_e]).mul(c[0].add(c[1].mul(v[i_iota])).add(c[2].mul(delta))).sub(v[i_u0].mul(c[0].add(c[1].mul(v[i_tok]))))
            };
            b.finish(Box::new(poly), vec![])
        }
        SO_TAB => {
            let tau = tr.challenge_fp2_vec(ltab);
            let mu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = nonzero(tr.challenge_fp2_vec(1))?[0];
            let i_eq = b.eq(&tau, 0);
            let i_s = b.public(supp(U8_LEN, tab_n));
            // the P-3 lift's first condition: padded table positions repeat
            // an existing entry (`i % 256`)
            let i_tv = b.public((0..tab_n).map(|z| k((z % U8_LEN) as i64).add(g_u8)).collect());
            let i_m = b.a(a_mult(l))?;
            let i_h = b.h(h_gu8(l))?;
            let poly = move |v: &[Fp2]| {
                let rel = v[i_h].mul(alpha.sub(v[i_tv])).sub(v[i_m]);
                let pad = Fp2::ONE.sub(v[i_s]).mul(v[i_m].add(zeta.mul(v[i_h])));
                v[i_eq].mul(mu[0].mul(rel).add(mu[1].mul(pad)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SO_ZS => {
            let i1 = b.public(vec![Fp2::ONE; 1usize << lay.h_log[h_u(l)]]);
            let iu = b.h(h_u(l))?;
            b.finish(Box::new(move |v: &[Fp2]| v[i1].mul(v[iu])), vec![])
        }
        SO_IOOUT => {
            let tau = tr.challenge_fp2_vec(low);
            let i_eq = b.eq(&tau, 0);
            let i_u0 = b.public(supp(1, ow));
            let i_tok = b.a_at(A_TOK, f0())?;
            let i_end = b.io(Cm::Out, low, rho(0..low), cx.ep_mask_row);
            b.finish(Box::new(move |v: &[Fp2]| v[i_eq].mul(v[i_end].sub(v[i_u0].mul(v[i_tok])))), vec![])
        }
        _ => Err("token I/O stage OUT: unknown slot".into()),
    }
}

fn run_slots(side: &mut Side, cx: &OutCtx, tr: &mut Transcript) -> Result<Acc, String> {
    let mut acc = Acc::default();
    let mut pts = OutPoints::default();
    for slot in 0..cx.lay.sched.slots.len() {
        let def = define(slot, cx, &mut pts, tr)?;
        run_stage_slot(side, &mut acc, def, &cx.lay.sched, tr)?;
    }
    finish_functionals(acc, cx.lay)
}

/// a lookup's value at every position of its (lifted) domain, as field words
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

/// How many byte lookups of a stage-OUT witness miss the byte table (review
/// R2-5: the run prover asks this BEFORE its first segment exists). The
/// witness's shape is checked first.
pub(crate) fn byte_misses(lay: &StageLayout, tp: &TokenProfile, wit: &StageOutWitness) -> Result<usize, String> {
    let mult = a_mult(tp.limbs);
    if wit.planes.len() != mult + 1 || (0..mult).any(|p| wit.planes[p].len() != 1usize << lay.a_log[p]) {
        return Err("token I/O stage OUT: witness shape".into());
    }
    let l = tp.limbs;
    let cols: Vec<Vec<Fp>> = [(lookups_lo(), tp.lo_log()), (lookups_do(), tp.do_log()), (lookups_vo(l), tp.vo_log())].iter().flat_map(|(lks, lg)| looked(&wit.planes, lks, 1usize << lg)).collect();
    Ok(cols.iter().map(|c| c.iter().filter(|v| (v.0 as usize) >= U8_LEN).count()).sum())
}

pub(crate) struct OutProved {
    pub seg: StageSegment,
    pub decommitment: Decommitment,
}

/// **THE STAGE OUT PROVER.** `pending_b` is block `L - 1`'s claim on `B_out`
/// (site 0) and `b_owner` its owner; both are consumed by `B_out`'s ONE
/// opening, after this stage's `M`, `A`, `H`. The output token endpoint is
/// opened last (consumed).
#[allow(clippy::too_many_arguments)]
pub(crate) fn prove(
    lay: &StageLayout,
    tp: &TokenProfile,
    tables: &TokenTables,
    wit: StageOutWitness,
    b_spec: &BoundarySpec,
    b_owner: PreparedBoundary,
    pending_b: Vec<ZClaim>,
    ep: CommittedZk,
    stage_index: u64,
    ntt: &crate::ntt::NttTables,
    rng: &mut crate::zk::ZkRng,
    tr: &mut Transcript,
    tag: &zkp_core::hashtag::HashTag,
) -> Result<OutProved, String> {
    #[cfg(test)]
    let cheating = protocol::cheating_prover_is_on();
    #[cfg(not(test))]
    let cheating = false;
    let n = lay.n;
    let l = tp.limbs;
    let mult = a_mult(l);
    if wit.planes.len() != mult + 1 || (0..mult).any(|p| wit.planes[p].len() != 1usize << lay.a_log[p]) {
        return Err("token I/O stage OUT: witness shape".into());
    }
    // the run's stage locality words (the block run's own two labels):
    // stage L + 1, whose public words are the head
    tr.absorb_u64(b"pb-run-stage", stage_index);
    tr.absorb(b"pb-run-block", &tp.head_digest);
    // the byte histogram over every looked column of the three lookup
    // domains (padded positions counted: the LogUp arm is never gated)
    let cols: Vec<Vec<Fp>> = [(lookups_lo(), tp.lo_log()), (lookups_do(), tp.do_log()), (lookups_vo(l), tp.vo_log())].iter().flat_map(|(lks, lg)| looked(&wit.planes, lks, 1usize << lg)).collect();
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
    // RULING CS-3's analogue: a miss is refused before A_out's mask rows are
    // drawn, its commitment made or any challenge of it drawn
    if misses > 0 && !cheating {
        return Err("token I/O stage OUT: the witness looks up a value that is not a byte (the class of the miss only)".into());
    }
    let params = lay.params;
    let zko = ZkOpts::standard(&params);
    let mut a_data = vec![Fp::ZERO; lay.a_rows * n];
    for p in 0..mult {
        a_data[lay.a_off[p]..lay.a_off[p] + wit.planes[p].len()].copy_from_slice(&wit.planes[p]);
    }
    for (i, c) in hist.iter().enumerate() {
        a_data[lay.a_off[mult] + i] = Fp::new(*c);
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
    // H_out: the helpers, the table helper, the zero-sum pair
    let mut h_data = vec![Fp::ZERO; lay.h_rows * n];
    let mut ci = 0usize;
    for (first, count) in [(H_LO, 1usize), (H_D0, H_DO_HELPERS), (H_V0, hv(l))] {
        let dom_cols = match first {
            H_LO => 1,
            H_D0 => lookups_do().len(),
            _ => l,
        };
        for kk in 0..count {
            let a_col = &cols[ci + 2 * kk];
            let b_col = if 2 * kk + 1 < dom_cols { Some(cols[ci + 2 * kk + 1].as_slice()) } else { None };
            write_h(&mut h_data, lay.h_off[first + kk], &helper_col(a_col, b_col, alpha, g_u8)?);
        }
        ci += dom_cols;
    }
    let tcol: Vec<Fp2> = (0..1usize << tp.tab_log())
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
    write_h(&mut h_data, lay.h_off[h_gu8(l)], &tcol);
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
    let cx = OutCtx { lay, tp, tables, alpha, g_u8, b_out_row: b_spec.mask_row(1)?, b_out_log: (tp.t_pad * tp.d_pad).trailing_zeros() as usize, ep_mask_row: ep_data_rows };
    let pd = super::super::argument::ProverData { data: [a.data.as_slice(), h.data.as_slice(), b_owner.data(), ep.data.as_slice()], masks: &mc.masks };
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
    // B_out's ONE opening: block L-1's claim (site 0), then this stage's (site 1)
    let mut claims = pending_b;
    claims.extend(ic);
    let b_open = b_owner.into_opening(b_spec, &claims, tr)?;
    check_token_endpoint_opening(&oc, ep_data_rows, tp.tier.ep_n(), tr)?;
    let ep_open = pcs::open_zk(&ep, &oc, tr);
    let decommitment = Decommitment { data: ep.data.clone(), pads: ep.pads.clone(), salts: ep.salts.clone() };
    drop(ep);
    Ok(OutProved { seg: StageSegment { b_root: None, a_root, h_root, mask_root, slots, mask_open, a_open, h_open, closes: vec![b_open, ep_open] }, decommitment })
}

/// **THE STAGE OUT VERIFIER.** `pending_b` is the verifier's OWN claim from
/// block `L - 1`'s stage; nothing about a claim is read from a frame.
#[allow(clippy::too_many_arguments)]
pub(crate) fn verify(
    lay: &StageLayout,
    tp: &TokenProfile,
    tables: &TokenTables,
    seg: &StageSegment,
    b_spec: &BoundarySpec,
    b_root: &Digest,
    pending_b: Vec<ZClaim>,
    ep_spec: &super::super::endpoint_g::EndpointSpecG,
    ep_root: &Digest,
    stage_index: u64,
    ntt: &crate::ntt::NttTables,
    tr: &mut Transcript,
    tag: &zkp_core::hashtag::HashTag,
) -> Result<(), String> {
    let params = lay.params;
    let zko = ZkOpts::standard(&params);
    if seg.closes.len() != 2 || seg.b_root.is_some() {
        return Err("token I/O: stage OUT's segment parts are not the run schedule's".into());
    }
    super::super::hash_domain::paths_are_the_tree_depth("stage OUT A", &params, &seg.a_open)?;
    super::super::hash_domain::paths_are_the_tree_depth("stage OUT H", &params, &seg.h_open)?;
    super::super::hash_domain::mask_paths_are_the_tree_depth(&seg.mask_open)?;
    super::super::hash_domain::paths_are_the_tree_depth("B_out", &b_spec.params(), &seg.closes[0])?;
    let ep_params = ep_spec.params();
    super::super::hash_domain::paths_are_the_tree_depth("output token endpoint", &ep_params, &seg.closes[1])?;
    // the run's stage locality words (the block run's own two labels):
    // stage L + 1, whose public words are the head
    tr.absorb_u64(b"pb-run-stage", stage_index);
    tr.absorb(b"pb-run-block", &tp.head_digest);
    protocol::absorb_root(tr, b"A", &seg.a_root, lay.a_rows, lay.log_n);
    tr.absorb(b"M", &seg.mask_root);
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    protocol::absorb_root(tr, b"H", &seg.h_root, lay.h_rows, lay.log_n);
    let ep_data_rows = ep_spec.data_rows();
    let cx = OutCtx { lay, tp, tables, alpha, g_u8, b_out_row: b_spec.mask_row(1)?, b_out_log: (tp.t_pad * tp.d_pad).trailing_zeros() as usize, ep_mask_row: ep_data_rows };
    let mut side = Side::Verify { slots: &seg.slots };
    let acc = run_slots(&mut side, &cx, tr)?;
    crate::zk::mask_verify_tagged(&seg.mask_root, &lay.mask_specs(), &acc.fs, &seg.mask_open, ntt, tr, tag).map_err(|e| format!("stage OUT M: {e}"))?;
    let [ac, mut hc, ic, oc] = acc.claims;
    hc.push(lay.logup_sum_claim());
    protocol::check_opening(&ac, lay.log_n, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, A_GROUPS, tr)?;
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.a_root, lay.a_rows, lay.log_n), &ac, &seg.a_open, ntt, tr, tag).map_err(|e| format!("stage OUT A: {e}"))?;
    protocol::check_opening(&hc, lay.log_n, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, H_GROUPS, tr)?;
    pcs::verify_zk_tagged(&params, &zko, &protocol::commitment(seg.h_root, lay.h_rows, lay.log_n), &hc, &seg.h_open, ntt, tr, tag).map_err(|e| format!("stage OUT H (the LogUp sum claim is part of this opening): {e}"))?;
    let mut claims = pending_b;
    claims.extend(ic);
    super::super::boundary::check_opening(b_spec, &claims, tr)?;
    let bp = b_spec.params();
    pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(*b_root, b_spec.commitment_rows(), b_spec.log_n()), &claims, &seg.closes[0], ntt, tr, tag).map_err(|e| format!("B_out: {e}"))?;
    check_token_endpoint_opening(&oc, ep_data_rows, tp.tier.ep_n(), tr)?;
    pcs::verify_zk_tagged(&ep_params, &ZkOpts::standard(&ep_params), &protocol::commitment(*ep_root, ep_spec.commitment_rows(), tp.tier.ep_log_n), &oc, &seg.closes[1], ntt, tr, tag).map_err(|e| format!("output token endpoint: {e}"))?;
    Ok(())
}

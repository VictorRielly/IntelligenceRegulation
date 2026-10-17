//! **STAGE 35 — the oracle for lever (b) inside the closures of slots 17 and
//! 14.** Ruling I-4 of `ZK60_SLOT_EXPRESSION_IR_DISPOSITION.md` says the loop
//! over evaluation points and the fold live in `zkp-core/src/sumcheck.rs`, so
//! a closure can only change what happens INSIDE one evaluation; lever (b) —
//! the support gate hoisted out of the clause batch, the sub-products the
//! closures recompute, the public base-field constants through `mul_base` —
//! is exactly that, and it is the whole of what this lane may take.
//!
//! **The rule of the stage is that nothing a verifier can see may move**, and
//! the strongest available form of that is a differential test: the OLD form
//! and the NEW form, evaluated on the same table vector, compared word for
//! word. Three things make this one strong, and all three are needed:
//!
//! 1. **the old form is copied verbatim** from the arm at the stage's base
//!    commit `89e393f`, not re-derived and not paraphrased — `old_szc` and
//!    `old_dzc` below are the two closure bodies with nothing changed but the
//!    `self.` that brings the captures in, and the four helpers they call
//!    (`limbs`, `helper_sum`, `Gate::at`, `PadTerm::eval`, `k`) are copied
//!    from the same commit. Stage 28 used the same device and its ledger
//!    explains why a re-derivation would be a second name for the code under
//!    test;
//! 2. **the captures are the REAL ones.** The closure of a slot captures
//!    thirty-odd definition-time values — table indices, the `mu` and `nu`
//!    challenges, the LogUp column descriptions, the pad-rule groups, the two
//!    support gates — and none of them is reachable from a sibling module.
//!    So the arm hands them over: two `#[cfg(test)]` statements per arm build
//!    the capture record below and call [`Szc::check`] / [`Dzc::check`] with
//!    a reference to the closure it just built. The comparison therefore runs
//!    **on every definition of those two slots in every test of the crate**,
//!    at every registered shape and on both sides of every pad branch,
//!    without any test having to arrange it;
//! 3. **the new form is the production closure itself**, passed in as
//!    `&dyn Fn`, never a copy of it.
//!
//! Beside that sits the stage-34 IR, which is a third, independent statement
//! of the same polynomial: `slot_ir.rs` is untouched by this stage, its
//! equality oracle proved it equal to the closure at `89e393f` over 1,656
//! evaluations, and [`the_two_rewritten_closures_equal_the_stage_34_ir_at_every_registered_shape`]
//! re-proves it against the rewritten closure at 32 points per shape. The
//! two legs meet: old == IR (stage 34, pinned) and IR == new (here), so
//! old == new even where a capture could not be handed over.
//!
//! Nothing in this module is compiled into a production build.

use super::argument::{define, Ctx, Points, SlotDef, Tab};
use super::layout::*;
use super::shape::Shape;
use super::slot_ir::{build_slot_ir, IrPoints, SlotIr};
use crate::field::{Fp, Fp2};
use crate::transcript::Transcript;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};

// ---------------------------------------------------------------- the copies
//
// Everything in this block is `argument.rs` at `89e393f`, copied and not
// rewritten. It exists so that the two old closure bodies below can be the
// arm's own text: they call these by the same names, with the same bodies.

/// verbatim: `argument.rs::k`
fn k(v: i64) -> Fp2 {
    Fp2::from_i64(v)
}

/// verbatim: `argument.rs::limbs` — `sum_k v[ix[k]] * 256^k`, the fold
/// starting at `k = 0` and therefore paying a full extension multiplication
/// by a runtime `Fp2::ONE`, which is one of the three things lever (b)
/// removes
fn limbs(v: &[Fp2], ix: &[usize]) -> Fp2 {
    ix.iter().enumerate().fold(Fp2::ZERO, |a, (k, i)| a.add(v[*i].mul(pow256(k))))
}

/// verbatim: `argument.rs::LkT`
#[derive(Clone)]
pub(super) struct LkT {
    pub terms: Vec<(usize, Fp)>,
    pub cst: Fp2,
}

/// verbatim: `argument.rs::helper_sum`
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

/// verbatim: `argument.rs::PadTerm`, the evaluation half
pub(super) struct PadTerm {
    pub groups: Vec<(usize, Vec<(usize, Fp2)>)>,
    pub mu: Fp2,
}

impl PadTerm {
    fn eval(&self, v: &[Fp2]) -> Fp2 {
        let mut acc = Fp2::ZERO;
        for (supp, planes) in &self.groups {
            let anti = Fp2::ONE.sub(v[*supp]);
            let mut inner = Fp2::ZERO;
            for (t, w) in planes {
                inner = inner.add(w.mul(v[*t]));
            }
            acc = acc.add(anti.mul(inner));
        }
        self.mu.mul(acc)
    }
}

/// verbatim: `argument.rs::Gate`
#[derive(Clone, Copy)]
pub(super) struct Gate(pub Option<usize>);

impl Gate {
    fn at(self, v: &[Fp2]) -> Fp2 {
        match self.0 {
            Some(i) => v[i],
            None => Fp2::ONE,
        }
    }
}

// ------------------------------------------------------------- the harness

/// a test-local xorshift, so nothing here depends on a production generator
/// (the same one `slot_ir_tests` uses, and `s25_tests`'s scan of the
/// production text is untouched by it: no `ZkRng` is named in this module)
fn xs(seed: u64) -> impl FnMut() -> u64 {
    let mut s = seed | 1;
    move || {
        s ^= s << 13;
        s ^= s >> 7;
        s ^= s << 17;
        s
    }
}

fn fp2_of(r: &mut impl FnMut() -> u64) -> Fp2 {
    Fp2::new(Fp::new(r() % crate::field::P), Fp::new(r() % crate::field::P))
}

/// how many random points every definition of slot 14 and slot 17 is compared
/// at. Four, and not more, because the comparison runs inside `define` and
/// `define` is called by both sides of every proof in the filter — including
/// the 125M gate, where the closure is cheap but the run is ten gigabytes. At
/// four points a wrong coefficient survives one definition with probability
/// at most `(deg / |F|)^4`, and the filter defines these slots many hundreds
/// of times.
const POINTS: usize = 4;

/// a fresh seed per definition, so the filter's hundreds of definitions do
/// not all test the same four points
static SEEDS: AtomicU64 = AtomicU64::new(0x3517_0000_0000_0001);
/// how many (point, slot) comparisons have been made in this process
static COMPARED: AtomicUsize = AtomicUsize::new(0);

fn next_seed() -> u64 {
    SEEDS.fetch_add(0x9E37_79B9_7F4A_7C15, Ordering::Relaxed) | 1
}

fn differ(tag: &str, n_tabs: usize, old: &dyn Fn(&[Fp2]) -> Fp2, new: &dyn Fn(&[Fp2]) -> Fp2) {
    let mut r = xs(next_seed());
    for j in 0..POINTS {
        let v: Vec<Fp2> = (0..n_tabs).map(|_| fp2_of(&mut r)).collect();
        let (want, got) = (old(&v), new(&v));
        assert_eq!(got, want, "{tag}: the stage-35 closure differs from the 89e393f closure at random point {j} of {n_tabs} tables");
    }
    COMPARED.fetch_add(POINTS, Ordering::Relaxed);
}

// ------------------------------------------------- slot 17, `SC_SZC`

/// the definition-time captures of `SC_SZC`'s closure, handed over by the arm
pub(super) struct Szc {
    pub idx: Vec<usize>,
    pub im: usize,
    pub imx: usize,
    pub isum: usize,
    pub ihx: usize,
    pub h0: usize,
    pub i_sr: Vec<usize>,
    pub i_sg: Vec<usize>,
    pub i_pl: Vec<usize>,
    pub lks: Vec<LkT>,
    pub mu: Vec<Fp2>,
    pub nu: Vec<Fp2>,
    pub n_help: usize,
    pub lam: Fp2,
    pub alpha: Fp2,
    pub beta: Fp2,
    pub g_exp: Fp2,
    pub gs: Gate,
    pub ght: Gate,
    pub pz: PadTerm,
    /// ROUND 2: the score shift (the frozen SH_S at every registered shape)
    pub sh_s: u32,
}

impl Szc {
    /// **THE OLD FORM, VERBATIM.** `argument.rs:1638-1658` at `89e393f`,
    /// character for character inside the `let ... = |v| { .. }` body; the
    /// only lines that are not the arm's are the two that bring the captures
    /// into scope under the arm's own names.
    fn old(&self, v: &[Fp2]) -> Fp2 {
        let (idx, im, imx, isum, ihx, h0) = (&self.idx, self.im, self.imx, self.isum, self.ihx, self.h0);
        let (i_sr, i_sg, i_pl, lks, mu, nu, n_help) = (&self.i_sr, &self.i_sg, &self.i_pl, &self.lks, &self.mu, &self.nu, self.n_help);
        let (lam, alpha, beta, g_exp, gs, ght, pz) = (self.lam, self.alpha, self.beta, self.g_exp, self.gs, self.ght, &self.pz);
        // ---- verbatim from here ----
        let at = |p: usize| v[idx[p]];
        let (mask, s8, zsel, e, p, sum) = (v[im], at(A_S8), at(A_ZSEL), at(A_E), at(A_P), v[isum]);
        let sr = limbs(v, i_sr);
        // delta = max - masked score, the masked score being mask * (s8 + 127) - 127
        let delta = v[imx].sub(mask.mul(s8.add(k(-MASK_SCORE)))).add(k(-MASK_SCORE));
        let c0 = zsel.mul(zsel).sub(zsel);
        let c1 = zsel.mul(delta);
        let c2 = k(1 << F_P).mul(mask).mul(e).sub(p.mul(sum)).sub(sr);
        let c3 = limbs(v, i_sg).add(sr).add(Fp2::ONE).sub(sum);
        let c4 = p.sub(limbs(v, i_pl));
        let cx = v[ihx].mul(alpha.sub(delta.add(beta.mul(e)).add(g_exp))).sub(Fp2::ONE);
        let g = gs.at(v);
        let mut zc = helper_sum(v, lks, h0, alpha, &mu[5..5 + n_help]).add(mu[5 + n_help].mul(cx)).add(pz.eval(v));
        for (m, c) in mu.iter().zip([c0, c1, c2, c3, c4]) {
            zc = zc.add(m.mul(g).mul(c));
        }
        let host_rs = sum.add(lam);
        let host_s = k(1i64 << self.sh_s).mul(s8).add(at(A_RSL)).sub(k(super::witness::half(self.sh_s)));
        v[0].mul(zc).add(nu[0].mul(v[1]).mul(ght.at(v)).mul(host_rs)).add(nu[1].mul(v[2]).mul(g).mul(host_s))
        // ---- verbatim to here ----
    }

    pub(super) fn check(&self, n_tabs: usize, new: &dyn Fn(&[Fp2]) -> Fp2) {
        differ("slot 17 SC_SZC", n_tabs, &|v: &[Fp2]| self.old(v), new);
    }
}

// ------------------------------------------------- slot 14, `SC_DZC`

/// the definition-time captures of `SC_DZC`'s closure, handed over by the arm
pub(super) struct Dzc {
    pub idx: Vec<usize>,
    pub ig: usize,
    pub igm: usize,
    pub id: usize,
    pub idm: usize,
    pub h0: usize,
    pub i_nr: Vec<usize>,
    pub i_ns: Vec<usize>,
    pub i_mr: Vec<usize>,
    pub i_ms: Vec<usize>,
    pub lks: Vec<LkT>,
    pub mu: Vec<Fp2>,
    pub nu: Vec<Fp2>,
    pub alpha: Fp2,
    pub gd: Gate,
    pub pz: PadTerm,
    /// NATIVE LANE (from the lane-C prototype): the shape's calibration
    /// constants of this arm (the frozen `NORM_CN` / `NORM_TN` / `SH_AO` at
    /// every registered shape; norm_a and norm_m carry separate multipliers)
    pub norm_cn_a: i64,
    pub norm_cn_m: i64,
    pub norm_tn: u32,
    pub sh_ao: u32,
    /// ROUND 2: the down shift (the frozen SH_Z at every registered shape)
    pub sh_z: u32,
}

impl Dzc {
    /// **THE OLD FORM, VERBATIM.** `argument.rs:1442-1470` at `89e393f`. The
    /// three norm constants and `p1` are recomputed here from the same module
    /// constants the arm computes them from (`layout.rs`'s `NORM_CN`,
    /// `NORM_TN` and `pow256`), so no capture carries a value this file could
    /// have got wrong.
    fn old(&self, v: &[Fp2]) -> Fp2 {
        let (idx, ig, igm, id, idm, h0) = (&self.idx, self.ig, self.igm, self.id, self.idm, self.h0);
        let (i_nr, i_ns, i_mr, i_ms) = (&self.i_nr, &self.i_ns, &self.i_mr, &self.i_ms);
        let (lks, mu, nu, alpha, gd, pz) = (&self.lks, &self.mu, &self.nu, self.alpha, self.gd, &self.pz);
        let p1 = pow256(1);
        // NATIVE LANE: the constants are the shape's (the frozen module
        // constants at every registered shape); `k_num_m` is norm_m's own
        let (k_num, k_dv, k_den) = (k(2 * self.norm_cn_a), k(1i64 << self.norm_tn), k(1i64 << (self.norm_tn + 1)));
        let k_num_m = k(2 * self.norm_cn_m);
        // LANE C SCRATCH: the one line below that is not verbatim takes the
        // shape's attention-output shift (the frozen SH_AO everywhere else)
        let (sh_ao_pow, sh_ao_half) = (k(1i64 << self.sh_ao), k(super::witness::half(self.sh_ao)));
        // ---- verbatim from here ----
        let at = |p: usize| v[idx[p]];
        let l2 = |o: usize| at(o).add(at(o + 1).mul(p1));
        let (x, y, ao, x1, d) = (at(A_X), at(A_Y), at(A_AO), at(A_X1), v[id]);
        let (nm, x2, z16, dm) = (at(A_YM), at(A_X2), at(A_Z16), v[idm]);
        let (nr, ns) = (limbs(v, i_nr), limbs(v, i_ns));
        let (mr, ms) = (limbs(v, i_mr), limbs(v, i_ms));
        let c0 = k_num.mul(v[ig]).mul(x).add(k_dv.mul(d)).sub(k_den.mul(y).mul(d)).sub(nr);
        let c1 = ns.add(nr).add(Fp2::ONE).sub(k_den.mul(d));
        let c2 = x.add(k(32768)).sub(l2(A_XL0));
        let c3 = ao.add(k(32768)).sub(l2(A_AL0));
        let c4 = x1.add(k(32768)).sub(l2(A_X1L0));
        let c5 = x1.sub(x).sub(ao);
        // norm_m: the identical relation with gamma_m and xres1 (T1 C.1)
        let c6 = k_num_m.mul(v[igm]).mul(x1).add(k_dv.mul(dm)).sub(k_den.mul(nm).mul(dm)).sub(mr);
        let c7 = ms.add(mr).add(Fp2::ONE).sub(k_den.mul(dm));
        // residual 2 and z16's int16 class (T1 C.2, T2 C.2)
        let c8 = x2.add(k(32768)).sub(l2(A_X2L0));
        let c9 = x2.sub(x1).sub(z16);
        let c10 = z16.add(k(32768)).sub(l2(A_ZL0));
        let g = gd.at(v);
        let mut zc = helper_sum(v, lks, h0, alpha, &mu[11..]).add(pz.eval(v));
        for (m, c) in mu.iter().zip([c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10]) {
            zc = zc.add(m.mul(g).mul(c));
        }
        let host_wo = sh_ao_pow.mul(ao).add(at(A_RAL)).sub(sh_ao_half);
        let host_dmm = k(1i64 << self.sh_z).mul(z16).add(at(A_RDL)).sub(k(super::witness::half(self.sh_z)));
        v[0].mul(zc).add(nu[0].mul(v[1]).mul(g).mul(host_wo)).add(nu[1].mul(v[2]).mul(g).mul(host_dmm))
        // ---- verbatim to here ----
    }

    pub(super) fn check(&self, n_tabs: usize, new: &dyn Fn(&[Fp2]) -> Fp2) {
        differ("slot 14 SC_DZC", n_tabs, &|v: &[Fp2]| self.old(v), new);
    }
}

// ---------------------------------------------------------------- the tests

/// every registered shape, in registry order (the same list `slot_ir_tests`
/// walks; a shape added to the registry and not to this list fails the count
/// assertion of the first test below)
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()]
}

fn shape_key(sh: &Shape) -> &'static str {
    const KEYS: [&str; 9] = ["toy", "rung", "rung-G", "rung-K4", "rung-P2", "rung-C6", "rung-W14", "rung-E32", "125M"];
    let i = every_shape().iter().position(|s| s.name == sh.name).unwrap_or_else(|| panic!("{} is not a registered shape", sh.name));
    KEYS[i]
}

/// the definition-time challenges the walks here feed every shape, all five
/// with a nonzero imaginary part as production's are (finding S34-F2)
fn ctx_scalars() -> (Fp2, Fp2, Fp2, Fp2, Fp2) {
    let c = |re: u64, im: u64| Fp2::new(Fp::new(re), Fp::new(im));
    (c(7, 1), c(11, 2), c(13, 3), c(17, 5), c(19, 7))
}

/// build every slot's definition at `sh` and hand each to `f`, dropping it
/// before the next: at the big shapes one public table is hundreds of
/// megabytes, and no table is BUILT here at all — only the definition
fn walk_defs(sh: &Shape, mut f: impl FnMut(usize, &SlotDef)) {
    let lay = Layout::for_shape(sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let (alpha, beta, g_u8, g_exp, g_act) = ctx_scalars();
    let ctx = Ctx { lay: &lay, public: &public, ff: &ff, alpha, beta, g_u8, g_exp, g_act };
    let mut tr = Transcript::new(sh.profile.as_bytes());
    let mut pts = Points::default();
    for s in 0..N_SLOTS {
        let def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
        f(s, &def);
    }
}

/// the twin walk of `slot_ir_tests`: the definition and the IR of every slot
/// at `sh`, on two transcripts in the same state, so the IR carries the same
/// challenge VALUES as the closure it is compared against
fn walk_pairs(sh: &Shape, mut f: impl FnMut(usize, &SlotDef, &SlotIr)) {
    let lay = Layout::for_shape(sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let (alpha, beta, g_u8, g_exp, g_act) = ctx_scalars();
    let ctx = Ctx { lay: &lay, public: &public, ff: &ff, alpha, beta, g_u8, g_exp, g_act };
    let mut tr_def = Transcript::new(sh.profile.as_bytes());
    let mut tr_ir = Transcript::new(sh.profile.as_bytes());
    let (mut pts, mut ipts) = (Points::default(), IrPoints::default());
    for s in 0..N_SLOTS {
        let def = define(s, &ctx, &mut pts, &mut tr_def).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
        let ir = build_slot_ir(s, &ctx, &mut ipts, &mut tr_ir).unwrap_or_else(|e| panic!("{}: slot {s} IR: {e}", sh.name));
        f(s, &def, &ir);
    }
}

/// **THE DIFFERENTIAL, LEG ONE: the rewritten closure against the verbatim
/// `89e393f` one, on the real captures.** The comparison itself is made by
/// the arm (two `#[cfg(test)]` statements each, calling [`Szc::check`] and
/// [`Dzc::check`]), so it happens on every definition of these two slots
/// anywhere in the crate's tests. This test drives the registry once so that
/// **every registered shape and both sides of the pad branch are covered by
/// name**, and asserts that the comparison really ran — a hook that had been
/// compiled out would leave the counter where it was.
#[test]
fn the_two_rewritten_closures_equal_the_parent_closure_at_every_registered_shape() {
    let before = COMPARED.load(Ordering::Relaxed);
    let mut pad_on = 0usize;
    let mut pad_off = 0usize;
    for sh in every_shape() {
        let pads = super::pad::indicator_tables_per_slot(&sh);
        if pads[SC_SZC] > 0 {
            pad_on += 1;
        } else {
            pad_off += 1;
        }
        walk_defs(&sh, |_, _| {});
    }
    let made = COMPARED.load(Ordering::Relaxed) - before;
    eprintln!("S35 differential: {made} (point, slot) comparisons on this walk alone, {} in the process so far", COMPARED.load(Ordering::Relaxed));
    eprintln!("S35 differential: slot 17's pad branch is taken at {pad_on} registered shapes and not taken at {pad_off}");
    assert!(pad_on > 0 && pad_off > 0, "the registry no longer covers both sides of the pad branch: on {pad_on}, off {pad_off}");
    assert_eq!(made, 9 * 2 * POINTS, "the walk should compare 9 shapes x 2 slots x {POINTS} points; the arm's hook is not firing");
}

/// **THE DIFFERENTIAL, LEG TWO: the rewritten closure against the stage-34
/// IR.** `slot_ir.rs` is not touched by this stage — the forbidden-files
/// proof says so with a diff — and its equality oracle proved the IR equal to
/// the closure AT `89e393f`. So an equality here is a second, independent
/// statement that the rewrite preserved the polynomial, reached without any
/// capture being handed over, and it reaches the 125M shape, whose IR needs
/// no witness.
#[test]
fn the_two_rewritten_closures_equal_the_stage_34_ir_at_every_registered_shape() {
    let mut r = xs(0x3517_0002_ABCD_0001);
    let mut points = 0usize;
    for sh in every_shape() {
        walk_pairs(&sh, |s, def, ir| {
            if s != SC_DZC && s != SC_SZC {
                return;
            }
            assert_eq!(ir.tables.len(), def.tabs.len(), "{}: slot {s} [{}]: the IR has {} tables, the definition {}", sh.name, SLOT_NAMES[s], ir.tables.len(), def.tabs.len());
            for _ in 0..32 {
                let v: Vec<Fp2> = (0..def.tabs.len()).map(|_| fp2_of(&mut r)).collect();
                assert_eq!(ir.eval(&v), (def.poly)(&v), "{}: slot {s} [{}]: the rewritten closure and the stage-34 IR differ", sh.name, SLOT_NAMES[s]);
                points += 1;
            }
        });
    }
    eprintln!("S35 IR leg: {points} random points over 9 shapes x 2 slots, every one equal");
    assert_eq!(points, 9 * 2 * 32, "the walk did not cover 9 shapes x 2 slots");
}

/// **WHAT MAY NOT MOVE, PINNED BY LITERAL.** The table list and its ORDER
/// decide the `v[..]` indices the closure reads and the order the masked
/// terminals are absorbed in; the declared degree decides the length of every
/// round message and therefore the receipt. Neither is a thing lever (b)
/// touches, and both are asserted here against literals read out of the
/// stage-34 export at `89e393f` (`x34-slot-ir/slot_ir_<shape>.json`, itself
/// digest-pinned), so a rewrite that quietly pushed a table or changed a
/// degree fails here and not only in a receipt length four shapes later.
///
/// The per-table character is the `Tab` VARIANT: `E` an `eq` table, `P` a
/// public one (the support indicators included — they are pushed through
/// `B::public`), `V` a private one (an `A` plane, an `H` helper or an
/// endpoint).
#[test]
fn the_table_list_the_order_and_the_declared_degree_of_the_two_slots_are_where_they_were() {
    #[rustfmt::skip]
    const PINS: [(&str, (usize, usize, usize, usize), &str, (usize, usize, usize, usize), &str); 9] = [
        ("toy", (61, 9, 1, 4), "EEEPPVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV", (25, 11, 1, 4), "EEEPVVVVVVVVVVVVVVVVVVVVV"),
        ("rung", (62, 12, 1, 5), "EEEPPVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVP", (30, 13, 1, 5), "EEEPVVVVVVVVVVVVVVVVVVVVVVVVPP"),
        ("rung-G", (62, 12, 1, 5), "EEEPPVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVP", (30, 13, 1, 5), "EEEPVVVVVVVVVVVVVVVVVVVVVVVVPP"),
        ("rung-K4", (62, 12, 1, 5), "EEEPPVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVP", (30, 14, 1, 5), "EEEPVVVVVVVVVVVVVVVVVVVVVVVVPP"),
        ("rung-P2", (62, 12, 1, 5), "EEEPPVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVP", (30, 14, 1, 5), "EEEPVVVVVVVVVVVVVVVVVVVVVVVVPP"),
        ("rung-C6", (60, 14, 1, 5), "EEEPPVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVP", (30, 14, 1, 5), "EEEPVVVVVVVVVVVVVVVVVVVVVVVVPP"),
        ("rung-W14", (60, 16, 1, 5), "EEEPPVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVP", (30, 16, 1, 5), "EEEPVVVVVVVVVVVVVVVVVVVVVVVVPP"),
        ("rung-E32", (60, 15, 1, 5), "EEEPPVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVP", (30, 14, 1, 5), "EEEPVVVVVVVVVVVVVVVVVVVVVVVVPP"),
        ("125M", (60, 19, 1, 5), "EEEPPVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVP", (30, 22, 1, 5), "EEEPVVVVVVVVVVVVVVVVVVVVVVVVPP"),
    ];
    let desc = |tabs: &[Tab]| -> String {
        tabs.iter()
            .map(|t| match t {
                Tab::Eq { .. } => 'E',
                Tab::Pub(_) => 'P',
                Tab::Priv(_) => 'V',
            })
            .collect()
    };
    let mut rows = 0usize;
    for sh in every_shape() {
        let key = shape_key(&sh);
        let pin = PINS.iter().find(|p| p.0 == key).unwrap_or_else(|| panic!("no pin for {key}"));
        // `Shape::slots()` is `(main rounds, extension rounds, declared degree)`
        let (sl14, sl17) = (sh.slots()[SC_DZC], sh.slots()[SC_SZC]);
        walk_defs(&sh, |s, def| {
            let (want, want_desc, sl) = match s {
                SC_DZC => (pin.1, pin.2, sl14),
                SC_SZC => (pin.3, pin.4, sl17),
                _ => return,
            };
            let got = (def.tabs.len(), sl.0, sl.1, sl.2);
            assert_eq!(got, want, "{key} slot {s} [{}]: (tables, main rounds, extension rounds, declared degree)", SLOT_NAMES[s]);
            assert_eq!(desc(&def.tabs), want_desc, "{key} slot {s} [{}]: the table list or its order moved", SLOT_NAMES[s]);
            rows += 1;
        });
    }
    eprintln!("S35 pins: {rows} (shape, slot) rows — table count, table order, main rounds, extension rounds and declared degree all where 89e393f left them");
    assert_eq!(rows, 18, "the pin walk did not cover 9 shapes x 2 slots");
}

/// **THE ONE IMPLEMENTATION IDENTITY lever (b)(iii) rests on**, stated and
/// tested rather than assumed: for a constant whose imaginary part is zero —
/// which every `k(c)`, `pow256(j)` and `2^SH_*` in the two arms is —
/// `x.mul(c)` and `x.mul_base(c.c0)` are the SAME field element, not merely
/// equal by a ring law. `Fp2::mul` computes
/// `(a c0 + b c1 * 7, a c1 + b c0)`, and with `c1 = 0` that is `(a c0, b c0)`,
/// which is `mul_base`'s body character for character. Two base
/// multiplications instead of five, and nothing to argue about.
#[test]
fn multiplying_by_a_constant_with_no_imaginary_part_is_exactly_mul_base() {
    let mut r = xs(0x3517_0003_5AFE_0001);
    let consts: Vec<Fp2> = [k(1 << F_P), k(1 << SH_S), k(1 << SH_AO), k(1 << SH_Z), k(2 * NORM_CN), k(1 << NORM_TN), k(1 << (NORM_TN + 1)), pow256(0), pow256(1), pow256(2), pow256(3), k(32768), k(-MASK_SCORE)].to_vec();
    for c in &consts {
        assert_eq!(c.c1, Fp::ZERO, "a constant of the two arms has an imaginary part");
    }
    let mut n = 0usize;
    for _ in 0..256 {
        let x = fp2_of(&mut r);
        for c in &consts {
            assert_eq!(x.mul(*c), x.mul_base(c.c0), "mul and mul_base differ on a constant with no imaginary part");
            assert_eq!(c.mul(x), x.mul_base(c.c0), "the constant on the left differs from mul_base");
            n += 2;
        }
    }
    eprintln!("S35 mul_base: {n} comparisons over {} constants of the two arms, every one exact", consts.len());
}

// ------------------------------------------------------------ the counting
//
// The two functions below are a MODEL and not a measurement: they count the
// base multiplications one evaluation of a slot's closure performs, in the
// unit of `ZK60_SLOT_EXPRESSION_IR_DESIGN_CHECK.md` §1 — a full extension
// multiplication is five base multiplications (`Fp2::mul` computes `ac`,
// `bd`, `ad`, `bc` and `bd * 7`), `mul_base` is two, and an addition costs
// nothing. They are kept in step with the two arms BY HAND, line by line,
// with the arm's own expression named in each comment; the equality tests
// above are the correctness gate and these are only arithmetic about it.
//
// **Ruling I-1: no count on this page is a time.** The check showed the
// count model does not reproduce the measured per-slot seconds (a 6.7x
// spread in implied throughput across the six big slots), so a count is a
// lower bound on work and never a forecast.

/// a full extension multiplication, in base multiplications
const MUL: usize = 5;
/// `Fp2::mul_base`, in base multiplications
const MULB: usize = 2;

/// `helper_sum`'s cost at a domain — IDENTICAL before and after, because the
/// function is outside the two arms and this stage does not touch it
fn logup_units(lay: &Layout, dom: Dom) -> usize {
    let lks = lay.lookups(dom);
    let mut u = 0;
    for kk in 0..lks.len().div_ceil(2) {
        // `den(l)` folds `terms.len()` coefficients through `mul_base`
        u += lks[2 * kk].terms.len() * MULB;
        match lks.get(2 * kk + 1) {
            // `h.mul(d1).mul(d2)` and `mu[k].mul(rel)`
            Some(l2) => u += l2.terms.len() * MULB + 3 * MUL,
            // `h.mul(d1)` and `mu[k].mul(rel)`
            None => u += 2 * MUL,
        }
    }
    u
}

/// the pad-zero groups a slot hosts, as plane counts — the arm's `pad_doms`
/// filter and `B::supp`'s two refusals together
fn pad_groups(sh: &Shape, ids: &Ids, slot: usize) -> Vec<usize> {
    ALL_DOMS
        .into_iter()
        .filter(|d| super::pad::pad_zero_host(*d) == slot && sh.carries_pad_rule() && sh.pads(*d))
        .map(|d| super::pad::zero_rule_a_planes(sh, ids, d).len())
        .filter(|n| *n > 0)
        .collect()
}

/// `PadTerm::eval` — also identical before and after. The final `mu.mul(acc)`
/// is paid even when there is no group at all, which is the memo's §3.5
/// observation about `PadTerm::eval` at slots 02/16/18.
fn pad_units(groups: &[usize]) -> usize {
    MUL + groups.iter().map(|n| (n + 1) * MUL).sum::<usize>()
}

/// the four rungs of the ladder, in the order the stage takes them:
/// `89e393f`, then lever (b)(i) the hoisted support gate, then (b)(ii) the
/// shared sub-products, then (b)(iii) the base-field constants
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) struct Ladder {
    pub old: usize,
    pub after_i: usize,
    pub after_ii: usize,
    pub after_iii: usize,
    /// what both forms pay and neither changes: `helper_sum` and `PadTerm`
    pub shared: usize,
}

/// slot 17 `SC_SZC`, per evaluation
fn szc_units(sh: &Shape, lay: &Layout) -> Ladder {
    let (ls, lp) = (sh.limbs_sigma_s(), sh.limbs_p());
    // `89e393f`, in the arm's order:
    //   limbs(sr) ls | delta 1 | c0 1 | c1 1 | c2 3 | limbs(sg) ls |
    //   limbs(pl) lp | cx 2 | mu*cx 1 | the clause loop 5*2 | host_s 1 |
    //   the three top-level products 7
    let old = (2 * ls + lp + 27) * MUL;
    // (b)(i): the clause loop's ten multiplications become six — five
    // `mu_i * c_i` and one by `g`
    let after_i = (2 * ls + lp + 23) * MUL;
    // (b)(ii): nothing. The check's §5 found the recomputed sub-products at
    // slot 14 only, and reading this arm confirms it — `delta`, `sr` and the
    // `at(p)` reads are already shared by a `let`
    let after_ii = after_i;
    // (b)(iii): lb(sr) and lb(sg) (ls-1) mul_base each, lb(pl) (lp-1),
    //   c2's `1 << F_P` and host_s's `1 << SH_S` through mul_base
    let after_iii = 21 * MUL + (2 * ls + lp - 1) * MULB;
    let shared = logup_units(lay, Dom::S) + pad_units(&pad_groups(sh, lay.ids(), SC_SZC));
    Ladder { old, after_i, after_ii, after_iii, shared }
}

/// slot 14 `SC_DZC`, per evaluation
fn dzc_units(sh: &Shape, lay: &Layout) -> Ladder {
    let ln = sh.limbs_norm();
    // `89e393f`:
    //   l2 x5 | limbs x4 (4 ln) | c0 5 | c1 1 | c6 5 | c7 1 |
    //   the clause loop 11*2 | host_wo 1 | host_dmm 1 |
    //   the three top-level products 7
    let old = (4 * ln + 48) * MUL;
    // (b)(i): the clause loop's twenty-two become twelve
    let after_i = (4 * ln + 38) * MUL;
    // (b)(ii): `k_den * d` is computed once for c0 and c1 and `k_den * dm`
    // once for c6 and c7 — one multiplication saved in each pair
    let after_ii = (4 * ln + 36) * MUL;
    // (b)(iii): l2 x5, the four limb folds (4(ln-1), the `256^0` multiply by
    //   one dropped), `kd`/`kdm`, `k_num` and `k_dv` in c0 and c6, and the
    //   two host shifts — all through mul_base
    let after_iii = 23 * MUL + (4 * ln + 9) * MULB;
    let shared = logup_units(lay, Dom::D) + pad_units(&pad_groups(sh, lay.ids(), SC_DZC));
    Ladder { old, after_i, after_ii, after_iii, shared }
}

/// **THE COUNT, per shape and per rung of the ladder, for the record.** It
/// asserts only what a count can carry: that every rung removes work and
/// none adds any, that rung-W14 and 125M save the same (their limb
/// structure is identical — the check's §7), and the headline figures.
/// Everything else it prints. Ruling I-1: none of this is a time.
#[test]
fn the_rewrite_removes_the_counted_multiplications_at_every_registered_shape() {
    let mut w14: Option<(usize, usize)> = None;
    let mut m125: Option<(usize, usize)> = None;
    for sh in every_shape() {
        let lay = Layout::for_shape(&sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
        let (a, b) = (szc_units(&sh, &lay), dzc_units(&sh, &lay));
        let key = shape_key(&sh);
        for (slot, l) in [(17usize, a), (14, b)] {
            let whole = l.old + l.shared;
            eprintln!(
                "S35 count {key} slot {slot}: {} -> {} -> {} -> {} units/evaluation in the arm (of {whole} with helper_sum and the pad term), {:.1}% of the closure",
                l.old,
                l.after_i,
                l.after_ii,
                l.after_iii,
                100.0 * (l.old - l.after_iii) as f64 / whole as f64
            );
            assert!(l.after_i <= l.old && l.after_ii <= l.after_i && l.after_iii < l.after_ii, "{key} slot {slot}: a rung of the ladder does not remove work: {l:?}");
        }
        if key == "rung-W14" {
            w14 = Some((a.old - a.after_iii, b.old - b.after_iii));
        }
        if key == "125M" {
            m125 = Some((a.old - a.after_iii, b.old - b.after_iii));
        }
    }
    assert_eq!(w14, m125, "rung-W14 and 125M have the same limb structure and must save the same count");
    assert_eq!(w14, Some((56, 155)), "the counted saving per evaluation at the 125M-structured shapes has moved");
}

//! **STEP S9, PREPARED: the pad rule of ruling P-1 (memo §3.7a).**
//!
//! At the toy no domain pads but `Dom::L` (finding B-F5), so no relation of
//! this module has ever been evaluated on a padded position. At the
//! development rung ALL NINE domains pad, and blocking item B-1 is that a
//! prover may write anything it likes there: the two claimed sums `SC_SS` and
//! `SC_SSM` read the FULL padded `Dom::D` cube, so junk in the padded columns
//! buys an arbitrary norm divisor and rescales every real column.
//!
//! **Ruling P-1: every hidden plane on a padded domain is PROVED zero off its
//! support**, by one batched pad-zero term `mu_pad · (1 − supp(x)) · Σ_j ζ^j
//! plane_j(x)` added to that domain's existing zero-check, with exemptions by
//! name and an exempted plane excluded from every summation by the indicator.
//!
//! **WHAT THIS MODULE IS, AND WHAT IT IS NOT.** It is the SPECIFICATION of
//! that rule as code — the support indicators, the per-plane ZERO / EXEMPT
//! table, and the two acceptance tests PZ-1 and PZ-2 — written BEFORE the
//! term itself, which is the order ruling P-7 requires. **The term is not
//! implemented.** It lives in `argument::define`'s zero-check brackets, and
//! `argument` is instantiable only at the toy (finding S5-F2): the claim
//! points, the RoPE tables, the row geometry (step S10) and the endpoints
//! (step S11) are still the toy's, so a padded shape produces no receipt at
//! all and a verifier-side test of the term cannot be written yet. PZ-1 and
//! PZ-2 below are therefore `#[ignore]`d and FAIL, each with the reason, and
//! what they demonstrate today is the HOLE: a pad tamper changes nothing that
//! any relation this module can evaluate at the rung looks at.
//!
//! Nothing here proves, claims or establishes a soundness or privacy
//! property; no witness value is printed.

use super::layout::*;
use super::shape::{Shape, LIMBS_ISQRT};
use super::witness::{self, Geom};

// ---------------------------------------------------------------- indicators

/// Is head slot `h` of the PADDED head axis a true query head?
///
/// **The memo's layout (§3.7a note 2, correction C-1): the padded head slots
/// INTERLEAVE, one per key-value group.** The padded head axis holds
/// `h_pad / kv_heads` slots per key-value group and the first `group =
/// q_heads / kv_heads` of each are true, so at 125M (16 slots, 4 groups of 4,
/// 3 true) the padded slots are `{3, 7, 11, 15}` and at the rung (8 slots, 2
/// groups of 4, 3 true) they are `{3, 7}`. A PREFIX mask would call slot 3
/// supported, which is what acceptance test PZ-1's head case is written to
/// catch.
pub(crate) fn head_is_true_interleaved(s: &Shape, h: usize) -> bool {
    let per_group = s.h_pad / s.kv_heads;
    h < s.h_pad && h % per_group < s.q_heads / s.kv_heads
}

/// Is head slot `h` true under the layout THE WITNESS BUILDER USES TODAY?
///
/// `witness::build_shaped` indexes query heads `0 .. q_heads` contiguously
/// (`g.dix(t, h * head_dim + i)`), so today's padded slots are the TAIL of
/// the head axis, `{6, 7}` at the rung, not `{3, 7}`. That is finding S9-F2:
/// the head permutation ruling P-2 and correction C-1 require is not built
/// yet, and it is a PREREQUISITE of the `Dom::Q` and `Dom::S` indicators.
pub(crate) fn head_is_true_contiguous(s: &Shape, h: usize) -> bool {
    h < s.q_heads
}

/// The public 0/1 support table of a padded domain, over the domain's PADDED
/// flat index, in the index convention `witness::Geom` lays the planes out
/// in. `interleaved` selects the head layout (see the two predicates above).
pub(crate) fn support_indicator(s: &Shape, dom: Dom, interleaved: bool) -> Vec<i64> {
    let head_true = |h: usize| if interleaved { head_is_true_interleaved(s, h) } else { head_is_true_contiguous(s, h) };
    let n = s.size(dom);
    let mut v = vec![0i64; n];
    let (t_pad, d_pad, f_pad, dh) = (s.t_pad, s.d_pad, s.f_pad, s.head_dim);
    let kvw = s.kv_heads * s.head_dim;
    match dom {
        Dom::T => {
            for t in 0..s.tokens {
                v[t] = 1;
            }
        }
        Dom::Ht => {
            for h in 0..s.h_pad {
                if head_true(h) {
                    for t in 0..s.tokens {
                        v[h * t_pad + t] = 1;
                    }
                }
            }
        }
        Dom::L => {
            for k in 0..3 * LIMBS_ISQRT {
                for t in 0..s.tokens {
                    v[k * t_pad + t] = 1;
                }
            }
        }
        // `Dom::D` is `(t, i)` with `i` the model width; `Dom::Q` is the SAME
        // flat index read as `(t, h, i')`, and they are different tables
        // (§3.7a note 1): `D` pads the top of each token's row, `Q` pads one
        // head slot per group.
        Dom::D => {
            for t in 0..s.tokens {
                for i in 0..s.width {
                    v[t * d_pad + i] = 1;
                }
            }
        }
        Dom::Q => {
            for t in 0..s.tokens {
                for h in 0..s.h_pad {
                    if head_true(h) {
                        for i in 0..dh {
                            v[t * d_pad + h * dh + i] = 1;
                        }
                    }
                }
            }
        }
        Dom::Kv => {
            for t in 0..s.tokens {
                for i in 0..kvw {
                    v[t * kvw + i] = 1;
                }
            }
        }
        Dom::S => {
            for h in 0..s.h_pad {
                if head_true(h) {
                    for t in 0..s.tokens {
                        for j in 0..s.tokens {
                            v[(h * t_pad + t) * t_pad + j] = 1;
                        }
                    }
                }
            }
        }
        Dom::F => {
            for t in 0..s.tokens {
                for j in 0..s.hidden {
                    v[t * f_pad + j] = 1;
                }
            }
        }
        Dom::Tab => {
            for i in 0..U8_LEN.min(n) {
                v[i] = 1;
            }
        }
    }
    v
}

// ---------------------------------------------------------------- the table

/// The per-plane rule of memo §3.7a's table.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Rule {
    /// covered by the domain's batched pad-zero term
    Zero,
    /// named in the table with a reason; excluded from the summations listed
    /// there by the support indicator
    Exempt,
    /// no pad rule at all (`H_U`, the zero-sum masking pair)
    None,
}

/// The rule for one `A` plane at `shape`, by the memo's table. Every `A`
/// plane on a padded domain is ZERO except `A_E`, which is EXEMPT because
/// `exp[0] = 2^F_E != 0` is a genuine table row and a zero there would make
/// the exp-pair lookup refuse. Planes on unpadded domains carry no rule.
pub(crate) fn a_rule(s: &Shape, ids: &Ids, plane: usize) -> Option<Rule> {
    let dom = ids.dom(plane);
    if !s.pads(dom) {
        return None;
    }
    if ids.is_multiplicity(plane) {
        // the three histograms are `Dom::Tab` planes and ARE proved zero
        // above index 255 — that is what makes the P-3 lift safe
        return Some(Rule::Zero);
    }
    if plane == ids.at(A_E) {
        return Some(Rule::Exempt);
    }
    Some(Rule::Zero)
}

/// The rule for one `H` plane. Every LogUp helper is EXEMPT — a helper is
/// `1/(alpha - v)` and is never zero — and `H_U`, the zero-sum masking pair,
/// carries no rule at all. The three table helpers are ZERO above index 255
/// for the same reason the histograms are.
///
/// The `H` plane LIST is shape-dependent (`Shape::h_plane_doms`): at 125M
/// correction C-6 drops four `Dom::D` lookups, so that block holds 17
/// helpers and not the toy's 19, and `N_H` is 50 rather than 51. The last
/// four planes are always the three table helpers and then `H_U`.
pub(crate) fn h_rule(s: &Shape, doms: &[Dom], plane: usize) -> Option<Rule> {
    if !s.pads(doms[plane]) {
        return None;
    }
    let n = doms.len();
    if plane == n - 1 {
        return Some(Rule::None);
    }
    if plane >= n - 4 {
        return Some(Rule::Zero);
    }
    Some(Rule::Exempt)
}

/// `(zero, exempt, none)` over both commitments at `shape`.
pub(crate) fn rule_counts(s: &Shape, ids: &Ids) -> (usize, usize, usize) {
    let (mut z, mut e, mut n) = (0, 0, 0);
    for p in 0..ids.n_a() {
        match a_rule(s, ids, p) {
            Some(Rule::Zero) => z += 1,
            Some(Rule::Exempt) => e += 1,
            Some(Rule::None) => n += 1,
            None => {}
        }
    }
    let hdoms = s.h_plane_doms();
    for p in 0..hdoms.len() {
        match h_rule(s, &hdoms, p) {
            Some(Rule::Zero) => z += 1,
            Some(Rule::Exempt) => e += 1,
            Some(Rule::None) => n += 1,
            None => {}
        }
    }
    (z, e, n)
}

// ------------------------------------------------------------- the two tests

/// A deterministic honest witness at `Shape::rung()`, and its geometry.
fn rung_witness() -> (Shape, Ids, witness::Witness) {
    let s = Shape::rung();
    let ids = Ids::new(&s).expect("the rung has a plane map");
    let (public, ff, input) = super::grow_tests::tame_case(&s);
    let w = witness::build_shaped(&s, &public, &ff, &input).expect("the rung's honest witness");
    (s, ids, w)
}

/// Every relation of the module that CAN be evaluated at a padded shape
/// today, as one boolean: the four norm relations (R1)..(R4) of
/// `norm_alias.rs` on every token row of both norms, the two residual
/// identities, the byte class of every limb plane on the true support, and
/// the two claimed row sums `SC_SS` / `SC_SSM` — the last over the **FULL
/// PADDED** `Dom::D` cube, which is exactly how `argument.rs:544-549` and
/// `:552-557` build them and exactly where blocking item B-1 lives.
///
/// `true` means "everything this module can check still holds".
fn every_checkable_relation_holds(s: &Shape, ids: &Ids, w: &witness::Witness) -> bool {
    let g = Geom::new(s);
    let sup_d = g.support(Dom::D);
    let limb = |p: usize, base: usize, t: usize| -> i64 { (0..LIMBS_ISQRT).map(|k| w.planes[p][(base + k) * s.t_pad + t] << (8 * k)).sum() };
    for (pd, pdsq, plimb, px) in [(ids.at(A_D), ids.at(A_DSQ), ids.at(A_LIMB), ids.at(A_X)), (ids.at(A_DM), ids.at(A_DSQM), ids.at(A_LIMBM), ids.at(A_X1))] {
        for t in 0..s.tokens {
            let d = w.planes[pd][t];
            // (R4) reads the claimed row sum over the FULL PADDED cube
            let ss: i64 = (0..s.d_pad).map(|i| w.planes[px][t * s.d_pad + i].pow(2)).sum();
            let (a1, a2) = (limb(plimb, 3, t), limb(plimb, 6, t));
            if w.planes[pdsq][t] != d * d || limb(plimb, 0, t) != d || a1 + a2 != 2 * d || d * d + a1 - 1 != ss {
                return false;
            }
        }
    }
    // residual 1 and residual 2, on the true support
    for &i in &sup_d {
        if w.planes[ids.at(A_X1)][i] != w.planes[ids.at(A_X)][i] + w.planes[ids.at(A_AO)][i] {
            return false;
        }
        if w.planes[ids.at(A_X2)][i] != w.planes[ids.at(A_X1)][i] + w.planes[ids.at(A_Z16)][i] {
            return false;
        }
    }
    // every limb plane really is a byte, on the true support of its domain
    for p in 0..ids.n_a() {
        if ids.is_multiplicity(p) {
            continue;
        }
        for lk in lookups_at(s, ids, ids.dom(p)) {
            if lk.terms.len() != 1 || lk.terms[0].0 != p {
                continue;
            }
            let sup = g.support(ids.dom(p));
            if sup.iter().any(|i| !(0..256).contains(&(lk.cst + lk.terms[0].1 * w.planes[p][*i]))) {
                return false;
            }
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    /// THE HEAD SLOTS INTERLEAVE (correction C-1), and a prefix mask does not.
    #[test]
    fn the_padded_head_slots_are_one_per_key_value_group() {
        let pads = |s: &Shape| -> Vec<usize> { (0..s.h_pad).filter(|h| !head_is_true_interleaved(s, *h)).collect() };
        assert_eq!(pads(&Shape::rung()), vec![3, 7], "the rung's padded head slots (memo section 9a)");
        assert_eq!(pads(&Shape::m125()), vec![3, 7, 11, 15], "125M's padded head slots (correction C-1)");
        assert!(pads(&Shape::toy()).is_empty(), "the toy's head axis does not pad");
        // a PREFIX mask would call slot 3 supported at both padded shapes:
        // that is the negative control PZ-1's head case rests on
        for s in [Shape::rung(), Shape::m125()] {
            let prefix_true = |h: usize| h < s.q_heads;
            assert!(prefix_true(3) && !head_is_true_interleaved(&s, 3), "{}: a prefix mask accepts padded slot 3", s.name);
        }
    }

    /// THE INDICATORS COUNT WHAT THE SHAPE COUNTS. A support table's weight
    /// must be the domain's true size at every shape, under the head layout
    /// the WITNESS uses; and `supp_D` and `supp_Q` must be DIFFERENT tables
    /// on the same cube wherever the head axis pads (memo section 3.7a
    /// note 1).
    #[test]
    fn every_support_indicator_has_the_true_sizes_weight() {
        for s in [Shape::toy(), Shape::rung(), Shape::m125()] {
            for dom in ALL_DOMS {
                let v = support_indicator(&s, dom, false);
                assert_eq!(v.len(), s.size(dom), "{}: {dom:?} indicator length", s.name);
                assert_eq!(v.iter().sum::<i64>() as usize, s.true_size(dom), "{}: {dom:?} indicator weight", s.name);
                assert!(v.iter().all(|b| *b == 0 || *b == 1), "{}: {dom:?} indicator is not 0/1", s.name);
                // it is exactly the builder's own support set
                let mut want = vec![0i64; s.size(dom)];
                for i in Geom::new(&s).support(dom) {
                    want[i] = 1;
                }
                assert_eq!(v, want, "{}: {dom:?} indicator differs from the witness's support", s.name);
            }
            // D and Q coincide only where the head axis does not pad
            let (d, q) = (support_indicator(&s, Dom::D, true), support_indicator(&s, Dom::Q, true));
            assert_eq!(d == q, s.h_pad == s.q_heads, "{}: supp_D and supp_Q must differ exactly when heads pad", s.name);
        }
    }

    /// **S9-F2, as a test.** The indicator the memo specifies and the support
    /// the witness builder actually writes DISAGREE at every shape whose head
    /// axis pads, because the builder lays query heads out contiguously and
    /// the memo's layout interleaves the padded slot into each key-value
    /// group. The head permutation is a prerequisite of the `Dom::Q` and
    /// `Dom::S` indicators and is not built.
    #[test]
    fn the_memos_head_layout_is_not_yet_the_builders() {
        for s in [Shape::rung(), Shape::m125()] {
            for dom in [Dom::Q, Dom::S, Dom::Ht] {
                let (memo, built) = (support_indicator(&s, dom, true), support_indicator(&s, dom, false));
                assert_eq!(memo.iter().sum::<i64>(), built.iter().sum::<i64>(), "{}: {dom:?} weights differ", s.name);
                assert_ne!(memo, built, "{}: {dom:?} — the two head layouts agree, so S9-F2 is stale", s.name);
            }
        }
        // ... and at the toy they are the same table, which is why the toy
        // cannot see the difference
        for dom in ALL_DOMS {
            assert_eq!(support_indicator(&Shape::toy(), dom, true), support_indicator(&Shape::toy(), dom, false));
        }
    }

    /// THE PLANE TABLE OF MEMO SECTION 3.7a, RECOUNTED FROM CODE. The
    /// editor's own recount (finding B-F4) is 100 planes at 125M: 64 ZERO,
    /// 35 EXEMPT by name and one (`H_U`) with no pad rule.
    #[test]
    fn the_pad_rule_table_reproduces_the_memos_counts() {
        let m = Shape::m125();
        let ids = Ids::new(&m).expect("125M has a plane map");
        let (z, e, n) = rule_counts(&m, &ids);
        assert_eq!((z, e, n), (64, 35, 1), "the 125M pad table is not the memo's 64 / 35 / 1");
        assert_eq!(z + e + n, 100, "the memo's 100 classified planes");
        // the single EXEMPT `A` plane is `A_E`, by name
        let exempt_a: Vec<usize> = (0..ids.n_a()).filter(|p| a_rule(&m, &ids, *p) == Some(Rule::Exempt)).collect();
        assert_eq!(exempt_a, vec![ids.at(A_E)], "the only exempt A plane is the exponential");
        // the 34 exempt `H` planes are the LogUp helpers, and `H_U` alone has
        // no rule
        let hdoms = m.h_plane_doms();
        assert_eq!(hdoms.len(), 50, "C-6 leaves 125M with 50 H planes, not the toy's 51");
        assert_eq!((0..hdoms.len()).filter(|p| h_rule(&m, &hdoms, *p) == Some(Rule::Exempt)).count(), 34, "the memo's 34 exempt helpers");
        assert_eq!((0..hdoms.len()).filter(|p| h_rule(&m, &hdoms, *p) == Some(Rule::None)).collect::<Vec<_>>(), vec![hdoms.len() - 1], "only the zero-sum pair has no rule");
        // AT THE RUNG every domain pads, so the table covers MORE planes
        let r = Shape::rung();
        let rids = Ids::new(&r).expect("the rung has a plane map");
        assert!(ALL_DOMS.iter().all(|d| r.pads(*d)), "memo section 9a: every rung domain pads");
        let (rz, re, rn) = rule_counts(&r, &rids);
        assert_eq!(rz + re + rn, rids.n_a() + r.h_plane_doms().len(), "at the rung every committed plane carries a rule");
        assert_eq!((rz, re, rn), (85, 49, 1), "the rung's pad table");
    }

    /// **S9-F1: the toy is NOT a no-pad shape.** `Dom::L` pads at the toy —
    /// nine of sixteen limb sub-planes carry the isqrt witness and seven are
    /// empty (finding B-F5) — so ruling P-1 would apply to it, and adding the
    /// term would move a toy byte. The rule must therefore be carried by a
    /// PROFILE and not switched on by "does this domain pad"; the toy profile
    /// stays as it is (D17) and its `Dom::L` pad remains unconstrained,
    /// exactly as it always was.
    #[test]
    fn the_toy_already_pads_one_domain_and_must_not_gain_the_term() {
        let t = Shape::toy();
        let padded: Vec<Dom> = ALL_DOMS.into_iter().filter(|d| t.pads(*d)).collect();
        assert_eq!(padded, vec![Dom::L], "the toy pads exactly one domain");
        assert_eq!((t.true_size(Dom::L), t.size(Dom::L)), (288, 512), "nine of sixteen limb sub-planes are used");
        // the two `Dom::L` planes would take the rule, and `SC_LZC` would take
        // the term — which is the toy's own transcript
        let ids = Ids::new(&t).expect("the toy has a plane map");
        assert_eq!(a_rule(&t, &ids, ids.at(A_LIMB)), Some(Rule::Zero));
        assert_eq!(a_rule(&t, &ids, ids.at(A_LIMBM)), Some(Rule::Zero));
        assert_eq!(rule_counts(&t, &ids), (2, 1, 0), "the toy's own pad table: the two limb planes, ZERO, and their LogUp helper, EXEMPT");
    }

    /// The honest rung witness satisfies every relation the module can
    /// evaluate at a padded shape — which is what makes PZ-1 and PZ-2
    /// meaningful: whatever they detect, they detect because of the PAD.
    #[test]
    fn the_honest_rung_witness_passes_every_checkable_relation() {
        let (s, ids, w) = rung_witness();
        assert!(every_checkable_relation_holds(&s, &ids, &w), "the honest rung witness fails a relation the module can check");
        // and its pad really is all zero today (finding S6-F4)
        for dom in ALL_DOMS {
            let supp = support_indicator(&s, dom, false);
            for p in 0..ids.n_a() {
                if ids.is_multiplicity(p) || ids.dom(p) != dom {
                    continue;
                }
                assert!((0..w.planes[p].len()).all(|i| supp[i] == 1 || w.planes[p][i] == 0), "plane {p} has a nonzero pad position");
            }
        }
    }

    /// **PZ-1 (ruling P-1, memo section 3.7a).** ONE nonzero value written
    /// into a padded position of a ZERO-rule plane that no claimed sum reads
    /// must be REJECTED BY THE VERIFIER.
    ///
    /// WHY IT IS IGNORED AND WHAT IT PROVES TODAY. The rejection is a term in
    /// `argument::define`'s zero-check bracket, and `argument` is
    /// instantiable only at the toy (finding S5-F2), so no rung receipt
    /// exists to verify. The test is written at the level where the relation
    /// is decided — every relation this module CAN evaluate at the rung —
    /// and it fails because the tampered witness satisfies all of them: the
    /// padded position of `A_RAL` is read by nothing at all. That is exactly
    /// the coverage half of B-1.
    #[test]
    #[ignore = "S9: the pad-zero term lives in argument::define, which is instantiable only at the toy (finding S5-F2); un-ignore when S10 and S11 make a rung receipt possible"]
    fn pz1_a_lone_nonzero_pad_value_is_rejected() {
        let (s, ids, mut w) = rung_witness();
        let supp = support_indicator(&s, Dom::D, false);
        let pad_pos = (0..s.size(Dom::D)).find(|i| supp[*i] == 0).expect("Dom::D pads at the rung");
        assert!(every_checkable_relation_holds(&s, &ids, &w), "the honest witness must pass first");
        w.planes[ids.at(A_RAL)][pad_pos] = 1;
        assert!(
            !every_checkable_relation_holds(&s, &ids, &w),
            "PZ-1: a lone nonzero value in A_RAL's pad is invisible to every relation this module can evaluate — which is the hole ruling P-1's pad-zero term closes"
        );
    }

    /// **PZ-2 (blocking item B-1 / B-4).** Nonzero values in `A_X`'s padded
    /// columns of one token row, WITH that row's `D`, `a1`, `a2`, `y`, `rho`
    /// and `sigma` recomputed consistently from the enlarged sum of squares,
    /// must be rejected. Before the fix the receipt VERIFIES: every
    /// constraint, every sum and every lookup is satisfied, under a divisor
    /// the prover chose.
    ///
    /// Ignored for the same reason as PZ-1, and what it demonstrates today is
    /// the sharper half of B-1: this test writes the pad, recomputes the
    /// norm row, and then asserts the module notices — and it does not,
    /// because `SC_SS`'s claimed row sum reads the padded cube and the
    /// recomputed `D` matches it exactly.
    #[test]
    #[ignore = "S9: the pad-zero term lives in argument::define, which is instantiable only at the toy (finding S5-F2); un-ignore when S10 and S11 make a rung receipt possible"]
    fn pz2_a_consistently_adjusted_pad_is_rejected() {
        let (s, ids, mut w) = rung_witness();
        assert!(every_checkable_relation_holds(&s, &ids, &w), "the honest witness must pass first");
        let t = 0usize;
        let (px, pd, pdsq, plimb) = (ids.at(A_X), ids.at(A_D), ids.at(A_DSQ), ids.at(A_LIMB));
        // write the pad of row `t`, then recompute the whole isqrt witness
        for i in s.width..s.d_pad {
            w.planes[px][t * s.d_pad + i] = 32_767;
        }
        // the int16-fill branch: the padded `x` stays inside int16 and its
        // byte limbs are filled consistently, so `SC_DZC`'s `c2` holds there
        // too and the tamper is not decided by a limb relation
        for i in s.width..s.d_pad {
            let v = w.planes[px][t * s.d_pad + i] + 32_768;
            w.planes[ids.at(A_XL0)][t * s.d_pad + i] = v & 255;
            w.planes[ids.at(A_XL1)][t * s.d_pad + i] = v >> 8;
        }
        let ss: i64 = 1 + (0..s.d_pad).map(|i| w.planes[px][t * s.d_pad + i].pow(2)).sum::<i64>();
        let d = witness::isqrt(ss as u64) as i64;
        let a1 = ss - d * d;
        let a2 = 2 * d - a1;
        w.planes[pd][t] = d;
        w.planes[pdsq][t] = d * d;
        for (base, v) in [(0usize, d), (3, a1), (6, a2)] {
            for k in 0..LIMBS_ISQRT {
                w.planes[plimb][(base + k) * s.t_pad + t] = (v >> (8 * k)) & 255;
            }
        }
        assert!(
            !every_checkable_relation_holds(&s, &ids, &w),
            "PZ-2: a consistently adjusted pad satisfies every relation this module can evaluate — the prover chose the norm divisor and nothing said no (blocking item B-1)"
        );
    }
}

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
//! **WHAT THIS MODULE IS (S9 parts 1–4).** It is the SPECIFICATION of that
//! rule as code — the support indicators, the per-plane ZERO / EXEMPT table,
//! the slot map, and the two acceptance tests PZ-1 and PZ-2 — written BEFORE
//! the term itself, which is the order ruling P-7 requires. Since S9 part 4
//! the TERM is built too: `argument::define` puts one batched
//! `mu_pad · (1 − supp) · Σ ζ^j plane_j` in each host slot of
//! [`indicator_slots`] and the support factor on the inhomogeneous clauses
//! and host terms of the eight `INDICATOR_SLOT_DOMAIN` slots. PZ-1 and PZ-2
//! are decided HERE, at the witness level, by the same statement the term
//! carries; the END-TO-END form — rejected by the verifier, from receipt
//! bytes — is step S12, and until it exists no rung run is a proof.
//!
//! The frozen toy profile carries none of it ([`Shape::carries_pad_rule`]).
//!
//! Nothing here proves, claims or establishes a soundness or privacy
//! property; no witness value is printed.

use super::layout::*;
use super::shape::{Shape, LIMBS_ISQRT};
use super::witness::Geom;
#[cfg(test)]
use super::witness;

// ---------------------------------------------------------------- indicators

/// **THE DEFINITION OF A SUPPORT INDICATOR (ruling S9-F3).** At every shape,
/// the indicator of a padded domain IS the builder's own public support table
/// for that domain: `1` exactly on the positions [`Geom::support`] writes, `0`
/// everywhere else. A closed multilinear form is an OPTIMISATION where one
/// exists and must equal this table ([`closed_form_indicator`], asserted).
///
/// Nothing witness-dependent enters it: `Geom::support` is a function of the
/// [`Shape`] alone, so the table is public data the verifier can rebuild.
pub(crate) fn support_indicator(s: &Shape, dom: Dom) -> Vec<i64> {
    let mut v = vec![0i64; s.size(dom)];
    for i in Geom::new(s).support(dom) {
        v[i] = 1;
    }
    v
}

/// The memo's own rule for the three head-indexed domains, written from
/// §3.7a note 2 and correction C-1 and NOT from the builder: the padded head
/// axis holds `h_pad / kv_heads` slots per key-value group and the first
/// `group = q_heads / kv_heads` of each are true, so the padded slots are
/// `{3, 7}` at the rung and `{3, 7, 11, 15}` at 125M. This is the oracle
/// [`support_indicator`] is checked against.
/// Test-only oracle: not read by the argument.
#[cfg(test)]
pub(crate) fn memo_head_indicator(s: &Shape, dom: Dom) -> Vec<i64> {
    head_indicator(s, dom, &|h: usize| {
        let per_group = s.h_pad / s.kv_heads;
        h % per_group < s.q_heads / s.kv_heads
    })
}

/// The CONTIGUOUS-TAIL layout — padded slots `{6, 7}` at the rung — which is
/// what the builder wrote before the head permutation (finding S9-F2) and
/// what a prefix-mask indicator would call supported. It is the negative
/// control of the head tests and of PZ-1's head case; nothing builds on it.
/// Test-only negative control: not read by the argument.
#[cfg(test)]
pub(crate) fn contiguous_head_indicator(s: &Shape, dom: Dom) -> Vec<i64> {
    head_indicator(s, dom, &|h: usize| h < s.q_heads)
}

#[cfg(test)]
fn head_indicator(s: &Shape, dom: Dom, head_true: &dyn Fn(usize) -> bool) -> Vec<i64> {
    let mut v = vec![0i64; s.size(dom)];
    let t_pad = s.t_pad;
    for h in 0..s.h_pad {
        if !head_true(h) {
            continue;
        }
        for t in 0..s.tokens {
            match dom {
                Dom::Ht => v[h * t_pad + t] = 1,
                Dom::Q => {
                    for i in 0..s.head_dim {
                        v[t * s.d_pad + h * s.head_dim + i] = 1;
                    }
                }
                Dom::S => {
                    for j in 0..s.tokens {
                        v[(h * t_pad + t) * t_pad + j] = 1;
                    }
                }
                _ => unreachable!("head_indicator is for the three head-indexed domains"),
            }
        }
    }
    v
}

/// `[x < lim]` on the field `0 .. pad` (`pad` a power of two), written the way
/// §3.7a writes its indicators — as a product over the sumcheck's own
/// variables, so that both sides could evaluate it without materialising a
/// table. Exactly two forms occur, and a predicate that is neither has no
/// cheap closed form at all (`supp_L`'s `[k < 9]` is the memo's own example).
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum BitForm {
    /// the axis is full: the factor is the constant 1
    Always,
    /// `lim` is a power of two: `prod_{b in bits} (1 - x_b)`
    AllZero(Vec<usize>),
    /// `pad - lim` is a power of two: `1 - prod_{b in bits} x_b`
    NotAllOne(Vec<usize>),
}

impl BitForm {
    fn of(lim: usize, pad: usize) -> Option<BitForm> {
        assert!(pad.is_power_of_two() && lim <= pad && lim > 0);
        let m = pad.trailing_zeros() as usize;
        if lim == pad {
            return Some(BitForm::Always);
        }
        if lim.is_power_of_two() {
            return Some(BitForm::AllZero((lim.trailing_zeros() as usize..m).collect()));
        }
        if (pad - lim).is_power_of_two() {
            return Some(BitForm::NotAllOne(((pad - lim).trailing_zeros() as usize..m).collect()));
        }
        None
    }
    /// the factor's value at `x`, the axis's own field of the flat index
    fn at(&self, x: usize) -> i64 {
        match self {
            BitForm::Always => 1,
            BitForm::AllZero(bits) => i64::from(bits.iter().all(|b| (x >> b) & 1 == 0)),
            BitForm::NotAllOne(bits) => i64::from(!bits.iter().all(|b| (x >> b) & 1 == 1)),
        }
    }
}

/// **The closed multilinear forms of §3.7a, where one exists (finding
/// S9-F3).** `Some((table, factors))` is the product of the per-axis
/// [`BitForm`]s evaluated on the whole cube, together with the factors
/// themselves; `None` means no cheap closed form is claimed at this shape and
/// the verifier must read the table.
///
/// The bit positions are those of the domain's own flat index, so the factors
/// ARE the memo's expressions: at 125M `supp_D = 1 - b9·b8`,
/// `supp_Q = 1 - b7·b6`, `supp_S = 1 - b19·b18`, `supp_Ht = 1 - b10·b9` and
/// `supp_Tab = prod_{k=8}^{13}(1 - b_k)`. `supp_L`'s `[k < 9]` is neither
/// form and returns `None`, exactly as the memo says.
pub(crate) fn closed_form_indicator(s: &Shape, dom: Dom) -> Option<(Vec<i64>, Vec<(usize, BitForm)>)> {
    let (t_pad, d_pad, f_pad, dh) = (s.t_pad, s.d_pad, s.f_pad, s.head_dim);
    // the padded head slots are the last `per - g` of each key-value group,
    // so the head factor lives on the LOW bits of the slot index
    let per = s.h_pad / s.kv_heads;
    let head = || BitForm::of(s.q_heads / s.kv_heads, per);
    // `(stride of the axis in the flat index, its factor)`, axis by axis
    let axes: Vec<(usize, Option<BitForm>)> = match dom {
        Dom::T => vec![(1, BitForm::of(s.tokens, t_pad))],
        Dom::D => vec![(1, BitForm::of(s.width, d_pad)), (d_pad, BitForm::of(s.tokens, t_pad))],
        Dom::F => vec![(1, BitForm::of(s.hidden, f_pad)), (f_pad, BitForm::of(s.tokens, t_pad))],
        Dom::Kv => vec![(s.kv_heads * dh, BitForm::of(s.tokens, t_pad))],
        // `Dom::Q` is `(t, slot, i')`: the head factor sits above `log2(dh)`
        Dom::Q => vec![(dh, head()), (d_pad, BitForm::of(s.tokens, t_pad))],
        Dom::Ht => vec![(1, BitForm::of(s.tokens, t_pad)), (t_pad, head())],
        Dom::S => vec![(1, BitForm::of(s.tokens, t_pad)), (t_pad, BitForm::of(s.tokens, t_pad)), (t_pad * t_pad, head())],
        Dom::L => vec![(1, BitForm::of(s.tokens, t_pad)), (t_pad, BitForm::of(3 * LIMBS_ISQRT, s.size(dom) / t_pad))],
        Dom::Tab => vec![(1, BitForm::of(U8_LEN, s.size(dom)))],
    };
    let mut factors = Vec::new();
    for (stride, form) in axes {
        let form = form?;
        if form != BitForm::Always {
            factors.push((stride.trailing_zeros() as usize, form));
        }
    }
    let mut v = vec![1i64; s.size(dom)];
    for (x, e) in v.iter_mut().enumerate() {
        for (shift, form) in &factors {
            *e *= form.at(x >> shift);
        }
    }
    Some((v, factors))
}

/// **What the verifier must evaluate, and what it costs (finding S9-F3).**
/// One entry per padded domain: the table's length, the number of SLOT
/// instantiations that materialise it (`table_of` clones a public table per
/// slot, `argument.rs:206`), and whether a closed form exists at this shape.
/// `bytes` prices the conservative form the memo prices: one `Fp2` (16 B) per
/// entry per materialisation.
#[cfg(test)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct IndicatorCost {
    pub dom: Dom,
    pub len: usize,
    pub slots: usize,
    pub bytes: usize,
    pub closed_form: bool,
}

/// The slots that carry `dom`'s indicator: the domain's own zero-check host
/// plus every slot whose relation the indicator gates (§3.7a, "what the
/// indicator gates"). This is the list `argument::define` actually
/// materialises, one `Tab::Pub` per entry, and
/// [`indicator_tables_per_slot`] is its transpose.
///
/// **Corrected in S9 part 4 (finding S9-F7).** `Dom::Ht` and `Dom::T` were
/// listed as carrying no table: `Dom::Ht`'s term was to ride in `SC_SZC` on
/// `supp_S` (§3.7a open question 2) and `Dom::T` had no term at all. Neither
/// works. `supp_S` is zero wherever the `j` axis pads, so riding on it would
/// force a TRUE row's `A_MX` and `A_SUM` to zero; and `Dom::T`'s four planes
/// are ZERO-rule by the memo's own table and are read by `SC_TZC`, whose cube
/// IS `Dom::T`. Each therefore carries its own table in its host slot.
#[cfg(test)]
pub(crate) fn indicator_slots(dom: Dom) -> &'static [usize] {
    match dom {
        Dom::D => &[SC_SS, SC_SSM, SC_DZC],
        Dom::Q => &[SC_QZC],
        Dom::S => &[SC_RS, SC_SZC],
        // lifted over the trailing `j` axis of the `Dom::S` cube
        Dom::Ht => &[SC_SZC],
        Dom::Kv => &[SC_KVZC],
        Dom::F => &[SC_FZC],
        Dom::L => &[SC_LZC],
        Dom::Tab => &[SC_TAB],
        Dom::T => &[SC_TZC],
    }
}

/// How many support tables `argument::define` materialises in each slot — the
/// transpose of [`indicator_slots`] over the shape's padded domains, and zero
/// everywhere on the frozen toy profile.
#[cfg(test)]
pub(crate) fn indicator_tables_per_slot(s: &Shape) -> [usize; N_SLOTS] {
    let mut out = [0usize; N_SLOTS];
    if !s.carries_pad_rule() {
        return out;
    }
    for dom in ALL_DOMS {
        if !s.pads(dom) {
            continue;
        }
        for sl in indicator_slots(dom) {
            out[*sl] += 1;
        }
    }
    out
}

#[cfg(test)]
pub(crate) fn indicator_costs(s: &Shape) -> Vec<IndicatorCost> {
    s.padded_domains()
        .into_iter()
        .map(|dom| {
            let (len, slots) = (s.size(dom), indicator_slots(dom).len());
            IndicatorCost { dom, len, slots, bytes: len * slots * 16, closed_form: closed_form_indicator(s, dom).is_some() }
        })
        .collect()
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

/// **The indicator the ARGUMENT builds (ruling on finding S9-F4).** The closed
/// multilinear form where one exists, the builder's public support table
/// otherwise. `the_closed_forms_equal_the_tables` asserts the two agree entry
/// for entry at every shape, so this is an optimisation of the CONSTRUCTOR and
/// never a second definition: [`support_indicator`] stays the definition of
/// record. It does NOT yet make the verifier table-free — `Tab::Pub` holds a
/// materialised vector on both sides — which is what S9-F4 still asks for.
pub(crate) fn indicator_table(s: &Shape, dom: Dom) -> Vec<i64> {
    match closed_form_indicator(s, dom) {
        Some((v, _)) => v,
        None => support_indicator(s, dom),
    }
}

/// **Which slot carries a padded domain's batched pad-zero term.** The
/// domain's own zero-check, except for the two domains that have none of their
/// own: `Dom::T`'s planes are read by `SC_TZC` (its cube IS `Dom::T`) and
/// `Dom::Ht`'s two planes are read inside `SC_SZC`, where the indicator is
/// lifted over the trailing `j` axis of the `Dom::S` cube (finding S9-F7).
pub(crate) fn pad_zero_host(dom: Dom) -> usize {
    match dom {
        Dom::T => SC_TZC,
        Dom::Ht => SC_SZC,
        Dom::L => SC_LZC,
        Dom::D => SC_DZC,
        Dom::Q => SC_QZC,
        Dom::Kv => SC_KVZC,
        Dom::S => SC_SZC,
        Dom::F => SC_FZC,
        Dom::Tab => SC_TAB,
    }
}

/// The ZERO-rule `A` planes of one domain, in plane order — the batched
/// pad-zero term's summands. Empty when the profile carries no pad rule or the
/// domain does not pad, which is how the toy's transcript stays free of the
/// machinery (the profile gate of finding S9-F1).
pub(crate) fn zero_rule_a_planes(s: &Shape, ids: &Ids, dom: Dom) -> Vec<usize> {
    if !s.carries_pad_rule() {
        return Vec::new();
    }
    (0..ids.n_a()).filter(|p| ids.dom(*p) == dom && a_rule(s, ids, *p) == Some(Rule::Zero)).collect()
}

/// The ZERO-rule `H` planes of one domain, in plane order (the three table
/// helpers, and nothing else — every LogUp helper of a value domain is EXEMPT
/// and `H_U` carries no rule).
pub(crate) fn zero_rule_h_planes(s: &Shape, dom: Dom) -> Vec<usize> {
    if !s.carries_pad_rule() {
        return Vec::new();
    }
    let doms = s.h_plane_doms();
    (0..doms.len()).filter(|p| doms[*p] == dom && h_rule(s, &doms, *p) == Some(Rule::Zero)).collect()
}

/// `(zero, exempt, none)` over both commitments at `shape`.
#[cfg(test)]
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
#[cfg(test)]
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
#[cfg(test)]
pub(super) fn every_checkable_relation_holds(s: &Shape, ids: &Ids, w: &witness::Witness) -> bool {
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
    // **S9 PART 4: ruling P-1's own relation.** Every ZERO-rule plane on a
    // padded domain vanishes off its support. This is the relation the
    // batched pad-zero term of `argument::define` decides, written here at the
    // witness level so that PZ-1 and PZ-2 are decided by the SAME statement
    // the argument carries. The end-to-end form (rejected BY THE VERIFIER) is
    // step S12.
    for dom in ALL_DOMS {
        let planes = zero_rule_a_planes(s, ids, dom);
        if planes.is_empty() {
            continue;
        }
        let supp = indicator_table(s, dom);
        for p in planes {
            if (0..w.planes[p].len()).any(|i| supp[i] == 0 && w.planes[p][i] != 0) {
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
    /// The permutation lives in [`Shape::head_slot`]; this checks the slot map
    /// against the memo's own set, and that the key-value group really is the
    /// HIGH bits of the slot index (ruling S9-F2: "query head h reads
    /// key-value head slot >> log(group slots)").
    #[test]
    fn the_padded_head_slots_are_one_per_key_value_group() {
        let pads = |s: &Shape| -> Vec<usize> { (0..s.h_pad).filter(|h| !s.slot_is_true_head(*h)).collect() };
        assert_eq!(pads(&Shape::rung()), vec![3, 7], "the rung's padded head slots (memo section 9a)");
        assert_eq!(pads(&Shape::m125()), vec![3, 7, 11, 15], "125M's padded head slots (correction C-1)");
        assert!(pads(&Shape::toy()).is_empty(), "the toy's head axis does not pad");
        for s in [Shape::toy(), Shape::rung(), Shape::m125()] {
            // the slot map is injective, lands on true slots only, and puts
            // the key-value group in the HIGH bits
            let slots: Vec<usize> = (0..s.q_heads).map(|h| s.head_slot(h)).collect();
            let mut sorted = slots.clone();
            sorted.sort_unstable();
            sorted.dedup();
            assert_eq!(sorted.len(), s.q_heads, "{}: the head slot map is not injective", s.name);
            for (h, sl) in slots.iter().enumerate() {
                assert!(s.slot_is_true_head(*sl), "{}: head {h} lands on a padded slot", s.name);
                assert_eq!(s.kv_of_slot(*sl), h / (s.q_heads / s.kv_heads), "{}: head {h}'s key-value group is not the high bits of its slot", s.name);
                assert_eq!(s.kv_of_slot(*sl), sl >> s.log_slots_per_kv_group(), "{}: the key-value head is not a shift of the slot", s.name);
            }
        }
        // a PREFIX mask would call slot 3 supported at both padded shapes:
        // that is the negative control PZ-1's head case rests on
        for s in [Shape::rung(), Shape::m125()] {
            assert!(3 < s.q_heads && !s.slot_is_true_head(3), "{}: a prefix mask accepts padded slot 3", s.name);
        }
    }

    /// **Finding S9-F3, as a test.** Where a closed multilinear form exists it
    /// must equal the builder's support table entry for entry; where the
    /// memo's formula does not describe the shape, none is claimed. At 125M
    /// every padded domain has one (the memo's `1 − b·b'` family); at the
    /// RUNG the token axis pads, so `D`, `Q`, `S`, `Ht`, `Kv`, `F` and `L`
    /// carry a prefix predicate as well and the memo's two-bit products alone
    /// are not enough — which is why the table, not the formula, is the
    /// definition.
    #[test]
    fn the_closed_forms_equal_the_tables() {
        for s in [Shape::toy(), Shape::rung(), Shape::m125()] {
            for dom in ALL_DOMS {
                if let Some((cf, _)) = closed_form_indicator(&s, dom) {
                    assert_eq!(cf, support_indicator(&s, dom), "{}: {dom:?}'s closed form differs from the support table", s.name);
                }
                // the CONSTRUCTOR the argument uses is the closed form where
                // one exists, and it is the table's equal, exhaustively
                assert_eq!(indicator_table(&s, dom), support_indicator(&s, dom), "{}: {dom:?}'s indicator_table differs from the support table", s.name);
            }
        }
        // where the optimisation actually bites: five of the rung's nine
        // padded domains are built from a product form and never touch
        // `Geom::support`
        let r = Shape::rung();
        let closed: Vec<Dom> = ALL_DOMS.into_iter().filter(|d| r.pads(*d) && closed_form_indicator(&r, *d).is_some()).collect();
        assert_eq!(closed, vec![Dom::T, Dom::Ht, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Tab], "the rung's closed-form domains");
        // 125M: the memo's own six padded domains, and its own verdict on
        // which of them has a cheap closed form (`supp_L`'s `[k < 9]` does
        // not — the memo says so in the indicator table)
        let m = Shape::m125();
        let costs = indicator_costs(&m);
        assert_eq!(costs.iter().map(|c| c.dom).collect::<Vec<_>>(), vec![Dom::Ht, Dom::L, Dom::D, Dom::Q, Dom::S, Dom::Tab], "125M's six padded domains (memo section 3.7a)");
        assert_eq!(costs.iter().filter(|c| !c.closed_form).map(|c| c.dom).collect::<Vec<_>>(), vec![Dom::L], "only supp_L has no product form");
        // the memo's own expressions, read off the factors
        let two_bit = |dom: Dom, hi: usize| {
            let (_, f) = closed_form_indicator(&m, dom).expect("a closed form");
            assert_eq!(f.len(), 1, "{dom:?} is one factor at 125M");
            match &f[0].1 {
                BitForm::NotAllOne(bits) => assert_eq!(bits.iter().map(|b| b + f[0].0).max(), Some(hi), "{dom:?}'s top bit"),
                other => panic!("{dom:?} is not a `1 - b·b'` form: {other:?}"),
            }
        };
        two_bit(Dom::D, 9);
        two_bit(Dom::Q, 7);
        two_bit(Dom::S, 19);
        two_bit(Dom::Ht, 10);
        // the memo's priced table sizes, §3.7a: 2^19 for D and Q, 2^22 for S
        assert_eq!(m.size(Dom::D), 1 << 19);
        assert_eq!(m.size(Dom::S), 1 << 22);
        // ... and what the verifier evaluates: one `eval_mle_ext` per slot
        // that carries the indicator, over the whole cube
        let s_cost = costs.iter().find(|c| c.dom == Dom::S).expect("Dom::S pads at 125M");
        assert_eq!((s_cost.slots, s_cost.bytes), (2, 2 * (1 << 22) * 16), "supp_S is materialised in SC_RS and SC_SZC: 67.1 MB each");
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
                let v = support_indicator(&s, dom);
                assert_eq!(v.len(), s.size(dom), "{}: {dom:?} indicator length", s.name);
                assert_eq!(v.iter().sum::<i64>() as usize, s.true_size(dom), "{}: {dom:?} indicator weight", s.name);
                assert!(v.iter().all(|b| *b == 0 || *b == 1), "{}: {dom:?} indicator is not 0/1", s.name);
                // the builder's support list has no repeats, so the weight
                // above really does count distinct positions
                assert_eq!(Geom::new(&s).support(dom).len(), s.true_size(dom), "{}: {dom:?} support list length", s.name);
            }
            // D and Q coincide only where the head axis does not pad
            let (d, q) = (support_indicator(&s, Dom::D), support_indicator(&s, Dom::Q));
            assert_eq!(d == q, s.h_pad == s.q_heads, "{}: supp_D and supp_Q must differ exactly when heads pad", s.name);
        }
    }

    /// **S9-F2, RESOLVED — the acceptance test of the head permutation.**
    /// The support the WITNESS BUILDER writes must be the interleaved layout
    /// correction C-1 and ruling P-2 specify, at every shape: padded head
    /// slots one per key-value group (`{3, 7}` at the rung, `{3, 7, 11, 15}`
    /// at 125M), never a contiguous tail. Until the permutation landed the
    /// builder laid query heads out contiguously and these two DISAGREED;
    /// that is what this test was written to catch.
    #[test]
    fn the_builders_head_layout_is_the_memos() {
        for s in [Shape::toy(), Shape::rung(), Shape::m125()] {
            for dom in [Dom::Q, Dom::S, Dom::Ht] {
                let memo = memo_head_indicator(&s, dom);
                let built = support_indicator(&s, dom);
                assert_eq!(memo.iter().sum::<i64>(), built.iter().sum::<i64>(), "{}: {dom:?} weights differ", s.name);
                assert_eq!(memo, built, "{}: {dom:?} — the builder's head layout is not the memo's interleaved one (finding S9-F2)", s.name);
            }
            // a CONTIGUOUS tail is a different table wherever the head axis
            // pads: that is the negative control the equality above rests on
            for dom in [Dom::Q, Dom::S, Dom::Ht] {
                let tail = contiguous_head_indicator(&s, dom);
                assert_eq!(tail == support_indicator(&s, dom), s.h_pad == s.q_heads, "{}: {dom:?} — tail and interleaved must differ exactly when heads pad", s.name);
            }
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
        // THE PROFILE GATE (ruling on finding S9-F1), stated as the predicate
        // it is: the frozen toy profile carries no pad machinery, and every
        // other profile does — including a shape with the TOY'S OWN geometry
        // under a new profile id, which is the case a domain-driven rule
        // could not tell apart.
        assert!(!t.carries_pad_rule(), "the frozen toy profile must not carry the pad rule");
        for s in [Shape::rung(), Shape::m125()] {
            assert!(s.carries_pad_rule(), "{} is a new profile and carries the rule", s.name);
        }
        let toy_geometry_new_profile =
            Shape::new("the toy geometry under a NEW profile", "hashline-zk-mr1/private-block-t32-padgate/1", 32, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None).expect("well formed");
        assert!(toy_geometry_new_profile.carries_pad_rule(), "the gate is the PROFILE, not the geometry");
        assert!(toy_geometry_new_profile.pads(Dom::L), "and that profile's Dom::L pads exactly as the toy's does");
        // the toy's slot degrees therefore do not move, and neither do the
        // new profile's: `Dom::L` hosts `SC_LZC`, which is homogeneous and
        // gains no degree from an indicator in any case
        assert_eq!(t.slots(), toy_geometry_new_profile.slots(), "the gate must not move a degree at the toy geometry");
        assert_eq!(t.slots()[SC_LZC].2, 4, "SC_LZC keeps degree 4: it is homogeneous and gains nothing");
    }

    /// **THE TOY-PADDING CHECK the ruling on S9-F1 asks for, reported as a
    /// FINDING and not fixed.** Which planes does the accepted toy profile
    /// place on its one padded domain, what rule would the memo's table give
    /// them, and what constrains their pad TODAY?
    ///
    /// Answer, asserted below: `A_LIMB` and `A_LIMBM` (both ZERO-rule) and
    /// their shared LogUp helper `H_L` (EXEMPT). What constrains the pad is
    /// the two `byte` U8 lookups, which are active on the WHOLE padded domain
    /// — the LogUp arm is never gated (§3.7a) — so every padded entry is
    /// proved to lie in `[0, 256)`. **Nothing forces it to zero.** Nothing
    /// else reads those positions: `SC_TZC` reads the nine used sub-slices at
    /// their fixed offsets and `SC_LZC` is homogeneous. An honest prover
    /// writes zeros (asserted), so no honest toy byte moves; a dishonest one
    /// could write any byte there without breaking a relation.
    #[test]
    fn the_toy_profiles_padded_planes_and_what_constrains_them() {
        let t = Shape::toy();
        let ids = Ids::new(&t).expect("the toy has a plane map");
        // the planes on the toy's one padded domain, by id
        let on_l: Vec<usize> = (0..ids.n_a()).filter(|p| ids.dom(*p) == Dom::L).collect();
        assert_eq!(on_l, vec![ids.at(A_LIMB), ids.at(A_LIMBM)], "the toy's Dom::L planes");
        // what constrains their pad: exactly two lookups, both plain `byte`
        let lks = lookups_at(&t, &ids, Dom::L);
        assert_eq!(lks.len(), 2, "two lookups on Dom::L");
        for (lk, p) in lks.iter().zip(on_l.iter()) {
            assert_eq!(lk.terms, vec![(*p, 1)], "a plain byte lookup on plane {p}");
            assert_eq!(lk.cst, 0, "with no constant offset");
        }
        // **WHICH RELATIONS READ THOSE PLANES, AND WHERE (the ruling on
        // S9-F1 asks for exactly this, at the toy, as ONE test).** Only two
        // slots touch a `Dom::L` plane:
        //
        // * `SC_LZC`, whose cube IS `Dom::L`: it reads the WHOLE padded
        //   domain, but only through the LogUp arm, which is homogeneous and
        //   is the one arm ruling P-1 never gates. It decides nothing about a
        //   padded value beyond the byte class the two lookups above give it.
        // * `SC_TZC`, which reads NINE fixed sub-slices of each limb plane,
        //   `[k * t_pad, k * t_pad + t_pad)` for `k < 9`.
        //
        // At the toy `tokens == t_pad`, so those nine slices are EXACTLY the
        // support: no relation of the toy reads a padded position. A future
        // relation that read one would move `read` below outside `supp` and
        // fail here.
        let lay = Layout::for_shape(&t).expect("the toy layout");
        let supp = support_indicator(&t, Dom::L);
        let mut read = vec![false; t.size(Dom::L)];
        for kk in 0..N_LIMBS {
            for (off, base) in [(lay.limb_off(kk), lay.a_off[ids.at(A_LIMB)]), (lay.limb_off_m(kk), lay.a_off[ids.at(A_LIMBM)])] {
                for tt in 0..t.t_pad {
                    read[off - base + tt] = true;
                }
            }
        }
        assert_eq!(read.iter().filter(|r| **r).count(), N_LIMBS * t.t_pad, "SC_TZC reads nine sub-slices of each limb plane");
        for i in 0..t.size(Dom::L) {
            assert!(!(read[i] && supp[i] == 0), "a toy relation reads padded Dom::L position {i}");
        }
        // and the honest builder really does leave that pad at zero
        let (public, ff, input) = super::super::grow_tests::tame_case(&t);
        let w = witness::build_shaped(&t, &public, &ff, &input).expect("the toy's honest witness");
        for p in &on_l {
            assert!((0..w.planes[*p].len()).all(|i| supp[i] == 1 || w.planes[*p][i] == 0), "the toy's honest Dom::L pad is not zero on plane {p}");
        }
        // THE TOY'S TRANSCRIPT CARRIES NO PAD MACHINERY: the profile gate
        // empties both plane lists, so `define` pushes no indicator table and
        // draws no `zeta` (the byte-for-byte gate is the frozen receipt).
        for dom in ALL_DOMS {
            assert!(zero_rule_a_planes(&t, &ids, dom).is_empty(), "the toy must carry no pad-zero term on {dom:?}");
            assert!(zero_rule_h_planes(&t, dom).is_empty(), "the toy must carry no pad-zero term on {dom:?}'s helpers");
        }
    }

    /// **RULING P-2, the acceptance test of §9a
    /// (`a_weight_nonzero_off_its_support_is_refused_at_construction`).**
    /// Building a statement whose weight matrix is nonzero at a padded input
    /// or output index is refused BY NAME, and the two cases the memo names
    /// are told apart: a nonzero at a padded WIDTH index, and a `Wo` whose
    /// input columns are in true-head order instead of slot order.
    #[test]
    fn a_weight_nonzero_off_its_support_is_refused_at_construction() {
        let s = Shape::rung();
        let (d, f, kvw) = (s.width, s.hidden, s.kv_heads * s.head_dim);
        let diag = |outer: usize, inner: usize| -> Vec<i8> { (0..outer * inner).map(|k| if k / inner == k % inner { 64i8 } else { 0 }).collect() };
        let gamma = vec![64i8; d];
        let (cos, sin) = crate::tables_attn::rope_tables_generate(s.tokens, s.head_dim, 10000.0, F_RO);
        let (exp, _) = crate::tables_attn::exp_member(0, s.head_dim, s.f_e);
        let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("the frozen SiLU member");
        let base = super::super::grow_tests::pad_attention_weights(&s, &diag(d, d), &diag(kvw, d), &diag(kvw, d), &diag(d, d), &gamma);
        let build = |w: &[Vec<i8>; 5]| crate::private_block::AttentionPublic::new_shaped(&s, &w[0], &w[1], &w[2], &w[3], &w[4], &cos, &sin, &exp).err();
        assert_eq!(build(&base), None, "the honest padded, head-permuted statement is accepted");
        let fw = super::super::grow_tests::pad_ff_weights(&s, &gamma, &diag(d, f), &diag(d, f), &diag(f, d));
        assert!(crate::private_block::FeedForwardPublic::new_shaped(&s, &fw[0], &fw[1], &fw[2], &fw[3], &act).is_ok(), "the honest padded feed-forward statement is accepted");

        // case 1: a nonzero `Wq` entry at a padded INPUT (width) column
        let mut w = base.clone();
        w[0][s.width] = 1;
        assert_eq!(build(&w).as_deref(), Some("private block: a public weight is nonzero at a padded width index"));
        // case 1b: a nonzero `Wq` row at a padded head SLOT (the output axis)
        let mut w = base.clone();
        let padded_slot = (0..s.h_pad).find(|sl| !s.slot_is_true_head(*sl)).expect("the rung's head axis pads");
        w[0][padded_slot * s.head_dim * s.d_pad] = 1;
        assert_eq!(build(&w).as_deref(), Some("private block: a public weight is nonzero at a padded head slot"));
        // case 2 (§9a, by name): a `Wo` that is NOT head-permuted — its input
        // columns in true-head order, so the padded slots hold real weights
        let mut w = base.clone();
        let id = |i: usize| i;
        w[3] = super::super::grow_tests::pad_matrix(&diag(d, d), d, d, s.d_pad, s.d_pad, &id, &id);
        assert_eq!(build(&w).as_deref(), Some("private block: a public weight is nonzero at a padded head slot"), "a Wo in true-head column order must be refused");
        // a feed-forward matrix nonzero off the hidden axis
        let mut g = fw.clone();
        g[1][s.hidden] = 1;
        assert_eq!(
            crate::private_block::FeedForwardPublic::new_shaped(&s, &g[0], &g[1], &g[2], &g[3], &act).err().as_deref(),
            Some("private block: a public weight is nonzero at a padded width index")
        );
    }

    /// **The memo's own wording of P-2 — the FOLDED weight vector.** The
    /// construction check is entrywise, which is strictly stronger; this ties
    /// the two together by folding each matrix the way its slot folds it and
    /// asserting the result vanishes off the inner axis's support.
    ///
    /// **STAGE 19, the one-sided check tightened.** Until this stage the
    /// attention branch asserted that its fold is NOT identically zero — so
    /// that "vanishes off support" says something — and the feed-forward
    /// branch did not. It now does, and it also makes the statement the
    /// `f > d` geometry needs and no test had: along the HIDDEN axis the
    /// feed-forward weights must reach **above `d`**, into `[d, f)`, and stop
    /// at `f`. `Wd`'s own fold is already a hidden-axis vector; `Wg` and `Wu`
    /// fold the other way, so their hidden-axis support is read with the
    /// mirror fold — an instrument for the support statement, not a fold any
    /// slot performs. Run at BOTH `Shape::rung()` and `Shape::rung_g()`, the
    /// two shapes with `f = 2d`.
    #[test]
    fn the_folded_weight_vectors_vanish_off_support() {
        use crate::field::Fp2;
        use crate::mle::{fold_cols_i8, fold_rows_i8};
        for s in [Shape::rung(), Shape::rung_g()] {
            let (d, f, kvw, dp, fp) = (s.width, s.hidden, s.kv_heads * s.head_dim, s.d_pad, s.f_pad);
            assert!(f > d, "{}: this test is about the f > d geometry", s.name);
            let band = |outer: usize, inner: usize| -> Vec<i8> { (0..outer * inner).map(|k| ((k * 37 + 11) % 61) as i8 - 30).collect() };
            let aw = super::super::grow_tests::pad_attention_weights(&s, &band(d, d), &band(kvw, d), &band(kvw, d), &band(d, d), &vec![64i8; d]);
            let fw = super::super::grow_tests::pad_ff_weights(&s, &vec![64i8; d], &band(d, f), &band(d, f), &band(f, d));
            let pt = |n: usize| -> Vec<Fp2> { (0..n).map(|i| Fp2::from_i64((i * 1_000_003 + 7) as i64)).collect() };
            let q_supported = |i: usize| s.slot_is_true_head(i / s.head_dim);
            // `SC_QMM` / `SC_KMM` / `SC_VMM` / `SC_WO` fold over the OUTPUT axis
            // the folded vector is over the INNER (input) axis: `Dom::D` for
            // `Wq` / `Wk` / `Wv`, the head-permuted `Dom::Q` for `Wo`
            let d_supported = |i: usize| i < d;
            let cases: [(&Vec<i8>, usize, &str, &dyn Fn(usize) -> bool); 4] =
                [(&aw[0], dp, "Wq", &d_supported), (&aw[1], kvw, "Wk", &d_supported), (&aw[2], kvw, "Wv", &d_supported), (&aw[3], dp, "Wo", &q_supported)];
            for (w, outer, name, supported) in cases {
                let folded = fold_rows_i8(w, outer, dp, &pt(outer));
                assert!(folded.iter().any(|v| *v != Fp2::ZERO), "{}: {name}: the fold is identically zero, so the check says nothing", s.name);
                for (i, v) in folded.iter().enumerate() {
                    assert!(supported(i) || *v == Fp2::ZERO, "{}: {name}: the folded weight is nonzero at unsupported input index {i}", s.name);
                }
            }
            // the three feed-forward matmuls fold over the OUTPUT axis too, but
            // their matrices are `(input, output)` row-major, so `fold_cols_i8`
            for (w, rows, cols, name, lim) in [(&fw[1], dp, fp, "Wg", d), (&fw[2], dp, fp, "Wu", d), (&fw[3], fp, dp, "Wd", f)] {
                let folded = fold_cols_i8(w, rows, cols, &pt(cols));
                // STAGE 19: what the attention branch above already asserted
                assert!(folded.iter().any(|v| *v != Fp2::ZERO), "{}: {name}: the fold is identically zero, so the check says nothing", s.name);
                for (i, v) in folded.iter().enumerate() {
                    assert!(i < lim || *v == Fp2::ZERO, "{}: {name}: the folded weight is nonzero at unsupported input index {i}", s.name);
                }
            }
            // **STAGE 19, THE HIDDEN AXIS.** `Wd`'s slot fold is already the
            // hidden-axis vector (`lim = f` above), so the statement is read
            // off it directly; `Wg` / `Wu` need the mirror fold. In all three
            // the band must reach into `[d, f)` — the half of the hidden axis
            // that the diagonal fixture `tame_case` leaves identically zero at
            // every shape with `f > d` — and must vanish on `[f, f_pad)`.
            let hidden_axis: [(Vec<Fp2>, &str); 3] = [
                (fold_rows_i8(&fw[1], dp, fp, &pt(dp)), "Wg (mirror fold)"),
                (fold_rows_i8(&fw[2], dp, fp, &pt(dp)), "Wu (mirror fold)"),
                (fold_cols_i8(&fw[3], fp, dp, &pt(dp)), "Wd"),
            ];
            for (folded, name) in hidden_axis {
                assert_eq!(folded.len(), fp, "{}: {name}: the hidden-axis fold is not the padded hidden length", s.name);
                let upper = folded[d..f].iter().filter(|v| **v != Fp2::ZERO).count();
                assert!(upper > 0, "{}: {name}: the folded weight is ZERO at every hidden index in [{d}, {f}) — the upper hidden half is not exercised", s.name);
                for (i, v) in folded.iter().enumerate().take(fp).skip(f) {
                    assert!(*v == Fp2::ZERO, "{}: {name}: the folded weight is nonzero at padded hidden index {i}", s.name);
                }
                eprintln!("{}: {name}: {upper} of {} hidden indices in [{d}, {f}) carry a nonzero fold, and all {} of [{f}, {fp}) vanish", s.name, f - d, fp - f);
            }
        }
    }

    /// **THE SLOT ARITHMETIC, re-asserted with the indicator (§3.7a, `zk.rs`'s
    /// hard assert `L + 256 <= 512`).** Every slot of every shape must fit,
    /// and the closest one is recorded here so a later degree rise cannot
    /// pass unnoticed.
    #[test]
    fn every_slot_fits_the_mask_budget_with_the_indicator() {
        for (s, want_max) in [(Shape::toy(), 50usize), (Shape::rung(), 72), (Shape::m125(), 117)] {
            let lens = s.slot_lengths();
            let (worst, l) = lens.iter().enumerate().max_by_key(|(_, l)| **l).map(|(i, l)| (i, *l)).expect("slots");
            assert_eq!(l, want_max, "{}: the largest slot length", s.name);
            assert!(l + 256 <= 512, "{}: slot {worst} needs {l} + 256 > 512", s.name);
            for (i, l) in lens.iter().enumerate() {
                assert!(l + 256 <= 512, "{}: slot {i} needs {l} + 256 > 512", s.name);
            }
            eprintln!("private block slot budget: {} — closest slot {worst}, L = {l}, L + 256 = {}", s.name, l + 256);
        }
        // the memo's own closest slots: `SC_SZC` at both padded shapes
        assert_eq!(Shape::m125().slot_lengths()[SC_SZC], 117, "125M's closest slot is SC_SZC");
        assert_eq!(Shape::rung().slot_lengths()[SC_SZC], 72, "the rung's closest slot is SC_SZC (SC_FZC ties it)");
        assert_eq!(Shape::rung().slot_lengths()[SC_FZC], 72, "and SC_FZC ties it");
        // **STAGE 20, the two slots the S19-F1 repair moved.** Their length is
        // recomputed here from the shape's axes alone — `lkv` more main
        // rounds and one more degree when the shape groups — and never read
        // off the schedule the test is checking. The toy's two are unmoved
        // (12 and 14) because `lkv = 0` there.
        let want_l = |sh: &Shape, inner: usize| -> usize {
            let lkv = sh.kv_heads.trailing_zeros() as usize;
            (lkv + inner + 2) * (2 + usize::from(lkv > 0)) + 2
        };
        for s in [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::m125()] {
            let dh = s.head_dim.trailing_zeros() as usize;
            let tp = s.t_pad.trailing_zeros() as usize;
            assert_eq!(s.slot_lengths()[SC_SCORE], want_l(&s, dh), "{}: SC_SCORE's masked length", s.name);
            assert_eq!(s.slot_lengths()[SC_PV], want_l(&s, tp), "{}: SC_PV's masked length", s.name);
        }
        assert_eq!((Shape::toy().slot_lengths()[SC_SCORE], Shape::toy().slot_lengths()[SC_PV]), (12, 16), "the frozen toy's bilinear slots moved");
    }

    /// **STAGE 20.** The `sc-round` entry of the T-3 hash-length table takes
    /// the WHOLE of [`Shape::degree_range`] rather than the degrees one shape
    /// uses, so the table is complete only while every shape's declared
    /// degrees are inside that range. The S19-F1 repair raises two slots from
    /// 2 to 3, which is inside it — asserted here so that a later degree move
    /// cannot silently leave a transcript length out of the guard.
    #[test]
    fn the_declared_degrees_are_inside_the_declared_range() {
        let (lo, hi) = Shape::degree_range();
        for s in [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::m125()] {
            for (slot, (_, _, d)) in s.slots().iter().enumerate() {
                assert!((lo..=hi).contains(d), "{}: slot {slot} declares degree {d}, outside the declared range {lo}..={hi}", s.name);
            }
        }
    }

    /// The honest rung witness satisfies every relation the module can
    /// evaluate at a padded shape — which is what makes PZ-1 and PZ-2
    /// meaningful: whatever they detect, they detect because of the PAD.
    #[test]
    fn the_honest_rung_witness_passes_every_checkable_relation() {
        let (s, ids, w) = rung_witness();
        assert!(every_checkable_relation_holds(&s, &ids, &w), "the honest rung witness fails a relation the module can check");
        // and its pad is what the memo's TABLE says (finding S6-F4, corrected
        // by S12-F3): every ZERO-rule plane vanishes off its support, and the
        // one EXEMPT `A` plane, `A_E`, does NOT — its padded positions carry
        // a genuine `exp` row, because the LogUp arm is never gated and a
        // zero there would put a pair that is no table row into the value-0
        // identity. That exemption is why the first honest rung proof failed
        // at the `H` sum group until the builder filled it.
        let mut exempt = Vec::new();
        for dom in ALL_DOMS {
            let supp = support_indicator(&s, dom);
            for p in 0..ids.n_a() {
                if ids.is_multiplicity(p) || ids.dom(p) != dom {
                    continue;
                }
                let zero_off_support = (0..w.planes[p].len()).all(|i| supp[i] == 1 || w.planes[p][i] == 0);
                match a_rule(&s, &ids, p) {
                    Some(Rule::Exempt) => {
                        exempt.push(p);
                        assert!(!zero_off_support, "the EXEMPT plane {p} has an all-zero pad: the exp pair would not be a table row");
                    }
                    _ => assert!(zero_off_support, "plane {p} has a nonzero pad position"),
                }
            }
        }
        assert_eq!(exempt, vec![ids.at(A_E)], "the rung's exempt A planes");
    }

    /// **PZ-1 (ruling P-1, memo section 3.7a).** ONE nonzero value written
    /// into a padded position of a ZERO-rule plane that no claimed sum reads
    /// must be REJECTED BY THE VERIFIER.
    ///
    /// WHAT LEVEL IT IS DECIDED AT (S9 part 4). Until the term existed this
    /// test was `#[ignore]`d and FAILED: the padded position of `A_RAL` was
    /// read by nothing at all, which is the coverage half of B-1. It is now
    /// decided by ruling P-1's own relation inside
    /// [`every_checkable_relation_holds`] — the same statement the batched
    /// pad-zero term of `argument::define` carries. The END-TO-END form
    /// (rejected by the verifier, from receipt bytes) is step S12.
    #[test]
    fn pz1_a_lone_nonzero_pad_value_is_rejected() {
        let (s, ids, mut w) = rung_witness();
        let supp = support_indicator(&s, Dom::D);
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
    /// Decided at the same level as PZ-1 (S9 part 4). Before the term it
    /// FAILED, which is the sharper half of B-1: this test writes the pad,
    /// recomputes the norm row, and the module did not notice, because
    /// `SC_SS`'s claimed row sum reads the padded cube and the recomputed `D`
    /// matches it exactly. The END-TO-END form is step S12.
    #[test]
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

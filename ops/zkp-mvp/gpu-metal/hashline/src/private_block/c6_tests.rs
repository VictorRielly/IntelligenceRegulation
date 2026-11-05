//! **STAGE 31: CORRECTION C-6, IN THE ORDINARY FILTER.**
//!
//! **The gap this closes.** A window of `w` bits held in `l` byte limbs
//! leaves `8l - w` slack bits in the top limb, so `layout::lookups_at` pins
//! the top limb with `scaled(top, 1 << (8l - w))` beside the `byte(top)`
//! lookup every limb gets. When the window fills its top limb exactly the
//! coefficient is `1 << 0 = 1`, the `scaled` entry is the same `Lk` as the
//! `byte` entry already emitted, and all FOUR of them — `rho` and `sigma` of
//! `norm_a` and of `norm_m` — are dropped. That is **correction C-6**:
//!
//! ```text
//! let norm_top = !sh.norm_top_is_full_byte();
//! ...
//! if norm_top { v.push(scaled(ids.nr(ln - 1), norm_scale)); }
//! ```
//!
//! so `Dom::D` carries **34** lookups per position instead of 38, **17**
//! helper planes instead of 19, and the `H` plane list is **50** planes
//! instead of 52.
//!
//! **Nothing in the ordinary filter reached that arm.** The flag is
//! `norm_wrho == 8 * limbs_norm`, and `norm_wrho = NORM_TN + 1 +
//! bit_length(D_max)` with `D_max = isqrt(1 + width * 32767^2)`, so it is a
//! function of the WIDTH alone and turns on the moment the width passes 256.
//! The toy is at width 16 (`norm_wrho` 29) and `rung`, `rung_g`, `rung_k4`
//! and `rung_p2` are all at width 96 (31). The one shape with the flag TRUE
//! is 125M, and every 125M proof is an `#[ignore]`d 10 GiB test.
//!
//! The security owner's standing rule after finding S19-F1 is that a branch
//! which only an ignored heavy test reaches is a branch nobody tests.
//! [`Shape::rung_c6`] closes it: rung-P2 with the head dimension moved from
//! 8 to 32 — the smallest value that crosses the window — and the two axes
//! that must follow, at a size the ordinary filter proves in about a second.
//!
//! **THE SOUNDNESS QUESTION C-6 RAISES, AND THE ANSWER.** Dropping a
//! range lookup is exactly the kind of optimisation that quietly removes an
//! obligation. It does not here, and
//! [`the_lookup_c6_drops_is_a_duplicate_of_one_that_stays`] is the
//! statement: at this shape the dropped entry's coefficient is `1`, so
//! `scaled(top, 1)` is TERM FOR TERM the `Lk` that `byte(top)` builds, and
//! `byte(top)` is emitted unconditionally by the `(0..ln)` loop above it. The
//! obligation "the top limb is in `[0, 256)`" is therefore carried by a
//! lookup that stays, and
//! [`a_norm_top_limb_outside_its_byte_range_is_rejected_at_the_rung_c6`]
//! puts a witness with an out-of-range top limb — and with every arithmetic
//! relation of the block still exactly satisfied — in front of the real
//! verifier.
//!
//! **WHAT A GREEN RUN HERE IS, AND IS NOT.** A CORRECTNESS result at a new
//! development-grade profile (ruling P-7): the honest prover and the honest
//! verifier agree on a GENERIC witness (dense public weights, a non-constant
//! hidden input, four key-value groups carrying pairwise different data),
//! the witness equals the independent reference kernel element for element
//! (`parity::the_dense_witness_equals_the_reference_kernel_at_the_rung_c6`),
//! and every tamper this branch could get wrong is rejected by the VERIFIER.
//! It is NOT a privacy result and NOT an acceptance.
//!
//! **THE CAPTURE RULE.** Everything here is public synthetic test data from
//! fixed-seed integer streams; what the census prints is counts, fractions
//! and live-slot counts, never a value or a position.

use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::review_tests::{clone_witness, outcome, Outcome};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::field::Fp2;

// ---------------------------------------------------------------- the shape's own facts

/// **THE COUNTED RECEIPT LENGTH OF ONE rung-C6 BLOCK.**
///
/// The INDEPENDENT Python model's own output at this shape
/// (`scripts/zk60_private_block_layout_model.py`, `SHAPES["rung_c6"]`,
/// `results/zk60_block125m_lane/model_rung_c6.json`), transcribed, with
/// nothing in between.
pub(super) const C6_FRAME_BYTES: usize = 7_452_040;

/// every shape this module builds — the registry the gap census runs over,
/// kept in the same order as `s24_tests::every_shape`
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::m125()]
}

fn c6_context() -> Digest {
    *blake3::hash(b"private block: stage 31, correction C-6").as_bytes()
}

/// the padded plane of a witness, as `int16`
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

/// the TRUE `(tokens, width)` input inside a padded `Dom::D` plane
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// the four TOP norm limb planes of a shape, by the names `layout.rs` uses:
/// `rho` and `sigma` of `norm_a` (`A_NR*`, `A_NS*`) and of `norm_m`
/// (`A_MR*`, `A_MS*`). These are the four planes C-6 is about.
fn top_norm_limbs(sh: &Shape, ids: &Ids) -> [(&'static str, usize); 4] {
    let ln = sh.limbs_norm();
    [("norm_a rho top limb (A_NR)", ids.nr(ln - 1)), ("norm_a sigma top limb (A_NS)", ids.ns(ln - 1)), ("norm_m rho top limb (A_MR)", ids.mr(ln - 1)), ("norm_m sigma top limb (A_MS)", ids.ms(ln - 1))]
}

/// Does this lookup list carry `Lk { terms: [(plane, coef)], cst: 0 }`?
fn has_single_term(lks: &[Lk], plane: usize, coef: i64) -> bool {
    lks.iter().any(|l| l.cst == 0 && l.terms.len() == 1 && l.terms[0] == (plane, coef))
}

/// how many single-term lookups of `lks` read `plane`
fn count_on(lks: &[Lk], plane: usize) -> usize {
    lks.iter().filter(|l| l.terms.len() == 1 && l.terms[0].0 == plane).count()
}

// ---------------------------------------------------------------- the gap

/// **THE GAP, STATED AS A CENSUS AND ASSERTED.**
///
/// For every shape the module builds, whether the norm window fills its top
/// byte limb — which is the whole of correction C-6's condition — and what
/// that costs `Dom::D`:
///
/// | shape | width | `norm_wrho` | `norm_top_is_full_byte` | `Dom::D` lookups / helpers |
/// |---|---:|---:|---|---:|
/// | `toy` | 16 | 29 | no | 38 / 19 |
/// | `rung`, `rung_g`, `rung_k4`, `rung_p2` | 96 | 31 | no | 38 / 19 |
/// | `m125` | 768 | 32 | **yes** | **34 / 17** — every proof `#[ignore]`d |
/// | `rung_c6` (new) | 384 | 32 | **yes** | **34 / 17**, in this filter |
///
/// The test asserts every cell, and asserts the NON-VACUITY that makes it a
/// gap: with the new shape removed from the registry, the only shape on the
/// C-6 arm is 125M.
#[test]
fn only_the_125m_shape_and_the_new_one_reach_correction_c_6() {
    let shapes = every_shape();
    let on: Vec<&'static str> = shapes.iter().filter(|s| s.norm_top_is_full_byte()).map(|s| s.name).collect();
    assert_eq!(on.len(), 2, "the shapes on the C-6 arm are {on:?}, not exactly two");
    assert_eq!(on[1], Shape::m125().name, "125M is not on the C-6 arm");
    assert_eq!(on[0], Shape::rung_c6().name, "the new shape is not on the C-6 arm");
    // NON-VACUITY: before this stage the arm belonged to 125M alone
    let before: Vec<&'static str> = shapes.iter().filter(|s| s.profile != Shape::rung_c6().profile).filter(|s| s.norm_top_is_full_byte()).map(|s| s.name).collect();
    assert_eq!(before, vec![Shape::m125().name], "the gap this stage closes does not exist");
    // the flag is a function of the WIDTH, and the census says so
    for sh in &shapes {
        let ids = Ids::new(sh).expect("a plane map");
        let lks = lookups_at(sh, &ids, Dom::D);
        assert_eq!(sh.limbs_norm(), 4, "{}: every shape in scope holds the norm remainder in four limbs", sh.name);
        assert_eq!(sh.norm_top_is_full_byte(), sh.norm_wrho == 32, "{}: the C-6 flag is not `norm_wrho == 32` at four limbs", sh.name);
        assert_eq!(sh.norm_top_is_full_byte(), sh.width > 256, "{}: the C-6 flag is not `width > 256`", sh.name);
        let want = if sh.norm_top_is_full_byte() { (34, 17) } else { (38, 19) };
        assert_eq!((sh.lookups_per_position(Dom::D), sh.helpers(Dom::D)), want, "{}: Dom::D's lookup and helper counts", sh.name);
        assert_eq!(lks.len(), want.0, "{}: the BUILT Dom::D lookup list is not the counted length", sh.name);
        eprintln!(
            "S31 C-6 CENSUS {:<62} width {:>4} D_max {:>7} norm_wrho {} full_byte {:<5} Dom::D {} lookups / {} helpers, H planes {}",
            sh.name,
            sh.width,
            sh.d_max,
            sh.norm_wrho,
            sh.norm_top_is_full_byte(),
            lks.len(),
            sh.helpers(Dom::D),
            sh.h_plane_doms().len()
        );
    }
}

/// **THE SOUNDNESS STATEMENT OF THIS STAGE: what C-6 drops is a DUPLICATE
/// of a lookup that stays.**
///
/// The dropped entry is `scaled(top, 1 << (8 ln - wrho))`. At a shape whose
/// window fills the top limb, `8 ln == wrho` and the coefficient is `1 << 0
/// = 1`, so the entry is `Lk { terms: [(top, 1)], cst: 0 }` — which is
/// exactly what `byte(top)` builds, and `byte(top)` is emitted
/// unconditionally by the `(0..ln).map(|k| byte(ids.nr(k)))` loop directly
/// above it. **The range obligation on the top limb is therefore carried by
/// a lookup C-6 does not touch**, and dropping the duplicate removes a
/// multiplicity from the LogUp histogram and nothing else.
///
/// The test states it three ways, so that no one of them has to be
/// believed on its own:
///
/// * the coefficient is 1 at rung-C6 and 2 at rung-P2, computed from the
///   shape and not read off a table;
/// * at rung-C6 each of the four top limb planes is read by **exactly one**
///   lookup and that lookup is `(plane, 1)`; at rung-P2 each is read by
///   **two**, `(plane, 1)` and `(plane, 2)`;
/// * the two lists differ by exactly the four `(plane, 1)` duplicates: the
///   multiset of rung-P2's `Dom::D` lookups minus rung-C6's is those four
///   scaled entries and nothing else.
#[test]
fn the_lookup_c6_drops_is_a_duplicate_of_one_that_stays() {
    let (c6, p2) = (Shape::rung_c6(), Shape::rung_p2());
    let (ic, ip) = (Ids::new(&c6).expect("plane map"), Ids::new(&p2).expect("plane map"));
    assert_eq!(1i64 << (8 * c6.limbs_norm() as u32 - c6.norm_wrho), 1, "the dropped lookup's coefficient at rung-C6 is not 1");
    assert_eq!(1i64 << (8 * p2.limbs_norm() as u32 - p2.norm_wrho), 2, "rung-P2's top-limb coefficient is not 2");
    let (lc, lp) = (lookups_at(&c6, &ic, Dom::D), lookups_at(&p2, &ip, Dom::D));
    for ((name, pc), (_, pp)) in top_norm_limbs(&c6, &ic).into_iter().zip(top_norm_limbs(&p2, &ip)) {
        // rung-C6: ONE lookup on the plane, the byte one
        assert!(has_single_term(&lc, pc, 1), "rung-C6: {name} has no `byte` lookup, so C-6 would have removed its range obligation");
        assert!(!has_single_term(&lc, pc, 2), "rung-C6: {name} carries a scaled lookup C-6 says is dropped");
        assert_eq!(count_on(&lc, pc), 1, "rung-C6: {name} is read by more than the byte lookup");
        // rung-P2: TWO, and the scaled one is the one that is NOT a duplicate
        assert!(has_single_term(&lp, pp, 1) && has_single_term(&lp, pp, 2), "rung-P2: {name} does not carry both the byte and the scaled lookup");
        assert_eq!(count_on(&lp, pp), 2, "rung-P2: {name} is read by other than two lookups");
        eprintln!("S31 C-6 DUPLICATE {name}: rung-C6 keeps `byte(plane)` and drops `scaled(plane, 1)`, which is the SAME Lk; rung-P2 keeps `byte(plane)` and `scaled(plane, 2)`, which is not");
    }
    // and the two lists differ by exactly those four entries
    let key = |l: &Lk| (l.cst, l.terms.clone());
    let mut only_p2: Vec<(i64, Vec<(usize, i64)>)> = lp.iter().map(key).collect();
    for k in lc.iter().map(key) {
        let i = only_p2.iter().position(|x| *x == k).unwrap_or_else(|| panic!("rung-C6 carries a Dom::D lookup rung-P2 does not: {k:?}"));
        only_p2.remove(i);
    }
    assert_eq!(only_p2.len(), 4, "the two Dom::D lists differ by {} lookups, not by C-6's four", only_p2.len());
    let tops: Vec<usize> = top_norm_limbs(&p2, &ip).into_iter().map(|(_, p)| p).collect();
    for (cst, terms) in &only_p2 {
        assert_eq!(*cst, 0, "a dropped lookup is not homogeneous");
        assert_eq!(terms.len(), 1, "a dropped lookup is not a single term");
        assert_eq!(terms[0].1, 2, "a dropped lookup's coefficient at rung-P2 is not 2");
        assert!(tops.contains(&terms[0].0), "a dropped lookup does not read a TOP norm limb");
    }
    eprintln!("S31 C-6 DIFFERENCE: rung-P2's Dom::D list minus rung-C6's is exactly the four scaled top-limb entries; at rung-C6 their coefficient would be 1, i.e. the byte lookup already in the list");
}

/// **THE LAYOUT CENSUS, BY NAME: what C-6 drops is ABSENT here and PRESENT
/// at rung-K4.**
///
/// The four lookups, the two `Dom::D` helper planes that carried them, the
/// two `H` plane-list entries and the two `H` claim sites, each named and
/// each counted on both shapes. The side-by-side table of rung-K4 / rung-P2
/// / rung-C6 / 125M is printed with it.
#[test]
fn the_rows_and_lookups_c6_drops_are_absent_here_and_present_at_rung_k4() {
    let (c6, p2, k4, m) = (Shape::rung_c6(), Shape::rung_p2(), Shape::rung_k4(), Shape::m125());
    // the four lookups
    for sh in [&c6, &k4] {
        let ids = Ids::new(sh).expect("plane map");
        let lks = lookups_at(sh, &ids, Dom::D);
        for (name, p) in top_norm_limbs(sh, &ids) {
            let scaled_here = lks.iter().any(|l| l.cst == 0 && l.terms.len() == 1 && l.terms[0].0 == p && l.terms[0].1 != 1);
            assert_eq!(scaled_here, !sh.norm_top_is_full_byte(), "{}: {name}'s scaled lookup is present exactly when C-6 does not apply", sh.name);
        }
    }
    // the two helper planes, and the two H plane-list entries
    assert_eq!((c6.helpers(Dom::D), k4.helpers(Dom::D)), (17, 19), "the Dom::D helper counts");
    let hc = c6.h_plane_doms();
    let hk = k4.h_plane_doms();
    assert_eq!((hc.len(), hk.len()), (50, 52), "the H plane lists");
    assert_eq!((hc.iter().filter(|d| **d == Dom::D).count(), hk.iter().filter(|d| **d == Dom::D).count()), (17, 19), "the H list's Dom::D block");
    for dom in ALL_DOMS.into_iter().filter(|d| *d != Dom::D) {
        assert_eq!(hc.iter().filter(|x| **x == dom).count(), hk.iter().filter(|x| **x == dom).count(), "{dom:?}'s H block moved, and only Dom::D's may");
    }
    // the two H claim sites, read off the built layouts
    let (lc, lk) = (Layout::for_shape(&c6).expect("layout"), Layout::for_shape(&k4).expect("layout"));
    assert_eq!(lk.h_sites().iter().sum::<usize>() - lc.h_sites().iter().sum::<usize>(), 2, "the H claim-site totals do not differ by the two dropped helpers");
    assert_eq!(lc.a_sites().iter().sum::<usize>(), lk.a_sites().iter().sum::<usize>(), "an A claim site moved, and C-6 touches none");
    assert_eq!((lc.a_rows, lc.h_rows), (1337, 1408), "the rung-C6 commitment rows");
    // 125M is on the same arm, which is the fact this shape stands in for
    assert_eq!((m.helpers(Dom::D), m.h_plane_doms().len()), (17, 50), "125M is not on the C-6 arm this shape stands in for");
    // THE SIDE-BY-SIDE TABLE
    eprintln!("S31 SIDE BY SIDE   shape | full_byte | pad_on per domain | A rows | H rows | Dom::D lookups | slot 14 terms | lkv | head_dim | row width");
    for sh in [&k4, &p2, &c6, &m] {
        let lay = Layout::for_shape(sh).expect("layout");
        let pads: Vec<String> = ALL_DOMS.into_iter().map(|d| format!("{d:?}:{}", u8::from(sh.pads(d)))).collect();
        eprintln!(
            "S31   {:<62} {:<5} | {} | A {:>5} | H {:>5} | D {:>2} lookups / {:>2} helpers | slot 14 terms {:>2} | lkv {} | head_dim {:>2} | 2^{}",
            sh.name,
            sh.norm_top_is_full_byte(),
            pads.join(" "),
            lay.a_rows,
            lay.h_rows,
            sh.lookups_per_position(Dom::D),
            sh.helpers(Dom::D),
            lay.slot_terms(SC_DZC),
            sh.kv_heads.trailing_zeros(),
            sh.head_dim,
            sh.log_cols
        );
    }
}

/// **THE NEW SHAPE IS rung-P2 WITH ONE AXIS MOVED**, and the assertions that
/// make every later measurement a measurement of C-6 and of the head
/// dimension and of nothing else: the same tokens, the same row width and
/// rate, the same calibration windows but the norm's, the same three
/// byte-limb counts but the norm top's consequence, the same head COUNT and
/// key-value grouping, the same padded-domain set, every named shape
/// refusal satisfied.
#[test]
fn the_new_shape_is_rung_p2_with_the_head_dimension_moved() {
    let (c6, p2, m) = (Shape::rung_c6(), Shape::rung_p2(), Shape::m125());
    assert_eq!((c6.tokens, c6.width, c6.hidden), (32, 384, 512), "rung-C6's block dimensions");
    assert_eq!((c6.q_heads, c6.head_dim, c6.kv_heads), (12, 32, 4), "rung-C6's head axis");
    assert_eq!((c6.t_pad, c6.d_pad, c6.h_pad, c6.f_pad), (32, 512, 16, 512), "rung-C6's padded axes");
    assert_eq!((c6.tokens, c6.q_heads, c6.kv_heads), (p2.tokens, p2.q_heads, p2.kv_heads), "rung-C6 moved something other than the head DIMENSION");
    assert_eq!((c6.log_cols, c6.inv_rate, c6.f_e), (p2.log_cols, p2.inv_rate, p2.f_e), "rung-C6's PCS parameters or calibration differ from rung-P2's");
    assert_eq!(c6.wrho_s, p2.wrho_s, "rung-C6's softmax window differs, so a second lookup family would move");
    assert_eq!((c6.limbs_sigma_s(), c6.limbs_p()), (p2.limbs_sigma_s(), p2.limbs_p()), "rung-C6's softmax limb counts differ from rung-P2's");
    assert_eq!(c6.limbs_sigma_s(), m.limbs_sigma_s(), "rung-C6 does not carry 125M's three sigma_s limbs");
    assert_eq!(c6.norm_wrho, 32, "rung-C6's norm window");
    assert_eq!(p2.norm_wrho, 31, "rung-P2's norm window");
    assert_eq!(c6.d_max, 642_099, "rung-C6's D_max");
    // the head permutation and the padded head slots are rung-P2's
    assert_eq!(c6.kv_heads.trailing_zeros() as usize, 2, "rung-C6 must carry TWO group bits");
    let slots: Vec<usize> = (0..c6.q_heads).map(|h| c6.head_slot(h)).collect();
    assert_eq!(slots, (0..p2.q_heads).map(|h| p2.head_slot(h)).collect::<Vec<usize>>(), "the head permutation moved");
    let pad_slots: Vec<usize> = (0..c6.h_pad).filter(|s| !c6.slot_is_true_head(*s)).collect();
    assert_eq!(pad_slots, vec![3, 7, 11, 15], "the padded head slots are not 125M's {{3, 7, 11, 15}}");
    // IT ALSO KEEPS STAGE 30's THREE UNPADDED DOMAINS — 125M's own set
    let unpadded: Vec<Dom> = ALL_DOMS.into_iter().filter(|d| !c6.pads(*d)).collect();
    assert_eq!(unpadded, vec![Dom::T, Dom::Kv, Dom::F], "rung-C6's unpadded domains are not T, Kv, F");
    assert_eq!(unpadded, ALL_DOMS.into_iter().filter(|d| !m.pads(*d)).collect::<Vec<Dom>>(), "rung-C6's unpadded set is not 125M's");
    assert_eq!(unpadded, ALL_DOMS.into_iter().filter(|d| !p2.pads(*d)).collect::<Vec<Dom>>(), "rung-C6 lost rung-P2's unpadded set");
    assert!(c6.carries_pad_rule(), "rung-C6 must carry the pad rule");
    for s in [SC_KVZC, SC_FZC] {
        assert_eq!(c6.slots()[s].2, 4, "slot {s} is not a degree below the all-padded pattern, so the unpadded arm is not exercised here");
    }
    // EVERY NAMED SHAPE REFUSAL, checked where it binds
    assert!(c6.head_dim.is_power_of_two() && c6.head_dim >= 2, "T-8");
    assert!(c6.t_pad.is_power_of_two() && c6.d_pad.is_power_of_two() && c6.f_pad.is_power_of_two(), "T-2");
    assert_eq!(c6.d_pad, c6.h_pad * c6.head_dim, "d_pad == h_pad * head_dim");
    assert_eq!(c6.width, c6.q_heads * c6.head_dim, "the reference kernel refuses a width that is not q_heads * head_dim");
    assert_eq!((c6.q_heads % c6.kv_heads, c6.h_pad % c6.kv_heads), (0, 0), "the grouping refusals");
    for dom in [Dom::Q, Dom::Kv, Dom::S] {
        assert_eq!(c6.log(dom), c6.natural_log(dom), "F-2: {dom:?} is lifted by P-3, so the bilinear slots cannot serve this shape");
    }
    assert_eq!(c6.log(Dom::Tab), c6.log_cols, "S-1: the table domain must sit exactly at the row width");
    assert!(c6.head_dim < 1usize << c6.log_cols, "S-3 / C-2: the head dimension reaches the row width");
    let worst = *c6.slot_lengths().iter().max().expect("slots");
    assert!(worst + 256 <= 512, "C-4: the mask budget");
    assert_eq!(worst, 77, "the worst slot's mask length");
    // the endpoint: sixteen data rows of the GENERALISED endpoint
    assert!(c6.endpoint_general, "rung-C6 must ride the generalised endpoint");
    assert_eq!((c6.endpoint_rows, c6.endpoint_log_n, c6.endpoint_inv_rate), (21, 10, 4), "rung-C6's endpoint");
    assert_eq!(c6.t_pad * c6.d_pad >> c6.endpoint_log_n, 16, "the endpoint's data rows");
    // D17: its own profile, its own key set
    assert_eq!(c6.profile, "hashline-zk-mr1/private-block-rung-c6-t32-dev/2");
    assert!(!c6.hashes_under_the_legacy_rule(), "rung-C6 must be TAGGED");
    assert_ne!(c6.hash_tag(), p2.hash_tag(), "rung-C6 and rung-P2 share a hash-tag key set");
    assert_eq!(run::RUN_PROFILE_RUNG_C6, "hashline-zk-mr1/private-run-rung-c6-t32-dev/2");
    // and the counted receipt, from the independent model
    assert_eq!(c6.receipt_bytes().total, C6_FRAME_BYTES, "the counted rung-C6 receipt is not the model's");
    assert_eq!(p2.receipt_bytes().total, super::p2_tests::P2_FRAME_BYTES, "rung-P2's counted receipt moved");
    assert_eq!(Shape::rung_k4().receipt_bytes().total, super::k4_tests::K4_FRAME_BYTES, "rung-K4's counted receipt moved");
    eprintln!(
        "S31 rung-C6: T{}/d{}/f{}, {} heads of {} over {} KV heads, pads ({}, {}, {}, {}), lkv 2, D_max {} -> norm_wrho {} -> C-6 ON, unpadded T/Kv/F, largest L {}, receipt {} B",
        c6.tokens, c6.width, c6.hidden, c6.q_heads, c6.head_dim, c6.kv_heads, c6.t_pad, c6.d_pad, c6.h_pad, c6.f_pad, c6.d_max, c6.norm_wrho, worst, c6.receipt_bytes().total
    );
}

// ---------------------------------------------------------------- the chain band probe

/// **THE FIRST ADMISSIBLE THREE-BLOCK DOWN BAND AT rung-C6 — MEASURED**,
/// exactly as stage 21 measures it at rung-G, stage 22 at rung-K4 and stage
/// 30 at rung-P2.
#[test]
fn the_pinned_rung_c6_chain_band_is_the_first_admissible_one() {
    use super::dense_tests::{band_down, band_down_run, dense_words_with, statement_of_words, BAND_ATTN, BAND_GATE, GAIN, INPUT_MAG};
    let sh = Shape::rung_c6();
    let ids = Ids::new(&sh).expect("plane map");
    let mut found: Option<i64> = None;
    for down in (1..=band_down(&sh)).rev() {
        let (words, input) = dense_words_with(&sh, BAND_ATTN, BAND_GATE, down, GAIN, INPUT_MAG);
        let (public, ff) = statement_of_words(&sh, &words);
        let mut x = input;
        let mut ok = true;
        for _ in 0..3 {
            match witness::build_shaped(&sh, &public, &ff, &x) {
                Ok(w) => x = true_input(&sh, &padded(&w, ids.at(A_X2))),
                Err(m) => {
                    eprintln!("C6 DENSE RUN band {down}: the witness builder refused a block of the chain: {m}");
                    ok = false;
                    break;
                }
            }
        }
        if ok {
            found = Some(down);
            break;
        }
    }
    let band = found.expect("no fully dense band makes a three-block chain admissible at rung-C6");
    eprintln!("C6 DENSE RUN: the first admissible three-block down band is {band} (the recipe's single-block band is {})", band_down(&sh));
    assert_eq!(band, band_down_run(&sh), "the band `dense_tests::band_down_run` pins for rung-C6 is not the first admissible one");
}

// ---------------------------------------------------------------- one honest block

fn endpoints_of(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the rung-C6 plane map");
    let spec = IoSpec::new_shaped(sh, c6_context(), 0, 0).expect("the rung-C6 endpoint spec");
    prepare_endpoints(spec, &padded(w, ids.at(A_X)), &padded(w, ids.at(A_X2))).expect("the rung-C6 endpoint owners")
}

fn prove_c6(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Receipt, Vec<u8>), String> {
    let (expected, owners) = endpoints_of(sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, receipt, bytes))
}

/// how non-trivial a rung-C6 witness is, as FRACTIONS and LIVE-SLOT COUNTS
/// only (the capture rule). It also asserts what this shape adds: the norm
/// remainders really do USE their top byte limb, so the range obligation
/// C-6 leans on is about live data and not about a limb that is always
/// zero.
fn assert_non_trivial(sh: &Shape, ids: &Ids, w: &Witness, what: &str) {
    let (d, f, fp, dh, dp) = (sh.width, sh.hidden, sh.f_pad, sh.head_dim, sh.d_pad);
    let kvw = sh.kv_heads * dh;
    for (plane, name, floor) in [(A_G8, "gate", 50u64), (A_A16, "activation", 20)] {
        let p = &w.planes[ids.at(plane)];
        let live = (0..sh.tokens).flat_map(|t| (d..f).map(move |j| t * fp + j)).filter(|i| p[*i] != 0).count();
        let pct = (100 * live as u64) / (sh.tokens * (f - d)) as u64;
        assert!(pct >= floor, "{what}: the {name} plane is nonzero at only {pct}% of the upper hidden half [{d}, {f})");
    }
    let o8 = &w.planes[ids.at(A_O8)];
    let live_slots = (0..sh.h_pad)
        .filter(|sl| sh.slot_is_true_head(*sl))
        .filter(|sl| (0..sh.tokens).flat_map(|t| (0..dh).map(move |c| t * dp + sl * dh + c)).any(|i| o8[i] != 0))
        .count();
    assert_eq!(live_slots, sh.q_heads, "{what}: only {live_slots} of the {} true head slots carry an attention output", sh.q_heads);
    for sl in (0..sh.h_pad).filter(|s| !sh.slot_is_true_head(*s)) {
        assert!(!(0..sh.tokens).flat_map(|t| (0..dh).map(move |c| t * dp + sl * dh + c)).any(|i| o8[i] != 0), "{what}: padded head slot {sl} carries an attention output");
    }
    let (kr, v8) = (&w.planes[ids.at(A_KR8)], &w.planes[ids.at(A_V8)]);
    let group_live = |p: &Vec<i64>, g: usize| (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| j * kvw + g * dh + c)).any(|i| p[i] != 0);
    let live_groups = (0..sh.kv_heads).filter(|g| group_live(kr, *g) && group_live(v8, *g)).count();
    assert_eq!(live_groups, 4, "{what}: only {live_groups} of the four key-value groups carry nonzero keys AND values");
    for a in 0..sh.kv_heads {
        for b in a + 1..sh.kv_heads {
            let differs = (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| (j, c))).any(|(j, c)| kr[j * kvw + a * dh + c] != kr[j * kvw + b * dh + c]);
            assert!(differs, "{what}: key-value groups {a} and {b} carry IDENTICAL rotated keys, so the two group bits are not exercised");
        }
    }
    // THE C-6 CENSUS: the top norm limb is live, in every one of the four
    // planes the correction is about
    let sup = witness::Geom::new(sh).support(Dom::D);
    for (name, p) in top_norm_limbs(sh, ids) {
        let live = sup.iter().filter(|i| w.planes[p][**i] != 0).count();
        let pct = (100 * live) / sup.len();
        assert!(pct >= 20, "{what}: {name} is nonzero at only {pct}% of the true Dom::D support, so C-6's range obligation would be about a dead limb");
        assert!(sup.iter().all(|i| (0..256).contains(&w.planes[p][*i])), "{what}: {name} is outside its byte range on the honest witness");
    }
    eprintln!("S31 CENSUS [{what}]: 12/12 head slots live, 4/4 key-value groups live and pairwise different, the upper hidden half live, all four TOP norm limbs live and in range");
}

/// **THE HONEST rung-C6 BLOCK PROVES AND VERIFIES FROM BYTES** on the FULLY
/// DENSE recipe with a GENERIC hidden input — every entry of all nine public
/// words nonzero, four genuinely different key-value groups, the upper
/// hidden half live, all four top norm limbs live — at the first
/// development shape whose norm window fills its top byte limb, so the four
/// `scaled` norm lookups are dropped. The frame is the COUNTED length and a
/// one-byte truncation is refused.
#[test]
fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_c6() {
    let sh = Shape::rung_c6();
    assert!(sh.norm_top_is_full_byte(), "this test is about the C-6 arm");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-C6 dense honest witness");
    let ids = Ids::new(&sh).expect("the rung-C6 plane map");
    assert!(super::pad::every_checkable_relation_holds(&sh, &ids, &w), "the honest rung-C6 witness is internally inconsistent");
    assert_non_trivial(&sh, &ids, &w, "one dense block");
    let blk = BlockPublic::new(public, ff);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_c6(&sh, &blk, w).expect("the rung-C6 dense prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), C6_FRAME_BYTES, "the rung-C6 frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the rung-C6 receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the rung-C6 receipt verifies from bytes");
    eprintln!("rung-C6 DENSE one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short rung-C6 frame was accepted");
}

/// **THE DEGENERATE CASE, NAMED AS ONE.** The all-zero hidden input on the
/// lane's synthetic tame fixture proves and verifies at rung-C6. It says
/// nothing about the group bits — every key-value group is identically zero
/// — and it exists because it is the fixed input the privacy case is stated
/// at and the witness the second capture bundle carries.
#[test]
fn the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_c6() {
    let sh = Shape::rung_c6();
    let (public, ff, _) = super::grow_tests::tame_case(&sh);
    let input = vec![0i16; sh.tokens * sh.width];
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-C6 all-zero witness");
    let blk = BlockPublic::new(public, ff);
    let (expected, receipt, bytes) = prove_c6(&sh, &blk, w).expect("the rung-C6 all-zero prover");
    assert_eq!(bytes.len(), C6_FRAME_BYTES, "a receipt's length is a function of the shape alone");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the all-zero receipt verifies in typed form");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the all-zero receipt verifies from bytes");
    eprintln!("rung-C6 ALL-ZERO (degenerate) one block: frame {} B, verified", bytes.len());
}

// ---------------------------------------------------------------- the negative controls

/// Re-decompose a norm remainder so that its VALUE is unchanged and its TOP
/// limb leaves the byte range: `top -= top + 1` (so the top limb is `-1`)
/// and the limb below absorbs `256 * (top + 1)`. Because
/// `argument::limbs` folds the limbs as `sum_k limb_k * 256^k`
/// (`argument.rs:825`), the recomposed `rho` (or `sigma`) the norm relation
/// reads is IDENTICAL, so every arithmetic clause of the block is still
/// exactly satisfied and the only thing wrong with the witness is that two
/// limbs are outside `[0, 256)`.
fn move_a_carry(w: &mut Witness, lo: usize, hi: usize, at: usize) -> (i64, i64) {
    let step = w.planes[hi][at] + 1;
    w.planes[hi][at] -= step;
    w.planes[lo][at] += 256 * step;
    (w.planes[hi][at], w.planes[lo][at])
}

/// the recomposed value of a norm remainder at one position, as
/// `argument::limbs` folds it
fn recomposed(w: &Witness, planes: &[usize], at: usize) -> i128 {
    planes.iter().enumerate().map(|(k, p)| i128::from(w.planes[*p][at]) * 256i128.pow(k as u32)).sum()
}

/// **THE SOUNDNESS TEST OF C-6: A NORM TOP LIMB OUTSIDE ITS BYTE RANGE IS
/// REJECTED, ALTHOUGH THE FOUR `scaled` LOOKUPS ARE GONE.**
///
/// This is the control the C-6 arm needs and no other shape in the filter
/// can give. For `norm_a`'s `rho` and for `norm_m`'s `rho` — the two
/// remainders whose top limb lost its `scaled` lookup — a carry is MOVED
/// between the top limb and the one below it, so that:
///
/// * the recomposed remainder is **bit for bit the value the honest witness
///   had** (asserted), and `argument::limbs` is the only way the limbs enter
///   any relation of `argument::define`, so every ARITHMETIC clause of the
///   block is still exactly satisfied;
/// * the top limb is `-1` and the limb below it is at least 256, so the only
///   thing wrong with this witness is the RANGE of two limbs.
///
/// Whatever rejects it is therefore the range obligation and nothing else.
/// The test asserts, in order: the honest control is accepted; the
/// tampered witness's norm arithmetic is untouched; the byte-range clause of
/// `pad::every_checkable_relation_holds` is the one that fails; and the
/// production VERIFIER rejects the proof (a refusal by the prover would not
/// be a soundness statement, and is asserted not to happen).
///
/// **WHICH RELATION CATCHES IT, MEASURED.** The rejection is
/// `"H: pcs zk: group {h_groups - 1}: <v, c> != combined claim"` — the LAST
/// opening group of the HELPER commitment, which is the one
/// `protocol::finish_claims` fills by pushing `protocol::logup_sum_claim`
/// after every slot's claims. That claim is the value-0 LogUp identity, and
/// its published value is the compile-time constant `Fp2::ZERO`. An
/// out-of-range lookup value cannot be in the table, the byte histogram
/// bins it into entry 0 (`protocol::byte_histogram_at`: "only the LogUp
/// identity can catch it"), and the identity therefore fails to close. **So
/// the relation that carries the top limb's range obligation after C-6 is
/// the `byte(top)` lookup inside the value-0 LogUp identity**, exactly as
/// [`the_lookup_c6_drops_is_a_duplicate_of_one_that_stays`] says by
/// inspection. The group index is asserted, not merely printed.
///
/// **FINDING S31-F1 (a message, not a hole).** That refusal names neither
/// the slot, nor the domain, nor the lookup: a reader sees an opening-group
/// mismatch on `H`. It is fail-closed and it arrives before the proof is
/// accepted, which is what matters for soundness, but it is weaker than the
/// sumcheck-level refusals, which name the slot and the relation. It is the
/// same family as stage 30's T30-F1 and it is left to the integrator as a
/// suggestion, not taken here: the LogUp group's refusal could say "the
/// value-0 LogUp identity" instead of a group number.
#[test]
fn a_norm_top_limb_outside_its_byte_range_is_rejected_at_the_rung_c6() {
    let sh = Shape::rung_c6();
    assert!(sh.norm_top_is_full_byte(), "this test is about the arm where the four scaled lookups are DROPPED");
    let ids = Ids::new(&sh).expect("plane map");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-C6 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    assert!(super::pad::every_checkable_relation_holds(&sh, &ids, &base), "the honest witness is inconsistent");
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest rung-C6 witness is not accepted");
    let ln = sh.limbs_norm();
    let at = witness::Geom::new(&sh).support(Dom::D)[0];
    let cases: [(&str, Vec<usize>); 4] = [
        ("norm_a rho (A_NR)", (0..ln).map(|k| ids.nr(k)).collect()),
        ("norm_a sigma (A_NS)", (0..ln).map(|k| ids.ns(k)).collect()),
        ("norm_m rho (A_MR)", (0..ln).map(|k| ids.mr(k)).collect()),
        ("norm_m sigma (A_MS)", (0..ln).map(|k| ids.ms(k)).collect()),
    ];
    let mut rejected = 0usize;
    for (what, planes) in cases {
        let mut w = clone_witness(&base);
        let before = recomposed(&w, &planes, at);
        let (top, below) = move_a_carry(&mut w, planes[ln - 2], planes[ln - 1], at);
        let unchanged = recomposed(&w, &planes, at) == before;
        assert!(unchanged, "{what}: the carry move changed the recomposed remainder, so this is not a RANGE-only tamper");
        assert!(top < 0, "{what}: the top limb is still inside its byte range");
        assert!(below >= 256, "{what}: the limb below is still inside its byte range");
        assert!(!super::pad::every_checkable_relation_holds(&sh, &ids, &w), "{what}: the witness-level byte-range clause does not see the out-of-range limb");
        let o = outcome(&sh, &blk, w);
        // THE CAPTURE RULE: the limbs and the remainder are values of the
        // fixture's hidden witness, so what is printed is the RANGE FACT and
        // never the value.
        eprintln!(
            "C6 NORM RANGE TAMPER {what}: top limb now negative {}, limb below now at or above 256 {}, recomposed remainder unchanged {} — {}",
            top < 0,
            below >= 256,
            unchanged,
            o.short()
        );
        match o {
            Outcome::Accepted => panic!("{what}: an out-of-range norm top limb was ACCEPTED at rung-C6, where C-6 drops the scaled lookup — THIS IS A SOUNDNESS FINDING"),
            Outcome::ProverRefused(e) => panic!("{what} was refused by the PROVER, which is not a soundness statement: {e}"),
            Outcome::VerifierRejected(e) => {
                // THE RELATION, NAMED: the LogUp sum claim's own opening
                // group, which is the last one of the helper commitment
                assert_eq!(e, format!("H: pcs zk: group {}: <v, c> != combined claim", sh.h_groups() - 1), "{what}: the rejection is not the value-0 LogUp identity's opening group: {e}");
                rejected += 1;
            }
        }
    }
    assert_eq!(rejected, 4, "not every norm remainder was exercised");
    assert_eq!(sh.h_groups() - 1, 8, "the LogUp sum claim's opening group moved");
    eprintln!(
        "C6 NORM RANGE SWEEP: 4 of 4 rejected by the VERIFIER at the H commitment's group {} — the value-0 LogUp identity `protocol::finish_claims` pushes last — with the block's ARITHMETIC exactly satisfied, so the `byte(top)` lookup C-6 keeps is what carries the range obligation (finding S31-F1: that refusal does not name the lookup)",
        sh.h_groups() - 1
    );
}

/// **THE SAME TAMPER AT rung-K4 REJECTS TOO**, which is what makes the test
/// above a statement about C-6 rather than about this shape: the obligation
/// is enforced identically on the arm that keeps the `scaled` lookup and on
/// the arm that drops it, and the rejecting slot is the same.
#[test]
fn the_norm_range_tamper_rejects_at_the_same_slot_on_both_arms() {
    let mut seen: Vec<(String, String)> = Vec::new();
    for sh in [Shape::rung_c6(), Shape::rung_k4()] {
        let ids = Ids::new(&sh).expect("plane map");
        let (public, ff, input) = super::dense_tests::dense_case(&sh);
        let base = witness::build_shaped(&sh, &public, &ff, &input).expect("an honest dense witness");
        let blk = BlockPublic::new(public, ff);
        let ln = sh.limbs_norm();
        let at = witness::Geom::new(&sh).support(Dom::D)[0];
        let planes: Vec<usize> = (0..ln).map(|k| ids.nr(k)).collect();
        let mut w = clone_witness(&base);
        let before = recomposed(&w, &planes, at);
        move_a_carry(&mut w, planes[ln - 2], planes[ln - 1], at);
        assert_eq!(recomposed(&w, &planes, at), before, "{}: the carry move changed the remainder", sh.name);
        match outcome(&sh, &blk, w) {
            Outcome::VerifierRejected(e) => {
                eprintln!("C6 BOTH ARMS {} (full_byte {}): {e}", sh.name, sh.norm_top_is_full_byte());
                seen.push((sh.name.to_string(), e));
            }
            o => panic!("{}: the norm range tamper was not rejected by the verifier: {}", sh.name, o.short()),
        }
    }
    assert_eq!(seen[0].1, seen[1].1, "the two arms reject the same tamper with different messages: {seen:?}");
    eprintln!("C6 BOTH ARMS: the arm that DROPS the scaled lookup and the arm that keeps it reject the identical out-of-range top limb with the identical message");
}

/// **THE ORDINARY NEGATIVE CONTROLS AT THIS SHAPE**: a wrong norm square, a
/// wrong residual 2, and a tamper inside each of the three unpadded
/// domains, each rejected by the VERIFIER at the slot whose relation it
/// breaks first. The message is asserted to name that slot, so a rejection
/// by an earlier check cannot pass for one.
#[test]
fn the_named_tampers_are_rejected_at_their_own_slots_at_the_rung_c6() {
    let sh = Shape::rung_c6();
    let ids = Ids::new(&sh).expect("plane map");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-C6 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest rung-C6 witness is not accepted");
    let sup_d = witness::Geom::new(&sh).support(Dom::D);
    let cases: [(&str, usize, usize, usize); 6] = [
        ("the norm square A_DSQ of norm_a (slot 02's own relation)", ids.at(A_DSQ), sh.size(Dom::T) - 1, SC_TZC),
        ("the norm square A_DSQM of norm_m", ids.at(A_DSQM), 0, SC_TZC),
        ("residual 2, A_X2 (slot 14 hosts it)", ids.at(A_X2), sup_d[0], SC_DZC),
        ("the key A_K8, the LAST index of the unpadded Dom::Kv", ids.at(A_K8), sh.size(Dom::Kv) - 1, SC_KVZC),
        ("the gate A_G8, the LAST index of the unpadded Dom::F", ids.at(A_G8), sh.size(Dom::F) - 1, SC_FZC),
        ("the norm square A_DSQ at index 0 of the unpadded Dom::T", ids.at(A_DSQ), 0, SC_TZC),
    ];
    let mut n = 0usize;
    for (what, plane, at, slot) in cases {
        let mut w = clone_witness(&base);
        w.planes[plane][at] += 1;
        let o = outcome(&sh, &blk, w);
        eprintln!("C6 TAMPER {what} at index {at}: {}", o.short());
        match o {
            Outcome::Accepted => panic!("{what} was ACCEPTED at rung-C6"),
            Outcome::ProverRefused(e) => panic!("{what} was refused by the PROVER, which is not a soundness statement: {e}"),
            Outcome::VerifierRejected(e) => {
                assert!(e.contains(&format!("slot {slot} [{}]", SLOT_NAMES[slot])), "{what} was rejected, but not by slot {slot} [{}]: {e}", SLOT_NAMES[slot]);
                n += 1;
            }
        }
    }
    assert_eq!(n, 6, "not every tamper was exercised");
    eprintln!("C6 TAMPER SWEEP: 6 of 6 rejected by the VERIFIER at the slot under test, 0 by the prover, 0 accepted");
}

/// **A TAMPERED ROUND MESSAGE OF SLOT 14 CANNOT BE FORGED.** Slot 14
/// (`03 D zero-check`) is the slot C-6 moves — it is the `Dom::D` LogUp
/// host, so it loses two helper claims and its term list shortens — so it
/// is the slot whose round messages this stage has to control.
#[test]
fn a_tampered_round_message_of_slot_14_is_rejected_at_the_rung_c6() {
    let sh = Shape::rung_c6();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-C6 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let (expected, _receipt, bytes) = prove_c6(&sh, &blk, w).expect("the rung-C6 dense prover");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest control verifies");
    for slot in [SC_DZC, SC_KVZC, SC_FZC] {
        let mut r = Receipt::from_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest frame parses");
        r.slots[slot].sc.rounds[0][1] = r.slots[slot].sc.rounds[0][1].add(Fp2::ONE);
        let e = verify_inner_at(&sh, &blk, &expected, &r).expect_err("a tampered round message was accepted");
        eprintln!("C6 ROUND-MESSAGE TAMPER slot {slot} [{}]: {e}", SLOT_NAMES[slot]);
        assert!(e.contains(&format!("slot {slot} [{}]", SLOT_NAMES[slot])), "the rejection does not name slot {slot}: {e}");
    }
}

/// **A PROOF SHAPED AS IF C-6 DID NOT APPLY IS REFUSED BY THE FRAME CHECK.**
/// A prover that had not applied C-6 would carry two more `Dom::D` helper
/// claims, so slot 14's term list would be two longer and its round
/// messages unchanged in degree but its TERMINAL list longer. The
/// production prover derives all of it from the shape, so the statement is
/// made on the FRAME, exactly as stage 30's finding T30-F1 makes it: the
/// per-slot schedule check `wire::validate` runs before the verifier
/// absorbs or draws anything, and it refuses an over-long term list with
/// `"private block wire: argument shape"`.
#[test]
fn a_frame_with_the_dropped_helper_claims_is_refused_before_any_draw_at_the_rung_c6() {
    let sh = Shape::rung_c6();
    let k4 = Shape::rung_k4();
    let lay = Layout::for_shape(&sh).expect("the rung-C6 layout");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-C6 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let (expected, _receipt, bytes) = prove_c6(&sh, &blk, w).expect("the rung-C6 dense prover");
    let honest = Receipt::from_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest frame parses");
    super::wire::validate(&honest, &lay).expect("the honest frame passes the schedule check");
    // slot 14's term list is two shorter than the un-corrected one would be
    let terms = lay.slot_terms(SC_DZC);
    let k4_terms = Layout::for_shape(&k4).expect("layout").slot_terms(SC_DZC);
    assert_eq!(k4_terms - terms, 2, "slot 14's term list does not differ from the all-lookup arm's by the two dropped helper claims");
    let mut r = Receipt::from_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest frame parses");
    assert_eq!(r.slots[SC_DZC].terms.len(), terms, "slot 14's honest term list is not the schedule's");
    r.slots[SC_DZC].terms.push(Fp2::ZERO);
    r.slots[SC_DZC].terms.push(Fp2::ZERO);
    let ev = super::wire::validate(&r, &lay).expect_err("an un-corrected frame passed the schedule check");
    assert_eq!(ev, "private block wire: argument shape", "the frame check refused for another reason: {ev}");
    let e = verify_inner_at(&sh, &blk, &expected, &r).expect_err("an un-corrected proof was accepted");
    assert_eq!(e, ev, "the verifier's refusal is not the frame check's");
    eprintln!("C6 UN-CORRECTED FRAME: slot 14 carries {terms} terminals here against {k4_terms} on the arm that keeps the four lookups; a frame with the two extra helper claims is refused by the frame check before any draw — {e}");
}

// ---------------------------------------------------------------- a three-block run

/// The honest chain of `l` rung-C6 blocks: each block's hidden output is the
/// next one's hidden input, and none of it is published.
pub(super) struct C6Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl C6Chain {
    pub(super) fn build(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> C6Chain {
        let ids = Ids::new(sh).expect("the rung-C6 plane map");
        let (mut inputs, mut planes) = (Vec::with_capacity(l), Vec::with_capacity(l + 1));
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness of the rung-C6 chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().expect("the block's hidden output"));
        }
        C6Chain { sh: sh.clone(), public, ff, inputs, planes }
    }
}

impl RunWitnessSource for C6Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

/// the run statement and the two EXTERNAL endpoint owners of a rung-C6 chain
pub(super) fn c6_statement_of(c: &C6Chain, l: usize, blocks: &[BlockPublic]) -> (RunStatement, Endpoints) {
    let rs = RunShape::rung_c6(l).expect("the rung-C6 run shape");
    let spec = IoSpec::new_shaped(&c.sh, c6_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &c.planes[0], &c.planes[l]).expect("the run's external endpoint owners");
    let st = RunStatement::new(rs, c6_context(), expected, blocks, &vec![(0, 0); l]).expect("the rung-C6 run statement");
    (st, owners)
}

/// the fully dense rung-C6 chain of `l` blocks and its `l` public statements
pub(super) fn c6_dense_chain(l: usize) -> (C6Chain, Vec<BlockPublic>) {
    let sh = Shape::rung_c6();
    let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
    let blocks = (0..l).map(|_| BlockPublic::new(public.clone(), ff.clone())).collect();
    (C6Chain::build(&sh, l, public, ff, x0), blocks)
}

/// **AN HONEST THREE-BLOCK FULLY DENSE rung-C6 RUN VERIFIES FROM ITS
/// SEGMENTS.** Three blocks under one transcript, each block's hidden output
/// the next one's hidden input and neither published, at the shape where
/// C-6 applies — so the run layer's boundary rows and the dropped norm
/// lookups are exercised together, which is the combination only an
/// `#[ignore]`d 125M run reached before. The segment lengths are the counted
/// ones, byte for byte, and every block's census is asserted.
#[test]
fn an_honest_three_block_fully_dense_run_verifies_from_its_segments_at_the_rung_c6() {
    let sh = Shape::rung_c6();
    let ids = Ids::new(&sh).expect("plane map");
    let (mut c, blocks) = c6_dense_chain(3);
    for k in 0..3 {
        let w = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[k]).expect("a fully dense witness of the chain");
        assert_non_trivial(&sh, &ids, &w, &format!("run block {k}"));
    }
    let (st, owners) = c6_statement_of(&c, 3, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let t0 = std::time::Instant::now();
    let stats = run::prove_run(&st, &blocks, &mut c, owners, &mut |k, b| {
        assert_eq!(k, segs.len(), "the sink was handed the segments out of order");
        segs.push(b);
        Ok(())
    })
    .expect("the honest three-block fully dense rung-C6 run proves");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(stats.segment_bytes, super::run_tests::counted_segment_bytes(&sh, 3, rows), "a rung-C6 segment is not the counted length");
    let t1 = std::time::Instant::now();
    run::verify_run(&st, &blocks, &segs).expect("the honest three-block fully dense rung-C6 run verifies from its segments");
    eprintln!(
        "C6 FULLY DENSE RUN L=3 (down band {}): prove {prove_s:.2} s, verify from segments {:.2} s, segments {:?} B (total {} B), boundary {rows} rows",
        super::dense_tests::band_down_run(&sh),
        t1.elapsed().as_secs_f64(),
        stats.segment_bytes,
        stats.segment_bytes.iter().sum::<usize>()
    );
}

//! **INDEPENDENT ADVERSARIAL CODE REVIEW of the lane's shaped private block
//! at the development rung (2026-09-20).**
//!
//! Written by a delegated reviewer who assumed the lane's change was wrong
//! until shown otherwise. Nothing here fixes anything: every test either
//! demonstrates that an attack is correctly refused (and then it passes and
//! the lane keeps it) or demonstrates a hole (and then it is `#[ignore]`d,
//! fails, and is named in
//! `docs/zkmatrix-poc/ZK60_BLOCK125M_RUNG_CODE_REVIEW.md`).
//!
//! Nothing here establishes a privacy property and nothing here is an
//! acceptance. No witness value, salt or private plane is printed beyond the
//! plane INDEX a case perturbs.

use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;

// --------------------------------------------------------------- rung harness
//
// Duplicated from `rung_tests.rs` on purpose: this reviewer may not edit the
// lane's files, and a harness of its own is in any case the right thing for an
// independent check.

fn review_context() -> Digest {
    // the SAME context the lane's rung tests use, so that a receipt produced
    // here is the receipt the lane's own tests produce
    *blake3::hash(b"private block: the development rung, end to end (S12a)").as_bytes()
}

fn honest_rung() -> (Shape, BlockPublic, Witness) {
    let sh = Shape::rung();
    let (public, ff, input) = super::grow_tests::tame_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung's honest witness");
    (sh, BlockPublic::new(public, ff), w)
}

pub(super) fn clone_witness(w: &Witness) -> Witness {
    Witness { planes: w.planes.clone() }
}

/// prove at the rung, with the two endpoints taken from THIS witness (so a
/// tamper of `x_in` or `xres2` is never caught merely by the endpoint policy)
fn prove_rung(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Vec<u8>), String> {
    let ids = Ids::new(sh).expect("the rung has a plane map");
    let plane = |p: usize| -> Result<Vec<i16>, String> {
        w.planes[p].iter().map(|v| i16::try_from(*v).map_err(|_| "an endpoint word outside int16".to_string())).collect()
    };
    let (pin, pout) = (plane(ids.at(A_X))?, plane(ids.at(A_X2))?);
    let spec = IoSpec::new_shaped(sh, review_context(), 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &pin, &pout)?;
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, bytes))
}

/// What happened to a tampered witness. `Accepted` is the only bad answer, and
/// `ProverRefused` is recorded separately because a refusal by the PROVER's own
/// consistency checks is not a soundness statement: a cheating prover simply
/// does not run them.
#[derive(Debug, PartialEq, Eq)]
pub(super) enum Outcome {
    Accepted,
    ProverRefused(String),
    VerifierRejected(String),
}

impl Outcome {
    pub(super) fn is_accepted(&self) -> bool {
        *self == Outcome::Accepted
    }
    pub(super) fn short(&self) -> String {
        match self {
            Outcome::Accepted => "ACCEPTED".into(),
            Outcome::ProverRefused(e) => format!("prover refused: {e}"),
            Outcome::VerifierRejected(e) => format!("verifier rejected: {e}"),
        }
    }
}

pub(super) fn outcome(sh: &Shape, blk: &BlockPublic, w: Witness) -> Outcome {
    match prove_rung(sh, blk, w) {
        Err(e) => Outcome::ProverRefused(e),
        Ok((expected, bytes)) => match verify_bytes_at(sh, blk, &expected, &bytes) {
            Err(e) => Outcome::VerifierRejected(e),
            Ok(()) => Outcome::Accepted,
        },
    }
}

/// shaped plane id -> the toy's name for it, where the toy has one
fn toy_id_of(ids: &Ids) -> Vec<Option<usize>> {
    let mut out = vec![None; ids.n_a()];
    for toy in 0..N_A {
        let p = ids.at(toy);
        if p < out.len() {
            out[p] = Some(toy);
        }
    }
    out
}

// ------------------------------------------------------------------ attack 1
//
// THE PAD-ZERO TERM: is every ZERO-rule plane of every padded domain really in
// some slot's batched term? The memo's table and `pad.rs` say which planes are
// covered; only the VERIFIER can say whether they are. This is the exhaustive
// form of PZ-1: one nonzero value in the pad of EVERY ZERO-rule plane of EVERY
// padded domain, one case each, all nine domains.

/// A pad position of `dom` that is adversarially chosen: for the three
/// head-indexed domains a PADDED HEAD SLOT at a TRUE token (the case a prefix
/// mask would call supported, correction C-1), otherwise the first padded
/// position of the domain's own axis.
fn pad_positions(sh: &Shape, dom: Dom) -> Vec<(usize, &'static str)> {
    let supp = super::pad::indicator_table(sh, dom);
    let first = |from: usize| (from..sh.size(dom)).find(|i| supp[*i] == 0);
    let (tp, dp, dh) = (sh.t_pad, sh.d_pad, sh.head_dim);
    let padded_slot = (0..sh.h_pad).find(|sl| !sh.slot_is_true_head(*sl)).expect("the rung's head axis pads");
    let mut out: Vec<(usize, &'static str)> = Vec::new();
    match dom {
        // (t 0, head slot 3, i' 0) — a padded head slot inside a TRUE token row
        Dom::Q => out.push((padded_slot * dh, "a padded head slot at a true token")),
        // (head slot 3, t 0) and (head slot 0, t 24): both kinds
        Dom::Ht => {
            out.push((padded_slot * tp, "a padded head slot at a true token"));
            out.push((tp - 1, "a padded token of a true head slot"));
        }
        // (head slot 3, t 0, j 0) and (head slot 0, t 0, j 24)
        Dom::S => {
            out.push((padded_slot * tp * tp, "a padded head slot at true (t, j)"));
            out.push((sh.tokens, "a padded key index j of a true row"));
        }
        // (t 0, i 96) — a padded width column of a true token row
        Dom::D => {
            out.push((sh.width, "a padded width column of a true token row"));
            out.push((sh.tokens * dp, "a padded token row"));
        }
        // an UNUSED limb sub-plane (`k >= 3 * LIMBS_ISQRT`), which NO relation
        // reads — the memo's own third PZ-1 case, and the only position at
        // which `Dom::L`'s own pad-zero term in `SC_LZC` can be what catches
        // the tamper. Inside a USED sub-slice, `SC_TZC`'s ungated limb
        // reconstruction gets there first.
        Dom::L => {
            out.push((9 * tp, "an unused limb sub-plane, which no relation reads"));
            out.push((sh.size(Dom::L) - 1, "the last position of the lifted domain"));
        }
        // a padded token row as well as a padded hidden column
        Dom::F => out.push((sh.tokens * sh.f_pad, "a padded token row")),
        Dom::Kv => out.push((sh.size(Dom::Kv) - 1, "the last position of the domain")),
        _ => {}
    }
    if let Some(i) = first(0) {
        out.push((i, "the first padded position of the domain"));
    }
    let mut seen: Vec<usize> = Vec::new();
    out.retain(|(i, _)| {
        let fresh = !seen.contains(i);
        seen.push(*i);
        fresh
    });
    for (i, _) in &out {
        assert_eq!(supp[*i], 0, "{dom:?}: position {i} is not a padded position");
    }
    out
}

/// **ATTACK 1(a) AND 1(e), EXHAUSTIVE.** Every ZERO-rule `A` plane of every
/// padded domain, one nonzero value written into a padded position, must be
/// REJECTED BY THE VERIFIER. A plane the batched term forgot is a free pad: the
/// prover may put anything there, and (blocking item B-1) on `Dom::D` that buys
/// it the norm's divisor.
///
/// The three lookup histograms are excluded and named: the prover DERIVES them
/// from the witness, so a witness edit cannot express that attack at all (it is
/// `tamper::a_moved_activation_multiplicity_is_rejected_by_the_logup_sum_claim`
/// at the toy, and it is still owed at the rung).
#[test]
fn every_zero_rule_plane_has_its_pad_proved_zero_at_the_rung() {
    let (sh, blk, base) = honest_rung();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let names = toy_id_of(&ids);
    let mut accepted: Vec<String> = Vec::new();
    let mut prover_only: Vec<String> = Vec::new();
    let (mut cases, mut planes_covered) = (0usize, 0usize);
    let mut derived: Vec<usize> = Vec::new();
    for dom in ALL_DOMS {
        let zero_rule = super::pad::zero_rule_a_planes(&sh, &ids, dom);
        if zero_rule.is_empty() {
            continue;
        }
        let positions = pad_positions(&sh, dom);
        assert!(!positions.is_empty(), "{dom:?} pads but no padded position was found");
        for p in zero_rule {
            if ids.is_multiplicity(p) {
                derived.push(p);
                continue;
            }
            planes_covered += 1;
            for (at, what) in &positions {
                let mut w = clone_witness(&base);
                assert_eq!(w.planes[p][*at], 0, "{dom:?} plane {p}: the honest pad at {at} is not zero");
                w.planes[p][*at] = 1;
                let o = outcome(&sh, &blk, w);
                cases += 1;
                let label = format!("{dom:?} plane {p} (toy id {:?}) at {at} — {what}", names[p]);
                eprintln!("PAD {label}: {}", o.short());
                match o {
                    Outcome::Accepted => accepted.push(label),
                    Outcome::ProverRefused(_) => prover_only.push(label),
                    Outcome::VerifierRejected(_) => {}
                }
            }
        }
    }
    eprintln!("PAD SWEEP: {cases} cases over {planes_covered} ZERO-rule A planes; {} derived histograms skipped; {} accepted; {} caught by the prover only", derived.len(), accepted.len(), prover_only.len());
    assert!(accepted.is_empty(), "a nonzero pad value was ACCEPTED on: {accepted:#?}");
    assert!(prover_only.is_empty(), "a nonzero pad value was caught only by the PROVER's own checks, which a cheating prover would not run: {prover_only:#?}");
}

/// **ATTACK 1(a), the static half.** Two invariants `argument::define` relies
/// on without stating them:
///
/// 1. `SC_TAB` batches the three `Dom::Tab` `A` planes by the HARD-CODED table
///    indices `[1, 4, 7]`, and — unlike `SC_TZC` and `SC_SZC`, which refuse by
///    name if their domain's declared plane list is not the one they push —
///    it never checks that list. A fourth `Dom::Tab` `A` plane would be
///    silently left out of the term. It holds today; this is the assertion
///    that would catch the day it stops holding.
/// 2. Every slot that carries an indicator must have a cube the indicator
///    TILES. `argument.rs:533` says so in a `debug_assert_eq!`, which the
///    release profile (`hashline/Cargo.toml`, no `debug-assertions`) compiles
///    out — and release is the only profile the rung and the 125M shape are
///    ever built in. Checked here for real, at all three shapes.
#[test]
fn the_pad_terms_unstated_invariants_hold_at_every_shape() {
    for sh in [Shape::toy(), Shape::rung(), Shape::m125()] {
        let ids = Ids::new(&sh).expect("a plane map");
        // (1) the `Dom::Tab` group is exactly the three derived histograms
        let tab = super::pad::zero_rule_a_planes(&sh, &ids, Dom::Tab);
        assert!(tab.iter().all(|p| ids.is_multiplicity(*p)), "{}: a non-histogram A plane sits on Dom::Tab and SC_TAB's hard-coded [1, 4, 7] would miss it", sh.name);
        assert!(tab.len() <= 3, "{}: Dom::Tab has {} ZERO-rule A planes; SC_TAB batches exactly three", sh.name, tab.len());
        // every ZERO-rule plane really is on the domain it is claimed for, and
        // every padded domain has a host slot
        for dom in ALL_DOMS {
            for p in super::pad::zero_rule_a_planes(&sh, &ids, dom) {
                assert_eq!(ids.dom(p), dom, "{}: plane {p} is batched under {dom:?} but lives elsewhere", sh.name);
            }
            assert!(super::pad::pad_zero_host(dom) < N_SLOTS, "{}: {dom:?} has no host slot", sh.name);
        }
        // (2) the indicator tiles its host slot's cube, exactly
        if !sh.carries_pad_rule() {
            continue;
        }
        for dom in ALL_DOMS.into_iter().filter(|d| sh.pads(*d)) {
            for slot in super::pad::indicator_slots(dom) {
                let cube = 1usize << sh.slots()[*slot].0;
                assert!(cube >= sh.size(dom) && cube % sh.size(dom) == 0, "{}: {dom:?}'s indicator ({} entries) does not tile slot {slot}'s cube ({cube})", sh.name, sh.size(dom));
            }
        }
    }
    eprintln!("PAD STATIC: the Dom::Tab group is the three histograms, every ZERO-rule plane is on its own domain, and every indicator tiles its slot's cube at all three shapes");
}

/// **PZ-2, THE TWO VARIANTS THE LANE DOES NOT RUN.** Memo §3.7a asks for
/// PZ-2 "in both the int16-fill and the free-field-element variants", and
/// names `A_X1` as the SECOND B-1 hole (`SC_SSM`'s claimed sum reads the
/// padded cube exactly as `SC_SS`'s does). `rung_tests::pz2_end_to_end_...`
/// runs one variant on one of the two norms. Here are the other three cases.
#[test]
fn pz2_at_the_second_norm_and_as_a_free_field_element_is_rejected_at_the_rung() {
    let (sh, blk, base) = honest_rung();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let t = 0usize;
    // (i) the SECOND norm, int16-fill: `A_X1`'s padded columns of one token
    // row, with that row's whole `norm_m` isqrt witness recomputed from the
    // enlarged sum of squares, so every relation but the pad rule holds under
    // a divisor the prover chose
    let mut w = clone_witness(&base);
    for i in sh.width..sh.d_pad {
        w.planes[ids.at(A_X1)][t * sh.d_pad + i] = 32_767;
        let v = 32_767 + 32_768;
        w.planes[ids.at(A_X1L0)][t * sh.d_pad + i] = v & 255;
        w.planes[ids.at(A_X1L1)][t * sh.d_pad + i] = v >> 8;
    }
    let ss: i64 = 1 + (0..sh.d_pad).map(|i| w.planes[ids.at(A_X1)][t * sh.d_pad + i].pow(2)).sum::<i64>();
    let d = witness::isqrt(ss as u64) as i64;
    let (a1, a2) = (ss - d * d, 2 * d - (ss - d * d));
    w.planes[ids.at(A_DM)][t] = d;
    w.planes[ids.at(A_DSQM)][t] = d * d;
    for (base_k, v) in [(0usize, d), (3, a1), (6, a2)] {
        for kk in 0..3 {
            w.planes[ids.at(A_LIMBM)][(base_k + kk) * sh.t_pad + t] = (v >> (8 * kk)) & 255;
        }
    }
    let o = outcome(&sh, &blk, w);
    eprintln!("PZ-2 norm_m, int16 fill: {}", o.short());
    assert!(!o.is_accepted(), "a consistently adjusted norm_m pad was ACCEPTED");
    // (ii) the FREE FIELD ELEMENT variant, on a plane that is not an endpoint
    // (an endpoint word outside int16 is refused by `prepare_endpoints`, which
    // would pass for the wrong reason)
    for (name, plane) in [("A_X1", ids.at(A_X1)), ("A_AO", ids.at(A_AO))] {
        let mut w = clone_witness(&base);
        w.planes[plane][t * sh.d_pad + sh.width] = 1_000_000_007;
        let o = outcome(&sh, &blk, w);
        eprintln!("PZ-2 free field element in {name}'s pad: {}", o.short());
        assert!(!o.is_accepted(), "{name}: a free field element in a pad was ACCEPTED");
    }
}

/// **ATTACK 1(e), the EXEMPT plane.** `A_E` is the one `A` plane the memo
/// exempts, because `exp[0] != 0` and a zero there is not a table row. The
/// exemption must buy a cheating prover NOTHING: whatever it writes into
/// `A_E`'s pad must still be the genuine `exp` row of the `delta` at that
/// position, and `delta` is pinned by `A_MX` and `A_S8`, both ZERO-rule.
#[test]
fn the_exempt_planes_pad_is_still_pinned_to_its_table_row_at_the_rung() {
    let (sh, blk, base) = honest_rung();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let (public, _, _) = super::grow_tests::tame_case(&sh);
    let supp = super::pad::indicator_table(&sh, Dom::S);
    let e = ids.at(A_E);
    // a padded position whose honest exp value is NOT zero — the case the
    // exemption exists for (`exp[0] = 2^F_E`). It is a PADDED HEAD SLOT at a
    // causally unmasked `(t, j)`; at a true row every padded `j` is above `t`,
    // where this rung's exp table has decayed to zero, so a zero there is a
    // genuine table row and says nothing.
    let at = (0..sh.size(Dom::S)).find(|i| supp[*i] == 0 && base.planes[e][*i] != 0).expect("a padded position with a nonzero exp row");
    let honest = base.planes[e][at];
    assert_ne!(honest, 0, "the exempt pad is zero: then it is not a table row and the lookup would refuse");
    eprintln!("EXEMPT pad at {at} (head slot {}, t {}, j {}) carries a nonzero exp row", at / (sh.t_pad * sh.t_pad), (at / sh.t_pad) % sh.t_pad, at % sh.t_pad);
    // (i) junk that is NOT a table row at all
    let mut w = clone_witness(&base);
    w.planes[e][at] = honest + 1;
    let o = outcome(&sh, &blk, w);
    eprintln!("EXEMPT pad, not a table row: {}", o.short());
    assert!(!o.is_accepted(), "a non-table value in the exempt pad was ACCEPTED");
    // (ii) junk that IS a genuine table row, but the wrong one for this delta
    let other = (0..256).map(|d| i64::from(public.exp[d])).find(|v| *v != honest).expect("the exp table has two distinct rows");
    let mut w = clone_witness(&base);
    w.planes[e][at] = other;
    let o = outcome(&sh, &blk, w);
    eprintln!("EXEMPT pad, a genuine table row of another delta: {}", o.short());
    assert!(!o.is_accepted(), "a wrong-row table value in the exempt pad was ACCEPTED");
}

/// **ATTACK 1(e), the exclusion the exemption needs (correction M-3).** Where
/// the exempt plane's pad really has to be excluded is a PADDED HEAD SLOT: the
/// causal mask keys on `(t, j)` only and is 1 there, and the honest `A_E`
/// carries `exp[0] != 0` on the whole causal triangle of that row, so an
/// ungated `SC_RS` would claim a row sum of several `exp[0]` against an
/// `A_SUM` that the `Dom::Ht` pad-zero term forces to zero. The honest proof
/// could not exist. On a TRUE row, by contrast, every padded `j` is above `t`,
/// where this rung's exp table has already decayed to zero — so on the `j`
/// axis the causal mask, not `supp_S`, is what excludes the pad.
#[test]
fn the_exempt_pads_entries_are_outside_the_softmax_row_sum_at_the_rung() {
    let (sh, _, w) = honest_rung();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let (tp, e, sum) = (sh.t_pad, ids.at(A_E), ids.at(A_SUM));
    let h = (0..sh.h_pad).find(|sl| !sh.slot_is_true_head(*sl)).expect("the head axis pads");
    let t = 3usize; // a true token index of a PADDED head slot
    let row = (h * tp + t) * tp;
    let masked: i64 = (0..=t).map(|j| w.planes[e][row + j]).sum();
    assert!(masked > 0, "the padded head slot's causal triangle carries no exp value: this test says nothing");
    assert_eq!(w.planes[sum][h * tp + t], 0, "the padded head slot's A_SUM is not zero");
    // and on a TRUE row the padded `j` entries are zero anyway: it is the
    // causal mask that kills them, not the support indicator
    let true_row = (0usize * tp + t) * tp;
    assert!(sh.slot_is_true_head(0));
    let padded_j: i64 = (sh.tokens..tp).map(|j| w.planes[e][true_row + j]).sum();
    eprintln!("EXEMPT exclusion: a padded head slot's causal triangle sums to {masked} while its A_SUM is 0 — so SC_RS's summand must carry supp_S (M-3); on a true row the padded j entries sum to {padded_j}, killed by the causal mask alone");
}

// ------------------------------------------------------------------ attack 9
//
// THE CLASS OF BUG AN HONEST PROOF WOULD NOT HAVE CAUGHT: an unconstrained
// plane, or a relation evaluated on a plane id that happens to be right for
// honest data. All three of the lane's end-of-stage bugs were found by a
// FAILING honest proof; this class is invisible to one. The sweep below
// perturbs every committed plane ON ITS TRUE SUPPORT and requires the verifier
// to reject: a plane whose perturbation is accepted is unconstrained.

/// **ATTACK 9, EXHAUSTIVE.** Every committed `A` plane, perturbed by one at a
/// TRUE-support position, must be rejected. The lane's own battery does 27
/// named planes; this does all of them, so a plane that no relation reads
/// cannot hide behind a family that has a representative.
#[test]
fn every_committed_plane_is_constrained_on_its_true_support_at_the_rung() {
    let (sh, blk, base) = honest_rung();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let names = toy_id_of(&ids);
    let mut accepted: Vec<String> = Vec::new();
    let mut prover_only: Vec<String> = Vec::new();
    let mut cases = 0usize;
    for p in 0..ids.n_a() {
        if ids.is_multiplicity(p) {
            continue;
        }
        let dom = ids.dom(p);
        let supp = super::pad::support_indicator(&sh, dom);
        let at = (0..sh.size(dom)).find(|i| supp[*i] == 1).expect("every domain has a true position");
        let mut w = clone_witness(&base);
        w.planes[p][at] += 1;
        let o = outcome(&sh, &blk, w);
        cases += 1;
        let label = format!("{dom:?} plane {p} (toy id {:?}) at true position {at}", names[p]);
        eprintln!("SUPPORT {label}: {}", o.short());
        match o {
            Outcome::Accepted => accepted.push(label),
            Outcome::ProverRefused(_) => prover_only.push(label),
            Outcome::VerifierRejected(_) => {}
        }
    }
    eprintln!("SUPPORT SWEEP: {cases} planes; {} accepted; {} caught by the prover only", accepted.len(), prover_only.len());
    assert!(accepted.is_empty(), "a true-support perturbation was ACCEPTED on: {accepted:#?}");
}

// ------------------------------------------------------------------ attack 3
//
// GROUPED-QUERY ATTENTION. Query head `h` must read key-value head
// `slot >> log(slots per group)`. The claim points take the key-value
// coordinates from the QUERY head's challenge (trap T-3), so a prover cannot
// choose them; what it CAN try is to move the key-value data.

/// **ATTACK 3, the structural half.** The key-value coordinate of the score and
/// value claim points is the TOP `log2(kv_heads)` entries of the head
/// challenge, and the head permutation really does put the group in the high
/// bits at every shape. If the group were the LOW bits, or the claim took its
/// own free coordinate, the two facts below would disagree.
#[test]
fn the_key_value_group_is_the_high_bits_of_the_head_slot_at_every_shape() {
    for sh in [Shape::toy(), Shape::rung(), Shape::m125()] {
        let lkv = sh.kv_heads.trailing_zeros() as usize;
        let lh = sh.h_pad.trailing_zeros() as usize;
        assert_eq!(1usize << lkv, sh.kv_heads, "{}: kv_heads is not a power of two", sh.name);
        for h in 0..sh.q_heads {
            let sl = sh.head_slot(h);
            // what `argument.rs`'s `r_h[..lkv]` selects: the top `lkv` bits of
            // the `lh`-bit slot index, most significant first
            let top_bits = sl >> (lh - lkv);
            assert_eq!(top_bits, sh.kv_of_slot(sl), "{}: head {h} slot {sl} — the top bits are not the key-value head", sh.name);
            assert_eq!(top_bits, h / (sh.q_heads / sh.kv_heads), "{}: head {h} reads the wrong key-value group", sh.name);
        }
        // and every padded slot belongs to a group too, so no group's padding
        // is a different group's data
        for sl in 0..sh.h_pad {
            assert!(sh.kv_of_slot(sl) < sh.kv_heads, "{}: slot {sl} has no key-value group", sh.name);
        }
    }
}

/// **FINDING (coverage).** `grow_tests::tame_case`, the ONLY fixture the rung
/// is ever proved at, gives every head — query and key-value — the same data:
/// its input alternates with period two in the width index and `head_dim` is
/// even, and its `Wk` / `Wv` are the same diagonal for both key-value heads. So
/// at the rung every head-permuting tamper is a NO-OP on the witness, and no
/// test written against this fixture can show that a query head reads the right
/// key-value group. Step S7's two acceptance tamper tests (memo §9a) are absent
/// from the lane, and on this fixture they could not have been written.
///
/// This test pins the limitation so it cannot be forgotten; the real attack is
/// in the test below, which builds a fixture that CAN tell the groups apart.
#[test]
fn the_tame_rung_fixture_cannot_tell_the_two_key_value_heads_apart() {
    let (sh, _, w) = honest_rung();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let (dh, kvw) = (sh.head_dim, sh.kv_heads * sh.head_dim);
    let mut same = true;
    for p in (0..ids.n_a()).filter(|p| ids.dom(*p) == Dom::Kv) {
        for t in 0..sh.tokens {
            for i in 0..dh {
                if w.planes[p][t * kvw + i] != w.planes[p][t * kvw + dh + i] {
                    same = false;
                }
            }
        }
    }
    assert!(same, "the tame fixture now DOES distinguish the two key-value heads — good news, and this test should be replaced by a direct swap tamper on it");
    eprintln!("COVERAGE: at the rung, tame_case's two key-value heads carry identical data, so every head-permuting tamper on it is a no-op");
}

/// A rung statement whose two key-value heads are NOT interchangeable: the
/// same tame fixture except that `Wk` and `Wv` weight the second key-value
/// head's rows differently. Everything else — the input, the query and output
/// projections, the tables — is `tame_case`'s.
pub(super) fn distinct_kv_case(s: &Shape) -> (BlockPublic, Vec<i16>) {
    let (d, f, kvw) = (s.width, s.hidden, s.kv_heads * s.head_dim);
    let diag = |outer: usize, inner: usize| -> Vec<i8> { (0..outer * inner).map(|k| if k / inner == k % inner { 64i8 } else { 0 }).collect() };
    // the second key-value head's diagonal is a THIRD of the first's, so its
    // requantised keys and values differ from the first's by much more than a
    // rounding step
    let kv_diag = |outer: usize, inner: usize| -> Vec<i8> {
        (0..outer * inner)
            .map(|k| {
                let (r, c) = (k / inner, k % inner);
                if r != c {
                    0i8
                } else if r < s.head_dim {
                    63i8
                } else {
                    21i8
                }
            })
            .collect()
    };
    let gamma = vec![64i8; d];
    let (cos, sin) = crate::tables_attn::rope_tables_generate(s.tokens, s.head_dim, 10000.0, F_RO);
    let (exp, _) = crate::tables_attn::exp_member(0, s.head_dim, s.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("the frozen SiLU member");
    let aw = super::grow_tests::pad_attention_weights(s, &diag(d, d), &kv_diag(kvw, d), &kv_diag(kvw, d), &diag(d, d), &gamma);
    let fw = super::grow_tests::pad_ff_weights(s, &gamma, &diag(d, f), &diag(d, f), &diag(f, d));
    let public = crate::private_block::AttentionPublic::new_shaped(s, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).expect("the distinct-KV statement");
    let ff = crate::private_block::FeedForwardPublic::new_shaped(s, &fw[0], &fw[1], &fw[2], &fw[3], &act).expect("the feed-forward statement");
    let (_, _, input) = super::grow_tests::tame_case(s);
    (BlockPublic::new(public, ff), input)
}

/// **ATTACK 3, the witness half.** On a fixture whose two key-value heads DO
/// differ, exchange their slices in every `Dom::Kv` plane, so that every query
/// head reads the OTHER group's keys and values while every relation INSIDE
/// `SC_KVZC` still holds (it is per position and its RoPE table does not depend
/// on the head). It must be rejected BY THE VERIFIER.
#[test]
fn a_query_head_reading_the_other_key_value_head_is_rejected_at_the_rung() {
    let sh = Shape::rung();
    assert_eq!(sh.kv_heads, 2, "this case is written for the rung's two key-value heads");
    let (blk, input) = distinct_kv_case(&sh);
    let base = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the distinct-KV honest witness");
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let (dh, kvw) = (sh.head_dim, sh.kv_heads * sh.head_dim);
    // the honest proof of THIS statement must verify first, or the tamper
    // below would be rejected for the wrong reason
    let o = outcome(&sh, &blk, clone_witness(&base));
    assert!(o.is_accepted(), "the distinct-KV honest witness does not prove: {}", o.short());
    let kv_planes: Vec<usize> = (0..ids.n_a()).filter(|p| ids.dom(*p) == Dom::Kv && !ids.is_multiplicity(*p)).collect();
    assert!(!kv_planes.is_empty(), "the rung has Dom::Kv planes");
    let mut w = clone_witness(&base);
    let mut moved = 0usize;
    for p in &kv_planes {
        for t in 0..sh.t_pad {
            for i in 0..dh {
                let (a, b) = (t * kvw + i, t * kvw + dh + i);
                if w.planes[*p][a] != w.planes[*p][b] {
                    moved += 1;
                }
                w.planes[*p].swap(a, b);
            }
        }
    }
    assert!(moved > 0, "the two key-value heads still carry identical data: the swap is a no-op and this test says nothing");
    let o = outcome(&sh, &blk, w);
    eprintln!("GQA: the two key-value heads exchanged ({moved} positions differ): {}", o.short());
    assert!(!o.is_accepted(), "a witness whose query heads read the other key-value head was ACCEPTED");
    assert!(matches!(o, Outcome::VerifierRejected(_)), "the key-value swap was caught only by the prover: {}", o.short());
}

// ------------------------------------------------------------------ attack 4
//
// THE TWO INTEGER WINDOWS. The rung's honest `NORM_WRHO` is 31 and `WRHO_S` is
// 17 with a third `sigma_s` limb. A remainder above its window, and the half-`p`
// isqrt alias, must both be refused by the VERIFIER.

/// **ATTACK 4.** A `rho` / `sigma` limb pushed above its declared window, on
/// both norms and on the softmax, must be rejected. The top limb's `scaled`
/// lookup is the only thing that bounds the window above the byte class, so
/// this is the test that the FOUR `1 << (8*limbs - wrho)` coefficients moved
/// with the window when the lane widened it.
#[test]
fn a_remainder_above_its_window_is_rejected_at_the_rung() {
    let (sh, blk, base) = honest_rung();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let ln = sh.limbs_norm();
    let ls = sh.limbs_sigma_s();
    assert_eq!((sh.norm_wrho, ln), (31, 4), "the rung's norm window");
    assert_eq!((sh.wrho_s, ls), (17, 3), "the rung's softmax window");
    // the top limb of each remainder: `scaled(top, 1 << (8*limbs - wrho))` is
    // what bounds it. The honest top limb is below `1 << (wrho - 8*(limbs-1))`;
    // one at that boundary is out of the window and inside the byte class.
    let norm_top = 1i64 << (sh.norm_wrho - 8 * (ln as u32 - 1));
    let sig_top = 1i64 << (sh.wrho_s - 8 * (ls as u32 - 1));
    let cases: Vec<(&str, usize, usize, i64)> = vec![
        ("norm_a rho top limb", ids.nr(ln - 1), 0, norm_top),
        ("norm_a sigma top limb", ids.ns(ln - 1), 0, norm_top),
        ("norm_m rho top limb", ids.mr(ln - 1), 0, norm_top),
        ("norm_m sigma top limb", ids.ms(ln - 1), 0, norm_top),
        ("softmax rho_s top limb", ids.sr(ls - 1), 0, sig_top),
        ("softmax sigma_s top limb", ids.sg(ls - 1), 0, sig_top),
    ];
    for (name, p, at, v) in cases {
        assert!((0..256).contains(&v), "{name}: {v} is outside the byte class, so the plain byte lookup would catch it and the test would say nothing");
        let mut w = clone_witness(&base);
        w.planes[p][at] = v;
        let o = outcome(&sh, &blk, w);
        eprintln!("WINDOW {name} set to {v} (the first value outside the window): {}", o.short());
        assert!(!o.is_accepted(), "{name}: a remainder above its window was ACCEPTED");
    }
}

// ------------------------------------------------------------------ attack 5
//
// SHAPE CONFUSION. The verifier takes its shape from its CALLER; the frame
// chooses nothing. What has to be shown is that a receipt for one shape or
// profile is rejected under another, including a shape whose PADDED sizes and
// receipt length are the same.

/// **ATTACK 5.** A rung receipt offered to a verifier that reads it at a
/// DIFFERENT head layout of the same padded sizes — 5 query heads over 1
/// key-value head, `h_pad` still 8, every domain still the same size, and the
/// SAME profile string, so only the parameter line and the schedule digest
/// separate them — must be rejected. And the toy's frame and the rung's frame
/// must each be refused by the other's verifier.
#[test]
fn a_receipt_does_not_verify_under_another_shape_at_the_rung() {
    let (sh, blk, w) = honest_rung();
    let (expected, bytes) = prove_rung(&sh, &blk, w).expect("the honest rung prover");
    // (i) the same padded geometry, a different head count, the SAME profile id
    let other = Shape::new(
        "the rung's padded geometry with a different head layout",
        "hashline-zk-mr1/private-block-rung-t24-dev/1",
        24,
        96,
        192,
        5,
        16,
        1,
        10,
        4,
        12,
        21,
        Some(8),
        Some(8),
        None,
        None,
    )
    .expect("well formed");
    assert_eq!((other.t_pad, other.d_pad, other.h_pad, other.f_pad), (sh.t_pad, sh.d_pad, sh.h_pad, sh.f_pad), "the two shapes must share every padded size");
    let r = verify_bytes_at(&other, &blk, &expected, &bytes);
    eprintln!("SHAPE: the rung frame under a 5-head / 1-KV verifier of the same padded sizes: {r:?}");
    assert!(r.is_err(), "a rung receipt verified under a different head layout");
    // (ii) the rung frame under the frozen toy verifier, and the toy's own
    // frame under the rung verifier
    let (toy_blk, toy_input) = BlockPublic::synthetic_fixture();
    let toy_out = compute_output(&toy_blk, &toy_input).expect("the toy output");
    let toy_spec = IoSpec::new(review_context(), 0, 0).expect("the toy endpoint spec");
    let (toy_expected, toy_owners) = prepare_endpoints(toy_spec, &toy_input, &toy_out).expect("the toy endpoints");
    let (toy_receipt, _) = prove_with_stats(&toy_blk, &toy_input, &toy_expected, toy_owners).expect("the toy prover");
    let toy_bytes = toy_receipt.to_bytes(&toy_blk, &toy_expected).expect("the toy frame");
    verify_bytes(&toy_blk, &toy_expected, &toy_bytes).expect("the toy receipt verifies under the toy verifier");
    assert!(verify_bytes(&toy_blk, &toy_expected, &bytes).is_err(), "a rung frame verified under the toy verifier");
    assert!(verify_bytes_at(&sh, &blk, &expected, &toy_bytes).is_err(), "a toy frame verified under the rung verifier");
    eprintln!("SHAPE: toy frame {} B, rung frame {} B; each refused by the other's verifier", toy_bytes.len(), bytes.len());
}

// ------------------------------------------------------------------ attack 6
//
// IS THE TOY REALLY UNTOUCHED? The lane's freeze gate pins the receipt LENGTH,
// a literal schedule digest and header lines. None of those proves the
// transcript's BYTES are unchanged. A receipt produced BEFORE the lane, by a
// build of this crate from before its first shared-file commit, is the check
// that needs no new capture: if it still verifies under the lane's verifier,
// the toy's verifier is bit-compatible with what it was.

/// the repository's own pre-lane toy receipts: produced at `4bf1fa0` (the row
/// fold integration), which precedes this lane's first shared-file commit
/// `bce1d7c` (step S1), and at commits before the review base `73d3398`
const PRE_LANE_RECEIPTS: [&str; 4] = [
    "/../results/zk60_rowfold_20260919/integration/native-block-0",
    "/../results/zk60_rowfold_20260919/integration/native-block-1",
    "/../results/zk60_private_block_evidence/owner_run1",
    "/../results/zk60_attention_integration_20260919/block_public",
];

/// **ATTACK 6, THE MOST IMPORTANT ONE.** A toy receipt produced BEFORE the lane
/// must still verify under the lane's verifier, against a public statement the
/// verifier rebuilds itself. This is stronger than the lane's freeze gate,
/// which pins a length and a digest of the SCHEDULE TEXT: a change in the
/// argument's arithmetic, in a claim point, in a challenge order or in the
/// codec would leave both unmoved and break this.
#[test]
fn a_toy_receipt_made_before_the_lane_still_verifies() {
    let (blk, _) = BlockPublic::synthetic_fixture();
    let mut checked = 0usize;
    for dir in PRE_LANE_RECEIPTS {
        let base = format!("{}{dir}", env!("CARGO_MANIFEST_DIR"));
        let (rp, ep) = (format!("{base}/block_receipt.bin"), format!("{base}/block_expected.bin"));
        let (frame, policy) = match (std::fs::read(&rp), std::fs::read(&ep)) {
            (Ok(f), Ok(p)) => (f, p),
            _ => {
                eprintln!("PRE-LANE {dir}: absent, skipped");
                continue;
            }
        };
        assert_eq!(frame.len(), 2_816_472, "{dir}: not a toy-profile frame");
        let expected = ExpectedIo::from_bytes(&policy).expect("the archived endpoint policy parses");
        let r = verify_bytes(&blk, &expected, &frame);
        eprintln!("PRE-LANE {dir}: {} B, verify = {r:?}", frame.len());
        r.unwrap_or_else(|e| panic!("{dir}: a toy receipt made BEFORE the lane no longer verifies under the lane's verifier: {e}"));
        // and a one-bit change to the same archived frame is still refused
        let mut bad = frame.clone();
        bad[40] ^= 1;
        assert!(verify_bytes(&blk, &expected, &bad).is_err(), "{dir}: a corrupted archived frame verified");
        checked += 1;
    }
    assert!(checked > 0, "no pre-lane toy receipt was found: this check did not run");
    eprintln!("PRE-LANE: {checked} archived toy receipts still verify under the lane's verifier");
}

// ------------------------------------------------------------------ attack 8
//
// A MALFORMED RECEIPT MUST NOT PANIC. Every index the verifier takes from the
// frame is a denial of service at best; the codec is supposed to make all of
// them unreachable.

/// **ATTACK 8.** Single-byte corruptions spread over the whole rung frame must
/// each produce an `Err`, never a panic and never an acceptance. Run in the
/// test process, so a panic fails the test.
#[test]
fn a_corrupted_rung_frame_is_refused_and_never_panics() {
    let (sh, blk, w) = honest_rung();
    let (expected, bytes) = prove_rung(&sh, &blk, w).expect("the honest rung prover");
    let n = bytes.len();
    // a deterministic spread: the header, the three roots, the slot block, the
    // mask opening, each of the four openings, and the last byte
    let picks: Vec<usize> = (0..48).map(|k| (k * (n / 48)).min(n - 1)).chain([0, 7, 8, 39, 40, 71, 103, n - 1]).collect();
    for at in picks {
        let mut bad = bytes.clone();
        bad[at] ^= 1;
        let r = verify_bytes_at(&sh, &blk, &expected, &bad);
        assert!(r.is_err(), "a rung frame with byte {at} flipped VERIFIED");
    }
    // and a frame one byte long and one byte short
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..n - 1]).is_err(), "a short frame verified");
    let mut long = bytes.clone();
    long.push(0);
    assert!(verify_bytes_at(&sh, &blk, &expected, &long).is_err(), "a long frame verified");
    eprintln!("CODEC: 56 single-byte corruptions, a short frame and a long frame all refused, none panicking");
}

// ------------------------------------------------------------------ attack 2
//
// THE ENDPOINTS. The endpoint plane is the PADDED `(32, 128)` `Dom::D` cube. Is
// its own pad bound, or only bound to `A_X`'s pad? Both must hold, or a
// verifier who later opens the endpoint sees something that is not the block's
// input.

/// **ATTACK 2, the endpoints.** An endpoint committed with a nonzero value in a
/// PADDED column must be rejected: `SC_IO_IN` binds the endpoint to `A_X` over
/// the whole padded cube, and `A_X`'s pad is proved zero, so the endpoint's pad
/// is zero too. The case is built by handing `prepare_endpoints` a plane that
/// differs from the witness's only at a padded column.
#[test]
fn an_endpoint_with_a_nonzero_pad_is_rejected_at_the_rung() {
    let (sh, blk, w) = honest_rung();
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| i16::try_from(*v).expect("int16")).collect() };
    let (mut pin, pout) = (plane(ids.at(A_X)), plane(ids.at(A_X2)));
    let at = sh.width; // (t 0, i 96): a padded width column
    assert_eq!(pin[at], 0, "the honest endpoint pad is not zero");
    pin[at] = 1;
    let spec = IoSpec::new_shaped(&sh, review_context(), 0, 0).expect("the rung endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &pin, &pout).expect("the endpoint owners");
    let r = prove_inner_at(&sh, &blk, w, &expected, owners);
    match r {
        Err(e) => eprintln!("ENDPOINT pad: refused by the prover: {e}"),
        Ok((receipt, _)) => {
            let bytes = receipt.to_bytes_at(&sh, &blk, &expected).expect("the frame");
            let v = verify_bytes_at(&sh, &blk, &expected, &bytes);
            eprintln!("ENDPOINT pad: {v:?}");
            assert!(v.is_err(), "an input endpoint with a nonzero padded column was ACCEPTED");
        }
    }
}

// ------------------------------------------------------------------ attack 7
//
// `audit_claims` is the whole defence against two claims sharing a reserved
// pair, and the lane's own finding S12-F2 is a concrete instance of it firing.
// It must still refuse every case it refused before, at the RUNG's row width.

/// **ATTACK 7.** The audit's six refusals, re-run at the rung's row width
/// (`log_cols` 10, `n` 1,024) instead of the toy's 256, and at the endpoints'
/// own width (256). The lane parameterised the audit by `n`; a `n` that was
/// silently the toy's would make every one of these vacuous at the rung, which
/// is exactly the shape of finding S12-F2.
#[test]
fn the_mask_schedule_audit_still_refuses_every_case_at_the_rungs_row_width() {
    use crate::field::Fp2;
    use crate::pcs::{Slice, ZClaim, ZPart};
    for log_n in [8usize, 10] {
        let n = 1usize << log_n;
        let sites = vec![4usize, 5, 6, 7];
        let claim = |i: usize, row: usize| ZClaim {
            parts: vec![
                ZPart { slice: Slice { offset: i * n, log_size: log_n as u32 }, coef: Fp2::ONE, point: vec![Fp2::ONE] },
                ZPart { slice: Slice { offset: row * n, log_size: (log_n + 1) as u32 }, coef: Fp2::ONE, point: vec![Fp2::ONE] },
            ],
            value: Fp2::ZERO,
        };
        let audit = |c: &[ZClaim]| super::protocol::audit_claims(c, n, 10, &sites, None, 8);
        audit(&[claim(0, 4), claim(1, 6)]).unwrap_or_else(|e| panic!("log_n {log_n}: the honest pair assignment was refused: {e}"));
        assert!(audit(&[claim(0, 4), claim(1, 4)]).is_err(), "log_n {log_n}: a pair shared by two claims");
        assert!(audit(&[claim(0, 4)]).is_err(), "log_n {log_n}: an unused reserved pair");
        assert!(audit(&[claim(0, 5), claim(1, 6)]).is_err(), "log_n {log_n}: a misaligned pair");
        assert!(audit(&[claim(0, 4), claim(1, 8)]).is_err(), "log_n {log_n}: a claim on the proximity pair");
        let mut dead = claim(1, 6);
        dead.parts[1].coef = Fp2::ZERO;
        assert!(audit(&[claim(0, 4), dead]).is_err(), "log_n {log_n}: a zero mask coefficient");
        let mut unmasked = claim(2, 4);
        unmasked.parts.remove(1);
        assert!(audit(&[claim(0, 4), claim(1, 6), unmasked]).is_err(), "log_n {log_n}: an unmasked claim");
    }
    eprintln!("AUDIT: all six refusals fire at both the endpoints' width (256) and the rung's (1,024)");
}

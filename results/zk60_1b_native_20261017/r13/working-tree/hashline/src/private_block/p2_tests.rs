//! **STAGE 30: THE UNPADDED ARM OF THE PAD RULE, IN THE ORDINARY FILTER.**
//!
//! **The gap this closes.** Ruling P-1's pad-zero term is drawn per HOST
//! SLOT, and only when the domain that slot hosts actually pads.
//! `argument.rs` does it with three lines per arm:
//!
//! ```text
//! let pad_doms = ALL_DOMS.filter(|d| pad_zero_host(*d) == slot && !zero_rule_a_planes(sh, ids, *d).is_empty());
//! let (pad_on, n_pad) = (!pad_doms.is_empty(), usize::from(pad_on));
//! let mu   = tr.challenge_fp2_vec(<base> + n_pad);
//! let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
//! ```
//!
//! and `B::supp` returns `None` — no public support table, no gate factor —
//! when `!sh.pads(dom)`. So a host slot whose domain does not pad draws **two
//! challenges fewer** (one `mu`, one `zeta`), builds no indicator and, when it
//! is one of the eight `INDICATOR_SLOT_DOMAIN` slots, declares **one degree
//! less**.
//!
//! **Nothing in the ordinary filter reached that arm.** `Shape::rung`,
//! `Shape::rung_g` and `Shape::rung_k4` — 24 tokens, width 96, hidden 192 —
//! pad **all nine** domains, so every host slot takes the `true` arm. The
//! frozen toy takes neither: `Shape::carries_pad_rule` is false there and the
//! machinery does not exist in its transcript at all (finding S9-F1). The one
//! shape that carries the rule and takes the FALSE arm is 125M, where three
//! domains are exact powers of two — `Dom::T = 2^9`, `Dom::Kv = 512 * 4 * 64
//! = 2^17`, `Dom::F = 512 * 2048 = 2^20` — and every 125M proof is an
//! `#[ignore]`d 10 GiB test. The independent Python gate had this branch
//! WRONG in its own port until 2026-09-21 and no development shape could show
//! it; that is its finding **M-F1**.
//!
//! The security owner's standing rule after S19-F1 is that a branch which
//! only an ignored heavy test reaches is a branch nobody tests.
//! [`Shape::rung_p2`] closes it: **125M's own padded-domain set at rung-K4's
//! padded size**, so both arms of the rule live in one shape that the
//! ordinary filter proves in seconds.
//!
//! **WHAT A GREEN RUN HERE IS, AND IS NOT.** A CORRECTNESS result at a new
//! development-grade profile (ruling P-7): the honest prover and the honest
//! verifier agree on a GENERIC witness (dense public weights, a non-constant
//! hidden input, four key-value groups carrying pairwise different data), the
//! witness equals the independent reference kernel, the draw census is the
//! rule's own count on both sides, and every tamper inside an unpadded domain
//! is rejected by the VERIFIER at the slot under test. It is NOT a privacy
//! result and NOT an acceptance.
//!
//! **THE CAPTURE RULE.** Everything here is public synthetic test data from
//! fixed-seed integer streams; what the census prints is fractions and
//! live-slot counts, never a value or a position.

use super::argument::{define, Ctx, Points};
use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::review_tests::{clone_witness, outcome, Outcome};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::field::Fp2;
use crate::transcript::Transcript;

// ---------------------------------------------------------------- the shape's own facts

/// **THE COUNTED RECEIPT LENGTH OF ONE rung-P2 BLOCK.**
///
/// The INDEPENDENT Python model's own output at this shape
/// (`scripts/zk60_private_block_layout_model.py`, `SHAPES["rung_p2"]`),
/// transcribed, with nothing in between. It is rung-K4's 4,743,128 B **minus
/// 400**, and those 400 bytes are the whole arithmetic of this stage: slots
/// 16 (`05 KV zero-check`) and 18 (`14 F zero-check`) lose the support
/// indicator, so each drops one degree and publishes one value fewer per
/// round — `(10 + 1) + (13 + 1) = 25` values of 16 B.
pub(super) const P2_FRAME_BYTES: usize = 4_742_728;

fn p2_context() -> Digest {
    *blake3::hash(b"private block: stage 30, both arms of the pad rule").as_bytes()
}

/// the padded plane of a witness, as `int16`
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

/// the TRUE `(tokens, width)` input inside a padded `Dom::D` plane
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

// ---------------------------------------------------------------- the pad census

/// **THE RULE, TRANSCRIBED FROM `argument.rs` AND NOT FROM THE SCHEDULE.**
/// Does the host slot of `dom` carry the pad-zero term at this shape? This is
/// `argument::define`'s own `pad_doms` predicate, written out once.
fn pad_on_for(sh: &Shape, ids: &Ids, dom: Dom) -> bool {
    !super::pad::zero_rule_a_planes(sh, ids, dom).is_empty()
}

/// Which slots host a pad-zero term at this shape, and for which domains.
/// `SC_SZC` hosts two (`Dom::Ht` and `Dom::S`, finding S9-F7), so this is a
/// slot-keyed map and not a domain-keyed one.
fn pad_on_by_slot(sh: &Shape) -> [bool; N_SLOTS] {
    let ids = Ids::new(sh).expect("a plane map");
    let mut out = [false; N_SLOTS];
    for dom in ALL_DOMS {
        if pad_on_for(sh, &ids, dom) {
            out[super::pad::pad_zero_host(dom)] = true;
        }
    }
    out
}

/// the host slot of every domain, deduplicated and sorted — the eight slots a
/// pad census is about
fn host_slots() -> Vec<usize> {
    let mut v: Vec<usize> = ALL_DOMS.into_iter().map(super::pad::pad_zero_host).collect();
    v.sort_unstable();
    v.dedup();
    v
}

/// **THE GAP, STATED AS A CENSUS AND ASSERTED.**
///
/// For every shape the module builds, which host slots take the `pad_on ==
/// true` arm of ruling P-1 and which take the `false` one. The three columns
/// that matter:
///
/// | shape | carries the rule | host slots on the TRUE arm | on the FALSE arm |
/// |---|---|---|---|
/// | `toy` | **no** (S9-F1's profile gate) | none | all 8 — but the machinery is absent, not switched off |
/// | `rung`, `rung_g`, `rung_k4` | yes | **all 8** | **none** |
/// | `m125` | yes | 5 | **3** — `SC_TZC`, `SC_KVZC`, `SC_FZC`; every 125M proof is `#[ignore]`d |
/// | `rung_p2` (new) | yes | 5 | **the same 3**, in this filter |
///
/// So before this stage the FALSE arm of a shape that carries the rule was
/// reachable at 125M and nowhere else, which is the gap. The test asserts
/// every cell of that table, and asserts in particular that the three slots
/// rung-P2 switches off are the three 125M switches off — the same slots, not
/// merely the same count.
#[test]
fn only_the_125m_shape_and_the_new_one_reach_the_unpadded_arm_of_the_pad_rule() {
    let hosts = host_slots();
    assert_eq!(hosts, vec![SC_TZC, SC_LZC, SC_DZC, SC_QZC, SC_KVZC, SC_SZC, SC_FZC, SC_TAB], "the pad-zero host slots moved");
    let off_at = |sh: &Shape| -> Vec<usize> {
        let on = pad_on_by_slot(sh);
        hosts.iter().copied().filter(|s| !on[*s]).collect()
    };
    // the frozen toy: the rule is ABSENT, not off for a domain
    let toy = Shape::toy();
    assert!(!toy.carries_pad_rule(), "the frozen toy must carry no pad machinery at all");
    assert_eq!(off_at(&toy), hosts, "the toy's transcript carries a pad-zero term");
    // the three development shapes the ordinary filter proves at: every
    // domain pads, so the FALSE arm is unreachable
    for sh in [Shape::rung(), Shape::rung_g(), Shape::rung_k4()] {
        assert!(sh.carries_pad_rule(), "{}: this shape must carry the rule", sh.name);
        assert!(ALL_DOMS.iter().all(|d| sh.pads(*d)), "{}: a domain of this shape does not pad, which this test's premise denies", sh.name);
        assert_eq!(off_at(&sh), Vec::<usize>::new(), "{}: a host slot takes the unpadded arm", sh.name);
    }
    // 125M, and the new shape: the same three domains and the same three
    // slots
    let want_doms = vec![Dom::T, Dom::Kv, Dom::F];
    let want_slots = vec![SC_TZC, SC_KVZC, SC_FZC];
    for sh in [Shape::m125(), Shape::rung_p2()] {
        let ids = Ids::new(&sh).expect("a plane map");
        assert!(sh.carries_pad_rule(), "{}: this shape must carry the rule", sh.name);
        let unpadded: Vec<Dom> = ALL_DOMS.into_iter().filter(|d| !sh.pads(*d)).collect();
        assert_eq!(unpadded, want_doms, "{}: the unpadded domains are not T, Kv, F", sh.name);
        assert_eq!(off_at(&sh), want_slots, "{}: the host slots on the unpadded arm are not 02, 16, 18", sh.name);
        for d in ALL_DOMS {
            assert_eq!(pad_on_for(&sh, &ids, d), sh.pads(d), "{}: {d:?}'s pad-zero group disagrees with `Shape::pads`", sh.name);
        }
    }
    assert_eq!((SC_TZC, SC_KVZC, SC_FZC), (2, 16, 18), "the three slots the Python gate names by number moved");
    eprintln!("S30 GAP CENSUS: toy = no rule; rung / rung-G / rung-K4 = 8 of 8 host slots on the PADDED arm; 125M and rung-P2 = 5 of 8, the unpadded three being slots 02, 16, 18 (Dom::T, Dom::Kv, Dom::F)");
}

/// **THE PER-DOMAIN TABLE**, printed for rung-P2 beside rung-K4 and 125M and
/// asserted where it matters: rung-P2's PADDED layout is rung-K4's exactly —
/// same nine logs, same helper counts, same slot cubes — and the only
/// difference between the two shapes is which of those padded domains the
/// witness actually fills. That identity is what makes the draw census of
/// [`the_draw_census_is_the_rules_count_and_differs_from_rung_k4_only_where_the_pad_rule_does`]
/// a measurement of the pad rule and of nothing else.
#[test]
fn the_new_shapes_padded_layout_is_rung_k4s_and_only_its_true_sizes_move() {
    let (p2, k4, m) = (Shape::rung_p2(), Shape::rung_k4(), Shape::m125());
    assert_eq!((p2.tokens, p2.width, p2.hidden), (32, 96, 256), "rung-P2's block dimensions");
    assert_eq!((p2.q_heads, p2.head_dim, p2.kv_heads), (12, 8, 4), "rung-P2's head axis");
    assert_eq!((p2.t_pad, p2.d_pad, p2.h_pad, p2.f_pad), (k4.t_pad, k4.d_pad, k4.h_pad, k4.f_pad), "rung-P2's padded axes are not rung-K4's");
    assert_eq!((p2.t_pad, p2.d_pad, p2.h_pad, p2.f_pad), (32, 128, 16, 256), "rung-P2's padded axes");
    assert_eq!(p2.kv_heads.trailing_zeros() as usize, 2, "rung-P2 must carry TWO group bits");
    let slots: Vec<usize> = (0..p2.q_heads).map(|h| p2.head_slot(h)).collect();
    assert_eq!(slots, vec![0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14], "the head permutation");
    let pad_slots: Vec<usize> = (0..p2.h_pad).filter(|s| !p2.slot_is_true_head(*s)).collect();
    assert_eq!(pad_slots, vec![3, 7, 11, 15], "the padded head slots are not 125M's {{3, 7, 11, 15}}");
    // the calibration and the endpoint are rung-K4's, so nothing but the pad
    // rule can move a byte between the two
    assert_eq!((p2.f_e, p2.norm_wrho, p2.wrho_s), (k4.f_e, k4.norm_wrho, k4.wrho_s), "rung-P2's calibration differs from rung-K4's");
    assert_eq!((p2.endpoint_rows, p2.endpoint_log_n, p2.endpoint_inv_rate), (k4.endpoint_rows, k4.endpoint_log_n, k4.endpoint_inv_rate), "rung-P2's endpoint differs");
    assert!(p2.endpoint_general, "rung-P2 must ride the GENERALISED endpoint");
    assert!(p2.carries_pad_rule(), "rung-P2 must carry the pad rule");
    // the bilinear refusal of stage 21 (F-2): no lifted domain there
    for dom in [Dom::Q, Dom::Kv, Dom::S] {
        assert_eq!(p2.log(dom), p2.natural_log(dom), "{dom:?} is lifted by P-3, so the bilinear slots cannot serve this shape");
    }
    assert_eq!(p2.log(Dom::Kv), p2.log_cols, "Dom::Kv is meant to sit exactly at the row width");
    // THE PER-DOMAIN TABLE
    eprintln!("S30 PER-DOMAIN TABLE  dom | natural size -> padded size, pad_on, host slot, n_pad");
    for dom in ALL_DOMS {
        let host = super::pad::pad_zero_host(dom);
        for sh in [&p2, &k4, &m] {
            let on = sh.pads(dom);
            eprintln!(
                "S30   {:<8} {:<4} true {:>9} padded {:>9} (log {:>2}{}) pad_on {:<5} host slot {host:02} n_pad {}",
                sh.name.split(' ').next().unwrap_or(""),
                format!("{dom:?}"),
                sh.true_size(dom),
                sh.size(dom),
                sh.log(dom),
                if sh.log(dom) != sh.natural_log(dom) { ", P-3 lifted" } else { "" },
                on,
                usize::from(on)
            );
        }
    }
    // the nine logs and the six helper counts are rung-K4's, one by one
    for dom in ALL_DOMS {
        assert_eq!(p2.log(dom), k4.log(dom), "{dom:?}'s log differs from rung-K4's");
        assert_eq!(p2.helpers(dom), k4.helpers(dom), "{dom:?}'s helper count differs from rung-K4's");
    }
    // the slot schedule differs in EXACTLY the two indicator slots whose
    // domain stopped padding
    let (sp, sk) = (p2.slots(), k4.slots());
    let moved: Vec<usize> = (0..N_SLOTS).filter(|s| sp[*s] != sk[*s]).collect();
    assert_eq!(moved, vec![SC_KVZC, SC_FZC], "the schedule differs from rung-K4's somewhere other than slots 16 and 18");
    for s in [SC_KVZC, SC_FZC] {
        assert_eq!((sp[s].0, sp[s].1, sp[s].2 + 1), sk[s], "slot {s} does not differ from rung-K4's by exactly one degree");
    }
    // 125M's schedule has the SAME two slots one degree below rung-K4's
    // pattern, which is the fact rung-P2 is standing in for
    assert_eq!((m.slots()[SC_KVZC].2, m.slots()[SC_FZC].2), (4, 4), "125M's two unpadded zero-checks are not degree 4");
    assert_eq!((sp[SC_KVZC].2, sp[SC_FZC].2), (4, 4), "rung-P2's two unpadded zero-checks are not degree 4");
    assert!(p2.slot_lengths().iter().all(|l| l + 256 <= 512), "a mask row leaves the M budget");
    // D17: its own profile, its own key set
    assert_eq!(p2.profile, "hashline-zk-mr1/private-block-rung-p2-t32-dev/1");
    assert!(!p2.hashes_under_the_legacy_rule(), "rung-P2 must be TAGGED");
    assert_ne!(p2.hash_tag(), k4.hash_tag(), "rung-P2 and rung-K4 share a hash-tag key set");
    assert_eq!(run::RUN_PROFILE_RUNG_P2, "hashline-zk-mr1/private-run-rung-p2-t32-dev/1");
    // and the counted receipt, from the independent model
    assert_eq!(p2.receipt_bytes().total, P2_FRAME_BYTES, "the counted rung-P2 receipt is not the model's");
    assert_eq!(k4.receipt_bytes().total, super::k4_tests::K4_FRAME_BYTES, "rung-K4's counted receipt moved");
    assert_eq!(super::k4_tests::K4_FRAME_BYTES - P2_FRAME_BYTES, 400, "the two shapes differ by other than the two lost degrees");
    eprintln!(
        "S30 rung-P2: T{}/d{}/f{}, {} heads of {} over {} KV heads, pads ({}, {}, {}, {}), lkv 2, unpadded domains T/Kv/F, largest L {}, receipt {} B (rung-K4's {} - 400)",
        p2.tokens,
        p2.width,
        p2.hidden,
        p2.q_heads,
        p2.head_dim,
        p2.kv_heads,
        p2.t_pad,
        p2.d_pad,
        p2.h_pad,
        p2.f_pad,
        p2.slot_lengths().iter().max().expect("slots"),
        p2.receipt_bytes().total,
        super::k4_tests::K4_FRAME_BYTES
    );
}

// ---------------------------------------------------------------- the draw census

/// How many challenges `argument::define` draws for each slot at `sh`,
/// MEASURED: the transcript is cloned before the definition and then replayed
/// one `challenge_fp2` at a time until it catches up, which is exactly how
/// `run_capture` recovers a slot's `definition_challenges` on the verifier's
/// side. A definition that ever ABSORBED would run away and be caught by the
/// bound rather than mis-counted.
fn measured_draws(sh: &Shape) -> [usize; N_SLOTS] {
    let lay = Layout::for_shape(sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let ctx = Ctx { accuracy:None,
        lay: &lay,
        public: &public,
        ff: &ff,
        alpha: Fp2::from_u64(7).add(Fp2::U),
        beta: Fp2::from_u64(11),
        g_u8: Fp2::from_u64(13),
        g_exp: Fp2::from_u64(17),
        g_act: Fp2::from_u64(19),
        g_dd: Fp2::from_u64(23),
    };
    let mut tr = Transcript::new(sh.profile.as_bytes());
    let mut pts = Points::default();
    let mut out = [0usize; N_SLOTS];
    for s in 0..N_SLOTS {
        let mut probe = Transcript::clone_state(&tr);
        let def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
        drop(def);
        let mut n = 0usize;
        while probe.state() != tr.state() {
            probe.challenge_fp2();
            n += 1;
            assert!(n <= 512, "{}: slot {s}'s definition did not reach the transcript's state in 512 draws", sh.name);
        }
        out[s] = n;
    }
    out
}

/// **THE RULE'S OWN COUNT, for the eight pad-zero HOST slots**, transcribed
/// arm by arm from `argument.rs` and from nothing else. `pad` is one when the
/// slot hosts a padded domain, and it appears TWICE in every arm but
/// `SC_LZC`'s and `SC_TAB`'s: once as the extra `mu` entry (`n_pad`) and once
/// as the `zeta`.
///
/// | slot | the arm's draws |
/// |---|---|
/// | `SC_TZC` (02) | `log(T)` (tau) + `6 + n_pad` (mu) + 2 (nu) + `pad` (zeta) |
/// | `SC_LZC` (03) | `log(L)` (tau) + `pad` (mu_pad) + `pad` (zeta) |
/// | `SC_DZC` (14) | `log(D)` + `11 + helpers(D) + n_pad` + 2 + `pad` |
/// | `SC_QZC` (15) | `log(Q)` + `1 + helpers(Q) + n_pad` + 2 + `pad` |
/// | `SC_KVZC` (16) | `log(Kv)` + `1 + helpers(Kv) + n_pad` + 2 + `pad` |
/// | `SC_SZC` (17) | `log(S)` + `5 + helpers(S) + 1 + n_pad` + 2 + `pad` |
/// | `SC_FZC` (18) | `log(F)` + `4 + helpers(F) + n_pad` + 2 + `pad` |
/// | `SC_TAB` (19) | `log(Tab)` + `3 + n_pad` + `pad` |
fn rule_draws(sh: &Shape, slot: usize) -> usize {
    let on = pad_on_by_slot(sh)[slot];
    let p = usize::from(on);
    match slot {
        SC_TZC => sh.log(Dom::T) + (6 + p) + 2 + p,
        SC_LZC => sh.log(Dom::L) + p + p,
        SC_DZC => sh.log(Dom::D) + (11 + sh.helpers(Dom::D) + p) + 2 + p,
        SC_QZC => sh.log(Dom::Q) + (1 + sh.helpers(Dom::Q) + p) + 2 + p,
        SC_KVZC => sh.log(Dom::Kv) + (1 + sh.helpers(Dom::Kv) + p) + 2 + p,
        SC_SZC => sh.log(Dom::S) + (5 + sh.helpers(Dom::S) + 1 + p) + 2 + p,
        SC_FZC => sh.log(Dom::F) + (4 + sh.helpers(Dom::F) + p) + 2 + p,
        SC_TAB => sh.log(Dom::Tab) + (3 + p) + p,
        _ => panic!("slot {slot} is not a pad-zero host"),
    }
}

/// **THE DRAW CENSUS.** For every pad-zero host slot of the new shape, the
/// number of challenges the definition draws is the rule's own count —
/// `<base> + n_pad` `mu` entries and a `zeta` if and only if the slot's
/// domain pads — and the same census function, on rung-K4, gives the count of
/// the all-padded arm. The two shapes have the SAME padded layout (the test
/// above asserts it slot by slot), so every base is identical and the two
/// censuses may differ ONLY where the pad rule does: **by exactly two, at
/// slots 02, 16 and 18, and nowhere else in the whole twenty-three-slot
/// schedule.**
#[test]
fn the_draw_census_is_the_rules_count_and_differs_from_rung_k4_only_where_the_pad_rule_does() {
    let (p2, k4) = (Shape::rung_p2(), Shape::rung_k4());
    let (dp, dk) = (measured_draws(&p2), measured_draws(&k4));
    for slot in host_slots() {
        assert_eq!(dp[slot], rule_draws(&p2, slot), "rung-P2 slot {slot} [{}] draws {} challenges, the rule says {}", SLOT_NAMES[slot], dp[slot], rule_draws(&p2, slot));
        assert_eq!(dk[slot], rule_draws(&k4, slot), "rung-K4 slot {slot} [{}] draws {} challenges, the rule says {}", SLOT_NAMES[slot], dk[slot], rule_draws(&k4, slot));
    }
    // and the differential, over ALL twenty-three slots
    let differ: Vec<usize> = (0..N_SLOTS).filter(|s| dp[*s] != dk[*s]).collect();
    assert_eq!(differ, vec![SC_TZC, SC_KVZC, SC_FZC], "the two shapes' draw counts differ somewhere other than the three unpadded host slots");
    for s in differ {
        assert_eq!(dp[s] + 2, dk[s], "slot {s} differs by {} draws, not by the one `mu` and the one `zeta` the rule costs", dk[s] - dp[s]);
    }
    for slot in host_slots() {
        eprintln!(
            "S30 DRAW CENSUS slot {slot:02} [{:<28}] rung-P2 {:>3} (pad_on {}) | rung-K4 {:>3} (pad_on {})",
            SLOT_NAMES[slot],
            dp[slot],
            pad_on_by_slot(&p2)[slot],
            dk[slot],
            pad_on_by_slot(&k4)[slot]
        );
    }
}

// ---------------------------------------------------------------- the chain band probe

/// **THE FIRST ADMISSIBLE THREE-BLOCK DOWN BAND AT rung-P2 — MEASURED**,
/// exactly as stage 21 measures it at rung-G and stage 22 at rung-K4: the
/// down-projection band is walked DOWN from the recipe's own single-block
/// band and the first one at which the witness builder accepts all three
/// blocks is taken, every other band left at the recipe's so that the four
/// key-value groups still carry genuinely different data.
#[test]
fn the_pinned_rung_p2_chain_band_is_the_first_admissible_one() {
    use super::dense_tests::{band_down, band_down_run, dense_words_with, statement_of_words, BAND_ATTN, BAND_GATE, GAIN, INPUT_MAG};
    let sh = Shape::rung_p2();
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
                    eprintln!("P2 DENSE RUN band {down}: the witness builder refused a block of the chain: {m}");
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
    let band = found.expect("no fully dense band makes a three-block chain admissible at rung-P2");
    eprintln!("P2 DENSE RUN: the first admissible three-block down band is {band} (the recipe's single-block band is {})", band_down(&sh));
    assert_eq!(band, band_down_run(&sh), "the band `dense_tests::band_down_run` pins for rung-P2 is not the first admissible one");
}

// ---------------------------------------------------------------- one honest block

fn endpoints_of(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the rung-P2 plane map");
    let spec = IoSpec::new_shaped(sh, p2_context(), 0, 0).expect("the rung-P2 endpoint spec");
    prepare_endpoints(spec, &padded(w, ids.at(A_X)), &padded(w, ids.at(A_X2))).expect("the rung-P2 endpoint owners")
}

fn prove_p2(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Receipt, Vec<u8>), String> {
    let (expected, owners) = endpoints_of(sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, receipt, bytes))
}

/// how non-trivial a rung-P2 witness is, as FRACTIONS and LIVE-SLOT COUNTS
/// only (the capture rule). It also asserts the one thing this shape adds:
/// the LAST position of each unpadded domain is inside the TRUE support, so
/// a tamper there is a tamper on real data and not on a pad.
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
    // the three UNPADDED domains are full: their last position is data
    for dom in [Dom::T, Dom::Kv, Dom::F] {
        assert!(!sh.pads(dom), "{what}: {dom:?} pads at this shape, which the whole stage denies");
        assert_eq!(sh.size(dom), sh.true_size(dom), "{what}: {dom:?}'s padded size is not its true size");
    }
    let last_t = &w.planes[ids.at(A_DSQ)][sh.size(Dom::T) - 1];
    assert!(*last_t != 0, "{what}: the LAST position of the unpadded Dom::T is zero, so a tamper there would say nothing");
    eprintln!("S30 CENSUS [{what}]: 12/12 head slots live, 4/4 key-value groups live and pairwise different, the upper hidden half live, the last position of T / Kv / F inside the true support");
}

/// **THE HONEST rung-P2 BLOCK PROVES AND VERIFIES FROM BYTES** on the FULLY
/// DENSE recipe with a GENERIC hidden input — every entry of all nine public
/// words nonzero, four genuinely different key-value groups, the upper
/// hidden half of the feed-forward planes live — with three of its nine
/// domains unpadded, so three host slots take the arm no other shape in this
/// filter takes. The frame is the COUNTED length and a one-byte truncation
/// is refused.
#[test]
fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_p2() {
    let sh = Shape::rung_p2();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-P2 dense honest witness");
    let ids = Ids::new(&sh).expect("the rung-P2 plane map");
    assert!(super::pad::every_checkable_relation_holds(&sh, &ids, &w), "the honest rung-P2 witness is internally inconsistent");
    assert_non_trivial(&sh, &ids, &w, "one dense block");
    let blk = BlockPublic::new(public, ff);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_p2(&sh, &blk, w).expect("the rung-P2 dense prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), P2_FRAME_BYTES, "the rung-P2 frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the rung-P2 receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the rung-P2 receipt verifies from bytes");
    eprintln!("rung-P2 DENSE one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short rung-P2 frame was accepted");
}

/// **THE DEGENERATE CASE, NAMED AS ONE.** The all-zero hidden input on the
/// lane's synthetic tame fixture proves and verifies at rung-P2. It says
/// nothing about the group bits — every key-value group is identically zero
/// — and it exists because it is the fixed input the privacy case is stated
/// at and the witness the second capture bundle carries.
#[test]
fn the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_p2() {
    let sh = Shape::rung_p2();
    let (public, ff, _) = super::grow_tests::tame_case(&sh);
    let input = vec![0i16; sh.tokens * sh.width];
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-P2 all-zero witness");
    let blk = BlockPublic::new(public, ff);
    let (expected, receipt, bytes) = prove_p2(&sh, &blk, w).expect("the rung-P2 all-zero prover");
    assert_eq!(bytes.len(), P2_FRAME_BYTES, "a receipt's length is a function of the shape alone");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the all-zero receipt verifies in typed form");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the all-zero receipt verifies from bytes");
    eprintln!("rung-P2 ALL-ZERO (degenerate) one block: frame {} B, verified", bytes.len());
}

// ---------------------------------------------------------------- the negative controls

/// **A TAMPER INSIDE AN UNPADDED DOMAIN IS REJECTED BY THE VERIFIER, AT THE
/// SLOT UNDER TEST.**
///
/// This is the control the unpadded arm needs and the padded one cannot
/// give. In each of the three domains that do not pad here, the tamper is
/// placed twice:
///
/// * at the **LAST index of the domain** — the position that at rung-K4, at
///   rung-G and at the rung is a PAD ROW, where ruling P-1's term forces a
///   zero and where the gate `(1 - supp)` switches the inhomogeneous clauses
///   off. Here there is no pad row and no gate, so the ORDINARY relation of
///   the slot has to catch it;
/// * at **index 0**, so that the case is not about the end of a cube.
///
/// The plane in each domain is chosen so that the first slot whose relation
/// the tamper breaks IS that domain's own zero-check: `A_DSQ` is read by
/// `SC_TZC` alone, `A_K8` by `SC_KVZC` and the key matmul it hosts, `A_G8`
/// by `SC_FZC` and the gate matmul it hosts. The message is asserted to name
/// that slot, so a rejection by an EARLIER check does not pass for one.
///
/// The honest control is asserted accepted first, or none of it is a
/// statement, and a refusal by the PROVER would not be one either.
#[test]
fn a_tamper_inside_an_unpadded_domain_is_rejected_at_that_domains_zero_check_at_the_rung_p2() {
    let sh = Shape::rung_p2();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-P2 dense honest witness");
    let ids = Ids::new(&sh).expect("the rung-P2 plane map");
    let blk = BlockPublic::new(public, ff);
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest rung-P2 witness is not accepted");
    let cases: [(&str, Dom, usize, usize); 3] = [
        ("Dom::T, the norm square A_DSQ", Dom::T, ids.at(A_DSQ), SC_TZC),
        ("Dom::Kv, the key A_K8", Dom::Kv, ids.at(A_K8), SC_KVZC),
        ("Dom::F, the gate A_G8", Dom::F, ids.at(A_G8), SC_FZC),
    ];
    let mut rejected = 0usize;
    for (what, dom, plane, slot) in cases {
        assert!(!sh.pads(dom), "{what}: {dom:?} pads, so this case is not about the unpadded arm");
        let last = sh.size(dom) - 1;
        for (where_, at) in [("the LAST index of the domain", last), ("index 0", 0usize)] {
            let mut w = clone_witness(&base);
            w.planes[plane][at] += 1;
            let o = outcome(&sh, &blk, w);
            eprintln!("P2 UNPADDED TAMPER {what} at {where_} ({at}): {}", o.short());
            match o {
                Outcome::Accepted => panic!("{what} at {where_} was ACCEPTED at rung-P2"),
                Outcome::ProverRefused(e) => panic!("{what} at {where_} was refused by the PROVER, which is not a soundness statement: {e}"),
                Outcome::VerifierRejected(e) => {
                    assert!(e.contains(&format!("slot {slot} [{}]", SLOT_NAMES[slot])), "{what} at {where_} was rejected, but not by slot {slot} [{}]: {e}", SLOT_NAMES[slot]);
                    rejected += 1;
                }
            }
        }
    }
    assert_eq!(rejected, 6, "not every tamper was exercised");
    eprintln!("P2 UNPADDED TAMPER SWEEP: 6 of 6 rejected by the VERIFIER, each at its own domain's zero-check, 0 by the prover, 0 accepted");
}

/// **A ROUND MESSAGE OF AN UNPADDED ZERO-CHECK CANNOT BE FORGED**, the
/// ordinary control on the two slots whose schedule this stage moves: one
/// value of one round message of slot 16 and of slot 18 is changed, and the
/// verifier rejects at that slot.
#[test]
fn a_tampered_round_message_of_an_unpadded_zero_check_is_rejected_at_the_rung_p2() {
    let sh = Shape::rung_p2();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-P2 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let (expected, receipt, bytes) = prove_p2(&sh, &blk, w).expect("the rung-P2 dense prover");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest control verifies");
    for slot in [SC_KVZC, SC_FZC] {
        let mut r = Receipt::from_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest frame parses");
        r.slots[slot].sc.rounds[0][1] = r.slots[slot].sc.rounds[0][1].add(Fp2::ONE);
        let e = verify_inner_at(&sh, &blk, &expected, &r).expect_err("a tampered round message was accepted");
        eprintln!("P2 ROUND-MESSAGE TAMPER slot {slot} [{}]: {e}", SLOT_NAMES[slot]);
        assert!(e.contains(&format!("slot {slot} [{}]", SLOT_NAMES[slot])), "the rejection does not name slot {slot}: {e}");
    }
    let _ = receipt;
}

/// **A PROOF SHAPED AS IF THE DOMAIN PADDED IS REFUSED BY THE FRAME CHECK,
/// NOT MIS-PARSED.**
///
/// A prover that believed `Dom::Kv` or `Dom::F` padded here — which is
/// exactly the mistake the Python gate's port made (finding M-F1) — would
/// declare that slot one degree higher and publish `degree + 1 = 6` values
/// per round instead of 5. The production prover cannot be made to do that
/// without editing production code, so the statement is made on the FRAME,
/// which is where the task's fallback puts it: a receipt whose slot 16 (or
/// 18) carries PADDED-STYLE round messages is refused by
/// `wire::validate` — the per-slot schedule check `verify_inner_at` runs
/// before it draws a single challenge — and the refusal is
/// `"private block wire: argument shape"`, a shape refusal and not a
/// mis-parse.
///
/// Three things are asserted, and the first two are what make the third a
/// statement about THIS slot:
///
/// * the honest receipt passes the same check, so the refusal is caused by
///   the edit;
/// * the ONLY edit is that slot's round messages — every other field of the
///   receipt is the honest one, byte for byte, because the receipt is parsed
///   from the honest frame and one field is changed;
/// * the padded-style object never reaches the transcript: the refusal
///   arrives from the frame check, so it cannot be confused with a
///   sumcheck-level rejection, and the same receipt cannot be re-encoded
///   into a frame of the honest length either.
///
/// The counted lengths say the same thing arithmetically: this shape's frame
/// is 4,742,728 B and the all-padded rung-K4's is 4,743,128 B, so a
/// padded-style proof is 400 B longer than anything this profile will read.
#[test]
fn a_padded_style_round_message_at_an_unpadded_slot_is_refused_by_the_frame_check_at_the_rung_p2() {
    let sh = Shape::rung_p2();
    let k4 = Shape::rung_k4();
    let lay = Layout::for_shape(&sh).expect("the rung-P2 layout");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-P2 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let (expected, _receipt, bytes) = prove_p2(&sh, &blk, w).expect("the rung-P2 dense prover");
    let honest = Receipt::from_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest frame parses");
    super::wire::validate(&honest, &lay).expect("the honest frame passes the schedule check");
    for slot in [SC_KVZC, SC_FZC] {
        let (main, ext, degree) = sh.slots()[slot];
        assert_eq!(degree + 1, k4.slots()[slot].2, "slot {slot} is not one degree below the all-padded shape's");
        let mut r = Receipt::from_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest frame parses");
        assert_eq!(r.slots[slot].sc.rounds.len(), main + ext, "slot {slot}'s round count");
        assert!(r.slots[slot].sc.rounds.iter().all(|m| m.len() == degree + 1), "slot {slot}'s honest round messages are not degree {degree}");
        // the padded-style message: one more evaluation in every round, the
        // shape a slot of degree `degree + 1` publishes
        for m in r.slots[slot].sc.rounds.iter_mut() {
            m.push(Fp2::ZERO);
        }
        let ev = super::wire::validate(&r, &lay).expect_err("a padded-style frame passed the schedule check");
        assert_eq!(ev, "private block wire: argument shape", "the frame check refused for another reason: {ev}");
        let e = verify_inner_at(&sh, &blk, &expected, &r).expect_err("a padded-style proof was accepted at an unpadded slot");
        eprintln!("P2 PADDED-STYLE FRAME slot {slot} [{}]: refused by the frame check — {e}", SLOT_NAMES[slot]);
        assert_eq!(e, ev, "the verifier's refusal is not the frame check's");
        // and in bytes: the codec prices every slot from the schedule, so a
        // padded-style frame is never the honest length
        match r.to_bytes_at(&sh, &blk, &expected) {
            Err(e) => eprintln!("P2 PADDED-STYLE FRAME slot {slot}: the encoder refuses it: {e}"),
            Ok(b) => {
                assert_ne!(b.len(), bytes.len(), "a padded-style frame encodes to the honest length");
                let e = verify_bytes_at(&sh, &blk, &expected, &b).expect_err("a padded-style frame was accepted from bytes");
                eprintln!("P2 PADDED-STYLE FRAME slot {slot}: {} B against the honest {} B, refused from bytes: {e}", b.len(), bytes.len());
            }
        }
    }
    assert_eq!(k4.receipt_bytes().total - sh.receipt_bytes().total, 400, "the all-padded frame is not 400 B longer");
}

// ---------------------------------------------------------------- a three-block run

/// The honest chain of `l` rung-P2 blocks: each block's hidden output is the
/// next one's hidden input, and none of it is published.
pub(super) struct P2Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl P2Chain {
    pub(super) fn build(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> P2Chain {
        let ids = Ids::new(sh).expect("the rung-P2 plane map");
        let (mut inputs, mut planes) = (Vec::with_capacity(l), Vec::with_capacity(l + 1));
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness of the rung-P2 chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().expect("the block's hidden output"));
        }
        P2Chain { sh: sh.clone(), public, ff, inputs, planes }
    }
}

impl RunWitnessSource for P2Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

/// the run statement and the two EXTERNAL endpoint owners of a rung-P2 chain
pub(super) fn p2_statement_of(c: &P2Chain, l: usize, blocks: &[BlockPublic]) -> (RunStatement, Endpoints) {
    let rs = RunShape::rung_p2(l).expect("the rung-P2 run shape");
    let spec = IoSpec::new_shaped(&c.sh, p2_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &c.planes[0], &c.planes[l]).expect("the run's external endpoint owners");
    let st = RunStatement::new(rs, p2_context(), expected, blocks, &vec![(0, 0); l]).expect("the rung-P2 run statement");
    (st, owners)
}

/// the fully dense rung-P2 chain of `l` blocks and its `l` public statements
pub(super) fn p2_dense_chain(l: usize) -> (P2Chain, Vec<BlockPublic>) {
    let sh = Shape::rung_p2();
    let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
    let blocks = (0..l).map(|_| BlockPublic::new(public.clone(), ff.clone())).collect();
    (P2Chain::build(&sh, l, public, ff, x0), blocks)
}

/// **AN HONEST THREE-BLOCK FULLY DENSE rung-P2 RUN VERIFIES FROM ITS
/// SEGMENTS.** Three blocks under one transcript, each block's hidden output
/// the next one's hidden input and neither published, at a shape three of
/// whose domains do not pad — so the run layer's boundary rows and the
/// unpadded arm of the pad rule are exercised together, which is the
/// combination only an `#[ignore]`d 125M run reached before. The segment
/// lengths are the counted ones, byte for byte, and every block's census is
/// asserted.
#[test]
fn an_honest_three_block_fully_dense_run_verifies_from_its_segments_at_the_rung_p2() {
    let sh = Shape::rung_p2();
    let ids = Ids::new(&sh).expect("plane map");
    let (mut c, blocks) = p2_dense_chain(3);
    for k in 0..3 {
        let w = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[k]).expect("a fully dense witness of the chain");
        assert_non_trivial(&sh, &ids, &w, &format!("run block {k}"));
    }
    let (st, owners) = p2_statement_of(&c, 3, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let t0 = std::time::Instant::now();
    let stats = run::prove_run(&st, &blocks, &mut c, owners, &mut |k, b| {
        assert_eq!(k, segs.len(), "the sink was handed the segments out of order");
        segs.push(b);
        Ok(())
    })
    .expect("the honest three-block fully dense rung-P2 run proves");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(stats.segment_bytes, super::run_tests::counted_segment_bytes(&sh, 3, rows), "a rung-P2 segment is not the counted length");
    let t1 = std::time::Instant::now();
    run::verify_run(&st, &blocks, &segs).expect("the honest three-block fully dense rung-P2 run verifies from its segments");
    eprintln!(
        "P2 FULLY DENSE RUN L=3 (down band {}): prove {prove_s:.2} s, verify from segments {:.2} s, segments {:?} B (total {} B), boundary {rows} rows",
        super::dense_tests::band_down_run(&sh),
        t1.elapsed().as_secs_f64(),
        stats.segment_bytes,
        stats.segment_bytes.iter().sum::<usize>()
    );
}

// ---------------------------------------------------------------- the verifier's own draws

/// How many challenges each slot's definition drew, READ OUT OF A CAPTURE
/// OF THE VERIFIER'S OWN TRANSCRIPT. `run_capture` rebuilds the run's
/// transcript from the public statement and replays every operation the
/// verifier performs; `definition_challenges` is the list it recovers by
/// drawing until its own transcript catches the verifier's, and a
/// definition that diverged by one operation would make the capture fail
/// rather than mis-record. So the LENGTH of that list is the verifier's
/// draw count for that slot.
fn capture_draw_counts(stage: &[u8]) -> Vec<usize> {
    let text = String::from_utf8_lossy(stage).into_owned();
    let pat = "\"definition_challenges\":[";
    let mut out = Vec::new();
    let mut rest = text.as_str();
    while let Some(i) = rest.find(pat) {
        let after = &rest[i + pat.len()..];
        let (mut depth, mut n, mut end) = (0usize, 0usize, after.len());
        for (j, ch) in after.char_indices() {
            match ch {
                '[' => {
                    if depth == 0 {
                        n += 1;
                    }
                    depth += 1;
                }
                ']' => {
                    if depth == 0 {
                        end = j;
                        break;
                    }
                    depth -= 1;
                }
                _ => {}
            }
        }
        out.push(n);
        rest = &after[end..];
    }
    out
}

/// **THE VERIFIER'S DRAWS ARE THE PROVER'S**, on a real two-block rung-P2
/// run and not on a definition walk: the run is PROVED with the production
/// prover and VERIFIED with the production verifier under the capture
/// recorder, which rebuilds the transcript independently, and the number of
/// challenges each slot's definition drew is read out of the capture and
/// compared with [`measured_draws`], slot for slot, in every stage.
///
/// This is the half of the draw census the definition walk cannot give. The
/// walk drives `argument::define` directly — the function both sides share
/// — so it says what the SHAPE costs; this says that the object a verifier
/// actually consumes has those counts in it, at the shape where three of
/// them are two lower than every other development shape's.
#[test]
fn the_verifiers_own_draw_census_at_the_rung_p2_is_the_provers() {
    let sh = Shape::rung_p2();
    let l = 2usize;
    let (mut c, blocks) = p2_dense_chain(l);
    let (st, owners) = p2_statement_of(&c, l, &blocks);
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(&st, &blocks, &mut c, owners, &mut |_k, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the honest two-block rung-P2 run proves");
    let bundle = {
        let guard = super::run_capture::Recorder::attach();
        super::run_capture::begin_run_with(
            st.capture_header().expect("the capture header"),
            st.binding().expect("the run binding"),
            super::run_capture::CaptureOpts { arrays: false, public_tables: false },
        );
        run::verify_run(&st, &blocks, &segs).expect("the honest two-block rung-P2 run verifies");
        let b = super::run_capture::take().expect("a bundle for an accepted run");
        drop(guard);
        b
    };
    let want = measured_draws(&sh);
    assert_eq!(bundle.stages.len(), l, "the capture does not carry one stage per block");
    for (k, stage) in bundle.stages.iter().enumerate() {
        let got = capture_draw_counts(stage);
        assert_eq!(got.len(), N_SLOTS, "stage {k} does not carry twenty-three slot transcripts");
        assert_eq!(got, want.to_vec(), "stage {k}: the verifier's definition draws are not the prover's");
    }
    for slot in host_slots() {
        eprintln!("S30 VERIFIER DRAW CENSUS slot {slot:02} [{:<28}] {:>3} challenges in every stage of the run", SLOT_NAMES[slot], want[slot]);
    }
    eprintln!("S30 VERIFIER DRAW CENSUS: {l} of {l} stages agree with the definition walk on all {N_SLOTS} slots");
}

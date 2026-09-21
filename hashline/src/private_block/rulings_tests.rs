//! **STAGE 9: THE SECURITY OWNER'S RULINGS on the independent review's nine
//! findings**, one test per ruling that can carry one.
//!
//! The review (`docs/zkmatrix-poc/ZK60_BLOCK125M_RUNG_CODE_REVIEW.md`) found
//! no hole and nine weaknesses. Four of them are defences that a release build
//! does not actually take (F-1, F-2, F-6), a coverage gap the only rung fixture
//! made unwritable (F-3), and an arm of ruling P-1 that no witness edit can
//! reach (F-4). This module is where each ruling is decided by a test rather
//! than by an argument.
//!
//! Nothing here is a privacy statement and nothing here is an acceptance. No
//! witness value, salt or private plane is printed beyond the plane INDEX a
//! case perturbs. The rung profiles are development grade (ruling P-7).

use super::layout::*;
use super::review_tests::{clone_witness, distinct_kv_case, outcome, Outcome};
use super::shape::Shape;
use super::witness;
use super::*;

// ------------------------------------------------------------------- F-1
//
// THE INDICATOR THAT DOES NOT TILE ITS SLOT'S CUBE. `argument.rs`'s guard was
// a `debug_assert_eq!`, and `hashline/Cargo.toml`'s release profile sets no
// `debug-assertions` — release is the only profile the rung and the 125M shape
// are ever built in. A non-tiling indicator would then give the PROVER AND THE
// VERIFIER the same wrong `(1 - supp)`, and the proof would verify while
// meaning something else.
//
// The ruling: it is a refusal by name, taken by `argument::tile_rep` on the
// shared path that both sides build their tables on. No shape reachable
// through `Shape::new` can produce a non-tiling pair (every axis is a power of
// two and every cube contains its domain), which is exactly why the check
// could not be tested end to end and why it has to be tested here.

/// **RULING ON F-1.** The tiling rule is a real refusal in a RELEASE build.
#[test]
fn a_non_tiling_indicator_is_refused_and_not_merely_debug_asserted() {
    eprintln!("F-1: this test runs with debug_assertions = {} (the filter runs --release, where it is false)", cfg!(debug_assertions));
    // the honest cases, including the coarser-domain repetition `supp` exists for
    for (t_len, cube, want) in [(8usize, 8usize, 1usize), (8, 64, 8), (256, 1024, 4), (1, 4096, 4096)] {
        assert_eq!(super::argument::tile_rep(t_len, cube).expect("an indicator that tiles"), want, "the repetition count of {t_len} in {cube}");
    }
    // the three ways it can fail to tile: a non-divisor, a table LONGER than
    // the cube (which used to give `rep = 0` and a divide-by-zero panic), and
    // an empty table
    for (t_len, cube) in [(3usize, 8usize), (6, 64), (16, 8), (1024, 256), (0, 64), (8, 0)] {
        let e = super::argument::tile_rep(t_len, cube).expect_err("a non-tiling indicator was accepted");
        assert!(e.contains("does not tile its slot's cube"), "the refusal does not name the fault: {e}");
        eprintln!("F-1: {t_len} entries in a cube of {cube}: {e}");
    }
}

// ------------------------------------------------------------------- F-2
//
// `SC_TAB` batched its three `Dom::Tab` `A` planes by the hard-coded table
// indices `[1, 4, 7]` and, alone among the pad-zero groups, never checked them
// against what `pad.rs` declares. A fourth `Dom::Tab` `A` plane would have sat
// silently outside the term. The ruling: both lists are checked, by
// `argument::tab_group_is_declared`, which a test can also call with a list
// that does not match.

/// **RULING ON F-2.** The declared lists are checked, and every way of getting
/// them wrong is refused by name.
#[test]
fn sc_tabs_pad_zero_group_is_checked_against_the_declared_lists() {
    for shape in [Shape::rung(), Shape::rung_g(), Shape::m125()] {
        let lay = Layout::for_shape(&shape).expect("the layout");
        let ids = lay.ids();
        let th = lay.hids().table_helpers();
        let a = vec![ids.at(A_MU8), ids.at(A_MEXP), ids.at(A_MACT)];
        super::argument::tab_group_is_declared(&shape, ids, &a, &th).expect("the honest group is the declared one");
        // a plane missing, a fourth plane, a permuted order, and a wrong helper list
        let mut four = a.clone();
        four.push(ids.at(A_X));
        let mut perm = a.clone();
        perm.swap(0, 2);
        for (label, list) in [("a plane missing", a[..2].to_vec()), ("a fourth plane", four), ("a permuted order", perm)] {
            let e = super::argument::tab_group_is_declared(&shape, ids, &list, &th).expect_err("an undeclared A group was accepted");
            assert!(e.contains("Dom::Tab multiplicity is outside"), "{}: {e}", shape.name);
            eprintln!("F-2 ({}): {label}: {e}", shape.name);
        }
        let e = super::argument::tab_group_is_declared(&shape, ids, &a, &[th[1], th[0], th[2]]).expect_err("an undeclared helper group was accepted");
        assert!(e.contains("Dom::Tab helper is outside"), "{}: {e}", shape.name);
    }
}

// ------------------------------------------------------------------- F-3
//
// GROUPED-QUERY ATTENTION, THE TWO ACCEPTANCE TAMPERS OF MEMO SECTION 9a. The
// only rung fixture gives every head identical data, so every head-permuting
// tamper on it is a no-op, and both of section 9a's step-S7 acceptance tests
// were unwritable. The review built a fixture whose two key-value groups carry
// different weights and used it for the first of the two ("a tamper that swaps
// two key-value heads is rejected", `review_tests::
// a_query_head_reading_the_other_key_value_head_is_rejected_at_the_rung`). This
// is the second: the QUERY side of the same permutation, which section 9a
// words as "a tamper that makes one query head read the wrong key-value
// group".
//
// Query heads 0 and 3 sit in DIFFERENT key-value groups (`head_slot` puts the
// group in the high bits of the slot, so at the rung head 0 is slot 0 and head
// 3 is slot 4). Exchanging everything the two head SLOTS own — their `Dom::Q`
// query slices, their `Dom::Ht` row quantities and their `Dom::S` score cubes —
// leaves every relation that is internal to a head holding position by
// position, and breaks exactly one thing: slot 0's scores are now the ones
// computed against key-value group 1's keys, and slot 4's against group 0's.

/// **RULING ON F-3, and memo section 9a's second acceptance tamper.**
#[test]
fn two_query_heads_of_different_key_value_groups_exchanged_is_rejected_at_the_rung() {
    let sh = Shape::rung();
    assert_eq!((sh.q_heads, sh.kv_heads), (6, 2), "this case is written for the rung's six heads over two groups");
    let (slot_a, slot_b) = (sh.head_slot(0), sh.head_slot(3));
    assert_ne!(slot_a >> sh.log_slots_per_kv_group(), slot_b >> sh.log_slots_per_kv_group(), "heads 0 and 3 must sit in different key-value groups");
    let (blk, input) = distinct_kv_case(&sh);
    let base = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the distinct-KV honest witness");
    let o = outcome(&sh, &blk, clone_witness(&base));
    assert!(o.is_accepted(), "the distinct-KV honest witness does not prove: {}", o.short());
    let ids = Ids::new(&sh).expect("the rung has a plane map");
    // every A plane that carries a head-slot axis, and the stride of that axis
    // in its flat index (`pad::closed_form_indicator`'s own axis table)
    let per_slot = |dom: Dom| -> usize {
        match dom {
            Dom::Q => sh.head_dim,
            Dom::Ht => sh.t_pad,
            Dom::S => sh.t_pad * sh.t_pad,
            _ => 0,
        }
    };
    let mut moved = 0usize;
    let mut w = clone_witness(&base);
    let mut touched = 0usize;
    for p in 0..ids.n_a() {
        let dom = ids.dom(p);
        let stride = per_slot(dom);
        if stride == 0 || ids.is_multiplicity(p) {
            continue;
        }
        touched += 1;
        // `Dom::Q` is `(t, slot, i')`: the slot axis repeats once per token.
        // `Dom::Ht` and `Dom::S` are slot-major, so there is one block each.
        assert_eq!(w.planes[p].len() % (stride * sh.h_pad), 0, "plane {p} on {dom:?} is not a whole number of head-slot blocks");
        let outer = w.planes[p].len() / (stride * sh.h_pad);
        for o in 0..outer {
            for i in 0..stride {
                let (x, y) = (o * stride * sh.h_pad + slot_a * stride + i, o * stride * sh.h_pad + slot_b * stride + i);
                if w.planes[p][x] != w.planes[p][y] {
                    moved += 1;
                }
                w.planes[p].swap(x, y);
            }
        }
    }
    assert!(touched >= 3, "the exchange reached only {touched} head-slot planes");
    assert!(moved > 0, "the two query head slots carry identical data: the exchange is a no-op and this test says nothing");
    let o = outcome(&sh, &blk, w);
    eprintln!("GQA: query head slots {slot_a} and {slot_b} exchanged across {touched} planes ({moved} positions differ): {}", o.short());
    assert!(!o.is_accepted(), "a witness whose query heads were exchanged across key-value groups was ACCEPTED");
    assert!(matches!(o, Outcome::VerifierRejected(_)), "the query-head exchange was caught only by the prover: {}", o.short());
}

// ------------------------------------------------------------------- F-4
//
// THE `Dom::Tab` PAD TERM, THE ONE ARM NO WITNESS EDIT CAN REACH. Its six
// planes are derived by the prover, so the review could not decide it end to
// end. `protocol::set_moved_multiplicity` is the `#[cfg(test)]` hook that
// closes it, and it closes the moved-multiplicity tamper family with it: one
// count moves from a true table row to the PADDED COPY of that same row, and
// the table helper that position needs is written too. The total multiplicity,
// the value counted and every LogUp denominator are unchanged, so the value-0
// identity and all three `SC_TAB` product relations still hold. The pad-zero
// term is the only thing left that can object — and it must.

/// **RULING ON F-4.** The `Dom::Tab` pad-zero term is exercised end to end.
#[test]
fn a_multiplicity_moved_into_the_padded_copy_of_its_row_is_rejected_at_the_rung() {
    let sh = Shape::rung();
    assert!(sh.size(Dom::Tab) > 256, "the rung's Dom::Tab is lifted, so it has padded rows");
    let (public, ff, input) = super::grow_tests::tame_case(&sh);
    let blk = BlockPublic::new(public, ff);
    // the byte histogram (0) is the only one certain to have a count on the
    // row this case moves; the other two are named for the record
    for (which, what) in [(0usize, "the byte histogram")] {
        let w = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the rung's honest witness");
        let row = 0usize;
        super::protocol::set_moved_multiplicity(Some((which, row, row + 256)));
        let o = outcome(&sh, &blk, w);
        super::protocol::set_moved_multiplicity(None);
        eprintln!("F-4: one count of {what} moved from row {row} to its padded copy {}: {}", row + 256, o.short());
        assert!(!o.is_accepted(), "a multiplicity moved into a padded table row was ACCEPTED");
        assert!(matches!(o, Outcome::VerifierRejected(_)), "the moved multiplicity was caught only by the prover: {}", o.short());
    }
    // and the hook, left clear, changes nothing: the honest proof still verifies
    let w = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the rung's honest witness");
    let o = outcome(&sh, &blk, w);
    assert!(o.is_accepted(), "the hook left a trace behind it: {}", o.short());
}

// ------------------------------------------------------------------- F-9
//
// Memo section 3.7a's open question 4 — "a future padded endpoint … the seam
// then has to say which positions it binds" — is live at both rung profiles,
// because both endpoints commit the PADDED `Dom::D` cube. The answer, stated
// in the ledger and pinned here: `SC_IO_IN` / `SC_IO_OUT` bind the WHOLE
// padded cube to `A_X` / `A_X2`, whose pads are ZERO-rule planes, so the
// endpoint's pad is proved zero transitively. The generalised endpoint of
// `endpoint_g.rs` keeps that property because it commits the same padded cube
// (`rows = t_pad`, `cols = d_pad`), and this test is what would notice if a
// later endpoint bound only the true plane.

/// **RULING ON F-9.** At BOTH rung profiles the endpoint statement covers the
/// padded cube, and the padded positions of the two endpoint planes are
/// ZERO-rule.
#[test]
fn the_endpoint_binds_the_padded_cube_at_both_rung_profiles() {
    for shape in [Shape::rung(), Shape::rung_g(), Shape::m125()] {
        let lay = Layout::for_shape(&shape).expect("the layout");
        let ids = lay.ids();
        let spec = IoSpec::new_shaped(&shape, *blake3::hash(b"private block: F-9, the endpoint's padded cube").as_bytes(), 0, 0).expect("the endpoint spec");
        assert_eq!(spec.plane_len(), shape.t_pad * shape.d_pad, "{}: the endpoint does not bind the padded Dom::D cube", shape.name);
        assert_eq!(spec.plane_len(), shape.size(Dom::D), "{}: the endpoint plane is not the Dom::D cube SC_IO_IN claims", shape.name);
        let zero = super::pad::zero_rule_a_planes(&shape, ids, Dom::D);
        for p in [ids.at(A_X), ids.at(A_X2)] {
            assert!(!shape.carries_pad_rule() || zero.contains(&p), "{}: endpoint plane {p} is not ZERO-rule, so the endpoint's pad is not proved zero", shape.name);
        }
        eprintln!("F-9 ({}): the endpoint binds {} words, the whole padded Dom::D cube, and both endpoint planes are ZERO-rule", shape.name, spec.plane_len());
    }
}

// ------------------------------------------- the ruling on stage 8's S11b-F4
//
// THE ENDPOINT'S COMMITMENT PARAMETERS GO INTO THE TRANSCRIPT'S PARAMETER LINE.
// They were bound only through the endpoint digest, which a reader of a
// receipt cannot unfold. The toy's line is frozen and gains nothing; every
// NEW profile states row width, inverse rate, pad count and row count.
//
// One consequence worth naming: before this ruling the rung and the rung-G
// profiles — the same geometry on two different endpoint constructions — had
// the SAME parameter line, and were separated only by their profile strings.

/// **RULING ON S11b-F4.**
#[test]
fn every_new_profile_states_its_endpoint_parameters_in_the_parameter_line() {
    let toy = super::protocol::parameter_line(&Shape::toy());
    assert_eq!(toy, "T32/d16/f16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript", "the toy's line is the frozen literal");
    assert!(!toy.contains("endpoint-log_n"), "the frozen toy's line must not gain the endpoint clause");
    for sh in [Shape::rung(), Shape::rung_g(), Shape::m125()] {
        let line = super::protocol::parameter_line(&sh);
        let want = format!("/endpoint-log_n{}-rate{}-pad{}-rows{}", sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows);
        assert!(line.ends_with(&want), "{}: the line does not state its endpoint parameters: {line}", sh.name);
        eprintln!("S11b-F4 ({}): {line}", sh.name);
    }
    let (r, g) = (Shape::rung(), Shape::rung_g());
    assert_eq!((r.tokens, r.width, r.log_cols), (g.tokens, g.width, g.log_cols), "the two rung profiles share their geometry");
    assert_ne!(super::protocol::parameter_line(&r), super::protocol::parameter_line(&g), "the two endpoint constructions must now separate their parameter lines");
}

// ------------------------------------------------------ the 125M CONSTRUCTION
//
// Nothing is proved at 125M here and no witness is built. What this decides is
// that the shape now CONSTRUCTS end to end at the definition level: the
// layout, the wire length, the endpoint statement, the NTT gate that used to
// refuse it, and — the part no smaller shape exercises — that the closed-form
// indicators the argument's public factors are built from agree with the
// geometry's own definition at every position of all six padded domains.

/// **ITEM 11 OF STAGE 9: the 125M layout constructs.** Read the figures in the
/// log; they are the layout memo's counted ones.
#[test]
fn the_125m_layout_constructs_and_its_indicators_agree_with_the_definition() {
    let sh = Shape::m125();
    assert_eq!((sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim), (512, 768, 2048, 12, 4, 64), "the 125M shape: 12 query heads of 64 over 4 key-value heads");
    // 1. the NTT gate, which refused this shape until stage 9
    super::protocol::fits_the_ntt_tables(&sh).expect("125M fits the shape-driven NTT tables");
    // 2. the layout and the schedule
    let lay = Layout::for_shape(&sh).expect("the 125M layout");
    assert_eq!(lay.shape().name, sh.name);
    // 3. the wire length: the codec's and the shape's own count must agree
    let r = sh.receipt_bytes();
    // STAGE 20: the pre-repair 40,782,792 plus the COUNTED bilinear delta of
    // the S19-F1 fix (`grow_tests::s20_bilinear_delta`), which is the only
    // part of a 125M frame the repair moves.
    assert_eq!(r.total, super::grow_tests::s20_frame_bytes(&sh, 40_782_792), "the 125M frame's counted length");
    assert_eq!(super::wire::encoded_len(&lay), r.total, "the codec disagrees with the count");
    assert!(r.total <= super::wire::MAX_WIRE_BYTES_ANY, "125M must fit the absolute wire ceiling");
    // 4. the endpoint geometry: the padded Dom::D cube, 32 data rows, 37 rows
    let spec = IoSpec::new_shaped(&sh, *blake3::hash(b"private block: the 125M construction test").as_bytes(), 0, 0).expect("the 125M endpoint spec");
    assert_eq!(spec.plane_len(), 1 << 19, "the 125M endpoint plane is the padded Dom::D cube");
    assert_eq!(sh.endpoint_rows, 37, "32 data rows at row width 2^14 plus five mask rows");
    assert!(sh.endpoint_general, "125M carries the generalised endpoint");
    // 5. THE CLOSED FORMS. `argument::B::supp` builds every public pad factor
    // from `pad::indicator_table`, which takes the CLOSED FORM where one
    // exists; the geometry's own `support_indicator` is the definition. They
    // have never been compared at this shape. Every position of every padded
    // domain, with a deterministic sample printed for the record.
    let mut seed = 0x9E37_79B9_7F4A_7C15u64;
    let mut next = move || {
        seed ^= seed << 13;
        seed ^= seed >> 7;
        seed ^= seed << 17;
        seed
    };
    let padded: Vec<Dom> = ALL_DOMS.into_iter().filter(|d| sh.pads(*d)).collect();
    assert_eq!(padded.len(), 6, "125M's six padded domains (memo section 3.7a)");
    for dom in padded {
        let closed = super::pad::indicator_table(&sh, dom);
        let def = super::pad::support_indicator(&sh, dom);
        assert_eq!(closed.len(), sh.size(dom), "{dom:?}: the closed form is not the domain's length");
        let mut sampled = Vec::new();
        for _ in 0..8 {
            let x = (next() as usize) % closed.len();
            assert_eq!(closed[x], def[x], "{dom:?}: the closed form and the definition differ at the sampled position {x}");
            sampled.push((x, closed[x]));
        }
        assert!(closed == def, "{dom:?}: the closed form and the definition differ somewhere");
        let true_count: i64 = def.iter().sum();
        eprintln!("125M {dom:?}: {} positions, {true_count} supported, closed form equals the definition everywhere; sampled {sampled:?}", closed.len());
    }
    eprintln!("125M CONSTRUCTS: frame {} B, endpoint {} rows over {} words at 2^{} / rate {}, A rows {}, H rows {}", r.total, sh.endpoint_rows, spec.plane_len(), sh.endpoint_log_n, sh.endpoint_inv_rate, lay.a_rows, lay.h_rows);
}

// ------------------------------------------------- the 125M RUN, PREPARED
//
// ITEM 12 OF STAGE 9. This lane does not run it. The test below is written,
// compiled and `#[ignore]`d, and the lane ledger carries the exact detached
// command line for the orchestrator, with ruling P-6's conditions: one job on
// the box, `flock /tmp/zk-heavy.lock`, a memory ceiling that kills the PROCESS
// rather than the box, a `.done` marker, and the peak resident memory recorded
// beside the wall clock. The layout memo's section 7 models 11.00 GiB peak,
// 9.60 GiB after the S2 buffer drops, which `protocol::prove_inner_at` already
// applies (the witness, `looked`, `deltas` and `act_idx` are moved and dropped
// before the `H` commitment — 711 MB, 789 MB, 33.6 MB and 8.4 MB at this
// shape).
//
// It is an `#[ignore]`d test and not an `examples/` binary for one reason: the
// whole shaped block path — `Shape::m125`, `witness::build_shaped`,
// `prove_inner_at`, `verify_bytes_at`'s shaped form — is `pub(crate)`, and an
// example links against the crate's PUBLIC API only. Making any of it `pub` to
// suit a benchmark would widen the library's surface for no reason.

/// Peak resident memory of this process in MiB, from Linux `VmHWM`. It is a
/// whole-process high-water mark, so it bounds the proof's cost from above.
fn peak_rss_mib() -> f64 {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("VmHWM:")).and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<f64>().ok())))
        .map(|kb| kb / 1024.0)
        .unwrap_or(f64::NAN)
}

/// **STAGE 19: which PUBLIC WEIGHTS the heavy tests use.** The default is the
/// diagonal fixture every earlier stage measured, so nothing that has been
/// measured moves. With `HL_PB_WEIGHTS=dense` the stage-19 DENSE recipe is
/// used instead: every weight entry nonzero, so the hidden units above `d` —
/// the whole upper half of every `Dom::F` plane, which the diagonal fixture
/// leaves identically zero — carry real values. Any other value of the
/// variable is refused by name rather than silently ignored.
///
/// The weight fold is the one phase whose COST this changes: `fold_cols_i8`
/// and `fold_rows_i8` skip zero weights, so every published 125M timing taken
/// on the diagonal fixture has an optimistic weight-fold phase.
pub(super) const WEIGHTS_ENV: &str = "HL_PB_WEIGHTS";

/// **STAGE 19 task 9(b): which HIDDEN INPUT the heavy tests use.** The
/// default is the recipe's own; `HL_PB_INPUT=zero` substitutes the ALL-ZERO
/// hidden input, which is the FIXED INPUT of the privacy case (U-4) and has
/// never been proved at the 125M shape. It is weight-independent — every
/// weight is multiplied by zero — so it is the same witness under either
/// recipe.
pub(super) const INPUT_ENV: &str = "HL_PB_INPUT";

fn heavy_case(sh: &Shape) -> (String, AttentionPublic, FeedForwardPublic, Vec<i16>) {
    let (recipe, p, f, x) = match std::env::var(WEIGHTS_ENV).ok().as_deref() {
        None | Some("") | Some("tame") => {
            let (p, f, x) = super::grow_tests::tame_case(sh);
            ("tame (diagonal, the fixture of every earlier stage)", p, f, x)
        }
        Some("dense-ff") => {
            let (p, f, x) = super::dense_tests::dense_ff_case(sh);
            ("dense-ff (stage 19: DENSE feed-forward words on the fixture's attention words and input — the recipe that PROVES)", p, f, x)
        }
        Some("dense") => {
            let (p, f, x) = super::dense_tests::dense_case(sh);
            ("dense (stage 19: every public weight entry nonzero — EXPECTED TO BE REJECTED by finding S19-F1 until it is fixed)", p, f, x)
        }
        Some(other) => panic!("{WEIGHTS_ENV}={other} is not a weights recipe: use `tame` (the default), `dense-ff` or `dense`"),
    };
    let (label, input) = match std::env::var(INPUT_ENV).ok().as_deref() {
        None | Some("") | Some("fixture") => ("the recipe's own hidden input", x),
        Some("zero") => ("the ALL-ZERO hidden input (the fixed input of the privacy case, U-4)", vec![0i16; sh.tokens * sh.width]),
        Some(other) => panic!("{INPUT_ENV}={other} is not a hidden input: use `fixture` (the default) or `zero`"),
    };
    (format!("weights {recipe}; input {label}"), p, f, input)
}

/// **ONE 125M BLOCK, END TO END.** Built, proved with the generalised
/// endpoint, encoded, and verified FROM BYTES by a fresh verifier call.
/// Development grade (ruling P-7) on public synthetic weights: not a privacy
/// statement, not an acceptance, and no receipt from it is shown to anyone.
///
/// **STAGE 19:** `HL_PB_WEIGHTS=dense` swaps the diagonal fixture for the
/// dense recipe and `HL_PB_INPUT=zero` swaps the hidden input for the
/// all-zero one (task 9(b)). Nothing else about the test moves — the same
/// endpoints, the same counted frame length, the same assertions — because a
/// receipt's length is a function of the shape and of nothing else.
#[test]
#[ignore = "the 125M run: about 11 GiB peak resident and minutes of wall clock. Launch it detached under ruling P-6's conditions with the command line in ZK60_BLOCK125M_LANE_PROGRESS.md; never from a session that is also building."]
fn private_block_125m_one_block() {
    let sh = Shape::m125();
    // **STAGE 11.** With `HL_PB_TIMING=1` the prover and the verifier each
    // print their own phase table — every phase with its seconds, its share of
    // the wall clock, the committed rows or sumcheck cube it covers and the
    // process's resident and peak memory at that moment — then the per-half
    // totals and the attention / feed-forward / rest split the P5 question
    // asks for. With it unset nothing below changes and nothing is printed.
    let clock = super::timing::enabled();
    println!("125M: the phase clock ({}) is {}", super::timing::ENV, if clock { "ON: the PB-TIMING tables below are ONE run on a shared box, a diagnostic and not a receipt" } else { "off" });
    let t_start = std::time::Instant::now();
    let (recipe, public, ff, input) = heavy_case(&sh);
    println!("125M: the case ({WEIGHTS_ENV} / {INPUT_ENV}) is {recipe}");
    let blk = BlockPublic::new(public, ff);
    let w = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the 125M honest witness");
    drop(input);
    let build_s = t_start.elapsed().as_secs_f64();
    println!("125M: witness built in {build_s:.2} s, peak RSS {:.0} MiB", peak_rss_mib());
    // the two caller-fixed endpoints, over the padded Dom::D cube
    let ids = Ids::new(&sh).expect("the 125M plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[p].iter().map(|v| i16::try_from(*v).expect("an endpoint word outside int16")).collect() };
    let (pin, pout) = (plane(ids.at(A_X)), plane(ids.at(A_X2)));
    let spec = IoSpec::new_shaped(&sh, *blake3::hash(b"private block: one 125M block, development grade").as_bytes(), 0, 0).expect("the 125M endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &pin, &pout).expect("the 125M endpoint owners");
    drop(pin);
    drop(pout);
    let t0 = std::time::Instant::now();
    let (receipt, _stats) = super::protocol::prove_inner_at(&sh, &blk, w, &expected, owners).expect("the 125M prover");
    let prove_s = t0.elapsed().as_secs_f64();
    let bytes = receipt.to_bytes_at(&sh, &blk, &expected).expect("the 125M frame encodes");
    drop(receipt);
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the 125M receipt verifies from bytes");
    let verify_s = t1.elapsed().as_secs_f64();
    let peak = peak_rss_mib();
    println!("125M ONE BLOCK: prove {prove_s:.2} s, verify from bytes {verify_s:.2} s, receipt {} B, peak RSS {peak:.0} MiB ({:.2} GiB), witness build {build_s:.2} s", bytes.len(), peak / 1024.0);
    if clock {
        // the anchor the phase tables are read against: `SUM OF PHASES` in
        // each table should reach its own `WALL CLOCK OF THE CALL`, and the
        // prover's wall clock should reach the `prove` figure on the line
        // above (the difference is the recorder's own `/proc` reads)
        println!("125M PHASE TABLES ABOVE: prover wall {prove_s:.2} s, verifier wall {verify_s:.2} s, witness build {build_s:.2} s (NOT inside the prover's table), peak RSS {:.2} GiB", peak / 1024.0);
    }
    assert_eq!(bytes.len(), 40_782_792, "the 125M frame is not the counted length");
    // a truncated frame is refused before anything is parsed
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short 125M frame was accepted");
}

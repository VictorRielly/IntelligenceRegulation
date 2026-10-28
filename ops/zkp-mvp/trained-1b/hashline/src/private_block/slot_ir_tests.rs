//! **LANE STAGE 34 — THE ORACLE TESTS OF THE SLOT EXPRESSION IR.**
//!
//! `slot_ir.rs` writes the twenty-three slot polynomials down as data. The
//! closures of `argument::define` are the ORACLE that says whether it wrote
//! them down correctly, and this module is where the two meet. Every test
//! here is in the ordinary `--lib private_` filter.
//!
//! **How the two are driven side by side without touching `argument.rs`.**
//! Both `define` and `slot_ir::build_slot_ir` draw their challenges from a
//! transcript, in the same order and the same counts. So the harness builds
//! TWO transcripts in the same initial state and walks the slot order once
//! on each: `define` on the first, the IR builder on the second. Nothing else
//! absorbs into either (the harness does not run `run_slot`), so the two stay
//! in lockstep and the IR carries the same challenge VALUES as the closure it
//! is compared against. **If the mirror ever drew a different number of
//! challenges, or drew them in a different order, every later slot's values
//! would diverge and the equality test would fail** — which is why a hand
//! transcription of sixteen arms is safe here, and it is the same device
//! `plane_index.rs` already uses for the push order.
//!
//! **What is NOT claimed.** Nothing here proves or verifies anything: no
//! commitment, no sumcheck of the protocol, no receipt. The tables are built
//! only where a test needs real WORDS (the `FieldKind` oracle and the
//! round-polynomial premise), and the witness behind them is the lane's own
//! dense fixture recipe, never a real one. No witness value is printed.

use super::argument::{build_tables_at, define, Ctx, Points, ProverData, SlotDef, TABLES_PAR_MIN};
use super::layout::*;
use super::shape::Shape;
use super::slot_ir::{build_slot_ir, export_shape, field_kind, FieldKind, IrPoints, SlotIr, TableKind, TableProv, EXPORT_SCHEMA};
use super::witness;
use crate::field::{Fp, Fp2};
use crate::transcript::Transcript;

// ---------------------------------------------------------------- harness

/// every registered shape, in registry order
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()]
}

/// the eight shapes small enough to build every slot's TABLES for — 125M is
/// excluded from those tests and from nothing else (its `Dom::S` cube is 2^22
/// words, so slot 17 alone would be a 1,920 MiB table set)
fn every_small_shape() -> Vec<Shape> {
    every_shape().into_iter().filter(|s| s.name != Shape::m125().name).collect()
}

/// a test-local xorshift, so no test here depends on a production generator
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

/// The definition-time challenges the harness feeds every shape — fixed, and
/// **every one of them with a nonzero imaginary part**, which the older
/// definition sweeps (`s24_tests`, `s20_review_tests`) do not need and this
/// one does.
///
/// In production all five are transcript challenges: `alpha`, `beta` and
/// `gamma` are drawn before `H` is committed and the three tags are
/// `gamma * TAG_*`, so each has an imaginary part with overwhelming
/// probability. A test that passes a BASE-FIELD tag makes
/// `table_values_u8_at(len, g_u8) = k(i % 256) + g_u8` a base-field column,
/// and the twelfth table of finding IR-C1 then becomes invisible to any
/// oracle — the degenerate-fixture pattern again. The values below are the
/// fix, and the `FieldKind` control is what would have caught their absence.
fn ctx_scalars() -> (Fp2, Fp2, Fp2, Fp2, Fp2) {
    let c = |re: u64, im: u64| Fp2::new(Fp::new(re), Fp::new(im));
    (c(7, 1), c(11, 2), c(13, 3), c(17, 5), c(19, 7))
}

/// **THE TWIN WALK.** Build every slot's definition and every slot's IR at
/// `sh`, on two transcripts in the same state, and hand each pair to `f`.
/// Each definition is dropped before the next is built, as `s24_tests` does,
/// because at the big shapes one public table is hundreds of megabytes.
fn walk_pairs(sh: &Shape, mut f: impl FnMut(usize, &SlotDef, &SlotIr)) {
    let lay = Layout::for_shape(sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let (alpha, beta, g_u8, g_exp, g_act) = ctx_scalars();
    let ctx = Ctx { lay: &lay, public: &public, ff: &ff, alpha, beta, g_u8, g_exp, g_act, g_dd: Fp2::ZERO };
    let mut tr_def = Transcript::new(sh.profile.as_bytes());
    let mut tr_ir = Transcript::new(sh.profile.as_bytes());
    let mut pts = Points::default();
    let mut ipts = IrPoints::default();
    for s in 0..N_SLOTS {
        let def = define(s, &ctx, &mut pts, &mut tr_def).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
        let ir = build_slot_ir(s, &ctx, &mut ipts, &mut tr_ir).unwrap_or_else(|e| panic!("{}: slot {s} IR: {e}", sh.name));
        f(s, &def, &ir);
    }
}

/// the IRs alone, for the tests that need no closure
fn every_ir(sh: &Shape) -> Vec<SlotIr> {
    let mut out = Vec::new();
    walk_pairs(sh, |_, _, ir| out.push(ir.clone()));
    out
}

// ---------------------------------------------------------------- (a) the equality

/// **THE ORACLE TEST.** For every registered shape, every slot and many
/// random points, the IR evaluated on a vector of table values equals the
/// closure evaluated on the same vector — the whole of stage 1's claim.
///
/// The values are random field elements and not a real table's words on
/// purpose: a slot polynomial is a polynomial in its tables, so agreeing at
/// random points of the WHOLE space is a far stronger statement than agreeing
/// on the cube of one witness, and by Schwartz–Zippel a single disagreeing
/// coefficient survives with probability at most `deg / |F|` ≈ 2^-125 per
/// point.
///
/// It also reports the two censuses the stage owes: how many tables the IR
/// calls base-field at each shape (ruling I-2's count, against the check's
/// 131 of 229 at 125M and rung-W14), and which slots take the pad branch at
/// which shape — with the assertion that **both branches of every pad-hosting
/// slot are exercised somewhere in the registry**, which is what "both pad
/// branches" can mean when the branch is a property of the shape.
#[test]
fn the_slot_ir_evaluates_to_the_closure_at_every_registered_shape_and_slot() {
    let mut r = xs(0x5107_1234_9ABC_DEF1);
    let mut points = 0usize;
    let mut pairs = 0usize;
    let mut pad_on_at: Vec<Vec<usize>> = Vec::new();
    let mut pad_off_at: Vec<Vec<usize>> = Vec::new();
    for sh in every_shape() {
        let (mut on, mut off) = (Vec::new(), Vec::new());
        let (mut base, mut total) = (0usize, 0usize);
        walk_pairs(&sh, |s, def, ir| {
            assert_eq!(ir.tables.len(), def.tabs.len(), "{}: slot {s} [{}]: the IR has {} tables, the definition {}", sh.name, SLOT_NAMES[s], ir.tables.len(), def.tabs.len());
            for _ in 0..8 {
                let v: Vec<Fp2> = (0..def.tabs.len()).map(|_| fp2_of(&mut r)).collect();
                let want = (def.poly)(&v);
                let got = ir.eval(&v);
                assert_eq!(got, want, "{}: slot {s} [{}]: the IR and the closure differ", sh.name, SLOT_NAMES[s]);
                points += 1;
            }
            pairs += 1;
            base += ir.base_field_tables();
            total += ir.tables.len();
            if super::pad::indicator_tables_per_slot(&sh)[s] > 0 || ir.pad_on {
                on.push(s);
            } else {
                off.push(s);
            }
        });
        eprintln!("S34 equality {}: 23 slots, {total} tables, {base} of them base-field by the IR's derivation", sh.name);
        pad_on_at.push(on);
        pad_off_at.push(off);
    }
    // the pad-hosting slots, and the assertion that the registry covers both
    // arms of each one
    for s in [SC_LZC, SC_TZC, SC_DZC, SC_QZC, SC_SZC, SC_TAB] {
        let on = pad_on_at.iter().filter(|v| v.contains(&s)).count();
        let off = pad_off_at.iter().filter(|v| v.contains(&s)).count();
        eprintln!("S34 pad branches, slot {s:02} [{}]: pad-on at {on} shapes, pad-off at {off} shapes", SLOT_NAMES[s]);
        assert!(on > 0 && off > 0, "slot {s} [{}] is only ever seen on one side of its pad branch: on {on}, off {off}", SLOT_NAMES[s]);
    }
    eprintln!("S34 equality: {pairs} (shape, slot) pairs, {points} random points, every one equal");
    assert_eq!(pairs, 9 * N_SLOTS, "the registry walk did not cover 9 shapes x 23 slots");
}

/// **THE SAME EQUALITY UNDER 1, 2 AND 8 THREADS.** Nothing in the IR
/// builder or in the interpreter is parallel — there is no rayon call in
/// either, and the census below says so by measuring rather than by claiming:
/// the same (shape, slot, point) triples give the same field element at every
/// `RAYON_NUM_THREADS`. The build of a slot's TABLES is parallel above a
/// threshold (`TABLES_PAR_MIN`, stage 29), and that is the one thing a thread
/// count could move here; it is covered by the `FieldKind` oracle below,
/// which builds real tables.
#[test]
fn the_slot_ir_is_thread_count_independent_because_nothing_in_it_is_parallel() {
    let sh = Shape::rung_p2();
    let mut digests: Vec<Vec<Fp2>> = Vec::new();
    for threads in [1usize, 2, 8] {
        let pool = rayon::ThreadPoolBuilder::new().num_threads(threads).build().expect("a rayon pool");
        let out: Vec<Fp2> = pool.install(|| {
            let mut r = xs(0x7317_0001);
            let mut acc = Vec::new();
            walk_pairs(&sh, |_, def, ir| {
                for _ in 0..4 {
                    let v: Vec<Fp2> = (0..def.tabs.len()).map(|_| fp2_of(&mut r)).collect();
                    assert_eq!(ir.eval(&v), (def.poly)(&v), "{} threads: the IR and the closure differ", threads);
                    acc.push(ir.eval(&v));
                }
            });
            acc
        });
        digests.push(out);
    }
    assert_eq!(digests[0], digests[1], "the IR's values moved between 1 and 2 threads");
    assert_eq!(digests[0], digests[2], "the IR's values moved between 1 and 8 threads");
    eprintln!("S34 threads: {} evaluations identical at 1, 2 and 8 threads (no rayon call exists in the IR path)", digests[0].len());
}

// ---------------------------------------------------------------- (b) the degree

/// the degree of `t -> f(v0 + t v1)` by exact forward differences: with
/// `k! != 0` in a field of characteristic `2^64 - 2^32 + 1` and `k <= 8`, the
/// k-th forward difference vanishes exactly when the k-th coefficient does
fn degree_on_a_line(f: &dyn Fn(&[Fp2]) -> Fp2, v0: &[Fp2], v1: &[Fp2], upto: usize) -> usize {
    let mut vals: Vec<Fp2> = Vec::with_capacity(upto + 1);
    for t in 0..=upto {
        let tt = Fp2::from_u64(t as u64);
        let v: Vec<Fp2> = v0.iter().zip(v1.iter()).map(|(a, b)| a.add(tt.mul(*b))).collect();
        vals.push(f(&v));
    }
    let mut deg = 0usize;
    let mut cur = vals;
    for k in 1..=upto {
        cur = cur.windows(2).map(|w| w[1].sub(w[0])).collect();
        if cur.iter().any(|x| !x.is_zero()) {
            deg = k;
        }
    }
    deg
}

/// **THE DECLARED DEGREE BOUNDS THE TRUE ONE, AND WHERE IT IS SLACK.**
///
/// Two things are measured on random lines through the table space, at every
/// registered shape and every slot:
///
/// * the closure's ACTUAL degree never exceeds the DECLARED degree
///   (`Shape::slots`), which is the soundness-relevant direction — the round
///   message carries `degree + 1` values and a higher true degree would not
///   fit;
/// * the IR's computed `max_term_degree` equals the closure's actual degree
///   at every slot and every shape. So the IR is the first artefact in this
///   lane that can state the true degree, which is the memo's §1.4 claim,
///   here measured rather than walked.
///
/// The gap between the two — **the check's finding, recorded as an ASSERTED
/// FACT and changed nowhere** — is that `Shape::slots` adds one to the base
/// degree for every `INDICATOR_SLOT_DOMAIN` slot whose domain pads, and for
/// the LogUp hosts that is conservative: their base degree was already set by
/// the UNGATED LogUp arm. Ruling I-7 excludes lowering it (it moves receipt
/// bytes and needs a new profile).
#[test]
fn the_declared_degree_bounds_the_closures_actual_degree_and_the_ir_computes_it_exactly() {
    let mut r = xs(0xDE_6E_7E_11);
    let mut gaps: Vec<(String, usize, usize, usize)> = Vec::new();
    let mut checked = 0usize;
    for sh in every_shape() {
        walk_pairs(&sh, |s, def, ir| {
            let v0: Vec<Fp2> = (0..def.tabs.len()).map(|_| fp2_of(&mut r)).collect();
            let v1: Vec<Fp2> = (0..def.tabs.len()).map(|_| fp2_of(&mut r)).collect();
            let upto = ir.degree + 2;
            let closure_deg = degree_on_a_line(&|v| (def.poly)(v), &v0, &v1, upto);
            let ir_deg = degree_on_a_line(&|v| ir.eval(v), &v0, &v1, upto);
            assert_eq!(closure_deg, ir_deg, "{}: slot {s} [{}]: the IR's degree on a line is not the closure's", sh.name, SLOT_NAMES[s]);
            assert!(closure_deg <= ir.degree, "{}: slot {s} [{}]: the true degree {closure_deg} EXCEEDS the declared {}", sh.name, SLOT_NAMES[s], ir.degree);
            assert_eq!(ir.max_term_degree(), closure_deg, "{}: slot {s} [{}]: the IR's computed max product degree {} is not the measured degree {closure_deg}", sh.name, SLOT_NAMES[s], ir.max_term_degree());
            if closure_deg < ir.degree {
                gaps.push((sh.name.to_string(), s, ir.degree, closure_deg));
            }
            checked += 1;
        });
    }
    for (name, s, declared, actual) in &gaps {
        eprintln!("S34 degree gap: {name} slot {s:02} [{}] declares {declared}, attains {actual}", SLOT_NAMES[*s]);
    }
    // THE ASSERTED FACT (the check's §8, ruling I-7): a gap appears at exactly
    // the four LogUp-host slots, and only where their own domain pads.
    let want: Vec<(String, usize)> = every_shape()
        .iter()
        .flat_map(|sh| {
            [(SC_DZC, Dom::D), (SC_QZC, Dom::Q), (SC_KVZC, Dom::Kv), (SC_FZC, Dom::F)]
                .into_iter()
                .filter(|(_, d)| sh.carries_pad_rule() && sh.pads(*d))
                .map(|(s, _)| (sh.name.to_string(), s))
                .collect::<Vec<(String, usize)>>()
        })
        .collect();
    let got: Vec<(String, usize)> = gaps.iter().map(|(n, s, _, _)| (n.clone(), *s)).collect();
    assert_eq!(got, want, "the set of (shape, slot) pairs with a declared-degree gap is not the LogUp hosts whose domain pads");
    for (_, _, declared, actual) in &gaps {
        assert_eq!(*declared, *actual + 1, "a declared-degree gap of more than one");
    }
    eprintln!("S34 degree: {checked} (shape, slot) pairs measured by interpolation, {} with a one-degree gap, none exceeding its declared degree", gaps.len());
}

// ---------------------------------------------------------------- (c) the FieldKind oracle

/// the committed data a slot's tables are built from: the honest dense
/// witness written into `A` exactly as `protocol::prove_core` writes it, and
/// a fixed-seed nonzero `Fp` stream everywhere else — the mask rows, the
/// three histograms, every `H` column and the two endpoints.
///
/// **Why the filler is dense and nonzero, and why that makes the oracle
/// stronger rather than weaker.** Committed data is `[Fp]`: base-field words.
/// An imaginary part can therefore only come from the CONSTRUCTION — `eq_cube`
/// of a challenge point, a public payload that carries a challenge, or
/// `priv_table`'s `eqf` weighting and slice coefficients — which is exactly
/// what ruling I-2's rule is about. A zero word can only HIDE a nonzero
/// imaginary part, never create one, so filling everything the witness does
/// not define with nonzero randomness is the sharpest instrument available.
fn prover_data(sh: &Shape, lay: &Layout, honest: bool) -> (Vec<Fp>, Vec<Fp>, Vec<Fp>) {
    let n = lay.n();
    let mut r = xs(0x4157_9E55 ^ (sh.tokens as u64) << 17 ^ sh.width as u64);
    let mut a_data: Vec<Fp> = (0..lay.a_rows * n).map(|_| Fp::new(1 + r() % (crate::field::P - 1))).collect();
    let h_data: Vec<Fp> = (0..lay.h_rows * n).map(|_| Fp::new(1 + r() % (crate::field::P - 1))).collect();
    let io: Vec<Fp> = (0..(1usize << sh.log(Dom::D)).max(n)).map(|_| Fp::new(1 + r() % (crate::field::P - 1))).collect();
    if !honest {
        return (a_data, h_data, io);
    }
    let (public, ff, input) = super::dense_tests::dense_ff_case(sh);
    let wit = witness::build_shaped(sh, &public, &ff, &input).unwrap_or_else(|e| panic!("{}: the dense witness: {e}", sh.name));
    let ids = lay.ids();
    for p in lay.a_planes() {
        if ids.is_multiplicity(p) {
            continue;
        }
        for (i, v) in wit.planes[p].iter().enumerate() {
            a_data[lay.a_off[p] + i] = Fp::from_i64(*v);
        }
    }
    (a_data, h_data, io)
}

/// **RULING I-2's ORACLE (the disposition of finding IR-C1).** At every shape
/// the filter can build tables for, every table the IR calls `Base` really
/// has a zero imaginary part in every word of the table the prover builds —
/// and the count of them is reported per shape, against the check's corrected
/// 131 of 229.
///
/// This is the test whose absence would have let a stage-5 evaluator hand out
/// `Fp` cubes for nine slots' tables and compute a different field element in
/// a migration whose whole claim is that it moves no byte.
#[test]
fn every_table_the_ir_calls_base_field_is_base_field_in_the_tables_the_prover_builds() {
    let mut census: Vec<(&'static str, usize, usize)> = Vec::new();
    for sh in every_small_shape() {
        let lay = Layout::for_shape(&sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
        let (public, ff, _) = super::grow_tests::tame_case(&sh);
        let (alpha, beta, g_u8, g_exp, g_act) = ctx_scalars();
        let (mut base, mut total, mut ext_seen, mut zero_base) = (0usize, 0usize, 0usize, 0usize);
        // PASS 1 the honest dense witness, PASS 2 a dense nonzero stream in
        // every word. The second pass is what makes the first one's silences
        // audible: a table whose data happens to be identically zero on a
        // fixture cannot show an imaginary part it should not have, and the
        // count of those is reported below rather than left implicit (the
        // degenerate-fixture pattern of finding S19-F1).
        for honest in [true, false] {
            let (a_data, h_data, io) = prover_data(&sh, &lay, honest);
            let masks = Vec::new();
            let pd = ProverData { data: [&a_data, &h_data, &io, &io], masks: &masks };
            let ctx = Ctx { lay: &lay, public: &public, ff: &ff, alpha, beta, g_u8, g_exp, g_act, g_dd: Fp2::ZERO };
            let mut tr_def = Transcript::new(sh.profile.as_bytes());
            let mut tr_ir = Transcript::new(sh.profile.as_bytes());
            let mut pts = Points::default();
            let mut ipts = IrPoints::default();
            for s in 0..N_SLOTS {
                let mut def = define(s, &ctx, &mut pts, &mut tr_def).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
                let ir = build_slot_ir(s, &ctx, &mut ipts, &mut tr_ir).unwrap_or_else(|e| panic!("{}: slot {s} IR: {e}", sh.name));
                let n = sh.slots()[s].0;
                let tables = build_tables_at(&mut def.tabs, n, &pd, TABLES_PAR_MIN);
                for (i, (t, tr)) in tables.iter().zip(ir.tables.iter()).enumerate() {
                    match tr.field() {
                        FieldKind::Base => {
                            let bad = t.iter().position(|w| !w.c1.is_zero());
                            assert!(
                                bad.is_none(),
                                "{}: slot {s} [{}] table {i} ({}) is called base-field and word {} of the {} table has a nonzero imaginary part",
                                sh.name,
                                SLOT_NAMES[s],
                                tr.label,
                                bad.unwrap_or(0),
                                if honest { "honest-witness" } else { "dense" }
                            );
                            if honest {
                                base += 1;
                                total += 1;
                                if t.iter().all(|w| w.c0.is_zero() && w.c1.is_zero()) {
                                    zero_base += 1;
                                }
                            }
                        }
                        FieldKind::Extension => {
                            // not an assertion about every word — an `eq` table
                            // takes base values at some points — but a count of
                            // the tables that really do carry an imaginary
                            // part, so the oracle cannot pass by calling
                            // everything `Extension`
                            if honest {
                                total += 1;
                                if t.iter().any(|w| !w.c1.is_zero()) {
                                    ext_seen += 1;
                                }
                            }
                        }
                    }
                }
            }
        }
        eprintln!(
            "S34 field kind {}: {base} of {total} tables base-field on both passes; {ext_seen} of the {} extension tables carry a nonzero imaginary part on the honest witness; {zero_base} base tables are identically zero there",
            sh.name,
            total - base
        );
        census.push((shape_key(&sh), base, total));
    }
    // the shape the design memo and its check are about, at the filter's
    // reach: rung-W14 has 125M's own 229-table census
    let w14 = census.iter().find(|(k, _, _)| *k == "rung_w14").expect("rung-W14 in the census");
    assert_eq!((w14.1, w14.2), (131, 229), "rung-W14's base-field count is not the check's corrected 131 of 229");
}

/// **THE CONTROL THAT MAKES THE ORACLE BITE.** The memo's own classification
/// is written back into the IR at rung-W14 — the U8 value column called
/// base-field (finding IR-C1's twelfth table) and the eleven planes read at a
/// fixed claim point called base-field (its other eleven) — and the oracle
/// must reject every one. Without this, "every table the IR calls Base is
/// base" would pass on an IR that called nothing Base.
///
/// The control runs on the DENSE data pass, where every committed word is
/// nonzero: on a fixture whose plane happens to be identically zero a
/// mislabel is invisible, which is a fact about the fixture and not about the
/// rule, and the oracle above counts those separately.
#[test]
fn the_field_kind_oracle_rejects_the_memos_own_classification_of_the_twelve_tables() {
    let sh = Shape::rung_w14();
    let lay = Layout::for_shape(&sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let (a_data, h_data, io) = prover_data(&sh, &lay, false);
    let masks = Vec::new();
    let pd = ProverData { data: [&a_data, &h_data, &io, &io], masks: &masks };
    let (public, ff, _) = super::grow_tests::tame_case(&sh);
    let (alpha, beta, g_u8, g_exp, g_act) = ctx_scalars();
    let ctx = Ctx { lay: &lay, public: &public, ff: &ff, alpha, beta, g_u8, g_exp, g_act, g_dd: Fp2::ZERO };
    let mut tr_def = Transcript::new(sh.profile.as_bytes());
    let mut tr_ir = Transcript::new(sh.profile.as_bytes());
    let mut pts = Points::default();
    let mut ipts = IrPoints::default();
    let mut caught = 0usize;
    for s in 0..N_SLOTS {
        let mut def = define(s, &ctx, &mut pts, &mut tr_def).unwrap_or_else(|e| panic!("slot {s}: {e}"));
        let mut ir = build_slot_ir(s, &ctx, &mut ipts, &mut tr_ir).unwrap_or_else(|e| panic!("slot {s} IR: {e}"));
        // the memo's classification: an `A` plane is base-field whatever its
        // claim point is, and the U8 value column is a base-field public table
        let mut mislabelled: Vec<usize> = Vec::new();
        for (i, t) in ir.tables.iter_mut().enumerate() {
            let memo_says_base = match &t.prov {
                TableProv::Committed { extension_slice_coef, .. } => !*extension_slice_coef,
                TableProv::PublicWithChallenge(why) => *why == "the U8 tag g_u8",
                _ => false,
            };
            if memo_says_base && field_kind(&t.prov) == FieldKind::Extension {
                t.prov = TableProv::PublicFromShape;
                mislabelled.push(i);
            }
        }
        if mislabelled.is_empty() {
            continue;
        }
        let n = sh.slots()[s].0;
        let tables = build_tables_at(&mut def.tabs, n, &pd, TABLES_PAR_MIN);
        for i in mislabelled {
            assert_eq!(ir.tables[i].field(), FieldKind::Base, "the control did not mislabel table {i} of slot {s}");
            assert!(
                tables[i].iter().any(|w| !w.c1.is_zero()),
                "slot {s} [{}] table {i} ({}) was mislabelled base-field and the oracle would NOT have caught it",
                SLOT_NAMES[s],
                ir.tables[i].label
            );
            caught += 1;
        }
    }
    eprintln!("S34 field-kind control: {caught} tables the memo called base-field are caught by the oracle at rung-W14");
    assert_eq!(caught, 12, "the memo's classification differs from the derived one at {caught} tables, not the check's twelve");
}

// ---------------------------------------------------------------- (e) IR-C19's premise

/// **THE PREMISE OF THE CHECK'S EXTRA LEVER (IR-C19, request R1d), MEASURED
/// ON THE ORACLE SIDE.** `sumcheck::prove` evaluates every round polynomial
/// at `degree + 1` points although the prover already knows the running claim
/// and `s(1) = claim - s(0)`; the check prices the redundant evaluation at
/// 15.8% of the counted baseline. The lever is only valid if the identity
/// really holds at every round of every slot, so this test is that identity,
/// on the honest prover's own round loop transliterated here (no transcript,
/// no mask, a test-local fold challenge): for the unmasked slot polynomial
/// `f`, `s_j(0) + s_j(1) == claim_j` at every round `j`, with `claim_0` the
/// sum over the whole cube and `claim_{j+1} = s_j(r_j)`.
///
/// **What it does and does not cover.** It is a statement about `f`, the
/// polynomial this lane's closures define, and about the shared loop's
/// arithmetic. It says nothing about the MASKED claim: ruling I-3 makes the
/// implementer read `zk::masked_prove` and say whether the claim the prover
/// tracks there is the unmasked one at that point. That is the integrator's
/// half of R1d and this is the lane's.
#[test]
fn the_honest_round_polynomial_satisfies_s0_plus_s1_equals_the_running_claim_at_every_round() {
    let mut rounds_checked = 0usize;
    let mut slots_checked = 0usize;
    for sh in [Shape::toy(), Shape::rung_p2()] {
        let lay = Layout::for_shape(&sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
        let (a_data, h_data, io) = prover_data(&sh, &lay, true);
        let masks = Vec::new();
        let pd = ProverData { data: [&a_data, &h_data, &io, &io], masks: &masks };
        let (public, ff, _) = super::grow_tests::tame_case(&sh);
        let (alpha, beta, g_u8, g_exp, g_act) = ctx_scalars();
        let ctx = Ctx { lay: &lay, public: &public, ff: &ff, alpha, beta, g_u8, g_exp, g_act, g_dd: Fp2::ZERO };
        let mut tr = Transcript::new(sh.profile.as_bytes());
        let mut pts = Points::default();
        let mut r = xs(0xC19_0001);
        for s in 0..N_SLOTS {
            let mut def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
            let (n, _, degree) = sh.slots()[s];
            let mut tables = build_tables_at(&mut def.tabs, n, &pd, TABLES_PAR_MIN);
            let poly = &def.poly;
            // the claim the shared loop starts from: the sum over the cube
            let mut claim = (0..1usize << n).fold(Fp2::ZERO, |a, x| {
                let row: Vec<Fp2> = tables.iter().map(|t| t[x]).collect();
                a.add(poly(&row))
            });
            for _round in 0..n {
                let half = tables[0].len() / 2;
                let mut acc = vec![Fp2::ZERO; degree + 1];
                let k = tables.len();
                let mut cur = vec![Fp2::ZERO; k];
                let mut dif = vec![Fp2::ZERO; k];
                for i in 0..half {
                    for (t, tb) in tables.iter().enumerate() {
                        cur[t] = tb[i];
                        dif[t] = tb[i + half].sub(tb[i]);
                    }
                    acc[0] = acc[0].add(poly(&cur));
                    for d in acc.iter_mut().skip(1) {
                        for (c, df) in cur.iter_mut().zip(dif.iter()) {
                            *c = c.add(*df);
                        }
                        *d = d.add(poly(&cur));
                    }
                }
                assert_eq!(acc[0].add(acc[1]), claim, "{}: slot {s} [{}] round {_round}: s(0) + s(1) is not the running claim", sh.name, SLOT_NAMES[s]);
                rounds_checked += 1;
                // fold at a test-local challenge and carry s(r) as the claim
                let rj = fp2_of(&mut r);
                claim = lagrange_eval(&acc, rj);
                for tb in tables.iter_mut() {
                    for i in 0..half {
                        tb[i] = tb[i].add(rj.mul(tb[i + half].sub(tb[i])));
                    }
                    tb.truncate(half);
                }
            }
            slots_checked += 1;
        }
    }
    eprintln!("S34 IR-C19 premise: s(0) + s(1) == claim at all {rounds_checked} rounds of {slots_checked} (shape, slot) pairs — the redundant evaluation R1d removes is recoverable at every one");
}

/// the value at `x` of the polynomial given by its values at `0 ..= d`
fn lagrange_eval(vals: &[Fp2], x: Fp2) -> Fp2 {
    let d = vals.len();
    let mut out = Fp2::ZERO;
    for (i, v) in vals.iter().enumerate() {
        let mut num = *v;
        for j in 0..d {
            if j == i {
                continue;
            }
            let dj = Fp2::from_u64(j as u64);
            let di = Fp2::from_u64(i as u64);
            num = num.mul(x.sub(dj)).mul(di.sub(dj).inv());
        }
        out = out.add(num);
    }
    out
}

// ---------------------------------------------------------------- (d) the drafter's inventory

/// one row of the drafter's inventory, by the column order of the file's
/// header line
struct InvRow {
    key: String,
    slot: usize,
    tables: usize,
    tables_base_field: usize,
    main_rounds: usize,
    extension_rounds: usize,
    declared_degree: usize,
    terms: usize,
    max_product_degree: usize,
    affine_forms: usize,
    sum_nodes: usize,
    monomials: usize,
}

/// the drafter's per-slot inventory, as this lane keeps it: one line per
/// (shape, slot) with the counts stage 34 can compare. Extracted into the
/// lane's own evidence directory from `results/zk60_slot_ir/slot_ir_counts.json`
/// in the main tree, with that file's SHA-256 in the header.
fn drafter_inventory() -> Vec<InvRow> {
    let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).parent().expect("the crate has a parent").join("results/zk60_block125m_lane/x34-slot-ir/drafter_inventory.tsv");
    let text = std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("the drafter's inventory at {}: {e}", p.display()));
    text.lines()
        .filter(|l| !l.starts_with('#') && !l.trim().is_empty())
        .map(|l| {
            let f: Vec<&str> = l.split('\t').collect();
            let g = |i: usize| f[i].parse::<usize>().unwrap_or_else(|e| panic!("field {i} of {l:?}: {e}"));
            InvRow {
                key: f[0].to_string(),
                slot: g(1),
                tables: g(2),
                tables_base_field: g(3),
                main_rounds: g(4),
                extension_rounds: g(5),
                declared_degree: g(6),
                terms: g(7),
                max_product_degree: g(8),
                affine_forms: g(9),
                sum_nodes: g(10),
                monomials: g(11),
            }
        })
        .collect()
}

/// the registry key the drafter's inventory and the JSON export use for a
/// shape: the constructor's name, which is stable where `Shape::name` is a
/// sentence
fn shape_key(sh: &Shape) -> &'static str {
    const KEYS: [&str; 9] = ["toy", "rung", "rung_g", "rung_k4", "rung_p2", "rung_c6", "rung_w14", "rung_e32", "m125"];
    let i = every_shape().iter().position(|s| s.name == sh.name).unwrap_or_else(|| panic!("{} is not a registered shape", sh.name));
    KEYS[i]
}

/// **THE IR AGAINST THE DRAFTER'S INVENTORY.** The design memo's counting
/// script read `argument.rs` by a third method (a Python transcription of the
/// builder calls and the closure bodies) and produced a per-slot inventory.
/// Where the two disagree, the arm decides — and the disagreements are
/// reported, not hidden.
#[test]
fn the_slot_irs_counts_agree_with_the_drafters_inventory_except_where_the_arm_says_otherwise() {
    let inv = drafter_inventory();
    let mut compared = 0usize;
    let mut field_kind_diffs = 0usize;
    let mut base_short = 0usize;
    let mut graph_diffs: Vec<String> = Vec::new();
    for sh in every_shape() {
        let key = shape_key(&sh);
        for ir in every_ir(&sh) {
            let row = inv.iter().find(|r| r.key == key && r.slot == ir.slot).unwrap_or_else(|| panic!("the inventory has no {key} slot {}", ir.slot));
            assert_eq!(ir.tables.len(), row.tables, "{key} slot {} [{}]: table count", ir.slot, ir.name);
            assert_eq!(ir.main_rounds, row.main_rounds, "{key} slot {} [{}]: main rounds", ir.slot, ir.name);
            assert_eq!(ir.extension_rounds, row.extension_rounds, "{key} slot {} [{}]: extension rounds", ir.slot, ir.name);
            assert_eq!(ir.degree, row.declared_degree, "{key} slot {} [{}]: declared degree", ir.slot, ir.name);
            assert_eq!(ir.terms.len(), row.terms, "{key} slot {} [{}]: top-level term count", ir.slot, ir.name);
            assert_eq!(ir.max_term_degree(), row.max_product_degree, "{key} slot {} [{}]: the IR's max product degree", ir.slot, ir.name);
            // the graph SHAPE is the drafter's own transcription choice, so a
            // difference here is reported and not asserted
            for (what, got, want) in [("affine forms", ir.affine_forms(), row.affine_forms), ("sum nodes", ir.sum_nodes(), row.sum_nodes), ("monomials", ir.monomials(), row.monomials)] {
                if got != want {
                    graph_diffs.push(format!("{key} slot {:02} [{}]: {what} {got} here, {want} in the inventory", ir.slot, ir.name));
                }
            }
            if ir.base_field_tables() != row.tables_base_field {
                field_kind_diffs += 1;
                base_short += row.tables_base_field - ir.base_field_tables();
            }
            compared += 1;
        }
    }
    for d in &graph_diffs {
        eprintln!("S34 inventory graph difference: {d}");
    }
    eprintln!("S34 inventory: {compared} (shape, slot) rows compared; table count, rounds, declared degree, term count and max product degree agree at every one");
    eprintln!("S34 inventory: the base-field count differs at {field_kind_diffs} rows, by {base_short} tables in all — the drafter's column is the MEMO's classification, which ruling I-2 corrects (finding IR-C1)");
    assert!(field_kind_diffs > 0, "the drafter's base-field column agrees everywhere, which would mean finding IR-C1 is not reproduced here");
}

// ---------------------------------------------------------------- stage 1b, the export

/// where the exported IR of each shape is written, and where the drafter's
/// inventory extract lives
fn export_dir() -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR")).parent().expect("the crate has a parent").join("results/zk60_block125m_lane/x34-slot-ir")
}

/// **THE PINNED EXPORT DIGESTS, one per registered shape.** A shape's export
/// is a function of the shape alone — no challenge value, no witness value,
/// no iteration order — so its SHA-256 is a constant of this lane, and a
/// change to the IR that the oracle tests happen not to see still moves one
/// of these.
const EXPORT_DIGESTS: [(&str, &str, usize); 9] = [
    ("toy", "12e7ed013f6ca106232e2f3be87ecce6a82e7382df75c45aabe0a13f358f6bfc", 99_232),
    ("rung", "506d06db2158a16952975a29e5b36d7213761b2ce7fce28ba260d24e8bf774ad", 109_631),
    ("rung_g", "5cb8323a2a6607f38860e6c79ec1ee9b2f37fb4468cd7cf053fb77838f17d496", 109_635),
    ("rung_k4", "e40501335cd10bfe75c04cf49d5b184426472e420658c8c7ade794a17a7f0401", 109_637),
    ("rung_p2", "fa11ed91ecf9662d446d123ee3c7b9ef190e099a8b40b3656ff92ab4ae80d677", 107_276),
    ("rung_c6", "120b116474c7265ebe75bbb122b87e2d5c1db10f068f5c951de2d133d2b4a9ba", 105_384),
    ("rung_w14", "d207b45cae6a43a950cb641c75ad2f8c1c8d3698a4255bc61c973d0a6aa9d3ad", 105_395),
    ("rung_e32", "500aefdcf6655f4c40aeb8a36d9651b51992f8427bd6aa6981eb0bbc031c04a7", 105_393),
    ("m125", "2e8cdb877d4938a63d92dc8f4b054e59ff296456c56063f61c1ad8e39e948d39", 105_382),
];

fn sha256_hex(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    h.update(bytes);
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

/// **STAGE 1b.** The canonical JSON export of every registered shape's
/// twenty-three slot IRs, written into the lane's evidence directory and
/// pinned by digest and by length.
///
/// What the export is FOR (ruling I-8): the independent Python gate reads it
/// as a CROSS-CHECK of its own hand port of the slot schedule. It does not
/// replace the hand port — the hand port is not retired until the gate has
/// predicted, from the shape alone, the draw counts and degrees the export
/// declares, and one hand-ported family stays as an independent check
/// forever. That is how the independence the memo's §6 says is lost is kept.
///
/// What the export deliberately does NOT contain: any coefficient value that
/// depends on a challenge (only its provenance), any witness value, any
/// table payload, any claim point. A challenge is per PROOF and this file is
/// per SHAPE.
#[test]
fn the_slot_ir_export_is_canonical_and_its_digest_is_pinned_at_every_registered_shape() {
    std::fs::create_dir_all(export_dir()).expect("the evidence directory");
    let mut rows: Vec<(String, String, usize)> = Vec::new();
    for sh in every_shape() {
        let key = shape_key(&sh);
        let irs = every_ir(&sh);
        let text = export_shape(key, &irs);
        // canonical: the same bytes when built again from a second walk
        let again = export_shape(key, &every_ir(&sh));
        assert_eq!(text, again, "{key}: the export is not the same on a second walk");
        assert!(text.contains(EXPORT_SCHEMA), "{key}: the export does not name its schema");
        assert!(!text.contains("\"value\":\"0+0u\"") || text.contains("\"prov\":\"kbase:0\""), "{key}: a zero value with no base provenance");
        let digest = sha256_hex(text.as_bytes());
        let path = export_dir().join(format!("slot_ir_{key}.json"));
        std::fs::write(&path, text.as_bytes()).unwrap_or_else(|e| panic!("writing {}: {e}", path.display()));
        eprintln!("S34 export {key}: {} bytes, sha256 {digest}", text.len());
        rows.push((key.to_string(), digest, text.len()));
    }
    // the structural coincidence the memo's §7 rests on, now a byte fact: at
    // rung-W14 and 125M the slot structure is identical, so the two exports
    // differ only in the header (shape key, profile) and the round counts
    let (w14, m125) = (rows.iter().find(|r| r.0 == "rung_w14").unwrap(), rows.iter().find(|r| r.0 == "m125").unwrap());
    assert_ne!(w14.1, m125.1, "rung-W14 and 125M export the same bytes, which cannot be: their round counts differ");
    for (key, digest, len) in &rows {
        let pin = EXPORT_DIGESTS.iter().find(|(k, _, _)| k == key).unwrap_or_else(|| panic!("no pin for {key}"));
        assert_eq!(digest, pin.1, "{key}: the export digest moved (length {len}, pinned length {})", pin.2);
        assert_eq!(*len, pin.2, "{key}: the export length moved");
    }
}

/// **THE S19-F1 REPAIR, STATED AS DATA AND CHECKED AGAINST THE SHAPE.** The
/// two bilinear slots sum over the key-value GROUP, so the group bits are
/// SUMCHECK VARIABLES under a public `eq` over the LEADING variables, not
/// fixed coordinates of both factors. The IR carries that as
/// `group_bits = Some(log2(kv_heads))` and a `GroupEq { bits }` table at
/// `start == 0`, and a reader of the export can check both from the shape
/// alone — which is the whole point of putting it in the export.
///
/// At one key-value head the gate is ABSENT: no table, no degree, no
/// transcript byte, the frozen toy's path byte for byte.
#[test]
fn the_bilinear_slots_carry_the_shapes_key_value_group_bits_and_no_other_slot_does() {
    let mut with_gate = 0usize;
    let mut without = 0usize;
    for sh in every_shape() {
        let lkv = sh.kv_heads.trailing_zeros() as usize;
        for ir in every_ir(&sh) {
            if ir.slot != SC_SCORE && ir.slot != SC_PV {
                assert_eq!(ir.group_bits, None, "{}: slot {} carries group bits", sh.name, ir.slot);
                assert!(!ir.tables.iter().any(|t| matches!(t.kind, TableKind::GroupEq { .. })), "{}: slot {} carries a group gate", sh.name, ir.slot);
                continue;
            }
            assert_eq!(ir.group_bits, Some(lkv), "{}: slot {} does not carry log2(kv_heads)", sh.name, ir.slot);
            let gates: Vec<&TableKind> = ir.tables.iter().map(|t| &t.kind).filter(|k| matches!(k, TableKind::GroupEq { .. })).collect();
            if lkv == 0 {
                assert!(gates.is_empty(), "{}: slot {} has a group gate at one key-value head", sh.name, ir.slot);
                assert_eq!(ir.degree, 2, "{}: slot {} is not degree 2 at one key-value head", sh.name, ir.slot);
                assert_eq!(ir.terms[0].wrapper.len(), 0, "{}: slot {} wraps something at one key-value head", sh.name, ir.slot);
                without += 1;
            } else {
                assert_eq!(gates.len(), 1, "{}: slot {} has {} group gates", sh.name, ir.slot, gates.len());
                assert!(matches!(gates[0], TableKind::GroupEq { bits } if *bits == lkv), "{}: slot {} gate is not over log2(kv_heads) variables", sh.name, ir.slot);
                // the gate is the term's WRAPPER and table 0, so it reads the
                // LEADING variables, where the group sits
                assert_eq!(ir.terms[0].wrapper, vec![0], "{}: slot {} does not wrap its two factors in the group gate", sh.name, ir.slot);
                assert_eq!(ir.degree, 3, "{}: slot {} is not degree 3 with a group gate", sh.name, ir.slot);
                with_gate += 1;
            }
        }
    }
    eprintln!("S34 group bits: {with_gate} bilinear slots with a group gate, {without} without it (one key-value head)");
    assert_eq!((with_gate, without), (16, 2), "the registry does not cover both arms of the group gate");
}

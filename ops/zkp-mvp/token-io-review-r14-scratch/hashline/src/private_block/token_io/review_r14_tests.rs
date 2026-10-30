//! **REVIEW OF TOKEN ROUND 14 (R-C3 short items; the N-r13-1 library binding):
//! the reviewer's own attacks.** TEST CODE ONLY, in the reviewer's scratch copy
//! (`ops/zkp-mvp/token-io-review-r14-scratch`); never part of a frozen tree.
//! Public synthetic data: the relation fixture (the dense trained-calibration
//! rung, a generic embedding, a random margin row, bound by the test-only
//! synthetic binding, as the lane's relation tests) and the CLI fixture `Cc`
//! (the dev rung's DERIVED tables). Each test names the brief's item it covers.
//!
//! S1 boundaries (n = 1, T-P0-S-1, T-P0-S; 0 and T-P0-S+1 refused) · S2 a short
//! receipt re-stated under every other n · S3 forged layouts (n declared != the
//! plane's, pads inside the content range, suffix moved, other ids at pad
//! positions) by the cheating prover and the honest prover · S4 the margin read
//! at other rows · S5 causality IN THE RELATION: a nonzero softmax weight from
//! the verdict row to a pad row · S6 another pad id (control / non-control):
//! bound, and the rows <= the verdict row unchanged · S7 the CLI: truncation
//! against the longer post, label mixes, the four new statement fields and the
//! schema edited · S8 (ignored) receipts across the r12 / r13 / r14 binaries.

use super::classify::*;
use super::classify_cli::{classify_input_owner_command, classify_prove_command, classify_verify_command};
use super::classify_cli_tests::{Cc, POLICY_RUNG_DEV};
use super::classify_run::*;
use super::classify_tied::BoundClassifierTables;
use super::stage_out_c;
use super::tests::{blocks, ctx, generic_tables, lcg, model_at, norm, rung};
use super::*;
use super::super::protocol::CheatingProver;
use super::super::run::{RunShape, RUN_PROFILE_CLASSIFY_RUNG_TC};
use super::super::run_sink;
use super::super::trained_statement::TrainedModelStatement;
use super::super::BlockPublic;
use super::run::VerifierPolicy;
use std::path::{Path, PathBuf};

const L: usize = 2;
const POLICY_93: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 93 };

// ------------------------------------------------------------------ the relation fixture

struct Fx {
    sh: Shape,
    blocks: Vec<BlockPublic>,
    model: TrainedModelStatement,
    tables: ClassifierTables,
    bound: BoundClassifierTables,
    policy: Policy,
}

fn fx_with(policy: Policy) -> Fx {
    let sh = rung();
    let blocks = blocks(&sh, L);
    let model = model_at(&sh, &blocks, RUN_PROFILE_CLASSIFY_RUNG_TC);
    let tt = generic_tables(sh.width, 0x636c_6173);
    let mut s = 0x6d61_7267u64;
    let w: Vec<i16> = (0..sh.width).map(|_| ((lcg(&mut s) % 65_535) as i64 - 32_767) as i16).collect();
    let tables = ClassifierTables::new(tt.v, tt.d, tt.emb.clone(), w).expect("the classifier tables");
    if !registered_policies().contains(&policy) {
        register_test_policy(policy.clone());
    }
    let bound = BoundClassifierTables::synthetic_for_relation_tests(tables.clone(), 1, norm(), &sh, RUN_PROFILE_CLASSIFY_RUNG_TC, &model, &policy).expect("the relation tests' binding");
    Fx { sh, blocks, model, tables, bound, policy }
}

fn size_of(f: &Fx) -> usize {
    f.sh.tokens - f.policy.prefix.len() - f.policy.suffix.len()
}

fn content_n(f: &Fx, n: usize, seed: u64) -> Vec<u64> {
    let mut s = seed;
    (0..n).map(|_| f.policy.num_special + lcg(&mut s) % (f.policy.v as u64 - f.policy.num_special)).collect()
}

fn prof(f: &Fx, n: usize) -> Result<ClassifierProfile, String> {
    ClassifierProfile::new(&f.sh, &f.tables, 1, norm(), &f.policy, n, Tier::R1_MVP)
}

fn stmt(f: &Fx, root: Digest, verdict: u8, n: usize, total: usize, index: usize) -> Result<ClassifyRunStatement, String> {
    ClassifyRunStatement::new_chunk(RunShape::new(f.sh.clone(), L, RUN_PROFILE_CLASSIFY_RUNG_TC)?, ctx(), f.blocks.iter().map(|b| b.digest()).collect(), &f.model, &f.bound, &f.policy, n, Tier::R1_MVP, root, verdict, total, index)
}

fn pipe(f: &Fx, cp: &ClassifierProfile, tokens: &[u64]) -> Result<HonestClassify, String> {
    honest_classify(&vec![f.sh.clone(); L], cp, &f.tables, &f.blocks, tokens)
}

fn pipe_cheat(f: &Fx, cp: &ClassifierProfile, tokens: &[u64]) -> HonestClassify {
    let _c = CheatingProver::on();
    pipe(f, cp, tokens).unwrap_or_else(|e| panic!("the cheating pipeline refused: {e}"))
}

struct Run {
    st: ClassifyRunStatement,
    segs: Vec<Vec<u8>>,
    dec: Decommitment,
}

/// seal the pipeline's plane, the one-chunk statement of an `n`-id item, prove
fn prove_n(f: &Fx, p: &mut HonestClassify, verdict: u8, n: usize) -> Result<Run, String> {
    let cp = prof(f, n)?;
    let spec = input_endpoint_spec(&f.sh, ctx(), &cp)?;
    let (root, owner) = seal_input(&spec, &p.in_plane, &f.sh.hash_tag())?;
    let st = stmt(f, root, verdict, n, n, 0)?;
    let mut segs = Vec::new();
    let (_, dec) = prove_classify_run(&st, &f.blocks, &f.bound, &mut ClassifySource(p), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })?;
    Ok(Run { st, segs, dec })
}

fn verify(f: &Fx, st: &ClassifyRunStatement, segs: &[Vec<u8>]) -> Result<(), String> {
    verify_classify_run(st, &f.blocks, &f.bound, segs, POLICY_93)
}

/// the cheating prover's receipt
fn cheat(f: &Fx, mut p: HonestClassify, verdict: u8, n: usize) -> Run {
    let _c = CheatingProver::on();
    prove_n(f, &mut p, verdict, n).unwrap_or_else(|e| panic!("the cheating prover produced no receipt: {e}"))
}

/// the honest prover handed a forged pipeline: refused, before any header
fn honest_refuses_before_header(f: &Fx, mut p: HonestClassify, verdict: u8, n: usize) -> String {
    let h0 = classify_headers();
    let e = prove_n(f, &mut p, verdict, n).err().expect("THE HONEST PROVER ACCEPTED A FORGED PIPELINE");
    assert_eq!(classify_headers(), h0, "refused only after a header: {e}");
    e
}

/// the item of `content` under the dev template, padded with `pad` to `t`
fn layout(f: &Fx, content: &[u64], pad: u64) -> Vec<u64> {
    let mut v: Vec<u64> = f.policy.prefix.iter().chain(content.iter()).chain(f.policy.suffix.iter()).copied().collect();
    while v.len() < f.sh.tokens {
        v.push(pad);
    }
    v
}

// ------------------------------------------------------------------ S1

/// **S1 (item 3, boundaries).** n = 1, T-P0-S-1 = 22 and T-P0-S = 23 each prove,
/// verify and owner-check, with the layout the statement names (item length
/// P0+n+S, pad positions T-P0-n-S, verdict row P0+n+S-1, the trailing ids the
/// pad id, the verdict row the suffix); n = 0 and n = 24 are refused at the
/// door; a statement whose n is not its derived chunk's length is refused
/// both ways; the opposite verdict is refused; the split at the boundary is
/// one FULL chunk at 23 and two at 24.
#[test]
fn rv14_s1_short_item_boundaries() {
    let f = fx_with(policy_rung_dev());
    let size = size_of(&f);
    assert_eq!(size, 23);
    let p0 = f.policy.prefix.len();
    assert!(prof(&f, 0).is_err(), "n = 0 admitted");
    assert!(prof(&f, size + 1).is_err(), "n = T - P0 - S + 1 admitted");
    let plan = ChunkPlan { size, overlap: chunk_overlap_of(RUN_PROFILE_CLASSIFY_RUNG_TC).unwrap() };
    assert_eq!(chunk_ranges(size, plan).unwrap(), vec![(0, size)]);
    assert_eq!(chunk_ranges(size + 1, plan).unwrap().len(), 2);
    assert!(chunk_ranges(0, plan).is_err());
    for n in [1usize, size - 1, size] {
        let cp = prof(&f, n).unwrap();
        assert_eq!((cp.item_len(), cp.pad_positions(), cp.verdict_row()), (p0 + n + 1, size - n, p0 + n), "n = {n}: the layout");
        let c = content_n(&f, n, 0x7631_0000 + n as u64);
        let toks = cp.tokens_of(&c).unwrap();
        assert_eq!(toks, layout(&f, &c, f.policy.pad));
        assert!(toks[cp.item_len()..].iter().all(|x| *x == f.policy.pad));
        assert_eq!(toks[cp.verdict_row()], f.policy.suffix[0]);
        assert!(cp.tokens_of(&c[..n - 1]).is_err() || n == 1, "tokens_of took another length");
        let mut p = pipe(&f, &cp, &toks).unwrap_or_else(|e| panic!("n = {n}: the honest pipeline refused: {e}"));
        let v = p.out_values.verdict;
        let r = prove_n(&f, &mut p, v, n).unwrap_or_else(|e| panic!("n = {n}: refused: {e}"));
        verify(&f, &r.st, &r.segs).unwrap_or_else(|e| panic!("n = {n}: did not verify: {e}"));
        owner_check_input(&r.st, &r.dec, &c).unwrap_or_else(|e| panic!("n = {n}: owner check: {e}"));
        let ch = r.st.chunk();
        assert_eq!((ch.index, ch.count, ch.a, ch.b, ch.total, ch.size), (0, 1, 0, n, n, size), "n = {n}: the chunk record");
        if n < size {
            let e = stmt(&f, r.st.in_root(), v, n, size, 0).err().expect("A SHORT n UNDER A FULL CHUNK WAS ADMITTED");
            assert!(e.contains("holds"), "{e}");
            let e = stmt(&f, r.st.in_root(), v, size, n, 0).err().expect("A FULL n UNDER A SHORT CHUNK WAS ADMITTED");
            assert!(e.contains("holds"), "{e}");
        }
        let flipped = stmt(&f, r.st.in_root(), 1 - v, n, n, 0).unwrap();
        assert!(verify(&f, &flipped, &r.segs).is_err(), "n = {n}: the opposite verdict verified");
        eprintln!("RV14 S1 | n = {n}: item length {}, pads {}, verdict row {}; proved, verified, owner-checked; the opposite verdict and the mismatched chunk statements refused", cp.item_len(), cp.pad_positions(), cp.verdict_row());
    }
}

// ------------------------------------------------------------------ S2

/// **S2 (item 3, N declared != actual, verifier side).** A 20-id receipt
/// re-stated, consistently, as an item of 1, 19, 21, 22 and 23 ids (the
/// statement derived by the verifier's own constructor, same root and verdict)
/// is refused every time; the owner's check under those statements refuses
/// both the 20-id content and a content of the stated length.
#[test]
fn rv14_s2_a_short_receipt_under_any_other_length_is_refused() {
    let f = fx_with(policy_rung_dev());
    let n = 20;
    let cp = prof(&f, n).unwrap();
    let c = content_n(&f, n, 0x7632);
    let mut p = pipe(&f, &cp, &cp.tokens_of(&c).unwrap()).unwrap();
    let v = p.out_values.verdict;
    let r = prove_n(&f, &mut p, v, n).unwrap();
    verify(&f, &r.st, &r.segs).unwrap();
    for m in [1usize, 19, 21, 22, 23] {
        let st = stmt(&f, r.st.in_root(), v, m, m, 0).unwrap();
        let e = verify(&f, &st, &r.segs).err().unwrap_or_else(|| panic!("A {n}-ID RECEIPT VERIFIED AS A {m}-ID ITEM"));
        assert!(owner_check_input(&st, &r.dec, &c).is_err(), "the owner's check took the 20-id content under n = {m}");
        let cm = content_n(&f, m, 0x7632);
        assert!(owner_check_input(&st, &r.dec, &cm).is_err(), "the owner's check took a {m}-id content");
        eprintln!("RV14 S2 | the 20-id receipt re-stated as n = {m}: refused ({e})");
    }
}

// ------------------------------------------------------------------ S3

/// **S3 (item 3, forged layouts, prover side).** The cheating prover seals a
/// plane whose layout is not the statement's and proves; the verifier refuses
/// each; the honest prover refuses each before any header.
#[test]
fn rv14_s3_forged_layouts_are_refused() {
    let f = fx_with(policy_rung_dev());
    let (sfx, pad) = (f.policy.suffix[0], f.policy.pad);
    let c23 = content_n(&f, 23, 0x7633);
    let (c20, c21) = (c23[..20].to_vec(), c23[..21].to_vec());
    let pre = f.policy.prefix.clone();
    let cat = |parts: &[&[u64]]| -> Vec<u64> { parts.concat() };
    let cases: Vec<(&str, usize, Vec<u64>)> = vec![
        ("a 20-id plane stated as n = 21", 21, layout(&f, &c20, pad)),
        ("a 21-id plane stated as n = 20", 20, layout(&f, &c21, pad)),
        ("a full 23-id plane stated as n = 20", 20, layout(&f, &c23, pad)),
        ("a 20-id plane stated as n = 23 (pads read as content)", 23, layout(&f, &c20, pad)),
        ("pads inside the content range: n = 23, content = 20 ids + 3 pad ids", 23, cat(&[&pre, &c20, &[pad, pad, pad], &[sfx]])),
        ("pads before the suffix: n = 20, the suffix at T - 1", 20, cat(&[&pre, &c20, &[pad, pad, pad], &[sfx]])),
        ("the suffix id over the pad positions: n = 20", 20, cat(&[&pre, &c20, &[sfx, sfx, sfx, sfx]])),
        ("a content id at every pad position: n = 20", 20, cat(&[&pre, &c20, &[sfx], &[150, 151, 152]])),
        ("control id 0 at the pad positions: n = 20", 20, cat(&[&pre, &c20, &[sfx], &[0, 0, 0]])),
        ("another control id (4) at the last pad position: n = 20", 20, cat(&[&pre, &c20, &[sfx], &[pad, pad, 4]])),
    ];
    for (name, n, toks) in cases {
        assert_eq!(toks.len(), f.sh.tokens, "{name}");
        let cp = prof(&f, n).unwrap();
        let e0 = pipe(&f, &cp, &toks).err().unwrap_or_else(|| panic!("{name}: the honest pipeline took the forged layout"));
        let p = pipe_cheat(&f, &cp, &toks);
        let v = p.out_values.verdict;
        let r = cheat(&f, p, v, n);
        let e = verify(&f, &r.st, &r.segs).err().unwrap_or_else(|| panic!("A FORGED LAYOUT VERIFIED: {name}"));
        let site = if e.contains("stage IN-C") { "stage IN-C" } else { "ELSEWHERE" };
        let e2 = honest_refuses_before_header(&f, pipe_cheat(&f, &cp, &toks), v, n);
        eprintln!("RV14 S3 | {name}: honest pipeline refused ({e0}); verifier refused at {site} ({e}); the honest prover refused before any header ({e2})");
    }
}

// ------------------------------------------------------------------ S4

/// **S4 (item 3, the verdict row shifted).** A margin computed from rows
/// vr - 1 (the last content row), vr + 1 (the first pad row), 0 and T - 1
/// instead of the public verdict row: refused at stage OUT-C (rows whose
/// value equals the verdict row's are skipped: no forgery exists there).
#[test]
fn rv14_s4_a_margin_at_any_other_row_is_refused() {
    let f = fx_with(policy_rung_dev());
    let n = 20;
    let cp = prof(&f, n).unwrap();
    let toks = cp.tokens_of(&content_n(&f, n, 0x7634)).unwrap();
    let vr = cp.verdict_row();
    let p0 = pipe(&f, &cp, &toks).unwrap();
    let b_out = p0.planes.last().unwrap().clone();
    let at_vr = stage_out_c::row_of(&cp, &b_out, vr);
    let mut done = 0;
    for row in [vr - 1, vr + 1, 0, f.sh.tokens - 1] {
        let x = stage_out_c::row_of(&cp, &b_out, row);
        if x == at_vr {
            eprintln!("RV14 S4 | row {row} equals the verdict row: no forgery there");
            continue;
        }
        let mut q = pipe(&f, &cp, &toks).unwrap();
        let ov = stage_out_c::out_values(&cp, &f.tables, &x, false).unwrap();
        q.stage_out = stage_out_c::witness_from_values(&cp, &ov).unwrap();
        let v = ov.verdict;
        q.out_values = ov;
        let r = cheat(&f, q, v, n);
        let e = verify(&f, &r.st, &r.segs).err().unwrap_or_else(|| panic!("A MARGIN AT ROW {row} VERIFIED (verdict row {vr})"));
        assert!(e.contains("OUT-C") || e.contains("boundary"), "row {row}: refused elsewhere: {e}");
        done += 1;
        eprintln!("RV14 S4 | the margin at row {row} instead of the verdict row {vr}: refused ({e})");
    }
    assert!(done >= 3, "fewer than three rows were attacked");
}

// ------------------------------------------------------------------ S5

/// **S5 (item 3, causality IN THE RELATION).** The softmax quotient of a
/// MASKED entry (the verdict row, or an earlier content row, toward a pad row)
/// is forged from 0 to 1 in every block's witness (native R12b's D24 forge
/// hook; the honest PV sum stays causal, so only the relation can object):
/// the verifier refuses. The relation's masked weight is 0 by SC_SZC's
/// division clause (mask = 0 gives P * Sum + rho = 0 with P, rho limbs in
/// range), and SC_PV sums P * V over every source position, so a pad row can
/// reach the verdict row only through a masked weight.
#[test]
fn rv14_s5_a_masked_weight_toward_a_pad_row_is_refused_by_the_relation() {
    use super::super::review_d24_tests::{rv14_forged_count, rv14_set_forge, Forge};
    let f = fx_with(policy_rung_dev());
    let n = 20;
    let cp = prof(&f, n).unwrap();
    let toks = cp.tokens_of(&content_n(&f, n, 0x7635)).unwrap();
    let vr = cp.verdict_row();
    // control: the honest run verifies
    let mut p = pipe(&f, &cp, &toks).unwrap();
    let v = p.out_values.verdict;
    let honest_margin = p.out_values.margin;
    let r = prove_n(&f, &mut p, v, n).unwrap();
    verify(&f, &r.st, &r.segs).unwrap();
    for (h, t, j) in [(0usize, vr, vr + 1), (0, vr, f.sh.tokens - 1), (1, vr - 3, vr + 2)] {
        rv14_set_forge(Some(Forge { h, t, j, delta: 1, k: 0, naive: true }));
        let q = {
            let _c = CheatingProver::on();
            pipe(&f, &cp, &toks)
        };
        let forged = rv14_forged_count();
        rv14_set_forge(None);
        let q = q.unwrap_or_else(|e| panic!("the forged pipeline refused: {e}"));
        assert!(forged >= 1, "the forge was not applied at ({h}, {t}, {j})");
        assert_eq!(q.out_values.margin, honest_margin, "the witness's PV is causal: the margin is unchanged");
        let r = cheat(&f, q, v, n);
        let e = verify(&f, &r.st, &r.segs).err().unwrap_or_else(|| panic!("A NONZERO MASKED WEIGHT ({h}, {t} -> {j}) VERIFIED"));
        eprintln!("RV14 S5 | P[h {h}, t {t}, j {j}] = 1 (masked: j > t) in {forged} block witness(es): refused ({e})");
    }
}

/// **S5b (item 3, causality: the CONSISTENT forgery).** Run with
/// `RV14_MUT=pv-all` (the cheating prover's PV then reads every source
/// position): a masked weight of 1/8 (P = 64 at F_P = 9) from the verdict row,
/// or an earlier content row, toward a pad row now MOVES the verdict row's
/// value and the margin, with P, O and every downstream plane consistent; only
/// the softmax zero-check's division clause (mask = 0 => P * Sum + rho = 0)
/// stands in the way, and the verifier refuses there.
#[test]
#[ignore = "run with RV14_MUT=pv-all"]
fn rv14_s5b_a_consistent_pad_row_influence_is_refused_at_the_softmax_division() {
    use super::super::review_d24_tests::{rv14_forged_count, rv14_set_forge, Forge};
    assert!(super::rv14_mut("pv-all"), "run with RV14_MUT=pv-all");
    let f = fx_with(policy_rung_dev());
    let n = 20;
    let cp = prof(&f, n).unwrap();
    let toks = cp.tokens_of(&content_n(&f, n, 0x7635)).unwrap();
    let vr = cp.verdict_row();
    let mut p = pipe(&f, &cp, &toks).unwrap();
    let v = p.out_values.verdict;
    let honest_margin = p.out_values.margin;
    let r = prove_n(&f, &mut p, v, n).unwrap();
    verify(&f, &r.st, &r.segs).expect("pv-all leaves an honest witness unchanged");
    let mut moved = 0;
    for (h, t, j) in [(0usize, vr, vr + 1), (3, vr, f.sh.tokens - 1), (1, vr - 3, vr + 2)] {
        rv14_set_forge(Some(Forge { h, t, j, delta: 64, k: 0, naive: true }));
        let q = {
            let _c = CheatingProver::on();
            pipe(&f, &cp, &toks)
        };
        let forged = rv14_forged_count();
        rv14_set_forge(None);
        let q = match q {
            Ok(q) => q,
            Err(e) => {
                eprintln!("RV14 S5b | P[h {h}, t {t}, j {j}] = 64: the forged witness itself leaves a class ({e}); no receipt");
                continue;
            }
        };
        assert!(forged >= 1);
        let m = q.out_values.margin;
        if m != honest_margin {
            moved += 1;
        }
        let vq = q.out_values.verdict;
        let r = cheat(&f, q, vq, n);
        let e = verify(&f, &r.st, &r.segs).err().unwrap_or_else(|| panic!("A PAD ROW REACHED ROW {t} AND VERIFIED"));
        eprintln!("RV14 S5b | P[h {h}, t {t}, j {j}] = 64 with PV over every position: margin {m} (honest {honest_margin}); refused ({e})");
    }
    assert!(moved >= 1, "no forgery moved the margin: the attack is vacuous");
}

// ------------------------------------------------------------------ S6

fn pol_pad(pad: u64) -> Policy {
    let mut p = policy_rung_dev();
    p.id = format!("rv14-dev-pad-{pad}/1");
    p.pad = pad;
    p
}

/// **S6 (item 3, another pad id).** The same 20-id content under the dev
/// policy (pad 2) and test policies with pad 3 (another control id) and 200
/// (a content-class id): each proves and verifies; every block's output rows
/// 0..=vr are identical across the three (only the pad rows differ), so the
/// margin is the same; a receipt is refused under the other pad id's
/// statement (same root, n, verdict), and so is its owner's check; the
/// profile texts differ in the policy id and pad id; a pad id >= V is refused.
#[test]
fn rv14_s6_the_pad_id_is_bound_and_never_reaches_the_verdict_row() {
    let fs = [fx_with(policy_rung_dev()), fx_with(pol_pad(3)), fx_with(pol_pad(200))];
    let n = 20;
    let c = content_n(&fs[0], n, 0x7636);
    let mut out: Vec<(i64, Vec<Vec<i16>>, Run)> = Vec::new();
    for f in &fs {
        let cp = prof(f, n).unwrap();
        let toks = cp.tokens_of(&c).unwrap();
        assert!(toks[cp.item_len()..].iter().all(|x| *x == f.policy.pad));
        let mut p = pipe(f, &cp, &toks).unwrap_or_else(|e| panic!("pad {}: {e}", f.policy.pad));
        let (m, planes) = (p.out_values.margin, p.planes.clone());
        let v = p.out_values.verdict;
        let r = prove_n(f, &mut p, v, n).unwrap_or_else(|e| panic!("pad {}: {e}", f.policy.pad));
        verify(f, &r.st, &r.segs).unwrap_or_else(|e| panic!("pad {}: {e}", f.policy.pad));
        owner_check_input(&r.st, &r.dec, &c).unwrap();
        out.push((m, planes, r));
    }
    let cp = prof(&fs[0], n).unwrap();
    let (vr, dp) = (cp.verdict_row(), fs[0].sh.d_pad);
    for k in 1..3 {
        assert_eq!(out[k].0, out[0].0, "pad {}: another margin", fs[k].policy.pad);
        for (b, (pa, pb)) in out[0].1.iter().zip(out[k].1.iter()).enumerate() {
            assert_eq!(&pa[..(vr + 1) * dp], &pb[..(vr + 1) * dp], "block {b}: a row <= the verdict row moved with the pad id {}", fs[k].policy.pad);
            assert_ne!(&pa[(vr + 1) * dp..fs[0].sh.tokens * dp], &pb[(vr + 1) * dp..fs[0].sh.tokens * dp], "block {b}: the pad rows did not move (the attack is vacuous)");
        }
        let a = prof(&fs[0], n).unwrap().describe_under(RUN_PROFILE_CLASSIFY_RUNG_TC);
        let b = prof(&fs[k], n).unwrap().describe_under(RUN_PROFILE_CLASSIFY_RUNG_TC);
        assert_ne!(a, b);
        assert!(b.contains(&format!("pad-id={}", fs[k].policy.pad)));
    }
    for (i, k) in [(0usize, 1usize), (1, 0), (0, 2), (2, 1)] {
        let r = &out[i].2;
        let st = stmt(&fs[k], r.st.in_root(), r.st.verdict(), n, n, 0).unwrap();
        let e = verify(&fs[k], &st, &r.segs).err().unwrap_or_else(|| panic!("A PAD-{} RECEIPT VERIFIED UNDER PAD {}", fs[i].policy.pad, fs[k].policy.pad));
        assert!(owner_check_input(&st, &r.dec, &c).is_err(), "the owner's check took a pad-{} plane under pad {}", fs[i].policy.pad, fs[k].policy.pad);
        eprintln!("RV14 S6 | the pad-{} receipt under the pad-{} statement: refused ({e}); owner check refused", fs[i].policy.pad, fs[k].policy.pad);
    }
    let bad = pol_pad(300);
    register_test_policy(bad.clone());
    let e = ClassifierProfile::new(&fs[0].sh, &fs[0].tables, 1, norm(), &bad, n, Tier::R1_MVP).err().expect("A PAD ID >= V WAS ADMITTED");
    eprintln!("RV14 S6 | margins equal across pad ids 2 / 3 / 200 ({}); rows 0..={vr} identical in every block; pad id 300 refused ({e})", out[0].0);
}

// ------------------------------------------------------------------ S7 (the CLI)

fn s(v: &[&str]) -> Vec<String> {
    v.iter().map(|x| x.to_string()).collect()
}

fn ids(text: &str) -> Vec<u64> {
    text.split(',').map(|x| x.parse().unwrap()).collect()
}

fn text(v: &[u64]) -> String {
    v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
}

fn sib(p: &Path, suffix: &str) -> PathBuf {
    let mut o = p.as_os_str().to_owned();
    o.push(suffix);
    PathBuf::from(o)
}

fn copy_dir(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for e in std::fs::read_dir(from).unwrap() {
        let e = e.unwrap();
        let (src, dst) = (e.path(), to.join(e.file_name()));
        if e.file_type().unwrap().is_dir() {
            copy_dir(&src, &dst);
        } else {
            std::fs::copy(&src, &dst).unwrap();
        }
    }
}

fn copy_run(from: &Path, to: &Path) {
    copy_dir(from, to);
    copy_dir(&sib(from, ".unverified-statement"), &sib(to, ".unverified-statement"));
}

fn unverified(out: &Path) -> PathBuf {
    sib(out, ".unverified-statement").join("statement.json")
}

fn published(out: &Path) -> bool {
    out.join(run_sink::STATEMENT_DIR).exists()
}

/// the dev template around `content`, padded with the dev pad id to T = 32
fn dev_item(content: &[u64]) -> Vec<u64> {
    let p = policy_rung_dev();
    let mut v: Vec<u64> = p.prefix.iter().chain(content.iter()).chain(p.suffix.iter()).copied().collect();
    while v.len() < 32 {
        v.push(p.pad);
    }
    v
}

/// **S7 (items 3 and 4, the CLI on derived tables).**
/// * truncation: a proof of the first 22 ids of the fixture's 23-id content is
///   refused by the input owner holding the 23-id post (and by any longer or
///   other content);
/// * D41 coverage: the short run labelled with a 27-id item's chunk runs, with
///   itself twice, and a 27-id item with a chunk missing: refused; the 27-id
///   item's two chunks label (control); the short run alone labels with
///   `content_total` 22 and one chunk;
/// * a 22-id content proved with `--chunk 1` (no such chunk) is refused;
/// * the four new statement fields and the schema, each edited alone in a
///   copy: refused at the door, nothing published; the honest copy verifies.
#[test]
fn rv14_s7_cli_truncation_coverage_and_statement_fields() {
    let cc = Cc::new("rv14-s7");
    let full = ids(&cc.content);
    assert_eq!(full.len(), 23);
    let short = full[..22].to_vec();
    let sd = cc.owners.join("seq-short");
    cc.write_seq_dir(&sd, &dev_item(&short));
    let rs = cc.root.join("short");
    assert_eq!(cc.prove_chunk(&rs, &text(&short), 0, Some(sd.as_path())), 0, "the 22-id item proves");
    let rs_bad = cc.root.join("short-chunk1");
    assert_eq!(cc.prove_chunk(&rs_bad, &text(&short), 1, Some(sd.as_path())), 1, "chunk 1 of a short item was proved");
    // copies BEFORE any verify (verify publishes in place)
    let honest_copy = cc.root.join("short-copy");
    copy_run(&rs, &honest_copy);
    let edits: [(&str, &str, &str); 7] = [
        ("pad_id", "\"pad_id\": 2,", "\"pad_id\": 3,"),
        ("pad_positions", "\"pad_positions\": 1,", "\"pad_positions\": 0,"),
        ("verdict_row", "\"verdict_row\": 30,", "\"verdict_row\": 31,"),
        ("item_length", "\"item_length\": 31,", "\"item_length\": 32,"),
        ("schema /2", "\"schema\": \"zk60-classify-run/3\"", "\"schema\": \"zk60-classify-run/2\""),
        ("T", "\"T\": 32,", "\"T\": 31,"),
        ("chunk range", "\"range\": [0, 22]", "\"range\": [0, 23]"),
    ];
    for (k, (name, from, to)) in edits.iter().enumerate() {
        let c = cc.root.join(format!("short-edit-{k}"));
        copy_run(&rs, &c);
        let t = std::fs::read_to_string(unverified(&c)).unwrap();
        assert!(t.contains(from), "{name}: {from} not in the statement:\n{t}");
        std::fs::write(unverified(&c), t.replacen(from, to, 1)).unwrap();
        assert_eq!(cc.verify(&c, &cc.tables), 1, "THE STATEMENT WITH {name} EDITED VERIFIED");
        assert!(!published(&c), "{name}: published");
        eprintln!("RV14 S7 | statement field {name} edited ({from} -> {to}): refused, nothing published");
    }
    assert_eq!(cc.verify(&honest_copy, &cc.tables), 0, "the honest short run verifies");
    // truncation and other contents at the input owner
    assert_eq!(cc.input_owner(&rs, &cc.tables, &text(&full)), 1, "A 22-ID PROOF PASSED THE OWNER CHECK OF THE 23-ID POST");
    assert_eq!(cc.input_owner(&rs, &cc.tables, &text(&short[..21])), 1, "a 21-id content passed");
    assert_eq!(cc.input_owner(&rs, &cc.tables, &text(&short)), 0, "the 22-id content");
    // the 27-id item's two chunks ([0, 23) and [4, 27))
    let long: Vec<u64> = full.iter().copied().chain([100u64, 101, 102, 103]).collect();
    let mut chunks = Vec::new();
    for (j, (a, b)) in [(0usize, 23usize), (4, 27)].iter().enumerate() {
        let d = cc.owners.join(format!("seq-long-{j}"));
        cc.write_seq_dir(&d, &dev_item(&long[*a..*b]));
        let o = cc.root.join(format!("long-{j}"));
        assert_eq!(cc.prove_chunk(&o, &text(&long), j, Some(d.as_path())), 0, "the 27-id item's chunk {j}");
        chunks.push(o);
    }
    let (l0, l1) = (chunks[0].clone(), chunks[1].clone());
    assert_eq!(cc.label(&[&rs, &l0]), 1, "A SHORT RUN LABELLED WITH ANOTHER ITEM'S CHUNK");
    assert_eq!(cc.label(&[&rs, &l1]), 1, "a short run as chunk 0 beside the long item's chunk 1");
    assert_eq!(cc.label(&[&rs, &rs]), 1, "the short run twice");
    assert_eq!(cc.label(&[&l0]), 1, "a 27-id item with chunk 1 missing");
    assert_eq!(cc.label(&[&l0, &l1]), 0, "the 27-id item's two chunks (control)");
    assert_eq!(cc.label(&[&rs]), 0, "the short run alone");
    // the short proof offered for the long post's owner
    assert_eq!(cc.input_owner(&rs, &cc.tables, &text(&long)), 1, "a 22-id proof passed the 27-id post's owner check");
    eprintln!("RV14 S7 | truncation refused by the owner of the 23- and 27-id posts; label mixes refused; the 27-id item and the short item each label");
}

// ------------------------------------------------------------------ S8 (named binaries)

fn bin_run(bin: &str, args: &[&str]) -> (i32, String, String) {
    let o = std::process::Command::new(bin).args(args).output().expect("the binary runs");
    (o.status.code().unwrap_or(-1), String::from_utf8_lossy(&o.stdout).into_owned(), String::from_utf8_lossy(&o.stderr).into_owned())
}

/// the refusal's own line when there is one (else the last line)
fn last(s: &str) -> &str {
    s.lines().find(|l| l.contains("\"event\":\"refused\"")).unwrap_or_else(|| s.lines().last().unwrap_or(""))
}

/// **S8 (item 4, no downgrade path), `RV14_R12_BIN` / `RV14_R13_BIN` /
/// `RV14_R14_BIN` the lane's frozen release binaries.** The fixture's full
/// item is proved by each binary and every receipt verified by every binary
/// (a fresh copy per verify): only the diagonal verifies. The 22-id item:
/// r14 proves; r12 and r13 refuse the prove; r12 and r13 refuse r14's short
/// receipt. Upgrade / downgrade: r13 segments under r14's statement (r13's
/// root) refused by r14; r14 segments under r13's statement (r14's root)
/// refused by r13. A /2 statement relabelled /3 refused by r14.
#[test]
#[ignore = "runs the named zk60_classify binaries; set RV14_R12_BIN, RV14_R13_BIN, RV14_R14_BIN"]
fn rv14_s8_receipts_do_not_cross_between_the_r12_r13_and_r14_binaries() {
    let bins: Vec<(&str, String)> = ["12", "13", "14"].iter().map(|r| (*r, std::env::var(format!("RV14_R{r}_BIN")).unwrap_or_else(|_| panic!("RV14_R{r}_BIN")))).collect();
    let cc = Cc::new("rv14-s8");
    let ex = cc.export.to_str().unwrap().to_string();
    let vc = cc.verifier_copy.to_str().unwrap().to_string();
    let tb = cc.tables.to_str().unwrap().to_string();
    let prove_with = |bin: &str, out: &Path, content: &str, seq_dir: Option<&Path>| {
        let cf = cc.content_file(content);
        let od = cc.owner_dir(out);
        let sdir: Option<String> = seq_dir.map(|d| d.to_str().unwrap().to_string());
        let mut a: Vec<&str> = vec!["prove", "--export", &ex, "--tables", &tb, "--policy", POLICY_RUNG_DEV, "--content-file", cf.to_str().unwrap(), "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap()];
        match &sdir {
            Some(d) => a.extend_from_slice(&["--seq-dir", d.as_str()]),
            None => a.extend_from_slice(&["--seq", "s0"]),
        }
        bin_run(bin, &a)
    };
    let verify_with = |bin: &str, out: &Path| bin_run(bin, &["verify", "--export", &vc, "--tables", &tb, "--policy", POLICY_RUNG_DEV, "--artifact", out.to_str().unwrap(), "--expect-statement", &cc.identity, "--min-bits", "93"]);
    // the full item through each binary
    let mut runs: Vec<(String, PathBuf)> = Vec::new();
    for (r, bin) in &bins {
        let o = cc.root.join(format!("full-r{r}"));
        let (c, out, err) = prove_with(bin, &o, &cc.content, None);
        assert_eq!(c, 0, "r{r} prove of the full item: {} {err}", last(&out));
        let st = std::fs::read_to_string(unverified(&o)).unwrap();
        let schema = st.lines().find(|l| l.contains("\"schema\"")).unwrap_or("").trim().to_string();
        eprintln!("RV14 S8 | r{r} proved the full item: {schema}");
        runs.push((r.to_string(), o));
    }
    for (rp, o) in &runs {
        for (rv, bin) in &bins {
            let c = cc.root.join(format!("full-r{rp}-by-r{rv}"));
            copy_run(o, &c);
            let (code, out, _) = verify_with(bin, &c);
            eprintln!("RV14 S8 | r{rp} receipt verified by r{rv}: exit {code} {}", last(&out));
            if rp == rv {
                assert_eq!(code, 0, "r{rv} refused its own receipt");
            } else {
                assert_eq!(code, 1, "THE r{rv} BINARY ACCEPTED AN r{rp} RECEIPT");
                assert!(!published(&c));
            }
        }
    }
    // the 22-id item
    let full = ids(&cc.content);
    let short = full[..22].to_vec();
    let sd = cc.owners.join("seq-short");
    cc.write_seq_dir(&sd, &dev_item(&short));
    let mut short14 = PathBuf::new();
    for (r, bin) in &bins {
        let o = cc.root.join(format!("short-r{r}"));
        let (c, out, err) = prove_with(bin, &o, &text(&short), Some(sd.as_path()));
        eprintln!("RV14 S8 | r{r} prove of the 22-id item: exit {c} {} {}", last(&out), last(&err));
        if r == &"14" {
            assert_eq!(c, 0, "r14 refused the short item");
            short14 = o;
        } else {
            assert_ne!(c, 0, "THE r{r} BINARY PROVED A SHORT ITEM");
        }
    }
    for (r, bin) in &bins {
        let c = cc.root.join(format!("short-r14-by-r{r}"));
        copy_run(&short14, &c);
        let (code, out, _) = verify_with(bin, &c);
        eprintln!("RV14 S8 | r14 short receipt verified by r{r}: exit {code} {}", last(&out));
        assert_eq!(code, if r == &"14" { 0 } else { 1 }, "r{r} on the r14 short receipt");
    }
    // upgrade / downgrade: segments of one binary under the other's statement (with the segments' own root)
    let root_of = |o: &Path| -> String {
        let t = std::fs::read_to_string(unverified(o)).unwrap();
        let l = t.lines().find(|l| l.contains("\"input_token_endpoint_root\"")).unwrap().to_string();
        l.split('"').nth(3).unwrap().to_string()
    };
    let (o13, o14) = (&runs[1].1, &runs[2].1);
    for (seg_of, st_of, verifier) in [(o13, o14, &bins[2].1), (o14, o13, &bins[1].1)] {
        let mix = cc.root.join(format!("mix-{}-under-{}", seg_of.file_name().unwrap().to_string_lossy(), st_of.file_name().unwrap().to_string_lossy()));
        copy_dir(seg_of, &mix);
        std::fs::create_dir_all(sib(&mix, ".unverified-statement")).unwrap();
        let t = std::fs::read_to_string(unverified(st_of)).unwrap().replacen(&root_of(st_of), &root_of(seg_of), 1);
        std::fs::write(unverified(&mix), t).unwrap();
        let (code, out, _) = verify_with(verifier, &mix);
        eprintln!("RV14 S8 | segments of {} under the statement of {} ({}): exit {code} {}", seg_of.display(), st_of.display(), verifier, last(&out));
        assert_eq!(code, 1, "A RECEIPT CROSSED BETWEEN SCHEMAS");
        assert!(!published(&mix));
    }
    // a /2 statement relabelled /3 (r13's receipt), for r14
    let re = cc.root.join("r13-relabelled");
    copy_run(o13, &re);
    let t = std::fs::read_to_string(unverified(&re)).unwrap().replacen("zk60-classify-run/2", "zk60-classify-run/3", 1);
    std::fs::write(unverified(&re), t).unwrap();
    let (code, out, _) = verify_with(&bins[2].1, &re);
    eprintln!("RV14 S8 | r13 receipt relabelled /3, r14 verifier: exit {code} {}", last(&out));
    assert_eq!(code, 1);
    // and the in-process verifier of this tree on r13's and r12's receipts
    for o in [&runs[0].1, o13] {
        let c = cc.root.join(format!("{}-inproc", o.file_name().unwrap().to_string_lossy()));
        copy_run(o, &c);
        let code = classify_verify_command(&s(&["--export", &vc, "--tables", &tb, "--policy", POLICY_RUNG_DEV, "--artifact", c.to_str().unwrap(), "--expect-statement", &cc.identity, "--min-bits", "93"]));
        assert_eq!(code, 1, "this tree's verifier accepted {}", o.display());
    }
    let _ = (classify_input_owner_command, classify_prove_command);
    eprintln!("RV14 S8 | PASS: only the diagonal verifies; the short item is r14-only; no upgrade / downgrade / relabel");
}

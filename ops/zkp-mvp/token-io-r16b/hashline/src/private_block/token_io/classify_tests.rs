//! **TOKEN I/O ROUND 12, RUNG R-C1: THE CLASSIFIER VARIANT'S TESTS.** TEST
//! CODE ONLY, public synthetic data (the dense trained-calibration rung, a
//! generic embedding, a random int16 margin vector). Mirrors R-C0
//! (`results/zk60_token_io_r1_20261017/classifier/rc0/`): honest runs at both
//! verdicts and the tie; every forgery proved by the CHEATING prover and
//! refused by the verifier at its site; the same forgeries refused BEFORE ANY
//! HEADER by the honest prover (the sealing pass); the verdict bound by the
//! transcript; the B-3 / B-6 door; the ruling switches in the profile text.
//!
//! **Round 14:** these are RELATION tests on a generic embedding and a random
//! margin row, so their tables are bound by the test-only synthetic binding
//! (`BoundClassifierTables::synthetic_for_relation_tests`; the capture replay
//! refuses it, and production builds have no such constructor). The tables
//! every production path and the gate's captures use are derived from the
//! pinned tensor (`classify_tied_tests`, `classify_r14_tests`,
//! `classify_capture_tests`). Round 14 adds the short-item relation tests
//! (DESIGN v2.4 §15): a short item proves and verifies; a doctored pad
//! position and a margin read at another row are refused.

use super::classify::*;
use super::classify_run::*;
use super::classify_tied::BoundClassifierTables;
use super::stage_out_c::{self, C_LIMB};
use super::tests::{blocks, ctx, generic_tables, lcg, model_at, norm, rung};
use super::*;
use super::super::protocol::CheatingProver;
use super::super::run::{RunShape, RUN_PROFILE_CLASSIFY_RUNG_TC};
use super::super::trained_statement::TrainedModelStatement;
use super::super::BlockPublic;
use super::run::VerifierPolicy;

const L: usize = 2;
const POLICY_93: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 93 };

struct Cx {
    sh: Shape,
    blocks: Vec<BlockPublic>,
    model: TrainedModelStatement,
    tables: ClassifierTables,
    /// the relation tests' synthetic binding of `tables` (test builds only)
    bound: BoundClassifierTables,
    policy: Policy,
}

fn bind(sh: &Shape, tables: &ClassifierTables, model: &TrainedModelStatement, policy: &Policy) -> BoundClassifierTables {
    BoundClassifierTables::synthetic_for_relation_tests(tables.clone(), 1, norm(), sh, RUN_PROFILE_CLASSIFY_RUNG_TC, model, policy).expect("the relation tests' binding")
}

fn cx_with(policy: Policy) -> Cx {
    let sh = rung();
    let blocks = blocks(&sh, L);
    let model = model_at(&sh, &blocks, RUN_PROFILE_CLASSIFY_RUNG_TC);
    let tt = generic_tables(sh.width, 0x636c_6173);
    let mut s = 0x6d61_7267u64;
    let w: Vec<i16> = (0..sh.width).map(|_| (lcg(&mut s) % 65_535) as i16 - 32_767 + 0).map(|x| if x == i16::MIN { x + 1 } else { x }).collect();
    let tables = ClassifierTables::new(tt.v, tt.d, tt.emb.clone(), w).expect("the classifier tables");
    let bound = bind(&sh, &tables, &model, &policy);
    Cx { sh, blocks, model, tables, bound, policy }
}

fn cx() -> Cx {
    cx_with(policy_rung_dev())
}

fn n_of(cx: &Cx) -> usize {
    cx.sh.tokens - cx.policy.prefix.len() - cx.policy.suffix.len()
}

/// a content of `n` ids in [num_special, V) from a seed
fn content(cx: &Cx, seed: u64) -> Vec<u64> {
    let mut s = seed;
    (0..n_of(cx)).map(|_| cx.policy.num_special + lcg(&mut s) % (cx.policy.v as u64 - cx.policy.num_special)).collect()
}

fn profile(cx: &Cx) -> ClassifierProfile {
    ClassifierProfile::new(&cx.sh, &cx.tables, 1, norm(), &cx.policy, n_of(cx), Tier::R1_MVP).expect("the classifier profile")
}

fn statement(cx: &Cx, root: Digest, verdict: u8) -> Result<ClassifyRunStatement, String> {
    ClassifyRunStatement::new(RunShape::new(cx.sh.clone(), L, RUN_PROFILE_CLASSIFY_RUNG_TC)?, ctx(), cx.blocks.iter().map(|b| b.digest()).collect(), &cx.model, &cx.bound, &cx.policy, n_of(cx), Tier::R1_MVP, root, verdict)
}

fn pipe(cx: &Cx, tokens: &[u64]) -> HonestClassify {
    let cp = profile(cx);
    honest_classify(&vec![cx.sh.clone(); L], &cp, &cx.tables, &cx.blocks, tokens).unwrap_or_else(|e| panic!("the honest classifier pipeline refused: {e}"))
}

struct Run {
    st: ClassifyRunStatement,
    segs: Vec<Vec<u8>>,
    dec: Decommitment,
}

/// seal the pipeline's input plane, build the statement under `verdict` and prove
fn prove_with(cx: &Cx, p: &mut HonestClassify, verdict: u8) -> Result<Run, String> {
    let cp = profile(cx);
    let spec = input_endpoint_spec(&cx.sh, ctx(), &cp)?;
    let (root, owner) = seal_input(&spec, &p.in_plane, &cx.sh.hash_tag())?;
    let st = statement(cx, root, verdict)?;
    let mut segs = Vec::new();
    let (_, dec) = prove_classify_run(&st, &cx.blocks, &cx.bound, &mut ClassifySource(p), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })?;
    Ok(Run { st, segs, dec })
}

fn verify(cx: &Cx, r: &Run) -> Result<(), String> {
    verify_classify_run(&r.st, &cx.blocks, &cx.bound, &r.segs, POLICY_93)
}

/// the cheating prover's receipt of a forged pipeline, then the verifier
fn forge(cx: &Cx, mut p: HonestClassify, verdict: u8) -> String {
    let r = {
        let _cheat = CheatingProver::on();
        prove_with(cx, &mut p, verdict).unwrap_or_else(|e| panic!("the cheating prover did not produce a receipt: {e}"))
    };
    verify(cx, &r).err().expect("A CLASSIFIER FORGERY VERIFIED")
}

/// the honest prover on a forged pipeline: refused, and BEFORE any header
fn refused_before_header(cx: &Cx, mut p: HonestClassify, verdict: u8) -> String {
    let h0 = classify_headers();
    let e = prove_with(cx, &mut p, verdict).err().expect("the honest prover accepted a forged pipeline");
    assert_eq!(classify_headers(), h0, "refused only AFTER the run header was built: {e}");
    e
}

/// **Both verdicts on the generic fixture.** The synthetic blocks keep the
/// last row close to the fixed suffix token's, so the margin moves little
/// with the content and sits on one side of c = 0. The threshold is
/// therefore set BETWEEN the observed margins, through a registered test
/// policy (as the tie test does): `c = min margin`, so the content with the
/// least margin is not flagged (b = 0) and the one with the most is (b = 1).
/// Returns (that context, content with b = 0, content with b = 1).
fn both_verdicts() -> (Cx, Vec<u64>, Vec<u64>) {
    let base = cx();
    let mut seen: Vec<(i64, Vec<u64>)> = (0..12u64)
        .map(|seed| {
            let c = content(&base, 0x1000 + seed);
            (pipe(&base, &item_tokens(&base.policy, &c)).out_values.margin, c)
        })
        .collect();
    seen.sort();
    let (lo, hi) = (seen.first().unwrap().clone(), seen.last().unwrap().clone());
    assert!(lo.0 < hi.0, "the content does not move the margin on this fixture");
    let mut split = policy_rung_dev();
    split.id = format!("rung-tc-split-test-policy/{}", lo.0);
    split.c = lo.0;
    register_test_policy(split.clone());
    let cx = cx_with(split);
    (cx, lo.1, hi.1)
}

#[test]
fn r12_honest_runs_prove_and_verify_at_both_verdicts_and_the_owner_check_holds() {
    let (cx, c0, c1) = both_verdicts();
    for (want, c) in [(0u8, &c0), (1u8, &c1)] {
        let mut p = pipe(&cx, &item_tokens(&cx.policy, c));
        assert_eq!(p.out_values.verdict, want);
        assert_eq!(p.out_values.verdict, u8::from(p.out_values.margin > cx.policy.c));
        let r = prove_with(&cx, &mut p, want).unwrap_or_else(|e| panic!("verdict {want}: the honest run refused: {e}"));
        verify(&cx, &r).unwrap_or_else(|e| panic!("verdict {want}: the honest run did not verify: {e}"));
        assert_eq!(r.segs.iter().map(|s| s.len()).collect::<Vec<_>>(), r.st.segment_lens().unwrap(), "segment lengths = the counted lengths");
        owner_check_input(&r.st, &r.dec, c).unwrap_or_else(|e| panic!("the owner's check: {e}"));
        let mut other = c.clone();
        other[0] = if other[0] + 1 < cx.policy.v as u64 { other[0] + 1 } else { cx.policy.num_special };
        assert!(owner_check_input(&r.st, &r.dec, &other).is_err(), "another content passed the owner's check");
        assert!(r.st.whole_run().floor_bits >= 93);
        eprintln!("TOKEN-IO R-C1 | honest classifier run, verdict {want} (margin {}), {} segments {:?} B, floor {} bits", p.out_values.margin, r.segs.len(), r.segs.iter().map(|s| s.len()).collect::<Vec<_>>(), r.st.whole_run().floor_bits);
    }
}

#[test]
fn r12_a_receipt_does_not_verify_under_the_other_verdict() {
    let (cx, c0, _) = both_verdicts();
    let mut p = pipe(&cx, &item_tokens(&cx.policy, &c0));
    let r = prove_with(&cx, &mut p, 0).unwrap();
    let flipped = Run { st: statement(&cx, r.st.in_root(), 1).unwrap(), segs: r.segs.clone(), dec: r.dec.clone() };
    let e = verify(&cx, &flipped).err().expect("a verdict-0 receipt verified as verdict 1");
    let st0 = r.st.transcript().unwrap().state();
    let st1 = flipped.st.transcript().unwrap().state();
    assert_ne!(st0, st1, "the verdict is not absorbed by the run header");
    eprintln!("TOKEN-IO R-C1 | a verdict-0 receipt read as verdict 1: refused ({e})");
}

#[test]
fn r12_the_tie_is_not_flagged_and_proves() {
    let base = cx();
    let c = content(&base, 0x7713);
    let margin = pipe(&base, &item_tokens(&base.policy, &c)).out_values.margin;
    let mut tie = policy_rung_dev();
    tie.id = format!("rung-tc-tie-test-policy/{margin}");
    tie.c = margin;
    register_test_policy(tie.clone());
    let cx = cx_with(tie);
    let mut p = pipe(&cx, &item_tokens(&cx.policy, &c));
    assert_eq!(p.out_values.margin, cx.policy.c);
    assert_eq!(p.out_values.verdict, 0, "the tie Delta = c is NOT flagged");
    assert_eq!(stage_out_c::delta_of(p.out_values.margin, cx.policy.c, 0), 0);
    let r = prove_with(&cx, &mut p, 0).unwrap();
    verify(&cx, &r).unwrap();
    eprintln!("TOKEN-IO R-C1 | the tie Delta = c = {margin}: verdict 0, delta 0, proves and verifies");
}

fn flip_with_forged_limbs(cx: &Cx, p: &mut HonestClassify) -> u8 {
    let b = p.out_values.verdict;
    let fb = 1 - b;
    let d = stage_out_c::delta_of(p.out_values.margin, cx.policy.c, fb);
    assert!(d < 0, "the flipped verdict's delta must be negative");
    let lam = &mut p.stage_out.planes[C_LIMB];
    for kk in 0..5 {
        lam[LAM_BASE + kk] = Fp::ZERO;
    }
    lam[LAM_BASE] = Fp::from_i64(d);
    fb
}

#[test]
fn r12_a_flipped_verdict_with_field_limbs_is_refused_at_the_byte_lookups() {
    let cx = cx();
    let c = content(&cx, 0x2201);
    let mut p = pipe(&cx, &item_tokens(&cx.policy, &c));
    let fb = flip_with_forged_limbs(&cx, &mut p);
    let e = forge(&cx, p, fb);
    assert!(e.contains("stage OUT-C H") || e.contains("stage OUT-C slot 04"), "refused elsewhere than the byte LogUp: {e}");
    let mut p = pipe(&cx, &item_tokens(&cx.policy, &c));
    let fb = flip_with_forged_limbs(&cx, &mut p);
    let e2 = refused_before_header(&cx, p, fb);
    eprintln!("TOKEN-IO R-C1 | a flipped verdict with field limbs: cheating prover refused by the verifier ({e}); honest prover refused before the header ({e2})");
}

#[test]
fn r12_a_nonzero_limb_pad_is_refused() {
    let cx = cx();
    let c = content(&cx, 0x2202);
    let mut p = pipe(&cx, &item_tokens(&cx.policy, &c));
    let b = p.out_values.verdict;
    p.stage_out.planes[C_LIMB][LAM_BASE + 5] = Fp::new(7);
    let e = forge(&cx, p, b);
    assert!(e.contains("stage OUT-C slot 04"), "refused elsewhere than LZC's pad clause: {e}");
    let mut p = pipe(&cx, &item_tokens(&cx.policy, &c));
    p.stage_out.planes[C_LIMB][LAM_BASE + 5] = Fp::new(7);
    let e2 = refused_before_header(&cx, p, b);
    eprintln!("TOKEN-IO R-C1 | a nonzero limb pad: refused at LZC ({e}); before the header ({e2})");
}

#[test]
fn r12_byte_limbs_that_break_the_margin_identity_are_refused() {
    let cx = cx();
    let c = content(&cx, 0x2203);
    let mut p = pipe(&cx, &item_tokens(&cx.policy, &c));
    let b = p.out_values.verdict;
    let l0 = p.stage_out.planes[C_LIMB][LAM_BASE].0;
    p.stage_out.planes[C_LIMB][LAM_BASE] = Fp::new((l0 + 1) % 256);
    let e = forge(&cx, p, b);
    assert!(e.contains("stage OUT-C slot 04") || e.contains("stage OUT-C slot 03"), "refused elsewhere than the margin identity: {e}");
    let mut p = pipe(&cx, &item_tokens(&cx.policy, &c));
    p.stage_out.planes[C_LIMB][LAM_BASE] = Fp::new((l0 + 1) % 256);
    let e2 = refused_before_header(&cx, p, b);
    eprintln!("TOKEN-IO R-C1 | byte limbs off by one: refused at the margin identity ({e}); before the header ({e2})");
}

/// a pipeline whose `tokens` are taken as given (template / control-id
/// checks skipped: the cheating prover's view), consistent downstream
fn cheating_pipe(cx: &Cx, tokens: &[u64]) -> HonestClassify {
    let _cheat = CheatingProver::on();
    pipe(cx, tokens)
}

#[test]
fn r12_a_changed_template_position_is_refused_at_the_template_clause() {
    let cx = cx();
    let mut toks = item_tokens(&cx.policy, &content(&cx, 0x2204));
    toks[3] = 200;
    let p = cheating_pipe(&cx, &toks);
    let b = p.out_values.verdict;
    let e = forge(&cx, p, b);
    assert!(e.contains("stage IN-C slot 01"), "refused elsewhere than the template clause: {e}");
    let p = cheating_pipe(&cx, &toks);
    let e2 = refused_before_header(&cx, p, b);
    eprintln!("TOKEN-IO R-C1 | a changed template id: refused at INC-01 ({e}); before the header ({e2})");
}

#[test]
fn r12_a_content_control_id_is_refused_by_the_ctl_column() {
    let cx = cx();
    let mut toks = item_tokens(&cx.policy, &content(&cx, 0x2205));
    let at = cx.policy.prefix.len() + 2;
    toks[at] = 2; // a control id (< num_special) at a content position
    let p = cheating_pipe(&cx, &toks);
    let b = p.out_values.verdict;
    let e = forge(&cx, p, b);
    assert!(e.contains("stage IN-C H") || e.contains("stage IN-C slot 01"), "refused elsewhere than the control-id lookup: {e}");
    let p = cheating_pipe(&cx, &toks);
    let e2 = refused_before_header(&cx, p, b);
    eprintln!("TOKEN-IO R-C1 | a content control id: refused at stage IN-C's LogUp ({e}); before the header ({e2})");
}

#[test]
fn r12_the_door_refuses_an_unregistered_policy_and_reads_the_margin_vector_itself() {
    let cx = cx();
    let mut rogue = policy_rung_dev();
    rogue.id = "free-text-policy-not-registered".into();
    let e = ClassifierProfile::new(&cx.sh, &cx.tables, 1, norm(), &rogue, n_of(&cx), Tier::R1_MVP).err().expect("an unregistered policy was admitted");
    assert!(e.contains("B-6"), "{e}");
    let mut edited = policy_rung_dev();
    edited.c = 5;
    assert!(ClassifierProfile::new(&cx.sh, &cx.tables, 1, norm(), &edited, n_of(&cx), Tier::R1_MVP).is_err(), "a registered id with another threshold was admitted");
    // B-3: a receipt made under the swapped vector -w does not verify under
    // the verifier's own w (the verifier's statement derives from ITS tables)
    let neg = ClassifierTables::new(cx.tables.v, cx.tables.d, cx.tables.emb.clone(), cx.tables.w_delta.iter().map(|w| -w).collect()).unwrap();
    let model = model_at(&cx.sh, &cx.blocks, RUN_PROFILE_CLASSIFY_RUNG_TC);
    let bound = bind(&cx.sh, &neg, &model, &cx.policy);
    let cxn = Cx { sh: cx.sh.clone(), blocks: cx.blocks.clone(), model, tables: neg, bound, policy: cx.policy.clone() };
    let c = content(&cx, 0x2206);
    let mut p = pipe(&cxn, &item_tokens(&cxn.policy, &c));
    let vn = p.out_values.verdict;
    let rn = prove_with(&cxn, &mut p, vn).unwrap();
    let under_w = Run { st: statement(&cx, rn.st.in_root(), rn.st.verdict()).unwrap(), segs: rn.segs.clone(), dec: rn.dec.clone() };
    assert!(verify(&cx, &under_w).is_err(), "a receipt under the swapped margin vector verified under the verifier's own");
    eprintln!("TOKEN-IO R-C1 | the door: an unregistered or edited policy refused; a swapped-vector receipt refused under the verifier's own vector");
}

#[test]
fn r12_the_ruling_switches_are_in_the_profile_text() {
    let cx = cx();
    let cp = profile(&cx);
    let s = cp.describe_under(RUN_PROFILE_CLASSIFY_RUNG_TC);
    for want in ["B-5 n-public=true", "B-6 fixed-policy-list=true", "B-8 binding=input-endpoint-root", "B-4 fail-closed=true", "mode=verdict-public-bit", "no-output-endpoint"] {
        assert!(s.contains(want), "the profile text lacks {want:?}: {s}");
    }
    assert!(rulings_are_built().is_ok());
    assert_eq!(cp.limbs, 5, "the margin's byte limbs (TF-1)");
    let lay = stage_out_c::layout(&cx.sh, &cp);
    eprintln!("TOKEN-IO R-C1 | stage OUT-C layout: A {} rows, H {} rows at 2^{} ({} elements); margin window {} bits, {} limbs", lay.a_rows, lay.h_rows, lay.log_n, lay.elems(), cp.window_bits, cp.limbs);
}

// ------------------------------------------------------------------ D41: chunks (DESIGN v2.2 §13)

fn statement_chunk(cx: &Cx, root: Digest, verdict: u8, total: usize, index: usize) -> Result<ClassifyRunStatement, String> {
    statement_n(cx, root, verdict, n_of(cx), total, index)
}

/// round 14: a chunk statement naming `n` content ids explicitly
fn statement_n(cx: &Cx, root: Digest, verdict: u8, n: usize, total: usize, index: usize) -> Result<ClassifyRunStatement, String> {
    ClassifyRunStatement::new_chunk(RunShape::new(cx.sh.clone(), L, RUN_PROFILE_CLASSIFY_RUNG_TC)?, ctx(), cx.blocks.iter().map(|b| b.digest()).collect(), &cx.model, &cx.bound, &cx.policy, n, Tier::R1_MVP, root, verdict, total, index)
}

/// **D41, the split (§13.1):** chunks of exactly `size` ids at stride
/// `size - overlap`, consecutive, covering `[0, N)`, the last one
/// end-aligned (overlap >= the plan's); one chunk when N = size; round 14:
/// a short content is one chunk of its length; an empty one and a bad plan
/// refused by name.
#[test]
fn r12_chunk_ranges_cover_the_content_consecutively_with_the_overlap_and_end_align() {
    let plan = ChunkPlan { size: 23, overlap: 4 };
    assert_eq!(chunk_ranges(23, plan).unwrap(), vec![(0, 23)]);
    assert_eq!(chunk_ranges(27, plan).unwrap(), vec![(0, 23), (4, 27)]);
    assert_eq!(chunk_ranges(42, plan).unwrap(), vec![(0, 23), (19, 42)]);
    assert_eq!(chunk_ranges(43, plan).unwrap(), vec![(0, 23), (19, 42), (20, 43)]);
    for total in 23..400 {
        let r = chunk_ranges(total, plan).unwrap();
        assert_eq!(r[0].0, 0);
        assert_eq!(r.last().unwrap().1, total, "covers to the end");
        for w in r.windows(2) {
            assert!(w[1].0 > w[0].0 && w[1].0 + plan.overlap <= w[0].1, "consecutive, overlap at least the plan's: {w:?}");
        }
        assert!(r.iter().all(|(a, b)| b - a == plan.size), "every chunk has exactly size ids");
        assert_eq!(r.len(), 1 + (total - plan.size).div_ceil(plan.size - plan.overlap));
    }
    // ROUND 14 (§15): short content is ONE chunk of its true length
    for total in 1..23 {
        assert_eq!(chunk_ranges(total, plan).unwrap(), vec![(0, total)], "a {total}-id content");
        let c = ChunkRef::derive(total, 0, plan).unwrap();
        assert_eq!((c.index, c.count, c.a, c.b, c.total, c.size, c.overlap), (0, 1, 0, total, total, 23, 4));
        assert!(ChunkRef::derive(total, 1, plan).is_err(), "no chunk 1 of a short content");
    }
    assert!(chunk_ranges(0, plan).unwrap_err().contains("an empty content has no chunk"));
    assert!(chunk_ranges(30, ChunkPlan { size: 4, overlap: 4 }).unwrap_err().contains("0 <= overlap < size"));
    let c = ChunkRef::derive(43, 2, plan).unwrap();
    assert_eq!((c.count, c.a, c.b), (3, 20, 43));
    assert!(ChunkRef::derive(43, 3, plan).is_err(), "no chunk 3 of 3");
    assert_eq!(chunk_overlap_of(RUN_PROFILE_CLASSIFY_RUNG_TC).unwrap(), 4);
    assert!(profile(&cx()).describe_under(RUN_PROFILE_CLASSIFY_RUNG_TC).contains("chunk-size=23 chunk-overlap=4 chunk-split=end-aligned"));
}

/// **D41, a chunk proof is bound to its place:** chunk 1 of a 27-id item
/// proves and verifies; read as chunk 0, or as a chunk of another total, it
/// is refused (the transcript absorbed `classify-chunk`); an index the plan
/// does not give is refused at the door.
#[test]
fn r12_a_chunk_receipt_is_bound_to_its_index_and_total() {
    let cx = cx();
    let n = n_of(&cx);
    let whole: Vec<u64> = content(&cx, 0x4c41).into_iter().chain(content(&cx, 0x4c42).into_iter().take(4)).collect();
    assert_eq!(whole.len(), n + 4);
    let ch = ChunkRef::derive(whole.len(), 1, ChunkPlan { size: n, overlap: 4 }).unwrap();
    assert_eq!((ch.count, ch.a, ch.b), (2, 4, n + 4));
    let mut p = pipe(&cx, &item_tokens(&cx.policy, &whole[ch.a..ch.b]));
    let cp = profile(&cx);
    let spec = input_endpoint_spec(&cx.sh, ctx(), &cp).unwrap();
    let (root, owner) = seal_input(&spec, &p.in_plane, &cx.sh.hash_tag()).unwrap();
    let verdict = p.out_values.verdict;
    let st = statement_chunk(&cx, root, verdict, whole.len(), 1).unwrap();
    assert_eq!(st.chunk(), ch);
    let mut segs = Vec::new();
    let (_, dec) = prove_classify_run(&st, &cx.blocks, &cx.bound, &mut ClassifySource(&mut p), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .unwrap();
    let r = Run { st, segs, dec };
    verify(&cx, &r).expect("chunk 1 verifies");
    owner_check_input(&r.st, &r.dec, &whole[ch.a..ch.b]).expect("the owner's check on the chunk's slice");
    assert!(owner_check_input(&r.st, &r.dec, &whole[..n]).is_err(), "chunk 0's slice is not chunk 1's plane");
    let as0 = Run { st: statement_chunk(&cx, root, verdict, whole.len(), 0).unwrap(), segs: r.segs.clone(), dec: r.dec.clone() };
    let e0 = verify(&cx, &as0).err().expect("a chunk-1 receipt verified as chunk 0");
    let as_other = Run { st: statement_chunk(&cx, root, verdict, whole.len() + 1, 1).unwrap(), segs: r.segs.clone(), dec: r.dec.clone() };
    let e1 = verify(&cx, &as_other).err().expect("a chunk receipt verified under another total");
    assert!(statement_chunk(&cx, root, verdict, whole.len(), 2).err().expect("chunk 2 of 2 was admitted").contains("the plan gives 2 chunks"));
    eprintln!("TOKEN-IO R-C1 | D41 chunk 1 of 2 [{}, {}) proves, verifies, owner-checks | refused: read as chunk 0 ({e0}); another total ({e1}); index 2 at the door", ch.a, ch.b);
}

// ------------------------------------------------------------------ round 14: short items (DESIGN v2.4 §15)

fn profile_n(cx: &Cx, n: usize) -> ClassifierProfile {
    ClassifierProfile::new(&cx.sh, &cx.tables, 1, norm(), &cx.policy, n, Tier::R1_MVP).expect("the classifier profile")
}

fn pipe_n(cx: &Cx, tokens: &[u64], n: usize) -> HonestClassify {
    honest_classify(&vec![cx.sh.clone(); L], &profile_n(cx, n), &cx.tables, &cx.blocks, tokens).unwrap_or_else(|e| panic!("the honest classifier pipeline refused: {e}"))
}

/// seal, build the statement of an `n`-id item (one chunk) and prove
fn prove_with_n(cx: &Cx, p: &mut HonestClassify, verdict: u8, n: usize) -> Result<Run, String> {
    let cp = profile_n(cx, n);
    let spec = input_endpoint_spec(&cx.sh, ctx(), &cp)?;
    let (root, owner) = seal_input(&spec, &p.in_plane, &cx.sh.hash_tag())?;
    let st = statement_n(cx, root, verdict, n, n, 0)?;
    let mut segs = Vec::new();
    let (_, dec) = prove_classify_run(&st, &cx.blocks, &cx.bound, &mut ClassifySource(p), owner, &mut |_, b| {
        segs.push(b);
        Ok(())
    })?;
    Ok(Run { st, segs, dec })
}

fn forge_n(cx: &Cx, mut p: HonestClassify, verdict: u8, n: usize) -> String {
    let r = {
        let _cheat = CheatingProver::on();
        prove_with_n(cx, &mut p, verdict, n).unwrap_or_else(|e| panic!("the cheating prover did not produce a receipt: {e}"))
    };
    verify(cx, &r).err().expect("A SHORT-ITEM FORGERY VERIFIED")
}

fn refused_before_header_n(cx: &Cx, mut p: HonestClassify, verdict: u8, n: usize) -> String {
    let h0 = classify_headers();
    let e = prove_with_n(cx, &mut p, verdict, n).err().expect("the honest prover accepted a forged short-item pipeline");
    assert_eq!(classify_headers(), h0, "refused only AFTER the run header was built: {e}");
    e
}

/// a short content of `n` ids (the first `n` of [`content`])
fn short_content(cx: &Cx, n: usize, seed: u64) -> Vec<u64> {
    content(cx, seed)[..n].to_vec()
}

/// **ROUND 14: a short item (20 ids; one chunk is 23) proves and verifies
/// at the library**: the item is prefix ‖ 20 ids ‖ suffix ‖ the pad id three
/// times; stage OUT-C reads the public verdict row 28 = P0 + n + S - 1, and
/// the margin there does not depend on what the pad positions hold (causal
/// attention: other ids there give the same margin); the owner's check holds
/// and refuses another content; read under another `n` (21, or the full 23)
/// the receipt is refused; a statement whose `n` is not its chunk's length is
/// refused at the door.
#[test]
fn r14_a_short_item_proves_and_verifies_and_reads_its_public_verdict_row() {
    let cx = cx();
    let n = n_of(&cx) - 3;
    let c = short_content(&cx, n, 0x5310);
    let cp = profile_n(&cx, n);
    assert_eq!((cp.item_len(), cp.pad_positions(), cp.verdict_row()), (29, 3, 28));
    let toks = cp.tokens_of(&c).unwrap();
    assert_eq!(toks.len(), cx.sh.tokens);
    assert_eq!(&toks[29..], &[cx.policy.pad; 3], "the trailing positions hold the public pad id");
    assert_eq!(toks[28], cx.policy.suffix[0], "the suffix follows the content");
    assert!(cp.describe_under(RUN_PROFILE_CLASSIFY_RUNG_TC).contains("n=20 S=1 item-length=29 pad-id=2 pad-positions=3 verdict-row=28"));
    let mut p = pipe_n(&cx, &toks, n);
    // causality: the verdict row does not read the pad rows
    let other_pads = {
        let _cheat = CheatingProver::on();
        let mut t = toks.clone();
        t[29..].copy_from_slice(&[200, 201, 202]);
        pipe_n(&cx, &t, n).out_values.margin
    };
    assert_eq!(other_pads, p.out_values.margin, "the margin at the verdict row depends on the pad positions");
    // the row read is the verdict row 28, not T - 1 (a pad row); on this fixture
    // the two rows differ (the margins of the short and the full item can
    // coincide: the synthetic blocks keep the suffix row close to its token's)
    let b_out = p.planes.last().unwrap().clone();
    assert_eq!(p.out_values.x, stage_out_c::row_of(&cp, &b_out, 28), "the pipeline read the verdict row");
    assert_ne!(stage_out_c::row_of(&cp, &b_out, 28), stage_out_c::row_of(&cp, &b_out, cp.tokens - 1), "the verdict row and the last pad row differ");
    let v = p.out_values.verdict;
    let r = prove_with_n(&cx, &mut p, v, n).unwrap_or_else(|e| panic!("the short item refused: {e}"));
    verify(&cx, &r).unwrap_or_else(|e| panic!("the short item did not verify: {e}"));
    assert_eq!((r.st.chunk().count, r.st.chunk().a, r.st.chunk().b, r.st.chunk().size), (1, 0, n, n_of(&cx)));
    owner_check_input(&r.st, &r.dec, &c).unwrap_or_else(|e| panic!("the owner's check: {e}"));
    let mut other = c.clone();
    other[0] = if other[0] + 1 < cx.policy.v as u64 { other[0] + 1 } else { cx.policy.num_special };
    assert!(owner_check_input(&r.st, &r.dec, &other).is_err(), "another content passed the owner's check");
    assert!(owner_check_input(&r.st, &r.dec, &content(&cx, 0x5310)[..n + 1]).is_err(), "a longer content passed the owner's check");
    for m in [n + 1, n_of(&cx)] {
        let as_m = Run { st: statement_n(&cx, r.st.in_root(), v, m, m, 0).unwrap(), segs: r.segs.clone(), dec: r.dec.clone() };
        assert!(verify(&cx, &as_m).is_err(), "a {n}-id receipt verified as a {m}-id item");
    }
    let e = statement_n(&cx, r.st.in_root(), v, n, n + 5, 0).err().expect("a statement whose n is not its chunk's length was admitted");
    assert!(e.contains("chunk 0 of a 25-id content holds 23 ids; the statement's n is 20"), "{e}");
    eprintln!("TOKEN-IO R14 | a 20-id item (chunk size 23): proved and verified at the public verdict row 28 (margin {}), owner-checked; read as 21 or 23 ids refused", p.out_values.margin);
}

/// **ROUND 14: a doctored pad position is refused.** The cheating prover
/// puts another id at a pad position (a content-like id, another control id,
/// the zero id): the verifier refuses at stage IN-C's template clause (or its
/// LogUp, for an id outside the control class); the honest prover refuses the
/// same item before any header.
#[test]
fn r14_a_doctored_pad_position_is_refused() {
    let cx = cx();
    let n = n_of(&cx) - 3;
    let c = short_content(&cx, n, 0x5311);
    let toks = profile_n(&cx, n).tokens_of(&c).unwrap();
    for (at, id, sites) in [(30usize, 200u64, &["stage IN-C slot 01", "stage IN-C H"][..]), (31, 3, &["stage IN-C slot 01"][..]), (29, 0, &["stage IN-C slot 01"][..])] {
        let mut t = toks.clone();
        t[at] = id;
        let p = {
            let _cheat = CheatingProver::on();
            pipe_n(&cx, &t, n)
        };
        let b = p.out_values.verdict;
        let e = forge_n(&cx, p, b, n);
        assert!(sites.iter().any(|s| e.contains(s)), "pad position {at} = {id}: refused elsewhere than {sites:?}: {e}");
        let p = {
            let _cheat = CheatingProver::on();
            pipe_n(&cx, &t, n)
        };
        let e2 = refused_before_header_n(&cx, p, b, n);
        eprintln!("TOKEN-IO R14 | pad position {at} = {id}: refused by the verifier ({e}); by the honest prover before the header ({e2})");
    }
}

/// **ROUND 14: the margin is read at the PUBLIC verdict row.** A cheating
/// prover that computes the margin from row T - 1 (the last pad row) instead
/// of row P0 + n + S - 1 is refused by stage OUT-C.
#[test]
fn r14_a_margin_read_at_another_row_than_the_verdict_row_is_refused() {
    let cx = cx();
    let n = n_of(&cx) - 3;
    let c = short_content(&cx, n, 0x5312);
    let cp = profile_n(&cx, n);
    let mut p = pipe_n(&cx, &cp.tokens_of(&c).unwrap(), n);
    let honest = p.out_values.margin;
    let b_out = p.planes.last().unwrap().clone();
    let ov = stage_out_c::out_values(&cp, &cx.tables, &stage_out_c::row_of(&cp, &b_out, cp.tokens - 1), false).unwrap();
    assert_ne!(ov.margin, honest, "row T - 1 gives another margin on this fixture");
    p.stage_out = stage_out_c::witness_from_values(&cp, &ov).unwrap();
    let b = ov.verdict;
    p.out_values = ov;
    let e = forge_n(&cx, p, b, n);
    assert!(e.contains("OUT-C") || e.contains("boundary"), "refused elsewhere than stage OUT-C: {e}");
    eprintln!("TOKEN-IO R14 | a margin read at row T - 1 instead of the verdict row 28: refused ({e})");
}

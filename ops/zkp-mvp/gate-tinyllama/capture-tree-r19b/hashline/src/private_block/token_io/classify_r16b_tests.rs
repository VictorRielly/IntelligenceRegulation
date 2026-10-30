//! **TOKEN I/O ROUND 16b: REVIEW_R16's F-1 and N-r16-1.** TEST CODE ONLY.
//!
//! * **F-1 (D45(2): one fixed policy list).** Each R13 Shieldstral classifier
//!   run profile (T128, T256) admits EXACTLY the three moderate D37 category
//!   policies through the whole statement constructor, with tables bound to
//!   the real export's margin parameters. Round 12's
//!   `shieldstral-1.0-3b-card-unsafe/1` (test-only since round 16b) is refused
//!   BY NAME: at the registry lookup the CLI's `--policy` uses, at the
//!   classifier door and at the statement constructor, although its margin
//!   parameters are the export's (only the registry refuses it).
//! * **N-r16-1 (the exact whole-run figures at L = 26).** Floors T128 96 /
//!   T256 95; total, column, LogUp and PCS + sumcheck terms to 0.01 bit
//!   (REVIEW_R16 §3's first-principles recompute, `r16/bits_r16.json`); the
//!   per-block term (N + 4 T_d - 1) / p^2; the LogUp term is the two stages'
//!   plus L = 26 block terms (the reviewer's `bits-l` mutant, one block
//!   instead of L, gives T128 floor 98 and fails here); `--min-bits` at the
//!   floor passes the verifier's floor door and one more bit is refused.

// this module is `token_io::classify_r16_tests::r16b` (registered by a
// `#[path]` line at the end of classify_r16_tests.rs): `tio` is token_io,
// `pb` is private_block
use super::super as tio;
use super::super::super as pb;
use tio::classify::*;
use tio::classify_run::*;
use tio::classify_tied::BoundClassifierTables;
use tio::run::{r13_block_logup_numerator, VerifierPolicy};
use tio::*;
use pb::run::{RunShape, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256};
use pb::shape::{Shape, R13_SHIELD_T128_H24, R13_SHIELD_T256_H24};
use pb::trained_statement::TrainedModelStatement;

const CARD_ID: &str = "shieldstral-1.0-3b-card-unsafe/1";
const DEV_ID: &str = "rung-tc-synthetic-policy-dev/1";
const MODERATE: [&str; 3] = ["shieldstral-1.0-3b-moderate-sexual/1", "shieldstral-1.0-3b-moderate-violence/1", "shieldstral-1.0-3b-moderate-hate/1"];
/// the real export's classifier final norm (its `token_io_parameters`)
const SH_NORM: FinalNorm = FinalNorm { g0: 127, cn: 1024, tn: 10, ceps: 2439 };
/// Shieldstral-1.0-3B's 26 layers
const L: usize = 26;

/// the two R13 Shieldstral classifier run profiles, each at its block shape
/// (the R13 profile tests' generic class calibration; the figures read lengths)
fn profiles() -> [(&'static str, Shape); 2] {
    let cal = r13_census_calibration();
    [
        (RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, Shape::accuracy_trained(R13_SHIELD_T128_H24, &cal, 9, 20).unwrap()),
        (RUN_PROFILE_CLASSIFY_R13_SHIELD_T256, Shape::accuracy_trained(R13_SHIELD_T256_H24, &cal, 9, 20).unwrap()),
    ]
}

/// a synthetic trained statement of L R13 layer records at `sh` (each its own
/// gate shift) and V = 131,072 x 3,072 synthetic tables (805 MB) bound to it
/// with the REAL export's margin parameters (yes 13059, no 2649, scale bits
/// 0x3ed11ff597db2fb6, c 0: `classifier_margin_parameters` of the T128 export,
/// REVIEW_R16 §4), so the policy list is the only thing that decides
fn bound_at(profile: &'static str, sh: &Shape) -> (TrainedModelStatement, BoundClassifierTables) {
    let gates: Vec<u32> = (0..L).map(|k| 17 + (k as u32 % 8)).collect();
    let model = r13_synthetic_model(sh, profile, &gates, [9; 32], 1.0 / 512.0);
    let export_margin = Policy { id: "r16b-the-export-margin-parameters (binding only)".into(), ..policy_shieldstral_moderate_hate() };
    assert_eq!((export_margin.yes, export_margin.no, export_margin.margin_scale_bits, export_margin.c), (13059, 2649, 0x3ed1_1ff5_97db_2fb6, 0));
    let (v, d) = (export_margin.v, sh.width);
    let emb: Vec<i16> = (0..v * d).map(|i| ((i * 7919) % 12_001) as i16 - 6_000).collect();
    let w: Vec<i16> = (0..d).map(|i| (i as i16 % 2000) - 1000).collect();
    let tables = ClassifierTables::new(v, d, emb, w).unwrap();
    let bound = BoundClassifierTables::synthetic_for_relation_tests(tables, 1, SH_NORM, sh, profile, &model, &export_margin).unwrap();
    (model, bound)
}

/// the content length of a full chunk under `policy` at `sh` (1 where the
/// template leaves none: the door refuses such a policy anyway)
fn chunk_of(sh: &Shape, policy: &Policy) -> usize {
    sh.tokens.checked_sub(policy.prefix.len() + policy.suffix.len()).filter(|n| *n > 0).unwrap_or(1)
}

/// the classifier run statement at `profile` under `policy`, L blocks
fn statement(profile: &'static str, sh: &Shape, model: &TrainedModelStatement, bound: &BoundClassifierTables, policy: &Policy) -> Result<ClassifyRunStatement, String> {
    let digests: Vec<Digest> = model.layers.iter().map(|r| r.block_digest).collect();
    ClassifyRunStatement::new(RunShape::new(sh.clone(), L, profile)?, tio::tests::ctx(), digests, model, bound, policy, chunk_of(sh, policy), Tier::R1_MVP, [7u8; 32], 1)
}

// ------------------------------------------------------------------ F-1

/// **REVIEW_R16 F-1 (D45(2)).** Failing first on frozen-r16 (the card policy in
/// the production list: both profiles admitted four policies).
#[test]
fn r16b_each_r13_shieldstral_profile_admits_exactly_the_three_moderate_policies_and_refuses_the_card_by_name() {
    let card = policy_shieldstral_card();
    assert_eq!(card.id, CARD_ID);
    for (profile, sh) in profiles() {
        let (model, bound) = bound_at(profile, &sh);
        // every pre-registered policy through the whole statement constructor
        // (check_for's margin binding, the classifier door, the chunk plan)
        let mut admitted = Vec::new();
        for p in registered_policies() {
            match statement(profile, &sh, &model, &bound, &p) {
                Ok(st) => {
                    eprintln!("TOKEN-IO R16b | F-1 | {profile}: ADMITS {} (P0 {}, chunk {}, floor {} bits)", p.id, p.prefix.len(), chunk_of(&sh, &p), st.whole_run().floor_bits);
                    admitted.push(p.id.clone());
                }
                Err(e) => eprintln!("TOKEN-IO R16b | F-1 | {profile}: refuses {}: {e}", p.id),
            }
        }
        assert_eq!(admitted, MODERATE.to_vec(), "{profile} admits {admitted:?}, not exactly the three moderate D37 category policies (D45(2), REVIEW_R16 F-1)");
        // the card policy, handed over directly: refused by name at the door
        // and at the statement constructor, past check_for (its margin
        // parameters are the bound export's)
        let e = ClassifierProfile::new(&sh, bound.tables(), bound.bos(), bound.norm(), &card, chunk_of(&sh, &card), Tier::R1_MVP).err().expect("THE CARD POLICY PASSED THE CLASSIFIER DOOR (REVIEW_R16 F-1)");
        assert!(e.contains(CARD_ID) && e.contains("is not the pre-registered one of that name"), "{e}");
        let e = statement(profile, &sh, &model, &bound, &card).err().expect("THE CARD POLICY PASSED THE STATEMENT CONSTRUCTOR (REVIEW_R16 F-1)");
        assert!(e.contains(CARD_ID) && e.contains("is not the pre-registered one of that name"), "{e}");
        eprintln!("TOKEN-IO R16b | F-1 | {profile}: admits exactly {admitted:?}; {CARD_ID} refused by name at the door and the statement constructor ({e})");
        drop((model, bound));
    }
    // the registry lookup the CLI's --policy uses (prove, verify, input-owner, label)
    let e = policy_by_id(CARD_ID).err().expect("THE CARD POLICY IS STILL PRE-REGISTERED (REVIEW_R16 F-1)");
    assert!(e.contains(CARD_ID) && e.contains("is not a pre-registered policy"), "{e}");
    // its margin parameters, template class and vocabulary are those of the
    // admitted three: nothing but the registry refuses it
    let hate = policy_shieldstral_moderate_hate();
    assert_eq!((card.yes, card.no, card.margin_scale_bits, card.c, card.v, card.pad, card.num_special, card.suffix.clone()), (hate.yes, hate.no, hate.margin_scale_bits, hate.c, hate.v, hate.pad, hate.num_special, hate.suffix.clone()));
    // the production list (no test policy is registered on this thread): the
    // synthetic rung's dev policy (V = 300) and the D37 category list, in order
    let ids: Vec<String> = registered_policies().into_iter().map(|p| p.id).collect();
    assert_eq!(ids, [DEV_ID, MODERATE[0], MODERATE[1], MODERATE[2]].map(String::from).to_vec(), "the pre-registered list (B-6, D45(2))");
    let shield: Vec<Policy> = registered_policies().into_iter().filter(|p| p.v == 131_072).collect();
    assert_eq!(shield, shieldstral_category_policies(), "the Shieldstral-vocabulary entries are exactly the D37 category list");
    for id in MODERATE {
        assert_eq!(policy_by_id(id).unwrap().id, id);
    }
    eprintln!("TOKEN-IO R16b | F-1 | the pre-registered list is {ids:?}; {CARD_ID} refused by name ({e})");
}

// ------------------------------------------------------------------ N-r16-1

/// **REVIEW_R16 N-r16-1 [COUNTED]: the exact whole-run figures at L = 26.**
#[test]
fn r16b_the_r13_shieldstral_whole_run_floors_and_terms_are_pinned_exactly() {
    let p2 = 2.0 * (P as f64).log2();
    let t_d: u128 = 512 + 4 * 4096;
    // REVIEW_R16 §3 (r16/bits_r16.json, the reviewer's recompute; identical at
    // every moderate policy): profile, REVIEW_R13 §6's N per block, floor,
    // total, column, LogUp, PCS + sumcheck (log2), per-block LogUp bits, and the
    // stage terms OUT-C / IN-C (log2)
    let want = [
        (RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, 66_879_488u128, 96u32, -96.8601f64, -98.7928f64, -97.3014f64, -106.1732f64, 102.003f64, -112.28f64, -107.09f64),
        (RUN_PROFILE_CLASSIFY_R13_SHIELD_T256, 154_730_496, 95, -95.9124, -99.0096, -96.0930, -106.1732, 100.794, -112.28, -107.09),
    ];
    let near = |got: f64, want: f64, tol: f64, what: &str| assert!((got - want).abs() < tol, "{what}: {got:.6}, pinned {want} (±{tol})");
    for ((profile, sh), (wp, n_review, floor, total, column, logup, omitted, per_block, out_c, in_c)) in profiles().into_iter().zip(want) {
        assert_eq!(profile, wp);
        // the per-block term (N + 4 T_d - 1) / p^2
        let blk = r13_block_logup_numerator(&sh).expect("an R13 shape has an R13 term");
        assert_eq!(blk, n_review + 4 * t_d - 1, "{profile}: the per-block numerator");
        near(p2 - (blk as f64).log2(), per_block, 0.01, &format!("{profile}: per-block LogUp bits"));
        let (model, bound) = bound_at(profile, &sh);
        for id in MODERATE {
            let policy = policy_by_id(id).unwrap();
            let st = statement(profile, &sh, &model, &bound, &policy).unwrap();
            let w = st.whole_run();
            let cp = ClassifierProfile::new(&sh, bound.tables(), bound.bos(), bound.norm(), &policy, chunk_of(&sh, &policy), Tier::R1_MVP).unwrap();
            assert_eq!(*w, whole_run_of_classifier(&sh, L, &cp), "{profile} / {id}: the statement's figure is the derived one");
            assert_eq!(w.openings, 4 * L + 8, "{profile} / {id}: openings");
            assert_eq!(w.floor_bits, floor, "{profile} / {id}: the whole-run floor (REVIEW_R16 N-r16-1)");
            near(w.total_log2, total, 0.01, &format!("{profile} / {id}: whole-run total"));
            near(w.column_log2, column, 0.01, &format!("{profile} / {id}: column term"));
            near(w.logup_log2, logup, 0.01, &format!("{profile} / {id}: LogUp term"));
            near(w.omitted_log2, omitted, 0.01, &format!("{profile} / {id}: PCS + sumcheck term"));
            // the LogUp term is the two stages' plus L block terms, each block
            // charged once (not one block for the run: the `bits-l` mutant)
            let (on, or) = tio::stage_out_c::logup_size(&tio::stage_out_c::layout(&sh, &cp));
            let (inn, inr) = tio::stage_in_c::logup_size(&tio::stage_in_c::layout(&sh, &cp), &cp);
            let lg = clog2(cp.d_pad) as u128;
            let (out_num, in_num) = (on + 3 * or - 1, inn + inr * (3 + lg) + cp.tokens as u128 * lg);
            near((out_num as f64).log2() - p2, out_c, 0.01, &format!("{profile} / {id}: stage OUT-C term"));
            near((in_num as f64).log2() - p2, in_c, 0.01, &format!("{profile} / {id}: stage IN-C term"));
            near(w.logup_log2, ((out_num + in_num + L as u128 * blk) as f64).log2() - p2, 1e-9, &format!("{profile} / {id}: LogUp = stages + {L} blocks"));
            assert!(w.logup_log2 > ((L as u128 * blk) as f64).log2() - p2 - 1e-9, "{profile} / {id}: the LogUp term is below the {L} blocks' share");
            eprintln!(
                "TOKEN-IO R16b | N-r16-1 [COUNTED] | {profile} / {id}: whole run 2^{:.4} (column 2^{:.4}, LogUp 2^{:.4} = OUT-C {out_num} + IN-C {in_num} + {L} x {blk}, PCS+sumcheck 2^{:.4}), {} openings, floor {} bits",
                w.total_log2, w.column_log2, w.logup_log2, w.omitted_log2, w.openings, w.floor_bits
            );
        }
        // --min-bits: at the floor the verifier passes its floor door (and stops
        // at the empty receipt); one bit more is refused at the door
        let st = statement(profile, &sh, &model, &bound, &policy_by_id(MODERATE[2]).unwrap()).unwrap();
        let at = verify_classify_run(&st, &[], &bound, &[], VerifierPolicy { min_whole_run_bits: floor }).err().expect("an empty receipt verified");
        assert!(!at.contains("below the verifier's minimum"), "{profile}: --min-bits {floor} was refused at the floor door: {at}");
        let above = verify_classify_run(&st, &[], &bound, &[], VerifierPolicy { min_whole_run_bits: floor + 1 }).err().unwrap();
        assert!(above.contains("below the verifier's minimum"), "{profile}: --min-bits {} was not refused at the floor door: {above}", floor + 1);
        assert_eq!(tio::classify_tied::min_bits_floor(profile), 95, "{profile}: D27's CLI floor");
        eprintln!("TOKEN-IO R16b | N-r16-1 | {profile}: floor {floor}; --min-bits {floor} passes the floor door ({at}); --min-bits {} refused ({above})", floor + 1);
        drop((st, model, bound));
    }
}

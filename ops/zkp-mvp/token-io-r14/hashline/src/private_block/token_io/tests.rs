//! **TOKEN I/O R1: THE ACCEPTANCE TESTS.** TEST CODE ONLY. Public synthetic
//! data only (R0's model words and a seeded generic model); no privacy claim.
//!
//! 1. the counted layout equals the design counter's figures for this rung
//!    (`results/zk60_token_io_r1_20261017/counts/r1_counts.json`, written
//!    before the construction; the per-row head of D25 T4 as amended);
//! 2. honest runs (R0's model; a generic model: dense weights, distinct
//!    embedding rows, heads that differ, per-row multipliers that differ)
//!    prove and verify; the owner checks rebuild both token roots and the
//!    decommitted id is the reference next token (the fresh-process verify
//!    from bytes is the `#[ignore]`d pair at the end, run separately);
//! 3. every control of DESIGN 6.1's table, proved by the CHEATING prover and
//!    refused by the verifier, actual catching site against the predicted;
//! 4. the token-I/O door (constants outside their classes, wrong tables, the
//!    variant) on both sides;
//! 5. the D16 rule-5 audit of the new layouts.

use super::run::*;
use super::stage_in::{self, StageInWitness};
use super::stage_out::{self, StageOutWitness};
use super::*;
use super::super::protocol::CheatingProver;
use super::super::run::{RunShape, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32, RUN_PROFILE_TOKEN_IO_RUNG_TC, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32};
use super::super::trained_statement::{IntegerCalibration, LayerRecord, ModelSource, Provenance, SourceKind, TrainedModelStatement};
use super::super::BlockPublic;
use super::r0_words::*;

const L: usize = 2;

/// the verifier policy of the R1 DEVELOPMENT runs (D27; review TR-1): the
/// rung's own derived whole-run figure, 93 whole bits (its blocks and
/// boundaries are the 2^10 development geometry, 2^-96.13 per opening). The
/// MVP tier's ~95 bits are stated at the named workload (Llama-3-8B T512),
/// not at this fixture; `tr1_*` shows a 94-bit policy refusing this rung.
const R1_DEV_POLICY: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 93 };

pub(super) fn rung() -> Shape {
    Shape::rung_tc(&super::super::trained_calib_tests::rung_tc_calibration()).expect("the trained-calibration rung")
}

pub(super) fn ctx() -> Digest {
    *blake3::hash(b"token I/O R1: synthetic run context").as_bytes()
}

/// the R1 final norm: tn 11 gives the window exactly 32 bits at width 384;
/// the refusal-free multiplier `g0 Cn = 127 * 2^tn` (DESIGN C-7)
pub(super) fn norm() -> FinalNorm {
    FinalNorm { g0: 127, cn: 2048, tn: 11, ceps: 33_554_467 }
}

pub(super) fn lcg(s: &mut u64) -> u64 {
    *s = s.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
    *s >> 33
}

/// `l` dense trained-calibration blocks, each its own words (the dense
/// recipe rotated per layer, as `trained_stack_tests`)
pub(super) fn blocks(sh: &Shape, l: usize) -> Vec<BlockPublic> {
    let (w0, _) = super::super::trained_calib_tests::trained_dense_words(sh, super::super::trained_calib_tests::TRAINED_BANDS);
    (0..l)
        .map(|k| {
            let mut w = w0.clone();
            for (i, m) in w.iter_mut().enumerate() {
                let len = m.len();
                m.rotate_left((k * (7 + i)) % len);
            }
            let (p, f) = super::super::dense_tests::statement_of_words(sh, &w);
            BlockPublic::new(p, f)
        })
        .collect()
}

/// R0's model words (300 x 16) tiled to the block width; multipliers 1
/// (R0's semantics exactly)
fn r0_tables(d: usize) -> TokenTables {
    let (v, d0) = (R0_V, R0_D);
    let emb = (0..v * d).map(|x| R0_EMB[(x / d) * d0 + (x % d) % d0]).collect();
    let head = (0..v * d).map(|x| R0_HEAD[(x / d) * d0 + (x % d) % d0]).collect();
    TokenTables::new(v, d, emb, head, vec![1; v]).expect("R0's tables")
}

/// a GENERIC model: dense int16 embedding with distinct rows (|x| <= 6000,
/// the dense recipe's input band), dense nonzero int8 head, per-row
/// multipliers across the whole class [1, 2^12]
pub(super) fn generic_tables(d: usize, seed: u64) -> TokenTables {
    generic_tables_v(300, d, seed)
}

/// the generic recipe at any vocabulary size (R2's multi-row fixtures)
pub(super) fn generic_tables_v(v: usize, d: usize, seed: u64) -> TokenTables {
    let mut s = seed;
    let emb: Vec<i16> = (0..v * d).map(|_| (lcg(&mut s) % 12_001) as i16 - 6_000).collect();
    let head: Vec<i8> = (0..v * d)
        .map(|_| {
            let x = (lcg(&mut s) % 254) as i64 - 127;
            (if x >= 0 { x + 1 } else { x }) as i8
        })
        .collect();
    let mult: Vec<i64> = (0..v).map(|_| 1 + (lcg(&mut s) % 4096) as i64).collect();
    TokenTables::new(v, d, emb, head, mult).expect("the generic tables")
}

pub(super) fn model(sh: &Shape, blocks: &[BlockPublic]) -> TrainedModelStatement {
    model_at(sh, blocks, RUN_PROFILE_TOKEN_IO_RUNG_TC)
}

/// the synthetic trained-model statement under any token-I/O run profile
pub(super) fn model_at(sh: &Shape, blocks: &[BlockPublic], run_profile: &str) -> TrainedModelStatement {
    let recs: Vec<LayerRecord> = blocks.iter().enumerate().map(|(k, b)| LayerRecord::of_block(k as u32, b, vec![])).collect();
    model_with_records(sh, recs, run_profile)
}

/// the synthetic statement of `l` layers that are all ONE block (the
/// censuses: an 8B block is 0.24 GB, so it is never cloned; its record is)
pub(super) fn model_of_one(sh: &Shape, blk: &BlockPublic, l: usize, run_profile: &str) -> TrainedModelStatement {
    let r0 = LayerRecord::of_block(0, blk, vec![]);
    let recs: Vec<LayerRecord> = (0..l).map(|k| LayerRecord { index: k as u32, ..r0.clone() }).collect();
    model_with_records(sh, recs, run_profile)
}

pub(super) fn model_with_records(sh: &Shape, recs: Vec<LayerRecord>, run_profile: &str) -> TrainedModelStatement {
    model_with_records_prov(sh, recs, run_profile, 1.0 / 512.0, [0; 32])
}

/// TOKEN ROUND 14: the synthetic statement naming an export's residual unit
/// and `profile.json` digest (the classifier capture fixture's tables are
/// derived under that profile: REVIEW_R13 N-r13-1)
pub(super) fn model_with_records_prov(sh: &Shape, recs: Vec<LayerRecord>, run_profile: &str, residual_unit: f64, export_profile_sha256: [u8; 32]) -> TrainedModelStatement {
    let src = ModelSource {
        kind: SourceKind::PublicSyntheticRecipe,
        repo: "hashline/token-io-r1/synthetic".into(),
        revision: "token-io-r1".into(),
        weights_sha256: [0; 32],
        config_sha256: [0; 32],
        checkpoint_parameters: 0,
        checkpoint_layers: recs.len() as u32,
    };
    let mut prov = Provenance::recipe("token-io-r1/synthetic", residual_unit, [5; 32], [6; 32]);
    prov.export_profile_sha256 = export_profile_sha256;
    prov.rope_theta = super::super::shape::trained_rope_theta(sh.profile).expect("a trained profile");
    let cal = IntegerCalibration::as_the_code_proves(sh, &prov);
    // the development rung admits a synthetic recipe; a trained profile
    // (R2's TinyLlama) takes the test-only constructor that says so
    TrainedModelStatement::new(sh, run_profile, src.clone(), cal.clone(), recs.clone())
        .or_else(|_| TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(sh, run_profile, src, cal, recs))
        .expect("the synthetic trained-model statement")
}

pub(super) struct Fx {
    pub name: &'static str,
    pub sh: Shape,
    pub blocks: Vec<BlockPublic>,
    pub tables: TokenTables,
    pub model: TrainedModelStatement,
    pub tokens: Vec<u64>,
    pub norm: FinalNorm,
    pub bos: u64,
}

/// R0's synthetic model: V01's eight tokens, then 24 more from a fixed stream
pub(super) fn fx_r0() -> Fx {
    let sh = rung();
    let blocks = blocks(&sh, L);
    let model = model(&sh, &blocks);
    let mut tokens = R0_V01_TOKENS.to_vec();
    let mut s = 0x7231_7230u64;
    while tokens.len() < sh.tokens {
        tokens.push(lcg(&mut s) % R0_V as u64);
    }
    Fx { name: "r0-model", tables: r0_tables(sh.width), sh, blocks, model, tokens, norm: norm(), bos: R0_BOS }
}

/// the generic model
pub(super) fn fx_generic() -> Fx {
    let sh = rung();
    let blocks = blocks(&sh, L);
    let model = model(&sh, &blocks);
    let mut s = 0x6765_6e65u64;
    let mut tokens = vec![1u64];
    while tokens.len() < sh.tokens {
        tokens.push(lcg(&mut s) % 300);
    }
    Fx { name: "generic", tables: generic_tables(sh.width, 0x7531_6765), sh, blocks, model, tokens, norm: norm(), bos: 1 }
}

pub(super) fn profile(fx: &Fx) -> TokenProfile {
    TokenProfile::new(&fx.sh, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, Tier::R1_MVP).expect("the R1 token profile")
}

pub(super) fn statement(fx: &Fx, roots: (Digest, Digest), variant: SelectorVariant) -> Result<TokenRunStatement, String> {
    TokenRunStatement::new(RunShape::new(fx.sh.clone(), fx.blocks.len(), RUN_PROFILE_TOKEN_IO_RUNG_TC)?, ctx(), fx.blocks.iter().map(|b| b.digest()).collect(), &fx.model, &fx.tables, fx.bos, fx.norm, variant, Tier::R1_MVP, roots)
}

pub(super) struct Proved {
    pub st: TokenRunStatement,
    pub segs: Vec<Vec<u8>>,
    pub hand: OwnerHandoff,
    pub stats: TokenRunStats,
    pub secs: f64,
}

/// seal the pipeline's two token planes, build the statement and prove
pub(super) fn prove_pipe(fx: &Fx, tp: &TokenProfile, pipe: &mut HonestPipeline) -> Result<Proved, String> {
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), tp)?;
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag())?;
    let st = statement(fx, roots, tp.variant)?;
    let mut segs = Vec::new();
    let t0 = std::time::Instant::now();
    let (stats, hand) = prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(pipe), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })?;
    Ok(Proved { st, segs, hand, stats, secs: t0.elapsed().as_secs_f64() })
}

pub(super) fn honest(fx: &Fx, tp: &TokenProfile) -> HonestPipeline {
    honest_pipeline(&fx.sh, tp, &fx.tables, &fx.blocks, &fx.tokens).unwrap_or_else(|e| panic!("{}: the honest pipeline refused: {e}", fx.name))
}

/// **For the hash-input census (s25 W-2):** a REAL token-I/O run statement of
/// the registered rung profile at `L` blocks (synthetic public words, roots
/// given), and the trained-model statement it binds. Nothing is committed.
/// the `L` a registered token-I/O profile's tests and runs prove at: the R1
/// rung's 2, R2's whole TinyLlama stack of 22
pub(crate) fn census_l(profile: &str) -> usize {
    match profile {
        RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32 | RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128 => 22,
        RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32 | RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128 => 32,
        _ => L,
    }
}

pub(crate) fn census_statement(profile: &'static str, l: usize) -> (TokenRunStatement, TrainedModelStatement, &'static TokenTables) {
    let (sh, norm, bos) = match profile {
        RUN_PROFILE_TOKEN_IO_RUNG_TC => (rung(), norm(), 1),
        RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32 => (Shape::tinyllama_trained(32, &r2_calibration(), R2_F_E).expect("the TinyLlama T32 shape"), R2_NORM, 1),
        RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32 => (Shape::llama3_8b_t32_trained(&r3_calibration(), R3_F_E).expect("the Llama-3-8B T32 shape"), R3_NORM_GENERIC, R3_BOS),
        // TOKEN I/O ROUND 8: the T128 profiles
        RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128 => (Shape::tinyllama_trained(128, &r2_calibration(), R2_F_E).expect("the TinyLlama T128 shape"), R2_NORM, 1),
        RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128 => (Shape::llama3_8b_trained(128, &r3_calibration(), R3_F_E).expect("the Llama-3-8B T128 shape"), R3_NORM_GENERIC, R3_BOS),
        _ => panic!("census_statement: {profile} is not a registered token-I/O run profile"),
    };
    let tables = census_tables(profile);
    // ONE synthetic block standing for all L: only its digest and record
    // enter the statement, and neither the block nor its words are cloned
    // (32 Llama-3-8B blocks would be 7.8 GB)
    let blk = blocks(&sh, 1).remove(0);
    let model = model_of_one(&sh, &blk, l, profile);
    let digest = blk.digest();
    drop(blk);
    let st = TokenRunStatement::new(
        RunShape::new(sh, l, profile).expect("the token-I/O run shape"),
        ctx(),
        vec![digest; l],
        &model,
        tables,
        bos,
        norm,
        SelectorVariant::PublicRow,
        Tier::R1_MVP,
        ([1u8; 32], [2u8; 32]),
    )
    .expect("the census token-I/O statement");
    (st, model, tables)
}

/// the public tables of each registered token-I/O profile's census (and of
/// the counted-layout tests), built ONCE per test process: the Llama-3-8B
/// pair is 1.58 GB, so every test that needs 8B-sized tables shares this copy
pub(crate) fn census_tables(profile: &str) -> &'static TokenTables {
    use std::sync::OnceLock;
    static RUNG: OnceLock<TokenTables> = OnceLock::new();
    static TINY: OnceLock<TokenTables> = OnceLock::new();
    static EIGHT: OnceLock<TokenTables> = OnceLock::new();
    match profile {
        RUN_PROFILE_TOKEN_IO_RUNG_TC => RUNG.get_or_init(|| generic_tables(384, 0x7531_6765)),
        RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32 | RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128 => TINY.get_or_init(|| generic_tables_v(32_000, 2048, 0x7232_6365)),
        RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32 | RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128 => EIGHT.get_or_init(|| hashed_tables(128_256, 4096)),
        _ => panic!("census_tables: {profile} is not a registered token-I/O run profile"),
    }
}

/// R3's BOS (Llama-3: `<|begin_of_text|>` = 128,000; D25 T8 / CHECK2 N-2: a
/// per-profile constant in [0, V))
pub(super) const R3_BOS: u64 = 128_000;

/// R3's GENERIC final norm: uniform gain 127, `tn 9` (the only `tn` that
/// makes the window exactly 32 at width 4,096), `Ceps 78,617` (the 8B
/// export's block Ceps, a stand-in), and the refusal-free `Cn = 512`
/// (`g0 Cn = 127 * 2^tn`, DESIGN C-7); the trained run takes the calibration
/// lane's constants
pub(super) const R3_NORM_GENERIC: FinalNorm = FinalNorm { g0: 127, cn: 512, tn: 9, ceps: 78_617 };

/// murmur3's 64-bit finaliser (the generic R3 tables' word source; the same
/// function is re-implemented in numpy by `tools/crosscheck_r3.py`)
pub(super) fn fmix64(mut u: u64) -> u64 {
    u ^= u >> 33;
    u = u.wrapping_mul(0xff51_afd7_ed55_8ccd);
    u ^= u >> 33;
    u = u.wrapping_mul(0xc4ce_b9fe_1a85_ec53);
    u ^= u >> 33;
    u
}

/// the generic R3 tables' three seeds
pub(super) const HASH_SEED_EMB: u64 = 0x5233_454d_4231_0001;
pub(super) const HASH_SEED_HEAD: u64 = 0x5233_4845_4144_0002;
pub(super) const HASH_SEED_MULT: u64 = 0x5233_4d55_4c54_0003;

/// **THE GENERIC TABLES AT ANY SIZE, WORD BY WORD FROM A HASH** (R3): dense
/// int16 embedding words in [-6000, 6000] (the dense recipe's input band),
/// dense nonzero int8 head words in [-127, 127], per-row multipliers over
/// the whole class [1, 2^12]; each word a pure function of its index, so the
/// 1.58 GB Llama-3-8B pair is built in parallel and re-derived independently
/// (in numpy) by the Python reference
pub(super) fn hashed_tables(v: usize, d: usize) -> TokenTables {
    use rayon::prelude::*;
    let idx = |r: usize, i: usize| ((r as u64) << 20) | i as u64;
    let emb: Vec<i16> = (0..v * d).into_par_iter().map(|x| (fmix64(HASH_SEED_EMB ^ idx(x / d, x % d)) % 12_001) as i16 - 6_000).collect();
    let head: Vec<i8> = (0..v * d)
        .into_par_iter()
        .map(|x| {
            let w = (fmix64(HASH_SEED_HEAD ^ idx(x / d, x % d)) % 254) as i64 - 127;
            (if w >= 0 { w + 1 } else { w }) as i8
        })
        .collect();
    let mult: Vec<i64> = (0..v).map(|j| 1 + (fmix64(HASH_SEED_MULT ^ j as u64) % 4096) as i64).collect();
    TokenTables::new(v, d, emb, head, mult).expect("the hashed generic tables")
}

/// R2's final norm (the fidelity lane's constants, `r2_inputs/
/// head_manifest.json`): uniform gain 127, `tn 10` (window exactly 32 at
/// width 2048), `Ceps 74,429`, and the CALIBRATED `Cn = 5,664` (review
/// condition (b): the final-norm int8 overflow is then a live D20 class)
pub(super) const R2_NORM: FinalNorm = FinalNorm { g0: 127, cn: 5664, tn: 10, ceps: 74_429 };

// ------------------------------------------------------------------ 1. the counted layout

/// **TEST 1, written before the construction (PROGRESS 20:10 / 20:23).** The
/// code's counted layout equals `token_io_count.py`'s figures for this rung,
/// with the per-row head of D25 T4 as amended (the counter's own formulas,
/// its logit bound times 2^12): `counts/r1_counts.json`, key
/// `per_row_12bit_D25_T4_amended`.
#[test]
fn the_counted_layout_is_the_counters() {
    let fx = fx_generic();
    let sh = &fx.sh;
    let tp = profile(&fx);
    // the derived keyed window and limb count (finding TF-1)
    assert_eq!((tp.window_bits, tp.limbs, tp.v_pad, tp.log_v), (45, 6, 512, 9), "the R1 keyed window");
    let li = stage_in::layout(sh, &tp);
    // stage IN: A 10 / H 14 / M 12 rows, 98,304 elements, sites A 3 / H 3, 4 slots
    assert_eq!((li.a_rows, li.h_rows, li.m_rows()), (10, 14, 12), "stage IN rows");
    assert_eq!(li.elems(), 98_304, "stage IN committed elements");
    assert_eq!((li.a_sites_total(), li.h_sites_total(), li.sched.slots.len()), (3, 3, 4), "stage IN sites and slots");
    assert_eq!((li.a_rows * li.n, li.h_rows * li.n), (40_960, 57_344), "stage IN A / H elements");
    let lo = stage_out::layout(sh, &tp);
    // stage OUT: A 121 / H 50 / M 26 rows, 700,416 elements, sites A 47 / H 12, 11 slots
    assert_eq!((lo.a_rows, lo.h_rows, lo.m_rows()), (121, 50, 26), "stage OUT rows");
    assert_eq!(lo.elems(), 700_416, "stage OUT committed elements");
    assert_eq!((lo.a_sites_total(), lo.h_sites_total(), lo.sched.slots.len()), (47, 12, 11), "stage OUT sites and slots");
    assert_eq!((lo.a_rows * lo.n, lo.h_rows * lo.n), (495_616, 204_800), "stage OUT A / H elements");
    // byte lookups of stage OUT: 12 Do + 1 Lo + 6 Vo columns over the lifted domains
    let u8 = (stage_out::lookups_do().len() + stage_out::lookups_lo().len() + stage_out::lookups_vo(tp.limbs).len()) * lo.n;
    assert_eq!(u8, 77_824, "stage OUT byte lookups");
    // the token endpoints: 256 words at 2^8 rate 1/8, one site, 6 rows
    let (ins, outs) = endpoint_specs(sh, ctx(), &tp).unwrap();
    assert_eq!((ins.len(), ins.data_rows(), ins.commitment_rows()), (256, 1, 6), "the input token endpoint");
    assert_eq!((outs.len(), outs.data_rows(), outs.commitment_rows()), (256, 1, 6), "the output token endpoint");
    assert_eq!((ins.params().log_cols, ins.params().inv_rate), (8, 8));
    // B_in / B_out: the block's internal-boundary geometry, data + 2*2 + 2
    let (roots, _) = seal_endpoints(&ins, &outs, &vec![Fp::ZERO; 256], &vec![Fp::ZERO; 256], &sh.hash_tag()).unwrap();
    let st = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
    for j in 0..=L {
        let b = st.boundary_spec(j).unwrap();
        assert_eq!((b.data_rows(), b.commitment_rows(), b.sites()), (16, 22, 2), "boundary {j}");
    }
    // the per-opening figures the design states for this rung [COUNTED]
    let t = tp.tier;
    let (ps, pe, pb) = (t.per_opening_log2(12, 4), t.per_opening_log2(8, 8), t.per_opening_log2(10, 4));
    assert!((ps + 103.69).abs() < 0.01 && (pe + 106.25).abs() < 0.01 && (pb + 96.13).abs() < 0.01, "per-opening: stages {ps:.2}, endpoints {pe:.2}, blocks {pb:.2}");
    // the segment byte counts (counted, never measured)
    let lens = st.segment_lens().unwrap();
    eprintln!("TOKEN-IO-R1 COUNTS stage IN A {} H {} M {} elems {} | stage OUT A {} H {} M {} elems {} u8 {} | window {} limbs {} | segments {:?} total {} B | per-opening stage {ps:.2} endpoint {pe:.2} block {pb:.2}", li.a_rows, li.h_rows, li.m_rows(), li.elems(), lo.a_rows, lo.h_rows, lo.m_rows(), lo.elems(), u8, tp.window_bits, tp.limbs, lens, lens.iter().sum::<usize>());
    // and the block layout is the registered one, untouched
    let bl = super::super::layout::Layout::for_shape(sh).unwrap();
    assert_eq!((bl.a_rows, bl.h_rows), (sh.totals().a_rows, sh.totals().h_rows));
}

// ------------------------------------------------------------------ 2. honest runs

pub(super) fn owner_checks(fx: &Fx, p: &Proved, tp: &TokenProfile, want_tok: usize) {
    let tag = fx.sh.hash_tag();
    let (ir, or) = p.st.roots();
    let words = owner_rebuild_root(&p.st.in_spec, &ir, &p.hand.input, &tag).expect("the input owner rebuilds the input root");
    // R0's owner_check_input semantics (public-row variant): BOS at 0, the
    // prompt, zero pad words
    assert_eq!(words[0], Fp::new(fx.bos), "{}: the sealed position 0 is not the profile's BOS", fx.name);
    assert!(words[..tp.tokens].iter().zip(fx.tokens.iter()).all(|(w, t)| *w == Fp::new(*t)), "{}: the sealed tokens are not the prompt", fx.name);
    assert!(words[tp.tokens..].iter().all(|w| w.is_zero()), "{}: a sealed pad word is not zero", fx.name);
    let out = owner_rebuild_root(&p.st.out_spec, &or, &p.hand.output, &tag).expect("the output owner rebuilds the output root");
    assert_eq!(out[0], Fp::new(want_tok as u64), "{}: the decommitted id is not the reference next token", fx.name);
    assert!(out[1..].iter().all(|w| w.is_zero()));
    // a decommitment one pad off, or of another shape, is refused
    let mut bad = p.hand.output.clone();
    bad.pads[3] = bad.pads[3].add(Fp::ONE);
    assert!(owner_rebuild_root(&p.st.out_spec, &or, &bad, &tag).unwrap_err().contains("does not rebuild"));
    let mut short = p.hand.input.clone();
    short.salts.pop();
    assert!(owner_rebuild_root(&p.st.in_spec, &ir, &short, &tag).unwrap_err().contains("derived geometry"));
    // and the input decommitment does not open the output root
    assert!(owner_rebuild_root(&p.st.out_spec, &or, &p.hand.input, &tag).is_err());
    // the owner checks proper (review TR-4), under the verified statement
    owner_check_input(&p.st, &p.hand.input, &fx.tokens).unwrap_or_else(|e| panic!("{}: the input owner's check refused the honest plane: {e}", fx.name));
    assert_eq!(owner_check_output(&p.st, &p.hand.output).unwrap_or_else(|e| panic!("{}: the output owner's check refused: {e}", fx.name)), want_tok);
}

/// the reference next token, computed independently of the stage code (R0's
/// integer semantics: final norm with a uniform gain, raw logits times the row
/// multiplier, numpy's first maximum) on the honest `B_out` row `T - 1`
fn reference_next_token(fx: &Fx, tp: &TokenProfile, b_out: &[i16]) -> usize {
    let x: Vec<i128> = (0..tp.d).map(|i| i128::from(b_out[(tp.tokens - 1) * tp.d_pad + i])).collect();
    let nm = fx.norm;
    let ss: i128 = i128::from(nm.ceps) + x.iter().map(|v| v * v).sum::<i128>();
    let mut d = (ss as f64).sqrt() as i128;
    while d * d > ss {
        d -= 1;
    }
    while (d + 1) * (d + 1) <= ss {
        d += 1;
    }
    let den = 2 * (d << nm.tn);
    let y: Vec<i128> = x.iter().map(|v| (2 * v * i128::from(nm.g0) * i128::from(nm.cn) + (d << nm.tn)).div_euclid(den)).collect();
    assert!(y.iter().all(|v| (-127..=127).contains(v)), "the reference final norm left int8");
    let l: Vec<i128> = (0..tp.v).map(|j| i128::from(fx.tables.mult[j]) * (0..tp.d).map(|i| i128::from(fx.tables.head[j * tp.d + i]) * y[i]).sum::<i128>()).collect();
    let mut best = 0usize;
    for j in 1..l.len() {
        if l[j] > l[best] {
            best = j;
        }
    }
    best
}

fn honest_run(fx: &Fx) {
    let tp = profile(fx);
    let mut pipe = honest(fx, &tp);
    let want = reference_next_token(fx, &tp, pipe.planes.last().unwrap());
    assert_eq!(pipe.out_values.tok, want, "{}: the stage code's greedy token is not the reference", fx.name);
    // generic: the logits are not degenerate (a unique maximum, a margin)
    let mut sorted = pipe.out_values.logits.clone();
    sorted.sort_unstable();
    let tok = pipe.out_values.tok;
    let p = prove_pipe(fx, &tp, &mut pipe).unwrap_or_else(|e| panic!("{}: the honest run did not prove: {e}", fx.name));
    let t0 = std::time::Instant::now();
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, R1_DEV_POLICY).unwrap_or_else(|e| panic!("{}: the honest run did not verify: {e}", fx.name));
    let vs = t0.elapsed().as_secs_f64();
    assert_eq!(p.segs.iter().map(|s| s.len()).collect::<Vec<_>>(), p.st.segment_lens().unwrap(), "the segment lengths are not the counted ones");
    owner_checks(fx, &p, &tp, want);
    eprintln!(
        "TOKEN-IO-R1 HONEST {}: next token {} (reference {}), top-2 logit margin {}, prove {:.2} s (stages {:?}), verify {:.2} s, receipt {} B in {} segments {:?} [MEASURED, shared box, n=1, test build]",
        fx.name,
        tok,
        want,
        sorted[sorted.len() - 1] - sorted[sorted.len() - 2],
        p.secs,
        p.stats.prove_s.iter().map(|s| (s * 100.0).round() / 100.0).collect::<Vec<_>>(),
        vs,
        p.segs.iter().map(|s| s.len()).sum::<usize>(),
        p.segs.len(),
        p.stats.segment_bytes
    );
}

#[test]
fn an_honest_run_of_r0s_model_proves_verifies_and_both_owners_check() {
    honest_run(&fx_r0());
}

#[test]
fn an_honest_generic_run_proves_verifies_and_both_owners_check() {
    let fx = fx_generic();
    // GENERIC: distinct embedding rows, every head word nonzero, multipliers
    // that differ, the blocks' heads differ (asserted by the dense recipe's
    // own generic-witness checks elsewhere; the rows here)
    let rows: std::collections::HashSet<&[i16]> = (0..fx.tables.v).map(|v| fx.tables.emb_row(v)).collect();
    assert_eq!(rows.len(), fx.tables.v, "two embedding rows are equal");
    assert!(fx.tables.head.iter().all(|w| *w != 0), "a head word is zero");
    let mults: std::collections::HashSet<i64> = fx.tables.mult.iter().copied().collect();
    assert!(mults.len() > 200, "the multipliers barely differ");
    honest_run(&fx);
}

// ------------------------------------------------------------------ 3. the controls

#[derive(Clone, Copy, Debug)]
pub(super) enum Site {
    InSlot(usize),
    OutSlot(usize),
    InLogUp,
    OutLogUp,
    /// a block stage's refusal (its slot or its openings)
    Block,
    /// the run statement / header binding (a segment of another run)
    Binding,
    /// the run statement's door: an unbuilt variant (review TR-3)
    Door,
}

impl Site {
    pub(super) fn matches(self, e: &str) -> bool {
        match self {
            Site::InSlot(s) => e.starts_with(&format!("stage IN slot {s:02} ")),
            Site::OutSlot(s) => e.starts_with(&format!("stage OUT slot {s:02} ")),
            Site::InLogUp => e.starts_with("stage IN H "),
            Site::OutLogUp => e.starts_with("stage OUT H "),
            Site::Block => e.starts_with("block "),
            Site::Binding => e.contains("belongs to another run"),
            Site::Door => e.contains("variant is not built"),
        }
    }
}

/// prove a forged pipeline with the CHEATING prover (none of the honest
/// prover's refusals), then verify: the verifier must speak
pub(super) fn forge(fx: &Fx, tp: &TokenProfile, mut pipe: HonestPipeline) -> String {
    let p = {
        let _cheat = CheatingProver::on();
        prove_pipe(fx, tp, &mut pipe).unwrap_or_else(|e| panic!("the cheating prover did not produce a receipt: {e}"))
    };
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, R1_DEV_POLICY).err().expect("A FORGERY VERIFIED")
}

pub(super) fn record(n: &str, what: &str, predicted: &[Site], err: &str) {
    let hit = predicted.iter().any(|s| s.matches(err));
    eprintln!("TOKEN-IO-R1 CONTROL #{n} | {what} | predicted {:?} | actual: {} | {}", predicted, err.chars().take(150).collect::<String>(), if hit { "AS PREDICTED" } else { "NOT AS PREDICTED" });
    assert!(hit, "control #{n} ({what}) was refused elsewhere than predicted {predicted:?}: {err}");
}

/// re-derive everything downstream of a forged `B_in` (blocks, `B_out`, the
/// stage-OUT witness and the output plane), as a consistent forger would
pub(super) fn with_b_in(fx: &Fx, tp: &TokenProfile, pipe: &mut HonestPipeline, b_in: Vec<i16>) {
    let (w, planes, ov, wout, out_plane) = downstream(&fx.sh, tp, &fx.tables, &fx.blocks, &b_in, false).expect("the forged chain builds");
    pipe.b_in = b_in;
    pipe.witnesses = w;
    pipe.planes = planes;
    pipe.out_values = ov;
    pipe.stage_out = wout;
    pipe.out_plane = out_plane;
}

pub(super) fn hist(tp: &TokenProfile, toks: &[u64]) -> Vec<Fp> {
    let mut m = vec![Fp::ZERO; 1usize << tp.voc_log()];
    for t in toks {
        m[*t as usize] = m[*t as usize].add(Fp::ONE);
    }
    m
}

pub(super) fn tok_plane(tp: &TokenProfile, toks: &[u64]) -> Vec<Fp> {
    let mut v = vec![Fp::ZERO; 1usize << tp.ti_log()];
    for (t, id) in toks.iter().enumerate() {
        v[t] = Fp::new(*id);
    }
    v
}

pub(super) fn set_row(tp: &TokenProfile, b: &mut [i16], t: usize, row: &[i16]) {
    b[t * tp.d_pad..t * tp.d_pad + tp.d].copy_from_slice(row);
}

/// the `limbs`-byte decomposition of a FIELD value: `carry` puts everything
/// above the low limbs into the top limb (a non-byte when the value does not
/// fit; the limb sum is the value), otherwise the low bytes only (truncation)
pub(super) fn limbs_of(v: Fp, n: usize, carry: bool) -> Vec<Fp> {
    let x = v.0;
    (0..n)
        .map(|k| {
            if carry && k == n - 1 {
                Fp::new(x >> (8 * k))
            } else {
                Fp::new((x >> (8 * k)) & 0xFF)
            }
        })
        .collect()
}

/// rewrite the keyed-argmax planes of a stage-OUT witness: selector `e`,
/// `tok`, `M`, and every true entry's difference from `delta(i)`
pub(super) fn argmax_planes(tp: &TokenProfile, w: &mut StageOutWitness, e: &[(usize, Fp)], tok: Fp, m: Fp, delta: &dyn Fn(usize) -> Fp, carry: bool) {
    let sn = 1usize << tp.vo_log();
    w.planes[stage_out::A_E] = vec![Fp::ZERO; sn];
    for (i, v) in e {
        w.planes[stage_out::A_E][*i] = *v;
    }
    w.planes[stage_out::A_TOK][0] = tok;
    w.planes[stage_out::A_M][0] = m;
    for kk in 0..tp.limbs {
        w.planes[stage_out::A_LAM0 + kk] = vec![Fp::ZERO; sn];
    }
    for i in 0..tp.v {
        for (kk, b) in limbs_of(delta(i), tp.limbs, carry).into_iter().enumerate() {
            w.planes[stage_out::A_LAM0 + kk][i] = b;
        }
    }
}

pub(super) fn keyed(tp: &TokenProfile, m: i64, l: i64, i: usize, j: usize) -> Fp {
    Fp::from_i64(((m - l) << tp.log_v) + (i as i64 - j as i64))
}

pub(super) fn second_best(l: &[i64], j: usize) -> usize {
    (0..l.len()).filter(|i| *i != j && l[*i] < l[j]).max_by_key(|i| (l[*i], std::cmp::Reverse(*i))).expect("a second-best entry")
}

/// **CONTROLS ON STAGE OUT's KEYED ARGMAX, the output plane and the public row**
/// (DESIGN 6.1 #1-3, #9-#15, #18).
#[test]
fn the_stage_out_controls_are_refused_where_the_design_predicts() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let base = honest(&fx, &tp);
    let l = base.out_values.logits.clone();
    let j = base.out_values.tok;
    let max = l[j];
    let inv2v = Fp::new(1u64 << tp.log_v).inv();
    let ep = |id: u64| stage_out::endpoint_plane(&tp, id);
    // #1: e on a PADDED vocabulary entry, tok = V, M = max + 1
    {
        let mut p = honest(&fx, &tp);
        let pad = tp.v;
        argmax_planes(&tp, &mut p.stage_out, &[(pad, Fp::ONE)], Fp::new(pad as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, pad), false);
        p.out_plane = ep(pad as u64);
        record("1", "e on a padded vocabulary entry, tok = V, M = max + 1", &[Site::OutSlot(stage_out::SO_VZC)], &forge(&fx, &tp, p));
    }
    // #2: e at a non-maximal j', M = max + 1, every delta in its bytes (A6-only)
    let j2 = second_best(&l, j);
    {
        let mut p = honest(&fx, &tp);
        argmax_planes(&tp, &mut p.stage_out, &[(j2, Fp::ONE)], Fp::new(j2 as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, j2), false);
        p.out_plane = ep(j2 as u64);
        record("2", "non-maximal j, M = max + 1, deltas in bytes (A6-only)", &[Site::OutSlot(stage_out::SO_RSEL)], &forge(&fx, &tp, p));
    }
    // #3: e, delta honest for j; tok' = j + 1 with M = l_j + 2^-v (tok' - j) (A3-only)
    {
        let mut p = honest(&fx, &tp);
        let t2 = (j + 1) as u64;
        p.stage_out.planes[stage_out::A_TOK][0] = Fp::new(t2);
        p.stage_out.planes[stage_out::A_M][0] = Fp::from_i64(max).add(inv2v);
        p.out_plane = ep(t2);
        record("3", "e, delta honest; tok' = j + 1, M = l_j + 2^-v (A3-only)", &[Site::OutSlot(stage_out::SO_RSEL)], &forge(&fx, &tp, p));
    }
    // #11 (b): tok changed with the endpoint, M unchanged (the naive form): A5
    {
        let mut p = honest(&fx, &tp);
        let t2 = (j + 1) as u64;
        p.stage_out.planes[stage_out::A_TOK][0] = Fp::new(t2);
        p.out_plane = ep(t2);
        record("11b", "wrong output token: A_out tok and endpoint another id, M unchanged", &[Site::OutSlot(stage_out::SO_RSEL), Site::OutSlot(stage_out::SO_VZC)], &forge(&fx, &tp, p));
    }
    // #9 / #11 (a): the output plane seals another id (the owner is told that id)
    {
        let mut p = honest(&fx, &tp);
        p.out_plane = ep(j2 as u64);
        record("9", "output plane seals another id (A_out honest)", &[Site::OutSlot(stage_out::SO_IOOUT)], &forge(&fx, &tp, p));
    }
    // #10 (b): a nonzero pad word in the OUTPUT token endpoint
    {
        let mut p = honest(&fx, &tp);
        p.out_plane[1] = Fp::new(7);
        record("10b", "nonzero pad word in the output token endpoint", &[Site::OutSlot(stage_out::SO_IOOUT)], &forge(&fx, &tp, p));
    }
    // #12: the second best with M = l_j', delta as FIELD values: (a) the low
    // bytes only -> A5; (b) the excess carried in the top limb -> byte lookups
    for (carry, tagn, site) in [(false, "12a", Site::OutSlot(stage_out::SO_VZC)), (true, "12b", Site::OutLogUp)] {
        let mut p = honest(&fx, &tp);
        argmax_planes(&tp, &mut p.stage_out, &[(j2, Fp::ONE)], Fp::new(j2 as u64), Fp::from_i64(l[j2]), &|i| keyed(&tp, l[j2], l[i], i, j2), carry);
        p.out_plane = ep(j2 as u64);
        record(tagn, if carry { "non-maximal token, M = l_j, delta field values in a non-byte top limb" } else { "non-maximal token, M = l_j, delta field values truncated to bytes" }, &[site], &forge(&fx, &tp, p));
    }
    // #14: selector not one-hot: two-hot (A2), halves (A1), (2, -1) (A1)
    {
        let mut p = honest(&fx, &tp);
        argmax_planes(&tp, &mut p.stage_out, &[(j, Fp::ONE), (j2, Fp::ONE)], Fp::new(j as u64), Fp::from_i64(max), &|i| keyed(&tp, max, l[i], i, j), false);
        record("14a", "two-hot selector", &[Site::OutSlot(stage_out::SO_VZC), Site::OutSlot(stage_out::SO_RSEL)], &forge(&fx, &tp, p));
        let half = Fp::new(2).inv();
        let mut p = honest(&fx, &tp);
        argmax_planes(&tp, &mut p.stage_out, &[(j, half), (j2, half)], Fp::new(j as u64), Fp::from_i64(max), &|i| keyed(&tp, max, l[i], i, j), false);
        record("14b", "fractional selector (1/2, 1/2)", &[Site::OutSlot(stage_out::SO_VZC)], &forge(&fx, &tp, p));
        let mut p = honest(&fx, &tp);
        argmax_planes(&tp, &mut p.stage_out, &[(j, Fp::new(2)), (j2, Fp::ONE.neg())], Fp::new(j as u64), Fp::from_i64(max), &|i| keyed(&tp, max, l[i], i, j), false);
        record("14c", "selector (2, -1)", &[Site::OutSlot(stage_out::SO_VZC), Site::OutSlot(stage_out::SO_RSEL)], &forge(&fx, &tp, p));
    }
    // #15: a delta limb that is not a byte, the same delta value
    {
        let mut p = honest(&fx, &tp);
        let i = (0..tp.v).find(|i| p.stage_out.planes[stage_out::A_LAM0 + 1][*i] != Fp::ZERO).expect("an entry with a second limb");
        p.stage_out.planes[stage_out::A_LAM0][i] = p.stage_out.planes[stage_out::A_LAM0][i].add(Fp::new(256));
        p.stage_out.planes[stage_out::A_LAM0 + 1][i] = p.stage_out.planes[stage_out::A_LAM0 + 1][i].sub(Fp::ONE);
        record("15", "a delta limb that is not a byte (same delta value)", &[Site::OutLogUp], &forge(&fx, &tp, p));
    }
    // #18: public row: the logits from row T - 2
    {
        let mut p = honest(&fx, &tp);
        let ov = stage_out::out_values(&tp, &fx.tables, &stage_out::row_of(&tp, p.planes.last().unwrap(), tp.tokens - 2), true).unwrap();
        p.stage_out = stage_out::witness_from_values(&tp, &ov).unwrap();
        p.out_plane = ep(ov.tok as u64);
        record("18", "public row: stage OUT computes from row T - 2", &[Site::OutSlot(stage_out::SO_IO)], &forge(&fx, &tp, p));
    }
}

/// #13: a tie broken the wrong way (two identical maximal head rows, the
/// higher id chosen). A head of its own (its digest is the statement's).
#[test]
fn a_tie_broken_toward_the_higher_id_is_refused() {
    let mut fx = fx_generic();
    let tp0 = profile(&fx);
    let y = honest(&fx, &tp0).out_values.y;
    let (j1, j2) = (17usize, 203usize);
    for jj in [j1, j2] {
        for i in 0..fx.tables.d {
            fx.tables.head[jj * fx.tables.d + i] = if y[i] >= 0 { 127 } else { -127 };
        }
        fx.tables.mult[jj] = 1 << MULT_BITS;
    }
    let tp = profile(&fx);
    let base = honest(&fx, &tp);
    let l = base.out_values.logits.clone();
    assert_eq!(l[j1], l[j2], "the two rows do not tie");
    assert_eq!(base.out_values.tok, j1, "numpy's first maximum is the lower id");
    // the honest tie verifies
    let mut hp = honest(&fx, &tp);
    let p = prove_pipe(&fx, &tp, &mut hp).unwrap();
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, R1_DEV_POLICY).expect("the honest tie run verifies");
    let mut p = honest(&fx, &tp);
    argmax_planes(&tp, &mut p.stage_out, &[(j2, Fp::ONE)], Fp::new(j2 as u64), Fp::from_i64(l[j2]), &|i| keyed(&tp, l[j2], l[i], i, j2), false);
    p.out_plane = stage_out::endpoint_plane(&tp, j2 as u64);
    record("13", "tie broken the wrong way (higher id chosen)", &[Site::OutSlot(stage_out::SO_VZC)], &forge(&fx, &tp, p));
}

/// **CONTROLS ON STAGE IN** (DESIGN 6.1 #4, #5, #7, #10a, #16).
#[test]
fn the_stage_in_controls_are_refused_where_the_design_predicts() {
    let fx = fx_generic();
    let tp = profile(&fx);
    // #4: tok_0 = BOS + 1, h_q(0) = 0, row 0 arbitrary, histogram without position 0
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[0] = fx.bos + 1;
        let mut b = p.b_in.clone();
        let arb: Vec<i16> = (0..tp.d).map(|i| (i as i16 * 37) % 5000 - 2500).collect();
        set_row(&tp, &mut b, 0, &arb);
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &toks), mult: hist(&tp, &toks[1..]), hq_zero: vec![0] };
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        with_b_in(&fx, &tp, &mut p, b);
        record("4", "tok_0 = BOS + 1, h_q(0) = 0, row 0 arbitrary (the CHECK2 N-1 forgery)", &[Site::InSlot(stage_in::SI_QZC)], &forge(&fx, &tp, p));
    }
    // #5: tok_0 != BOS, otherwise honest for that sequence
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[0] = 7;
        let mut b = p.b_in.clone();
        set_row(&tp, &mut b, 0, fx.tables.emb_row(7));
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &toks), mult: hist(&tp, &toks), hq_zero: vec![] };
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        with_b_in(&fx, &tp, &mut p, b);
        record("5", "tok_0 != BOS, otherwise honest", &[Site::InSlot(stage_in::SI_QZC)], &forge(&fx, &tp, p));
    }
    // #7: a consistent re-lookup in A_in under the honest seal
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[5] = (toks[5] + 11) % tp.v as u64;
        let mut b = p.b_in.clone();
        set_row(&tp, &mut b, 5, fx.tables.emb_row(toks[5] as usize));
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &toks), mult: hist(&tp, &toks), hq_zero: vec![] };
        with_b_in(&fx, &tp, &mut p, b);
        record("7", "consistent re-lookup in A_in (tok, row, histogram) under the honest seal", &[Site::InSlot(stage_in::SI_IO)], &forge(&fx, &tp, p));
    }
    // #10 (a): a nonzero pad word in the INPUT token endpoint
    {
        let mut p = honest(&fx, &tp);
        p.in_plane[tp.tokens] = Fp::new(5);
        record("10a", "nonzero pad word in the input token endpoint", &[Site::InSlot(stage_in::SI_IO)], &forge(&fx, &tp, p));
    }
    // #16 (a): a wrong embedding row (tok and histogram unchanged)
    {
        let mut p = honest(&fx, &tp);
        let mut b = p.b_in.clone();
        set_row(&tp, &mut b, 5, fx.tables.emb_row(((fx.tokens[5] + 3) % tp.v as u64) as usize));
        with_b_in(&fx, &tp, &mut p, b);
        record("16a", "wrong embedding row", &[Site::InLogUp], &forge(&fx, &tp, p));
    }
    // #16 (b): one changed word of an embedded row
    {
        let mut p = honest(&fx, &tp);
        let mut b = p.b_in.clone();
        b[5 * tp.d_pad + 7] += 1;
        with_b_in(&fx, &tp, &mut p, b);
        record("16b", "one changed word of an embedded row", &[Site::InLogUp], &forge(&fx, &tp, p));
    }
    // #16 (c): a padded token id (V), its row the repeated table row 0; the
    // histogram counts it on the pad (pad-zero) / the histogram unchanged (LogUp)
    for (count_pad, tagn, site) in [(true, "16c", Site::InSlot(stage_in::SI_TZC)), (false, "16c2", Site::InLogUp)] {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[5] = tp.v as u64;
        let mut b = p.b_in.clone();
        set_row(&tp, &mut b, 5, fx.tables.emb_row(0));
        let m = if count_pad { hist(&tp, &toks) } else { hist(&tp, &fx.tokens) };
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &toks), mult: m, hq_zero: vec![] };
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        with_b_in(&fx, &tp, &mut p, b);
        record(tagn, if count_pad { "padded token id V, histogram on the pad" } else { "padded token id V, histogram unchanged" }, &[site], &forge(&fx, &tp, p));
    }
    // #16 (d): the histogram off by one
    {
        let mut p = honest(&fx, &tp);
        p.stage_in.mult[3] = p.stage_in.mult[3].add(Fp::ONE);
        record("16d", "histogram off by one", &[Site::InLogUp], &forge(&fx, &tp, p));
    }
}

/// `x` row's final-norm intermediates at a CHOSEN `D` (the honest relation
/// with that `D`): `(dsq, a1, a2, y, rho, sigma)` as field / integers
fn norm_at(tp: &TokenProfile, x: &[i64], d: i64) -> (i128, Vec<i64>, Vec<i128>, Vec<i128>) {
    let nm = tp.norm;
    let ss: i128 = i128::from(nm.ceps) + x[..tp.d].iter().map(|v| i128::from(*v) * i128::from(*v)).sum::<i128>();
    let dv = i128::from(d) << nm.tn;
    let den = 2 * dv;
    let mut y = vec![0i64; tp.d_pad];
    let mut rho = vec![0i128; tp.d_pad];
    let mut sg = vec![0i128; tp.d_pad];
    for i in 0..tp.d {
        let num = 2 * i128::from(x[i]) * i128::from(nm.g0) * i128::from(nm.cn) + dv;
        let q = num.div_euclid(den);
        y[i] = q as i64;
        rho[i] = num - q * den;
        sg[i] = den - 1 - rho[i];
    }
    (ss, y, rho, sg)
}

fn fpi(v: i128) -> Fp {
    if v >= 0 {
        Fp::from_u128(v as u128)
    } else {
        Fp::from_u128((-v) as u128).neg()
    }
}

/// rebuild a stage-OUT witness around new final-norm planes (`y` changes the
/// logits, so the argmax part is re-derived honestly for the new `y`)
fn with_norm(fx: &Fx, tp: &TokenProfile, p: &mut HonestPipeline, d: Fp, a1: Fp, a2: Fp, y: &[i64], rho: &[Fp], sigma: &[Fp], carry_limbs: bool) {
    let mut ov = p.out_values.clone();
    ov.y = y.to_vec();
    ov.logits = fx.tables.logits(y);
    ov.tok = stage_out::first_argmax(&ov.logits);
    ov.rho = vec![0; tp.d_pad];
    ov.sigma = vec![0; tp.d_pad];
    let mut w = stage_out::witness_from_values(tp, &ov).expect("the argmax part");
    w.planes[stage_out::A_D][0] = d;
    w.planes[stage_out::A_DSQ][0] = d.mul(d);
    for (s, v) in [d, a1, a2].iter().enumerate() {
        for (kk, b) in limbs_of(*v, LIMBS_ISQRT, carry_limbs).into_iter().enumerate() {
            w.planes[stage_out::A_LIMB][2 * (3 * s + kk)] = b;
        }
    }
    for i in 0..tp.d {
        for (kk, b) in limbs_of(rho[i], NORM_LIMBS, true).into_iter().enumerate() {
            w.planes[stage_out::A_RHO0 + kk][i] = b;
        }
        for (kk, b) in limbs_of(sigma[i], NORM_LIMBS, true).into_iter().enumerate() {
            w.planes[stage_out::A_SIG0 + kk][i] = b;
        }
    }
    p.stage_out = w;
    p.out_plane = stage_out::endpoint_plane(tp, ov.tok as u64);
    p.out_values = ov;
}

/// **CONTROLS ON THE FINAL NORM** (DESIGN 6.1 #17, with the D16 item-6
/// half-p alias re-run on the final norm).
#[test]
fn the_final_norm_controls_are_refused_where_the_design_predicts() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let base = honest(&fx, &tp);
    let x = base.out_values.x.clone();
    let d0 = base.out_values.d;
    // #17 (a): y off by one, rho / sigma re-derived (rho goes negative)
    {
        let mut p = honest(&fx, &tp);
        let (ss, mut y, rho, sg) = norm_at(&tp, &x, d0);
        let _ = ss;
        let i0 = (0..tp.d).find(|i| y[*i] < 127).unwrap();
        let den = 2 * (i128::from(d0) << tp.norm.tn);
        y[i0] += 1;
        let rho_f: Vec<Fp> = (0..tp.d_pad).map(|i| fpi(if i == i0 { rho[i] - den } else { rho[i] })).collect();
        let sg_f: Vec<Fp> = (0..tp.d_pad).map(|i| fpi(if i == i0 { sg[i] + den } else { sg[i] })).collect();
        let ov = &base.out_values;
        with_norm(&fx, &tp, &mut p, Fp::from_i64(d0), Fp::from_i64(ov.a1), Fp::from_i64(ov.a2), &y, &rho_f, &sg_f, false);
        record("17a", "final norm: y off by one (rho, sigma re-derived)", &[Site::OutLogUp], &forge(&fx, &tp, p));
    }
    // #17 (b): D off by one, both directions (a1 or a2 leaves its limbs)
    for (dd, tagn) in [(1i64, "17b+"), (-1, "17b-")] {
        let mut p = honest(&fx, &tp);
        let d = d0 + dd;
        let (ss, y, rho, sg) = norm_at(&tp, &x, d);
        let a1 = ss - i128::from(d) * i128::from(d);
        let a2 = 2 * i128::from(d) - a1;
        let rho_f: Vec<Fp> = rho.iter().map(|v| fpi(*v)).collect();
        let sg_f: Vec<Fp> = sg.iter().map(|v| fpi(*v)).collect();
        with_norm(&fx, &tp, &mut p, Fp::from_i64(d), fpi(a1), fpi(a2), &y, &rho_f, &sg_f, true);
        record(tagn, "final norm: D off by one (isqrt relations kept in the field)", &[Site::OutLogUp], &forge(&fx, &tp, p));
    }
    // #17 (c-i): the D16 half-p alias, D = D + (p - 1)/2, limbs left honest: the limb pin (TZC)
    {
        let mut p = honest(&fx, &tp);
        let alias = Fp::from_i64(d0).add(Fp::new((P - 1) / 2));
        p.stage_out.planes[stage_out::A_D][0] = alias;
        p.stage_out.planes[stage_out::A_DSQ][0] = alias.mul(alias);
        record("17c-i", "D16 half-p alias of D, limbs honest", &[Site::OutSlot(stage_out::SO_TZC)], &forge(&fx, &tp, p));
    }
    // #17 (c-ii): the alias with limbs that RECONSTRUCT it and every relation
    // kept in the field: only the byte lookups object (the catch MOVES)
    {
        let mut p = honest(&fx, &tp);
        let nm = tp.norm;
        let alias = Fp::from_i64(d0).add(Fp::new((P - 1) / 2));
        let ss: i128 = i128::from(nm.ceps) + x[..tp.d].iter().map(|v| i128::from(*v) * i128::from(*v)).sum::<i128>();
        let a1 = fpi(ss).sub(alias.mul(alias));
        let a2 = alias.double().sub(a1);
        let y = base.out_values.y.clone();
        let two_tn = Fp::new(1u64 << nm.tn);
        let rho_f: Vec<Fp> = (0..tp.d_pad)
            .map(|i| if i < tp.d { Fp::from_i64(2 * x[i] * nm.g0 * nm.cn).add(alias.mul(two_tn)).sub(alias.mul(two_tn.double()).mul(Fp::from_i64(y[i]))) } else { Fp::ZERO })
            .collect();
        let sg_f: Vec<Fp> = (0..tp.d_pad).map(|i| if i < tp.d { alias.mul(two_tn.double()).sub(Fp::ONE).sub(rho_f[i]) } else { Fp::ZERO }).collect();
        with_norm(&fx, &tp, &mut p, alias, a1, a2, &y, &rho_f, &sg_f, true);
        // the alias reconstructed in limb 0 alone
        for s in 0..3 {
            let v = [alias, a1, a2][s];
            p.stage_out.planes[stage_out::A_LIMB][2 * (3 * s)] = v;
            p.stage_out.planes[stage_out::A_LIMB][2 * (3 * s + 1)] = Fp::ZERO;
            p.stage_out.planes[stage_out::A_LIMB][2 * (3 * s + 2)] = Fp::ZERO;
        }
        record("17c-ii", "D16 half-p alias reconstructed by its limbs, relations kept", &[Site::OutLogUp], &forge(&fx, &tp, p));
    }
    // #17 (e): x's int16 limbs wrong (xl1 + 1): DZC c2. (A non-int16 x itself
    // is not expressible: x = B_out's row, an int16 plane block L-1 re-proves.)
    {
        let mut p = honest(&fx, &tp);
        p.stage_out.planes[stage_out::A_XL1][0] = p.stage_out.planes[stage_out::A_XL1][0].add(Fp::ONE);
        record("17e", "x int16 limbs off by one (xl1 + 1)", &[Site::OutSlot(stage_out::SO_DZC)], &forge(&fx, &tp, p));
    }
}

/// #17 (d): `y` outside int8 with in-window remainders, under a HOT `Cn`
/// (16x the refusal-free one): the honest prover refuses (D20), a cheating
/// prover proves the exact integer quotient, the `sym` lookups object.
#[test]
fn a_norm_output_outside_int8_is_refused_by_the_sym_lookups() {
    let mut fx = fx_generic();
    fx.norm = FinalNorm { cn: 2048 * 16, ..norm() };
    let tp = profile(&fx);
    let e = match honest_pipeline(&fx.sh, &tp, &fx.tables, &fx.blocks, &fx.tokens) {
        Err(e) => e,
        Ok(_) => panic!("the hot Cn did not overflow int8 on this row; choose a hotter one"),
    };
    assert!(e.contains("final norm quotient"), "{e}");
    let (wit_in, b_in, in_plane) = stage_in::honest_inputs(&tp, &fx.tables, &fx.tokens).unwrap();
    let (w, planes, ov, wout, out_plane) = downstream(&fx.sh, &tp, &fx.tables, &fx.blocks, &b_in, false).unwrap();
    assert!(ov.y.iter().any(|v| v.abs() > 127) && ov.rho.iter().all(|r| *r >= 0 && *r < 1 << 32));
    let p = HonestPipeline { tokens: fx.tokens.clone(), stage_in: wit_in, b_in, witnesses: w, planes, out_values: ov, stage_out: wout, in_plane, out_plane };
    record("17d", "y outside int8 (hot Cn) with in-window remainders", &[Site::OutLogUp], &forge(&fx, &tp, p));
}

/// **RUN-LEVEL CONTROLS** (DESIGN 6.1 #20-#23; #6, #8, #19 belong to the
/// hidden-length variant, not built at R1): the token-I/O door on both
/// sides, wrong tables, the variant, segment order, endpoint geometry.
#[test]
fn the_run_level_controls_and_the_door_refuse() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap();
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, R1_DEV_POLICY).expect("the honest run verifies");
    let roots = p.st.roots();
    // #23 (a)-(c): a verifier with another embedding / head / multiplier
    // builds ANOTHER statement: refused at the first segment (the binding)
    for (what, edit) in [("embedding word", 0usize), ("head word", 1), ("head multiplier", 2)] {
        let mut f2 = fx_generic();
        match edit {
            0 => f2.tables.emb[11] += 1,
            1 => f2.tables.head[11] = if f2.tables.head[11] == 127 { 126 } else { f2.tables.head[11] + 1 },
            _ => f2.tables.mult[11] = if f2.tables.mult[11] == 4096 { 4095 } else { f2.tables.mult[11] + 1 },
        }
        let st2 = statement(&f2, roots, SelectorVariant::PublicRow).unwrap();
        let e = verify_token_run(&st2, &f2.blocks, &f2.tables, &p.segs, R1_DEV_POLICY).unwrap_err();
        record("23", &format!("a verifier configured with another {what}"), &[Site::Binding], &e);
        // and the honest statement refuses tables that are not its own
        let e = verify_token_run(&p.st, &fx.blocks, &f2.tables, &p.segs, R1_DEV_POLICY).unwrap_err();
        assert!(e.contains("not the ones the statement names"), "{e}");
    }
    // #23 (d): constants outside their classes, refused at the door
    let door = |f: &dyn Fn(&mut Fx)| {
        let mut f2 = fx_generic();
        f(&mut f2);
        TokenProfile::new(&f2.sh, &f2.tables, f2.bos, f2.norm, SelectorVariant::PublicRow, Tier::R1_MVP).err().expect("an out-of-class constant was admitted")
    };
    for (what, f) in [
        ("BOS = V", Box::new(|f: &mut Fx| f.bos = 300) as Box<dyn Fn(&mut Fx)>),
        ("BOS = 128000 under V = 300", Box::new(|f: &mut Fx| f.bos = 128_000)),
        ("g0 = 128", Box::new(|f: &mut Fx| f.norm.g0 = 128)),
        ("g0 = 0", Box::new(|f: &mut Fx| f.norm.g0 = 0)),
        ("Cn = 2^20 + 1", Box::new(|f: &mut Fx| f.norm.cn = (1 << 20) + 1)),
        ("Ceps = 0", Box::new(|f: &mut Fx| f.norm.ceps = 0)),
        ("Ceps = 2^40 + 1", Box::new(|f: &mut Fx| f.norm.ceps = (1 << 40) + 1)),
        ("tn = 10 (window 31, not 32)", Box::new(|f: &mut Fx| f.norm.tn = 10)),
        ("tn = 12 (window 33)", Box::new(|f: &mut Fx| f.norm.tn = 12)),
        ("a head multiplier 0", Box::new(|f: &mut Fx| f.tables.mult[0] = 0)),
        ("a head multiplier 2^12 + 1", Box::new(|f: &mut Fx| f.tables.mult[0] = 4097)),
    ] {
        let e = door(&*f);
        eprintln!("TOKEN-IO-R1 CONTROL #23d | {what} | predicted [the token-I/O door] | actual: {} | AS PREDICTED", e.chars().take(120).collect::<String>());
    }
    let e = TokenProfile::new(&fx.sh, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, Tier { lookup_ext_degree: 3, ..Tier::R1_MVP }).unwrap_err();
    assert!(e.contains("not built"), "{e}");
    // #22: a receipt re-read under another variant (P / F): since review
    // TR-3 no statement naming an unbuilt variant exists (the door refuses
    // it; tr3_* shows the verifier refusing one built around the door)
    for v in [SelectorVariant::SealedInInput, SelectorVariant::SealedInOutput] {
        let e = match statement(&fx, roots, v) {
            Err(e) => e,
            Ok(st2) => verify_token_run(&st2, &fx.blocks, &fx.tables, &p.segs, R1_DEV_POLICY).unwrap_err(),
        };
        record("22", &format!("the receipt re-read under variant {}", v.tag()), &[Site::Door], &e);
    }
    // ... and the prover refuses to build any variant but the public row at R1
    {
        let tp2 = TokenProfile::new(&fx.sh, &fx.tables, fx.bos, fx.norm, SelectorVariant::SealedInInput, Tier::R1_MVP).unwrap();
        let mut pp = honest(&fx, &tp);
        let e = prove_pipe(&fx, &tp2, &mut pp).err().expect("a P-variant run proved");
        assert!(e.contains("variant is not built"), "{e}");
    }
    // #20 (public-row analogue): the input endpoint opened with a claim count
    // other than its one, or in another place
    {
        let n = 256usize;
        let part = |row: usize, log: u32| crate::pcs::ZPart { slice: Slice { offset: row * n, log_size: log }, coef: Fp2::ONE, point: vec![Fp2::ONE; log as usize] };
        let good = ZClaim { parts: vec![part(0, 8), part(1, 8), part(2, 8)], value: Fp2::ZERO };
        let tr = Transcript::new(b"token I/O R1: endpoint claim schedule");
        check_token_endpoint_opening(std::slice::from_ref(&good), 1, n, &tr).expect("one claim at its own pair");
        assert!(check_token_endpoint_opening(&[], 1, n, &tr).is_err(), "no claim was accepted");
        assert!(check_token_endpoint_opening(&[good.clone(), good.clone()], 1, n, &tr).is_err(), "two claims were accepted");
        let mut swapped = p.segs.clone();
        swapped.swap(0, 1);
        let e = verify_token_run(&p.st, &fx.blocks, &fx.tables, &swapped, R1_DEV_POLICY).unwrap_err();
        eprintln!("TOKEN-IO-R1 CONTROL #20 | (public-row analogue) segments out of order | predicted [the run's counted segment geometry] | actual: {} | AS PREDICTED", e.chars().take(120).collect::<String>());
        let mut cut = p.segs.clone();
        let last = cut.len() - 1;
        let keep = cut[last].len() - 9;
        cut[last].truncate(keep);
        assert!(verify_token_run(&p.st, &fx.blocks, &fx.tables, &cut, R1_DEV_POLICY).is_err(), "a stage OUT segment missing its endpoint opening's tail verified");
    }
    // #21 (public-row analogue): an endpoint of another row count is refused
    // by the counted geometry (the spec DERIVES data + 5 rows)
    {
        let (ins, _) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
        assert_eq!(ins.commitment_rows(), ins.data_rows() + super::super::endpoint_g::MASK_ROWS);
        let lay = stage_in::layout(&fx.sh, &tp);
        let g = StageSegGeom { magic: STAGE_IN_MAGIC, lay: &lay, has_b_root: true, a_groups: stage_in::A_GROUPS, h_groups: stage_in::H_GROUPS, closes: vec![(Dim::of(&ins.params()), 1, ins.commitment_rows() + 1)], total: L + 2, index: 0 };
        let tr = p.st.transcript().unwrap();
        let e = g.decode(&p.segs[0], &tr.state(), &[0u8; 32]).err().expect("a 7-row endpoint geometry decoded a 6-row receipt");
        eprintln!("TOKEN-IO-R1 CONTROL #21 | (public-row analogue) endpoint declared with another row count | predicted [the derived geometry] | actual: {} | AS PREDICTED", e.chars().take(120).collect::<String>());
    }
    // the profile string: registered for the rung's block shape (CS-7), and
    // refused for a blocks-only run statement
    assert!(RunShape::new(Shape::rung_c6(), L, RUN_PROFILE_TOKEN_IO_RUNG_TC).err().unwrap().contains("ruling CS-7"));
    eprintln!("TOKEN-IO-R1 CONTROL #6 #8 #19 | hidden-length variant (SBOOL, IO-s, the sealed selector) | not applicable to the public-row rung R1 (D26's two-site endpoint is the next rung)");
}

// ------------------------------------------------------------------ 5. the D16 rule-5 audit

/// **D16 RULE 5 on the new layouts** (DESIGN 4.1, C-8): every committed value
/// that a relation multiplies by a non-unit coefficient is RANGED (byte /
/// sym lookups) or DETERMINED (by a relation over ranged / public values);
/// and every clause read over the integers stays far below `p / 2` over the
/// WHOLE declared class (the no-wrap premises).
#[test]
fn the_d16_rule_5_audit_of_the_new_layouts() {
    use stage_out::*;
    let fx = fx_generic();
    let tp = profile(&fx);
    // ---- every A plane, its non-unit coefficients and what bounds it
    let mut out: Vec<(usize, &str, &str, &str)> = vec![
        (A_D, "D", "2^tn, 2^(tn+1) (DZC c0, c1), 2 (TZC)", "determined: D = l0 + 256 l1 + 65536 l2 (TZC), limbs bytes (LZC)"),
        (A_DSQ, "Dsq", "unit", "determined: Dsq = D^2 (TZC)"),
        (A_TOK, "tok", "-2^-v (VZC l*), c2 (RSEL), -1 (IO-out u0)", "determined: tok = sum i e (A3) with e one-hot (A1 + A2) -> tok in [0, V)"),
        (A_M, "M", "unit in l*", "determined: M = l_j (A5 at i = j with delta_j = 0 by A6)"),
        (A_LIMB, "isqrt limbs", "256, 65536 (TZC)", "ranged: byte lookups (LZC), pad-zero"),
        (A_X, "x", "2 g0 Cn (DZC c0), x^2 (SS)", "ranged: int16 by c2 with two byte limbs; bound to B_out row T-1 (IO-in)"),
        (A_XL0, "x limb 0", "unit", "ranged: byte lookup"),
        (A_XL1, "x limb 1", "256 (c2)", "ranged: byte lookup"),
        (A_Y, "y", "2^(tn+1) D (c0), W' (HEAD)", "ranged: sym lookups y + 127, 127 - y in [0, 256)"),
        (A_E, "e", "c1 + c2 iota + c3 delta (RSEL)", "ranged: booleanity e(1 - e) = 0 (VZC), pad-zero"),
        (a_mult(tp.limbs), "U8 histogram", "1 / (alpha - v) (TAB)", "a LogUp multiplicity: no range needed (residue argument, counts < p)"),
    ];
    for k in 0..NORM_LIMBS {
        out.push((A_RHO0 + k, "rho limb", "256^k", "ranged: byte lookup"));
        out.push((A_SIG0 + k, "sigma limb", "256^k", "ranged: byte lookup"));
    }
    for k in 0..tp.limbs {
        out.push((A_LAM0 + k, "delta limb", "256^k 2^-v (l*), 256^k c3 (RSEL)", "ranged: byte lookup"));
    }
    out.sort_by_key(|r| r.0);
    let ids: Vec<usize> = out.iter().map(|r| r.0).collect();
    assert_eq!(ids, (0..=a_mult(tp.limbs)).collect::<Vec<_>>(), "the audit does not cover every stage-OUT A plane exactly once");
    let inn: Vec<(usize, &str, &str, &str)> = vec![
        (stage_in::A_TOK, "tok", "beta-free unit in q_t; -BOS clause", "determined: (tok_t, x~(t, r_emb)) is a row of the public table (LogUp) -> tok in [0, V); pad-zero beyond T"),
        (stage_in::A_MULT, "m", "1 / (alpha - tau_v) (table zero-check)", "a LogUp multiplicity: no range needed (residue in [1, T] nonzero since p > T)"),
    ];
    // ---- the no-wrap premises at the class edges (i128, exact)
    let p_half = i128::from(P / 2);
    let d = tp.d as i128;
    let cls = (127i128, CN_F_MAX as i128, 16u32, CEPS_F_MAX as i128);
    let d_max: i128 = 1 << 24; // three limbs
    let clauses: Vec<(&str, i128)> = vec![
        ("TZC Dsq = D^2", d_max * d_max),
        ("TZC Dsq + a1 - Ceps = sum x^2", d_max * d_max + d_max + cls.3),
        ("SS sum x^2 over d int16", d * 32768 * 32768),
        ("DZC c0 2 g0 Cn |x| (class edge)", 2 * cls.0 * cls.1 * 32768),
        ("DZC c0 2^(tn+1) D |y| (tn 16)", (1i128 << (cls.2 + 1)) * d_max * 127),
        ("DZC c1 sigma + rho + 1 - 2^(tn+1) D", (1i128 << 33) + (1i128 << (cls.2 + 1)) * d_max),
        ("HEAD |l| = 2^12 d 127^2", (1i128 << MULT_BITS) * d * 127 * 127),
        ("A5 identity 2^v (l_j - l_i) + (i - j)", 1i128 << tp.window_bits),
        ("A4 delta in limbs + identity", (1i128 << (8 * tp.limbs)) + (1i128 << tp.window_bits)),
        ("RSEL sum e over V_pad", tp.v_pad as i128),
        ("stage IN multiplicities <= T", tp.tokens as i128),
        ("stage OUT histogram <= lookups", 77_824),
    ];
    for (what, v) in &clauses {
        assert!(*v < p_half, "no-wrap: {what} = 2^{:.2} reaches p/2", (*v as f64).log2());
    }
    for r in out.iter().chain(inn.iter()) {
        eprintln!("TOKEN-IO-R1 D16 | plane {:2} {:14} | coefficients: {:42} | {}", r.0, r.1, r.2, r.3);
    }
    for (what, v) in &clauses {
        eprintln!("TOKEN-IO-R1 NOWRAP | {what:42} | 2^{:.2} < p/2 = 2^63", (*v as f64).log2());
    }
}

// ------------------------------------------------------------------ the fresh-process pair

fn out_dir() -> std::path::PathBuf {
    std::path::PathBuf::from(std::env::var("TOKEN_IO_R1_OUT").expect("set TOKEN_IO_R1_OUT to the evidence directory"))
}

/// **PROVE TO A DIRECTORY** (run alone; `#[ignore]`): both fixtures, each to
/// `$TOKEN_IO_R1_OUT/<fixture>/`: the `L + 2` segments, the public
/// `statement.txt` (roots, counted lengths, timings) and the synthetic
/// cross-check inputs for the Python reference (R0's semantics).
#[test]
#[ignore]
fn token_io_r1_prove_to_dir() {
    for fx in [fx_r0(), fx_generic()] {
        let tp = profile(&fx);
        let mut pipe = honest(&fx, &tp);
        let b_out = pipe.planes.last().unwrap().clone();
        let p = prove_pipe(&fx, &tp, &mut pipe).unwrap();
        let t0 = std::time::Instant::now();
        verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, R1_DEV_POLICY).expect("in-process verify");
        let vs = t0.elapsed().as_secs_f64();
        let dir = out_dir().join(fx.name);
        std::fs::create_dir_all(&dir).unwrap();
        for (k, s) in p.segs.iter().enumerate() {
            std::fs::write(dir.join(format!("segment_{k:03}.bin")), s).unwrap();
        }
        owner_check_input(&p.st, &p.hand.input, &fx.tokens).expect("the input owner's check");
        let tok = owner_check_output(&p.st, &p.hand.output).expect("the output owner's check") as u64;
        let (ir, or) = p.st.roots();
        let stmt = format!(
            "profile {}\nL {}\ncontext {}\ninput_root {}\noutput_root {}\nsegment_bytes {:?}\ntotal_bytes {}\nprove_seconds {:.3}\nstage_seconds {:?}\nin_process_verify_seconds {:.3}\nparameter_line {}\n",
            RUN_PROFILE_TOKEN_IO_RUNG_TC,
            L,
            hex(&ctx()),
            hex(&ir),
            hex(&or),
            p.stats.segment_bytes,
            p.segs.iter().map(|s| s.len()).sum::<usize>(),
            p.secs,
            p.stats.prove_s,
            vs,
            p.st.parameter_line().unwrap()
        );
        std::fs::write(dir.join("statement.txt"), stmt).unwrap();
        // the OWNER's view (synthetic data): the decommitted id; and the
        // inputs of the independent Python reference (R0's semantics)
        let row: Vec<String> = (0..tp.d).map(|i| b_out[(tp.tokens - 1) * tp.d_pad + i].to_string()).collect();
        let cross = format!(
            "{{\"fixture\": \"{}\", \"note\": \"public synthetic data; the B_out row is a synthetic run's hidden intermediate, exported for the Python reference only\", \"decommitted_next_token\": {tok}, \"tokens\": {:?}, \"x_row\": [{}], \"g0\": {}, \"cn\": {}, \"tn\": {}, \"ceps\": {}, \"V\": {}, \"d\": {}, \"head_sha256_blake3\": \"{}\", \"multipliers\": {:?}}}\n",
            fx.name,
            fx.tokens,
            row.join(", "),
            fx.norm.g0,
            fx.norm.cn,
            fx.norm.tn,
            fx.norm.ceps,
            tp.v,
            tp.d,
            hex(&tp.head_digest),
            fx.tables.mult
        );
        std::fs::write(dir.join("crosscheck.json"), cross).unwrap();
        let head: Vec<u8> = fx.tables.head.iter().map(|w| *w as u8).collect();
        std::fs::write(dir.join("head_int8.bin"), head).unwrap();
        eprintln!("TOKEN-IO-R1 PROVED {} -> {}: next token {tok}, {} B, prove {:.2} s, in-process verify {vs:.2} s [MEASURED, shared box, n=1]", fx.name, dir.display(), p.segs.iter().map(|s| s.len()).sum::<usize>(), p.secs);
    }
}

/// **VERIFY FROM THE SAVED BYTES IN A FRESH PROCESS** (run alone, after the
/// prover; `#[ignore]`): the public model is regenerated from its seeds and
/// its digests are the statement's; the roots are read from `statement.txt`;
/// every segment is read from disk. A one-byte change to a copy is refused.
#[test]
#[ignore]
fn token_io_r1_verify_from_dir() {
    for fx in [fx_r0(), fx_generic()] {
        let dir = out_dir().join(fx.name);
        let stmt = std::fs::read_to_string(dir.join("statement.txt")).expect("statement.txt");
        let field = |k: &str| stmt.lines().find_map(|l| l.strip_prefix(&format!("{k} "))).unwrap_or_else(|| panic!("{k} missing")).to_string();
        let unhex = |s: String| -> Digest {
            let mut d = [0u8; 32];
            for i in 0..32 {
                d[i] = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).unwrap();
            }
            d
        };
        assert_eq!(field("context"), hex(&ctx()));
        let roots = (unhex(field("input_root")), unhex(field("output_root")));
        let st = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
        assert_eq!(field("parameter_line"), st.parameter_line().unwrap(), "the saved run is another statement");
        let segs: Vec<Vec<u8>> = (0..L + 2).map(|k| std::fs::read(dir.join(format!("segment_{k:03}.bin"))).unwrap()).collect();
        let t0 = std::time::Instant::now();
        verify_token_run(&st, &fx.blocks, &fx.tables, &segs, R1_DEV_POLICY).unwrap_or_else(|e| panic!("{}: the saved run does not verify in a fresh process: {e}", fx.name));
        let vs = t0.elapsed().as_secs_f64();
        let mut bad = segs.clone();
        let at = bad[L + 1].len() / 2;
        bad[L + 1][at] ^= 1;
        assert!(verify_token_run(&st, &fx.blocks, &fx.tables, &bad, R1_DEV_POLICY).is_err(), "a one-bit change verified");
        eprintln!("TOKEN-IO-R1 FRESH-PROCESS VERIFY {}: accepted from {} ({} B) in {vs:.2} s; a one-bit change refused [MEASURED, shared box, n=1]", fx.name, dir.display(), segs.iter().map(|s| s.len()).sum::<usize>());
    }
}

// ------------------------------------------------------------------ 6. the review's fixes (TR-1 .. TR-5)

/// **REVIEW TR-1 / TR-2, FAILING FIRST (2026-10-17).** The tier door refuses,
/// by name and on both sides (`Tier::check` inside `TokenProfile::new`), every
/// tier below DESIGN B-1's floors (each row of the review's reproduction
/// table), a column-check count other than `zk.rs`'s `MASK_Q`, and every tier
/// that is not one of the registered constants (name AND levers).
#[test]
fn tr1_the_tier_door_refuses_every_tier_below_b1_and_every_unregistered_tier() {
    let fx = fx_generic();
    let r = Tier::R1_MVP;
    for t in Tier::REGISTERED {
        t.check().unwrap_or_else(|e| panic!("a registered tier was refused: {e}"));
        assert!(t.stage_log_n >= Tier::B1_STAGE_LOG_N_MIN);
        assert!(t.per_opening_log2(t.stage_log_n, t.stage_inv_rate) <= Tier::B1_STAGE_OPENING_LOG2_MAX);
        assert!(t.per_opening_log2(t.ep_log_n, t.ep_inv_rate) <= Tier::B1_ENDPOINT_OPENING_LOG2_MAX);
    }
    let cases: Vec<(&str, Tier, &str)> = vec![
        ("token endpoints 2^8 rate 1/4 (the v1 B-1 hole, 2^-67.34)", Tier { ep_inv_rate: 4, ..r }, "B-1"),
        ("token endpoints 2^8 rate 1/2 (RS(512, 512), zero distance)", Tier { ep_inv_rate: 2, ..r }, "B-1"),
        ("stage commitments at 2^9 (2^-86.28)", Tier { stage_log_n: 9, ..r }, "B-1"),
        ("stage commitments at 2^11 rate 1/8 (per opening strong, row width below the floor)", Tier { stage_log_n: 11, stage_inv_rate: 8, ..r }, "B-1"),
        ("Q = 128", Tier { opened_cols: 128, ..r }, "MASK_Q"),
        ("Q = 1", Tier { opened_cols: 1, ..r }, "MASK_Q"),
        ("a stronger tier under the registered name (endpoints rate 1/16)", Tier { ep_inv_rate: 16, ..r }, "registered"),
        ("R1_MVP's levers under another name", Tier { name: "mvp-128 (unregistered)", ..r }, "registered"),
    ];
    for (what, t, want) in cases {
        let e = t.check().err().unwrap_or_else(|| panic!("REVIEW TR-1: the tier door ADMITTED {what}"));
        assert!(e.contains(want), "REVIEW TR-1: {what} was refused for another reason: {e}");
        let e2 = TokenProfile::new(&fx.sh, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, t).err().expect("TokenProfile::new admitted a tier the door refuses");
        assert_eq!(e, e2);
        eprintln!("TOKEN-IO-R1 REVIEW TR-1 | {what} | refused at the tier door: {e}");
    }
}

/// **REVIEW TR-1, FAILING FIRST: the derived whole-run figure and the
/// verifier's minimum.** The statement carries the run's derived figure
/// (recounted here opening by opening), it is bound through the parameter
/// line, and a verifier whose policy asks for more refuses the statement by
/// name before reading any segment.
#[test]
fn tr1_the_verifier_refuses_a_statement_below_its_minimum_whole_run_figure() {
    let fx = fx_generic();
    let sh = &fx.sh;
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap();
    let w = p.st.whole_run().clone();
    // the openings, counted independently: two stages x (A, H) at 2^12 rate
    // 1/4, their two M and the L blocks' M, two token endpoints at 2^8 rate
    // 1/8, the L blocks' A and H, the L + 1 boundaries
    let t = tp.tier;
    let mut col = vec![t.per_opening_log2(12, 4); 4];
    col.extend(vec![mask_opening_log2(); 2 + L]);
    col.extend(vec![t.per_opening_log2(8, 8); 2]);
    col.extend(vec![hiding_opening_log2(sh.log_cols, sh.inv_rate, sh.opened_cols); 2 * L]);
    col.extend(vec![hiding_opening_log2(sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols); L + 1]);
    assert_eq!(w.openings, col.len(), "the opening count");
    let column: f64 = col.iter().map(|x| x.exp2()).sum();
    assert!((w.column_log2 - column.log2()).abs() < 1e-9, "the column term {w:?}");
    assert!(w.logup_log2 < w.column_log2 - 10.0, "at this rung the lookup term is far below the column term: {w:?}");
    assert_eq!(w.floor_bits, 93, "the rung's derived whole-run figure: {w:?}");
    assert!(p.st.parameter_line().unwrap().contains("/whole-run-floor-93-bits-"), "the figure is not bound through the parameter line");
    eprintln!(
        "TOKEN-IO-R1 REVIEW TR-1 WHOLE-RUN | openings {} | column 2^{:.2} | logup (derived) 2^{:.2} | total 2^{:.2} | floor {} bits [COUNTED]",
        w.openings, w.column_log2, w.logup_log2, w.total_log2, w.floor_bits
    );
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, VerifierPolicy { min_whole_run_bits: 93 }).expect("a 93-bit policy accepts the 93-bit rung");
    for min in [94u32, 95, 100, 128] {
        let e = verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, VerifierPolicy { min_whole_run_bits: min }).err().unwrap_or_else(|| panic!("REVIEW TR-1: a {min}-bit policy ACCEPTED a 93-bit statement"));
        assert!(e.contains("below the verifier's minimum"), "{e}");
        // before any segment is read: the same refusal with no segments
        let e2 = verify_token_run(&p.st, &fx.blocks, &fx.tables, &[], VerifierPolicy { min_whole_run_bits: min }).unwrap_err();
        assert_eq!(e, e2);
        eprintln!("TOKEN-IO-R1 REVIEW TR-1 POLICY | minimum {min} bits | refused: {e}");
    }
}

/// **REVIEW TR-2, FAILING FIRST.** The mask commitment `M`'s opening is
/// sized from `zk.rs` (`MASK_Q` columns, `MASK_VEC`, `MASK_DOM`), whatever
/// the stage's own column-check count.
#[test]
fn tr2_the_mask_opening_is_sized_by_zk_mask_q_not_by_the_tier() {
    let fx = fx_generic();
    let tp = profile(&fx);
    assert_eq!((MASK_VEC, MASK_DOM, MASK_PATH), (1024, 4096, 12));
    for q in [128usize, 256, 320] {
        let mut lay = stage_in::layout(&fx.sh, &tp);
        lay.params.num_col_checks = q;
        let g = StageSegGeom { magic: STAGE_IN_MAGIC, lay: &lay, has_b_root: true, a_groups: stage_in::A_GROUPS, h_groups: stage_in::H_GROUPS, closes: vec![], total: L + 2, index: 0 };
        assert_eq!(g.mask_checks(), crate::zk::MASK_Q, "REVIEW TR-2: a Q = {q} stage sizes its M opening by its own Q");
        assert_eq!(g.mask_len(), 2 * MASK_VEC * 16 + crate::zk::MASK_Q * (8 + lay.m_rows() * 8 + 32 + MASK_PATH * 32));
    }
}

/// **REVIEW TR-3, FAILING FIRST.** An unbuilt selector variant (P, F) is
/// refused by the statement's door, by the endpoint specs and by the verifier
/// itself (a statement built around the door), each by name.
#[test]
fn tr3_unbuilt_variants_are_refused_by_the_statement_the_endpoints_and_the_verifier() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap();
    let roots = p.st.roots();
    for v in [SelectorVariant::SealedInInput, SelectorVariant::SealedInOutput] {
        let e = statement(&fx, roots, v).err().unwrap_or_else(|| panic!("REVIEW TR-3: a {} statement was BUILT", v.tag()));
        assert!(e.contains("variant is not built"), "{e}");
        let tpv = TokenProfile::new(&fx.sh, &fx.tables, fx.bos, fx.norm, v, Tier::R1_MVP).expect("the profile text names the variant");
        let e = endpoint_specs(&fx.sh, ctx(), &tpv).err().unwrap_or_else(|| panic!("REVIEW TR-3: endpoint specs were built for {}", v.tag()));
        assert!(e.contains("variant is not built"), "{e}");
        let mut st2 = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
        st2.tp.variant = v;
        let e = verify_token_run(&st2, &fx.blocks, &fx.tables, &p.segs, R1_DEV_POLICY).err().expect("REVIEW TR-3: THE VERIFIER ACCEPTED AN UNBUILT VARIANT");
        assert!(e.contains("variant is not built"), "{e}");
        eprintln!("TOKEN-IO-R1 REVIEW TR-3 | variant {} | refused by the statement, the endpoint specs and the verifier: {e}", v.tag());
    }
}

/// **REVIEW TR-4, FAILING FIRST.** The two owner checks take the VERIFIED
/// statement and check the plane rules (DESIGN 3.4, D26 C-d): planes sealed
/// by the real specs, whose roots the decommitments DO rebuild, are refused
/// when position 0 is not BOS, a pad word is nonzero, an id leaves the
/// vocabulary, or the plane is not the owner's prompt.
#[test]
fn tr4_the_owner_checks_take_the_verified_statement_and_check_the_plane_rules() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let want = pipe.out_values.tok;
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap();
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, R1_DEV_POLICY).expect("the honest run verifies");
    owner_check_input(&p.st, &p.hand.input, &fx.tokens).expect("the honest input owner");
    assert_eq!(owner_check_output(&p.st, &p.hand.output).unwrap(), want);
    let mut other = fx.tokens.clone();
    other[3] = (other[3] + 1) % 300;
    let e = owner_check_input(&p.st, &p.hand.input, &other).err().expect("REVIEW TR-4: another prompt passed the input owner's check");
    assert!(e.contains("not the owner's prompt"), "{e}");
    let e = owner_check_input(&p.st, &p.hand.input, &fx.tokens[..tp.tokens - 1]).err().expect("REVIEW TR-4: a short prompt passed");
    assert!(e.contains("prompt"), "{e}");
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let tag = fx.sh.hash_tag();
    let t = tp.tokens;
    // (what, input plane, prompt, output plane, which owner, expected)
    let mut cases: Vec<(&str, Vec<Fp>, Vec<u64>, Vec<Fp>, bool, &str)> = Vec::new();
    {
        let mut ip = pipe.in_plane.clone();
        let mut pr = fx.tokens.clone();
        ip[0] = Fp::new(5);
        pr[0] = 5;
        cases.push(("input: position 0 is not BOS (the prompt agrees)", ip, pr, pipe.out_plane.clone(), true, "BOS"));
    }
    {
        let mut ip = pipe.in_plane.clone();
        ip[t] = Fp::new(7);
        cases.push(("input: a nonzero pad word", ip, fx.tokens.clone(), pipe.out_plane.clone(), true, "pad word"));
    }
    {
        let mut ip = pipe.in_plane.clone();
        let mut pr = fx.tokens.clone();
        ip[2] = Fp::new(300);
        pr[2] = 300;
        cases.push(("input: an id outside the vocabulary (the prompt agrees)", ip, pr, pipe.out_plane.clone(), true, "vocabulary"));
    }
    {
        let mut op = pipe.out_plane.clone();
        op[0] = Fp::new(300);
        cases.push(("output: an id outside the vocabulary", pipe.in_plane.clone(), fx.tokens.clone(), op, false, "vocabulary"));
    }
    {
        let mut op = pipe.out_plane.clone();
        op[5] = Fp::new(1);
        cases.push(("output: a nonzero pad word", pipe.in_plane.clone(), fx.tokens.clone(), op, false, "pad word"));
    }
    for (what, ip, pr, op, input, want_e) in cases {
        let (roots, owners) = seal_endpoints(&ins, &outs, &ip, &op, &tag).unwrap();
        let st = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
        let (din, dout) = (Decommitment::of(&owners.input), Decommitment::of(&owners.output));
        // the binding holds: both decommitments rebuild their roots
        owner_rebuild_root(&st.in_spec, &roots.0, &din, &tag).expect("the tampered input plane rebuilds its root");
        owner_rebuild_root(&st.out_spec, &roots.1, &dout, &tag).expect("the tampered output plane rebuilds its root");
        let e = if input { owner_check_input(&st, &din, &pr).err() } else { owner_check_output(&st, &dout).err() };
        let e = e.unwrap_or_else(|| panic!("REVIEW TR-4: the owner's check ACCEPTED {what}"));
        assert!(e.contains(want_e), "REVIEW TR-4: {what} was refused for another reason: {e}");
        eprintln!("TOKEN-IO-R1 REVIEW TR-4 | {what} | refused by the owner's check: {e}");
    }
}

/// **REVIEW TR-5, FAILING FIRST.** The head-word class is `[-127, 127]`
/// (DESIGN 3.1's clip; D24 F-1: every exportable constant has a declared
/// class); a `-128` word is refused at the door.
#[test]
fn tr5_a_head_word_of_minus_128_is_refused_at_the_door() {
    let mut fx = fx_generic();
    fx.tables.head[17] = -128;
    let e = TokenProfile::new(&fx.sh, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, Tier::R1_MVP).err().expect("REVIEW TR-5: a -128 head word was admitted");
    assert!(e.contains("[-127, 127]"), "{e}");
    eprintln!("TOKEN-IO-R1 REVIEW TR-5 | a -128 head word | refused at the door: {e}");
}

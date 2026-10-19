//! **TOKEN I/O R3 (Llama-3-8B, T32, 32 blocks): THE ACCEPTANCE TESTS.** TEST
//! CODE ONLY; no privacy claim (the G-1..G-7 gates are owed; no privacy
//! figure is quoted). Written before the R3 profile is registered (PROGRESS,
//! R3 plan of 01:46): every test that builds an R3 statement fails first at
//! ruling CS-7.
//!
//! 1. the counted layout at Llama-3-8B equals `counts/r3_counts.json` (stage
//!    IN A 41 / H 76 / M 12, stage OUT A 374 / H 302 / M 26, 970,752 byte
//!    lookups, window 56, 7 limbs) and the derived whole-run figure of the
//!    32-block run is at least the MVP's 95 bits;
//! 2. the multi-row planes at `V_pad = 2^17` (32 rows per vocabulary plane)
//!    on a cheap fixture (the rung's blocks, `V = 128,256`, BOS 128,000): an
//!    honest run, and the R2 controls moved to the LAST row and to padded
//!    entries above `V`;
//! 3. block streaming: a streamed run proves and verifies; a stream handing
//!    another block at a stage is refused by name (CS-6) on both sides;
//! 4. the parallel folds equal the serial ones; the table loader (R2's file
//!    format) round-trips and refuses a table that is not the recorded one;
//! 5. the R3 run itself (`#[ignore]`d, run alone, guarded): the trained 8B
//!    export's 32 blocks streamed, generic or trained tables; prove to a
//!    directory, then verify in a FRESH process from the saved bytes under a
//!    95-bit policy.

use super::run::*;
use super::stage_in::{self, StageInWitness};
use super::stage_out::{self, StageOutWitness};
use super::tests::*;
use super::*;
use super::super::layout::{Ids, A_X2};
use super::super::run::{BlockRef, RunShape, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32};
use super::super::trained_block::{sha256, Constants, TrainedExport};
use super::super::trained_statement::{IntegerCalibration, Provenance, TrainedModelStatement};
use super::super::BlockPublic;
use std::path::{Path, PathBuf};

fn eightb() -> Shape {
    Shape::llama3_8b_t32_trained(&r3_calibration(), R3_F_E).expect("the trained Llama-3-8B T32 shape")
}

// ------------------------------------------------------------------ 1. the counted layout

/// **R3 TEST 1, written before the R3 construction (PROGRESS 01:46).** The
/// code's counted layout at Llama-3-8B T32 equals `counts/r3_counts.py`'s
/// figures (the design counter, per-row head, stages at 2^12); the window is
/// 32 bits only at `tn = 9` at width 4,096; the derived whole-run figure of
/// the 32-block run is at least 95 bits; the R3 statement builds (CS-7: the
/// failing-first point) and its counted segment lengths are printed beside
/// the counter's receipts.
#[test]
fn r3_the_counted_layout_is_the_counters() {
    let sh = eightb();
    let tables = census_tables(RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32);
    let tp = TokenProfile::new(&sh, tables, R3_BOS, R3_NORM_GENERIC, SelectorVariant::PublicRow, Tier::R1_MVP).expect("the R3 token profile");
    assert_eq!((tp.window_bits, tp.limbs, tp.v_pad, tp.log_v, tp.d_pad, tp.t_pad), (56, 7, 131_072, 17, 4096, 32), "the R3 keyed window and paddings");
    assert_eq!((tp.ti_log(), tp.voc_log(), tp.lo_log(), tp.do_log(), tp.vo_log(), tp.tab_log()), (12, 17, 12, 12, 17, 12), "the stage domains");
    let li = stage_in::layout(&sh, &tp);
    assert_eq!((li.a_rows, li.h_rows, li.m_rows()), (41, 76, 12), "stage IN rows");
    assert_eq!(li.elems(), 479_232, "stage IN committed elements");
    assert_eq!((li.a_sites_total(), li.h_sites_total(), li.sched.slots.len()), (3, 3, 4), "stage IN sites and slots");
    assert_eq!((li.a_log.clone(), li.h_log.clone()), (vec![12, 17], vec![12, 17, 12]), "stage IN plane logs (m and h_tab span 32 rows)");
    let lo = stage_out::layout(&sh, &tp);
    assert_eq!((lo.a_rows, lo.h_rows, lo.m_rows()), (374, 302, 26), "stage OUT rows");
    assert_eq!(lo.elems(), 2_768_896, "stage OUT committed elements");
    assert_eq!((lo.a_sites_total(), lo.h_sites_total(), lo.sched.slots.len()), (49, 13, 11), "stage OUT sites and slots");
    assert_eq!(stage_out::hv(tp.limbs), 4, "four VZC helpers");
    assert_eq!(stage_out::logup_size(&lo, &tp), (970_752, 256), "stage OUT byte lookups");
    let (ins, outs) = endpoint_specs(&sh, *blake3::hash(b"r3 counted").as_bytes(), &tp).unwrap();
    assert_eq!((ins.len(), ins.data_rows(), ins.commitment_rows()), (256, 1, 6), "the input token endpoint");
    assert_eq!((outs.len(), outs.data_rows(), outs.commitment_rows()), (256, 1, 6), "the output token endpoint");
    // the window is exactly 32 only at tn = 9 at width 4,096
    let e = TokenProfile::new(&sh, tables, R3_BOS, FinalNorm { tn: 10, ..R3_NORM_GENERIC }, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap_err();
    assert!(e.contains("exactly 32"), "{e}");
    let w = whole_run_of(&sh, 32, &tp);
    assert!(w.floor_bits >= 95, "the R3 run's derived whole-run figure is below the MVP's 95 bits: {w:?}");
    // the R3 statement (ruling CS-7) and its counted segments
    let (st, _, _) = census_statement(RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32, 32);
    assert_eq!(st.whole_run().floor_bits, w.floor_bits);
    let lens = st.segment_lens().unwrap();
    assert_eq!(lens.len(), 34);
    eprintln!(
        "TOKEN-IO-R3 COUNTS stage IN A {} H {} M {} elems {} | stage OUT A {} H {} M {} elems {} u8 {} | window {} limbs {} | segments: stage IN {} B (counter 1415040), block {} B x 32, stage OUT {} B (counter 3222400), total {} B | whole run (L = 32): openings {} column 2^{:.2} logup 2^{:.2} pcs-field+sumcheck bound 2^{:.2} total 2^{:.2} floor {} bits [COUNTED]",
        li.a_rows,
        li.h_rows,
        li.m_rows(),
        li.elems(),
        lo.a_rows,
        lo.h_rows,
        lo.m_rows(),
        lo.elems(),
        stage_out::logup_size(&lo, &tp).0,
        tp.window_bits,
        tp.limbs,
        lens[0],
        lens[1],
        lens[33],
        lens.iter().sum::<usize>(),
        w.openings,
        w.column_log2,
        w.logup_log2,
        w.omitted_log2,
        w.total_log2,
        w.floor_bits
    );
    // review R2-1: the bound is in the total before the floor, and the floor
    // still holds with it
    assert!(w.omitted_log2 < -104.0 && w.total_log2 <= -(w.floor_bits as f64), "{w:?}");
}

/// **R3 (review round 2): V_pad = 2^17 is exactly the door's limit.** V =
/// 2^17 is admitted (V_pad 2^17, 32-row planes); V = 2^17 + 1 is refused by
/// name (its padded cube would be 2^18).
#[test]
fn r3_v_pad_2_17_is_the_doors_edge() {
    let sh = rung();
    let at = generic_tables_v(1 << 17, sh.width, 0x6564_6765);
    let tp = TokenProfile::new(&sh, &at, R3_BOS, norm(), SelectorVariant::PublicRow, Tier::R1_MVP).expect("V = 2^17 is admitted");
    assert_eq!((tp.v_pad, tp.voc_log(), tp.vo_log()), (1 << 17, 17, 17));
    drop(at);
    let over = generic_tables_v((1 << 17) + 1, sh.width, 0x6564_6766);
    let e = TokenProfile::new(&sh, &over, R3_BOS, norm(), SelectorVariant::PublicRow, Tier::R1_MVP).unwrap_err();
    assert!(e.contains("V = 131073 is outside its declared class"), "{e}");
    eprintln!("TOKEN-IO-R3 EDGE | V = 2^17: admitted (V_pad 2^17, 32-row planes) | V = 2^17 + 1: refused: {e}");
}

/// **R3 (review round 2, R2-5): a refused stage-OUT witness publishes
/// nothing.** The run prover asks for the stage-OUT witness FIRST and runs
/// its byte-lookup refusal before stage IN; a witness with a non-byte limb
/// is refused with ZERO segments handed to the sink.
#[test]
fn r3_a_refused_stage_out_witness_emits_no_segment() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    pipe.stage_out.planes[stage_out::A_LAM0][3] = Fp::new(300);
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
    let st = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
    let mut emitted = 0usize;
    let e = prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners, &mut |_, _| {
        emitted += 1;
        Ok(())
    })
    .err()
    .expect("REVIEW R2-5: a non-byte stage-OUT witness PROVED");
    assert!(e.contains("not a byte"), "{e}");
    assert_eq!(emitted, 0, "REVIEW R2-5: {emitted} segment(s) reached the sink before the refusal");
    eprintln!("TOKEN-IO-R3 REVIEW R2-5 | a non-byte stage-OUT limb | refused before any segment: {e} | segments emitted: {emitted}");
}

// ------------------------------------------------------------------ 2. the multi-row planes at V_pad 2^17

/// the first entry of the last row of a 2^17 vocabulary plane
const LAST_ROW: usize = (1 << 17) - (1 << 12);

/// the V_pad 2^17 fixture: the rung's blocks, a generic model of 128,256
/// tokens (32 rows per vocabulary plane), BOS 128,000, a prompt with ids in
/// the first, a middle and the LAST row
fn fx_vpad17() -> Fx {
    let sh = rung();
    let blocks = blocks(&sh, 2);
    let model = model(&sh, &blocks);
    let mut s = 0x7633_3137u64;
    let mut tokens = vec![R3_BOS];
    while tokens.len() < sh.tokens {
        tokens.push(lcg(&mut s) % 128_256);
    }
    tokens[7] = 127_500;
    tokens[9] = 65_000;
    tokens[11] = 300;
    Fx { name: "vpad17-v128256", tables: generic_tables_v(128_256, sh.width, 0x7633_7462), sh, blocks, model, tokens, norm: norm(), bos: R3_BOS }
}

/// **R3 MULTI-ROW at V_pad 2^17.** An honest run with 32-row vocabulary
/// planes and the Llama-3 BOS proves, verifies, and both owners check.
#[test]
fn r3_vpad17_an_honest_run_proves_verifies_and_both_owners_check() {
    let fx = fx_vpad17();
    let tp = profile(&fx);
    assert_eq!((tp.v_pad, tp.voc_log(), tp.vo_log(), tp.limbs), (131_072, 17, 17, 7));
    let li = stage_in::layout(&fx.sh, &tp);
    let lo = stage_out::layout(&fx.sh, &tp);
    assert_eq!(li.a_log, vec![12, 17], "m spans 32 rows");
    assert_eq!(lo.a_log[stage_out::A_E], 17, "e spans 32 rows");
    let mut pipe = honest(&fx, &tp);
    let want = pipe.out_values.tok;
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap_or_else(|e| panic!("the honest V_pad 2^17 run did not prove: {e}"));
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, VerifierPolicy { min_whole_run_bits: 93 }).unwrap_or_else(|e| panic!("the honest V_pad 2^17 run did not verify: {e}"));
    assert_eq!(p.segs.iter().map(|s| s.len()).collect::<Vec<_>>(), p.st.segment_lens().unwrap(), "the segment lengths are not the counted ones");
    owner_checks(&fx, &p, &tp, want);
    eprintln!(
        "TOKEN-IO-R3 VPAD17 HONEST: V 128256 (V_pad 2^17, 32 rows per vocabulary plane), BOS 128000, next token {want}, stage IN A {} H {} / stage OUT A {} H {} rows, prove {:.2} s, receipt {} B [MEASURED, shared box, n=1, test build]",
        li.a_rows,
        li.h_rows,
        lo.a_rows,
        lo.h_rows,
        p.secs,
        p.segs.iter().map(|s| s.len()).sum::<usize>()
    );
}

/// **R3 MULTI-ROW CONTROLS at V_pad 2^17**: the R2 controls on the LAST row
/// of a 32-row plane and on padded entries above `V = 128,256`, plus the
/// per-profile BOS at its Llama-3 value.
#[test]
fn r3_vpad17_controls_are_refused_where_predicted() {
    let fx = fx_vpad17();
    let tp = profile(&fx);
    let base = honest(&fx, &tp);
    let l = base.out_values.logits.clone();
    let j = base.out_values.tok;
    let max = l[j];
    let ep = |id: u64| stage_out::endpoint_plane(&tp, id);
    let jl = (LAST_ROW..tp.v).filter(|i| *i != j && l[*i] < max).max_by_key(|i| (l[*i], std::cmp::Reverse(*i))).expect("a non-maximal last-row entry");
    {
        let mut p = honest(&fx, &tp);
        let pad = tp.v + 5;
        argmax_planes(&tp, &mut p.stage_out, &[(pad, Fp::ONE)], Fp::new(pad as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, pad), false);
        p.out_plane = ep(pad as u64);
        record("R3-1", "(#1, last row) e on the padded entry V + 5 = 128,261, tok = V + 5, M = max + 1", &[Site::OutSlot(stage_out::SO_VZC)], &forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        argmax_planes(&tp, &mut p.stage_out, &[(jl, Fp::ONE)], Fp::new(jl as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, jl), false);
        p.out_plane = ep(jl as u64);
        record("R3-2", "(#2, last row) non-maximal j >= 126,976, M = max + 1, deltas in bytes (A6-only)", &[Site::OutSlot(stage_out::SO_RSEL)], &forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        argmax_planes(&tp, &mut p.stage_out, &[(jl, Fp::ONE)], Fp::new(jl as u64), Fp::from_i64(l[jl]), &|i| keyed(&tp, l[jl], l[i], i, jl), true);
        p.out_plane = ep(jl as u64);
        record("R3-3", "(#12b, last row) non-maximal j >= 126,976, M = l_j, delta field values in a non-byte 7th limb", &[Site::OutLogUp], &forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        let i = (LAST_ROW..tp.v).find(|i| p.stage_out.planes[stage_out::A_LAM0 + 1][*i] != Fp::ZERO).expect("a last-row entry with a second limb");
        p.stage_out.planes[stage_out::A_LAM0][i] = p.stage_out.planes[stage_out::A_LAM0][i].add(Fp::new(256));
        p.stage_out.planes[stage_out::A_LAM0 + 1][i] = p.stage_out.planes[stage_out::A_LAM0 + 1][i].sub(Fp::ONE);
        record("R3-4", "(#15, last row) a delta limb that is not a byte at an entry >= 126,976 (same delta value)", &[Site::OutLogUp], &forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        p.stage_out.planes[stage_out::A_LAM0][tp.v + 9] = Fp::new(1);
        record("R3-5", "a nonzero delta limb on the padded entry V + 9 (last row)", &[Site::OutSlot(stage_out::SO_VZC)], &forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        let mut m = hist(&tp, &fx.tokens);
        m[127_500] = m[127_500].sub(Fp::ONE);
        m[127_500 - LAST_ROW] = m[127_500 - LAST_ROW].add(Fp::ONE);
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &fx.tokens), mult: m, hq_zero: vec![] };
        record("R3-6", "stage IN histogram: one count moved from a last-row id (127,500) to its first-row twin (tok, rows honest)", &[Site::InLogUp], &forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[5] = (tp.v + 13) as u64;
        let mut b = p.b_in.clone();
        set_row(&tp, &mut b, 5, fx.tables.emb_row(0));
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &toks), mult: hist(&tp, &toks), hq_zero: vec![] };
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        with_b_in(&fx, &tp, &mut p, b);
        record("R3-7", "(#16c, last row) padded token id V + 13, histogram on that pad entry", &[Site::InSlot(stage_in::SI_TZC)], &forge(&fx, &tp, p));
    }
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[0] = R3_BOS - 1;
        let mut b = p.b_in.clone();
        set_row(&tp, &mut b, 0, fx.tables.emb_row((R3_BOS - 1) as usize));
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &toks), mult: hist(&tp, &toks), hq_zero: vec![] };
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        with_b_in(&fx, &tp, &mut p, b);
        record("R3-8", "(#5, Llama-3 BOS) position 0 = 127,999 (not BOS 128,000), otherwise consistent", &[Site::InSlot(stage_in::SI_QZC)], &forge(&fx, &tp, p));
    }
}

// ------------------------------------------------------------------ 3. block streaming

/// a streaming block source over generated blocks: block `order[k]` handed
/// at stage `k`, ONE resident at a time (R3's loader in miniature)
struct GenBlocks {
    all: Vec<BlockPublic>,
    order: Vec<usize>,
    cur: Option<(usize, std::sync::Arc<BlockPublic>)>,
    loads: usize,
}

impl TokenBlocks for GenBlocks {
    fn count(&self) -> usize {
        self.order.len()
    }
    fn block(&mut self, k: usize) -> Result<BlockRef<'_>, String> {
        if let Some((j, a)) = &self.cur {
            if *j == k {
                return Ok(BlockRef::Shared(a.clone()));
            }
        }
        self.cur = None;
        let a = std::sync::Arc::new(self.all.get(*self.order.get(k).ok_or("no such stage")?).ok_or("no such block")?.clone());
        self.cur = Some((k, a.clone()));
        self.loads += 1;
        Ok(BlockRef::Shared(a))
    }
}

/// **R3 STREAMING.** A run whose blocks are handed one at a time proves and
/// verifies; a stream that hands the other block at stage 0 is refused by
/// name at that stage by the prover and by the verifier (CS-6), and a
/// stream of the wrong length is refused before anything is absorbed.
#[test]
fn r3_streamed_blocks_prove_and_verify_and_another_block_at_a_stage_is_refused() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
    let st = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
    let gen = |order: Vec<usize>| GenBlocks { all: fx.blocks.clone(), order, cur: None, loads: 0 };
    let mut segs = Vec::new();
    let mut bl = gen(vec![0, 1]);
    prove_token_run_with(&st, &mut bl, &fx.tables, &mut PipelineSource(&mut pipe), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .unwrap_or_else(|e| panic!("the streamed run did not prove: {e}"));
    assert_eq!(bl.loads, 2, "one load per block stage");
    verify_token_run_with(&st, &mut gen(vec![0, 1]), &fx.tables, &segs, R1_DEV_POLICY_R3).expect("the streamed run verifies with a streamed verifier");
    verify_token_run(&st, &fx.blocks, &fx.tables, &segs, R1_DEV_POLICY_R3).expect("and with a resident one");
    let e = verify_token_run_with(&st, &mut gen(vec![1, 0]), &fx.tables, &segs, R1_DEV_POLICY_R3).unwrap_err();
    assert!(e.contains("ruling CS-6 — block 0"), "{e}");
    eprintln!("TOKEN-IO-R3 STREAM | the verifier handed block 1 at stage 0 | refused: {e}");
    let e = verify_token_run_with(&st, &mut gen(vec![0]), &fx.tables, &segs, R1_DEV_POLICY_R3).unwrap_err();
    assert!(e.contains("1 blocks and 4 segments"), "{e}");
    // the honest prover refuses the swapped stream at stage 0
    let mut pipe2 = honest(&fx, &tp);
    let (roots2, owners2) = seal_endpoints(&ins, &outs, &pipe2.in_plane, &pipe2.out_plane, &fx.sh.hash_tag()).unwrap();
    let st2 = statement(&fx, roots2, SelectorVariant::PublicRow).unwrap();
    let e = prove_token_run_with(&st2, &mut gen(vec![1, 0]), &fx.tables, &mut PipelineSource(&mut pipe2), owners2, &mut |_, _| Ok(())).err().expect("the prover proved a swapped stream");
    assert!(e.contains("ruling CS-6 — block 0"), "{e}");
    eprintln!("TOKEN-IO-R3 STREAM | the prover handed block 1 at stage 0 | refused: {e}");
}

/// the R1 rung's verifier policy (its own derived figure, 93 bits)
const R1_DEV_POLICY_R3: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 93 };

// ------------------------------------------------------------------ 4. folds and the loader

/// **R3: the parallel folds are the serial folds**, entry for entry.
#[test]
fn r3_the_parallel_folds_equal_the_serial_folds() {
    let tables = generic_tables_v(5000, 384, 0x6631_6f6c);
    let mut tr = Transcript::new(b"token I/O R3: fold equality");
    let r = tr.challenge_fp2_vec(9);
    assert_eq!(tables.emb_fold(&r), tables.emb_fold_serial(&r), "the parallel embedding fold");
    let w = crate::mle::eq_table_msb(&tr.challenge_fp2_vec(13));
    assert_eq!(tables.head_fold(&w, 512), tables.head_fold_serial(&w, 512), "the parallel head fold");
    let y: Vec<i64> = (0..384).map(|i| (i as i64 * 37) % 255 - 127).collect();
    let serial: Vec<i64> = (0..tables.v).map(|j| tables.mult[j] * tables.head_row(j).iter().zip(y.iter()).map(|(a, b)| i64::from(*a) * b).sum::<i64>()).collect();
    assert_eq!(tables.logits(&y), serial, "the parallel logits");
}

/// R2's file format: `embedding_int16.bin` ([V, d] int16 LE) described by
/// `token_io.json` (`embedding_table` -> `sha256`), and `head_int8_perrow.bin`
/// ([V, d] int8) / `head_mult12.bin` ([V] int64 LE) described by
/// `head_manifest.json` (each file's `sha256`, and the `final_norm`
/// constants). Read in 16 MiB chunks with the SHA-256 streamed: no second
/// copy of a 1.05 GB table.
pub(super) struct TableFiles {
    pub emb_dir: PathBuf,
    pub head_dir: PathBuf,
}

/// the SHA-256 recorded under `key` (the first `"sha256": "<hex>"` after it)
fn json_sha_after(text: &str, key: &str) -> Result<String, String> {
    let at = text.find(key).ok_or_else(|| format!("manifest: no `{key}`"))?;
    let rest = &text[at..];
    let s = rest.find("\"sha256\"").ok_or_else(|| format!("manifest: no sha256 after `{key}`"))?;
    let q = rest[s + 8..].find('"').ok_or("manifest: malformed sha256")? + s + 9;
    let h = &rest[q..q + 64];
    if !h.bytes().all(|c| c.is_ascii_hexdigit()) {
        return Err(format!("manifest: `{key}`'s sha256 is not 64 hex digits"));
    }
    Ok(h.to_ascii_lowercase())
}

/// the integer recorded under `key` inside the `final_norm` object
fn json_int_in_final_norm(text: &str, key: &str) -> Result<i64, String> {
    let fnm = text.find("\"final_norm\"").ok_or("head manifest: no final_norm")?;
    let rest = &text[fnm..];
    let at = rest.find(&format!("\"{key}\"")).ok_or_else(|| format!("head manifest: final_norm has no `{key}`"))? + key.len() + 2;
    let colon = rest[at..].find(':').ok_or("head manifest: malformed")? + at + 1;
    let num: String = rest[colon..].trim_start().chars().take_while(|c| c.is_ascii_digit() || *c == '-').collect();
    num.parse::<i64>().map_err(|_| format!("head manifest: final_norm.{key} is not an integer"))
}

/// read `path` (exactly `len` bytes) in chunks, hashing as it goes
fn read_streamed(path: &Path, len: usize, want: &str, mut each: impl FnMut(&[u8])) -> Result<(), String> {
    use sha2::Digest as _;
    use std::io::Read;
    let meta = std::fs::metadata(path).map_err(|e| format!("{}: {e}", path.display()))?;
    if meta.len() != len as u64 {
        return Err(format!("{}: {} bytes, the table is {len}", path.display(), meta.len()));
    }
    let mut f = std::fs::File::open(path).map_err(|e| format!("{}: {e}", path.display()))?;
    let mut h = sha2::Sha256::new();
    let mut buf = vec![0u8; 16 << 20];
    let mut left = len;
    while left > 0 {
        let n = left.min(buf.len());
        f.read_exact(&mut buf[..n]).map_err(|e| format!("{}: {e}", path.display()))?;
        h.update(&buf[..n]);
        each(&buf[..n]);
        left -= n;
    }
    let got: [u8; 32] = h.finalize().into();
    if hex(&got) != want {
        return Err(format!("{}: not the recorded table (sha256 {} != {want})", path.display(), hex(&got)));
    }
    Ok(())
}

/// **THE TRAINED TABLES' LOADER** (R2's format; R3's trained run)
pub(super) fn load_token_tables(files: &TableFiles, v: usize, d: usize) -> Result<(TokenTables, String), String> {
    let tio = std::fs::read_to_string(files.emb_dir.join("token_io.json")).map_err(|e| format!("token_io.json: {e}"))?;
    let hm = std::fs::read_to_string(files.head_dir.join("head_manifest.json")).map_err(|e| format!("head_manifest.json: {e}"))?;
    let mut emb: Vec<i16> = Vec::with_capacity(v * d);
    read_streamed(&files.emb_dir.join("embedding_int16.bin"), 2 * v * d, &json_sha_after(&tio, "\"embedding_table\"")?, |b| emb.extend(b.chunks_exact(2).map(|c| i16::from_le_bytes([c[0], c[1]]))))?;
    let mut head: Vec<i8> = Vec::with_capacity(v * d);
    read_streamed(&files.head_dir.join("head_int8_perrow.bin"), v * d, &json_sha_after(&hm, "\"head_int8_perrow.bin\"")?, |b| head.extend(b.iter().map(|x| *x as i8)))?;
    let mut mult: Vec<i64> = Vec::with_capacity(v);
    read_streamed(&files.head_dir.join("head_mult12.bin"), 8 * v, &json_sha_after(&hm, "\"head_mult12.bin\"")?, |b| mult.extend(b.chunks_exact(8).map(|c| i64::from_le_bytes(c.try_into().unwrap()))))?;
    Ok((TokenTables::new(v, d, emb, head, mult)?, hm))
}

/// write a table set in R2's format (the loader test, and nothing else)
fn write_token_tables(dir: &Path, t: &TokenTables, norm: FinalNorm) {
    std::fs::create_dir_all(dir).unwrap();
    let emb: Vec<u8> = t.emb.iter().flat_map(|w| w.to_le_bytes()).collect();
    let head: Vec<u8> = t.head.iter().map(|w| *w as u8).collect();
    let mult: Vec<u8> = t.mult.iter().flat_map(|w| w.to_le_bytes()).collect();
    std::fs::write(dir.join("embedding_int16.bin"), &emb).unwrap();
    std::fs::write(dir.join("head_int8_perrow.bin"), &head).unwrap();
    std::fs::write(dir.join("head_mult12.bin"), &mult).unwrap();
    std::fs::write(dir.join("token_io.json"), format!("{{\"embedding_table\": {{\"dtype\": \"int16\", \"file\": \"embedding_int16.bin\", \"sha256\": \"{}\", \"shape\": [{}, {}]}}}}\n", hex(&sha256(&emb)), t.v, t.d)).unwrap();
    std::fs::write(
        dir.join("head_manifest.json"),
        format!(
            "{{\"head_int8_perrow.bin\": {{\"sha256\": \"{}\"}}, \"head_mult12.bin\": {{\"sha256\": \"{}\"}}, \"final_norm\": {{\"g0\": {}, \"tn\": {}, \"ceps\": {}, \"cn_calibrated\": {}}}}}\n",
            hex(&sha256(&head)),
            hex(&sha256(&mult)),
            norm.g0,
            norm.tn,
            norm.ceps,
            norm.cn
        ),
    )
    .unwrap();
}

/// the final norm a head manifest records (`cn_calibrated`)
fn manifest_norm(hm: &str) -> Result<FinalNorm, String> {
    Ok(FinalNorm { g0: json_int_in_final_norm(hm, "g0")?, cn: json_int_in_final_norm(hm, "cn_calibrated")?, tn: json_int_in_final_norm(hm, "tn")? as u32, ceps: json_int_in_final_norm(hm, "ceps")? })
}

/// **R3: the table loader** round-trips a written set (R2's format) and
/// refuses a table whose bytes are not the recorded ones, or of another size.
#[test]
fn r3_the_table_loader_round_trips_and_refuses_a_table_that_is_not_the_recorded_one() {
    let t = generic_tables(384, 0x6c6f_6164);
    let dir = std::env::temp_dir().join(format!("tio-r3-loader-{}", std::process::id()));
    write_token_tables(&dir, &t, norm());
    let files = TableFiles { emb_dir: dir.clone(), head_dir: dir.clone() };
    let (back, hm) = load_token_tables(&files, t.v, t.d).expect("the written set loads");
    assert_eq!(back, t, "the round trip");
    assert_eq!(manifest_norm(&hm).unwrap(), norm(), "the final norm the manifest records");
    let mut head = std::fs::read(dir.join("head_int8_perrow.bin")).unwrap();
    head[1234] ^= 1;
    std::fs::write(dir.join("head_int8_perrow.bin"), &head).unwrap();
    let e = load_token_tables(&files, t.v, t.d).unwrap_err();
    assert!(e.contains("not the recorded table"), "{e}");
    let e = load_token_tables(&files, t.v + 1, t.d).unwrap_err();
    assert!(e.contains("bytes, the table is"), "{e}");
    let _ = std::fs::remove_dir_all(&dir);
}

// ------------------------------------------------------------------ 5. the R3 run

/// the public side of the R3 run: the export's 32 layers' records and block
/// digests (each block loaded, digested and DROPPED: the digest pass), the
/// trained-model statement under the R3 profile
struct R3Pub {
    ex: TrainedExport,
    c: Constants,
    sh: Shape,
    layers: Vec<u32>,
    digests: Vec<Digest>,
    model: TrainedModelStatement,
    digest_s: f64,
}

fn env_path(k: &str, default: &str) -> PathBuf {
    PathBuf::from(std::env::var(k).unwrap_or_else(|_| default.to_string()))
}

fn r3_public() -> R3Pub {
    let t0 = std::time::Instant::now();
    let export = env_path("TOKEN_IO_R3_EXPORT", "/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32");
    let ex = TrainedExport::load(&export).unwrap_or_else(|e| panic!("the export: {e}"));
    let layers = ex.layers.clone();
    assert_eq!(layers.len(), 32, "the Llama-3-8B export has 32 layers");
    let c = ex.run_constants(&layers).unwrap();
    let sh = ex.shape_for(&c).unwrap();
    let mut digests = Vec::with_capacity(32);
    let mut records = Vec::with_capacity(32);
    for &k in &layers {
        let t = ex.load_layer(&sh, &c, k, false).unwrap_or_else(|e| panic!("layer {k}: {e}"));
        digests.push(t.record.block_digest);
        records.push(t.record);
    }
    let prov = Provenance {
        label: format!("export:{}", ex.variant),
        residual_unit: ex.residual_unit,
        quantizer_sha256: ex.tool_sha256,
        calibration_set_sha256: ex.calibration_set_sha256,
        export_profile_sha256: ex.profile_sha256,
        calibration_tool_sha256: ex.tool_sha256,
        rope_theta: c.rope_theta,
    };
    let cal = IntegerCalibration::as_the_code_proves(&sh, &prov);
    let model = TrainedModelStatement::new(&sh, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32, ex.source.clone(), cal, records).unwrap_or_else(|e| panic!("the R3 trained-model statement: {e}"));
    R3Pub { ex, c, sh, layers, digests, model, digest_s: t0.elapsed().as_secs_f64() }
}

/// **THE R3 BLOCK SOURCE**: block `k` reloaded from the export at its stage
/// (`reload_block`, the native loader's proving-pass reload) and refused
/// unless its digest is the digest pass's; ONE resident at a time.
struct ExportBlocks<'a> {
    p: &'a R3Pub,
    cur: Option<(usize, std::sync::Arc<BlockPublic>)>,
    load_s: f64,
}

impl TokenBlocks for ExportBlocks<'_> {
    fn count(&self) -> usize {
        self.p.layers.len()
    }
    fn block(&mut self, k: usize) -> Result<BlockRef<'_>, String> {
        if let Some((j, a)) = &self.cur {
            if *j == k {
                return Ok(BlockRef::Shared(a.clone()));
            }
        }
        self.cur = None;
        let t = std::time::Instant::now();
        let layer = *self.p.layers.get(k).ok_or_else(|| format!("R3: no block {k}"))?;
        let blk = self.p.ex.reload_block(&self.p.sh, &self.p.c, layer, false)?;
        if blk.digest() != self.p.digests[k] {
            return Err(format!("R3: layer {layer}'s reloaded public statement is not the digest pass's"));
        }
        let a = std::sync::Arc::new(blk);
        self.cur = Some((k, a.clone()));
        self.load_s += t.elapsed().as_secs_f64();
        Ok(BlockRef::Shared(a))
    }
}

fn seq_tokens(ex: &TrainedExport, seq: &str) -> Vec<u64> {
    let m = std::fs::read_to_string(ex.dir.join(format!("seq_{seq}")).join("manifest.json")).unwrap();
    let at = m.find("\"token_ids\"").expect("token_ids") + "\"token_ids\"".len();
    let open = at + m[at..].find('[').unwrap() + 1;
    let close = open + m[open..].find(']').unwrap();
    m[open..close].split(',').map(|x| x.trim().parse::<u64>().expect("a token id")).collect()
}

fn pad_plane(sh: &Shape, x: &[i16]) -> Vec<i16> {
    let mut p = vec![0i16; sh.t_pad * sh.d_pad];
    for t in 0..sh.tokens {
        p[t * sh.d_pad..t * sh.d_pad + sh.width].copy_from_slice(&x[t * sh.width..(t + 1) * sh.width]);
    }
    p
}

fn unpad(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect()
}

/// the GENERIC table's planted rows: each prompt id's row is the export's
/// x_in_L00 row at its positions (refused if one id would get two rows).
/// Written to the run directory as part of the generic table's PUBLIC
/// definition (this generic fixture therefore does not hide the prompt ids).
fn planted_rows(tokens: &[u64], x_in0: &[i16], d: usize) -> Vec<(u64, Vec<i16>)> {
    let mut out: Vec<(u64, Vec<i16>)> = Vec::new();
    for (t, id) in tokens.iter().enumerate() {
        let row = x_in0[t * d..(t + 1) * d].to_vec();
        match out.iter().find(|(i, _)| i == id) {
            Some((_, r)) => assert_eq!(r, &row, "the export's x_in_L00 gives token {id} two different rows"),
            None => out.push((*id, row)),
        }
    }
    out
}

fn write_planted(dir: &Path, rows: &[(u64, Vec<i16>)]) {
    let mut b = Vec::new();
    for (id, r) in rows {
        b.extend_from_slice(&id.to_le_bytes());
        for w in r {
            b.extend_from_slice(&w.to_le_bytes());
        }
    }
    std::fs::write(dir.join("generic_planted_rows.bin"), b).unwrap();
}

fn read_planted(dir: &Path, d: usize) -> Vec<(u64, Vec<i16>)> {
    let b = std::fs::read(dir.join("generic_planted_rows.bin")).expect("generic_planted_rows.bin");
    b.chunks_exact(8 + 2 * d).map(|c| (u64::from_le_bytes(c[..8].try_into().unwrap()), c[8..].chunks_exact(2).map(|x| i16::from_le_bytes([x[0], x[1]])).collect())).collect()
}

fn plant(t: &mut TokenTables, rows: &[(u64, Vec<i16>)]) {
    for (id, r) in rows {
        let at = *id as usize * t.d;
        t.emb[at..at + t.d].copy_from_slice(r);
    }
}

/// the run's tables and final norm: the calibration lane's trained set when
/// `TOKEN_IO_R3_EMB` / `TOKEN_IO_R3_HEAD` name it, the generic set otherwise
fn r3_tables(planted: Option<&[(u64, Vec<i16>)]>) -> (TokenTables, FinalNorm, String) {
    match (std::env::var("TOKEN_IO_R3_EMB"), std::env::var("TOKEN_IO_R3_HEAD")) {
        (Ok(e), Ok(h)) => {
            let (t, hm) = load_token_tables(&TableFiles { emb_dir: e.into(), head_dir: h.into() }, 128_256, 4096).unwrap_or_else(|e| panic!("the trained R3 tables: {e}"));
            (t, manifest_norm(&hm).expect("the head manifest's final norm"), "trained".into())
        }
        _ => {
            let mut t = hashed_tables(128_256, 4096);
            plant(&mut t, planted.expect("the generic table's planted rows"));
            (t, R3_NORM_GENERIC, "generic".into())
        }
    }
}

/// the R3 witness source: stage IN and OUT from the pipeline; block `k`'s
/// witness built at its stage from the previous boundary and checked bit for
/// bit against the export's x_out_Lk (the native parity) before its segment
/// exists; boundary `k + 1` sealed from the export's x_out_Lk
struct R3Source<'a> {
    p: &'a R3Pub,
    seq: String,
    ids: Ids,
    stage_in: Option<(StageInWitness, Vec<i16>)>,
    stage_out: Option<StageOutWitness>,
    x: Vec<i16>,
    witness_s: f64,
    parity: usize,
}

impl TokenRunSource for R3Source<'_> {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        self.stage_in.take().ok_or_else(|| "R3: stage IN asked twice".to_string())
    }
    fn witness(&mut self, k: usize, blk: &BlockPublic) -> Result<super::super::witness::Witness, String> {
        let t0 = std::time::Instant::now();
        let sh = &self.p.sh;
        let w = super::super::witness::build_shaped(sh, blk.attention(), blk.feed_forward(), &self.x)?;
        let out: Vec<i16> = w.planes[self.ids.at(A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| "R3: a block output outside int16".to_string())).collect::<Result<_, _>>()?;
        let next = unpad(sh, &out);
        if next != self.p.ex.load_seq(sh, &self.seq, self.p.layers[k])?.1 {
            return Err(format!("R3: block {k}'s native output is not the export's x_out_L{:02} (parity)", self.p.layers[k]));
        }
        self.parity += 1;
        self.x = next;
        self.witness_s += t0.elapsed().as_secs_f64();
        Ok(w)
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(pad_plane(&self.p.sh, &self.p.ex.load_seq(&self.p.sh, &self.seq, self.p.layers[k])?.1))
    }
    fn stage_out(&mut self) -> Result<StageOutWitness, String> {
        self.stage_out.take().ok_or_else(|| "R3: stage OUT asked twice".to_string())
    }
}

/// the reference next token, independent of the stage code (R0's integer
/// semantics, i128) on the export's x_out_L31 row T - 1
fn reference_next_token_r3(tp: &TokenProfile, tables: &TokenTables, x_last: &[i16]) -> (usize, i128, i128) {
    use rayon::prelude::*;
    let x: Vec<i128> = x_last.iter().map(|v| i128::from(*v)).collect();
    let nm = tp.norm;
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
    let l: Vec<i128> = (0..tp.v).into_par_iter().map(|j| i128::from(tables.mult[j]) * (0..tp.d).map(|i| i128::from(tables.head[j * tp.d + i]) * y[i]).sum::<i128>()).collect();
    let mut best = 0usize;
    for j in 1..l.len() {
        if l[j] > l[best] {
            best = j;
        }
    }
    let second = (0..l.len()).filter(|j| *j != best).map(|j| l[j]).max().unwrap();
    (best, l[best] - second, d)
}

fn r3_out() -> PathBuf {
    PathBuf::from(std::env::var("TOKEN_IO_R3_OUT").expect("set TOKEN_IO_R3_OUT to the evidence directory"))
}

fn r3_seq() -> String {
    std::env::var("TOKEN_IO_R3_SEQ").unwrap_or_else(|_| "ho00".into())
}

fn r3_context(seq: &str, mode: &str) -> Digest {
    let mut b = format!("token I/O R3: Llama-3-8B T32 public-row run context, {mode} tables, sequence ").into_bytes();
    b.extend_from_slice(seq.as_bytes());
    *blake3::hash(&b).as_bytes()
}

/// the verifier's policy for R3: the D27 MVP level, 95 whole bits
const R3_POLICY: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 95 };

/// **THE R3 RUN: PROVE TO A DIRECTORY** (run alone, guarded; `#[ignore]`).
/// The trained 8B export's 32 blocks streamed one at a time; the generic
/// tables (prompt rows planted from the export's x_in_L00) or the trained
/// tables; the endpoints sealed from the export's words (B_in = the embedded
/// prompt = x_in_L00; the next token from x_out_L31 row 31), every block's
/// witness checked against the export's x_out_Lk in the proving pass.
#[test]
#[ignore]
fn token_io_r3_prove_to_dir() {
    let t_all = std::time::Instant::now();
    let seq = r3_seq();
    let p = r3_public();
    let sh = &p.sh;
    let tokens = seq_tokens(&p.ex, &seq);
    let x_in0 = p.ex.load_seq(sh, &seq, p.layers[0]).unwrap().0;
    let rows = planted_rows(&tokens, &x_in0, sh.width);
    let t = std::time::Instant::now();
    let (tables, nm, mode) = r3_tables(Some(rows.as_slice()));
    let tables_s = t.elapsed().as_secs_f64();
    let tp = TokenProfile::new(sh, &tables, R3_BOS, nm, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    // the endpoints, from the export's own words (no sealing pass)
    let (wit_in, b_in, in_plane) = stage_in::honest_inputs(&tp, &tables, &tokens).unwrap_or_else(|e| panic!("R3 stage IN refused: {e}"));
    assert_eq!(unpad(sh, &b_in), x_in0, "B_in (the embedded prompt) is not the export's x_in_L00");
    let x_last_all = p.ex.load_seq(sh, &seq, p.layers[31]).unwrap().1;
    let x_last: Vec<i64> = x_last_all[(tp.tokens - 1) * tp.d..tp.tokens * tp.d].iter().map(|v| i64::from(*v)).collect();
    let mut row = vec![0i64; tp.d_pad];
    row[..tp.d].copy_from_slice(&x_last);
    let ov = stage_out::out_values(&tp, &tables, &row, true).unwrap_or_else(|e| panic!("R3 stage OUT refused: {e}"));
    let wout = stage_out::witness_from_values(&tp, &ov).unwrap();
    let (want, margin, dref) = reference_next_token_r3(&tp, &tables, &x_last_all[(tp.tokens - 1) * tp.d..tp.tokens * tp.d]);
    assert_eq!(ov.tok, want, "the stage code's greedy token is not the reference");
    let out_plane = stage_out::endpoint_plane(&tp, ov.tok as u64);
    let ctx = r3_context(&seq, &mode);
    let (ins, outs) = endpoint_specs(sh, ctx, &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &in_plane, &out_plane, &sh.hash_tag()).unwrap();
    let st = TokenRunStatement::new(RunShape::new(sh.clone(), 32, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32).unwrap(), ctx, p.digests.clone(), &p.model, &tables, R3_BOS, nm, SelectorVariant::PublicRow, Tier::R1_MVP, roots).unwrap();
    let dir = r3_out().join(format!("{mode}-{seq}"));
    std::fs::create_dir_all(&dir).unwrap();
    if mode == "generic" {
        write_planted(&dir, &rows);
    }
    let mut src = R3Source { p: &p, seq: seq.clone(), ids: Ids::new(sh).unwrap(), stage_in: Some((wit_in, b_in)), stage_out: Some(wout), x: x_in0.clone(), witness_s: 0.0, parity: 0 };
    let mut blocks = ExportBlocks { p: &p, cur: None, load_s: 0.0 };
    let t = std::time::Instant::now();
    let mut lens = Vec::new();
    let proved = prove_token_run_with(&st, &mut blocks, &tables, &mut src, owners, &mut |k, b| {
        lens.push(b.len());
        std::fs::write(dir.join(format!("segment_{k:03}.bin")), &b).map_err(|e| e.to_string())
    });
    // review R2-5: what the sink wrote is unpublished until the prover
    // returns Ok; a refused run leaves no directory a verifier could read
    let (stats, hand) = match proved {
        Ok(x) => x,
        Err(e) => {
            let _ = std::fs::remove_dir_all(&dir);
            panic!("the R3 run did not prove: {e}")
        }
    };
    let prove_s = t.elapsed().as_secs_f64();
    assert_eq!(src.parity, 32, "parity was checked at every layer");
    assert_eq!(lens, st.segment_lens().unwrap(), "the segment lengths are not the counted ones");
    owner_check_input(&st, &hand.input, &tokens).expect("the input owner's check");
    let tok = owner_check_output(&st, &hand.output).expect("the output owner's check");
    assert_eq!(tok, want, "the decommitted id is not the reference next token");
    let w = st.whole_run();
    let stmt = format!(
        "profile {}\nL 32\nseq {seq}\ntables {mode}\nfinal_norm g0 {} cn {} tn {} ceps {}\ncontext {}\ninput_root {}\noutput_root {}\ntrained_statement_identity {}\nsegment_bytes {:?}\ntotal_bytes {}\nprove_seconds {prove_s:.3}\nstage_seconds {:?}\nof_which_witness_seconds {:.3}\nof_which_block_load_seconds {:.3}\nvmhwm_mib {:?}\ndigest_pass_seconds {:.3}\ntables_seconds {tables_s:.3}\nwhole_run openings {} column_log2 {:.3} logup_log2 {:.3} total_log2 {:.3} floor_bits {}\nparameter_line {}\n",
        RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32,
        nm.g0,
        nm.cn,
        nm.tn,
        nm.ceps,
        hex(&ctx),
        hex(&roots.0),
        hex(&roots.1),
        hex(&p.model.identity()),
        stats.segment_bytes,
        lens.iter().sum::<usize>(),
        stats.prove_s.iter().map(|s| (s * 1000.0).round() / 1000.0).collect::<Vec<_>>(),
        src.witness_s,
        blocks.load_s,
        stats.hwm_mib.iter().map(|m| m.round()).collect::<Vec<_>>(),
        p.digest_s,
        w.openings,
        w.column_log2,
        w.logup_log2,
        w.total_log2,
        w.floor_bits,
        st.parameter_line().unwrap()
    );
    std::fs::write(dir.join("statement.txt"), stmt).unwrap();
    let cross = format!(
        "{{\"seq\": \"{seq}\", \"tables\": \"{mode}\", \"note\": \"public calibration data and public tables only; the decommitted token is the OWNER's output\", \"decommitted_next_token\": {tok}, \"reference_top2_margin\": {margin}, \"reference_D\": {dref}, \"tokens\": {:?}, \"x_last_from\": \"export seq_{seq}/x_out_L31.bin row {}\", \"g0\": {}, \"cn\": {}, \"tn\": {}, \"ceps\": {}, \"V\": {}, \"d\": {}, \"hash_seeds\": [{}, {}, {}]}}\n",
        tokens,
        tp.tokens - 1,
        nm.g0,
        nm.cn,
        nm.tn,
        nm.ceps,
        tp.v,
        tp.d,
        HASH_SEED_EMB,
        HASH_SEED_HEAD,
        HASH_SEED_MULT
    );
    std::fs::write(dir.join("crosscheck.json"), cross).unwrap();
    eprintln!(
        "TOKEN-IO-R3 PROVED {mode}-{seq} -> {}: next token {tok} (reference {want}, top-2 logit margin {margin}), {} B in {} segments, prove {prove_s:.1} s (witness {:.1} s, block loads {:.1} s), digest pass {:.1} s, tables {tables_s:.1} s, peak RSS {:.0} MiB, whole run 2^{:.2} (floor {} bits), parity at 32 layers, total {:.1} s [MEASURED, shared box, n=1]",
        dir.display(),
        lens.iter().sum::<usize>(),
        lens.len(),
        src.witness_s,
        blocks.load_s,
        p.digest_s,
        stats.hwm_mib.iter().cloned().fold(0.0, f64::max),
        w.total_log2,
        w.floor_bits,
        t_all.elapsed().as_secs_f64()
    );
}

/// **THE R3 RUN: VERIFY IN A FRESH PROCESS** (run alone; `#[ignore]`). Every
/// public input rebuilt from the export's public files (no seq_* data), the
/// tables from their public definition (the generic seeds and the planted
/// rows in the run directory, or the trained files), the roots and context
/// from `statement.txt`, the blocks streamed; the verifier's policy is the
/// D27 MVP level (95 bits); a one-bit change is refused.
#[test]
#[ignore]
fn token_io_r3_verify_from_dir() {
    let seq = r3_seq();
    let p = r3_public();
    let mode = if std::env::var("TOKEN_IO_R3_EMB").is_ok() && std::env::var("TOKEN_IO_R3_HEAD").is_ok() { "trained" } else { "generic" };
    let dir = r3_out().join(format!("{mode}-{seq}"));
    let planted = if mode == "generic" { Some(read_planted(&dir, p.sh.width)) } else { None };
    let t = std::time::Instant::now();
    let (tables, nm, _) = r3_tables(planted.as_deref());
    let tables_s = t.elapsed().as_secs_f64();
    let stmt = std::fs::read_to_string(dir.join("statement.txt")).expect("statement.txt");
    let field = |k: &str| stmt.lines().find_map(|l| l.strip_prefix(&format!("{k} "))).unwrap_or_else(|| panic!("{k} missing")).to_string();
    let unhex = |s: String| -> Digest {
        let mut d = [0u8; 32];
        for i in 0..32 {
            d[i] = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).unwrap();
        }
        d
    };
    let ctx = unhex(field("context"));
    assert_eq!(ctx, r3_context(&seq, mode));
    let roots = (unhex(field("input_root")), unhex(field("output_root")));
    let st = TokenRunStatement::new(RunShape::new(p.sh.clone(), 32, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32).unwrap(), ctx, p.digests.clone(), &p.model, &tables, R3_BOS, nm, SelectorVariant::PublicRow, Tier::R1_MVP, roots).unwrap();
    assert_eq!(field("parameter_line"), st.parameter_line().unwrap(), "the saved run is another statement");
    assert_eq!(field("trained_statement_identity"), hex(&p.model.identity()));
    let segs: Vec<Vec<u8>> = (0..34).map(|k| std::fs::read(dir.join(format!("segment_{k:03}.bin"))).unwrap()).collect();
    let mut blocks = ExportBlocks { p: &p, cur: None, load_s: 0.0 };
    let t0 = std::time::Instant::now();
    verify_token_run_with(&st, &mut blocks, &tables, &segs, R3_POLICY).unwrap_or_else(|e| panic!("the saved R3 run does not verify in a fresh process: {e}"));
    let vs = t0.elapsed().as_secs_f64();
    // a one-bit change (in stage IN's segment: refused before any block is loaded)
    let mut bad = segs.clone();
    let at = bad[0].len() / 2;
    bad[0][at] ^= 1;
    assert!(verify_token_run_with(&st, &mut ExportBlocks { p: &p, cur: None, load_s: 0.0 }, &tables, &bad, R3_POLICY).is_err(), "a one-bit change verified");
    eprintln!(
        "TOKEN-IO-R3 FRESH-PROCESS VERIFY {mode}-{seq}: accepted from {} ({} B) in {vs:.1} s (of which block loads {:.1} s) under a {}-bit policy (digest pass {:.1} s, tables {tables_s:.1} s); a one-bit change refused [MEASURED, shared box, n=1]",
        dir.display(),
        segs.iter().map(|s| s.len()).sum::<usize>(),
        blocks.load_s,
        R3_POLICY.min_whole_run_bits,
        p.digest_s
    );
}

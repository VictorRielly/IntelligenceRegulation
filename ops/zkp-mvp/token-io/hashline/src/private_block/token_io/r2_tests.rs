//! **TOKEN I/O R2 (TinyLlama-1.1B, T32, the 22 trained blocks): THE
//! ACCEPTANCE TESTS.** TEST CODE ONLY; no privacy claim (the G-1..G-7 gates
//! are owed; no privacy figure is quoted).
//!
//! 1. the counted layout at TinyLlama equals `counts/r2_counts.json` (written
//!    before the multi-row construction): stage IN A 17 / H 28 / M 12, stage
//!    OUT A 182 / H 110 / M 26, 282,624 byte lookups, window 53, 7 limbs;
//! 2. the MULTI-ROW planes (review condition (a)) on a cheap fixture: the
//!    trained-calibration rung's blocks with `V = 5,000` (`V_pad = 2^13`, two
//!    rows per vocabulary plane): an honest run proves and verifies, and the
//!    controls that touch the second row are refused where predicted;
//! 3. D20 at the calibrated `Cn = 5,664` (review condition (b)): the final
//!    norm's int8 overflow is a live, input-dependent refusal before any
//!    commitment, naming no position or value;
//! 4. the R2 run itself (`#[ignore]`d, run alone, guarded): the export's 22
//!    blocks, the embedding table, the per-row head; prove to a directory,
//!    then verify in a FRESH process from the saved bytes.

use super::run::*;
use super::stage_in::{self, StageInWitness};
use super::stage_out::{self, OutValues, StageOutWitness};
use super::tests::*;
use super::*;
use super::super::layout::{Ids, A_X2};
use super::super::run::{RunShape, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32};
use super::super::trained_block::{sha256, TrainedExport};
use super::super::trained_statement::{IntegerCalibration, Provenance, TrainedModelStatement};
use super::super::BlockPublic;

fn tinyllama() -> Shape {
    Shape::tinyllama_trained(32, &r2_calibration(), R2_F_E).expect("the trained TinyLlama T32 shape")
}

// ------------------------------------------------------------------ 1. the counted layout

/// **R2 TEST 1, written before the multi-row construction (PROGRESS 22:44).**
/// The code's counted layout at TinyLlama T32 equals `counts/r2_counts.py`'s
/// figures (`counts/r2_counts.json`: mode (i), public row, per-row head,
/// stages at 2^12).
#[test]
fn r2_the_counted_layout_is_the_counters() {
    let sh = tinyllama();
    let tables = generic_tables_v(32_000, 2048, 0x7232_6c61);
    let tp = TokenProfile::new(&sh, &tables, 1, R2_NORM, SelectorVariant::PublicRow, Tier::R1_MVP).expect("the R2 token profile");
    assert_eq!((tp.window_bits, tp.limbs, tp.v_pad, tp.log_v, tp.d_pad, tp.t_pad), (53, 7, 32_768, 15, 2048, 32), "the R2 keyed window and paddings");
    assert_eq!((tp.ti_log(), tp.voc_log(), tp.lo_log(), tp.do_log(), tp.vo_log(), tp.tab_log()), (12, 15, 12, 12, 15, 12), "the stage domains");
    let li = stage_in::layout(&sh, &tp);
    assert_eq!((li.a_rows, li.h_rows, li.m_rows()), (17, 28, 12), "stage IN rows");
    assert_eq!(li.elems(), 184_320, "stage IN committed elements");
    assert_eq!((li.a_sites_total(), li.h_sites_total(), li.sched.slots.len()), (3, 3, 4), "stage IN sites and slots");
    assert_eq!((li.a_log.clone(), li.h_log.clone()), (vec![12, 15], vec![12, 15, 12]), "stage IN plane logs (m and h_tab span eight rows)");
    let lo = stage_out::layout(&sh, &tp);
    assert_eq!((lo.a_rows, lo.h_rows, lo.m_rows()), (182, 110, 26), "stage OUT rows");
    assert_eq!(lo.elems(), 1_196_032, "stage OUT committed elements");
    assert_eq!((lo.a_sites_total(), lo.h_sites_total(), lo.sched.slots.len()), (49, 13, 11), "stage OUT sites and slots");
    assert_eq!(stage_out::hv(tp.limbs), 4, "four VZC helpers");
    let (u8n, tab) = stage_out::logup_size(&lo, &tp);
    assert_eq!((u8n, tab), (282_624, 256), "stage OUT byte lookups");
    let (ins, outs) = endpoint_specs(&sh, *blake3::hash(b"r2 counted").as_bytes(), &tp).unwrap();
    assert_eq!((ins.len(), ins.data_rows(), ins.commitment_rows()), (256, 1, 6), "the input token endpoint");
    assert_eq!((outs.len(), outs.data_rows(), outs.commitment_rows()), (256, 1, 6), "the output token endpoint");
    // the derived whole-run figure of the 22-block run [COUNTED]
    let w = whole_run_of(&sh, 22, &tp);
    assert!(w.floor_bits >= 95, "the R2 run's derived whole-run figure is below the MVP's 95 bits: {w:?}");
    eprintln!(
        "TOKEN-IO-R2 COUNTS stage IN A {} H {} M {} elems {} | stage OUT A {} H {} M {} elems {} u8 {} | window {} limbs {} | whole run (L = 22): openings {} column 2^{:.2} logup 2^{:.2} total 2^{:.2} floor {} bits [COUNTED]",
        li.a_rows,
        li.h_rows,
        li.m_rows(),
        li.elems(),
        lo.a_rows,
        lo.h_rows,
        lo.m_rows(),
        lo.elems(),
        u8n,
        tp.window_bits,
        tp.limbs,
        w.openings,
        w.column_log2,
        w.logup_log2,
        w.total_log2,
        w.floor_bits
    );
}

// ------------------------------------------------------------------ 2. the multi-row planes

/// the multi-row fixture: the R1 rung's blocks, a generic model of 5,000
/// tokens (`V_pad = 2^13`: two rows per vocabulary plane, entries 4,096..
/// 8,191 in the second), a prompt with ids drawn over the whole vocabulary
fn fx_multirow() -> Fx {
    let sh = rung();
    let blocks = blocks(&sh, 2);
    let model = model(&sh, &blocks);
    let mut s = 0x6d72_6f77u64;
    let mut tokens = vec![1u64];
    while tokens.len() < sh.tokens {
        tokens.push(lcg(&mut s) % 5000);
    }
    assert!(tokens.iter().any(|t| *t >= 4096), "the multi-row prompt never reads the second vocabulary row");
    Fx { name: "multirow-v5000", tables: generic_tables_v(5000, sh.width, 0x6d72_7462), sh, blocks, model, tokens, norm: norm(), bos: 1 }
}

/// **R2 MULTI-ROW, FAILING FIRST (the R1 door refuses `V_pad` above one
/// stage row).** An honest run with two-row vocabulary planes proves,
/// verifies, and both owners check; the decommitted id is the reference.
#[test]
fn r2_multirow_an_honest_run_proves_verifies_and_both_owners_check() {
    let fx = fx_multirow();
    let tp = profile(&fx);
    assert_eq!((tp.v_pad, tp.voc_log(), tp.vo_log(), tp.limbs), (8192, 13, 13, 7));
    let li = stage_in::layout(&fx.sh, &tp);
    let lo = stage_out::layout(&fx.sh, &tp);
    assert_eq!(li.a_log, vec![12, 13], "m spans two rows");
    assert_eq!(lo.a_log[stage_out::A_E], 13, "e spans two rows");
    let mut pipe = honest(&fx, &tp);
    let want = pipe.out_values.tok;
    let p = prove_pipe(&fx, &tp, &mut pipe).unwrap_or_else(|e| panic!("the honest multi-row run did not prove: {e}"));
    verify_token_run(&p.st, &fx.blocks, &fx.tables, &p.segs, VerifierPolicy { min_whole_run_bits: 93 }).unwrap_or_else(|e| panic!("the honest multi-row run did not verify: {e}"));
    assert_eq!(p.segs.iter().map(|s| s.len()).collect::<Vec<_>>(), p.st.segment_lens().unwrap(), "the segment lengths are not the counted ones");
    owner_checks(&fx, &p, &tp, want);
    eprintln!(
        "TOKEN-IO-R2 MULTIROW HONEST: V 5000 (V_pad 8192, two rows per vocabulary plane), next token {want}, stage IN A {} H {} / stage OUT A {} H {} rows, prove {:.2} s, receipt {} B [MEASURED, shared box, n=1, test build]",
        li.a_rows,
        li.h_rows,
        lo.a_rows,
        lo.h_rows,
        p.secs,
        p.segs.iter().map(|s| s.len()).sum::<usize>()
    );
}

/// **R2 MULTI-ROW CONTROLS, FAILING FIRST** (the R2 rows of DESIGN 6.1's
/// table that touch the new planes): each is the R1 control of the same
/// number moved onto the SECOND row of a two-row plane, proved by the
/// cheating prover and refused where the R1 control is.
#[test]
fn r2_multirow_controls_are_refused_where_predicted() {
    let fx = fx_multirow();
    let tp = profile(&fx);
    let base = honest(&fx, &tp);
    let l = base.out_values.logits.clone();
    let j = base.out_values.tok;
    let max = l[j];
    let ep = |id: u64| stage_out::endpoint_plane(&tp, id);
    let row2 = 1usize << tp.tier.stage_log_n;
    // the best non-maximal entry of the second row
    let j2 = (row2..tp.v).filter(|i| *i != j && l[*i] < max).max_by_key(|i| (l[*i], std::cmp::Reverse(*i))).expect("a non-maximal second-row entry");
    // R2-1 (#1): e on a padded vocabulary entry in the second row (V + 3)
    {
        let mut p = honest(&fx, &tp);
        let pad = tp.v + 3;
        argmax_planes(&tp, &mut p.stage_out, &[(pad, Fp::ONE)], Fp::new(pad as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, pad), false);
        p.out_plane = ep(pad as u64);
        record("R2-1", "(#1, second row) e on the padded entry V + 3, tok = V + 3, M = max + 1", &[Site::OutSlot(stage_out::SO_VZC)], &forge(&fx, &tp, p));
    }
    // R2-2 (#2): e at a non-maximal second-row entry, M = max + 1, deltas in bytes
    {
        let mut p = honest(&fx, &tp);
        argmax_planes(&tp, &mut p.stage_out, &[(j2, Fp::ONE)], Fp::new(j2 as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, j2), false);
        p.out_plane = ep(j2 as u64);
        record("R2-2", "(#2, second row) non-maximal j >= 4096, M = max + 1, deltas in bytes (A6-only)", &[Site::OutSlot(stage_out::SO_RSEL)], &forge(&fx, &tp, p));
    }
    // R2-3 (#12b): the second-row token with M = l_j', the excess carried in
    // the 7th (top) limb, which is then not a byte
    {
        let mut p = honest(&fx, &tp);
        argmax_planes(&tp, &mut p.stage_out, &[(j2, Fp::ONE)], Fp::new(j2 as u64), Fp::from_i64(l[j2]), &|i| keyed(&tp, l[j2], l[i], i, j2), true);
        p.out_plane = ep(j2 as u64);
        record("R2-3", "(#12b, second row) non-maximal j >= 4096, M = l_j, delta field values in a non-byte 7th limb", &[Site::OutLogUp], &forge(&fx, &tp, p));
    }
    // R2-4 (#15): a delta limb that is not a byte at a second-row entry
    {
        let mut p = honest(&fx, &tp);
        let i = (row2..tp.v).find(|i| p.stage_out.planes[stage_out::A_LAM0 + 1][*i] != Fp::ZERO).expect("a second-row entry with a second limb");
        p.stage_out.planes[stage_out::A_LAM0][i] = p.stage_out.planes[stage_out::A_LAM0][i].add(Fp::new(256));
        p.stage_out.planes[stage_out::A_LAM0 + 1][i] = p.stage_out.planes[stage_out::A_LAM0 + 1][i].sub(Fp::ONE);
        record("R2-4", "(#15, second row) a delta limb that is not a byte at an entry >= 4096 (same delta value)", &[Site::OutLogUp], &forge(&fx, &tp, p));
    }
    // R2-5: a nonzero limb on a padded entry of the second row (the pad clause)
    {
        let mut p = honest(&fx, &tp);
        p.stage_out.planes[stage_out::A_LAM0][tp.v + 7] = Fp::new(1);
        record("R2-5", "a nonzero delta limb on the padded entry V + 7 (second row)", &[Site::OutSlot(stage_out::SO_VZC)], &forge(&fx, &tp, p));
    }
    // R2-6: the stage-IN histogram moved within the vocabulary rows (one
    // count of a first-row id moved to a second-row id; tok and rows honest)
    {
        let mut p = honest(&fx, &tp);
        let from = *fx.tokens.iter().skip(1).find(|t| **t as usize >= row2).expect("a second-row prompt id") as usize;
        let to = from - row2;
        let mut m = hist(&tp, &fx.tokens);
        m[from] = m[from].sub(Fp::ONE);
        m[to] = m[to].add(Fp::ONE);
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &fx.tokens), mult: m, hq_zero: vec![] };
        record("R2-6", "stage IN histogram: one count moved from a second-row id to its first-row twin (tok, rows honest)", &[Site::InLogUp], &forge(&fx, &tp, p));
    }
    // R2-7 (#16c): a padded token id in the second row (V + 11), its row the
    // repeated table row 0, the histogram counting it on that pad entry
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[5] = (tp.v + 11) as u64;
        let mut b = p.b_in.clone();
        set_row(&tp, &mut b, 5, fx.tables.emb_row(0));
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &toks), mult: hist(&tp, &toks), hq_zero: vec![] };
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        with_b_in(&fx, &tp, &mut p, b);
        record("R2-7", "(#16c, second row) padded token id V + 11, histogram on that pad entry", &[Site::InSlot(stage_in::SI_TZC)], &forge(&fx, &tp, p));
    }
}

// ------------------------------------------------------------------ 3. D20 at the calibrated Cn

/// **R2, review condition (b): D20 at the calibrated `Cn = 5,664`.** A row
/// whose final-norm output leaves int8 is refused by the honest pipeline
/// BEFORE any commitment, with a message naming no position or value; the
/// same row passes at the refusal-free `Cn = 1,024` (DESIGN C-7's trade);
/// a spread row passes at both.
#[test]
fn r2_d20_the_final_norm_int8_overflow_is_a_live_refusal_at_the_calibrated_cn() {
    let sh = tinyllama();
    let tables = generic_tables_v(32_000, 2048, 0x7232_6432);
    let tp = TokenProfile::new(&sh, &tables, 1, R2_NORM, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    let free = TokenProfile::new(&sh, &tables, 1, FinalNorm { cn: 1024, ..R2_NORM }, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    let mut spiky = vec![0i64; tp.d_pad];
    spiky[0] = 32_767;
    let e = stage_out::out_values(&tp, &tables, &spiky, true).err().expect("D20: an int8 overflow of the final norm was admitted at Cn 5,664");
    assert_eq!(e, "token I/O stage OUT: final norm quotient/remainder (refused, D20)", "the refusal names a position or a value");
    stage_out::out_values(&free, &tables, &spiky, true).expect("the refusal-free Cn admits every int16 row");
    let mut s = 0x6432_3070u64;
    let mut spread = vec![0i64; tp.d_pad];
    for v in spread.iter_mut().take(tp.d) {
        *v = (lcg(&mut s) % 2001) as i64 - 1000;
    }
    let ov = stage_out::out_values(&tp, &tables, &spread, true).expect("a spread row is admitted at the calibrated Cn");
    assert!(ov.y.iter().all(|v| (-127..=127).contains(v)));
    eprintln!("TOKEN-IO-R2 D20 | final-norm int8 overflow at Cn 5,664 | refused before any commitment: {e} | the same row at Cn 1,024: admitted | a spread row (|x| <= 1000): admitted, |y| <= {}", ov.y.iter().map(|v| v.abs()).max().unwrap());
}

// ------------------------------------------------------------------ 4. the R2 run

/// the inputs of the R2 run, from public files only
struct R2Inputs {
    ex: TrainedExport,
    sh: Shape,
    blocks: Vec<BlockPublic>,
    model: TrainedModelStatement,
    tables: TokenTables,
    load_s: f64,
}

/// the SHA-256 of the three public tables (export `token_io.json`, lane
/// `r2_inputs/head_manifest.json`)
const EMB_SHA256: &str = "ad68c716693f12d17cd19c957fbe84ca0f94d79063735f7eb84ead8063d9ab06";
const HEAD_SHA256: &str = "b99cbec5f457e47ca2441de517135ba1bd1870e2ae8abe2038dbd84617436280";
const MULT_SHA256: &str = "7824019e82a62fd6e36c165b9aabfd3711d03b815731e298b356a734a7ea663f";

fn env_path(k: &str, default: &str) -> std::path::PathBuf {
    std::path::PathBuf::from(std::env::var(k).unwrap_or_else(|_| default.to_string()))
}

fn read_checked(path: &std::path::Path, want: &str) -> Vec<u8> {
    let b = std::fs::read(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    assert_eq!(hex(&sha256(&b)), want, "{}: not the recorded table", path.display());
    b
}

/// THE R2 PUBLIC SIDE: the export's 22 layers (every array SHA-checked by
/// the native loader), the trained-model statement under the R2 token run
/// profile (the export's records and provenance, `statement_of_records`'
/// rule), and the three tables.
fn load_r2() -> R2Inputs {
    let t0 = std::time::Instant::now();
    let export = env_path("TOKEN_IO_R2_EXPORT", "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128");
    let inputs = env_path("TOKEN_IO_R2_INPUTS", "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r2_inputs");
    let ex = TrainedExport::load(&export).unwrap_or_else(|e| panic!("the export: {e}"));
    let layers = ex.layers.clone();
    assert_eq!(layers.len(), 22, "the TinyLlama export has 22 layers");
    let c = ex.run_constants(&layers).unwrap();
    let sh = ex.shape_for(&c).unwrap();
    assert_eq!(sh, tinyllama(), "the export's shape is not the registered R2 shape (r2_calibration)");
    let mut blocks = Vec::with_capacity(22);
    let mut records = Vec::with_capacity(22);
    for &k in &layers {
        let t = ex.load_layer(&sh, &c, k, false).unwrap_or_else(|e| panic!("layer {k}: {e}"));
        records.push(t.record);
        blocks.push(t.blk);
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
    let model = TrainedModelStatement::new(&sh, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32, ex.source.clone(), cal, records).unwrap_or_else(|e| panic!("the R2 trained-model statement: {e}"));
    let emb: Vec<i16> = read_checked(&export.join("embedding_int16.bin"), EMB_SHA256).chunks_exact(2).map(|c| i16::from_le_bytes([c[0], c[1]])).collect();
    let head: Vec<i8> = read_checked(&inputs.join("head_int8_perrow.bin"), HEAD_SHA256).into_iter().map(|b| b as i8).collect();
    let mult: Vec<i64> = read_checked(&inputs.join("head_mult12.bin"), MULT_SHA256).chunks_exact(8).map(|c| i64::from_le_bytes(c.try_into().unwrap())).collect();
    let tables = TokenTables::new(32_000, 2048, emb, head, mult).unwrap();
    R2Inputs { ex, sh, blocks, model, tables, load_s: t0.elapsed().as_secs_f64() }
}

/// the prompt's token ids (the sequence manifest's `token_ids`)
fn seq_tokens(ex: &TrainedExport, seq: &str) -> Vec<u64> {
    let m = std::fs::read_to_string(ex.dir.join(format!("seq_{seq}")).join("manifest.json")).unwrap();
    let at = m.find("\"token_ids\"").expect("token_ids") + "\"token_ids\"".len();
    let open = at + m[at..].find('[').unwrap() + 1;
    let close = open + m[open..].find(']').unwrap();
    m[open..close].split(',').map(|x| x.trim().parse::<u64>().expect("a token id")).collect()
}

fn unpad(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect()
}

/// R2's honest pipeline: keeps the boundary planes only (each witness is
/// built, its output plane taken, and dropped; the proving pass rebuilds it)
struct R2Pipe {
    stage_in: StageInWitness,
    b_in: Vec<i16>,
    planes: Vec<Vec<i16>>,
    out_values: OutValues,
    stage_out: StageOutWitness,
    in_plane: Vec<Fp>,
    out_plane: Vec<Fp>,
}

fn block_plane(sh: &Shape, ids: &Ids, blk: &BlockPublic, x: &[i16]) -> Result<Vec<i16>, String> {
    let w = super::super::witness::build_shaped(sh, blk.attention(), blk.feed_forward(), x)?;
    w.planes[ids.at(A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| "a block output outside int16".to_string())).collect()
}

/// every refusal fires here, before any header exists (ruling H-1); the
/// boundary planes are compared with the export's own `x_in_L00` and every
/// `x_out_Lk` (the native parity)
fn r2_pipeline(inp: &R2Inputs, tp: &TokenProfile, seq: &str, tokens: &[u64]) -> Result<R2Pipe, String> {
    let sh = &inp.sh;
    let (stage_in, b_in, in_plane) = stage_in::honest_inputs(tp, &inp.tables, tokens)?;
    let ids = Ids::new(sh)?;
    let (x_in0, _) = inp.ex.load_seq(sh, seq, 0)?;
    if unpad(sh, &b_in) != x_in0 {
        return Err("R2: B_in (the embedded prompt) is not the export's x_in_L00".into());
    }
    let mut x = x_in0;
    let mut planes = Vec::with_capacity(inp.blocks.len());
    for (k, blk) in inp.blocks.iter().enumerate() {
        let plane = block_plane(sh, &ids, blk, &x).map_err(|e| format!("R2: block {k}: {e}"))?;
        x = unpad(sh, &plane);
        if x != inp.ex.load_seq(sh, seq, k as u32)?.1 {
            return Err(format!("R2: block {k}'s output is not the export's x_out_L{k:02}"));
        }
        planes.push(plane);
    }
    let b_out = planes.last().ok_or("R2: no block")?;
    let out_values = stage_out::out_values(tp, &inp.tables, &stage_out::row_of(tp, b_out, tp.tokens - 1), true)?;
    let stage_out = stage_out::witness_from_values(tp, &out_values)?;
    let out_plane = stage_out::endpoint_plane(tp, out_values.tok as u64);
    Ok(R2Pipe { stage_in, b_in, planes, out_values, stage_out, in_plane, out_plane })
}

/// the streaming source: block `k`'s witness rebuilt from boundary `k`
struct StreamSource<'a> {
    sh: &'a Shape,
    pipe: &'a R2Pipe,
    witness_s: f64,
}

impl TokenRunSource for StreamSource<'_> {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        Ok((self.pipe.stage_in.clone(), self.pipe.b_in.clone()))
    }
    fn witness(&mut self, k: usize, blk: &BlockPublic, ssh: &Shape) -> Result<super::super::witness::Witness, String> {
        let t0 = std::time::Instant::now();
        let x = unpad(self.sh, if k == 0 { &self.pipe.b_in } else { &self.pipe.planes[k - 1] });
        let w = super::super::witness::build_shaped(ssh, blk.attention(), blk.feed_forward(), &x);
        self.witness_s += t0.elapsed().as_secs_f64();
        w
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.pipe.planes.get(k).cloned().ok_or_else(|| format!("R2: no plane after block {k}"))
    }
    fn stage_out(&mut self) -> Result<StageOutWitness, String> {
        Ok(self.pipe.stage_out.clone())
    }
    fn seal_check(&mut self, k: usize, blk: &BlockPublic, ssh: &Shape, check: &mut dyn FnMut(&super::super::witness::Witness) -> Result<(), String>) -> Result<(), String> {
        let x = unpad(self.sh, if k == 0 { &self.pipe.b_in } else { &self.pipe.planes[k - 1] });
        check(&super::super::witness::build_shaped(ssh, blk.attention(), blk.feed_forward(), &x)?)
    }
}

/// the reference next token, computed independently of the stage code (R0's
/// integer semantics) on the export's own `x_out_L21` row `T - 1`
fn reference_next_token_r2(tp: &TokenProfile, tables: &TokenTables, x_last: &[i16]) -> (usize, i128) {
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
    let l: Vec<i128> = (0..tp.v).map(|j| i128::from(tables.mult[j]) * (0..tp.d).map(|i| i128::from(tables.head[j * tp.d + i]) * y[i]).sum::<i128>()).collect();
    let mut best = 0usize;
    for j in 1..l.len() {
        if l[j] > l[best] {
            best = j;
        }
    }
    let second = (0..l.len()).filter(|j| *j != best).map(|j| l[j]).max().unwrap();
    (best, l[best] - second)
}

fn r2_out() -> std::path::PathBuf {
    std::path::PathBuf::from(std::env::var("TOKEN_IO_R2_OUT").expect("set TOKEN_IO_R2_OUT to the evidence directory"))
}

fn r2_seq() -> String {
    std::env::var("TOKEN_IO_R2_SEQ").unwrap_or_else(|_| "ho00".into())
}

fn r2_context(seq: &str) -> Digest {
    let mut b = b"token I/O R2: TinyLlama-1.1B T32 public-row run context, sequence ".to_vec();
    b.extend_from_slice(seq.as_bytes());
    *blake3::hash(&b).as_bytes()
}

/// the verifier's policy for R2: the D27 MVP level, 95 whole bits
const R2_POLICY: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 95 };

/// **THE R2 RUN: PROVE TO A DIRECTORY** (run alone, guarded; `#[ignore]`).
/// The export's 22 trained blocks, the embedding table, the per-row head,
/// the calibrated final norm; the run's segments, the public statement and
/// the Python cross-check inputs into `$TOKEN_IO_R2_OUT/<seq>/`.
#[test]
#[ignore]
fn token_io_r2_prove_to_dir() {
    let t_all = std::time::Instant::now();
    let seq = r2_seq();
    let inp = load_r2();
    let tokens = seq_tokens(&inp.ex, &seq);
    let tp = TokenProfile::new(&inp.sh, &inp.tables, 1, R2_NORM, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    let t = std::time::Instant::now();
    let pipe = r2_pipeline(&inp, &tp, &seq, &tokens).unwrap_or_else(|e| panic!("the R2 honest pipeline refused: {e}"));
    let pipe_s = t.elapsed().as_secs_f64();
    let x_last_all = inp.ex.load_seq(&inp.sh, &seq, 21).unwrap().1;
    let x_last = &x_last_all[(tp.tokens - 1) * tp.d..tp.tokens * tp.d];
    let (want, margin) = reference_next_token_r2(&tp, &inp.tables, x_last);
    assert_eq!(pipe.out_values.tok, want, "the stage code's greedy token is not the reference");
    let ctx = r2_context(&seq);
    let (ins, outs) = endpoint_specs(&inp.sh, ctx, &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &inp.sh.hash_tag()).unwrap();
    let digests: Vec<Digest> = inp.blocks.iter().map(|b| b.digest()).collect();
    let st = TokenRunStatement::new(RunShape::new(inp.sh.clone(), 22, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32).unwrap(), ctx, digests, &inp.model, &inp.tables, 1, R2_NORM, SelectorVariant::PublicRow, Tier::R1_MVP, roots).unwrap();
    let dir = r2_out().join(&seq);
    std::fs::create_dir_all(&dir).unwrap();
    let mut src = StreamSource { sh: &inp.sh, pipe: &pipe, witness_s: 0.0 };
    let t = std::time::Instant::now();
    let mut lens = Vec::new();
    let (stats, hand) = prove_token_run(&st, &inp.blocks, &inp.tables, &mut src, owners, &mut |k, b| {
        lens.push(b.len());
        std::fs::write(dir.join(format!("segment_{k:03}.bin")), &b).map_err(|e| e.to_string())
    })
    .unwrap_or_else(|e| panic!("the R2 run did not prove: {e}"));
    let prove_s = t.elapsed().as_secs_f64();
    assert_eq!(lens, st.segment_lens().unwrap(), "the segment lengths are not the counted ones");
    owner_check_input(&st, &hand.input, &tokens).expect("the input owner's check");
    let tok = owner_check_output(&st, &hand.output).expect("the output owner's check");
    assert_eq!(tok, want, "the decommitted id is not the reference next token");
    let w = st.whole_run();
    let stmt = format!(
        "profile {}\nL 22\nseq {seq}\ncontext {}\ninput_root {}\noutput_root {}\ntrained_statement_identity {}\nsegment_bytes {:?}\ntotal_bytes {}\nprove_seconds {prove_s:.3}\nstage_seconds {:?}\nof_which_witness_seconds {:.3}\nvmhwm_mib {:?}\nload_seconds {:.3}\npipeline_seconds {pipe_s:.3}\nwhole_run openings {} column_log2 {:.3} logup_log2 {:.3} total_log2 {:.3} floor_bits {}\nparameter_line {}\n",
        RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32,
        hex(&ctx),
        hex(&roots.0),
        hex(&roots.1),
        hex(&inp.model.identity()),
        stats.segment_bytes,
        lens.iter().sum::<usize>(),
        stats.prove_s.iter().map(|s| (s * 1000.0).round() / 1000.0).collect::<Vec<_>>(),
        src.witness_s,
        stats.hwm_mib.iter().map(|m| m.round()).collect::<Vec<_>>(),
        inp.load_s,
        w.openings,
        w.column_log2,
        w.logup_log2,
        w.total_log2,
        w.floor_bits,
        st.parameter_line().unwrap()
    );
    std::fs::write(dir.join("statement.txt"), stmt).unwrap();
    let cross = format!(
        "{{\"seq\": \"{seq}\", \"note\": \"public calibration data and public tables only; the decommitted token is the OWNER's output\", \"decommitted_next_token\": {tok}, \"reference_top2_margin\": {margin}, \"tokens\": {:?}, \"x_last_from\": \"export seq_{seq}/x_out_L21.bin row {}\", \"g0\": {}, \"cn\": {}, \"tn\": {}, \"ceps\": {}, \"V\": {}, \"d\": {}}}\n",
        tokens,
        tp.tokens - 1,
        tp.norm.g0,
        tp.norm.cn,
        tp.norm.tn,
        tp.norm.ceps,
        tp.v,
        tp.d
    );
    std::fs::write(dir.join("crosscheck.json"), cross).unwrap();
    eprintln!(
        "TOKEN-IO-R2 PROVED {seq} -> {}: next token {tok} (reference {want}, top-2 logit margin {margin}), {} B in {} segments, prove {prove_s:.1} s (witness {:.1} s), load {:.1} s, pipeline {pipe_s:.1} s, peak RSS {:.0} MiB, whole run 2^{:.2} (floor {} bits), total {:.1} s [MEASURED, shared box, n=1]",
        dir.display(),
        lens.iter().sum::<usize>(),
        lens.len(),
        src.witness_s,
        inp.load_s,
        stats.hwm_mib.iter().cloned().fold(0.0, f64::max),
        w.total_log2,
        w.floor_bits,
        t_all.elapsed().as_secs_f64()
    );
}

/// **THE R2 RUN: VERIFY IN A FRESH PROCESS** (run alone; `#[ignore]`). Every
/// public input rebuilt from the export's public files and the tables (no
/// `seq_*` data is read); the roots and the context from `statement.txt`;
/// the verifier's policy is the D27 MVP level (95 bits); a one-bit change is
/// refused.
#[test]
#[ignore]
fn token_io_r2_verify_from_dir() {
    let seq = r2_seq();
    let dir = r2_out().join(&seq);
    let inp = load_r2();
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
    assert_eq!(ctx, r2_context(&seq));
    let roots = (unhex(field("input_root")), unhex(field("output_root")));
    let digests: Vec<Digest> = inp.blocks.iter().map(|b| b.digest()).collect();
    let st = TokenRunStatement::new(RunShape::new(inp.sh.clone(), 22, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32).unwrap(), ctx, digests, &inp.model, &inp.tables, 1, R2_NORM, SelectorVariant::PublicRow, Tier::R1_MVP, roots).unwrap();
    assert_eq!(field("parameter_line"), st.parameter_line().unwrap(), "the saved run is another statement");
    assert_eq!(field("trained_statement_identity"), hex(&inp.model.identity()));
    let segs: Vec<Vec<u8>> = (0..24).map(|k| std::fs::read(dir.join(format!("segment_{k:03}.bin"))).unwrap()).collect();
    let t0 = std::time::Instant::now();
    verify_token_run(&st, &inp.blocks, &inp.tables, &segs, R2_POLICY).unwrap_or_else(|e| panic!("the saved R2 run does not verify in a fresh process: {e}"));
    let vs = t0.elapsed().as_secs_f64();
    let mut bad = segs.clone();
    let at = bad[23].len() / 2;
    bad[23][at] ^= 1;
    assert!(verify_token_run(&st, &inp.blocks, &inp.tables, &bad, R2_POLICY).is_err(), "a one-bit change verified");
    eprintln!(
        "TOKEN-IO-R2 FRESH-PROCESS VERIFY {seq}: accepted from {} ({} B) in {vs:.1} s under a {}-bit policy (load {:.1} s); a one-bit change refused [MEASURED, shared box, n=1]",
        dir.display(),
        segs.iter().map(|s| s.len()).sum::<usize>(),
        R2_POLICY.min_whole_run_bits,
        inp.load_s
    );
}

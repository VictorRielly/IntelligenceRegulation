//! **INDEPENDENT ADVERSARIAL REVIEW, ROUND 3 (2026-10-19): the rebase onto
//! native R6, per-layer score shifts in the token run, rung R3 (Llama-3-8B,
//! 32 trained blocks streamed, V_pad 2^17).** TEST CODE ONLY, reviewer's
//! scratch copy only; a child of `token_io::run`.
//!
//! * `rv3_a*` (synthetic rung, cheap): per-layer score-shift probes and
//!   streaming probes (a wrong block mid-run on both sides).
//! * `rv3_b*` (`#[ignore]`): the R3 profile, the TRAINED 8B tables (V 128,256,
//!   32-row vocabulary planes) and the b7 export's first two trained layers
//!   (layer 1 at its own score shift 7): forgeries at R3 shape.
//! * `rv3_c*` (`#[ignore]`): the full 32-layer trained statement: the lane's
//!   saved receipt re-verified in this fresh process with probes and an
//!   independent recount of the whole-run figure; one full-scale forgery.
//!
//! `REVIEW-R3 CONTROL` lines are asserted refused where predicted; `REVIEW-R3
//! FINDING` lines are printed demonstrations. Public data only; no privacy
//! claim.

use super::*;
use super::super::super::protocol::CheatingProver;
use super::super::super::run::{BlockRef, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32, RUN_PROFILE_TOKEN_IO_RUNG_TC};
use super::super::super::trained_block::{Constants, TrainedExport};
use super::super::super::trained_statement::{IntegerCalibration, LayerRecord, Provenance};
use super::super::r3_tests::{load_token_tables, TableFiles};
use super::super::tests::{ctx, fx_generic, honest, model_with_records, profile, Fx, R3_BOS};

const POL93: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 93 };
const POL95: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 95 };

fn outcome(r: &Result<(), String>) -> String {
    match r {
        Ok(()) => "ACCEPTED".into(),
        Err(e) => format!("refused: {}", e.chars().take(180).collect::<String>()),
    }
}

fn expect_refused(id: &str, what: &str, predicted: &[&str], res: Result<(), String>) {
    match res {
        Ok(()) => {
            eprintln!("REVIEW-R3 CONTROL {id} | {what} | predicted {predicted:?} | actual: ACCEPTED | A FORGERY VERIFIED");
            panic!("REVIEW-R3 {id} ({what}): A FORGERY VERIFIED");
        }
        Err(e) => {
            let hit = predicted.iter().any(|p| e.starts_with(p) || e.contains(p));
            eprintln!("REVIEW-R3 CONTROL {id} | {what} | predicted {predicted:?} | actual: {} | {}", e.chars().take(180).collect::<String>(), if hit { "AS PREDICTED" } else { "NOT AS PREDICTED" });
            assert!(hit, "REVIEW-R3 {id} ({what}) was refused elsewhere than predicted {predicted:?}: {e}");
        }
    }
}

fn finding(id: &str, what: &str, out: &str) {
    eprintln!("REVIEW-R3 FINDING {id} | {what} | {out}");
}

fn bump(v: i16) -> i16 {
    if v < i16::MAX { v + 1 } else { v - 1 }
}

/// a block source that hands block `wrong.1` at stage `wrong.0` (resident slice)
struct WrongAt<'a> {
    blocks: &'a [BlockPublic],
    wrong: (usize, usize),
}

impl TokenBlocks for WrongAt<'_> {
    fn count(&self) -> usize {
        self.blocks.len()
    }
    fn block(&mut self, k: usize) -> Result<BlockRef<'_>, String> {
        let j = if k == self.wrong.0 { self.wrong.1 } else { k };
        self.blocks.get(j).map(BlockRef::Borrowed).ok_or_else(|| format!("no block {j}"))
    }
}

fn rung_statement(fx: &Fx, model: &TrainedModelStatement, roots: (Digest, Digest)) -> Result<TokenRunStatement, String> {
    TokenRunStatement::new(RunShape::new(fx.sh.clone(), fx.blocks.len(), RUN_PROFILE_TOKEN_IO_RUNG_TC)?, ctx(), fx.blocks.iter().map(|b| b.digest()).collect(), model, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots)
}

fn recs_with(fx: &Fx, own: &[(usize, u32)]) -> Vec<LayerRecord> {
    let mut r: Vec<LayerRecord> = fx.blocks.iter().enumerate().map(|(k, b)| LayerRecord::of_block(k as u32, b, vec![])).collect();
    for (k, v) in own {
        r[*k].sh_s = Some(*v);
    }
    r
}

// =================================================================== A: cheap probes

/// RV3-A1: per-layer score shift at the rung. An honest per-layer run (layer 1
/// at its own shift) verifies; the same receipt under statements that move
/// the shift to layer 0, give it to both layers, or drop it, is refused; the
/// trained door refuses a record whose own shift equals the run's or leaves
/// the one-limb window.
#[test]
fn rv3_a1_per_layer_score_shift_probes_at_the_rung() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let own = if fx.sh.sh_s == 6 { 5 } else { 6 };
    let shapes = vec![fx.sh.clone(), fx.sh.with_score_shift(own).unwrap()];
    let mut pipe = honest_pipeline_at(&shapes, &tp, &fx.tables, &fx.blocks, &fx.tokens).unwrap();
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
    let m1 = model_with_records(&fx.sh, recs_with(&fx, &[(1, own)]), RUN_PROFILE_TOKEN_IO_RUNG_TC);
    let st = rung_statement(&fx, &m1, roots).unwrap();
    let mut segs = Vec::new();
    prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .unwrap();
    verify_token_run(&st, &fx.blocks, &fx.tables, &segs, POL93).expect("the honest per-layer run verifies");
    for (what, own_list) in [("the own shift moved to layer 0", vec![(0usize, own)]), ("both layers at the own shift", vec![(0, own), (1, own)]), ("no layer with its own shift (run-wide)", vec![])] {
        let m = model_with_records(&fx.sh, recs_with(&fx, &own_list), RUN_PROFILE_TOKEN_IO_RUNG_TC);
        let r = match rung_statement(&fx, &m, roots) {
            Err(e) => Err(format!("construction: {e}")),
            Ok(s2) => verify_token_run(&s2, &fx.blocks, &fx.tables, &segs, POL93),
        };
        expect_refused("RV3-A1", &format!("the per-layer receipt under a statement with {what}"), &["token I/O wire: this segment belongs to another run", "construction"], r);
    }
    for (what, v) in [("an own shift equal to the run's", fx.sh.sh_s), ("an own shift outside the one-limb window (40)", 40)] {
        let mut r = recs_with(&fx, &[]);
        r[1].sh_s = Some(v);
        let e = TrainedModelStatement::new(&fx.sh, RUN_PROFILE_TOKEN_IO_RUNG_TC, fx.model.source.clone(), fx.model.calibration.clone(), r).map(|_| ());
        expect_refused("RV3-A1", &format!("a layer record with {what}"), &["trained statement: "], e);
    }
}

/// RV3-A2: streaming. A block source handing block 0 at stage 1 is refused by
/// name (CS-6) by the verifier and by the honest prover; the prover's
/// refusal comes after the segments of stage IN and block 0 reached the sink
/// (the documented sink contract: nothing is published before Ok).
#[test]
fn rv3_a2_a_wrong_block_mid_run_is_refused_on_both_sides() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
    let st = rung_statement(&fx, &fx.model, roots).unwrap();
    let mut segs = Vec::new();
    prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .unwrap();
    verify_token_run(&st, &fx.blocks, &fx.tables, &segs, POL93).expect("the honest run verifies");
    let r = verify_token_run_with(&st, &mut WrongAt { blocks: &fx.blocks, wrong: (1, 0) }, &fx.tables, &segs, POL93);
    expect_refused("RV3-A2", "verifier handed block 0 at stage 1", &["ruling CS-6"], r);
    let mut pipe2 = honest(&fx, &tp);
    let (roots2, owners2) = seal_endpoints(&ins, &outs, &pipe2.in_plane, &pipe2.out_plane, &fx.sh.hash_tag()).unwrap();
    let st2 = rung_statement(&fx, &fx.model, roots2).unwrap();
    let mut emitted = 0usize;
    let r = prove_token_run_with(&st2, &mut WrongAt { blocks: &fx.blocks, wrong: (1, 0) }, &fx.tables, &mut PipelineSource(&mut pipe2), owners2, &mut |_, _| {
        emitted += 1;
        Ok(())
    })
    .map(|_| ());
    expect_refused("RV3-A2", "honest prover handed block 0 at stage 1", &["ruling CS-6"], r);
    finding("TR3-sink", "segments the honest prover handed to the sink before a mid-run CS-6 refusal at stage 1", &format!("{emitted} (stage IN, which carries the input token endpoint's ONE opening, and block 0)"));
}

// =================================================================== the 8B fixtures

const EXPORT_B7: &str = "/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b7_T32";
const LANE_R3_TRAINED: &str = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/runs/r3/trained-ho00";
const R3_TRAINED_NORM: FinalNorm = FinalNorm { g0: 127, cn: 4234, tn: 9, ceps: 78_617 };

struct E8 {
    ex: TrainedExport,
    c: Constants,
    sh: Shape,
    layers: Vec<u32>,
    blocks: Vec<BlockPublic>,
    digests: Vec<Digest>,
    records: Vec<LayerRecord>,
    cal: IntegerCalibration,
    tables: TokenTables,
}

/// the b7 export: all 32 layers' records and digests (the digest pass); the
/// first `keep` blocks kept resident; the trained tables (SHA-checked loader)
fn load8(keep: usize) -> E8 {
    let ex = TrainedExport::load(std::path::Path::new(EXPORT_B7)).unwrap_or_else(|e| panic!("the b7 export: {e}"));
    let layers = ex.layers.clone();
    assert_eq!(layers.len(), 32);
    let c = ex.run_constants(&layers).unwrap();
    let sh = ex.shape_for(&c).unwrap();
    let (mut blocks, mut digests, mut records) = (Vec::new(), Vec::new(), Vec::new());
    for (i, &k) in layers.iter().enumerate() {
        let t = ex.load_layer(&sh, &c, k, false).unwrap_or_else(|e| panic!("layer {k}: {e}"));
        digests.push(t.record.block_digest);
        records.push(t.record);
        if i < keep {
            blocks.push(t.blk);
        }
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
    let tio = ex.dir.join("token_io");
    let (tables, hm) = load_token_tables(&TableFiles { emb_dir: tio.clone(), head_dir: tio }, 128_256, 4096).unwrap_or_else(|e| panic!("the trained 8B tables: {e}"));
    assert!(hm.contains("4234"), "the head manifest does not record the calibrated Cn 4,234");
    E8 { ex, c, sh, layers, blocks, digests, records, cal, tables }
}

fn model8(e: &E8, n: usize, records: Vec<LayerRecord>) -> Result<TrainedModelStatement, String> {
    let _ = n;
    TrainedModelStatement::new(&e.sh, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32, e.ex.source.clone(), e.cal.clone(), records)
}

fn stage_shapes(e: &E8, records: &[LayerRecord]) -> Vec<Shape> {
    records.iter().map(|r| r.sh_s.map(|v| e.sh.with_score_shift(v).unwrap()).unwrap_or_else(|| e.sh.clone())).collect()
}

fn st8(e: &E8, l: usize, model: &TrainedModelStatement, norm: FinalNorm, bos: u64, ctx: Digest, roots: (Digest, Digest), tables: &TokenTables) -> Result<TokenRunStatement, String> {
    TokenRunStatement::new(RunShape::new(e.sh.clone(), l, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32)?, ctx, e.digests[..l].to_vec(), model, tables, bos, norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots)
}

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

fn pad_plane(sh: &Shape, x: &[i16]) -> Vec<i16> {
    let mut p = vec![0i16; sh.t_pad * sh.d_pad];
    for t in 0..sh.tokens {
        p[t * sh.d_pad..t * sh.d_pad + sh.width].copy_from_slice(&x[t * sh.width..(t + 1) * sh.width]);
    }
    p
}

fn r3_context(seq: &str, mode: &str) -> Digest {
    let mut b = format!("token I/O R3: Llama-3-8B T32 public-row run context, {mode} tables, sequence ").into_bytes();
    b.extend_from_slice(seq.as_bytes());
    *blake3::hash(&b).as_bytes()
}

#[derive(Clone)]
struct Pipe8 {
    stage_in: StageInWitness,
    b_in: Vec<i16>,
    x0: Option<Vec<i16>>,
    planes: Vec<Vec<i16>>,
    out_values: OutValues,
    stage_out: StageOutWitness,
    in_plane: Vec<Fp>,
    out_plane: Vec<Fp>,
}

fn chain8(sh: &Shape, shapes: &[Shape], blocks: &[BlockPublic], x0: &[i16]) -> Result<Vec<Vec<i16>>, String> {
    let ids = Ids::new(sh)?;
    let mut x = x0.to_vec();
    let mut planes = Vec::new();
    for (k, blk) in blocks.iter().enumerate() {
        let w = super::super::super::witness::build_shaped(&shapes[k], blk.attention(), blk.feed_forward(), &x).map_err(|e| format!("block {k}: {e}"))?;
        let plane: Vec<i16> = w.planes[ids.at(A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| "a block output outside int16".to_string())).collect::<Result<_, _>>()?;
        x = unpad(sh, &plane);
        planes.push(plane);
    }
    Ok(planes)
}

fn out8(tp: &TokenProfile, tables: &TokenTables, b_out: &[i16], row: usize, check: bool) -> Result<(OutValues, StageOutWitness, Vec<Fp>), String> {
    let ov = stage_out::out_values(tp, tables, &stage_out::row_of(tp, b_out, row), check)?;
    let w = stage_out::witness_from_values(tp, &ov)?;
    let ep = stage_out::endpoint_plane(tp, ov.tok as u64);
    Ok((ov, w, ep))
}

fn pipe8(e: &E8, shapes: &[Shape], tp: &TokenProfile, tokens: &[u64], check: bool) -> Result<Pipe8, String> {
    let (stage_in, b_in, in_plane) = stage_in::honest_inputs(tp, &e.tables, tokens)?;
    let planes = chain8(&e.sh, shapes, &e.blocks, &unpad(&e.sh, &b_in))?;
    let (out_values, stage_out, out_plane) = out8(tp, &e.tables, planes.last().unwrap(), tp.tokens - 1, check)?;
    Ok(Pipe8 { stage_in, b_in, x0: None, planes, out_values, stage_out, in_plane, out_plane })
}

/// resident-pipe source: block k's witness at the HANDED stage shape
struct Src8<'a> {
    sh: &'a Shape,
    p: &'a Pipe8,
    /// a forger's override: witness block `k` at this shape instead
    shape_override: Option<(usize, Shape)>,
}

impl TokenRunSource for Src8<'_> {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        Ok((self.p.stage_in.clone(), self.p.b_in.clone()))
    }
    fn witness(&mut self, k: usize, blk: &BlockPublic, ssh: &Shape) -> Result<Witness, String> {
        let x = if k == 0 { self.p.x0.clone().unwrap_or_else(|| unpad(self.sh, &self.p.b_in)) } else { unpad(self.sh, &self.p.planes[k - 1]) };
        let s = match &self.shape_override {
            Some((j, s)) if *j == k => s.clone(),
            _ => ssh.clone(),
        };
        super::super::super::witness::build_shaped(&s, blk.attention(), blk.feed_forward(), &x)
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.p.planes.get(k).cloned().ok_or_else(|| format!("no plane after block {k}"))
    }
    fn stage_out(&mut self) -> Result<StageOutWitness, String> {
        Ok(self.p.stage_out.clone())
    }
}

/// the 8B block source: block k reloaded at its stage and digest-checked
/// against the digest pass (one resident)
struct Stream8<'a> {
    e: &'a E8,
    cur: Option<(usize, std::sync::Arc<BlockPublic>)>,
    /// a hostile source: hand layer `wrong.1`'s block at stage `wrong.0`
    wrong: Option<(usize, usize)>,
}

impl TokenBlocks for Stream8<'_> {
    fn count(&self) -> usize {
        self.e.layers.len()
    }
    fn block(&mut self, k: usize) -> Result<BlockRef<'_>, String> {
        if let Some((j, a)) = &self.cur {
            if *j == k {
                return Ok(BlockRef::Shared(a.clone()));
            }
        }
        self.cur = None;
        let pick = match self.wrong {
            Some((at, from)) if at == k => from,
            _ => k,
        };
        let blk = self.e.ex.reload_block(&self.e.sh, &self.e.c, self.e.layers[pick], false)?;
        let a = std::sync::Arc::new(blk);
        self.cur = Some((k, a.clone()));
        Ok(BlockRef::Shared(a))
    }
}

/// the streaming witness source of the full run (the export's own words)
struct SrcFull<'a> {
    e: &'a E8,
    seq: String,
    stage_in: Option<(StageInWitness, Vec<i16>)>,
    stage_out: Option<StageOutWitness>,
}

impl TokenRunSource for SrcFull<'_> {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        self.stage_in.take().ok_or_else(|| "stage IN asked twice".to_string())
    }
    fn witness(&mut self, k: usize, blk: &BlockPublic, ssh: &Shape) -> Result<Witness, String> {
        let x = if k == 0 { self.e.ex.load_seq(&self.e.sh, &self.seq, self.e.layers[0])?.0 } else { self.e.ex.load_seq(&self.e.sh, &self.seq, self.e.layers[k - 1])?.1 };
        super::super::super::witness::build_shaped(ssh, blk.attention(), blk.feed_forward(), &x)
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(pad_plane(&self.e.sh, &self.e.ex.load_seq(&self.e.sh, &self.seq, self.e.layers[k])?.1))
    }
    fn stage_out(&mut self) -> Result<StageOutWitness, String> {
        self.stage_out.take().ok_or_else(|| "stage OUT asked twice".to_string())
    }
}

fn set_argmax(tp: &TokenProfile, w: &mut StageOutWitness, e: &[(usize, Fp)], tok: Fp, m: Fp, delta: &dyn Fn(usize) -> Fp) {
    let n = 1usize << tp.vo_log();
    w.planes[stage_out::A_E] = vec![Fp::ZERO; n];
    for (i, v) in e {
        w.planes[stage_out::A_E][*i] = *v;
    }
    w.planes[stage_out::A_TOK][0] = tok;
    w.planes[stage_out::A_M][0] = m;
    for kk in 0..tp.limbs {
        w.planes[stage_out::A_LAM0 + kk] = vec![Fp::ZERO; n];
    }
    for i in 0..tp.v {
        let x = delta(i).0;
        for kk in 0..tp.limbs {
            w.planes[stage_out::A_LAM0 + kk][i] = Fp::new((x >> (8 * kk)) & 0xFF);
        }
    }
}

fn keyed(tp: &TokenProfile, m: i64, l: i64, i: usize, j: usize) -> Fp {
    Fp::from_i64(((m - l) << tp.log_v) + (i as i64 - j as i64))
}

// =================================================================== B: R3 shape, two trained layers

/// RV3-B: the R3 profile, the TRAINED 8B tables, the b7 export's layers 0 and
/// 1 (layer 1 at its own score shift), 32-row vocabulary planes.
#[test]
#[ignore]
fn rv3_b_r3_shape_forgeries_on_two_trained_layers() {
    let e = load8(2);
    let tokens = seq_tokens(&e.ex, "ho00");
    let recs2 = e.records[..2].to_vec();
    assert!(recs2[1].sh_s.is_some(), "the b7 export's layer 1 has no own score shift: this fixture would not test it");
    eprintln!("REVIEW-R3 FIXTURE | b7 layers 0, 1: run sh_s {}, layer 1's own sh_s {:?}", e.sh.sh_s, recs2[1].sh_s);
    let m2 = model8(&e, 2, recs2.clone()).expect("the two-layer prefix statement");
    let shapes = stage_shapes(&e, &recs2);
    let cal_tp = TokenProfile::new(&e.sh, &e.tables, R3_BOS, R3_TRAINED_NORM, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    assert_eq!((cal_tp.v_pad, cal_tp.voc_log(), cal_tp.vo_log(), cal_tp.do_log(), cal_tp.limbs, cal_tp.window_bits), (131_072, 17, 17, 12, 7, 56));
    let norm = match pipe8(&e, &shapes, &cal_tp, &tokens, true) {
        Ok(p) => {
            eprintln!("REVIEW-R3 D20 | two-layer prefix, ho00 row 31 at Cn 4,234 | admitted (max |y| {})", p.out_values.y.iter().map(|v| v.abs()).max().unwrap());
            R3_TRAINED_NORM
        }
        Err(err) => {
            eprintln!("REVIEW-R3 D20 | two-layer prefix, ho00 row 31 at Cn 4,234 | refused before any commitment: {err:?}");
            assert_eq!(err, "token I/O stage OUT: final norm quotient/remainder (refused, D20)");
            FinalNorm { cn: 512, ..R3_TRAINED_NORM }
        }
    };
    let tp = TokenProfile::new(&e.sh, &e.tables, R3_BOS, norm, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    let base = pipe8(&e, &shapes, &tp, &tokens, true).unwrap();
    for k in 0..2 {
        assert_eq!(unpad(&e.sh, &base.planes[k]), e.ex.load_seq(&e.sh, "ho00", e.layers[k]).unwrap().1, "parity with x_out_L{k:02} (layer 1 at its own shift)");
    }
    let ctx3 = *blake3::hash(b"review round 3: two-layer 8B prefix").as_bytes();
    let prove = |p: &Pipe8, cheat: bool, over: Option<(usize, Shape)>, model: &TrainedModelStatement| -> Result<(TokenRunStatement, Vec<Vec<u8>>, OwnerHandoff), String> {
        let (ins, outs) = endpoint_specs(&e.sh, ctx3, &tp)?;
        let (roots, owners) = seal_endpoints(&ins, &outs, &p.in_plane, &p.out_plane, &e.sh.hash_tag())?;
        let st = st8(&e, 2, model, norm, R3_BOS, ctx3, roots, &e.tables)?;
        let mut segs = Vec::new();
        let mut src = Src8 { sh: &e.sh, p, shape_override: over };
        let res = {
            let _c = if cheat { Some(CheatingProver::on()) } else { None };
            prove_token_run(&st, &e.blocks, &e.tables, &mut src, owners, &mut |_, b| {
                segs.push(b);
                Ok(())
            })
        };
        let (_, hand) = res?;
        Ok((st, segs, hand))
    };
    let forge = |p: &Pipe8| -> Result<(), String> {
        let (st, segs, _) = prove(p, true, None, &m2).unwrap_or_else(|er| panic!("the cheating prover did not produce a receipt: {er}"));
        verify_token_run(&st, &e.blocks, &e.tables, &segs, POL95)
    };
    let t0 = std::time::Instant::now();
    let (st, segs, hand) = prove(&base, false, None, &m2).expect("the honest two-layer 8B run");
    let ps = t0.elapsed().as_secs_f64();
    verify_token_run(&st, &e.blocks, &e.tables, &segs, POL95).expect("the honest two-layer 8B run verifies");
    assert_eq!(segs.iter().map(|s| s.len()).collect::<Vec<_>>(), st.segment_lens().unwrap());
    owner_check_input(&st, &hand.input, &tokens).expect("input owner");
    assert_eq!(owner_check_output(&st, &hand.output).expect("output owner"), base.out_values.tok);
    assert!(st.stage_lines().unwrap()[2].contains("score shift"), "layer 1's stage line does not name its own shift");
    eprintln!("REVIEW-R3 HONEST two-layer 8B run: Cn {}, next token {}, prove {ps:.1} s, {} B, floor {} bits [MEASURED, shared box, n=1]", norm.cn, base.out_values.tok, segs.iter().map(|s| s.len()).sum::<usize>(), st.whole_run().floor_bits);
    let l = base.out_values.logits.clone();
    let j = base.out_values.tok;
    let max = l[j];
    let row = 1usize << tp.tier.stage_log_n;
    let last = (1usize << tp.vo_log()) - 1;
    let inv2v = Fp::new(1u64 << tp.log_v).inv();
    let ep = |id: u64| stage_out::endpoint_plane(&tp, id);
    {
        let mut p = base.clone();
        let pad = tp.v + 5;
        set_argmax(&tp, &mut p.stage_out, &[(pad, Fp::ONE)], Fp::new(pad as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, pad));
        p.out_plane = ep(pad as u64);
        expect_refused("RV3-B1", "e on the padded entry V + 5 (last row of a 32-row plane), tok = V + 5", &["stage OUT slot 06 "], forge(&p));
    }
    let j2 = (0..tp.v).filter(|i| i / row != j / row && l[*i] < max).max_by_key(|i| (l[*i], std::cmp::Reverse(*i))).unwrap();
    {
        let mut p = base.clone();
        set_argmax(&tp, &mut p.stage_out, &[(j2, Fp::ONE)], Fp::new(j2 as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, j2));
        p.out_plane = ep(j2 as u64);
        expect_refused("RV3-B2", &format!("A6-only at id {j2} (row {}; honest {j}, row {})", j2 / row, j / row), &["stage OUT slot 07 "], forge(&p));
    }
    {
        let mut p = base.clone();
        let t3 = if j + row < tp.v { j + row } else { j - row };
        p.stage_out.planes[stage_out::A_TOK][0] = Fp::new(t3 as u64);
        p.stage_out.planes[stage_out::A_M][0] = Fp::from_i64(max).add(inv2v.mul(Fp::from_i64(t3 as i64 - j as i64)));
        p.out_plane = ep(t3 as u64);
        expect_refused("RV3-B3", &format!("A3-only: tok' = {t3} (one row away), M shifted by 2^-17 (tok' - j)"), &["stage OUT slot 07 "], forge(&p));
    }
    {
        let mut p = base.clone();
        p.stage_in.mult[0] = p.stage_in.mult[0].sub(Fp::ONE);
        p.stage_in.mult[tp.v + 1] = p.stage_in.mult[tp.v + 1].add(Fp::ONE);
        expect_refused("RV3-B4", "stage IN m: one count of row 0 moved to the padded entry V + 1 (invisible to LogUp)", &["stage IN slot 02 "], forge(&p));
    }
    {
        let mut p = base.clone();
        p.stage_out.planes[stage_out::A_LAM0][last] = Fp::ONE;
        expect_refused("RV3-B5", "a nonzero delta limb on the last cube entry (131,071)", &["stage OUT slot 06 "], forge(&p));
    }
    {
        let mut p = base.clone();
        let (ov, w, epl) = out8(&tp, &e.tables, p.planes.last().unwrap(), tp.tokens - 2, false).unwrap();
        p.out_values = ov;
        p.stage_out = w;
        p.out_plane = epl;
        expect_refused("RV3-B6", "stage OUT computed from row T - 2", &["stage OUT slot 00 "], forge(&p));
    }
    {
        let mut p = base.clone();
        p.stage_out.planes[stage_out::A_E][last] = Fp::ONE;
        expect_refused("RV3-B7", "a second hot e on entry 131,071 beside the honest one", &["stage OUT slot 06 "], forge(&p));
    }
    {
        let mut p = base.clone();
        let mut toks = tokens.clone();
        toks[5] = (tp.v + 11) as u64;
        let mut b = p.b_in.clone();
        b[5 * tp.d_pad..5 * tp.d_pad + tp.d].copy_from_slice(e.tables.emb_row(0));
        let mut m = vec![Fp::ZERO; 1usize << tp.voc_log()];
        for t in &toks {
            m[*t as usize] = m[*t as usize].add(Fp::ONE);
        }
        p.stage_in.tok[5] = Fp::new(toks[5]);
        p.stage_in.mult = m;
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        p.planes = chain8(&e.sh, &shapes, &e.blocks, &unpad(&e.sh, &b)).unwrap();
        let (ov, w, epl) = out8(&tp, &e.tables, p.planes.last().unwrap(), tp.tokens - 1, false).unwrap();
        p.out_values = ov;
        p.stage_out = w;
        p.out_plane = epl;
        p.b_in = b;
        expect_refused("RV3-B8", "a padded token id V + 11 at position 5, row = table row 0, histogram on the pad", &["stage IN slot 02 ", "stage IN H "], forge(&p));
    }
    {
        let mut p = base.clone();
        let mut x0 = unpad(&e.sh, &p.b_in);
        x0[3 * tp.d + 17] = bump(x0[3 * tp.d + 17]);
        p.planes = chain8(&e.sh, &shapes, &e.blocks, &x0).unwrap();
        let (ov, w, epl) = out8(&tp, &e.tables, p.planes.last().unwrap(), tp.tokens - 1, false).unwrap();
        p.out_values = ov;
        p.stage_out = w;
        p.out_plane = epl;
        p.x0 = Some(x0);
        expect_refused("RV3-B9", "B_in = E[tok] for stage IN, block 0 proved on another input", &["block 0", "boundary 0"], forge(&p));
    }
    {
        let mut p = base.clone();
        let new_id = 127_000u64;
        let mut toks = tokens.clone();
        toks[7] = new_id;
        let mut b = p.b_in.clone();
        b[7 * tp.d_pad..7 * tp.d_pad + tp.d].copy_from_slice(e.tables.emb_row(new_id as usize));
        let mut m = vec![Fp::ZERO; 1usize << tp.voc_log()];
        for t in &toks {
            m[*t as usize] = m[*t as usize].add(Fp::ONE);
        }
        p.stage_in.tok[7] = Fp::new(new_id);
        p.stage_in.mult = m;
        p.planes = chain8(&e.sh, &shapes, &e.blocks, &unpad(&e.sh, &b)).unwrap();
        let (ov, w, epl) = out8(&tp, &e.tables, p.planes.last().unwrap(), tp.tokens - 1, false).unwrap();
        p.out_values = ov;
        p.stage_out = w;
        p.out_plane = epl;
        p.b_in = b;
        expect_refused("RV3-B10", "consistent re-lookup (position 7 -> id 127,000, last Voc row) under the honest seal", &["stage IN slot 00 "], forge(&p));
    }
    {
        let mut p = base.clone();
        let from = tokens[3] as usize;
        let to = if from + row < tp.v { from + row } else { from - row };
        p.stage_in.mult[from] = p.stage_in.mult[from].sub(Fp::ONE);
        p.stage_in.mult[to] = p.stage_in.mult[to].add(Fp::ONE);
        expect_refused("RV3-B11", &format!("stage IN m: one count moved from id {from} to id {to} (another row)"), &["stage IN H "], forge(&p));
    }
    // the per-layer score shift at real 8B weights
    {
        let wide = e.sh.clone();
        let (st_c, segs_c, _) = prove(&base, true, Some((1, wide)), &m2).expect("the cheating prover");
        expect_refused("RV3-B12", "block 1 (layer 1, own shift) witnessed at the run-wide shift under the per-layer statement", &["block 1"], verify_token_run(&st_c, &e.blocks, &e.tables, &segs_c, POL95));
    }
    {
        let mut r = recs2.clone();
        r[1].sh_s = None;
        let m_wide = model8(&e, 2, r).unwrap();
        let st_w = st8(&e, 2, &m_wide, norm, R3_BOS, ctx3, st.roots(), &e.tables).unwrap();
        expect_refused("RV3-B13", "the honest per-layer receipt under the statement without layer 1's own shift", &["token I/O wire: this segment belongs to another run"], verify_token_run(&st_w, &e.blocks, &e.tables, &segs, POL95));
        let mut r = recs2.clone();
        r[0].sh_s = r[1].sh_s;
        r[1].sh_s = None;
        let res = match model8(&e, 2, r) {
            Err(er) => Err(format!("construction: {er}")),
            Ok(m0) => match st8(&e, 2, &m0, norm, R3_BOS, ctx3, st.roots(), &e.tables) {
                Err(er) => Err(format!("construction: {er}")),
                Ok(s0) => verify_token_run(&s0, &e.blocks, &e.tables, &segs, POL95),
            },
        };
        expect_refused("RV3-B14", "the honest receipt under a statement with the own shift moved to layer 0", &["token I/O wire: this segment belongs to another run", "construction"], res);
    }
    // streaming: the verifier handed layer 0's block at stage 1
    {
        let r = verify_token_run_with(&st, &mut WrongAt { blocks: &e.blocks, wrong: (1, 0) }, &e.tables, &segs, POL95);
        expect_refused("RV3-B15", "the verifier handed layer 0's block at stage 1 (8B)", &["ruling CS-6"], r);
    }
}

// =================================================================== C: the full trained R3 statement

fn unhex(s: &str) -> Digest {
    let mut d = [0u8; 32];
    for i in 0..32 {
        d[i] = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).unwrap();
    }
    d
}

/// RV3-C1: the lane's saved TRAINED receipt (token 11, 34 segments)
/// re-verified by MY binary in this fresh process (blocks streamed from the
/// b7 export and digest-checked, the trained tables through the SHA-checked
/// loader, roots and context from statement.txt), an independent recount of
/// its whole-run figure, and probes.
#[test]
#[ignore]
fn rv3_c1_the_saved_trained_receipt_and_its_probes() {
    let t_load = std::time::Instant::now();
    let e = load8(0);
    let load_s = t_load.elapsed().as_secs_f64();
    let dir = std::path::PathBuf::from(LANE_R3_TRAINED);
    let stmt = std::fs::read_to_string(dir.join("statement.txt")).unwrap();
    let field = |k: &str| stmt.lines().find_map(|l| l.strip_prefix(&format!("{k} "))).unwrap_or_else(|| panic!("{k} missing")).to_string();
    assert_eq!(field("final_norm"), "g0 127 cn 4234 tn 9 ceps 78617");
    let ctx_t = unhex(&field("context"));
    assert_eq!(ctx_t, r3_context("ho00", "trained"));
    let roots = (unhex(&field("input_root")), unhex(&field("output_root")));
    let model = model8(&e, 32, e.records.clone()).unwrap();
    assert_eq!(field("trained_statement_identity"), hex(&model.identity()));
    let st = st8(&e, 32, &model, R3_TRAINED_NORM, R3_BOS, ctx_t, roots, &e.tables).unwrap();
    assert_eq!(field("parameter_line"), st.parameter_line().unwrap(), "the saved run is another statement");
    let own: Vec<(usize, u32)> = (0..32).filter_map(|k| st.stage_shape(k).ok().filter(|s| s.sh_s != e.sh.sh_s).map(|s| (k, s.sh_s))).collect();
    eprintln!("REVIEW-R3 TRAINED STATEMENT | run sh_s {} | stages at their own shift: {own:?} | digest pass + tables {load_s:.1} s", e.sh.sh_s);
    let segs: Vec<Vec<u8>> = (0..34).map(|k| std::fs::read(dir.join(format!("segment_{k:03}.bin"))).unwrap()).collect();
    let t0 = std::time::Instant::now();
    verify_token_run_with(&st, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &segs, POL95).unwrap_or_else(|er| panic!("REVIEW-R3: the saved trained receipt does NOT verify in a fresh process: {er}"));
    let vs = t0.elapsed().as_secs_f64();
    // independent recount of the derived figure from its documented pieces
    let tp = &st.tp;
    let w = st.whole_run().clone();
    let t = tp.tier;
    let sh = &e.sh;
    let mut col: Vec<f64> = vec![t.per_opening_log2(t.stage_log_n, t.stage_inv_rate); 4];
    col.extend(vec![mask_opening_log2(); 2 + 32]);
    col.extend(vec![t.per_opening_log2(t.ep_log_n, t.ep_inv_rate); 2]);
    col.extend(vec![hiding_opening_log2(sh.log_cols, sh.inv_rate, sh.opened_cols); 64]);
    col.extend(vec![hiding_opening_log2(sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols); 33]);
    let column: f64 = col.iter().map(|x| x.exp2()).sum();
    let (bn, br) = block_logup_size(sh);
    let (on, or) = stage_out::logup_size(&stage_out::layout(sh, tp), tp);
    let (inn, inr) = stage_in::logup_size(&stage_in::layout(sh, tp), tp);
    let lg = (tp.d_pad.trailing_zeros()) as u128;
    let num = 32.0 * (bn + 3 * br - 1) as f64 + (on + 3 * or - 1) as f64 + (inn + inr * (2 + lg) + 32 * lg) as f64;
    let logup = num * (-2.0 * (P as f64).log2()).exp2();
    let omitted = 137.0 * (-113.0f64).exp2() + 34.0 * (-117.2f64).exp2();
    let total = (column + logup + omitted).log2();
    eprintln!(
        "REVIEW-R3 FRESH-PROCESS VERIFY trained-ho00 | accepted from the saved bytes ({} B) in {vs:.1} s under a 95-bit policy | code: {} openings, column 2^{:.3}, logup 2^{:.3}, omitted 2^{:.3}, total 2^{:.3}, floor {} | my recount: {} openings, column 2^{:.3}, logup 2^{:.3} (block N {bn}, stage OUT N {on}, stage IN N {inn} R {inr}), omitted 2^{:.3}, total 2^{:.3}, floor {}, margin to the floor {:.3} bits [MEASURED / COUNTED]",
        segs.iter().map(|s| s.len()).sum::<usize>(),
        w.openings,
        w.column_log2,
        w.logup_log2,
        w.omitted_log2,
        w.total_log2,
        w.floor_bits,
        col.len(),
        column.log2(),
        logup.log2(),
        omitted.log2(),
        total,
        (-total).floor(),
        -total - (-total).floor()
    );
    assert_eq!(col.len(), w.openings, "the opening count");
    assert!((total - w.total_log2).abs() < 1e-9, "the recount differs from the code's figure");
    assert_eq!(w.floor_bits, 97);
    verify_token_run_with(&st, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &[], VerifierPolicy { min_whole_run_bits: 97 }).map(|_| ()).err().map(|er| assert!(!er.contains("below the verifier's minimum"), "a 97-bit policy refused the 97-bit statement: {er}"));
    expect_refused("RV3-C1a", "a 98-bit policy (no segments: refused before any segment)", &["below the verifier's minimum"], verify_token_run_with(&st, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &[], VerifierPolicy { min_whole_run_bits: 98 }));
    let free = st8(&e, 32, &model, FinalNorm { cn: 512, ..R3_TRAINED_NORM }, R3_BOS, ctx_t, roots, &e.tables).unwrap();
    expect_refused("RV3-C1b", "the refusal-free Cn 512 instead of the calibrated 4,234", &["token I/O wire: this segment belongs to another run"], verify_token_run_with(&free, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &segs, POL95));
    let mut r = e.records.clone();
    for x in r.iter_mut() {
        x.sh_s = None;
    }
    let m_wide = model8(&e, 32, r).unwrap();
    let wide = st8(&e, 32, &m_wide, R3_TRAINED_NORM, R3_BOS, ctx_t, roots, &e.tables).unwrap();
    expect_refused("RV3-C1c", "every layer at the run-wide score shift (layer 1's own dropped)", &["token I/O wire: this segment belongs to another run"], verify_token_run_with(&wide, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &segs, POL95));
    let bos1 = st8(&e, 32, &model, R3_TRAINED_NORM, 1, ctx_t, roots, &e.tables).unwrap();
    expect_refused("RV3-C1d", "BOS 1 (TinyLlama's) instead of 128,000", &["token I/O wire: this segment belongs to another run"], verify_token_run_with(&bos1, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &segs, POL95));
    let mut t2 = e.tables.clone();
    t2.mult[128_255] = if t2.mult[128_255] == 4096 { 4095 } else { t2.mult[128_255] + 1 };
    let st_t2 = st8(&e, 32, &model, R3_TRAINED_NORM, R3_BOS, ctx_t, roots, &t2).unwrap();
    expect_refused("RV3-C1e", "a verifier whose head has one multiplier changed (row 128,255)", &["token I/O wire: this segment belongs to another run"], verify_token_run_with(&st_t2, &mut Stream8 { e: &e, cur: None, wrong: None }, &t2, &segs, POL95));
    drop(t2);
    let generic_ctx = st8(&e, 32, &model, R3_TRAINED_NORM, R3_BOS, r3_context("ho00", "generic"), roots, &e.tables).unwrap();
    expect_refused("RV3-C1f", "the generic run's context", &["token I/O wire: this segment belongs to another run"], verify_token_run_with(&generic_ctx, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &segs, POL95));
    expect_refused("RV3-C1g", "the verifier's block source hands layer 0's block at stage 5", &["ruling CS-6"], verify_token_run_with(&st, &mut Stream8 { e: &e, cur: None, wrong: Some((5, 0)) }, &e.tables, &segs, POL95));
    let mut s2 = segs.clone();
    s2.swap(10, 11);
    expect_refused("RV3-C1h", "block segments 10 and 11 swapped", &["private run wire"], verify_token_run_with(&st, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &s2, POL95));
    let mut s3 = segs.clone();
    let at = s3[33].len() / 3;
    s3[33][at] ^= 0x04;
    expect_refused("RV3-C1i", "one bit flipped in stage OUT's segment", &["stage OUT", "token I/O", "pcs", "output token endpoint", "B_out"], verify_token_run_with(&st, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &s3, POL95));
}

/// RV3-C2: one forgery at the FULL trained R3 statement (32 trained layers
/// streamed, the trained tables, Cn 4,234): A6-only at the best non-maximal
/// id of another vocabulary row.
#[test]
#[ignore]
fn rv3_c2_a_full_scale_trained_r3_forgery() {
    let e = load8(0);
    let tokens = seq_tokens(&e.ex, "ho00");
    let tp = TokenProfile::new(&e.sh, &e.tables, R3_BOS, R3_TRAINED_NORM, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    let model = model8(&e, 32, e.records.clone()).unwrap();
    let (wit_in, b_in, in_plane) = stage_in::honest_inputs(&tp, &e.tables, &tokens).unwrap();
    assert_eq!(unpad(&e.sh, &b_in), e.ex.load_seq(&e.sh, "ho00", e.layers[0]).unwrap().0, "B_in is not x_in_L00");
    let b_out = pad_plane(&e.sh, &e.ex.load_seq(&e.sh, "ho00", e.layers[31]).unwrap().1);
    let (ov, mut wout, _) = out8(&tp, &e.tables, &b_out, tp.tokens - 1, true).unwrap();
    assert_eq!(ov.tok, 11, "the honest next token is not the lane's 11");
    let l = ov.logits.clone();
    let j = ov.tok;
    let max = l[j];
    let row = 1usize << tp.tier.stage_log_n;
    let j2 = (0..tp.v).filter(|i| i / row != j / row && l[*i] < max).max_by_key(|i| (l[*i], std::cmp::Reverse(*i))).unwrap();
    set_argmax(&tp, &mut wout, &[(j2, Fp::ONE)], Fp::new(j2 as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, j2));
    let out_plane = stage_out::endpoint_plane(&tp, j2 as u64);
    let ctx_f = *blake3::hash(b"review round 3: full-scale trained forgery").as_bytes();
    let (ins, outs) = endpoint_specs(&e.sh, ctx_f, &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &in_plane, &out_plane, &e.sh.hash_tag()).unwrap();
    let st = st8(&e, 32, &model, R3_TRAINED_NORM, R3_BOS, ctx_f, roots, &e.tables).unwrap();
    let mut src = SrcFull { e: &e, seq: "ho00".into(), stage_in: Some((wit_in, b_in)), stage_out: Some(wout) };
    let mut segs = Vec::new();
    let t0 = std::time::Instant::now();
    {
        let _c = CheatingProver::on();
        prove_token_run_with(&st, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &mut src, owners, &mut |_, b| {
            segs.push(b);
            Ok(())
        })
        .unwrap_or_else(|er| panic!("the cheating prover did not produce a receipt: {er}"));
    }
    let ps = t0.elapsed().as_secs_f64();
    let r = verify_token_run_with(&st, &mut Stream8 { e: &e, cur: None, wrong: None }, &e.tables, &segs, POL95);
    eprintln!("REVIEW-R3 timing: the full-scale forgery proved in {ps:.1} s, then verified");
    expect_refused("RV3-C2", &format!("FULL trained R3: A6-only at id {j2} (row {}; honest 11, row {}), M = max + 1", j2 / row, j / row), &["stage OUT slot 07 "], r);
}

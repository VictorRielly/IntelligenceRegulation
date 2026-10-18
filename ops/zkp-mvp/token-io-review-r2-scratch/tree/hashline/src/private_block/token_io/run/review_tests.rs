//! **INDEPENDENT ADVERSARIAL REVIEW, ROUND 2 (2026-10-18): the TR fixes and
//! rung R2 (TinyLlama-1.1B, 22 trained blocks, T32).** TEST CODE ONLY, in the
//! reviewer's SCRATCH copy only. A child of `token_io::run`.
//!
//! * `rv2_a*` (synthetic R1 rung, cheap): the round-1 probes re-run against
//!   the fixes (TR-1..TR-5), and the whole-run figure's binding.
//! * `rv2_b*` (`#[ignore]`, guarded): R2's real tables (32,000 x 2,048
//!   embedding, per-row head with 12-bit multipliers), the TinyLlama token
//!   profile and multi-row stage planes, over the export's FIRST TWO trained
//!   layers (a consecutive-prefix trained statement), so each forgery costs
//!   seconds: the multi-row and boundary forgeries.
//! * `rv2_c*` (`#[ignore]`, guarded): the full 22-layer R2 statement: the
//!   lane's saved ho00 receipt re-verified in this fresh process with probes,
//!   and two full-scale forgeries.
//!
//! `REVIEW-R2 CONTROL` lines must be refused where predicted (asserted);
//! `REVIEW-R2 FINDING` lines are printed demonstrations. Public calibration
//! data and public tables only. No privacy claim.

use super::*;
use super::super::super::protocol::CheatingProver;
use super::super::super::run::{RUN_PROFILE_TOKEN_IO_RUNG_TC, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32};
use super::super::super::trained_block::{sha256, TrainedExport};
use super::super::super::trained_statement::{IntegerCalibration, LayerRecord, Provenance};
use super::super::tests::{ctx, fx_generic, honest, profile, statement, Fx, R2_NORM};

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
            eprintln!("REVIEW-R2 CONTROL {id} | {what} | predicted {predicted:?} | actual: ACCEPTED | A FORGERY VERIFIED");
            panic!("REVIEW-R2 {id} ({what}): A FORGERY VERIFIED");
        }
        Err(e) => {
            let hit = predicted.iter().any(|p| e.starts_with(p) || e.contains(p));
            eprintln!("REVIEW-R2 CONTROL {id} | {what} | predicted {predicted:?} | actual: {} | {}", e.chars().take(180).collect::<String>(), if hit { "AS PREDICTED" } else { "NOT AS PREDICTED" });
            assert!(hit, "REVIEW-R2 {id} ({what}) was refused elsewhere than predicted {predicted:?}: {e}");
        }
    }
}

fn finding(id: &str, what: &str, out: &str) {
    eprintln!("REVIEW-R2 FINDING {id} | {what} | {out}");
}

fn bump(v: i16) -> i16 {
    if v < i16::MAX { v + 1 } else { v - 1 }
}

/// `prove_token_run` without its one variant refusal (a forger's prover)
fn prove_without_the_variant_check(st: &TokenRunStatement, blocks: &[BlockPublic], tables: &TokenTables, src: &mut dyn TokenRunSource, owners: TokenOwners) -> Result<Vec<Vec<u8>>, String> {
    let (sh, l, tp) = (st.sh(), st.l(), &st.tp);
    let mut rng = ZkRng::from_os(&super::super::super::hash_domain::run_seed_domain(st.rs.profile())).map_err(|e| format!("randomness: {e}"))?;
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.ntt_log());
    let mut tr = st.transcript()?;
    let binding = tr.state();
    let TokenOwners { input: in_ep, output: out_ep } = owners;
    let mut segs = Vec::new();
    let start = position_tag(&tr);
    let (win, b_in_plane) = src.stage_in()?;
    let in_lay = stage_in::layout(sh, tp);
    let b0 = st.boundary_spec(0)?;
    let inp = stage_in::prove(&in_lay, tp, tables, win, &b0, &b_in_plane, in_ep, &ntt, &mut rng, &mut tr, &tag)?;
    let end = position_tag(&tr);
    segs.push(st.in_geom(&in_lay).encode(&inp.seg, &binding, &start, &end)?);
    let mut pending: Vec<ZClaim> = inp.pending_b;
    let mut prev: (BoundarySpec, PreparedBoundary) = (b0, inp.b_owner);
    for k in 0..l {
        let mut ph = timing::Phases::start();
        let mut phases: Vec<(&'static str, f64)> = Vec::new();
        let mut tick = std::time::Instant::now();
        let start = position_tag(&tr);
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let spec = st.boundary_spec(k + 1)?;
        let plane = src.boundary_plane(k)?;
        let words: Vec<Fp> = plane.iter().map(|x| Fp::from_i64(i64::from(*x))).collect();
        let cur = boundary::prepare(&spec, &words, &ntt, &mut rng, &tag)?;
        protocol::absorb_root(&mut tr, b"B", &cur.root(), spec.commitment_rows(), spec.log_n());
        let lay = st.block_layout(k)?;
        let wit = src.witness(k)?;
        let core = protocol::prove_core(sh, &lay, &blocks[k], wit, [prev.1.data(), cur.data()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)?;
        let [ic, oc] = core.io_claims;
        let mut claims = std::mem::take(&mut pending);
        claims.extend(ic);
        let (pspec, powner) = prev;
        let in_open = powner.into_opening(&pspec, &claims, &mut tr)?;
        pending = oc;
        let end = position_tag(&tr);
        let seg = Segment { b_root: Some(cur.root()), a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open, in_open, out_open: None };
        segs.push(wire::encode_segment(&seg, &lay, st.block_geom(k)?, &binding, &start, &end)?);
        prev = (spec, cur);
    }
    let start = position_tag(&tr);
    let wout = src.stage_out()?;
    let out_lay = stage_out::layout(sh, tp);
    let (bspec, bowner) = prev;
    let outp = stage_out::prove(&out_lay, tp, tables, wout, &bspec, bowner, pending, out_ep, (l + 1) as u64, &ntt, &mut rng, &mut tr, &tag)?;
    let end = position_tag(&tr);
    segs.push(st.out_geom(&out_lay)?.encode(&outp.seg, &binding, &start, &end)?);
    Ok(segs)
}

fn r1_statement_at(fx: &Fx, roots: (Digest, Digest), tier: Tier) -> Result<TokenRunStatement, String> {
    TokenRunStatement::new(RunShape::new(fx.sh.clone(), fx.blocks.len(), RUN_PROFILE_TOKEN_IO_RUNG_TC)?, ctx(), fx.blocks.iter().map(|b| b.digest()).collect(), &fx.model, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, tier, roots)
}

// =================================================================== A: the TR fixes

/// RV2-A1 (TR-1, TR-2, TR-5): every tier of my round-1 reproduction table
/// (and a stronger unregistered one) is refused at the door AND by the
/// statement constructor; a -128 head word is refused.
#[test]
fn rv2_a1_the_round1_tier_probes_are_refused() {
    let fx = fx_generic();
    let r = Tier::R1_MVP;
    let cases: Vec<(&str, Tier)> = vec![
        ("token endpoints 2^8 rate 1/4 (round-1 TR-1: admitted and verified)", Tier { ep_inv_rate: 4, ..r }),
        ("token endpoints 2^8 rate 1/2 (round-1 TR-1: 2^0, admitted and verified)", Tier { ep_inv_rate: 2, ..r }),
        ("stage commitments at 2^9 (round-1 TR-1)", Tier { stage_log_n: 9, ..r }),
        ("Q = 128 (round-1 TR-2)", Tier { opened_cols: 128, ..r }),
        ("Q = 1 (round-1 TR-2)", Tier { opened_cols: 1, ..r }),
        ("stage 2^13 (stronger levers, not registered)", Tier { stage_log_n: 13, ..r }),
        ("lookup field F_p^3", Tier { lookup_ext_degree: 3, ..r }),
    ];
    for (what, t) in cases {
        let door = t.check();
        let st = r1_statement_at(&fx, ([1; 32], [2; 32]), t).map(|_| ());
        eprintln!("REVIEW-R2 CONTROL RV2-A1 | {what} | door: {} | statement: {} | {}", outcome(&door), outcome(&st), if door.is_err() && st.is_err() { "AS PREDICTED" } else { "NOT AS PREDICTED" });
        assert!(door.is_err() && st.is_err(), "REVIEW-R2 RV2-A1: {what} was admitted");
    }
    r1_statement_at(&fx, ([1; 32], [2; 32]), r).expect("the registered tier builds");
    let mut f2 = fx_generic();
    f2.tables.head[123] = -128;
    let e = TokenProfile::new(&f2.sh, &f2.tables, f2.bos, f2.norm, SelectorVariant::PublicRow, r).map(|_| ());
    eprintln!("REVIEW-R2 CONTROL RV2-A1 | a -128 head word (round-1 TR-5) | {} | {}", outcome(&e), if e.is_err() { "AS PREDICTED" } else { "NOT AS PREDICTED" });
    assert!(e.is_err());
}

/// RV2-A2 (TR-3): a FORGED receipt made with the public-row construction under
/// a statement relabelled to P or F around every door (the forger's prover
/// skips the variant refusal): the verifier refuses the statement by name.
#[test]
fn rv2_a2_an_unbuilt_variant_is_refused_by_the_verifier_even_for_a_forged_receipt() {
    let fx = fx_generic();
    let tp = profile(&fx);
    for v in [SelectorVariant::SealedInInput, SelectorVariant::SealedInOutput] {
        let mut pipe = honest(&fx, &tp);
        let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
        let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
        let mut st = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
        st.tp.variant = v;
        let segs = prove_without_the_variant_check(&st, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners).expect("the forger's prover");
        expect_refused("RV2-A2", &format!("a public-row receipt proved under a statement relabelled {}", v.tag()), &["token I/O run: the "], verify_token_run(&st, &fx.blocks, &fx.tables, &segs, POL93));
    }
}

/// RV2-A3 (TR-4): my round-1 owner probe (planes sealed by the real specs,
/// rebuilding their roots) against the real owner checks; and the honest
/// decommitments presented to the wrong owner or under another statement.
#[test]
fn rv2_a3_the_owner_checks_refuse_the_round1_planes() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let tag = fx.sh.hash_tag();
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let mut bad_in = vec![Fp::ZERO; tp.in_ep_words()];
    let mut prompt = fx.tokens.clone();
    for (t, id) in prompt.iter().enumerate() {
        bad_in[t] = Fp::new(*id);
    }
    bad_in[0] = Fp::new(tp.bos + 1);
    prompt[0] = tp.bos + 1;
    bad_in[tp.tokens + 3] = Fp::new(9);
    let mut bad_out = vec![Fp::ZERO; tp.out_ep_words()];
    bad_out[0] = Fp::new(tp.v as u64 + 5);
    bad_out[1] = Fp::new(4);
    let (roots, owners) = seal_endpoints(&ins, &outs, &bad_in, &bad_out, &tag).unwrap();
    let st = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
    let (di, dout) = (Decommitment::of(&owners.input), Decommitment::of(&owners.output));
    expect_refused("RV2-A3", "input owner: non-BOS position 0 (the prompt agrees) and a nonzero pad word", &["owner check: "], owner_check_input(&st, &di, &prompt));
    expect_refused("RV2-A3", "output owner: an id >= V and a nonzero pad word", &["owner check: "], owner_check_output(&st, &dout).map(|_| ()));
    // honest decommitments: to the wrong owner, and under another run's statement
    let pipe = honest(&fx, &tp);
    let (roots2, owners2) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &tag).unwrap();
    let st2 = statement(&fx, roots2, SelectorVariant::PublicRow).unwrap();
    let (hi, ho) = (Decommitment::of(&owners2.input), Decommitment::of(&owners2.output));
    owner_check_input(&st2, &hi, &fx.tokens).expect("the honest input decommitment");
    assert_eq!(owner_check_output(&st2, &ho).unwrap(), pipe.out_values.tok);
    expect_refused("RV2-A3", "the input decommitment presented to the output owner", &["owner check: "], owner_check_output(&st2, &hi).map(|_| ()));
    expect_refused("RV2-A3", "an honest output decommitment under another run's statement", &["owner check: "], owner_check_output(&st, &ho).map(|_| ()));
}

/// RV2-A4 (TR-1, D27): can a statement claim a higher whole-run figure than
/// its levers give? The figure is derived inside `TokenRunStatement::new` and
/// bound through the parameter line: a prover that inflates it changes its
/// own transcript, and the verifier's own statement (re-derived) refuses the
/// receipt. A verifier would accept the inflated figure only if handed the
/// mutated statement itself (a `pub(crate)` field), never from bytes.
#[test]
fn rv2_a4_an_inflated_whole_run_figure_does_not_verify() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
    let mut claim = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
    assert_eq!(claim.whole_run.floor_bits, 93);
    claim.whole_run.floor_bits = 120;
    let mut segs = Vec::new();
    prove_token_run(&claim, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the inflating prover");
    let honest_st = statement(&fx, roots, SelectorVariant::PublicRow).unwrap();
    expect_refused("RV2-A4", "receipt proved under a statement claiming 120 bits, verified under the verifier's own (93) at a 93-bit policy", &["token I/O wire: this segment belongs to another run"], verify_token_run(&honest_st, &fx.blocks, &fx.tables, &segs, POL93));
    expect_refused("RV2-A4", "the same receipt under a 120-bit policy (the verifier's own figure is 93)", &["below the verifier's minimum"], verify_token_run(&honest_st, &fx.blocks, &fx.tables, &segs, VerifierPolicy { min_whole_run_bits: 120 }));
    let r = verify_token_run(&claim, &fx.blocks, &fx.tables, &segs, VerifierPolicy { min_whole_run_bits: 120 });
    finding("TR2-figure", "the inflated statement OBJECT itself (a pub(crate) field mutated in-process) handed to the verifier at a 120-bit policy", &outcome(&r));
}

// =================================================================== R2 fixtures (real export)

const EXPORT: &str = "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128";
const INPUTS: &str = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r2_inputs";
const LANE_R2_RUNS: &str = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/runs/r2";
const EMB_SHA256: &str = "ad68c716693f12d17cd19c957fbe84ca0f94d79063735f7eb84ead8063d9ab06";
const HEAD_SHA256: &str = "b99cbec5f457e47ca2441de517135ba1bd1870e2ae8abe2038dbd84617436280";
const MULT_SHA256: &str = "7824019e82a62fd6e36c165b9aabfd3711d03b815731e298b356a734a7ea663f";

struct R2 {
    ex: TrainedExport,
    sh: Shape,
    blocks: Vec<BlockPublic>,
    records: Vec<LayerRecord>,
    cal: IntegerCalibration,
    model: TrainedModelStatement,
    tables: TokenTables,
}

fn read_checked(path: &std::path::Path, want: &str) -> Vec<u8> {
    let b = std::fs::read(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    assert_eq!(hex(&sha256(&b)), want, "{}: not the recorded table", path.display());
    b
}

/// the export's first `n` trained layers (a consecutive-prefix trained
/// statement under the R2 token profile), the R2 tables
fn load(n: usize) -> R2 {
    let export = std::path::PathBuf::from(EXPORT);
    let inputs = std::path::PathBuf::from(INPUTS);
    let ex = TrainedExport::load(&export).unwrap_or_else(|e| panic!("the export: {e}"));
    let layers = ex.layers.clone();
    assert_eq!(layers.len(), 22);
    let c = ex.run_constants(&layers).unwrap();
    let sh = ex.shape_for(&c).unwrap();
    let mut blocks = Vec::with_capacity(n);
    let mut records = Vec::with_capacity(n);
    for &k in layers.iter().take(n) {
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
    let model = TrainedModelStatement::new(&sh, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32, ex.source.clone(), cal.clone(), records.clone()).unwrap_or_else(|e| panic!("the prefix trained statement: {e}"));
    let emb: Vec<i16> = read_checked(&export.join("embedding_int16.bin"), EMB_SHA256).chunks_exact(2).map(|c| i16::from_le_bytes([c[0], c[1]])).collect();
    let head: Vec<i8> = read_checked(&inputs.join("head_int8_perrow.bin"), HEAD_SHA256).into_iter().map(|b| b as i8).collect();
    let mult: Vec<i64> = read_checked(&inputs.join("head_mult12.bin"), MULT_SHA256).chunks_exact(8).map(|c| i64::from_le_bytes(c.try_into().unwrap())).collect();
    let tables = TokenTables::new(32_000, 2048, emb, head, mult).unwrap();
    R2 { ex, sh, blocks, records, cal, model, tables }
}

fn seq_tokens(ex: &TrainedExport, seq: &str) -> Vec<u64> {
    let m = std::fs::read_to_string(ex.dir.join(format!("seq_{seq}")).join("manifest.json")).unwrap();
    let at = m.find("\"token_ids\"").expect("token_ids") + "\"token_ids\"".len();
    let open = at + m[at..].find('[').unwrap() + 1;
    let close = open + m[open..].find(']').unwrap();
    m[open..close].split(',').map(|x| x.trim().parse::<u64>().expect("a token id")).collect()
}

fn r2_context(seq: &str) -> Digest {
    let mut b = b"token I/O R2: TinyLlama-1.1B T32 public-row run context, sequence ".to_vec();
    b.extend_from_slice(seq.as_bytes());
    *blake3::hash(&b).as_bytes()
}

fn unpad(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect()
}

fn chain(sh: &Shape, blocks: &[BlockPublic], x0: &[i16]) -> Result<Vec<Vec<i16>>, String> {
    let ids = Ids::new(sh)?;
    let mut x = x0.to_vec();
    let mut planes = Vec::with_capacity(blocks.len());
    for (k, blk) in blocks.iter().enumerate() {
        let w = super::super::super::witness::build_shaped(sh, blk.attention(), blk.feed_forward(), &x).map_err(|e| format!("block {k}: {e}"))?;
        let plane: Vec<i16> = w.planes[ids.at(A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| "a block output outside int16".to_string())).collect::<Result<_, _>>()?;
        x = unpad(sh, &plane);
        planes.push(plane);
    }
    Ok(planes)
}

#[derive(Clone)]
struct Pipe {
    stage_in: StageInWitness,
    b_in: Vec<i16>,
    /// block 0's input when a forger runs it on something other than B_in
    x0: Option<Vec<i16>>,
    planes: Vec<Vec<i16>>,
    out_values: OutValues,
    stage_out: StageOutWitness,
    in_plane: Vec<Fp>,
    out_plane: Vec<Fp>,
}

fn out_of(tp: &TokenProfile, tables: &TokenTables, b_out: &[i16], row: usize, check: bool) -> Result<(OutValues, StageOutWitness, Vec<Fp>), String> {
    let ov = stage_out::out_values(tp, tables, &stage_out::row_of(tp, b_out, row), check)?;
    let w = stage_out::witness_from_values(tp, &ov)?;
    let ep = stage_out::endpoint_plane(tp, ov.tok as u64);
    Ok((ov, w, ep))
}

fn pipeline(r2: &R2, tp: &TokenProfile, tokens: &[u64], check: bool) -> Result<Pipe, String> {
    let (stage_in, b_in, in_plane) = stage_in::honest_inputs(tp, &r2.tables, tokens)?;
    let planes = chain(&r2.sh, &r2.blocks, &unpad(&r2.sh, &b_in))?;
    let (out_values, stage_out, out_plane) = out_of(tp, &r2.tables, planes.last().unwrap(), tp.tokens - 1, check)?;
    Ok(Pipe { stage_in, b_in, x0: None, planes, out_values, stage_out, in_plane, out_plane })
}

/// everything downstream of a new B_in, as a consistent forger would
fn rebuild_from_b_in(r2: &R2, tp: &TokenProfile, p: &mut Pipe, b_in: Vec<i16>) {
    p.planes = chain(&r2.sh, &r2.blocks, &unpad(&r2.sh, &b_in)).unwrap();
    let (ov, w, ep) = out_of(tp, &r2.tables, p.planes.last().unwrap(), tp.tokens - 1, false).unwrap();
    p.out_values = ov;
    p.stage_out = w;
    p.out_plane = ep;
    p.b_in = b_in;
}

struct Stream<'a> {
    sh: &'a Shape,
    blocks: &'a [BlockPublic],
    pipe: &'a Pipe,
}

impl TokenRunSource for Stream<'_> {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        Ok((self.pipe.stage_in.clone(), self.pipe.b_in.clone()))
    }
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        let x = if k == 0 { self.pipe.x0.clone().unwrap_or_else(|| unpad(self.sh, &self.pipe.b_in)) } else { unpad(self.sh, &self.pipe.planes[k - 1]) };
        super::super::super::witness::build_shaped(self.sh, self.blocks[k].attention(), self.blocks[k].feed_forward(), &x)
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.pipe.planes.get(k).cloned().ok_or_else(|| format!("no plane after block {k}"))
    }
    fn stage_out(&mut self) -> Result<StageOutWitness, String> {
        Ok(self.pipe.stage_out.clone())
    }
}

fn r2_statement(r2: &R2, l: usize, model: &TrainedModelStatement, tp_norm: FinalNorm, ctx: Digest, roots: (Digest, Digest)) -> Result<TokenRunStatement, String> {
    let digests: Vec<Digest> = r2.blocks.iter().take(l).map(|b| b.digest()).collect();
    TokenRunStatement::new(RunShape::new(r2.sh.clone(), l, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32)?, ctx, digests, model, &r2.tables, 1, tp_norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots)
}

fn prove_r2(r2: &R2, tp: &TokenProfile, pipe: &Pipe, ctx: Digest, cheat: bool) -> Result<(TokenRunStatement, Vec<Vec<u8>>, OwnerHandoff), String> {
    let (ins, outs) = endpoint_specs(&r2.sh, ctx, tp)?;
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &r2.sh.hash_tag())?;
    let st = r2_statement(r2, r2.blocks.len(), &r2.model, tp.norm, ctx, roots)?;
    let mut segs = Vec::new();
    let mut src = Stream { sh: &r2.sh, blocks: &r2.blocks, pipe };
    let res = {
        let _cheat = if cheat { Some(CheatingProver::on()) } else { None };
        prove_token_run(&st, &r2.blocks, &r2.tables, &mut src, owners, &mut |_, b| {
            segs.push(b);
            Ok(())
        })
    };
    let (_, hand) = res?;
    Ok((st, segs, hand))
}

fn forge2(r2: &R2, tp: &TokenProfile, pipe: &Pipe, ctx: Digest) -> Result<(), String> {
    let (st, segs, _) = prove_r2(r2, tp, pipe, ctx, true).unwrap_or_else(|e| panic!("the cheating prover did not produce a receipt: {e}"));
    verify_token_run(&st, &r2.blocks, &r2.tables, &segs, POL95)
}

/// rewrite the keyed-argmax planes on the multi-row Vo cube
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

// =================================================================== B: R2 shape, two real layers

/// RV2-B: R2's real tables and profile, multi-row planes (Voc / Vo = 2^15:
/// eight rows of 4,096 per plane), over the export's first two trained
/// layers. D20 on real data, the honest baseline (parity with the export,
/// owner checks), then the multi-row and boundary forgeries.
#[test]
#[ignore]
fn rv2_b_r2_shape_forgeries_on_two_real_layers() {
    let r2 = load(2);
    let tokens = seq_tokens(&r2.ex, "ho00");
    let cal_tp = TokenProfile::new(&r2.sh, &r2.tables, 1, R2_NORM, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    assert_eq!((cal_tp.voc_log(), cal_tp.vo_log(), cal_tp.do_log(), cal_tp.limbs, cal_tp.window_bits), (15, 15, 12, 7, 53));
    // D20 on real data at the calibrated Cn: layer 1's output row 31
    let norm = match pipeline(&r2, &cal_tp, &tokens, true) {
        Ok(p) => {
            eprintln!("REVIEW-R2 D20 | two-layer prefix, ho00 row 31 at Cn 5,664 | admitted (max |y| {})", p.out_values.y.iter().map(|v| v.abs()).max().unwrap());
            R2_NORM
        }
        Err(e) => {
            eprintln!("REVIEW-R2 D20 | two-layer prefix, ho00 row 31 at Cn 5,664 | honest pipeline refused before any commitment: {e:?}");
            assert_eq!(e, "token I/O stage OUT: final norm quotient/remainder (refused, D20)", "the D20 refusal carries data-derived text");
            FinalNorm { cn: 1024, ..R2_NORM }
        }
    };
    let tp = TokenProfile::new(&r2.sh, &r2.tables, 1, norm, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    let base = pipeline(&r2, &tp, &tokens, true).expect("the honest two-layer pipeline");
    for k in 0..2 {
        assert_eq!(unpad(&r2.sh, &base.planes[k]), r2.ex.load_seq(&r2.sh, "ho00", k as u32).unwrap().1, "parity with x_out_L{k:02}");
    }
    let ctx2 = *blake3::hash(b"review round 2: two-layer prefix").as_bytes();
    let t0 = std::time::Instant::now();
    let (st, segs, hand) = prove_r2(&r2, &tp, &base, ctx2, false).expect("the honest two-layer run");
    let ps = t0.elapsed().as_secs_f64();
    verify_token_run(&st, &r2.blocks, &r2.tables, &segs, POL95).expect("the honest two-layer run verifies");
    assert_eq!(segs.iter().map(|s| s.len()).collect::<Vec<_>>(), st.segment_lens().unwrap());
    owner_check_input(&st, &hand.input, &tokens).expect("input owner");
    let tok = owner_check_output(&st, &hand.output).expect("output owner");
    assert_eq!(tok, base.out_values.tok);
    eprintln!("REVIEW-R2 HONEST two-layer R2-shape run: Cn {}, next token {tok}, prove {ps:.1} s, {} B, whole run floor {} bits ({} openings) [MEASURED, shared box, n=1]", norm.cn, segs.iter().map(|s| s.len()).sum::<usize>(), st.whole_run.floor_bits, st.whole_run.openings);
    let l = base.out_values.logits.clone();
    let j = base.out_values.tok;
    let max = l[j];
    let row = 1usize << tp.tier.stage_log_n;
    let inv2v = Fp::new(1u64 << tp.log_v).inv();
    let ep = |id: u64| stage_out::endpoint_plane(&tp, id);
    // F1: e on a padded entry of the last (partial) row, tok = V + 5, M = max + 1
    {
        let mut p = base.clone();
        let pad = tp.v + 5;
        set_argmax(&tp, &mut p.stage_out, &[(pad, Fp::ONE)], Fp::new(pad as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, pad));
        p.out_plane = ep(pad as u64);
        expect_refused("RV2-B1", "e on the padded entry V + 5 (last row), tok = V + 5, M = max + 1", &["stage OUT slot 06 "], forge2(&r2, &tp, &p, ctx2));
    }
    // F2: A6-only at the best non-maximal entry of ANOTHER row than j
    let j2 = (0..tp.v).filter(|i| i / row != j / row && l[*i] < max).max_by_key(|i| (l[*i], std::cmp::Reverse(*i))).unwrap();
    {
        let mut p = base.clone();
        set_argmax(&tp, &mut p.stage_out, &[(j2, Fp::ONE)], Fp::new(j2 as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, j2));
        p.out_plane = ep(j2 as u64);
        expect_refused("RV2-B2", &format!("A6-only: non-maximal j' = {j2} (row {}; honest j = {j}, row {}), M = max + 1, deltas in bytes", j2 / row, j / row), &["stage OUT slot 07 "], forge2(&r2, &tp, &p, ctx2));
    }
    // F3: A3-only: e, delta honest for j; tok' = j +- 4096 (another row) with M = l_j + 2^-v (tok' - j)
    {
        let mut p = base.clone();
        let t3 = if j + row < tp.v { j + row } else { j - row };
        p.stage_out.planes[stage_out::A_TOK][0] = Fp::new(t3 as u64);
        p.stage_out.planes[stage_out::A_M][0] = Fp::from_i64(max).add(inv2v.mul(Fp::from_i64(t3 as i64 - j as i64)));
        p.out_plane = ep(t3 as u64);
        expect_refused("RV2-B3", &format!("A3-only: tok' = {t3} (one row away), M = l_j + 2^-v (tok' - j)"), &["stage OUT slot 07 "], forge2(&r2, &tp, &p, ctx2));
    }
    // F4: stage IN: one count of table row 0 moved to the padded entry V + 1 (tau equal: invisible to LogUp)
    {
        let mut p = base.clone();
        p.stage_in.mult[0] = p.stage_in.mult[0].sub(Fp::ONE);
        p.stage_in.mult[tp.v + 1] = p.stage_in.mult[tp.v + 1].add(Fp::ONE);
        expect_refused("RV2-B4", "stage IN m: one count of row 0 moved to the padded entry V + 1 (eighth row)", &["stage IN slot 02 "], forge2(&r2, &tp, &p, ctx2));
    }
    // F5: a difference limb (a byte) on the LAST entry of the Vo cube (32,767)
    {
        let mut p = base.clone();
        let last = (1usize << tp.vo_log()) - 1;
        p.stage_out.planes[stage_out::A_LAM0][last] = Fp::ONE;
        expect_refused("RV2-B5", "a nonzero delta limb on the last entry of the Vo cube (32,767)", &["stage OUT slot 06 "], forge2(&r2, &tp, &p, ctx2));
    }
    // F6: public row: stage OUT computed from row T - 2 of the 16-row B_out
    {
        let mut p = base.clone();
        let (ov, w, e) = out_of(&tp, &r2.tables, p.planes.last().unwrap(), tp.tokens - 2, false).unwrap();
        p.out_values = ov;
        p.stage_out = w;
        p.out_plane = e;
        expect_refused("RV2-B6", "stage OUT computed from row T - 2 of the multi-row B_out", &["stage OUT slot 00 "], forge2(&r2, &tp, &p, ctx2));
    }
    // F7: x nonzero on the Do lift (entries 2,048..4,095; read by no IO / SS term)
    {
        let mut p = base.clone();
        p.stage_out.planes[stage_out::A_X][tp.d_pad + 9] = Fp::new(3);
        expect_refused("RV2-B7", "x nonzero on the Do lift (entry d_pad + 9)", &["stage OUT slot 05 "], forge2(&r2, &tp, &p, ctx2));
    }
    // F8: a second hot e entry on the last padded entry beside the honest one
    {
        let mut p = base.clone();
        let last = (1usize << tp.vo_log()) - 1;
        p.stage_out.planes[stage_out::A_E][last] = Fp::ONE;
        expect_refused("RV2-B8", "a second hot e on entry 32,767 beside the honest one (A2/A3/A6 sum over supp_V)", &["stage OUT slot 06 "], forge2(&r2, &tp, &p, ctx2));
    }
    // F9: a padded token id V + 11 at position 5, its row the table's row 0, counted on that pad entry
    {
        let mut p = base.clone();
        let mut toks = tokens.clone();
        toks[5] = (tp.v + 11) as u64;
        let mut b = p.b_in.clone();
        b[5 * tp.d_pad..5 * tp.d_pad + tp.d].copy_from_slice(r2.tables.emb_row(0));
        let mut m = vec![Fp::ZERO; 1usize << tp.voc_log()];
        for t in &toks {
            m[*t as usize] = m[*t as usize].add(Fp::ONE);
        }
        p.stage_in.tok[5] = Fp::new(toks[5]);
        p.stage_in.mult = m;
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        rebuild_from_b_in(&r2, &tp, &mut p, b);
        expect_refused("RV2-B9", "a padded token id V + 11 (eighth row) at position 5, row = table row 0, histogram on the pad", &["stage IN slot 02 ", "stage IN H "], forge2(&r2, &tp, &p, ctx2));
    }
    // F10: B_in honest for stage IN, block 0 proved on another input
    {
        let mut p = base.clone();
        let mut x0 = unpad(&r2.sh, &p.b_in);
        x0[3 * tp.d + 17] = bump(x0[3 * tp.d + 17]);
        p.planes = chain(&r2.sh, &r2.blocks, &x0).unwrap();
        let (ov, w, e) = out_of(&tp, &r2.tables, p.planes.last().unwrap(), tp.tokens - 1, false).unwrap();
        p.out_values = ov;
        p.stage_out = w;
        p.out_plane = e;
        p.x0 = Some(x0);
        expect_refused("RV2-B10", "B_in = E[tok] for stage IN, block 0 proved on another input (16-row boundary)", &["block 0", "boundary 0"], forge2(&r2, &tp, &p, ctx2));
    }
    // F11: a consistent re-lookup in A_in under the honest seal: position 7 -> an id of the last Voc row
    {
        let mut p = base.clone();
        let new_id = 31_000u64;
        let mut toks = tokens.clone();
        toks[7] = new_id;
        let mut b = p.b_in.clone();
        b[7 * tp.d_pad..7 * tp.d_pad + tp.d].copy_from_slice(r2.tables.emb_row(new_id as usize));
        let mut m = vec![Fp::ZERO; 1usize << tp.voc_log()];
        for t in &toks {
            m[*t as usize] = m[*t as usize].add(Fp::ONE);
        }
        p.stage_in.tok[7] = Fp::new(new_id);
        p.stage_in.mult = m;
        rebuild_from_b_in(&r2, &tp, &mut p, b);
        expect_refused("RV2-B11", "consistent re-lookup in A_in (position 7 -> id 31,000, row and histogram) under the honest seal", &["stage IN slot 00 "], forge2(&r2, &tp, &p, ctx2));
    }
    // F12: the histogram: one count moved between two REAL ids in different rows (LogUp)
    {
        let mut p = base.clone();
        let from = tokens[3] as usize;
        let to = if from + row < tp.v { from + row } else { from - row };
        p.stage_in.mult[from] = p.stage_in.mult[from].sub(Fp::ONE);
        p.stage_in.mult[to] = p.stage_in.mult[to].add(Fp::ONE);
        expect_refused("RV2-B12", &format!("stage IN m: one count moved from id {from} to id {to} (another row)"), &["stage IN H "], forge2(&r2, &tp, &p, ctx2));
    }
}

// =================================================================== C: the full R2 statement

fn unhex(s: &str) -> Digest {
    let mut d = [0u8; 32];
    for i in 0..32 {
        d[i] = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).unwrap();
    }
    d
}

/// RV2-C1: the lane's saved R2 receipt (ho00, 24 segments) verified by MY
/// binary in this fresh process from the saved bytes (every public input
/// rebuilt from the export and the tables; roots and context read from
/// statement.txt), then probes: policies around the derived figure, and
/// statements changed in one field.
#[test]
#[ignore]
fn rv2_c1_the_saved_r2_receipt_and_its_probes() {
    let r2 = load(22);
    let dir = std::path::PathBuf::from(LANE_R2_RUNS).join("ho00");
    let stmt = std::fs::read_to_string(dir.join("statement.txt")).unwrap();
    let field = |k: &str| stmt.lines().find_map(|l| l.strip_prefix(&format!("{k} "))).unwrap_or_else(|| panic!("{k} missing")).to_string();
    let ctx_ho = unhex(&field("context"));
    assert_eq!(ctx_ho, r2_context("ho00"));
    let roots = (unhex(&field("input_root")), unhex(&field("output_root")));
    let st = r2_statement(&r2, 22, &r2.model, R2_NORM, ctx_ho, roots).unwrap();
    assert_eq!(field("parameter_line"), st.parameter_line().unwrap(), "the saved run is another statement");
    assert_eq!(field("trained_statement_identity"), hex(&r2.model.identity()));
    let segs: Vec<Vec<u8>> = (0..24).map(|k| std::fs::read(dir.join(format!("segment_{k:03}.bin"))).unwrap()).collect();
    let t0 = std::time::Instant::now();
    verify_token_run(&st, &r2.blocks, &r2.tables, &segs, POL95).unwrap_or_else(|e| panic!("REVIEW-R2: the saved R2 receipt does NOT verify in a fresh process: {e}"));
    let vs = t0.elapsed().as_secs_f64();
    let w = &st.whole_run;
    eprintln!(
        "REVIEW-R2 FRESH-PROCESS VERIFY ho00 | accepted from the saved bytes ({} B) in {vs:.1} s under a 95-bit policy | derived whole run: {} openings, column 2^{:.3}, logup 2^{:.3}, total 2^{:.3}, floor {} bits [MEASURED, shared box, n=1]",
        segs.iter().map(|s| s.len()).sum::<usize>(),
        w.openings,
        w.column_log2,
        w.logup_log2,
        w.total_log2,
        w.floor_bits
    );
    verify_token_run(&st, &r2.blocks, &r2.tables, &segs, VerifierPolicy { min_whole_run_bits: 97 }).expect("a 97-bit policy accepts the 97-bit statement");
    expect_refused("RV2-C1a", "a 98-bit policy (the statement derives 97)", &["below the verifier's minimum"], verify_token_run(&st, &r2.blocks, &r2.tables, &segs, VerifierPolicy { min_whole_run_bits: 98 }));
    expect_refused("RV2-C1b", "a 98-bit policy with NO segments (refused before any segment is read)", &["below the verifier's minimum"], verify_token_run(&st, &r2.blocks, &r2.tables, &[], VerifierPolicy { min_whole_run_bits: 98 }));
    // statements changed in one field
    let mut inflated = r2_statement(&r2, 22, &r2.model, R2_NORM, ctx_ho, roots).unwrap();
    inflated.whole_run.floor_bits = 120;
    expect_refused("RV2-C1c", "a statement whose whole-run figure is set to 120 bits (bound through the parameter line)", &["token I/O wire: this segment belongs to another run"], verify_token_run(&inflated, &r2.blocks, &r2.tables, &segs, POL95));
    let free = r2_statement(&r2, 22, &r2.model, FinalNorm { cn: 1024, ..R2_NORM }, ctx_ho, roots).unwrap();
    expect_refused("RV2-C1d", "the refusal-free Cn 1,024 instead of the calibrated 5,664", &["token I/O wire: this segment belongs to another run"], verify_token_run(&free, &r2.blocks, &r2.tables, &segs, POL95));
    let other = r2_statement(&r2, 22, &r2.model, R2_NORM, r2_context("ho36"), roots).unwrap();
    expect_refused("RV2-C1e", "another sequence's context (ho36)", &["token I/O wire: this segment belongs to another run"], verify_token_run(&other, &r2.blocks, &r2.tables, &segs, POL95));
    let swapped = r2_statement(&r2, 22, &r2.model, R2_NORM, ctx_ho, (roots.1, roots.0)).unwrap();
    expect_refused("RV2-C1f", "the two token roots swapped", &["token I/O wire: this segment belongs to another run"], verify_token_run(&swapped, &r2.blocks, &r2.tables, &segs, POL95));
    let m21 = TrainedModelStatement::new(&r2.sh, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32, r2.ex.source.clone(), r2.cal.clone(), r2.records[..21].to_vec()).unwrap();
    let pre = r2_statement(&r2, 21, &m21, R2_NORM, ctx_ho, roots).unwrap();
    expect_refused("RV2-C1g", "a 21-layer prefix statement over the 22-layer receipt", &["token I/O run: 21 blocks and 24 segments", "token I/O"], verify_token_run(&pre, &r2.blocks[..21], &r2.tables, &segs, POL95));
    let mut s2 = segs.clone();
    s2.swap(5, 6);
    expect_refused("RV2-C1h", "block segments 5 and 6 swapped", &["private run wire"], verify_token_run(&st, &r2.blocks, &r2.tables, &s2, POL95));
    let mut s3 = segs.clone();
    let at = s3[0].len() / 3;
    s3[0][at] ^= 0x10;
    expect_refused("RV2-C1i", "one bit flipped in stage IN's segment", &["stage IN", "token I/O", "pcs", "input token endpoint", "boundary", "block", "private"], verify_token_run(&st, &r2.blocks, &r2.tables, &s3, POL95));
    let tbl = load_tables_with_mult_bump(&r2);
    let st_t = TokenRunStatement::new(RunShape::new(r2.sh.clone(), 22, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32).unwrap(), ctx_ho, r2.blocks.iter().map(|b| b.digest()).collect(), &r2.model, &tbl, 1, R2_NORM, SelectorVariant::PublicRow, Tier::R1_MVP, roots).unwrap();
    expect_refused("RV2-C1j", "a verifier configured with one head multiplier changed (31,999's m_j)", &["token I/O wire: this segment belongs to another run"], verify_token_run(&st_t, &r2.blocks, &tbl, &segs, POL95));
}

fn load_tables_with_mult_bump(r2: &R2) -> TokenTables {
    let mut t = r2.tables.clone();
    let last = t.v - 1;
    t.mult[last] = if t.mult[last] == 4096 { 4095 } else { t.mult[last] + 1 };
    t
}

/// RV2-C2: two forgeries at the FULL R2 statement (22 trained layers, the
/// calibrated Cn, ho00): A6-only across vocabulary rows, and the histogram
/// moved onto a padded table entry (invisible to LogUp).
#[test]
#[ignore]
fn rv2_c2_full_scale_r2_forgeries() {
    let r2 = load(22);
    let tokens = seq_tokens(&r2.ex, "ho00");
    let tp = TokenProfile::new(&r2.sh, &r2.tables, 1, R2_NORM, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap();
    let base = pipeline(&r2, &tp, &tokens, true).expect("the honest 22-layer pipeline");
    assert_eq!(unpad(&r2.sh, base.planes.last().unwrap()), r2.ex.load_seq(&r2.sh, "ho00", 21).unwrap().1, "parity with x_out_L21");
    assert_eq!(base.out_values.tok, 29914, "the honest next token is not the lane's");
    let ctx_f = *blake3::hash(b"review round 2: full-scale forgeries").as_bytes();
    let l = base.out_values.logits.clone();
    let j = base.out_values.tok;
    let max = l[j];
    let row = 1usize << tp.tier.stage_log_n;
    let ep = |id: u64| stage_out::endpoint_plane(&tp, id);
    let j2 = (0..tp.v).filter(|i| i / row != j / row && l[*i] < max).max_by_key(|i| (l[*i], std::cmp::Reverse(*i))).unwrap();
    {
        let mut p = base.clone();
        set_argmax(&tp, &mut p.stage_out, &[(j2, Fp::ONE)], Fp::new(j2 as u64), Fp::from_i64(max + 1), &|i| keyed(&tp, max + 1, l[i], i, j2));
        p.out_plane = ep(j2 as u64);
        let t0 = std::time::Instant::now();
        let r = forge2(&r2, &tp, &p, ctx_f);
        eprintln!("REVIEW-R2 timing: full-scale forgery proved and refused in {:.1} s", t0.elapsed().as_secs_f64());
        expect_refused("RV2-C2a", &format!("FULL R2: A6-only at the best non-maximal id {j2} of another row (honest 29914), M = max + 1"), &["stage OUT slot 07 "], r);
    }
    {
        let mut p = base.clone();
        p.stage_in.mult[0] = p.stage_in.mult[0].sub(Fp::ONE);
        p.stage_in.mult[tp.v + 1] = p.stage_in.mult[tp.v + 1].add(Fp::ONE);
        expect_refused("RV2-C2b", "FULL R2: stage IN m, one count of row 0 moved to the padded entry V + 1", &["stage IN slot 02 "], forge2(&r2, &tp, &p, ctx_f));
    }
}

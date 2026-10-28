//! **INDEPENDENT ADVERSARIAL REVIEW, ROUND 6 (2026-10-19): the R8 rebase's
//! per-layer calibration in a token run, and the capture hooks on hostile
//! receipts.** TEST CODE ONLY, reviewer's scratch copy; a child of
//! `token_io::r3_tests` (its rung fixture and helpers). `REVIEW-R6 CONTROL`
//! lines are asserted; `REVIEW-R6 NOTE` lines are printed.

use super::*;
use super::super::super::protocol::CheatingProver;
use super::super::super::run_capture::{self, CaptureOpts};
use super::super::super::shape::NormCalibration;
use super::super::super::trained_statement::{apply_own, cal_field, own_of, OWN_FIELDS};

fn control(id: &str, what: &str, ok: bool, detail: &str) {
    eprintln!("REVIEW-R6 CONTROL {id} | {what} | {} | {}", detail.chars().take(240).collect::<String>(), if ok { "AS PREDICTED" } else { "NOT AS PREDICTED" });
    assert!(ok, "REVIEW-R6 {id} ({what}): {detail}");
}

fn records(fx: &Fx, own: &[[Option<i64>; 11]]) -> TrainedModelStatement {
    let mut recs: Vec<LayerRecord> = fx.blocks.iter().enumerate().map(|(k, b)| LayerRecord::of_block(k as u32, b, vec![])).collect();
    for (k, o) in own.iter().enumerate() {
        recs[k].own = *o;
    }
    model_with_records(&fx.sh, recs, super::super::super::run::RUN_PROFILE_TOKEN_IO_RUNG_TC)
}

fn mk(fx: &Fx, roots: (Digest, Digest), m: &TrainedModelStatement) -> Result<TokenRunStatement, String> {
    let digests: Vec<Digest> = fx.blocks.iter().map(|b| b.digest()).collect();
    TokenRunStatement::new(RunShape::new(fx.sh.clone(), 2, super::super::super::run::RUN_PROFILE_TOKEN_IO_RUNG_TC).unwrap(), ctx(), digests, m, &fx.tables, fx.bos, fx.norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots)
}

/// prove `pipe` (honest, or with the cheating prover) under the statement of `m`
fn prove_under(fx: &Fx, tp: &TokenProfile, m: &TrainedModelStatement, pipe: &mut HonestPipeline, cheat: bool) -> (TokenRunStatement, Vec<Vec<u8>>, (Digest, Digest)) {
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
    let st = mk(fx, roots, m).expect("the statement");
    let mut segs = Vec::new();
    {
        let _c = if cheat { Some(CheatingProver::on()) } else { None };
        prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(pipe), owners, &mut |_, b| {
            segs.push(b);
            Ok(())
        })
        .unwrap_or_else(|e| panic!("the prover did not produce a receipt: {e}"));
    }
    (st, segs, roots)
}

/// the lane's own candidate calibrations at the rung, in its order
fn candidates(base: NormCalibration) -> Vec<NormCalibration> {
    vec![
        NormCalibration { tn: 9, cn_a: 700, cn_m: 1100, ceps: 16_777_259, sh_ao: 7, sh_qkv: 7, sh_s: 6, sh_o: 11, sh_g: 7, sh_h: 14, sh_z: 6 },
        NormCalibration { tn: 9, cn_a: 700, cn_m: 1100, ceps: 16_777_259, ..base },
        NormCalibration { cn_a: 700, ..base },
        NormCalibration { sh_o: base.sh_o + 1, ..base },
        NormCalibration { sh_qkv: base.sh_qkv + 1, ..base },
    ]
}

/// RV6-4: a cheating prover witnessing block 1 at the layer's calibration
/// with ONE field put back to the run's value (i.e. under the other layer's
/// constant), under the honest per-layer statement: refused for every field
/// that moves block 1's output. RV6-5: the honest per-layer receipt read
/// under statements whose layer records differ (the own constants on the
/// other layer, on both layers, or one field dropped): refused.
#[test]
fn rv6_4_5_every_own_field_is_enforced_and_bound() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let base = fx.sh.norm_calibration();
    let wide = honest(&fx, &tp);
    let mut chosen = None;
    for cal in candidates(base) {
        let Ok(s1) = fx.sh.with_layer_calibration(&cal) else { continue };
        let Ok(p) = honest_pipeline_at(&[fx.sh.clone(), s1], &tp, &fx.tables, &fx.blocks, &fx.tokens) else { continue };
        if p.planes[1] != wide.planes[1] {
            chosen = Some((cal, p));
            break;
        }
    }
    let (cal, pipe) = chosen.expect("an admissible per-layer calibration that moves block 1");
    let own = own_of(&base, &cal);
    let none = [None; 11];
    let model = records(&fx, &[none, own]);
    eprintln!("REVIEW-R6 NOTE | block 1's own constants at the rung: {:?}", own.iter().enumerate().filter_map(|(i, v)| v.map(|v| format!("{}={v} (run {})", OWN_FIELDS[i].0, cal_field(&base, i)))).collect::<Vec<_>>());
    // the honest receipt
    let mut hp = pipe;
    let (st, segs, roots) = prove_under(&fx, &tp, &model, &mut hp, false);
    verify_token_run(&st, &fx.blocks, &fx.tables, &segs, R1_DEV_POLICY_R3).expect("the honest per-layer receipt verifies");
    // RV6-5: the same receipt under other layer records
    let mut variants: Vec<(String, [[Option<i64>; 11]; 2])> = vec![("the own constants on layer 0 instead of layer 1".into(), [own, none]), ("the own constants on both layers".into(), [own, own])];
    for (i, v) in own.iter().enumerate() {
        if v.is_some() {
            let mut o = own;
            o[i] = None;
            variants.push((format!("layer 1's own {} dropped (the run's value)", OWN_FIELDS[i].0), [none, o]));
        }
    }
    for (n, (what, o)) in variants.iter().enumerate() {
        let m = records(&fx, o);
        match mk(&fx, roots, &m) {
            Ok(st2) => {
                let r = verify_token_run(&st2, &fx.blocks, &fx.tables, &segs, R1_DEV_POLICY_R3);
                control(&format!("RV6-5.{n}"), &format!("the honest receipt read under a statement with {what}"), r.is_err(), &format!("{:?}", r.err()));
            }
            Err(e) => eprintln!("REVIEW-R6 NOTE | RV6-5.{n} | {what}: no statement ({e})"),
        }
    }
    // RV6-4: one field at a time, block 1 witnessed with that field at the run's value
    let mut enforced = Vec::new();
    let mut harmless = Vec::new();
    let mut inadmissible = Vec::new();
    for (i, v) in own.iter().enumerate() {
        if v.is_none() {
            continue;
        }
        let mut back = [None; 11];
        back[i] = Some(cal_field(&base, i));
        let cal_i = apply_own(&cal, &back).unwrap();
        let s1 = match fx.sh.with_layer_calibration(&cal_i) {
            Ok(s) => s,
            Err(e) => {
                inadmissible.push(format!("{}: {e}", OWN_FIELDS[i].0));
                continue;
            }
        };
        let mut cheat = match honest_pipeline_at(&[fx.sh.clone(), s1], &tp, &fx.tables, &fx.blocks, &fx.tokens) {
            Ok(p) => p,
            Err(e) => {
                inadmissible.push(format!("{}: no honest pipeline ({e})", OWN_FIELDS[i].0));
                continue;
            }
        };
        if cheat.planes[1] == hp.planes[1] {
            harmless.push(OWN_FIELDS[i].0);
            continue;
        }
        let (st_c, segs_c, _) = prove_under(&fx, &tp, &model, &mut cheat, true);
        let r = verify_token_run(&st_c, &fx.blocks, &fx.tables, &segs_c, R1_DEV_POLICY_R3);
        let ok = matches!(&r, Err(e) if e.starts_with("block "));
        control(&format!("RV6-4.{}", OWN_FIELDS[i].0), &format!("block 1 witnessed with {} at the run's value under the per-layer statement", OWN_FIELDS[i].0), ok, &format!("{:?}", r.err()));
        enforced.push(OWN_FIELDS[i].0);
    }
    eprintln!("REVIEW-R6 NOTE | RV6-4 summary: refused at block 1 for {enforced:?}; output unmoved (nothing to forge) for {harmless:?}; not admissible alone {inadmissible:?}");
}

/// RV6-6: two layers with DIFFERENT own calibrations; a cheating prover
/// witnesses each block at the OTHER layer's calibration (swapped) under the
/// honest statement: refused.
#[test]
fn rv6_6_swapped_layer_calibrations_are_refused() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let base = fx.sh.norm_calibration();
    let cands = candidates(base);
    let mut found = None;
    'outer: for (ia, ca) in cands.iter().enumerate() {
        for (ib, cb) in cands.iter().enumerate() {
            if ia == ib {
                continue;
            }
            let (Ok(sa), Ok(sb)) = (fx.sh.with_layer_calibration(ca), fx.sh.with_layer_calibration(cb)) else { continue };
            let (Ok(h), Ok(c)) = (honest_pipeline_at(&[sa.clone(), sb.clone()], &tp, &fx.tables, &fx.blocks, &fx.tokens), honest_pipeline_at(&[sb, sa], &tp, &fx.tables, &fx.blocks, &fx.tokens)) else { continue };
            if h.planes[0] != c.planes[0] && h.planes[1] != c.planes[1] {
                found = Some((*ca, *cb, h, c));
                break 'outer;
            }
        }
    }
    let Some((ca, cb, mut h, mut c)) = found else {
        eprintln!("REVIEW-R6 NOTE | RV6-6: no pair of admissible calibrations whose swap moves both blocks at the rung; not run");
        return;
    };
    let model = records(&fx, &[own_of(&base, &ca), own_of(&base, &cb)]);
    let (st, segs, roots) = prove_under(&fx, &tp, &model, &mut h, false);
    verify_token_run(&st, &fx.blocks, &fx.tables, &segs, R1_DEV_POLICY_R3).expect("the honest two-calibration receipt verifies");
    let (st_c, segs_c, _) = prove_under(&fx, &tp, &model, &mut c, true);
    let r = verify_token_run(&st_c, &fx.blocks, &fx.tables, &segs_c, R1_DEV_POLICY_R3);
    control("RV6-6", "blocks 0 and 1 witnessed at each other's own calibration (swapped) under the honest statement", matches!(&r, Err(e) if e.starts_with("block ")), &format!("{:?}", r.err()));
    // and the honest receipt under the statement with the records swapped
    let swapped = records(&fx, &[own_of(&base, &cb), own_of(&base, &ca)]);
    let r = mk(&fx, roots, &swapped).and_then(|s2| verify_token_run(&s2, &fx.blocks, &fx.tables, &segs, R1_DEV_POLICY_R3));
    control("RV6-6b", "the honest receipt under a statement with the two layers' records swapped", r.is_err(), &format!("{:?}", r.err()));
}

/// RV6-7: the capture hooks on hostile receipts. Mutated receipts of the rung
/// run (byte flips across every segment, truncation, extension, swapped and
/// emptied segments) are verified with NO recorder and again WITH one
/// attached: never a panic, always a refusal, no bundle, the recorder
/// detached afterwards.
#[test]
fn rv6_7_hostile_receipts_with_and_without_a_recorder() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let (st, segs, _) = prove_under(&fx, &tp, &fx.model, &mut pipe, false);
    verify_token_run(&st, &fx.blocks, &fx.tables, &segs, R1_DEV_POLICY_R3).expect("the honest rung run");
    let mut cases: Vec<(String, Vec<Vec<u8>>)> = Vec::new();
    for k in 0..segs.len() {
        let n = segs[k].len();
        for j in [0usize, 1, 31, 32, 64, n / 7, n / 3, n / 2, 2 * n / 3, n - 33, n - 2, n - 1] {
            let mut s = segs.clone();
            s[k][j.min(n - 1)] ^= 0x41;
            cases.push((format!("segment {k} byte {j} flipped"), s));
        }
        let mut s = segs.clone();
        s[k].pop();
        cases.push((format!("segment {k} truncated by one byte"), s));
        let mut s = segs.clone();
        s[k].push(0);
        cases.push((format!("segment {k} extended by one byte"), s));
        let mut s = segs.clone();
        s[k].clear();
        cases.push((format!("segment {k} emptied"), s));
    }
    let mut s = segs.clone();
    s.swap(1, 2);
    cases.push(("blocks 0 and 1's segments swapped".into(), s));
    let mut s = segs.clone();
    s.pop();
    cases.push(("the last segment dropped".into(), s));
    let (mut panics, mut accepted, mut bundles) = (0usize, 0usize, 0usize);
    for (n, (what, s)) in cases.iter().enumerate() {
        let off = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| verify_token_run(&st, &fx.blocks, &fx.tables, s, R1_DEV_POLICY_R3)));
        let on = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let guard = run_capture::Recorder::attach();
            run_capture::begin_run_with(st.capture_header().unwrap(), st.binding().unwrap(), CaptureOpts { arrays: true, public_tables: true });
            let r = verify_token_run(&st, &fx.blocks, &fx.tables, s, R1_DEV_POLICY_R3);
            let b = if r.is_ok() { run_capture::take().ok() } else { None };
            drop(guard);
            (r, b.is_some())
        }));
        let detached = !run_capture::active();
        match (&off, &on) {
            (Ok(Err(_)), Ok((Err(_), false))) if detached => {}
            _ => {
                panics += usize::from(off.is_err() || on.is_err());
                accepted += usize::from(matches!(off, Ok(Ok(()))) || matches!(on, Ok((Ok(()), _))));
                bundles += usize::from(matches!(on, Ok((_, true))));
                eprintln!("REVIEW-R6 HOSTILE #{n} {what}: off {:?} | on {:?} | detached {detached}", off.as_ref().map(|r| r.as_ref().err().map(|e| e.chars().take(80).collect::<String>())), on.as_ref().map(|(r, b)| (r.as_ref().err().map(|e| e.chars().take(80).collect::<String>()), *b)));
            }
        }
    }
    control("RV6-7", &format!("{} hostile receipts verified without and with a recorder", cases.len()), panics == 0 && accepted == 0 && bundles == 0, &format!("panics {panics}, accepted {accepted}, bundles {bundles}"));
}

/// RV6-8 (the coordinator's t34 question): on the HONEST prover path (no
/// cheating flag), (i) a stage-IN lookup miss and (ii) an input endpoint
/// sealed over another prompt are not refused by the prover. Whatever
/// receipt it produces, the VERIFIER must refuse it; the refusing relation
/// is printed. Controls: the same forgery class with every part consistent
/// (a true run of the other prompt) is accepted, as it should be.
#[test]
fn rv6_8_stage_in_misses_on_the_honest_prover_path_are_refused_by_the_verifier() {
    let fx = fx_generic();
    let tp = profile(&fx);
    // prove a pipeline with the HONEST prover; seal its own in/out planes
    let run = |pipe: &mut HonestPipeline| -> Result<(TokenRunStatement, Vec<Vec<u8>>), String> {
        let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp)?;
        let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag())?;
        let st = mk(&fx, roots, &fx.model)?;
        let mut segs = Vec::new();
        prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(pipe), owners, &mut |_, b| {
            segs.push(b);
            Ok(())
        })?;
        Ok((st, segs))
    };
    let other = |t: u64| (t + 11) % tp.v as u64;
    let mut cases: Vec<(&str, bool, HonestPipeline)> = Vec::new();
    // (i-a) a lookup miss: position 5's id changed (endpoint and histogram follow it), B_in row 5 kept = E[old]
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[5] = other(toks[5]);
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &toks), mult: hist(&tp, &toks), hq_zero: vec![] };
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        cases.push(("(i-a) lookup miss: id at position 5 changed, endpoint and histogram follow, B_in row 5 = E[old]", false, p));
    }
    // (i-b) a lookup miss: B_in row 5 = E[old] with one word changed (downstream re-derived)
    {
        let mut p = honest(&fx, &tp);
        let mut b = p.b_in.clone();
        b[5 * tp.d_pad + 3] += 1;
        with_b_in(&fx, &tp, &mut p, b);
        cases.push(("(i-b) lookup miss: one word of B_in row 5 changed, blocks and B_out re-derived", false, p));
    }
    // (i-c) a lookup miss: an id >= V at position 5 (endpoint and histogram follow; B_in row = E[0], the padded row)
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[5] = tp.v as u64 + 3;
        let mut b = p.b_in.clone();
        set_row(&tp, &mut b, 5, fx.tables.emb_row(0));
        p.stage_in = StageInWitness { tok: tok_plane(&tp, &toks), mult: hist(&tp, &fx.tokens), hq_zero: vec![] };
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        with_b_in(&fx, &tp, &mut p, b);
        cases.push(("(i-c) lookup miss: an id >= V at position 5, B_in row = the padded row E[0]", false, p));
    }
    // (ii-a) the input endpoint sealed over another prompt; the witness is the honest prompt's
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[7] = other(toks[7]);
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        cases.push(("(ii-a) input endpoint sealed over another prompt (position 7), witness = the honest prompt", false, p));
    }
    // (ii-b) the input endpoint = the honest prompt plus a nonzero pad word
    {
        let mut p = honest(&fx, &tp);
        p.in_plane[tp.tokens] = Fp::new(9);
        cases.push(("(ii-b) input endpoint = the honest prompt + a nonzero pad word", false, p));
    }
    // (ii-c) the input endpoint over a prompt whose BOS is changed; the witness is the honest prompt's
    {
        let mut p = honest(&fx, &tp);
        let mut toks = fx.tokens.clone();
        toks[0] = 7;
        p.in_plane = stage_in::endpoint_plane(&tp, &toks);
        cases.push(("(ii-c) input endpoint over a prompt with position 0 changed, witness = the honest prompt", false, p));
    }
    // control: the OTHER prompt, everything consistent (a true run of that prompt): accepted
    {
        let mut toks = fx.tokens.clone();
        toks[7] = other(toks[7]);
        let p = honest_pipeline(&fx.sh, &tp, &fx.tables, &fx.blocks, &toks).expect("the other prompt's honest pipeline");
        cases.push(("control: the other prompt, every part consistent", true, p));
    }
    for (what, want_ok, mut p) in cases {
        match run(&mut p) {
            Err(e) => {
                eprintln!("REVIEW-R6 NOTE | RV6-8 | {what}: the HONEST prover refused: {e}");
                assert!(!want_ok, "{what}: the control did not prove: {e}");
            }
            Ok((st, segs)) => {
                let r = verify_token_run(&st, &fx.blocks, &fx.tables, &segs, R1_DEV_POLICY_R3);
                control(&format!("RV6-8 {}", &what[..what.find(' ').unwrap_or(what.len())]), &format!("{what} (receipt from the HONEST prover)"), r.is_ok() == want_ok, &format!("verifier: {}", match &r { Ok(()) => "ACCEPTED".to_string(), Err(e) => format!("refused: {e}") }));
            }
        }
    }
}

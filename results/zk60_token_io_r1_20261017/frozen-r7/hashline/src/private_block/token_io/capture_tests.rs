//! **TOKEN I/O ROUND 7: RUN CAPTURES OF TOKEN-I/O RUNS** (the privacy gate
//! lane's request `results/zk60_gate_tinyllama_20261017/token_io/
//! CAPTURE_HOOK_REQUEST.md`). TEST CODE ONLY.
//!
//! A capture is the VERIFIER'S VIEW of one accepted token run, written by
//! `run_capture.rs` (schema `hashline-native-capture/6-token-run`): stage IN,
//! the `L` blocks and stage OUT, each with its slot transcripts, its M
//! opening and every PCS opening (A-in / H-in / the input token endpoint;
//! A / H / the boundary before each block, `B_in` at block 0; A-out / H-out
//! / `B_out` / the output token endpoint). The hooks fire only on the
//! verifier's side and only when a recorder is attached; they are
//! `cfg(test)`, so no production build carries them. A capture never holds
//! a token id, the next token, an activation or an owner decommitment.
//!
//! Here: the rung run captured and checked against itself and the
//! allow-list; the prover's path records nothing even with a recorder
//! attached and seeded, and a run verifies the same with and without one; a
//! tampered run writes no bundle. And the two `#[ignore]`d,
//! environment-driven captures the gate reads: TinyLlama T32 (the R2
//! geometry) and Llama-3-8B T32, at `L` blocks from `HL_PB_FIRST_LAYER`,
//! with a dense (held-out) or a fixed prompt.

use super::load::{load_token_tables, token_run_profile_of, TableFiles};
use super::run::*;
use super::tests::*;
use super::*;
use super::super::run::RunShape;
use super::super::run_capture::{self, Bundle, CaptureOpts};
use super::super::trained_block::TrainedExport;
use super::super::trained_statement::{apply_own, has_own, IntegerCalibration, Provenance, TrainedModelStatement};
use super::super::BlockPublic;
use super::stage_in::StageInWitness;
use super::stage_out::StageOutWitness;
use crate::field::Fp;
use std::path::{Path, PathBuf};

const POLICY: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 93 };

fn contains(hay: &[u8], needle: &str) -> bool {
    hay.windows(needle.len()).any(|w| w == needle.as_bytes())
}

fn count(hay: &[u8], needle: &str) -> usize {
    hay.windows(needle.len()).filter(|w| *w == needle.as_bytes()).count()
}

/// verify `segs` with a recorder attached; the bundle only for an accepted run
fn capture(st: &TokenRunStatement, blocks: &[BlockPublic], tables: &TokenTables, segs: &[Vec<u8>], opts: CaptureOpts) -> Result<Bundle, String> {
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(st.capture_header()?, st.binding()?, opts);
    let out = match verify_token_run(st, blocks, tables, segs, POLICY) {
        Ok(()) => run_capture::take(),
        Err(e) => {
            run_capture::discard();
            Err(e)
        }
    };
    drop(guard);
    out
}

/// every key of every file of a bundle is on the allow-list
fn keys_allowed(b: &Bundle) -> usize {
    let mut n = 0usize;
    let mut files: Vec<(&str, &[u8])> = vec![("run.json", &b.run_json)];
    for s in &b.stages {
        files.push(("stage", s));
    }
    for (name, bytes) in files {
        for key in run_capture::keys_of(bytes) {
            assert!(run_capture::ALLOWED_KEYS.contains(&key.as_str()), "{name} carries the field {key:?}, which is not on the capture allow-list");
            n += 1;
        }
    }
    n
}

/// every `"salt":[...]` value and every unsigned integer of a JSON file
fn index_json(bytes: &[u8], salts: &mut std::collections::HashSet<Vec<u8>>, numbers: &mut std::collections::HashSet<u64>) {
    const KEY: &[u8] = b"\"salt\":";
    let mut i = 0usize;
    while i < bytes.len() {
        if bytes[i] == b'"' && bytes[i..].starts_with(KEY) {
            let start = i + KEY.len();
            if let Some(end) = bytes[start..].iter().position(|&c| c == b']') {
                salts.insert(bytes[start..start + end + 1].to_vec());
                i = start + end + 1;
                continue;
            }
        }
        if bytes[i].is_ascii_digit() {
            let (mut j, mut v, mut ok) = (i, 0u64, true);
            while j < bytes.len() && bytes[j].is_ascii_digit() {
                match v.checked_mul(10).and_then(|x| x.checked_add(u64::from(bytes[j] - b'0'))) {
                    Some(x) => v = x,
                    None => ok = false,
                }
                j += 1;
            }
            if ok {
                numbers.insert(v);
            }
            i = j;
            continue;
        }
        i += 1;
    }
}

/// the checks every token bundle must pass, whatever its geometry
fn check_token_bundle(b: &Bundle, l: usize, binding: Digest, segs: &[Vec<u8>], hand: &OwnerHandoff) {
    assert!(b.token, "a token run's bundle is not marked as one");
    assert_eq!(b.stages.len(), l + 2, "a token bundle has L + 2 stage files");
    assert!(contains(&b.run_json, "\"schema\":\"hashline-native-capture/6-token-run\""), "run.json does not declare the token schema");
    assert!(contains(&b.run_json, &format!("\"blocks\":{l},\"stages\":{}", l + 2)), "run.json does not declare L and L + 2");
    assert!(contains(&b.run_json, &format!("\"run_binding\":{binding:?}")), "run.json does not carry the run binding the statement computed");
    assert!(contains(&b.run_json, "\"token_io\":{\"run_profile\":"), "run.json carries no token facts");
    assert_eq!(count(&b.run_json, "\"plane_index\":"), 1, "the block plane index belongs in run.json exactly once");
    assert!(contains(&b.run_json, "\"owner decommitments\""), "not_in_a_capture does not name the owners' decommitments");
    for (k, s) in b.stages.iter().enumerate() {
        let (kind, slots, order) = if k == 0 {
            ("IN", 4, "[\"M\", \"A-in\", \"H-in\", \"E-token-in\"]")
        } else if k == l + 1 {
            ("OUT", 11, "[\"M\", \"A-out\", \"H-out\", \"B-out\", \"E-token-out\"]")
        } else {
            ("BLOCK", 23, "[\"M\", \"A\", \"H\", \"Input\"]")
        };
        assert!(contains(s, &format!("\"stage\":{k},\"stage_kind\":\"{kind}\"")), "stage {k} is not {kind}");
        assert_eq!(count(s, "\"definition_challenges\":"), slots, "stage {k} ({kind}) does not carry {slots} slot transcripts");
        assert!(contains(s, &format!("\"opening_order\":{order}")), "stage {k}'s opening order is not {order}");
        assert!(contains(s, &format!("\"segment_bytes\":{}", segs[k].len())), "stage {k} does not carry its segment's length");
        assert!(contains(s, &format!("\"segment_sha256\":\"{}\"", crate::export_v3::sha256_hex(&segs[k]))), "stage {k} is not pinned to the bytes that were verified");
        assert_eq!(contains(s, "\"stage_plane_index\":"), kind != "BLOCK", "stage {k}'s plane table");
        assert!(!contains(s, "\"plane_index\":"), "stage {k} carries a copy of the block plane index");
        if kind != "BLOCK" {
            assert!(contains(s, "\"fixed\":"), "stage {k} ({kind}) records no fixed claim coordinate");
        }
    }
    assert!(contains(&b.stages[1], "\"commitment_kind\":\"B-in\""), "block 0's stage does not open B_in");
    assert!(contains(&b.stages[l + 1], "\"commitment_kind\":\"B-out\""), "stage OUT does not open B_out");
    // NO OWNER DECOMMITMENT. A token endpoint's opening publishes the salts
    // of its Q opened columns (they are in the receipt), so at most Q of an
    // owner's salts may appear and never all of them; and none of the
    // owner's pad words appears, as text or in `arrays.bin`.
    // (Indexed once: every published salt, every integer of the JSON and
    // every 8-byte word of `arrays.bin`, whose arrays are 8-byte aligned.)
    let (mut salts, mut numbers) = (std::collections::HashSet::new(), std::collections::HashSet::new());
    for f in std::iter::once(&b.run_json).chain(b.stages.iter()) {
        index_json(f, &mut salts, &mut numbers);
    }
    let words: std::collections::HashSet<u64> = b.arrays.blob().chunks_exact(8).map(|c| u64::from_le_bytes(c.try_into().expect("8 bytes"))).collect();
    for (which, d) in [("input", &hand.input), ("output", &hand.output)] {
        let found = d.salts.iter().filter(|salt| salts.contains(format!("{salt:?}").as_bytes())).count();
        assert!(found <= Tier::R1_MVP.opened_cols && found < d.salts.len(), "the {which} owner's decommitment: {found} of its {} salts are in the bundle", d.salts.len());
        for pad in d.pads.iter().filter(|p| p.0 >= 1_000_000_000_000) {
            assert!(!numbers.contains(&pad.0), "an {which} owner's pad word is in the bundle's JSON");
            assert!(!words.contains(&pad.0), "an {which} owner's pad word is in arrays.bin");
        }
    }
    let n = keys_allowed(b);
    assert!(n > 1000, "only {n} keys were scanned");
}

// -------------------------------------------------- the rung (fast)

/// **A TOKEN RUN IS CAPTURED AND ITS BUNDLE IS SELF-CONSISTENT** (the rung,
/// `L = 2`): `L + 2` stage files, IN / BLOCK / OUT in order with their slot
/// counts and opening orders, every segment pinned, the token facts and the
/// boundaries in token numbering, the plane tables of the new stages, fixed
/// claim coordinates recorded, every key on the allow-list, and no owner
/// decommitment anywhere.
#[test]
fn a_token_run_is_captured_and_its_bundle_is_self_consistent() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let p = prove_pipe(&fx, &tp, &mut pipe).expect("the honest rung run");
    let bundle = capture(&p.st, &fx.blocks, &fx.tables, &p.segs, CaptureOpts { arrays: false, public_tables: true }).expect("a bundle for an accepted token run");
    check_token_bundle(&bundle, fx.blocks.len(), p.st.binding().unwrap(), &p.segs, &p.hand);
    assert!(contains(&bundle.stages[0], "\"r_emb\":[["), "stage IN records no r_emb challenge");
    eprintln!(
        "TOKEN CAPTURE rung L={}: run.json {} B, stage files {:?} B",
        fx.blocks.len(),
        bundle.run_json.len(),
        bundle.stages.iter().map(|s| s.len()).collect::<Vec<_>>()
    );
}

/// **THE HOOKS ARE NO-OPS ON THE PROVER'S PATH, AND A RUN VERIFIES THE SAME
/// WITH AND WITHOUT A RECORDER.** A run proved while a recorder is attached
/// AND seeded with its header: the recorder has recorded nothing (no stage,
/// no failure) — every hook is on the verifier's side. The receipt verifies
/// without a recorder, and again with one (a bundle), and the receipt's
/// segment lengths are the statement's counted ones either way. (The token
/// prover's randomness is OS-seeded, so "same seed, same bytes" is not
/// available; the release binary, which compiles no hook, is compared byte
/// for byte with the one built before the hooks in the round ledger.)
#[test]
fn the_hooks_are_inert_on_the_prover_and_a_run_verifies_the_same_with_and_without_a_recorder() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let (ins, outs) = endpoint_specs(&fx.sh, ctx(), &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &fx.sh.hash_tag()).unwrap();
    let st = statement(&fx, roots, tp.variant).unwrap();
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(st.capture_header().unwrap(), st.binding().unwrap(), CaptureOpts { arrays: false, public_tables: false });
    let mut segs = Vec::new();
    prove_token_run(&st, &fx.blocks, &fx.tables, &mut PipelineSource(&mut pipe), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the honest run proves with a recorder attached");
    assert_eq!(run_capture::recorded(), Some((0, false, None)), "the prover's path touched the recorder");
    run_capture::discard();
    drop(guard);
    let lens: Vec<usize> = segs.iter().map(|s| s.len()).collect();
    assert_eq!(lens, st.segment_lens().unwrap(), "the receipt's segments are not the counted lengths");
    verify_token_run(&st, &fx.blocks, &fx.tables, &segs, POLICY).expect("verifies without a recorder");
    let b = capture(&st, &fx.blocks, &fx.tables, &segs, CaptureOpts { arrays: false, public_tables: false }).expect("verifies with a recorder");
    assert_eq!(b.stages.len(), fx.blocks.len() + 2);
    verify_token_run(&st, &fx.blocks, &fx.tables, &segs, POLICY).expect("and again without");
    eprintln!("TOKEN CAPTURE | the prover records nothing with a recorder attached; the receipt verifies with and without one");
}

/// **A TAMPERED TOKEN RUN WRITES NO BUNDLE.** One byte of block 0's segment
/// flipped: the verifier refuses, `take` is never reached, nothing remains.
#[test]
fn a_tampered_token_run_is_refused_and_no_bundle_is_written() {
    let fx = fx_generic();
    let tp = profile(&fx);
    let mut pipe = honest(&fx, &tp);
    let p = prove_pipe(&fx, &tp, &mut pipe).expect("the honest rung run");
    let mut segs = p.segs.clone();
    let mid = segs[1].len() / 2;
    segs[1][mid] ^= 1;
    let e = capture(&p.st, &fx.blocks, &fx.tables, &segs, CaptureOpts { arrays: false, public_tables: false }).err().expect("A TAMPERED TOKEN RUN WAS CAPTURED");
    assert!(!run_capture::active(), "a recorder was left attached");
    eprintln!("TOKEN CAPTURE | a tampered run refused ({e}); no bundle");
}

// -------------------------------------------------- the gate's captures (heavy, environment-driven)

fn env_or(k: &str, default: &str) -> String {
    std::env::var(k).unwrap_or_else(|_| default.to_string())
}

/// `HL_PB_CAPTURE_DIR`: absolute and outside the repository
fn capture_dir() -> PathBuf {
    let raw = std::env::var("HL_PB_CAPTURE_DIR").expect("HL_PB_CAPTURE_DIR is not set: this test writes a bundle of evidence and will not choose a directory for you");
    let dir = PathBuf::from(&raw);
    assert!(dir.is_absolute(), "HL_PB_CAPTURE_DIR must be an absolute path, not {raw:?}");
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).ancestors().nth(4).expect("the repository root").to_path_buf();
    let repo = std::fs::canonicalize(&repo).unwrap_or(repo);
    let parent = dir.parent().map(|p| std::fs::canonicalize(p).unwrap_or_else(|_| p.to_path_buf())).unwrap_or_default();
    assert!(!parent.starts_with(&repo), "HL_PB_CAPTURE_DIR={raw} is inside the repository at {}; a capture bundle is written outside the tree", repo.display());
    dir
}

fn public_tables_from_env() -> bool {
    match std::env::var("HL_RUN_CAPTURE_PUBLIC_TABLES").as_deref() {
        Ok("1") => true,
        Ok("0") => false,
        _ => panic!("HL_RUN_CAPTURE_PUBLIC_TABLES is not set to 1 or 0: whether a bundle carries the public tables' VALUES changes what the gate can check and how large the bundle is; this test will not pick for you"),
    }
}

/// THE FIXED PROMPT (the gate's degenerate partner): `T` copies of BOS. BOS
/// is forced at position 0, so it is the one id admissible at every
/// position of every profile; TinyLlama's is 1, Llama-3-8B's 128,000.
fn fixed_prompt(bos: u64, t: usize) -> Vec<u64> {
    vec![bos; t]
}

/// a sequence manifest's `token_ids` (the held-out prompt, `dense`)
fn seq_tokens(export: &Path, seq: &str) -> Vec<u64> {
    let m = std::fs::read_to_string(export.join(format!("seq_{seq}")).join("manifest.json")).unwrap_or_else(|e| panic!("seq_{seq}: {e}"));
    let at = m.find("\"token_ids\"").expect("token_ids") + "\"token_ids\"".len();
    let open = at + m[at..].find('[').unwrap() + 1;
    let close = open + m[open..].find(']').unwrap();
    m[open..close].split(',').map(|x| x.trim().parse::<u64>().expect("a token id")).collect()
}

fn unpad(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| plane[t * sh.d_pad + i]).collect()
}

/// the streaming honest source: stage IN's witness and `B_in`, the padded
/// plane after each block, stage OUT's witness and the two endpoint planes;
/// block `k`'s witness is rebuilt from boundary `k` when the prover asks
struct StreamPipe {
    sh: Shape,
    stage_in: StageInWitness,
    b_in: Vec<i16>,
    planes: Vec<Vec<i16>>,
    stage_out: StageOutWitness,
    in_plane: Vec<Fp>,
    out_plane: Vec<Fp>,
}

impl TokenRunSource for StreamPipe {
    fn stage_in(&mut self) -> Result<(StageInWitness, Vec<i16>), String> {
        Ok((self.stage_in.clone(), self.b_in.clone()))
    }
    fn witness(&mut self, k: usize, blk: &BlockPublic, ssh: &Shape) -> Result<super::super::witness::Witness, String> {
        let x = unpad(&self.sh, if k == 0 { &self.b_in } else { &self.planes[k - 1] });
        super::super::witness::build_shaped(ssh, blk.attention(), blk.feed_forward(), &x)
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.planes.get(k).cloned().ok_or_else(|| format!("capture: no plane after block {k}"))
    }
    fn stage_out(&mut self) -> Result<StageOutWitness, String> {
        Ok(self.stage_out.clone())
    }
}

#[allow(clippy::type_complexity)]
fn stream_pipeline(sh: &Shape, shapes: &[Shape], tp: &TokenProfile, tables: &TokenTables, blocks: &[BlockPublic], tokens: &[u64], parity: Option<(&TrainedExport, &str, &[u32])>) -> Result<StreamPipe, String> {
    let (stage_in, b_in, in_plane) = super::stage_in::honest_inputs(tp, tables, tokens)?;
    let ids = super::super::layout::Ids::new(sh)?;
    let mut x = unpad(sh, &b_in);
    if let Some((ex, seq, layers)) = parity {
        if x != ex.load_seq(sh, seq, layers[0])?.0 {
            return Err("B_in (the embedded prompt) is not the export's input plane".into());
        }
    }
    let mut planes = Vec::with_capacity(blocks.len());
    for (k, blk) in blocks.iter().enumerate() {
        let w = super::super::witness::build_shaped(&shapes[k], blk.attention(), blk.feed_forward(), &x).map_err(|e| format!("block {k}: {e}"))?;
        let plane: Vec<i16> = w.planes[ids.at(super::super::layout::A_X2)].iter().map(|v| i16::try_from(*v).map_err(|_| format!("block {k}: an output outside int16"))).collect::<Result<_, _>>()?;
        drop(w);
        x = unpad(sh, &plane);
        if let Some((ex, seq, layers)) = parity {
            if x != ex.load_seq(sh, seq, layers[k])?.1 {
                return Err(format!("block {k}'s output is not the export's x_out of layer {}", layers[k]));
            }
        }
        planes.push(plane);
    }
    let b_out = planes.last().ok_or("capture: no block")?;
    let ov = super::stage_out::out_values(tp, tables, &super::stage_out::row_of(tp, b_out, tp.tokens - 1), true)?;
    let stage_out = super::stage_out::witness_from_values(tp, &ov)?;
    let out_plane = super::stage_out::endpoint_plane(tp, ov.tok as u64);
    Ok(StreamPipe { sh: sh.clone(), stage_in, b_in, planes, stage_out, in_plane, out_plane })
}

/// **ONE GATE CAPTURE**: layers `first .. first + l` of a trained export as a
/// token run (its own trained-model statement over those layers), the
/// production table loaders, a dense or fixed prompt; prove (resident), then
/// verify with the recorder, write the bundle ONLY after the run verified,
/// read it back and check it.
#[allow(clippy::too_many_arguments)]
fn capture_token_export(tag: &str, export: &Path, emb_dir: &Path, head_dir: &Path, seq: &str, command: &str) {
    let t0 = std::time::Instant::now();
    let dir = capture_dir();
    let l: usize = env_or("HL_PB_CAPTURE_BLOCKS", "2").parse().expect("HL_PB_CAPTURE_BLOCKS is a number");
    let first: u32 = env_or("HL_PB_FIRST_LAYER", "0").parse().expect("HL_PB_FIRST_LAYER is a number");
    let input = env_or("HL_PB_TOKEN_INPUT", "dense");
    let public_tables = public_tables_from_env();
    let ex = TrainedExport::load(export).unwrap_or_else(|e| panic!("{tag}: the export: {e}"));
    let layers: Vec<u32> = (first..first + l as u32).collect();
    assert!(layers.iter().all(|k| ex.layers.contains(k)), "{tag}: layers {layers:?} are not all in the export");
    let c = ex.run_constants(&layers).unwrap_or_else(|e| panic!("{tag}: {e}"));
    let sh = ex.shape_for(&c).unwrap_or_else(|e| panic!("{tag}: {e}"));
    let profile = token_run_profile_of(&sh).unwrap_or_else(|e| panic!("{tag}: {e}"));
    let mut blocks = Vec::with_capacity(l);
    let mut records = Vec::with_capacity(l);
    for &k in &layers {
        let t = ex.load_layer(&sh, &c, k, false).unwrap_or_else(|e| panic!("{tag}: layer {k}: {e}"));
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
    // each block stage at its layer's own calibration (native R8)
    let base = sh.norm_calibration();
    let shapes: Vec<Shape> = records.iter().map(|r| if has_own(&r.own) { sh.with_layer_calibration(&apply_own(&base, &r.own).unwrap()).unwrap() } else { sh.clone() }).collect();
    let model = TrainedModelStatement::new(&sh, profile, ex.source.clone(), cal, records).unwrap_or_else(|e| panic!("{tag}: the trained-model statement over layers {layers:?}: {e}"));
    let files = TableFiles { emb_dir: emb_dir.to_path_buf(), head_dir: head_dir.to_path_buf() };
    let (tables, tm) = load_token_tables(&files, super::load::read_manifests(&files).unwrap().v, sh.width).unwrap_or_else(|e| panic!("{tag}: the tables: {e}"));
    let tp = TokenProfile::new(&sh, &tables, tm.bos, tm.norm, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap_or_else(|e| panic!("{tag}: {e}"));
    let tokens = match input.as_str() {
        "dense" => seq_tokens(export, seq),
        "fixed" => fixed_prompt(tm.bos, sh.tokens),
        other => panic!("HL_PB_TOKEN_INPUT={other:?} is `dense` (the held-out prompt) or `fixed` (T copies of BOS)"),
    };
    let load_s = t0.elapsed().as_secs_f64();
    // the honest pipeline, STREAMING (boundary planes kept, each block's
    // witness built, its output taken and dropped; the proving pass rebuilds
    // it), so L = 22 fits; a dense prompt is checked against the export's
    // own activations at every layer (the native parity)
    let mut pipe = stream_pipeline(&sh, &shapes, &tp, &tables, &blocks, &tokens, if input == "dense" { Some((&ex, seq, &layers)) } else { None }).unwrap_or_else(|e| panic!("{tag}: the honest pipeline ({input} prompt) refused: {e}"));
    let context = *blake3::hash(format!("hashline/token-io capture/{tag}/{input}").as_bytes()).as_bytes();
    let (ins, outs) = endpoint_specs(&sh, context, &tp).unwrap();
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &sh.hash_tag()).unwrap();
    let digests: Vec<Digest> = blocks.iter().map(|b| b.digest()).collect();
    let st = TokenRunStatement::new(RunShape::new(sh.clone(), l, profile).unwrap(), context, digests, &model, &tables, tm.bos, tm.norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots).unwrap_or_else(|e| panic!("{tag}: {e}"));
    let t1 = std::time::Instant::now();
    let mut segs = Vec::new();
    let (_, hand) = prove_token_run(&st, &blocks, &tables, &mut pipe, owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .unwrap_or_else(|e| panic!("{tag}: prove: {e}"));
    let prove_s = t1.elapsed().as_secs_f64();
    drop(pipe);
    let t2 = std::time::Instant::now();
    let bundle = capture(&st, &blocks, &tables, &segs, CaptureOpts { arrays: true, public_tables }).unwrap_or_else(|e| panic!("{tag}: the capture: {e}"));
    let verify_s = t2.elapsed().as_secs_f64();
    check_token_bundle(&bundle, l, st.binding().unwrap(), &segs, &hand);
    let note = format!(
        "Bundle: one honest TOKEN-I/O run, {tag}: export `{}` (variant {}), layers {}..{} as an {l}-block run under the token profile `{profile}`, the public-row variant, mode (i), tier `{}`. Prompt: {}. Context: blake3(\"hashline/token-io capture/{tag}/{input}\").\n\nPublic weights and tables (the export's, SHA-checked by the loaders); the prompt and every activation are prover-side and NOT here; neither is either owner's decommitment.",
        export.display(),
        ex.variant,
        first,
        first + l as u32 - 1,
        Tier::R1_MVP.name,
        if input == "dense" { format!("dense: the export's held-out sequence seq_{seq} (T = {})", tokens.len()) } else { format!("fixed: T = {} copies of BOS (id {}), the degenerate partner", tokens.len(), tm.bos) }
    );
    run_capture::write_bundle(&dir, &bundle, &segs, &note, command).unwrap_or_else(|e| panic!("{tag}: {e}"));
    // read back: every file in the manifest with its own length and digest
    let manifest = std::fs::read(dir.join("manifest.json")).expect("a manifest");
    let mut names = vec!["run.json".to_string(), "README.md".to_string(), run_capture::ARRAYS_FILE.to_string()];
    names.extend((0..l + 2).map(run_capture::stage_file));
    let mut total = 0usize;
    for name in &names {
        let bytes = std::fs::read(dir.join(name)).unwrap_or_else(|e| panic!("{name}: {e}"));
        assert!(contains(&manifest, &format!("{{\"file\":\"{name}\",\"bytes\":{},\"sha256\":\"{}\"}}", bytes.len(), crate::export_v3::sha256_hex(&bytes))), "{name} is not in the manifest with its own length and digest");
        if name.ends_with(".json") {
            for key in run_capture::keys_of(&bytes) {
                assert!(run_capture::ALLOWED_KEYS.contains(&key.as_str()), "{name} carries {key:?}, not on the allow-list");
            }
        }
        total += bytes.len();
    }
    eprintln!(
        "TOKEN CAPTURE {tag}: L={l} from layer {first}, {input} prompt, public tables {}: load {load_s:.1} s, prove {prove_s:.1} s, verify+record {verify_s:.1} s, peak RSS {:.2} GiB; {total} B in {} ({:?} B stage files, arrays.bin {} B)",
        if public_tables { "values" } else { "length + digest" },
        super::super::run::peak_rss_mib() / 1024.0,
        dir.display(),
        bundle.stages.iter().map(|s| s.len()).collect::<Vec<_>>(),
        bundle.arrays.blob().len()
    );
}

/// **CAPTURE A TINYLLAMA TOKEN RUN (the R2 geometry)** — TinyLlama T32, the
/// public-row variant, mode (i), the R2 export and tables. `#[ignore]`d:
/// launched under the guard by whoever wants a bundle.
///
/// | variable | what | default |
/// |---|---|---|
/// | `HL_PB_CAPTURE_DIR` | where the bundle goes | **required**, absolute, outside the repository |
/// | `HL_PB_CAPTURE_BLOCKS` | `L` (22 is the whole model; 1 and 2 are the quick rungs) | 2 |
/// | `HL_PB_FIRST_LAYER` | the first layer | 0 |
/// | `HL_PB_TOKEN_INPUT` | `dense` (the R2 demo's ho00 ids) or `fixed` (T copies of BOS, id 1) | `dense` |
/// | `HL_RUN_CAPTURE_PUBLIC_TABLES` | `1` the public tables' values, `0` length + digest | **required** |
/// | `HL_TEST_SOURCE_COMMIT` | the commit the bundle records | `uncommitted-test` |
/// | `TOKEN_IO_R2_EXPORT` / `TOKEN_IO_R2_INPUTS` | the export / the head tables | the R2 demo's |
#[test]
#[ignore = "writes a TinyLlama token-run capture; set HL_PB_CAPTURE_DIR (outside the repo) and HL_RUN_CAPTURE_PUBLIC_TABLES"]
fn capture_a_tinyllama_token_run() {
    let export = PathBuf::from(env_or("TOKEN_IO_R2_EXPORT", "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128"));
    let inputs = PathBuf::from(env_or("TOKEN_IO_R2_INPUTS", "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r2_inputs"));
    capture_token_export(
        "tinyllama-t32",
        &export,
        &export,
        &inputs,
        "ho00",
        "HL_PB_CAPTURE_DIR=<dir> HL_PB_CAPTURE_BLOCKS=<L> HL_PB_FIRST_LAYER=<k> HL_PB_TOKEN_INPUT=<dense|fixed> HL_RUN_CAPTURE_PUBLIC_TABLES=<1|0> cargo test --release --lib private_block::token_io::capture_tests::capture_a_tinyllama_token_run -- --ignored --nocapture",
    );
}

/// **CAPTURE A LLAMA-3-8B TOKEN RUN (the 8B T32 token geometry)**, with the
/// same variables; the export defaults to the fidelity lane's b7voc0_T32
/// (`HL_PB_TOKEN_EXPORT` overrides; its tables are `<export>/token_io/`).
/// The endpoint, IN and OUT geometry is what is new, so a reduced `L` (1
/// block) is what the 15 GiB box is asked for; the peak is printed.
#[test]
#[ignore = "writes a Llama-3-8B token-run capture; heavy; set HL_PB_CAPTURE_DIR (outside the repo) and HL_RUN_CAPTURE_PUBLIC_TABLES"]
fn capture_a_llama3_8b_token_run() {
    let export = PathBuf::from(env_or("HL_PB_TOKEN_EXPORT", "/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32"));
    let tio = export.join("token_io");
    capture_token_export(
        "llama3-8b-t32",
        &export,
        &tio,
        &tio,
        "ho00",
        "HL_PB_CAPTURE_DIR=<dir> HL_PB_CAPTURE_BLOCKS=<L> HL_PB_FIRST_LAYER=<k> HL_PB_TOKEN_INPUT=<dense|fixed> HL_RUN_CAPTURE_PUBLIC_TABLES=<1|0> cargo test --release --lib private_block::token_io::capture_tests::capture_a_llama3_8b_token_run -- --ignored --nocapture",
    );
}

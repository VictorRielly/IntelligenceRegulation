//! Guarded public synthetic R14 streaming and fresh-verifier fixtures.
use super::split_definition_tests::{calibration, data, public};
use super::*;
use crate::ntt::NttTables;
use crate::private_block::{
    protocol, shape, split_endpoint,
    split_profile::SplitProfile,
    split_run, trained_statement,
    witness::{self, Witness},
    BlockPublic,
};

fn fixture(
    dd: bool,
) -> (
    Shape,
    Vec<BlockPublic>,
    trained_statement::TrainedModelStatement,
) {
    let base = if dd {
        shape::R13_SHIELD_T128_H24_DD
    } else {
        shape::R13_SHIELD_T128_H24
    };
    let sh = Shape::accuracy_trained(base, &calibration(), 9, 20).unwrap();
    let (mut a, mut f) = public(&sh);
    a.rope_cos.fill(1i64 << F_RO);
    a.exp.fill(1i64 << sh.f_e);
    for j in 0..sh.width {
        a.gamma_a[j] = ((j % 255) as i16 - 127) as i8;
        f.gamma_m[j] = a.gamma_a[j];
    }
    let block = BlockPublic::new(a, f).with_accuracy(data(&sh));
    let blocks = vec![block.clone(), block];
    let mut model = trained_statement::accuracy_hash_model(&sh, 2);
    let digest = blocks[0].digest();
    for record in &mut model.layers {
        record.block_digest = digest;
    }
    let mut next = sh.norm_calibration();
    next.cn_a += 1;
    model.layers[1].own = trained_statement::own_of(&sh.norm_calibration(), &next);
    (sh, blocks, model)
}
fn pieces(sh: &Shape, p: &SplitProfile, w: &Witness, parent: usize) -> [Vec<Fp>; 2] {
    crate::private_block::split_geometry::gather_numeric_plane(
        sh,
        p.layout(),
        parent,
        &w.planes[parent],
    )
    .unwrap()
    .into_iter()
    .map(|(_, v)| v.into_iter().map(Fp::from_i64).collect())
    .collect::<Vec<_>>()
    .try_into()
    .unwrap()
}
fn dense(sh: &Shape, w: &Witness, parent: usize) -> Vec<i16> {
    (0..sh.tokens)
        .flat_map(|t| {
            (0..sh.width).map(move |j| i16::try_from(w.planes[parent][t * sh.d_pad + j]).unwrap())
        })
        .collect()
}
struct Source<'a> {
    first: Option<Witness>,
    next: Shape,
    input: Vec<i16>,
    blocks: &'a [BlockPublic],
    boundary: [Vec<Fp>; 2],
    forge: bool,
}
impl split_run::WitnessSource for Source<'_> {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        match k {
            0 => self
                .first
                .take()
                .ok_or_else(|| "fixture first witness consumed".into()),
            1 => witness::build_for_block(&self.next, &self.blocks[1], &self.input),
            _ => Err("fixture has only2 stages".into()),
        }
    }
    fn boundary_pieces(&mut self, index: usize) -> Result<[Vec<Fp>; 2], String> {
        if index != 1 {
            return Err("fixture has only1 internal boundary".into());
        }
        let mut values = self.boundary.clone();
        if self.forge {
            values[1][0] = values[1][0].add(Fp::ONE);
        }
        Ok(values)
    }
}
fn verify(
    st: &split_run::Statement,
    blocks: &[BlockPublic],
    frames: &[Vec<u8>],
) -> Result<(), String> {
    let mut v = split_run::Verifier::new(st, blocks)?;
    for bytes in frames {
        v.verify_next(bytes)?;
    }
    v.finish()
}

fn prove_case(dd: bool, forge: bool) {
    let (sh, blocks, model) = fixture(dd);
    let scales = vec![model.calibration.block_scales; 2];
    let plan = split_run::Plan::new(sh.clone(), [107; 32], &model, &blocks, &scales).unwrap();
    let next = model.layers[1].shape_at(&sh).unwrap();
    let input = (0..sh.tokens * sh.width)
        .map(|j| if j % 2 == 0 { 1i16 } else { -1i16 })
        .collect::<Vec<_>>();
    let ids = Ids::new(&sh).unwrap();
    let first = witness::build_for_block(&sh, &blocks[0], &input).unwrap();
    let ins = pieces(&sh, plan.stage(0).unwrap(), &first, ids.at(A_X));
    let boundary = pieces(&sh, plan.stage(0).unwrap(), &first, ids.at(A_X2));
    let intermediate = dense(&sh, &first, ids.at(A_X2));
    // Only the first witness is retained. Recompute the second on demand
    // after the first stage frees it, retaining the native lean-memory rule.
    let second = witness::build_for_block(&next, &blocks[1], &intermediate).unwrap();
    let outs = pieces(&next, plan.stage(1).unwrap(), &second, ids.at(A_X2));
    drop(second);
    let sin = plan.endpoint(false).unwrap();
    let sout = plan.endpoint(true).unwrap();
    let ntt = NttTables::new(protocol::ntt_log_at(&sh));
    let ein = split_endpoint::prepare(&sin, [&ins[0], &ins[1]], &ntt).unwrap();
    let eout = split_endpoint::prepare(&sout, [&outs[0], &outs[1]], &ntt).unwrap();
    let ri = ein.commitment().root;
    let ro = eout.commitment().root;
    let st = plan.bind(ri, ro).unwrap();
    let mut source = Source {
        first: Some(first),
        next,
        input: intermediate,
        blocks: &blocks,
        boundary,
        forge,
    };
    let mut frames = Vec::new();
    split_run::prove(&st, &blocks, &mut source, [ein, eout], &mut |k, bytes| {
        assert_eq!(k, frames.len());
        frames.push(bytes);
        Ok(())
    })
    .unwrap();
    assert_eq!(frames.len(), 2);
    if forge {
        let error = verify(&st, &blocks, &frames)
            .expect_err("R14 streaming proof accepted a changed narrow boundary word");
        assert!(
            error.contains("slot 30") && error.contains("sumcheck round 0"),
            "boundary forgery failed outside the intended native narrow IO constraint: {error}"
        );
    } else {
        verify(&st, &blocks, &frames).unwrap();
        let mut swapped = split_run::Verifier::new(&st, &blocks).unwrap();
        assert!(swapped.verify_next(&frames[1]).is_err());
        assert!(swapped.finish().is_err());
        let mut dropped = split_run::Verifier::new(&st, &blocks).unwrap();
        dropped.verify_next(&frames[0]).unwrap();
        assert!(dropped.finish().is_err());
        if let Ok(path) = std::env::var("HL_R14_RUN_OUTPUT") {
            let dir = std::path::PathBuf::from(path);
            assert!(!dir.exists(), "do not overwrite a retained receipt fixture");
            std::fs::create_dir_all(&dir).unwrap();
            for (k, bytes) in frames.iter().enumerate() {
                std::fs::write(dir.join(format!("segment{k}.bin")), bytes).unwrap();
            }
            let hex = |v: &[u8]| v.iter().map(|b| format!("{b:02x}")).collect::<String>();
            let metadata = serde_json::json!({"format":"R14-public-synthetic-stream-fixture/1","dd":dd,"stages":2,"context":hex(&[107;32]),
                "model_identity":hex(&model.identity()),"input_root":hex(&ri),"output_root":hex(&ro),"binding":hex(&st.binding()),
                "scope":"public synthetic native R14 component with native test-only model waiver; not an approved trained model or privacy acceptance"});
            std::fs::write(
                dir.join("statement.json"),
                serde_json::to_vec_pretty(&metadata).unwrap(),
            )
            .unwrap();
        }
    }
    eprintln!("R14_NATIVE_STREAM {{\"tokens\":128,\"dd\":{},\"blocks\":2,\"narrow_boundary_forgery\":{},\"bytes\":{:?},\"scope\":\"new native run/segment path, public synthetic model with explicit native test waiver; no trained-model/privacy acceptance\"}}",dd,forge,frames.iter().map(Vec::len).collect::<Vec<_>>());
}

#[test]
#[ignore = "guarded R14 T1282block streaming proof,9.5GiB; public synthetic only"]
fn split_run_t128_non_dd_serialized_two_blocks_with_own_calibration_verify() {
    prove_case(false, false)
}
#[test]
#[ignore = "guarded R14 T1282block streaming proof,9.5GiB; public synthetic only"]
fn split_run_t128_dd_serialized_two_blocks_with_own_calibration_verify() {
    prove_case(true, false)
}
#[test]
#[ignore = "guarded emitted R14 narrow-boundary malicious receipt,9.5GiB"]
fn split_run_t128_non_dd_narrow_boundary_forgery_emits_and_refuses() {
    prove_case(false, true)
}
#[test]
#[ignore = "guarded emitted R14 narrow-boundary malicious receipt,9.5GiB"]
fn split_run_t128_dd_narrow_boundary_forgery_emits_and_refuses() {
    prove_case(true, true)
}

fn parse_digest(v: &serde_json::Value, key: &str) -> Result<[u8; 32], String> {
    let text = v
        .get(key)
        .and_then(serde_json::Value::as_str)
        .ok_or_else(|| format!("fixture metadata missing {key}"))?;
    if text.len() != 64 || !text.is_ascii() {
        return Err(format!("fixture digest {key} length/class"));
    }
    let mut out = [0; 32];
    for (i, b) in out.iter_mut().enumerate() {
        *b = u8::from_str_radix(&text[2 * i..2 * i + 2], 16)
            .map_err(|_| format!("fixture digest {key} encoding"))?;
    }
    Ok(out)
}
fn read_file(path: &std::path::Path, exact: Option<usize>, cap: usize) -> Result<Vec<u8>, String> {
    let meta = std::fs::symlink_metadata(path).map_err(|e| e.to_string())?;
    if !meta.is_file() || meta.len() > cap as u64 || exact.is_some_and(|n| meta.len() != n as u64) {
        return Err("fixture file is not bounded regular exact-size input".into());
    }
    let bytes = std::fs::read(path).map_err(|e| e.to_string())?;
    if bytes.len() as u64 != meta.len() {
        return Err("fixture file changed during read".into());
    }
    Ok(bytes)
}
fn fresh_verify(dd: bool) -> Result<(), String> {
    let path = std::env::var("HL_R14_RUN_INPUT")
        .map_err(|_| "explicit public synthetic fixture directory required")?;
    let dir = std::path::PathBuf::from(path);
    let metadata: serde_json::Value =
        serde_json::from_slice(&read_file(&dir.join("statement.json"), None, 8192)?)
            .map_err(|e| e.to_string())?;
    if metadata["format"] != "R14-public-synthetic-stream-fixture/1"
        || metadata["dd"] != dd
        || metadata["stages"] != 2
    {
        return Err("fixture metadata differs from verifier-owned variant".into());
    }
    let (sh, blocks, model) = fixture(dd);
    if parse_digest(&metadata, "model_identity")? != model.identity()
        || parse_digest(&metadata, "context")? != [107; 32]
    {
        return Err("fixture metadata differs from verifier-owned model/context".into());
    }
    let scales = vec![model.calibration.block_scales; 2];
    let plan = split_run::Plan::new(sh, [107; 32], &model, &blocks, &scales)?;
    let st = plan.bind(
        parse_digest(&metadata, "input_root")?,
        parse_digest(&metadata, "output_root")?,
    )?;
    if st.binding() != parse_digest(&metadata, "binding")? {
        return Err("fixture routing binding differs from verifier derivation".into());
    }
    let mut v = split_run::Verifier::new(&st, &blocks)?;
    for k in 0..2 {
        let len = crate::private_block::wire::split::Geometry::new(st.plan().stage(k)?, 2, k)?
            .encoded_len();
        v.verify_next(&read_file(
            &dir.join(format!("segment{k}.bin")),
            Some(len),
            256 * 1024 * 1024,
        )?)?;
    }
    v.finish()?;
    eprintln!("R14_FRESH_NATIVE_STREAM {{\"dd\":{},\"blocks\":2,\"status\":\"PASS\",\"scope\":\"fresh-process native R14 verifier, public synthetic metadata fixture with explicit test waiver; not CLI or approved trained model\"}}",dd);
    Ok(())
}
#[test]
#[ignore = "separate guarded fresh-process R14 verifier; explicit HL_R14_RUN_INPUT"]
fn split_run_t128_non_dd_fresh_verify_from_dir() {
    fresh_verify(false).unwrap()
}
#[test]
#[ignore = "separate guarded fresh-process R14 verifier; explicit HL_R14_RUN_INPUT"]
fn split_run_t128_dd_fresh_verify_from_dir() {
    fresh_verify(true).unwrap()
}
#[test]
#[ignore = "separate guarded fresh-process corrupt canonical R14 stream refusal"]
fn split_run_t128_non_dd_fresh_rejects_corrupt_stream() {
    let error =
        fresh_verify(false).expect_err("fresh verifier accepted corrupted R14 native stream");
    assert!(
        error.contains("sumcheck round 0"),
        "corrupt stream failed outside its native scalar check: {error}"
    );
}
#[test]
#[ignore = "separate guarded fresh-process corrupt canonical R14 stream refusal"]
fn split_run_t128_dd_fresh_rejects_corrupt_stream() {
    let error =
        fresh_verify(true).expect_err("fresh verifier accepted corrupted R14 native stream");
    assert!(
        error.contains("sumcheck round 0"),
        "corrupt stream failed outside its native scalar check: {error}"
    );
}

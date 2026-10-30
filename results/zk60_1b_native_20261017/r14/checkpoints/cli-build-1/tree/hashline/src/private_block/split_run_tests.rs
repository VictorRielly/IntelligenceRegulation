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
const FIXTURE_HELPERS_SHA256: &str =
    "9bce20f3bc9f97592db66bbbef9a307529604dbf46980bac9dce43c3a1ad8c96";

pub(super) fn fixture(
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
pub(super) fn pieces(sh: &Shape, p: &SplitProfile, w: &Witness, parent: usize) -> [Vec<Fp>; 2] {
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
pub(super) fn verify(
    st: &split_run::Statement,
    blocks: &[BlockPublic],
    frames: &[Vec<u8>],
) -> Result<(), String> {
    let mut v = split_run::Verifier::new(st, blocks)?;
    for bytes in frames {
        v.verify_next(bytes)?;
    }
    v.finish()?;
    if std::env::var("HL_R14_STREAM_SOURCE_CONTROLS").as_deref() == Ok("1") {
        super::split_streaming_tests::verify_source_controls(st, blocks, frames)?;
    }
    Ok(())
}

pub(super) fn prove_case(dd: bool, forge: bool) {
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
    let tick = std::time::Instant::now();
    let mut emit = |k, bytes| {
        assert_eq!(k, frames.len());
        frames.push(bytes);
        Ok(())
    };
    if std::env::var("HL_R14_STREAM_SOURCE_CONTROLS").as_deref() == Ok("1") {
        let (mut public, metrics) = super::split_streaming_tests::OneBlockSource::new(&blocks);
        split_run::prove_with_source(&st, &mut public, &mut source, [ein, eout], &mut emit)
            .unwrap();
        drop(public);
        assert_eq!(metrics.borrow().max_live, 1);
        assert!(metrics
            .borrow()
            .allocated
            .iter()
            .all(|w| w.strong_count() == 0));
        eprintln!("R14_STREAM_SOURCE_PROVE stages=2 peak_owned_public_blocks=1");
    } else {
        split_run::prove(&st, &blocks, &mut source, [ein, eout], &mut emit).unwrap();
    }
    let prove_seconds = tick.elapsed().as_secs_f64();
    let prove_hwm_mib = crate::private_block::run::peak_rss_mib();
    assert_eq!(frames.len(), 2);
    let tick = std::time::Instant::now();
    let verified = verify(&st, &blocks, &frames);
    let verify_seconds = tick.elapsed().as_secs_f64();
    if forge {
        let error =
            verified.expect_err("R14 streaming proof accepted a changed narrow boundary word");
        assert!(
            error.contains("slot 30") && error.contains("sumcheck round 0"),
            "boundary forgery failed outside the intended native narrow IO constraint: {error}"
        );
    } else {
        verified.unwrap();
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
            let metadata=format!("R14-public-synthetic-stream-fixture/1\ndd={}\nstages=2\ncontext={}\nmodel_identity={}\ninput_root={}\noutput_root={}\nbinding={}\nscope=public synthetic native test waiver, no trained-model or privacy acceptance\n",
                usize::from(dd),hex(&[107;32]),hex(&model.identity()),hex(&ri),hex(&ro),hex(&st.binding()));
            std::fs::write(dir.join("statement.txt"), metadata).unwrap();
        }
    }
    let hex = |d: &[u8]| d.iter().map(|b| format!("{b:02x}")).collect::<String>();
    eprintln!("R14_NATIVE_STREAM {{\"tokens\":128,\"dd\":{},\"blocks\":2,\"narrow_boundary_forgery\":{},\"prove_seconds\":{},\"verify_seconds\":{},\"prove_hwm_mib\":{},\"bytes\":{:?},\"model_identity\":{:?},\"block_digest\":{:?},\"fixture_helpers_sha256\":{:?},\"scope\":\"new native run/segment path, public synthetic model with explicit native test waiver; prove timer excludes endpoint/setup and later controls, includes on-demand second witness; n1 sharedhost, no trained-model/privacy acceptance\"}}",dd,forge,prove_seconds,verify_seconds,prove_hwm_mib,frames.iter().map(Vec::len).collect::<Vec<_>>(),hex(&model.identity()),hex(&blocks[0].digest()),FIXTURE_HELPERS_SHA256);
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

pub(super) fn parse_digest(
    v: &std::collections::BTreeMap<&str, &str>,
    key: &str,
) -> Result<[u8; 32], String> {
    let text = v
        .get(key)
        .copied()
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
pub(super) fn read_file(
    path: &std::path::Path,
    exact: Option<usize>,
    cap: usize,
) -> Result<Vec<u8>, String> {
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
    let bytes = read_file(&dir.join("statement.txt"), None, 8192)?;
    let text = std::str::from_utf8(&bytes).map_err(|e| e.to_string())?;
    let mut lines = text.lines();
    if lines.next() != Some("R14-public-synthetic-stream-fixture/1") {
        return Err("fixture metadata format differs".into());
    }
    let mut metadata = std::collections::BTreeMap::new();
    for line in lines {
        let (key, value) = line
            .split_once('=')
            .ok_or("fixture metadata field encoding")?;
        if metadata.insert(key, value).is_some() {
            return Err("fixture metadata duplicate field".into());
        }
    }
    if metadata.len() != 8
        || metadata.get("dd").copied() != Some(if dd { "1" } else { "0" })
        || metadata.get("stages").copied() != Some("2")
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

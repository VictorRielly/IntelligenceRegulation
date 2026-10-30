//! Native observer tests: public seed and rejected-run suppression first;
//! a separately guarded three-stage capture follows.
use super::split_run_tests::{fixture, pieces};
use super::*;
use crate::ntt::NttTables;
use crate::private_block::{
    protocol,
    run_capture::split as cap,
    split_endpoint,
    split_profile::SplitProfile,
    split_run, trained_statement,
    witness::{self, Witness},
    BlockPublic,
};

fn statement() -> (split_run::Statement, Vec<BlockPublic>) {
    let (sh, blocks, model) = fixture(false);
    let scales = vec![model.calibration.block_scales; 2];
    let plan = split_run::Plan::new(sh, [107; 32], &model, &blocks, &scales).unwrap();
    (plan.bind([37; 32], [41; 32]).unwrap(), blocks)
}
#[test]
fn split_capture_public_seed_matches_native_and_changed_context_refuses_replay() {
    cap::discard();
    let (st, _) = statement();
    cap::begin(st.capture_header().unwrap()).unwrap();
    assert!(cap::seed_matches(&st.transcript()));
    assert!(cap::take().unwrap_err().contains("unaccepted"));
    let mut header = st.capture_header().unwrap();
    header.context[0] ^= 1;
    cap::begin(header).unwrap();
    assert!(!cap::seed_matches(&st.transcript()));
    cap::stage_begin(0, Some([43; 32]), &st.transcript());
    assert!(cap::take().unwrap_err().contains("replay differs"));
}
#[test]
fn split_capture_rejected_or_incomplete_run_cannot_return_a_bundle() {
    cap::discard();
    let (st, blocks) = statement();
    cap::begin(st.capture_header().unwrap()).unwrap();
    let mut verifier = split_run::Verifier::new(&st, &blocks).unwrap();
    assert!(verifier.verify_next(&[]).is_err());
    assert!(verifier.finish().is_err());
    assert!(cap::take().unwrap_err().contains("unaccepted"));
    assert!(cap::checkpoint(&st.transcript()).is_none());
}
fn dense(sh: &Shape, w: &Witness, parent: usize) -> Vec<i16> {
    (0..sh.tokens)
        .flat_map(|t| {
            (0..sh.width).map(move |j| i16::try_from(w.planes[parent][t * sh.d_pad + j]).unwrap())
        })
        .collect()
}
struct Chain<'a> {
    profiles: Vec<SplitProfile>,
    blocks: &'a [BlockPublic],
    input: Vec<i16>,
    next: usize,
    cached: Option<Witness>,
}
impl Chain<'_> {
    fn ensure(&mut self, k: usize) -> Result<(), String> {
        if k != self.next {
            return Err("capture chain source order".into());
        }
        if self.cached.is_none() {
            self.cached = Some(witness::build_for_block(
                self.profiles[k].base(),
                &self.blocks[k],
                &self.input,
            )?);
        }
        Ok(())
    }
}
impl split_run::WitnessSource for Chain<'_> {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.ensure(k)?;
        let w = self.cached.take().unwrap();
        let sh = self.profiles[k].base();
        self.input = dense(sh, &w, Ids::new(sh)?.at(A_X2));
        self.next += 1;
        Ok(w)
    }
    fn boundary_pieces(&mut self, index: usize) -> Result<[Vec<Fp>; 2], String> {
        if index != self.next + 1 {
            return Err("capture boundary source index".into());
        }
        self.ensure(index - 1)?;
        let p = &self.profiles[index - 1];
        Ok(pieces(
            p.base(),
            p,
            self.cached.as_ref().unwrap(),
            Ids::new(p.base())?.at(A_X2),
        ))
    }
}
fn verify(
    st: &split_run::Statement,
    blocks: &[BlockPublic],
    frames: &[Vec<u8>],
) -> Result<(), String> {
    let mut v = split_run::Verifier::new(st, blocks)?;
    for b in frames {
        v.verify_next(b)?;
    }
    v.finish()
}
#[test]
#[ignore = "guarded native three-stage R14 capture; explicit HL_R14_DD and HL_R14_CAPTURE_OUTPUT"]
fn split_capture_t128_three_stage_native_verifier_view_and_rejected_bundle_suppression() {
    cap::discard();
    let dd = match std::env::var("HL_R14_DD").unwrap().as_str() {
        "0" => false,
        "1" => true,
        _ => panic!("DD0/1"),
    };
    let (sh, base, _) = fixture(dd);
    let blocks = vec![base[0].clone(); 3];
    let mut model = trained_statement::accuracy_hash_model(&sh, 3);
    for (k, record) in model.layers.iter_mut().enumerate() {
        record.block_digest = blocks[k].digest();
        if k > 0 {
            let mut own = sh.norm_calibration();
            own.cn_a += k as i64;
            record.own = trained_statement::own_of(&sh.norm_calibration(), &own);
        }
    }
    let scales = vec![model.calibration.block_scales; 3];
    let plan = split_run::Plan::new(sh.clone(), [217; 32], &model, &blocks, &scales).unwrap();
    let input = (0..sh.tokens * sh.width)
        .map(|j| if j % 2 == 0 { 1i16 } else { -1 })
        .collect::<Vec<_>>();
    let mut last = input.clone();
    let mut outs = None;
    for (k, block) in blocks.iter().enumerate() {
        let p = plan.stage(k).unwrap();
        let w = witness::build_for_block(p.base(), block, &last).unwrap();
        let parent = Ids::new(p.base()).unwrap().at(A_X2);
        if k == 2 {
            outs = Some(pieces(p.base(), p, &w, parent));
        }
        last = dense(p.base(), &w, parent);
    }
    let outs = outs.unwrap();
    let mut ins = [Vec::new(), Vec::new()];
    for t in 0..sh.tokens {
        ins[0].extend(
            input[t * sh.width..t * sh.width + 2048]
                .iter()
                .map(|&v| Fp::from_i64(v as i64)),
        );
        ins[1].extend(
            input[t * sh.width + 2048..(t + 1) * sh.width]
                .iter()
                .map(|&v| Fp::from_i64(v as i64)),
        );
    }
    let ntt = NttTables::new(protocol::ntt_log_at(&sh));
    let ein =
        split_endpoint::prepare(&plan.endpoint(false).unwrap(), [&ins[0], &ins[1]], &ntt).unwrap();
    let eout =
        split_endpoint::prepare(&plan.endpoint(true).unwrap(), [&outs[0], &outs[1]], &ntt).unwrap();
    let st = plan
        .bind(ein.commitment().root, eout.commitment().root)
        .unwrap();
    let profiles = (0..3)
        .map(|k| SplitProfile::new(st.plan().stage(k).unwrap().base().clone()).unwrap())
        .collect();
    let mut source = Chain {
        profiles,
        blocks: &blocks,
        input,
        next: 0,
        cached: None,
    };
    let mut frames = Vec::new();
    split_run::prove(&st, &blocks, &mut source, [ein, eout], &mut |k, b| {
        assert_eq!(k, frames.len());
        frames.push(b);
        Ok(())
    })
    .unwrap();
    assert_eq!(frames.len(), 3);
    verify(&st, &blocks, &frames).unwrap();
    cap::begin(st.capture_header().unwrap()).unwrap();
    verify(&st, &blocks, &frames).unwrap();
    let bundle = cap::take().unwrap();
    assert_eq!(bundle.stages.len(), 3);
    assert!(!bundle.arrays.is_empty());
    let output = std::path::PathBuf::from(std::env::var("HL_R14_CAPTURE_OUTPUT").unwrap());
    assert!(!output.exists());
    std::fs::create_dir_all(&output).unwrap();
    std::fs::write(output.join("run.json"), bundle.run_json).unwrap();
    std::fs::write(output.join("arrays.bin"), bundle.arrays).unwrap();
    for (k, b) in bundle.stages.into_iter().enumerate() {
        std::fs::write(output.join(format!("stage{k}.json")), b).unwrap();
    }
    for (k, b) in frames.iter().enumerate() {
        std::fs::write(output.join(format!("segment{k}.bin")), b).unwrap();
    }
    // A canonical scalar forgery must not yield any accepted capture bundle.
    let offset = 120 + 32 + 96;
    let old = u64::from_le_bytes(frames[0][offset..offset + 8].try_into().unwrap());
    assert!(old < 0xffffffff00000001);
    frames[0][offset..offset + 8].copy_from_slice(&((old + 1) % 0xffffffff00000001).to_le_bytes());
    cap::begin(st.capture_header().unwrap()).unwrap();
    let error = verify(&st, &blocks, &frames).unwrap_err();
    assert!(error.contains("sumcheck round 0"));
    assert!(cap::take().is_err());
    eprintln!("R14_NATIVE_CAPTURE {{\"dd\":{},\"stages\":3,\"schema\":{:?},\"status\":\"native accepted view replayed; same receipt accepted without recorder; rejected scalar forgery produced no bundle\",\"scope\":\"public synthetic native capture only; no rank/NL1/privacy acceptance\"}}",dd,cap::SCHEMA_SPLIT);
}

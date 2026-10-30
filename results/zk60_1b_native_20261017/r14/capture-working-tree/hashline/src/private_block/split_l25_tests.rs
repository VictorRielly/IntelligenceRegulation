//! Exact19-site independent actual-S2 oracle through the physical R14 witness,
//! followed optionally by a strict-model native one-stage R14 receipt.
use super::*;
use crate::ntt::NttTables;
use crate::private_block::{
    protocol, split_endpoint,
    split_layout::Part,
    split_profile::SplitProfile,
    split_run,
    split_witness::PieceWitness,
    trained_block::{hex, sha256, TrainedExport},
    trained_statement::TrainedModelStatement,
    witness::{self, Witness},
    BlockPublic,
};

const EXPECTED: [(&str, usize, &str); 19] = [
    (
        "input",
        A_X,
        "f2cf0593048fbe1506312675394e97e665b40c533195769c1948b4a5d82f85c3",
    ),
    (
        "y",
        A_Y,
        "8c1bc7dfe96371c7381cf4a60f7a99090fc621a623e7f30650cd3bf3a54efef0",
    ),
    (
        "q",
        A_Q8,
        "482d1798482499cead622d83cfbedc8c403e1065e9073894bdfc59f358b5d9f1",
    ),
    (
        "k",
        A_K8,
        "9e017ead8c0c3475f05bc5643fa44872fa29546546fe2aecfd87f00c697e4cd4",
    ),
    (
        "v",
        A_V8,
        "97de303048743627d1d1e448d59f20999c36f79e25dfc290b805585e6d7cb662",
    ),
    (
        "qr",
        A_QR8,
        "c9f3669618aa8eefd14cdc5db02ac50bd70704d99a8d403c8b0a8ce714b1b64e",
    ),
    (
        "kr",
        A_KR8,
        "5c5494b97b7d52220cd242245603a979ffcf2dc3ddf46131e7e223155f74b9a3",
    ),
    (
        "s",
        A_S8,
        "1f1ea848fba7ac122ed9015bdf27fa20837ff5b1aa94d94fd033d2c7b97ffd43",
    ),
    (
        "p",
        A_P,
        "5218292cf60841e256bf4758bab1cd25d391a3caed2da66af4116224c665a9ff",
    ),
    (
        "o",
        A_O8,
        "f19994e4f6aad515c1e190c96785d98a86f28e7620d428a22f081c4582d07ea4",
    ),
    (
        "ao",
        A_AO,
        "3d25f3bd6791ff42df5ebd4f2e0364e5775b3ee2ee6ec0a200ec97da2acfdb0d",
    ),
    (
        "x1",
        A_X1,
        "6c1407e2a02387b7e74f20e34c9413df79b360e9a400b630083a4e9abc49e5d1",
    ),
    (
        "nm",
        A_YM,
        "eb4d3b94ddf1bf88da93ef540747e6bd7a8faddc0d7888c49153f140090d20fe",
    ),
    (
        "gate",
        A_G8,
        "db11d47d7296f1caf8e76a4fe9573067510110171b03de51615377a8cf6149da",
    ),
    (
        "a_scaled",
        A_A16,
        "c75d3b7bf74ec5e2b07d37aeb5dd884796eca05acb475c523ac96b18c0898d14",
    ),
    (
        "up",
        A_U16,
        "b2a508276bd4a90ebb8b2a710b407df5ce4c65376351f8c32f9376a9ae404b1e",
    ),
    (
        "h",
        A_H16,
        "d033f3649b815155a9b41651023dc4e5309955e2f0f3ea3ebd8b250a63eea484",
    ),
    (
        "z",
        A_Z16,
        "dd3c8c9b1de86c3fe565eddc6938dc7c637d6ed64114f551e0fb5b0a31e7570f",
    ),
    (
        "x2",
        A_X2,
        "d16c6a96749fd7e05a2e8abb8d5f964cd4fdb7bd5b27b07a440cc5b1a48c33a7",
    ),
];
fn variant() -> bool {
    match std::env::var("HL_R14_DD").unwrap().as_str() {
        "0" => false,
        "1" => true,
        _ => panic!("explicit DD0/1"),
    }
}
fn load(dd: bool) -> (Shape, BlockPublic, TrainedModelStatement) {
    let root = std::path::PathBuf::from(
        std::env::var("HL_R14_ACTUAL_L25_EXPORT")
            .expect("explicit immutable actual S2 export required"),
    );
    assert_eq!(
        hex(&sha256(&std::fs::read(root.join("profile.json")).unwrap())),
        "2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0"
    );
    let mut ex = TrainedExport::load(&root).unwrap();
    ex.accuracy_dd = dd;
    let c = ex.run_constants(&[25]).unwrap();
    let seed = ex.shape_for(&c).unwrap();
    let layer = ex.load_layer(&seed, &c, 25, false).unwrap();
    let sh = layer.record.shape_at(&seed).unwrap();
    assert_eq!((sh.tokens, sh.width, sh.hidden), (128, 3072, 9216));
    let model = ex.statement(&seed, &c, &[&layer]).unwrap();
    assert!(
        !model.test_synthetic_waiver,
        "actual proof enabled synthetic waiver"
    );
    (sh, layer.blk, model)
}
fn native_dense(sh: &Shape, dom: Dom, words: &[i64]) -> Vec<i64> {
    assert_eq!(words.len(), sh.size(dom));
    let mut out = Vec::new();
    match dom {
        Dom::D | Dom::F => {
            let (pad, width) = if dom == Dom::D {
                (sh.d_pad, sh.width)
            } else {
                (sh.f_pad, sh.hidden)
            };
            for t in 0..sh.tokens {
                out.extend_from_slice(&words[t * pad..t * pad + width]);
            }
        }
        Dom::Q => {
            for t in 0..sh.tokens {
                for h in 0..sh.q_heads {
                    let start = t * sh.q_pad() + sh.head_slot(h) * sh.head_dim;
                    out.extend_from_slice(&words[start..start + sh.head_dim]);
                }
            }
        }
        Dom::Kv => out.extend_from_slice(&words[..sh.tokens * sh.kv_heads * sh.head_dim]),
        Dom::S => {
            for h in 0..sh.q_heads {
                for t in 0..sh.tokens {
                    let start = (sh.head_slot(h) * sh.t_pad + t) * sh.t_pad;
                    out.extend_from_slice(&words[start..start + sh.tokens]);
                }
            }
        }
        _ => panic!("not an oracle trace domain"),
    }
    out
}
fn piece_dense(p: &SplitProfile, w: &PieceWitness, parent: usize) -> Vec<i64> {
    let sh = p.base();
    let dom = Ids::new(sh).unwrap().dom(parent);
    if !matches!(dom, Dom::D | Dom::F) {
        return native_dense(sh, dom, w.plane(p, parent, Part::Whole).unwrap());
    }
    let ext = if dom == Dom::D {
        p.layout().d
    } else {
        p.layout().f
    };
    let wide = w.plane(p, parent, Part::Wide).unwrap();
    let narrow = w.plane(p, parent, Part::Narrow).unwrap();
    let mut out = Vec::with_capacity(sh.tokens * (ext[0].width + ext[1].width));
    for t in 0..sh.tokens {
        for (v, e) in [(wide, ext[0]), (narrow, ext[1])] {
            out.extend_from_slice(&v[t * e.width..(t + 1) * e.width]);
        }
    }
    out
}
fn digest(v: &[i64]) -> String {
    hex(&sha256(
        &v.iter().flat_map(|v| v.to_le_bytes()).collect::<Vec<_>>(),
    ))
}
struct One(Option<Witness>);
impl split_run::WitnessSource for One {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        if k != 0 {
            return Err("one actual layer only".into());
        }
        self.0.take().ok_or("actual witness consumed".into())
    }
    fn boundary_pieces(&mut self, _: usize) -> Result<[Vec<Fp>; 2], String> {
        Err("no internal actual boundary".into())
    }
}
fn plan(sh: Shape, blk: &BlockPublic, model: &TrainedModelStatement) -> split_run::Plan {
    split_run::Plan::new(
        sh,
        [225; 32],
        model,
        &[blk.clone()],
        &[model.calibration.block_scales],
    )
    .unwrap()
}
fn verify(st: &split_run::Statement, blk: &BlockPublic, frame: &[u8]) -> Result<(), String> {
    let blocks = [blk.clone()];
    let mut v = split_run::Verifier::new(st, &blocks)?;
    v.verify_next(frame)?;
    v.finish()
}
#[test]
#[ignore = "guarded actual-weight T128 R14 parity/proof; explicit export/DD and optional output"]
fn split_actual_l25_t128_all19_sites_and_optional_native_proof() {
    let dd = variant();
    let (sh, blk, model) = load(dd);
    let ids = Ids::new(&sh).unwrap();
    let p = SplitProfile::new(sh.clone()).unwrap();
    let file = std::path::PathBuf::from(
        std::env::var("HL_R14_L25_INPUT").expect("retained reviewer prefix input"),
    );
    let bytes = std::fs::read(file).unwrap();
    assert_eq!(bytes.len(), 128 * 3072 * 2);
    assert_eq!(
        hex(&sha256(&bytes)),
        "e97c32bf6df17902d7383f7d585aa31582037da1ccebb02ef1e9547528d25ffa"
    );
    let input = bytes
        .chunks_exact(2)
        .map(|b| i16::from_le_bytes([b[0], b[1]]))
        .collect::<Vec<_>>();
    let w = witness::build_for_block(&sh, &blk, &input).unwrap();
    for (name, old, want) in EXPECTED {
        let parent = ids.at(old);
        let v = native_dense(&sh, ids.dom(parent), &w.planes[parent]);
        assert_eq!(digest(&v), want, "reference actual {name}");
    }
    let packed = PieceWitness::from_reference(&p, w).unwrap();
    for (name, old, want) in EXPECTED {
        let v = piece_dense(&p, &packed, ids.at(old));
        assert_eq!(digest(&v), want, "physical actual {name}");
        eprintln!("R14_ACTUAL_L25_TRACE {{\"dd\":{},\"site\":{:?},\"words\":{},\"sha256\":{:?},\"reference_and_physical_match\":true}}",dd,name,v.len(),want);
    }
    drop(packed);
    if std::env::var("HL_R14_ACTUAL_L25_PROVE").as_deref() != Ok("1") {
        return;
    }
    let w = witness::build_for_block(&sh, &blk, &input).unwrap();
    let plan = plan(sh.clone(), &blk, &model);
    let p = plan.stage(0).unwrap();
    let ins = super::split_run_tests::pieces(&sh, p, &w, ids.at(A_X));
    let outs = super::split_run_tests::pieces(&sh, p, &w, ids.at(A_X2));
    let ntt = NttTables::new(protocol::ntt_log_at(&sh));
    let ein =
        split_endpoint::prepare(&plan.endpoint(false).unwrap(), [&ins[0], &ins[1]], &ntt).unwrap();
    let eout =
        split_endpoint::prepare(&plan.endpoint(true).unwrap(), [&outs[0], &outs[1]], &ntt).unwrap();
    let ri = ein.commitment().root;
    let ro = eout.commitment().root;
    let st = plan.bind(ri, ro).unwrap();
    let mut frames = Vec::new();
    let tick = std::time::Instant::now();
    split_run::prove(
        &st,
        &[blk.clone()],
        &mut One(Some(w)),
        [ein, eout],
        &mut |k, b| {
            assert_eq!(k, frames.len());
            frames.push(b);
            Ok(())
        },
    )
    .unwrap();
    let prove_seconds = tick.elapsed().as_secs_f64();
    assert_eq!(frames.len(), 1);
    verify(&st, &blk, &frames[0]).unwrap();
    let dir = std::path::PathBuf::from(
        std::env::var("HL_R14_ACTUAL_L25_OUTPUT").expect("retain actual receipt"),
    );
    assert!(!dir.exists());
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join("segment0.bin"), &frames[0]).unwrap();
    let metadata=format!("R14-actual-S2-L25-reviewer-prefix/1\ndd={}\nstages=1\ncontext={}\nmodel_identity={}\ninput_root={}\noutput_root={}\nbinding={}\nscope=actual S2 public layer L25, reviewer residual causal prefix, native one-stage path; no full26/CLI/privacy acceptance\n",usize::from(dd),hex(&[225;32]),hex(&model.identity()),hex(&ri),hex(&ro),hex(&st.binding()));
    std::fs::write(dir.join("statement.txt"), metadata).unwrap();
    eprintln!("R14_ACTUAL_L25_NATIVE_PROOF {{\"dd\":{},\"trace_sites\":19,\"bytes\":{},\"prove_seconds\":{},\"process_hwm_mib\":{},\"model_identity\":{:?},\"test_synthetic_waiver\":false,\"scope\":\"actual S2 L25 public weights, reviewer residual causal prefix, native R14 one-stage only; no full26/CLI/privacy acceptance\"}}",dd,frames[0].len(),prove_seconds,crate::private_block::run::peak_rss_mib(),hex(&model.identity()));
}
fn fresh() -> Result<(), String> {
    let dd = variant();
    let (sh, blk, model) = load(dd);
    let dir = std::path::PathBuf::from(
        std::env::var("HL_R14_ACTUAL_L25_INPUT").expect("actual receipt directory"),
    );
    let bytes = super::split_run_tests::read_file(&dir.join("statement.txt"), None, 8192)?;
    let text = std::str::from_utf8(&bytes).map_err(|e| e.to_string())?;
    let mut lines = text.lines();
    if lines.next() != Some("R14-actual-S2-L25-reviewer-prefix/1") {
        return Err("actual fixture version".into());
    }
    let mut meta = std::collections::BTreeMap::new();
    for line in lines {
        let (k, v) = line.split_once('=').ok_or("actual fixture field")?;
        if meta.insert(k, v).is_some() {
            return Err("duplicate actual field".into());
        }
    }
    use super::split_run_tests::parse_digest;
    if meta.len() != 8
        || meta.get("dd").copied() != Some(if dd { "1" } else { "0" })
        || meta.get("stages").copied() != Some("1")
        || parse_digest(&meta, "context")? != [225; 32]
        || parse_digest(&meta, "model_identity")? != model.identity()
    {
        return Err("actual fixture public context mismatch".into());
    }
    let st = plan(sh, &blk, &model).bind(
        parse_digest(&meta, "input_root")?,
        parse_digest(&meta, "output_root")?,
    )?;
    if st.binding() != parse_digest(&meta, "binding")? {
        return Err("actual fixture binding mismatch".into());
    }
    let n =
        crate::private_block::wire::split::Geometry::new(st.plan().stage(0)?, 1, 0)?.encoded_len();
    verify(
        &st,
        &blk,
        &super::split_run_tests::read_file(&dir.join("segment0.bin"), Some(n), 256 * 1024 * 1024)?,
    )?;
    eprintln!("R14_ACTUAL_L25_FRESH_VERIFY {{\"dd\":{},\"status\":\"PASS\",\"test_synthetic_waiver\":false}}",dd);
    Ok(())
}
#[test]
#[ignore = "guarded fresh actual S2 R14 native verifier; explicit export/DD/input"]
fn split_actual_l25_t128_fresh_native_verifier() {
    fresh().unwrap();
}
#[test]
#[ignore = "guarded fresh actual S2 R14 canonical scalar corruption refusal"]
fn split_actual_l25_t128_fresh_native_corruption_refusal() {
    let error = fresh().expect_err("actual R14 scalar mutation accepted");
    assert!(
        error.contains("sumcheck round 0"),
        "corruption stopped outside native sumcheck: {error}"
    );
}

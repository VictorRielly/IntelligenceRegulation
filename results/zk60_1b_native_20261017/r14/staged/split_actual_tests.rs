//! Exact19-site independent actual-S2 oracle through the physical R14 witness,
//! followed optionally by a strict-model native one-stage R14 receipt.
use super::*;
use crate::ntt::NttTables;
use crate::private_block::{protocol, split_endpoint, split_layout::Part,
    split_profile::SplitProfile, split_run, split_witness::PieceWitness,
    trained_block::{TrainedExport,hex,sha256}, trained_statement::TrainedModelStatement,
    witness::{self,Witness}, BlockPublic};

const EXPECTED: [(&str,usize,&str);19] = [
    ("input", A_X, "f692d5f3437bae77bedea8164930992a9603017481bb603e5aec7f7a35750f30"),
    ("y", A_Y, "9fca0e9c8aa134aa5946c052c4f7e337217357fb32d4d22872d6e12c6703c47d"),
    ("q", A_Q8, "8f8e13a812dbf55f9b9cf9b46d3e147d1dd1c3dc5ca9dc88b8d55381d062e4d7"),
    ("k", A_K8, "9ae3fc1660b2f64b857a4bbee03052608566ec4419e02d10fda1355480adbed7"),
    ("v", A_V8, "2c0cacc6f5157da8a55593c1878e0b2757c410a5b32397b0bea5f012c1c55cfb"),
    ("qr", A_QR8, "9b82d70839b31697e91f658daa72c4d0c446bbe2cf526f5a127ea3712c01489c"),
    ("kr", A_KR8, "9aecc6b7e2fd45f12463985aaa22c87d5fa68279e10b85ce4113df3aa2b9931e"),
    ("s", A_S8, "bb9f8df61474d25e71fa00722318cd387396ca1736605e1248821cc0de3d3af8"),
    ("p", A_P, "2e0211eec3e7eeca1a41da2acb7c979c789beec8c992f3c97290a97e12ac7834"),
    ("o", A_O8, "37362f0f84a112757cd12ba67d4bc6cf66214b2da53f87835c4762ff15e6ae68"),
    ("ao", A_AO, "1f5027fae943fee11b29afc75f5bdd61233cae7781bf9e317db9d5aff3592bca"),
    ("x1", A_X1, "ea09573d5c5b3987a9fc3fbd8949aaaacbd611bf95e16abe9e203b0e72d19d41"),
    ("nm", A_YM, "35f75d2e04a7f3068df5c16e7becd24cdf53c885b34bd0107d3927717cdf4d9f"),
    ("gate", A_G8, "8a5a53231851bb238d1a1ef31b2c4fe1674a561bfc73ec757e59dfcd70aff2e0"),
    ("a_scaled", A_A16, "854d984436b4a8e58183b4c46fd01cd428fdb83af178f22ea7de322811dd4bd3"),
    ("up", A_U16, "d7487123d89896638e3cc7bb4ae3551010ca2520f98d68e7d0e57e979f59f105"),
    ("h", A_H16, "9639af590f77236b28341876ee3cb78e13567acbf93374abd2b80052fdd1998c"),
    ("z", A_Z16, "b068d5c6fd7a1c1e3053cfe31507ac8ffad5bb20f9271c53b9b707ef37fe4c47"),
    ("x2", A_X2, "8c4e75d719f9609b07aa88bba29e5be790bbb7781788826624cb6525325b5fda"),
];
fn variant() -> bool {
    match std::env::var("HL_R14_DD").unwrap().as_str() {"0"=>false,"1"=>true,_=>panic!("explicit DD0/1")}
}
fn load(dd: bool) -> (Shape, BlockPublic, TrainedModelStatement) {
    let root=std::path::PathBuf::from(std::env::var("HL_R14_ACTUAL_EXPORT").expect("explicit immutable actual S2 export required"));
    assert_eq!(hex(&sha256(&std::fs::read(root.join("profile.json")).unwrap())),"04102cce64dea0cd45dee5caa62095da1cf33fcaabd5647554202b564e6e7e57");
    assert_eq!(hex(&sha256(&std::fs::read(root.join("PUBLIC_ORACLE.json")).unwrap())),"9fe10a9c257bd18baf1dd00d752ddfa4e46ef0db914027fcc715d26f2d8e59b2");
    let mut ex=TrainedExport::load(&root).unwrap(); ex.accuracy_dd=dd;
    let c=ex.run_constants(&[0]).unwrap(); let seed=ex.shape_for(&c).unwrap();
    let layer=ex.load_layer(&seed,&c,0,false).unwrap();
    let sh=layer.record.shape_at(&seed).unwrap();
    assert_eq!((sh.tokens,sh.width,sh.hidden),(128,3072,9216));
    let model=ex.statement(&seed,&c,&[&layer]).unwrap();
    assert!(!model.test_synthetic_waiver,"actual proof enabled synthetic waiver");
    (sh,layer.blk,model)
}
fn native_dense(sh: &Shape, dom: Dom, words: &[i64]) -> Vec<i64> {
    assert_eq!(words.len(),sh.size(dom));
    let mut out=Vec::new();
    match dom {
        Dom::D|Dom::F=> {
            let (pad,width)=if dom==Dom::D {(sh.d_pad,sh.width)} else {(sh.f_pad,sh.hidden)};
            for t in 0..sh.tokens {out.extend_from_slice(&words[t*pad..t*pad+width]);}
        },
        Dom::Q=>for t in 0..sh.tokens {for h in 0..sh.q_heads {
            let start=t*sh.q_pad()+sh.head_slot(h)*sh.head_dim;
            out.extend_from_slice(&words[start..start+sh.head_dim]);
        }},
        Dom::Kv=>out.extend_from_slice(&words[..sh.tokens*sh.kv_heads*sh.head_dim]),
        Dom::S=>for h in 0..sh.q_heads {for t in 0..sh.tokens {
            let start=(sh.head_slot(h)*sh.t_pad+t)*sh.t_pad;
            out.extend_from_slice(&words[start..start+sh.tokens]);
        }},
        _=>panic!("not an oracle trace domain"),
    }
    out
}
fn piece_dense(p: &SplitProfile, w: &PieceWitness, parent: usize) -> Vec<i64> {
    let sh=p.base();let dom=Ids::new(sh).unwrap().dom(parent);
    if !matches!(dom,Dom::D|Dom::F) {
        return native_dense(sh,dom,w.plane(p,parent,Part::Whole).unwrap());
    }
    let ext=if dom==Dom::D {p.layout().d} else {p.layout().f};
    let wide=w.plane(p,parent,Part::Wide).unwrap(); let narrow=w.plane(p,parent,Part::Narrow).unwrap();
    let mut out=Vec::with_capacity(sh.tokens*(ext[0].width+ext[1].width));
    for t in 0..sh.tokens {
        for (v,e) in [(wide,ext[0]),(narrow,ext[1])] {out.extend_from_slice(&v[t*e.width..(t+1)*e.width]);}
    }
    out
}
fn digest(v: &[i64]) -> String {
    hex(&sha256(&v.iter().flat_map(|v|v.to_le_bytes()).collect::<Vec<_>>()))
}
struct One(Option<Witness>);
impl split_run::WitnessSource for One {
    fn witness(&mut self,k:usize)->Result<Witness,String> {
        if k!=0 {return Err("one actual layer only".into());}
        self.0.take().ok_or("actual witness consumed".into())
    }
    fn boundary_pieces(&mut self,_:usize)->Result<[Vec<Fp>;2],String> {Err("no internal actual boundary".into())}
}
fn plan(sh: Shape, blk: &BlockPublic, model: &TrainedModelStatement) -> split_run::Plan {
    split_run::Plan::new(sh,[201;32],model,&[blk.clone()],&[model.calibration.block_scales]).unwrap()
}
fn verify(st: &split_run::Statement, blk: &BlockPublic, frame: &[u8]) -> Result<(),String> {
    let blocks=[blk.clone()]; let mut v=split_run::Verifier::new(st,&blocks)?;
    v.verify_next(frame)?; v.finish()
}
#[test]
#[ignore="guarded actual-weight T128 R14 parity/proof; explicit export/DD and optional output"]
fn split_actual_s2_t128_all19_sites_and_optional_native_proof() {
    let dd=variant(); let(sh,blk,model)=load(dd);
    let ids=Ids::new(&sh).unwrap();let p=SplitProfile::new(sh.clone()).unwrap();
    let mut input=vec![0i16;sh.tokens*sh.width];
    for t in 0..sh.tokens {for j in 0..32 {input[t*sh.width+(j*97+t*13)%sh.width]=if (j+t)%2==1 {1}else{-1};}}
    let w=witness::build_for_block(&sh,&blk,&input).unwrap();
    for (name,old,want) in EXPECTED {
        let parent=ids.at(old);let v=native_dense(&sh,ids.dom(parent),&w.planes[parent]);
        assert_eq!(digest(&v),want,"reference actual {name}");
    }
    let packed=PieceWitness::from_reference(&p,w).unwrap();
    for (name,old,want) in EXPECTED {
        let v=piece_dense(&p,&packed,ids.at(old));
        assert_eq!(digest(&v),want,"physical actual {name}");
        eprintln!("R14_ACTUAL_TRACE {{\"dd\":{},\"site\":{:?},\"words\":{},\"sha256\":{:?},\"reference_and_physical_match\":true}}",dd,name,v.len(),want);
    }
    drop(packed);
    if std::env::var("HL_R14_ACTUAL_PROVE").as_deref()!=Ok("1") {return;}
    let w=witness::build_for_block(&sh,&blk,&input).unwrap();
    let plan=plan(sh.clone(),&blk,&model);let p=plan.stage(0).unwrap();
    let ins=super::split_run_tests::pieces(&sh,p,&w,ids.at(A_X));
    let outs=super::split_run_tests::pieces(&sh,p,&w,ids.at(A_X2));
    let ntt=NttTables::new(protocol::ntt_log_at(&sh));
    let ein=split_endpoint::prepare(&plan.endpoint(false).unwrap(),[&ins[0],&ins[1]],&ntt).unwrap();
    let eout=split_endpoint::prepare(&plan.endpoint(true).unwrap(),[&outs[0],&outs[1]],&ntt).unwrap();
    let ri=ein.commitment().root;let ro=eout.commitment().root;let st=plan.bind(ri,ro).unwrap();
    let mut frames=Vec::new();let tick=std::time::Instant::now();
    split_run::prove(&st,&[blk.clone()],&mut One(Some(w)),[ein,eout],&mut |k,b| {assert_eq!(k,frames.len());frames.push(b);Ok(())}).unwrap();
    let prove_seconds=tick.elapsed().as_secs_f64();assert_eq!(frames.len(),1);
    verify(&st,&blk,&frames[0]).unwrap();
    let dir=std::path::PathBuf::from(std::env::var("HL_R14_ACTUAL_OUTPUT").expect("retain actual receipt"));
    assert!(!dir.exists());std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join("segment0.bin"),&frames[0]).unwrap();
    let metadata=format!("R14-actual-S2-L00-public-input/1\ndd={}\nstages=1\ncontext={}\nmodel_identity={}\ninput_root={}\noutput_root={}\nbinding={}\nscope=actual S2 public layer L00, public synthetic input, native one-stage path; no full26/CLI/privacy acceptance\n",usize::from(dd),hex(&[201;32]),hex(&model.identity()),hex(&ri),hex(&ro),hex(&st.binding()));
    std::fs::write(dir.join("statement.txt"),metadata).unwrap();
    eprintln!("R14_ACTUAL_NATIVE_PROOF {{\"dd\":{},\"trace_sites\":19,\"bytes\":{},\"prove_seconds\":{},\"process_hwm_mib\":{},\"model_identity\":{:?},\"test_synthetic_waiver\":false,\"scope\":\"actual S2 L00 public weights, public synthetic input, native R14 one-stage only; no full26/CLI/privacy acceptance\"}}",dd,frames[0].len(),prove_seconds,crate::private_block::run::peak_rss_mib(),hex(&model.identity()));
}
fn fresh() -> Result<(),String> {
    let dd=variant();let (sh,blk,model)=load(dd);
    let dir=std::path::PathBuf::from(std::env::var("HL_R14_ACTUAL_INPUT").expect("actual receipt directory"));
    let bytes=super::split_run_tests::read_file(&dir.join("statement.txt"),None,8192)?;
    let text=std::str::from_utf8(&bytes).map_err(|e|e.to_string())?;let mut lines=text.lines();
    if lines.next()!=Some("R14-actual-S2-L00-public-input/1") {return Err("actual fixture version".into());}
    let mut meta=std::collections::BTreeMap::new();
    for line in lines {let(k,v)=line.split_once('=').ok_or("actual fixture field")?;if meta.insert(k,v).is_some(){return Err("duplicate actual field".into());}}
    use super::split_run_tests::parse_digest;
    if meta.len()!=8 || meta.get("dd").copied()!=Some(if dd {"1"}else{"0"}) || meta.get("stages").copied()!=Some("1")
        || parse_digest(&meta,"context")?!=[201;32] || parse_digest(&meta,"model_identity")?!=model.identity() {return Err("actual fixture public context mismatch".into());}
    let st=plan(sh,&blk,&model).bind(parse_digest(&meta,"input_root")?,parse_digest(&meta,"output_root")?)?;
    if st.binding()!=parse_digest(&meta,"binding")? {return Err("actual fixture binding mismatch".into());}
    let n=crate::private_block::wire::split::Geometry::new(st.plan().stage(0)?,1,0)?.encoded_len();
    verify(&st,&blk,&super::split_run_tests::read_file(&dir.join("segment0.bin"),Some(n),256*1024*1024)?)?;
    eprintln!("R14_ACTUAL_FRESH_VERIFY {{\"dd\":{},\"status\":\"PASS\",\"test_synthetic_waiver\":false}}",dd);
    Ok(())
}
#[test]
#[ignore="guarded fresh actual S2 R14 native verifier; explicit export/DD/input"]
fn split_actual_s2_t128_fresh_native_verifier() {fresh().unwrap();}
#[test]
#[ignore="guarded fresh actual S2 R14 canonical scalar corruption refusal"]
fn split_actual_s2_t128_fresh_native_corruption_refusal() {
    let error=fresh().expect_err("actual R14 scalar mutation accepted");
    assert!(error.contains("sumcheck round 0"),"corruption stopped outside native sumcheck: {error}");
}

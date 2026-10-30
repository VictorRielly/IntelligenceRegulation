//! Draft verifier-only R14 capture. This child module reuses only its
//! parent's public serializers/replay helpers. New schema, physical layout.
//! Not active until hooks, three-stage tests and the privacy adapter pass.
use super::*;
use crate::private_block::{protocol, split_layout::Part, split_profile::SplitProfile};
use crate::private_block::layout::{Dom,HIds,Ids};
use crate::private_block::split_run;
use crate::private_block::split_endpoint::{JointSpec,Kind};
pub(crate) const SCHEMA_SPLIT: &str = "hashline-native-capture/6-split-run";

pub(crate) struct Header {
    pub profiles: Vec<SplitProfile>,
    pub block_digests: Vec<Digest>,
    pub plan: Digest,
    pub model: Digest,
    pub context: Digest,
    pub binding: Digest,
    pub input: Digest,
    pub output: Digest,
    pub scales: Vec<(i32,i32)>,
}
pub(crate) struct JointPublic {digest: Digest,scale: i32}
struct Stage {
    k: usize,
    start_tag: Digest,
    end_tag: Option<Digest>,
    boundary: Option<Digest>,
    roots: Option<[Digest;3]>,
    definition: Option<Transcript>,
    arguments: Vec<Vec<u8>>,
    mask: Option<Vec<u8>>,
    roles: Vec<Vec<u8>>,
    role_names: Vec<&'static str>,
    logup: Vec<Fp2>,
}
struct SplitRecorder {
    header: Header,
    own: Transcript,
    cur: Option<Stage>,
    stages: Vec<Vec<u8>>,
    closed: usize,
    accepted: bool,
    failure: Option<String>,
    store: ArrayStore,
    public_tables: bool,
    sites: Vec<Vec<u8>>,
}
thread_local! { static SPLIT_REC: RefCell<Option<SplitRecorder>> = const {RefCell::new(None)}; }
fn with(f: impl FnOnce(&mut SplitRecorder)) {
    SPLIT_REC.with(|s| {if let Some(r)=s.borrow_mut().as_mut() {f(r);}});
}
fn fail(r: &mut SplitRecorder, error: String) {if r.failure.is_none() {r.failure=Some(error);}}
fn at(r: &mut SplitRecorder, site: &str, tr: &Transcript) {
    if !same_transcript(&r.own,tr) {fail(r,format!("R14 capture replay differs at {site}"));}
}
fn site(r: &mut SplitRecorder, name: &str, before: &Transcript, after: &Transcript) {
    let mut out=Vec::new();write!(out,"{{\"site\":{name:?},").unwrap();
    state(&mut out,"before",before);write!(out,",").unwrap();state(&mut out,"after",after);write!(out,"}}").unwrap();
    r.sites.push(out);
}
fn seeded(h: &Header) -> Result<Transcript,String> {
    let p=h.profiles.first().ok_or("R14 capture empty run")?;
    let mut tr=Transcript::new_tagged(b"hashline/private-block/split-r14/run/v1",*p.tag().transcript_key().ok_or("R14 capture unkeyed profile")?);
    tr.absorb(b"R14-run-binding",&h.binding);tr.absorb(b"R14-run-plan",&h.plan);
    tr.absorb(b"R14-trained-arithmetic-statement",&h.model);tr.absorb(b"R14-public-context",&h.context);
    tr.absorb_u64(b"R14-blocks",h.profiles.len() as u64);tr.absorb(b"R14-input",&h.input);tr.absorb(b"R14-output",&h.output);
    Ok(tr)
}
pub(crate) fn begin(header: Header) -> Result<(),String> {
    if header.profiles.is_empty() || header.profiles.len()>128 || header.profiles.len()!=header.block_digests.len()
        || header.profiles.len()!=header.scales.len() {return Err("R14 capture header counts".into());}
    let own=seeded(&header)?;
    SPLIT_REC.with(|s| {
        let mut slot=s.borrow_mut();if slot.is_some() {return Err("R14 recorder already attached".into());}
        *slot=Some(SplitRecorder{header,own,cur:None,stages:vec![],closed:0,accepted:false,failure:None,
            store:ArrayStore::new(true),public_tables:true,sites:vec![]});Ok(())
    })
}
pub(crate) fn checkpoint(tr: &Transcript) -> Option<Transcript> {
    SPLIT_REC.with(|s|s.borrow().is_some().then(||Transcript::clone_state(tr)))
}
pub(crate) fn seed_matches(tr: &Transcript) -> bool {
    SPLIT_REC.with(|s|s.borrow().as_ref().is_some_and(|r|same_transcript(&r.own,tr)))
}
pub(crate) fn start_slot(side: &Side,tr: &Transcript) {
    if !matches!(side,Side::Verify{..}) {return;}
    with(|r| {at(r,"before R14 definition",tr);if let Some(c)=r.cur.as_mut() {c.definition=Some(Transcript::clone_state(tr));}});
}
pub(crate) fn stage_begin(k: usize,boundary: Option<Digest>,before: &Transcript) {
    with(|r| {
        if r.failure.is_some() {return;}
        if r.cur.is_some() || k!=r.closed || k>=r.header.profiles.len()
            || boundary.is_some()!=(k+1<r.header.profiles.len()) {fail(r,"R14 capture stage order/boundary".into());return;}
        at(r,"R14 stage start",before);if r.failure.is_some(){return;}
        let start_tag=split_run::position_tag(&r.own);let p=&r.header.profiles[k];
        r.own.absorb_u64(b"R14-stage",k as u64);r.own.absorb(b"R14-stage-profile",&p.digest());
        r.own.absorb(b"R14-stage-block",&r.header.block_digests[k]);
        if let Some(root)=boundary {
            let index=k+1;
            let spec=match JointSpec::new(p,r.header.plan,Kind::Boundary(index as u64),r.header.scales[k].1) {
                Ok(spec)=>spec,Err(error)=>{fail(r,format!("R14 replay joint spec: {error}"));return;}
            };
            r.own.absorb_u64(b"R14-boundary-index",index as u64);
            r.own.absorb(b"R14-boundary-spec",&spec.digest());
            protocol::absorb_root(&mut r.own,b"R14-boundary-root",&root,spec.rows(),spec.params().log_cols as usize);
        }
        r.cur=Some(Stage{k,start_tag,end_tag:None,boundary,roots:None,definition:None,
            arguments:vec![],mask:None,roles:vec![],role_names:vec![],logup:vec![]});
    });
}
pub(crate) fn core_roots(a: Digest,h: Digest,m: Digest,after: &Transcript) {
    with(|r| {
        if r.failure.is_some(){return;}
        let Some(cur)=r.cur.as_ref() else {fail(r,"R14 roots outside a stage".into());return;};
        if cur.roots.is_some(){fail(r,"R14 duplicate core roots".into());return;}
        let p=&r.header.profiles[cur.k];let s=p.layout();
        protocol::absorb_root(&mut r.own,b"A",&a,s.a_rows,p.base().log_cols);
        r.own.absorb(b"M",&m);let logup=r.own.challenge_fp2_vec(3);
        protocol::absorb_root(&mut r.own,b"H",&h,s.h_rows,p.base().log_cols);
        at(r,"R14 core roots/challenges",after);
        let cur=r.cur.as_mut().unwrap();cur.roots=Some([a,h,m]);cur.logup=logup;
    });
}
fn io_slot(p: &SplitProfile,base: usize,part: Part) -> usize {
    p.layout().slots.iter().position(|s|s.base==base && s.part==part).expect("typed R14 IO slot")
}
pub(crate) fn joint_pcs(spec: &JointSpec,root: Digest,claims: &[ZClaim],opening: &OpeningZk,
    ntt: &NttTables,before: Option<Transcript>,after: &Transcript) {
    if before.is_none(){return;}
    let geometry=SPLIT_REC.with(|slot| {
        let r=slot.borrow();let r=r.as_ref()?;let cur=r.cur.as_ref()?;
        let p=&r.header.profiles[cur.k];
        let sources=match spec.kind() {
            Kind::Input=>[Part::Wide,Part::Narrow].into_iter().map(|part|(0,io_slot(&r.header.profiles[0],super::super::layout::SC_IO_IN,part),1)).collect(),
            Kind::Output=>[Part::Wide,Part::Narrow].into_iter().map(|part|(r.header.profiles.len()-1,io_slot(p,super::super::layout::SC_IO_OUT,part),1)).collect(),
            Kind::Boundary(index)=>{
                let index=index as usize;if index!=cur.k || index==0 || index>=r.header.profiles.len(){return None;}
                [Part::Wide,Part::Narrow].into_iter().map(|part|(index-1,io_slot(&r.header.profiles[index-1],super::super::layout::SC_IO_OUT,part),1))
                    .chain([Part::Wide,Part::Narrow].into_iter().map(|part|(index,io_slot(p,super::super::layout::SC_IO_IN,part),1))).collect()
            },
        };
        let internal=matches!(spec.kind(),Kind::Boundary(_));let data=p.layout().endpoint.data_rows;
        Some(Geom{role:if matches!(spec.kind(),Kind::Output){"Output"}else{"Input"},commitment_kind:if internal{"internal-boundary"}else{"external-endpoint"},
            params:spec.params(),root,rows:spec.rows(),data_rows:data,site_rows:(data..data+if internal{8}else{4}).collect(),sum_rows:None,
            prox_row:spec.rows()-2,boundary:if let Kind::Boundary(k)=spec.kind(){Some(k as usize)}else{None},claim_sources:sources})
    });
    let Some(g)=geometry else {with(|r|fail(r,"R14 joint observation has no matching stage/spec".into()));return;};
    pcs(g,claims,opening,ntt,before,after,Some(JointPublic{digest:spec.digest(),scale:spec.scale()}));
}

// The generator appends the audited verifier-view slot/M/PCS serializers,
// replacing legacy slot metadata with this stage's physical schedule.
// @@COPIED_OBSERVERS@@

fn write_stage(r: &SplitRecorder,c: &Stage,receipt: &[u8]) -> Vec<u8> {
    let mut out=Vec::new();let roots=c.roots.expect("checked accepted roots");
    write!(out,"{{\"schema\":{SCHEMA_SPLIT:?},\"stage\":{},\"start_tag\":{:?},\"end_tag\":{:?},\"boundary\":{},\"a_root\":{:?},\"h_root\":{:?},\"mask_root\":{:?},\"logup\":{:?},\"arguments\":[",c.k,c.start_tag,c.end_tag.unwrap(),c.boundary.map(|v|format!("{v:?}")).unwrap_or("null".into()),roots[0],roots[1],roots[2],fp2s(&c.logup)).unwrap();
    for (i,item) in c.arguments.iter().enumerate(){if i>0 {write!(out,",").unwrap();}out.extend_from_slice(item);}
    let digest=crate::private_block::trained_block::hex(&crate::private_block::trained_block::sha256(receipt));
    write!(out,"],\"receipt_bytes\":{},\"receipt_sha256\":{:?},\"mask\":",receipt.len(),digest).unwrap();out.extend_from_slice(c.mask.as_ref().unwrap());write!(out,",\"roles\":[").unwrap();
    for (i,item) in c.roles.iter().enumerate(){if i>0 {write!(out,",").unwrap();}out.extend_from_slice(item);}
    write!(out,"]}}").unwrap();let _=r;out
}
pub(crate) fn stage_end(k: usize,end: Digest,tr: &Transcript,receipt: &[u8]) {
    with(|r| {
        if r.failure.is_some(){return;}
        at(r,"R14 stage end",tr);if r.failure.is_some(){return;}
        let Some(mut cur)=r.cur.take() else {fail(r,"R14 stage end without stage".into());return;};
        if cur.k!=k || cur.arguments.len()!=r.header.profiles[k].layout().slots.len()
            || cur.roots.is_none() || cur.mask.is_none() || cur.definition.is_some()
            || cur.role_names!=if k+1==r.header.profiles.len() {vec!["A","H","Input","Output"]}else{vec!["A","H","Input"]}
            || split_run::position_tag(&r.own)!=end {fail(r,"R14 incomplete/mismatched stage capture".into());return;}
        cur.end_tag=Some(end);let json=write_stage(r,&cur,receipt);r.stages.push(json);r.closed+=1;
    });
}
pub(crate) fn run_accepted() {
    with(|r| {
        if r.failure.is_none() && r.closed==r.header.profiles.len() && r.cur.is_none() {r.accepted=true;}
        else {fail(r,"R14 finish without complete accepted capture".into());}
    });
}
pub(crate) fn discard(){SPLIT_REC.with(|s|*s.borrow_mut()=None);}
#[derive(Debug)]
pub(crate) struct SplitBundle {pub run_json: Vec<u8>,pub stages: Vec<Vec<u8>>,pub arrays: Vec<u8>}
pub(crate) fn take() -> Result<SplitBundle,String> {
    let mut r=SPLIT_REC.with(|s|s.borrow_mut().take()).ok_or("no R14 recorder attached")?;
    if let Some(error)=r.failure.take(){return Err(error);}
    if !r.accepted || r.cur.is_some() || r.closed!=r.header.profiles.len(){return Err("R14 no bundle for unaccepted/incomplete run".into());}
    let mut out=Vec::new();write!(out,"{{\"schema\":{SCHEMA_SPLIT:?},\"kind\":\"R14 native verifier observations\",\"blocks\":{},\"binding\":{:?},\"plan\":{:?},\"model\":{:?},\"context\":{:?},\"input_root\":{:?},\"output_root\":{:?},\"scales\":{:?},\"profiles\":[",r.closed,r.header.binding,r.header.plan,r.header.model,r.header.context,r.header.input,r.header.output,r.header.scales.iter().map(|&(a,b)|[a,b]).collect::<Vec<_>>()).unwrap();
    // Add all public block digests explicitly; the replay consumes them.
    for (i,p) in r.header.profiles.iter().enumerate(){if i>0{write!(out,",").unwrap();}write_profile(&mut out,p);}
    write!(out,"],\"block_digests\":{:?},\"fully_verified\":true,\"sites\":[",r.header.block_digests).unwrap();for(i,item)in r.sites.iter().enumerate(){if i>0{write!(out,",").unwrap();}out.extend_from_slice(item);}
    write!(out,"],\"source_pins\":[").unwrap();
    let root=std::path::Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    for(i,name)in SOURCE_FILES.iter().enumerate(){if i>0{write!(out,",").unwrap();}let bytes=std::fs::read(root.join(name)).map_err(|e|format!("R14 capture source {name}: {e}"))?;write!(out,"{{\"file\":{name:?},\"sha256\":{:?}}}",crate::private_block::trained_block::hex(&crate::private_block::trained_block::sha256(&bytes))).unwrap();}
    write!(out,"]}}").unwrap();Ok(SplitBundle{run_json:out,stages:r.stages,arrays:r.store.blob().to_vec()})
}
fn h_plane_name(sh: &Shape,ids: &HIds,parent: usize) -> String {
    for dom in [Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F,Dom::Dd] {
        for k in 0..sh.helpers(dom) {
            if ids.helper(dom,k)==parent {return format!("H_{dom:?}{k}");}
        }
    }
    let table=ids.table_helpers();
    for (id,name) in [(ids.sexp(),"H_SEXP"),(ids.fact(),"H_FACT"),
        (table[0],"H_GU8"),(table[1],"H_GEXP"),(table[2],"H_GACT"),(ids.u(),"H_U")] {
        if parent==id {return name.into();}
    }
    if sh.dd_cap>0 {
        if parent==ids.stuple(){return "H_STUPLE".into();}
        if parent==ids.gdd(){return "H_GDD".into();}
    }
    panic!("R14 capture unnamed H parent {parent}")
}
fn write_profile(out: &mut Vec<u8>,p: &SplitProfile){
    let b=p.base();let s=p.layout();
    let ids=Ids::new(b).expect("R14 A roles");let names=&ids.accuracy().expect("R14 accuracy roles").names;
    let hids=HIds::new(b).expect("R14 H roles");
    write!(out,"{{\"profile\":{:?},\"descriptor\":{:?},\"arithmetic_reference\":{:?},\"tokens\":{},\"width\":{},\"hidden\":{},\"q_heads\":{},\"kv_heads\":{},\"head_dim\":{},\"q_pad\":{},\"t_pad\":{},\"d_pad\":{},\"f_pad\":{},\"N\":{},\"a_rows\":{},\"h_rows\":{},\"m_rows\":{},\"external_rows\":{},\"internal_rows\":{},\"physical_planes\":[",p.name(),p.digest(),b.profile,b.tokens,b.width,b.hidden,b.q_heads,b.kv_heads,b.head_dim,b.q_pad(),b.t_pad,b.d_pad,b.f_pad,s.n,s.a_rows,s.h_rows,s.m_rows,s.endpoint.external_rows,s.endpoint.internal_rows).unwrap();
    let mut first=true;for(h,planes)in[(false,&s.a),(true,&s.h)]{for(i,v)in planes.iter().enumerate(){
        if !first{write!(out,",").unwrap();}first=false;
        let name=if h {h_plane_name(b,&hids,v.parent)}else{format!("A_{}",names[v.parent])};
        let extent=match v.domain {Dom::D=>Some(s.d),Dom::F=>Some(s.f),_=>None};
        let extent=extent.map(|pieces|pieces[match v.part {Part::Wide=>0,Part::Narrow=>1,Part::Whole=>panic!("unsplit D/F capture plane")}]);
        let start=extent.map(|e|e.start.to_string()).unwrap_or("null".into());
        let width=extent.map(|e|e.width.to_string()).unwrap_or("null".into());
        write!(out,"{{\"cm\":{},\"physical\":{},\"parent\":{},\"name\":{:?},\"domain\":{:?},\"part\":{:?},\"offset\":{},\"log\":{},\"rows_per_component\":{},\"components\":{},\"global_feature_start\":{},\"global_feature_width\":{}}}",usize::from(h),i,v.parent,name,format!("{:?}",v.domain),format!("{:?}",v.part),v.offset,v.log,v.rows_per_component,if h {2}else{1},start,width).unwrap();
    }}
    write!(out,"],\"slots\":[").unwrap();for(i,m)in s.slots.iter().enumerate(){if i>0{write!(out,",").unwrap();}write!(out,"{{\"slot\":{i},\"base\":{},\"part\":{:?},\"main\":{},\"extension\":{},\"degree\":{},\"a_pairs\":{:?},\"h_pairs\":{:?}}}",m.base,format!("{:?}",m.part),m.main,m.ext,m.degree,m.a_pairs,m.h_pairs).unwrap();}
    write!(out,"],\"joint_piece_offsets\":{:?},\"joint_piece_logs\":{:?},\"joint_data_rows\":{},\"calibration\":{{\"norm_tn\":{},\"cn_a\":{},\"cn_m\":{},\"ceps\":{},\"d_max\":{},\"f_e\":{},\"f_p\":{},\"shifts\":{:?},\"gate_shift\":{}}}}}",s.endpoint.piece_offsets,s.endpoint.piece_logs,s.endpoint.data_rows,b.norm_tn,b.norm_cn_a,b.norm_cn_m,b.norm_ceps,b.d_max,b.f_e,b.f_p(),[b.sh_ao,b.sh_qkv,b.sh_s,b.sh_o,b.sh_g,b.sh_h,b.sh_z],b.accuracy_gate_shift).unwrap();
}
// @@SOURCE_FILES@@

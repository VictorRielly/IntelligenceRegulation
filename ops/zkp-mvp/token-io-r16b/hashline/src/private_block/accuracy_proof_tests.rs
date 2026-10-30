//! Native R13 receipt, relation-mutation and actual public-import acceptance gates.
use super::*;
use super::layout::*;
use super::run::{self,RunShape,RunStatement,RunWitnessSource};
use super::trained_block::TrainedExport;
use super::witness::{self,Witness};

struct One(Option<Witness>);
impl RunWitnessSource for One {
    fn witness(&mut self,k:usize)->Result<Witness,String> {
        if k!=0 {return Err("one public synthetic stage".into());}
        self.0.take().ok_or("witness consumed".into())
    }
    fn boundary_plane(&mut self,_k:usize)->Result<Vec<i16>,String> {Err("no internal boundary".into())}
}

#[derive(Clone,Copy,Debug)]
enum Attack { Byte(super::accuracy_layout::Limbs,usize), DdUnused, TablePad(usize), DdCounts }

struct Hooks;
impl Drop for Hooks {
    fn drop(&mut self) {
        super::protocol::set_moved_multiplicity(None);
        super::protocol::set_dd_moved_multiplicity(None);
    }
}

fn prove_case(name:&str,dd:bool,attack:Option<Attack>) {
    let _hooks=Hooks;
    let path=/* TOKEN ROUND 16: HL_R13_LOADER_FIXTURES overrides the native tree's sibling dir */ std::env::var_os("HL_R13_LOADER_FIXTURES").map(std::path::PathBuf::from).unwrap_or_else(|| std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures")).join(name);
    let mut ex=TrainedExport::load(&path).unwrap();ex.accuracy_dd=dd;
    let c=ex.run_constants(&[0]).unwrap();let seed=ex.shape_for(&c).unwrap();
    let layer=ex.load_layer(&seed,&c,0,false).unwrap();let sh=layer.record.shape_at(&seed).unwrap();
    let(x,expected_words)=ex.load_seq(&sh,"public",0).unwrap();
    let mut wit=witness::build_for_block(&sh,&layer.blk,&x).unwrap();let ids=Ids::new(&sh).unwrap();
    let true_output:Vec<_>=(0..sh.tokens).flat_map(|t|(0..sh.width).map(move |i|(t,i)))
        .map(|(t,i)|wit.planes[ids.at(A_X2)][t*sh.d_pad+i] as i16).collect();
    assert_eq!(true_output,expected_words);
    let input:Vec<_>=wit.planes[ids.at(A_X)].iter().map(|&v|v as i16).collect();
    let output:Vec<_>=wit.planes[ids.at(A_X2)].iter().map(|&v|v as i16).collect();
    match attack {
        Some(Attack::Byte(role,k))=> {
            let plane=ids.accuracy().unwrap().limb(role,k);
            let value=&mut wit.planes[plane][0];*value^=1;
            assert!((0..256).contains(value));
        }
        Some(Attack::DdUnused)=> {
            assert!(dd);let column=layer.blk.attention().dd_e_column(sh.dd_cap).unwrap();
            let k=(0..sh.dd_cap).rev().find(|&k|column[k]==0 && wit.planes[ids.mdd()][k]==0).expect("unused zero slot");
            assert_eq!(wit.planes[ids.pdict()][k],0);
            wit.planes[ids.pdict()][k]=1;
            let low=ids.accuracy().unwrap();
            wit.planes[low.limb(super::accuracy_layout::Limbs::P,0)][k]=1;
            // This slot is not queried; all byte and tuple lookups still hit.
            super::protocol::check_lookup_misses(&sh,&Layout::for_shape(&sh).unwrap(),&layer.blk,&wit).unwrap();
        }
        Some(Attack::TablePad(which))=> {
            let (from,to)=match which {
                0=>(0,256),
                1=>(127,383), // the padded copy carries exactly the same tuple
                2=>(2048,layer.blk.accuracy().unwrap().groups().len()*4096),
                _=>panic!("unknown table family"),
            };
            assert!(to<sh.size(Dom::Tab));
            super::protocol::set_moved_multiplicity(Some((which,from,to)));
        }
        Some(Attack::DdCounts)=> {
            assert!(dd);
            let from=(0..sh.dd_cap).find(|&k|wit.planes[ids.mdd()][k]>0).unwrap();
            super::protocol::set_dd_moved_multiplicity(Some((from,sh.dd_cap-1)));
        }
        None=>{}
    }
    let model=ex.statement(&seed,&c,&[&layer]).unwrap();let blocks=vec![layer.blk];
    let context=[37;32];let spec=IoSpec::new_shaped(&seed,context,0,0).unwrap();
    let(expected,owners)=prepare_endpoints(spec,&input,&output).unwrap();
    let st=RunStatement::new_bound(RunShape::accuracy(seed,1).unwrap(),context,expected,&blocks,&[(0,0)],&model).unwrap();
    let mut segments=Vec::new();let mut source=One(Some(wit));
    run::prove_run(&st,&blocks,&mut source,owners,&mut |k,bytes| {
        assert_eq!(k,segments.len());segments.push(bytes);Ok(())
    }).unwrap();
    assert_eq!(segments.len(),1);
    let verified=run::verify_run(&st,&blocks,&segments);
    if attack.is_some() {assert!(verified.is_err(),"native mutation {attack:?} was accepted");}
    else {
        verified.unwrap();let mut changed=segments.clone();let mid=changed[0].len()/2;changed[0][mid]^=1;
        assert!(run::verify_run(&st,&blocks,&changed).is_err(),"changed receipt accepted");
    }
    eprintln!("R13 scoped receipt {name} DD={dd} attack={attack:?}: bytes{}",segments[0].len());
}

#[test]
#[ignore="separate guarded full R13 proof gate; public synthetic only"]
fn accuracy_dense_low_and_h24_dd_and_non_dd_prove_and_verify() {
    
    for name in ["r13-low-dense","r13-h24-wide"] {for dd in [false,true] {prove_case(name,dd,None);}}
}

#[test]
#[ignore="separate guarded native relation mutation; no builder-only refusal"]
fn accuracy_new_norm_high_byte_mutation_reaches_native_proof_and_is_rejected() {
    prove_case("r13-h24-wide",true,Some(Attack::Byte(super::accuracy_layout::Limbs::Y,1)));
}

#[test]
#[ignore="separate guarded R13 new limb and FP12 dictionary attacks"]
fn accuracy_all_new_limb_and_unused_dictionary_mutations_reach_verification() {
    use super::accuracy_layout::Limbs as L;
    
    for (role,k) in [(L::Ym,1),(L::Q,1),(L::K,1),(L::V,1),(L::O,1),
        (L::Rao,2),(L::Rs,2),(L::Rg,2),(L::Up,1),(L::H,2),(L::Rh,1),(L::Rd,2)] {
        prove_case("r13-h24-wide",true,Some(Attack::Byte(role,k)));
    }
    prove_case("r13-h24-wide",true,Some(Attack::DdUnused));
    prove_case("r13-h24-wide",true,Some(Attack::DdCounts));
}

#[test]
#[ignore="separate guarded R13 byte/exp/ACT3 support-tail attacks"]
fn accuracy_every_table_support_tail_rejects_a_moved_multiplicity() {
    
    for which in 0..3 {prove_case("r13-low-dense",false,Some(Attack::TablePad(which)));}
}

#[test]
#[ignore="authenticated full Shieldstral public export via HL_R13_SHIELDSTRAL_EXPORT; guarded separately"]
fn accuracy_actual_shieldstral_v2_all_public_weights_and_layer_contexts_import() {
    use super::accuracy_precision::Stack;
    use super::accuracy_tables::Registry;
    use super::trained_statement::LayerRecord;
    use super::trained_block::{hex,sha256};
    let root=std::path::PathBuf::from(std::env::var("HL_R13_SHIELDSTRAL_EXPORT").expect("explicit actual export required"));
    let profile=std::fs::read(root.join("profile.json")).unwrap();
    assert_eq!(hex(&sha256(&profile)),"1d50078243f13d58afa814a55c47c2df797e494d7f045941ea82fa142740498a");
    // load authenticates the checkpoint and regenerates the tied token tables.
    let mut ex=TrainedExport::load(&root).unwrap();
    assert_eq!(ex.accuracy_stack,Stack::LowH24);
    let layers:Vec<u32>=(0..26).collect();let c=ex.run_constants(&layers).unwrap();
    let seed=ex.shape_for(&c).unwrap();assert_eq!((seed.tokens,seed.width,seed.q_width()),(256,3072,4096));
    ex.accuracy_dd=true;let dd_seed=ex.shape_for(&c).unwrap();ex.accuracy_dd=false;
    let mut digests=std::collections::BTreeSet::new();
    for i in layers {
        let layer=ex.load_layer(&seed,&c,i,false).unwrap();
        let sh=layer.record.shape_at(&seed).unwrap();
        let dd=layer.record.shape_at(&dd_seed).unwrap();
        layer.blk.check_accuracy_for_shape(&sh).unwrap();
        layer.blk.check_accuracy_for_shape(&dd).unwrap();
        let a=layer.blk.accuracy().unwrap();assert_eq!(a.registry(),Registry::Shieldstral);
        assert_eq!(layer.record.accuracy_gate_shift,Some(a.folds().gate.shift));
        assert_eq!(sh.f_p(),12);assert_eq!(dd.f_p(),12);
        layer.blk.attention().dd_e_column(dd.dd_cap).unwrap();
        let fresh=LayerRecord::of_block(i,&layer.blk,vec![]);
        assert_eq!(fresh.table_sha256,layer.record.table_sha256);
        assert_eq!(fresh.block_digest,layer.record.block_digest);
        assert!(digests.insert(fresh.block_digest));
        eprintln!("R13_ACTUAL_IMPORT layer={i} G={} groups={} block={} act={}",
                  a.folds().gate.shift,a.groups().len(),hex(&fresh.block_digest),hex(&fresh.table_sha256[2]));
    }
    assert_eq!(digests.len(),26);
}

struct Pair {
    witnesses:Vec<Option<Witness>>,
    boundary:Vec<i16>,
}
impl RunWitnessSource for Pair {
    fn witness(&mut self,k:usize)->Result<Witness,String> {self.witnesses.get_mut(k).and_then(Option::take).ok_or("pair witness consumed".into())}
    fn boundary_plane(&mut self,k:usize)->Result<Vec<i16>,String> {if k==0 {Ok(self.boundary.clone())} else {Err("one internal boundary".into())}}
}

#[test]
#[ignore="guarded two-stage R13 private boundary with distinct public gate denominators"]
fn accuracy_two_stage_private_boundary_with_different_gate_shifts_verifies() {
    use super::accuracy_public::AccuracyPublic;
    use super::trained_statement::LayerRecord;
    
    for dd in [false,true] {
        let path=/* TOKEN ROUND 16: HL_R13_LOADER_FIXTURES */ std::env::var_os("HL_R13_LOADER_FIXTURES").map(std::path::PathBuf::from).unwrap_or_else(|| std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures")).join("r13-h24-wide");
        let mut ex=TrainedExport::load(&path).unwrap();ex.accuracy_dd=dd;ex.source.checkpoint_layers=2;
        let c=ex.run_constants(&[0]).unwrap();let seed=ex.shape_for(&c).unwrap();
        let first=ex.load_layer(&seed,&c,0,false).unwrap();let a=first.blk.accuracy().unwrap();
        let changed=AccuracyPublic::new(a.stack(),a.geometry(),a.base(),(-4,-13),a.multipliers().clone(),
            a.groups().to_vec(),a.group_ids().to_vec(),a.raw_tables().to_vec()).unwrap();
        let second=first.blk.clone().with_accuracy(changed);
        let mut r2=LayerRecord::of_block(1,&second,vec![]);r2.manifest_sha256=[53;32];
        let s1=first.record.shape_at(&seed).unwrap();let s2=r2.shape_at(&seed).unwrap();
        assert_ne!(s1.accuracy_gate_shift,s2.accuracy_gate_shift);
        let (x,_)=ex.load_seq(&s1,"public",0).unwrap();
        let w1=witness::build_for_block(&s1,&first.blk,&x).unwrap();let boundary=w1.output().unwrap();
        let true_mid:Vec<_>=(0..s1.tokens).flat_map(|t|(0..s1.width).map(move|i|(t,i)))
            .map(|(t,i)|boundary[t*s1.d_pad+i]).collect();
        let w2=witness::build_for_block(&s2,&second,&true_mid).unwrap();
        let ids=Ids::new(&seed).unwrap();
        let input:Vec<_>=w1.planes[ids.at(A_X)].iter().map(|&v|v as i16).collect();let output=w2.output().unwrap();
        let model=ex.statement_of_records(&seed,&c,vec![first.record,r2]).unwrap();
        let blocks=vec![first.blk,second];let context=[41;32];
        let (expected,owners)=prepare_endpoints(IoSpec::new_shaped(&seed,context,0,0).unwrap(),&input,&output).unwrap();
        let st=RunStatement::new_bound(RunShape::accuracy(seed,2).unwrap(),context,expected,&blocks,&[(0,0),(0,0)],&model).unwrap();
        assert_eq!(st.stage_shape(0).unwrap().accuracy_gate_shift,s1.accuracy_gate_shift);
        assert_eq!(st.stage_shape(1).unwrap().accuracy_gate_shift,s2.accuracy_gate_shift);
        let mut source=Pair{witnesses:vec![Some(w1),Some(w2)],boundary};let mut segments=Vec::new();
        run::prove_run(&st,&blocks,&mut source,owners,&mut|k,b|{assert_eq!(k,segments.len());segments.push(b);Ok(())}).unwrap();
        assert_eq!(segments.len(),2);run::verify_run(&st,&blocks,&segments).unwrap();
        let mid=segments[1].len()/2;segments[1][mid]^=1;assert!(run::verify_run(&st,&blocks,&segments).is_err());
        eprintln!("R13 two-stage private boundary DD={dd}: G{} -> G{}",s1.accuracy_gate_shift,s2.accuracy_gate_shift);
    }
}

#[test]
#[ignore="guarded ACT3 wrong-group witness with otherwise self-consistent arithmetic"]
fn accuracy_wrong_group_table_is_rejected_after_both_honest_contexts_verify() {
    use super::accuracy_public::AccuracyPublic;
    use super::accuracy_groups::Group;
    use super::accuracy_tables::silu_table;
    use super::trained_statement::LayerRecord;
    let path=/* TOKEN ROUND 16: HL_R13_LOADER_FIXTURES */ std::env::var_os("HL_R13_LOADER_FIXTURES").map(std::path::PathBuf::from).unwrap_or_else(|| std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures")).join("r13-h24-wide");
    let mut ex=TrainedExport::load(&path).unwrap();ex.accuracy_dd=true;
    let c=ex.run_constants(&[0]).unwrap();let seed=ex.shape_for(&c).unwrap();
    let layer=ex.load_layer(&seed,&c,0,false).unwrap();let a=layer.blk.accuracy().unwrap();
    // All groups use the SAME input exponent: changing only group IDs leaves
    // every gate matmul/coefficient/shift intact. Only the output lookup changes.
    let groups=vec![Group{e_in:-1,e_out:-11},Group{e_in:-1,e_out:-10},Group{e_in:-1,e_out:-9}];
    let tables=groups.iter().map(|g|silu_table(g.e_in,g.e_out,12).unwrap()).collect::<Vec<_>>();
    let ids=(0..seed.hidden).map(|i|i%3).collect::<Vec<_>>();
    let make=|ids| AccuracyPublic::new(a.stack(),a.geometry(),a.base(),a.member(),a.multipliers().clone(),
                                     groups.clone(),ids,tables.clone()).unwrap();
    let correct=layer.blk.clone().with_accuracy(make(ids));
    let changed=layer.blk.clone().with_accuracy(make((0..seed.hidden).map(|i|(i+1)%3).collect()));
    assert_eq!(correct.accuracy().unwrap().folds().gate,changed.accuracy().unwrap().folds().gate);
    assert_eq!(correct.accuracy().unwrap().folds().product.shift,changed.accuracy().unwrap().folds().product.shift);
    let mut record=LayerRecord::of_block(0,&correct,vec![]);record.manifest_sha256=[61;32];
    let sh=record.shape_at(&seed).unwrap();let(x,_)=ex.load_seq(&sh,"public",0).unwrap();
    let honest=witness::build_for_block(&sh,&correct,&x).unwrap();
    let wrong=witness::build_for_block(&sh,&changed,&x).unwrap();let low=Ids::new(&sh).unwrap();
    assert_eq!(honest.planes[low.at(A_G8)],wrong.planes[low.at(A_G8)]);
    assert_ne!(honest.planes[low.at(A_A16)],wrong.planes[low.at(A_A16)]);
    let lay=Layout::for_shape(&sh).unwrap();
    assert!(super::protocol::check_lookup_misses(&sh,&lay,&correct,&wrong).is_err());
    super::protocol::check_lookup_misses(&sh,&lay,&changed,&wrong).unwrap();
    let run_case=|blk:&BlockPublic,mut rec:LayerRecord,wit:Witness,expect:bool| {
        rec.manifest_sha256=[61;32];
        let model=ex.statement_of_records(&seed,&c,vec![rec]).unwrap();
        let context=[43;32];let input=wit.planes[low.at(A_X)].iter().map(|&v|v as i16).collect::<Vec<_>>();
        let output=wit.output().unwrap();let(expected,owners)=prepare_endpoints(
            IoSpec::new_shaped(&seed,context,0,0).unwrap(),&input,&output).unwrap();
        let blocks=vec![blk.clone()];let st=RunStatement::new_bound(RunShape::accuracy(seed.clone(),1).unwrap(),
            context,expected,&blocks,&[(0,0)],&model).unwrap();
        let mut source=One(Some(wit));let mut segs=Vec::new();
        run::prove_run(&st,&blocks,&mut source,owners,&mut|_,b|{segs.push(b);Ok(())}).unwrap();
        assert_eq!(segs.len(),1);assert_eq!(run::verify_run(&st,&blocks,&segs).is_ok(),expect);
    };
    run_case(&correct,record.clone(),honest,true);
    run_case(&changed,LayerRecord::of_block(0,&changed,vec![]),wrong.clone(),true);
    // The cheating switch skips only the pre-proof miss refusal. Native
    // relation construction, commitments, helper identities and verification
    // remain enabled. Proving must emit a full receipt before it is rejected.
    let _cheat=super::protocol::CheatingProver::on();
    run_case(&correct,record,wrong,false);
    eprintln!("R13 ACT3 wrong-group: both honest contexts verify; self-consistent wrong-group witness rejected under the original statement");
}

//! Public synthetic R13 receipts; availability is scoped to this test thread.
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

fn prove_case(name:&str,dd:bool,mutate:bool) {
    let path=std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures").join(name);
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
    if mutate {
        let plane=ids.accuracy().unwrap().limb(super::accuracy_layout::Limbs::Y,1);
        let value=&mut wit.planes[plane][0];*value=if *value<255 {*value+1} else {*value-1};
        assert!((0..256).contains(value));
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
    if mutate {assert!(verified.is_err(),"new norm high-byte mutation was accepted");}
    else {
        verified.unwrap();let mut changed=segments.clone();let mid=changed[0].len()/2;changed[0][mid]^=1;
        assert!(run::verify_run(&st,&blocks,&changed).is_err(),"changed receipt accepted");
    }
    eprintln!("R13 scoped receipt {name} DD={dd} mutation={mutate}: bytes{}",segments[0].len());
}

#[test]
#[ignore="separate guarded full R13 proof gate; public synthetic only"]
fn accuracy_dense_low_and_h24_dd_and_non_dd_prove_and_verify() {
    let _scope=AccuracyProofTests::scoped();
    for name in ["r13-low-dense","r13-h24-wide"] {for dd in [false,true] {prove_case(name,dd,false);}}
}

#[test]
#[ignore="separate guarded native relation mutation; no builder-only refusal"]
fn accuracy_new_norm_high_byte_mutation_reaches_native_proof_and_is_rejected() {
    let _scope=AccuracyProofTests::scoped();prove_case("r13-h24-wide",true,true);
}

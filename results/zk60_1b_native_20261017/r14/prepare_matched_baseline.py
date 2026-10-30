"""Accepted R13 source plus one test-only module sharing the exact R14 fixture."""
import hashlib,json,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent;R13=HERE.parent/'r13';OUT=HERE/'matched-r13';TREE=OUT/'working-tree'
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
    assert not OUT.exists(),'retain baseline attempts; do not overwrite'
    pin=json.loads((R13/'manifest_frozen.json').read_text())
    for name,want in pin['files'].items():
        source=R13/'frozen-tree'/name;assert sha(source.read_bytes())==want,name
        target=TREE/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    source=(HERE/'working-tree/hashline/src/private_block/split_definition_tests.rs').read_text()
    helpers=source[source.index('pub(super) fn calibration()'):source.index('fn check_degree(')]
    source=(HERE/'working-tree/hashline/src/private_block/split_run_tests.rs').read_text()
    fixture=source[source.index('fn fixture('):source.index('fn pieces(')]
    fixture_sha=sha((helpers+fixture).encode())
    header='''//! Matched public synthetic two-block R13 baseline, accepted source unchanged.
use super::*;
use super::layout::*;
use super::shape::{self,Shape,NormCalibration};
use super::accuracy_groups::Group;
use super::accuracy_public::{AccuracyPublic,Geometry,Multipliers};
use super::{run,trained_statement,witness::{self,Witness}};
'''
    body=r'''
struct Source<'a> {first:Option<Witness>,next:Shape,input:Vec<i16>,blocks:&'a [BlockPublic],boundary:Vec<i16>}
impl run::RunWitnessSource for Source<'_> {
    fn witness(&mut self,k:usize)->Result<Witness,String> {match k {
        0=>self.first.take().ok_or_else(||"first witness consumed".into()),
        1=>witness::build_for_block(&self.next,&self.blocks[1],&self.input),_=>Err("two stages only".into())}}
    fn boundary_plane(&mut self,k:usize)->Result<Vec<i16>,String> {
        if k!=1 {return Err("one internal boundary only".into());}Ok(self.boundary.clone())
    }
}
fn dense(sh:&Shape,w:&Witness,parent:usize)->Vec<i16> {
    (0..sh.tokens).flat_map(|t|(0..sh.width).map(move|j|i16::try_from(w.planes[parent][t*sh.d_pad+j]).unwrap())).collect()
}
fn padded(w:&Witness,parent:usize)->Vec<i16> {w.planes[parent].iter().map(|&v|i16::try_from(v).unwrap()).collect()}
fn case(dd:bool) {
    let(sh,blocks,model)=fixture(dd);let scales=vec![model.calibration.block_scales;2];let ids=Ids::new(&sh).unwrap();
    let next=model.layers[1].shape_at(&sh).unwrap();let input=(0..sh.tokens*sh.width).map(|j|if j%2==0 {1i16}else{-1i16}).collect::<Vec<_>>();
    let first=witness::build_for_block(&sh,&blocks[0],&input).unwrap();let pin=padded(&first,ids.at(A_X));let boundary=padded(&first,ids.at(A_X2));let intermediate=dense(&sh,&first,ids.at(A_X2));
    let second=witness::build_for_block(&next,&blocks[1],&intermediate).unwrap();let pout=padded(&second,ids.at(A_X2));drop(second);
    let spec=IoSpec::new_shaped(&sh,[107;32],scales[0].0,scales[1].1).unwrap();let(expected,owners)=prepare_endpoints(spec,&pin,&pout).unwrap();
    let st=run::RunStatement::new_bound(run::RunShape::accuracy(sh.clone(),2).unwrap(),[107;32],expected,&blocks,&scales,&model).unwrap();
    let mut source=Source{first:Some(first),next,input:intermediate,blocks:&blocks,boundary};let mut frames=Vec::new();let tick=std::time::Instant::now();
    run::prove_run(&st,&blocks,&mut source,owners,&mut|k,bytes|{assert_eq!(k,frames.len());frames.push(bytes);Ok(())}).unwrap();let prove_seconds=tick.elapsed().as_secs_f64();
    let tick=std::time::Instant::now();run::verify_run(&st,&blocks,&frames).unwrap();let verify_seconds=tick.elapsed().as_secs_f64();
    let hex=|d:&[u8]|d.iter().map(|b|format!("{b:02x}")).collect::<String>();
    eprintln!("R13_MATCHED_STREAM {{\"dd\":{},\"tokens\":128,\"blocks\":2,\"prove_seconds\":{},\"verify_seconds\":{},\"process_hwm_mib\":{},\"bytes\":{:?},\"model_identity\":{:?},\"block_digest\":{:?},\"fixture_helpers_sha256\":{:?},\"scope\":\"accepted R13 native source plus test-only exact R14 public synthetic fixture, same2layer calibrations; n1 sharedhost, not approved trained-model performance\"}}",dd,prove_seconds,verify_seconds,run::peak_rss_mib(),frames.iter().map(Vec::len).collect::<Vec<_>>(),hex(&model.identity()),hex(&blocks[0].digest()),FIXTURE_HELPERS_SHA256);
}
#[test]
#[ignore="separate guarded matched R13 T128 baseline9.5GiB"]
fn r14_matched_r13_t128_non_dd_two_blocks() {case(false)}
#[test]
#[ignore="separate guarded matched R13 T128 baseline9.5GiB"]
fn r14_matched_r13_t128_dd_two_blocks() {case(true)}
'''
    test=header+f'const FIXTURE_HELPERS_SHA256:&str="{fixture_sha}";\n'+helpers+fixture+body
    test_path=TREE/'hashline/src/private_block/matched_r14_benchmark.rs';test_path.write_text(test)
    root=TREE/'hashline/src/private_block.rs';root.write_text(root.read_text()+'\n#[cfg(test)]\nmod matched_r14_benchmark;\n')
    names=set(pin['files']);names.add('hashline/src/private_block/matched_r14_benchmark.rs')
    files={name:sha((TREE/name).read_bytes()) for name in sorted(names)}
    manifest={'tree_sha256':sha(''.join(f'{k} {v}\n' for k,v in files.items()).encode()),'count':len(files),'files':files}
    (OUT/'source.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (OUT/'BASE.json').write_text(json.dumps({'accepted_r13_source':pin['tree_sha256'],'test_only_existing_file_change':'hashline/src/private_block.rs: append cfg(test) module declaration',
        'new_test_file':'matched_r14_benchmark.rs','fixture_helpers_sha256':fixture_sha,'fixture_source_r14':'sol-r14-run-build-3.source.json',
        'scope':'No R13 proving/verification source edited; independent baseline copy only. Exact R14 fixture helper and public model construction text shared. Native prove-only clock and guard RSS/HWM, n1 shared host.'},indent=2)+'\n')
    print(json.dumps({'source':manifest['tree_sha256'],'files':len(files),'fixture_helpers_sha256':fixture_sha}))
if __name__=='__main__':main()

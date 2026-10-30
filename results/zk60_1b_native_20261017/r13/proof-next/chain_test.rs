
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
    let _scope=AccuracyProofTests::scoped();
    for dd in [false,true] {
        let path=std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures/r13-h24-wide");
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

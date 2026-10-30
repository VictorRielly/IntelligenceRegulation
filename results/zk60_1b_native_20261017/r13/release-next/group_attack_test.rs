
#[test]
#[ignore="guarded ACT3 wrong-group witness with otherwise self-consistent arithmetic"]
fn accuracy_wrong_group_table_is_rejected_after_both_honest_contexts_verify() {
    use super::accuracy_public::AccuracyPublic;
    use super::accuracy_groups::Group;
    use super::accuracy_tables::silu_table;
    use super::trained_statement::LayerRecord;
    let path=std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures/r13-h24-wide");
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

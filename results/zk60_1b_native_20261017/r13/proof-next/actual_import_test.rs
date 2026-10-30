
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

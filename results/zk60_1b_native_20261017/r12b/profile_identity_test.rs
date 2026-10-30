#[test]
fn every_token_calibration_field_is_bound_by_the_trained_statement() {
    use super::trained_block::{TrainedExport, J, parse_json};
    let root=std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../results/r12b-profile-fields");
    let (dir,_)=super::trained_block_tests::write_export(&root,"profile-fields",&Default::default());
    let original=std::fs::read_to_string(dir.join("profile.json")).unwrap();
    let values=[1,127,1024,10,2439,127,512,9,2439];
    let parameters=|v:&[i64;9]| format!(r#", "token_io_parameters": {{"bos":{},"classifier_final_norm":{{"g0":{},"cn":{},"tn":{},"ceps":{}}},"head_final_norm":{{"g0":{},"cn":{},"tn":{},"ceps":{}}}}}}}"#,v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8]);
    let prefix=original.trim_end().strip_suffix('}').unwrap();
    let identity=|v:&[i64;9]| {
        let profile=format!("{prefix}{}",parameters(v));
        assert!(matches!(parse_json(profile.as_bytes()).unwrap(),J::Obj(_)));
        std::fs::write(dir.join("profile.json"),profile).unwrap();
        let export=TrainedExport::load(&dir).unwrap();
        let constants=export.run_constants(&[0]).unwrap();
        let shape=export.shape_for(&constants).unwrap();
        let layer=export.load_layer(&shape,&constants,0,false).unwrap();
        export.statement(&shape,&constants,&[&layer]).unwrap().identity()
    };
    let baseline=identity(&values);
    for i in 0..values.len() {
        let mut changed=values;changed[i]+=1;
        assert_ne!(identity(&changed),baseline,"token_io_parameters field {i} was not bound");
    }
}

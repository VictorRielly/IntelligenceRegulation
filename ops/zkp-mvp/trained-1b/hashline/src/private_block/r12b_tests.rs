//! R12 review fixes: refusal controls and full pinned-table integration.
use super::trained_block::{TrainedExport, tied_of, parse_json, J, Geometry};
use super::trained_statement::ModelSource;

#[test]
fn transformed_profile_refuses_export_rope_before_any_layer_read() {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../results/r12b-rope");
    let (dir,_) = super::trained_block_tests::write_export(&root,"r12b-rope",&Default::default());
    let mut export = TrainedExport::load(&dir).unwrap();
    let constants = export.constants.clone().unwrap();
    let shape = export.shape_for(&constants).unwrap();
    // Exercise the refusal independently of file content: even matching
    // exported tables cannot opt out of a pinned transform.
    export.rope_scaling = super::rope::RopeScaling::shieldstral();
    let error = match export.load_layer(&shape,&constants,0,true) {
        Err(e) => e,
        Ok(_) => panic!("pinned transform accepted --rope-from-export"),
    };
    assert!(error.contains("pinned RoPE transform"),"{error}");
}

#[test]
#[ignore = "full pinned checkpoint/table reads; run guarded with ZK60_R12B_TIED_FIXTURE"]
fn pinned_tied_tables_accept_honest_and_refuse_rehashed_forgery() {
    use std::io::{Read,Write,Seek,SeekFrom};
    use super::trained_block::{hex,sha256};
    let root = std::path::PathBuf::from(std::env::var_os("ZK60_R12B_TIED_FIXTURE").expect("reference fixture directory"));
    let bytes = std::fs::read(root.join("profile.json")).unwrap();
    let profile = parse_json(&bytes).unwrap();
    let model = ModelSource::shieldstral_1_0_3b();
    let honest = tied_of(&root,&profile,Geometry::Shieldstral(256),&model).unwrap().unwrap();
    println!("R12B-HONEST {} {} {}",hex(&honest.embedding_table_sha256),hex(&honest.head_table_sha256),hex(&honest.head_mult_sha256));
    // Use the small multiplier file for a consistency-preserving forgery;
    // retain copies and restore even when the refusal assertion fails.
    let file = root.join("token_io/head_mult12.bin");
    let manifest = root.join("token_io/head_manifest.json");
    let original = std::fs::read(&file).unwrap();
    let original_manifest = std::fs::read(&manifest).unwrap();
    let mut doctored=original.clone();doctored[0]^=1;
    std::fs::write(&file,&doctored).unwrap();
    let text=String::from_utf8(original_manifest.clone()).unwrap().replace(&hex(&sha256(&original)),&hex(&sha256(&doctored)));
    std::fs::write(&manifest,text).unwrap();
    let result = tied_of(&root,&profile,Geometry::Shieldstral(256),&model);
    std::fs::write(&file,&original).unwrap();
    std::fs::write(&manifest,&original_manifest).unwrap();
    assert!(result.unwrap_err().contains("not derived from the pinned tensor"));
    println!("R12B rehashed multiplier forgery rejected");
    // A large head edit need not be copied into memory. Hash its consumed
    // bytes through the bounded helper, update the manifest, and retry.
    let file=root.join("token_io/head_int8_perrow.bin");
    let mut f=std::fs::OpenOptions::new().read(true).write(true).open(&file).unwrap();
    let mut old=[0];f.read_exact(&mut old).unwrap();f.seek(SeekFrom::Start(0)).unwrap();f.write_all(&[old[0]^1]).unwrap();
    let changed=super::tied_tables::hash_regular_exact(&file,131072*3072).unwrap();
    let text=String::from_utf8(original_manifest.clone()).unwrap().replace(&hex(&honest.head_table_sha256),&hex(&changed));
    std::fs::write(&manifest,text).unwrap();
    let result=tied_of(&root,&profile,Geometry::Shieldstral(256),&model);
    f.seek(SeekFrom::Start(0)).unwrap();f.write_all(&old).unwrap();std::fs::write(&manifest,&original_manifest).unwrap();
    assert!(result.unwrap_err().contains("not derived from the pinned tensor"));
    println!("R12B rehashed head forgery rejected");
    // Shape and dtype are rejected before table reads.
    let path=root.join("token_io/token_io.json");
    let original=std::fs::read(&path).unwrap();
    let text=String::from_utf8(original.clone()).unwrap().replace("\"int16\"","\"int8\"");
    std::fs::write(&path,text).unwrap();
    let result=tied_of(&root,&profile,Geometry::Shieldstral(256),&model);
    std::fs::write(&path,original).unwrap();
    assert!(result.unwrap_err().contains("dtype/shape"));
    assert!(matches!(profile,J::Obj(_)));
}

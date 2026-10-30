#[cfg(test)]
mod profile_tests {
    use super::*;

    fn fixture(name:&str)->PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures").join(name)
    }

    #[test]
    fn accuracy_v2_loader_imports_both_stacks_and_reconstructs_dd_records() {
        for (name,stack,ng) in [("r13-low-1g",Stack::Low,1),("r13-h24-4g",Stack::LowH24,4)] {
            for dd in [false,true] {
                let mut ex=TrainedExport::load(&fixture(name)).unwrap();
                assert_eq!(ex.accuracy_stack,stack);
                if dd {ex.enable_dd().unwrap();}
                let c=ex.run_constants(&[0]).unwrap();let seed=ex.shape_for(&c).unwrap();
                assert_eq!(seed.accuracy_stack(),stack);assert_eq!(seed.dd_cap>0,dd);
                let layer=ex.load_layer(&seed,&c,0,false).unwrap();let data=layer.blk.accuracy().unwrap();
                assert_eq!(data.groups().len(),ng);
                assert_eq!(layer.record.accuracy_gate_shift,Some(data.folds().gate.shift));
                let stage=seed.clone().with_accuracy_gate_shift(data.folds().gate.shift).unwrap();
                layer.blk.check_accuracy_for_shape(&stage).unwrap();
                let statement=ex.statement(&seed,&c,&[&layer]).unwrap();
                assert_eq!(statement.run_profile,ex.run_profile());
                assert_eq!(statement.layers[0].accuracy_gate_shift,layer.record.accuracy_gate_shift);
                assert!(layer.blk.check_for_shape(&stage).unwrap_err().contains("R13 proof profiles remain disabled"));
            }
        }
    }

    #[test]
    fn accuracy_v2_model_stack_selection_has_no_global_fallback() {
        use crate::private_block::shape::*;
        use crate::private_block::trained_block::Geometry as G;
        let expected=[
            (G::TinyLlama(128),Stack::Low,false,R13_TINY_T128_LOW),
            (G::TinyLlama(128),Stack::Low,true,R13_TINY_T128_LOW_DD),
            (G::Llama3_8B(128),Stack::LowH24,false,R13_8B_T128_H24),
            (G::Llama3_8B(128),Stack::LowH24,true,R13_8B_T128_H24_DD),
            (G::Shieldstral(128),Stack::LowH24,false,R13_SHIELD_T128_H24),
            (G::Shieldstral(128),Stack::LowH24,true,R13_SHIELD_T128_H24_DD),
            (G::Shieldstral(256),Stack::LowH24,false,R13_SHIELD_T256_H24),
            (G::Shieldstral(256),Stack::LowH24,true,R13_SHIELD_T256_H24_DD),
            (G::RungHdDev,Stack::Low,false,R13_RUNG_LOW),
            (G::RungHdDev,Stack::Low,true,R13_RUNG_LOW_DD),
            (G::RungHdDev,Stack::LowH24,false,R13_RUNG_H24),
            (G::RungHdDev,Stack::LowH24,true,R13_RUNG_H24_DD),
        ];
        for (geometry,stack,dd,profile) in expected {assert_eq!(profile_for(geometry,stack,dd).unwrap(),profile);}
        for (geometry,stack) in [(G::TinyLlama(128),Stack::LowH24),(G::Llama3_8B(128),Stack::Low),
            (G::Shieldstral(128),Stack::Low),(G::TinyLlama(32),Stack::Low),(G::Llama3_8B(64),Stack::LowH24),
            (G::RungTcDev,Stack::Low),(G::RungHdDev,Stack::Legacy)] {
            for dd in [false,true] {assert!(profile_for(geometry,stack,dd).is_err());}
        }
    }

    #[test]
    fn accuracy_v2_schema_stack_and_fp12_are_checked_before_layer_payloads() {
        let original=std::fs::read_to_string(fixture("r13-low-1g").join("profile.json")).unwrap();
        let cases=[
            (original.replace("zk60-trained-profile-export/2","zk60-trained-profile-export/1"),"legacy export"),
            (original.replace("  \"accuracy_stack\": \"low-v1\",\n",""),"accuracy_stack"),
            (original.replace("\"accuracy_stack\": \"low-v1\"","\"accuracy_stack\": \"unknown\""),"accuracy_stack"),
            (original.replace("\"f_p\": 12","\"f_p\": 9"),"f_p"),
        ];
        for (i,(text,needle)) in cases.into_iter().enumerate() {
            assert_ne!(text,original);
            let dir=crate::private_block::trained_block_tests::base_dir(&format!("r13-schema-{i}"));
            std::fs::write(dir.join("profile.json"),text).unwrap();
            let error=match TrainedExport::load(&dir) {Err(e)=>e,Ok(_)=>panic!("malformed schema/stack was accepted")};
            assert!(error.contains(needle),"unexpected refusal: {error}");
        }
    }
}

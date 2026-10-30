#[cfg(test)]
mod accuracy_metadata_tests {
    use super::*;

    fn provenance(sh:&Shape)->Provenance {
        let mut p=Provenance::recipe("R13 metadata fixture",1.0,[3;32],[4;32]);
        p.rope_theta=super::super::shape::trained_rope_theta(sh.profile).unwrap();
        p.rope_scaling=super::super::shape::trained_rope_scaling(sh.profile).unwrap();p
    }

    #[test]
    fn accuracy_calibration_describes_fp12_three_byte_norm_remainders_and_up_shift12() {
        for sh in super::super::accuracy_profile_tests::registered_shapes() {
            let p=provenance(&sh);let c=IntegerCalibration::as_the_code_proves(&sh,&p);
            assert_eq!((c.f_p,c.norm_wrho,c.sh_u),(12,24,12));
            assert_eq!(c.norm_tn,sh.norm_tn,"base calibration remains the source of effective precision");
            c.check_honoured_by_code(&sh).unwrap();
            for field in 0..3 {
                let mut forged=c.clone();match field {0=>forged.f_p=9,1=>forged.norm_wrho=32,_=>forged.sh_u=0};
                assert!(forged.check_honoured_by_code(&sh).is_err());
            }
        }
        let sh=Shape::toy();let c=IntegerCalibration::as_the_code_proves(&sh,&Provenance::recipe("legacy",1.0,[3;32],[4;32]));
        assert_eq!((c.f_p,c.norm_wrho,c.sh_u),(9,sh.norm_wrho,0));
    }

    #[test]
    fn accuracy_layer_records_require_exactly_one_class_checked_gate_scalar() {
        let mut r=LayerRecord::unhashed(0);
        r.check_accuracy_gate(&Shape::toy()).unwrap();r.accuracy_gate_shift=Some(17);
        assert!(r.check_accuracy_gate(&Shape::toy()).is_err());
        for sh in super::super::accuracy_profile_tests::registered_shapes() {
            r.accuracy_gate_shift=None;assert!(r.check_accuracy_gate(&sh).is_err());
            for g in 17..=24 {r.accuracy_gate_shift=Some(g);r.check_accuracy_gate(&sh).unwrap();}
            for g in [0,16,25,u32::MAX] {r.accuracy_gate_shift=Some(g);assert!(r.check_accuracy_gate(&sh).is_err());}
        }
    }

    fn model(sh:&Shape,gates:&[u32])->TrainedModelStatement {
        let source=ModelSource{kind:SourceKind::PublicSyntheticRecipe,repo:"synthetic/r13-metadata".into(),revision:"r13-test".into(),
            weights_sha256:[0;32],config_sha256:[0;32],checkpoint_parameters:0,checkpoint_layers:gates.len() as u32};
        let layers=gates.iter().enumerate().map(|(k,&g)| {
            let mut r=LayerRecord::unhashed(k as u32);r.accuracy_gate_shift=Some(g);r.block_digest=[k as u8+1;32];
            r.silu_member=(-3,-11);r
        }).collect();
        TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(sh,super::super::run::accuracy_run_profile(sh.profile).unwrap(),
            source,IntegerCalibration::as_the_code_proves(sh,&provenance(sh)),layers).unwrap()
    }

    pub(super) fn hash_census_model(sh:&Shape,l:usize)->TrainedModelStatement {model(sh,&vec![sh.accuracy_gate_shift;l])}

    #[test]
    fn accuracy_same_calibration_layers_reconstruct_distinct_bound_stage_denominators() {
        use super::super::{run,IoSpec,ExpectedIo,layout::Layout};
        for sh in super::super::accuracy_profile_tests::registered_shapes().into_iter().filter(|s|s.tokens==32) {
            let m=model(&sh,&[17,24]);let rs=run::RunShape::accuracy(sh.clone(),2).unwrap();let context=[7;32];
            let spec=IoSpec::new_shaped(&sh,context,0,0).unwrap();let expected=ExpectedIo::from_roots(spec,[1;32],[2;32]);
            let digests=m.layers.iter().map(|r|r.block_digest).collect::<Vec<_>>();
            let st=run::RunStatement::new_bound_from_digests(rs,context,expected,digests,&[super::super::ENDPOINT_SCALES;2],&m).unwrap();
            let(a,b)=(st.stage_shape(0).unwrap(),st.stage_shape(1).unwrap());
            assert_eq!(a.norm_calibration(),b.norm_calibration());
            assert_eq!((a.accuracy_gate_shift,b.accuracy_gate_shift),(17,24));
            assert_ne!(Layout::for_shape(&a).unwrap().schedule_digest(),Layout::for_shape(&b).unwrap().schedule_digest());
            let mut changed=m.clone();changed.layers[1].accuracy_gate_shift=Some(23);
            changed.check_self_with(&sh,true).unwrap();assert_ne!(changed.identity(),m.identity());
            assert_eq!(String::from_utf8_lossy(&m.encode()).matches("accuracy-gate-layer").count(),2);
            changed.layers[1].accuracy_gate_shift=None;assert!(changed.check_self_with(&sh,true).is_err());
        }
    }

    #[test]
    fn accuracy_profiles_keep_their_legacy_model_and_tied_tensor_pins() {
        for spec in &super::super::shape::ACCURACY_PROFILES {
            assert_eq!(ModelSource::pinned_for_profile(spec.profile),ModelSource::pinned_for_profile(spec.legacy));
            assert_eq!(tied_tensor_for_profile(spec.profile),tied_tensor_for_profile(spec.legacy));
        }
    }
}

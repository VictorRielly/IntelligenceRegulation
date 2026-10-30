    #[test]
    #[ignore = "guarded T128 actual26 native capture; public export, verified backend artifact, expected model/binding and output required"]
    fn split_cli_actual_full26_native_capture_and_rejected_bundle_suppression() {
        use crate::private_block::run_capture::split as cap;
        let env = |name| std::env::var(name).expect("explicit full26 capture contract");
        let export = PathBuf::from(env("HL_R14_CAPTURE_EXPORT"));
        let artifact = PathBuf::from(env("HL_R14_CAPTURE_ARTIFACT"));
        let output = PathBuf::from(env("HL_R14_CAPTURE_OUTPUT"));
        assert!(!output.exists());
        refuse_prover_private_entries(&export).unwrap();
        assert_eq!(hex(&sha256(&read_bounded(&export.join("profile.json"), MAX_JSON_BYTES).unwrap())),
            "2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0");
        let dd = match env("HL_R14_DD").as_str() { "0" => false, "1" => true, _ => panic!("explicit DD0/1") };
        let mut ex = TrainedExport::load(&export).unwrap();
        if dd { ex.enable_dd().unwrap(); }
        let layers = (0..26).collect::<Vec<u32>>();
        assert_eq!(ex.layers, layers);
        let mut group_counts = Vec::new();
        for layer in &layers {
            let bytes = read_bounded(&export.join(format!("layer_{layer:02}/manifest.json")), MAX_JSON_BYTES).unwrap();
            let expected = ex.layer_manifest_sha256.iter().find(|(k,_)| k == layer).unwrap().1;
            assert_eq!(sha256(&bytes), expected);
            let value = parse_json(&bytes).unwrap();
            let dims = value.get("arrays").unwrap().get("silu_groups").unwrap().get("shape").unwrap().arr().unwrap();
            group_counts.push(usize::try_from(dims[0].i64().unwrap()).unwrap());
        }
        assert_eq!(group_counts.iter().filter(|&&n| n == 3).count(), 12);
        assert_eq!(group_counts.iter().filter(|&&n| n == 4).count(), 14);
        let (constants, shape, _metadata, digests, model) = stack_records(&ex, &layers, false).unwrap();
        assert!(!model.test_synthetic_waiver);
        assert_eq!(hex(&model.identity()), env("HL_R14_CAPTURE_EXPECT_MODEL"));
        assert_eq!((shape.tokens, shape.width, shape.hidden), (128, 3072, 9216));
        let context = stack_context(&ex.variant, &layers, LABELS[0]).unwrap();
        let plan = split_run::Plan::from_records(shape.clone(), context, &model,
            &vec![model.calibration.block_scales; layers.len()]).unwrap();
        let expected = read_bounded(&artifact.join("statement/expected.bin"), POLICY_BYTES as u64).unwrap();
        let st = bind_policy(plan, model.identity(), context, &expected).unwrap();
        assert_eq!(hex(&st.binding()), env("HL_R14_CAPTURE_EXPECT_BINDING"));
        let cache = || BlockCache::shared(&ex, &shape, &constants, layers.clone(), digests.clone(), false);
        cap::discard();
        let without = verify_dir(&st, cache(), &artifact).unwrap();
        assert_eq!(without.len(), 26);
        cap::begin(st.capture_header().unwrap()).unwrap();
        let observed = verify_dir(&st, cache(), &artifact).unwrap();
        assert_eq!(observed, without, "recorder changed the consumed segment bytes");
        let bundle = cap::take().unwrap();
        assert_eq!(bundle.stages.len(), 26);
        assert!(!bundle.arrays.is_empty());
        std::fs::create_dir(&output).unwrap();
        std::fs::write(output.join("run.json"), bundle.run_json).unwrap();
        std::fs::write(output.join("arrays.bin"), bundle.arrays).unwrap();
        for (k, bytes) in bundle.stages.into_iter().enumerate() {
            std::fs::write(output.join(format!("stage{k}.json")), bytes).unwrap();
        }
        for (k, (length, digest)) in observed.iter().enumerate() {
            let path = artifact.join(crate::private_block::run_sink::segment_file_name(k));
            let bytes = read_bounded(&path, *length).unwrap();
            assert_eq!(bytes.len() as u64, *length);
            assert_eq!(hex(&sha256(&bytes)), *digest, "source frame changed after verification");
            std::fs::write(output.join(format!("segment{k}.bin")), bytes).unwrap();
        }
        // Re-encode a canonical first scalar change using trusted geometry,
        // including the extra boundary root present in a multi-stage frame.
        let bytes = read_bounded(&artifact.join(crate::private_block::run_sink::segment_file_name(0)), observed[0].0).unwrap();
        let geometry = wire::split::Geometry::new(st.plan().stage(0).unwrap(), 26, 0).unwrap();
        let start = split_run::position_tag(&st.transcript());
        let (mut frame, end) = wire::split::decode(&bytes, &geometry, &st.binding(), &start).unwrap();
        frame.slots[0].scalar = frame.slots[0].scalar.add(crate::field::Fp2::ONE);
        let changed = wire::split::encode(&frame, &geometry, &st.binding(), &start, &end).unwrap();
        assert_eq!(changed.len(), bytes.len());
        cap::begin(st.capture_header().unwrap()).unwrap();
        let mut verifier = split_run::Verifier::with_source(&st, Box::new(PublicBlocks(cache()))).unwrap();
        let error = verifier.verify_next(&changed).unwrap_err();
        assert!(error.contains("sumcheck round 0"), "wrong refusal: {error}");
        assert!(verifier.finish().is_err());
        assert!(cap::take().is_err());
        eprintln!("R14_FULL26_NATIVE_CAPTURE {{\"dd\":{dd},\"stages\":26,\"group_counts\":{group_counts:?},\"test_synthetic_waiver\":false,\"accepted_without_observer\":true,\"rejected_bundle_suppressed\":true,\"scope\":\"actual public S2 model, public reference fixture, native verifier view; no privacy acceptance\"}}");
    }

    #[test]
    #[ignore = "guarded actual T128 R14 CLI receipt publication race; explicit retained unverified artifact/export/output"]
    fn split_cli_publication_names_only_the_segment_bytes_consumed_by_verification() {
        use crate::private_block::trained_block_tests::copy_tree_for_tests;
        let env = |name| std::env::var(name).expect("explicit immutable CLI fixture path");
        let source = PathBuf::from(env("HL_R14_CLI_ARTIFACT"));
        let export = env("HL_R14_CLI_EXPORT");
        let work = PathBuf::from(env("HL_R14_CLI_M9_OUTPUT"));
        assert!(!work.exists());
        std::fs::create_dir(&work).unwrap();
        let artifact = work.join("run");
        let unverified = unverified_statement_dir(&artifact).unwrap();
        copy_tree_for_tests(&source, &artifact);
        copy_tree_for_tests(&unverified_statement_dir(&source).unwrap(), &unverified);
        assert!(!artifact.join("statement").exists());
        let statement = parse_json(&std::fs::read(unverified.join("statement.json")).unwrap()).unwrap();
        let identity = statement.get("statement_identity").unwrap().str().unwrap().to_string();
        let binding = statement.get("binding").unwrap().str().unwrap().to_string();
        let mut args = vec!["--experimental-r14".into(), "--export".into(), export,
            "--artifact".into(), artifact.display().to_string(), "--layers".into(), "25".into(),
            "--expect-statement".into(), identity, "--expect-binding".into(), binding];
        if env("HL_R14_DD") == "1" { args.push("--dd".into()); }
        let segment = artifact.join(crate::private_block::run_sink::segment_file_name(0));
        let original = std::fs::read(&segment).unwrap();
        let mut changed = original.clone();
        // A same-length canonical field mutation, after the native verifier
        // consumed the original frame. This tests publication, not decoding.
        let at = 120 + 3 * 32;
        let scalar = u64::from_le_bytes(changed[at..at+8].try_into().unwrap());
        assert!(scalar < 0xffff_ffff_0000_0001);
        changed[at..at+8].copy_from_slice(&((scalar + 1) % 0xffff_ffff_0000_0001).to_le_bytes());
        let old_hash = hex(&sha256(&original));
        let new_hash = hex(&sha256(&changed));
        let manifest_path = unverified.join("segments.json");
        let manifest = std::fs::read_to_string(&manifest_path).unwrap();
        assert!(manifest.contains(&old_hash));
        let (path, bytes, meta, from, to) = (segment.clone(), changed.clone(), manifest_path.clone(), old_hash.clone(), new_hash.clone());
        after_verify_hook_for_tests(Box::new(move || {
            std::fs::write(path, bytes).unwrap();
            let text = std::fs::read_to_string(&meta).unwrap();
            let forged = text.replace(&from, &to);
            assert_ne!(text, forged);
            std::fs::write(meta, forged).unwrap();
        }));
        let error = verify(&flags(&args, &["--export", "--artifact", "--layers", "--label", "--expect-statement", "--expect-binding"], &["--experimental-r14", "--dd", "--rope-from-export"]).unwrap()).unwrap_err();
        assert!(error.contains("bytes consumed by verification"), "wrong refusal: {error}");
        assert!(!artifact.join("statement").exists());
        assert!(unverified.join(UNVERIFIED_MARKER).exists());
        std::fs::write(&segment, &original).unwrap();
        std::fs::write(&manifest_path, &manifest).unwrap();
        let (path, bytes) = (segment.clone(), changed);
        after_verify_hook_for_tests(Box::new(move || std::fs::write(path, bytes).unwrap()));
        assert_eq!(trained_split_stack_verify_command(&args), 0);
        let published = std::fs::read_to_string(artifact.join("statement/segments.json")).unwrap();
        assert!(published.contains(&old_hash) && !published.contains(&new_hash));
        assert!(!unverified.exists());
        assert_eq!(trained_split_stack_verify_command(&args), 1);
        std::fs::write(&segment, &original).unwrap();
        assert_eq!(trained_split_stack_verify_command(&args), 0);
        eprintln!("R14_CLI_M9 consumed_hash_publication_and_manifest_rewrite_refusal PASS");
    }

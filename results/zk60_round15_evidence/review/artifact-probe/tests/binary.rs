#[test] fn built_binary_runs() { assert!(std::process::Command::new(env!("CARGO_BIN_EXE_artifact-probe")).output().unwrap().status.success()); }

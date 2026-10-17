//! Profiling is explicit, CPU-only, and cannot silently change command scope.
use std::process::Command;

#[test]
fn phase_profile_rejects_unsupported_commands_before_export_access() {
    for args in [
        vec!["layer", "0", "16", "--phase-profile"],
        vec!["chain", "1", "--phase-profile"],
        vec!["attn-pass", "/nonexistent", "1", "--phase-profile"],
        vec!["pass", "1", "16", "--phase-profile"],
        vec!["pass", "1", "16", "--profile", "v3", "--phase-profile", "--phase-profile"],
    ] {
        let output = Command::new(env!("CARGO_BIN_EXE_hashline"))
            .args(&args).env_remove("HL_GPU").output().unwrap();
        assert_eq!(output.status.code(), Some(2), "args {args:?}");
        assert!(String::from_utf8_lossy(&output.stderr).contains("--phase-profile"));
        assert!(!String::from_utf8_lossy(&output.stdout).contains("HASHLINE_PROFILE"));
        assert!(!String::from_utf8_lossy(&output.stderr).contains("cannot read"));
    }
}

#[test]
fn phase_profile_refuses_gpu_without_initializing_it() {
    let output = Command::new(env!("CARGO_BIN_EXE_hashline"))
        .args(["pass", "1", "16", "--profile", "v3", "--phase-profile"])
        .env("HL_GPU", "1").output().unwrap();
    assert_eq!(output.status.code(), Some(2));
    assert!(String::from_utf8_lossy(&output.stderr).contains("CPU execution only"));
    assert!(output.stdout.is_empty());
}

#[test]
fn phase_profile_keeps_exact_signed_matmul_output() {
    let a = [-128, 127, 0, -1, 3, -17];
    let weights = [-128, 127, -1, 1, 0, 11];
    let baseline = hashline::chain::matmul_i8_i32(&a, &weights, 2, 3, 2);
    let capture = hashline::phase_profile::Capture::begin(true);
    let measured = hashline::phase_profile::measure("matmul.gate", ||
        hashline::chain::matmul_i8_i32(&a, &weights, 2, 3, 2));
    assert_eq!(baseline, measured);
    let phases = capture.finish().unwrap();
    assert_eq!(phases.len(), 2);
    assert!(phases.iter().any(|p| p.name == "allocation.matmul_output"));
    assert!(phases.iter().any(|p| p.name == "matmul.gate"));
}

//! Unsupported privacy requests must fail before a witness is accessed.
use std::process::Command;

fn rejected(args: &[&str], message: &str) {
    let output = Command::new(env!("CARGO_BIN_EXE_hashline"))
        .args(args).env_remove("HL_GPU").output().unwrap();
    assert_eq!(output.status.code(), Some(2), "{:?}: {}", args, String::from_utf8_lossy(&output.stderr));
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains(message), "{stderr}");
    assert!(!String::from_utf8_lossy(&output.stdout).contains("PROOF sha256"));
}

#[test]
fn attention_never_silently_drops_privacy_requests() {
    for cmd in ["attn-layer", "attn-full", "attn-pass", "attn-chain"] {
        for flag in ["--zk", "--p3", "--predicate", "--output-claim", "--model-id"] {
            rejected(&[cmd, "/nonexistent/zk60-export", "1", flag], "does not implement ZK");
        }
    }
    rejected(&["attn-pass", "/nonexistent/zk60-export", "--zk"], "does not implement ZK");
}

#[test]
fn attention_requires_a_real_layer_count_and_known_chain_options() {
    for layers in ["0", "nonsense", "--t"] {
        rejected(&["attn-pass", "/nonexistent/zk60-export", layers], "positive layer count");
    }
    rejected(&["attn-pass", "/nonexistent/zk60-export"], "positive layer count");
    rejected(&["attn-chain", "/nonexistent/zk60-export", "--unknown"], "accepts only");
}

#[test]
fn a_model_declaration_cannot_be_silently_ignored() {
    rejected(&["pass", "1", "16", "--zk", "--model-id", "example"], "requires --zk --profile v3");
    rejected(&["pass", "1", "16", "--profile", "v3", "--model-id", "example"], "requires --zk --profile v3");
    rejected(&["chain", "1", "--zk"], "does not implement ZK");
}

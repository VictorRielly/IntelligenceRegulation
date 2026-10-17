//! EXPERIMENTAL multi-block private RUN, prove and verify from separate
//! processes. One transcript over `L` blocks with hidden internal boundaries
//! (`private_block::run`), NOT `L` standalone block proofs.
//!
//!   zk60_private_stack prove  --shape p2|m125 --blocks N --out DIR --policy-out FILE
//!                             [--recipe dense-run|dense-run-varied]
//!                             [--context-label LABEL] [--input-seed N]
//!   zk60_private_stack verify --artifact DIR --policy FILE
//!                             [--policy-sha256 HEX] [--expect-shape S]
//!                             [--expect-blocks N] [--expect-recipe R]
//!                             [--expect-context-label L] [--expect-run-profile P]
//!                             [--expect-calibration HEX] [--expect-block-digests HEX]
//!                             [--expect-input-root HEX] [--expect-output-root HEX]
//!
//! SCOPE: the model is a PUBLIC SYNTHETIC dense recipe on a registered
//! development shape, and the input is synthetic. This is not a trained model
//! and not a trained-8B proof, and it is a correctness result with no privacy
//! acceptance. `verify` trusts only the caller's policy file and pins, never
//! the artifact. Output is JSON lines on stdout; exit 0 = accepted, 1 = failed
//! or refused, 2 = bad arguments. Private values are never printed or saved.
//! A heavy 125M run must be launched by the run owner, not by this comment.

fn main() {
    // `args_os`, not `args`: a non-UTF-8 argument must be a clean exit-2 refusal, not a
    // panic. The driver's machine-readable output names paths as JSON strings, which
    // cannot represent non-UTF-8 bytes faithfully, so such arguments are refused up front.
    let mut args: Vec<String> = Vec::new();
    for a in std::env::args_os().skip(1) {
        match a.into_string() {
            Ok(s) => args.push(s),
            Err(_) => {
                eprintln!("zk60_private_stack: an argument is not valid UTF-8; refused");
                std::process::exit(2);
            }
        }
    }
    let code = match args.first().map(String::as_str) {
        Some("prove") => hashline::private_block::prove_command(&args[1..]),
        Some("verify") => hashline::private_block::verify_command(&args[1..]),
        _ => {
            eprintln!("usage: zk60_private_stack prove|verify ... (see the header of examples/zk60_private_stack.rs)");
            2
        }
    };
    std::process::exit(code);
}

//! Experimental R14 true-width trained-stack backend. Uses the existing public
//! export and private sequence formats, authenticates the complete model, and
//! seals/parity-checks every layer before creating the run directory.
//!
//! stack-prove --experimental-r14 --export DIR (--seq ID|--seq-dir DIR) --out DIR
//!             [--layers A..B] [--dd] [--witness-cache-gib G] [--verify-in-process]
//! stack-verify --experimental-r14 --export PUBLIC_DIR --artifact DIR
//!              --expect-statement MODEL_HEX --expect-binding RUN_HEX
//!              [--layers A..B] [--dd]
//!
//! A fresh verifier independently rebuilds the public model, checks both pins,
//! verifies every segment, and publishes its own canonical statement. This
//! example does not register a production profile or claim privacy acceptance.
fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let code = match args.first().map(String::as_str) {
        Some("stack-prove") => {
            hashline::private_block::trained_split_stack_prove_command(&args[1..])
        }
        Some("stack-verify") => {
            hashline::private_block::trained_split_stack_verify_command(&args[1..])
        }
        _ => {
            eprintln!("usage: zk60_split_stack stack-prove|stack-verify --experimental-r14 ...");
            2
        }
    };
    std::process::exit(code);
}

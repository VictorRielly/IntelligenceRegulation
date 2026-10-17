//! NATIVE LANE (2026-10-17): prove and verify ONE TRAINED private block from
//! a calibration export, in separate processes.
//!
//!   zk60_trained_block prove  --export DIR --layer N (--seq ID | --seq-dir DIR) --out DIR
//!                             [--label L] [--rope-from-export] [--controls]
//!   zk60_trained_block verify --export DIR --layer N --artifact DIR
//!                             --expect-statement HEX [--label L]
//!                             [--rope-from-export] [--controls]
//!
//! `DIR` for `--export` is ONE variant directory (`.../export/<variant>/`,
//! schema `zk60-trained-profile-export/1`). `prove` verifies every digest,
//! checks that the native witness reproduces the export's `x_out` bit for bit,
//! proves the block as a one-block run BOUND to the trained-model statement
//! and writes `segment-000.bin`, `expected.bin` and `statement.json` into a
//! new directory. `verify` rebuilds everything from the export's PUBLIC files
//! (never a `seq_*` directory), refuses unless the rebuilt statement identity
//! equals `--expect-statement`, and verifies; `--controls` runs the
//! statement-mismatch and receipt-mutation controls (verify) or the
//! inconsistent-witness controls (prove), each of which must refuse.
//!
//!   zk60_trained_block stack-prove  --export DIR (--seq ID | --seq-dir DIR) --out DIR
//!                             [--layers A..B] [--label L] [--rope-from-export]
//!                             [--verify-in-process] [--witness-cache-gib G]
//!                             [--lie-at-boundary K]
//!   zk60_trained_block stack-verify --export DIR --artifact DIR --expect-statement HEX
//!                             [--layers A..B] [--label L] [--rope-from-export] [--controls]
//!
//! (ROUND 2, R2-3) `stack-prove` proves the listed layers (default: all) as
//! ONE run bound to the trained-model statement — one transcript, block k's
//! hidden output is block k+1's hidden input through a hidden internal
//! boundary. R5b (privacy review P-1): every witness is built, and parity
//! against the export checked at every layer, BEFORE the run header (ruling
//! H-1); one segment per block goes into a new directory; the public
//! statement goes to `<out>/statement/` only after a verification — in
//! process with `--verify-in-process`, otherwise the prover's statement is
//! written beside the run as `<out>.unverified-statement/` and `stack-verify`
//! promotes it after its fresh-process verification passes (M-9 / D12b(1)).
//! `stack-verify` verifies the directory one segment at a time. Verifiers
//! refuse an export directory holding a `seq_*` entry (P-5: hand them a copy
//! of the public files); `--label` admits only the deployment constant
//! (C-R4); `statement.json` records the backend (P-7). stdout from a run on a
//! hidden input is prover-private (P-6).
//!
//! SCOPE: one block of 22 at T = 32 on the CPU (prove/verify); not a model pass; no privacy
//! acceptance at this shape (D22 covers only the toy). Output is JSON lines
//! on stdout; exit 0 = accepted, 1 = refused or failed, 2 = bad arguments.
//! Private values are never printed or saved.

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let code = match args.first().map(String::as_str) {
        Some("prove") => hashline::private_block::trained_prove_command(&args[1..]),
        Some("verify") => hashline::private_block::trained_verify_command(&args[1..]),
        Some("stack-prove") => hashline::private_block::trained_stack_prove_command(&args[1..]),
        Some("stack-verify") => hashline::private_block::trained_stack_verify_command(&args[1..]),
        _ => {
            eprintln!("usage: zk60_trained_block prove|verify ... (see the header of examples/zk60_trained_block.rs)");
            2
        }
    };
    std::process::exit(code);
}

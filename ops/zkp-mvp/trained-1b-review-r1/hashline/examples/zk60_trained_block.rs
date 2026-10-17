//! NATIVE LANE (2026-10-17): prove and verify ONE TRAINED private block from
//! a calibration export, in separate processes.
//!
//!   zk60_trained_block prove  --export DIR --layer N --seq ID --out DIR
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
//! SCOPE: one block of 22 at T = 32 on the CPU; not a model pass; no privacy
//! acceptance at this shape (D22 covers only the toy). Output is JSON lines
//! on stdout; exit 0 = accepted, 1 = refused or failed, 2 = bad arguments.
//! Private values are never printed or saved.

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let code = match args.first().map(String::as_str) {
        Some("prove") => hashline::private_block::trained_prove_command(&args[1..]),
        Some("verify") => hashline::private_block::trained_verify_command(&args[1..]),
        _ => {
            eprintln!("usage: zk60_trained_block prove|verify ... (see the header of examples/zk60_trained_block.rs)");
            2
        }
    };
    std::process::exit(code);
}

//! TOKEN I/O LANE (2026-10-19): ONE private next-token run of a calibration
//! export (Llama-3-8B T32, TinyLlama T32, or the development rung), proved and
//! verified in separate processes.
//!
//!   zk60_token_io prove   --export DIR --emb DIR --head DIR (--seq ID | --seq-dir DIR)
//!                         [--prompt ID,ID,...] --out DIR [--owner-dir DIR] [--label L]
//!   zk60_token_io profile --export DIR --emb DIR --head DIR
//!   zk60_token_io verify  --export DIR --emb DIR --head DIR --artifact DIR
//!                         --expect-statement HEX --expect-token-profile HEX
//!                         [--label L] [--min-bits N]
//!   zk60_token_io owner       (verify's arguments) --decommitment FILE
//!   zk60_token_io input-owner (verify's arguments) --decommitment FILE --prompt ID,ID,...
//!
//! `--export` is ONE variant directory; `--emb` holds `embedding_int16.bin` +
//! `token_io.json`, `--head` holds `head_int8_perrow.bin`, `head_mult12.bin` +
//! `head_manifest.json` (the 8B exports: both `<export>/token_io/`).
//! `prove` writes the segments into `<out>/` (built as `<out>.incomplete/`,
//! renamed after the run returns Ok), an UNVERIFIED statement into
//! `<out>.unverified-statement/` and the two owners' decommitments into the
//! owner directory (`--owner-dir`, default `$HOME/zk60-artifacts/token-io/
//! <run>-<key of the run's canonical path>.owner-private`, printed in the
//! `proved` line; never inside the run's parent; 0700, files 0600; never
//! published; claimed at the start). `profile` prints the two pins of an approved export and
//! table set. `verify` refuses an export holding `seq_*` (hand it a copy of
//! the public files), requires both pins (the trained statement identity and
//! the token profile digest), verifies under `--min-bits` (default 95), and
//! then itself writes `<out>/statement/` (and re-checks it byte for byte when
//! run again). `owner` / `input-owner` first re-run that full check of the
//! published statement against every segment, then check the decommitment
//! (the next token is printed; the input owner's prompt is confirmed).
//! stdout from `prove` is prover-private.
//!
//! SCOPE: public-row variant; CPU unless the statement's backend says
//! otherwise; NO privacy acceptance (the rank / CFS gates on the token stages
//! are owed). JSON lines on stdout; exit 0 = done, 1 = refused, 2 = bad
//! arguments.

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let code = match args.first().map(String::as_str) {
        Some("prove") => hashline::private_block::token_prove_command(&args[1..]),
        Some("verify") => hashline::private_block::token_verify_command(&args[1..]),
        Some("profile") => hashline::private_block::token_profile_command(&args[1..]),
        Some("owner") => hashline::private_block::token_owner_command(&args[1..]),
        Some("input-owner") => hashline::private_block::token_input_owner_command(&args[1..]),
        _ => {
            eprintln!("usage: zk60_token_io prove|profile|verify|owner|input-owner ... (see the header of examples/zk60_token_io.rs)");
            2
        }
    };
    std::process::exit(code);
}

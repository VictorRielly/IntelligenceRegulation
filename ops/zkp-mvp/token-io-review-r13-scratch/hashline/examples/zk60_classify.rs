//! TOKEN I/O ROUND 12 (rung R-C1, 2026-10-21): the CLASSIFIER CLI. One
//! private classifier run of a calibration export under a pre-registered
//! policy (DESIGN_CLASSIFIER v2, results/zk60_token_io_r1_20261017/classifier/):
//! the approved integer model's public verdict (flagged iff the margin
//! `y . w_Delta` exceeds the policy's threshold c) over hidden content.
//!
//!   zk60_classify prove        --export DIR --tables DIR --policy ID --content-file FILE|-
//!                              [--chunk J] (--seq ID | --seq-dir DIR) --out DIR
//!                              [--owner-dir DIR] [--label L]
//!   zk60_classify verify       --export DIR --tables DIR --policy ID --artifact DIR
//!                              --expect-statement HEX [--label L] [--min-bits N]
//!   zk60_classify input-owner  (verify's arguments) --decommitment FILE --content-file FILE|-
//!   zk60_classify label        --export DIR --tables DIR --policy ID --runs DIR,DIR,...
//!                              --expect-statement HEX [--label L] [--min-bits N]
//!
//! `--tables` holds `token_io.json` + `embedding_int16.bin` and
//! `classifier.json` + `margin_int16.bin` (and, at the development rung, the
//! pinned `dev_tied_tensor_bf16.bin`). ROUND 13 (rung R-C2): prove and verify
//! RE-DERIVE the margin row and the embedding's digest from the pinned tied
//! tensor, with the yes / no ids, the public scale and c of the export
//! profile's `classifier_margin_parameters` (the registered policy must agree),
//! and BOS / the final norm from its `token_io_parameters`; a table file that
//! disagrees is refused. `--min-bits` below the profile's floor (93 at the
//! development rung only, else 95: D27) is refused. The content never goes on the
//! command line (`--content` is refused, exit 2). D41: the content file holds
//! the WHOLE content's ids; `--chunk J` proves chunk J of the profile's public
//! split; `label` prints the OR over every chunk run of one item. Every
//! refusal prints the fail-closed outcome line (B-4: no accepted proof is
//! handled as flagged). See `src/private_block/token_io/classify_cli.rs`.
//!
//! SCOPE: the development rung is the registered run profile (Shieldstral's
//! tied source is wired through native R12b's recompute; its classifier run
//! profile is not registered yet); public-row variant; NO privacy acceptance. JSON lines
//! on stdout; exit 0 = done, 1 = refused, 2 = bad arguments. The frozen
//! next-token CLI (`zk60_token_io`) is a separate binary and is unchanged.

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let code = match args.first().map(String::as_str) {
        Some("prove") => hashline::private_block::classify_prove_command(&args[1..]),
        Some("verify") => hashline::private_block::classify_verify_command(&args[1..]),
        Some("input-owner") => hashline::private_block::classify_input_owner_command(&args[1..]),
        Some("label") => hashline::private_block::classify_label_command(&args[1..]),
        _ => {
            eprintln!("usage: zk60_classify prove|verify|input-owner|label ... (see the header of examples/zk60_classify.rs)");
            2
        }
    };
    std::process::exit(code);
}

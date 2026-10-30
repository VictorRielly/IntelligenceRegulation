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
//!                              --expect-statement HEX --expect-total N [--label L] [--min-bits N]
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
//! split; `label` prints the OR over every chunk run of one item. ROUND 14
//! (rung R-C3): a content SHORTER than one chunk is one chunk of its true
//! length, its trailing positions holding the policy's public pad id (the
//! content length is public: D45(1)); statement schema `zk60-classify-run/3`.
//! ROUND 15 (REVIEW_R14 N-r14-1): `label --expect-total N` is required, N being
//! the POST's own token count from the pinned tokenizer; a label is refused
//! unless the chunk runs cover exactly `[0, N)` (a proof set of only the
//! post's first ids is refused).
//! ROUND 16 (native R13, REVIEW_R13 §10): the Shieldstral-1.0-3B LOW + h24
//! exports (schema v2, `low-h24-v1`, `shieldstral-3b-t128` / `-t256`, non-DD)
//! are registered under their own classifier run profiles; each block stage
//! is proved and verified at its layer's bound gate denominator; the D37
//! category policies `shieldstral-1.0-3b-moderate-{sexual,violence,hate}/1`
//! (moderate wording, pending Victor's strict / moderate ruling) are the fixed
//! list; a prove or verify streams the pinned checkpoint ONCE (the loader's
//! pass also derives the margin row).
//! Every refusal prints the fail-closed outcome line (D45(4): no accepted proof
//! is handled as flagged). See `src/private_block/token_io/classify_cli.rs`.
//!
//! SCOPE: the development rung and (round 16) the R13 Shieldstral T128 / T256
//! classifier run profiles (T256 is not proved on the 8 GB laptop);
//! public-row variant; NO privacy acceptance, NO classifier-quality claim. JSON lines
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

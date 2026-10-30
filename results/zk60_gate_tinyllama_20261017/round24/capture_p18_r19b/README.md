# ZK60 classifier run capture bundle

Bundle: a capture through the CLASSIFIER CLI PATH (the native P-18 pattern): the named binary /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/zk60_classify.r19b.release.bin (sha256 6d65d32ea783e36db2458ccce2d459cb29a91bcb45a89c4e23e484914126d609) ran `zk60_classify prove` and `zk60_classify verify` as its own processes (verify from a verifier copy without seq_*, pinned by --expect-statement; it published the statement); then, with no CLI hook, the run directory was read through the CLI's own door (classify_cli::door: the B-3 re-render and the segment reads) and verified with the round-7 recorder attached, and this is that verification's bundle. The rung's tiny export (one layer, seq_s0), the synthetic policy `rung-tc-synthetic-policy-dev/1` (c = 0), verdict 0 (not flagged). The content, every activation and the owner's decommitment are prover-side and NOT here.

What this is: the VERIFIER'S VIEW of one private CLASSIFIER run (stage IN-C, 1 blocks,
stage OUT-C) under one transcript, profile `hashline-zk-mr1/private-classify-run-rung-tc-t32-public-row-dev/1`, written by
`hashline/src/private_block/run_capture.rs` (schema `hashline-native-capture/7-classify-run`). It is the INPUT to the
privacy gate's classifier items (gate round 16) and it is NOT a privacy result: no gate has read it.

What made it:

    HL_PB_CAPTURE_DIR=<dir> HL_PB_CLI_BIN=<zk60_classify binary> HL_PB_CLI_BIN_SHA256=<its sha256> HL_RUN_CAPTURE_PUBLIC_TABLES=<1|0> cargo test --release --lib private_block::token_io::classify_capture_tests::capture_the_classify_cli_verify_path -- --ignored --nocapture

Files: `run.json` (the run header, the shape, `classify` with the classifier facts: the policy,
c, the margin vector's digest, the PUBLIC verdict and D41's chunk; the boundaries in token
numbering: 0 = B_in, L = B_out) and `stage-NN.json` for the 3 stages: stage-00 is stage IN-C
(its slots, M, A-in, H-in and the input token endpoint, and its plane table), stage-01 ..
stage-01 the blocks (each with the Input opening of the boundary before it, B_in at stage-01),
and the last is stage OUT-C (its slots, M, A-out, H-out and B-out, and its plane table; NO output
endpoint). Each stage file carries its segment's length and SHA-256. `manifest.json` lists every
file with its SHA-256 and pins the source files (the classifier's five included).

THE ARRAYS ARE IN `arrays.bin` (schema `hashline-native-capture/5-run`). A field-element
array of at least 256 entries is written in the JSON as
`{"array":"<sha256>","elem":"fp"|"fp2","len":N,"offset":O,"bytes":B}` and its
values are the B bytes at offset O of that file, little-endian: eight bytes
per `fp`, sixteen per `fp2` (`c0` then `c1`). Identical arrays are stored
ONCE and every reference to them names the same offset, which is why the
shape-only public tables cost one copy for the whole bundle rather than one
per slot per stage. Here: 653 references over 628 distinct arrays
(25 resolved to an array already stored), 2568 small arrays left
inline as plain JSON lists, 12294008 bytes of `arrays.bin`. Everything else
is byte for byte what schema `hashline-native-capture/4-run` writes.

NOT in this bundle: any prover-side value, the content's token ids, the margin and its limbs,
and the owner's decommitment (`not_in_a_capture` in `run.json`); every key is on the allow-list.

21281354 bytes of run file, stage files and segments.

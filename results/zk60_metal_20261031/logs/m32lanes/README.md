# m32: post-merge check after the TS / CENSUS / bases lane and the NL-1 / PRE lane (2026-11-02)

The check ran on the main checkout at the NL records merge (011a12bb; code as of d2ae2bc7, with no code change since). The script is
`m32_merge.sh` (m31 with `HL_GPU=1` beside `HL_GPU_REQUIRED=1` in the targeted step, and the TS lane's eight base
bundles in the Python suite). It started from the merged-gate queue (`results/zk60_d60_20261102/privacy_gate_merged/queue.sh`)
once the NL lane's chain had finished, on an otherwise idle heavy lock. Every step went through the resource guard.

| step | result | floor |
|---|---|---|
| build (`--features gpu-metal`, lib tests + check) | exit 0, 143 s, **133 warnings** | 133 |
| targeted (Metal, `HL_GPU=1 HL_GPU_REQUIRED=1`) | **132 passed, 0 failed**, 23 ignored | m31 had one failure (the script set `HL_GPU_REQUIRED` without `HL_GPU`); gone |
| bytes, CPU = Metal | **01fa1b2e / 992034f8 / 371e6b00 / 3ab090df** | the same |
| v25 Python suite | 168 run, 72 skipped, **1 failure: the known `test_r19b_self_check_and_its_control`** | 150 / 71 / 1, plus the TS lane's 10 (one skipped by design) and the NL lane's 8 |
| full Rust suite | **896 passed, 3 failed, 92 ignored**: the known three | 896 / 3 / 92 |

The known three full-suite failures are `review_tests::a_toy_receipt_made_before_the_lane_still_verifies`,
`accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces` and
`review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.

These are not timing figures, because the box was not quiesced for them.

# ZK60 D55 fork-run capture bundle (TEST-ONLY)

D55 privacy gate fixture (D59 condition 5 / D60 prerequisite, 2026-11-02): one honest 3-fork D55 run at the block profile `hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/1` under the D55 profile over the TEST-ONLY run identity `hashline-zk-mr1/private-run-rung-lh-t32-w16r2-t/1`, public synthetic weights (`range16_tests::case`), a hidden synthetic chain from seed 1 (`w16_privacy_gate_tests::rung_chain_at`); proved on this path: gpu: off (built with gpu-metal; HL_GPU unset). Test-only: delete once recorded.

What this is: the VERIFIER'S VIEW of one D55 "commit, fork, join" run of 3 blocks, profile
`d55-commit-fork-join-runs/opt-in-prototype-unregistered/test-only/v1/hashline-zk-mr1/private-run-rung-lh-t32-w16r2-t/1`, recorded by `run_capture.rs`'s fork-run recorder (schema `hashline-native-capture/8-d55-fork-run-prototype`) and written by the
test-only `w16_privacy_gate_tests::write_fork_bundle` (`run_capture::write_bundle` refuses a
fork-run bundle). NOT a privacy result.

What made it:

    HL_W16PG_CAPTURE_DIR=<dir> [HL_W16PG_PROFILES=<names>] [HL_D55PG_L=<L>] <hashline lib test binary> --ignored --exact --nocapture private_block::w16_privacy_gate_tests::d55_privacy_gate_write_the_fork_bundles

Files: `run.json` (header, shape, endpoints, boundaries; the D55 transcript program), `stage-NN.json`
(fork k: its roots, slots, M, A and H openings; it opens no boundary and no endpoint),
`d55_tail.json` (after S1: every boundary opened ONCE with both claims, then the input and output
endpoints), `arrays.bin`, the receipt frames under `receipt/` (head, forks, tail), `manifest.json`.

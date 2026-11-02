# ZK60 D55 fork-run capture bundle (a REGISTERED D55 run profile, D60)

D60 privacy-gate fixture (2026-11-02): one honest 3-fork D55 run under the REGISTERED D55 run profile `hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1` (base `hashline-zk-mr1/private-run-rung-lh-t32-dev/1`), the public synthetic R13 loader fixture r13-h24-wide (layer 0 and its other-gate twin (-4, -13), alternating); hidden input 1: the fixture's public sequence, token rows rotated by 5, every word nudged by ((i 7 + 1) mod 3) - 1; proved and verified on this path: gpu: off (built with gpu-metal; HL_GPU unset). TEST-ONLY SYNTHETIC BUNDLE, NOT FOR PUBLICATION: no real content; delete once recorded.

What this is: the VERIFIER'S VIEW of one D55 "commit, fork, join" run of 3 blocks, profile
`hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1`, recorded by `run_capture.rs`'s fork-run recorder (schema `hashline-native-capture/8-d55-fork-run-prototype`) and written by
`run_capture::write_bundle`. It is the INPUT to the privacy gate and NOT a privacy result.

What made it:

    HL_D60PG_CAPTURE_DIR=<dir> [HL_D60PG_CASES=<PROFILE:hidden,...>] [HL_D60PG_L=<L>] HL_R13_LOADER_FIXTURES=<fixtures> <hashline lib test binary> --ignored --exact --nocapture private_block::run::fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles

Files: `run.json` (header, shape, endpoints, boundaries; the D55 transcript program), `stage-NN.json`
(fork k: its roots, slots, M, A and H openings; it opens no boundary and no endpoint),
`d55_tail.json` (after S1: every boundary opened ONCE with both claims, then the input and output
endpoints), `arrays.bin`, the receipt frames under `receipt/` (head, forks, tail), `manifest.json`.

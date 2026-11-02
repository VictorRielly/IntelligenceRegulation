# m31: post-merge check of gate round 26 wiring (2026-11-02)

Merged `worktree-agent-ad2863f50f3102344` (23199feb..a6d3894e) into `perf/zk-batch-optimizations` by fast-forward
from 6d06b8b0. Script: a copy of m30's, plus the staging v25 Python suite (`m31.out` is the console).

| step | result |
|---|---|
| build | ok, 133 warnings (unchanged) |
| targeted (`tests.log`) | 131 passed, 1 failed, 23 ignored: see below |
| dev bytes (`bytes.log`) | 01fa1b2e / 992034f8 / 371e6b00 / 3ab090df, CPU = Metal (unchanged) |
| v25 Python suite (`py.log`) | 150 run, 1 failure (`test_r19b_self_check_and_its_control`, the r16b..r19b CLI binaries stayed on the laptop; it failed before this work), 71 skipped: identical to the wiring agent's `suite_v25b.log` |
| full suite (`full.log`) | 896 passed, 3 failed, 92 ignored: the known Mac-only three |
| F3 + capture writer on Metal (`f3_metal.log`) | 2 passed (HL_GPU=1 HL_GPU_REQUIRED=1) |

**The one targeted failure is an artefact of this script, not of the code.**
`d60_f3_the_cli_fails_closed_for_a_d55_run_until_the_privacy_gate_passes` launches the CLI as a child process. The
targeted step sets `HL_GPU_REQUIRED=1` without `HL_GPU=1`, so the child refused to start ("HL_GPU_REQUIRED=1 but the
GPU path is not live", `tests.log` line 165). The test did not exist when m30 ran. It passes in the full suite (no
GPU variables) and on Metal (`f3_metal.log`). A later copy of this script should give the targeted step `HL_GPU=1`
too, or drop `HL_GPU_REQUIRED`.

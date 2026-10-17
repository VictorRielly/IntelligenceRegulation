# Tagged hiding commitment CUDA candidate — 2026-09-27

Status: **isolated, unpromoted candidate**. Source lives at `/tmp/zk60-sol-gpu-20260927`, copied from the validated `/tmp/zk60-groups-20260926` candidate without Git metadata or build outputs. `candidate.patch` is the review diff. `pins.json` fixes 184 source files and the exact two compiled debug test binaries. No full private 8B result or speed result follows from this patch.

## Correctness change

The D19 tagged path previously declined GPU work because the resident and streamed CUDA column hashers only supported unkeyed BLAKE3. The core now offers a separate `try_commit_zk_keyed` hook. The default still declines to the CPU oracle; hashline's CUDA backend accepts the key, uses it as the initial chaining value for every chunk and parent compression, and sets `KEYED_HASH` on every compression. Both resident and chunked paths retain the original pads, salts, keyed salted-leaf/inner-node handling, transcript and receipt format. Legacy commitments still call the old unkeyed hook and kernels. An `HL_GPU_REQUIRED=1` diagnostic marker makes successful keyed device dispatch visible to a bounded gate.

Separately, `k_zk_pad_scale` now applies `-pad[i]` and `+pad[i-n]` independently when `q>n`. The old `else if` omitted the negative term in their overlap. This changes only that admitted q>n case and is checked against the CPU polynomial encoder in the device oracle. It is a correctness repair, not a measured optimization. The researcher's proposed fused pad loader was not integrated.

## Changed source

- `zkp-core/src/pcs/backend.rs`, `zkp-core/src/pcs.rs`
- `hashline/src/pcs.rs`, `hashline/src/gpu/mod.rs`, `hashline/src/gpu/cuda.rs`, `hashline/src/gpu/kernels.cu`
- `hashline/tests/zk60_tagged_gpu_commit.rs` (new)

## Validation

Completed in the isolated lane:

- `cargo check --offline --locked --features gpu-cuda -j 2`, with `CUDA_ROOT=/home/victor/cuda-root`: pass.
- `cargo test --offline --locked -j 2 tagged_offer_passes_exact_key_and_decline_keeps_cpu_bytes` in `zkp-core`: one passing core test. It checks exact tag key dispatch, default decline to CPU, root/pad/salt/RNG continuation equality.
- Both exact GPU-feature test binaries compiled with `--offline --locked -j 2 --no-run`; no actual device or CUDA kernel execution is claimed from compilation. The `gpu-cuda` check initially failed because `CUDA_ROOT` was omitted and then passed with the local toolkit root.
- Source and binary hashes in `pins.json`: all matched after the final build.

The first actual-device attempt is retained in `attempt-1/`, including its original `pins.json`, binary hashes and patch. Strict resident keyed hashing passed. Forced chunked hashing failed at the 256-thread launch of `k_hash_cols_stream_keyed` with `CUDA_ERROR_LAUNCH_OUT_OF_RESOURCES`. That exact original CUDA source hash is retained. The second candidate reduced only the keyed streamed launch to 64 threads/block and was recompiled and repinned separately in `attempt-2/`.

**Attempt 2 passed on the RTX 4070** (`attempt-2/device_report.json`, `device.done=0`): keyed resident, forced chunked and forced compact pad-width oracles each passed. The oracle compares all 1,024 keyed leaves at 37/128/129/257 rows with the CPU encoder and hash, including `q>n`, a real 128-row chunk boundary, wrong public key, duplicate opened columns, and the whole tagged commitment root, pads, salts and RNG continuation. The full dense tagged rung-G receipt then passed on CPU and GPU; its GPU run recorded four accepted keyed commitments, typed and byte verification, and truncated-byte refusal. Per-case device diagnostic wall times were 4.255/3.943/3.841 seconds for the three oracles, and 3.245/6.106 seconds for CPU/GPU rung-G receipts. These are correctness gate runtimes on a shared development GPU, not 8B or speed-target measurements.

`attempt-3-legacy/` passed the existing unkeyed 189-case CUDA oracle in 182.03 seconds. Its full debug GPU-feature library run was deliberately stopped after 422.62 seconds; this was an interrupted gate, not an assertion failure. `attempt-4-release/` then ran the full release GPU-feature library in 296.34 seconds: **491 passed, 1 failed, 17 ignored**. The sole failure was `private_block::review_tests::a_toy_receipt_made_before_the_lane_still_verifies`, because all four historical toy-receipt fixture directories were absent from this isolated source copy. No frozen proof gate ran in that attempt. Both attempt records remain unchanged; neither is reported as a passing full-library run.

`attempt-6-release-proof/` ran on host and remains **failed as recorded**. The smallest pre-lane public synthetic toy receipt (2,816,472 bytes) and expected policy (112 bytes) were staged in the isolated copy and pinned against their source. The exact missing-fixture test passed, as did the resident-v2 frozen proof. Resident-v3 exited zero, produced the exact frozen proof SHA-256 and length, logged `PASS-V3 ACCEPT` and `verified=true`, but the runner incorrectly required the v2 text `PASS ACCEPT`. It retained the v3 proof. This is a runner parser false negative, not a proof mismatch; the original failed report and logs remain unchanged.

`attempt-7-frozen-continuation/` **passed on the RTX 4070** (`report.status=passed`, `done=0`). Its runner pinned and adjudicated the attempt-6 result with source, binary, fixture, log, runner and retained-proof hashes. All six remaining frozen 12x512 proof-byte comparisons passed (resident `zk`/`zkv3`, and forced chunked `v2`/`v3`/`zk`/`zkv3`), each with exact proof SHA-256 and length, a profile-specific acceptance marker, and verified GPU timing. The combined evidence comprises the 189-case unkeyed oracle, 491 prior library passes plus one repaired fixture test with 17 ignored, and eight frozen proofs across two attempts. The full-library attempt is still not a single passing run.

The separate six-process synthetic dense 125M CPU/GPU A/B diagnostic in `attempt-5-dense-ab/` also **passed** with all six log hashes matching. Non-warm proving-call means were 32.95 seconds CPU and 17.13 seconds GPU; whole-process means were 39.895 and 30.055 seconds. See [dense125m_ab_analysis.md](dense125m_ab_analysis.md) for individual runs, phase bottlenecks and limits. This shared-laptop diagnostic is not an 8B or proved-tokens/s result.

The local device is an NVIDIA RTX 4070 Laptop GPU with 8188 MiB and driver 566.14, from root's inventory. RTX 5090 readiness, actual 8B layout and VRAM, full P1 privacy acceptance, and >=50 proved tokens/s remain open. The D19b tagged-hash model ruling is still proposed; this implementation does not widen a security statement.

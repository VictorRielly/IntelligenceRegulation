# Read-only review of prepared dense 125M CPU/GPU A/B runner

Inspected `results/zk60_sol_gpu_20260927/attempt-5-dense-ab/run_dense_ab.py`
and the native test `private_block_125m_one_block` in the pinned GPU
candidate. No A/B run or source edit was made in this review. SHA-256
pins of the inspected runner/test are in `dense_ab_review_pins.txt`.

**Current launch status.** As inspected, `attempt-6-release-proof/report.json`
has status `failed`, only three cases, and `resident-v3` has `passed:false`
despite exit code 0. The runner's `readiness()` requires `status=passed`,
nine passed cases and pinned logs, so it correctly refuses to start.
The GPU lane is repairing that prerequisite after a profile-specific
output-marker issue; its replacement evidence needs to be checked before
the A/B is launched. The 189-case legacy oracle is a passed *named case*
inside an overall failed attempt-3 report; `readiness()` intentionally
selects and pins that case, not the report's overall status. The release
library attempt-4 failure is pinned as a missing-fixture diagnostic,
followed by the separate fixture-repair proof gate.

**What the runner measures.** It fixes `HL_PB_WEIGHTS=dense`, launches the
ignored synthetic `Shape::m125()` one-block test in separate processes,
and uses CPU/GPU warmups followed by CPU/GPU/GPU/CPU measured order.
`HL_GPU=1`, `HL_GPU_REQUIRED=1` and `HL_ZK_CHUNK=force` select the GPU
arm; the CPU arm sets `HL_GPU=0`. It checks exact pinned source, binary
and fixtures before starting and before each sample; it requires a zero
exit, one passing test, the counted 40,783,352-byte receipt, no GPU
decline marker, and at least four keyed-commit acceptance markers for a
GPU sample. The native test actually serializes a receipt and calls
`verify_bytes_at` on those bytes. This is same-process fresh verifier
invocation, not an independent fresh-process verifier. The runner's
`complete_model_passes=0` and `complete_model_proved_tokens_per_second=None`
accurately prohibit a full-stack/8B claim.

**Concrete accounting limitations.** The native `prove_seconds` clocks
`prove_inner_at` only. Endpoint preparation precedes it and
`receipt.to_bytes_at` follows it; `verify_seconds` clocks only
`verify_bytes_at`. `wall_seconds` measures the whole subprocess, including
process/CUDA startup, witness build, endpoints, proving, serialization,
verification and runner effects. The reported
`serialize_and_other_seconds = wall - witness - prove - verify` is a
heterogeneous residual, not serialization time, and can be slightly
negative because the native clocks print two decimals. Its
`witness_seconds` starts before fixture/weights/input setup, so it is not
pure witness construction. `peak_rss_mib` is the process's host RSS
high-water value; there is no per-sample peak VRAM measurement. The
report declares `warmups_excluded_from_arm_means=True`, but this script
does **not compute arm means**; any later aggregation must explicitly
exclude rows with `warmup:true` and report order and variance. Fresh
GPU initialization in every GPU process means the samples do not measure
a persistent-stack steady state.

**Guard and attribution limits.** `/proc/meminfo:MemAvailable >=11 GiB`
is checked before each sample, under `/tmp/zk-heavy.lock`. It is a
start condition, not a memory cap or guarantee against interference;
the script does not inspect a cgroup limit, VRAM free/peak, or allocations
during the run. Each sample has a 300-second timeout. Acceptance markers
are unlabelled counts from the keyed backend. `>=4` plus absence of a
decline string is a useful route check only while the test makes exactly
four keyed GPU offers; it does not independently identify A, H or both
endpoints, nor prove each used chunking. The forced switch and pinned
source provide the intended chunking route, but the log/report should
retain per-commit route evidence if it is used for capacity or detailed
speed attribution. CUDA failure can otherwise fall back to a CPU
materialized commitment, which this runner correctly tries to reject
through the decline marker.

**Operational issue to fix before interpreting failures.** If a source
pin, prerequisite, memory guard or other exception fails after `save()`,
the top-level handler writes `error.txt` and `done=1` but does not set
`report.json.status='failed'`; it can leave `waiting-for-heavy-lock` or
`running` in the report. Consumers should treat `done` and `error.txt`
as authoritative on exceptions, or the runner should mark the report
failed in its exception handler. This does not affect successful samples
but can mislead an automated dashboard or a reader of report.json alone.

The script is suitable as a bounded **synthetic one-block CPU/GPU
diagnostic** once its repaired prerequisites pass. It is not a trained
8B, complete-model or 50 proved-token/s measurement; no throughput or
privacy acceptance should be inferred from this A/B.

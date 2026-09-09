# Round-14 retained validation and review evidence

Combined source `df7fb0d6860b41e3af421b9f99d3b672e9736d32`.
The sibling `../zk60_round14_validation.json` adds retained paths and aggregate
results to the raw run records. `index.json` binds every retained file except
itself by full SHA-256 and byte length. Logs and runner records are unmodified.

In the failed `83115b5` run, the raw outer summary's `gpu_executed` remains
false because the runner sets it only after the whole floor stage succeeds.
The retained floor manifest and case logs establish that 189 GPU oracle cases
and all 12 byte comparisons actually passed. The sibling validation JSON records
that distinction; the failed overall floor verdict is not promoted to success.

| Directory | Evidence |
|---|---|
| `registration_only` | Initial successful `7a9273b` run: 218 Rust tests, four frozen CPU proofs, B4 exact reproduction and B5 verification |
| `attempts/merge_compile_1`, `attempts/merge_compile_2` | Two `b044e20` runs stopped at the same E0004 storage cleanup compile error, before GPU execution; fixed by `83115b5` |
| `attempts/floor_lock_failure` | `83115b5`: storage/core tests, oracle and all 12 byte comparisons pass, but default-feature test suite finds the journal lock-lifetime issue; overall manifest is red |
| `combined` | Final combined validator, stage logs/resources, standalone core checks, repeatable two-crate graphs and completion marker |
| `combined/floors` | Original suite-v3 manifest and all case logs, including the bounded hardware oracle and frozen CPU/GPU/chunk proof cases |
| `consumers` | 343 tooling/GPU-log consumer tests, CPU only, exit 0 |
| `review` | PCS review hashes and three held-decoder reproductions against local Fable commit `f8d40a7` |
| `lock_review` | Native inherited-descriptor reproduction and deterministic journal regression before/after the fix; the first native attempt was blocked by the sandbox's Unix socket restriction |

Heavy validation uses two threads and the shared heavy lock. CPU stages apply
an 8-GiB process address-space cap; the bounded GPU floor stage omits that cap
for CUDA virtual reservations. No 5090/full-model throughput qualification is
claimed. The separate unchanged full Python/native suite retains round 11's
546-test result. Ordinary tests repeated in the default-feature floor run are
not added again to the combined unique Rust total.

Large proofs, cache files and binaries remain in scratch. Their executed
commands, lengths and hashes are retained. Original logs/manifests retain
absolute scratch paths; the sibling validation JSON maps logs to these retained
paths without rewriting or invalidating their hashes. Run scripts retain the
original source pin and scratch destination; choose a new scratch directory and
the pinned checkout when reproducing a run.

## Reproducing the held decoder review

The probe first proves/verifies/decodes a normal tiny fixture, then records two
caught panics and one honest-proof decoding refusal. `probes.done` is 0 because
the harness completes, not because the proposed decoder is correct. The
findings and acceptance criteria are in
[the review](../../docs/zkmatrix-poc/ZK60_CL20_ROUND14_REVIEW.md).

`held_source.patch` is the exact Git diff from integrated PCS pin
`76ee27513763b7992bd57638b203b7ce76e6a8ed` to reviewed local pin
`f8d40a74e07ee9d60f869fe323eee2a2f564f067`, restricted to both crates.
`snapshot_sha256.json` records all 94 files of that reviewed snapshot. The
retained reconstruction script was exercised and all 94 hashes matched. This
makes the source reproducible even before Fable publishes the held branch.

From the repository root, choosing a fresh scratch directory:

```sh
python3 results/zk60_round14_evidence/review/reconstruct.py /tmp/cl20-review-repro/snapshot
cp -r results/zk60_round14_evidence/review/probe /tmp/cl20-review-repro/probe
env -u HL_GPU CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 CARGO_NET_OFFLINE=true flock /tmp/zk-heavy.lock cargo run --locked --offline --manifest-path /tmp/cl20-review-repro/probe/Cargo.toml
```

Unset any other locally configured `HL_*` overrides, as the retained original
runner does. The probe uses debug overflow checks and panic unwinding; Fable's
correction should separately test debug and release behavior. The tiny fixtures
and keys elsewhere in this evidence are public test data.

## Reproducing journal lock inheritance

`lock_review/reproduce.rs` uses only the Rust standard library and local Unix
syscalls. It holds a child between fork and exec with a bounded handshake, then
compares close-only cleanup with explicit unlock. Compile it with
`rustc --edition 2021 lock_review/reproduce.rs -o /tmp/zk60-lock-reproduce`
from this evidence directory, then run `/tmp/zk60-lock-reproduce` on the tested
Linux/WSL host. The original sandbox denied the Unix socket pair; `native.log`
records the successful unsandboxed run. Child setup uses only signal-safe
syscalls, an alarm bounds the child wait, and parent cleanup always releases it.

`regression_before.log` records the actual journal test failing on the previous
cleanup implementation. `regression_after.log` records all eight journal unit
tests passing with the fix. The regression models the inherited file description
using a duplicate descriptor, so it does not depend on winning a process-startup
race or require a Unix socket. Both versions use the same assertion that a new
owner can acquire the lock, retains the spent counter, and keeps its lock when
the stale inherited descriptor closes.

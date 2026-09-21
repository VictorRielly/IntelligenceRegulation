# Evidence of the independent adversarial review of stage 28

Report: `docs/zkmatrix-poc/ZK60_BLOCK125M_S28_REVIEW.md`.
Reviewed tip: `309d238`; base `79f0726`. Written 2026-09-21.
Every run below is detached with its exit code in the matching `.done`.

| file | what it is |
|---|---|
| `gate-ambient.log` / `.done` | the whole `--lib private_` filter with this review's tests, ambient rayon pool: **327 passed / 0 failed / 13 ignored, 414.59 s, exit 0** |
| `gate-rayon1.log` / `.done` | the same filter under **`RAYON_NUM_THREADS=1`** — the thread-count control, since every honest proof in it is verified from its own bytes: **327 / 0 / 13, 255.35 s, exit 0** |
| `gate-final.log` / `.done` | the same filter again on the FINAL review code (the authoritative gate): **327 / 0 / 13, 412.62 s, exit 0** |
| `crossver-nolock-m125-l12-dense.log` / `.done` | **the cross-version result**: the twelve-block 125M dense run at `/home/victor/zk60-artifacts/m125-run-l12-dense`, proved by the PRE-stage-28 prover at `0426ad2`, **VERIFIES under the stage-28 verifier in 15.20 s at 476 MiB peak, exit 0**. Verify-only, so it ran outside the heavy lock in its own `MemoryMax=4G, MemorySwapMax=0` scope, on the orchestrator's ruling |
| `crossver-m125-l12-dense.log` / `.done` | the same check queued on the heavy lock behind another lane's jobs; it will run a second time when the lock frees, harmlessly. Empty until then |

The `.seen*` files are a watcher's bookkeeping and carry nothing.

No 125M PROVE was run by this review; the only 125M-shape work here is the
verify above. No privacy claim is made about any run.

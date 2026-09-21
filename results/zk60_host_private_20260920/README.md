# Combined host/private integration — 2026-09-20

**Candidate validation passed; the exact source patch is applied to main.**
All 43 steps pass: 307 storage-feature tests (two explicit capture writers
ignored), private-IO and probe tests under every pool/fold combination,
189 required-device oracle cases, 34 device commitment and 12 cache tests,
20 frozen proof comparisons, and all six CPU/GPU probe arms. `audit.json`
records a second check of 132 sources, twelve binaries and all 43 logs.
`validation/` preserves the complete detached candidate run. Main's rebuild
and additional receipt checks also passed under `main-gate/`: 23 steps,
two fresh receipts, fourteen cross-version verifications / 42 corruption
refusals and 24 GPU-feature P1/P3 tests under all pool/fold settings.
Its independent audit rechecks 132 sources, nine main binaries and 23 logs.

The source snapshot is in `/tmp/wt-zk60-host-private-20260920`, branch
`integrate/zk60-host-private-20260920`, based on accepted row-fold `4bf1fa0`.
Apply the archived patches in order: host, private, norm, pool-control.
The host delta starts at its FSP-L9 tip so it does not overwrite the already
accepted compact-kernel integration or its rollback correction.

`candidate-run.py` is an ARCHIVE of that worktree's runner. Do not run this
copy against main. The actual runner is `results/zk60_host_private_20260920/run.py`
in that worktree. It pins source and binaries, serializes builds/proofs,
retains logs and terminal markers, and refuses to overwrite evidence.
`state.json` records the candidate's terminal state. `main-gate.py` is the
separate main rebuild runner, not an instruction to rerun completed evidence.

The combined source includes corrected plane uploads and lazy cache keys
(04894c7), private staging/fold reuse and the public-endpoint repaired-mask
cost probe (a328dea), norm-alias controls (ad0b55c), and a new dirty-pool
shrink/grow test. `integration.patch` is the exact ten-file source delta
from `4bf1fa0` to validated candidate `3d5c60c`.

Acceptance: complete storage-feature tests including doctests; repaired P1/P3
private-IO checks in every pool/fold configuration; actual-device oracles;
twelve frozen proof hashes; resident/streamed plane paths plus plane/narrow
rollback and warm-cache fallback; three cost-probe arms on CPU/GPU.
No model-width job is launched and no model-scale speed/privacy claim follows.

Floors v11 pins the measured 307-test storage inventory and preserves
versions 1–10. Its 89 Python tests pass (`floors-v11-tests.log`). Core remains
37 and the device oracle remains 189. The toy example publication guard
is a separate change already verified in `../zk60_publication_20260920/`.

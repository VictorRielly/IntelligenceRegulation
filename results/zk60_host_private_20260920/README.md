# Combined host/private integration — 2026-09-20

The source snapshot is in `/tmp/wt-zk60-host-private-20260920`, branch
`integrate/zk60-host-private-20260920`, based on accepted row-fold `4bf1fa0`.
Apply the archived patches in order: host, private, norm, pool-control.
The host delta starts at its FSP-L9 tip so it does not overwrite the already
accepted compact-kernel integration or its rollback correction.

`candidate-run.py` is an ARCHIVE of that worktree's runner. Do not run this
copy against main. The actual runner is `results/zk60_host_private_20260920/run.py`
in that worktree. It pins source and binaries, serializes builds/proofs,
retains logs and terminal markers, and refuses to overwrite evidence.
`state.json` names the detached process and authoritative report.

The combined source includes corrected plane uploads and lazy cache keys
(04894c7), private staging/fold reuse and the public-endpoint repaired-mask
cost probe (a328dea), norm-alias controls (ad0b55c), and a new dirty-pool
shrink/grow test. It is NOT yet accepted into main.

Acceptance: complete storage-feature tests including doctests; repaired P1/P3
private-IO checks in every pool/fold configuration; actual-device oracles;
twelve frozen proof hashes; resident/streamed plane paths plus plane/narrow
rollback and warm-cache fallback; three cost-probe arms on CPU/GPU.
No model-width job is launched and no model-scale speed/privacy claim follows.

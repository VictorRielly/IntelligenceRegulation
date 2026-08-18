# U-PERF2 lane P — THE GPU RUNG, step 4: the descent kernels + the per-round floor

Branch `uperf2-p` (worktree /home/victor/wt-uperf2-p), opened at 151edc9 (=
main after round 8) on 2026-08-18. Ledger: PROGRESS_UPERF2.md "Round 9 ...
Lane P" + "Agent P status". This continues lane L's GPU step 2
(U_PERF2_GPU2_REPORT.md: the fused round / ixf chains on the device, Section
5.2 = the kernel levers) and lane N's GPU step 3 (U_PERF2_GPU3_REPORT.md: the
device tree store, Section 5 = what was left: the kernels, the eq uploads /
per-round floor, the build's step kernel). Hardware as lane L's report states
it (RTX 4070 Laptop, 8,188 MiB, sm_89, WSL2, a 55-70 W-class mobile part;
host Core Ultra 9 185H, 15 GB). Every number carries [MEASURED] / [ASSUMED] /
[MODEL] and a [WSL-BOX NT QUIET|NOISY-SHARED] label — lane Q works
concurrently in /home/victor/wt-uperf2-q; its rigs and mine share the flock.

## 0. One paragraph

(to be written with the final numbers)

## 1. Design

(what changes, why the values are identical — per item)

## 2. What landed (files)

(files, knobs, defaults)

## 3. Differential evidence

(batteries in both builds; the rig digests)

## 4. Measurements

(before/after per item with the same command; the kernels' % of peak before/
after and how it was computed; rig rows; VRAM peaks; what did NOT work)

## 5. What is left / honest state

(the resumption point)

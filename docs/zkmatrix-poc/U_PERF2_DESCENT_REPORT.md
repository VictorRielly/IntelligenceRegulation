# U-PERF2 lane A — the descents (masked fractional-GKR prove) on synthetic packed trees

Branch `uperf2-a` (worktree /home/victor/wt-uperf2-a), opened at c46483a
on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane A — DESCENTS" + "Agent A
status". Box: the WSL box (Intel Core Ultra 9 185H, 22 threads, 15 GB,
no m125 export). Every number below carries a label:
`[WSL-BOX 1T|NT, QUIET|NOISY-SHARED]` (NOISY-SHARED = lane C was
building or running at the same time).

STATUS: SKELETON — sections are filled as the deliverables land.

## 0. One paragraph

(what the lane built, the headline before/after at depth 20 x 8, the
extrapolation to the rig's 208M leaf elements, and what did not land)

## 1. The bench (`uperf-a descent-bench <depth> <l> [n_real] [dt]`)

What it mirrors (bk_pass_run's descent phase), the fixed seeds, the
digest definition, how attribution is taken (observation-only
`prof::timer` phases `a.*` inside gkr/gkr_masked/kfield).

## 2. Attribution at depth 20 x 8 (before)

| phase | seconds | share |
|---|---:|---:|
| (pending) | | |

Peak RSS of the bench (VmHWM): (pending) — the T9 descent-tree
memory question.

## 3. Optimizations, one line each (before / after, byte-identical)

| item | before | after | speedup | evidence |
|---|---:|---:|---:|---|
| (pending) | | | | |

## 4. Thread scaling (ZK_THREADS 1 / 2 / 4 / 8)

(pending)

## 5. Extrapolation to the rig (depth 21-22, l up to 16, ~208M leaf elements)

(pending; the rig's shape does NOT fit this box — the extrapolation is
linear in leaf elements and says so)

## 6. Battery + gates

`uperf-a descent-battery` (shapes, oracle vs fast, ZK_THREADS 1/2/7),
self-test, bh-verifier battery, uperf-pc diff-battery, freeze-check 98
rows vs the baseline capture.

## 7. What is left

(pending)

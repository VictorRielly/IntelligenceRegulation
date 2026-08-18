# U-PERF3 spike S1 / S2 — range facts as booleanity zero-checks; SiLU LogUp as one sumcheck (lane S)

Status: SKELETON (2026-08-18, U-PERF3 round 1, lane S, worktree
wt-uperf3-s, branch uperf3-s, base d1d1963). Ledger: PROGRESS_UPERF3.md
"Agent S status". Box: the WSL box (Intel Core Ultra 9 185H, 22 threads,
15 GB; default CPU build, no GPU). Every number carries a label:
[MEASURED]/[COUNTED]/[MODEL] and [WSL-BOX 1T|8T, QUIET|NOISY-SHARED].

Design memo: U_PERF3_OPENING_LAYER_DESIGN.md §2.2-2.4 (the batched
sumcheck; how the range facts and the SiLU lookup ride it), §5.1/§5.3
(assumptions; the spike definitions), §6.1. The frozen pass is the
ORACLE (UAGB1_TABLE_DESCENT_REPORT.md: the BK pair builder; the
U_PERF2 descent reports: the masked descent kernels as built), never the
patient — no engine file is changed by this lane.

## 0. One paragraph — go / no-go per spike, with the measured ratios

(pending — filled at close)

## 1. What was built (files / functions; what is reused from the frozen code)

(pending)

## 2. S1 — the range facts: method, counts, measurements

(pending)

## 3. S2 — the SiLU lookup: method, equality evidence, measurements

(pending)

## 4. The counted implication for the 12x512 shape and the 8B shape [MODEL]

(pending)

## 5. What is left / caveats — what the spike did NOT test

(pending)

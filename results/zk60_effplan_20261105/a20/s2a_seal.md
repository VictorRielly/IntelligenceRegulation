# A15 sealing-pass clocks: [a20old+cast1] against [a20old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2a_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +0.6% (3, 0) | +1.6% (3, 0) | **+1.1%** | 9.121 / 9.222 |
| one request: sealing user CPU s | -0.5% (3, 3) | -0.7% (3, 3) | **-0.6%** | 32.897 / 32.698 |
| one request: sealing sys CPU s | -6.4% (3, 3) | -0.4% (3, 2) | **-3.4%** | 9.717 / 9.340 |
| one request: sealing involuntary csw | -6.5% (3, 2) | +1.7% (3, 1) | **-2.4%** | 187179.833 / 180862.167 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

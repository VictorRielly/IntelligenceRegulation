# A15 sealing-pass clocks: [a20old+write16] against [a20old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2d_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +1.1% (3, 0) | +0.1% (3, 1) | **+0.6%** | 9.115 / 9.170 |
| one request: sealing user CPU s | -0.1% (3, 2) | -0.3% (3, 3) | **-0.2%** | 32.895 / 32.838 |
| one request: sealing sys CPU s | +1.7% (3, 1) | -0.9% (3, 1) | **+0.4%** | 9.745 / 9.778 |
| one request: sealing involuntary csw | +4.2% (3, 1) | +0.6% (3, 1) | **+2.4%** | 180080.833 / 184372.833 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

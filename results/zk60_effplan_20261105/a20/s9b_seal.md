# A15 sealing-pass clocks: [default] against [default+recpar0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s9b_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -22.8% (3, 3) | -21.6% (3, 3) | **-22.2%** | 4.122 / 3.207 |
| one request: sealing user CPU s | +1.1% (3, 0) | +1.4% (3, 0) | **+1.2%** | 33.612 / 34.032 |
| one request: sealing sys CPU s | -2.3% (3, 2) | +0.9% (3, 1) | **-0.7%** | 8.467 / 8.408 |
| one request: sealing involuntary csw | -4.5% (3, 3) | +4.8% (3, 1) | **+0.1%** | 156301.000 / 156293.000 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

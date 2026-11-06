# A15 sealing-pass clocks: [recpar1+cast0+loads3+write16] against [recpar1+cast0+loads2+write16], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2g_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -14.2% (3, 3) | -14.4% (3, 3) | **-14.3%** | 3.907 / 3.348 |
| one request: sealing user CPU s | +0.6% (3, 0) | +0.2% (3, 1) | **+0.4%** | 33.825 / 33.948 |
| one request: sealing sys CPU s | -1.9% (3, 3) | -2.4% (3, 3) | **-2.1%** | 8.322 / 8.143 |
| one request: sealing involuntary csw | -2.5% (3, 3) | -1.6% (3, 2) | **-2.1%** | 150672.667 / 147574.833 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

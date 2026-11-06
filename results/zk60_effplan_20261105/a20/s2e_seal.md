# A15 sealing-pass clocks: [recpar1+cast0+loads3+write16] against [a20old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2e_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -64.4% (3, 3) | -63.7% (3, 3) | **-64.0%** | 9.219 / 3.317 |
| one request: sealing user CPU s | +1.5% (3, 0) | +1.1% (3, 0) | **+1.3%** | 33.178 / 33.615 |
| one request: sealing sys CPU s | -20.8% (3, 3) | -15.0% (3, 3) | **-17.9%** | 9.802 / 8.038 |
| one request: sealing involuntary csw | -24.6% (3, 3) | -15.7% (3, 3) | **-20.1%** | 184880.833 / 146892.000 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

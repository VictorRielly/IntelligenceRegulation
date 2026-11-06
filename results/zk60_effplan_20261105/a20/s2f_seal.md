# A15 sealing-pass clocks: [recpar1+cast0+loads4+write16] against [recpar1+cast0+loads3+write16], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2f_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -3.2% (3, 3) | -4.4% (3, 3) | **-3.8%** | 3.389 / 3.260 |
| one request: sealing user CPU s | +0.9% (3, 0) | -0.1% (3, 2) | **+0.4%** | 33.963 / 34.087 |
| one request: sealing sys CPU s | +3.7% (3, 0) | -3.2% (3, 2) | **+0.3%** | 8.767 / 8.780 |
| one request: sealing involuntary csw | +6.8% (3, 0) | -7.0% (3, 2) | **-0.1%** | 174208.167 / 172974.833 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

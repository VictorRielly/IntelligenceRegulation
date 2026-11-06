# A15 sealing-pass clocks: [default] against [a20old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s9a_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -66.3% (3, 3) | -66.2% (3, 3) | **-66.2%** | 9.258 / 3.127 |
| one request: sealing user CPU s | +1.5% (3, 0) | +1.9% (3, 0) | **+1.7%** | 33.193 / 33.767 |
| one request: sealing sys CPU s | -18.1% (3, 3) | -16.0% (3, 3) | **-17.0%** | 9.782 / 8.107 |
| one request: sealing involuntary csw | -25.1% (3, 3) | -20.6% (3, 3) | **-22.9%** | 183806.000 / 141148.500 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

# A15 sealing-pass clocks: [default] against [default+b3par0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s2e_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -12.9% (3, 3) | -14.4% (3, 3) | **-13.6%** | 3.005 / 2.596 |
| one request: sealing user CPU s | +3.2% (3, 0) | +2.3% (3, 0) | **+2.8%** | 21.453 / 22.043 |
| one request: sealing sys CPU s | +9.5% (3, 0) | +9.1% (3, 0) | **+9.3%** | 9.673 / 10.572 |
| one request: sealing involuntary csw | +18.2% (3, 0) | +14.9% (3, 0) | **+16.6%** | 177230.667 / 206804.167 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

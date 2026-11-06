# A15 sealing-pass clocks: [default] against [a21old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s2c_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -20.2% (3, 3) | -19.7% (3, 3) | **-20.0%** | 3.245 / 2.597 |
| one request: sealing user CPU s | -35.3% (3, 3) | -35.9% (3, 3) | **-35.6%** | 34.028 / 21.917 |
| one request: sealing sys CPU s | +20.1% (3, 0) | +19.3% (3, 0) | **+19.7%** | 8.730 / 10.445 |
| one request: sealing involuntary csw | +29.4% (3, 0) | +26.9% (3, 0) | **+28.2%** | 159572.667 / 203409.333 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

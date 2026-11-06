# A15 sealing-pass clocks: [default] against [a21old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s9a_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -18.6% (3, 3) | -19.8% (3, 3) | **-19.2%** | 3.199 / 2.584 |
| one request: sealing user CPU s | -34.8% (3, 3) | -35.4% (3, 3) | **-35.1%** | 33.960 / 22.045 |
| one request: sealing sys CPU s | +23.8% (3, 0) | +22.8% (3, 0) | **+23.3%** | 8.535 / 10.517 |
| one request: sealing involuntary csw | +36.9% (3, 0) | +34.0% (3, 0) | **+35.4%** | 152558.667 / 205873.333 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

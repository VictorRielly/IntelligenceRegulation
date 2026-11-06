# A15 sealing-pass clocks: [ahead16] against [noahead], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326/results/zk60_effplan_20261105/a19/raw/s2a_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +0.9% (3, 0) | +0.9% (3, 0) | **+0.9%** | 9.114 / 9.198 |
| one request: sealing user CPU s | +11.9% (3, 0) | +11.5% (3, 0) | **+11.7%** | 32.868 / 36.718 |
| one request: sealing sys CPU s | +25.3% (3, 0) | +24.0% (3, 0) | **+24.7%** | 9.433 / 11.747 |
| one request: sealing involuntary csw | +2.2% (3, 1) | +1.0% (3, 1) | **+1.6%** | 177870.333 / 180111.333 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

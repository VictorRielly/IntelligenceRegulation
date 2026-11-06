# A15 sealing-pass clocks: [share1+noahead] against [share0+noahead], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326/results/zk60_effplan_20261105/a19/raw/s2b_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +2.0% (3, 0) | +2.0% (3, 0) | **+2.0%** | 8.940 / 9.120 |
| one request: sealing user CPU s | +0.5% (3, 0) | +0.7% (3, 0) | **+0.6%** | 32.605 / 32.797 |
| one request: sealing sys CPU s | +11.0% (3, 0) | +13.9% (3, 0) | **+12.4%** | 8.428 / 9.463 |
| one request: sealing involuntary csw | -2.8% (3, 2) | +4.3% (3, 2) | **+0.8%** | 175187.500 / 175359.833 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

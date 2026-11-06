# A15 sealing-pass clocks: [ahead16] against [noahead], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326/results/zk60_effplan_20261105/a19/raw/s2c_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +4.7% (3, 0) | +3.9% (3, 0) | **+4.3%** | 2.357 / 2.457 |
| one request: sealing user CPU s | +31.5% (3, 0) | +32.1% (3, 0) | **+31.8%** | 13.277 / 17.500 |
| one request: sealing sys CPU s | +23.6% (3, 0) | +20.9% (3, 0) | **+22.2%** | 9.533 / 11.630 |
| one request: sealing involuntary csw | +31.0% (3, 0) | +38.9% (3, 0) | **+35.0%** | 159893.833 / 215661.667 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

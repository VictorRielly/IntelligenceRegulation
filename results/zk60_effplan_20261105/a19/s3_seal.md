# A15 sealing-pass clocks: [ahead32] against [noahead], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326/results/zk60_effplan_20261105/a19/raw/s3_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +2.4% (3, 0) | +2.3% (3, 0) | **+2.3%** | 9.066 / 9.277 |
| one request: sealing user CPU s | +24.0% (3, 0) | +23.9% (3, 0) | **+24.0%** | 32.677 / 40.507 |
| one request: sealing sys CPU s | +61.4% (3, 0) | +55.6% (3, 0) | **+58.5%** | 9.573 / 15.163 |
| one request: sealing involuntary csw | +21.0% (3, 0) | +17.6% (3, 0) | **+19.3%** | 165107.000 / 196910.500 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

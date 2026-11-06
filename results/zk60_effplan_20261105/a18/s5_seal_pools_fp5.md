# A15 sealing-pass clocks: [fp5] against [fpauto], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s5_pools.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +0.4% (3, 1) | +3.0% (3, 0) | **+1.7%** | 1.533 / 1.558 |
| one request: sealing user CPU s | -0.1% (3, 2) | -0.4% (3, 1) | **-0.3%** | 5.363 / 5.348 |
| one request: sealing sys CPU s | +0.8% (3, 1) | +6.7% (3, 0) | **+3.7%** | 3.157 / 3.255 |
| one request: sealing involuntary csw | -6.1% (3, 3) | +1.0% (3, 1) | **-2.5%** | 27546.000 / 26785.167 |
| stream: request 0's sealing pass s (alone) | -0.3% (3, 2) | +4.1% (3, 0) | **+1.9%** | 1.533 / 1.561 |
| stream: requests 1.. sealing pass s (beside the forks) | -0.6% (3, 2) | -6.4% (3, 3) | **-3.5%** | 2.674 / 2.579 |

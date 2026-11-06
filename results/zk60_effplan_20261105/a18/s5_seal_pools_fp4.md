# A15 sealing-pass clocks: [fp4] against [fpauto], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s5_pools.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -1.4% (3, 2) | +2.2% (3, 0) | **+0.4%** | 1.533 / 1.539 |
| one request: sealing user CPU s | -1.6% (3, 2) | +0.6% (3, 1) | **-0.5%** | 5.363 / 5.335 |
| one request: sealing sys CPU s | +0.2% (3, 1) | +2.1% (3, 0) | **+1.1%** | 3.157 / 3.192 |
| one request: sealing involuntary csw | -5.4% (3, 2) | -5.2% (3, 3) | **-5.3%** | 27546.000 / 26006.833 |
| stream: request 0's sealing pass s (alone) | +9.0% (3, 1) | +2.1% (3, 1) | **+5.5%** | 1.533 / 1.618 |
| stream: requests 1.. sealing pass s (beside the forks) | -12.4% (3, 3) | -8.5% (3, 3) | **-10.5%** | 2.674 / 2.394 |

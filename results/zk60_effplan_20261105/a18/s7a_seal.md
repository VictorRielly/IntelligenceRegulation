# A15 sealing-pass clocks: [a18def] against [a18old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s7a_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -4.9% (3, 3) | -0.6% (3, 3) | **-2.8%** | 1.572 / 1.528 |
| one request: sealing user CPU s | -0.6% (3, 3) | +0.6% (3, 1) | **+0.0%** | 5.313 / 5.315 |
| one request: sealing sys CPU s | -13.1% (3, 3) | -3.2% (3, 1) | **-8.1%** | 3.352 / 3.077 |
| one request: sealing involuntary csw | -5.2% (3, 2) | -3.2% (3, 2) | **-4.2%** | 30668.333 / 29317.500 |
| stream: request 0's sealing pass s (alone) | +4.6% (3, 1) | +0.9% (3, 1) | **+2.7%** | 1.568 / 1.613 |
| stream: requests 1.. sealing pass s (beside the forks) | +1.4% (3, 1) | +1.1% (3, 1) | **+1.3%** | 2.603 / 2.636 |

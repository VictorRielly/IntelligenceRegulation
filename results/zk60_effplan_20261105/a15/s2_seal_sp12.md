# A15 sealing-pass clocks: [sp12] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -21.3% (2, 2) | -22.3% (2, 2) | **-21.8%** | 4.355 / 3.406 |
| one request: sealing user CPU s | -45.1% (2, 2) | -45.9% (2, 2) | **-45.5%** | 15.760 / 8.592 |
| one request: sealing sys CPU s | -79.9% (2, 2) | -80.1% (2, 2) | **-80.0%** | 28.240 / 5.647 |
| one request: sealing involuntary csw | -84.3% (2, 2) | -84.2% (2, 2) | **-84.3%** | 628939.250 / 99030.000 |
| stream: request 0's sealing pass s (alone) | -22.3% (2, 2) | -22.9% (2, 2) | **-22.6%** | 4.363 / 3.377 |
| stream: requests 1.. sealing pass s (beside the forks) | -14.1% (2, 2) | -13.3% (2, 2) | **-13.7%** | 5.372 / 4.636 |

# A15 sealing-pass clocks: [sp8] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -20.3% (2, 2) | -23.7% (2, 2) | **-22.0%** | 4.355 / 3.397 |
| one request: sealing user CPU s | -51.5% (2, 2) | -51.7% (2, 2) | **-51.6%** | 15.760 / 7.633 |
| one request: sealing sys CPU s | -89.6% (2, 2) | -89.7% (2, 2) | **-89.6%** | 28.240 / 2.928 |
| one request: sealing involuntary csw | -93.5% (2, 2) | -93.8% (2, 2) | **-93.7%** | 628939.250 / 39860.250 |
| stream: request 0's sealing pass s (alone) | -23.7% (2, 2) | -23.9% (2, 2) | **-23.8%** | 4.363 / 3.326 |
| stream: requests 1.. sealing pass s (beside the forks) | -14.8% (2, 2) | -14.3% (2, 2) | **-14.6%** | 5.372 / 4.590 |

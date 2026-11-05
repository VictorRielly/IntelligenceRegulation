# A15 sealing-pass clocks: [sp4] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -12.5% (2, 2) | -12.0% (2, 2) | **-12.2%** | 4.355 / 3.823 |
| one request: sealing user CPU s | -54.9% (2, 2) | -54.7% (2, 2) | **-54.8%** | 15.760 / 7.125 |
| one request: sealing sys CPU s | -95.1% (2, 2) | -94.9% (2, 2) | **-95.0%** | 28.240 / 1.413 |
| one request: sealing involuntary csw | -98.1% (2, 2) | -98.2% (2, 2) | **-98.2%** | 628939.250 / 11419.250 |
| stream: request 0's sealing pass s (alone) | -12.4% (2, 2) | -11.8% (2, 2) | **-12.1%** | 4.363 / 3.835 |
| stream: requests 1.. sealing pass s (beside the forks) | -7.1% (2, 2) | -7.6% (2, 2) | **-7.4%** | 5.372 / 4.976 |

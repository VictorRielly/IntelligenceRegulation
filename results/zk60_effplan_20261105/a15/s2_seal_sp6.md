# A15 sealing-pass clocks: [sp6] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -19.9% (2, 2) | -19.5% (2, 2) | **-19.7%** | 4.355 / 3.498 |
| one request: sealing user CPU s | -53.1% (2, 2) | -53.1% (2, 2) | **-53.1%** | 15.760 / 7.397 |
| one request: sealing sys CPU s | -93.5% (2, 2) | -93.4% (2, 2) | **-93.4%** | 28.240 / 1.855 |
| one request: sealing involuntary csw | -96.3% (2, 2) | -96.4% (2, 2) | **-96.3%** | 628939.250 / 23189.250 |
| stream: request 0's sealing pass s (alone) | -21.2% (2, 2) | -20.7% (2, 2) | **-20.9%** | 4.363 / 3.450 |
| stream: requests 1.. sealing pass s (beside the forks) | -13.1% (2, 2) | -12.1% (2, 2) | **-12.6%** | 5.372 / 4.695 |

# A15 sealing-pass clocks: [sp16] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -18.3% (2, 2) | -19.6% (2, 2) | **-19.0%** | 4.355 / 3.529 |
| one request: sealing user CPU s | -37.8% (2, 2) | -39.1% (2, 2) | **-38.5%** | 15.760 / 9.695 |
| one request: sealing sys CPU s | -67.7% (2, 2) | -67.8% (2, 2) | **-67.7%** | 28.240 / 9.107 |
| one request: sealing involuntary csw | -71.6% (2, 2) | -72.2% (2, 2) | **-71.9%** | 628939.250 / 176683.500 |
| stream: request 0's sealing pass s (alone) | -18.3% (2, 2) | -19.9% (2, 2) | **-19.1%** | 4.363 / 3.527 |
| stream: requests 1.. sealing pass s (beside the forks) | -12.3% (2, 2) | -13.3% (2, 2) | **-12.8%** | 5.372 / 4.684 |

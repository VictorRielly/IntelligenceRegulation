# A15 sealing-pass clocks: [spg] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -1.4% (2, 1) | -1.0% (2, 1) | **-1.2%** | 4.355 / 4.303 |
| one request: sealing user CPU s | -0.8% (2, 1) | -0.9% (2, 2) | **-0.8%** | 15.760 / 15.627 |
| one request: sealing sys CPU s | -4.4% (2, 2) | -3.5% (2, 2) | **-4.0%** | 28.240 / 27.133 |
| one request: sealing involuntary csw | +0.5% (2, 1) | -1.2% (2, 1) | **-0.4%** | 628939.250 / 626589.000 |
| stream: request 0's sealing pass s (alone) | -1.9% (2, 2) | -1.6% (2, 2) | **-1.7%** | 4.363 / 4.288 |
| stream: requests 1.. sealing pass s (beside the forks) | +1.1% (2, 1) | +0.3% (2, 1) | **+0.7%** | 5.372 / 5.409 |

# A15 sealing-pass clocks: [spauto+lazy0] against [spauto], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s3_lazy_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +0.6% (3, 1) | +0.9% (3, 0) | **+0.8%** | 3.355 / 3.381 |
| one request: sealing user CPU s | +0.1% (3, 1) | +0.3% (3, 0) | **+0.2%** | 7.702 / 7.718 |
| one request: sealing sys CPU s | +1.4% (3, 0) | +0.7% (3, 0) | **+1.1%** | 2.897 / 2.927 |
| one request: sealing involuntary csw | +3.0% (3, 1) | +0.6% (3, 1) | **+1.8%** | 39985.167 / 40681.333 |
| stream: request 0's sealing pass s (alone) | -1.8% (3, 1) | +0.4% (3, 1) | **-0.7%** | 3.407 / 3.381 |
| stream: requests 1.. sealing pass s (beside the forks) | +1.6% (3, 1) | -0.1% (3, 2) | **+0.8%** | 4.542 / 4.576 |

# A15 sealing-pass clocks: [looked1+checked1] against [looked1], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528/results/zk60_effplan_20261105/a17/raw/s5_checked_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +0.9% (3, 0) | +1.0% (3, 0) | **+0.9%** | 3.352 / 3.383 |
| one request: sealing user CPU s | +0.6% (3, 1) | +0.3% (3, 0) | **+0.5%** | 7.692 / 7.727 |
| one request: sealing sys CPU s | +1.1% (3, 1) | +0.6% (3, 0) | **+0.8%** | 2.923 / 2.947 |
| one request: sealing involuntary csw | -1.3% (3, 2) | +0.8% (3, 1) | **-0.3%** | 40683.833 / 40552.000 |
| stream: request 0's sealing pass s (alone) | +1.0% (3, 1) | -0.4% (3, 2) | **+0.3%** | 3.376 / 3.386 |
| stream: requests 1.. sealing pass s (beside the forks) | -2.5% (3, 2) | -1.3% (3, 3) | **-1.9%** | 4.536 / 4.450 |

# A15 sealing-pass clocks: [a17new] against [a17old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528/results/zk60_effplan_20261105/a17/raw/s5_default_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -0.2% (3, 2) | +1.1% (3, 2) | **+0.4%** | 3.365 / 3.380 |
| one request: sealing user CPU s | +0.1% (3, 2) | -0.3% (3, 2) | **-0.1%** | 7.662 / 7.655 |
| one request: sealing sys CPU s | +1.1% (3, 1) | +0.3% (3, 1) | **+0.7%** | 2.958 / 2.978 |
| one request: sealing involuntary csw | +0.2% (3, 1) | +1.0% (3, 1) | **+0.6%** | 41691.500 / 41956.000 |
| stream: request 0's sealing pass s (alone) | +1.8% (3, 1) | +0.4% (3, 1) | **+1.1%** | 3.358 / 3.393 |
| stream: requests 1.. sealing pass s (beside the forks) | -1.8% (3, 3) | -2.5% (3, 3) | **-2.1%** | 4.623 / 4.523 |

# A15 sealing-pass clocks: [a17new] against [a17old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528/results/zk60_effplan_20261105/a17/raw/s3_whole_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +0.9% (3, 1) | +2.2% (3, 0) | **+1.5%** | 3.389 / 3.441 |
| one request: sealing user CPU s | +0.7% (3, 1) | +0.9% (3, 0) | **+0.8%** | 7.693 / 7.755 |
| one request: sealing sys CPU s | +1.2% (3, 0) | +2.6% (3, 0) | **+1.9%** | 2.955 / 3.012 |
| one request: sealing involuntary csw | -0.2% (3, 2) | +0.4% (3, 2) | **+0.1%** | 41625.167 / 41658.667 |
| stream: request 0's sealing pass s (alone) | +0.5% (3, 0) | +0.8% (3, 1) | **+0.7%** | 3.373 / 3.396 |
| stream: requests 1.. sealing pass s (beside the forks) | +1.2% (3, 0) | +3.6% (3, 0) | **+2.4%** | 4.626 / 4.733 |

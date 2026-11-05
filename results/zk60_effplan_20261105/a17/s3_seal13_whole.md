# A13 one-request clocks: [a17new] against [a17old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528/results/zk60_effplan_20261105/a17/raw/s3_whole_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +0.2% (3, 1) | +0.6% (3, 1) | **+0.4%** | 7.481 / 7.511 |
| sealing pass s | +0.9% (3, 1) | +2.2% (3, 0) | **+1.5%** | 3.389 / 3.441 |
| sealing CPU-s | +0.9% (3, 0) | +1.3% (3, 0) | **+1.1%** | 10.650 / 10.767 |
| prove call s | -0.3% (3, 1) | -0.8% (3, 2) | **-0.5%** | 4.093 / 4.070 |
| forks phase (of the request) s | -1.1% (3, 2) | -1.2% (3, 2) | **-1.2%** | 3.714 / 3.671 |
| preflight + commit s | +11.3% (3, 1) | +6.2% (3, 1) | **+8.7%** | 0.297 / 0.322 |

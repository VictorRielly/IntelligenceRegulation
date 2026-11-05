# A13 one-request clocks: [looked1+checked1] against [looked1], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528/results/zk60_effplan_20261105/a17/raw/s5_checked_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +0.2% (3, 1) | +1.5% (3, 1) | **+0.8%** | 7.283 / 7.342 |
| sealing pass s | +0.9% (3, 0) | +1.0% (3, 0) | **+0.9%** | 3.352 / 3.383 |
| sealing CPU-s | +0.6% (3, 0) | +0.6% (3, 0) | **+0.6%** | 10.600 / 10.667 |
| prove call s | -0.4% (3, 2) | +1.9% (3, 1) | **+0.7%** | 3.931 / 3.959 |
| forks phase (of the request) s | +0.3% (3, 1) | +2.2% (3, 1) | **+1.3%** | 3.543 / 3.587 |
| preflight + commit s | -6.8% (3, 2) | +0.0% (3, 1) | **-3.4%** | 0.306 / 0.294 |

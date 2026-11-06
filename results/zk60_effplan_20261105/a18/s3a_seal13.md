# A13 one-request clocks: [a18new] against [a18old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s3a_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +1.7% (3, 1) | -1.1% (3, 3) | **+0.3%** | 5.457 / 5.472 |
| sealing pass s | +0.1% (3, 1) | -2.9% (3, 3) | **-1.4%** | 1.500 / 1.480 |
| sealing CPU-s | +0.4% (3, 0) | -1.2% (3, 2) | **-0.4%** | 8.100 / 8.067 |
| prove call s | +2.3% (3, 1) | -0.4% (3, 3) | **+0.9%** | 3.957 / 3.993 |
| forks phase (of the request) s | +2.4% (3, 1) | -0.3% (3, 2) | **+1.1%** | 3.595 / 3.632 |
| preflight + commit s | +0.0% (3, 1) | -3.5% (3, 2) | **-1.7%** | 0.286 / 0.281 |

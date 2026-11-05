# A13 one-request clocks: [spg] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -0.3% (2, 1) | -1.0% (2, 1) | **-0.6%** | 8.441 / 8.387 |
| sealing pass s | -1.4% (2, 1) | -1.0% (2, 1) | **-1.2%** | 4.355 / 4.303 |
| sealing CPU-s | -3.0% (2, 2) | -2.5% (2, 2) | **-2.8%** | 43.975 / 42.775 |
| prove call s | +0.8% (2, 0) | -0.9% (2, 2) | **-0.0%** | 4.086 / 4.084 |
| forks phase (of the request) s | +0.5% (2, 1) | -1.0% (2, 2) | **-0.3%** | 3.712 / 3.701 |
| preflight + commit s | +4.7% (2, 1) | +4.2% (2, 0) | **+4.5%** | 0.293 / 0.306 |

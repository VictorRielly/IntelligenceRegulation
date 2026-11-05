# A13 one-request clocks: [sp6] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -11.6% (2, 2) | -10.9% (2, 2) | **-11.3%** | 8.441 / 7.488 |
| sealing pass s | -19.9% (2, 2) | -19.5% (2, 2) | **-19.7%** | 4.355 / 3.498 |
| sealing CPU-s | -79.0% (2, 2) | -78.9% (2, 2) | **-79.0%** | 43.975 / 9.250 |
| prove call s | -2.9% (2, 2) | -1.7% (2, 2) | **-2.3%** | 4.086 / 3.990 |
| forks phase (of the request) s | -3.6% (2, 2) | -1.4% (2, 2) | **-2.5%** | 3.712 / 3.617 |
| preflight + commit s | +4.9% (2, 0) | -2.8% (2, 1) | **+1.0%** | 0.293 / 0.296 |

# A13 one-request clocks: [sp16] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -8.9% (2, 2) | -10.4% (2, 2) | **-9.6%** | 8.441 / 7.627 |
| sealing pass s | -18.3% (2, 2) | -19.6% (2, 2) | **-19.0%** | 4.355 / 3.529 |
| sealing CPU-s | -56.9% (2, 2) | -57.4% (2, 2) | **-57.2%** | 43.975 / 18.825 |
| prove call s | +1.0% (2, 0) | -0.4% (2, 1) | **+0.3%** | 4.086 / 4.098 |
| forks phase (of the request) s | +0.8% (2, 0) | -0.1% (2, 1) | **+0.3%** | 3.712 / 3.724 |
| preflight + commit s | +4.0% (2, 1) | -0.5% (2, 1) | **+1.7%** | 0.293 / 0.298 |

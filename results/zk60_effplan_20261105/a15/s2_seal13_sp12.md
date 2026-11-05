# A13 one-request clocks: [sp12] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -11.1% (2, 2) | -11.6% (2, 2) | **-11.3%** | 8.441 / 7.485 |
| sealing pass s | -21.3% (2, 2) | -22.3% (2, 2) | **-21.8%** | 4.355 / 3.406 |
| sealing CPU-s | -67.4% (2, 2) | -67.8% (2, 2) | **-67.6%** | 43.975 / 14.250 |
| prove call s | -0.3% (2, 1) | -0.0% (2, 1) | **-0.2%** | 4.086 / 4.079 |
| forks phase (of the request) s | -0.6% (2, 1) | -0.5% (2, 1) | **-0.6%** | 3.712 / 3.689 |
| preflight + commit s | +4.7% (2, 1) | +10.7% (2, 0) | **+7.7%** | 0.293 / 0.316 |

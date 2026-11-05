# A13 one-request clocks: [sp4] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -5.1% (2, 2) | -5.7% (2, 2) | **-5.4%** | 8.441 / 7.988 |
| sealing pass s | -12.5% (2, 2) | -12.0% (2, 2) | **-12.2%** | 4.355 / 3.823 |
| sealing CPU-s | -80.7% (2, 2) | -80.4% (2, 2) | **-80.6%** | 43.975 / 8.550 |
| prove call s | +2.7% (2, 0) | +1.1% (2, 1) | **+1.9%** | 4.086 / 4.164 |
| forks phase (of the request) s | +2.7% (2, 0) | +1.7% (2, 1) | **+2.2%** | 3.712 / 3.792 |
| preflight + commit s | +3.3% (2, 1) | -1.1% (2, 1) | **+1.1%** | 0.293 / 0.296 |

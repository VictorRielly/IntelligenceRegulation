# A13 one-request clocks: [sp8] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -10.8% (2, 2) | -11.3% (2, 2) | **-11.0%** | 8.441 / 7.509 |
| sealing pass s | -20.3% (2, 2) | -23.7% (2, 2) | **-22.0%** | 4.355 / 3.397 |
| sealing CPU-s | -76.0% (2, 2) | -76.0% (2, 2) | **-76.0%** | 43.975 / 10.550 |
| prove call s | -0.8% (2, 2) | +2.0% (2, 0) | **+0.6%** | 4.086 / 4.112 |
| forks phase (of the request) s | -1.4% (2, 2) | +0.9% (2, 1) | **-0.2%** | 3.712 / 3.703 |
| preflight + commit s | +7.3% (2, 0) | +18.3% (2, 0) | **+12.8%** | 0.293 / 0.332 |

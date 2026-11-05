# A13 one-request clocks: [spauto] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s3_default_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -13.2% (3, 3) | -12.3% (3, 3) | **-12.7%** | 8.419 / 7.346 |
| sealing pass s | -23.8% (3, 3) | -23.4% (3, 3) | **-23.6%** | 4.368 / 3.336 |
| sealing CPU-s | -76.4% (3, 3) | -76.5% (3, 3) | **-76.4%** | 44.400 / 10.467 |
| prove call s | -1.7% (3, 3) | -0.3% (3, 2) | **-1.0%** | 4.051 / 4.009 |
| forks phase (of the request) s | -1.5% (3, 3) | -0.5% (3, 3) | **-1.0%** | 3.666 / 3.630 |
| preflight + commit s | -3.1% (3, 1) | +2.9% (3, 1) | **-0.1%** | 0.302 / 0.300 |

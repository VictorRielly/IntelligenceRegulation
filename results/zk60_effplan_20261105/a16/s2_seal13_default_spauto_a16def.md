# A13 one-request clocks: [spauto+a16def] against [spauto+a16old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s2_default_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -30.6% (3, 3) | -20.9% (3, 3) | **-25.8%** | 8.713 / 6.267 |
| sealing pass s | -49.6% (3, 3) | -48.7% (3, 3) | **-49.1%** | 3.675 / 1.862 |
| sealing CPU-s | -4.7% (3, 3) | -7.4% (3, 3) | **-6.0%** | 11.000 / 10.317 |
| prove call s | -15.8% (3, 2) | +1.4% (3, 1) | **-7.2%** | 5.039 / 4.405 |
| forks phase (of the request) s | -16.6% (3, 2) | +1.1% (3, 1) | **-7.7%** | 4.630 / 4.002 |
| preflight + commit s | +2.6% (3, 2) | +5.6% (3, 0) | **+4.1%** | 0.314 / 0.327 |

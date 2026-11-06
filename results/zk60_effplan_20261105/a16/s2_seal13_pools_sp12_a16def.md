# A13 one-request clocks: [sp12+a16def] against [spauto+a16def], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s2_pools_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +1.1% (2, 1) | +1.3% (2, 1) | **+1.2%** | 5.946 / 6.017 |
| sealing pass s | +6.8% (2, 0) | +11.0% (2, 0) | **+8.9%** | 1.616 / 1.755 |
| sealing CPU-s | +50.1% (2, 0) | +60.1% (2, 0) | **+55.1%** | 8.925 / 13.800 |
| prove call s | -1.0% (2, 2) | -2.2% (2, 2) | **-1.6%** | 4.330 / 4.261 |
| forks phase (of the request) s | -0.8% (2, 2) | -1.4% (2, 2) | **-1.1%** | 3.937 / 3.894 |
| preflight + commit s | -3.7% (2, 2) | -11.6% (2, 2) | **-7.6%** | 0.318 / 0.293 |

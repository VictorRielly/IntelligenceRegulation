# A13 one-request clocks: [sp16+a16def] against [spauto+a16def], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s3_pools_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +6.1% (2, 0) | +7.8% (2, 0) | **+7.0%** | 5.609 / 6.000 |
| sealing pass s | +25.0% (2, 0) | +25.5% (2, 0) | **+25.2%** | 1.517 / 1.900 |
| sealing CPU-s | +135.4% (2, 0) | +137.8% (2, 0) | **+136.6%** | 8.200 / 19.400 |
| prove call s | -0.8% (2, 1) | +1.2% (2, 1) | **+0.2%** | 4.091 / 4.100 |
| forks phase (of the request) s | -1.2% (2, 1) | +1.7% (2, 0) | **+0.3%** | 3.712 / 3.722 |
| preflight + commit s | +3.7% (2, 1) | -5.4% (2, 1) | **-0.8%** | 0.303 / 0.300 |

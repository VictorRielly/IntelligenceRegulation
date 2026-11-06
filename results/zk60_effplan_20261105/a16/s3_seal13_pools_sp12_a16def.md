# A13 one-request clocks: [sp12+a16def] against [spauto+a16def], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s3_pools_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +1.6% (2, 0) | +2.7% (2, 0) | **+2.1%** | 5.609 / 5.729 |
| sealing pass s | +12.6% (2, 0) | +9.6% (2, 0) | **+11.1%** | 1.517 / 1.685 |
| sealing CPU-s | +62.3% (2, 0) | +62.2% (2, 0) | **+62.3%** | 8.200 / 13.300 |
| prove call s | -2.4% (2, 2) | +0.1% (2, 1) | **-1.1%** | 4.091 / 4.044 |
| forks phase (of the request) s | -2.9% (2, 2) | +0.7% (2, 0) | **-1.1%** | 3.712 / 3.671 |
| preflight + commit s | +2.5% (2, 0) | -6.2% (2, 2) | **-1.8%** | 0.303 / 0.297 |

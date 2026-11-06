# A13 one-request clocks: [a18def+ahead16+stsl] against [a18old+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s7b_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -1.3% (3, 2) | -2.4% (3, 2) | **-1.9%** | 5.679 / 5.571 |
| sealing pass s | +6.8% (3, 0) | +6.8% (3, 1) | **+6.8%** | 1.657 / 1.767 |
| sealing CPU-s | +62.9% (3, 0) | +64.7% (3, 0) | **+63.8%** | 8.967 / 14.667 |
| prove call s | -4.8% (3, 3) | -6.2% (3, 3) | **-5.5%** | 4.023 / 3.800 |
| forks phase (of the request) s | -6.4% (3, 3) | -7.5% (3, 3) | **-6.9%** | 3.645 / 3.391 |
| preflight + commit s | +9.3% (3, 1) | +8.6% (3, 0) | **+9.0%** | 0.293 / 0.318 |

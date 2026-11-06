# A13 one-request clocks: [a18new+ahead16+stsl] against [a18new+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s3c_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -2.3% (3, 3) | -1.1% (3, 2) | **-1.7%** | 5.617 / 5.521 |
| sealing pass s | +8.2% (3, 0) | +12.8% (3, 0) | **+10.5%** | 1.566 / 1.730 |
| sealing CPU-s | +66.7% (3, 0) | +72.3% (3, 0) | **+69.5%** | 8.483 / 14.367 |
| prove call s | -6.4% (3, 3) | -6.4% (3, 3) | **-6.4%** | 4.051 / 3.791 |
| forks phase (of the request) s | -7.9% (3, 3) | -7.7% (3, 3) | **-7.8%** | 3.679 / 3.393 |
| preflight + commit s | +11.9% (3, 0) | +8.8% (3, 0) | **+10.4%** | 0.287 / 0.317 |

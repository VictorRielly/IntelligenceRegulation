# A13 one-request clocks: [a18new+ahead32+stsl] against [a18new+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s3c_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -0.2% (3, 2) | +1.5% (3, 0) | **+0.6%** | 5.617 / 5.652 |
| sealing pass s | +22.7% (3, 0) | +27.1% (3, 0) | **+24.9%** | 1.566 / 1.954 |
| sealing CPU-s | +133.2% (3, 0) | +142.5% (3, 0) | **+137.8%** | 8.483 / 20.150 |
| prove call s | -9.2% (3, 3) | -8.2% (3, 3) | **-8.7%** | 4.051 / 3.698 |
| forks phase (of the request) s | -11.3% (3, 3) | -10.7% (3, 3) | **-11.0%** | 3.679 / 3.276 |
| preflight + commit s | +16.5% (3, 0) | +18.7% (3, 0) | **+17.6%** | 0.287 / 0.337 |

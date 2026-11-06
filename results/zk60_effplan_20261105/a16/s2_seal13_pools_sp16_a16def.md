# A13 one-request clocks: [sp16+a16def] against [spauto+a16def], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s2_pools_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +5.2% (2, 0) | +3.5% (2, 0) | **+4.4%** | 5.946 / 6.205 |
| sealing pass s | +15.5% (2, 0) | +23.8% (2, 0) | **+19.7%** | 1.616 / 1.928 |
| sealing CPU-s | +117.8% (2, 0) | +134.7% (2, 0) | **+126.2%** | 8.925 / 20.125 |
| prove call s | +1.3% (2, 0) | -3.7% (2, 2) | **-1.2%** | 4.330 / 4.278 |
| forks phase (of the request) s | +1.2% (2, 0) | -2.9% (2, 2) | **-0.8%** | 3.937 / 3.903 |
| preflight + commit s | +2.8% (2, 0) | -12.2% (2, 2) | **-4.7%** | 0.318 / 0.302 |

# A13 one-request clocks: [a18def+ahead16+stsl] against [a18def+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s6a_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -2.9% (3, 3) | -1.6% (3, 2) | **-2.3%** | 5.569 / 5.442 |
| sealing pass s | +6.7% (3, 0) | +11.3% (3, 0) | **+9.0%** | 1.555 / 1.693 |
| sealing CPU-s | +67.5% (3, 0) | +69.5% (3, 0) | **+68.5%** | 8.350 / 14.067 |
| prove call s | -6.6% (3, 3) | -6.6% (3, 3) | **-6.6%** | 4.014 / 3.749 |
| forks phase (of the request) s | -7.8% (3, 3) | -7.6% (3, 3) | **-7.7%** | 3.631 / 3.352 |
| preflight + commit s | +7.5% (3, 0) | +4.5% (3, 0) | **+6.0%** | 0.294 / 0.311 |

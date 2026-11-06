# A13 one-request clocks: [a18def+ahead16+qos1+stsl] against [a18def+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s6b_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -2.0% (3, 3) | -1.0% (3, 2) | **-1.5%** | 5.615 / 5.531 |
| sealing pass s | +10.0% (3, 0) | +16.2% (3, 0) | **+13.1%** | 1.559 / 1.762 |
| sealing CPU-s | +72.1% (3, 0) | +77.2% (3, 0) | **+74.6%** | 8.417 / 14.700 |
| prove call s | -6.6% (3, 3) | -7.6% (3, 3) | **-7.1%** | 4.056 / 3.769 |
| forks phase (of the request) s | -8.1% (3, 3) | -8.1% (3, 3) | **-8.1%** | 3.659 / 3.363 |
| preflight + commit s | +11.3% (3, 0) | +9.1% (3, 0) | **+10.2%** | 0.291 / 0.321 |

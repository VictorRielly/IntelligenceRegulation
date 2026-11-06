# A13 one-request clocks: [a18def+ahead8+stsl] against [a18def+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s6b_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -1.9% (3, 2) | -2.4% (3, 3) | **-2.2%** | 5.615 / 5.494 |
| sealing pass s | +4.7% (3, 1) | +7.9% (3, 0) | **+6.3%** | 1.559 / 1.657 |
| sealing CPU-s | +33.5% (3, 0) | +35.1% (3, 0) | **+34.3%** | 8.417 / 11.300 |
| prove call s | -4.4% (3, 3) | -6.4% (3, 3) | **-5.4%** | 4.056 / 3.837 |
| forks phase (of the request) s | -4.9% (3, 3) | -6.2% (3, 3) | **-5.6%** | 3.659 / 3.455 |
| preflight + commit s | +2.4% (3, 2) | +2.2% (3, 0) | **+2.3%** | 0.291 / 0.298 |

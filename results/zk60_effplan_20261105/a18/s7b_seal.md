# A15 sealing-pass clocks: [a18def+ahead16+stsl] against [a18old+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s7b_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +6.8% (3, 0) | +6.8% (3, 1) | **+6.8%** | 1.657 / 1.767 |
| one request: sealing user CPU s | +78.0% (3, 0) | +76.3% (3, 0) | **+77.2%** | 5.382 / 9.533 |
| one request: sealing sys CPU s | +39.8% (3, 0) | +47.8% (3, 0) | **+43.8%** | 3.610 / 5.142 |
| one request: sealing involuntary csw | +36.9% (3, 0) | +46.2% (3, 0) | **+41.6%** | 30020.333 / 42285.000 |
| stream: request 0's sealing pass s (alone) | +5.1% (3, 1) | +10.2% (3, 0) | **+7.6%** | 1.675 / 1.796 |
| stream: requests 1.. sealing pass s (beside the forks) | +3.8% (3, 0) | +7.2% (3, 0) | **+5.5%** | 2.747 / 2.894 |

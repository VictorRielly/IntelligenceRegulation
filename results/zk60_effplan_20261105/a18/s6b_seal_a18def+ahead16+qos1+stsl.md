# A15 sealing-pass clocks: [a18def+ahead16+qos1+stsl] against [a18def+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s6b_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +10.0% (3, 0) | +16.2% (3, 0) | **+13.1%** | 1.559 / 1.762 |
| one request: sealing user CPU s | +75.5% (3, 0) | +78.8% (3, 0) | **+77.2%** | 5.438 / 9.633 |
| one request: sealing sys CPU s | +64.2% (3, 0) | +75.7% (3, 0) | **+69.9%** | 2.977 / 5.053 |
| one request: sealing involuntary csw | +37.4% (3, 0) | +55.8% (3, 0) | **+46.6%** | 28323.167 / 41387.000 |
| stream: request 0's sealing pass s (alone) | +11.4% (3, 0) | +12.9% (3, 0) | **+12.2%** | 1.582 / 1.773 |
| stream: requests 1.. sealing pass s (beside the forks) | +5.2% (3, 0) | +7.8% (3, 0) | **+6.5%** | 2.697 / 2.872 |

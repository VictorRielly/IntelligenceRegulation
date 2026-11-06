# A15 sealing-pass clocks: [a18def+ahead16+stsl] against [a18def+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s6a_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +6.7% (3, 0) | +11.3% (3, 0) | **+9.0%** | 1.555 / 1.693 |
| one request: sealing user CPU s | +74.6% (3, 0) | +77.3% (3, 0) | **+76.0%** | 5.432 / 9.557 |
| one request: sealing sys CPU s | +55.5% (3, 0) | +55.1% (3, 0) | **+55.3%** | 2.907 / 4.502 |
| one request: sealing involuntary csw | +50.7% (3, 0) | +51.6% (3, 0) | **+51.1%** | 28773.000 / 43453.167 |
| stream: request 0's sealing pass s (alone) | +10.1% (3, 0) | +8.8% (3, 0) | **+9.4%** | 1.554 / 1.700 |
| stream: requests 1.. sealing pass s (beside the forks) | +4.2% (3, 0) | +1.4% (3, 1) | **+2.8%** | 2.730 / 2.805 |

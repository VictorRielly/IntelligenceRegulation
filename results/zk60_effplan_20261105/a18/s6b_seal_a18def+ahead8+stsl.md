# A15 sealing-pass clocks: [a18def+ahead8+stsl] against [a18def+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s6b_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +4.7% (3, 1) | +7.9% (3, 0) | **+6.3%** | 1.559 / 1.657 |
| one request: sealing user CPU s | +35.8% (3, 0) | +38.1% (3, 0) | **+36.9%** | 5.438 / 7.445 |
| one request: sealing sys CPU s | +28.9% (3, 0) | +30.5% (3, 0) | **+29.7%** | 2.977 / 3.852 |
| one request: sealing involuntary csw | +19.7% (3, 0) | +23.5% (3, 0) | **+21.6%** | 28323.167 / 34388.500 |
| stream: request 0's sealing pass s (alone) | +4.7% (3, 0) | +4.2% (3, 1) | **+4.4%** | 1.582 / 1.651 |
| stream: requests 1.. sealing pass s (beside the forks) | +2.5% (3, 0) | +2.0% (3, 0) | **+2.3%** | 2.697 / 2.758 |

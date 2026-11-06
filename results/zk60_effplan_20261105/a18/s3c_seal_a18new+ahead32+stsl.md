# A15 sealing-pass clocks: [a18new+ahead32+stsl] against [a18new+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s3c_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +22.7% (3, 0) | +27.1% (3, 0) | **+24.9%** | 1.566 / 1.954 |
| one request: sealing user CPU s | +152.4% (3, 0) | +153.7% (3, 0) | **+153.0%** | 5.355 / 13.548 |
| one request: sealing sys CPU s | +105.1% (3, 0) | +121.8% (3, 0) | **+113.5%** | 3.127 / 6.602 |
| one request: sealing involuntary csw | +89.5% (3, 0) | +103.3% (3, 0) | **+96.4%** | 29257.833 / 57278.833 |
| stream: request 0's sealing pass s (alone) | +37.2% (3, 0) | +31.7% (3, 0) | **+34.4%** | 1.588 / 2.132 |
| stream: requests 1.. sealing pass s (beside the forks) | +12.7% (3, 0) | +16.8% (3, 0) | **+14.7%** | 2.709 / 3.106 |

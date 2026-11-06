# A15 sealing-pass clocks: [a18new+ahead16+stsl] against [a18new+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s3c_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +8.2% (3, 0) | +12.8% (3, 0) | **+10.5%** | 1.566 / 1.730 |
| one request: sealing user CPU s | +77.9% (3, 0) | +76.9% (3, 0) | **+77.4%** | 5.355 / 9.498 |
| one request: sealing sys CPU s | +50.4% (3, 0) | +64.7% (3, 0) | **+57.6%** | 3.127 / 4.880 |
| one request: sealing involuntary csw | +38.6% (3, 0) | +50.3% (3, 0) | **+44.4%** | 29257.833 / 42146.500 |
| stream: request 0's sealing pass s (alone) | +10.5% (3, 0) | +11.0% (3, 0) | **+10.8%** | 1.588 / 1.757 |
| stream: requests 1.. sealing pass s (beside the forks) | +2.0% (3, 0) | +7.6% (3, 0) | **+4.8%** | 2.709 / 2.836 |

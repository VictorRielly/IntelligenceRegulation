# A15 sealing-pass clocks: [sp16+a16def] against [spauto+a16def], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s3_pools_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +25.0% (2, 0) | +25.5% (2, 0) | **+25.2%** | 1.517 / 1.900 |
| one request: sealing user CPU s | +45.2% (2, 0) | +44.2% (2, 0) | **+44.7%** | 5.373 / 7.772 |
| one request: sealing sys CPU s | +301.3% (2, 0) | +315.9% (2, 0) | **+308.6%** | 2.842 / 11.602 |
| one request: sealing involuntary csw | +335.1% (2, 0) | +382.6% (2, 0) | **+358.9%** | 28109.500 / 128569.750 |
| stream: request 0's sealing pass s (alone) | +18.6% (2, 0) | +23.4% (2, 0) | **+21.0%** | 1.545 / 1.867 |
| stream: requests 1.. sealing pass s (beside the forks) | +14.9% (2, 0) | +15.5% (2, 0) | **+15.2%** | 2.619 / 3.018 |

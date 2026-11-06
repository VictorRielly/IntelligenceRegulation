# A15 sealing-pass clocks: [sp12+a16def] against [spauto+a16def], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s3_pools_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +12.6% (2, 0) | +9.6% (2, 0) | **+11.1%** | 1.517 / 1.685 |
| one request: sealing user CPU s | +19.3% (2, 0) | +17.0% (2, 0) | **+18.2%** | 5.373 / 6.348 |
| one request: sealing sys CPU s | +141.0% (2, 0) | +148.3% (2, 0) | **+144.7%** | 2.842 / 6.935 |
| one request: sealing involuntary csw | +169.5% (2, 0) | +166.2% (2, 0) | **+167.8%** | 28109.500 / 75069.250 |
| stream: request 0's sealing pass s (alone) | +7.3% (2, 1) | +12.9% (2, 0) | **+10.1%** | 1.545 / 1.697 |
| stream: requests 1.. sealing pass s (beside the forks) | +7.6% (2, 0) | +8.8% (2, 0) | **+8.2%** | 2.619 / 2.833 |

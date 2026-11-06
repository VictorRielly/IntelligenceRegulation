# A15 sealing-pass clocks: [spauto+a16def+prod] against [spauto+a16old+prod], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s3_prod_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -49.3% (2, 2) | -52.6% (2, 2) | **-50.9%** | 3.518 / 1.723 |
| one request: sealing user CPU s | -35.8% (2, 2) | -36.1% (2, 2) | **-35.9%** | 8.352 / 5.353 |
| one request: sealing sys CPU s | +54.9% (2, 0) | +38.7% (2, 0) | **+46.8%** | 2.980 / 4.357 |
| one request: sealing involuntary csw | -14.5% (2, 2) | -22.6% (2, 2) | **-18.5%** | 48622.000 / 39571.000 |
| stream: request 0's sealing pass s (alone) | -49.0% (2, 2) | -50.9% (2, 2) | **-49.9%** | 3.432 / 1.717 |
| stream: requests 1.. sealing pass s (beside the forks) | -40.0% (2, 2) | -41.3% (2, 2) | **-40.7%** | 4.604 / 2.731 |

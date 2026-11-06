# A15 sealing-pass clocks: [sp16+a16def] against [spauto+a16def], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s2_pools_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +15.5% (2, 0) | +23.8% (2, 0) | **+19.7%** | 1.616 / 1.928 |
| one request: sealing user CPU s | +39.8% (2, 0) | +41.7% (2, 0) | **+40.7%** | 5.438 / 7.650 |
| one request: sealing sys CPU s | +234.3% (2, 0) | +291.5% (2, 0) | **+262.9%** | 3.490 / 12.490 |
| one request: sealing involuntary csw | +236.5% (2, 0) | +296.0% (2, 0) | **+266.3%** | 35575.250 / 128466.250 |
| stream: request 0's sealing pass s (alone) | +17.2% (2, 0) | +18.5% (2, 0) | **+17.8%** | 1.639 / 1.931 |
| stream: requests 1.. sealing pass s (beside the forks) | +13.9% (2, 0) | +18.6% (2, 0) | **+16.2%** | 2.871 / 3.333 |

# A15 sealing-pass clocks: [sp12+a16def] against [spauto+a16def], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s2_pools_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +6.8% (2, 0) | +11.0% (2, 0) | **+8.9%** | 1.616 / 1.755 |
| one request: sealing user CPU s | +17.2% (2, 0) | +18.0% (2, 0) | **+17.6%** | 5.438 / 6.393 |
| one request: sealing sys CPU s | +100.2% (2, 0) | +129.4% (2, 0) | **+114.8%** | 3.490 / 7.405 |
| one request: sealing involuntary csw | +132.1% (2, 0) | +139.2% (2, 0) | **+135.7%** | 35575.250 / 83106.250 |
| stream: request 0's sealing pass s (alone) | +6.6% (2, 0) | +5.7% (2, 0) | **+6.2%** | 1.639 / 1.740 |
| stream: requests 1.. sealing pass s (beside the forks) | +3.4% (2, 1) | +10.6% (2, 0) | **+7.0%** | 2.871 / 3.068 |

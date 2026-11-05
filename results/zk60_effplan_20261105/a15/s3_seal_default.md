# A15 sealing-pass clocks: [spauto] against [sp0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s3_default_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -23.8% (3, 3) | -23.4% (3, 3) | **-23.6%** | 4.368 / 3.336 |
| one request: sealing user CPU s | -51.6% (3, 3) | -51.6% (3, 3) | **-51.6%** | 15.698 / 7.600 |
| one request: sealing sys CPU s | -90.0% (3, 3) | -90.0% (3, 3) | **-90.0%** | 28.710 / 2.878 |
| one request: sealing involuntary csw | -93.8% (3, 3) | -93.8% (3, 3) | **-93.8%** | 656069.167 / 40556.500 |
| stream: request 0's sealing pass s (alone) | -23.9% (3, 3) | -24.4% (3, 3) | **-24.1%** | 4.375 / 3.318 |
| stream: requests 1.. sealing pass s (beside the forks) | -16.1% (3, 3) | -15.5% (3, 3) | **-15.8%** | 5.382 / 4.530 |

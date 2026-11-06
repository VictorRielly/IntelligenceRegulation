# A15 sealing-pass clocks: [a18new] against [a18old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s3a_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +0.1% (3, 1) | -2.9% (3, 3) | **-1.4%** | 1.500 / 1.480 |
| one request: sealing user CPU s | +1.0% (3, 0) | -1.2% (3, 3) | **-0.1%** | 5.325 / 5.320 |
| one request: sealing sys CPU s | +0.7% (3, 1) | -1.7% (3, 2) | **-0.5%** | 2.758 / 2.745 |
| one request: sealing involuntary csw | +4.7% (3, 1) | -0.7% (3, 1) | **+2.0%** | 27705.833 / 28181.667 |
| stream: request 0's sealing pass s (alone) | +0.6% (3, 2) | +0.8% (3, 1) | **+0.7%** | 1.473 / 1.482 |
| stream: requests 1.. sealing pass s (beside the forks) | +2.6% (3, 1) | +6.2% (3, 0) | **+4.4%** | 2.563 / 2.675 |

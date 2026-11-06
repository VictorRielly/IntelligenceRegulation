# A15 sealing-pass clocks: [a21old+b3par1] against [a21old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s2b_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +2.6% (3, 0) | +2.8% (3, 0) | **+2.7%** | 3.479 / 3.573 |
| one request: sealing user CPU s | +2.0% (3, 0) | +1.4% (3, 0) | **+1.7%** | 34.382 / 34.973 |
| one request: sealing sys CPU s | +4.4% (3, 0) | +1.1% (3, 1) | **+2.8%** | 10.208 / 10.488 |
| one request: sealing involuntary csw | +7.9% (3, 0) | +6.4% (3, 0) | **+7.2%** | 245410.167 / 262807.833 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

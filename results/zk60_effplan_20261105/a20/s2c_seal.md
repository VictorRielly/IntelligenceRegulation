# A15 sealing-pass clocks: [a20old+loads3] against [a20old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2c_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -50.6% (3, 3) | -50.1% (3, 3) | **-50.4%** | 9.151 / 4.540 |
| one request: sealing user CPU s | -0.1% (3, 2) | +0.2% (3, 1) | **+0.1%** | 32.973 / 32.990 |
| one request: sealing sys CPU s | -19.0% (3, 3) | -15.9% (3, 3) | **-17.4%** | 9.990 / 8.237 |
| one request: sealing involuntary csw | -17.1% (3, 3) | -16.0% (3, 3) | **-16.5%** | 196230.500 / 163336.833 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

# A15 sealing-pass clocks: [a21old+sha1] against [a21old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s2a_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -3.3% (3, 3) | -2.6% (3, 2) | **-3.0%** | 3.498 / 3.393 |
| one request: sealing user CPU s | -35.4% (3, 3) | -36.3% (3, 3) | **-35.8%** | 34.255 / 21.975 |
| one request: sealing sys CPU s | +15.7% (3, 0) | +13.8% (3, 0) | **+14.8%** | 10.105 / 11.588 |
| one request: sealing involuntary csw | +15.8% (3, 1) | +16.8% (3, 0) | **+16.3%** | 247519.500 / 286490.500 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

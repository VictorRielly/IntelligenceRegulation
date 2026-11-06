# A15 sealing-pass clocks: [default] against [default+sha0], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s2d_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -23.0% (3, 3) | -20.8% (3, 3) | **-21.9%** | 3.344 / 2.611 |
| one request: sealing user CPU s | -36.7% (3, 3) | -36.3% (3, 3) | **-36.5%** | 34.680 / 22.022 |
| one request: sealing sys CPU s | +13.5% (3, 0) | +18.8% (3, 0) | **+16.2%** | 9.008 / 10.462 |
| one request: sealing involuntary csw | +8.5% (3, 0) | +27.2% (3, 0) | **+17.9%** | 172172.667 / 201781.500 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

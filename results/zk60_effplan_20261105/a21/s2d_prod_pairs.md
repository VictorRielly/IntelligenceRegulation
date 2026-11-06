# A21 production pairs: [default] against [default+sha0], alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s2d_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test | test lower in |
|---|---|---|---|---|---|
| one request from its input s | -12.0% (3, 3) | -9.5% (3, 3) | **-10.7%** | 7.937 / 7.083 | 6 of 6 |
| its sealing pass s | -23.0% (3, 3) | -20.8% (3, 3) | **-21.9%** | 3.344 / 2.611 | 6 of 6 |
| loads beside it (summed) s | -81.0% (3, 3) | -80.8% (3, 3) | **-80.9%** | 8.815 / 1.683 | 6 of 6 |
| witness builds (summed) s | -2.5% (3, 2) | -3.3% (3, 3) | **-2.9%** | 1.890 / 1.834 | 5 of 6 |
| the pass's wait for its loads s | -91.6% (3, 3) | -90.8% (3, 3) | **-91.2%** | 0.799 / 0.070 | 6 of 6 |
| its prove call s | -2.3% (3, 3) | +1.1% (3, 1) | **-0.6%** | 4.211 / 4.185 | 4 of 6 |
| its preflight (CS-6 re-hash) s | -4.6% (3, 2) | -7.5% (3, 3) | **-6.1%** | 0.322 / 0.301 | 5 of 6 |
| its commit phase s | -7.0% (3, 2) | +0.7% (3, 1) | **-3.2%** | 0.211 / 0.204 | 3 of 6 |
| its forks phase s | -1.7% (3, 2) | +1.9% (3, 1) | **+0.1%** | 3.602 / 3.604 | 3 of 6 |
| the receipt write s | -28.2% (3, 3) | -32.1% (3, 3) | **-30.2%** | 0.319 / 0.222 | 6 of 6 |
| directory to receipt written s | -4.1% (3, 3) | -1.3% (3, 2) | **-2.7%** | 4.543 / 4.421 | 5 of 6 |
| peak footprint GiB | +0.0% (3, 1) | -0.3% (3, 3) | **-0.2%** | 41.717 / 41.650 | 4 of 6 |

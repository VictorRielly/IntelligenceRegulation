# A21 production pairs: [default] against [default+b3par0], alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s2e_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test | test lower in |
|---|---|---|---|---|---|
| one request from its input s | -5.9% (3, 3) | -6.7% (3, 3) | **-6.3%** | 7.520 / 7.049 | 6 of 6 |
| its sealing pass s | -12.9% (3, 3) | -14.4% (3, 3) | **-13.6%** | 3.005 / 2.596 | 6 of 6 |
| loads beside it (summed) s | -77.4% (3, 3) | -78.4% (3, 3) | **-77.9%** | 7.714 / 1.703 | 6 of 6 |
| witness builds (summed) s | +7.7% (3, 0) | +5.0% (3, 0) | **+6.3%** | 1.700 / 1.807 | 0 of 6 |
| the pass's wait for its loads s | -86.6% (3, 3) | -88.1% (3, 3) | **-87.3%** | 0.605 / 0.077 | 6 of 6 |
| its prove call s | -1.4% (3, 2) | -1.6% (3, 3) | **-1.5%** | 4.238 / 4.173 | 5 of 6 |
| its preflight (CS-6 re-hash) s | -15.3% (3, 3) | -22.7% (3, 3) | **-19.0%** | 0.366 / 0.297 | 6 of 6 |
| its commit phase s | -3.4% (3, 2) | -0.1% (3, 1) | **-1.8%** | 0.208 / 0.204 | 3 of 6 |
| its forks phase s | +0.1% (3, 2) | +0.6% (3, 1) | **+0.3%** | 3.585 / 3.595 | 3 of 6 |
| the receipt write s | +3.5% (3, 0) | -1.3% (3, 2) | **+1.1%** | 0.217 / 0.219 | 2 of 6 |
| directory to receipt written s | -1.2% (3, 2) | -1.6% (3, 3) | **-1.4%** | 4.468 / 4.405 | 5 of 6 |
| peak footprint GiB | -2.6% (3, 3) | -3.8% (3, 3) | **-3.2%** | 43.367 / 41.967 | 6 of 6 |

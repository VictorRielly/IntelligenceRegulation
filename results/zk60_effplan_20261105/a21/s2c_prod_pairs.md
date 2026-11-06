# A21 production pairs: [default] against [a21old], alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s2c_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test | test lower in |
|---|---|---|---|---|---|
| one request from its input s | -10.3% (3, 3) | -10.7% (3, 3) | **-10.5%** | 7.873 / 7.045 | 6 of 6 |
| its sealing pass s | -20.2% (3, 3) | -19.7% (3, 3) | **-20.0%** | 3.245 / 2.597 | 6 of 6 |
| loads beside it (summed) s | -80.5% (3, 3) | -80.7% (3, 3) | **-80.6%** | 8.609 / 1.669 | 6 of 6 |
| witness builds (summed) s | +2.0% (3, 0) | +1.3% (3, 1) | **+1.7%** | 1.790 / 1.819 | 1 of 6 |
| the pass's wait for its loads s | -91.2% (3, 3) | -91.1% (3, 3) | **-91.2%** | 0.795 / 0.070 | 6 of 6 |
| its prove call s | -1.1% (3, 2) | -2.1% (3, 2) | **-1.6%** | 4.241 / 4.171 | 4 of 6 |
| its preflight (CS-6 re-hash) s | -15.4% (3, 3) | -16.9% (3, 3) | **-16.1%** | 0.382 / 0.319 | 6 of 6 |
| its commit phase s | -2.0% (3, 2) | +0.0% (3, 2) | **-1.0%** | 0.212 / 0.209 | 4 of 6 |
| its forks phase s | +0.4% (3, 1) | -0.6% (3, 2) | **-0.1%** | 3.573 / 3.568 | 3 of 6 |
| the receipt write s | -31.9% (3, 3) | -34.4% (3, 3) | **-33.1%** | 0.326 / 0.217 | 6 of 6 |
| directory to receipt written s | -3.4% (3, 3) | -4.4% (3, 3) | **-3.9%** | 4.580 / 4.400 | 6 of 6 |
| peak footprint GiB | -2.9% (3, 3) | -3.1% (3, 3) | **-3.0%** | 43.300 / 42.000 | 6 of 6 |

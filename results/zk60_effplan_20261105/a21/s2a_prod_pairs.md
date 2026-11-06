# A21 production pairs: [a21old+sha1] against [a21old], alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119/results/zk60_effplan_20261105/a21/raw/s2a_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test | test lower in |
|---|---|---|---|---|---|
| one request from its input s | -1.9% (3, 3) | -2.5% (3, 3) | **-2.2%** | 8.246 / 8.063 | 6 of 6 |
| its sealing pass s | -3.3% (3, 3) | -2.6% (3, 2) | **-3.0%** | 3.498 / 3.393 | 5 of 6 |
| loads beside it (summed) s | -7.9% (3, 3) | -9.2% (3, 3) | **-8.6%** | 8.815 / 8.053 | 6 of 6 |
| witness builds (summed) s | -2.7% (3, 2) | -1.5% (3, 2) | **-2.1%** | 1.849 / 1.811 | 4 of 6 |
| the pass's wait for its loads s | -31.2% (3, 3) | -28.4% (3, 3) | **-29.8%** | 0.642 / 0.453 | 6 of 6 |
| its prove call s | +1.7% (3, 1) | -0.3% (3, 2) | **+0.7%** | 4.357 / 4.386 | 3 of 6 |
| its preflight (CS-6 re-hash) s | +2.8% (3, 1) | -5.2% (3, 2) | **-1.2%** | 0.414 / 0.406 | 3 of 6 |
| its commit phase s | +2.8% (3, 2) | -1.5% (3, 2) | **+0.6%** | 0.258 / 0.259 | 4 of 6 |
| its forks phase s | +1.7% (3, 0) | +0.2% (3, 2) | **+0.9%** | 3.604 / 3.638 | 2 of 6 |
| the receipt write s | -34.1% (3, 3) | -33.4% (3, 3) | **-33.7%** | 0.325 / 0.215 | 6 of 6 |
| directory to receipt written s | -0.8% (3, 2) | -2.6% (3, 3) | **-1.7%** | 4.695 / 4.615 | 5 of 6 |
| peak footprint GiB | +0.1% (3, 2) | -0.1% (3, 1) | **+0.0%** | 43.117 / 43.117 | 3 of 6 |

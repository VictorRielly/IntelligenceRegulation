# A20 production pairs: [recpar1+cast0+loads4+write16] against [recpar1+cast0+loads3+write16], alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2f_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request from its input s | -1.2% (3, 2) | -2.8% (3, 3) | **-2.0%** | 8.095 / 7.931 |
| its sealing pass s | -3.2% (3, 3) | -4.4% (3, 3) | **-3.8%** | 3.389 / 3.260 |
| loads beside it (summed) s | +17.0% (3, 0) | +16.9% (3, 0) | **+16.9%** | 7.355 / 8.601 |
| witness builds (summed) s | +0.3% (3, 2) | -0.4% (3, 2) | **-0.1%** | 1.765 / 1.763 |
| the pass's wait for its loads s | -19.0% (3, 3) | -11.5% (3, 3) | **-15.2%** | 0.932 / 0.789 |
| its prove call s | +0.3% (3, 2) | -1.8% (3, 3) | **-0.7%** | 4.316 / 4.283 |
| its forks phase s | +0.2% (3, 2) | -1.1% (3, 3) | **-0.5%** | 3.648 / 3.631 |
| the receipt write s | -0.5% (3, 1) | -1.0% (3, 2) | **-0.8%** | 0.330 / 0.325 |
| directory to receipt written s | +0.2% (3, 2) | -1.8% (3, 3) | **-0.8%** | 4.660 / 4.622 |
| peak footprint GiB | +0.8% (3, 0) | -0.8% (3, 3) | **+0.0%** | 43.583 / 43.583 |

# A20 production pairs: [recpar1+cast0+loads3+write16] against [recpar1+cast0+loads2+write16], alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2g_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request from its input s | -6.3% (3, 3) | -5.9% (3, 3) | **-6.1%** | 8.586 / 8.063 |
| its sealing pass s | -14.2% (3, 3) | -14.4% (3, 3) | **-14.3%** | 3.907 / 3.348 |
| loads beside it (summed) s | +13.5% (3, 0) | +14.2% (3, 0) | **+13.9%** | 6.422 / 7.313 |
| witness builds (summed) s | +2.1% (3, 1) | -0.7% (3, 2) | **+0.7%** | 1.730 / 1.741 |
| the pass's wait for its loads s | -37.6% (3, 3) | -34.8% (3, 3) | **-36.2%** | 1.520 / 0.970 |
| its prove call s | +0.6% (3, 1) | -0.2% (3, 1) | **+0.2%** | 4.295 / 4.301 |
| its forks phase s | +0.3% (3, 1) | -0.0% (3, 1) | **+0.2%** | 3.646 / 3.651 |
| the receipt write s | -1.1% (3, 2) | +17.7% (3, 1) | **+8.3%** | 0.322 / 0.349 |
| directory to receipt written s | +0.4% (3, 1) | +1.1% (3, 0) | **+0.7%** | 4.631 / 4.665 |
| peak footprint GiB | -0.1% (3, 1) | -0.5% (3, 2) | **-0.3%** | 43.367 / 43.233 |

# A20 production pairs: [recpar1+cast0+loads3+write16] against [a20old], alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2e_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request from its input s | -49.3% (3, 3) | -48.5% (3, 3) | **-48.9%** | 15.503 / 7.926 |
| its sealing pass s | -64.4% (3, 3) | -63.7% (3, 3) | **-64.0%** | 9.219 / 3.317 |
| loads beside it (summed) s | -14.5% (3, 3) | -15.1% (3, 3) | **-14.8%** | 8.453 / 7.199 |
| witness builds (summed) s | -79.3% (3, 3) | -78.8% (3, 3) | **-79.0%** | 8.185 / 1.716 |
| the pass's wait for its loads s | — | — | — | 0.000 / 0.957 |
| its prove call s | -0.7% (3, 2) | +0.3% (3, 1) | **-0.2%** | 4.240 / 4.230 |
| its forks phase s | -0.7% (3, 2) | +0.4% (3, 1) | **-0.2%** | 3.625 / 3.618 |
| the receipt write s | -84.0% (3, 3) | -83.5% (3, 3) | **-83.8%** | 1.964 / 0.319 |
| directory to receipt written s | -27.1% (3, 3) | -26.2% (3, 3) | **-26.7%** | 6.224 / 4.562 |
| peak footprint GiB | -0.4% (3, 3) | +0.2% (3, 1) | **-0.1%** | 43.083 / 43.050 |

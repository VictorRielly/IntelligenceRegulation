# A11 pairs: [a18def+ahead8+stsl] against [a18def+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s6b_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | -3.2% (3, 2) | -0.2% (3, 1) | **-1.7%** | 4.033 / 3.961 |
| forks phase s | -2.6% (3, 2) | -0.1% (3, 1) | **-1.4%** | 3.642 / 3.591 |
| sealed wall s | -1.9% (3, 2) | -2.4% (3, 3) | **-2.2%** | 5.615 / 5.494 |
| stream steady tok/s | +3.1% (3, 3) | +1.8% (3, 3) | **+2.5%** | 32.533 / 33.330 |
| stream amortized tok/s | +1.2% (3, 3) | +0.2% (3, 2) | **+0.7%** | 28.723 / 28.932 |
| user CPU s | -2.2% (3, 3) | +0.6% (3, 0) | **-0.8%** | 40.183 / 39.850 |
| sys CPU s | +3.9% (3, 0) | +13.7% (3, 1) | **+8.8%** | 5.050 / 5.467 |
| minor faults | +2.8% (3, 1) | +7.1% (3, 1) | **+5.0%** | 657,365 / 689,011 |

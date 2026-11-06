# A11 pairs: [recpar1+cast0+loads3+write16] against [recpar1+cast0+loads2+write16], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2g_prod_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | +0.6% (3, 1) | -0.2% (3, 1) | **+0.2%** | 4.295 / 4.301 |
| forks phase s | +0.3% (3, 1) | -0.0% (3, 1) | **+0.2%** | 3.646 / 3.651 |
| sealed wall s | -6.3% (3, 3) | -5.9% (3, 3) | **-6.1%** | 8.586 / 8.063 |
| user CPU s | +0.2% (3, 1) | +0.1% (3, 2) | **+0.1%** | 82.110 / 82.213 |
| sys CPU s | +2.1% (3, 0) | -5.3% (3, 2) | **-1.6%** | 15.937 / 15.667 |
| minor faults | -1.0% (3, 1) | -0.3% (3, 2) | **-0.7%** | 1,799,043 / 1,786,013 |

# A11 pairs: [recpar1+cast0+loads4+write16] against [recpar1+cast0+loads3+write16], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9/results/zk60_effplan_20261105/a20/raw/s2f_prod_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | +0.3% (3, 2) | -1.8% (3, 3) | **-0.7%** | 4.316 / 4.283 |
| forks phase s | +0.2% (3, 2) | -1.1% (3, 3) | **-0.5%** | 3.648 / 3.631 |
| sealed wall s | -1.2% (3, 2) | -2.8% (3, 3) | **-2.0%** | 8.095 / 7.931 |
| user CPU s | +0.2% (3, 1) | -0.6% (3, 3) | **-0.2%** | 82.253 / 82.100 |
| sys CPU s | -1.0% (3, 2) | -9.2% (3, 3) | **-5.1%** | 16.995 / 16.103 |
| minor faults | +1.1% (3, 0) | +1.8% (3, 1) | **+1.4%** | 1,780,074 / 1,804,884 |

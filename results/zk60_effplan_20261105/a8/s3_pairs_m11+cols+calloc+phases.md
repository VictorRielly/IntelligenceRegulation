# A11 pairs: [m11+cols+calloc+phases] against [m11+cols+vecfill+phases], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6902a0faf57242d4/results/zk60_effplan_20261105/a8/s3_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | +9.6% (3, 0) | +1.5% (3, 1) | **+5.6%** | 4.601 / 4.849 |
| forks phase s | +10.5% (3, 0) | +1.4% (3, 1) | **+6.0%** | 4.230 / 4.476 |
| user CPU s | +2.6% (3, 0) | -0.1% (3, 1) | **+1.2%** | 55.567 / 56.250 |
| sys CPU s | +23.8% (3, 0) | +25.8% (3, 0) | **+24.8%** | 7.100 / 8.850 |
| minor faults | +1.0% (3, 1) | +4.6% (3, 1) | **+2.8%** | 1,205,350 / 1,234,783 |

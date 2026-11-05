# A11 pairs: [small+nocols+calloc] against [m11+cols+vecfill], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6902a0faf57242d4/results/zk60_effplan_20261105/a8/s2_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | +0.6% (3, 2) | -3.4% (3, 3) | **-1.4%** | 4.651 / 4.582 |
| forks phase s | +0.7% (3, 2) | -3.3% (3, 3) | **-1.3%** | 4.282 / 4.224 |
| sealed wall s | +2.5% (3, 0) | -0.3% (3, 2) | **+1.1%** | 8.809 / 8.903 |
| stream steady tok/s | -4.3% (3, 0) | -1.7% (3, 1) | **-3.0%** | 23.202 / 22.497 |
| stream amortized tok/s | -2.2% (3, 0) | +0.0% (3, 2) | **-1.1%** | 19.770 / 19.553 |
| user CPU s | -8.1% (3, 3) | -7.9% (3, 3) | **-8.0%** | 55.517 / 51.083 |
| sys CPU s | +23.8% (3, 0) | +6.1% (3, 1) | **+15.0%** | 7.467 / 8.567 |
| minor faults | +7.3% (3, 0) | -1.1% (3, 2) | **+3.1%** | 1,175,063 / 1,207,340 |

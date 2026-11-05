# A11 pairs: [ahead32+qos1] against [noahead], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-afed131c59aa694b5/results/zk60_effplan_20261105/a13/s4_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | +2.1% (1, 0) | +4.4% (1, 0) | **+3.3%** | 4.135 / 4.269 |
| forks phase s | +2.5% (1, 0) | +5.1% (1, 0) | **+3.8%** | 3.745 / 3.885 |
| sealed wall s | -3.5% (1, 1) | -3.5% (1, 1) | **-3.5%** | 8.563 / 8.264 |
| stream steady tok/s | -4.9% (1, 0) | -2.1% (1, 0) | **-3.5%** | 23.495 / 22.675 |
| stream amortized tok/s | -4.1% (1, 0) | -1.2% (1, 0) | **-2.6%** | 20.260 / 19.725 |
| user CPU s | +2.1% (1, 0) | +0.9% (1, 0) | **+1.5%** | 42.250 / 42.900 |
| sys CPU s | +10.0% (1, 0) | +9.6% (1, 0) | **+9.8%** | 7.650 / 8.400 |
| minor faults | -4.4% (1, 1) | -2.5% (1, 1) | **-3.4%** | 1,175,272 / 1,134,847 |

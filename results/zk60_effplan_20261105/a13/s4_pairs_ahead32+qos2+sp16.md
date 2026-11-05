# A11 pairs: [ahead32+qos2+sp16] against [noahead], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-afed131c59aa694b5/results/zk60_effplan_20261105/a13/s4_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | -0.6% (1, 1) | +1.5% (1, 0) | **+0.5%** | 4.135 / 4.152 |
| forks phase s | -0.3% (1, 1) | +2.1% (1, 0) | **+0.9%** | 3.745 / 3.778 |
| sealed wall s | -7.3% (1, 1) | -11.6% (1, 1) | **-9.5%** | 8.563 / 7.751 |
| stream steady tok/s | -10.8% (1, 0) | -11.8% (1, 0) | **-11.3%** | 23.495 / 20.835 |
| stream amortized tok/s | -13.7% (1, 0) | -11.4% (1, 0) | **-12.6%** | 20.260 / 17.715 |
| user CPU s | +1.9% (1, 0) | +0.5% (1, 0) | **+1.2%** | 42.250 / 42.750 |
| sys CPU s | +6.2% (1, 0) | +5.5% (1, 0) | **+5.9%** | 7.650 / 8.100 |
| minor faults | -7.5% (1, 1) | -3.8% (1, 1) | **-5.6%** | 1,175,272 / 1,108,390 |

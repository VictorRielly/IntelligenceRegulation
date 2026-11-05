# A11 pairs: [ahead16+qos2] against [noahead], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-afed131c59aa694b5/results/zk60_effplan_20261105/a13/s4_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | -1.1% (1, 1) | +4.8% (1, 0) | **+1.8%** | 4.135 / 4.209 |
| forks phase s | -0.7% (1, 1) | +5.3% (1, 0) | **+2.3%** | 3.745 / 3.829 |
| sealed wall s | -0.2% (1, 1) | +0.2% (1, 0) | **-0.0%** | 8.563 / 8.563 |
| stream steady tok/s | -3.7% (1, 0) | -4.3% (1, 0) | **-4.0%** | 23.495 / 22.550 |
| stream amortized tok/s | -4.2% (1, 0) | -3.4% (1, 0) | **-3.8%** | 20.260 / 19.490 |
| user CPU s | +1.4% (1, 0) | +2.4% (1, 0) | **+1.9%** | 42.250 / 43.050 |
| sys CPU s | -3.7% (1, 1) | +5.5% (1, 0) | **+0.9%** | 7.650 / 7.700 |
| minor faults | -9.9% (1, 1) | -1.0% (1, 1) | **-5.5%** | 1,175,272 / 1,109,512 |

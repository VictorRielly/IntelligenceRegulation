# A11 pairs: [looked1+checked1] against [looked1], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528/results/zk60_effplan_20261105/a17/raw/s5_checked_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | -1.1% (3, 1) | -2.5% (3, 2) | **-1.8%** | 4.011 / 3.936 |
| forks phase s | -0.3% (3, 1) | -2.8% (3, 2) | **-1.5%** | 3.616 / 3.559 |
| sealed wall s | +0.2% (3, 1) | +1.5% (3, 1) | **+0.8%** | 7.283 / 7.342 |
| stream steady tok/s | +2.6% (3, 2) | +1.2% (3, 3) | **+1.9%** | 29.058 / 29.605 |
| stream amortized tok/s | +1.0% (3, 2) | +0.8% (3, 2) | **+0.9%** | 24.573 / 24.788 |
| user CPU s | +0.3% (3, 1) | -1.0% (3, 2) | **-0.4%** | 39.933 / 39.783 |
| sys CPU s | -11.9% (3, 3) | +6.5% (3, 0) | **-2.7%** | 5.500 / 5.300 |
| minor faults | +3.4% (3, 0) | -7.8% (3, 3) | **-2.2%** | 685,996 / 667,742 |

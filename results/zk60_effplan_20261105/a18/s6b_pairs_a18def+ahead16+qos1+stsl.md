# A11 pairs: [a18def+ahead16+qos1+stsl] against [a18def+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s6b_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | -1.9% (3, 3) | -1.5% (3, 3) | **-1.7%** | 4.033 / 3.961 |
| forks phase s | -1.3% (3, 2) | -1.7% (3, 3) | **-1.5%** | 3.642 / 3.587 |
| sealed wall s | -2.0% (3, 3) | -1.0% (3, 2) | **-1.5%** | 5.615 / 5.531 |
| stream steady tok/s | +4.9% (3, 3) | +3.5% (3, 3) | **+4.2%** | 32.533 / 33.893 |
| stream amortized tok/s | +0.4% (3, 3) | -0.2% (3, 1) | **+0.1%** | 28.723 / 28.752 |
| user CPU s | -1.6% (3, 3) | +0.1% (3, 2) | **-0.7%** | 40.183 / 39.883 |
| sys CPU s | -3.1% (3, 2) | +4.9% (3, 1) | **+0.9%** | 5.050 / 5.067 |
| minor faults | +4.8% (3, 0) | +10.3% (3, 0) | **+7.6%** | 657,365 / 706,405 |

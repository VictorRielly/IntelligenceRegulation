# A11 pairs: [a18new+ahead32+stsl] against [a18new+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s3c_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | -0.8% (3, 2) | +3.7% (3, 0) | **+1.5%** | 3.966 / 4.021 |
| forks phase s | -0.7% (3, 2) | +3.9% (3, 0) | **+1.6%** | 3.591 / 3.645 |
| sealed wall s | -0.2% (3, 2) | +1.5% (3, 0) | **+0.6%** | 5.617 / 5.652 |
| stream steady tok/s | +1.3% (3, 2) | -0.3% (3, 2) | **+0.5%** | 32.613 / 32.763 |
| stream amortized tok/s | -5.4% (3, 0) | -6.1% (3, 0) | **-5.7%** | 28.773 / 27.112 |
| user CPU s | -0.4% (3, 2) | +1.0% (3, 0) | **+0.3%** | 40.283 / 40.400 |
| sys CPU s | +4.7% (3, 1) | +22.5% (3, 0) | **+13.6%** | 5.450 / 6.167 |
| minor faults | -5.5% (3, 3) | +33.2% (3, 1) | **+13.9%** | 725,391 / 822,850 |

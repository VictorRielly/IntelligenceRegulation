# A11 pairs: [a18def+ahead16+stsl] against [a18old+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s7b_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | -0.5% (3, 2) | -1.7% (3, 2) | **-1.1%** | 3.979 / 3.934 |
| forks phase s | -0.3% (3, 2) | -2.3% (3, 2) | **-1.3%** | 3.608 / 3.561 |
| sealed wall s | -1.3% (3, 2) | -2.4% (3, 2) | **-1.9%** | 5.679 / 5.571 |
| stream steady tok/s | +4.1% (3, 3) | +3.0% (3, 3) | **+3.5%** | 32.483 / 33.627 |
| stream amortized tok/s | +0.6% (3, 1) | -0.9% (3, 1) | **-0.1%** | 28.520 / 28.475 |
| user CPU s | -0.5% (3, 2) | -1.2% (3, 2) | **-0.9%** | 40.167 / 39.817 |
| sys CPU s | -13.6% (3, 3) | -3.2% (3, 1) | **-8.4%** | 5.483 / 5.017 |
| minor faults | -2.9% (3, 2) | +0.5% (3, 2) | **-1.2%** | 683,030 / 673,326 |

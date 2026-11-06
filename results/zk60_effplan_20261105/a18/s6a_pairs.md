# A11 pairs: [a18def+ahead16+stsl] against [a18def+noahead+stsl], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s6a_d55_ab.log)

| metric | base first: mean change (pairs, favour test) | test first: mean change (pairs, favour test) | order bias solved out | means base / test |
|---|---|---|---|---|
| proof wall s | +0.7% (3, 1) | +0.9% (3, 2) | **+0.8%** | 3.933 / 3.963 |
| forks phase s | +0.4% (3, 1) | +1.0% (3, 2) | **+0.7%** | 3.556 / 3.580 |
| sealed wall s | -2.9% (3, 3) | -1.6% (3, 2) | **-2.3%** | 5.569 / 5.442 |
| stream steady tok/s | +5.8% (3, 3) | +4.1% (3, 3) | **+5.0%** | 32.113 / 33.700 |
| stream amortized tok/s | +1.6% (3, 2) | +0.1% (3, 1) | **+0.8%** | 28.563 / 28.802 |
| user CPU s | +0.0% (3, 1) | -0.2% (3, 2) | **-0.1%** | 39.867 / 39.833 |
| sys CPU s | -2.1% (3, 1) | +4.8% (3, 1) | **+1.3%** | 5.367 / 5.433 |
| minor faults | -4.3% (3, 2) | +5.9% (3, 1) | **+0.8%** | 681,137 / 684,182 |

# A15 sealing-pass clocks: [spauto+a16def] against [spauto+a16old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s2_default_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -49.6% (3, 3) | -48.7% (3, 3) | **-49.1%** | 3.675 / 1.862 |
| one request: sealing user CPU s | -29.7% (3, 3) | -29.7% (3, 3) | **-29.7%** | 7.803 / 5.482 |
| one request: sealing sys CPU s | +54.4% (3, 0) | +55.9% (3, 0) | **+55.1%** | 3.193 / 4.837 |
| one request: sealing involuntary csw | -5.7% (3, 1) | +0.9% (3, 2) | **-2.4%** | 45171.833 / 43581.000 |
| stream: request 0's sealing pass s (alone) | -51.7% (3, 3) | -51.4% (3, 3) | **-51.6%** | 3.741 / 1.796 |
| stream: requests 1.. sealing pass s (beside the forks) | -41.0% (3, 3) | -46.0% (3, 3) | **-43.5%** | 5.476 / 3.010 |

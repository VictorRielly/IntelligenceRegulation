# A15 sealing-pass clocks: [spauto+a16def] against [spauto+a16old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s3_default_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -47.7% (3, 3) | -50.4% (3, 3) | **-49.1%** | 3.382 / 1.721 |
| one request: sealing user CPU s | -30.1% (3, 3) | -31.3% (3, 3) | **-30.7%** | 7.687 / 5.328 |
| one request: sealing sys CPU s | +59.8% (3, 0) | +38.8% (3, 0) | **+49.3%** | 2.913 / 4.337 |
| one request: sealing involuntary csw | -5.1% (3, 3) | -17.7% (3, 3) | **-11.4%** | 40267.500 / 35643.167 |
| stream: request 0's sealing pass s (alone) | -46.5% (3, 3) | -51.4% (3, 3) | **-48.9%** | 3.387 / 1.727 |
| stream: requests 1.. sealing pass s (beside the forks) | -39.5% (3, 3) | -42.5% (3, 3) | **-41.0%** | 4.522 / 2.667 |

# A13 one-request clocks: [spauto+a16def] against [spauto+a16old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s3_default_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -21.6% (3, 3) | -22.6% (3, 3) | **-22.1%** | 7.450 / 5.800 |
| sealing pass s | -47.7% (3, 3) | -50.4% (3, 3) | **-49.1%** | 3.382 / 1.721 |
| sealing CPU-s | -6.0% (3, 3) | -11.8% (3, 3) | **-8.9%** | 10.617 / 9.667 |
| prove call s | -0.1% (3, 1) | +0.7% (3, 1) | **+0.3%** | 4.068 / 4.080 |
| forks phase (of the request) s | +0.0% (3, 1) | +1.2% (3, 0) | **+0.6%** | 3.692 / 3.713 |
| preflight + commit s | -0.6% (3, 1) | -3.8% (3, 2) | **-2.2%** | 0.295 / 0.288 |

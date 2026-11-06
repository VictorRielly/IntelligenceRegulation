# A13 one-request clocks: [spauto+a16def+prod] against [spauto+a16old+prod], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s3_prod_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -22.8% (2, 2) | -25.0% (2, 2) | **-23.9%** | 7.540 / 5.738 |
| sealing pass s | -49.3% (2, 2) | -52.6% (2, 2) | **-50.9%** | 3.518 / 1.723 |
| sealing CPU-s | -12.5% (2, 2) | -16.6% (2, 2) | **-14.5%** | 11.325 / 9.675 |
| prove call s | -0.1% (2, 1) | -0.2% (2, 1) | **-0.2%** | 4.022 / 4.015 |
| forks phase (of the request) s | -0.3% (2, 1) | -0.4% (2, 2) | **-0.4%** | 3.657 / 3.644 |
| preflight + commit s | +1.4% (2, 1) | +0.4% (2, 1) | **+0.9%** | 0.290 / 0.293 |

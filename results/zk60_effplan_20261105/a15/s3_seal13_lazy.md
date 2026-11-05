# A13 one-request clocks: [spauto+lazy0] against [spauto], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s3_lazy_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +0.9% (3, 0) | +0.9% (3, 0) | **+0.9%** | 7.425 / 7.491 |
| sealing pass s | +0.6% (3, 1) | +0.9% (3, 0) | **+0.8%** | 3.355 / 3.381 |
| sealing CPU-s | +0.6% (3, 0) | +0.6% (3, 0) | **+0.6%** | 10.583 / 10.650 |
| prove call s | +1.1% (3, 1) | +0.9% (3, 0) | **+1.0%** | 4.071 / 4.110 |
| forks phase (of the request) s | +1.4% (3, 1) | +0.6% (3, 1) | **+1.0%** | 3.698 / 3.735 |
| preflight + commit s | -3.5% (3, 2) | +4.4% (3, 1) | **+0.5%** | 0.296 / 0.297 |

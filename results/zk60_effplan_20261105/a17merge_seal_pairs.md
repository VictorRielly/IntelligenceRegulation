# A15 sealing-pass clocks: [a17new] against [a17old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105/a17merge_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +0.4% (2, 1) | +0.3% (2, 1) | **+0.4%** | 3.283 / 3.295 |
| one request: sealing user CPU s | +0.5% (2, 0) | +0.0% (2, 1) | **+0.3%** | 7.550 / 7.570 |
| one request: sealing sys CPU s | +1.0% (2, 1) | +0.5% (2, 0) | **+0.7%** | 2.857 / 2.877 |
| one request: sealing involuntary csw | -3.1% (2, 2) | -0.1% (2, 1) | **-1.6%** | 42001.750 / 41333.750 |
| stream: request 0's sealing pass s (alone) | +1.9% (2, 1) | +0.1% (2, 1) | **+1.0%** | 3.324 / 3.353 |
| stream: requests 1.. sealing pass s (beside the forks) | -0.7% (2, 2) | -3.4% (2, 2) | **-2.1%** | 4.480 / 4.388 |

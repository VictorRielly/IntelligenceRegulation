# A15 sealing-pass clocks: [a16def+prod] against [a16old+prod], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105/a16merge_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -49.0% (2, 2) | -52.6% (2, 2) | **-50.8%** | 3.476 / 1.708 |
| one request: sealing user CPU s | -35.6% (2, 2) | -37.2% (2, 2) | **-36.4%** | 8.305 / 5.280 |
| one request: sealing sys CPU s | +56.4% (2, 0) | +38.9% (2, 0) | **+47.6%** | 2.920 / 4.300 |
| one request: sealing involuntary csw | -17.5% (2, 2) | -26.7% (2, 2) | **-22.1%** | 47266.250 / 36817.000 |
| stream: request 0's sealing pass s (alone) | -50.1% (2, 2) | -51.5% (2, 2) | **-50.8%** | 3.494 / 1.719 |
| stream: requests 1.. sealing pass s (beside the forks) | -40.7% (2, 2) | -43.0% (2, 2) | **-41.8%** | 4.554 / 2.648 |

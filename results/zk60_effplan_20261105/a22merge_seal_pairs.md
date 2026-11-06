# A15 sealing-pass clocks: [default] against [a21old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105/a22merge_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -16.7% (2, 2) | -9.5% (2, 2) | **-13.1%** | 3.263 / 2.834 |
| one request: sealing user CPU s | -35.6% (2, 2) | -36.1% (2, 2) | **-35.8%** | 33.907 / 21.752 |
| one request: sealing sys CPU s | +19.5% (2, 0) | +22.7% (2, 0) | **+21.1%** | 9.383 / 11.360 |
| one request: sealing involuntary csw | +20.3% (2, 0) | +47.0% (2, 0) | **+33.7%** | 164033.500 / 217415.250 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

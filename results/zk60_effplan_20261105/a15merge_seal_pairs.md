# A15 sealing-pass clocks: [spauto] against [spg], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105/a15merge_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -20.1% (2, 2) | -21.0% (2, 2) | **-20.6%** | 4.322 / 3.436 |
| one request: sealing user CPU s | -50.4% (2, 2) | -50.9% (2, 2) | **-50.7%** | 15.322 / 7.560 |
| one request: sealing sys CPU s | -89.6% (2, 2) | -89.6% (2, 2) | **-89.6%** | 27.210 / 2.835 |
| one request: sealing involuntary csw | -93.1% (2, 2) | -93.5% (2, 2) | **-93.3%** | 625480.250 / 41842.500 |
| stream: request 0's sealing pass s (alone) | -26.3% (2, 2) | -19.3% (2, 2) | **-22.8%** | 4.385 / 3.382 |
| stream: requests 1.. sealing pass s (beside the forks) | -14.1% (2, 2) | -13.3% (2, 2) | **-13.7%** | 5.458 / 4.710 |

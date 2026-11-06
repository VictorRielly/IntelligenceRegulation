# A15 sealing-pass clocks: [default] against [a20old], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105/a20merge_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | -64.9% (2, 2) | -65.8% (2, 2) | **-65.4%** | 9.688 / 3.345 |
| one request: sealing user CPU s | +1.5% (2, 0) | +1.3% (2, 0) | **+1.4%** | 33.455 / 33.938 |
| one request: sealing sys CPU s | -18.2% (2, 2) | -16.0% (2, 2) | **-17.1%** | 10.447 / 8.610 |
| one request: sealing involuntary csw | -19.0% (2, 2) | -19.5% (2, 2) | **-19.3%** | 230312.000 / 179210.250 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

# A15 sealing-pass clocks: [share1+noahead] against [share0+noahead], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105/a19merge_prod_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +1.1% (2, 0) | +1.4% (2, 0) | **+1.2%** | 8.990 / 9.102 |
| one request: sealing user CPU s | +0.0% (2, 0) | +0.4% (2, 0) | **+0.2%** | 32.688 / 32.758 |
| one request: sealing sys CPU s | +15.8% (2, 0) | +16.5% (2, 0) | **+16.2%** | 8.555 / 9.935 |
| one request: sealing involuntary csw | -2.4% (2, 1) | -1.9% (2, 1) | **-2.2%** | 175207.000 / 171144.500 |
| stream: request 0's sealing pass s (alone) | — | — | — | — |
| stream: requests 1.. sealing pass s (beside the forks) | — | — | — | — |

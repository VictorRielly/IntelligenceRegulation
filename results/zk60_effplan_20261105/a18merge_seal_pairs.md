# A15 sealing-pass clocks: [a18def+prod] against [a18old+prod], N = 6, alternating order (/Users/victorrielly/IntelligenceRegulation/results/zk60_effplan_20261105/a18merge_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request: sealing pass s | +4.0% (2, 0) | -4.9% (2, 1) | **-0.4%** | 1.524 / 1.512 |
| one request: sealing user CPU s | +2.3% (2, 0) | -0.9% (2, 1) | **+0.7%** | 5.293 / 5.328 |
| one request: sealing sys CPU s | +5.5% (2, 0) | +0.1% (2, 1) | **+2.8%** | 2.848 / 2.910 |
| one request: sealing involuntary csw | +2.0% (2, 1) | -3.2% (2, 1) | **-0.6%** | 28394.250 / 28192.000 |
| stream: request 0's sealing pass s (alone) | -0.3% (2, 1) | +1.9% (2, 1) | **+0.8%** | 1.483 / 1.494 |
| stream: requests 1.. sealing pass s (beside the forks) | +2.9% (2, 0) | +3.7% (2, 0) | **+3.3%** | 2.569 / 2.653 |

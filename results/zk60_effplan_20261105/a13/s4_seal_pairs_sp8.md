# A13 one-request clocks: [sp8] against [noahead], N = 6, alternating order (s4_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -10.4% (1, 1) | -12.6% (1, 1) | **-11.5%** | 8.563 / 7.581 |
| sealing pass s | -20.8% (1, 1) | -22.8% (1, 1) | **-21.8%** | 4.222 / 3.301 |
| sealing CPU-s | -74.3% (1, 1) | -76.0% (1, 1) | **-75.2%** | 42.350 / 10.500 |
| prove call s | -0.7% (1, 1) | -2.1% (1, 1) | **-1.4%** | 4.341 / 4.280 |
| forks phase (of the request) s | +3.1% (1, 0) | -2.6% (1, 1) | **+0.2%** | 3.878 / 3.887 |
| preflight + commit s | -35.9% (1, 1) | +1.9% (1, 0) | **-17.0%** | 0.387 / 0.307 |

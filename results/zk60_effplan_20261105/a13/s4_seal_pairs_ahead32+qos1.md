# A13 one-request clocks: [ahead32+qos1] against [noahead], N = 6, alternating order (s4_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -3.5% (1, 1) | -3.5% (1, 1) | **-3.5%** | 8.563 / 8.264 |
| sealing pass s | +8.3% (1, 0) | +2.3% (1, 0) | **+5.3%** | 4.222 / 4.443 |
| sealing CPU-s | +38.7% (1, 0) | +24.4% (1, 0) | **+31.5%** | 42.350 / 55.550 |
| prove call s | -14.5% (1, 1) | -9.4% (1, 1) | **-11.9%** | 4.341 / 3.821 |
| forks phase (of the request) s | -13.8% (1, 1) | -11.4% (1, 1) | **-12.6%** | 3.878 / 3.389 |
| preflight + commit s | -30.5% (1, 1) | +4.2% (1, 0) | **-13.1%** | 0.387 / 0.323 |

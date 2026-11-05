# A13 one-request clocks: [ahead16+qos2] against [noahead], N = 6, alternating order (s4_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -0.2% (1, 1) | +0.2% (1, 0) | **-0.0%** | 8.563 / 8.563 |
| sealing pass s | +11.5% (1, 0) | +9.5% (1, 0) | **+10.5%** | 4.222 / 4.664 |
| sealing CPU-s | +39.7% (1, 0) | +25.1% (1, 0) | **+32.4%** | 42.350 / 55.900 |
| prove call s | -11.1% (1, 1) | -9.2% (1, 1) | **-10.2%** | 4.341 / 3.899 |
| forks phase (of the request) s | -8.7% (1, 1) | -9.9% (1, 1) | **-9.3%** | 3.878 / 3.516 |
| preflight + commit s | -36.7% (1, 1) | -4.2% (1, 1) | **-20.4%** | 0.387 / 0.295 |

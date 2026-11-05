# A13 one-request clocks: [ahead32+qos2+sp16] against [noahead], N = 6, alternating order (s4_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -7.3% (1, 1) | -11.6% (1, 1) | **-9.5%** | 8.563 / 7.751 |
| sealing pass s | -8.7% (1, 1) | -15.4% (1, 1) | **-12.0%** | 4.222 / 3.711 |
| sealing CPU-s | +0.7% (1, 0) | -8.7% (1, 1) | **-4.0%** | 42.350 / 40.550 |
| prove call s | -6.1% (1, 1) | -7.8% (1, 1) | **-7.0%** | 4.341 / 4.040 |
| forks phase (of the request) s | -6.9% (1, 1) | -11.9% (1, 1) | **-9.4%** | 3.878 / 3.513 |
| preflight + commit s | -0.4% (1, 1) | +39.2% (1, 0) | **+19.4%** | 0.387 / 0.447 |

# A13 one-request clocks: [sp16] against [noahead], N = 6, alternating order (s4_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | -11.2% (1, 1) | -10.7% (1, 1) | **-11.0%** | 8.563 / 7.624 |
| sealing pass s | -16.9% (1, 1) | -18.7% (1, 1) | **-17.8%** | 4.222 / 3.468 |
| sealing CPU-s | -54.9% (1, 1) | -57.4% (1, 1) | **-56.1%** | 42.350 / 18.550 |
| prove call s | -5.9% (1, 1) | -2.5% (1, 1) | **-4.2%** | 4.341 / 4.156 |
| forks phase (of the request) s | -2.3% (1, 1) | -3.2% (1, 1) | **-2.7%** | 3.878 / 3.772 |
| preflight + commit s | -40.4% (1, 1) | -3.5% (1, 1) | **-22.0%** | 0.387 / 0.288 |

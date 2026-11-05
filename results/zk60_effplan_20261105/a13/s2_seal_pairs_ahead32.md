# A13 one-request clocks: [ahead32] against [noahead], N = 6, alternating order (s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +2.4% (1, 0) | -0.2% (1, 1) | **+1.1%** | 8.423 / 8.514 |
| sealing pass s | +10.4% (1, 0) | +8.0% (1, 0) | **+9.2%** | 4.244 / 4.632 |
| sealing CPU-s | +34.4% (1, 0) | +25.8% (1, 0) | **+30.1%** | 42.900 / 55.750 |
| prove call s | -5.2% (1, 1) | -8.7% (1, 1) | **-6.9%** | 4.172 / 3.882 |
| forks phase (of the request) s | -7.5% (1, 1) | -11.3% (1, 1) | **-9.4%** | 3.809 / 3.450 |
| preflight + commit s | +20.6% (1, 0) | +13.8% (1, 0) | **+17.2%** | 0.285 / 0.335 |

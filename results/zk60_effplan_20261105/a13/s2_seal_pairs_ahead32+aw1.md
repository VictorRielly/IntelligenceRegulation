# A13 one-request clocks: [ahead32+aw1] against [noahead], N = 6, alternating order (s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +1.6% (1, 0) | -0.1% (1, 1) | **+0.7%** | 8.423 / 8.484 |
| sealing pass s | +12.6% (1, 0) | +7.4% (1, 0) | **+10.0%** | 4.244 / 4.664 |
| sealing CPU-s | +34.9% (1, 0) | +26.0% (1, 0) | **+30.4%** | 42.900 / 55.900 |
| prove call s | -8.9% (1, 1) | -7.9% (1, 1) | **-8.4%** | 4.172 / 3.820 |
| forks phase (of the request) s | -10.8% (1, 1) | -10.0% (1, 1) | **-10.4%** | 3.809 / 3.413 |
| preflight + commit s | +14.2% (1, 0) | +13.1% (1, 0) | **+13.7%** | 0.285 / 0.325 |

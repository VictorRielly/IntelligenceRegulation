# A13 one-request clocks: [ahead16] against [noahead], N = 6, alternating order (s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +3.1% (1, 0) | +1.0% (1, 0) | **+2.0%** | 8.423 / 8.591 |
| sealing pass s | +10.1% (1, 0) | +5.8% (1, 0) | **+7.9%** | 4.244 / 4.578 |
| sealing CPU-s | +15.9% (1, 0) | +13.6% (1, 0) | **+14.7%** | 42.900 / 49.200 |
| prove call s | -3.6% (1, 1) | -4.0% (1, 1) | **-3.8%** | 4.172 / 4.014 |
| forks phase (of the request) s | -7.1% (1, 1) | -4.6% (1, 1) | **-5.8%** | 3.809 / 3.588 |
| preflight + commit s | +22.8% (1, 0) | +2.4% (1, 0) | **+12.6%** | 0.285 / 0.321 |

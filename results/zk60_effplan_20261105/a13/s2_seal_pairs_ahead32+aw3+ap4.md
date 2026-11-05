# A13 one-request clocks: [ahead32+aw3+ap4] against [noahead], N = 6, alternating order (s2_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +5.4% (1, 0) | -2.0% (1, 1) | **+1.7%** | 8.423 / 8.561 |
| sealing pass s | +17.8% (1, 0) | +5.0% (1, 0) | **+11.4%** | 4.244 / 4.720 |
| sealing CPU-s | +27.2% (1, 0) | +23.1% (1, 0) | **+25.1%** | 42.900 / 53.650 |
| prove call s | -6.5% (1, 1) | -9.3% (1, 1) | **-7.9%** | 4.172 / 3.841 |
| forks phase (of the request) s | -9.5% (1, 1) | -11.4% (1, 1) | **-10.5%** | 3.809 / 3.410 |
| preflight + commit s | +21.4% (1, 0) | +17.6% (1, 0) | **+19.5%** | 0.285 / 0.341 |

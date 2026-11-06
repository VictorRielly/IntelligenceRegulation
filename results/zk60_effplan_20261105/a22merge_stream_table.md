| arm | passes | steady tok/s mean (min, max) | amortized tok/s mean (min, max) | first request's latency, mean | mean latency | peak footprint |
|---|---:|---:|---:|---:|---:|---:|
| serve1 | 4 | n/a (one request) | 18.85 (18.55, 19.13) | 6.793 s | 6.793 s | 50.3 GiB |
| serve4 | 4 | 29.67 (29.26, 29.89) | 25.28 (25.11, 25.44) | 7.305 s | 13.866 s | 59.8 GiB |
| harness4 | 4 | 32.65 (32.20, 32.97) | 28.93 (28.54, 29.32) | 5.940 s | 8.742 s | 54.7 GiB |
| serve8 | 4 | 29.05 (28.83, 29.37) | 26.89 (26.60, 27.22) | 7.245 s | 18.443 s | 60.3 GiB |

**serve4 -> harness4** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.89 / 32.95 | +10.2% | 25.44 / 29.32 | +15.3% |
| 1 | 29.89 / 32.97 | +10.3% | 25.33 / 29.09 | +14.8% |
| 2 | 29.65 / 32.48 | +9.5% | 25.25 / 28.77 | +13.9% |
| 3 | 29.26 / 32.20 | +10.0% | 25.11 / 28.54 | +13.7% |

steady: mean +10.0% (4 of 4 faster; even passes +9.9%, odd +10.2%); amortized: mean +14.4% (4 of 4 faster; even +14.6%, odd +14.3%)

**serve4 -> serve8** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.89 / 29.37 | -1.7% | 25.44 / 27.22 | +7.0% |
| 1 | 29.89 / 28.99 | -3.0% | 25.33 / 26.93 | +6.3% |
| 2 | 29.65 / 28.83 | -2.8% | 25.25 / 26.60 | +5.3% |
| 3 | 29.26 / 29.03 | -0.8% | 25.11 / 26.81 | +6.8% |

steady: mean -2.1% (0 of 4 faster; even passes -2.3%, odd -1.9%); amortized: mean +6.4% (4 of 4 faster; even +6.2%, odd +6.5%)

| served arm | requests (after the first of each stream) | sealing pass | waited for the prover | prove call | preflight | commit | forks | join | receipt write |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| serve4 | 12 | 3.889 s | 0.346 s | 4.332 s | 0.275 s | 0.238 s | 3.739 s | 0.081 s | 0.240 s |
| serve8 | 28 | 3.851 s | 0.320 s | 4.411 s | 0.270 s | 0.251 s | 3.811 s | 0.080 s | 0.241 s |

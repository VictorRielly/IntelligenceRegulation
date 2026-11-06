| arm | passes | steady tok/s mean (min, max) | amortized tok/s mean (min, max) | first request's latency, mean | mean latency | peak footprint |
|---|---:|---:|---:|---:|---:|---:|
| serve1 | 2 | n/a (one request) | 18.20 (18.06, 18.34) | 7.035 s | 7.035 s | 50.2 GiB |
| serve4 | 2 | 29.49 (29.34, 29.64) | 25.12 (24.95, 25.29) | 7.365 s | 13.961 s | 59.6 GiB |
| harness4 | 2 | 32.43 (32.28, 32.58) | 28.85 (28.78, 28.92) | 5.905 s | 8.709 s | 54.0 GiB |
| serve8 | 2 | 29.16 (28.99, 29.34) | 26.98 (26.83, 27.12) | 7.230 s | 18.423 s | 59.4 GiB |

**serve4 -> harness4** (2 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.64 / 32.28 | +8.9% | 25.29 / 28.78 | +13.8% |
| 1 | 29.34 / 32.58 | +11.0% | 24.95 / 28.92 | +15.9% |

steady: mean +10.0% (2 of 2 faster; even passes +8.9%, odd +11.0%); amortized: mean +14.9% (2 of 2 faster; even +13.8%, odd +15.9%)

**serve4 -> serve8** (2 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.64 / 29.34 | -1.0% | 25.29 / 27.12 | +7.2% |
| 1 | 29.34 / 28.99 | -1.2% | 24.95 / 26.83 | +7.5% |

steady: mean -1.1% (0 of 2 faster; even passes -1.0%, odd -1.2%); amortized: mean +7.4% (2 of 2 faster; even +7.2%, odd +7.5%)

| served arm | requests (after the first of each stream) | sealing pass | waited for the prover | prove call | preflight | commit | forks | join | receipt write |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| serve4 | 6 | 3.925 s | 0.339 s | 4.357 s | 0.277 s | 0.234 s | 3.770 s | 0.077 s | 0.241 s |
| serve8 | 14 | 3.822 s | 0.355 s | 4.395 s | 0.270 s | 0.243 s | 3.804 s | 0.078 s | 0.249 s |

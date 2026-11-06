| arm | passes | steady tok/s mean (min, max) | amortized tok/s mean (min, max) | first request's latency, mean | mean latency | peak footprint |
|---|---:|---:|---:|---:|---:|---:|
| serve1 | 4 | n/a (one request) | 18.27 (17.98, 18.43) | 7.008 s | 7.008 s | 69.0 GiB |
| serve4 | 4 | 29.23 (28.58, 29.51) | 24.88 (24.59, 25.12) | 7.445 s | 14.133 s | 78.8 GiB |
| harness4 | 4 | 32.53 (32.38, 32.73) | 28.61 (28.40, 28.77) | 6.088 s | 8.845 s | 73.2 GiB |
| serve8 | 4 | 28.98 (28.84, 29.07) | 26.72 (26.61, 26.89) | 7.410 s | 18.601 s | 78.9 GiB |
| serve4+dig1 | 4 | 30.67 (30.02, 31.14) | 25.82 (25.59, 26.16) | 7.308 s | 13.689 s | 78.7 GiB |
| serve4+ahead16 | 4 | 29.73 (29.41, 30.21) | 25.00 (24.73, 25.27) | 7.562 s | 14.179 s | 84.6 GiB |

**serve4 -> harness4** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.41 / 32.38 | +10.1% | 24.94 / 28.40 | +13.9% |
| 1 | 28.58 / 32.73 | +14.5% | 24.59 / 28.68 | +16.6% |
| 2 | 29.41 / 32.54 | +10.6% | 25.12 / 28.77 | +14.5% |
| 3 | 29.51 / 32.46 | +10.0% | 24.85 / 28.60 | +15.1% |

steady: mean +11.3% (4 of 4 faster; even passes +10.4%, odd +12.3%); amortized: mean +15.0% (4 of 4 faster; even +14.2%, odd +15.9%)

**serve4 -> serve4+dig1** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.41 / 31.01 | +5.4% | 24.94 / 25.87 | +3.7% |
| 1 | 28.58 / 30.02 | +5.0% | 24.59 / 25.59 | +4.1% |
| 2 | 29.41 / 30.50 | +3.7% | 25.12 / 25.66 | +2.1% |
| 3 | 29.51 / 31.14 | +5.5% | 24.85 / 26.16 | +5.3% |

steady: mean +4.9% (4 of 4 faster; even passes +4.6%, odd +5.3%); amortized: mean +3.8% (4 of 4 faster; even +2.9%, odd +4.7%)

**serve4 -> serve4+ahead16** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.41 / 30.21 | +2.7% | 24.94 / 25.27 | +1.3% |
| 1 | 28.58 / 29.53 | +3.3% | 24.59 / 24.96 | +1.5% |
| 2 | 29.41 / 29.76 | +1.2% | 25.12 / 25.05 | -0.3% |
| 3 | 29.51 / 29.41 | -0.3% | 24.85 / 24.73 | -0.5% |

steady: mean +1.7% (3 of 4 faster; even passes +2.0%, odd +1.5%); amortized: mean +0.5% (2 of 4 faster; even +0.5%, odd +0.5%)

**serve4 -> serve8** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.41 / 29.07 | -1.2% | 24.94 / 26.89 | +7.8% |
| 1 | 28.58 / 28.84 | +0.9% | 24.59 / 26.61 | +8.2% |
| 2 | 29.41 / 29.00 | -1.4% | 25.12 / 26.74 | +6.4% |
| 3 | 29.51 / 29.02 | -1.7% | 24.85 / 26.64 | +7.2% |

steady: mean -0.8% (1 of 4 faster; even passes -1.3%, odd -0.4%); amortized: mean +7.4% (4 of 4 faster; even +7.1%, odd +7.7%)

| served arm | requests (after the first of each stream) | sealing pass | waited for the prover | prove call | preflight | commit | forks | join | receipt write |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| serve4 | 12 | 3.940 s | 0.349 s | 4.393 s | 0.280 s | 0.240 s | 3.789 s | 0.084 s | 0.249 s |
| serve8 | 28 | 3.832 s | 0.349 s | 4.425 s | 0.274 s | 0.252 s | 3.818 s | 0.081 s | 0.245 s |
| serve4+dig1 | 12 | 3.921 s | 0.239 s | 4.178 s | 0.118 s | 0.230 s | 3.748 s | 0.082 s | 0.216 s |
| serve4+ahead16 | 12 | 4.013 s | 0.324 s | 4.322 s | 0.281 s | 0.257 s | 3.701 s | 0.084 s | 0.235 s |

| arm | passes | steady tok/s mean (min, max) | amortized tok/s mean (min, max) | first request's latency, mean | mean latency | peak footprint |
|---|---:|---:|---:|---:|---:|---:|
| serve1 | 4 | n/a (one request) | 20.18 (19.82, 20.36) | 6.345 s | 6.345 s | 43.2 GiB |
| serve4 | 4 | 32.40 (32.26, 32.67) | 27.46 (27.13, 27.78) | 6.795 s | 12.781 s | 45.6 GiB |
| serve4+chk0 | 4 | 31.04 (30.83, 31.38) | 26.66 (26.60, 26.77) | 6.835 s | 13.100 s | 45.9 GiB |
| serve4+share0 | 4 | 30.04 (29.73, 30.45) | 25.51 (25.32, 25.87) | 7.287 s | 13.789 s | 60.1 GiB |
| harness4 | 4 | 33.15 (32.89, 33.65) | 29.13 (28.83, 29.35) | 5.995 s | 8.686 s | 54.5 GiB |
| serve8 | 4 | 31.90 (31.79, 32.16) | 29.38 (29.29, 29.57) | 6.768 s | 16.854 s | 45.3 GiB |

**serve4+share0 -> serve4** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 30.45 / 32.67 | +7.3% | 25.87 / 27.78 | +7.4% |
| 1 | 30.03 / 32.35 | +7.7% | 25.43 / 27.13 | +6.7% |
| 2 | 29.73 / 32.31 | +8.7% | 25.32 / 27.44 | +8.4% |
| 3 | 29.93 / 32.26 | +7.8% | 25.42 / 27.48 | +8.1% |

steady: mean +7.9% (4 of 4 faster; even passes +8.0%, odd +7.8%); amortized: mean +7.6% (4 of 4 faster; even +7.9%, odd +7.4%)

**serve4+chk0 -> serve4** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 30.86 / 32.67 | +5.9% | 26.65 / 27.78 | +4.2% |
| 1 | 31.08 / 32.35 | +4.1% | 26.60 / 27.13 | +2.0% |
| 2 | 31.38 / 32.31 | +3.0% | 26.77 / 27.44 | +2.5% |
| 3 | 30.83 / 32.26 | +4.6% | 26.61 / 27.48 | +3.3% |

steady: mean +4.4% (4 of 4 faster; even passes +4.4%, odd +4.4%); amortized: mean +3.0% (4 of 4 faster; even +3.4%, odd +2.6%)

**serve4 -> harness4** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 32.67 / 32.93 | +0.8% | 27.78 / 29.21 | +5.1% |
| 1 | 32.35 / 32.89 | +1.7% | 27.13 / 28.83 | +6.3% |
| 2 | 32.31 / 33.13 | +2.5% | 27.44 / 29.12 | +6.1% |
| 3 | 32.26 / 33.65 | +4.3% | 27.48 / 29.35 | +6.8% |

steady: mean +2.3% (4 of 4 faster; even passes +1.7%, odd +3.0%); amortized: mean +6.1% (4 of 4 faster; even +5.6%, odd +6.5%)

| served arm | requests (after the first of each stream) | sealing pass | waited for the prover | prove call | preflight | commit | forks | join | receipt write |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| serve4 | 12 | 3.638 s | 0.284 s | 3.944 s | 0.002 s | 0.214 s | 3.651 s | 0.077 s | 0.216 s |
| serve4+chk0 | 12 | 3.678 s | 0.428 s | 4.122 s | 0.103 s | 0.216 s | 3.724 s | 0.078 s | 0.218 s |
| serve4+share0 | 12 | 3.820 s | 0.379 s | 4.277 s | 0.269 s | 0.237 s | 3.695 s | 0.076 s | 0.243 s |
| serve8 | 28 | 3.647 s | 0.216 s | 4.012 s | 0.002 s | 0.216 s | 3.717 s | 0.078 s | 0.217 s |

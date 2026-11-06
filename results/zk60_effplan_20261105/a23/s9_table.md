| arm | passes | steady tok/s mean (min, max) | amortized tok/s mean (min, max) | first request's latency, mean | mean latency | peak footprint |
|---|---:|---:|---:|---:|---:|---:|
| serve1 | 2 | n/a (one request) | 19.88 (19.70, 20.05) | 6.440 s | 6.440 s | 43.3 GiB |
| serve4 | 2 | 31.75 (31.67, 31.83) | 27.16 (27.06, 27.27) | 6.755 s | 12.893 s | 45.5 GiB |
| harness4 | 2 | 33.27 (32.97, 33.58) | 29.30 (29.19, 29.40) | 5.935 s | 8.600 s | 54.4 GiB |
| serve8 | 2 | 30.82 (30.77, 30.87) | 28.59 (28.56, 28.62) | 6.745 s | 17.361 s | 45.6 GiB |
| serve4+share0 | 2 | 29.80 (29.73, 29.88) | 25.52 (25.45, 25.60) | 7.180 s | 13.731 s | 59.3 GiB |
| serve4+chk1 | 2 | 32.57 (32.47, 32.67) | 27.94 (27.79, 28.09) | 6.535 s | 12.499 s | 45.2 GiB |

**serve4 -> harness4** (2 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 31.83 / 33.58 | +5.5% | 27.06 / 29.40 | +8.6% |
| 1 | 31.67 / 32.97 | +4.1% | 27.27 / 29.19 | +7.0% |

steady: mean +4.8% (2 of 2 faster; even passes +5.5%, odd +4.1%); amortized: mean +7.8% (2 of 2 faster; even +8.6%, odd +7.0%)

**serve4 -> serve8** (2 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 31.83 / 30.77 | -3.3% | 27.06 / 28.62 | +5.8% |
| 1 | 31.67 / 30.87 | -2.5% | 27.27 / 28.56 | +4.7% |

steady: mean -2.9% (0 of 2 faster; even passes -3.3%, odd -2.5%); amortized: mean +5.2% (2 of 2 faster; even +5.8%, odd +4.7%)

**serve4+share0 -> serve4** (2 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.73 / 31.83 | +7.1% | 25.60 / 27.06 | +5.7% |
| 1 | 29.88 / 31.67 | +6.0% | 25.45 / 27.27 | +7.2% |

steady: mean +6.5% (2 of 2 faster; even passes +7.1%, odd +6.0%); amortized: mean +6.4% (2 of 2 faster; even +5.7%, odd +7.2%)

**serve4 -> serve4+chk1** (2 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 31.83 / 32.67 | +2.6% | 27.06 / 28.09 | +3.8% |
| 1 | 31.67 / 32.47 | +2.5% | 27.27 / 27.79 | +1.9% |

steady: mean +2.6% (2 of 2 faster; even passes +2.6%, odd +2.5%); amortized: mean +2.9% (2 of 2 faster; even +3.8%, odd +1.9%)

**serve4+chk1 -> harness4** (2 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 32.67 / 33.58 | +2.8% | 28.09 / 29.40 | +4.7% |
| 1 | 32.47 / 32.97 | +1.5% | 27.79 / 29.19 | +5.0% |

steady: mean +2.2% (2 of 2 faster; even passes +2.8%, odd +1.5%); amortized: mean +4.9% (2 of 2 faster; even +4.7%, odd +5.0%)

| served arm | requests (after the first of each stream) | sealing pass | waited for the prover | prove call | preflight | commit | forks | join | receipt write |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| serve4 | 6 | 3.644 s | 0.382 s | 4.021 s | 0.096 s | 0.217 s | 3.629 s | 0.079 s | 0.224 s |
| serve8 | 14 | 3.623 s | 0.372 s | 4.151 s | 0.101 s | 0.221 s | 3.753 s | 0.076 s | 0.217 s |
| serve4+share0 | 6 | 3.890 s | 0.318 s | 4.310 s | 0.266 s | 0.244 s | 3.722 s | 0.078 s | 0.238 s |
| serve4+chk1 | 6 | 3.630 s | 0.255 s | 3.925 s | 0.001 s | 0.218 s | 3.624 s | 0.081 s | 0.221 s |

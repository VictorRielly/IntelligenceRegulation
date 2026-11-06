| arm | passes | steady tok/s mean (min, max) | amortized tok/s mean (min, max) | first request's latency, mean | mean latency | peak footprint |
|---|---:|---:|---:|---:|---:|---:|
| serve4 | 4 | 29.49 (28.62, 29.90) | 25.09 (24.43, 25.48) | 7.385 s | 14.018 s | 60.4 GiB |
| serve4+share1 | 4 | 31.35 (30.91, 31.76) | 27.02 (26.62, 27.44) | 6.703 s | 12.918 s | 46.4 GiB |
| serve4+share1+chk1 | 4 | 32.56 (32.29, 32.79) | 27.75 (27.67, 27.83) | 6.660 s | 12.623 s | 46.1 GiB |
| harness4 | 4 | 32.79 (32.55, 32.98) | 28.92 (28.65, 29.14) | 5.990 s | 8.746 s | 54.6 GiB |
| serve4+share1+chk1+seal6 | 4 | 32.49 (31.69, 32.89) | 27.50 (27.12, 28.09) | 6.800 s | 12.796 s | 46.2 GiB |
| serve4+share1+chk1+seal4 | 4 | 32.59 (32.16, 33.00) | 27.32 (27.11, 27.49) | 6.952 s | 12.874 s | 45.5 GiB |
| serve8+share1+chk1 | 4 | 32.22 (31.87, 32.45) | 29.73 (29.51, 29.97) | 6.623 s | 16.654 s | 45.7 GiB |
| serve1+share1+chk1 | 4 | n/a (one request) | 20.17 (19.87, 20.46) | 6.348 s | 6.348 s | 44.0 GiB |
| serve1 | 4 | n/a (one request) | 18.67 (18.47, 18.77) | 6.855 s | 6.855 s | 50.5 GiB |

**serve4 -> serve4+share1** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.63 / 31.20 | +5.3% | 25.25 / 27.01 | +7.0% |
| 1 | 29.90 / 31.54 | +5.5% | 25.48 / 27.01 | +6.0% |
| 2 | 29.81 / 30.91 | +3.7% | 25.21 / 26.62 | +5.6% |
| 3 | 28.62 / 31.76 | +11.0% | 24.43 / 27.44 | +12.3% |

steady: mean +6.4% (4 of 4 faster; even passes +4.5%, odd +8.2%); amortized: mean +7.7% (4 of 4 faster; even +6.3%, odd +9.2%)

**serve4+share1 -> serve4+share1+chk1** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 31.20 / 32.41 | +3.9% | 27.01 / 27.67 | +2.4% |
| 1 | 31.54 / 32.29 | +2.4% | 27.01 / 27.70 | +2.6% |
| 2 | 30.91 / 32.79 | +6.1% | 26.62 / 27.78 | +4.4% |
| 3 | 31.76 / 32.77 | +3.2% | 27.44 / 27.83 | +1.4% |

steady: mean +3.9% (4 of 4 faster; even passes +5.0%, odd +2.8%); amortized: mean +2.7% (4 of 4 faster; even +3.4%, odd +2.0%)

**serve4 -> serve4+share1+chk1** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.63 / 32.41 | +9.4% | 25.25 / 27.67 | +9.6% |
| 1 | 29.90 / 32.29 | +8.0% | 25.48 / 27.70 | +8.7% |
| 2 | 29.81 / 32.79 | +10.0% | 25.21 / 27.78 | +10.2% |
| 3 | 28.62 / 32.77 | +14.5% | 24.43 / 27.83 | +13.9% |

steady: mean +10.5% (4 of 4 faster; even passes +9.7%, odd +11.2%); amortized: mean +10.6% (4 of 4 faster; even +9.9%, odd +11.3%)

**serve4+share1+chk1 -> harness4** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 32.41 / 32.93 | +1.6% | 27.67 / 29.14 | +5.3% |
| 1 | 32.29 / 32.55 | +0.8% | 27.70 / 28.65 | +3.4% |
| 2 | 32.79 / 32.69 | -0.3% | 27.78 / 28.79 | +3.6% |
| 3 | 32.77 / 32.98 | +0.6% | 27.83 / 29.11 | +4.6% |

steady: mean +0.7% (3 of 4 faster; even passes +0.6%, odd +0.7%); amortized: mean +4.2% (4 of 4 faster; even +4.5%, odd +4.0%)

**serve4 -> harness4** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 29.63 / 32.93 | +11.1% | 25.25 / 29.14 | +15.4% |
| 1 | 29.90 / 32.55 | +8.9% | 25.48 / 28.65 | +12.4% |
| 2 | 29.81 / 32.69 | +9.7% | 25.21 / 28.79 | +14.2% |
| 3 | 28.62 / 32.98 | +15.2% | 24.43 / 29.11 | +19.2% |

steady: mean +11.2% (4 of 4 faster; even passes +10.4%, odd +12.0%); amortized: mean +15.3% (4 of 4 faster; even +14.8%, odd +15.8%)

**serve4+share1+chk1 -> serve4+share1+chk1+seal6** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 32.41 / 32.54 | +0.4% | 27.67 / 27.32 | -1.3% |
| 1 | 32.29 / 31.69 | -1.9% | 27.70 / 27.12 | -2.1% |
| 2 | 32.79 / 32.89 | +0.3% | 27.78 / 27.47 | -1.1% |
| 3 | 32.77 / 32.84 | +0.2% | 27.83 / 28.09 | +0.9% |

steady: mean -0.2% (3 of 4 faster; even passes +0.4%, odd -0.8%); amortized: mean -0.9% (1 of 4 faster; even -1.2%, odd -0.6%)

**serve4+share1+chk1 -> serve4+share1+chk1+seal4** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 32.41 / 32.16 | -0.8% | 27.67 / 27.33 | -1.2% |
| 1 | 32.29 / 32.95 | +2.0% | 27.70 / 27.35 | -1.3% |
| 2 | 32.79 / 32.25 | -1.6% | 27.78 / 27.11 | -2.4% |
| 3 | 32.77 / 33.00 | +0.7% | 27.83 / 27.49 | -1.2% |

steady: mean +0.1% (2 of 4 faster; even passes -1.2%, odd +1.4%); amortized: mean -1.5% (0 of 4 faster; even -1.8%, odd -1.2%)

**serve4+share1+chk1 -> serve8+share1+chk1** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | 32.41 / 32.32 | -0.3% | 27.67 / 29.81 | +7.7% |
| 1 | 32.29 / 32.22 | -0.2% | 27.70 / 29.65 | +7.0% |
| 2 | 32.79 / 31.87 | -2.8% | 27.78 / 29.51 | +6.2% |
| 3 | 32.77 / 32.45 | -1.0% | 27.83 / 29.97 | +7.7% |

steady: mean -1.1% (0 of 4 faster; even passes -1.5%, odd -0.6%); amortized: mean +7.2% (4 of 4 faster; even +7.0%, odd +7.4%)

**serve1 -> serve1+share1+chk1** (4 passes)

| pass | steady, base / test | change | amortized, base / test | change |
|---:|---:|---:|---:|---:|
| 0 | nan / nan | +nan% | 18.67 / 20.46 | +9.6% |
| 1 | nan / nan | +nan% | 18.47 / 19.87 | +7.6% |
| 2 | nan / nan | +nan% | 18.76 / 20.28 | +8.1% |
| 3 | nan / nan | +nan% | 18.77 / 20.06 | +6.9% |

steady: mean +nan% (0 of 4 faster; even passes +nan%, odd +nan%); amortized: mean +8.0% (4 of 4 faster; even +8.8%, odd +7.2%)

| served arm | requests (after the first of each stream) | sealing pass | waited for the prover | prove call | preflight | commit | forks | join | receipt write |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| serve4 | 12 | 3.979 s | 0.321 s | 4.343 s | 0.269 s | 0.244 s | 3.754 s | 0.077 s | 0.240 s |
| serve4+share1 | 12 | 3.614 s | 0.437 s | 4.083 s | 0.097 s | 0.222 s | 3.686 s | 0.078 s | 0.219 s |
| serve4+share1+chk1 | 12 | 3.593 s | 0.301 s | 3.929 s | 0.001 s | 0.213 s | 3.639 s | 0.076 s | 0.217 s |
| serve4+share1+chk1+seal6 | 12 | 3.628 s | 0.277 s | 3.940 s | 0.001 s | 0.223 s | 3.637 s | 0.078 s | 0.218 s |
| serve4+share1+chk1+seal4 | 12 | 3.769 s | 0.156 s | 3.908 s | 0.001 s | 0.217 s | 3.607 s | 0.083 s | 0.218 s |
| serve8+share1+chk1 | 28 | 3.626 s | 0.172 s | 3.971 s | 0.001 s | 0.217 s | 3.676 s | 0.077 s | 0.221 s |

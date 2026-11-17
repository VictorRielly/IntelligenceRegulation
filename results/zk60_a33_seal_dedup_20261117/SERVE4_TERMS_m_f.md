### serve4 terms, pooled over 8 runs (4 unpatched, 4 patched); medians

| term | n (A/B) | unpatched | patched | patched minus unpatched |
|---|---|---|---|---|
| cadence (s) | 24/24 | 3.693 | 3.700 | +0.007 |
| prove call (s) | 72/72 | 3.703 | 3.744 | +0.041 |
| forks (s) | 72/72 | 3.416 | 3.450 | +0.034 |
| commit (s) | 72/72 | 0.207 | 0.212 | +0.005 |
| preflight (s) | 72/72 | 0.001 | 0.001 | +0.000 |
| join (s) | 72/72 | 0.079 | 0.078 | -0.001 |
| receipt write (s) | 72/72 | 0.222 | 0.223 | +0.002 |
| prover wait (s) | 72/72 | 0.132 | 0.474 | +0.342 |
| admission (s) | 48/48 | 0.520 | 0.830 | +0.310 |
| sealing ov (s) | 72/72 | 3.409 | 3.130 | -0.280 |
| sealing solo (s) | 24/24 | 2.215 | 1.899 | -0.315 |
| result gap (s) | 72/72 | 3.714 | 3.734 | +0.021 |
| CPU s/pass (s) | 24/24 | 265.300 | 242.800 | -22.500 |
| seal-prove overlap (s) | 72/72 | 3.442 | 3.159 | -0.283 |
| seal turn after prover(q-1) start (s) | 72/72 | 0.237 | 0.239 | +0.002 |
| seal done before prover(q-1) end (s) | 72/72 | 0.132 | 0.474 | +0.342 |

### per run: cadence median, steady tok/s from cadence (128/cadence), prove call, sealing ov, admission, prover wait

| run | binary | cadence s [min-max] | prove call s | forks s | sealing ov s | admission s | prover wait s | CPU s/pass |
|---|---|---|---|---|---|---|---|---|
| m_serve4_1A | unpatched | 3.646 [3.607-3.728] | 3.680 | 3.399 | 3.408 | 0.518 | 0.148 | 266.1 |
| m_serve4_2B | patched | 3.706 [3.676-3.730] | 3.763 | 3.457 | 3.075 | 0.825 | 0.493 | 242.2 |
| m_serve4_3A | unpatched | 3.651 [3.611-3.716] | 3.720 | 3.425 | 3.393 | 0.550 | 0.189 | 264.8 |
| m_serve4_4B | patched | 3.687 [3.624-3.794] | 3.722 | 3.435 | 3.101 | 0.901 | 0.474 | 243.5 |
| f_serve4_1A | unpatched | 3.706 [3.686-3.768] | 3.700 | 3.417 | 3.442 | 0.485 | 0.121 | 265.6 |
| f_serve4_2B | patched | 3.709 [3.642-3.960] | 3.779 | 3.479 | 3.206 | 0.801 | 0.432 | 241.8 |
| f_serve4_3A | unpatched | 3.706 [3.653-3.753] | 3.706 | 3.406 | 3.394 | 0.510 | 0.132 | 264.9 |
| f_serve4_4B | patched | 3.709 [3.607-3.826] | 3.739 | 3.447 | 3.138 | 0.861 | 0.510 | 243.1 |

pairs (A-run then the B-run that follows it), per-run cadence medians:
- m_serve4_1A -> m_serve4_2B: 3.646 -> 3.706 (+0.060)
- m_serve4_3A -> m_serve4_4B: 3.651 -> 3.687 (+0.036)
- f_serve4_1A -> f_serve4_2B: 3.706 -> 3.709 (+0.003)
- f_serve4_3A -> f_serve4_4B: 3.706 -> 3.709 (+0.003)
patched slower in 4 of 4 pairs
pooled cadence per pass: unpatched median 3.693 mean 3.683 (n=24), patched median 3.700 mean 3.718 (n=24); mean difference +0.035 s, Welch se 0.017, t = 1.98

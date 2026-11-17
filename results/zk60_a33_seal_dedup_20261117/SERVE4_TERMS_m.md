### serve4 terms, pooled over 4 runs (2 unpatched, 2 patched); medians

| term | n (A/B) | unpatched | patched | patched minus unpatched |
|---|---|---|---|---|
| cadence (s) | 12/12 | 3.646 | 3.694 | +0.048 |
| prove call (s) | 36/36 | 3.707 | 3.741 | +0.034 |
| forks (s) | 36/36 | 3.419 | 3.449 | +0.030 |
| commit (s) | 36/36 | 0.206 | 0.213 | +0.007 |
| preflight (s) | 36/36 | 0.001 | 0.001 | +0.000 |
| join (s) | 36/36 | 0.078 | 0.079 | +0.001 |
| receipt write (s) | 36/36 | 0.222 | 0.227 | +0.005 |
| prover wait (s) | 36/36 | 0.170 | 0.486 | +0.317 |
| admission (s) | 24/24 | 0.550 | 0.825 | +0.275 |
| sealing ov (s) | 36/36 | 3.398 | 3.092 | -0.306 |
| sealing solo (s) | 12/12 | 2.203 | 1.906 | -0.297 |
| result gap (s) | 36/36 | 3.700 | 3.737 | +0.036 |
| CPU s/pass (s) | 12/12 | 265.400 | 242.800 | -22.600 |
| seal-prove overlap (s) | 36/36 | 3.426 | 3.139 | -0.286 |
| seal turn after prover(q-1) start (s) | 36/36 | 0.237 | 0.238 | +0.001 |
| seal done before prover(q-1) end (s) | 36/36 | 0.170 | 0.486 | +0.316 |

### per run: cadence median, steady tok/s from cadence (128/cadence), prove call, sealing ov, admission, prover wait

| run | binary | cadence s [min-max] | prove call s | forks s | sealing ov s | admission s | prover wait s | CPU s/pass |
|---|---|---|---|---|---|---|---|---|
| m_serve4_1A | unpatched | 3.646 [3.607-3.728] | 3.680 | 3.399 | 3.408 | 0.518 | 0.148 | 266.1 |
| m_serve4_2B | patched | 3.706 [3.676-3.730] | 3.763 | 3.457 | 3.075 | 0.825 | 0.493 | 242.2 |
| m_serve4_3A | unpatched | 3.651 [3.611-3.716] | 3.720 | 3.425 | 3.393 | 0.550 | 0.189 | 264.8 |
| m_serve4_4B | patched | 3.687 [3.624-3.794] | 3.722 | 3.435 | 3.101 | 0.901 | 0.474 | 243.5 |

pairs (A-run then the B-run that follows it), per-run cadence medians:
- m_serve4_1A -> m_serve4_2B: 3.646 -> 3.706 (+0.060)
- m_serve4_3A -> m_serve4_4B: 3.651 -> 3.687 (+0.036)
patched slower in 2 of 2 pairs
pooled cadence per pass: unpatched median 3.646 mean 3.662 (n=12), patched median 3.694 mean 3.704 (n=12); mean difference +0.043 s, Welch se 0.018, t = 2.31

# A11 merged tree: [fpauto] (per-fork pools, the default) against [global] (pre-A11), N = 6, 4 passes, arm order alternating (global first in passes 0 and 2)

| metric | pass 0 (global first) | pass 1 (fpauto first) | pass 2 (global first) | pass 3 (fpauto first) | mean of changes | means global / fpauto |
|---|---|---|---|---|---|---|
| proof-only wall s | -10.4% | -16.1% | -4.4% | -7.2% | **-9.5%** | 4.942 / 4.467 |
| one request from its input, wall s | -10.6% | -6.0% | -8.0% | -3.6% | **-7.1%** | 9.424 / 8.754 |
| stream steady tok/s | +17.9% | +16.6% | +19.6% | +21.9% | **+19.0%** | 19.585 / 23.300 |
| stream amortized tok/s | +14.0% | +11.5% | +14.1% | +14.2% | **+13.4%** | 17.492 / 19.840 |

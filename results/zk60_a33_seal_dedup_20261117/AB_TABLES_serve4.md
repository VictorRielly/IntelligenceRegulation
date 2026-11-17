### serve4: per run (warm passes 0-5 each; medians)

| run | binary | cadence median [min-max] | steady_toks median [min-max] | seal0 median [min-max] | seal_ov median [min-max] | wall0 median [min-max] | test | receipts-verified lines |
|---|---|---|---|---|---|---|---|---|
| serve4_1A | unpatched | 3.637 [3.615-3.689] | 35.190 [34.690-35.410] | 2.197 [2.163-2.218] | 3.376 [3.308-3.509] | 6.389 [6.257-6.561] | ok | 2 (n=6) |
| serve4_2B | patched | 3.702 [3.630-3.756] | 34.575 [34.080-35.260] | 1.906 [1.754-1.983] | 3.030 [2.965-3.212] | 6.178 [5.956-6.247] | ok | 2 (n=6) |
| serve4_3A | unpatched | 3.768 [3.668-3.898] | 33.975 [32.840-34.890] | 2.240 [2.169-3.002] | 3.494 [3.414-3.666] | 6.557 [6.457-7.402] | ok | 2 (n=6) |
| serve4_4B | patched | 3.739 [3.634-3.803] | 34.235 [33.650-35.230] | 1.979 [1.767-2.103] | 3.145 [3.020-3.203] | 6.159 [6.056-6.343] | ok | 2 (n=6) |

### serve4: pooled over the runs (n warm passes per binary)

| metric | n | unpatched median [p25-p75] | patched median [p25-p75] | patched minus unpatched (medians) |
|---|---|---|---|---|
| cadence | 12/12 | 3.689 [3.646-3.757] | 3.732 [3.665-3.750] | +0.044 |
| steady_toks | 12/12 | 34.695 [34.072-35.110] | 34.295 [34.133-34.925] | -0.400 |
| seal0 | 12/12 | 2.197 [2.181-2.232] | 1.911 [1.895-1.998] | -0.286 |
| seal_ov | 12/12 | 3.442 [3.379-3.507] | 3.113 [3.010-3.166] | -0.329 |
| wall0 | 12/12 | 6.480 [6.407-6.574] | 6.172 [6.121-6.226] | -0.308 |

per-run-median pairs, A-run median minus the next B-run median (cadence):
- serve4_1A -> serve4_2B: 3.637 -> 3.702 (+0.065)
- serve4_3A -> serve4_4B: 3.768 -> 3.739 (-0.029)

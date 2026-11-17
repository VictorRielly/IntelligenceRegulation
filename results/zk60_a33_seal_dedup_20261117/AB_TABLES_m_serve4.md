### serve4: per run (warm passes 0-5 each; medians)

| run | binary | cadence median [min-max] | steady_toks median [min-max] | seal0 median [min-max] | seal_ov median [min-max] | wall0 median [min-max] | test | receipts-verified lines |
|---|---|---|---|---|---|---|---|---|
| m_serve4_1A | unpatched | 3.646 [3.607-3.728] | 35.110 [34.330-35.480] | 2.188 [2.063-2.243] | 3.411 [3.341-3.447] | 6.421 [6.280-6.574] | ok | 2 (n=6) |
| m_serve4_2B | patched | 3.706 [3.676-3.730] | 34.545 [34.320-34.820] | 1.930 [1.844-1.961] | 3.094 [3.008-3.192] | 6.150 [5.989-6.289] | ok | 2 (n=6) |
| m_serve4_3A | unpatched | 3.651 [3.611-3.716] | 35.060 [34.450-35.450] | 2.231 [2.109-2.363] | 3.418 [3.338-3.450] | 6.468 [6.360-6.641] | ok | 2 (n=6) |
| m_serve4_4B | patched | 3.687 [3.624-3.794] | 34.715 [33.740-35.320] | 1.878 [1.769-1.952] | 3.083 [3.026-3.183] | 6.152 [6.001-6.257] | ok | 2 (n=6) |

### serve4: pooled over the runs (n warm passes per binary)

| metric | n | unpatched median [p25-p75] | patched median [p25-p75] | patched minus unpatched (medians) |
|---|---|---|---|---|
| cadence | 12/12 | 3.646 [3.624-3.710] | 3.694 [3.680-3.730] | +0.048 |
| steady_toks | 12/12 | 35.110 [34.502-35.318] | 34.650 [34.320-34.790] | -0.460 |
| seal0 | 12/12 | 2.203 [2.141-2.241] | 1.907 [1.845-1.939] | -0.296 |
| seal_ov | 12/12 | 3.416 [3.376-3.431] | 3.083 [3.044-3.128] | -0.333 |
| wall0 | 12/12 | 6.464 [6.363-6.546] | 6.150 [6.069-6.213] | -0.314 |

per-run-median pairs, A-run median minus the next B-run median (cadence):
- m_serve4_1A -> m_serve4_2B: 3.646 -> 3.706 (+0.060)
- m_serve4_3A -> m_serve4_4B: 3.651 -> 3.687 (+0.036)

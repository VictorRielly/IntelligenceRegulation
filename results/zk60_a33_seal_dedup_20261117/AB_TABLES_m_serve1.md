### serve1: per run (warm passes 0-5 each; medians)

| run | binary | seal0 median [min-max] | wall0 median [min-max] | test | receipts-verified lines |
|---|---|---|---|---|---|
| m_serve1_1A | unpatched | 2.173 [2.111-2.210] | 6.116 [5.989-6.233] | ok | 2 (n=6) |
| m_serve1_2B | patched | 1.917 [1.840-1.965] | 5.896 [5.771-5.985] | ok | 2 (n=6) |
| m_serve1_3A | unpatched | 2.188 [2.169-2.305] | 6.200 [6.035-6.281] | ok | 2 (n=6) |
| m_serve1_4B | patched | 1.903 [1.883-1.972] | 5.888 [5.771-5.977] | ok | 2 (n=6) |

### serve1: pooled over the runs (n warm passes per binary)

| metric | n | unpatched median [p25-p75] | patched median [p25-p75] | patched minus unpatched (medians) |
|---|---|---|---|---|
| seal0 | 12/12 | 2.181 [2.172-2.195] | 1.906 [1.893-1.934] | -0.275 |
| wall0 | 12/12 | 6.143 [6.055-6.225] | 5.888 [5.818-5.940] | -0.255 |

per-run-median pairs, A-run median minus the next B-run median (seal0):
- m_serve1_1A -> m_serve1_2B: 2.173 -> 1.917 (-0.257)
- m_serve1_3A -> m_serve1_4B: 2.188 -> 1.903 (-0.285)

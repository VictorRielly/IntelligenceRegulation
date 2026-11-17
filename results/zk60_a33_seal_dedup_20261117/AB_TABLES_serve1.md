### serve1: per run (warm passes 0-5 each; medians)

| run | binary | seal0 median [min-max] | wall0 median [min-max] | test | receipts-verified lines |
|---|---|---|---|---|---|
| serve1_1A | unpatched | 2.179 [2.143-2.243] | 6.127 [6.019-6.251] | ok | 2 (n=6) |
| serve1_2B | patched | 1.926 [1.832-1.944] | 5.877 [5.765-6.000] | ok | 2 (n=6) |
| serve1_3A | unpatched | 2.269 [2.148-2.398] | 6.357 [6.100-6.587] | ok | 2 (n=6) |
| serve1_4B | patched | 1.916 [1.840-1.996] | 5.847 [5.633-6.113] | ok | 2 (n=6) |

### serve1: pooled over the runs (n warm passes per binary)

| metric | n | unpatched median [p25-p75] | patched median [p25-p75] | patched minus unpatched (medians) |
|---|---|---|---|---|
| seal0 | 12/12 | 2.188 [2.161-2.266] | 1.927 [1.887-1.933] | -0.262 |
| wall0 | 12/12 | 6.213 [6.092-6.333] | 5.878 [5.780-5.933] | -0.335 |

per-run-median pairs, A-run median minus the next B-run median (seal0):
- serve1_1A -> serve1_2B: 2.179 -> 1.926 (-0.253)
- serve1_3A -> serve1_4B: 2.269 -> 1.916 (-0.353)

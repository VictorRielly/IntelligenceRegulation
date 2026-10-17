## /home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5/stack-pg_rot1_b4_T128-ho00-cpu/prove.log

22 block phase tables, sum of block walls 186.4 s; prove_run 187.304 s (witness 16.712 s, block loads 1.963 s); gpu: gpu: off (built without --features gpu-cuda)

| half | seconds | % |
|---|---|---|
| commit | 61.28 | 32.9% |
| residual | 32.74 | 17.6% |
| attention | 31.44 | 16.9% |
| feed-forward | 23.95 | 12.8% |
| run (witness, boundary) | 19.70 | 10.6% |
| openings | 10.31 | 5.5% |
| endpoints | 2.47 | 1.3% |
| norm | 2.11 | 1.1% |
| lookup-table | 1.94 | 1.0% |

| phase (summed over blocks) | seconds | % | counted work | ns per unit | bytes | GB/s |
|---|---|---|---|---|---|---|
| slot 14 03 D zero-check (hosts 12, 13D) | 32.74 | 17.6% | 680,525,824 elem-terms | 48.114 | 10,888,413,184 | 0.333 |
| H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 22.89 | 12.3% | 786,497,536 words | 29.099 | 25,167,921,152 | 1.100 |
| slot 18 14 F zero-check (hosts 13G, 13U) | 22.30 | 12.0% | 968,884,224 elem-terms | 23.016 | 15,502,147,584 | 0.695 |
| A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 21.08 | 11.3% | 718,372,864 words | 29.344 | 22,987,931,648 | 1.091 |
| run: block load + witness (the source) | 17.79 | 9.5% | 21 block | 847095238.095 | 0 | 0.000 |
| slot 17 06 softmax zero-check (hosts 07, 10) | 13.48 | 7.2% | 576,716,800 elem-terms | 23.379 | 9,227,468,800 | 0.684 |
| slot 15 04 Q zero-check (hosts 09Q, 11) | 9.47 | 5.1% | 230,686,720 elem-terms | 41.034 | 3,690,987,520 | 0.390 |
| H: LogUp helper inverses (six lookup domains) | 7.48 | 4.0% | 637,992,960 words | 11.727 | 10,207,887,360 | 1.364 |
| open A (schedule audit + pcs::open_zk) | 5.94 | 3.2% | 718,372,864 words | 8.271 | 5,746,982,912 | 0.967 |
| slot 16 05 KV zero-check (hosts 09K, 09V) | 5.07 | 2.7% | 25,952,256 elem-terms | 195.166 | 415,236,096 | 0.082 |
| open H (schedule audit + pcs::open_zk) | 4.23 | 2.3% | 786,497,536 words | 5.374 | 6,291,980,288 | 1.489 |
| A: allocate + witness planes -> committed rows | 4.16 | 2.2% | 718,372,864 words | 5.788 | 5,746,982,912 | 1.382 |
| slot 19 TAB table helper zero-check | 1.78 | 1.0% | 7,929,856 elem-terms | 224.720 | 126,877,696 | 0.071 |
| A: mask + proximity rows (fresh randomness) | 1.77 | 1.0% | 87,228,416 words | 20.326 | 0 | 0.000 |
| slot 04 07 masked row sums + selector (private) | 1.68 | 0.9% | 92,274,688 elem-terms | 18.152 | 1,476,395,008 | 0.881 |
| H: exp + activation helper inverses | 1.53 | 0.8% | 34,603,008 words | 44.187 | 553,648,128 | 0.362 |
| slot 21 IO-in endpoint equality | 1.32 | 0.7% | 34,603,008 elem-terms | 38.031 | 553,648,128 | 0.421 |
| slot 22 IO-out endpoint equality | 1.15 | 0.6% | 34,603,008 elem-terms | 33.321 | 553,648,128 | 0.480 |
| run: boundary B_k commitment | 1.01 | 0.5% | 5,505,024 words | 183.105 | 44,040,192 | 0.044 |
| run: witness hand-over (the last block builds it here) | 0.90 | 0.5% | 22 block | 40818181.818 | 0 | 0.000 |
| H: mask rows + the zero-sum rows | 0.80 | 0.4% | 36,044,800 words | 22.195 | 0 | 0.000 |
| slot 01 01m SS row sums norm_m (private) | 0.73 | 0.4% | 23,068,672 elem-terms | 31.428 | 369,098,752 | 0.509 |
| slot 00 01 SS row sums norm_a (private) | 0.71 | 0.4% | 23,068,672 elem-terms | 30.908 | 369,098,752 | 0.518 |
| slot 03 08 limb zero-check | 0.66 | 0.4% | 3,604,480 elem-terms | 182.551 | 57,671,680 | 0.088 |


## /home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5/stack-llama3_8b_pg_rot1_T32-ho00-cpu/prove.log

32 block phase tables, sum of block walls 240.7 s; prove_run 241.923 s (witness 30.453 s, block loads 24.15 s); gpu: gpu: off (built without --features gpu-cuda)

| half | seconds | % |
|---|---|---|
| run (witness, boundary) | 56.40 | 23.4% |
| commit | 52.17 | 21.7% |
| residual | 44.01 | 18.3% |
| feed-forward | 35.61 | 14.8% |
| attention | 34.81 | 14.5% |
| openings | 10.01 | 4.2% |
| endpoints | 3.16 | 1.3% |
| norm | 2.67 | 1.1% |
| lookup-table | 1.31 | 0.5% |

| phase (summed over blocks) | seconds | % | counted work | ns per unit | bytes | GB/s |
|---|---|---|---|---|---|---|
| run: block load + witness (the source) | 53.03 | 22.0% | 31 block | 1710483870.968 | 0 | 0.000 |
| slot 14 03 D zero-check (hosts 12, 13D) | 44.01 | 18.3% | 494,927,872 elem-terms | 88.918 | 7,918,845,952 | 0.180 |
| slot 18 14 F zero-check (hosts 13G, 13U) | 28.87 | 12.0% | 704,643,072 elem-terms | 40.974 | 11,274,289,152 | 0.390 |
| H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 16.79 | 7.0% | 460,849,152 words | 36.422 | 14,747,172,864 | 0.879 |
| A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 15.52 | 6.4% | 444,858,368 words | 34.879 | 14,235,467,776 | 0.917 |
| slot 15 04 Q zero-check (hosts 09Q, 11) | 14.10 | 5.9% | 167,772,160 elem-terms | 84.049 | 2,684,354,560 | 0.190 |
| H: LogUp helper inverses (six lookup domains) | 10.44 | 4.3% | 374,865,920 words | 27.845 | 5,997,854,720 | 0.575 |
| slot 17 06 softmax zero-check (hosts 07, 10) | 9.80 | 4.1% | 52,428,800 elem-terms | 186.863 | 838,860,800 | 0.086 |
| slot 16 05 KV zero-check (hosts 09K, 09V) | 7.66 | 3.2% | 37,748,736 elem-terms | 202.841 | 603,979,776 | 0.079 |
| open A (schedule audit + pcs::open_zk) | 5.74 | 2.4% | 444,858,368 words | 12.894 | 3,558,866,944 | 0.620 |
| open H (schedule audit + pcs::open_zk) | 3.94 | 1.6% | 460,849,152 words | 8.556 | 3,686,793,216 | 0.935 |
| A: allocate + witness planes -> committed rows | 3.57 | 1.5% | 444,858,368 words | 8.023 | 3,558,866,944 | 0.997 |
| slot 13 13D down matmul (private) | 2.32 | 1.0% | 2,097,152 elem-terms | 1108.646 | 33,554,432 | 0.014 |
| slot 12 13U up matmul (private) | 2.24 | 0.9% | 524,288 elem-terms | 4266.739 | 8,388,608 | 0.004 |
| slot 11 13G gate matmul (private) | 2.18 | 0.9% | 524,288 elem-terms | 4150.391 | 8,388,608 | 0.004 |
| run: witness hand-over (the last block builds it here) | 1.94 | 0.8% | 32 block | 60718750.000 | 0 | 0.000 |
| A: mask + proximity rows (fresh randomness) | 1.88 | 0.8% | 63,438,848 words | 29.572 | 0 | 0.000 |
| slot 22 IO-out endpoint equality | 1.59 | 0.7% | 25,165,824 elem-terms | 63.300 | 402,653,184 | 0.253 |
| slot 21 IO-in endpoint equality | 1.56 | 0.6% | 25,165,824 elem-terms | 62.148 | 402,653,184 | 0.257 |
| run: boundary B_k commitment | 1.43 | 0.6% | 4,063,232 words | 351.444 | 32,505,856 | 0.023 |
| H: exp + activation helper inverses | 1.21 | 0.5% | 17,825,792 words | 67.599 | 285,212,672 | 0.237 |
| slot 19 TAB table helper zero-check | 1.15 | 0.5% | 5,767,168 elem-terms | 199.058 | 92,274,688 | 0.080 |
| M: mask commit (zk::mask_commit, ONE call) | 1.08 | 0.5% | 1,600 rows | 676875.000 | 0 | 0.000 |
| slot 01 01m SS row sums norm_m (private) | 0.99 | 0.4% | 16,777,216 elem-terms | 59.187 | 268,435,456 | 0.270 |


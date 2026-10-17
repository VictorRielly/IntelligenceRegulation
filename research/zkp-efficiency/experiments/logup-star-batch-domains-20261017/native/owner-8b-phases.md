## /home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5/stack-llama3_8b_pg_rot1_T32-ho00-cpu-cli3/prove.log

32 block phase tables, sum of block walls 155.2 s; prove_run 156.143 s (witness 21.376 s, block loads 15.993 s); gpu: gpu: off (built without --features gpu-cuda)

| half | seconds | % |
|---|---|---|
| run (witness, boundary) | 38.35 | 24.7% |
| commit | 33.50 | 21.6% |
| residual | 28.79 | 18.5% |
| attention | 22.46 | 14.5% |
| feed-forward | 21.04 | 13.6% |
| openings | 5.97 | 3.8% |
| endpoints | 2.47 | 1.6% |
| norm | 1.43 | 0.9% |
| lookup-table | 0.91 | 0.6% |

| phase (summed over blocks) | seconds | % | counted work | ns per unit | bytes | GB/s |
|---|---|---|---|---|---|---|
| run: block load + witness (the source) | 36.42 | 23.5% | 31 block | 1174935483.871 | 0 | 0.000 |
| slot 14 03 D zero-check (hosts 12, 13D) | 28.79 | 18.5% | 494,927,872 elem-terms | 58.168 | 7,918,845,952 | 0.275 |
| slot 18 14 F zero-check (hosts 13G, 13U) | 16.64 | 10.7% | 704,643,072 elem-terms | 23.609 | 11,274,289,152 | 0.678 |
| H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 11.75 | 7.6% | 460,849,152 words | 25.492 | 14,747,172,864 | 1.255 |
| A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 11.03 | 7.1% | 444,858,368 words | 24.801 | 14,235,467,776 | 1.290 |
| slot 15 04 Q zero-check (hosts 09Q, 11) | 8.25 | 5.3% | 167,772,160 elem-terms | 49.150 | 2,684,354,560 | 0.326 |
| slot 17 06 softmax zero-check (hosts 07, 10) | 7.14 | 4.6% | 52,428,800 elem-terms | 136.261 | 838,860,800 | 0.117 |
| slot 16 05 KV zero-check (hosts 09K, 09V) | 5.23 | 3.4% | 37,748,736 elem-terms | 138.468 | 603,979,776 | 0.116 |
| H: LogUp helper inverses (six lookup domains) | 4.78 | 3.1% | 374,865,920 words | 12.762 | 5,997,854,720 | 1.254 |
| open A (schedule audit + pcs::open_zk) | 3.55 | 2.3% | 444,858,368 words | 7.982 | 3,558,866,944 | 1.002 |
| open H (schedule audit + pcs::open_zk) | 2.23 | 1.4% | 460,849,152 words | 4.850 | 3,686,793,216 | 1.650 |
| A: allocate + witness planes -> committed rows | 2.23 | 1.4% | 444,858,368 words | 5.011 | 3,558,866,944 | 1.597 |
| slot 13 13D down matmul (private) | 1.53 | 1.0% | 2,097,152 elem-terms | 730.038 | 33,554,432 | 0.022 |
| slot 12 13U up matmul (private) | 1.46 | 0.9% | 524,288 elem-terms | 2790.451 | 8,388,608 | 0.006 |
| slot 11 13G gate matmul (private) | 1.41 | 0.9% | 524,288 elem-terms | 2683.640 | 8,388,608 | 0.006 |
| slot 21 IO-in endpoint equality | 1.25 | 0.8% | 25,165,824 elem-terms | 49.829 | 402,653,184 | 0.321 |
| slot 22 IO-out endpoint equality | 1.21 | 0.8% | 25,165,824 elem-terms | 48.161 | 402,653,184 | 0.332 |
| A: mask + proximity rows (fresh randomness) | 1.17 | 0.8% | 63,438,848 words | 18.474 | 0 | 0.000 |
| run: witness hand-over (the last block builds it here) | 1.11 | 0.7% | 32 block | 34718750.000 | 0 | 0.000 |
| run: boundary B_k commitment | 0.82 | 0.5% | 4,063,232 words | 200.579 | 32,505,856 | 0.040 |
| slot 19 TAB table helper zero-check | 0.81 | 0.5% | 5,767,168 elem-terms | 139.757 | 92,274,688 | 0.114 |
| H: exp + activation helper inverses | 0.74 | 0.5% | 17,825,792 words | 41.569 | 285,212,672 | 0.385 |
| M: mask commit (zk::mask_commit, ONE call) | 0.69 | 0.4% | 1,600 rows | 428750.000 | 0 | 0.000 |
| H: mask rows + the zero-sum rows | 0.52 | 0.3% | 26,214,400 words | 19.684 | 0 | 0.000 |


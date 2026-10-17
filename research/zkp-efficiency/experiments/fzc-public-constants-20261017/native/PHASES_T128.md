## /home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r4/phases-T128-cpu/prove.log

22 block phase tables, sum of block walls 152.2 s; prove_run 153.072 s, witness 13.236 s, gpu: gpu: off (built without --features gpu-cuda)

| half | seconds | % of block walls |
|---|---|---|
| commit | 64.21 | 42.2% |
| residual | 27.50 | 18.1% |
| attention | 26.81 | 17.6% |
| feed-forward | 19.02 | 12.5% |
| openings | 8.89 | 5.8% |
| endpoints | 1.97 | 1.3% |
| norm | 1.75 | 1.1% |
| lookup-table | 1.69 | 1.1% |

| phase (summed over blocks) | seconds | % |
|---|---|---|
| slot 14 03 D zero-check (hosts 12, 13D) | 27.50 | 18.1% |
| H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 18.13 | 11.9% |
| A: allocate + witness planes -> committed rows | 17.67 | 11.6% |
| slot 18 14 F zero-check (hosts 13G, 13U) | 17.63 | 11.6% |
| A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 16.56 | 10.9% |
| slot 17 06 softmax zero-check (hosts 07, 10) | 11.53 | 7.6% |
| slot 15 04 Q zero-check (hosts 09Q, 11) | 7.95 | 5.2% |
| H: LogUp helper inverses (six lookup domains) | 6.91 | 4.5% |
| open A (schedule audit + pcs::open_zk) | 5.15 | 3.4% |
| slot 16 05 KV zero-check (hosts 09K, 09V) | 4.41 | 2.9% |
| open H (schedule audit + pcs::open_zk) | 3.60 | 2.4% |
| A: mask + proximity rows (fresh randomness) | 1.61 | 1.1% |
| slot 19 TAB table helper zero-check | 1.55 | 1.0% |
| H: exp + activation helper inverses | 1.39 | 0.9% |
| slot 04 07 masked row sums + selector (private) | 1.34 | 0.9% |
| slot 21 IO-in endpoint equality | 1.05 | 0.7% |
| slot 22 IO-out endpoint equality | 0.92 | 0.6% |
| H: mask rows + the zero-sum rows | 0.69 | 0.5% |
| slot 01 01m SS row sums norm_m (private) | 0.61 | 0.4% |
| slot 00 01 SS row sums norm_a (private) | 0.60 | 0.4% |
| slot 13 13D down matmul (private) | 0.54 | 0.4% |
| slot 03 08 limb zero-check | 0.53 | 0.4% |
| A: lookup values + the byte histogram | 0.52 | 0.3% |
| M: mask commit (zk::mask_commit, ONE call) | 0.49 | 0.3% |
| slot 11 13G gate matmul (private) | 0.44 | 0.3% |

| slot step (summed over blocks) | seconds |
|---|---|
| slot 14 masked sumcheck (zk.rs, shared) | 21.12 |
| slot 18 masked sumcheck (zk.rs, shared) | 14.62 |
| slot 17 masked sumcheck (zk.rs, shared) | 8.83 |
| slot 15 masked sumcheck (zk.rs, shared) | 5.90 |
| slot 14 extension rounds (mask_eval + zk.rs) | 5.86 |
| slot 16 masked sumcheck (zk.rs, shared) | 2.83 |
| slot 17 extension rounds (mask_eval + zk.rs) | 2.10 |
| slot 18 extension rounds (mask_eval + zk.rs) | 1.90 |
| slot 15 extension rounds (mask_eval + zk.rs) | 1.65 |
| slot 16 extension rounds (mask_eval + zk.rs) | 1.43 |
| slot 18 tables: build (argument.rs) | 0.97 |
| slot 04 masked sumcheck (zk.rs, shared) | 0.93 |
| slot 19 masked sumcheck (zk.rs, shared) | 0.75 |
| slot 19 extension rounds (mask_eval + zk.rs) | 0.69 |
| slot 21 masked sumcheck (zk.rs, shared) | 0.60 |
| slot 22 masked sumcheck (zk.rs, shared) | 0.54 |
| slot 17 tables: build (argument.rs) | 0.53 |
| slot 14 tables: build (argument.rs) | 0.48 |
| slot 00 masked sumcheck (zk.rs, shared) | 0.41 |
| slot 01 masked sumcheck (zk.rs, shared) | 0.40 |

## /home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r4/phases-T128-gpu/prove.log

22 block phase tables, sum of block walls 134.8 s; prove_run 135.809 s, witness 15.899 s, gpu: gpu: ON — NVIDIA GeForce RTX 4070 Laptop GPU (sm_89, 36 SMs, 8.6 GB)

| half | seconds | % of block walls |
|---|---|---|
| commit | 43.62 | 32.3% |
| attention | 26.61 | 19.7% |
| residual | 25.35 | 18.8% |
| feed-forward | 21.11 | 15.7% |
| openings | 12.31 | 9.1% |
| norm | 2.06 | 1.5% |
| endpoints | 1.94 | 1.4% |
| lookup-table | 1.45 | 1.1% |

| phase (summed over blocks) | seconds | % |
|---|---|---|
| slot 14 03 D zero-check (hosts 12, 13D) | 25.35 | 18.8% |
| A: allocate + witness planes -> committed rows | 21.19 | 15.7% |
| slot 18 14 F zero-check (hosts 13G, 13U) | 19.48 | 14.5% |
| slot 17 06 softmax zero-check (hosts 07, 10) | 11.83 | 8.8% |
| open A (schedule audit + pcs::open_zk) | 9.18 | 6.8% |
| H: LogUp helper inverses (six lookup domains) | 8.84 | 6.6% |
| slot 15 04 Q zero-check (hosts 09Q, 11) | 7.95 | 5.9% |
| A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 4.00 | 3.0% |
| slot 16 05 KV zero-check (hosts 09K, 09V) | 3.86 | 2.9% |
| H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 3.62 | 2.7% |
| open H (schedule audit + pcs::open_zk) | 2.99 | 2.2% |
| A: mask + proximity rows (fresh randomness) | 1.88 | 1.4% |
| H: exp + activation helper inverses | 1.77 | 1.3% |
| slot 04 07 masked row sums + selector (private) | 1.42 | 1.1% |
| slot 19 TAB table helper zero-check | 1.31 | 1.0% |
| slot 21 IO-in endpoint equality | 1.03 | 0.8% |
| slot 22 IO-out endpoint equality | 0.91 | 0.7% |
| H: mask rows + the zero-sum rows | 0.79 | 0.6% |
| slot 01 01m SS row sums norm_m (private) | 0.75 | 0.6% |
| A: lookup values + the byte histogram | 0.75 | 0.6% |
| slot 00 01 SS row sums norm_a (private) | 0.74 | 0.6% |
| slot 13 13D down matmul (private) | 0.68 | 0.5% |
| slot 03 08 limb zero-check | 0.56 | 0.4% |
| M: mask commit (zk::mask_commit, ONE call) | 0.49 | 0.4% |
| slot 12 13U up matmul (private) | 0.48 | 0.4% |

| slot step (summed over blocks) | seconds |
|---|---|
| slot 14 masked sumcheck (zk.rs, shared) | 19.86 |
| slot 18 masked sumcheck (zk.rs, shared) | 16.46 |
| slot 17 masked sumcheck (zk.rs, shared) | 9.35 |
| slot 15 masked sumcheck (zk.rs, shared) | 6.13 |
| slot 14 extension rounds (mask_eval + zk.rs) | 4.87 |
| slot 16 masked sumcheck (zk.rs, shared) | 2.49 |
| slot 17 extension rounds (mask_eval + zk.rs) | 1.75 |
| slot 18 extension rounds (mask_eval + zk.rs) | 1.58 |
| slot 15 extension rounds (mask_eval + zk.rs) | 1.39 |
| slot 18 tables: build (argument.rs) | 1.30 |
| slot 16 extension rounds (mask_eval + zk.rs) | 1.19 |
| slot 04 masked sumcheck (zk.rs, shared) | 1.01 |
| slot 19 masked sumcheck (zk.rs, shared) | 0.68 |
| slot 17 tables: build (argument.rs) | 0.67 |
| slot 21 masked sumcheck (zk.rs, shared) | 0.62 |
| slot 14 tables: build (argument.rs) | 0.58 |
| slot 00 masked sumcheck (zk.rs, shared) | 0.56 |
| slot 19 extension rounds (mask_eval + zk.rs) | 0.55 |
| slot 01 masked sumcheck (zk.rs, shared) | 0.54 |
| slot 22 masked sumcheck (zk.rs, shared) | 0.53 |


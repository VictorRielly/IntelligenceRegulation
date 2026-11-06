# A18 phase clock, ms per block (mean over passes), N = 6 (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2b8233000ecbf9ef/results/zk60_effplan_20261105/a18/raw/s5_d55_phases.log)

| phase | a18old+phases | a18old+tabinv1+phases | a18old+tabinv1+tabpar1+phases | a18old+pubtab1+phases | a18old+registry1+phases |
|---|---:|---:|---:|---:|---:|
| A: allocate + witness planes -> committed rows | 23.12 | 23.10 (-0.02) | 22.16 (-0.96) | 24.18 (+1.06) | 24.97 (+1.85) |
| A: lookup values + the byte histogram | 14.93 | 15.06 (+0.14) | 15.64 (+0.72) | 15.47 (+0.54) | 15.08 (+0.15) |
| A: exp/act indices + their two histograms | 2.97 | 2.92 (-0.04) | 2.93 (-0.04) | 3.07 (+0.10) | 2.81 (-0.16) |
| A: mask + proximity rows (fresh randomness) | 11.48 | 11.27 (-0.21) | 11.62 (+0.13) | 11.22 (-0.26) | 11.16 (-0.32) |
| A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 65.63 | 65.89 (+0.26) | 69.55 (+3.92) | 66.35 (+0.72) | 66.69 (+1.06) |
| M: mask commit (zk::mask_commit, ONE call) | 3.81 | 3.83 (+0.02) | 3.83 (+0.02) | 3.84 (+0.03) | 3.90 (+0.09) |
| H: LogUp helper inverses (six lookup domains) | 23.35 | 22.88 (-0.47) | 22.27 (-1.08) | 23.21 (-0.14) | 22.57 (-0.78) |
| H: exp + activation helper inverses | 12.38 | 12.32 (-0.06) | 12.38 (-0.00) | 12.10 (-0.28) | 12.29 (-0.10) |
| H: release the four witness buffers (S2 drops) | 5.44 | 4.57 (-0.87) | 4.79 (-0.65) | 4.96 (-0.48) | 4.59 (-0.84) |
| H: the three table helpers | 4.65 | 0.78 (-3.87) | 0.73 (-3.92) | 4.62 (-0.03) | 4.66 (+0.01) |
| H: mask rows + the zero-sum rows | 4.73 | 4.74 (+0.01) | 4.72 (-0.00) | 4.75 (+0.02) | 4.75 (+0.02) |
| H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call) | 42.74 | 44.01 (+1.26) | 47.03 (+4.29) | 43.68 (+0.93) | 43.95 (+1.21) |
| slot 00 01 SS row sums norm_a (private) | 17.57 | 18.57 (+1.00) | 19.08 (+1.51) | 17.58 (+0.01) | 17.97 (+0.41) |
| slot 01 01m SS row sums norm_m (private) | 12.04 | 12.07 (+0.03) | 11.87 (-0.17) | 11.29 (-0.75) | 11.87 (-0.17) |
| slot 02 02 norm squares zero-check (hosts 01, 01m) | 0.57 | 0.57 (-0.00) | 0.57 (+0.00) | 0.56 (-0.01) | 0.35 (-0.22) |
| slot 03 08 limb zero-check | 6.76 | 6.62 (-0.14) | 6.28 (-0.48) | 7.93 (+1.17) | 6.96 (+0.20) |
| slot 04 07 masked row sums + selector (private) | 10.96 | 11.82 (+0.87) | 9.21 (-1.75) | 9.76 (-1.20) | 12.21 (+1.25) |
| slot 05 09Q matmul (private) | 2.38 | 2.39 (+0.02) | 2.38 (+0.00) | 2.46 (+0.08) | 2.24 (-0.14) |
| slot 06 09K matmul (private) | 1.50 | 1.53 (+0.03) | 1.46 (-0.04) | 1.63 (+0.13) | 1.28 (-0.22) |
| slot 07 09V matmul (private) | 1.51 | 1.50 (-0.01) | 1.52 (+0.01) | 1.59 (+0.08) | 1.27 (-0.24) |
| slot 08 10 score matmul (private, bilinear) | 1.41 | 1.22 (-0.19) | 1.27 (-0.13) | 1.29 (-0.12) | 1.05 (-0.35) |
| slot 09 11 PV matmul (private, bilinear) | 1.23 | 1.20 (-0.03) | 1.25 (+0.02) | 1.23 (+0.00) | 0.98 (-0.25) |
| slot 10 12 Wo matmul (private) | 2.45 | 2.50 (+0.05) | 2.62 (+0.17) | 2.55 (+0.10) | 2.33 (-0.12) |
| slot 11 13G gate matmul (private) | 5.41 | 5.30 (-0.10) | 5.56 (+0.15) | 5.38 (-0.02) | 5.19 (-0.22) |
| slot 12 13U up matmul (private) | 5.33 | 5.38 (+0.05) | 5.39 (+0.05) | 5.29 (-0.04) | 5.14 (-0.20) |
| slot 13 13D down matmul (private) | 8.88 | 8.86 (-0.02) | 8.89 (+0.02) | 8.27 (-0.61) | 8.63 (-0.25) |
| slot 14 03 D zero-check (hosts 12, 13D) | 47.37 | 49.83 (+2.45) | 51.36 (+3.99) | 50.69 (+3.32) | 47.81 (+0.44) |
| slot 15 04 Q zero-check (hosts 09Q, 11) | 31.43 | 29.89 (-1.54) | 31.01 (-0.42) | 29.81 (-1.62) | 30.44 (-0.99) |
| slot 16 05 KV zero-check (hosts 09K, 09V) | 15.35 | 12.47 (-2.88) | 13.05 (-2.29) | 12.89 (-2.45) | 13.38 (-1.97) |
| slot 17 06 softmax zero-check (hosts 07, 10) | 31.20 | 30.82 (-0.38) | 31.64 (+0.45) | 29.91 (-1.28) | 28.27 (-2.92) |
| slot 18 14 F zero-check (hosts 13G, 13U) | 99.70 | 96.92 (-2.79) | 101.01 (+1.30) | 102.63 (+2.93) | 96.47 (-3.23) |
| slot 19 TAB table helper zero-check | 37.59 | 35.20 (-2.38) | 39.50 (+1.92) | 38.19 (+0.60) | 32.57 (-5.02) |
| slot 20 ZS zero-sum row | 1.72 | 1.43 (-0.29) | 1.56 (-0.16) | 1.64 (-0.08) | 1.05 (-0.67) |
| slot 21 IO-in endpoint equality | 6.96 | 6.02 (-0.94) | 6.02 (-0.94) | 5.33 (-1.63) | 6.87 (-0.09) |
| slot 22 IO-out endpoint equality | 2.74 | 4.20 (+1.46) | 2.71 (-0.03) | 2.66 (-0.08) | 4.05 (+1.31) |
| open M (zk::mask_open, ONE call) | 3.75 | 3.82 (+0.07) | 3.79 (+0.04) | 3.79 (+0.04) | 3.87 (+0.12) |
| open A (schedule audit + pcs::open_zk) | 27.76 | 29.66 (+1.91) | 27.17 (-0.59) | 28.11 (+0.35) | 31.71 (+3.95) |
| open H (schedule audit + pcs::open_zk) | 29.21 | 30.04 (+0.82) | 28.45 (-0.76) | 29.24 (+0.03) | 29.77 (+0.56) |
| ALL PHASES | 628.00 | 621.19 (-6.81) | 632.28 (+4.28) | 629.18 (+1.19) | 621.15 (-6.84) |

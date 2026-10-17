| rung | mode | total wall (s) | sealing (s) | witness (s) [per block] | proofs only (s) | in-proc verify (s) | fresh verify (s) | receipt (B) | peak RSS (GiB) | peak VRAM (MiB) | positions/s total | positions/s proofs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T32 (r2 ref) | CPU r2 | 529.0 | 230.648 | 222.999 [10.136] | 59.6 | 4.872 | 4.886 | 250,855,088 | 2.15 | - | 0.06 | 0.537 |
| T32 (r2 ref) | GPU r2 | 545.2 | 229.941 | 227.97 [10.362] | 68.1 | 4.901 | 4.979 | 250,855,088 | 1.99 | 1281 | 0.059 | 0.47 |
| T32  | CPU | 56.2 | 0.022 | 2.683 [0.122] | 40.2 | 3.015 | 3.152 | 250,855,088 | 2.15 | - | 0.569 | 0.797 |
| T32  | GPU | 60.8 | 0.023 | 2.774 [0.126] | 40.8 | 3.376 | 3.431 | 250,855,088 | 1.98 | 1281 | 0.527 | 0.785 |
| T64  | CPU | 84.9 | 0.013 | 5.085 [0.231] | 64.8 | 5.074 | 4.925 | 333,316,880 | 2.92 | - | 0.754 | 0.987 |
| T64  | GPU | 89.3 | 0.042 | 5.246 [0.238] | 63.5 | 5.097 | 5.011 | 333,316,880 | 2.31 | 2529 | 0.717 | 1.008 |
| T128  | CPU | 168.6 | 0.05 | 12.831 [0.583] | 136.2 | 9.042 | 11.1 | 497,665,904 | 4.82 | - | 0.759 | 0.94 |
| T128  | GPU | 142.8 | 0.045 | 12.872 [0.585] | 107.1 | 8.742 | 8.451 | 497,665,904 | 3.03 | 3105 | 0.896 | 1.195 |
T32 CPU r2 threads default (22) controls 11 declines 0 id 68ad19c83a3ae1a3 load 10.203 fresh-verify wall 34.4
T32 GPU r2 threads default (22) controls None declines 0 id 68ad19c83a3ae1a3 load 9.063 fresh-verify wall 14.9
T32 CPU threads 16 controls 11 declines 0 id 9b71dfb0a2b4608d load 9.703 fresh-verify wall 26.6
T32 GPU threads 16 controls None declines 0 id 9b71dfb0a2b4608d load 9.147 fresh-verify wall 14.3
T64 CPU threads 16 controls 11 declines 0 id c2a42c61f2d88113 load 9.266 fresh-verify wall 35.2
T64 GPU threads 16 controls None declines 0 id c2a42c61f2d88113 load 10.123 fresh-verify wall 15.1
T128 CPU threads 16 controls 11 declines 0 id 53a5667decccbe4d load 9.714 fresh-verify wall 55.6
T128 GPU threads 16 controls None declines 0 id 53a5667decccbe4d load 9.393 fresh-verify wall 19.8

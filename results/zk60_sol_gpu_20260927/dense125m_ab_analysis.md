# Synthetic dense 125M private-block CPU/GPU diagnostic — 2026-09-27

The frozen six-process A/B gate passed on the shared RTX 4070 Laptop GPU (8188 MiB, driver 566.14). It ran one synthetic 125M-shaped private block at T512, d768, f2048 with dense public weights and the recipe's hidden input. The release test binary SHA-256 was `314fd717838f5d99a0385f250a79e8a4285d73b3cafe433ff35f80a4d6befdc3`; runner SHA-256 was `365e4910d8a3a04a05443659a04a1b95c48253c5484477a0ee5126234176336d`. The raw `attempt-5-dense-ab/report.json` SHA-256 is `43c6b416c2d4254d821ec304e0fc49c6b8fbfb974b9122f919fdf7663d347506`; it has `status=passed`, `done=0`, six passed cases and matching SHA-256 for all six logs. GPU samples each recorded exactly four accepted keyed device commitments and no decline; CPU samples recorded none. Every sample verified the 40,783,352-byte receipt from bytes and refused its truncated form in the same test process.

The first CPU and GPU runs were warmups and are excluded below. ABBA order was CPU, GPU, GPU, CPU, with two Rayon threads and one fresh process per sample. The process wall includes startup and GPU initialization. Times are seconds; RSS is the host process high-water mark, not GPU VRAM.

| Sample | Prove call | Whole process | Witness build | Verify bytes | Other residual* | Host peak RSS MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| a1 CPU | 33.21 | 39.614 | 5.35 | 0.85 | 0.204 | 10,526 |
| b1 GPU | 17.40 | 32.586 | 10.66 | 0.81 | 3.716 | 4,380 |
| b2 GPU | 16.86 | 27.524 | 5.77 | 0.82 | 4.074 | 4,443 |
| a2 CPU | 32.69 | 40.177 | 6.34 | 0.96 | 0.187 | 10,522 |
| CPU mean | **32.95** | **39.895** | 5.845 | 0.905 | 0.195 | 10,524 |
| GPU mean | **17.13** | **30.055** | 8.215 | 0.815 | 3.895 | 4,411.5 |

The observed mean proving-call ratio is **1.924× CPU/GPU** (15.82 seconds less on GPU); the whole-process ratio is **1.327×** (9.840 seconds less). These are two measured samples per arm, not a steady-state throughput estimate. The b1 GPU witness build took 10.66 seconds versus 5.77 in b2, increasing its whole-process wall. Root observed another persistent research cycle start at 03:52:33 UTC during this A/B; the shared host was not quiesced.

The tagged GPU route reduces the two large A/H commitment phases from a mean **16.079 seconds on CPU** (A 7.137, H 8.942) to **0.796 seconds on GPU** (A 0.365, H 0.431). This approximately 15.283-second phase reduction explains most of the 15.82-second proving-call difference. The dominant remaining GPU proving phase is the **softmax zero-check**: 8.045 seconds mean, about 47% of GPU proving. The mixed D zero-check averages 2.244 seconds (13%), and the F zero-check 1.168 seconds (7%). GPU attention phases total 9.679 seconds mean, about 56.5% of proving. These phase tables make softmax the next concrete performance target; they do not establish a new optimization's benefit.

The test's separate `wire::encode` phase averaged only 0.029 seconds on GPU (0.019 on CPU) for the 40.8 MB frame. The `Other residual*` column is the raw process wall minus displayed witness, proving and verification times. It includes endpoint preparation, process startup, GPU initialization, receipt serialization, test checks and timing precision; it is **not** an isolated serialization measure. The proving-call time excludes endpoint preparation and frame serialization, and same-process byte verification is not an independent fresh-process verifier gate.

The test source explicitly calls this 125M run development-grade and not privacy acceptance. Its printed dense-recipe label still says S19-F1 is expected to reject the case, but Stage 20 source and adversarial tests document the S19-F1 repair; this run verified. The label is stale and should be reconciled separately. This A/B is one block on a laptop GPU, with no complete-model passes or proved tokens per second. It does not establish P1 privacy acceptance, RTX 5090 readiness, an 8B transformer stack, or the >=50 proved tokens/s target.

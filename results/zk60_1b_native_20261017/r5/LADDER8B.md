| T | arm | block wall (PB-TIMING) | model | err | commit | zero-checks (D/F/S/Q/Kv) | inverses | openings | conversion | rest | witness | prove_one_bound | verify (fresh) | receipt B | peak RSS GiB | VRAM MiB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 64 | cpu | 4.27 | 5.47 | -22% | 1.09 (1.28) | 2.10 = 0.81/0.63/0.23/0.24/0.19 (2.64 = 1.12/0.76/0.22/0.32/0.22) | 0.27 (0.31) | 0.23 (0.32) | 0.12 (0.16) | 0.46 (0.76) | 1.506 (1.19) | 5.073 | - | 21697592 (21.7 MB) | 3.9 (3.2) | - |
| 64 | gpu | 6.55 | 4.78 | +37% | 0.72 (1.28) | 3.97 = 1.72/1.02/0.33/0.58/0.32 (2.64 = 1.12/0.76/0.22/0.32/0.22) | 0.35 (0.31) | 0.61 (0.32) | 0.17 (0.16) | 0.73 (0.76) | 1.571 (1.19) | 7.657 | - | 21697592 (21.7 MB) | 2.38 (3.2) | 4417 |
| 64 | gpu-chunked | 6.17 | 4.78 | +29% | 0.69 (1.28) | 3.51 = 1.61/0.93/0.31/0.39/0.27 (2.64 = 1.12/0.76/0.22/0.32/0.22) | 0.40 (0.31) | 0.68 (0.32) | 0.16 (0.16) | 0.73 (0.76) | 1.644 (1.19) | 7.374 | - | 21697592 (21.7 MB) | 2.37 (3.2) | 737 |
| 128 | cpu | 8.15 | 10.60 | -23% | 2.84 (2.72) | 3.34 = 1.25/1.12/0.40/0.35/0.22 (5.05 = 2.15/1.43/0.53/0.57/0.37) | 0.55 (0.67) | 0.48 (0.69) | 0.21 (0.34) | 0.73 (1.14) | 2.384 (2.51) | 8.917 | - | 29300936 (29.3 MB) | 7.14 (6.3) | - |
| 128 | gpu-chunked | 9.12 | 8.78 | +4% | 0.76 (2.72) | 5.31 = 1.72/1.74/0.81/0.68/0.35 (5.05 = 2.15/1.43/0.53/0.57/0.37) | 0.77 (0.67) | 0.89 (0.69) | 0.37 (0.34) | 1.02 (1.14) | 3.752 (2.51) | 10.497 | - | 29300936 (29.3 MB) | 3.66 (6.3) | 1345 |

T64 cpu: per-group error vs the model (>15% flagged):
   commit       measured   1.088  model   1.277   -14.8% ok
   zero_checks  measured   2.103  model   2.637   -20.3% MISS
   inverses     measured   0.273  model   0.310   -11.9% ok
   openings     measured   0.235  model   0.322   -27.0% MISS
   conversion   measured   0.115  model   0.163   -29.4% MISS
   rest         measured   0.459  model   0.761   -39.7% MISS
T64 gpu: per-group error vs the model (>15% flagged):
   zero_checks  measured   3.966  model   2.637   +50.4% MISS
   inverses     measured   0.351  model   0.310   +13.2% ok
   openings     measured   0.613  model   0.322   +90.4% MISS
   conversion   measured   0.171  model   0.163    +4.9% ok
   rest         measured   0.730  model   0.761    -4.1% ok
T64 gpu-chunked: per-group error vs the model (>15% flagged):
   commit       measured   0.694  model   1.277   -45.7% MISS
   zero_checks  measured   3.506  model   2.637   +33.0% MISS
   inverses     measured   0.403  model   0.310   +30.0% MISS
   openings     measured   0.682  model   0.322  +111.8% MISS
   conversion   measured   0.159  model   0.163    -2.5% ok
   rest         measured   0.728  model   0.761    -4.3% ok
T128 cpu: per-group error vs the model (>15% flagged):
   commit       measured   2.842  model   2.717    +4.6% ok
   zero_checks  measured   3.337  model   5.049   -33.9% MISS
   inverses     measured   0.555  model   0.668   -16.9% MISS
   openings     measured   0.479  model   0.685   -30.1% MISS
   conversion   measured   0.208  model   0.344   -39.5% MISS
   rest         measured   0.733  model   1.135   -35.4% MISS
T128 gpu-chunked: per-group error vs the model (>15% flagged):
   commit       measured   0.758  model   2.717   -72.1% MISS
   zero_checks  measured   5.308  model   5.049    +5.1% ok
   inverses     measured   0.774  model   0.668   +15.9% MISS
   openings     measured   0.889  model   0.685   +29.8% MISS
   conversion   measured   0.366  model   0.344    +6.4% ok
   rest         measured   1.025  model   1.135    -9.7% ok

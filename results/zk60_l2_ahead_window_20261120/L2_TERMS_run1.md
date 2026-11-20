### L2 run1: 96 request lines, arms ['serve4', 'serve4+ahead8', 'serve4+ahead16', 'serve4+ahead32'], passes [0, 1, 2, 3, 4, 5]

arm order per pass: 0: serve4 > serve4+ahead8 > serve4+ahead16 > serve4+ahead32; 1: serve4+ahead32 > serve4+ahead16 > serve4+ahead8 > serve4; 2: serve4 > serve4+ahead8 > serve4+ahead16 > serve4+ahead32; 3: serve4+ahead32 > serve4+ahead16 > serve4+ahead8 > serve4; 4: serve4 > serve4+ahead8 > serve4+ahead16 > serve4+ahead32; 5: serve4+ahead32 > serve4+ahead16 > serve4+ahead8 > serve4

| term (s, median) | serve4 | serve4+ahead8 | serve4+ahead16 | serve4+ahead32 |
|---|---|---|---|---|
| cadence | 3.765 (n=6) | 3.685 (n=6) | 3.690 (n=6) | 3.752 (n=6) |
| prove call | 3.768 (n=18) | 3.739 (n=18) | 3.788 (n=18) | 3.937 (n=18) |
| forks | 3.486 (n=18) | 3.444 (n=18) | 3.506 (n=18) | 3.632 (n=18) |
| commit | 0.223 (n=18) | 0.212 (n=18) | 0.208 (n=18) | 0.227 (n=18) |
| join | 0.083 (n=18) | 0.081 (n=18) | 0.076 (n=18) | 0.087 (n=18) |
| sealing ov | 3.136 (n=18) | 3.148 (n=18) | 3.172 (n=18) | 3.248 (n=18) |
| sealing solo | 1.990 (n=6) | 2.026 (n=6) | 2.117 (n=6) | 2.189 (n=6) |
| admission | 0.871 (n=12) | 0.803 (n=12) | 0.863 (n=12) | 0.867 (n=12) |
| prover wait | 0.497 (n=18) | 0.440 (n=18) | 0.445 (n=18) | 0.418 (n=18) |
| result gap | 3.761 (n=18) | 3.744 (n=18) | 3.776 (n=18) | 3.934 (n=18) |

| cadence per pass (s) | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median | min-max |
|---|---|---|---|---|---|---|---|---|
| serve4 | 3.665 | 3.767 | 3.780 | 3.765 | 3.737 | 3.765 | 3.765 | 3.665-3.780 |
| serve4+ahead8 | 3.684 | 3.703 | 3.686 | 3.724 | 3.669 | 3.641 | 3.685 | 3.641-3.724 |
| serve4+ahead16 | 3.758 | 3.645 | 3.735 | 3.787 | 3.601 | 3.643 | 3.690 | 3.601-3.787 |
| serve4+ahead32 | 3.751 | 3.641 | 3.837 | 3.743 | 3.780 | 3.753 | 3.752 | 3.641-3.837 |

Pairs by pass against `serve4` (arm minus base, s; negative = the arm is faster):

| arm | pass 0 (pos arm/base) | pass 1 (pos arm/base) | pass 2 (pos arm/base) | pass 3 (pos arm/base) | pass 4 (pos arm/base) | pass 5 (pos arm/base) | median diff | median % | lower in |
|---|---|---|---|---|---|---|---|---|---|
| serve4+ahead8 | +0.019 (2/1) | -0.063 (3/4) | -0.093 (2/1) | -0.040 (3/4) | -0.068 (2/1) | -0.125 (3/4) | -0.066 | -1.75% | 5 of 6 |
| serve4+ahead16 | +0.093 (3/1) | -0.122 (2/4) | -0.044 (3/1) | +0.022 (2/4) | -0.136 (3/1) | -0.122 (2/4) | -0.083 | -2.21% | 4 of 6 |
| serve4+ahead32 | +0.087 (4/1) | -0.126 (1/4) | +0.057 (4/1) | -0.022 (1/4) | +0.043 (4/1) | -0.012 (1/4) | +0.015 | +0.41% | 3 of 6 |

`serve4+ahead8` minus `serve4` (medians): cadence -0.080, prove call -0.030, forks -0.042, commit -0.011, join -0.002, sealing ov +0.011, sealing solo +0.037, admission -0.068, prover wait -0.057, result gap -0.017
`serve4+ahead16` minus `serve4` (medians): cadence -0.075, prove call +0.020, forks +0.019, commit -0.015, join -0.006, sealing ov +0.036, sealing solo +0.127, admission -0.008, prover wait -0.052, result gap +0.015
`serve4+ahead32` minus `serve4` (medians): cadence -0.013, prove call +0.169, forks +0.145, commit +0.004, join +0.004, sealing ov +0.112, sealing solo +0.200, admission -0.004, prover wait -0.079, result gap +0.173

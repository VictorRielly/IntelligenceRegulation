### L2 run1: 96 request lines; requests per pass {'serve4': 4, 'serve4+ahead8': 4, 'serve4+ahead16': 4, 'serve4+ahead32': 4}; passes [0, 1, 2, 3, 4, 5]

arm order per pass: 0: serve4 > serve4+ahead8 > serve4+ahead16 > serve4+ahead32; 1: serve4+ahead32 > serve4+ahead16 > serve4+ahead8 > serve4; 2: serve4 > serve4+ahead8 > serve4+ahead16 > serve4+ahead32; 3: serve4+ahead32 > serve4+ahead16 > serve4+ahead8 > serve4; 4: serve4 > serve4+ahead8 > serve4+ahead16 > serve4+ahead32; 5: serve4+ahead32 > serve4+ahead16 > serve4+ahead8 > serve4

| steady gap per pass (s) | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median | min-max |
|---|---|---|---|---|---|---|---|---|
| serve4 | 3.905 | 3.942 | 3.883 | 4.002 | 3.749 | 3.875 | 3.894 | 3.749-4.002 |
| serve4+ahead8 | 3.761 | 3.655 | 3.854 | 3.883 | 3.723 | 3.727 | 3.744 | 3.655-3.883 |
| serve4+ahead16 | 3.914 | 3.754 | 3.927 | 3.969 | 3.736 | 3.833 | 3.874 | 3.736-3.969 |
| serve4+ahead32 | 3.918 | 3.955 | 4.124 | 4.006 | 4.026 | 3.961 | 3.984 | 3.918-4.124 |

| cadence per pass (s) | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median | min-max |
|---|---|---|---|---|---|---|---|---|
| serve4 | 3.665 | 3.767 | 3.780 | 3.765 | 3.737 | 3.765 | 3.765 | 3.665-3.780 |
| serve4+ahead8 | 3.684 | 3.703 | 3.686 | 3.724 | 3.669 | 3.641 | 3.685 | 3.641-3.724 |
| serve4+ahead16 | 3.758 | 3.645 | 3.735 | 3.787 | 3.601 | 3.643 | 3.690 | 3.601-3.787 |
| serve4+ahead32 | 3.751 | 3.641 | 3.837 | 3.743 | 3.780 | 3.753 | 3.752 | 3.641-3.837 |

Pairs by pass against `serve4` on the steady gap (arm minus base, s; negative = the arm is faster; pos arm/base):

| arm | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median diff | median % | lower in |
|---|---|---|---|---|---|---|---|---|---|
| serve4+ahead8 | -0.144 (2/1) | -0.287 (3/4) | -0.029 (2/1) | -0.119 (3/4) | -0.026 (2/1) | -0.148 (3/4) | -0.131 | -3.33% | 6 of 6 |
| serve4+ahead16 | +0.009 (3/1) | -0.188 (2/4) | +0.044 (3/1) | -0.033 (2/4) | -0.013 (3/1) | -0.042 (2/4) | -0.023 | -0.59% | 4 of 6 |
| serve4+ahead32 | +0.013 (4/1) | +0.013 (1/4) | +0.241 (4/1) | +0.004 (1/4) | +0.277 (4/1) | +0.086 (1/4) | +0.050 | +1.28% | 0 of 6 |

Pairs by pass against `serve4` on the cadence (arm minus base, s; negative = the arm is faster; pos arm/base):

| arm | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median diff | median % | lower in |
|---|---|---|---|---|---|---|---|---|---|
| serve4+ahead8 | +0.019 (2/1) | -0.063 (3/4) | -0.093 (2/1) | -0.040 (3/4) | -0.068 (2/1) | -0.125 (3/4) | -0.066 | -1.75% | 5 of 6 |
| serve4+ahead16 | +0.093 (3/1) | -0.122 (2/4) | -0.044 (3/1) | +0.022 (2/4) | -0.136 (3/1) | -0.122 (2/4) | -0.083 | -2.21% | 4 of 6 |
| serve4+ahead32 | +0.087 (4/1) | -0.126 (1/4) | +0.057 (4/1) | -0.022 (1/4) | +0.043 (4/1) | -0.012 (1/4) | +0.015 | +0.41% | 3 of 6 |

| prove call by request (s, median over passes) | q0 | q1 | q2 | q3 |
|---|---|---|---|---|
| serve4 | 4.032 | 3.843 | 3.881 | 3.520 |
| serve4+ahead8 | 3.981 | 3.855 | 3.739 | 3.422 |
| serve4+ahead16 | 4.168 | 3.853 | 3.874 | 3.343 |
| serve4+ahead32 | 4.126 | 3.973 | 3.984 | 3.305 |

| forks by request (s, median over passes) | q0 | q1 | q2 | q3 |
|---|---|---|---|---|
| serve4 | 3.639 | 3.548 | 3.580 | 3.196 |
| serve4+ahead8 | 3.460 | 3.549 | 3.444 | 3.118 |
| serve4+ahead16 | 3.571 | 3.567 | 3.584 | 3.067 |
| serve4+ahead32 | 3.570 | 3.665 | 3.638 | 2.971 |

| commit by request (s, median over passes) | q0 | q1 | q2 | q3 |
|---|---|---|---|---|
| serve4 | 0.296 | 0.225 | 0.223 | 0.217 |
| serve4+ahead8 | 0.424 | 0.212 | 0.211 | 0.213 |
| serve4+ahead16 | 0.443 | 0.212 | 0.205 | 0.207 |
| serve4+ahead32 | 0.422 | 0.227 | 0.231 | 0.221 |

| sealing pass by request (s, median over passes) | q0 | q1 | q2 | q3 |
|---|---|---|---|---|
| serve4 | 1.990 | 3.136 | 3.136 | 3.138 |
| serve4+ahead8 | 2.026 | 3.189 | 3.158 | 3.122 |
| serve4+ahead16 | 2.117 | 3.127 | 3.179 | 3.218 |
| serve4+ahead32 | 2.189 | 3.154 | 3.295 | 3.396 |

| prover wait by request (s, median over passes) | q0 | q1 | q2 | q3 |
|---|---|---|---|---|
| serve4 | 0.000 | 0.803 | 0.461 | 0.479 |
| serve4+ahead8 | 0.000 | 0.740 | 0.420 | 0.364 |
| serve4+ahead16 | 0.000 | 0.962 | 0.357 | 0.396 |
| serve4+ahead32 | 0.000 | 0.934 | 0.378 | 0.327 |


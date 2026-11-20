### L2 run2: 192 request lines; requests per pass {'serve8+lanes2': 8, 'serve8+lanes2+ahead4': 8, 'serve8+lanes2+ahead8': 8, 'serve8+lanes2+ahead16': 8}; passes [0, 1, 2, 3, 4, 5]

arm order per pass: 0: serve8+lanes2 > serve8+lanes2+ahead4 > serve8+lanes2+ahead8 > serve8+lanes2+ahead16; 1: serve8+lanes2+ahead16 > serve8+lanes2+ahead8 > serve8+lanes2+ahead4 > serve8+lanes2; 2: serve8+lanes2 > serve8+lanes2+ahead4 > serve8+lanes2+ahead8 > serve8+lanes2+ahead16; 3: serve8+lanes2+ahead16 > serve8+lanes2+ahead8 > serve8+lanes2+ahead4 > serve8+lanes2; 4: serve8+lanes2 > serve8+lanes2+ahead4 > serve8+lanes2+ahead8 > serve8+lanes2+ahead16; 5: serve8+lanes2+ahead16 > serve8+lanes2+ahead8 > serve8+lanes2+ahead4 > serve8+lanes2

| steady gap per pass (s) | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median | min-max |
|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.856 | 3.796 | 3.890 | 3.774 | 3.784 | 3.809 | 3.803 | 3.774-3.890 |
| serve8+lanes2+ahead4 | 3.815 | 3.775 | 3.869 | 3.832 | 3.809 | 3.931 | 3.824 | 3.775-3.931 |
| serve8+lanes2+ahead8 | 3.811 | 3.818 | 3.880 | 3.764 | 3.810 | 3.791 | 3.811 | 3.764-3.880 |
| serve8+lanes2+ahead16 | 3.925 | 3.922 | 3.887 | 3.910 | 3.799 | 3.815 | 3.899 | 3.799-3.925 |

| cadence per pass (s) | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median | min-max |
|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.753 | 3.738 | 3.815 | 3.726 | 3.747 | 3.807 | 3.750 | 3.726-3.815 |
| serve8+lanes2+ahead4 | 3.767 | 3.746 | 3.826 | 3.780 | 3.758 | 3.845 | 3.773 | 3.746-3.845 |
| serve8+lanes2+ahead8 | 3.760 | 3.776 | 3.842 | 3.708 | 3.749 | 3.759 | 3.759 | 3.708-3.842 |
| serve8+lanes2+ahead16 | 3.872 | 3.867 | 3.817 | 3.868 | 3.730 | 3.747 | 3.842 | 3.730-3.872 |

Pairs by pass against `serve8+lanes2` on the steady gap (arm minus base, s; negative = the arm is faster; pos arm/base):

| arm | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median diff | median % | lower in |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2+ahead4 | -0.041 (2/1) | -0.021 (3/4) | -0.021 (2/1) | +0.058 (3/4) | +0.025 (2/1) | +0.123 (3/4) | +0.002 | +0.07% | 3 of 6 |
| serve8+lanes2+ahead8 | -0.045 (3/1) | +0.022 (2/4) | -0.009 (3/1) | -0.010 (2/4) | +0.026 (3/1) | -0.018 (2/4) | -0.010 | -0.25% | 4 of 6 |
| serve8+lanes2+ahead16 | +0.069 (4/1) | +0.125 (1/4) | -0.002 (4/1) | +0.136 (1/4) | +0.015 (4/1) | +0.006 (1/4) | +0.042 | +1.09% | 1 of 6 |

Pairs by pass against `serve8+lanes2` on the cadence (arm minus base, s; negative = the arm is faster; pos arm/base):

| arm | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median diff | median % | lower in |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2+ahead4 | +0.014 (2/1) | +0.008 (3/4) | +0.012 (2/1) | +0.054 (3/4) | +0.011 (2/1) | +0.038 (3/4) | +0.013 | +0.33% | 0 of 6 |
| serve8+lanes2+ahead8 | +0.007 (3/1) | +0.039 (2/4) | +0.027 (3/1) | -0.018 (2/4) | +0.001 (3/1) | -0.049 (2/4) | +0.004 | +0.11% | 2 of 6 |
| serve8+lanes2+ahead16 | +0.119 (4/1) | +0.129 (1/4) | +0.002 (4/1) | +0.143 (1/4) | -0.017 (4/1) | -0.061 (1/4) | +0.061 | +1.61% | 2 of 6 |

| prove call by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 |
|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.974 | 3.772 | 3.809 | 3.733 | 3.865 | 3.833 | 3.817 | 3.484 |
| serve8+lanes2+ahead4 | 4.037 | 3.814 | 3.857 | 3.868 | 3.891 | 3.789 | 3.779 | 3.470 |
| serve8+lanes2+ahead8 | 4.079 | 3.808 | 3.862 | 3.788 | 3.785 | 3.883 | 3.822 | 3.432 |
| serve8+lanes2+ahead16 | 4.110 | 3.898 | 3.930 | 3.925 | 3.818 | 3.881 | 3.825 | 3.404 |

| forks by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 |
|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.619 | 3.466 | 3.511 | 3.449 | 3.538 | 3.548 | 3.516 | 3.202 |
| serve8+lanes2+ahead4 | 3.545 | 3.513 | 3.532 | 3.554 | 3.508 | 3.495 | 3.486 | 3.179 |
| serve8+lanes2+ahead8 | 3.579 | 3.506 | 3.571 | 3.498 | 3.498 | 3.575 | 3.498 | 3.150 |
| serve8+lanes2+ahead16 | 3.592 | 3.607 | 3.630 | 3.619 | 3.530 | 3.580 | 3.526 | 3.107 |

| commit by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 |
|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 0.290 | 0.209 | 0.212 | 0.211 | 0.223 | 0.221 | 0.231 | 0.220 |
| serve8+lanes2+ahead4 | 0.356 | 0.221 | 0.220 | 0.217 | 0.221 | 0.217 | 0.215 | 0.207 |
| serve8+lanes2+ahead8 | 0.413 | 0.206 | 0.210 | 0.207 | 0.206 | 0.211 | 0.225 | 0.204 |
| serve8+lanes2+ahead16 | 0.431 | 0.211 | 0.215 | 0.216 | 0.208 | 0.209 | 0.211 | 0.208 |

| sealing pass by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 |
|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 1.885 | 3.174 | 2.995 | 3.215 | 3.102 | 3.131 | 3.048 | 3.148 |
| serve8+lanes2+ahead4 | 1.969 | 3.155 | 3.112 | 3.152 | 3.141 | 3.120 | 3.086 | 3.139 |
| serve8+lanes2+ahead8 | 2.066 | 3.149 | 3.126 | 3.153 | 3.147 | 3.086 | 3.101 | 3.139 |
| serve8+lanes2+ahead16 | 2.220 | 3.345 | 3.224 | 3.307 | 3.264 | 3.258 | 3.234 | 3.217 |

| prover wait by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 |
|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 0.000 | 0.816 | 0.489 | 0.335 | 0.386 | 0.444 | 0.482 | 0.376 |
| serve8+lanes2+ahead4 | 0.000 | 0.848 | 0.447 | 0.443 | 0.464 | 0.440 | 0.400 | 0.353 |
| serve8+lanes2+ahead8 | 0.000 | 0.859 | 0.457 | 0.413 | 0.390 | 0.392 | 0.452 | 0.405 |
| serve8+lanes2+ahead16 | 0.000 | 0.725 | 0.384 | 0.302 | 0.338 | 0.343 | 0.396 | 0.344 |


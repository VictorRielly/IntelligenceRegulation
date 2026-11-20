### A35 t1: 96 request lines; requests per pass {'serve8+lanes2': 8, 'serve8+lanes2+ba1': 8}; passes [0, 1, 2, 3, 4, 5]

arm order per pass: 0: serve8+lanes2 > serve8+lanes2+ba1; 1: serve8+lanes2+ba1 > serve8+lanes2; 2: serve8+lanes2 > serve8+lanes2+ba1; 3: serve8+lanes2+ba1 > serve8+lanes2; 4: serve8+lanes2 > serve8+lanes2+ba1; 5: serve8+lanes2+ba1 > serve8+lanes2

switches per arm as the STREAM lines print them (bounds ahead): serve8+lanes2: ['false'], window ['0']; serve8+lanes2+ba1: ['true'], window ['0']

| steady gap per pass (s) | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median | min-max |
|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.732 | 3.787 | 3.730 | 3.779 | 3.809 | 3.747 | 3.763 | 3.730-3.809 |
| serve8+lanes2+ba1 | 3.538 | 3.606 | 3.563 | 3.582 | 3.541 | 3.582 | 3.572 | 3.538-3.606 |

| cadence per pass (s) | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median | min-max |
|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.725 | 3.760 | 3.710 | 3.780 | 3.754 | 3.737 | 3.745 | 3.710-3.780 |
| serve8+lanes2+ba1 | 3.483 | 3.558 | 3.502 | 3.522 | 3.505 | 3.536 | 3.513 | 3.483-3.558 |

Pairs by pass, `serve8+lanes2+ba1` minus `serve8+lanes2` on the steady gap (s; negative = the switch-on arm is faster; pos arm/base):

| arm | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median diff | median % | lower in |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2+ba1 | -0.194 (2/1) | -0.181 (1/2) | -0.168 (2/1) | -0.197 (1/2) | -0.269 (2/1) | -0.165 (1/2) | -0.187 | -4.98% | 6 of 6 |

**Verdict by the fixed rule (steady gap, n = 6 passes): PASS** (lower in 6 of 6; median -4.98%)

Pairs by pass, `serve8+lanes2+ba1` minus `serve8+lanes2` on the cadence (s; negative = the switch-on arm is faster; pos arm/base):

| arm | pass 0 | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | median diff | median % | lower in |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2+ba1 | -0.242 (2/1) | -0.201 (1/2) | -0.208 (2/1) | -0.258 (1/2) | -0.248 (2/1) | -0.201 (1/2) | -0.225 | -6.06% | 6 of 6 |

| prove call by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 | median q1-q6 |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.917 | 3.795 | 3.699 | 3.777 | 3.798 | 3.764 | 3.822 | 3.575 | 3.784 |
| serve8+lanes2+ba1 | 3.926 | 4.105 | 3.907 | 3.857 | 3.825 | 3.851 | 3.835 | 3.615 | 3.873 |

| commit by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 | median q1-q6 |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 0.295 | 0.214 | 0.215 | 0.215 | 0.210 | 0.213 | 0.223 | 0.213 | 0.214 |
| serve8+lanes2+ba1 | 0.291 | 0.565 | 0.311 | 0.331 | 0.303 | 0.311 | 0.307 | 0.314 | 0.331 |

| forks by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 | median q1-q6 |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.541 | 3.484 | 3.409 | 3.476 | 3.501 | 3.474 | 3.516 | 3.278 | 3.484 |
| serve8+lanes2+ba1 | 3.562 | 3.439 | 3.535 | 3.458 | 3.435 | 3.487 | 3.471 | 3.221 | 3.458 |

| join by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 | median q1-q6 |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 0.082 | 0.082 | 0.078 | 0.082 | 0.080 | 0.075 | 0.079 | 0.080 | 0.078 |
| serve8+lanes2+ba1 | 0.079 | 0.074 | 0.076 | 0.074 | 0.073 | 0.073 | 0.074 | 0.077 | 0.074 |

| prover hold (left - entered) by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 | median q1-q6 |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 3.917 | 3.796 | 3.698 | 3.776 | 3.798 | 3.765 | 3.823 | 3.576 | 3.784 |
| serve8+lanes2+ba1 | 3.641 | 3.513 | 3.609 | 3.531 | 3.510 | 3.559 | 3.546 | 3.300 | 3.533 |

| prover wait (entered - sealing side done) by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 | median q1-q6 |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 0.000 | 0.760 | 0.454 | 0.404 | 0.423 | 0.457 | 0.466 | 0.416 | 0.461 |
| serve8+lanes2+ba1 | 0.292 | 0.848 | 0.320 | 0.341 | 0.312 | 0.336 | 0.310 | 0.326 | 0.347 |

| prover-turn wait inside the call by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 | median q1-q6 |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| serve8+lanes2+ba1 | 0.000 | 0.281 | 0.000 | 0.010 | 0.006 | 0.022 | 0.000 | 0.005 | 0.018 |

| sealing pass by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 | median q1-q6 |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 1.901 | 3.111 | 3.085 | 3.007 | 3.058 | 3.072 | 3.000 | 3.091 | 3.064 |
| serve8+lanes2+ba1 | 1.892 | 3.072 | 2.944 | 3.005 | 2.955 | 2.936 | 3.030 | 2.952 | 2.974 |

| receipt write by request (s, median over passes) | q0 | q1 | q2 | q3 | q4 | q5 | q6 | q7 | median q1-q6 |
|---|---|---|---|---|---|---|---|---|---|
| serve8+lanes2 | 0.217 | 0.216 | 0.224 | 0.216 | 0.215 | 0.221 | 0.212 | 0.216 | 0.216 |
| serve8+lanes2+ba1 | 0.227 | 0.221 | 0.217 | 0.231 | 0.218 | 0.222 | 0.224 | 0.215 | 0.221 |

| footprint per arm (GiB, over passes) | start median | peak median | peak max | end median | CPU user+sys per pass median (s) |
|---|---|---|---|---|---|
| serve8+lanes2 | 32.2 | 46.9 | 47.1 | 32.4 | 487.4 |
| serve8+lanes2+ba1 | 32.2 | 46.8 | 47.2 | 32.2 | 488.0 |


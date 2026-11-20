#!/bin/bash
# One guarded build-class job (third run): generate the K5 libraries and build the bench. Output stays in this folder.
set -e
R=/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118
K=/Users/victorrielly/IntelligenceRegulation/results/zk60_a27_app_20261107/kbench
D=/Users/victorrielly/zk60-artifacts/a27_shader_dumps_20261117/w16r2_8b
/usr/bin/python3 $R/k5_gen.py $K/slot14_shieldstral_r13_a26.metal $R/build/k5_s14.metal 4
/usr/bin/python3 $R/k5_gen.py $K/slot18_shieldstral_r13_a26.metal $R/build/k5_s18.metal 4
/usr/bin/python3 $R/k5_gen.py $D/slot_k36_d4_00000005e420705d.metal $R/build/k5_b14.metal 4
/usr/bin/python3 $R/k5_gen.py $D/slot_k19_d5_000000038f804b13.metal $R/build/k5_b18.metal 4
/usr/bin/python3 $R/k5_gen.py $D/slot_k19_d5_000000038f804b13.metal $R/build/k5_b18r0.metal 4 --kernel k_sc_round0
/usr/bin/python3 $R/k5_check_v13.py
/usr/bin/clang++ -O2 -std=c++17 -fobjc-arc -framework Metal -framework Foundation -o $R/build/k5_bench $R/k5_bench.mm
echo BUILD_OK

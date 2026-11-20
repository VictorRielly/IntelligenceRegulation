#!/bin/bash
# One guarded build-class job (second run): generate the K3/K4 libraries and build the bench. Output stays in this folder.
set -e
R=/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118
K=/Users/victorrielly/IntelligenceRegulation/results/zk60_a27_app_20261107/kbench
/usr/bin/python3 $R/k3k4_gen.py $K/slot14_shieldstral_r13_a26.metal $R/build/k3k4_s14.metal 4
/usr/bin/python3 $R/k3k4_gen.py $K/slot18_shieldstral_r13_a26.metal $R/build/k3k4_s18.metal 4 --k4 $R/build/k3k4_k4.metal
/usr/bin/python3 $R/k3k4_check_v13.py
/usr/bin/clang++ -O2 -std=c++17 -fobjc-arc -framework Metal -framework Foundation -o $R/build/k3k4_bench $R/k3k4_bench.mm
echo BUILD_OK

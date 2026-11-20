#!/bin/bash
# One guarded build-class job: generate the kernel libraries, build the bench. Output stays in this folder.
set -e
R=/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118
K=/Users/victorrielly/IntelligenceRegulation/results/zk60_a27_app_20261107/kbench
PRO=/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal_kernels.metal
mkdir -p $R/build
# attained degree 4 for both slots, as the A27 README / kb1 used (v13 = np 4)
/usr/bin/python3 $R/gen_k1.py $K/slot14_shieldstral_r13_a26.metal $R/build/s14.metal 4
/usr/bin/python3 $R/gen_k1.py $K/slot18_shieldstral_r13_a26.metal $R/build/s18.metal 4
# the original gen.py, run unmodified into our folder, to confirm our k_v13 text is the same kernel
/usr/bin/python3 $K/gen.py $K/slot14_shieldstral_r13_a26.metal $R/build/ref14.metal 4
/usr/bin/python3 $K/gen.py $K/slot18_shieldstral_r13_a26.metal $R/build/ref18.metal 4
/usr/bin/python3 $R/mk_k0_src.py $PRO $R/build/k0.metal
/usr/bin/clang++ -O2 -std=c++17 -fobjc-arc -framework Metal -framework Foundation -o $R/build/bench $R/bench.mm
echo BUILD_OK

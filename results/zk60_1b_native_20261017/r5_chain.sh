#!/bin/bash
# NATIVE LANE round 5 (evening): after the guarded builds (r5_build.sh r5b),
# (1) the full guarded release suite on the R5 tree (task 1), then (2) the
# speed-plan task-1 acceptance runs with the R5 CPU CLI (each prove job one
# guarded command, then a FRESH-process verify; controls on every CPU run):
#   * Llama-3-8B T32 ho00 (32 blocks; the R4 baseline 384.5 s),
#   * TinyLlama T32 ho00 (statement identity 9b71dfb0...),
#   * TinyLlama T128 ho00 (byte counters vs the counted totals).
# usage: r5_chain.sh
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
until [ -f $D/r5_build_r5b.done ]; do sleep 20; done
[ "$(cat $D/r5_build_r5b.done)" = 0 ] || { echo "build chain failed: $(cat $D/r5_build_r5b.done)"; exit 1; }
echo "suite start $(date -u +%H:%M:%S)"
NEED=4.5 CAP=8 $D/r3_suite.sh r5-suite
echo "suite exit $(cat $D/r5-suite.done 2>/dev/null) $(date -u +%H:%M:%S)"
E8=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32
EX=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export
# cap 9 GiB for the 8B prove: the kernel cap counts page cache, and the R4
# run sat AT its 6 GiB cap (cgroup peak 6.0) while streaming 6.6 GB twice
VNEED=2.5 VCAP=8 $D/r5_stack.sh $E8 cpu ho00 3 9
echo "8B T32 done $(date -u +%H:%M:%S)"
$D/r5_stack.sh $EX/pg_rot1_b4_T32_cal128 cpu ho00 3 6
echo "TinyLlama T32 done $(date -u +%H:%M:%S)"
$D/r5_stack.sh $EX/pg_rot1_b4_T128 cpu ho00 5.5 8
echo "TinyLlama T128 done $(date -u +%H:%M:%S)"

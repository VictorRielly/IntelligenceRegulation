#!/bin/bash
# NATIVE LANE, after R8: the fidelity lane's two per-layer exports through the
# R8 CPU CLI — R8's owed parity check against the Python integer reference
# at per-layer constants. (1) TinyLlama dg T128 (22 blocks; need 5.5 / cap 8,
# witness cache 4: the R5 TinyLlama T128 stack peaked at 3.63 GiB); (2) 8B
# b7voc0 T128 (32 blocks; need 7.5 / cap 10.5, cache 0: peak 6.4-6.6 GiB).
# Each: prove (parity bit-exact at every layer or refused) -> fresh verify
# --controls from a seq-free verifier copy (publishes) -> byte re-check; then
# the report and the box label.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
F=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports
VNEED=2.5 VCAP=8 $D/r8_stack.sh $F/tinyllama_dg_rot1_T128 ho00 5.5 8 4
echo "tinyllama dg T128 script exit $?"
R=$D/r8/stack-tinyllama_dg_rot1_T128-ho00-cpu
python3 -B $D/r6/r6_b7_report.py $R $D/r5/stack-pg_rot1_b4_T128-ho00-cpu "" > /dev/null; python3 -B $D/r6_quiet_label.py $R
VNEED=3 VCAP=8 $D/r8_stack.sh $F/llama3_8b_pg_rot1_b7voc0_T128 ho00 7.5 10.5 0
echo "8b b7voc0 T128 script exit $?"
R=$D/r8/stack-llama3_8b_pg_rot1_b7voc0_T128-ho00-cpu
python3 -B $D/r6/r6_b7_report.py $R $D/r6/stack-llama3_8b_pg_rot1_b7_T128-ho00-cpu "" > /dev/null; python3 -B $D/r6_quiet_label.py $R

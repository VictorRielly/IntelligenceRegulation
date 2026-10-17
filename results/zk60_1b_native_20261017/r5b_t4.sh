#!/bin/bash
# NATIVE LANE task 4 ON R5b: after the R5b re-measure chain, the 32-block
# Llama-3-8B T128 trained stack again with the R5b CLI (sealing before the
# header, statement promoted only by the fresh-process verify), CPU, witness
# cache 0 (each witness rebuilt in the proving pass: at T128 a witness is
# about 0.45 GB, so keeping them would add up to ~14 GB). PENDING INDEPENDENT
# REVIEW OF THE T128 PROFILE.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
until [ -f $D/r5b_freeze.done ]; do sleep 20; done
[ "$(cat $D/r5b_freeze.done)" = 0 ] || { echo "R5b chain failed: no T128 re-run"; exit 1; }
VNEED=3 VCAP=8 $D/r5b_stack.sh /home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b6_T128 ho00 7.5 10.5 0
echo "8B T128 on R5b done $(date -u +%H:%M:%S)"

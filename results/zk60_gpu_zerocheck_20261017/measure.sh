#!/bin/bash
# GPU ZERO-CHECK lane (round 3): ONE guarded GPU test job (gtest.sh) with the
# clock-state sampler beside it (gpu_sampler2.sh: clocks.sm, clocks.mem,
# clocks_throttle_reasons.active, ~3/s, from the guard's START line until the
# job's .done). usage: measure.sh <label> <gtest.sh args after the label ...>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_gpu_zerocheck_20261017
L=$1; shift
setsid nohup bash -c "$D/gpu_sampler2.sh $D/logs/$L.out $D/logs/$L.done $D/logs/$L.gpu_samples.csv 'START $L'" >/dev/null 2>&1 &
$D/gtest.sh "$L" "$@" > $D/logs/$L.out 2>&1
echo $? > $D/logs/$L.exit

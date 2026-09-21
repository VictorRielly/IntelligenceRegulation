#!/bin/bash
# ROUND 8 (2026-09-21): the ten records of record as the REPOSITORY has them,
# taken BEFORE any refresh run, so the leaf diff compares against the
# committed bytes and not against a file the refresh overwrote.
set -x
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_mask/before
mkdir -p $D
for p in \
  zk60_native_run_gate/run-a-tame \
  zk60_native_run_gate/run-b-zero \
  zk60_native_run_gate_planeindex/run-c-tame \
  zk60_native_run_gate_planeindex/run-d-zero \
  zk60_native_run_gate_tagged/run-e-tame-tagged \
  zk60_native_run_gate_tagged/run-f-zero-tagged \
  zk60_native_run_gate_s20/run-g-dense-s20 \
  zk60_native_run_gate_s20/run-h-zero-s20 \
  zk60_native_run_gate_k4/run-i-dense-k4 \
  zk60_native_run_gate_k4/run-j-zero-k4 ; do
  git --no-pager -C $W show "HEAD:results/$p.json" > "$D/$(basename $p).json"
done

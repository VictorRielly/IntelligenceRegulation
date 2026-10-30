#!/bin/bash
# Rebuild and run only the reviewer's harness (Sol's four already reproduced in s4dc-checks-1).
set -u
O=/home/victor/IntelligenceRegulation/ops/zkp-mvp/s4-design-check-scratch
DEPS=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/working-tree/hashline/target/release/deps
RLIB=$DEPS/libhashline-779e537f6d239754.rlib
echo "rlib $(sha256sum "$RLIB" | cut -c1-64)"
echo "src $(sha256sum "$O/s4_gate_check.rs" | cut -c1-64)"
/home/victor/.cargo/bin/rustc --edition=2021 "$O/s4_gate_check.rs" -O -L "dependency=$DEPS" --extern "hashline=$RLIB" -o "$O/bin/s4_gate_check" 2> "$O/out/s4_gate_check.build.err" || { echo "BUILD FAIL"; exit 1; }
/usr/bin/env RAYON_NUM_THREADS=2 HL_GPU=0 "$O/bin/s4_gate_check" > "$O/out/s4_gate_check.out" 2> "$O/out/s4_gate_check.err"
rc=$?; echo "run s4_gate_check exit $rc"; tail -1 "$O/out/s4_gate_check.out"; exit $rc

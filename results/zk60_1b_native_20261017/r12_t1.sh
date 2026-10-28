#!/bin/bash
# NATIVE R12: compile the live tree's test binary, then the r12 tests (non-ignored)
set -u
/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12_cargo.sh r12-t1-build build 2 5 /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml test --release --lib --no-run || exit 1
/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12_cargo.sh r12-t1-run cpu 2 5 /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml test --release --lib -- --test-threads=4 r12_tests || exit 1

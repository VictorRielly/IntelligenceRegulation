#!/bin/bash
# NATIVE R12: rebuild after the census fixes; the r12 tests, the regression set, the kernel crate
set -u
/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12_cargo.sh r12-t3-build build 2 5 /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml test --release --lib --no-run || exit 1
/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12_cargo.sh r12-t3-check cpu 2 5 /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml test --release --lib -- --test-threads=4 r12_tests r9_tests trained_stack_tests trained_block_tests r6_tests r8_tests s24_tests s25_tests s33_tests pad::tests trained_statement review_e_ cs_port_tests parity dense_tests trained_calib_tests rung_tests grow_tests run_capture || exit 1
/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12_cargo.sh r12-t3-kernel cpu 1 3 /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/private-block-kernel-shaped/Cargo.toml test --release || exit 1

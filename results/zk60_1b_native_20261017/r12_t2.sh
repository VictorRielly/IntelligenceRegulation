#!/bin/bash
# NATIVE R12: the r12 tests (printing), then the targeted existing set, and the kernel crate
set -u
/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12_cargo.sh r12-t2-build build 2 5 /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml test --release --lib --no-run || exit 1
/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12_cargo.sh r12-t2-run cpu 2.5 6 /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml test --release --lib -- --test-threads=4 --nocapture r12_tests || exit 1
/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12_cargo.sh r12-t2-check cpu 4 7 /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml test --release --lib -- --test-threads=4 r9_tests trained_stack_tests trained_block_tests r6_tests r8_tests s24_tests s25_tests s33_tests pad::tests trained_statement review_e_ cs_port_tests parity dense_tests trained_calib_tests rung_tests grow_tests || exit 1
/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12_cargo.sh r12-t2-kernel cpu 1 3 /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/private-block-kernel-shaped/Cargo.toml test --release || exit 1

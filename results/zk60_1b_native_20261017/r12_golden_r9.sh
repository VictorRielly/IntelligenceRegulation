#!/bin/bash
# NATIVE R12: record the R9 goldens (incl. the DD shapes) in r12/r9-golden-tree.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
M=$D/r12/r9-golden-tree/hashline/Cargo.toml
$D/r12_cargo.sh r12-golden-r9-build build 3 6 $M test --release --lib --no-run || exit 1
$D/r12_cargo.sh r12-golden-r9-run cpu 7.5 10.5 $M test --release --lib -- --ignored --test-threads=1 --nocapture r12_golden || exit 1
grep "R12-GOLDEN" $D/r12/r12-golden-r9-run.log

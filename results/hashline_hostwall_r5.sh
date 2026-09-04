#!/bin/bash
# [UPERF3 AJ] rung 5: the twelve byte gates re-run on the FINAL binary
# (after the narrow-upload error-path fix), plus the crate tests.
set -u
R=/home/victor/wt-uperf3-aj
say () { echo; echo "=== $* ==="; date '+%F %T'; }
say "cargo test --release"
cargo test --release --manifest-path $R/hashline/Cargo.toml 2>&1 | grep -E "^test result|running [0-9]+ tests|^error"
$R/results/hashline_hostwall_floors.sh $R/results/scratch_r5

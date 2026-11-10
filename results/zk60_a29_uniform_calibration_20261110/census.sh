#!/bin/bash
# Lane A29: the W16R2 trained-model check on an export, with lane A25's own census test
# (a25_census_the_real_export_at_w16r2, commit 13593409, read-only copy of its crates in the
# A29 artifacts directory; debug test build). For each of the 26 layers it asks the trained
# door (Shape::with_layer_calibration at the W16R2 twin of the run seed) whether it admits the
# layer's calibration, and reports the W16R2 plane list (A, H) at the layer's own calibration
# AND its own gate. The test ends with A25's assertion that layer 0 is refused: on an export
# the door fully admits, that assertion FAILS by design (the census lines print first).
# usage: census.sh <export_dir> <out_log>   (run under the guard, class cpu)
set -u
EXP=$1
OUT=$2
M=/Users/victorrielly/zk60-artifacts/a29-uniform-calibration/a25tree/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
export HL_A25_EXPORT=$EXP HL_GPU=0 HL_PB_ORACLE=0 HL_PB_TIMING=0
/opt/homebrew/bin/cargo test --offline --locked -j 4 --manifest-path $M --lib a25_census -- --ignored --nocapture --test-threads=1 > $OUT 2>&1
rc=$?
echo "census rc=$rc" >> $OUT
grep -c "A25-CENSUS layer" $OUT
exit 0

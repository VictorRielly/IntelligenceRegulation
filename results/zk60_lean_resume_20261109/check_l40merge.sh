#!/bin/bash
# 2026-11-10, coordinator. Lane L40 (the run model with one shape per block; the app's real Shieldstral model as an
# instance; the gates re-indexed; a computable twin of the approved model) on the MERGED tree in the main checkout,
# as one guarded cpu job: the generic Lean check (check_lean_merge.sh), then the lane's two checkers: RunShapeCheck
# (the approved block run on the committed R13 trace fixture, 14 negative controls built in) and l40_shield_export.py
# (the 26 calibrations and the public data against the app's verifier export, negative control built in).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l40_20261110
L=$R/formal/ZK60Formal
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
R1=$R/results/zk60_lean_l1l2_20261106
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l40 RunShape.lean RunShapeShield.lean \
  RunShapeExec.lean RunShapeProtocol.lean RunShapeGate.lean RunShapeShieldOpen.lean RunShapeLeak.lean \
  RunShapeGateL.lean RunShapeCheck.lean
P=$O/l40merge.progress
X=$O/l40merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L40's own steps start"
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/RunShapeCheck.lean $V/block_fixture_t32.tsv $V/block_trace_low_h24_t32.tsv \
  $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/silu_-4_-13.bin $V/silu_-1_-11.bin \
  $R/results/zk60_lean_l2d_20261106/rust_token_out.tsv > ${X}_runshapecheck.log 2>&1
say "RunShapeCheck rc=$?"
tail -n 1 ${X}_runshapecheck.log >> $P
grep -c 'negative control .*: caught' ${X}_runshapecheck.log | sed 's/^/negative controls caught (14 required): /' >> $P
python3 -I $O/l40_shield_export.py $R > ${X}_shield_export.log 2>&1
say "l40_shield_export.py rc=$?"
grep -E '^L40 SHIELD EXPORT' ${X}_shield_export.log >> $P
say "all done (L40)"

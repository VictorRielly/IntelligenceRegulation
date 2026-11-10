#!/bin/bash
# 2026-11-10, coordinator. Lane L47 (the W16R2 block's lookup side and SC_TAB; SC_TAB's identity at R13; test-only
# Rust lean_l47_export_tests.rs) on the MERGED tree in the main checkout, as one guarded cpu job: the generic Lean
# check (check_lean_merge.sh, which now audits every lane L9 on, L41-L47 included), hashline's census tests and the
# lane's export tests, and the lane's three agreement checks against the code with their negative controls, on the
# committed short corpora.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l47_20261110
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
export LEAN_NUM_THREADS=4
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l47 BlockTabBase.lean BlockTabSlot.lean \
  BlockTabForm.lean BlockLookBase.lean BlockLookJoin.lean BlockLookEntry.lean BlockLookCov.lean BlockLookCov2.lean \
  BlockLookFinal.lean BlockLookRelBase.lean BlockLookSum.lean BlockLookRelHost.lean BlockLookRelPer.lean \
  BlockLookRelW16.lean BlockLookRelFinal.lean BlockLookDone.lean BlockR13JoinTab.lean BlockR13JoinForm.lean \
  BlockTabExportCheck.lean BlockHostExportCheck.lean
P=$O/l47merge.progress
X=$O/l47merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L47's own steps start"
for f in s25_tests hash_domain lean_l47_export_tests; do
  $C $f > ${X}_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" ${X}_$f.log >> $P
done
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/BlockTabExportCheck.lean $O/l47_w16r2_short.txt neg > ${X}_export_w16r2.log 2>&1
say "BlockTabExportCheck (W16R2 lookup side) rc=$?"; grep -E '^checks:|^negative controls:' ${X}_export_w16r2.log >> $P
$LAKE -d $R/formal env lean --run $L/BlockHostExportCheck.lean $O/l47_host_short.txt neg > ${X}_export_host.log 2>&1
say "BlockHostExportCheck (W16R2 host tables) rc=$?"; grep -E '^checks:|^negative controls:' ${X}_export_host.log >> $P
$LAKE -d $R/formal env lean --run $L/BlockTabExportCheck.lean $O/l47_r13_short.txt neg > ${X}_export_r13.log 2>&1
say "BlockTabExportCheck (R13 rung lookup side) rc=$?"; grep -E '^checks:|^negative controls:' ${X}_export_r13.log >> $P
say "all done (L47)"

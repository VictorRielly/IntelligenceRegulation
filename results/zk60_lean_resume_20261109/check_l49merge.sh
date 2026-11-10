#!/bin/bash
# 2026-11-10, coordinator. Lane L49 (the app's block at R13: block_knowledge_r13_rung, block_knowledge_r13_shield; 45
# modules) on the MERGED tree in the main checkout, as one guarded cpu job: the generic Lean check (check_lean_merge.sh:
# the full build, the axiom audits of every lane L9 on, the source scan of the lane's 45 files and its two checkers,
# the regressions), then the lane's own steps: hashline's census tests and the lane's export tests (the Shieldstral
# block test is #[ignore]d and does not run here), and the lane's two agreement checks against the code with their
# negative controls (BlockR13HostExportCheck on the committed short R13 rung corpus; BlockR13LookSumCheck on lane L47's
# committed R13 corpus). Every lean --run reads /dev/null (finding L49-FZC-1).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l49_20261110
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
export LEAN_NUM_THREADS=4
F=""
for m in $(cat $O/modules.txt); do F="$F $m.lean"; done
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l49 $F BlockR13HostExportCheck.lean \
  BlockR13LookSumCheck.lean < /dev/null
P=$O/l49merge.progress
X=$O/l49merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L49's own steps start; the source scan covered $(echo $F | wc -w) lane modules plus the two checkers"
for f in s25_tests hash_domain lean_l49_export_tests; do
  $C $f < /dev/null > ${X}_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" ${X}_$f.log >> $P
done
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/BlockR13HostExportCheck.lean $O/pub_r13_host_short.txt neg < /dev/null \
  > ${X}_export_host.log 2>&1
say "BlockR13HostExportCheck (R13 rung host tables) rc=$?"; grep -E '^checks:|^negative controls:' ${X}_export_host.log >> $P
# the first real Shieldstral T128 R13 block (layer 0 of the app's export; sub-agent pub's committed short corpus)
$LAKE -d $R/formal env lean --run $L/BlockR13HostExportCheck.lean $O/pub_shield_short.txt neg < /dev/null \
  > ${X}_export_shield.log 2>&1
say "BlockR13HostExportCheck (real Shieldstral block, layer 0) rc=$?"; grep -E '^checks:|^negative controls:' ${X}_export_shield.log >> $P
$LAKE -d $R/formal env lean --run $L/BlockR13LookSumCheck.lean $R/results/zk60_lean_l47_20261110/l47_r13_short.txt neg \
  < /dev/null > ${X}_sum.log 2>&1
say "BlockR13LookSumCheck (R13 sum claim) rc=$?"; grep -E '^checks:|^negative controls:' ${X}_sum.log >> $P
say "all done (L49)"

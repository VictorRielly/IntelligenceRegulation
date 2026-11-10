#!/bin/bash
# 2026-11-10, coordinator. Lane L44 (the block join: the five remaining hosts, the public tables, part of the helper
# layer, the R13 slot program; a test-only Rust export closing L35-7) on the MERGED tree in the main checkout, as one
# guarded cpu job: the generic Lean check (check_lean_merge.sh), hashline's census tests with the new test-only file
# (s25_tests, hash_domain), and the lane's three agreement checks against the code with their built-in negative
# controls, on the committed corpora.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l44_20261110
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l44 BlockHostBase.lean BlockHostPub.lean \
  BlockHostDzc.lean BlockHostSzc.lean BlockHostFzc.lean BlockHostQkv.lean BlockHostFinal.lean BlockR13Prog.lean \
  BlockR13ProgCnt.lean BlockR13ProgOk.lean BlockLkBase.lean BlockLkLzc.lean BlockLkGd.lean \
  BlockHelperExportCheck.lean BlockR13ProgCheck.lean BlockR13ProgExportCheck.lean
P=$O/l44merge.progress
X=$O/l44merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L44's own steps start"
for f in s25_tests hash_domain; do
  $C $f > ${X}_$f.log 2>&1; say "hashline $f with the new test-only file rc=$?"
  grep -E "^test result" ${X}_$f.log >> $P
done
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/BlockHelperExportCheck.lean $O/l44_w16r2_corpus.txt neg > ${X}_export_w16r2.log 2>&1
say "BlockHelperExportCheck rc=$?"; grep -E 'checks, [0-9]+ failed|negative controls' ${X}_export_w16r2.log >> $P
$LAKE -d $R/formal env lean --run $L/BlockR13ProgCheck.lean $R/results/zk60_lean_l17_20261107/slots_corpus.txt \
  $R/results/zk60_lean_l17_20261107/block_corpus.txt --neg > ${X}_r13_l17.log 2>&1
say "BlockR13ProgCheck rc=$?"; grep -E 'checks, [0-9]+ failed|negative control' ${X}_r13_l17.log | grep -v '^  ' >> $P
$LAKE -d $R/formal env lean --run $L/BlockR13ProgExportCheck.lean $O/l44_r13_corpus.txt neg > ${X}_export_r13.log 2>&1
say "BlockR13ProgExportCheck rc=$?"; grep -E 'checks, [0-9]+ failed|negative controls' ${X}_export_r13.log >> $P
say "all done (L44)"

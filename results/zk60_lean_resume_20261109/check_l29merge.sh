#!/bin/bash
# 2026-11-09, coordinator. Lane L29 (the executable stage verifiers, the stages' completeness, the honest prover's
# oracle form) on the MERGED tree in the main checkout, as one guarded cpu job. L29 adds test-only Rust
# (hashline/src/lean_l29_export_tests.rs), so beyond the generic Lean check (check_lean_merge.sh) this runs:
#  1. a FRESH test-only export on the merged tree, written OUTSIDE the repository (the committed corpus.txt is not
#     touched): corpus and the two stage segments of ONE run (the receipt is fresh-entropy);
#  2. hashline's census tests with the new test-only file (s25_tests, hash_domain, r19b);
#  3. StageVerifyExecCheck on that fresh pair, with the segments' bytes;
#  4. StageVerifyExecCheck on the COMMITTED corpus with the lane's own segments (kept outside the repository; their
#     sha256 are in the lane's segments.sha256);
#  5. the negative control (mutate_corpus.py, seven single changes; 8 failures required with the segments);
#  6. the regressions StageCheckOutC (L15's corpus) and ProtocolClassifyCheck (L18's corpus).
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_l29_20261107
O15=$R/results/zk60_lean_l15_20261107
O18=$R/results/zk60_lean_l18_20261107
L=$R/formal/ZK60Formal
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
D=/Users/victorrielly/zk60-artifacts/lean-merge-fixtures/l29merge
LANE=/Users/victorrielly/zk60-artifacts/resume-20261109/l29
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
MODS="StageVerifyExecLay.lean StageVerifyExecInC.lean StageVerifyExecOutC.lean StageVerifyExec.lean StageVerifyExecComplete.lean StageVerifyExecAssemble.lean HonestOracleProg.lean HonestOracleSlots.lean HonestOracleParts.lean StageVerifyExecCheck.lean"
/bin/bash $R/results/zk60_lean_resume_20261109/check_lean_merge.sh l29 $MODS
P=$O/l29merge.progress
X=$O/l29merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "L29's own steps start"
rm -rf $D; mkdir -p $D
env LEAN_L29_CORPUS=$D/corpus.txt LEAN_L29_SEG_IN=$D/l29_seg_in.bin LEAN_L29_SEG_OUT=$D/l29_seg_out.bin \
  $C lean_l29_export -- --nocapture > ${X}_export.log 2>&1; say "hashline lean_l29_export (test only) rc=$?"
grep -E "^test result" ${X}_export.log >> $P
ls -l $D | awk 'NR>1 {print "fresh export file: " $9 " " $5 " bytes"}' >> $P
for f in s25_tests hash_domain r19b; do
  $C $f > ${X}_$f.log 2>&1; say "hashline $f rc=$?"
  grep -E "^test result" ${X}_$f.log >> $P
done
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/StageVerifyExecCheck.lean $D/corpus.txt $D/l29_seg_in.bin $D/l29_seg_out.bin \
  > ${X}_l29check_fresh.log 2>&1; say "StageVerifyExecCheck on the FRESH merged-tree export rc=$?"
grep -E "^FAIL|^StageVerifyExecCheck" ${X}_l29check_fresh.log >> $P
( cd $LANE && shasum -a 256 l29_seg_in.bin l29_seg_out.bin ) > ${X}_lane_segments.sha256
grep -c -F -f ${X}_lane_segments.sha256 $O/segments.sha256 | sed 's/^/lane segments whose sha256 line is in the committed segments.sha256 (2 required): /' >> $P
$LAKE -d $R/formal env lean --run $L/StageVerifyExecCheck.lean $O/corpus.txt $LANE/l29_seg_in.bin $LANE/l29_seg_out.bin \
  > ${X}_l29check_committed.log 2>&1; say "StageVerifyExecCheck on the COMMITTED corpus with the lane's segments rc=$?"
grep -E "^FAIL|^StageVerifyExecCheck" ${X}_l29check_committed.log >> $P
python3 -I $O/mutate_corpus.py $D/corpus.txt $D/l29_mutated.txt
$LAKE -d $R/formal env lean --run $L/StageVerifyExecCheck.lean $D/l29_mutated.txt $D/l29_seg_in.bin $D/l29_seg_out.bin \
  > ${X}_negative.log 2>&1; say "negative control (seven single changes; nonzero rc and 8 failed required) rc=$?"
grep -E "^StageVerifyExecCheck" ${X}_negative.log >> $P
$LAKE -d $R/formal env lean --run $L/StageCheckOutC.lean $O15/corpus.txt > ${X}_l15check.log 2>&1; say "StageCheckOutC rc=$?"
tail -1 ${X}_l15check.log >> $P
$LAKE -d $R/formal env lean --run $L/ProtocolClassifyCheck.lean $O18/corpus.txt > ${X}_l18check.log 2>&1
say "ProtocolClassifyCheck rc=$?"; tail -1 ${X}_l18check.log >> $P
say "all done (L29)"

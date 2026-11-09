#!/bin/bash
# 2026-11-09, coordinator. The check of a Lean lane on the MERGED tree in the main checkout, as one guarded cpu job.
# It follows results/zk60_lean_l25_20261107/check_l25merge.sh, made generic:
#   check_lean_merge.sh <tag> <LeanFile> [<LeanFile> ...]
# <tag> is the lane (l26, l27, ...); its evidence directory is results/zk60_lean_<tag>_20261107 and the progress
# file is <tag>merge.progress there. The <LeanFile>s are the lane's new files in formal/ZK60Formal (base names with
# .lean), for the source scan.
# Steps: the full Lean build; the axiom audit of EVERY lane L9..L29 whose audit file exists (so L17 and L18 too);
# the source scan of the lane's files; the regressions ExecBlockCheck (W16R2 rung receipt), L11Check, L6Check,
# L5Check, the fixture L1 check and the R13 CheckR13Block. The binary fixtures are the ones regen_fixtures.sh made
# in ~/zk60-artifacts/lean-merge-fixtures (the R13 segment pair comes from one export, since it is fresh-entropy).
set -u
TAG=$1; shift
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_${TAG}_20261107
O17=$R/results/zk60_lean_l17_20261107
O11=$R/results/zk60_lean_l11_20261107
O9=$R/results/zk60_lean_l9_20261107
O6=$R/results/zk60_lean_l6_20261106
O5=$R/results/zk60_lean_l5_20261106
R1=$R/results/zk60_lean_l1l2_20261106
V=$R/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$R/formal/ZK60Formal
D=/Users/victorrielly/zk60-artifacts/lean-merge-fixtures
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
P=$O/${TAG}merge.progress
M=$O/${TAG}merge
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
: > $P
say "start; HEAD $(git -C $R rev-parse --short HEAD); lane files: $*"
$LAKE -d $R/formal build > ${M}_lake.log 2>&1; say "lake build rc=$?"
tail -2 ${M}_lake.log >> $P
grep -ciE "warning|sorry" ${M}_lake.log | sed 's/^/lines naming a warning or sorry in the build log: /' >> $P
for n in 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9; do
  A=$R/results/zk60_lean_l${n}_20261107/axioms_l${n}.lean
  [ -f $A ] || continue
  b=axioms_l${n}
  $LAKE -d $R/formal env lean $A > ${M}_$b.log 2>&1; say "axiom audit $b rc=$?"
  grep -cE "sorryAx|ofReduceBool" ${M}_$b.log | sed 's/^/sorryAx or ofReduceBool mentions: /' >> $P
  grep -oE "axioms: \[[^]]*\]" ${M}_$b.log | sort | uniq -c >> $P
  grep -cE "does not depend on any axioms" ${M}_$b.log | sed 's/^/declarations with no axioms: /' >> $P
done
FILES=""
for f in "$@"; do FILES="$FILES $L/$f"; done
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|bv_decide|ofReduceBool' \
  $FILES > ${M}_scan.log
say "source scan hits (grep rc 1 = none): rc=$?"
wc -l < ${M}_scan.log | sed 's/^/source scan hit lines: /' >> $P
ulimit -s 65520
$LAKE -d $R/formal env lean --run $L/ExecBlockCheck.lean $O9/corpus.txt $D/l9merge/fork_frame.bin > ${M}_l9check.log 2>&1
say "ExecBlockCheck regression rc=$?"; tail -1 ${M}_l9check.log >> $P
$LAKE -d $R/formal env lean --run $L/L11Check.lean $O11/corpus.txt > ${M}_l11check.log 2>&1; say "L11Check rc=$?"
tail -1 ${M}_l11check.log >> $P
$LAKE -d $R/formal env lean --run $L/L6Check.lean $O6/corpus.txt > ${M}_l6check.log 2>&1; say "L6Check rc=$?"
tail -1 ${M}_l6check.log >> $P
$LAKE -d $R/formal env lean --run $L/L5Check.lean $O5/corpus.txt > ${M}_l5check.log 2>&1; say "L5Check rc=$?"
tail -1 ${M}_l5check.log >> $P
$LAKE -d $R/formal env lean --run $L/L1Check.lean $V/block_fixture_t32.tsv \
  $V/block_trace_low_h24_t32.tsv $V/block_trace_low_t32.tsv $R1/rust_fixture_trace.tsv $V/r13_requant_vectors.tsv \
  > ${M}_l1check.log 2>&1; say "fixture L1 check rc=$?"
tail -1 ${M}_l1check.log >> $P
$LAKE -d $R/formal env lean --run $L/CheckR13Block.lean $O17/block_corpus.txt $D/l17merge/out/fork_frame.bin \
  $D/l17merge/out/segment_corpus.txt $D/l17merge/out/segment.bin > ${M}_r13block.log 2>&1
say "CheckR13Block regression rc=$?"; tail -1 ${M}_r13block.log >> $P
say "all done"

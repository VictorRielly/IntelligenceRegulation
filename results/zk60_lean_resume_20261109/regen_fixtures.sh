#!/bin/bash
# 2026-11-09, coordinator. The merged-tree checks of the Lean lanes read binary fixtures that earlier checks
# (check_l9merge.sh, check_l17merge.sh) regenerated into the session scratchpad under /private/tmp. The reboot of
# 2026-11-09 wiped that directory. This script regenerates them from the seeded test-only hashline exports into a
# durable directory outside the repository, and records that each small corpus equals the committed one byte for
# byte. One guarded job, class cpu. Nothing in the repository is written except this directory's logs.
set -u
R=/Users/victorrielly/IntelligenceRegulation
O=$R/results/zk60_lean_resume_20261109
O9=$R/results/zk60_lean_l9_20261107
O17=$R/results/zk60_lean_l17_20261107
M=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
D=/Users/victorrielly/zk60-artifacts/lean-merge-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
P=$O/regen.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; perf HEAD $(git -C $R rev-parse --short HEAD)"
rm -rf $D/l9merge $D/l17merge; mkdir -p $D/l9merge $D/l17merge/out
env L9_OUT=$D/l9merge $C lean_l9_export_the_w16r2_rung_block -- --nocapture --test-threads 1 > $O/regen_l9export.log 2>&1
say "hashline lean_l9_export (test only) rc=$?"
grep -E "^test result" $O/regen_l9export.log >> $P
cmp $D/l9merge/corpus.txt $O9/corpus.txt; say "regenerated L9 corpus equals the committed corpus.txt: cmp rc=$?"
ls -l $D/l9merge/fork_frame.bin | awk '{print "regenerated L9 fork frame bytes: " $5}' >> $P
env L17_OUT=$D/l17merge/out HL_R13_LOADER_FIXTURES=$R/results/zk60_1b_native_20261017/r13/loader-fixtures \
  $C lean_l17_export -- --nocapture --test-threads 1 > $O/regen_l17export.log 2>&1; say "hashline lean_l17_export rc=$?"
grep -E "^test result" $O/regen_l17export.log >> $P
for f in block_corpus.txt slots_corpus.txt segment_corpus.txt shape_corpus.txt; do
  cmp $D/l17merge/out/$f $O17/$f; say "regenerated $f equals the committed one: cmp rc=$?"
done
( cd $D/l17merge/out && shasum -a 256 fork_frame.bin segment.bin open_corpus.txt ) > $D/l17merge/large.sha256
cmp $D/l17merge/large.sha256 $O17/large_files.sha256; say "the three large files' sha256 equal large_files.sha256: cmp rc=$?"
say "all done"
